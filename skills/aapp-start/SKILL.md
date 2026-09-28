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

### Step 3: Success Confirmation
On exit 0, `aapp start` has updated the plan status to `⚡ In Development`, recorded the base commit, updated `state_matrix.md`, and bound the local worktree buffer.

Confirm active binding to the user and notify them that:
1. Tool writes and Git commits are now strictly constrained to the declared `### 📂 Target Files`.
2. Implementation begins with failure-first tests (confirming Red 🔴) followed by production code and plan-bound commits (`aapp commit`).

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
