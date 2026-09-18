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
  * `aapp freeze-start <plan>` -> Atomic validator, disjointness check, status update (`🟠`), and buffer binding.
  * `aapp start <plan>` -> Activates frozen specification (`🟢`) into development (`🟠`).
  * `aapp active [id]` -> Displays or sets active plan pointer buffer (`$(git rev-parse --git-path aapp_active_plan)`).
  * `aapp active swap` / `aapp active clear` -> Toggles between current and previous buffer or clears context.
  * `aapp plan-status [id]` -> Deterministic read-only inspector for plan matrix or specific blueprint.
  * `aapp plan [query]` -> Educational planning switchboard guiding users and agents.
  * Disjointness Activation Gate -> Enforces non-overlapping target file sets between concurrent `🟠 In Development` plans.
* **Anti-Wrapper Warning:** Never manually write to `.git/aapp_active_plan` without going through `cmd_plan.sh`.

### 🧭 Plan ID Standards & Shorthand Resolver (`lib/plan_resolver.sh`)
* **Purpose:** Canonical resolver for ADR-style Plan IDs (`P-<num>`), filenames, and slugs.
* **Key Functions:**
  * `resolve_plan_path(query)` -> Maps `P-13`, `13`, `guard-path`, or `P13-*.md` to absolute blueprint path.
  * `get_plan_id(path)` / `get_next_plan_id(dir)` -> Extracts or increments unpadded numeric Plan IDs.
  * `verify_transition_target(cmd, target)` -> Rejects empty queries and `#`-prefixed issue collisions.
* **Anti-Wrapper Warning:** Do not parse plan filenames using raw ad-hoc `grep` or `cut`; use `resolve_plan_path`.

### 🛡️ Planning Health Integrity Engine (`lib/planning_health.sh`)
* **Purpose:** Automated mechanical integrity validator running 7 orthogonal verification pairs:
  * **Pair 1:** Disjointness between active `ISSUES.md` and `000-issues-archive.md`.
  * **Pair 2:** Referential integrity between `issues_road_map.md` and active `ISSUES.md`.
  * **Pair 3:** Pickup queue routing hygiene (`.plans/pickup.md`).
  * **Pair 4:** Plan ID uniqueness, header agreement, and reference integrity.
  * **Pair 5:** Self-protection safety (blocks Section 2 targets in blueprint `Target Files`).
  * **Pair 6:** Recorded hexadecimal commit SHA existence in git object database.
  * **Pair 7:** Concurrent boundary collision detection for multiple `🟠 In Development` plans.
* **Anti-Wrapper Warning:** Keep health checks mechanical, fast, and free of external runtime dependencies.

### 🏷️ AI Attribution Switchboard (`lib/cmd_ai.sh`)
* **Purpose:** Governs AI attribution modes (`none`, `commit`, `notes`) and credits roster generation.
* **Key Commands & Behaviors:**
  * `aapp ai-commit` / `aapp ai-notes` / `aapp ai-off` -> Switchboard state machine.
  * `aapp ai-note --stage` -> Pre-stages Option C note buffer keyed by commit message SHA-256.
  * `aapp ai-credits` -> Append-only union generator updating `AI Contributors` roster in `README.md`.
* **Anti-Wrapper Warning:** Never emit fake email addresses (`Co-authored-by: Agent <email>`).

### 📊 Context Recovery Briefing (`lib/cmd_status.sh`)
* **Purpose:** Read-only four-pillar context recovery agent inspecting Shipped (`CHANGELOG.md`), Issues (`ISSUES.md`), Plans (`state_matrix.md`), and Pickup (`pickup.md`).
* **Anti-Wrapper Warning:** Must remain strictly non-destructive and idempotent.

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
  5. Section 3: Workspace invariant allowlists (`.plans/*`, `.agents/*`, documentation anchors).
  6. Section 4: Blueprint Blast Radius matching (3-tier fast path: exact, prefix, pure-Bash glob).
  7. Section 5: Single-active-plan isolation (evaluates designated `🟠` buffer or single active plan).

### 🛑 Layer 2 Commit-Time Gate (`templates/aapp-pre-commit`)
* **Purpose:** Authoritative git pre-commit gate verifying staged changes before recording commit objects.
* **Enforcement Gates:**
  1. Blast Radius compliance across non-bypass staged files.
  2. Frozen Plan Immutability: Rejects edits to `## 2. Technical Blueprint` and `## 4. Blast Radius` on `🟢 Frozen` plans.
  3. Changelog verification: Enforces `CHANGELOG.md` entry for any code changes.
  4. Issue roadmap hygiene: Auto-prunes resolved issues (`✅`/`Resolved`) in <5ms.
  5. Relocation Invariant: Detects and blocks active `ISSUES.md` if resolved rows are committed.
  6. Worktree isolation & Fail-Closed Quarantine: Refuses execution if `.plans/` is missing or unmounted.

### ✍️ Commit Message & Note Hooks
* `templates/commit-msg` / `templates/aapp-commit-msg`: Enforces <=72 char subject line conciseness, validates semantic trailers (`AI-Agent:`, etc.), permits git reverts.
* `templates/post-commit` / `templates/aapp-post-commit`: Attaches Option C staged notes to `refs/notes/commits`, cleans buffer with `&&`, reaps expired buffers.

---

## 🚦 4. Interface Contracts & Architectural Invariants

1. **Path Resolution:** Always resolve repository root via `git rev-parse --show-toplevel` or git common directory. Do NOT use fragile relative assumptions like `../../`.
2. **Never Edit Generated Artifacts Directly:** Never edit `.githooks/*` directly; edit `templates/` and run `aapp init` to synchronize.
3. **Two-Lane Boundary:** Never merge bugs into `state_matrix.md` or raw feature blueprints into `issues_road_map.md`. Large bug fixes are promoted to blueprints via `digest ISSUE-00X`.
4. **Relocation Invariant:** Active `ISSUES.md` holds ONLY unresolved items (`🟡`, `🔵`, `🟠`). Resolved issues belong exclusively in `.plans/done/000-issues-archive.md`.
