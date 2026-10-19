---
title: Dual-Layer Blast Radius Enforcement Engine
description: Deterministic write-time and commit-time boundary enforcement, branch protection, and path containment in AAPP.
---

# 🛡️ Dual-Layer Blast Radius Enforcement Engine

AAPP provides deterministic safety by enforcing boundaries at two distinct moments in the development lifecycle:

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Developer / AI Agent
    participant Guard as Layer 1: blast-radius-guard (PreToolUse)
    participant Disk as Working Tree (Disk)
    participant Hook as Layer 2: aapp-pre-commit (Git Hook)
    participant Git as Git Object Store

    Dev->>Guard: Attempt file edit via AI Tool
    alt File outside Target Files OR in Self-Protection Perimeter
        Guard-->>Dev: ❌ Edit Denied (exit code 2 / hookSpecificOutput.permissionDecision: deny)
    else File matches Target Files or no active plans
        Guard->>Disk: ✅ Allow write to disk
    end

    Dev->>Disk: Stage files (`git add .`)
    Dev->>Hook: Run `git commit`
    alt CHANGELOG.md missing on code touch
        Hook-->>Dev: ❌ Refuse commit: CHANGELOG.md required
    else Staged file not in Target Files of any active plan
        Hook-->>Dev: ❌ Refuse commit: Blast Radius Violation
    else Active plan marked BLOCKED
        Hook-->>Dev: ❌ Refuse commit: Active plan is BLOCKED
    else All validations pass
        Hook->>Git: ✅ Commit recorded
    end
```

---

## Layer 1: Write-Time PreToolUse Guard (`blast-radius-guard`)

Located at `.githooks/blast-radius-guard`, this executable intercepts AI tool calls before disk writes occur (e.g. Claude Code's `PreToolUse` hook across `Write`, `Edit`, `MultiEdit`, `NotebookEdit`).

### Evaluation Order & Engine Pipeline:
1. **Input Parsing & Canonicalization**: Standardizes paths using zero-dependency POSIX lexical resolution, collapsing `.` and `..` without dereferencing symlinks to close path traversal escapes while preserving dual-path inode protection.
2. **Section 2 — Self-Protection Perimeter**: AI tools are strictly forbidden from modifying enforcement configuration and governance skills:
   - `.githooks/*`, `.git/hooks/*`, `.git/config`
   - `.claude/settings.json`, `.agents/claude/*`
   - `.agents/skills/aapp-*`, `.claude/skills/aapp-*`
   - `.cursor/rules/*`
3. **Section 2b — External Hard-Deny**: Inviolable credentials, shell startup files, and system binaries are blocked regardless of allowlist breadth:
   - Credentials & keys: `~/.ssh/*`, `~/.gnupg/*`, `~/.aws/*`, `~/.azure/*`, `~/.kube/*`, `~/.docker/config.json`, `~/.netrc`, `~/.npmrc`, `~/.pypirc`, `~/.git-credentials`
   - Git configs: `~/.gitconfig`, `~/.config/git/*`
   - Shell profiles & rc files: `~/.bashrc`, `~/.bash_profile`, `~/.zshrc`, `~/.zprofile`, `~/.profile`, `~/.config/fish/*`
   - Binaries & cron: `~/.local/bin/*`, `*/crontab`
4. **Section 2c — External Path Allowlist**: Authorizes agent scratchpads, memory stores, and caches outside the repository:
   - **Built-in multi-agent defaults**:
     - Claude Code: `$HOME/.claude/` (project memory, session state)
     - Google Antigravity: `$HOME/.gemini/` (artifacts, brain logs, scratchpads)
     - OpenAI Codex: `$HOME/.codex/`
     - Cursor: `$HOME/.cursor/`
     - XDG directories: `$XDG_CONFIG_HOME/`, `$XDG_DATA_HOME/`, `$HOME/.config/`, `$HOME/.local/share/`
     - Temporary scratchpads: `/tmp/`, `$TMPDIR/`, `/var/folders/`
   - **User-configurable allowlist**: Extend via git config:
     ```bash
     git config --add aapp.allowPath "$HOME/.local/state/myagent/"
     ```
   - **Trailing-slash normalization**: All allowlisted directories enforce strict trailing slashes to prevent prefix aliasing (`~/.claude/` never matches `~/.claude_fake/*`).
5. **Section 3 — Always-Allowed Repository Invariants**: Project architecture documents, package manifests, rules, and plans (`.plans/*`, `.agents/*`, `CHANGELOG.md`, `README.md`, `MANUAL.md`, `CHEATSHEET.md`, `COOKBOOK.md`, `docs/*`, etc.) are always permitted.
6. **Section 4 — Blast Radius Validation**: If an active, non-blocked plan exists in `.plans/current/*.md`, any write outside the plan's `### 📂 Target Files` (or listed in `### 🛑 Out of Bounds`) is blocked immediately with exit code 2 and a structured failure message.
7. **Tool-Scoped Boundary vs. Layer 2 Gate**: Layer 1 evaluates structured file-writing tools only (`Write`, `Edit`, `MultiEdit`, `NotebookEdit`). Because shell executions (`Bash`) carry command strings rather than structured paths, shell writes cannot be safely parsed; Layer 2 (`aapp-pre-commit`) serves as the strict, inescapable gate for all committed code.
8. **Fail-Open Resilience**: If no active plan exists, or on malformed input, normal repository files are permitted so developer workflows are never bricked.

---

## Layer 2: Commit-Time Pre-Commit Engine (`aapp-pre-commit`)

Located at `.githooks/aapp-pre-commit` (invoked directly or via `.githooks/pre-commit`), this Git hook runs on every `git commit`.

### Key Responsibilities:
1. **Runtime Reachability & Inspection-Only Gate**: Verifies that the `aapp` binary is reachable via `$PATH` or `$HOME/.local/bin/aapp`. Clones on machines without `aapp` installed enter a commit-blocking **Inspection-Only mode**, protecting against un-guarded code and plan desynchronization. Only native `git commit --no-verify` bypasses pre-commit.
2. **Adaptive Branch Protection**: Prevents accidental direct commits to stable production branches (`main`, `master`, `production`) whenever active development branches exist.
3. **Changelog Enforcement**: Whenever any source code file is modified, `CHANGELOG.md` must be staged. Rules files (`.agents/*`) and planning files (`.plans/*`) are exempt.
4. **Blast Radius Verification**: Compares all staged files against the union of `### 📂 Target Files` across all active blueprints in `.plans/current/*.md`.
5. **Concurrent Plan Support**: If two developers or agents work on separate active plans (`plan-a.md` and `plan-b.md`), files declared in *either* plan are permitted.
6. **Blocked Plan Refusal**: If a plan's status is `🟥 BLOCKED`, commits targeting its files are rejected until the human unblocks the plan.
7. **Syntax Validation**: Automatically runs syntax verification on staged files (e.g., Python `python3 -m py_compile`, PHP `php -l`, JSON syntax).
8. **Roadmap Hygiene**: Automatically prunes resolved issues (`✅` or `Resolved`) from `issues_road_map.md` (<5ms), keeping the work queue strictly focused on active items while permanent records remain in `ISSUES.md`.

---

## Adaptive Branch Protection & Repository Topologies

AAPP supports two primary development models, adapting automatically without requiring manual configuration:

### 1. Trunk-Based Development (Single Branch)
In single-branch repositories where developers or teams commit directly to `main` (or `master`):
- No separate development branch (`develop`, `dev`, `development`) exists.
- The pre-commit engine probes local branches (`refs/heads/*`) and remote tracking branches (`refs/remotes/*/*`).
- When no development branch is found, **the branch protection guard automatically fails open**, permitting all commits directly on `main`.

### 2. Dual-Branch Topology: Stable vs. Edge (Recommended)
In multi-branch repositories, AAPP enforces the **2-Rule Law**:
- **Branch Law**:
  - `main` is strictly **STABLE** (clean semantic release tags `vX.Y.Z`).
  - `develop` (or `dev`) is **EDGE** (active day-to-day engineering and feature development).
- **Release Law**:
  - Active engineering stays on `develop`.
  - Releases fast-forward cleanly into `main` before tagging:
    ```bash
    git checkout main
    git merge develop --ff-only
    git tag -a v1.2.0 -m "Release v1.2.0"
    ```

### Enforcement & Auto-Detection Algorithm
When committing on a protected branch (`main`, `master`, `production`), the pre-commit engine executes:
```sh
1. Is ALLOW_MAIN_COMMIT=1? -> Allow commit (emergency/release bypass).
2. Is aapp.protectStable configured to false? -> Allow commit (opt-out).
3. Is current branch in $PROTECTED_BRANCHES?
   -> Check if any branch in $DEV_BRANCHES exists:
      - git show-ref --verify --quiet "refs/heads/$DB" (local)
      - git show-ref --verify --quiet "refs/remotes/origin/$DB" (remote origin)
      - git show-ref --quiet -- "refs/remotes/*/$DB" (any remote)
   -> If dev branch exists: Block commit with instructions to switch branches.
   -> If no dev branch exists: Allow commit (trunk-based fallback).
```

### Configuration Options (`git config`)
You can fine-tune branch protection per-repository or globally:

| Git Config Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `aapp.protectStable` | bool | `true` | Set to `false` to disable branch protection entirely. |
| `aapp.protectedBranches` | string | `"main master production"` | Space-separated list of protected production branches. |
| `aapp.devBranch` | string | `"develop dev development"` | Space-separated list of candidate development branches; the first one present locally or on a remote is the development branch. Plan worktrees branch from it too. |

### Bypassing Branch Protection
- **Intentional Release or Hotfix Commit on `main`**:
  ```bash
  ALLOW_MAIN_COMMIT=1 git commit -m "hotfix: critical security patch"
  ```
- **Complete Blast Radius & Hook Bypass**:
  ```bash
  SKIP_BLAST_RADIUS=1 git commit -m "emergency bypass"
  ```

---

## Parsing Invariants & Prose Isolation

To prevent accidental scope widening, AAPP uses strict parsing invariants:

- **First-Backtick Rule**: Only the **first** backticked path on a list line in `### 📂 Target Files` is treated as a target path.
  ```markdown
  ### 📂 Target Files
  - [ ] `src/Auth/TokenManager.php` -> Refactor token rotation; see `src/Database/Connection.php` for reference.
  ```
  *Result*: Only `src/Auth/TokenManager.php` is in scope. `src/Database/Connection.php` is treated purely as prose.
- **Directory Prefix Matching**: If a target ends in `/` (e.g. `- [ ] `src/Billing/``), all files within that directory subtree are permitted.
- **Spaces in Filenames**: Correctly parses and matches filepaths containing spaces or special characters.

---

## Escape Hatches & Fail-Open Design

AAPP is designed to assist developers, not trap them.

- **Commit-Time Escape Hatch**:
  ```bash
  SKIP_BLAST_RADIUS=1 git commit -m "emergency: hotfix bypass"
  ```
  Setting `SKIP_BLAST_RADIUS=1` bypasses both CHANGELOG and Blast Radius validation.
- **No-Plan Grace Period**: If `.plans/current/` has no active markdown blueprints, the pre-commit hook allows all commits, ensuring bootstrapping and free-form human commits are never blocked.

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🍳 [Cookbook Catalog](../../COOKBOOK.md)
- 🏠 [Repository Overview](../../README.md)
