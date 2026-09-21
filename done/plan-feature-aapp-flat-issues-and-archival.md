# 🗺️ Plan: Flat Issue Ledger, Universal Domain Taxonomy & Archival Protocol
* **Created:** 2026-09-14 | **Last Refined:** 2026-09-14
* **Target Issue / Milestone:** Flat Issue Ledger & Archival Protocol
* **Status:** ✅ Done
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

#### Bulletproof POSIX ID-Anchored Auto-Prune Regex Invariant:
In `templates/aapp-pre-commit`, roadmap auto-pruning requires a valid list prefix followed by an issue ID token with optional backticks, using standard POSIX character classes and no stray escapes:
```bash
grep -v -E '^[[:space:]]*([0-9]+\.|-[[:space:]]*\[[ xX]?\]|\*)[[:space:]]*`?#?[0-9]+`?.*(✅|[Rr]esolved)'
```
- **POSIX Compliant**: Uses `[[:space:]]` instead of GNU `\s` extension (portable across BSD/macOS and Linux).
- **No Stray Escapes**: Clean unescaped unicode `✅` (avoids `ugrep` / strict parser syntax errors).
- **Backtick Tolerant**: Correctly matches both bare `#49` and backticked `` `#49` `` or `` `ISSUE-049` ``.
- **Case-Insensitive Status**: Matches both `✅` and `[Rr]esolved`.
- **Prose Immune**: Never deletes explanatory bullets, rules, or blockquotes containing the word "resolved".

---

### D. Enforcement & Context Recovery Updates

1. **Strictly Read-Only Context Recovery in `cmd_status.sh` (`status` verb)**:
   The `status` command is an **idempotent, read-only observer**. It must **never write to disk, dirty worktrees, or race across concurrent agent sessions**:
   - **Delete Legacy Workarounds**: Remove both brittle heuristics in `cmd_status.sh` (the `sed '/Resolved Issues/,$d'` cutoff and older `grep -v 'Resolved|DONE'`).
   - **Pillar 2 Issue Briefing**: Directly extracts top active issues from `issues_road_map.md` and `ISSUES.md`.
   - **Non-Destructive Drift Detection**:
     - If a roadmap entry has no corresponding detail row in `ISSUES.md` (e.g. phantom `#64`), prints:
       `⚠️ [Roadmap Drift] #64 is on the priority board but missing from ISSUES.md.`
     - If active issues in `ISSUES.md` are unsequenced on the roadmap, prints:
       `ℹ️ [Unsequenced] Active issues (#50, #51) are not yet on the priority board.`
   - Mutation and auto-synchronization are strictly forbidden on the read path.
2. **Three-Pair Planning-Health Engine (`lib/planning_health.sh`)**:
   Provides reusable consistency validation across hooks and CLI:
   - **Pair 1 (`ISSUES ↔ archive`)**: IDs in `ISSUES.md` and `.plans/done/000-issues-archive.md` must be mutually disjoint. Normalizes IDs numerically (`int()` / `10#$num`) so `#1` and `#01` cannot collide. No row in active `ISSUES.md` may carry `✅` or `Resolved`.
   - **Pair 2 (`roadmap ↔ ISSUES`)**: Referential integrity. Every `#<num>` listed on `issues_road_map.md` must have a corresponding detail row in `ISSUES.md` (prevents phantom roadmap entries like `#64`).
   - **Pair 3 (`pickup ↔ ISSUES`)**: Clean routing. When an issue is logged from `pickup.md`, its pickup draft must be removed.
3. **Detect-and-Block Relocation Invariant in `templates/aapp-pre-commit`**:
   The hook does **not** attempt unreviewed, schema-altering in-hook mutations (active 8 columns → archive 7 columns) or invent commit hashes that do not exist before commit object creation. Instead, it **detects and blocks**:
   - **Dedicated Table-Row Matcher**:
     ```bash
     grep -E '^[[:space:]]*\|[[:space:]]*`?#?[0-9]+`?.*(✅|[Rr]esolved)'
     ```
   - If any resolved row is found in `ISSUES.md`, `aapp-pre-commit` refuses the commit with an actionable error:
     ```text
     ❌ [Pre-Commit Violation] Found resolved issue in active ISSUES.md.
        The Relocation Invariant requires resolved rows to be moved to .plans/done/000-issues-archive.md.
        Resolution is a physical row relocation, never an in-place status badge.
     ```
   - **Hook Execution Order**:
     1. Roadmap list hygiene: Prune resolved items from `issues_road_map.md` using the bulletproof POSIX regex.
     2. Planning-health validation: Check disjointness and referential integrity. Block if violations exist.
4. **Issue Archival Workflow**:
   - **With a Plan**: `/aapp-done <plan>` moves the target issue row from `ISSUES.md` to `000-issues-archive.md` upon plan verification, filling in the verified commit hash and archiving the plan.
   - **Direct (Non-Promoted) Fixes**: The committer manually relocates the row to `000-issues-archive.md` (recording the target release milestone or post-commit hash) and commits both files.
5. **Non-Destructive Guidance at Init Time (`lib/cmd_init.sh`)**:
   In arbitrary wild codebases, `ISSUES.md` may exist in custom formats (Jira dumps, prose, bullet lists). `aapp init` must **never destructively alter** or corrupt arbitrary existing files:
   - If an existing non-flat `ISSUES.md` is detected, `cmd_init.sh` leaves it untouched and prints a clean informational notice directing the developer to `MANUAL.md` and `templates/issues.md` to format it at their own pace.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Templates & Taxonomy Specification
- [x] Task 1.1: Rewrite `templates/issues.md` into the flat database table format with `Sev`, `Type`, `Date`, and clean unpadded `#<num>` IDs.
- [x] Task 1.2: Add extensible `Type` taxonomy documentation in `templates/issues.md` and `MANUAL.md`.
- [x] Task 1.3: Author starter template `templates/done-issues-archive.md` for `.plans/done/000-issues-archive.md`.
- [x] Task 1.4: Update `templates/issues_road_map.md` to include `## ⭐ User Priority (Pinned / Immediate Human Focus)` and `## 📥 Triage (Incoming / Unsequenced)`.

### Phase 2: Engine, Health & Skill Synchronization
- [x] Task 2.1: Update `lib/cmd_status.sh` to be strictly read-only, remove legacy parser workarounds (`sed` cutoff and unanchored grep), and non-destructively surface roadmap drift and unsequenced issues.
- [x] Task 2.2: Author shared integrity check module `lib/planning_health.sh` verifying the three pairs (`ISSUES ↔ archive`, `roadmap ↔ ISSUES`, and format/status validity) with numerical ID normalization and dedicated table row matcher.
- [x] Task 2.3: Update `templates/aapp-pre-commit` to use bulletproof POSIX ID-anchored auto-prune regex for `issues_road_map.md` and detect-and-block validation for `ISSUES.md` resolved rows.
- [x] Task 2.4: Update `templates/skills/aapp-done/SKILL.md` to relocate resolved issues to `000-issues-archive.md` and prune roadmap entries upon plan completion.
- [x] Task 2.5: Update `lib/cmd_init.sh` to check for existing custom `ISSUES.md` files non-destructively and print formatting guidance to `MANUAL.md`.
- [x] Task 2.6: Run `aapp init` to propagate updated templates into `.githooks/` and `.agents/skills/` without violating Section 2 write guards.

### Phase 3: Repository Migration & Data Integrity Verification
- [x] Task 3.1: Create `.plans/done/000-issues-archive.md` and migrate all 49 historical resolved issues from `.plans/ISSUES.md` using unpadded integer IDs.
- [x] Task 3.2: Log the missing row for `#64` (`Status enum is not enforced in write-guard/pre-commit`) into `.plans/ISSUES.md` and prune its unworked note from `.plans/pickup.md`.
- [x] Task 3.3: Reformat `.plans/ISSUES.md` into the single flat table containing all 15 active open issues (`#49`–`#60`, `#62`–`#64`).
- [x] Task 3.4: **Count-Preservation Assertion**: Run an automated ID set-difference script verifying `49 (archived) + 15 (active) = 64 (unique project issues #01..#64)`. Assert zero dropped IDs and zero duplicate collisions.
- [x] Task 3.5: Update `.plans/issues_road_map.md` with the new `#<num>` syntax and `⭐ User Priority` header.

### Phase 4: Documentation & Test Verification
- [x] Task 4.1: Update `MANUAL.md` and `README.md` documenting the Flat Issue Ledger, Domain Taxonomy, Direct-Fix Archival, and Relocation Invariant.
- [x] Task 4.2: Update `tests/install_test.sh` and `tests/pre-commit_test.sh` with assertions for flat template generation, bulletproof POSIX auto-pruning, detect-and-block validation, and referential integrity checks.
- [x] Task 4.3: Verify all test suites pass (all 102+ test cases across `install_test.sh`, `pre-commit_test.sh`, and `write-guard_test.sh`) and align test count in `ISSUE-063`.
- [x] Task 4.4: Record changelog entry in `CHANGELOG.md` under `[Unreleased]`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [x] `templates/issues.md` -> Flat single-table schema with Sev, Type, Date, # ID.
- [x] `templates/issues_road_map.md` -> Add ⭐ User Priority section and # ID format.
- [x] `NEW FILE` -> `templates/done-issues-archive.md` -> Template for historical issue archive ledger.
- [x] `lib/cmd_status.sh` -> Read-only status briefing, delete workarounds, non-destructive drift reporting.
- [x] `NEW FILE` -> `lib/planning_health.sh` -> Shared planning-health integrity validator for hooks and CLI.
- [x] `templates/aapp-pre-commit` -> Bulletproof POSIX auto-pruning and detect-and-block Relocation Invariant.
- [x] `templates/skills/aapp-done/SKILL.md` -> Update aapp-done procedure to relocate issues to archive ledger.
- [x] `lib/cmd_init.sh` -> Non-destructive advisory for existing custom ISSUES.md files.
- [x] `templates/AGENTS.md` -> Document Relocation Invariant, taxonomy, and issue archival.
- [x] `MANUAL.md` -> Comprehensive documentation of issue taxonomy and archival.
- [x] `README.md` -> Update structural trees and issue management overview.
- [x] `CHANGELOG.md` -> Document flat issue ledger evolution under [Unreleased].
- [x] `tests/install_test.sh` -> Regression coverage for new templates, non-destructive init, and propagation.
- [x] `tests/pre-commit_test.sh` -> Regression coverage for POSIX auto-pruning, detect-and-block validation, and integrity validation.
- [x] `.plans/ISSUES.md` -> Migrate active issues to flat table, update ISSUE-063 count, and add missing #64.
- [x] `.plans/issues_road_map.md` -> Reformat active board with # IDs and User Priority.
- [x] `.plans/pickup.md` -> Prune digested ISSUE-064 entry.
- [x] `NEW FILE` -> `.plans/done/000-issues-archive.md` -> Master archive ledger of resolved issues.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/aapp-pre-commit` -> Protected by Section 2 self-protection. Propagated from `templates/aapp-pre-commit` via `aapp init`.
- [ ] `.agents/skills/aapp-done/SKILL.md` -> Protected by Section 2 self-protection. Propagated from `templates/skills/` via `aapp init`.
- [ ] `.agents/AGENTS.md` -> Delimited protocol block generated from `templates/AGENTS.md` via `aapp init`.
- [ ] `aapp` -> Core executable version string remains stable; version bumping belongs to the release preflight workflow (/aapp-release).
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
* **2026-09-14:** Refined blueprint following adversarial peer review rounds 1 & 2 (Claude red team audits):
  - **Engine Protection**: Moved `.githooks/aapp-pre-commit` and `.agents/skills/aapp-done/SKILL.md` to Out of Bounds (protected by write-guard Section 2); added Task 2.6 to propagate via `aapp init`.
  - **POSIX Bulletproof Roadmap Auto-Prune**: Fixed regex portability and backtick tolerance with `^[[:space:]]*([0-9]+\.|-[[:space:]]*\[[ xX]?\]|\*)[[:space:]]*`?#?[0-9]+`?.*(✅|[Rr]esolved)`.
  - **Separate Matchers**: Dedicated table-row matcher `^[[:space:]]*\|[[:space:]]*`?#?[0-9]+`?.*(✅|[Rr]esolved)` for `ISSUES.md`.
  - **Detect-and-Block Invariant**: Replaced unsafe pre-commit content transforms and non-existent commit hash guessing with strict detect-and-block validation.
  - **Read-Only Status**: Restored `cmd_status.sh` to strictly read-only, non-destructive drift reporting, preserving worktree hygiene and CI safety.
  - **Three-Pair Planning-Health Engine**: Consistency verification across `ISSUES ↔ archive`, `roadmap ↔ ISSUES`, and `pickup ↔ ISSUES` in `lib/planning_health.sh` with integer normalization.
  - **Active Range & Missing #64**: Corrected active range to `#49`–`#60`, `#62`–`#63` (14 items) and added Task 3.2 to author the missing `#64` detail row in `ISSUES.md`.
  - **Count-Preservation Assertion**: Added explicit Task 3.4 asserting `49 archived + 15 active = 64 unique IDs` with an automated set diff.
  - **Non-Destructive Init Guidance**: Specified safe advisory guidance in `lib/cmd_init.sh` for existing codebases with custom `ISSUES.md` layouts.
  - **Release Workflow Separation**: Confirmed that version bumping belongs strictly to the formal `/aapp-release` workflow upon milestone completion, keeping feature plans focused on capability implementation.
