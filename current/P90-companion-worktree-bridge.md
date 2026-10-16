# 🗺️ Plan P-90: Companion Worktree Bridge
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-16
* **Target Issue / Milestone:** none
* **Plan ID:** P-90
* **Changelog:** Added: `aapp companion` manages isolated companion-repo worktrees for cross-repo co-development (P-90)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Commits:** none
<!-- AAPP-PROTOCOL:START v1.0.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** #<num>        <- written by verbs: 'aapp issue hotfix' or 'aapp refine <id> blocked <num>' adds it; 'aapp issue close' removes it -->
<!-- * **Emergency Hotfixes:** #<num> <- append-only, written by 'aapp issue hotfix'; more than aapp.maxEmergencyHotfixes blocks the plan for good -->
<!-- * **Also Closes:** #<n>, #<m>  <- written by 'aapp refine <id> closes <num> [remove]': further issues this plan sorts; 'aapp done' closes them with the plan's commit -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp refine issues`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal

When developing a companion repository (e.g. a downstream web dashboard, consumer SDK, client adapter, or companion service) alongside a core repository:
- **Both repositories advance concurrently**: The core repository (`repo-a`) introduces new contracts, schemas, and engine capabilities; the companion repository (`repo-b`) introduces consumer logic, UI components, and state management.
- **The Context Dilemma**: Developing new capabilities in `repo-b` requires deep access to `repo-a`'s architecture, codemap, test suites, and plans. Developing inside `repo-b` in isolation deprives autonomous agents of `repo-a`'s rich context. Conversely, copying `repo-b`'s code directly into `repo-a` pollutes `repo-a`'s Git history and violates repository portability.

### The Architectural Goal:
This plan introduces **`aapp companion`**, a formal CLI suite for cross-repository co-development via **Git-Linked Companion Worktrees**:
1. Mounts an external companion repository's genuine Git branch inside `.workspace/companion/<name>/` within the primary repository.
2. Gives developers and autonomous agents simultaneous access to both worlds: full read access to the primary repository's architectural context, while authoring and committing code directly to the companion repository's native Git lineage.
3. Provides one-command synchronization (`mount`, `status`, `push`, `unmount`), preserving clean repository boundaries and strict Git hygiene.

---

## 2. Technical Blueprint

### 2.1 The Companion Architecture
Git's content-addressable object database allows any local repository to register an external repository as a remote and check out its branches into a dedicated worktree:

```
/home/user/repo-a/                            <── PRIMARY REPO (Full Context & Engine)
├── lib/                                      <── Core modules and contracts
├── ARCHITECTURE.md                           <── Architectural specification
├── CODEMAP.md                                <── Canonical boundary map
├── .plans/                                   <── Planning ledgers
│
└── .workspace/companion/<name>/              <── LINKED COMPANION WORKTREE
    ├── package.json                          <── Companion repo files
    ├── src/                                  <── Consumer code & UI
    └── (Commits made here advance Repo-B's genuine Git history!)
```

- **Remote registration**: Stored strictly in local `.git/config` (`remote.<name>.url`). No machine-specific paths leak into tracked files (preserving Portability Invariant).
- **Worktree path**: Standardized at `.workspace/companion/<name>`.

---

### 2.2 CLI Verb Specification: `aapp companion`

A dedicated verb `aapp companion` provides full lifecycle management:

```bash
aapp companion add <name> <repo-path>
aapp companion mount <name> [branch]
aapp companion status [name]
aapp companion push <name> [target-branch]
aapp companion unmount <name> [force]
aapp companion list
```

#### Detailed Subcommand Behaviors:

1. **`aapp companion add <name> <repo-path>`**:
   - Validates that `<repo-path>` is an existing Git repository (`git -C <repo-path> rev-parse --git-dir`).
   - Normalizes `<name>` to lowercase alphanumeric (`[a-z0-9_-]+`).
   - Registers the companion as a Git remote: `git remote add <name> <repo-path>`.
   - Fetches companion references: `git fetch <name>`.
   - Refuses duplicate names or invalid paths.

2. **`aapp companion mount <name> [branch]`**:
   - Refuses if `.workspace/companion/<name>` is already mounted.
   - Fetches latest updates from `<name>`: `git fetch <name>`.
   - Resolves `<branch>` (defaults to the remote's `HEAD`, e.g. `develop` or `main`).
   - Cuts a dedicated tracking branch: `companion/<name>/<branch>`.
   - Creates the linked worktree:
     ```bash
     git worktree add .workspace/companion/<name> -b companion/<name>/<branch> <name>/<branch>
     ```
   - Sets up write-guard authorization: registers path in local `.git/config` under `aapp.allowPath` so write-guard permits agent edits within `.workspace/companion/<name>`.
   - Emits a diagnostic summary with instructions and target paths.

3. **`aapp companion status [name]`**:
   - Inspects mounted companion worktrees.
   - Displays:
     - Companion name, local worktree path, and target branch.
     - Uncommitted working copy changes in the worktree.
     - Ahead/behind commit counts relative to the companion remote branch (`git rev-list --left-right --count`).
     - List of outgoing commits ready to be pushed.

4. **`aapp companion push <name> [target-branch]`**:
   - Refuses if `.workspace/companion/<name>` has uncommitted working tree changes.
   - Pushes the local tracking branch directly to the companion remote:
     ```bash
     git push <name> companion/<name>/<branch>:<target-branch>
     ```
   - Updates the tracking reference.

5. **`aapp companion unmount <name> [force]`**:
   - Checks for uncommitted changes or unpushed commits in `.workspace/companion/<name>`.
   - If unpushed commits exist and `force` is not passed: **refuses closed**, reporting unpushed commit SHAs.
   - Safely removes the linked worktree: `git worktree remove .workspace/companion/<name>`.
   - Deletes the local tracking branch `companion/<name>/<branch>`.
   - Cleans up `aapp.allowPath` entry.

6. **`aapp companion list`**:
   - Lists all configured companion remotes, their filesystem targets, and whether they are currently mounted.

---

### 2.3 Layer 1 & Layer 2 Guard Integration
- **Layer 1 (`blast-radius-guard`)**:
  - The guard already checks `git config --get-all aapp.allowPath`.
  - When `aapp companion mount` runs, it automatically adds `.workspace/companion/<name>` to `aapp.allowPath`.
  - Agents operating in companion worktrees are permitted to write code within `.workspace/companion/<name>`.
- **Layer 2 (`pre-commit`)**:
  - Commits in `.workspace/companion/<name>` are commits on the companion's Git lineage, completely isolated from `repo-a`'s `pre-commit` plan validation.
  - Commits in `repo-a` cannot accidentally include files from `.workspace/companion/<name>` because `.workspace/` is ignored.

---

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`
- Purely additive new capability; does not alter existing plan or issue verbs.

---

## 🔨 3. Implementation Steps & Execution Checklist

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/companion.sh::test_companion_add_validates_repo` -> asserts `aapp companion add` succeeds for a valid Git repo and fails closed for a non-git directory
- [ ] `tests/verbs/companion.sh::test_companion_add_refuses_duplicate` -> asserts adding an already existing companion name fails closed
- [ ] `tests/verbs/companion.sh::test_companion_mount_creates_worktree` -> asserts `aapp companion mount` fetches remote and creates `.workspace/companion/<name>` on correct branch
- [ ] `tests/verbs/companion.sh::test_companion_status_reports_outgoing_commits` -> asserts `aapp companion status` lists uncommitted changes and unpushed commits
- [ ] `tests/verbs/companion.sh::test_companion_push_syncs_to_companion_repo` -> asserts `aapp companion push` updates the companion repository's branch
- [ ] `tests/verbs/companion.sh::test_companion_unmount_refuses_unpushed_without_force` -> asserts `aapp companion unmount` blocks removal when unpushed commits exist unless `force` is specified
- [ ] `tests/verbs/companion.sh::test_companion_unmount_cleans_worktree_and_branch` -> asserts clean unmount removes worktree directory and local tracking branch
- [ ] `tests/verbs/companion.sh::test_guard_authorizes_companion_writes` -> asserts blast-radius-guard permits file writes inside mounted companion worktree

### Phase 1: Tests First (red)
- [ ] Task 1.1: Author `tests/verbs/companion.sh` with full fixture scaffolding (creating dummy companion repo); confirm red.

### Phase 2: Core Implementation
- [ ] Task 2.1: `lib/cmd_companion.sh`: Implement `aapp companion add`, `mount`, `status`, `push`, `unmount`, `list`.
- [ ] Task 2.2: `lib/aapp-lib.sh`: Register `companion` in CLI dispatcher and verb catalog.
- [ ] Task 2.3: `templates/blast-radius-guard.sh`: Verify companion worktree path resolution in `aapp.allowPath`.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites across all verbs.
- [ ] Task 3.2: Update `MANUAL.md` (§ Companion Development & Worktree Bridge).
- [ ] Task 3.3: Update `CHEATSHEET.md` with `aapp companion` command summary.
- [ ] Task 3.4: Update `ARCHITECTURE.md` (§ Cross-Repository Companion Development).
- [ ] Task 3.5: Update `lib/docs/verbs/companion.md` with full verb specification and contracts.
- [ ] Task 3.6: Verify `CHANGELOG.md` updates and run syntax/build checks.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_companion.sh` -> Implementation of `aapp companion` verb.
- [ ] `lib/aapp-lib.sh` -> CLI dispatcher and helper functions.
- [ ] `lib/docs/verbs/companion.md` -> Command reference documentation.
- [ ] `templates/blast-radius-guard.sh` -> Companion worktree authorization in guard.
- [ ] `MANUAL.md` -> User manual section on companion development.
- [ ] `CHEATSHEET.md` -> CLI quick reference.
- [ ] `ARCHITECTURE.md` -> Architecture reference for companion worktrees.
- [ ] `NEW FILE` -> `tests/verbs/companion.sh` -> Test suite.

### 🧪 Required Test Files
- [ ] `tests/verbs/companion.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_plan.sh` -> Core plan engine is unaffected.
- [ ] `lib/cmd_issue.sh` -> Issue lifecycle is unaffected.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-16:** Plan drafted: authored blueprint for `aapp companion` verb, linked companion worktrees, remote tracking, and cross-repo push/unmount lifecycle.
