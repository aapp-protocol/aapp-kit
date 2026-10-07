# 🗺️ Plan P-59: Kit Release Lifecycle Hook & Version Synchronizer
* **Created:** 2026-10-07 | **Last Refined:** 2026-10-07
* **Target Issue / Milestone:** #58
* **Plan ID:** P-59
* **Changelog:** Added: Kit release lifecycle hook and template version synchronizer
* **Commit Mode:** atomic
* **Changelog Mode:** plan
* **Status:** 🟣 Under Review
* **Base:** none
* **Commits:** none
<!-- AAPP-PROTOCOL:START v1.0.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]`. Never stage or commit the plan file yourself.
> 5. **Mid-Execution Bugs**: Log non-blocking bugs in `.plans/ISSUES.md`. For blocking issues, use `aapp issue hotfix`.
> 6. **User Documentation Sync**: Update `MANUAL.md` and `README.md` with kit release hook conventions.
> 7. **Architecture & Codemap Sync**: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md`.
> 8. **Fail-Closed Invariant**: Silent fallbacks are strictly prohibited. Every check must fail closed.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal

While Plan P-38 establishes the universal, language-agnostic release engine (`aapp release`) and delegates version bumping to an `on-release` action delegate via Dual Delivery (`stdin` JSON + POSIX env), the core engine contains zero project-specific file mutation logic. 

In the `agent-planning-kit` repository:
1. **Unstamped Version Drift (Issue #58)**: `AAPP_VERSION="1.0.0"` in `aapp` was hardcoded during install/upgrade implementation without release tag automation. Upgraded downstream repositories copy templates still carrying `<!-- AAPP-PROTOCOL:START v1.0.0 -->`.
2. **Dogfooding Lifecycle Hooks**: The AAPP Kit should dogfood its own extension architecture by implementing a dedicated `on-release` hook (`scripts/kit-on-release.sh`) rather than hardcoding kit-specific `sed` commands into `lib/cmd_release.sh`.
3. **Template Version Synchronization**: When a release occurs, the kit must synchronously update `AAPP_VERSION` in the executable CLI and advance protocol delimiter blocks across all starter templates (`templates/AGENTS.md`, `templates/plan-template.md`, `templates/pickup.md`, `templates/release_checklist.md`).

### Architectural Goal
Provide the official repository-level release personalisation hook for `agent-planning-kit`:
- Implement `scripts/kit-on-release.sh` as an `on-release` action delegate responding to `aapp release`.
- Extract raw version (`AAPP_RAW_VERSION`, e.g. `1.1.0`) and release tag (`AAPP_RELEASE_VERSION`, e.g. `v1.1.0`).
- Update `AAPP_VERSION="<rawVersion>"` in `aapp`.
- Update `<!-- AAPP-PROTOCOL:START v<rawVersion> -->` across all managed template files in `templates/`.
- Validate that all target files were updated cleanly and exit 0 (or exit 1 on any failure to roll back the release transaction).
- Provide automated regression testing via `tests/kit_release_hook_test.sh`.

---

## 2. Technical Blueprint

### 2.1 Hook Interface & Execution Flow (`scripts/kit-on-release.sh`)

When `aapp release <version>` executes, Step 3 invokes `on-release` via `dispatch_lifecycle_hook`:

```text
                  [ aapp release v1.2.0 ]
                            │
                            ▼ (Step 3: on-release)
              [ scripts/kit-on-release.sh ]
              (Env: AAPP_RAW_VERSION="1.2.0")
              (STDIN: {"event":"on-release","version":"v1.2.0",...})
                            │
            ┌───────────────┴───────────────┐
            ▼                               ▼
    [ Update aapp CLI ]           [ Update templates/* ]
    AAPP_VERSION="1.2.0"          <!-- AAPP-PROTOCOL:START v1.2.0 -->
            │                               │
            └───────────────┬───────────────┘
                            ▼
                  [ Verify Changes ]
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
           Success                      Error
         (exit code 0)              (exit code 1)
              │                           │
              ▼                           ▼
      Proceed with Release       🛑 Rollback & Abort
```

### 2.2 Payload Consumption
The hook consumes the payload from Dual Delivery:
- **Primary**: Environment variable `$AAPP_RAW_VERSION` (fallback: parsed from STDIN JSON `.rawVersion` via awk/grep without requiring `jq`).
- **Normalized Tag**: `$AAPP_RELEASE_VERSION` (fallback: `v$AAPP_RAW_VERSION`).

### 2.3 File Mutation Operations
1. **CLI Executable (`aapp`)**:
   ```bash
   sed -i -E "s/^AAPP_VERSION=\".*\"/AAPP_VERSION=\"$RAW_VERSION\"/" "$REPO_ROOT/aapp"
   ```
2. **Template Protocol Delimiters (`templates/`)**:
   Scan `templates/` for files matching `<!-- AAPP-PROTOCOL:START v.* -->`:
   - `templates/AGENTS.md`
   - `templates/plan-template.md`
   - `templates/pickup.md`
   - `templates/release_checklist.md`
   Replace version token:
   ```bash
   sed -i -E "s/<!-- AAPP-PROTOCOL:START v[0-9]+\.[0-9]+(\.[0-9]+)?.* -->/<!-- AAPP-PROTOCOL:START v$RAW_VERSION -->/" "$FILE"
   ```
3. **Verification**:
   Assert that `grep -q "AAPP_VERSION=\"$RAW_VERSION\"" "$REPO_ROOT/aapp"` succeeds and that modified templates contain the new protocol version string.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`: The hook operates strictly via the standardized `on-release` contract defined in P-38 and P-23.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Script Authoring & Test Suite
- [ ] Task 1.1: Author `scripts/kit-on-release.sh` with robust input validation, dual-delivery payload parsing, atomic file updates, and fail-closed exit codes.
- [ ] Task 1.2: Ensure `scripts/kit-on-release.sh` is executable (`chmod +x`).
- [ ] Task 1.3: Author `tests/kit_release_hook_test.sh` simulating `on-release` dispatch in an isolated copy of the kit repo, verifying version updates in `aapp` and `templates/`.

### Phase 2: Hook Registration & Verification
- [ ] Task 2.1: Register `scripts/kit-on-release.sh` in `.agents/skills/aapp-hooks/registry.tsv` (or project config `git config aapp.hook.on-release scripts/kit-on-release.sh`) with `mode=gate` and `timeout=30`.
- [ ] Task 2.2: Test hook execution via `./aapp hook-test on-release` (or mock payload) verifying zero errors and clean output.

### Phase 3: Documentation & Issue Resolution
- [ ] Task 3.1: Document the kit self-release hook architecture in `MANUAL.md` and `.agents/CODEMAP.md`.
- [ ] Task 3.2: Verify resolution of Issue #58.
- [ ] Task 3.3: Update `CHANGELOG.md` and run regression test suite (`./aapp test strict quiet`).

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `scripts/kit-on-release.sh` -> Concrete on-release lifecycle hook script for agent-planning-kit
- [ ] `tests/kit_release_hook_test.sh` -> Regression tests for kit release hook and version synchronization
- [ ] `MANUAL.md` -> Document kit release hook in extension recipes
- [ ] `README.md` -> Note self-release hook dogfooding
- [ ] `.agents/CODEMAP.md` -> Document scripts/kit-on-release.sh contracts
- [ ] `CHANGELOG.md` -> Record kit release hook addition

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Guard Section 2 self-protection.
- [ ] `lib/cmd_release.sh` -> Core universal release engine remains language-agnostic (governed by P-38).
- [ ] `.agents/skills/aapp-*` -> Engine skills remain untouched.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-07:** Drafted blueprint promoting Issue #58 into a dedicated personalisation plan for `agent-planning-kit`'s own `on-release` hook and template protocol synchronizer.
