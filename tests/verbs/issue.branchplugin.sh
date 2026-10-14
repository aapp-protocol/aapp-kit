#!/usr/bin/env bash
# Tests: `aapp issue` behaviour contract (lib/docs/verbs/issue.md)
# Part: issue.branchplugin.sh (the team's `aapp-issue-branch` plugin names the
# branch a fix lands on; a fix on a group's parent comes back to its feature
# branch, P-83).
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

HDR='| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |'
SEP='| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |'
ARCH='| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |'
ASEP='| :--- | :--- | :--- | :--- | :--- | :--- | :--- |'
# row <n> <location-cell>
row() { printf '| #%s | `Low` | `CORE` | 2026-10-01 | %s | Defect %s shows. |  | 🟡 `Incubated` |\n' "$1" "$2" "$1"; }
pf() { ls .plans/current/P"${1#P-}"-*.md 2>/dev/null; }
resolve_q() { sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$1"; }
cell() {
  awk -F'|' -v id="#$1" '
    !col && /^\|[[:space:]]*#[[:space:]]*\|/ { for (i = 2; i <= NF; i++) { h = $i; gsub(/^[ \t]+|[ \t]+$/, "", h); if (h == "Branch") col = i } next }
    { c = $2; gsub(/[ \t`]/, "", c) }
    c == id { if (col) { v = $col; gsub(/[ \t`]/, "", v); print v } exit }' .plans/ISSUES.md
}
blocked_on() { sed -nE 's/^\* \*\*Blocked On:\*\*[[:space:]]*//p' "$1" | head -n 1; }
# plan <slug> <file> [<group>]: a drafted plan targeting src/<file>.sh; prints its id.
plan() {
  local id f; id="P-$(git config aapp.planId)"; aapp draft "$1" ${3:+group "$3"} >/dev/null 2>&1; f="$(pf "$id")"
  sed -i -E "s|src/path/to/file\.ext|src/$2.sh|g; /src\/path\/to\/new_file\.ext/d" "$f"; resolve_q "$f"
  git -C .plans commit -qam "prep $id" >/dev/null 2>&1
  echo "$id"
}
# sandbox <dir> <rows…>: a project on develop with core and modx branches and a ledger.
sandbox() {
  local d="$1" n; shift
  init_sandbox_project "$d"
  cd "$d" || exit 1
  mkdir -p src/core src/modx; for n in a b c d e f g h i; do echo "$n=1" > "src/$n.sh"; done
  echo "x=1" > src/core/x.sh; echo "y=1" > src/modx/y.sh
  git add -A && git commit -qm "sources" --no-verify
  git branch develop; git branch core; git branch modx
  git checkout -q develop
  git config aapp.planWorktrees on; git config aapp.commitMode microcommits; git config aapp.integrate ff
  git config aapp.issueFixWait 0; git config aapp.pluginTimeout 2; git config aapp.maxEmergencyHotfixes 9
  { printf '%s\n' '# Issues' '' "$HDR" "$SEP"; printf '%s\n' "$@"; } > .plans/ISSUES.md
  { printf '%s\n' '# Issue Priority Board' '' '## 🔴 High Priority (Technical Urgency)'
    printf '%s\n' "$@" | sed -nE 's/^\| (#[0-9]+) .*/- [ ] \1 -> Defect./p'; } > .plans/issues_road_map.md
  printf '%s\n' '# Archive' '' "$ARCH" "$ASEP" > .plans/done/000-issues-archive.md
  git -C .plans add -A >/dev/null 2>&1; git -C .plans commit -qm fixture >/dev/null 2>&1
  git config aapp.issueId 40
}

sandbox "$R/p" "$(row 1 '`src/a.sh`')" "$(row 2 '`src/b.sh`')" "$(row 3 '`src/c.sh`')" "$(row 4 '`src/d.sh`')" \
  "$(row 5 '`src/e.sh`')" "$(row 6 '`src/f.sh`')" "$(row 7 '`src/g.sh`')" "$(row 8 '`src/h.sh`')" "$(row 9 '`src/i.sh`')" \
  "$(row 10 '`src/core/x.sh`')" "$(row 11 '`main.py`')" "$(row 12 '`src/core/x.sh`, `src/modx/y.sh`')"
PDIR=".agents/skills/aapp-issue-branch"
# plugin <body…>: installs the branch plugin. It records each call and the
# envelope it got, then runs the given lines. It never calls `aapp` itself.
plugin() {
  mkdir -p "$PDIR"
  { echo '#!/bin/sh'; echo "cat > \"$R/payload\"; echo call >> \"$R/calls\""; printf '%s\n' "$@"; } > "$PDIR/run"; chmod +x "$PDIR/run"
}
answer() { plugin "echo '$1'"; }
calls() { wc -l < "$R/calls" 2>/dev/null | tr -d ' ' || echo 0; }
reset_calls() { : > "$R/calls"; }
opened_on_dev() { [ -f ".plans/current/fix-$1.md" ] && opened_from "$1" develop; }
opened_from() { [ -d ".workspace/fix-$1" ] && [ "$(git -C ".workspace/fix-$1" rev-parse HEAD)" = "$(git rev-parse "$2")" ]; }
nothing_opened() { [ ! -f ".plans/current/fix-$1.md" ] && [ ! -e ".workspace/fix-$1" ]; }

echo "== the answer =="
reset_calls; answer '{"status": "ok", "branch": "core"}'
out="$(aapp issue fix 1 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && opened_from 1 core && [ "$(cell 1)" = "core" ] && [ "$(calls)" = "1" ]; then
  ok "test_answered_branch_opens_fix_there"
else
  bad "test_answered_branch_opens_fix_there" "rc=$rc cell=[$(cell 1)] calls=$(calls) out=$out"
fi
aapp issue fix 1 abort >/dev/null 2>&1
reset_calls
out="$(aapp issue fix 1 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && opened_from 1 core && [ "$(calls)" = "0" ]; then
  ok "test_answer_recorded_once"
else
  bad "test_answer_recorded_once" "rc=$rc calls=$(calls) out=$out"
fi
aapp issue fix 1 abort >/dev/null 2>&1

answer '{"status": "declined"}'
out="$(aapp issue fix 2 2>&1)"; rc=$?
d1=0; [ "$rc" -eq 0 ] && opened_on_dev 2 && [ -z "$(cell 2)" ] && d1=1
aapp issue fix 2 abort >/dev/null 2>&1
answer '{"status": "ok", "branch": "develop"}'
out2="$(aapp issue fix 2 2>&1)"; rc2=$?
d2=0; [ "$rc2" -eq 0 ] && opened_on_dev 2 && [ -z "$(cell 2)" ] && d2=1
aapp issue fix 2 abort >/dev/null 2>&1
if [ "$d1" -eq 1 ] && [ "$d2" -eq 1 ]; then
  ok "test_declined_is_dev_branch"
else
  bad "test_declined_is_dev_branch" "declined=$d1 develop=$d2 rc=$rc/$rc2 cell=[$(cell 2)] out=$out | $out2"
fi

rm -rf "$PDIR"
out="$(aapp issue fix 3 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && opened_on_dev 3 && [ -z "$(cell 3)" ]; then
  ok "test_no_plugin_is_dev_branch"
else
  bad "test_no_plugin_is_dev_branch" "rc=$rc out=$out"
fi
aapp issue fix 3 abort >/dev/null 2>&1

echo "== a plugin that cannot answer =="
head0="$(git -C .plans rev-parse HEAD)"; fails=""
# refused <label>: `fix 4` must refuse, write nothing and name the way past.
refused() {
  local o r; o="$(aapp issue fix 4 2>&1)"; r=$?
  if [ "$r" -ne 0 ] && nothing_opened 4 && [ "$(git -C .plans rev-parse HEAD)" = "$head0" ] && [ -z "$(cell 4)" ] && \
     [ -z "$(git -C .plans status --porcelain)" ] && echo "$o" | grep -qF 'aapp refine issues "<msg>" branch 4 <name>'; then return 0; fi
  fails="$fails $1(rc=$r: $o)"; aapp issue fix 4 abort >/dev/null 2>&1; return 0
}
answer '{"status": "failed"}';                 refused failed
plugin 'exit 3';                               refused exit
plugin 'sleep 6' "echo '{\"status\": \"ok\", \"branch\": \"core\"}'"; refused timeout
answer '{"status": "ok"}';                     refused no-branch
answer '{"status": "ok", "branch": "no-such"}'; refused unknown-branch
if [ -z "$fails" ]; then
  ok "test_failure_refuses_fix"
else
  bad "test_failure_refuses_fix" "$fails"
fi

answer '{"status": "failed", "message": "src/d.sh is owned by core and by modx"}'
out="$(aapp issue fix 4 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && nothing_opened 4 && echo "$out" | grep -qF "src/d.sh is owned by core and by modx"; then
  ok "test_plugin_message_is_shown"
else
  bad "test_plugin_message_is_shown" "rc=$rc out=$out"
fi

echo "== when it is not asked =="
answer '{"status": "ok", "branch": "modx"}'
aapp refine issues "5 belongs to core" branch 5 core >/dev/null 2>&1
reset_calls
out="$(aapp issue fix 5 2>&1)"; rc=$?
named=0; [ "$rc" -eq 0 ] && opened_from 5 core && [ "$(calls)" = "0" ] && named=1
aapp issue fix 5 abort >/dev/null 2>&1
G="P-$(git config aapp.planId)"; aapp draft grp group >/dev/null 2>&1; resolve_q "$(pf "$G")"
git -C .plans commit -qam "prep $G" >/dev/null 2>&1; aapp freeze-start "$G" >/dev/null 2>&1
reset_calls
out2="$(aapp issue fix 6 group "$G" 2>&1)"; rc2=$?
grouped=0; [ "$rc2" -eq 0 ] && opened_from 6 feature/grp && [ "$(calls)" = "0" ] && grouped=1
aapp issue fix 6 abort >/dev/null 2>&1
if [ "$named" -eq 1 ] && [ "$grouped" -eq 1 ]; then
  ok "test_named_branch_is_not_asked"
else
  bad "test_named_branch_is_not_asked" "named=$named group=$grouped rc=$rc/$rc2 calls=$(calls) out=$out | $out2"
fi

reset_calls
sout="$(aapp status 2>&1)"; lout="$(aapp issue list all 2>&1)"
if [ "$(calls)" = "0" ] && [ -n "$sout" ] && [ -n "$lout" ]; then
  ok "test_views_do_not_ask"
else
  bad "test_views_do_not_ask" "calls=$(calls)"
fi

echo "== what it is sent =="
git remote add origin "https://someone:s3cr3t@example.com/team/project.git"
answer '{"status": "declined"}'
out="$(aapp issue fix 7 file src/extra.sh 2>&1)"; rc=$?
p="$(cat "$R/payload" 2>/dev/null)"
if [ "$rc" -eq 0 ] && echo "$p" | grep -qF '"issue.branch"' && echo "$p" | grep -qF '"#7"' && echo "$p" | grep -qF 'Defect 7 shows.' && \
   echo "$p" | grep -qE '"files": *\[ *"src/g\.sh", *"src/extra\.sh" *\]' && echo "$p" | grep -qF '"sev"' && ! echo "$p" | grep -qF 's3cr3t'; then
  ok "test_payload_carries_issue_and_files"
else
  bad "test_payload_carries_issue_and_files" "rc=$rc payload=$p"
fi
aapp issue fix 7 abort >/dev/null 2>&1
git remote remove origin

echo "== next-blocker and a direct close =="
sed -i '/^## 🔴/i ## 🧱 Plan Blockers\n- [ ] #8 -> Defect (blocks X)\n' .plans/issues_road_map.md
git -C .plans commit -qam "queue #8" >/dev/null 2>&1
reset_calls; answer '{"status": "ok", "branch": "modx"}'
out="$(aapp issue fix next-blocker 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && opened_from 8 modx && [ "$(cell 8)" = "modx" ] && [ "$(calls)" = "1" ]; then
  ok "test_next_blocker_asks"
else
  bad "test_next_blocker_asks" "rc=$rc cell=[$(cell 8)] calls=$(calls) out=$out"
fi
aapp issue fix 8 abort >/dev/null 2>&1

DEV_SHA="$(git rev-parse --short=7 develop)"
git worktree add -q "$R/p-core" core && echo "x=core" > "$R/p-core/src/core/x.sh" && git -C "$R/p-core" commit -qam "core only" --no-verify
CORE_SHA="$(git -C "$R/p-core" rev-parse --short=7 HEAD)"; git worktree remove "$R/p-core"
answer '{"status": "ok", "branch": "core"}'
git commit -q --allow-empty -m "develop moves" --no-verify; DEV_ONLY="$(git rev-parse --short=7 HEAD)"
out="$(aapp issue close 9 sha "$DEV_ONLY" summary "Fixed." 2>&1)"; rc=$?
c1=0; [ "$rc" -ne 0 ] && grep -qE '^\| #9 \|' .plans/ISSUES.md && echo "$out" | grep -qF "core" && c1=1
answer '{"status": "failed", "message": "ask the core team"}'
out2="$(aapp issue close 9 sha "$CORE_SHA" summary "Fixed." 2>&1)"; rc2=$?
c2=0; [ "$rc2" -ne 0 ] && grep -qE '^\| #9 \|' .plans/ISSUES.md && echo "$out2" | grep -qF "ask the core team" && c2=1
answer '{"status": "ok", "branch": "core"}'
out3="$(aapp issue close 9 sha "$CORE_SHA" summary "Fixed." 2>&1)"; rc3=$?
c3=0; [ "$rc3" -eq 0 ] && ! grep -qE '^\| #9 \|' .plans/ISSUES.md && grep -E '^\| #9 \|' .plans/done/000-issues-archive.md | grep -qF 'core' && c3=1
if [ "$c1" -eq 1 ] && [ "$c2" -eq 1 ] && [ "$c3" -eq 1 ]; then
  ok "test_direct_close_asks"
else
  bad "test_direct_close_asks" "outside=$c1 failed=$c2 inside=$c3 rc=$rc/$rc2/$rc3 dev=$DEV_SHA out=$out | $out2 | $out3"
fi

echo "== the shipped sample =="
rm -rf "$PDIR"; mkdir -p "$PDIR"
cp "$KIT/examples/plugins/aapp-issue-branch/run.sample" "$PDIR/run" 2>/dev/null; chmod +x "$PDIR/run" 2>/dev/null
printf '%s\n' '# path prefix	branch' 'src/core/	core' 'src/modx/	modx' > "$PDIR/branches"
out="$(aapp issue fix 10 2>&1)"; rc=$?
s1=0; [ "$rc" -eq 0 ] && opened_from 10 core && [ "$(cell 10)" = "core" ] && s1=1
aapp issue fix 10 abort >/dev/null 2>&1
out2="$(aapp issue fix 11 2>&1)"; rc2=$?
s2=0; [ "$rc2" -eq 0 ] && opened_on_dev 11 && [ -z "$(cell 11)" ] && s2=1
aapp issue fix 11 abort >/dev/null 2>&1
out3="$(aapp issue fix 12 2>&1)"; rc3=$?
s3=0; [ "$rc3" -ne 0 ] && nothing_opened 12 && echo "$out3" | grep -F "core" | grep -qF "modx" && s3=1
if [ "$s1" -eq 1 ] && [ "$s2" -eq 1 ] && [ "$s3" -eq 1 ]; then
  ok "test_sample_maps_paths"
else
  bad "test_sample_maps_paths" "match=$s1 none=$s2 two=$s3 rc=$rc/$rc2/$rc3 out=$out | $out2 | $out3"
fi

echo "== a fix on a group's parent comes back to its feature branch =="
sandbox "$R/g" "$(row 1 '`src/a.sh`')" "$(row 2 '`src/b.sh`')" "$(row 3 '`src/c.sh`')" "$(row 4 '`src/d.sh`')" "$(row 5 '`src/e.sh`')"
G="P-$(git config aapp.planId)"; aapp draft grp group >/dev/null 2>&1; resolve_q "$(pf "$G")"
git -C .plans commit -qam "prep $G" >/dev/null 2>&1; aapp freeze-start "$G" >/dev/null 2>&1
M="$(plan mem-m m "$G")"; aapp freeze-start "$M" >/dev/null 2>&1
# fix_on_develop <n> <file>: a fix made and committed in the main checkout, left open.
fix_on_develop() {
  aapp issue fix "$1" >/dev/null 2>&1
  ( cd ".workspace/fix-$1" && echo "$2=fixed" > "src/$2.sh" && git add "src/$2.sh" && aapp commit "fix: $2 (#$1)" changelog "$2 fixed" >/dev/null 2>&1 )
}

# The feature branch has work of its own, so taking develop in is a real merge.
git worktree add -q "$R/g-feat" feature/grp && echo "f=group" > "$R/g-feat/src/f.sh" && git -C "$R/g-feat" commit -qam "group work on f" --no-verify
git worktree remove "$R/g-feat"
aapp refine "$M" blocked 1 >/dev/null 2>&1
fix_on_develop 1 a; FIX1="$(git rev-parse HEAD)"
out="$(aapp issue close 1 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && git merge-base --is-ancestor "$FIX1" feature/grp && [ "$(git rev-list --merges --count develop..feature/grp)" = "1" ] && \
   ! grep -q '^\* \*\*Blocked On:\*\*' "$(pf "$M")" && echo "$out" | grep -F "feature/grp" | grep -qiF "merged" && echo "$out" | grep -qiF "rebase"; then
  ok "test_close_merges_group_parent_into_feature"
else
  bad "test_close_merges_group_parent_into_feature" "rc=$rc merged=$(git merge-base --is-ancestor "$FIX1" feature/grp && echo yes || echo no) M=[$(blocked_on "$(pf "$M")")] out=$out"
fi

# A plan promoted from #4 closes it at `done` and integrates into develop.
D="P-$(git config aapp.planId)"; aapp draft promo issue 4 >/dev/null 2>&1; df="$(pf "$D")"
sed -i -E "s|src/path/to/file\.ext|src/d.sh|g; /src\/path\/to\/new_file\.ext/d" "$df"; resolve_q "$df"
git -C .plans commit -qam "prep $D" >/dev/null 2>&1; aapp freeze-start "$D" >/dev/null 2>&1
aapp refine "$M" blocked 4 >/dev/null 2>&1
( cd "$R/g/.workspace/P${D#P-}" && echo "d=fixed" > src/d.sh && git add src/d.sh && aapp commit "fix: d by plan" >/dev/null 2>&1 )
out="$(aapp done "$D" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(git show feature/grp:src/d.sh 2>/dev/null)" = "d=fixed" ] && ! grep -q '^\* \*\*Blocked On:\*\*' "$(pf "$M")"; then
  ok "test_done_merges_group_parent_into_feature"
else
  bad "test_done_merges_group_parent_into_feature" "rc=$rc feature=$(git show feature/grp:src/d.sh 2>/dev/null) M=[$(blocked_on "$(pf "$M")")] out=$out"
fi

# A plan whose parent is a branch the team owns (modx): its Base names it.
T="$(plan team-plan t)"; tf="$(pf "$T")"
sed -i -E "s|^\* \*\*Base:\*\*.*|* **Base:** \`$(git rev-parse --short modx)\` (modx)|" "$tf"; git -C .plans commit -qam "base $T" >/dev/null 2>&1
aapp refine "$T" blocked 2 >/dev/null 2>&1
modx0="$(git rev-parse modx)"
fix_on_develop 2 b
out="$(aapp issue close 2 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(git rev-parse modx)" = "$modx0" ] && blocked_on "$tf" | grep -q '#2' && echo "$out" | grep -F "$T" | grep -qF "modx"; then
  ok "test_team_branch_is_not_merged"
else
  bad "test_team_branch_is_not_merged" "rc=$rc modx moved=$([ "$(git rev-parse modx)" = "$modx0" ] && echo no || echo yes) T=[$(blocked_on "$tf")] out=$out"
fi

# A fix on core, which is not the group's parent (develop).
aapp refine issues "3 on core" branch 3 core >/dev/null 2>&1
aapp refine "$M" blocked 3 >/dev/null 2>&1
aapp issue fix 3 >/dev/null 2>&1
( cd "$R/g/.workspace/fix-3" && echo "c=fixed" > src/c.sh && git add src/c.sh && aapp commit "fix: c (#3)" changelog "c fixed" >/dev/null 2>&1 )
fb0="$(git rev-parse feature/grp)"
out="$(aapp issue close 3 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(git show core:src/c.sh)" = "c=fixed" ] && [ "$(git rev-parse feature/grp)" = "$fb0" ] && blocked_on "$(pf "$M")" | grep -q '#3'; then
  ok "test_fix_on_third_branch_is_not_merged"
else
  bad "test_fix_on_third_branch_is_not_merged" "rc=$rc feature moved=$([ "$(git rev-parse feature/grp)" = "$fb0" ] && echo no || echo yes) M=[$(blocked_on "$(pf "$M")")] out=$out"
fi

# The feature branch and develop change the same line: the merge cannot be made.
git worktree add -q "$R/g-feat" feature/grp && echo "e=group" > "$R/g-feat/src/e.sh" && git -C "$R/g-feat" commit -qam "group work on e" --no-verify
git worktree remove "$R/g-feat"
aapp refine "$M" blocked 5 >/dev/null 2>&1
fix_on_develop 5 e
fb0="$(git rev-parse feature/grp)"
out="$(aapp issue close 5 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(git rev-parse feature/grp)" = "$fb0" ] && blocked_on "$(pf "$M")" | grep -q '#5' && \
   echo "$out" | grep -F "feature/grp" | grep -qiF "does not merge cleanly" && [ -z "$(git worktree list | grep -v "$R/g")" ]; then
  ok "test_merge_conflict_changes_nothing"
else
  bad "test_merge_conflict_changes_nothing" "rc=$rc feature moved=$([ "$(git rev-parse feature/grp)" = "$fb0" ] && echo no || echo yes) M=[$(blocked_on "$(pf "$M")")] out=$out"
fi

print_test_summary "$PASS" "$FAIL"
