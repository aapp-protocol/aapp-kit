# 🗺️ Plan: Air-Gapped Reference Store & Leak Protection (`.plans/pickup/`)
* **Created:** 2026-09-10 | **Last Refined:** 2026-09-10
* **Target Issue / Milestone:** Milestone v1.1.0 (Air-Gapped Reference Store)
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
* **What**: Standardize an air-gapped reference ingestion directory (`.plans/pickup/`) alongside `.plans/pickup.md`, backed by a 5-layer leak-prevention architecture ensuring sensitive transcripts, audio logs, and private scratchpads are never committed or pushed to remote repositories.
* **Why**: Developers and architects frequently seed plans with chat transcripts (Gemini, Claude, ChatGPT), meeting transcripts, or PRD excerpts containing sensitive credentials, auth tokens, or private business logic. Dumping these into `.plans/pickup.md` destroys the brevity of the context recovery briefing. Furthermore, relying on a single `.gitignore` line is vulnerable to accidental deletion or `git add -f`.
* **The Air-Gap Guarantee**: Reference files dropped into `.plans/pickup/` can be freely inspected and digested by AI agents (`/digest pickup/transcript.txt`), but cannot be staged, committed, or pushed to any remote under any circumstances.

---

## 2. Technical Blueprint

### A. The 5-Layer Leak Protection Architecture
```text
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: Innermost .plans/pickup/.gitignore                │ -> Wildcard * ignores everything inside folder
├─────────────────────────────────────────────────────────────┤
│  Layer 2: Worktree-level .plans/.gitignore                  │ -> Worktree parent exclusion rules
├─────────────────────────────────────────────────────────────┤
│  Layer 3: Git Engine Private Exclusion (.git/info/exclude)  │ -> Uncommitted git-level ignore rules
├─────────────────────────────────────────────────────────────┤
│  Layer 4: Pre-Commit Hook Hard Rejection (aapp-pre-commit)  │ -> Programmatic exit 1 if pickup/* staged
├─────────────────────────────────────────────────────────────┤
│  Layer 5: Remote Sync Pre-Push Scanner (aapp push / sync)   │ -> Refuses push if pickup/* ever tracked in HEAD
└─────────────────────────────────────────────────────────────┘
```

#### 1. Innermost `.plans/pickup/.gitignore`
Created during `aapp init`:
```gitignore
# AAPP Air-Gapped Local Scratchpad
# Ignore everything dropped in this folder
*
!.gitignore
!.gitkeep
```

#### 2. Worktree Root `.plans/.gitignore`
Ensures `.plans/` as a worktree root maintains explicit rules:
```gitignore
pickup/*
!pickup/.gitkeep
!pickup/.gitignore
```

#### 3. Git Private Exclusion (`$GIT_DIR/info/exclude`)
During `aapp init`, AAPP appends `pickup/*` to `.git/info/exclude` (and `.git/worktrees/<name>/info/exclude`). Because `info/exclude` is uncommitted and local to the developer's workstation, no repository commit or branch switch can remove it.

#### 4. Pre-Commit Hook Hard Enforcement (`templates/aapp-pre-commit`)
`aapp-pre-commit` evaluates all staged files. If any staged file is inside `pickup/` (excluding `.gitkeep` and `.gitignore`), it immediately aborts the commit with exit code 1:
```bash
for F in "${STAGED_FILES[@]}"; do
    if [[ "$F" =~ ^(\.plans/)?pickup/ ]] && [[ "$F" != *".gitkeep" && "$F" != *".gitignore" ]]; then
        echo "❌ [Security Violation] Refusing commit: Staged file '$F' is inside pickup/."
        echo "   The pickup/ directory is reserved for local, untracked reference files and must never be committed."
        exit 1
    fi
done
```

#### 5. Push-Time Scanner (`aapp push` / `aapp sync`)
Before pushing the `plans` branch, `aapp push` runs:
`git -C .plans ls-tree -r --name-only HEAD pickup/` (filtering out `.gitkeep` and `.gitignore`). If any file is tracked, the push is refused.

---

### B. CLI & Workflow Integration

1. **`aapp init` Scaffolding**:
   - Creates `.plans/pickup/` directory.
   - Deploys `.plans/pickup/.gitkeep` and `.plans/pickup/.gitignore`.
   - Deploys `.plans/.gitignore`.
   - Registers exclusion in `.git/info/exclude`.
   - Banner report: `➡️  Air-gapped scratch:  .plans/pickup/ (local-only, shielded from git)`.

2. **`aapp status` Visibility**:
   - In Pillar 4 (Pickup), `cmd_status.sh` checks for files in `.plans/pickup/` in addition to `.plans/pickup.md` bullet points:
     ```text
     💡 [4/4] PICKUP QUEUE (Unprocessed Ideas & References)
       • (1 unworked idea in pickup.md)
       • (1 unworked reference file in pickup/):
           - gemini-sync-workflow.txt
     ```

3. **Targeted Ingestion (`/digest` & `/aapp:digest`)**:
   - `digest <file>` natively accepts relative paths to files in `pickup/` (e.g., `/digest pickup/gemini-sync-workflow.txt`).
   - The agent ingests the reference document, scaffolds a draft blueprint in `.plans/current/`, and leaves the local reference untouched in `pickup/`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Scaffolding Templates & `aapp init` Integration
- [ ] Task 1.1: Create `templates/pickup-gitignore` and `templates/plans-gitignore`.
- [ ] Task 1.2: Update `lib/cmd_init.sh` to scaffold `.plans/pickup/`, `.gitkeep`, `.gitignore`, and configure `.git/info/exclude`.
- [ ] Task 1.3: Update completion banner in `cmd_init.sh` to display the air-gapped scratchpad path.

### Phase 2: Enforcement Gates in Pre-Commit & Push Engine
- [ ] Task 2.1: Add hard commit refusal for staged `pickup/` files in `templates/aapp-pre-commit`.
- [ ] Task 2.2: Add pre-push verification check in `lib/cmd_sync.sh` (or `aapp push`).
- [ ] Task 2.3: Update `lib/cmd_status.sh` to discover and list reference files inside `.plans/pickup/`.

### Phase 3: Automated Regression Tests & Documentation
- [ ] Task 3.1: Add test in `tests/install_test.sh` verifying `aapp init` creates `.plans/pickup/` with all ignore rules.
- [ ] Task 3.2: Add test in `tests/pre-commit_test.sh` verifying that attempting to `git add -f` and commit a file in `pickup/` is blocked.
- [ ] Task 3.3: Document the 5-layer air-gap architecture and workflow in `README.md` and `MANUAL.md`.
- [ ] Task 3.4: Update `CHANGELOG.md`.

---

## 💥 4. Blast Radius & System Boundaries
*(Marked: **PROPOSED** — confers no execution rights until frozen)*

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `templates/pickup-gitignore` -> Default ignore file for `.plans/pickup/.gitignore`.
- [ ] `NEW FILE` -> `templates/plans-gitignore` -> Default ignore file for `.plans/.gitignore`.
- [ ] `lib/cmd_init.sh` -> Scaffold pickup directory, copy ignore files, and append to `info/exclude`.
- [ ] `templates/aapp-pre-commit` -> Add Layer 4 pre-commit hook block for staged `pickup/` files.
- [ ] `lib/cmd_status.sh` -> Report unworked reference files found in `.plans/pickup/`.
- [ ] `tests/install_test.sh` -> Add assertions for pickup folder scaffolding and ignore configuration.
- [ ] `tests/pre-commit_test.sh` -> Add assertions for pre-commit rejection on `pickup/` file commit attempts.
- [ ] `README.md` -> Document air-gapped reference workflow.
- [ ] `MANUAL.md` -> Detailed guide on using `.plans/pickup/` with AI transcripts.
- [ ] `CHANGELOG.md` -> Record feature addition under `## [Unreleased]`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Write-guard stays focused on tool write interception.
- [ ] `aapp` -> Dispatcher requires no changes.
- [ ] `templates/state_matrix.md` -> Structure unchanged.

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1 (Digested File Handling):** Once an agent digests a reference file from `.plans/pickup/` into a blueprint, should the file remain in `pickup/`, be marked with a prefix (e.g. `[digested]`), or offered for deletion? (Recommended: Leave untouched in `pickup/` by default so the human can review or delete manually, since it's local and untracked anyway).
* [ ] **Question 2 (Allowed Extensions):** Should `pickup/` accept all file types, or should the status briefing only scan text-like extensions (`.txt`, `.md`, `.json`, `.csv`, `.log`)? (Recommended: Accept all file types, but only parse text/markdown in status briefings).

---

## 📦 6. Change Log & Refinement History
* **2026-09-10:** Plan initialized from user request to establish an air-gapped reference store for transcripts and brainstorming dumps.
