# 🗺️ Plan P-77: Plugin Answer Standard
* **Created:** 2026-10-12 | **Last Refined:** 2026-10-12
* **Target Issue / Milestone:** none
* **Plan ID:** P-77
* **Changelog:** Changed: one answer contract for the plugins the kit calls (P-77)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ✅ Done
* **Base:** `d1b9e68` (feature/issue-tracker)
* **Worktree:** .workspace/P77 (plan/P77-plugin-answer-standard)
* **Group:** P-72
* **Commits:** `1e3792a` (plan/P77-plugin-answer-standard), `e47c311` (plan/P77-plugin-answer-standard), `29e3138` (plan/P77-plugin-answer-standard)
<!-- AAPP-PROTOCOL:START v1.0.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** #<num>        <- written by verbs: 'aapp issue hotfix' or 'aapp refine <id> blocked <num>' adds it; 'aapp issue close' removes it -->
<!-- * **Emergency Hotfixes:** #<num> <- append-only, written by 'aapp issue hotfix'; more than aapp.maxEmergencyHotfixes blocks the plan for good -->

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
The Plugin Payload Standard says what the kit sends a supported plugin (the envelope) and that the plugin answers with one flat JSON object. It does not say how a plugin gets the kit to do something locally, so a plugin author's natural move is to call the `aapp` CLI from inside the plugin, while the calling verb holds its lock and is mid-commit.

This plan gives supported plugins (the reserved names the kit calls: `aapp-issue-tracker`, `aapp-planid`) one answer contract that reads the way a person would say it, and keeps the kit the only writer. An ad hoc plugin or script is outside it: to the kit it is a CLI user like any other, and the CLI's own locks and checks are the safeguard.

---

## 2. Technical Blueprint
A step is a short exchange between the kit and a supported plugin.

**1. The kit asks.** The envelope of the Plugin Payload Standard, unchanged in form:
- `event` names the step (`issue.log`, `issue.fix`, `issue.close`, `issue.list`, `plan.allocate`, …).
- `data` carries the whole subject (every cell of the issue, its note, its plan link), not only an id.

**2. The plugin answers.** One flat JSON object on stdout; the exit code still decides success.
```json
{ "status": "ok",
  "message": "Created PROJ-101 on the tracker",
  "handled": "note",
  "id": "PROJ-101",
  "tracker": "jira" }
```
- `status`: `ok`, `declined` (not mine; the kit does it) or `failed`. Absent on a successful exit means `ok`, so an answer that carries only what it produced stays valid.
- `message`: one sentence the kit shows the user.
- `handled`: what the plugin took care of. Whatever it does not name, the kit does; a part added by a later kit version is therefore still done by the kit under an older plugin.
- The rest: what it produced, under the field names the kit sent (`id`, …), plus the informational `tracker`, `url` and `version` (the tracker's current release or milestone).

**3. Longer answers** go in two optional files the kit names in the plugin's environment; every line is flat, readable with `cat`:
- `AAPP_PLUGIN_LIST`: one flat JSON object per line, in the shape of `data` (the issues of `issue.list`).
- `AAPP_PLUGIN_DO`: the `do` list: aapp commands exactly as a person types them, one per line.
  ```
  issue close 12 summary "closed on the tracker"
  issue abort 14 reason "won't fix: superseded"
  ```
  The kit runs them after the plugin exits and after the step has finished and released its lock: in order, each command taking the lock it needs as it would from the CLI, through the code the CLI runs, each result reported; a refused command is reported and the rest still run. A command run from `do` does not call the plugin that asked for it.

**4. The kit finishes** the local part: everything not in `handled`, then the `do` list.

**Reference.** In the manual's reference tree (P-57): `docs/reference/06-plugin-protocol.md` (the exchange: envelope, answer, `handled`, the two files, the rules, credentials) and one file per subject, `docs/reference/07-issue-protocol.md` first (plans follow). A subject file has three tables: the events (who sends each, when, the outcome on plugin failure), the data fields (type and allowed values, for the envelope and for the answer, with what `handled` may name per event), and the `do` commands accepted for that subject with their arguments. Each file carries P-57's frontmatter and navigation footer. A test fails when the code sends an event or field, or accepts a `do` command, that the reference does not list. Until P-57 makes `docs/` an always-allowed path, these files are listed as Target Files.

**Rules**
- **`do` is whitelisted.** Only the commands listed in the subject's reference are accepted; any other line is refused and reported. For issues the list is `issue close` and `issue abort`: a tracker's new issues arrive through `issue.list`, so `issue log` is not on it.
- **During a step** a supported plugin that runs a writing `aapp` verb directly is refused (the kit marks the plugin's environment) and pointed to `do`. Reading verbs work.
- **Version:** the answer may echo `version`; the kit refuses an answer from a version newer than its own.
- **Behind its entry point a plugin is its own business.** The file in `.agents/skills/<name>/` is typically a thin caller of a service that lives elsewhere, where the credentials are. Keeping its own state, recognising a step it has already seen, and avoiding a second ticket when a step is sent again are the plugin's to do, for example by keeping its own hashes (SHAs) of the payloads it has handled; a tracker may create a ticket even when the kit saw a timeout, and the kit does not try to prevent or detect that.
- **Credentials** are the plugin's responsibility: the envelope carries none (the remote URL is stripped), the kit stores none, and the plugin runs with the caller's environment. A missing or rejected credential is an ordinary failure with a clear `message`.
- **Timeout:** one for every plugin call, `aapp.pluginTimeout` seconds (default 10; anything slower is treated as an unreachable network), enforced by the hook dispatcher's watchdog. A plugin that runs past it is ended and the step takes its failure outcome.
- **No plugin:** the kit does everything. **A failing plugin:** each step defines the outcome (fall back or refuse).
- **Plans are not covered yet.** `aapp-planid` and `plan.allocate` stay as they are, bare-number answer included; the exchange above binds the issue steps, and plans follow in their own chapter.
- **Hooks** receive the same envelope and stay notifications; a `pre-` hook blocks with its exit code.
- **Ad hoc plugins and scripts** are outside the protocol: CLI users, guarded by the CLI's own locks and checks. The MANUAL says so.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [x] `tests/plugin_protocol_test.sh::test_message_is_shown` -> asserts the answer's `message` is printed to the user
- [x] `tests/plugin_protocol_test.sh::test_unnamed_part_left_to_kit` -> asserts a part missing from `handled`, and an answer with no `handled`, are reported to the caller as the kit's to do
- [x] `tests/plugin_protocol_test.sh::test_declined_leaves_all_to_kit` -> asserts `status: declined` leaves every part to the kit, exit 0
- [x] `tests/plugin_protocol_test.sh::test_newer_version_refused` -> asserts an answer echoing a `version` newer than the kit's is refused
- [x] `tests/plugin_protocol_test.sh::test_list_file_read_per_line` -> asserts each flat object in `AAPP_PLUGIN_LIST` is delivered to the caller
- [x] `tests/plugin_protocol_test.sh::test_do_runs_after_step_in_order` -> asserts `do` lines run after the plugin exits and the step has released its lock, in order, each result reported; a `do` line needing the issue lock the step held does not wait on it
- [x] `tests/plugin_protocol_test.sh::test_do_refuses_unlisted_command` -> asserts a line not in the subject's whitelist is refused and reported
- [x] `tests/plugin_protocol_test.sh::test_do_continues_after_refusal` -> asserts the lines after a refused one still run
- [x] `tests/plugin_protocol_test.sh::test_do_does_not_recall_plugin` -> asserts a command run from `do` does not call the plugin that asked for it
- [x] `tests/plugin_protocol_test.sh::test_write_verb_refused_inside_plugin` -> asserts a writing `aapp` verb run by a plugin during a step is refused and points to `do`; a reading verb works
- [x] `tests/plugin_protocol_test.sh::test_timeout_ends_plugin` -> asserts a plugin running past the timeout is ended and the step takes its failure outcome
- [x] `tests/plugin_protocol_test.sh::test_envelope_carries_no_secret` -> asserts a remote URL with credentials reaches the plugin stripped
- [x] `tests/plugin_protocol_test.sh::test_reference_matches_code` -> asserts every event and field the code sends, and every `do` command it accepts, is listed in `docs/reference/`

### ♻️ Existing Tests Changed or Retired
> Tests that exist today and assert behaviour this plan changes.
- None expected. The provider fixtures of `tests/verbs/issue.sh` and `tests/plan_resolver_test.sh` answer with only `id` or `status`, which stays valid; `plan.allocate` and its checks are unchanged. A fixture that fails shows an answer form the protocol must still accept.

### Phase 1: Tests First (red)
- [x] Task 1.1: Write `tests/plugin_protocol_test.sh` with a scripted plugin fixture; confirm red.

### Phase 2: Core Implementation
- [x] Task 2.1: Answer reading in `lib/hook_dispatcher.sh`: `status`, `message`, `handled`, `version`, the list file.
- [x] Task 2.2: The `do` list: file, whitelist (`lib/plugin_do.tsv`), runner (after the step releases its lock, in order, each command under its own lock, no re-call, results reported).
- [x] Task 2.3: The step marker in the plugin's environment; writing verbs refuse under it.
- [x] Task 2.4: One timeout for every plugin call: `aapp.pluginTimeout` (default 10 s) through `execute_with_watchdog`.
- [x] Task 2.5: The issue callers (`issue.allocate`, `issue.close`) and the issue-tracker sample answer in the protocol. `plan.allocate` keeps its present answer forms (`{"id": …}` or a bare number) and its tests: plans get their own chapter of the protocol later.
- [x] Task 2.6: `docs/reference/06-plugin-protocol.md` and `07-issue-protocol.md` (today's events); the reference test.

### Phase 3: Verification & Documentation
- [x] Task 3.1: Run automated test suites and verify edge cases.
- [x] Task 3.2: Update user-facing documentation per `.agents/PROJECT.MD` (`MANUAL.md`, `README.md`, or `docs/`) if CLI verbs, configuration, or workflows were introduced or changed.
- [x] Task 3.3: Architecture and Codemap sections (CODEMAP §5) live in group P-72.
- [x] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [x] Task 3.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/hook_dispatcher.sh` -> Answer reading, list file, `do` runner, step marker, timeout.
- [ ] `NEW FILE` -> `lib/plugin_do.tsv` -> The `do` whitelist: subject, command.
- [ ] `aapp` -> Writing verbs refuse under the step marker.
- [ ] `lib/plan_resolver.sh` -> The issue allocation caller reads the answer through the protocol; `plan.allocate` unchanged.
- [ ] `lib/cmd_issue.sh` -> The close caller reads the answer through the protocol.
- [ ] `examples/plugins/aapp-issue-tracker/run.sample` -> Answers in the protocol.
- [ ] `NEW FILE` -> `docs/reference/06-plugin-protocol.md` -> The exchange.
- [ ] `NEW FILE` -> `docs/reference/07-issue-protocol.md` -> Issue events, fields, `do` commands.
- [ ] `MANUAL.md` -> Plugin protocol; ad hoc plugins are CLI users.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/plugin_protocol_test.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/aapp-pre-commit` -> Hooks keep their contract.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — The form of the exchange? → RESOLVED (developer, 2026-10-12):** the kit asks with the whole subject; the plugin answers with what happened, what it handled and what it produced; wanted operations are aapp command lines the kit runs after the step.
* [x] **Question 2 — The words? → RESOLVED (developer, 2026-10-12):** `handled` for what the plugin took care of; `do` for the list of commands (used in the flow of many languages, self-describing).
* [x] **Question 3 — A `do` command that is refused? → RESOLVED (developer, 2026-10-12):** reported, and the rest still run.
* [x] **Question 5 — Credentials? → RESOLVED (developer, 2026-10-12):** the plugin's responsibility; there are many ways to implement it. The kit carries no secret: none in the envelope, none stored.

---

## 📦 6. Change Log & Refinement History
* **2026-10-12:** Plan implementation completed and archived to done/.
* **2026-10-12:** Plan frozen and activated into ⚡ In Development via freeze-start.
*Tracks how the plan evolved across sessions.*
* **2026-10-12:** Drafted as a member of P-72.
