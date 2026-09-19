# 🗺️ Plan P-23: Lifecycle Hook Sequencing, Pre-Mutation Quality Gates & Return Code Abort Protocol
* **Created:** 2026-09-19 | **Last Refined:** 2026-09-19
* **Target Issue / Milestone:** Milestone v1.2.1 (Lifecycle Extension Governance)
* **Plan ID:** P-23
* **Status:** 🟣 Under Review
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 5. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.

---

## 1. Context & Architectural Goal
* **What**: Re-order and formalize the execution timing of all lifecycle hooks across AAPP commands (`freeze`, `start`, `freeze-start`, `done`, `sync`, `pause`, `resume`). Establish a symmetric Pre/Post lifecycle architecture where all `pre-*` hooks act as **Pre-Mutation Quality Gates** executed strictly *before* any disk modifications or Git commits occur, with the absolute authority to **STOP** the operation based on their process return number (exit code).
* **Why**:
  1. **Transactional Integrity & The Trapped State Problem**: In the initial P-12 implementation, `on-freeze` and `on-start` fired *after* the blueprint header was rewritten on disk and committed to Git in `.plans/`. If a gating hook (such as an un-annotated fallback ratchet or security scanner) returned exit code `1`, AAPP halted with an error, but the blueprint had already been committed as `🔷 Frozen`. Because the pre-commit hook enforces strict design-lock on frozen plans, the developer was trapped: they could not fix Section 2 or Section 4 without unfreezing first. Gating hooks must execute *before* the vault door is locked.
  2. **Deterministic Return Code Contract**: Codifies standard POSIX exit-code behavior across all gating hooks:
     - `0`: Pass (Success) $\rightarrow$ proceed with state mutation and Git commit.
     - `1` *(or any non-zero except 2)*: **STOP immediately**. Abort the command, stream `stderr` diagnostics, and make **zero changes** to working trees, buffers, or Git history.
     - `2`: Advisory warning. Log diagnostic but allow the command to proceed.
     - `124`: Watchdog timeout. Treated as return code `1` (hard abort).
  3. **Symmetric Taxonomy (`pre-*` vs `post-*` vs `on-*`)**:
     - `pre-*` hooks are **GATES** (pre-mutation; can abort the operation).
     - `post-*` hooks are **OBSERVERS** (post-mutation; report completed events to webhooks/sync).
     - `on-*` hooks are **ACTION DELEGATES** (e.g. `on-sync` replacing built-in transport).
  4. **Pre-Done Quality Verification**: Introduces `pre-done` enabling teams to gate plan archival on test pass rates, verification matrices, or Definition of Done checklists before moving files to `.plans/done/`.
* **The Invariant**: A gate cannot fail after the action has already been committed to history. Gating happens before mutation; observation happens after mutation.

---

## 2. Technical Blueprint

### A. The Return Code Contract (Exit Codes)
All `pre-*` gating hooks communicate their verdict to the calling AAPP command via standard process exit codes:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        PRE-MUTATION GATING FLOW                        │
└────────────────────────────────────────────────────────────────────────┘

              [ Command Invocation, e.g. aapp freeze <plan> ]
                                   │
                                   ▼
                    [ Pre-flight Syntactic Checks ]
                                   │
                                   ▼
                 [ Fire 'pre-freeze' Gating Hook(s) ]
                                   │
                    ┌──────────────┴──────────────┐
                    │                             │
               Exit Code 0                   Exit Code != 0
               (or Code 2)                   (1, 124, etc.)
                    │                             │
                    ▼                             ▼
        [ Mutate State on Disk ]           🛑 HARD ABORT
                    │                   • Output Hook STDERR
                    ▼                   • ZERO disk modifications
         [ Git Commit to .plans ]       • ZERO Git commits
                    │                   • Return exit code 1
                    ▼
        [ Fire 'post-freeze' ]
```

| Return Code | Semantics | Command Behavior |
| :---: | :--- | :--- |
| **`0`** | **Pass (Success)** | Hook approved the operation. Command proceeds to mutate state and commit. |
| **`1`** | **STOP (Fatal Rejection)** | **Hard abort immediately.** Command exits with code 1. Zero disk or Git state mutations. |
| **`2`** | **Advisory Warning** | Non-fatal check warning. Command logs diagnostic to `stderr` and proceeds. |
| **`124`** | **Watchdog Timeout** | Handler exceeded timeout budget. Treated as return code `1` (hard abort). |
| Other | **Fatal Error** | Treated as return code `1` (hard abort). |

---

### B. Lifecycle Command Execution Sequences

#### 1. Plan Freezing (`aapp freeze <plan>`)
1. **Pre-Flight Validation**: Check that all Open Questions in Section 5 are checked off (`[x]`) and Target Files are declared in Section 4.
2. **`pre-freeze` Gate**: Dispatches payload `{"plan_id": "$plan_id", "plan_file": "$plan_file", "target_files": [...]}`.
   - If hook exits non-zero: **Hard abort.** The blueprint remains untouched in `.plans/current/` with status `🟣 Under Review` or `📝 Refining`.
3. **State Mutation**: Rewrite blueprint status to `* **Status:** 🔷 Frozen`, lock marker to `LOCKED`, append changelog, and update `.plans/state_matrix.md`.
4. **Git Commit**: Commit to `.plans/` (`plan(freeze): lock blast radius and greenlight $plan_id`).
5. **`post-freeze` Observer**: Fires in `mode=notify` to broadcast event to external systems.

#### 2. Plan Activation (`aapp start <plan>`)
1. **Pre-Flight Validation**: Check that blueprint status is `🔷 Frozen`, and run `check_disjointness_activation_gate` ensuring no target file collision with other active plans.
2. **`pre-start` Gate**: Dispatches payload with plan ID and target files.
   - If hook exits non-zero: **Hard abort.** Active buffer is not written; plan remains `🔷 Frozen`.
3. **State Mutation**: Rewrite blueprint status to `* **Status:** ⚡ In Development`, bind active plan pointer buffer (`.git/aapp_active_plan`), and update `.plans/state_matrix.md`.
4. **Git Commit**: Commit to `.plans/` (`plan(start): activate $plan_id into development`).
5. **`post-start` Observer**: Fires in `mode=notify`.

#### 3. Atomic Freeze-Start (`aapp freeze-start <plan>`)
1. **Pre-Flight Validation**: Open questions, target files, and disjointness validation.
2. **`pre-freeze` Gate**: If exits non-zero: **Hard abort.**
3. **`pre-start` Gate**: If exits non-zero: **Hard abort.**
4. **State Mutation**: Rewrite status to `⚡ In Development`, mark `LOCKED`, bind active buffer, update `state_matrix.md`.
5. **Git Commit**: Commit to `.plans/` (`plan(start): freeze and activate $plan_id into development`).
6. **`post-freeze` & `post-start` Observers**: Fire in `mode=notify`.

#### 4. Plan Archival & Completion (`aapp done <plan>`)
1. **`pre-done` Gate**: Dispatches `{"plan_id": "$plan_id", "plan_file": "$plan_file"}`. Enables project gates to ensure automated test suites pass and DoD is fulfilled.
   - If hook exits non-zero: **Hard abort.** Blueprint remains active in `current/`; ledger and buffer are untouched.
2. **State Mutation**: Move blueprint from `current/` to `done/`, append row to `000-archive-ledger.md`, prune from `state_matrix.md`, clear `.git/aapp_active_plan` buffer.
3. **Git Commit**: Commit to `.plans/` (`plan(done): archive $plan_id to done/ and update state matrix`).
4. **`post-done` Observer (formerly `on-done`)**: Fires in `mode=notify` with commit hash and archive file path. Triggers automated worktree sync (`examples/hooks/on-done-sync.sh`) or cloud notifications.

#### 5. Remote Worktree Synchronization (`aapp push`, `pull`, `sync`)
1. **Pre-Flight Cleanliness Check**: Assert no uncommitted changes in active worktrees.
2. **`pre-sync` Gate**: Dispatches action, remote, and worktree array.
   - **Fail-Closed Gate**: If `pre-sync` exits non-zero, **abort sync immediately** before initiating any network requests or transport actions.
3. **Transport Execution**:
   - If `aapp.syncStrategy = hook`: Dispatches `on-sync` transport delegate. Aborts on exit non-zero.
   - If `aapp.syncStrategy = builtin`: Executes native Git worktree push/pull with `--ff-only`. Aborts on exit non-zero.
4. **`post-sync` Observer**: Fires in `mode=notify` after successful transport across all worktrees.

#### 6. Emergency Brake & Resumption (`aapp pause`, `aapp resume`)
- **`post-pause`**: Fires in `mode=notify` after worktrees are safely stashed and pause buffer is recorded. (Pausing is an emergency brake and cannot be blocked).
- **`post-resume`**: Fires in `mode=notify` after stashes are restored and active state is recovered.

---

### C. Unified Lifecycle Event Taxonomy

| Event | Type | Timing | Default Mode | Authority to Stop | Payload Context |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **`pre-freeze`** | Gate | Pre-mutation | `gate` | **YES** | Plan ID, plan path, proposed target files. |
| **`post-freeze`** | Observer | Post-commit | `notify` | No | Plan ID, plan path, locked target files. |
| **`pre-start`** | Gate | Pre-mutation | `gate` | **YES** | Plan ID, plan path, target files. |
| **`post-start`** | Observer | Post-commit | `notify` | No | Plan ID, plan path, active buffer path. |
| **`pre-done`** | Gate | Pre-mutation | `gate` | **YES** | Plan ID, plan path, last commit SHA. |
| **`post-done`** | Observer | Post-commit | `notify` | No | Plan ID, archive path, commit SHA. |
| **`pre-sync`** | Gate | Pre-network | `gate` | **YES** | Action (`push`/`pull`/`sync`), remote, worktrees. |
| **`on-sync`** | Transport | In-transport | `gate` | **YES** | Action, remote, worktrees (executes transport). |
| **`post-sync`** | Observer | Post-transport | `notify` | No | Action, remote, worktrees, transport result. |
| **`post-pause`** | Observer | Post-stash | `notify` | No | Pause reason, quarantined worktree list. |
| **`post-resume`** | Observer | Post-restore | `notify` | No | Restored plan ID, restored worktree count. |

---

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break with Named Aliases`
- **Fallback Inventory**:
  - `on-freeze` $\rightarrow$ Aliased to `pre-freeze` (Gate). Emits deprecation notice recommending `pre-freeze`.
  - `on-start` $\rightarrow$ Aliased to `pre-start` (Gate). Emits deprecation notice recommending `pre-start`.
  - `on-done` $\rightarrow$ Aliased to `post-done` (Observer). Preserves existing starter templates and examples (`on-done-sync.sh`).
  - `on-pause` $\rightarrow$ Aliased to `post-pause` (Observer).
  - `on-resume` $\rightarrow$ Aliased to `post-resume` (Observer).
  - Deprecation Target: v2.0.0.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Re-Order Hook Sequencing in Core Commands
- [ ] Task 1.1: Update `cmd_freeze` in `lib/cmd_plan.sh` to dispatch `pre-freeze` (and legacy `on-freeze`) **before** modifying the plan file or committing to Git. Abort immediately on exit != 0.
- [ ] Task 1.2: Update `cmd_start` in `lib/cmd_plan.sh` to dispatch `pre-start` (and legacy `on-start`) **before** updating status, binding active buffer, or committing to Git. Abort immediately on exit != 0.
- [ ] Task 1.3: Update `cmd_freeze_start` in `lib/cmd_plan.sh` to run `pre-freeze` then `pre-start` before mutating disk state or committing to Git.
- [ ] Task 1.4: Update `cmd_done` in `lib/cmd_plan.sh` to dispatch `pre-done` gate **before** moving the blueprint, appending to ledger, or committing to Git. Keep `post-done` / `on-done` as post-commit observer.
- [ ] Task 1.5: Update `lib/cmd_sync.sh` to treat `pre-sync` as a fail-closed gate that aborts sync if return code != 0.
- [ ] Task 1.6: Update `lib/cmd_pause.sh` to dispatch `post-pause` and `post-resume` (aliasing `on-pause` and `on-resume`).

### Phase 2: Dispatcher Event Mapping & Aliasing
- [ ] Task 2.1: Update `lib/hook_dispatcher.sh` to support symmetric `pre-*` and `post-*` event dispatching with transparent legacy aliases (`on-freeze` $\rightarrow$ `pre-freeze`, `on-done` $\rightarrow$ `post-done`).
- [ ] Task 2.2: Update `lib/cmd_hook.sh` (`aapp hooks`, `hook-test`) to reflect `pre-*` and `post-*` event definitions.

### Phase 3: Templates, Test Suite & Documentation
- [ ] Task 3.1: Update starter registry template `templates/skills/aapp-hooks/registry.tsv` and `SKILL.md` to showcase `pre-freeze`, `pre-done`, `pre-sync`, and `post-done`.
- [ ] Task 3.2: Expand `tests/hooks_test.sh` with regression tests verifying:
  - `pre-freeze` exit 1 aborts `aapp freeze` with ZERO disk edits and ZERO commits to `.plans/`.
  - `pre-start` exit 1 aborts `aapp start` without setting active buffer.
  - `pre-done` exit 1 aborts `aapp done` leaving blueprint in `current/`.
  - `pre-sync` exit 1 aborts `aapp push`/`pull`/`sync` before network actions.
  - Exit code 2 logs warning and proceeds.
  - Legacy event aliases dispatch transparently.
- [ ] Task 3.3: Document the Pre/Post execution sequence, return code abort contract, and lifecycle pipeline in `MANUAL.md` and `README.md`.
- [ ] Task 3.4: Update `CHANGELOG.md`.

---

## 💥 4. Blast Radius & System Boundaries
*(Marked: **PROPOSED** — confers no execution rights until frozen)*

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_plan.sh` -> Re-order hook dispatch points for `cmd_freeze`, `cmd_start`, `cmd_freeze_start`, and `cmd_done`.
- [ ] `lib/cmd_sync.sh` -> Make `pre-sync` a fail-closed gate before transport.
- [ ] `lib/cmd_pause.sh` -> Update pause/resume observer hook dispatching.
- [ ] `lib/hook_dispatcher.sh` -> Event alias mapping and pre/post validation.
- [ ] `lib/cmd_hook.sh` -> Update CLI inspection and dry-run testing for pre/post events.
- [ ] `templates/skills/aapp-hooks/registry.tsv` -> Update starter registry template with pre/post naming.
- [ ] `templates/skills/aapp-hooks/SKILL.md` -> Document pre/post hooks.
- [ ] `examples/hooks/on-done-sync.sh` -> Align reference script comments with post-done/on-done.
- [ ] `tests/hooks_test.sh` -> Automated regression tests for pre-mutation aborts and return codes.
- [ ] `MANUAL.md` -> Comprehensive documentation of lifecycle sequencing, pre-mutation gates, and return code semantics.
- [ ] `README.md` -> Update extensibility overview with pre/post lifecycle contract.
- [ ] `CHANGELOG.md` -> Record lifecycle hook sequencing and pre-mutation gate additions.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> File write guard remains focused on tool-call write interception.
- [ ] `templates/aapp-pre-commit` -> Pre-commit hook remains focused on staged git commit validation.
- [ ] `.plans/done/*` -> Historical blueprints remain immutable.

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1 (Clean Break vs Alias Transition):** Should legacy `on-freeze` and `on-start` event names be retained indefinitely as transparent aliases to `pre-freeze` and `pre-start`, or should they emit a deprecation warning and be scheduled for retirement in v2.0.0?
* [ ] **Question 2 (Pre-Done Default Mode):** Should `pre-done` default to `gate` (failing closed if a registered script fails) while `post-done` / `on-done` defaults to `notify`?

---

## 📦 6. Change Log & Refinement History
* **2026-09-19:** Plan initialized to resolve lifecycle hook sequencing and establish pre-mutation quality gates with POSIX return code abort authority.
