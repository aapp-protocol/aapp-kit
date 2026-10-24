# 🗺️ Plan P-124: Perl Lifecycle Verb Test Modules
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Target Issue / Milestone:** none
* **Plan ID:** P-124
* **Changelog:** Changed: the read-only and plan lifecycle verb suites run as Perl test files (`t/verb/*.t`) under `AAPP::Tests`
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `e83d584` (feature/perl-port-of-the-kit)
* **Worktree:** .workspace/P124 (plan/P124-perl-lifecycle-verb-test-modules)
* **Group:** P-111
* **Commits:** `7a1b6c1` (plan/P124-perl-lifecycle-verb-test-modules), `0116f30` (plan/P124-perl-lifecycle-verb-test-modules)
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
Part 3 of 4 of the test migration split from P-114 (kept as the reference until all four parts are drafted). Ports the read-only and plan lifecycle verb suites (`tests/verbs/<verb>.sh` and their parts) to `t/verb/*.t` under the harness P-126 built, keeping every scenario and test name, and deletes each bash suite once its module passes. Needs P-126 done; independent of P-123. Kit runtime code stays untouched.

---

## 2. Technical Blueprint
1. **Scope:** `status`, `matrix`, `plan-status`, `help`, `draft`, `refine`, `tdd`, `freeze`, `start` (with `start.group`, `start.worktree`), `freeze-start`, `done` (with `done.closes`, `done.squash`, `done.worktree`), `active`, `plan` (with `plan.abort`).
2. **One test file per verb:** a verb and its parts become `t/verb/<verb>.t`, named after its contract (`freeze-start` -> `t/verb/freeze-start.t`, package `AAPP::T::Verb::FreezeStart`; P-126 §2.1.1); every `test_<name>` keeps its name and its contract description; contract identifiers change to `t/verb/<verb>.t::test_<name>`. The `Run:` line stays `aapp test verb <verb>` (true again after P-125).
3. **Independent tests:** a verb suite's shared repository becomes the file's fixture, built once and copied per test (P-126 §2.1.5). A test that leaned on an earlier test's state builds what it needs itself; P-113 left the verb suites in file order (P-113 §6).
4. **Batches:** one verb (with its parts) per commit (microcommits); the gate runs both runners throughout (P-126 §2.1.8).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Read-Only Verbs
- [ ] Task 1.1: Port `status`, `matrix`, `plan-status`, `help`.

### Phase 2: Plan Lifecycle Verbs
- [ ] Task 2.1: Port `draft`, `refine`, `tdd`, `freeze`, `freeze-start`, `active`.
- [ ] Task 2.2: Port `start` (and parts), `done` (and parts), `plan` (and parts).

### Phase 3: Verification
- [ ] Task 3.1: `t/test-run strict quiet` and `./aapp test strict quiet` both green; none of these verbs' `.sh` suites left; record each runner's wall and CPU time.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `t/verb/*.t` -> Verb test files for the verbs in §2.1.
- [ ] `DELETE` -> `tests/verbs/status.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/matrix.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/plan-status.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/help.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/draft.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/refine.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/tdd.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/freeze.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/freeze-start.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/start*.sh` -> Ported with its parts.
- [ ] `DELETE` -> `tests/verbs/done*.sh` -> Ported with its parts.
- [ ] `DELETE` -> `tests/verbs/active.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/plan.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/plan.abort.sh` -> Ported.
- [ ] `lib/docs/verbs/*.md` -> Test identifiers of these verbs point at `t/verb/*.t`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `tests/verb_contracts_test.sh` -> The bash contract checker stays until P-125.
- [ ] `tests/test_helpers.sh` -> Still used by the remaining verb suites.
- [ ] `lib/cmd_test.sh` -> `aapp test` switches in P-125 only.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-24:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-19:** Drafted as part 3 of 4 split from P-114 (read-only and lifecycle verb suites).
