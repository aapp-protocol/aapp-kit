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
        ├── 02-cli-commands-and-verbs.md     # 5-tier discovery hierarchy, canonical verb contracts
        ├── 03-configuration-matrix.md       # Full git config aapp.* dictionary & defaults
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

An exhaustive, standalone command dictionary covering every verb, syntax variation, and parameter permutation across all 5 discovery tiers:
1. **Primary Lifecycle**:
   - `aapp init [mode]` (fresh repository bootstrap, worktree mounting, template sync).
   - `aapp draft <slug> [issue <num>]` (blueprint scaffolding from scratch or promoted from issue).
   - `aapp tdd <id>` (test failure registration and verification).
   - `aapp freeze <id>` (design lock, blast-radius verification, unfreezing protocol).
   - `aapp start <id>` (worktree binding, development phase ingress).
   - `aapp commit "<msg>" [agent <A> vendor <V> model <M>] [note "<text>"]` (plan-bound commit helper).
   - `aapp commit adopt <sha>...` (retroactive commit binding).
   - `aapp done [id]` (verification commit recording, archive relocation, matrix pruning).
   - `aapp release [version]` (release runbook, pre-flight gate, tag ledger).
2. **Issue & Mini-Plan Operations**:
   - `aapp issue allocate` (atomic ID reservation via provider or local sequence).
   - `aapp issue next` (peek next unallocated issue ID).
   - `aapp issue list` (table dump of active issues).
   - `aapp issue fix next-blocker` (claim top unblocked issue and open mini-plan).
   - `aapp issue fix <num> file <path>...` (scoped mini-plan on target issue and files).
   - `aapp issue hotfix "<text>" [file <path>]... [plan]` (emergency plan blocking, queue injection, stash set-aside).
   - `aapp issue close <num> [sha <sha>] [summary "<text>"]` (archive relocation, road-map removal, unblock cascade).
   - `aapp issue abort [num]` (mini-plan deletion, revert to queue).
3. **Refinement & Board Operations**:
   - `aapp refine <id> "<msg>"` (blueprint progress, design refinement before freeze).
   - `aapp refine <id> blocked <num>` (manual dependency blocking).
   - `aapp refine <id> slug <new-slug>` (plan renaming with automatic issue cross-link repair).
   - `aapp refine issues "<msg>"` (validated flat ledger and roadmap commit).
   - `aapp refine pickup "<msg>"` (unprocessed idea queue commit).
4. **Inspection & Context Recovery**:
   - `aapp status [brief]` (context recovery agent 4-pillar briefing).
   - `aapp active` (print currently bound plan ID and worktree path).
   - `aapp diff [id]` (working tree blast-radius diff inspection).
   - `aapp tree` (visual worktree and orphan branch layout).
   - `aapp plan <id>` (switch worktree active-plan context pointer).
   - `aapp ai [status|lax|strict|none|notes [on|off]]` (switchboard attribution status and switching).
5. **Maintenance & Emergency Controls**:
   - `aapp pause [reason]` (emergency brake, stash isolation, velocity freeze).
   - `aapp resume` (lift pause, verify tree parity, resume velocity).
   - `aapp sync` (sync template blocks across `.agents/` and `.plans/`).
   - `aapp upgrade [--develop]` (upstream update, version protocol check).
   - `aapp develop` (symlink-based local development mode).
   - `aapp install` (system-wide share directory installation).

**Standardized Entry Schema per Verb**:
- Syntax signature with required, optional, and multi-value parameters.
- Preconditions: Current worktree, required branch, plan lifecycle status.
- Exit Codes: `0` (Success), `1` (Fatal / Refusal), `2` (Hook / Gate Veto).
- Terminal output examples and common failure diagnostics.
- IDE / Agent Slash Command Mappings (`/aapp-freeze`, `/aapp-status`, `/aapp-digest`, etc.).

### 2.6 Dedicated Configuration Dictionary (`docs/reference/03-configuration-matrix.md`)

An authoritative, single-source reference dictionary for every `git config aapp.*` setting:
- **Attribution & Provenance**:
  - `aapp.aiAttribution`: Enum (`none | lax | strict | notes`). Governs public commit trailers.
  - `aapp.aiNotes`: Boolean (`true | false`). Controls parallel private notes recording in `refs/notes/ai`.
  - `aapp.aiAgent`, `aapp.aiVendor`, `aapp.aiModel`: Default agent identity strings for manual overrides.
- **Commit Formatting Invariants**:
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
- **Blast Radius & Containment**:
  - `aapp.allowPath`: Colon-separated path patterns authorized to bypass Layer 1 write-guard.
- **Lifecycle Hook Overrides**:
  - `aapp.hook.<event>`: Script path overrides for any of the 10 lifecycle events (e.g., `aapp.hook.post-done`).

**Standardized Entry Schema per Setting**:
- Key name, data type, default value, and valid values/enums.
- Configuration scope: repository-local (`--local`) vs user-global (`--global`).
- Enforcement layer: Layer 1 Write-Time Guard, Layer 2 Pre-Commit Hook, or CLI Runtime.
- Shell configuration examples and preset recipes (e.g., "Autonomous CI Agent Mode", "Human-Only Private Notes Mode", "Strict Compliance Mode").

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Conceptual Architecture Modularization (`docs/concepts/`)
- [ ] Task 1.1: Author `docs/concepts/01-worktree-architecture.md` (extracting and refining from `MANUAL.md` §1 & §2).
- [ ] Task 1.2: Author `docs/concepts/02-blast-radius-engine.md` (extracting from `MANUAL.md` §3).
- [ ] Task 1.3: Author `docs/concepts/03-two-lane-governance.md` (extracting from `MANUAL.md` §4).
- [ ] Task 1.4: Author `docs/concepts/04-security-and-threat-model.md` (extracting from `MANUAL.md` §10).

### Phase 2: Technical Reference Modularization (`docs/reference/`)
- [ ] Task 2.1: Author `docs/reference/01-lifecycle-state-machine.md` (extracting from `MANUAL.md` §5).
- [ ] Task 2.2: Author `docs/reference/02-cli-commands-and-verbs.md` with complete parameter variations across all 5 verb tiers, execution preconditions, exit codes, error diagnostics, and slash command mappings.
- [ ] Task 2.3: Author `docs/reference/03-configuration-matrix.md` with complete `git config aapp.*` dictionary, data types, defaults, scopes, enforcement layers, and configuration presets.
- [ ] Task 2.4: Author `docs/reference/04-plugin-and-hook-engine.md` (extracting from `MANUAL.md` §8).
- [ ] Task 2.5: Author `docs/reference/05-ai-attribution-and-notes.md` (extracting from `MANUAL.md` §9).

### Phase 3: Portal Transformation & Storefront Cleanup
- [ ] Task 3.1: Rewrite root `MANUAL.md` into the concise executive portal (~150 lines) with complete relative links into `docs/`.
- [ ] Task 3.2: Slim down root `README.md` to ~120 lines, adopting `.plans/pickup/readme-draft.md` enriched with `COOKBOOK.md` navigation links.
- [ ] Task 3.3: Verify all internal markdown links are repository-relative and validate anchor hygiene.

### Phase 4: Installer Sync & Regression Verification
- [ ] Task 4.1: Update `lib/cmd_install.sh` to package `docs/concepts/` and `docs/reference/`.
- [ ] Task 4.2: Update `tests/install_test.sh` to verify full `docs/` tree installation in `$SHARE_DIR`.
- [ ] Task 4.3: Execute all automated test suites (`tests/install_test.sh`, `tests/pre-commit_test.sh`, `tests/write-guard_test.sh`) to ensure 100% compliance.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `MANUAL.md` -> Transformed into executive navigation portal.
- [ ] `README.md` -> Slimmed down to ~120-line storefront.
- [ ] `NEW FILE` -> `docs/concepts/01-worktree-architecture.md` -> Deep dive on orphan worktree mechanics.
- [ ] `NEW FILE` -> `docs/concepts/02-blast-radius-engine.md` -> Dual-layer enforcement specification.
- [ ] `NEW FILE` -> `docs/concepts/03-two-lane-governance.md` -> Issues vs Plans two-lane doctrine.
- [ ] `NEW FILE` -> `docs/concepts/04-security-and-threat-model.md` -> Containment & security boundaries.
- [ ] `NEW FILE` -> `docs/reference/01-lifecycle-state-machine.md` -> State machine transitions & taxonomy.
- [ ] `NEW FILE` -> `docs/reference/02-cli-commands-and-verbs.md` -> Complete reference of all CLI verbs, parameter variations, exit codes, and preconditions.
- [ ] `NEW FILE` -> `docs/reference/03-configuration-matrix.md` -> Complete git config aapp.* dictionary, data types, defaults, scopes, and presets.
- [ ] `NEW FILE` -> `docs/reference/04-plugin-and-hook-engine.md` -> Hook triggers and registry contract.
- [ ] `NEW FILE` -> `docs/reference/05-ai-attribution-and-notes.md` -> AI attribution modes and git notes.
- [ ] `lib/cmd_install.sh` -> Package docs/ tree into SHARE_DIR.
- [ ] `tests/install_test.sh` -> Regression test asserting docs/ distribution.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `COOKBOOK.md` -> Governed by Plan P-56.
- [ ] `docs/recipes/` -> Governed by Plan P-56.
- [ ] `templates/blast-radius-guard.sh` -> Enforcement engine logic unchanged.
- [ ] `templates/aapp-pre-commit` -> Commit hook engine unchanged.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-07:** Refined blueprint to establish dedicated, exhaustive reference specifications for CLI Verbs with all parameter variations (`docs/reference/02-cli-commands-and-verbs.md`) and the complete Configuration Matrix dictionary (`docs/reference/03-configuration-matrix.md`).
* **2026-10-07:** Drafted blueprint P-57 from user discussion. Defined modular technical specification hierarchy (`docs/concepts/` and `docs/reference/`), outlined executive portal `MANUAL.md`, and specified storefront `README.md` slimdown.
