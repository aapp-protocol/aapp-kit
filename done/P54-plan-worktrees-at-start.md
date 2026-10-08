# 🗺️ Plan P-54: Plan Worktrees at Start
* **Created:** 2026-10-04 | **Last Refined:** 2026-10-07
* **Target Issue / Milestone:** None (follows P-52 and the #84 fix)
* **Plan ID:** P-54
* **Changelog:** Added: `aapp start` can create a branch and worktree per plan (`aapp.planWorktrees`) and open a session there (`aapp.planSession`)
* **Commit Mode:** atomic
* **Changelog Mode:** plan
* **Status:** ✅ Done
* **Base:** `ade93c3` (develop)
* **Commits:** `61d1f9b` (develop)
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

Placeholders: `{id}` (`P51`), `{num}` (`51`), `{slug}`, `{repo}` (primary checkout directory name). The base branch comes from `aapp.devBranch`, a space-separated candidate list (default `develop dev development`, as the hook reads it): a resolver in `lib/aapp-lib.sh` returns the first candidate that exists locally or on a remote, and **empty** when none does. Only `start` falls back, to the repository's default branch (`origin/HEAD`, else `main` or `master` when present), and refuses when there is none. The hook's branch protection keeps its own reading (none found → no protection).

### 2.2 `aapp start` / `aapp freeze-start` (`lib/cmd_plan.sh`)
With `aapp.planWorktrees = on`, in this order:
1. the existing gates;
2. renders the branch and path, and refuses when the branch or path already exists (never reuses or overwrites) or no base branch resolves (2.1). Uncommitted changes in the primary checkout do not block: the worktree is created from the branch ref, so they are unaffected; `start` prints a notice that they stay in the primary;
3. snapshots the plan file and `state_matrix.md` (for rollback, without touching the developer's own uncommitted planning edits), then `git worktree add --no-track -b <branch> <path> <base>` (`--no-track`: a plan branch made from a remote-only base must not track it, or `git pull`/`git push` in the plan worktree would act on the development branch);
4. links the kit into the worktree: `.githooks`, `.agents`, `.plans` and `.claude` (when present in the primary), as relative symlinks to the primary checkout, so the hooks (`core.hooksPath` is relative), the Claude guard (`${CLAUDE_PROJECT_DIR}/.githooks/blast-radius-guard`), rules, skills and plans are there. Without them a plan worktree runs no hook and no guard. It appends `/.githooks`, `/.agents`, `/.plans`, `/.claude` (no trailing slash: a `dir/` pattern does not match a symlink) to `$(git rev-parse --git-common-dir)/info/exclude` once, idempotently: shared by all worktrees, never tracked, no adopter file changed. A link that cannot be made **fails closed** (rollback); never a copy, which would be a second, diverging plan store that the guard reads first;
5. binds the plan in the new worktree's buffer (`git -C <path> rev-parse --git-path aapp_active_plan`; `write_active_buffer` takes the target worktree), leaving the primary's buffer untouched, so P-39's "held elsewhere" check keeps working;
6. dispatches `on-start` with the created `worktree` and `branch` in its `data`. The hook keeps the pass/fail contract; inside, it may rename the branch (`git branch -m`) or move the worktree (`git worktree move`) to fit the team's conventions;
7. reads back where the plan's worktree actually is (`git worktree list`, the lookup P-39 uses) and records `* **Worktree:** <path> (<branch>)` in the plan header with the path **relative to the primary checkout** (the plans branch is shared; an absolute path means nothing on another machine), and `* **Base:** `<sha>` (<base branch>)`: the commit the worktree was created from and the **base branch** it came from (`develop`, `module/…`), not the plan branch, which `Worktree:` already names. P-55 resolves the integration target from this branch. A hook's renaming is reflected in `Worktree:`;
8. the start commit, as today; prints the real path;
9. opens a session there per `aapp.planSession` (2.5), else prints the next step: `cd <path>`.

**All or nothing.** Any failure from step 3 to step 8 (link, hook, read-back, or the start commit, e.g. a `.plans` index lock while another `start` runs) rolls back: removes the worktree and its links, deletes the branch, clears the buffer and restores the plan file and `state_matrix.md` from the step 3 snapshot, leaving no trace, so `start` can simply be retried.

Optional override token: `aapp start <id> worktree <path> [branch <name>]` — explicit names win over templates. With `aapp.planWorktrees = off`, the token alone creates the worktree for that one plan.

### 2.3 Inside a plan worktree
- `.plans`, `.agents`, `.githooks`, `.claude` are the links from 2.2 step 4; the guard, hook, `aapp commit` and `aapp done` work from the plan worktree. Covered by tests (Phase 1). #84 (guard path relativisation) is fixed beforehand through `aapp issue fix` (Q3), so writes to the primary's `.plans` by absolute path are allowed too.
- Checkouts with no buffer do not adopt plans held here, and are refused their files (P-52 2.6).
- Team naming conventions live in `on-start` (2.2 step 6); the templates are the default when no hook renames.
- **Keeping `Commits:` right across rebases (RFC C60 option a, C61–C64).** A rebase or amend rewrites the plan's recorded commits, and `aapp done` refuses unreachable ones. A `post-rewrite` git hook (master `templates/post-rewrite` + engine `templates/aapp-post-rewrite`, installed and wired by `aapp init` like `pre-commit` and `commit-msg`, hook managers included) maps old to new SHAs in the bound plan's `* **Commits:**`, matching recorded short SHAs by prefix; dedupes after a squash; removes tokens on the current branch that the rebase dropped (already upstream, not in git's mapping, not reachable from `HEAD`) with a notice; does nothing when `AAPP_COMMIT_HELPER=1` (`aapp commit amend` keeps its own record); commits the plan via `plans_commit`. Its exit status cannot stop a rebase, so a failed `.plans` commit warns loudly with the fix command. It applies with `aapp.planWorktrees` off too: a raw `git commit --amend` orphans a recorded SHA today.
- **Picking up a fix from the development branch: rebase only** (`git rebase --autostash <devBranch>`), never merge. `--autostash` sets the plan's uncommitted work aside for the rebase and re-applies it (a conflict keeps the stash); nothing is stashed at hotfix time in worktree mode (P-52). Finishing a conflicted merge runs pre-commit with every file the development branch changed staged, all outside the plan's Target Files, so the plan's own hook refuses it; `git rebase` runs no pre-commit.
- **Issue fixes are not made here.** `aapp issue fix` refuses inside a worktree recorded in a `⚡` plan's `* **Worktree:**` (resolved from the primary checkout), printing the primary path: a fix committed on the plan branch would be swallowed by the plan's squash and its recorded SHA would dangle. A blocking bug in a file **outside** the plan's Target Files: the agent runs `aapp issue hotfix "<text>" file <path>…` (P-52) in the plan worktree and stops. That one command logs and queues the issue, records it in `Emergency Hotfixes:` and blocks the plan; the fix runs in the main checkout (`aapp issue fix next-blocker`), and its close unblocks the plan and prints the rebase step. A bug in a file the plan already owns is plan work. With `aapp.planWorktrees = off` (no recorded worktree), P-52's interrupt through `.prev` stays the path.

### 2.4 `aapp done`
- Refuses when run with uncommitted changes in the plan's worktree.
- Clears the plan's buffer in the worktree that holds it (`find_worktree_holding_plan`) as well as the current one, wherever `done` runs; otherwise that worktree stays bound to an archived plan and its guard refuses every edit.
- Does not merge, delete the branch or remove the worktree (Q1): integration (squash or merge) stays the developer's or the team tooling's step. It prints `git worktree remove <path>`, warning that removal **deletes ignored files** in that worktree (local env files, build output), and that the branch is deleted after integration (`git branch -D` after a squash merge, where `-d` refuses). An automatic removal token is left to the Work Dispatch Queue idea, where a runner owns its worktrees.
- The `* **Worktree:**` line moves to `done/` with the plan; it is where a finished plan's branch can be found (the state matrix lists only `current/`).

### 2.5 Opening a session in the plan's worktree: `aapp.planSession`
A personal, per-clone command template (not seeded; empty by default) that `aapp start` / `aapp freeze-start` run after the start commit, so a new agent session, another vendor's CLI or an editor opens in the plan's worktree:
```
git config aapp.planSession 'tmux new-window -c {path} -n {id} claude'
git config aapp.planSession 'gnome-terminal --working-directory={path} -- gemini'
git config aapp.planSession 'code {path}'
```
- Placeholders: `{path}` (the actual worktree, read back after `on-start`), `{id}`, `{branch}`, `{slug}`, `{plan_file}`; also exported as `AAPP_PLAN_ID`, `AAPP_WORKTREE`, `AAPP_BRANCH`, `AAPP_SLUG`, `AAPP_PLAN_FILE` (worktree-relative `.plans/current/<file>`, through the link). Placeholders are substituted **shell-quoted** (`printf %q`): refnames may contain `$`, `;`, `&`, `|` or backticks, and `on-start` may rename the branch.
- Run **detached** in the worktree and never waited on: `aapp start` is often invoked by an agent, and an interactive session inside that command would hang it. Output goes to `$(git rev-parse --git-path aapp_session.log)` of the plan's worktree.
- A launch failure only warns and prints the `cd <path>` fallback: the plan has started and its worktree exists (registered in the Fallback Inventory).
- A config, not `on-start`: hooks are registered and hash-locked per repository (team gates); the session tool is each developer's own choice.
- Out of scope: giving the new session its task (e.g. "work on P-51"). Prompt passing differs per vendor; it belongs to the *Work Dispatch Queue* pickup idea, where agents claim plans. The manual does not present a one-shot unattended run (e.g. `claude -p`) as dispatch: it stops at the first blocking bug (2.3) with no one watching.

### 2.6 Agent-facing text
- `templates/skills/aapp-start/SKILL.md`: after `aapp start`, continue in the printed worktree path; blocking bug outside the plan → `aapp issue hotfix` and stop (2.3); pick up fixes by rebase.
- `templates/skills/aapp-done/SKILL.md`: the printed removal command, its ignored-files warning, branch deletion after integration.
- AGENTS.md (both copies): plan work happens in the plan's worktree when `aapp.planWorktrees = on`; issue fixes happen in the main checkout on the development branch (P-52); plan branches take fixes by rebase only.

### 2.7 `aapp status`
`lib/cmd_status.sh` prints a plan's worktree next to it: `• P-51: P51-….md (⚡ In Development → ../repo-P51)`, from the header line.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `aapp.planSession` launch failure → warning plus the `cd <path>` fallback; the plan's start has already succeeded. `post-rewrite` failing to commit the updated `Commits:` → loud warning naming the command to fix the record (the hook cannot stop a rebase). No other fallback: kit links never fall back to copies.
- Default `off`: nothing changes for existing repositories until they opt in.
- Symlinks on Windows (Git Bash) are untested: listed as a risk in MANUAL §14.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Tests First (red)
- [ ] Task 1.1: `tests/verbs/start.sh`: with `on`, `start` creates the templated branch from the resolved development branch (candidate list; empty → default branch; none → refuse) without upstream (`--no-track`), creates the worktree with the four links and the `info/exclude` entries (links untracked, `git status` clean), binds the plan there and leaves the primary's buffer untouched, records `**Worktree:**` relative to the primary and `**Base:**` as the base commit and base branch; refusals (existing branch or path, no base); a dirty primary only prints a notice; `worktree`/`branch` tokens override; an `on-start` hook that renames the branch and moves the worktree is reflected in the record and the printed path; a failing `on-start`, a failing link or a failing start commit rolls back fully, keeping the developer's prior uncommitted plan edits; `aapp.planSession` runs detached in the worktree with quoted placeholders and the environment filled in, `start` returns without waiting, and a failing session command only warns; `off` changes nothing.
- [ ] Task 1.2: `tests/worktree_hooks_test.sh`: from a plan worktree, the hook runs, the guard confines to the plan's files, an absolute-path write to the primary's `.plans` is allowed, `aapp commit` records the commit in the plan, and `git rebase <devBranch>` passes while finishing a conflicted merge is refused; after a rebase, an interactive squash and a rebase that drops an already-applied commit, `Commits:` lists exactly the reachable rewritten SHAs (no duplicates) and `done` accepts them; `aapp commit amend` records its SHA once; `aapp issue fix` inside the plan worktree is refused with the primary path.
- [ ] Task 1.3: `tests/verbs/done.sh`: `done` from a plan worktree archives; refuses with uncommitted changes there; run from the primary, it clears the holding worktree's buffer; prints the removal command with the ignored-files warning and leaves the worktree.
- [ ] Task 1.4: `tests/verbs/issue.sh`: `aapp issue fix` refuses inside a recorded plan worktree and prints the primary path; allowed with `off`.
- [ ] Task 1.5: `tests/verbs/status.sh`: the worktree is shown next to its plan.
- [ ] Task 1.6: `tests/install_test.sh`: the three keys seeded only when absent.

### Phase 2: Implementation
- [ ] Task 2.1: Config seeding in `lib/cmd_init.sh`.
- [ ] Task 2.2: Development-branch resolver and template rendering in `lib/aapp-lib.sh`.
- [ ] Task 2.3: Worktree creation (`--no-track`), links and excludes, binding, read-back, relative `**Worktree:**` and `**Base:**` records, snapshot rollback; `worktree`/`branch` tokens; in `lib/cmd_plan.sh`.
- [ ] Task 2.4: `on-start` dispatched after creation with `worktree` and `branch`, inside the rollback scope.
- [ ] Task 2.5: `aapp done`: uncommitted check, holding-buffer cleanup, removal advice, in `lib/cmd_plan.sh`.
- [ ] Task 2.6: `aapp.planSession`: quoted placeholders, environment, detached launch, warn on failure.
- [ ] Task 2.7: Plan-worktree refusal in `lib/cmd_issue.sh`; worktree column in `lib/cmd_status.sh`.
- [ ] Task 2.8: Contracts `lib/docs/verbs/start.md`, `freeze-start.md` (Base = base commit and base branch), `done.md`, `issue.md`, `status.md`.
- [ ] Task 2.9: `post-rewrite` master and engine in `templates/`, installed and wired by `lib/cmd_init.sh`.

### Phase 3: Agent Text, Docs & Verification
- [ ] Task 3.1: skills `aapp-start`, `aapp-done`; AGENTS.md (both) (2.6).
- [ ] Task 3.2: `MANUAL.md` (plan worktrees; `aapp.devBranch` rows made consistent; §14 Windows symlinks), `CHEATSHEET.md` (config rows), `ARCHITECTURE.md`, `.agents/CODEMAP.md`.
- [ ] Task 3.3: Run `./aapp test strict quiet`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/cmd_init.sh` -> Seed the three config keys; install and wire `post-rewrite`.
- [ ] `lib/cmd_plan.sh` -> Worktree creation, links, records and rollback in `start` / `freeze-start`; tokens; `done` checks and buffer cleanup.
- [ ] `lib/cmd_issue.sh` -> Refuse `fix` inside a plan worktree.
- [ ] `lib/cmd_status.sh` -> Worktree next to its plan.
- [ ] `lib/aapp-lib.sh` -> Template rendering and development-branch resolver.
- [ ] `lib/docs/verbs/start.md` -> Contract.
- [ ] `lib/docs/verbs/freeze-start.md` -> Contract.
- [ ] `lib/docs/verbs/done.md` -> Contract.
- [ ] `lib/docs/verbs/issue.md` -> Plan-worktree refusal.
- [ ] `lib/docs/verbs/status.md` -> Worktree column.
- [ ] `tests/verbs/start.sh` -> Worktree creation tests.
- [ ] `tests/verbs/freeze-start.sh` -> Same through `freeze-start`.
- [ ] `tests/verbs/done.sh` -> `done` from a plan worktree.
- [ ] `tests/verbs/issue.sh` -> Plan-worktree refusal.
- [ ] `tests/verbs/status.sh` -> Worktree column.
- [ ] `tests/worktree_hooks_test.sh` -> Guard, commit, rebase and `post-rewrite` from a plan worktree.
- [ ] `tests/install_test.sh` -> Config seeding; `post-rewrite` installed and wired (custom hook, hook manager).
- [ ] `tests/verbs/active.sh` -> Fixture releases the primary's binding before binding in another worktree (the holding-worktree lookup now resolves the primary's buffer).
- [ ] `templates/skills/aapp-start/SKILL.md` -> Continue in the plan worktree; hotfix; rebase.
- [ ] `templates/skills/aapp-done/SKILL.md` -> Worktree removal advice.
- [ ] `templates/post-rewrite` -> NEW FILE: master `post-rewrite` entrypoint.
- [ ] `templates/aapp-post-rewrite` -> NEW FILE: keeps the bound plan's `Commits:` across rebase and amend.
- [ ] `templates/AGENTS.md` -> Where plan work and fixes happen.
- [ ] `.agents/AGENTS.md` -> Same as the template.
- [ ] `MANUAL.md` -> Plan worktrees; `aapp.devBranch` rows; §14 Windows symlinks.
- [ ] `CHEATSHEET.md` -> Config rows, incl. `aapp.planSession`.
- [ ] `ARCHITECTURE.md` -> Plan worktrees in the lifecycle.
- [ ] `.agents/CODEMAP.md` -> Helper and behaviour.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit` from the declaration.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> #84 is fixed beforehand through `aapp issue fix` (Q3); held-plan handling is P-52's.
- [ ] `templates/aapp-pre-commit` -> Branch protection keeps its own development-branch reading.
- [ ] `.githooks/*` -> Refreshed from `templates/` by `aapp init`.
- [ ] `.agents/skills/*` -> Refreshed from `templates/skills/` by `aapp init`.
- [ ] `lib/verbs.tsv` -> No new verbs.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Does `aapp done` remove the plan's worktree? → RESOLVED (developer, 2026-10-04): (a), with the ignored-files warning (2.4).** (a) No: it prints the `git worktree remove` command; the developer removes it after integrating (squash/merge). (b) Yes, when the worktree is clean and its branch is already merged into `aapp.devBranch`; otherwise it prints the command. Recommendation: (a) — `done` usually runs before the squash, so (b) would rarely apply and adds a merge check.
* [x] **Question 2 — Should `on-start` be able to choose the names? → RESOLVED (developer, 2026-10-04): yes, by acting, not by returning data.** The hook keeps the pass/fail contract and may rename the branch or move the worktree itself; the kit reads back the actual names before recording, and rolls back what it created if the hook fails (2.2).
* [x] **Question 3 — Order with #84. → RESOLVED (developer, 2026-10-04): fixed first through `aapp issue fix`, after P-52 ships.** The guard's path relativisation bug (#84) bites in exactly the situation this plan makes normal (working inside a linked worktree). Fix #84 first (as a P-52 issue fix once that ships), or fold it into this plan's file list?

---

## 📦 6. Change Log & Refinement History
* **2026-10-08:** Plan implementation completed and archived to done/.
* **2026-10-08:** Plan activated into ⚡ In Development via start.
* **2026-10-08:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-10-08:** Added `tests/verbs/active.sh` to Target Files (developer-approved round trip): `find_worktree_holding_plan` now resolves the primary checkout's relative buffer path, so a linked worktree can no longer bind a plan the primary holds; that test's fixture relied on the old behaviour.
* **2026-10-08:** Plan frozen and activated into ⚡ In Development via freeze-start.
*Tracks how the plan evolved across sessions.*
* **2026-10-07:** Resume after a hotfix with `git rebase --autostash <devBranch>`: the plan's uncommitted work rides through the rebase (P-52's stash settlement; single-checkout stashing is P-52's).
* **2026-10-07:** Renamed `aapp issue handoff` to `aapp issue hotfix` (developer): vendor-neutral, and one word with `Emergency Hotfixes:` and `aapp.maxEmergencyHotfixes`; misuse is caught both ways (`hotfix` needs a bound plan, `fix` is refused in a plan worktree).
* **2026-10-05:** Refined from the P-52/P-54 review RFC (settled design, C60–C64): `Base:` records the base branch (for P-55's integration target); blocking bugs hand off with `aapp issue handoff` (P-52); `post-rewrite` hook keeps `Commits:` across rebase, squash, dropped commits and amend.
* **2026-10-04:** Refined from the P-52/P-54 review RFC (C1–C5, C7, C12, C13, C17–C21, C27–C30, C51, C58; user decisions on C17, C51, Q1, Q3): kit links and `info/exclude` at start, failing closed; `--no-track`; development-branch resolver; relative `Worktree:` and Base from the new worktree; no dirty-primary refusal; all-or-nothing rollback from a snapshot; `done` clears the holding buffer and warns that removal deletes ignored files; quoted session placeholders and `AAPP_PLAN_FILE`; `issue fix` refused in plan worktrees with a BLOCKED hand-off; rebase only; worktree shown in `aapp status`; Q1 (a), Q3 (#84 first).
* **2026-10-04:** Added `aapp.planSession`: a personal command template run detached after the start commit to open an agent session (any vendor), terminal or editor in the plan's worktree; first step towards multi-agent work, task hand-off left to the Work Dispatch Queue idea.
* **2026-10-04:** Q2 resolved: `on-start` renames by acting (pass/fail contract unchanged); start order is create → hook → read back → record → commit, with rollback on hook failure.
* **2026-10-04:** Drafted from the developer's proposal: `aapp start` creates the plan's branch and worktree (opt-in), names from config templates with the development branch as base, `on-start` notified; foundation for P-52's rule that issue fixes land on the development branch.
