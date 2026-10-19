# 🗺️ Plan P-113: Slim The Test Suites
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Target Issue / Milestone:** #[Issue ID or Milestone] *(`aapp draft <slug> issue <num>` writes the issue ID here and links this plan in the issue's `Target Plan / Fix` cell — the issue stays open until the fix ships)*
* **Plan ID:** P-113
* **Changelog:** Changed: slim the test suites to verb behaviour and core wrappers, fold `#nnn` regressions into behaviour tests, and add `lib/docs/core/` contracts (P-113)
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
The test suite has grown from 899 assertions (`64 s` wall) at P-68 to 1,764 assertions (`261 s` wall, `1,494 s` CPU), testing internal bash helpers, grepping source files, and running standalone regression setups for single `#nnn` fixes alongside verb behaviour tests. Before porting the harness to Perl (`P-114`), this plan slims the existing bash suites under the user's test rule (`.plans/pickup/perl-port-rfc.md` §2.5, §4) and creates `lib/docs/core/<module>.md` contract files so every core and verb test has one canonical `## Tests` list. Kit runtime code (`lib/`, `templates/`, `aapp`) is untouched.

---

## 2. Technical Blueprint

### 2.1 The Test Rule (`.plans/pickup/perl-port-rfc.md` §2.5, §4)
1. **Verb behaviour & core wrappers stay:** every daily/setup verb's observable CLI contract (`stdout`, `stderr`, exit code, committed files, worktree/branch state, JSON output) and core functions with a real effect (tested by running the wrapper against a mock/sandbox path and checking the result) are kept.
2. **Helper-only & source-grep tests go:** tests that source internal bash helpers (`_plan_state_nth`, `_plan_state_index_of`, internal `_ig_*`/`_wt_*` helpers) or `grep` bash source files for implementation strings are removed; their observable effect is verified through the wrapper or verb that calls them.
3. **Fold `#nnn` regressions into behaviour tests first:** standalone tests added solely for a `#nnn` regression (e.g. `tests/verbs/issue.fixes.sh` and one-off `#nnn` checks in `pre-commit_test.sh`, `write-guard_test.sh`, `aapp_lib_test.sh`) are folded as assertions into the corresponding behaviour test before their standalone setup is removed.
4. **Independence:** a real step chain (`draft` → `freeze` → `start` → `done`) is one test function with several checks, not separate `test_*` functions that depend on the previous test's state.

### 2.2 Core Contract Files (`lib/docs/core/<module>.md`)
Each non-verb suite (`tests/*_test.sh`) gets a contract file in `lib/docs/core/<module>.md` using the same `## Tests` line format as `lib/docs/verbs/<verb>.md`:
- `` `tests/<suite>_test.sh::test_<name>` -> <description> ``
- `tests/verb_contracts_test.sh` is extended to check both `lib/docs/verbs/*.md` and `lib/docs/core/*.md` in both directions (every listed test exists in the suite, and every test the suite reports is listed in its contract).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Fold Regressions & Slim Core Suites
- [ ] Task 1.1: Audit and slim `tests/aapp_lib_test.sh`, `tests/plan_states_test.sh`, `tests/plan_resolver_test.sh`, `tests/issue_id_test.sh`, `tests/issue_ledger_test.sh`, `tests/output_test.sh`, `tests/output_json_test.sh`, `tests/group_docs_test.sh`, and `tests/adoption_test.sh` — keep core wrapper effect tests, fold `#nnn` checks, drop internal helper unit tests.
- [ ] Task 1.2: Audit and slim `tests/pre-commit_test.sh`, `tests/write-guard_test.sh`, `tests/hooks_test.sh`, `tests/worktree_hooks_test.sh`, `tests/plugin_protocol_test.sh`, `tests/event_telemetry_test.sh`, `tests/ai_attribution_test.sh`, `tests/notes_test.sh`, `tests/integrate_test.sh`, `tests/install_test.sh`, `tests/sync_test.sh`, `tests/release_test.sh`, `tests/kit_release_hook_test.sh`, `tests/matrix_test.sh`, `tests/template_sync_test.sh`, and `tests/doc_links_test.sh`.

### Phase 2: Slim Verb Suites & Sync Contracts
- [ ] Task 2.1: Fold `tests/verbs/issue.fixes.sh` and helper-only checks in `tests/verbs/*.sh` into behaviour tests; update `lib/docs/verbs/*.md` (`## Tests`) to match.
- [ ] Task 2.2: Author `lib/docs/core/*.md` contract files for the kept core suites and extend `tests/verb_contracts_test.sh` to verify `lib/docs/core/*.md` <-> `tests/*_test.sh` in both directions.

### Phase 3: Verification
- [ ] Task 3.1: Run `/usr/bin/time -p ./aapp test strict quiet` and record the new assertion count, wall-clock time, and total CPU time (`user + sys`) as the baseline for `P-114`–`P-122`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `tests/*.sh` -> Slim core test suites to wrapper/behaviour tests and fold `#nnn` regressions.
- [ ] `tests/verbs/*.sh` -> Fold standalone `#nnn` regression setups into verb behaviour tests and drop helper-only checks.
- [ ] `lib/docs/verbs/*.md` -> Sync `## Tests` lists with the slimmed verb suites.
- [ ] `NEW FILE` -> `lib/docs/core/*.md` -> Contract files (`## Tests`) for non-verb core test suites.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/*.sh` -> Kit runtime and verb libraries are untouched in this plan.
- [ ] `templates/*` -> Hook and markdown templates are untouched in this plan.
- [ ] `aapp` -> CLI entrypoint is untouched in this plan.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified in `.plans/pickup/perl-port-rfc.md`)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-19:** Plan drafted as member 1 of group P-111 from settled RFC (`.plans/pickup/perl-port-rfc.md`).
* **2026-10-19:** Updated Task 3.1 to explicitly record CPU (`user + sys`) and wall-clock baseline per RFC §5.1.3.

