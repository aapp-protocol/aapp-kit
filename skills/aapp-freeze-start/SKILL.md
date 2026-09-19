---
name: aapp-freeze-start
description: Atomically freeze an incubator blueprint, lock its blast radius, transition to ⚡ In Development, and bind worktree execution context.
disable-model-invocation: true
argument-hint: "<plan-id or plan-name>"
---

# AAPP Freeze-Start (Atomic Workflow Accelerator)

Atomically greenlight an incubator blueprint and activate it for immediate execution in a single command. Verifies open questions, locks the technical blueprint and blast radius, verifies the Disjointness Activation Gate, transitions status directly to `⚡ In Development`, and binds the local worktree buffer.

## Execution Procedure

### Step 1: Resolve & Verify Blueprint
1. **Resolve Blueprint:** Resolve `<plan>` using `resolve_plan_path <plan> freeze-start current`. Bare command without target is strictly refused.
2. **Scan Blueprint:**
   - **Open Questions:** Verify all items in `## ❓ 5. Open Questions` are checked off (`[x]`).
   - **Target Files:** Verify `### 📂 Target Files` has explicit declarations.
3. **Disjointness Activation Gate:** Ensure no currently in-flight (`⚡ In Development`) blueprint shares overlapping Target Files.

### Step 2: Atomic State Transition & Lock
1. Update blueprint header:
   ```markdown
   * **Status:** ⚡ In Development
   ```
2. Set lock marker:
   `*(Marked: **LOCKED** — Greenlit for implementation)*`
3. Append dated entry to `## 📦 6. Change Log & Refinement History` noting that the plan was frozen and activated into development.
4. Bind the worktree pointer buffer:
   ```bash
   ACTIVE_BUFFER="$(git rev-parse --git-path aapp_active_plan)"
   echo "<plan-id>" > "$ACTIVE_BUFFER"
   ```
5. Update `.plans/state_matrix.md` with status `⚡`.
6. Commit to the `plans` worktree:
   ```bash
   git -C .plans add "current/<plan>.md" state_matrix.md
   git -C .plans commit -m "plan(start): freeze and activate <plan> into development"
   ```

### Step 3: Immediate Execution
- The Blast Radius is locked and actively enforced.
- Proceed immediately with code changes in `### 📂 Target Files`.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
