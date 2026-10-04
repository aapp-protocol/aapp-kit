# 🗺️ Plan P-55: Automated Worktree Branch Integration, Parent Branch Lifecycle & Safe Cleanup
* **Created:** 2026-10-04 | **Last Refined:** 2026-10-04
* **Target Issue / Milestone:** Multi-Agent Worktree Integration Engine (Pickup #8)
* **Plan ID:** P-55
* **Changelog:** Added: Automated worktree branch integration, parent-branch targeting, and safe cleanup (`aapp integrate`)
* **Status:** 🟣 Under Review
* **Base:** none
* **Commits:** none
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 6. **User Documentation Sync**: Update `MANUAL.md`, `README.md`, and `CHEATSHEET.md` with new `aapp integrate` commands and config options.
> 7. **Architecture & Codemap Sync**: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` for new CLI verbs and integration modules.
> 8. **Fail-Closed Invariant**: Silent fallbacks are strictly prohibited. Refuse integration if working trees are dirty or branches are not rebased.

---

## 1. Context & Architectural Goal

**What.** Build the automated integration and lifecycle cleanup engine for plan branches executed in isolated worktrees (created by P-54). Automates the promotion of finished plan branches into their parent base branches (`develop` or modular parent branches like `module/*`), supporting both milestone squashing (`aapp.integrate = squash`, default) and granular microcommits (`aapp.integrate = ff`). Provides safe, automated worktree removal with protection for untracked/ignored files (`.env`), lineage trailer synthesis (`Plan-Parent:`, `Base-Branch:`), and multi-module branch targeting.

**Why.** P-54 deliberately stops at `aapp done` without merging, deleting branches, or removing worktrees, because manual integration was left as a developer/queue step. While this protected P-54 from scope creep, it leaves developers and autonomous queue runners with error-prone manual chores:
1. Remembering git squash commands and manually formulating commit messages.
2. Missing AI semantic trailers and plan linkage trailers upon squash.
3. Needing `git branch -D` after squash merges (because Git refuses `-d` when a squashed commit is not a direct ancestor).
4. Running `git worktree remove` manually, which empirically deletes untracked ignored files (e.g. `.env`, local build caches) without any warning.
5. In multi-branch / modular repositories, plans spawned from a module branch (`module/auth`) risk being accidentally merged into root `develop`.

**Core Invariants:**
1. **Parent-Branch Fidelity**: A plan spawned from `module/auth` integrates into `module/auth`; a plan spawned from `develop` integrates into `develop`. Target branch is dynamically resolved from the plan's `* **Base:**` header.
2. **Strict Ancestry Pre-Flight Gate**: Integration refuses unless the plan branch is fully rebased onto its parent branch (`git merge-base --is-ancestor <parent> <plan>`).
3. **Zero Ignored-File Data Loss**: Worktree removal checks for untracked/ignored files (`.env`) and halts with a diagnostic before deleting.
4. **Attribution & Lineage Survival**: Squash commits carry structured metadata trailers (`Plan-ID:`, `Plan-Parent:`, `Base-Branch:`) and preserve AI semantic attribution trailers.

---

## 2. Technical Blueprint

### 2.1 Configuration Parameters (`git config aapp.*`)
Seeded only when absent by `cmd_init.sh`:

| Config Key | Allowed Values | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `aapp.integrate` | `squash` \| `ff` \| `manual` | `squash` | Default integration strategy upon completion: `squash` (milestone commit), `ff` (fast-forward microcommits), or `manual` (print advice only, P-54 behavior). |
| `aapp.integrateTarget` | `parent` \| `dev` \| `<branch>` | `parent` | Integration target branch: `parent` resolves the branch the worktree was spawned from; `dev` resolves `aapp.devBranch`. |
| `aapp.integrateCleanup` | `true` \| `false` | `true` | Automatically remove worktree and delete plan branch after successful integration. |
| `aapp.maxEmergencyHotfixes` | integer | `1` | Maximum allowable emergency fixes before a plan is mechanically blocked. |

### 2.2 Parent Branch Resolution & Modular Lineage

In modular repository architectures, concurrent plans branch from different parent branches:
```text
develop (Root Development Branch)
  │
  ├── module/billing (Parent Branch)
  │     └── plan/p51-stripe-webhook (Worktree Branch) ──► squashes into module/billing
  │
  ├── module/auth (Parent Branch)
  │     └── plan/p54-jwt-rotation   (Worktree Branch) ──► squashes into module/auth
  │
  └── emergency bugfixes (#41, #42, #43)
```

1. **Resolution Logic (`lib/aapp-lib.sh:resolve_plan_integrate_target`)**:
   - When `aapp.integrateTarget = parent` (default):
     - Inspects the plan header in `.plans/done/<file>` (or `.plans/current/<file>`):
       ```markdown
       * **Base:** `d52551e` (module/auth)
       ```
     - Extracts the branch name `module/auth`.
     - Asserts that `module/auth` exists as a local or remote branch ref.
   - When `aapp.integrateTarget = dev`:
     - Resolves the candidate list from `aapp.devBranch` (`develop dev development`).
   - When set to an explicit branch name:
     - Uses the explicit branch name directly.

2. **Lineage Attribution Trailers**:
   When integrating via `squash`, the synthesized commit message on the parent branch automatically embeds lineage trailers:
   ```text
   feat(auth): implement JWT token rotation (P-54)

   Plan-ID: P-54
   Plan-Parent: module/auth
   Base-Branch: develop
   AI-Agent: Antigravity
   AI-Vendor: Google
   AI-Model: gemini-3.8-flash
   ```
   When `module/auth` is later merged into `develop`, the history retains full traceability of which plan authored the feature.

### 2.3 The Two Integration Models (Empirically Proven)

Empirical testing in Git test harnesses confirmed two supported models:

#### Model A: Milestone Squash (`aapp.integrate = squash`, Default)
1. Verifies that `<plan-branch>` contains `<target-branch>` (`git merge-base --is-ancestor <target-branch> <plan-branch>`).
2. Switches the primary checkout to `<target-branch>` (refusing if primary checkout has uncommitted changes).
3. Executes `git merge --squash <plan-branch>`.
4. Gathers commit message: extracts the plan's title and `* **Changelog:**` line, appends lineage and AI attribution trailers.
5. Commits to `<target-branch>`.
6. Executes cleanup per §2.4.

#### Model B: Microcommit Model (`aapp.integrate = ff`)
1. Verifies ancestry (`git merge-base --is-ancestor <target-branch> <plan-branch>`).
2. Switches primary checkout to `<target-branch>`.
3. Executes `git merge --ff-only <plan-branch>`.
4. All individual microcommits (and intermediate emergency hotfixes) survive directly on `<target-branch>` with 100% linear history and original commit SHAs.
5. P-48 union merge for `CHANGELOG.md` guarantees zero merge conflicts.
6. Executes cleanup per §2.4.

### 2.4 Safe Worktree Removal & Ignored-File Protection

`git worktree remove` silently and permanently deletes untracked ignored files (e.g. `.env`, local configs, build artifacts).

* **Pre-Removal Inspection (`lib/cmd_integrate.sh:safe_worktree_remove`)**:
  1. Inspects the worktree for untracked ignored files:
     ```bash
     ignored_files="$(git -C "$worktree_path" status --porcelain --ignored | grep -E '^\!\! ' | awk '{print $2}')"
     ```
  2. If sensitive ignored files (matching `.env*`, `*.pem`, `*.key`, `*secret*`) are found:
     - **Default:** Refuses removal, prints the detected files, and instructs the user to either back them up or run with `--force-cleanup`.
     - **Safe Backup Option:** If `aapp.quarantineIgnored = true`, copies them to `.plans/quarantine/<plan-id>/` before deletion.
  3. Executes `git worktree remove "$worktree_path"`.
  4. Deletes the plan branch:
     - If integrated via `ff`: runs safe `git branch -d <plan-branch>`.
     - If integrated via `squash`: runs `git branch -D <plan-branch>` (since `-d` fails after squash merges because the squashed commit SHA is not an ancestor).

### 2.5 CLI Interface (`aapp integrate` & `aapp done` Hookup)

1. **Standalone Verb (`aapp integrate`)**:
   ```bash
   aapp integrate [<plan-id>] [--squash | --ff] [--target <branch>] [--no-cleanup] [--force-cleanup]
   ```
   Can be run on any archived plan in `done/` (or active plan ready for integration).

2. **Integration at `aapp done`**:
   `aapp done` gains an optional token or automatic execution:
   ```bash
   aapp done <id> [integrate | no-integrate]
   ```
   - If `aapp.integrate = manual` (current P-54 default): prints `aapp integrate <id>` advice.
   - If `aapp.integrate = squash` or `ff`: automatically triggers `aapp integrate <id>` upon successful archival.

### 2.6 Mechanical Gate for 2+ Emergency Fixes

Enforces the "Rule of 2" to prevent endless daisy-chaining of hotfixes:
1. `count_plan_emergency_extensions "$plan_file"`: counts items in `### 🚨 Emergency Hotfix Extensions`.
2. `count_plan_blocked_on "$plan_file"`: counts issue IDs in `* **Blocked On:**`.
3. If total >= 2:
   - `aapp unblock` refuses to return status to `⚡ In Development`.
   - `aapp integrate` refuses integration with:
     ```text
     ❌ [Integration Block] Plan 'P-XX' accumulated 2+ emergency fixes (#41, #42).
        Daisy-chaining hotfixes is prohibited without formal re-scoping.
        Requires human sign-off: run 'aapp integrate P-XX --override-hotfix-cap'.
     ```

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`. Adopters with manual integration scripts continue working because `aapp.integrate` defaults to `manual` if unconfigured, or can be set to `squash`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Parent Branch Resolver & Inspection Engine
- [ ] Task 1.1: Implement `resolve_plan_integrate_target` in `lib/aapp-lib.sh`, extracting parent branch from `* **Base:**` header.
- [ ] Task 1.2: Implement `check_worktree_ignored_files` in `lib/aapp-lib.sh` to detect untracked `.env` and sensitive files before removal.
- [ ] Task 1.3: Implement `count_plan_emergency_extensions` and `count_plan_blocked_on` in `lib/aapp-lib.sh`.

### Phase 2: Core Integration Engine (`lib/cmd_integrate.sh`)
- [ ] Task 2.1: Create `lib/cmd_integrate.sh` implementing `cmd_integrate`:
  - Target branch resolution (`parent` vs `dev`).
  - Pre-flight ancestry check (`git merge-base --is-ancestor`).
  - Emergency fix cap enforcement (veto if >= 2 hotfixes without override).
- [ ] Task 2.2: Implement `integrate_squash`:
  - Synthesize message with plan title, changelog line, `Plan-ID:`, `Plan-Parent:`, and AI semantic trailers.
  - Commit to target branch.
- [ ] Task 2.3: Implement `integrate_ff`:
  - Fast-forward merge onto target branch.
- [ ] Task 2.4: Implement safe cleanup (`git worktree remove` + branch deletion).

### Phase 3: Lifecycle Hookup & Dispatch Routing
- [ ] Task 3.1: Wire `aapp integrate` into CLI switchboard in `bin/aapp` (and `aapp`).
- [ ] Task 3.2: Hook into `lib/cmd_plan.sh` (`cmd_done`):
  - When `aapp.integrate` is `squash` or `ff`, trigger automated integration upon archival.
- [ ] Task 3.3: Implement universal skill `templates/skills/aapp-integrate/SKILL.md`.

### Phase 4: Test Suite & Documentation
- [ ] Task 4.1: Write unit and integration test suite `tests/integrate_test.sh`:
  - Parent branch targeting (module branch vs develop).
  - Squash integration with trailers and `-D` branch cleanup.
  - Fast-forward microcommit integration.
  - Ignored file (`.env`) warning and abort.
  - Emergency fix cap veto (2+ blockers halt integration).
- [ ] Task 4.2: Update `MANUAL.md`, `README.md`, and `CHEATSHEET.md` with `aapp.integrate*` configs and `aapp integrate` command syntax.
- [ ] Task 4.3: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md`.
- [ ] Task 4.4: Run full test suite (`./aapp test`) and ensure clean pass.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `lib/cmd_integrate.sh` -> Core integration command implementation (squash, ff, cleanup).
- [ ] `lib/aapp-lib.sh` -> Target branch resolver, ancestry checks, ignored-file detector, and hotfix counter.
- [ ] `lib/cmd_plan.sh` -> `cmd_done` integration hookup and `aapp unblock` hotfix cap check.
- [ ] `lib/cmd_init.sh` -> Seed `aapp.integrate`, `aapp.integrateTarget`, and `aapp.integrateCleanup` config defaults.
- [ ] `NEW FILE` -> `lib/docs/verbs/integrate.md` -> CLI verb contract for integrate.
- [ ] `NEW FILE` -> `templates/skills/aapp-integrate/SKILL.md` -> Universal skill for automated branch integration.
- [ ] `NEW FILE` -> `tests/integrate_test.sh` -> Automated test harness for squash, ff, parent targeting, and safe cleanup.
- [ ] `MANUAL.md` -> Document automated integration, multi-branch module targeting, and worktree cleanup.
- [ ] `README.md` -> Update feature table with worktree integration engine.
- [ ] `CHEATSHEET.md` -> Add `aapp integrate` and config options.
- [ ] `ARCHITECTURE.md` -> Document parent branch resolution and integration lifecycle.
- [ ] `.agents/CODEMAP.md` -> Register `cmd_integrate.sh` and integration verb ownership.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Layer 1 write guard remains untouched.
- [ ] `templates/aapp-pre-commit` -> Layer 2 pre-commit gate remains untouched.
- [ ] `lib/commit_engine.sh` -> Plan recording engine remains untouched.

---

## ❓ 5. Open Questions (Optional / Gate)

* [ ] **Question 1 — Default activation in `cmd_done`:** Should `aapp done` automatically execute `aapp integrate` when `aapp.integrate` is configured (`squash`/`ff`), or should `aapp done` always require an explicit flag (`aapp done <id> integrate`)?
  - *Option (a) (Recommended):* Automatic when configured (`aapp.integrate = squash`). Eliminates manual chores for autonomous runners. Interactive users can set `aapp.integrate = manual`.
  - *Option (b):* Always require explicit `aapp integrate <id>` or `aapp done <id> integrate`.
* [ ] **Question 2 — Untracked ignored file quarantine:** When `git worktree remove` encounters untracked `.env` or ignored files, should it automatically quarantine them to `.plans/quarantine/<plan-id>/`, or refuse and prompt?
  - *Option (a) (Recommended):* Refuse and require `--force-cleanup`, unless `aapp.quarantineIgnored = true` is set, which copies them to `.plans/quarantine/<id>/`.

---

## 📦 6. Change Log & Refinement History

* **2026-10-04:** Drafted blueprint based on findings from RFC P-52/P-54, empirical Git tests for squash vs microcommit models, parent-branch targeting for modular hierarchies (`develop` vs `module/*`), lineage trailer synthesis, and safe worktree cleanup mechanics.
