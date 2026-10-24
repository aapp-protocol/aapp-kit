# 🗺️ Plan P-134: Perl Lifecycle Verb Tests
* **Created:** 2026-10-24 | **Last Refined:** 2026-10-24
* **Target Issue / Milestone:** none
* **Plan ID:** P-134
* **Changelog:** Changed: the read-only and plan lifecycle verbs are tested in Perl (`t/verb/*.t`) through their Perl functions on fixtures built once per file, verified via byte-offset event slicing and dual-channel assertions per test salvage RFC and matrix
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
Redraft of P-124 (aborted: `.plans/aborted/P124-perl-lifecycle-verb-test-modules.md`). P-124's test files, all passing against the bash CLI, are kept on the branch `ref/p124-cli-tests`; their checks are salvaged here. The design comes from `.plans/pickup/perl-port-test-salvage-rfc.md`.

The group exists to cut process starts (P-111 §1: ~45k processes in one verb suite, `sys > user` 2:1). These tests serve that goal: the verbs are called as Perl functions, each file builds its repositories once, and a test starts as few processes as its contract line needs. The plan runs after the verbs it tests are ported to `AAPP::Cmd::*` (P-118 read-only, P-119 lifecycle). Kit runtime code stays untouched.

**Strict Implementation References (`D7`):**
- **Test Salvage RFC:** `.plans/pickup/perl-port-test-salvage-rfc.md`
- **Tabular Verification Matrix (§3 Lifecycle & Read-Only Verb Suites, 13 files, 248+ tests):** `.plans/pickup/perl-port-test-matrix-tabular-check.md`
- **Single Prepared Repository Schema (Epochs E1, E3, E4, E5):** `.plans/pickup/perl-port-single-repo-schema.md`
- **Logging Events Spec (§4.4 & §4.5):** `.plans/pickup/perl-port-logging-events-spec.md`

---

## 2. Technical Blueprint
1. **Scope:** `status`, `matrix`, `plan-status`, `help`, `draft`, `refine`, `tdd`, `freeze`, `freeze-start`, `active`, `start` (with its worktree and group parts), `done` (with its worktree, squash and closes parts), `plan` (with `abort`); one file per verb, `t/verb/<verb>.t`, package `AAPP::T::Verb::<Name>`, one `test_*` sub per contract line, identifiers `t/verb/<verb>.t::test_<name>`.
2. **Verb calls through Perl functions with Byte-Offset Slicing:** a test calls the verb's `AAPP::Cmd::*` function with `lib_call` (a fork of the test: no new program, fresh state per call). `lib_call` records byte offsets into `.git/aapp.log` before and after invocation, parsing the emitted slice into `$res->{events}` (structured JSON objects) and `$res->{log_lines}`. Tests assert results via `event_or_die`, `no_event_or_die`, and `log_match_or_die` in `< 0.01ms`.
3. **Dual-Channel Verification:** `event_or_die` proves the verb logic, dispatch, and parameters occurred; `read_text` / `match_or_die` / `file_exists_or_die` prove the durable state effect on disk without spawning shell subprocesses.
4. **Repositories built once:** each file's `fixture` builds one repository, or very few (one per scenario, in subfolders via the Single Prepared Repository pools from `perl-port-single-repo-schema.md`), with the kit's own writers through `lib_call` or one CLI build; each test works on an isolated copy or sandbox. When several tests read the outcome of the same step, the fixture runs that step once and keeps its output; those tests only read.
5. **Few processes in checks:** facts come from files (`.git/aapp_active_plan`, `.git/config`, plan files, ledgers); the remaining git queries are batched (`git rev-parse A B C`, `git log -1 --format=…`); setup commits that do not test the hooks use `--no-verify`.
6. **Salvage:** each test of `ref/p124-cli-tests` splits into *state* (→ the fixture), *action* (→ the function call, or `run_aapp` in the CLI layer) and *checks* (→ shared `check_*` subs reading files and the result record). Exit-code checks become return-number checks (`AAPP::Constants`). A salvage inventory per verb (test → state → action → checks), kept in `.plans/pickup/`, decides the fixtures before code is written. `start` and `status` carry P-133's wording.
7. **Measured:** each file's wall time, CPU time and process count, recorded in §6 against the bash suites it replaces.
8. **P-130's checks:** the amendments ledger (P-130 §2.0–2.5, §2.7, §2.9; P-130 §2.8 writes no tests) is tested here, in `refine.t`, `done.t`, `start.t`, `freeze-start.t`, `plan-status.t` and `draft.t`, with their contracts' `## Tests` lines; the checks P-130 recorded by hand in its §6 (concurrent requests, a claim across two groups, a start refused by an approval) become tests.
9. **Needs first:** the engine changes of the RFC (R4), made in `lib/AAPP/Tests.pm` by amendment: `copy_fixture` rewrites every worktree pointer it copies; a fixture may hold several scenario projects; #192.


### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Salvage inventory
- [ ] Task 1.1: The salvage inventory per verb from `ref/p124-cli-tests` (§2.5), reviewed by the user before any test file.

### Phase 2: Read-only verbs
- [ ] Task 2.1: `status`, `matrix`, `plan-status`, `help`; one verb per commit; each file measured.

### Phase 3: Plan lifecycle verbs
- [ ] Task 3.1: `draft`, `refine`, `tdd`, `freeze`, `freeze-start`, `active`.
- [ ] Task 3.2: `start`, `done`, `plan` with their parts.
- [ ] Task 3.3: P-130's checks (§2.7) in their verb files, with their contract lines.

### Phase 4: Verification
- [ ] Task 4.1: `t/test-run strict quiet` and `./aapp test strict quiet` green; none of these verbs' `.sh` suites left; wall, CPU and process counts recorded.
- [ ] Task 4.2: Log every finding outside the Target Files as an issue (`aapp issue log`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
*Every file is named on its own line, no patterns (#194).*
- [ ] `NEW FILE` -> `t/verb/status.t` -> Tests of `lib/docs/verbs/status.md`.
- [ ] `NEW FILE` -> `t/verb/matrix.t` -> Tests of `lib/docs/verbs/matrix.md`.
- [ ] `NEW FILE` -> `t/verb/plan-status.t` -> Tests of `lib/docs/verbs/plan-status.md`.
- [ ] `NEW FILE` -> `t/verb/help.t` -> Tests of `lib/docs/verbs/help.md`.
- [ ] `NEW FILE` -> `t/verb/draft.t` -> Tests of `lib/docs/verbs/draft.md`.
- [ ] `NEW FILE` -> `t/verb/refine.t` -> Tests of `lib/docs/verbs/refine.md`.
- [ ] `NEW FILE` -> `t/verb/tdd.t` -> Tests of `lib/docs/verbs/tdd.md`.
- [ ] `NEW FILE` -> `t/verb/freeze.t` -> Tests of `lib/docs/verbs/freeze.md`.
- [ ] `NEW FILE` -> `t/verb/freeze-start.t` -> Tests of `lib/docs/verbs/freeze-start.md`.
- [ ] `NEW FILE` -> `t/verb/active.t` -> Tests of `lib/docs/verbs/active.md`.
- [ ] `NEW FILE` -> `t/verb/start.t` -> Tests of `lib/docs/verbs/start.md`, with its parts.
- [ ] `NEW FILE` -> `t/verb/done.t` -> Tests of `lib/docs/verbs/done.md`, with its parts.
- [ ] `NEW FILE` -> `t/verb/plan.t` -> Tests of `lib/docs/verbs/plan.md`, with `abort`.
- [ ] `lib/docs/verbs/status.md` -> Test identifiers point at `t/verb/status.t`.
- [ ] `lib/docs/verbs/matrix.md` -> Test identifiers point at `t/verb/matrix.t`.
- [ ] `lib/docs/verbs/plan-status.md` -> Test identifiers point at `t/verb/plan-status.t`.
- [ ] `lib/docs/verbs/help.md` -> Test identifiers point at `t/verb/help.t`.
- [ ] `lib/docs/verbs/draft.md` -> Test identifiers point at `t/verb/draft.t`.
- [ ] `lib/docs/verbs/refine.md` -> Test identifiers point at `t/verb/refine.t`.
- [ ] `lib/docs/verbs/tdd.md` -> Test identifiers point at `t/verb/tdd.t`.
- [ ] `lib/docs/verbs/freeze.md` -> Test identifiers point at `t/verb/freeze.t`.
- [ ] `lib/docs/verbs/freeze-start.md` -> Test identifiers point at `t/verb/freeze-start.t`.
- [ ] `lib/docs/verbs/active.md` -> Test identifiers point at `t/verb/active.t`.
- [ ] `lib/docs/verbs/start.md` -> Test identifiers point at `t/verb/start.t`.
- [ ] `lib/docs/verbs/done.md` -> Test identifiers point at `t/verb/done.t`.
- [ ] `lib/docs/verbs/plan.md` -> Test identifiers point at `t/verb/plan.t`.
- [ ] `DELETE` -> `tests/verbs/status.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/matrix.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/plan-status.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/help.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/draft.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/refine.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/tdd.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/freeze.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/freeze-start.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/active.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/start.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/start.worktree.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/start.group.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/done.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/done.worktree.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/done.squash.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/done.closes.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/plan.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/plan.abort.sh` -> Ported.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/Tests.pm` -> The engine changes (§2.8) come by amendment, before this plan starts.
- [ ] `tests/verb_contracts_test.sh` -> The bash contract checker stays until P-125.
- [ ] `tests/test_helpers.sh` -> Still used by the remaining bash suites.
- [ ] `lib/cmd_test.sh` -> `aapp test` switches in P-125 only.

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1:** The CLI layer per verb: how many tests go through `aapp` (for example one success and one refusal per verb), the rest through functions?
* [ ] **Question 2:** Each file's repositories: built once and copied per test (independent tests), or one live repository the tests change in turn (no copies, order-dependent)?
* [ ] **Question 3:** Start the read-only verbs (Phase 2) after P-118, or wait for P-119 and do all verbs together?
* [ ] **Question 4:** Place in the group order, once the RFC's road map is settled.

---

## 📦 6. Change Log & Refinement History
* **2026-10-24:** Drafted as the redraft of P-124 (aborted): verb tests through Perl functions on fixtures built once, design from `.plans/pickup/perl-port-test-salvage-rfc.md`, checks salvaged from `ref/p124-cli-tests`.
* **2026-10-24:** Refined technical blueprint, D7 references, and checklist with single-repo schema fixture pools, byte-offset event slicing, and dual-channel test assertion helpers per salvage RFC and matrix.

