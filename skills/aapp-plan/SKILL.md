---
name: aapp-plan
description: Canonical blueprint planning and lane routing. Scaffolds durable blueprints in .plans/current/ instead of ephemeral IDE scratchpads.
disable-model-invocation: false
argument-hint: "[idea, feature, or plan-id]"
---

# AAPP Plan (Canonical Blueprint Planning & Lane Router)

Author durable, version-controlled architecture blueprints in `.plans/current/` under Git-level Blast Radius protection.

> ### 📋 Canonical Planning Invariant
> - **Universal Blueprint Standard**: When asked to plan, architect, or scaffold an implementation (via `/plan`, `/aapp-plan`, or in natural language), the agent **MUST NEVER** generate internal IDE scratchpads (such as `implementation_plan.md` in IDE cache directories).
> - **Single Source of Truth**: All implementation plans **MUST** be authored as canonical blueprints in `.plans/current/P<num>-<slug>.md` using `templates/plan-template.md` and registered in `.plans/state_matrix.md`.
> - **Visible Artifact Standard**: Canonical planning always leaves a committed or staged file in `.plans/current/` that is visible in `aapp status`.

---

## Execution Workflow

### Scenario A: Inspecting an Existing Plan (`/aapp-plan P-<num>`)
If the argument matches an existing Plan ID or blueprint slug:
1. Inspect the blueprint in `.plans/current/`.
2. Report status, declared Target Files, and unresolved Open Questions.
3. Advise on next lifecycle action:
   - If `📝 Refining` with resolved questions: run `/aapp-freeze <id>` or `/aapp-freeze-start <id>`.
   - If `🔷 Frozen`: run `aapp start <id>` or `aapp active <id>`.
   - If `⚡ In Development`: report active progress and target boundaries.

### Scenario B: Planning a New Feature or Change (`/aapp-plan <idea>`)
If the argument is an idea, feature description, or instruction:

1. **Step 1: Check Lane Routing (Never Merge Lanes)**:
   - *Defect / Bug in Existing Code*: Record in `.plans/ISSUES.md` (or root `ISSUES.md`) and place on `.plans/issues_road_map.md` first. Only promote to a blueprint if the fix requires architectural changes or multiple modules.
   - *New Capability / Refactor*: Proceed to the Plan lane.

2. **Step 2: Check Existing Blueprints (Amend vs. New)**:
   - Scan `.plans/current/*.md`. If an active blueprint already covers this capability, amend it and log the change in Section 6.

3. **Step 3: Scaffold Canonical Blueprint**:
   - Allocate the next unpadded Plan ID (`get_next_plan_id`).
   - Scaffold `.plans/current/P<num>-<slug>.md` from `templates/plan-template.md`.
   - Complete Technical Blueprint (§2), Implementation Tasks (§3), proposed Blast Radius (§4), and Open Questions (§5).
   - Register in `.plans/state_matrix.md` under `## 🧠 1. Human Thought & Refinement (The Incubator)` with status 🟣 or 📝.

4. **Step 4: Report to User**:
   - Confirm blueprint creation path in `.plans/current/`.
   - Highlight key Open Questions for the user to review.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
