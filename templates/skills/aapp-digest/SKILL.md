---
name: aapp-digest
description: Take one idea or issue and work it toward a blueprint in the Incubator. Scaffolds a new plan or amends an existing plan.
disable-model-invocation: false
argument-hint: "[idea or ISSUE-ID]"
---

# AAPP Digest (Idea / Issue Routing & Blueprint Scaffolding)

Take **one** idea or issue and work it toward an architectural plan. This is a targeted, single-item operation — never a bulk sweep of `pickup.md`.

## Six-Step Execution Procedure

### Step 1: Resolve the Idea (No-Dead-End Invariant)
The argument `<idea>` may be raw text typed inline, a reference to an entry in `.plans/pickup.md`, or an issue identifier (e.g. `#74` or `ISSUE-74`).
* **If `<idea>` is provided:** Proceed immediately to Step 2.
* **If `<idea>` is omitted (Bare Invocation):**
  1. **Check Pickup Queue (`.plans/pickup.md`):** If open unworked ideas exist, present up to 10 entries (with a concise overflow summary line if more exist) and ask the user which one to digest.
  2. **Fallback to Issues Backlog (`.plans/ISSUES.md`):** If `pickup.md` is empty, inspect `.plans/ISSUES.md` (respecting the priority ordering in `issues_road_map.md`). Display the top open issues (max 10, with overflow summary) and ask: *"The pickup queue is empty. Would you like to promote one of these open issues to a blueprint?"*
  3. **Fallback to Inline Prompt:** If both pickup and open issues are empty, prompt: *"No ideas or open issues queued. What feature, bugfix, or architectural refactor would you like to plan?"*
* **Display Ceiling:** Render at most 10 candidates (never more than 15) to preserve context.
* Never choose automatically for the user, and never process multiple items at once.

### Step 2: Route to a Lane
Determine whether the item describes a defect or a new capability:
* **Issue Lane:** If it describes wrong behavior or a bug in code that already ships, claim its ID with `aapp issue allocate` (never derive an ID from the files), record the row in `.plans/ISSUES.md` (or root `ISSUES.md`) and place it on `.plans/issues_road_map.md` first — always — then commit both with `aapp refine issues "log #<num> <title>"` (it validates the ledgers and names any line to fix). Then judge the size of the fix:
  - *Small / obvious fix* → stop there. The issue record is sufficient; do not scaffold a blueprint. Make the fix through `aapp issue fix <num> file <path>…` (a temporary mini plan that confines and records it; one fix at a time, so run it with a tool timeout longer than `aapp.issueFixWait`), commit with `aapp commit`, then close with `aapp issue close <num>` (bare number); never move table rows by hand.
  - *Large fix* (spans several modules, requires locked Blast Radius, has design trade-offs) → promote to a plan and proceed to Step 3.
* **`<idea>` is an ISSUE ID (e.g. `ISSUE-004`):** The user has chosen promotion. Proceed to Step 3 and scaffold with `aapp draft <slug> issue <num>` (Step 4a), which links the plan and the issue.
* **Plan Lane (New Capability / Refactor):** Proceed directly to Step 3.

### Step 3: Decide NEW or AMEND
Scan `.plans/current/*.md` before drafting:
* **AMEND:** An active blueprint already covers or closely relates to this capability.
* **NEW:** No active blueprint covers it.
* *Ambiguity:* If the match is ambiguous, ask the user. Never silently merge an idea into an unrelated blueprint.

### Step 4a: NEW Plan (Authoritative CLI Scaffolding)
1. Scaffold the canonical incubator blueprint via the authoritative CLI engine:
   ```bash
   aapp draft <slug>                # an idea
   aapp draft <slug> issue <num>    # promoting issue #<num> (bare number)
   ```
   With `issue <num>`, the same commit puts `#<num>` in the plan's Target Issue field, links the plan in the issue row and marks it 🔵 `Planned`; never edit those cells by hand. `aapp draft` deterministically allocates the next Plan ID from the sequence counter, generates `.plans/current/P<num>-<slug>.md` from `templates/plan-template.md`, registers the plan in `.plans/state_matrix.md`, and commits the addition cleanly.
2. Cross-reference `.agents/CODEMAP.md` and `ARCHITECTURE.md` to ensure the design extends existing modules rather than adding duplicate helpers.
3. Open and author `.plans/current/P<num>-<slug>.md`:
   - Detail *Context & Architectural Goal* and *Technical Blueprint*.
   - Detail *Implementation Steps & Execution Checklist*.
   - Propose a Blast Radius (`### 📂 Target Files` and `### 🛑 Out of Bounds`). Mark it **PROPOSED** — it is not locked and confers no code execution rights. Never place files matching Guard Section 2 self-protection in Target Files (enforced by Pair 5).
   - Record every unresolved technical decision in `## ❓ 5. Open Questions`.
   - Reword the header's `* **Changelog:**` line (pre-filled from the title) into the plan's single release note and pick its section: `Added:`, `Changed:` or `Fixed:`. `aapp commit` writes it into `CHANGELOG.md`; never edit `CHANGELOG.md` by hand for a plan.
4. Commit the authored content (never raw git on the plans worktree):
   ```bash
   aapp refine P-<num> "author context and blueprint"
   ```

### Step 4b: AMEND Existing Plan
1. Fold the new requirements into the appropriate sections (*Technical Blueprint*, *Implementation Steps*, *Open Questions*, or *Blast Radius*).
2. Append a dated entry to `## 📦 6. Change Log & Refinement History` detailing what changed and why.
3. *If the plan was already frozen:* Changing its design or Blast Radius invalidates execution safety. Stop and obtain explicit human approval. Then set its Status to `📝 Refining` with §2/§4 untouched and commit that alone (`aapp refine <plan-id> "back to Refining for <reason>"`), make the change, and re-freeze. The state matrix re-derives itself.
4. Commit the refinement (never raw git on the plans worktree):
   ```bash
   aapp refine <plan-id> "amend with <idea>"
   ```

### Step 5: Clean Up Pickup Queue
If `<idea>` originated from `.plans/pickup.md`, remove **only** the digested entry from `pickup.md`. Leave every other entry in place. Commit the removal with `aapp refine pickup "digest <slug>"` (never raw git on the plans worktree).

### Step 6: Report & Next Actions
State plainly which path was taken (NEW, AMEND, or routed to `ISSUES.md`). Name the file written or modified, and explicitly list the Open Questions the user must review next.

> **Note:** `digest` produces an incubator draft, never an executable green light. Only `aapp freeze` locks the design and makes a plan executable.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
