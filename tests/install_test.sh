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
  [ -d "$KIT/examples" ] && cp -r "$KIT/examples" "$target_dir/"
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
if [ $rc -eq 0 ] && [ -d "$PROJ/.plans" ] && [ -d "$PROJ/.agents" ] && [ -d "$PROJ/.githooks" ] && [ -f "$PROJ/.plans/done/000-archive-ledger.md" ]; then
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
if [ $rc -eq 0 ] && [ ! -d "$PROJ/aapp-kit" ] && [ -f "$PROJ/.agents/CODEMAP.md" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "drop-in: aapp-kit/ consumed automatically on success" "PASS" "$got"

# Test 6b: ./agent-planning-kit/aapp init from project root targets project (#50)
PROJ="$R/t6b_proj"; make_dummy_project "$PROJ"
make_kit_clone "$PROJ/agent-planning-kit"
(
  cd "$PROJ"
  HOME="$TEST_HOME" ./agent-planning-kit/aapp init >/dev/null 2>&1
)
rc=$?
if [ $rc -eq 0 ] && [ -d "$PROJ/.plans" ] && [ -d "$PROJ/.agents" ] && [ -d "$PROJ/.githooks" ] && [ -d "$PROJ/agent-planning-kit" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "drop-in: ./agent-planning-kit/aapp init from project root targets project (#50)" "PASS" "$got"

# Test 6c: cd agent-planning-kit && ./aapp init targets kit itself (#50)
KIT_ONLY="$R/t6c_dir/agent-planning-kit"; make_kit_clone "$KIT_ONLY"
(
  cd "$KIT_ONLY"
  HOME="$TEST_HOME" ./aapp init >/dev/null 2>&1
)
rc=$?
if [ $rc -eq 0 ] && [ -d "$KIT_ONLY/.plans" ] && [ -d "$KIT_ONLY/.agents" ] && [ -d "$KIT_ONLY/.githooks" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "drop-in: cd agent-planning-kit && ./aapp init targets kit itself (#50)" "PASS" "$got"

# Test 6d: drop-in: ./aapp-kit/aapp init rejects unknown flag --keep (#51)
PROJ="$R/t6d_proj"; make_dummy_project "$PROJ"
make_kit_clone "$PROJ/aapp-kit"
out_6d=$(
  cd "$PROJ"
  HOME="$TEST_HOME" ./aapp-kit/aapp init --keep 2>&1 || true
)
if echo "$out_6d" | grep -q "Unknown option '--keep'" && [ -d "$PROJ/aapp-kit" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "drop-in: ./aapp-kit/aapp init rejects unknown flag --keep" "PASS" "$got"

# Test 6e: drop-in: extra file in aapp-kit/ preserves drop-in folder without self-consuming (#51)
PROJ="$R/t6e_proj"; make_dummy_project "$PROJ"
make_kit_clone "$PROJ/aapp-kit"
touch "$PROJ/aapp-kit/custom_notes.txt"
(
  cd "$PROJ"
  HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1
)
rc=$?
if [ $rc -eq 0 ] && [ -d "$PROJ/aapp-kit" ] && [ -f "$PROJ/aapp-kit/custom_notes.txt" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "drop-in: extra file in aapp-kit/ preserves folder without self-consuming (#51)" "PASS" "$got"

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
(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
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
make_kit_clone "$PROJ/aapp-kit"
(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
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
make_kit_clone "$PROJ/aapp-kit"
(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
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
make_kit_clone "$PROJ/aapp-kit"
(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
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
make_kit_clone "$PROJ/aapp-kit"
(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
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
make_kit_clone "$PROJ_33/aapp-kit"
(cd "$PROJ_33" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
# Intentionally corrupt .agents/AGENTS.md by removing END marker
cat > "$PROJ_33/.agents/AGENTS.md" <<'EOF'
# Custom Header
<!-- AAPP-PROTOCOL:START v1.0.0 -->
Some content that was not closed properly
# Important custom notes that must not be deleted
EOF
make_kit_clone "$PROJ_33/aapp-kit2"
out_corrupt=$(cd "$PROJ_33" && HOME="$TEST_HOME" ./aapp-kit2/aapp init 2>&1)
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
out_uninst_broken=$(
  PATH="/usr/bin:/bin" HOME="$DEV_HOME_36" XDG_DATA_HOME="$DEV_HOME_36/.local/share" "$KIT/aapp" uninstall 2>&1
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
make_kit_clone "$PROJ_37/aapp-kit"
(cd "$PROJ_37" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
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
for v in aapp-status aapp-digest aapp-freeze aapp-start aapp-done aapp-pause aapp-release aapp-plan plan; do
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
make_kit_clone "$PROJ_40/aapp-kit"
(cd "$PROJ_40" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
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
make_kit_clone "$PROJ_41/aapp-kit"
(cd "$PROJ_41" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
touch "$PROJ_41/.agents/skills/aapp-status/stale-old-file.txt"
make_kit_clone "$PROJ_41/aapp-kit"
(cd "$PROJ_41" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
if [ ! -f "$PROJ_41/.agents/skills/aapp-status/stale-old-file.txt" ] && \
   [ -f "$PROJ_41/.agents/skills/aapp-status/SKILL.md" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "clean upgrade: drops stale files on skill re-sync" "PASS" "$got"

# Test 42: Drift control: all governance skills declare valid frontmatter, flags, and inline/fork contracts
drift_ok=1
for v in aapp-status aapp-digest aapp-freeze aapp-start aapp-done aapp-pause aapp-release aapp-plan plan; do
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
make_kit_clone "$PROJ_43/aapp-kit"
(cd "$PROJ_43" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
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
make_kit_clone "$PROJ_44/aapp-kit"
init_out=$(cd "$PROJ_44" && HOME="$TEST_HOME" ./aapp-kit/aapp init 2>&1)
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
make_kit_clone "$PROJ/aapp-kit"
init_out=$(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init 2>&1)
if echo "$init_out" | grep -q "Experience Your First AAPP Loop" && \
   echo "$init_out" | grep -q "/aapp-digest Onboarding"; then
  got="PASS"
else
  got="FAIL"
fi
report "init banner: aapp init outputs First AAPP Loop onboarding guidance" "PASS" "$got"

# Test 50: aapp init syncs aapp-pause skill into .agents/skills and .claude/skills
PROJ="$R/t50_proj"; make_dummy_project "$PROJ"
make_kit_clone "$PROJ/aapp-kit"
(cd "$PROJ" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
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
make_kit_clone "$PROJ_52/aapp-kit"
(cd "$PROJ_52" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
mkdir -p "$PROJ_52/.agents/skills/aapp-freeze-start" "$PROJ_52/.claude/skills/aapp-freeze-start"
mkdir -p "$PROJ_52/.agents/skills/aapp-active" "$PROJ_52/.claude/skills/aapp-active"
touch "$PROJ_52/.agents/skills/aapp-freeze-start/SKILL.md" "$PROJ_52/.claude/skills/aapp-freeze-start/SKILL.md"
touch "$PROJ_52/.agents/skills/aapp-active/SKILL.md" "$PROJ_52/.claude/skills/aapp-active/SKILL.md"
touch "$PROJ_52/.agents/skills/aapp-hooks/SKILL.md"
mkdir -p "$PROJ_52/.claude/skills/aapp-hooks"
touch "$PROJ_52/.claude/skills/aapp-hooks/SKILL.md"
printf "on-sync\tcustom_handler.sh\tsha256:dummy\t10\tgate\n" > "$PROJ_52/.agents/skills/aapp-hooks/registry.tsv"
make_kit_clone "$PROJ_52/aapp-kit"
(cd "$PROJ_52" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
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
make_kit_clone "$PROJ_54/aapp-kit"
(cd "$PROJ_54" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
(cd "$PROJ_54" && HOME="$TEST_HOME" "$KIT/aapp" draft test-feature >/dev/null 2>&1)
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
make_kit_clone "$PROJ_55/aapp-kit"
(cd "$PROJ_55" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
echo "1. Automatic Backup System: Implement automated local backup" > "$PROJ_55/.plans/pickup.md"
(cd "$PROJ_55" && HOME="$TEST_HOME" "$KIT/aapp" draft </dev/null >/dev/null 2>&1)
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

# Test 57: aapp hooks --events prints lifecycle event catalog
events_out="$("$KIT/aapp" hooks --events 2>&1)"
if echo "$events_out" | grep -q "Supported Lifecycle Events Catalog" && \
   echo "$events_out" | grep -q "pre-freeze" && \
   echo "$events_out" | grep -q "on-sync" && \
   echo "$events_out" | grep -q "post-freeze"; then
  got="PASS"
else
  got="FAIL"
fi
report "hooks catalog: aapp hooks --events displays Pre/On/Post timing taxonomy" "PASS" "$got"

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
make_kit_clone "$PROJ_60/aapp-kit"
(cd "$PROJ_60" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
(cd "$PROJ_60" && HOME="$TEST_HOME" "$KIT/aapp" draft archive-test >/dev/null 2>&1)
plan_60="$(compgen -G "$PROJ_60/.plans/current/P*-archive-test.md" | head -n 1)"
bname_60="$(basename "$plan_60")"
sed -i 's/^### 📂 Target Files/### 📂 Target Files\n* `dummy.txt` - test file/' "$plan_60"
(cd "$PROJ_60" && HOME="$TEST_HOME" "$KIT/aapp" freeze "$bname_60" >/dev/null 2>&1)
(cd "$PROJ_60" && HOME="$TEST_HOME" "$KIT/aapp" start "$bname_60" >/dev/null 2>&1)
(cd "$PROJ_60" && HOME="$TEST_HOME" "$KIT/aapp" done "$bname_60" >/dev/null 2>&1)
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
(cd "$INSTALLER_61" && HOME="$HOME_61" ./aapp install >/dev/null 2>&1)
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
make_kit_clone "$PROJ_62/aapp-kit"
(cd "$PROJ_62" && HOME="$TEST_HOME" ./aapp-kit/aapp init >/dev/null 2>&1)
if [ ! -d "$PROJ_62/.agents/skills/hello-tool" ] && \
   [ ! -d "$PROJ_62/.agents/skills/aapp-planid" ] && \
   ! compgen -G "$PROJ_62/.agents/skills/*.sample" >/dev/null; then
  got="PASS"
else
  got="FAIL"
fi
report "drop-in zero-footprint: aapp init leaves .agents/skills/ free of sample files" "PASS" "$got"

echo ""
echo "============================================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================================"
[ $FAIL -eq 0 ] || exit 1

