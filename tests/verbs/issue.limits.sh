#!/usr/bin/env bash
# Tests: issue fix safeguards (P-82): file and line limits, declared files with reason,
# and collision detection with plans in development (lib/docs/verbs/issue.md).
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

echo "== fix limits and declared files (P-82) =="
init_sandbox_project "$R/sbox"
cd "$R/sbox" || exit 1
git config aapp.issueFixWait 0

# Base files
mkdir -p src
for i in 1 2 3 4 5; do echo "f$i" > "src/f$i.sh"; done
echo "shared=1" > src/shared.sh
echo "blocked=1" > src/blocked.sh
git add src CHANGELOG.md && git commit -qm "base files" --no-verify

# Issues fixture
printf '%s\n' '# Issues' '' '| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |' \
  '| #1 | `Low` | `CORE` | 2026-10-01 | `src/f1.sh` | File limit issue. |  | 🟡 `Incubated` |' \
  '| #2 | `Low` | `CORE` | 2026-10-01 | `src/f1.sh` | Line limit issue. |  | 🟡 `Incubated` |' \
  '| #3 | `Low` | `CORE` | 2026-10-01 | `src/f1.sh` | Configurable limits. |  | 🟡 `Incubated` |' \
  '| #4 | `Low` | `CORE` | 2026-10-01 | `src/f1.sh` | Reason required issue. |  | 🟡 `Incubated` |' \
  '| #5 | `Low` | `CORE` | 2026-10-01 | `src/f1.sh` | Undeclared file issue. |  | 🟡 `Incubated` |' \
  '| #6 | `Low` | `CORE` | 2026-10-01 | `src/shared.sh` | Collision issue. |  | 🟡 `Incubated` |' \
  '| #7 | `Low` | `CORE` | 2026-10-01 | `src/blocked.sh` | Hotfix blocked plan issue. |  | 🟡 `Incubated` |' > .plans/ISSUES.md

printf '%s\n' '# 🗺️ Issue Work Queue' '' '## 📋 Queued' \
  '- [ ] #1 -> File limit.' \
  '- [ ] #2 -> Line limit.' \
  '- [ ] #3 -> Configurable limits.' \
  '- [ ] #4 -> Reason required.' \
  '- [ ] #5 -> Undeclared file.' \
  '- [ ] #6 -> Collision.' \
  '- [ ] #7 -> Blocked plan.' > .plans/issues_road_map.md

printf '%s\n' '# Archive' '' '| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- |' > .plans/done/000-issues-archive.md
git -C .plans add -A >/dev/null 2>&1; git -C .plans commit -qm "issues fixture" --no-verify >/dev/null 2>&1

# 1. test_close_refuses_over_file_limit
aapp issue fix 1 >/dev/null 2>&1
aapp issue fix 1 file src/f2.sh "need second" >/dev/null 2>&1
aapp issue fix 1 file src/f3.sh "need third" >/dev/null 2>&1
aapp issue fix 1 file src/f4.sh "need fourth" >/dev/null 2>&1
( cd .workspace/fix-1 && \
  echo "mod1" >> src/f1.sh && \
  echo "mod2" >> src/f2.sh && \
  echo "mod3" >> src/f3.sh && \
  echo "mod4" >> src/f4.sh && \
  git add src/ && \
  aapp commit "fix: 4 files (#1)" changelog "fix 4 files" >/dev/null 2>&1 )
out1="$(aapp issue close 1 2>&1)"; rc1=$?
if [ "$rc1" -ne 0 ] && echo "$out1" | grep -q "4 files" && echo "$out1" | grep -q "limit.*3" && \
   echo "$out1" | grep -qF "aapp issue fix 1 abort" && echo "$out1" | grep -qF "aapp draft" && \
   grep -qF '| #1 |' .plans/ISSUES.md; then
  ok "test_close_refuses_over_file_limit"
else
  bad "test_close_refuses_over_file_limit" "rc=$rc1 out=$out1"
fi
aapp issue fix 1 abort >/dev/null 2>&1

# 2. test_close_refuses_over_line_limit
aapp issue fix 2 >/dev/null 2>&1
( cd .workspace/fix-2 && \
  for l in $(seq 1 30); do echo "line $l" >> src/f1.sh; done && \
  git add src/f1.sh && \
  aapp commit "fix: 30 lines (#2)" changelog "fix 30 lines" >/dev/null 2>&1 )
out2="$(aapp issue close 2 2>&1)"; rc2=$?
if [ "$rc2" -ne 0 ] && echo "$out2" | grep -q "lines" && echo "$out2" | grep -q "limit.*25" && \
   echo "$out2" | grep -qF "aapp issue fix 2 abort" && echo "$out2" | grep -qF "aapp draft" && \
   grep -qF '| #2 |' .plans/ISSUES.md; then
  ok "test_close_refuses_over_line_limit"
else
  bad "test_close_refuses_over_line_limit" "rc=$rc2 out=$out2"
fi
aapp issue fix 2 abort >/dev/null 2>&1

# 3. test_limits_are_configurable
git config aapp.fixMaxFiles 5
git config aapp.fixMaxLines 50
aapp issue fix 3 >/dev/null 2>&1
aapp issue fix 3 file src/f2.sh "need f2" >/dev/null 2>&1
aapp issue fix 3 file src/f3.sh "need f3" >/dev/null 2>&1
aapp issue fix 3 file src/f4.sh "need f4" >/dev/null 2>&1
( cd .workspace/fix-3 && \
  for l in $(seq 1 28); do echo "line $l" >> src/f1.sh; done && \
  echo "c2" >> src/f2.sh && echo "c3" >> src/f3.sh && echo "c4" >> src/f4.sh && \
  git add src/ && \
  aapp commit "fix: configurable limits (#3)" changelog "fix configurable" >/dev/null 2>&1 )
out3="$(aapp issue close 3 2>&1)"; rc3=$?
git config --unset aapp.fixMaxFiles
git config --unset aapp.fixMaxLines
if [ "$rc3" -eq 0 ] && ! grep -qF '| #3 |' .plans/ISSUES.md; then
  ok "test_limits_are_configurable"
else
  bad "test_limits_are_configurable" "rc=$rc3 out=$out3"
fi

# 4. test_added_file_needs_a_reason
aapp issue fix 4 >/dev/null 2>&1
noreason_out="$(aapp issue fix 4 file src/f2.sh 2>&1)"; noreason_rc=$?
reason_out="$(aapp issue fix 4 file src/f2.sh "helper dependency" 2>&1)"; reason_rc=$?
mini_has_reason="$(grep -F 'src/f2.sh' .plans/current/fix-4.md | grep -F 'helper dependency' || true)"
note_has_reason="$(aapp issue list note 4 2>/dev/null | grep -F 'file src/f2.sh: helper dependency' || true)"
aapp issue fix 4 abort >/dev/null 2>&1
if [ "$noreason_rc" -ne 0 ] && [ "$reason_rc" -eq 0 ] && [ -n "$mini_has_reason" ] && [ -n "$note_has_reason" ]; then
  ok "test_added_file_needs_a_reason"
else
  bad "test_added_file_needs_a_reason" "noreason_rc=$noreason_rc reason_rc=$reason_rc mini=$mini_has_reason note=$note_has_reason"
fi

# 5. test_close_refuses_undeclared_file
aapp issue fix 5 >/dev/null 2>&1
( cd .workspace/fix-5 && \
  echo "mod1" >> src/f1.sh && \
  echo "undeclared" >> src/f5.sh && \
  git add src/f1.sh src/f5.sh && \
  SKIP_BLAST_RADIUS=1 aapp commit "fix: with undeclared file (#5)" changelog "fix undeclared" >/dev/null 2>&1 )
out5="$(aapp issue close 5 2>&1)"; rc5=$?
aapp issue fix 5 abort >/dev/null 2>&1
if [ "$rc5" -ne 0 ] && echo "$out5" | grep -q "src/f5.sh" && grep -qF '| #5 |' .plans/ISSUES.md; then
  ok "test_close_refuses_undeclared_file"
else
  bad "test_close_refuses_undeclared_file" "rc=$rc5 out=$out5"
fi

# 6. test_collision_notice
# Draft a plan in development that lists src/shared.sh
pid="P-$(git config aapp.planId)"; aapp draft plan-colliding >/dev/null 2>&1
pf="$(ls .plans/current/P"${pid#P-}"-*.md)"
sed -i -E "s|src/path/to/file\.ext|src/shared.sh|g" "$pf"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$pf"
git -C .plans commit -qam "prep collision plan" >/dev/null 2>&1
aapp freeze-start "$pid" >/dev/null 2>&1

out6="$(aapp issue fix 6 2>&1)"; rc6=$?
aapp issue fix 6 abort >/dev/null 2>&1
if [ "$rc6" -eq 0 ] && echo "$out6" | grep -q "P-[0-9].*in development also lists src/shared.sh"; then
  ok "test_collision_notice"
else
  bad "test_collision_notice" "rc=$rc6 out=$out6"
fi

# 7. test_collision_refuse_setting
git config aapp.fixCollision refuse
out7_refuse="$(aapp issue fix 6 2>&1)"; rc7_refuse=$?
out7_force="$(aapp issue fix 6 force 2>&1)"; rc7_force=$?
aapp issue fix 6 abort >/dev/null 2>&1
git config --unset aapp.fixCollision
if [ "$rc7_refuse" -ne 0 ] && [ "$rc7_force" -eq 0 ] && [ ! -d ".workspace/fix-6" ]; then
  ok "test_collision_refuse_setting"
else
  bad "test_collision_refuse_setting" "rc_refuse=$rc7_refuse rc_force=$rc7_force"
fi

# 8. test_blocked_plan_is_no_collision
bid="P-$(git config aapp.planId)"; aapp draft plan-blocked >/dev/null 2>&1
bf="$(ls .plans/current/P"${bid#P-}"-*.md)"
sed -i -E "s|src/path/to/file\.ext|src/blocked.sh|g" "$bf"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$bf"
git -C .plans commit -qam "prep blocked plan" >/dev/null 2>&1
aapp freeze-start "$bid" >/dev/null 2>&1
# Block bid on #7
aapp refine "$bid" blocked 7 >/dev/null 2>&1
out8="$(aapp issue fix 7 2>&1)"; rc8=$?
aapp issue fix 7 abort >/dev/null 2>&1
if [ "$rc8" -eq 0 ] && ! echo "$out8" | grep -q "also lists src/blocked.sh"; then
  ok "test_blocked_plan_is_no_collision"
else
  bad "test_blocked_plan_is_no_collision" "rc=$rc8 out=$out8"
fi

# 9. test_protected_file_refused
aapp issue fix 1 >/dev/null 2>&1
out9="$(aapp issue fix 1 file .githooks/pre-commit "try protected" 2>&1)"; rc9=$?
aapp issue fix 1 abort >/dev/null 2>&1
if [ "$rc9" -ne 0 ] && ! grep -q "pre-commit" .plans/current/fix-1.md 2>/dev/null; then
  ok "test_protected_file_refused"
else
  bad "test_protected_file_refused" "rc=$rc9 out=$out9"
fi

print_test_summary "$PASS" "$FAIL"
