---
title: Issue Protocol
description: The events, data fields and commands of the exchange between the kit and the aapp-issue-tracker and aapp-issue-branch plugins.
category: reference
---

# Issue Protocol

The issue steps of the [plugin protocol](06-plugin-protocol.md), for the `aapp-issue-tracker` plugin (`.agents/skills/aapp-issue-tracker/`). A test keeps this page equal to the code.

## Events

| Event | Sent by | `data` | The plugin answers | When the plugin fails |
| :--- | :--- | :--- | :--- | :--- |
| `issue.allocate` | A new issue number is taken (`aapp issue allocate`, `aapp issue hotfix`) | `{}` | `id`: the number to use (`{"id": "#97"}`, or a bare number) | The command refuses; the kit does not number locally |
| `issue.next-blocker` | `aapp issue fix next-blocker` | `{}` | `id`: the queued blocker to claim | The command refuses; the kit does not pick from its own queue |
| `issue.close` | `aapp issue close`, and `aapp done` for a plan's issue; once, after the local close | `id`, `commit`, `summary`, `plan` | `status` (shown), `message` | A warning; the issue stays closed locally |

Without the plugin installed, the kit numbers issues from its own counter (`aapp.issueId`), claims blockers from its own queue, and closes without telling anyone.

### The branch of a fix: `aapp-issue-branch`

A second plugin, `.agents/skills/aapp-issue-branch/`, answers one question: on which branch does this issue's fix land? Which branch owns which paths is a team's own knowledge (who has clearance for a branch, which paths are live and hot, who has the expertise to certify a fix there), so the kit defines no format for it and asks.

| Event | Sent by | `data` | The plugin answers | When the plugin fails |
| :--- | :--- | :--- | :--- | :--- |
| `issue.branch` | `aapp issue fix` (and `fix next-blocker`) before the fix opens; `aapp issue close` of an issue with no open fix. Only for an issue whose row names no branch | `id`, `sev`, `type`, `date`, `symptom`, `status`, `files` | `branch`: the branch that owns the files | The command refuses: no fix opens, nothing is closed, nothing is written |

| Answer | The kit does |
| :--- | :--- |
| `ok` with `branch` | Takes that branch and writes it to the row's `Branch` cell (nothing is written for the development branch); the plugin is not asked again for that issue |
| `declined` | Takes the development branch; nothing is written |
| `failed`, a timeout, `ok` without `branch`, a branch that exists neither here nor on a remote | Refuses, shows the plugin's `message` and names the way past: `aapp refine issues "<msg>" branch <num> <name>` |

The plugin gives direction and enforces nothing: a `failed` answer's `message` says where the fix should go or who should make it, and what a branch accepts is enforced where the branch is hosted. A branch a person names (`branch <name>`) is not put to the plugin, and neither is a fix opened with `group <group>`. The views (`aapp status`, `aapp issue list`) never ask. Files that belong to two branches are the plugin's call: one branch, or `failed` naming the owners. Without the plugin installed every fix lands on the development branch. The sample in `examples/plugins/aapp-issue-branch/` maps path prefixes to branches from a list kept beside it.

## Data fields

| Field | Type | Values |
| :--- | :--- | :--- |
| `id` | text | The issue's id, `#<number>` |
| `commit` | text | The commit that fixed the issue (short SHA), or `aborted` |
| `summary` | text | One line: what the fix changed |
| `plan` | text or `null` | The plan that closed the issue (`P-<number>`), `null` for a direct fix |
| `sev`, `type`, `date`, `symptom`, `status` | text | The issue's row, cell by cell, as `ISSUES.md` holds it |
| `files` | list of text | The paths the fix covers: those in the row's Location and those given with `file <path>` |
| `branch` | text | In an answer to `issue.branch`: the branch the fix lands on |

`issue.close` also sets `AAPP_ISSUE_ID`, `AAPP_COMMIT_SHA` and `AAPP_SUMMARY` in the plugin's environment; `issue.branch` sets `AAPP_ISSUE_ID`.

No event has parts for `handled` yet: the kit does all local work for these three.

## Accepted `do` commands

| Command | Arguments | Does |
| :--- | :--- | :--- |
| `issue close` | `<id> [sha <sha>] [summary "<text>"]` | Closes an active issue, as `aapp issue close` does |
| `issue abort` | `<id> [reason "<text>"]` | Withdraws an active issue, as `aapp issue abort` does |

Any other line of a `do` list is refused and reported.

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🍳 [Cookbook Catalog](../../COOKBOOK.md)
- 🏠 [Repository Overview](../../README.md)
