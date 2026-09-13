# 🗺️ Plan: Universal AAPP Skills & Slash Commands (`.agents/skills/` & `.claude/skills/`)
* **Created:** 2026-09-10 | **Last Refined:** 2026-09-13
* **Target Issue / Milestone:** `ISSUE-061`
* **Status:** 🔴 Under Review

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Every commit you make must include your co-author trailer.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.

> ### 🔒 Execution Note: `.githooks/` is write-protected
> `blast-radius-guard` hard-blocks every write to `.githooks/*` (self-protection). The engine copy is therefore **never edited directly**. Edit `templates/blast-radius-guard.sh` and run `aapp init` to propagate it into `.githooks/blast-radius-guard`. The same applies to `.agents/AGENTS.md`, which is regenerated from `templates/AGENTS.md` by the delimited-block sync.

---

## 1. Context & Architectural Goal

`README.md:241-245` presents `/status`, `/digest`, `/freeze`, `/done` and `/release` as slash commands, but they previously existed **only as prose** inside `templates/AGENTS.md`. In active agent sessions (Claude Code, Antigravity, Cursor) they resolve to unknown commands or require reading a ~20 KB `AGENTS.md` into full conversational context — which does *not* happen on a cold start, in subagents, or upon fresh repository adoption.

**Goal:** Ship the five lifecycle verbs as **Universal AAPP Skills** (`skills/<name>/SKILL.md`) natively housed within the orphan `agents` worktree (`.agents/skills/`) and bridged to Claude Code (`.claude/skills/`). This ensures cross-agent interoperability (Antigravity, Claude Code, Cursor), eliminates prompt context pollution through progressive disclosure, and enables isolated subagent execution.

### Architectural Advantages of Universal Skills over Flat Commands:
1. **Multi-Agent Interoperability**:
   - **Google Antigravity** natively discovers workspace skills in `.agents/skills/<name>/SKILL.md` via progressive disclosure.
   - **Claude Code** natively discovers `.claude/skills/<name>/SKILL.md` and exposes them as slash commands (e.g. `/aapp:status`, `/aapp:digest`).
   - Standardizes on the open `SKILL.md` format with YAML frontmatter across AI pair-programming tools.
2. **Decoupled Worktree Alignment**:
   - Canonical skill files live in the orphan `agents` worktree (`.agents/skills/`), never polluting the application code branch or commit history.
   - `aapp init` wires Claude Code compatibility via `.claude/skills` (symlink or directory mirror).
3. **Progressive Disclosure & Token Economics**:
   - Instead of injecting 20 KB of `AGENTS.md` on every turn, agents only register ~100 tokens of skill names and 1-line descriptions. Full procedure text is loaded on-demand *only* when the skill or slash command is triggered.
4. **Execution Isolation (`context: fork`)**:
   - Intensive workflows like `/aapp:digest` (codebase research and blueprint scaffolding) or `/aapp:release` (running full test suites and linters) run in an isolated fork or subagent context, reporting only clean summaries back to the primary chat.
5. **Deterministic Tool Execution**:
   - Eliminates brittle pre-render `` !`aapp status` `` macro injections that crash Claude sessions on missing binaries or permission checks. The agent inspects `aapp status` via standard tool execution or falls back gracefully to reading the four pillar markdown files directly.

---

## 2. Technical Blueprint

### 2.1 Skill Hierarchy & Namespace

Each lifecycle verb is authored as an isolated skill directory:
```text
templates/skills/
├── aapp-status/
│   └── SKILL.md
├── aapp-digest/
│   └── SKILL.md
├── aapp-freeze/
│   └── SKILL.md
├── aapp-done/
│   └── SKILL.md
└── aapp-release/
    └── SKILL.md
```

When `aapp init` executes:
1. Installs canonical skills into `.agents/skills/aapp-*/SKILL.md`.
2. Creates `.claude/skills/` as a symlink to `../.agents/skills` (with POSIX directory mirror fallback where symlinks are unsupported).
3. In Claude Code, this generates slash commands `/aapp:status` (or `/aapp-status`), `/aapp:digest`, `/aapp:freeze`, `/aapp:done`, and `/aapp:release`.
4. In Antigravity, the skills are immediately indexed and available via progressive disclosure and slash command triggers.

### 2.2 Sync Semantics — Engine Files, Not User Templates

| Class | Existing example | Sync verb | Applies here |
| :--- | :--- | :--- | :--- |
| User-owned scaffold | `pickup.md`, `ISSUES.md` | `copy_guarded` (create if absent) | ✗ |
| AAPP-owned engine | `aapp-pre-commit`, `blast-radius-guard` | `cp` / symlink byte-for-byte every init | ✓ |

The skill files encode core protocol behaviour that must stay in lockstep with the installed `AAPP` release. A new `sync_skills()` helper in `lib/cmd_init.sh` manages `.agents/skills/` and wires `.claude/skills/`. User skills elsewhere in `.agents/skills/` or `.claude/skills/` (not starting with `aapp-`) are strictly preserved.

### 2.3 Anatomy of an AAPP `SKILL.md` File

```markdown
---
name: aapp-status
description: Act as a Context Recovery agent upon desk return. Scan the four pillars (Shipped, Issues, Plans, Pickup) and report a concise structured briefing.
disable-model-invocation: false
context: inline
argument-hint: ""
---

# AAPP Status (Context Recovery)

Execute the 5-step four-pillar context recovery procedure...
```

* **Frontmatter Contract**:
  - `name`: `aapp-status`, `aapp-digest`, `aapp-freeze`, `aapp-done`, `aapp-release`.
  - `description`: Crisp 1-sentence explanation used by agent skill catalogs for progressive disclosure.
  - `disable-model-invocation: true` on `freeze`, `done`, and `release`: Critical state transitions (granting commit rights, archiving plans, running releases) must be human-initiated. `status` and `digest` remain model-invocable.
  - `context: fork` on `digest` and `release`: Heavy research and test runs execute in an isolated subagent/fork context. `status`, `freeze`, and `done` remain `context: inline`.
* **Zero-Crash Execution Logic (No Brittle Macros)**:
  - `status` instructs the agent to run `./aapp status` if available. If absent or unpermitted, the agent directly inspects the four pillar files (`CHANGELOG.md`, `ISSUES.md` / `issues_road_map.md`, `state_matrix.md`, `pickup.md`) without ever failing or aborting the session.
* **Canonical Pointer**:
  - Each skill references the canonical specification in `.agents/AGENTS.md` for deep edge-case resolution.

### 2.4 Drift Control

`templates/AGENTS.md` remains canonical protocol prose; the skill files are the executable procedures. A new assertion block in `tests/install_test.sh` verifies, for each of the five verbs, that:
1. `SKILL.md` exists and contains valid YAML frontmatter (`name`, `description`).
2. Mandatory invariant markers (`state_matrix.md`, `000-archive-ledger.md`, `release_checklist.md`) are present.
3. Frontmatter fields match expected safety flags (`disable-model-invocation: true` for freeze/done/release).

### 2.5 Self-Protection & Blast Radius Guard

An agent must not be able to tamper with its own governance skills. `templates/blast-radius-guard.sh` expands its self-protection `case` to include:
- `.agents/skills/aapp-*`
- `.claude/skills/aapp-*`
Project-specific skills (e.g. `.agents/skills/deploy/`) remain freely writable by agents.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Author the Universal Skill Templates
- [ ] Task 1.1: Create `templates/skills/aapp-status/SKILL.md` — frontmatter (`name: aapp-status`, `description`, `context: inline`), 5-step four-pillar briefing contract with deterministic fallback file reading.
- [ ] Task 1.2: Create `templates/skills/aapp-digest/SKILL.md` — frontmatter (`name: aapp-digest`, `context: fork`, `argument-hint: [idea or ISSUE-ID]`), 6-step routing procedure (resolve → route to lane → NEW/AMEND → scaffold → clean pickup → report).
- [ ] Task 1.3: Create `templates/skills/aapp-freeze/SKILL.md` — frontmatter (`name: aapp-freeze`, `disable-model-invocation: true`, `argument-hint: [plan-name]`), 3-step boundary verification and greenlight lock procedure.
- [ ] Task 1.4: Create `templates/skills/aapp-done/SKILL.md` — frontmatter (`name: aapp-done`, `disable-model-invocation: true`, `argument-hint: [plan-name]`), 4-step archive procedure (move → ledger append → state matrix prune → worktree commit).
- [ ] Task 1.5: Create `templates/skills/aapp-release/SKILL.md` — frontmatter (`name: aapp-release`, `disable-model-invocation: true`, `context: fork`, `argument-hint: [version]`), 5-step preflight verification runbook against `.plans/release/release_checklist.md`.

### Phase 2: Wire Skill Sync & Claude Bridge into `aapp init`
- [ ] Task 2.1: Implement `sync_skills()` in `lib/cmd_init.sh` to copy `templates/skills/aapp-*` into `.agents/skills/` and create symlink/bridge `.claude/skills`.
- [ ] Task 2.2: Call `sync_skills()` during `aapp init` (Phase 5) and update the completion banner with `➡️  Universal Skills: .agents/skills/ (bridged to .claude/skills/)`.
- [ ] Task 2.3: Add `.agents/skills/aapp-*` and `.claude/skills/aapp-*` to self-protection in `templates/blast-radius-guard.sh` and sync to `.githooks/blast-radius-guard`.
- [ ] Task 2.4: Update `templates/AGENTS.md` to document the Universal Skills and `/aapp:` slash command triggers.

### Phase 3: Automated Verification & Documentation
- [ ] Task 3.1: Extend `tests/install_test.sh` — verify skill installation in `.agents/skills/`, `.claude/skills/` bridge creation, preservation of non-AAPP custom skills, and byte-for-byte upgrade overwrites.
- [ ] Task 3.2: Extend `tests/write-guard_test.sh` — verify self-protection denies edits to `.agents/skills/aapp-freeze/SKILL.md` and `.claude/skills/aapp-freeze/SKILL.md` while permitting user skills.
- [ ] Task 3.3: Add drift assertions in `tests/install_test.sh` verifying all five skills declare valid frontmatter and match `AGENTS.md` invariants.
- [ ] Task 3.4: Update `README.md` and `MANUAL.md` documentation covering Universal Skills and multi-agent IDE integration.
- [ ] Task 3.5: Run full test suite (`install_test.sh`, `pre-commit_test.sh`, `write-guard_test.sh`) to ensure 100% pass rate.
- [ ] Task 3.6: Update `CHANGELOG.md` under `## [Unreleased]`.

---

## 💥 4. Blast Radius & System Boundaries
*(Marked: **PROPOSED** — incubator draft)*

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `templates/skills/aapp-status/SKILL.md` -> Four-pillar context recovery skill.
- [ ] `NEW FILE` -> `templates/skills/aapp-digest/SKILL.md` -> Idea/issue routing and blueprint scaffolding skill.
- [ ] `NEW FILE` -> `templates/skills/aapp-freeze/SKILL.md` -> Blast Radius lock and greenlight skill.
- [ ] `NEW FILE` -> `templates/skills/aapp-done/SKILL.md` -> Archival lifecycle and ledger append skill.
- [ ] `NEW FILE` -> `templates/skills/aapp-release/SKILL.md` -> Release preflight runbook skill.
- [ ] `lib/cmd_init.sh` -> Add `sync_skills()`, wire into initialization flow, update completion banner.
- [ ] `templates/blast-radius-guard.sh` -> Add `.agents/skills/aapp-*` and `.claude/skills/aapp-*` to self-protection.
- [ ] `templates/AGENTS.md` -> Document Universal Skills and `/aapp:` slash command triggers.
- [ ] `tests/install_test.sh` -> Skill sync, symlink bridge, upgrade, and drift assertions.
- [ ] `tests/write-guard_test.sh` -> Self-protection assertions for AAPP skill namespace.
- [ ] `README.md` -> Document Universal Skills, slash command table, and updated test counts.
- [ ] `MANUAL.md` -> Multi-agent skills reference section.
- [ ] `templates/architecture.md` -> Add `.agents/skills/` to the structural architecture tree.
- [ ] `ARCHITECTURE.md` -> Mirror structural tree update.
- [ ] `CHANGELOG.md` -> Unreleased entry citing ISSUE-061.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/` -> Write-protected engine copies; regenerate via `aapp init`, never edit.
- [ ] `.agents/AGENTS.md` -> Generated from `templates/AGENTS.md` by delimited-block sync.
- [ ] `lib/cmd_upgrade.sh` -> Distribution fixes belong to ISSUE-049, not this plan.
- [ ] `lib/cmd_install.sh` -> Self-consumption fixes belong to ISSUE-051, not this plan.
- [ ] `templates/aapp-pre-commit` -> Commit-time enforcement is unchanged by this work.
- [ ] `aapp` -> No dispatcher verb is added; these are agent skills, not CLI subcommands.

---

## ❓ 5. Open Questions (Optional / Gate)

* [x] **Question 1 — Namespace (Resolved 2026-09-10):** **Adopt the `aapp` command family namespace.** Formally namespace all lifecycle commands as `/aapp:<verb>` (e.g. `/aapp:status`, `/aapp:digest`, `/aapp:freeze`, `/aapp:done`, `/aapp:release`, `/aapp:sync`) with `/aapp <verb>` dispatcher alias support.
* [x] **Question 2 — Commands vs. Skills (Resolved 2026-09-13):** **Adopt Universal AAPP Skills (`.agents/skills/`).** Pivoted from Claude-only flat commands (`.claude/commands/`) to cross-agent `SKILL.md` files housed in `.agents/skills/` and bridged to Claude Code (`.claude/skills/`). Provides native discovery in Google Antigravity and Claude Code, progressive disclosure, and context forking.
* [x] **Question 3 — Tool & Status Coupling (Resolved 2026-09-13):** **Standard Tool Execution with Direct Markdown Fallback.** Replaced brittle pre-render `` !`aapp status` `` macro with normal agent execution (`./aapp status`) and direct fallback to reading the 4 pillar files (`CHANGELOG.md`, `ISSUES.md` + `issues_road_map.md`, `state_matrix.md`, `pickup.md`). Guarantees the session never aborts on missing binaries or strict tool permissions.

---

## 📦 6. Change Log & Refinement History
* **2026-09-13:** Pivoted from Claude-only flat commands (`.claude/commands/`) to Universal AAPP Skills (`.agents/skills/` with `.claude/skills/` bridge) per human decision (Option 1). Resolved Open Questions 2 and 3; updated blueprint, sync architecture, and execution tasks.
* **2026-09-10:** User confirmed `aapp` command family namespace (`/aapp:<verb>` and `/aapp <verb>`) to eliminate cross-environment collisions across Antigravity CLI and Claude Code; marked Open Question 1 resolved.
* **2026-09-10:** Verified `!` injection semantics: execution is pre-render and non-discretionary, a non-zero exit aborts the whole invocation, and a non-`allow` permission check does the same. Hardened §2.3, Task 3.4 and Open Question 3 accordingly.
* **2026-09-10:** Verified against the slash-command spec that no command-to-command delegation exists and that shadowing a built-in is total; recorded in Open Question 1.
* **2026-09-10:** Plan initialized from `ISSUE-061` (2026-09-10 audit sweep). Namespace, engine-sync semantics, self-protection scope and drift-test strategy specified; three open questions raised for human decision.
