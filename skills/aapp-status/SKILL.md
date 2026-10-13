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
Show the user the output of `aapp status` as it was printed, in a code block: every line, in its order. Do not summarise, shorten, reword, merge or drop anything, and do not replace items with a count ("and 5 more"). The command's output is the briefing; the user may not see it unless you show it. Your own remarks come after it, in a few lines, not in place of it. The output covers the **four pillars**:
1. **Shipped Pillar**: Recently landed features, bugfixes, or unreleased changes from `CHANGELOG.md`.
2. **Issue Lane**: Active bugs and backlog items from `ISSUES.md` strictly in the priority order established by `issues_road_map.md`. The briefing shows the top 5; `aapp issue list` (or `aapp issue list all`) prints the rest in the same order.
3. **Plan Lane**: Active blueprints in development, frozen specifications, or incubator drafts from `state_matrix.md`.
4. **Pickup Queue**: Unprocessed ideas and raw notes from `pickup.md`. List ideas with a count; never omit this pillar.

Where the Pickup queue is non-empty, recommend `/aapp-digest <idea>` as the immediate Next Action.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
