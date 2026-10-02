#!/usr/bin/env bash
# Tests: `aapp refine` behaviour contract (lib/docs/verbs/refine.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1

id="P-$(git config aapp.planId)"
aapp draft refine-me >/dev/null 2>&1
f="$(ls .plans/current/P"${id#P-}"-*.md)"
rel="current/$(basename "$f")"

echo "== happy path =="
echo "* **2026-10-03:** Clarified the goal." >> "$f"
echo "- [ ] unrelated note" >> .plans/pickup.md
git -C .plans add pickup.md
out="$(aapp refine "$id" "clarify goal" 2>&1)"; rc=$?
sha="$(git -C .plans rev-parse --short HEAD)"
if [ "$rc" -eq 0 ] && git -C .plans log -1 --format=%s | grep -qxF "plan(refine): $id clarify goal" && \
   [ "$(git -C .plans show --name-only --format= HEAD)" = "$rel" ] && \
   echo "$out" | grep -qF "📝 [Refine] $id committed ($sha): clarify goal"; then
  ok "test_refine_commits_only_the_plan"
else
  bad "test_refine_commits_only_the_plan" "rc=$rc out=$out files=$(git -C .plans show --name-only --format= HEAD)"
fi
if git -C .plans diff --cached --name-only | grep -qx "pickup.md"; then
  ok "test_refine_leaves_other_staged_paths"
else
  bad "test_refine_leaves_other_staged_paths" "staged=$(git -C .plans diff --cached --name-only)"
fi
git -C .plans reset -q pickup.md && git -C .plans checkout -q -- pickup.md

echo "== refusals =="
head_before="$(git -C .plans rev-parse HEAD)"
aapp refine >/dev/null 2>&1; rc1=$?
aapp refine "$id" >/dev/null 2>&1; rc2=$?
aapp refine P-999 "x" >/dev/null 2>&1; rc3=$?
out="$(aapp refine "$id" "again" 2>&1)"; rc4=$?
if [ "$rc1" -ne 0 ] && [ "$rc2" -ne 0 ] && [ "$rc3" -ne 0 ] && [ "$rc4" -ne 0 ] && \
   echo "$out" | grep -qi "nothing to commit" && [ "$(git -C .plans rev-parse HEAD)" = "$head_before" ]; then
  ok "test_refine_refuses_bad_input_and_no_change"
else
  bad "test_refine_refuses_bad_input_and_no_change" "rc=$rc1/$rc2/$rc3/$rc4 out=$out"
fi

print_test_summary "$PASS" "$FAIL"
