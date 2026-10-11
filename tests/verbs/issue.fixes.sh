#!/usr/bin/env bash
# Tests: `aapp issue fix` alongside active plans (P-58), in plan worktrees (P-54)
# and for groups (P-64); a part of the issue suite (lib/docs/verbs/issue.md, P-68).
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

echo "== fixes alongside active plans (P-58) =="
init_sandbox_project "$R/wd"
cd "$R/wd" || exit 1
printf '%s\n' '# Issues' '' '| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |' \
  '| #10 | `Low` | `CORE` | 2026-10-01 | `src/host.py` (`HOST_REGEX`) | Host defect. |  | 🟡 `Incubated` |' \
  '| #11 | `Low` | `CORE` | 2026-10-01 | `src/free.py:12-14` | Free defect. |  | 🟡 `Incubated` |' \
  '| #12 | `Low` | `CORE` | 2026-10-01 | `src/busy.py` | Busy defect. |  | 🟡 `Incubated` |' > .plans/ISSUES.md
printf '%s\n' '# Issue Priority Board' '' '## 🔴 High Priority (Technical Urgency)' '- [ ] #10 -> Host.' '- [ ] #11 -> Free.' '- [ ] #12 -> Busy.' > .plans/issues_road_map.md
printf '%s\n' '# Archive' '' '| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- |' > .plans/done/000-issues-archive.md
git -C .plans add ISSUES.md issues_road_map.md done/000-issues-archive.md >/dev/null 2>&1; git -C .plans commit -qm fixture >/dev/null 2>&1
git config aapp.issueId 20; git config aapp.issueFixWait 0
wid="P-$(git config aapp.planId)"; aapp draft side-plan >/dev/null 2>&1
wf="$(ls .plans/current/P"${wid#P-}"-*.md)"
sed -i -E "s|src/path/to/file\.ext|src/host.py|g; s|src/path/to/new_file\.ext|src/other.py|g" "$wf"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$wf"; git -C .plans commit -qam prep >/dev/null 2>&1
mkdir -p src; echo "h=1" > src/host.py; echo "f=1" > src/free.py; echo "b=1" > src/busy.py; echo "o=1" > src/other.py
git add src && git commit -qm "base files" --no-verify >/dev/null 2>&1
aapp freeze-start "$wid" >/dev/null 2>&1

out="$(aapp issue fix 10 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -qxF -- '- [ ] `src/host.py`' .plans/current/fix-10.md && ! grep -qF 'HOST_REGEX' .plans/current/fix-10.md; then
  ok "test_fix_takes_only_paths_from_location"
else
  bad "test_fix_takes_only_paths_from_location" "rc=$rc out=$out targets=$(grep -F -- '- [ ]' .plans/current/fix-10.md 2>/dev/null | tr '\n' ' ')"
fi
echo "h=2" > src/host.py; git add src/host.py; aapp commit "fix: host (#10)" changelog "host fixed" >/dev/null 2>&1
out="$(aapp issue close 10 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -qF "$wid also lists src/host.py: it picks this fix up at its next rebase."; then
  ok "test_close_notices_other_plan_listing_fixed_file"
else
  bad "test_close_notices_other_plan_listing_fixed_file" "rc=$rc out=$out"
fi

out="$(aapp issue fix 11 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -qxF -- '- [ ] `src/free.py`' .plans/current/fix-11.md; then
  ok "test_fix_strips_line_suffix_from_location"
else
  bad "test_fix_strips_line_suffix_from_location" "rc=$rc out=$out"
fi
echo "f=2" > src/free.py; git add src/free.py; aapp commit "fix: free (#11)" changelog "free fixed" >/dev/null 2>&1
out="$(aapp issue close 11 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && ! echo "$out" | grep -qF "also lists"; then
  ok "test_close_no_notice_when_unlisted"
else
  bad "test_close_no_notice_when_unlisted" "rc=$rc out=$out"
fi

head0="$(git -C .plans rev-parse HEAD)"
echo "h=3" > src/host.py
out="$(aapp issue fix 12 file src/host.py 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "aapp issue hotfix" && ! echo "$out" | grep -qF "commit or stash" && \
   [ ! -f .plans/current/fix-12.md ] && [ "$(git -C .plans rev-parse HEAD)" = "$head0" ]; then
  ok "test_fix_timeout_on_bound_plan_file_hints_hotfix"
else
  bad "test_fix_timeout_on_bound_plan_file_hints_hotfix" "rc=$rc out=$out"
fi
echo "h=2" > src/host.py

echo "b=2" > src/busy.py
out="$(aapp issue fix 12 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "src/busy.py has uncommitted changes" && ! echo "$out" | grep -qF "hotfix" && \
   ! echo "$out" | grep -qF "waiting" && [ ! -f .plans/current/fix-12.md ]; then
  ok "test_fix_wait_zero_refuses_at_once"
else
  bad "test_fix_wait_zero_refuses_at_once" "rc=$rc out=$out"
fi

git config aapp.issueFixWait 1
( sleep 3; echo "b=1" > src/busy.py ) &
out="$(aapp issue fix 12 2>&1)"; rc=$?
wait
if [ "$rc" -eq 0 ] && echo "$out" | grep -qF "src/busy.py has uncommitted changes here; waiting" && [ -f .plans/current/fix-12.md ]; then
  ok "test_fix_waits_for_dirty_file_then_proceeds"
else
  bad "test_fix_waits_for_dirty_file_then_proceeds" "rc=$rc out=$out"
fi
aapp issue fix 12 abort >/dev/null 2>&1

sed -i '/^## 🔴/i ## 🧱 Plan Blockers\n- [ ] #12 -> Busy (blocks X)\n' .plans/issues_road_map.md
git -C .plans commit -qam "queue #12" >/dev/null 2>&1
echo "b=2" > src/busy.py
git config aapp.issueFixWait 0
out="$(aapp issue fix next-blocker 2>&1)"; rc0=$?
git config aapp.issueFixWait 1
( sleep 3; echo "b=1" > src/busy.py ) &
out1="$(aapp issue fix next-blocker 2>&1)"; rc1=$?
wait
git config aapp.issueFixWait 0
if [ "$rc0" -ne 0 ] && [ "$rc1" -eq 0 ] && echo "$out1" | grep -qF "waiting" && [ -f .plans/current/fix-12.md ]; then
  ok "test_next_blocker_waits_when_every_blocker_is_dirty"
else
  bad "test_next_blocker_waits_when_every_blocker_is_dirty" "rc=$rc0/$rc1 out=$out | $out1"
fi

echo "== issue fixes are not made in a plan worktree (P-54) =="
aapp issue fix 12 abort >/dev/null 2>&1
git branch -f develop HEAD
git config aapp.planWorktrees on
pw="P-$(git config aapp.planId)"; aapp draft wt-host >/dev/null 2>&1
pwf="$(ls .plans/current/P"${pw#P-}"-*.md)"
sed -i -E "s|src/path/to/file\.ext|src/wt_host.py|g; /src\/path\/to\/new_file\.ext/d" "$pwf"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$pwf"; git -C .plans commit -qam prep >/dev/null 2>&1
aapp freeze-start "$pw" >/dev/null 2>&1
git config aapp.planWorktrees off
head0="$(git -C .plans rev-parse HEAD)"
cd "$R/wd/.workspace/P${pw#P-}" || exit 1
out="$(aapp issue fix 12 2>&1)"; rc=$?
cd "$R/wd" || exit 1
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "$R/wd" && echo "$out" | grep -qi "plan worktree" && \
   [ ! -f .plans/current/fix-12.md ] && [ "$(git -C .plans rev-parse HEAD)" = "$head0" ]; then
  ok "test_fix_refused_inside_plan_worktree"
else
  bad "test_fix_refused_inside_plan_worktree" "rc=$rc out=$out"
fi

echo "== fixes and groups (P-64) =="
init_sandbox_project "$R/gx"
cd "$R/gx" || exit 1
mkdir -p src && echo "g=1" > src/g.sh && echo "h=1" > src/h.sh
git add -A && git commit -qm "track init files" --no-verify
git branch develop
git config aapp.planWorktrees on
git config aapp.commitMode microcommits
git config aapp.issueFixWait 0
printf '%s\n' '# Issues' '' '| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |' \
  '| #3 | `Low` | `CORE` | 2026-10-11 | `src/g.sh` | Group code wrong |  | 🟡 `Incubated` |' \
  '| #4 | `Low` | `CORE` | 2026-10-11 | `src/h.sh` | Shared code wrong |  | 🟡 `Incubated` |' > .plans/ISSUES.md
printf '%s\n' '# Issue Priority Board' '' '## 🔴 High Priority (Technical Urgency)' '- [ ] #3 -> Group code wrong.' '- [ ] #4 -> Shared code wrong.' > .plans/issues_road_map.md
printf '%s\n' '# Archive' '' '| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- |' > .plans/done/000-issues-archive.md
git -C .plans add ISSUES.md issues_road_map.md done/000-issues-archive.md >/dev/null 2>&1; git -C .plans commit -qm fixture >/dev/null 2>&1
git config aapp.issueId 5
GXPRIM="$(git rev-parse --abbrev-ref HEAD)"

head0="$(git -C .plans rev-parse HEAD)"
out="$(aapp issue fix 3 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "develop" && [ ! -f .plans/current/fix-3.md ] && [ "$(git -C .plans rev-parse HEAD)" = "$head0" ]; then
  ok "test_fix_refuses_off_development_branch"
else
  bad "test_fix_refuses_off_development_branch" "rc=$rc out=$out"
fi

gid="P-$(git config aapp.planId)"; aapp draft fixgrp group >/dev/null 2>&1
gfile="$(ls .plans/current/P"${gid#P-}"-*.md)"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$gfile"; git -C .plans commit -qam prep >/dev/null 2>&1
aapp freeze-start "$gid" >/dev/null 2>&1
fsha0="$(git rev-parse feature/fixgrp)"; dev0="$(git rev-parse develop)"
out="$(aapp issue fix 3 group "$gid" 2>&1)"; rc=$?
fwt="$R/gx/.workspace/fix-3"
opened=0; [ "$rc" -eq 0 ] && [ -d "$fwt" ] && [ "$(git -C "$fwt" rev-parse HEAD)" = "$fsha0" ] && \
  [ "$(git -C "$fwt" rev-parse --abbrev-ref HEAD)" = "fix/3" ] && opened=1
( cd "$fwt" && echo "g=2" > src/g.sh && git add src/g.sh && aapp commit "fix: group code (#3)" changelog "group code fixed" >/dev/null 2>&1 )
out2="$(aapp issue close 3 2>&1)"; rc2=$?
if [ "$opened" -eq 1 ] && [ "$rc2" -eq 0 ] && [ "$(git show feature/fixgrp:src/g.sh)" = "g=2" ] && \
   [ "$(git rev-parse develop)" = "$dev0" ] && [ ! -d "$fwt" ] && ! git rev-parse --verify -q fix/3 >/dev/null && \
   ! grep -qE '^\| #3 \|' .plans/ISSUES.md && [ ! -f .plans/current/fix-3.md ]; then
  ok "test_fix_group_opens_worktree_and_close_integrates"
else
  bad "test_fix_group_opens_worktree_and_close_integrates" "rc=$rc/$rc2 opened=$opened out=$out | $out2"
fi

# The group changed src/h.sh on its feature branch; a fix of #4 on develop hints at the group.
git worktree add -q "$R/gx-feat" feature/fixgrp && echo "h=group" > "$R/gx-feat/src/h.sh" && \
  git -C "$R/gx-feat" commit -qam "group work on h" --no-verify && git worktree remove "$R/gx-feat"
git checkout -q develop
out="$(aapp issue fix 4 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -qF "group $gid" && [ -f .plans/current/fix-4.md ]; then
  ok "test_fix_hints_group_for_group_files"
else
  bad "test_fix_hints_group_for_group_files" "rc=$rc out=$out"
fi
aapp issue fix 4 abort >/dev/null 2>&1
git checkout -q "$GXPRIM"

print_test_summary "$PASS" "$FAIL"
