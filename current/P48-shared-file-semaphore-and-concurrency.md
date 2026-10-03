# 🗺️ Plan P-48: Shared Invariant Semaphore & Concurrency Control
* **Created:** 2026-10-03 | **Last Refined:** 2026-10-03
* **Target Issue / Milestone:** #96 *(supersedes #96 upon completion)*
* **Plan ID:** P-48
* **Status:** 🟣 Under Review
* **Base:** `1755e68` (develop)
* **Commits:** none
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.

---

## 🎯 1. Context & Architectural Goal

### Problem Statement
When two or more plans are in active execution concurrently (`⚡ In Development`) — whether through multi-agent parallel execution, distributed worktrees, or concurrent feature branches — shared mutable invariant files (`CODEMAP.md`, `CHANGELOG.md`, `ARCHITECTURE.md`, `MANUAL.md`) create a severe concurrency hazard:

1. **The False Collision Lock in Pair 7**: Planning Health Pair 7 (`check_pair7_inflight_boundary_collision`) flags any shared path listed under `### 📂 Target Files` as a hard collision. Because almost every plan must update `CHANGELOG.md` and `ARCHITECTURE.md`, listing them in Target Files blocks parallel development of completely disjoint source modules.
2. **The Lost-Update Anomaly (Unsynchronized Concurrent Writes)**: If Pair 7 simply exempts these files, multiple agents write to `CODEMAP.md` or `CHANGELOG.md` concurrently without coordination. Agent B reads a stale version while Agent A is writing, then writes back and clobbers Agent A's changes (read-modify-write race condition).
3. **The Git Integration Conflict Storm**: In multi-worktree execution, concurrent agents both append to the top of `## [Unreleased]` in `CHANGELOG.md` or the bottom of tables in `CODEMAP.md`, causing guaranteed Git merge conflicts at branch integration time.

### Architectural Goal
1. **POSIX Atomic Semaphore Engine (`aapp lock`)**: Provide a lightweight, cross-platform file locking mechanism in `.git/aapp_locks/` using POSIX atomic `mkdir` semantics (fully compatible with macOS Bash 3.2 and Linux) with lease timeout and stale lock recovery.
2. **Pair 7 Invariant Refinement**: Refine Pair 7 in `lib/planning_health.sh` to distinguish between **domain source files** (which strictly forbid concurrent modification) and **shared invariants** (`ALWAYS_ALLOWED_REGEX`), which are allowed under concurrency via synchronization.
3. **Transactional Shared File Access**: Provide clear protocol rules and CLI helpers (`aapp lock acquire <file>` / `aapp lock release <file>`) so autonomous agents acquire a write lease before reading, modifying, and committing shared invariant files.

---

## 🏗️ 2. Technical Blueprint

### 2.1 Atomic File Semaphore Architecture (`lib/lock_engine.sh`)

POSIX file locking across diverse platforms (macOS, Linux, BSD, container mounts) cannot reliably depend on `flock(1)` due to divergent CLI switches and absence in default macOS setups. Atomic `mkdir` is standard POSIX and guaranteed atomic by kernel filesystems:

```text
.git/aapp_locks/
├── CHANGELOG.md.lock/
│   ├── pid
│   ├── plan_id
│   └── acquired_at (epoch seconds)
└── CODEMAP.md.lock/
    ├── pid
    ├── plan_id
    └── acquired_at
```

#### Lease & Stale Eviction Protocol:
1. **Acquisition (`aapp lock acquire <file> [timeout_sec]`)**:
   - Path is sanitized and hashed/escaped: `.git/aapp_locks/<slug>.lock`.
   - Attempts atomic `mkdir .git/aapp_locks/<slug>.lock`.
   - On success: writes PID, Plan ID, and timestamp into lock directory; returns 0.
   - On failure: inspects lock timestamp. If `now - acquired_at > aapp.lockLeaseTimeout` (default 300s) and PID is dead, evicts stale lock and re-acquires. Otherwise retries up to `timeout_sec` (default 10s) with exponential backoff before failing closed (exit 1).
2. **Release (`aapp lock release <file>`)**:
   - Verifies ownership (Plan ID / PID match); deletes lock directory recursively (`rm -rf`).
3. **Quarantine / Brake**:
   - `aapp pause` releases all held locks or marks them quarantined.

### 2.2 Pair 7 Refinement (`lib/planning_health.sh`)

Update `check_pair7_inflight_boundary_collision`:
- Extract targets for each plan in `⚡ In Development`.
- If two plans share a file:
  - Check if target matches `$ALWAYS_ALLOWED_REGEX` (`CHANGELOG.md`, `ARCHITECTURE.md`, `CODEMAP.md`, `MANUAL.md`).
  - If YES: emit an advisory notice rather than a blocking error:
    ```text
    ℹ️  [Pair 7 Concurrency Notice] Plans 'P-46' and 'P-48' share invariant 'CHANGELOG.md' (managed via concurrency lock).
    ```
  - If NO (domain code conflict, e.g. both touch `lib/cmd_hook.sh`): emit hard blocking error:
    ```text
    ❌ [Pair 7 Violation] In-Flight Blueprint Collision on domain file 'lib/cmd_hook.sh'!
    ```

### 2.3 Integration with Commit Helper (`aapp commit`)

When `aapp commit` runs while multiple plans are in development:
- If staged files include `$ALWAYS_ALLOWED_REGEX`, `aapp commit` wraps the commit in a transient lock:
  1. `aapp lock acquire <file>`
  2. Executes git commit
  3. `aapp lock release <file>`

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
- Single-agent execution incurs zero overhead: lock acquisition succeeds on the first attempt with no contention.
- Existing single-plan workflows remain 100% backward-compatible.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Core Lock Engine & CLI Switchboard
- [ ] Task 1.1: Implement `lib/lock_engine.sh` with atomic `mkdir` primitives, metadata tracking, and stale lease eviction.
- [ ] Task 1.2: Implement `cmd_lock` supporting `acquire`, `release`, `status`, and `clean` subcommands.
- [ ] Task 1.3: Register `lock` verb in `lib/verbs.tsv` under the sync tier and dispatch from `aapp`.
- [ ] Task 1.4: Author contract documentation in `lib/docs/verbs/lock.md`.

### Phase 2: Pair 7 Concurrency Filter
- [ ] Task 2.1: Refactor `check_pair7_inflight_boundary_collision` in `lib/planning_health.sh` to filter out `$ALWAYS_ALLOWED_REGEX`.
- [ ] Task 2.2: Add concurrency notice output for shared invariants while maintaining hard stops for domain code collisions.
- [ ] Task 2.3: Add test cases in `tests/plan_resolver_test.sh` verifying shared invariant tolerance and domain collision blocking.

### Phase 3: Blast-Radius & Commit Engine Integration
- [ ] Task 3.1: Wire `aapp commit` to auto-acquire lock when mutating shared invariants during multi-plan execution.
- [ ] Task 3.2: Update `aapp pause` and `aapp resume` to release/audit active lock states.

### Phase 4: Automated Concurrency & Lock Test Suite
- [ ] Task 4.1: Author `tests/verbs/lock.sh` covering acquire, release, timeout, stale eviction, and contention backoff.
- [ ] Task 4.2: Verify full test suite passes cleanly via `./aapp test strict quiet`.

### Phase 5: Verification & Documentation
- [ ] Task 5.1: Update `MANUAL.md` with multi-agent concurrency guidelines and semaphore mechanics.
- [ ] Task 5.2: Update `.agents/CODEMAP.md` and `ARCHITECTURE.md` documenting `lib/lock_engine.sh`.
- [ ] Task 5.3: Update `CHANGELOG.md` under `## [Unreleased]`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `lib/lock_engine.sh` -> POSIX atomic directory/file semaphore engine.
- [ ] `NEW FILE` -> `lib/docs/verbs/lock.md` -> Lock verb contract documentation.
- [ ] `NEW FILE` -> `tests/verbs/lock.sh` -> Contract test suite for lock acquire/release/evict.
- [ ] `lib/planning_health.sh` -> Pair 7 collision filter distinguishing domain files from shared invariants.
- [ ] `lib/cmd_commit.sh` -> Lock integration during shared invariant commits.
- [ ] `lib/cmd_pause.sh` -> Lock state cleanup on emergency pause.
- [ ] `lib/verbs.tsv` -> Register lock verb in sync tier.
- [ ] `aapp` -> Dispatch lock verb.
- [ ] `tests/plan_resolver_test.sh` -> Add Pair 7 invariant concurrency test cases.
- [ ] `MANUAL.md` -> Multi-agent concurrency and lock documentation.
- [ ] `ARCHITECTURE.md` -> Architecture diagram update for lock subsystem.
- [ ] `.agents/CODEMAP.md` -> Register lock engine in codemap.
- [ ] `CHANGELOG.md` -> Record under unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Guard engine self-protection.
- [ ] `.agents/skills/*` -> Governance skills self-protection.
- [ ] `.plans/ISSUES.md` -> Managed via issue lifecycle.
- [ ] `.plans/state_matrix.md` -> Managed via state transitions.

---

## ❓ 5. Open Questions & Settled Decisions

* [x] **Question 1 — Default Lease Timeout Duration**: Is 300 seconds (5 minutes) the right default for stale lock eviction, or should it be configurable via `git config aapp.lockLeaseTimeout`? → **RESOLVED (developer, 2026-10-03): Adopted recommendation (300s default with git config override).** Lock engine defaults to a 300-second lease timeout, with custom values configurable via `git config aapp.lockLeaseTimeout`.
* [x] **Question 2 — Fragment Queue Alternative for CHANGELOG.md**: Can changelog updates be deferred to `aapp done` via an unreleased fragment queue? → **RESOLVED (developer, 2026-10-03): Rejected. CHANGELOG.md must be updated at code commit time.** By non-negotiable protocol invariant, every commit that touches code MUST update `CHANGELOG.md` in that exact same commit (enforced mechanically by pre-commit). Deferring to `aapp done` is fundamentally invalid because the code is already committed prior to plan archival. Therefore, `CHANGELOG.md` concurrency is managed at commit time via the atomic semaphore (`aapp lock` acquired during the commit window).

---

## 📦 6. Change Log & Refinement History

* **2026-10-03 (Refinement):** Settled decisions for Q1 (adopted 300s default lease with `aapp.lockLeaseTimeout` override) and Q2 (rejected `aapp done` changelog deferral; re-affirmed strict commit-time changelog requirement synchronized via atomic file semaphore).
* **2026-10-03:** Blueprint drafted from Issue #96 analysis. Established POSIX atomic `mkdir` semaphore engine, Pair 7 invariant filtering, and commit engine lease acquisition.
