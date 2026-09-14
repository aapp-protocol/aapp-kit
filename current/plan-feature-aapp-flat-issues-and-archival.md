# 🗺️ Plan: Flat Issue Ledger, Universal Domain Taxonomy & Archival Protocol
* **Created:** 2026-09-14 | **Last Refined:** 2026-09-14
* **Target Issue / Milestone:** Milestone v1.1.0 (Flat Issue Ledger & Archival)
* **Status:** 🔴 Under Review
<!-- Status must be exactly ONE of: 🔴 Under Review | 🟡 Refining | 🟢 Ready for Execution | 🚫 BLOCKED -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Every commit you make must include your co-author trailer (`Co-authored-by: Antigravity <antigravity@google.com>`).
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.

---

## 1. Context & Architectural Goal
* **What**: Redesign `ISSUES.md` from a multi-table, subheading-divided document into a single, flat, continuous markdown database table (zero subheadings). Enforce the **Relocation Invariant** where resolved issues migrate out of the active file into an append-only archive ledger (`.plans/done/000-issues-archive.md`). Enrich issue metadata with explicit `Severity`, `Type` (multi-domain taxonomy: `UI`, `DB`, `NET`, `SEC`, `CORE`, `CLI`, etc.), and `Date` columns, using clean `#<number>` IDs. Concurrently, upgrade `issues_road_map.md` with an explicit `## ⭐ User Priority (Pinned / Immediate Human Appetite)` band.
* **Why**: The legacy subheading layout (`## 🔴 1. Critical`, `## 🟠 2. High`, etc.) caused state fragmentation:
  1. **Duplicate Entries**: Resolved issues were marked `✅ Resolved` in the active severity tables *and* duplicated in Section 6.
  2. **Parser Fragility**: CLI tools (`cmd_status.sh`) required brittle multi-table regexes and cutoff heuristics (`sed '/Resolved Issues/,$d'`) to parse active issues.
  3. **Severity vs. Appetite Conflict**: Technical severity dictated roadmap position; users lacked an explicit way to prioritize a "Low" severity annoyance over a "High" technical edge case without corrupting the severity classification.
* **Core Invariants**:
  1. **Zero-Subheading Invariant**: `ISSUES.md` contains exactly one markdown table. All categorization happens via metadata columns, never visual markdown headers.
  2. **The Relocation Invariant**: Active tables hold ONLY active items (`🟡 Incubated`, `🔵 Planned`, `🟠 In Progress`). Resolution is a physical row relocation to `.plans/done/000-issues-archive.md`, never an in-place status badge.
  3. **Human Primacy**: `issues_road_map.md` provides a `⭐ User Priority` band that overrides architectural severity based purely on developer appetite.

---

## 2. Technical Blueprint

### A. Flat Database Schema (`ISSUES.md`)
`ISSUES.md` is strictly an active technical backlog. It contains a preamble followed by a single flat table:

```markdown
# 🐛 Issues: Active Technical Backlog

> **Active Backlog Only:** Every row below is an unresolved defect or gap. When resolved, issues are relocated to `.plans/done/000-issues-archive.md` and pruned from `issues_road_map.md`.

| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #49 | `Critical` | `CORE` | 2026-09-10 | `lib/cmd_upgrade.sh:19` | `aapp upgrade` clones default branch, but `main` trails `develop`; downgrades Layer 1. | Publish `develop` to `main`, check upstream version. | 🟡 `Incubated` |
| #50 | `High` | `CLI` | 2026-09-10 | `lib/cmd_init.sh:19` | Drop-in mode on `agent-planning-kit` resolves root to kit repo instead of `$PWD`. | Prefer kit root only when cwd is inside it. | 🟡 `Incubated` |
| #53 | `High` | `SEC` | 2026-09-10 | `lib/cmd_init.sh:346` | Matcher lacks `MultiEdit`, letting agent writes bypass Layer 1 write guard. | Add `MultiEdit` to hook matcher and settings. | 🟡 `Incubated` |
```

#### Field Specifications:
* **`#`**: Numeric identifier prefixed with `#` (e.g. `#49`). Self-explanatory, compact, and collision-free with list indices.
* **`Sev` (Severity)**: Technical impact:
  - `Critical` (breaks core execution, data corruption, or security bypass)
  - `High` (major functionality failure or unexpected crash)
  - `Medium` (isolated feature failure, CLI ergonomics, portability)
  - `Low` (documentation drift, formatting, cosmetic)
* **`Type` (Cross-Domain Taxonomy)**: Standard vocabulary for diverse project domains:
  - `CORE`: Core execution engine, runtime algorithms, language internals.
  - `CLI`: Command-line interface, argument parsing, terminal output, prompts.
  - `UI`: User interface, web views, components, layout, styling, UX.
  - `DB`: Database, ORM, schemas, migrations, persistent storage.
  - `NET`: Networking, API endpoints, HTTP/gRPC, socket protocols, remote sync.
  - `SEC`: Security, authentication, authorization, write guards, sandboxing.
  - `HOOK`: Git hooks, tool use interceptors, lifecycle plugins.
  - `DOCS`: Documentation, README, user manuals, starter templates.
  - `TEST`: Test suites, regression harnesses, CI/CD pipelines, assertions.
  - `PERF`: Performance, memory leaks, latency, caching, stream buffering.
* **`Date`**: Date discovered (`YYYY-MM-DD`).
* **`Location`**: Path and line range (`path/to/file.ext:123`).
* **`Symptom / Problem`**: Exact defect description (strictly 2–3 sentences max).
* **`Target Plan / Fix`**: Direction of fix, or link to promoted blueprint (`current/plan-<name>.md`).
* **`Status`**: `🟡 Incubated` | `🔵 Planned` | `🟠 In Progress` *(Note: `✅ Resolved` does NOT exist in this table).*

---

### B. The Archival Ledger (`.plans/done/000-issues-archive.md`)
When an issue is fixed, it is cut from `ISSUES.md` and appended to the master historical archive:

```markdown
# 🏛️ Master Issue Archive Ledger

Append-only historical ledger of verified and resolved issues.

| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #61 | `High` | `CORE` | 2026-09-14 | 2026-09-14 | `362cf80` (`v1.1.0`) | Universal AAPP Skills in `templates/skills/`, bridged to `.claude/skills/`, decoupled settings. |
| #01 | `Critical` | `SEC` | 2026-09-09 | 2026-09-09 | `b9e0daf` (`v1.0.1`) | Added `hookSpecificOutput.permissionDecision` JSON output and exit code 2 in `blast-radius-guard.sh`. |
```

---

### C. The Priority Board (`issues_road_map.md`)
`issues_road_map.md` remains the human's subjective prioritization queue, enriched with the `⭐ User Priority` band:

```markdown
# 🗺️ Issue Priority Board

> **Role:** This file puts issues recorded in `ISSUES.md` into the order you intend to fix them. It is an **active view**, not a record. Resolved issues are auto-pruned.

---

## ⭐ User Priority (Pinned / Immediate Human Focus)
*Direct developer overrides based on current focus and appetite.*
- [ ] #53 -> Add `MultiEdit` to hook matcher to prevent bypass.

## 🔴 High Priority (Technical Urgency)
1. #49 -> `aapp upgrade` clones default branch, but `main` trails `develop`; upgrades downgrade Layer 1.
2. #52 -> Deny payload omits `hookEventName` and `permissionDecisionReason`; agent blocked with no reason.
3. #64 -> Status enum is not enforced in write-guard/pre-commit (`🚫|BLOCKED` check only).

## 🟡 Medium Priority (Upcoming Iterations)
- [ ] #50 -> Drop-in mode on `agent-planning-kit` resolves root to kit repo instead of `$PWD`.
- [ ] #51 -> Guard self-consumption on signatures rather than dirname.

## 🟢 Low Priority (Edge Cases & Tooling)
- [ ] #62 -> Assert denial reason reaches caller in write-guard tests.
- [ ] #63 -> Add GitHub Actions CI workflow running test suites.
```

---

### D. Enforcement & Context Recovery Updates

1. **Dynamic Roadmap Reconciliation in `cmd_status.sh` (`status` verb)**:
   Before rendering the Context Recovery briefing, `cmd_status.sh` actively reconciles `issues_road_map.md` against `ISSUES.md` to eliminate staleness:
   - **Step 1 (Auto-Prune Resolved Ghost Items)**: Strips any lines marked `✅` or `Resolved` (or present in `000-issues-archive.md`), preventing dead issues from lingering.
   - **Step 2 (Auto-Seed Unsequenced Issues)**: Scans active `#<num>` entries in `ISSUES.md`. Any issue not yet present on `issues_road_map.md` is automatically appended under `## 📥 Triage (Incoming / Unsequenced)` so newly logged defects are immediately visible.
   - **Step 3 (Immediate Ground-Truth Reporting)**: Pillar 2 extracts the top items directly from the freshly synchronized roadmap. If new items were appended to Triage, a 1-line notice alerts the user to prioritize them.
2. **`aapp-pre-commit` Integrity Guard**:
   Add a fast check (<5ms) during `.plans/` commits:
   - Ensure no issue appears in both `ISSUES.md` and `.plans/done/000-issues-archive.md`.
   - Ensure no line in `ISSUES.md` has status `✅` or `Resolved` (must be relocated).
3. **`/aapp-done` Skill Automation**:
   When archiving a plan that targets an issue (e.g. `Target Issue: #61`):
   - Move row from `ISSUES.md` to `.plans/done/000-issues-archive.md`.
   - Delete entry from `issues_road_map.md`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Templates & Taxonomy Specification
- [ ] Task 1.1: Rewrite `templates/issues.md` into the flat database table format with `Sev`, `Type`, `Date`, and clean `#` IDs.
- [ ] Task 1.2: Add standard `Type` taxonomy documentation in `templates/issues.md` and `MANUAL.md`.
- [ ] Task 1.3: Author starter template `templates/done-issues-archive.md` for `.plans/done/000-issues-archive.md`.
- [ ] Task 1.4: Update `templates/issues_road_map.md` to include `## ⭐ User Priority (Pinned / Immediate Human Focus)` and `## 📥 Triage (Incoming / Unsequenced)`.

### Phase 2: Engine & Skill Synchronization
- [ ] Task 2.1: Update `lib/cmd_status.sh` to dynamically reconcile `issues_road_map.md` (prune resolved, auto-append incoming issues from `ISSUES.md` to Triage) before reporting Pillar 2.
- [ ] Task 2.2: Update `templates/skills/aapp-done/SKILL.md` and `.agents/skills/aapp-done/SKILL.md` to relocate resolved issues to `000-issues-archive.md`.
- [ ] Task 2.3: Update `templates/aapp-pre-commit` and `.githooks/aapp-pre-commit` with an anti-duplication integrity check for `.plans/` commits.

### Phase 3: Repository Migration
- [ ] Task 3.1: Create `.plans/done/000-issues-archive.md` and migrate all 49 historical resolved issues from `.plans/ISSUES.md`.
- [ ] Task 3.2: Reformat `.plans/ISSUES.md` into the single flat table containing only the 14 active open issues (`#49`–`#60`, `#62`–`#64`).
- [ ] Task 3.3: Update `.plans/issues_road_map.md` with the new `#<num>` syntax and `⭐ User Priority` header.

### Phase 4: Documentation & Test Verification
- [ ] Task 4.1: Update `MANUAL.md` and `README.md` documenting the Flat Issue Ledger, Domain Taxonomy, and Relocation Invariant.
- [ ] Task 4.2: Update `tests/install_test.sh` and `tests/pre-commit_test.sh` with assertions for flat template generation and archive migration.
- [ ] Task 4.3: Verify all test suites pass (102+ test cases).
- [ ] Task 4.4: Record changelog entry in `CHANGELOG.md`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/issues.md` -> Flat single-table schema with Sev, Type, Date, # ID.
- [ ] `templates/issues_road_map.md` -> Add ⭐ User Priority section and # ID format.
- [ ] `NEW FILE` -> `templates/done-issues-archive.md` -> Template for historical issue archive ledger.
- [ ] `lib/cmd_status.sh` -> Streamline status briefing issue parser for flat table.
- [ ] `templates/aapp-pre-commit` -> Add anti-duplication integrity check for .plans commits.
- [ ] `.githooks/aapp-pre-commit` -> Synchronize engine from template.
- [ ] `templates/skills/aapp-done/SKILL.md` -> Update aapp-done procedure to relocate issues to archive ledger.
- [ ] `.agents/skills/aapp-done/SKILL.md` -> Update active skill definition.
- [ ] `templates/AGENTS.md` -> Document Relocation Invariant and issue archival.
- [ ] `.agents/AGENTS.md` -> Synchronize protocol rules.
- [ ] `MANUAL.md` -> Comprehensive documentation of issue taxonomy and archival.
- [ ] `README.md` -> Update structural trees and issue management overview.
- [ ] `CHANGELOG.md` -> Document v1.1.0 issue ledger evolution.
- [ ] `tests/install_test.sh` -> Regression coverage for new templates.
- [ ] `tests/pre-commit_test.sh` -> Regression coverage for integrity guard.
- [ ] `.plans/ISSUES.md` -> Migrate active issues to flat table.
- [ ] `.plans/issues_road_map.md` -> Reformat active board with # IDs and User Priority.
- [ ] `NEW FILE` -> `.plans/done/000-issues-archive.md` -> Master archive ledger of resolved issues.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Write-time guard remains stable and unmodified.
- [ ] `.githooks/blast-radius-guard` -> Inode self-protection and tool filters remain untouched.
- [ ] `lib/cmd_develop.sh` -> Symlink development engine is out of bounds.
- [ ] `lib/cmd_upgrade.sh` -> Core upgrade logic is untouched (subject to #49).
- [ ] `templates/claude/` -> Claude Code bridge is stable.

---

## ❓ 5. Open Questions (Optional / Gate)

* [ ] **Question 1 (Domain Taxonomy Extensibility):** Should the `Type` column be restricted to a strict closed enum enforced by linters, or remain an open string with a recommended core vocabulary (`CORE`, `CLI`, `UI`, `DB`, `NET`, `SEC`, `HOOK`, `DOCS`, `TEST`, `PERF`) allowing adopters to define project-specific tags (e.g. `ML`, `AUDIO`, `3D`)?
* [ ] **Question 2 (Archival Ledger Naming):** Is `.plans/done/000-issues-archive.md` the preferred location, matching `.plans/done/000-archive-ledger.md` for plans?
* [ ] **Question 3 (Roadmap ID Format):** Do you prefer `#49` or bare numbers `49` on `issues_road_map.md`? (Recommendation: `#49` for unambiguous parsing).

---

## 📦 6. Change Log & Refinement History
* **2026-09-14:** Initial draft scaffolded from user architectural proposal on flat issue ledger, universal domain taxonomy, and relocation archival protocol.
* **2026-09-14:** Added dynamic roadmap reconciliation in `cmd_status.sh` (`status` verb) to automatically prune ghost resolved items, auto-seed incoming unsequenced issues into `## 📥 Triage`, and report the freshly updated ground truth upon desk return.
