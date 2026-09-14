---
name: aapp-digest
description: Take one idea or issue and work it toward a blueprint in the Incubator. Scaffolds a new plan or amends an existing plan.
disable-model-invocation: false
argument-hint: "[idea or ISSUE-ID]"
---

# AAPP Digest (Idea / Issue Routing & Blueprint Scaffolding)

Take **one** idea or issue and work it toward an architectural plan. This is a targeted, single-item operation — never a bulk sweep of `pickup.md`.

## Six-Step Execution Procedure

### Step 1: Resolve the Idea
The argument `<idea>` may be raw text typed inline, a reference to an entry in `.plans/pickup.md`, or a file in `.plans/pickup/`.
* If `<idea>` is omitted, read the open entries in `.plans/pickup.md` and **ask the user which one to digest**.
* Never choose automatically for the user, and never process multiple items at once.

### Step 2: Route to a Lane
Determine whether the item describes a defect or a new capability:
* **Issue Lane:** If it describes wrong behavior or a bug in code that already ships, record it in `.plans/ISSUES.md` (or root `ISSUES.md`) and place it on `.plans/issues_road_map.md` first — always. Then judge the size of the fix:
  - *Small / obvious fix* → stop there. The issue record is sufficient; do not scaffold a blueprint.
  - *Large fix* (spans several modules, requires locked Blast Radius, has design trade-offs) → promote to a plan and proceed to Step 3.
* **`<idea>` is an ISSUE ID (e.g. `ISSUE-004`):** The user has chosen promotion. Carry the issue ID into the plan header and proceed to Step 3.
* **Plan Lane (New Capability / Refactor):** Proceed directly to Step 3.

### Step 3: Decide NEW or AMEND
Scan `.plans/current/*.md` before drafting:
* **AMEND:** An active blueprint already covers or closely relates to this capability.
* **NEW:** No active blueprint covers it.
* *Ambiguity:* If the match is ambiguous, ask the user. Never silently merge an idea into an unrelated blueprint.

### Step 4a: NEW Plan (From Scratch)
1. Cross-reference `.agents/CODEMAP.md` (or `CODEMAP.md`) and `ARCHITECTURE.md` to ensure the design extends existing modules rather than adding duplicate helpers.
2. Scaffold `.plans/current/<feature-name>.md` from `.plans/plan-template.md`.
3. Fill in *Context & Architectural Goal*, *Technical Blueprint*, and *Implementation Steps & Execution Checklist*.
4. Propose a Blast Radius (`### 📂 Target Files` and `### 🛑 Out of Bounds`). Mark it **PROPOSED** — it is not locked and confers no code execution rights.
5. Record every unresolved technical decision in `## ❓ 5. Open Questions`.
6. Register the plan in `.plans/state_matrix.md` under `## 🧠 1. Human Thought & Refinement (The Incubator)` with status 🔴.

### Step 4b: AMEND Existing Plan
1. Fold the new requirements into the appropriate sections (*Technical Blueprint*, *Implementation Steps*, *Open Questions*, or *Blast Radius*).
2. Append a dated entry to `## 📦 6. Change Log & Refinement History` detailing what changed and why.
3. *If the plan was already frozen:* Changing its Blast Radius invalidates execution safety. Stop, obtain explicit human approval, and move the plan back to the Incubator in `state_matrix.md` until re-frozen.
4. Update status in `.plans/state_matrix.md` if necessary.

### Step 5: Clean Up Pickup Queue
If `<idea>` originated from `.plans/pickup.md`, remove **only** the digested entry from `pickup.md`. Leave every other entry in place.

### Step 6: Report & Next Actions
State plainly which path was taken (NEW, AMEND, or routed to `ISSUES.md`). Name the file written or modified, and explicitly list the Open Questions the user must review next.

> **Note:** `digest` produces an incubator draft, never an executable green light. Only `/aapp-freeze` makes a plan executable.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
