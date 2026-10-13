# 🗺️ Plan P-87: Rules On Demand
* **Created:** 2026-10-13 | **Last Refined:** 2026-10-13
* **Target Issue / Milestone:** #120
* **Plan ID:** P-87
* **Changelog:** Changed: `aapp help <verb>` is short and answers `aapp <verb> help`; `/aapp` start skill; the rules file drops its per-verb walkthroughs
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `6424d2f` (develop)
* **Worktree:** .workspace/P87 (plan/P87-rules-on-demand)
* **Commits:** `4d7ee97` (plan/P87-rules-on-demand), `a8e297f` (plan/P87-rules-on-demand)
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
An agent gets the kit's rules from `.agents/AGENTS.md`, which its IDE loads at session start. The file is 51 KB, and some agents cut what they load at session start, so the end of the rules may never reach the agent. About 170 of its 397 lines are per-verb material that exists elsewhere: the skills carry each verb's procedure, and the contracts in `lib/docs/verbs/` carry its syntax. Two of the walkthroughs (`done`, `status`) describe doing by hand what the skills forbid.

Syntax is also not at hand when it is needed: `aapp help <verb>` prints the whole contract (253 lines for `issue`), and `help` typed after a verb is taken as an argument (#120: `aapp tdd help` drafted and committed a plan named `help`).

Three changes, one aim: the rules file holds rules, and the rest is read when needed.

1. **`/aapp`, a start skill.** It tells the agent to read `.agents/AGENTS.md` in full with its own file tool, which the session-start cut does not apply to, then to run `aapp status` and give a briefing.
2. **Help at the moment of use.** `aapp help <verb>` prints the synopsis and the arguments; `full` prints the whole contract; `aapp <verb> help` is the same command.
3. **A shorter rules file.** The per-verb walkthroughs and the onboarding section leave `templates/AGENTS.md`; the CLI Reference stays as the index of verbs and points at `aapp help <verb>`.

The size of the file is not capped: a project's own rules, `PROJECT.MD` and the code map may be larger than any limit. What matters is that they are read by the agent, not injected by the IDE.

---

## 2. Technical Blueprint
### 2.1 `aapp help` (`lib/cmd_help.sh`)

| Command | Prints |
| :--- | :--- |
| `aapp help` | the catalog, as today |
| `aapp help <verb>` | the contract's first line (the synopsis, written as `aapp <verb> …`) and its `## Ingress` section; a last line names `aapp help <verb> full` |
| `aapp help <verb> full` | the whole contract, as `aapp help <verb>` prints today |
| `aapp <verb> help` | the same as `aapp help <verb>` |

- A verb without a contract prints its description from `lib/verbs.tsv`, as today.
- An unknown verb exits 1, as today.
- `help` gets its own contract, `lib/docs/verbs/help.md`, named in `lib/verbs.tsv`.

### 2.2 `help` after a verb (`aapp`)

The dispatcher answers `aapp <verb> help` before the verb runs: when the first argument after a known verb is exactly `help`, it runs `aapp help <verb>` and exits 0. No verb sees the word, so none can take it as a slug, an id or a reason. One place, every verb. A plan can no longer be drafted under the slug `help`; that is intended.

### 2.3 The start skill (`templates/skills/aapp/SKILL.md`)

Name `aapp`, invoked as `/aapp`. Its text, in substance:

1. Read `.agents/AGENTS.md` in full with the file tool, to its last line.
2. Run `aapp status`.
3. Give a short briefing.
4. Before using a verb for the first time in a session, run `aapp help <verb>`.
5. Read `.agents/PROJECT.MD` and `.agents/CODEMAP.md` when the task touches the code they describe.
6. Run `/aapp` again after the conversation was summarised.

Paths are relative to the repository root. The text names no agent's tools (`view_file`, `run_command`, `Read`), so one file serves every agent.

`sync_skills` in `lib/cmd_init.sh` installs `aapp-*` and `plan`; it also installs `aapp`, to `.agents/skills/aapp/` and the Claude Code bridge.

### 2.4 The rules file (`templates/AGENTS.md`)

Removed from "Asymmetric Planning Protocol (AAPP) & Universal Skills":
- the step-by-step entries for `status`, `digest`, `freeze-start`, `freeze`, `start`, `plan`, `active`, `done`, `release`, `pause`, `resume`;
- "First-Run Repository Onboarding (Day 1 Experience)".

Kept there:
- the Canonical Planning Invariant, unchanged: it must reach an agent asked to plan in plain words;
- one paragraph: `/aapp` starts a session, and a verb's syntax comes from `aapp help <verb>`;
- a skill index: one sentence (each skill's instructions are in `.agents/skills/<name>/SKILL.md`; follow that file when running the workflow) and a two-column table, the slash command and when to use it, with a row for every skill the kit ships with a `SKILL.md`: `/aapp`, `/aapp-status`, `/aapp-digest`, `/aapp-plan`, `/plan`, `/aapp-tdd`, `/aapp-freeze`, `/aapp-start`, `/aapp-done`, `/aapp-fix`, `/aapp-pause`, `/aapp-release`. It serves an agent without skill support, which reaches a skill only by opening its file.

"CLI Reference" stays the index of verbs, one row per verb with its name and purpose, without the syntax. The two tables are all the rules file says about commands. A rule that a removed walkthrough was the only place for moves to the section it belongs to; none is dropped (Task 2.4 lists them before removing).

### 2.5 Onboarding (`templates/pickup.md`)

The seeded `Onboarding` item carries what the removed section said about the work: inspect the layout, build manifests, dependencies and entry points, and replace the template placeholders in `.agents/CODEMAP.md`, `ARCHITECTURE.md` and `.agents/PROJECT.MD`. The instruction lives with the task and goes when the task is done. `aapp init` and the adoption checklist already name `/aapp-digest Onboarding`.

### 2.6 Not in this plan

- Contracts for the verbs that have none (`pause`, `resume`, `init`, `push`, `pull`, `sync`, the hook verbs).
- A gate that makes an agent run `/aapp`: nothing can.
- P-70, drafted by the bug in #120: abandoned with `aapp plan abort P-70`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`

- [ ] `tests/verbs/help.sh::test_help_verb_is_short` -> asserts `aapp help commit` prints the contract's first line and its Ingress section, and no `## Failure modes` or `## Tests`
- [ ] `tests/verbs/help.sh::test_help_verb_full` -> asserts `aapp help commit full` prints the whole contract
- [ ] `tests/verbs/help.sh::test_help_names_full` -> asserts the short form's last line names `aapp help commit full`
- [ ] `tests/verbs/help.sh::test_help_after_verb` -> asserts `aapp tdd help`, `aapp draft help` and `aapp issue help` print the same as `aapp help <verb>`, exit 0, and leave `.plans` without a new plan or commit
- [ ] `tests/verbs/help.sh::test_help_after_verb_without_contract` -> asserts `aapp pause help` prints the verb's description and does not pause
- [ ] `tests/verbs/help.sh::test_help_unknown_verb` -> asserts `aapp help nosuch` exits 1 naming `aapp help`
- [ ] `tests/template_sync_test.sh::test_start_skill_text` -> asserts `templates/skills/aapp/SKILL.md` is named `aapp`, names `.agents/AGENTS.md`, `aapp status` and `aapp help`, and holds no absolute path and no agent's tool name
- [ ] `tests/template_sync_test.sh::test_init_installs_start_skill` -> asserts `aapp init` leaves `.agents/skills/aapp/SKILL.md` and `.claude/skills/aapp`
- [ ] `tests/template_sync_test.sh::test_onboarding_item_carries_instruction` -> asserts the seeded `Onboarding` item names the three files and the placeholders to replace
- [ ] `tests/verb_contracts_test.sh::test_rules_file_has_no_walkthroughs` -> asserts `templates/AGENTS.md` holds no onboarding section and no hand-made archive steps (`mv .plans/current`), and keeps the Canonical Planning Invariant
- [ ] `tests/verb_contracts_test.sh::test_rules_file_points_to_help` -> asserts the rules file names `/aapp` and `aapp help <verb>`
- [ ] `tests/verb_contracts_test.sh::test_every_skill_in_rules_index` -> asserts every directory of `templates/skills/` that holds a `SKILL.md` has a row in the rules file's skill index, and the index names `.agents/skills/<name>/SKILL.md`

### Phase 1: Failing tests
- [ ] Task 1.1: Write the tests above; `tests/verbs/help.sh` is new. Commit them red.

### Phase 2: Core Implementation
- [ ] Task 2.1: `lib/cmd_help.sh`: short form, `full` token; `lib/docs/verbs/help.md` and its `lib/verbs.tsv` cell.
- [ ] Task 2.2: `aapp`: `help` after a known verb runs `aapp help <verb>`.
- [ ] Task 2.3: `templates/skills/aapp/SKILL.md`; `sync_skills` installs it.
- [ ] Task 2.4: `templates/AGENTS.md`: list every rule the removed entries alone state, move each to its section, then remove the entries and the onboarding section; add the skill index; trim the CLI Reference to one row per verb.
- [ ] Task 2.5: `templates/pickup.md`: the `Onboarding` item's text.

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
- [ ] `lib/cmd_help.sh` -> short form and `full`.
- [ ] `aapp` -> `help` after a verb.
- [ ] `lib/cmd_init.sh` -> `sync_skills` installs the `aapp` skill.
- [ ] `lib/verbs.tsv` -> the `help` row names its contract.
- [ ] `NEW FILE` -> `lib/docs/verbs/help.md` -> the `help` contract.
- [ ] `NEW FILE` -> `templates/skills/aapp/SKILL.md` -> the start skill.
- [ ] `templates/AGENTS.md` -> walkthroughs and onboarding removed; CLI Reference trimmed.
- [ ] `templates/pickup.md` -> the `Onboarding` item's text.
- [ ] `MANUAL.md` -> `aapp help`, the start skill.
- [ ] `CHEATSHEET.md` -> `aapp help <verb> [full]`, `aapp <verb> help`.
- [ ] `NEW FILE` -> `tests/verbs/help.sh` -> the help tests.
- [ ] `tests/template_sync_test.sh` -> skill and onboarding tests.
- [ ] `tests/verb_contracts_test.sh` -> rules file tests.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/verbs/help.sh`
- [ ] `tests/template_sync_test.sh`
- [ ] `tests/verb_contracts_test.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/skills/aapp-status/SKILL.md` -> stays the status alone.
- [ ] `lib/docs/verbs/` -> the other contracts are read, not changed.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — Does `aapp help <verb> <word>` narrow the answer to one form? → RESOLVED (developer, 2026-10-13):** not in this plan. The contracts' Ingress lines are not tied to a form.
* [x] **Question 2 — Is the skill named exactly `aapp`? → RESOLVED (developer, 2026-10-13):** yes. It is tried in Claude Code and Antigravity during implementation; a clash with the command is reported before the plan is done.
* [x] **Question 3 — Does the CLI Reference keep each verb's syntax? → RESOLVED (developer, 2026-10-13):** name and purpose only; the syntax comes from `aapp help <verb>`.

---

## 📦 6. Change Log & Refinement History
* **2026-10-13:** Plan frozen and activated into ⚡ In Development via freeze-start.
*Tracks how the plan evolved across sessions.*
* **2026-10-13:** Plan initialized from `pickup.md`.
* **2026-10-13:** Refined blast radius and locked module boundaries.
