#!/usr/bin/env bash
# Tests: `aapp freeze` behaviour contract (lib/docs/verbs/freeze.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-48s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-48s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

# A project holding one drafted plan; prints the plan's ID. The template ships
# one unchecked §5 question and example Target Files.
init_sandbox_project "$R/p"
cd "$R/p" || exit 1
draft_plan() {
  local id; id="$(git config --get aapp.planId)"
  aapp draft "$1" >/dev/null 2>&1 || return 1
  echo "P-$id"
}
plan_file() { ls .plans/current/P"${1#P-}"-*.md; }
resolve_questions() { sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$1"; git -C .plans commit -qam "resolve questions" >/dev/null; }
status_of() { grep -m1 '^\* \*\*Status:\*\*' "$1"; }

echo "== refusals =="
id="$(draft_plan open-questions)"; f="$(plan_file "$id")"
before="$(cksum < "$f")"
aapp freeze "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ] && [ "$(cksum < "$f")" = "$before" ]; then ok "test_refuses_unresolved_questions"; else bad "test_refuses_unresolved_questions" "rc=$rc"; fi

id="$(draft_plan no-targets)"; f="$(plan_file "$id")"
resolve_questions "$f"
sed -i -E '/^### 📂 Target Files/,/^### 🛑 Out of Bounds/{/^- \[ \] `/d}' "$f"; git -C .plans commit -qam "drop targets" >/dev/null
before="$(cksum < "$f")"
aapp freeze "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ] && [ "$(cksum < "$f")" = "$before" ]; then ok "test_refuses_without_target_files"; else bad "test_refuses_without_target_files" "rc=$rc"; fi

aapp freeze P-999 >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ]; then ok "test_refuses_unknown_plan"; else bad "test_refuses_unknown_plan" "rc=$rc"; fi

echo "== happy path =="
id="$(draft_plan ready-plan)"; f="$(plan_file "$id")"
resolve_questions "$f"
aapp freeze "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && status_of "$f" | grep -q '🔷 Frozen' && \
   grep -q "Plan locked and frozen into 🔷 Frozen via freeze." "$f" && \
   awk '/^## /{s=$0} s ~ /Frozen/ && /ready-plan/ {found=1} END{exit !found}' .plans/state_matrix.md && \
   git -C .plans log -1 --format=%s | grep -qF "plan(freeze): lock blast radius and greenlight $id" && \
   [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_freezes_and_commits"
else
  bad "test_freezes_and_commits" "rc=$rc status=[$(status_of "$f")]"
fi

echo "== source status (#89) =="
# ready-plan is now Frozen: freezing it again must refuse and change nothing.
before="$(cksum < "$f")"
aapp freeze "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ] && [ "$(cksum < "$f")" = "$before" ]; then
  ok "test_refuses_non_incubator_plan"
else
  bad "test_refuses_non_incubator_plan" "rc=$rc"
fi

print_test_summary "$PASS" "$FAIL"
