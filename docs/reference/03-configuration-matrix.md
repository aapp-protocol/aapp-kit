---
title: Repository Configuration Reference
description: Complete matrix of Git configuration keys (git config aapp.*), environment variables, and subsystem defaults.
---

# ⚙️ Repository Configuration Reference

AAPP controls repository policies, attribution modes, hook behaviors, and worktree synchronization via standard Git configuration keys (`git config aapp.<key>`).

---

## Complete Configuration Settings Matrix

| Setting Key | Type / Enum | Default | Subsystem | Purpose & Behavior |
| :--- | :--- | :--- | :--- | :--- |
| `aapp.planId` | integer | `1` | Core / Lifecycle | Monotonic Plan ID allocation counter (claimed via `allocate_plan_id`). |
| `aapp.issueId` | integer | *(unset)* | Core / Lifecycle | The kit's issue counter (`aapp issue log` takes the next id when no tracker numbers the issue; seeded from both issue ledgers on first use). |
| `aapp.statusOutputWidth` | integer (≥ 40) | `85` | `aapp status`, `aapp issue list` | The most characters on a line of the briefing. |
| `aapp.statusItemsMax` | integer (≥ 1) | `5` | `aapp status` | How many Shipped entries and pickup ideas the briefing lists. |
| `aapp.jsonLocalPath` | `true` / `false` | `true` | `aapp status json`, `aapp issue list json` | `false` writes `repository.root` as `null`, so a published document names no local path. |
| `aapp.statusTextMax` | integer (≥ 1) | `220` | `aapp status` | The most characters of an entry's or idea's text the briefing shows, cut at a word with `…`. |
| `aapp.issueSyncWindow` | minutes | `15` | `aapp status` | Least time between two syncs with a provider that lists issues, counted from the last attempt. |
| `aapp.issueCacheMax` | integer | `200` | `aapp issue list`, `aapp status` | Open issues kept from a tracker's listing; issues the plans depend on are kept beyond it. |
| `aapp.offlineEnabled` | boolean | `true` | Offline | `false`: a failing provider refuses and nothing is staged in `.offline`. |
| `aapp.offlineOnly` | boolean | `false` | Offline | `true` (`aapp offline on`): the provider is not asked; issues and draft plans are staged at once. |
| `aapp.offlineIdOffset` | integer | `1000` | Offline | Distance between the highest known id and the first temporary offline id. |
| `aapp.pluginTimeout` | seconds | `10` | Plugins | How long a plugin step may take. |
| `aapp.planState.<slug>` | string (multi) | *(kit defaults)* | Core / Lifecycle | Custom plan status as `<emoji>\|<name>\|<heading>\|<rank>`; overrides a shipped status when the slug matches. |
| `aapp.aiAttribution` | `none` / `lax` / `strict` / `notes` | `none` | AI Attribution | Attribution mode (emailless semantic trailers vs. git notes vs. human). |
| `aapp.aiNotes` | `true` / `false` | `false` | AI Attribution | Enables parallel git notes attachment (`refs/notes/ai`). |
| `aapp.aiCredits` | `true` / `false` | `false` | AI Attribution | Automatically maintains alphabetical `AI Contributors` in `README.md`. |
| `aapp.subjectMaxLen` | integer | `72` | Git Hooks | Numeric conciseness limit for commit subject lines (enforced in `aapp-commit-msg`). |
| `aapp.commitLineMaxLen` | integer | `100` | Git Hooks | Maximum characters per line in commit body (enforced in `aapp-commit-msg`, URLs exempt). |
| `aapp.bodyMaxLen` | integer | `1200` | Git Hooks | Maximum characters allowed in commit message body (enforced in `aapp-commit-msg`). |
| `aapp.maxBodyLines` | integer | `20` | Git Hooks | Maximum lines allowed in commit message body (enforced in `aapp-commit-msg`). |
| `aapp.changelogMaxLen` | integer | `300` | Git Hooks | Numeric conciseness limit for single-line changelog bullet points (enforced in `aapp-pre-commit`). |
| `aapp.changelogMode` | `plan` / `commit` | `plan` | Git Hooks | `plan`: one entry per plan, declared in its `**Changelog:**` line and written by `aapp commit`; later commits for the plan pass once it is present. `commit`: every code commit changes `CHANGELOG.md`. |
| `aapp.commitMode` | `atomic` / `microcommits` | `atomic` | `aapp commit`, Git Hooks | `atomic`: one commit per plan; further changes via `aapp commit amend`. `microcommits`: any number. Recorded in each plan's header. |
| `aapp.issueFixWait` | minutes | `5` | `aapp issue fix` | How long `fix` and the issue lock wait (printing each wait) for an open fix; `0` fails at once, for dispatch runners. |
| `aapp.fixMaxFiles` | integer | `3` | `aapp issue close` | Max files changed in an issue fix before `close` refuses; `0` disables. |
| `aapp.fixMaxLines` | integer | `25` | `aapp issue close` | Max lines changed (added + deleted across fix files, excluding CHANGELOG.md) before `close` refuses; `0` disables. |
| `aapp.fixCollision` | `notice` / `refuse` | `notice` | `aapp issue fix` | Collision behavior when an active plan in development lists a fix file: `notice` warns, `refuse` refuses unless `force` is passed. |
| `aapp.maxEmergencyHotfixes` | integer | `2` | `aapp issue hotfix` | Hotfixes a plan may take; the next one blocks it permanently until re-scoped. |
| `aapp.protectStable` | `true` / `false` | `true` | Branch Guard | Refuses direct commits on `main` when dual-branch topology (`develop`) is active. |
| `aapp.protectedBranches` | string | `"main master production"` | Branch Guard | Space-separated list of protected production branches. |
| `aapp.devBranch` | string (list) | `develop dev development` | Branch Guard, `aapp start` | Candidate development branches, first present (local or remote) wins. Branch protection uses it; plan worktrees branch from it. |
| `aapp.planWorktrees` | `on` / `off` | `off` | `aapp start`, `freeze-start` | `on`: a plan's first start creates its own branch and worktree. |
| `aapp.planBranch` | template | `plan/{id}-{slug}` | `aapp start` | Plan branch name; placeholders `{id}` (`P51`), `{num}`, `{slug}`, `{repo}`. |
| `aapp.planWorktreePath` | template | `.workspace/{id}` | `aapp start` | Plan worktree path, relative to the primary checkout; same placeholders. |
| `aapp.planSession` | command template | *(unset, personal)* | `aapp start` | Opens a session (agent CLI, terminal, editor) in a new plan worktree, detached; placeholders `{path}`, `{id}`, `{branch}`, `{slug}`, `{plan_file}`. |
| `aapp.integrate` | `manual` / `squash` / `ff` / `hook` | `manual` | `aapp done` | How `done` integrates a worktree plan into its parent branch; `manual` archives and prints advice. |
| `aapp.integrateTarget` | `parent` / `dev` / `<branch>` | `parent` | `aapp done` | Integration target: the branch in the plan's `Base:`, the development branch, or a named branch. |
| `aapp.integrateCleanup` | `true` / `false` | `true` | `aapp done` | Remove the plan worktree and branch after integrating. |
| `aapp.quarantineIgnored` | `true` / `false` | `false` | `aapp done` | Copy sensitive ignored files into quarantine directory before cleanup removes them. |
| `aapp.allowPath` | string (multi) | *(empty)* | Write Guard | External filesystem paths authorized for AI file writes (`blast-radius-guard`). |
| `aapp.remote` | string | `origin` | Remote Sync | Git remote targeted by `aapp push`, `aapp pull`, and `aapp sync`. |
| `aapp.syncStrategy` | `builtin` / `hook` | `builtin` | Remote Sync | Transport engine for worktree sync (`builtin` git plumbing vs custom hook). |
| `aapp.syncWorktrees` | string (list) | `plans agents githooks` | Remote Sync | Space-delimited worktrees synchronized across remotes. |
| `aapp.pullStrategy` | `ff-only` | `ff-only` | Remote Sync | Non-negotiable fast-forward safety invariant for worktree updates. |
| `aapp.allowLocalHooks` | `true` / `false` | `true` | Hook Engine | Enables/disables local clone hook overrides (`git config aapp.hook.[event]`). |
| `aapp.hookTimeout` | integer (seconds) | `10` | Hook Engine | Execution timeout ceiling for local notify hook handlers. |
| `aapp.tagPrefix` | string | `v` | `aapp release` | Prefix applied to Git release tags. |
| `aapp.testCommand` | command | *(auto-detect)* | `aapp release` | Test command executed as pre-flight gate during release. |
| `aapp.issueArchiveMax` | integer | `500` | Archival Ledger | Live bounds ceiling for rows in `000-issues-archive.md` before rolling over into overflow archive files. |

---

## Environment Variables

| Variable | Scope | Purpose |
| :--- | :--- | :--- |
| `ALLOW_MAIN_COMMIT=1` | Commit Guard | Bypasses stable branch protection to permit intentional emergency or release commits on `main`. |
| `SKIP_BLAST_RADIUS=1` | Write & Commit Guard | Emergency escape hatch bypassing both write-time target checking and commit-time blast radius gates. |
| `AAPP_LOG_FILE` | Telemetry | Overrides destination path for JSON Lines event logging. |
| `AAPP_NON_INTERACTIVE=1` | CLI Runtime | Forces non-interactive behavior, suppressing prompts and using defaults. |
| `AAPP_PLAN_ID` | Plan Session | Exported into detached sessions opened in plan worktrees. |
| `AAPP_WORKTREE` | Plan Session | Absolute path to active plan worktree exported into detached sessions. |
| `AAPP_BRANCH` | Plan Session | Branch name for active plan exported into detached sessions. |

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🍳 [Cookbook Catalog](../../COOKBOOK.md)
- 🏠 [Repository Overview](../../README.md)
