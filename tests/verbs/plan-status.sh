#!/usr/bin/env bash
# Tests: `aapp plan-status` behaviour contract (lib/docs/verbs/plan-status.md)
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
plan_file() { ls .plans/current/P"${1#P-}"-*.md; }

incubating="$(draft_plan incubating)"
frozen="$(draft_plan frozen-one)"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$(plan_file "$frozen")"
git -C .plans commit -qam "resolve" >/dev/null
aapp freeze "$frozen" >/dev/null 2>&1

out="$(aapp plan-status 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '🔷 Frozen Backlog : 1' && \
   printf '%s' "$out" | grep -q '🟣 Incubator      : 1' && printf '%s' "$out" | grep -q '⚡ In Development : 0'; then
  ok "test_overview_buckets_by_status"
else
  bad "test_overview_buckets_by_status" "rc=$rc"
fi

out="$(aapp plan-status "$incubating" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '• src/path/to/file.ext' && \
   printf '%s' "$out" | grep -q '• src/path/to/new_file.ext' && ! printf '%s' "$out" | grep -q 'backticked path'; then
  ok "test_single_plan_lists_targets"
else
  bad "test_single_plan_lists_targets" "rc=$rc"
fi

aapp plan-status P-999 >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ]; then ok "test_refuses_unknown_plan"; else bad "test_refuses_unknown_plan" "rc=$rc"; fi

print_test_summary "$PASS" "$FAIL"
