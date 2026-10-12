#!/usr/bin/env bash
# Tests: `aapp issue` behaviour contract (lib/docs/verbs/issue.md)
# Part: issue.provider.sh (the handler `issue log`, the three parts of an
# issue's text, and the provider wrapper, P-74).
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'chmod -R u+rwx "$R" 2>/dev/null; rm -rf "$R"' EXIT
confine_test_runtime "$R"
export AAPP_STATE_DIR="$R/state"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1
mkdir -p src; for f in a b c d e f g h; do echo "$f=1" > "src/$f.sh"; done
git add -A && git commit -qm "sources" --no-verify
git branch develop; git checkout -q develop
git config aapp.planWorktrees on; git config aapp.commitMode microcommits
git config aapp.issueFixWait 0; git config aapp.pluginTimeout 2

row() { printf '| #%s | `Low` | `CORE` | 2026-10-01 | `src/%s.sh` | Defect %s shows. |  | 🟡 `Incubated` |\n' "$1" "$2" "$1"; }
{ printf '%s\n' '# Issues' '' '| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |'
  row 1 a; row 2 b; row 3 c; row 4 d; row 5 e; row 6 f; row 7 g; } > .plans/ISSUES.md
{ printf '%s\n' '# Issue Priority Board' '' '## 📥 Triage (Incoming / Unsequenced)'; for n in 1 2 3 4 5 6 7; do echo "- [ ] #$n -> Defect $n."; done; } > .plans/issues_road_map.md
printf '%s\n' '# Archive' '' '| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- |' > .plans/done/000-issues-archive.md
git -C .plans add -A >/dev/null 2>&1; git -C .plans commit -qm fixture >/dev/null 2>&1
git config aapp.issueId 10

pf() { ls .plans/current/P"${1#P-}"-*.md 2>/dev/null; }
has_row() { grep -qE "^\| #$1 \|" .plans/ISSUES.md; }
rows() { grep -cE '^\| #' .plans/ISSUES.md; }
store() { find "$R/state" -name issues-data.md 2>/dev/null | head -n 1; }
PDIR=".agents/skills/aapp-issue-tracker"
# plugin <body…>: installs the provider. Each call appends its envelope, on one
# line, to $R/log, then runs the given lines. It never calls `aapp` itself.
plugin() {
  mkdir -p "$PDIR"
  { echo '#!/bin/sh'; echo "tr -d '\\n' >> \"$R/log\"; echo >> \"$R/log\""; printf '%s\n' "$@"; } > "$PDIR/run"; chmod +x "$PDIR/run"
}
answer() { plugin "echo '$1'"; }
no_plugin() { rm -rf "$PDIR"; }
reset_log() { : > "$R/log"; }
calls() { grep -c . "$R/log" 2>/dev/null; }
# sent <event>: the last envelope of that event; data_of: its data object.
sent() { grep -F "\"event\": \"$1\"" "$R/log" 2>/dev/null | tail -n 1; }
data_of() { sent "$1" | sed -E 's/.*"data": *//; s/, *"extra": *\{\} *\} *$//'; }
reset_log

echo "== the handler =="
head0="$(git -C .plans rev-parse HEAD)"
out="$(aapp issue log Low CLI "The parser drops its last line" file src/a.sh 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -qF '| #10 | `Low` | `CLI` |' .plans/ISSUES.md && grep -E '^\| #10 \|' .plans/ISSUES.md | grep -qF '| `src/a.sh` | The parser drops its last line |' && \
   grep -qE '#10 -> ' .plans/issues_road_map.md && [ "$(git config aapp.issueId)" = "11" ] && \
   [ "$(git -C .plans log -1 --format=%s)" = "issue(log): #10" ] && [ "$(git -C .plans rev-list --count "$head0"..HEAD)" = "1" ] && \
   [ -z "$(git -C .plans status --porcelain)" ] && echo "$out" | grep -qF "#10"; then
  ok "test_log_writes_row_with_kit_id"
else
  bad "test_log_writes_row_with_kit_id" "rc=$rc out=$out row=$(grep -E '^\| #10 ' .plans/ISSUES.md) subject=$(git -C .plans log -1 --format=%s)"
fi

n0="$(rows)"; long="$(printf 'x%.0s' $(seq 1 251))"
out="$(aapp issue log Low CLI "$long" file src/a.sh 2>&1)"; rc=$?
out2="$(aapp issue log Low CLI "$(printf 'First line\nsecond line')" file src/b.sh 2>&1)"; rc2=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qiF "note" && [ "$rc2" -eq 0 ] && [ "$(rows)" = "$((n0 + 1))" ] && \
   grep -E '^\| #11 \|' .plans/ISSUES.md | grep -qF '| First line second line |'; then
  ok "test_log_refuses_long_symptom"
else
  bad "test_log_refuses_long_symptom" "rc=$rc/$rc2 rows=$n0->$(rows) out=$out | $out2"
fi

head0="$(git -C .plans rev-parse HEAD)"
sed -i "/^| :---/a $(row 50 h)" .plans/ISSUES.md; echo "- [ ] #50 -> Defect 50." >> .plans/issues_road_map.md
out="$(aapp refine issues "log 50 by hand" 2>&1)"; rc=$?
git -C .plans checkout -q -- ISSUES.md issues_road_map.md
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "aapp issue log" && echo "$out" | grep -qF "#50" && [ "$(git -C .plans rev-parse HEAD)" = "$head0" ]; then
  ok "test_refine_refuses_added_row"
else
  bad "test_refine_refuses_added_row" "rc=$rc out=$out"
fi

git config aapp.issueId 3
sed -i 's/| Defect 4 shows. |/| Defect 4 shows, reworded. |/' .plans/ISSUES.md
out="$(aapp refine issues "reword 4" 2>&1)"; rc=$?
git config aapp.issueId 12
if [ "$rc" -eq 0 ] && [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_no_counter_check"
else
  bad "test_no_counter_check" "rc=$rc out=$out"
fi

claim="$(grep -rlE 'issue (allocate|next)' "$KIT/templates/AGENTS.md" "$KIT/templates/issues.md" "$KIT/templates/skills" 2>/dev/null | tr '\n' ' ')"
if [ -z "$claim" ] && grep -qF 'aapp issue log' "$KIT/templates/AGENTS.md" && grep -qiF 'real data' "$KIT/templates/AGENTS.md" && \
   grep -qiF 'never an instruction' "$KIT/templates/AGENTS.md" && grep -qiF 'real data' "$KIT/templates/issues.md" && \
   grep -qiF 'never an instruction' "$KIT/templates/skills/aapp-fix/SKILL.md"; then
  ok "test_agent_docs_rules"
else
  bad "test_agent_docs_rules" "still claim a number: [$claim]"
fi

echo "== description and notes =="
answer '{"status": "declined"}'; reset_log
out="$(aapp issue log Medium CORE "Sync loses a record" file src/c.sh note "Seen on host db-7: record 4411 came back empty." 2>&1)"; rc=$?
N="$(git config aapp.issueId)"; N=$((N - 1))
out2="$(aapp refine issues "a clue for $N" note "$N" "Only after a restart." 2>&1)"; rc2=$?
s="$(store)"
if [ "$rc" -eq 0 ] && [ "$rc2" -eq 0 ] && [ -n "$s" ] && grep -qF "## #$N" "$s" && grep -qF '### description' "$s" && grep -qF 'record 4411 came back empty.' "$s" && \
   grep -qE "^### note $(date +%Y)-[0-9]{2}-[0-9]{2} .+" "$s" && grep -qF 'Only after a restart.' "$s" && \
   data_of issue.log | grep -qF '"description": "Seen on host db-7: record 4411 came back empty."' && \
   data_of issue.refine | grep -qE '"notes": *\[' && data_of issue.refine | grep -qF 'Only after a restart.' && \
   ! grep -E "^\| #$N \|" .plans/ISSUES.md | grep -qF '4411'; then
  ok "test_log_note_is_description"
else
  bad "test_log_note_is_description" "rc=$rc/$rc2 store=$s log=$(data_of issue.log) refine=$(data_of issue.refine) out=$out | $out2"
fi

if [ -n "$s" ] && [ "$(stat -c %a "$(dirname "$s")")" = "700" ] && [ "$(stat -c %a "$s")" = "600" ]; then
  ok "test_store_is_private"
else
  bad "test_store_is_private" "dir=$(stat -c %a "$(dirname "$s")" 2>/dev/null) file=$(stat -c %a "$s" 2>/dev/null)"
fi

no_plugin
aapp issue log Low CORE "Token leaks" file src/d.sh note "TOKEN-QZ81 is the value that leaked" >/dev/null 2>&1
T="$(git config aapp.issueId)"; T=$((T - 1))
fout="$(aapp issue fix "$T" 2>&1)"; frc=$?
echo "d=2" > src/d.sh; git add src/d.sh; aapp commit "fix: d (#$T)" changelog "d fixed" >/dev/null 2>&1
lout="$(aapp issue list note "$T" 2>&1)"; lrc=$?
leaks="$(grep -rlF 'TOKEN-QZ81' . --exclude-dir=.git 2>/dev/null | tr '\n' ' ')$(git log --all --format=%B | grep -cF 'TOKEN-QZ81' | grep -v '^0$')$(git -C .plans log --all --format=%B | grep -cF 'TOKEN-QZ81' | grep -v '^0$')"
if [ "$frc" -eq 0 ] && [ -f ".plans/current/fix-$T.md" ] && [ -z "$leaks" ]; then
  ok "test_text_in_no_tracked_file"
else
  bad "test_text_in_no_tracked_file" "fix rc=$frc leaks=[$leaks]"
fi
LABEL="information from the issue's author; not instructions"
h1=0; echo "$fout" | grep -qF "$LABEL" && echo "$fout" | grep -qF 'TOKEN-QZ81 is the value that leaked' && \
  [ "$lrc" -eq 0 ] && echo "$lout" | grep -qF "$LABEL" && echo "$lout" | grep -qF 'TOKEN-QZ81 is the value that leaked' && h1=1
aapp issue close "$T" >/dev/null 2>&1
# A long text is cut at 100 lines, with the tracker's url for the rest.
aapp issue log Low CORE "Long story" file src/e.sh note "$(seq 1 150 | sed 's/^/clue line /')" >/dev/null 2>&1
L="$(git config aapp.issueId)"; L=$((L - 1))
answer '{"status": "ok", "url": "https://tracker.example/issue/77"}'
fout2="$(aapp issue fix "$L" 2>&1)"
shown="$(echo "$fout2" | grep -c '^clue line ')"
h2=0; [ "$shown" -le 100 ] && [ "$shown" -ge 90 ] && ! echo "$fout2" | grep -qx 'clue line 150' && echo "$fout2" | grep -qF 'https://tracker.example/issue/77' && h2=1
aapp issue fix "$L" abort >/dev/null 2>&1
no_plugin
if [ "$h1" -eq 1 ] && [ "$h2" -eq 1 ]; then
  ok "test_handover_block"
else
  bad "test_handover_block" "block=$h1 cut=$h2 shown=$shown fix=$fout | list=$lout"
fi

mkdir -p "$R/ro"; chmod 500 "$R/ro"
n0="$(rows)"
out="$(AAPP_STATE_DIR="$R/ro" aapp issue log Low CORE "No place for the text" file src/f.sh note "kept nowhere" 2>&1)"; rc=$?
chmod 700 "$R/ro"
if [ "$rc" -eq 0 ] && [ "$(rows)" = "$((n0 + 1))" ] && [ "$(echo "$out" | grep -ciE 'could not be kept|not kept')" = "1" ]; then
  ok "test_store_unreachable_carries_on"
else
  bad "test_store_unreachable_carries_on" "rc=$rc rows=$n0->$(rows) out=$out"
fi

echo "== the provider and the id =="
answer '{"status": "ok", "id": "#60"}'
aapp issue log Low CORE "Kept by the kit" file src/g.sh note "LOCALTEXT stays here" >/dev/null 2>&1
answer '{"status": "ok", "id": "#61", "handled": "description, notes"}'
aapp issue log Low CORE "Kept by the tracker" file src/g.sh note "REMOTETEXT goes away" >/dev/null 2>&1
if has_row 60 && has_row 61 && grep -qF 'LOCALTEXT stays here' "$(store)" && ! grep -qF 'REMOTETEXT' "$(store)"; then
  ok "test_unhandled_text_stays_local"
else
  bad "test_unhandled_text_stays_local" "60=$(has_row 60 && echo y) 61=$(has_row 61 && echo y) store=$(grep -c TEXT "$(store)")"
fi

reset_log; answer '{"status": "ok", "id": "#62"}'
aapp issue log High NET "Socket closes early" file src/h.sh file src/a.sh note "Body text." >/dev/null 2>&1
d="$(data_of issue.log)"
if [ "$(calls)" = "1" ] && echo "$d" | grep -qF '"sev": "High"' && echo "$d" | grep -qF '"type": "NET"' && echo "$d" | grep -qF '"symptom": "Socket closes early"' && \
   echo "$d" | grep -qF '"description": "Body text."' && echo "$d" | grep -qF 'src/h.sh' && echo "$d" | grep -qF '"date": "' && \
   echo "$d" | grep -qF '"status": "' && ! echo "$d" | grep -qF '"id"'; then
  ok "test_log_sends_whole_issue_without_id"
else
  bad "test_log_sends_whole_issue_without_id" "calls=$(calls) data=$d"
fi

answer '{"status": "ok", "id": "PROJ-101", "tracker": "jira", "url": "https://jira.example/PROJ-101", "version": "2.4"}'
out="$(aapp issue log Low CLI "A key from the tracker" file src/a.sh 2>&1)"; rc=$?
lout="$(aapp issue list all 2>&1)"
if [ "$rc" -eq 0 ] && has_row PROJ-101 && echo "$lout" | grep -F '#PROJ-101' | grep -F 'jira' | grep -F 'https://jira.example/PROJ-101' | grep -qF '2.4'; then
  ok "test_log_takes_provider_id"
else
  bad "test_log_takes_provider_id" "rc=$rc out=$out list=$(echo "$lout" | grep -F PROJ-101)"
fi

n0="$(rows)"; head0="$(git -C .plans rev-parse HEAD)"
answer '{"status": "ok"}'
out="$(aapp issue log Low CLI "No id comes back" file src/a.sh 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && [ "$(rows)" = "$n0" ] && [ "$(git -C .plans rev-parse HEAD)" = "$head0" ] && [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_log_refuses_ok_without_id"
else
  bad "test_log_refuses_ok_without_id" "rc=$rc rows=$n0->$(rows) out=$out"
fi

plugin 'echo "{\"error\": \"tracker is down\"}"' 'exit 4'
out="$(aapp issue log Low CLI "The tracker is down" file src/a.sh 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && [ "$(rows)" = "$n0" ] && [ "$(git -C .plans rev-parse HEAD)" = "$head0" ] && echo "$out" | grep -qF "tracker is down"; then
  ok "test_log_refuses_when_provider_fails"
else
  bad "test_log_refuses_when_provider_fails" "rc=$rc rows=$n0->$(rows) out=$out"
fi

answer '{"status": "declined"}'
c0="$(git config aapp.issueId)"
out="$(aapp issue log Low CLI "The tracker has no opinion" file src/a.sh 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && has_row "$c0" && [ "$(git config aapp.issueId)" = "$((c0 + 1))" ]; then
  ok "test_declined_log_uses_counter"
else
  bad "test_declined_log_uses_counter" "rc=$rc counter=$c0->$(git config aapp.issueId) out=$out"
fi

reset_log; answer '{"status": "ok", "id": "#70"}'
aapp issue log Low CLI "$long" file src/a.sh >/dev/null 2>&1
aapp issue log Enormous CLI "Bad severity" file src/a.sh >/dev/null 2>&1; rb=$?
sed -i 's/^| #5 | `Low` |/| #5 |/' .plans/ISSUES.md
aapp refine issues "a broken table" >/dev/null 2>&1; rr=$?
git -C .plans checkout -q -- ISSUES.md
if [ "$(calls)" = "0" ] && [ "$rb" -ne 0 ] && [ "$rr" -ne 0 ] && ! has_row 70; then
  ok "test_refused_row_never_sent"
else
  bad "test_refused_row_never_sent" "calls=$(calls) rc=$rb/$rr"
fi

echo "== the steps =="
SHA="$(git rev-parse --short=7 develop)"
reset_log; answer '{"status": "ok"}'
out="$(aapp issue close 1 sha "$SHA" summary "Fixed in passing." 2>&1)"; rc=$?
d="$(data_of issue.close)"
if [ "$rc" -eq 0 ] && echo "$d" | grep -qF '"id": "#1"' && echo "$d" | grep -qF '"symptom": "Defect 1 shows."' && echo "$d" | grep -qF '"sev": "Low"' && \
   echo "$d" | grep -qF "\"commit\": \"$SHA\"" && echo "$d" | grep -qF '"summary": "Fixed in passing."'; then
  ok "test_close_sends_whole_issue"
else
  bad "test_close_sends_whole_issue" "rc=$rc data=$d out=$out"
fi

reset_log
aapp issue fix 2 >/dev/null 2>&1; f1="$(data_of issue.fix)"
out="$(aapp issue fix 2 abort 2>&1)"; rc=$?
d="$(data_of issue.fix-abort)"
if [ "$rc" -eq 0 ] && echo "$f1" | grep -qF '"id": "#2"' && echo "$d" | grep -qF '"id": "#2"' && echo "$d" | grep -qF '"symptom": "Defect 2 shows."' && has_row 2; then
  ok "test_fix_abort_sends_fix_abort"
else
  bad "test_fix_abort_sends_fix_abort" "rc=$rc fix=$f1 abort=$d out=$out"
fi

reset_log
out="$(aapp issue abort 3 reason "Not a defect after all" 2>&1)"; rc=$?
d="$(data_of issue.abort)"
if [ "$rc" -eq 0 ] && echo "$d" | grep -qF '"id": "#3"' && echo "$d" | grep -qF '"reason": "Not a defect after all"' && ! has_row 3; then
  ok "test_issue_abort_sends_abort"
else
  bad "test_issue_abort_sends_abort" "rc=$rc data=$d out=$out"
fi

reset_log
D="P-$(git config aapp.planId)"; aapp draft promo issue 4 >/dev/null 2>&1
p1="$(data_of issue.refine)"
out="$(aapp plan abort "$D" reason "Dropped" 2>&1)"; rc=$?
p2="$(data_of issue.refine)"
if [ "$rc" -eq 0 ] && echo "$p1" | grep -qF '"id": "#4"' && echo "$p1" | grep -qF 'Planned' && echo "$p2" | grep -qF '"id": "#4"' && echo "$p2" | grep -qF 'Incubated' && \
   ! echo "$p2" | grep -qF 'Planned'; then
  ok "test_plan_abort_sends_refine"
else
  bad "test_plan_abort_sends_refine" "rc=$rc planned=$p1 back=$p2 out=$out"
fi

plugin 'exit 1'; fb=""
# falls_back <label> <command…>: the kit completes the step and warns.
falls_back() {
  local label="$1" o r; shift
  o="$("$@" 2>&1)"; r=$?
  if [ "$r" -ne 0 ] || ! echo "$o" | grep -qF "aapp-issue-tracker"; then fb="$fb $label(rc=$r: $(echo "$o" | head -n 2 | tr '\n' ' '))"; fi
}
falls_back refine aapp refine issues "a clue for 5" note 5 "Something."
falls_back fix aapp issue fix 5
falls_back fix-abort aapp issue fix 5 abort
falls_back abort aapp issue abort 6 reason "Withdrawn anyway"
falls_back close aapp issue close 5 sha "$SHA" summary "Closed anyway."
falls_back list aapp issue list
if [ -z "$fb" ] && ! has_row 5 && ! has_row 6; then
  ok "test_failure_falls_back_and_warns"
else
  bad "test_failure_falls_back_and_warns" "$fb 5=$(has_row 5 && echo open) 6=$(has_row 6 && echo open)"
fi

answer '{"status": "ok"}'; reset_log
git commit -q --allow-empty -m "chore: a commit through the hooks" >/dev/null 2>&1; crc=$?
if [ "$crc" -eq 0 ] && [ "$(calls)" = "0" ]; then
  ok "test_hooks_never_call_provider"
else
  bad "test_hooks_never_call_provider" "commit rc=$crc calls=$(calls)"
fi

print_test_summary "$PASS" "$FAIL"
