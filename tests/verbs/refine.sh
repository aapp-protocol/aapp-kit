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
| #10 | `High` | `CORE` | 2026-10-07 | `a.sh` | First blocker. |  | 🟡 `Incubated` |
| #11 | `High` | `CORE` | 2026-10-07 | `b.sh` | Second blocker. |  | 🟡 `Incubated` |
| #12 | `High` | `CORE` | 2026-10-07 | `c.sh` | Third blocker. |  | 🟡 `Incubated` |
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
| #21 | \`Low\` | \`CORE\` | 2026-10-07 | \`b.sh\` | Second. |  | 🟡 \`Incubated\` |
EOF
cat > .plans/issues_road_map.md <<EOF
# 🗺️ Issue Work Queue

## 📋 Queued
- [ ] #20 -> See [$id2](current/$b2).
- [ ] #21 -> Second.
EOF
git -C .plans add ISSUES.md issues_road_map.md done/000-issues-archive.md >/dev/null 2>&1
git -C .plans commit -qm "test: ledger fixture" >/dev/null 2>&1
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
echo "- [ ] A new idea: worth a plan one day" >> .plans/pickup.md
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

echo "== pickup entry form (P-96) =="
# pickup_refused <entry>: appends the entry, runs the gate; prints the output,
# returns 0 when the gate refused it and nothing was committed. The entry is
# taken out again.
pickup_refused() {
  local before out rc
  before="$(git -C .plans rev-parse HEAD)"
  printf '%s\n' "$1" >> .plans/pickup.md
  out="$(aapp refine pickup "try entry" 2>&1)"; rc=$?
  git -C .plans checkout -q -- pickup.md
  printf '%s\n' "$out"
  [ "$rc" -ne 0 ] && [ "$(git -C .plans rev-parse HEAD)" = "$before" ]
}
# pickup_accepted <entry>: appends the entry and commits it through the gate.
pickup_accepted() {
  printf '%s\n' "$1" >> .plans/pickup.md
  aapp refine pickup "add entry" >/dev/null 2>&1
}
title_of() { printf '%*s' "$1" '' | tr ' ' 'T'; }

out="$(pickup_refused "- [ ] An idea written without a title")"; r1=$?
lineno="$(( $(wc -l < .plans/pickup.md) + 1 ))"
if [ "$r1" -eq 0 ] && echo "$out" | grep -q "Line $lineno" && echo "$out" | grep -qi "no title"; then
  ok "test_refine_pickup_refuses_untitled_entry"
else
  bad "test_refine_pickup_refuses_untitled_entry" "rc=$r1 out=$out"
fi

out="$(pickup_refused "- [ ] $(title_of 73): text")"; r1=$?
pickup_accepted "- [ ] $(title_of 72): text"; r2=$?
# The gate reads the whole file: the 72-character entry goes before the limit drops.
sed -i "/^- \[ \] $(title_of 72): text$/d" .plans/pickup.md && aapp refine pickup "drop entry" >/dev/null 2>&1
git config aapp.pickupTitleMax 50
out50="$(pickup_refused "- [ ] $(title_of 51): text")"; r3=$?
pickup_accepted "- [ ] $(title_of 50): text"; r4=$?
git config --unset aapp.pickupTitleMax
if [ "$r1" -eq 0 ] && echo "$out" | grep -q "73 characters" && echo "$out" | grep -q "at most 72 (aapp.pickupTitleMax)" && \
   [ "$r2" -eq 0 ] && [ "$r3" -eq 0 ] && echo "$out50" | grep -q "at most 50 (aapp.pickupTitleMax)" && [ "$r4" -eq 0 ]; then
  ok "test_refine_pickup_refuses_long_title"
else
  bad "test_refine_pickup_refuses_long_title" "73=$r1 72=$r2 51=$r3 50=$r4 out=$out out50=$out50"
fi

git config aapp.pickupTitleMax many
outa="$(pickup_refused "- [ ] Fine Title: text")"; r1=$?
git config aapp.pickupTitleMax 9
outb="$(pickup_refused "- [ ] Fine Title: text")"; r2=$?
git config --unset aapp.pickupTitleMax
if [ "$r1" -eq 0 ] && echo "$outa" | grep -q "aapp.pickupTitleMax" && [ "$r2" -eq 0 ] && echo "$outb" | grep -q "aapp.pickupTitleMax"; then
  ok "test_refine_pickup_title_max_invalid"
else
  bad "test_refine_pickup_title_max_invalid" "many=$r1 nine=$r2 outa=$outa outb=$outb"
fi

out="$(pickup_refused "- [ ] Title:")"; r1=$?
out2="$(pickup_refused "- [ ] Title:   ")"; r2=$?
if [ "$r1" -eq 0 ] && [ "$r2" -eq 0 ] && echo "$out$out2" | grep -qi "no text after the title"; then
  ok "test_refine_pickup_refuses_empty_text"
else
  bad "test_refine_pickup_refuses_empty_text" "rc=$r1/$r2 out=$out $out2"
fi

mkdir -p .plans/pickup && echo "notes" > .plans/pickup/real-notes.md
out="$(pickup_refused "- [ ] Idea With Notes: details in \`.plans/pickup/missing-notes.md\`.")"; r1=$?
pickup_accepted "- [ ] Idea With Notes: details in \`.plans/pickup/real-notes.md\`."; r2=$?
if [ "$r1" -eq 0 ] && echo "$out" | grep -qF ".plans/pickup/missing-notes.md" && echo "$out" | grep -qi "does not exist" && [ "$r2" -eq 0 ]; then
  ok "test_refine_pickup_refuses_missing_file"
else
  bad "test_refine_pickup_refuses_missing_file" "missing=$r1 real=$r2 out=$out"
fi
# Another clone: the committed entry names a file this machine does not have
# (`.plans/pickup/` is gitignored); a commit of another entry still passes.
rm -f .plans/pickup/real-notes.md
pickup_accepted "- [ ] Unrelated Idea: written on another machine"; r1=$?
if [ "$r1" -eq 0 ] && git -C .plans log -1 --format=%s | grep -qxF "pickup: add entry"; then
  ok "test_refine_pickup_committed_file_elsewhere"
else
  bad "test_refine_pickup_committed_file_elsewhere" "rc=$r1"
fi

pickup_accepted "- [x] a digested note written before titles"; r1=$?
if [ "$r1" -eq 0 ] && git -C .plans log -1 --format=%s | grep -qxF "pickup: add entry"; then
  ok "test_refine_pickup_skips_digested"
else
  bad "test_refine_pickup_skips_digested" "rc=$r1 last=$(git -C .plans log -1 --format=%s)"
fi
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
   refused_issues board sed -i '$a ## Other' .plans/issues_road_map.md; then
  ok "test_refine_issues_validation_refuses"
else
  bad "test_refine_issues_validation_refuses" "a malformed ledger was committed or not refused"
fi

echo "== the fix cell holds links only (P-66) =="
head_before="$(git -C .plans rev-parse HEAD)"
sed -i 's/^\(| #21 |.*| Second, reworded. |\)[^|]*|/\1 Fix it later, see notes. |/' .plans/ISSUES.md
out="$(aapp refine issues "notes in the cell" 2>&1)"; rc=$?
git -C .plans checkout -q -- ISSUES.md
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "#21" && [ "$(git -C .plans rev-parse HEAD)" = "$head_before" ]; then
  ok "test_issues_refuses_text_in_fix_cell"
else
  bad "test_issues_refuses_text_in_fix_cell" "rc=$rc out=$out"
fi
sed -i 's/^\(| #21 |.*| Second, reworded. |\)[^|]*|/\1 blocks [P-1](current\/P1-x.md) |/' .plans/ISSUES.md
out1="$(aapp refine issues "blocks link" 2>&1)"; r1=$?
sed -i 's/^\(| #21 |.*| Second, reworded. |\)[^|]*|/\1  |/' .plans/ISSUES.md
out2="$(aapp refine issues "empty cell" 2>&1)"; r2=$?
if [ "$r1" -eq 0 ] && [ "$r2" -eq 0 ] && git -C .plans log -1 --format=%s | grep -qxF "issue(triage): empty cell"; then
  ok "test_issues_accepts_plan_and_blocks_links"
else
  bad "test_issues_accepts_plan_and_blocks_links" "rc=$r1/$r2 out=$out1 | $out2"
fi

echo "== group membership (P-64) =="
init_sandbox_project "$R/g"
cd "$R/g" || exit 1
gid="P-$(git config aapp.planId)"; aapp draft grp group >/dev/null 2>&1
gf="$(ls .plans/current/P"${gid#P-}"-grp.md)"; aid="P-$(( ${gid#P-} + 1 ))"
pid="P-$(git config aapp.planId)"; aapp draft member-a >/dev/null 2>&1
pf="$(ls .plans/current/P"${pid#P-}"-*.md)"
aapp refine "$pid" group "$gid" >/dev/null 2>&1; r1=$?
joined=0; grep -qx "\* \*\*Group:\*\* $gid" "$pf" && grep -qx "\* \*\*Members:\*\* $pid, $aid" "$gf" && joined=1
aapp refine "$pid" group none >/dev/null 2>&1; r2=$?
left=0; ! grep -q '^\* \*\*Group:\*\*' "$pf" && grep -qx "\* \*\*Members:\*\* $aid" "$gf" && left=1
aapp refine "$pid" group "$gid" >/dev/null 2>&1
# Fixture: the member as started (the status the verbs would have written).
sed -i -E 's/^\* \*\*Status:\*\*.*/* **Status:** ⚡ In Development/' "$pf"
git -C .plans commit -qam "fixture: $pid started" >/dev/null 2>&1
aapp refine "$pid" group none >/dev/null 2>&1; r3=$?
if [ "$r1" -eq 0 ] && [ "$joined" -eq 1 ] && [ "$r2" -eq 0 ] && [ "$left" -eq 1 ] && [ "$r3" -ne 0 ] && \
   grep -qx "\* \*\*Group:\*\* $gid" "$pf"; then
  ok "test_refine_joins_and_leaves_group"
else
  bad "test_refine_joins_and_leaves_group" "join=$r1/$joined leave=$r2/$left started=$r3"
fi

echo "== owner of a plan in development (P-99) =="
git add -A >/dev/null 2>&1; git commit -qm "track before worktrees" --no-verify >/dev/null 2>&1
git config aapp.planWorktrees on; git config aapp.commitMode microcommits
# own_plan <slug> [group]: a plan (or group member) freeze-started into its worktree.
own_plan() {
  local id f; id="P-$(git config aapp.planId)"
  if [ -n "${2:-}" ]; then aapp draft "$1" group "$2" >/dev/null 2>&1; else aapp draft "$1" >/dev/null 2>&1; fi
  f="$(ls .plans/current/P"${id#P-}"-*.md)"
  sed -i -E "s|src/path/to/file\.ext|src/$1.sh|g; /src\/path\/to\/new_file\.ext/d; s/^\* \[ \] \*\*Question/* [x] **Question/" "$f"
  git -C .plans commit -qam "prep $id" >/dev/null 2>&1
  echo "$id"
}
o="$(own_plan owned)"; aapp freeze-start "$o" >/dev/null 2>&1
of="$(ls .plans/current/P"${o#P-}"-*.md)"; owt="$PWD/.workspace/P${o#P-}"
echo "* **2026-10-17:** foreign note." >> "$of"
out="$(aapp refine "$o" "foreign note" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "only its worktree .workspace/P${o#P-} amends it" && \
   echo "$out" | grep -qF "aapp issue log" && [ -n "$(git -C .plans status --porcelain -- "current/$(basename "$of")")" ]; then
  ok "test_refine_plan_in_development_refused_elsewhere"
else
  bad "test_refine_plan_in_development_refused_elsewhere" "rc=$rc out=$out"
fi
out="$(cd "$owt" && aapp refine "$o" "owner note" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && git -C .plans log -1 --format=%s | grep -qF "$o owner note"; then
  ok "test_refine_plan_in_development_from_its_worktree"
else
  bad "test_refine_plan_in_development_from_its_worktree" "rc=$rc out=$out"
fi
out="$(aapp refine "$o" closes 9999 2>&1)"; rc=$?
if ! echo "$out" | grep -qF "amends it"; then
  ok "test_refine_verb_written_kind_not_owner_checked"
else
  bad "test_refine_verb_written_kind_not_owner_checked" "rc=$rc out=$out"
fi
gid="P-$(git config aapp.planId)"; aapp draft owners group >/dev/null 2>&1
gfile="$(ls .plans/current/P"${gid#P-}"-*.md)"; sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$gfile"
git -C .plans commit -qam "prep $gid" >/dev/null 2>&1
aapp freeze "$gid" >/dev/null 2>&1 && aapp start "$gid" base "$(git rev-parse --abbrev-ref HEAD)" >/dev/null 2>&1
m1="$(own_plan mem-one "$gid")"; aapp freeze-start "$m1" >/dev/null 2>&1
m2="$(own_plan mem-two "$gid")"; m2f="$(ls .plans/current/P"${m2#P-}"-*.md)"
echo "* **2026-10-17:** note on an unstarted member." >> "$m2f"
r1=0; out1="$(aapp refine "$m2" "unstarted note" 2>&1)" || r1=$?
r2=0; out2="$(cd "$PWD/.workspace/P${m1#P-}" 2>&1 && aapp refine "$m2" "unstarted note" 2>&1)" || r2=$?
if [ "$r1" -ne 0 ] && echo "$out1" | grep -qF "group $gid" && [ "$r2" -eq 0 ]; then
  ok "test_refine_group_plans_only_from_the_group"
else
  bad "test_refine_group_plans_only_from_the_group" "r1=$r1 out1=$out1 r2=$r2 out2=$out2"
fi

echo "== the amendments member (P-101) =="
# amend_group <slug>: a started group (with its amendments member) and one member
# freeze-started into its worktree; prints "<group> <amendments> <member>".
amend_group() {
  local gid aid mid g m
  gid="P-$(git config aapp.planId)"; aapp draft "$1" group >/dev/null 2>&1; aid="P-$(( ${gid#P-} + 1 ))"
  g="$(ls .plans/current/P"${gid#P-}"-"$1".md)"
  sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$g"; git -C .plans commit -qam "prep $gid" >/dev/null 2>&1
  aapp freeze "$gid" >/dev/null 2>&1; aapp start "$gid" base "$(git rev-parse --abbrev-ref HEAD)" >/dev/null 2>&1
  mid="P-$(git config aapp.planId)"; aapp draft "$1-m" group "$gid" >/dev/null 2>&1
  m="$(ls .plans/current/P"${mid#P-}"-"$1"-m.md)"
  sed -i -E "s|src/path/to/file\.ext|src/$1-m.sh|g; /src\/path\/to\/new_file\.ext/d; s/^\* \[ \] \*\*Question/* [x] **Question/" "$m"
  git -C .plans commit -qam "prep $mid" >/dev/null 2>&1
  aapp freeze-start "$mid" worktree ".workspace/P${mid#P-}" >/dev/null 2>&1
  echo "$gid $aid $mid"
}
read -r ag aa am <<< "$(amend_group amg)"
af="$(ls .plans/current/P"${aa#P-}"-*.md)"; mwt="$PWD/.workspace/P${am#P-}"; awt="$PWD/.workspace/P${aa#P-}"
r1=0; out1="$(cd "$mwt" && aapp refine "$aa" request "needs a helper" file src/helper.sh 2>&1)" || r1=$?
r2=0; out2="$(aapp refine "$aa" request "from outside" file src/x.sh 2>&1)" || r2=$?
if [ "$r1" -eq 0 ] && echo "$out1" | grep -qF "R1 recorded" && echo "$out1" | grep -qF "Do not implement" && \
   grep -qF -- "- **R1** $(date +%Y-%m-%d) · $am · \`src/helper.sh\` · needs a helper — pending" "$af" && \
   [ "$r2" -ne 0 ] && echo "$out2" | grep -qF "for itself"; then
  ok "test_amend_request_from_member_only"
else
  bad "test_amend_request_from_member_only" "r1=$r1 out1=$out1 r2=$r2 out2=$out2"
fi
# P-129: the owner is the group plan or a plan of the group; any other plan is refused.
op="P-$(git config aapp.planId)"; aapp draft outsider >/dev/null 2>&1
r1=0; out1="$(cd "$mwt" && aapp refine "$aa" request "for the group" file src/g.sh for "$ag" 2>&1)" || r1=$?
r2=0; out2="$(cd "$mwt" && aapp refine "$aa" request "unknown" file src/u.sh for P-9999 2>&1)" || r2=$?
r3=0; out3="$(cd "$mwt" && aapp refine "$aa" request "outside" file src/o.sh for "$op" 2>&1)" || r3=$?
if [ "$r1" -eq 0 ] && grep -qF -- "- **R2** $(date +%Y-%m-%d) · $am · \`src/g.sh\` · for the group · for $ag — pending" "$af" && \
   [ "$r2" -ne 0 ] && [ "$r3" -ne 0 ] && echo "$out3" | grep -qF "group $ag" && ! grep -qF "src/u.sh" "$af" && ! grep -qF "src/o.sh" "$af"; then
  ok "test_amend_request_names_its_owner"
else
  bad "test_amend_request_names_its_owner" "r1=$r1 out1=$out1 r2=$r2 out2=$out2 r3=$r3 out3=$out3"
fi
# A Target Files line the amendments member kept from before P-129 is no claim (#190).
awk '/^### 📂 Target Files/ { print; print "- [ ] `src/helper.sh` -> R0 old route"; next } { print }' "$af" > "$af.t" && mv "$af.t" "$af"
git -C .plans commit -qam "fixture: old-route target" --no-verify >/dev/null 2>&1
out="$(aapp refine "$aa" approve 1 2>&1)"; rc=$?
g1=0; ( cd "$mwt" && bash .githooks/blast-radius-guard src/helper.sh >/dev/null 2>&1 ) || g1=$?
g2=0; ( cd "$mwt" && bash .githooks/blast-radius-guard src/unlisted.sh >/dev/null 2>&1 ) || g2=$?
if [ "$rc" -eq 0 ] && grep -q '· needs a helper — approved (' "$af" && ! grep -qF '`src/helper.sh` -> R1' "$af" && \
   echo "$out" | grep -qF "amendment 1" && [ "$g1" -eq 0 ] && [ "$g2" -ne 0 ]; then
  ok "test_amend_approve_lets_the_requester_write"
else
  bad "test_amend_approve_lets_the_requester_write" "rc=$rc out=$out guard=$g1/$g2"
fi
( cd "$mwt" && aapp refine "$aa" request "taken" file "src/amg-m.sh" >/dev/null 2>&1 )
r3=0; out3="$(aapp refine "$aa" approve 3 2>&1)" || r3=$?
r4=0; out4="$(aapp refine "$aa" refuse 3 "a member's own file" 2>&1)" || r4=$?
( cd "$mwt" && aapp refine "$aa" request "again" file "src/helper.sh" >/dev/null 2>&1 )
r5=0; out5="$(aapp refine "$aa" approve 4 2>&1)" || r5=$?
if [ "$r3" -ne 0 ] && echo "$out3" | grep -qF "Target File of $am" && [ "$r4" -eq 0 ] && \
   grep -q "— refused: a member's own file$" "$af" && [ "$r5" -ne 0 ] && echo "$out5" | grep -qF "R1" && grep -q "· again — pending$" "$af"; then
  ok "test_amend_approve_refuses_active_member_file_and_refuse"
else
  bad "test_amend_approve_refuses_active_member_file_and_refuse" "r3=$r3 out3=$out3 r4=$r4 out4=$out4 r5=$r5 out5=$out5"
fi
git config aapp.amendmentApprovalRequired false
r6=0; out6="$(cd "$mwt" && aapp refine "$aa" request "auto" file src/auto.sh 2>&1)" || r6=$?
git config aapp.amendmentApprovalRequired maybe
r8=0; out8="$(cd "$mwt" && aapp refine "$aa" request "any" 2>&1)" || r8=$?
git config --unset aapp.amendmentApprovalRequired
if [ "$r6" -eq 0 ] && grep -qF "· auto — approved (auto)" "$af" && [ "$r8" -ne 0 ] && echo "$out8" | grep -qF "aapp.amendmentApprovalRequired"; then
  ok "test_amend_auto_approved_when_not_required"
else
  bad "test_amend_auto_approved_when_not_required" "r6=$r6 out6=$out6 r8=$r8 out8=$out8"
fi
# A correction of the group's text: requested by heading, approved, written into the group plan.
gfa="$(ls .plans/current/P"${ag#P-}"-amg.md)"
awk '/^### ARCHITECTURE.md/ { print; print "````markdown"; print "## Amg Lifecycle"; print "first text"; print "````"; next } { print }' "$gfa" > "$gfa.t" && mv "$gfa.t" "$gfa"
git -C .plans commit -qam "fixture: group section" --no-verify >/dev/null 2>&1
( cd "$mwt" && aapp refine "$aa" request "landing changed" heading "Amg Lifecycle" >/dev/null 2>&1 )
aapp refine "$aa" approve 6 >/dev/null 2>&1
sed -i 's/^first text$/corrected text/' "$gfa"
r9=0; out9="$(cd "$awt" && aapp refine "$aa" decision 6 "landing changed" 2>&1)" || r9=$?
files9="$(git -C .plans show --name-only --format= HEAD)"
sed -i 's/^Group goal.*$//' "$gfa"; echo "* stray" >> "$gfa"
r10=0; out10="$(cd "$awt" && aapp refine "$aa" decision 6 "again" 2>&1)" || r10=$?
git -C .plans checkout -q -- "current/$(basename "$gfa")"
if [ "$r9" -eq 0 ] && grep -qx "corrected text" "$gfa" && grep -qF -- "· § Amg Lifecycle · R6 · landing changed" "$af" && \
   grep -q "· landing changed — applied$" "$af" && echo "$files9" | grep -qx "current/$(basename "$gfa")" && \
   echo "$files9" | grep -qx "current/$(basename "$af")" && [ "$r10" -ne 0 ]; then
  ok "test_amend_decision_corrects_group_text_with_record"
else
  bad "test_amend_decision_corrects_group_text_with_record" "r9=$r9 out9=$out9 files=$files9 r10=$r10 out10=$out10"
fi
# P-129: an aborted requester's open requests are closed as withdrawn; refused and applied ones stay.
r11=0; out11="$(aapp plan abort "$am" reason "dropped" 2>&1)" || r11=$?
if [ "$r11" -eq 0 ] && grep -qF "· needs a helper — closed · withdrawn" "$af" && grep -qF "· for $ag — closed · withdrawn" "$af" && \
   grep -qF "· again — closed · withdrawn" "$af" && grep -qF "· auto — closed · withdrawn" "$af" && \
   grep -q "— refused: a member's own file$" "$af" && grep -q "· landing changed — applied$" "$af" && \
   git -C .plans show --name-only --format= HEAD | grep -qx "current/$(basename "$af")"; then
  ok "test_amend_abort_withdraws_requests"
else
  bad "test_amend_abort_withdraws_requests" "r11=$r11 out11=$out11"
fi

print_test_summary "$PASS" "$FAIL"
