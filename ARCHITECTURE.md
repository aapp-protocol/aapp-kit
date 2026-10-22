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
│   ├── adoption.sh        # Adoption rules catalogue, sync engine & open-task counter (P-63)
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
│   ├── cmd_release.sh     # Milestone release bundling, tag ledgers & hook-based versioning (P-38)
│   ├── plan_resolver.sh   # Plan ID standard (P-<num>) & shorthand resolver
│   ├── plan_states.sh     # Status registry (emoji, name, matrix heading & rank) & Status-line accessors
│   └── planning_health.sh # 7-pair mechanical integrity validation engine
├── templates/             # Version-controlled hook engines and starter blueprints
│   ├── blast-radius-guard.sh # Layer 1 PreToolUse write-guard engine
│   ├── aapp-pre-commit    # Layer 2 Authoritative pre-commit engine
│   ├── aapp-lib.sh        # Shared pure-function library for hook engines
│   ├── aapp-pre-commit-develop # Develop-only verb contract correspondence engine (seeded by aapp develop)
│   ├── aapp-commit-msg    # Commit-msg conciseness & trailer validator
│   ├── aapp-post-commit   # Post-commit Option C staged note attacher
│   ├── plan-template.md   # ADR-style blueprint template
│   ├── adoption.md        # Starter adoption checklist template (P-63)
│   ├── state_matrix.md    # Active plan lane & incubator brain
│   ├── issues.md          # Active flat defect table template
│   ├── issues_road_map.md # Work queue template (plan blockers, queued issues)
│   ├── 000-issues-archive.md # Relocated defect archive template
│   ├── 000-archive-ledger.md  # Master architectural archive ledger template
│   └── skills/            # Universal AAPP lifecycle skills
├── tests/                 # Automated test suites (modular regression, hook & lifecycle suites)
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
│   ├── scrub-attribution.sh # Attribution migration & SHA repair utility
│   └── kit-on-release.sh  # Kit self-release on-release action delegate hook (P-59)
├── .plans/                # Isolated planning worktree (mounted on branch 'plans')
│   ├── current/           # Active blueprints (P<N>-<slug>.md)
│   ├── done/              # Archived blueprints & 000-archive-ledger.md
│   ├── release/           # Milestone release bundle directories (P-38)
│   ├── ISSUES.md          # Canonical active defect ledger (Relocation Invariant)
│   ├── issues_road_map.md # Work queue: plan blockers and issues queued for work
│   ├── pickup.md          # Raw unworked scratchpad queue
│   ├── adoption.md        # Local, untracked per-clone setup checklist (P-63)
│   └── state_matrix.md    # Active plan roadmap & incubator state matrix
├── .agents/               # Behavioral rules & codemap worktree (branch 'agents')
│   ├── AGENTS.md          # Agent behavioral contracts & lifecycle rules
│   ├── CODEMAP.md         # Canonical code map & module ownership
│   ├── PROJECT.MD         # Project roadmap, milestones & agent personas
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

### Code & Paths

#### Zero Reinvention
Always check `.agents/CODEMAP.md` before creating helper functions or commands.

#### Path Resolution Single Source of Truth
Resolve repository root via `git rev-parse --show-toplevel` or git common directory (`--git-common-dir`). Master wrappers and hook dispatchers navigate via `git rev-parse --git-common-dir` so hooks execute identically in linked worktrees (`.plans`, `.agents`) and primary code branches. Never use brittle relative paths (`../../`).

#### Front-Door Repository Assertion & Fail-Closed Roots
The `aapp` dispatcher asserts Git repository membership once, before dispatch, and exports `REPO_ROOT` for every sourced subcommand. Operational verbs invoked outside a repository exit 1 with a stderr diagnostic; only `version`, `help`, `install`, `uninstall`, `upgrade`, and `develop` are exempt. `init` requires an existing repository root and fails fast if invoked outside one. Subcommands must never re-derive the root with a silent `|| pwd` fallback, which substitutes `$PWD` and lets commands operate on an arbitrary directory. Libraries that also run standalone (`lib/plan_resolver.sh`, `lib/hook_dispatcher.sh`, `lib/planning_health.sh`, `lib/cmd_matrix.sh`) derive the root themselves and **fail closed** when there is none. Two of these deliberately derive from the current directory rather than inheriting `REPO_ROOT` — `allocate_plan_id()` because the ID counter is per-repository, and `cmd_matrix.sh` because it is executed directly — so a stale exported root cannot target the wrong repository. `REPO_ROOT` carries the *active worktree* root, so `--git-common-dir`/`PRIMARY_ROOT` resolution (*Path Resolution Single Source of Truth*) remains necessary to locate `.plans` from a linked worktree.

#### Runtime Reachability & Inspection-Only Invariant
Cloned adopter repositories require an installed `aapp` toolchain in `$PATH` or `~/.local/bin`. If `aapp` is unreachable, `.githooks/aapp-pre-commit` locks commits in **Inspection-Only mode** to prevent un-guarded code changes, plan desynchronization, or blast-radius escapes. The reachability gate executes prior to any bypass flags (`SKIP_BLAST_RADIUS=1`); only Git's native `--no-verify` flag bypasses pre-commit.

#### Shared Hook Library & Parser Boundaries (P-37)
`lib/aapp-lib.sh` is the single owner of plan-section parsing (`parse_plan_target_paths`, `parse_plan_oob_paths`, `extract_plan_section`), plan and group progress (`plan_progress`), glob matching (`glob_to_regex`, `match_pattern_list`) and platform detection (`aapp_os`). It holds pure functions only — arguments or stdin in, stdout out, no top-level side effects. `lib/` is the only authored copy; `templates/aapp-lib.sh` is a tracked symlink to it, and `aapp init` installs a real copy into `.githooks/aapp-lib.sh` (from `$AAPP_LIB`, failing loudly if absent), with `plan_states.sh` beside it: the library loads the status registry from its own directory (through the symlink's target in `templates/`) and does not load without it. Hooks source it from their own directory; kit modules source it relative to their own file, never via `$AAPP_LIB`. Every consumer asserts the `aapp_lib_loaded` sentinel and refuses when it is missing — the write-guard through `deny_action` (exit 2), since a PreToolUse exit 1 would let the write through. Parser boundaries: target and Out of Bounds headings count only inside `## 💥 4.`, match by full name (`Target Files`, `Required Test Files` grant writes; `Out of Bounds` vetoes), any other heading ends the region, fenced blocks and `>` lines are never parsed. Add no inline section parser elsewhere; `tests/aapp_lib_test.sh` fails on one. Known exception: Pair 5 (#86).

### Hooks & Enforcement

#### Never Edit Hook Targets Directly
Never edit `.githooks/*` directly; edit `templates/` and run `aapp init` to propagate.

#### Linked Worktree Hook Defense-in-Depth
Worktrees mount `.githooks` symlinks (`.plans/.githooks -> ../.githooks`) and dispatchers resolve the primary project root via `--git-common-dir`, ensuring attribution checks, conciseness invariants, and commit policies protect commits in all worktrees. Symlinks are explicitly ignored in `.plans/.gitignore` and `.agents/.gitignore` to prevent orphan branch pollution.

#### Hook Security, Integrity & Trust Model
Autonomous agent execution of lifecycle hooks is governed by a strict 5-layer defense-in-depth model:

- **Layer 0 (OS Permissions & Binary Separation):** Hook scripts may reside outside the workspace or be owned by a separate user (`root` or CI service account) with read-only permissions (`chmod 555`) to prevent in-process tampering.
- **Layer 1 (PreToolUse Write Interception):** `.githooks/blast-radius-guard` blocks agent edits to hook engine components and `.agents/skills/*` out-of-bounds.
- **Layer 2 (Authoritative Pre-Commit Boundary):** `.githooks/aapp-pre-commit` rejects unauthorized changes staged outside active plan blast radius.
- **Layer 3 (Cryptographic SHA-256 Pinning):** `.agents/skills/aapp-hooks/registry.tsv` pins handler SHAs. In `mode=gate`, any unpinned, missing, or altered handler causes immediate execution refusal with exit code 1.
- **Layer 4 (Watchdog Timeout & Sandboxed Execution):** All hooks run under a deterministic process watchdog timeout (`aapp.hookTimeout`, default 10s, terminating with exit code 124) with isolated environments (`stdin` JSON envelope + exported `AAPP_*` metadata).

### Documentation & Contracts

#### Documentation Synchronization
Every implementation introducing new files, interfaces, or architectural contracts must update `ARCHITECTURE.md` and `.agents/CODEMAP.md`.

#### Verb Behaviour Contracts (P-34)
Each daily verb's behaviour is specified once, at `lib/docs/verbs/<verb>.md` (Ingress, Preconditions, Failure modes, Effects, Exit, Tests), and `lib/verbs.tsv` links it in a fifth `contract` column so agents reach the contract in the same read as the registry. The contract is the source of truth; tests in `tests/verbs/<verb>.sh` are derived from it, failure modes first, and current code that violates a line is marked `⚠️ Divergence` in the contract rather than described as intended. Correspondence is bidirectional and fail-closed (`tests/verb_contracts_test.sh`): every daily row names an existing contract, every contract has exactly one row, every declared test exists. `aapp develop` seeds `.githooks/aapp-pre-commit-develop` to run that check on commits touching the registry, contracts or verb suites; `aapp init` never seeds it. `aapp help` stays user-facing and never renders contracts.

#### Three-Tier Document Governance & Delimited Template Sync (P-25)
Repository templates are categorized into three distinct operational tiers to prevent protocol drift without destroying project-specific customization:

- **Tier 1 (Pure Reusable Templates):** Scaffold assets (`.plans/plan-template.md`, `.plans/release/release_checklist.md`, `.plans/done/000-archive-ledger.md`) kept synchronized with canonical protocol invariants. When diverged without delimiters in `safe` mode, writes a `.new` buffer rather than overwriting.
- **Tier 2 (Hybrid Governance Documents):** Core protocol blocks synchronized strictly within HTML delimiters (`<!-- AAPP-PROTOCOL:START -->` ... `<!-- AAPP-PROTOCOL:END -->`) in `.agents/AGENTS.md` and `.plans/pickup.md`, preserving surrounding custom rules and user ideas.
- **Tier 3 (Pure Project Domain Data):** Live ledgers and project ownership docs (`.plans/ISSUES.md`, `.plans/state_matrix.md`, `.plans/issues_road_map.md`, `.agents/CODEMAP.md`, `.agents/PROJECT.MD`, `ARCHITECTURE.md`) are seeded once on initial install and never overwritten during template sync.

Template drift is probed by `aapp status` directing maintainers to `aapp init`.

#### Continuous Documentation Navigation Invariant
All high-level architectural documentation assets (`ARCHITECTURE.md`, `MANUAL.md`, `CHEATSHEET.md`, `CODEMAP.md`) and workflow cookbooks must maintain continuous bidirectional navigation links without dead-ends.

#### Kit Release Lifecycle Hook & Version Synchronizer (P-59)
The AAPP Kit dogfoods its lifecycle hook engine by implementing `scripts/kit-on-release.sh` as an `on-release` action delegate. During `aapp release`, it extracts `AAPP_RAW_VERSION` via Dual Delivery (env + STDIN JSON) and atomically synchronizes `AAPP_VERSION` in the `aapp` CLI executable and advances `<!-- AAPP-PROTOCOL:START v<version> -->` delimiter blocks across all starter templates in `templates/` (`templates/AGENTS.md`, `templates/plan-template.md`, `templates/pickup.md`, `templates/release_checklist.md`, `templates/amendments-template.md`).


### Testing

#### Test Harness Sandbox Confinement
All test fixtures must source `tests/test_helpers.sh` and execute `assert_test_sandbox()` before running test logic to verify that operations remain strictly confined to temporary disposable directories. Identity configuration in test sandboxes inherits developer name/email while explicitly disabling GPG signing (`gpgsign false`) for headless, non-interactive execution.

#### Opt-In Failure Test Declaration & TDD Gate (P-35)
Plans may opt into failure-first testing via `aapp tdd <id>`. Declarations split across two sections: `### 🧪 Required Tests (Failure & Boundary Assertions)` in §3 holds tickable assertions (`path::name -> asserts <condition>`), while `### 🧪 Required Test Files` in §4 is design-locked at freeze time and grants write access under Option A single-entry semantics without redundant entry in Target Files. Section 4 is the sole authoritative trigger: plans without it are completely unaffected. Pre-commit tolerates empty sections, mismatches, and unwritten files during `📝 Refining`, but strictly enforces mutual correspondence and non-emptiness at `🔷 Frozen` and `⚡ In Development` (with disk existence enforced at `⚡`). `cmd_done` provides a mechanical completion gate: all §3 assertions must be ticked (`- [x]`), declared test files must exist on disk and be tracked in Git, and verified evidence is recorded as `tdd (N/N)` in the archive ledger.

### Plans

#### Frozen Plan Immutability
Once a blueprint is `🔷 Frozen`, its technical blueprint (§2) and blast radius (§4) are locked. Unfreezing requires explicit reversion to `📝 Refining`.

#### Plan Worktrees (P-54)
Opt-in (`aapp.planWorktrees`): a plan's first `start`/`freeze-start` creates its own branch (`--no-track`, from the resolved development branch, `aapp_dev_branch`) and worktree, and binds the plan in that worktree's buffer only. The kit reaches the worktree through relative symlinks (`.githooks`, `.agents`, `.plans`, `.claude`) excluded via the common `info/exclude`, never copies, so there is still one plan store and one hook engine. Creation is a transaction (`_wt_start` in `lib/cmd_plan.sh`): worktree → links → bind → `on-start` (may rename/move) → read-back → record `Worktree:`/`Base:` → commit, with a snapshot rollback on any failure. Issue fixes stay on the development branch (`issue fix` refuses inside a plan worktree); plans take fixes by rebase only. A `post-rewrite` hook (`templates/aapp-post-rewrite`, carrying `commit_engine.sh` into `.githooks`) keeps `Commits:` true across rebase and amend. `done` integrates only when asked (P-55): with `aapp.integrate` = `squash`/`ff`/`hook` (seeded `manual`) or the `integrate` token, a worktree plan is merged into its parent branch, the branch in its `Base:` (`resolve_plan_integrate_target`), after all checks ran before the archive (ancestry, clean main checkout, open issue fix under the issue lock, hotfix cap, a registered `on-integrate` for `hook`); the mutating engine (`_ig_*` in `lib/cmd_plan.sh`) runs after the archive commit and is safe to retry; cleanup refuses when sensitive ignored files would be deleted unless they are quarantined into the git common dir.

#### Plan Groups (P-64)
A group plan (`# 🧩 Group Plan P-<n>:`, the one marker verbs read) is a planning container for several member plans (`* **Group:**`, listed in its `* **Members:**`, its amendments member last). `ARCHITECTURE.md` and `CODEMAP.md` changes live whole in the group plan and are applied by heading (`lib/group_docs.sh`), guarded by checksum base lines; members never edit them. Groups do not nest. Fixes stay on the development branch, except group-caused ones (`issue fix … group`), which land on the feature branch. Its lifecycle (feature branch, members, ownership, the amendments member, `done`) is *Group Lifecycle: Ownership, Amendments, Done (P-103)*.

#### Plan Conflict Audit (P-65)
`aapp plan conflict-check` / `conflict-free` answer, before any `start`, which plans can be in development at the same time, by the same rule the activation gate enforces (exact Target File overlap, shared docs exempt). For a group they order the members into waves for parallel agents. Read-only: they never change plans or the matrix.

#### Plan Abort (P-69)
`aapp plan abort <id>` is the second way out of `.plans/current/`: `done` without the code. Every refusal comes before any change; the archive to `.plans/aborted/` (plan, `000-aborted-ledger.md`, issue row, matrix) is one commit under the snapshot `done` uses; the worktree and branch go only after that commit lands. The direction is one-way: a plan's abort hands its Target Issue back as 🟡 `Incubated` and never closes or withdraws it. A plan without its own worktree keeps its commits; nothing is reverted. A group plan's abort removes the whole group (open members, feature branch) after a confirmation.

#### A Plan Closes Further Issues (P-86)
Besides its `Target Issue`, a plan may list issues it sorts by the way in its header, `* **Also Closes:**`, written only by `aapp refine <plan> closes <num> [remove]` (`plan_also_closes` reads it). The listed rows are not touched: such a plan is not a plan for those issues, is never squashed because of them, and anyone may close them first. `done` archives each listed issue still open with the commit the plan is recorded with, in the plan's archive commit, by the same functions as the `Target Issue` (`ledger_archive_row`, `issue_unblock_plans`, `issue_notify_close`); an issue whose branch neither is the plan's parent nor holds the commit stays open (P-78). Several issues may share one commit; each issue still names exactly one. The tracker sync counts listed issues among those the plans depend on (`_issue_dependent_ids`).

### Commits & Integration

#### Attribution Policy Tiers & Single Identity Layer (P-40)
Attribution mode is governed by `aapp.aiAttribution` across four discrete tiers: `none` (default; pure human authoring; trailers refused), `lax` (opt-in mixed human/AI work, trailers validated when present, human commits pass freely without trailers), `strict` (mandatory valid emailless trailers on every commit), and `notes` (private git notes in `refs/notes/commits`, trailers in commit messages refused). The legacy `commit` mode is retired and refused loudly at commit time with actionable migration advice (`aapp ai lax` or `aapp ai strict`). `lib/attribution.sh` is the single authoritative identity layer (`resolve_ai_identity`, `attribution_decorate`, `attribution_note`) used across CLI verbs and lifecycle triggers; no verb constructs trailers or notes by hand. Identity resolution respects strict precedence: parameters > environment (`AAPP_AGENT_*`) > per-worktree git config (`aapp.aiAgent`, `aapp.aiVendor`, `aapp.aiModel`); plain repository config is never read to avoid cross-worktree bleed. Synthetic vendor emails in `Co-authored-by:` are strictly blocked across all modes.

#### Plan-Bound Commit Helper & Unified Lifecycle Commit Engine (P-39)
Implementation commits during active execution are bound to plans via the `aapp commit` helper (`lib/cmd_commit.sh`). The helper commits only staged code in the working tree, attributes via P-40's identity layer (`lib/attribution.sh`), records `sha (branch)` in the active plan's `* **Commits:**` header, and commits the plan file alone via `lib/commit_engine.sh`. `plans_commit` provides a single authoritative commit engine for all `.plans` commits (lifecycle verbs `draft`, `freeze`, `start`, `freeze-start`, `done`, and helper recordings), enforcing explicit pathspec staging (`git commit -- <paths>`), lock-retry resilience, attribution decoration, and loud failures without `|| true`. `aapp done` enforces that an active plan has at least one recorded reachable commit, eliminating guessed `HEAD` recording. Discipline is taught via plan template execution invariants and warning-only pre-commit reminders when raw `git commit` is detected outside the helper.

#### General-Purpose Git Notes Subsystem (P-44)
Git notes operate across two strictly isolated namespaces: `refs/notes/commits` (developer notes) and `refs/notes/ai` (AI traces). Notes are appended non-destructively on amend without error suppression. Remote sync is opt-in via `aapp.notesRemote` with `union` merge strategy by default to prevent notes loss. The audit guard (`aapp.aiNotesGuard`, `warn` or `enforce`) audits lossless configuration (`notes.rewriteRef`, `notes.rewriteMode concatenate`) and surfaces actionable warnings.

#### The Squash on the Plan Branch (P-84)
A squash happens on the plan branch, before the archive, so every SHA the kit records exists on the parent branch. After every check and `pre-done`, `done` replaces the plan's commits with one commit on the plan's base (the plan's tree, the squash message with its lineage trailers, the attribution of the plan's last commit), records that commit (`Commits:`, archive ledger, the archived issue row, `issue.close`), and the parent is fast-forwarded to it; a plan waiting on the closed issue resumes by the commit rule of P-78. Which plans: every plan under `aapp.integrate squash`, and a plan made for an issue under any setup (one issue, one commit), recognised when the plan's `Target Issue` and the issue's `Planned` row linking the plan agree (`plan_made_for_issue`); such a plan always gets its own worktree at `start`. A failed squash or archive puts the branch back at its former tip. An archived plan squashed later (`done <id> integrate squash`) has its records corrected in one `plan(record)` commit (`ledger_set_archive_commit` for the issue row). Engine: `_sq_*` in `lib/cmd_plan.sh`.

#### Automated Clean Rebase & Documentation Governance (P-106)
During integration (`aapp done … integrate`), `aapp.autoRebase` (`true` | `false`, default `false`) enables automated clean rebasing of diverged plan branches onto their parent branch prior to fast-forwarding. Because Plan P-65 guarantees code disjointness across active plans, independent plan rebases are mathematically conflict-free; if conflicts arise (e.g. concurrent doc updates), the engine immediately runs `git rebase --abort` to fail closed without worktree corruption. Documentation governance (`aapp.docs`, default `true`) allows brownfield adopters to bypass rigid manual heading tasks and pre-commit documentation reminders when using external doc frameworks.

#### Parent Integration Lock & Headless CAS Landing (P-107)
During integration (`aapp done … integrate`), an atomic named lock scoped to the target parent branch (`integrate/<parent>`) serializes landings into that parent, waiting up to `aapp.integrateWait` seconds (default 15s, 10–600s range). Integrations targeting distinct parent branches proceed concurrently. Fast-forward landing is completely headless via Compare-and-Swap (`git update-ref refs/heads/<parent> <new> <old>` or merge in the worktree holding the parent), eliminating `PRIMARY_ROOT` switching. Under Option i, the parent branch fast-forwards before plan archival commit; if archival fails, CAS rolls the parent branch back to `<old>` while the lock is held, preserving active plan buffers on failure (resolving #124). `_issue_land_fix` acquires the parent lock when landing fixes, and the pre-commit hook rejects direct raw commits to a parent branch while its integration lock is held. All locks are managed by the unified named lock engine in `lib/aapp-lib.sh` (`aapp_lock_acquire`, `aapp_lock_release`, `aapp_lock_held`).

#### Milestone Release Bundling & Tag Ledgers (P-38)
Milestone orchestration (`aapp release <version>`) creates immutable, freeze-locked snapshots of completed plans in `.plans/release/<tag>/`, rolls up active archive entries into a single-line milestone entry in `000-archive-ledger.md`, and prunes active archive plan files. Release operations remain snapshot-agnostic and language-agnostic, delegating project-specific artifact generation, template synchronization, or packaging exclusively to registered lifecycle hooks (`pre-release`, `on-release`, `post-release`).

### Issues

#### Two-Lane Boundary
Never merge bugs into `state_matrix.md` or raw feature requests into `issues_road_map.md`. Large bug fixes are promoted to blueprints via `digest ISSUE-00X`.

#### Issue Fixes, Hotfixes & Plans Held Elsewhere (P-52)
A small fix runs in a temporary mini plan `.plans/current/fix-<num>.md` (created by `aapp issue fix`, deleted by `aapp issue close`; one at a time, serialised by a waiting roller and the shared issue lock in the git common dir); the issue row is its permanent record and plan lookups (resolver, Pair 4, matrix, plan-status, ID seed) ignore it. A plan blocked by a bug outside its files hands off with one command, `aapp issue hotfix`, which logs and queues the issue (🧱 Plan Blockers), appends it to the plan's append-only `Emergency Hotfixes:` and blocks the plan; above `aapp.maxEmergencyHotfixes` the block is permanent. A 🔷 Frozen plan restricts nothing (#98). Single-plan auto-discovery skips plans held by another worktree's buffer, and an unbound checkout is refused their files; overlap checks (activation gate, Pair 7) still see them.

#### Issue Abort (P-76)
`aapp issue abort <num>` withdraws an issue that is wrong or unwanted, in the opposite direction of P-69: the issue goes and takes what was opened for it. Its promoted plan goes through `plan abort` and its open mini plan through the mini-plan drop, each in its own commit; then the row is archived as `aborted` by the same function `issue close` uses (`_issue_archive_active`), which also resumes the plans it blocked. Each step leaves a consistent state, so an interrupted run is finished by running the command again.

#### One Commit per Fix (P-85)
A small fix follows the rule of P-84: one issue, one commit. Every fix is made in its own worktree, `.workspace/fix-<num>` on `fix/<num>`, cut from the issue's branch; the main checkout is never bound to a fix, so uncommitted work there is no reason to wait. At `close` (`_issue_land_fix` in `lib/cmd_issue.sh`) the fix is rebased when its branch moved, a fix of several commits is squashed into one (`_issue_squash_fix`: subject `fix: <changelog entry> (#<num>)` within `aapp.subjectMaxLen`, the attribution and git notes of the last commit through the carrier of P-84), and the branch is fast-forwarded to it; uncommitted changes in the fixed files where that branch is checked out refuse the close before anything changes. The archive row and `issue.close` name the commit on the branch.

#### The Issue Work Queue (P-89)
An issue is cleared for work the way a plan is: by a person. `ISSUES.md` records every issue, in the order logged (`aapp issue list`; sorting is a plugin's job). `issues_road_map.md` is the work queue, with exactly two sections: `## 🧱 Plan Blockers`, written by `aapp issue hotfix`, and `## 📋 Queued`, written by `aapp issue queue <num> [urgent | low | remove]`, in three levels (Urgent, Normal, Low), oldest first in each, each line with its queue date. `aapp issue fix` opens only an issue in one of them (`fix next-blocker`: blockers first), so an agent cannot carry work through self-logged issues. The ledger functions own the file (`roadmap_queue_entries`, `roadmap_queue_set`, `roadmap_queue_add`, `roadmap_queue_level`, `roadmap_queued`, `roadmap_blockers`); the lists show each issue with its row's facts and its queue date and level (`ledger_issue_lines`); planning health refuses any other section. Where a tracker keeps the record, the tracker's queue is the queue: the provider steps `issue.queue` / `issue.unqueue` must succeed, and each sync rebuilds the levels from the listing's `queued`, `priority` and `queued_at` fields.

#### Issue Fix Safeguards & Size Limits (P-82)
An issue fix is small by measure, held to a bounded scope checked mechanically at `aapp issue close`: at most 3 changed files (`aapp.fixMaxFiles`, default 3) and 25 changed lines (`aapp.fixMaxLines`, default 25), with `0` disabling either limit. A fix exceeding limits cannot land: `close` prints the numbers and directs the developer to `aapp issue fix <n> abort` followed by `aapp draft <slug> issue <n>` to promote the fix to a blueprint. Every changed file must be declared before it is touched: files outside the issue row's `Location` require an explicit reason (`aapp issue fix <n> file <path> "<why>"`), committed to the mini plan (`- [ ] `<path>` -> <why>`) and mirrored to the issue's out-of-band notes (`file <path>: <why>`); undeclared changed files are refused at `close`. Guard Section 2 protected files (`.githooks/*`, skills, IDE rules) are barred from mini plans entirely. Finally, opening a fix or adding a file warns if an active plan in `⚡ In Development` already targets that file (`aapp.fixCollision refuse` turns this into a refusal overridden only by `force`), protecting concurrent plans from silent rebase collisions while ignoring blocked plans.

## Plan State: Derived, Not Maintained

Plan state is **derived**: the `**Status:**` line inside each `.plans/current/*.md` is authoritative, and the matrix is regenerated from it.

* **One registry.** `lib/plan_states.sh` declares every status — emoji, canonical name, generated section heading, sort rank. Matching is by canonical name, never by glyph, so presentation and semantics stay separable and no reader depends on telling glyphs apart. Adopters add statuses through `git config aapp.planState.<slug>`; a malformed entry warns and is skipped rather than breaking status output.
* **One reader, one writer.** A plan's Status line is read and written only through the accessors beside the registry: `plan_status_line` (the header's line, outside fences and before the first `## `), `plan_status_text`, `plan_status_slug`, `plan_status_is` and `plan_status_render`, and `plan_set_status`, the one writer (registry slugs only; `✅ Done` and `❌ Aborted` are literals of `done` and `plan abort`). Verbs and both hooks call the same functions, so an adopter status is honoured everywhere alike; `tests/plan_states_test.sh` fails on a status match written anywhere else.
* **Headings generated, not parsed.** Sections and their order come from the registry, so no code anchors on heading text and adopter divergence cannot silently break resolution.
* **Population is `current/` only.** A plan that has left `current/` has no row; the archive ledger is terminal. Orphan rows vanish as a consequence of derivation rather than by special-case deletion.
* **Human content is preserved.** The Roadmap block is carried verbatim (priority ordering is human judgement, never derived) and each row's annotation after the first em-dash is reattached by Plan ID, so notes follow a plan across sections.
* **No silent loss.** A status matching no registry entry is reported in a visible *Unrecognized* section by both `aapp matrix` and `aapp plan-status`, instead of being folded into the Incubator where a typo would hide.
* **One engine, many callers.** `lib/cmd_matrix.sh` implements a single check-and-sync, invoked by `aapp matrix`, by `aapp status` before it reads the matrix, and by `draft` / `freeze` / `freeze-start` / `start` before they stage a lifecycle commit. Sourcing it with `AAPP_MATRIX_LIB_ONLY=1` loads the functions without executing the command.
* **Pause-aware.** The pause allowlist admits only `.plans/` pickup, issues and `current/` paths, so a matrix written while paused cannot be committed. The sync writes anyway and says the commit waits for `aapp resume`: the uncommitted diff is the record of how the board moved during the pause.

## Concurrent Plans & the Changelog (P-48)

Plans run in parallel on separate worktrees and branches; three rules keep the shared documentation from becoming a bottleneck:

* **Shared docs never collide.** One definition in `lib/aapp-lib.sh` names the shared docs; the `aapp start` gate and Pair 7 treat them as a notice, while any shared code file still blocks.
* **One changelog entry per plan.** A CLI cannot know which commit completes a plan, so the plan declares its entry (`* **Changelog:**`). `aapp commit` writes it on the plan's first commit and the pre-commit hook passes later commits once it is present (`aapp.changelogMode = plan`). Direct fixes and `commit` mode keep the per-commit rule, so nothing ships undocumented.
* **Union merge.** `CHANGELOG.md merge=union` keeps the entries both branches added.

## Plan Identity: Stored, Not Derived

Identity is **stored**: `aapp.planId` in git config holds the next id to hand out, as a bare integer. The `P-` prefix is a namespace marker applied on output to distinguish a plan id from an issue id (`#69`), never part of the value.

* **Monotonic.** The counter only moves forward, so an id is never reused — including ids belonging to plans that were archived, pruned, or abandoned into `.plans/aborted/`.
* **Seeded once.** `aapp init` scans the filesystem exactly once to bootstrap the counter (`1` on a new project). A numeric value is thereafter left alone, so repeat `init` — including the init that follows `aapp upgrade` — never disturbs a live counter.
* **Extensible.** A repository with more than one contributor installs an `aapp-planid` action plugin at `.agents/skills/aapp-planid/` to source ids from a central authority. Only plugin *absence* falls back to the local counter; a plugin that is present and fails aborts allocation rather than silently issuing a local id.
* **Bounded.** The core defines only the provider contract — emit an id, exit non-zero to refuse. Provider internals, dependencies and credentials are the adopter's responsibility and are never inspected.

`check_pair4_plan_id_integrity` is the independent detector for duplicate ids, decoupled from the counter.

**Issue ids are named by whoever creates the issue (P-74, P-79).** Without a provider, `aapp.issueId` is a second, independent counter (`#32` and `P-32` may both exist), seeded on **first use**, not by `aapp init`: git config is not cloned and a clone never runs init, so the first allocation in any clone continues from the numeric ids of both `ISSUES.md` and the archive. With an `aapp-issue-tracker` provider, the provider creates the issue and returns its id, and that id is the issue's identity: a number or the tracker's own key (`#PROJ-101`). A counter kept in one clone cannot name issues for a team, so the kit never numbers an issue a provider accepted. Duplicates are caught by Pair 1 (across ledgers) and Pair 8 (within one ledger).

## Adoption Advisories & Setup Checklist (P-63)

`aapp init` sets up worktrees, hooks, and skills, while leaving project-specific decisions (branch naming, remote pushes, project rules, build tool worktree exclusions, and configuration reviews) to the adopter. The kit tracks them in `.plans/adoption.md`:

* **Untracked & Local-First**: `.plans/adoption.md` is added to `.plans/.gitignore`. It is never committed to `.plans` git history, avoiding merge conflicts across clones.
* **Hybrid Auto-Verification**: `aapp init` scans repository state against the rules catalogue in `lib/adoption.sh`. Tasks with verifiable checks are automatically ticked (`- [ ]` → `- [x]`) upon satisfaction. Existing ticks (`- [x]`) — whether machine or hand-checked — are never unticked.
* **Status Awareness**: `adoption_open_count` queries unticked tasks (`^- \[ \] \`\[`). Open tasks are reported in the overview line (`| <N> adoption`) and recovery briefing, remaining completely silent once zero open tasks remain.

## Issues: One View, One Definition, One Exchange (P-72)

Three things about issues are each defined in exactly one place, and tests fail when a second copy appears.

* **What an issue id is (P-79).** One definition in `lib/aapp-lib.sh`: `#` followed by digits (`#46`) or by a key, a dash and digits (`#PROJ-101`). Every verb and both hook engines validate, normalise and extract ids through it. The mini plan file, its worktree, the commit subject and the plans' `Target Issue` / `Blocked On` lines all carry the same id.
* **How the ledgers are read and written (P-73).** `ISSUES.md`, `done/000-issues-archive.md` and `issues_road_map.md` are touched only by the ledger functions of `lib/aapp-lib.sh`. A team's issues have one record: these ledgers, committed, when there is no tracker; the tracker when a provider lists issues. In that case the ledgers stay in place, untracked, and a sync updates them row by row, so every view (`status`, `issue list`, the blocker queue, `draft`) reads the same files either way. Hooks read the local ledger only; they never reach the network and never receive the code that calls a provider.
* **How the kit talks to a supported plugin (P-77).** A step is a short exchange: the kit sends the whole subject in the envelope; the plugin answers with one flat object (`status`, `message`, `handled`, what it produced); whatever `handled` does not name, the kit does. Longer answers go in two files the kit names: a list (one flat object per line) and `do`, aapp commands as a person types them, which the kit runs after the step from a whitelist. A supported plugin cannot run a writing verb during a step. Credentials are the plugin's responsibility; the envelope carries none. Ad hoc plugins and scripts are outside the exchange: CLI users, guarded by the CLI's own locks and checks. The reference is `docs/reference/06-plugin-protocol.md` and, per subject, `07-issue-protocol.md`; a test keeps it equal to the code.

**An issue belongs to a branch (P-78).** Its `Branch` cell names where the fix must land; no branch named means the development branch. The cell and the `branch <name>` token are optional: a logged issue names a branch only when a person or an agent gives one, never from where it was logged. Which branch owns an issue's files is the team's knowledge: the kit asks the team's `aapp-issue-branch` plugin when a fix opens and refuses the fix when the plugin fails (P-83); without the plugin it is the development branch. A fix opens on that branch. Closing follows the code: a close that names a commit is refused until the commit is in the issue's branch, and a plan waiting on the issue resumes only when the fix is reachable from the plan's own parent branch (`aapp status` notices and unblocks it). The kit never pulls or merges a code branch. A withdrawn issue has no commit and is exempt. A hotfix names the blocked plan's parent branch only when every file it names is one of that plan's Target Files; a fix that lands on a group's parent is merged into the group's feature branch at `close`, so its members can resume (P-83). A closure made on the tracker reaches the ledger at once, the tracker being the record; only the plans waiting on the issue follow the code (#142).

**Issue steps (P-74).** `aapp issue log` is the one way a row is created: the agent hands the issue over and never writes a row or claims a number. Each step (`log`, `refine`, `fix`, `fix-abort`, `abort`, `close`, `list`) goes through one wrapper; with no provider installed the kit does everything. An issue's text has three parts: the symptom (one line, in the row), the description and the notes. Description and notes may hold real data and are never in the ledger or any tracked file: a provider keeps them, or the kit does, outside the repository and per machine, as written. The kit hands them over when a fix opens, in a labelled block (information, not instructions); a team's `aapp-issue-note-filter` (P-80), a text substitution mechanism, decides what is shown, and a filter that fails withholds the note.

**Working offline (P-75).** With a provider installed and unreachable, an issue is staged in the `.offline` worktree (orphan branch `offline`, listed in `.git/info/exclude`, never pushed) under a temporary numeric id, far above the known ids. The offline ledgers have the main ledgers' format and are a second source of the ledger functions: readers see staged issues beside the others, and a writer is pointed at them. Three modes: the provider is asked first and a failure stages offline (default); it is not asked at all (`aapp.offlineOnly`); or a failure refuses and nothing is staged (`aapp.offlineEnabled false`). A step for an issue the tracker knows that cannot be sent waits in `.offline/outbox` and is sent before anything is read from the tracker. `aapp offline sync` publishes: each issue gets its real id, references in the plans are rewritten, and a former id stays resolvable; commits made offline are never rewritten. A draft plan follows the same rule when the plan-id provider is unreachable.

## Output: Records, Terminal, JSON (P-91)

`aapp status` and `aapp issue list` collect what they show into records first: tab-separated lines, one per item, holding raw values (slugs, ids, dates, full text). Two renderers print the records and compute nothing, so the outputs cannot disagree.

* **Terminal.** Every line within `aapp.statusOutputWidth` characters (default 85). An item's long text wraps with a hanging indent; an issue's facts stand on a line of their own, the symptom below it. The briefing cuts long text (`aapp.statusTextMax`) and caps long lists (`aapp.statusItemsMax`); `issue list` never cuts. The full text stays in its file.
* **JSON.** A bare `json` token prints one JSON object on stdout and nothing else: the document, or, when the run fails, an error document (`error.code`, `message`, `aapp_config`, P-100), the exit code saying which. A JSON run never waits for input; whatever it says on the way is in its `notices`, grouped as `warning` and `info`. Its fields are a contract, versioned and documented in `docs/reference/08-output-json.md`; adding a field keeps the version, renaming or removing one raises it. Text is verbatim (inline Markdown as written), absent values are `null`, enums are lowercase slugs.

The Issues records are one function for both commands, beside the ledger functions. Shared rendering (wrapping, cutting, the JSON writer) lives in `lib/output.sh`; `json_escape` stays the one string escaper.

## Group Lifecycle: Ownership, Amendments, Done (P-103)

**A plan in development belongs to its checkout (P-99).** A `refine` that edits a plan in development runs only from its recorded worktree, or, for a plan without one, from the checkout whose active-plan buffer holds it. Elsewhere it is refused, and the refusal says what to do instead: tell the developer, log an issue, or add a pickup line. Ownership rests on the place, never on something an agent holds: sessions lose memory on a reboot or a session cap. Verbs that write defined fields (commit SHAs, blocked state, closes, a group's members, amendments requests) run from any checkout. Every `refine` fires `pre-refine` (gate), `on-refine` (in-transaction) and `post-refine` (observer), with the kind of refine in the payload. The design lock also covers a frozen group's `## Architecture & Codemap`.

**Members are never amended after start (P-101).** Each group has an amendments member (`* **Kind:** amendments`), drafted with the group and archived last. A member's session requests a file or decision (`refine <amend-id> request`), a file `for` the plan of the group it belongs to (its owner: an archived member, the group plan, or by default the requester itself, P-129); with `aapp.amendmentApprovalRequired` (default `true`) an approver, a person or a managing agent, approves it (with `false` a file request is approved when made). Approval edits no plan's §4: the write guard and the pre-commit hook let the requester write that file until its one commit, `aapp commit "<msg>" amendment <n>` (trailer `Amendment: R<n>`, not recorded in the requester's Commits). For another owner that commit lands at once on the requester's parent branch, built on its tip under the `integrate/<parent>` lock (refused when the file moved there), and the requester rebases, dropping its copy; the owner, in `current/` or archived in `done/`, gains the file in its Target Files and a `### Amendments` line at the end of its §4 with the landed hash, the only lines the design lock accepts there; its Commits stay its own, matching the archive ledger. A request the requester owns lands with its `done`, which finds the commit by the trailer (the squash commit under a squash). The requester's `done` closes its requests (`closed · landed`, `unused`, `withdrawn`), `plan abort` withdraws them, and a later change to the file is a new request. Members rebase onto the feature branch as they take a parent's commits; status shows the order. Request lines move by verbs only; `plan-status` and `status` show them. The amendments member is the group's ordered record of what its planning missed; the owner plans hold the after-care with their own logic. The group plan's `## Architecture & Codemap` stays the one guide: a correction is written into it, recorded in the amendments member's `Decisions` in the same commit, and members re-read it at start and at every session start or resume.

**A group's `done` gates before it claims delivery (P-102).** Checks and the gate run on the feature branch first; only then are the `ARCHITECTURE.md` sections and the umbrella changelog entry committed, restored by `reset --hard` when a hook refuses that commit. The group is archived, the parent fast-forwarded, the `.agents/CODEMAP.md` sections committed, and cleanup runs last.

## Cross-Repository Companion Architecture (P-90)

AAPP supports multi-repository co-development where a primary project coordinates with consumer adapters, SDKs, or companion applications:

* **Isolated Git Object Stores**: Companions are never nested git submodules or subtrees. Every companion maintains its own independent Git common directory (`.git`), preserving native hooks, object databases, and commit histories.
* **Three Topologies**: Supports peer `checkout` (unlinked on removal), managed `worktree` (for non-AAPP repos), and managed `clone` (under `.workspace/companion/<name>`).
* **G2 Refusal of AAPP Worktrees**: Creating a raw git worktree for an AAPP repository is prohibited (`G2 Refusal Rule`) because raw worktrees lack linked kit hooks. Adopters start a plan in the companion and register its active worktree as a checkout.
* **G1 Guard Delegation**: Write-time interception (`blast-radius-guard.sh`) delegates tool write checks to the companion's own `.githooks/blast-radius-guard` when targeting an AAPP companion, ensuring both repositories' blast radiuses are strictly enforced. Non-AAPP companions are authorized via `aapp.allowPath`.
* **Bounded Push & Offline Telemetry**: `aapp companion push` delegates strictly to `git -C <path> push` with no force pushes or uncommitted changes allowed. `aapp companion status` queries local tracking refs (`@{u}`) with zero network overhead.

## Milestone Release Bundling, Tag Ledgers & Hook Versioning (P-38)

AAPP structures project completion and releases into immutable milestone bundles:

* **Snapshot-Agnostic Milestone Bundles**: At release time, completed architecture blueprints in `.plans/done/` and defect records in `done/000-issues-archive.md` are moved into `.plans/release/<tag>/` (`plans/`, `000-archive-ledger.md`, `000-issues-archive.md`, `manifest.md`, `manifest.json`).
* **Hierarchical Master Ledger Rollup**: Master archive `.plans/done/000-archive-ledger.md` is structured into `## 🏷️ Shipped Releases` (1-line summary row per release linking to `../release/<tag>/000-archive-ledger.md` with dynamic plan/issue counts) and `## ⚡ Current Unreleased Cycle`.
* **Recursive Resolution & Seeding**: `plan_resolver.sh`, `seed_plan_id`, and `seed_issue_id` traverse `.plans/release/*/` recursively across `done` and `all` scopes, ensuring historical blueprints remain searchable and ID seeding never collides.
* **Dual-Phase Architecture**: Releases execute Phase A (Read-Only Pre-Flight Gate & Simulation) before Phase B (Atomic Mutation Pipeline with fail-closed transactional rollback trap `_release_rollback()`).
* **Hook-Delegated Versioning**: Language-agnostic version bumping dispatches `on-release` action delegate with Dual Delivery (`stdin` JSON + POSIX environment variables) rather than hardcoding application manifest files.


