# 🗺️ Plan P-27: Tiered CLI Discovery, Canonical Verb Manifest & Mechanical Cheatsheet Parity
* **Created:** 2026-09-21 | **Last Refined:** 2026-09-21
* **Target Issue / Milestone:** #75 *(supersedes #75 upon completion)*
* **Plan ID:** P-27
* **Status:** 🟣 Under Review
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 5. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 6. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.

---

## 🎯 1. Context & Architectural Goal

### Problem Statement
During an operational audit of developer onboarding and beginner ergonomics, an acute discovery and usability gap was identified:
1. **Rapid Surface Growth**: Over 12 days, AAPP's command surface expanded from 8 verbs to 36 verbs across core lifecycle, multi-worktree pause/resume, team sync, hooks, action plugins, and AI attribution.
2. **Cognitive Overload in Discovery**: `aapp help` prints a flat, unprioritized catalog of 36 commands. A newcomer encountering 36 verbs alongside 93 minutes of comprehensive documentation (`MANUAL.md`, `README.md`, `AGENTS.md`) is paralyzed by choice, unable to discern which 6 verbs constitute the actual daily development loop.
3. **Severe Cheatsheet Drift**: `CHEATSHEET.md`, intended as the one-screen quick-reference for beginners, only documents 16 of the 36 verbs (44% coverage). Critically, it completely omits the core plan lifecycle verbs (`freeze`, `start`, `done`, `plan`), failing at its primary onboarding purpose.
4. **Scattered Extension Points**: Lifecycle hook triggers and action plugin contracts are fragmented across distant narrative sections of `MANUAL.md`, leaving developers and agents without a central catalog of valid hook events or plugin signatures.
5. **Absence of Mechanical Blueprint Scaffolding**: Creating a plan today relies heavily on conversational slash commands (`/plan`, `/aapp-digest`). Terminal CLI help prompts dead-end with *"Use in chat"*, forcing human developers working purely in bash to manually copy templates, format filenames, and edit matrices by hand.
6. **Lack of Standalone CLI Readiness Signals**: Documentation fails to distinguish between commands that can run 100% standalone on headless/remote servers without an AI agent vs. those that are agent-assisted.

### Architectural Goal
1. **Tiered Progressive Disclosure in `aapp help`**: Group commands by ergonomic frequency and operational moment rather than flat catalogs:
   - **Tier 1: Daily Working Loop** (`status`, `draft`, `freeze`, `start`, `done`, `active`) — the 6 core lifecycle verbs.
   - **Tier 2: Setup & Lifecycle Management** (`init`, `install`, `upgrade`, `develop`, `uninstall`).
   - **Tier 3: Team Sync & Emergency Controls** (`push`, `pull`, `sync`, `pause`, `resume`).
   - **Tier 4: Extensibility & Automation (Hooks & Plugins)** (`hooks`, `hook-test`, `hook-hash`, `plugins`).
   - **Tier 5: Attribution & Metadata (AI Switchboard)** (`ai-commit`, `ai-notes`, `ai-off`, `ai-credits`, `ai-status`, `ai-note`).
2. **Canonical Verb Manifest (`lib/verbs.tsv`)**: Implement a zero-dependency, tab-separated catalog (`verb<TAB>tier<TAB>standalone<TAB>description`) as the single source of truth for CLI metadata, help generation, standalone readiness, and documentation testing.
3. **Deterministic Mechanical Scaffolding (`aapp draft <slug>`)**: Provide a pure-CLI command that allocates the next monotonic Plan ID (`aapp.planId`), copies `templates/plan-template.md`, stamps headers, and registers the incubator row in `state_matrix.md`, giving humans and agents frictionless 1-command scaffolding.
4. **Consolidated Extension Catalog & Timing Taxonomy**: Unify all 10+ hook events into a dedicated catalog structured by execution timing:
   - **Pre-Mutation Gates (`pre-*`)**: Run *before* disk mutation or Git commit; can hard abort (exit != 0).
   - **Action Delegates (`on-*`)**: Execute or replace core operations (e.g. `on-sync` transport delegate).
   - **Post-Mutation Observers (`post-*`)**: Run *after* state is securely recorded.
5. **Standalone CLI Transparency in `CHEATSHEET.md`**: Add an explicit readiness indicator column (`✅ CLI` vs `🤖 Hybrid` vs `🚧 In Progress`) so newcomers immediately see that AAPP is a first-class, standalone Unix developer tool.
6. **Mechanical Cheatsheet Parity Enforcement**: Add automated test assertions in `tests/install_test.sh` verifying:
   - (a) Every verb in `aapp`'s dispatcher `case` statement is declared in `lib/verbs.tsv`.
   - (b) Every verb in `lib/verbs.tsv` is documented in `CHEATSHEET.md`.

---

## 🏗️ 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
- All 36 existing verbs remain callable with identical syntax and exit codes. `aapp draft` is added to complete the daily lifecycle.

### 2.1 Canonical Manifest Schema (`lib/verbs.tsv`)

A zero-dependency TSV file conforming to AAPP's standard tabular conventions (matching `registry.tsv`):

```tsv
# verb	tier	standalone	description
status	daily	yes	4-pillar recovery briefing (or 'status short' for 1-line pulse)
draft	daily	yes	Scaffold blueprint from template, stamp ID & date, register in matrix
plan	daily	yes	Display educational planning switchboard or query blueprints
freeze	daily	yes	Lock blueprint blast radius & design into frozen backlog spec
start	daily	yes	Transition frozen blueprint to in-development and bind buffer
done	daily	yes	Archive implemented blueprint to done/ and update archival ledger
active	daily	yes	Display or manage active execution plan buffer (swap, clear)
init	setup	yes	Initialize or update AAPP worktrees in current repository
install	setup	yes	Install AAPP globally into ~/.local/bin and configure PATH
upgrade	setup	yes	Upgrade global AAPP binaries & templates from upstream
develop	setup	yes	Link local development clone globally via symlinks
uninstall	setup	yes	Remove global AAPP binaries and shared directories
push	sync	yes	Push active worktrees (.plans, .agents, .githooks) to remote
pull	sync	yes	Pull remote updates for active worktrees with non-negotiable --ff-only
sync	sync	yes	Bi-directional sync: pull updates followed by push
pause	sync	yes	Emergency brake: quarantine in-flight changes into stashes
resume	sync	yes	Disengage brake, verify commit drift, and restore stashes
hooks	hooks	yes	Audit lifecycle hook registry and verify SHA256 integrity
hook-test	hooks	yes	Dry-run test an event trigger with mock payload
hook-hash	hooks	yes	Compute SHA256 registration hash for hook script
plugins	hooks	yes	Discover installed action plugins in .agents/skills/
ai-commit	ai	yes	Switch to public, emailless semantic trailer attribution
ai-notes	ai	yes	Switch to local-first / private git notes attribution
ai-off	ai	yes	Disable AI attribution (pure human authoring)
ai-credits	ai	yes	Generate or update AI Contributors block in README.md
ai-status	ai	yes	Display current AI attribution mode and pending notes
ai-note	ai	yes	Pre-stage customizable note buffer for next commit (--stage)
version	setup	yes	Show installed AAPP version (-v, --version)
help	setup	yes	Show grouped command catalog (-h, --help)
```

### 2.2 Tiered Help Rendering (`lib/cmd_help.sh`)

`lib/cmd_help.sh` parses `lib/verbs.tsv` using pure POSIX `dash`-compatible parsing, printing commands grouped into 5 clear visual tiers:

```text
Asymmetric Agent Planning Protocol (AAPP v1.0.0)

Daily Working Loop (Core):
  status        4-pillar context recovery briefing (Shipped, Issues, Plans, Pickup)
  draft         Scaffold blueprint from template, stamp ID & date, register in matrix
  plan          Display educational planning switchboard or query blueprints
  freeze        Lock blueprint blast radius & design into frozen backlog spec
  start         Transition frozen blueprint to in-development and bind buffer
  done          Archive implemented blueprint to done/ and update archival ledger
  active        Display or manage active execution plan buffer (swap, clear)

Setup & Maintenance:
  init          Initialize or update AAPP worktrees in current repository
  install       Install AAPP globally into ~/.local/bin and configure PATH
  upgrade       Upgrade global AAPP binaries & templates from upstream
  develop       Link local development clone globally via symlinks
  uninstall     Remove global AAPP binaries and shared directories

Team Sync & Emergency Controls:
  push          Push active worktrees (.plans, .agents, .githooks) to remote
  pull          Pull remote updates for active worktrees with --ff-only
  sync          Bi-directional sync: pull updates followed by push
  pause         Emergency brake: quarantine in-flight changes into stashes
  resume        Disengage brake, verify commit drift, and restore stashes

Extensibility & Automation (Hooks & Plugins):
  hooks         Audit lifecycle hook registry and verify SHA256 integrity
  hook-test     Dry-run test an event trigger with mock payload
  hook-hash     Compute SHA256 registration hash for hook script
  plugins       Discover installed action plugins in .agents/skills/

Attribution & Metadata (AI Switchboard):
  ai-commit     Switch to public, emailless semantic trailer attribution
  ai-notes      Switch to local-first / private git notes attribution
  ai-off        Disable AI attribution (pure human authoring)
  ai-credits    Generate or update AI Contributors block in README.md
  ai-status     Display current AI attribution mode and pending notes
  ai-note       Pre-stage customizable note buffer for next commit
```

### 2.3 Deterministic Mechanical Scaffolding (`aapp draft <slug>`)

Implements `cmd_draft` in `lib/cmd_plan.sh` to remove clerical boilerplate for both humans and AI agents:
1. **Slug Sanitization**: Converts `<slug>` to lowercase alphanumeric hyphenated slug (`^[a-z0-9-]+$`).
2. **Monotonic Plan ID Allocation**: Calls `allocate_plan_id` to reliably increment and claim next ID `<num>`.
3. **Template Copy & Header Stamping**: Copies `templates/plan-template.md` to `.plans/current/P<num>-<slug>.md`, replacing:
   - `[Feature or Refactor Name]` $\rightarrow$ Humanized title
   - `[YYYY-MM-DD]` $\rightarrow$ Current date (`$(date +%Y-%m-%d)`)
   - `P-XX` $\rightarrow$ `P-<num>`
   - Status defaults to `🟣 Under Review`
4. **State Matrix Registration**: Appends row to `.plans/state_matrix.md` under `## 🧠 1. Human Thought & Refinement (The Incubator)`:
   `- 🟣 **P-<num>**: [\`P<num>-<slug>.md\`](current/P<num>-<slug>.md) — <title>.`
5. **Git Commit in `.plans`**: Creates clean commit: `plan(draft): scaffold P-<num> <slug>`.
6. **Editor Launch**: If invoked in an interactive human terminal (`[ -t 0 ]`) and `$EDITOR` is set, prompts to open the new file.

### 2.4 Cheatsheet Ergonomics & Standalone Readiness (`CHEATSHEET.md`)

`CHEATSHEET.md` is reorganized to place the Daily Working Loop at the top of the card with an explicit **Standalone CLI** indicator:

```markdown
### ⚡ The Daily Working Loop (Run Anytime in Shell)

| Command | Standalone CLI? | Role & Purpose |
| :--- | :---: | :--- |
| `aapp status [short]` | **✅ Yes** | 4-pillar context recovery briefing (or 'short' for 1-line remote pulse) |
| `aapp draft <slug>` | **✅ Yes** | Scaffold blueprint from template, stamp ID & date, register in matrix |
| `aapp freeze <id>` | **✅ Yes** | Lock blueprint blast radius & design into frozen backlog spec |
| `aapp start <id>` | **✅ Yes** | Bind execution buffer & transition to In Development |
| `aapp done <id>` | **✅ Yes** | Move to `done/`, update archive ledger, clear execution buffer |
| `aapp active [id]` | **✅ Yes** | Inspect, swap, or clear active plan execution buffer |
```

### 2.5 Dedicated Extension Catalog: Timing Taxonomy & Action Plugins

Centralizes hook triggers and plugin contracts structured around execution timing:

| Timing Tier | Prefix | Role & Semantics | Canonical Events |
| :--- | :---: | :--- | :--- |
| **Pre-Mutation Gates** | `pre-*` | **Gating**: Runs *before* disk mutation or Git commit. Exit code `0` = pass; non-zero (`1`, `124`) = **hard abort** with zero state change. | `pre-freeze`, `pre-start`, `pre-done`, `pre-sync` |
| **Action Delegates** | `on-*` | **Delegating**: Executes or replaces the core operation (e.g. custom transport). | `on-sync`, `on-pickup`, `on-digest` |
| **Post-Mutation Observers** | `post-*` | **Observing**: Runs *after* state is securely recorded. Broadcasts telemetry or triggers downstream sync. | `post-freeze`, `post-start`, `post-done`, `post-sync`, `post-pause`, `post-resume` |

#### Canonical Action Plugins (`.agents/skills/<name>/run`)
- **Location**: `.agents/skills/<name>/run` (extension-agnostic executable: binary, `.sh`, `.py`).
- **Standard Registry**:
  - `aapp-planid`: Central authority for monotonic Plan ID allocation in multi-contributor teams.
  - Future plugins (e.g. `aapp-review`, `aapp-notify`): Discovered via `aapp plugins`.

This taxonomy is centralized in:
1. **`CHEATSHEET.md`**: Dedicated "Extension Points" table with events, timing, and modes.
2. **`MANUAL.md`**: Consolidated "Extensibility Catalog" chapter uniting hooks, payload schemas, and plugin contracts.
3. **`aapp hooks`**: Enhanced CLI output listing all supported lifecycle events when unconfigured or via `aapp hooks --events`.

### 2.6 Automated Two-Way Parity Test (`tests/install_test.sh`)

Add Test 59 and Test 60 to `tests/install_test.sh`:
- **Test 59 (Dispatcher-to-Manifest Parity)**: Extracts all top-level cases from `aapp` and verifies each non-alias verb exists in `lib/verbs.tsv`.
- **Test 60 (Manifest-to-Cheatsheet Parity)**: Verifies every verb defined in `lib/verbs.tsv` appears as a backticked command in `CHEATSHEET.md`.

---

## 🔨 3. Implementation Steps & Execution Checklist

- [ ] **Phase 1: Canonical Verb Manifest**
  - [ ] Author `lib/verbs.tsv` with all verbs categorized into 5 tiers with standalone capability flags and descriptions.
  - [ ] Ensure `aapp install` and `aapp develop` copy/link `lib/verbs.tsv` to share directory.

- [ ] **Phase 2: Deterministic CLI Scaffolding (`lib/cmd_plan.sh`)**
  - [ ] Implement `cmd_draft <slug>` in `lib/cmd_plan.sh` automating template copy, date stamping, ID stamping, and matrix registration.
  - [ ] Wire `draft` verb in `aapp` dispatcher.

- [ ] **Phase 3: Tiered Help Generation (`lib/cmd_help.sh`)**
  - [ ] Refactor `lib/cmd_help.sh` to parse `lib/verbs.tsv` and output grouped sections.
  - [ ] Update `aapp help` and bare `aapp` invalid command output to reflect tiered discovery.

- [ ] **Phase 4: Cheatsheet Reorganization & Extension Matrix (`CHEATSHEET.md`)**
  - [ ] Restructure `CHEATSHEET.md` with the 6-verb Daily Working Loop prominent on the first screen.
  - [ ] Add standalone CLI capability column (`✅ CLI`).
  - [ ] Add dedicated Extension Points table (Pre/On/Post hook timing + action plugin contracts).
  - [ ] Ensure all verbs are documented under their respective tier headings.

- [ ] **Phase 5: CLI Event Catalog & Discovery (`lib/cmd_hook.sh`)**
  - [ ] Update `aapp hooks` to display available lifecycle event catalog when no hooks are registered.
  - [ ] Add `aapp hooks --events` catalog flag.

- [ ] **Phase 6: Automated Parity Test Suites (`tests/install_test.sh`)**
  - [ ] Implement Test 59: assert dispatcher `case` statement matches `lib/verbs.tsv`.
  - [ ] Implement Test 60: assert all `lib/verbs.tsv` verbs exist in `CHEATSHEET.md`.
  - [ ] Run test suites and verify 100% pass rate.

- [ ] **Phase 7: Documentation & Manual Sync**
  - [ ] Create dedicated "Extensibility Catalog: Lifecycle Hooks & Action Plugins" chapter in `MANUAL.md`.
  - [ ] Add "Pure-Human Terminal Workflow" chapter in `MANUAL.md`.
  - [ ] Update `ARCHITECTURE.md` CLI metadata & extension architecture.
  - [ ] Update `CHANGELOG.md`.

---

## 🛡️ 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/verbs.tsv` -> Canonical verb manifest
- [ ] `lib/cmd_help.sh` -> Tiered help generator
- [ ] `lib/cmd_plan.sh` -> Deterministic blueprint drafting (`cmd_draft`)
- [ ] `lib/cmd_hook.sh` -> Lifecycle event catalog discovery (`--events`)
- [ ] `lib/cmd_install.sh` -> Install verbs.tsv to share directory
- [ ] `aapp` -> Wire `draft` command in main dispatcher
- [ ] `CHEATSHEET.md` -> Reorganized 36-verb tiered cheatsheet with extension matrix & standalone badges
- [ ] `tests/install_test.sh` -> Automated parity assertions (Tests 59 & 60)
- [ ] `MANUAL.md` -> Consolidated Extensibility Catalog, pure-human workflow, and 5-tier CLI hierarchy
- [ ] `ARCHITECTURE.md` -> Document CLI metadata & extension architecture
- [ ] `CHANGELOG.md` -> Document P-27 implementation

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Protected by Pair 5 self-protection rule
- [ ] `.agents/skills/*` -> Governance skills self-protection
- [ ] `.plans/ISSUES.md` -> Managed via issue lifecycle
- [ ] `.plans/state_matrix.md` -> Managed via state transitions

---

## ❓ 5. Open Questions & Settled Decisions

1. **Static Case Statement vs. Dynamic Dispatch**: Should `aapp` dynamically dispatch commands from `verbs.tsv`?
   - **Decision**: **No (Keep Static Dispatcher)**. As established in architectural review, a static POSIX `case "$ACTION" in` statement is fast, syntax-checked by `bash -n`, impossible to inject, and practically unbreakable. `verbs.tsv` acts strictly as metadata for help rendering and mechanical drift tests.
2. **Ordering of Subsystems**: Which comes first: Hooks/Plugins or AI Attribution?
   - **Decision**: **Hooks & Plugins before AI Attribution**. AI attribution is a set-and-forget one-time repo configuration (`aapp ai-commit`), whereas hooks and plugins are actively used for team workflow extensions and quality gates.
3. **Treatment of Command Aliases**: How should aliases (`plan-status`, `start`, `freeze-start`) be treated in `verbs.tsv`?
   - **Decision**: Primary canonical verbs are listed in `verbs.tsv`. Shorthands and aliases are noted in the command description or separate alias column without polluting the primary 5-tier listing.
4. **Editor Launch on `aapp draft`**: Should `aapp draft` automatically invoke `$EDITOR`?
   - **Decision**: **Conditional on TTY**. If stdin is an interactive terminal (`[ -t 0 ]`) and `$EDITOR` is defined, print a prompt or launch editor. In headless, CI, or AI agent subshell invocations, output the created blueprint path to `stdout` without blocking.

---

## 📦 6. Change Log & Refinement History

* **2026-09-21 (Refinement):** Noted `aapp status [short]` positional subcommand in manifest and cheatsheet daily loop table for remote reporting and quick backlog pulse.
* **2026-09-21 (Refinement):** Refined P-27 to incorporate deterministic mechanical scaffolding (`aapp draft <slug>`), Standalone CLI capability indicator column in `lib/verbs.tsv` and `CHEATSHEET.md`, and conditional editor launch. Harmonized with P-23 pre/on/post timing taxonomy.
* **2026-09-21:** Drafted initial canonical blueprint P-27 from Issue #75 analysis. Established 5-tier progressive disclosure model, canonical `lib/verbs.tsv` manifest, cheatsheet daily loop hierarchy, and automated 2-way parity tests.
