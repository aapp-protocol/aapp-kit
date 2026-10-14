#!/usr/bin/env bash
# Tests: `aapp issue` behaviour contract (lib/docs/verbs/issue.md)
# Part: issue.onecommit.sh (every fix in its own worktree, landing as one
# commit, P-85).
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
mkdir -p src; for f in a b c d e; do printf 'x1 = 1\nx2 = 2\n' > "src/$f.sh"; done
git add -A && git commit -qm "sources" --no-verify
git branch develop; git checkout -q develop
git config aapp.commitMode microcommits
git config aapp.issueFixWait 0
git config aapp.offlineEnabled false
git config aapp.pluginTimeout 2
git config aapp.aiAttribution lax

mk_issue() { aapp issue log Low CORE "Defect in $1 shows." file "src/$1.sh" 2>&1 | sed -nE 's/.*#([0-9]+) logged.*/\1/p' | head -n 1; }
wt() { echo "$R/p/.workspace/fix-$1"; }
# fcommit <n> <file> <value> <msg> [tokens…]: one commit in the fix's worktree.
fcommit() {
  local n="$1" f="$2" v="$3" m="$4"; shift 4
  ( cd "$(wt "$n")" && sed -i "s/^x1 = .*/x1 = $v/" "src/$f.sh" && git add "src/$f.sh" && aapp commit "$m" "$@" >/dev/null 2>&1 )
}
BUF="$(git rev-parse --git-path aapp_active_plan)"
buf_now() { cat "$BUF" 2>/dev/null || echo "(none)"; }
row_sha() { grep -E "^\| #$1 \|" .plans/done/000-issues-archive.md | head -n 1 | awk -F'|' '{ gsub(/[` ]/, "", $7); print $7 }'; }
PDIR=".agents/skills/aapp-issue-tracker"
plugin_on() { mkdir -p "$PDIR"; { echo '#!/bin/sh'; echo "tr -d '\\n' >> \"$R/log\"; echo >> \"$R/log\""; echo "echo '{\"status\": \"declined\"}'"; } > "$PDIR/run"; chmod +x "$PDIR/run"; : > "$R/log"; }
plugin_off() { rm -rf "$PDIR"; }

echo "== every fix in its own worktree =="
n1="$(mk_issue a)"
buf0="$(buf_now)"; st0="$(git status --porcelain)"; head0="$(git rev-parse HEAD)"; dev0="$(git rev-parse develop)"
out="$(aapp issue fix "$n1" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -d "$(wt "$n1")" ] && [ "$(git rev-parse "fix/$n1" 2>/dev/null)" = "$dev0" ] && \
   [ "$(git rev-parse --abbrev-ref HEAD)" = "develop" ] && echo "$out" | grep -qF ".workspace/fix-$n1"; then
  ok "test_fix_always_opens_in_its_worktree"
else
  bad "test_fix_always_opens_in_its_worktree" "rc=$rc out=$out"
fi
fcommit "$n1" a 10 "fix: first step" changelog "the defect in a no longer shows when its input carries a trailing line and several more words than fit" agent "First Bot" vendor Acme model one
plugin_on
fcommit "$n1" a 11 "fix: second step" agent "Last Bot" vendor Acme model two
left1=0; [ "$(buf_now)" = "$buf0" ] && [ "$(git status --porcelain)" = "$st0" ] && [ "$(git rev-parse HEAD)" = "$head0" ] && left1=1

out="$(aapp issue close "$n1" 2>&1)"; rc=$?
plugin_off
tip="$(git rev-parse develop)"; subj="$(git log -1 --format=%s develop)"; body="$(git log -1 --format=%B develop)"
max="$(git config --int aapp.subjectMaxLen 2>/dev/null || echo 72)"
if [ "$rc" -eq 0 ] && [ "$(git rev-list --count "$dev0"..develop)" = "1" ] && [ "${#subj}" -le "$max" ] && \
   echo "$subj" | grep -qE "^fix: the defect in a no longer shows .*\.\.\. \(#$n1\)$" && \
   echo "$body" | grep -qF "several more words than fit" && echo "$body" | grep -qF "fix: first step" && \
   [ "$(git show develop:src/a.sh | head -n 1)" = "x1 = 11" ] && [ ! -d "$(wt "$n1")" ] && ! git rev-parse -q --verify "refs/heads/fix/$n1" >/dev/null; then
  ok "test_close_squashes_to_one_commit"
else
  bad "test_close_squashes_to_one_commit" "rc=$rc count=$(git rev-list --count "$dev0"..develop) subj=$subj out=$out"
fi
if [ "$(row_sha "$n1")" = "$(git rev-parse --short "$tip")" ] && \
   grep -F '"event": "issue.close"' "$R/log" | tail -n 1 | grep -qF "\"commit\": \"$(git rev-parse --short "$tip")\""; then
  ok "test_row_and_provider_name_the_commit"
else
  bad "test_row_and_provider_name_the_commit" "row=$(row_sha "$n1") tip=$(git rev-parse --short "$tip") sent=$(grep -F 'issue.close' "$R/log" | tail -n 1 | cut -c1-200)"
fi
if echo "$body" | grep -qx "AI-Agent: Last Bot" && [ "$(echo "$body" | grep -c '^AI-Agent:')" = "1" ]; then
  ok "test_attribution_is_the_last_commit"
else
  bad "test_attribution_is_the_last_commit" "body=$(echo "$body" | tr '\n' '/')"
fi

echo "== a fix of one commit =="
n2="$(mk_issue b)"
aapp issue fix "$n2" >/dev/null 2>&1
fcommit "$n2" b 20 "fix: b in one step" changelog "b is fixed"
one="$(git rev-parse "fix/$n2" 2>/dev/null)"
out="$(aapp issue close "$n2" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -n "$one" ] && [ "$(git rev-parse develop)" = "$one" ] && [ "$(git log -1 --format=%s develop)" = "fix: b in one step" ]; then
  ok "test_single_commit_fix_keeps_its_sha"
else
  bad "test_single_commit_fix_keeps_its_sha" "rc=$rc one=$one dev=$(git rev-parse develop) out=$out"
fi

echo "== the main checkout is left alone =="
n3="$(mk_issue c)"
buf0="$(buf_now)"; st0="$(git status --porcelain)"
aapp issue fix "$n3" >/dev/null 2>&1
left2=0; [ "$(buf_now)" = "$buf0" ] && [ "$(git status --porcelain)" = "$st0" ] && left2=1
out="$(aapp issue fix "$n3" abort 2>&1)"; rc=$?
if [ "$left1" -eq 1 ] && [ "$left2" -eq 1 ] && [ "$rc" -eq 0 ] && [ "$(buf_now)" = "$buf0" ] && [ "$(git status --porcelain)" = "$st0" ] && \
   [ ! -d "$(wt "$n3")" ] && ! git rev-parse -q --verify "refs/heads/fix/$n3" >/dev/null; then
  ok "test_main_checkout_left_alone"
else
  bad "test_main_checkout_left_alone" "left=$left1/$left2 rc=$rc buf=$(buf_now) out=$out"
fi

echo "== uncommitted work in the main checkout =="
n4="$(mk_issue d)"
sed -i 's/^x2 = .*/x2 = 99/' src/d.sh
out="$(aapp issue fix "$n4" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -d "$(wt "$n4")" ] && [ "$(sed -n 2p src/d.sh)" = "x2 = 99" ]; then
  ok "test_fix_does_not_wait_for_dirty_files"
else
  bad "test_fix_does_not_wait_for_dirty_files" "rc=$rc out=$out"
fi
fcommit "$n4" d 40 "fix: d" changelog "d is fixed"
fix4="$(git rev-parse "fix/$n4" 2>/dev/null)"; dev4="$(git rev-parse develop)"
out="$(aapp issue close "$n4" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "src/d.sh" && [ -d "$(wt "$n4")" ] && [ "$(git rev-parse "fix/$n4")" = "$fix4" ] && \
   [ "$(git rev-parse develop)" = "$dev4" ] && grep -qE "^\| #$n4 \|" .plans/ISSUES.md && [ -f ".plans/current/fix-$n4.md" ] && \
   [ "$(sed -n 2p src/d.sh)" = "x2 = 99" ]; then
  ok "test_close_refuses_over_uncommitted_work"
else
  bad "test_close_refuses_over_uncommitted_work" "rc=$rc out=$out"
fi
git checkout -q -- src/d.sh
aapp issue close "$n4" >/dev/null 2>&1

echo "== a hotfix in a single checkout =="
git config aapp.planWorktrees off
sid="P-$(git config aapp.planId)"; aapp draft host >/dev/null 2>&1
sf="$(ls .plans/current/P"${sid#P-}"-*.md)"
sed -i -E "s|src/path/to/file\.ext|src/e.sh|g; /src\/path\/to\/new_file\.ext/d; s/^\* \[ \] \*\*Question/* [x] **Question/" "$sf"
git -C .plans commit -qam prep >/dev/null 2>&1
aapp freeze-start "$sid" >/dev/null 2>&1
sed -i 's/^x2 = .*/x2 = 50/' src/e.sh
n5="$(aapp issue hotfix "Bug in e" file src/e.sh 2>&1 | sed -nE 's/.*#([0-9]+) logged.*/\1/p' | head -n 1)"
set_aside=0; [ -z "$(git status --porcelain -- src/e.sh)" ] && set_aside=1
aapp issue fix "$n5" >/dev/null 2>&1
fcommit "$n5" e 5 "fix: e" changelog "e is fixed"
out="$(aapp issue close "$n5" 2>&1)"; rc=$?
if [ "$set_aside" -eq 1 ] && [ "$rc" -eq 0 ] && [ "$(git show develop:src/e.sh | head -n 1)" = "x1 = 5" ] && \
   [ "$(sed -n 1p src/e.sh)" = "x1 = 5" ] && [ "$(sed -n 2p src/e.sh)" = "x2 = 50" ] && ! git stash list | grep -qF "aapp-hotfix:"; then
  ok "test_hotfix_stash_reapplied"
else
  bad "test_hotfix_stash_reapplied" "aside=$set_aside rc=$rc e=$(tr '\n' '|' < src/e.sh) out=$out"
fi

print_test_summary "$PASS" "$FAIL"
