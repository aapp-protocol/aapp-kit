# 🗺️ Plan P-38: Milestone Release Bundling & Tag Ledgers
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

### Architectural Goal
Establish **Milestone Release Bundling** under `.plans/release/<tag>/` and **1-Row Master Ledger Rollups**:
1. When a release is cut (`aapp release <version>`), the completed blueprints currently in `.plans/done/` and the resolved issues in `.plans/done/000-issues-archive.md` are bundled into `.plans/release/<tag>/`.
2. A dedicated **Tag Ledger** (`.plans/release/<tag>/000-archive-ledger.md`) is stamped inside the release bundle with the full details of all plans in that release.
3. The master ledger (`.plans/done/000-archive-ledger.md`) is truncated to a lean table containing **1-line summary rows per release tag** (linking directly to each release's tag ledger), followed only by plans completed in the current unreleased cycle.
4. The active issues archive (`.plans/done/000-issues-archive.md`) is reset to a clean, empty table for the next cycle, with a reference link to past release archives.
5. The Plan Resolver (`lib/plan_resolver.sh`) is upgraded to search recursively across `.plans/done/` and `.plans/release/*/plans/`, ensuring shorthand plan resolution (`aapp plan-status P-10`) works seamlessly across all historical releases.

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
└── manifest.md                          # 1-page milestone summary (tag, date, commit SHA, metrics)
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
- **Deep Inspection**: Clicking or navigating `[v1.0.0 Ledger](../release/v1.0.0/000-archive-ledger.md)` opens the complete, unabridged plan history for that version.

### 2.3 Standalone CLI Command (`aapp release <version>`)

Add `lib/cmd_release.sh` and register `release` in `lib/verbs.tsv` under the Setup & Maintenance tier:

```bash
aapp release [version] [--dry-run]
```

**Execution Pipeline:**
1. **Pre-Flight Test Gate**: Sinks `./aapp test strict quiet` and asserts 100% green pass.
2. **Branch Parity & Clean Check**: Asserts on `develop` (or current branch), working tree is clean across all worktrees.
3. **Bundle Provisioning**: Creates `.plans/release/<version>/plans/`.
4. **Plan Migration**: Moves all `P*.md` and `plan-*.md` from `.plans/done/` into `.plans/release/<version>/plans/`.
5. **Tag Ledger Generation**: Generates `.plans/release/<version>/000-archive-ledger.md` containing the detailed table of moved plans.
6. **Issue Archive Relocation**: Moves the resolved rows from `.plans/done/000-issues-archive.md` into `.plans/release/<version>/000-issues-archive.md`.
7. **Master Ledger Truncation**: Appends the 1-line release row to the `Shipped Releases` section of `.plans/done/000-archive-ledger.md` and resets `Current Unreleased Cycle`.
8. **Changelog Rollup**: Rolls up `CHANGELOG.md` `## [Unreleased]` into `## [<version>] - <date>`.
9. **Version Bumping**: Updates `AAPP_VERSION` in `aapp` and protocol markers in `templates/AGENTS.md`.
10. **Git Tagging & Parity Merge**: Fast-forward merges `develop` to `main`, tags `git tag -a <version>`, and commits worktree state.

### 2.4 Recursive Plan Resolution (`lib/plan_resolver.sh`)

Update `resolve_plan_path` in `lib/plan_resolver.sh`:
- Search scope `done` searches both `.plans/done/` and `.plans/release/*/plans/` recursively.
- `list_available_plans` and direct lookup use `find "$DIR" -name "*.md" ! -name "000-*"` instead of `-maxdepth 1`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`: Existing flat `.plans/done/` plans from the initial runway are migrated into `.plans/release/v1.0.0/plans/` as the initial release baseline.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Resolver & Health Engine Upgrades
- [ ] Task 1.1: Update `lib/plan_resolver.sh` to search `.plans/done/` and `.plans/release/*/plans/` recursively without depth restrictions.
- [ ] Task 1.2: Update `lib/planning_health.sh` to validate Plan IDs and Recorded SHAs across tag ledgers in `.plans/release/*/000-archive-ledger.md`.
- [ ] Task 1.3: Add regression tests in `tests/plan_resolver_test.sh` asserting resolution of plans nested inside release tag folders.

### Phase 2: Release CLI Implementation (`lib/cmd_release.sh`)
- [ ] Task 2.1: Author `lib/cmd_release.sh` implementing the automated 10-step release pipeline.
- [ ] Task 2.2: Register `release` in `lib/verbs.tsv` and wire into `aapp` dispatcher.
- [ ] Task 2.3: Support `--dry-run` to preview bundle generation, changelog rollup, and ledger truncation without disk mutation.

### Phase 3: Initial v1.0.0 Baseline Migration
- [ ] Task 3.1: Execute baseline bundle for existing shipped plans (P-9 through P-36) into `.plans/release/v1.0.0/`.
- [ ] Task 3.2: Format `.plans/done/000-archive-ledger.md` with the 1-line `v1.0.0` summary linking to `release/v1.0.0/000-archive-ledger.md`.
- [ ] Task 3.3: Reset `.plans/done/000-issues-archive.md` for the current cycle.

### Phase 4: Test Suite & Documentation Sync
- [ ] Task 4.1: Author `tests/release_test.sh` covering bundle creation, ledger truncation, changelog rollup, and dry-run mode.
- [ ] Task 4.2: Update `templates/skills/aapp-release/SKILL.md` to delegate directly to `aapp release`.
- [ ] Task 4.3: Update `MANUAL.md`, `README.md`, `CHEATSHEET.md`, `ARCHITECTURE.md`, and `.agents/CODEMAP.md`.
- [ ] Task 4.4: Run full regression test suite (`./aapp test strict quiet`) and update `CHANGELOG.md`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/plan_resolver.sh` -> Enable recursive resolution across release tag subdirectories
- [ ] `lib/planning_health.sh` -> Audit release tag ledgers alongside master archive
- [ ] `NEW FILE` -> `lib/cmd_release.sh` -> Core release orchestration and bundle generation engine
- [ ] `lib/verbs.tsv` -> Register release verb
- [ ] `aapp` -> Route release command in dispatcher
- [ ] `templates/skills/aapp-release/SKILL.md` -> Update release skill to invoke CLI
- [ ] `NEW FILE` -> `tests/release_test.sh` -> Regression test suite for release lifecycle
- [ ] `tests/plan_resolver_test.sh` -> Add nested release plan resolution tests
- [ ] `README.md` -> Document aapp release workflow
- [ ] `MANUAL.md` -> Document milestone bundling and tag ledger architecture
- [ ] `CHEATSHEET.md` -> Add aapp release to command table
- [ ] `ARCHITECTURE.md` -> Document milestone release bundling invariant
- [ ] `.agents/ARCHITECTURE.md` -> Record release bundling in agent architecture
- [ ] `.agents/CODEMAP.md` -> Document cmd_release.sh contracts
- [ ] `CHANGELOG.md` -> Record release command and milestone bundling

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Guard Section 2 self-protection.
- [ ] `lib/cmd_pause.sh` -> Emergency brake logic is separate.
- [ ] `lib/cmd_test.sh` -> Test runner execution is invoked as a subprocess.

---

## ❓ 5. Open Questions
* [x] **Question 1: Should master ledger link directly to the tag ledger?**  
  *Decision:* **Yes.** The master archive ledger maintains a 1-line summary row for each release tag that links directly to `.plans/release/<tag>/000-archive-ledger.md`, enabling quick scanning and deep-drill capability.
* [x] **Question 2: How should existing flat plans in .plans/done/ be handled?**  
  *Decision:* They will be bundled into `.plans/release/v1.0.0/` during initial execution, giving the repository an immediate clean slate for subsequent work.

---

## 📦 6. Change Log & Refinement History
* **2026-09-27:** Initial blueprint drafted from developer directive on milestone release bundling, archive truncation, and tag ledgers.
