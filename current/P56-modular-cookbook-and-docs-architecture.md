# 🗺️ Plan P-56: Modular Cookbook And Docs Architecture
* **Created:** 2026-10-07 | **Last Refined:** 2026-10-07
* **Target Issue / Milestone:** Milestone v1.1.0 (Documentation & Adopter UX Architecture)
* **Plan ID:** P-56
* **Changelog:** Added: Modular Cookbook (`COOKBOOK.md`) and topic-based recipe architecture (`docs/recipes/`)
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Commits:** none
<!-- AAPP-PROTOCOL:START v1.0.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** ISSUE-00X   <- add this line while BLOCKED, remove it when unblocked -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
`MANUAL.md` has grown into a monolithic 1,835-line (130 KB) technical document. While highly thorough, it mixes three distinct documentation functions:
1. **Architectural Specifications**: Worktree isolation, blast-radius engines, hash locks, threat models.
2. **Command & Configuration Reference**: Verbs, exit codes, switchboard flags, `git config aapp.*` matrix.
3. **Procedural How-To Recipes**: Setting up Git hook managers (Husky, Lefthook), onboarding legacy repos, configuring multi-agent worktrees, troubleshooting blast-radius refusals.

This creates significant cognitive friction for human developers who need immediate copy-paste solutions, forces AI agents to consume excessive context tokens when looking up specific operational tasks, and lacks an architecture that easily ports to static site documentation generators (VitePress, Astro Starlight, Docusaurus).

**Architectural Goal**:
Split procedural guidance into a modular **Cookbook Architecture**:
- Create a root [`COOKBOOK.md`](COOKBOOK.md) acting as a front-door catalog with curated learning tracks and categorized recipe links.
- Create [`docs/recipes/`](docs/recipes/) housing modular, topic-based markdown recipes equipped with standard frontmatter suitable for both SSG web ingestion and progressive disclosure by AI coding agents.
- Refactor [`MANUAL.md`](MANUAL.md) by extracting heavy procedural walkthroughs and hook wrapper scripts, replacing them with concise summaries and bidirectional links to the relevant recipes, restoring `MANUAL.md` as a lean, authoritative **Technical Reference Specification**.
- Ensure packaging scripts (`lib/cmd_install.sh`, `lib/cmd_develop.sh`) preserve and distribute `docs/` and `COOKBOOK.md`.

---

## 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
- Existing links in `README.md`, `MANUAL.md`, and skills will be updated to point directly to `COOKBOOK.md` and specific recipes in `docs/recipes/`.

### 2.1 File Hierarchy & Directory Structure

```text
agent-planning-kit/
├── COOKBOOK.md                     # Root catalog & curated index with links to recipes
├── MANUAL.md                       # Pure Technical Specification & Configuration Reference
├── README.md                       # High-level overview & quickstart
├── docs/
│   └── recipes/
│       ├── getting-started/
│       │   ├── adopt-existing-repo.md
│       │   └── solo-developer-workflow.md
│       ├── integrations/
│       │   ├── husky-git-hooks.md
│       │   ├── lefthook-git-hooks.md
│       │   └── github-actions-ci.md
│       ├── workflows/
│       │   ├── tdd-failure-assertions.md
│       │   ├── emergency-hotfixes.md
│       │   └── multi-agent-worktrees.md
│       └── troubleshooting/
│           ├── blast-radius-recovery.md
│           └── worktree-collision-recovery.md
```

### 2.2 Standard Recipe Frontmatter & Schema (SSG & Agent Compatible)

Every recipe in `docs/recipes/**/*.md` conforms to a standardized structure designed for both static site parsers and conversational progressive disclosure:

```markdown
---
title: "Recipe Title"
description: "A single concise sentence describing what this recipe accomplishes."
category: "getting-started | integrations | workflows | troubleshooting"
difficulty: "beginner | intermediate | advanced"
tags: [tag1, tag2, tag3]
---

# 🍳 Recipe: <Recipe Title>

## 🎯 Goal
A 1–2 sentence summary of the exact objective and when to use this recipe.

## 📋 Prerequisites
- Specific tool requirements (e.g. `npm`, `husky`, `git`, or initialized AAPP repo).
- Initial working tree or branch states.

## 🛠️ Step-by-Step Instructions
Step-by-step shell commands, configuration snippets, and expected terminal outputs.

## ⚠️ Critical Invariants & Gotchas
Blast-radius constraints, hook traps, or common failure modes to avoid.

## 🔗 Related References
- Links to relevant sections in `MANUAL.md`, `ARCHITECTURE.md`, or neighboring recipes.
```

### 2.3 Refactoring `MANUAL.md` (Extraction & Pointer Strategy)

The following procedural sections from `MANUAL.md` will be refactored into modular recipes:
1. **Section 7: Hook Manager Interoperability Recipes & Multi-Language Integration**
   - Extract Husky, Lefthook, pre-commit framework, Perl, Python, and Ruby hook runners into `docs/recipes/integrations/husky-git-hooks.md`, `lefthook-git-hooks.md`, and polyglot guides.
   - Retain the architectural description of subprocess invocation and dispatcher mechanics in Section 7 of `MANUAL.md`, replacing inline wrapper scripts with links to the recipes.
2. **Section 11: Troubleshooting & Operations FAQ**
   - Extract operational guides ("What if an agent gets trapped in a refusal loop?", "How do I handle merge conflicts in `.plans/`?", "How do I upgrade an existing project?") into `docs/recipes/troubleshooting/`.
   - Keep high-level policy answers in `MANUAL.md` FAQ, linking to the step-by-step recipes.

### 2.4 Kit Packaging & Distribution Sync

1. In `lib/cmd_install.sh`: Ensure `$SHARE_DIR` installs `docs/` and `COOKBOOK.md` alongside `lib/`, `templates/`, and `MANUAL.md`.
2. In `lib/cmd_develop.sh`: Verify develop mode symlinks or reflects `docs/` and `COOKBOOK.md`.
3. In `tests/install_test.sh`: Add assertions confirming `COOKBOOK.md` and `docs/recipes/` are copied to `$SHARE_DIR`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Directory Scaffold & Initial Recipe Suite
- [ ] Task 1.1: Create directory tree `docs/recipes/{getting-started,integrations,workflows,troubleshooting}/`.
- [ ] Task 1.2: Author Getting Started recipes:
  - `docs/recipes/getting-started/adopt-existing-repo.md`
  - `docs/recipes/getting-started/solo-developer-workflow.md`
- [ ] Task 1.3: Author Tooling Integration recipes (extracting and expanding from `MANUAL.md` §7):
  - `docs/recipes/integrations/husky-git-hooks.md`
  - `docs/recipes/integrations/lefthook-git-hooks.md`
  - `docs/recipes/integrations/github-actions-ci.md`
- [ ] Task 1.4: Author Advanced Workflow recipes:
  - `docs/recipes/workflows/tdd-failure-assertions.md`
  - `docs/recipes/workflows/emergency-hotfixes.md`
  - `docs/recipes/workflows/multi-agent-worktrees.md`
- [ ] Task 1.5: Author Troubleshooting recipes (extracting from `MANUAL.md` §11):
  - `docs/recipes/troubleshooting/blast-radius-recovery.md`
  - `docs/recipes/troubleshooting/worktree-collision-recovery.md`

### Phase 2: Root Catalog & MANUAL.md Slimdown
- [ ] Task 2.1: Author root [`COOKBOOK.md`](COOKBOOK.md) with categorized index, difficulty badges, and cross-references.
- [ ] Task 2.2: Refactor [`MANUAL.md`](MANUAL.md) to replace procedural scripts in §7 and §11 with links to the corresponding recipes in `docs/recipes/`.
- [ ] Task 2.3: Update [`README.md`](README.md) and [`CHEATSHEET.md`](CHEATSHEET.md) to feature [`COOKBOOK.md`](COOKBOOK.md).

### Phase 3: Packaging Sync & Test Coverage
- [ ] Task 3.1: Update `lib/cmd_install.sh` to install `COOKBOOK.md` and `docs/` into `$SHARE_DIR`.
- [ ] Task 3.2: Add regression tests in `tests/install_test.sh` verifying `COOKBOOK.md` and `docs/recipes/` distribution.
- [ ] Task 3.3: Verify all markdown links are strictly repository-relative and pass `tests/pre-commit_test.sh`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `COOKBOOK.md` -> Root cookbook catalog and categorized recipe index.
- [ ] `MANUAL.md` -> Technical manual slimmed down to pure reference, pointing to recipes.
- [ ] `README.md` -> Surface cookbook link in primary documentation overview.
- [ ] `CHEATSHEET.md` -> Reference cookbook for operational recipes.
- [ ] `NEW FILE` -> `docs/recipes/getting-started/adopt-existing-repo.md` -> Recipe for retrofitting existing repos.
- [ ] `NEW FILE` -> `docs/recipes/getting-started/solo-developer-workflow.md` -> Recipe for pure-human CLI workflow.
- [ ] `NEW FILE` -> `docs/recipes/integrations/husky-git-hooks.md` -> Recipe for pairing AAPP with Husky.
- [ ] `NEW FILE` -> `docs/recipes/integrations/lefthook-git-hooks.md` -> Recipe for pairing AAPP with Lefthook.
- [ ] `NEW FILE` -> `docs/recipes/integrations/github-actions-ci.md` -> Recipe for CI blast-radius gates.
- [ ] `NEW FILE` -> `docs/recipes/workflows/tdd-failure-assertions.md` -> Recipe for failure-first TDD loop.
- [ ] `NEW FILE` -> `docs/recipes/workflows/emergency-hotfixes.md` -> Recipe for hotfix extensions.
- [ ] `NEW FILE` -> `docs/recipes/workflows/multi-agent-worktrees.md` -> Recipe for concurrent multi-agent worktrees.
- [ ] `NEW FILE` -> `docs/recipes/troubleshooting/blast-radius-recovery.md` -> Recipe for resolving write refusals.
- [ ] `NEW FILE` -> `docs/recipes/troubleshooting/worktree-collision-recovery.md` -> Recipe for repairing stale worktrees.
- [ ] `lib/cmd_install.sh` -> Install COOKBOOK.md and docs/ into system share directory.
- [ ] `tests/install_test.sh` -> Regression test asserting cookbook distribution.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_init.sh` -> Worktree sync engine remains untouched.
- [ ] `templates/blast-radius-guard.sh` -> Write guard logic unchanged.
- [ ] `templates/aapp-pre-commit` -> Commit hook engine unchanged.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-07:** Drafted blueprint P-56 from user discussion. Established modular `COOKBOOK.md` + `docs/recipes/` architecture, defined SSG-compatible frontmatter schema, mapped extraction targets from `MANUAL.md`, and locked blast radius.
