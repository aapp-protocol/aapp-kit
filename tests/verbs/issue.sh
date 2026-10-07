#!/usr/bin/env bash
# Tests: `aapp issue` behaviour contract (lib/docs/verbs/issue.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1

# Known ledgers: three active issues (one with an escaped pipe), one archived.
cat > .plans/ISSUES.md <<'EOF'
# Issues

| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #10 | `Low` | `CLI` | 2026-09-01 | `a.sh` | Pipe `a\|b` breaks. | Escape the pipe. | 🟡 `Incubated` |
| #11 | `Medium` | `CORE` | 2026-09-02 | `b.sh` | Second defect. | Fix b. | 🟡 `Incubated` |
| #12 | `Low` | `CORE` | 2026-09-03 | `c.sh` | Third defect. | Fix c. | 🟡 `Incubated` |
EOF
cat > .plans/done/000-issues-archive.md <<'EOF'
# Archive

| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #5 | `Low` | `CLI` | 2026-08-01 | 2026-08-02 | `0000000` | Old. |
EOF
cat > .plans/issues_road_map.md <<'EOF'
# Board

## High
1. #11 -> Second defect.

## Triage
- [ ] #10 -> Pipe breaks.
- [ ] #12 -> Third defect.
EOF
git -C .plans add -A && git -C .plans commit -qm "fixture ledgers" >/dev/null 2>&1
git config aapp.issueId 13
SHA="$(git rev-parse --short=7 HEAD)"

echo "== next / allocate =="
out="$(aapp issue next 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q '#13' && [ "$(git config aapp.issueId)" = "13" ]; then
  ok "test_next_peeks_without_claiming"
else
  bad "test_next_peeks_without_claiming" "rc=$rc out=$out"
fi

out="$(aapp issue allocate 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "#13" ] && [ "$(git config aapp.issueId)" = "14" ]; then
  ok "test_allocate_claims_and_advances"
else
  bad "test_allocate_claims_and_advances" "rc=$rc out=$out"
fi

git config aapp.issueId abc
out="$(aapp issue allocate 2>&1)"; rc1=$?
aapp issue next >/dev/null 2>&1; rc2=$?
if [ "$rc1" -ne 0 ] && [ "$rc2" -ne 0 ] && [ "$(git config aapp.issueId)" = "abc" ] && \
   echo "$out" | grep -qF "git config --unset aapp.issueId"; then
  ok "test_non_integer_counter_fails_closed"
else
  bad "test_non_integer_counter_fails_closed" "rc1=$rc1 rc2=$rc2"
fi
git config aapp.issueId 14

echo "== provider plugin =="
PDIR=.agents/skills/aapp-issue-tracker
mkdir -p "$PDIR"
printf '%s\n' '#!/bin/sh' '[ "$AAPP_ACTION" = allocate ] && echo "{\"id\": \"#40\"}"' > "$PDIR/run"
chmod +x "$PDIR/run"
out="$(aapp issue allocate 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "#40" ] && [ "$(git config aapp.issueId)" = "41" ]; then
  ok "test_provider_allocate_ratchets_counter"
else
  bad "test_provider_allocate_ratchets_counter" "rc=$rc out=$out counter=$(git config aapp.issueId)"
fi

printf '%s\n' '#!/bin/sh' 'echo "{\"error\": \"tracker offline\"}"' 'exit 1' > "$PDIR/run"
aapp issue allocate >/dev/null 2>&1; rc=$?
if [ "$rc" -ne 0 ] && [ "$(git config aapp.issueId)" = "41" ]; then
  ok "test_failing_provider_refuses_allocation"
else
  bad "test_failing_provider_refuses_allocation" "rc=$rc"
fi

echo "== close =="
out="$(aapp issue close 10 sha "$SHA" 2>&1)"; rc=$?
arow="$(grep -E '^\| #10 \|' .plans/done/000-issues-archive.md)"
if [ "$rc" -eq 0 ] && ! grep -qE '^\| #10 \|' .plans/ISSUES.md && \
   echo "$arow" | grep -qF "| \`$SHA\` | Direct fix (no plan): Escape the pipe. |" && \
   [ "$(grep -E '^\| #[0-9]' .plans/done/000-issues-archive.md | head -n 1 | cut -d'|' -f2 | tr -d ' ')" = "#10" ] && \
   ! grep -q '#10 ->' .plans/issues_road_map.md && \
   git -C .plans log -1 --format=%s | grep -qF 'issue(close): archive #10' && \
   [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_close_relocates_prunes_and_commits"
else
  bad "test_close_relocates_prunes_and_commits" "rc=$rc row=$arow log=$(git -C .plans log -1 --format=%s) status=$(git -C .plans status --porcelain)"
fi
if echo "$out" | grep -q 'aapp-issue-tracker failed (tracker offline)'; then
  ok "test_close_plugin_failure_only_warns"
else
  bad "test_close_plugin_failure_only_warns" "out=$out"
fi

# A recording provider: the close envelope carries data, the stripped remote and extra.
git remote add origin "https://bot:s3cret@example.com/acme/app.git"
printf '%s\n' '#!/bin/sh' "cat > \"$R/close.stdin\"" 'echo "{\"status\": \"queued\", \"extra\": {\"ticket\": 7}}"' > "$PDIR/run"
out="$(aapp issue close 11 sha "$SHA" summary "Fixed a\|b and c|d" 2>&1)"; rc=$?
arow="$(grep -E '^\| #11 \|' .plans/done/000-issues-archive.md)"
if [ "$rc" -eq 0 ] && echo "$arow" | grep -qF 'Fixed a\|b and c\|d |' && ! grep -q '#11 ->' .plans/issues_road_map.md; then
  ok "test_close_summary_escapes_pipes"
else
  bad "test_close_summary_escapes_pipes" "rc=$rc row=$arow"
fi
if echo "$out" | grep -q 'handed to aapp-issue-tracker: queued' && \
   grep -q '"event": "issue.close"' "$R/close.stdin" && grep -q '"id": "#11"' "$R/close.stdin" && \
   grep -q '"url": "https://example.com/acme/app.git"' "$R/close.stdin" && ! grep -q 's3cret' "$R/close.stdin" && \
   grep -q '"plan": null' "$R/close.stdin" && grep -q '"extra": {}' "$R/close.stdin"; then
  ok "test_close_sends_envelope_and_reports_status"
else
  bad "test_close_sends_envelope_and_reports_status" "out=$out stdin=$(cat "$R/close.stdin" 2>/dev/null)"
fi
rm -rf "$PDIR"

out="$(aapp issue close '#10' 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q 'already archived' && \
   [ "$(grep -cE '^\| #10 \|' .plans/done/000-issues-archive.md)" -eq 1 ]; then
  ok "test_close_archived_is_idempotent"
else
  bad "test_close_archived_is_idempotent" "rc=$rc out=$out"
fi

aapp issue close 99 >/dev/null 2>&1; rc1=$?
aapp issue close 12 bogus >/dev/null 2>&1; rc2=$?
aapp issue close >/dev/null 2>&1; rc3=$?
if [ "$rc1" -ne 0 ] && [ "$rc2" -ne 0 ] && [ "$rc3" -ne 0 ] && grep -qE '^\| #12 \|' .plans/ISSUES.md; then
  ok "test_close_refuses_unknown_id_and_tokens"
else
  bad "test_close_refuses_unknown_id_and_tokens" "rc1=$rc1 rc2=$rc2 rc3=$rc3"
fi

echo "== list =="
for n in $(seq 20 44); do echo "- [ ] #$n -> Filler $n." >> .plans/issues_road_map.md; done
out="$(aapp issue list 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(echo "$out" | grep -c ' -> ')" -eq 20 ] && echo "$out" | tail -n 1 | grep -q '6 more (aapp issue list all)' && \
   echo "$out" | head -n 1 | grep -q '#12 ->'; then
  ok "test_list_default_cap_in_roadmap_order"
else
  bad "test_list_default_cap_in_roadmap_order" "rc=$rc out=$out"
fi
out1="$(aapp issue list 3 2>&1)"; out2="$(aapp issue list all 2>&1)"
aapp issue list -n >/dev/null 2>&1; rc=$?
if [ "$(echo "$out1" | grep -c ' -> ')" -eq 3 ] && [ "$(echo "$out2" | grep -c ' -> ')" -eq 26 ] && [ "$rc" -ne 0 ]; then
  ok "test_list_cap_tokens"
else
  bad "test_list_cap_tokens" "rc=$rc"
fi
git -C .plans checkout -q -- issues_road_map.md

echo "== done closes its target issue =="
id="P-$(git config aapp.planId)"
aapp draft close-twelve >/dev/null 2>&1
f="$(ls .plans/current/P"${id#P-}"-*.md)"
sed -i -E "s|src/path/to/file\.ext|src/twelve.py|g; /src\/path\/to\/new_file\.ext/d" "$f"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$f"
sed -i -E 's/^(\* \*\*Target Issue \/ Milestone:\*\*).*/\1 #12/' "$f"
sed -i -E "s/^\* \*\*Commits:\*\*.*/\* \*\*Commits:\*\* \`$SHA\` ($(git rev-parse --abbrev-ref HEAD))/" "$f"
git -C .plans commit -qam "prepare $id" >/dev/null 2>&1
aapp freeze-start "$id" >/dev/null 2>&1
aapp done "$id" >/dev/null 2>&1; rc=$?
arow="$(grep -E '^\| #12 \|' .plans/done/000-issues-archive.md)"
if [ "$rc" -eq 0 ] && ! grep -qE '^\| #12 \|' .plans/ISSUES.md && echo "$arow" | grep -qF "[$id](" && \
   ! grep -q '#12 ->' .plans/issues_road_map.md && [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_done_closes_target_issue"
else
  bad "test_done_closes_target_issue" "rc=$rc row=$arow"
fi

id="P-$(git config aapp.planId)"
aapp draft dangling-target >/dev/null 2>&1
f="$(ls .plans/current/P"${id#P-}"-*.md)"
sed -i -E "s|src/path/to/file\.ext|src/dangling.py|g; /src\/path\/to\/new_file\.ext/d" "$f"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$f"
sed -i -E 's/^(\* \*\*Target Issue \/ Milestone:\*\*).*/\1 #77/' "$f"
sed -i -E "s/^\* \*\*Commits:\*\*.*/\* \*\*Commits:\*\* \`$SHA\` ($(git rev-parse --abbrev-ref HEAD))/" "$f"
git -C .plans commit -qam "prepare $id" >/dev/null 2>&1
aapp freeze-start "$id" >/dev/null 2>&1
out="$(aapp done "$id" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && [ -f "$f" ] && echo "$out" | grep -q 'Target issue #77 is in neither'; then
  ok "test_done_refuses_dangling_target_issue"
else
  bad "test_done_refuses_dangling_target_issue" "rc=$rc"
fi

echo "== first use without a counter (config is not cloned) =="
# New project: init installs the template ledgers; the first issue is #1.
init_sandbox_project "$R/new"
cd "$R/new" || exit 1
git config --unset aapp.issueId 2>/dev/null
out1="$(aapp issue next 2>&1)"; out2="$(aapp issue allocate 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out1" | grep -q '#1$' && [ "$out2" = "#1" ] && [ "$(git config aapp.issueId)" = "2" ]; then
  ok "test_new_project_first_issue_is_1"
else
  bad "test_new_project_first_issue_is_1" "rc=$rc next=$out1 alloc=$out2"
fi

# Clone: ledgers arrive with real rows, the counter does not.
init_sandbox_project "$R/clone"
cd "$R/clone" || exit 1
cat > .plans/ISSUES.md <<'EOF'
| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #3 | `Low` | `CLI` | 2026-09-01 | `a.sh` | Open. | Fix. | 🟡 `Incubated` |
EOF
cat > .plans/done/000-issues-archive.md <<'EOF'
| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #7 | `Low` | `CLI` | 2026-08-01 | 2026-08-02 | `0000000` | Closed. |
EOF
git config --unset aapp.issueId 2>/dev/null
out1="$(aapp issue next 2>&1)"; unset_after_peek="$(git config --get aapp.issueId || echo unset)"
out2="$(aapp issue allocate 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out1" | grep -q '#8$' && [ "$unset_after_peek" = "unset" ] && \
   [ "$out2" = "#8" ] && [ "$(git config aapp.issueId)" = "9" ]; then
  ok "test_clone_first_allocate_continues_ledgers"
else
  bad "test_clone_first_allocate_continues_ledgers" "rc=$rc next=$out1 peek_left=$unset_after_peek alloc=$out2"
fi

# Remote-authority clone: no ledger files and no provider -> refuse, never #1.
rm -f .plans/ISSUES.md .plans/done/000-issues-archive.md
git config --unset aapp.issueId 2>/dev/null
out1="$(aapp issue next 2>&1)"; rc1=$?
out2="$(aapp issue allocate 2>&1)"; rc2=$?
if [ "$rc1" -ne 0 ] && [ "$rc2" -ne 0 ] && echo "$out2" | grep -q 'aapp-issue-tracker' && \
   [ -z "$(git config --get aapp.issueId)" ]; then
  ok "test_no_ledgers_without_provider_refuses"
else
  bad "test_no_ledgers_without_provider_refuses" "rc1=$rc1 rc2=$rc2 out=$out2"
fi

# Same clone once the team provider is installed: the provider issues the id.
mkdir -p .agents/skills/aapp-issue-tracker
printf '%s\n' '#!/bin/sh' '[ "$AAPP_ACTION" = allocate ] && echo "{\"id\": \"#120\"}"' > .agents/skills/aapp-issue-tracker/run
chmod +x .agents/skills/aapp-issue-tracker/run
out="$(aapp issue allocate 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "#120" ]; then
  ok "test_no_ledgers_with_provider_allocates"
else
  bad "test_no_ledgers_with_provider_allocates" "rc=$rc out=$out"
fi

echo "== hotfix and mini-plan fixes (P-52) =="
init_sandbox_project "$R/hf"
cd "$R/hf" || exit 1
cat > .plans/ISSUES.md <<'EOF'
# Issues

| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #10 | `Low` | `CORE` | 2026-10-01 | `a.sh` | Old defect. | Fix a. | 🟡 `Incubated` |
EOF
cat > .plans/issues_road_map.md <<'EOF'
# Issue Priority Board

## 🔴 High Priority (Technical Urgency)
- [ ] #10 -> Old defect.
EOF
cat > .plans/done/000-issues-archive.md <<'EOF'
# Archive

| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
EOF
git -C .plans add ISSUES.md issues_road_map.md done/000-issues-archive.md >/dev/null 2>&1
git -C .plans commit -qm "fixture" >/dev/null 2>&1
git config aapp.issueId 20; git config aapp.issueFixWait 0
hid="P-$(git config aapp.planId)"
aapp draft host-plan >/dev/null 2>&1
hf="$(ls .plans/current/P"${hid#P-}"-*.md)"; hrel="current/$(basename "$hf")"
sed -i -E "s|src/path/to/file\.ext|src/host.py|g; /src\/path\/to\/new_file\.ext/d" "$hf"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$hf"
git -C .plans commit -qam "prep host" >/dev/null 2>&1
aapp freeze-start "$hid" >/dev/null 2>&1
BUF="$(git rev-parse --git-path aapp_active_plan)"

head0="$(git -C .plans rev-parse HEAD)"
mv "$BUF" "$BUF.save"; aapp issue hotfix "No plan bound" file lib/x.sh >/dev/null 2>&1; r2=$?; mv "$BUF.save" "$BUF"
echo "#99" > "$BUF.mini"; cp "$BUF" "$BUF.keep"; cp "$BUF.mini" "$BUF"; aapp issue hotfix "Mini bound" file lib/x.sh >/dev/null 2>&1; r3=$?; mv "$BUF.keep" "$BUF"; rm -f "$BUF.mini"
if [ "$r2" -ne 0 ] && [ "$r3" -ne 0 ] && [ "$(git -C .plans rev-parse HEAD)" = "$head0" ] && [ "$(git config aapp.issueId)" = "20" ]; then
  ok "test_hotfix_refusals"
else
  bad "test_hotfix_refusals" "rc=$r2/$r3 issueId=$(git config aapp.issueId)"
fi

out="$(aapp issue hotfix "Parser crashes" file lib/x.sh 2>&1)"; rc=$?
rm_first_h2="$(grep -m1 '^## ' .plans/issues_road_map.md)"
if [ "$rc" -eq 0 ] && echo "$out" | grep -qF "#20" && \
   grep -qF '| #20 | `High` | `CORE` |' .plans/ISSUES.md && grep -qF '| `lib/x.sh` | Parser crashes |' .plans/ISSUES.md && \
   grep -qF "| blocks [$hid]($hrel) | 🟡 \`Incubated\` |" .plans/ISSUES.md && \
   [ "$rm_first_h2" = "## 🧱 Plan Blockers" ] && grep -qE '^- \[ \] #20 ' .plans/issues_road_map.md && \
   grep -qxF "* **Status:** 🟥 BLOCKED" "$hf" && grep -qxF "* **Blocked On:** #20 (was ⚡ In Development)" "$hf" && \
   grep -qxF "* **Emergency Hotfixes:** #20" "$hf" && \
   git -C .plans log -1 --format=%s | grep -qxF "issue(hotfix): #20 blocks $hid" && [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_hotfix_logs_queues_records_and_blocks"
else
  bad "test_hotfix_logs_queues_records_and_blocks" "rc=$rc out=$out h2=$rm_first_h2 status=$(git -C .plans status --porcelain | tr '\n' ' ')"
fi

out="$(aapp issue fix next-blocker 2>&1)"; rc=$?
mp=".plans/current/fix-20.md"
if [ "$rc" -eq 0 ] && [ -f "$mp" ] && grep -qxF "* **Plan ID:** #20" "$mp" && grep -q '⚡ In Development' "$mp" && \
   grep -qF '`lib/x.sh`' "$mp" && [ "$(cat "$BUF")" = "#20" ] && \
   [ "$(cat "$(git rev-parse --git-path aapp_active_plan.prev)")" = "$hid" ] && \
   git -C .plans log -1 --format=%s | grep -qxF "fix(start): #20"; then
  ok "test_fix_next_blocker_opens_mini_plan"
else
  bad "test_fix_next_blocker_opens_mini_plan" "rc=$rc out=$out buf=$(cat "$BUF" 2>/dev/null)"
fi

git config aapp.issueFixWait 0
head1="$(git -C .plans rev-parse HEAD)"
out="$(aapp issue fix 10 file a.sh 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "#20 is still being fixed" && [ ! -f .plans/current/fix-10.md ] && \
   [ "$(git -C .plans rev-parse HEAD)" = "$head1" ]; then
  ok "test_fix_one_at_a_time"
else
  bad "test_fix_one_at_a_time" "rc=$rc out=$out"
fi

aapp issue close 20 >/dev/null 2>&1; rc_nocommit=$?
mkdir -p lib; echo "fixed=1" > lib/x.sh; git add lib/x.sh
aapp commit "fix: parser crash (#20)" >/dev/null 2>&1; rc_c=$?
fsha="$(git rev-parse --short HEAD)"
out="$(aapp issue close 20 2>&1)"; rc=$?
if [ "$rc_nocommit" -ne 0 ] && [ "$rc_c" -eq 0 ] && [ "$rc" -eq 0 ] && [ ! -f "$mp" ] && \
   grep -qF "| #20 |" .plans/done/000-issues-archive.md && grep -qF "\`$fsha\`" .plans/done/000-issues-archive.md && \
   grep -qF "Fixed via aapp issue fix: lib/x.sh; unblocks $hid" .plans/done/000-issues-archive.md && \
   ! grep -q '#20' .plans/issues_road_map.md && grep -qxF "* **Status:** ⚡ In Development" "$hf" && \
   ! grep -q '^\* \*\*Blocked On:\*\*' "$hf" && grep -qxF "* **Emergency Hotfixes:** #20" "$hf" && \
   [ "$(cat "$BUF")" = "$hid" ] && [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_close_archives_and_unblocks"
else
  bad "test_close_archives_and_unblocks" "rc=$rc_nocommit/$rc_c/$rc out=$out status=$(grep -m1 '^\* \*\*Status' "$hf") buf=$(cat "$BUF" 2>/dev/null)"
fi

aapp issue hotfix "Second blocker" file lib/y.sh >/dev/null 2>&1
aapp issue hotfix "Third blocker" file lib/z.sh >/dev/null 2>&1
if grep -qxF "* **Emergency Hotfixes:** #20, #21, #22" "$hf" && grep -q '^\* \*\*Blocked On:\*\* #21, #22 .*hotfix limit reached' "$hf" && \
   grep -qE '^- \[ \] #22 ' .plans/issues_road_map.md; then
  ok "test_hotfix_over_limit_blocks_permanently"
else
  bad "test_hotfix_over_limit_blocks_permanently" "eh=$(grep 'Emergency Hotfixes' "$hf") bo=$(grep 'Blocked On' "$hf")"
fi

aapp issue fix 22 file lib/z.sh >/dev/null 2>&1
out="$(aapp issue fix 22 abort 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ ! -f .plans/current/fix-22.md ] && [ "$(cat "$BUF")" = "$hid" ] && \
   grep -qE '^- \[ \] #22 ' .plans/issues_road_map.md && grep -q '^\* \*\*Blocked On:\*\* .*#22' "$hf"; then
  ok "test_fix_abort_keeps_hotfix_queued"
else
  bad "test_fix_abort_keeps_hotfix_queued" "rc=$rc out=$out"
fi

aapp issue fix next-blocker >/dev/null 2>&1
echo "fixed=1" > lib/y.sh; git add lib/y.sh; aapp commit "fix: second (#21)" >/dev/null 2>&1
aapp issue close 21 >/dev/null 2>&1
if grep -qxF "* **Status:** 🟥 BLOCKED" "$hf" && grep -q '^\* \*\*Blocked On:\*\* #22 (was ⚡ In Development); hotfix limit reached' "$hf"; then
  ok "test_permanent_block_survives_close"
else
  bad "test_permanent_block_survives_close" "$(grep -E 'Status|Blocked On' "$hf")"
fi

lock="$(git rev-parse --git-common-dir)/aapp_issue.lock"
mkdir -p "$lock"; echo 999999 > "$lock/pid"
out="$(aapp issue hotfix "Behind a dead lock" file lib/w.sh 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -qi "stale" && [ ! -d "$lock" ]; then
  ok "test_stale_lock_taken_over"
else
  bad "test_stale_lock_taken_over" "rc=$rc out=$out"
fi
git config aapp.issueFixWait 1
( aapp issue hotfix "Racer one" file lib/r1.sh >/dev/null 2>&1 & aapp issue hotfix "Racer two" file lib/r2.sh >/dev/null 2>&1 & wait )
git config aapp.issueFixWait 0
n1="$(grep -F 'Racer one' .plans/ISSUES.md | awk -F'|' '{print $2}' | tr -d ' ')"
n2="$(grep -F 'Racer two' .plans/ISSUES.md | awk -F'|' '{print $2}' | tr -d ' ')"
if [ -n "$n1" ] && [ -n "$n2" ] && [ "$n1" != "$n2" ]; then
  ok "test_concurrent_hotfixes_get_distinct_ids"
else
  bad "test_concurrent_hotfixes_get_distinct_ids" "n1=$n1 n2=$n2"
fi

echo "== hotfix plan token and provider next-blocker (P-52) =="
init_sandbox_project "$R/hp"
cd "$R/hp" || exit 1
printf '%s\n' '# Issues' '' '| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |' > .plans/ISSUES.md
printf '%s\n' '# Issue Priority Board' '' '## 🔴 High Priority (Technical Urgency)' > .plans/issues_road_map.md
printf '%s\n' '# Archive' '' '| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- |' > .plans/done/000-issues-archive.md
git -C .plans add ISSUES.md issues_road_map.md done/000-issues-archive.md >/dev/null 2>&1; git -C .plans commit -qm fixture >/dev/null 2>&1
git config aapp.issueId 30
pid="P-$(git config aapp.planId)"; aapp draft blocked-host >/dev/null 2>&1
pf="$(ls .plans/current/P"${pid#P-}"-*.md)"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$pf"; git -C .plans commit -qam prep >/dev/null 2>&1
aapp freeze-start "$pid" >/dev/null 2>&1
dpid="$(git config aapp.planId)"
out="$(aapp issue hotfix "Needs a redesign" file lib/big.sh plan 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -qF '| #30 |' .plans/ISSUES.md && grep -F '| #30 |' .plans/ISSUES.md | grep -qF "🔵 \`Planned\`" && \
   grep -F '| #30 |' .plans/ISSUES.md | grep -qF "[P-${dpid}](current/P${dpid}-" && ! grep -q '#30' .plans/issues_road_map.md && \
   grep -q '^\* \*\*Blocked On:\*\* #30' "$pf" && ls .plans/current/P"${dpid}"-*.md >/dev/null 2>&1; then
  ok "test_hotfix_plan_token_promotes"
else
  bad "test_hotfix_plan_token_promotes" "rc=$rc out=$out row=$(grep '#30' .plans/ISSUES.md)"
fi
sed -i '/^## 🔴/i ## 🧱 Plan Blockers\n- [ ] #31 -> Provider pick (blocks X)\n' .plans/issues_road_map.md
mkdir -p .agents/skills/aapp-issue-tracker
printf '%s\n' '#!/bin/sh' 'if [ "$AAPP_ACTION" = next-blocker ]; then echo "{\"id\": \"#30\"}"; exit 0; fi' 'exit 1' > .agents/skills/aapp-issue-tracker/run
chmod +x .agents/skills/aapp-issue-tracker/run
out="$(aapp issue fix next-blocker file lib/big.sh 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -f .plans/current/fix-30.md ]; then
  ok "test_provider_next_blocker_claims"
else
  bad "test_provider_next_blocker_claims" "rc=$rc out=$out"
fi

out="$(aapp issue fix 30 file lib/extra.sh 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -qF '`lib/big.sh`' .plans/current/fix-30.md && grep -qF '`lib/extra.sh`' .plans/current/fix-30.md && \
   grep -qxF '* **Commits:** none' .plans/current/fix-30.md && git -C .plans log -1 --format=%s | grep -qxF "fix(files): #30"; then
  ok "test_fix_adds_files_to_open_mini_plan"
else
  bad "test_fix_adds_files_to_open_mini_plan" "rc=$rc out=$out"
fi

echo "== done of a promoted plan unblocks (P-52) =="
cd "$R/hp" || exit 1
rm -f .agents/skills/aapp-issue-tracker/run
aapp issue fix 30 abort >/dev/null 2>&1
dpf="$(ls .plans/current/P"${dpid}"-*.md)"
SHA="$(git rev-parse --short HEAD)"
sed -i -E "s|src/path/to/file\.ext|src/redesign.py|g; /src\/path\/to\/new_file\.ext/d" "$dpf"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$dpf"
sed -i -E "s/^\* \*\*Commits:\*\*.*/\* \*\*Commits:\*\* \`$SHA\` ($(git rev-parse --abbrev-ref HEAD))/" "$dpf"
git -C .plans commit -qam "prepare P-$dpid" >/dev/null 2>&1
aapp active clear >/dev/null 2>&1
aapp freeze-start "P-$dpid" >/dev/null 2>&1
aapp done "P-$dpid" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && grep -qxF "* **Status:** ⚡ In Development" "$pf" && ! grep -q '^\* \*\*Blocked On:\*\*' "$pf" && \
   git -C .plans show --name-only --format= HEAD | grep -qx "current/$(basename "$pf")"; then
  ok "test_done_of_promoted_plan_unblocks"
else
  bad "test_done_of_promoted_plan_unblocks" "rc=$rc $(grep -E '^\* \*\*(Status|Blocked On)' "$pf" | tr '\n' ' ')"
fi

echo "== hotfix by scope, stash, no stall (P-52, single checkout) =="
init_sandbox_project "$R/st"
cd "$R/st" || exit 1
printf '%s\n' '# Issues' '' '| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |' '| #10 | `Low` | `CORE` | 2026-10-01 | `src/dirty.py` | Old defect. | Fix it. | 🟡 `Incubated` |' > .plans/ISSUES.md
printf '%s\n' '# Issue Priority Board' '' '## 🔴 High Priority (Technical Urgency)' '- [ ] #10 -> Old defect.' > .plans/issues_road_map.md
printf '%s\n' '# Archive' '' '| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- |' > .plans/done/000-issues-archive.md
git -C .plans add ISSUES.md issues_road_map.md done/000-issues-archive.md >/dev/null 2>&1; git -C .plans commit -qm fixture >/dev/null 2>&1
git config aapp.issueId 20; git config aapp.issueFixWait 0
sid="P-$(git config aapp.planId)"; aapp draft scope-host >/dev/null 2>&1
sf="$(ls .plans/current/P"${sid#P-}"-*.md)"
sed -i -E "s|src/path/to/file\.ext|src/host.py|g; s|src/path/to/new_file\.ext|src/other.py|g" "$sf"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$sf"; git -C .plans commit -qam prep >/dev/null 2>&1
mkdir -p src; printf 'a1 = 1\na2 = 2\na3 = 3\na4 = 4\na5 = 5\n' > src/host.py; echo "o=1" > src/other.py; echo "d=1" > src/dirty.py
git add src && git commit -qm "base files" --no-verify >/dev/null 2>&1
aapp freeze-start "$sid" >/dev/null 2>&1
sed -i 's/^a5 = 5$/a5 = 50/' src/host.py; echo "o=2" > src/other.py
out="$(aapp issue hotfix "Bug in host" file src/host.py 2>&1)"; rc=$?
sbuf="$(git rev-parse --git-path aapp_hotfix_stash)"
if [ "$rc" -eq 0 ] && [ -z "$(git status --porcelain -- src/host.py)" ] && [ -n "$(git status --porcelain -- src/other.py)" ] && \
   [ -s "$sbuf" ] && git stash list | grep -qF "aapp-hotfix:$sid:#20"; then
  ok "test_hotfix_own_file_stashes_only_its_files"
else
  bad "test_hotfix_own_file_stashes_only_its_files" "rc=$rc out=$out status=$(git status --porcelain | tr '\n' ' ')"
fi
aapp issue fix next-blocker >/dev/null 2>&1
if .githooks/blast-radius-guard src/host.py >/dev/null 2>&1; then
  ok "test_mini_plan_edits_file_listed_by_blocked_plan"
else
  bad "test_mini_plan_edits_file_listed_by_blocked_plan" "guard refused src/host.py"
fi
sed -i 's/^a1 = 1$/a1 = 10/' src/host.py; git add src/host.py
cout="$(aapp commit "fix: host bug (#20)" 2>&1)"; rc_c=$?
out="$(aapp issue close 20 2>&1)"; rc=$?
[ "$rc_c" -eq 0 ] || echo "       commit: $(echo "$cout" | grep -E '❌|Staged|plan' | head -3 | tr '\n' ' ')"
if [ "$rc_c" -eq 0 ] && [ "$rc" -eq 0 ] && grep -qx 'a1 = 10' src/host.py && grep -qx 'a5 = 50' src/host.py && \
   [ ! -s "$sbuf" ] && ! git stash list | grep -qF "aapp-hotfix:" && grep -qxF "* **Status:** ⚡ In Development" "$sf"; then
  ok "test_close_reapplies_stash_on_top_of_fix"
else
  bad "test_close_reapplies_stash_on_top_of_fix" "rc=$rc_c/$rc out=$out host=$(tr '\n' '|' < src/host.py)"
fi
head0="$(git -C .plans rev-parse HEAD)"
echo "d=2" > src/dirty.py
out="$(aapp issue fix 10 file src/dirty.py 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "has uncommitted changes" && [ "$(git -C .plans rev-parse HEAD)" = "$head0" ]; then
  ok "test_fix_refuses_dirty_file"
else
  bad "test_fix_refuses_dirty_file" "rc=$rc out=$out"
fi
aapp issue hotfix "Clean blocker" file src/clean.py >/dev/null 2>&1
sed -i '/^## 🧱 Plan Blockers/a - [ ] #10 -> Old defect (dirty here).' .plans/issues_road_map.md
out="$(aapp issue fix next-blocker 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -f .plans/current/fix-21.md ] && [ ! -f .plans/current/fix-10.md ]; then
  ok "test_next_blocker_skips_untakeable"
else
  bad "test_next_blocker_skips_untakeable" "rc=$rc out=$out"
fi

echo "== fixes alongside active plans (P-58) =="
init_sandbox_project "$R/wd"
cd "$R/wd" || exit 1
printf '%s\n' '# Issues' '' '| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |' \
  '| #10 | `Low` | `CORE` | 2026-10-01 | `src/host.py` (`HOST_REGEX`) | Host defect. | Fix host. | 🟡 `Incubated` |' \
  '| #11 | `Low` | `CORE` | 2026-10-01 | `src/free.py:12-14` | Free defect. | Fix free. | 🟡 `Incubated` |' \
  '| #12 | `Low` | `CORE` | 2026-10-01 | `src/busy.py` | Busy defect. | Fix busy. | 🟡 `Incubated` |' > .plans/ISSUES.md
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
echo "h=2" > src/host.py; git add src/host.py; aapp commit "fix: host (#10)" >/dev/null 2>&1
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
echo "f=2" > src/free.py; git add src/free.py; aapp commit "fix: free (#11)" >/dev/null 2>&1
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

print_test_summary "$PASS" "$FAIL"
