# 🗺️ Plan: Flat Issue Ledger, Universal Domain Taxonomy & Archival Protocol
* **Created:** 2026-09-14 | **Last Refined:** 2026-09-14
* **Target Issue / Milestone:** Milestone v1.1.0 (Flat Issue Ledger & Archival)
* **Status:** 🟡 Refining
<!-- Status must be exactly ONE of: 🔴 Under Review | 🟡 Refining | 🟢 Ready for Execution | 🚫 BLOCKED -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Engine Self-Protection Invariant**: Files under `.githooks/*` and `.agents/skills/aapp-*` are protected by write-guard Section 2 (exit 2). NEVER edit them directly in execution sessions; modify source templates under `templates/` and run `aapp init` to propagate.
> 3. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 4. **Attribution Trailer**: Every commit you make must include your co-author trailer (`Co-authored-by: Antigravity <antigravity@google.com>`).
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.

---

## 1. Context & Architectural Goal
* **What**: Redesign `ISSUES.md` from a multi-table, subheading-divided document into a single, flat, continuous markdown database table (zero subheadings). Enforce the **Relocation Invariant** where resolved issues migrate out of the active file into an append-only archive ledger (`.plans/done/000-issues-archive.md`). Enrich issue metadata with explicit `Severity`, `Type` (open multi-domain taxonomy with recommended core: `CORE`, `CLI`, `UI`, `DB`, `NET`, `SEC`, `HOOK`, `DOCS`, `TEST`, `PERF`), and `Date` columns, using clean `#<number>` IDs. Concurrently, upgrade `issues_road_map.md` with an explicit `## ⭐ User Priority (Pinned / Immediate Human Focus)` band.
* **Why**: The legacy subheading layout (`## 🔴 1. Critical`, `## 🟠 2. High`, etc.) caused state fragmentation:
  1. **Duplicate Entries**: Resolved issues were marked `✅ Resolved` in the active severity tables *and* duplicated in Section 6.
  2. **Parser Fragility**: CLI tools (`cmd_status.sh`) required brittle multi-table regexes and cutoff heuristics (`sed '/Resolved Issues/,$d'`) to parse active issues.
  3. **Severity vs. Appetite Conflict**: Technical severity dictated roadmap position; users lacked an explicit way to prioritize a "Low" severity annoyance over a "High" technical edge case without corrupting the severity classification.
  4. **Referential Gaps**: Roadmap and active issues diverged (e.g. `#64` logged on roadmap but missing detail row in `ISSUES.md`).
* **Core Invariants**:
  1. **Zero-Subheading Invariant**: `ISSUES.md` contains exactly one markdown table. All categorization happens via metadata columns, never visual markdown headers.
  2. **The Relocation Invariant**: Active tables hold ONLY active items (`🟡 Incubated`, `🔵 Planned`, `🟠 In Progress`). Resolution is a physical row relocation to `.plans/done/000-issues-archive.md`, never an in-place status badge.
  3. **Human Primacy**: `issues_road_map.md` provides a `⭐ User Priority` band that overrides architectural severity based purely on developer appetite.
  4. **Referential Integrity**: All active issues on `issues_road_map.md` must resolve to a valid detail row in `ISSUES.md`. Active issues and archive ledger are strictly mutually disjoint.

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
| #64 | `High` | `SEC` | 2026-09-14 | `blast-radius-guard.sh:182` | Status enum not enforced; only `🚫|BLOCKED` checked, while `🔴` and `🟡` fall through. | Enforce strict status enum in write-guard and pre-commit. | 🟡 `Incubated` |
```

#### Field Specifications:
* **`#`**: Numeric identifier prefixed with `#` (e.g. `#49`). Self-explanatory, compact, and collision-free with list indices.
* **`Sev` (Severity)**: Technical impact:
  - `Critical` (breaks core execution, data corruption, or security bypass)
  - `High` (major functionality failure or unexpected crash)
  - `Medium` (isolated feature failure, CLI ergonomics, portability)
  - `Low` (documentation drift, formatting, cosmetic)
* **`Type` (Extensible Domain Taxonomy)**: Uppercase token conforming to `^[A-Z0-9_-]+$`.
  - **Recommended Core Vocabulary**:
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
  - **Extensibility Rule**: Linters warn on unknown tokens but do not block, allowing adopters to declare domain-specific types (e.g., `ML`, `AUDIO`, `3D`).
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
| #1 | `Critical` | `SEC` | 2026-09-09 | 2026-09-09 | `b9e0daf` (`v1.0.1`) | Added `hookSpecificOutput.permissionDecision` JSON output and exit code 2 in `blast-radius-guard.sh`. |
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

#### Bulletproof ID-Anchored Auto-Prune Regex Invariant:
In `templates/aapp-pre-commit`, auto-pruning requires an issue number token (`#?[0-9]+`) immediately following the list marker:
```bash
grep -v -E '^\s*([0-9]+\.|-\s*\[[ xX]?\]|\*)\s*#?[0-9]+.*(\✅|Resolved)'
```
This guarantees that explanatory bullets, rules, or instructions containing the word "resolved" (e.g. `* Note: Resolved issues are pruned automatically`) are **never** accidentally deleted.

---

### D. Enforcement & Context Recovery Updates

1. **Dynamic Roadmap Reconciliation in `cmd_status.sh` (`status` verb)**:
   Before rendering the Context Recovery briefing, `cmd_status.sh` actively reconciles `issues_road_map.md` against `ISSUES.md`:
   - **Delete Legacy Workarounds**: Remove both brittle heuristics in `cmd_status.sh` (the `sed '/Resolved Issues/,$d'` cutoff and older `grep -v 'Resolved|DONE'`).
   - **Step 1 (Auto-Prune Resolved Ghost Items)**: Strips any issue rows marked `✅` or `Resolved` using the bulletproof ID-anchored regex.
   - **Step 2 (Auto-Seed Unsequenced Issues)**: Scans active `#<num>` entries in `ISSUES.md`. Any issue not yet present on `issues_road_map.md` is automatically appended under `## 📥 Triage (Incoming / Unsequenced)` so newly logged defects are immediately visible.
   - **Step 3 (Immediate Ground-Truth Reporting)**: Pillar 2 extracts the top items directly from the freshly synchronized roadmap. If new items were appended to Triage, a 1-line notice alerts the user to prioritize them.
2. **Three-Pair Planning-Health Engine (`lib/planning_health.sh` / `templates/aapp-pre-commit`)**:
   Enforce comprehensive consistency during `.plans/` commits and `aapp health`:
   - **Pair 1 (`ISSUES ↔ archive`)**: IDs in `ISSUES.md` and `.plans/done/000-issues-archive.md` must be mutually disjoint. Normalizes IDs numerically (`int()` / `10#$num`) so `#1` and `#01` cannot collide. No row in active `ISSUES.md` may carry `✅` or `Resolved`.
   - **Pair 2 (`roadmap ↔ ISSUES`)**: Referential integrity. Every `#<num>` listed on `issues_road_map.md` must have a corresponding detail row in `ISSUES.md` (prevents phantom roadmap entries like `#64`).
   - **Pair 3 (`pickup ↔ ISSUES`)**: Clean routing. When an issue is logged from `pickup.md`, its pickup draft must be removed.
3. **Pre-Commit Auto-Relocation for Direct (Non-Promoted) Fixes (`templates/aapp-pre-commit`)**:
   When an engineer or agent fixes a bug directly in code without drafting a feature plan ("*Do not promote a small, obvious fix. Just make it*"):
   - They simply mark the issue row as `✅ Resolved` (or `Resolved`) in `ISSUES.md`.
   - On `git commit`, `aapp-pre-commit` intercepts rows marked `✅|Resolved` in `ISSUES.md`.
   - It extracts the row, transforms it into the archive schema (`Date Resolved = today`, staged commit hash), and appends it to `.plans/done/000-issues-archive.md`.
   - It cuts the row from `ISSUES.md`, purges `#<num>` from `issues_road_map.md`, and stages all modified files.
   - The **Relocation Invariant** is thus **self-enforcing and zero-friction**.
4. **`/aapp-done` Skill Automation (`templates/skills/aapp-done/SKILL.md`)**:
   When archiving a plan that targets an issue (e.g. `Target Issue: #61`):
   - Move row from `ISSUES.md` to `.plans/done/000-issues-archive.md`.
   - Delete entry from `issues_road_map.md`.
5. **Non-Destructive Guidance at Init Time (`lib/cmd_init.sh`)**:
   In arbitrary wild codebases, `ISSUES.md` may exist in custom formats (Jira dumps, prose, bullet lists). `aapp init` must **never destructively alter** or corrupt arbitrary existing files:
   - If an existing non-flat `ISSUES.md` is detected, `cmd_init.sh` leaves it untouched and prints a clean informational notice directing the developer to `MANUAL.md` and `templates/issues.md` to format it at their own pace.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Templates & Taxonomy Specification
- [ ] Task 1.1: Rewrite `templates/issues.md` into the flat database table format with `Sev`, `Type`, `Date`, and clean unpadded `#<num>` IDs.
- [ ] Task 1.2: Add extensible `Type` taxonomy documentation in `templates/issues.md` and `MANUAL.md`.
- [ ] Task 1.3: Author starter template `templates/done-issues-archive.md` for `.plans/done/000-issues-archive.md`.
- [ ] Task 1.4: Update `templates/issues_road_map.md` to include `## ⭐ User Priority (Pinned / Immediate Human Focus)` and `## 📥 Triage (Incoming / Unsequenced)`.

### Phase 2: Engine, Health & Skill Synchronization
- [ ] Task 2.1: Update `lib/cmd_status.sh` to delete legacy parser workarounds (`sed` cutoff and unanchored grep) and dynamically reconcile `issues_road_map.md` before reporting Pillar 2.
- [ ] Task 2.2: Author shared integrity check module `lib/planning_health.sh` verifying the three pairs (`ISSUES ↔ archive`, `roadmap ↔ ISSUES`, and format/status validity) with numerical ID normalization.
- [ ] Task 2.3: Update `templates/aapp-pre-commit` to use bulletproof ID-anchored auto-prune regex `^\s*([0-9]+\.|-\s*\[[ xX]?\]|\*)\s*#?[0-9]+.*(\✅|Resolved)`, invoke planning-health integrity checks, and auto-relocate direct `✅|Resolved` rows to `000-issues-archive.md`.
- [ ] Task 2.4: Update `templates/skills/aapp-done/SKILL.md` to relocate resolved issues to `000-issues-archive.md` and prune roadmap entries.
- [ ] Task 2.5: Update `lib/cmd_init.sh` to check for existing custom `ISSUES.md` files non-destructively and print formatting guidance to `MANUAL.md`.
- [ ] Task 2.6: Run `aapp init` to propagate updated templates into `.githooks/` and `.agents/skills/` without violating Section 2 write guards.

### Phase 3: Repository Migration & Data Integrity Verification
- [ ] Task 3.1: Create `.plans/done/000-issues-archive.md` and migrate all 49 historical resolved issues from `.plans/ISSUES.md`.
- [ ] Task 3.2: Log the missing row for `#64` (`Status enum is not enforced in write-guard/pre-commit`) into `.plans/ISSUES.md` and prune its unworked note from `.plans/pickup.md`.
- [ ] Task 3.3: Reformat `.plans/ISSUES.md` into the single flat table containing all 15 active open issues (`#49`–`#60`, `#62`–`#64`).
- [ ] Task 3.4: **Count-Preservation Assertion**: Run an automated ID set-difference script verifying `49 (archived) + 15 (active) = 64 (unique project issues #01..#64)`. Assert zero dropped IDs and zero duplicate collisions.
- [ ] Task 3.5: Update `.plans/issues_road_map.md` with the new `#<num>` syntax and `⭐ User Priority` header.

### Phase 4: Documentation & Test Verification
- [ ] Task 4.1: Update `MANUAL.md` and `README.md` documenting the Flat Issue Ledger, Domain Taxonomy, Direct-Fix Archival, and Relocation Invariant.
- [ ] Task 4.2: Update `tests/install_test.sh` and `tests/pre-commit_test.sh` with assertions for flat template generation, bulletproof auto-prune preservation, pre-commit auto-relocation, and referential integrity checks.
- [ ] Task 4.3: Verify all test suites pass (all 102+ test cases across `install_test.sh`, `pre-commit_test.sh`, and `write-guard_test.sh`).
- [ ] Task 4.4: Record changelog entry in `CHANGELOG.md`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/issues.md` -> Flat single-table schema with Sev, Type, Date, # ID.
- [ ] `templates/issues_road_map.md` -> Add ⭐ User Priority section and # ID format.
- [ ] `NEW FILE` -> `templates/done-issues-archive.md` -> Template for historical issue archive ledger.
- [ ] `lib/cmd_status.sh` -> Streamline status briefing issue parser, delete workarounds, add dynamic reconciliation.
- [ ] `NEW FILE` -> `lib/planning_health.sh` -> Shared planning-health integrity validator for hooks and CLI.
- [ ] `templates/aapp-pre-commit` -> Bulletproof ID-anchored auto-pruning, pre-commit auto-relocation, and planning-health checks.
- [ ] `templates/skills/aapp-done/SKILL.md` -> Update aapp-done procedure to relocate issues to archive ledger.
- [ ] `lib/cmd_init.sh` -> Non-destructive advisory for existing custom ISSUES.md files.
- [ ] `templates/AGENTS.md` -> Document Relocation Invariant, taxonomy, and issue archival.
- [ ] `.agents/AGENTS.md` -> Synchronize protocol rules.
- [ ] `MANUAL.md` -> Comprehensive documentation of issue taxonomy and archival.
- [ ] `README.md` -> Update structural trees and issue management overview.
- [ ] `CHANGELOG.md` -> Document v1.1.0 issue ledger evolution.
- [ ] `tests/install_test.sh` -> Regression coverage for new templates, non-destructive init, and propagation.
- [ ] `tests/pre-commit_test.sh` -> Regression coverage for ID-anchored auto-pruning, pre-commit auto-relocation, and integrity validation.
- [ ] `.plans/ISSUES.md` -> Migrate active issues to flat table and add missing #64.
- [ ] `.plans/issues_road_map.md` -> Reformat active board with # IDs and User Priority.
- [ ] `.plans/pickup.md` -> Prune digested ISSUE-064 entry.
- [ ] `NEW FILE` -> `.plans/done/000-issues-archive.md` -> Master archive ledger of resolved issues.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/aapp-pre-commit` -> Protected by Section 2 self-protection. Propagated from `templates/aapp-pre-commit` via `aapp init`.
- [ ] `.agents/skills/aapp-done/SKILL.md` -> Protected by Section 2 self-protection. Propagated from `templates/skills/` via `aapp init`.
- [ ] `templates/blast-radius-guard.sh` -> Write-time guard remains stable and unmodified.
- [ ] `.githooks/blast-radius-guard` -> Inode self-protection and tool filters remain untouched.
- [ ] `lib/cmd_develop.sh` -> Symlink development engine is out of bounds.
- [ ] `lib/cmd_upgrade.sh` -> Core upgrade logic is untouched (subject to #49).
- [ ] `templates/claude/` -> Claude Code bridge is stable.

---

## ❓ 5. Open Questions & Peer Review Resolutions

* [x] **Question 1 (Domain Taxonomy Extensibility):** Should the `Type` column be restricted to a strict closed enum enforced by linters, or remain an open string with a recommended core vocabulary?
  - **Resolution**: **Open Vocabulary with Recommended Core**. A general-purpose kit cannot restrict unknown downstream domains (e.g. `ML`, `AUDIO`, `3D`). We enforce shape (`^[A-Z0-9_-]+$`) to ensure clean greppability, recommend the 10 core types (`CORE`, `CLI`, `UI`, `DB`, `NET`, `SEC`, `HOOK`, `DOCS`, `TEST`, `PERF`), and emit non-blocking linter warnings on unknown tags.
* [x] **Question 2 (Archival Ledger Naming):** Is `.plans/done/000-issues-archive.md` the preferred location, matching `.plans/done/000-archive-ledger.md` for plans?
  - **Resolution**: **Yes**. `.plans/done/000-issues-archive.md` preserves the `000-` sort-first convention established by the plan archive ledger.
* [x] **Question 3 (Roadmap ID Format):** Do you prefer `#49` or bare numbers `49` on `issues_road_map.md`?
  - **Resolution**: **`#49` Syntax (Unpadded Integers)**. The hash prefix prevents ambiguity with ordered list numbering (`1. #49 ...`) and enables precise regex matching. Unpadded integers (`#1`, `#49`, `#64`) eliminate padding collisions.

---

## 📦 6. Change Log & Refinement History
* **2026-09-14:** Initial draft scaffolded from user architectural proposal on flat issue ledger, universal domain taxonomy, and relocation archival protocol.
* **2026-09-14:** Added dynamic roadmap reconciliation in `cmd_status.sh` (`status` verb) to automatically prune ghost resolved items, auto-seed incoming unsequenced issues into `## 📥 Triage`, and report the freshly updated ground truth upon desk return.
* **2026-09-14:** Refined blueprint following adversarial peer review (Claude red team audit):
  - **Engine Protection**: Moved `.githooks/aapp-pre-commit` and `.agents/skills/aapp-done/SKILL.md` to Out of Bounds (protected by write-guard Section 2); added Task 2.6 to propagate via `aapp init`.
  - **Roadmap Preamble Protection**: Fixed destructive auto-prune bug in `templates/aapp-pre-commit` by specifying bulletproof ID-anchored row regex `^\s*([0-9]+\.|-\s*\[[ xX]?\]|\*)\s*#?[0-9]+.*(\✅|Resolved)`.
  - **Three-Pair Planning-Health Engine**: Expanded consistency verification beyond `ISSUES ↔ archive` to cover `roadmap ↔ ISSUES` (referential integrity) and `pickup ↔ ISSUES`, architected into `lib/planning_health.sh` with integer ID normalization.
  - **Active Range & Missing #64**: Corrected active range to `#49`–`#60`, `#62`–`#63` (14 items) and added Task 3.2 to author the missing `#64` detail row in `ISSUES.md`.
  - **Count-Preservation Assertion**: Added explicit Task 3.4 asserting `49 archived + 15 active = 64 unique IDs` with an automated set diff.
  - **Pre-Commit Auto-Relocation for Direct Fixes**: Specified pre-commit interception of `✅|Resolved` rows in `ISSUES.md` for zero-friction archival without plans.
  - **Non-Destructive Init Guidance**: Specified safe advisory guidance in `lib/cmd_init.sh` for existing codebases with custom `ISSUES.md` layouts.
  - **Resolved Open Questions**: Formalized resolutions for Q1 (open vocabulary), Q2 (`000-issues-archive.md`), and Q3 (`#49` unpadded syntax).
