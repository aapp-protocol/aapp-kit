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
* **Status:** 🟥 BLOCKED
* **Blocked On:** #140 (was ⚡ In Development)
* **Emergency Hotfixes:** #140
* **Base:** `b4f94e8` (feature/issue-tracker)
* **Worktree:** .workspace/P75 (plan/P75-offline-worktree)
* **Group:** P-72
* **Commits:** `8296ca6` (plan/P75-offline-worktree), `8b4ccb7` (plan/P75-offline-worktree)
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
* **Why**: With a provider installed, an issue cannot be logged while the provider is unreachable: numbering refuses. An issue logged offline has a temporary id, which must never be committed to the plans branch or mixed with the rows of the record (the committed ledger, or the tracker's rows in the untracked one); telling them apart by a marker would put special cases in every reader and in the sync. Making a file untracked needs an ignore rule, which is itself a commit to the shared plans branch. A separate worktree keeps offline rows apart by location, with the same format and the same ledger functions, gives offline work its own local history (an audit trail for what was logged, fixed and closed offline), and is never pushed.
* **The Core Solution**:
  1. **Isolated Orphan Worktree (`.offline`)**: Mounted on-demand (`git worktree add --orphan -b offline .offline`) and unmounted when clean (`git worktree remove .offline`), completely unpushed to `origin`.
  2. **Configurable High-Offset ID Allocation**: Offline issues use standard `#<num>` syntax starting from `max(canonical) + aapp.offlineIdOffset` (configurable via `git config aapp.offlineIdOffset`, default `1000`), preventing collisions with upstream pulls while retaining universal `#<num>` parser compatibility.
  3. **Local Outbox & Local Archive**: Contains `.offline/ISSUES.md` (active staged issues), `.offline/done/000-issues-archive.md` (locally resolved and aborted issues), and `.offline/current/` (offline draft plans).
  4. **Context Recovery Awareness**: `aapp status` detects `.offline/` and reports staged offline items alongside canonical work.
  5. **Atomic Promotion & Synchronization (`aapp offline sync`)**: Reconciles staged issues with canonical `.plans/` (and external trackers), atomically re-identifying `#<temp_id>` references in plans to canonical IDs.
  6. **One Ledger View**: the `.offline` ledgers are a source of the ledger functions in `lib/aapp-lib.sh` (P-73), next to the main ledger. Every reader (status, `issue list`, blockers, `draft`, `next-blocker`) sees offline issues, marked as offline, with no reader of its own.
  7. **Opt-out**: offline staging is configurable; with `aapp.offlineEnabled=false` it never kicks in and a provider failure refuses (§2 C).

---

## 2. Technical Blueprint

### A. The `.offline` Worktree Topology
Mounted alongside `.plans`, `.agents`, and `.githooks`:
```text
.offline/
├── ISSUES.md                  <- Staged offline issues (table schema with Branch cell, P-78)
├── outbox                     <- Steps for existing issues not yet sent to the provider
├── done/
│   ├── 000-issues-archive.md  <- Locally resolved (<sha>) and aborted (`aborted`, P-76) issues
│   └── P*-*.md                <- Completed local scratchpad plans
└── current/                   <- Exploratory/offline draft plans
```

### B. Local Offline ID Allocation Strategy
* **Sole Owner**: This offline numbering rule lives exclusively in P-75 (removed from P-74).
* **Syntax Invariant**: Offline issue IDs strictly retain numeric `#<num>` syntax (`^#[0-9]+$`). At sync, the canonical ID returned by the provider may be a tracker key (`#PROJ-88`, P-79) or a kit counter number; offline IDs themselves stay numeric, so the counter rule continues to apply to them.
* **Allocation Algorithm (handled by the issue handler script)**:
  When the agent hands an issue to the handler script and the provider fails (or times out, or `offlineOnly` is set), the handler allocates the ID using this rule:
  1. **Existing local offline issues**: If `.offline/` already contains local issues (in `ISSUES.md` or `done/000-issues-archive.md`), allocate **one number higher than the highest registered offline ID**:
     $$\text{Next ID} = \max(\text{IDs in } .offline) + 1$$
  2. **First local offline issue**: If no local offline issues exist yet, match the highest ID registered locally in canonical `.plans/` (across `ISSUES.md` and `done/000-issues-archive.md`) plus the configurable offset:
     $$\text{Next ID} = \max(\text{canonical IDs in } .plans) + \text{offlineIdOffset}$$
* **Configuration**: `aapp.offlineIdOffset` (default: `1000`, overrideable via `git config aapp.offlineIdOffset <val>`).
* **Filesystem-Derived Monotonicity**:
  - Scanning the ledgers in `.offline/` and `.plans/` always computes the exact next ID without requiring external network access.
  - The local git config key `aapp.offlineIssueId` persists the ratchet, but if unset or out of sync, scanning the active and archived ledgers yields the deterministic next ID.
  - **Example**: If canonical max is `#42`, the first offline issue is allocated `#1043`. The second offline issue finds `#1043` in `.offline/` and allocates `#1044`, then `#1045`, guaranteeing clean sequential numbering without repeated offset jumps.

* **Plan ids follow the same rule.** With an `aapp-planid` provider installed and unreachable, `aapp draft` takes a temporary plan id: the highest plan id in `.offline/current/` plus 1, or, for the first one, the highest plan id known locally plus `aapp.offlineIdOffset`; the draft is written to `.offline/current/`. Without such a provider nothing changes: the kit's counter numbers the plan and it is drafted in `.plans/current/`, online or not.

### C. Three-Tier Offline Governance & Where Fallback Hooks In
All network-dependent plugin operations (e.g. `aapp-issue-tracker`) are governed by a global timeout and a 3-tier execution mode:

| Mode | Configuration | Operational Behavior |
| :--- | :--- | :--- |
| **Smart Fallback** *(Default)* | `aapp.offlineEnabled=true`<br>`aapp.offlineOnly=false` | **Natural Flow**: Attempts plugin first. If it succeeds, canonical sync proceeds. If plugin times out (exceeding `aapp.pluginTimeout`) or fails with network error, gracefully falls back to `.offline` workflow. |
| **Zero-Latency Offline** | `aapp.offlineOnly=true`<br>(or `aapp offline on`) | **Immediate Offline**: Completely skips plugin execution and network sockets. Directly routes operations to `.offline` on the fly with zero latency and zero timeout waits. |
| **Strict Compliance** | `aapp.offlineEnabled=false` | **Fail-Closed**: Attempts plugin. If unreachable, failing, or timed out, fails closed with a diagnostic refusal; local `.offline` staging is denied to prevent untracked drift. |

* **Where the fallback hooks in**: In P-74, every provider failure surfaces at one point — the `issue_provider` wrapper in `lib/cmd_issue.sh` — where logging an issue (`issue.log`) refuses. P-75 replaces that one refusal with the offline staging path (unless `aapp.offlineEnabled=false`, which keeps P-74's refusal).
* **Plugin timeout (`aapp.pluginTimeout`)**: Integer seconds (default: `10`). The key and its enforcement belong to the plugin protocol (P-77), which runs every plugin call under the hook dispatcher's watchdog; this plan uses a timeout as one of the failures that trigger the offline path.

### D. CLI Verbs & Lifecycle (`aapp offline`)
* `aapp offline mount`: Creates or mounts the `.offline` worktree on orphan branch `offline` (reusing `mount_or_create_worktree`), and adds `.offline/` to `.git/info/exclude`, so the main repository ignores it without a commit.
* `aapp offline unmount`: Unmounts and prunes `.offline` after verifying no un-synced items remain (or the bare token `force`).
* `aapp offline on` / `off`: Toggles `aapp.offlineOnly` for zero-latency airplane/air-gap sessions.
* `aapp offline status`: Detailed status of staged issues and draft plans in `.offline/`.
* `aapp offline sync` (run when the provider is reachable; it also runs before any tracker sync of P-74 reads issues, see §C):
  1. **The outbox first.** Steps for existing issues that could not reach the provider while offline (`refine`, `fix`, `fix-abort`, `abort`, `close`) are kept in `.offline/outbox`, one per line, in the order they happened. They are sent before anything is read from the tracker; a line the provider accepts is removed. While a line remains, the tracker's list is not applied to the local ledger, so a close made offline is never undone by a sync.
  2. **Staged active issues**: for each row in `.offline/ISSUES.md`, the `log` step is sent with the whole issue (its `description` and `notes` from the kit's store, its `Branch` cell).
     - The id comes back from the provider (a tracker key such as `#PROJ-88`, or a number, P-79), or from the kit's counter when the provider answers `declined` and does not keep the record.
     - Plan references (`Target Issue`, `Blocked On`, the road map, draft blueprints) are rewritten from `#<temp>` to the real id with `ledger_relink`; the store entry moves to the real id.
     - The row leaves `.offline/ISSUES.md` and is written to the main ledger through `ledger_add_row`.
     - A row the provider fails on, or declines while it keeps the record, stays staged; the sync continues with the others and reports it.
  3. **Staged archived issues & the Commit Immutability Invariant**: for each row in `.offline/done/000-issues-archive.md` (closed, or aborted via P-76, while offline), the `log` step is sent and then `close` or `abort` with its commit and summary.
     - **Former id recording**: an issue logged offline as `#1043` and committed as `(#1043)` gets its real id at sync. Git commits are immutable, so historical commit messages are never rewritten. The archive row's summary, and the summary sent to the provider, carry `logged offline as #<temp>`.
     - **Former id lookup**: `ledger_locate` and `ledger_row` in `lib/aapp-lib.sh` resolve a former id (`#1043` or `1043`) to the real one.
     - **Integrity checks** (Pairs 1, 2, 8) and `issue_id_refs` treat a commit's reference to `#<temp>` as an alias of the real id.
  4. **Draft plans**: each blueprint in `.offline/current/` moves into `.plans/current/` as `🟣 Under Review` (registered in `state_matrix.md`), with its `#<temp>` issue references rewritten.
     - **Plan ids mimic issue ids (§B).** A draft made while the `aapp-planid` provider was unreachable carries a temporary id. The sync asks the provider for the real one, renames the file (`P<temp>-<slug>.md` to `P<real>-<slug>.md`), rewrites its header and every reference to `P-<temp>` (issue rows, other plans, the group's members), and adds `drafted offline as P-<temp>` to the plan's change log. A draft has no commits, so nothing in Git history names the temporary id.
  5. **What is committed** depends on where the record is (P-74 §2.4):
     - *Ledgers committed* (no provider that lists issues): the moved rows, the archive, the road map and the changed plans are committed to the plans branch.
     - *The tracker keeps the record* (ledgers untracked): only the plans whose references changed, and the promoted drafts, are committed; the ledgers are local files.
  6. Clears what was synced from `.offline` and offers to unmount.
* **Without any provider** nothing is staged: the kit numbers and logs locally, online or not.

### E. Context Recovery Integration (`aapp status`)
* `cmd_status.sh` checks if `.offline` is mounted and non-empty.
* If staged items exist, appends a dedicated pillar to the briefing:
  ```text
  📡 Staged Offline Work (.offline):
     - Issues: 2 staged (#1043, #1044) | 1 in local archive (#1042)
     - Draft Plans: 1 offline blueprint (current/P99-experimental.md)
     Action: Run 'aapp offline sync' when online to publish.
  ```

### F. Wiring Into the Ledger Module (P-73, P-74, P-78, P-79)
* **Reads:** `ledger_rows` and `ledger_locate` in `lib/aapp-lib.sh` merge `.offline/ISSUES.md` and `.offline/done/000-issues-archive.md` (`offline`), so offline issues block plans and show in `status`, `issue list`, `draft` and `next-blocker` like local ones.
* **Writes:** logging, closing, and aborting (`aapp issue abort <num>`, P-76) while offline go through `lib/aapp-lib.sh` writers, pointed at `.offline/`. Aborting an offline issue moves its row to `.offline/done/000-issues-archive.md` with commit `` `aborted` `` and `Aborted: <reason>`, unblocks plans it blocked, and withdraws any attached mini plan or draft plan in `.offline/current/`.
* **Branch:** An issue logged offline carries its `Branch` cell like any other (P-78), under the same rule: a branch only when one is given (`branch <name>`), otherwise none, which means the development branch.
* **Fallback hook:** The smart fallback replaces the P-74 provider failure refusal in `issue_provider` (`lib/cmd_issue.sh`) with the `.offline` allocation and staging path. A step for an existing issue that cannot be sent is written to `.offline/outbox` instead of only warning, and sent first at the next sync (§D).
* **Relink:** sync rewrites `#<temp>` to `#<canonical>` (including tracker keys like `#PROJ-88`, P-79) with `ledger_relink`, extended to plans' `Target Issue` and `Blocked On` lines.
* **ID Resolution:** `ledger_locate` and `ledger_row` resolve former offline IDs (`"logged offline as #<temp>"`) to the canonical ID.
* **CLI Normalization:** `aapp offline` and offline issue commands accept bare IDs or `#<num>` via `issue_id_normalize` (P-79).

### G. Blast Radius & Hook Enforcement
* `templates/blast-radius-guard.sh`: Recognizes `.offline/**` as a permitted path for offline workflows.
* `templates/aapp-pre-commit`: Rejects commits on `develop` or `plans` that stage files inside `.offline/`.
* The `offline` branch is never pushed by the kit: it is not among the worktrees `aapp push` and `aapp sync` handle by default, and both refuse it when `aapp.syncWorktrees` names it. The kit adds no pre-push hook.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/offline.sh::test_mount_creates_orphan_worktree` -> asserts `aapp offline mount` creates `.offline` on orphan branch `offline`
- [ ] `tests/verbs/offline.sh::test_allocate_uses_offset` -> asserts first offline allocation starts at `max(canonical) + aapp.offlineIdOffset`
- [ ] `tests/verbs/offline.sh::test_allocate_subsequent_increments_by_one` -> asserts subsequent offline allocation increments from highest existing offline ID (+1)
- [ ] `tests/verbs/offline.sh::test_custom_offset_configuration` -> asserts changing `git config aapp.offlineIdOffset 5000` starts offline IDs at 5000+
- [ ] `tests/verbs/offline.sh::test_plugin_smart_fallback_on_timeout` -> asserts when plugin hangs beyond `aapp.pluginTimeout`, operation falls back to `.offline` with advisory
- [ ] `tests/verbs/offline.sh::test_offline_only_skips_network` -> asserts `offlineOnly=true` bypasses plugin execution completely with zero latency
- [ ] `tests/verbs/offline.sh::test_offline_disabled_fails_closed` -> asserts `offlineEnabled=false` refuses when plugin fails instead of staging locally
- [ ] `tests/verbs/offline.sh::test_offline_issue_local_archive` -> asserts closing an offline issue moves it to `.offline/done/000-issues-archive.md`
- [ ] `tests/verbs/offline.sh::test_offline_issue_abort_archives_row` -> asserts `aapp issue abort` on an offline issue moves it to `.offline/done/000-issues-archive.md` with commit `aborted` and unblocks plans
- [ ] `tests/verbs/offline.sh::test_status_reports_staged_offline_work` -> asserts `aapp status` displays staged offline issues and plans
- [ ] `tests/verbs/offline.sh::test_offline_sync_promotes_and_relinks` -> asserts `aapp offline sync` moves rows to `.plans/`, rewrites `#<temp>` references to `#<canonical>`, and clears `.offline`
- [ ] `tests/verbs/offline.sh::test_offline_issue_in_every_view` -> asserts an offline issue shows, marked, in `status` and `issue list`, and blocks a plan whose `Blocked On` names it
- [ ] `tests/verbs/offline.sh::test_sync_preserves_offline_commit_messages` -> asserts sync promotes closed offline issue without rewriting historical commit subject (#<temp>), recording formerly offline #<temp> in archive summary
- [ ] `tests/verbs/offline.sh::test_former_id_lookup_resolves_to_canonical` -> asserts ledger_locate and ledger_row resolve former offline ID (#1043) to canonical ID after sync
- [ ] `tests/verbs/offline.sh::test_unmount_refuses_when_dirty` -> asserts `aapp offline unmount` refuses if unpromoted issues exist without the `force` token
- [ ] `tests/verbs/offline.sh::test_outbox_sent_before_tracker_read` -> asserts an issue closed offline stays closed after the next sync: its `close` step is sent first, and while it cannot be sent the tracker's list is not applied
- [ ] `tests/verbs/offline.sh::test_sync_sends_description_and_notes` -> asserts a staged issue's description and notes are in the `log` payload and the store entry moves to the real id
- [ ] `tests/verbs/offline.sh::test_sync_commits_by_record` -> asserts with committed ledgers the sync commits rows and plans, and with the tracker as the record it commits only the changed plans
- [ ] `tests/verbs/offline.sh::test_sync_keeps_failed_row_staged` -> asserts a row the provider fails on stays in `.offline`, the others are synced, and the sync reports it
- [ ] `tests/verbs/offline.sh::test_offline_dir_excluded_locally` -> asserts mounting adds `.offline/` to `.git/info/exclude` and makes no commit
- [ ] `tests/verbs/offline.sh::test_offline_draft_takes_temporary_plan_id` -> asserts with an unreachable `aapp-planid` provider `draft` writes `.offline/current/P<temp>-<slug>.md`, the id being the highest local plan id plus the offset, then the highest offline plan id plus 1
- [ ] `tests/verbs/offline.sh::test_sync_gives_draft_real_plan_id` -> asserts the sync asks the provider for the id, renames the file, rewrites the header and every reference to `P-<temp>`, and records the former id in the plan's change log
- [ ] `tests/verbs/offline.sh::test_push_verbs_refuse_offline` -> asserts `aapp push` and `aapp sync` leave `.offline` alone by default and refuse when `aapp.syncWorktrees` names `offline`

### Phase 1: Tests First (red)
- [ ] Task 1.1: Author test suite in `tests/verbs/offline.sh` proving mounting, offset allocation, sequential local increments, status detection, local archiving, and sync.

### Phase 2: Core Implementation
- [ ] Task 2.1: Implement `lib/cmd_offline.sh` with `mount`, `unmount`, `on`, `off`, `status`, and `sync` handlers.
- [ ] Task 2.2: Add offline ID allocation logic in issue handler (max offline + 1 if offline issues exist, else max canonical + offset). The same rule for plan ids (Task 2.2b).
- [ ] Task 2.2b: Offline plan ids: `draft` with an unreachable `aapp-planid` provider; real id, rename and reference rewrite at sync.
- [ ] Task 2.3: Wire the 3-tier governance into the `issue_provider` wrapper (`lib/cmd_issue.sh`): skip the provider when `offlineOnly`, stage on failure or timeout, refuse when offline is disabled; the outbox for steps that could not be sent.
- [ ] Task 2.4: Wire local archive relocation in `lib/cmd_issue.sh` when closing or aborting (`aapp issue abort`) issues located in `.offline/`.
- [ ] Task 2.5: Update `lib/cmd_status.sh` to observe `.offline/` and print the offline briefing pillar.
- [ ] Task 2.6: Update `templates/blast-radius-guard.sh` and `templates/aapp-pre-commit` to authorize `.offline/**` and prevent push leakage.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify edge cases.
- [ ] Task 3.2: Update user-facing documentation in `MANUAL.md` (`aapp offline` commands, offset config, local lifecycle).
- [ ] Task 3.3: Incorporate P-75 architecture and codemap entries into group P-72's Architecture and Codemap sections once P-75 is settled.
- [ ] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 3.5: Log every finding outside Target Files as an issue (`aapp refine issues`).

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `lib/cmd_offline.sh` -> CLI ingress and subcommands for `aapp offline` (`mount`, `unmount`, `status`, `sync`).
- [ ] `lib/aapp-lib.sh` -> `.offline` ledgers as a read source; writers pointed at `.offline/`; relink of plan references.
- [ ] `lib/cmd_issue.sh` -> The offline path at the `issue_provider` failure point: modes, staging, the outbox; local archiving.
- [ ] `aapp` -> Route the `offline` verb.
- [ ] `lib/verbs.tsv` -> Register the `offline` verb.
- [ ] `NEW FILE` -> `lib/docs/verbs/offline.md` -> Verb contract.
- [ ] `lib/cmd_status.sh` -> Context recovery briefing inspection of `.offline/`.
- [ ] `lib/cmd_sync.sh` -> `push` and `sync` refuse `offline` in `aapp.syncWorktrees`.
- [ ] `lib/plan_resolver.sh` -> Offset calculation and `aapp.offlineIdOffset` config resolution, for issue ids and plan ids.
- [ ] `lib/cmd_plan.sh` -> `draft` takes a temporary plan id and writes to `.offline/current/` when the `aapp-planid` provider is unreachable; the sync gives a draft its real id, renames its file and rewrites references.
- [ ] `templates/blast-radius-guard.sh` -> Worktree path authorization.
- [ ] `templates/aapp-pre-commit` -> Hook leak protection against `.offline`.
- [ ] `MANUAL.md` -> User documentation for offline workflows and configuration.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `NEW FILE` -> `tests/verbs/offline.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/blast-radius-guard` -> Generated hook runtime; edit template instead.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Offline triggering and plugin governance? → RESOLVED (developer, 2026-10-11): 3-tier governance with global timeout.** (1) Smart fallback default (try plugin first, guarded by global `aapp.pluginTimeout` default 10s, fall back to `.offline` on failure/timeout if `offlineEnabled=true`). (2) Zero-latency `aapp.offlineOnly` (`aapp offline on`) skips network calls entirely when explicitly desired. (3) Strict `aapp.offlineEnabled=false` fails closed.
* [x] **Question 2 — Offline draft plan promotion during sync? → RESOLVED (developer, 2026-10-12):** Offline draft plans in `.offline/current/` automatically land in `.plans/current/` as `🟣 Under Review` during `aapp offline sync`. They remain unexecutable blueprints with locked gates until explicit review and freeze, matching standard draft scaffolding.
* [x] **Question 3 — Plan ids for offline draft plans? → RESOLVED (developer, 2026-10-12):** they mimic issue ids: a temporary id from the same rule while the `aapp-planid` provider is unreachable, replaced by the real id at sync, with the file renamed and references rewritten.
* [x] **Question 4 — Blocking a push of the `offline` branch? → RESOLVED (developer, 2026-10-12):** no pre-push hook. The push verbs work on a named list of worktrees (`plans agents githooks`, or `aapp.syncWorktrees`); `offline` is never in the default list, and `aapp push` / `aapp sync` refuse it when `aapp.syncWorktrees` names it.

---

## 📦 6. Change Log & Refinement History
* **2026-10-12:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-11:** Scaffolded canonical blueprint P-75 for the offline worktree and local lifecycle.
* **2026-10-11:** Completed technical blueprint, high-offset ID allocation (+1000 configurable), local archiving, and sync relinking specifications.
* **2026-10-11:** Integrated 3-tier offline governance (smart fallback, offline-only zero latency, strict compliance) and global plugin timeout (`aapp.pluginTimeout` default 3s); resolved Q1.
* **2026-10-11:** Refined offline ID allocation algorithm: highest offline ID + 1 if offline issues exist, else max canonical + offset for first offline issue.
* **2026-10-12:** Supported offline issue abort (P-76): `.offline/done/000-issues-archive.md` accepts aborted rows (`aborted` commit marker) and sync relocates them.
* **2026-10-12:** Refined P-75: updated ledger module to `lib/aapp-lib.sh`, codified Git commit immutability for closed offline issues during sync, resolved Q2 (automatic promotion to `🟣 Under Review`).
* **2026-10-12:** Incorporated session refinements: former ID resolution lookup in `lib/aapp-lib.sh` (`"logged offline as #<temp>"`), explicit fallback hook into P-74 `issue_provider` wrapper, sole ownership of offline numbering rule, tracker keys support at sync (P-79), `Branch` cell preservation (P-78), offline abort archival (P-76), and deferred P-72 codemap sync.
