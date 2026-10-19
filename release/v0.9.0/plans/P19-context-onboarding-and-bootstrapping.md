# 🗺️ Plan P-19: First-Run Onboarding Loop & Context Alignment via Pickup Queue
* **Created:** 2026-09-18 | **Last Refined:** 2026-09-18
* **Target Issue / Milestone:** None
* **Plan ID:** P-19
* **Status:** ✅ Done
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

When AAPP is adopted into an existing codebase, starter templates are provisioned from generic skeletons:
- `.agents/CODEMAP.md` (from `templates/codemap.md`)
- `ARCHITECTURE.md` (from `templates/architecture.md`)
- `.agents/PROJECT.MD` (from `templates/PROJECT.MD`)
- `.plans/pickup.md` (from `templates/pickup.md`)

Currently, AAPP does not notify the user with an actionable onboarding prompt sequence or guide the agent on how to map the project. Rather than introducing a one-off `aapp onboard` CLI command that pollutes the CLI surface and is only used once in a repository's lifespan, AAPP will leverage its **native lifecycle primitives**:
1. **Pre-Seeded Pickup Queue**: `templates/pickup.md` is initialized with an `Onboarding` queue item.
2. **First-Run Banner Guidance**: `aapp init` directs the developer to run `/aapp-status` followed by `/aapp-digest Onboarding`.
3. **First-Hand Protocol Experience**: The user experiences the full AAPP loop on Day 1 (`status` → `digest` → `freeze-start` → `done`), while the agent executes the codebase audit within a strictly declared blast radius.
4. **Natural Self-Cleanup**: `/aapp-digest` automatically consumes the item from `pickup.md`, the blueprint replaces template placeholders with real project architecture, and `/aapp-done` permanently archives the onboarding audit trail.

---

## 2. Technical Blueprint

### A. Initial Queue Seeding (`templates/pickup.md`)

When `.plans/pickup.md` is provisioned during `aapp init`, it includes an initial actionable item:
```markdown
## 🆕 New Ideas / Prompt Inputs
- [ ] Onboarding: Map codebase architecture into .agents/CODEMAP.md, ARCHITECTURE.md, and .agents/PROJECT.MD
```

### B. Post-Init User Guidance Banner (`lib/cmd_init.sh`)

At the conclusion of `aapp init`, replace generic completion output with an explicit, actionable Day 1 guide:
```text
🚀 Next Steps — Experience Your First AAPP Loop:
   1. Open your AI agent (Claude Code, Antigravity, Cursor).
   2. Run '/aapp-status' (or 'aapp status') to inspect the 4 pillars.
   3. Run '/aapp-digest Onboarding' to map your codebase into
      .agents/CODEMAP.md, ARCHITECTURE.md, and .agents/PROJECT.MD!
```

### C. Agent Protocol Rules (`templates/AGENTS.md` & `.agents/AGENTS.md`)

Add an explicit **Repository Onboarding Protocol** section:
```markdown
### 🗺️ Repository Onboarding & Day 1 Bootstrap
When adopting AAPP in an existing codebase, `.plans/pickup.md` contains an initial `Onboarding` item. Running `/aapp-digest Onboarding` initiates the canonical onboarding blueprint:
1. **Inspection**: The agent analyzes directory trees, build manifests, dependencies, and main entrypoints.
2. **Blast Radius**: The blueprint confines modifications strictly to `.agents/CODEMAP.md`, `ARCHITECTURE.md`, and `.agents/PROJECT.MD`.
3. **Execution**: The agent replaces all generic template placeholders (`[Module 1: Name & Path]`, `[What the application does]`, `[Project Name]`) with the real project architecture, tech stack, and active roadmap.
4. **Completion**: Running `/aapp-done` archives the onboarding blueprint into `.plans/done/000-archive-ledger.md`.
```

### D. Documentation Architecture

Document the first-run onboarding workflow across three public surfaces:

1. **`README.md`**:
   - In Section 4 (*Quick Start & Distribution Modes*), add a dedicated subsection:
     `### 🚀 The First-Run Onboarding Loop (Day 1 Experience)`
   - Explains the 4-step walk-through (`/aapp-status` → `/aapp-digest Onboarding` → `/aapp-freeze-start` → `/aapp-done`).
2. **`MANUAL.md`**:
   - In Section 5 (*AAPP State Machine & Lifecycle Commands*), under `### The Lifecycle Pipeline`, add:
     `#### Repository Onboarding (The Day 1 Loop)`
   - Documents the rationale: why onboarding runs as a real blueprint under a locked Blast Radius rather than a hidden CLI wizard.
3. **`CHEATSHEET.md`**:
   - In the `## The loop` table, add a dedicated row:
     `| Day 1 in a new repo | /aapp-digest Onboarding | Maps your codebase into CODEMAP.md, ARCHITECTURE.md, PROJECT.MD |`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Core Setup & Guidance
- [x] Task 1.1: Pre-seed `templates/pickup.md` with the initial `Onboarding` task.
- [x] Task 1.2: Update `lib/cmd_init.sh` completion banner to output the 3-step First AAPP Loop sequence.

### Phase 2: Agent Governance Rules
- [x] Task 2.1: Add the Repository Onboarding & Day 1 Bootstrap rule to `templates/AGENTS.md`.
- [x] Task 2.2: Sync rule to `.agents/AGENTS.md`.

### Phase 3: Documentation & Verification
- [x] Task 3.1: Document the First-Run Onboarding Loop in `README.md` (Section 4).
- [x] Task 3.2: Document the onboarding architecture in `MANUAL.md` (Section 5).
- [x] Task 3.3: Add Day 1 onboarding row to `CHEATSHEET.md`.
- [x] Task 3.4: Add regression test assertions in `tests/install_test.sh` verifying `templates/pickup.md` seeding and `cmd_init.sh` banner output.
- [x] Task 3.5: Run full test verification suite (`install_test.sh`, `pre-commit_test.sh`, `write-guard_test.sh`, `plan_resolver_test.sh`, `ai_attribution_test.sh`, `planning_health.sh`).
- [x] Task 3.6: Update `CHANGELOG.md` under `## [Unreleased]`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/pickup.md` -> Seed initial Onboarding queue item.
- [ ] `lib/cmd_init.sh` -> Update post-init banner with first-run guidance.
- [ ] `templates/AGENTS.md` -> Add Repository Onboarding rule to agent protocol template.
- [ ] `README.md` -> Document First-Run Onboarding Loop in Section 4.
- [ ] `MANUAL.md` -> Document Day 1 Onboarding in Section 5.
- [ ] `CHEATSHEET.md` -> Add Day 1 onboarding row to The Loop table.
- [ ] `tests/install_test.sh` -> Add regression test coverage for onboarding pickup seed and banner.
- [ ] `CHANGELOG.md` -> Record feature release notes.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `aapp` -> CLI dispatcher remains untouched; no new one-off commands.
- [ ] `lib/cmd_help.sh` -> Core command surface remains untouched.
- [ ] `.githooks/*` -> Hook enforcement engine remains untouched.
- [ ] `.agents/skills/aapp-*` -> Universal skills contracts remain untouched.
- [ ] `lib/plan_resolver.sh` -> Plan resolution engine is out of scope.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified using native AAPP pickup-to-digest lifecycle).*

---

## 📦 6. Change Log & Refinement History
* **2026-09-18:** Completed and verified in commit `d06da51`. All 256 automated test cases passing. Archiving to `.plans/done/`.
* **2026-09-18:** Plan frozen and activated into 🟠 In Development via freeze-start.
* **2026-09-18:** Plan drafted in `.plans/current/P19-context-onboarding-and-bootstrapping.md`.
* **2026-09-18:** Refined blueprint from a separate `aapp onboard` CLI command to native pickup queue ingestion (`/aapp-digest Onboarding`), preserving zero-bloat CLI minimalism and providing Day 1 hands-on protocol experience.
