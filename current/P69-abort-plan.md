# 🗺️ Plan P-69: Lifecycle Plan Abort & Worktree Decommissioning
* **Created:** 2026-10-11 | **Last Refined:** 2026-10-11
* **Target Issue / Milestone:** #118
* **Plan ID:** P-69
* **Changelog:** Added: `aapp plan abort` command to safely decommission in-flight plans, clean worktrees/branches, and archive to .plans/aborted/
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
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal

In AAPP, blueprint lifecycles are currently strictly unidirectional towards `done`:
- Once started (`aapp start`), a plan can only reach `done` (`aapp done <id>`), which gates on tests, integrates commits, and archives the plan to `.plans/done/`.
- While mini-plans have `aapp issue fix <num> abort` to cleanly drop uncommitted issue fixes, full plans have **no verb-driven exit path** when an approach fails, an RFC is rejected, or an architectural pivot renders the blueprint obsolete.
- Developers and agents are left with manual surgery: deleting worktrees, removing branches, hand-editing `.plans/state_matrix.md`, clearing buffers, and manually moving files.

**Goal:** Implement a first-class `aapp plan abort <id>` lifecycle command that safely decommissions any non-done plan, tears down its worktree/branch resources, reverts promoted issues back to `🟡 Incubated`, unlinks group memberships, and moves the blueprint into `.plans/aborted/`.

---

## 2. Technical Blueprint

`plan abort` is `done` without the code: same resolver, same snapshot-and-restore archive commit, same issue and matrix helpers, same worktree record. Every refusal happens before anything changes; the worktree and branch go only after the archive commit has landed.

### 2.1 CLI Ingress & Command Syntax

- **Entrypoint**: `aapp plan abort <id> [reason "<text>"] [keep-branch] [force] [force-cleanup]`, a subcommand of the existing `plan` verb routed by `cmd_plan_switchboard` (beside `conflict-check`); no top-level `abort` verb is registered.
- **Positional `<id>`**: resolved by `resolve_plan_file <id> abort`, so only plans in `.plans/current/` resolve.
- **Bare tokens**:
  - `reason "<text>"`: why the plan is abandoned (default `Abandoned`); one line.
  - `keep-branch`: the plan branch (or a group's feature branch) is kept.
  - `force`: uncommitted work in the plan's worktree is discarded.
  - `force-cleanup`: sensitive ignored files in the plan's worktree are deleted with it (the token `done` uses).
  - `confirm`: a group plan's abort proceeds without the terminal prompt (§2.2).
- An unknown token refuses with the usage line, as `_ig_parse_tokens` does.

### 2.2 Preflight (nothing changed on refusal, exit 1)

1. **Plan kind and place**:
   - Any status in `.plans/current/` is eligible: `🟣 Under Review`, `📝 Refining`, `🔷 Frozen`, `⚡ In Development`, `🟥 BLOCKED`.
   - A plan in `done/` or `aborted/` does not resolve: the resolver's `not found in .plans/current/` is the refusal.
   - A mini plan (`fix-<num>.md`) is refused and pointed to `aapp issue fix <num> abort`.
2. **Not from the worktree it removes**: run from inside the plan's own worktree, abort refuses and names the main checkout (the check `_issue_refuse_in_plan_worktree` makes).
3. **Plan worktree** (`parse_plan_worktree`: the recorded path and branch, never names derived from the slug):
   - any `git status --porcelain` output, tracked or untracked (the test `done` applies), refuses without `force`, listing the files;
   - sensitive ignored files (`check_worktree_ignored_files`) follow `_ig_cleanup`'s rule: copied to the quarantine directory when `aapp.quarantineIgnored` is true, otherwise a refusal without `force-cleanup`.
4. **Group plan** (`aapp_is_group_plan`): the whole group goes (§2.6). Checks 2 and 3 run for every member still in `current/`. Then abort prints what it removes and asks:
   - the members it aborts, each with its recorded commits;
   - the archived members whose work is on the feature branch;
   - the feature branch and its SHA.
   On a terminal (`[ -t 0 ]`) it prompts `[y/N]`; anything but `y` exits 1 with nothing changed. Without a terminal it refuses unless `confirm` is given. A member released beforehand with `aapp refine <id> group none` is not part of the group.
5. **Group member** (`* **Group:** <group>`), aborted on its own: refused once it has recorded commits (`parse_plan_commits`), as `aapp issue fix <num> abort` refuses a fix with commits; implemented member work is finished with `aapp done <id>`. A member without commits aborts like any plan.
6. **Target issue**: `issue_locate` must find `#<n>` in `ISSUES.md` or the issues archive; an archived issue is left alone.

### 2.3 Archive (one commit in the plans worktree)

Taken under `done`'s snapshot (#121): `current/`, both ledgers, `ISSUES.md`, `issues_road_map.md`, `state_matrix.md`.

1. **Move** `current/P<n>-<slug>.md` to `aborted/P<n>-<slug>.md`.
2. **Header**: `* **Status:** ❌ Aborted`, followed by `* **Aborted:** <date> | **Reason:** <reason>` (`write_plan_field`).
3. **Change log**: `* **<date>:** Plan aborted: <reason>` under `## 📦 6. Change Log`.
4. **Ledger** `aborted/000-aborted-ledger.md`, written with its heading and table header when missing; the row goes under the separator line, newest first, `|` escaped, as the archive ledger's:
   `| Date Aborted | Plan ID | Plan File | Target Issue / Milestone | Reason | Commits |`
   `Commits` lists the recorded SHAs (`parse_plan_commits`) or `none`.
5. **Issues**: §2.4.
6. **Group member** (`* **Group:** <group>`): `group_set_member <group> <id> remove`; the group plan joins the commit.
7. **Matrix**: `sync_state_matrix`; the plan has left `current/`, so its row is gone.
8. **Buffers**, as `done` clears them: `ACTIVE_FILE` when it names the plan, and the buffer of the worktree holding it (`find_worktree_holding_plan`).
9. **Commit**: `plans_commit "plan(abort): archive <id> to aborted/"`; the reason stays in the header and the ledger, so the subject never exceeds `aapp.subjectMaxLen`. A failed commit unstages, restores the snapshot and exits 1; no worktree or branch has been touched.

### 2.4 Issues

1. **Target issue** (`* **Target Issue / Milestone:** #<n>`, active row):
   - It is **not closed**. Status goes from `🔵 Planned` back to `🟡 Incubated`.
   - The `Target Plan / Fix` cell keeps the plan link, repointed to the archive: `[P-<id>](aborted/P<n>-<slug>.md)`, a verb-written link the fix-cell check (`check_fix_cells`) already accepts; no note is written.
   - The row edit is the issue module's abort step in `lib/cmd_issue.sh`, the counterpart of `issue_mark_planned`, shared with `aapp issue fix <num> abort`; `plan abort` writes no issue row itself.
   - A hotfix issue promoted to this plan is `Incubated` again, so `issue_queued_blockers` lists it again and the plan it blocks stays blocked.
2. **Other links**: `issue_relink "current/<file>" "aborted/<file>"` repoints every other row and road-map line, including the `blocks [P-<id>](…)` rows of the plan's own hotfix issues.
3. **A `🟥 BLOCKED` plan's hotfix issues** stay open and queued: they are bugs in their own right. In single-checkout mode the work `hotfix` set aside for them is this plan's: its lines leave `aapp_hotfix_stash`, so `issue close` re-applies nothing, and each stash stays in `git stash list`, named in the output.

### 2.5 Teardown (after the archive commit)

A failure here warns with the command to run by hand; the abort stands (as `_ig_cleanup`).

1. **Plan worktree**: the kit links (`.githooks`, `.agents`, `.plans`, `.claude`) are removed, then `git worktree remove --force <path>`; preflight has already cleared or quarantined what it holds.
2. **Plan branch**: `git branch -D <branch>` with a warning naming the branch and its SHA (Question 2); `keep-branch` keeps it and prints `ℹ️  Branch '<branch>' preserved.`
3. **Single-checkout plan** (no `Worktree:`): its commits are on the development branch already and stay there, with its `CHANGELOG.md` entry. Abort reverts nothing: it lists the recorded commits and says so. Uncommitted work in the checkout is not touched.
4. **Group plan**: §2.6.

### 2.6 Group Plan Abort

Aborting a group plan removes the group: its plan, its open members and its code.

1. **Members in `current/`**, whatever their status and commits: each is archived as in §2.3 (own ledger row, reason `Group <id> aborted: <reason>`) and its issues handled as in §2.4. The group plan and all members land in one commit, `plan(abort): archive group <id> to aborted/`, under one snapshot.
2. **Teardown**: each member's worktree and branch as in §2.5; a temporary `.workspace/P<n>` through `_group_done_drop_wt`; a started group's `Feature Branch` is deleted with the work of its archived members. `keep-branch` keeps the feature branch and the member branches.
3. **Archived members** stay in `done/` with their ledger rows and closed issues; the output lists them as plans whose code was removed.
4. `post-abort` fires once per aborted plan, the group last.

### 2.7 Hook & Output

- `post-abort` observer, dispatched after teardown with `plan_id`, `plan_file` (`aborted/<file>`), `reason`, `worktree`, `branch`, `commits`. The dispatcher already runs any `post-*` event as `notify`; the event joins the catalogue (`aapp hooks events`, the `hook-test` list, the registry header).
- Output: the archive path, the ledger, the issue's new state, what was removed or kept.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/plan.abort.sh::test_abort_draft_moves_to_aborted_and_cleans_matrix` -> asserts an Under Review plan lands in `aborted/` as `❌ Aborted` with its reason, and its matrix row is gone
- [ ] `tests/verbs/plan.abort.sh::test_abort_frozen_plan` -> asserts a Frozen plan aborts in one `plan(abort)` commit
- [ ] `tests/verbs/plan.abort.sh::test_abort_writes_ledger_row` -> asserts the ledger is created when missing and gains the row with reason and commits
- [ ] `tests/verbs/plan.abort.sh::test_abort_refuses_mini_plan` -> asserts `fix-<num>` is refused and points to `issue fix <num> abort`
- [ ] `tests/verbs/plan.abort.sh::test_abort_refuses_archived_plan` -> asserts a plan in `done/` or `aborted/` is not found
- [ ] `tests/verbs/plan.abort.sh::test_abort_refuses_dirty_worktree_without_force` -> asserts tracked or untracked changes refuse and nothing changes; `force` proceeds
- [ ] `tests/verbs/plan.abort.sh::test_abort_refuses_sensitive_ignored_files` -> asserts a `.env` in the worktree refuses without `force-cleanup` and is quarantined with `aapp.quarantineIgnored`
- [ ] `tests/verbs/plan.abort.sh::test_abort_refuses_inside_plan_worktree` -> asserts abort run from the plan's worktree refuses
- [ ] `tests/verbs/plan.abort.sh::test_abort_removes_worktree_and_branch` -> asserts the recorded worktree and branch are gone and the warning names the SHA
- [ ] `tests/verbs/plan.abort.sh::test_abort_keep_branch_preserves_ref` -> asserts `keep-branch` leaves the branch
- [ ] `tests/verbs/plan.abort.sh::test_abort_clears_buffers` -> asserts no buffer still names the plan
- [ ] `tests/verbs/plan.abort.sh::test_abort_commit_failure_restores` -> asserts a refused plans commit restores plan, ledgers and matrix and removes no worktree or branch
- [ ] `tests/verbs/plan.abort.sh::test_abort_single_checkout_keeps_commits` -> asserts recorded commits stay on the branch, are listed, and reach the ledger
- [ ] `tests/verbs/plan.abort.sh::test_abort_target_issue_incubated_with_aborted_link` -> asserts the row is `🟡 Incubated`, still active, its cell `[P-<id>](aborted/…)`
- [ ] `tests/verbs/plan.abort.sh::test_abort_relinks_other_issue_rows` -> asserts other rows and road-map lines point at `aborted/`
- [ ] `tests/verbs/plan.abort.sh::test_abort_blocked_plan_drops_stash_record` -> asserts the hotfix issue stays open and its `aapp_hotfix_stash` line is gone while the stash remains
- [ ] `tests/verbs/plan.abort.sh::test_abort_group_member_unlinked` -> asserts the group's `Members` no longer lists the plan
- [ ] `tests/verbs/plan.abort.sh::test_abort_group_member_with_commits_refused` -> asserts a member with recorded commits is refused and nothing changes
- [ ] `tests/verbs/plan.abort.sh::test_abort_group_needs_confirm` -> asserts a group abort without a terminal and without `confirm` is refused, lists what it would remove, and changes nothing
- [ ] `tests/verbs/plan.abort.sh::test_abort_group_aborts_open_members` -> asserts with `confirm` the group and every member in `current/`, with or without commits, land in `aborted/` in one commit, each with a ledger row
- [ ] `tests/verbs/plan.abort.sh::test_abort_group_removes_feature_branch` -> asserts the feature branch and member branches go, or stay with `keep-branch`
- [ ] `tests/verbs/plan.abort.sh::test_abort_group_lists_archived_members` -> asserts archived members stay in `done/` and are named in the output
- [ ] `tests/verbs/plan.abort.sh::test_abort_dispatches_post_abort` -> asserts a registered `post-abort` handler receives the payload

### Phase 1: Tests First (red)
- [ ] Task 1.1: Write `tests/verbs/plan.abort.sh` with the Required Tests; all fail.

### Phase 2: Core Implementation
- [ ] Task 2.1: `cmd_plan_abort()` in `lib/cmd_plan.sh`: tokens, preflight (§2.2).
- [ ] Task 2.2: Route `abort` in `cmd_plan_switchboard` and list it in the switchboard text.
- [ ] Task 2.3: Archive (§2.3): move, header, change log, ledger, matrix, buffers, snapshot-guarded commit.
- [ ] Task 2.4: Issue abort step in `lib/cmd_issue.sh` (`🔵 Planned` -> `🟡 Incubated`, link repointed to `aborted/`), shared by `issue fix <num> abort` and `plan abort`; relink; hotfix stash records (§2.4).
- [ ] Task 2.5: Group member refusal on recorded commits and member unlinking; group plan abort with confirmation (§2.6).
- [ ] Task 2.6: Teardown (§2.5).
- [ ] Task 2.7: `post-abort` dispatch and event catalogue (§2.7).

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run the kit suites; the Required Tests pass.
- [ ] Task 3.2: `plan abort` form in the `plan` verb contract `lib/docs/verbs/plan.md`.
- [ ] Task 3.3: `MANUAL.md`, `CHEATSHEET.md` and the `templates/AGENTS.md` CLI Reference.
- [ ] Task 3.4: `ARCHITECTURE.md` and `.agents/CODEMAP.md`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_plan.sh` -> `cmd_plan_abort`: preflight, archive, teardown; switchboard route.
- [ ] `lib/cmd_issue.sh` -> Issue abort step: status back to Incubated, plan link repointed to `aborted/`; hotfix stash records.
- [ ] `lib/cmd_hook.sh` -> `post-abort` in the events catalogue and the `hook-test` list.
- [ ] `templates/skills/aapp-hooks/registry.tsv` -> `post-abort` in the header's event list.
- [ ] `lib/docs/verbs/plan.md` -> `plan abort` form in the `plan` verb contract.
- [ ] `templates/AGENTS.md` -> `aapp plan abort` in the CLI Reference.
- [ ] `NEW FILE` -> `tests/verbs/plan.abort.sh` -> `plan` verb suite part.
- [ ] `MANUAL.md` -> Abandoning a plan; the aborted ledger; `post-abort`.
- [ ] `CHEATSHEET.md` -> `aapp plan abort` row.
- [ ] `ARCHITECTURE.md` -> Abort in the plan lifecycle.
- [ ] `.agents/CODEMAP.md` -> `cmd_plan_abort` and the issue abort step.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit`.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/verbs/plan.abort.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Core git hooks untouched.
- [ ] `templates/blast-radius-guard.sh` -> Write guard untouched.
- [ ] `lib/planning_health.sh` -> Planning health engine untouched; `check_fix_cells` already accepts a link into `aborted/`.
- [ ] `lib/verbs.tsv` -> No new verb.
- [ ] `lib/hook_dispatcher.sh` -> Runs `post-*` events as `notify` already.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Aborted Ledger Location & Format. → RESOLVED (developer, 2026-10-11): (a) Dedicated .plans/aborted/000-aborted-ledger.md.** Keeps clean architectural separation between completed implementations and abandoned plans, mirroring the directory structure.
* [x] **Question 2 — Branch deletion on unmerged commits. → RESOLVED (developer, 2026-10-11): (a) Warn and delete branch.** In a normal case if the plan is aborted that implies there is no need of the code. A clear diagnostic warning is printed naming the deleted branch SHA. If the developer explicitly wishes to preserve the commits for future reference, `keep-branch` is used.

---

## 📦 6. Change Log & Refinement History
* **2026-10-11:** A group plan's abort removes the whole group (open members, feature branch) after a confirmation.
* **2026-10-11:** A group member with recorded commits is refused.
* **2026-10-11:** Aligned with the code: preflight before any change, `done`'s snapshot commit and helpers, recorded worktree and branch, ignored-file rule, single-checkout, blocked and group cases, hook catalogue, Required Tests.
* **2026-10-11:** Issue side runs through the issue module's abort step; the row keeps the plan link, repointed to `aborted/`.
* **2026-10-11:** Single command form `aapp plan abort <id>`: no top-level `abort` verb, contract in `lib/docs/verbs/plan.md`, tests in the suite part `tests/verbs/plan.abort.sh`.
* **2026-10-11:** Resolved Q1 (dedicated aborted ledger) and Q2 (warn and delete unmerged branch unless keep-branch). Blueprint fully specified.
* **2026-10-11:** Scaffolded from Issue #118 and refined technical blueprint: defined CLI ingress (`aapp abort`), worktree teardown, `.plans/aborted/` archival, issue reversion to Incubated, and group member unlinking.
