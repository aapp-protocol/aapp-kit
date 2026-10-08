#!/usr/bin/env bash
# Tests: `aapp active` behaviour contract (lib/docs/verbs/active.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-48s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-48s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1
draft_plan() {
  local id; id="$(git config --get aapp.planId)"
  aapp draft "$1" >/dev/null 2>&1 || return 1
  echo "P-$id"
}
BUF="$(git rev-parse --git-path aapp_active_plan)"
PREV="$(git rev-parse --git-path aapp_active_plan.prev)"
a="$(draft_plan plan-a)"
b="$(draft_plan plan-b)"

aapp active "$a" >/dev/null 2>&1; rc=$?
out="$(aapp active 2>&1)"
if [ "$rc" -eq 0 ] && [ "$(cat "$BUF")" = "$a" ] && printf '%s' "$out" | grep -qF "'$a'" && \
   printf '%s' "$out" | grep -q '• src/path/to/file.ext'; then
  ok "test_bind_then_show"
else
  bad "test_bind_then_show" "rc=$rc buffer=[$(cat "$BUF" 2>/dev/null)]"
fi

aapp active "$b" >/dev/null 2>&1
aapp active swap >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat "$BUF")" = "$a" ] && [ "$(cat "$PREV")" = "$b" ]; then
  ok "test_swap_exchanges_previous"
else
  bad "test_swap_exchanges_previous" "rc=$rc"
fi

aapp active clear >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$BUF" ] && [ "$(cat "$PREV")" = "$a" ]; then
  ok "test_clear_empties_buffer"
else
  bad "test_clear_empties_buffer" "rc=$rc"
fi

aapp active "$a" >/dev/null 2>&1
aapp active P-999 >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ] && [ "$(cat "$BUF")" = "$a" ]; then
  ok "test_refuses_unknown_plan"
else
  bad "test_refuses_unknown_plan" "rc=$rc"
fi

echo "== one plan one worktree (P-39) =="
git worktree add -b feat/active-wt "$R/active_wt" >/dev/null 2>&1
# The primary holds "$a" from the tests above; release it so active_wt can bind
# it (seen from a linked worktree, the primary's buffer now resolves, P-54).
aapp active clear >/dev/null 2>&1
(
  cd "$R/active_wt" || exit 1
  aapp active "$a" >/dev/null 2>&1
)
aapp active clear >/dev/null 2>&1
out="$(aapp active "$a" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -qiE '(bound|worktree)' && [ ! -f "$BUF" ]; then
  ok "test_refuses_plan_bound_in_other_worktree"
else
  bad "test_refuses_plan_bound_in_other_worktree" "rc=$rc out=$out"
fi
af="$(ls .plans/current/P"${a#P-}"-*.md)"
sed -i -E 's/^\* \*\*Status:\*\*.*/* **Status:** ⚡ In Development/' "$af"
out="$(aapp active 2>&1)"
git -C .plans checkout -q -- "current/$(basename "$af")"
if ! echo "$out" | grep -qF "'$a' (auto-discovered"; then
  ok "test_discovery_skips_plan_held_elsewhere"
else
  bad "test_discovery_skips_plan_held_elsewhere" "out=$out"
fi

print_test_summary "$PASS" "$FAIL"
