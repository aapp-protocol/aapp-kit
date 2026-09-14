# 🗺️ Plan P-13: Plan IDs, ADR-Style Filenames & Command Shorthand Resolution
* **Created:** 2026-09-15 | **Last Refined:** 2026-09-15
* **Target Issue / Milestone:** Ergonomic Enhancement (Plan Lane Identity & CLI/Skill Shorthand)
* **Plan ID:** P-13
* **Status:** 🔴 Under Review
<!-- Status must be exactly ONE of: 🔴 Under Review | 🟡 Refining | 🟢 Ready for Execution | 🚫 BLOCKED -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Every commit you make must include your co-author trailer (e.g. `Co-authored-by: Antigravity <antigravity@google.com>`).
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.

> ### 🔒 Execution Note: engine copies are write-protected
> `blast-radius-guard` Section 2 hard-blocks `.githooks/*` and `.agents/skills/aapp-*`. Never edit those directly. Edit `templates/` and run `aapp init` to propagate.

> ### 🚧 Do NOT introduce version numbers
> This project has no git tag and no release. `AAPP_VERSION` is a placeholder. Do not add, bump, or infer a version anywhere in this plan's execution.

---

## 1. Context & Architectural Goal

**What.** Establish a canonical numbering standard for blueprints (`P-<num>` / `P<NN>`), adopt chronological ADR-style file naming (e.g. `P09-guard-path-authorization.md`), and build a zero-dependency POSIX shorthand resolver for all lifecycle skills (`/aapp-freeze`, `/aapp-done`, `/aapp-digest`) and CLI commands.

**Why.**
1. **Ergonomic Friction & Typing Fatigue:** Today, interacting with blueprints requires typing or copy-pasting lengthy file paths like `/aapp-freeze plan-feature-aapp-flat-issues-and-archival.md` (55+ characters). This is tedious, error-prone in CLI and chat environments, and clutters cross-agent handoffs.
2. **Loss of Chronological Hierarchy:** Filesystem listings (`ls .plans/current/`, `ls .plans/done/`) sort purely alphabetically rather than chronologically by architecture sequence.
3. **Strict Lane Separation Invariant:** The workspace strictly separates the **Issue Lane** (`ISSUES.md`, using `#1`..`#64` or `ISSUE-064`) from the **Plan Lane** (`state_matrix.md`). Plans cannot use bare numbers like `#8` without creating namespace collisions and confusing whether a handle refers to a bug or an implementation blueprint. A distinct `P-<num>` namespace solves this completely.
4. **Multi-Agent Interoperability:** Compact canonical identifiers (`P-9`, `P-13`) enable crisp, unambiguous context transfer across heterogeneous agents (Claude Code, Google Antigravity, Cursor, Codex) without copy-pasting brittle 50-character strings.

**Constraints.**
* Zero-dependency POSIX bash (`/bin/sh` and `/bin/bash` compatible). No python or jq required.
* Complete backward compatibility: existing unnumbered plans in `.plans/done/` must remain valid and discoverable.
* Deterministic resolution: shorthand expansion must resolve unambiguously or cleanly fail with helpful candidate listings if ambiguous.

---

## 2. Technical Blueprint

### A. The Plan Identifier Standard (`P-<num>`)
1. **Syntax & Canonical Token:**
   - Standard token format: `P-<num>` (e.g. `P-1`, `P-8`, `P-13`) in prose, status reporting, and state matrices.
   - Padded token format in filenames: `P<NN>-<slug>.md` (e.g. `P09-guard-path-authorization.md`, `P13-plan-ids-and-shorthand-resolution.md`) to guarantee natural filesystem sorting up to 99 plans, scaling seamlessly to `P<NNN>` as needed.
2. **Plan Header Contract (`templates/plan-template.md`):**
   ```markdown
   # 🗺️ Plan P-XX: [Feature or Refactor Name]
   * **Created:** YYYY-MM-DD | **Last Refined:** YYYY-MM-DD
   * **Target Issue / Milestone:** #[Issue ID or Milestone]
   * **Plan ID:** P-XX
   * **Status:** 🔴 Under Review
   ```
3. **Archive Ledger & State Matrix Alignment:**
   - In `.plans/state_matrix.md`:
     `- 🔴 **P-09**: [P09-guard-path-authorization.md](current/P09-guard-path-authorization.md) — Guard Path Authorization...`
   - In `.plans/done/000-archive-ledger.md`: Add a `Plan ID` column:
     `| Date Completed | Plan ID | Plan File | Target Issue / Milestone | Verification Commit | Impact Summary |`

### B. Shorthand Resolver Engine (`lib/plan_resolver.sh`)
Author a centralized, reusable POSIX resolution routine `resolve_plan_path`:

```bash
# resolve_plan_path <query> [search_scope: current|done|all] [repo_root]
# Resolves <query> to an existing relative path under .plans/
# Supports:
#   1. Exact relative/absolute filepath (.plans/current/P09-guard-path-authorization.md)
#   2. Plan ID: "P-9", "p-9", "P09", "p9", "9"
#   3. Slug keyword: "guard-path", "remote-sync", "flat-issues"
#   4. Omitted query: If only 1 plan exists in the target scope, resolves automatically!
```

**Resolution Algorithm:**
1. **Direct Path Check:** If `<query>` exists on disk as a file, return it immediately.
2. **Single Plan Default:** If `<query>` is empty and exactly one `.md` blueprint exists in `.plans/current/`, resolve to that blueprint. If multiple exist, return exit code 1 with a numbered list of choices.
3. **ID Matcher:**
   - Normalize `<query>` by stripping leading `P-`, `p-`, `P`, `p` or `#`.
   - If remainder is numeric (`^[0-9]+$`): match filenames matching `P0*<num>-*.md` or inspect headers for `* **Plan ID:** P-0*<num>`.
4. **Slug / Keyword Substring Matcher:**
   - Perform case-insensitive substring search across blueprint filenames in `.plans/<scope>/`.
5. **Ambiguity & Failure Diagnostics:**
   - If 0 matches: Output `❌ Plan '<query>' not found.` followed by a list of available active blueprints.
   - If >1 matches: Output `⚠️ Ambiguous plan reference '<query>'. Multiple candidates match:` followed by candidate paths.

### C. Skill & Lifecycle Command Integration
Update the canonical skill instructions in `templates/skills/`:
1. **`/aapp-freeze <plan>`**:
   - Accepts `<plan>` as ID (`P-9`, `9`), slug (`guard-path`), or filename.
   - Invokes resolver to identify target file in `.plans/current/`.
2. **`/aapp-done <plan>`**:
   - Accepts shorthand reference; resolves plan; moves to `.plans/done/`; records completion in `000-archive-ledger.md` using its `Plan ID`.
3. **`/aapp-digest <idea>`**:
   - When scaffolding a new plan, scans highest existing Plan ID across `.plans/current/` and `.plans/done/`, increments by 1, and scaffolds `P<NN>-<slug>.md` with `* **Plan ID:** P-<NN>`.
4. **`/aapp-status` (`lib/cmd_status.sh`)**:
   - Formats active blueprints in Section [3/4] as:
     `• P-09 [🔴 Under Review] Guard Path Authorization (P09-guard-path-authorization.md)`

### D. Integrity & Planning-Health Engine (`lib/planning_health.sh`)
Extend `planning_health.sh` with **Pair 4: Plan ID Uniqueness & Reference Integrity**:
- Ensures every blueprint in `.plans/current/` has a unique, non-colliding `Plan ID`.
- Verifies that `Plan ID` in the header matches filename prefix where applicable.
- Verifies that `state_matrix.md` and `000-archive-ledger.md` references resolve cleanly.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Resolver Engine & Health Validator
- [ ] Task 1.1: Author `lib/plan_resolver.sh` implementing POSIX `resolve_plan_path` with ID matching, slug matching, single-plan defaulting, and diagnostic formatting.
- [ ] Task 1.2: Add Pair 4 validation (`check_pair4_plan_id_integrity`) to `lib/planning_health.sh`.
- [ ] Task 1.3: Author unit test suite `tests/plan_resolver_test.sh` covering exact paths, numeric IDs (`P-9`, `9`, `P09`), slugs, ambiguities, and empty defaults.

### Phase 2: Status & CLI Integration
- [ ] Task 2.1: Update `lib/cmd_status.sh` to extract and display Plan IDs alongside filenames and status badges in Pillar [3/4].
- [ ] Task 2.2: Update `aapp` CLI entry points if applicable to expose helper resolution.

### Phase 3: Templates, Governance Rules & Universal Skills
- [ ] Task 3.1: Update `templates/plan-template.md` to include `Plan ID` field in header.
- [ ] Task 3.2: Update `templates/state_matrix.md` and `templates/done-archive-ledger.md` schema with Plan ID columns.
- [ ] Task 3.3: Update `templates/skills/aapp-freeze/SKILL.md`, `templates/skills/aapp-done/SKILL.md`, and `templates/skills/aapp-digest/SKILL.md` to document shorthand resolution.
- [ ] Task 3.4: Update `templates/AGENTS.md` to document Plan ID syntax, ADR naming rules, and the Two Lanes namespace distinction.
- [ ] Task 3.5: Run `aapp init` to propagate templates into `.agents/skills/` and `.agents/AGENTS.md`.

### Phase 4: Retroactive Indexing & Migration of Existing Blueprints
- [ ] Task 4.1: Index existing 9 archived plans in `.plans/done/000-archive-ledger.md` with retroactive IDs `P-01` through `P-08` (and `P-00` for `foundation-setup.md`).
- [ ] Task 4.2: Rename and assign IDs to active Incubator plans:
  - `P-09`: `P09-guard-path-authorization.md`
  - `P-10`: `P10-remote-sync.md`
  - `P-11`: `P11-airgapped-pickup.md`
  - `P-12`: `P12-lifecycle-hooks.md`
  - `P-13`: `P13-plan-ids-and-shorthand-resolution.md` (this blueprint)
- [ ] Task 4.3: Update `.plans/state_matrix.md` with new filenames and `P-` ID prefixes.

### Phase 5: Test Suite Expansion & Documentation
- [ ] Task 5.1: Update `tests/install_test.sh` and `tests/pre-commit_test.sh` to verify Plan ID handling and resolver availability.
- [ ] Task 5.2: Run all test suites (`tests/install_test.sh`, `tests/pre-commit_test.sh`, `tests/write-guard_test.sh`, `tests/plan_resolver_test.sh`).
- [ ] Task 5.3: Update `MANUAL.md` and `README.md` with Plan ID documentation and shorthand command examples.
- [ ] Task 5.4: Record all changes in `CHANGELOG.md` under `[Unreleased]`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `lib/plan_resolver.sh` -> Reusable POSIX plan resolution helper.
- [ ] `NEW FILE` -> `tests/plan_resolver_test.sh` -> Test suite for plan ID & shorthand resolution.
- [ ] `lib/planning_health.sh` -> Add Pair 4 plan ID integrity validation.
- [ ] `lib/cmd_status.sh` -> Display Plan IDs in Pillar 3 reporting.
- [ ] `templates/plan-template.md` -> Add `Plan ID` header and metadata fields.
- [ ] `templates/state_matrix.md` -> Incorporate `Plan ID` column/prefix in incubator and greenlight zones.
- [ ] `templates/done-archive-ledger.md` -> Incorporate `Plan ID` column in completed plans table.
- [ ] `templates/skills/aapp-freeze/SKILL.md` -> Document shorthand resolution in freeze skill.
- [ ] `templates/skills/aapp-done/SKILL.md` -> Document shorthand resolution in done skill.
- [ ] `templates/skills/aapp-digest/SKILL.md` -> Document auto-incrementing ID assignment in digest skill.
- [ ] `templates/AGENTS.md` -> Formalize Plan ID specification and Two Lanes namespace distinction.
- [ ] `.agents/AGENTS.md` -> Updated via template sync.
- [ ] `.agents/skills/aapp-freeze/SKILL.md` -> Updated via template sync.
- [ ] `.agents/skills/aapp-done/SKILL.md` -> Updated via template sync.
- [ ] `.agents/skills/aapp-digest/SKILL.md` -> Updated via template sync.
- [ ] `MANUAL.md` -> User documentation for plan IDs and shorthand commands.
- [ ] `README.md` -> Feature description for plan ergonomics.
- [ ] `CHANGELOG.md` -> Keep a Changelog entries under `[Unreleased]`.
- [ ] `.plans/done/000-archive-ledger.md` -> Add retroactive Plan IDs (P-00 to P-08).
- [ ] `.plans/state_matrix.md` -> Update active incubator list with P-09 to P-13.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Engine git hooks must never be edited directly (tamper protection).
- [ ] `templates/blast-radius-guard.sh` -> Guard logic unchanged (preserves existing blast radius rules).
- [ ] `lib/cmd_init.sh` -> Preserve existing init flow unless adding `lib/plan_resolver.sh` distribution.

---

## ❓ 5. Open Questions (Optional / Gate)

* [ ] **Question 1: Historical File Renaming in `done/`:** Should historical files in `.plans/done/` actually be renamed on disk (e.g. `mv plan-feature-aapp-flat-issues-and-archival.md P08-flat-issues-and-archival.md`), or should they keep their existing filenames on disk and only be assigned IDs (`P-08`) in `000-archive-ledger.md`? *(Renaming them provides clean `ls` ordering; keeping filenames avoids breaking historical commit links).*
* [ ] **Question 2: Leading Zero Padding:** Should IDs pad to 2 digits (`P-01`, `P-09`, `P-10`) or remain unpadded like issues (`P-1`, `P-9`, `P-10`)? Recommendation: Filenames pad to 2 digits (`P09-...`) for lexicographical filesystem sorting, but resolver tolerates both `P-9` and `P-09` interchangeably.

---

## 📦 6. Change Log & Refinement History
* **2026-09-15:** Drafted initial blueprint `plan-feature-aapp-plan-ids-and-shorthand-resolution.md` (P-13) based on user ergonomics pickup. Established `P-<num>` standard, shorthand resolution algorithm, and state matrix alignment.
