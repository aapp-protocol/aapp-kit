---
name: aapp-pause
description: Engage the project emergency brake, quarantine in-flight work per-worktree into stashes, inspect pause state, or resume normal velocity.
disable-model-invocation: true
argument-hint: "[resume | inspect | <reason>]"
---

# AAPP Pause & Resume (Project Circuit Breaker)

Engage or disengage the Master Emergency Brake & Multi-Worktree State Preserver ("Hibernate & Wake"). Quarantines in-flight uncommitted code per-worktree into SHA-addressed Git stashes, prevents accidental cross-window or cross-project code modifications, and enables safe resumption with drift forensics.

## Commands & Usage

| Action | Command / Usage | Purpose |
| :--- | :--- | :--- |
| **Engage Brake (Repo-Wide)** | `/aapp-pause [reason]` (or `aapp pause [reason]`) | Quarantines uncommitted code per-worktree into SHA-addressed stashes (`aapp-pause-<timestamp>:<branch>`) and locks codebase modifications. |
| **Engage Brake (Team-Wide)** | `/aapp-pause --shared [reason]` (or `aapp pause --shared [reason]`) | Freezes repo and commits pause marker to `.plans/PAUSED.md` for team-wide synchronization across clones. |
| **Inspect Pause State** | `/aapp-pause` (or `aapp pause` when paused) | Display active pause reason, duration, quarantined stashes, and snapshot details without modifying state. |
| **Disengage Brake (Resume)** | `/aapp-pause resume` (or `aapp resume`) | Detects commit drift, restores stashes by commit SHA, runs planning health checks, and clears pause buffer. |

## Invariants & Guarantees

1. **Dynamic Multi-Worktree Discovery**: Discovers all mounted worktrees via `git worktree list --porcelain` and quarantees changes across all of them atomically.
2. **In-Flight Operation Guard**: Pre-checks for active merges, rebases, or cherry-picks (`MERGE_HEAD`, `rebase-merge`, `CHERRY_PICK_HEAD`) and refuses to pause if a conflict is unresolved.
3. **Atomic Rollback**: Asserts valid 40-character commit SHAs for every stash created; rolls back all stashes if any worktree fails.
4. **Air-Gap Safety**: Stashing strictly uses `--include-untracked` and forbids `--all`, preserving `.gitignore` boundaries and protecting air-gapped stores (e.g. private notes in `.plans/pickup/`).
5. **No-Loss Conflict Guarantee & Buffer Survival**: On `resume`, if a stash apply encounters a conflict, the stash entry is permanently preserved in `git stash list` and the pause buffer remains active on disk until manually resolved.
6. **Permitted Cognitive Functions**: While paused, reading code, capturing ideas in `.plans/pickup*`, logging defects in `.plans/ISSUES.md` (and `issues_road_map.md`), and drafting blueprints in `.plans/current/` remain 100% operational. Modifications to the codebase, the `.agents/` control plane, templates, and hooks are strictly blocked.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
