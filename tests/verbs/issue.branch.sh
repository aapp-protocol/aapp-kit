#!/usr/bin/env bash
# Tests: `aapp issue` behaviour contract (lib/docs/verbs/issue.md)
# Part: issue.branch.sh (an issue carries the branch its fix lands on, P-78).
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1
mkdir -p src; for f in a b c d e f g h i j; do echo "$f=1" > "src/$f.sh"; done
git add -A && git commit -qm "sources" --no-verify
git branch develop; git branch core; git branch tmp-x
git checkout -q develop
git config aapp.planWorktrees on
git config aapp.commitMode microcommits
git config aapp.integrate ff
git config aapp.issueFixWait 0
git config aapp.maxEmergencyHotfixes 9

HDR='| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |'
SEP='| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |'
row() { printf '| #%s | `Low` | `CORE` | 2026-10-01 | `src/%s.sh` | Defect %s. |  | 🟡 `Incubated` |%s\n' "$1" "$2" "$1" "${3:-}"; }
{ printf '%s\n' '# Issues' '' "$HDR" "$SEP"; for p in "1 a" "2 b" "3 c" "4 d" "5 e" "6 f" "7 g" "8 h" "9 i"; do row $p; done; } > .plans/ISSUES.md
{ printf '%s\n' '# Issue Priority Board' '' '## 🔴 High Priority (Technical Urgency)'; for n in 1 2 3 4 5 6 7 8 9; do echo "- [ ] #$n -> Defect $n."; done; } > .plans/issues_road_map.md
printf '%s\n' '# Archive' '' '| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- |' > .plans/done/000-issues-archive.md
git -C .plans add -A >/dev/null 2>&1; git -C .plans commit -qm fixture >/dev/null 2>&1
git config aapp.issueId 20

pf() { ls .plans/current/P"${1#P-}"-*.md 2>/dev/null; }
resolve_q() { sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$1"; }
# cell <n> [file]: the Branch cell of #<n>, read by the header's column name.
cell() {
  awk -F'|' -v id="#$1" '
    !col && /^\|[[:space:]]*#[[:space:]]*\|/ { for (i = 2; i <= NF; i++) { h = $i; gsub(/^[ \t]+|[ \t]+$/, "", h); if (h == "Branch") col = i } next }
    { c = $2; gsub(/[ \t`]/, "", c) }
    c == id { if (col) { v = $col; gsub(/[ \t`]/, "", v); print v } exit }' "${2:-.plans/ISSUES.md}"
}
has_col() { grep -m 1 -E '^\|[[:space:]]*#[[:space:]]*\|' "${1:-.plans/ISSUES.md}" | grep -q '| Branch |'; }
blocked_on() { sed -nE 's/^\* \*\*Blocked On:\*\*[[:space:]]*//p' "$1" | head -n 1; }
# plan <slug> <file>: a drafted plan targeting src/<file>.sh; prints its id.
plan() {
  local id f; id="P-$(git config aapp.planId)"; aapp draft "$1" ${3:+group "$3"} >/dev/null 2>&1; f="$(pf "$id")"
  sed -i -E "s|src/path/to/file\.ext|src/$2.sh|g; /src\/path\/to\/new_file\.ext/d" "$f"; resolve_q "$f"
  git -C .plans commit -qam "prep $id" >/dev/null 2>&1
  echo "$id"
}
issue_branch_of() { ( cd "$R/p" && REPO_ROOT="$R/p" PLANS_DIR="$R/p/.plans" bash -c ". '$KIT/lib/cmd_issue.sh'; issue_branch $1" 2>/dev/null ); }

echo "== no branch named =="
b1="$(issue_branch_of 1)"
out="$(aapp issue fix 1 2>&1)"; rc=$?
indev=0; [ "$rc" -eq 0 ] && [ -f .plans/current/fix-1.md ] && [ -d .workspace/fix-1 ] && [ "$(git rev-parse fix/1)" = "$(git rev-parse develop)" ] && indev=1
aapp issue fix 1 abort >/dev/null 2>&1
# The same with the column present and the cell empty.
cp .plans/ISSUES.md "$R/issues.keep"
sed -i -E '/^\| # \|/ s/$/ Branch |/; /^\| :---/ s/$/ :--- |/; /^\| #[0-9]/ s/$/  |/' .plans/ISSUES.md
b2="$(issue_branch_of 2)"
cp "$R/issues.keep" .plans/ISSUES.md
if [ "$b1" = "develop" ] && [ "$b2" = "develop" ] && [ "$indev" -eq 1 ]; then
  ok "test_no_branch_means_dev_branch"
else
  bad "test_no_branch_means_dev_branch" "no column=[$b1] empty cell=[$b2] indev=$indev rc=$rc out=$out"
fi

echo "== logging =="
A="$(plan plan-a j)"; aapp freeze-start "$A" >/dev/null 2>&1
G="P-$(git config aapp.planId)"; aapp draft grp group >/dev/null 2>&1; resolve_q "$(pf "$G")"
git -C .plans commit -qam "prep $G" >/dev/null 2>&1; aapp freeze-start "$G" >/dev/null 2>&1
M="$(plan mem-m m "$G")"; aapp freeze-start "$M" >/dev/null 2>&1
WA="$R/p/.workspace/P${A#P-}"; WM="$R/p/.workspace/P${M#P-}"
# A second group, cut from a branch the team owns (core): its member's parent
# branch is a feature branch the kit does not bring develop's fixes into.
G2="P-$(git config aapp.planId)"; aapp draft grp-two group >/dev/null 2>&1; resolve_q "$(pf "$G2")"
git -C .plans commit -qam "prep $G2" >/dev/null 2>&1; aapp freeze "$G2" >/dev/null 2>&1 && aapp start "$G2" base core >/dev/null 2>&1
M2="$(plan mem-n n "$G2")"; aapp freeze-start "$M2" >/dev/null 2>&1

out="$(cd "$WA" && aapp issue hotfix "Core broke" file src/c.sh branch core 2>&1)"; rc=$?
shape="$(grep -E '^\|' .plans/ISSUES.md | sed 's/\\|//g' | awk -F'|' '{ print NF }' | sort -u | wc -l | tr -d ' ')"
if [ "$rc" -eq 0 ] && has_col && [ "$(cell 20)" = "core" ] && [ -z "$(cell 1)" ] && [ "$shape" = "1" ]; then
  ok "test_branch_token_adds_column"
else
  bad "test_branch_token_adds_column" "rc=$rc col=$(has_col && echo yes || echo no) cell=[$(cell 20)] shape=$shape out=$out"
fi

# A hotfix in the plan's own Target Files belongs to the plan's line of work (P-83).
out="$(cd "$WA" && aapp issue hotfix "Dev broke" file src/j.sh 2>&1)"; rc=$?
out2="$(cd "$WM" && aapp issue hotfix "Group broke" file src/m.sh 2>&1)"; rc2=$?
if [ "$rc" -eq 0 ] && [ "$rc2" -eq 0 ] && [ -z "$(cell 21)" ] && [ "$(cell 22)" = "feature/grp" ]; then
  ok "test_hotfix_takes_plan_parent_branch"
else
  bad "test_hotfix_takes_plan_parent_branch" "rc=$rc/$rc2 dev=[$(cell 21)] member=[$(cell 22)] out=$out | $out2"
fi

# Two more rows for the tests below, written straight into the ledger as setup.
log_row() { sed -i "/^| :---/a $(row "$1" "$2" '  |')" .plans/ISSUES.md; echo "- [ ] #$1 -> Defect $1." >> .plans/issues_road_map.md; git config aapp.issueId "$(( $1 + 1 ))"; }
log_row 23 e; log_row 24 f
git -C .plans commit -qam "fixture: rows 23 and 24" >/dev/null 2>&1

echo "== refine issues … branch =="
out="$(aapp refine issues "24 belongs to core" branch 24 core 2>&1)"; rc=$?
set1="$(cell 24)"; head0="$(git -C .plans rev-parse HEAD)"
out2="$(aapp refine issues "24 nowhere" branch 24 no-such-branch 2>&1)"; rc2=$?
if [ "$rc" -eq 0 ] && [ "$set1" = "core" ] && [ "$rc2" -ne 0 ] && [ "$(cell 24)" = "core" ] && [ "$(git -C .plans rev-parse HEAD)" = "$head0" ] && \
   echo "$out2" | grep -qF "no-such-branch"; then
  ok "test_refine_sets_branch"
else
  bad "test_refine_sets_branch" "rc=$rc/$rc2 cell=[$set1]/[$(cell 24)] out=$out | $out2"
fi

echo "== fixing =="
out="$(aapp issue fix 2 2>&1)"; rc=$?
main_ok=0; [ "$rc" -eq 0 ] && [ -d .workspace/fix-2 ] && [ "$(git rev-parse fix/2)" = "$(git rev-parse develop)" ] && main_ok=1
( cd .workspace/fix-2 && echo "b=2" > src/b.sh && git add src/b.sh && aapp commit "fix: b (#2)" changelog "b fixed" >/dev/null 2>&1 )
aapp issue close 2 >/dev/null 2>&1; crc=$?
core0="$(git rev-parse core)"; dev0="$(git rev-parse develop)"
out2="$(aapp issue fix 24 2>&1)"; rc2=$?
fwt="$R/p/.workspace/fix-24"
wt_ok=0; [ "$rc2" -eq 0 ] && [ -d "$fwt" ] && [ "$(git -C "$fwt" rev-parse HEAD)" = "$core0" ] && [ "$(git -C "$fwt" rev-parse --abbrev-ref HEAD)" = "fix/24" ] && wt_ok=1
( cd "$fwt" && echo "f=2" > src/f.sh && git add src/f.sh && aapp commit "fix: f (#24)" changelog "f fixed" >/dev/null 2>&1 )
out3="$(aapp issue close 24 2>&1)"; rc3=$?
if [ "$main_ok" -eq 1 ] && [ "$crc" -eq 0 ] && [ "$wt_ok" -eq 1 ] && [ "$rc3" -eq 0 ] && [ "$(git show core:src/f.sh)" = "f=2" ] && \
   [ "$(git rev-parse develop)" = "$dev0" ] && [ ! -d "$fwt" ] && ! git rev-parse --verify -q fix/24 >/dev/null && \
   [ "$(cell 24 .plans/done/000-issues-archive.md)" = "core" ]; then
  ok "test_fix_opens_on_issue_branch"
else
  bad "test_fix_opens_on_issue_branch" "main=$main_ok close=$crc wt=$wt_ok rc=$rc/$rc2/$rc3 archive=[$(cell 24 .plans/done/000-issues-archive.md)] out=$out | $out2 | $out3"
fi

echo "== a branch that is gone =="
aapp refine issues "7 on tmp" branch 7 tmp-x >/dev/null 2>&1
git branch -D tmp-x >/dev/null 2>&1
out="$(aapp issue fix 7 2>&1)"; rc=$?
gone_ok=0
[ "$rc" -eq 0 ] && [ -z "$(cell 7)" ] && [ -d .workspace/fix-7 ] && [ "$(git rev-parse fix/7)" = "$(git rev-parse develop)" ] && \
  echo "$out" | grep -qF "#7 targeted tmp-x, which no longer exists; it now targets develop" && gone_ok=1
aapp issue fix 7 abort >/dev/null 2>&1
git init -q --bare "$R/remote.git"; git remote add origin "$R/remote.git"
git push -q --no-verify origin core:rel-1 >/dev/null 2>&1; git fetch -q origin >/dev/null 2>&1
aapp refine issues "8 on the release branch" branch 8 rel-1 >/dev/null 2>&1; set8="$(cell 8)"
out2="$(aapp issue fix 8 2>&1)"; rc2=$?
remote_ok=0
[ "$set8" = "rel-1" ] && [ "$rc2" -eq 0 ] && [ "$(cell 8)" = "rel-1" ] && [ -d .workspace/fix-8 ] && ! echo "$out2" | grep -qF "no longer exists" && remote_ok=1
aapp issue fix 8 abort >/dev/null 2>&1
if [ "$gone_ok" -eq 1 ] && [ "$remote_ok" -eq 1 ] && [ ! -e .workspace/fix-8 ]; then
  ok "test_gone_branch_falls_back_to_dev"
else
  bad "test_gone_branch_falls_back_to_dev" "gone=$gone_ok remote=$remote_ok rc=$rc/$rc2 7=[$(cell 7)] 8=[$set8] left=$(ls .workspace) out=$out | $out2"
fi

echo "== closing follows the code =="
git worktree add -q "$R/p-core" core && echo "i=core" > "$R/p-core/src/i.sh" && git -C "$R/p-core" commit -qam "core only" --no-verify
CORE_ONLY="$(git -C "$R/p-core" rev-parse --short=7 HEAD)"; git worktree remove "$R/p-core"
head0="$(git -C .plans rev-parse HEAD)"
out="$(aapp issue close 9 sha "$CORE_ONLY" summary "Fixed." 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "develop" && echo "$out" | grep -qF "$CORE_ONLY" && grep -qE '^\| #9 \|' .plans/ISSUES.md && \
   [ "$(git -C .plans rev-parse HEAD)" = "$head0" ]; then
  ok "test_close_refuses_sha_not_in_branch"
else
  bad "test_close_refuses_sha_not_in_branch" "rc=$rc out=$out"
fi

echo "== unblocking follows the code =="
# The waiting plan is the member of the group cut from core: the fix lands on
# develop, which is not that group's parent, so the kit merges nothing (P-83).
aapp refine "$A" blocked 3 >/dev/null 2>&1; aapp refine "$M2" blocked 3 >/dev/null 2>&1
aapp issue fix 3 >/dev/null 2>&1
( cd .workspace/fix-3 && echo "c=2" > src/c.sh && git add src/c.sh && aapp commit "fix: c (#3)" changelog "c fixed" >/dev/null 2>&1 )
g2tip="$(git rev-parse feature/grp-two)"
out="$(aapp issue close 3 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && ! blocked_on "$(pf "$A")" | grep -qE '#3([^0-9]|$)' && blocked_on "$(pf "$M2")" | grep -qE '#3([^0-9]|$)' && \
   echo "$out" | grep -F "$M2" | grep -qF "feature/grp-two" && [ "$(git rev-parse feature/grp-two)" = "$g2tip" ]; then
  ok "test_unblock_waits_for_parent_branch"
else
  bad "test_unblock_waits_for_parent_branch" "rc=$rc A=[$(blocked_on "$(pf "$A")")] M2=[$(blocked_on "$(pf "$M2")")] out=$out"
fi

git fetch -q . develop:feature/grp-two
head0="$(git -C .plans rev-parse HEAD)"
out="$(aapp status 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && ! blocked_on "$(pf "$M2")" | grep -qE '#3([^0-9]|$)' && echo "$out" | grep -F "$M2" | grep -qF "#3" && \
   [ "$(git -C .plans rev-parse HEAD)" != "$head0" ] && [ -z "$(git -C .plans status --porcelain -- current)" ]; then
  ok "test_status_unblocks_after_merge"
else
  bad "test_status_unblocks_after_merge" "rc=$rc M2=[$(blocked_on "$(pf "$M2")")] out=$(echo "$out" | grep -F "$M2")"
fi

aapp refine issues "4 on core" branch 4 core >/dev/null 2>&1
aapp refine "$M" blocked 4 >/dev/null 2>&1
aapp issue fix 4 >/dev/null 2>&1
( cd "$R/p/.workspace/fix-4" && echo "d=2" > src/d.sh && git add src/d.sh && aapp commit "fix: d (#4)" changelog "d fixed" >/dev/null 2>&1 )
aapp issue close 4 >/dev/null 2>&1
FIX4="$(git rev-parse --short=7 core)"
git worktree add -q "$R/p-grp" feature/grp && git -C "$R/p-grp" cherry-pick "$FIX4" >/dev/null 2>&1; git worktree remove --force "$R/p-grp"
out="$(aapp status 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(git show feature/grp:src/d.sh)" = "d=2" ] && blocked_on "$(pf "$M")" | grep -qE '#4([^0-9]|$)' && \
   echo "$out" | grep -F "#4" | grep -F "$FIX4" | grep -qF "feature/grp"; then
  ok "test_cherry_picked_fix_stays_blocked"
else
  bad "test_cherry_picked_fix_stays_blocked" "rc=$rc M=[$(blocked_on "$(pf "$M")")] picked=$(git show feature/grp:src/d.sh) out=$(echo "$out" | grep -F '#4')"
fi

C="$(plan plan-c pc)"; st0="$(grep -m 1 '^\* \*\*Status:\*\*' "$(pf "$C")")"
aapp refine issues "5 on core" branch 5 core >/dev/null 2>&1
aapp refine "$C" blocked 5 >/dev/null 2>&1
out="$(aapp refine "$C" unblocked 5 2>&1)"; rc=$?
still="$(blocked_on "$(pf "$C")")"
aapp issue close 5 sha "$CORE_ONLY" summary "Fixed on core." >/dev/null 2>&1
waits="$(blocked_on "$(pf "$C")")"
out2="$(aapp refine "$C" unblocked 5 2>&1)"; rc2=$?
out3="$(aapp refine "$M" unblocked 4 2>&1)"; rc3=$?
if [ "$rc" -ne 0 ] && echo "$still" | grep -q '#5' && echo "$waits" | grep -q '#5' && [ "$rc2" -eq 0 ] && \
   ! grep -q '^\* \*\*Blocked On:\*\*' "$(pf "$C")" && [ "$(grep -m 1 '^\* \*\*Status:\*\*' "$(pf "$C")")" = "$st0" ] && \
   [ "$rc3" -eq 0 ] && ! blocked_on "$(pf "$M")" | grep -qE '#4([^0-9]|$)' && grep -q '🟥' <(grep -m 1 '^\* \*\*Status:\*\*' "$(pf "$M")") && \
   [ -z "$(git -C .plans status --porcelain -- current)" ]; then
  ok "test_refine_unblocked"
else
  bad "test_refine_unblocked" "rc=$rc/$rc2/$rc3 still=[$still] waits=[$waits] C=[$(grep -E 'Status:|Blocked On' "$(pf "$C")" | tr '\n' ' ')] M=[$(blocked_on "$(pf "$M")")] out=$out | $out2 | $out3"
fi

aapp refine issues "6 on core" branch 6 core >/dev/null 2>&1
aapp refine "$C" blocked 6 >/dev/null 2>&1
out="$(aapp issue abort 6 reason "Not a defect" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -qE '^\| #6 \|.*aborted' .plans/done/000-issues-archive.md && ! grep -q '^\* \*\*Blocked On:\*\*' "$(pf "$C")" && \
   [ "$(grep -m 1 '^\* \*\*Status:\*\*' "$(pf "$C")")" = "$st0" ]; then
  ok "test_abort_ignores_branch_rules"
else
  bad "test_abort_ignores_branch_rules" "rc=$rc C=[$(grep -E 'Status:|Blocked On' "$(pf "$C")" | tr '\n' ' ')] out=$out"
fi

echo "== views =="
# #20 (core) is queued first on the board; #9 (no branch named) follows it.
lout="$(aapp issue list all 2>&1)"; lrc=$?
sout="$(aapp status 2>&1)"; src=$?
first_core="$(echo "$lout" | grep -n '#20 ' | head -1 | cut -d: -f1)"; first_dev="$(echo "$lout" | grep -n '#9 ' | head -1 | cut -d: -f1)"
if [ "$lrc" -eq 0 ] && [ "$src" -eq 0 ] && echo "$lout" | grep -F '#20 ' | grep -qF 'core' && echo "$lout" | grep -F '#9 ' | grep -qF 'develop' && \
   [ -n "$first_core" ] && [ -n "$first_dev" ] && [ "$first_dev" -lt "$first_core" ] && echo "$sout" | grep -F '#9 ' | grep -qF 'develop'; then
  ok "test_views_show_branch"
else
  bad "test_views_show_branch" "rc=$lrc/$src dev line=$first_dev core line=$first_core list=$lout"
fi

echo "== a hotfix outside the plan's files =="
n1="$(git config aapp.issueId)"
out="$(cd "$WM" && aapp issue hotfix "Elsewhere broke" file src/m.sh file src/d.sh 2>&1)"; rc=$?
n2="$(git config aapp.issueId)"
out2="$(cd "$WM" && aapp issue hotfix "Somewhere broke" 2>&1)"; rc2=$?
if [ "$rc" -eq 0 ] && [ "$rc2" -eq 0 ] && grep -qE "^\| #$n1 \|" .plans/ISSUES.md && [ -z "$(cell "$n1")" ] && \
   grep -qE "^\| #$n2 \|" .plans/ISSUES.md && [ -z "$(cell "$n2")" ]; then
  ok "test_hotfix_outside_plan_files_names_no_branch"
else
  bad "test_hotfix_outside_plan_files_names_no_branch" "rc=$rc/$rc2 #$n1=[$(cell "$n1")] #$n2=[$(cell "$n2")] out=$out | $out2"
fi

echo "== the kit removes a branch =="
init_sandbox_project "$R/g"
cd "$R/g" || exit 1
mkdir -p src; echo "a=1" > src/a.sh
git add -A && git commit -qm "sources" --no-verify
git branch develop; git branch module/m
git config aapp.planWorktrees on
git config aapp.commitMode microcommits
git config aapp.integrate ff
git config aapp.issueFixWait 0
{ printf '%s\n' '# Issues' '' "$HDR" "$SEP"; row 1 a; row 2 a; } > .plans/ISSUES.md
printf '%s\n' '# Issue Priority Board' '' '## 🔴 High Priority (Technical Urgency)' '- [ ] #1 -> Defect 1.' '- [ ] #2 -> Defect 2.' > .plans/issues_road_map.md
printf '%s\n' '# Archive' '' '| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- |' > .plans/done/000-issues-archive.md
git -C .plans add -A >/dev/null 2>&1; git -C .plans commit -qm fixture >/dev/null 2>&1
git config aapp.issueId 5
G2="P-$(git config aapp.planId)"; aapp draft grp group >/dev/null 2>&1; resolve_q "$(pf "$G2")"
git -C .plans commit -qam "prep $G2" >/dev/null 2>&1
aapp freeze "$G2" >/dev/null 2>&1 && aapp start "$G2" base module/m >/dev/null 2>&1
M2="$(plan mem-n n "$G2")"; aapp freeze-start "$M2" >/dev/null 2>&1
( cd "$R/g/.workspace/P${M2#P-}" && echo "n=1" > src/n.sh && git add src/n.sh && aapp commit "feat: n" >/dev/null 2>&1 )
aapp done "$M2" >/dev/null 2>&1
aapp refine issues "1 on the feature branch" branch 1 feature/grp >/dev/null 2>&1
before="$(cell 1)"
out="$(aapp done "$G2" 2>&1)"; rc=$?
if [ "$before" = "feature/grp" ] && [ "$rc" -eq 0 ] && ! git rev-parse --verify -q feature/grp >/dev/null && [ "$(cell 1)" = "module/m" ] && \
   [ -z "$(cell 2)" ] && [ -z "$(git -C .plans status --porcelain -- ISSUES.md)" ]; then
  ok "test_group_done_moves_issues_to_parent"
else
  bad "test_group_done_moves_issues_to_parent" "before=[$before] rc=$rc after=[$(cell 1)] out=$out"
fi

print_test_summary "$PASS" "$FAIL"
