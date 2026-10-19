# 🗺️ Plan P-76: Issue Abort
* **Created:** 2026-10-11 | **Last Refined:** 2026-10-11
* **Target Issue / Milestone:** #123
* **Plan ID:** P-76
* **Changelog:** Added: `aapp issue abort <num>` withdraws an issue with its plan or mini plan
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ✅ Done
* **Base:** `a1412c0` (develop)
* **Worktree:** .workspace/P76 (plan/P76-issue-abort)
* **Commits:** `1442c57` (plan/P76-issue-abort), `20e4182` (plan/P76-issue-abort)
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

An issue that turns out wrong, invalid or unwanted has no way out: `aapp issue close <num>` without a commit archives it as fixed at `HEAD`, and whatever was opened for it (its plan, its mini plan) stays in `current/`.

**Goal:** one command, `aapp issue abort <num>`, withdraws the issue together with what was opened for it. The direction is one-way:

- `aapp issue abort <num>` removes the issue and its plan or open mini plan.
- `aapp plan abort <id>` (P-69) and `aapp issue fix <num> abort` remove only the plan or mini plan; the issue stays open, since it may still be valid.

**Built on P-69:** the plan side is `plan abort`, called as it is. This plan starts after P-69 is archived.

---

## 2. Technical Blueprint

### 2.1 CLI Ingress

- **Entrypoint**: `aapp issue abort <num> [reason "<text>"] [keep-branch] [force] [force-cleanup] [confirm]`, a new form of the `issue` verb routed by `cmd_issue`.
- `<num>`: as every `issue` form takes it (`issue_normalize_id`).
- `reason "<text>"`: why the issue is withdrawn (default `Withdrawn`); one line.
- `keep-branch`, `force`, `force-cleanup`, `confirm`: passed to `plan abort` unchanged; they mean nothing when the issue has no plan.
- An unknown token refuses with the usage line.

### 2.2 What Is Attached

Read from the row and from `current/`:

| Attached | How it is found | What `issue abort` does with it |
| :--- | :--- | :--- |
| A promoted plan | Status `🔵 Planned`, cell `[P-<id>](current/…)` | `plan abort <id>` |
| An open mini plan | `current/fix-<num>.md` | dropped, as `aapp issue fix <num> abort` drops it |
| A blocked plan | cell `blocks [P-<id>](…)`, or any plan whose `Blocked On:` lists `#<num>` | not aborted: it resumes (§2.4) |
| A plan already archived | cell link into `aborted/` or `done/` | nothing |

### 2.3 Preflight (nothing changed on refusal, exit 1)

1. `issue_locate`: `#<num>` must be an active row. An archived issue refuses with `already archived`; an unknown one with `not found`.
2. **Mini plan with recorded commits**: refused, as `aapp issue fix <num> abort` refuses it; the fix is on the development branch and the issue is closed with `aapp issue close <num>`.
3. **Promoted plan**: every `plan abort` preflight check (P-69 §2.2) runs for it with the tokens given, including a group plan's confirmation.

### 2.4 Effects

In this order; each step leaves a consistent state, and running the command again finishes an interrupted abort.

1. **The attachment goes**, through its own code and its own commit:
   - mini plan: `_issue_fix_abort` (`fix(abort): #<num>`);
   - plan: `plan abort <id> reason "Issue #<num> aborted: <reason>"` (`plan(abort): archive <id> to aborted/`). The row is then `🟡 Incubated` and links the aborted plan.
2. **The row is withdrawn**: `issue_close_local <num> aborted "<summary>"` moves it to the top of `done/000-issues-archive.md` and prunes its road-map line.
   - *Target Commit / Release* cell: `` `aborted` `` in place of a SHA.
   - *Plan / Resolution Summary* cell: `Aborted: <reason>`, followed by `([P-<id>](../aborted/<file>))` when a plan went with it.
3. **Plans it blocked resume**: `issue_unblock_plans <num>`, then `_issue_reapply_stash <num>` and `sync_state_matrix`, as `close` does.
4. **One commit** `issue(abort): withdraw #<num>` with the paths `close` commits: `ISSUES.md`, the archive, `issues_road_map.md`, the unblocked plans, `state_matrix.md`.
5. **Output**: the archive row, what was removed, which plans resumed or are still blocked.

Steps 2 to 4 are the active branch of `cmd_issue_close` with another commit cell, summary and subject: both call one function. `issue_notify_close` is not called: it reports a fix.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [x] `tests/verbs/issue.abort.sh::test_abort_withdraws_row` -> asserts the row moves to the archive with `aborted` and the reason, its road-map line is gone, in one `issue(abort)` commit
- [x] `tests/verbs/issue.abort.sh::test_abort_refuses_archived_or_unknown` -> asserts an archived or unknown id is refused and nothing changes
- [x] `tests/verbs/issue.abort.sh::test_abort_takes_promoted_plan` -> asserts the plan lands in `aborted/` with its ledger row and the archive row links it
- [x] `tests/verbs/issue.abort.sh::test_abort_plan_refusal_changes_nothing` -> asserts a dirty plan worktree refuses and the issue is still `🔵 Planned`
- [x] `tests/verbs/issue.abort.sh::test_abort_group_plan_needs_confirm` -> asserts an issue whose plan is a group plan is refused without `confirm`
- [x] `tests/verbs/issue.abort.sh::test_abort_drops_mini_plan` -> asserts `current/fix-<num>.md` is gone and the buffer restored
- [x] `tests/verbs/issue.abort.sh::test_abort_refuses_mini_plan_with_commits` -> asserts a fix with recorded commits is refused and points to `issue close`
- [x] `tests/verbs/issue.abort.sh::test_abort_unblocks_plans` -> asserts a plan blocked on the issue returns to its recorded status and is not aborted
- [x] `tests/verbs/issue.abort.sh::test_abort_rerun_finishes` -> asserts after the plan is aborted and the row left open, a second run withdraws the row
- [x] `tests/verbs/issue.abort.sh::test_fix_abort_keeps_issue` -> asserts `issue fix <num> abort` still leaves the issue active

### Phase 1: Tests First (red)
- [x] Task 1.1: Write `tests/verbs/issue.abort.sh` with the Required Tests; all fail.

### Phase 2: Core Implementation
- [x] Task 2.1: One archive function for `close` and `abort` (§2.4 steps 2 to 4); `cmd_issue_close` calls it.
- [x] Task 2.2: `cmd_issue_abort`: tokens, attachment lookup, preflight (§2.1 to §2.3).
- [x] Task 2.3: Attachment step: mini plan drop, `plan abort` call (§2.4 step 1).
- [x] Task 2.4: Route `abort` in `cmd_issue`; usage lines.

### Phase 3: Verification & Documentation
- [x] Task 3.1: Run the kit suites; the Required Tests pass.
- [x] Task 3.2: `abort` form in the `issue` verb contract `lib/docs/verbs/issue.md`.
- [x] Task 3.3: `MANUAL.md`, `CHEATSHEET.md` and `templates/AGENTS.md`.
- [x] Task 3.4: `ARCHITECTURE.md` and `.agents/CODEMAP.md`.
- [x] Task 3.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_issue.sh` -> `cmd_issue_abort`; the archive function shared with `close`; route and usage.
- [ ] `lib/docs/verbs/issue.md` -> `abort` form in the `issue` verb contract.
- [ ] `NEW FILE` -> `tests/verbs/issue.abort.sh` -> `issue` verb suite part.
- [ ] `templates/AGENTS.md` -> Withdrawing an issue; which abort removes what.
- [ ] `MANUAL.md` -> `aapp issue abort`; the archive's `aborted` rows.
- [ ] `CHEATSHEET.md` -> `aapp issue abort` row.
- [ ] `ARCHITECTURE.md` -> Issue withdrawal in the issue lifecycle.
- [ ] `.agents/CODEMAP.md` -> `cmd_issue_abort` and the shared archive function.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit`.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/verbs/issue.abort.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_plan.sh` -> `plan abort` is called as P-69 ships it.
- [ ] `lib/planning_health.sh` -> No reader parses the archive's commit cell as a SHA.
- [ ] `lib/verbs.tsv` -> No new verb.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-12:** Plan implementation completed and archived to done/.
* **2026-10-12:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-11:** Scaffolded from #123; blueprint written on top of P-69's `plan abort`.
