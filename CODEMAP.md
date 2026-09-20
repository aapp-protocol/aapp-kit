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
* **Responsibilities:** Resolves global share directory vs drop-in checkout (`AAPP_IS_DROP_IN`, `AAPP_BASE`), exports core environment variables, and delegates to `lib/` modules.
* **Anti-Wrapper Warning:** Never write wrapper shell scripts around `aapp` commands; invoke `aapp` directly.

---

## ⚙️ 2. Operational Modules & Command Libraries (`lib/`)

### 📦 Workspace Initializer & Worktree Manager (`lib/cmd_init.sh`)
* **Purpose:** Single source of truth for target repository resolution, multi-orphan worktree mounting, delimited block synchronization, and Claude Code settings bridging.
* **Key Functions / Blocks:**
  * `mount_or_create_worktree(branch, dir)` -> Safely provisions or mounts orphan worktrees (`plans`, `agents`, `githooks`).
  * `sync_agent_rules()` -> Delimited block updater (`<!-- AAPP-PROTOCOL:START -->` ... `<!-- AAPP-PROTOCOL:END -->`) preserving custom user rules in `AGENTS.md`.
  * `copy_guarded(src, target, msg)` -> Non-destructive file copy that never overwrites existing user content.
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
  * `aapp freeze-start <plan>` -> Atomic validator, disjointness check, status update (`⚡`), and buffer binding.
  * `aapp start <plan>` -> Activates frozen specification (`🔷`) into development (`⚡`).
  * `aapp active [id]` -> Displays or sets active plan pointer buffer (`$(git rev-parse --git-path aapp_active_plan)`).
  * `aapp active swap` / `aapp active clear` -> Toggles between current and previous buffer or clears context.
  * `aapp plan-status [id]` -> Deterministic read-only inspector for plan matrix or specific blueprint.
  * `aapp plan [query]` -> Educational planning switchboard guiding users and agents.
  * Disjointness Activation Gate -> Enforces non-overlapping target file sets between concurrent `⚡ In Development` plans.
* **Anti-Wrapper Warning:** Never manually write to `.git/aapp_active_plan` without going through `cmd_plan.sh`.

### 🧭 Plan ID Standards & Shorthand Resolver (`lib/plan_resolver.sh`)
* **Purpose:** Canonical resolver for ADR-style Plan IDs (`P-<num>`), filenames, and slugs.
* **Key Functions:**
  * `resolve_plan_path(query)` -> Maps `P-13`, `13`, `guard-path`, or `P13-*.md` to absolute blueprint path.
  * `get_plan_id(path)` -> Extracts the declared unpadded Plan ID from a blueprint header.
  * `get_next_plan_id()` -> **Read-only peek** at the next Plan ID from the `aapp.planId` counter. Never mutates; claims nothing.
  * `allocate_plan_id()` -> **Claims** a Plan ID and persists the increment. Delegates to an optional `aapp-planid` provider plugin (`.agents/skills/aapp-planid/`); only plugin *absence* falls back to the local counter, a present-but-failing provider is fatal.
  * `normalize_plan_id(raw)` -> Accepts `P-42` or bare `42`; anything not a plain integer is an error.
  * `verify_transition_target(cmd, target)` -> Rejects empty queries and `#`-prefixed issue collisions.
* **Anti-Wrapper Warning:** Do not parse plan filenames using raw ad-hoc `grep` or `cut`; use `resolve_plan_path`.
* **Allocation Warning:** Plan IDs are **stored, not derived**. Never reconstruct an ID by scanning filenames or the archive ledger — that approach was removed (issue `#69`). Use `allocate_plan_id` to claim, `get_next_plan_id` to display.

### 🛡️ Planning Health Integrity Engine (`lib/planning_health.sh`)
* **Purpose:** Automated mechanical integrity validator running 7 orthogonal verification pairs:
  * **Pair 1:** Disjointness between active `ISSUES.md` and `000-issues-archive.md`.
  * **Pair 2:** Referential integrity between `issues_road_map.md` and active `ISSUES.md`.
  * **Pair 3:** Pickup queue routing hygiene (`.plans/pickup.md`).
  * **Pair 4:** Plan ID uniqueness, header agreement, and reference integrity.
  * **Pair 5:** Self-protection safety (blocks Section 2 targets in blueprint `Target Files`).
  * **Pair 6:** Recorded hexadecimal commit SHA existence in git object database.
  * **Pair 7:** Concurrent boundary collision detection for multiple `⚡ In Development` plans.
* **Anti-Wrapper Warning:** Keep health checks mechanical, fast, and free of external runtime dependencies.

### 🏷️ AI Attribution Switchboard (`lib/cmd_ai.sh`)
* **Purpose:** Governs AI attribution modes (`none`, `commit`, `notes`) and credits roster generation.
* **Key Commands & Behaviors:**
  * `aapp ai-commit` / `aapp ai-notes` / `aapp ai-off` -> Switchboard state machine.
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
  * `resolve_plugin_entrypoint(pdir, name)` -> Extension-agnostic plugin resolution (`run`, `$name`, `scripts/run`, `scripts/$name`, pattern match) with `.sample` exclusion filtering.
  * `cmd_plugins_status()` -> Authoritative CLI inspection command (`aapp plugins`) reporting status of hardcoded standard extension points (`aapp-planid`, `hello-tool`) and custom user plugins.
  * `cmd_hooks_status()` / `cmd_hook_hash()` -> Validates executable bits and live SHA-256 integrity against `.agents/skills/aapp-hooks/registry.tsv`.
* **Anti-Wrapper Warning:** Never bypass `registry.tsv` hash verification or run unhashed handlers in `mode=gate`.

### 🔧 Auxiliary Commands
* `lib/cmd_develop.sh`: Symlinks local development checkout to global bin/share for live editing.
* `lib/cmd_upgrade.sh`: Upgrades global installation in-place from upstream repository.
* `lib/cmd_uninstall.sh`: Uninstalls binary and share data, cleaning dangling symlinks safely.
* `lib/cmd_help.sh`: Command catalog and usage instructions.

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
| **`aapp-planid`** | Core Identity | `allocate_plan_id` (`lib/plan_resolver.sh`) | `AAPP_ACTION=allocate` → stdout `P-<int>` (or bare `<int>`) | `examples/plugins/aapp-planid/run.sample` | `.agents/skills/aapp-planid/run` |
| **`aapp-review`** *(P-15)* | Code Quality | `/aapp-review` / CLI dispatch | Review Packet JSON on `stdin` → Markdown findings on `stdout` | `examples/plugins/aapp-review/run.sample` | `.agents/skills/aapp-review/run` |
| **`hello-tool`** | Showcase / Demo | `aapp hello-tool` | CLI arguments → stdout greeting | `examples/plugins/hello-tool/run.sample` | `.agents/skills/hello-tool/run` |

### 📋 Extension Point Rules
1. **Verbatim Naming Invariant:** Shipped sample directories in `examples/plugins/<name>/` match the canonical installed plugin directory in `.agents/skills/<name>/` **verbatim**. No rename translation mapping is permitted.
2. **The `.sample` Inactive Suffix:** Reference examples carry the `.sample` suffix (`run.sample`, `.sample/` directories). The execution engine and resolver strictly ignore `.sample` assets until an adopter explicitly activates them.
3. **Runtime Source of Truth:** Because production adopter repositories do not retain `CODEMAP.md`, `cmd_plugins_status()` in `lib/cmd_hook.sh` hardcodes this catalog to report status (Active, Sample Available, or Fallback) directly in the CLI.

