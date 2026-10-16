# 🗺️ Plan P-94: JSON Output
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-16
* **Target Issue / Milestone:** none
* **Plan ID:** P-94
* **Changelog:** Added: `aapp status json` and `aapp issue list json` print one JSON document, its fields documented in `docs/reference/08-output-json.md` (P-94)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-91
* **Commits:** none
<!-- AAPP-PROTOCOL:START v1.0.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** #<num>        <- written by verbs: 'aapp issue hotfix' or 'aapp refine <id> blocked <num>' adds it; 'aapp issue close' removes it -->
<!-- * **Emergency Hotfixes:** #<num> <- append-only, written by 'aapp issue hotfix'; more than aapp.maxEmergencyHotfixes blocks the plan for good -->
<!-- * **Also Closes:** #<n>, #<m>  <- written by 'aapp refine <id> closes <num> [remove]': further issues this plan sorts; 'aapp done' closes them with the plan's commit -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp refine issues`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
A script that wants what `aapp status` or `aapp issue list` shows (a web CMS building its pages, a dashboard, a bot) can today only scrape terminal text, which breaks at every change of layout. This member, the last of group P-91, prints the records of P-92 as one JSON document whose fields are a versioned contract (group P-91 §2.4, §2.5).

---

## 2. Technical Blueprint

### 2.1 Ingress
- `aapp status json`, `aapp issue list [<n> | all] [confirm] json`: a bare token, in any position among the verb's tokens.
- `aapp status short json` -> exit 1, usage on stderr: the overview is the `overview` field.

### 2.2 The writer (`lib/output.sh`)
- `out_json_open`, `out_json_field <key> <type> <value>`, `out_json_list_open` / `_close`, `out_json_close`: one object, 2-space indent, keys in call order. Types: `string`, `number`, `bool`, `date`, `time`, and `?` forms that write `null` for an empty value. Strings through `json_escape`.
- The document is built in a buffer and printed whole at the end: a failure on the way prints nothing on stdout and exits non-zero.

### 2.3 The documents
- Exactly the fields of group P-91 §2.5, in that order, from the records; the issue object is one function (`issue_render_json`) used by both commands.
- `aapp status json` runs the briefing's side effects as the terminal briefing does; what they did is in `notices`. The terminal text never reaches stdout.
- `aapp issue list json`: the provider sync's messages go to stderr.

### 2.4 The reference (`docs/reference/08-output-json.md`, new)
- Front matter like `06-plugin-protocol.md`; the stream rule, the value rules, the versioning rule, one table per object, and a full example of each document.
- `tests/output_json_test.sh` runs both commands on a fixture and compares the keys of every object with the doc's tables: a field in the code and not in the doc, or the reverse, fails.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/output_json_test.sh::test_status_json_parses` -> asserts `aapp status json` prints one object that a JSON parser accepts, and nothing else on stdout
- [ ] `tests/output_json_test.sh::test_issue_list_json_parses` -> asserts `aapp issue list json` prints one object with `issues`, `shown` and `total`, honouring `<n>` and `all`
- [ ] `tests/output_json_test.sh::test_fields_match_reference` -> asserts the keys of every object equal the tables of `docs/reference/08-output-json.md`
- [ ] `tests/output_json_test.sh::test_issue_notes_count` -> asserts an issue's `notes` is the number of its description and notes, `0` with none, `null` where a provider keeps them, and no text of a note appears anywhere in either document
- [ ] `tests/output_json_test.sh::test_absent_values_are_null` -> asserts an issue with no plan, queue, branch or tracker carries those fields as `null`, and empty lists as `[]`
- [ ] `tests/output_json_test.sh::test_text_verbatim` -> asserts a symptom with backticks, quotes, a backslash and `…` comes back unchanged after parsing, uncut and unwrapped
- [ ] `tests/output_json_test.sh::test_failure_prints_nothing` -> asserts a failing run exits non-zero with stdout empty
- [ ] `tests/output_json_test.sh::test_pickup_objects` -> asserts each `pickup.items` object has `title`, `text` and `files`, `title` `null` for an entry without one, the text whole and verbatim, and `files` the existing `.plans/pickup/` paths the entry names
- [ ] `tests/output_json_test.sh::test_same_items_as_terminal` -> asserts the ids in `issues.queue`, `plans.items` and `pickup.items` are those the terminal briefing lists, in the same order
- [ ] `tests/output_json_test.sh::test_repository_remote` -> asserts `repository.remote` names the remote and its URL with credentials removed, and is `null` in a repository without a remote, in both documents
- [ ] `tests/output_json_test.sh::test_local_path_setting` -> asserts `repository.root` is the checkout by default and `null` with `aapp.jsonLocalPath false`, in both documents, and that no other value holds the checkout's absolute path
- [ ] `tests/output_json_test.sh::test_group_nests_members` -> asserts a group's `members` holds its member plans as objects, with `kind` `group` and `feature_branch`, and no member appears at the top level of `plans.items`
- [ ] `tests/verbs/status.sh::test_short_json_refused` -> asserts `aapp status short json` exits 1 with usage on stderr

### Phase 1: Foundation & Setup
- [ ] Task 1.1: Write the tests of this section; commit them red.

### Phase 2: Core Implementation
- [ ] Task 2.1: `lib/output.sh`: the JSON writer; `repository` with `remote` and `root` (`aapp.jsonLocalPath`).
- [ ] Task 2.2: `lib/aapp-lib.sh`: `issue_render_json`.
- [ ] Task 2.3: `lib/cmd_status.sh`: `status_render_json`, the `json` token.
- [ ] Task 2.4: `lib/cmd_issue.sh`: `issue list … json`.
- [ ] Task 2.5: `docs/reference/08-output-json.md`; `lib/docs/verbs/status.md` and `issue.md`: the token and the tests.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify edge cases.
- [ ] Task 3.2: Update user-facing documentation per `.agents/PROJECT.MD` (`MANUAL.md`, `README.md`, or `docs/`) if CLI verbs, configuration, or workflows were introduced or changed.
- [ ] Task 3.3: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` if new modules, commands, or interface contracts were introduced.
- [ ] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 3.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/output.sh` -> the JSON writer.
- [ ] `lib/aapp-lib.sh` -> `issue_render_json`.
- [ ] `lib/cmd_status.sh` -> `status_render_json`, the `json` token.
- [ ] `lib/cmd_issue.sh` -> the `json` token of `issue list`.
- [ ] `NEW FILE` -> `docs/reference/08-output-json.md` -> the JSON contract.
- [ ] `lib/docs/verbs/status.md` -> the `json` token and its tests.
- [ ] `lib/docs/verbs/issue.md` -> the `json` token of `list`.
- [ ] `MANUAL.md` -> JSON output, pointing to the reference; `aapp.jsonLocalPath`.
- [ ] `CHEATSHEET.md` -> `aapp status json`, `aapp issue list json`; the `aapp.jsonLocalPath` row.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `NEW FILE` -> `tests/output_json_test.sh`
- [ ] `tests/verbs/status.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `ARCHITECTURE.md` -> written from group P-91's sections at the group's `done`.
- [ ] `.agents/CODEMAP.md` -> written from group P-91's sections at the group's `done`.
- [ ] `docs/reference/06-plugin-protocol.md` -> the plugin exchange is a different contract.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — A JSON parser in the tests. → RESOLVED (developer, 2026-10-16):** `python3` (`json`), as the kit's other JSON handling; a test skips with a notice where it is missing.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-16:** Drafted as the fourth member of group P-91.
* **2026-10-16:** Tests for `repository.remote` and nested group members.
* **2026-10-16:** `aapp.jsonLocalPath` leaves `repository.root` out (group P-91 Q4).
* **2026-10-16:** Pickup objects: `title`, `text`, `files`.
* **2026-10-16:** Test for the issue `notes` count.
