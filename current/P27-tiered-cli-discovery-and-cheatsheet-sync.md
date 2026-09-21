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
During an operational audit of developer onboarding and beginner ergonomics, an acute discovery gap was identified:
1. **Rapid Surface Growth**: Over 12 days, AAPP's command surface expanded from 8 verbs to 36 verbs across core lifecycle, multi-worktree pause/resume, team sync, hooks, action plugins, and AI attribution.
2. **Cognitive Overload in Discovery**: `aapp help` prints a flat, unprioritized catalog of 36 commands. A newcomer encountering 36 verbs alongside 93 minutes of comprehensive documentation (`MANUAL.md`, `README.md`, `AGENTS.md`) is paralyzed by choice, unable to discern which 6 verbs constitute the actual daily development loop.
3. **Severe Cheatsheet Drift**: `CHEATSHEET.md`, intended as the one-screen quick-reference for beginners, only documents 16 of the 36 verbs (44% coverage). Critically, it completely omits the core plan lifecycle verbs (`freeze`, `start`, `done`, `plan`), failing at its primary onboarding purpose.
4. **Failure of Human-Only Release Checklists**: Attempting to guard cheatsheet drift via a manual checklist item in `release_checklist.md` failed because active feature development occurs continuously between releases. Without mechanical enforcement in test suites, documentation drifts silently.

### Architectural Goal
1. **Tiered Progressive Disclosure in `aapp help`**: Group commands by ergonomic frequency and operational moment rather than flat catalogs:
   - **Tier 1: Daily Working Loop** (`status`, `plan`, `freeze`, `start`, `done`, `active`) — the 6 core verbs.
   - **Tier 2: Setup & Lifecycle Management** (`init`, `install`, `upgrade`, `develop`, `uninstall`).
   - **Tier 3: Team Sync & Emergency Controls** (`push`, `pull`, `sync`, `pause`, `resume`).
   - **Tier 4: Extensibility & Automation (Hooks & Plugins)** (`hooks`, `hook-test`, `hook-hash`, `plugins`).
   - **Tier 5: Attribution & Metadata (AI Switchboard)** (`ai-commit`, `ai-notes`, `ai-off`, `ai-credits`, `ai-status`, `ai-note`).
2. **Canonical Verb Manifest (`lib/verbs.tsv`)**: Implement a zero-dependency, tab-separated catalog (`verb<TAB>tier<TAB>description`) as the single source of truth for CLI metadata, help generation, and documentation testing.
3. **Minimal Manifest Architecture**: Retain `aapp`'s rock-solid, static POSIX `case "$ACTION" in` dispatcher for execution safety and performance, while using `verbs.tsv` purely for help formatting and automated drift validation.
4. **Mechanical Cheatsheet Parity Enforcement**: Add automated test assertions in `tests/install_test.sh` verifying:
   - (a) Every verb in `aapp`'s dispatcher `case` statement is declared in `lib/verbs.tsv`.
   - (b) Every verb in `lib/verbs.tsv` is documented in `CHEATSHEET.md`.

---

## 🏗️ 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
- All 36 verbs remain callable with identical syntax and exit codes; only help grouping, `CHEATSHEET.md` organization, and test assertions are updated.

### 2.1 Canonical Manifest Schema (`lib/verbs.tsv`)

A zero-dependency TSV file conforming to AAPP's standard tabular conventions (matching `registry.tsv`):

```tsv
# verb	tier	description
status	daily	4-pillar context recovery briefing (Shipped, Issues, Plans, Pickup)
plan	daily	Display educational planning switchboard or query blueprints
freeze	daily	Lock blueprint blast radius & design into frozen backlog spec
start	daily	Transition frozen blueprint to in-development and bind buffer
done	daily	Archive implemented blueprint to done/ and update archival ledger
active	daily	Display or manage active execution plan buffer (swap, clear)
init	setup	Initialize or update AAPP worktrees in current repository
install	setup	Install AAPP globally into ~/.local/bin and configure PATH
upgrade	setup	Upgrade global AAPP binaries & templates from upstream
develop	setup	Link local development clone globally via symlinks
uninstall	setup	Remove global AAPP binaries and shared directories
push	sync	Push active worktrees (.plans, .agents, .githooks) to remote
pull	sync	Pull remote updates for active worktrees with non-negotiable --ff-only
sync	sync	Bi-directional sync: pull updates followed by push
pause	sync	Emergency brake: quarantine in-flight changes into stashes
resume	sync	Disengage brake, verify commit drift, and restore stashes
hooks	hooks	Audit lifecycle hook registry and verify SHA256 integrity
hook-test	hooks	Dry-run test an event trigger with mock payload
hook-hash	hooks	Compute SHA256 registration hash for hook script
plugins	hooks	Discover installed action plugins in .agents/skills/
ai-commit	ai	Switch to public, emailless semantic trailer attribution
ai-notes	ai	Switch to local-first / private git notes attribution
ai-off	ai	Disable AI attribution (pure human authoring)
ai-credits	ai	Generate or update AI Contributors block in README.md
ai-status	ai	Display current AI attribution mode and pending notes
ai-note	ai	Pre-stage customizable note buffer for next commit (--stage)
version	setup	Show installed AAPP version (-v, --version)
help	setup	Show grouped command catalog (-h, --help)
```

### 2.2 Tiered Help Rendering (`lib/cmd_help.sh`)

`lib/cmd_help.sh` parses `lib/verbs.tsv` using pure POSIX `dash`-compatible parsing, printing commands grouped into 5 clear visual tiers:

```text
Asymmetric Agent Planning Protocol (AAPP v1.0.0)

Daily Working Loop (Core):
  status        4-pillar context recovery briefing (Shipped, Issues, Plans, Pickup)
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

### 2.3 Cheatsheet Ergonomics & Organization (`CHEATSHEET.md`)

`CHEATSHEET.md` is reorganized to place the Daily Working Loop at the top of the card:
1. **Hero Table (The 6-Verb Loop)**:
   $$\text{status} \longrightarrow \text{plan} \longrightarrow \text{freeze} \longrightarrow \text{start} \longrightarrow \text{code} \longrightarrow \text{done}$$
2. **Lifecycle State Transition Matrix**: Clear mapping of status badges (`🟣 Under Review`, `📝 Refining`, `🔷 Frozen`, `⚡ In Development`, `✅ Done`).
3. **Setup & Onboarding**: `init`, `develop`, `install`, `upgrade`.
4. **Team Collaboration & Emergency Brake**: `sync`, `push`, `pull`, `pause`, `resume`.
5. **Hooks & Plugins**: Extension commands.
6. **AI Attribution Switchboard**: One-time repo configuration commands.

### 2.4 Automated Two-Way Parity Test (`tests/install_test.sh`)

Add Test 59 and Test 60 to `tests/install_test.sh`:
- **Test 59 (Dispatcher-to-Manifest Parity)**: Extracts all top-level cases from `aapp` and verifies each non-alias verb exists in `lib/verbs.tsv`.
- **Test 60 (Manifest-to-Cheatsheet Parity)**: Verifies every verb defined in `lib/verbs.tsv` appears as a backticked command in `CHEATSHEET.md`.

### 2.5 Dedicated Extension Catalog: Timing Taxonomy & Action Plugins

To resolve the scattering of hook events and plugin contracts across the manual, P-27 introduces a dedicated **Extension Catalog** structured around execution timing:

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

---

## 🔨 3. Implementation Steps & Execution Checklist

- [ ] **Phase 1: Canonical Verb Manifest**
  - [ ] Author `lib/verbs.tsv` with all 36 verbs categorized into 5 tiers with concise descriptions.
  - [ ] Ensure `aapp install` and `aapp develop` copy/link `lib/verbs.tsv` to share directory.

- [ ] **Phase 2: Tiered Help Generation (`lib/cmd_help.sh`)**
  - [ ] Refactor `lib/cmd_help.sh` to parse `lib/verbs.tsv` and output grouped sections.
  - [ ] Update `aapp help` and bare `aapp` invalid command output to reflect tiered discovery.

- [ ] **Phase 3: Cheatsheet Reorganization & Extension Matrix (`CHEATSHEET.md`)**
  - [ ] Restructure `CHEATSHEET.md` with the 6-verb Daily Working Loop prominent on the first screen.
  - [ ] Add dedicated Extension Points table (Pre/On/Post hook timing + action plugin contracts).
  - [ ] Ensure all 36 verbs are documented under their respective tier headings.

- [ ] **Phase 4: CLI Event Catalog & Discovery (`lib/cmd_hook.sh`)**
  - [ ] Update `aapp hooks` to display available lifecycle event catalog when no hooks are registered.
  - [ ] Add `aapp hooks --events` catalog flag.

- [ ] **Phase 5: Automated Parity Test Suites (`tests/install_test.sh`)**
  - [ ] Implement Test 59: assert dispatcher `case` statement matches `lib/verbs.tsv`.
  - [ ] Implement Test 60: assert all `lib/verbs.tsv` verbs exist in `CHEATSHEET.md`.
  - [ ] Run test suites and verify 100% pass rate.

- [ ] **Phase 6: Consolidated Extension Catalog in `MANUAL.md`**
  - [ ] Create dedicated "Extensibility Catalog: Lifecycle Hooks & Action Plugins" chapter in `MANUAL.md`.
  - [ ] Update `ARCHITECTURE.md` CLI metadata & extension architecture.
  - [ ] Update `CHANGELOG.md`.

---

## 🛡️ 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/verbs.tsv` -> Canonical verb manifest
- [ ] `lib/cmd_help.sh` -> Tiered help generator
- [ ] `lib/cmd_hook.sh` -> Lifecycle event catalog discovery (`--events`)
- [ ] `lib/cmd_install.sh` -> Install verbs.tsv to share directory
- [ ] `CHEATSHEET.md` -> Reorganized 36-verb tiered cheatsheet with extension matrix
- [ ] `tests/install_test.sh` -> Automated parity assertions (Tests 59 & 60)
- [ ] `MANUAL.md` -> Consolidated Extensibility Catalog & 5-tier CLI hierarchy
- [ ] `ARCHITECTURE.md` -> Document CLI metadata & extension architecture
- [ ] `CHANGELOG.md` -> Document P-27 implementation

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Protected by Pair 5 self-protection rule
- [ ] `.agents/skills/*` -> Governance skills self-protection
- [ ] `aapp` -> Dispatcher routing logic remains unchanged (only static case checked by test)
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

---

## 📦 6. Change Log & Refinement History

* **2026-09-21:** Drafted initial canonical blueprint P-27 from Issue #75 analysis. Established 5-tier progressive disclosure model, canonical `lib/verbs.tsv` manifest, cheatsheet daily loop hierarchy, and automated 2-way parity tests.
