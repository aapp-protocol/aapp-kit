---
title: JSON Output
description: The JSON documents `aapp status json` and `aapp issue list json` print, field by field, for scripts and web pages built on them.
category: reference
---

# JSON Output

`aapp status` and `aapp issue list` print a terminal layout for people. With the bare token `json` they print the same records as one JSON document for scripts: a web CMS building its pages, a dashboard, a bot. The fields on this page are a contract. A test keeps this page equal to the code.

```bash
aapp status json
aapp issue list json          # the first 20 issues
aapp issue list all json      # every open issue
```

## The rules

- **Stream.** Standard output always holds exactly one JSON object and nothing else: the document, or, when the run fails, the [error document](#error-document). The exit code says which: 0, or non-zero. The run never waits for input. A successful run prints nothing on standard error; a failed one prints its message there too, for a person at a terminal.
- **Warnings.** Whatever a run says on the way, a tracker that did not answer, a matrix re-derived, a file a pickup idea names that is not here, is in `notices`, grouped by level: `warning` first, then `info`.
- **Shape.** UTF-8, indented by 2 spaces, the keys in the order of the tables below. Every field listed is always present: an unknown or absent value is `null`, an empty list `[]`.
- **Values.** Field names are `snake_case`. Enumerations are lowercase slugs (`under-review`, `medium`, `urgent`). Dates are `YYYY-MM-DD`; times are UTC ISO 8601 (`2026-10-16T12:04:11Z`). Ids keep their prefix (`#155`, `P-88`). Text fields hold the source text verbatim: inline Markdown as written, never wrapped or cut, no emoji added by the kit.
- **Paths.** Every path is relative to the repository root, except `repository.root`. Set `aapp.jsonLocalPath false` to write `repository.root` as `null`, so that a published document names no local path.
- **Limits.** `aapp status json` lists the items the briefing lists (`aapp.statusItemsMax`, default 5, for Shipped and Pickup), their text whole; `more`, `unqueued` and `total` count the rest. `aapp issue list json` keeps the verb's own cap: `<n>`, `all`, default 20.
- **Versions.** `version` is the contract's version. Adding a field keeps it; renaming, removing or retyping a field raises it.

## The objects

Each table lists an object's fields in their order. The heading names where the object is found.

### `envelope`
The top of both documents.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `version` | string | `"1.0"` |
| `command` | string | `"status"` or `"issue list"` |
| `generated_at` | time | when the document was made |
| `repository` | object | the project, below |
| `notices` | object | the run's warnings and remarks, by level, below |

### `repository`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `remote` | object or `null` | the remote `aapp.remote` names (default `origin`); `null` without one |
| `branch` | string or `null` | the checkout's branch; `null` when detached |
| `root` | string or `null` | the checkout's absolute path; `null` with `aapp.jsonLocalPath false` |

### `repository.remote`
What identifies the project on every machine.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `name` | string | the remote's name |
| `url` | string | its URL, any credentials removed |

### `notices`
Both keys are always present; a level with nothing to say is `[]`.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `warning` | list | what may make the document incomplete or stale, as items below |
| `info` | list | the other remarks, as items below |

### `notices.*[]`
An item of `notices.warning` or `notices.info`.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `section` | string | where it belongs: `issues`, `plans`, `pickup`, or the command itself (`status`) |
| `text` | string | the remark, without the terminal's emoji |

### `issue`
One issue, the same in both documents.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `id` | string | `"#155"`; a tracker's key: `"#PROJ-101"` |
| `severity` | string | `critical`, `high`, `medium`, `low` |
| `type` | string | the type token, as written (`"CLI"`) |
| `status` | string | `incubated`, `planned`, `in-progress` |
| `logged` | date | when it was logged |
| `location` | string | the Location cell, as written |
| `symptom` | string | the symptom, verbatim |
| `plan` | string or `null` | the plan that fixes it |
| `blocks` | string or `null` | the plan it blocks (a hotfix's) |
| `queue` | object or `null` | its place on the work queue, below; `null` when not queued |
| `branch` | string or `null` | the branch its fix lands on; `null` for the development branch |
| `offline` | boolean | `true` when staged in `.offline` |
| `tracker` | object or `null` | what a provider calls it, below |
| `notes` | number or `null` | how many entries (the description and each note) it has; `null` where a provider keeps them. Their text is never in a document |

### `issue.queue`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `section` | string | `blockers` or `queued` |
| `level` | string or `null` | `urgent`, `normal`, `low`; `null` for a plan blocker |
| `queued` | date or `null` | when it was queued |

### `issue.tracker`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `name` | string or `null` | the tracker's name |
| `url` | string or `null` | the issue's address there |
| `release` | string or `null` | the release it is planned for |

### `issue list`
`aapp issue list json`: the envelope, then:

| Field | Type | Holds |
| :--- | :--- | :--- |
| `issues` | list | the issues listed, in the order listed (this branch's first, once an issue names a branch) |
| `shown` | number | how many are listed |
| `total` | number | how many are open |

### `status`
`aapp status json`: the envelope, then:

| Field | Type | Holds |
| :--- | :--- | :--- |
| `overview` | object | the counts of `aapp status short` |
| `templates` | object | whether the rules and templates are current |
| `pause` | object or `null` | the pause, when the project is paused |
| `shipped` | object | what landed last |
| `issues` | object | the work queue |
| `plans` | object | the active plans |
| `pickup` | object | the ideas waiting |
| `adoption` | object | the open adoption tasks |
| `offline` | object or `null` | what waits in `.offline` for the provider |
| `next_action` | object | the suggested next step |

### `status.overview`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `issues` | number | open issues |
| `next_issues` | list | the first three ids on the work queue |
| `plans` | number | plans in `.plans/current/` |
| `roadmap_plans` | list | the first three plan ids of the matrix's roadmap |
| `pickup` | number | unworked ideas |
| `adoption` | number | open adoption tasks |

### `status.templates`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `synced` | boolean | `true` when nothing drifted |
| `version` | string | the kit's version the templates are compared with |
| `drifted` | list | each drifted template, below |

### `status.templates.drifted[]`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `file` | string | the template |
| `reason` | string | how it drifted |

### `status.pause`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `scope` | string | `local` (this clone) or `team` (`.plans/PAUSED.md`) |
| `reason` | string or `null` | why |
| `paused_at` | string or `null` | when, as recorded |
| `stashes` | list | the work set aside, below |

### `status.pause.stashes[]`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `worktree` | string | the worktree, relative to the repository root (`.` for the main checkout) |
| `branch` | string or `null` | its branch |

### `status.shipped`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `source` | string or `null` | the changelog read |
| `entries` | list | the entries, newest first, below |
| `more` | number | entries under `## [Unreleased]` not listed |

### `status.shipped.entries[]`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `section` | string or `null` | `added`, `changed`, `fixed`, … |
| `text` | string | the entry as written |
| `plan` | string or `null` | the plan it is tagged with |
| `issue` | string or `null` | the issue it is tagged with |
| `commit` | string or `null` | the commit that added it; `null` without history |
| `date` | date or `null` | that commit's date |

### `status.issues`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `queue` | list | the work queue as `issue` objects: the plan blockers, then the queued issues by level, then those staged in `.offline` |
| `unqueued` | number | the other open issues |

### `status.plans`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `items` | list | the plans as `plan` objects, in the briefing's order |

### `plan`
A plan in `status.plans.items`, or a member in a group's `members`.

| Field | Type | Holds |
| :--- | :--- | :--- |
| `id` | string or `null` | `"P-88"` |
| `file` | string | its file in `.plans/current/` |
| `title` | string | its title |
| `kind` | string | `plan`, `group`, or `amendments` (a group's amendments member) |
| `status` | string or `null` | `under-review`, `refining`, `frozen`, `in-development`, `blocked`, … |
| `status_label` | string | the status as named, without its emoji (`"In Development"`) |
| `group` | string or `null` | the group it belongs to |
| `target_issue` | string or `null` | the issue it was made for |
| `blocked_on` | list | the issues it waits for |
| `worktree` | string or `null` | its worktree, relative to the repository root |
| `branch` | string or `null` | its worktree's branch |
| `feature_branch` | string or `null` | a group's feature branch |
| `members` | list | a group's member plans, as `plan` objects, in the group's order; `[]` for a plan |
| `requests` | object or `null` | an amendments member's requests by state, below; `null` for any other plan |
| `must_rebase` | list or `null` | an amendments member's: the group's members in development whose branch lacks the feature branch's tip; `null` for any other plan |

### `plan.requests`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `pending` | number | requests waiting for approval (or for the owner, when approval is not required) |
| `approved` | number | approved, not yet landed or applied |
| `refused` | number | refused |
| `landed` | number | files landed on the feature branch |
| `applied` | number | corrections written into the group plan |

### `status.pickup`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `source` | string or `null` | `".plans/pickup.md"` |
| `items` | list | the ideas listed, below |
| `total` | number | unworked ideas |

### `status.pickup.items[]`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `title` | string or `null` | what stands before the first `: ` outside backticks |
| `text` | string | the rest, verbatim |
| `files` | list | the `.plans/pickup/` files it names that exist |

### `status.adoption`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `source` | string | `".plans/adoption.md"` |
| `open` | number | open tasks |

### `status.offline`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `issues` | list | ids of the issues staged |
| `archived` | list | ids of the issues closed while staged |
| `plans` | list | the draft plans staged |
| `outbox` | number | steps not yet sent to the provider |

### `status.next_action`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `kind` | string | `paused`, `init`, `approve`, `digest`, `in-development`, `start`, `issue`, `freeze`, `plan` |
| `text` | string | the suggestion |
| `command` | string | the command it suggests |

### `error document`
What a failed run prints: the envelope (its `repository` is `null` when the project cannot be read), then:

| Field | Type | Holds |
| :--- | :--- | :--- |
| `error` | object | what went wrong, below |

### `error`

| Field | Type | Holds |
| :--- | :--- | :--- |
| `code` | string | what kind of failure, from the list below |
| `message` | string | the kit's message, without its emoji, on one line |
| `aapp_config` | string or `null` | the `aapp.*` setting at fault (`"aapp.statusItemsMax"`), when one is |

### Error codes
The values of `error.code`:

| Code | When |
| :--- | :--- |
| `usage` | a token, or a combination of tokens, the command refuses (`aapp status short json`) |
| `invalid-setting` | an `aapp.*` setting holds a value it cannot have; `aapp_config` names it |
| `confirm-needed` | the tracker's sync asks a question (letting the tracker keep the record): run again with `confirm` |
| `sync-failed` | the tracker's sync refuses (it does not know issues open here) |
| `failed` | any other failure; `message` says what |

## Examples

`aapp issue list 1 json`:

```json
{
  "version": "1.0",
  "command": "issue list",
  "generated_at": "2026-10-16T12:04:11Z",
  "repository": {
    "remote": {
      "name": "origin",
      "url": "ssh://git@github.com/aapp-protocol/aapp-kit.git"
    },
    "branch": "develop",
    "root": null
  },
  "notices": {
    "warning": [],
    "info": []
  },
  "issues": [
    {
      "id": "#155",
      "severity": "low",
      "type": "CLI",
      "status": "planned",
      "logged": "2026-10-16",
      "location": "`lib/aapp-lib.sh`",
      "symptom": "`aapp issue list` prints each issue as one line of up to ~350 characters.",
      "plan": "P-93",
      "blocks": null,
      "queue": null,
      "branch": null,
      "offline": false,
      "tracker": null,
      "notes": 0
    }
  ],
  "shown": 1,
  "total": 24
}
```

`aapp status json` with `aapp.statusItemsMax` set to `none`, a failed run:

```json
{
  "version": "1.0",
  "command": "status",
  "generated_at": "2026-10-16T17:40:02Z",
  "repository": {
    "remote": null,
    "branch": "develop",
    "root": null
  },
  "notices": {
    "warning": [],
    "info": []
  },
  "error": {
    "code": "invalid-setting",
    "message": "[Status] aapp.statusItemsMax is 'none'; it must be a whole number of at least 1.",
    "aapp_config": "aapp.statusItemsMax"
  }
}
```

`aapp status json` holds the same envelope, then `overview`, `templates`, `pause`, `shipped`, `issues`, `plans`, `pickup`, `adoption`, `offline` and `next_action`, as the tables above list them.
