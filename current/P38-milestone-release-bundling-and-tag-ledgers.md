# 🗺️ Plan P-38: Milestone Release Bundling, Tag Ledgers & Hook-Based Versioning
* **Created:** 2026-09-27 | **Last Refined:** 2026-09-27
* **Target Issue / Milestone:** #58, #63
* **Plan ID:** P-38
* **Status:** 🟣 Under Review
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
4. **Adopter Heterogeneity**: Different software ecosystems track versions differently (Python `pyproject.toml`, Node `package.json`, Rust `Cargo.toml`, CalVer, SemVer). The release engine must not hardcode application file mutations; it must delegate version incrementing to project-specific lifecycle hooks while accepting flexible CLI parameters.

### Architectural Goal
Establish **Milestone Release Bundling** under `.plans/release/<tag>/`, **1-Row Master Ledger Rollups**, and **Hook-Delegated Versioning**:
1. **CLI Parameter & Bump Flexibility**: `aapp release <version-or-bump>` accepts explicit version tags (`v1.2.0`, `1.2.0`, `2026.09.1`) or standard SemVer bump tokens (`patch`, `minor`, `major`).
2. **Hook-Based Version Increment**: Delegates project file mutation to an `on-release` (or `pre-release`) lifecycle hook, passing version payload via Dual Delivery (`stdin` JSON + POSIX env).
3. **Milestone Bundling**: Moves completed blueprints in `.plans/done/` and resolved issues in `.plans/done/000-issues-archive.md` into an immutable `.plans/release/<tag>/` bundle.
4. **Tag Ledger & Master Rollup**: Generates `.plans/release/<tag>/000-archive-ledger.md` with full plan details, while truncating `.plans/done/000-archive-ledger.md` to a **1-line summary row per release** linking directly to the tag ledger.
5. **Rolling Active Graveyard**: Resets `.plans/done/000-issues-archive.md` to a lean table for the next unreleased cycle.
6. **Recursive Resolution**: Upgrades `lib/plan_resolver.sh` to search `.plans/done/` and `.plans/release/*/plans/` recursively without depth limits.
7. **Simulation & Safety**: Provides `--dry-run` preview, pre-flight test gating (`aapp test strict quiet`), clean worktree enforcement, and branch parity verification (`develop` ➔ `main`).

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
| `v1.0.0` | 2026-09-27 | [`v1.0.0 Ledger`](../release/v1.0.0/000-archive-ledger.md) | 30 | 34 | `ae1ff90` | Initial production release of AAPP Protocol |

## ⚡ Current Unreleased Cycle
| Date Completed | Plan ID | Plan File | Target Issue / Milestone | Verification Commit | Impact Summary (Repo-Relative) |
| :--- | :--- | :--- | :--- | :--- | :--- |
*(New plans completed via 'aapp done' append here until the next release)*
```

- **Scan Performance**: An agent or human inspecting the master ledger sees a high-density, 1-line overview of every shipped release and only the current in-flight completions.
- **Deep Inspection**: Following `[v1.0.0 Ledger](../release/v1.0.0/000-archive-ledger.md)` opens the unabridged plan history for that version.

### 2.3 Standalone CLI Command & Interface (`aapp release`)

Add `lib/cmd_release.sh` and register `release` in `lib/verbs.tsv` under the Setup & Maintenance tier:

```bash
aapp release <version-or-bump> [--no-archive] [--dry-run] [-y|--yes]
```

**Argument Parsing & Resolution:**
- **Explicit Version**: If `<version-or-bump>` matches `v?[0-9]+\.[0-9]+.*` or arbitrary tag strings (e.g. `2026.09.1`), normalizes tag to `vX.Y.Z` and raw version to `X.Y.Z`.
- **SemVer Bump Token**: If `patch`, `minor`, or `major`, extracts previous tag from `git describe --tags --abbrev=0` (or `v1.0.0` default) and computes next version.
- **`--no-archive` (or `no-archive`)**: Explicitly bypasses plan and issue bundling (useful when custom post-commit hooks manage plans out-of-repo, or for code-only releases).
- **Zero-Item Resilience (Silent / 1-Line Response)**: If `--no-archive` is passed OR if no unreleased plans exist in `.plans/done/`, `aapp release` outputs a concise 1-line response:
  `ℹ️  No unreleased plans or issues to bundle (skipping plan migration)`
  and cleanly skips bundle creation while proceeding with version bumping, changelog rollup, and tagging.
- **Missing Argument**: Fails fast with status briefing: displays latest tag, count of unreleased plans in `done/`, count of resolved issues, and syntax guidance.

**10-Step Execution Pipeline:**
1. **Pre-Flight Test Gate**: Executes `./aapp test strict quiet` (or project test runner). Aborts if non-zero.
2. **Worktree Cleanliness & Branch Parity**:
   - Asserts working tree is clean across `develop`, `plans`, `agents`, `githooks`.
   - On multi-branch topology, verifies `develop` fast-forwards cleanly into `main` (`git merge-base --is-ancestor develop main` or vice-versa).
3. **Hook-Based Version Increment (`on-release`)**:
   - Invokes `on-release` via `dispatch_lifecycle_hook`.
   - Passes Dual Delivery payload:
     - Env: `AAPP_RELEASE_VERSION="v1.2.0"`, `AAPP_RAW_VERSION="1.2.0"`, `AAPP_PREVIOUS_VERSION="v1.0.0"`, `AAPP_VERSION_BUMP="minor"`.
     - STDIN: JSON payload `{"event":"on-release","version":"v1.2.0","rawVersion":"1.2.0","previousVersion":"v1.0.0","bump":"minor"}`.
   - The hook edits project-specific version files (e.g. `package.json`, `pyproject.toml`, `aapp:AAPP_VERSION`).
   - If hook fails (exit non-zero), release aborts cleanly before any Git commits or tags.
4. **Changelog Rollup**:
   - Extracts items under `## [Unreleased]` from `CHANGELOG.md`.
   - Rolls up into `## [<version>] - <date>`.
   - Pre-seeds empty `## [Unreleased]` block above it.
5. **Milestone Bundle Provisioning (Skipped if `--no-archive` or zero plans)**:
   - Creates directory `.plans/release/<tag>/plans/`.
   - Moves all `P*.md` and `plan-*.md` from `.plans/done/` into `.plans/release/<tag>/plans/`.
6. **Tag Ledger Generation (Skipped if `--no-archive` or zero plans)**:
   - Formats `.plans/release/<tag>/000-archive-ledger.md` with table of all plans shipped in this tag.
   - Relocates resolved defect rows from `.plans/done/000-issues-archive.md` into `.plans/release/<tag>/000-issues-archive.md`.
   - Generates `.plans/release/<tag>/manifest.md` recording commit SHA, plan count, issue count, and verification timestamp.
7. **Master Ledger Truncation (Skipped if `--no-archive` or zero plans)**:
   - Appends 1-line summary row to `Shipped Releases` in `.plans/done/000-archive-ledger.md` linking to `../release/<tag>/000-archive-ledger.md`.
   - Truncates `Current Unreleased Cycle` table in `000-archive-ledger.md`.
   - Resets `.plans/done/000-issues-archive.md` to empty template with link to previous release archives.
8. **Worktree Commit**:
   - Commits `.plans` worktree: `git -C .plans commit -m "release(plans): bundle <tag> milestone and roll ledgers"`.
9. **Git Parity Merge & Tagging**:
   - If dual-branch: checks out `main`, executes `ALLOW_MAIN_COMMIT=1 git merge --ff-only develop`.
   - Creates annotated tag: `git tag -a <tag> -m "Release <tag>"`.
10. **Post-Release Notification (`post-release`)**:
    - Dispatches `post-release` hook with release metadata payload for downstream CI/CD deployment or notification.

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
- **Fallback Inventory**: `None (Clean Break)`: Existing flat `.plans/done/` plans (P-9 through P-36) and archived issues are migrated into `.plans/release/v1.0.0/` during initial execution as the v1.0.0 baseline release.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Resolver & Health Engine Upgrades
- [ ] Task 1.1: Update `lib/plan_resolver.sh` to search `.plans/done/` and `.plans/release/*/plans/` recursively without depth restrictions.
- [ ] Task 1.2: Update `lib/planning_health.sh` to validate Plan IDs and Recorded SHAs across tag ledgers in `.plans/release/*/000-archive-ledger.md`.
- [ ] Task 1.3: Add regression tests in `tests/plan_resolver_test.sh` asserting resolution of plans nested inside release tag folders.

### Phase 2: Release CLI & Lifecycle Hook Implementation (`lib/cmd_release.sh`)
- [ ] Task 2.1: Author `lib/cmd_release.sh` implementing:
  - Argument parsing for explicit versions (`v1.2.0`) and SemVer tokens (`patch`, `minor`, `major`).
  - `--dry-run` simulation mode.
  - Pre-flight test runner gate (`./aapp test strict quiet`).
  - `on-release` hook dispatch with Dual Delivery payload.
  - Milestone bundle generation under `.plans/release/<tag>/`.
  - Master ledger rollup in `000-archive-ledger.md` and archive truncation in `000-issues-archive.md`.
  - `CHANGELOG.md` rollup and git parity merge (`develop` ➔ `main`) with annotated tag.
  - `post-release` hook notification trigger.
- [ ] Task 2.2: Register `release` in `lib/verbs.tsv` and wire into `aapp` dispatcher.
- [ ] Task 2.3: Author `examples/hooks/on-release.sh.sample` in `examples/hooks/`.

### Phase 3: Initial v1.0.0 Baseline Migration
- [ ] Task 3.1: Execute baseline bundle for existing shipped plans (P-9 through P-36) into `.plans/release/v1.0.0/plans/`.
- [ ] Task 3.2: Format `.plans/done/000-archive-ledger.md` with the 1-line `v1.0.0` summary linking to `release/v1.0.0/000-archive-ledger.md`.
- [ ] Task 3.3: Reset `.plans/done/000-issues-archive.md` for the current cycle.

### Phase 4: Test Suite & Documentation Sync
- [ ] Task 4.1: Author `tests/release_test.sh` covering:
  - Explicit version parameter vs SemVer bump calculation.
  - `on-release` hook execution and abort-on-failure.
  - Bundle creation and master ledger truncation.
  - `--dry-run` execution with zero disk/git mutations.
- [ ] Task 4.2: Update `templates/skills/aapp-release/SKILL.md` to delegate directly to `aapp release`.
- [ ] Task 4.3: Update `MANUAL.md`, `README.md`, `CHEATSHEET.md`, `ARCHITECTURE.md`, and `.agents/CODEMAP.md`.
- [ ] Task 4.4: Run full regression test suite (`./aapp test strict quiet`) and update `CHANGELOG.md`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/plan_resolver.sh` -> Enable recursive resolution across release tag subdirectories
- [ ] `lib/planning_health.sh` -> Audit release tag ledgers alongside master archive
- [ ] `NEW FILE` -> `lib/cmd_release.sh` -> Core release orchestration, version hook, and bundle engine
- [ ] `lib/verbs.tsv` -> Register release verb
- [ ] `aapp` -> Route release command in dispatcher
- [ ] `templates/skills/aapp-release/SKILL.md` -> Update release skill to invoke CLI
- [ ] `NEW FILE` -> `examples/hooks/on-release.sh.sample` -> Reference sample for project version bumping
- [ ] `NEW FILE` -> `tests/release_test.sh` -> Regression test suite for release lifecycle
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
  *Decision:* **Hook delegation via `on-release`.** Core AAPP is language-agnostic. It dispatches the target version payload to a project hook, which modifies `package.json`, `pyproject.toml`, or other project-specific files.
* [x] **Question 3: How should the CLI accept the version?**  
  *Decision:* **Parameter required (`aapp release <version-or-bump>`).** Accepts explicit version string (`v1.2.0`, `2026.09.1`) or SemVer bump token (`patch`, `minor`, `major`). Fails fast if omitted.
* [x] **Question 4: What if no plans/issues exist to archive, or external hooks manage them?**  
  *Decision:* **Provide `--no-archive` flag and automatic zero-item resilience.** If `--no-archive` is passed or no plans/issues are found in `.plans/done/`, output a concise 1-line notice (`ℹ️  No unreleased plans or issues to bundle (skipping plan migration)`) and cleanly proceed with version bump, changelog rollup, and tagging without erroring.

---

## 📦 6. Change Log & Refinement History
* **2026-09-27:** Added `--no-archive` flag and zero-item resilience for out-of-repo plan workflows and empty-archive releases.
* **2026-09-27:** Refined blueprint to include mandatory CLI version/bump parameter, hook-delegated version updates (`on-release`), and `--dry-run` simulation preview.
* **2026-09-27:** Initial blueprint drafted from developer directive on milestone release bundling, archive truncation, and tag ledgers.
