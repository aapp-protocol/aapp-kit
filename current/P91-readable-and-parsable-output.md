# 🧩 Group Plan P-91: Readable And Parsable Output
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-16
* **Plan ID:** P-91
* **Changelog:** Added: `aapp status` and `aapp issue list` read cleanly in a narrow terminal, and print one JSON document with `json` (P-91)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The umbrella CHANGELOG.md entry for what the whole group delivers; members keep their own entries.
     The group's `done` writes it with the ARCHITECTURE.md commit. -->
* **Status:** ⚡ In Development
* **Base:** `751b9da` (develop)
* **Feature Branch:** feature/readable-and-parsable-output
* **Members:** P-92, P-94, P-93, P-88, P-96
* **Commits:** none
<!-- A group plan writes no code. `aapp start <group> [base <branch>]` cuts `feature/<slug>` from the parent
     branch; members are planned with `aapp draft <slug> group P-91` (or `aapp refine <id> group P-91`) and
     start from the feature branch. `aapp done <group>` refuses while a member is open, applies the sections
     below, runs the pre-done gate on the feature branch and merges it into the parent. -->

---

## 1. Goal
`aapp status` and `aapp issue list` are read in two ways: by a person in a terminal (often a narrow or split pane, or a code block in an agent's chat), and by scripts, such as a web CMS that builds its pages from JSON. Today both commands print as they compute: long single lines that wrap under their own columns, and text a script can only scrape.

The group gives each command one set of records and two renderers:
- **Terminal:** every line within one width, long text wrapped with a hanging indent, each item's facts on a line of their own.
- **JSON:** a bare `json` token prints the same records as one JSON document whose fields are a documented contract (`docs/reference/08-output-json.md`).

Merge criterion: every member archived and the pre-done gate green on the feature branch.

## 2. Shared Decisions

### 2.1 Scope
- `aapp status` (the whole briefing) and `aapp issue list`. `aapp status short` stays its one `📊 Overview:` line; `aapp issue list note <num>` stays the hand-over block.
- Other verbs keep their output; they can adopt the renderers later.

### 2.2 Records, then renderers
- Each section is first collected into **records**: tab-separated lines, one per item, fields in a fixed order (§2.5 names them). Records hold raw values (slugs, ids, dates, full text); they never hold layout.
- A **renderer** prints records and computes nothing. The terminal renderer and the JSON renderer read the same records, so the two outputs cannot disagree.
- One set of records per section, used everywhere: the Issues records of `aapp status` and of `aapp issue list` are one function (`ledger_issue_records` in `lib/aapp-lib.sh`, beside the ledger functions).
- Shared rendering lives in a new `lib/output.sh`: wrapping, cutting, and the JSON writer. `json_escape` (`lib/hook_dispatcher.sh`) stays the one string escaper; the JSON writer calls it.
- `aapp status` keeps its side effects (tracker sync, unblocking, matrix re-derivation) in both renderers; what they did is reported as notices.

### 2.3 Terminal layout
- **Width:** no line longer than `aapp.statusOutputWidth` characters (default `85`), counted in characters, not bytes (`…`, emoji, accented letters). It governs the briefing and `aapp issue list`, which shows the Issues pillar's layout: one width keeps the two identical.
- **Items** start at 2 spaces. A continuation line of an item's text aligns under the first character of that text.
- **Issues:** a facts line, then the symptom wrapped at 8 spaces:
  `#<id>  <Severity>  <Status>  logged <date>[  queued <date> (<Level>)][  [<plan>]][  (branch: <name>)][  offline][  <n> notes]`
  Facts that are absent are left out, never padded. No blank line between issues: each facts line, starting with `#`, marks the next issue.
- **Pickup ideas:** the title on the item's line, the text wrapped at 8 spaces below it, then one `files: <path>` line at 8 spaces per file:
  `  - [ ] <title>` / `        <text>` / `        files: .plans/pickup/<file>`. An idea with no title shows its text on the item's line, wrapped at 8 spaces. A title wider than the line (a high `aapp.pickupTitleMax`, a narrow width) wraps at 8 spaces too.
- **Cutting:** `aapp status` cuts an item's text at the last space before `aapp.statusTextMax` characters (default `220`) and ends it with `…`; `aapp issue list` never cuts. The full text stays in its file.
- **Item caps** in `aapp status`: `aapp.statusItemsMax` (default `5`) for Shipped and Pickup, followed by a line naming where the rest is. The Issues pillar lists the work queue whole, as today.
- Section headings, the frame and the `➡️  Next Action:` line keep their wording.
- Settings: `aapp.statusOutputWidth`, `aapp.statusTextMax`, `aapp.statusItemsMax`; for the JSON, `aapp.jsonLocalPath` (§2.5). No other output setting.

### 2.4 JSON output
- **Ingress:** a bare token, `aapp status json` and `aapp issue list [<n> | all] json`. No new verb.
- **Stream:** stdout holds exactly one JSON object and nothing else; every message goes to stderr. On failure: exit non-zero, stdout empty.
- **Shape:** UTF-8, 2-space indent, keys in the order this plan lists them. Every field listed is always present: an unknown or absent value is `null`, an empty list `[]`. Field names are `snake_case`.
- **Values:** enums are lowercase slugs (`under-review`, `medium`, `urgent`); dates are `YYYY-MM-DD`; times are UTC ISO 8601 (`2026-10-16T12:04:11Z`); ids keep their prefix (`#155`, `P-88`). Text fields hold the source text verbatim: inline Markdown as written, never wrapped or cut, no emoji added by the kit.
- **Contract:** `version` is the contract's version (`1.0`). Adding a field keeps the version; renaming, removing or retyping a field raises it. `docs/reference/08-output-json.md` is the reference; a test keeps it equal to the code, as for the plugin protocol.

### 2.5 Fields

**Envelope** (both commands):

| Field | Holds |
| :--- | :--- |
| `version` | `"1.0"` |
| `command` | `"status"` or `"issue list"` |
| `generated_at` | UTC time of the run |
| `repository` | `{ "remote": { "name", "url" } \| null, "branch", "root" }`. `remote` identifies the project on every machine: the remote `aapp.remote` names (default `origin`), its URL with any credentials removed, as the plugin envelope builds it (`_envelope_remote_json`); `null` without a remote. `branch` is the checkout's branch; `root` the local checkout, which differs per machine, or `null` with `aapp.jsonLocalPath false` (default `true`). Every other path in the JSON is relative to the repository root, so `root` is the only local path a document can hold |
| `notices` | `[{ "level": "info" \| "warning", "section", "text" }]`: every line the terminal prints as a remark (sync results, unblocking, matrix re-derived, a gone branch, drift), `section` naming where it belongs (`issues`, `plans`, …) |

**Issue** (one object, the same in both commands):

| Field | Holds |
| :--- | :--- |
| `id` | `"#155"` (a tracker's key: `"#PROJ-101"`) |
| `severity` | `critical`, `high`, `medium`, `low` |
| `type` | the row's type token, as written (`"CLI"`) |
| `status` | `incubated`, `planned`, `in-progress` |
| `logged` | date |
| `location` | the row's Location cell, as written |
| `symptom` | the row's symptom, verbatim |
| `plan` | the plan that fixes it (`"P-93"`), or `null` |
| `blocks` | the plan it blocks (a hotfix's), or `null` |
| `queue` | `null`, or `{ "section": "blockers" \| "queued", "level": "urgent" \| "normal" \| "low" \| null, "queued": date \| null }` |
| `branch` | the branch its fix lands on, or `null` (the development branch) |
| `offline` | `true` when staged in `.offline` |
| `tracker` | `null`, or `{ "name", "url", "release" }` as the provider named them |
| `notes` | how many entries (the description and each note) the issue has: `0` when none; `null` when a provider keeps them, as the kit cannot count them. The count only: no text of a description or note is ever in any output but the hand-over (`issue fix`, `issue list note <num>`) |

**`aapp issue list json`:** envelope, then `issues` (the issues listed, in the order listed), `shown`, `total`.

**`aapp status json`:** envelope, then:

| Field | Holds |
| :--- | :--- |
| `overview` | `{ "issues", "next_issues": [id], "plans", "roadmap_plans": [id], "pickup", "adoption" }`: the counts of `status short` |
| `templates` | `{ "synced": bool, "version", "drifted": [{ "file", "reason" }] }` |
| `pause` | `null`, or `{ "scope": "local" \| "team", "reason", "paused_at", "stashes": [{ "worktree", "branch" }] }`; `worktree` relative to the repository root (`.` for the main checkout) |
| `shipped` | `{ "source", "entries": [{ "section": "added" \| "changed" \| "fixed" \| …, "text", "plan", "issue", "commit", "date" }], "more" }`: `text` is the bullet as written; `plan` / `issue` the id it is tagged with, or `null`; `commit` and `date` where it landed, `null` from the fallback |
| `issues` | `{ "queue": [issue], "unqueued" }`: the work queue in queue order, offline issues included (`offline: true`); the count of the others |
| `plans` | `{ "items": [plan] }`, in briefing order. A plan: `{ "id", "file", "title", "kind": "plan" \| "group", "status", "status_label", "group", "target_issue", "blocked_on": [id], "worktree", "branch", "feature_branch", "members": [plan] }`. A group's `members` holds its member plans, nested in the group's order, as the briefing shows them under it; a member names its `group` and is not repeated at the top level. A member whose group is archived stands at the top level. `feature_branch` is a group's, `null` otherwise; `members` is `[]` for a plan |
| `pickup` | `{ "source", "items": [{ "title", "text", "files": [path] }], "total" }`. An entry is `- [ ] <title>: <text>`: `title` is what stands before the first `: ` outside backticks, `text` the rest, verbatim; an entry with no such separator has `title` `null` and its whole text in `text`. `files` lists, in the order named, the paths under `.plans/pickup/` the entry names that exist (repository-relative); a named file that does not exist is left out and reported as a `warning` notice |
| `adoption` | `{ "source", "open" }` |
| `offline` | `null`, or `{ "issues": [id], "archived": [id], "plans": [file], "outbox" }` |
| `next_action` | `{ "kind", "text", "command" }`; `kind` one of `paused`, `init`, `digest`, `in-development`, `start`, `issue`, `freeze`, `plan` |

The JSON lists the items the terminal lists (the same caps, `aapp.statusItemsMax`, §2.3) with their text whole; `more`, `unqueued` and `total` count the rest. `aapp issue list json` keeps the verb's own cap (`<n>`, `all`, default 20): each command sets its own limits.

## 3. Members & Order
All five members change `lib/aapp-lib.sh` or `lib/cmd_status.sh`: one runs at a time, in this order.

1. **P-96 Pickup Entry Form:** a pickup entry is `- [ ] <title>: <text>`, checked by `aapp refine pickup`; `pickup_entry_split` is the one split, which P-92's pickup records reuse.
2. **P-92 Output Records And Wrapping:** the records of every section, `lib/output.sh` (wrap, cut, width), the terminal renderer on the records. Shipped, Issues and Pickup print as today; the frame, Plans pillar, notices, offline block and next action keep to the width.
3. **P-88 Status Recent And Bounded (#147):** Shipped from the changelog's Git history, newest first, with `commit` and `date`; Shipped and Pickup bounded and wrapped (§2.3).
4. **P-93 Issue List Layout (#155):** the issue facts line and wrapped symptom in `aapp issue list` and the Issues pillar, offline issues included.
5. **P-94 JSON Output:** the `json` token on both commands, the JSON writer, `docs/reference/08-output-json.md` and its test.

## Architecture & Codemap
*Every changed section of `ARCHITECTURE.md` and `.agents/CODEMAP.md`, written out whole in a ```` fence, under the exact heading it has (or will have) in the file. Members do not edit these files; read the sections here as the target architecture. At the group's `done` a section replaces the file's section with the same heading, or is added at the end. `aapp refine` records a base line above each fence: `done` refuses a section the file changed meanwhile. Write `No changes.` under a file that keeps its content.*

### ARCHITECTURE.md
<!-- aapp-base: new -->
````markdown
## Output: Records, Terminal, JSON (P-91)

`aapp status` and `aapp issue list` collect what they show into records first: tab-separated lines, one per item, holding raw values (slugs, ids, dates, full text). Two renderers print the records and compute nothing, so the outputs cannot disagree.

* **Terminal.** Every line within `aapp.statusOutputWidth` characters (default 85). An item's long text wraps with a hanging indent; an issue's facts stand on a line of their own, the symptom below it. The briefing cuts long text (`aapp.statusTextMax`) and caps long lists (`aapp.statusItemsMax`); `issue list` never cuts. The full text stays in its file.
* **JSON.** A bare `json` token prints one JSON object on stdout and nothing else. Its fields are a contract, versioned and documented in `docs/reference/08-output-json.md`; adding a field keeps the version, renaming or removing one raises it. Text is verbatim (inline Markdown as written), absent values are `null`, enums are lowercase slugs.

The Issues records are one function for both commands, beside the ledger functions. Shared rendering (wrapping, cutting, the JSON writer) lives in `lib/output.sh`; `json_escape` stays the one string escaper.
````

### .agents/CODEMAP.md
<!-- aapp-base: 37f17acc82801936171b72e6967a2aa9168fa7bc38e5925b6c4c903e494110bb -->
````markdown
### 📊 Context Recovery Briefing (`lib/cmd_status.sh`)
* **Purpose:** The four-pillar context recovery briefing: Shipped (`CHANGELOG.md` and its Git history), Issues (the work queue), Plans (`.plans/current/`), and Pickup (`pickup.md`), with the pause banner, adoption tasks, staged offline work and the next action. Collects every section into records first; the terminal renderer and the JSON renderer (`aapp status json`) print them (P-91).
* **Key Functions:** `status_records_<section>` (`overview`, `templates`, `pause`, `shipped`, `issues`, `plans`, `pickup`, `adoption`, `offline`, `next`) and `status_notices` -> the records; `status_render_terminal` / `status_render_json` -> the two renderers.
* **Anti-Wrapper Warning:** Must remain strictly non-destructive and idempotent. A renderer computes nothing: a value both renderers need is a record field.
````

<!-- aapp-base: new -->
````markdown
### 🖨️ Output Renderers (`lib/output.sh`)
* **Purpose:** Shared rendering for commands that print records (P-91): terminal width, wrapping and cutting, and the JSON writer.
* **Key Functions:**
  * `out_width` -> `aapp.statusOutputWidth` (default 85). `out_wrap <first-indent> <hang-indent>` -> text on stdin wrapped at the width, counted in characters; `out_cut <limit>` -> text cut at the last space before `<limit>`, ending in `…`.
  * `out_json_open` / `out_json_field <key> <type> <value>` / `out_json_close` -> one JSON object, 2-space indent, keys in call order; strings through `json_escape`; `null` for an empty value of a nullable field.
* **Consumers:** `lib/cmd_status.sh`, `lib/cmd_issue.sh` (`issue list`).
* **Anti-Wrapper Warning:** Never print JSON by hand elsewhere: field order, `null` and escaping are decided here.
````

<!-- aapp-base: new -->
````markdown
### 📥 Pickup Entries (`lib/aapp-lib.sh`, `lib/planning_health.sh`)
* **Purpose:** The one form of a pickup idea, `- [ ] <title>: <text>` (P-96), and its gate at `aapp refine pickup`.
* **Key Functions:**
  * `pickup_entry_split <line>` -> `<title>\t<text>`: the title ends at the first `: ` outside backticks (or a `:` ending the line); empty when there is none. The one split: the gate and the briefing's pickup records read it.
  * `pickup_title_max` -> `aapp.pickupTitleMax` (default 72); fails naming the key below 10 or when not a number. `pickup_entry_files <text>` -> the `.plans/pickup/` paths an entry names. `aapp_char_len <text>` -> characters, not bytes, whatever the locale; the one length every width or limit check uses.
  * `check_pickup_entries <pickup_file>` (`lib/planning_health.sh`) -> refuses, line by line, a non-checkbox entry, and an unworked one without a title, with a title over the limit, without text, or naming a `.plans/pickup/` file that does not exist; files are checked for the entries the commit adds or changes only (`.plans/pickup/` is gitignored).
* **Consumers:** `aapp refine pickup` (`lib/cmd_plan.sh`); the Pickup records of `lib/cmd_status.sh`.
````

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `ARCHITECTURE.md` -> Sections from `## Architecture & Codemap`, applied at the group's `done`.
- [ ] `.agents/CODEMAP.md` -> Sections from `## Architecture & Codemap`, applied after the merge.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/skills/` -> The skills show `aapp status` as printed; they do not change.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — A blank line between issues? → RESOLVED (developer, 2026-10-16):** no blank line (§2.3).
* [x] **Question 2 — P-88's settings and cut. → RESOLVED (developer, 2026-10-16):** one set of settings for the briefing, named for the command: `aapp.statusOutputWidth`, `aapp.statusTextMax`, `aapp.statusItemsMax`; Shipped wraps like Pickup, through `lib/output.sh`.
* [x] **Question 3 — How many items in the JSON? → RESOLVED (developer, 2026-10-16):** each command keeps its own limits: the briefing's JSON follows `aapp.statusItemsMax`, `issue list json` its `<n>` / `all` cap.
* [x] **Question 4 — The local path in the JSON. → RESOLVED (developer, 2026-10-16):** `aapp.jsonLocalPath` (`true` by default; `false` writes `repository.root` as `null`), one setting for the JSON of every command; built in P-94.

---

## 📦 6. Change Log & Refinement History
* **2026-10-16:** Group started: `feature/readable-and-parsable-output` from `develop`.
* **2026-10-16:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-10-16:** Group drafted: shared records, terminal layout and JSON contract; members P-92, P-88, P-93, P-94.
* **2026-10-16:** Q1–Q3 resolved; `repository.remote` in every document; groups nest their members in `plans`; settings named `aapp.status…`.
* **2026-10-16:** Q4 resolved: `aapp.jsonLocalPath`; the JSON holds no other local path.
* **2026-10-16:** Pickup ideas carry `title`, `text` and `files`; the briefing shows the title on its own line.
* **2026-10-16:** P-96 (pickup entry form) joins, first in order.
* **2026-10-16:** A pickup title wider than the line wraps.
* **2026-10-16:** CODEMAP section for pickup entries (P-96).
* **2026-10-16:** Issues carry a `notes` count: a facts-line hint and a JSON field, never the text.
