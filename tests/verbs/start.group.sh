#!/usr/bin/env bash
# Tests: `aapp start` for group plans and their members (P-64); a part of the
# start suite (lib/docs/verbs/start.md, P-68).
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-48s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-48s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

plan_file() { ls .plans/current/P"${1#P-}"-*.md; }
freeze_plan() {
  sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$(plan_file "$1")"
  git -C .plans commit -qam "resolve questions" >/dev/null
  aapp freeze "$1" >/dev/null 2>&1
}
status_of() { grep -m1 '^\* \*\*Status:\*\*' "$1"; }
buffer() { cat "$(git rev-parse --git-path aapp_active_plan)" 2>/dev/null; }
# targets_only <id> <code-file>: the plan targets one code file plus the shared docs.
targets_only() {
  local f; f="$(plan_file "$1")"
  sed -i -E "s|src/path/to/file\.ext|$2|; /src\/path\/to\/new_file\.ext/d" "$f"
  sed -i -E "s|^(- \[ \] \`$2\`.*)$|\1\n- [ ] \`CHANGELOG.md\` -> Record.\n- [ ] \`.agents/CODEMAP.md\` -> Map.|" "$f"
}

echo "== group plans (P-64) =="
init_sandbox_project "$R/gr"
cd "$R/gr" || exit 1
git add -A && git commit -qm "track init files" --no-verify
git branch develop; git branch module/x
git config aapp.planWorktrees on
# draft_group <slug>: a frozen group plan; draft_member <slug> <group>: a frozen member.
draft_group() { local id; id="P-$(git config --get aapp.planId)"; aapp draft "$1" group >/dev/null 2>&1 && freeze_plan "$id"; echo "$id"; }
draft_member() {
  local id; id="P-$(git config --get aapp.planId)"; aapp draft "$1" group "$2" >/dev/null 2>&1
  targets_only "$id" "src/$1.py"; freeze_plan "$id"; echo "$id"
}
fb_of() { sed -nE 's/^\* \*\*Feature Branch:\*\* (.+)$/\1/p' "$(plan_file "$1")"; }

g1="$(draft_group g-one)"; g1f="$(plan_file "$g1")"; dev="$(git rev-parse --short develop)"; nwt="$(git worktree list | wc -l)"
out="$(aapp start "$g1" 2>&1)"; rc=$?
g2="$(draft_group g-two)"; g2f="$(plan_file "$g2")"; mod="$(git rev-parse --short module/x)"
out2="$(aapp start "$g2" base module/x 2>&1)"; rc2=$?
if [ "$rc" -eq 0 ] && [ "$(fb_of "$g1")" = "feature/g-one" ] && [ "$(git rev-parse --short feature/g-one)" = "$dev" ] && \
   grep -qxF "* **Base:** \`$dev\` (develop)" "$g1f" && status_of "$g1f" | grep -q '⚡ In Development' && \
   [ "$(git worktree list | wc -l)" = "$nwt" ] && [ -z "$(buffer)" ] && \
   [ "$rc2" -eq 0 ] && [ "$(git rev-parse --short feature/g-two)" = "$mod" ] && grep -qxF "* **Base:** \`$mod\` (module/x)" "$g2f"; then
  ok "test_group_start_cuts_feature_branch_from_parent"
else
  bad "test_group_start_cuts_feature_branch_from_parent" "rc=$rc/$rc2 out=$out | $out2"
fi

g3="$(draft_group g-three)"; g3f="$(plan_file "$g3")"; before="$(cksum < "$g3f")"
out="$(aapp start "$g3" base no-such-branch 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && ! git rev-parse --verify -q feature/g-three >/dev/null && [ "$(cksum < "$g3f")" = "$before" ]; then
  ok "test_group_start_refuses_missing_branch"
else
  bad "test_group_start_refuses_missing_branch" "rc=$rc out=$out"
fi

m1="$(draft_member m-one "$g1")"; m1f="$(plan_file "$m1")"; fsha="$(git rev-parse --short feature/g-one)"
out="$(aapp start "$m1" 2>&1)"; rc=$?
mwt="$R/gr/.workspace/P${m1#P-}"
if [ "$rc" -eq 0 ] && [ "$(git -C "$mwt" rev-parse --short HEAD)" = "$fsha" ] && \
   grep -qxF "* **Base:** \`$fsha\` (feature/g-one)" "$m1f" && grep -qxF "* **Group:** $g1" "$m1f"; then
  ok "test_member_start_branches_from_feature_branch"
else
  bad "test_member_start_branches_from_feature_branch" "rc=$rc out=$out $(grep -E 'Base|Group' "$m1f" | tr '\n' ' ')"
fi

m3="$(draft_member m-three "$g3")"; m3f="$(plan_file "$m3")"; before="$(cksum < "$m3f")"
out="$(aapp start "$m3" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "$g3" && [ "$(cksum < "$m3f")" = "$before" ] && [ ! -d "$R/gr/.workspace/P${m3#P-}" ]; then
  ok "test_member_start_refuses_unstarted_group"
else
  bad "test_member_start_refuses_unstarted_group" "rc=$rc out=$out"
fi

g4="$(draft_group g-four)"; g4f="$(plan_file "$g4")"; before="$(cksum < "$g4f")"
out="$(aapp start "$g4" base feature/g-one 2>&1)"; r1=$?
out2="$(aapp refine "$g4" group "$g1" 2>&1)"; r2=$?
if [ "$r1" -ne 0 ] && [ "$r2" -ne 0 ] && ! git rev-parse --verify -q feature/g-four >/dev/null && \
   [ "$(cksum < "$g4f")" = "$before" ] && ! grep -qF "$g4" "$g1f"; then
  ok "test_groups_do_not_nest"
else
  bad "test_groups_do_not_nest" "rc=$r1/$r2 out=$out | $out2"
fi

print_test_summary "$PASS" "$FAIL"
