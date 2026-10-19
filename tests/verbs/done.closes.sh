#!/usr/bin/env bash
# Tests: `aapp done` behaviour contract (lib/docs/verbs/done.md)
# Part: done.closes.sh (a plan that closes further issues: `refine <plan>
# closes <num>`, archived by `done` with the plan's recorded commit, P-86).
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"
export AAPP_STATE_DIR="$R/state"
unset AAPP_AGENT_NAME AAPP_AGENT_VENDOR AAPP_AGENT_MODEL

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1
printf '%s\n' '.env' >> .gitignore
git add -A && git commit -qm "track init files" --no-verify
git branch develop; git branch core
git config aapp.planWorktrees on
git config aapp.commitMode microcommits
git config aapp.integrate ff
git config aapp.issueFixWait 0
git config aapp.offlineEnabled false
git config aapp.pluginTimeout 2

mk_issue() { aapp issue log Low CORE "Defect in $1 shows." file "src/$1.sh" 2>&1 | sed -nE 's/.*#([0-9]+) logged.*/\1/p' | head -n 1; }
# mk_plan <name> [issue <n>]: drafts and freeze-starts a plan; prints its id.
mk_plan() {
  local name="$1" id f; shift
  id="P-$(git config aapp.planId)"; aapp draft "$name" "$@" >/dev/null 2>&1
  f="$(ls .plans/current/P"${id#P-}"-*.md)"
  sed -i -E "s|src/path/to/file\.ext|src/$name.sh|g; s|src/path/to/new_file\.ext|src/${name}_b.sh|g" "$f"
  sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$f"
  git -C .plans commit -qam "prep $id" >/dev/null 2>&1
  aapp freeze-start "$id" >/dev/null 2>&1
  echo "$id"
}
wt() { echo "$R/p/.workspace/P${1#P-}"; }
work() { ( cd "$(wt "$1")" && mkdir -p src && echo "v=$3" > "src/$2.sh" && git add "src/$2.sh" && aapp commit "feat: $2 $3" >/dev/null 2>&1 ); }
pfile() { ls .plans/current/P"${1#P-}"-*.md 2>/dev/null || ls .plans/done/P"${1#P-}"-*.md; }
also() { sed -nE 's/^\* \*\*Also Closes:\*\*[[:space:]]*//p' "$(pfile "$1")" | head -n 1; }
row() { grep -E "^\| #$1 \|" .plans/ISSUES.md; }
arch() { grep -E "^\| #$1 \|" .plans/done/000-issues-archive.md | head -n 1; }
arch_sha() { arch "$1" | awk -F'|' '{ gsub(/[` ]/, "", $7); print $7 }'; }
PDIR=".agents/skills/aapp-issue-tracker"
plugin_on() { mkdir -p "$PDIR"; { echo '#!/bin/sh'; echo "tr -d '\\n' >> \"$R/log\"; echo >> \"$R/log\""; echo "echo '{\"status\": \"declined\"}'"; } > "$PDIR/run"; chmod +x "$PDIR/run"; : > "$R/log"; }
plugin_off() { rm -rf "$PDIR"; }

echo "== refine <plan> closes <num> =="
n1="$(mk_issue one)"; n2="$(mk_issue two)"; n3="$(mk_issue three)"; n4="$(mk_issue four)"
row1="$(row "$n1")"
p="$(mk_plan alpha)"
out="$(aapp refine "$p" closes "$n1" 2>&1)"; rc=$?
files="$(git -C .plans show --name-only --format= HEAD)"
out2="$(aapp refine "$p" closes "$n2" 2>&1)"; rc2=$?
if [ "$rc" -eq 0 ] && [ "$files" = "current/$(basename "$(pfile "$p")")" ] && [ "$rc2" -eq 0 ] && [ "$(also "$p")" = "#$n1, #$n2" ]; then
  ok "test_refine_closes_lists_the_issue"
else
  bad "test_refine_closes_lists_the_issue" "rc=$rc/$rc2 files=$files also=$(also "$p") out=$out | $out2"
fi

aapp issue abort "$n3" reason "Not a bug" >/dev/null 2>&1
q="$(mk_plan beta issue "$n4")"
h0="$(git -C .plans rev-parse HEAD)"; before="$(also "$p")"
aapp refine "$p" closes 999 >/dev/null 2>&1; r1=$?
aapp refine "$p" closes "$n3" >/dev/null 2>&1; r2=$?
aapp refine "$q" closes "$n4" >/dev/null 2>&1; r3=$?
h1="$(git -C .plans rev-parse HEAD)"
aapp refine "$p" closes "$n1" >/dev/null 2>&1; r4=$?
if [ "$r1" -ne 0 ] && [ "$r2" -ne 0 ] && [ "$r3" -ne 0 ] && [ "$h1" = "$h0" ] && [ "$(also "$p")" = "$before" ] && [ -z "$(also "$q")" ] && \
   [ "$r4" -eq 0 ] && [ "$(git -C .plans rev-parse HEAD)" = "$h0" ]; then
  ok "test_refine_closes_refusals"
else
  bad "test_refine_closes_refusals" "rc=$r1/$r2/$r3/$r4 also=$(also "$p")"
fi

aapp refine "$p" closes "$n2" remove >/dev/null 2>&1; s1="$(also "$p")"
aapp refine "$p" closes "$n1" remove >/dev/null 2>&1
gone=0; grep -q '^\* \*\*Also Closes:\*\*' "$(pfile "$p")" || gone=1
aapp refine "$p" closes "$n1" remove >/dev/null 2>&1; r5=$?
if [ "$s1" = "#$n1" ] && [ "$gone" -eq 1 ] && [ "$r5" -ne 0 ]; then
  ok "test_refine_closes_remove"
else
  bad "test_refine_closes_remove" "after one=[$s1] gone=$gone rc=$r5"
fi

aapp refine "$p" closes "$n1" >/dev/null 2>&1; aapp refine "$p" closes "$n2" >/dev/null 2>&1
if [ "$(row "$n1")" = "$row1" ]; then
  ok "test_listed_row_is_untouched"
else
  bad "test_listed_row_is_untouched" "before=[$row1] after=[$(row "$n1")]"
fi

echo "== done closes the listed issues =="
w="$(mk_plan waiter)"; work "$w" waiter 1
aapp refine "$w" blocked "$n1" >/dev/null 2>&1
work "$p" alpha 1; work "$p" alpha 2
pbr="$(git branch --list "plan/P${p#P-}-*" --format='%(refname:short)')"
c1="$(git rev-parse "$pbr~1")"; c2="$(git rev-parse "$pbr")"; dev0="$(git rev-parse develop)"
plugin_on
out="$(aapp done "$p" 2>&1)"; rc=$?
plugin_off
tip="$(git rev-parse --short develop)"
archived_in="$(git -C .plans log --format=%s -- done/000-issues-archive.md | head -n 1)"
if [ "$rc" -eq 0 ] && [ "$(arch_sha "$n1")" = "$tip" ] && [ "$(arch_sha "$n2")" = "$tip" ] && \
   arch "$n1" | grep -qF "[$p](" && [ -z "$(row "$n1")" ] && [ -z "$(row "$n2")" ] && \
   echo "$archived_in" | grep -qF "plan(done): archive $p"; then
  ok "test_done_archives_listed_issues"
else
  bad "test_done_archives_listed_issues" "rc=$rc tip=$tip a1=$(arch_sha "$n1") a2=$(arch_sha "$n2") in=$archived_in out=$out"
fi
if ! grep -q '^\* \*\*Blocked On:\*\*' "$(pfile "$w")" && \
   [ "$(grep -F '"event": "issue.close"' "$R/log" | grep -cF "\"commit\": \"$tip\"")" -ge 2 ] && \
   grep -F '"event": "issue.close"' "$R/log" | grep -qF "\"id\": \"#$n1\"" && grep -F '"event": "issue.close"' "$R/log" | grep -qF "\"id\": \"#$n2\""; then
  ok "test_done_unblocks_and_notifies"
else
  bad "test_done_unblocks_and_notifies" "blocked=$(grep 'Blocked On' "$(pfile "$w")") closes=$(grep -cF 'issue.close' "$R/log")"
fi
if [ "$rc" -eq 0 ] && [ "$(git rev-list --count "$dev0"..develop)" = "2" ] && git merge-base --is-ancestor "$c1" develop && \
   [ "$(git rev-parse develop)" = "$c2" ]; then
  ok "test_plan_not_squashed_for_listed_issue"
else
  bad "test_plan_not_squashed_for_listed_issue" "count=$(git rev-list --count "$dev0"..develop)"
fi

echo "== listed issues that are not closed =="
n5="$(mk_issue five)"; n6="$(mk_issue six)"
aapp refine issues "six belongs to core" branch "$n6" core >/dev/null 2>&1
g="$(mk_plan gamma)"; work "$g" gamma 1
aapp refine "$g" closes "$n5" >/dev/null 2>&1; aapp refine "$g" closes "$n6" >/dev/null 2>&1
aapp issue abort "$n5" reason "Withdrawn meanwhile" >/dev/null 2>&1
out="$(aapp done "$g" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -F "#$n5" | grep -qi "archived"; then
  ok "test_already_archived_is_skipped"
else
  bad "test_already_archived_is_skipped" "rc=$rc out=$out"
fi
if [ "$rc" -eq 0 ] && [ -n "$(row "$n6")" ] && echo "$out" | grep -F "#$n6" | grep -qF "core"; then
  ok "test_issue_on_another_branch_stays_open"
else
  bad "test_issue_on_another_branch_stays_open" "rc=$rc row=$(row "$n6") out=$out"
fi

print_test_summary "$PASS" "$FAIL"
