#!/usr/bin/env bash
# Regression harness for aapp-init and aapp-install distribution workflow
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT

report() {
  local name="$1" expect="$2" got="$3" details="${4:-}"
  if [ "$got" = "$expect" ]; then
    printf "  \033[32m✔\033[0m %-60s %s\n" "$name" "$got"; PASS=$((PASS+1))
  else
    printf "  \033[31m✘\033[0m %-60s want %s got %s\n" "$name" "$expect" "$got"; FAIL=$((FAIL+1))
    [ -n "$details" ] && echo "$details" | sed 's/^/       /'
  fi
}

make_kit_clone() {
  local target_dir="$1"
  mkdir -p "$target_dir"
  cp "$KIT/aapp-init" "$KIT/aapp-install" "$target_dir/"
  chmod +x "$target_dir/aapp-init" "$target_dir/aapp-install"
  cp -r "$KIT/templates" "$target_dir/"
  [ -d "$KIT/tests" ] && cp -r "$KIT/tests" "$target_dir/"
  (
    cd "$target_dir"
    git init -q .
    git config user.email t@t; git config user.name T
    git config commit.gpgsign false; git config tag.gpgsign false
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
    git config user.email t@t; git config user.name T
    git config commit.gpgsign false; git config tag.gpgsign false
    echo "print('hello')" > main.py
    git add main.py
    git commit -qm "initial commit"
  )
}

echo "== 1. Drop-in Mode: Base & Target Resolution =="

# Test 1: ./aapp-kit/aapp-init from project root targets project
TEST_HOME="$R/t1_home"; mkdir -p "$TEST_HOME"
PROJ="$R/t1_proj"; make_dummy_project "$PROJ"
make_kit_clone "$PROJ/aapp-kit"
(
  cd "$PROJ"
  HOME="$TEST_HOME" ./aapp-kit/aapp-init >/dev/null 2>&1
)
rc=$?
if [ $rc -eq 0 ] && [ -d "$PROJ/.plans" ] && [ -d "$PROJ/.agents" ] && [ -d "$PROJ/.githooks" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "drop-in: ./aapp-kit/aapp-init from project root targets project" "PASS" "$got"

# Test 2: cd aapp-kit && ./aapp-init targets the project, not the clone
PROJ="$R/t2_proj"; make_dummy_project "$PROJ"
make_kit_clone "$PROJ/aapp-kit"
(
  cd "$PROJ/aapp-kit"
  HOME="$TEST_HOME" ./aapp-init >/dev/null 2>&1
)
rc=$?
if [ $rc -eq 0 ] && [ -d "$PROJ/.plans" ] && [ -d "$PROJ/.agents" ] && [ -d "$PROJ/.githooks" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "drop-in: cd aapp-kit && ./aapp-init targets project (not clone)" "PASS" "$got"

# Test 3: nested at tools/aapp-kit resolves to project root
PROJ="$R/t3_proj"; make_dummy_project "$PROJ"
mkdir -p "$PROJ/tools"
make_kit_clone "$PROJ/tools/aapp-kit"
(
  cd "$PROJ"
  HOME="$TEST_HOME" ./tools/aapp-kit/aapp-init >/dev/null 2>&1
)
rc=$?
if [ $rc -eq 0 ] && [ -d "$PROJ/.plans" ] && [ -d "$PROJ/.agents" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "drop-in: nested tools/aapp-kit resolves to project root" "PASS" "$got"

# Test 4: drop-in, no conflicts: aapp-kit/ is gone afterwards; workflow enforces
PROJ="$R/t4_proj"; make_dummy_project "$PROJ"
make_kit_clone "$PROJ/aapp-kit"
(
  cd "$PROJ"
  HOME="$TEST_HOME" ./aapp-kit/aapp-init >/dev/null 2>&1
)
rc=$?
if [ $rc -eq 0 ] && [ ! -d "$PROJ/aapp-kit" ] && [ -f "$PROJ/CODEMAP.md" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "drop-in no conflicts: aapp-kit/ consumed on success" "PASS" "$got"

echo "== 2. Drop-in Mode: Conflicts, Warnings, and Cleanup =="

# Test 5: drop-in, a file skipped: aapp-kit/ kept and warning names template
PROJ="$R/t5_proj"; make_dummy_project "$PROJ"
echo "# Custom CODEMAP" > "$PROJ/CODEMAP.md"
make_kit_clone "$PROJ/aapp-kit"
out=$(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp-init 2>&1)
rc=$?
if [ $rc -eq 0 ] && [ -d "$PROJ/aapp-kit" ] && echo "$out" | grep -q "These files already existed" && echo "$out" | grep -q "CODEMAP.md"; then
  got="PASS"
else
  got="FAIL"
fi
report "drop-in with conflict: aapp-kit/ kept and warning printed" "PASS" "$got" "$out"

# Test 6: --cleanup removes the folder and touches nothing else
out_cleanup=$(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp-init --cleanup 2>&1)
rc_cleanup=$?
if [ $rc_cleanup -eq 0 ] && [ ! -d "$PROJ/aapp-kit" ] && [ -d "$PROJ/.plans" ] && [ -f "$PROJ/CODEMAP.md" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "--cleanup removes kit folder and touches nothing else" "PASS" "$got" "$out_cleanup"

# Test 7: --cleanup on an already-clean project is a harmless no-op
out_noop=$(cd "$PROJ" && HOME="$TEST_HOME" "$KIT/aapp-init" --cleanup 2>&1)
rc_noop=$?
if [ $rc_noop -eq 0 ] && echo "$out_noop" | grep -q "No aapp-kit directory found"; then
  got="PASS"
else
  got="FAIL"
fi
report "--cleanup on clean project is a harmless no-op" "PASS" "$got" "$out_noop"

# Test 8: existing AGENTS.md / CODEMAP.md kept and skipped
PROJ="$R/t8_proj"; make_dummy_project "$PROJ"
echo "# User AGENTS" > "$PROJ/AGENTS.md"
echo "# User CODEMAP" > "$PROJ/CODEMAP.md"
make_kit_clone "$PROJ/aapp-kit"
out=$(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp-init 2>&1)
rc=$?
content_agents=$(cat "$PROJ/AGENTS.md")
content_codemap=$(cat "$PROJ/CODEMAP.md")
if [ $rc -eq 0 ] && [ "$content_agents" = "# User AGENTS" ] && [ "$content_codemap" = "# User CODEMAP" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "existing AGENTS.md and CODEMAP.md preserved untouched" "PASS" "$got"

# Test 9: warning block appears before success banner & exit code is 0
if [ $rc -eq 0 ] && echo "$out" | grep -B 10 "Multi-Orphan Worktree Setup Complete!" | grep -q "These files already existed"; then
  got="PASS"
else
  got="FAIL"
fi
report "warning block appears before success banner with exit 0" "PASS" "$got" "$out"

# Test 10: clean project skips nothing and prints no warning block
PROJ="$R/t10_proj"; make_dummy_project "$PROJ"
make_kit_clone "$PROJ/aapp-kit"
out=$(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp-init 2>&1)
if echo "$out" | grep -q "These files already existed"; then
  got="WARN_PRINTED"
else
  got="PASS"
fi
report "clean project skips nothing and prints no warning block" "PASS" "$got" "$out"

echo "== 3. Git Hooks & Hook Manager Interoperability =="

# Test 11: core.hooksPath unset -> set to .githooks, no warning
PROJ="$R/t11_proj"; make_dummy_project "$PROJ"
make_kit_clone "$PROJ/aapp-kit"
out=$(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp-init 2>&1)
hooks_path=$(cd "$PROJ" && git config --get core.hooksPath || true)
if [ "$hooks_path" = ".githooks" ] && ! echo "$out" | grep -q "existing hook configuration was detected"; then
  got="PASS"
else
  got="FAIL"
fi
report "core.hooksPath unset -> set to .githooks with no warning" "PASS" "$got"

# Test 12: core.hooksPath already .githooks -> idempotent re-run, no warning
PROJ="$R/t12_proj"; make_dummy_project "$PROJ"
(cd "$PROJ" && git config core.hooksPath .githooks)
make_kit_clone "$PROJ/aapp-kit"
out=$(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp-init 2>&1)
hooks_path=$(cd "$PROJ" && git config --get core.hooksPath || true)
if [ "$hooks_path" = ".githooks" ] && ! echo "$out" | grep -q "existing hook configuration was detected"; then
  got="PASS"
else
  got="FAIL"
fi
report "core.hooksPath already .githooks -> unchanged, no warning" "PASS" "$got"

# Test 13: core.hooksPath=.husky -> hooks installed, config untouched, wiring printed
PROJ="$R/t13_proj"; make_dummy_project "$PROJ"
(cd "$PROJ" && git config core.hooksPath .husky)
make_kit_clone "$PROJ/aapp-kit"
out=$(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp-init 2>&1)
hooks_path=$(cd "$PROJ" && git config --get core.hooksPath || true)
if [ "$hooks_path" = ".husky" ] && [ -f "$PROJ/.githooks/pre-commit" ] && echo "$out" | grep -q "core.hooksPath is currently set to: '.husky'"; then
  got="PASS"
else
  got="FAIL"
fi
report "core.hooksPath=.husky -> config untouched, wiring printed" "PASS" "$got" "$out"

# Test 14: executable .git/hooks/pre-commit -> config untouched, wiring printed
PROJ="$R/t14_proj"; make_dummy_project "$PROJ"
mkdir -p "$PROJ/.git/hooks"
echo "#!/bin/sh" > "$PROJ/.git/hooks/pre-commit"
chmod +x "$PROJ/.git/hooks/pre-commit"
make_kit_clone "$PROJ/aapp-kit"
out=$(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp-init 2>&1)
hooks_path=$(cd "$PROJ" && git config --get core.hooksPath || true)
if [ -z "$hooks_path" ] && echo "$out" | grep -q "Executable hook found at '.git/hooks/pre-commit'"; then
  got="PASS"
else
  got="FAIL"
fi
report "executable .git/hooks/pre-commit -> config untouched, wiring printed" "PASS" "$got" "$out"

# Test 15: wiring line in custom hook catches blast-radius violation
PROJ="$R/t15_proj"; make_dummy_project "$PROJ"
mkdir -p "$PROJ/.husky"
cat > "$PROJ/.husky/pre-commit" <<'EOF'
#!/bin/sh
"$(git rev-parse --show-toplevel)/.githooks/pre-commit" || exit 1
EOF
chmod +x "$PROJ/.husky/pre-commit"
(cd "$PROJ" && git config core.hooksPath .husky)
make_kit_clone "$PROJ/aapp-kit"
(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp-init >/dev/null 2>&1)
# Create plan targeting only a.py
mkdir -p "$PROJ/.plans/current"
cat > "$PROJ/.plans/current/plan.md" <<'EOF'
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

echo "== 4. Error Cases & Collision Protections =="

# Test 16: drop-in with no parent repo -> "did you mean aapp-install?"
BARE_DIR="$R/t16_bare"
mkdir -p "$BARE_DIR"
make_kit_clone "$BARE_DIR/aapp-kit"
out=$(cd "$BARE_DIR" && HOME="$TEST_HOME" ./aapp-kit/aapp-init 2>&1 || true)
if echo "$out" | grep -q "Did you mean ./aapp-kit/aapp-install ?"; then
  got="PASS"
else
  got="FAIL"
fi
report "drop-in with no parent repo prints aapp-install suggestion" "PASS" "$got" "$out"

# Test 17: Flask-style templates/ directory in project is never mistaken for kit or deleted
PROJ="$R/t17_proj"; make_dummy_project "$PROJ"
mkdir -p "$PROJ/templates"
echo "<h1>Flask App</h1>" > "$PROJ/templates/index.html"
make_kit_clone "$PROJ/aapp-kit"
(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp-init >/dev/null 2>&1)
if [ -f "$PROJ/templates/index.html" ]; then
  got="PASS"
else
  got="DELETED"
fi
report "project's own templates/ directory is preserved untouched" "PASS" "$got"

# Test 18: pre-existing non-worktree directory collision guard
PROJ="$R/t18_proj"; make_dummy_project "$PROJ"
mkdir -p "$PROJ/.plans"
echo "custom non-worktree content" > "$PROJ/.plans/custom.txt"
make_kit_clone "$PROJ/aapp-kit"
out=$(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp-init 2>&1 || true)
if echo "$out" | grep -q "exists as a normal directory, not an AAPP worktree"; then
  got="PASS"
else
  got="FAIL"
fi
report "existing flat non-worktree folder triggers collision guard" "PASS" "$got" "$out"

# Test 19: multi-machine restore: origin/plans tracking branch mounts cleanly
PROJ_REMOTE="$R/t19_remote"; make_dummy_project "$PROJ_REMOTE"
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
PROJ_LOCAL="$R/t19_local"
git clone -q "$PROJ_REMOTE" "$PROJ_LOCAL"
make_kit_clone "$PROJ_LOCAL/aapp-kit"
out=$(cd "$PROJ_LOCAL" && HOME="$TEST_HOME" ./aapp-kit/aapp-init 2>&1)
rc=$?
if [ $rc -eq 0 ] && [ -f "$PROJ_LOCAL/.plans/current/p.md" ] && echo "$out" | grep -q "Existing AAPP project restored"; then
  got="PASS"
else
  got="FAIL"
fi
report "multi-machine restore: mounts origin tracking branch without conflict" "PASS" "$got" "$out"

echo "== 5. Global Installer (aapp-install) & Global aapp-init =="

# Test 20: install succeeds when ~/.local/bin and ~/.local/share do not exist
GLOBAL_HOME="$R/t20_home"
mkdir -p "$GLOBAL_HOME"
INSTALLER_DIR="$R/t20_installer"
make_kit_clone "$INSTALLER_DIR"
(
  cd "$INSTALLER_DIR"
  HOME="$GLOBAL_HOME" XDG_DATA_HOME="$GLOBAL_HOME/.local/share" ./aapp-install >/dev/null 2>&1
)
rc=$?
if [ $rc -eq 0 ] && [ -x "$GLOBAL_HOME/.local/bin/aapp-init" ] && [ -x "$GLOBAL_HOME/.local/bin/aapp-install" ] && [ -f "$GLOBAL_HOME/.local/share/aapp-kit/templates/pre-commit" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp-install creates ~/.local/bin and share dir when missing" "PASS" "$got"

# Test 21: aapp-install removes installer clone folder
if [ ! -d "$INSTALLER_DIR" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp-install consumes installer clone folder on success" "PASS" "$got"

# Test 22: tests/ reachable from installed share dir
if [ -d "$GLOBAL_HOME/.local/share/aapp-kit/tests" ] && [ -f "$GLOBAL_HOME/.local/share/aapp-kit/tests/pre-commit_test.sh" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "tests/ reachable in installed share directory" "PASS" "$got"

# Test 23: installed mode aapp-init targets cwd repo and deletes nothing
PROJ="$R/t23_proj"; make_dummy_project "$PROJ"
(
  cd "$PROJ"
  PATH="$GLOBAL_HOME/.local/bin:$PATH" HOME="$GLOBAL_HOME" XDG_DATA_HOME="$GLOBAL_HOME/.local/share" aapp-init >/dev/null 2>&1
)
rc=$?
if [ $rc -eq 0 ] && [ -d "$PROJ/.plans" ] && [ -d "$PROJ/.agents" ] && [ -x "$GLOBAL_HOME/.local/bin/aapp-init" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "installed mode aapp-init targets cwd repo and deletes nothing" "PASS" "$got"

# Test 24: PATH detection: already present -> no edit
out_path=$(
  cd "$GLOBAL_HOME"
  PATH="$GLOBAL_HOME/.local/bin:$PATH" HOME="$GLOBAL_HOME" XDG_DATA_HOME="$GLOBAL_HOME/.local/share" make_kit_clone "$R/t24_kit"
  cd "$R/t24_kit"
  PATH="$GLOBAL_HOME/.local/bin:$PATH" HOME="$GLOBAL_HOME" XDG_DATA_HOME="$GLOBAL_HOME/.local/share" ./aapp-install 2>&1
)
if echo "$out_path" | grep -q "is already in your PATH"; then
  got="PASS"
else
  got="FAIL"
fi
report "PATH detection: already present -> no edit, report ok" "PASS" "$got" "$out_path"

# Test 25: freshly-created ~/.local/bin advises re-login
NEW_HOME="$R/t25_home"; mkdir -p "$NEW_HOME"
INSTALLER_25="$R/t25_installer"; make_kit_clone "$INSTALLER_25"
out_fresh=$(
  cd "$INSTALLER_25"
  PATH="/usr/bin:/bin" HOME="$NEW_HOME" XDG_DATA_HOME="$NEW_HOME/.local/share" ./aapp-install 2>&1
)
if echo "$out_fresh" | grep -q "logging out and" && echo "$out_fresh" | grep -q "back in will automatically add it"; then
  got="PASS"
else
  got="FAIL"
fi
report "freshly-created ~/.local/bin -> advises re-login, edits nothing" "PASS" "$got" "$out_fresh"

# Test 26: --uninstall removes binaries and share data, leaves directories and PATH intact
UNINSTALL_HOME="$R/t26_home"; mkdir -p "$UNINSTALL_HOME"
touch "$UNINSTALL_HOME/.bashrc"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$UNINSTALL_HOME/.bashrc"
INSTALLER_26="$R/t26_installer"; make_kit_clone "$INSTALLER_26"
(
  cd "$INSTALLER_26"
  PATH="/usr/bin:/bin" HOME="$UNINSTALL_HOME" XDG_DATA_HOME="$UNINSTALL_HOME/.local/share" ./aapp-install >/dev/null 2>&1
)
out_uninst=$(
  PATH="/usr/bin:/bin" HOME="$UNINSTALL_HOME" XDG_DATA_HOME="$UNINSTALL_HOME/.local/share" "$UNINSTALL_HOME/.local/bin/aapp-install" --uninstall 2>&1
)
rc=$?
bashrc_content=$(cat "$UNINSTALL_HOME/.bashrc")
if [ $rc -eq 0 ] && \
   [ ! -f "$UNINSTALL_HOME/.local/bin/aapp-init" ] && \
   [ ! -f "$UNINSTALL_HOME/.local/bin/aapp-install" ] && \
   [ ! -d "$UNINSTALL_HOME/.local/share/aapp-kit" ] && \
   [ -d "$UNINSTALL_HOME/.local/bin" ] && \
   [ -d "$UNINSTALL_HOME/.local/share" ] && \
   [ "$bashrc_content" = 'export PATH="$HOME/.local/bin:$PATH"' ]; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp-install --uninstall leaves no trace of kit but preserves shared dirs and rc" "PASS" "$got" "$out_uninst"

# Test 27: Self-consumption protection when run in kit dev checkout
out_dev=$(
  cd "$KIT"
  HOME="$TEST_HOME" ./aapp-install 2>&1 || true
)
if [ -d "$KIT" ] && [ -f "$KIT/aapp-install" ]; then
  got="PASS"
else
  got="DELETED"
fi
report "running aapp-install inside dev repo preserves dev repo" "PASS" "$got"

echo ""
echo "============================================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================================"
[ $FAIL -eq 0 ] || exit 1
