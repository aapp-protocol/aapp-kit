---
name: aapp-status
description: Act as a Context Recovery agent upon desk return. Scan the four pillars (Shipped, Issues, Plans, Pickup) and report a concise structured briefing.
disable-model-invocation: false
argument-hint: ""
---

# AAPP Status (Context Recovery)

Act as a Context Recovery agent upon desk return. Execute the authoritative CLI recovery briefing across the four pillars (Shipped, Issues, Plans, Pickup) to orient the developer and determine immediate next actions.

## Execution Procedure

### Step 1: Execute Authoritative CLI Verb
Invoke the deterministic status verb:
```bash
aapp status
```
*(For a single-line pulse check, use `aapp status short`).*

### Step 2: Diagnostic Handling
If `aapp status` exits non-zero, report any repository corruption or missing toolchain configuration to the user.

### Step 3: Present Context Recovery Briefing
Present the structured briefing across the **four pillars**:
1. **Shipped Pillar**: Recently landed features, bugfixes, or unreleased changes from `CHANGELOG.md`.
2. **Issue Lane**: Active bugs and backlog items from `ISSUES.md` strictly in the priority order established by `issues_road_map.md`.
3. **Plan Lane**: Active blueprints in development, frozen specifications, or incubator drafts from `state_matrix.md`.
4. **Pickup Queue**: Unprocessed ideas and raw notes from `pickup.md`. List ideas with a count; never omit this pillar.

Where the Pickup queue is non-empty, recommend `/aapp-digest <idea>` as the immediate Next Action.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
