# 🗺️ Plan P-126: Perl Test Runner
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Target Issue / Milestone:** none
* **Plan ID:** P-126
* **Changelog:** Added: Perl 5.26+ test engine (`AAPP::Tests`) for the `t/` test files, with per-test fixture copies, a process-group watchdog, parallel workers and an end-of-run failure recap, run through `t/test-run` or `prove -l t/`
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ✅ Done
* **Base:** `a40820d` (feature/perl-port-of-the-kit)
* **Worktree:** .workspace/P126 (plan/P126-perl-test-runner)
* **Group:** P-111
* **Commits:** `bc75af1` (plan/P126-perl-test-runner), `99c1387` (plan/P126-perl-test-runner), `7087b33` (plan/P126-perl-test-runner), `cabcde9` (plan/P126-perl-test-runner)
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
Part 1 of 4 of the test migration split from P-114 (kept as the reference until all four parts are drafted). Builds the modular Perl 5.26+ test engine (`lib/AAPP/Tests.pm`, a core module modeled on `Logsniffer::Tests`) and its temporary entry point `t/test-run`, and proves both by porting one core suite (`output`) to `t/core/output.t`. Needs P-127 (foundation) and P-115 (core) done: the engine runs on `AAPP::Runner`, `AAPP::Logger`, `AAPP::Config` and `AAPP::Constants`, and reads JSON with `AAPP::JSON`. The other suites move in P-123 (core), P-124 (lifecycle verbs) and P-125 (remaining verbs, then `aapp test` switches to the engine). The test files live in `t/`, as in any Perl project (`t/core/<name>.t`, `t/verb/<verb>.t`, named after their contracts); they are run from the kit's checkout, and `aapp install` ships no tests (P-121).

---

## 2. Technical Blueprint

### 2.1 `AAPP::Tests` (`.plans/pickup/perl-port-rfc.md` §2.6, A4, A6, A7, §5.1.3; P-114 §2.1)
1. **Zero-boilerplate test files:** each file (`t/core/<name>.t`, `t/verb/<verb>.t`, named after its contract `lib/docs/core/<name>.md` or `lib/docs/verbs/<verb>.md`) is a plain package of `sub test_<name> { my ($self) = @_; ... }` functions, `AAPP::T::<Area>::<Name>` (the file name's parts capitalised: `pre-commit.t` -> `PreCommit`). It ends with `AAPP::Tests::run_file(__FILE__) unless caller;`, so `prove -l t/` (or `perl -Ilib t/core/output.t`) runs one file alone with a TAP plan, while the engine loads it without running it.
2. **60 s watchdog & process-group termination, on P-127's `AAPP::Runner`:** `t/test-run` calls `AAPP::Runner::init_signals()` (HUP/TERM/INT, `__WARN__`, `__DIE__`) and reports through `AAPP::Logger::print_msg`; outcomes are `AAPP::Constants` return numbers, exit by `AAPP::Runner::exit_code()`. Each test runs in its own process group (`POSIX::setpgid(0, 0)`) under a `60 s` default watchdog, overridable per test (a test averages ~3.4 s alone, ~3× that in a full parallel run). Each group is registered in `@AAPP::Runner::cleanups`, so an interrupt stops it through the Runner's `cleanup`: TERM, up to `TEST_STOP_GRACE_SECONDS` for a worker to stop its own test's group, then KILL; a timeout (`SIGALRM`) kills the test's group (TERM, KILL) and records the test as `not ok`. The engine's defaults are in `AAPP::Constants` (`TEST_*`). No `git` or `aapp` child survives (as `_test_stop` in `lib/cmd_test.sh` does today).
3. **Contract-driven list & order:** the runner reads `lib/docs/verbs/<verb>.md` and `lib/docs/core/<module>.md` (`## Tests` lines `` `t/{core,verb}/<name>.t::test_<name>` -> <description> ``) for execution order and TAP descriptions, and checks them against each file's `test_*` subs both ways.
4. **Diagnostic assertions & skips:** helpers on `$self` (`run_aapp`, `ok_cmd`, `fail_cmd`, `eq_or_die`, `match_or_die`, `file_exists_or_die`) `die` with `caller` `file:line`, exit code and command output, so a failure prints `not ok N - <message> (Error: <$@>)`. Returning `\"reason"` prints `ok N - <message> # SKIP <reason>`.
5. **Run-wide sandbox & per-test fixture copies:** one sandboxed kit install (`$HOME/.local/bin/aapp`, `$HOME/.local/share/aapp-kit` with `lib`, `templates` and `examples`, as installed: no tests) per run in the system's temporary directory, shared by non-installer files (a file asks for its own with `own_sandbox`). Each file builds its initialized Git fixture once; before each `test_*` sub, `$self` copies it into a fresh directory, rewrites the root prefix in the 6 worktree pointer files (`.git/worktrees/{-plans,-agents,-githooks}/gitdir` and `.{plans,agents,githooks}/.git`) in Perl, and `chdir`s into it. Every test can run alone.
6. **`t/test-run`:** an executable, extensionless Perl entry point loading `AAPP::Tests` (`prove` runs `*.t` only). Selection by area/file, `verb [<name>]`, numeric index, or test name / description substring, with `strict`, `quiet`, `bail`, `list`, `help` and `jobs <n>` (one worker per file in its own process group). No forced baseline file on filtered runs. Temporary name: P-125 routes `aapp test` to the engine and removes it.
7. **End-of-run failure recap:** every `not ok` line (file, test, message, error) is repeated after the summary banner. `.agents/hooks/test-gate.sh` and `examples/hooks/test-gate.sh.sample` print from the last summary line to the end instead of `tail -n 20`; output with no summary line (the command stopped before one) still shows its last 20 lines.
8. **Bridge until P-125 (configuration, not kit code):** `aapp test` keeps running the bash suites. The gate's `TEST_CMD` in `.agents/hooks/test-gate.sh` runs both, the engine only where the branch has it (`.agents/` serves every branch): `./aapp test strict quiet && { [ ! -x t/test-run ] || t/test-run strict quiet; }`. Because `.agents/skills/aapp-hooks/registry.tsv` is self-protected, the developer re-registers the gate's SHA-256 before `aapp done`. `tests/verb_contracts_test.sh` skips contract lines naming a `t/` file; `t/test-run` checks those both ways.

9. **One helper for library calls:** a test that exercises a kit library calls it through `$self->lib_call($library, $function, @args)` only. A library already ported calls `AAPP::<Module>::<function>` in a fork of the test process (fresh caches, as in a new `aapp` run; the result comes back through `Storable`); one still in bash runs `bash -c '. lib/<library>.sh; <function> "$@"'`. When a later member (P-116, P-118, P-119) ports a library, only this helper's map changes; the assertions do not.
10. **Tests never verify with the kit's own parsers:** assertions read the kit's output, files and git state as literal text (small regexes in the test), never through `AAPP::State`, `AAPP::Text` or other kit parsers, so a parser bug cannot hide itself. `AAPP::JSON` is the exception: it reads JSON documents the test then checks field by field.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Harness & Runner
- [x] Task 1.1: Implement `tests/AAPP/Tests.pm` per §2.1.1–5, 7, 9 and 10.
- [x] Task 1.2: Add `tests/test-run` per §2.1.6.

### Phase 2: Proof Suite & Bridge
- [x] Task 2.1: Port `tests/output_test.sh` to `tests/AAPP/Core/Output.pm`, point `lib/docs/core/output.md` at it, delete the `.sh` suite.
- [x] Task 2.2: `tests/verb_contracts_test.sh` skips contract lines naming `tests/AAPP/*.pm`.
- [x] Task 2.3: Set the gate's `TEST_CMD` and summary-to-end print in `.agents/hooks/test-gate.sh`, and the print in `examples/hooks/test-gate.sh.sample`; ask the user to re-register the gate with `aapp hook-hash`.

### Phase 3: Verification
- [x] Task 3.2: Re-scoped (2026-10-22): the engine to `lib/AAPP/Tests.pm`, the entry point to `t/test-run`, the proof suite to `t/core/output.t` (with `run_file` for `prove`), contract lines and the gate to `t/`; the sandbox kit without tests; both runners green again.
- [x] Task 3.1: Verify a single test, a single module and a full parallel run of `tests/test-run`, a failing test's recap, a watchdog timeout, and `./aapp test strict quiet` still green.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `lib/AAPP/Tests.pm` -> Test engine: sandbox, fixture copies, watchdog, assertion helpers, parallel runner, recap, `run_file`.
- [ ] `NEW FILE` -> `t/test-run` -> Temporary executable entry point loading `AAPP::Tests`.
- [ ] `NEW FILE` -> `t/core/output.t` -> Proof suite ported from `tests/output_test.sh`.
- [ ] `DELETE` -> `tests/AAPP/Tests.pm` -> Moved to `lib/AAPP/Tests.pm`.
- [ ] `DELETE` -> `tests/test-run` -> Moved to `t/test-run`.
- [ ] `DELETE` -> `tests/AAPP/Core/Output.pm` -> Moved to `t/core/output.t`.
- [ ] `DELETE` -> `tests/output_test.sh` -> Replaced by `t/core/output.t`.
- [ ] `lib/docs/core/output.md` -> Test identifiers point at `t/core/output.t`.
- [ ] `tests/verb_contracts_test.sh` -> Skip contract lines naming `t/` files.
- [ ] `.agents/hooks/test-gate.sh` -> `TEST_CMD` runs both suites; print from the summary line to the end.
- [ ] `examples/hooks/test-gate.sh.sample` -> Print from the summary line to the end.
- [x] `lib/AAPP/Constants.pm` -> R14 (by P-126)

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_test.sh` -> `aapp test` switches to the harness in P-125 only.
- [ ] `lib/aapp-lib.sh` -> Kit runtime stays untouched.
- [ ] `templates/*` -> Hook templates stay untouched.

### Amendments
- R14 2026-10-23 · `lib/AAPP/Constants.pm` · P-126: test harness defaults (watchdog 60 s, jobs step 4, sandbox prefix, fallback git identity, default branch) go into AAPP::Constants (by P-126, landed `4a47a16`)

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-23:** Plan implementation completed and archived to done/.
* **2026-10-22:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-22:** Re-scoped at the developer's request: the engine is a core module (`lib/AAPP/Tests.pm`), the tests live in `t/` as `.t` files named after their contracts (`t/core/output.t`), the entry point is `t/test-run`; `aapp install` ships no tests (note in P-121). §2.1.2, 5, 8 and 9 now also say how the first implementation settled the interrupt, the defaults, the gate and `lib_call`.
* **2026-10-22:** Implemented. Harness defaults in `AAPP::Constants` by R14 (P-112), made here as amendment commit `4a47a16` (P-129). `lib_call` runs a Perl function in a fork of the test process, so each call starts with fresh caches as a new `aapp` run does. An interrupt stops worker groups with TERM, up to `TEST_STOP_GRACE_SECONDS` for each worker to stop its test's group, then KILL (TERM and KILL together left a test orphaned). The gate runs `tests/test-run` only where it exists (`.agents/` serves every branch) and prints the last 20 lines when the output has no summary line. Verified: one test, one module, a parallel run, a failure's recap, a watchdog timeout that also kills a background child, an interrupt that leaves no process or sandbox, contract mismatches both ways; bash suites 62/62 (856), `tests/test-run` 5/5.
* **2026-10-22:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-19:** Drafted as part 1 of 4 split from P-114 (harness, `tests/test-run`, proof suite, gate bridge).
