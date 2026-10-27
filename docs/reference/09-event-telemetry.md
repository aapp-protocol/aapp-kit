---
title: Event Telemetry
description: The event envelopes and payloads emitted to registered observer hooks on lifecycle mutations, field by field.
category: reference
---

# Event Telemetry

The kit emits structured telemetry to registered observer hooks (`mode=observer` or `mode=notify`) whenever lifecycle mutations occur. Telemetry is pumped to standard input of registered hooks as a uniform JSON envelope containing repository context and action data.

Observer hooks allow teams to track planning progress, audit commit attribution, ship real-time event logs to centralized collectors, or update external dashboards without polluting the Git workspace or interfering with git pre-commit quality gates.

## The rules

- **Standard Input Delivery.** Handlers receive standard input holding exactly one JSON envelope containing the event metadata and payload. The hook execution runs under the timeout watchdog (`aapp.hookTimeout`, default 10 seconds).
- **Non-Blocking Observers.** Observer hooks run in `notify` mode; non-zero exit codes log an advisory notice but never block or roll back kit operations.
- **Universal 2-Key Invariant.** Every event's `data` payload consistently carries `command` (the subsystem) and `event` (the lifecycle action), enabling uniform ingestion, filtering, and indexing across downstream log processors.
- **Out-of-Repo Logging.** Observer hooks should record events strictly outside the Git-tracked workspace (for example, in `.git/aapp_events.jsonl` or an external logging directory) to preserve repository portability and prevent write-guard refusals.
- **Shapes & Values.** All strings are UTF-8. Times are UTC ISO-8601 (`YYYY-MM-DDTHH:MM:SSZ`). Repository paths are relative to repository root, except `repository.root` which names the absolute path of the checkout.
- **Unified Issue Telemetry.** All issue state transitions emit a single observer event, `post-issue`, using the `command: "issue"` and `event: "<action>"` model aligned with kit plugins.

## The objects

### `envelope`
The outer wrapper delivered to `stdin` on every lifecycle hook dispatch.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `version` | string | `"1.0"` |
| `event` | string | the dispatched hook name (e.g. `"post-commit"`, `"post-issue"`) |
| `timestamp` | time | UTC ISO-8601 timestamp of the dispatch |
| `actor` | string | author identity, defaults to `"developer"` or `$AAPP_ACTOR` |
| `repository` | object | project repository context, below |
| `data` | object | event-specific data payload, below |
| `extra` | object | reserved extensible metadata object, always `{}` |

### `repository`
Context describing the local repository checkout.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `root` | string | absolute path of the repository root |
| `branch` | string | current Git branch name or `"detached"` |
| `remote` | object or `null` | remote origin information, below; `null` without a remote |

### `repository.remote`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `name` | string | the remote's name (e.g. `"origin"`) |
| `url` | string | the remote URL, credentials stripped |

---

## Lifecycle Observer Payloads (`data`)

### 1. `post-draft`
Dispatched when a new plan blueprint is scaffolded and registered.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `command` | string | `"plan"` |
| `event` | string | `"draft"` |
| `plan_id` | string | the allocated Plan ID (e.g. `"P-104"`) |
| `slug` | string | the blueprint slug |
| `plan_file` | string | relative path to the plan blueprint |
| `group` | string | parent group ID, or `"none"` |

### 2. `post-freeze`
Dispatched when a blueprint's design and blast radius are locked.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `command` | string | `"plan"` |
| `event` | string | `"freeze"` |
| `plan_id` | string | the frozen Plan ID |
| `plan_file` | string | relative path to the blueprint |

### 3. `post-start`
Dispatched when a plan is activated into active development (`⚡ In Development`).

| Field | Type | Holds |
| :--- | :--- | :--- |
| `command` | string | `"plan"` |
| `event` | string | `"start"` |
| `plan_id` | string | the activated Plan ID |
| `plan_file` | string | relative path to the blueprint |
| `worktree` | string | path to the dedicated worktree, or `"none"` |
| `branch` | string | branch name cut for development, or `"none"` |

### 4. `post-refine`
Dispatched after an edit or amendment commit lands on an active plan.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `command` | string | `"plan"` |
| `event` | string | `"refine"` |
| `plan_id` | string | the refined Plan ID |
| `kind` | string | refinement kind (e.g. `"message"`, `"slug"`, `"group"`, `"request"`, `"approve"`) |
| `args` | list | arguments passed to the refine operation |
| `files` | list | target files touched or amended |
| `commit` | string | short SHA of the refinement commit |

### 5. `post-done`
Dispatched after an implemented plan is archived to `.plans/done/`.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `command` | string | `"plan"` |
| `event` | string | `"done"` |
| `plan_id` | string | the archived Plan ID |
| `plan_file` | string | relative path to the archived blueprint |
| `commit_hash` | string | final commit SHA recorded for the plan |
| `commits` | list | list of commit SHAs belonging to this plan |
| `worktree` | string | relative worktree path, or `"none"` |

### 6. `post-abort`
Dispatched when an active plan is abandoned and relocated to `.plans/aborted/`.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `command` | string | `"plan"` |
| `event` | string | `"abort"` |
| `plan_id` | string | the aborted Plan ID |
| `plan_file` | string | relative path in `aborted/` |
| `reason` | string | explanation recorded for the abort |
| `worktree` | string | worktree path removed, or `""` |
| `branch` | string | branch removed, or `""` |
| `commits` | list | unmerged commits recorded in the plan |

### 7. `post-active`
Dispatched when the active plan execution pointer buffer is updated.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `command` | string | `"plan"` |
| `event` | string | `"active"` |
| `action` | string | `"set"`, `"swap"`, or `"clear"` |
| `active_plan` | string | newly designated Plan ID, or `"none"` |
| `previous_plan` | string | previously active Plan ID, or `"none"` |

### 8. `post-tdd`
Dispatched when test-driven development failure sections are injected into a blueprint.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `command` | string | `"plan"` |
| `event` | string | `"tdd"` |
| `plan_id` | string | the target Plan ID |
| `plan_file` | string | relative path to the blueprint |

### 9. `post-commit`
Dispatched after `aapp commit` records a code commit in the active plan.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `command` | string | `"commit"` |
| `event` | string | `"record"` |
| `plan_id` | string | Plan ID the commit was bound to |
| `commit_sha` | string | short SHA of the code commit |
| `subject` | string | commit subject line |
| `worktree` | string | checkout or worktree path where commit was created |
| `agent` | string | AI agent name, or `""` |
| `vendor` | string | AI vendor name, or `""` |
| `model` | string | AI model ID, or `""` |

### 10. `post-land`
Dispatched after an amendments member's commits land onto its group's feature branch.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `command` | string | `"commit"` |
| `event` | string | `"land"` |
| `group_id` | string | the owning Group Plan ID |
| `amendment_id` | string | the amendments member Plan ID |
| `feature_branch` | string | target feature branch name |
| `commit_sha` | string | landed commit SHA |

### 11. `post-issue`
Unified observer hook dispatched across all issue operations and transitions.

| Operation | `event` | Additional Fields in `data` |
| :--- | :--- | :--- |
| Log | `"log"` | `issue_id` (string), `sev` (string), `type` (string), `symptom` (string), `files` (list) |
| Queue | `"queue"` | `issue_id` (string), `level` (string: `"urgent"`, `"normal"`, `"low"`) |
| Unqueue | `"unqueue"` | `issue_id` (string) |
| Fix | `"fix"` | `issue_id` (string), `worktree` (string), `branch` (string) |
| Close | `"close"` | `issue_id` (string), `commit_sha` (string), `summary` (string) |
| Hotfix | `"hotfix"` | `issue_id` (string), `blocked_plan` (string), `files` (list) |
| Withdraw | `"withdraw"` | `issue_id` (string), `reason` (string) |

### 12. `post-pause`
Dispatched after the master emergency brake pauses the project.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `command` | string | `"pause"` |
| `event` | string | `"pause"` |
| `reason` | string | pause reason or description |
| `shared` | boolean | `true` if paused with shared lock file |

### 13. `post-resume`
Dispatched after normal velocity is restored by `aapp resume`.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `command` | string | `"pause"` |
| `event` | string | `"resume"` |
| `restored_count` | number | count of worktree stashes restored |
| `drift_found` | number | count of worktrees with detected drift |

### 14. `post-sync`
Dispatched after worktree synchronization completes with remote.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `command` | string | `"sync"` |
| `event` | string | `"sync"` |
| `action` | string | transport action (e.g. `"pull_push"`, `"pull"`, `"push"`) |
| `remote` | string | remote repository name |
| `worktrees` | list | list of worktrees synchronized |

**Settings on this page:** [Hooks & Plugins](03-configuration-matrix.md#hooks--plugins)

---

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🍳 [Cookbook Catalog](../../COOKBOOK.md)
- 🏠 [Repository Overview](../../README.md)
