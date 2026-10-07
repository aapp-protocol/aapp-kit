# 🗺️ Code Map & Interface Registry: Agent Planning Kit (AAPP)

> **Rule for All Agents:** Before creating a new file, script, function, or wrapper, you MUST scan this map. If a module exists that covers the concern, you must extend or import it. Maintain single sources of truth for path resolution, state transitions, and configuration.
>
> **The Callable Contract Standard:** For each component, record the callable contract: invocation forms (arguments, stdin), outputs (stdout, stderr), exit codes, environment variables read, and files touched. An agent must be able to call or test it without reading the source.

---

## 🏗️ 1. Core Executables & CLI Switchboard

### 🚀 Primary Dispatcher (`aapp`)
* **Purpose:** Single source of truth for CLI entrypoint, base resolution, and command routing.
* **Key Functions:**
  * `has_kit_signature(dir)` -> Validates presence of essential kit structures (`templates/`, `pre-commit`, `AGENTS.md`, `lib/`, `cmd_init.sh`).
  * `is_safe_to_consume_kit_dir(dir, keep)` -> Content-based signature, file manifest audit, and clean git working tree check protecting non-kit assets and development checkouts from self-consumption.
* **Responsibilities:** Resolves runtime environment (`AAPP_RUNTIME=installed|local`, `AAPP_BASE`), exports core environment variables, enforces front-door repository membership assertions, and delegates to `lib/` modules.
* **Anti-Wrapper Warning:** Never write wrapper shell scripts around `aapp` commands; invoke `aapp` directly.

---

## ⚙️ 2. Operational Modules & Command Libraries (`lib/`)

### 📦 Workspace Initializer & Worktree Manager (`lib/cmd_init.sh`)
* **Purpose:** Single source of truth for target repository resolution, multi-orphan worktree mounting, delimited block synchronization, and Claude Code settings bridging.
* **Key Functions / Blocks:**
  * `mount_or_create_worktree(branch, dir)` -> Safely provisions or mounts orphan worktrees (`plans`, `agents`, `githooks`).
  * `sync_agent_rules()` -> Delimited block updater (`<!-- AAPP-PROTOCOL:START -->` ... `<!-- AAPP-PROTOCOL:END -->`) preserving custom user rules in `AGENTS.md`.
  * `copy_guarded(src, target, msg)` -> Non-destructive file copy that never overwrites existing user content.
  * Canonical Physical Fast-Fail -> Asserts `[ "$AAPP_RUNTIME" = "installed" ] || [ "$AAPP_BASE_PHYSICAL" = "$REPO_ROOT_PHYSICAL" ]`, fast-failing any attempt to run `init` from an uninstalled clone against an external repository.
* **Anti-Wrapper Warning:** Do not implement ad-hoc worktree creation or rule-sync logic outside this module.

### 🌐 Global Installer & Self-Consumption Manager (`lib/cmd_install.sh`)
* **Purpose:** Installs binary to `~/.local/bin/aapp` and shared libraries/templates to `${XDG_DATA_HOME:-~/.local/share}/aapp-kit/`.
* **Key Behaviors:**
  * Evaluates `is_safe_to_consume_kit_dir` before unlinking temporary installer clones.
  * Preserves development checkouts and existing projects automatically with zero-flag minimalism.
* **Anti-Wrapper Warning:** Do not alter PATH or rc files destructively.

### 🎯 Plan Lifecycle Switchboard (`lib/cmd_plan.sh`)
* **Purpose:** Single source of truth for in-flight plan execution state and worktree context buffers.
* **Key Commands:**
  * `aapp refine <plan> "<msg>"` -> Commits an edit to an active plan's content (only the plan file, through `plans_commit`); the agents' path for plan edits, so nothing runs raw git on `.plans` (P-47). Tokens: `blocked <num>` (`plan_block_on`, P-49); `slug <new-slug>` renames the file and repairs links (`_refine_slug`, P-50). Reserved targets `pickup` / `issues` commit validated ledger edits (`_refine_ledger` + `check_ledger_issues` / `check_pickup_entries` in `planning_health.sh`, P-50).
  * `aapp draft <slug> issue <num>` -> promotion: Target Issue, `issue_mark_planned`, one commit (P-50).
  * `aapp tdd <plan>` -> Injects failure test declaration sections (`### 🧪 Required Tests` in §3, `### 🧪 Required Test Files` in §4) into an incubator blueprint before freeze.
  * `aapp freeze-start <plan>` -> Atomic validator, disjointness check, status update (`⚡`), and buffer binding.
  * `aapp freeze <plan>` -> Locks blueprint into 🔷 Frozen backlog specification, verifying TDD correspondence if present.
  * `aapp start <plan>` -> Activates frozen specification (`🔷`) into development (`⚡`).
  * `aapp done <plan>` -> Archives implemented plan to `done/`, enforcing mechanical TDD completion gate (`tdd (N/N)` recorded in archive ledger).
  * `aapp active [id]` -> Displays or sets active plan pointer buffer (`$(git rev-parse --git-path aapp_active_plan)`).
  * `aapp active swap` / `aapp active clear` -> Toggles between current and previous buffer or clears context.
  * `aapp plan-status [id]` -> Deterministic read-only inspector for plan matrix or specific blueprint.
  * `aapp plan [query]` -> Educational planning switchboard guiding users and agents.
  * Disjointness Activation Gate -> Shared docs only print a `[Shared Doc]` notice (P-48); otherwise enforces non-overlapping target file sets between concurrent `⚡ In Development` plans.
* **Anti-Wrapper Warning:** Never manually write to `.git/aapp_active_plan` without going through `cmd_plan.sh`.

### 🎨 Plan Status Registry (`lib/plan_states.sh`)
* **Purpose:** Single source of truth for which plan statuses exist and how each one renders. Pure module with no top-level side effects; safe to source anywhere.
* **Key Functions:**
  * `plan_states_load()` -> Loads kit defaults, then merges adopter overrides from `git config aapp.planState.*`. Idempotent.
  * `plan_state_for_status_line(line)` -> Resolves a raw `**Status:**` line to a slug, or empty if unrecognized. Matches by **canonical name, not emoji**.
  * `plan_state_field(slug, field)` -> Accessor for `emoji` / `name` / `heading` / `rank`.
  * `plan_state_sections()` -> Unique matrix headings in rank order, deduplicated (`under-review` and `refining` deliberately share one).
  * `plan_state_emoji_class()` -> Alternation of live status glyphs, for callers that must match any status.
* **Adopter Extension:** `git config aapp.planState.<slug> "<emoji>|<name>|<heading>|<rank>"`. A slug matching a kit default overrides it in place; a new slug is appended. Malformed tuples warn to stderr and are skipped — never fatal.
* **Accessibility Invariant:** The shipped glyph set (`🟣 📝 🔷 ⚡ 🟥`) is colour-blind friendly and is a hard design constraint. The retired `🔴`/`🟡` pair is the red/green-family combination that fails common colour-vision deficiency and carries **no alias**; a plan still using one resolves as unrecognized so it gets cleaned up. Adopter-defined glyphs should be shape- or symbol-distinct rather than hue-distinct.
* **Anti-Wrapper Warning:** Never hardcode a status emoji alternation (`🟣|🔷|📝`) or an `In Development` / `Frozen` regex. Source this module and use the accessors.

### 🔄 State Matrix Derivation Engine (`lib/cmd_matrix.sh`)
* **Purpose:** Derives `.plans/state_matrix.md` from the `**Status:**` lines in `.plans/current/*.md`. The matrix is a generated view, never a record.
* **Key Commands:**
  * `aapp matrix` -> Checks and syncs in one pass. Reports what changed; silent when already in sync.
  * `aapp matrix --check` -> Read-only audit. Exits `0` in sync, `1` on drift. Never writes.
* **Callers:** `aapp status` (before reading the matrix, so the briefing reports the real board) and `draft` / `freeze` / `freeze-start` / `start` via `sync_state_matrix()` in `cmd_plan.sh` (before staging, so each lifecycle commit carries a correct matrix).
* **Library Mode:** Source with `AAPP_MATRIX_LIB_ONLY=1` to load `cmd_matrix()` without executing it.
* **Derivation Contract:**
  * Population is strictly `.plans/current/*.md`. A row with no backing plan file disappears; the archive ledger is terminal.
  * Sections and their order come from the status registry — **no code anchors on heading text.**
  * Human-owned content is preserved: the Roadmap block verbatim, and each row's annotation after the **first** ` — `, keyed by Plan ID so it follows a plan across sections.
  * A status matching no registry entry lands in a visible *Unrecognized Status* section rather than being folded into the Incubator.
* **Pause Behaviour:** The pause allowlist excludes `state_matrix.md`, so a sync while paused cannot be committed. It writes anyway and reports the commit as deferred until `aapp resume` — the uncommitted diff is the record of how the board moved during the pause.
* **Anti-Wrapper Warning:** Never patch a matrix row with `sed`. That was the previous approach and it could recolour a row but never relocate it, leaving frozen plans under the Incubator. Call `sync_state_matrix` (or `aapp matrix`) instead.

### 🧭 Plan ID Standards & Shorthand Resolver (`lib/plan_resolver.sh`)
* **Purpose:** Canonical resolver for ADR-style Plan IDs (`P-<num>`), filenames, and slugs.
* **Key Functions:**
  * `resolve_plan_path(query)` -> Maps `P-13`, `13`, `guard-path`, or `P13-*.md` to absolute blueprint path.
  * `get_plan_id(path)` -> Extracts the declared unpadded Plan ID from a blueprint header.
  * `get_next_plan_id()` -> **Read-only peek** at the next Plan ID from the `aapp.planId` counter. Never mutates; claims nothing.
  * `allocate_plan_id()` -> **Claims** a Plan ID and persists the increment. Delegates to an optional `aapp-planid` provider plugin (`.agents/skills/aapp-planid/`); only plugin *absence* falls back to the local counter, a present-but-failing provider is fatal.
  * `normalize_plan_id(raw)` -> Accepts `P-42` or bare `42`; anything not a plain integer is an error.
  * `get_next_issue_id()` / `allocate_issue_id()` -> Same contract for issue IDs (`#<n>`, `aapp.issueId`, optional `aapp-issue-tracker` provider), except an unset counter is seeded on first use by `seed_issue_id` (both ledgers, template rows skipped; no ledgers and no provider refuses). Both ID kinds share `_next_id` / `_allocate_id` / `_normalize_id` (P-32).
  * `verify_transition_target(cmd, target)` -> Rejects empty queries and `#`-prefixed issue collisions.
* **Anti-Wrapper Warning:** Do not parse plan filenames using raw ad-hoc `grep` or `cut`; use `resolve_plan_path`.
* **Allocation Warning:** Plan IDs are **stored, not derived**. Never reconstruct an ID by scanning filenames or the archive ledger — that approach was removed (issue `#69`). Use `allocate_plan_id` to claim, `get_next_plan_id` to display.

### 🐛 Issue Lifecycle Verb (`lib/cmd_issue.sh`)
* **Purpose:** `aapp issue [next | allocate | hotfix | fix | close <id> | list]` (P-32, P-52); contract in `lib/docs/verbs/issue.md`.
* **Key Functions:**
  * `issue_locate(n)` -> `active`, `archive`, or empty.
  * `cmd_issue_hotfix` / `cmd_issue_fix` / `_issue_fix_abort` -> P-52 hotfix (row, 🧱 Plan Blockers queue, `Emergency Hotfixes:`, block via `plan_block_on`, one commit) and temporary mini plans `current/fix-<num>.md` (one at a time; verbose wait up to `aapp.issueFixWait`).
  * `_issue_lock_acquire` / `_issue_lock_release` -> the shared issue lock `$(git rev-parse --git-common-dir)/aapp_issue.lock` (PID-based stale takeover).
  * `issue_unblock_plans(n)` -> drops `#n` from every plan's `Blocked On:`; restores the recorded status when the list empties and the block is not permanent; used by `issue close` and `cmd_done` (P-52).
  * `issue_close_local(n, sha, summary)` -> Moves the active row to the top of the archive and prunes the road map; does not commit.
  * `issue_relink(old, new)` -> Rewrites links to a plan file in *Target Plan / Fix* cells and road-map lines (observation cells untouched); prints the count; does not commit (P-50).
  * `issue_mark_planned(n, link)` -> Promotion's row edit: Target Plan / Fix → link, Status → 🔵 `Planned` (P-50).
  * `issue_notify_close(n, sha, summary, [plan])` -> Fire-and-forget `issue.close` to `aapp-issue-tracker` (§5 Plugin Payload Standard); prints the returned status; failure only warns.
* **Consumers:** `aapp issue`, and `lib/cmd_plan.sh`: `cmd_done` closes a plan's Target Issue and repairs links inside its archive commit; `refine … slug` repairs links; `draft … issue` marks the row Planned.
* **Anti-Wrapper Warning:** Never hand-edit rows between `ISSUES.md` and the archive; use `aapp issue close` or `aapp done`.

### 📚 Shared Hook Library (`lib/aapp-lib.sh`)
* **Purpose:** Single owner of plan-section parsing, glob matching and platform detection, sourced by the CLI and both hook engines (P-37).
* **Public Interface:**
  * `parse_plan_target_paths(file)` -> Write targets from `Target Files`, `Emergency Hotfix Extensions`, `Required Test Files` inside §4.
  * `parse_plan_oob_paths(file)` -> Vetoed paths from `Out of Bounds` inside §4.
  * `parse_plan_required_test_files(file)` -> Declared test file paths under `### 🧪 Required Test Files` inside §4 (Option A single-entry semantics).
  * `parse_plan_required_tests(file)` -> Declared test items under `### 🧪 Required Tests` inside §3 (isolates path prefix).
  * `plan_has_required_test_files(file)` -> True when §4 carries `### 🧪 Required Test Files`.
  * `validate_plan_tdd_correspondence(file, [prefix])` -> Validates non-empty sections and bidirectional correspondence between §3 and §4.
  * `aapp_shared_docs_regex()` / `aapp_is_shared_doc(path)` -> The one definition of shared docs (CHANGELOG, README, MANUAL, CHEATSHEET, CODEMAP, ARCHITECTURE, ISSUES): exempt from the `aapp start` gate and Pair 7, and the base of the pre-commit always-allowed list (P-48).
  * `aapp_plan_changelog_decl(file)` / `aapp_render_changelog_bullet(text, id)` / `aapp_changelog_plan_line(id)` -> The plan's `**Changelog:**` declaration, its rendered bullet, and the plan's bullet under `## [Unreleased]` (P-48). Used by `aapp commit` (writes it), `aapp freeze` (validates it) and the pre-commit hook (`plan` mode check).
  * `parse_plan_commits(file)` -> Parses recorded `sha (branch)` and `sha (detached)` commits from blueprint header.
  * `write_plan_commits(file, commits...)` -> Replaces or inserts `* **Commits:**` line in blueprint header.
  * `write_plan_base(file, sha, branch)` -> Records `* **Base:** <sha> (<branch>)` if currently `none`.
  * `find_worktree_holding_plan(plan_file)` -> Finds if a plan is bound in another worktree's execution buffer.
  * `aapp_held_plans` / `aapp_plan_held_by(plan_file, held)` -> one-pass list of plans held by other worktrees' buffers, and the match used by the five single-plan discovery sites (guard, hook plan and changelog checks, `aapp commit`, `aapp active`) so an unbound checkout neither adopts a held plan nor edits its files (P-52).
  * `extract_plan_section(n)` -> Stdin filter printing numbered section `## … n.` (design lock).
  * `glob_to_regex(pattern)` / `match_pattern_list(target, patterns…)` -> Exact, directory-prefix and glob matching.
  * `aapp_os([uname_s] [proc_version])` -> `linux|darwin|windows|wsl|bsd|unknown`; `wsl` is a GNU userland.
  * `aapp_lib_loaded()` -> Load sentinel every consumer asserts.
* **Consumers:** `lib/cmd_plan.sh`, `lib/cmd_commit.sh`, `lib/planning_health.sh` (Pair 7), `.githooks/aapp-pre-commit`, `.githooks/blast-radius-guard`.
* **Anti-Wrapper Warning:** Never add an inline section parser elsewhere; extend this library and `tests/aapp_lib_test.sh`. Edit `lib/aapp-lib.sh`, never `templates/aapp-lib.sh` (a symlink) or `.githooks/aapp-lib.sh` (installed by `aapp init`).

### 📝 Plan-Bound Commit Helper (`lib/cmd_commit.sh`)
* **Purpose:** Single source of truth for committing staged implementation code, attaching attribution via P-40, and recording commit SHAs in the active plan.
* **Key Commands:**
  * `aapp commit "<msg>" [agent <A> vendor <V> model <M>] [note "<text>"]` -> Commits staged files in worktree, decorates attribution, and records SHA and branch in active plan.
  * `aapp commit amend ["<msg>"]` -> Amends last commit, preserving message if omitted without duplicate trailers, and updates recorded SHA in active plan.
  * `aapp commit adopt <sha>...` -> Adopts existing commits made outside the helper and records them into active plan with a warning.
* **Anti-Wrapper Warning:** Never bypass `aapp commit` during an active plan; it ensures trailer compliance, lock resilience, and plan ledger integrity.

### 🚂 Unified Plans Commit Engine (`lib/commit_engine.sh`)
* **Purpose:** Single authoritative engine for all `.plans` worktree commits, eliminating ad-hoc `git commit || true` patterns.
* **Key Functions:**
  * `plans_commit(subject, path...)` -> Commits specified paths in `.plans` with explicit pathspec limiting (`git commit -- <paths>`), lock-retry resilience, attribution decoration, and loud failures.
* **Consumers:** `lib/cmd_commit.sh`, `lib/cmd_plan.sh` (`draft`, `freeze`, `start`, `freeze-start`, `done`).
* **Anti-Wrapper Warning:** Never use `git add ... || true; git commit ... || true` in `.plans`. Always use `plans_commit`.

### 🛡️ Planning Health Integrity Engine (`lib/planning_health.sh`)
* **Purpose:** Automated mechanical integrity validator running 8 orthogonal verification pairs:
  * **Pair 1:** Disjointness between active `ISSUES.md` and `000-issues-archive.md`.
  * **Pair 2:** Referential integrity between `issues_road_map.md` and active `ISSUES.md`.
  * **Pair 3:** Pickup queue routing hygiene (`.plans/pickup.md`).
  * **Pair 4:** Plan ID uniqueness, header agreement, and reference integrity.
  * **Pair 5:** Self-protection safety (blocks Section 2 targets in blueprint `Target Files`).
  * **Pair 6:** Recorded hexadecimal commit SHA existence in git object database.
  * **Pair 7:** Concurrent boundary collision detection for multiple `⚡ In Development` plans.
  * **Pair 8:** Issue ID repeated within `ISSUES.md` or within the archive (cross-ledger collisions are Pair 1).
* **Anti-Wrapper Warning:** Keep health checks mechanical, fast, and free of external runtime dependencies.

### 🏷️ AI Attribution Switchboard & Identity Layer (`lib/cmd_ai.sh`, `lib/attribution.sh`)
* **Purpose:** Governs AI attribution modes (`none`, `lax`, `strict`, `notes`), single identity resolution layer, commit decoration, and credits roster generation.
* **Key Commands & Behaviors:**
  * `aapp ai-lax` / `aapp ai-strict` / `aapp ai-notes` / `aapp ai-off` -> Switchboard state machine.
  * `aapp.aiAttribution=commit` is retired and refused loudly at commit time.
  * `lib/attribution.sh` -> Shared functions: `resolve_ai_identity`, `attribution_decorate`, `attribution_note`, `apply_agent_aliases`, `normalize_agent_identity`.
  * `aapp ai-note --stage` -> Pre-stages Option C note buffer keyed by commit message SHA-256.
  * `aapp ai-credits` -> Append-only union generator updating `AI Contributors` roster in `README.md`.
* **Anti-Wrapper Warning:** Never emit fake email addresses (`Co-authored-by: Agent <email>`).

### 🛑 Master Emergency Brake & Multi-Worktree State Preserver (`lib/cmd_pause.sh`)
* **Purpose:** Freezes codebase modifications and quarantines in-flight uncommitted work across all worktrees into SHA-addressed stashes ("Hibernate & Wake").
* **Key Commands & Behaviors:**
  * `aapp pause [reason]` -> Discovers worktrees dynamically via `git worktree list --porcelain`, pre-checks no in-flight merges/rebases (`git rev-parse --git-path MERGE_HEAD`, `rebase-merge`, `CHERRY_PICK_HEAD`), stashes with `--include-untracked`, validates 40-char commit SHA with atomic rollback on failure, and records snapshot to `$(git rev-parse --git-common-dir)/aapp_paused`. Acts as idempotent inspector if already paused.
  * `aapp pause --shared [reason]` -> Team-wide freeze committed to `.plans/PAUSED.md`.
  * `aapp resume` (or `aapp unpause`) -> Compares current HEAD SHAs against snapshot (forensic drift detection without auto-rebase), restores stashes by commit SHA, permanently preserves stashes on conflict while keeping pause buffer intact (No-Loss Conflict Invariant), conditionally drops stashes on success, verifies planning health, and removes pause buffer.
* **Anti-Wrapper Warning:** Never address stashes by index (`stash@{0}`); use 40-character commit SHAs exclusively. Never use `--all` (preserves `.gitignore` air-gaps).

### 📊 Context Recovery Briefing (`lib/cmd_status.sh`)
* **Purpose:** Read-only four-pillar context recovery agent inspecting Shipped (`CHANGELOG.md`), Issues (`ISSUES.md`), Plans (`state_matrix.md`), and Pickup (`pickup.md`). Surfaces prominent pause banner and quarantined worktrees when paused.
* **Anti-Wrapper Warning:** Must remain strictly non-destructive and idempotent.

### 🪝 Lifecycle Hooks & Action Plugins Engine (`lib/hook_dispatcher.sh`, `lib/cmd_hook.sh`)
* **Purpose:** Zero-dependency lifecycle hook dispatch, SHA256-hash-locked quality gating, and dynamic action plugin discovery.
* **Key Functions:**
  * `dispatch_hook(event, data_json, repo_root)` -> Dual Delivery dispatcher streaming JSON on `stdin` alongside exported `AAPP_*` environment variables with process watchdog timeout enforcement (exit 124).
  * `build_event_envelope(event, data_json)` / `run_action_plugin(entry, root, action, event, data_json)` / `json_field(json, key)` / `json_escape(text)` -> The shared envelope (with `repository.remote` and reserved `extra`), the plugin call, and flat-response parsing: see §5 **Plugin Payload Standard**.
  * `resolve_plugin_entrypoint(pdir, name)` -> Extension-agnostic plugin resolution (`run`, `$name`, `scripts/run`, `scripts/$name`, pattern match) with `.sample` exclusion filtering.
  * `cmd_plugins_status()` -> `aapp plugins`: **Kit Plugins** (every row of `lib/plugins.tsv`, installed or not, incl. `RESERVED (planned, …)`), a `==========================` delimiter, then **Your Plugins** (any other executable plugin in `.agents/skills/`, with a warning for unregistered `aapp-*` names). Fails closed when the registry is missing (P-46).
  * `cmd_hooks_status()` / `cmd_hook_hash()` -> Validates executable bits and live SHA-256 integrity against `.agents/skills/aapp-hooks/registry.tsv`.
* **Anti-Wrapper Warning:** Never bypass `registry.tsv` hash verification or run unhashed handlers in `mode=gate`.

### 📜 Verb Behaviour Contracts (`lib/docs/verbs/`)
* **Purpose:** Canonical owner of each daily verb's behaviour: ingress, preconditions, failure modes, effects, exit and derived tests (P-34). Resolve a verb's contract through the fifth column of `lib/verbs.tsv`.
* **Tests:** `tests/verbs/<verb>.sh` (run with `aapp test verb <verb>`); correspondence in `tests/verb_contracts_test.sh`.
* **Develop hook:** `templates/aapp-pre-commit-develop`, seeded into `.githooks/` by `aapp develop` only; removed by `aapp uninstall` inside the repository.
* **Anti-Wrapper Warning:** Never describe verb behaviour in skill prose that disagrees with the contract. Change the contract first, then the code and its verb suite. Mark current code that violates a contract line as `⚠️ Divergence`, not as intended behaviour.

### 🧪 Unified Test Runner Orchestrator (`lib/cmd_test.sh`)
* **Purpose:** Single entrypoint for automated test discovery, selective filtering, subshell isolation, execution timing, and assertion metric aggregation across all kit components.
* **Key Behaviors:**
  * Zero double-dash invariant: bare positional tokens (`list`, `strict`, `quiet`, `bail`).
  * Fail-closed sandbox propagation (`AAPP_TEST_SANDBOX_STRICT=1`).
  * Adopter mode fallback: delegates to `aapp.testCommand` / auto-detected project runner (`npm`, `cargo`, etc.) or performs non-destructive AAPP protocol environment health audit.
* **Anti-Wrapper Warning:** Never bypass subshell sandboxing or alter suite exit codes.

### 🔧 Auxiliary Commands
* `lib/cmd_develop.sh`: Symlinks local development checkout to global bin/share for live editing.
* `lib/cmd_upgrade.sh`: Upgrades global installation in-place from upstream repository.
* `lib/cmd_uninstall.sh`: Uninstalls binary and share data, cleaning dangling symlinks safely.
* `lib/cmd_help.sh`: Command catalog and usage instructions; `aapp help <verb>` prints that verb's contract from the installed kit (the agents' reference for verbs no skill covers, P-47).

---

## 🔒 3. Enforcement Engines & Hook Templates (`templates/`)

### 🛡️ Layer 1 Write-Time Interceptor (`templates/blast-radius-guard.sh`)
* **Purpose:** PreToolUse hook intercepting file-writing tools (`Write`, `Edit`, `MultiEdit`) before disk touches.
* **Evaluation Pipeline:**
  1. Section 1: Argument validation & lexical path canonicalization.
  2. Section 2: Repository self-protection (`.git/*`, `.githooks/*`, `.agents/skills/*`, `.claude/settings*`).
  3. Section 2b: External hard-deny (credentials, SSH/GPG keys, shell configs, system binaries).
  4. Section 2c: External path allowlists (agent scratchpads, temp dirs, `aapp.allowPath`).
  5. Section 2d: Project Circuit Breaker (emergency pause check; allows `.plans/*` and `.agents/*` only).
  6. Section 3: Workspace invariant allowlists (`.plans/*`, `.agents/*`, documentation anchors).
  7. Section 4: Blueprint Blast Radius matching (3-tier fast path: exact, prefix, pure-Bash glob).
  8. Section 5: Single-active-plan isolation (evaluates designated `⚡` buffer or single active plan).

### 🛑 Layer 2 Commit-Time Gate (`templates/aapp-pre-commit`)
* **Purpose:** Authoritative git pre-commit gate verifying staged changes before recording commit objects.
* **Enforcement Gates:**
  1. Section 0b: Project Circuit Breaker (refuses code commits while project is paused; allows `.plans/*` and `.agents/*`).
  2. Blast Radius compliance across non-bypass staged files.
  3. Frozen Plan Immutability: Rejects edits to `## 2. Technical Blueprint` and `## 4. Blast Radius` on `🟢 Frozen` plans.
  4. Changelog verification: Enforces `CHANGELOG.md` entry for any code changes.
  5. Issue roadmap hygiene: Auto-prunes resolved issues (`✅`/`Resolved`) in <5ms.
  6. Relocation Invariant: Detects and blocks active `ISSUES.md` if resolved rows are committed.
  7. Worktree isolation & Fail-Closed Quarantine: Refuses execution if `.plans/` is missing or unmounted.

### ✍️ Commit Message & Note Hooks
* `templates/commit-msg` / `templates/aapp-commit-msg`: Enforces <=72 char subject line conciseness, validates semantic trailers (`AI-Agent:`, etc.), permits git reverts.
* `templates/post-commit` / `templates/aapp-post-commit`: Attaches Option C staged notes to `refs/notes/commits`, cleans buffer with `&&`, reaps expired buffers.

---

## 🚦 4. Interface Contracts & Architectural Invariants

1. **Path Resolution:** Always resolve repository root via `git rev-parse --show-toplevel` or git common directory. Do NOT use fragile relative assumptions like `../../`.
2. **Never Edit Generated Artifacts Directly:** Never edit `.githooks/*` directly; edit `templates/` and run `aapp init` to synchronize.
3. **Two-Lane Boundary:** Never merge bugs into `state_matrix.md` or raw feature blueprints into `issues_road_map.md`. Large bug fixes are promoted to blueprints via `digest ISSUE-00X`.
4. **Relocation Invariant:** Active `ISSUES.md` holds ONLY unresolved items (`🟡`, `🔵`, `🟠`). Resolved issues belong exclusively in `.plans/done/000-issues-archive.md`.

---

## 🔌 5. Canonical Extension Points & Action Plugins Registry

To prevent naming drift across development, blueprint authoring, and runtime tooling, standard plugin extension points are cataloged here. The runtime switchboard and `aapp plugins` inspect these standard names directly:

| Plugin Name | Namespace / Role | Invocation Trigger | Input / Output Contract | Shipped Sample Source | Installed Target |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`aapp-planid`** | Core Identity | `allocate_plan_id` (`lib/plan_resolver.sh`) | Payload Standard: `plan.allocate` → `{"id": "P-<int>"}` | `examples/plugins/aapp-planid/run.sample` | `.agents/skills/aapp-planid/run` |
| **`aapp-issue-tracker`** | Core Identity | `allocate_issue_id` (`lib/plan_resolver.sh`), `issue_notify_close` (`lib/cmd_issue.sh`) | Payload Standard: `issue.allocate` → `{"id": "#<int>"}`; `issue.close` → `{"status": …}`, fire-and-forget | `examples/plugins/aapp-issue-tracker/run.sample` | `.agents/skills/aapp-issue-tracker/run` |
| **`aapp-review`** *(P-15)* | Code Quality | `/aapp-review` / CLI dispatch | Review Packet JSON on `stdin` → Markdown findings on `stdout` | `examples/plugins/aapp-review/run.sample` | `.agents/skills/aapp-review/run` |
| **`hello-tool`** | Showcase / Demo | `aapp hello-tool` | CLI arguments → stdout greeting | `examples/plugins/hello-tool/run.sample` | `.agents/skills/hello-tool/run` |

### 📨 Plugin Payload Standard (Dual Delivery, P-32)
Every action plugin the kit calls (`aapp-planid`, `aapp-issue-tracker`) speaks one contract, the same envelope lifecycle hooks receive. Built by `build_event_envelope`, sent by `run_action_plugin`, read by `json_field` (all in `lib/hook_dispatcher.sh`).

**stdin: JSON envelope**
```json
{
  "version": "1.0",
  "event": "issue.close",
  "timestamp": "2026-09-29T14:02:11Z",
  "actor": "lorand",
  "repository": {
    "root": "/path/to/project",
    "branch": "develop",
    "remote": { "name": "origin", "url": "git@github.com:acme/app.git" }
  },
  "data": { "id": "#79", "commit": "e07811f", "summary": "…", "plan": "P-32" },
  "extra": {}
}
```
* **`event`:** `plan.allocate`, `issue.allocate`, `issue.close` (hooks keep their lifecycle names).
* **`repository.remote`:** `aapp.remote` (default `origin`) via `git remote get-url`; credentials stripped (`user:secret@`, any userinfo on http/https); `null` without a remote. Identifies the team project to a remote authority.
* **`extra`:** reserved for arbitrary data, `{}` by default; the kit never interprets it.
* **env (shell plugins):** `AAPP_ACTION` (`allocate` / `close`), `AAPP_REPO_ROOT`; on close `AAPP_ISSUE_ID`, `AAPP_COMMIT_SHA`, `AAPP_SUMMARY`.

**stdout: one flat JSON object; the exit code decides**

| Event | stdout | Exit |
| :--- | :--- | :--- |
| `*.allocate` | `{"id": "P-42"}` / `{"id": "#97"}` (or a bare integer) | 0 issued; non-zero refuses, **no local fallback** |
| `issue.close` | `{"status": "accepted"}` / `{"status": "queued"}` | status printed; non-zero **only warns** (fire-and-forget) |
| any failure | optional `{"error": "<text>"}` | non-zero; the text is shown |

* A response may add `"extra": {…}`; the kit ignores it. Plain-text output is rejected.
* Plugin **absence** falls back to the local counter; a present plugin that fails is fatal for `allocate`.

### 📋 Extension Point Rules
1. **Verbatim Naming Invariant:** Shipped sample directories in `examples/plugins/<name>/` match the canonical installed plugin directory in `.agents/skills/<name>/` **verbatim**. No rename translation mapping is permitted.
2. **The `.sample` Inactive Suffix:** Reference examples carry the `.sample` suffix (`run.sample`, `.sample/` directories). The execution engine and resolver strictly ignore `.sample` assets until an adopter explicitly activates them.
3. **Runtime Source of Truth:** `lib/plugins.tsv` (P-46) is the shipped registry of kit-reserved names (`name`, `role`, `state` = `shipped` | `planned:<plan-id>`, `events`, `counter`, `sample`); this table documents it. It is kit-owned and replaced on every install/upgrade — adopters never edit it, and their own plugins need no row. A new kit plugin is one registry row; a test fails when a sample directory or a plugin-name literal in `lib/` has no row.

