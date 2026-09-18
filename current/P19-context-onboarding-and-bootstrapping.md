# 🗺️ Plan P-19: Dedicated Onboarding CLI Command & Self-Cleaning Context Bootstrapping
* **Created:** 2026-09-18 | **Last Refined:** 2026-09-18
* **Target Issue / Milestone:** None
* **Plan ID:** P-19
* **Status:** 🟡 Refining
<!-- Status must be exactly ONE of: 🔴 Under Review | 🟡 Refining | 🟢 Frozen | 🟠 In Development | 🚫 BLOCKED
     The pre-commit hook and write-guard read this line. A 🟢 Frozen plan is an approved backlog
     specification. An 🟠 In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.
> 5. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.

---

## 1. Context & Architectural Goal

When AAPP is adopted into an existing repository or newly initialized, starter templates are provisioned from generic skeletons:
- `.agents/CODEMAP.md` (from `templates/codemap.md`)
- `ARCHITECTURE.md` (from `templates/architecture.md`)
- `.agents/PROJECT.MD` (from `templates/PROJECT.MD`)
- `.plans/pickup.md` (from `templates/pickup.md`)

Currently, AAPP does not notify the user with an actionable prompt sequence, does not instruct the agent on how to map the project, and provides no mechanism to clean up initial scaffolding comments once the files are populated. 

This plan introduces:
1. A dedicated `aapp onboard` command that analyzes context file status and displays a tailored, copy-pasteable prompt sequence for AI agents (Claude Code, Antigravity, Cursor).
2. Delimited, self-consuming instruction blocks (`<!-- AAPP-BOOTSTRAP:START -->...<!-- AAPP-BOOTSTRAP:END -->`) embedded in the starter templates.
3. An automated mechanical removal tool (`aapp onboard --clean`) that strips these instruction markers, validates that template placeholders were replaced, and cleans the initial onboarding item from `.plans/pickup.md`.
4. Protocol and documentation updates ensuring agents proactively discover unpopulated templates and know how to clean them up.

---

## 2. Technical Blueprint

### A. CLI Command Architecture (`lib/cmd_onboard.sh` & `aapp`)

`aapp` dispatches `onboard` to `lib/cmd_onboard.sh`. The command supports two operational modes:

#### 1. Inspection & Prompt Mode: `aapp onboard` (default)
- **Context Detection**: Resolves repository root and locates `.agents/CODEMAP.md`, `ARCHITECTURE.md`, and `.agents/PROJECT.MD` (with legacy root fallbacks).
- **Status Audit**:
  - Checks each file for the presence of `<!-- AAPP-BOOTSTRAP:START -->` markers.
  - Checks for unpopulated generic placeholders:
    - `CODEMAP.md`: `[Module 1: Name & Path]`, `src/.../`
    - `ARCHITECTURE.md`: `[What the application does]`, `[e.g. Perl 5.34+`
    - `PROJECT.MD`: `[Project Name]`
  - Prints a status overview:
    - `⚠️  PENDING: .agents/CODEMAP.md (unpopulated template)`
    - `✅  POPULATED: ARCHITECTURE.md`
- **Agent Prompt Sequence**:
  If any file is pending onboarding, renders an actionable prompt sequence enclosed in a distinct terminal box:
  ```text
  📋 Copy-paste this prompt sequence to your AI agent (Claude Code, Antigravity, Cursor):
  ────────────────────────────────────────────────────────────────────────────────
  Please inspect this repository's codebase, directory layout, dependencies, and entrypoints:
  1. Populate .agents/CODEMAP.md with core modules, exported APIs, and anti-wrapper invariants.
  2. Populate ARCHITECTURE.md with technology stack runtime, architectural patterns, and directory map.
  3. Populate .agents/PROJECT.MD with active milestone tracks and near-term task queues.

  When finished, run 'aapp onboard --clean' or remove the <!-- AAPP-BOOTSTRAP --> blocks.
  ────────────────────────────────────────────────────────────────────────────────
  ```
- If all files are already clean and populated:
  Prints `✨ Repository context is fully onboarded! All architecture documents are populated.`

#### 2. Cleanup & Verification Mode: `aapp onboard --clean` (or `-c`)
- **Block Stripping**: Uses POSIX `sed` to excise `<!-- AAPP-BOOTSTRAP:START -->` through `<!-- AAPP-BOOTSTRAP:END -->` from `.agents/CODEMAP.md`, `ARCHITECTURE.md`, and `.agents/PROJECT.MD`.
- **Placeholder Inspection**: Warns if placeholder tokens (e.g. `[Module 1:`) remain in the stripped files.
- **Queue Pruning**: If `.plans/pickup.md` contains the initial `Onboard Project Context` item, removes that line using POSIX regex pruning.
- **Worktree Sync**: If the current repo has git worktrees, commits or stages clean updates without dirtying the source code branch.
- **Completion Notice**: Emits clear confirmation: `🧹 Stripped bootstrap instructions and verified repository context.`

---

### B. Starter Template Delimiters (`templates/`)

Embed a standardized delimiter in each starter template:

#### 1. `templates/codemap.md`
```markdown
<!-- AAPP-BOOTSTRAP:START
🤖 AGENT ONBOARDING INSTRUCTIONS:
1. Scan repository files and directories to identify core architectural modules and entrypoints.
2. Replace all template placeholders below with real module paths, functions, and anti-wrapper rules.
3. Once populated, remove this comment block or run 'aapp onboard --clean'.
AAPP-BOOTSTRAP:END -->
```

#### 2. `templates/architecture.md`
```markdown
<!-- AAPP-BOOTSTRAP:START
🤖 AGENT ONBOARDING INSTRUCTIONS:
1. Identify primary runtime, languages, frameworks, and external dependencies from manifests.
2. Document architectural principles, system topology, and global directory layout.
3. Once populated, remove this comment block or run 'aapp onboard --clean'.
AAPP-BOOTSTRAP:END -->
```

#### 3. `templates/PROJECT.MD`
```markdown
<!-- AAPP-BOOTSTRAP:START
🤖 AGENT ONBOARDING INSTRUCTIONS:
1. Review existing issues, git log history, and documentation to identify current milestone state.
2. Outline active phase goals, immediate task batches, and long-term roadmap.
3. Once populated, remove this comment block or run 'aapp onboard --clean'.
AAPP-BOOTSTRAP:END -->
```

#### 4. `templates/pickup.md`
Pre-seed with initial onboarding task:
```markdown
## 🆕 New Ideas / Prompt Inputs
- [ ] Onboard Project Context: Run 'aapp onboard' and map codebase into .agents/CODEMAP.md, ARCHITECTURE.md, and .agents/PROJECT.MD
```

---

### C. Initialization & Help Integration

- `lib/cmd_init.sh`: In Phase 7 completion banner, output:
  ```text
  🚀 Next Step — Bootstrap Project Context:
     Run 'aapp onboard' to get the agent bootstrapping prompt sequence.
  ```
- `lib/cmd_help.sh`: Document `aapp onboard [--clean]` in command catalog under Core Commands.
- `templates/AGENTS.md`: Add a rule in the protocol block instructing agents on the onboarding protocol.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Engine Implementation
- [ ] Task 1.1: Create `lib/cmd_onboard.sh` implementing status detection, prompt formatting, and `--clean` marker stripping.
- [ ] Task 1.2: Dispatch `onboard` in `aapp` and add help entries in `lib/cmd_help.sh`.
- [ ] Task 1.3: Update `lib/cmd_init.sh` post-init banner to suggest `aapp onboard`.

### Phase 2: Templates & Governance Synchronization
- [ ] Task 2.1: Add delimited bootstrap blocks to `templates/codemap.md`, `templates/architecture.md`, and `templates/PROJECT.MD`.
- [ ] Task 2.2: Add onboarding pickup item to `templates/pickup.md`.
- [ ] Task 2.3: Update `templates/AGENTS.md` and `.agents/AGENTS.md` to document the context onboarding protocol.

### Phase 3: Documentation & Verification
- [ ] Task 3.1: Update `MANUAL.md` and `CHEATSHEET.md` with `aapp onboard` reference and workflow instructions.
- [ ] Task 3.2: Add automated test cases in `tests/install_test.sh` covering `aapp onboard` and `aapp onboard --clean`.
- [ ] Task 3.3: Run full test verification suite (`install_test.sh`, `pre-commit_test.sh`, `write-guard_test.sh`, `plan_resolver_test.sh`, `ai_attribution_test.sh`, `planning_health.sh`).
- [ ] Task 3.4: Update `CHANGELOG.md` under `## [Unreleased]`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_onboard.sh` -> New implementation for the aapp onboard command engine.
- [ ] `aapp` -> Add onboard command dispatcher route.
- [ ] `lib/cmd_help.sh` -> Add aapp onboard to CLI help catalog.
- [ ] `lib/cmd_init.sh` -> Add aapp onboard next-step recommendation to init banner.
- [ ] `templates/codemap.md` -> Add delimited bootstrap instruction block.
- [ ] `templates/architecture.md` -> Add delimited bootstrap instruction block.
- [ ] `templates/PROJECT.MD` -> Add delimited bootstrap instruction block.
- [ ] `templates/pickup.md` -> Seed initial project context onboarding queue item.
- [ ] `templates/AGENTS.md` -> Document onboarding protocol in agent rules template.
- [ ] `MANUAL.md` -> Document aapp onboard command and bootstrap cleanup workflow.
- [ ] `CHEATSHEET.md` -> Add aapp onboard to command cheat sheet.
- [ ] `tests/install_test.sh` -> Add regression test coverage for aapp onboard and --clean.
- [ ] `CHANGELOG.md` -> Record feature release notes.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Hook engine is not affected; do not edit directly.
- [ ] `.agents/skills/aapp-*` -> Universal skills contracts remain unchanged.
- [ ] `lib/plan_resolver.sh` -> Plan resolution engine is out of scope.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified based on user selection of dedicated CLI onboarding command with prompt sequence and mechanical instruction cleanup).*

---

## 📦 6. Change Log & Refinement History
* **2026-09-18:** Plan drafted in `.plans/current/P19-context-onboarding-and-bootstrapping.md` following discussion on adoption template onboarding gap.
