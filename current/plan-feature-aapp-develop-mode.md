# 🗺️ Plan: Developer Mode Verb (`aapp develop`) & Live Symlink Engine

* **Created:** 2026-09-10 | **Last Refined:** 2026-09-10
* **Target Issue / Milestone:** Feature: Developer Mode (`aapp develop`)
* **Status:** 🟢 Ready for Execution

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Every commit you make must include your co-author trailer (e.g., `Co-authored-by: Antigravity <antigravity@google.com>` or `Claude <noreply@anthropic.com>`).
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.

---

## 1. Context & Architectural Goal

AAPP currently supports two distribution flows:
1. **Drop-in Project Setup**: Cloned directly into an existing repository, initialized via `./aapp init`, and consumed (`rm -rf`).
2. **Global Copy Installation (`aapp install`)**: Copies binary and templates into `~/.local/bin/aapp` and `~/.local/share/aapp-kit`.

For core developers and contributors developing on AAPP itself (`aapp-develop-kit`):
- `aapp install` copies static snapshot files, meaning edits in `lib/` or `templates/` require constant manual re-installation to test globally.
- We need an **editable / live development mode** (analogous to `npm link` or `pip install -e .`) via the first-class verb `aapp develop`.

`aapp develop` establishes symbolic links between the active git clone and the global discovery paths (`~/.local/share/aapp-kit` and `~/.local/bin/aapp`), making all local source changes instantly live across the entire machine without copying or self-consumption.

---

## 2. Technical Blueprint

### 2.1 Command Dispatcher (`aapp`)
* Add `develop` command to `aapp` dispatcher:
  ```bash
  develop)
      source "$AAPP_LIB/cmd_develop.sh" "$@"
      ;;
  ```

### 2.2 Developer Mode Engine (`lib/cmd_develop.sh`)
* Implement `lib/cmd_develop.sh`:
  1. Validate that `$AAPP_SCRIPT_DIR` contains valid AAPP source code (`has_kit_signature`).
  2. Verify that `$AAPP_SCRIPT_DIR` is a git repository or development workspace named `aapp-develop-kit` (or `agent-planning-kit`).
  3. Ensure `$HOME/.local/bin` and `$HOME/.local/share` directories exist.
  4. Replace existing files/directories at `$HOME/.local/share/aapp-kit` with a symlink pointing to `$AAPP_SCRIPT_DIR`:
     ```bash
     rm -rf "$SHARE_DIR"
     ln -s "$AAPP_SCRIPT_DIR" "$SHARE_DIR"
     ```
  5. Replace `$HOME/.local/bin/aapp` with a symlink pointing to `$AAPP_SCRIPT_DIR/aapp`:
     ```bash
     rm -f "$BIN_DIR/aapp"
     ln -s "$AAPP_SCRIPT_DIR/aapp" "$BIN_DIR/aapp"
     ```
  6. Ensure executables have correct permissions (`chmod +x "$AAPP_SCRIPT_DIR/aapp"`).
  7. Print structured confirmation of live development mode with symlink targets.

### 2.3 Help & Documentation Catalog
* In `lib/cmd_help.sh`:
  - Add `develop` to the command reference list.
* In `README.md` and `MANUAL.md`:
  - Document the developer setup flow:
    ```bash
    git clone https://github.com/aapp-protocol/aapp-kit.git aapp-develop-kit
    cd aapp-develop-kit
    ./aapp develop
    ```

---

## 🔨 3. Implementation Steps & Execution Checklist
*Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Command Implementation & Dispatcher
- [ ] 1.1 Create `lib/cmd_develop.sh` with symlink linking logic and diagnostic reporting.
- [ ] 1.2 Wire `develop` verb into `aapp` dispatcher.
- [ ] 1.3 Add `develop` command to `lib/cmd_help.sh`.

### Phase 2: Documentation & Developer Guides
- [ ] 2.1 Document `aapp develop` workflow in `README.md`.
- [ ] 2.2 Document `aapp develop` in `MANUAL.md`.

### Phase 3: Automated Test Verification
- [ ] 3.1 Add regression tests in `tests/install_test.sh` verifying symlink creation, live edits propagation, and non-consumption.
- [ ] 3.2 Run full regression test suites (`install_test.sh`, `pre-commit_test.sh`, `write-guard_test.sh`).

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `lib/cmd_develop.sh` -> Symlink linking engine for developer mode.
- [ ] `aapp` -> Wire `develop` verb in command dispatcher.
- [ ] `lib/cmd_help.sh` -> Add `develop` command description.
- [ ] `README.md` -> Document contributor / developer setup workflow.
- [ ] `MANUAL.md` -> Add `aapp develop` reference documentation.
- [ ] `tests/install_test.sh` -> Automated tests for `aapp develop` symlinks and live edit behavior.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Guard logic is stable.
- [ ] `templates/aapp-pre-commit` -> Pre-commit hook is stable.
- [ ] `LICENSE` -> License file.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified and backward-compatible)*

---

## 📦 6. Change Log & Refinement History
* **2026-09-10:** Initial blueprint scaffolded for `aapp develop` feature.
