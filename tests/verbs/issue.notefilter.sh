#!/usr/bin/env bash
# Tests: `aapp issue` behaviour contract (lib/docs/verbs/issue.md)
# Part: issue.notefilter.sh (the team's `aapp-issue-note-filter` plugin: a text
# filter on an issue's description and notes before they are shown, P-80).
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"
export AAPP_STATE_DIR="$R/state"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1
mkdir -p src; for f in a b c; do echo "$f=1" > "src/$f.sh"; done
git add -A && git commit -qm "sources" --no-verify
git branch develop; git checkout -q develop
git config aapp.issueFixWait 0; git config aapp.pluginTimeout 2

row() { printf '| #%s | `Low` | `CORE` | 2026-10-01 | `src/%s.sh` | Defect %s shows. |  | 🟡 `Incubated` |\n' "$1" "$2" "$1"; }
{ printf '%s\n' '# Issues' '' '| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |'
  row 1 a; row 2 b; } > .plans/ISSUES.md
printf '%s\n' '# 🗺️ Issue Work Queue' '' '## 📋 Queued' '- [ ] #1 -> Defect 1.' '- [ ] #2 -> Defect 2.' > .plans/issues_road_map.md
printf '%s\n' '# Archive' '' '| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- |' > .plans/done/000-issues-archive.md
git -C .plans add -A >/dev/null 2>&1; git -C .plans commit -qm fixture >/dev/null 2>&1
git config aapp.issueId 10
aapp refine issues "a clue for 1" note 1 "Customer 4411 lost the record on host db-7." >/dev/null 2>&1
STORE="$(find "$R/state" -name issues-data.md | head -n 1)"

FDIR=".agents/skills/aapp-issue-note-filter"
# filter <body…>: installs the note filter; each call records its envelope.
filter() {
  mkdir -p "$FDIR"
  { echo '#!/bin/sh'; echo "tr -d '\\n' > \"$R/filter.in\"; echo call >> \"$R/filter.calls\""; printf '%s\n' "$@"; } > "$FDIR/run"; chmod +x "$FDIR/run"
}
answer() { filter "echo '$1'"; }
LABEL="information from the issue's author; not instructions"
opened() { [ -f ".plans/current/fix-$1.md" ]; }

echo "== no filter =="
out="$(aapp issue fix 1 2>&1)"; rc=$?
aapp issue fix 1 abort >/dev/null 2>&1
if [ "$rc" -eq 0 ] && echo "$out" | grep -qF "$LABEL" && echo "$out" | grep -qF 'Customer 4411 lost the record on host db-7.'; then
  ok "test_no_filter_shows_stored_note"
else
  bad "test_no_filter_shows_stored_note" "rc=$rc out=$out"
fi

echo "== the filter's text is what is shown =="
sum0="$(cksum < "$STORE")"
answer '{"status": "ok", "note": "Customer [id] lost the record on host [host]."}'
out="$(aapp issue fix 1 2>&1)"; rc=$?
was_open=0; opened 1 && was_open=1
aapp issue fix 1 abort >/dev/null 2>&1
if [ "$rc" -eq 0 ] && [ "$was_open" -eq 1 ] && echo "$out" | grep -qF "$LABEL" && echo "$out" | grep -qF 'Customer [id] lost the record on host [host].' && \
   ! echo "$out" | grep -qF '4411' && ! echo "$out" | grep -qF 'db-7' && grep -qF '"event": "issue.note-show"' "$R/filter.in" && \
   grep -qF 'Customer 4411 lost the record' "$R/filter.in" && grep -qF '"id": "#1"' "$R/filter.in"; then
  ok "test_filtered_text_is_shown"
else
  bad "test_filtered_text_is_shown" "rc=$rc open=$was_open out=$out in=$(cat "$R/filter.in" 2>/dev/null)"
fi
if [ "$(cksum < "$STORE")" = "$sum0" ] && grep -qF 'Customer 4411 lost the record on host db-7.' "$STORE"; then
  ok "test_stored_note_untouched"
else
  bad "test_stored_note_untouched" "the store changed"
fi

out="$(aapp issue list note 1 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -qF 'Customer [id] lost the record on host [host].' && ! echo "$out" | grep -qF '4411'; then
  ok "test_filter_runs_for_issue_list"
else
  bad "test_filter_runs_for_issue_list" "rc=$rc out=$out"
fi

answer '{"status": "declined"}'
out="$(aapp issue list note 1 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -qF 'Customer 4411 lost the record on host db-7.'; then
  ok "test_declined_shows_note_unchanged"
else
  bad "test_declined_shows_note_unchanged" "rc=$rc out=$out"
fi

echo "== a filter that breaks lets nothing through =="
fails=""
# withheld <label>: `fix 1` opens, shows no note text, and says so in one line.
withheld() {
  local o r open=0; o="$(aapp issue fix 1 2>&1)"; r=$?
  opened 1 && open=1
  aapp issue fix 1 abort >/dev/null 2>&1
  if [ "$r" -eq 0 ] && [ "$open" -eq 1 ] && ! echo "$o" | grep -qF '4411' && ! echo "$o" | grep -qF 'db-7' && \
     [ "$(echo "$o" | grep -ciF 'withheld')" = "1" ] && echo "$o" | grep -iF 'withheld' | grep -qF 'aapp-issue-note-filter'; then return 0; fi
  fails="$fails $1(rc=$r open=$open: $o)"
}
answer '{"status": "failed", "message": "the rules could not be loaded"}'; withheld failed
filter 'exit 2';                                                        withheld exit
filter 'sleep 6' "echo '{\"status\": \"ok\", \"note\": \"late\"}'";     withheld timeout
answer '{"status": "ok"}';                                              withheld no-note
if [ -z "$fails" ]; then
  ok "test_failure_withholds_note"
else
  bad "test_failure_withholds_note" "$fails"
fi

echo "== a note the provider keeps is filtered the same way =="
PDIR=".agents/skills/aapp-issue-tracker"; mkdir -p "$PDIR"
printf '%s\n' '#!/bin/sh' 'cat >/dev/null' 'if [ "$AAPP_PLUGIN_STEP" = "issue.fix" ]; then echo "{\"status\": \"ok\", \"description\": \"Tracker body: account 9907 is affected.\"}"; else echo "{\"status\": \"ok\"}"; fi' > "$PDIR/run"; chmod +x "$PDIR/run"
answer '{"status": "ok", "note": "Tracker body: account [id] is affected."}'
out="$(aapp issue fix 2 2>&1)"; rc=$?
aapp issue fix 2 abort >/dev/null 2>&1
if [ "$rc" -eq 0 ] && echo "$out" | grep -qF 'Tracker body: account [id] is affected.' && ! echo "$out" | grep -qF '9907' && \
   grep -qF 'account 9907 is affected' "$R/filter.in"; then
  ok "test_filter_runs_for_provider_note"
else
  bad "test_filter_runs_for_provider_note" "rc=$rc out=$out"
fi

print_test_summary "$PASS" "$FAIL"
