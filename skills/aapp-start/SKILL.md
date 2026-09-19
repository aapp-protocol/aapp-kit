---
name: aapp-start
description: Activate a frozen blueprint into active implementation (⚡ In Development) and bind the local worktree pointer buffer.
disable-model-invocation: true
argument-hint: "<plan-id or plan-name>"
---

# AAPP Start (Activate Execution Context)

Activate an approved, frozen blueprint from the backlog into active implementation (`⚡ In Development`). Sets the local worktree pointer buffer (`$(git rev-parse --git-path aapp_active_plan)`), enforcing the declared Blast Radius for all subsequent tool writes and Git commits.

## Three-Step Execution Procedure

### Step 1: Disjointness Check & Activation
1. **Resolve Blueprint:** Resolve `<plan>` using `resolve_plan_path <plan> start current` (or Plan ID / slug).
2. **Verify Status:** Verify that the blueprint is in `🔷 Frozen` (or `🔷 Ready for Execution`) status.
3. **Disjointness Activation Gate:** Ensure no other plan currently in `⚡ In Development` in the same workspace shares overlapping Target Files.
4. **Transition Header:** Update plan header:
   ```markdown
   * **Status:** ⚡ In Development
   ```
5. **Change Log:** Append a dated entry to `## 📦 6. Change Log & Refinement History` noting that implementation has started.

### Step 2: Bind Worktree Execution Context
1. Point the authoritative filesystem pointer buffer to the active plan:
   ```bash
   ACTIVE_BUFFER="$(git rev-parse --git-path aapp_active_plan)"
   echo "<plan-id>" > "$ACTIVE_BUFFER"
   ```
2. Update `.plans/state_matrix.md`:
   - Move or mark the plan with status indicator `⚡`.
3. Commit transition to the `plans` worktree:
   ```bash
   git -C .plans add "current/<plan>.md" state_matrix.md
   git -C .plans commit -m "plan(start): activate <plan> into development"
   ```

### Step 3: Begin Implementation
- The write-guard and pre-commit hooks now actively enforce the plan's locked Blast Radius.
- Proceed to implement tasks in Section 3 of the blueprint.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
