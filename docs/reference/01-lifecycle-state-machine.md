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

### 3.4 Committing Plan Edits (`aapp refine`)
Lifecycle verbs commit their own changes; `aapp refine` commits the rest. Nobody, agent or person, needs raw `git` in the plans worktree.

- **Content:** `aapp refine <id> "<what changed>"` commits only that plan file, with the configured attribution, as `plan(refine): <id> <what changed>`, and prints `📝 [Refine] <id> committed (<sha>): <what changed>`. It refuses a missing message, an unknown plan and a plan with no changes.
- **One line, within the limit:** the message becomes the commit subject, so `plan(refine): <id> <msg>` must fit `aapp.subjectMaxLen` (default 72). The overrun is named before any Git work: `Commit subject is 81 characters; the limit is 72 (aapp.subjectMaxLen).` and `Shorten the message by 9 characters`.
- **Owner only:** a plan in development is refined only from its own worktree, or from the checkout whose active-plan buffer holds it. In a group in development, every plan of the group is refined only from a checkout bound to one of its plans. Elsewhere the refusal names what to do instead: tell the developer, log an issue, or add a pickup line.
- **Design lock:** on a frozen plan, the pre-commit hook still refuses changes to §2 and §4; ticks in §3, §5 and §6 are allowed.
- **Blocking:** `aapp refine <id> blocked <num>` sets the Status to `🟥 BLOCKED` and adds `#<num>` to `* **Blocked On:**` (the first block records the previous status, e.g. `#41 (was ⚡ In Development)`); an unknown or archived issue is refused. `aapp refine <id> unblocked <num>` takes a closed issue off, for a fix that reached the plan's parent branch as another commit (squash, cherry-pick, rebase), which `aapp issue close` and `aapp status` cannot recognise. Neither touches `state_matrix.md`: run `aapp matrix` after them.
- **Renaming:** `aapp refine <id> slug <new-slug>` renames `current/P<N>-<old>.md` (the `P<N>-` prefix and Plan ID never change). In one commit it repairs every issue and work-queue link to the file, re-derives the matrix, follows the active buffer and logs `File renamed from <old> to <new>` in the plan's §6. It refuses an empty slug, an existing target and a plan with uncommitted edits. The title line is content: reword it with a normal refine.
- **Also closes:** `aapp refine <id> closes <num> [remove]` lists a further issue the plan sorts; `aapp done` closes it with the plan's commit.
- **Groups:** `aapp refine <id> group <group>|none` moves a plan into a group or out of it before it starts; the amendments member has its own forms ([16. Group Amendments](16-group-amendments.md)).
- **Ledgers:** `aapp refine pickup "<msg>"` commits a hand edit of `pickup.md`; `aapp refine issues "<msg>"` commits changes to existing rows of `ISSUES.md` and `issues_road_map.md` (new rows come only from `aapp issue log`). `pickup` and `issues` are reserved words, checked before plan names. The edit is checked first and nothing is committed on a failure; each message names the line to fix ([13. Planning Health](13-planning-health-engine.md)).

### 3.4a One Changelog Entry per Plan (`aapp.changelogMode`)
A tool cannot know which commit completes a plan, but the plan knows what it delivers, so it declares its release note once, in its header:

```markdown
* **Changelog:** Added: Shared docs never block concurrent plans
```

- `aapp draft` pre-fills it as `Changed: <Title>`; reword it and pick `Added:`, `Changed:` or `Fixed:` while refining. `aapp freeze` refuses a missing, malformed or over-long declaration (`aapp.changelogMaxLen`).
- In `plan` mode (the default), `aapp commit` writes `- <text> (\`P-xx\`)` under `## [Unreleased]` on the plan's first commit, and replaces that line if the declaration is reworded later. Every later commit for the plan passes without touching `CHANGELOG.md`: a plan with five commits ships one bullet.
- A code commit with no active plan (a direct fix) must change `CHANGELOG.md` itself, and so must every code commit in `commit` mode.
- `aapp init` adds `CHANGELOG.md merge=union` to `.gitattributes`, so entries added on two branches are both kept when they merge.

**The entry lands with the plan's first commit.** No tool can know which commit is a plan's last, so the line is written when the plan starts committing. Its wording follows the plan's current declaration; its position reflects the start:

| Day | Commit | `## [Unreleased]` → `### Fixed` |
| :--- | :--- | :--- |
| 1 | P-60's first commit (on `develop`) | `- Parser handles empty input (P-60)` |
| 2 | a direct fix, no plan | `- Guard no longer crashes on symlinks` ← new line on top<br>`- Parser handles empty input (P-60)` |
| 3 | P-60's last commit | unchanged: the plan's line stays below the fix |

- Working on the development branch directly, a plan's line sits below anything committed after the plan started, and `git log CHANGELOG.md` shows it in the plan's first commit.
- A plan worktree integrated with `squash` arrives as one commit carrying its one line, so the question does not arise.
- To change the wording, edit the `**Changelog:**` line, commit it with `aapp refine`, and the next `aapp commit` updates the bullet in place.

Settings: [Commits & Changelog](03-configuration-matrix.md#commits--changelog).

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
