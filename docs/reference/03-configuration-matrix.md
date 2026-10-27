---
title: Configuration Reference
description: Every aapp.* setting the kit reads, grouped by role, with its type, default, the verbs that read it and every value it accepts; and the environment variables the kit reads.
---

# ⚙️ Configuration Reference

The kit's settings are Git configuration keys under `aapp.*`, set per repository with `git config aapp.<key> <value>` (`git config --add` for a key that takes several values; `git config --unset` returns a key to its default). Key names are not case-sensitive. How values from system and user files are layered over the repository's is [15. Configuration Hierarchy](15-configuration-hierarchy.md).

`aapp init` writes some keys with their defaults so they are visible in `.git/config`; a key that is not set behaves as its default. Only the keys marked *allowed in system and user files* may be set in those files; any other key there is refused.

**Groups:** [Attribution & Notes](#attribution--notes) · [Commits & Changelog](#commits--changelog) · [Plans & Worktrees](#plans--worktrees) · [Groups & Amendments](#groups--amendments) · [Issues & Fixes](#issues--fixes) · [Integration](#integration) · [Branches, Remote & Sync](#branches-remote--sync) · [Write Guard](#write-guard) · [Hooks & Plugins](#hooks--plugins) · [Offline](#offline) · [Status & Output](#status--output) · [Release & Templates](#release--templates) · [Companion](#companion) · [Logging](#logging) · [Environment Variables](#environment-variables)

---

## Attribution & Notes

How commits record which agent wrote them. Background: [05. AI Attribution & Notes](05-ai-attribution-and-notes.md).

### `aapp.aiAttribution`
Enum · default `none` · read by `aapp commit`, the `commit-msg` hook, `aapp ai` · set by `aapp ai <mode>` · allowed in system and user files
- `none`: human authoring only; AI trailers in a commit message are refused. Notes still work through `aapp note` and `note "<text>"`.
- `lax`: AI trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`) are checked when present; commits without them pass.
- `strict`: every commit must carry the three trailers.
- `notes`: commit messages stay free of trailers; the identity is recorded as a Git note in `refs/notes/ai` (and `aapp.aiNotes` is set `true`).

### `aapp.aiNotes`
Boolean · default `false` · read by `aapp commit`, `aapp ai` · set by `aapp ai notes on|off` · allowed in system and user files
- `true`: each AI commit also gets a Git note in `refs/notes/ai`, alongside whatever `aapp.aiAttribution` writes.
- `false`: a note is attached only when `note "<text>"` is given, or in `notes` mode.

### `aapp.aiNotesGuard`
Enum · default `warn` · read by `aapp note`
- `warn`: Git's own note settings are left as they are; `aapp note status` reports them.
- `enforce`: the kit sets `notes.rewriteMode concatenate`, so notes survive an amend or rebase that merges commits.

### `aapp.aiAlias`
Multi-valued · default none · read by `aapp commit`, `aapp ai`
- Each value is `<from>=<to>`: an agent name as reported is replaced by `<to>` before it is written to a trailer or note (`git config --add aapp.aiAlias "claude-code=Claude"`).

### `aapp.aiAgent`, `aapp.aiVendor`, `aapp.aiModel`
Text · default none · per worktree (`git config --worktree`) · read by `aapp commit`
- The agent identity for commits made in this worktree, used when neither `agent`/`vendor`/`model` tokens nor the `AAPP_AGENT_*` variables give it. Plain repository config is never read for these, so one checkout's identity never leaks into another.

### `aapp.aiCredits`
Boolean · default `false` · set by `aapp ai credits`, cleared by `aapp ai none` · shown by `aapp ai`
- `true`: records that the `AI Contributors` block in `README.md` is in use. The block is written when `aapp ai credits` runs; nothing refreshes it on its own.
- `false`: no block is maintained.

### `aapp.notesRemote`
Remote name · default none · read by `aapp note push|pull`, `aapp sync`
- Unset: notes stay local; `aapp note push` and `pull` need a remote argument.
- `<remote>`: notes are pushed to and pulled from that remote, and `aapp sync` carries them.

### `aapp.noteTTL`
Minutes · default `1440` · read by the `post-commit` hook
- A staged note buffer that no commit claimed is removed after this many minutes.

---

## Commits & Changelog

Commit message limits and how plan work reaches `CHANGELOG.md`.

### `aapp.commitMode`
Enum · default `atomic` · read by `aapp commit`, the `pre-commit` hook · recorded in each plan's header when the plan starts
- `atomic`: a plan is one commit; after its first `aapp commit`, further changes are folded in with `aapp commit amend`, and a second commit is refused.
- `microcommits`: a plan may have any number of commits. A group's amendments member always uses this mode.

### `aapp.changelogMode`
Enum · default `plan` · read by `aapp commit`, the `pre-commit` hook · recorded in each plan's header
- `plan`: a plan declares one entry in its `* **Changelog:**` line; `aapp commit` writes it under `## [Unreleased]` on the plan's first commit, and later commits pass once it is there.
- `commit`: every code commit must change `CHANGELOG.md` itself.

A commit with no active plan (a direct fix) must change `CHANGELOG.md` in either mode.

### `aapp.changelogMaxLen`
Characters · default `300` · read by the `pre-commit` hook, `aapp commit`, `aapp freeze`
- The longest a changelog bullet may be.

### `aapp.subjectMaxLen`
Characters · default `72` · read by the `commit-msg` hook, `aapp refine`, `aapp issue`, `aapp done` · allowed in system and user files · a value that is not a positive whole number counts as `72`
- The longest a commit subject may be, for code commits and for the kit's own plans commits.

### `aapp.commitLineMaxLen`
Characters · default `100` · read by the `commit-msg` hook · allowed in system and user files
- The longest a line of a commit body may be; a line holding an unbroken URL is exempt.

### `aapp.bodyMaxLen`
Characters · default `1200` · read by the `commit-msg` hook · allowed in system and user files
- The most characters a commit body may have, trailers excluded.

### `aapp.maxBodyLines`
Lines · default `20` · read by the `commit-msg` hook
- The most lines a commit body may have, trailers excluded.

### `aapp.docs`
Boolean · default `true` · read by the `pre-commit` hook, `lib/adoption.sh`
- `true`: a commit that stages code without touching `README.md`, `ARCHITECTURE.md` or `CODEMAP.md` prints a reminder (for a group member: a reminder that those changes go into the group plan). The reminder never refuses.
- `false`: no reminder, and the documentation adoption tasks are not listed.

---

## Plans & Worktrees

Plan ids, plan branches and worktrees, and plan statuses.

### `aapp.planId`
Whole number · seeded by `aapp init` from the highest plan id found · written by `aapp draft`
- The next Plan ID the kit's counter gives. Do not set it by hand except to skip ids; a team shares ids through an `aapp-planid` provider ([18. Plan ID Allocation](18-plan-id-allocation.md)).

### `aapp.planWorktrees`
Enum · default `off` · read by `aapp start`, `aapp freeze-start`
- `on`: a plan's first start creates its own branch (`aapp.planBranch`) and worktree (`aapp.planWorktreePath`); work happens there and `aapp done` integrates it ([Integration](#integration)).
- `off`: plans are worked in the checkout that starts them. A group's members and a plan drafted for an issue get their own worktree whatever this says.

### `aapp.planBranch`
Template · default `plan/{id}-{slug}` · read by `aapp start`
- The name of a plan's branch. Placeholders: `{id}` (`P51`), `{num}` (`51`), `{slug}`, `{repo}` (the repository folder's name). A result that is not a valid branch name is refused.

### `aapp.planWorktreePath`
Template · default `.workspace/{id}` · read by `aapp start`, `lib/adoption.sh`
- Where a plan's worktree is created, relative to the primary checkout; same placeholders as `aapp.planBranch`.

### `aapp.planSession`
Command template · default none (personal) · read by `aapp start`
- Unset: `start` prints the worktree to `cd` into.
- `<command>`: run, detached, in a new plan worktree to open a session there (an agent CLI, a terminal, an editor). Placeholders: `{path}`, `{id}`, `{branch}`, `{slug}`, `{plan_file}`; the same values are exported as `AAPP_WORKTREE`, `AAPP_PLAN_ID`, `AAPP_BRANCH`, `AAPP_SLUG`, `AAPP_PLAN_FILE`. Its output goes to a log file; a command that cannot start is reported and the plan stays started.

### `aapp.planState.<slug>`
Text, one key per status · default the kit's statuses · read by `aapp matrix`, `aapp status` and every verb that reads a plan's Status
- `<emoji>|<name>|<heading>|<rank>`: declares a plan status. A slug of a kit status (`under-review`, `refining`, `frozen`, `in-development`, …) replaces it; a new slug adds one. `<heading>` is the `state_matrix.md` section it is listed under, `<rank>` orders the sections.

### `aapp.pickupTitleMax`
Characters, at least `10` · default `72` · read by `aapp refine pickup`, `aapp status`
- The longest an idea's title in `pickup.md` may be. A value below 10 or not a whole number is refused, naming the key.

---

## Groups & Amendments

### `aapp.amendmentApprovalRequired`
Boolean · default `true` · read by `aapp refine <amend-id> request|approve|decision`
- `true`: a member's request waits for an approver (`approve <n>` / `refuse <n> "<reason>"`), a person or a managing agent.
- `false`: a file request is `approved (auto)` when made; a correction of the group's text is recorded with `decision "<heading>" "<reason>"`.
- Any other value is refused, naming the key. Flow: [16. Group Amendments](16-group-amendments.md).

---

## Issues & Fixes

The issue lane: ids, fixes and their limits. Background: [07. Issue Tracker Protocol](07-issue-protocol.md).

### `aapp.issueId`
Whole number · unset in a fresh clone · written by `aapp issue log`, `aapp issue hotfix`
- The next issue id the kit's counter gives when no tracker numbers the issue. When unset, it is seeded from both issue ledgers on first use.

### `aapp.issueFixWait`
Minutes · default `5` · read by `aapp issue fix`, the issue lock
- How long `fix` waits, printing each wait, while another fix is open. `0`: fail at once (for dispatch runners).

### `aapp.fixMaxFiles`
Files · default `3` · read by `aapp issue close`, `aapp issue fix <num> abort` · allowed in system and user files
- The most files an issue fix may change. `0` disables the limit. A fix over it is aborted and promoted to a plan.

### `aapp.fixMaxLines`
Lines · default `25` · read by `aapp issue close`, `aapp issue fix <num> abort` · allowed in system and user files
- The most lines (added plus deleted, `CHANGELOG.md` excluded) an issue fix may change. `0` disables the limit.

### `aapp.fixCollision`
Enum · default `notice` · read by `aapp issue fix`
- `notice`: when a plan in development lists a file of the fix, a notice names the plan, which rebases over the fix.
- `refuse`: the fix is refused unless `force` is given.

### `aapp.maxEmergencyHotfixes`
Whole number · default `2` · read by `aapp issue hotfix`, `aapp done` · allowed in system and user files
- How many hotfixes a plan may take. The next one blocks the plan until a person re-scopes it, and `done` refuses to integrate a plan over the limit.

### `aapp.issueArchiveMax`
Rows · default none (no limit) · read by `aapp issue close`, `aapp done`
- Unset or `0`: `.plans/done/000-issues-archive.md` grows without limit.
- `<n>`: past `<n>` rows, the oldest rows move to `000-issues-archive-overflow.md`.

### `aapp.issueSyncWindow`
Minutes · default `15` · read by `aapp status`
- The least time between two syncs with a provider that lists issues, counted from the last attempt.

### `aapp.issueCacheMax`
Issues · default `200` · read by `aapp issue list`, `aapp status`
- How many open issues are kept from a tracker's listing; issues the plans depend on are kept beyond it.

---

## Integration

How `aapp done` lands a plan's branch. Background: [10. Integration & Rebase](10-integration-and-rebase.md).

### `aapp.integrate`
Enum · default `manual` · read by `aapp done`
- `manual`: `done` archives the plan without integrating its branch; `aapp done <id> integrate` integrates on request (`squash`), or name the strategy: `aapp done <id> squash|ff|hook`. `no-integrate` archives only, whatever this setting says.
- `squash`: the branch lands as one commit on the target.
- `ff`: the target fast-forwards to the branch, keeping its commits.
- `hook`: an `on-integrate` handler does the merge; refused when none is registered.
- Any other value is refused, naming the key.

Only a plan with its own worktree integrates; a plan worked in the main checkout has its commits on the development branch already. In every mode, a branch that does not contain the target's tip is refused with the rebase command to run, unless `aapp.autoRebase` is on.

### `aapp.integrateTarget`
Enum or branch · default `parent` · read by `aapp done`
- `parent`: the branch named in the plan's `* **Base:**`.
- `dev`: the development branch (`aapp.devBranch`).
- `<branch>`: that branch.

### `aapp.integrateCleanup`
Boolean · default `true` · read by `aapp done`
- `true`: the plan's worktree and branch are removed after integrating.
- `false`: both are kept. The `no-cleanup` token does the same for one `done`.

### `aapp.integrateWait`
Seconds · default `15` · read by `aapp done`, `aapp issue close`
- How long a landing waits for the `integrate/<branch>` lock held by another landing. `done` keeps the value between 10 and 600.

### `aapp.autoRebase`
Boolean · default `false` · read by `aapp done`
- `true`: a plan branch that does not contain its target's tip is rebased onto it (`git rebase --autostash`) before integrating, and the plan's recorded commits are updated; a rebase with conflicts is undone and stops `done`.
- `false`: such a branch is refused with the rebase command to run.

### `aapp.quarantineIgnored`
Boolean · default `false` · read by `aapp done`, `aapp plan abort` · allowed in system and user files
- `false`: when the worktree to remove holds ignored files (build output, local secrets), cleanup stops and names them; back them up, or add `force-cleanup`.
- `true`: those files are copied to a quarantine folder in the Git directory before the worktree is removed.

---

## Branches, Remote & Sync

The development branch, branch protection, and how the planning worktrees travel between machines. Background: [12. Git Plumbing](12-git-plumbing.md).

### `aapp.devBranch`
Branch names, space-separated · default `develop dev development` · read by the `pre-commit` hook, `aapp start`, `aapp release`, `aapp issue`
- The development branch: the first name that exists, locally or on a remote, wins. Plans branch from it, fixes land on it, and branch protection steers commits to it. No match: the repository's default branch is used.

### `aapp.protectedBranches`
Branch names, space-separated · default `main master production` · read by the `pre-commit` hook, `aapp release`
- Branches where direct commits are refused while a development branch exists (`aapp.protectStable`), and the candidates for the release branch.

### `aapp.protectStable`
Boolean · default `true` · read by the `pre-commit` hook
- `true`: a commit on a protected branch is refused while a development branch exists; `ALLOW_MAIN_COMMIT=1` lets one intentional commit through.
- `false`: no branch protection (trunk-based development).

### `aapp.remote`
Remote name · default `origin` (set by `aapp init` to the remote it finds) · read by `aapp push`, `aapp pull`, `aapp sync`, `aapp issue`, `aapp status`
- The remote the planning worktrees are pushed to and pulled from, and whose URL names the repository's local state folder.

### `aapp.syncWorktrees`
Worktree names, space-separated · default `plans agents githooks` · read by `aapp push`, `aapp pull`, `aapp sync`
- Which of the kit's worktrees travel. `offline` is refused: the `.offline` worktree never leaves the machine.

### `aapp.syncStrategy`
Enum · default `builtin` (`hook` when `aapp init` finds an `on-sync` handler) · read by `aapp sync`
- `builtin`: the kit pushes and pulls the worktrees itself.
- `hook`: an `on-sync` handler does the transport; refused when none is registered.

### `aapp.pullStrategy`
Git pull mode · default `ff-only` · read by `aapp pull`, `aapp sync`
- Passed to `git pull` as `--<value>`. Keep `ff-only`: a planning worktree that cannot fast-forward stops the pull instead of merging.

---

## Write Guard

What the write guard lets an agent write outside the plan's Target Files. Background: [02. Blast Radius Engine](../concepts/02-blast-radius-engine.md).

### `aapp.allowPath`
Paths, multi-valued · default none · read by the write guard, `aapp companion` · allowed in system and user files
- Each value is a folder outside the repository that agents may write to, added to the guard's built-in list: `~/.claude`, `~/.gemini`, `~/.codex`, `~/.cursor`, `$XDG_CONFIG_HOME` (`~/.config`), `$XDG_DATA_HOME` (`~/.local/share`), `$TMPDIR`, `/tmp` and, on macOS, `/var/folders`.
- Credentials, shell start-up files and `~/.local/bin` are always refused, whatever this list says (`~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.gitconfig`, `~/.bashrc`, `~/.zshrc`, crontab, …).
- `aapp companion add` adds a companion's path here and `remove` takes it off.

---

## Hooks & Plugins

Background: [04. Plugin & Hook Engine](04-plugin-and-hook-engine.md).

### `aapp.hook.<event>`
Command, multi-valued · default none · read by every verb that fires `<event>` · allowed in system and user files
- A local handler for a lifecycle event (`git config --add aapp.hook.on-done "<command>"`). Local handlers run in `notify` mode: they observe and can never refuse a step; only handlers in the committed `registry.tsv` can gate.

### `aapp.allowLocalHooks`
Boolean · default `true` · read by the hook dispatcher, `aapp hooks`
- `true`: `aapp.hook.<event>` handlers run.
- `false`: they are ignored (CI confinement), and `aapp hooks` says so.

### `aapp.hookTimeout`
Seconds · default `10` · read by the hook dispatcher
- How long a local `aapp.hook.<event>` handler may run.

### `aapp.pluginTimeout`
Seconds · default `10` · read by the plugin runner
- How long one plugin step (a provider or action plugin) may take.

### Settings of the shipped samples
Read by the samples in `examples/` once you adopt them, not by the kit:

| Setting | Sample | Effect |
| :--- | :--- | :--- |
| `aapp.logFile` / `AAPP_LOG_FILE` | `examples/hooks/event-logger.sample` | Where the event log is written (the variable wins). Default `$(git rev-parse --git-path aapp_events.jsonl)`. |
| `AAPP_PLANID_CMD` | `examples/plugins/aapp-planid/run.sample` | The plan-id provider command it calls. Default `~/.local/bin/aapp-planid-provider`. |
| `AAPP_SAMPLE_TRACKER_FILE` | `examples/plugins/aapp-issue-tracker/run.sample` | Where the sample tracker keeps its issues. |
| `AAPP_SAMPLE_TRACKER_LISTS=1` | `examples/plugins/aapp-issue-tracker/run.sample` | The sample tracker answers issue listings. |

---

## Offline

What happens when the team's provider (issue tracker, plan-id provider) cannot be reached. Background: `aapp help offline`.

### `aapp.offlineEnabled`
Boolean · default `true` · read by `aapp issue log`, `aapp draft`
- `true`: when the provider fails, the issue or draft plan is staged in `.offline` under a temporary id and published later with `aapp offline sync`.
- `false`: a failing provider refuses the step; nothing is staged.

### `aapp.offlineOnly`
Boolean · default `false` · set by `aapp offline on|off`
- `true`: the provider is not asked; issues and draft plans are staged at once.
- `false`: the provider is asked first.

### `aapp.offlineIdOffset`
Whole number · default `1000` · read by `aapp offline`
- The distance between the highest known id and the first temporary offline id, so temporary ids never collide with real ones.

---

## Status & Output

The briefing and the JSON documents. Background: [08. JSON Output Schemas](08-output-json.md).

### `aapp.statusOutputWidth`
Characters, at least `40` · default `85` · read by `aapp status`, `aapp issue list`
- The longest a line of the briefing may be. Below 40 or not a whole number is refused, naming the key.

### `aapp.statusItemsMax`
Whole number, at least `1` · default `5` · read by `aapp status`
- How many Shipped entries and pickup ideas the briefing lists.

### `aapp.statusTextMax`
Characters, at least `1` · default `220` · read by `aapp status`
- How much of an entry's or idea's text the briefing shows; longer text is cut at a word with `…`.

### `aapp.jsonLocalPath`
Boolean · default `true` · read by every `json` output
- `true`: `repository.root` holds the local path.
- `false`: it is `null`, so a published document names no local path.
- Any other value is refused, naming the key.

---

## Release & Templates

### `aapp.tagPrefix`
Text · default `v` · read by `aapp release`
- Put before the version in a release tag (`v1.2.0`); set it empty for bare versions.

### `aapp.initialVersion`
Version · default none · read by `aapp release`
- The version a bump (`patch`, `minor`, `major`) starts from when no release tag exists yet. Unset: the first release needs an explicit version.

### `aapp.releaseBranch`
Branch · default the first of `aapp.protectedBranches` that exists, else `main` · read by `aapp release`
- The branch releases are cut from.

### `aapp.testCommand`
Command · default none · read by `aapp release`
- Unset: `release` runs no tests.
- `<command>`: run as the release's test gate; a failure refuses the release. (Tests on `aapp done` are a `pre-done` gate hook: [04](04-plugin-and-hook-engine.md).)

### `aapp.templateSync`
Enum · default `safe` · read by `aapp init`, `aapp upgrade`
In every mode a missing file is created from its template, and project data files (ledgers, state matrix) are never overwritten ([11. Document Governance](11-document-governance.md)).
- `safe`: in a file with the kit's managed block (`<!-- AAPP-PROTOCOL:START … END -->`), the block is refreshed and the rest is kept. A template file without a block that differs from the kit's is kept, and the kit's version is written beside it as `<file>.new`.
- `strict`: managed blocks are refreshed as in `safe`; a template file without a block that differs is overwritten with the kit's version.
- `manual`: existing files are left untouched.
- Any other value counts as `safe`.

---

## Companion

Written by `aapp companion`; set them with that verb, not by hand. Background: [17. Companion Development](17-companion-development.md).

### `aapp.companion.<name>.path`, `aapp.companion.<name>.mode`
Path and enum · read by `aapp companion`, the write guard
- `path`: where companion `<name>` lives (also added to `aapp.allowPath`).
- `mode`: `checkout` (an existing folder), `worktree` (a worktree of this repository), or `clone` (a clone the kit made).

---

## Logging

### `aapp.perlLogFile`
Path · default none · read by the Perl modules · allowed in system and user files
- Unset: no log file.
- `<path>`: the Perl modules append their log lines there; a relative path is taken from the repository's common Git directory. Lines are plain text. Until the bash verbs are replaced, only the Perl parts of the kit log.

---

## Environment Variables

| Variable | Read by | Effect |
| :--- | :--- | :--- |
| `AAPP_AGENT_NAME`, `AAPP_AGENT_VENDOR`, `AAPP_AGENT_MODEL` | `aapp commit` | The agent identity, when the `agent`/`vendor`/`model` tokens are not given; before `aapp.aiAgent`/`aiVendor`/`aiModel`. |
| `SKIP_BLAST_RADIUS=1` | write guard, `pre-commit` hook | Emergency escape: skips the write guard and the commit-time Blast Radius and changelog checks. |
| `ALLOW_MAIN_COMMIT=1` | `pre-commit` hook | Lets one commit through on a protected branch. |
| `AAPP_STATE_DIR` | issue lane, `aapp status` | Where the kit keeps per-repository state outside Git (issue descriptions and notes, caches). Default `$XDG_STATE_HOME`, else `~/.local/state`, then `aapp/<key>/`. |
| `XDG_DATA_HOME` | `aapp install`, `aapp upgrade`, hooks | Where the installed kit lives: `${XDG_DATA_HOME:-~/.local/share}/aapp-kit`. |
| `AAPP_UPSTREAM_URL` | `aapp upgrade` | The repository the kit is upgraded from. Default `https://github.com/aapp-protocol/aapp-kit.git`. |
| `AAPP_ACTOR` | hook dispatcher | Who triggered an event, passed to handlers. Default `developer`. |
| `AAPP_TEST_SANDBOX_STRICT=1` | the kit's test suites | Fail-closed sandbox containment while testing the kit (`aapp test strict`). |

Exported by the kit, not read: to handlers (see [04](04-plugin-and-hook-engine.md)) and, from `aapp start`, to a session opened by `aapp.planSession` (`AAPP_PLAN_ID`, `AAPP_WORKTREE`, `AAPP_BRANCH`, `AAPP_SLUG`, `AAPP_PLAN_FILE`).

---

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🗂️ [Configuration Hierarchy](15-configuration-hierarchy.md)
- 💻 [CLI Verb Reference](02-cli-commands-and-verbs.md)
- 🏠 [Repository Overview](../../README.md)
