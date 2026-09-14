---
name: aapp-status
description: Act as a Context Recovery agent upon desk return. Scan the four pillars (Shipped, Issues, Plans, Pickup) and report a concise structured briefing.
disable-model-invocation: false
argument-hint: ""
---

# AAPP Status (Context Recovery)

Act as a Context Recovery agent upon desk return. Execute the five-step four-pillar context recovery procedure to orient the developer and determine immediate next actions.

## Execution Method

First, attempt to run `./aapp status` or `aapp status` via shell execution. If the command succeeds, present its output to the user.

If the command is unavailable, fails, or tool execution is restricted, execute the deterministic file-inspection procedure below directly:

## Four-Pillar Inspection Procedure

### 1. Shipped Pillar (Recently Landed / Unreleased)
Inspect `CHANGELOG.md` (or `.plans/CHANGELOG.md` if configured) to identify recently shipped features, fixes, or unreleased changes.

### 2. Issue Lane (Bugs & Backlog)
Inspect `.plans/ISSUES.md` (or root `ISSUES.md`) and `.plans/issues_road_map.md` (the human's fix ordering over open issues). Report the top open issues **strictly in the order the board gives them**. Do not re-sort or filter unless marked resolved.

### 3. Plan Lane (Active Blueprints)
Inspect `.plans/state_matrix.md` for active incubator plans, blocked plans, and greenlit tasks in the Greenlight Zone. Keep this strictly separate from the issue lane in your briefing — never blend the two into one list.

### 4. Pickup Queue (Unprocessed Ideas)
Inspect `.plans/pickup.md` and **list the unprocessed ideas by name, with a count**. These are live and unworked thoughts dumped by the user. Surface them so the user can choose one; do **not** digest them automatically, and do not compress them away into a single vague line.

### 5. Structured Briefing & Next Actions
Print a concise, structured briefing across all **four pillars — Shipped, Issues, Plans, Pickup** — with immediate next actions. **Never omit a pillar**, even when empty (write `Pickup: empty` rather than dropping the section). Where the Pickup queue is non-empty, offer `/aapp-digest <idea>` on a named entry as a recommended next action.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
