---
title: Issue Protocol
description: The events, data fields and commands of the exchange between the kit and the aapp-issue-tracker and aapp-issue-branch plugins.
category: reference
---

# Issue Protocol

The issue steps of the [plugin protocol](06-plugin-protocol.md), for the `aapp-issue-tracker` plugin (`.agents/skills/aapp-issue-tracker/`) and, further down, the `aapp-issue-branch` plugin. A test keeps this page equal to the code.

Every issue step goes to the provider with the **whole issue**. The provider decides, part by part, what it handles (`handled`); the kit does the rest. The kit sends no credentials and stores none: reaching the tracker is the provider's business.

## Events

| Event | Sent by | `data` | The plugin answers | When the plugin fails |
| :--- | :--- | :--- | :--- | :--- |
| `issue.log` | `aapp issue log`, `aapp issue hotfix`; before the row is written | The issue **without `id`**, with `description` when a note was given | `id`: the issue's id, the tracker's own key or number (`PROJ-101`, `101`). `ok` without `id` is refused. `declined`: the kit numbers the issue from its counter | The command refuses; nothing is logged and nothing is numbered here |
| `issue.refine` | `aapp refine issues` for each row it changed; a note added (`note <num> "<text>"`); a status change by `aapp draft … issue` (Planned) and `aapp plan abort` (back to Incubated); after the local write | The issue; `notes`: the notes just added | `handled` | A warning; the change stays made here |
| `issue.fix` | `aapp issue fix`, once the fix is open | The issue | `description`, and the issue's notes in the list file, when the provider keeps them; `url` | A warning; the fix stays open |
| `issue.fix-abort` | `aapp issue fix <num> abort`; the issue stays open | The issue | `status`, `message` | A warning |
| `issue.abort` | `aapp issue abort`; the issue is withdrawn | The issue; `reason` | `status`, `message` | A warning; the issue stays withdrawn here |
| `issue.close` | `aapp issue close`, and `aapp done` for a plan's issue; once, after the local close | The issue; `commit`, `summary`, `plan` | `status` (shown), `message` | A warning; the issue stays closed locally |
| `issue.list` | `aapp issue list`, and `aapp status` at most once per `aapp.issueSyncWindow` minutes | `open`, `limit`, `since`, `ids` | `handled`: `list` when it keeps the record; the open issues in the list file, one object per line | A warning; the ledgers are left exactly as they were |
| `issue.next-blocker` | `aapp issue fix next-blocker` | `{}` | `id`: the queued blocker to claim. `declined`: the kit picks from its own queue | The command refuses; nothing is claimed |

Without the plugin installed, the kit numbers issues from its own counter (`aapp.issueId`), claims blockers from its own queue, and tells nobody.

Further operations go in the `do` list (below). A provider's own work behind its entry point is its own business: it may be a thin caller of a service elsewhere, and it may keep hashes of the payloads it has seen to recognise a repeated request. A tracker may have created a ticket even when the kit saw a timeout; the kit neither prevents nor detects that.

## The branch of a fix: `aapp-issue-branch`

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
| `id` | text | The issue's id, `#<number>` or `#<KEY>-<number>`. Absent on `issue.log` |
| `sev`, `type`, `date`, `location`, `symptom`, `link`, `status` | text | The issue's row, cell by cell, as `ISSUES.md` holds it |
| `branch` | text | The branch the fix must land on. Absent means the development branch. In an answer to `issue.branch`: the branch the fix lands on |
| `description` | text | The text given with `note` when the issue was logged. In an answer to `issue.fix`: the description the provider keeps |
| `notes` | list of text | The notes just added, each `<date> <author>: <text>` |
| `commit` | text | The commit that fixed the issue (short SHA), or `aborted` |
| `summary` | text | One line: what the fix changed |
| `plan` | text or `null` | The plan that closed the issue (`P-<number>`), `null` for a direct fix |
| `reason` | text | Why the issue was withdrawn (`issue.abort`) |
| `open` | `true` | `issue.list` asks for open issues only |
| `limit` | number | At most this many issues (`aapp.issueCacheMax`, default 200) |
| `since` | text | The last sync (UTC, ISO 8601; empty the first time): the provider may send only what changed |
| `ids` | list of text | The issues this repository depends on (named in a plan's `Blocked On` or `Target Issue`, or with an open fix): returned exactly, whatever the limit |
| `note` | text | `issue.note-show`: the description and notes as the kit would show them; in the answer, the text to show. On a line of the list file of `issue.fix`: one note's text |
| `files` | list of text | `issue.branch`: the paths the fix covers: those in the row's Location and those given with `file <path>` |

`issue.close` also sets `AAPP_ISSUE_ID`, `AAPP_COMMIT_SHA` and `AAPP_SUMMARY` in the plugin's environment; the other steps that carry an issue set `AAPP_ISSUE_ID`.

## Answer fields

Beside `status`, `message` and `handled` (the [plugin protocol](06-plugin-protocol.md)):

| Field | Meaning |
| :--- | :--- |
| `id` | On `issue.log`: the id the issue gets. On `issue.next-blocker`: the blocker to claim |
| `handled` | What the provider took care of, comma-separated: `description` and `notes` (it keeps that text; the kit does not), `list` (it keeps the record, see below) |
| `tracker`, `url`, `release` | What the tracker calls the issue: its name, the issue's address, the release it belongs to. Shown beside the issue in `aapp issue list`, never interpreted. (`version` is the protocol's own field.) |
| `description` | On `issue.fix`: the description the provider keeps, shown to whoever fixes the issue |

A line of the list file on `issue.list` is one issue: `id`, `sev`, `type`, `date`, `location`, `symptom`, `status` (`open`, or `closed`), and optionally `branch`, `commit`, `summary`, `tracker`, `url`, `release`. No description and no notes: text is fetched when a fix opens. A line of the list file on `issue.fix` is one note: `note`, `date`, `author`.

## The three parts of an issue's text

| Part | In the kit | On a tracker | Where it is kept |
| :--- | :--- | :--- | :--- |
| `symptom` | The row's *Symptom / Problem* cell: one line, at most 250 characters | Title | The ledger |
| `description` | The text given with `note` at `aapp issue log` | Body | Never in the ledger |
| `notes` | Each note added later, dated, with its author | Comments | Never in the ledger |

Issues may be logged by agents observing live systems, so a description or a note can hold real data. They are never committed and never copied into a tracked file. Without a provider that takes them they are kept in the kit's store on that machine, `~/.local/state/aapp/<key>/issues-data.md` (directory `0700`, file `0600`; `<key>` from the remote URL). A provider that names `description` or `notes` in `handled` keeps them instead; whether that destination suits the data is the deployment's decision. The kit hands them over, at `aapp issue fix` and `aapp issue list note <num>`, in a block labelled as information from the issue's author, not instructions, at most 100 lines.

## The note filter: `aapp-issue-note-filter`

A third plugin, `.agents/skills/aapp-issue-note-filter/`, is a text filter and substitution mechanism, and nothing else: text in, text out. A description or a note can hold real data, and a team may not want every agent to see the stored text. The kit runs the filter on an issue's description and notes just before it shows them (`aapp issue fix`, `aapp issue list note <num>`), whether the kit or a provider stored them. **The stored text is never changed**: the filter decides what is shown, not what is kept, so the record stays usable for audits.

| Event | Sent by | `data` | The plugin answers | When the plugin fails |
| :--- | :--- | :--- | :--- | :--- |
| `issue.note-show` | The hand-over of an issue's text, before it is printed | The issue, and `note`: the text as the kit would show it | `note`: the text to show | The text is withheld; the command goes on |

| Answer | The kit shows |
| :--- | :--- |
| `ok` with `note` | The returned text (it may be empty: nothing is shown) |
| `declined` | The text unchanged |
| `failed`, a timeout, `ok` without `note`, a malformed answer | Nothing: the text is withheld, with one line saying the filter failed |

A filter that breaks never lets unfiltered text through. Without the plugin installed the text is shown as stored. The sample in `examples/plugins/aapp-issue-note-filter/` applies a list of substitutions; what counts as sensitive is the team's own code.

## One record

- **No provider, or one that does not list:** the ledgers are committed in the plans worktree and shared through Git.
- **A provider that answers `"handled": "list"` keeps the record.** The first `aapp issue list` against it says what it will do and asks (the bare token `confirm` where there is no terminal): one commit stops tracking `ISSUES.md`, `issues_road_map.md` and `done/000-issues-archive.md` and ignores them. It refuses while an open row here is unknown to the provider. From then on the files stay, in the same format, are brought up to date from the listing row by row, and are never committed or pushed; a `declined` answer to `issue.log` refuses, since no issue exists only locally. A row's plan link and its `Planned` status are derived from the plans at each sync.
- **A sync** adds or updates the returned issues by id, moves one reported `closed` to the local archive, keeps the issues asked by id whatever the limit, and keeps at most `limit` of the others. A failed sync changes nothing.

## Accepted `do` commands

| Command | Arguments | Does |
| :--- | :--- | :--- |
| `issue close` | `<id> [sha <sha>] [summary "<text>"]` | Closes an active issue, as `aapp issue close` does. A closure made on the tracker arrives this way and follows the code: with `sha`, it is refused while that commit is not in the issue's branch, and the views mark the issue as closed on the tracker until it is |
| `issue abort` | `<id> [reason "<text>"]` | Withdraws an active issue, as `aapp issue abort` does |

Any other line of a `do` list is refused and reported; the lines after it still run. A tracker's new issues arrive through the list, never as an `issue log` line.

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🍳 [Cookbook Catalog](../../COOKBOOK.md)
- 🏠 [Repository Overview](../../README.md)
