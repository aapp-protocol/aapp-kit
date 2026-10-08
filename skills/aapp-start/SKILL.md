---
name: aapp-start
description: Activate a frozen blueprint into active implementation (⚡ In Development) and bind the local worktree pointer buffer.
disable-model-invocation: false
argument-hint: "[plan-id or plan-name]"
---

# AAPP Start (Activate Execution Context)

Activate an approved, frozen blueprint from the backlog into active implementation (`⚡ In Development`) via the authoritative CLI engine.

Binding sets the local worktree pointer buffer (`.git/aapp_active_plan`), enforcing the declared Blast Radius for all subsequent tool writes and Git commits.

## Execution Procedure

### Step 1: Execute Authoritative CLI Verb
Invoke the deterministic activation verb:
```bash
aapp start [target]
```
*(If `<target>` is omitted, `aapp start` automatically activates the single frozen plan or prompts among candidate frozen plans).*

### Step 2: Deterministic Failure Branch (Fail Closed)
If `aapp start` exits non-zero, **STOP immediately**.
**Do NOT attempt manual buffer file writes, header editing, or raw git commits on the plans worktree.**

Parse and explain the exact CLI diagnostic:
- **Worktree Collision**: If another worktree has already bound or activated the plan, report the collision.
- **Not Frozen**: A plan must be frozen in `🔷 Frozen` (or `🔷 Ready for Execution`) status before it can be started. Run `aapp freeze <plan>` first.
- **Target Files Collision**: If another plan currently in development shares overlapping Target Files, resolve the overlap or finish the in-development plan first.
- **Pending Fix** (`<file> has a pending fix (#<num>)`): a queued 🧱 Plan Blocker is about to change one of the plan's Target Files. Fix it first (`/aapp-fix #<num>`), or start another plan.

### Step 3: Begin Implementation Immediately (Continuous Execution)
On exit 0, `aapp start` has updated the plan status to `⚡ In Development`, recorded the base commit, updated `state_matrix.md`, and bound the local worktree buffer.

**Plan worktree?** With `aapp.planWorktrees = on` (or `worktree <path>`), `aapp start` created the plan's own branch and worktree and bound the plan **there**, printing its path. Continue in that path (`cd <path>`); the primary checkout stays on the development branch, where issue fixes are made. `aapp issue fix` is refused inside a plan worktree.

**Do NOT pause to ask for redundant confirmation.** Immediately proceed to execute Section 3 of the blueprint:
0. **Resuming a plan in a worktree?** Rebase first: `git rebase --autostash <devBranch>`. Fixes to its files may have landed; conflicts in its own lines are its to resolve. Take fixes by rebase only, never by merge (the hook refuses a merge's foreign files); the `post-rewrite` hook keeps the plan's recorded commits right.
1. Verify / author failure tests (confirming Red 🔴) if TDD sections are declared.
2. Begin Phase 1 implementation tasks within the declared `### 📂 Target Files`.
3. **Blocking bug unrelated to your plan's change** (even in one of your own files)? Run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop: it logs and queues the issue and blocks this plan in one commit; the fix runs in the main checkout. A bug inside your Target Files is plan work.
4. Use plan-bound commits (`aapp commit`) to record execution progress. In `aapp.commitMode = atomic` (default) the plan is one commit: after the first, fold changes in with `aapp commit amend`. The first one writes the plan's declared `**Changelog:**` entry into `CHANGELOG.md`; later commits need no changelog edit. Never edit `CHANGELOG.md` by hand for the plan: to change the wording, edit the plan's `**Changelog:**` line and commit it with `aapp refine`.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
