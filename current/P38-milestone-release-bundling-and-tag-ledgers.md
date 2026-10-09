# 🗺️ Plan P-38: Milestone Release Bundling, Tag Ledgers & Hook-Based Versioning
* **Created:** 2026-09-27 | **Last Refined:** 2026-10-09
* **Target Issue / Milestone:** #63
* **Plan ID:** P-38
* **Changelog:** Added: Milestone release bundling, tag ledgers, and hook-based versioning
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
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
5. **Tagging, Signing & Publishing Standards Across Teams**: Diverse projects require distinct tag conventions (e.g. `v1.0.0` vs bare `1.0.0`), cryptographic verification (native `tag.gpgSign`), and remote publishing workflows (`push` token vs explicit copy-paste instructions).
6. **Machine-Readable Automation Requirements**: CI/CD pipelines (GitHub Actions, GitLab CI) require structured release data (`manifest.json` alongside `manifest.md` and `json` CLI token) rather than parsing markdown.
7. **Changelog Portability & Atomicity Guarantees**: Release operations must safely rollup `CHANGELOG.md` (or bypass via `no-changelog`), and mid-release failures must never leave repositories in half-mutated, corrupted states.

### Architectural Goal
Establish **Milestone Release Bundling** under `.plans/release/<tag>/`, **1-Row Master Ledger Rollups**, and **Hook-Delegated Versioning**:
1. **CLI Parameter & Bump Flexibility (Bare Tokens Only)**: `aapp release <version-or-bump> [unverified] [yes] [check] [push] [json] [no-archive] [no-changelog]` accepts explicit versions (`1.0.0` or `1.n` notation, optional `v` prefix, arbitrary suffixes like `.alpha`, `-rc.1` up to 30 chars) or standard SemVer bump tokens (`patch`, `minor`, `major`). Strictly avoids `--flags` to honor the kit-wide bare-word convention.
2. **Multi-Project Baseline Version Determination**: For third-party adopter projects without existing git tags, the initial version is determined via a clear precedence ladder: explicit CLI argument $\rightarrow$ `git describe --tags` $\rightarrow$ `git config aapp.initialVersion` $\rightarrow$ interactive terminal prompt fallback $\rightarrow$ fail fast with guidance. Ecosystem manifest updates are delegated to lifecycle hooks.
3. **Hook-Based Version Increment**: Delegates project file mutation to an in-transaction `on-release` action delegate (with `pre-release` gate and `post-release` observer per P-23 taxonomy), passing version payload via Dual Delivery (`stdin` JSON + POSIX env).
4. **Snapshot-Agnostic Milestone Bundling**: Dynamically moves whatever completed blueprints reside in `.plans/done/` and resolved issues in `.plans/done/000-issues-archive.md` into an immutable `.plans/release/<tag>/` bundle.
5. **Tag Ledger & Master Rollup**: Generates `.plans/release/<tag>/000-archive-ledger.md` with full plan details, while truncating `.plans/done/000-archive-ledger.md` to a **1-line summary row per release** linking directly to the tag ledger.
6. **Rolling Active Graveyard**: Resets `.plans/done/000-issues-archive.md` to a lean table for the next unreleased cycle.
7. **Universal Reader & Seeder Upgrades**: Upgrades `lib/plan_resolver.sh`, `seed_plan_id` (`lib/cmd_init.sh`), `seed_issue_id` (`lib/plan_resolver.sh`), `issue_locate` (`lib/cmd_issue.sh`), `_ig_resolve_done` (`lib/cmd_plan.sh`), and `lib/planning_health.sh` (Pairs 1, 6, 8) to search `.plans/done/` and `.plans/release/*/` recursively, ensuring fresh clones and diagnostic audits never lose track of historical plans or re-allocate past IDs.
8. **Mandatory Pre-Flight Simulation & Safety Gate**: Every release invocation automatically runs a mandatory pre-flight simulation and verification runbook:
   - Cleanliness check across primary checkout and kit worktrees (`.plans`, `.agents`, `.githooks`), specifically exempting in-flight plan worktrees.
   - Quality test gate delegating to project test runner (`aapp.testCommand` / P-60 gate runner / `pre-release` hook).
   - Strict 2-tier commit reachability gate: Tier 1 ancestry (`git merge-base --is-ancestor "$PLAN_SHA" "$DEV_BRANCH"`) OR Tier 2 exact `Plan-ID: <id>` trailer (`git log "$DEV_BRANCH" --format="%(trailers:key=Plan-ID,valueonly)"`), with human override via bare token `unverified` permanently recorded in manifests.
   - Branch parity and unmerged branch advisories.
   - Bypasses zero safety checks; requires explicit confirmation in interactive TTY or `yes` token for automation. Dedicated `aapp release check` runs Phase A only.
9. **Tag Formatting & Prefix Customization**: Configurable via `git config aapp.tagPrefix` (default `"v"`, supports bare `""` or custom prefix). Automatically derives raw SemVer version and applies repo tag prefix convention.
10. **Dual Manifest Artifacts & JSON Output**: Generates both human-readable `manifest.md` and machine-readable `manifest.json` under `.plans/release/<tag>/`. Supports `json` CLI token for headless CI/CD automation.
11. **Cryptographic Tag Signing Policy**: Leverages native Git signing configuration (`tag.gpgSign`). If enabled or signing key is present, creates signed tag (`-s`); otherwise annotated tag (`-a`). Avoids redundant `aapp.signTags` config sprawl.
12. **Remote Publishing Guidance & Optional Push**: Displays a clear publication banner or automatically executes push when `push` bare token is specified (or delegates to `post-release` hook).
13. **Changelog Rollup & Bypass**: Standardizes on repository root `CHANGELOG.md` with `no-changelog` bypass token for projects without a markdown changelog.
14. **Fail-Closed Transactional Rollback Engine**: Pre-captures branch HEAD snapshots; implements fail-closed `_release_rollback()` restoring each branch ref explicitly (`git update-ref`), deleting partially created tags, and restoring pristine state on failure without masking errors.

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
├── manifest.md                          # Milestone summary (tag, date, commit SHA, metrics)
└── manifest.json                        # Machine-readable release manifest for CI/CD automation
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
aapp release <version-or-bump> [unverified] [yes] [check] [push] [json] [no-archive] [no-changelog]
```

#### A. Supported Version Formats, Tag Prefixes & Validation Contract
The release engine strictly validates version syntax, supporting two base formats, customizable tag prefixes, and arbitrary prerelease/build suffixes:
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
5. **Tag Prefix Customization (`aapp.tagPrefix`)**:
   - Evaluated via `git config aapp.tagPrefix` (default: `"v"`).
   - Supports bare SemVer tags (`git config aapp.tagPrefix ""` -> produces `1.0.0`), standard `v` prefix (`v1.0.0`), or custom prefix (e.g. `release-`).
   - The raw version (`AAPP_RAW_VERSION`) is cleanly extracted without the prefix for lifecycle hooks and manifest version numbers.
   - The final git tag (`TARGET_TAG`) is computed as `${TAG_PREFIX}${RAW_VERSION}` unless an explicit prefix was passed on the CLI.

#### B. Initial / Baseline Version Precedence Ladder (Multi-Project Support)
For the AAPP Kit itself, the version is established in `aapp` (`AAPP_VERSION="1.0.0"`). For third-party adopter projects that do not yet have an annotated git release tag (`git describe --tags` returns empty), `aapp release` resolves the baseline version via a strict priority ladder:
1. **Explicit CLI Argument**: If `<version-or-bump>` is an explicit version string (matching the format above), that version is adopted immediately.
2. **Previous Git Tag**: If `<version-or-bump>` is a SemVer bump token (`patch`, `minor`, `major`), extracts base version from `git describe --tags --abbrev=0`.
3. **Repository Configuration (`aapp.initialVersion`)**: If no git tags exist and a bump token is supplied or version is omitted, checks `git config aapp.initialVersion` (e.g. `git config aapp.initialVersion "1.0.0"`).
4. **Interactive / Last-Resort Prompt**:
   - If standard input is an interactive terminal (`[ -t 0 ]`), prompts the user:
     `Enter initial release version [default: v1.0.0]: `
   - If non-interactive (automated agent or CI/CD), fails fast with actionable guidance:
     `❌ [Release] No previous release tag found. Specify an explicit version or set 'git config aapp.initialVersion <ver>'.`

#### C. Two-Phase Execution Pipeline: Mandatory Pre-Flight Gate & Atomic Release Mutation

Every release operation strictly executes in two distinct phases: **Phase A (Mandatory Read-Only Pre-Flight Gate & Simulation)** and **Phase B (Atomic Release Mutation)**. Pre-flight verification is strictly mandatory on every run; zero files are mutated and zero git commands are committed if any pre-flight check fails.

##### Phase A: Mandatory Read-Only Pre-Flight Gate & Simulation (Non-Mutating)
1. **Clean Worktree Verification (Primary & Kit Worktrees Only)**:
   - Asserts working tree cleanliness across the primary code checkout and kit worktrees (`.plans`, `.agents`, `.githooks`).
   - Specifically exempts in-flight plan worktrees (`ig-*` / `wt-*`), allowing active plans carrying over to the next cycle to have uncommitted edits without blocking the current release.
   - If uncommitted changes exist in primary or kit worktrees: **hard abort** (`❌ [Release Refusal] Uncommitted changes detected in <worktree>. Aborting release to preserve uncommitted work`).
2. **Automated Test Suite Quality Gate (Project Delegation)**:
   - Executes the project test command configured via `git config aapp.testCommand`, the P-60 pre-done test gate runner, or `pre-release` hook handler.
   - If tests fail (exit non-zero): **hard abort** (`❌ [Release Refusal] Test suite failed. Releases require all test suites to pass 100%`).
3. **Pre-Release Lifecycle Quality Gate**:
   - Dispatches `pre-release` gate hook via `dispatch_hook` with payload `{"event":"pre-release","version":"$TARGET_VERSION","previousVersion":"$PREV_VERSION","bump":"$BUMP_TYPE"}`.
   - If `pre-release` exits non-zero: **hard abort** (`❌ [pre-release Refusal] Pre-release hook rejected release`).
4. **Tag Signing Capability Inspection**:
   - Queries native Git configuration `tag.gpgSign` and committer signing key (`user.signingkey`).
   - If enabled or key is present, tags will be cryptographically signed (`git tag -s`); otherwise annotated (`git tag -a`).
5. **Changelog Existence Gate**:
   - Checks repository root `CHANGELOG.md`.
   - If `no-changelog` token is passed, changelog checks are skipped.
   - If missing without bypass: fails fast with guidance.
6. **Archive Commit Reachability Gate (Strict 2-Tier Ladder & Override)**:
   - For every completed blueprint in `.plans/done/` being bundled:
     - **Special Case (No-Code Plans)**: If the plan records `* **Commits:** none`, reachability is bypassed with a benign informational notice (`ℹ️ Plan $PID has no recorded code commits; skipping reachability check`).
     - **Tier 1 (Git Ancestry)**: Verifies recorded commit SHA is an ancestor of `$DEV_BRANCH`:
       `git merge-base --is-ancestor "$PLAN_SHA" "$DEV_BRANCH"`
       *(Passes direct commits on dev/main, fast-forward merges, and standard 2-parent merge commits).*
     - **Tier 2 (P-55 Semantic Trailer)**: If Tier 1 fails (e.g. squashed branch), verifies `$DEV_BRANCH` contains a commit carrying `Plan-ID: $PID` in its trailers:
       `git log "$DEV_BRANCH" --format="%(trailers:key=Plan-ID,valueonly)" | grep -qw "$PID"`
       *(Passes all P-55 automated squash merges).*
     - **Human Override (`unverified` Bare Token)**: If neither Tier 1 nor Tier 2 matches, the release is rejected with actionable diagnostic guidance. If the operator explicitly passed the bare token `unverified`, the check bypasses with an advisory notice and records `"unverified": true` in both release manifests.
7. **Branch Parity & Fast-Forward Gate**:
   - Resolves `$DEV_BRANCH` via `aapp_dev_branch` (`aapp.devBranch`, default `develop dev development`).
   - Resolves `$RELEASE_BRANCH` via `aapp.releaseBranch` / `aapp.protectedBranches` (default `main`).
   - On multi-branch topologies (where `$DEV_BRANCH` exists distinct from `$RELEASE_BRANCH`), asserts `$DEV_BRANCH` fast-forwards cleanly into `$RELEASE_BRANCH`:
     `git merge-base --is-ancestor "$DEV_BRANCH" "$RELEASE_BRANCH"`
   - If parity check fails: **hard abort** (`❌ [Release Refusal] Development branch $DEV_BRANCH cannot be fast-forward merged into release branch $RELEASE_BRANCH`).
   - On single-branch / trunk-based topologies (no separate `$DEV_BRANCH` distinct from `$RELEASE_BRANCH`), asserts working tree cleanliness on the current branch.
8. **Unmerged Branches Advisory Inspection (Non-Blocking)**:
   - Probes for active branches not yet merged into `$DEV_BRANCH`:
     `git branch --no-merged "$DEV_BRANCH"`
   - Displays advisory summary listing unmerged `plan/*` or `feature/*` branches that will not be part of this release.
9. **Simulation Preview & Confirmation Contract**:
   - Formats complete release simulation banner (or JSON object if `json` token is specified):
     - Target version transition: `$PREV_VERSION` ➔ `$TARGET_VERSION` (`$BUMP_TYPE`).
     - Tag name: `$TARGET_TAG` (with signing status: signed/annotated).
     - Reachability status: verified or `unverified` override active.
     - Bundled blueprints: count and names of plans moving from `.plans/done/` to `.plans/release/<tag>/`.
     - In-flight blueprints: plans remaining active in `.plans/current/` (carrying over).
     - Bundled defects: count of issues moving from `000-issues-archive.md`.
     - Changelog rollup preview: items under `## [Unreleased]`.
   - **Pre-flight exit / confirmation contract**:
     - If `check` token: prints simulation and exits 0 cleanly (no mutations).
     - If interactive terminal (`[ -t 0 ]`): prompts `Proceed with release <tag>? [y/N]` (unless `yes` token is passed).
     - If non-interactive (CI runner or autonomous agent): requires explicit `yes` token to proceed to Phase B; without `yes`, prints simulation and safely exits with advisory message.

##### Phase B: Atomic Release Mutation (Mutating)
Executed strictly after Phase A passes:
1. **Transaction Snapshot & Trap Installation**:
   - Captures HEAD SHAs (`$DEV_SNAP`, `$RELEASE_SNAP`, `$PLANS_SNAP`) and sets fail-closed trap `_release_rollback()` ensuring clean unwinding on any mid-mutation failure (see §2.6).
2. **Hook-Based Version Increment (`on-release` Action Delegate)**:
   - Dispatches `on-release` action delegate via `dispatch_hook`.
   - Passes Dual Delivery payload:
     - POSIX Env: `AAPP_RELEASE_VERSION="$TARGET_TAG"`, `AAPP_RAW_VERSION="$RAW_VERSION"`, `AAPP_PREVIOUS_VERSION="$PREV_VERSION"`, `AAPP_VERSION_BUMP="$BUMP_TYPE"`.
     - STDIN JSON: `{"event":"on-release","tag":"$TARGET_TAG","version":"$RAW_VERSION","previousVersion":"$PREV_VERSION","bump":"$BUMP_TYPE"}`.
   - The project hook mutates ecosystem-specific files (e.g. `package.json`, `pyproject.toml`, `aapp:AAPP_VERSION`).
   - If the hook fails (exit non-zero), transactional rollback triggers immediately before any Git commits or tags.
3. **Changelog Rollup (Skipped if `no-changelog` token passed)**:
   - Extracts entries under `## [Unreleased]` in `CHANGELOG.md`.
   - Rolls up into `## [<version>] - <YYYY-MM-DD>`.
   - Pre-seeds an empty `## [Unreleased]` block above it.
4. **Snapshot-Driven Milestone Bundling (Skipped if `no-archive` or zero plans)**:
   - Scans `.plans/done/` for all completed blueprints (`P*.md`, `plan-*.md`).
   - Creates directory `.plans/release/<tag>/plans/`.
   - Moves all completed blueprints from `.plans/done/` into `.plans/release/<tag>/plans/`.
   - Relocates resolved defects from `.plans/done/000-issues-archive.md` into `.plans/release/<tag>/000-issues-archive.md`.
   - Relinks issue rows in `000-issues-archive.md` (and active ledgers) so references pointing to `done/<file>` now point to `release/<tag>/plans/<file>`.
   - Generates `.plans/release/<tag>/000-archive-ledger.md` listing all bundled blueprints.
   - Generates `.plans/release/<tag>/manifest.md` recording commit SHA, exact plan count, issue count, `unverified` status, and metrics.
   - Generates `.plans/release/<tag>/manifest.json` structured machine-readable metadata (see §2.7).
5. **Master Ledger Rollup & Truncation**:
   - Appends 1-line summary row to `## 🏷️ Shipped Releases` in `.plans/done/000-archive-ledger.md` linking to `../release/<tag>/000-archive-ledger.md` with dynamic plan/issue counts.
   - Clears `## ⚡ Current Unreleased Cycle` in `.plans/done/000-archive-ledger.md`.
   - Resets `.plans/done/000-issues-archive.md` to a lean template for the next cycle.
6. **Worktree Commit**:
   - Commits `.plans` worktree: `git -C .plans commit -m "release(plans): bundle <tag> milestone and roll ledgers"`.
7. **Git Parity Merge & Tagging**:
   - If multi-branch topology: checks out `$RELEASE_BRANCH` and runs `ALLOW_MAIN_COMMIT=1 git merge --ff-only "$DEV_BRANCH"`.
   - If single-branch / trunk-based topology: commits the release rollup directly on the current release branch.
   - Creates tag according to signing capability:
     - If signed: `git tag -s "$TARGET_TAG" -m "Release $TARGET_TAG"`
     - If annotated: `git tag -a "$TARGET_TAG" -m "Release $TARGET_TAG"`
8. **Disarm Rollback Trap**:
   - Upon successful completion of commits and tags, disarms the `_release_rollback()` trap (`trap - ERR EXIT`).
9. **Remote Publishing Guidance & Optional Push**:
   - If `push` bare token is passed:
     - Pushes release branch: `git push origin "$RELEASE_BRANCH"`
     - Pushes release tag: `git push origin "$TARGET_TAG"`
     - Pushes plans orphan branch: `git push origin plans`
   - If not pushing automatically, prints prominent publication banner:
     ```text
     ════════════════════════════════════════════════════════════════════════════
     🚀 Release <tag> successfully created locally!
     To publish release commits and tags to remote, run:
       git push origin <RELEASE_BRANCH> && git push origin <tag> && git push origin plans
     ════════════════════════════════════════════════════════════════════════════
     ```
10. **Post-Release Notification (`post-release` Observer)**:
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

### 2.4 Recursive Plan Resolution & Universal Seeder Upgrades

Upgrades across core readers to seamlessly accommodate release milestone bundles:
1. **Plan Resolver (`lib/plan_resolver.sh`)**:
   - Scope `done` and `all` searches `.plans/done/` and `.plans/release/*/plans/` recursively.
   - `list_available_plans` and direct lookups traverse nested release folders without depth limits.
2. **Plan ID Seeder (`lib/cmd_init.sh:seed_plan_id`)**:
   - Scans `current/`, `done/`, `aborted/`, and `.plans/release/*/plans/` alongside tag ledgers to ensure plan counter initialization never collides with historical plans.
3. **Issue ID Seeder (`lib/plan_resolver.sh:seed_issue_id`)**:
   - Scans `ISSUES.md`, `done/000-issues-archive.md`, and all `.plans/release/*/000-issues-archive.md` ledgers, ensuring fresh clones without a local `aapp.issueId` counter never re-issue past defect IDs.
4. **Issue Locator (`lib/cmd_issue.sh:issue_locate`) & Integration Resolver (`lib/cmd_plan.sh:_ig_resolve_done`)**:
   - Searches historical issue archives and completed blueprints inside `.plans/release/*/`.
5. **Planning Health Engine (`lib/planning_health.sh`)**:
   - Audits Pair 1 and Pair 8 issue ID integrity across all release archives.
   - Audits Pair 6 recorded SHA integrity across tag ledgers.
6. **Issue Relinking (`issue_relink`)**:
   - Relinks issue rows in archives from `done/<file>` to `release/<tag>/plans/<file>` upon bundling.

### 2.5 Reference Hook Sample (`examples/hooks/on-release.sh.sample`)

Provide a plug-and-play sample demonstrating multi-ecosystem version bumping:
- Node.js: `npm version --no-git-tag-version "$AAPP_RAW_VERSION"`
- Python: `sed -i -E "s/^version = .*/version = \"$AAPP_RAW_VERSION\"/" pyproject.toml`
- AAPP Kit: `sed -i -E "s/AAPP_VERSION=\".*\"/AAPP_VERSION=\"$AAPP_RAW_VERSION\"/" aapp`

### 2.6 Fail-Closed Transactional Rollback Engine (`_release_rollback()`)

To ensure absolute atomicity across multi-step mutations (file updates, changelog rollup, `.plans` bundle movement, git commits, and tags), `lib/cmd_release.sh` implements a fail-closed rollback coordinator:
1. **Transaction Snapshotting**:
   Before executing Step 1 of Phase B, the engine captures:
   - Git SHAs: `$DEV_SNAP` (active dev branch HEAD), `$RELEASE_SNAP` (release branch HEAD), `$PLANS_SNAP` (`.plans` orphan branch HEAD).
   - Pre-mutation working directory file list.
2. **Fail-Closed Trap Execution**:
   A POSIX trap intercepts non-zero exits without masking errors:
   ```bash
   _release_rollback() {
     local exit_code=$?
     if [ "$exit_code" -ne 0 ]; then
       echo "🚨 [Release Failure] Release aborted during Phase B. Rolling back transaction..." >&2
       if [ -n "$TARGET_TAG" ] && git rev-parse --verify "refs/tags/$TARGET_TAG" >/dev/null 2>&1; then
         git tag -d "$TARGET_TAG" >/dev/null 2>&1 || echo "⚠️  Failed to delete partial tag $TARGET_TAG" >&2
       fi
       [ -n "$DEV_SNAP" ] && git update-ref "refs/heads/$DEV_BRANCH" "$DEV_SNAP"
       [ -n "$RELEASE_SNAP" ] && git update-ref "refs/heads/$RELEASE_BRANCH" "$RELEASE_SNAP"
       [ -n "$PLANS_SNAP" ] && git -C .plans update-ref refs/heads/plans "$PLANS_SNAP"
       git checkout -f "$CURRENT_BRANCH" >/dev/null 2>&1 || true
       rm -rf ".plans/release/$TARGET_TAG" 2>/dev/null || true
       echo "✅ [Release Rollback] Repository restored cleanly to pre-release state." >&2
     fi
   }
   ```
3. **Commit Disarming**:
   Upon reaching successful completion after Step 7, disarms the rollback trap (`trap - ERR EXIT`) before printing the publication banner.

### 2.7 Machine-Readable Release Manifest Schema (`manifest.json`)

To enable seamless automation in modern CI/CD pipelines (GitHub Actions, GitLab CI, release dispatchers), every milestone bundle produces a standardized `manifest.json` alongside `manifest.md`:

```json
{
  "schemaVersion": "1.0.0",
  "tag": "v1.2.0",
  "version": "1.2.0",
  "rawVersion": "1.2.0",
  "previousVersion": "1.1.0",
  "bump": "minor",
  "releaseDate": "2026-10-08T10:00:00Z",
  "devBranch": "develop",
  "releaseBranch": "main",
  "commitSha": "4fcfd77",
  "signedTag": true,
  "unverified": false,
  "metrics": {
    "plansCount": 3,
    "issuesCount": 2
  },
  "plans": [
    {
      "id": "P-10",
      "slug": "remote-sync",
      "file": "P10-remote-sync.md",
      "commit": "a1b2c3d"
    }
  ],
  "issues": [
    {
      "id": "#42",
      "type": "CORE",
      "description": "Fix memory leak in parser"
    }
  ]
}
```
CLI invocations with the `json` token output this exact schema directly to stdout, suppressing human decoration.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`: Zero legacy shims or dual-path directories. For any repository adopting AAPP or executing its baseline release, `aapp release` dynamically moves whatever completed plans and archived issues currently reside in `.plans/done/` into `.plans/release/<tag>/` as that repository's baseline release snapshot, without assumptions about plan count or IDs.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Reader, Seeder & Health Engine Upgrades
- [ ] Task 1.1: Update `lib/plan_resolver.sh` to search `.plans/done/` and `.plans/release/*/plans/` recursively without depth restrictions across all scopes (`done`, `all`).
- [ ] Task 1.2: Upgrade Plan ID and Issue ID seeders:
  - Update `seed_plan_id` in `lib/cmd_init.sh` to scan `.plans/release/*/plans/` alongside tag ledgers and `done/`.
  - Update `seed_issue_id` in `lib/plan_resolver.sh` to scan `.plans/release/*/000-issues-archive.md` alongside `done/000-issues-archive.md` and `ISSUES.md`.
- [ ] Task 1.3: Update `issue_locate` in `lib/cmd_issue.sh` and `_ig_resolve_done` in `lib/cmd_plan.sh` to resolve historical defects and plans inside `.plans/release/*/`.
- [ ] Task 1.4: Update `lib/planning_health.sh` to validate Plan IDs and Recorded SHAs across tag ledgers in `.plans/release/*/000-archive-ledger.md` and check archived issues across `.plans/release/*/000-issues-archive.md` (Pairs 1, 6, 8).
- [ ] Task 1.5: Add regression tests in `tests/plan_resolver_test.sh` asserting resolution of plans and seeding of IDs from release bundles.

### Phase 2: Core Release CLI & Pre-Flight Gate (`lib/cmd_release.sh`)
- [ ] Task 2.1: Author `lib/cmd_release.sh` implementing:
  - Version validation supporting `1.0.0` (preferred) and `1.n` (valid) with suffixes up to 30 characters (`^v?[0-9]+\.[0-9]+(\.[0-9]+)?([.-][a-zA-Z0-9_.-]{1,30})?$`), plus tag prefix customization via `git config aapp.tagPrefix`.
  - Baseline resolution ladder for third-party adopters (CLI arg $\rightarrow$ git tag $\rightarrow$ `git config aapp.initialVersion` $\rightarrow$ interactive prompt fallback).
  - Mandatory Phase A (Read-Only Pre-Flight Gate & Simulation):
    - Primary and kit worktree cleanliness check (exempting in-flight plan worktrees).
    - Project test suite quality gate (delegating to `aapp.testCommand`, P-60 test gate runner, or `pre-release` hook).
    - `pre-release` lifecycle quality gate hook dispatch.
    - Tag signing capability inspection via native `tag.gpgSign`.
    - Changelog existence gate on root `CHANGELOG.md` (bypassable via `no-changelog` token).
    - Strict 2-tier archive commit reachability gate (Tier 1 ancestry `merge-base` OR Tier 2 `Plan-ID: <id>` trailer; bypassable via human override bare token `unverified`; benign notice on `Commits: none`).
    - Branch parity fast-forward verification and unmerged branches advisory inspection.
    - Simulation preview output with `check` bare token exit contract and interactive `[y/N]` / `yes` token safety gate.
  - Fail-closed transactional rollback coordinator (`_release_rollback()`) with per-branch `git update-ref` unwinding.
- [ ] Task 2.2: Register `release` in `lib/verbs.tsv`, author `lib/docs/verbs/release.md`, and wire into `aapp` dispatcher.

### Phase 3: Milestone Bundling & Manifest Generation Engine
- [ ] Task 3.1: Author Phase B (Atomic Release Mutation) in `lib/cmd_release.sh`:
  - `on-release` action delegate hook dispatch with Dual Delivery payload.
  - Changelog rollup in root `CHANGELOG.md` (rolling `## [Unreleased]` into `## [<version>] - <YYYY-MM-DD>`).
  - Snapshot-driven milestone bundle generation under `.plans/release/<tag>/` including `plans/`, `000-archive-ledger.md`, `000-issues-archive.md`, `manifest.md`, and `manifest.json` (recording `unverified` status).
  - Issue relinking: rewrite issue row links in `000-issues-archive.md` pointing to `done/<file>` to `release/<tag>/plans/<file>`.
  - Master ledger rollup in `000-archive-ledger.md` (1-line summary row per release) and graveyard reset in `000-issues-archive.md`.
  - Worktree commit in `.plans` and Git parity merge (`$DEV_BRANCH` ➔ `$RELEASE_BRANCH`).
  - Tag creation with `-s` or `-a` according to `tag.gpgSign`.
  - Remote publishing guidance banner and optional automated push (`push` bare token).
  - `post-release` observer hook notification trigger.
- [ ] Task 3.2: Author `examples/hooks/on-release.sh.sample` demonstrating multi-ecosystem version bumping.

### Phase 4: Test Suite & Documentation Sync
- [ ] Task 4.1: Author `tests/release_test.sh` covering:
  - Explicit version parameter parsing (`1.0.0`, `1.n`, suffixes up to 30 chars) vs SemVer bump calculation.
  - Bare token modifiers (`unverified`, `yes`, `check`, `push`, `json`, `no-archive`, `no-changelog`).
  - Tag prefix customization (`aapp.tagPrefix`) and native tag signing (`tag.gpgSign`).
  - Baseline resolution precedence ladder (CLI arg, git tag, config `aapp.initialVersion`, prompt).
  - 2-tier reachability gate (ancestry, `Plan-ID` trailer, `unverified` override, `Commits: none`).
  - Worktree cleanliness scoping (in-flight plan worktrees exempt).
  - Snapshot-driven bundle creation, `manifest.json` schema validation, and 1-line master ledger truncation.
  - Fail-closed transactional rollback restoring refs upon simulated hook failure.
- [ ] Task 4.2: Update `templates/skills/aapp-release/SKILL.md` to delegate directly to `aapp release`.
- [ ] Task 4.3: Update `MANUAL.md`, `README.md`, `CHEATSHEET.md`, `ARCHITECTURE.md`, `.agents/ARCHITECTURE.md`, and `.agents/CODEMAP.md`.
- [ ] Task 4.4: Run full regression test suite (`./aapp test strict quiet`) and update `CHANGELOG.md`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/plan_resolver.sh` -> Enable recursive resolution across release tag subdirectories; scan release archives in `seed_issue_id`
- [ ] `lib/planning_health.sh` -> Audit release tag ledgers and archives alongside master archive (Pairs 1, 6, 8)
- [ ] `lib/cmd_init.sh` -> Update `seed_plan_id` to scan release tag plans and ledgers
- [ ] `lib/cmd_issue.sh` -> Update `issue_locate` to resolve archived defects in release folders
- [ ] `lib/cmd_plan.sh` -> Update `_ig_resolve_done` to resolve release plans and relink issue rows upon bundling
- [ ] `lib/cmd_release.sh` -> Core release orchestration, reachability ladder, hooks, rollback, and bundle engine
- [ ] `lib/verbs.tsv` -> Register release verb
- [ ] `lib/docs/verbs/release.md` -> Release verb CLI reference documentation
- [ ] `aapp` -> Route release command in dispatcher
- [ ] `templates/skills/aapp-release/SKILL.md` -> Update release skill to invoke CLI
- [ ] `examples/hooks/on-release.sh.sample` -> Reference sample for project version bumping
- [ ] `tests/release_test.sh` -> Regression test suite for release lifecycle
- [ ] `tests/plan_resolver_test.sh` -> Add nested release plan resolution and seeder tests
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
  *Decision:* **Provide `no-archive` bare token and automatic zero-item resilience.** If `no-archive` is passed or no plans/issues are found in `.plans/done/`, output a concise 1-line notice (`ℹ️  No unreleased plans or issues to bundle (skipping plan migration)`) and cleanly proceed with version bump, changelog rollup, and tagging without erroring.
* [x] **Question 5: What version formats and suffixes are supported?**  
  *Decision:* Support both `1.0.0` (preferred) and `1.n` (valid) base notations, with arbitrary prerelease/build suffixes (e.g. `1.0.1.alpha`, `1.2.beta`, `1.0.0-rc.1`) up to 30 characters, strictly validated via `^v?[0-9]+\.[0-9]+(\.[0-9]+)?([.-][a-zA-Z0-9_.-]{1,30})?$`.
* [x] **Question 6: How is initial baseline version determined for third-party adopter projects?**  
  *Decision:* Multi-project precedence ladder: explicit CLI argument $\rightarrow$ existing tag $\rightarrow$ `git config aapp.initialVersion` $\rightarrow$ interactive terminal prompt fallback (`[ -t 0 ]`). Ecosystem manifest autodetection is delegated to hooks. For the AAPP Kit itself, the version is established in `aapp` as `1.0.0`.
* [x] **Question 7: How are plan counts handled during release bundling?**  
  *Decision:* Snapshot-agnostic dynamic bundling. The release command bundles all blueprints currently present in `.plans/done/` without hardcoded plan counts or ID constraints.
* [x] **Question 8: How should the development branch be determined for multi-branch parity merge?**  
  *Decision:* **Dynamically configured via `aapp.devBranch`.** The release engine never hardcodes `develop`. It calls `aapp_dev_branch` (`git config aapp.devBranch`, candidate list: `develop dev development`), matching the branch conventions of each adopter project. Similarly, the release target branch is resolved via `aapp.releaseBranch` / `aapp.protectedBranches` (defaulting to `main` / `master`). Trunk-based repositories without a distinct development branch bypass the merge step cleanly.
* [x] **Question 9: Should dry-run / pre-flight verification be mandatory before executing a release?**  
  *Decision:* **Yes, mandatory on every release.** `aapp release` always runs Phase A (Mandatory Pre-Flight Gate & Simulation) before Phase B (Mutations). It verifies working tree cleanliness (exempting in-flight plan worktrees), runs automated test suites via project runner, checks `pre-release` hook, verifies commit reachability of all bundled plans in `$DEV_BRANCH`, checks branch parity, and displays unmerged branch advisories. In interactive terminals, it requires human confirmation (`[y/N]`) unless `yes` is passed; in non-interactive CI/agent runs, `yes` is required. Dedicated `aapp release check` runs Phase A only.
* [x] **Question 10: How are tag prefixes formatted and configured?**  
  *Decision:* **Configurable via `git config aapp.tagPrefix` (default `"v"`).** Supports empty string `""` for bare SemVer (e.g. `1.2.0`) or custom prefixes like `release-`. The engine separates raw SemVer version (`AAPP_RAW_VERSION`) from formatted git tag (`TARGET_TAG`).
* [x] **Question 11: Should machine-readable release artifacts be generated for CI/CD pipelines?**  
  *Decision:* **Yes.** Every release milestone produces both `manifest.md` (for human review) and `manifest.json` (for automated CI/CD pipelines such as GitHub Actions/GitLab CI) recording version, git SHA, date, branch metadata, `unverified` status, and list of bundled plans and issues. The CLI token `json` outputs this schema directly to stdout.
* [x] **Question 12: How should git tag cryptographic signing be governed?**  
  *Decision:* **Leverages native Git configuration `tag.gpgSign`.** If enabled or signing key is present, signs with `git tag -s`; otherwise falls back to annotated tag `git tag -a`. Drops redundant `aapp.signTags` config key.
* [x] **Question 13: How should post-release remote publishing be handled?**  
  *Decision:* **Safety-first default with copy-paste publication banner and optional `push` bare token.** By default, local release commits and tags are not pushed automatically; the runner prints a clear, copy-pasteable publication banner (`git push origin <branch> && git push origin <tag> && git push origin plans`). When `push` is passed, pushes automatically.
* [x] **Question 14: How should changelog file path and format be handled?**  
  *Decision:* **Standard repository root `CHANGELOG.md` with `no-changelog` bypass.** Gracefully generates release blocks even if `## [Unreleased]` is absent, and allows complete bypass via `no-changelog`. Eliminates single-command `aapp.changelogPath` sprawl.
* [x] **Question 15: How is atomicity guaranteed if a mutation fails midway during Phase B?**  
  *Decision:* **Pre-mutation transaction snapshot and fail-closed rollback handler (`_release_rollback()`).** Captures initial Git SHAs of the active branch, release branch, and `.plans` worktree before mutations begin. If any hook or git command fails, the trap rolls back modified files, cleans untracked release files, deletes partially created tags, and restores HEADs back to their pre-release snapshot via explicit `git update-ref`.
* [x] **Question 16: How are squash-integrated and legacy plans verified in the reachability gate?**  
  *Decision:* **2-Tier ladder with `unverified` human override.** Tier 1 verifies ancestry via `git merge-base --is-ancestor`. Tier 2 checks exact `Plan-ID: <id>` trailer line on `$DEV_BRANCH` (`%(trailers:key=Plan-ID,valueonly)`). If neither matches, fails closed unless bare token `unverified` is explicitly passed. Plans with `* **Commits:** none` pass with a benign notice.
* [x] **Question 17: How are plan and issue ID counters protected against ledger truncation collisions?**  
  *Decision:* **Universal seeder and reader upgrades.** `seed_plan_id` (`lib/cmd_init.sh`) and `seed_issue_id` (`lib/plan_resolver.sh`) scan `.plans/release/*/` alongside active and archived tables, ensuring fresh clones without local Git counters never re-allocate historical IDs.

---

## 📦 6. Change Log & Refinement History
* **2026-10-09:** Refined blueprint following RFC review settlement: aligned with `microcommits` mode, formalized strict 2-tier commit reachability ladder (ancestry or exact `Plan-ID` trailer) with `unverified` bare token override and `Commits: none` exemption; implemented fail-closed per-branch `git update-ref` rollback; upgraded `seed_plan_id`, `seed_issue_id`, `issue_locate`, `_ig_resolve_done`, and `planning_health.sh` across `.plans/release/*/`; standardized on bare token modifiers (`unverified`, `yes`, `check`, `push`, `json`, `no-archive`, `no-changelog`); pruned redundant Git config keys (`aapp.signTags`, `aapp.releasePush`, `aapp.changelogPath`); delegated test quality gate to project test runners; and scoped worktree cleanliness checks to primary and kit checkouts.
* **2026-10-08:** Refined blueprint for universal adopter projects: added tag prefix customization (`aapp.tagPrefix`), dual release manifests (`manifest.md` and `manifest.json`), publication guidance banner, and Phase B transactional rollback handler.
* **2026-10-08:** Refined blueprint: enshrined mandatory pre-flight simulation and verification phase across all release runs, archive commit reachability gating, unmerged branches advisory inspection, and safety confirmation.
* **2026-10-08:** Refined blueprint: resolved branch resolution strategy so the developing branch is dynamically determined from configuration (`aapp.devBranch` via `aapp_dev_branch`) rather than hardcoded `develop`, with target release branch resolved via `aapp.releaseBranch` / `aapp.protectedBranches`, supporting arbitrary adopter branch topologies and trunk-based workflows.
* **2026-10-07:** Refined blueprint: added changelog header, established multi-project baseline resolution ladder, specified version syntax supporting both 1.0.0 (preferred) and 1.n with suffixes up to 30 chars, aligned hooks with P-23 (pre-release gate, on-release action delegate, post-release observer), and codified snapshot-agnostic dynamic bundling.
* **2026-09-27:** Added `--no-archive` flag and zero-item resilience for out-of-repo plan workflows and empty-archive releases.
* **2026-09-27:** Refined blueprint to include mandatory CLI version/bump parameter, hook-delegated version updates (`on-release`), and `--dry-run` simulation preview.
* **2026-09-27:** Initial blueprint drafted from developer directive on milestone release bundling, archive truncation, and tag ledgers.
