#!/usr/bin/env bash
# Regression harness for unified aapp CLI workflow (v1.0.0)
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT

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

echo "== 2. Drop-in Mode: Base & Target Resolution =="

TEST_HOME="$R/test_home"; mkdir -p "$TEST_HOME"

# Test 3: ./aapp-kit/aapp init from project root targets project
PROJ="$R/t3_proj"; make_dummy_project "$PROJ"
make_kit_clone "$PROJ/aapp-kit"
(
  cd "$PROJ"
  HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1
)
rc=$?
if [ $rc -eq 0 ] && [ -d "$PROJ/.plans" ] && [ -d "$PROJ/.agents" ] && [ -d "$PROJ/.githooks" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "drop-in: ./aapp-kit/aapp init from project root targets project" "PASS" "$got"

# Test 4: cd aapp-kit && ./aapp init targets the project, not the clone
PROJ="$R/t4_proj"; make_dummy_project "$PROJ"
make_kit_clone "$PROJ/aapp-kit"
(
  cd "$PROJ/aapp-kit"
  HOME="$TEST_HOME" ./aapp init >/dev/null 2>&1
)
rc=$?
if [ $rc -eq 0 ] && [ -d "$PROJ/.plans" ] && [ -d "$PROJ/.agents" ] && [ -d "$PROJ/.githooks" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "drop-in: cd aapp-kit && ./aapp init targets project (not clone)" "PASS" "$got"

# Test 5: nested at tools/aapp-kit resolves to project root
PROJ="$R/t5_proj"; make_dummy_project "$PROJ"
mkdir -p "$PROJ/tools"
make_kit_clone "$PROJ/tools/aapp-kit"
(
  cd "$PROJ"
  HOME="$TEST_HOME" ./tools/aapp-kit/aapp init >/dev/null 2>&1
)
rc=$?
if [ $rc -eq 0 ] && [ -d "$PROJ/.plans" ] && [ -d "$PROJ/.agents" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "drop-in: nested tools/aapp-kit resolves to project root" "PASS" "$got"

# Test 6: drop-in consumes aapp-kit/ on success
PROJ="$R/t6_proj"; make_dummy_project "$PROJ"
make_kit_clone "$PROJ/aapp-kit"
(
  cd "$PROJ"
  HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1
)
rc=$?
if [ $rc -eq 0 ] && [ ! -d "$PROJ/aapp-kit" ] && [ -f "$PROJ/CODEMAP.md" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "drop-in: aapp-kit/ consumed automatically on success" "PASS" "$got"

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
make_kit_clone "$PROJ/aapp-kit"
out_t7=$(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init 2>&1)
if grep -q "# Custom Project Rules (No Markers)" "$PROJ/.agents/AGENTS.md" && \
   grep -q "rule 1: always write tests" "$PROJ/.agents/AGENTS.md" && \
   grep -q "<!-- AAPP-PROTOCOL:START v1.0.0 -->" "$PROJ/.agents/AGENTS.md" && \
   grep -q "<!-- AAPP-PROTOCOL:END -->" "$PROJ/.agents/AGENTS.md"; then
  got="PASS"
else
  got="FAIL"
fi
report "adoption: existing rules without markers get AAPP block appended" "PASS" "$got"

# Test 8: Upgrade: existing .agents/AGENTS.md with markers has block swapped, surrounding rules intact
PROJ="$R/t8_proj"; make_dummy_project "$PROJ"
(
  cd "$PROJ"
  git checkout --orphan agents -q
  git rm -rf . -q 2>/dev/null || true
  cat > AGENTS.md <<'EOF'
# Header Rule 1

<!-- AAPP-PROTOCOL:START v0.8.0 -->
old protocol version 0.8.0 content
<!-- AAPP-PROTOCOL:END -->

# Footer Rule 2
Custom user footer rule that must never be deleted.
EOF
  git add AGENTS.md
  git commit -qm "old version agents branch"
  git checkout main -q
)
make_kit_clone "$PROJ/aapp-kit"
out_t8=$(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init 2>&1)
if grep -q "# Header Rule 1" "$PROJ/.agents/AGENTS.md" && \
   grep -q "# Footer Rule 2" "$PROJ/.agents/AGENTS.md" && \
   grep -q "Custom user footer rule that must never be deleted." "$PROJ/.agents/AGENTS.md" && \
   grep -q "<!-- AAPP-PROTOCOL:START v1.0.0 -->" "$PROJ/.agents/AGENTS.md" && \
   ! grep -q "old protocol version 0.8.0 content" "$PROJ/.agents/AGENTS.md"; then
  got="PASS"
else
  got="FAIL"
fi
report "upgrade: delimited block swapped in-place, header and footer rules intact" "PASS" "$got"

# Test 9: Legacy flat AGENTS.md at repo root migrated into .agents/AGENTS.md
PROJ="$R/t9_proj"; make_dummy_project "$PROJ"
echo "# Legacy Root AGENTS File" > "$PROJ/AGENTS.md"
make_kit_clone "$PROJ/aapp-kit"
out_t9=$(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init 2>&1)
if [ ! -f "$PROJ/AGENTS.md" ] && \
   [ -f "$PROJ/.agents/AGENTS.md" ] && \
   grep -q "# Legacy Root AGENTS File" "$PROJ/.agents/AGENTS.md" && \
   grep -q "<!-- AAPP-PROTOCOL:START v1.0.0 -->" "$PROJ/.agents/AGENTS.md"; then
  got="PASS"
else
  got="FAIL"
fi
report "migration: legacy flat AGENTS.md migrated into .agents/ worktree" "PASS" "$got"

# Test 10: Existing project root anchors (CODEMAP, ARCHITECTURE, etc.) preserved
PROJ="$R/t10_proj"; make_dummy_project "$PROJ"
echo "# User Custom CODEMAP" > "$PROJ/CODEMAP.md"
echo "# User Custom ARCHITECTURE" > "$PROJ/ARCHITECTURE.md"
make_kit_clone "$PROJ/aapp-kit"
(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
if [ "$(cat "$PROJ/CODEMAP.md")" = "# User Custom CODEMAP" ] && \
   [ "$(cat "$PROJ/ARCHITECTURE.md")" = "# User Custom ARCHITECTURE" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "project root anchors (CODEMAP, ARCHITECTURE) preserved untouched" "PASS" "$got"

echo "== 4. Core Infrastructure & Claude Settings =="

# Test 11: .githooks/pre-commit and .githooks/blast-radius-guard overwritten and +x
PROJ="$R/t11_proj"; make_dummy_project "$PROJ"
(
  cd "$PROJ"
  git checkout --orphan githooks -q
  git rm -rf . -q 2>/dev/null || true
  echo "# old hook" > pre-commit
  echo "# old guard" > blast-radius-guard
  git add .
  git commit -qm "old hooks branch"
  git checkout main -q
)
make_kit_clone "$PROJ/aapp-kit"
(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
if [ -x "$PROJ/.githooks/pre-commit" ] && \
   [ -x "$PROJ/.githooks/blast-radius-guard" ] && \
   grep -q "AAPP" "$PROJ/.githooks/pre-commit" && \
   ! grep -q "# old hook" "$PROJ/.githooks/pre-commit"; then
  got="PASS"
else
  got="FAIL"
fi
report "deterministic infrastructure sync: hooks overwritten and chmod +x" "PASS" "$got"

# Test 12: Fresh install writes .claude/settings.json
PROJ="$R/t12_proj"; make_dummy_project "$PROJ"
make_kit_clone "$PROJ/aapp-kit"
(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
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
make_kit_clone "$PROJ/aapp-kit"
(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
if grep -q '"userCustomSetting": true' "$PROJ/.claude/settings.json" && \
   grep -q "blast-radius-guard" "$PROJ/.claude/settings.json" && \
   grep -q "PostToolUse" "$PROJ/.claude/settings.json"; then
  got="PASS"
else
  got="FAIL"
fi
report "non-destructive merge: preserves existing .claude/settings.json keys" "PASS" "$got"

# Test 14: Idempotent .claude/settings.json (no duplicated hooks)
(cd "$PROJ" && HOME="$TEST_HOME" "$KIT/aapp" init >/dev/null 2>&1 || true)
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
make_kit_clone "$PROJ/aapp-kit"
out_t15=$(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init 2>&1)
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
make_kit_clone "$PROJ/aapp-kit"
out_t16=$(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init 2>&1)
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
make_kit_clone "$PROJ/aapp-kit"
out_t17=$(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init 2>&1)
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
make_kit_clone "$PROJ/aapp-kit"
out_t18=$(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init 2>&1)
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
make_kit_clone "$PROJ/aapp-kit"
(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
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

echo "== 6. Error Cases & Collision Protections =="

# Test 20: drop-in with no parent repo -> "Did you mean ./aapp-kit/aapp install ?"
BARE_DIR="$R/t20_bare"; mkdir -p "$BARE_DIR"
make_kit_clone "$BARE_DIR/aapp-kit"
out_t20=$(cd "$BARE_DIR" && HOME="$TEST_HOME" ./aapp-kit/aapp init 2>&1 || true)
if echo "$out_t20" | grep -q "Did you mean ./aapp-kit/aapp install ?"; then
  got="PASS"
else
  got="FAIL"
fi
report "drop-in with no parent repo prints 'aapp install' suggestion" "PASS" "$got" "$out_t20"

# Test 21: project's own templates/ directory is preserved untouched
PROJ="$R/t21_proj"; make_dummy_project "$PROJ"
mkdir -p "$PROJ/templates"
echo "<h1>Flask App</h1>" > "$PROJ/templates/index.html"
make_kit_clone "$PROJ/aapp-kit"
(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
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
make_kit_clone "$PROJ/aapp-kit"
out_t22=$(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init 2>&1 || true)
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
make_kit_clone "$PROJ_LOCAL/aapp-kit"
out_t23=$(cd "$PROJ_LOCAL" && HOME="$TEST_HOME" ./aapp-kit/aapp init 2>&1)
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

# Test 25: aapp install consumes installer clone folder on success
if [ ! -d "$INSTALLER_DIR" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp install consumes installer clone folder on success" "PASS" "$got"

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
make_kit_clone "$PROJ_31/aapp-kit"
(cd "$PROJ_31" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
out_status=$(cd "$PROJ_31" && "$KIT/aapp" status 2>&1)
if echo "$out_status" | grep -q "SHIPPED" && \
   echo "$out_status" | grep -q "ISSUES" && \
   echo "$out_status" | grep -q "PLANS" && \
   echo "$out_status" | grep -q "PICKUP QUEUE"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp status prints all 4 pillars of context recovery" "PASS" "$got" "$out_status"

echo ""
echo "============================================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================================"
[ $FAIL -eq 0 ] || exit 1
