#!/usr/bin/env bash
# ==============================================================================
# Automated Regression Test Suite: AAPP Remote Sync (Plan P-10)
# Covers:
#   - aapp init defaults seeding (aapp.remote, syncWorktrees, pullStrategy, syncStrategy)
#   - Pushing orphan worktrees to bare remotes (with upstream tracking setup)
#   - Pulling updates with strict --ff-only
#   - Bi-directional sync (pull then push)
#   - Pre-flight cleanliness abort when worktree is dirty
#   - Custom remote override (aapp push <remote>)
#   - Selective worktree syncing (aapp.syncWorktrees)
#   - Three-tier strategy resolution (CLI positional > local git config > committed registry)
#   - Missing-hook refusal (fail-closed invariant)
#   - on-sync transport hook delegation & Dual Delivery environment variables
# ==============================================================================
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
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
  (
    cd "$target_dir" || exit 1
    git init -q .
    setup_test_git_identity "$target_dir"
    git add . >/dev/null 2>&1
    git commit -qm "kit clone" >/dev/null 2>&1 || true
  )
}

make_project() {
  local proj_dir="$1"
  mkdir -p "$proj_dir"
  (
    cd "$proj_dir" || exit 1
    git init -q .
    setup_test_git_identity "$proj_dir"
    echo "print('hello')" > main.py
    git add main.py
    git commit -qm "initial commit"
  )
}

echo "============================================================"
echo "🧪 Running Test Suite: Remote Sync Automation (Plan P-10)"
echo "============================================================"

# Scaffolding: Kit named agent-planning-kit to prevent drop-in consumption
KIT_DIR="$R/agent-planning-kit"
make_kit_clone "$KIT_DIR"

PROJ_DIR="$R/proj1"
make_project "$PROJ_DIR"

REMOTE_ORIGIN="$R/origin.git"
git init --bare -q "$REMOTE_ORIGIN"

REMOTE_UPSTREAM="$R/upstream.git"
git init --bare -q "$REMOTE_UPSTREAM"

(
  cd "$PROJ_DIR" || exit 1
  git remote add origin "$REMOTE_ORIGIN"
  git remote add upstream "$REMOTE_UPSTREAM"
)

# ------------------------------------------------------------------------------
# Test 1: aapp init seeds config defaults
# ------------------------------------------------------------------------------
(
  cd "$PROJ_DIR" || exit 1
  "$KIT_DIR/aapp" init >/dev/null 2>&1
)

r_remote="$(git -C "$PROJ_DIR" config aapp.remote || echo "")"
r_wts="$(git -C "$PROJ_DIR" config aapp.syncWorktrees || echo "")"
r_pull="$(git -C "$PROJ_DIR" config aapp.pullStrategy || echo "")"
r_sync="$(git -C "$PROJ_DIR" config aapp.syncStrategy || echo "")"

if [ "$r_remote" = "origin" ] && [ "$r_wts" = "plans agents githooks" ] && [ "$r_pull" = "ff-only" ] && [ "$r_sync" = "builtin" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp init seeds safe-by-default sync configuration" "PASS" "$got" "remote=$r_remote wts=$r_wts pull=$r_pull sync=$r_sync"

# Commit initial worktree content so branches exist and can be pushed
(
  cd "$PROJ_DIR" || exit 1
  echo "test plan" > .plans/test.md
  git -C .plans add test.md
  git -C .plans commit -qm "add test plan"

  echo "test rule" > .agents/test.md
  git -C .agents add test.md
  git -C .agents commit -qm "add test rule"
)

# ------------------------------------------------------------------------------
# Test 2: aapp push pushes active worktrees and sets upstream tracking
# ------------------------------------------------------------------------------
push_out=""
push_code=0
push_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" push 2>&1)" || push_code=$?

if [ "$push_code" -eq 0 ] && echo "$push_out" | grep -q "All AAPP worktrees pushed successfully"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp push exports active worktrees to remote with upstream tracking" "PASS" "$got" "$push_out"

# Verify bare remote now contains branches 'plans' and 'agents'
has_plans="$(git -C "$REMOTE_ORIGIN" branch --list plans | tr -d ' *')"
has_agents="$(git -C "$REMOTE_ORIGIN" branch --list agents | tr -d ' *')"
if [ "$has_plans" = "plans" ] && [ "$has_agents" = "agents" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "origin bare remote contains pushed orphan branches" "PASS" "$got" "plans=$has_plans agents=$has_agents"

# Verify upstream tracking was configured on the worktrees
plans_u="$(git -C "$PROJ_DIR/.plans" rev-parse --abbrev-ref '@{u}' 2>/dev/null || echo "")"
if [ "$plans_u" = "origin/plans" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp push establishes upstream tracking for worktrees" "PASS" "$got" "upstream=$plans_u"

# ------------------------------------------------------------------------------
# Test 3: aapp pull with --ff-only brings updates
# ------------------------------------------------------------------------------
TMP_CLONE="$R/tmp_clone"
git clone -q "$REMOTE_ORIGIN" -b plans "$TMP_CLONE" >/dev/null 2>&1
(
  cd "$TMP_CLONE" || exit 1
  setup_test_git_identity "$TMP_CLONE"
  echo "updated from clone" >> test.md
  git commit -qam "update plan from remote"
  git push -q origin plans
)

pull_out=""
pull_code=0
pull_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" pull 2>&1)" || pull_code=$?

if [ "$pull_code" -eq 0 ] && grep -q "updated from clone" "$PROJ_DIR/.plans/test.md"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp pull pulls remote changes with strict --ff-only" "PASS" "$got" "$pull_out"

# ------------------------------------------------------------------------------
# Test 4: aapp sync performs bi-directional sync (pull then push)
# ------------------------------------------------------------------------------
# Add another update remotely
(
  cd "$TMP_CLONE" || exit 1
  echo "remote line 2" >> test.md
  git commit -qam "update remote line 2"
  git push -q origin plans
)
# Add local commit in .agents
(
  cd "$PROJ_DIR/.agents" || exit 1
  echo "local agent rule" >> test.md
  git commit -qam "local agent update"
)

sync_out=""
sync_code=0
sync_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" sync 2>&1)" || sync_code=$?

if [ "$sync_code" -eq 0 ] && grep -q "remote line 2" "$PROJ_DIR/.plans/test.md"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp sync performs bi-directional sync (pull then push)" "PASS" "$got" "$sync_out"

# ------------------------------------------------------------------------------
# Test 5: Pre-flight cleanliness check aborts pull & sync when dirty
# ------------------------------------------------------------------------------
echo "uncommitted dirty content" >> "$PROJ_DIR/.plans/test.md"

dirty_pull_out=""
dirty_pull_code=0
dirty_pull_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" pull 2>&1)" || dirty_pull_code=$?

if [ "$dirty_pull_code" -ne 0 ] && echo "$dirty_pull_out" | grep -q "Pre-flight check failed"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp pull aborts immediately when a worktree is dirty (pre-flight check)" "PASS" "$got" "$dirty_pull_out"

dirty_sync_out=""
dirty_sync_code=0
dirty_sync_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" sync 2>&1)" || dirty_sync_code=$?

if [ "$dirty_sync_code" -ne 0 ] && echo "$dirty_sync_out" | grep -q "Pre-flight check failed"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp sync aborts immediately when a worktree is dirty (pre-flight check)" "PASS" "$got" "$dirty_sync_out"

# Clean up dirty change
(cd "$PROJ_DIR/.plans" && git checkout -- test.md)

# ------------------------------------------------------------------------------
# Test 6: Custom remote override (aapp push upstream)
# ------------------------------------------------------------------------------
up_push_out=""
up_push_code=0
up_push_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" push upstream 2>&1)" || up_push_code=$?

has_upstream_plans="$(git -C "$REMOTE_UPSTREAM" branch --list plans | tr -d ' *')"
if [ "$up_push_code" -eq 0 ] && [ "$has_upstream_plans" = "plans" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp push [remote] pushes to specified custom remote" "PASS" "$got" "$up_push_out"

# ------------------------------------------------------------------------------
# Test 7: Selective worktree syncing (aapp.syncWorktrees)
# ------------------------------------------------------------------------------
(
  cd "$PROJ_DIR" || exit 1
  git config aapp.syncWorktrees "plans"
)

sel_push_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" push 2>&1)"
if echo "$sel_push_out" | grep -q "\.plans/" && ! echo "$sel_push_out" | grep -q "\.agents/"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp.syncWorktrees respects selective worktree filtering" "PASS" "$got" "$sel_push_out"

# Restore syncWorktrees
(cd "$PROJ_DIR" && git config aapp.syncWorktrees "plans agents githooks")

# ------------------------------------------------------------------------------
# Test 8: Missing hook refusal (Fail-closed invariant)
# ------------------------------------------------------------------------------
# When strategy is hook but no on-sync handler is registered
refuse_out=""
refuse_code=0
refuse_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" push hook 2>&1)" || refuse_code=$?

expected_refuse="❌ aapp.syncStrategy=hook but no executable handler is registered for on-sync in .agents/skills/aapp-hooks/registry.tsv or git config."
if [ "$refuse_code" -ne 0 ] && echo "$refuse_out" | grep -Fq "$expected_refuse"; then
  got="PASS"
else
  got="FAIL"
fi
report "aapp push hook refuses cleanly when no on-sync handler is registered" "PASS" "$got" "$refuse_out"

# ------------------------------------------------------------------------------
# Test 9: on-sync handler execution & Dual Delivery contract
# ------------------------------------------------------------------------------
# Create executable mock on-sync hook handler
MOCK_HOOK="$PROJ_DIR/mock_on_sync.sh"
cat << 'EOF' > "$MOCK_HOOK"
#!/usr/bin/env bash
INPUT="$(cat)"
echo "HOOK_INVOKED: action=$AAPP_ACTION remote=$AAPP_REMOTE event=$AAPP_EVENT"
echo "HOOK_PAYLOAD: $INPUT"
exit 0
EOF
chmod +x "$MOCK_HOOK"

# Register in .agents/skills/aapp-hooks/registry.tsv
mkdir -p "$PROJ_DIR/.agents/skills/aapp-hooks"
TAB="$(printf '\t')"
printf "on-sync%s%s%ssha256:dummy%s10%sgate\n" "$TAB" "$MOCK_HOOK" "$TAB" "$TAB" "$TAB" > "$PROJ_DIR/.agents/skills/aapp-hooks/registry.tsv"

# With handler registered and no git config set, committed registry defaults to hook strategy
git -C "$PROJ_DIR" config --unset aapp.syncStrategy 2>/dev/null || true
hook_run_out=""
hook_run_code=0
hook_run_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" push 2>&1)" || hook_run_code=$?

if [ "$hook_run_code" -eq 0 ] && echo "$hook_run_out" | grep -q "HOOK_INVOKED: action=push remote=origin event=on-sync"; then
  got="PASS"
else
  got="FAIL"
fi
report "on-sync handler delegates transport with exported POSIX env vars" "PASS" "$got" "$hook_run_out"

# Verify payload contains action, remote, worktrees
if echo "$hook_run_out" | grep -q '"action": "push"' && echo "$hook_run_out" | grep -q '"worktrees":'; then
  got="PASS"
else
  got="FAIL"
fi
report "on-sync handler receives structured JSON envelope on stdin" "PASS" "$got" "$hook_run_out"

# ------------------------------------------------------------------------------
# Test 10: Three-Tier Precedence Overrides
# ------------------------------------------------------------------------------
# Tier 2 override: local git config overrides committed registry default
(
  cd "$PROJ_DIR" || exit 1
  git config aapp.syncStrategy builtin
)

override_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" push 2>&1)"
if ! echo "$override_out" | grep -q "HOOK_INVOKED" && echo "$override_out" | grep -q "All AAPP worktrees pushed successfully"; then
  got="PASS"
else
  got="FAIL"
fi
report "git config aapp.syncStrategy builtin overrides committed registry hook default" "PASS" "$got" "$override_out"

# Tier 1 override: CLI positional argument overrides local git config
cli_override_out=""
cli_override_out="$(cd "$PROJ_DIR" && "$KIT_DIR/aapp" push origin hook 2>&1)"
if echo "$cli_override_out" | grep -q "HOOK_INVOKED: action=push remote=origin"; then
  got="PASS"
else
  got="FAIL"
fi
report "CLI positional argument 'aapp push origin hook' overrides local git config" "PASS" "$got" "$cli_override_out"

echo "============================================================"
echo "📊 Results: $PASS passed, $FAIL failed"
echo "============================================================"
[ "$FAIL" -eq 0 ] || exit 1
