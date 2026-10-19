# 🗺️ Plan P-114: Perl Test Harness
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Target Issue / Milestone:** #[Issue ID or Milestone] *(`aapp draft <slug> issue <num>` writes the issue ID here and links this plan in the issue's `Target Plan / Fix` cell — the issue stays open until the fix ships)*
* **Plan ID:** P-114
* **Changelog:** Added: modular Perl 5.26+ test harness (`AAPP::Tests`) with per-test fixture cloning, contract-driven discovery, parallel module workers and end-of-run failure recap (P-114)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-111
* **Commits:** none
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
Replaces the bash test scripts (`tests/*.sh`, `tests/verbs/*.sh`) with a modular Perl 5.26+ test harness (`AAPP::Tests`, modeled on `Logsniffer::Tests`), keeping the exact scenarios from `P-113` while leaving kit runtime code untouched. Every module (`AAPP::Tests::Verb::*`, `AAPP::Tests::Core::*`), verb, or individual test runs standalone via `aapp test`.

---

## 2. Technical Blueprint

### 2.1 `AAPP::Tests` Architecture (`.plans/pickup/perl-port-rfc.md` §2.6, A4, A6, A7)
1. **Zero-boilerplate test modules:** Each module (`lib/AAPP/Tests/Verb/<Verb>.pm`, `lib/AAPP/Tests/Core/<Module>.pm`) is a plain package of `sub test_<name> { my ($self) = @_; ... }` functions. `AAPP::Tests` invokes each test as `$code->($self)` inside `eval` with an `alarm` watchdog (`timeout` default `10 s`, overridable per test).
2. **Contract-driven test list & order:** `AAPP::Tests` reads `lib/docs/verbs/<verb>.md` and `lib/docs/core/<module>.md` (`## Tests` lines `` `<module>::test_<name>` -> <description> ``) for both execution order and TAP description strings, and verifies 1-to-1 correspondence against each module's `test_*` subs.
3. **Diagnostic assertions & skip protocol:**
   - Helpers on `$self` (`run_aapp`, `ok_cmd`, `fail_cmd`, `eq_or_die`, `match_or_die`, `file_exists_or_die`) `die` with `caller` `file:line`, exit code, and command output so failed tests always populate `$@` in `not ok N - <message> (Error: <$@>)`.
   - Returning a scalar ref `\"reason"` emits `ok N - <message> # SKIP <reason>`.
4. **Run-wide sandbox & per-test fixture cloning:**
   - One sandboxed kit install (`$HOME/.local/bin/aapp`, `$HOME/.local/share/aapp-kit`) is created once per run in `/tmp` and shared by non-installer modules.
   - Each module builds its initialized Git fixture template once; before each `test_*` sub runs, `$self` copies that template into a fresh per-test directory, rewrites the root prefix in the 6 worktree pointer files (`.git/worktrees/{-plans,-agents,-githooks}/gitdir` and `.{plans,agents,githooks}/.git`) in-process in Perl, and `chdir`s into it. Every test can run alone.
5. **Selection & parallel execution:**
   - `aapp test` supports selection by area/module, `verb <name...>`, numeric index, or test name / description substring, plus `strict`, `quiet`, `bail`, `list`, and `jobs <n>` (forking one worker per module). No forced baseline module on filtered runs.
6. **End-of-run failure recap:**
   - All failed `not ok` lines (with module, test name, message, and error) are repeated after the summary banner.
   - `.agents/hooks/test-gate.sh` and `examples/hooks/test-gate.sh.sample` print from the summary banner to the end of the output instead of `tail -n 20`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: `AAPP::Tests` Runner & Fixture Engine
- [ ] Task 1.1: Implement `lib/AAPP/Tests.pm` (sandbox confinement, contract-driven test discovery, per-test fixture cloner + 6-file `gitdir` rewriter, `alarm` watchdog, `die`-based assertion helpers, TAP output, parallel module worker pool, and end-of-run failure recap).
- [ ] Task 1.2: Update `lib/cmd_test.sh`, `.agents/hooks/test-gate.sh`, and `examples/hooks/test-gate.sh.sample` to invoke `lib/AAPP/Tests.pm` and print from the summary banner to the end on failure.

### Phase 2: Port Core & Verb Suites to `AAPP::Tests::*`
- [ ] Task 2.1: Port core suites from `tests/*_test.sh` to `lib/AAPP/Tests/Core/*.pm` and update `lib/docs/core/*.md` paths.
- [ ] Task 2.2: Port verb suites from `tests/verbs/*.sh` to `lib/AAPP/Tests/Verb/*.pm` and update `lib/docs/verbs/*.md` paths; remove legacy `tests/*.sh` and `tests/verbs/*.sh`.

### Phase 3: Verification
- [ ] Task 3.1: Verify single-test, single-verb, and full parallel (`./aapp test strict quiet`) execution.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `lib/AAPP/Tests.pm` -> Modular Perl test harness, sandbox/fixture cloner, assertion helpers, and parallel runner.
- [ ] `NEW FILE` -> `lib/AAPP/Tests/Core/*.pm` -> Core test modules ported from `tests/*_test.sh`.
- [ ] `NEW FILE` -> `lib/AAPP/Tests/Verb/*.pm` -> Verb test modules ported from `tests/verbs/*.sh`.
- [ ] `lib/cmd_test.sh` -> Route `aapp test` to `lib/AAPP/Tests.pm`.
- [ ] `lib/docs/verbs/*.md` -> Update test module identifiers in `## Tests`.
- [ ] `lib/docs/core/*.md` -> Update test module identifiers in `## Tests`.
- [ ] `.agents/hooks/test-gate.sh` -> Print from summary line to end (including failure recap) instead of `tail -n 20`.
- [ ] `examples/hooks/test-gate.sh.sample` -> Print from summary line to end (including failure recap) instead of `tail -n 20`.
- [ ] `DELETE` -> `tests/*.sh` -> Replaced by `lib/AAPP/Tests/Core/*.pm`.
- [ ] `DELETE` -> `tests/verbs/*.sh` -> Replaced by `lib/AAPP/Tests/Verb/*.pm`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/aapp-lib.sh` -> Kit runtime libraries remain untouched in Plan 2.
- [ ] `templates/*` -> Hook templates remain untouched in Plan 2.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified in `.plans/pickup/perl-port-rfc.md`)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-19:** Plan drafted as member 2 of group P-111 from settled RFC (`.plans/pickup/perl-port-rfc.md`).
