# 🏛️ System Architecture Overview: Agent Planning Kit (AAPP)

> **Rule for All Agents:** Read this document at the start of every session to align with the core design patterns, structural choices, and technology rules of this project. Do NOT introduce frameworks, libraries, or global state patterns that violate this blueprint.

---

## 🚀 1. Executive Summary & Philosophy
* **Primary Purpose:** Asymmetric Agent Planning Protocol (AAPP) — a deterministic, low-dependency protocol decoupling planning, agent behavioral rules, and git enforcement hooks from application code using isolated Git worktrees and dual-layer blast radius enforcement.
* **Core Pillars:**
  * **Worktree Isolation:** Blueprints (`plans`), agent behavioral rules (`agents`), and enforcement hooks (`githooks`) reside on isolated orphan git branches, keeping design text completely decoupled from active application code branches.
  * **Dual-Layer Blast Radius Enforcement:** Layer 1 write-time interception (PreToolUse hook) prevents out-of-bounds file edits before touching disk; Layer 2 authoritative pre-commit gate blocks unauthorized staged commits.
  * **Single-Active-Plan Architecture:** Per-worktree execution pointer buffers (`$(git rev-parse --git-path aapp_active_plan)`) eliminate cross-plan interference and enable deterministic parallel multi-agent workflows.
  * **Master Emergency Brake & Multi-Worktree State Preserver ("Hibernate & Wake"):** Circuit Breaker (`aapp pause`, `aapp resume`) quarantines in-flight changes into SHA-addressed stashes across dynamically discovered worktrees, blocks codebase modifications, and safely wakes with drift forensics.
  * **Zero Non-Core Dependencies:** Pure POSIX shell and git plumbing, with optional Python for fast-path JSON serialization and complete POSIX fallback.

---

## ⚙️ 2. Technology Stack & Runtime
* **Core Language Runtime:** Pure POSIX Bash (3.2+), Git (2.20+), optional Python 3.8+ for JSON parsing in write-guard.
* **Dependencies:** Zero external npm, pip, or binary packages. Standard POSIX utilities only (`grep`, `sed`, `awk`, `find`, `mktemp`).
* **Attribution Engine:** Git semantic commit trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`) and native git notes (`refs/notes/commits`).

---

## 📂 3. Global Structural Mapping
```text
├── aapp                   # Primary executable & CLI dispatcher
├── lib/                   # Operational command libraries & lifecycle modules
│   ├── verbs.tsv          # Canonical zero-dependency CLI manifest (32 verbs across 5 tiers)
│   ├── cmd_help.sh        # Tiered help generator parsing verbs.tsv
│   ├── cmd_init.sh        # Target resolution, orphan worktrees, rules & skills sync
│   ├── cmd_install.sh     # Global installer & signature-gated self-consumption
│   ├── cmd_plan.sh        # Active buffer manager, deterministic drafting & lifecycle triggers
│   ├── cmd_matrix.sh      # State matrix derivation engine (check & sync)
│   ├── cmd_pause.sh       # Emergency brake, multi-worktree stash quarantine & wake engine
│   ├── cmd_hook.sh        # Hook audit, event catalog discovery (--events) & testing
│   ├── cmd_ai.sh          # AI attribution switchboard & credits manager
│   ├── cmd_status.sh      # 4-pillar context recovery agent briefing
│   ├── cmd_develop.sh     # Live editable development symlinking
│   ├── cmd_upgrade.sh     # Upstream release fetch and in-place upgrade
│   ├── cmd_uninstall.sh   # Global installation cleanup
│   ├── plan_resolver.sh   # Plan ID standard (P-<num>) & shorthand resolver
│   ├── plan_states.sh     # Status registry: emoji, name, matrix heading & rank
│   └── planning_health.sh # 7-pair mechanical integrity validation engine
├── templates/             # Version-controlled hook engines and starter blueprints
│   ├── blast-radius-guard.sh # Layer 1 PreToolUse write-guard engine
│   ├── aapp-pre-commit    # Layer 2 Authoritative pre-commit engine
│   ├── aapp-commit-msg    # Commit-msg conciseness & trailer validator
│   ├── aapp-post-commit   # Post-commit Option C staged note attacher
│   ├── plan-template.md   # ADR-style blueprint template
│   ├── state_matrix.md    # Active plan lane & incubator brain
│   ├── issues.md          # Active flat defect table template
│   ├── issues_road_map.md # Human defect priority board template
│   ├── done-issues-archive.md # Relocated defect archive template
│   ├── 000-archive-ledger.md  # Master architectural archive ledger template
│   └── skills/            # Universal AAPP lifecycle skills
├── tests/                 # Automated test suites (369 passing test cases)
│   ├── test_helpers.sh    # Shared test harness: sandbox confinement & identity inheritance
│   ├── install_test.sh    # CLI, init, drop-in, adoption, installer & worktree tests
│   ├── write-guard_test.sh# Layer 1 write-guard, allowlists, single-plan isolation
│   ├── pre-commit_test.sh # Layer 2 pre-commit, design-lock, changelog, isolation
│   ├── worktree_hooks_test.sh # Worktree hook execution & attribution regression suite
│   ├── hooks_test.sh      # Lifecycle hooks & plugins engine tests
│   ├── sync_test.sh       # Remote worktree synchronization & transport tests
│   ├── plan_resolver_test.sh # Plan ID resolution, pairs 4, 5, 6
│   └── ai_attribution_test.sh # Switchboard, trailers, Option C notes, credits
├── scripts/               # Migration and maintenance utilities
│   └── scrub-attribution.sh # Attribution migration & SHA repair utility
├── .plans/                # Isolated planning worktree (mounted on branch 'plans')
│   ├── current/           # Active blueprints (P<N>-<slug>.md)
│   ├── done/              # Archived blueprints & 000-archive-ledger.md
│   ├── ISSUES.md          # Canonical active defect ledger (Relocation Invariant)
│   ├── issues_road_map.md # Defect sequence & human priority board
│   ├── pickup.md          # Raw unworked scratchpad queue
│   └── state_matrix.md    # Active plan roadmap & incubator state matrix
├── .agents/               # Behavioral rules & codemap worktree (branch 'agents')
│   ├── AGENTS.md          # Agent behavioral contracts & lifecycle rules
│   ├── CODEMAP.md         # Canonical code map & module ownership
│   ├── PROJECT.MD         # Project roadmap, milestones & agent personas
│   ├── ARCHITECTURE.md    # Invariant architecture & structural mapping
│   ├── claude/            # Versioned Claude Code settings (settings.json)
│   └── skills/            # Universal skills bridged to .claude/skills/
├── .claude/               # Gitignored Claude Code bridge (relative symlinks)
├── .githooks/             # Blast radius enforcement worktree (branch 'githooks')
├── CHANGELOG.md           # Public release notes & keep-a-changelog ledger
├── README.md              # Project overview & quick start guide
├── MANUAL.md              # Comprehensive manual & technical reference
├── CHEATSHEET.md          # 1-page cheatsheet for human & agent reference
└── ARCHITECTURE.md        # System architecture overview & invariants
```

---

## 🚦 4. Invariant Architectural Rules
1. **Zero Reinvention:** Always check `.agents/CODEMAP.md` before creating helper functions or commands.
2. **Path Resolution Single Source of Truth:** Resolve repository root via `git rev-parse --show-toplevel` or git common directory (`--git-common-dir`). Master wrappers and hook dispatchers navigate via `git rev-parse --git-common-dir` so hooks execute identically in linked worktrees (`.plans`, `.agents`) and primary code branches. Never use brittle relative paths (`../../`).
3. **Never Edit Hook Targets Directly:** Never edit `.githooks/*` directly; edit `templates/` and run `aapp init` to propagate.
4. **Frozen Plan Immutability:** Once a blueprint is `🔷 Frozen`, its technical blueprint (§2) and blast radius (§4) are locked. Unfreezing requires explicit reversion to `📝 Refining`.
5. **Two-Lane Boundary:** Never merge bugs into `state_matrix.md` or raw feature requests into `issues_road_map.md`. Large bug fixes are promoted to blueprints via `digest ISSUE-00X`.
6. **Documentation Synchronization:** Every implementation introducing new files, interfaces, or architectural contracts must update `ARCHITECTURE.md` and `.agents/CODEMAP.md`.
7. **Test Harness Sandbox Confinement:** All test fixtures must source `tests/test_helpers.sh` and execute `assert_test_sandbox()` before running test logic to verify that operations remain strictly confined to temporary disposable directories. Identity configuration in test sandboxes inherits developer name/email while explicitly disabling GPG signing (`gpgsign false`) for headless, non-interactive execution.
8. **Linked Worktree Hook Defense-in-Depth:** Worktrees mount `.githooks` symlinks (`.plans/.githooks -> ../.githooks`) and dispatchers resolve the primary project root via `--git-common-dir`, ensuring attribution checks, conciseness invariants, and commit policies protect commits in all worktrees. Symlinks are explicitly ignored in `.plans/.gitignore` and `.agents/.gitignore` to prevent orphan branch pollution.

## Plan State: Derived, Not Maintained

`.plans/state_matrix.md` was historically **hand-maintained**: each lifecycle verb patched a row's status emoji in place, and nothing reconciled the file against the blueprints it described. Because the emoji was rewritten where the row already sat, a plan could be frozen or started without ever leaving its old section — a frozen badge under the Incubator. Section headings were also parsed by `cmd_status.sh` with hardcoded `awk` anchors, which returned silently empty once an adopter's headings diverged from the template.

Plan state is now **derived**: the `**Status:**` line inside each `.plans/current/*.md` is authoritative, and the matrix is regenerated from it.

* **One registry.** `lib/plan_states.sh` declares every status — emoji, canonical name, generated section heading, sort rank. Matching is by canonical name, never by glyph, so presentation and semantics stay separable. Adopters add statuses through `git config aapp.planState.<slug>`; a malformed entry warns and is skipped rather than breaking status output.
* **Headings generated, not parsed.** Sections and their order come from the registry, so no code anchors on heading text and adopter divergence cannot silently break resolution.
* **Population is `current/` only.** A plan that has left `current/` has no row; the archive ledger is terminal. Orphan rows vanish as a consequence of derivation rather than by special-case deletion.
* **Human content is preserved.** The Roadmap block is carried verbatim (priority ordering is human judgement, never derived) and each row's annotation after the first em-dash is reattached by Plan ID, so notes follow a plan across sections.
* **No silent loss.** A status matching no registry entry is reported in a visible *Unrecognized* section by both `aapp matrix` and `aapp plan-status`, instead of being folded into the Incubator where a typo would hide.
* **One engine, many callers.** `lib/cmd_matrix.sh` implements a single check-and-sync, invoked by `aapp matrix`, by `aapp status` before it reads the matrix, and by `draft` / `freeze` / `freeze-start` / `start` before they stage a lifecycle commit. Sourcing it with `AAPP_MATRIX_LIB_ONLY=1` loads the functions without executing the command.
* **Pause-aware.** The pause allowlist admits only `.plans/` pickup, issues and `current/` paths, so a matrix written while paused cannot be committed. The sync writes anyway and says the commit waits for `aapp resume`: the uncommitted diff is the record of how the board moved during the pause.

## Plan Identity: Stored, Not Derived

Plan IDs were historically **derived** on demand by scanning blueprint filenames, plan headers, and the archive ledger, taking the maximum and adding one. That made allocation depend on parse correctness, and a single malformed regex (`#69`) was enough to break it entirely.

Identity is now **stored**: `aapp.planId` in git config holds the next id to hand out, as a bare integer. The `P-` prefix is a namespace marker applied on output to distinguish a plan id from an issue id (`#69`), never part of the value.

* **Monotonic.** The counter only moves forward, so an id is never reused — including ids belonging to plans that were archived, pruned, or abandoned into `.plans/aborted/`.
* **Seeded once.** `aapp init` scans the filesystem exactly once to bootstrap the counter (`1` on a new project). A numeric value is thereafter left alone, so repeat `init` — including the init that follows `aapp upgrade` — never disturbs a live counter.
* **Extensible.** A repository with more than one contributor installs an `aapp-planid` action plugin at `.agents/skills/aapp-planid/` to source ids from a central authority. Only plugin *absence* falls back to the local counter; a plugin that is present and fails aborts allocation rather than silently issuing a local id.
* **Bounded.** The core defines only the provider contract — emit an id, exit non-zero to refuse. Provider internals, dependencies and credentials are the adopter's responsibility and are never inspected.

`check_pair4_plan_id_integrity` remains the independent detector for duplicate ids, unchanged and deliberately decoupled from the counter.

