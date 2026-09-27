#!/usr/bin/env bash
# Tests: `aapp status` behaviour contract (lib/docs/verbs/status.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-48s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-48s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1

out="$(aapp status short 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | wc -l)" -eq 1 ] && printf '%s' "$out" | grep -q '^📊 Overview:'; then
  ok "test_short_is_one_line"
else
  bad "test_short_is_one_line" "rc=$rc lines=$(printf '%s\n' "$out" | wc -l)"
fi

out="$(aapp status 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | grep -c 'Next Action:')" -eq 1 ]; then
  ok "test_briefing_has_next_action"
else
  bad "test_briefing_has_next_action" "rc=$rc"
fi

print_test_summary "$PASS" "$FAIL"
