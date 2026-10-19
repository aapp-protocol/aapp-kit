# 🗺️ Plan P-123: Perl Core Test Modules
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Target Issue / Milestone:** #[Issue ID or Milestone] *(`aapp draft <slug> issue <num>` writes the issue ID here and links this plan in the issue's `Target Plan / Fix` cell — the issue stays open until the fix ships)*
* **Plan ID:** P-123
* **Changelog:** Changed: the core test suites run as Perl modules (`tests/AAPP/Core/*.pm`) under `AAPP::Tests` (P-123)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-111
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
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp refine issues`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
Part 2 of 4 of the test migration split from P-114 (kept as the reference until all four parts are drafted). Ports the core suites (`tests/*_test.sh`, slimmed by P-113) to `tests/AAPP/Core/*.pm` under the harness P-126 built, keeping every scenario and test name, and deletes each bash suite once its module passes. Needs P-126 done. Kit runtime code stays untouched.

---

## 2. Technical Blueprint
1. **Scope:** every `tests/*_test.sh` except `tests/verb_contracts_test.sh` (the bash contract checker, replaced by the runner's check in P-125) and `tests/output_test.sh` (ported in P-126). `tests/test_helpers.sh` stays: the verb suites still use it.
2. **Same tests, same names:** each `test_<name>` reported by a bash suite becomes `sub test_<name>` in `tests/AAPP/Core/<Module>.pm` (module named after the suite: `pre-commit_test.sh` -> `PreCommit.pm`, `aapp_lib_test.sh` -> `AappLib.pm`). The contract's description stays; its identifier changes to `tests/AAPP/Core/<Module>.pm::test_<name>`. Shared setup becomes the module's fixture, built once and copied per test (P-126 §2.1.5); a test that leaned on an earlier test's state builds what it needs itself.
3. **Core wrappers:** suites that source `lib/*.sh` functions keep calling the bash library through a shell (`bash -c '. lib/x.sh; fn ...'`) until P-115/P-116/P-118/P-119 switch them to `AAPP::<Module>` (P-111 §2, tests vs code boundary).
4. **Batches:** port, run under `tests/test-run`, delete the `.sh`, update the contract, commit, one suite or a few small ones at a time (microcommits). The gate runs both runners throughout (P-126 §2.1.8).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Library & Ledger Suites
- [ ] Task 1.1: Port `aapp_lib`, `plan_states`, `plan_resolver`, `issue_id`, `issue_ledger`, `output_json`, `group_docs`, `adoption`, `doc_links`.

### Phase 2: Hook & Engine Suites
- [ ] Task 2.1: Port `pre-commit`, `write-guard`, `hooks`, `worktree_hooks`, `plugin_protocol`, `event_telemetry`, `ai_attribution`, `notes`.
- [ ] Task 2.2: Port `integrate`, `install`, `sync`, `release`, `kit_release_hook`, `matrix`, `template_sync`.

### Phase 3: Verification
- [ ] Task 3.1: `tests/test-run strict quiet` and `./aapp test strict quiet` both green; no `tests/*_test.sh` left but `verb_contracts_test.sh`; record each runner's wall and CPU time.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `tests/AAPP/Core/*.pm` -> Core test modules ported from `tests/*_test.sh`.
- [ ] `DELETE` -> `tests/*_test.sh` -> Each suite once its module passes (not `verb_contracts_test.sh`).
- [ ] `lib/docs/core/*.md` -> Test identifiers point at `tests/AAPP/Core/*.pm`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `tests/verb_contracts_test.sh` -> The bash contract checker stays until P-125.
- [ ] `tests/test_helpers.sh` -> Still used by the verb suites.
- [ ] `tests/verbs/*.sh` -> Ported in P-124 and P-125.
- [ ] `lib/cmd_test.sh` -> `aapp test` switches in P-125 only.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-19:** Drafted as part 2 of 4 split from P-114 (core suites).
