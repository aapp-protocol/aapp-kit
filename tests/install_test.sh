#!/usr/bin/env bash
# Regression harness for unified aapp CLI workflow (v1.0.0)
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

report() {
  local name="$1" expect="$2" got="$3" details="${4:-}"
  if [ "$got" = "$expect" ]; then
    printf "  \033[32m✔\033[0m %-65s %s\n" "$name" "$got"; PASS=$((PASS+1))
  else
    printf "  \033[31m✘\033[0m %-65s want %s got %s\n" "$name" "$expect" "$got"; FAIL=$((FAIL+1))
    [ -n "$details" ] && echo "$details" | sed 's/^/       /'
  fi
}

make_kit_clone() {
  local target_dir="$1"
  mkdir -p "$target_dir"
  cp "$KIT/aapp" "$target_dir/"
  chmod +x "$target_dir/aapp"
  cp -r "$KIT/lib" "$KIT/templates" "$target_dir/"
  [ -d "$KIT/tests" ] && cp -r "$KIT/tests" "$target_dir/"
  [ -d "$KIT/examples" ] && cp -r "$KIT/examples" "$target_dir/"
  (
    cd "$target_dir"
    git init -q .
    setup_test_git_identity "$target_dir"
    git add . >/dev/null 2>&1
    git commit -qm "kit clone" >/dev/null 2>&1 || true
  )
}

make_dummy_project() {
  local proj_dir="$1"
  mkdir -p "$proj_dir"
  (
    cd "$proj_dir"
    git init -q .
    setup_test_git_identity "$proj_dir"
    echo "print('hello')" > main.py
    git add main.py
    git commit -qm "initial commit"
  )
}

echo "== 1. Version & Help Verbs =="

# Test 1: aapp version / -v / --version
out_v=$("$KIT/aapp" version)
out_short=$("$KIT/aapp" -v)
out_long=$("$KIT/aapp" --version)
if [ "$out_v" = "aapp version 1.0.0" ] && [ "$out_short" = "aapp version 1.0.0" ] && [ "$out_long" = "aapp version 1.0.0" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp version / -v / --version outputs version 1.0.0" "PASS" "$got" "$out_v"

# Test 2: aapp help / -h / --help
out_help=$("$KIT/aapp" help)
if echo "$out_help" | grep -q "Usage: aapp <command>" && echo "$out_help" | grep -q "init" && echo "$out_help" | grep -q "upgrade"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp help displays full command catalog" "PASS" "$got" "$out_help"

echo "== 2. Canonical Self-Init & Uninstalled Clone Confinement =="

TEST_HOME="$HOME"

# Test 3: Canonical self-init: kit repository initializes itself
KIT_SELF="$R/kit_self"; make_kit_clone "$KIT_SELF"
(
  cd "$KIT_SELF"
  ./aapp init >/dev/null 2>&1
)
rc=$?
if [ $rc -eq 0 ] && [ -d "$KIT_SELF/.plans" ] && [ -d "$KIT_SELF/.agents" ] && [ -d "$KIT_SELF/.githooks" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "canonical self-init: uninstalled kit repo initializes itself" "PASS" "$got"

# Test 4: Uninstalled clone running init against external project fails fast
PROJ_EXT="$R/t_ext_proj"; make_dummy_project "$PROJ_EXT"
KIT_EXT="$R/t_ext_kit"; make_kit_clone "$KIT_EXT"
out_fast_fail=$(
  cd "$PROJ_EXT"
  "$KIT_EXT/aapp" init 2>&1 || true
)
if echo "$out_fast_fail" | grep -q "AAPP must be installed globally before initializing projects"; then
  got="PASS"
else
  got="FAIL"
fi
report "uninstalled clone running init against external project fails fast" "PASS" "$got" "$out_fast_fail"

# Test 5: aapp init outside git repository fails closed at front door
NON_GIT="$R/non_git_dir"; mkdir -p "$NON_GIT"
out_non_git=$(
  cd "$NON_GIT"
  aapp init 2>&1 || true
)
if echo "$out_non_git" | grep -q "must be run inside a Git repository"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp init outside git repository fails closed at front door" "PASS" "$got" "$out_non_git"

echo "== 3. Delimited Block Sync, Adoption, and Upgrades =="

# Test 7: Adoption: existing .agents/AGENTS.md without markers gets block appended
PROJ="$R/t7_proj"; make_dummy_project "$PROJ"
(
  cd "$PROJ"
  git checkout --orphan agents -q
  git rm -rf . -q 2>/dev/null || true
  echo "# Custom Project Rules (No Markers)" > AGENTS.md
  echo "rule 1: always write tests" >> AGENTS.md
  git add AGENTS.md
  git commit -qm "custom agents branch"
  git checkout main -q
)
(cd "$PROJ" && aapp init >/dev/null 2>&1)
if grep -q "<!-- AAPP-PROTOCOL:START v1.0.0 -->" "$PROJ/.agents/AGENTS.md" && \
   grep -q "# Custom Project Rules (No Markers)" "$PROJ/.agents/AGENTS.md"; then
  got="PASS"
else
  got="FAIL"
fi
report "adoption: unmanaged .agents/AGENTS.md gets protocol block appended" "PASS" "$got"

# Test 8: Protocol Upgrade: existing block updated, custom rules outside block preserved
PROJ="$R/t8_proj"; make_dummy_project "$PROJ"
(
  cd "$PROJ"
  git checkout --orphan agents -q
  git rm -rf . -q 2>/dev/null || true
  cat > AGENTS.md <<'EOF'
# Project Custom Rules
Custom rule: always use snake_case for functions.

<!-- AAPP-PROTOCOL:START v0.9.0 -->
Old protocol block v0.9.0 content that should be replaced.
<!-- AAPP-PROTOCOL:END -->

# Post-Protocol Custom Rules
Custom rule: enforce 80 chars max line length.
EOF
  git add AGENTS.md
  git commit -qm "v0.9.0 agents branch"
  git checkout main -q
)
(cd "$PROJ" && aapp init >/dev/null 2>&1)
agents_content=$(cat "$PROJ/.agents/AGENTS.md")
if echo "$agents_content" | grep -q "<!-- AAPP-PROTOCOL:START v1.0.0 -->" && \
   echo "$agents_content" | grep -q "Custom rule: always use snake_case for functions." && \
   echo "$agents_content" | grep -q "Custom rule: enforce 80 chars max line length." && \
   ! echo "$agents_content" | grep -q "Old protocol block v0.9.0 content"; then
  got="PASS"
else
  got="FAIL"
fi
report "upgrade: protocol block upgraded in-place preserving surrounding rules" "PASS" "$got"

# Test 9: Migration: project-root AGENTS.md migrated into .agents/ worktree
PROJ="$R/t9_proj"; make_dummy_project "$PROJ"
echo "# Legacy Root AGENTS File" > "$PROJ/AGENTS.md"
(cd "$PROJ" && aapp init >/dev/null 2>&1)
if [ ! -f "$PROJ/AGENTS.md" ] && \
   [ -f "$PROJ/.agents/AGENTS.md" ] && \
   grep -q "# Legacy Root AGENTS File" "$PROJ/.agents/AGENTS.md" && \
   grep -q "<!-- AAPP-PROTOCOL:START v1.0.0 -->" "$PROJ/.agents/AGENTS.md"; then
  got="PASS"
else
  got="FAIL"
fi
report "migration: legacy flat AGENTS.md migrated into .agents/ worktree" "PASS" "$got"

# Test 10: Existing project root anchors (CODEMAP, ARCHITECTURE, etc.) preserved / migrated
PROJ="$R/t10_proj"; make_dummy_project "$PROJ"
echo "# User Custom CODEMAP" > "$PROJ/CODEMAP.md"
echo "# User Custom ARCHITECTURE" > "$PROJ/ARCHITECTURE.md"
(cd "$PROJ" && aapp init >/dev/null 2>&1)
if [ "$(cat "$PROJ/.agents/CODEMAP.md")" = "# User Custom CODEMAP" ] && \
   [ "$(cat "$PROJ/ARCHITECTURE.md")" = "# User Custom ARCHITECTURE" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "project root anchors (CODEMAP, ARCHITECTURE) preserved/migrated" "PASS" "$got"

echo "== 4. Core Infrastructure & Claude Settings =="

# Test 11: Namespaced hook sync: aapp-pre-commit updated, user custom pre-commit preserved
PROJ="$R/t11_proj"; make_dummy_project "$PROJ"
(
  cd "$PROJ"
  git checkout --orphan githooks -q
  git rm -rf . -q 2>/dev/null || true
  cat > pre-commit <<'EOF'
#!/usr/bin/env bash
# Custom Project Perl / Linter Hook
perl -e 'print "custom check\n"' || exit 1
EOF
  echo "# old guard" > blast-radius-guard
  git add .
  git commit -qm "custom hooks branch"
  git checkout main -q
)
(cd "$PROJ" && aapp init >/dev/null 2>&1)
if [ -x "$PROJ/.githooks/aapp-pre-commit" ] && \
   [ -x "$PROJ/.githooks/blast-radius-guard" ] && \
   [ -x "$PROJ/.githooks/pre-commit" ] && \
   grep -q "custom check" "$PROJ/.githooks/pre-commit" && \
   grep -q "aapp-pre-commit" "$PROJ/.githooks/pre-commit"; then
  got="PASS"
else
  got="FAIL"
fi
report "namespaced hook sync: aapp-pre-commit updated, custom pre-commit preserved" "PASS" "$got"

# P-37: aapp init installs the shared library beside the hook engines as a real file
if [ -f "$PROJ/.githooks/aapp-lib.sh" ] && [ ! -L "$PROJ/.githooks/aapp-lib.sh" ] && \
   cmp -s "$PROJ/.githooks/aapp-lib.sh" "$XDG_DATA_HOME/aapp-kit/lib/aapp-lib.sh"; then
  got="PASS"
else
  got="FAIL"
fi
report "test_init_installs_library_as_real_file" "PASS" "$got"

# P-37: aapp init fails loudly when the installed kit has no shared library
PROJ_LIB="$R/t11b_proj"; make_dummy_project "$PROJ_LIB"
LIB_SRC="$XDG_DATA_HOME/aapp-kit/lib/aapp-lib.sh"
LIB_AWAY="$R/aapp-lib.sh.away"
out_lib=""; rc_lib=0
if [ -f "$LIB_SRC" ]; then
  mv "$LIB_SRC" "$LIB_AWAY"
  out_lib=$(cd "$PROJ_LIB" && aapp init 2>&1) || rc_lib=$?
  mv "$LIB_AWAY" "$LIB_SRC"
else
  out_lib=$(cd "$PROJ_LIB" && aapp init 2>&1) || rc_lib=$?
fi
if [ "$rc_lib" -ne 0 ] && echo "$out_lib" | grep -q "aapp-lib.sh" && echo "$out_lib" | grep -q "Detected OS"; then
  got="PASS"
else
  got="FAIL"
fi
report "test_init_fails_loudly_when_lib_missing" "PASS" "$got" "rc=$rc_lib"

# Test 12: Fresh install writes .claude/settings.json
PROJ="$R/t12_proj"; make_dummy_project "$PROJ"
(cd "$PROJ" && aapp init >/dev/null 2>&1)
if [ -f "$PROJ/.claude/settings.json" ] && grep -q "blast-radius-guard" "$PROJ/.claude/settings.json"; then
  got="PASS"
else
  got="FAIL"
fi
report "fresh install writes .claude/settings.json with blast-radius-guard" "PASS" "$got"

# Test 13: Existing .claude/settings.json merged non-destructively
PROJ="$R/t13_proj"; make_dummy_project "$PROJ"
mkdir -p "$PROJ/.claude"
cat > "$PROJ/.claude/settings.json" <<'JSON'
{
  "userCustomSetting": true,
  "hooks": {
    "PostToolUse": [
      {
        "matcher": ".*",
        "hooks": [{"type": "command", "command": "echo done"}]
      }
    ]
  }
}
JSON
(cd "$PROJ" && aapp init >/dev/null 2>&1)
if grep -q '"userCustomSetting": true' "$PROJ/.claude/settings.json" && \
   grep -q "blast-radius-guard" "$PROJ/.claude/settings.json" && \
   grep -q "PostToolUse" "$PROJ/.claude/settings.json"; then
  got="PASS"
else
  got="FAIL"
fi
report "non-destructive merge: preserves existing .claude/settings.json keys" "PASS" "$got"

# Test 14: Idempotent .claude/settings.json (no duplicated hooks)
(cd "$PROJ" && aapp init >/dev/null 2>&1 || true)
count_guard=$(grep -o "blast-radius-guard" "$PROJ/.claude/settings.json" | wc -l)
if [ "$count_guard" -eq 1 ]; then
  got="PASS"
else
  got="FAIL"
fi
report "idempotent .claude/settings.json merge: no duplicate entries" "PASS" "$got"

echo "== 5. Git Hooks & Hook Manager Interoperability =="

# Test 15: core.hooksPath unset -> set to .githooks, no warning
PROJ="$R/t15_proj"; make_dummy_project "$PROJ"
out_t15=$(cd "$PROJ" && aapp init 2>&1)
hooks_path=$(cd "$PROJ" && git config --get core.hooksPath || true)
if [ "$hooks_path" = ".githooks" ] && ! echo "$out_t15" | grep -q "existing hook configuration was detected"; then
  got="PASS"
else
  got="FAIL"
fi
report "core.hooksPath unset -> set to .githooks with no warning" "PASS" "$got"

# Test 16: core.hooksPath already .githooks -> idempotent re-run, no warning
PROJ="$R/t16_proj"; make_dummy_project "$PROJ"
(cd "$PROJ" && git config core.hooksPath .githooks)
out_t16=$(cd "$PROJ" && aapp init 2>&1)
hooks_path=$(cd "$PROJ" && git config --get core.hooksPath || true)
if [ "$hooks_path" = ".githooks" ] && ! echo "$out_t16" | grep -q "existing hook configuration was detected"; then
  got="PASS"
else
  got="FAIL"
fi
report "core.hooksPath already .githooks -> unchanged, no warning" "PASS" "$got"

# Test 17: core.hooksPath=.husky -> hooks installed, config untouched, wiring printed
PROJ="$R/t17_proj"; make_dummy_project "$PROJ"
(cd "$PROJ" && git config core.hooksPath .husky)
out_t17=$(cd "$PROJ" && aapp init 2>&1)
hooks_path=$(cd "$PROJ" && git config --get core.hooksPath || true)
if [ "$hooks_path" = ".husky" ] && [ -f "$PROJ/.githooks/pre-commit" ] && echo "$out_t17" | grep -q "core.hooksPath is currently set to: '.husky'"; then
  got="PASS"
else
  got="FAIL"
fi
report "core.hooksPath=.husky -> config untouched, wiring printed" "PASS" "$got" "$out_t17"

# Test 18: executable .git/hooks/pre-commit -> config untouched, wiring printed
PROJ="$R/t18_proj"; make_dummy_project "$PROJ"
mkdir -p "$PROJ/.git/hooks"
echo "#!/bin/sh" > "$PROJ/.git/hooks/pre-commit"
chmod +x "$PROJ/.git/hooks/pre-commit"
out_t18=$(cd "$PROJ" && aapp init 2>&1)
hooks_path=$(cd "$PROJ" && git config --get core.hooksPath || true)
if [ -z "$hooks_path" ] && echo "$out_t18" | grep -q "Executable hook found at '.git/hooks/pre-commit'"; then
  got="PASS"
else
  got="FAIL"
fi
report "executable .git/hooks/pre-commit -> config untouched, wiring printed" "PASS" "$got" "$out_t18"

# Test 19: wiring line in custom hook catches blast-radius violation
PROJ="$R/t19_proj"; make_dummy_project "$PROJ"
mkdir -p "$PROJ/.husky"
cat > "$PROJ/.husky/pre-commit" <<'EOF'
#!/bin/sh
"$(git rev-parse --show-toplevel)/.githooks/pre-commit" || exit 1
EOF
chmod +x "$PROJ/.husky/pre-commit"
(cd "$PROJ" && git config core.hooksPath .husky)
(cd "$PROJ" && aapp init >/dev/null 2>&1)
mkdir -p "$PROJ/.plans/current"
cat > "$PROJ/.plans/current/plan.md" <<'EOF'
## 💥 4. Blast Radius & System Boundaries
### 📂 Target Files (Modifications & Additions)
- [ ] `a.py` -> modify
### 🛑 Out of Bounds (Do Not Touch)
EOF
echo "unauthorized" > "$PROJ/forbidden.py"
(
  cd "$PROJ"
  git add forbidden.py
  git commit -m "violating commit" >/dev/null 2>&1
)
rc_commit=$?
if [ $rc_commit -ne 0 ]; then
  got="PASS"
else
  got="FAIL"
fi
report "wiring line in custom hook catches blast-radius violation" "PASS" "$got"

echo "== 6. Error Cases & Collision Protections =="

# Test 21: project's own templates/ directory is preserved untouched
PROJ="$R/t21_proj"; make_dummy_project "$PROJ"
mkdir -p "$PROJ/templates"
echo "<h1>Flask App</h1>" > "$PROJ/templates/index.html"
(cd "$PROJ" && aapp init >/dev/null 2>&1)
if [ -f "$PROJ/templates/index.html" ]; then
  got="PASS"
else
  got="DELETED"
fi
report "project's own templates/ directory is preserved untouched" "PASS" "$got"

# Test 22: pre-existing non-worktree directory collision guard
PROJ="$R/t22_proj"; make_dummy_project "$PROJ"
mkdir -p "$PROJ/.plans"
echo "custom non-worktree content" > "$PROJ/.plans/custom.txt"
out_t22=$(cd "$PROJ" && aapp init 2>&1 || true)
if echo "$out_t22" | grep -q "exists as a normal directory, not an AAPP worktree"; then
  got="PASS"
else
  got="FAIL"
fi
report "existing flat non-worktree folder triggers collision guard" "PASS" "$got" "$out_t22"

# Test 23: multi-machine restore: origin/plans tracking branch mounts cleanly
PROJ_REMOTE="$R/t23_remote"; make_dummy_project "$PROJ_REMOTE"
(
  cd "$PROJ_REMOTE"
  git checkout --orphan plans -q
  git rm -rf . -q 2>/dev/null || true
  mkdir -p current
  echo "# Remote Plan" > current/p.md
  git add current/p.md
  git commit -qm "remote plans branch"
  git checkout main -q
)
PROJ_LOCAL="$R/t23_local"
git clone -q "$PROJ_REMOTE" "$PROJ_LOCAL"
out_t23=$(cd "$PROJ_LOCAL" && aapp init 2>&1)
rc=$?
if [ $rc -eq 0 ] && [ -f "$PROJ_LOCAL/.plans/current/p.md" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "multi-machine restore: mounts origin tracking branch without conflict" "PASS" "$got" "$out_t23"

echo "== 7. Global Installer & Commands (install, uninstall, status) =="

# Test 24: aapp install creates ~/.local/bin and share dir when missing
GLOBAL_HOME="$R/t24_home"; mkdir -p "$GLOBAL_HOME"
INSTALLER_DIR="$R/t24_installer"; make_kit_clone "$INSTALLER_DIR"
(
  cd "$INSTALLER_DIR"
  HOME="$GLOBAL_HOME" XDG_DATA_HOME="$GLOBAL_HOME/.local/share" ./aapp install >/dev/null 2>&1
)
rc=$?
if [ $rc -eq 0 ] && [ -x "$GLOBAL_HOME/.local/bin/aapp" ] && [ -f "$GLOBAL_HOME/.local/share/aapp-kit/templates/pre-commit" ] && [ -f "$GLOBAL_HOME/.local/share/aapp-kit/lib/cmd_init.sh" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp install creates ~/.local/bin and share lib/templates when missing" "PASS" "$got"

# P-37: install keeps templates/aapp-lib.sh a symlink resolving inside the installed kit
TPL_LIB="$GLOBAL_HOME/.local/share/aapp-kit/templates/aapp-lib.sh"
if [ -L "$TPL_LIB" ] && [ "$(readlink "$TPL_LIB")" = "../lib/aapp-lib.sh" ] && \
   cmp -s "$TPL_LIB" "$GLOBAL_HOME/.local/share/aapp-kit/lib/aapp-lib.sh"; then
  got="PASS"
else
  got="FAIL"
fi
report "test_install_preserves_template_symlink" "PASS" "$got"

# Test 25: aapp install consumes installer clone folder on success
if [ ! -d "$INSTALLER_DIR" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp install consumes installer clone folder on success" "PASS" "$got"

# Test 25b: aapp install rejects unknown flag --keep (#51)
GLOBAL_HOME_25B="$R/t25b_home"; mkdir -p "$GLOBAL_HOME_25B"
INSTALLER_DIR_25B="$R/t25b_installer"; make_kit_clone "$INSTALLER_DIR_25B"
out_25b=$(
  cd "$INSTALLER_DIR_25B"
  HOME="$GLOBAL_HOME_25B" XDG_DATA_HOME="$GLOBAL_HOME_25B/.local/share" ./aapp install --keep 2>&1 || true
)
if echo "$out_25b" | grep -q "Unknown option '--keep'" && [ -d "$INSTALLER_DIR_25B" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp install rejects unknown flag --keep" "PASS" "$got"

# Test 25c: aapp install preserves installer folder when extra non-kit files are present (#51)
GLOBAL_HOME_25C="$R/t25c_home"; mkdir -p "$GLOBAL_HOME_25C"
INSTALLER_DIR_25C="$R/t25c_installer"; make_kit_clone "$INSTALLER_DIR_25C"
touch "$INSTALLER_DIR_25C/user_data.txt"
(
  cd "$INSTALLER_DIR_25C"
  HOME="$GLOBAL_HOME_25C" XDG_DATA_HOME="$GLOBAL_HOME_25C/.local/share" ./aapp install >/dev/null 2>&1
)
rc=$?
if [ $rc -eq 0 ] && [ -d "$INSTALLER_DIR_25C" ] && [ -f "$INSTALLER_DIR_25C/user_data.txt" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp install preserves installer folder when extra non-kit files are present (#51)" "PASS" "$got"

# Test 25d: aapp install preserves installer folder when uncommitted modifications are present (#51)
GLOBAL_HOME_25D="$R/t25d_home"; mkdir -p "$GLOBAL_HOME_25D"
INSTALLER_DIR_25D="$R/t25d_installer"; make_kit_clone "$INSTALLER_DIR_25D"
echo "# uncommitted change" >> "$INSTALLER_DIR_25D/templates/pre-commit"
(
  cd "$INSTALLER_DIR_25D"
  HOME="$GLOBAL_HOME_25D" XDG_DATA_HOME="$GLOBAL_HOME_25D/.local/share" ./aapp install >/dev/null 2>&1
)
rc=$?
if [ $rc -eq 0 ] && [ -d "$INSTALLER_DIR_25D" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp install preserves installer folder when uncommitted modifications are present (#51)" "PASS" "$got"

# Test 26: tests/ and lib/ reachable from installed share dir
if [ -d "$GLOBAL_HOME/.local/share/aapp-kit/tests" ] && [ -f "$GLOBAL_HOME/.local/share/aapp-kit/lib/cmd_status.sh" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "lib/ and tests/ reachable in installed share directory" "PASS" "$got"

# Test 27: installed aapp init targets cwd repo and deletes nothing
PROJ="$R/t27_proj"; make_dummy_project "$PROJ"
(
  cd "$PROJ"
  PATH="$GLOBAL_HOME/.local/bin:$PATH" HOME="$GLOBAL_HOME" XDG_DATA_HOME="$GLOBAL_HOME/.local/share" aapp init >/dev/null 2>&1
)
rc=$?
if [ $rc -eq 0 ] && [ -d "$PROJ/.plans" ] && [ -d "$PROJ/.agents" ] && [ -x "$GLOBAL_HOME/.local/bin/aapp" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "installed 'aapp init' targets cwd repo and deletes nothing" "PASS" "$got"

# Test 28: PATH detection: already present -> no edit
out_path=$(
  cd "$GLOBAL_HOME"
  PATH="$GLOBAL_HOME/.local/bin:$PATH" HOME="$GLOBAL_HOME" XDG_DATA_HOME="$GLOBAL_HOME/.local/share" make_kit_clone "$R/t28_kit"
  cd "$R/t28_kit"
  PATH="$GLOBAL_HOME/.local/bin:$PATH" HOME="$GLOBAL_HOME" XDG_DATA_HOME="$GLOBAL_HOME/.local/share" ./aapp install 2>&1
)
if echo "$out_path" | grep -q "is already in your PATH"; then
  got="PASS"
else
  got="FAIL"
fi
report "PATH detection: already present -> no edit, report ok" "PASS" "$got" "$out_path"

# Test 29: freshly-created ~/.local/bin advises re-login
NEW_HOME="$R/t29_home"; mkdir -p "$NEW_HOME"
INSTALLER_29="$R/t29_installer"; make_kit_clone "$INSTALLER_29"
out_fresh=$(
  cd "$INSTALLER_29"
  PATH="/usr/bin:/bin" HOME="$NEW_HOME" XDG_DATA_HOME="$NEW_HOME/.local/share" ./aapp install 2>&1
)
if echo "$out_fresh" | grep -q "logging out and" && echo "$out_fresh" | grep -q "back in will automatically add it"; then
  got="PASS"
else
  got="FAIL"
fi
report "freshly-created ~/.local/bin -> advises re-login, edits nothing" "PASS" "$got" "$out_fresh"

# Test 30: aapp uninstall removes binary and share data, leaves user rc intact
UNINSTALL_HOME="$R/t30_home"; mkdir -p "$UNINSTALL_HOME"
touch "$UNINSTALL_HOME/.bashrc"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$UNINSTALL_HOME/.bashrc"
INSTALLER_30="$R/t30_installer"; make_kit_clone "$INSTALLER_30"
(
  cd "$INSTALLER_30"
  PATH="/usr/bin:/bin" HOME="$UNINSTALL_HOME" XDG_DATA_HOME="$UNINSTALL_HOME/.local/share" ./aapp install >/dev/null 2>&1
)
out_uninst=$(
  PATH="/usr/bin:/bin" HOME="$UNINSTALL_HOME" XDG_DATA_HOME="$UNINSTALL_HOME/.local/share" "$UNINSTALL_HOME/.local/bin/aapp" uninstall 2>&1
)
rc=$?
bashrc_content=$(cat "$UNINSTALL_HOME/.bashrc")
if [ $rc -eq 0 ] && \
   [ ! -f "$UNINSTALL_HOME/.local/bin/aapp" ] && \
   [ ! -d "$UNINSTALL_HOME/.local/share/aapp-kit" ] && \
   [ -d "$UNINSTALL_HOME/.local/bin" ] && \
   [ -d "$UNINSTALL_HOME/.local/share" ] && \
   [ "$bashrc_content" = 'export PATH="$HOME/.local/bin:$PATH"' ]; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp uninstall leaves no trace of kit but preserves shared dirs and rc" "PASS" "$got" "$out_uninst"

# Test 31: aapp status prints 4-pillar context recovery briefing
PROJ_31="$R/t31_proj"; make_dummy_project "$PROJ_31"
(cd "$PROJ_31" && aapp init >/dev/null 2>&1)
out_status=$(cd "$PROJ_31" && aapp status 2>&1)
if echo "$out_status" | grep -q "SHIPPED" && \
   echo "$out_status" | grep -q "ISSUES" && \
   echo "$out_status" | grep -q "PLANS" && \
   echo "$out_status" | grep -q "PICKUP QUEUE"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp status prints all 4 pillars of context recovery" "PASS" "$got" "$out_status"

# Test 32: aapp-develop-kit directory is preserved on install
DEV_KIT_DIR="$R/aapp-develop-kit"; make_kit_clone "$DEV_KIT_DIR"
DEV_HOME="$R/t32_home"; mkdir -p "$DEV_HOME"
(
  cd "$DEV_KIT_DIR"
  PATH="/usr/bin:/bin" HOME="$DEV_HOME" XDG_DATA_HOME="$DEV_HOME/.local/share" ./aapp install >/dev/null 2>&1
)
if [ -d "$DEV_KIT_DIR" ] && [ -f "$DEV_KIT_DIR/aapp" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp install preserves aapp-develop-kit folder without self-consuming" "PASS" "$got"

# Test 33: unclosed <!-- AAPP-PROTOCOL:START --> marker skips replacement to prevent data loss
PROJ_33="$R/t33_proj"; make_dummy_project "$PROJ_33"
(cd "$PROJ_33" && aapp init >/dev/null 2>&1)
# Intentionally corrupt .agents/AGENTS.md by removing END marker
cat > "$PROJ_33/.agents/AGENTS.md" <<'EOF'
# Custom Header
<!-- AAPP-PROTOCOL:START v1.0.0 -->
Some content that was not closed properly
# Important custom notes that must not be deleted
EOF
out_corrupt=$(cd "$PROJ_33" && aapp init 2>&1)
agents_content=$(cat "$PROJ_33/.agents/AGENTS.md")
if echo "$out_corrupt" | grep -q "Found unclosed <!-- AAPP-PROTOCOL:START --> marker" && \
   echo "$agents_content" | grep -q "Important custom notes that must not be deleted"; then
  got="PASS"
else
  got="FAIL"
fi
report "unclosed START marker logs warning and preserves file untouched" "PASS" "$got" "$out_corrupt"

# Test 34: aapp develop creates symlinks and live changes propagate
DEV_HOME_34="$R/t34_home"; mkdir -p "$DEV_HOME_34"
DEV_KIT_34="$R/t34_dev_kit"; make_kit_clone "$DEV_KIT_34"
out_dev=$(
  cd "$DEV_KIT_34"
  PATH="/usr/bin:/bin" HOME="$DEV_HOME_34" XDG_DATA_HOME="$DEV_HOME_34/.local/share" ./aapp develop 2>&1
)
bin_symlink="$DEV_HOME_34/.local/bin/aapp"
share_symlink="$DEV_HOME_34/.local/share/aapp-kit"

is_symlinks=0
[ -L "$bin_symlink" ] && [ -L "$share_symlink" ] && is_symlinks=1

echo "# test_live_marker=1" >> "$DEV_KIT_34/lib/cmd_status.sh"
live_edit=0
[ -f "$share_symlink/lib/cmd_status.sh" ] && grep -q "test_live_marker=1" "$share_symlink/lib/cmd_status.sh" && live_edit=1

if [ $is_symlinks -eq 1 ] && [ $live_edit -eq 1 ] && [ -d "$DEV_KIT_34" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp develop links live clone globally without copying or consuming" "PASS" "$got" "$out_dev"

# P-34: develop-only pre-commit engine — absent after init, seeded by develop,
# idempotent on re-run, removed by uninstall inside the repository
DEV_HOME_34B="$R/t34b_home"; mkdir -p "$DEV_HOME_34B"
DEV_KIT_34B="$R/t34b_dev_kit"; make_kit_clone "$DEV_KIT_34B"
(cd "$DEV_KIT_34B" && aapp init >/dev/null 2>&1)
absent_after_init=0
[ -d "$DEV_KIT_34B/.githooks" ] && [ ! -e "$DEV_KIT_34B/.githooks/aapp-pre-commit-develop" ] && absent_after_init=1
(cd "$DEV_KIT_34B" && PATH="/usr/bin:/bin" HOME="$DEV_HOME_34B" XDG_DATA_HOME="$DEV_HOME_34B/.local/share" ./aapp develop >/dev/null 2>&1)
seeded=0
[ -x "$DEV_KIT_34B/.githooks/aapp-pre-commit-develop" ] && \
  [ "$(grep -c '^# >>> aapp-pre-commit-develop (P-34) >>>$' "$DEV_KIT_34B/.githooks/pre-commit")" -eq 1 ] && seeded=1
sum_first="$(cksum < "$DEV_KIT_34B/.githooks/pre-commit")"
(cd "$DEV_KIT_34B" && PATH="/usr/bin:/bin" HOME="$DEV_HOME_34B" XDG_DATA_HOME="$DEV_HOME_34B/.local/share" ./aapp develop >/dev/null 2>&1)
sum_second="$(cksum < "$DEV_KIT_34B/.githooks/pre-commit")"
if [ "$absent_after_init" -eq 1 ] && [ "$seeded" -eq 1 ] && [ "$sum_first" = "$sum_second" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "test_develop_hook_seeding" "PASS" "$got" "absent_after_init=$absent_after_init seeded=$seeded"

(cd "$DEV_KIT_34B" && PATH="/usr/bin:/bin" HOME="$DEV_HOME_34B" XDG_DATA_HOME="$DEV_HOME_34B/.local/share" ./aapp uninstall >/dev/null 2>&1)
if [ ! -e "$DEV_KIT_34B/.githooks/aapp-pre-commit-develop" ] && \
   ! grep -q "aapp-pre-commit-develop" "$DEV_KIT_34B/.githooks/pre-commit"; then
  got="PASS"
else
  got="FAIL"
fi
report "uninstall removes the develop-only engine and its wrapper block" "PASS" "$got"

# Test 35: aapp install after aapp develop safely unlinks symlink and preserves source files
DEV_HOME_35="$R/t35_home"; mkdir -p "$DEV_HOME_35"
DEV_KIT_35="$R/t35_dev_kit"; make_kit_clone "$DEV_KIT_35"
(
  cd "$DEV_KIT_35"
  PATH="/usr/bin:/bin" HOME="$DEV_HOME_35" XDG_DATA_HOME="$DEV_HOME_35/.local/share" ./aapp develop >/dev/null 2>&1
)
INSTALLER_35="$R/t35_installer"; make_kit_clone "$INSTALLER_35"
(
  cd "$INSTALLER_35"
  PATH="/usr/bin:/bin" HOME="$DEV_HOME_35" XDG_DATA_HOME="$DEV_HOME_35/.local/share" ./aapp install >/dev/null 2>&1 < /dev/null
)
if [ -d "$DEV_KIT_35/lib" ] && \
   [ -f "$DEV_KIT_35/lib/cmd_init.sh" ] && \
   [ -d "$DEV_HOME_35/.local/share/aapp-kit" ] && \
   [ ! -L "$DEV_HOME_35/.local/share/aapp-kit" ] && \
   [ ! -L "$DEV_HOME_35/.local/bin/aapp" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "install after develop unlinks safely without deleting repo source" "PASS" "$got"

# Test 36: aapp uninstall cleans up broken/dangling symlinks
DEV_HOME_36="$R/t36_home"; mkdir -p "$DEV_HOME_36"
DEV_KIT_36="$R/t36_dev_kit"; make_kit_clone "$DEV_KIT_36"
(
  cd "$DEV_KIT_36"
  PATH="/usr/bin:/bin" HOME="$DEV_HOME_36" XDG_DATA_HOME="$DEV_HOME_36/.local/share" ./aapp develop >/dev/null 2>&1
)
rm -rf "$DEV_KIT_36"
# Run outside any repository: uninstall also cleans the develop-only hook of
# the repository it is invoked in, which must never be the kit under test.
out_uninst_broken=$(
  cd "$R" && PATH="/usr/bin:/bin" HOME="$DEV_HOME_36" XDG_DATA_HOME="$DEV_HOME_36/.local/share" "$KIT/aapp" uninstall 2>&1
)
bin_remains=0
[ -e "$DEV_HOME_36/.local/bin/aapp" ] || [ -L "$DEV_HOME_36/.local/bin/aapp" ] && bin_remains=1
share_remains=0
[ -e "$DEV_HOME_36/.local/share/aapp-kit" ] || [ -L "$DEV_HOME_36/.local/share/aapp-kit" ] && share_remains=1
if [ $bin_remains -eq 0 ] && [ $share_remains -eq 0 ] && echo "$out_uninst_broken" | grep -q "Removed"; then
  got="PASS"
else
  got="FAIL"
fi
report "uninstall removes broken/dangling symlinks cleanly" "PASS" "$got" "$out_uninst_broken"

echo "== 8. Universal Skills, Claude Bridge, and Settings Decoupling =="

# Test 37: Fresh install decouples .claude/settings.json into canonical .agents/claude/settings.json and creates granular symlink
PROJ_37="$R/t37_proj"; make_dummy_project "$PROJ_37"
(cd "$PROJ_37" && aapp init >/dev/null 2>&1)
if [ -L "$PROJ_37/.claude/settings.json" ] && \
   [ -f "$PROJ_37/.agents/claude/settings.json" ] && \
   [ "$(readlink "$PROJ_37/.claude/settings.json")" = "../.agents/claude/settings.json" ] && \
   grep -q "blast-radius-guard" "$PROJ_37/.claude/settings.json"; then
  got="PASS"
else
  got="FAIL"
fi
report "settings decoupling: .claude/settings.json symlinks to canonical .agents/claude/settings.json" "PASS" "$got"

# Test 38: Fresh install adds .claude/ to .gitignore on code branch
if grep -qxF ".claude/" "$PROJ_37/.gitignore"; then
  got="PASS"
else
  got="FAIL"
fi
report "clean codebase: .claude/ added to .gitignore on code branch" "PASS" "$got"

# Test 39: Fresh install synchronizes canonical .agents/skills/ and bridges .claude/skills/ via granular relative symlinks
skills_ok=1
for v in aapp-status aapp-digest aapp-freeze aapp-start aapp-done aapp-pause aapp-release aapp-plan aapp-tdd plan; do
  [ -f "$PROJ_37/.agents/skills/$v/SKILL.md" ] || skills_ok=0
  [ -L "$PROJ_37/.claude/skills/$v" ] || skills_ok=0
  [ "$(readlink "$PROJ_37/.claude/skills/$v")" = "../../.agents/skills/$v" ] || skills_ok=0
  [ -s "$PROJ_37/.claude/skills/$v/SKILL.md" ] || skills_ok=0
done
if [ $skills_ok -eq 1 ]; then
  got="PASS"
else
  got="FAIL"
fi
report "universal skills: installed in .agents/skills and bridged to .claude/skills via relative symlinks" "PASS" "$got"

# Test 40: Non-destructive: preserves custom user skills and local settings
PROJ_40="$R/t40_proj"; make_dummy_project "$PROJ_40"
mkdir -p "$PROJ_40/.claude/skills/custom-deploy"
echo "# Custom Deploy" > "$PROJ_40/.claude/skills/custom-deploy/SKILL.md"
echo '{"localSecret": "123"}' > "$PROJ_40/.claude/settings.local.json"
(cd "$PROJ_40" && aapp init >/dev/null 2>&1)
if [ -f "$PROJ_40/.claude/skills/custom-deploy/SKILL.md" ] && \
   [ ! -L "$PROJ_40/.claude/skills/custom-deploy" ] && \
   grep -q "Custom Deploy" "$PROJ_40/.claude/skills/custom-deploy/SKILL.md" && \
   [ -f "$PROJ_40/.claude/settings.local.json" ] && \
   grep -q "localSecret" "$PROJ_40/.claude/settings.local.json"; then
  got="PASS"
else
  got="FAIL"
fi
report "non-destructive: preserves custom user skills and local settings" "PASS" "$got"

# Test 41: Clean upgrade: drops stale files on skill re-sync
PROJ_41="$R/t41_proj"; make_dummy_project "$PROJ_41"
(cd "$PROJ_41" && aapp init >/dev/null 2>&1)
touch "$PROJ_41/.agents/skills/aapp-status/stale-old-file.txt"
(cd "$PROJ_41" && aapp init >/dev/null 2>&1)
if [ ! -f "$PROJ_41/.agents/skills/aapp-status/stale-old-file.txt" ] && \
   [ -f "$PROJ_41/.agents/skills/aapp-status/SKILL.md" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "clean upgrade: drops stale files on skill re-sync" "PASS" "$got"

# Test 42: Drift control: all governance skills declare valid frontmatter, flags, and inline/fork contracts
drift_ok=1
for v in aapp-status aapp-digest aapp-freeze aapp-start aapp-done aapp-pause aapp-release aapp-plan aapp-tdd plan; do
  skill_file="$KIT/templates/skills/$v/SKILL.md"
  [ -f "$skill_file" ] || { drift_ok=0; break; }
  grep -q "^name: $v$" "$skill_file" || drift_ok=0
  grep -q "^description: " "$skill_file" || drift_ok=0
  grep -q "^disable-model-invocation: false$" "$skill_file" || drift_ok=0
done
# Retired skills must not declare SKILL.md
[ -f "$KIT/templates/skills/aapp-freeze-start/SKILL.md" ] && drift_ok=0
[ -f "$KIT/templates/skills/aapp-active/SKILL.md" ] && drift_ok=0
[ -f "$KIT/templates/skills/aapp-hooks/SKILL.md" ] && drift_ok=0
grep -q "^context: fork$" "$KIT/templates/skills/aapp-release/SKILL.md" || drift_ok=0
grep -q "context: fork" "$KIT/templates/skills/aapp-digest/SKILL.md" && drift_ok=0
grep -q "context: fork" "$KIT/templates/skills/aapp-status/SKILL.md" && drift_ok=0
grep -q "aapp-plan" "$KIT/templates/skills/plan/SKILL.md" || drift_ok=0

if [ $drift_ok -eq 1 ]; then
  got="PASS"
else
  got="FAIL"
fi
report "drift control: all governance skills declare valid frontmatter, flags, and inline/fork contracts" "PASS" "$got"

# Test 43: aapp init provisions .plans/done/000-issues-archive.md from template
PROJ_43="$R/t43_proj"; make_dummy_project "$PROJ_43"
(cd "$PROJ_43" && aapp init >/dev/null 2>&1)
if [ -f "$PROJ_43/.plans/done/000-issues-archive.md" ] && \
   grep -q "Master Issue Archive Ledger" "$PROJ_43/.plans/done/000-issues-archive.md" && \
   grep -q "| Date Opened | Date Resolved |" "$PROJ_43/.plans/done/000-issues-archive.md"; then
  got="PASS"
else
  got="FAIL"
fi
report "archive ledger: aapp init provisions .plans/done/000-issues-archive.md" "PASS" "$got"

# Test 44: non-destructive init preserves custom ISSUES.md and prints advisory
PROJ_44="$R/t44_proj"; make_dummy_project "$PROJ_44"
cat > "$PROJ_44/ISSUES.md" <<'EOF'
# Custom Jira Export
- ISSUE-1234: Custom issue description in prose format
EOF
(
  cd "$PROJ_44"
  git add ISSUES.md
  git commit -qm "add custom issues"
)
init_out=$(cd "$PROJ_44" && aapp init 2>&1)
if [ -f "$PROJ_44/.plans/ISSUES.md" ] && \
   grep -q "Custom Jira Export" "$PROJ_44/.plans/ISSUES.md" && \
   echo "$init_out" | grep -q "Found existing custom .plans/ISSUES.md"; then
  got="PASS"
else
  got="FAIL"
fi
report "non-destructive init: preserves custom ISSUES.md with advisory notice" "PASS" "$got"

# Test 45: templates/issues.md conforms to flat single-table schema (zero subheadings)
template_issues="$KIT/templates/issues.md"
subheading_count=$(grep -E '^## ' "$template_issues" 2>/dev/null | wc -l | tr -d ' ')
has_flat_columns=0
if grep -q '| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |' "$template_issues"; then
  has_flat_columns=1
fi
if [ "$subheading_count" -eq 0 ] && [ "$has_flat_columns" -eq 1 ]; then
  got="PASS"
else
  got="FAIL"
fi
report "flat schema: templates/issues.md has zero subheadings and 8-column format" "PASS" "$got"

# Test 46: templates/plan-template.md includes Plan ID header
template_plan="$KIT/templates/plan-template.md"
if grep -q '\* \*\*Plan ID:\*\* P-XX' "$template_plan"; then
  got="PASS"
else
  got="FAIL"
fi
report "plan template: templates/plan-template.md includes Plan ID header" "PASS" "$got"

# Test 47: templates/000-archive-ledger.md includes Plan ID column
template_ledger="$KIT/templates/000-archive-ledger.md"
if grep -q '| Plan ID |' "$template_ledger"; then
  got="PASS"
else
  got="FAIL"
fi
report "archive ledger: templates/000-archive-ledger.md includes Plan ID column" "PASS" "$got"

# Test 48: templates/pickup.md pre-seeds Onboarding queue item
template_pickup="$KIT/templates/pickup.md"
if grep -q '\- \[ \] Onboarding: Inspect repository codebase to populate \.agents/CODEMAP\.md, ARCHITECTURE\.md, and \.agents/PROJECT\.MD' "$template_pickup"; then
  got="PASS"
else
  got="FAIL"
fi
report "pickup template: templates/pickup.md pre-seeds Onboarding task" "PASS" "$got"

# Test 49: aapp init outputs First AAPP Loop onboarding next steps
PROJ="$R/t49_proj"; make_dummy_project "$PROJ"
init_out=$(cd "$PROJ" && aapp init 2>&1)
if echo "$init_out" | grep -q "Experience Your First AAPP Loop" && \
   echo "$init_out" | grep -q "/aapp-digest Onboarding"; then
  got="PASS"
else
  got="FAIL"
fi
report "init banner: aapp init outputs First AAPP Loop onboarding guidance" "PASS" "$got"

# Test 50: aapp init syncs aapp-pause skill into .agents/skills and .claude/skills
PROJ="$R/t50_proj"; make_dummy_project "$PROJ"
(cd "$PROJ" && aapp init >/dev/null 2>&1)
rc=$?
if [ $rc -eq 0 ] && \
   [ -f "$PROJ/.agents/skills/aapp-pause/SKILL.md" ] && \
   [ -e "$PROJ/.claude/skills/aapp-pause/SKILL.md" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "skill sync: aapp init syncs aapp-pause into .agents/skills and .claude/skills" "PASS" "$got"

# Test 51: templates/skills/aapp-pause/SKILL.md has valid name and argument hints
pause_skill="$KIT/templates/skills/aapp-pause/SKILL.md"
if [ -f "$pause_skill" ] && \
   grep -q "^name: aapp-pause" "$pause_skill" && \
   grep -q "^argument-hint:" "$pause_skill"; then
  got="PASS"
else
  got="FAIL"
fi
report "pause skill schema: templates/skills/aapp-pause/SKILL.md has valid frontmatter" "PASS" "$got"

# Test 52: aapp init prunes retired skills from .agents/skills and .claude/skills while keeping registry.tsv
PROJ_52="$R/t52_proj"; make_dummy_project "$PROJ_52"
(cd "$PROJ_52" && aapp init >/dev/null 2>&1)
mkdir -p "$PROJ_52/.agents/skills/aapp-freeze-start" "$PROJ_52/.claude/skills/aapp-freeze-start"
mkdir -p "$PROJ_52/.agents/skills/aapp-active" "$PROJ_52/.claude/skills/aapp-active"
touch "$PROJ_52/.agents/skills/aapp-freeze-start/SKILL.md" "$PROJ_52/.claude/skills/aapp-freeze-start/SKILL.md"
touch "$PROJ_52/.agents/skills/aapp-active/SKILL.md" "$PROJ_52/.claude/skills/aapp-active/SKILL.md"
touch "$PROJ_52/.agents/skills/aapp-hooks/SKILL.md"
mkdir -p "$PROJ_52/.claude/skills/aapp-hooks"
touch "$PROJ_52/.claude/skills/aapp-hooks/SKILL.md"
printf "on-sync\tcustom_handler.sh\tsha256:dummy\t10\tgate\n" > "$PROJ_52/.agents/skills/aapp-hooks/registry.tsv"
(cd "$PROJ_52" && aapp init >/dev/null 2>&1)
if [ ! -d "$PROJ_52/.agents/skills/aapp-freeze-start" ] && \
   [ ! -d "$PROJ_52/.claude/skills/aapp-freeze-start" ] && \
   [ ! -d "$PROJ_52/.agents/skills/aapp-active" ] && \
   [ ! -d "$PROJ_52/.claude/skills/aapp-active" ] && \
   [ ! -f "$PROJ_52/.agents/skills/aapp-hooks/SKILL.md" ] && \
   [ ! -d "$PROJ_52/.claude/skills/aapp-hooks" ] && \
   [ -f "$PROJ_52/.agents/skills/aapp-hooks/registry.tsv" ] && \
   grep -q "custom_handler.sh" "$PROJ_52/.agents/skills/aapp-hooks/registry.tsv"; then
  got="PASS"
else
  got="FAIL"
fi
report "skill pruning: aapp init removes retired skills and bridges while preserving registry.tsv" "PASS" "$got"

# Test 53: Canonical Verb Manifest (lib/verbs.tsv) exists and conforms to schema
manifest="$KIT/lib/verbs.tsv"
if [ -f "$manifest" ] && \
   [ "$(grep -v '^[[:space:]]*#' "$manifest" | grep -v '^[[:space:]]*$' | wc -l)" -ge 30 ] && \
   grep -q "daily" "$manifest" && grep -q "setup" "$manifest" && \
   grep -q "sync" "$manifest" && grep -q "hooks" "$manifest" && grep -q "ai" "$manifest"; then
  got="PASS"
else
  got="FAIL"
fi
report "canonical manifest: lib/verbs.tsv defines verbs across 5 visual tiers" "PASS" "$got"

# Test 54: aapp draft scaffolds blueprint, stamps monotonic ID, registers in matrix
PROJ_54="$R/t54_proj"; make_dummy_project "$PROJ_54"
(cd "$PROJ_54" && aapp init >/dev/null 2>&1)
(cd "$PROJ_54" && aapp draft test-feature >/dev/null 2>&1)
if compgen -G "$PROJ_54/.plans/current/P*-test-feature.md" >/dev/null && \
   grep -q "Plan P-.*: Test Feature" "$PROJ_54"/.plans/current/P*-test-feature.md && \
   grep -q "test-feature.md" "$PROJ_54/.plans/state_matrix.md"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp draft: scaffolds blueprint, stamps ID & date, registers in matrix" "PASS" "$got"

# Test 55: aapp draft no-dead-end fallback auto-selects pickup note in non-interactive mode
PROJ_55="$R/t55_proj"; make_dummy_project "$PROJ_55"
(cd "$PROJ_55" && aapp init >/dev/null 2>&1)
echo "1. Automatic Backup System: Implement automated local backup" > "$PROJ_55/.plans/pickup.md"
(cd "$PROJ_55" && aapp draft </dev/null >/dev/null 2>&1)
if compgen -G "$PROJ_55/.plans/current/P*-automatic-backup-system*.md" >/dev/null; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp draft: bare non-interactive fallback targets candidate pickup note" "PASS" "$got"

# Test 56: Tiered help generation (lib/cmd_help.sh) matches lib/verbs.tsv
help_out="$("$KIT/aapp" help 2>&1)"
if echo "$help_out" | grep -q "Daily Working Loop (Core):" && \
   echo "$help_out" | grep -q "Setup & Maintenance:" && \
   echo "$help_out" | grep -q "Team Sync & Emergency Controls:" && \
   echo "$help_out" | grep -q "Extensibility & Automation (Hooks & Plugins):" && \
   echo "$help_out" | grep -q "Attribution & Metadata (AI Switchboard):"; then
  got="PASS"
else
  got="FAIL"
fi
report "tiered help: aapp help groups verbs into 5 canonical visual tiers" "PASS" "$got"

# P-34: the fifth verbs.tsv column (contract path) never leaks into aapp help
if [ -n "$help_out" ] && ! echo "$help_out" | grep -q "lib/docs/verbs/" && \
   echo "$help_out" | grep -qE "^  draft +Scaffold blueprint from template, stamp ID & date, register in matrix$"; then
  got="PASS"
else
  got="FAIL"
fi
report "test_help_ignores_contract_column" "PASS" "$got"

# Test 57: aapp hooks events prints lifecycle event catalog
events_out="$("$KIT/aapp" hooks events 2>&1)"
if echo "$events_out" | grep -q "Supported Lifecycle Events Catalog" && \
   echo "$events_out" | grep -q "pre-freeze" && \
   echo "$events_out" | grep -q "on-sync" && \
   echo "$events_out" | grep -q "post-freeze"; then
  got="PASS"
else
  got="FAIL"
fi
report "hooks catalog: aapp hooks events displays Pre/On/Post timing taxonomy" "PASS" "$got"

# Test 58: Dispatcher-to-Manifest Parity: all verbs in lib/verbs.tsv handled in aapp
manifest="$KIT/lib/verbs.tsv"
missing_verbs=""
while IFS="$(printf '\t')" read -r v tier stand desc || [ -n "$v" ]; do
  [ -z "$v" ] && continue
  [ "${v#\#}" != "$v" ] && continue
  if ! grep -qE "([|[:space:]]|^)$v([|)][[:space:]]*|$)" "$KIT/aapp"; then
    missing_verbs="$missing_verbs $v"
  fi
done < "$manifest"
if [ -z "$missing_verbs" ]; then
  got="PASS"
else
  got="FAIL ($missing_verbs)"
fi
report "dispatcher parity: all verbs in lib/verbs.tsv are wired into aapp dispatcher" "PASS" "$got"

# Test 59: Manifest-to-Cheatsheet Parity: all verbs in lib/verbs.tsv appear in CHEATSHEET.md
cheatsheet="$KIT/CHEATSHEET.md"
missing_cheat=""
while IFS="$(printf '\t')" read -r v tier stand desc || [ -n "$v" ]; do
  [ -z "$v" ] && continue
  [ "${v#\#}" != "$v" ] && continue
  if ! grep -q "\`aapp $v" "$cheatsheet" && ! grep -q "\`$v" "$cheatsheet"; then
    missing_cheat="$missing_cheat $v"
  fi
done < "$manifest"
if [ -z "$missing_cheat" ]; then
  got="PASS"
else
  got="FAIL ($missing_cheat)"
fi
report "cheatsheet parity: all verbs in lib/verbs.tsv appear in CHEATSHEET.md" "PASS" "$got"

# Test 60: aapp done moves plan to done/ and updates status to Done
PROJ_60="$R/t60_proj"; make_dummy_project "$PROJ_60"
(cd "$PROJ_60" && aapp init >/dev/null 2>&1)
(cd "$PROJ_60" && aapp draft archive-test >/dev/null 2>&1)
plan_60="$(compgen -G "$PROJ_60/.plans/current/P*-archive-test.md" | head -n 1)"
bname_60="$(basename "$plan_60")"
sed -i 's/^### 📂 Target Files/### 📂 Target Files\n* `dummy.txt` - test file/' "$plan_60"
# Resolve the template's §5 question: freeze refuses it, and done archives only
# an in-development plan (#89), so every step must genuinely succeed.
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$plan_60"
(cd "$PROJ_60" && aapp freeze "$bname_60" >/dev/null 2>&1)
(cd "$PROJ_60" && aapp start "$bname_60" >/dev/null 2>&1)
(cd "$PROJ_60" && echo "data" > dummy.txt && echo "- dummy" >> CHANGELOG.md && git add dummy.txt CHANGELOG.md && aapp commit "feat: dummy commit" >/dev/null 2>&1)
(cd "$PROJ_60" && aapp done "$bname_60" >/dev/null 2>&1)
done_60="$PROJ_60/.plans/done/$bname_60"
if [ -f "$done_60" ] && \
   grep -qE '^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*[[:space:]]*✅[[:space:]]*Done' "$done_60" && \
   grep -q "Plan implementation completed and archived to done/" "$done_60"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp done: updates plan header status to Done and records archival in changelog" "PASS" "$got"

# Test 61: aapp install copies examples/ to $SHARE_DIR/examples/
PROJ_61="$R/t61_proj"; make_dummy_project "$PROJ_61"
HOME_61="$R/t61_home"; mkdir -p "$HOME_61"
INSTALLER_61="$R/t61_installer"; make_kit_clone "$INSTALLER_61"
mkdir -p "$HOME_61/.local/share/aapp-kit/examples/stale"
touch "$HOME_61/.local/share/aapp-kit/examples/stale/stale.txt"
(cd "$INSTALLER_61" && HOME="$HOME_61" XDG_DATA_HOME="$HOME_61/.local/share" ./aapp install >/dev/null 2>&1)
if [ -d "$HOME_61/.local/share/aapp-kit/examples" ] && \
   [ -f "$HOME_61/.local/share/aapp-kit/examples/plugins/hello-tool/run.sample" ] && \
   [ -f "$HOME_61/.local/share/aapp-kit/examples/hooks/registry.tsv.sample" ] && \
   [ ! -d "$HOME_61/.local/share/aapp-kit/examples/stale" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp install: preserves examples/ in SHARE_DIR and cleans stale samples" "PASS" "$got"

# Test 62: aapp init preserves zero-footprint isolation without .sample files
PROJ_62="$R/t62_proj"; make_dummy_project "$PROJ_62"
(cd "$PROJ_62" && aapp init >/dev/null 2>&1)
if [ ! -d "$PROJ_62/.agents/skills/hello-tool" ] && \
   [ ! -d "$PROJ_62/.agents/skills/aapp-planid" ] && \
   ! compgen -G "$PROJ_62/.agents/skills/*.sample" >/dev/null; then
  got="PASS"
else
  got="FAIL"
fi
report "drop-in zero-footprint: aapp init leaves .agents/skills/ free of sample files" "PASS" "$got"

# Test 63: aapp init wires .githooks symlinks in .plans and .agents worktrees
PROJ_63="$R/t63_proj"; make_dummy_project "$PROJ_63"
(cd "$PROJ_63" && aapp init >/dev/null 2>&1)
if [ -L "$PROJ_63/.plans/.githooks" ] && \
   [ "$(readlink "$PROJ_63/.plans/.githooks")" = "../.githooks" ] && \
   [ -L "$PROJ_63/.agents/.githooks" ] && \
   [ "$(readlink "$PROJ_63/.agents/.githooks")" = "../.githooks" ] && \
   grep -qE '^\.githooks' "$PROJ_63/.plans/.gitignore" && \
   grep -qE '^\.githooks' "$PROJ_63/.agents/.gitignore"; then
  got="PASS"
else
  got="FAIL"
fi
report "worktree hooks: aapp init wires .githooks symlinks and ignores them in .plans/.agents" "PASS" "$got"

# Test 64: aapp test list lists discovered test suites without executing them
list_out=$("$KIT/aapp" test list 2>&1 || true)
if echo "$list_out" | grep -q "Available AAPP Test Suites" && \
   echo "$list_out" | grep -q "hooks_test.sh" && \
   echo "$list_out" | grep -q "install_test.sh"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp test: list mode discovers all suites without executing them" "PASS" "$got"

# Test 65: aapp test quiet [filter] runs targeted suite and aggregates assertions
filter_out=$("$KIT/aapp" test quiet matrix 2>&1 || true)
if echo "$filter_out" | grep -q "1 suites selected" && \
   echo "$filter_out" | grep -q "matrix_test.sh" && \
   echo "$filter_out" | grep -q "Test Summary: 1/1 suites passed"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp test: selective filtering runs targeted suite with aggregated metrics" "PASS" "$got"

# Test 66: aapp test in adopter repository falls back to protocol health audit
PROJ_66="$R/t66_proj"; make_dummy_project "$PROJ_66"
(cd "$PROJ_66" && aapp init >/dev/null 2>&1)
audit_out=$(cd "$PROJ_66" && aapp test 2>&1 || true)
if echo "$audit_out" | grep -q "Executing AAPP Protocol Environment Health Audit" && \
   echo "$audit_out" | grep -q "Worktree '.plans' mounted" && \
   echo "$audit_out" | grep -q "AAPP protocol environment is healthy"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp test: adopter repository fallback executes protocol health audit" "PASS" "$got"

echo "== 9. Front-Door Git Repository Assertion (P-33) =="

# Test 67 (test_non_repo_failure): operational verbs must fail closed outside a git repository.
# A non-git sandbox is built under $R, which is itself outside any repository (mktemp -d).
NONGIT_67="$R/t67_nongit"; mkdir -p "$NONGIT_67"
nonrepo_fail=0; nonrepo_details=""
for verb in status plan test freeze ai-status init; do
  # shellcheck disable=SC2086
  verb_out=$(cd "$NONGIT_67" && HOME="$TEST_HOME" "$KIT/aapp" $verb 2>&1); verb_rc=$?
  if [ "$verb_rc" -ne 1 ]; then
    nonrepo_fail=1; nonrepo_details="$nonrepo_details\n  '$verb' exit $verb_rc (want 1)"
  fi
  if ! echo "$verb_out" | grep -q "must be run inside a Git repository"; then
    nonrepo_fail=1; nonrepo_details="$nonrepo_details\n  '$verb' stderr missing diagnostic"
  fi
done
[ "$nonrepo_fail" -eq 0 ] && got="PASS" || got="FAIL"
report "test_non_repo_failure: operational verbs exit 1 with diagnostic outside a repo" "PASS" "$got" "$(printf '%b' "$nonrepo_details")"

# Test 68 (test_exempt_verbs_succeed): exempt verbs must still work outside a git repository.
NONGIT_68="$R/t68_nongit"; mkdir -p "$NONGIT_68"
INSTALL_HOME_68="$R/t68_home"; mkdir -p "$INSTALL_HOME_68"
exempt_fail=0; exempt_details=""
for verb in version help; do
  verb_out=$(cd "$NONGIT_68" && HOME="$TEST_HOME" "$KIT/aapp" "$verb" 2>&1); verb_rc=$?
  if [ "$verb_rc" -ne 0 ]; then
    exempt_fail=1; exempt_details="$exempt_details\n  '$verb' exit $verb_rc (want 0)"
  fi
done
# 'install' writes into HOME, so it is exercised against an isolated throwaway HOME.
install_out=$(cd "$NONGIT_68" && HOME="$INSTALL_HOME_68" "$KIT/aapp" install 2>&1); install_rc=$?
if [ "$install_rc" -ne 0 ]; then
  exempt_fail=1; exempt_details="$exempt_details\n  'install' exit $install_rc (want 0)"
fi
[ "$exempt_fail" -eq 0 ] && got="PASS" || got="FAIL"
report "test_exempt_verbs_succeed: exempt verbs exit 0 outside a repo" "PASS" "$got" "$(printf '%b' "$exempt_details")"

# Test 69 (test_init_defaults_to_none): fresh aapp init seeds none; an existing value is kept
PROJ_69="$R/t69_proj"; make_dummy_project "$PROJ_69"
(cd "$PROJ_69" && aapp init >/dev/null 2>&1)
seeded_mode=$(git -C "$PROJ_69" config aapp.aiAttribution 2>/dev/null || echo "")

PROJ_69B="$R/t69b_proj"; make_dummy_project "$PROJ_69B"
git -C "$PROJ_69B" config aapp.aiAttribution "notes"
(cd "$PROJ_69B" && aapp init >/dev/null 2>&1)
preserved_mode=$(git -C "$PROJ_69B" config aapp.aiAttribution 2>/dev/null || echo "")

if [ "$seeded_mode" = "none" ] && [ "$preserved_mode" = "notes" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "test_init_defaults_to_none: fresh aapp init seeds none and keeps existing value" "PASS" "$got" "seeded=$seeded_mode (want none), preserved=$preserved_mode (want notes)"

# Test 69c (P-48): init adds the CHANGELOG union-merge line once, keeps existing
# .gitattributes lines, and seeds aapp.changelogMode=plan only when absent.
PROJ_69C="$R/t69c_proj"; make_dummy_project "$PROJ_69C"
printf '*.png binary\n' > "$PROJ_69C/.gitattributes"
git -C "$PROJ_69C" config aapp.changelogMode commit
(cd "$PROJ_69C" && aapp init >/dev/null 2>&1 && aapp init >/dev/null 2>&1)
union_lines=$(grep -cx 'CHANGELOG.md merge=union' "$PROJ_69C/.gitattributes")
kept_line=$(grep -cx '\*.png binary' "$PROJ_69C/.gitattributes")
kept_mode=$(git -C "$PROJ_69C" config aapp.changelogMode)
PROJ_69D="$R/t69d_proj"; make_dummy_project "$PROJ_69D"
(cd "$PROJ_69D" && aapp init >/dev/null 2>&1)
seeded_cl_mode=$(git -C "$PROJ_69D" config aapp.changelogMode)
if [ "$union_lines" = "1" ] && [ "$kept_line" = "1" ] && [ "$kept_mode" = "commit" ] && [ "$seeded_cl_mode" = "plan" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "test_init_changelog_union_and_mode: union line once, lines kept, mode seeded only when absent" "PASS" "$got" "union=$union_lines kept=$kept_line kept_mode=$kept_mode seeded=$seeded_cl_mode"

# Test 70: CLI-First Universal Skills Alignment (TDD Failure & Boundary Assertions)
# Assert that templates/skills/{aapp-done, aapp-freeze, aapp-start, aapp-status, aapp-digest} follow CLI-first execution
# and do NOT contain manual sed -i, mv, or raw git commits bypassing CLI lifecycle gates.

# 70.1 test_skills_cli_first_done
done_skill="$KIT/templates/skills/aapp-done/SKILL.md"
if grep -q "aapp done" "$done_skill" && \
   ! grep -q "sed -i" "$done_skill" && \
   ! grep -q "mv \".plans/current" "$done_skill" && \
   ! grep -q "git -C .plans commit" "$done_skill"; then
  got="PASS"
else
  got="FAIL"
fi
report "test_skills_cli_first_done: aapp-done executes 'aapp done' without manual git surgery or sed" "PASS" "$got"

# 70.2 test_skills_cli_first_freeze
freeze_skill="$KIT/templates/skills/aapp-freeze/SKILL.md"
if grep -q "aapp freeze" "$freeze_skill" && \
   ! grep -q "sed -i" "$freeze_skill" && \
   ! grep -q "git -C .plans commit" "$freeze_skill"; then
  got="PASS"
else
  got="FAIL"
fi
report "test_skills_cli_first_freeze: aapp-freeze executes 'aapp freeze' without manual git surgery or sed" "PASS" "$got"

# 70.3 test_skills_cli_first_start
start_skill="$KIT/templates/skills/aapp-start/SKILL.md"
if grep -q "aapp start" "$start_skill" && \
   ! grep -q 'echo "<plan-id>" >' "$start_skill" && \
   ! grep -q "git -C .plans commit" "$start_skill"; then
  got="PASS"
else
  got="FAIL"
fi
report "test_skills_cli_first_start: aapp-start executes 'aapp start' without direct buffer writes or git surgery" "PASS" "$got"

# 70.4 test_skills_cli_first_status
status_skill="$KIT/templates/skills/aapp-status/SKILL.md"
if grep -q "aapp status" "$status_skill"; then
  got="PASS"
else
  got="FAIL"
fi
report "test_skills_cli_first_status: aapp-status delegates to 'aapp status'" "PASS" "$got"

# 70.5 test_skills_cli_first_digest
digest_skill="$KIT/templates/skills/aapp-digest/SKILL.md"
if grep -q "aapp draft" "$digest_skill"; then
  got="PASS"
else
  got="FAIL"
fi
report "test_skills_cli_first_digest: aapp-digest delegates scaffolding to 'aapp draft'" "PASS" "$got"

echo ""
echo "============================================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================================"
[ $FAIL -eq 0 ] || exit 1



