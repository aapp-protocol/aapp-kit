# 🗺️ Plan: Remote Worktree Synchronization (`aapp push`, `aapp pull`, `aapp sync`)
* **Created:** 2026-09-10 | **Last Refined:** 2026-09-10
* **Target Issue / Milestone:** Milestone v1.1.0 (Remote Worktree Automation)
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
* **What**: Implement automated remote synchronization commands (`aapp push`, `aapp pull`, and `aapp sync`) for all active AAPP orphan worktrees (`.plans`, `.agents`, `.githooks`), with an **A/C Hybrid** configuration mechanism.
* **Why**: Currently, keeping remote repositories updated requires executing 3 separate `git -C <dir> push origin <branch>` commands (or 6 for bi-directional pull/push). This introduces friction, cognitive load, and risk of desynchronization (e.g. pushing `.plans` but forgetting `.agents`).
* **Storage Model (A/C Hybrid)**:
  - **Option A (Git-Native Storage)**: Zero extra configuration files, zero JSON parsers, zero external dependencies. Configuration lives in Git's native config (`.git/config` or `~/.gitconfig` via `git config aapp.*`).
  - **Option C (Init Defaults Seeding)**: `aapp init` automatically discovers existing git remotes and seeds sensible repository defaults (`aapp.remote origin`, `aapp.syncWorktrees "plans agents githooks"`, `aapp.pullStrategy ff-only`) if unset, allowing immediate zero-config operation while remaining fully customizable per-developer or per-repository.
  - **CLI Runtime Overrides**: All sync commands accept an optional `[remote]` positional argument (`aapp push upstream`) to override the configured remote on an ad-hoc basis without modifying configuration.

---

## 2. Technical Blueprint

### A. CLI Commands & User Interface
```bash
aapp push [remote]    # Push active AAPP worktrees to remote
aapp pull [remote]    # Pull updates for active AAPP worktrees from remote
aapp sync [remote]    # Bi-directional sync: pull (--ff-only) followed by push
```

#### Terminal UX Feedback Example
```text
🚀 Syncing AAPP worktrees with 'origin'...
  📥 Pulling updates (--ff-only)...
    • .plans/    --> up to date
    • .agents/   --> up to date
    • .githooks/ --> up to date
  📤 Pushing worktrees...
    • .plans/    --> origin/plans    (synced)
    • .agents/   --> origin/agents   (synced)
    • .githooks/ --> origin/githooks (synced)
✨ All AAPP worktrees synchronized successfully.
```

### B. Configuration Schema (Git-Native `git config aapp.*`)
| Key | Type | Default (Seeded by `aapp init`) | Description |
| :--- | :--- | :--- | :--- |
| `aapp.remote` | string | `origin` (or first detected remote) | Target git remote for sync operations. |
| `aapp.syncWorktrees` | string | `"plans agents githooks"` | Space-delimited list of worktrees to sync. |
| `aapp.pullStrategy` | string | `"ff-only"` | Strategy for pulling (`ff-only`, `rebase`, `merge`). |

### C. Core Safety & Resilience Mechanisms
1. **Pre-flight Cleanliness Check**: Before performing `pull` or `sync`, every active worktree in `aapp.syncWorktrees` is checked via `git -C <dir> status --porcelain`. If any worktree has uncommitted modifications, the operation immediately halts to protect uncommitted drafts from merge conflicts or dirty states.
2. **First-Time Upstream Tracking**: When pushing an orphan worktree for the first time where upstream tracking is not configured, `aapp push` automatically runs `git -C <dir> push -u <remote> <branch>` to establish upstream tracking.
3. **Fail-Fast & Conflict Isolation**: If one worktree encounters a non-fast-forward push rejection or network error, detailed diagnostic steps are provided, and exit code 1 is returned.
4. **Zero Extra Dependencies**: Built strictly with POSIX / bash and git primitives. No python, jq, or external binaries required.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Core Command Implementation (`lib/cmd_push.sh`, `lib/cmd_pull.sh`, `lib/cmd_sync.sh`)
- [ ] Task 1.1: Create shared sync helper library or modular commands implementing remote resolution, worktree discovery, cleanliness checks, and push/pull primitives.
- [ ] Task 1.2: Implement `aapp push [remote]` with upstream detection and `-u` tracking setup.
- [ ] Task 1.3: Implement `aapp pull [remote]` with pre-flight dirty checks and `--ff-only` strategy.
- [ ] Task 1.4: Implement `aapp sync [remote]` orchestrating pull followed by push.

### Phase 2: CLI Dispatcher & `aapp init` Defaults Seeding
- [ ] Task 2.1: Wire `push`, `pull`, and `sync` commands into `aapp` dispatcher.
- [ ] Task 2.2: Update `lib/cmd_init.sh` to automatically seed `aapp.remote`, `aapp.syncWorktrees`, and `aapp.pullStrategy` in `.git/config` if not already set.
- [ ] Task 2.3: Update `lib/cmd_help.sh` with command syntax, examples, and config guidance.

### Phase 3: Automated Regression Tests & Documentation
- [ ] Task 3.1: Add automated tests in a new test suite `tests/sync_test.sh` (or `tests/install_test.sh`) covering:
  - Default config seeding during `aapp init`.
  - Pushing orphan branches to a bare local test remote.
  - Pulling changes from remote.
  - Bi-directional sync.
  - Safety guard aborting when a worktree is dirty.
  - Custom remote argument override.
  - Selective worktree syncing (`aapp.syncWorktrees`).
- [ ] Task 3.2: Update `README.md` and `MANUAL.md` documenting `aapp push`, `aapp pull`, and `aapp sync`.
- [ ] Task 3.3: Verify all regression test suites pass cleanly.
- [ ] Task 3.4: Update `CHANGELOG.md` with features and additions.

---

## 💥 4. Blast Radius & System Boundaries
*(Marked: **PROPOSED** — confers no execution rights until frozen)*

### 📂 Target Files (Modifications & Additions)
- [ ] `aapp` -> Add `push`, `pull`, `sync` commands to CLI dispatcher.
- [ ] `NEW FILE` -> `lib/cmd_sync.sh` -> Core synchronization engine handling push, pull, and sync operations.
- [ ] `lib/cmd_init.sh` -> Seed git config defaults during initialization.
- [ ] `lib/cmd_help.sh` -> Document `push`, `pull`, `sync` commands and options.
- [ ] `NEW FILE` -> `tests/sync_test.sh` -> Automated regression test suite for push/pull/sync against bare remotes.
- [ ] `README.md` -> Document remote sync automation and workflows.
- [ ] `CHANGELOG.md` -> Record v1.1.0 feature additions.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/blast-radius-guard` -> Hook enforcement engine is stable.
- [ ] `templates/pre-commit` -> Pre-commit hook wrapper is stable.
- [ ] `lib/cmd_status.sh` -> Context recovery briefing remains unchanged.

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1 (Atomic Abort vs Partial Skip):** If one worktree has uncommitted changes when `aapp pull` or `aapp sync` is invoked, should the entire operation abort immediately before touching any worktree (Recommended: Yes, strict atomicity prevents inconsistent states across worktrees), or should it skip the dirty worktree and proceed with the clean ones?
* [ ] **Question 2 (Pull Default Behavior):** Should `--ff-only` be the non-negotiable default for `aapp pull`, refusing merges and directing developers to resolve manually inside the affected worktree if divergence occurs? (Recommended: Yes, automatic recursive merge or rebase on orphan branches without human oversight is error-prone).
* [ ] **Question 3 (Agent Integration):** Should `aapp push` or `aapp sync` be suggested in `.agents/AGENTS.md` during `/done <plan>` or `/release <version>` briefings?

---

## 📦 6. Change Log & Refinement History
* **2026-09-10:** Plan drafted from user request with A/C hybrid configuration model.
