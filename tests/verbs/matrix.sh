#!/usr/bin/env bash
# Tests: `aapp matrix` behaviour contract (lib/docs/verbs/matrix.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-48s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-48s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1
aapp draft matrix-subject >/dev/null 2>&1
SM=.plans/state_matrix.md

# Drift: hand-edit a plan's Status so the matrix no longer matches.
f="$(ls .plans/current/P*-matrix-subject.md)"
sed -i -E 's/^\* \*\*Status:\*\*.*/* **Status:** 🔷 Frozen/' "$f"

before="$(cksum < "$SM")"
aapp matrix check >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ] && [ "$(cksum < "$SM")" = "$before" ]; then
  ok "test_check_reports_drift_without_writing"
else
  bad "test_check_reports_drift_without_writing" "rc=$rc"
fi

out1="$(aapp matrix 2>&1)"; rc1=$?
out2="$(aapp matrix 2>&1)"; rc2=$?
if [ "$rc1" -eq 0 ] && printf '%s' "$out1" | grep -q 'Re-derived' && \
   [ "$rc2" -eq 0 ] && printf '%s' "$out2" | grep -q 'in sync' && \
   awk '/^## /{s=$0} s ~ /Frozen/ && /matrix-subject/ {found=1} END{exit !found}' "$SM"; then
  ok "test_sync_is_idempotent"
else
  bad "test_sync_is_idempotent" "rc1=$rc1 rc2=$rc2"
fi

aapp matrix --bogus >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ]; then ok "test_refuses_unknown_option"; else bad "test_refuses_unknown_option" "rc=$rc"; fi

echo "== mini plans (P-52) =="
printf '* **Plan ID:** #98\n* **Target Issue / Milestone:** #98\n* **Status:** ⚡ In Development\n' > .plans/current/fix-98.md
aapp matrix >/dev/null 2>&1
if ! grep -q "fix-98" "$SM"; then ok "test_matrix_ignores_mini_plans"; else bad "test_matrix_ignores_mini_plans" "$(grep fix-98 "$SM")"; fi
rm -f .plans/current/fix-98.md; aapp matrix >/dev/null 2>&1

print_test_summary "$PASS" "$FAIL"
