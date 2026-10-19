#!/usr/bin/env bash
# Core suite for event telemetry (P-104): the observer envelopes and payloads
# the lifecycle verbs dispatch, against docs/reference/09-event-telemetry.md.
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

PROJ="$R/telemetry_proj"
init_sandbox_project "$PROJ"
cd "$PROJ" || exit 1
git add -A && git commit -qm "init project" --no-verify

# The sample event logger, registered for every post-* event, records each
# envelope it is handed as one line of $AAPP_LOG_FILE.
mkdir -p .agents/hooks .agents/skills/aapp-hooks
cp "$KIT/examples/hooks/event-logger.sample" .agents/hooks/event-logger
chmod +x .agents/hooks/event-logger
export AAPP_LOG_FILE="$R/events.jsonl"
for ev in post-draft post-freeze post-start post-refine post-done post-abort post-active post-tdd \
          post-commit post-land post-issue post-pause post-resume post-sync; do
  aapp hook-hash .agents/hooks/event-logger "$ev" 10 notify 2>/dev/null | grep "^$ev" >> .agents/skills/aapp-hooks/registry.tsv
done
(cd .agents && git add -A && git commit -qm "chore: register test hooks" --no-verify)

# last_has <step> <text>…: the last recorded envelope holds every <text>.
last_has() {
  local step="$1" last; shift
  last="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
  local t; for t in "$@"; do
    printf '%s' "$last" | grep -qF "$t" || { t_fail "$step: no [$t] in $last"; return; }
  done
}
# plan_id <slug>: the id of the plan drafted as <slug>.
plan_id() { sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' .plans/current/P*-"$1".md | head -1; }

echo "== plan lifecycle =="
aapp draft telemetry-feature >/dev/null 2>&1
last_has draft '"event": "post-draft"' '"command": "plan"' '"event": "draft"'
pid="$(plan_id telemetry-feature)"; pf="$(ls .plans/current/P*-telemetry-feature.md)"
aapp active "$pid" >/dev/null 2>&1
last_has "active set" '"event": "post-active"' '"command": "plan"' '"action": "set"'
aapp active clear >/dev/null 2>&1
last_has "active clear" '"action": "clear"'
aapp draft tdd-feature >/dev/null 2>&1
tpid="$(plan_id tdd-feature)"
aapp tdd "$tpid" >/dev/null 2>&1
last_has tdd '"event": "post-tdd"' '"command": "plan"' '"event": "tdd"'
aapp plan abort "$tpid" reason "tdd check complete" confirm >/dev/null 2>&1
last_has abort '"event": "post-abort"' '"command": "plan"' '"event": "abort"'
sed -i 's/\* \[ \]/\* \[x\]/g' "$pf"
sed -i '/^### 📂 Target Files/,/^### 🛑/ { /^### 📂 Target Files/b; /^### 🛑/b; d; }' "$pf"
sed -i '/^### 📂 Target Files/a - `main.py` -> Target file.' "$pf"
aapp refine "$pid" "resolve questions and targets" >/dev/null 2>&1
last_has refine '"event": "post-refine"' '"command": "plan"' '"event": "refine"'
aapp freeze "$pid" >/dev/null 2>&1
last_has freeze '"event": "post-freeze"' '"command": "plan"' '"event": "freeze"'
aapp start "$pid" >/dev/null 2>&1
last_has start '"event": "post-start"' '"command": "plan"' '"event": "start"'
echo "# app update" >> main.py; git add main.py
aapp commit "feat: update main" agent Antigravity vendor Google model gemini-3.8-flash >/dev/null 2>&1
last_has commit '"event": "post-commit"' '"command": "commit"' '"agent": "Antigravity"'
aapp done "$pid" >/dev/null 2>&1
last_has done '"event": "post-done"' '"command": "plan"' '"event": "done"'
t_done test_plan_lifecycle_events

echo "== issue lifecycle =="
mkdir -p src && touch src/issue1.txt
git add src/issue1.txt && git commit -qm "feat: add issue1 file" --no-verify
aapp issue log Medium CLI "Telemetry issue symptom" file src/issue1.txt >/dev/null 2>&1
last_has log '"event": "post-issue"' '"command": "issue"' '"event": "log"'
aapp issue queue 1 urgent >/dev/null 2>&1
last_has queue '"command": "issue"' '"event": "queue"' '"level": "urgent"'
aapp issue queue 1 remove >/dev/null 2>&1
last_has unqueue '"command": "issue"' '"event": "unqueue"'
aapp issue queue 1 >/dev/null 2>&1
aapp issue fix 1 >/dev/null 2>&1
last_has fix '"command": "issue"' '"event": "fix"'
( cd .workspace/fix-1 && echo "# fix 1" >> src/issue1.txt && git add src/issue1.txt && \
  aapp commit "fix: fix issue 1" changelog "fixed telemetry issue" ) >/dev/null 2>&1
aapp issue close 1 >/dev/null 2>&1
last_has close '"command": "issue"' '"event": "close"'
aapp issue log Low CLI "Withdrawn issue symptom" >/dev/null 2>&1
aapp issue abort 2 reason "Not needed" confirm >/dev/null 2>&1
last_has withdraw '"command": "issue"' '"event": "withdraw"'
t_done test_issue_lifecycle_events

echo "== pause and resume =="
aapp pause "switching tasks" >/dev/null 2>&1
last_has pause '"event": "post-pause"' '"command": "pause"' '"event": "pause"'
aapp resume >/dev/null 2>&1
last_has resume '"event": "post-resume"' '"command": "pause"' '"event": "resume"'
t_done test_pause_resume_events

echo "== sync =="
git init -q --bare "$R/remote.git"
git remote add origin "$R/remote.git"
for wt in .plans .agents .githooks; do
  git -C "$wt" remote add origin "$R/remote.git" 2>/dev/null
  git -C "$wt" push -q -u origin HEAD >/dev/null 2>&1
done
git push -q -u origin HEAD >/dev/null 2>&1
aapp sync origin >/dev/null 2>&1
last_has sync '"event": "post-sync"' '"command": "sync"' '"event": "sync"'
t_done test_sync_event

print_test_summary "$PASS" "$FAIL"
