---
title: The Two-Lane Protocol: Issues vs. Plans
description: Conceptual separation between fixing existing behavior and building new features, ledger schemas, promotion, and triage in AAPP.
---

# 🛤️ The Two-Lane Protocol: Issues vs. Plans

AAPP enforces a strict conceptual separation between **fixing what exists** and **building what does not exist**.

```text
                           ┌───────────────────────────┐
                           │      RAW IDEA / INPUT     │
                           └─────────────┬─────────────┘
                                         │
                   Does it describe broken/wrong behavior
                         in existing shipped code?
                                ╱            ╲
                             YES              NO
                             ╱                  ╲
                            ▼                    ▼
               ┌───────────────────────┐   ┌───────────────────────────┐
               │      ISSUE LANE       │   │         PLAN LANE         │
               │  Record in ISSUES.md  │   │  Draft in .plans/current  │
               │  Order on roadmap.md  │   │  Track on state_matrix.md │
               └───────────┬───────────┘   └─────────────┬─────────────┘
                           │                             │
                     Is fix large,                       │
                  multi-module, or RFC?                  │
                         ╱       ╲                       │
                      YES         NO                     │
                      ╱             ╲                    │
                     ▼               ▼                   ▼
            ┌─────────────────┐ ┌─────────┐   ┌────────────────────────┐
            │   PROMOTION     │ │ Direct  │   │  Incubator -> Freeze   │
            │ Draft Blueprint │ │  Patch  │   │     -> Execution       │
            └────────┬────────┘ └─────────┘   └────────────────────────┘
                     │                                   │
                     └───────────────────────────────────┘
```

---

## Strict Lane Separation

| Property | **Issue Lane** (Bugs & Gaps) | **Plan Lane** (Implementations) |
| :--- | :--- | :--- |
| **Describes** | Something that exists and behaves wrongly | Something that does not exist yet |
| **Canonical Record** | `ISSUES.md` (repo root or `.plans/`) | `.plans/current/<plan>.md` |
| **Cleared for work** | `.plans/issues_road_map.md` (the work queue) | `.plans/state_matrix.md` (frozen plans) |
| **Contents** | Bugs, regressions, edge-case gaps | Features, refactors, new capabilities |
| **Blast Radius?** | No — fixed in place | Yes — locked before execution |

---

## Flat Issue Ledger Schema (`ISSUES.md`)

`ISSUES.md` is strictly an active technical backlog. It consists of a preamble and a single flat database table with **zero subheadings**:

```markdown
| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #49 | `Critical` | `CORE` | 2026-09-10 | `lib/cmd_upgrade.sh:19` | Upgrade clones default branch but main trails develop. | Publish develop to main. | 🟡 `Incubated` |
```

### Field Specifications:
- **`#`**: Numeric identifier prefixed with `#` (e.g. `#1`, `#49`). Uses unpadded positive integers.
- **`Sev` (Severity)**: Technical impact classification:
  - `Critical`: Core runtime breakage, data corruption, or write-guard bypass.
  - `High`: Major functionality failure or unexpected crash.
  - `Medium`: Isolated feature failure, CLI ergonomics, portability issue.
  - `Low`: Formatting, cosmetic, or documentation drift.
- **`Type` (Extensible Domain Taxonomy)**: Uppercase token conforming to `^[A-Z0-9_-]+$`.
  - **Recommended Core Vocabulary**:
    - `CORE`: Core execution engine, runtime algorithms, language internals.
    - `CLI`: Command-line interface, argument parsing, terminal output, prompts.
    - `UI`: User interface, web views, components, layout, styling, UX.
    - `DB`: Database, ORM, schemas, migrations, persistent storage.
    - `NET`: Networking, API endpoints, HTTP/gRPC, socket protocols, remote sync.
    - `SEC`: Security, authentication, authorization, write guards, sandboxing.
    - `HOOK`: Git hooks, tool use interceptors, lifecycle plugins.
    - `DOCS`: Documentation, README, user manuals, starter templates.
    - `TEST`: Test suites, regression harnesses, CI/CD pipelines, assertions.
    - `PERF`: Performance, memory leaks, latency, caching, stream buffering.
  - **Extensibility Rule**: Projects may declare custom domain tags (e.g., `ML`, `AUDIO`, `3D`). Linters warn on unknown tokens, never block.
- **`Date`**: Date discovered (`YYYY-MM-DD`).
- **`Location`**: File path and line reference (`path/to/file.ext:123`).
- **`Symptom / Problem`**: Exact defect description (2–3 concise sentences maximum).
- **`Target Plan / Fix`**: Direction of fix, or link to promoted blueprint (`current/plan-<name>.md`).
- **`Status`**: `🟡 Incubated` (recorded, unscheduled) · `🔵 Planned` (promoted to a blueprint) · `🟠 In Progress` (active execution).
  *(Note: `✅ Resolved` does NOT exist in this table; resolved items are relocated to `.plans/done/000-issues-archive.md`).*
- **`Branch`** (optional, last column; also in the archive): the branch the issue's fix must land on. Empty, or the column absent, means the development branch.

---

## The Relocation Invariant & Archival Protocol

Active tables hold **ONLY** active items. Resolution is a **physical row relocation** out of `ISSUES.md` and into `.plans/done/000-issues-archive.md`.

### Archive Schema (`000-issues-archive.md`):
```markdown
# 🏛️ Master Issue Archive Ledger

| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #1 | `Critical` | `SEC` | 2026-09-09 | 2026-09-09 | `b9e0daf` (`v1.0.1`) | Added hookSpecificOutput.permissionDecision output. |
```

### Archival Workflows:
1. **With a Blueprint**: When an issue was promoted to a blueprint, completing the plan via `/aapp-done <plan>` automatically relocates the issue row to `.plans/done/000-issues-archive.md`, records the landing commit hash, and archives the plan.
2. **Direct (Non-Promoted) Fixes**: For small, in-place fixes without a blueprint, the developer or agent runs `aapp issue close <num>`, or manually cuts the row from `ISSUES.md`, appends it to `000-issues-archive.md`, and commits both files.
3. **Commit-Time Enforcement**: `.githooks/aapp-pre-commit` detects any resolved rows (`grep -E '^[[:space:]]*\|[[:space:]]*`?(#|ISSUE-)?[0-9]+`?.*(✅|[Rr]esolved)'`) left in `ISSUES.md` and blocks the commit.

---

## Work Queue (`issues_road_map.md`)

`issues_road_map.md` holds the issues cleared for work, and nothing else. Every issue is recorded in `ISSUES.md` and listed by `aapp issue list` in the order it was recorded. The work queue has two sections:
- **`## 🧱 Plan Blockers`**: written by `aapp issue hotfix`, one line per bug that blocks a plan; capped per plan by `aapp.maxEmergencyHotfixes`.
- **`## 📋 Queued`**: written by `aapp issue queue <num> [urgent | low]`, a person's decision that an issue may be worked on, in three levels: `### 🔺 Urgent` (a bottleneck, a security risk), `### Normal` (the default) and `### Low`. Inside a level the oldest comes first, so a waiting issue rises as the ones above it are done. Queueing an issue at another level moves it there, keeping its queue date; `aapp issue queue <num> remove` takes it off. Each line carries its queue date: `- [ ] #12 -> Login fails on Safari (queued 2026-10-16)`.

`aapp issue fix <num>` opens only an issue listed in one of the two sections, and `aapp issue fix next-blocker` takes the first blocker, then Urgent, Normal and Low in turn.

### What the lists show
`aapp issue list` and the Issues pillar of `aapp status` give each issue its facts on one line, so a person, an orchestrating agent or an agent can decide from the list itself:

```text
  #12    High     Incubated  logged 2026-10-01  queued 2026-10-16 (Urgent)   Login fails on Safari
  #7     Medium   Planned    logged 2026-09-28  queued 2026-10-02 (Normal)   Slow export  [P-91]
  #33    Low      Incubated  logged 2026-10-14                               Typo in the manual
```

**POSIX ID-Anchored Auto-Pruning**: The pre-commit hook auto-prunes any resolved list item using the POSIX ID-anchored regex `^[[:space:]]*([0-9]+\.|-[[:space:]]*\[[ xX]?\]|\*)[[:space:]]*`?(#|ISSUE-)?[0-9]+`?.*(✅|[Rr]esolved)`, preserving prose headers and explanatory text.

---

## Issue Conciseness Invariant (2–3 Lines Maximum)

To prevent context bloat and keep triage boards scan-friendly:
- **Concise Summaries**: Table entries in `ISSUES.md` must never be long transcripts or essays. State the exact location, the specific symptom, and the 1-line fix direction in **2–3 concise sentences maximum**.
- **The Complexity Rule**: If describing a bug, reproduction steps, or root cause requires multi-paragraph explanations, diagrams, or architectural analysis, **do not bloat `ISSUES.md`**. Log a 2-sentence summary in `ISSUES.md` and immediately promote it to a draft blueprint (`/digest ISSUE-00X`), where full technical blueprints and RFCs belong.

---

## Issue Promotion Protocol

When a bug requires architectural decisions, spans multiple modules, or requires a locked Blast Radius, it is promoted to a plan:

1. **Keep `ISSUES.md` intact**: The issue is never deleted; it remains the record of *what is wrong*.
2. **Draft and Link in One Command**: `aapp draft <slug> issue <num>` scaffolds `.plans/current/P<N>-<slug>.md` and, in the same commit, sets the plan's `**Target Issue / Milestone:** #<num>`, links the blueprint in the issue row's *Target Plan / Fix* cell (`[P-<N>](current/P<N>-<slug>.md)`) and sets the row's Status to 🔵 `Planned`. An archived or unknown issue is refused before any Plan ID is spent; observation cells are never touched.
3. **Keep It Open**: The issue stays in `ISSUES.md` until the fix ships (and on the work queue, if it was queued); the plan is registered in the matrix like any draft.
4. **Links Follow the Plan**: Renaming the plan (`aapp refine <id> slug <new-slug>`) and archiving it (`aapp done`) rewrite every *Target Plan / Fix* and road-map link pointing at the plan file, inside that command's own commit.
5. **Relocate upon Archive**: Relocate the issue row from `ISSUES.md` to `.plans/done/000-issues-archive.md` only when the plan is implemented, verified, and archived via `/done`. Prune the issue from `issues_road_map.md` (the pre-commit hook automatically purges any resolved items).

---

## Mid-Execution Issue Escape Triage

If an agent discovers an unexpected bug while executing a frozen plan:

1. **Plan work vs hotfix is decided by scope, not by file**: a bug the plan's change causes, or code it must rewrite anyway, is plan work. A bug unrelated to the change is a hotfix even in one of the plan's own files; otherwise the plan would stall for good.
2. **Evaluate Triage Path** for a bug outside them:
   - **Path A: Non-Blocking Bug**: Continue the assigned plan. Do not touch the bug. Log it with one command, `aapp issue log <sev> <type> "<symptom>" file <path>…`.
   - **Path B: Blocking**: `aapp issue hotfix "<text>" file <path>…`, one command, then stop.
   - **Path C: Blocking & Substantial**: `aapp issue hotfix "<text>" file <path>… plan` drafts an empty plan linked to the issue instead of queueing a small fix. Stop, present open questions to the human and wait: the design is theirs.

**Settings on this page:** [Issues & Fixes](../reference/03-configuration-matrix.md#issues--fixes)

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🍳 [Cookbook Catalog](../../COOKBOOK.md)
- 🏠 [Repository Overview](../../README.md)
