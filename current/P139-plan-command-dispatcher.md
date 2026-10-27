# 🗺️ Plan P-139: Noun First Plan Commands
* **Created:** 2026-10-27 | **Last Refined:** 2026-10-27
* **Target Issue / Milestone:** none
* **Plan ID:** P-139
* **Changelog:** Changed: plan lifecycle commands move under `aapp plan` (`aapp plan draft`, `aapp plan refine`, `aapp plan freeze`, …); the old top-level verbs are removed
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
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
The CLI becomes noun-first, as `aapp issue …` already is: every command that acts on a plan moves under `aapp plan`, so a person or agent finds the plan commands in one place and each subcommand says exactly what it does. The logic lives in one module per subcommand under `lib/AAPP/Plan/`, with `AAPP::Cmd::Plan` parsing tokens only. Starts after the Perl port (group P-111) is done. Clean break: the old top-level verbs leave the kit (no aliases).

---

## 2. Technical Blueprint

### 2.1 Verb conversion
| Today | After | Module |
|---|---|---|
| `aapp draft [slug] [issue <num> \| group [<id>]]` | `aapp plan draft …` | `AAPP::Plan::Draft` |
| `aapp refine <id> "<msg>"` and its plan tokens (`blocked`, `unblocked`, `slug`, `closes`, `group`) | `aapp plan refine <id> …` | `AAPP::Plan::Refine` |
| `aapp refine <amend-id> request \| approve \| refuse \| decision …` | `aapp plan amend request \| approve \| refuse \| decision …` | `AAPP::Plan::Amend` |
| `aapp tdd <id>` | `aapp plan tdd <id>` | `AAPP::Plan::Tdd` |
| `aapp freeze <id>` | `aapp plan freeze <id>` | `AAPP::Plan::Freeze` |
| `aapp start <id>` | `aapp plan start <id>` | `AAPP::Plan::Start` |
| `aapp freeze-start <id>` | `aapp plan freeze-start <id>` | `AAPP::Plan::Freeze` + `AAPP::Plan::Start` |
| `aapp done <id>` | `aapp plan done <id>` | `AAPP::Plan::Done` |
| `aapp active [<id> \| clear]` | `aapp plan active [<id> \| clear]` | `AAPP::Plan::Active` |
| `aapp plan-status [<id>]` | `aapp plan status [<id>]` | `AAPP::Plan::Status` |
| `aapp matrix [check]` | `aapp plan matrix [check]` | `AAPP::Plan::Matrix` |
| `aapp plan abort <id> …` | unchanged | `AAPP::Plan::Abort` |
| `aapp plan conflict-check \| conflict-free …` | unchanged | `AAPP::Plan::Conflict` |
| `aapp plan [query]` | `aapp plan` (bare: the switchboard) | `AAPP::Cmd::Plan` |

Unchanged: `status` (all four pillars), `commit` (code), `review` (P-138), `issue`, `note`, `ai`, `offline`, `companion`, `test`, the setup, sync and hook verbs.

### 2.2 Reserved words
After `aapp plan` the subcommand words above are reserved; a plan whose slug equals one is named by its id (`P-<n>`).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Foundation & Setup
- [ ] Task 1.1: ...
- [ ] Task 1.2: ...

### Phase 2: Core Implementation
- [ ] Task 2.1: ...
- [ ] Task 2.2: ...

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify edge cases.
- [ ] Task 3.2: Update user-facing documentation per `.agents/PROJECT.MD` (`MANUAL.md`, `README.md`, or `docs/`) if CLI verbs, configuration, or workflows were introduced or changed.
- [ ] Task 3.3: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` if new modules, commands, or interface contracts were introduced.
- [ ] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 3.5: Log every finding outside the Target Files as an issue (`aapp issue log`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `src/path/to/file.ext` -> Description of specific modification.
- [ ] `NEW FILE` -> `src/path/to/new_file.ext` -> Purpose of the new component.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/core/critical_module.ext` -> Core module is frozen; do not refactor.
- [ ] `src/auth/` -> Authentication flow must remain completely isolated.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [ ] **Question 1:** `aapp refine pickup "<msg>"` and `aapp refine issues "<msg>" …` do not act on a plan: where do they go (`aapp pickup …`, `aapp issue refine …`)?
* [ ] **Question 2:** `aapp plan [query]` today takes a positional query; does the bare switchboard keep a query, and how is it told apart from a subcommand?
* [ ] **Question 3:** Blast radius: every doc, skill, template, contract, test and the rules name the old verbs; one plan or a group?

---

## 📦 6. Change Log & Refinement History
* **2026-10-27:** File renamed from P139-noun-first-plan-commands.md to P139-plan-command-dispatcher.md.
*Tracks how the plan evolved across sessions.*
* **2026-10-27:** Drafted with the verb conversion; details come in refinement.
