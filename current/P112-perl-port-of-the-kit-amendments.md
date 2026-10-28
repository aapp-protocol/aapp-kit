# 🗺️ Plan P-112: Perl Port Of The Kit Amendments
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-24
* **Plan ID:** P-112
* **Kind:** amendments
* **Changelog:** Changed: Perl Port Of The Kit Amendments
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- A group's amendments member (P-101): drafted with its group, started by the group's `start`, archived
     last. It takes what development finds: members request (`aapp refine <id> request`), an approver grants
     (`approve` / `refuse`), it implements and lands on the feature branch (`aapp commit … land`), members
     rebase. Its Target Files grow only by approved requests. Corrections of the group's text go into the
     group plan with a line under `## Decisions` (`aapp refine <id> decision`). Only verbs write the three
     sections at the end. -->
* **Status:** ⚡ In Development
* **Base:** `fa3a42e` (feature/perl-port-of-the-kit)
* **Worktree:** .workspace/P112 (plan/P112-perl-port-of-the-kit-amendments)
* **Group:** P-111
* **Commits:** `41e579d` (plan/P112-perl-port-of-the-kit-amendments), `e0aeb86` (plan/P112-perl-port-of-the-kit-amendments), `373da77` (plan/P112-perl-port-of-the-kit-amendments), `6649edb` (plan/P112-perl-port-of-the-kit-amendments)
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
The group's amendments member: the one place where what the group's development finds is requested, approved, recorded and made. Members are never amended after start. Typical requests: a test outside a member that asserts the behaviour the member changes (landed here, the member rebases and turns it green); a file two members need; a correction of the group's text.

---

## 2. Technical Blueprint
Each request is implemented as its approval describes; corrections of the group's text are recorded under `## Decisions`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist
- [ ] Task 1: Implement each approved request; land it (`aapp commit … land`).
- [ ] Task 2: Leave no request pending or approved without landing before the group's members are archived.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
<!-- Empty: an approved file is changed by its requester and recorded in the plan that owns it (P-129). -->

### 🛑 Out of Bounds (Do Not Touch)

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-25:** Unfrozen to 📝 Refining to empty target files per P-129.
* **2026-10-19:** Plan activated into ⚡ In Development via start.
* **2026-10-19:** Drafted with its group.

---

## Scope Requests
- **R1** 2026-10-20 · P-115 · `lib/AAPP/Logger.pm` · Logger opens the log file with :encoding(UTF-8) (use utf8 port-wide) — landed `41e579d`
- **R2** 2026-10-20 · P-115 · `lib/AAPP/Logger.pm` · Logger writes no emoji to the log file (symbols stripped, terminal unchanged) — landed `e0aeb86`
- **R3** 2026-10-20 · P-115 · `tests/write-guard_test.sh` · write-guard fixture copies lib/AAPP into .githooks/AAPP; the no-python3 deny test keeps perl and git on PATH — landed `373da77`
- **R4** 2026-10-20 · P-115 · `tests/pre-commit_test.sh` · pre-commit fixtures that copy the hook libraries also copy lib/AAPP into the hook folder (pause reason via AAPP::JSON) — landed `373da77`
- **R5** 2026-10-21 · P-115 · `lib/AAPP/Util.pm` · AAPP::Util: the central module for reused helpers; first plan_number and plan_sort (plans sorted by number, one implementation) — landed `373da77`
- **R6** 2026-10-21 · P-115 · § ⚙️ 2. Operational Modules & Command Libraries (`lib/`) · List AAPP::Util (central reused helpers) in the codemap's core modules and in the structural map — applied
- **R7** 2026-10-21 · P-115 · § 📂 3. Global Structural Mapping · Add lib/AAPP/Util.pm to the structural map's AAPP/ listing — applied
- **R8** 2026-10-21 · P-115 · `lib/docs/core/write-guard.md` · Contract drops test_deny_payload_without_python (the python fallback it tested is gone) — landed `373da77`
- **R9** 2026-10-21 · P-115 · § Shared Hook Library & Parser Boundaries (P-37) · Hooks load AAPP::* from the installed kit ($AAPP_LIB, else the install location); init copies nothing into .githooks/ — applied
- **R10** 2026-10-21 · P-115 · § 📂 3. Global Structural Mapping · Structural map: lib/AAPP/ is loaded from the installed kit, not copied; .githooks/ holds no AAPP/ — applied
- **R11** 2026-10-21 · P-115 · § ⚙️ 2. Operational Modules & Command Libraries (`lib/`) · Codemap: init merges settings via AAPP::JSON and copies no Perl modules into .githooks/ — applied
- **R12** 2026-10-21 · P-115 · `lib/AAPP/Constants.pm` · Constants declares every default the Perl modules use (widths, title/subject limits, lock waits, plans-commit retries, remote, dev branches, modes, integrate target, kit dir name, data/state home, JSON format version) — landed `373da77`
- **R13** 2026-10-21 · P-115 · `lib/AAPP/Runner.pm` · Runner loads a verb module with a block eval: require on AAPP/Cmd/<Verb>.pm, no string eval — landed `6649edb`
- **R14** 2026-10-22 · P-126 · `lib/AAPP/Constants.pm` · P-126: test harness defaults (watchdog 60 s, jobs step 4, sandbox prefix, fallback git identity, default branch) go into AAPP::Constants — closed · landed `4a47a16`
- **R15** 2026-10-23 · P-126 · § 📂 3. Global Structural Mapping · P-126: the test engine is lib/AAPP/Tests.pm, the tests are t/core|verb/<name>.t — applied
- **R16** 2026-10-23 · P-126 · § Test Harness Sandbox Confinement · P-126: the test engine is lib/AAPP/Tests.pm, the tests are t/core|verb/<name>.t — applied
- **R17** 2026-10-23 · P-126 · § ⚙️ 2. Operational Modules & Command Libraries (`lib/`) · P-126: the test engine is lib/AAPP/Tests.pm, the tests are t/core|verb/<name>.t — applied
- **R18** 2026-10-23 · P-126 · § 🔒 3. Enforcement Engines & Hook Templates (`templates/`) · P-126: the test engine is lib/AAPP/Tests.pm, the tests are t/core|verb/<name>.t — applied
- **R19** 2026-10-23 · P-126 · `lib/AAPP/Tests.pm` · was tests/AAPP/Tests.pm: the test engine is a core module, not a test, so it sits with the runtime modules; its sandbox kit is built without tests, as an install ships none (P-121) — closed · landed `cabcde9`
- **R20** 2026-10-23 · P-126 · `t/core/output.t` · was tests/AAPP/Core/Output.pm: tests live in t/ as in any Perl project, named after their contract (lib/docs/core/output.md), runnable alone with prove -l t/ — closed · landed `cabcde9`
- **R21** 2026-10-23 · P-126 · `t/test-run` · was tests/test-run: the temporary runner sits with the tests until P-125 routes aapp test to the engine; nothing Perl stays in tests/ — closed · landed `cabcde9`
- **R22** 2026-10-23 · P-126 · `.agents/hooks/test-gate.sh` · TEST_CMD runs t/test-run instead of tests/test-run, because the runner moved (R21) — closed · landed `5652c1d`
- **R23** 2026-10-23 · P-126 · — · P-116 to P-125 name t/core/<name>.t, t/verb/<verb>.t and lib/AAPP/Tests.pm instead of tests/AAPP/, because of the P-126 re-scope (R19–R21); P-121 adds that the install ships no tests, as tests run from a kit checkout; P-111 §3 member lines follow (its Architecture & Codemap: D4–D7) — applied
- **R24** 2026-10-23 · P-111 · — · new member P-130 (amendments ledger in Perl), after P-120: the review of P-129 found the owner of a request unenforced, its why optional, approvals invisible to start and to other groups' ledgers, and the ledger's worktree unneeded; built once in Perl, the bash kit keeps P-129 — applied
- **R25** 2026-10-23 · P-123 · `lib/AAPP/Tests.pm` · lib_call passes { stdin => text } to a Perl function too (its fork reads /dev/null): plan_states tests read a Status line from stdin ('-'), as the bash suite does · for P-126 — closed · landed `0b972a4`
- **R26** 2026-10-23 · P-123 · — approved (Lorand Veres)
- **R27** 2026-10-23 · P-123 · — approved (Lorand Veres)
- **R28** 2026-10-23 · P-123 · — approved (Lorand Veres)
- **R29** 2026-10-23 · P-123 · `lib/AAPP/Tests.pm` · %LIBRARIES gains aapp_lib => lib/aapp-lib.sh: the issue_ledger writers (ledger_set_cell, ledger_archive_row, ledger_set_archive_commit, ledger_relink, roadmap_prune) are still bash until P-117 ports the issue lane; their tests call them through lib_call's bash route, as P-126 §2.1.9 foresees · for P-126 — closed · landed `3330ff2`
- **R30** 2026-10-23 · P-123 · `lib/docs/verbs/draft.md` · lib/docs/verbs/draft.md names tests/aapp_lib_test.sh::test_subject_max_len, which P-123 deleted: the line points at t/core/aapp_lib.t and says a value that is not a number is refused (R27) — closed · landed `c282704`
- **R31** 2026-10-23 · P-123 · `lib/docs/verbs/draft.md` · lib/docs/verbs/draft.md drops the test_subject_max_len line R30 repointed: a verb contract names t/verb/ files only (the engine refuses t/core/ there), and lib/docs/core/aapp_lib.md already names t/core/aapp_lib.t::test_subject_max_len — closed · landed `5fd4f62`
- **R32** 2026-10-23 · P-123 · — approved (Lorand Veres)
- **R33** 2026-10-23 · P-123 · `lib/AAPP/Tests.pm` · AAPP::Tests gains in_dir($dir, $code): runs test code with another directory as cwd and returns to the test's own, dying with the code's error; Phase 2 suites (notes, integrate, install, sync, release) run aapp and git in a second clone or remote, and issue_ledger.t's private copy moves there (one helper, reused) · for P-126 — closed · landed `92293ab`
- **R34** 2026-10-23 · P-123 · — approved (Lorand Veres)
- **R35** 2026-10-23 · P-123 · `lib/docs/verbs/refine.md` · lib/docs/verbs/refine.md drops its three tests/hooks_test.sh lines (pre-refine veto, on-refine failure, post-refine payload): P-123 deleted that suite, a verb contract names t/verb/ files only, and lib/docs/core/hooks.md names the same three tests in t/core/hooks.t — closed · landed `5e2fe63`
- **R36** 2026-10-23 · P-123 · `lib/docs/verbs/matrix.md` · lib/docs/verbs/matrix.md line 'Broader coverage ... tests/matrix_test.sh' points at t/core/matrix.t: P-123 ported and deleted that suite — closed · landed `1984a0a`
- **R37** 2026-10-23 · P-123 · `lib/docs/verbs/done.md` · lib/docs/verbs/done.md drops its nine tests/integrate_test.sh lines (integration on done): P-123 ported and deleted that suite, a verb contract names t/verb/ files only, and lib/docs/core/integrate.md names the same tests in t/core/integrate.t — closed · landed `ec6839d`
- **R38** 2026-10-23 · P-123 · — approved (Lorand Veres)
- **R39** 2026-10-24 · P-111 · — · new member P-131 (lifecycle governance: an outside program approves freeze, start, done and abort per aapp.governance mode, mode-aware CLI messages, yield rules in the lifecycle skills), 13th after P-119: the twiat run showed an agent chaining draft, freeze, start and done without yielding to the developer; P-119 creates the AAPP::Cmd::Plan it extends — applied
- **R40** 2026-10-24 · P-111 · — · new member P-132 (layered configuration: system and user main.conf above the repository's git config, a higher level always winning, allow-listed administrative keys only, read and never written by the kit), 6th after P-123 and before P-131: settings that bind the agent, such as P-131's governance mode and handler, need a place the agent cannot change; decided with the developer in the P-131 review — applied
- **R41** 2026-10-24 · P-123 · `lib/AAPP/Tests.pm` · the test sandbox also drops REPO_ROOT and PLANS_DIR: aapp exports REPO_ROOT to the hooks it runs, so under the pre-done gate the bash ledger writers in t/core/issue_ledger.t acted on the real project's .plans ledgers instead of the fixture (7 failures; nothing written only because the ids did not match). The sandbox keeps dropping GIT_* and AAPP_* and adds these two exact names · for P-126 — closed · landed `e83d584`
- **R42** 2026-10-24 · P-111 · — · new member P-133 (read the whole group plan: every pointer to a group plan in start/freeze-start, status, AGENTS.md, the aapp-start skill and group-template.md names §1 Goal and §2 Shared Decisions before ## Architecture & Codemap), 6th after P-123 (`D4`) — applied
- **R43** 2026-10-24 · P-111 · — · new member P-134 (Perl lifecycle verb tests: redraft of aborted P-124, salvaging ref/p124-cli-tests over the single prepared repository and .git/aapp.log event assertions after the verb ports, `D1`–`D3`, `D7`), 17th after P-135 — applied
- **R44** 2026-10-24 · P-111 · — · new member P-135 (Perl core tests redesign: redesigns the 16 non-pure t/core/*.t suites into Group (b) 3 single-fixture files and Group (c) 13 shared-repository Pool K + .git/aapp.log event-verified files, `D6`, `D7`), 16th after P-121 and before P-134 — applied
- **R45** 2026-10-24 · P-111 · — · P-111 group introduction, §1 Goal, §2 Shared Decisions, §3 Members & Order and ## Architecture & Codemap aligned with `.plans/pickup/perl-port-test-salvage-rfc.md` (`D1`–`D7`) and strict references `.plans/pickup/perl-port-single-repo-schema.md`, `.plans/pickup/perl-port-logging-events-spec.md`, and `.plans/pickup/perl-port-test-matrix-tabular-check.md` — applied
- **R46** 2026-10-24 · P-111 · — · new member P-136 (Perl test engine update & AAPP::TestRepo split: update lib/AAPP/Tests.pm with log-event slicing and assertion helpers, and split single prepared mock repo provisioning into lib/AAPP/TestRepo.pm, D8), 16th after P-121 and before P-135; P-111 §3, architecture and codemap updated — applied
- **R47** 2026-10-24 · P-111 · — · new member P-137 (Perl port documentation and manuals overhaul: comprehensive rewrite of README.md, MANUAL.md, and CHEATSHEET.md to fact-check and document pure Perl runtime, layered config, lifecycle governance, and group amendments), 21st after P-122 and before P-112 — applied
- **R48** 2026-10-26 · P-116 · `lib/AAPP/State.pm` · implement provider exchange in State::_allocate_id for aapp-planid provider · for P-115 — closed · landed `850223a`
- **R49** 2026-10-27 · P-116 · `lib/AAPP/Constants.pm` · add commit limits and note TTL defaults to Constants · for P-127 — closed · landed `07e14ef`
- **R50** 2026-10-28 · P-138 · § 2. Shared Decisions · CLI hierarchy for every ported command: everything that is a CLI command lives under lib/AAPP/Runner/ (top-level verbs Runner/<Verb>.pm; nouns plan, issue, review, pickup as Runner/<Noun>.pm with words in Runner/<Noun>/<Word>.pm), each with one public sub run; AAPP::Runner reads one parameter per layer and maps today's verb names to the new modules until P-140 renames the commands; all other modules stay single modules in lib/AAPP/; no lib/AAPP/Cmd/ — pending
- **R51** 2026-10-28 · P-138 · § 3. Members & Order · member order: P-116, P-138, then P-136 (test engine and mock repo) and P-135 (sweep of every test that exists by then and runs git under the hood: t/core/*.t and t/verb/review.t) before the ports P-117–P-121, P-131, P-130, so each port writes its Perl tests once, on the engine it keeps; the bash verb suites stay the safety net beside it; then P-134, P-125, P-122, P-137, P-112 last — pending

## Decisions
- **D1** 2026-10-21 · § 📂 3. Global Structural Mapping · R7 · Structural map lists Util, Constants, Logger, Runner and Paths::kit_dir (the last three done in P-127, missing)
- **D2** 2026-10-21 · § Shared Hook Library & Parser Boundaries (P-37) · R9 · Hooks load AAPP::* from the installed kit; init copies no Perl modules
- **D3** 2026-10-21 · § ⚙️ 2. Operational Modules & Command Libraries (`lib/`) · R6 · Codemap lists AAPP::Util; also Constants, Logger, Runner (done in P-127, missing) and Paths::kit_dir
- **D4** 2026-10-23 · § 📂 3. Global Structural Mapping · R15 · the test engine is a core module; tests in t/ (P-126)
- **D5** 2026-10-23 · § Test Harness Sandbox Confinement · R16 · tests in t/, engine lib/AAPP/Tests.pm (P-126)
- **D6** 2026-10-23 · § ⚙️ 2. Operational Modules & Command Libraries (`lib/`) · R17 · test engine in lib/AAPP/Tests.pm (P-126)
- **D7** 2026-10-23 · § 🔒 3. Enforcement Engines & Hook Templates (`templates/`) · R18 · the develop gate checks t/ (P-126)
- **D8** 2026-10-24 · § 📂 3. Global Structural Mapping · R45 · Structural map lists Governance.pm, log_event in Logger.pm, main.conf in Config.pm, claims in State.pm, and setup_shared_repo + log-event slicing in Tests.pm (D1–D7)
- **D9** 2026-10-24 · § Test Harness Sandbox Confinement · R45 · Single prepared repository (`$sandbox/repo`), `.git/aapp.log` byte-offset event slicing (`event_or_die`, `no_event_or_die`, `log_match_or_die`), and 6-pointer `copy_fixture` rewrite (D2, D3, D6, D7)
- **D10** 2026-10-24 · § ⚙️ 2. Operational Modules & Command Libraries (`lib/`) · R45 · Codemap lists `log_event` in Logger.pm, `main.conf` in Config.pm, `claims_for_path` in State.pm, `AAPP::Governance`, and `setup_shared_repo` / `event_or_die` in Tests.pm (D1–D7)
- **D11** 2026-10-24 · § 📂 3. Global Structural Mapping · R46 · Structural map lists TestRepo.pm under lib/AAPP/ as mock repository builder (D8)
- **D12** 2026-10-24 · § Test Harness Sandbox Confinement · R46 · Test harness AAPP::Tests delegates repository setup to AAPP::TestRepo::setup_shared_repo (D8)
- **D13** 2026-10-24 · § ⚙️ 2. Operational Modules & Command Libraries (`lib/`) · R46 · Codemap lists lib/AAPP/TestRepo.pm and updates Tests.pm (D8)

## Follow-ups
