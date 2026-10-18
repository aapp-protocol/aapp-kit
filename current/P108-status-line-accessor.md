# 🗺️ Plan P-108: Status Line Accessor
* **Created:** 2026-10-18 | **Last Refined:** 2026-10-18
* **Target Issue / Milestone:** #85
* **Plan ID:** P-108
* **Changelog:** Changed: every verb and hook reads and writes a plan's Status line through one registry-backed accessor; the retired 🚫 BLOCKED glyph is no longer recognised
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `d7c2f38` (develop)
* **Worktree:** .workspace/P108 (plan/P108-status-line-accessor)
* **Commits:** `1ef1c95` (plan/P108-status-line-accessor), `f42a27e` (plan/P108-status-line-accessor)
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
A plan's `* **Status:**` line is parsed by about 64 hand-written regexes across 11 files (#85). Only some go through the registry accessor (`plan_state_for_status_line` in `lib/plan_states.sh`, `plan_status_slug` in `lib/cmd_plan.sh`). The rest disagree:
- The pre-commit hook and the write guard still accept the retired `🚫` as BLOCKED (`templates/aapp-pre-commit` :501, :614, :617; `templates/blast-radius-guard.sh` :428, :505), and `templates/AGENTS.md` :110 still names it. The registry knows only `🟥`.
- The hooks hard-code `⚡ In Development`, `🔷 Frozen` and BLOCKED, so an adopter status from `aapp.planState.<slug>` is honoured by the verbs and not by the hooks.
- The hooks cannot reach the registry: `aapp init` ships only `aapp-lib.sh` into `.githooks/`.

Goal: one accessor that reads a plan's status, and one that writes it, both backed by the registry and available to verbs and hooks alike. Every caller moves onto them first (consolidation), and `🚫` leaves the kit with that change.

---

## 2. Technical Blueprint

### 2.1 Accessors
- `plan_status_slug <file>` -> the registry slug of the header Status line (outside fenced blocks, before the first `## `), empty when unrecognised. It replaces every reading regex.
- `plan_status_is <file> <slug>…` -> true when the plan's slug is one of them; the form for hook checks (`blocked`, `in-development`, `frozen`).
- `plan_status_render <slug>` -> `<emoji> <name>` from the registry, for messages and writers.
- `plan_set_status <file> <slug>` -> rewrites the header Status line from the registry; the one writer, replacing the `sed -i` / `awk` rewrites in `lib/cmd_plan.sh` and `lib/cmd_issue.sh`.
- All four live in `lib/plan_states.sh`, beside the registry. `aapp init` ships `plan_states.sh` into `.githooks/` beside `aapp-lib.sh`, as it ships `commit_engine.sh` and `attribution.sh` (`lib/cmd_init.sh` :475-476), and both hooks source it, refusing to run without it.

### 2.2 Callers
- Readers in `lib/` (cmd_plan, cmd_commit, cmd_issue, cmd_matrix, cmd_pause, cmd_status, planning_health, aapp-lib) use `plan_status_slug` / `plan_status_is`.
- Hooks (`templates/aapp-pre-commit`, `templates/blast-radius-guard.sh`) use `plan_status_is`; refusal messages use `plan_status_render`. The design-lock check that reads Status from `HEAD` content (pre-commit :793) gets a content-on-stdin form of the same accessor.
- Writers (block, unblock, freeze, start, done, abort) use `plan_set_status`.

### 2.3 Archived status
`✅ Done` stays outside the registry: a literal written by `done` alone. `plan_set_status` takes registry slugs only, so it cannot write it.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`. `🚫` is not recognised by any reader after this plan; nothing names it.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Consolidate
- [ ] Task 1.1: Add the four accessors to `lib/plan_states.sh`; tests for each, including an adopter status from `aapp.planState.<slug>`.
- [ ] Task 1.2: Move every reader in `lib/` onto them, with behaviour unchanged.
- [ ] Task 1.3: Move every writer onto `plan_set_status`.

### Phase 2: Hooks and clean break
- [ ] Task 2.1: `aapp init` ships `plan_states.sh` into `.githooks/`; the hooks source it and move the hooks' Status checks onto `plan_status_is`.
- [ ] Task 2.2: Remove `🚫` from the hooks, their messages and `templates/AGENTS.md`.
- [ ] Task 2.3: Test that the hooks treat an adopter-defined blocked or in-development status as the verbs do.
- [ ] Task 2.4: Test that no `**Status:**` regex remains outside the accessors (a source scan in `tests/plan_states_test.sh`).

### Phase 3: Verification & Documentation
- [ ] Task 3.1: `./aapp test quiet` passes.
- [ ] Task 3.2: `ARCHITECTURE.md` and `.agents/CODEMAP.md` name the accessors as the one owner of the Status line.
- [ ] Task 3.3: Log every finding outside the Target Files as an issue; none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/plan_states.sh` -> The registry and the four accessors.
- [ ] `lib/aapp-lib.sh` -> Readers onto the accessors.
- [ ] `lib/cmd_plan.sh` -> Readers and writers onto the accessors.
- [ ] `lib/cmd_issue.sh` -> Readers and writers onto the accessors.
- [ ] `lib/cmd_commit.sh` -> Readers onto the accessors.
- [ ] `lib/cmd_matrix.sh` -> Reader onto the accessors.
- [ ] `lib/cmd_pause.sh` -> Reader onto the accessors.
- [ ] `lib/cmd_status.sh` -> Readers onto the accessors.
- [ ] `lib/planning_health.sh` -> Reader onto the accessors.
- [ ] `lib/cmd_init.sh` -> Ships `plan_states.sh` into `.githooks/`.
- [ ] `templates/aapp-pre-commit` -> Status checks onto `plan_status_is`; `🚫` removed.
- [ ] `templates/blast-radius-guard.sh` -> Status checks onto `plan_status_is`; `🚫` removed.
- [ ] `templates/AGENTS.md` -> `🚫 BLOCKED` becomes `🟥 BLOCKED` (:110).
- [ ] `tests/plan_states_test.sh` -> Accessor tests, adopter-status hook parity, the source scan.
- [ ] `tests/aapp_lib_test.sh` -> Readers that move with the accessors.
- [ ] `tests/pre-commit_test.sh` -> The fixture copies `plan_states.sh` beside `aapp-lib.sh` into the hook directory.
- [ ] `tests/write-guard_test.sh` -> The fixture copies `plan_states.sh` beside `aapp-lib.sh` into `.githooks/`.
- [ ] `ARCHITECTURE.md` -> The one owner of the Status line.
- [ ] `.agents/CODEMAP.md` -> The accessors.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/plan-template.md` -> The Status comment already lists the registry's glyphs.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Where the registry lives.** -> **Resolved**: `plan_states.sh` stays its own module; `aapp init` ships it into `.githooks/` beside `aapp-lib.sh`, as it does `commit_engine.sh` and `attribution.sh`.
* [x] **Question 2 — `✅ Done`.** -> **Resolved**: a literal of `done`, outside the registry; `plan_set_status` takes registry slugs only.

---

## 📦 6. Change Log & Refinement History
* **2026-10-18:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-18:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-18:** Drafted from #85.
