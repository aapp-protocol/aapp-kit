---
title: Lifecycle State Machine & Execution Transitions
description: Complete specification of blueprint status taxonomy, state machine transitions, failure branches, and lifecycle commands.
---

# 🔄 Lifecycle State Machine & Execution Transitions

AAPP blueprints progress through a deterministic, version-controlled state machine designed to eliminate agent drift, hallucinated scope, and silent codebase corruption.

---

## 1. The Lifecycle Pipeline

```text
  ┌────────────┐        ┌─────────────┐        ┌──────────────┐        ┌───────────┐
  │  Idea /    │ /digest│  Incubator  │ /freeze│  Greenlight  │ /done  │  Archive  │
  │  pickup.md ├───────►│ 🟣 Under    ├───────►│  🔷 Ready    ├───────►│  .plans/  │
  │            │        │    Review   │        │  (Execution) │        │  done/    │
  └────────────┘        └─────────────┘        └──────────────┘        └───────────┘
                               │                      │
                        /pause │               /abort │
                               ▼                      ▼
                        ┌─────────────┐        ┌──────────────┐
                        │ ⏸️ Paused    │        │ ❌ Aborted   │
                        └─────────────┘        └──────────────┘
```

---

## 2. Status Taxonomy

Every blueprint in `.plans/current/` records its exact lifecycle state in its header (`* **Status:** <badge>`). The status badge is the authoritative single source of truth; `.plans/state_matrix.md` is derived from it via `aapp matrix`.

| Status Badge | Phase | Allowed Operations | Blast Radius |
| :--- | :--- | :--- | :--- |
| `🟣 Under Review` | Incubator (Draft) | Collaborative refinement, open questions, schema authoring | Unlocked (`OPEN`) |
| `📝 Refining` | Incubator (Active) | Iterative drafting, section additions, TDD declarations | Unlocked (`OPEN`) |
| `🔷 Ready for Execution` | Backlog (Frozen) | Task checkbox updates (`[ ]` → `[x]`), status transitions | **LOCKED** (Design & files immutable) |
| `🔷 Frozen` | Backlog (Frozen) | Alias for Ready for Execution | **LOCKED** |
| `⚡ In Development` | Active Implementation | Task checklist ticks, git commits within target files | **LOCKED** (Pre-commit enforced) |
| `⏸️ Paused` | Emergency Brake / Pause | Inspection, unpause, status transition | **LOCKED** |
| `🟥 BLOCKED` | Blocked on Issue / Dep | Issue resolution, unblocking via `aapp refine` | **LOCKED** (Zero tool writes allowed) |
| `❌ Aborted` | Abandoned | Read-only historical audit in `.plans/aborted/` | Sealed |
| `✅ Done` | Archived Milestone | Read-only historical audit in `.plans/done/` or `release/` | Sealed |

---

## 3. Transition Rules & Preconditions

### 3.1 Scaffolding (`/aapp-digest` or `aapp draft`)
- **Source**: Idea in `.plans/pickup.md`, issue in `.plans/ISSUES.md`, or raw user prompt.
- **Target**: `🟣 Under Review` in `.plans/current/P<num>-<slug>.md`.
- **Preconditions**:
  - Valid alphanumeric slug (`^[a-z0-9-]+$`).
  - Next monotonic Plan ID allocated via `allocate_plan_id`.
  - Stamped with ISO 8601 date, target issue (if promoted), and default modes.
- **Commit**: Automatic atomic commit to `.plans` worktree (`plan(draft): scaffold <slug>`).

### 3.2 Freezing (`/aapp-freeze` or `aapp freeze`)
- **Source**: `🟣 Under Review` or `📝 Refining`.
- **Target**: `🔷 Ready for Execution`.
- **Preconditions**:
  - All items under `## 5. Open Questions` must be answered or marked resolved.
  - Section `## 2. Technical Blueprint` must be populated.
  - Section `### 📂 Target Files` must declare explicit, repository-relative file paths.
  - Pair 5 Self-Protection Gate: Target files must NOT touch `.githooks/*`, `.agents/skills/aapp-*`, `.claude/settings*`, or `.cursor/rules/*`.
  - Mode records (`* **Commit Mode:**` and `* **Changelog Mode:**`) and `* **Changelog:**` line must be valid.
- **Design Lock**: Once frozen, Section 2 (Technical Blueprint) and Section 4 (Blast Radius) become strictly immutable. Pre-commit hooks reject any commit modifying these sections unless explicitly unfrozen first.

### 3.3 Activation (`/aapp-start` or `aapp start`)
- **Source**: `🔷 Ready for Execution`.
- **Target**: `⚡ In Development`.
- **Preconditions**:
  - Blueprint must be frozen.
  - Disjointness Gate: Declared target files must not overlap with another plan currently marked `⚡ In Development` (except registered shared documentation files).
  - Active Plan Buffer: Binds the local execution buffer (`.git/aapp_active_plan`).

### 3.4 In-Flight Refinement (`aapp refine`)
- **Scope**: Modifying plan contents during development without raw git operations.
- **Rules**:
  - Governed by checkout ownership: a plan in development is refined only from its dedicated worktree or bound checkout.
  - Commit subject must conform to `aapp.subjectMaxLen` (default 72 characters).
  - Pre-commit design lock continues to protect §2 and §4 for frozen plans.

### 3.5 Archival (`/aapp-done` or `aapp done`)
- **Source**: `⚡ In Development`.
- **Target**: Relocated to `.plans/done/` and recorded in `.plans/done/000-archive-ledger.md`.
- **Preconditions**:
  - At least one valid commit SHA must be recorded in `* **Commits:**` header.
  - Recorded commits must be reachable from git references.
  - All TDD failure assertions (if declared) must be completed (`[x]`).
  - Pre-done hook dispatch must exit 0.
- **Mutations**:
  - Moves blueprint file to `.plans/done/`.
  - Appends 1-line completion record to archive ledger.
  - Prunes row from `.plans/state_matrix.md`.
  - Relocates resolved target issues from `ISSUES.md` to `000-issues-archive.md`.
  - Dispatches `post-done` lifecycle event.

### 3.6 Abandonment (`aapp plan abort`)
- **Source**: Any active blueprint in `.plans/current/`.
- **Target**: Relocated to `.plans/aborted/` as `❌ Aborted`.
- **Preconditions**:
  - Run from main checkout.
  - Worktree must be clean (or passed with `force`).
- **Mutations**:
  - Records reason in `.plans/aborted/000-aborted-ledger.md`.
  - Restores Target Issue back to `🟡 Incubated` in `ISSUES.md`.
  - Deletes plan worktree and branch (unless `keep-branch` specified).

---

## 4. Repository Onboarding (The Day 1 Loop)

When adopting AAPP in an existing codebase, onboarding is executed as a **real AAPP blueprint** under a locked Blast Radius:

1. **Initial Seed**: Running `aapp init` pre-seeds `.plans/pickup.md` with:
   ```markdown
   - [ ] Onboarding: Inspect repository codebase to populate .agents/CODEMAP.md, ARCHITECTURE.md, and .agents/PROJECT.MD
   ```
2. **Context Discovery**: Opening your AI assistant and running `/aapp-status` reports the queued `Onboarding` item in Pillar 4 (Pickup).
3. **Blueprint Scaffolding**: Running `/aapp-digest Onboarding` drafts a blueprint whose Target Files are strictly confined to `.agents/CODEMAP.md`, `ARCHITECTURE.md`, and `.agents/PROJECT.MD`.
4. **Execution & Self-Cleanup**: Running `/aapp-freeze-start <plan>` greenlights the agent to inspect the codebase and replace generic template placeholders with real project context.
5. **Archival**: Running `/aapp-done <plan>` archives the completed plan to `.plans/done/000-archive-ledger.md`.

---

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🍳 [Cookbook Catalog](../../COOKBOOK.md)
- 🏠 [Repository Overview](../../README.md)
