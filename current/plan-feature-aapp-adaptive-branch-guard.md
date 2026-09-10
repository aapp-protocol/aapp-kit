# 🗺️ Plan: Smart Adaptive Branch Protection & Getting Started Docs
* **Created:** 2026-09-10 | **Last Refined:** 2026-09-10
* **Target Issue / Milestone:** Milestone v1.1.0 (Branch Protection & Onboarding)
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
* **What**: Implement an existence-aware, adaptive branch protection guard in `aapp-pre-commit` that prevents accidental direct commits to stable production branches (`main`/`master`), while introducing clear "Getting Started: Branching & Worktree Topologies" documentation in `README.md` and `MANUAL.md`.
* **Why**: 
  1. Developers frequently forget which branch is checked out and accidentally commit exploratory code directly to `main`.
  2. However, hardcoding a blind block on `main` breaks trunk-based repositories where `main` is the only branch.
  3. By inspecting whether a designated development branch (`develop`, `dev`) actually exists locally, the hook automatically adapts: single-branch repositories experience zero friction, while dual-branch repositories gain bulletproof protection.
* **Configuration (A/C Hybrid Model)**: Governed entirely through Git's native configuration system (`git config aapp.*`), requiring zero new configuration files or parsers.

---

## 2. Technical Blueprint

### A. The Adaptive Guard Algorithm in `aapp-pre-commit`
```text
┌─────────────────────────────────────────────────────────────┐
│ 1. Is 'aapp.protectStable' false or ALLOW_MAIN_COMMIT=1?    │ ──► ALLOW
└─────────────────────────────┬───────────────────────────────┘
                              │ No
┌─────────────────────────────▼───────────────────────────────┐
│ 2. Is current branch in 'protectedBranches' (main, master)? │ ──► NO ──► ALLOW
└─────────────────────────────┬───────────────────────────────┘
                              │ Yes
┌─────────────────────────────▼───────────────────────────────┐
│ 3. Does any configured 'devBranch' (develop, dev) exist?    │ ──► NO ──► ALLOW (Trunk repo)
└─────────────────────────────┬───────────────────────────────┘
                              │ Yes! Both exist!
┌─────────────────────────────▼───────────────────────────────┐
│ 4. BLOCK COMMIT with actionable guidance:                   │
│    "Direct commits to 'main' are blocked. Switch to develop"│
└─────────────────────────────────────────────────────────────┘
```

### B. Git Configuration Keys (`git config aapp.*`)
| Key | Type | Default | Purpose |
| :--- | :--- | :--- | :--- |
| `aapp.protectStable` | boolean | `true` | Master switch for branch protection. |
| `aapp.protectedBranches` | string | `"main master production"` | Space-delimited list of protected stable branches. |
| `aapp.devBranch` | string | `"develop dev development"` | Space-delimited candidates for active development branch. |

### C. Hook Failure UX
When a direct commit to a protected branch is blocked:
```text
❌ [AAPP Branch Protection] Direct commits to 'main' are prohibited!
   A development branch ('develop') exists for active engineering.

   👉 Switch to your development branch before committing:
      git checkout develop

   💡 If this is an intentional release commit:
      ALLOW_MAIN_COMMIT=1 git commit -m "..."
   💡 Or to disable branch protection for trunk-based development:
      git config --bool aapp.protectStable false
```

### D. Documentation: "Getting Started" Section
* **Location:** Prominent Section 2 in `README.md` and Chapter 1 in `MANUAL.md`.
* **Content:**
  * **Option A: Trunk-Based Development (Single Branch):** Commit directly to `main` with orphan worktrees (`.plans`, `.agents`, `.githooks`).
  * **Option B: Stable vs. Edge Topology (Dual Branch — Recommended):**
    * `main` = STABLE (production, clean release tags `vX.Y.Z`).
    * `develop` = EDGE (active development, feature incubation).
  * Clear guide on how the hook automatically detects the topology and how to customize branch names.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Pre-Commit Hook Engine Implementation
- [ ] Task 1.1: Add Phase 0 Branch Protection in `templates/aapp-pre-commit`.
- [ ] Task 1.2: Implement `git config aapp.*` resolution with defaults.
- [ ] Task 1.3: Implement local branch existence probe (`git show-ref --verify --quiet refs/heads/<branch>`).
- [ ] Task 1.4: Support bypass via `ALLOW_MAIN_COMMIT=1` and `SKIP_BLAST_RADIUS=1`.

### Phase 2: Documentation in "Getting Started"
- [ ] Task 2.1: Add "Getting Started & Branching Topologies" section to `README.md`.
- [ ] Task 2.2: Add comprehensive configuration and workflow guide in `MANUAL.md`.
- [ ] Task 2.3: Update `cmd_init.sh` completion banner to report detected branching topology.

### Phase 3: Automated Regression Test Suite
- [ ] Task 3.1: Add test in `tests/pre-commit_test.sh`: Single-branch repo (`main` only) allows commit.
- [ ] Task 3.2: Add test in `tests/pre-commit_test.sh`: Dual-branch repo (`main` + `develop`) blocks commit on `main`.
- [ ] Task 3.3: Add test in `tests/pre-commit_test.sh`: Committing on `develop` succeeds.
- [ ] Task 3.4: Add test in `tests/pre-commit_test.sh`: `ALLOW_MAIN_COMMIT=1` allows commit on `main`.
- [ ] Task 3.5: Add test in `tests/pre-commit_test.sh`: `git config aapp.protectStable false` allows commit on `main`.
- [ ] Task 3.6: Add test in `tests/pre-commit_test.sh`: Custom branch configuration (`aapp.devBranch "staging"`).
- [ ] Task 3.7: Run all test suites and verify 100% pass rate.
- [ ] Task 3.8: Update `CHANGELOG.md`.

---

## 💥 4. Blast Radius & System Boundaries
*(Marked: **PROPOSED** — confers no execution rights until frozen)*

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/aapp-pre-commit` -> Implement adaptive branch guard.
- [ ] `tests/pre-commit_test.sh` -> Add 6 automated test cases for branch protection.
- [ ] `README.md` -> Add Getting Started & Branching Topologies section.
- [ ] `MANUAL.md` -> Document branch protection and configuration.
- [ ] `lib/cmd_init.sh` -> Report detected topology during `aapp init`.
- [ ] `CHANGELOG.md` -> Record feature under `## [Unreleased]`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> PreToolUse guard remains focused on tool call file paths.
- [ ] `aapp` -> CLI dispatcher requires no changes.
- [ ] `templates/AGENTS.md` -> Shorthand triggers remain unchanged.

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1 (Auto-detection Scope):** Should the hook check only local branches (`refs/heads/<branch>`) or also remote tracking branches (`refs/remotes/origin/<branch>`) when checking if `develop` exists? (Recommended: Check local branches first, fall back to remote tracking branches so freshly cloned repos with an un-checked-out `develop` are still protected).
* [ ] **Question 2 (Merge Commit Exemption):** When `develop` is merged into `main` (fast-forward or merge commit during release), should the hook automatically exempt merge commits? (Recommended: Yes, fast-forward merges do not fire pre-commit, and `ALLOW_MAIN_COMMIT=1` handles non-fast-forward release merges).

---

## 📦 6. Change Log & Refinement History
* **2026-09-10:** Plan drafted to eliminate accidental commits to `main` with existence-aware auto-detection and Getting Started onboarding documentation.
