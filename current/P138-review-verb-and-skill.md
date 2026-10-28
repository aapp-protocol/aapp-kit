# 🗺️ Plan P-138: Review Verb And Skill
* **Created:** 2026-10-26 | **Last Refined:** 2026-10-26
* **Target Issue / Milestone:** none
* **Plan ID:** P-138
* **Changelog:** Added: `aapp review` verb and `/aapp-review` skill: an RFC drafted from a template, signed implementation findings in a plan's §7 and their follow-up fixes in §8
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `0b6c95b` (feature/perl-port-of-the-kit)
* **Worktree:** .workspace/P138 (plan/P138-review-verb-and-skill)
* **Group:** P-111
* **Commits:** `d098a78` (plan/P138-review-verb-and-skill)
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
Reviews of important plans run today through hand-made files in `.plans/pickup/` (RFCs, review scratch files): their structure is a habit, their findings are not tracked against the work that answers them, and nothing stops a plan from landing with findings unanswered. This plan builds review into the kit as its own verb, `aapp review`, and one skill, `/aapp-review <id>`:
- **Design** (plan 🟣/📝): the plan's RFC, drafted from a template with the sections every RFC so far has used.
- **Implementation** (plan ⚡): signed findings in the plan's §7, answered by the implementer's follow-up fixes in §8, checked before `done`.

One verb per noun keeps the meaning plain for people and agents (no overloading of `refine`). The commands live in `lib/AAPP/Runner/Review/`, one module per word, so the noun-first CLI planned after the port (`aapp plan …`) does not touch it. A richer review workflow can come later as a plugin (P-15 after the port).

---

## 2. Technical Blueprint

### 2.1 Commands
| Command | From | Effect |
|---|---|---|
| `aapp review draft <id>` | any checkout | creates `.plans/pickup/p<n>-<slug>-rfc.md` for plan `<id>` from `templates/rfc-template.md`; no commit: `pickup/` is the local, ignored store |
| `aapp review draft <slug>` | any checkout | creates `.plans/pickup/<slug>-rfc.md` before any plan exists (a topic that may become one plan or a group); its §1 is seeded from the pickup line whose title normalises to `<slug>`, when there is one; no commit |
| `aapp review flag <id> "<finding>" [file <path>]` | any checkout | appends a signed finding `F<n>` to §7 of plan `<id>`; append only |
| `aapp review fix <id> F<n> "<task>"` | the plan's own checkout | appends `- [ ] F<n>: <task>` to §8; the finding becomes `planned` |
| `aapp review fix done <id> F<n>` | the plan's own checkout | ticks the task; the finding becomes `done` |
| `aapp review fix decline <id> F<n> "<reason>"` | the plan's own checkout | the finding becomes `declined: <reason>`; no task |
| `aapp review check <id>` | any checkout | read only: exit 0 when the plan has no §7, or every finding is `done` / `declined` and every §8 task is ticked; else exit 1, listing each open finding and unticked task |

**The `done` gate until the Perl `done` (P-119):** the repository's `pre-done` gate, `.agents/hooks/test-gate.sh`, runs `aapp review check <plan_id>` (the id from the event envelope) before its `TEST_CMD`, so `done` refuses open findings now, with no change to the bash `done`. The edited gate is re-registered with `aapp hook-hash .agents/hooks/test-gate.sh pre-done 900 gate`. P-119 then calls `AAPP::Review::gate` from the Perl `done`, and the gate line goes; P-118 shows `fixes x/y` in `status`; P-119's `draft` calls `AAPP::Rfc::link`. Those lines reach P-118 and P-119 through P-112 requests.

Every form refuses with nothing written when its preconditions fail (§2.4). `flag` and `fix` commit once through `AAPP::CommitEngine::plans_commit`; `draft` writes a local file only.

**An RFC is local.** It lives in the ignored `pickup/` store and never reaches another clone. A plan drafted from a topic that has an RFC names it in its §1 as a local reference, and the RFC's `## 5. Carried Into Plans` gains the plan; every decision the plan relies on is written into the plan itself (§1/§2), never left only in the RFC. RFCs are temporary and may be deleted from `pickup/`: nothing in the kit reads one after the plan is drafted, and a missing RFC is never an error.

### 2.2 The review kind follows the plan's Status
- 🟣 Under Review / 📝 Refining: design review. `review draft <id>` applies; `review flag` and `review fix` refuse (`design findings go in the plan's RFC`).
- ⚡ In Development: implementation review: `flag` and `fix` apply.
- 🔷 Frozen, 🟥 BLOCKED, ✅ Done: every form refuses, naming the Status.
The skill reads the Status and runs the matching review; the verb enforces it.

### 2.3 Plan sections and line formats
- `## 🔍 7. Implementation Review` and `## 🧩 8. Review Fixes`, after §6, each heading written on first use (as `### Amendments`). Neither is design-locked; §2/§4 stay locked.
- Finding: `- **F<n>** <date> · <reviewer> · [`<path>` (outside targets: needs an amendment) · ]<finding> — <state>`; `<reviewer>` is the agent identity (`AAPP::Attribution::resolve_ai_identity`), else `user.name`; `<state>` ∈ `open`, `planned`, `done`, `declined: <reason>`. Only `<state>` ever changes.
- Fix: `- [ ] F<n>: <task>` / `- [x] F<n>: <task>`, one per finding.
- A finding's `file <path>` outside the plan's Target Files is a hint for the implementer: the reviewer never opens an amendment request. The implementer opens it (`aapp refine <amend-id> request … file <path>`) and names it in the task (`F4: … (R48)`); `fix done <id> F<n>` refuses until that request is approved and its amendment commit has landed.
- Numbering: `F<n>` continues from the highest in §7; a plan's findings are never renumbered.

### 2.4 Refusals (each exit 1, nothing committed)
- unknown plan, or a Status the form does not apply to (§2.2);
- `review draft` when the RFC file exists; `<slug>` empty after normalising;
- `review fix` from a checkout that does not own the plan (the P-99 owner rule, via `AAPP::State::held_plans` / `plan_held_by`); `F<n>` unknown, or not in the state the form needs (`fix <id> F<n> "<task>"` needs `open`; `fix done` needs `planned`; `fix decline` needs `open` or `planned`); an empty task or reason; a plan whose slug is `done` or `decline` is named by its id (`P-<n>`), as both words are reserved after `fix`;
- `fix done` with a named or required amendment not landed (§2.3).

### 2.5 The RFC template (`templates/rfc-template.md`)
The five sections the RFCs in `.plans/pickup/` already share: `## 1. Scope & Question`, `## 2. Current State`, `## 3. Findings Log (append-only, signed; never edit another block)`, `## 4. User Decisions (recorded only from the user's own words)`, `## 5. Carried Into Plans`; the header names the plan (or the pickup topic) and the date. Signed block heading: `### <date> — <agent> (<vendor>, <model>) — <subject>`.

### 2.6 Modules
Every CLI command lives under `lib/AAPP/Runner/`, every other module stays a single module in `lib/AAPP/` (the layout group P-140 decides for every command).
- **The CLI hierarchy, built here** (the first noun in Perl, for every command after it):
  - `AAPP::Runner` reads only the first parameter and calls `AAPP::Runner::<Name>->run(@rest)`; a noun module (`AAPP::Runner::Review`) reads only its first parameter, the word, and calls `AAPP::Runner::Review::<Word>->run(@rest)`. The step "read one token, find the module, call its `run` with the rest, refuse an unknown or missing token naming what exists" is written once, in `AAPP::Runner`, and every layer calls it.
  - The `aapp` dispatcher routes a name with a `lib/AAPP/Runner/<Name>.pm` to `AAPP::Runner`, in place of today's `lib/AAPP/Cmd/<Verb>.pm` check.
  - Every module under `lib/AAPP/Runner/` has one public sub, `run`; its other subs are private (`_name`).
- Noun: `lib/AAPP/Runner/Review.pm` (picks the word; bare `aapp review` lists the words).
- Words: `lib/AAPP/Runner/Review/Draft.pm` (`review draft`), `Flag.pm` (`review flag`), `Fix.pm` (`review fix`, `fix done`, `fix decline`), `Check.pm` (`review check`).
- Shared, in `lib/AAPP/`: `AAPP::Rfc`, the RFC file (create from the template, `link` a plan drafted from it); `AAPP::Review`, a plan's §7/§8 (parse, number, append, state change, tick, the amendment check, `counts($plan)` for `fixes <done>/<total>`, `gate($plan)` for open findings and unticked tasks).
- Plan lookup, sections, fields, ownership, commits and paths come from `AAPP::State`, `AAPP::CommitEngine` and `AAPP::Paths`; no module rebuilds them.

### 2.7 Telemetry
`AAPP::Logger::log_event('review', <form>, {...})` per `.plans/pickup/perl-port-logging-events-spec.md`: `review.draft` (`target`, `file`), `review.flag` (`plan_id`, `finding`, `file`, `outside_targets`), `review.fix` (`plan_id`, `finding`, `action` ∈ `task`/`done`/`decline`). The three events are added to the spec.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 0: The CLI hierarchy for the whole port
- [x] Task 0.1: From this plan's worktree, request the group decision: `aapp refine P-112 request "CLI hierarchy for every ported command: everything that is a CLI command lives under lib/AAPP/Runner/ (top-level verbs Runner/<Verb>.pm; nouns plan, issue, review, pickup as Runner/<Noun>.pm with words in Runner/<Noun>/<Word>.pm), each with one public sub run; AAPP::Runner reads one parameter per layer and maps today's verb names to the new modules until P-140 renames the commands; all other modules stay single modules in lib/AAPP/; no lib/AAPP/Cmd/" heading "2. Shared Decisions"`. Once approved, the P-112 session writes it into P-111 §2 and aligns the members that name `lib/AAPP/Cmd/` (P-117–P-121, P-130, P-131, P-134, P-125, P-135) before any of them starts.
- [x] Task 0.2: From this plan's worktree, request the new member order: `aapp refine P-112 request "member order: P-116, P-138, then P-136 (test engine and mock repo) and P-135 (sweep of every test that exists by then and runs git under the hood: t/core/*.t and t/verb/review.t) before the ports P-117–P-121, P-131, P-130, so each port writes its Perl tests once, on the engine it keeps; the bash verb suites stay the safety net beside it; then P-134, P-125, P-122, P-137, P-112 last" heading "3. Members & Order"`. Once approved, the P-112 session writes the order into P-111 §3 (and the matching line of §2), and adds `t/verb/review.t` to P-135's scope.

### Phase 1: Contract and failing tests
- [x] Task 1.1: Write `lib/docs/verbs/review.md` (syntax, refusals of §2.4, effects, one test line each) and the `review` row in `lib/verbs.tsv`.
- [x] Task 1.2: Write `t/verb/review.t` from the contract lines, failing first.

### Phase 2: Modules and verb
- [ ] Task 2.1: `templates/rfc-template.md`, `AAPP::Rfc` (create, `link`) and `AAPP::Runner::Review::Draft` (`review draft <id>` / `<slug>`).
- [ ] Task 2.2: `AAPP::Review` (§7/§8, the amendment check, `counts`, `gate`) and `AAPP::Runner::Review::Flag` (`review flag`).
- [ ] Task 2.3: `AAPP::Runner::Review::Fix` (`review fix <id> F<n> "<task>"`, `review fix done <id> F<n>`, `review fix decline <id> F<n> "<reason>"`) and `AAPP::Runner::Review::Check` (`review check`).
- [ ] Task 2.4: The CLI hierarchy: `AAPP::Runner` reads one parameter per layer (the one delegate step every layer calls); `aapp` routes a name with a `lib/AAPP/Runner/<Name>.pm`; `AAPP::Runner::Review` picks the word; add the review events to the logging spec.
- [ ] Task 2.5: `.agents/hooks/test-gate.sh` runs `aapp review check <plan_id>` before `TEST_CMD`; ask the developer to re-register it (`aapp hook-hash .agents/hooks/test-gate.sh pre-done 900 gate`).
- [ ] Task 2.6: Request through P-112 the lines for P-118 (`fixes x/y` in `status`) and P-119 (`done` calls `AAPP::Review::gate` and the gate line in `test-gate.sh` goes; `draft` calls `AAPP::Rfc::link`).

### Phase 3: Skill, templates and docs
- [ ] Task 3.1: `templates/skills/aapp-review/SKILL.md`: reads the plan's Status, runs a design review through its RFC or an implementation review through `review flag`; never opens amendment requests.
- [ ] Task 3.2: `templates/plan-template.md`: a comment naming §7/§8 and the verb that writes them; `templates/AGENTS.md`: the `/aapp-review` skill row and the `aapp review` CLI row.
- [ ] Task 3.3: `CHEATSHEET.md`, `MANUAL.md`, `docs/reference/02-cli-commands-and-verbs.md`, `docs/reference/19-skills-and-slash-commands.md`.
- [ ] Task 3.4: Request the group's `## Architecture & Codemap` lines for `lib/AAPP/Runner/` and the shared `AAPP::Rfc` / `AAPP::Review` through P-112 (members do not edit `ARCHITECTURE.md` / `.agents/CODEMAP.md`).

### Phase 4: Verification
- [ ] Task 4.1: `t/test-run strict quiet` and `./aapp test strict quiet` pass.
- [ ] Task 4.2: Log every finding outside the Target Files as an issue (`aapp issue log`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `aapp` -> Routes a name with a `lib/AAPP/Runner/<Name>.pm` to `AAPP::Runner`.
- [ ] `lib/AAPP/Runner.pm` -> Reads the first parameter, calls `AAPP::Runner::<Name>->run(@rest)`; the one delegate step every layer calls.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Review.pm` -> The `review` noun: picks the word; bare `aapp review` lists the words.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Review/Draft.pm` -> `review draft`.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Review/Flag.pm` -> `review flag`.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Review/Fix.pm` -> `review fix`, `fix done`, `fix decline`.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Review/Check.pm` -> `review check`.
- [ ] `NEW FILE` -> `lib/AAPP/Rfc.pm` -> the RFC file from the template; `link` of a plan drafted from it.
- [ ] `NEW FILE` -> `lib/AAPP/Review.pm` -> A plan's §7/§8, amendment check, `counts`, `gate`.
- [ ] `NEW FILE` -> `templates/rfc-template.md` -> The RFC's five sections and rules.
- [ ] `NEW FILE` -> `templates/skills/aapp-review/SKILL.md` -> The `/aapp-review <id>` skill.
- [ ] `NEW FILE` -> `lib/docs/verbs/review.md` -> The verb's contract.
- [ ] `NEW FILE` -> `t/verb/review.t` -> The verb's tests, one per contract line.
- [ ] `lib/verbs.tsv` -> The `review` row.
- [ ] `.agents/hooks/test-gate.sh` -> Runs `aapp review check <plan_id>` before `TEST_CMD` (the `done` gate until P-119).
- [ ] `templates/plan-template.md` -> Comment naming §7/§8.
- [ ] `templates/AGENTS.md` -> Skill index and CLI reference rows.
- [ ] `CHEATSHEET.md` -> The `aapp review` row.
- [ ] `MANUAL.md` -> Reviews: RFC, findings, fixes.
- [ ] `docs/reference/02-cli-commands-and-verbs.md` -> The verb.
- [ ] `docs/reference/19-skills-and-slash-commands.md` -> The skill.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/State.pm` -> Read through its accessors only; a missing accessor is an amendment request.
- [ ] `lib/AAPP/CommitEngine.pm` -> Commits through `plans_commit` only.
- [ ] `lib/cmd_status.sh` -> `fixes x/y` in status arrives with the Perl `status` (P-118).
- [ ] `lib/cmd_plan.sh` -> The bash `done` and `draft` stay as they are; the gate runs through `test-gate.sh` until the Perl `done` (P-119).

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
*(None — design is fully specified.)* A design review is guided by the skill as reviews are run today (the RFC, signed blocks, decisions from the developer's words); its automation (rounds, limits, settling) comes with the review plugin contract, after the port. §5 Open Questions stays the freeze gate.

---

## 📦 6. Change Log & Refinement History
* **2026-10-28:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-26:** Drafted from the review of P-116; design settled in chat (own verb and skill, kind from Status, §7/§8 on first use, `fix` / `decline`, amendments opened by the implementer, RFC template). A plan drafted from an RFC topic links it, and carries the decisions itself because the RFC is local. Until the Perl `done`, the gate runs as `aapp review check` in the `pre-done` test gate; P-118/P-119 take over through P-112. Design-review automation waits for the review plugin contract.
