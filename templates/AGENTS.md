# Project Rules: [Project Name]

See `.agents/CODEMAP.md` (or `CODEMAP.md` at the repo root) before assuming where a concern lives -- it names the canonical owner for path resolution, configuration parsing, and module boundaries.

---

## 🏛️ Core Philosophy & Role
- Prioritize clean, low-dependency, and high-performance design.
- Maintain a single source of truth for paths, state, and configuration.
- Enforce strict repository portability: never write absolute machine paths or `file://` URIs into project files.
- Enforce canonical planning: implementation blueprints belong in `.plans/current/` under Git-level Blast Radius protection, never in proprietary ephemeral IDE scratchpads (`implementation_plan.md`).
- Enforce clean breaks: in refactors and migrations, clean breaks are the mandatory default; backwards-compatibility fallbacks, duplicate aliases, or dual-syntax parser regexes are strictly forbidden unless explicitly itemized and justified in Section 2 (Technical Blueprint).

<!-- AAPP-PROTOCOL:START v1.0.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOM RULES OUTSIDE. -->

## 🚦 Code Verification & Changelog Rule
- **Every code change is covered by `CHANGELOG.md`. No exceptions — a one-character typo fix still counts.** The pre-commit hook enforces this, and it is not up for negotiation or optimization.
  - **Work for a plan (`aapp.changelogMode = plan`, default):** the plan declares its single entry in its `* **Changelog:**` header line; `aapp commit` writes it under `## [Unreleased]` on the plan's first commit, and later commits for that plan pass once it is there. Never hand-edit the plan's bullet: reword the plan's line and commit it with `aapp refine`.
  - **No active plan (a direct fix), or `aapp.changelogMode = commit`:** the commit itself must change `CHANGELOG.md`.
  - **Never leave a change out to keep the changelog short:** in `plan` mode one entry covers all of a plan's commits; in `commit` mode and for direct fixes each code commit adds its own line. Condensing is done at release time.
- **For Code Changes:** You MUST run syntax checks, build steps, and automated tests BEFORE updating `CHANGELOG.md`.
- **For Rules & Internal Config (`.agents/*`):** Do NOT update `CHANGELOG.md`.
- **Changelog Single-Line Bullet Invariant**: When updating `CHANGELOG.md`, follow Keep a Changelog format: place entries under `## [Unreleased]` or version headers, categorize by `### Added`, `### Changed`, `### Fixed`, etc. Every entry MUST be a concise, single-line bullet starting with `- ` (strictly <= 300 characters, configurable via `git config aapp.changelogMaxLen`). Unbulleted continuation lines and multi-line indented paragraphs are strictly prohibited.

---

## 🛡️ Git Commit & Workflow Rule

### 🌐 Portability & Relative Path Invariant (Zero Machine-Specific `file://` URIs)
- **Relative paths only**: All paths written into repository files (`.plans/*`, `.agents/*`, `README.md`, `MANUAL.md`, templates, source code, and commit messages) MUST be repository-relative or plain backticked basenames.
- **Strictly forbidden in tracked files**: Machine-specific absolute paths (e.g. `/home/user/...`, `/Users/user/...`, `C:\...`) and `file:///` URI schemes are strictly prohibited. They break portability across clones, corrupt web links on GitHub/GitLab, and leak local filesystem paths.
- **Chat vs. Workspace Boundary**: AI IDE instructions requiring clickable `file://` links apply **exclusively to conversational chat output** presented in the IDE interface. They must **never** bleed into files written to the workspace. The pre-commit hook mechanically rejects any commit introducing `file:///` URIs or absolute home paths into tracked files.

### ✍️ AI Attribution Switchboard & Commit Standards

Attribution mode is governed by repository configuration (`git config aapp.aiAttribution`):

| Mode | Command | Scope & Behavior |
| :--- | :--- | :--- |
| `none` | `aapp ai none` | **Pure human authoring.** No AI trailers in commit messages; trailers are refused. (Notes remain independently usable via `aapp note`). |
| `lax` | `aapp ai lax` | **Default. Mixed human/AI work.** Validates emailless trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`) when present; human commits pass freely. Notes attach in parallel when provided or when `aapp.aiNotes=true`. |
| `strict` | `aapp ai strict` | **Autonomous agent trace.** Every commit must carry valid emailless semantic trailers. Notes attach in parallel when provided or when `aapp.aiNotes=true`. |
| `notes` | `aapp ai notes` | **Private-first attribution.** Leaves commit messages pristine and human-only; records attribution metadata in `refs/notes/ai`. |

#### 📝 Parallel Git Notes (Hand-in-Hand or Independent)
Git notes are out-of-band metadata (`refs/notes/ai` for AI audit traces and `refs/notes/commits` for review/developer context) that operate orthogonally to commit message trailers:
- **Hand-in-Hand**: Run `aapp ai strict` (or `lax`) and enable parallel notes via `aapp ai notes on` (or pass `note "<text>"` to `aapp commit`). Commits receive public trailers AND an immutable audit trace in `refs/notes/ai`.
- **Private Compliance**: Run `aapp ai none` with `aapp ai notes on`. Commit messages remain 100% human and clean, while internal audit traces are recorded in `refs/notes/ai`.
- **Independent Context**: Any commit across all modes can attach developer review notes via `aapp commit ... note "<text>"` or `aapp note stage`.

#### 🏷️ Semantic Trailer Standard (`lax` and `strict` modes)
When operating with public semantic trailers (`lax` or `strict`), AI commits MUST carry semantic, emailless trailers. **Synthetic or fake email addresses (`Co-authored-by: Agent <email>`) are strictly forbidden** to prevent GitHub account hijacking and spoofing:

```text
AI-Agent: <Agent Name>
AI-Vendor: <Vendor Name>
AI-Model: <Model ID>
```

| Agent | Semantic Trailers |
| :--- | :--- |
| Claude Code | `AI-Agent: Claude`<br>`AI-Vendor: Anthropic`<br>`AI-Model: claude-3-5-sonnet-20241022` |
| Antigravity | `AI-Agent: Antigravity`<br>`AI-Vendor: Google`<br>`AI-Model: gemini-1.5-pro` |

#### 📏 Numeric Commit Conciseness & Structure Invariant
- **Subject Length**: Commit subject lines must not exceed `72` characters (configurable via `git config aapp.subjectMaxLen`).
- **Imperative Mood**: Write subject lines in the imperative mood (e.g. `feat: add ...`, `fix: handle ...`).
- **Blank Separator Line**: Line 2 must be blank if a commit body is present. Text immediately following the subject without an empty line breaks `git log --oneline` and is rejected.
- **Line Width**: No individual line in the commit body may exceed `100` characters (configurable via `git config aapp.commitLineMaxLen`), with exceptions for lines containing unbroken URLs.
- **Body Volume**: Total commit body volume must not exceed `1,200` characters (configurable via `git config aapp.bodyMaxLen`) and `20` lines (configurable via `git config aapp.maxBodyLines`), excluding trailing metadata/trailers.
- **Concise Scope**: Explain *why* and *what*, leaving detailed architectural design to `.plans/current/<plan>.md`.

#### ⚖️ Commit vs. Notes Asymmetry
- **Trailers are primary**: They become immutable parts of the commit object, survive `git cherry-pick`, `git rebase`, and display natively on GitHub/GitLab without requiring special push refspecs.
- **Notes are opt-in and local-first**: Notes keep commit messages pristine for internal or private benchmarking. Notes require explicit push refspecs (`+refs/notes/*:refs/notes/*`), merge strategies (`cat_sort_uniq`), and `notes.rewriteRef=refs/notes/commits` to persist across amends and rebases.

#### 📝 Staged Note Protocol (`notes` mode)
When operating in `notes` mode, an agent or developer customizes attribution by pre-staging a note buffer before `git commit`:
- Note buffer path: `$(git rev-parse --git-path aapp_pending_note).<message-sha256>`
- `aapp-post-commit` automatically matches the commit body hash, attaches the note via `git notes add -f -F`, and unlinks the buffer on success (`&&`).

### 🎯 Plan-Bound Commit Helper (`aapp commit`)
When executing an active plan (`⚡ In Development`), autonomous agents should use the plan-bound commit helper (`aapp commit "<msg>" [agent <A> vendor <V> model <M>] [note "<text>"]`) rather than raw `git commit`. The helper commits staged code, completes required attribution trailers, records `sha (branch)` in the active plan's header, and commits the plan file alone. If a raw `git commit` is made, agents can repair the record with `aapp commit adopt <sha>...`.

### 📜 Worktree Commit & Plan Lifecycle Conventions
When committing changes inside the `.plans/`, `.agents/`, or `.githooks/` worktrees, use structured lifecycle prefixes so `git log` provides a clean, searchable architectural audit trail:

| Scope | Prefix | Purpose / Example |
| :--- | :--- | :--- |
| **Plan Draft** | `plan(draft):` | `plan(draft): scaffold <plan-name> from pickup` |
| **Plan Refinement** | `plan(refine):` | `plan(refine): <plan-id> resolve open questions` (written by `aapp refine`) |
| **Plan Freeze** | `plan(freeze):` | `plan(freeze): lock blast radius and greenlight <plan-name>` |
| **Plan Archival** | `plan(done):` | `plan(done): archive <plan-name> to done/ and update state matrix` |
| **Issue Triage** | `issue(triage):` | `issue(triage): log #<num> in .plans/ISSUES.md` |
| **Agent Rules** | `rules(agents):` | `rules(agents): update behavioral guidelines in .agents/AGENTS.md` |
| **Git Hooks** | `feat(hooks):` | `feat(hooks): update blast radius enforcement engine` |

### 💥 Blast Radius Enforcement
When you write a `### 📂 Target Files` entry, the **first** `backticked path` on the line is the target and everything after it is prose. Mentioning another file in a description does **not** put it in scope — give every file its own line. You cannot widen your own blast radius by writing about a path.

Enforcement runs at **two moments**, and neither is optional:

| When | What |
| :--- | :--- |
| **Write time** | `.githooks/blast-radius-guard` (a `PreToolUse` hook) intercepts structured file-writing tools (`Write`, `Edit`, `MultiEdit`, `NotebookEdit`). External agent scratchpads and memories (e.g. `~/.claude/`, `~/.gemini/`, `/tmp/`, or configured via `git config aapp.allowPath`) are authorized, while repository edits outside declared Target Files are refused before touching disk. |
| **Commit time** | `.githooks/pre-commit` is the authoritative boundary that refuses to record staged files outside the plan. Because shell executions (`Bash`) carry command strings rather than structured file targets, write-time tool interception cannot safely parse raw shell writes; Layer 2 (`pre-commit`) serves as the strict, inescapable gate for all committed code. |

If a write is refused, **do not work around it** — not with a shell heredoc, not with `sed`, not by disabling the hook. A refusal means the file is outside the plan you were given. Either stay inside the Target Files, or stop and ask the human to add the file to `### 📂 Target Files` first. Both layers also refuse any work on a plan marked `🚫 BLOCKED`.

### 🔒 Frozen Plan Immutability & Design-Lock Contract
Once a blueprint is frozen (`🔷 Ready for Execution`), its **design** is locked while its **execution progress** remains writable:
- **Locked Regions**: `## 2. Technical Blueprint` and `## 4. Blast Radius & System Boundaries`. Attempting to modify these sections while a plan is frozen is strictly blocked by `pre-commit`.
- **Permitted Regions**: Task checkboxes in `## 3.` (`- [ ]` → `- [x]`), `## 5. Open Questions`, and `## 6. Change Log` remain freely editable to record execution progress and verification history.
- **Unfreezing**: To modify a frozen blueprint or blast radius, the plan must be explicitly unfrozen first by reverting status to `📝 Refining` (with §2 and §4 untouched in that unfreeze commit).

### 🔄 Clean Break Invariant & Fallback Governance
In refactors, schema migrations, and API updates, **clean breaks are the mandatory default**:
- **Zero Un-named Fallbacks**: Autonomous coding agents must NEVER unilaterally introduce backwards-compatibility fallbacks, legacy shim wrappers, duplicate aliases, or dual-syntax parser regexes.
- **Explicit Declaration in Section 2**: If an adopter or project constraint genuinely requires backwards compatibility, every preserved fallback, alias, or legacy schema MUST be explicitly itemized in the plan's `## 2. Technical Blueprint` under `### 🔄 Migration & Compatibility Strategy`, accompanied by a clear justification and retirement/deprecation date.
- **Unlisted Fallbacks Prohibited**: Any fallback, legacy alias, or dual-syntax regex introduced into the codebase that is not explicitly registered in Section 2 is considered architectural debt and a protocol violation.

---

## 🛤️ Two Lanes: Issues vs. Plans (Never Merge Them)
The workspace tracks two separate phases. Routing an item into the wrong lane corrupts both.

| | **Issue Lane** (bugs & gaps) | **Plan Lane** (implementations) |
| :--- | :--- | :--- |
| **Describes** | Something that exists and behaves wrongly | Something that does not exist yet |
| **Canonical record** | `.plans/ISSUES.md` (or repo root) | `.plans/current/<plan>.md` |
| **Priority ordering** | `.plans/issues_road_map.md` | `.plans/state_matrix.md` |
| **Holds** | Bugs, regressions, edge-case gaps | Features, refactors, new capabilities |
| **Blast Radius?** | No — fixed in place | Yes — locked before execution |

- **Routing rule:** If it is wrong behaviour in code that already ships, it is an **issue** — and it is recorded in `.plans/ISSUES.md` (or root `ISSUES.md`) first, always. If it is something not yet built, it is a **plan**. Never file a raw feature request in `issues_road_map.md`, and never drop a raw bug into `state_matrix.md` — what legitimately appears there is a *fix plan* carrying the issue's ID (see **Promotion** below).
- **Ordering rule:** Both priority files are ordered by **human judgement** — appetite, dependency, and available context, not a severity calculation. Read the order as given, report it as given, and append new items into the correct priority band. Do **not** re-sort, re-rank, or "optimize" either list unless the user explicitly asks you to.

### 📏 Issue Conciseness Invariant (2–3 Lines Maximum)
- **Table entries in `ISSUES.md` must never be long transcripts or essays.** State the location, the exact symptom, and the 1-line fix direction in **2–3 concise sentences maximum**.
- **The Complexity Rule:** If describing the bug, reproduction steps, or root cause requires multi-paragraph explanations, diagrams, or architectural analysis, **do not bloat `ISSUES.md`**. Log a 2-sentence summary in `ISSUES.md` and immediately promote it to a draft blueprint (`/digest ISSUE-00X`), where full technical blueprints belong.

### 🏛️ Flat Issue Ledger & Relocation Invariant
- **Single Flat Table:** `ISSUES.md` consists of exactly one markdown table with zero subheadings: `| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |`.
- **The Relocation Invariant:** Active `ISSUES.md` holds ONLY active items (`🟠 Incubated`, `🔵 Planned`, `🟠 In Progress`). Resolved issues are physically relocated to `.plans/done/000-issues-archive.md`. The status badge `✅ Resolved` does NOT exist in active `ISSUES.md`. Pre-commit hooks detect and block any commit leaving resolved rows in `ISSUES.md`.
- **Historical Issue Immutability Invariant:** Issue entries in `ISSUES.md` and `000-issues-archive.md` are immutable historical records of observed symptoms at that date. Autonomous agents must **never** edit, rephrase, sanitize, or modernize an issue's original location or symptom text when triaging, promoting, or relocating. If an issue is resolved or obsoleted by an architectural pivot rather than a direct patch, the archive resolution summary must simply state: `Superseded by [P-XX](...) and [P-YY](...)` without altering historical prose.
- **Universal Domain Taxonomy:** The `Type` column uses an uppercase token conforming to `^[A-Z0-9_-]+$` (recommended core: `CORE`, `CLI`, `UI`, `DB`, `NET`, `SEC`, `HOOK`, `DOCS`, `TEST`, `PERF`).

### 🏷️ Distinct Identifiers: Issue IDs (`#<num>`) vs. Plan IDs (`P-<num>`)
- **Issues use `#<num>`**: Unpadded integer IDs prefixed with `#` (e.g. `#1`, `#49`, `#64`). Claim one with `aapp issue allocate` (the `aapp.issueId` counter; `aapp issue next` peeks). Never pick an ID by scanning `ISSUES.md`: it is priority-ordered and resolved rows live in the archive.
- **Plans use `P-<num>`**: Unpadded integer IDs prefixed with `P-` (e.g. `P-1`, `P-8`, `P-9`, `P-13`). Active blueprint filenames adopt ADR-style naming: `P<num>-<slug>.md` (e.g. `P9-guard-path-authorization.md`).
- **Namespace Separation**: Issue references (`#9`) and Plan references (`P-9`) must never be interchanged. Commands (`/aapp-freeze`, `/aapp-done`) accept Plan IDs (`P-9`, `9`), slugs (`guard-path`), or filenames, and reject `#9` with an advisory notice.
- **Pair 5 Self-Protection Rule**: When declaring `### 📂 Target Files`, never list files matching Guard Section 2 self-protection (`.githooks/*`, `.agents/skills/aapp-*`, `.claude/settings*`, `.cursor/rules/*`). Pair 5 of the planning-health engine mechanically blocks any blueprint violating this rule.

---
### ⬆️ Promotion: an Issue becoming a Plan is a normal path
The lanes are separate, **not sealed**. A fix too large to simply *do* deserves a proper blueprint. This is not an exception or an escalation — it is ordinary engineering, and for a wide code touch it is the **expected** path, because a locked Blast Radius is exactly what you want around a big refactor.

**Take this path when it fits. Do not ask permission to draft.** Drafting is free: the blueprint lands in the Incubator unfrozen, carrying Open Questions, conferring no execution rights. The human reviews it there, and nothing reaches the code until `freeze`. Asking before drafting just asks twice.

- **Promote when the fix** touches several modules, needs a locked Blast Radius, carries real design decisions, spans more than one session, or is a refactor rather than a patch.
- **Do not promote** a small, obvious fix. Just make it.
- A *blocking* bug hit mid-execution is a different case — use `### 🚨 Emergency Hotfix Extensions` (see *Issue Escape Triage*), not a promotion.

**How promotion works:**
1. The issue is **never deleted or moved out of `.plans/ISSUES.md`**. It stays the record of *what is wrong*; the plan becomes the record of *how it will be fixed*.
2. Run `digest ISSUE-00X` to scaffold the blueprint from `.plans/plan-template.md`.
3. Link the two records with the fields the templates already carry: put the issue ID in the plan's `**Target Issue / Milestone:**` field, and a link to the blueprint in the issue's `Proposed Fix / Target Plan` cell.
4. Set the issue's status to 🔵 `Planned` and **leave it on `issues_road_map.md`** — it is still an open issue until the fix ships.
5. `aapp draft` registers the plan in `state_matrix.md` like any other; the issue ID lives in its `Target Issue` header.
6. Close the issue only when the fix is verified and the plan is archived via `done`. `aapp done` relocates the Target Issue row to `.plans/done/000-issues-archive.md` and prunes `issues_road_map.md` in the same commit. For a direct fix with no plan, run `aapp issue close <num> [sha <sha>] [summary "<text>"]` instead of editing the tables by hand.

**Visibility, not permission.** Promote when it fits, then **say plainly what you did and why** — "ISSUE-004 touches four modules and the parser contract, so I promoted it to a draft blueprint." The human can refine, abort, or ignore it; a draft costs nothing. What you must never do is promote *silently*.

**Promotion does not touch priority.** The issue keeps the exact band the human put it in on `issues_road_map.md`. Promoting changes *how* it gets fixed, never *when* — the ordering rule still holds absolutely.

**Ask only when the size is genuinely ambiguous** — a fix that could reasonably go either way. Default to proceeding.

**One hard exception — blocking bugs.** If the bug halts work already in flight *and* the fix is substantial, promotion is **never** automatic: stop, block the in-flight plan, and ask. See *Issue Escape Triage*.

> **Where the real gates are:** drafting is free, **`freeze` is the gate** — that is where a plan becomes executable and the pre-commit hook starts enforcing its Blast Radius. Likewise, amending an *already frozen* plan needs explicit approval, because that changes what the hook permits in the working tree. Gate what becomes executable, not what gets written down.


## 🤖 Asymmetric Planning Protocol (AAPP) & Universal Skills
All planning and architectural tracking operates in the isolated `.plans/` worktree (on orphan branch `plans`), keeping design text decoupled from active code branches.

### 📋 Canonical Planning Invariant (AAPP Blueprints Over IDE Ephemeral Artifacts)
- **Universal Blueprint Standard**: When asked to plan, architect, or scaffold an implementation (in natural language or via `/plan` / `/aapp-plan`), the agent MUST NEVER generate internal IDE scratchpads (such as `implementation_plan.md` in IDE cache directories).
- **Two-Lane Routing**: Evaluate whether the request describes a bug in existing code (route to `.plans/ISSUES.md` first) or a new capability (scaffold in `.plans/current/`).
- **Single Source of Truth**: All implementation plans MUST be authored as canonical AAPP blueprints in `.plans/current/P<num>-<slug>.md` using `templates/plan-template.md` and registered in `.plans/state_matrix.md`.
- **Visible Artifact Standard**: Canonical planning always leaves a committed or staged file in `.plans/current/' that is visible in 'aapp status'.

Lifecycle verbs are authored as **Universal AAPP Skills** in `.agents/skills/` (`skills/<name>/SKILL.md`) and bridged to Claude Code (`.claude/skills/`). They are exposed as slash commands (`/aapp-status`, `/aapp-digest`, `/aapp-freeze`, `/aapp-done`, `/aapp-release`, `/aapp-active`, `/aapp-plan`, `/plan`) in Claude Code and indexed natively via progressive disclosure in Google Antigravity, Cursor, and OpenAI Codex.

The agent must support and execute these shorthand workflow triggers immediately without requiring manual prompt setup:

- **`status` (or `/aapp-status`, `/aapp:status`, `/aapp status`, `/status`)**: Act as a Context Recovery agent upon desk return.
  1. Inspect `CHANGELOG.md` (or `.plans/CHANGELOG.md`) to identify recently shipped code.
  2. **Issue lane:** Inspect `.plans/ISSUES.md` (or root `ISSUES.md`) and `.plans/issues_road_map.md` (the human's fix ordering over it). Report the top open issues **in the order the board gives them**.
  3. **Plan lane:** Inspect `.plans/state_matrix.md` (future implementations only) for active incubator plans, blockers, and greenlit tasks. Keep this separate from the issue lane in your briefing — never blend the two into one list.
  4. **Pickup queue:** Inspect `.plans/pickup.md` and **list the unprocessed ideas by name, with a count**. These are live and unworked — often the most valuable thing on the board when the user has just returned to the desk. Surface them so the user can pick one; do **not** digest them, and do not compress them away into a single "you have some notes" line.
  5. Print a concise, structured briefing across all **four pillars — Shipped, Issues, Plans, Pickup** — with immediate next actions. **Never omit a pillar**, even when it is empty: write `Pickup: empty` rather than silently dropping the section. Where the Pickup queue is non-empty, offer `/aapp-digest <idea>` on a named entry as a next action.

- **`digest <idea>` (or `/aapp-digest <idea>`, `/aapp:digest <idea>`, `/aapp digest <idea>`, `/digest <idea>`)**: Take **one** idea and work it toward a plan. This is a targeted operation — never a bulk sweep of `pickup.md`.

  **Step 1 — Resolve the idea.** `<idea>` may be raw text typed inline, or a reference to an entry in `.plans/pickup.md` (or a reference file in `.plans/pickup/`). If `<idea>` is omitted, list the open entries in `pickup.md` and **ask the user which one to digest**. Never choose for them, and never process the whole file at once.

  **Step 2 — Route it to a lane.** If the idea describes wrong behaviour in code that already ships, it is an issue: **claim its ID with `aapp issue allocate`, record it in `.plans/ISSUES.md` (or root `ISSUES.md`) and place it on `.plans/issues_road_map.md` first — always.** Then judge the size of the fix:
  - **Small / obvious fix** → stop there. The issue record is enough; no blueprint.
  - **Large fix** (several modules, needs a Blast Radius, real design decisions, spans sessions, or is a refactor) → **promote it and continue to Step 3.** Draft the blueprint, then state plainly that you promoted it and why. Do not stop to ask first — the draft is unfrozen and costs nothing. **Unless it is blocking work already in flight** — then stop and ask (see *Issue Escape Triage*).
  - **`<idea>` is itself an issue ID** (e.g. `digest ISSUE-004`) → the user has already chosen promotion. Go straight to Step 3 and carry the issue ID into the plan.

  (See *Promotion: an Issue may become a Plan*.)

  **Step 3 — Decide NEW or AMEND.** Scan `.plans/current/*.md` before writing anything:
  - **AMEND** — the idea refines, extends, or corrects a plan already in flight.
  - **NEW** — no active plan covers it.
  - If the match is ambiguous, **ask**. Never silently fold an idea into an unrelated blueprint. State which path you chose, and for AMEND name the plan you matched and why.

  **Step 4a — NEW plan (from scratch):**
  1. Cross-reference `.agents/CODEMAP.md` (or `CODEMAP.md`) and `ARCHITECTURE.md` so the design extends existing modules instead of adding duplicate helpers or wrappers.
  2. Run `aapp draft <slug>`: it claims the next Plan ID, scaffolds `.plans/current/P<num>-<slug>.md` from the template, registers it in the Incubator and commits it. Never allocate IDs or copy the template by hand.
  3. Fill in *Context & Architectural Goal*, *Technical Blueprint*, and *Implementation Steps & Execution Checklist*.
  4. Propose a Blast Radius. Mark it **PROPOSED** — it is not locked and confers no execution rights. Never declare files matching Guard Section 2 self-protection in Target Files (enforced by Pair 5).
  5. Write every unresolved decision into *Open Questions*. A first draft with no open questions is usually an under-examined draft.
  6. Commit the authored content with `aapp refine P-<num> "<what changed>"`.

  **Step 4b — AMEND an existing plan:**
  1. Fold the new detail into the section it belongs to — *Technical Blueprint*, *Implementation Steps*, *Open Questions*, or *Blast Radius*.
  2. Append a dated line to that plan's `## 📦 6. Change Log & Refinement History` recording what changed and why.
  3. **If the plan is already frozen / greenlit:** changing its Blast Radius changes what the pre-commit hook will permit. Stop and get explicit approval. Then set its Status to `📝 Refining` with §2/§4 untouched, commit that alone with `aapp refine`, make the change, and re-freeze.
  4. Commit it with `aapp refine <plan-id> "<what changed>"`; the state matrix re-derives itself.

  **Step 5 — Clean up.** Remove **only** the digested entry from `pickup.md`. Leave every other note in place.

  **Step 6 — Report.** State which path you took (NEW / AMEND / routed to `ISSUES.md`), name the file you wrote, and list the Open Questions the user must answer next.

  > **`digest` produces a draft, never a green light.** The output is an Incubator entry to be refined. Only `freeze` makes a plan executable.

### 🗺️ First-Run Repository Onboarding (Day 1 Experience)
When a repository is freshly initialized via `aapp init`, `.plans/pickup.md` contains an initial `Onboarding` queue item:
1. **Trigger**: The user runs `/aapp-status` (or `status`) and sees `Onboarding` in Pillar 4 (Pickup), then runs `/aapp-digest Onboarding`.
2. **Target Files**: The onboarding blueprint confines modifications strictly to `.agents/CODEMAP.md`, `ARCHITECTURE.md`, and `.agents/PROJECT.MD`.
3. **Execution**: The agent inspects the codebase (directory layout, build manifests, dependencies, primary entrypoints) and replaces generic template placeholders (`[Module 1: Name & Path]`, `[What the application does]`, `[Project Name]`) with actual module ownership, exported APIs, runtime rules, and active milestone tracks.
4. **Completion**: Running `/aapp-done <plan>` archives the blueprint and establishes the canonical codemap and architecture foundation for all subsequent agent work.

- **`freeze-start <plan>` (or `/aapp-freeze-start <plan>`, `aapp freeze-start <plan>`)**: The atomic workflow accelerator.
  1. Validates open questions (`[x]`) and explicit Target Files.
  2. Runs the Disjointness Activation Gate: verifies zero overlapping Target Files with other in-flight (`⚡ In Development`) blueprints in the same workspace.
  3. Transitions blueprint directly to `⚡ In Development`, sets the lock marker, updates the change log, and binds the local worktree buffer (`$(git rev-parse --git-path aapp_active_plan)`).
  4. Continuous Execution Ingress: Immediately greenlights code execution in the working tree. Do NOT pause to ask for redundant confirmation; immediately proceed to execute Section 3 of the blueprint.

- **`freeze <plan>` (or `/aapp-freeze <plan>`, `/aapp:freeze <plan>`, `/aapp freeze <plan>`, `/freeze <plan>`)**: Lock and greenlight a blueprint for the backlog.
  1. Resolve `<plan>` using shorthand resolution (Plan ID `P-9`, `9`, slug, or filename). Target must be explicitly named — empty queries are strictly refused.
  2. Scan `.plans/current/<plan>.md` to verify all Open Questions are resolved and Blast Radius (`Target Files` / `Out of Bounds`) is explicitly defined.
  3. Move the plan in `.plans/state_matrix.md` from the Incubator into `## 🔷 2b. Frozen Backlog (Approved Specifications)`.
  4. Locks the technical blueprint and blast radius into the backlog. (To begin implementation, run `aapp start <plan>` or use `aapp freeze-start <plan>`).

- **`start <plan>` (or `/aapp-start <plan>`, `aapp start <plan>`)**: Activate a frozen backlog blueprint into development.
  1. Verifies plan is in `🔷 Frozen` status.
  2. Runs the Disjointness Activation Gate against other in-flight plans.
  3. Transitions status to `⚡ In Development` and binds local worktree pointer buffer (`$(git rev-parse --git-path aapp_active_plan)`).
  4. Activates enforcement of the plan's locked Blast Radius for tool writes and commits.
  5. Continuous Execution Ingress: Do NOT pause to ask for redundant confirmation. Immediately proceed to execute Section 3 of the blueprint (verifying / authoring failure tests first if TDD sections are declared).

- **`plan <idea>` (or `/plan <idea>`, `/aapp-plan <idea>`)**: Canonical blueprint planning and lane routing.
  1. Enforces the Canonical Planning Invariant: author blueprints in `.plans/current/P<num>-<slug>.md`, never in ephemeral IDE scratchpads (`implementation_plan.md`).
  2. Routes defects to `.plans/ISSUES.md` first; features and refactors to `.plans/current/`.
  3. Scaffolds using `templates/plan-template.md` and registers in `.plans/state_matrix.md`.
  4. In the shell: bare `aapp plan` acts as an educational switchboard; `aapp plan-status [id]` acts as the deterministic read-only inspector.

- **`active [plan-id]` (or `/aapp-active`, `aapp active`, `aapp active swap`, `aapp active clear`)**: Manage local worktree active execution buffer (`$(git rev-parse --git-path aapp_active_plan)`).
  1. `aapp active <id>`: Set active plan buffer to `<id>` (stashing previous in `.prev`).
  2. `aapp active`: Display currently designated active plan, status, and declared Target Files.
  3. `aapp active swap`: Toggle between current and previous active plan buffer.
  4. `aapp active clear`: Clear active buffer, reverting to auto-discovery mode.

- **`done <plan>` (or `/aapp-done <plan>`, `/aapp:done <plan>`, `/aapp done <plan>`, `/done <plan>`)**: Complete lifecycle and archive implemented blueprint.
  1. Resolve `<plan>` using shorthand resolution (Plan ID `P-9`, `9`, slug, or filename). Target must be explicitly named — empty queries are strictly refused.
  2. Move the plan file: `mv .plans/current/<plan>.md .plans/done/<plan>.md`.
  3. Rewrite the blueprint header status line to `* **Status:** ✅ Done` and append an archival completion line to `## 📦 6. Change Log`.
  4. Clear or update active plan buffer if it matched the completed plan.
  5. Append a 1-line completion record to `.plans/done/000-archive-ledger.md` with `Plan ID`, plan file link, target issue, verification commit, and repo-relative impact summary.
  6. Remove the plan entry from `.plans/state_matrix.md` (keeping `state_matrix.md` strictly focused on active roadmap & incubator items). If the plan resolved a target issue, `aapp done` relocates it from `ISSUES.md` to `.plans/done/000-issues-archive.md` and prunes `issues_road_map.md` (Relocation Invariant); a Target Issue in neither ledger refuses `done`.
  7. Commit the transition to the `plans` worktree.

- **`release <version>` (or `/aapp-release <version>`, `/aapp:release <version>`, `/aapp release <version>`, `/release <version>`, `/preflight`)**: Execute release pre-flight verification runbook.
  1. Inspect `.plans/release/release_checklist.md` (the canonical release runbook for the project).
  2. Enforce the Stable vs. Edge convention (Section 0 of checklist): `main` is strictly STABLE (clean tag `vX.Y.Z`), `develop` is EDGE (`-dev`). `develop` must fast-forward cleanly into `main` before tagging.
  3. Step through the defined test suites, linters, and security audit checks.
  4. Verify `CHANGELOG.md` (or `.plans/CHANGELOG.md`) has version entries staged and ready for tagging.
  5. Report a structured release posture assessment (Tests, Linters, Docs, Rollback readiness) to the user.

- **`pause [reason]` (or `/aapp-pause [reason]`, `aapp pause [reason]`, `aapp pause shared [reason]`)**: Engage the Master Emergency Brake & Multi-Worktree State Preserver ("Hibernate & Wake").
  1. Idempotently inspects active pause state if already paused.
  2. Runs In-Flight Operation Guard across all worktrees (`git worktree list --porcelain`), verifying zero active merges, rebases, or cherry-picks via canonical gitdir plumbing (`git rev-parse --git-path MERGE_HEAD`, `rebase-merge`, `CHERRY_PICK_HEAD`).
  3. Quarantines uncommitted in-flight code per-worktree into SHA-addressed stashes (`aapp-pause-<timestamp>:<branch>`) using `--include-untracked` (strictly forbidding `--all` to respect `.gitignore` air-gaps).
  4. Enforces the Atomic Rollback Invariant: validates 40-character hexadecimal commit SHAs; rolls back all stashes if any worktree fails.
  5. Engages Circuit Breaker: locks all codebase and control-plane (`.agents/*`) writes and commits across worktrees while keeping reflection strictly within `.plans/` (pickup, issues, current) operational.

- **`resume` (or `/aapp-pause resume`, `aapp resume`, `aapp unpause`)**: Disengage the emergency brake and wake workspace.
  1. Detects forensic drift by comparing current HEAD SHAs against the pause snapshot (reporting foreign commits without auto-rebasing).
  2. Restores quarantined stashes safely by 40-character commit SHA (never fragile indices).
  3. Enforces the Pause Buffer Survival & No-Loss Conflict Invariant: on conflict, the stash entry is permanently preserved in `git stash list` and the project remains PAUSED until resolved.
  4. Runs planning health integrity checks, deactivates pause buffer, and restores full developer velocity.

---

## 🧰 CLI Reference
Every chore has a verb; use it instead of editing ledgers or running git on `.plans` by hand. **Never run raw `git` in the plans worktree**: lifecycle verbs commit their own changes, and plan edits are committed with `aapp refine`.

| Verb | Purpose |
| :--- | :--- |
| `aapp status [short]` | Four-pillar briefing (Shipped, Issues, Plans, Pickup) |
| `aapp draft <slug>` | Claim a Plan ID, scaffold the blueprint, register and commit it |
| `aapp refine <id> "<what changed>"` | Commit an edit to an active plan |
| `aapp refine <id> blocked <num>` | Block a plan on active issue `#<num>` (then `aapp matrix`) |
| `aapp tdd <id>` | Inject failure-test sections into a plan before freeze |
| `aapp plan [query]` | Planning switchboard |
| `aapp plan-status [id]` | Read-only plan matrix or one plan's details |
| `aapp matrix [check]` | Re-derive (or audit) `state_matrix.md` from plan Status lines |
| `aapp freeze <id>` | Lock design and Blast Radius |
| `aapp start <id>` | Activate a frozen plan for implementation |
| `aapp freeze-start <id>` | Freeze and start in one step |
| `aapp done <id>` | Archive an implemented plan; closes its Target Issue |
| `aapp commit "<msg>" …` | Plan-bound code commit with attribution; records the SHA in the plan and writes its declared changelog entry |
| `aapp active [id \| swap \| clear]` | Show or set the active plan buffer |
| `aapp note …` | Stage, inspect, push or pull git notes |
| `aapp issue [next \| allocate \| close <num> \| list]` | Claim, close and list issue IDs |
| `aapp test …` | Run the kit's test suites |
| `aapp ai …` | Inspect or switch the attribution mode |

Full catalog: `aapp help`. A verb's complete contract (arguments, refusals, effects): `aapp help <verb>`.

---

## 🛑 Master Emergency Brake & Hibernate/Wake Protocol ("Hibernate & Wake")
When switching focus across projects, stepping away from the desk, or preventing accidental cross-window collisions:
- **Zero Daily Friction**: Zero overhead during normal active development.
- **Dynamic Multi-Worktree Stash Quarantine**: In-flight code across all mounted worktrees (`git worktree list --porcelain`) is quarantined into named, SHA-addressed stashes (`aapp-pause-<timestamp>:<branch>`), leaving all working trees clean.
- **State Buffer Scope**: Defaults to `$(git rev-parse --git-common-dir)/aapp_paused` (uncommitted, shared across all linked worktrees). Optional `shared` commits `.plans/PAUSED.md` for remote team freeze.
- **Cross-Medium Hook Realism ("Uncommittable, Not Untouchable")**: For sessions rooted in this repository, Layer 1 (`blast-radius-guard`) intercepts write tools before disk touches. For external or companion chat sessions rooted elsewhere, Layer 2 (`pre-commit`) serves as the strict, inescapable gate that rejects any commit touching codebase files.
- **Permitted Paths While Paused**: Only `.plans/` reflections (`pickup*`, `ISSUES.md`, `issues*`, `current/*`) are permitted. All writes to codebase files, `.agents/*` control plane, templates, or hooks are strictly blocked.
- **Emergency Escape Hatches**: `SKIP_BLAST_RADIUS=1` bypasses Layer 1 and Layer 2; `git commit --no-verify` bypasses Layer 2. Stashes are recoverable manually via `git stash list` and `git stash apply <sha>`.

---

## 🐛 Issue Escape Triage (Mid-Execution Bugs)
If you discover an unexpected bug while executing a plan inside a locked Blast Radius, **claim its ID with `aapp issue allocate` and record it in `.plans/ISSUES.md` (or root `ISSUES.md`) first — always** — then take one of three paths:

- **Non-blocking:** Do not fix it. Continue the assigned plan. Do not add it to `state_matrix.md`, and do not re-prioritize `issues_road_map.md` on your own — append it and let the human place it.

- **Blocking & small:** The bug halts the plan but the fix is contained. Pause, expand the plan's Blast Radius under an `### 🚨 Emergency Hotfix Extensions` subsection with a one-sentence justification, fix the blocker, log the hotfix, and resume.

- **Blocking & substantial:** The bug halts the plan *and* the fix is real work — several modules, a Blast Radius of its own, or genuine design decisions.
  **STOP. Do not fast-forward a design, and do not promote it on your own.** This is the one place promotion is never automatic.
  1. Block the in-flight plan with one command: `aapp refine <plan-id> blocked <num> && aapp matrix`. It sets the Status to `🟥 BLOCKED`, records `* **Blocked On:** #<num>` (with the status it had before), commits the plan, and the matrix re-derives. Never hand-edit the Status line or `state_matrix.md`. **A blocked plan is not executable** — and the pre-commit hook enforces it: while the Status line says `BLOCKED`, that plan admits no commits at all.
  2. Report the situation and **ask** whether to promote the issue into its own plan. Lay out what you know — scope, modules touched, the options you can see — as **open questions, not decisions already taken**.
  3. Wait. Resume only when the human unblocks: the issue is fixed, the blocked plan is re-scoped around it, or they explicitly say to continue.

> **Why this one asks, when promotion normally does not.** Everywhere else drafting is free, because a draft sits harmlessly *beside* your work. A blocking bug is different: the human's actual plan is stalled, so anything you fast-forward arrives while they are under pressure to accept it just to get moving again. That is the worst possible moment to hand someone a finished design and a set of decisions already made. Substantial blocking work is the human's call, made unhurried.

---

## 🧹 Token Efficiency, Prerequisite Resolution & Archival Scoping
- **Active Focus Only:** When inspecting `.plans/state_matrix.md`, focus strictly on active sections (`Roadmap`, `1. The Incubator`, and `2. The Greenlight Zone`).
- **Archival Authoritative Invariant (Ledger is Terminal):** Any plan listed in `.plans/done/000-archive-ledger.md` or residing in `.plans/done/` is definitively **COMPLETE and SHIPPED**. When evaluating prerequisites, dependencies, or prior art:
  1. Presence in `000-archive-ledger.md` or `.plans/done/` is terminal proof of completion.
  2. Agents MUST NOT re-verify, re-read, or second-guess an archived plan's implementation status.
  3. If an archived blueprint file is opened for architectural context, its `* **Status:** ✅ Done` header is final.
- **Ignore Archived History:** Strictly ignore `.plans/done/` and `.plans/done/000-archive-ledger.md` during normal working loops unless resolving an explicit prerequisite, auditing historical context, or directly requested by the user.

---

## 📂 Project Context
Refer to `.agents/PROJECT.MD` for specific sub-agent behavior profiles and task queues.

<!-- AAPP-PROTOCOL:END -->
