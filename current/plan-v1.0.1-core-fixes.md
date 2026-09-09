# 🗺️ Plan: AAPP v1.0.1 Core Engine, Layer 1 Write-Guard & Parser Fixes

* **Created:** 2026-09-09 | **Last Refined:** 2026-09-09
* **Target Issue / Milestone:** ISSUE-001, ISSUE-002, ISSUE-003, ISSUE-004, ISSUE-005, ISSUE-006, ISSUE-008, ISSUE-035, ISSUE-036
* **Status:** 🟢 Ready for Execution

---

## 1. Context & Architectural Goal

This blueprint resolves critical Layer 1 write-guard enforcement failures, path resolution bugs, destructive git fallbacks, and target parsing errors in the AAPP core engine:
1. **Layer 1 Claude Code Hook (`blast-radius-guard.sh`)**:
   - Claude Code `PreToolUse` requires an exit code of `2` (or JSON with `hookSpecificOutput.permissionDecision: "deny"`) to block tool execution; returning `exit 1` is treated as a non-blocking error.
   - Claude Code sends absolute paths in `tool_input.file_path`, whereas target matching rules are relative to the repository root.
2. **Blast Radius Parser (`blast-radius-guard.sh` & `aapp-pre-commit`)**:
   - Targets declared with `- [ ] `NEW FILE` -> `path`` in blueprints were dropping the target path because the parser captured `` `NEW FILE` `` and aborted line extraction.
   - Guard execution from subdirectories failed open when inspecting `.plans/current/`.
3. **Commit-Time & Pre-Commit Hook (`aapp-pre-commit`)**:
   - `--diff-filter=ACMR` excluded `D`, allowing deletions of Out-of-Bounds files.
   - `SKIP_BLAST_RADIUS=1` did not bypass `CHANGELOG.md` verification.
   - `CORE_CODE_REGEX` omitted shell files (`.sh`, `.bash`, `.zsh`) and CLI binaries.
4. **Safe Worktree Initialization (`cmd_init.sh`)**:
   - Replaced destructive `git rm -rf .` fallback with safe detached worktree creation.

---

## 2. Technical Blueprint

### 2.1 Layer 1 Fixes (`templates/blast-radius-guard.sh`)
- Normalize `TARGET_FILE` by stripping `$REPO_ROOT/` (or `$(git rev-parse --show-toplevel 2>/dev/null)/`).
- Change directory to `$REPO_ROOT` to ensure `.plans/current/*.md` scans succeed from any working directory.
- Update deny responses: emit valid `hookSpecificOutput` JSON or return `exit 2` when denying tool calls so Claude Code halts writes.

### 2.2 Parser Normalization (`templates/blast-radius-guard.sh` & `templates/aapp-pre-commit`)
- Strip both backticked and unbackticked prefix markers:
  ```awk
  sub(/^[[:space:]]*(`?(NEW FILE|MODIFY|DELETE|ADD|REPLACE)`?)?[[:space:]]*->[[:space:]]*/, "", line)
  ```

### 2.3 Pre-Commit Fixes (`templates/aapp-pre-commit`)
- Change `--diff-filter=ACMR` to `--diff-filter=ACMRD` so deletions are verified against Out-of-Bounds lists.
- Move `SKIP_BLAST_RADIUS=1` bypass check to the top before CHANGELOG enforcement.
- Add `sh|bash|zsh` to `CORE_CODE_REGEX`.

### 2.4 Safe Worktree Fallback (`lib/cmd_init.sh`)
- Check out orphan worktrees using detached worktree initialization without wiping the developer's main working tree.

---

## 💥 3. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/blast-radius-guard.sh` -> Fix Claude Code response payload, absolute path stripping, and target parsing.
- [ ] `templates/aapp-pre-commit` -> Fix backticked target parser, diff-filter deletions, escape hatch order, and core code regex.
- [ ] `lib/cmd_init.sh` -> Safe worktree fallback.
- [ ] `lib/cmd_status.sh` -> Quote plan file loop variables and update regex.
- [ ] `tests/pre-commit_test.sh` -> Add backticked marker and deletion test assertions.
- [ ] `tests/write-guard_test.sh` -> Add absolute path and JSON payload regression tests.
- [ ] `CHANGELOG.md` -> Document v1.0.1 fixes.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.agents/` -> Agent behavioural contracts.
- [ ] `LICENSE` -> License file.

---

## ❓ 4. Open Questions & Decision Matrix
* [x] **Question 1:** Should `SKIP_BLAST_RADIUS=1` bypass CHANGELOG.md check? -> **Yes**, emergency hotfix bypass must permit commits when emergency patches cannot stage changelog edits immediately.
* [x] **Question 2:** Should `CORE_CODE_REGEX` include shell scripts? -> **Yes**, `sh|bash|zsh` are core source files for CLI tooling.

---

## 📦 5. Change Log & Refinement History
* **2026-09-09:** Blueprint initialized and frozen for execution.
