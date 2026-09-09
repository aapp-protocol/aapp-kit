# 🗺️ Plan: CLI Reliability, POSIX Fallback & Upgrade Robustness

* **Created:** 2026-09-09 | **Last Refined:** 2026-09-09
* **Target Issue / Milestone:** `ISSUE-009` (Batch 3: CLI, Init, Upgrade & POSIX Fallback Reliability Fixes)
* **Status:** 🟢 Ready for Execution

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Every commit you make must include your co-author trailer (e.g., `Co-authored-by: Antigravity <antigravity@google.com>` or `Claude <noreply@anthropic.com>`).
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.

---

## 1. Context & Architectural Goal

Batch 3 addresses reliability edge-cases across CLI commands (`init`, `upgrade`, `install`), pure POSIX fallbacks when `python3` is missing, and clean warning diagnostics:
* **`ISSUE-009`**: Add pure-POSIX JSON parsing & decision serialization in `blast-radius-guard.sh` so Layer 1 enforcement is 100% zero-dependency on systems without `python3`.
* **`ISSUE-010`**: Add explicit warning notice in `cmd_init.sh` when `.claude/settings.json` merge is skipped due to missing `python3`.
* **`ISSUE-013`**: Export `AAPP_VERSION` outside subshell in `cmd_upgrade.sh` and pass `AAPP_IS_UPGRADE=1` to suppress temporary folder consumption notice during upgrades.
* **`ISSUE-014`**: Update self-consumption check in `cmd_init.sh` and `cmd_install.sh` to exempt developer workspaces (`aapp-develop-kit` and `agent-planning-kit`) without adding double-dash parameters.
* **`ISSUE-015`**: Strengthen drop-in target repository detection in `cmd_init.sh` when run from nested subdirectories.
* **`ISSUE-017`**: Safeguard `sync_agent_rules` in `cmd_init.sh` against truncated/unclosed `<!-- AAPP-PROTOCOL:START -->` blocks without an `END` marker.
* **`ISSUE-018`**: Clean up unused variables (`IS_RESTORE`, `AAPP_IS_DROP_IN` assignments).
* **`ISSUE-019`**: Soften shell redirection claims in `README.md` to accurately describe write-time hook vs commit-time pre-commit boundaries.

---

## 2. Technical Blueprint

### 2.1 Pure POSIX Fallback in `blast-radius-guard.sh` (`ISSUE-009`)
* In `templates/blast-radius-guard.sh`:
  - When `python3` is absent, use POSIX `sed` / `awk` JSON field extraction for `tool_name` and `file_path`.
  - In `deny_action()`, when `TOOL_NAME` is set and `python3` is absent, format and output standard JSON payload:
    ```bash
    local escaped_reason
    escaped_reason=$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g')
    printf '{"decision":"deny","reason":"%s","hookSpecificOutput":{"permissionDecision":"deny"}}\n' "$escaped_reason"
    ```

### 2.2 Warning Diagnostics & Error Handling (`ISSUE-010`, `ISSUE-017`)
* In `lib/cmd_init.sh`:
  - When `.claude/settings.json` merge cannot run because `python3` is missing, emit clear actionable warning.
  - In `sync_agent_rules()`, if `START` marker is present but `END` marker is missing, log warning and preserve existing content rather than truncating file.

### 2.3 Upgrade & Development Workspace Protection (`ISSUE-013`, `ISSUE-014`, `ISSUE-018`)
* In `lib/cmd_upgrade.sh`:
  - Hoist `AAPP_VERSION` resolution outside subshell.
  - Set `AAPP_IS_UPGRADE=1` so `cmd_install.sh` suppresses temporary installer consumption notice.
* In `lib/cmd_init.sh` & `lib/cmd_install.sh`:
  - Protect development repository root directory names (`aapp-develop-kit` and `agent-planning-kit`) from self-consumption (`rm -rf`).
  - No double-dash flags added — maintains clean, flagless CLI design.
  - Remove dead variables (`IS_RESTORE`).

### 2.4 Documentation Softening (`ISSUE-019`)
* In `README.md`:
  - Clarify that write-time guard protects against agent IDE tool edits (`Write`, `Edit`, `NotebookEdit`), while direct shell commands (`cat > file`) are caught by the commit-time pre-commit hook.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Pure POSIX Fallback in Guard
- [ ] 1.1 Implement POSIX JSON serializer in `templates/blast-radius-guard.sh` `deny_action()`.
- [ ] 1.2 Copy to `.githooks/blast-radius-guard`.

### Phase 2: CLI Robustness & Upgrades
- [ ] 2.1 Update `lib/cmd_init.sh` for unclosed marker safety, missing python3 warning, and `aapp-develop-kit` protection.
- [ ] 2.2 Update `lib/cmd_upgrade.sh` to hoist `AAPP_VERSION` and handle upgrade suppression cleanly.
- [ ] 2.3 Update `lib/cmd_install.sh` to handle `AAPP_IS_UPGRADE` and protect `aapp-develop-kit`.

### Phase 3: Documentation & Verification
- [ ] 3.1 Soften shell tool description in `README.md` and `MANUAL.md`.
- [ ] 3.2 Add regression test coverage in `tests/write-guard_test.sh` asserting POSIX fallback JSON output without `python3`.
- [ ] 3.3 Add regression test in `tests/install_test.sh` for `aapp-develop-kit` protection and missing `END` marker.
- [ ] 3.4 Run full regression suite (`tests/install_test.sh`, `tests/pre-commit_test.sh`, `tests/write-guard_test.sh`).

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/blast-radius-guard.sh` -> POSIX JSON output fallback in `deny_action()`.
- [ ] `lib/cmd_init.sh` -> Unclosed marker protection, python3 warning, `aapp-develop-kit` protection.
- [ ] `lib/cmd_upgrade.sh` -> Subshell version export fix and upgrade flag.
- [ ] `lib/cmd_install.sh` -> Protect `aapp-develop-kit` and `AAPP_IS_UPGRADE`.
- [ ] `README.md` -> Soften shell redirection invariant claim.
- [ ] `MANUAL.md` -> Update POSIX fallback notes.
- [ ] `tests/write-guard_test.sh` -> Test JSON output under no-python3 simulation.
- [ ] `tests/install_test.sh` -> Test `aapp-develop-kit` folder protection and unclosed marker handling.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `LICENSE` -> License file.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified and backward-compatible)*

---

## 📦 6. Change Log & Refinement History
* **2026-09-09:** Initial draft created from `/digest ISSUE-009` (Batch 3: CLI Reliability, POSIX Fallback & Upgrade Robustness).
