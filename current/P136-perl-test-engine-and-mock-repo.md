# 🗺️ Plan P-136: Perl Test Engine And Mock Repository Builder
* **Created:** 2026-10-24 | **Last Refined:** 2026-10-24
* **Target Issue / Milestone:** none
* **Plan ID:** P-136
* **Changelog:** Added: update test engine `AAPP::Tests` with event log byte-offset slicing, assertion helpers, and action execution; create `AAPP::TestRepo` to build the single prepared repository
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-111
* **Commits:** none
<!-- AAPP-PROTOCOL:START v0.9.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** #<num>        <- written by verbs: 'aapp issue hotfix' or 'aapp refine <id> blocked <num>' adds it; 'aapp issue close' removes it -->
<!-- * **Emergency Hotfixes:** #<num> <- append-only, written by 'aapp issue hotfix'; more than aapp.maxEmergencyHotfixes blocks the plan for good -->
<!-- * **Also Closes:** #<n>, #<m>  <- written by 'aapp refine <id> closes <num> [remove]': further issues this plan sorts; 'aapp done' closes them with the plan's commit -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp refine issues`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
Plan `P-136` is the sixteenth member of group `P-111` (*Perl Port Of The Kit*). It executes immediately after `P-121` (once all core modules, hooks, and CLI verbs are in Perl and emitting structured telemetry) and **before** the test suites are implemented (`P-135` core tests redesign, `P-134` lifecycle verb tests, `P-125` remaining verb tests).

Per Decision **`D8`** in `.plans/pickup/perl-port-test-salvage-rfc.md`:
1. `lib/AAPP/Tests.pm` (currently ~1,240 lines) must be enhanced with the capabilities required by the single prepared repository schema and event telemetry spec: byte-offset event slicing of `.git/aapp.log`, event assertions (`event_or_die`, `no_event_or_die`, `log_match_or_die`), action runner (`run_action` writing `$sandbox/state/A<nnn>.json`), and universal worktree pointer rewriting.
2. The creation of the mock repository and all that includes creations in it (pre-seeding the 6 pools: disjoint mock source files `src/m*.py`, pre-seeded plans `P-1`..`P-35`, issues `#1`..`#20`, branches `develop`, `module/auth`, `third/other`, and bare remotes `$sandbox/origin.git` and `$sandbox/companion-ui`) is split into a **separate module**: `lib/AAPP/TestRepo.pm` (`AAPP::TestRepo`) to cleanly isolate test repository provisioning logic from test harness orchestration (`lib/AAPP/Tests.pm`).

**Strict Implementation References (`D7`, `D8`):**
- **Test Salvage RFC (Decisions `D2`, `D3`, `D6`, `D7`, `D8`):** `.plans/pickup/perl-port-test-salvage-rfc.md`
- **Single Prepared Repository Schema (Disjoint Pools & Pre-Seeding):** `.plans/pickup/perl-port-single-repo-schema.md`
- **Logging Events Spec (§2–§5 Telemetry & Assertions):** `.plans/pickup/perl-port-logging-events-spec.md`
- **Tabular Verification Matrix:** `.plans/pickup/perl-port-test-matrix-tabular-check.md`

---

## 2. Technical Blueprint

### 2.1 `AAPP::TestRepo` (`lib/AAPP/TestRepo.pm`) — Single Prepared Repository Builder
Ports and isolates repository fixture synthesis from `lib/AAPP/Tests.pm`:
- **`setup_shared_repo($sandbox)`**:
  - Initializes `$sandbox/repo` on branch `develop` (initial commit `C0`), configures `aapp.perlLogFile` to `aapp.log` (`$sandbox/repo/.git/aapp.log`), disables GPG signing, and configures test committer identity.
  - Provisions bare remotes: `$sandbox/origin.git` and `$sandbox/companion-ui`.
  - Provisions 6 disjoint source file pools (`Pool L`, `Pool S`, `Pool C`, `Pool G`, `Pool I`, `Pool D`, `Shared Docs`) per `perl-port-single-repo-schema.md` §2.2.
  - Pre-seeds plans `P-1`..`P-35` across Pools L, S, C, G, I, D with headers, §3 required tests, §4 Target Files, and initial status glyphs per `perl-port-single-repo-schema.md` §2.3.
  - Pre-seeds issues `#1`..`#20` in `.plans/ISSUES.md` and `.plans/issues_road_map.md` per `perl-port-single-repo-schema.md` §2.4.
  - Provisions branches: `develop`, `module/auth`, `third/other`, `remote-only/dev`.
  - Runs `AAPP::Cmd::Matrix::cmd_matrix()` at the end of setup so `state_matrix.md` is 100% in sync at `E0`.
  - Exportable helper methods: `seed_pool_l`, `seed_pool_s`, `seed_pool_c`, `seed_pool_g`, `seed_pool_i`, `seed_pool_d`, `seed_shared_docs`, `seed_plans`, `seed_issues`.

### 2.2 `AAPP::Tests` (`lib/AAPP/Tests.pm`) — Test Harness Enhancements
- **Delegation to `AAPP::TestRepo`**: Calls `AAPP::TestRepo::setup_shared_repo($sandbox)` during `setup_shared_repo` invocation.
- **Byte-Offset Event Log Slicing**:
  - In `lib_call` and `run_aapp`, records file size / byte offset of `$sandbox/repo/.git/aapp.log` before execution.
  - Reads the slice from pre-offset to current EOF post-execution.
  - Decodes JSONL lines into `$res->{events}` (arrayref of event hashrefs) and `$res->{log_lines}` (arrayref of raw log lines).
- **Test Assertion Helpers**:
  - `event_or_die($r, $command, $event, %expected_data)`: finds matching event by command and event, verifies expected data keys (exact string, qr// regex, or arrayref).
  - `no_event_or_die($r, $command, $event)`: asserts that no event with command/event was emitted.
  - `log_match_or_die($r, $tag, $regex, $desc)`: asserts a line with tag matching regex exists in log lines.
- **Action Execution & State Capture**:
  - `run_action($action_id, $code_sub)`: executes action via `lib_call`, captures `{ rc, ret, out, err, events, log_lines }`, writes state snapshot to `$sandbox/state/$action_id.json`.
- **Universal Worktree Pointer Rewrite in `copy_fixture`**:
  - Scans `.git/worktrees/*/gitdir` and any file named `.git` containing `gitdir:`, rewriting the source fixture prefix to the destination directory.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default).
- **Fallback Inventory**: `None`. All new assertion helpers fail closed with clear diagnostics naming file, line, and mismatched data.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Separate Mock Repository Builder (`AAPP::TestRepo`)
- [ ] Task 1.1: Author `lib/AAPP/TestRepo.pm` with `setup_shared_repo($sandbox)` provisioning `$sandbox/repo`, `$sandbox/origin.git`, `$sandbox/companion-ui`, the 6 source pools, plans `P-1`..`P-35`, and issues `#1`..`#20`.
- [ ] Task 1.2: Author unit contract test `t/core/test_repo.t` verifying that `AAPP::TestRepo` produces a valid, in-sync repository topology.
- [ ] Task 1.3: Author core contract `lib/docs/core/test_repo.md`.

### Phase 2: Test Engine Enhancements (`AAPP::Tests`)
- [ ] Task 2.1: Add byte-offset event log slicing to `lib/AAPP/Tests.pm` in `lib_call` and `run_aapp`.
- [ ] Task 2.2: Add assertion helpers `event_or_die`, `no_event_or_die`, and `log_match_or_die` to `lib/AAPP/Tests.pm`.
- [ ] Task 2.3: Add `run_action` and state snapshot capture to `lib/AAPP/Tests.pm`.
- [ ] Task 2.4: Add universal worktree pointer rewrite in `copy_fixture`.
- [ ] Task 2.5: Update core contract `lib/docs/core/tests.md`.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run `t/test-run strict quiet` and `./aapp test strict quiet` to confirm zero regressions across all existing suites.
- [ ] Task 3.2: Verify `CHANGELOG.md` updates and run `perl -c lib/AAPP/TestRepo.pm` and `perl -c lib/AAPP/Tests.pm`.
- [ ] Task 3.3: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly confined to the files listed under `### 📂 Target Files`.
- [ ] `NEW FILE` -> `lib/AAPP/TestRepo.pm` -> Single prepared repository builder (`setup_shared_repo`), provisioning pools L, S, C, G, I, D, mock files, branches, plans, issues.
- [ ] `lib/AAPP/Tests.pm` -> Add log-event byte-offset slicing, assertion helpers (`event_or_die`, `no_event_or_die`, `log_match_or_die`), `run_action`, state capture.
- [ ] `NEW FILE` -> `t/core/test_repo.t` -> Unit contract test for `AAPP::TestRepo`.
- [ ] `NEW FILE` -> `lib/docs/core/test_repo.md` -> Core contract for `AAPP::TestRepo`.
- [ ] `lib/docs/core/tests.md` -> Update contract for `AAPP::Tests` log assertions.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `t/verb/` -> Verb test suites are implemented in `P-134` and `P-125`.
- [ ] `t/core/*.t` (except `test_repo.t`) -> Redesigned in `P-135`.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified by RFC Decision D8 and single-repo schema)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-24:** Drafted per RFC Decision `D8` to update `lib/AAPP/Tests.pm` and create separate mock repository builder `lib/AAPP/TestRepo.pm` before test suite implementation (`P-135`, `P-134`, `P-125`).
