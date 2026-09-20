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

This blueprint was decoupled from Plan P-22 on developer direction to maintain strict separation of concerns: P-22 owns runtime Plan ID allocation (`#69`), while P-24 owns distribution asset preservation, `.sample` conventions, and drop-in mode asset handling.

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
| **Action Plugin Showcase** | `examples/plugins/hello-tool/run.sample` | Completely ignored by dynamic CLI dispatch and plugin resolution. | Developer/agent copies directory and renames entrypoint: `cp -r .agents/skills/hello-tool.sample .agents/skills/hello-tool && mv .agents/skills/hello-tool/run.sample .agents/skills/hello-tool/run && chmod +x .agents/skills/hello-tool/run`. |
| **Team ID Provider Mock** | `examples/plugins/aapp-planid/run.sample` | Completely ignored by `allocate_plan_id`; resolver falls back to local git config. | Developer copies directory, renames entrypoint to `run`, adapts to network API, and marks executable: `cp -r .agents/skills/aapp-planid.sample .agents/skills/aapp-planid && mv .agents/skills/aapp-planid/run.sample .agents/skills/aapp-planid/run && chmod +x .agents/skills/aapp-planid/run`. |
| **Quality Gate Hook** | `examples/hooks/fallback-ratchet.sh.sample` | Ignored by `hook_dispatcher.sh` (requires explicit entry in `registry.tsv`). | Developer copies script without `.sample`, marks executable, registers with `aapp hook-hash`, and records hash in `registry.tsv`. |
| **Lifecycle Observer Hook** | `examples/hooks/on-done-sync.sh.sample` | Ignored by `hook_dispatcher.sh`. | Developer copies script without `.sample`, marks executable, and registers with `aapp hook-hash`. |
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

#### 1. Hardcoded Standard Extension Points Catalog (`cmd_plugins_status`)
`cmd_plugins_status()` in `lib/cmd_hook.sh` defines the known standard extension points and checks their status dynamically:

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
    elif [ -d "$skills_dir/aapp-planid.sample" ]; then
        local counter="$(git config --get aapp.planId 2>/dev/null || echo 1)"
        printf "    • %-16s [Team Plan ID Authority] -> .agents/skills/aapp-planid.sample/ (SAMPLE AVAILABLE)\n" "aapp-planid"
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
    elif [ -d "$skills_dir/hello-tool.sample" ]; then
        printf "    • %-16s [Custom CLI Showcase]   -> .agents/skills/hello-tool.sample/ (SAMPLE AVAILABLE)\n" "hello-tool"
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
}
```

#### 2. Lifecycle Hooks Audit (`aapp hooks`)
In `cmd_hooks_status()` (`lib/cmd_hook.sh`), if a registered handler path ends in `.sample`, the audit reports a distinct badge `⚠️  INERT SAMPLE` and outputs an advisory notice indicating the sample must be copied to an active script before triggering:
```bash
if [[ "$hp" == *.sample ]]; then
    status_badge="⚠️  INERT SAMPLE"
fi
```

### 2.5 Drop-in Mode Installation with `.sample` Suffix (`lib/cmd_init.sh`)

In drop-in mode (`./aapp-kit/aapp init`), an adopting repository consumes the transient kit directory upon successful initialization (Phase 7, `lib/cmd_init.sh:715-731`). Without asset extraction, deleting `./aapp-kit` destroys all reference examples.

Rather than polluting the adopter's project root with a top-level `examples/` directory, drop-in mode installs samples **directly into the `.agents` worktree** using the `.sample` suffix convention before self-consumption:

#### 1. Destination Layout in the Adopter Repository
- **Action Plugin Samples**:
  Copied to `.agents/skills/<name>.sample/` (e.g. `.agents/skills/hello-tool.sample/`, `.agents/skills/aapp-planid.sample/`).
  Inside each directory, entrypoints carry the `.sample` suffix (`run.sample`).
- **Lifecycle Hook Samples**:
  Copied to `.agents/skills/aapp-hooks/examples/` (e.g. `fallback-ratchet.sh.sample`, `on-done-sync.sh.sample`, `registry.tsv.sample`).

#### 2. Execution Logic in `lib/cmd_init.sh` (`sync_samples`)
A dedicated helper `sync_samples()` runs in Phase 5 right alongside `sync_skills()`:

```bash
sync_samples() {
    local examples_dir="$AAPP_SCRIPT_DIR/examples"
    [ ! -d "$examples_dir" ] && return 0

    [ ! -d .agents/skills ] && mkdir -p .agents/skills

    # 1. Action Plugin Samples -> .agents/skills/<name>.sample/
    if [ -d "$examples_dir/plugins" ]; then
        for pdir in "$examples_dir/plugins"/*; do
            [ ! -d "$pdir" ] && continue
            local pname
            pname="$(basename "$pdir")"
            local dest=".agents/skills/${pname}.sample"
            # Overwrite sample directory on init/upgrade so reference templates refresh cleanly
            rm -rf "$dest"
            mkdir -p "$dest"
            cp -R "$pdir/." "$dest/"
            # Ensure entrypoint carries .sample suffix
            if [ -f "$dest/run" ] && [ ! -f "$dest/run.sample" ]; then
                mv "$dest/run" "$dest/run.sample"
            fi
        done
    fi

    # 2. Lifecycle Hook Samples -> .agents/skills/aapp-hooks/examples/
    if [ -d "$examples_dir/hooks" ]; then
        mkdir -p .agents/skills/aapp-hooks/examples
        for hfile in "$examples_dir/hooks"/*; do
            [ ! -f "$hfile" ] && continue
            local hname
            hname="$(basename "$hfile")"
            local dest_file=".agents/skills/aapp-hooks/examples/$hname"
            case "$dest_file" in
                *.sample) ;;
                *) dest_file="${dest_file}.sample" ;;
            esac
            cp "$hfile" "$dest_file"
        done
    fi
}
```

#### 3. Automatic Tracking & Safe Consumption
- `sync_samples()` executes immediately before lines 682-690 (`git -C .agents add . && git commit`).
- The sample assets are automatically committed into the isolated `.agents` orphan branch.
- Phase 7 then executes `rm -rf "$AAPP_SCRIPT_DIR"`. The kit self-consumes safely, leaving the adopter repo clean, portable, and equipped with inert reference samples.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

> **Sequencing Dependency Note:** Implementation follows completion of Plan P-22 (`P22-config-backed-plan-id-allocation.md`), inheriting the relocation of `resolve_plugin_entrypoint` to `lib/hook_dispatcher.sh` and the baseline `examples/plugins/aapp-planid/` directory.

### Phase 1: Foundation & Test Setup
- [ ] Task 1.1: Add assertions in `tests/install_test.sh` verifying that `examples/` is copied to `$SHARE_DIR/examples/` during `aapp install`, and that `${SHARE_DIR:?}/examples` is cleaned before copying.
- [ ] Task 1.2: Add unit tests in `tests/hooks_test.sh` asserting that `resolve_plugin_entrypoint` ignores `run.sample` and `*.sample` files even if marked executable.
- [ ] Task 1.3: Add test cases in `tests/install_test.sh` (Section 2) asserting drop-in initialization copies `.sample` assets into `.agents/skills/` before kit consumption, and refreshes them on repeat `aapp init`.

### Phase 2: Engine Guards & Plugins Catalog Implementation
- [ ] Task 2.1: Add the `.sample` exclusion filter to `resolve_plugin_entrypoint` in `lib/hook_dispatcher.sh`.
- [ ] Task 2.2: Update the dynamic subcommand fallthrough in `aapp` to block `*.sample` and reuse `resolve_plugin_entrypoint` so unrenamed `run.sample` files cannot be executed via `aapp <cmd>`.
- [ ] Task 2.3: Update `cmd_plugins_status()` in `lib/cmd_hook.sh` with the hardcoded standard extension points catalog (`aapp-planid`, `hello-tool`), accurately reporting Active, Sample Available, Configured But Not Executable, and Fallback status, while skipping `hello-tool` in the custom plugins loop.
- [ ] Task 2.4: Update `cmd_hooks_status()` in `lib/cmd_hook.sh` to audit registered hooks and flag `*.sample` paths with `⚠️  INERT SAMPLE`.

### Phase 3: Global Installation & Packaging
- [ ] Task 3.1: Update `lib/cmd_install.sh` to clean `${SHARE_DIR:?}/examples` on line 84 and copy `examples/` to `$SHARE_DIR/examples/`.
- [ ] Task 3.2: Strictly rename shipped source examples in `examples/` to use in-place `.sample` suffix (`examples/plugins/hello-tool/run.sample`, `examples/plugins/aapp-planid/run.sample`, `examples/hooks/fallback-ratchet.sh.sample`, `examples/hooks/on-done-sync.sh.sample`), and author `examples/hooks/registry.tsv.sample`.

### Phase 4: Drop-In Initialization Seeding
- [ ] Task 4.1: Implement `sync_samples()` in `lib/cmd_init.sh` to seed and refresh `.sample` action plugins and hooks into `.agents/skills/` during drop-in mode.
- [ ] Task 4.2: Verify `is_safe_to_consume_kit_dir` cleanly consumes `./aapp-kit` after `sync_samples()` executes.

### Phase 5: Verification & Documentation
- [ ] Task 5.1: Run all test suites (`tests/install_test.sh`, `tests/hooks_test.sh`); verify zero regressions.
- [ ] Task 5.2: Document the `.sample` convention, directory copy activation workflow, and drop-in sample seeding in `MANUAL.md` and `README.md`.
- [ ] Task 5.3: Update `CHANGELOG.md` and run syntax checks before committing.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
- [ ] `lib/cmd_install.sh` -> Clean and copy `examples/` to `$SHARE_DIR/examples/` during `aapp install`.
- [ ] `lib/cmd_init.sh` -> Implement `sync_samples()` to seed and refresh `.sample` assets into `.agents/skills/` during drop-in mode.
- [ ] `tests/install_test.sh` -> Assert `examples/` copied to `$SHARE_DIR` on install, and drop-in initialization seeds `.sample` assets.
- [ ] `lib/hook_dispatcher.sh` -> Filter `*.sample` in `resolve_plugin_entrypoint`.
- [ ] `lib/cmd_hook.sh` -> Filter `*.sample`, hardcode standard plugin catalog, and audit sample hooks with `⚠️  INERT SAMPLE`.
- [ ] `aapp` -> Prevent `aapp <cmd>` fallthrough from executing `.sample` files or directories by delegating to `resolve_plugin_entrypoint`.
- [ ] `tests/hooks_test.sh` -> Test `.sample` ignore behavior and `aapp plugins` catalog output.
- [ ] `examples/plugins/hello-tool/run.sample` -> Renamed sample action plugin.
- [ ] `examples/plugins/aapp-planid/run.sample` -> Shipped mock planid provider.
- [ ] `examples/hooks/fallback-ratchet.sh.sample` -> Renamed sample hook.
- [ ] `examples/hooks/on-done-sync.sh.sample` -> Renamed sample hook.
- [ ] `examples/hooks/registry.tsv.sample` -> Reference 5-column TSV schema template.
- [ ] `MANUAL.md` -> Document sample convention, activation workflow, and installation assets.
- [ ] `README.md` -> Document reference samples.
- [ ] `CHANGELOG.md` -> Record under Unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/plan_resolver.sh` -> Plan ID resolution is owned exclusively by P-22.
- [ ] `lib/cmd_init.sh:452-476` -> Counter seeding (`aapp.lastPlanId`) owned exclusively by P-22.
- [ ] `lib/planning_health.sh` -> Integrity backstop is out of scope.
- [ ] `.claude/skills/aapp-*` -> Guard Section 2 self-protected.
- [ ] `.agents/skills/aapp-*` -> Guard Section 2 self-protected.

---

## ❓ 5. Open Questions (Optional / Gate)

* [x] **Question 1 — Drop-In Mode Asset Handling. → RESOLVED (developer, 2026-09-20): direct `.sample` seeding into `.agents/skills/`.** See §2.5. Drop-in mode copies mock plugins to `.agents/skills/<name>.sample/` and mock hooks to `.agents/skills/aapp-hooks/examples/*.sh.sample`, staging and committing them to the `.agents` worktree before Phase 7 kit consumption. Does not pollute repo root.
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



