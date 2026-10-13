---
name: aapp
description: Start a session. Read the project's full rules, run the status briefing, and report ready for work.
disable-model-invocation: false
argument-hint: ""
---

# AAPP (Session Start)

The rules file an agent is given at session start may be cut short. This skill loads the rules in full and orients the session. Run it first in every session, and again after the conversation was summarised.

## Execution Procedure

### Step 1: Read the rules in full
Open `.agents/AGENTS.md` with your file tool and read it to its last line; read it in parts if your tool limits one read. The path is relative to the repository root.

### Step 2: Run the status briefing
```bash
aapp status
```

### Step 3: Report
Report what `aapp status` printed, pillar by pillar and item by item: what shipped, the open issues, the plans, and the pickup queue. Keep every field of every item (a plan's id, name and status; an issue's id and symptom): do not drop, abbreviate, merge or reorder them. Your own remarks and suggested next actions come after the report, not in place of it. Then wait for the user's direction.

## During the session
- Before using a verb for the first time in a session, run `aapp help <verb>`: it prints the verb's arguments. `aapp help <verb> full` adds its refusals and effects.
- Read `.agents/PROJECT.MD` and `.agents/CODEMAP.md` when the task touches the code they describe.
- A workflow that has a skill is run by following that skill's file, `.agents/skills/<name>/SKILL.md`.

### Fail Closed
If `aapp status` exits non-zero, **STOP** and explain its diagnostic.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
