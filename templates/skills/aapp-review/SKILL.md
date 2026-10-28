---
name: aapp-review
description: Review a plan. In design, through its RFC; in development, through signed findings the implementer answers with fixes before done.
disable-model-invocation: false
argument-hint: "[plan-id or topic-slug]"
---

# AAPP Review

Review one plan, or a topic that has no plan yet. The plan's Status decides the kind of review; the `aapp review` verb enforces it.

## Execution Procedure

### Step 1: Read the Status
1. Run `aapp help review` once, then `aapp plan-status <id>` and read the plan's Status.
2. **No plan yet** (a topic or a pickup idea): go to Step 2 with its slug.
3. **🟣 Under Review or 📝 Refining:** a design review (Step 2).
4. **⚡ In Development:** an implementation review (Step 3).
5. **🔷 Frozen, 🟥 BLOCKED, ✅ Done:** stop; tell the user the plan is not open to review in that Status.

### Step 2: Design review (the plan's RFC)
1. Create the RFC once: `aapp review draft <id>` (or `aapp review draft <slug>` for a topic). It is a local file in `.plans/pickup/`, never committed. If it exists, open it instead.
2. Read the plan, then check every claim it makes against the code: the files, functions and behaviour it relies on.
3. Fill §2 with the current state you checked, and append one signed block to §3: `### <date> — <agent> (<vendor>, <model>) — <subject>`, each finding checked against the code. Never edit another block.
4. Never write §4: decisions are the user's, recorded from their own words.
5. Report the findings to the user in chat, short, as options to refine the plan, keeping its defaults. The plan changes only when the user agrees, through its usual commit.

### Step 3: Implementation review (findings and fixes)
1. Read the plan's §2 (design) and §4 (Target Files), then the code it changed (`aapp plan-status <id>` lists the commits).
2. For each defect, flag one finding, from any checkout:
   ```bash
   aapp review flag <id> "<what is wrong, where, why>" [file <path>]
   ```
   Name the `file` the finding is about. A file outside the plan's Target Files is marked as needing an amendment: **never open the amendment request yourself**; the implementer does.
3. Do not fix anything: the implementer answers each finding from the plan's own checkout:
   - `aapp review fix <id> F<n> "<task>"`: a task in §8 (name its amendment request as `(R<n>)` when the file is outside the targets);
   - `aapp review fix done <id> F<n>`: the task done;
   - `aapp review fix decline <id> F<n> "<reason>"`: declined, with the reason.
4. `aapp review check <id>` lists what is still open (exit 1); a `pre-done` gate that runs it refuses `done` until every finding is answered.
5. Report the findings flagged to the user.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
