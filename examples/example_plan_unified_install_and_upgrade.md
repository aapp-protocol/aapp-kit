# 🗺️ Plan: Unified Deterministic Install & Upgrade via `aapp-init`

* **Created:** 2026-09-08 | **Last Refined:** 2026-09-08
* **Target Issue / Milestone:** —
* **Status:** 🟢 Ready for Execution
<!-- Status must be exactly ONE of: 🔴 Under Review | 🟡 Refining | 🟢 Ready for Execution | 🚫 BLOCKED -->

---

## 1. Context & Architectural Goal

AAPP currently treats initialization as a one-time operation: if a target file exists, it skips it. This creates three critical problems:
1. **Adoption Friction**: When adopting AAPP in a repository with an existing `AGENTS.md`, the existing file is kept untouched, but it lacks the AAPP slash commands (`/status`, `/digest`, `/freeze`, `/done`, `/release`), Changelog rules, and Blast Radius rules.
2. **The Upgrade Barrier**: When new AAPP versions ship (with new hooks, bug fixes, or workflow improvements), running `aapp-init` skips all existing files, leaving projects stranded on old versions unless manually updated.
3. **The LLM Reliability Risk**: Asking an AI coding agent to merge upstream templates byte-for-byte is error-prone (agents hallucinate, drop regexes, omit edge-case lines, or summarize strict rules).

**Goal:** Transform `aapp-init` into a **single, zero-parameter command** that handles **Initial Setup**, **Adoption into Existing Projects**, and **Future Upgrades** with 100% bit-exact determinism in native Bash without staging folders or LLM copying.

---

## 2. Technical Blueprint & Architecture

```text
                                `aapp-init` executed
                                         │
                   ┌─────────────────────┴─────────────────────┐
                   ▼                                           ▼
         [INFRASTRUCTURE SCRIPTS]                      [RULE & DOC FILES]
    (.githooks/*, .claude/settings.json)               (.agents/AGENTS.md)
                   │                                           │
     Updated directly byte-for-byte              Does file contain AAPP markers?
     from template (100% bit-exact).                     ╱           ╲
                   │                                   YES            NO
                   │                                   ╱                ╲
                   │                    Replaces ONLY the block         Appends the AAPP block
                   │                    between markers. Custom         with markers at the end.
                   │                    user rules untouched!           Existing rules untouched!
                   │                                   │                         │
                   └───────────────────┬───────────────┴─────────────────────────┘
                                       ▼
                      Records version stamp (e.g. v1.0.0)
                      in git worktrees and exits 0!
```

---

### 2.1 Single Source of Truth for Version (`AAPP_VERSION`)
* Define `AAPP_VERSION="1.0.0"` at the top of `aapp-init` and `aapp-install`.
* Add `-v` / `--version` flags to both binaries to output `aapp v1.0.0`.
* Delimited block headers dynamically use `$AAPP_VERSION` to tag the installed block: `<!-- AAPP-PROTOCOL:START v1.0.0 -->`.

---

### 2.2 Delimited Block Protocol (`.agents/AGENTS.md`)

`templates/AGENTS.md` encloses all AAPP protocol invariants between structured, machine-parseable comment tags:

```markdown
<!-- AAPP-PROTOCOL:START v1.0.0 -->
## 🤖 Asymmetric Agent Planning Protocol (AAPP) & Workflow Commands
... (Attribution trailers, Blast Radius rules, Two Lanes, Slash commands, Triage) ...
<!-- AAPP-PROTOCOL:END -->
```

#### Behavior Modes in `aapp-init`:
1. **Fresh Install** (No `AGENTS.md` exists):
   - Copies `templates/AGENTS.md` with default headers and markers into `.agents/AGENTS.md`.
2. **Legacy Flat Root Migration** (`/AGENTS.md` exists at repo root, but `.agents/` was not yet mounted):
   - Migrates content into `.agents/AGENTS.md`, appends the AAPP delimited block, and deletes the root duplicate.
3. **Adoption** (`.agents/AGENTS.md` exists, but has NO markers):
   - Preserves all existing custom rules untouched.
   - Appends the `<!-- AAPP-PROTOCOL:START v1.0.0 -->...<!-- AAPP-PROTOCOL:END -->` block directly to the end of `.agents/AGENTS.md`.
4. **Upgrade** (`.agents/AGENTS.md` exists AND has markers):
   - Extracts the latest block from `templates/AGENTS.md`.
   - Uses an exact, single-pass `awk` block replacer to swap only the content between `<!-- AAPP-PROTOCOL:START ... -->` and `<!-- AAPP-PROTOCOL:END -->`.
   - **All user-written custom rules before and after the markers remain 100% untouched.**

---

### 2.3 Deterministic Infrastructure & Worktree Commits

For pure enforcement code where bit-exact execution is mandatory:
* **`.githooks/blast-radius-guard`**: Refreshed directly from `templates/blast-radius-guard.sh` and chmodded `+x`.
* **`.githooks/pre-commit`**: Refreshed directly from `templates/pre-commit` and chmodded `+x`.
* **`.claude/settings.json`**:
  - If missing: created with the `PreToolUse` matcher for `.githooks/blast-radius-guard`.
  - If existing: safely parses JSON and adds/updates the `PreToolUse` hook matcher **without clobbering** existing custom tool configurations or environment variables.
* **Worktree Commits on Upgrade**:
  - If `.agents/AGENTS.md` was modified during upgrade $\rightarrow$ commits with `chore(aapp): upgrade protocol to v$AAPP_VERSION` inside the `agents` worktree.
  - If `.githooks/*` was modified during upgrade $\rightarrow$ commits with `chore(aapp): upgrade blast-radius engine to v$AAPP_VERSION` inside the `githooks` worktree.
  - If already up to date $\rightarrow$ skips committing for 100% idempotency.

---

### 2.4 Documentation Anchors (`CODEMAP.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `ISSUES.md`)
* If missing: scaffolded from templates.
* If existing: preserved untouched (never overwritten, as these are project-owned documents).

---

### 2.5 Console Banners & User Experience

* **Fresh Project Output**:
  ```text
  ✨ Multi-Orphan Worktree Setup Complete (AAPP v1.0.0)!
  ➡️  Planning workspace:   .plans/    (branch: 'plans')
  ➡️  Agent rules & ctx:    .agents/   (branch: 'agents')
  ➡️  Git hooks engine:     .githooks/ (branch: 'githooks')
  ```

* **Adoption Output (Existing project, rules appended)**:
  ```text
  ✨ AAPP Protocol v1.0.0 adopted into existing .agents/AGENTS.md!
     Existing project rules were preserved untouched.
  ```

* **Upgrade Output (Existing project, rules updated)**:
  ```text
  ✨ AAPP Protocol updated to v1.0.0 in .agents/AGENTS.md & .githooks/!
     Existing custom project rules and hooks preserved untouched.
  ```

* **Idempotent Re-Run Output**:
  ```text
  ✨ AAPP Protocol is already up to date (v1.0.0).
  ```

---

## 3. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `aapp-init` -> Add version constant, marker detection, block insertion/replacement logic, infrastructure refresh, flat root migration, and `.claude/settings.json` non-destructive merge
- [ ] `aapp-install` -> Add version constant and `-v`/`--version` support
- [ ] `templates/AGENTS.md` -> Wrap AAPP protocol invariants with `<!-- AAPP-PROTOCOL:START v1.0.0 -->` and `<!-- AAPP-PROTOCOL:END -->`
- [ ] `tests/install_test.sh` -> Add test cases for marker replacement on upgrade, appending on adoption, flat root migration, and idempotent re-runs
- [ ] `README.md` -> Document the unified install/upgrade workflow and marker protocol
- [ ] `MANUAL.md` -> Document the block delimiter specification and upgrade mechanics

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/pre-commit` -> Commit-time hook enforcement engine is frozen
- [ ] `templates/blast-radius-guard.sh` -> Write-time guard enforcement engine is frozen
- [ ] `tests/pre-commit_test.sh` -> Pre-commit test suite is frozen
- [ ] `tests/write-guard_test.sh` -> Write-guard test suite is frozen

---

## 4. Deleted Functionalities & Cleanup Checklist

### 🗑️ Deleted Functionalities
- [ ] **Delete Passive Skipping of `AGENTS.md`**: No longer leave existing `AGENTS.md` orphaned without protocol rules.
- [ ] **Delete `--cleanup` Flag Dependency**: Since `aapp-init` now automatically adopts and upgrades without leaving unmerged conflicts, `aapp-kit/` is always safely consumed on success. `--cleanup` becomes a harmless legacy no-op.
- [ ] **Delete "Conflict Warning Block" for `AGENTS.md`**: Replaced by the positive **Adoption / Upgrade Banner** (`✨ AAPP Protocol adopted into .agents/AGENTS.md`).

### 🧪 Tests to Delete & Replace in `tests/install_test.sh`
- [ ] **DELETE / REPLACE Test 5**: `drop-in with conflict: aapp-kit/ kept and warning printed`
  - *Reason:* We no longer retain `aapp-kit/` when `AGENTS.md` exists; we adopt directly and consume `aapp-kit/`.
  - *Replacement:* Test that drop-in on existing project adopts rules and consumes `aapp-kit/`.
- [ ] **DELETE / REPLACE Test 6 & 7**: `--cleanup removes kit folder...`
  - *Reason:* `--cleanup` is no longer needed in the standard workflow.
  - *Replacement:* Retain a lightweight no-op test for backwards compatibility, and add primary tests for Adoption & Upgrade.
- [ ] **UPDATE Test 8**: `existing AGENTS.md and CODEMAP.md preserved untouched`
  - *Reason:* `CODEMAP.md` is preserved untouched, but `AGENTS.md` now preserves user rules AND appends the delimited AAPP block.
  - *Update:* Assert that custom user content is 100% preserved at the top and AAPP block is present at the bottom.
- [ ] **DELETE / REPLACE Test 9**: `warning block appears before success banner with exit 0`
  - *Reason:* Warning block is replaced by the positive Adoption/Upgrade output banner.

---

## 5. Implementation Checklist

### Phase 1: Delimited Block Template Updates
- [ ] Update `templates/AGENTS.md` with standard `<!-- AAPP-PROTOCOL:START v1.0.0 -->` and `<!-- AAPP-PROTOCOL:END -->` delimiters around the AAPP protocol sections.
- [ ] Ensure the template retains a top-level placeholder for project-specific rules above/below the delimited section.

### Phase 2: `aapp-init` Replacement Engine
- [ ] Define `AAPP_VERSION="1.0.0"` in `aapp-init` and `aapp-install` with `-v`/`--version` flag handling.
- [ ] Implement flat root `AGENTS.md` migration into `.agents/AGENTS.md`.
- [ ] Implement `sync_agent_rules()` in `aapp-init`:
  - Detect if `.agents/AGENTS.md` exists.
  - If not exists $\rightarrow$ standard copy from template.
  - If exists and contains `<!-- AAPP-PROTOCOL:START` $\rightarrow$ replace delimited block in-place using `awk`.
  - If exists and does NOT contain `<!-- AAPP-PROTOCOL:START` $\rightarrow$ append delimited block to the end of the file.
- [ ] Implement `sync_infrastructure()` in `aapp-init`:
  - Update `.githooks/blast-radius-guard` and `.githooks/pre-commit` byte-for-byte.
  - Chmod `+x` and verify syntax via `bash -n`.
  - Non-destructively ensure `.claude/settings.json` has `PreToolUse` hook matcher.
- [ ] Update commit logic in worktrees (`agents` and `githooks`) to record clean update commits only if files changed.
- [ ] Refine console banners to clearly report Fresh Install, Adoption, Upgrade, or Up-to-Date state.

### Phase 3: Regression Test Suite in `tests/install_test.sh`
- [ ] **Test Case 1 (Fresh Install)**: Fresh project receives `AGENTS.md` with delimiters.
- [ ] **Test Case 2 (Flat Root Migration)**: Legacy `/AGENTS.md` at repo root is migrated into `.agents/AGENTS.md` and root file is removed.
- [ ] **Test Case 3 (Adoption Mode)**: Existing project without delimiters has AAPP block appended; custom pre-existing rules preserved at top.
- [ ] **Test Case 4 (Upgrade Mode)**: Existing project with older v1.0 markers has AAPP block updated to v1.1 between markers; custom rules above and below untouched.
- [ ] **Test Case 5 (Infrastructure Upgrade)**: Existing `.githooks/pre-commit` and `.githooks/blast-radius-guard` updated to latest byte-for-byte.
- [ ] **Test Case 6 (Non-destructive Claude Settings)**: Existing custom `.claude/settings.json` preserves existing keys while wiring `PreToolUse`.
- [ ] **Test Case 7 (Idempotent Re-run)**: Re-running `aapp-init` when already up to date is a clean, harmless no-op with zero changes.
- [ ] **Test Case 8 (Drop-in Consumption on Adoption)**: Drop-in clone folder `aapp-kit/` is consumed on successful adoption.
- [ ] **Test Case 9 (Version Flags)**: `aapp-init -v` and `aapp-install --version` output valid version string.

### Phase 4: Documentation & Manual Updates
- [ ] Update `README.md` to highlight zero-parameter upgrade & adoption simplicity.
- [ ] Update `MANUAL.md` Section 8 with the Delimited Section specification.

---

## 5. Verification Matrix

```bash
# Run complete test verification suite (all suites must pass 100%)
./tests/install_test.sh && ./tests/pre-commit_test.sh && ./tests/write-guard_test.sh
```

| Suite | Scope | Target |
| :--- | :--- | :--- |
| `tests/install_test.sh` | Installer, Resolution, Adoption & Upgrade | 35+ cases passing with exit code 0 |
| `tests/pre-commit_test.sh` | Commit-Time Blast Radius | 12 cases passing |
| `tests/write-guard_test.sh` | Write-Time PreToolUse Guard | 26 cases passing |

---

## 7. Decisions & Technical Invariants Log

* **Q1: Why use `awk` instead of `sed` for block replacement?**
  * *Answer:* `awk` handles multi-line pattern replacements across arbitrary files without newline or regex delimiter escaping bugs that frequently plague multi-line `sed` scripts across BSD/GNU implementations.
* **Q2: What happens if a user customized something inside the AAPP block?**
  * *Answer:* The comment clearly warns `<!-- AAPP-PROTOCOL:START: DO NOT EDIT THIS BLOCK DIRECTLY; PLACE CUSTOM RULES OUTSIDE -->`. User rules outside the block are 100% protected.
* **Q3: Does this require any new CLI commands or flags?**
  * *Answer:* No. The user only ever types `aapp-init`. It detects whether the project is fresh, an adoption, or an upgrade automatically.
* **Q4: How are worktree commits managed during an upgrade?**
  * *Answer:* `aapp-init` checks `git status --porcelain` inside `.agents` and `.githooks`. If modified, it records an atomic update commit. If unchanged, it skips committing for complete idempotency.
