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

AAPP's mock examples are actively expanding (`examples/hooks/`, `examples/plugins/`, and future mock providers like `examples/plugins/aapp-planid/run`). Adopters and AI agents require these reference examples on the machine to inspect canonical patterns and copy working templates.

Currently, `lib/cmd_install.sh:84-87` copies `lib/`, `templates/`, and `tests/` to `$SHARE_DIR` (`~/.local/share/aapp-kit/`), but omits `examples/`. When the installer self-consumes the temporary clone directory, all examples are permanently lost from the machine.

Furthermore, shipping mock plugins and hooks requires a strict safety convention so they cannot be accidentally executed, matched by dynamic command dispatch, or run as lifecycle gates:
- If a sample hook script exists in a repo, it must not execute unless explicitly registered in `registry.tsv`.
- If an action plugin sample exists in `.agents/skills/` (or `examples/`), it must not be picked up by dynamic command fallthrough (`aapp <cmd>`) or provider resolution (`resolve_plugin_entrypoint`).

Adopting the canonical **`.sample` convention** (mirroring Git's `.git/hooks/*.sample`) makes reference files completely inert by default.

This blueprint was decoupled from Plan P-22 on developer direction to maintain strict separation of concerns: P-22 owns runtime Plan ID allocation (`#69`), while P-24 owns distribution asset preservation, `.sample` conventions, centralized `$SHARE_DIR` sample storage, and drop-in mode zero-footprint isolation.

---

## 2. Technical Blueprint

### 2.1 Global Installation Asset Preservation (`lib/cmd_install.sh`)

`lib/cmd_install.sh` installs the AAPP suite into the user's home directory (`$SHARE_DIR`, defaulting to `~/.local/share/aapp-kit`). Lines 84-87 currently clean and copy only libraries, templates, and tests.

Update `lib/cmd_install.sh` line 84 to include `${SHARE_DIR:?}/examples` in the cleanup list, and copy `examples/` alongside the other directories:
```bash
# Line 84: Clean existing directories before copying (ensures removed/renamed samples do not linger on upgrade)
rm -rf "${SHARE_DIR:?}/lib" "${SHARE_DIR:?}/templates" "${SHARE_DIR:?}/tests" "${SHARE_DIR:?}/examples"

# Lines 85-88: Copy assets
[ -d "$AAPP_SCRIPT_DIR/lib" ] && cp -r "$AAPP_SCRIPT_DIR/lib" "$SHARE_DIR/"
cp -r "$AAPP_SCRIPT_DIR/templates" "$SHARE_DIR/"
[ -d "$AAPP_SCRIPT_DIR/tests" ] && cp -r "$AAPP_SCRIPT_DIR/tests" "$SHARE_DIR/"
[ -d "$AAPP_SCRIPT_DIR/examples" ] && cp -r "$AAPP_SCRIPT_DIR/examples" "$SHARE_DIR/"
```

When `aapp install` finishes and self-consumes the temporary source clone, `$SHARE_DIR/examples/` remains intact on the host machine for browsing and reference.

### 2.2 The `.sample` Suffix Convention (Strict In-Place Suffixing)

Reference examples in `examples/` strictly adopt **in-place `*.sample` naming** with **no duplicate dual shipping**. This guarantees a single source of truth, eliminates maintenance drift between parallel copies, mirrors Git's canonical `.git/hooks/*.sample` paradigm, and ensures reference assets are inert across development checkouts, CI runs, and installed `$SHARE_DIR` directories.

| Asset Type | Canonical Path in Source | Behavior When Ignored | Activation Workflow |
| :--- | :--- | :--- | :--- |
| **Action Plugin Showcase** | `examples/plugins/hello-tool/run.sample` | Completely ignored by dynamic CLI dispatch and plugin resolution. | Developer/agent copies directory from `$SHARE_DIR/examples/plugins/hello-tool` to `.agents/skills/hello-tool` and renames entrypoint: `cp -r "$SHARE_DIR/examples/plugins/hello-tool" .agents/skills/hello-tool && mv .agents/skills/hello-tool/run.sample .agents/skills/hello-tool/run && chmod +x .agents/skills/hello-tool/run`. |
| **Team ID Provider Mock** | `examples/plugins/aapp-planid/run.sample` | Completely ignored by `allocate_plan_id`; resolver falls back to local git config. | Developer copies directory from `$SHARE_DIR/examples/plugins/aapp-planid` to `.agents/skills/aapp-planid`, renames entrypoint to `run`, adapts to network API, and marks executable: `cp -r "$SHARE_DIR/examples/plugins/aapp-planid" .agents/skills/aapp-planid && mv .agents/skills/aapp-planid/run.sample .agents/skills/aapp-planid/run && chmod +x .agents/skills/aapp-planid/run`. |
| **Quality Gate Hook** | `examples/hooks/fallback-ratchet.sh.sample` | Ignored by `hook_dispatcher.sh` (requires explicit entry in `registry.tsv`). | Developer copies script without `.sample` from `$SHARE_DIR/examples/hooks/`, marks executable, registers with `aapp hook-hash`, and records hash in `registry.tsv`. |
| **Lifecycle Observer Hook** | `examples/hooks/on-done-sync.sh.sample` | Ignored by `hook_dispatcher.sh`. | Developer copies script without `.sample` from `$SHARE_DIR/examples/hooks/`, marks executable, and registers with `aapp hook-hash`. |
| **Reference Hook Registry** | `examples/hooks/registry.tsv.sample` | Reference template showing 5-column TSV schema. | Copy reference entries into active `.agents/skills/aapp-hooks/registry.tsv`. |

#### Canonical Reference Hook Registry Schema (`examples/hooks/registry.tsv.sample`)
The reference registry template ships illustrative, commented standard hooks showing the strict 5-column TSV format:
```tsv
# event	handler_path	expected_sha256	timeout	mode
# on-freeze	examples/hooks/fallback-ratchet.sh	sha256:0000000000000000000000000000000000000000000000000000000000000000	10	gate
# on-done	examples/hooks/on-done-sync.sh	sha256:0000000000000000000000000000000000000000000000000000000000000000	15	notify
```

### 2.3 Engine Filtering in `resolve_plugin_entrypoint` & `aapp` Switchboard

To guarantee that `.sample` assets cannot be accidentally executed:

1. **Resolver Pattern Filtering (`resolve_plugin_entrypoint`)**:
   In `lib/hook_dispatcher.sh` (relocated from `lib/cmd_hook.sh` under P-22), pattern expansion explicitly skips `.sample` files and backup suffixes:
   ```bash
   for f in "$pdir/$name".* "$pdir/run".* "$pdir/scripts/$name".* "$pdir/scripts/run".*; do
       case "$f" in
           *.sample|*.sample.*|*.bak|*~) continue ;;
       esac
       if [ -x "$f" ]; then echo "$f"; return 0; fi
   done
   ```

2. **Switchboard Execution Guard & Delegation Consolidation (`aapp`)**:
   In `aapp` lines 156-185, replace the duplicated inline pattern search by reusing `resolve_plugin_entrypoint`. This guarantees that typing `aapp <cmd>` never executes an unrenamed `run.sample` even if marked executable:
   ```bash
   case "$CMD" in
       *.sample) exit 127 ;; # Do not execute sample plugins directly
   esac
   CWD_GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
   if [ -n "$CWD_GIT_ROOT" ] && [ -d "$CWD_GIT_ROOT/.agents/skills/$CMD" ]; then
       PLUGIN_DIR="$CWD_GIT_ROOT/.agents/skills/$CMD"
       CANDIDATE=""
       if command -v resolve_plugin_entrypoint >/dev/null 2>&1; then
           CANDIDATE="$(resolve_plugin_entrypoint "$PLUGIN_DIR" "$CMD" || true)"
       elif [ -f "$AAPP_LIB/hook_dispatcher.sh" ]; then
           # shellcheck source=/dev/null
           source "$AAPP_LIB/hook_dispatcher.sh"
           CANDIDATE="$(resolve_plugin_entrypoint "$PLUGIN_DIR" "$CMD" || true)"
       fi
       if [ -n "$CANDIDATE" ] && [ -x "$CANDIDATE" ]; then
           exec "$CANDIDATE" "$@"
       fi
   fi
   ```

### 2.4 Inspection & Audit Behavior (`aapp plugins` & `aapp hooks`)

In production, adopting repositories initialized with `aapp init` or `aapp install` do not retain the kit development repository's internal `CODEMAP.md`. Therefore, **the runtime code itself (`aapp plugins` in `lib/cmd_hook.sh`) must serve as the authoritative source of truth** by hardcoding the recognized standard extension points.

#### 1. Hardcoded Standard Extension Points Catalog & Sample Discovery (`cmd_plugins_status`)
`cmd_plugins_status()` in `lib/cmd_hook.sh` defines the known standard extension points, checks their status dynamically, and discovers available samples from `$AAPP_BASE/examples/plugins/` without polluting the project repository *(Note: This implementation is a complete replacement superseding the existing function in `lib/cmd_hook.sh:144-174`, not an in-place patch)*:

```bash
cmd_plugins_status() {
    local skills_dir="$REPO_ROOT/.agents/skills"
    echo "🔌 AAPP Action Plugins & Extension Points (.agents/skills/)"
    echo ""

    # 1. Standard Extension Points (Hardcoded Runtime Authority)
    echo "  Standard Extension Points:"
    
    # aapp-planid
    if [ -d "$skills_dir/aapp-planid" ] && resolve_plugin_entrypoint "$skills_dir/aapp-planid" "aapp-planid" >/dev/null 2>&1; then
        local entry="$(resolve_plugin_entrypoint "$skills_dir/aapp-planid" "aapp-planid")"
        printf "    • %-16s [Team Plan ID Authority] -> %s (ACTIVE)\n" "aapp-planid" "${entry#$REPO_ROOT/}"
    elif [ -d "$skills_dir/aapp-planid" ]; then
        local counter="$(git config --get aapp.planId 2>/dev/null || echo 1)"
        printf "    • %-16s [Team Plan ID Authority] -> .agents/skills/aapp-planid/ (CONFIGURED BUT NOT EXECUTABLE)\n" "aapp-planid"
        printf "      %-16s (Fallback Active: local git config aapp.planId = %s)\n" "" "$counter"
    elif [ -d "$AAPP_BASE/examples/plugins/aapp-planid" ]; then
        local counter="$(git config --get aapp.planId 2>/dev/null || echo 1)"
        printf "    • %-16s [Team Plan ID Authority] -> NOT INSTALLED (SAMPLE AVAILABLE in %s)\n" "aapp-planid" "${AAPP_BASE/#$HOME/\~}/examples/plugins/aapp-planid/"
        printf "      %-16s (Fallback Active: local git config aapp.planId = %s)\n" "" "$counter"
    else
        local counter="$(git config --get aapp.planId 2>/dev/null || echo 1)"
        printf "    • %-16s [Team Plan ID Authority] -> NOT INSTALLED\n" "aapp-planid"
        printf "      %-16s (Fallback Active: local git config aapp.planId = %s)\n" "" "$counter"
    fi

    # hello-tool (showcase)
    if [ -d "$skills_dir/hello-tool" ] && resolve_plugin_entrypoint "$skills_dir/hello-tool" "hello-tool" >/dev/null 2>&1; then
        local entry="$(resolve_plugin_entrypoint "$skills_dir/hello-tool" "hello-tool")"
        printf "    • %-16s [Custom CLI Showcase]   -> %s (ACTIVE)\n" "hello-tool" "${entry#$REPO_ROOT/}"
    elif [ -d "$skills_dir/hello-tool" ]; then
        printf "    • %-16s [Custom CLI Showcase]   -> .agents/skills/hello-tool/ (CONFIGURED BUT NOT EXECUTABLE)\n" "hello-tool"
    fi

    echo ""
    echo "  Custom Action Plugins:"
    local custom_count=0
    if [ -d "$skills_dir" ]; then
        for sdir in "$skills_dir"/*; do
            [ ! -d "$sdir" ] && continue
            local sname="$(basename "$sdir")"
            case "$sname" in
                aapp-*|aapp|plan|hello-tool|*.sample|node_modules|vendor) continue ;; # Skip core skills, standard points, and samples
            esac
            local entrypoint="$(resolve_plugin_entrypoint "$sdir" "$sname" || true)"
            if [ -n "$entrypoint" ]; then
                custom_count=$((custom_count + 1))
                printf "    • %-16s -> %s (executable via 'aapp %s')\n" "$sname" "${entrypoint#$REPO_ROOT/}" "$sname"
            fi
        done
    fi
    if [ "$custom_count" -eq 0 ]; then
        echo "    ℹ️  No custom action plugins found."
    fi

    # 3. Available Samples Discovery (Zero Repo Clutter)
    echo ""
    if [ "${AAPP_IS_DROP_IN:-0}" -eq 0 ] && [ -d "$AAPP_BASE/examples/plugins" ]; then
        local sample_count=0
        local sample_names=""
        for edir in "$AAPP_BASE/examples/plugins"/*; do
            [ ! -d "$edir" ] && continue
            sample_count=$((sample_count + 1))
            sample_names="${sample_names:+${sample_names}, }$(basename "$edir")"
        done
        if [ "$sample_count" -gt 0 ]; then
            echo "  📦 Available Plugin Samples ($sample_count):"
            echo "    • Location:  ${AAPP_BASE/#$HOME/\~}/examples/plugins/"
            echo "    • Available: $sample_names"
            echo "    • To adopt:  cp -r \"$AAPP_BASE/examples/plugins/<name>\" \"$skills_dir/\""
        fi
    else
        echo "  📦 Reference Samples:"
        echo "    • Documented in MANUAL.md and at:"
        echo "      https://github.com/aapp-protocol/aapp-kit/tree/main/examples/plugins"
        echo "    • Install globally to retain local samples: 'aapp install'"
    fi
}
```

#### 2. Lifecycle Hooks Audit & Sample Discovery (`aapp hooks`)
In `cmd_hooks_status()` (`lib/cmd_hook.sh`), if a registered handler path ends in `.sample`, the audit reports a distinct badge `⚠️  INERT SAMPLE` and outputs an advisory notice indicating the sample must be copied to an active script before triggering.

Additionally, `cmd_hooks_status()` reports available sample hooks directly from `$AAPP_BASE/examples/hooks/`:
```bash
if [[ "$hp" == *.sample ]]; then
    status_badge="⚠️  INERT SAMPLE"
fi

# Available Samples Discovery (Zero Repo Clutter)
echo ""
if [ "${AAPP_IS_DROP_IN:-0}" -eq 0 ] && [ -d "$AAPP_BASE/examples/hooks" ]; then
    local hook_sample_count=0
    local hook_sample_names=""
    for hfile in "$AAPP_BASE/examples/hooks"/*; do
        [ ! -f "$hfile" ] && continue
        hook_sample_count=$((hook_sample_count + 1))
        hook_sample_names="${hook_sample_names:+${hook_sample_names}, }$(basename "$hfile")"
    done
    if [ "$hook_sample_count" -gt 0 ]; then
        echo "  📦 Available Hook Samples ($hook_sample_count):"
        echo "    • Location:  ${AAPP_BASE/#$HOME/\~}/examples/hooks/"
        echo "    • Available: $hook_sample_names"
        echo "    • To adopt:  cp \"$AAPP_BASE/examples/hooks/<file>\" .githooks/ && aapp hook-hash ..."
    fi
else
    echo "  📦 Reference Samples:"
    echo "    • Documented in MANUAL.md and at:"
    echo "      https://github.com/aapp-protocol/aapp-kit/tree/main/examples/hooks"
    echo "    • Install globally to retain local samples: 'aapp install'"
fi
```

### 2.5 Drop-in Mode Zero-Footprint Isolation (Strict Self-Containment)

In drop-in mode (`./aapp-kit/aapp init`), an adopting repository consumes the transient kit directory upon successful initialization (Phase 7, `lib/cmd_init.sh:715-731`).

Rather than extracting reference samples into `.agents/skills/` or writing to `~/.local/share/`:

#### 1. Zero Repository Pollution & Agent Context Bloat
- **The Hot Path Invariant**: The `.agents/` worktree is the primary reasoning and rules context ("hot path") for AI coding agents. Any directory inside `.agents/` is actively scanned, indexed for embeddings, and read into model context windows.
- Seeding inert showcase mocks (`hello-tool`, `aapp-planid.sample`, mock hooks) into `.agents/` forces agents to burn token budgets on inactive files, clutters file pickers, and risks hallucinations where the agent assumes sample mocks are active project tools.
- Both global and drop-in modes keep `.agents/skills/` containing strictly the active, universal engine skills (`aapp-*`, `plan`).

#### 2. Strict Self-Containment (No "10% Install" Anti-Pattern)
- Writing to `~/.local/share/aapp-kit/` during drop-in initialization would violate the core contract of drop-in mode: **100% self-containment within the project directory**.
- A drop-in adoption must leave zero external footprint. If an adopter evaluates AAPP on a throwaway project and subsequently deletes the repository (`rm -rf project`), zero ghost directories or orphaned files remain on their machine.

#### 3. Distribution of Reference Assets
- Adopters who require local machine samples install the kit globally via `aapp install`, which populates `$SHARE_DIR/examples/` (`~/.local/share/aapp-kit/examples/`) in one central location for all repositories.
- Adopters evaluating via drop-in mode access reference templates directly via `MANUAL.md` or online at `https://github.com/aapp-protocol/aapp-kit/tree/main/examples`.
- `lib/cmd_init.sh` therefore requires **no sample extraction logic** (`sync_samples`), keeping the initialization engine minimal, robust, and fast.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

> **Sequencing Dependency Note:** Prerequisite Plan P-22 (`P22-config-backed-plan-id-allocation.md`) is completed and archived to `.plans/done/`. The relocation of `resolve_plugin_entrypoint` to `lib/hook_dispatcher.sh` and the baseline `examples/plugins/aapp-planid/` directory are live on `develop` (resolved under commit `d49d201`). Prerequisite gate is 100% satisfied.

### Phase 1: Foundation & Test Setup
- [ ] Task 1.1: Add assertions in `tests/install_test.sh` verifying that `examples/` is copied to `$SHARE_DIR/examples/` during `aapp install`, and that `${SHARE_DIR:?}/examples` is cleaned before copying.
- [ ] Task 1.2: Add unit tests in `tests/hooks_test.sh` asserting that `resolve_plugin_entrypoint` ignores `run.sample` and `*.sample` files even if marked executable.
- [ ] Task 1.3: Add test cases in `tests/install_test.sh` (Section 2) asserting that `aapp init` (in both drop-in and global modes) leaves `.agents/skills/` completely clean without any `.sample` directories or showcase files.

### Phase 2: Engine Guards & Plugins Catalog Implementation
- [ ] Task 2.1: Add the `.sample` exclusion filter to `resolve_plugin_entrypoint` in `lib/hook_dispatcher.sh`.
- [ ] Task 2.2: Update the dynamic subcommand fallthrough in `aapp` to block `*.sample` and reuse `resolve_plugin_entrypoint` so unrenamed `run.sample` files cannot be executed via `aapp <cmd>`.
- [ ] Task 2.3: Update `cmd_plugins_status()` in `lib/cmd_hook.sh` with the hardcoded standard extension points catalog (`aapp-planid`, `hello-tool`), checking `$AAPP_BASE/examples/plugins/` for sample availability, accurately reporting Active, Sample Available, Configured But Not Executable, and Fallback status, and outputting available plugin sample count and copy path.
- [ ] Task 2.4: Update `cmd_hooks_status()` in `lib/cmd_hook.sh` to audit registered hooks for `*.sample` (reporting `⚠️  INERT SAMPLE`) and output available hook sample count and copy path.

### Phase 3: Global Installation & Packaging
- [ ] Task 3.1: Update `lib/cmd_install.sh` to clean `${SHARE_DIR:?}/examples` on line 84 and copy `examples/` to `$SHARE_DIR/examples/`.
- [ ] Task 3.2: Strictly rename shipped source examples in `examples/` to use in-place `.sample` suffix (`examples/plugins/hello-tool/run.sample`, `examples/plugins/aapp-planid/run.sample`, `examples/hooks/fallback-ratchet.sh.sample`, `examples/hooks/on-done-sync.sh.sample`), and author `examples/hooks/registry.tsv.sample`.

### Phase 4: Drop-In Mode Zero-Footprint Verification
- [ ] Task 4.1: Verify in `tests/install_test.sh` that `lib/cmd_init.sh` leaves `.agents/skills/` pristine without seeding sample directories into the project worktree.
- [ ] Task 4.2: Verify `is_safe_to_consume_kit_dir` cleanly consumes `./aapp-kit` in drop-in mode without writing any external files or directories to `~/.local/share/`.

### Phase 5: Verification & Documentation
- [ ] Task 5.1: Run all test suites (`tests/install_test.sh`, `tests/hooks_test.sh`); verify zero regressions.
- [ ] Task 5.2: Document the `.sample` convention, centralized `$SHARE_DIR/examples/` storage, CLI sample discovery, and drop-in zero-footprint behavior in `MANUAL.md` and `README.md`.
- [ ] Task 5.3: Update `CHANGELOG.md` and run syntax checks before committing.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
- [ ] `lib/cmd_install.sh` -> Clean and copy `examples/` to `$SHARE_DIR/examples/` during `aapp install`.
- [ ] `lib/hook_dispatcher.sh` -> Filter `*.sample` in `resolve_plugin_entrypoint`.
- [ ] `lib/cmd_hook.sh` -> Filter `*.sample`, hardcode standard plugin catalog, report sample count & copy location, and audit sample hooks with `⚠️  INERT SAMPLE`.
- [ ] `aapp` -> Prevent `aapp <cmd>` fallthrough from executing `.sample` files or directories by delegating to `resolve_plugin_entrypoint`.
- [ ] `tests/install_test.sh` -> Assert `examples/` copied to `$SHARE_DIR` on install, and `aapp init` preserves zero-footprint isolation without `.sample` files.
- [ ] `tests/hooks_test.sh` -> Test `.sample` ignore behavior and `aapp plugins` / `aapp hooks` sample discovery output.
- [ ] `examples/plugins/hello-tool/run.sample` -> Renamed sample action plugin.
- [ ] `examples/plugins/aapp-planid/run.sample` -> Shipped mock planid provider.
- [ ] `examples/hooks/fallback-ratchet.sh.sample` -> Renamed sample hook.
- [ ] `examples/hooks/on-done-sync.sh.sample` -> Renamed sample hook.
- [ ] `examples/hooks/registry.tsv.sample` -> Reference 5-column TSV schema template.
- [ ] `MANUAL.md` -> Document sample convention, centralized `$SHARE_DIR/examples/`, CLI sample discovery, and drop-in zero-footprint behavior.
- [ ] `README.md` -> Document reference samples and central storage.
- [ ] `CHANGELOG.md` -> Record under Unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_init.sh` -> Preserved as-is (zero-footprint drop-in requires no sample syncing logic).
- [ ] `lib/plan_resolver.sh` -> Plan ID resolution is owned exclusively by P-22.
- [ ] `lib/planning_health.sh` -> Integrity backstop is out of scope.
- [ ] `.claude/skills/aapp-*` -> Guard Section 2 self-protected.
- [ ] `.agents/skills/aapp-*` -> Guard Section 2 self-protected.

---

## ❓ 5. Open Questions (Optional / Gate)

* [x] **Question 1 — Drop-In Mode Asset Handling & Centralized Storage. → RESOLVED (developer, 2026-09-21): centralized `$SHARE_DIR/examples/` for global installs; zero-footprint isolation for drop-in mode.** In global install mode, samples live centrally in `~/.local/share/aapp-kit/examples/` and are updated on every `aapp install`. Repositories stay 100% clean with zero sample clutter. In drop-in mode, no samples are extracted into the project or written to `~/.local/share/`, avoiding the '10% install' anti-pattern and orphaned files if the project is deleted. In-repo sample copying into `.agents/` was rejected because `.agents/` is an AI agent hot path where inert mocks cause token bloat and context clutter. `aapp plugins` and `aapp hooks` dynamically report sample count and copy paths.
* [x] **Question 2 — In-Place Rename vs Dual Shipping. → RESOLVED (developer, 2026-09-20): strict in-place `*.sample` suffixing.** Reference examples in `examples/` strictly ship single `*.sample` files. Dual shipping introduces duplicate copies that inevitably drift. Mirroring Git's `.git/hooks/*.sample` convention, reference assets remain inert everywhere by default and are tested by copying without `.sample` during test fixture setup.
* [x] **Question 3 — `aapp plugins` Display & Standard Authority. → RESOLVED (developer, 2026-09-20): hardcoded standard catalog in `cmd_plugins_status`.** Because adopter repositories in production do not retain `CODEMAP.md`, `aapp plugins` hardcodes the catalog of supported standard extension points (`aapp-planid`, `hello-tool`), reporting Active vs Sample Available vs Fallback status directly in the CLI.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-09-19:** Plan scaffolded and decoupled from P-22 on developer direction. Formulates installation asset preservation (`$SHARE_DIR/examples/`), the inert `.sample` suffix convention for mock plugins and hooks, and engine filtering guards.
* **2026-09-20 (amendment 1):** **Drop-in install with `.sample` suffix detailed on developer direction** — Added §2.5 specifying `sync_samples()` in `lib/cmd_init.sh` to extract mock plugins into `.agents/skills/<name>.sample/` and mock hooks into `.agents/skills/aapp-hooks/examples/*.sh.sample` prior to Phase 7 kit consumption. Added test tasks in Phase 1 & 4, added `lib/cmd_init.sh` and `tests/init_test.sh` to Target Files, and resolved Open Question 1.
* **2026-09-20 (amendment 2):** **Standard plugin catalog hardcoded in `aapp plugins` on developer direction** — Because production adopter repositories do not retain the kit repo's internal `CODEMAP.md`, `cmd_plugins_status()` in `lib/cmd_hook.sh` hardcodes the standard extension points catalog (`aapp-planid`, `hello-tool`) to serve as the runtime source of truth. Added Task 2.3 and resolved Open Question 3.
* **2026-09-20 (amendment 3):** **Strict in-place suffixing confirmed on developer direction** — Resolved Question 2 in favor of single in-place `*.sample` files across `examples/` (no dual shipping), eliminating duplication and maintenance drift. All three open questions are now resolved.
* **2026-09-20 (amendment 4):** **Safety hardening, switchboard consolidation & edge-case corrections** —
  1. Updated §2.1 to clean `${SHARE_DIR:?}/examples` on line 84 of `lib/cmd_install.sh` before copying.
  2. Fixed §2.2 activation instructions to specify copying/renaming the `.agents/skills/<name>.sample` directory alongside the entrypoint, and authored the reference `examples/hooks/registry.tsv.sample` schema.
  3. Closed dynamic switchboard execution loophole in `aapp` by delegating directly to `resolve_plugin_entrypoint`, blocking accidental execution of `run.sample` files.
  4. Corrected `cmd_plugins_status()` in §2.4 to avoid double-printing `hello-tool` under custom plugins, use `git config --get aapp.planId`, and distinguish `CONFIGURED BUT NOT EXECUTABLE` from `NOT INSTALLED`.
  5. Updated `sync_samples()` in §2.5 to overwrite `.sample` directories on `aapp init` so reference templates refresh on upgrades.
  6. Corrected non-existent `tests/init_test.sh` references across Phase 1, Phase 5, and Target Files to `tests/install_test.sh`.
  7. Formally recorded sequencing dependency following completion of Plan P-22.
* **2026-09-21 (amendment 5):** **Centralized `$SHARE_DIR` sample storage & drop-in zero-footprint isolation confirmed on developer direction** —
  1. **Rejected in-repo sample copying**: `.agents/` is a critical hot path for AI coding agents. Seeding inert `.sample` directories into `.agents/skills/` causes unnecessary token bloat, clutters file pickers, and risks agent hallucination.
  2. **Rejected drop-in partial install**: Writing to `~/.local/share/` during drop-in mode creates an undeclared '10% install' that leaves orphaned files on the host if a throwaway repository is deleted. Drop-in mode remains 100% self-contained.
  3. **Centralized global samples**: Global installs (`aapp install`) store all reference samples centrally in `$SHARE_DIR/examples/` (`~/.local/share/aapp-kit/examples/`), refreshed in one place on every kit update.
  4. **CLI sample discovery**: Updated `aapp plugins` and `aapp hooks` in §2.4 to dynamically report the count and source path for available samples in global mode, and reference documentation/URL in drop-in mode.
  5. **Pruned blast radius**: Removed `lib/cmd_init.sh` from Target Files since sample sync logic is eliminated, updating Phase 1, Phase 4, and test requirements accordingly.
* **2026-09-22 (amendment 6):** **Red team re-review refinements prior to freeze** —
  1. **Fixed parameter expansion syntax**: Replaced broken `${AAPP_BASE#$HOME/~/}` with POSIX/Bash prefix replacement `${AAPP_BASE/#$HOME/\~}` across §2.4 sample location reporting.
  2. **Clarified `cmd_plugins_status()` scope**: Explicitly specified that `cmd_plugins_status()` is a complete function replacement superseding `lib/cmd_hook.sh:144-174`, avoiding incremental patch confusion.
  3. **Sequencing clearance**: Verified that prerequisite Plan P-22 is ✅ Done and archived to `.plans/done/`, satisfying the sequencing gate with zero file-collision risk. Confirmed `plan_resolver.sh:299` resolves only against `.agents/skills/aapp-planid`, establishing that renaming `examples/plugins/aapp-planid/run` to `run.sample` carries zero risk to runtime allocation.



