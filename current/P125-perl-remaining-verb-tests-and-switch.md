# 🗺️ Plan P-125: Perl Remaining Verb Tests And Switch
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-28
* **Target Issue / Milestone:** none
* **Plan ID:** P-125
* **Changelog:** Changed: `aapp test` runs the Perl test engine (`AAPP::Tests`) over `t/` with file, verb, index and name selection; remaining verb suites verified via event telemetry and byte-offset slicing; bash test suites and `tests/` removed
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
Part 4 of the test migration split from P-114. Ports the remaining verb suites to `t/verb/*.t`, then switches `aapp test` to the test engine (`lib/AAPP/Tests.pm`) and removes everything temporary: the bash suites, `tests/test_helpers.sh`, the bash contract checker, `t/test-run`, and the two-runner gate command; the `tests/` folder is gone and every test lives in `t/`.

The group exists to cut process starts (P-111 §1: ~45k processes in one verb suite, `sys > user` 2:1); these tests serve that goal as P-134's do. The plan runs after the verbs it tests are ported (P-117 issue and offline, P-120 commit, note and ai, P-121 companion and test) and after P-134, whose design it follows (`.plans/pickup/perl-port-test-salvage-rfc.md`, D2–D3). Kit runtime code stays untouched except the `test` verb (`lib/AAPP/Runner/Test.pm`).

**Strict Implementation References (`D7`):**
- **Test Salvage RFC:** `.plans/pickup/perl-port-test-salvage-rfc.md`
- **Tabular Verification Matrix (§3 Remaining Verb Suites, 7 files, 278 tests):** `.plans/pickup/perl-port-test-matrix-tabular-check.md`
- **Single Prepared Repository Schema (Pool C, Pool I, and Epoch E7):** `.plans/pickup/perl-port-single-repo-schema.md`
- **Logging Events Spec (§4.6, §4.7 & §3 Layer 1):** `.plans/pickup/perl-port-logging-events-spec.md`

---

## 2. Technical Blueprint
1. **Remaining verbs:** `issue` (with its parts: `abort`, `branchplugin`, `branch`, `fixes`, `keyid`, `limits`, `notefilter`, `onecommit`, `provider`, `queue`, `tracker`), `offline`, `commit`, `note`, `ai`, `companion`, `test`; one file per verb, `t/verb/<verb>.t`, one `test_*` sub per contract line.
2. **The design of P-134 §2.2–2.6 with Byte-Offset Slicing:** verbs called as Perl functions through `lib_call` with a thin CLI layer. `lib_call` captures `.git/aapp.log` byte slices into `$res->{events}` and `$res->{log_lines}`, asserted via `event_or_die`, `no_event_or_die`, and `log_match_or_die` in `< 0.01ms`; suites execute against the single prepared repository (`$sandbox/repo`) provisioned by `P-136` per `perl-port-single-repo-schema.md` (`Pool C` for `commit`, `note`, `ai`; `Pool I` for `issue` and `offline`; Epoch `E7` for `companion`, `test`, and contract checker), with zero per-file repository builds and zero per-test copies; facts read from files (`read_text`, `match_or_die`, `file_exists_or_die`), git queries batched, setup commits `--no-verify`; checks carried over from the bash suites as shared `check_*` subs; each file's wall, CPU and process count recorded.
3. **P-130's `commit` checks:** `commit … amendment <n>` over the claims reader (P-130 §2.3; P-130 §2.8 writes no tests) is tested in `t/verb/commit.t`, with the contract's `## Tests` lines.
4. **Contract checker in Perl:** the checks of `tests/verb_contracts_test.sh` move to `t/core/verb_contracts.t` (registry <-> contracts, contract shape, core contracts per test file, every test named both ways, daily verbs in the agent reference, rules-file and skill-index checks, `aapp help` of an unknown verb); its contract `lib/docs/core/verb_contracts.md` follows. Its reads come from files in-process, with no process per check.
5. **The switch (clean break):** `lib/AAPP/Runner/Test.pm` (ported by P-121, running the bash suites until here) runs `AAPP::Tests` over `t/` with the runner's selection forms (P-126 §2.1.6) and `strict`, `quiet`, `bail`, `list`, `jobs <n>`; `t/test-run` is deleted and nothing names it. `lib/docs/verbs/test.md` (Ingress, Effects, Tests) and `CHEATSHEET.md` document the forms. The `test` verb file tests the new runner.
6. **Gate back to one command:** `.agents/hooks/test-gate.sh` `TEST_CMD` returns to `./aapp test strict quiet`; the developer re-registers it with `./aapp hook-hash .agents/hooks/test-gate.sh` before `aapp done`.


### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Salvage inventory
- [ ] Task 1.1: The inventory per verb of the remaining bash suites (test → state → action → checks, as P-134 §2.5), kept in `.plans/pickup/`, reviewed by the user before any test file.

### Phase 2: Remaining Verb Files
- [ ] Task 2.1: `issue` and its parts; each file measured.
- [ ] Task 2.2: `offline`, `commit` (with P-130's checks, §2.3), `note`, `ai`, `companion`; each file measured.

### Phase 3: The Switch
- [ ] Task 3.1: `tests/verb_contracts_test.sh` to `t/core/verb_contracts.t`.
- [ ] Task 3.2: `aapp test` runs the test engine in `lib/AAPP/Cmd/Test.pm`; the `test` verb file against it; `lib/docs/verbs/test.md` and `CHEATSHEET.md`.
- [ ] Task 3.3: Delete `t/test-run`, `tests/test_helpers.sh`, `tests/verb_contracts_test.sh` and the remaining bash verb suites; reset the gate's `TEST_CMD` and ask the user to re-register it.

### Phase 4: Verification
- [ ] Task 4.1: `./aapp test strict quiet` green with every test file; single-test, single-verb and parallel runs; wall, CPU and process counts recorded against the P-113 baseline (856 tests, 163 s wall, 1,477 s CPU).
- [ ] Task 4.2: Log every finding outside the Target Files as an issue (`aapp issue log`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
*Every file is named on its own line, no patterns (#194).*
- [ ] `NEW FILE` -> `t/verb/issue.t` -> Tests of `lib/docs/verbs/issue.md`, with its parts.
- [ ] `NEW FILE` -> `t/verb/offline.t` -> Tests of `lib/docs/verbs/offline.md`.
- [ ] `NEW FILE` -> `t/verb/commit.t` -> Tests of `lib/docs/verbs/commit.md`.
- [ ] `NEW FILE` -> `t/verb/note.t` -> Tests of `lib/docs/verbs/note.md`.
- [ ] `NEW FILE` -> `t/verb/ai.t` -> Tests of `lib/docs/verbs/ai.md`.
- [ ] `NEW FILE` -> `t/verb/companion.t` -> Tests of `lib/docs/verbs/companion.md`.
- [ ] `NEW FILE` -> `t/verb/test.t` -> Tests of `lib/docs/verbs/test.md`.
- [ ] `NEW FILE` -> `t/core/verb_contracts.t` -> The contract checker in Perl.
- [ ] `lib/AAPP/Runner/Test.pm` -> `aapp test` runs the test engine over `t/`.
- [ ] `lib/docs/verbs/issue.md` -> Test identifiers point at `t/verb/issue.t`.
- [ ] `lib/docs/verbs/offline.md` -> Test identifiers point at `t/verb/offline.t`.
- [ ] `lib/docs/verbs/commit.md` -> Test identifiers point at `t/verb/commit.t`.
- [ ] `lib/docs/verbs/note.md` -> Test identifiers point at `t/verb/note.t`.
- [ ] `lib/docs/verbs/ai.md` -> Test identifiers point at `t/verb/ai.t`.
- [ ] `lib/docs/verbs/companion.md` -> Test identifiers point at `t/verb/companion.t`.
- [ ] `lib/docs/verbs/test.md` -> Test identifiers; the selection forms.
- [ ] `lib/docs/core/verb_contracts.md` -> Identifiers point at `t/core/verb_contracts.t`.
- [ ] `CHEATSHEET.md` -> `aapp test` selection forms.
- [ ] `.agents/hooks/test-gate.sh` -> `TEST_CMD` back to `./aapp test strict quiet`.
- [ ] `DELETE` -> `tests/verbs/issue.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/issue.abort.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/issue.branch.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/issue.branchplugin.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/issue.fixes.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/issue.keyid.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/issue.limits.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/issue.notefilter.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/issue.onecommit.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/issue.provider.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/issue.queue.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/issue.tracker.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/offline.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/commit.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/note.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/ai.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/companion.sh` -> Ported.
- [ ] `DELETE` -> `tests/verbs/test.sh` -> Ported.
- [ ] `DELETE` -> `tests/verb_contracts_test.sh` -> Replaced by `t/core/verb_contracts.t`.
- [ ] `DELETE` -> `tests/test_helpers.sh` -> No bash suite left.
- [ ] `DELETE` -> `t/test-run` -> `aapp test` runs the test engine.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/aapp-lib.sh` -> Kit runtime stays untouched.
- [ ] `lib/AAPP/Tests.pm` -> Test engine and mock repo builder are delivered by P-136.
- [ ] `templates/aapp-pre-commit` -> Hook templates stay untouched.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — shared choices are settled in RFC §5 and single-repo schema: 2 CLI smoke tests per verb, single prepared repository with zero per-test copies, test engine and mock repo delivered by P-136).*

---

## 📦 6. Change Log & Refinement History
* **2026-10-28:** Aligned module reference for test verb with `lib/AAPP/Runner/Test.pm`.
* **2026-10-24:** Refined technical blueprint, D7 references, and checklist with single-repo schema fixture pools (Pools D, F, I, J), byte-offset event slicing, and dual-channel test assertions per salvage RFC and matrix.
* **2026-10-24:** Refined to the RFC (`.plans/pickup/perl-port-test-salvage-rfc.md`, D2–D3): after the verb ports and P-134, verbs tested through Perl functions on fixtures built once, the switch in `lib/AAPP/Cmd/Test.pm` (P-121), every file named.
* **2026-10-19:** Drafted as part 4 of 4 split from P-114 (remaining verbs, `aapp test` switch, cleanup).

