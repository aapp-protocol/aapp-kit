# 🗺️ Plan P-100: JSON Errors And Warnings
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-16
* **Target Issue / Milestone:** none
* **Plan ID:** P-100
* **Changelog:** Changed: a JSON run that fails prints an error document; warnings and remarks of the run are in its `notices` (P-100)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `5a6f3c7` (feature/readable-and-parsable-output)
* **Worktree:** .workspace/P100 (plan/P100-json-errors-and-warnings)
* **Group:** P-91
* **Commits:** `c388e16` (plan/P100-json-errors-and-warnings), `f48e497` (plan/P100-json-errors-and-warnings)
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
P-94's JSON is read by programs: a web page, another agent. When a run fails they get a non-zero exit, an empty stdout and a message on stderr in prose with the kit's emoji. When a run succeeds with trouble on the way (a tracker sync that failed, so the issues may be stale) the warning goes to stderr and the document says `"notices": []`. Neither reaches the consumer in the form it reads.

This member, the sixth of group P-91, puts both in the JSON: stdout always holds one JSON object, the document or an error document; warnings and remarks are in `notices`, grouped by level. The contract is still `1.0` and unused outside the kit, so the change is made before the group merges.

---

## 2. Technical Blueprint

### 2.1 The stream (replaces group P-91 §2.4 "Stream")
- In `json` mode stdout always holds exactly one JSON object: the document, or, when the run fails, the error document. The exit code says which (0 or non-zero).
- Nothing else goes to stdout. The error's message also goes to stderr, for a person at a terminal; a successful run prints nothing on stderr.

### 2.2 `notices` (replaces the list of group P-91 §2.5)
```json
"notices": {
  "warning": [ { "section": "issues", "text": "aapp-issue-tracker failed on list (timeout); the issues may be stale." } ],
  "info":    [ { "section": "plans",  "text": "[Matrix] state_matrix.md re-derived from .plans/current/ (review and commit the diff)" } ]
}
```
- An object with both keys always present, each a list (`[]` when empty), in this order: `warning`, `info`. An item: `{ "section", "text" }`, the text without the kit's emoji.
- Everything a JSON run says on the way is captured and goes here: the briefing's notices as today, and in `aapp issue list json` what the sync says (until now sent to stderr). A line marked `⚠️` or `❌` is a warning; any other is info.

### 2.3 The error document
```json
{
  "version": "1.0",
  "command": "status",
  "generated_at": "2026-10-16T17:40:02Z",
  "repository": { "remote": null, "branch": "develop", "root": null },
  "notices": { "warning": [], "info": [] },
  "error": {
    "code": "invalid-setting",
    "message": "aapp.statusItemsMax is 'none'; it must be a whole number of at least 1.",
    "aapp_config": "aapp.statusItemsMax"
  }
}
```
- The envelope, then `error` instead of the command's own fields: `code`, `message` (the stderr text without emoji, one line per line joined by a space), `aapp_config` (the setting at fault, `aapp.<name>`, or `null`).
- `code`, a slug from this list:
  - `usage` -> a token or combination the verb refuses (`status short json`, `issue list sideways json`);
  - `invalid-setting` -> an `aapp.*` setting with a value it cannot have (`aapp_config` names it);
  - `confirm-needed` -> the sync asks a question (the switch to the tracker's record) and `confirm` was not given: a JSON run never waits for input;
  - `sync-failed` -> a sync that refuses (the tracker's record does not match the ledgers);
  - `failed` -> any other failure.
- When the envelope itself cannot be built (no repository, `aapp.jsonLocalPath` invalid), the error document carries `repository: null` and still is one JSON object.
- One function writes it, `out_json_error <command> <stderr text>` (`lib/output.sh`): it classifies the captured message (a `Usage:` line -> `usage`; `aapp.<name> is '…'` -> `invalid-setting` with `aapp_config`; the sync's confirmation question -> `confirm-needed`; the sync's refusal -> `sync-failed`; otherwise `failed`) and prints the document and, to stderr, the message.

### 2.4 Where it runs
- `aapp status json` and `aapp issue list json` run their whole JSON path with stderr captured: on success the captured lines become notices; on failure they become the error document.
- `aapp issue list json` without `confirm`: the sync's question is answered `no` (non-interactive), which refuses with `confirm-needed`.

### 2.5 The group
- Group P-91 §2.4 (Stream) and §2.5 (`notices`, and the `error` object) are amended to this member, with the developer's OK (2026-10-16), in the group's own commit.
- `docs/reference/08-output-json.md`: the stream rule, the `notices` object and its `notices.warning[]` / `notices.info[]` items, the `error` object and its codes; the example.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/output_json_test.sh::test_failure_is_error_document` -> asserts a failing `status json` exits non-zero with one JSON object on stdout holding the envelope and `error`, and the message also on stderr
- [ ] `tests/output_json_test.sh::test_error_codes` -> asserts `usage` for `issue list sideways json`, `invalid-setting` with `aapp_config` `aapp.statusItemsMax` for a bad value, `confirm-needed` for a first tracker listing without `confirm`, `failed` otherwise; `aapp_config` is `null` where no setting is at fault
- [ ] `tests/output_json_test.sh::test_notices_grouped_by_level` -> asserts `notices` is `{ "warning": [...], "info": [...] }`, both keys present, items `{ section, text }` without emoji
- [ ] `tests/output_json_test.sh::test_sync_warning_in_notices` -> asserts a failing tracker sync in `issue list json` is a `warning` notice of section `issues`, and nothing is printed on stderr
- [ ] `tests/output_json_test.sh::test_fields_match_reference` -> asserts the keys of every object, the error document's included, equal the tables of the reference

### Phase 1: Foundation & Setup
- [ ] Task 1.1: Write the tests of this section; update `test_failure_prints_nothing` and the fixtures that read `notices` as a list; commit them red.

### Phase 2: Core Implementation
- [ ] Task 2.1: `lib/output.sh`: `out_json_notices` as the grouped object; `out_json_error`.
- [ ] Task 2.2: `lib/cmd_status.sh`: the JSON path with stderr captured; notices and the error document.
- [ ] Task 2.3: `lib/cmd_issue.sh`: `list … json` with the sync's output captured; `confirm-needed`.
- [ ] Task 2.4: `docs/reference/08-output-json.md`, `lib/docs/verbs/status.md`, `lib/docs/verbs/issue.md`: the stream, `notices`, `error`, the codes, the tests.
- [ ] Task 2.5: group P-91 §2.4 and §2.5 amended (the group's commit).

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
- [ ] `lib/output.sh` -> `out_json_notices` grouped; `out_json_error`.
- [ ] `lib/cmd_status.sh` -> the JSON path captured; error document.
- [ ] `lib/cmd_issue.sh` -> `list … json` captured; `confirm-needed`.
- [ ] `docs/reference/08-output-json.md` -> stream, `notices`, `error`, codes.
- [ ] `lib/docs/verbs/status.md` -> the error document; the tests.
- [ ] `lib/docs/verbs/issue.md` -> the error document; the tests.
- [ ] `MANUAL.md` -> JSON errors and warnings.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/output_json_test.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `ARCHITECTURE.md` -> written from group P-91's sections at the group's `done`.
- [ ] `.agents/CODEMAP.md` -> written from group P-91's sections at the group's `done`.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
*(None — design is fully specified.)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-16:** Plan frozen and activated into ⚡ In Development via freeze-start.
*Tracks how the plan evolved across sessions.*
* **2026-10-16:** Drafted as the sixth member of group P-91: errors as a JSON document, warnings and remarks grouped in `notices`; `aapp_config` names the setting at fault.
