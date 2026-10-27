# 🗺️ Plan P-139: Plan Noun
* **Created:** 2026-10-27 | **Last Refined:** 2026-10-27
* **Target Issue / Milestone:** none
* **Plan ID:** P-139
* **Changelog:** Changed: every plan command moves under `aapp plan` (`plan draft`, `plan freeze`, `plan start`, `plan done`, `plan status`, …), and `refine`'s plan forms become one word per action (`plan commit`, `plan rename`, `plan block`, …)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-140
* **Commits:** none
<!-- AAPP-PROTOCOL:START v0.9.0 -->
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
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp issue log <sev> <type> "<symptom>" file <path>…`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
A member of group P-140 (noun-first CLI). Every command that acts on a plan moves under `aapp plan`: the lifecycle verbs (`draft`, `tdd`, `freeze`, `start`, `freeze-start`, `done`, `active`), the read-only ones (`plan-status`, `matrix`), and the plan forms of `refine`, which split into one word per action. The words that already live under `plan` (`abort`, `conflict-check`, `conflict-free`) move into the same layout. The behaviour of every command stays as it is; what changes is its name, its module and where its contract lives. Runs after the Perl port (P-111): the code moved is the ported Perl code. The group's §2 rules apply (module layout, one parameter per layer, one public `run`, one action per word, clean break).

---

## 2. Technical Blueprint

### 2.1 The noun
- `lib/AAPP/Runner/Plan.pm` (`AAPP::Runner::Plan`): reads one parameter, the word, and calls `AAPP::Runner::Plan::<Word>->run(@rest)` through the delegate step in `AAPP::Runner`; a hyphenated word joins its parts (`freeze-start` → `FreezeStart`).
- Bare `aapp plan [query]`: the switchboard, keeping its query. The first parameter is a word when it is one of §2.2 (they are reserved, §2.3); anything else is the query.
- An unknown word is refused, naming every word of §2.2.
- `aapp help plan` lists the words; `aapp help plan <word>` prints one word's arguments, `full` its refusals and effects.

### 2.2 The words
Each word does exactly what the command in the first column does today: same arguments, refusals, effects, events and output, except where the second column changes the arguments.

| Today | After | Module (`lib/AAPP/Runner/Plan/…`) |
|---|---|---|
| `aapp draft [slug] [issue <num> \| group [<id>]]` | `aapp plan draft [slug] [issue <num> \| group [<id>]]` | `Draft.pm` |
| `aapp tdd <id>` | `aapp plan tdd <id>` | `Tdd.pm` |
| `aapp freeze <id>` | `aapp plan freeze <id>` | `Freeze.pm` |
| `aapp start <id> [worktree <path> [branch <name>]] \| <group> [base <branch>]` | `aapp plan start …` (same tokens) | `Start.pm` |
| `aapp freeze-start <id> [worktree <path> [branch <name>]]` | `aapp plan freeze-start …` | `FreezeStart.pm` |
| `aapp done <id> [integrate … \| no-integrate]` | `aapp plan done …` (same tokens) | `Done.pm` |
| `aapp active [<id> \| swap \| clear]` | `aapp plan active [<id> \| swap \| clear]` | `Active.pm` |
| `aapp plan-status [<id>]` | `aapp plan status [<id>]` | `Status.pm` |
| `aapp matrix [check]` | `aapp plan matrix [check]` | `Matrix.pm` |
| `aapp refine <id> "<what changed>"` | `aapp plan commit <id> "<what changed>"`: commits plan text, not code (group §2) | `Commit.pm` |
| `aapp refine <id> slug <new-slug>` | `aapp plan rename <id> <new-slug>` | `Rename.pm` |
| `aapp refine <id> blocked <num>` | `aapp plan block <id> <num>` | `Block.pm` |
| `aapp refine <id> unblocked <num>` | `aapp plan unblock <id> <num>` | `Unblock.pm` |
| `aapp refine <id> closes <num>` / `closes <num> remove` | `aapp plan closes add <id> <num>` / `aapp plan closes remove <id> <num>` | `Closes.pm` |
| `aapp refine <id> group <group>` / `group none` | `aapp plan join <id> <group>` / `aapp plan leave <id>` | `Join.pm`, `Leave.pm` |
| `aapp refine <amend-id> request "<summary>" [file <path> [for <plan-id>] \| heading "<heading>"]` | `aapp plan amend request <amend-id> …` | `Amend.pm` |
| `aapp refine <amend-id> approve <n>` / `refuse <n> "<reason>"` | `aapp plan amend approve <amend-id> <n>` / `aapp plan amend refuse <amend-id> <n> "<reason>"` | `Amend.pm` |
| `aapp refine <amend-id> decision <n> "<reason>"` / `decision "<heading>" "<reason>"` | `aapp plan amend decision <amend-id> …` (same tokens) | `Amend.pm` |
| `aapp plan abort <id> …` | unchanged | `Abort.pm` |
| `aapp plan conflict-check <id> <id>… [json]` | unchanged | `ConflictCheck.pm` |
| `aapp plan conflict-free [<id> \| <group>] [json]` | unchanged | `ConflictFree.pm` |

- Arguments follow the word, then the plan: `aapp plan <word> <id> …`. `closes` and `amend` take their action first (`closes add`, `amend approve`), then the plan.
- Events keep their names (`pre-freeze`, `post-done`, `pre-refine`, …); the payload's `command` names the new form. `pre-refine` / `on-refine` / `post-refine` keep firing for the words that came from `refine` (`commit`, `rename`, `block`, `unblock`, `closes`, `join`, `leave`, `amend`), with the same `kind` values.
- The two `refine` forms that are not about a plan (`refine pickup`, `refine issues`) are not this plan's: P-142 and the issue member move them. `refine` leaves the kit when the last of the three lands.

### 2.3 Reserved words
Every word of §2.2 is reserved after `aapp plan`. The plan resolver refuses a slug equal to one (`a plan named like a plan word is named by its id: P-<n>`), so `aapp plan status` is never read as a plan called `status`. `aapp plan draft <slug>` refuses such a slug, naming the word.

### 2.4 Everything that names an old form
Clean break: after this plan, nothing in the kit names `aapp draft`, `aapp tdd`, `aapp freeze`, `aapp start`, `aapp freeze-start`, `aapp done`, `aapp active`, `aapp plan-status`, `aapp matrix`, or the plan forms of `aapp refine`. Changed in this plan:
- `lib/verbs.tsv`: the old rows go; the `plan` row lists its words.
- The contracts: one contract for the noun and all its words, `lib/docs/verbs/plan.md`, as P-138 does for `review`; today's `lib/docs/verbs/<verb>.md` of each moved verb is merged into it and removed. One test file, `t/verb/plan.t`, one test per contract line.
- Messages: every refusal, hint and next action the kit prints that names an old form (`Next Action`, `Run 'aapp freeze …'`, …).
- The agent rules (`templates/AGENTS.md`), the skills (`templates/skills/`), the templates' comments (`templates/plan-template.md`, `templates/group-template.md`, `templates/amendments-template.md`).
- The user docs: `README.md`, `MANUAL.md`, `CHEATSHEET.md`, `COOKBOOK.md`, `CONTRIBUTING.md`, `docs/`.
- Wherever `aapp plan commit` or `aapp commit` is named, the other is named beside it with the difference (group §2).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: The noun
- [ ] Task 1.1: The `plan` contract `lib/docs/verbs/plan.md`: the noun, its words, `help plan` (§2.1, §2.4).
- [ ] Task 1.2: `t/verb/plan.t`: tests for the noun, the query and the reserved words, failing first.
- [ ] Task 1.3: `lib/AAPP/Runner/Plan.pm` and the reserved-word refusal in the plan resolver (§2.3).

### Phase 2: The words
- [ ] Task 2.1: Read-only words first: `status`, `matrix`, `conflict-check`, `conflict-free`.
- [ ] Task 2.2: Lifecycle words: `draft`, `tdd`, `freeze`, `start`, `freeze-start`, `done`, `active`, `abort`.
- [ ] Task 2.3: Plan edits: `commit`, `rename`, `block`, `unblock`, `closes`, `join`, `leave`.
- [ ] Task 2.4: `amend`.
- [ ] Task 2.5: Each word's tests carried over from today's verb tests, renamed, green.

### Phase 3: Clean break & documentation
- [ ] Task 3.1: `lib/verbs.tsv`, the old contracts, messages (§2.4).
- [ ] Task 3.2: Rules, skills, templates (§2.4).
- [ ] Task 3.3: User docs (§2.4); the `plan commit` / `commit` note wherever either is named.
- [ ] Task 3.4: `grep` the kit for every old form of §2.4: none left outside `CHANGELOG.md` and the plans archive.
- [ ] Task 3.5: Run `t/test-run` and the remaining bash suites; both green.
- [ ] Task 3.6: Log every finding outside the Target Files as an issue (`aapp issue log`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Plan.pm` -> the noun (§2.1)
- [ ] `lib/AAPP/Runner/Plan/` -> one module per word (§2.2)
- [ ] `lib/AAPP/Runner/` -> the ported modules of the moved verbs leave their top-level place
- [ ] `lib/AAPP/State.pm` -> the reserved-word refusal in the plan resolver (§2.3)
- [ ] `lib/verbs.tsv` -> rows (§2.4)
- [ ] `lib/docs/verbs/` -> the `plan` contract; the moved verbs' contracts (§2.4)
- [ ] `t/verb/` -> the `plan` tests
- [ ] `templates/AGENTS.md` -> rules naming the new forms
- [ ] `templates/skills/` -> skills naming the new forms
- [ ] `templates/plan-template.md` -> comments naming the new forms
- [ ] `templates/group-template.md` -> comments naming the new forms
- [ ] `templates/amendments-template.md` -> comments naming the new forms
- [ ] `README.md` -> user docs
- [ ] `MANUAL.md` -> user docs
- [ ] `CHEATSHEET.md` -> user docs
- [ ] `COOKBOOK.md` -> user docs
- [ ] `CONTRIBUTING.md` -> user docs
- [ ] `docs/` -> user docs
- [ ] `CHANGELOG.md` -> the plan's entry
*(The ported modules' exact files are known once P-111 is done; they are confirmed here before freeze.)*

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/Runner/Issue/` -> the issue words belong to the issue member
- [ ] `lib/AAPP/Runner/Pickup/` -> P-142

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1:** `aapp plan [query]` today takes a positional query; does the bare switchboard keep a query, and how is it told apart from a word? **Answer:** yes, it keeps the query; a word of §2.2 is a word, anything else is the query (§2.1).
* [x] **Question 2:** Contracts and tests for about twenty words: one `lib/docs/verbs/plan.md` and one `t/verb/plan.t`, as P-138 does for `review`, or one contract and test file per word (`plan/<word>.md`, `plan.<word>.t`)? **Answer:** one contract, `lib/docs/verbs/plan.md`, and one test file, `t/verb/plan.t` (§2.4).

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-27:** Drafted with the verb conversion; details come in refinement.
* **2026-10-27:** Became the dispatcher member of group P-140; the verb conversion is the group's §2.
* **2026-10-27:** File renamed from P139-noun-first-plan-commands.md to P139-plan-command-dispatcher.md.
* **2026-10-27:** File renamed from P139-plan-command-dispatcher.md to P139-plan-noun.md.
* **2026-10-27:** Every plan command moved in from the group's §2: the words, their modules, reserved words and the clean break are this plan's; the group keeps only the shared rules.
