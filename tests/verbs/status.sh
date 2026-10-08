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

# P-54: a plan's worktree is shown next to it.
git branch develop
git config aapp.planWorktrees on
sid="P-$(git config aapp.planId)"; aapp draft shown-wt >/dev/null 2>&1
sf="$(ls .plans/current/P"${sid#P-}"-*.md)"
sed -i -E "s|src/path/to/file\.ext|src/shown.py|g; /src\/path\/to\/new_file\.ext/d" "$sf"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$sf"; git -C .plans commit -qam prep >/dev/null 2>&1
aapp freeze-start "$sid" >/dev/null 2>&1
out="$(aapp status 2>&1)"
if echo "$out" | grep -qF "$sid: $(basename "$sf")  (⚡ In Development → ../p-P${sid#P-})"; then
  ok "test_plan_worktree_shown_next_to_plan"
else
  bad "test_plan_worktree_shown_next_to_plan" "$(echo "$out" | grep -F "$sid")"
fi

print_test_summary "$PASS" "$FAIL"
