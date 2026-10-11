# 🗺️ Plan P-75: Offline Worktree & Local Lifecycle
* **Created:** 2026-10-11 | **Last Refined:** 2026-10-11
* **Target Issue / Milestone:** none
* **Plan ID:** P-75
* **Changelog:** Added: on-demand .offline worktree for air-gapped issues, local archive, and draft plans (P-75)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Commits:** none
<!-- AAPP-PROTOCOL:START v1.0.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** #<num>        <- written by verbs: 'aapp issue hotfix' or 'aapp refine <id> blocked <num>' adds it; 'aapp issue close' removes it -->
<!-- * **Emergency Hotfixes:** #<num> <- append-only, written by 'aapp issue hotfix'; more than aapp.maxEmergencyHotfixes blocks the plan for good -->

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
* **What**: Standardize an on-demand, isolated orphan worktree (`.offline` on orphan branch `offline`) acting as a local outbox and air-gapped staging environment for offline issue logging, local issue archiving, and draft plan authoring.
* **Why**: Currently, developers and agents cannot log issues or draft plans while offline without either failing closed or polluting the remote-tracked `.plans` branch. Furthermore, issues lack an air-gapped local lifecycle: an issue resolved while offline has no legitimate local audit trail.
* **The Core Solution**:
  1. **Isolated Orphan Worktree (`.offline`)**: Mounted on-demand (`git worktree add --orphan -b offline .offline`) and unmounted when clean (`git worktree remove .offline`), completely unpushed to `origin`.
  2. **Configurable High-Offset ID Allocation**: Offline issues use standard `#<num>` syntax starting from `max(canonical) + aapp.offlineIdOffset` (configurable via `git config aapp.offlineIdOffset`, default `1000`), preventing collisions with upstream pulls while retaining universal `#<num>` parser compatibility.
  3. **Local Outbox & Local Archive**: Contains `.offline/ISSUES.md` (active staged issues), `.offline/done/000-issues-archive.md` (locally resolved/archived issues), and `.offline/current/` (offline draft plans).
  4. **Context Recovery Awareness**: `aapp status` detects `.offline/` and reports staged offline items alongside canonical work.
  5. **Atomic Promotion & Synchronization (`aapp offline sync`)**: Reconciles staged issues with canonical `.plans/` (and external trackers), atomically re-identifying `#<temp_id>` references in plans to canonical IDs.

---

## 2. Technical Blueprint

### A. The `.offline` Worktree Topology
Mounted alongside `.plans`, `.agents`, and `.githooks`:
```text
.offline/
├── ISSUES.md                  <- Staged offline issues (standard table schema)
├── done/
│   ├── 000-issues-archive.md  <- Locally resolved/closed issues
│   └── P*-*.md                <- Completed local scratchpad plans
└── current/                   <- Exploratory/offline draft plans
```

### B. High-Offset ID Allocation Strategy
* **Syntax Invariant**: Offline issue IDs strictly retain the canonical `#<num>` syntax (`^#[0-9]+$`).
* **Offset Calculation**:
  $$\text{Next Offline ID} = \max(\text{canonical IDs in } .plans) + \text{offlineIdOffset}$$
* **Configuration**: `aapp.offlineIdOffset` (default: `1000`, overrideable via `git config aapp.offlineIdOffset <val>`).
* **Seeding & Storage**:
  - Tracked in `git config aapp.offlineIssueId`.
  - When offline, `aapp issue allocate` (or logging via `refine issues` / `hotfix`) seeds `aapp.offlineIssueId` from `max(canonical) + offset` if unset, then increments.
  - Because offline IDs start at e.g. `#1045` when canonical is `#45`, local work is visibly distinct and completely immune to upstream `git pull` collisions of normal sequential IDs.

### C. CLI Verbs & Lifecycle (`aapp offline`)
* `aapp offline mount`: Creates or mounts the `.offline` worktree on orphan branch `offline` (reusing `mount_or_create_worktree`).
* `aapp offline unmount`: Unmounts and prunes `.offline` after verifying no un-synced items remain (or `--force`).
* `aapp offline status`: Detailed status of staged issues and draft plans in `.offline/`.
* `aapp offline sync`:
  1. For each active row in `.offline/ISSUES.md`:
     - Allocates canonical ID (from canonical counter or provider).
     - Relocates row from `.offline/ISSUES.md` into `.plans/ISSUES.md`.
     - Atomically rewrites plan references (`Target Issue`, `Blocked On`) from `#<temp>` to `#<canonical>`.
  2. For each archived row in `.offline/done/000-issues-archive.md`:
     - Relocates to `.plans/done/000-issues-archive.md`.
  3. Commits canonical changes to `.plans` branch.
  4. Clears `.offline` ledgers and prompts for unmount.

### D. Context Recovery Integration (`aapp status`)
* `cmd_status.sh` checks if `.offline` is mounted and non-empty.
* If staged items exist, appends a dedicated pillar to the briefing:
  ```text
  📡 Staged Offline Work (.offline):
     - Issues: 2 staged (#1043, #1044) | 1 in local archive (#1042)
     - Draft Plans: 1 offline blueprint (current/P99-experimental.md)
     Action: Run 'aapp offline sync' when online to publish.
  ```

### E. Blast Radius & Hook Enforcement
* `templates/blast-radius-guard.sh`: Recognizes `.offline/**` as a permitted path for offline workflows.
* `templates/aapp-pre-commit`: Rejects commits on `develop` or `plans` that stage files inside `.offline/`.
* Pre-push gate: Blocks any push containing `refs/heads/offline`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/offline.sh::test_mount_creates_orphan_worktree` -> asserts `aapp offline mount` creates `.offline` on orphan branch `offline`
- [ ] `tests/verbs/offline.sh::test_allocate_uses_offset` -> asserts offline allocation starts at `max(canonical) + aapp.offlineIdOffset`
- [ ] `tests/verbs/offline.sh::test_custom_offset_configuration` -> asserts changing `git config aapp.offlineIdOffset 5000` starts offline IDs at 5000+
- [ ] `tests/verbs/offline.sh::test_offline_issue_local_archive` -> asserts closing an offline issue moves it to `.offline/done/000-issues-archive.md`
- [ ] `tests/verbs/offline.sh::test_status_reports_staged_offline_work` -> asserts `aapp status` displays staged offline issues and plans
- [ ] `tests/verbs/offline.sh::test_offline_sync_promotes_and_relinks` -> asserts `aapp offline sync` moves rows to `.plans/`, rewrites `#<temp>` references to `#<canonical>`, and clears `.offline`
- [ ] `tests/verbs/offline.sh::test_unmount_refuses_when_dirty` -> asserts `aapp offline unmount` refuses if unpromoted issues exist without `--force`

### Phase 1: Tests First (red)
- [ ] Task 1.1: Author test suite in `tests/verbs/offline.sh` proving mounting, offset allocation, status detection, local archiving, and sync.

### Phase 2: Core Implementation
- [ ] Task 2.1: Implement `lib/cmd_offline.sh` with `mount`, `unmount`, `status`, and `sync` handlers.
- [ ] Task 2.2: Add high-offset offline ID allocation logic in `lib/cmd_issue.sh` / `lib/plan_resolver.sh`.
- [ ] Task 2.3: Wire local archive relocation in `lib/cmd_issue.sh` when closing issues located in `.offline/`.
- [ ] Task 2.4: Update `lib/cmd_status.sh` to observe `.offline/` and print the offline briefing pillar.
- [ ] Task 2.5: Update `templates/blast-radius-guard.sh` and `templates/aapp-pre-commit` to authorize `.offline/**` and prevent push leakage.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify edge cases.
- [ ] Task 3.2: Update user-facing documentation in `MANUAL.md` (`aapp offline` commands, offset config, local lifecycle).
- [ ] Task 3.3: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md`.
- [ ] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 3.5: Log every finding outside Target Files as an issue (`aapp refine issues`).

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `lib/cmd_offline.sh` -> CLI ingress and subcommands for `aapp offline` (`mount`, `unmount`, `status`, `sync`).
- [ ] `lib/cmd_issue.sh` -> Offline ID allocation fallback and local archiving handling.
- [ ] `lib/cmd_status.sh` -> Context recovery briefing inspection of `.offline/`.
- [ ] `lib/plan_resolver.sh` -> Offset calculation and `aapp.offlineIdOffset` config resolution.
- [ ] `templates/blast-radius-guard.sh` -> Worktree path authorization.
- [ ] `templates/aapp-pre-commit` -> Hook leak protection against `.offline`.
- [ ] `MANUAL.md` -> User documentation for offline workflows and configuration.
- [ ] `ARCHITECTURE.md` -> Architecture sync for the `.offline` worktree.
- [ ] `.agents/CODEMAP.md` -> Codemap sync for `cmd_offline.sh`.

### 🧪 Required Test Files
- [ ] `NEW FILE` -> `tests/verbs/offline.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_plan.sh` -> Plan drafting core unchanged (offline plans use standard templates).
- [ ] `.githooks/blast-radius-guard` -> Generated hook runtime; edit template instead.

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1:** Should `aapp offline mount` be automatically triggered on the fly whenever `aapp refine issues` or `aapp issue allocate` is run while offline, or should it require an explicit `aapp offline mount` first?
* [ ] **Question 2:** When promoting offline draft plans during `aapp offline sync`, should they automatically land in `.plans/current/` as `🟣 Under Review`, or should plans require explicit individual promotion (e.g. `aapp offline publish plan <id>`)?

---

## 📦 6. Change Log & Refinement History
* **2026-10-11:** Scaffolded canonical blueprint P-75 for the offline worktree and local lifecycle.
* **2026-10-11:** Completed technical blueprint, high-offset ID allocation (+1000 configurable), local archiving, and sync relinking specifications.
