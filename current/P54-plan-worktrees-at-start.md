# 🗺️ Plan P-54: Plan Worktrees at Start
* **Created:** 2026-10-04 | **Last Refined:** 2026-10-04
* **Target Issue / Milestone:** None (foundation for P-52)
* **Plan ID:** P-54
* **Changelog:** Added: `aapp start` can create a branch and worktree per plan (`aapp.planWorktrees`) and open a session there (`aapp.planSession`)
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

Plans that run on their own branch are a convention today, not something the kit sets up. That leaves three problems:

1. **Squash merges swallow issue fixes.** A fix committed on a plan's branch disappears into the plan's squash, cannot ship before the plan, and its recorded SHA dangles once the branch is deleted (P-52 discussion).
2. **Concurrent plans share one working copy** unless the developer sets up worktrees by hand, which brings back the same-file hazard P-48 and P-52 work around.
3. **Every developer creates branches and worktrees differently**, so nothing in the kit can rely on where plan work lives.

**Goal:** opt-in, `aapp start` creates the plan's branch (from the configured development branch) and its worktree, binds the plan to it, and names both by configurable templates. Plan work then lives on plan branches by construction, and the main checkout on `aapp.devBranch` stays the place for issue fixes (P-52). No new verb: a behaviour of `aapp start` plus an optional token.

---

## 2. Technical Blueprint

### 2.1 Config (`lib/cmd_init.sh`), seeded only when absent
| Key | Default | Meaning |
| :--- | :--- | :--- |
| `aapp.planWorktrees` | `off` | `on`: `aapp start` / `aapp freeze-start` create the plan's branch and worktree |
| `aapp.planBranch` | `plan/{id}-{slug}` | branch name template |
| `aapp.planWorktreePath` | `../{repo}-{id}` | worktree path template, relative to the primary checkout |

Placeholders: `{id}` (`P51`), `{num}` (`51`), `{slug}`, `{repo}` (primary checkout directory name). The base branch is `aapp.devBranch` (existing; `main` when unset in a single-branch repository).

### 2.2 `aapp start` / `aapp freeze-start` (`lib/cmd_plan.sh`)
With `aapp.planWorktrees = on`, in this order:
1. the existing gates;
2. renders the branch and path; refuses with a clear message when the branch or path already exists (never reuses or overwrites), when the base branch is missing, or when the primary checkout has uncommitted changes to tracked files that `git worktree add` would not carry;
3. `git worktree add -b <branch> <path> <devBranch>` and binds the plan to the new worktree (its active-plan buffer, P-39's per-worktree binding, so the "held elsewhere" check keeps working);
4. dispatches `on-start` with the created `worktree` and `branch` in its `data`. The hook keeps the pass/fail contract; inside, it may rename the branch (`git branch -m`) or move the worktree (`git worktree move`) to fit the team's conventions. Exit non-zero → `aapp start` refuses and **rolls back**: removes the worktree and branch it created, leaving no trace;
5. reads back where the plan's worktree actually is (`git worktree list`, the lookup P-39 uses to find the worktree holding a plan) and records `* **Worktree:** <path> (<branch>)` in the plan header (data only, like P-51's record) — so a hook's renaming is reflected;
6. the start commit, as today; prints the real path;
7. opens a session there per `aapp.planSession` (2.5), else prints the next step: `cd <path>`.

Optional override token: `aapp start <id> worktree <path> [branch <name>]` — explicit names win over templates. With `aapp.planWorktrees = off`, the token alone creates the worktree for that one plan.

### 2.3 Inside a plan worktree
- `.plans`, `.agents`, `.githooks` are reached through the primary checkout (resolved via `git rev-parse --git-common-dir`, as today); the guard, hook, `aapp commit` and `aapp done` work from the plan worktree. Covered by tests (Phase 1), and depends on #84 (guard path relativisation) being fixed.
- Team naming conventions live in `on-start` (2.2 step 4); the templates are the default when no hook renames.

### 2.4 `aapp done`
- Refuses when run with uncommitted changes in the plan's worktree.
- Does not merge and does not delete the branch: integration (squash or merge) stays the developer's or the team tooling's step. Worktree removal per Q1.

### 2.5 Opening a session in the plan's worktree: `aapp.planSession`
A personal, per-clone command template (not seeded; empty by default) that `aapp start` / `aapp freeze-start` run after the start commit, so a new agent session, another vendor's CLI or an editor opens in the plan's worktree:
```
git config aapp.planSession 'tmux new-window -c {path} -n {id} claude'
git config aapp.planSession 'gnome-terminal --working-directory={path} -- gemini'
git config aapp.planSession 'code {path}'
```
- Placeholders: `{path}` (the actual worktree, read back after `on-start`), `{id}`, `{branch}`, `{slug}`; also exported as `AAPP_PLAN_ID`, `AAPP_WORKTREE`, `AAPP_BRANCH`.
- Run **detached** in the worktree and never waited on: `aapp start` is often invoked by an agent, and an interactive session inside that command would hang it. Output goes to `$(git rev-parse --git-path aapp_session.log)` of the plan's worktree.
- A launch failure only warns and prints the `cd <path>` fallback: the plan has started and its worktree exists (registered in the Fallback Inventory).
- A config, not `on-start`: hooks are registered and hash-locked per repository (team gates); the session tool is each developer's own choice.
- Out of scope: giving the new session its task (e.g. "work on P-51"). Prompt passing differs per vendor; it belongs to the *Work Dispatch Queue* pickup idea, where agents claim plans.

### 2.6 Agent-facing text
- `templates/skills/aapp-start/SKILL.md`: after `aapp start`, continue in the printed worktree path.
- AGENTS.md (both copies): plan work happens in the plan's worktree when `aapp.planWorktrees = on`; issue fixes happen in the main checkout on the development branch (P-52).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `aapp.planSession` launch failure → warning plus the `cd <path>` fallback; the plan's start has already succeeded.
- Default `off`: nothing changes for existing repositories until they opt in.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Tests First (red)
- [ ] Task 1.1: `tests/verbs/start.sh`: with `on`, `start` creates the templated branch from `aapp.devBranch` and the worktree, binds the plan there, records `**Worktree:**`; refusals (existing branch or path, missing base, dirty primary checkout); `worktree`/`branch` tokens override; an `on-start` hook that renames the branch and moves the worktree is reflected in the record and the printed path; a failing `on-start` refuses and leaves no worktree or branch; `aapp.planSession` runs detached in the worktree with the placeholders and environment filled in, `start` returns without waiting, and a failing session command only warns; `off` changes nothing.
- [ ] Task 1.2: `tests/worktree_hooks_test.sh`: from a plan worktree, the guard confines to the plan's files and `aapp commit` records the commit in the plan.
- [ ] Task 1.3: `tests/verbs/done.sh`: `done` from a plan worktree archives; refuses with uncommitted changes there; worktree removal per Q1.
- [ ] Task 1.4: `tests/install_test.sh`: the three keys seeded only when absent.

### Phase 2: Implementation
- [ ] Task 2.1: Config seeding in `lib/cmd_init.sh`.
- [ ] Task 2.2: Template rendering, worktree creation, binding and `**Worktree:**` record in `lib/cmd_plan.sh`; `worktree`/`branch` tokens.
- [ ] Task 2.3: `aapp done` checks (and Q1 removal) in `lib/cmd_plan.sh`.
- [ ] Task 2.4: `on-start` dispatched after creation with `worktree` and `branch`; rollback on failure; read back the actual worktree before recording.
- [ ] Task 2.6: `aapp.planSession`: render placeholders, export the environment, launch detached, warn on failure.
- [ ] Task 2.5: Contracts `lib/docs/verbs/start.md`, `freeze-start.md`, `done.md`.

### Phase 3: Agent Text, Docs & Verification
- [ ] Task 3.1: `templates/skills/aapp-start/SKILL.md`; AGENTS.md (both).
- [ ] Task 3.2: `MANUAL.md`, `CHEATSHEET.md` (config rows), `ARCHITECTURE.md`, `.agents/CODEMAP.md`.
- [ ] Task 3.3: Run `./aapp test strict quiet`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/cmd_init.sh` -> Seed the three config keys.
- [ ] `lib/cmd_plan.sh` -> Worktree creation in `start` / `freeze-start`; tokens; `done` checks.
- [ ] `lib/aapp-lib.sh` -> Template rendering helper.
- [ ] `lib/docs/verbs/start.md` -> Contract.
- [ ] `lib/docs/verbs/freeze-start.md` -> Contract.
- [ ] `lib/docs/verbs/done.md` -> Contract.
- [ ] `tests/verbs/start.sh` -> Worktree creation tests.
- [ ] `tests/verbs/freeze-start.sh` -> Same through `freeze-start`.
- [ ] `tests/verbs/done.sh` -> `done` from a plan worktree.
- [ ] `tests/worktree_hooks_test.sh` -> Guard and commit from a plan worktree.
- [ ] `tests/install_test.sh` -> Config seeding.
- [ ] `templates/skills/aapp-start/SKILL.md` -> Continue in the plan worktree.
- [ ] `templates/AGENTS.md` -> Where plan work and fixes happen.
- [ ] `.agents/AGENTS.md` -> Same as the template.
- [ ] `MANUAL.md` -> Plan worktrees.
- [ ] `CHEATSHEET.md` -> Config rows, incl. `aapp.planSession`.
- [ ] `ARCHITECTURE.md` -> Plan worktrees in the lifecycle.
- [ ] `.agents/CODEMAP.md` -> Helper and behaviour.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit` from the declaration.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Path handling is #84's fix, not this plan's.
- [ ] `.githooks/*` -> Refreshed from `templates/` by `aapp init`.
- [ ] `.agents/skills/*` -> Refreshed from `templates/skills/` by `aapp init`.
- [ ] `lib/verbs.tsv` -> No new verbs.

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1 — Does `aapp done` remove the plan's worktree?** (a) No: it prints the `git worktree remove` command; the developer removes it after integrating (squash/merge). (b) Yes, when the worktree is clean and its branch is already merged into `aapp.devBranch`; otherwise it prints the command. Recommendation: (a) — `done` usually runs before the squash, so (b) would rarely apply and adds a merge check.
* [x] **Question 2 — Should `on-start` be able to choose the names? → RESOLVED (developer, 2026-10-04): yes, by acting, not by returning data.** The hook keeps the pass/fail contract and may rename the branch or move the worktree itself; the kit reads back the actual names before recording, and rolls back what it created if the hook fails (2.2).
* [ ] **Question 3 — Order with #84.** The guard's path relativisation bug (#84) bites in exactly the situation this plan makes normal (working inside a linked worktree). Fix #84 first (as a P-52 issue fix once that ships), or fold it into this plan's file list?

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-04:** Added `aapp.planSession`: a personal command template run detached after the start commit to open an agent session (any vendor), terminal or editor in the plan's worktree; first step towards multi-agent work, task hand-off left to the Work Dispatch Queue idea.
* **2026-10-04:** Q2 resolved: `on-start` renames by acting (pass/fail contract unchanged); start order is create → hook → read back → record → commit, with rollback on hook failure.
* **2026-10-04:** Drafted from the developer's proposal: `aapp start` creates the plan's branch and worktree (opt-in), names from config templates with the development branch as base, `on-start` notified; foundation for P-52's rule that issue fixes land on the development branch.
