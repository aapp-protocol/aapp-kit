---
name: aapp-freeze
description: Lock and greenlight a blueprint for code execution. Verifies open questions, marks blast radius locked, and moves plan to Greenlight Zone.
disable-model-invocation: false
argument-hint: "[plan-id or plan-name]"
---

# AAPP Freeze (Greenlight & Blast Radius Lock)

Lock and greenlight an incubator blueprint for code execution. Freezing transitions a plan from human design into active implementation.

## Three-Step Execution Procedure

### Step 1: Resolve & Verify Blueprint Readiness (No-Dead-End Invariant)
1. **Resolve Blueprint:**
   - **If `<plan>` is provided:** Resolve `<plan>` using `resolve_plan_path <plan> freeze current` (or match Plan ID `P-9`, `9`, slug, or filename).
   - **If `<plan>` is omitted (Bare Invocation):**
     - Scan `.plans/current/*.md` and `.plans/state_matrix.md` for incubator blueprints in `🟣 Under Review` or `📝 Refining` status.
     - **Incubator Plans Found:** Present candidate blueprints (max 10, with concise overflow summary line if >10) and ask: *"Which incubator blueprint would you like to review and freeze?"*
     - **Zero Incubator Plans:** Report: *"No incubator drafts found in .plans/current/. Use /aapp-plan to draft a new blueprint."* Never dead-end with a blank refusal.
2. **Scan Blueprint:** In `.plans/current/<plan>.md`:
1. **Open Questions:** Verify that all entries in `## ❓ 5. Open Questions` are checked off and marked resolved (`[x]`). A plan with unresolved questions cannot be frozen.
2. **Blast Radius:** Verify that `### 📂 Target Files` and `### 🛑 Out of Bounds` are explicitly declared, with one canonical backticked file path per line.
3. **Status Line:** Update the status in the plan header to `* **Status:** 🔷 Frozen` (or `🔷 Ready for Execution`).
4. **Lock Marker:** Change `*(Marked: **PROPOSED** — incubator draft)*` to `*(Marked: **LOCKED** — Greenlit for implementation)*`.
5. **Change Log:** Append a dated entry to `## 📦 6. Change Log & Refinement History` noting that the plan was frozen and greenlit for the backlog.

### Step 2: Update State Matrix
1. Edit `.plans/state_matrix.md`:
   - Move the plan entry from `## 🧠 1. Human Thought & Refinement (The Incubator)` into `## 🔷 2. Frozen Backlog (Approved Specifications)`.
   - Update its status indicator to 🔷.
2. Commit the transition to the `plans` worktree:
   ```bash
   git -C .plans add "current/<plan>.md" state_matrix.md
   git -C .plans commit -m "plan(freeze): lock blast radius and greenlight <plan>"
   ```

### Step 3: Backlog Placement & Execution Activation
Inform the developer that the specification is frozen in the backlog:
- The technical blueprint and blast radius are design-locked against tampering.
- To activate execution in the working tree, run `/aapp-start <plan>` (or CLI: `aapp start <plan>`).
- To freeze and immediately begin coding in one command, use CLI: `aapp freeze-start <plan>`.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
