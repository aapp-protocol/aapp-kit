---
title: Troubleshooting Guide
description: Diagnosing and resolving common errors, blast-radius blocks, hook rejections, and state desynchronizations in AAPP.
---

# 🛠️ AAPP Troubleshooting Guide

This guide covers common errors, hook blocks, and edge cases encountered when operating AAPP, along with straightforward remediation steps.

---

## 1. Blast Radius Violations

### Symptom
An agent or developer attempts to edit a file, and the IDE or git hook returns:
```text
[AAPP BLAST RADIUS GUARD] Refused: 'src/components/Nav.jsx' is not in target files for P-38.
```

### Cause
The file being modified is not declared in the plan's `### 📂 Target Files` list under Section 4. The `blast-radius-guard` tool hook (pre-tool use) and `pre-commit` hook mechanically prevent modifications outside declared boundaries.

### Resolution
- **If the file should be modified:** The plan must be amended before editing. In the development worktree, run:
  ```bash
  aapp refine <plan-id> target src/components/Nav.jsx "Navigation header updates"
  ```
  Or edit Section 4 in the plan file directly and commit the plan refinement.
- **If the modification was accidental:** Revert the file changes immediately:
  ```bash
  git checkout -- src/components/Nav.jsx
  ```

---

## 2. Changelog Verification Errors

### Symptom
`git commit` fails with:
```text
[AAPP PRE-COMMIT] Error: CHANGELOG.md was not modified.
[AAPP PRE-COMMIT] Error: Changelog bullet exceeds 300 characters.
```

### Cause
AAPP enforces that every code change is covered by `CHANGELOG.md`, adhering to the single-line bullet invariant (strictly <= 300 characters, starting with `- ` under an appropriate version or `## [Unreleased]` heading).

### Resolution
1. Ensure your plan's `* **Changelog:**` line in the header is concise and <= 300 characters.
2. In plan mode (`aapp.changelogMode = plan`), the first commit via `aapp commit` automatically inserts the plan's changelog line.
3. For direct commits or issue fixes, manually add a bullet under `## [Unreleased]` in `CHANGELOG.md`:
   ```markdown
   ## [Unreleased]

   ### Fixed
   - Handle empty input gracefully in string parser (#42).
   ```

---

## 3. Worktree Pointer Desynchronization

### Symptom
Running `aapp status` inside a worktree reports `No active plan in development`, or `aapp commit` warns that the active plan cannot be determined.

### Cause
The local worktree buffer (`.git/aapp_active_plan` or worktree gitdir pointer) is missing or out of sync.

### Resolution
Explicitly set the active plan pointer for the current worktree:
```bash
aapp start <plan-id>
```
Or check existing active branches and plans:
```bash
aapp plan list
git worktree list
```

---

## 4. Release Pre-flight Failures

### Symptom
Running `aapp release` halts during Phase A pre-flight with an error message:
- `Dirty working tree: uncommitted changes detected`
- `Test suite failed with exit code 1`
- `Unmerged branches detected: feature/P42`

### Resolution
- **Dirty working tree:** Commit or stash your changes (`git stash`) before running `aapp release`.
- **Test failure:** Run `./aapp test strict` locally to locate failing assertions and fix them. Releases cannot bypass test validation.
- **Unmerged branches:** If branches have already been integrated, delete them (`git branch -d feature/P42`). If they are independent, verify reachability or proceed after acknowledging the warning.

---

## 5. Non-Interactive CLI Hanging

### Symptom
Automated test scripts or CI/CD pipelines hang when invoking `aapp release` or interactive prompts.

### Cause
Some virtual terminals or CI runners allocate a pseudo-TTY (`[ -t 0 ]` evaluates to true), waiting for interactive user input (`read -r`).

### Resolution
Redirect standard input from `/dev/null` or pass the non-interactive `--yes` flag:
```bash
aapp release v1.2.0 < /dev/null
```

---

## 6. Issue Table Relocation Violations

### Symptom
Pre-commit hook rejects edits to `.plans/ISSUES.md`:
```text
[AAPP PRE-COMMIT] Error: ISSUES.md contains resolved rows. Resolved issues must be relocated.
```

### Cause
A row in `ISSUES.md` was manually marked as `✅ Resolved`. AAPP enforces the Flat Issue Ledger & Relocation Invariant: resolved issues must be physically moved to `.plans/done/000-issues-archive.md`.

### Resolution
Do not manually edit status to `✅ Resolved`. Instead, use:
```bash
aapp issue close <num>
```
Or archive the implementing plan using:
```bash
aapp done <plan-id>
```
This automatically relocates the row to the archive ledger and removes it from active tracking.

---

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🍳 [Cookbook Catalog](../../COOKBOOK.md)
- 🏠 [Repository Overview](../../README.md)
