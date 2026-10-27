---
title: CLI Command Reference
description: Every aapp verb and every form it accepts, grouped as aapp help groups them, with what each form does and links to the settings and pages that explain it.
---

# 💻 CLI Command Reference

Every chore has a verb. Arguments are bare tokens (`aapp done P-7 squash`), never `--flags`. The verbs and their groups come from `lib/verbs.tsv`; `aapp help` prints the catalog, `aapp help <verb>` one verb's arguments, and `aapp help <verb> full` its refusals and effects, from the verb's contract in `lib/docs/verbs/<verb>.md`.

A plan is named by `P-<N>`, a bare `<N>`, its file name, or a slug prefix. An issue is named by its number (`79`, `#79`) or a tracker's key (`PROJ-101`); quote a `#` form, which the shell otherwise treats as a comment.

**Groups:** [Daily](#1-daily-working-loop) · [Setup & Maintenance](#2-setup--maintenance) · [Sync & Emergency Brake](#3-sync--emergency-brake) · [Hooks & Plugins](#4-hooks--plugins) · [A Terminal-Only Day](#5-a-terminal-only-day)

---

## 1. Daily Working Loop

### `aapp status`
```text
aapp status [short | json]
```
- *(no argument)*: the four-pillar briefing: Shipped (unreleased changelog), Issues (work queue, then the count of the rest), Plans (state matrix, groups with their members) and Pickup (ideas), then the adoption tasks and the next action.
- `short` (or `summary`): one line.
- `json`: the briefing as one JSON document ([08. JSON Output](08-output-json.md)).

Settings: [Status & Output](03-configuration-matrix.md#status--output), [Issues & Fixes](03-configuration-matrix.md#issues--fixes) (`aapp.issueSyncWindow`).

### `aapp draft`
```text
aapp draft [slug] [issue <num> | group [<id>]]
```
- `<slug>`: takes the next Plan ID, writes `.plans/current/P<N>-<slug>.md` from the plan template (title from the slug), registers it in the state matrix, and commits. The plan is `🟣 Under Review`.
- *(no slug)*: offers the open pickup ideas and issues to draft from.
- `issue <num>`: the plan is made for an issue: its `Target Issue` is set, the issue's row links the plan and becomes `🔵 Planned` (promotion, [03. Two Lanes](../concepts/03-two-lane-governance.md)).
- `group`: drafts a group plan and its amendments member together; `group <id>` drafts a member of group `<id>`.

Plan IDs: [18. Plan ID Allocation](18-plan-id-allocation.md). A provider that cannot be reached stages the draft offline ([Offline](03-configuration-matrix.md#offline)).

### `aapp refine`
```text
aapp refine <id> "<what changed>"
aapp refine <id> blocked <num> | unblocked <num>
aapp refine <id> slug <new-slug>
aapp refine <id> closes <num> [remove]
aapp refine <id> group <group> | none
aapp refine <amend-id> request "<summary>" [file <path> [for <plan-id>] | heading "<heading>"]
aapp refine <amend-id> approve <n> | refuse <n> "<reason>" | decision <n> "<reason>" | decision "<heading>" "<reason>"
aapp refine pickup "<msg>"
aapp refine issues "<msg>" [branch <num> <name>] [note <num> "<text>"]…
```
- `"<what changed>"`: commits your edit of the plan file, alone, as `plan(refine): <id> <what changed>`.
- `blocked <num>` / `unblocked <num>`: blocks the plan on an issue, or takes a closed issue off by hand.
- `slug <new-slug>`: renames the plan and repairs every link to it.
- `closes <num> [remove]`: lists a further issue the plan sorts; `done` closes it.
- `group <group>` / `group none`: moves a plan into a group, or out of it, before it starts.
- `request`, `approve`, `refuse`, `decision`: the group amendments ledger ([16. Group Amendments](16-group-amendments.md)).
- `pickup "<msg>"`: commits a hand edit of `pickup.md`, after checking every line.
- `issues "<msg>"`: commits changes to existing issue rows; `branch <num> <name>` names the branch an issue's fix must land on; `note <num> "<text>"` adds a note kept outside Git.

Details, ownership and refusals: [01. Lifecycle §3.4](01-lifecycle-state-machine.md#34-committing-plan-edits-aapp-refine).

### `aapp tdd`
```text
aapp tdd <id_or_slug>
```
- Adds a plan's failure-first test sections, `### 🧪 Required Tests` in §3 and `### 🧪 Required Test Files` in §4, before freeze; with a new slug, drafts the plan first. Skill: `/aapp-tdd`.
- It declares tests only: it writes no test code and runs nothing. When the plan starts, the agent writes the declared tests first and confirms they fail (red) before writing the feature.
- Files listed under `### 🧪 Required Test Files` may be written during development without a second line under `### 📂 Target Files`.

### `aapp plan`
```text
aapp plan [query]
aapp plan conflict-check <id> <id>… [json]
aapp plan conflict-free [<id> | <group>] [json]
aapp plan abort <id> [reason "<text>"] [keep-branch] [force] [force-cleanup] [confirm]
```
- *(no argument)* / `<query>`: the planning switchboard: how to plan, and the plans that match.
- `conflict-check <id> <id>…`: compares the Target Files of two or more plans, any status (a group expands to its members). Exit 0 when disjoint (shared docs are noted, not counted), 1 naming each colliding file.
- `conflict-free`: every pending plan against the plans in development; `conflict-free <id>`: every other plan against `<id>`; `conflict-free <group>`: the group's members placed in waves that can run side by side.
- `json`: the same result as one JSON document.
- `abort <id>`: abandons a plan, any status: archived to `.plans/aborted/`, its worktree and branch removed (`keep-branch` keeps the branch), its issue back to `🟡 Incubated`. `force` discards uncommitted work in its worktree; `force-cleanup` deletes ignored files there too; `confirm` skips the prompt for a group. Run it from the main checkout, and only when a person asks.

### `aapp plan-status`
```text
aapp plan-status [id]
```
- *(no argument)*: the lane overview of every plan in `.plans/current/`.
- `<id>`: one plan: title, Status, file, unresolved open questions, Target Files; for an amendments member also its requests and decisions. Read-only.

### `aapp matrix`
```text
aapp matrix [check]
```
- *(no argument)*: re-derives `.plans/state_matrix.md` from the plans' Status lines, keeping its hand-written Roadmap and row notes.
- `check`: audits only; exit 1 when the matrix has drifted.
- A plan has a row only while it is in `.plans/current/`; once archived, aborted or renamed, the archive ledger (`done/000-archive-ledger.md`, `aborted/000-aborted-ledger.md`) is its record.
- A Status that matches no known status is listed under *Unrecognized Status*, so a typo is visible instead of filed away.
- While the project is paused, the matrix is written but not committed; run `aapp matrix` again after `aapp resume` to commit it.

Custom statuses: `aapp.planState.<slug>` ([Plans & Worktrees](03-configuration-matrix.md#plans--worktrees)).

### `aapp freeze`
```text
aapp freeze <id>
```
- Locks the plan's design (§2) and Blast Radius (§4): Status `🔷 Frozen`. Refused while an open question is unticked, or the `* **Changelog:**` line is missing or malformed. Skill: `/aapp-freeze`.

### `aapp start`
```text
aapp start <id> [worktree <path> [branch <name>]]
aapp start <group> [base <branch>]
```
- `<id>`: a frozen plan becomes `⚡ In Development`; the commit and changelog modes are recorded in its header. With `aapp.planWorktrees on` (and always for a group member or a plan made for an issue) it gets its own branch and worktree; otherwise the active-plan buffer of this checkout is bound to it. A plan whose Target Files overlap another plan in development is refused.
- `worktree <path>`: a worktree at `<path>` for this start, whatever the setting says; `branch <name>`: the plan branch's name.
- `<group> [base <branch>]`: starts a group: cuts its feature branch from the development branch (or `<branch>`) and starts its amendments member.

Settings: [Plans & Worktrees](03-configuration-matrix.md#plans--worktrees) (`aapp.planWorktrees`, `aapp.planBranch`, `aapp.planWorktreePath`, `aapp.planSession`). Skill: `/aapp-start`.

### `aapp freeze-start`
```text
aapp freeze-start <id> [worktree <path> [branch <name>]]
```
- `freeze` then `start`, in one step, with the same tokens as `start`.

### `aapp done`
```text
aapp done <id> [integrate [squash | ff | hook] [target <branch>] [no-cleanup] [force-cleanup] [override-hotfix-cap] | no-integrate]
```
- Archives an implemented plan: moves it to `.plans/done/`, appends the archive ledger, updates the matrix, closes its Target Issue and the issues it lists under `Also Closes`, and fires `pre-done` (a gate, e.g. green tests) and `post-done`.
- For a plan with its own worktree, integrates its branch per `aapp.integrate`; `integrate` (or a strategy name: `squash`, `ff`, `hook`) integrates now, `target <branch>` names the target, `no-integrate` archives only.
- `no-cleanup` keeps the worktree and branch; `force-cleanup` removes them even with ignored files inside; `override-hotfix-cap` is a person's sign-off past `aapp.maxEmergencyHotfixes`.
- A group's `done` merges its feature branch into its parent; its amendments member is archived last.

Settings: [Integration](03-configuration-matrix.md#integration). Background: [10. Integration & Rebase](10-integration-and-rebase.md). Skill: `/aapp-done`.

### `aapp commit`
```text
aapp commit "<msg>" [agent <A> vendor <V> model <M>] [note "<text>"] [changelog "<text>"]
aapp commit amend ["<msg>"]
aapp commit adopt <sha>…
aapp commit "<msg>" amendment <n>
```
- `"<msg>"`: commits the staged code for the active plan with the attribution the repository asks for, records `sha (branch)` in the plan's `Commits:`, and on the plan's first commit writes its changelog entry. **Not to be confused with `aapp refine`, which commits plan text.**
- `agent`/`vendor`/`model`: the AI identity for the trailers (or `AAPP_AGENT_*`, or `aapp.aiAgent`/`aiVendor`/`aiModel`).
- `note "<text>"`: attaches a Git note to the commit.
- `changelog "<text>"`: the entry for a fix's mini plan.
- `amend`: folds staged changes into the plan's last commit and replaces the recorded hash (the way to change an `atomic` plan after its first commit).
- `adopt <sha>…`: records commits made with raw `git commit`.
- `amendment <n>`: the one commit of an approved group amendment request ([16](16-group-amendments.md)).

Settings: [Commits & Changelog](03-configuration-matrix.md#commits--changelog), [Attribution & Notes](03-configuration-matrix.md#attribution--notes).

### `aapp active`
```text
aapp active [id | swap | clear]
```
- *(no argument)*: shows the active-plan buffer of this checkout, or binds the single plan in development no other worktree holds.
- `<id>`: binds that plan. `swap`: back to the previous value. `clear`: empties the buffer.

### `aapp note`
```text
aapp note [status]
aapp note stage "<text>" msg "<commit-msg>" | msg-file <path> [agent <A> vendor <V> model <M>]
aapp note push [remote] | pull [remote]
```
- `status` (default): the notes remote, merge and rewrite settings, guard level and pending note buffers.
- `stage`: prepares a note for a commit you are about to make, keyed by its message; the `post-commit` hook attaches it. With `agent`, the note goes to `refs/notes/ai`, else `refs/notes/commits`.
- `push` / `pull`: notes to and from a remote (`aapp.notesRemote` by default); pulls merge as a union.

Settings: [Attribution & Notes](03-configuration-matrix.md#attribution--notes). Background: [05. AI Attribution](05-ai-attribution-and-notes.md).

### `aapp issue`
```text
aapp issue log <sev> <type> "<symptom>" [file <path>]… [branch <name>] [note "<text>"]
aapp issue hotfix "<text>" [file <path>]… [branch <name>] [note "<text>"] [plan]
aapp issue fix next-blocker
aapp issue fix <num> [file <path> ["<why>"]]… [group <group>] [force]
aapp issue fix <num> abort
aapp issue queue <num> [urgent | low | remove]
aapp issue close <id> [sha <sha>] [summary "<text>"]
aapp issue abort <num> [reason "<text>"] [keep-branch] [force] [force-cleanup] [confirm]
aapp issue list [<n> | all] [confirm] [json]
aapp issue list note <num>
```
- `log`: logs an issue: takes its id, writes the row (`<sev>`: Critical, High, Medium or Low; `<type>`: an uppercase token) and commits. `file` fills its Location; `branch` names where its fix must land; `note` is its description, kept outside Git.
- `hotfix`: from a plan's worktree, logs a bug that blocks the plan, queues it as a plan blocker and blocks the plan, in one commit; `plan` drafts a plan for it instead of queueing.
- `fix <num>` / `fix next-blocker`: from the main checkout, opens a temporary mini plan for one queued issue in `.workspace/fix-<num>`, one fix at a time. `file <path> "<why>"` declares a file beyond the issue's Location; `group <group>` makes the fix land on a group's feature branch; `force` overrides a `refuse` collision setting. `fix <num> abort` drops the mini plan.
- `queue <num>`: clears an issue for work, at Normal, `urgent` or `low` level; `remove` takes it off. **A person's decision: agents never run it.**
- `close <id>`: closes a fixed issue: its fix lands as one commit and the row moves to the archive. `sha` and `summary` set what the archive records.
- `abort <num>`: withdraws an issue that is wrong or unwanted, with its plan or open mini plan; only when a person asks. The other tokens pass to `aapp plan abort`.
- `list`: the open issues (20 by default; `<n>` or `all`); `json` as a document; `list note <num>`: one issue with its description and notes.

Settings: [Issues & Fixes](03-configuration-matrix.md#issues--fixes). Background: [03. Two Lanes](../concepts/03-two-lane-governance.md), [07. Issue Protocol](07-issue-protocol.md). Skill: `/aapp-fix`.

### `aapp offline`
```text
aapp offline [status | mount | unmount [force] | on | off | sync]
```
- `status` (default): what is staged in `.offline` while the team's provider is unreachable.
- `mount` / `unmount [force]`: creates or removes the `.offline` worktree (`force` when something is still staged).
- `on` / `off`: offline-only: the provider is not asked at all, until `off`.
- `sync`: publishes what is staged, giving each item its real id, once the provider answers.

Settings: [Offline](03-configuration-matrix.md#offline).

### `aapp companion`
```text
aapp companion add <name> <path> [worktree] | add <name> <url>
aapp companion list | status [name] | push <name> | remove <name> [force]
```
Registers other repositories worked on together with this one: [17. Companion Development](17-companion-development.md).

### `aapp test`
```text
aapp test [modifier…] [verb [name] | suite…]
```
- Runs the **kit's own** bash test suites, never your project's tests. Modifiers: `list`, `strict`, `quiet`, `bail`, `jobs <n>`. `verb [name]` runs the verb suites; a suite name runs that suite. The kit's Perl tests run with `t/test-run` ([CONTRIBUTING.md](../../CONTRIBUTING.md)).

### `aapp help`
```text
aapp help [<verb> [full]]
```
- The catalog of verbs; `<verb>` its arguments; `full` its refusals, effects and tests. `aapp <verb> help`, `-h` and `--help` work too.

### `aapp ai`
```text
aapp ai [status | none | lax | strict | notes [on | off] | credits]
```
- `status` (default): the attribution mode, notes and credits settings.
- `none` / `lax` / `strict` / `notes`: sets `aapp.aiAttribution`. `notes on|off`: turns parallel notes on or off (`aapp.aiNotes`) without changing the mode.
- `credits`: writes the `AI Contributors` block into `README.md`.

Settings: [Attribution & Notes](03-configuration-matrix.md#attribution--notes). Background: [05. AI Attribution](05-ai-attribution-and-notes.md).

---

## 2. Setup & Maintenance

### `aapp init`
- Sets up the repository, or brings it to the installed kit's protocol: the `.plans`, `.agents` and `.githooks` worktrees (mounted from the remote's branches when they exist), the rules and starter files, hooks, agent wiring, default settings, the Plan ID counter and the adoption checklist. Safe to run again. Walk-through: [Adopting an Existing Repository](../recipes/getting-started/adopt-existing-repo.md). Setting: [`aapp.templateSync`](03-configuration-matrix.md#release--templates).

### `aapp install`
- Installs the kit for your user: `aapp` in `~/.local/bin`, its files in `${XDG_DATA_HOME:-~/.local/share}/aapp-kit/`; offers to add `~/.local/bin` to `PATH`. It then deletes the clone it ran from, unless that is a development clone ([CONTRIBUTING.md](../../CONTRIBUTING.md)).

### `aapp upgrade`
- Fetches the latest kit (`AAPP_UPSTREAM_URL`, default the public repository) and installs it; then run `aapp init` in each project.

### `aapp develop`
- Makes this clone the installed kit, through links, so edits are live everywhere ([CONTRIBUTING.md](../../CONTRIBUTING.md)).

### `aapp uninstall`
- Removes the installed kit (`~/.local/bin/aapp` and its files). Projects keep their `.plans`, `.agents` and `.githooks`.

### `aapp version`
- The installed version (also `-v`, `--version`).

### `aapp release`
```text
aapp release <version-or-bump> [check] [yes] [push] [json] [unverified] [no-archive] [no-changelog]
```
- `<version-or-bump>`: an explicit version (`1.2.0`, `v1.0.1.alpha`) or `patch`, `minor`, `major`.
- Phase A, pre-flight (read-only): clean worktrees (plan worktrees in flight excepted), the test gate (`aapp.testCommand`), the `pre-release` gate hook, whether tags can be signed (`tag.gpgSign`), the changelog, that each recorded commit is reachable (an ancestor of the release, or carried by a `Plan-ID:` trailer), and that the branches fast-forward.
- Phase B: `on-release` handlers (the kit itself uses one, `scripts/kit-on-release.sh`, to stamp its version), the changelog rolled up under the version, completed plans moved from `.plans/done/` to `.plans/release/<tag>/plans/` with the archived issues, the release's own ledger plus `manifest.md` and `manifest.json`, a one-line summary left in the master ledger, the merge to the release branch and the tag. Any failure rolls everything back. Then `post-release` fires and the publication commands are printed (or run, with `push`).
- `check`: Phase A only, nothing changed. `yes`: no confirmation prompt. `push`: pushes the release branch, tags and plans branch afterwards. `json`: the result as a document. `unverified`: records the release as unverified instead of refusing unreachable commits. `no-archive`: no bundling. `no-changelog`: no changelog check or rollup.

Settings: [Release & Templates](03-configuration-matrix.md#release--templates). Skill: `/aapp-release`.

---

## 3. Sync & Emergency Brake

### `aapp push`, `aapp pull`, `aapp sync`
```text
aapp push | pull | sync [remote] [builtin | hook]
```
- `push`: the planning worktrees to the remote; `pull`: from it, fast-forward only; `sync`: pull, then push. Every worktree must be clean first.
- `[remote]`: overrides `aapp.remote`; `builtin` / `hook`: overrides `aapp.syncStrategy` for this run.

Details: [12. Git Plumbing](12-git-plumbing.md#push-pull-and-sync). Settings: [Branches, Remote & Sync](03-configuration-matrix.md#branches-remote--sync).

### `aapp pause`, `aapp resume`
```text
aapp pause [shared] [reason]
aapp resume
```
- `pause`: the emergency brake. In-flight changes in every mounted worktree are set aside into named stashes, leaving the trees clean, and writes to code, rules, templates and hooks are refused until `resume`. Running it again while paused shows the pause.
  - It refuses while a merge, rebase or cherry-pick is unfinished in any worktree.
  - Stashes include untracked files but never ignored ones (`git stash push --include-untracked`, never `--all`), so private files such as `.plans/pickup/` stay where they are. Which files were staged is recorded, and restored as unstaged.
  - All or nothing: if one worktree cannot be stashed, every stash made by that run is undone.
  - The pause is recorded in `$(git rev-parse --git-common-dir)/aapp_paused`, shared by all worktrees of the clone. While paused, only `.plans/` pickup, issue and `current/` files may change.
- `shared`: also commits `.plans/PAUSED.md`, so the pause reaches the team through `aapp push`.
- `resume` (or `unpause`): checks for commits made since the pause, restores the stashes, runs the planning health check and lifts the brake.

Skill: `/aapp-pause`.

---

## 4. Hooks & Plugins

```text
aapp hooks [events]
aapp plugins
aapp hook-test <event> [plan-id]      (also: aapp hook-run)
aapp hook-hash <file> [event] [timeout] [mode]
```
What each does: [04. Plugin & Hook Engine §9](04-plugin-and-hook-engine.md#9-hook-and-plugin-commands). Any other word that names a plugin in `.agents/skills/<name>/` runs that plugin: `aapp <name> [args…]` ([§10](04-plugin-and-hook-engine.md#10-plugins-as-commands)).

---

## 5. A Terminal-Only Day

Everything an agent does through skills, a person can do from the terminal:

```bash
aapp status                         # the briefing
aapp draft my-feature               # P-20, in .plans/current/P20-my-feature.md
#   edit §2 (design) and §4 (Target Files), answer §5, then:
aapp refine P-20 "design and targets"
aapp freeze-start P-20              # lock and start (own worktree with aapp.planWorktrees on)
#   work inside the Target Files, then:
git add src/
aapp commit "feat(core): add my-feature"
aapp done P-20                      # archive, integrate, close its issue
```

---

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- ⚙️ [Configuration Reference](03-configuration-matrix.md)
- 🍳 [Cookbook Catalog](../../COOKBOOK.md)
- 🏠 [Repository Overview](../../README.md)
