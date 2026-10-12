---
title: Issue Protocol
description: The events, data fields and commands of the exchange between the kit and the aapp-issue-tracker plugin.
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

## Data fields

| Field | Type | Values |
| :--- | :--- | :--- |
| `id` | text | The issue's id, `#<number>` |
| `commit` | text | The commit that fixed the issue (short SHA), or `aborted` |
| `summary` | text | One line: what the fix changed |
| `plan` | text or `null` | The plan that closed the issue (`P-<number>`), `null` for a direct fix |

`issue.close` also sets `AAPP_ISSUE_ID`, `AAPP_COMMIT_SHA` and `AAPP_SUMMARY` in the plugin's environment.

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
