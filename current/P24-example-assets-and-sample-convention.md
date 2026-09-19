# 🗺️ Plan P-24: Example Asset Preservation & Sample Hook/Plugin Convention
* **Created:** 2026-09-19 | **Last Refined:** 2026-09-19
* **Target Issue / Milestone:** Distribution & Packaging Architecture
* **Plan ID:** P-24
* **Status:** 🟣 Under Review
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 5. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.

---

## 1. Context & Architectural Goal

AAPP's mock examples are actively expanding (`examples/hooks/`, `examples/plugins/`, and future mock providers like `planid-remote/run`). Adopters and AI agents require these reference examples on the machine to inspect canonical patterns and copy working templates.

Currently, `lib/cmd_install.sh:84-87` copies `lib/`, `templates/`, and `tests/` to `$SHARE_DIR` (`~/.local/share/aapp-kit/`), but omits `examples/`. When the installer self-consumes the temporary clone directory, all examples are permanently lost from the machine.

Furthermore, shipping mock plugins and hooks requires a strict safety convention so they cannot be accidentally executed, matched by dynamic command dispatch, or run as lifecycle gates:
- If a sample hook script exists in a repo, it must not execute unless explicitly registered in `registry.tsv`.
- If an action plugin sample exists in `.agents/skills/` (or `examples/`), it must not be picked up by dynamic command fallthrough (`aapp <cmd>`) or provider resolution (`resolve_plugin_entrypoint`).

Adopting the canonical **`.sample` convention** (mirroring Git's `.git/hooks/*.sample`) makes reference files completely inert by default.

This blueprint was decoupled from Plan P-22 on developer direction to maintain strict separation of concerns: P-22 owns runtime Plan ID allocation (`#69`), while P-24 owns distribution asset preservation, `.sample` conventions, and drop-in mode asset handling.

---

## 2. Technical Blueprint

### 2.1 Global Installation Asset Preservation (`lib/cmd_install.sh`)

`lib/cmd_install.sh` installs the AAPP suite into the user's home directory (`$SHARE_DIR`, defaulting to `~/.local/share/aapp-kit`). Lines 84-87 currently copy only libraries, templates, and tests.

Update `lib/cmd_install.sh` to copy `examples/` alongside the other directories:
```bash
[ -d "$AAPP_SCRIPT_DIR/examples" ] && cp -r "$AAPP_SCRIPT_DIR/examples" "$SHARE_DIR/"
```

When `aapp install` finishes and self-consumes the temporary source clone, `$SHARE_DIR/examples/` remains intact on the host machine for browsing and reference.

### 2.2 The `.sample` Suffix Convention

Mock plugins and hooks adopt a standard `.sample` naming convention:

| Asset Type | Sample Convention | Behavior When Ignored | Activation Workflow |
| :--- | :--- | :--- | :--- |
| **Action Plugins** | `run.sample` or `.agents/skills/<name>.sample/` | Completely ignored by dynamic CLI dispatch and plugin resolution. | Developer/agent copies or renames: `cp run.sample run && chmod +x run`. |
| **Lifecycle Hooks** | `examples/hooks/<name>.sh.sample` | Completely ignored by `hook_dispatcher.sh` (requires explicit registration in `registry.tsv`). | Developer copies script, registers with `aapp hook-hash`, and records hash in `registry.tsv`. |

### 2.3 Engine Filtering in `resolve_plugin_entrypoint` & `aapp` Switchboard

To guarantee that `.sample` assets cannot be accidentally executed:

1. **Resolver Pattern Filtering (`resolve_plugin_entrypoint`)**:
   In `lib/hook_dispatcher.sh` (and `lib/cmd_hook.sh`), pattern expansion explicitly skips `.sample` files:
   ```bash
   for f in "$pdir/$name".* "$pdir/run".* "$pdir/scripts/$name".* "$pdir/scripts/run".*; do
       case "$f" in
           *.sample|*.sample.*|*.bak|*~) continue ;;
       esac
       if [ -x "$f" ]; then echo "$f"; return 0; fi
   done
   ```

2. **Switchboard Directory Guard (`aapp` line 159)**:
   In the dynamic subcommand fallthrough in `aapp`:
   ```bash
   case "$CMD" in
       *.sample) exit 127 ;; # Do not execute sample plugins directly
   esac
   ```

### 2.4 Inspection & Audit Behavior (`aapp plugins` & `aapp hooks`)

- **`aapp plugins`**:
  Display installed action plugins under `🔌 Installed Action Plugins`. Optionally list `.sample` skills under `💡 Available Samples (Inactive)`.
- **`aapp hooks`**:
  If a user accidentally registers a path ending in `.sample` in `registry.tsv`, `aapp hooks` reports an advisory warning:
  `⚠️ Warning: Registered hook points to a sample file (.sample)`

### 2.5 Drop-in Mode Asset Handling (`lib/cmd_init.sh`)

In drop-in mode (`./aapp-kit/aapp init`), an adopting repository consumes the kit directory upon initialization (Phase 7, `lib/cmd_init.sh:715-731`).
**The exact disposition of `examples/` during drop-in mode is undecided and held as Open Question 1.**
Candidate options include:
- **Option A (Host Share Dir)**: Copy `examples/` to `$HOME/.local/share/aapp-kit/examples/` so the host retains them without polluting the adopter repository.
- **Option B (Adopter Repo Copy)**: Copy `.sample` assets into the adopter repo (e.g. `.agents/skills/samples/` or `.plans/examples/`).
- **Option C (Minimal Consumption)**: Keep drop-in minimal with kit folder self-consumed and no examples copied.
- **Option D (Interactive Opt-in)**: Provide an explicit flag (e.g. `aapp init --with-examples`).

Phase 7 remains completely untouched until Open Question 1 is resolved.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Foundation & Test Setup
- [ ] Task 1.1: Add assertions in `tests/install_test.sh` verifying that `examples/` is copied to `$SHARE_DIR/examples/` during `aapp install`.
- [ ] Task 1.2: Add unit tests in `tests/hooks_test.sh` asserting that `resolve_plugin_entrypoint` ignores `run.sample` and `*.sample` files even if executable.

### Phase 2: Engine Guards Implementation
- [ ] Task 2.1: Add the `.sample` exclusion filter to `resolve_plugin_entrypoint` in `lib/hook_dispatcher.sh` (or `lib/cmd_hook.sh`).
- [ ] Task 2.2: Add the `.sample` subcommand block in the `aapp` switchboard.

### Phase 3: Global Installation Update
- [ ] Task 3.1: Update `lib/cmd_install.sh` to copy `examples/` to `$SHARE_DIR/examples/`.

### Phase 4: Mock Asset Renaming & Packaging
- [ ] Task 4.1: Rename `examples/plugins/hello-tool/run` to `examples/plugins/hello-tool/run.sample`.
- [ ] Task 4.2: Rename `examples/hooks/*.sh` to `*.sh.sample`.
- [ ] Task 4.3: Ensure shipped `examples/plugins/planid-remote/` uses `run.sample`.

### Phase 5: Drop-In Mode Resolution
- [ ] Task 5.1: Resolve Open Question 1 regarding drop-in mode asset disposition.
- [ ] Task 5.2: If decided, implement the chosen strategy in `lib/cmd_init.sh` Phase 7.

### Phase 6: Verification & Documentation
- [ ] Task 6.1: Run all test suites; verify zero regressions.
- [ ] Task 6.2: Document the `.sample` convention in `MANUAL.md` and `README.md`.
- [ ] Task 6.3: Update `CHANGELOG.md` and run syntax checks before committing.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
- [ ] `lib/cmd_install.sh` -> Copy `examples/` to `$SHARE_DIR/examples/` during `aapp install`.
- [ ] `tests/install_test.sh` -> Assert `examples/` copied to `$SHARE_DIR` on install.
- [ ] `lib/hook_dispatcher.sh` -> Filter `*.sample` in `resolve_plugin_entrypoint`.
- [ ] `lib/cmd_hook.sh` -> Filter `*.sample` and audit sample hooks.
- [ ] `aapp` -> Prevent `aapp <cmd>` fallthrough from executing `.sample` directories.
- [ ] `tests/hooks_test.sh` -> Test `.sample` ignore behavior.
- [ ] `examples/plugins/hello-tool/run.sample` -> Renamed sample action plugin.
- [ ] `examples/hooks/fallback-ratchet.sh.sample` -> Renamed sample hook.
- [ ] `examples/hooks/on-done-sync.sh.sample` -> Renamed sample hook.
- [ ] `MANUAL.md` -> Document sample convention and installation assets.
- [ ] `README.md` -> Document reference samples.
- [ ] `CHANGELOG.md` -> Record under Unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/plan_resolver.sh` -> Plan ID resolution is owned exclusively by P-22.
- [ ] `lib/cmd_init.sh:452-476` -> Counter seeding owned exclusively by P-22.
- [ ] `lib/planning_health.sh` -> Integrity backstop is out of scope.
- [ ] `.claude/skills/aapp-*` -> Guard Section 2 self-protected.
- [ ] `.agents/skills/aapp-*` -> Guard Section 2 self-protected.

---

## ❓ 5. Open Questions (Optional / Gate)

* [ ] **Question 1 — Drop-In Mode Asset Handling (Undecided).** What should happen to `examples/` during drop-in repo initialization (`./aapp-kit/aapp init`) when the kit folder self-consumes? Options: (a) Copy `examples/` to `$HOME/.local/share/aapp-kit/examples/` so the host machine retains them without polluting the adopter repository; (b) Copy into adopter repo (e.g. `examples/` or `.plans/examples/`); (c) Keep drop-in minimal with kit folder self-consumed and no examples copied; (d) Interactive prompt or user opt-in flag. *Held strictly open per developer directive.*
* [ ] **Question 2 — In-Place Rename vs Dual Shipping.** Should reference examples in `examples/` be renamed strictly to `*.sample`, or should both active and `.sample` files be shipped in distinct folders (e.g. `examples/samples/`)?
* [ ] **Question 3 — `aapp plugins` Display.** Should `aapp plugins` show available `.sample` plugins in an "Inactive Samples" section, or should they be completely silent unless activated?

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-09-19:** Plan scaffolded and decoupled from P-22 on developer direction. Formulates installation asset preservation (`$SHARE_DIR/examples/`), the inert `.sample` suffix convention for mock plugins and hooks, engine filtering guards, and defers drop-in mode asset disposition under Open Question 1.
