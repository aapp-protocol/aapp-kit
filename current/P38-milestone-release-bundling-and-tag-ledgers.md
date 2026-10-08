# 🗺️ Plan P-38: Milestone Release Bundling, Tag Ledgers & Hook-Based Versioning
* **Created:** 2026-09-27 | **Last Refined:** 2026-10-08
* **Target Issue / Milestone:** #63
* **Plan ID:** P-38
* **Changelog:** Added: Milestone release bundling, tag ledgers, and hook-based versioning
* **Status:** 🟣 Under Review
* **Base:** none
* **Commits:** none
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Portability & Relative Path Invariant**: Zero machine-specific `file://` URIs or home directory paths in tracked repository files. All links between ledgers and release folders must be relative.
> 5. **User Documentation Sync**: Update `MANUAL.md`, `README.md`, `CHEATSHEET.md`, `ARCHITECTURE.md`, and `.agents/CODEMAP.md`.

---

## 1. Context & Architectural Goal

In active, long-lived projects governed by AAPP, `.plans/done/000-archive-ledger.md` and `.plans/done/000-issues-archive.md` accumulate hundreds of rows monotonically. This causes:
1. **Severe Context Bloat**: Every AI session inspecting the archive ledger incurs high token costs scanning hundreds of historical items.
2. **Merge Contention**: Concurrent branches touch monolithic archive tables.
3. **Loss of Release Coherence**: Discerning which specific blueprints and bug fixes shipped in a particular release tag requires cross-referencing git logs rather than reading a self-contained release artifact.
4. **Adopter Heterogeneity & Multi-Project Portability**: Different software ecosystems track versions differently (Python `pyproject.toml`, Node `package.json`, Rust `Cargo.toml`, CalVer, SemVer). The release engine must not hardcode application file mutations; it must delegate version incrementing to project-specific lifecycle hooks while accepting flexible CLI parameters. Furthermore, every project at any given moment has an arbitrary snapshot of completed plans in `.plans/done/`. The release engine must be strictly snapshot-agnostic—never assuming fixed plan counts or hardcoded plan ID ranges.

### Architectural Goal
Establish **Milestone Release Bundling** under `.plans/release/<tag>/`, **1-Row Master Ledger Rollups**, and **Hook-Delegated Versioning**:
1. **CLI Parameter & Bump Flexibility**: `aapp release <version-or-bump>` accepts explicit versions (`1.0.0` or `1.n` notation, optional `v` prefix, arbitrary suffixes like `.alpha`, `-rc.1` up to 30 chars) or standard SemVer bump tokens (`patch`, `minor`, `major`).
2. **Multi-Project Baseline Version Determination**: For third-party adopter projects without existing git tags, the initial version is determined via a clear precedence ladder: explicit CLI argument $\rightarrow$ `git describe --tags` $\rightarrow$ `git config aapp.initialVersion` $\rightarrow$ project manifest autodetection $\rightarrow$ interactive terminal prompt fallback. (For the AAPP Kit itself, the baseline version is declared in `aapp` as `1.0.0`).
3. **Hook-Based Version Increment**: Delegates project file mutation to an in-transaction `on-release` action delegate (with `pre-release` gate and `post-release` observer per P-23 taxonomy), passing version payload via Dual Delivery (`stdin` JSON + POSIX env).
4. **Snapshot-Agnostic Milestone Bundling**: Dynamically moves whatever completed blueprints reside in `.plans/done/` and resolved issues in `.plans/done/000-issues-archive.md` into an immutable `.plans/release/<tag>/` bundle.
5. **Tag Ledger & Master Rollup**: Generates `.plans/release/<tag>/000-archive-ledger.md` with full plan details, while truncating `.plans/done/000-archive-ledger.md` to a **1-line summary row per release** linking directly to the tag ledger.
6. **Rolling Active Graveyard**: Resets `.plans/done/000-issues-archive.md` to a lean table for the next unreleased cycle.
7. **Recursive Resolution**: Upgrades `lib/plan_resolver.sh` to search `.plans/done/` and `.plans/release/*/plans/` recursively without depth limits.
8. **Mandatory Pre-Flight Simulation & Safety Gate**: Every release invocation automatically runs a mandatory pre-flight simulation and verification runbook (cleanliness across active worktrees, automated test suites, pre-release gate hook, archive commit reachability, branch parity, unmerged branches advisory). Bypasses zero safety checks; requires explicit confirmation in interactive TTY or `--yes` flag for automation. Dedicated `aapp release check` / `--dry-run` runs Phase A only.

---

## 2. Technical Blueprint

### 2.1 Release Milestone Bundle Layout (`.plans/release/<tag>/`)

```text
.plans/release/<tag>/
├── plans/                               # Blueprints shipped in this release
│   ├── P10-remote-sync.md
│   ├── P36-deprecate-drop-in-and-enforce-runtime-reachability.md
│   └── ...
├── 000-archive-ledger.md                # Full, detailed plan ledger for this tag
├── 000-issues-archive.md                # Slice of defects resolved during this milestone
├── CHANGELOG.md                         # Release notes specific to this version
└── manifest.md                          # Milestone summary (tag, date, commit SHA, metrics)
```

### 2.2 Hierarchical Master Ledger Rollup (`.plans/done/000-archive-ledger.md`)

The master archive ledger at `.plans/done/000-archive-ledger.md` is structured into two clear sections:

```markdown
# 🏛️ Archival Ledger (Master Release Index)

## 🏷️ Shipped Releases
| Release | Release Date | Tag Ledger | Plans | Issues | Verification Commit | Impact Summary |
| :--- | :--- | :--- | :---: | :---: | :--- | :--- |
| `v1.0.0` | 2026-10-07 | [`v1.0.0 Ledger`](../release/v1.0.0/000-archive-ledger.md) | 45 | 40 | `ae1ff90` | Initial baseline production release |

## ⚡ Current Unreleased Cycle
| Date Completed | Plan ID | Plan File | Target Issue / Milestone | Verification Commit | Impact Summary (Repo-Relative) |
| :--- | :--- | :--- | :--- | :--- | :--- |
*(New plans completed via 'aapp done' append here until the next release)*
```

- **Scan Performance**: An agent or human inspecting the master ledger sees a high-density, 1-line overview of every shipped release and only the current in-flight completions.
- **Deep Inspection**: Following `[v1.0.0 Ledger](../release/v1.0.0/000-archive-ledger.md)` opens the unabridged plan history for that version.
- **Snapshot-Driven Counts**: The `Plans` and `Issues` tallies in each release row are dynamically computed from the exact set of blueprints and defect rows bundled at that release moment.

### 2.3 Standalone CLI Command & Interface (`aapp release`)

Add `lib/cmd_release.sh` and register `release` in `lib/verbs.tsv` under the Setup & Maintenance tier:

```bash
aapp release <version-or-bump> [--no-archive] [--dry-run] [-y|--yes]
```

#### A. Supported Version Formats & Validation Contract
The release engine strictly validates version syntax, supporting two base formats and arbitrary prerelease/build suffixes:
1. **3-Segment SemVer (Preferred)**: `X.Y.Z` or `vX.Y.Z` (e.g. `1.0.0`, `v1.2.3`).
2. **2-Segment Notation (Valid)**: `X.Y` or `vX.Y` / `1.n` (e.g. `1.0`, `v1.2`). Both variants are first-class valid inputs.
3. **Prerelease & Build Suffixes**:
   - Suffixes appended via `.` or `-` are fully supported (e.g. `1.0.1.alpha`, `1.2.beta`, `1.0.0-rc.1`, `1.1-preview.2`).
   - **Suffix Length Constraint**: The suffix string must not exceed `30` characters and consists of alphanumeric characters, hyphens, periods, or underscores.
4. **Validation Regex**:
   ```bash
   ^v?[0-9]+\.[0-9]+(\.[0-9]+)?([.-][a-zA-Z0-9_.-]{1,30})?$
   ```
   Any input that fails this regex or exceeds the suffix length constraint fails immediately with exit code 1 and concise syntax guidance.

#### B. Initial / Baseline Version Precedence Ladder (Multi-Project Support)
For the AAPP Kit itself, the version is established in `aapp` (`AAPP_VERSION="1.0.0"`). For third-party adopter projects that do not yet have an annotated git release tag (`git describe --tags` returns empty), `aapp release` resolves the baseline version via a strict priority ladder:
1. **Explicit CLI Argument**: If `<version-or-bump>` is an explicit version string (matching the format above), that version is adopted immediately.
2. **Previous Git Tag**: If `<version-or-bump>` is a SemVer bump token (`patch`, `minor`, `major`), extracts base version from `git describe --tags --abbrev=0`.
3. **Repository Configuration (`aapp.initialVersion`)**: If no git tags exist and a bump token is supplied or version is omitted, checks `git config aapp.initialVersion` (e.g. `git config aapp.initialVersion "1.0.0"`).
4. **Project Manifest Autodetection**: If unconfigured, probes standard project manifests in the root directory:
   - `package.json` (`"version": "..."`)
   - `pyproject.toml` (`version = "..."`)
   - `Cargo.toml` (`version = "..."`)
   - `VERSION` file
   - `aapp` script (`AAPP_VERSION="..."`)
5. **Interactive / Last-Resort Prompt**:
   - If standard input is an interactive terminal (`[ -t 0 ]`), prompts the user:
     `Enter initial release version [default: v1.0.0]: `
   - If non-interactive (automated agent or CI/CD), fails fast with actionable guidance:
     `❌ [Release] No previous release tag found. Specify an explicit version or set 'git config aapp.initialVersion <ver>'.`

#### C. Two-Phase Execution Pipeline: Mandatory Pre-Flight Gate & Atomic Release Mutation

Every release operation (`aapp release <version-or-bump>`) strictly executes in two distinct phases: **Phase A (Mandatory Read-Only Pre-Flight Gate & Simulation)** and **Phase B (Atomic Release Mutation)**. Pre-flight verification is strictly mandatory on every run; zero files are mutated and zero git commands are committed if any pre-flight check fails.

##### Phase A: Mandatory Read-Only Pre-Flight Gate & Simulation (Non-Mutating)
1. **Clean Worktree Verification**:
   - Asserts working tree cleanliness across all active worktrees (the active code checkout, `plans`, `agents`, `githooks`).
   - If uncommitted or unstaged changes exist: **hard abort** (`❌ [Release Refusal] Uncommitted changes detected in <worktree>. Aborting release to preserve uncommitted work`).
2. **Automated Test Suite Quality Gate**:
   - Executes `./aapp test strict quiet` (or project test runner).
   - If tests fail (exit non-zero): **hard abort** (`❌ [Release Refusal] Test suite failed. Releases require all test suites to pass 100%`).
3. **Pre-Release Lifecycle Quality Gate**:
   - Dispatches `pre-release` gate hook via `dispatch_hook` with payload `{"event":"pre-release","version":"$TARGET_VERSION","previousVersion":"$PREV_VERSION","bump":"$BUMP_TYPE"}`.
   - If `pre-release` exits non-zero: **hard abort** (`❌ [pre-release Refusal] Pre-release hook rejected release`).
4. **Archive Commit Reachability Gate (Strict Integrity)**:
   - For every completed blueprint in `.plans/done/` being bundled, extracts its recorded commit SHA (`* **Commits:** \`<sha>\``).
   - Verifies each SHA is an ancestor of `$DEV_BRANCH`:
     `git merge-base --is-ancestor "$PLAN_SHA" "$DEV_BRANCH"`
   - If any archived plan's commit is missing from `$DEV_BRANCH`: **hard abort** (`❌ [Release Refusal] Plan $PID is archived in done/, but commit $PLAN_SHA is not present in development branch $DEV_BRANCH. Run 'aapp done $PID integrate' or merge branch before releasing`).
5. **Branch Parity & Fast-Forward Gate**:
   - Resolves `$DEV_BRANCH` via `aapp_dev_branch` (`aapp.devBranch`, default `develop dev development`).
   - Resolves `$RELEASE_BRANCH` via `aapp.releaseBranch` / `aapp.protectedBranches` (default `main`).
   - On multi-branch topologies (where `$DEV_BRANCH` exists distinct from `$RELEASE_BRANCH`), asserts `$DEV_BRANCH` fast-forwards cleanly into `$RELEASE_BRANCH`:
     `git merge-base --is-ancestor "$DEV_BRANCH" "$RELEASE_BRANCH"`
   - If parity check fails: **hard abort** (`❌ [Release Refusal] Development branch $DEV_BRANCH cannot be fast-forward merged into release branch $RELEASE_BRANCH`).
   - On single-branch / trunk-based topologies (no separate `$DEV_BRANCH` distinct from `$RELEASE_BRANCH`), asserts working tree cleanliness on the current branch.
6. **Unmerged Branches Advisory Inspection (Non-Blocking)**:
   - Probes for active branches not yet merged into `$DEV_BRANCH`:
     `git branch --no-merged "$DEV_BRANCH"`
   - Displays advisory summary listing unmerged `plan/*` or `feature/*` branches that will not be part of this release.
7. **Simulation Preview & Confirmation Contract**:
   - Formats complete release simulation banner:
     - Target version transition: `$PREV_VERSION` ➔ `$TARGET_VERSION` (`$BUMP_TYPE`).
     - Bundled blueprints: count and names of plans moving from `.plans/done/` to `.plans/release/<tag>/`.
     - In-flight blueprints: plans remaining active in `.plans/current/` (carrying over).
     - Bundled defects: count of issues moving from `000-issues-archive.md`.
     - Changelog rollup preview: items under `## [Unreleased]`.
   - **Pre-flight exit / confirmation contract**:
     - If `--dry-run` flag or `check` subcommand: prints simulation and exits 0 cleanly (no mutations).
     - If interactive terminal (`[ -t 0 ]`): prompts `Proceed with release <tag>? [y/N]` (unless `--yes` / `-y` is passed).
     - If non-interactive (CI runner or autonomous agent): requires explicit `--yes` / `-y` to proceed to Phase B; without `--yes`, prints simulation and safely exits with advisory message.

##### Phase B: Atomic Release Mutation (Mutating)
Executed strictly after Phase A passes:
1. **Hook-Based Version Increment (`on-release` Action Delegate)**:
   - Dispatches `on-release` action delegate via `dispatch_hook`.
   - Passes Dual Delivery payload:
     - POSIX Env: `AAPP_RELEASE_VERSION="v1.2.0"`, `AAPP_RAW_VERSION="1.2.0"`, `AAPP_PREVIOUS_VERSION="v1.0.0"`, `AAPP_VERSION_BUMP="minor"`.
     - STDIN JSON: `{"event":"on-release","version":"v1.2.0","rawVersion":"1.2.0","previousVersion":"v1.0.0","bump":"minor"}`.
   - The project hook mutates ecosystem-specific files (e.g. `package.json`, `pyproject.toml`, `aapp:AAPP_VERSION`).
   - If the hook fails (exit non-zero), rolls back modified files and aborts before any Git commits or tags.
2. **Changelog Rollup**:
   - Extracts entries under `## [Unreleased]` from `CHANGELOG.md`.
   - Rolls up into `## [<version>] - <YYYY-MM-DD>`.
   - Pre-seeds an empty `## [Unreleased]` block above it.
3. **Snapshot-Driven Milestone Bundling (Skipped if `--no-archive` or zero plans)**:
   - Scans `.plans/done/` for all completed blueprints (`P*.md`, `plan-*.md`).
   - Creates directory `.plans/release/<tag>/plans/`.
   - Moves all completed blueprints from `.plans/done/` into `.plans/release/<tag>/plans/`.
   - Relocates resolved defects from `.plans/done/000-issues-archive.md` into `.plans/release/<tag>/000-issues-archive.md`.
   - Generates `.plans/release/<tag>/000-archive-ledger.md` listing all bundled blueprints.
   - Generates `.plans/release/<tag>/manifest.md` recording commit SHA, exact plan count, issue count, and timestamp.
4. **Master Ledger Rollup & Truncation**:
   - Appends 1-line summary row to `## 🏷️ Shipped Releases` in `.plans/done/000-archive-ledger.md` linking to `../release/<tag>/000-archive-ledger.md` with dynamic plan/issue counts.
   - Clears `## ⚡ Current Unreleased Cycle` in `.plans/done/000-archive-ledger.md`.
   - Resets `.plans/done/000-issues-archive.md` to a lean template for the next cycle.
5. **Worktree Commit**:
   - Commits `.plans` worktree: `git -C .plans commit -m "release(plans): bundle <tag> milestone and roll ledgers"`.
6. **Git Parity Merge & Tagging**:
   - If multi-branch topology: checks out `$RELEASE_BRANCH` and runs `ALLOW_MAIN_COMMIT=1 git merge --ff-only "$DEV_BRANCH"`.
   - If single-branch / trunk-based topology: commits the release rollup directly on the current release branch.
   - Creates annotated tag: `git tag -a <tag> -m "Release <tag>"`.
7. **Post-Release Notification (`post-release` Observer)**:
   - Dispatches `post-release` observer hook in `mode=notify` with release metadata payload for downstream CI/CD deployment or notification.

#### D. Branch Topology & Dynamic Development Branch Resolution
The release engine avoids hardcoding `develop` or `main`:
1. **Development Branch (`$DEV_BRANCH`)**:
   - Evaluated dynamically via `aapp_dev_branch()` in `lib/aapp-lib.sh`.
   - Queries `git config --get aapp.devBranch` (default candidates: `develop dev development`).
   - Selects the first candidate that exists locally or on a remote.
   - Allows projects to use custom development branches (e.g. `staging`, `dev`, `development`).
2. **Release Target Branch (`$RELEASE_BRANCH`)**:
   - Queries `git config aapp.releaseBranch`.
   - If unset, queries candidate list from `git config aapp.protectedBranches` (default: `main master production`), selecting the first existing branch.
   - Defaults to `main` if no config matches.
3. **Topology Detection**:
   - **Multi-Branch Topology**: If `$DEV_BRANCH` is non-empty, exists, and `$DEV_BRANCH != $RELEASE_BRANCH`: fast-forward parity verification (`git merge-base --is-ancestor "$DEV_BRANCH" "$RELEASE_BRANCH"`) and fast-forward parity merge (`git merge --ff-only "$DEV_BRANCH"`) are strictly enforced.
   - **Single-Branch / Trunk-Based Topology**: If no separate `$DEV_BRANCH` exists, or if current working branch is already `$RELEASE_BRANCH`: trunk-based execution is detected. Parity merge is skipped, and version bump/tagging executes directly on the current branch.

### 2.4 Recursive Plan Resolution (`lib/plan_resolver.sh`)

Update `resolve_plan_path` in `lib/plan_resolver.sh`:
- Scope `done` searches both `.plans/done/` and `.plans/release/*/plans/` recursively.
- `list_available_plans` and direct lookup use `find "$DIR" -name "*.md" ! -name "000-*"` instead of `-maxdepth 1`.

### 2.5 Reference Hook Sample (`examples/hooks/on-release.sh.sample`)

Provide a plug-and-play sample demonstrating multi-ecosystem version bumping:
- Node.js: `npm version --no-git-tag-version "$AAPP_RAW_VERSION"`
- Python: `sed -i -E "s/^version = .*/version = \"$AAPP_RAW_VERSION\"/" pyproject.toml`
- AAPP Kit: `sed -i -E "s/AAPP_VERSION=\".*\"/AAPP_VERSION=\"$AAPP_RAW_VERSION\"/" aapp`

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`: Zero legacy shims or dual-path directories. For any repository adopting AAPP or executing its baseline release, `aapp release` dynamically moves whatever completed plans and archived issues currently reside in `.plans/done/` into `.plans/release/<tag>/` as that repository's baseline release snapshot, without assumptions about plan count or IDs.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Resolver & Health Engine Upgrades
- [ ] Task 1.1: Update `lib/plan_resolver.sh` to search `.plans/done/` and `.plans/release/*/plans/` recursively without depth restrictions.
- [ ] Task 1.2: Update `lib/planning_health.sh` to validate Plan IDs and Recorded SHAs across tag ledgers in `.plans/release/*/000-archive-ledger.md` and check archived issues across `.plans/release/*/000-issues-archive.md`.
- [ ] Task 1.3: Add regression tests in `tests/plan_resolver_test.sh` asserting resolution of plans nested inside release tag folders.

### Phase 2: Release CLI & Lifecycle Hook Implementation (`lib/cmd_release.sh`)
- [ ] Task 2.1: Author `lib/cmd_release.sh` implementing:
  - Version validation supporting `1.0.0` (preferred) and `1.n` (valid) with suffixes up to 30 characters (`^v?[0-9]+\.[0-9]+(\.[0-9]+)?([.-][a-zA-Z0-9_.-]{1,30})?$`).
  - Baseline resolution ladder for third-party adopters (CLI arg $\rightarrow$ git tag $\rightarrow$ `git config aapp.initialVersion` $\rightarrow$ manifest autodetection $\rightarrow$ interactive prompt fallback).
  - Mandatory two-phase execution: Phase A (Mandatory Read-Only Pre-Flight Gate & Simulation) covering working tree cleanliness, automated tests (`./aapp test strict quiet`), `pre-release` gate hook, archive commit reachability in `$DEV_BRANCH`, branch parity fast-forward check, and unmerged branch advisories; Phase B (Atomic Release Mutation) gated on Phase A passing with explicit interactive confirmation or `--yes` flag.
  - Dedicated simulation mode via `--dry-run` and `aapp release check`.
  - `on-release` action delegate hook dispatch with Dual Delivery payload.
  - Snapshot-driven milestone bundle generation under `.plans/release/<tag>/` (dynamically moving whatever plans reside in `.plans/done/`).
  - Master ledger rollup in `000-archive-ledger.md` and archive truncation in `000-issues-archive.md`.
  - `CHANGELOG.md` rollup and git parity merge (`$DEV_BRANCH` ➔ `$RELEASE_BRANCH` via `aapp.devBranch`) with annotated tag.
  - `post-release` observer hook notification trigger.
- [ ] Task 2.2: Register `release` in `lib/verbs.tsv`, author `lib/docs/verbs/release.md`, and wire into `aapp` dispatcher.
- [ ] Task 2.3: Author `examples/hooks/on-release.sh.sample` in `examples/hooks/`.

### Phase 3: Snapshot-Driven Engine Verification (Isolated Test Harnesses)
- [ ] Task 3.1: Verify baseline bundling of variable plan snapshots in isolated test repositories under `tests/release_test.sh`.
- [ ] Task 3.2: Verify 1-line master archive rollup format and relative link integrity across simulated release tags.
- [ ] Task 3.3: Verify graveyard reset of `000-issues-archive.md` and `--no-archive` bypass handling in test harnesses.
*(Note: Live release execution for this repository is delegated to its dedicated personalisation hook plan targeting #58).*

### Phase 4: Test Suite & Documentation Sync
- [ ] Task 4.1: Author `tests/release_test.sh` covering:
  - Explicit version parameter parsing (`1.0.0`, `1.n`, suffixes up to 30 chars) vs SemVer bump calculation.
  - Baseline resolution precedence ladder (CLI arg, git tag, config `aapp.initialVersion`, manifest probe, prompt).
  - `pre-release`, `on-release`, `post-release` hook lifecycle execution and abort-on-failure.
  - Snapshot-driven bundle creation and master ledger truncation.
  - `--dry-run` execution with zero disk/git mutations.
- [ ] Task 4.2: Update `templates/skills/aapp-release/SKILL.md` to delegate directly to `aapp release`.
- [ ] Task 4.3: Update `MANUAL.md`, `README.md`, `CHEATSHEET.md`, `ARCHITECTURE.md`, `.agents/ARCHITECTURE.md`, and `.agents/CODEMAP.md`.
- [ ] Task 4.4: Run full regression test suite (`./aapp test strict quiet`) and update `CHANGELOG.md`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/plan_resolver.sh` -> Enable recursive resolution across release tag subdirectories
- [ ] `lib/planning_health.sh` -> Audit release tag ledgers alongside master archive
- [ ] `lib/cmd_release.sh` -> Core release orchestration, version resolution ladder, hooks, and bundle engine
- [ ] `lib/verbs.tsv` -> Register release verb
- [ ] `lib/docs/verbs/release.md` -> Release verb CLI reference documentation
- [ ] `aapp` -> Route release command in dispatcher
- [ ] `templates/skills/aapp-release/SKILL.md` -> Update release skill to invoke CLI
- [ ] `examples/hooks/on-release.sh.sample` -> Reference sample for project version bumping
- [ ] `tests/release_test.sh` -> Regression test suite for release lifecycle
- [ ] `tests/plan_resolver_test.sh` -> Add nested release plan resolution tests
- [ ] `README.md` -> Document aapp release workflow
- [ ] `MANUAL.md` -> Document milestone bundling, tag ledgers, and on-release hook
- [ ] `CHEATSHEET.md` -> Add aapp release to command table
- [ ] `ARCHITECTURE.md` -> Document milestone release bundling invariant
- [ ] `.agents/ARCHITECTURE.md` -> Record release bundling in agent architecture
- [ ] `.agents/CODEMAP.md` -> Document cmd_release.sh contracts and hooks
- [ ] `CHANGELOG.md` -> Record release command and milestone bundling

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Guard Section 2 self-protection.
- [ ] `lib/cmd_pause.sh` -> Emergency brake logic is separate.
- [ ] `lib/cmd_test.sh` -> Test runner execution is invoked as a subprocess.

---

## ❓ 5. Open Questions
* [x] **Question 1: Should master ledger link directly to the tag ledger?**  
  *Decision:* **Yes.** The master archive ledger maintains a 1-line summary row for each release tag that links directly to `.plans/release/<tag>/000-archive-ledger.md`, enabling quick scanning and deep-drill capability.
* [x] **Question 2: How should project files be updated with the new version?**  
  *Decision:* **Hook delegation via `on-release` action delegate.** Core AAPP is language-agnostic. It dispatches the target version payload to a project hook, which modifies `package.json`, `pyproject.toml`, or other project-specific files, rolling back on failure.
* [x] **Question 3: How should the CLI accept the version?**  
  *Decision:* **Parameter required (`aapp release <version-or-bump>`).** Accepts explicit version string (`v1.2.0`, `1.2`, `1.0.1.alpha`) or SemVer bump token (`patch`, `minor`, `major`). Fails fast if omitted.
* [x] **Question 4: What if no plans/issues exist to archive, or external hooks manage them?**  
  *Decision:* **Provide `--no-archive` flag and automatic zero-item resilience.** If `--no-archive` is passed or no plans/issues are found in `.plans/done/`, output a concise 1-line notice (`ℹ️  No unreleased plans or issues to bundle (skipping plan migration)`) and cleanly proceed with version bump, changelog rollup, and tagging without erroring.
* [x] **Question 5: What version formats and suffixes are supported?**  
  *Decision:* Support both `1.0.0` (preferred) and `1.n` (valid) base notations, with arbitrary prerelease/build suffixes (e.g. `1.0.1.alpha`, `1.2.beta`, `1.0.0-rc.1`) up to 30 characters, strictly validated via `^v?[0-9]+\.[0-9]+(\.[0-9]+)?([.-][a-zA-Z0-9_.-]{1,30})?$`.
* [x] **Question 6: How is initial baseline version determined for third-party adopter projects?**  
  *Decision:* Multi-project precedence ladder: explicit CLI argument $\rightarrow$ existing tag $\rightarrow$ `git config aapp.initialVersion` $\rightarrow$ manifest autodetection (`package.json`, `pyproject.toml`, `Cargo.toml`, `aapp`) $\rightarrow$ interactive terminal prompt fallback (`[ -t 0 ]`). For the AAPP Kit itself, the version is established in `aapp` as `1.0.0`.
* [x] **Question 7: How are plan counts handled during release bundling?**  
  *Decision:* Snapshot-agnostic dynamic bundling. The release command bundles all blueprints currently present in `.plans/done/` without hardcoded plan counts or ID constraints.
* [x] **Question 8: How should the development branch be determined for multi-branch parity merge?**  
  *Decision:* **Dynamically configured via `aapp.devBranch`.** The release engine never hardcodes `develop`. It calls `aapp_dev_branch` (`git config aapp.devBranch`, candidate list: `develop dev development`), matching the branch conventions of each adopter project. Similarly, the release target branch is resolved via `aapp.releaseBranch` / `aapp.protectedBranches` (defaulting to `main` / `master`). Trunk-based repositories without a distinct development branch bypass the merge step cleanly.
* [x] **Question 9: Should dry-run / pre-flight verification be mandatory before executing a release?**  
  *Decision:* **Yes, mandatory on every release.** `aapp release` always runs Phase A (Mandatory Pre-Flight Gate & Simulation) before Phase B (Mutations). It verifies working tree cleanliness, runs automated test suites, checks `pre-release` hook, verifies commit reachability of all bundled plans in `$DEV_BRANCH`, checks branch parity, and displays unmerged branch advisories. In interactive terminals, it requires human confirmation (`[y/N]`) unless `--yes` is passed; in non-interactive CI/agent runs, `--yes` is required. The `--dry-run` flag or `aapp release check` runs Phase A only.

---

## 📦 6. Change Log & Refinement History
* **2026-10-08:** Refined blueprint: enshrined mandatory pre-flight simulation and verification phase across all release runs, archive commit reachability gating, unmerged branches advisory inspection, and interactive/--yes safety confirmation.
* **2026-10-08:** Refined blueprint: resolved branch resolution strategy so the developing branch is dynamically determined from configuration (`aapp.devBranch` via `aapp_dev_branch`) rather than hardcoded `develop`, with target release branch resolved via `aapp.releaseBranch` / `aapp.protectedBranches`, supporting arbitrary adopter branch topologies and trunk-based workflows.
* **2026-10-07:** Refined blueprint: added changelog header, established multi-project baseline resolution ladder (config, manifest autodetection, prompt fallback), specified version syntax supporting both 1.0.0 (preferred) and 1.n with suffixes up to 30 chars, aligned hooks with P-23 (pre-release gate, on-release action delegate, post-release observer), and codified snapshot-agnostic dynamic bundling.
* **2026-09-27:** Added `--no-archive` flag and zero-item resilience for out-of-repo plan workflows and empty-archive releases.
* **2026-09-27:** Refined blueprint to include mandatory CLI version/bump parameter, hook-delegated version updates (`on-release`), and `--dry-run` simulation preview.
* **2026-09-27:** Initial blueprint drafted from developer directive on milestone release bundling, archive truncation, and tag ledgers.
