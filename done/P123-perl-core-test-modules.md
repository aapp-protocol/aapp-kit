# 🗺️ Plan P-123: Perl Core Test Modules
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Target Issue / Milestone:** none
* **Plan ID:** P-123
* **Changelog:** Changed: the core test suites run as Perl test files (`t/core/*.t`) under `AAPP::Tests`
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ✅ Done
* **Base:** `cabcde9` (feature/perl-port-of-the-kit)
* **Worktree:** .workspace/P123 (plan/P123-perl-core-test-modules)
* **Group:** P-111
* **Commits:** `67fc461` (plan/P123-perl-core-test-modules), `9605431` (plan/P123-perl-core-test-modules), `cd16e1b` (plan/P123-perl-core-test-modules), `1a2235a` (plan/P123-perl-core-test-modules), `e34d9df` (plan/P123-perl-core-test-modules), `a159a5f` (plan/P123-perl-core-test-modules), `50064e9` (plan/P123-perl-core-test-modules), `c66273f` (plan/P123-perl-core-test-modules), `4a0a66d` (plan/P123-perl-core-test-modules), `3342b2d` (plan/P123-perl-core-test-modules), `a88f609` (plan/P123-perl-core-test-modules), `aa23f8f` (plan/P123-perl-core-test-modules), `5de4f91` (plan/P123-perl-core-test-modules), `1d0fc2d` (plan/P123-perl-core-test-modules), `3b1e85c` (plan/P123-perl-core-test-modules), `9ffa8c2` (plan/P123-perl-core-test-modules), `470caf6` (plan/P123-perl-core-test-modules), `36a91f5` (plan/P123-perl-core-test-modules), `f4fd424` (plan/P123-perl-core-test-modules), `0d2c0a7` (plan/P123-perl-core-test-modules), `8f53ca7` (plan/P123-perl-core-test-modules), `ade1c95` (plan/P123-perl-core-test-modules), `8da3cde` (plan/P123-perl-core-test-modules)
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
Part 2 of 4 of the test migration split from P-114 (kept as the reference until all four parts are drafted). Ports the core suites (`tests/*_test.sh`, slimmed by P-113) to `t/core/*.t` under the harness P-126 built, keeping every scenario and test name, and deletes each bash suite once its module passes. Needs P-115 (core) and P-126 (harness) done. Kit runtime code stays untouched.

---

## 2. Technical Blueprint
1. **Scope:** every `tests/*_test.sh` except `tests/verb_contracts_test.sh` (the bash contract checker, replaced by the runner's check in P-125) and `tests/output_test.sh` (ported in P-126). `tests/test_helpers.sh` stays: the verb suites still use it.
2. **Same tests, same names:** each `test_<name>` reported by a bash suite becomes `sub test_<name>` in `t/core/<name>.t`, named after its contract (`pre-commit_test.sh` -> `t/core/pre-commit.t`, package `AAPP::T::Core::PreCommit`; `aapp_lib_test.sh` -> `t/core/aapp_lib.t`), ending with `AAPP::Tests::run_file(__FILE__) unless caller;` (P-126 §2.1.1). The contract's description stays; its identifier changes to `t/core/<name>.t::test_<name>`. Shared setup becomes the file's fixture, built once and copied per test (P-126 §2.1.5); a test that leaned on an earlier test's state builds what it needs itself.
3. **Library calls through one helper (P-126 §2.1.9):** every call into a kit library goes through `$self->lib_call(...)`. P-115 runs before this member, so the seven core-library test files (`aapp_lib`, `plan_states`, `plan_resolver`, `issue_id`, `issue_ledger`, `output` from P-126, `output_json`) are written against `AAPP::*` from the start and never rewritten. Libraries ported later (`hook_dispatcher`/`attribution` in P-116, `adoption` in P-118, `group_docs` in P-119) run in bash through the same helper until those members change its map. Tests never verify with the kit's own parsers (P-126 §2.1.10).
4. **Batches:** port, run under `t/test-run`, delete the `.sh`, update the contract, commit, one suite or a few small ones at a time (microcommits). The gate runs both runners throughout (P-126 §2.1.8).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Library & Ledger Suites
- [x] Task 1.1: Port `aapp_lib`, `plan_states`, `plan_resolver`, `issue_id`, `issue_ledger`, `output_json`, `group_docs`, `adoption`, `doc_links`.

### Phase 2: Hook & Engine Suites
- [x] Task 2.1: Port `pre-commit`, `write-guard`, `hooks`, `worktree_hooks`, `plugin_protocol`, `event_telemetry`, `ai_attribution`, `notes`.
- [x] Task 2.2: Port `integrate`, `install`, `sync`, `release`, `kit_release_hook`, `matrix`, `template_sync`.

### Phase 3: Verification
- [x] Task 3.1: `t/test-run strict quiet` and `./aapp test strict quiet` both green; no `tests/*_test.sh` left but `verb_contracts_test.sh`; record each runner's wall and CPU time.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `t/core/*.t` -> Core test files ported from `tests/*_test.sh`.
- [ ] `DELETE` -> `tests/*_test.sh` -> Each suite once its test file passes (not `verb_contracts_test.sh`).
- [ ] `lib/docs/core/*.md` -> Test identifiers point at `t/core/*.t`.
- [x] `lib/docs/verbs/draft.md` -> R30 (by P-123)
- [x] `lib/docs/verbs/draft.md` -> R31 (by P-123)
- [x] `lib/docs/verbs/refine.md` -> R35 (by P-123)
- [x] `lib/docs/verbs/matrix.md` -> R36 (by P-123)
- [x] `lib/docs/verbs/done.md` -> R37 (by P-123)

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `tests/verb_contracts_test.sh` -> The bash contract checker stays until P-125.
- [ ] `tests/test_helpers.sh` -> Still used by the verb suites.
- [ ] `tests/verbs/*.sh` -> Ported in P-124 and P-125.
- [ ] `lib/cmd_test.sh` -> `aapp test` switches in P-125 only.

### Amendments
- R30 2026-10-24 · `lib/docs/verbs/draft.md` · lib/docs/verbs/draft.md names tests/aapp_lib_test.sh::test_subject_max_len, which P-123 deleted: the line points at t/core/aapp_lib.t and says a value that is not a number is refused (R27) (by P-123, landed `c282704`)
- R31 2026-10-24 · `lib/docs/verbs/draft.md` · lib/docs/verbs/draft.md drops the test_subject_max_len line R30 repointed: a verb contract names t/verb/ files only (the engine refuses t/core/ there), and lib/docs/core/aapp_lib.md already names t/core/aapp_lib.t::test_subject_max_len (by P-123, landed `5fd4f62`)
- R35 2026-10-24 · `lib/docs/verbs/refine.md` · lib/docs/verbs/refine.md drops its three tests/hooks_test.sh lines (pre-refine veto, on-refine failure, post-refine payload): P-123 deleted that suite, a verb contract names t/verb/ files only, and lib/docs/core/hooks.md names the same three tests in t/core/hooks.t (by P-123, landed `5e2fe63`)
- R36 2026-10-24 · `lib/docs/verbs/matrix.md` · lib/docs/verbs/matrix.md line 'Broader coverage ... tests/matrix_test.sh' points at t/core/matrix.t: P-123 ported and deleted that suite (by P-123, landed `1984a0a`)
- R37 2026-10-24 · `lib/docs/verbs/done.md` · lib/docs/verbs/done.md drops its nine tests/integrate_test.sh lines (integration on done): P-123 ported and deleted that suite, a verb contract names t/verb/ files only, and lib/docs/core/integrate.md names the same tests in t/core/integrate.t (by P-123, landed `ec6839d`)

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-24:** Plan implementation completed and archived to done/.
* **2026-10-23:** Verified: `t/test-run strict quiet` 25/25 files (322 passed, 1 skipped) in 111 s wall, 339 s CPU; `./aapp test strict quiet` 38/38 suites (538 passed) in 120 s wall, 1120 s CPU (user + sys); `verb_contracts_test.sh` the one core bash suite left.
* **2026-10-23:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-19:** Drafted as part 2 of 4 split from P-114 (core suites).
