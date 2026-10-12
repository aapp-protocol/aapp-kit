#!/usr/bin/env bash
# Tests: `aapp issue` behaviour contract (lib/docs/verbs/issue.md)
# Part: issue.keyid.sh (an issue whose id is a tracker's key, P-79).
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1
git config aapp.issueFixWait 0
git config aapp.planWorktrees off
mkdir -p src; echo "k=1" > src/k.sh; echo "o=1" > src/other.sh; echo "p=1" > src/promo.py
git add src; git commit -qm "sources" --no-verify >/dev/null 2>&1
git checkout -q -b develop 2>/dev/null || git checkout -q develop

cat > .plans/ISSUES.md <<'EOF'
# Issues

| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #PROJ-101 | `Low` | `CLI` | 2026-09-01 | `src/k.sh` | The k helper loses its value. |  | 🟡 `Incubated` |
| #PROJ-102 | `Medium` | `CORE` | 2026-09-02 | `src/other.sh` | Second defect. |  | 🟡 `Incubated` |
| #PROJ-103 | `Low` | `CORE` | 2026-09-03 | `src/promo.py` | Third defect. |  | 🟡 `Incubated` |
EOF
cat > .plans/issues_road_map.md <<'EOF'
# Board

## Triage
- [ ] #PROJ-101 -> The k helper loses its value.
- [ ] #PROJ-102 -> Second defect.
- [ ] #PROJ-103 -> Third defect.
EOF
git -C .plans add -A >/dev/null 2>&1; git -C .plans commit -qm "test: ledger fixture" >/dev/null 2>&1
plan_file() { ls .plans/current/P"${1#P-}"-*.md; }

echo "== fix, commit, close =="
out="$(aapp issue fix proj-101 2>&1)"; rc=$?
mp=".plans/current/fix-PROJ-101.md"
opened=0; [ "$rc" -eq 0 ] && [ -f "$mp" ] && grep -qxF '* **Plan ID:** #PROJ-101' "$mp" && opened=1
echo "k=2" > src/k.sh; git add src/k.sh
cout="$(aapp commit "fix: k keeps its value (#PROJ-101)" changelog "the k helper keeps its value" 2>&1)"; crc=$?
guard_other="$(bash .githooks/blast-radius-guard src/other.sh 2>&1)"; g1=$?
guard_k="$(bash .githooks/blast-radius-guard src/k.sh 2>&1)"; g2=$?
clout="$(aapp issue close PROJ-101 2>&1)"; clrc=$?
if [ "$opened" -eq 1 ] && [ "$crc" -eq 0 ] && git log -1 --format=%s | grep -qF '(#PROJ-101)' && [ "$clrc" -eq 0 ] && \
   grep -qE '^\| #PROJ-101 \|' .plans/done/000-issues-archive.md && ! grep -q '#PROJ-101' .plans/ISSUES.md && \
   ! grep -q '#PROJ-101 ' .plans/issues_road_map.md && [ ! -f "$mp" ]; then
  ok "test_fix_and_close_with_key_id"
else
  bad "test_fix_and_close_with_key_id" "fix rc=$rc opened=$opened commit rc=$crc close rc=$clrc out=$out | $cout | $clout"
fi
if [ "$g2" -eq 0 ] && [ "$g1" -ne 0 ]; then
  ok "test_write_guard_binds_key_id_fix"
else
  bad "test_write_guard_binds_key_id_fix" "k rc=$g2 other rc=$g1 ($guard_other)"
fi

echo "== blocking a plan =="
pid="P-$(git config --get aapp.planId)"; aapp draft blocked-one >/dev/null 2>&1
pf="$(plan_file "$pid")"
out="$(aapp refine "$pid" blocked PROJ-102 2>&1)"; rc=$?
blocked=0; grep -qF '* **Blocked On:** #PROJ-102' "$pf" && grep -q 'BLOCKED' "$pf" && blocked=1
out2="$(aapp issue close PROJ-102 summary "Fixed elsewhere." 2>&1)"; rc2=$?
if [ "$rc" -eq 0 ] && [ "$blocked" -eq 1 ] && [ "$rc2" -eq 0 ] && ! grep -q '^\* \*\*Blocked On:\*\*' "$pf" && ! grep -q 'BLOCKED' <(grep '^\* \*\*Status:' "$pf"); then
  ok "test_key_id_blocks_and_unblocks_plan"
else
  bad "test_key_id_blocks_and_unblocks_plan" "rc=$rc blocked=$blocked rc2=$rc2 out=$out | $out2 header=$(grep -E 'Status:|Blocked' "$pf" | tr '\n' ' ')"
fi

echo "== promoting to a plan =="
dpid="$(git config --get aapp.planId)"
out="$(aapp draft promo issue PROJ-103 2>&1)"; rc=$?
dpf="$(plan_file "P-$dpid")"
promoted=0
grep -qxF '* **Target Issue / Milestone:** #PROJ-103' "$dpf" && grep -E '^\| #PROJ-103 \|' .plans/ISSUES.md | grep -q 'Planned' && promoted=1
SHA="$(git rev-parse --short HEAD)"
sed -i -E "s|src/path/to/file\.ext|src/promo.py|g; /src\/path\/to\/new_file\.ext/d" "$dpf"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$dpf"
sed -i -E "s/^\* \*\*Commits:\*\*.*/\* \*\*Commits:\*\* \`$SHA\` ($(git rev-parse --abbrev-ref HEAD))/" "$dpf"
git -C .plans commit -qam "prepare P-$dpid" >/dev/null 2>&1
aapp active clear >/dev/null 2>&1
aapp freeze-start "P-$dpid" >/dev/null 2>&1
dout="$(aapp done "P-$dpid" 2>&1)"; drc=$?
if [ "$rc" -eq 0 ] && [ "$promoted" -eq 1 ] && [ "$drc" -eq 0 ] && grep -qE '^\| #PROJ-103 \|' .plans/done/000-issues-archive.md && \
   ! grep -q '#PROJ-103' .plans/ISSUES.md; then
  ok "test_draft_promotes_key_id"
else
  bad "test_draft_promotes_key_id" "draft rc=$rc promoted=$promoted done rc=$drc out=$out | $(echo "$dout" | tail -3)"
fi

print_test_summary "$PASS" "$FAIL"
