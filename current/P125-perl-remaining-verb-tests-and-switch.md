# 🗺️ Plan P-125: Perl Remaining Verb Tests And Switch
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Target Issue / Milestone:** none
* **Plan ID:** P-125
* **Changelog:** Changed: `aapp test` runs the Perl harness (`AAPP::Tests`) with module, verb, index and name selection; the bash test suites are gone (P-125)
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
Part 4 of 4 of the test migration split from P-114 (kept as the reference until all four parts are drafted). Ports the remaining verb suites to `tests/AAPP/Verb/*.pm`, then switches `aapp test` to the harness and removes everything temporary: the bash suites, `tests/test_helpers.sh`, the bash contract checker, `tests/test-run`, and the two-runner gate command. Needs P-126, P-123 and P-124 done. Kit runtime code stays untouched except the test runner (`lib/cmd_test.sh`).

---

## 2. Technical Blueprint
1. **Remaining verbs:** `issue` (with its parts: `abort`, `branchplugin`, `branch`, `fixes`, `keyid`, `limits`, `notefilter`, `onecommit`, `provider`, `queue`, `tracker`), `offline`, `commit`, `note`, `ai`, `companion`, `test`; same naming and fixture rules as P-124 §2.2–3.
2. **Contract checker in Perl:** the checks of `tests/verb_contracts_test.sh` move to `tests/AAPP/Core/VerbContracts.pm` (registry <-> contracts, contract shape, core contracts per module, every test named both ways, daily verbs in the agent reference, rules-file and skill-index checks, `aapp help` of an unknown verb); its contract `lib/docs/core/verb_contracts.md` follows.
3. **The switch (clean break):** `lib/cmd_test.sh` routes `aapp test` to `AAPP::Tests` with the runner's selection forms (P-126 §2.1.6) and `strict`, `quiet`, `bail`, `list`, `jobs <n>`; `tests/test-run` is deleted and nothing names it. `lib/docs/verbs/test.md` (Ingress, Effects, Tests) and `CHEATSHEET.md` document the forms. The `test` verb module tests the new runner.
4. **Gate back to one command:** `.agents/hooks/test-gate.sh` `TEST_CMD` returns to `./aapp test strict quiet`; the developer re-registers it with `./aapp hook-hash .agents/hooks/test-gate.sh` before `aapp done`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Remaining Verb Suites
- [ ] Task 1.1: Port `issue` and its parts.
- [ ] Task 1.2: Port `offline`, `commit`, `note`, `ai`, `companion`.

### Phase 2: The Switch
- [ ] Task 2.1: Port `tests/verb_contracts_test.sh` to `tests/AAPP/Core/VerbContracts.pm`.
- [ ] Task 2.2: Route `aapp test` to the harness in `lib/cmd_test.sh`; port the `test` verb suite against it; update `lib/docs/verbs/test.md` and `CHEATSHEET.md`.
- [ ] Task 2.3: Delete `tests/test-run`, `tests/test_helpers.sh`, `tests/verb_contracts_test.sh` and the remaining `tests/verbs/*.sh`; reset the gate's `TEST_CMD` and ask the user to re-register it.

### Phase 3: Verification
- [ ] Task 3.1: `./aapp test strict quiet` green with every module; single-test, single-verb and parallel runs; record wall and CPU time against the P-113 baseline (856 tests, 163 s wall, 1,477 s CPU).

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `tests/AAPP/Verb/*.pm` -> Verb test modules for the verbs in §2.1.
- [ ] `NEW FILE` -> `tests/AAPP/Core/VerbContracts.pm` -> The contract checker in Perl.
- [ ] `lib/cmd_test.sh` -> `aapp test` runs the harness.
- [ ] `lib/docs/verbs/*.md` -> Test identifiers point at `tests/AAPP/Verb/*.pm`; `test.md` documents the selection forms.
- [ ] `lib/docs/core/verb_contracts.md` -> Identifiers point at `tests/AAPP/Core/VerbContracts.pm`.
- [ ] `CHEATSHEET.md` -> `aapp test` selection forms.
- [ ] `.agents/hooks/test-gate.sh` -> `TEST_CMD` back to `./aapp test strict quiet`.
- [ ] `DELETE` -> `tests/verbs/*.sh` -> The remaining bash verb suites.
- [ ] `DELETE` -> `tests/verb_contracts_test.sh` -> Replaced by `VerbContracts.pm`.
- [ ] `DELETE` -> `tests/test_helpers.sh` -> No bash suite left.
- [ ] `DELETE` -> `tests/test-run` -> `aapp test` runs the harness.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/aapp-lib.sh` -> Kit runtime stays untouched.
- [ ] `templates/*` -> Hook templates stay untouched.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-19:** Drafted as part 4 of 4 split from P-114 (remaining verbs, `aapp test` switch, cleanup).
