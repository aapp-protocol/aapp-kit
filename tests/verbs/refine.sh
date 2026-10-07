#!/usr/bin/env bash
# Tests: `aapp refine` behaviour contract (lib/docs/verbs/refine.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1

id="P-$(git config aapp.planId)"
aapp draft refine-me >/dev/null 2>&1
f="$(ls .plans/current/P"${id#P-}"-*.md)"
rel="current/$(basename "$f")"

echo "== happy path =="
echo "* **2026-10-03:** Clarified the goal." >> "$f"
echo "- [ ] unrelated note" >> .plans/pickup.md
git -C .plans add pickup.md
out="$(aapp refine "$id" "clarify goal" 2>&1)"; rc=$?
sha="$(git -C .plans rev-parse --short HEAD)"
if [ "$rc" -eq 0 ] && git -C .plans log -1 --format=%s | grep -qxF "plan(refine): $id clarify goal" && \
   [ "$(git -C .plans show --name-only --format= HEAD)" = "$rel" ] && \
   echo "$out" | grep -qF "📝 [Refine] $id committed ($sha): clarify goal"; then
  ok "test_refine_commits_only_the_plan"
else
  bad "test_refine_commits_only_the_plan" "rc=$rc out=$out files=$(git -C .plans show --name-only --format= HEAD)"
fi
if git -C .plans diff --cached --name-only | grep -qx "pickup.md"; then
  ok "test_refine_leaves_other_staged_paths"
else
  bad "test_refine_leaves_other_staged_paths" "staged=$(git -C .plans diff --cached --name-only)"
fi
git -C .plans reset -q pickup.md && git -C .plans checkout -q -- pickup.md

echo "== refusals =="
head_before="$(git -C .plans rev-parse HEAD)"
aapp refine >/dev/null 2>&1; rc1=$?
aapp refine "$id" >/dev/null 2>&1; rc2=$?
aapp refine P-999 "x" >/dev/null 2>&1; rc3=$?
out="$(aapp refine "$id" "again" 2>&1)"; rc4=$?
if [ "$rc1" -ne 0 ] && [ "$rc2" -ne 0 ] && [ "$rc3" -ne 0 ] && [ "$rc4" -ne 0 ] && \
   echo "$out" | grep -qi "nothing to commit" && [ "$(git -C .plans rev-parse HEAD)" = "$head_before" ]; then
  ok "test_refine_refuses_bad_input_and_no_change"
else
  bad "test_refine_refuses_bad_input_and_no_change" "rc=$rc1/$rc2/$rc3/$rc4 out=$out"
fi

echo "== subject checks (P-49) =="
echo "* **2026-10-07:** Pending edit." >> "$f"
head_before="$(git -C .plans rev-parse HEAD)"
long_msg="$(printf 'x%.0s' $(seq 1 70))"
subj="plan(refine): $id $long_msg"
over=$(( ${#subj} - 72 ))
out="$(aapp refine "$id" "$long_msg" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "Commit subject is ${#subj} characters; the limit is 72 (aapp.subjectMaxLen)." && \
   echo "$out" | grep -qF "Shorten the message by $over characters" && [ "$(git -C .plans rev-parse HEAD)" = "$head_before" ]; then
  ok "test_refine_refuses_overlong_subject"
else
  bad "test_refine_refuses_overlong_subject" "rc=$rc out=$out"
fi
git config aapp.subjectMaxLen 30
out="$(aapp refine "$id" "a message of medium size" 2>&1)"; rc=$?
git config --unset aapp.subjectMaxLen
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "the limit is 30 (aapp.subjectMaxLen)" && [ "$(git -C .plans rev-parse HEAD)" = "$head_before" ]; then
  ok "test_refine_honours_subject_max_len"
else
  bad "test_refine_honours_subject_max_len" "rc=$rc out=$out"
fi
out="$(aapp refine "$id" "$(printf 'line one\nline two')" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "The message must be a single line" && [ "$(git -C .plans rev-parse HEAD)" = "$head_before" ]; then
  ok "test_refine_refuses_multiline_message"
else
  bad "test_refine_refuses_multiline_message" "rc=$rc out=$out"
fi
git -C .plans checkout -q -- "$rel"

echo "== blocked token (P-49) =="
cat > .plans/ISSUES.md <<'EOF'
# Issues

| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #10 | `High` | `CORE` | 2026-10-07 | `a.sh` | First blocker. | Fix a. | 🟡 `Incubated` |
| #11 | `High` | `CORE` | 2026-10-07 | `b.sh` | Second blocker. | Fix b. | 🟡 `Incubated` |
| #12 | `High` | `CORE` | 2026-10-07 | `c.sh` | Third blocker. | Fix c. | 🟡 `Incubated` |
EOF
cat > .plans/done/000-issues-archive.md <<'EOF'
# Archive

| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #5 | `Low` | `CLI` | 2026-08-01 | 2026-08-02 | `0000000` | Old. |
EOF
prev="$(sed -nE 's/^\* \*\*Status:\*\* (.*)$/\1/p' "$f" | head -n 1)"
out="$(aapp refine "$id" blocked 10 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -qxF "* **Status:** 🟥 BLOCKED" "$f" && \
   grep -qxF "* **Blocked On:** #10 (was $prev)" "$f" && \
   git -C .plans log -1 --format=%s | grep -qxF "plan(refine): $id blocked on #10" && \
   [ "$(git -C .plans show --name-only --format= HEAD)" = "$rel" ] && \
   [ -z "$(git -C .plans status --porcelain -- state_matrix.md)" ]; then
  ok "test_refine_blocked_sets_status_and_blocked_on"
else
  bad "test_refine_blocked_sets_status_and_blocked_on" "rc=$rc out=$out status=$(grep -m1 'Status:' "$f") blocked=$(grep -m1 '^\* \*\*Blocked On' "$f")"
fi
out="$(aapp refine "$id" blocked 11 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -qxF "* **Blocked On:** #10, #11 (was $prev)" "$f" && \
   [ "$(grep -c '^\* \*\*Blocked On:\*\*' "$f")" -eq 1 ]; then
  ok "test_refine_blocked_appends_to_list"
else
  bad "test_refine_blocked_appends_to_list" "rc=$rc out=$out blocked=$(grep '^\* \*\*Blocked On' "$f")"
fi
head_before="$(git -C .plans rev-parse HEAD)"
out="$(aapp refine "$id" blocked 11 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -qF "already blocked on #11" && [ "$(git -C .plans rev-parse HEAD)" = "$head_before" ]; then
  ok "test_refine_blocked_same_issue_is_noop"
else
  bad "test_refine_blocked_same_issue_is_noop" "rc=$rc out=$out"
fi
aapp refine "$id" blocked 99 >/dev/null 2>&1; rc1=$?
aapp refine "$id" blocked 5 >/dev/null 2>&1; rc2=$?
if [ "$rc1" -ne 0 ] && [ "$rc2" -ne 0 ] && [ "$(git -C .plans rev-parse HEAD)" = "$head_before" ] && \
   [ -z "$(git -C .plans status --porcelain -- "$rel")" ]; then
  ok "test_refine_blocked_refuses_unknown_or_closed_issue"
else
  bad "test_refine_blocked_refuses_unknown_or_closed_issue" "rc=$rc1/$rc2"
fi
lib_out="$( (AAPP_PLAN_LIB_ONLY=1 REPO_ROOT="$PWD" AAPP_LIB="$KIT/lib"; export AAPP_PLAN_LIB_ONLY REPO_ROOT AAPP_LIB
  . "$KIT/lib/cmd_plan.sh" && declare -f plan_block_on >/dev/null && plan_block_on "$f" 12 && echo LIB_OK) 2>&1 )"
if echo "$lib_out" | grep -qx "LIB_OK" && grep -qxF "* **Blocked On:** #10, #11, #12 (was $prev)" "$f" && \
   [ "$(git -C .plans rev-parse HEAD)" = "$head_before" ]; then
  ok "test_plan_block_on_is_write_only_and_lib_loadable"
else
  bad "test_plan_block_on_is_write_only_and_lib_loadable" "out=$lib_out"
fi
git -C .plans checkout -q -- "$rel"

echo "== rename: slug (P-50) =="
id2="P-$(git config aapp.planId)"
aapp draft rename-me >/dev/null 2>&1
f2="$(ls .plans/current/P"${id2#P-}"-*.md)"; b2="$(basename "$f2")"; n2="${id2#P-}"
cat > .plans/ISSUES.md <<EOF
# Issues

| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #20 | \`High\` | \`CORE\` | 2026-10-07 | \`a.sh\` | Mentions [old](current/$b2). | [$id2](current/$b2) | 🔵 \`Planned\` |
| #21 | \`Low\` | \`CORE\` | 2026-10-07 | \`b.sh\` | Second. | Fix b. | 🟡 \`Incubated\` |
EOF
cat > .plans/issues_road_map.md <<EOF
# Issue Priority Board

## 🔴 High Priority (Technical Urgency)
- [ ] #20 -> See [$id2](current/$b2).

## 📥 Triage (Incoming / Unsequenced)
- [ ] #21 -> Second.
EOF
git -C .plans add ISSUES.md issues_road_map.md done/000-issues-archive.md >/dev/null 2>&1
git -C .plans commit -qm "test: ledger fixture" >/dev/null 2>&1
git config aapp.issueId 22
nb="P${n2}-new-name.md"
out="$(aapp refine "$id2" slug "New Name" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ ! -e "$f2" ] && [ -f ".plans/current/$nb" ] && \
   grep -qF "| [$id2](current/$nb) |" .plans/ISSUES.md && grep -qF "Mentions [old](current/$b2)." .plans/ISSUES.md && \
   grep -qF "See [$id2](current/$nb)." .plans/issues_road_map.md && grep -qF "$nb" .plans/state_matrix.md && \
   grep -qF "File renamed from $b2 to $nb" ".plans/current/$nb" && \
   [ -z "$(git -C .plans status --porcelain)" ] && \
   echo "$out" | grep -qF "📝 [Refine] $id2 renamed to $nb (" && echo "$out" | grep -qF "2 issue links repaired"; then
  ok "test_refine_slug_renames_and_repairs_links"
else
  bad "test_refine_slug_renames_and_repairs_links" "rc=$rc out=$out status=$(git -C .plans status --porcelain | tr '\n' ' ')"
fi
f2=".plans/current/$nb"; head_before="$(git -C .plans rev-parse HEAD)"
aapp refine "$id2" slug "!!!" >/dev/null 2>&1; r1=$?
touch ".plans/current/P${n2}-taken.md"; aapp refine "$id2" slug taken >/dev/null 2>&1; r2=$?; rm -f ".plans/current/P${n2}-taken.md"
echo "* **2026-10-07:** dirty." >> "$f2"; aapp refine "$id2" slug other >/dev/null 2>&1; r3=$?; git -C .plans checkout -q -- "current/$nb"
aapp refine P-999 slug x >/dev/null 2>&1; r4=$?
if [ "$r1" -ne 0 ] && [ "$r2" -ne 0 ] && [ "$r3" -ne 0 ] && [ "$r4" -ne 0 ] && [ -f "$f2" ] && \
   [ "$(git -C .plans rev-parse HEAD)" = "$head_before" ]; then
  ok "test_refine_slug_refusals"
else
  bad "test_refine_slug_refusals" "rc=$r1/$r2/$r3/$r4"
fi

echo "== ledger commits (P-50) =="
aapp draft pickup-stuff >/dev/null 2>&1
pf="$(ls .plans/current/*-pickup-stuff.md)"; echo "* **2026-10-07:** pending." >> "$pf"
echo "- [ ] A new idea" >> .plans/pickup.md
out="$(aapp refine pickup "add idea" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && git -C .plans log -1 --format=%s | grep -qxF "pickup: add idea" && \
   [ "$(git -C .plans show --name-only --format= HEAD)" = "pickup.md" ]; then
  ok "test_refine_pickup_commits_only_pickup"
else
  bad "test_refine_pickup_commits_only_pickup" "rc=$rc out=$out files=$(git -C .plans show --name-only --format= HEAD | tr '\n' ' ')"
fi
git -C .plans checkout -q -- "current/$(basename "$pf")"
head_before="$(git -C .plans rev-parse HEAD)"
echo "* not a checkbox entry" >> .plans/pickup.md
out="$(aapp refine pickup "bad entry" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qi "line" && [ "$(git -C .plans rev-parse HEAD)" = "$head_before" ]; then
  ok "test_refine_pickup_refuses_malformed_entry"
else
  bad "test_refine_pickup_refuses_malformed_entry" "rc=$rc out=$out"
fi
git -C .plans checkout -q -- pickup.md
sed -i 's/| Second. |/| Second, reworded. |/' .plans/ISSUES.md
out="$(aapp refine issues "reword 21" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && git -C .plans log -1 --format=%s | grep -qxF "issue(triage): reword 21" && \
   [ "$(git -C .plans show --name-only --format= HEAD)" = "ISSUES.md" ]; then
  ok "test_refine_issues_commits_ledgers"
else
  bad "test_refine_issues_commits_ledgers" "rc=$rc out=$out"
fi
head_before="$(git -C .plans rev-parse HEAD)"
refused_issues() {  # <label> <sed-or-cmd>: apply, expect refusal, restore
  local label="$1"; shift
  "$@"
  local o r; o="$(aapp refine issues "$label" 2>&1)"; r=$?
  git -C .plans checkout -q -- ISSUES.md issues_road_map.md
  [ "$r" -ne 0 ] && [ "$(git -C .plans rev-parse HEAD)" = "$head_before" ] && echo "$o" | grep -qi "line\|#"
}
if refused_issues blank sed -i '/^| #20 |/G' .plans/ISSUES.md && \
   refused_issues cells sed -i 's/^| #21 | `Low` |/| #21 |/' .plans/ISSUES.md && \
   refused_issues dup sed -i '/^| #21 |/p' .plans/ISSUES.md && \
   refused_issues high sed -i 's/^| #21 |/| #30 |/; s/#21 ->/#30 ->/' .plans/ISSUES.md .plans/issues_road_map.md && \
   refused_issues board sed -i '/#21 ->/d' .plans/issues_road_map.md; then
  ok "test_refine_issues_validation_refuses"
else
  bad "test_refine_issues_validation_refuses" "a malformed ledger was committed or not refused"
fi

print_test_summary "$PASS" "$FAIL"
