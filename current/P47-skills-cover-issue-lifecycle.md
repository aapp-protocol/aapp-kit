# 🗺️ Plan P-47: Skills Cover Issue Lifecycle
* **Created:** 2026-10-02 | **Last Refined:** 2026-10-02
* **Target Issue / Milestone:** None (follow-up to P-32)
* **Plan ID:** P-47
* **Status:** 🟣 Under Review
* **Base:** none
* **Commits:** none
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** ISSUE-00X   <- add this line while BLOCKED, remove it when unblocked -->

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

## 1. Context & Architectural Goal
P-32 shipped `aapp issue` (`next`, `allocate`, `close`, `list`) and made `aapp done` close a plan's Target Issue. The shipped skills were not updated, so an agent that follows them still does the manual steps P-32 removed:

1. **No ID claim.** `aapp-digest` (Issue Lane), `aapp-plan` (defect routing) and `aapp-pause` (logging while paused) say "record it in `ISSUES.md`" without `aapp issue allocate`; AGENTS.md *Issue Escape Triage* omits it too. Agents keep picking IDs by reading the file — the `#77` failure.
2. **No mechanical close.** No skill mentions `aapp issue close`; direct fixes end in hand-moved table rows.
3. **Stale `aapp-done`.** It does not say `done` closes the Target Issue (an agent may relocate the row a second time) nor list the new refusal (`Target issue #N is in neither ledger`).
4. **Contradictory commit rule.** `aapp-digest` and `aapp-tdd` instruct raw `git -C .plans commit`; `aapp-done`, `aapp-freeze` and `aapp-start` forbid raw commits on the plans worktree.
5. **No skill for the `issue` verb**, while every other lifecycle verb has one.

**Goal:** the skills are the single, complete behaviour script for agents. Every issue action goes through `aapp issue` / `aapp done`, the commit rule reads the same everywhere, and a test fails when a daily verb has no skill coverage, so this drift cannot recur silently.

**Constraint:** `.agents/skills/aapp-*` is Guard Section 2 self-protected and must not appear in Target Files (Pair 5). Edits go to `templates/skills/`; `aapp init` (`sync_skills` in `lib/cmd_init.sh`) rebuilds every `aapp-*` skill from there and bridges new ones into `.claude/skills/`.

---

## 2. Technical Blueprint
### 2.1 New skill: `templates/skills/aapp-issue/SKILL.md`
Same shape as the other verb skills (Step 1 run the verb, Step 2 fail-closed diagnostics, Step 3 report):
- **Log an issue:** `aapp issue allocate` → write the row with that ID → road map entry → `issue(triage):` commit. Never derive an ID from the files.
- **Close a direct fix:** `aapp issue close <num> [sha <sha>] [summary "<text>"]`; bare number (an unquoted `#79` is a shell comment). Never hand-move rows.
- **Plan-targeted issues:** closed by `aapp done`; do not close them separately.
- **Read the backlog:** `aapp issue list [<n> | all]`.
- Diagnostics: corrupt counter, no ledgers and no provider (install `aapp-issue-tracker`), unknown id.

### 2.2 Existing skills
| Skill | Change |
| :--- | :--- |
| `aapp-digest` | Issue Lane: claim the ID with `aapp issue allocate`; point to `/aapp-issue` |
| `aapp-plan` | Defect routing: same |
| `aapp-pause` | Logging defects while paused: claim with `aapp issue allocate` |
| `aapp-done` | Step 2 adds the dangling-Target-Issue refusal; Step 3 states the Target Issue is archived and pruned in the same commit — do not relocate it again |
| `aapp-status` | Full issue backlog: `aapp issue list` |
| `aapp-digest`, `aapp-tdd` | Commit wording follows the rule settled in Q1 |

### 2.3 AGENTS.md (`templates/AGENTS.md`, `.agents/AGENTS.md`)
- *Issue Escape Triage*: log with `aapp issue allocate`.
- Commit-convention examples: `#<num>` instead of `ISSUE-00X`.
- The plans-worktree commit rule, as settled in Q1.

### 2.4 Coverage guard (test)
`tests/verb_contracts_test.sh` gains `test_daily_verbs_have_skill_coverage`: every `daily` verb in `lib/verbs.tsv` is named (`aapp <verb>`) in at least one `templates/skills/*/SKILL.md`. Scope of the allow-list per Q2.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`
- Adopters pick up the updated skills on their next `aapp init` (`sync_skills` overwrites `aapp-*` skills; `aapp-hooks/registry.tsv` is preserved).

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Coverage Guard (red first)
- [ ] Task 1.1: Add `test_daily_verbs_have_skill_coverage` to `tests/verb_contracts_test.sh`; confirm it fails on `issue` (and on the verbs Q2 keeps in scope).

### Phase 2: Skills
- [ ] Task 2.1: Author `templates/skills/aapp-issue/SKILL.md` (§2.1).
- [ ] Task 2.2: Update `aapp-digest`, `aapp-plan`, `aapp-pause`, `aapp-done`, `aapp-status`, `aapp-tdd` (§2.2).
- [ ] Task 2.3: Apply the Q1 commit rule consistently across all skills.

### Phase 3: Protocol Text
- [ ] Task 3.1: Update `templates/AGENTS.md` and `.agents/AGENTS.md` (§2.3).

### Phase 4: Verification & Documentation
- [ ] Task 4.1: Run `./aapp test strict quiet`; the coverage guard passes.
- [ ] Task 4.2: In a sandbox, `aapp init` installs `aapp-issue` into `.agents/skills/` and bridges it into `.claude/skills/`.
- [ ] Task 4.3: `.agents/CODEMAP.md` lists the new skill; MANUAL skill list if one exists.
- [ ] Task 4.4: `CHANGELOG.md` under `## [Unreleased]`.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `templates/skills/aapp-issue/SKILL.md` -> Skill for `aapp issue` (log, close, list).
- [ ] `templates/skills/aapp-digest/SKILL.md` -> Issue Lane claims IDs via `aapp issue allocate`; commit rule.
- [ ] `templates/skills/aapp-plan/SKILL.md` -> Defect routing claims IDs via `aapp issue allocate`.
- [ ] `templates/skills/aapp-pause/SKILL.md` -> Paused defect logging claims IDs via `aapp issue allocate`.
- [ ] `templates/skills/aapp-done/SKILL.md` -> Target Issue close and dangling-issue refusal.
- [ ] `templates/skills/aapp-status/SKILL.md` -> Point to `aapp issue list`.
- [ ] `templates/skills/aapp-tdd/SKILL.md` -> Commit rule.
- [ ] `templates/AGENTS.md` -> Issue Escape Triage, `#<num>` examples, commit rule.
- [ ] `.agents/AGENTS.md` -> Same as the template.
- [ ] `tests/verb_contracts_test.sh` -> Daily-verb skill coverage guard.
- [ ] `.agents/CODEMAP.md` -> List the new skill.
- [ ] `MANUAL.md` -> Skill list, if present.
- [ ] `CHANGELOG.md` -> Record under unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.agents/skills/` -> Guard Section 2 self-protected; refreshed from `templates/skills/` by `aapp init`.
- [ ] `.claude/skills/` -> Bridge maintained by `sync_skills`.
- [ ] `lib/` -> No CLI behaviour changes; P-32 already ships the verbs.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [ ] **Question 1 — Commit rule for plan refinements.** `aapp-digest` and `aapp-tdd` tell agents to run raw `git -C .plans commit` after editing a plan; `aapp-done`/`aapp-freeze`/`aapp-start` forbid raw commits on the plans worktree. Options: (a) narrow the prohibition to lifecycle transitions and state explicitly that plan-content refinements are committed with `git -C .plans commit -- <plan file>`; (b) route refinements through a CLI path (no such verb exists today; would need `lib/` changes, out of this plan's scope).
* [ ] **Question 2 — Coverage guard scope.** Besides `issue`, seven daily verbs appear in no skill today: `plan`, `plan-status`, `matrix`, `active`, `note`, `test`, `ai`. Options: (a) require every daily verb to be named in a skill (adds mentions or skills for all seven); (b) keep an explicit allow-list in the test for verbs that are developer-facing rather than agent workflow (e.g. `ai`, `note`, `test`), with each exemption justified in a comment.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-02:** Plan drafted after the P-32 skills audit: skills lack `aapp issue`, `aapp-done` predates issue close-on-done, contradictory plans-worktree commit rule, no daily-verb coverage guard.
