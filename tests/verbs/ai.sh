#!/usr/bin/env bash
# Tests: `aapp ai` behaviour contract (lib/docs/verbs/ai.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1

# 1. test_ai_status_default
out="$(aapp ai 2>&1)"; rc=$?
out_status="$(aapp ai status 2>&1)"; rc_s=$?
if [ "$rc" -eq 0 ] && [ "$rc_s" -eq 0 ] && echo "$out" | grep -q "AI Attribution Policy"; then
  ok "test_ai_status_default"
else
  bad "test_ai_status_default" "rc=$rc rc_s=$rc_s out=$out"
fi

# 2. test_ai_mode_transitions
modes_pass=1
for m in lax strict notes none; do
  aapp ai "$m" >/dev/null 2>&1 || modes_pass=0
  curr="$(git config aapp.aiAttribution)"
  [ "$curr" != "$m" ] && modes_pass=0
done
if [ "$modes_pass" -eq 1 ]; then
  ok "test_ai_mode_transitions"
else
  bad "test_ai_mode_transitions" "failed setting one of the modes"
fi

# 3. test_ai_refuses_invalid_subcommand
out="$(aapp ai bogus-command 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -qiE 'Unknown AI mode or command'; then
  ok "test_ai_refuses_invalid_subcommand"
else
  bad "test_ai_refuses_invalid_subcommand" "rc=$rc out=$out"
fi

# 4. test_ai_refuses_legacy_off_alias
out="$(aapp ai off 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -qiE 'Unknown AI mode or command'; then
  ok "test_ai_refuses_legacy_off_alias"
else
  bad "test_ai_refuses_legacy_off_alias" "rc=$rc out=$out"
fi

# 5. test_ai_credits_runs_cleanly
out="$(aapp ai credits 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  ok "test_ai_credits_runs_cleanly"
else
  bad "test_ai_credits_runs_cleanly" "rc=$rc out=$out"
fi

# 6. test_ai_notes_preserves_notes_config
git config --replace-all notes.rewriteRef "refs/notes/commits"
git config --add notes.rewriteRef "refs/notes/ai"
git config notes.ai.mergeStrategy "union"
aapp ai notes >/dev/null 2>&1
rewrites="$(git config --get-all notes.rewriteRef)"
strat="$(git config notes.ai.mergeStrategy)"
if echo "$rewrites" | grep -qx "refs/notes/commits" && \
   echo "$rewrites" | grep -qx "refs/notes/ai" && \
   [ "$strat" = "union" ]; then
  ok "test_ai_notes_preserves_notes_config"
else
  bad "test_ai_notes_preserves_notes_config" "rewrites=[$rewrites] strat=[$strat]"
fi

# 7. test_ai_notes_toggle
aapp ai notes on >/dev/null 2>&1
on_val="$(git config aapp.aiNotes)"
aapp ai notes off >/dev/null 2>&1
off_val="$(git config aapp.aiNotes)"
if [ "$on_val" = "true" ] && [ "$off_val" = "false" ]; then
  ok "test_ai_notes_toggle"
else
  bad "test_ai_notes_toggle" "on=[$on_val] off=[$off_val]"
fi

# 8. test_ai_status_reports_dual_policy
out="$(aapp ai status 2>&1)"
if echo "$out" | grep -q "Commit Trailers" && echo "$out" | grep -q "AI Git Notes"; then
  ok "test_ai_status_reports_dual_policy"
else
  bad "test_ai_status_reports_dual_policy" "out=$out"
fi

print_test_summary "$PASS" "$FAIL"
