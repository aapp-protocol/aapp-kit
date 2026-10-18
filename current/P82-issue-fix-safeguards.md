# 🗺️ Plan P-82: Issue Fix Safeguards
* **Created:** 2026-10-12 | **Last Refined:** 2026-10-12
* **Target Issue / Milestone:** none
* **Plan ID:** P-82
* **Changelog:** Changed: an issue fix is held to 3 files and 25 lines (configurable) and to its declared files; plans in development are named (P-82)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `2947af4` (develop)
* **Worktree:** .workspace/P82 (plan/P82-issue-fix-safeguards)
* **Commits:** `bf8f505` (plan/P82-issue-fix-safeguards)
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
An issue fix is a small, separate change: one issue, one commit (P-85). Nothing measures "small" today, and nothing holds a fix to the files its issue names:

- **No size limit.** A fix may grow to any number of files and lines. An issue then becomes a way around a plan: an agent can carry a refactor, or cover its own mistakes, through `aapp issue fix` without a frozen design or a locked Blast Radius.
- **The scope widens silently.** A fix's files come from the issue row's Location; `aapp issue fix <n> file <path>` adds any file, with no reason recorded.
- **No signal when a fix touches a plan's files.** A plan in development that lists a fixed file learns of it at `close` ("P-xx also lists <file>") or at its next rebase.
- **The agent rules send a plan's own fallout to the issue lane.** "Non-blocking (a bug, gap or stale text, including one outside your Target Files): log it" covers what the plan's own change caused. That work belongs to the plan.

This plan makes an issue fix small by measure, declared before it is touched, and visible to the plans it meets, and makes the agent rules tell plan work from issues.

---

## 2. Technical Blueprint
1. **Limits, checked at `close` before anything lands.** The fix's diff against the point where it started (its merge base with the issue's branch) gives the number of files changed and the lines changed (added plus deleted, tests included). Above `aapp.fixMaxFiles` (default 3) or `aapp.fixMaxLines` (default 25), `close` refuses, nothing lands, and the message names both numbers and the way on: `aapp issue fix <n> abort`, then `aapp draft <slug> issue <n>`. A value of `0` turns that limit off.
2. **Every file declared before it is touched.** The row's Location is the scope known before the fix starts. A file beyond it is declared with a reason: `aapp issue fix <n> file <path> "<why>"` (the reason is required for a file outside the row), recorded in the mini plan as `- [ ] \`<path>\` -> <why>` in one commit `fix(files): #<n>`, and sent to the issue as a note (`file <path>: <why>`). At `close`, a changed file that is neither in the row's Location nor declared refuses the landing, naming it. The guard and the pre-commit hook already confine the fix's commits to the mini plan's files; this is the check of record.
3. **Collision notice.** At `fix`, and at `fix <n> file`, for each plan ⚡ In Development whose Target Files list one of the fix's files: `ℹ️  P-xx in development also lists <file>; it rebases over this fix.` Not counted: a plan that is BLOCKED (the plan a hotfix blocks among them: its own hotfix is always allowed). `aapp.fixCollision refuse` turns the notice into a refusal, nothing written; the bare token `force` lets one fix through.
4. **Protected files.** A file the guard protects (Guard Section 2: `.githooks/*`, `.agents/skills/aapp-*`, `.claude/settings*`, …) is never a fix's file. Pair 5 of the planning health already checks mini plans' Target Files; a test pins that `fix … file` of such a path is refused with nothing written.
5. **Agent rules: plan work and issues apart** (`templates/AGENTS.md` Issue Escape Triage, the start skill):
   - caused by the plan's change, or left undone by it, even outside its Target Files: plan work. Stop, tell the human, amend the plan with their OK;
   - unrelated to the plan's change: log it as an issue; if it blocks the plan, `aapp issue hotfix`, also when it is in the plan's own files: the fix gets its own commit, apart from the plan's work;
   - a fix stays within its limits; a fix that outgrows them is promoted to a plan, never split across issues.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`. A fix open when this lands is closed under the new checks.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [x] `tests/verbs/issue.limits.sh::test_close_refuses_over_file_limit` -> asserts a fix of 4 changed files is refused at `close` with both numbers and the promotion commands; nothing lands, the issue stays open
- [x] `tests/verbs/issue.limits.sh::test_close_refuses_over_line_limit` -> asserts a fix of 30 changed lines in one file is refused the same way
- [x] `tests/verbs/issue.limits.sh::test_limits_are_configurable` -> asserts `aapp.fixMaxFiles` and `aapp.fixMaxLines` move the limits, and `0` turns one off
- [x] `tests/verbs/issue.limits.sh::test_added_file_needs_a_reason` -> asserts `fix <n> file <path>` outside the row is refused without a reason, nothing written; with one, the mini plan records the file and its reason in one commit and the issue gets the note
- [x] `tests/verbs/issue.limits.sh::test_close_refuses_undeclared_file` -> asserts a changed file neither in the row nor declared refuses `close`, naming it
- [x] `tests/verbs/issue.limits.sh::test_collision_notice` -> asserts `fix` names a plan in development that lists one of its files, and opens
- [x] `tests/verbs/issue.limits.sh::test_collision_refuse_setting` -> asserts `aapp.fixCollision refuse` refuses with nothing written, and `force` opens the fix
- [x] `tests/verbs/issue.limits.sh::test_blocked_plan_is_no_collision` -> asserts the plan a hotfix blocks, listing the hotfix's file, neither warns nor refuses
- [x] `tests/verbs/issue.limits.sh::test_protected_file_refused` -> asserts `fix <n> file .githooks/pre-commit "<why>"` is refused with nothing written

### ♻️ Existing Tests Changed or Retired
> Tests that exist today and assert behaviour this plan changes. Each is rewritten or removed in the same commit as the change, with its contract line.
- Tests that add a file outside the row with `fix <n> file <path>` (`tests/verbs/issue.sh`, `tests/verbs/issue.branchplugin.sh`, `tests/verbs/issue.fixes.sh`): given a reason.

### Phase 1: Tests First (red)
- [x] Task 1.1: Write `tests/verbs/issue.limits.sh`; confirm red.

### Phase 2: Core Implementation
- [x] Task 2.1: The limits at `close`, with the two settings.
- [x] Task 2.2: Declared files: the reason at `fix <n> file`, the note, the check at `close`.
- [x] Task 2.3: The collision notice, `aapp.fixCollision` and `force`.
- [x] Task 2.4: The agent rules and the skills.

### Phase 3: Verification & Documentation
- [x] Task 3.1: Run automated test suites and verify edge cases.
- [x] Task 3.2: Update `MANUAL.md` (fix flow, settings table), `CHEATSHEET.md`, the issue contract, `templates/AGENTS.md`, the fix and start skills.
- [x] Task 3.3: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md`.
- [x] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [x] Task 3.5: Fallout of this plan outside its Target Files: stop and amend the plan with the human's OK; an unrelated finding is logged as an issue.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_issue.sh` -> Limits and the undeclared-file check at `close`; the reason and note at `fix <n> file`; the collision notice and setting.
- [ ] `lib/docs/verbs/issue.md` -> Contract.
- [ ] `templates/AGENTS.md` -> Plan work vs issues; a fix's limits and declared files.
- [ ] `templates/skills/aapp-fix/SKILL.md` -> Limits, declaring a file with its reason, promoting a fix that outgrows them.
- [ ] `templates/skills/aapp-start/SKILL.md` -> A plan's own fallout is plan work.
- [ ] `MANUAL.md` -> Issue fix flow; settings `aapp.fixMaxFiles`, `aapp.fixMaxLines`, `aapp.fixCollision`.
- [ ] `CHEATSHEET.md` -> `fix <n> file <path> "<why>"`, `force`, the three settings.
- [ ] `ARCHITECTURE.md` -> An issue fix is small by measure.
- [ ] `tests/verbs/issue.sh` -> Existing tests given a reason (§3).
- [ ] `tests/verbs/issue.branchplugin.sh` -> Existing tests given a reason (§3).
- [ ] `tests/verbs/issue.fixes.sh` -> Existing tests given a reason (§3).

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `NEW FILE` -> `tests/verbs/issue.limits.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> The guard already confines a fix to its mini plan's files.
- [ ] `lib/planning_health.sh` -> Pair 5 already refuses protected files in a mini plan.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — Collision at `fix`: refuse or warn? → RESOLVED (developer, 2026-10-15):** a notice by default; a setting turns it into a refusal, with an override.
* [x] **Question 2 — Start after group P-72? → RESOLVED (developer, 2026-10-15):** P-72 has landed.
* [x] **Question 3 — The size of a fix. → RESOLVED (developer, 2026-10-15):** at most 3 files and 25 changed lines in all, both configurable; above, a plan.
* [x] **Question 4 — A plan's own fallout. → RESOLVED (developer, 2026-10-15):** what the plan's change caused or left undone is plan work, amended into the plan with the human's OK; an unrelated bug is logged, and a blocking one is a hotfix even in the plan's own files, because the fix gets its own commit.
* [x] **Question 5 — Where a declared file is recorded. → RESOLVED (developer, 2026-10-18):** in the committed mini plan with its reason, and mirrored to the issue as a note (mini plan is the trusted Git record checked at `close`).
* [x] **Question 6 — What counts toward the line limit. → RESOLVED (developer, 2026-10-18):** added plus deleted lines, tests included, without contract lines (standard git diff additions + deletions across the fix files).
* [x] **Question 7 — Does a declared file still need a person's `[y/N]`? → RESOLVED (developer, 2026-10-18):** no interactive `[y/N]` prompt; the mandatory reason, issue note, and file/line limits replace it.

---

## 📦 6. Change Log & Refinement History
* **2026-10-18:** Plan activated into ⚡ In Development via start.
* **2026-10-18:** Plan locked and frozen into 🔷 Frozen via freeze.
*Tracks how the plan evolved across sessions.*
* **2026-10-13:** Drafted.
