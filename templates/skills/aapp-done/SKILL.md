---
name: aapp-done
description: Complete lifecycle and archive an implemented blueprint. Moves plan to done/, appends to archive ledger, and cleans active state matrix.
disable-model-invocation: true
argument-hint: "[plan-name]"
---

# AAPP Done (Plan Completion & Archival)

Complete the implementation lifecycle and archive a finished blueprint.

## Four-Step Execution Procedure

### Step 1: Archive Blueprint File
Move the implemented plan from `.plans/current/` to `.plans/done/`:
```bash
mv ".plans/current/<plan>.md" ".plans/done/<plan>.md"
```

### Step 2: Append to Archival Ledger
Inspect git history to identify the verification or landing commit SHA. Append a 1-line completion record to `.plans/done/000-archive-ledger.md` using the canonical format:
```markdown
- `YYYY-MM-DD` | [`<plan>.md`](<plan>.md) | Target: `<ISSUE-ID>` | Verified: `<commit-sha>` | Impact: <1-sentence repo-relative summary>
```

### Step 3: Prune Active State Matrix & Roadmap
Edit `.plans/state_matrix.md` and `.plans/issues_road_map.md`:
* Remove the plan entry from `## 🟢 2. Frozen & Ready for Coding (The Greenlight Zone)` (or Incubator).
* If the blueprint resolved a target issue (`Target Issue / Milestone`), mark it resolved in `.plans/ISSUES.md` and prune its line from `.plans/issues_road_map.md`.
* Keep `state_matrix.md` and `issues_road_map.md` strictly focused on active, in-flight work.

### Step 4: Record Worktree Commit
Commit the archive transition inside the isolated `plans` worktree:
```bash
git -C .plans add "current/<plan>.md" "done/<plan>.md" done/000-archive-ledger.md state_matrix.md issues_road_map.md ISSUES.md
git -C .plans commit -m "plan(done): archive <plan> to done/ and update state matrix"
```

Report completion to the developer with the recorded archive ledger entry.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
