# 🗺️ Plan P-82: Issue Fix Safeguards
* **Created:** 2026-10-12 | **Last Refined:** 2026-10-12
* **Target Issue / Milestone:** none
* **Plan ID:** P-82
* **Changelog:** Changed: an issue fix opens only when no plan in development lists its files, and a file outside the issue's row needs a person's confirmation (P-82)
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
A plan's files are fixed by a person at freeze. An issue fix has no such gate, and it does not look at the plans in development:

- **No collision check when a fix opens.** `aapp issue fix <n>` waits for uncommitted changes in its files in this checkout; the `group` form skips even that. Neither form looks at whether a plan in development lists one of the fix's files. A fix landed on a group's feature branch while a member edits the same file leaves that member unable to fast-forward. The only signal today is a line at `close`: "P-xx also lists <file>".
- **The file list widens without approval.** A fix's files come from the issue row's Location; `aapp issue fix <n> file <path>` adds any file to an open fix. An agent can name files nobody intended to change.

This plan makes a fix start only when it cannot collide, and puts a person in front of a widened file list.

---

## 2. Technical Blueprint
**To be settled when the plan is taken up; the two rules below are the starting point.**

1. **Collision check at open, both forms.** When a plan in development lists one of the fix's files in its Target Files, `issue fix` waits and then refuses, as it does for uncommitted changes, naming the plan and the file. For the `group` form the plans looked at are that group's members; for a fix on the development branch, the plans branched from it.
2. **A person approves a widened file list.** The files named in the issue's row are the fix's scope. `file <path>` naming a file outside it asks `[y/N]` on a terminal and needs the bare token `confirm` without one.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/issue.fixes.sh::test_fix_refuses_file_of_plan_in_development` -> asserts a fix whose file a plan in development lists waits, then refuses, naming the plan and the file
- [ ] `tests/verbs/issue.fixes.sh::test_group_fix_refuses_file_of_member_in_development` -> asserts the same for `fix … group` against the group's member in development
- [ ] `tests/verbs/issue.fixes.sh::test_added_file_needs_confirm` -> asserts `fix <n> file <path>` outside the row's Location refuses without `confirm` when there is no terminal, and adds the file with it

### Phase 1: Tests First (red)
- [ ] Task 1.1: Write the three tests; confirm red.

### Phase 2: Core Implementation
- [ ] Task 2.1: The collision check when a fix opens.
- [ ] Task 2.2: The confirmation for a file outside the issue's row.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify edge cases.
- [ ] Task 3.2: Update `MANUAL.md`, the issue contract, `templates/AGENTS.md` and the fix skill.
- [ ] Task 3.3: Update `.agents/CODEMAP.md`.
- [ ] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 3.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_issue.sh` -> The collision check and the confirmation in `cmd_issue_fix`.
- [ ] `lib/docs/verbs/issue.md` -> Contract.
- [ ] `templates/AGENTS.md` -> A fix's files are the issue's; widening needs a person.
- [ ] `templates/skills/aapp-fix/SKILL.md` -> The same.
- [ ] `MANUAL.md` -> Issue fix flow.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/verbs/issue.fixes.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> The guard already confines a fix to its mini plan's files.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [ ] **Question 1:** Are the two rules of §2 the ones wanted, and does the confirmation apply to every added file or only to the `group` form?
* [ ] **Question 2:** This plan changes `lib/cmd_issue.sh`, which group P-72 rewrites: start it after the group lands?

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-13:** Drafted.
