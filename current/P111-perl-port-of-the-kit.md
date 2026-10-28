# 🧩 Group Plan P-111: Perl Port Of The Kit
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-28
* **Plan ID:** P-111
* **Changelog:** Changed: port the kit runtime, hooks and test harness from bash to Perl 5.26+ with a single-pass workspace state model, decorative-only emojis and a built-in JSON engine
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The umbrella CHANGELOG.md entry for what the whole group delivers; members keep their own entries.
     The group's `done` writes it with the ARCHITECTURE.md commit. -->
* **Status:** ⚡ In Development
* **Base:** `fa3a42e` (port/perl)
* **Feature Branch:** feature/perl-port-of-the-kit
* **Members:** P-113, P-115, P-116, P-117, P-118, P-119, P-120, P-121, P-122, P-123, P-125, P-126, P-127, P-130, P-131, P-132, P-133, P-134, P-135, P-136, P-137, P-138, P-142, P-145, P-112
* **Commits:** none
<!-- AAPP-PROTOCOL:START v1.0.0 -->
<!-- A group plan writes no code. `aapp start <group> [base <branch>]` cuts `feature/<slug>` from the parent
     branch; members are planned with `aapp draft <slug> group P-111` (or `aapp refine <id> group P-111`) and
     start from the feature branch. `aapp done <group>` refuses while a member is open, applies the sections
     below, runs the pre-done gate on the feature branch and merges it into the parent. -->

> **Read this whole plan before starting or resuming any member.** §1 says why the group exists and how its success is measured; §2 holds the decisions every member keeps; `## Architecture & Codemap` is the target architecture. A member's own plan is read against them.

---

## 1. Goal
The kit's design holds; its cost is ~20.5k lines of bash spawning ~45k processes in a single verb suite (`1,494 s` CPU across 1,764 assertions, `sys > user` 2:1). This group ports the test harness, hooks, and CLI verbs from bash (and `python3` JSON helpers) to Perl 5.26+ directly into a unified noun-first CLI architecture (`lib/AAPP/Runner/`, absorbing Group P-140):
1. **Slim and modularize the test suite (`P-113`, `P-126`, `P-123`, `P-136`, `P-135`, `P-134`, `P-125`):** keep verb behaviour and core wrapper tests, fold `#nnn` regressions into behaviour tests, add `lib/docs/core/<module>.md` contracts, and move to the `AAPP::Tests` Perl harness (`lib/AAPP/Tests.pm`) and separate mock repo builder (`lib/AAPP/TestRepo.pm`, `D8`) over a single pre-seeded repository (`$sandbox/repo`, `.plans/pickup/perl-port-single-repo-schema.md`) and native `.git/aapp.log` event telemetry (`AAPP::Logger::log_event`, `.plans/pickup/perl-port-logging-events-spec.md`), verified against `.plans/pickup/perl-port-test-matrix-tabular-check.md`.
2. **Single-pass Perl core and state model (`P-127`, `P-115`, `P-132`):** read `git config` and upper-level `main.conf` files (`AAPP::Config`), paths, active-plan buffer, `.plans/current/*.md`, plan states, and ledgers once per process (`AAPP::State`), with a single deterministic kit JSON module (`AAPP::JSON`, retiring `python3`), structured event logging (`AAPP::Logger`), and decorative-only emoji normalization (`AAPP::Text`).
3. **Port hooks and verbs by slice directly to noun-first runners (`P-116`, `P-138`, `P-136`, `P-135`, `P-117`–`P-121`, `P-131`, `P-130`), then verb tests (`P-134`, `P-125`), bash removal (`P-122`) and manuals overhaul (`P-137`):** hooks first (`P-116`), then the first noun runner & review skill (`P-138`), test engine update & mock repo (`P-136`) and core test redesign (`P-135`), followed by noun-first verb ports: issue/offline lane with issue ledger words (`P-117`), read-only verbs (`P-118`), plan lifecycle noun & words (`P-119`, absorbing P-139), lifecycle governance (`P-131`), commit/notes/ai (`P-120`), amendments ledger as `plan amend` (`P-130`), and setup/release (`P-121`). Test suites (`P-134`, `P-125`) test the noun-first CLI once without throwaway intermediate suites, followed by bash clean break (`P-122`) and user documentation overhaul (`P-137`).

Design & measurements: `.plans/pickup/perl-port-rfc.md` (settled 2026-10-19) and `.plans/pickup/perl-port-test-salvage-rfc.md` (`D1`–`D8`, settled 2026-10-24), with strict implementation references `.plans/pickup/perl-port-single-repo-schema.md`, `.plans/pickup/perl-port-logging-events-spec.md`, and `.plans/pickup/perl-port-test-matrix-tabular-check.md` (`D7`, `D8`). Merge criterion: every member archived and the `pre-done` gate green on `feature/perl-port-of-the-kit`.

## 2. Shared Decisions
- **Perl floor & dependencies:** Perl `5.26` (`use 5.026; use strict; use warnings; use utf8;`). Core modules only (`Digest::SHA`, `File::Spec`, `File::Path`, `File::Basename`, `File::Copy`, `POSIX`, `Time::HiRes`, `Cwd`). Zero CPAN dependencies.
- **One kit JSON module (`AAPP::JSON`), never `JSON::PP`:** `JSON::PP` is absent from Debian's `perl-base`, packaged apart on Fedora/RHEL, and Perl hash order / alphabetical `canonical` sorting violates the table-order contract (`docs/reference/08-output-json.md`). `AAPP::JSON` provides an ordered `@_` key-value builder (`json_obj(k1 => $v1, ...)`), 2-space pretty-printer, and reader for write-guard payloads, `.claude/settings.json`, and pause snapshots — replacing `python3` everywhere (folding in the "Perl in place of python3" pickup entry).
- **Emojis are decorative only (`AAPP::Text`):** Every parser normalizes headings, statuses, and table cells by stripping leading non-ASCII symbols/emojis and spaces via `^(?:(?=[^\x00-\x7F])[\p{S}\p{Me}\x{2139}]|[\x{200D}\x{FE0E}\x{FE0F}\s])+`. This strips all kit emojis (including `ℹ️` U+2139 `Ll`, arrows `Sm`, skin tones `Sk`, keycaps `Me`) while keeping leading ASCII symbols (`` ` ``, `$`, `~`) and accented/non-Latin letters (`Árak`, `日本語`). Emojis are emitted for human readers only and never required when reading back.
- **One workspace state read per process (`AAPP::State`):** One `git config --list -z` and one `git rev-parse --show-toplevel --git-common-dir --git-dir` per process, plus one in-memory pass over `aapp_active_plan`, `.plans/current/*.md` (headers, §3 required tests, §4 Target Files / Required Test Files / Out of Bounds), plan states, and ledgers. Hooks and verbs query `AAPP::State` in memory.
- **Noun-first CLI architecture (`lib/AAPP/Runner/`, absorbing P-140):**
  - Everything that is a CLI command lives under `lib/AAPP/Runner/`; every shared core module stays a single module in `lib/AAPP/` (no `lib/AAPP/Cmd/`).
  - Top-level verb: `lib/AAPP/Runner/<Verb>.pm` (`Status.pm`, `Help.pm`, `Commit.pm`, `Note.pm`, `Ai.pm`, etc.).
  - Noun: `lib/AAPP/Runner/<Noun>.pm` (`Plan.pm`, `Issue.pm`, `Pickup.pm`, `Review.pm`), with its words in `lib/AAPP/Runner/<Noun>/<Word>.pm` (`AAPP::Runner::Plan::Draft`, `Freeze`, `Start`, `Done`, `Commit`, etc.; hyphenated words join parts).
  - One file per command; one parameter per layer: `AAPP::Runner` reads only the first parameter and calls `AAPP::Runner::<Name>->run(@rest)`; a noun module reads only its first parameter (the word) and calls `AAPP::Runner::<Noun>::<Word>->run(@rest)`; with no word it runs its bare form (e.g. switchboard for `plan`) or lists its words. The delegate step is written once in `AAPP::Runner` and called across layers.
  - One public sub per command module: `run`.
- **Clean break eliminating `refine` and legacy top-level verbs:**
  - `refine` leaves the kit entirely: plan forms become `aapp plan <word>` (`plan commit`, `plan rename`, `plan block`, `plan unblock`, `plan closes`, `plan join`, `plan leave`, `plan amend`), issue forms become `aapp issue commit`, `aapp issue branch`, `aapp issue note`, and pickup becomes `aapp pickup commit`.
  - `aapp plan commit <id> "<msg>"` commits plan text in `.plans/`; `aapp commit "<msg>"` commits code for the active plan.
  - Reserved words: noun words are reserved after the noun; a plan named like a plan word is referenced by its ID (`P-<n>`).
- **Tests vs. code boundary & revised ordering (`D1`–`D8`, `R51`):** Hooks (`P-116`) and the first noun runner `review` (`P-138`) are implemented, followed by the test engine update (`P-136`) and core test redesign sweep (`P-135`). Then noun-first verb ports (`P-117`–`P-121`, `P-131`, `P-130`) write their Perl tests once directly against `AAPP::Runner` and the prepared mock repo, avoiding throwaway intermediate test suites. Each ported module emits structured telemetry via `AAPP::Logger::log_event($command, $event, \%data)`.
- **Porting parent branch & `develop` fix-only workflow:** Before starting the port, a tag is placed on `develop` at the cut point and a porting parent branch (e.g. `port/perl`) is cut from `develop`. The group is started from that parent (`aapp start P-111 base <parent>`); `aapp done P-111` merges into `<parent>`, and `<parent>` goes into `develop` by the user's hand. During the port, `develop` keeps the working bash kit and takes fixes only; fixes reach the port by merging `develop` into `<parent>`. The `aapp` that drives the port is the installed `develop` kit; no `aapp install` is run from the port branch until it lands.
- **Single source for verb syntax, behavior, logging & test matrix (`D7`):** Member plans treat `aapp help <verb> full`, `lib/docs/{verbs,core}/*.md`, `.plans/pickup/perl-port-single-repo-schema.md`, `.plans/pickup/perl-port-logging-events-spec.md`, and `.plans/pickup/perl-port-test-matrix-tabular-check.md` as strict implementation references.
- **Modular test harness (`lib/AAPP/Tests.pm`), separate mock repo builder (`lib/AAPP/TestRepo.pm`), single prepared repository & log-event verification (`D2`, `D3`, `D6`, `D7`, `D8`):** Test files live in `t/core/*.t` and `t/verb/*.t` (run by `lib/AAPP/Tests.pm`, runnable alone via `prove -l t/`). Per Decision `D8`, creation of the single prepared mock repository at `$sandbox/repo` (`$self->{shared_repo}`) is implemented as a dedicated module `lib/AAPP/TestRepo.pm` (`AAPP::TestRepo`), isolating repository provisioning from test harness execution (`P-136`). Verb tests (`P-134`, `P-125`) call `AAPP::Runner::*->run(@args)` via `lib_call` (plus 2 CLI smoke tests per verb via `run_aapp`), slice `.git/aapp.log` by byte offset before and after each call, and assert behavior via `event_or_die`, `no_event_or_die`, and `log_match_or_die`.
- **Adopter plugins and hooks:** Keep the language-neutral JSON stdin + POSIX environment protocol unchanged.

## 3. Members & Order
1. **P-113** (`P113-slim-the-test-suites.md`): slim the bash suites to verb behaviour and core wrappers, fold `#nnn` regressions into behaviour tests, and author `lib/docs/core/<module>.md` contracts. Code untouched.
2. **P-127** (`P127-perl-foundation.md`): `AAPP::Constants` (declared return numbers), `AAPP::Paths`, `AAPP::Config`, `AAPP::Logger` (standard output line, `aapp.perlLogFile`), `AAPP::Runner` (signals, crash handling, exit codes), and the comment rule. Nothing in the bash kit switched.
3. **P-115** (`P115-perl-core-and-state-model.md`): `AAPP::Text` (emoji-free normalizer + wrap/cut), `AAPP::JSON` (the one JSON writer and reader, for code and tests; retiring `python3`), `AAPP::Output`, `AAPP::State`, `AAPP::CommitEngine`, `AAPP::Health`, and `aapp` hybrid verb routing, on P-127's foundation. The slimmed bash suites are its safety net.
4. **P-126** (`P126-perl-test-runner.md`): the test engine `lib/AAPP/Tests.pm` on the foundation and core, the temporary `t/test-run`, the `output` proof file `t/core/output.t`, and the two-runner gate command.
5. **P-123** (`P123-perl-core-test-modules.md`): core suites to `t/core/*.t`; the seven core-library test files call `AAPP::*` directly.
6. **P-133** (`P133-read-the-whole-group-plan.md`): every pointer to a group plan (`start`/`freeze-start`, `status`, `AGENTS.md`, `aapp-start` skill, `group-template.md`) names the whole group plan (§1 Goal, §2 Shared Decisions, `## Architecture & Codemap`) first (`D4`).
7. **P-132** (`P132-layered-configuration.md`): system and user `main.conf` files above the repository's git config, a higher level always winning; upper levels take allow-listed administrative keys only, read and never written by the kit.
8. **P-116** (`P116-perl-hooks-and-write-guard.md`): port `aapp-pre-commit`, `aapp-pre-commit-develop`, `aapp-commit-msg`, `aapp-post-commit`, `aapp-post-rewrite`, `blast-radius-guard.sh`, `AAPP::HookDispatcher`, and `AAPP::Attribution` to Perl over `AAPP::State`, `AAPP::JSON`, and `AAPP::Logger::log_event`.
9. **P-138** (`P138-review-verb-and-skill.md`): first noun runner (`lib/AAPP/Runner/Review/`), RFC template, review findings §7 and review fixes §8, establishing the `AAPP::Runner` layered delegation.
10. **P-136** (`P136-perl-test-engine-and-mock-repo.md`): update test engine `lib/AAPP/Tests.pm` with multi-repo log-event byte-offset slicing, assertion helpers (`event_or_die`, `no_event_or_die`, `log_match_or_die`), epoch replay, and `%LIBRARIES` switch to Perl; create separate mock repository builder `lib/AAPP/TestRepo.pm` (`AAPP::TestRepo`) provisioning the 7 pools (L, S, C, G, I, D, K), mock files, plans, and issues per single-repo schema (`D8`).
11. **P-135** (`P135-perl-core-tests-redesign.md`): redesign the 16 non-pure `t/core/*.t` suites (323 contract tests across 25 core files) and sweep existing tests (`t/core/*.t`, `t/verb/review.t`) over the prepared repository.
12. **P-117** (`P117-perl-issue-and-offline-lane.md`): port `aapp issue` (`log`, `hotfix`, `fix`, `queue`, `close`, `abort`, `list`, plus ledger words `commit`, `branch`, `note`, absorbing P-144) and `offline` under `lib/AAPP/Runner/Issue/` and `Offline.pm`.
13. **P-118** (`P118-perl-readonly-verbs.md`): port `status`, `help`, and `AAPP::Adoption` under `lib/AAPP/Runner/` (`matrix` and `plan-status` move under `aapp plan` in P-119).
14. **P-119** (`P119-perl-plan-lifecycle.md`): port all plan lifecycle and query commands directly under the `aapp plan` noun (`lib/AAPP/Runner/Plan/`, absorbing P-139): `draft`, `tdd`, `freeze`, `start`, `freeze-start`, `done`, `active`, `status`, `matrix`, `commit`, `rename`, `block`, `unblock`, `closes`, `join`, `leave`, `abort`, `conflict-check`, `conflict-free`, and `AAPP::GroupDocs`.
15. **P-131** (`P131-lifecycle-governance-and-review-gates.md`): lifecycle governance: external gate for `plan freeze`, `plan start`, `plan done`, `plan abort`.
16. **P-120** (`P120-perl-commit-and-integration.md`): port `commit` (code commit, distinguished from `plan commit`), `note`, and `ai` under `lib/AAPP/Runner/`.
17. **P-130** (`P130-perl-amendments-ledger.md`): amendments ledger under `aapp plan amend <request|approve|refuse|decision>` (`lib/AAPP/Runner/Plan/Amend.pm`).
18. **P-121** (`P121-perl-setup-and-release.md`): port `init`, `install`, `upgrade`, `uninstall`, `develop`, `sync`, `release`, `companion`, `hook`, `pause`/`resume`, and `test` under `lib/AAPP/Runner/`.
19. **P-134** (`P134-perl-lifecycle-verb-tests.md`): lifecycle verb suites in `t/verb/plan.t` testing all `aapp plan <word>` commands over the prepared repository and event assertions.
20. **P-125** (`P125-perl-remaining-verb-tests-and-switch.md`): remaining verb suites (`issue`, `pickup`, `status`, `commit`, etc.) in `t/verb/*.t`; `aapp test` switches to `AAPP::Tests`; bash suites removed.
21. **P-122** (`P122-remove-bash-clean-break.md`): convert `aapp` to pure Perl, rename `aapp.perlLogFile` to `aapp.logFile`, clean break removing legacy `.sh` files and top-level verbs.
22. **P-137** (`P137-perl-port-documentation-and-manuals.md`): comprehensive user documentation overhaul (`README.md`, `MANUAL.md`, `CHEATSHEET.md`) documenting the pure Perl 5.26+ runtime with noun-first CLI.
23. **P-112** (`P112-perl-port-of-the-kit-amendments.md`): group amendments member (started with the group, archived last).

## Architecture & Codemap
*Every changed section of `ARCHITECTURE.md` and `.agents/CODEMAP.md`, written out whole in a ```` fence, under the exact heading it has (or will have) in the file. Members do not edit these files; read the sections here as the target architecture. At the group's `done` a section replaces the file's section with the same heading, or is added at the end. `aapp refine` records a base line above each fence: `done` refuses a section the file changed meanwhile. Write `No changes.` under a file that keeps its content.*

### ARCHITECTURE.md
<!-- aapp-base: e28e6edc004e07b38c41db76e04fb11ddd1f1d3f8a894528c5134a327ee7d95c -->
````markdown
## 🚀 1. Executive Summary & Philosophy
* **Primary Purpose:** Asymmetric Agent Planning Protocol (AAPP) — a deterministic, low-dependency protocol decoupling planning, agent behavioral rules, and git enforcement hooks from application code using isolated Git worktrees and dual-layer blast radius enforcement.
* **Core Pillars:**
  * **Worktree Isolation:** Blueprints (`plans`), agent behavioral rules (`agents`), and enforcement hooks (`githooks`) reside on isolated orphan git branches, keeping design text completely decoupled from active application code branches.
  * **Dual-Layer Blast Radius Enforcement:** Layer 1 write-time interception (PreToolUse hook) prevents out-of-bounds file edits before touching disk; Layer 2 authoritative pre-commit gate blocks unauthorized staged commits.
  * **Single-Active-Plan Architecture:** Per-worktree execution pointer buffers (`$(git rev-parse --git-path aapp_active_plan)`) eliminate cross-plan interference and enable deterministic parallel multi-agent workflows.
  * **Single-Pass Workspace State (`AAPP::State`):** Each CLI command and Git hook loads repository configuration (`git config --list -z`), paths (`git rev-parse`), active-plan buffers, `.plans/current/*.md` blueprints, and ledgers once per process in memory.
  * **Master Emergency Brake & Multi-Worktree State Preserver ("Hibernate & Wake"):** Circuit Breaker (`aapp pause`, `aapp resume`) quarantines in-flight changes into SHA-addressed stashes across dynamically discovered worktrees, blocks codebase modifications, and safely wakes with drift forensics.
  * **Zero Non-Core Dependencies:** Pure Perl 5.26+ core modules and Git plumbing, with a built-in deterministic JSON engine (`AAPP::JSON`) and decorative-only emoji normalizer (`AAPP::Text`).

---
````
<!-- aapp-base: d13c111c020802c911d29255c51e2725162546e89ceb55962ce932be7a4cd2d7 -->
````markdown
## ⚙️ 2. Technology Stack & Runtime
* **Core Language Runtime:** Perl (5.26+, `use 5.026; use strict; use warnings; use utf8;`) and Git (2.20+).
* **Dependencies:** Zero external CPAN, npm, pip, or Python packages. Core Perl modules only (`Digest::SHA`, `File::Spec`, `File::Path`, `File::Basename`, `File::Copy`, `POSIX`, `Time::HiRes`, `Cwd`).
* **Attribution Engine:** Git semantic commit trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`) and native git notes across two fixed namespaces: `refs/notes/commits` (developer notes) and `refs/notes/ai` (AI traces).

---
````
<!-- aapp-base: 0e4e276623f91cb62537c6fcae416df1b623b665a5450270be0c24eadb27611f -->
````markdown
## 📂 3. Global Structural Mapping
```text
├── aapp                   # Primary Perl CLI executable & verb dispatcher
├── lib/                   # Operational Perl modules, registries & contracts
│   ├── verbs.tsv          # Canonical CLI manifest; 5th column links daily verbs to their contracts
│   ├── plugins.tsv        # Canonical kit-reserved action plugin registry
│   ├── plugin_do.tsv      # Whitelist of aapp commands allowed in plugin `do` lists
│   ├── docs/verbs/        # Per-verb behaviour contracts: ingress, failure modes, effects, tests (P-34)
│   ├── docs/core/         # Per-module core behaviour contracts: `## Tests` (P-113)
│   └── AAPP/              # Core Perl 5.26+ runtime & verb modules (hooks load them from the installed kit; never copied)
│       ├── Constants.pm   # Every default, return numbers & their exit codes
│       ├── Util.pm        # Central reused helpers (plan_number, plan_sort); one implementation each
│       ├── Logger.pm      # The one agent output line, structured event emitter (`log_event`) & log file (`aapp.logFile`, no emoji)
│       ├── Runner.pm      # CLI entry, signals, crash handling, exit codes
│       ├── Config.pm      # Multi-level INI (`main.conf`) & single-pass git config reader, plan status registry (`aapp.planState.*`)
│       ├── Paths.pm       # Single-pass repository/worktree path resolver, kit locator (kit_dir), globs, OS & named locks
│       ├── Text.pm        # Decorative-only emoji normalizer, UTF-8 char length, wrap & cut
│       ├── JSON.pm        # Deterministic ordered JSON builder, pretty-printer, envelope & reader
│       ├── Output.pm      # Shared terminal & JSON record renderers
│       ├── State.pm       # Single-pass workspace state model (buffers, plans, claims, ledgers, note store)
│       ├── CommitEngine.pm# Unified .plans worktree commit engine (plans_commit)
│       ├── Health.pm      # 8-pair mechanical planning health validator
│       ├── Governance.pm  # Pluggable external lifecycle governance protocol (`aapp.governance*`, HITL/strict/lax/autonomous)
│       ├── HookDispatcher.pm # Lifecycle hook & action plugin dispatcher (SHA-256 + watchdog)
│       ├── Attribution.pm # AI identity resolution, trailer decorator & staged note writer
│       ├── Adoption.pm    # Adoption checklist rules catalogue, sync engine & open-task counter
│       ├── GroupDocs.pm   # Group plan ARCHITECTURE.md / CODEMAP.md section stamper & applier
│       ├── Issue.pm       # Issue domain helpers, provider exchange, outbox & fix-worktree engine
│       ├── Plan.pm        # Plan lifecycle, worktree (_wt_*), squash (_sq_*) & integration (_ig_*)
│       ├── TestRepo.pm    # Single prepared mock repository builder (setup_shared_repo, pools L, S, C, G, I, D)
│       ├── Tests.pm       # Test engine (`aapp test`): shared repo (`setup_shared_repo`), log-event slicing, fixture copies, watchdog, parallel workers, recap
│       ├── Hooks/         # Hook implementation modules (PreCommit, CommitMsg, PostCommit, PostRewrite, WriteGuard, PreCommitDevelop)
│       └── Runner/        # Universal CLI command hierarchy (single-parameter dispatch; top-level verbs & nouns Plan/, Issue/, Pickup/, Review/)
├── templates/             # Version-controlled hook entrypoints and starter blueprints
│   ├── blast-radius-guard.sh # Layer 1 PreToolUse write-guard Perl entrypoint
│   ├── aapp-pre-commit    # Layer 2 Authoritative pre-commit Perl entrypoint
│   ├── aapp-pre-commit-develop # Develop-only contract correspondence hook entrypoint
│   ├── aapp-commit-msg    # Commit-msg conciseness & trailer validator Perl entrypoint
│   ├── aapp-post-commit   # Post-commit Option C staged note attacher Perl entrypoint
│   ├── aapp-post-rewrite  # Post-rewrite commit SHA mapper Perl entrypoint
│   ├── plan-template.md   # ADR-style blueprint template
│   ├── group-template.md  # Group plan blueprint template
│   ├── amendments-template.md # Group amendments member template
│   ├── adoption.md        # Starter adoption checklist template (P-63)
│   ├── state_matrix.md    # Active plan lane & incubator brain
│   ├── issues.md          # Active flat defect table template
│   ├── issues_road_map.md # Work queue template (plan blockers, queued issues)
│   ├── done-issues-archive.md # Relocated defect archive template
│   ├── 000-archive-ledger.md  # Master architectural archive ledger template
│   └── skills/            # Universal AAPP lifecycle skills
├── t/                     # Perl test files run by `AAPP::Tests` (`aapp test`, or `prove -l t/`); not installed
│   ├── core/              # `<name>.t`: the tests of `lib/docs/core/<name>.md`
│   └── verb/              # `<verb>.t`: the tests of `lib/docs/verbs/<verb>.md`
├── scripts/               # Migration and maintenance utilities
│   ├── scrub-attribution.sh # Attribution migration & SHA repair utility
│   └── kit-on-release.sh  # Kit self-release on-release action delegate hook (P-59)
├── .plans/                # Isolated planning worktree (mounted on branch 'plans')
├── .agents/               # Behavioral rules & codemap worktree (branch 'agents')
├── .claude/               # Gitignored Claude Code bridge (relative symlinks)
├── .githooks/             # Blast radius enforcement worktree (branch 'githooks')
├── CHANGELOG.md           # Public release notes & keep-a-changelog ledger
├── README.md              # Project overview & quick start guide
├── MANUAL.md              # Comprehensive manual & technical reference
├── CHEATSHEET.md          # 1-page cheatsheet for human & agent reference
└── ARCHITECTURE.md        # System architecture overview & invariants
```

---
````
<!-- aapp-base: e50b2e8beb951919efe5fa748d7bb7f0d4fd87d46a07aef4457344de8d48be9b -->
````markdown
#### Shared Hook Library & Parser Boundaries (P-37)
`lib/AAPP/` (`AAPP::State`, `AAPP::Paths`, `AAPP::Text`, `AAPP::Config`) is the single owner of plan-section parsing (`Target Files`, `Emergency Hotfix Extensions`, `Required Test Files`, `Out of Bounds`, numbered section extraction), plan and group progress, glob matching (`glob_to_regex`, `match_pattern_list`), decorative-only emoji normalization (`AAPP::Text`), and platform detection (`aapp_os`). `lib/AAPP/` is the only copy: hook entrypoints in `.githooks/` load `AAPP::*` from the installed kit (`$AAPP_LIB` when an `aapp` verb runs the hook, else `AAPP::Paths::kit_dir()`'s `lib/`); `aapp init` copies no Perl modules. A hook that cannot load them refuses (the write guard exits 2). Every parser normalizes headings, statuses, and table cells by stripping leading non-ASCII symbols/emojis and whitespace (`^(?:(?=[^\x00-\x7F])[\p{S}\p{Me}\x{2139}]|[\x{200D}\x{FE0E}\x{FE0F}\s])+`), so emojis are decorative only. Parser boundaries: target and Out of Bounds headings count only inside `## 4.`, match by normalized name (`Target Files`, `Required Test Files` grant writes; `Out of Bounds` vetoes), any other heading ends the region, fenced blocks and `>` lines are never parsed.
````
<!-- aapp-base: d8825859e59331c696e8fa0957df341ead7661ab78e9102254b57c6ac68c5654 -->
````markdown
#### Test Harness Sandbox Confinement
All tests are files in `t/` (`t/core/<name>.t`, `t/verb/<verb>.t`, each a package of `test_*` subs named after its contract) run by the test engine `lib/AAPP/Tests.pm` (`AAPP::Tests`, a core module), which confines every test to a disposable sandbox under the system's temporary directory (an installed kit ships no tests). Once per test run, `setup_shared_repo($sandbox)` delegates to `AAPP::TestRepo::setup_shared_repo($sandbox)` (`lib/AAPP/TestRepo.pm`) to build a single pre-seeded repository at `$sandbox/repo` (`$self->{shared_repo}`) with disjoint mock source files (`src/l01.py`..`src/d16.py` and `src/k01.py`..`src/k12.py`), pre-seeded plans (`P-1`..`P-35`, `P-1L`, `P-2L`, `P-290`, `P-50`..`P-62`) across Pools L, S, C, G, I, D, K, and issues (`#1`..`#8`, `aapp.issueId = 9`), bare remotes (`$sandbox/origin.git`, `comp-non-aapp`, `comp-aapp`), plus `aapp.logFile` set to `.git/aapp.log` (`.plans/pickup/perl-port-single-repo-schema.md`, `D8`). Verb and scenario tests call `AAPP::*` and `AAPP::Runner::*` functions in-process via `lib_call` (forking the test for fresh caches with zero `perl` interpreter startup), slice `.git/aapp.log` by byte offset before and after each call into `$res->{events}` and `$res->{log_lines}`, and assert behavior via `event_or_die`, `no_event_or_die`, and `log_match_or_die` (`.plans/pickup/perl-port-logging-events-spec.md`), alongside 2 thin CLI smoke tests per verb (`run_aapp`). When a file uses a dedicated fixture copy (`copy_fixture`), all 6 worktree pointer locations are rewritten in-process in Perl; `prove -l t/` runs any file alone with a TAP plan (`setup_shared_repo` initializes `$sandbox/repo` on demand). Each test executes in its own process group under a `60 s` watchdog (killing `-PGID` on timeout; an interrupt stops each worker's group with TERM, a grace period, then KILL) with developer identity inherited and GPG signing disabled (`gpgsign false`). Test order and descriptions come from `lib/docs/verbs/<verb>.md` and `lib/docs/core/<name>.md` (`## Tests`), verified bidirectionally, and failed `not ok` lines are repeated after the summary banner. The engine's defaults are `TEST_*` in `AAPP::Constants`.
````
<!-- aapp-base: 9e0118d0205066c56e8c84707dd0387f8cc2323bf5e36c856148860f47578181 -->
````markdown
## Output: Records, Terminal, JSON (P-91)

`aapp status` and `aapp issue list` collect what they show into records first: structured records holding raw values (slugs, ids, dates, full text). Two renderers in `AAPP::Output` and `AAPP::JSON` print the records and compute nothing, so the outputs cannot disagree.

* **Terminal.** Every line within `aapp.statusOutputWidth` characters (default 85). An item's long text wraps with a hanging indent (`AAPP::Text::out_wrap`); an issue's facts stand on a line of their own, the symptom below it. The briefing cuts long text (`aapp.statusTextMax`, `AAPP::Text::out_cut`) and caps long lists (`aapp.statusItemsMax`); `issue list` never cuts. The full text stays in its file.
* **JSON.** A bare `json` token prints one JSON object on stdout and nothing else: the document, or, when the run fails, an error document (`error.code`, `message`, `aapp_config`, P-100), the exit code saying which. A JSON run never waits for input; whatever it says on the way is in its `notices`, grouped as `warning` and `info`. Its fields are a contract, versioned and documented in `docs/reference/08-output-json.md`; adding a field keeps the version, renaming or removing one raises it. Text is verbatim (inline Markdown as written), absent values are `null`, enums are lowercase slugs.

`AAPP::JSON` is the kit's single JSON builder, 2-space pretty-printer, and reader (taking ordered `@_` key-value pairs so keys always appear in the order documented in `08-output-json.md`, without `JSON::PP` or `python3`).
````

### .agents/CODEMAP.md
<!-- aapp-base: 0afb347550e05020da2659c286a8a2bc52d4d4ca4bec83706f142fb9e449e011 -->
````markdown
## 🏗️ 1. Core Executables & CLI Switchboard

### 🚀 Primary Dispatcher (`aapp`)
* **Purpose:** Single source of truth for Perl 5.26+ CLI entrypoint, base resolution, and command routing.
* **Key Functions:**
  * `has_kit_signature($dir)` -> Validates presence of essential kit structures (`templates/`, `pre-commit`, `AGENTS.md`, `lib/AAPP/`).
  * `is_safe_to_consume_kit_dir($dir, $keep)` -> Content-based signature, file manifest audit, and clean git working tree check protecting non-kit assets and development checkouts from self-consumption.
* **Responsibilities:** Resolves runtime environment (`AAPP_RUNTIME=installed|local`, `AAPP_BASE`), enforces plugin re-entrancy guards (`AAPP_PLUGIN_STEP`), asserts front-door Git repository membership via `AAPP::Paths`, and dispatches verbs in-process to `AAPP::Runner`.
* **Anti-Wrapper Warning:** Never write wrapper shell scripts around `aapp` commands; invoke `aapp` directly.

---
````
<!-- aapp-base: aeb41292a570d5e5073203a14d0c577c7f13772aaa984f1b8b12e12164bbcb08 -->
````markdown
## ⚙️ 2. Operational Modules & Command Libraries (`lib/`)

### 🧱 Core State, Config, Paths, Text & JSON (`lib/AAPP/`)
* **`lib/AAPP/Constants.pm`:** Every default the modules use (widths, limits, waits, retries, remote, branches, modes, kit and state folder names, JSON format version) and the declared return numbers with their exit codes; no module hard-codes a default.
* **`lib/AAPP/Util.pm`:** Central reused helpers, one implementation each: `plan_number`, `plan_sort` (plans by number, not as text).
* **`lib/AAPP/Logger.pm` & `lib/AAPP/Runner.pm`:** The one agent output line (`print_msg`, `[ TAG ] text`), structured event emitter (`log_event($command, $event, \%data)`), and optional log file (`aapp.logFile`, UTF-8, no emoji); the CLI entry with signal handling, crash reporting, universal single-parameter layered dispatch (`run`), and exit codes from return numbers.
* **`lib/AAPP/Config.pm`:** Multi-level INI (`main.conf`, `System > User > Repo` inverted precedence with upper-level allowlist) and single-pass `git config --list -z` loader, plus Plan Status Registry (`aapp.planState.*`, matching by canonical name after `AAPP::Text` emoji stripping).
* **`lib/AAPP/Paths.pm`:** Single-pass repository and worktree path resolver (`git rev-parse --show-toplevel --git-common-dir --git-dir`), the one kit locator (`kit_dir`, OS-aware), glob matcher (`glob_to_regex`, `match_pattern_list`), platform detector (`aapp_os`), and named lock engine (`aapp_lock_acquire`, `aapp_lock_release`, `aapp_lock_held`).
* **`lib/AAPP/Text.pm`:** Decorative-only emoji normalizer (`strip_leading_emoji`), UTF-8 character counter (`aapp_char_len`), line wrapper (`out_wrap`), truncator (`out_cut`), and pickup line splitter (`pickup_entry_split`).
* **`lib/AAPP/JSON.pm`:** Zero-dependency ordered JSON builder (`json_obj`, `json_list`, `json_str`, `json_strn`, `json_num`, `json_numn`, `json_bool`), 2-space pretty-printer, envelope/notices/error document builders (`docs/reference/08-output-json.md`), and JSON reader for hook/plugin payloads, `.claude/settings.json`, and pause snapshots.
* **`lib/AAPP/Output.pm`:** Shared terminal and JSON record renderers (`issue_render_terminal`, `issue_render_json`, `out_width`).
* **`lib/AAPP/State.pm`:** Single-pass workspace state loader reading `aapp_active_plan`, held plans across worktrees, `.plans/current/*.md` blueprints (headers, Status slugs, §3 required tests, §4 Target Files / Required Test Files / Out of Bounds), cross-plan/cross-ledger file claims (`claims_for_path`), and the issue/archive/roadmap/offline ledgers (`ISSUES.md`, `done/000-issues-archive.md`, `issues_road_map.md`, `.offline/`) plus the external issue text store (`~/.local/state/aapp/<key>/issues-data.md`).
* **`lib/AAPP/CommitEngine.pm`:** Authoritative `.plans` worktree commit engine (`plans_commit`), enforcing explicit pathspecs, lock retry, and attribution decoration.
* **`lib/AAPP/Health.pm`:** 8-pair mechanical integrity engine (`Pairs 1–8`, `check_fix_cells`, `check_issues_table_shape`, `check_ledger_issues`, `check_pickup_entries`).
* **`lib/AAPP/Governance.pm`:** Pluggable external lifecycle governance protocol (`check_gate`, `aapp.governance` modes `hitl | strict | lax | autonomous`, `aapp.governanceHandler` JSON over stdio).
* **`lib/AAPP/TestRepo.pm`:** Single prepared repository builder (`AAPP::TestRepo`): provisions `$sandbox/repo`, `$sandbox/origin.git`, `$sandbox/comp-non-aapp`, `$sandbox/comp-aapp`, 7 disjoint source pools (L, S, C, G, I, D, K) and Shared Docs, mock files `src/l01.py`..`src/d16.py` and `src/k01.py`..`src/k12.py`, pre-seeded plans (`P-1`..`P-35`, `P-1L`, `P-2L`, `P-290`, `P-50`..`P-62`), and issues (`#1`..`#8`, `aapp.issueId = 9`) per the single-repo schema (`D8`).
* **`lib/AAPP/Tests.pm`:** The test engine (`AAPP::Tests`): runs `t/core/*.t` and `t/verb/*.t` in contract order (`load_tests`, `select_tests`, `run_tests`, `run_file` for `prove`), one sandboxed kit and one shared pre-seeded repository per run (`make_sandbox`, delegating repository provisioning to `AAPP::TestRepo::setup_shared_repo`), `.git/aapp.log` byte-offset event slicing (`event_or_die`, `no_event_or_die`, `log_match_or_die`), 6-pointer fixture copies (`copy_fixture`), process-group watchdog (`run_isolated`, `stop_live`), and assertion helpers (`run_cmd`, `run_aapp`, `ok_cmd`, `fail_cmd`, `eq_or_die`, `match_or_die`, `true_or_die`, `file_exists_or_die`, `skip`, `lib_call`, `in_dir`, `init_repo`, `init_project`).
* **`lib/AAPP/Adoption.pm`:** Repository adoption rules catalogue, checklist sync engine (`sync_adoption_checklist`), and open-task counter (`adoption_open_count`) for `.plans/adoption.md`.
* **`lib/AAPP/GroupDocs.pm`:** Group plan `## Architecture & Codemap` section stamper (`group_docs_stamp`) and applier (`group_docs_apply`).
* **`lib/AAPP/HookDispatcher.pm` & `lib/AAPP/Attribution.pm`:** Lifecycle hook and action plugin dispatcher (`Digest::SHA` verification of `.agents/skills/aapp-hooks/registry.tsv`, process-group watchdog timeout, `AAPP_PLUGIN_LIST` / `AAPP_PLUGIN_DO` handling) and AI attribution identity/trailer/note layer.

### 🎯 Plan Lifecycle & Integration Engine (`lib/AAPP/Plan.pm`, `lib/AAPP/Runner/Plan.pm`, `lib/AAPP/Runner/Plan/*.pm`)
* **Purpose:** Implements `aapp plan` and all its subcommands (`draft`, `tdd`, `freeze`, `start`, `freeze-start`, `done`, `active`, `status`, `matrix`, `commit`, `rename`, `block`, `unblock`, `closes`, `join`, `leave`, `amend`, `abort`, `conflict-check`, `conflict-free`) over `AAPP::State`, `AAPP::CommitEngine`, and `AAPP::GroupDocs`.
* **Worktrees, Squash & Integration:** Includes `_wt_start` (plan worktree provisioning `.workspace/P<num>` and relative kit symlinks), `_sq_*` (squash on the plan branch before archive under `aapp.integrate = squash` or `plan_made_for_issue`), and `_ig_*` (parent lock `integrate/<parent>`, `aapp.autoRebase`, headless CAS fast-forward, and `_wt_quarantine` cleanup).

### 🐛 Issue & Offline Lane (`lib/AAPP/Issue.pm`, `lib/AAPP/Runner/Issue.pm`, `lib/AAPP/Runner/Issue/*.pm`, `lib/AAPP/Runner/Offline.pm`)
* **Purpose:** Implements `aapp issue` (`log`, `hotfix`, `fix`, `fix ... abort`, `queue`, `close`, `abort`, `list`, `list note <num>`, `commit`, `branch`, `note`) and `aapp offline` (`mount`, `unmount`, `on`, `off`, `status`, `sync`), including `issue_provider` plugin exchange (`aapp-issue-tracker`, `aapp-issue-note-filter`, `aapp-issue-branch`), `.workspace/fix-<num>` worktrees, mini-plans (`current/fix-<num>.md`), and single-commit fix landing (`_issue_land_fix`).

### 📊 Read-Only, Review, Pickup, Commit, Note, AI, Setup & Release Modules (`lib/AAPP/Runner/*.pm`)
* **`AAPP::Runner::Status`, `AAPP::Runner::Help`, `AAPP::Runner::Review`, `AAPP::Runner::Pickup`:** 4-pillar recovery briefing (`aapp status [short | json]`), contract-backed help (`aapp help [<verb> [full]]`), review noun with RFC/findings/fixes (`aapp review ...`), and pickup noun (`aapp pickup commit`).
* **`AAPP::Runner::Commit`, `AAPP::Runner::Note`, `AAPP::Runner::Ai`:** Plan-bound code commit helper (`commit`, `amend`, `adopt`, `land`, distinguished from `plan commit`), Git notes manager (`note [status | stage | push | pull]`), and AI attribution switchboard (`ai [status | none | lax | strict | notes | credits]`).
* **`AAPP::Runner::Init`, `Install`, `Upgrade`, `Uninstall`, `Develop`, `Sync`, `Release`, `Companion`, `Hook`, `Pause`, `Test`:** Workspace initializer (merging `.claude/settings.json` via `AAPP::JSON`; it copies no Perl modules), global installer, worktree sync (`push`, `pull`, `sync`), milestone release engine (`release`), companion repo manager (`companion`), hook/plugin inspector (`hooks`, `plugins`, `hook-test`, `hook-run`, `hook-hash`), emergency brake (`pause`, `resume`), and test runner entry (`test` -> `lib/AAPP/Tests.pm` over `t/`, from a kit checkout).

---
````
<!-- aapp-base: bc86aef5ebc8c050ca5ab5370b6dd601b5f6e26041fc222c60abda18f0c6715a -->
````markdown
## 🔒 3. Enforcement Engines & Hook Templates (`templates/`)

### 🛡️ Layer 1 Write-Time Interceptor (`templates/blast-radius-guard.sh`, `lib/AAPP/Hooks/WriteGuard.pm`)
* **Purpose:** PreToolUse hook intercepting file-writing tools (`Write`, `Edit`, `MultiEdit`, `NotebookEdit`) in Perl via `AAPP::State` and `AAPP::JSON` before disk touches (Sections 1–5: canonicalization, self-protection, external hard-deny/allowlist, G1 companion delegation, circuit breaker, workspace invariants, and active/held plan Target Files).

### 🛑 Layer 2 Commit-Time Gate (`templates/aapp-pre-commit`, `lib/AAPP/Hooks/PreCommit.pm`)
* **Purpose:** Authoritative git pre-commit gate evaluating staged changes in a single pass over `AAPP::State` (circuit breaker, blast radius, frozen §2/§4/group-section design lock, `CHANGELOG.md` rule, roadmap auto-prune, `ISSUES.md` relocation invariant, portability check, and atomic commit mode).
* **Develop Gate (`templates/aapp-pre-commit-develop`, `lib/AAPP/Hooks/PreCommitDevelop.pm`):** Seeded by `aapp develop` to verify bidirectional correspondence between `lib/verbs.tsv`, `lib/docs/verbs/*.md`, `lib/docs/core/*.md`, and `t/{verb,core}/*.t`.

### ✍️ Commit Message, Post-Commit & Post-Rewrite Hooks (`lib/AAPP/Hooks/CommitMsg.pm`, `PostCommit.pm`, `PostRewrite.pm`)
* `templates/aapp-commit-msg`: Enforces subject/line/body conciseness limits and validates `AI-*` semantic trailers via `AAPP::Attribution`.
* `templates/aapp-post-commit`: Attaches staged notes (`aapp_pending_note.<sha256>`) to `refs/notes/commits` and `refs/notes/ai`.
* `templates/aapp-post-rewrite`: Updates the bound plan's `* **Commits:**` SHAs after `git rebase` or `git commit --amend` and commits via `AAPP::CommitEngine::plans_commit`.

---
````

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `ARCHITECTURE.md` -> Sections from `## Architecture & Codemap`, applied at the group's `done`.
- [ ] `.agents/CODEMAP.md` -> Sections from `## Architecture & Codemap`, applied after the merge.

### 🛑 Out of Bounds (Do Not Touch)

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified in `.plans/pickup/perl-port-rfc.md`)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-28:** Adopted noun-first CLI architecture (lib/AAPP/Runner/) directly into Perl port, absorbing Group P-140 into P-119 (plan noun), P-117 (issue words), and P-130 (plan amend); updated codemap and member ordering.
* **2026-10-24:** Aligned log_event 3-arg signature, AAPP::Cmd::<Verb>->run(@args) class method entrypoint, P-136 %LIBRARIES switch off bash, and single-repo schema disjoint pools (L, S, C, G, I, D, K + Shared Docs, mock files `l01`..`d16`, `k01`..`k12`, plans `P-1`..`P-35`, `P-1L`, `P-2L`, `P-290`, `P-50`..`P-62`, issues `#1`..`#8`, remotes `comp-*`).
* **2026-10-24:** Added P-137 (Perl port documentation and manuals overhaul) as #21 after P-122.
* **2026-10-24:** Added P-136 (Perl test engine update & AAPP::TestRepo split per Decision D8) before test suite implementations (P-135, P-134, P-125); updated group architecture and codemap.
* **2026-10-24:** Aligned group introduction, §1 Goal, §2 Shared Decisions, §3 Members & Order (`P-133`, `P-132`, `P-116`–`P-121`, `P-131`, `P-130`, `P-135`, `P-134`, `P-125`, `P-122`, `P-112`), and `## Architecture & Codemap` with `.plans/pickup/perl-port-test-salvage-rfc.md` (`D1`–`D7`) and strict references `.plans/pickup/perl-port-single-repo-schema.md`, `.plans/pickup/perl-port-logging-events-spec.md`, and `.plans/pickup/perl-port-test-matrix-tabular-check.md`.
* **2026-10-19:** Group started: `feature/perl-port-of-the-kit` from `port/perl`.
* **2026-10-19:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-10-19:** Group drafted and refined from settled RFC (`.plans/pickup/perl-port-rfc.md`).
* **2026-10-19:** Added transitional bash/Perl coexistence inventory, core wrapper test rule, and complete `ARCHITECTURE.md` and `.agents/CODEMAP.md` replacement sections per RFC §5.1 review.

