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
if echo "$out" | grep -qF "$sid: $(basename "$sf")  (⚡ In Development → .workspace/P${sid#P-})"; then
  ok "test_plan_worktree_shown_next_to_plan"
else
  bad "test_plan_worktree_shown_next_to_plan" "$(echo "$out" | grep -F "$sid")"
fi

# P-64: members are listed under their group.
gid="P-$(git config aapp.planId)"; aapp draft grouped group >/dev/null 2>&1
mid="P-$(git config aapp.planId)"; aapp draft in-group group "$gid" >/dev/null 2>&1
out="$(aapp status 2>&1)"
gline="$(printf '%s\n' "$out" | grep -n "$gid: " | head -1 | cut -d: -f1)"
mline="$(printf '%s\n' "$out" | grep -n "$mid: " | head -1 | cut -d: -f1)"
if [ -n "$gline" ] && [ -n "$mline" ] && [ "$mline" -eq $((gline + 1)) ] && \
   printf '%s\n' "$out" | sed -n "${mline}p" | grep -qE "^ {4,}.*$mid: "; then
  ok "test_members_listed_under_group"
else
  bad "test_members_listed_under_group" "$(printf '%s\n' "$out" | grep -E "$gid|$mid")"
fi

# P-63: open adoption tasks show in overview and briefing; none when none open.
cat <<'EOF' > .plans/adoption.md
# 📋 Adoption Checklist
- [ ] `[TEST-TASK]` Test open task → MANUAL: Overview
- [x] `[DONE-TASK]` Done task → MANUAL: Overview
EOF
out="$(aapp status 2>&1)"
if echo "$out" | grep -qE '^[[:space:]]*📊 Overview:.*\| 1 adoption' && \
   echo "$out" | grep -qF '📋 Adoption: 1 open task(s) in .plans/adoption.md'; then
  ok "test_overview_counts_open_adoption_tasks"
else
  bad "test_overview_counts_open_adoption_tasks" "$(echo "$out" | grep -E 'Overview|Adoption')"
fi

# With no open tasks, neither is printed
sed -i -E 's/^- \[ \]/- [x]/' .plans/adoption.md
out="$(aapp status 2>&1)"
if ! echo "$out" | grep -q 'adoption' && ! echo "$out" | grep -q '📋 Adoption:'; then
  ok "test_no_adoption_output_when_none_open"
else
  bad "test_no_adoption_output_when_none_open" "$(echo "$out" | grep -E 'Overview|Adoption')"
fi
rm -f .plans/adoption.md

print_test_summary "$PASS" "$FAIL"
