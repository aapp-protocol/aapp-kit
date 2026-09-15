---
name: aapp-freeze
description: Lock and greenlight a blueprint for code execution. Verifies open questions, marks blast radius locked, and moves plan to Greenlight Zone.
disable-model-invocation: true
argument-hint: "<plan-id or plan-name>"
---

# AAPP Freeze (Greenlight & Blast Radius Lock)

Lock and greenlight an incubator blueprint for code execution. Freezing transitions a plan from human design into active implementation.

## Three-Step Execution Procedure

### Step 1: Resolve & Verify Blueprint Readiness
1. **Resolve Blueprint:** Resolve `<plan>` using `resolve_plan_path <plan> freeze current` (or match Plan ID `P-9`, `9`, slug, or filename). The target plan must be explicitly specified — bare `/aapp-freeze` without arguments is strictly refused.
2. **Scan Blueprint:** In `.plans/current/<plan>.md`:
1. **Open Questions:** Verify that all entries in `## ❓ 5. Open Questions` are checked off and marked resolved (`[x]`). A plan with unresolved questions cannot be frozen.
2. **Blast Radius:** Verify that `### 📂 Target Files` and `### 🛑 Out of Bounds` are explicitly declared, with one canonical backticked file path per line.
3. **Status Line:** Update the status in the plan header to `* **Status:** 🟢 Ready for Execution`.
4. **Lock Marker:** Change `*(Marked: **PROPOSED** — incubator draft)*` to `*(Marked: **LOCKED** — greenlit for execution)*`.
5. **Change Log:** Append a dated entry to `## 📦 6. Change Log & Refinement History` noting that the plan was frozen and greenlit.

### Step 2: Update State Matrix
1. Edit `.plans/state_matrix.md`:
   - Move the plan entry from `## 🧠 1. Human Thought & Refinement (The Incubator)` into `## 🟢 2. Frozen & Ready for Coding (The Greenlight Zone)`.
   - Update its status indicator to 🟢.
2. Commit the transition to the `plans` worktree:
   ```bash
   git -C .plans add "current/<plan>.md" state_matrix.md
   git -C .plans commit -m "plan(freeze): lock blast radius and greenlight <plan>"
   ```

### Step 3: Seal the Boundary
Inform the developer that the plan is now active in the Greenlight Zone:
- The pre-commit hook and write-guard now enforce the locked Blast Radius on code changes.
- The coding agent is authorized to implement the tasks defined in the execution checklist, modifying only files declared in `### 📂 Target Files`.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
