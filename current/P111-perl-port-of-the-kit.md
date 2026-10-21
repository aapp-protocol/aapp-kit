# 🧩 Group Plan P-111: Perl Port Of The Kit
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Plan ID:** P-111
* **Changelog:** Changed: port the kit runtime, hooks and test harness from bash to Perl 5.26+ with a single-pass workspace state model, decorative-only emojis and a built-in JSON engine
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The umbrella CHANGELOG.md entry for what the whole group delivers; members keep their own entries.
     The group's `done` writes it with the ARCHITECTURE.md commit. -->
* **Status:** ⚡ In Development
* **Base:** `fa3a42e` (port/perl)
* **Feature Branch:** feature/perl-port-of-the-kit
* **Members:** P-113, P-115, P-116, P-117, P-118, P-119, P-120, P-121, P-122, P-123, P-124, P-125, P-126, P-127, P-112
* **Commits:** none
<!-- A group plan writes no code. `aapp start <group> [base <branch>]` cuts `feature/<slug>` from the parent
     branch; members are planned with `aapp draft <slug> group P-111` (or `aapp refine <id> group P-111`) and
     start from the feature branch. `aapp done <group>` refuses while a member is open, applies the sections
     below, runs the pre-done gate on the feature branch and merges it into the parent. -->

---

## 1. Goal
The kit's design holds; its cost is ~20.5k lines of bash spawning ~45k processes in a single verb suite (`1,494 s` CPU across 1,764 assertions, `sys > user` 2:1). This group ports the test harness, hooks, and CLI verbs from bash (and `python3` JSON helpers) to Perl 5.26+:
1. **Slim and modularize the test suite (`P-113`, `P-114`):** keep verb behaviour and core wrapper tests, fold `#nnn` regressions into behaviour tests, add `lib/docs/core/<module>.md` contracts, and move to the `AAPP::Tests` Perl harness (`Logsniffer::Tests` model) with per-test fixture copies, `die`-based diagnostics, parallel module workers, and an end-of-run failure recap.
2. **Single-pass Perl core and state model (`P-115`):** read `git config`, paths, active-plan buffer, `.plans/current/*.md`, plan states, and ledgers once per process (`AAPP::State`), with a single deterministic kit JSON module (`AAPP::JSON`, retiring `python3`) and decorative-only emoji normalization (`AAPP::Text`).
3. **Port hooks and verbs by slice (`P-116`–`P-121`), then remove bash (`P-122`):** hooks first (cutting process spawns on every commit across all suites), then the issue/offline lane, read-only verbs, plan lifecycle, commit/integration, and setup/release, ending with a clean break removing all legacy `.sh` libraries.

Design & measurements: `.plans/pickup/perl-port-rfc.md` (settled 2026-10-19). Merge criterion: every member archived and the `pre-done` gate green on `feature/perl-port-of-the-kit`.

## 2. Shared Decisions
- **Perl floor & dependencies:** Perl `5.26` (`use 5.026; use strict; use warnings; use utf8;`). Core modules only (`Digest::SHA`, `File::Spec`, `File::Path`, `File::Basename`, `File::Copy`, `POSIX`, `Time::HiRes`, `Cwd`). Zero CPAN dependencies.
- **One kit JSON module (`AAPP::JSON`), never `JSON::PP`:** `JSON::PP` is absent from Debian's `perl-base`, packaged apart on Fedora/RHEL, and Perl hash order / alphabetical `canonical` sorting violates the table-order contract (`docs/reference/08-output-json.md`). `AAPP::JSON` provides an ordered `@_` key-value builder (`json_obj(k1 => $v1, ...)`), 2-space pretty-printer, and reader for write-guard payloads, `.claude/settings.json`, and pause snapshots — replacing `python3` everywhere (folding in the "Perl in place of python3" pickup entry).
- **Emojis are decorative only (`AAPP::Text`):** Every parser normalizes headings, statuses, and table cells by stripping leading non-ASCII symbols/emojis and spaces via `^(?:(?=[^\x00-\x7F])[\p{S}\p{Me}\x{2139}]|[\x{200D}\x{FE0E}\x{FE0F}\s])+`. This strips all kit emojis (including `ℹ️` U+2139 `Ll`, arrows `Sm`, skin tones `Sk`, keycaps `Me`) while keeping leading ASCII symbols (`` ` ``, `$`, `~`) and accented/non-Latin letters (`Árak`, `日本語`). Emojis are emitted for human readers only and never required when reading back.
- **One workspace state read per process (`AAPP::State`):** One `git config --list -z` and one `git rev-parse --show-toplevel --git-common-dir --git-dir` per process, plus one in-memory pass over `aapp_active_plan`, `.plans/current/*.md` (headers, §3 required tests, §4 Target Files / Required Test Files / Out of Bounds), plan states, and ledgers. Hooks and verbs query `AAPP::State` in memory.
- **Strict top-level boundary & transitional coexistence during the port (`P-115`–`P-121`):** `aapp` routes ported verbs to `AAPP::Cmd::<Verb>` in Perl and unported verbs to `lib/cmd_<verb>.sh` in bash. Unported bash verbs continue sourcing `lib/*.sh` until ported; bash never shells out to Perl per-helper inside loops. `aapp init` copies `lib/AAPP/` into `.githooks/AAPP/` alongside the hooks so `.githooks/` works standalone in any clone without a build step. During `P-115`–`P-121`, the following Perl modules coexist with their legacy bash counterparts and all 30 `lib/*.sh` files plus `templates/aapp-lib.sh` are deleted in `P-122`:
  - `P-115`: `AAPP::Config`, `AAPP::Paths`, `AAPP::Text`, `AAPP::JSON`, `AAPP::Output`, `AAPP::State`, `AAPP::CommitEngine`, `AAPP::Health` coexist with `lib/aapp-lib.sh`, `lib/output.sh`, `lib/plan_states.sh`, `lib/plan_resolver.sh`, `lib/planning_health.sh`, `lib/commit_engine.sh`.
  - `P-116`: `AAPP::HookDispatcher` and `AAPP::Attribution` coexist with `lib/hook_dispatcher.sh` and `lib/attribution.sh`.
  - `P-118`: `AAPP::Adoption` and `AAPP::Cmd::Matrix` coexist with `lib/adoption.sh` and `lib/cmd_matrix.sh`.
  - `P-119`: `AAPP::GroupDocs` coexists with `lib/group_docs.sh`.
- **Tests vs. code boundary:** `P-113` and `P-114` change only tests, contracts, and the test runner (`lib/cmd_test.sh`, `.agents/hooks/test-gate.sh`, `CHEATSHEET.md`). In `P-115`–`P-122`, black-box verb test modules (`tests/AAPP/Verb/*.pm`) are completely locked and never touched; a core wrapper test module (`tests/AAPP/Core/<Module>.pm`) moves only in the member plan that ports its underlying core library from bash to `AAPP::<Module>` (`P-115`, `P-116`, `P-118`, `P-119`), switching its wrapper call from `lib/<module>.sh` to `AAPP::<Module>` while keeping identical assertions.
- **Porting parent branch & `develop` fix-only workflow:** Before starting the port, a tag is placed on `develop` at the cut point and a porting parent branch (e.g. `port/perl`) is cut from `develop`. The group is started from that parent (`aapp start P-111 base <parent>`); `aapp done P-111` merges into `<parent>`, and `<parent>` goes into `develop` by the user's hand. During the port, `develop` keeps the working bash kit and takes fixes only; fixes reach the port by merging `develop` into `<parent>`. The `aapp` that drives the port is the installed `develop` kit; no `aapp install` is run from the port branch until it lands.
- **Single source for verb syntax & behavior:** Member plans (`P-117`–`P-121`) do not restate CLI argument synopses; each names its verbs and bash files and points to `aapp help <verb> full` and `lib/docs/verbs/<verb>.md` as the behavior to keep under unchanged tests.
- **Modular test harness (`tests/AAPP/Tests.pm`):** Test modules live in `tests/AAPP/Verb/*.pm` and `tests/AAPP/Core/*.pm` (under `$AAPP_BASE/tests`, keeping runtime `lib/AAPP/` clean for `.githooks/AAPP/`). Each module is a plain list of `sub test_... { my ($self) = @_; ... }` with assertion/fixture helpers on `$self`. Test order and descriptions live in `lib/docs/verbs/<verb>.md` and `lib/docs/core/<module>.md` (`## Tests`), checked both ways by the contract test. Each module builds its initialized Git fixture once and copies it per test (rewriting the 6 `.git/worktrees` path files in-process) so any test runs alone. Each test runs in its own process group under a `60 s` default watchdog (killing `-PGID` on timeout/interrupt), modules run in parallel (`jobs <n>`), failures `die` with `file:line` + `rc`/`out`, and `not ok` lines are repeated after the summary banner (`test-gate.sh` prints from the summary line to the end).
- **Adopter plugins and hooks:** Keep the language-neutral JSON stdin + POSIX environment protocol unchanged.

## 3. Members & Order
1. **P-113** (`P113-slim-the-test-suites.md`): slim the bash suites to verb behaviour and core wrappers, fold `#nnn` regressions into behaviour tests, and author `lib/docs/core/<module>.md` contracts. Code untouched.
2. **P-127** (`P127-perl-foundation.md`): `AAPP::Constants` (declared return numbers), `AAPP::Paths`, `AAPP::Config`, `AAPP::Logger` (standard output line, `aapp.perlLogFile`), `AAPP::Runner` (signals, crash handling, exit codes), and the comment rule. Nothing in the bash kit switched.
3. **P-115** (`P115-perl-core-and-state-model.md`): `AAPP::Text` (emoji-free normalizer + wrap/cut), `AAPP::JSON` (the one JSON writer and reader, for code and tests; retiring `python3`), `AAPP::Output`, `AAPP::State`, `AAPP::CommitEngine`, `AAPP::Health`, and `aapp` hybrid verb routing, on P-127's foundation. The slimmed bash suites are its safety net.
4. **P-126** (`P126-perl-test-runner.md`): `tests/AAPP/Tests.pm` on the foundation and core, the temporary `tests/test-run`, the `output` proof module, and the two-runner gate command. Code untouched.
5. **P-123** (`P123-perl-core-test-modules.md`): core suites to `tests/AAPP/Core/*.pm`; the seven core-library modules call `AAPP::*` directly.
6. **P-124** (`P124-perl-lifecycle-verb-test-modules.md`): read-only and lifecycle verb suites to `tests/AAPP/Verb/*.pm`.
7. **P-125** (`P125-perl-remaining-verb-tests-and-switch.md`): remaining verb suites and the contract checker; `aapp test` switches to the harness; bash suites and the bridge removed.
8. **P-116** (`P116-perl-hooks-and-write-guard.md`): port `aapp-pre-commit`, `aapp-pre-commit-develop`, `aapp-commit-msg`, `aapp-post-commit`, `aapp-post-rewrite`, `blast-radius-guard.sh`, `AAPP::HookDispatcher`, and `AAPP::Attribution` to Perl over `AAPP::State` and `AAPP::JSON`.
9. **P-117** (`P117-perl-issue-and-offline-lane.md`): port `issue` (`log`, `hotfix`, `fix`, `queue`, `close`, `abort`, `list`, provider & sync helpers) and `offline` (`mount`, `unmount`, `on`, `off`, `status`, `sync`) to Perl.
10. **P-118** (`P118-perl-readonly-verbs.md`): port `status`, `matrix`, `plan-status`, `help`, and `AAPP::Adoption` to Perl.
11. **P-119** (`P119-perl-plan-lifecycle.md`): port `lib/cmd_plan.sh` (`draft`, `refine`, `tdd`, `freeze`, `start`, `freeze-start`, `done` + worktree/squash/integration engine, `active`, and `plan` `conflict-check`/`conflict-free`/`abort`) and `lib/group_docs.sh` (`AAPP::GroupDocs`) to Perl.
12. **P-120** (`P120-perl-commit-and-integration.md`): port `commit` (standard, `amend`, `adopt`, `land`), `note` (`status`, `stage`, `push`, `pull`), and `ai` (`status`, `none`, `lax`, `strict`, `notes`, `credits`) to Perl.
13. **P-121** (`P121-perl-setup-and-release.md`): port `init`, `install`, `upgrade`, `uninstall`, `develop`, `sync` (`push`, `pull`, `sync`), `release`, `companion`, `hook` (`hooks`, `plugins`, `hook-test`, `hook-run`, `hook-hash`), `pause`/`resume`, and `test` to Perl; stop copying legacy `.sh` files into `.githooks/`.
14. **P-122** (`P122-remove-bash-clean-break.md`): convert `aapp` to pure Perl, remove all 30 `lib/*.sh` files, `templates/aapp-lib.sh`, and `.githooks/*.sh` copies.
15. **P-112** (`P112-perl-port-of-the-kit-amendments.md`): group amendments member (started with the group, archived last).

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
│       ├── Logger.pm      # The one agent output line and the optional log file (no emoji in the log)
│       ├── Runner.pm      # CLI entry, signals, crash handling, exit codes
│       ├── Config.pm      # Single-pass git config reader & plan status registry (aapp.planState.*)
│       ├── Paths.pm       # Single-pass repository/worktree path resolver, kit locator (kit_dir), globs, OS & named locks
│       ├── Text.pm        # Decorative-only emoji normalizer, UTF-8 char length, wrap & cut
│       ├── JSON.pm        # Deterministic ordered JSON builder, pretty-printer, envelope & reader
│       ├── Output.pm      # Shared terminal & JSON record renderers
│       ├── State.pm       # Single-pass workspace state model (buffers, plans, ledgers, note store)
│       ├── CommitEngine.pm# Unified .plans worktree commit engine (plans_commit)
│       ├── Health.pm      # 8-pair mechanical planning health validator
│       ├── HookDispatcher.pm # Lifecycle hook & action plugin dispatcher (SHA-256 + watchdog)
│       ├── Attribution.pm # AI identity resolution, trailer decorator & staged note writer
│       ├── Adoption.pm    # Adoption checklist rules catalogue, sync engine & open-task counter
│       ├── GroupDocs.pm   # Group plan ARCHITECTURE.md / CODEMAP.md section stamper & applier
│       ├── Issue.pm       # Issue domain helpers, provider exchange, outbox & fix-worktree engine
│       ├── Plan.pm        # Plan lifecycle, worktree (_wt_*), squash (_sq_*) & integration (_ig_*)
│       ├── Hooks/         # Hook implementation modules (PreCommit, CommitMsg, PostCommit, PostRewrite, WriteGuard, PreCommitDevelop)
│       └── Cmd/           # CLI verb modules (Status, Matrix, PlanStatus, Help, Issue, Offline, Plan, Commit, Note, Ai, Init, Install, Upgrade, Uninstall, Develop, Sync, Release, Companion, Hook, Pause, Test)
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
├── tests/                 # Modular Perl test harness & suites (`AAPP::Tests`)
│   └── AAPP/              # Test runner (`Tests.pm`), `Core/*.pm`, and `Verb/*.pm` modules
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
All test suites run under `tests/AAPP/Tests.pm` (`AAPP::Tests`), which confines every test to a disposable sandbox directory under `/tmp`, builds each module's initialized Git fixture once, and clones it per `test_*` sub (rewriting the 6 `.git/worktrees` pointer files in-process in Perl) so every test is self-contained and runnable alone. Each test executes in its own process group under a `60 s` watchdog (killing `-PGID` on timeout or interrupt) with developer identity inherited and GPG signing disabled (`gpgsign false`). Test order and descriptions come from `lib/docs/verbs/<verb>.md` and `lib/docs/core/<module>.md` (`## Tests`), verified bidirectionally, and failed `not ok` lines are repeated after the summary banner.
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
* **Responsibilities:** Resolves runtime environment (`AAPP_RUNTIME=installed|local`, `AAPP_BASE`), enforces plugin re-entrancy guards (`AAPP_PLUGIN_STEP`), asserts front-door Git repository membership via `AAPP::Paths`, and dispatches verbs in-process to `AAPP::Cmd::<Verb>`.
* **Anti-Wrapper Warning:** Never write wrapper shell scripts around `aapp` commands; invoke `aapp` directly.

---
````
<!-- aapp-base: aeb41292a570d5e5073203a14d0c577c7f13772aaa984f1b8b12e12164bbcb08 -->
````markdown
## ⚙️ 2. Operational Modules & Command Libraries (`lib/`)

### 🧱 Core State, Config, Paths, Text & JSON (`lib/AAPP/`)
* **`lib/AAPP/Constants.pm`:** Every default the modules use (widths, limits, waits, retries, remote, branches, modes, kit and state folder names, JSON format version) and the declared return numbers with their exit codes; no module hard-codes a default.
* **`lib/AAPP/Util.pm`:** Central reused helpers, one implementation each: `plan_number`, `plan_sort` (plans by number, not as text).
* **`lib/AAPP/Logger.pm` & `lib/AAPP/Runner.pm`:** The one agent output line (`print_msg`, `[ TAG ] text`) and the optional log file (`aapp.perlLogFile`, UTF-8, no emoji); the CLI entry with signal handling, crash reporting and exit codes from return numbers.
* **`lib/AAPP/Config.pm`:** Single-pass `git config --list -z` loader and Plan Status Registry (`aapp.planState.*`, matching by canonical name after `AAPP::Text` emoji stripping).
* **`lib/AAPP/Paths.pm`:** Single-pass repository and worktree path resolver (`git rev-parse --show-toplevel --git-common-dir --git-dir`), the one kit locator (`kit_dir`, OS-aware), glob matcher (`glob_to_regex`, `match_pattern_list`), platform detector (`aapp_os`), and named lock engine (`aapp_lock_acquire`, `aapp_lock_release`, `aapp_lock_held`).
* **`lib/AAPP/Text.pm`:** Decorative-only emoji normalizer (`strip_leading_emoji`), UTF-8 character counter (`aapp_char_len`), line wrapper (`out_wrap`), truncator (`out_cut`), and pickup line splitter (`pickup_entry_split`).
* **`lib/AAPP/JSON.pm`:** Zero-dependency ordered JSON builder (`json_obj`, `json_list`, `json_str`, `json_strn`, `json_num`, `json_numn`, `json_bool`), 2-space pretty-printer, envelope/notices/error document builders (`docs/reference/08-output-json.md`), and JSON reader for hook/plugin payloads, `.claude/settings.json`, and pause snapshots.
* **`lib/AAPP/Output.pm`:** Shared terminal and JSON record renderers (`issue_render_terminal`, `issue_render_json`, `out_width`).
* **`lib/AAPP/State.pm`:** Single-pass workspace state loader reading `aapp_active_plan`, held plans across worktrees, `.plans/current/*.md` blueprints (headers, Status slugs, §3 required tests, §4 Target Files / Required Test Files / Out of Bounds), and the issue/archive/roadmap/offline ledgers (`ISSUES.md`, `done/000-issues-archive.md`, `issues_road_map.md`, `.offline/`) plus the external issue text store (`~/.local/state/aapp/<key>/issues-data.md`).
* **`lib/AAPP/CommitEngine.pm`:** Authoritative `.plans` worktree commit engine (`plans_commit`), enforcing explicit pathspecs, lock retry, and attribution decoration.
* **`lib/AAPP/Health.pm`:** 8-pair mechanical integrity engine (`Pairs 1–8`, `check_fix_cells`, `check_issues_table_shape`, `check_ledger_issues`, `check_pickup_entries`).
* **`lib/AAPP/Adoption.pm`:** Repository adoption rules catalogue, checklist sync engine (`sync_adoption_checklist`), and open-task counter (`adoption_open_count`) for `.plans/adoption.md`.
* **`lib/AAPP/GroupDocs.pm`:** Group plan `## Architecture & Codemap` section stamper (`group_docs_stamp`) and applier (`group_docs_apply`).
* **`lib/AAPP/HookDispatcher.pm` & `lib/AAPP/Attribution.pm`:** Lifecycle hook and action plugin dispatcher (`Digest::SHA` verification of `.agents/skills/aapp-hooks/registry.tsv`, process-group watchdog timeout, `AAPP_PLUGIN_LIST` / `AAPP_PLUGIN_DO` handling) and AI attribution identity/trailer/note layer.

### 🎯 Plan Lifecycle & Integration Engine (`lib/AAPP/Plan.pm`, `lib/AAPP/Cmd/Plan.pm`)
* **Purpose:** Implements `draft`, `refine`, `tdd`, `freeze`, `start`, `freeze-start`, `done`, `active`, `plan-status`, and `plan` (`conflict-check`, `conflict-free`, `abort`) over `AAPP::State`, `AAPP::CommitEngine`, and `AAPP::GroupDocs`.
* **Worktrees, Squash & Integration:** Includes `_wt_start` (plan worktree provisioning `.workspace/P<num>` and relative kit symlinks), `_sq_*` (squash on the plan branch before archive under `aapp.integrate = squash` or `plan_made_for_issue`), and `_ig_*` (parent lock `integrate/<parent>`, `aapp.autoRebase`, headless CAS fast-forward, and `_wt_quarantine` cleanup).

### 🐛 Issue & Offline Lane (`lib/AAPP/Issue.pm`, `lib/AAPP/Cmd/Issue.pm`, `lib/AAPP/Cmd/Offline.pm`)
* **Purpose:** Implements `aapp issue` (`log`, `hotfix`, `fix`, `fix ... abort`, `queue`, `close`, `abort`, `list`, `list note <num>`) and `aapp offline` (`mount`, `unmount`, `on`, `off`, `status`, `sync`), including `issue_provider` plugin exchange (`aapp-issue-tracker`, `aapp-issue-note-filter`, `aapp-issue-branch`), `.workspace/fix-<num>` worktrees, mini-plans (`current/fix-<num>.md`), and single-commit fix landing (`_issue_land_fix`).

### 📊 Read-Only, Commit, Note, AI, Setup & Release Modules (`lib/AAPP/Cmd/*.pm`)
* **`AAPP::Cmd::Status`, `AAPP::Cmd::Matrix`, `AAPP::Cmd::Help`:** 4-pillar recovery briefing (`aapp status [short | json]`), state matrix derivation (`aapp matrix [check]`), and contract-backed help (`aapp help [<verb> [full]]`).
* **`AAPP::Cmd::Commit`, `AAPP::Cmd::Note`, `AAPP::Cmd::Ai`:** Plan-bound commit helper (`commit`, `amend`, `adopt`, `land`), Git notes manager (`note [status | stage | push | pull]`), and AI attribution switchboard (`ai [status | none | lax | strict | notes | credits]`).
* **`AAPP::Cmd::Init`, `Install`, `Upgrade`, `Uninstall`, `Develop`, `Sync`, `Release`, `Companion`, `Hook`, `Pause`, `Test`:** Workspace initializer (merging `.claude/settings.json` via `AAPP::JSON`; it copies no Perl modules), global installer, worktree sync (`push`, `pull`, `sync`), milestone release engine (`release`), companion repo manager (`companion`), hook/plugin inspector (`hooks`, `plugins`, `hook-test`, `hook-run`, `hook-hash`), emergency brake (`pause`, `resume`), and test runner entry (`test` -> `tests/AAPP/Tests.pm`).

---
````
<!-- aapp-base: bc86aef5ebc8c050ca5ab5370b6dd601b5f6e26041fc222c60abda18f0c6715a -->
````markdown
## 🔒 3. Enforcement Engines & Hook Templates (`templates/`)

### 🛡️ Layer 1 Write-Time Interceptor (`templates/blast-radius-guard.sh`, `lib/AAPP/Hooks/WriteGuard.pm`)
* **Purpose:** PreToolUse hook intercepting file-writing tools (`Write`, `Edit`, `MultiEdit`, `NotebookEdit`) in Perl via `AAPP::State` and `AAPP::JSON` before disk touches (Sections 1–5: canonicalization, self-protection, external hard-deny/allowlist, G1 companion delegation, circuit breaker, workspace invariants, and active/held plan Target Files).

### 🛑 Layer 2 Commit-Time Gate (`templates/aapp-pre-commit`, `lib/AAPP/Hooks/PreCommit.pm`)
* **Purpose:** Authoritative git pre-commit gate evaluating staged changes in a single pass over `AAPP::State` (circuit breaker, blast radius, frozen §2/§4/group-section design lock, `CHANGELOG.md` rule, roadmap auto-prune, `ISSUES.md` relocation invariant, portability check, and atomic commit mode).
* **Develop Gate (`templates/aapp-pre-commit-develop`, `lib/AAPP/Hooks/PreCommitDevelop.pm`):** Seeded by `aapp develop` to verify bidirectional correspondence between `lib/verbs.tsv`, `lib/docs/verbs/*.md`, `lib/docs/core/*.md`, and `tests/AAPP/{Verb,Core}/*.pm`.

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
* **2026-10-19:** Group started: `feature/perl-port-of-the-kit` from `port/perl`.
* **2026-10-19:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-10-19:** Group drafted and refined from settled RFC (`.plans/pickup/perl-port-rfc.md`).
* **2026-10-19:** Added transitional bash/Perl coexistence inventory, core wrapper test rule, and complete `ARCHITECTURE.md` and `.agents/CODEMAP.md` replacement sections per RFC §5.1 review.

