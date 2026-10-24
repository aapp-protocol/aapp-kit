# 🗺️ Plan P-119: Perl Plan Lifecycle
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-24
* **Target Issue / Milestone:** none
* **Plan ID:** P-119
* **Changelog:** Changed: Port plan lifecycle verbs (`draft`, `refine`, `tdd`, `freeze`, `start`, `freeze-start`, `done`, `active`, and `plan` subverbs) to `AAPP::Plan` and `AAPP::Cmd::Plan` with structured log event telemetry
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-111
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
Plan `P-119` is the seventh member of group `P-111` (*Perl Port Of The Kit*). It ports the entire Plan Lane (`lib/cmd_plan.sh`, 4,495 lines — the largest file in the repository) and group documentation stamper/applier (`lib/group_docs.sh`, 139 lines) into `lib/AAPP/GroupDocs.pm`, `lib/AAPP/Plan.pm`, and `lib/AAPP/Cmd/Plan.pm`, covering `draft`, `refine`, `tdd`, `freeze`, `start`, `freeze-start`, `done`, `active`, and `plan` (`conflict-check`, `conflict-free`, `abort`).

In bash, every lifecycle transition (`draft -> refine -> tdd -> freeze -> start -> done`) re-runs multi-pass `awk` over `state_matrix.md`, `ISSUES.md`, and every `.plans/current/P*.md` file, and `cmd_plan.sh` embeds the entire worktree (`_wt_*`), squash (`_sq_*`), and lock-based parent branch integration (`_ig_*`) engines. In Perl, `AAPP::GroupDocs`, `AAPP::Plan`, and `AAPP::Cmd::Plan` mutate the parsed plan AST and `state_matrix.md` rows in memory via `AAPP::State`, run `AAPP::Health` in-process, and commit `.plans` atomically via `AAPP::CommitEngine`.

**Strict Tests-vs-Code Boundary:** This plan touches **only** kit code (`lib/AAPP/GroupDocs.pm`, `lib/AAPP/Plan.pm`, `lib/AAPP/Cmd/Plan.pm`, `lib/cmd_plan.sh`, `lib/group_docs.sh`, `aapp`) plus switching `t/core/group_docs.t` and `t/core/integrate.t` from bash `source` wrappers to direct `AAPP::GroupDocs` and `AAPP::Plan` calls per `P-111`'s core-wrapper rule.

**Strict Implementation References (`D7`):**
- **Logging Events Spec (§4.5 `plan` lifecycle verbs):** `.plans/pickup/perl-port-logging-events-spec.md`
- **Tabular Verification Matrix (§3.5 `plan` lifecycle verbs):** `.plans/pickup/perl-port-test-matrix-tabular-check.md`
- **Single Prepared Repository Schema (Epoch E5, Actions A051–A069):** `.plans/pickup/perl-port-single-repo-schema.md`

---

## 2. Technical Blueprint

### 2.1 `AAPP::GroupDocs` (`lib/AAPP/GroupDocs.pm`) — `lib/group_docs.sh` (139 lines)
Ports `lib/group_docs.sh`:
- Parses `## Architecture & Codemap` (`### ARCHITECTURE.md` and `### CODEMAP.md` fenced with ` ````markdown ` ... ` ```` `).
- `group_docs_stamp($plan_file)`: computes SHA-256 of each target `## <Heading>` section in `ARCHITECTURE.md` and `.agents/CODEMAP.md` via `Digest::SHA::sha256_hex` and stamps `<!-- aapp-base: <sha256> -->` above each ```` fence on `aapp refine`.
- `group_docs_check($plan_file)`: verifies recorded `<!-- aapp-base: <sha256> -->` comments against live `ARCHITECTURE.md` and `.agents/CODEMAP.md` on `freeze` and `done`.
- `group_docs_apply($plan_file)`: replaces matching `## <Heading>` sections in `ARCHITECTURE.md` and `.agents/CODEMAP.md` when closing a group plan via `aapp done`.

### 2.2 `AAPP::Plan` (`lib/AAPP/Plan.pm`) — Worktree, Squash, Integration & Conflict Engine (`lib/cmd_plan.sh`)
Provides shared engines across plan lifecycle verbs and `aapp commit land` (`P-120`):
- **Plan ID allocation & scaffolding**: allocates next `P-<num>` via `aapp-planid` plugin or `git config aapp.planId` (seeded on first use from `.plans/current/P*.md`, `.plans/done/000-archive-ledger.md`, and `.plans/aborted/000-aborted-ledger.md`), renders `templates/plan-template.md`, `templates/group-template.md` (`* **Members:**`), and `templates/amendments-template.md` (`P<group+1>-<slug>-amendments.md`).
- **Worktree Engine (`_wt_*`)**:
  - Creates, inspects, and removes isolated plan worktrees at `.workspace/P<num>` on branch `plan/P<num>-<slug>` (configurable via `aapp.planWorktreePath` default `.workspace/{id}` and `aapp.planBranch` default `plan/{id}-{slug}`), group integration branches (`group/P<num>-<slug>`), and quarantines dirty worktrees on failure (`_wt_quarantine`).
  - Manages active plan pointer buffer `$(git rev-parse --git-path aapp_active_plan)` and previous pointer `aapp_active_plan.prev`.
- **Squash Engine (`_sq_*`)**:
  - Squashes multi-commit plan branches (`_sq_squash_plan_branch`) into a single cohesive commit while preserving semantic AI trailers and `refs/notes/ai` / `refs/notes/commits`.
- **Parent-Locked Integration Engine (`_ig_*` — also called by `aapp commit land` in `P-120`)**:
  - `_ig_preflight`: verifies clean worktree, recorded commits, and target branch state.
  - `_ig_lock_acquire` / `_ig_lock_release`: acquires parent integration lock ref `refs/heads/integrate/<parent>`.
  - Auto-rebases onto target branch when `aapp.autoRebase` is enabled (`_ig_rebase`), runs pre-integration hook (`aapp-pre-integrate`), and performs headless CAS fast-forward (`git update-ref` / `git fetch . <src>:<dst>`) or checkout merge when target is checked out.
- **Blast Radius Overlap & Conflict Matrix (`conflict_check` / `conflict_free`)**:
  - Compares `### 📂 Target Files` across concurrent plans in `.plans/current/P*.md` to detect overlapping files and compute conflict-free execution sets.

### 2.3 `AAPP::Cmd::Plan` (`lib/AAPP/Cmd/Plan.pm`) — Plan Lifecycle Verb Handlers (`lib/cmd_plan.sh`, 4,495 lines)
Ports all plan lifecycle verbs from `lib/cmd_plan.sh`, keeping exact behavior, arguments, failure modes, and side effects defined in `aapp help <verb> full` and `lib/docs/verbs/<verb>.md` under the unchanged bash verb suites (`tests/verbs/*.sh`; their Perl files come after the ports, P-134):
- **`draft`** (`aapp help draft full`, `lib/docs/verbs/draft.md`): normal plan, promoted issue plan, group plan + companion amendments plan, and group member plan scaffolding, `.plans/state_matrix.md` registration, and `plan(draft):` commit.
- **`refine`** (`aapp help refine full`, `lib/docs/verbs/refine.md`): plan refinement (including `slug`, `blocked`, `unblocked`, `closes`, `group`, and amendments forms `request`, `approve`, `refuse`, `file`, `decision`), cross-checkout ownership check, `AAPP::Health` check, `AAPP::GroupDocs::group_docs_stamp`, plus `refine pickup` and `refine issues` (including `note` and `branch`).
- **`tdd`** (`aapp help tdd full`, `lib/docs/verbs/tdd.md`): §3 failure-first test identifier and §4 test file validation and `plan(tdd):` commit.
- **`freeze`** (`aapp help freeze full`, `lib/docs/verbs/freeze.md`): open-questions, `AAPP::Health` Pairs 1–6, `AAPP::GroupDocs::group_docs_check`, and TDD gate verification, Blast Radius lock, Greenlight Zone transition in `.plans/state_matrix.md`, and `plan(freeze):` commit.
- **`start` and `freeze-start`** (`aapp help start full`, `aapp help freeze-start full`, `lib/docs/verbs/start.md`, `lib/docs/verbs/freeze-start.md`): pause check, `⚡ In Development` transition, mode/base header recording, `.workspace/P<num>` worktree or group branch provisioning (`_wt_*`), and `aapp_active_plan` binding.
- **`done`** (`aapp help done full`, `lib/docs/verbs/done.md`): task checkbox, recorded commit, and changelog verification, `_sq_*` squash and `_ig_*` parent-locked integration, `AAPP::GroupDocs::group_docs_apply` on group completion, archival to `.plans/done/YYYY/MM/` and `.plans/done/000-archive-ledger.md`, `.plans/state_matrix.md` cleanup, promoted Target Issue closure (`AAPP::Issue`), dependent plan unblocking, and worktree/pointer teardown.
- **`active`** (`aapp help active full`, `lib/docs/verbs/active.md`): active plan pointer inspection, switching, `swap` (`aapp_active_plan.prev`), and `clear`.
- **`plan`** (`aapp help plan full`, `lib/docs/verbs/plan.md`): plan resolution/query, `conflict-check`, `conflict-free`, and `abort` (archiving to `.plans/aborted/YYYY/MM/` and `.plans/aborted/000-aborted-ledger.md` and reverting promoted issues).
- **Amendments (P-129):** `refine` (`request … for <plan-id>`, `approve` without the amendments member's Target Files, auto-approval), `done` (closing the requester's requests, recording its own amendment commits by their `Amendment: R<n>` trailer) and `plan abort` (withdrawing them) port P-129's bash behaviour, with the owner's record written in current and archived plans of the same group.

### 2.4 Logging Telemetry (`AAPP::Logger::log_event`)
Per `.plans/pickup/perl-port-logging-events-spec.md` §4.5, all plan lifecycle actions emit structured telemetry to `.git/aapp.log`:
- `post-draft`: `plan_id => $id`, `status => $status`, `group => $grp`.
- `post-refine`: `plan_id => $id`, `subcommand => $sub`, `status => $status`.
- `post-tdd`: `plan_id => $id`, `tests_count => $n`.
- `post-freeze`: `plan_id => $id`, `status => 'frozen'`.
- `post-start`: `plan_id => $id`, `worktree => $wt`, `branch => $branch`.
- `post-freeze-start`: `plan_id => $id`, `worktree => $wt`, `branch => $branch`.
- `post-done`: `plan_id => $id`, `integrate => $mode`, `parent_branch => $parent`, `worktree_removed => 0|1`.
- `post-active`: `plan_id => $id`, `subcommand => $sub`.
- `post-plan-conflict-check`: `conflicts_count => $n`.
- `post-plan-conflict-free`: `conflict_free_plans => \@ids`.
- `post-plan-abort`: `plan_id => $id`, `action => 'abort'`.
- `group.docs`: `action => 'stamp'|'apply'`, `key => $key`, `sections => \@sections`.

### 🔄 Migration & Compatibility Strategy
- **Transitional Coexistence (`P-119` → `P-122`):** `lib/cmd_commit.sh` (`aapp commit land`, ported in `P-120`) calls integration helpers from `lib/cmd_plan.sh` until `P-120` switches `commit` to `AAPP::Cmd::Commit` and `AAPP::Plan`. Keep `lib/cmd_plan.sh` intact for `cmd_commit.sh` until `P-120` completes, then delete `lib/cmd_plan.sh` and `lib/group_docs.sh` in `P-122`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: GroupDocs & Shared Plan Engine (`AAPP::GroupDocs`, `AAPP::Plan`)
- [ ] Task 1.1: Implement `lib/AAPP/GroupDocs.pm` (`lib/group_docs.sh`) with `group.docs` event telemetry, and switch `t/core/group_docs.t` to call `AAPP::GroupDocs` directly without bash `source` wrappers.
- [ ] Task 1.2: Implement `lib/AAPP/Plan.pm` covering counter allocation (`aapp.planId` / `aapp-planid`), template rendering (`plan-template.md`, `group-template.md`, `amendments-template.md`), `_wt_*` worktree management, `_sq_*` branch squashing, `_ig_*` parent-locked integration, and conflict analysis, and switch `t/core/integrate.t` to call `AAPP::Plan` directly.

### Phase 2: Plan Lifecycle Verb Handlers (`AAPP::Cmd::Plan`) with Event Telemetry
- [ ] Task 2.1: Implement `draft`, `refine`, `tdd`, `freeze`, `start`, and `freeze-start` in `lib/AAPP/Cmd/Plan.pm` with `post-*` event telemetry.
- [ ] Task 2.2: Implement `done`, `active`, and `plan` (`conflict-check`, `conflict-free`, `abort`) in `lib/AAPP/Cmd/Plan.pm` with `post-*` event telemetry, and wire all nine verbs (`draft`, `refine`, `tdd`, `freeze`, `start`, `freeze-start`, `done`, `active`, `plan`) in `./aapp`.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: `./aapp test strict quiet` (the bash suites, the lifecycle verbs' `tests/verbs/*.sh` among them) and `t/test-run strict quiet` (`t/core`, with `group_docs.t` and `integrate.t`) green.
- [ ] Task 3.2: Verify `CHANGELOG.md` updates and run `perl -c` syntax checks on all new `.pm` files.
- [ ] Task 3.3: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/AAPP/GroupDocs.pm` -> Group `ARCHITECTURE.md` and `CODEMAP.md` base hash stamping, checking, and replacement with `group.docs` telemetry.
- [ ] `NEW FILE` -> `lib/AAPP/Plan.pm` -> Shared plan scaffolding, worktree (`_wt_*`), squash (`_sq_*`), parent-locked integration (`_ig_*`), and conflict analysis engine.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Plan.pm` -> `draft`, `refine`, `tdd`, `freeze`, `start`, `freeze-start`, `done`, `active`, and `plan` (`conflict-check`, `conflict-free`, `abort`) verb handlers with `post-*` telemetry.
- [ ] `aapp` -> Dispatch `draft`, `refine`, `tdd`, `freeze`, `start`, `freeze-start`, `done`, `active`, and `plan` to `AAPP::Cmd::Plan`.
- [ ] `lib/cmd_plan.sh` -> Retained for `lib/cmd_commit.sh` callers until `P-120` or delegated to `AAPP::Plan` until `P-122`.
- [ ] `lib/group_docs.sh` -> Transitional shim delegating to `AAPP::GroupDocs` until `P-122`.
- [ ] `t/core/group_docs.t` -> Switch from bash `source` wrappers to direct `AAPP::GroupDocs` calls.
- [ ] `t/core/integrate.t` -> Switch from bash `source` wrappers to direct `AAPP::Plan` calls.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/Tests.pm` -> The test engine (P-126) and every test file in `t/` stay out of bounds during code plans.
- [ ] `lib/docs/` -> Spec contracts in `lib/docs/verbs/*.md` are locked in `P-114`.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-24:** Aligned technical blueprint, logging telemetry (`post-*` lifecycle events, `group.docs`), and execution checklist with `.plans/pickup/perl-port-logging-events-spec.md` and `.plans/pickup/perl-port-test-matrix-tabular-check.md`.
* **2026-10-19:** Plan initialized from `pickup.md` and `.plans/pickup/perl-port-rfc.md`.
* **2026-10-19:** Refined technical blueprint and blast radius per `§5.1.4` to match `lib/cmd_plan.sh` (4,495 lines) and `lib/group_docs.sh` (139 lines) contracts.

