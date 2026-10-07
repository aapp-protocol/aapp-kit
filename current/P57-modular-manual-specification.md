# 🗺️ Plan P-57: Modular Manual Specification
* **Created:** 2026-10-07 | **Last Refined:** 2026-10-07
* **Target Issue / Milestone:** Milestone v1.1.0 (Documentation & Technical Reference Architecture)
* **Plan ID:** P-57
* **Changelog:** Changed: Modular technical specification (`docs/`) and executive portal `MANUAL.md` architecture
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
`MANUAL.md` currently spans 1,835 lines (130 KB), while `README.md` spans 463 lines (35 KB).
Following Plan P-56 (which establishes the How-To Cookbook in `docs/recipes/`), `MANUAL.md` still houses over 1,200 lines of disparate technical content covering 12 separate domains: worktree plumbing, blast-radius mechanics, two-lane governance, lifecycle state machines, plugin registries, AI attribution, threat models, and configuration dictionaries.

Simultaneously, `README.md` suffers from severe content bloat, duplicating low-level manual content (5-column TSV schemas, branching theory, hook manager shims, and §E.8 academic mode-boundary rationale) rather than acting as a crisp, inviting storefront.

**Architectural Goal**:
Complete the Diátaxis documentation architecture:
1. **Modular Technical Specification (`docs/concepts/` & `docs/reference/`)**:
   - Extract `MANUAL.md` into clean, topic-based modular specification files with YAML frontmatter.
   - Separate conceptual deep-dives (`docs/concepts/`) from factual lookups (`docs/reference/`).
2. **Executive Portal `MANUAL.md`**:
   - Transform the root `MANUAL.md` into a lean ~150-line executive manual providing system axioms, high-level architecture, and direct navigation links to the modular specs.
3. **Slim Storefront `README.md`**:
   - Reduce `README.md` to ~120 lines focused purely on value proposition, 30-second architecture diagram, 60-second quickstart, and documentation links.
4. **Static Site Generator (SSG) & Progressive Disclosure Readiness**:
   - Ensure the entire `docs/` hierarchy is formatted for seamless ingestion by modern SSG engines (VitePress, Astro Starlight, Docusaurus) and token-efficient progressive disclosure by AI coding agents.

---

## 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
- All internal markdown cross-links will use repository-relative paths (`[Concepts](docs/concepts/...)`).
- Existing external references to `MANUAL.md` will land on the executive portal with immediate links to the detailed subtopics.

### 2.0 Shared Documentation Invariant (Enabling `docs/**` and `COOKBOOK.md` in Guard & Hook)

Currently, `templates/blast-radius-guard.sh:310` and `templates/aapp-pre-commit` only exempt named root files (`CHANGELOG.md`, `README.md`, `MANUAL.md`, `CHEATSHEET.md`, `CODEMAP.md`, `ARCHITECTURE.md`, `ISSUES.md`). Neither `COOKBOOK.md` nor `docs/**` are recognized. Without updating this, any plan editing documentation in `docs/` would be forced to list every markdown file in its `### 📂 Target Files`, and concurrent plans touching documentation would collide at the disjointness activation gate.

To uphold the core invariant (*"documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants"*), Plan P-57 updates the shared-documentation engine:
1. In `lib/aapp-lib.sh`:
   - Update `aapp_shared_docs_regex()` to include `COOKBOOK\.md`.
   - Update `aapp_is_shared_doc()` to return `0` (true) for any file under `docs/` (`docs/*` and `docs/**`).
2. In `templates/blast-radius-guard.sh`:
   - Add `docs/*|COOKBOOK.md` to Section 3 always-allowed cases.
3. In `templates/aapp-pre-commit`:
   - Update `ALWAYS_ALLOWED_REGEX` and documentation scanner so staged files matching `docs/*` and `COOKBOOK.md` pass without requiring target file declarations.
4. Add regression tests in `tests/write-guard_test.sh` and `tests/pre-commit_test.sh`.

### 2.1 Information Architecture & Taxonomy

```text
agent-planning-kit/
├── README.md                           # Storefront: Pitch, 30s diagram, 60s install (~120 lines)
├── CHEATSHEET.md                       # Desk Card: 1-screen quick reference (<= 200 lines)
├── COOKBOOK.md                         # [P-56] How-To Catalog: Topic index linking to docs/recipes/
├── MANUAL.md                           # Executive Portal: Core axioms & navigation hub (~150 lines)
│
└── docs/
    ├── recipes/                        # [P-56] Task-Oriented How-To Guides
    │   ├── getting-started/
    │   ├── integrations/
    │   ├── plugins-and-hooks/
    │   ├── workflows/
    │   └── troubleshooting/
    │
    ├── concepts/                       # Deep Architectural Understanding & Mechanics
    │   ├── 01-worktree-architecture.md      # Orphan branches, worktree mounts, remote sync
    │   ├── 02-blast-radius-engine.md        # PreToolUse guard, pre-commit, bracket regex
    │   ├── 03-two-lane-governance.md        # Issues vs Plans, flat ledger, relocation invariant
    │   └── 04-security-and-threat-model.md  # Pair programming trust model, shell containment
    │
    └── reference/                      # Authoritative Lookups & Specifications
        ├── 01-lifecycle-state-machine.md    # Status taxonomy, transitions, failure branches
        ├── 02-cli-commands-and-verbs.md     # All 35 CLI verbs across 4 tiers, parameter variations
        ├── 03-configuration-matrix.md       # Complete git config aapp.* dictionary (22+ keys)
        ├── 04-plugin-and-hook-engine.md     # registry.tsv contract, lifecycle triggers, execution
        └── 05-ai-attribution-and-notes.md   # Trailers vs Notes, switchboard, audit compliance
```

### 2.2 Portal `MANUAL.md` Structure (~150 Lines)

The root `MANUAL.md` becomes the master navigation portal:
1. **Core Architectural Axioms**:
   - The Clean Break Invariant.
   - The Blast Radius Lock.
   - The Two-Lane Separation Law (Issues vs. Plans).
   - Zero Context Pollution (Orphan branches).
2. **Master Specification Map**:
   - Structured table linking each domain to its modular file in `docs/concepts/` or `docs/reference/`.
3. **Quick CLI & Switchboard Cheat Matrix**:
   - Concise lookup for key verbs and configuration flags.

### 2.3 Slim Storefront `README.md` Structure (~120 Lines)

`README.md` is rebuilt using the proven 101-line storefront blueprint drafted in `.plans/pickup/readme-draft.md`:
- **Hero & Value Proposition**: 2-sentence hook ("Zero-drift autonomous pair programming") and badges.
- **Highlights**: 5 crisp architectural pillars (Asymmetric Architecture, Deterministic Blast Radius, Zero Pollution, Universal Agent Compatibility, Fail-Closed Security).
- **Quickstart**: 3-step setup (1. User installation, 2. Repo initialization, 3. First pair-programming session).
- **The Core Lifecycle**: Clear 6-step ASCII sequence (`draft` ➔ `tdd` ➔ `freeze` ➔ `start` ➔ `commit` ➔ `done`).
- **Dual-Layer Blast Radius Enforcement**: Concise table (Layer 1 Write-time vs Layer 2 Commit-time).
- **Software Provenance**: Rationale for transparent emailless trailers and private Git notes.
- **Documentation Navigation Quadrant**: Links to `CHEATSHEET.md`, `COOKBOOK.md`, and `MANUAL.md`.
- **License**: Clean dual MIT/Apache 2.0 license declaration.

### 2.4 Packaging & Installer Synchronization

1. In `lib/cmd_install.sh`: Ensure `$SHARE_DIR` copies the entire `docs/` tree (`recipes/`, `concepts/`, `reference/`) and `MANUAL.md`.
2. In `lib/cmd_develop.sh`: Verify symlink reflection covers `docs/` and root documentation portals.
3. In `tests/install_test.sh`: Assert that installed share directories contain `docs/concepts/` and `docs/reference/`.

### 2.5 Dedicated CLI Verbs & Parameter Variations Reference (`docs/reference/02-cli-commands-and-verbs.md`)

An authoritative, single-source reference dictionary derived directly from `lib/verbs.tsv` and `lib/docs/verbs/*.md` contracts, covering all **35 canonical CLI verbs across the 4 tested tiers**:
1. **Daily Tier (17 Verbs - Core Lifecycle & Operations)**:
   - `aapp status [brief|short]` -> 4-pillar context recovery briefing (or 1-line pulse).
   - `aapp draft <slug> [issue <num>]` -> Scaffold blueprint from template, stamp ID & date, register in matrix.
   - `aapp refine <id> "<msg>" | <id> blocked <num> | <id> slug <new-slug> | pickup|issues "<msg>"` -> Plan refinement and board commits.
   - `aapp tdd <id>` -> Declare plan failure-first tests (§3 identifiers, §4 test files) before freeze.
   - `aapp freeze <id>` -> Lock blueprint blast radius & design into frozen backlog spec.
   - `aapp start <id>` -> Transition frozen blueprint to in-development and bind local buffer.
   - `aapp freeze-start <id>` -> Atomically freeze blueprint and activate execution buffer.
   - `aapp done [id]` -> Archive implemented blueprint to `done/` and update archival ledger.
   - `aapp commit "<msg>" [agent <A> vendor <V> model <M>] [note "<text>"]` -> Plan-bound commit helper.
   - `aapp commit adopt <sha>...` -> Retroactively record code commits in active plan.
   - `aapp active [id | clear]` -> Display, bind, or clear active execution plan buffer.
   - `aapp issue allocate | next | list | fix next-blocker | fix <num> file <path>... | hotfix "<text>" [file <path>]... [plan] | close <num> [sha <sha>] [summary "<text>"] | fix <num> abort` -> Canonical issue and mini-plan operations.
   - `aapp plan [id | <slug>]` -> Display educational planning switchboard or resolve blueprint.
   - `aapp plan-status [id]` -> Inspect plan lane matrix or specific blueprint details.
   - `aapp matrix [check]` -> Re-derive state matrix from plan Status lines (`check` to audit).
   - `aapp note [stage|push|pull|show]` -> Inspect, stage, push, or pull general and AI Git notes.
   - `aapp ai [status|lax|strict|none|notes [on|off]]` -> Configure or inspect AI attribution mode.
   - `aapp test [suite]` -> Run automated test suites across all kit components.
2. **Setup Tier (7 Verbs - Bootstrap & Distribution)**:
   - `aapp init [mode]` -> Initialize or update AAPP worktrees in current repository.
   - `aapp install` -> Install AAPP globally into `~/.local/bin` and configure PATH.
   - `aapp upgrade [develop]` -> Upgrade global AAPP binaries & templates from upstream (or switch to develop clone).
   - `aapp develop` -> Link local development clone globally via symlinks.
   - `aapp uninstall` -> Remove global AAPP binaries and shared directories.
   - `aapp version [-v|--version]` -> Show installed AAPP version.
   - `aapp help [-h|--help] [verb]` -> Show grouped command catalog or verb help.
3. **Sync Tier (5 Verbs - Multi-Worktree Coordination & Safety)**:
   - `aapp push` -> Push active worktrees (`.plans`, `.agents`, `.githooks`) to remote.
   - `aapp pull` -> Pull remote updates for active worktrees with non-negotiable `--ff-only`.
   - `aapp sync` -> Bi-directional sync: pull updates followed by push.
   - `aapp pause [reason]` -> Emergency brake: quarantine in-flight changes into stashes.
   - `aapp resume` -> Disengage brake, verify commit drift, and restore stashes.
4. **Hooks Tier (5 Verbs - Lifecycle Extension Audit & Execution)**:
   - `aapp hooks` -> Audit lifecycle hook registry and verify SHA256 integrity.
   - `aapp hook-test <event>` -> Dry-run test an event trigger with mock payload.
   - `aapp hook-run <event>` -> Execute a registered hook handler with specified payload.
   - `aapp hook-hash <file>` -> Compute SHA256 registration hash for hook script.
   - `aapp plugins` -> Discover installed action plugins in `.agents/skills/`.

*Note on Agent Skills*: Distinct from CLI verbs, interactive agent workflows (`/aapp-release`, `/aapp-digest`, `/aapp-plan`, `/plan`) are exposed as Universal AAPP Skills in `.agents/skills/` and documented with clear cross-references.

**Standardized Entry Schema per Verb**:
- Syntax signature with required, optional, and multi-value parameters.
- Preconditions: Current worktree, required branch, plan lifecycle status.
- Exit Codes: `0` (Success), `1` (Fatal / Refusal), `2` (Advisory Warning).
- Terminal output examples and common failure diagnostics.

### 2.6 Dedicated Configuration Dictionary (`docs/reference/03-configuration-matrix.md`)

An authoritative, single-source dictionary covering all 22+ `git config aapp.*` settings discovered across the codebase, organized to match the manifest schema of Pickup **Configuration Manager CLI / #99** (`config.tsv`):
- **Attribution & Provenance**:
  - `aapp.aiAttribution`: Enum (`none | lax | strict | notes`, default `lax`). Governs public commit trailers.
  - `aapp.aiNotes`: Boolean (`true | false`, default `false`). Controls parallel private notes recording in `refs/notes/ai`.
  - `aapp.aiAgent`, `aapp.aiVendor`, `aapp.aiModel`: Default agent identity strings for manual overrides.
  - `aapp.notesRemote`: String (default `origin`). Remote name for pushing/pulling Git notes.
- **Commit & Formatting Invariants**:
  - `aapp.subjectMaxLen`: Integer (default `72`). Maximum commit subject character length.
  - `aapp.commitLineMaxLen`: Integer (default `100`). Maximum commit body line width.
  - `aapp.bodyMaxLen`: Integer (default `1200`). Maximum total commit body characters.
  - `aapp.maxBodyLines`: Integer (default `20`). Maximum total commit body lines.
  - `aapp.changelogMaxLen`: Integer (default `300`). Maximum characters per single-line bullet in `CHANGELOG.md`.
- **Governance & Planning Modes**:
  - `aapp.changelogMode`: Enum (`plan | commit`, default `plan`). Plan-header single entry vs commit-by-commit entry.
  - `aapp.issueId`: Integer counter. Current local sequence cursor for issue allocation.
  - `aapp.issueTracker`: String. Provider plugin identifier for external issue tracker integration.
  - `aapp.maxEmergencyHotfixes`: Integer (default `2`). Threshold of hotfixes before permanent plan blocking.
  - `aapp.issueFixWait`: Integer (default `5`). Wait timeout in minutes when another mini-plan is in development.
  - `aapp.planState.<id>`: String. State matrix overrides.
- **Branching, Remotes & Worktree Sync**:
  - `aapp.devBranch`: String (default `develop`). Main development integration branch.
  - `aapp.protectStable`: Boolean (default `true`). Blocks direct commits to stable branches (`main`, `master`).
  - `aapp.remote`: String (default `origin`). Canonical git remote name.
  - `aapp.syncStrategy`: String (default `ff-only`). Merge strategy for sync operations.
  - `aapp.pullStrategy`: String (default `ff-only`). Merge strategy for pull operations.
  - `aapp.syncWorktrees`: String. Space/comma-separated list of worktrees to synchronize.
- **Blast Radius & Containment**:
  - `aapp.allowPath`: Colon-separated path patterns authorized to bypass Layer 1 write-guard.
- **Lifecycle Hook Overrides & Testing**:
  - `aapp.hook.<event>`: Script path overrides for lifecycle events (e.g., `aapp.hook.pre-freeze`, `aapp.hook.post-done`).
  - `aapp.hookTimeout`: Integer (default `15`). Watchdog timeout in seconds for hook execution.
  - `aapp.testCommand`: String. Custom test execution runner command.

**Standardized Entry Schema per Setting**:
- Key name, data type, default value, and valid values/enums.
- Configuration scope: repository-local (`--local`) vs user-global (`--global`).
- Enforcement layer: Layer 1 Write-Time Guard, Layer 2 Pre-Commit Hook, or CLI Runtime.
- Shell configuration examples and preset recipes (e.g., "Autonomous CI Agent Mode", "Human-Only Private Notes Mode", "Strict Compliance Mode").

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 0: Prerequisite Shared Documentation Invariant (Layer 1 & Layer 2)
- [ ] Task 0.1: Update `lib/aapp-lib.sh` (`aapp_shared_docs_regex` and `aapp_is_shared_doc`), `templates/blast-radius-guard.sh`, and `templates/aapp-pre-commit` (`ALWAYS_ALLOWED_REGEX`) to include `COOKBOOK.md` and `docs/*`.
- [ ] Task 0.2: Add regression tests in `tests/write-guard_test.sh` and `tests/pre-commit_test.sh` verifying that modifying and committing `docs/**/*.md` and `COOKBOOK.md` passes freely without active plan target declarations.

### Phase 1: Conceptual Architecture Modularization (`docs/concepts/`)
- [ ] Task 1.1: Author `docs/concepts/01-worktree-architecture.md` (extracting and refining from `MANUAL.md` §1 & §2).
- [ ] Task 1.2: Author `docs/concepts/02-blast-radius-engine.md` (extracting from `MANUAL.md` §3).
- [ ] Task 1.3: Author `docs/concepts/03-two-lane-governance.md` (extracting from `MANUAL.md` §4).
- [ ] Task 1.4: Author `docs/concepts/04-security-and-threat-model.md` (extracting from `MANUAL.md` §10).

### Phase 2: Technical Reference Modularization (`docs/reference/`)
- [ ] Task 2.1: Author `docs/reference/01-lifecycle-state-machine.md` (extracting from `MANUAL.md` §5).
- [ ] Task 2.2: Author `docs/reference/02-cli-commands-and-verbs.md` covering all 35 verbs strictly aligned with `lib/verbs.tsv` and `lib/docs/verbs/*.md` contracts, execution preconditions, exit codes, and diagnostics.
- [ ] Task 2.3: Author `docs/reference/03-configuration-matrix.md` covering all 22+ `git config aapp.*` settings discovered in code, aligned with Pickup #99 manifest schema.
- [ ] Task 2.4: Author `docs/reference/04-plugin-and-hook-engine.md` (extracting from `MANUAL.md` §8).
- [ ] Task 2.5: Author `docs/reference/05-ai-attribution-and-notes.md` (extracting from `MANUAL.md` §9).

### Phase 3: Portal Transformation, Storefront Cleanup & Link Audit
- [ ] Task 3.1: Rewrite root `MANUAL.md` into the concise executive portal (~150 lines) with complete relative links into `docs/`.
- [ ] Task 3.2: Slim down root `README.md` to ~120 lines, adopting `.plans/pickup/readme-draft.md` enriched with `COOKBOOK.md` navigation links.
- [ ] Task 3.3: Perform repository-wide anchor and link audit across `templates/`, `lib/`, `tests/`, and `.agents/` updating old `MANUAL.md` anchor references.

### Phase 4: Installer Sync & Regression Verification
- [ ] Task 4.1: Update `lib/cmd_install.sh` to package `docs/concepts/` and `docs/reference/`.
- [ ] Task 4.2: Update `tests/install_test.sh` to verify full `docs/` tree installation in `$SHARE_DIR`.
- [ ] Task 4.3: Author automated dead-link test `tests/doc_links_test.sh` verifying that all cross-links between `README.md`, `MANUAL.md`, `COOKBOOK.md`, and `docs/**/*.md` resolve to valid files and headings.
- [ ] Task 4.4: Execute all automated test suites (`tests/install_test.sh`, `tests/pre-commit_test.sh`, `tests/write-guard_test.sh`, `tests/doc_links_test.sh`) to ensure 100% compliance.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/aapp-lib.sh` -> Update shared doc regex to include COOKBOOK.md and docs/*.
- [ ] `templates/blast-radius-guard.sh` -> Add COOKBOOK.md and docs/* to always-allowed case.
- [ ] `templates/aapp-pre-commit` -> Add COOKBOOK.md and docs/* to ALWAYS_ALLOWED_REGEX.
- [ ] `MANUAL.md` -> Transformed into executive navigation portal.
- [ ] `README.md` -> Slimmed down to ~120-line storefront.
- [ ] `NEW FILE` -> `docs/concepts/01-worktree-architecture.md` -> Deep dive on orphan worktree mechanics.
- [ ] `NEW FILE` -> `docs/concepts/02-blast-radius-engine.md` -> Dual-layer enforcement specification.
- [ ] `NEW FILE` -> `docs/concepts/03-two-lane-governance.md` -> Issues vs Plans two-lane doctrine.
- [ ] `NEW FILE` -> `docs/concepts/04-security-and-threat-model.md` -> Containment & security boundaries.
- [ ] `NEW FILE` -> `docs/reference/01-lifecycle-state-machine.md` -> State machine transitions & taxonomy.
- [ ] `NEW FILE` -> `docs/reference/02-cli-commands-and-verbs.md` -> Complete reference of all 35 CLI verbs, parameter variations, exit codes, and preconditions.
- [ ] `NEW FILE` -> `docs/reference/03-configuration-matrix.md` -> Complete git config aapp.* dictionary (22+ keys), data types, defaults, scopes, and presets.
- [ ] `NEW FILE` -> `docs/reference/04-plugin-and-hook-engine.md` -> Hook triggers and registry contract.
- [ ] `NEW FILE` -> `docs/reference/05-ai-attribution-and-notes.md` -> AI attribution modes and git notes.
- [ ] `NEW FILE` -> `tests/doc_links_test.sh` -> Automated link and anchor hygiene test.
- [ ] `tests/write-guard_test.sh` -> Regression test asserting docs/ are always-allowed.
- [ ] `tests/pre-commit_test.sh` -> Regression test asserting docs/ commits pass without plan target listing.
- [ ] `lib/cmd_install.sh` -> Package docs/ tree into SHARE_DIR.
- [ ] `tests/install_test.sh` -> Regression test asserting docs/ distribution.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `COOKBOOK.md` -> Governed by Plan P-56.
- [ ] `docs/recipes/` -> Governed by Plan P-56.
- [ ] `lib/cmd_init.sh` -> Worktree sync engine remains untouched.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-07:** Refined blueprint: added Phase 0 prerequisite for shared-doc engine (`docs/*` and `COOKBOOK.md` always-allowed in guard and hook), aligned CLI verbs reference with all 35 verbs in `lib/verbs.tsv`, aligned configuration dictionary with all 22+ keys from codebase, and added anchor audit and `tests/doc_links_test.sh` dead-link test.
* **2026-10-07:** Refined blueprint to establish dedicated, exhaustive reference specifications for CLI Verbs with all parameter variations (`docs/reference/02-cli-commands-and-verbs.md`) and the complete Configuration Matrix dictionary (`docs/reference/03-configuration-matrix.md`).
* **2026-10-07:** Drafted blueprint P-57 from user discussion. Defined modular technical specification hierarchy (`docs/concepts/` and `docs/reference/`), outlined executive portal `MANUAL.md`, and specified storefront `README.md` slimdown.
