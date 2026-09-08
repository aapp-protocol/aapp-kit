# Project Rules: [Project Name]

See `CODEMAP.md` at the repo root before assuming where a concern lives -- it names the canonical owner for path resolution, configuration parsing, and module boundaries.

---

## 🏛️ Core Philosophy & Role
- Prioritize clean, low-dependency, and high-performance design.
- Maintain a single source of truth for paths, state, and configuration.

---

## 🚦 Code Verification & Changelog Rule
- **Every commit that touches code updates `CHANGELOG.md`. No exceptions — a one-character typo fix still gets a line.** The pre-commit hook enforces this, and it is not up for negotiation or optimization. Length is handled at release time, not by skipping entries.
- **For Code Changes:** You MUST run syntax checks, build steps, and automated tests BEFORE updating `CHANGELOG.md`.
- **For Rules & Internal Config (`.agents/*`):** Do NOT update `CHANGELOG.md`.
- When updating `CHANGELOG.md`, follow Keep a Changelog format: place entries under `## [Unreleased]`, categorize by `### Added`, `### Changed`, `### Fixed`, etc., with concise bullet points.

---

## 🛡️ Git Commit & Workflow Rule

### ✍️ Agent Attribution — Opt-In
> **Setting: `ENABLED`** — change to `DISABLED`, or delete this subsection entirely, to turn agent attribution off. Off is a perfectly good default; this is a matter of taste, not correctness.

While enabled, every commit you make carries a trailer naming **the agent that actually wrote the change**, so `git log` records which tool did what:

```text
Co-authored-by: <Agent Name> <agent@vendor.tld>
```

**Rules while this is enabled:**
- **Use your own identity.** You know which agent you are — fill it in. **Never copy a trailer you found in the existing `git log`**, and never inherit one left by a different agent. Pattern-matching the previous commit is the natural failure mode here, and it silently makes the history wrong.
- **Use your vendor's documented no-reply address.** If you do not actually know it, **ask the human rather than inventing one** — a fabricated address is worse than no trailer at all.
- **One trailer per agent** that genuinely contributed. If two agents worked the change, list both.
- **The human remains the commit `author`.** This is a co-author trailer only; it never replaces authorship.
- Applies equally to code commits and to commits inside the `plans`, `agents`, and `githooks` worktrees.

| Agent | Trailer |
| :--- | :--- |
| Claude Code | `Co-authored-by: Claude <noreply@anthropic.com>` |
| Antigravity | `Co-authored-by: Antigravity <antigravity@google.com>` |
| *anything else* | *use your vendor's documented address — do not guess* |

### 💥 Blast Radius Enforcement
When you write a `### 📂 Target Files` entry, the **first** `backticked path` on the line is the target and everything after it is prose. Mentioning another file in a description does **not** put it in scope — give every file its own line. You cannot widen your own blast radius by writing about a path.

Enforcement runs at **two moments**, and neither is optional:

| When | What |
| :--- | :--- |
| **Write time** | `.githooks/blast-radius-guard` (a `PreToolUse` hook) refuses the edit itself. A file outside the Target Files never changes on disk. |
| **Commit time** | `.githooks/pre-commit` refuses to record staged files outside the plan. |

If a write is refused, **do not work around it** — not with a shell heredoc, not with `sed`, not by disabling the hook. A refusal means the file is outside the plan you were given. Either stay inside the Target Files, or stop and ask the human to add the file to `### 📂 Target Files` first. Both layers also refuse any work on a plan marked `🚫 BLOCKED`.

---

## 🛤️ Two Lanes: Issues vs. Plans (Never Merge Them)
The workspace tracks two separate phases. Routing an item into the wrong lane corrupts both.

| | **Issue Lane** (bugs & gaps) | **Plan Lane** (implementations) |
| :--- | :--- | :--- |
| **Describes** | Something that exists and behaves wrongly | Something that does not exist yet |
| **Canonical record** | `ISSUES.md` (repo root) | `.plans/current/<plan>.md` |
| **Priority ordering** | `.plans/issues_road_map.md` | `.plans/state_matrix.md` |
| **Holds** | Bugs, regressions, edge-case gaps | Features, refactors, new capabilities |
| **Blast Radius?** | No — fixed in place | Yes — locked before execution |

- **Routing rule:** If it is wrong behaviour in code that already ships, it is an **issue** — and it is recorded in `ISSUES.md` first, always. If it is something not yet built, it is a **plan**. Never file a raw feature request in `issues_road_map.md`, and never drop a raw bug into `state_matrix.md` — what legitimately appears there is a *fix plan* carrying the issue's ID (see **Promotion** below).
- **Ordering rule:** Both priority files are ordered by **human judgement** — appetite, dependency, and available context, not a severity calculation. Read the order as given, report it as given, and append new items into the correct priority band. Do **not** re-sort, re-rank, or "optimize" either list unless the user explicitly asks you to.

---
### ⬆️ Promotion: an Issue becoming a Plan is a normal path
The lanes are separate, **not sealed**. A fix too large to simply *do* deserves a proper blueprint. This is not an exception or an escalation — it is ordinary engineering, and for a wide code touch it is the **expected** path, because a locked Blast Radius is exactly what you want around a big refactor.

**Take this path when it fits. Do not ask permission to draft.** Drafting is free: the blueprint lands in the Incubator unfrozen, carrying Open Questions, conferring no execution rights. The human reviews it there, and nothing reaches the code until `freeze`. Asking before drafting just asks twice.

- **Promote when the fix** touches several modules, needs a locked Blast Radius, carries real design decisions, spans more than one session, or is a refactor rather than a patch.
- **Do not promote** a small, obvious fix. Just make it.
- A *blocking* bug hit mid-execution is a different case — use `### 🚨 Emergency Hotfix Extensions` (see *Issue Escape Triage*), not a promotion.

**How promotion works:**
1. The issue is **never deleted or moved out of `ISSUES.md`**. It stays the record of *what is wrong*; the plan becomes the record of *how it will be fixed*.
2. Run `digest ISSUE-00X` to scaffold the blueprint from `.plans/plan-template.md`.
3. Link the two records with the fields the templates already carry: put the issue ID in the plan's `**Target Issue / Milestone:**` field, and a link to the blueprint in the issue's `Proposed Fix / Target Plan` cell.
4. Set the issue's status to 🔵 `Planned` and **leave it on `issues_road_map.md`** — it is still an open issue until the fix ships.
5. Register the plan in `state_matrix.md` like any other, with the issue ID visible in its entry.
6. Close the issue only when the fix is verified and the plan is archived via `done`.

**Visibility, not permission.** Promote when it fits, then **say plainly what you did and why** — "ISSUE-004 touches four modules and the parser contract, so I promoted it to a draft blueprint." The human can refine, abort, or ignore it; a draft costs nothing. What you must never do is promote *silently*.

**Promotion does not touch priority.** The issue keeps the exact band the human put it in on `issues_road_map.md`. Promoting changes *how* it gets fixed, never *when* — the ordering rule still holds absolutely.

**Ask only when the size is genuinely ambiguous** — a fix that could reasonably go either way. Default to proceeding.

**One hard exception — blocking bugs.** If the bug halts work already in flight *and* the fix is substantial, promotion is **never** automatic: stop, block the in-flight plan, and ask. See *Issue Escape Triage*.

> **Where the real gates are:** drafting is free, **`freeze` is the gate** — that is where a plan becomes executable and the pre-commit hook starts enforcing its Blast Radius. Likewise, amending an *already frozen* plan needs explicit approval, because that changes what the hook permits in the working tree. Gate what becomes executable, not what gets written down.


## 🤖 Asymmetric Planning Protocol (AAPP) & Workflow Commands
All planning and architectural tracking operates in the isolated `.plans/` worktree (on orphan branch `plans`), keeping design text decoupled from active code branches.

The agent must support and execute these shorthand workflow triggers immediately without requiring manual prompt setup:

- **`status` (or `/status`)**: Act as a Context Recovery agent upon desk return.
  1. Inspect `CHANGELOG.md` (`## [Unreleased]`) to identify recently shipped code.
  2. **Issue lane:** Inspect `ISSUES.md` (the canonical issue record) and `.plans/issues_road_map.md` (the human's fix ordering over it). Report the top open issues **in the order the board gives them**.
  3. **Plan lane:** Inspect `.plans/state_matrix.md` (future implementations only) for active incubator plans, blockers, and greenlit tasks. Keep this separate from the issue lane in your briefing — never blend the two into one list.
  4. **Pickup queue:** Inspect `.plans/pickup.md` and **list the unprocessed ideas by name, with a count**. These are live and unworked — often the most valuable thing on the board when the user has just returned to the desk. Surface them so the user can pick one; do **not** digest them, and do not compress them away into a single "you have some notes" line.
  5. Print a concise, structured briefing across all **four pillars — Shipped, Issues, Plans, Pickup** — with immediate next actions. **Never omit a pillar**, even when it is empty: write `Pickup: empty` rather than silently dropping the section. Where the Pickup queue is non-empty, offer `/digest <idea>` on a named entry as a next action.

- **`digest <idea>` (or `/digest <idea>`)**: Take **one** idea and work it toward a plan. This is a targeted operation — never a bulk sweep of `pickup.md`.

  **Step 1 — Resolve the idea.** `<idea>` may be raw text typed inline, or a reference to an entry in `.plans/pickup.md`. If `<idea>` is omitted, list the open entries in `pickup.md` and **ask the user which one to digest**. Never choose for them, and never process the whole file at once.

  **Step 2 — Route it to a lane.** If the idea describes wrong behaviour in code that already ships, it is an issue: **record it in `ISSUES.md` and place it on `.plans/issues_road_map.md` first — always.** Then judge the size of the fix:
  - **Small / obvious fix** → stop there. The issue record is enough; no blueprint.
  - **Large fix** (several modules, needs a Blast Radius, real design decisions, spans sessions, or is a refactor) → **promote it and continue to Step 3.** Draft the blueprint, then state plainly that you promoted it and why. Do not stop to ask first — the draft is unfrozen and costs nothing. **Unless it is blocking work already in flight** — then stop and ask (see *Issue Escape Triage*).
  - **`<idea>` is itself an issue ID** (e.g. `digest ISSUE-004`) → the user has already chosen promotion. Go straight to Step 3 and carry the issue ID into the plan.

  (See *Promotion: an Issue may become a Plan*.)

  **Step 3 — Decide NEW or AMEND.** Scan `.plans/current/*.md` before writing anything:
  - **AMEND** — the idea refines, extends, or corrects a plan already in flight.
  - **NEW** — no active plan covers it.
  - If the match is ambiguous, **ask**. Never silently fold an idea into an unrelated blueprint. State which path you chose, and for AMEND name the plan you matched and why.

  **Step 4a — NEW plan (from scratch):**
  1. Cross-reference `CODEMAP.md` and `ARCHITECTURE.md` so the design extends existing modules instead of adding duplicate helpers or wrappers.
  2. Scaffold `.plans/current/<feature-name>.md` from `.plans/plan-template.md`.
  3. Fill in *Context & Architectural Goal* and a first-pass *Technical Blueprint*.
  4. Propose a Blast Radius. Mark it **PROPOSED** — it is not locked and confers no execution rights.
  5. Write every unresolved decision into *Open Questions*. A first draft with no open questions is usually an under-examined draft.
  6. Register it in `.plans/state_matrix.md` under the Incubator with status 🔴/🟡.

  **Step 4b — AMEND an existing plan:**
  1. Fold the new detail into the section it belongs to — *Technical Blueprint*, *Open Questions*, or *Blast Radius*.
  2. Append a dated line to that plan's `## 📦 5. Change Log & Refinement History` recording what changed and why.
  3. **If the plan is already frozen / greenlit:** changing its Blast Radius changes what the pre-commit hook will permit. Stop, get explicit approval, and move the plan back to the Incubator in `state_matrix.md` until it is re-frozen.
  4. Update its `state_matrix.md` entry if the status changed.

  **Step 5 — Clean up.** Remove **only** the digested entry from `pickup.md`. Leave every other note in place.

  **Step 6 — Report.** State which path you took (NEW / AMEND / routed to `ISSUES.md`), name the file you wrote, and list the Open Questions the user must answer next.

  > **`digest` produces a draft, never a green light.** The output is an Incubator entry to be refined. Only `freeze` makes a plan executable.

- **`freeze <plan>` (or `/freeze <plan>`)**: Lock and greenlight a blueprint for code execution.
  1. Scan `.plans/current/<plan>.md` to verify all Open Questions are resolved and Blast Radius (`Target Files` / `Out of Bounds`) is explicitly defined.
  2. Move the plan in `.plans/state_matrix.md` from the Incubator into `## 🟢 2. Frozen & Ready for Coding (The Greenlight Zone)`.
  3. Seal the boundary: the execution session may only touch files in the locked Blast Radius.

- **`done <plan>` (or `/done <plan>`)**: Complete lifecycle and archive implemented blueprint.
  1. Move the plan file: `mv .plans/current/<plan>.md .plans/done/<plan>.md`.
  2. Update `.plans/state_matrix.md` to mark the plan `100% DONE` in the summary table and Archival Ledger.
  3. Commit the transition to the `plans` worktree.

- **`release <version>` (or `/release <version>`, `/preflight`)**: Execute release pre-flight verification runbook.
  1. Inspect `.plans/release/release_checklist.md` (the canonical release runbook for the project).
  2. If the checklist contains unconfigured placeholders, assist the developer in tailoring the audit and test commands to the project's actual stack.
  3. Step through the defined test suites, linters, and security audit checks.
  4. Verify `CHANGELOG.md` has version entries staged and ready for tagging.
  5. Report a structured release posture assessment (Tests, Linters, Docs, Rollback readiness) to the user.

---

## 🐛 Issue Escape Triage (Mid-Execution Bugs)
If you discover an unexpected bug while executing a plan inside a locked Blast Radius, **record it in `ISSUES.md` first — always** — then take one of three paths:

- **Non-blocking:** Do not fix it. Continue the assigned plan. Do not add it to `state_matrix.md`, and do not re-prioritize `issues_road_map.md` on your own — append it and let the human place it.

- **Blocking & small:** The bug halts the plan but the fix is contained. Pause, expand the plan's Blast Radius under an `### 🚨 Emergency Hotfix Extensions` subsection with a one-sentence justification, fix the blocker, log the hotfix, and resume.

- **Blocking & substantial:** The bug halts the plan *and* the fix is real work — several modules, a Blast Radius of its own, or genuine design decisions.
  **STOP. Do not fast-forward a design, and do not promote it on your own.** This is the one place promotion is never automatic.
  1. Set the in-flight plan's status to 🚫 `BLOCKED` and record `**Blocked On:** ISSUE-00X` in the plan file.
  2. Move it out of the Greenlight Zone into `## 🚫 Blocked` in `state_matrix.md`. **A blocked plan is not executable** — and the pre-commit hook enforces it: while the Status line says `BLOCKED`, that plan admits no commits at all.
  3. Report the situation and **ask** whether to promote the issue into its own plan. Lay out what you know — scope, modules touched, the options you can see — as **open questions, not decisions already taken**.
  4. Wait. Resume only when the human unblocks: the issue is fixed, the blocked plan is re-scoped around it, or they explicitly say to continue.

> **Why this one asks, when promotion normally does not.** Everywhere else drafting is free, because a draft sits harmlessly *beside* your work. A blocking bug is different: the human's actual plan is stalled, so anything you fast-forward arrives while they are under pressure to accept it just to get moving again. That is the worst possible moment to hand someone a finished design and a set of decisions already made. Substantial blocking work is the human's call, made unhurried.

---

## 🧹 Token Efficiency & Archival Scoping
- **Active Focus Only:** When inspecting `.plans/state_matrix.md`, focus strictly on active sections (`Roadmap`, `1. The Incubator`, and `2. The Greenlight Zone`).
- **Ignore Collapsed Archives:** Strictly ignore all collapsed `<details>` tags, historical milestone ledgers, or files in `.plans/done/` unless the user explicitly requests a historical lookup or audit.

---

## 📂 Project Context
Refer to `.agents/PROJECT.MD` for specific sub-agent behavior profiles and task queues.
