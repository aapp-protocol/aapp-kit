# 🗺️ Plan P-90: Companion Repository Bridge
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-16
* **Target Issue / Milestone:** none
* **Plan ID:** P-90
* **Changelog:** Added: `aapp companion` manages companion repositories for cross-repo co-development (P-90)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `bf8f505` (develop)
* **Worktree:** .workspace/P90 (plan/P90-companion-worktree-bridge)
* **Commits:** `9812ba3` (plan/P90-companion-worktree-bridge)
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
- **Sound Topology Consensus**: Per `.plans/pickup/p90-companion-repos-rfc.md`, creating a Git worktree of `repo-a` for `repo-b` is mathematically unsound (shares `repo-a`'s common dir, causing `IS_SAME_REPO=1`, failing the write-guard closed and polluting `repo-a`'s object store). Instead, `repo-b` must retain its own Git directory (`IS_SAME_REPO=0`), governed by its own Git lineage and hooks.

### The Architectural Goal:
This plan introduces **`aapp companion`**, a core CLI suite (`lib/cmd_companion.sh`) for cross-repository co-development supporting three clean topologies:
1. **Existing local checkout (`checkout`)**: Registers an already existing checkout of `repo-b` on the local machine.
2. **Dedicated companion worktree (`worktree`)**: For non-AAPP repositories, creates a dedicated worktree via `git -C <repo-b> worktree add` placed under `.workspace/companion/<name>`. (Refused for AAPP repositories per G2, directing the user to run `aapp start` inside `repo-b` and register that worktree as a checkout).
3. **Dedicated clone (`clone`)**: Clones a remote repository URL into `.workspace/companion/<name>`.

Provides uniform, predictable lifecycle commands (`add`, `status`, `push`, `remove`, `list`) with offline-first status reporting and seamless write-guard authorization.

---

## 2. Technical Blueprint

### 2.1 The Companion Topology & Registry
Every companion retains its own Git common dir (`repo-b/.git`), isolating object databases, refs, and hooks:

```
/home/user/repo-a/                            <── PRIMARY REPO (Full Context & Engine)
├── lib/                                      <── Core modules and contracts
├── ARCHITECTURE.md                           <── Architectural specification
├── CODEMAP.md                                <── Canonical boundary map
├── .plans/                                   <── Planning ledgers
│
└── .workspace/companion/<name>/              <── COMPANION REPO (Mode: worktree or clone)
    ├── package.json                          <── Companion repo files
    ├── src/                                  <── Consumer code & UI
    └── .git                                  <── Points strictly to Repo-B's object store!
```

- **Local Registry**: Machine-specific paths are stored strictly in local `.git/config` via dedicated config keys:
  - `aapp.companion.<name>.path`: Canonical absolute path to companion checkout/worktree.
  - `aapp.companion.<name>.mode`: One of `checkout`, `worktree`, `clone`.
  - No machine-specific paths leak into tracked files (preserving the Portability Invariant).
- **Write-Guard Authorization**: Every companion path is also registered in `aapp.allowPath` in `.git/config` so Layer 1 permits tool-time writes.

---

### 2.2 CLI Verb Specification: `aapp companion`

Core verb in `lib/cmd_companion.sh`:

```bash
aapp companion add <name> <path> [worktree]
aapp companion add <name> <url>
aapp companion status [name]
aapp companion push <name>
aapp companion remove <name> [force]
aapp companion list
```

#### Detailed Subcommand Behaviors:

1. **`aapp companion add <name> <path> [worktree]` / `aapp companion add <name> <url>`**:
   - Normalizes `<name>` to lowercase alphanumeric (`[a-z0-9_-]+`). Refuses duplicate names.
   - **Mode `checkout`** (`add <name> <path>`):
     - Validates `<path>` is a valid Git repository (`git -C <path> rev-parse --git-dir`).
     - Stores `aapp.companion.<name>.path` and `mode = checkout`.
     - Adds `<path>` to `aapp.allowPath`.
   - **Mode `worktree`** (`add <name> <path> worktree`):
     - Validates `<path>` is a valid Git repository.
     - **G2 Refusal Rule**: If `<path>` is detected as an AAPP repository (`[ -f "$path/aapp" ] || [ -d "$path/.agents" ] || [ -d "$path/.plans" ]`), **refuses closed**:
       `❌ [Companion] <path> uses AAPP. Raw worktrees lack linked kit hooks. Start the plan in <path> ('aapp start <id>') and register its worktree here: 'aapp companion add <name> <path-to-worktree>'.`
     - For non-AAPP repositories: creates `.workspace/companion/<name>` via `git -C <path> worktree add .workspace/companion/<name> HEAD`.
     - Stores `aapp.companion.<name>.path` and `mode = worktree`.
     - Adds `.workspace/companion/<name>` to `aapp.allowPath`.
   - **Mode `clone`** (`add <name> <url>`):
     - Validates `<url>` is a URL/remote spec.
     - Runs `git clone <url> .workspace/companion/<name>`.
     - Stores `aapp.companion.<name>.path` and `mode = clone`.
     - Adds `.workspace/companion/<name>` to `aapp.allowPath`.

2. **`aapp companion status [name]`**:
   - Offline-first: strictly zero network calls.
   - For each companion (or designated `<name>`):
     - Resolves checked-out branch: `git -C <path> rev-parse --abbrev-ref HEAD`.
     - Computes `dirty`: integer count of modified/untracked files via `git -C <path> status --porcelain | wc -l`.
     - Computes `ahead` and `behind` vs. upstream tracking branch (`@{u}`) via `git -C <path> rev-list --left-right --count HEAD...@{u}` (or 0 if no upstream).
     - Resolves `fetched_at`: timestamp of last fetch on upstream ref, or empty/null if un-fetched.
   - Formats human-readable table in CLI; emits companion array in `aapp status json` (per RFC C14).

3. **`aapp companion push <name>`**:
   - Strictly bounded per RFC §3 C11:
     - Refuses if the companion has uncommitted changes (`dirty > 0`).
     - Refuses if the companion branch has no configured upstream tracking branch (`git -C <path> rev-parse --abbrev-ref --symbolic-full-name @{u}`).
     - Executes delegated push: `git -C <path> push`.
     - Runs Repo-B's native `pre-push` hooks and uses Repo-B's credentials.
     - **No force push, no target branch argument, no further Git wrappers** (`pull`, `fetch`, `commit`).

4. **`aapp companion remove <name> [force]`**:
   - Resolves companion from registry.
   - If `mode == checkout`:
     - Strictly **unlinks configuration only** (removes `aapp.companion.<name>.*` and `aapp.allowPath`). **Never deletes directory contents**.
   - If `mode == worktree` or `mode == clone`:
     - Checks for uncommitted changes or unpushed commits (`ahead > 0`).
     - If uncommitted/unpushed exist and `force` is not passed: **refuses closed**, reporting unpushed commits / dirty files.
     - If clean or `force` passed: removes directory (`git -C <base> worktree remove` or `rm -rf`), removes local branch if created, and cleans config / allowlist.

5. **`aapp companion list`**:
   - Lists all registered companions, modes, paths, and active branches.

---

### 2.3 Layer 1 & Layer 2 Guard Integration
- **Layer 1 (`blast-radius-guard.sh`)**:
  - The guard reads companion paths via registry accessor (`git config --get-regexp '^aapp\.companion\..*\.path$'`).
  - **G1 Guard Delegation**: When an edit targets a file under a companion path:
    - If the companion is an AAPP repository (`[ -x "$companion_path/.githooks/blast-radius-guard" ]`): Repo-A's guard delegates the check by invoking `(cd "$companion_path" && .githooks/blast-radius-guard)` passing the canonical absolute path (`$CANONICAL_TARGET`) on stdin. Repo-B's active plan's blast radius is enforced at tool-write time!
    - If the companion is a non-AAPP repository (or has no active plan): the file is recognized as an authorized external path and permitted (`exit 0`).
- **Layer 2 (`pre-commit`)**:
  - Repo-A's `pre-commit` only inspects files staged in Repo-A. Files under `.workspace/companion/` are ignored by `/.workspace` in `.git/info/exclude`; external checkouts are outside Repo-A. Repo-A commits cannot stage companion files.
  - Repo-B's `pre-commit` governs all commits made in Repo-B.

---

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`
- Additive core verb; does not alter existing plan or issue semantics.

---

## 🔨 3. Implementation Steps & Execution Checklist

### 🧪 Required Tests (Failure & Boundary Assertions)
- [x] `tests/verbs/companion.sh::test_companion_add_checkout_validates_repo` -> asserts `aapp companion add` registers existing repo and adds to allowlist
- [x] `tests/verbs/companion.sh::test_companion_add_worktree_non_aapp` -> asserts worktree mode creates worktree for non-AAPP repo
- [x] `tests/verbs/companion.sh::test_companion_add_worktree_refuses_aapp_repo` -> asserts worktree mode refuses AAPP repos per G2 with helpful guidance
- [x] `tests/verbs/companion.sh::test_companion_status_offline_metrics` -> asserts status reports dirty count, ahead/behind without network access
- [x] `tests/verbs/companion.sh::test_companion_push_bounded` -> asserts push delegates to git -C push, refusing dirty copy or unconfigured upstream
- [x] `tests/verbs/companion.sh::test_companion_remove_checkout_unlinks_only` -> asserts remove on checkout preserves directory and unregisters config
- [x] `tests/verbs/companion.sh::test_companion_remove_worktree_guards_unpushed` -> asserts remove on worktree refuses unpushed commits unless force specified
- [x] `tests/verbs/companion.sh::test_companion_guard_delegation_aapp` -> asserts blast-radius-guard delegates check to companion AAPP guard per G1

### Phase 1: Tests First (red)
- [x] Task 1.1: Author `tests/verbs/companion.sh` with full fixture scaffolding; confirm red.

### Phase 2: Core Implementation
- [x] Task 2.1: `lib/cmd_companion.sh`: Implement `add`, `status`, `push`, `remove`, `list`.
- [x] Task 2.2: `aapp` & `lib/verbs.tsv`: Register `companion` in CLI dispatcher and verb catalog.
- [x] Task 2.3: `templates/blast-radius-guard.sh`: Implement companion registry lookup and G1 guard delegation with `$CANONICAL_TARGET`.

### Phase 3: Verification & Documentation
- [x] Task 3.1: Run automated test suites across all verbs.
- [x] Task 3.2: Update `MANUAL.md` (§ Companion Development & Multi-Repository Co-Development).
- [x] Task 3.3: Update `CHEATSHEET.md` with `aapp companion` command summary.
- [x] Task 3.4: Update `ARCHITECTURE.md` (§ Cross-Repository Companion Architecture).
- [x] Task 3.5: Update `lib/docs/verbs/companion.md` with full verb specification and contracts.
- [x] Task 3.6: Verify `CHANGELOG.md` updates and run syntax/build checks.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `aapp` -> Wire companion verb into CLI dispatcher.
- [ ] `lib/verbs.tsv` -> Register companion verb in canonical manifest.
- [ ] `lib/cmd_companion.sh` -> Implementation of `aapp companion` verb.
- [ ] `lib/aapp-lib.sh` -> Helper functions and companion routines.
- [ ] `templates/blast-radius-guard.sh` -> Companion registry resolution and G1 guard delegation.
- [ ] `lib/docs/verbs/companion.md` -> Command reference documentation.
- [ ] `MANUAL.md` -> User manual section on companion development.
- [ ] `CHEATSHEET.md` -> CLI quick reference.
- [ ] `ARCHITECTURE.md` -> Architecture reference for companion repositories.
- [ ] `templates/AGENTS.md` -> CLI Reference documentation for daily verbs.
- [ ] `NEW FILE` -> `tests/verbs/companion.sh` -> Test suite.

### 🧪 Required Test Files
- [ ] `tests/verbs/companion.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_plan.sh` -> Core plan engine is unaffected.
- [ ] `lib/cmd_issue.sh` -> Issue lifecycle is unaffected.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified per .plans/pickup/p90-companion-repos-rfc.md)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-18:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-18:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-16:** Plan drafted: initial linked worktree proposal.
* **2026-10-16:** Comprehensive architectural redesign via `.plans/pickup/p90-companion-repos-rfc.md`: settled 3 topologies (`checkout`, `worktree`, `clone`) preserving Repo-B's Git directory; bounded `push` (C11); offline status telemetry (C14); G1 guard delegation; and G2 refusal of AAPP worktrees.
