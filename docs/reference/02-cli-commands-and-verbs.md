---
title: CLI Command Reference & Verb Catalog
description: Complete reference for all 35 AAPP CLI verbs across the 5 discovery tiers, including contracts, arguments, and execution semantics.
---

# 💻 CLI Command Reference & Verb Catalog

AAPP maintains complete parity between conversational AI agent interfaces (Universal Skills) and standalone Unix terminal workflows. Command metadata is centralized in `lib/verbs.tsv`, a zero-dependency manifest providing discovery, documentation, and contract enforcement.

---

## 1. The 5-Tier Discovery Hierarchy

To eliminate cognitive overload, the AAPP CLI organizes its 35 commands into 5 visual discovery tiers:

| Tier | Purpose | Verbs |
| :--- | :--- | :--- |
| **1. Daily Working Loop** | Core lifecycle and execution workflows | `status`, `draft`, `refine`, `tdd`, `plan`, `plan-status`, `matrix`, `freeze`, `start`, `freeze-start`, `done`, `commit`, `active`, `note`, `issue`, `offline`, `companion`, `test`, `help`, `ai` |
| **2. Setup & Maintenance** | Initialization, updates, releases, and development links | `init`, `install`, `upgrade`, `develop`, `uninstall`, `version`, `release` |
| **3. Team Sync & Controls** | Multi-worktree transport and emergency braking | `push`, `pull`, `sync`, `pause`, `resume` |
| **4. Extensibility & Hooks** | Lifecycle hook verification and plugin execution | `hooks`, `hook-test`, `hook-run`, `hook-hash`, `plugins` |
| **5. Attribution & Metadata** | Semantic commit trailers and private git notes | `ai` (`none`, `lax`, `strict`, `notes`, `credits`) |

---

## 2. Command Catalog by Tier

### 2.1 Tier 1: Daily Working Loop

#### `aapp status [short]`
- **Description**: Displays the 4-pillar recovery briefing (Shipped, Issues, Plans, Pickup).
- **Options**: `short` emits a concise 1-line project health pulse.
- **Contract**: `lib/docs/verbs/status.md`.

#### `aapp draft [slug]`
- **Description**: Scaffolds a new blueprint in `.plans/current/` from `templates/plan-template.md`.
- **Behavior**: Allocates next monotonic Plan ID (`aapp.planId`), stamps date and issue link, registers row in `.plans/state_matrix.md`, and commits to `.plans`. When `slug` is omitted, selects from `.plans/pickup.md`.
- **Contract**: `lib/docs/verbs/draft.md`.

#### `aapp refine <id> "<message>"`
- **Description**: Commits an edit to an active plan's content via the path-limited plans commit engine.
- **Special Actions**:
  - `aapp refine <id> blocked <num>`: Marks plan `🟥 BLOCKED` on issue `#<num>`.
  - `aapp refine <id> slug <new-slug>`: Renames plan file and updates all cross-references.
  - `aapp refine pickup "<msg>"`: Validates and commits updates to `.plans/pickup.md`.
  - `aapp refine issues "<msg>"`: Validates and commits updates to `.plans/ISSUES.md`.
- **Contract**: `lib/docs/verbs/refine.md`.

#### `aapp tdd <plan_or_slug>`
- **Description**: Injects or validates failure-first test sections: `### 🧪 Required Tests` in §3 and `### 🧪 Required Test Files` in §4.
- **Behavior**: Scaffolds a new TDD plan if slug does not exist, or upgrades an existing incubator blueprint.
- **Contract**: `lib/docs/verbs/tdd.md`.

#### `aapp plan [query]`
- **Description**: Interactive educational planning switchboard or query interface for active blueprints.
- **Contract**: `lib/docs/verbs/plan.md`.

#### `aapp plan-status [id]`
- **Description**: Read-only inspection of the state matrix or detailed metadata for a specific blueprint.
- **Contract**: `lib/docs/verbs/plan-status.md`.

#### `aapp matrix [check]`
- **Description**: Re-derives `.plans/state_matrix.md` from the `Status:` lines in `.plans/current/*.md`.
- **Options**: `check` audits state matrix consistency without writing (exits 0 if synced, 1 if drifted).
- **Contract**: `lib/docs/verbs/matrix.md`.

#### `aapp freeze <id>`
- **Description**: Locks blast radius and design into an immutable greenlight backlog specification (`🔷 Ready for Execution`).
- **Contract**: `lib/docs/verbs/freeze.md`.

#### `aapp start <id>`
- **Description**: Activates a frozen plan into implementation (`⚡ In Development`), checks disjointness, and binds the local execution buffer.
- **Contract**: `lib/docs/verbs/start.md`.

#### `aapp freeze-start <id>`
- **Description**: Atomically executes `freeze` followed immediately by `start` in a single command.
- **Contract**: `lib/docs/verbs/freeze-start.md`.

#### `aapp done <id>`
- **Description**: Archives an implemented plan to `.plans/done/`, verifies recorded commits and TDD assertions, updates archive ledgers, and cleans matrix.
- **Contract**: `lib/docs/verbs/done.md`.

#### `aapp commit "<message>" [agent <A> vendor <V> model <M>] [note "<text>"]`
- **Description**: Plan-bound commit helper. Commits staged code, appends semantic attribution trailers, and records commit SHA into active plan header.
- **Variants**:
  - `aapp commit amend ["<msg>"]`: Amends last commit and replaces recorded SHA in plan.
  - `aapp commit adopt <sha>...`: Adopts external commits into the active plan.
- **Contract**: `lib/docs/verbs/commit.md`.

#### `aapp active [id | swap | clear]`
- **Description**: Displays, swaps, or clears the local execution buffer pointer (`.git/aapp_active_plan`).
- **Contract**: `lib/docs/verbs/active.md`.

#### `aapp note [stage | show | push | pull]`
- **Description**: Manages developer review notes and private AI audit notes (`refs/notes/*`).
- **Contract**: `lib/docs/verbs/note.md`.

#### `aapp issue <log | fix | close | withdraw | list> ...`
- **Description**: Manages the flat issue ledger in `.plans/ISSUES.md`.
- **Variants**:
  - `aapp issue log <sev> <type> "<symptom>" [file <path>] [note "<text>"]`: Records and commits new issue.
  - `aapp issue fix <num>`: Creates dedicated fix worktree and mini-plan.
  - `aapp issue close <num>`: Closes issue and relocates row to `000-issues-archive.md`.
- **Contract**: `lib/docs/verbs/issue.md`.

#### `aapp offline [sync | status]`
- **Description**: Manages offline planning queue in `.offline/` when remote tracker or network is unreachable.
- **Contract**: `lib/docs/verbs/offline.md`.

#### `aapp companion <add | list | sync>`
- **Description**: Coordinates cross-repository planning for paired or multi-repo projects.
- **Contract**: `lib/docs/verbs/companion.md`.

#### `aapp test [filter] [strict] [quiet]`
- **Description**: Discovers and executes automated test suites with subshell isolation and assertion tracking.
- **Contract**: `lib/docs/verbs/test.md`.

#### `aapp help [verb] [full]`
- **Description**: Displays grouped verb catalog or detailed usage contract for a specific command.
- **Contract**: `lib/docs/verbs/help.md`.

#### `aapp ai <status | none | lax | strict | notes [on|off] | credits>`
- **Description**: Inspects or configures AI commit attribution mode and credits.
- **Contract**: `lib/docs/verbs/ai.md`.

---

### 2.2 Tier 2: Setup & Maintenance

#### `aapp init`
- **Description**: Initializes AAPP worktrees (`.plans`, `.agents`, `.githooks`), installs blast-radius guards, and configures default git settings.

#### `aapp install`
- **Description**: Installs AAPP globally into `~/.local/bin` and configures `PATH`.

#### `aapp upgrade`
- **Description**: Upgrades global AAPP installation and skill templates from upstream repository.

#### `aapp develop`
- **Description**: Links the current development repository clone globally via symlinks for local testing.

#### `aapp uninstall`
- **Description**: Removes global AAPP binaries, shell completions, and shared directories.

#### `aapp version`
- **Description**: Emits installed AAPP version (`-v`, `--version`).

#### `aapp release <version-or-bump> [check] [yes] [push] [unverified] [json]`
- **Description**: Milestone release bundling, changelog rollup, tag ledgers, and hook-based versioning.
- **Phases**:
  - Phase A (Pre-Flight): Verifies clean worktrees, test gate, signing config, changelog gate, reachability, and branch parity.
  - Phase B (Atomic Mutation): Dispatches `on-release`, rolls up changelog, moves completed plans to `.plans/release/<tag>/plans/`, creates tag ledger and manifests, merges to release branch, and tags release. Includes fail-closed rollback.

---

### 2.3 Tier 3: Team Sync & Emergency Controls

#### `aapp push`
- **Description**: Pushes active repository worktrees (`.plans`, `.agents`, `.githooks`) to remote.

#### `aapp pull`
- **Description**: Pulls remote updates for active worktrees with strict `--ff-only`.

#### `aapp sync`
- **Description**: Bi-directional worktree transport: executes `pull` followed by `push`.

#### `aapp pause [reason]`
- **Description**: Emergency brake: halts writes and quarantines in-flight uncommitted changes across mounted worktrees into Git stashes.

#### `aapp resume`
- **Description**: Disengages emergency brake, verifies upstream commit drift, and restores quarantined stashes.

---

### 2.4 Tier 4: Extensibility & Automation (Hooks & Plugins)

#### `aapp hooks`
- **Description**: Audits `.agents/skills/aapp-hooks/registry.tsv` and verifies SHA256 integrity of all registered entrypoints.

#### `aapp hook-test <event>`
- **Description**: Dry-run tests an event trigger with a mock envelope payload.

#### `aapp hook-run <event> [args...]`
- **Description**: Executes a registered lifecycle hook handler with live context.

#### `aapp hook-hash <path>`
- **Description**: Computes the canonical `sha256:...` checksum for a hook script to paste into `registry.tsv`.

#### `aapp plugins`
- **Description**: Discovers and inspects installed action plugins located in `.agents/skills/`.

---

## 3. Pure-Human Terminal Workflow

For developers who prefer direct CLI operations without conversational AI assistants:

```bash
# 1. Inspect morning recovery briefing
aapp status

# 2. Scaffold a new feature blueprint
aapp draft my-feature
# (Edit .plans/current/P20-my-feature.md: define Section 2 & Section 4)

# 3. Lock blast radius into greenlight backlog
aapp freeze P-20

# 4. Activate plan into development (binds buffer)
aapp start P-20

# 5. Commit implementation code under plan tracking
git add src/
aapp commit "feat(core): implement my-feature"

# 6. Archive completed blueprint
aapp done P-20
```

---

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- ⚙️ [Configuration Reference](03-configuration-matrix.md)
- 🍳 [Cookbook Catalog](../../COOKBOOK.md)
- 🏠 [Repository Overview](../../README.md)
