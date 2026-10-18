#!/usr/bin/env bash
# Tests: `aapp companion` behaviour contract (lib/docs/verbs/companion.md)
# Governed by Plan P-90 (Companion Repository Bridge).
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-60s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-60s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

make_plain_repo() {
  local dir="$1"
  mkdir -p "$dir"
  (
    cd "$dir" || exit 1
    git init -q .
    setup_test_git_identity "$dir"
    echo "# Plain Repo" > README.md
    git add README.md
    git commit -qm "initial commit"
  )
}

make_upstream_remote() {
  local bare_dir="$1" work_dir="$2"
  git init -q --bare "$bare_dir"
  (
    cd "$work_dir" || exit 1
    git remote add origin "$bare_dir"
    git push -qu origin HEAD:main
    git branch --set-upstream-to=origin/main main >/dev/null 2>&1 || true
  )
}

init_sandbox_project "$R/primary"
cd "$R/primary" || exit 1

echo "== 1. companion add (checkout & validation) =="

# 1. test_companion_add_checkout_validates_repo
COMP1="$R/comp1_checkout"; make_plain_repo "$COMP1"
out1_bad="$(aapp companion add "INVALID NAME!" "$COMP1" 2>&1)"; rc1_bad=$?
out1_not_repo="$(aapp companion add comp1 "$R/nonexistent" 2>&1)"; rc1_not_repo=$?
out1="$(aapp companion add comp1 "$COMP1" 2>&1)"; rc1=$?

cfg_path="$(git config aapp.companion.comp1.path || true)"
cfg_mode="$(git config aapp.companion.comp1.mode || true)"
allow_has_comp1=0
if git config --get-all aapp.allowPath 2>/dev/null | grep -qxF "$COMP1"; then
  allow_has_comp1=1
fi

# Duplicate refusal
out1_dup="$(aapp companion add comp1 "$COMP1" 2>&1)"; rc1_dup=$?

if [ "$rc1_bad" -ne 0 ] && [ "$rc1_not_repo" -ne 0 ] && [ "$rc1" -eq 0 ] && \
   [ "$cfg_path" = "$COMP1" ] && [ "$cfg_mode" = "checkout" ] && \
   [ "$allow_has_comp1" -eq 1 ] && [ "$rc1_dup" -ne 0 ]; then
  ok "test_companion_add_checkout_validates_repo"
else
  bad "test_companion_add_checkout_validates_repo" "rc1=$rc1 cfg_path=$cfg_path cfg_mode=$cfg_mode allow=$allow_has_comp1 dup_rc=$rc1_dup"
fi

echo "== 2. companion add (worktree mode for non-AAPP) =="

# 2. test_companion_add_worktree_non_aapp
COMP2="$R/comp2_plain"; make_plain_repo "$COMP2"
out2="$(aapp companion add comp2 "$COMP2" worktree 2>&1)"; rc2=$?

comp2_expected_path="$R/primary/.workspace/companion/comp2"
cfg2_path="$(git config aapp.companion.comp2.path || true)"
cfg2_mode="$(git config aapp.companion.comp2.mode || true)"
allow_has_comp2=0
if git config --get-all aapp.allowPath 2>/dev/null | grep -qxF "$comp2_expected_path"; then
  allow_has_comp2=1
fi

if [ "$rc2" -eq 0 ] && [ -d "$comp2_expected_path" ] && [ -f "$comp2_expected_path/.git" ] && \
   [ "$cfg2_path" = "$comp2_expected_path" ] && [ "$cfg2_mode" = "worktree" ] && \
   [ "$allow_has_comp2" -eq 1 ]; then
  ok "test_companion_add_worktree_non_aapp"
else
  bad "test_companion_add_worktree_non_aapp" "rc2=$rc2 out=$out2 path=$cfg2_path mode=$cfg2_mode allow=$allow_has_comp2"
fi

echo "== 3. companion add (worktree mode refuses AAPP repos per G2) =="

# 3. test_companion_add_worktree_refuses_aapp_repo
COMP3_AAPP="$R/comp3_aapp"; init_sandbox_project "$COMP3_AAPP"
out3="$(aapp companion add comp3 "$COMP3_AAPP" worktree 2>&1)"; rc3=$?

if [ "$rc3" -ne 0 ] && echo "$out3" | grep -q "uses AAPP" && [ ! -d ".workspace/companion/comp3" ]; then
  ok "test_companion_add_worktree_refuses_aapp_repo"
else
  bad "test_companion_add_worktree_refuses_aapp_repo" "rc3=$rc3 out=$out3"
fi

echo "== 4. companion status (offline metrics) =="

# 4. test_companion_status_offline_metrics
# Setup COMP1 with remote and commits
COMP1_REMOTE="$R/comp1_remote.git"
make_upstream_remote "$COMP1_REMOTE" "$COMP1"
# Add a dirty file and an unpushed commit in COMP1
echo "change" >> "$COMP1/README.md"
(
  cd "$COMP1" || exit 1
  git commit -qam "local commit"
  echo "untracked" > "$COMP1/untracked.txt"
)

out4="$(aapp companion status comp1 2>&1)"; rc4=$?

if [ "$rc4" -eq 0 ] && echo "$out4" | grep -q "comp1" && \
   echo "$out4" | grep -q "ahead: 1" && echo "$out4" | grep -q "dirty: 1"; then
  ok "test_companion_status_offline_metrics"
else
  bad "test_companion_status_offline_metrics" "rc4=$rc4 out=$out4"
fi

echo "== 5. companion push (bounded) =="

# 5. test_companion_push_bounded
# Push should be refused while dirty
out5_dirty="$(aapp companion push comp1 2>&1)"; rc5_dirty=$?
# Clean the untracked file
rm -f "$COMP1/untracked.txt"
# Companion comp2 has no upstream, so push must be refused
out5_no_upstream="$(aapp companion push comp2 2>&1)"; rc5_no_upstream=$?

# Now push comp1 (it has upstream and is clean of uncommitted changes, 1 commit ahead)
out5_push="$(aapp companion push comp1 2>&1)"; rc5_push=$?
comp1_ahead_after="$(git -C "$COMP1" rev-list --count origin/main..HEAD 2>/dev/null || true)"

if [ "$rc5_dirty" -ne 0 ] && [ "$rc5_no_upstream" -ne 0 ] && \
   [ "$rc5_push" -eq 0 ] && [ "$comp1_ahead_after" -eq 0 ]; then
  ok "test_companion_push_bounded"
else
  bad "test_companion_push_bounded" "rc_dirty=$rc5_dirty rc_no_up=$rc5_no_upstream rc_push=$rc5_push ahead=$comp1_ahead_after"
fi

echo "== 6. companion remove (checkout unlinks only) =="

# 6. test_companion_remove_checkout_unlinks_only
out6="$(aapp companion remove comp1 2>&1)"; rc6=$?
cfg1_path_after="$(git config aapp.companion.comp1.path || true)"
allow_has_comp1_after=0
if git config --get-all aapp.allowPath 2>/dev/null | grep -qxF "$COMP1"; then
  allow_has_comp1_after=1
fi

if [ "$rc6" -eq 0 ] && [ -d "$COMP1" ] && [ -f "$COMP1/README.md" ] && \
   [ -z "$cfg1_path_after" ] && [ "$allow_has_comp1_after" -eq 0 ]; then
  ok "test_companion_remove_checkout_unlinks_only"
else
  bad "test_companion_remove_checkout_unlinks_only" "rc6=$rc6 dir_exists=$([ -d "$COMP1" ] && echo 1 || echo 0) cfg=$cfg1_path_after allow=$allow_has_comp1_after"
fi

echo "== 7. companion remove (worktree guards unpushed) =="

# 7. test_companion_remove_worktree_guards_unpushed
# Add an unpushed commit to comp2 worktree
echo "worktree edit" >> "$comp2_expected_path/README.md"
(
  cd "$comp2_expected_path" || exit 1
  git commit -qam "worktree unpushed commit"
)

out7_refuse="$(aapp companion remove comp2 2>&1)"; rc7_refuse=$?
out7_force="$(aapp companion remove comp2 force 2>&1)"; rc7_force=$?
cfg2_path_after="$(git config aapp.companion.comp2.path || true)"

if [ "$rc7_refuse" -ne 0 ] && [ "$rc7_force" -eq 0 ] && \
   [ ! -d "$comp2_expected_path" ] && [ -z "$cfg2_path_after" ]; then
  ok "test_companion_remove_worktree_guards_unpushed"
else
  bad "test_companion_remove_worktree_guards_unpushed" "rc7_refuse=$rc7_refuse rc7_force=$rc7_force dir_exists=$([ -d "$comp2_expected_path" ] && echo 1 || echo 0) cfg=$cfg2_path_after"
fi

echo "== 8. companion guard delegation for AAPP repos (G1) =="

# 8. test_companion_guard_delegation_aapp
COMP_AAPP="$R/comp_aapp_delegated"; init_sandbox_project "$COMP_AAPP"
(
  cd "$COMP_AAPP" || exit 1
  # Scaffold and activate a plan in COMP_AAPP that lists only 'src/allowed.py'
  aapp draft companion-feature >/dev/null 2>&1
  pfile="$(ls .plans/current/P*-companion-feature.md | head -n 1)"
  pid="$(basename "$pfile" | sed -E 's/^P([0-9]+)-.*/P-\1/')"
  sed -i "s|src/path/to/file\.ext|src/allowed\.py|g" "$pfile"
  # Mark questions answered so it can freeze
  sed -i 's/^\* \[ \] \*\*Question/\* [x] \*\*Question/g' "$pfile"
  git -C .plans commit -qam "prep companion plan" >/dev/null 2>&1
  aapp freeze-start "$pid" >/dev/null 2>&1
)

aapp companion add comp_aapp "$COMP_AAPP" >/dev/null 2>&1

# In primary repo, invoke blast-radius-guard on allowed file and out-of-bounds file in companion
target_allowed="$COMP_AAPP/src/allowed.py"
target_refused="$COMP_AAPP/src/disallowed.py"

# Simulate Write tool call passing file path to guard
echo "$target_allowed" | .githooks/blast-radius-guard >/dev/null 2>&1; rc8_allowed=$?
echo "$target_refused" | .githooks/blast-radius-guard >/dev/null 2>&1; rc8_refused=$?

if [ "$rc8_allowed" -eq 0 ] && [ "$rc8_refused" -ne 0 ]; then
  ok "test_companion_guard_delegation_aapp"
else
  bad "test_companion_guard_delegation_aapp" "rc8_allowed=$rc8_allowed rc8_refused=$rc8_refused"
fi

print_test_summary "$PASS" "$FAIL"
