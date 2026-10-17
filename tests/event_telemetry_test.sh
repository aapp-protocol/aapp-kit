#!/usr/bin/env bash
# ==============================================================================
# Contract Test Suite: Event Telemetry Specification (Plan P-104)
# Verifies that lifecycle hook observer dispatches produce envelopes and payloads
# that strictly conform to docs/reference/09-event-telemetry.md.
# ==============================================================================
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

report() {
  local name="$1" expect="$2" got="$3" details="${4:-}"
  if [ "$expect" = "$got" ]; then
    printf "  \033[32m✔\033[0m %-65s %s\n" "$name" "PASS"; PASS=$((PASS+1))
  else
    printf "  \033[31m✘\033[0m %-65s want %s got %s\n" "$name" "$expect" "$got"; FAIL=$((FAIL+1))
    if [ -n "$details" ]; then echo "$details" | sed 's/^/       /'; fi
  fi
}

echo "============================================================"
echo "🧪 Running Contract Test Suite: Event Telemetry (P-104)"
echo "============================================================"

# Initialize test sandbox project
PROJ="$R/telemetry_proj"
init_sandbox_project "$PROJ"
cd "$PROJ" || exit 1
git add -A && git commit -qm "init project" --no-verify

# Create observer sink script to record all dispatched envelopes to $R/events.jsonl
mkdir -p .agents/hooks .agents/skills/aapp-hooks
cp "$KIT/examples/hooks/event-logger.sample" .agents/hooks/event-logger
chmod +x .agents/hooks/event-logger

export AAPP_LOG_FILE="$R/events.jsonl"
rm -f "$AAPP_LOG_FILE"

# Register event-logger across all 14 lifecycle events in registry.tsv
EVENTS=(
  post-draft post-freeze post-start post-refine post-done post-abort post-active post-tdd
  post-commit post-land post-issue post-pause post-resume post-sync
)
for ev in "${EVENTS[@]}"; do
  line="$(aapp hook-hash .agents/hooks/event-logger "$ev" 10 notify 2>/dev/null | grep "^$ev")"
  echo "$line" >> .agents/skills/aapp-hooks/registry.tsv
done
(cd .agents && git add -A && git commit -qm "chore: register test hooks" --no-verify)

# 1. Test post-draft
aapp draft telemetry-feature >/dev/null 2>&1
got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"event": "post-draft"' && \
   echo "$last_event" | grep -qF '"command": "plan"' && \
   echo "$last_event" | grep -qF '"event": "draft"'; then
  got=PASS
fi
report "telemetry_post_draft_envelope_and_payload" "PASS" "$got" "$last_event"

pf="$(ls .plans/current/P*-telemetry-feature.md 2>/dev/null | head -n 1)"
pid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" 2>/dev/null || echo "P-1")"

# 2. Test post-active (set, clear)
aapp active "$pid" >/dev/null 2>&1
got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"event": "post-active"' && \
   echo "$last_event" | grep -qF '"command": "plan"' && \
   echo "$last_event" | grep -qF '"action": "set"'; then
  got=PASS
fi
report "telemetry_post_active_set_envelope" "PASS" "$got" "$last_event"

aapp active clear >/dev/null 2>&1
got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"action": "clear"'; then
  got=PASS
fi
report "telemetry_post_active_clear_envelope" "PASS" "$got" "$last_event"

# 3. Test post-tdd on a separate draft plan
aapp draft tdd-feature >/dev/null 2>&1
tpf="$(ls .plans/current/P*-tdd-feature.md 2>/dev/null | head -n 1)"
tpid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$tpf" 2>/dev/null || echo "P-2")"
aapp tdd "$tpid" >/dev/null 2>&1
got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"event": "post-tdd"' && \
   echo "$last_event" | grep -qF '"command": "plan"' && \
   echo "$last_event" | grep -qF '"event": "tdd"'; then
  got=PASS
fi
report "telemetry_post_tdd_envelope_and_payload" "PASS" "$got" "$last_event"
aapp plan abort "$tpid" reason "tdd check complete" confirm >/dev/null 2>&1

# 4. Test post-refine, post-freeze and post-start
sed -i 's/\* \[ \]/\* \[x\]/g' "$pf"
sed -i '/^### 📂 Target Files/,/^### 🛑/ {
  /^### 📂 Target Files/b
  /^### 🛑/b
  d
}' "$pf"
sed -i '/^### 📂 Target Files/a - `main.py` -> Target file.' "$pf"

aapp refine "$pid" "resolve questions and targets" >/dev/null 2>&1
got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"event": "post-refine"' && \
   echo "$last_event" | grep -qF '"command": "plan"' && \
   echo "$last_event" | grep -qF '"event": "refine"'; then
  got=PASS
fi
report "telemetry_post_refine_envelope_and_payload" "PASS" "$got" "$last_event"

aapp freeze "$pid" >/dev/null 2>&1
got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"event": "post-freeze"' && \
   echo "$last_event" | grep -qF '"command": "plan"' && \
   echo "$last_event" | grep -qF '"event": "freeze"'; then
  got=PASS
fi
report "telemetry_post_freeze_envelope_and_payload" "PASS" "$got" "$last_event"

aapp start "$pid" >/dev/null 2>&1
got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"event": "post-start"' && \
   echo "$last_event" | grep -qF '"command": "plan"' && \
   echo "$last_event" | grep -qF '"event": "start"'; then
  got=PASS
fi
report "telemetry_post_start_envelope_and_payload" "PASS" "$got" "$last_event"

# 5. Test post-commit
wt_rec="$(parse_plan_worktree "$pf" 2>/dev/null || true)"
wt_dir=""
if [ -n "$wt_rec" ]; then
  wt_dir="$(aapp_abs_path "${wt_rec%%$'\t'*}" "$PROJ")"
fi

if [ -n "$wt_dir" ] && [ -d "$wt_dir" ]; then
  cd "$wt_dir" || exit 1
  echo "# app update" >> main.py
  git add main.py
  aapp commit "feat: update main" agent Antigravity vendor Google model gemini-3.8-flash >/dev/null 2>&1
  cd "$PROJ" || exit 1
else
  echo "# app update" >> main.py
  git add main.py
  aapp commit "feat: update main" agent Antigravity vendor Google model gemini-3.8-flash >/dev/null 2>&1
fi

got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"event": "post-commit"' && \
   echo "$last_event" | grep -qF '"command": "commit"' && \
   echo "$last_event" | grep -qF '"agent": "Antigravity"'; then
  got=PASS
fi
report "telemetry_post_commit_envelope_and_payload" "PASS" "$got" "$last_event"

# 6. Test post-done
aapp done "$pid" >/dev/null 2>&1
got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"event": "post-done"' && \
   echo "$last_event" | grep -qF '"command": "plan"' && \
   echo "$last_event" | grep -qF '"event": "done"'; then
  got=PASS
fi
report "telemetry_post_done_envelope_and_payload" "PASS" "$got" "$last_event"

# 7. Test post-abort
aapp draft abort-feature >/dev/null 2>&1
apf="$(ls .plans/current/P*-abort-feature.md 2>/dev/null | head -n 1)"
apid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$apf" 2>/dev/null || echo "P-3")"
aapp plan abort "$apid" reason "Test abort" confirm >/dev/null 2>&1
got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"event": "post-abort"' && \
   echo "$last_event" | grep -qF '"command": "plan"' && \
   echo "$last_event" | grep -qF '"event": "abort"'; then
  got=PASS
fi
report "telemetry_post_abort_envelope_and_payload" "PASS" "$got" "$last_event"

# 8. Test post-issue lifecycle (log, queue, unqueue, fix, close, withdraw)
mkdir -p src && touch src/issue1.txt
git add src/issue1.txt && git commit -qm "feat: add issue1 file" --no-verify

aapp issue log Medium CLI "Telemetry issue symptom" file src/issue1.txt >/dev/null 2>&1
got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"event": "post-issue"' && \
   echo "$last_event" | grep -qF '"command": "issue"' && \
   echo "$last_event" | grep -qF '"event": "log"'; then
  got=PASS
fi
report "telemetry_post_issue_log" "PASS" "$got" "$last_event"

aapp issue queue 1 urgent >/dev/null 2>&1
got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"command": "issue"' && \
   echo "$last_event" | grep -qF '"event": "queue"' && \
   echo "$last_event" | grep -qF '"level": "urgent"'; then
  got=PASS
fi
report "telemetry_post_issue_queue" "PASS" "$got" "$last_event"

aapp issue queue 1 remove >/dev/null 2>&1
got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"command": "issue"' && \
   echo "$last_event" | grep -qF '"event": "unqueue"'; then
  got=PASS
fi
report "telemetry_post_issue_unqueue" "PASS" "$got" "$last_event"

aapp issue queue 1 >/dev/null 2>&1
aapp issue fix 1 >/dev/null 2>&1
got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"command": "issue"' && \
   echo "$last_event" | grep -qF '"event": "fix"'; then
  got=PASS
fi
report "telemetry_post_issue_fix" "PASS" "$got" "$last_event"

# Commit and close fix
cd .workspace/fix-1 || exit 1
echo "# fix 1" >> src/issue1.txt
git add src/issue1.txt
aapp commit "fix: fix issue 1" changelog "fixed telemetry issue" >/dev/null 2>&1
cd "$PROJ" || exit 1

aapp issue close 1 >/dev/null 2>&1
got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"command": "issue"' && \
   echo "$last_event" | grep -qF '"event": "close"'; then
  got=PASS
fi
report "telemetry_post_issue_close" "PASS" "$got" "$last_event"

aapp issue log Low CLI "Withdrawn issue symptom" >/dev/null 2>&1
aapp issue abort 2 reason "Not needed" confirm >/dev/null 2>&1
got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"command": "issue"' && \
   echo "$last_event" | grep -qF '"event": "withdraw"'; then
  got=PASS
fi
report "telemetry_post_issue_withdraw" "PASS" "$got" "$last_event"

# 9. Test post-pause and post-resume
aapp pause "switching tasks" >/dev/null 2>&1
got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"event": "post-pause"' && \
   echo "$last_event" | grep -qF '"command": "pause"' && \
   echo "$last_event" | grep -qF '"event": "pause"'; then
  got=PASS
fi
report "telemetry_post_pause_envelope" "PASS" "$got" "$last_event"

aapp resume >/dev/null 2>&1
got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"event": "post-resume"' && \
   echo "$last_event" | grep -qF '"command": "pause"' && \
   echo "$last_event" | grep -qF '"event": "resume"'; then
  got=PASS
fi
report "telemetry_post_resume_envelope" "PASS" "$got" "$last_event"

# 10. Test post-sync with a local bare remote
git init -q --bare "$R/remote.git"
git remote add origin "$R/remote.git"
for wt in .plans .agents .githooks; do
  git -C "$wt" remote add origin "$R/remote.git" 2>/dev/null || true
  git -C "$wt" push -q -u origin HEAD >/dev/null 2>&1 || true
done
git push -q -u origin HEAD >/dev/null 2>&1 || true

aapp sync origin >/dev/null 2>&1 || true
got=FAIL
last_event="$(tail -n 1 "$AAPP_LOG_FILE" 2>/dev/null)"
if echo "$last_event" | grep -qF '"event": "post-sync"' && \
   echo "$last_event" | grep -qF '"command": "sync"' && \
   echo "$last_event" | grep -qF '"event": "sync"'; then
  got=PASS
fi
report "telemetry_post_sync_envelope" "PASS" "$got" "$last_event"

echo "============================================================"
echo "📊 Results: $PASS passed, $FAIL failed"
echo "============================================================"
[ "$FAIL" -eq 0 ] || exit 1
