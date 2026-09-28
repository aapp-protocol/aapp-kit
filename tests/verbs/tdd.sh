#!/usr/bin/env bash
# Tests: `aapp tdd` behaviour contract (lib/docs/verbs/tdd.md)
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

echo "== refusals =="
# 1. Refuses unknown plan
aapp tdd P-999 >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ]; then ok "test_refuses_unknown_plan"; else bad "test_refuses_unknown_plan" "rc=$rc"; fi

# 2. Refuses outside a git repo
( cd "$R" && "$KIT/aapp" tdd P-1 >/dev/null 2>&1 ); rc=$?
if [ "$rc" -ne 0 ]; then ok "test_refuses_outside_repo"; else bad "test_refuses_outside_repo" "rc=$rc"; fi

# 3. Happy path injection
id="$(draft_plan tdd-plan)"; f="$(plan_file "$id")"
aapp tdd "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && \
   grep -q "### 🧪 Required Tests" "$f" && \
   grep -q "### 🧪 Required Test Files" "$f" && \
   git -C .plans log -1 --format=%s | grep -qF "plan(refine): declare failure tests for $id"; then
  ok "test_injects_tdd_sections"
else
  bad "test_injects_tdd_sections" "rc=$rc"
fi

# 4. Refuses when already injected (idempotence)
before="$(cksum < "$f")"
aapp tdd "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ] && [ "$(cksum < "$f")" = "$before" ]; then
  ok "test_refuses_already_injected"
else
  bad "test_refuses_already_injected" "rc=$rc"
fi

# 5. Injection commit accepted while refining
if [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_injection_commit_accepted_while_refining"
else
  bad "test_injection_commit_accepted_while_refining" "uncommitted changes in .plans"
fi

echo "== freeze timing & gates =="
# 6. Freeze refuses when sections are empty
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$f"
aapp freeze "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -ne 0 ]; then
  ok "test_freeze_refuses_empty_tdd_sections"
else
  bad "test_freeze_refuses_empty_tdd_sections" "rc=$rc"
fi

# 7. Freeze refuses correspondence mismatch
# Populate mismatch: §3 has test_fail in test_x.sh, §4 has test_y.sh
cp "$f" "$f.bak"
awk '
/### 🧪 Required Tests/ { print; print "- [ ] `tests/test_x.sh::test_fail` -> asserts error"; next }
/### 🧪 Required Test Files/ { print; print "- `tests/test_y.sh`"; next }
{ print }
' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
aapp freeze "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -ne 0 ]; then
  ok "test_freeze_refuses_mismatch"
else
  bad "test_freeze_refuses_mismatch" "rc=$rc"
fi

# 8. Freeze succeeds when matched (tolerating unwritten files on disk)
cp "$f.bak" "$f"
awk '
/### 🧪 Required Tests/ { print; print "- [ ] `tests/test_x.sh::test_fail` -> asserts error"; next }
/### 🧪 Required Test Files/ { print; print "- `tests/test_x.sh`"; next }
{ print }
' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
aapp freeze "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && grep -q '🔷 Frozen' "$f"; then
  ok "test_freeze_tolerates_unwritten_matching_tests"
else
  bad "test_freeze_tolerates_unwritten_matching_tests" "rc=$rc"
fi

echo "== done gate completion =="
# Start the plan
aapp start "$id" >/dev/null 2>&1

# 9. Done refuses when unticked
aapp done "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -ne 0 ] && [ -f "$f" ]; then
  ok "test_done_refuses_unticked_tests"
else
  bad "test_done_refuses_unticked_tests" "rc=$rc"
fi

# Tick the box, but test file missing on disk
sed -i -E 's/- \[ \] `tests\/test_x.sh/- [x] `tests\/test_x.sh/' "$f"

# 10. Done refuses when test file missing from disk
aapp done "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -ne 0 ] && [ -f "$f" ]; then
  ok "test_done_refuses_missing_test_file_on_disk"
else
  bad "test_done_refuses_missing_test_file_on_disk" "rc=$rc"
fi

# Create test file on disk, but untracked in Git
mkdir -p tests; touch tests/test_x.sh

# 11. Done refuses when test file untracked in Git
aapp done "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -ne 0 ] && [ -f "$f" ]; then
  ok "test_done_refuses_untracked_test_file"
else
  bad "test_done_refuses_untracked_test_file" "rc=$rc"
fi

# Track test file in Git
git add tests/test_x.sh
git commit -qm "feat: add test_x.sh" --no-verify
aapp commit adopt "$(git rev-parse HEAD)" >/dev/null 2>&1

# 12. Done succeeds when all ticked and tracked, records tdd (N/N) in ledger
aapp done "$id" >/dev/null 2>&1; rc=$?
ledger_row="$(grep -F "\`$id\`" .plans/done/000-archive-ledger.md 2>/dev/null || true)"
if [ "$rc" -eq 0 ] && [ -f ".plans/done/$(basename "$f")" ] && \
   echo "$ledger_row" | grep -qF "tdd (1/1)"; then
  ok "test_done_succeeds_and_records_ledger_badge"
else
  bad "test_done_succeeds_and_records_ledger_badge" "rc=$rc, ledger=$ledger_row"
fi

print_test_summary "$PASS" "$FAIL"
