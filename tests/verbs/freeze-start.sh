#!/usr/bin/env bash
# Tests: `aapp freeze-start` behaviour contract (lib/docs/verbs/freeze-start.md)
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
status_of() { grep -m1 '^\* \*\*Status:\*\*' "$1"; }
buffer_file() { git rev-parse --git-path aapp_active_plan; }

echo "== refusals =="
id="$(draft_plan open-questions)"; f="$(plan_file "$id")"
before="$(cksum < "$f")"
aapp freeze-start "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ] && [ "$(cksum < "$f")" = "$before" ] && [ ! -f "$(buffer_file)" ]; then
  ok "test_refuses_unresolved_questions"
else
  bad "test_refuses_unresolved_questions" "rc=$rc"
fi

echo "== happy path =="
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$f"; git -C .plans commit -qam "resolve questions" >/dev/null
aapp freeze-start "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && status_of "$f" | grep -q '⚡ In Development' && [ "$(cat "$(buffer_file)")" = "$id" ] && \
   grep -q "Plan frozen and activated into ⚡ In Development via freeze-start." "$f" && \
   git -C .plans log -1 --format=%s | grep -qF "plan(start): freeze and activate $id into development" && \
   [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_freezes_and_activates"
else
  bad "test_freezes_and_activates" "rc=$rc"
fi

print_test_summary "$PASS" "$FAIL"
