# 🗺️ Plan P-135: Perl Core Tests Redesign
* **Created:** 2026-10-24 | **Last Refined:** 2026-10-28
* **Target Issue / Milestone:** none
* **Plan ID:** P-135
* **Changelog:** Changed: move the setup-isolated and scenario core test suites (`t/core/*.t`) to the prepared-repository and structured event-logging design
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
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp issue log`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
Plan `P-123` ported the 25 core test suites (`t/core/*.t`, 323 contract tests in `lib/docs/core/*.md`) to Perl while `P-116`–`P-121` were still bash. Because 16 of those 25 files invoke CLI verbs and Git hooks per test (spawning ~1,200 bash/git subprocesses across `t/core`, with `t/core/integrate.t` alone taking `112.1 s` wall time and `t/core/install.t`, `pre-commit.t`, `write-guard.t`, `worktree_hooks.t`, `hooks.t` taking `25–51 s` each), the core suite became the primary wall-clock bottleneck (~380 s total CPU).

Per Decisions **`D6`** (*Core tests in their own plan*) and **`D7`** (*The matrix is the reference at implementation*) in `.plans/pickup/perl-port-test-salvage-rfc.md`, this plan runs immediately after `P-136` (once the test engine `AAPP::Tests` and mock repository builder `AAPP::TestRepo` are updated and emit/slice structured events) and before `P-134` and `P-125`. It moves the Group (b) and Group (c) core test suites to the prepared-repository and structured event-logging design while keeping all 323 `lib/docs/core/*.md` contract test names and order unchanged.

**Strict Implementation References (`D7`):**
- **Tabular Verification Matrix (§4 Core Suites):** `.plans/pickup/perl-port-test-matrix-tabular-check.md`
- **Core & Verb Logging Events Spec (§2–§5):** `.plans/pickup/perl-port-logging-events-spec.md`
- **Single Prepared Repository Schema (§5 `D6` Core Test Suite Schema):** `.plans/pickup/perl-port-single-repo-schema.md`

---

## 2. Technical Blueprint

### 2.1 Group (a): Pure Library, AST & Schema Unit Tests (9 Files, 90 Tests — Unchanged, Zero Lifecycle Events)
Per `.plans/pickup/perl-port-test-matrix-tabular-check.md` §4 Group (a) and `.plans/pickup/perl-port-logging-events-spec.md` §2 Invariant 3, the 9 pure library/AST unit test files (`t/core/plan_states.t`, `t/core/plan_resolver.t`, `t/core/aapp_lib.t`, `t/core/issue_id.t`, `t/core/issue_ledger.t`, `t/core/matrix.t`, `t/core/group_docs.t`, `t/core/output.t`, `t/core/doc_links.t`) call pure in-memory Perl functions, emit zero lifecycle events, and already run in `1.9–5.3 s` each; their `lib_call` switches to `AAPP::*` in `P-116`–`P-119`, so they are not rewritten here.

### 2.2 Group (b): Setup-Isolated Suites (3 Files, 89 Tests — Built Once Per File + Ordered Actions)
Per `.plans/pickup/perl-port-test-matrix-tabular-check.md` §4 Group (b) and `.plans/pickup/perl-port-single-repo-schema.md` §5.2:
1. **`t/core/install.t` (37 tests — `AAPP::Cmd::Init` & `AAPP::Cmd::Install`, `P-121`):**
   - Provisions one isolated workspace (`$sandbox/core-install`) and `$HOME` (`~/.local/bin/aapp`) once at file startup instead of per test; executes the 37 `init` and `install` contract checks as ordered, self-restoring actions via `lib_call('AAPP::Cmd::Init', ...)` / `lib_call('AAPP::Cmd::Install', ...)` (with a thin CLI layer for `--help`/exit codes), asserting `file_exists_or_die` and `read_text`.
2. **`t/core/pre-commit.t` (34 tests — `AAPP::Hooks::PreCommit` & `AAPP::Health`, `P-115`/`P-116`/`P-131`):**
   - Provisions one repository (`$sandbox/core-pre-commit`) with `git config aapp.perlLogFile aapp.log` and hooks wired once; each test stages its Pair 1–8 / self-protection / governance / changelog / portability case, invokes `AAPP::Hooks::PreCommit` / `AAPP::Health`, asserts `event_or_die($r, 'health', 'veto', pair => ...)` or `event_or_die($r, 'commits', 'plans', ...)`, and resets the index cleanly before the next action.
3. **`t/core/write-guard.t` (18 tests — `AAPP::Hooks::WriteGuard`, `P-116`):**
   - Provisions one repository (`$sandbox/core-write-guard`) with `aapp.perlLogFile = aapp.log`; feeds tool JSON payloads (`Write`, `Edit`, `MultiEdit`, `NotebookEdit`) directly to `AAPP::Hooks::WriteGuard` in-process, asserting `RETURN_OK` (`0`) vs `RETURN_DENY` (`-2`) and `event_or_die($r, 'guard', 'check', decision => 'allow'|'deny', reason => ...)`.

### 2.3 Group (c): Scenario & Lifecycle Suites (13 Files, 144 Tests — Shared `Pool K` + Event Logging)
Per `.plans/pickup/perl-port-test-matrix-tabular-check.md` §4 Group (c) and `.plans/pickup/perl-port-single-repo-schema.md` §5.3, these 13 suites execute against the prepared repository design (`Pool K`: `src/k01.py` .. `src/k12.py`, plans `P-50` .. `P-62`) and replace shell `run_aapp` + external `git` inspection queries with `lib_call` + `event_or_die` / `no_event_or_die` / `log_match_or_die` + `read_text`:
1. **`t/core/integrate.t` (24 tests — 112.1 s baseline):** Calls `AAPP::Cmd::Plan` / `AAPP::Plan` in-process and asserts `post-done` (`integrate => 'squash'|'ff'|'manual'`, `parent_branch`, `worktree_removed`), `hook.dispatch` (`pre-done`, `on-integrate`), and `group.docs` (`action => 'apply'`).
2. **`t/core/output_json.t` (15 tests):** Calls `AAPP::Cmd::Status` and `AAPP::Cmd::Issue` (`json`) in-process and validates JSON envelopes and `error_document` codes via `AAPP::JSON::decode`.
3. **`t/core/worktree_hooks.t` (8 tests):** Asserts `post-start` (`worktree`, `branch`), relative symlinks, and per-worktree `guard.check` (`active_plan`).
4. **`t/core/hooks.t` (22 tests):** Asserts `event_or_die($r, 'hook', 'dispatch', kind => 'hook', name => ..., status => 'ok'|'veto'|'timeout', payload_keys => [...])`.
5. **`t/core/plugin_protocol.t` (10 tests):** Asserts `event_or_die($r, 'hook', 'dispatch', kind => 'plugin', name => ..., skip_reason => 'in_step'|'sync_window'|'offline_only', response => {...})` with zero external spy files.
6. **`t/core/event_telemetry.t` (4 tests):** Verifies that observer and adopter hooks receive expected event telemetry dispatch and `post-*` payloads across adopter hooks (checking hook dispatch rather than asserting log lines alone).
7. **`t/core/adoption.t` (13 tests):** Calls `AAPP::Adoption` and `AAPP::Cmd::Status` in-process on prepared states and asserts `read_text` on `.plans/adoption.md` plus `post-status` (`open_adoption_tasks`).
8. **`t/core/template_sync.t` (14 tests):** Calls `AAPP::Cmd::Init` / `AAPP::Cmd::Install` in-process and verifies `AAPP-PROTOCOL` block synchronization and `health.veto` via `read_text` and `event_or_die`.
9. **`t/core/notes.t` (5 tests):** Asserts `event_or_die($r, 'notes', 'attach', action => 'add'|'rewrite', ref => 'refs/notes/commits')` and `post-note-stage`.
10. **`t/core/ai_attribution.t` (16 tests):** Asserts `event_or_die($r, 'commits', 'decorate', mode => 'none'|'lax'|'strict'|'notes', trailers_added => 0|1, status => ...)` and `notes.attach` (`ref => 'refs/notes/ai'`).
11. **`t/core/release.t` (6 tests) & `t/core/kit_release_hook.t` (4 tests):** Calls `AAPP::Cmd::Release` in-process and asserts `CHANGELOG.md` rollup, `.plans/release/<tag>/` bundles, and `hook.dispatch` (`on-release`, `post-release`).
12. **`t/core/sync.t` (3 tests):** Calls `AAPP::Cmd::Sync` in-process and asserts `post-sync` via `event_or_die($r, 'sync', 'sync', action => 'pull_push'|'pull'|'push', worktrees => [...])`.

### 2.4 Recorded Measurements
Every redesigned file's wall time, CPU time, and process count are measured and recorded in §6 against the `P-123` baseline (~380 s total CPU, 112.1 s wall for `integrate.t`).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Group (b) Setup-Isolated Suites (`install.t`, `pre-commit.t`, `write-guard.t`)
- [ ] Task 1.1: Refactor `t/core/install.t` (37 tests), `t/core/pre-commit.t` (34 tests), and `t/core/write-guard.t` (18 tests) to build their sandbox once per file and assert `health.veto`, `commits.plans`, and `guard.check` via `event_or_die` per `.plans/pickup/perl-port-test-matrix-tabular-check.md` §4 Group (b).

### Phase 2: Group (c) Primary Lifecycle & Hook Suites (`integrate.t`, `worktree_hooks.t`, `hooks.t`, `plugin_protocol.t`, `event_telemetry.t`)
- [ ] Task 2.1: Refactor `t/core/integrate.t` (24 tests) and `t/core/worktree_hooks.t` (8 tests) onto `Pool K` with in-process `AAPP::Cmd::Plan` calls and `post-done`, `post-start`, `hook.dispatch`, `group.docs`, and `guard.check` assertions.
- [ ] Task 2.2: Refactor `t/core/hooks.t` (22 tests), `t/core/plugin_protocol.t` (10 tests), and `t/core/event_telemetry.t` (4 tests) onto `hook.dispatch`, adopter hook invocation, and Layer 2 `post-*` event assertions.

### Phase 3: Group (c) Remaining Scenario Suites (`output_json.t`, `adoption.t`, `template_sync.t`, `notes.t`, `ai_attribution.t`, `release.t`, `kit_release_hook.t`, `sync.t`)
- [ ] Task 3.1: Refactor `t/core/output_json.t` (15 tests), `t/core/adoption.t` (13 tests), `t/core/template_sync.t` (14 tests), `t/core/notes.t` (5 tests), `t/core/ai_attribution.t` (16 tests), `t/core/release.t` (6 tests), `t/core/kit_release_hook.t` (4 tests), and `t/core/sync.t` (3 tests) per `.plans/pickup/perl-port-test-matrix-tabular-check.md` §4 Group (c).

### Phase 4: Verification & Measurements
- [ ] Task 4.1: Run `t/test-run strict quiet` and `./aapp test strict quiet`; verify all 25 `t/core/*.t` suites (323 tests) pass and record wall time, CPU time, and process counts in §6.
- [ ] Task 4.2: Log every finding outside the Target Files as an issue (`aapp issue log`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
*Every file is named on its own line, no patterns (#194).*
- [ ] `t/core/install.t` -> Group (b) setup-once redesign (37 tests).
- [ ] `t/core/pre-commit.t` -> Group (b) setup-once + `health.veto` / `commits.plans` event assertions (34 tests).
- [ ] `t/core/write-guard.t` -> Group (b) setup-once + `guard.check` event assertions (18 tests).
- [ ] `t/core/integrate.t` -> Group (c) `Pool K` + `post-done` / `hook.dispatch` / `group.docs` event assertions (24 tests).
- [ ] `t/core/output_json.t` -> Group (c) in-process JSON envelope & error code assertions (15 tests).
- [ ] `t/core/worktree_hooks.t` -> Group (c) `post-start` & `guard.check` worktree isolation assertions (8 tests).
- [ ] `t/core/hooks.t` -> Group (c) `hook.dispatch` (`kind => 'hook'`) assertions (22 tests).
- [ ] `t/core/plugin_protocol.t` -> Group (c) `hook.dispatch` (`kind => 'plugin'`) assertions (10 tests).
- [ ] `t/core/event_telemetry.t` -> Group (c) Layer 2 `post-*` telemetry assertions (4 tests).
- [ ] `t/core/adoption.t` -> Group (c) prepared-state `AAPP::Adoption` + `post-status` assertions (13 tests).
- [ ] `t/core/template_sync.t` -> Group (c) protocol block sync + `health.veto` assertions (14 tests).
- [ ] `t/core/notes.t` -> Group (c) `notes.attach` + `post-note-stage` assertions (5 tests).
- [ ] `t/core/ai_attribution.t` -> Group (c) `commits.decorate` + `notes.attach` assertions (16 tests).
- [ ] `t/core/release.t` -> Group (c) `AAPP::Runner::Release` + `hook.dispatch` (`on-release`) assertions (6 tests).
- [ ] `t/core/kit_release_hook.t` -> Group (c) `hook.dispatch` (`post-release`) assertions (4 tests).
- [ ] `t/core/sync.t` -> Group (c) `post-sync` worktree coordination assertions (3 tests).

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/docs/core/` -> All 323 core contract test names and descriptions remain locked.
- [ ] `lib/AAPP/` -> Runtime modules are untouched; test harness helpers and mock repository builder are delivered by `P-136` before this plan starts.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — settled by Decisions `D6` and `D7` in `.plans/pickup/perl-port-test-salvage-rfc.md`)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-28:** Aligned module references with `lib/AAPP/Runner/`.
* **2026-10-24:** Drafted as member `P-135` of group `P-111` per Decisions `D6` and `D7` (`.plans/pickup/perl-port-test-salvage-rfc.md`): moves the 16 Group (b) and Group (c) `t/core/*.t` suites to the prepared-repository and structured event-logging design after `P-121`.
* **2026-10-24:** Refined execution sequencing to run after `P-136`, corrected module reference to `AAPP::Cmd::Install`, and clarified `event_telemetry.t` adopter hook scope and `post-sync` event name.
