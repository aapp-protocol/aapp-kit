#!/usr/bin/env bash
# Tests: `aapp plan` behaviour contract (lib/docs/verbs/plan.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-48s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-48s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1

out="$(aapp plan 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'aapp plan-status' && printf '%s' "$out" | grep -q 'aapp active'; then
  ok "test_prints_switchboard"
else
  bad "test_prints_switchboard" "rc=$rc"
fi

# Snapshot every tracked and untracked file state in the project and plans worktree.
snapshot() { { git status --porcelain --ignored; git -C .plans status --porcelain; git -C .plans rev-parse HEAD; } 2>/dev/null; }
before="$(snapshot)"
aapp plan P-1 >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && [ "$(snapshot)" = "$before" ]; then
  ok "test_changes_nothing"
else
  bad "test_changes_nothing" "rc=$rc"
fi

print_test_summary "$PASS" "$FAIL"
