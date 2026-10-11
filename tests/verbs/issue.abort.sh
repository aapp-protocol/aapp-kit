#!/usr/bin/env bash
# Tests: `aapp issue abort` (P-76); a part of the issue suite
# (lib/docs/verbs/issue.md, P-68).
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-48s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-48s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

# fixture_ledgers <num>…: active Incubated rows, their road-map lines, an archive holding #5.
fixture_ledgers() {
  local n
  { printf '%s\n' '# Issues' '' '| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |'
    for n in "$@"; do printf '| #%s | `Low` | `CORE` | 2026-10-01 | `lib/f%s.sh` | Defect %s. |  | 🟡 `Incubated` |\n' "$n" "$n" "$n"; done; } > .plans/ISSUES.md
  { printf '%s\n' '# Issue Priority Board' '' '## 🔴 High Priority (Technical Urgency)'
    for n in "$@"; do printf -- '- [ ] #%s -> Defect %s.\n' "$n" "$n"; done; } > .plans/issues_road_map.md
  printf '%s\n' '# Archive' '' '| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- |' \
    '| #5 | `Low` | `CLI` | 2026-08-01 | 2026-08-02 | `0000000` | Old. |' > .plans/done/000-issues-archive.md
  git -C .plans add ISSUES.md issues_road_map.md done/000-issues-archive.md >/dev/null 2>&1; git -C .plans commit -qm fixture >/dev/null 2>&1
  git config aapp.issueId 20; git config aapp.issueFixWait 0
}
draft_plan() {
  local id; id="$(git config --get aapp.planId)"
  aapp draft "$@" >/dev/null 2>&1 || return 1
  echo "P-$id"
}
plan_file() { ls .plans/current/P"${1#P-}"-*.md 2>/dev/null; }
aborted_file() { ls .plans/aborted/P"${1#P-}"-*.md 2>/dev/null; }
prepare() {
  sed -i -E "s|src/path/to/file\.ext|src/$2.sh|g; /src\/path\/to\/new_file\.ext/d; s/^\* \[ \] \*\*Question/* [x] **Question/" "$(plan_file "$1")"
  git -C .plans commit -qam "prepare $1" >/dev/null
}
active() { grep -q "^| #$1 |" .plans/ISSUES.md; }
archived() { grep "^| #$1 |" .plans/done/000-issues-archive.md; }
ARCH=".plans/done/000-issues-archive.md"

echo "== withdrawing an issue =="
init_sandbox_project "$R/s"
cd "$R/s" || exit 1
fixture_ledgers 10 11 12 13 14

out="$(aapp issue abort 10 reason "Not a bug" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && ! active 10 && archived 10 | grep -qF '| `aborted` | Aborted: Not a bug |' && \
   ! grep -q '#10' .plans/issues_road_map.md && [ "$(git -C .plans log -1 --format=%s)" = "issue(abort): withdraw #10" ] && \
   [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_abort_withdraws_row"
else
  bad "test_abort_withdraws_row" "rc=$rc out=$out row=$(archived 10)"
fi

head0="$(git -C .plans rev-parse HEAD)"
out1="$(aapp issue abort 5 2>&1)"; rc1=$?
out2="$(aapp issue abort 99 2>&1)"; rc2=$?
if [ "$rc1" -ne 0 ] && echo "$out1" | grep -qi "already archived" && [ "$rc2" -ne 0 ] && echo "$out2" | grep -qi "not found" && \
   [ "$(git -C .plans rev-parse HEAD)" = "$head0" ]; then
  ok "test_abort_refuses_archived_or_unknown"
else
  bad "test_abort_refuses_archived_or_unknown" "rc=$rc1/$rc2 out=$out1 | $out2"
fi

p="$(draft_plan promoted issue 11)"; pb="$(basename "$(plan_file "$p")")"
out="$(aapp issue abort 11 reason "Duplicate" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -f ".plans/aborted/$pb" ] && [ -z "$(plan_file "$p")" ] && ! active 11 && \
   grep -F "\`$p\`" .plans/aborted/000-aborted-ledger.md | grep -qF "Issue #11 aborted: Duplicate" && \
   archived 11 | grep -qF "| \`aborted\` | Aborted: Duplicate ([$p](../aborted/$pb)) |" && [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_abort_takes_promoted_plan"
else
  bad "test_abort_takes_promoted_plan" "rc=$rc out=$out row=$(archived 11)"
fi

q="$(draft_plan rerun issue 14)"; qb="$(basename "$(plan_file "$q")")"
aapp plan abort "$q" >/dev/null 2>&1
still=0; active 14 && grep '^| #14 |' .plans/ISSUES.md | grep -qF "Incubated" && still=1
out="$(aapp issue abort 14 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$still" -eq 1 ] && ! active 14 && archived 14 | grep -qF "Aborted: Withdrawn ([$q](../aborted/$qb))"; then
  ok "test_abort_rerun_finishes"
else
  bad "test_abort_rerun_finishes" "rc=$rc still=$still out=$out row=$(archived 14)"
fi

echo "== mini plans =="
BUF="$(git rev-parse --git-path aapp_active_plan)"
aapp issue fix 12 file lib/f12.sh >/dev/null 2>&1
out="$(aapp issue fix 12 abort 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ ! -f .plans/current/fix-12.md ] && active 12 && [ -z "$(archived 12)" ]; then
  ok "test_fix_abort_keeps_issue"
else
  bad "test_fix_abort_keeps_issue" "rc=$rc out=$out"
fi

aapp issue fix 12 file lib/f12.sh >/dev/null 2>&1
opened=0; [ -f .plans/current/fix-12.md ] && [ "$(cat "$BUF" 2>/dev/null)" = "#12" ] && opened=1
out="$(aapp issue abort 12 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$opened" -eq 1 ] && [ ! -f .plans/current/fix-12.md ] && [ "$(cat "$BUF" 2>/dev/null)" != "#12" ] && \
   ! active 12 && archived 12 | grep -qF '`aborted`' && [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_abort_drops_mini_plan"
else
  bad "test_abort_drops_mini_plan" "rc=$rc opened=$opened out=$out"
fi

aapp issue fix 13 file lib/f13.sh >/dev/null 2>&1
mkdir -p lib; echo "fixed=1" > lib/f13.sh; git add lib/f13.sh
aapp commit "fix: f13 (#13)" changelog "f13 no longer fails" >/dev/null 2>&1
head0="$(git -C .plans rev-parse HEAD)"
out="$(aapp issue abort 13 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "aapp issue close 13" && [ -f .plans/current/fix-13.md ] && active 13 && \
   [ "$(git -C .plans rev-parse HEAD)" = "$head0" ]; then
  ok "test_abort_refuses_mini_plan_with_commits"
else
  bad "test_abort_refuses_mini_plan_with_commits" "rc=$rc out=$out"
fi
aapp issue close 13 >/dev/null 2>&1

echo "== plans it blocked =="
h="$(draft_plan host)"; prepare "$h" host; hf="$(plan_file "$h")"
aapp freeze-start "$h" >/dev/null 2>&1
aapp issue hotfix "Parser crashes" file lib/x.sh >/dev/null 2>&1
blocked=0; grep -qxF "* **Status:** 🟥 BLOCKED" "$hf" && grep -q '^\* \*\*Blocked On:\*\* #20' "$hf" && blocked=1
out="$(aapp issue abort 20 reason "Misread" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$blocked" -eq 1 ] && [ -f "$hf" ] && grep -qxF "* **Status:** ⚡ In Development" "$hf" && \
   ! grep -q '^\* \*\*Blocked On:\*\*' "$hf" && ! active 20 && archived 20 | grep -qF "Aborted: Misread" && \
   ! grep -q '#20' .plans/issues_road_map.md && echo "$out" | grep -qF "unblocked" && [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_abort_unblocks_plans"
else
  bad "test_abort_unblocks_plans" "rc=$rc blocked=$blocked out=$out status=$(grep -m1 Status "$hf")"
fi

echo "== a plan in its own worktree; a group plan =="
init_sandbox_project "$R/w"
cd "$R/w" || exit 1
git add -A && git commit -qm "track init files" --no-verify
git branch develop
git config aapp.planWorktrees on
fixture_ledgers 10 11
w="$(draft_plan wt issue 10)"; prepare "$w" wt; wf="$(plan_file "$w")"; wt="$R/w/.workspace/P${w#P-}"
aapp freeze-start "$w" >/dev/null 2>&1
( cd "$wt" && mkdir -p src && echo "v=1" > src/wt.sh && git add src/wt.sh && aapp commit "feat: wt" >/dev/null 2>&1 )
echo "v=2" > "$wt/src/wt.sh"
head0="$(git -C .plans rev-parse HEAD)"
out1="$(aapp issue abort 10 2>&1)"; rc1=$?
kept=0; [ -f "$wf" ] && [ -d "$wt" ] && grep '^| #10 |' .plans/ISSUES.md | grep -qF "Planned" && [ "$(git -C .plans rev-parse HEAD)" = "$head0" ] && kept=1
out2="$(aapp issue abort 10 force 2>&1)"; rc2=$?
if [ "$rc1" -ne 0 ] && echo "$out1" | grep -qF "src/wt.sh" && [ "$kept" -eq 1 ] && \
   [ "$rc2" -eq 0 ] && [ ! -d "$wt" ] && [ -n "$(aborted_file "$w")" ] && ! active 10 && [ -n "$(archived 10)" ]; then
  ok "test_abort_plan_refusal_changes_nothing"
else
  bad "test_abort_plan_refusal_changes_nothing" "rc=$rc1/$rc2 kept=$kept out=$out1 | $out2"
fi

g="$(draft_plan grp group)"; gf="$(plan_file "$g")"; gb="$(basename "$gf")"
sed -i -E "s|^\* \*\*Target Issue / Milestone:\*\*.*|* **Target Issue / Milestone:** #11|" "$gf"
sed -i -E "s#^(\| \#11 \|.*\|) +\| 🟡 \`Incubated\` \|\$#\1 [$g](current/$gb) | 🔵 \`Planned\` |#" .plans/ISSUES.md
git -C .plans commit -qam "group promoted from #11" >/dev/null 2>&1
linked=0; grep '^| #11 |' .plans/ISSUES.md | grep -qF "[$g](current/$gb) | 🔵" && linked=1
head0="$(git -C .plans rev-parse HEAD)"
out1="$(aapp issue abort 11 </dev/null 2>&1)"; rc1=$?
kept=0; [ -f "$gf" ] && active 11 && [ "$(git -C .plans rev-parse HEAD)" = "$head0" ] && kept=1
out2="$(aapp issue abort 11 confirm </dev/null 2>&1)"; rc2=$?
if [ "$linked" -eq 1 ] && [ "$rc1" -ne 0 ] && echo "$out1" | grep -qF "confirm" && [ "$kept" -eq 1 ] && \
   [ "$rc2" -eq 0 ] && [ -n "$(aborted_file "$g")" ] && ! active 11; then
  ok "test_abort_group_plan_needs_confirm"
else
  bad "test_abort_group_plan_needs_confirm" "linked=$linked rc=$rc1/$rc2 kept=$kept out=$out1 | $out2"
fi

print_test_summary "$PASS" "$FAIL"
