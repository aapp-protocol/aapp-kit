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
* **Attribution Engine:** Git semantic commit trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`) and native git notes across two fixed namespaces: `refs/notes/commits` (developer notes) and `refs/notes/ai` (AI traces).

---

## 📂 3. Global Structural Mapping
```text
├── aapp                   # Primary executable & CLI dispatcher
├── lib/                   # Operational command libraries & lifecycle modules
│   ├── aapp-lib.sh        # Shared pure-function library: plan parsing, globs, aapp_os (P-37)
│   ├── verbs.tsv          # Canonical CLI manifest; 5th column links daily verbs to their contracts
│   ├── docs/verbs/        # Per-verb behaviour contracts: ingress, failure modes, effects, tests (P-34)
│   ├── cmd_help.sh        # Tiered help generator parsing verbs.tsv
│   ├── cmd_init.sh        # Target resolution, orphan worktrees, rules & skills sync
│   ├── cmd_install.sh     # Global installer & signature-gated self-consumption
│   ├── cmd_plan.sh        # Active buffer manager, deterministic drafting & lifecycle triggers
│   ├── cmd_matrix.sh      # State matrix derivation engine (check & sync)
│   ├── cmd_pause.sh       # Emergency brake, multi-worktree stash quarantine & wake engine
│   ├── cmd_hook.sh        # Hook audit, event catalog discovery (events) & testing
│   ├── cmd_ai.sh          # AI attribution switchboard & credits manager
│   ├── cmd_note.sh        # Dedicated Git Notes engine & CLI handler (status, stage, push, pull) (P-44)
│   ├── attribution.sh     # AI identity resolution, decorator & note writer (P-40, P-44)
│   ├── cmd_status.sh      # 4-pillar context recovery agent briefing
│   ├── cmd_develop.sh     # Live editable development symlinking
│   ├── cmd_upgrade.sh     # Upstream release fetch and in-place upgrade
│   ├── cmd_uninstall.sh   # Global installation cleanup
│   ├── cmd_test.sh        # Unified test runner orchestrator & assertion aggregator
│   ├── plan_resolver.sh   # Plan ID standard (P-<num>) & shorthand resolver
│   ├── plan_states.sh     # Status registry: emoji, name, matrix heading & rank
│   └── planning_health.sh # 7-pair mechanical integrity validation engine
├── templates/             # Version-controlled hook engines and starter blueprints
│   ├── blast-radius-guard.sh # Layer 1 PreToolUse write-guard engine
│   ├── aapp-pre-commit    # Layer 2 Authoritative pre-commit engine
│   ├── aapp-lib.sh        # Symlink -> ../lib/aapp-lib.sh; init installs a real copy into .githooks/
│   ├── aapp-pre-commit-develop # Develop-only verb contract correspondence engine (seeded by aapp develop)
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
9. **Front-Door Repository Assertion & Fail-Closed Roots:** The `aapp` dispatcher asserts Git repository membership once, before dispatch, and exports `REPO_ROOT` for every sourced subcommand. Operational verbs invoked outside a repository exit 1 with a stderr diagnostic; only `version`, `help`, `install`, `uninstall`, `upgrade`, and `develop` are exempt. `init` requires an existing repository root and fails fast if invoked outside one. Subcommands must never re-derive the root with a silent `|| pwd` fallback, which substitutes `$PWD` and lets commands operate on an arbitrary directory. Libraries that also run standalone (`lib/plan_resolver.sh`, `lib/hook_dispatcher.sh`, `lib/planning_health.sh`, `lib/cmd_matrix.sh`) derive the root themselves and **fail closed** when there is none. Two of these deliberately derive from the current directory rather than inheriting `REPO_ROOT` — `allocate_plan_id()` because the ID counter is per-repository, and `cmd_matrix.sh` because it is executed directly — so a stale exported root cannot target the wrong repository. `REPO_ROOT` carries the *active worktree* root, so `--git-common-dir`/`PRIMARY_ROOT` resolution (Rule 2) remains necessary to locate `.plans` from a linked worktree.
10. **Runtime Reachability & Inspection-Only Invariant:** Cloned adopter repositories require an installed `aapp` toolchain in `$PATH` or `~/.local/bin`. If `aapp` is unreachable, `.githooks/aapp-pre-commit` locks commits in **Inspection-Only mode** to prevent un-guarded code changes, plan desynchronization, or blast-radius escapes. The reachability gate executes prior to any bypass flags (`SKIP_BLAST_RADIUS=1`); only Git's native `--no-verify` flag bypasses pre-commit.
11. **Shared Hook Library & Parser Boundaries (P-37):** `lib/aapp-lib.sh` is the single owner of plan-section parsing (`parse_plan_target_paths`, `parse_plan_oob_paths`, `extract_plan_section`), glob matching (`glob_to_regex`, `match_pattern_list`) and platform detection (`aapp_os`). It holds pure functions only — arguments or stdin in, stdout out, no top-level side effects. `lib/` is the only authored copy; `templates/aapp-lib.sh` is a tracked symlink to it, and `aapp init` installs a real copy into `.githooks/aapp-lib.sh` (from `$AAPP_LIB`, failing loudly if absent). Hooks source it from their own directory; kit modules source it relative to their own file, never via `$AAPP_LIB`. Every consumer asserts the `aapp_lib_loaded` sentinel and refuses when it is missing — the write-guard through `deny_action` (exit 2), since a PreToolUse exit 1 would let the write through. Parser boundaries: target and Out of Bounds headings count only inside `## 💥 4.`, match by full name (`Target Files`, `Emergency Hotfix Extensions`, `Required Test Files` grant writes; `Out of Bounds` vetoes), any other heading ends the region, fenced blocks and `>` lines are never parsed. Add no inline section parser elsewhere; `tests/aapp_lib_test.sh` fails on one. Known exception: Pair 5 (#86).
12. **Verb Behaviour Contracts (P-34):** Each daily verb's behaviour is specified once, at `lib/docs/verbs/<verb>.md` (Ingress, Preconditions, Failure modes, Effects, Exit, Tests), and `lib/verbs.tsv` links it in a fifth `contract` column so agents reach the contract in the same read as the registry. The contract is the source of truth; tests in `tests/verbs/<verb>.sh` are derived from it, failure modes first, and current code that violates a line is marked `⚠️ Divergence` in the contract rather than described as intended. Correspondence is bidirectional and fail-closed (`tests/verb_contracts_test.sh`): every daily row names an existing contract, every contract has exactly one row, every declared test exists. `aapp develop` seeds `.githooks/aapp-pre-commit-develop` to run that check on commits touching the registry, contracts or verb suites; `aapp init` never seeds it. `aapp help` stays user-facing and never renders contracts.
13. **Opt-In Failure Test Declaration & TDD Gate (P-35):** Plans may opt into failure-first testing via `aapp tdd <id>`. Declarations split across two sections: `### 🧪 Required Tests (Failure & Boundary Assertions)` in §3 holds tickable assertions (`path::name -> asserts <condition>`), while `### 🧪 Required Test Files` in §4 is design-locked at freeze time and grants write access under Option A single-entry semantics without redundant entry in Target Files. Section 4 is the sole authoritative trigger: plans without it are completely unaffected. Pre-commit tolerates empty sections, mismatches, and unwritten files during `📝 Refining`, but strictly enforces mutual correspondence and non-emptiness at `🔷 Frozen` and `⚡ In Development` (with disk existence enforced at `⚡`). `cmd_done` provides a mechanical completion gate: all §3 assertions must be ticked (`- [x]`), declared test files must exist on disk and be tracked in Git, and verified evidence is recorded as `tdd (N/N)` in the archive ledger.
14. **Attribution Policy Tiers & Single Identity Layer (P-40):** Attribution mode is governed by `aapp.aiAttribution` across four discrete tiers: `none` (default; pure human authoring; trailers refused), `lax` (opt-in mixed human/AI work, trailers validated when present, human commits pass freely without trailers), `strict` (mandatory valid emailless trailers on every commit), and `notes` (private git notes in `refs/notes/commits`, trailers in commit messages refused). The legacy `commit` mode is retired and refused loudly at commit time with actionable migration advice (`aapp ai lax` or `aapp ai strict`). `lib/attribution.sh` is the single authoritative identity layer (`resolve_ai_identity`, `attribution_decorate`, `attribution_note`) used across CLI verbs and lifecycle triggers; no verb constructs trailers or notes by hand. Identity resolution respects strict precedence: parameters > environment (`AAPP_AGENT_*`) > per-worktree git config (`aapp.aiAgent`, `aapp.aiVendor`, `aapp.aiModel`); plain repository config is never read to avoid cross-worktree bleed. Synthetic vendor emails in `Co-authored-by:` are strictly blocked across all modes.
15. **Plan-Bound Commit Helper & Unified Lifecycle Commit Engine (P-39):** Implementation commits during active execution are bound to plans via the `aapp commit` helper (`lib/cmd_commit.sh`). The helper commits only staged code in the working tree, attributes via P-40's identity layer (`lib/attribution.sh`), records `sha (branch)` in the active plan's `* **Commits:**` header, and commits the plan file alone via `lib/commit_engine.sh`. `plans_commit` provides a single authoritative commit engine for all `.plans` commits (lifecycle verbs `draft`, `freeze`, `start`, `freeze-start`, `done`, and helper recordings), enforcing explicit pathspec staging (`git commit -- <paths>`), lock-retry resilience, attribution decoration, and loud failures without `|| true`. `aapp done` enforces that an active plan has at least one recorded reachable commit, eliminating guessed `HEAD` recording. Discipline is taught via plan template execution invariants and warning-only pre-commit reminders when raw `git commit` is detected outside the helper.
16. **General-Purpose Git Notes Subsystem (P-44):** Git notes operate across two strictly isolated namespaces: `refs/notes/commits` (developer notes) and `refs/notes/ai` (AI traces). Notes are appended non-destructively on amend without error suppression. Remote sync is opt-in via `aapp.notesRemote` with `union` merge strategy by default to prevent notes loss. The audit guard (`aapp.aiNotesGuard`, `warn` or `enforce`) audits lossless configuration (`notes.rewriteRef`, `notes.rewriteMode concatenate`) and surfaces actionable warnings.

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

**Issue IDs follow the same model (P-32).** `aapp.issueId` is a second, independent counter (`#32` and `P-32` may both exist), seeded by `aapp init` from both `ISSUES.md` and the archive, and optionally served by an `aapp-issue` provider. Both kinds share one allocation core in `lib/plan_resolver.sh`. Closing is mechanical: `aapp issue close` and `aapp done` relocate the row and prune the road map, then notify the provider fire-and-forget, since the local ledgers are authoritative. Duplicates are caught by Pair 1 (across ledgers) and Pair 8 (within one ledger).

