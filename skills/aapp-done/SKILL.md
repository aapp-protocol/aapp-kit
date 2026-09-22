---
name: aapp-done
description: Complete lifecycle and archive an implemented blueprint. Moves plan to done/, appends to archive ledger, and cleans active state matrix.
disable-model-invocation: false
argument-hint: "[plan-id or plan-name]"
---

# AAPP Done (Plan Completion & Archival)

Complete the implementation lifecycle and archive a finished blueprint.

## Four-Step Execution Procedure

### Step 1: Resolve Blueprint File (No-Dead-End Invariant)
1. **Resolve Blueprint:**
   - **If `<plan>` is provided:** Resolve `<plan>` using `resolve_plan_path <plan> done current` (or match Plan ID `P-9`, `9`, slug, or filename).
   - **If `<plan>` is omitted (Bare Invocation):**
     - Inspect the active execution buffer: check `$(git rev-parse --git-path aapp_active_plan)`.
     - **Active Buffer Present:** If an active plan is bound in `aapp_active_plan`, ask user for confirmation: *"Active plan in development is P-XX (<slug>). Mark as complete and archive to .plans/done/?"*
     - **Buffer Empty / Multiple in Development:** Scan `.plans/current/*.md` for plans in `⚡ In Development` status. If exactly 1 exists, target it; if multiple, list candidates (max 10, with concise overflow summary line if >10) and ask which plan was completed; if 0, report: *"No plans currently in ⚡ In Development."* Never dead-end with a blank refusal.
2. **Move File & Mark Done:** Move the implemented plan from `.plans/current/` to `.plans/done/`, rewrite its header status to `* **Status:** ✅ Done`, and append an archival entry to `## 📦 6. Change Log`:
```bash
mv ".plans/current/<plan>.md" ".plans/done/<plan>.md"
sed -i -E 's/^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*.*/\* \*\*Status:\*\* ✅ Done/' ".plans/done/<plan>.md"
```

### Step 2: Append to Archival Ledger
Inspect git history to identify the verification or landing commit SHA. Extract the plan's `Plan ID` (e.g. `P-9`). Append a 1-line completion record to `.plans/done/000-archive-ledger.md` using the canonical format:
```markdown
| `YYYY-MM-DD` | `P-X` | [`<plan>.md`](<plan>.md) | Target: `<ISSUE-ID>` | `<commit-sha>` | <1-sentence repo-relative summary> |
```

### Step 3: Relocate Resolved Issue & Prune Roadmap
Edit `.plans/state_matrix.md`, `.plans/ISSUES.md`, and `.plans/issues_road_map.md`:
* Remove the plan entry from `## 🟢 2. Frozen & Ready for Coding (The Greenlight Zone)` (or Incubator).
* If the blueprint resolved a target issue (`Target Issue / Milestone`):
  - **Relocation Invariant**: Move the issue row from `.plans/ISSUES.md` to `.plans/done/000-issues-archive.md`, filling in `Date Resolved`, `Target Commit / Release`, and resolution summary. Do not leave a resolved row in `ISSUES.md`.
  - Prune the issue's line from `.plans/issues_road_map.md`.
* Keep `state_matrix.md`, `ISSUES.md`, and `issues_road_map.md` strictly focused on active, in-flight work.

### Step 4: Record Worktree Commit
Commit the archive transition inside the isolated `plans` worktree:
```bash
git -C .plans add "current/<plan>.md" "done/<plan>.md" done/000-archive-ledger.md done/000-issues-archive.md state_matrix.md issues_road_map.md ISSUES.md
git -C .plans commit -m "plan(done): archive <plan> to done/ and update state matrix"
```

Report completion to the developer with the recorded archive ledger entry.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
