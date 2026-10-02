# 🗺️ Plan P-47: Skills Drive the CLI & Agent CLI Reference
* **Created:** 2026-10-02 | **Last Refined:** 2026-10-03
* **Target Issue / Milestone:** None (follow-up to P-32)
* **Plan ID:** P-47
* **Status:** 🔷 Frozen
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
4. **Contradictory commit rule.** `aapp-digest` and `aapp-tdd` instruct raw `git -C .plans commit`; `aapp-done`, `aapp-freeze` and `aapp-start` forbid raw commits on the plans worktree. No verb commits a plan-content edit.
5. **Manual scaffolding.** `aapp-plan` tells agents to call `allocate_plan_id`, copy the template and register the matrix by hand instead of running `aapp draft`.
6. **No reachable reference for rarely used verbs.** `ai`, `note`, `test`, `matrix`, `active`, `plan-status`, `issue list` are documented only in human docs; `aapp help <verb>` ignores the verb and repo-relative links to `lib/docs/verbs/` break in adopter repos.

**Goal:** agents never do the chores by hand and every chore has one expected output.
- **Skills stay lean:** no new skills. The existing workflow skills call the CLI wherever their step has one.
- **One reachable reference:** a compact CLI section in `AGENTS.md` (always loaded) lists every daily verb in one line, and `aapp help <verb>` prints its installed contract, independent of where the kit is installed.
- **A guard:** a test fails when a daily verb is missing from that reference or has no contract reachable through `aapp help`.

**Constraint:** `.agents/skills/aapp-*` is Guard Section 2 self-protected and must not appear in Target Files (Pair 5). Edits go to `templates/skills/`; `aapp init` (`sync_skills` in `lib/cmd_init.sh`) rebuilds every `aapp-*` skill from there and bridges new ones into `.claude/skills/`.

---

## 2. Technical Blueprint
### 2.1 Existing skills call the CLI (no new skills)
| Skill | Change |
| :--- | :--- |
| `aapp-digest` | Issue Lane: claim the ID with `aapp issue allocate` before writing the row; a direct fix closes with `aapp issue close <num>`. Plan edits committed with `aapp refine` |
| `aapp-plan` | Defect routing: same as digest. Scaffolding: `aapp draft <slug>` (allocates, scaffolds, registers, commits) replaces the manual `allocate_plan_id` / template copy / matrix steps |
| `aapp-pause` | Logging defects while paused: claim with `aapp issue allocate` |
| `aapp-done` | Step 2 adds the dangling-Target-Issue refusal; Step 3 states `done` archived and pruned the Target Issue in the same commit — never relocate it again |
| `aapp-tdd` | Step 3 commits the enumerated tests with `aapp refine` (the CLI commits only its own injection) |
| `aapp-status` | Full backlog beyond the top 5: `aapp issue list` |

### 2.2 Agent CLI reference in `AGENTS.md` (`templates/AGENTS.md`, `.agents/AGENTS.md`)
A compact `## 🧰 CLI Reference` section, always in the agent's context:
- one line per daily verb (`aapp <verb> <args>` — purpose), in `lib/verbs.tsv` order; no examples or option tables;
- the closing line: full catalog `aapp help`, a verb's contract `aapp help <verb>`;
- the rule: no raw git on the plans worktree; every plans change goes through an `aapp` verb (`aapp refine` for plan edits).
Also: *Issue Escape Triage* logs with `aapp issue allocate`; commit-convention examples use `#<num>` instead of `ISSUE-00X`.

### 2.3 `aapp help <verb>` (`lib/cmd_help.sh`)
- `aapp help <verb>` prints the contract file named in that verb's `lib/verbs.tsv` row, resolved from the same installed `lib/` that `help` already reads (`$AAPP_LIB`, script dir, `${XDG_DATA_HOME:-~/.local/share}/aapp-kit/lib`). Works in any adopter repo and install method.
- Unknown verb → exit 1, `Unknown command '<verb>'` plus the catalog hint. A verb without a contract (setup tier) → its one-line description.
- `aapp help` with no argument is unchanged.

### 2.4 New verb: `aapp refine <plan-id> "<what changed>"`
- Commits **only** `current/<plan file>` through `plans_commit` (configured attribution added automatically), subject `plan(refine): <plan-id> <what changed>`.
- Refuses: missing plan id or message, unknown plan, plan not in `.plans/current/`, nothing to commit. The pre-commit design lock still guards a frozen plan's §2/§4.
- Output on success: `📝 [Refine] <plan-id> committed (<sha>): <what changed>`.
- Registered in `lib/verbs.tsv` (daily) with contract `lib/docs/verbs/refine.md`; dispatched from `aapp`.
- Side fix: the `aapp tdd` commit in `lib/cmd_plan.sh` (`plans_commit ... || true`, then a raw `git commit ... || true`) fails silently, against invariant 8; it fails loudly instead.

### 2.5 Guard (test)
`tests/verb_contracts_test.sh` gains `test_daily_verbs_in_agent_reference`: every `daily` verb in `lib/verbs.tsv` appears as `aapp <verb>` in the CLI Reference section of `templates/AGENTS.md`, and `aapp help <verb>` prints its contract. Skills are not required to name every verb.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`
- Adopters pick up the updated skills on their next `aapp init` (`sync_skills` overwrites `aapp-*` skills; `aapp-hooks/registry.tsv` is preserved).

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Tests First (red)
- [ ] Task 1.1: Add `test_daily_verbs_in_agent_reference` to `tests/verb_contracts_test.sh`; confirm it fails (no CLI Reference yet, `help <verb>` ignores the verb).
- [ ] Task 1.2: Author `tests/verbs/refine.sh` (commits only the plan file, subject and output, refusals).

### Phase 2: CLI
- [ ] Task 2.1: Implement `cmd_refine` in `lib/cmd_plan.sh`; dispatch from `aapp`; register in `lib/verbs.tsv`; contract `lib/docs/verbs/refine.md`.
- [ ] Task 2.2: `aapp help <verb>` in `lib/cmd_help.sh` (§2.3).
- [ ] Task 2.3: Make the `aapp tdd` commit fail loudly.

### Phase 3: Skills & Protocol Text
- [ ] Task 3.1: Update `aapp-digest`, `aapp-plan`, `aapp-pause`, `aapp-done`, `aapp-tdd`, `aapp-status` (§2.1).
- [ ] Task 3.2: Add the CLI Reference and triage wording to `templates/AGENTS.md` and `.agents/AGENTS.md` (§2.2).

### Phase 4: Verification & Documentation
- [ ] Task 4.1: Run `./aapp test strict quiet`.
- [ ] Task 4.2: `.agents/CODEMAP.md` lists `cmd_refine` and `help <verb>`; `MANUAL.md` and `CHEATSHEET.md` document both.
- [ ] Task 4.3: `CHANGELOG.md` under `## [Unreleased]`.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `templates/skills/aapp-digest/SKILL.md` -> Issue IDs via `aapp issue allocate`, close via `aapp issue close`, plan edits via `aapp refine`.
- [ ] `templates/skills/aapp-plan/SKILL.md` -> Issue IDs via `aapp issue allocate`; scaffold via `aapp draft`.
- [ ] `templates/skills/aapp-pause/SKILL.md` -> Paused defect logging via `aapp issue allocate`.
- [ ] `templates/skills/aapp-done/SKILL.md` -> Target Issue close and dangling-issue refusal.
- [ ] `templates/skills/aapp-tdd/SKILL.md` -> Enumerated tests committed via `aapp refine`.
- [ ] `templates/skills/aapp-status/SKILL.md` -> Point to `aapp issue list`.
- [ ] `templates/AGENTS.md` -> CLI Reference section, Issue Escape Triage, `#<num>` examples.
- [ ] `.agents/AGENTS.md` -> Same as the template.
- [ ] `tests/verb_contracts_test.sh` -> Agent reference guard.
- [ ] `lib/cmd_plan.sh` -> `cmd_refine`; `aapp tdd` commit fails loudly.
- [ ] `lib/cmd_help.sh` -> `aapp help <verb>` prints the installed contract.
- [ ] `aapp` -> Dispatch `refine`.
- [ ] `lib/verbs.tsv` -> Register `refine` (daily).
- [ ] `NEW FILE` -> `lib/docs/verbs/refine.md` -> Verb contract.
- [ ] `NEW FILE` -> `tests/verbs/refine.sh` -> Contract test suite.
- [ ] `.agents/CODEMAP.md` -> List `cmd_refine` and `help <verb>`.
- [ ] `MANUAL.md` -> Document `aapp refine`, `aapp help <verb>`, the no-raw-git rule.
- [ ] `CHEATSHEET.md` -> Add `aapp refine` and `aapp help <verb>`.
- [ ] `CHANGELOG.md` -> Record under unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.agents/skills/` -> Guard Section 2 self-protected; refreshed from `templates/skills/` by `aapp init`.
- [ ] `.claude/skills/` -> Bridge maintained by `sync_skills`.
- [ ] `lib/cmd_issue.sh`, `lib/plan_resolver.sh` -> P-32 behaviour is unchanged; skills only describe it.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — Commit rule for plan refinements? → RESOLVED (developer, 2026-10-03): a CLI verb, `aapp refine` (§2.4).** Minimize agent chores and make every plans change produce one expected output; agents never run raw git on `.plans`.
* [x] **Question 2 — Where do rarely used verbs live? → RESOLVED (developer, 2026-10-03): not in skills.** No new skills; existing skills call the CLI where their workflow needs it; every daily verb is listed in a compact `AGENTS.md` CLI Reference and reachable through `aapp help <verb>` (§2.2, §2.3, §2.5).

---

## 📦 6. Change Log & Refinement History
* **2026-10-03:** Plan locked and frozen into 🔷 Frozen via freeze.
*Tracks how the plan evolved across sessions.*
* **2026-10-03:** Reworked to lean skills: no new `aapp-issue` skill; existing skills call the CLI (incl. `aapp-plan` → `aapp draft`); rarely used verbs go into an `AGENTS.md` CLI Reference plus `aapp help <verb>`; the guard checks the reference, not the skills. Retitled.
* **2026-10-03:** Q1 and Q2 resolved from the developer's intent (minimize agent chores, one expected output, nothing forgotten): added the `aapp refine` verb (§2.5), the loud `aapp tdd` commit, and strict daily-verb coverage.
* **2026-10-02:** Plan drafted after the P-32 skills audit: skills lack `aapp issue`, `aapp-done` predates issue close-on-done, contradictory plans-worktree commit rule, no daily-verb coverage guard.
