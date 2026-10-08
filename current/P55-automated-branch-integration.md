# 🗺️ Plan P-55: Automated Worktree Branch Integration, Parent Branch Lifecycle & Safe Cleanup
* **Created:** 2026-10-04 | **Last Refined:** 2026-10-07
* **Target Issue / Milestone:** Multi-Agent Worktree Integration Engine (Pickup #8)
* **Plan ID:** P-55
* **Changelog:** Added: Automated worktree branch integration, parent-branch targeting, and safe cleanup (`aapp done <id> integrate`)
* **Status:** ⚡ In Development
* **Base:** `61d1f9b` (develop)
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
> 6. **User Documentation Sync**: Update `MANUAL.md`, `README.md`, and `CHEATSHEET.md` with new `aapp done integrate` commands and config options.
> 7. **Architecture & Codemap Sync**: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` for integration verb ownership and helpers.
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
| `aapp.integrate` | `squash` \| `ff` \| `hook` \| `manual` | `manual` | Integration strategy upon completion: `squash` (milestone commit), `ff` (fast-forward microcommits), `hook` (§2.7), or `manual` (print advice only, P-54 behavior). Seeded `manual` (Q1): nothing changes until a repository opts in. |
| `aapp.integrateTarget` | `parent` \| `dev` \| `<branch>` | `parent` | Integration target branch: `parent` resolves the branch the worktree was spawned from; `dev` resolves `aapp.devBranch`. |
| `aapp.integrateCleanup` | `true` \| `false` | `true` | Automatically remove worktree and delete plan branch after successful integration. |
| `aapp.quarantineIgnored` | `true` \| `false` | `false` | When true, automatically backup sensitive ignored files (`.env`) to `.git/aapp_quarantine/<plan-id>/` before removing worktree. |

*(Note: `aapp.maxEmergencyHotfixes` is owned and seeded by P-52 with default `2`; P-55 reads it for its integration pre-flight check).*

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

**Pre-flight before any mutation (P-23 invariant: a gate cannot fail after the action is committed).** When `aapp done` integrates (automatically, or with the `integrate` token on a plan still in `current/`), every integration check runs **before** `pre-done` and the archive commit: an open mini plan in the main checkout (waited for under the issue lock with the P-52 roller, up to `aapp.issueFixWait`; `0` fails at once), the target branch resolving, ancestry (`git merge-base --is-ancestor`), a clean main checkout, and the `aapp.maxEmergencyHotfixes` fallback (§2.6). Any failure → `done` refuses and nothing is archived. After these checks the built-in squash and fast-forward cannot fail on content (the plan branch already contains the target); only the `hook` delegate (§2.7) can still refuse after archival, and `aapp done <id> integrate` retries it. Standalone integration of a plan in `done/` runs the same checks before switching the main checkout.

Empirical testing in Git test harnesses confirmed two supported models:

#### Model A: Milestone Squash (`aapp.integrate = squash`)
1. Pre-flight passed (above), including no open mini plan, so the primary checkout is never switched away mid-fix.
2. Verifies that `<plan-branch>` contains `<target-branch>` (`git merge-base --is-ancestor <target-branch> <plan-branch>`).
3. Switches the primary checkout to `<target-branch>` (refusing if primary checkout has uncommitted changes).
4. Executes `git merge --squash <plan-branch>`.
5. Gathers commit message: extracts the plan's title and `* **Changelog:**` line, appends lineage and AI attribution trailers.
6. Commits to `<target-branch>`.
7. Executes cleanup per §2.4.

#### Model B: Microcommit Model (`aapp.integrate = ff`)
1. Pre-flight passed (above).
2. Verifies ancestry (`git merge-base --is-ancestor <target-branch> <plan-branch>`).
3. Switches primary checkout to `<target-branch>`.
4. Executes `git merge --ff-only <plan-branch>`.
5. All individual microcommits (and intermediate emergency hotfixes) survive directly on `<target-branch>` with 100% linear history and original commit SHAs.
6. P-48 union merge for `CHANGELOG.md` guarantees zero merge conflicts.
7. Executes cleanup per §2.4.

### 2.4 Safe Worktree Removal & Ignored-File Protection

`git worktree remove` silently and permanently deletes untracked ignored files (e.g. `.env`, local configs, build artifacts).

* **Pre-Removal Inspection (`lib/aapp-lib.sh:safe_worktree_remove`)**:
  1. Inspects the worktree for untracked ignored files:
     ```bash
     ignored_files="$(git -C "$worktree_path" status --porcelain --ignored | grep -E '^\!\! ' | awk '{print $2}')"
     ```
  2. If sensitive ignored files (matching `.env*`, `*.pem`, `*.key`, `*secret*`) are found (Q2: refuse by default, quarantine opt-in):
     - **Default:** Refuses removal, prints the detected files, and instructs the user to either back them up or run with bare token `force-cleanup`. The integration already done stands; only the cleanup is refused, and `aapp done <id> integrate` (or the manual commands) completes it later.
     - **Safe Backup Option (opt-in):** If `aapp.quarantineIgnored = true`, copies them to `$(git rev-parse --git-common-dir)/aapp_quarantine/<plan-id>/` (inside `.git`, untracked and never pushed) before deletion, and says where. Never copies secrets into `.plans/quarantine/`.
  3. Executes `git worktree remove "$worktree_path"`.
  4. Deletes the plan branch:
     - If integrated via `ff`: runs safe `git branch -d <plan-branch>`.
     - If integrated via `squash`: runs `git branch -D <plan-branch>` (since `-d` fails after squash merges because the squashed commit SHA is not an ancestor).

### 2.5 CLI Interface (`aapp done <id> integrate`)

Integration is executed via tokens on the existing `done` lifecycle verb (strictly preserving the invariant `lib/verbs.tsv -> No new verbs`):
```bash
aapp done <id> integrate [squash | ff | hook] [target <branch>] [no-cleanup] [force-cleanup]
```

1. **Automatic Archival & Integration (`aapp done <id>`)**:
   - If `aapp.integrate = squash`, `ff` or `hook` and the plan records a `* **Worktree:**` (P-54): running `aapp done <id>` archives the plan and automatically executes integration into its parent branch, one command (Q1). A plan without a worktree has its commits on the development branch already: `done` archives as today.
   - If `aapp.integrate = manual` (seeded default, Q1): archives the plan and prints `aapp done <id> integrate` advice without integrating.
   - Override token: `aapp done <id> no-integrate` archives the plan and skips integration regardless of configuration.

2. **Standalone / Post-Archival Integration (`aapp done <id> integrate ...`)**:
   - Can be run on any already archived plan in `.plans/done/` (or active plan ready for integration).
   - Reads the plan's `* **Base:**` and `* **Worktree:**` headers to locate the worktree and target branch.

### 2.6 Mechanical Gate for 2+ Emergency Fixes

Enforces the "Rule of 2" to prevent endless daisy-chaining of hotfixes:
1. `count_plan_emergency_hotfixes "$plan_file"`: counts issue IDs in the append-only `* **Emergency Hotfixes:**` header line populated by `aapp issue hotfix` (P-52).
2. If `count > aapp.maxEmergencyHotfixes` (e.g. `count >= 3` with default `maxEmergencyHotfixes = 2`):
   - `aapp issue hotfix` blocks the plan permanently at the 3rd hotfix (P-52).
   - `aapp done <id> integrate` refuses integration with:
     ```text
     ❌ [Integration Block] Plan 'P-XX' accumulated 3+ emergency fixes (#41, #42, #43).
        Daisy-chaining hotfixes is prohibited without formal re-scoping.
        Requires human sign-off: run 'aapp done P-XX integrate override-hotfix-cap'.
     ```


### 2.7 `on-integrate` action delegate
Mirrors `on-sync` (`aapp.syncStrategy = hook`): with `aapp.integrate = hook` (or the `hook` token), after pre-flight the built-in squash / fast-forward is replaced by the `on-integrate` handler, dispatched in `gate` mode with `{"plan_id", "plan_file", "plan_branch", "target_branch", "worktree"}`. Teams that integrate through pull requests, or deploy through a plugin, plug in here.
- Exit `0`: integration is the handler's (e.g. a PR opened or merged); non-zero: `done` reports the refusal, the plan stays archived, and `aapp done <id> integrate` retries.
- `hook` with no `on-integrate` handler registered → refuse before archiving (fail closed, like `syncStrategy=hook` without `on-sync`).
- Built-in cleanup (§2.4) is **skipped** under `hook`: a PR flow still needs the plan branch; the handler owns the branch's lifecycle.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`. Adopters with manual integration scripts continue working because `aapp.integrate` defaults to `manual` if unconfigured, or can be set to `squash`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Parent Branch Resolver & Inspection Engine
- [ ] Task 1.1: Implement `resolve_plan_integrate_target` in `lib/aapp-lib.sh`, extracting parent branch from `* **Base:**` header.
- [ ] Task 1.2: Implement `check_worktree_ignored_files` in `lib/aapp-lib.sh` to detect untracked `.env` and sensitive files before removal.
- [ ] Task 1.3: Implement `count_plan_emergency_hotfixes` in `lib/aapp-lib.sh`.

### Phase 2: Core Integration Engine (`lib/aapp-lib.sh` & `lib/cmd_plan.sh`)
- [ ] Task 2.1: Implement integration pre-flight engine in `lib/aapp-lib.sh`:
  - Runs before `pre-done` and the archive commit (§2.3); mini-plan check waits with the P-52 roller under the issue lock (`aapp.issueFixWait`, `0` = fail fast).
  - Target branch resolution (`parent` vs `dev`).
  - Pre-flight ancestry check (`git merge-base --is-ancestor`).
  - Emergency fix cap enforcement (veto if > `aapp.maxEmergencyHotfixes`, e.g. >= 3, without override).
- [ ] Task 2.2: Implement `integrate_squash` in `lib/aapp-lib.sh`:
  - Synthesize message with plan title, changelog line, `Plan-ID:`, `Plan-Parent:`, and AI semantic trailers.
  - Commit to target branch.
- [ ] Task 2.3: Implement `integrate_ff` in `lib/aapp-lib.sh`:
  - Fast-forward merge onto target branch.
- [ ] Task 2.4: Implement safe cleanup (`git worktree remove` + branch deletion + `.git/aapp_quarantine/` backup); skipped under `hook`.
- [ ] Task 2.5: `on-integrate` delegate (§2.7): dispatch in `gate` mode under `aapp.integrate = hook` / `hook` token; refuse when no handler is registered.

### Phase 3: Lifecycle Hookup & Dispatch Routing
- [ ] Task 3.1: Wire `integrate` tokens into `lib/cmd_plan.sh` (`cmd_done`):
  - When `aapp.integrate` is `squash` or `ff`, trigger automated integration upon archival.
  - Standalone `aapp done <id> integrate ...` acts on plans in `current/` or `done/`.
- [ ] Task 3.2: Update universal skill `templates/skills/aapp-done/SKILL.md` with integration tokens.

### Phase 4: Test Suite & Documentation
- [ ] Task 4.1: Write unit and integration test suite `tests/integrate_test.sh`:
  - Parent branch targeting (module branch vs develop).
  - Squash integration with trailers and `-D` branch cleanup.
  - Fast-forward microcommit integration.
  - Integration checks run before the archive: a failing check leaves the plan in `current/` and nothing committed; an open mini plan is waited for (and `aapp.issueFixWait 0` refuses at once).
  - `on-integrate`: a registered handler replaces the built-in squash; no handler with `hook` refuses before archiving; cleanup skipped; a refusing handler leaves the plan archived and `done <id> integrate` retries.
  - Ignored file (`.env`): cleanup refused by default with the files listed, integration kept; with `aapp.quarantineIgnored = true`, safe `.git` quarantine then removal (Q2).
  - Seeded `manual`: `done` of a worktree plan archives without integrating and prints the advice; a plan without a worktree is never integrated (Q1).
  - Emergency fix cap veto (3+ blockers halt integration).
- [ ] Task 4.2: Update `MANUAL.md`, `README.md`, and `CHEATSHEET.md` with `aapp.integrate*` configs and `aapp done <id> integrate` command syntax.
- [ ] Task 4.3: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md`.
- [ ] Task 4.4: Run full test suite (`./aapp test`) and ensure clean pass.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/aapp-lib.sh` -> Target branch resolver, ancestry checks, ignored-file detector, quarantine helper, and squash/ff engines.
- [ ] `lib/cmd_plan.sh` -> `cmd_done` integration hookup and `integrate` subcommand tokens.
- [ ] `lib/cmd_init.sh` -> Seed `aapp.integrate`, `aapp.integrateTarget`, `aapp.integrateCleanup`, and `aapp.quarantineIgnored` config defaults.
- [ ] `lib/docs/verbs/done.md` -> CLI verb contract updates for `integrate` tokens on `done`.
- [ ] `templates/skills/aapp-done/SKILL.md` -> Universal skill updates for branch integration tokens.
- [ ] `NEW FILE` -> `tests/integrate_test.sh` -> Automated test harness for squash, ff, parent targeting, and safe cleanup.
- [ ] `MANUAL.md` -> Document automated integration, multi-branch module targeting, worktree cleanup, and the `on-integrate` event (lifecycle event table).
- [ ] `README.md` -> Update feature table with worktree integration engine.
- [ ] `CHEATSHEET.md` -> Add `aapp done <id> integrate` and config options.
- [ ] `ARCHITECTURE.md` -> Document parent branch resolution and integration lifecycle.
- [ ] `.agents/CODEMAP.md` -> Register integration functions in `cmd_plan.sh` and `aapp-lib.sh`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/verbs.tsv` -> No new verbs; integration belongs to `aapp done`.
- [ ] `templates/blast-radius-guard.sh` -> Layer 1 write guard remains untouched.
- [ ] `templates/aapp-pre-commit` -> Layer 2 pre-commit gate remains untouched.
- [ ] `lib/commit_engine.sh` -> Plan recording engine remains untouched.

---

## ❓ 5. Open Questions (Optional / Gate)

* [x] **Question 1 — Default activation in `cmd_done`: → RESOLVED (developer, 2026-10-08): automatic, seeded `manual`.** `done` integrates automatically when `aapp.integrate` is `squash`/`ff`/`hook` and the plan records a Worktree; init seeds `manual`, so nothing changes until a repository opts in (§2.1, §2.5). Should `aapp done` automatically execute integration when `aapp.integrate` is configured (`squash`/`ff`), or should `aapp done` always require an explicit flag (`aapp done <id> integrate`)?
  - *Option (a) (Recommended):* Automatic when configured (`aapp.integrate = squash`). Eliminates manual chores for autonomous runners. Interactive users can set `aapp.integrate = manual`.
  - *Option (b):* Always require explicit `aapp done <id> integrate`.
* [x] **Question 2 — Untracked ignored file quarantine: → RESOLVED (developer, 2026-10-08): option (a), refuse by default, quarantine opt-in.** The integration stands; only the cleanup is refused, listing the files (§2.4). When `git worktree remove` encounters untracked `.env` or ignored files, should it automatically quarantine them or refuse?
  - *Option (a) (Recommended):* Refuse and require bare token `force-cleanup`, unless `aapp.quarantineIgnored = true` is set, which safely copies them to `$(git rev-parse --git-common-dir)/aapp_quarantine/<id>/` (inside `.git`, never in `.plans`).

---

## 📦 6. Change Log & Refinement History
* **2026-10-08:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-08:** Q1 and Q2 resolved (developer): automatic integration on `done` for worktree plans, with `aapp.integrate` seeded `manual` (no change until opt-in); ignored sensitive files refuse the cleanup by default (integration kept), quarantine opt-in via `aapp.quarantineIgnored`. Tests for both added to Task 4.1.
* **2026-10-07:** Integration checks run before `pre-done` and the archive commit (P-23 invariant), so `done` integrates fully or archives nothing; the mini-plan wait follows P-52's roller (no `wait` token); added the `on-integrate` action delegate (`aapp.integrate = hook`, mirrors `on-sync`), with cleanup skipped under it (developer decision).

* **2026-10-07:** Refined blueprint from cross-review findings: integration folded into `aapp done <id> integrate` (preserving `lib/verbs.tsv` invariant); dropped duplicate seeding of `aapp.maxEmergencyHotfixes` (owned by P-52); corrected veto to `> max` (>= 3); dropped ghost verb `unblock`; added pre-flight refusal when mini-plans are active in the primary checkout; standardized on bare token `force-cleanup`; moved quarantine destination inside `.git` (`$(git rev-parse --git-common-dir)/aapp_quarantine/<id>/`) to prevent secret leaks into `.plans`.
* **2026-10-04:** Drafted blueprint based on findings from RFC P-52/P-54, empirical Git tests for squash vs microcommit models, parent-branch targeting for modular hierarchies (`develop` vs `module/*`), lineage trailer synthesis, and safe worktree cleanup mechanics.
