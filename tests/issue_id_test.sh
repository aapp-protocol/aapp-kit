#!/usr/bin/env bash
# Unit suite for the issue id section of lib/aapp-lib.sh (P-79): the one
# definition of what an issue id is.
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
LIB="$KIT/lib/aapp-lib.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT

# shellcheck source=/dev/null
. "$LIB"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }
have() { declare -f "$1" >/dev/null; }
norm() { issue_id_normalize "$1" 2>/dev/null; }

echo "== numeric ids =="
if have issue_id_normalize && have issue_id_valid && have issue_id_is_numeric && have issue_fix_name && have issue_fix_id; then
  a="$(norm 46)"; b="$(norm '#46')"; c="$(norm '`#046`')"; d="$(norm ISSUE-79)"
  if [ "$a" = "#46" ] && [ "$b" = "#46" ] && [ "$c" = "#46" ] && [ "$d" = "#79" ] && issue_id_valid 46 && issue_id_valid '#46' && \
     issue_id_is_numeric '#46' && [ "$(issue_fix_name '#46')" = "fix-46.md" ] && [ "$(issue_fix_id fix-46.md)" = "#46" ]; then
    ok "test_normalize_numeric_forms"
  else
    bad "test_normalize_numeric_forms" "46=[$a] #46=[$b] #046=[$c] ISSUE-79=[$d]"
  fi
else
  bad "test_normalize_numeric_forms" "the id functions are not implemented"
fi

echo "== ids named in a line =="
if have issue_id_refs; then
  got="$(issue_id_refs '* **Blocked On:** #12, #PROJ-7 (was ⚡ In Development); hotfix limit reached (#3)' | tr '\n' ' ')"
  if [ "$got" = "#12 #PROJ-7 #3 " ]; then ok "test_refs_from_plan_lines"; else bad "test_refs_from_plan_lines" "got=[$got]"; fi
  a="$(issue_id_refs '### PROJ-101' | tr '\n' ' ')"; b="$(issue_id_refs 'colour #A1B2C3 here' | tr '\n' ' ')"
  c="$(issue_id_refs 'x#12 and a#PROJ-9' | tr '\n' ' ')"; d="$(issue_id_refs 'fix: thing (#PROJ-101)' | tr '\n' ' ')"
  e="$(issue_id_refs '- [ ] #45 -> text' | tr '\n' ' ')"
  if [ -z "$a" ] && [ -z "$b" ] && [ -z "$c" ] && [ "$d" = "#PROJ-101 " ] && [ "$e" = "#45 " ]; then
    ok "test_refs_ignore_headings_and_hex"
  else
    bad "test_refs_ignore_headings_and_hex" "heading=[$a] hex=[$b] glued=[$c] subject=[$d] line=[$e]"
  fi
else
  bad "test_refs_from_plan_lines" "issue_id_refs not implemented"
  bad "test_refs_ignore_headings_and_hex" "issue_id_refs not implemented"
fi

echo "== tracker keys =="
if have issue_id_normalize; then
  a="$(norm PROJ-101)"; b="$(norm '#PROJ-101')"; c="$(norm proj-101)"; d="$(norm 'A1-7')"
  if [ "$a" = "#PROJ-101" ] && [ "$b" = "#PROJ-101" ] && [ "$c" = "#PROJ-101" ] && [ "$d" = "#A1-7" ] && \
     ! issue_id_is_numeric '#PROJ-101' && [ "$(issue_fix_name '#PROJ-101')" = "fix-PROJ-101.md" ] && \
     [ "$(issue_fix_id fix-PROJ-101.md)" = "#PROJ-101" ]; then
    ok "test_key_id_valid"
  else
    bad "test_key_id_valid" "PROJ-101=[$a] #PROJ-101=[$b] proj-101=[$c] A1-7=[$d]"
  fi
  fails=""
  for t in 'PROJ-' '#-7' 'PROJ 101' '101-PROJ' '' 'PROJ-1a' '#'; do
    issue_id_valid "$t" && fails="$fails valid:[$t]"
    out="$(issue_id_normalize "$t" 2>&1)" && fails="$fails normalized:[$t]"
  done
  out="$(issue_id_normalize 'PROJ-' 2>&1)"
  if [ -z "$fails" ] && echo "$out" | grep -q '46' && echo "$out" | grep -q 'PROJ-101'; then
    ok "test_malformed_id_refused"
  else
    bad "test_malformed_id_refused" "$fails out=[$out]"
  fi
else
  bad "test_key_id_valid" "issue_id_normalize not implemented"
  bad "test_malformed_id_refused" "issue_id_normalize not implemented"
fi

echo "== the counter =="
# shellcheck source=/dev/null
. "$KIT/lib/plan_resolver.sh" 2>/dev/null
P="$R/proj/.plans"; mkdir -p "$P/done"; git init -q "$R/proj"
cat > "$P/ISSUES.md" <<'EOF'
| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #PROJ-900 | `Low` | `CLI` | 2026-10-01 | `a.sh` | Tracker issue. |  | 🟡 `Incubated` |
| #12 | `Low` | `CLI` | 2026-10-01 | `a.sh` | Local issue. |  | 🟡 `Incubated` |
EOF
cat > "$P/done/000-issues-archive.md" <<'EOF'
| # | Sev | Type | Date Opened | Date Resolved | Target Commit | Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #CORE-4000 | `Low` | `CLI` | 2026-09-01 | 2026-09-02 | `abc1234` | Fixed. |
| #7 | `Low` | `CLI` | 2026-09-01 | 2026-09-02 | `abc1234` | Fixed. |
EOF
seed="$( (cd "$R/proj" && unset REPO_ROOT PLANS_DIR && seed_issue_id "$P") 2>/dev/null)"
ids="$( (cd "$R/proj" && unset REPO_ROOT && PLANS_DIR="$P" ledger_ids active) 2>/dev/null | tr '\n' ' ')"
if [ "$seed" = "13" ] && [ "$ids" = "PROJ-900 12 " ]; then
  ok "test_counter_ignores_key_ids"
else
  bad "test_counter_ignores_key_ids" "seed=[$seed] ids=[$ids]"
fi

print_test_summary "$PASS" "$FAIL"
