#!/usr/bin/env bash
# Tests: `aapp test` behaviour contract (lib/docs/verbs/test.md)
# Runs the runner against a stand-in kit tree of stub suites, so it never
# recurses into the real suites.
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-48s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-48s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

P="$R/stub"
mkdir -p "$P/tests/verbs"
git -C "$P" init -q . && setup_test_git_identity "$P"
stub() { printf '#!/usr/bin/env bash\necho "ran %s"\necho "Results: 1 passed, 0 failed"\n' "$2" > "$1"; }
stub "$P/tests/alpha_test.sh" alpha
stub "$P/tests/matrix_test.sh" flat-matrix
stub "$P/tests/verbs/draft.sh" verb-draft
stub "$P/tests/verbs/matrix.sh" verb-matrix
cd "$P" || exit 1

out="$(aapp test list 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'alpha_test.sh' && \
   printf '%s' "$out" | grep -q 'verb/draft' && printf '%s' "$out" | grep -q 'verb/matrix'; then
  ok "test_list_shows_verb_suites"
else
  bad "test_list_shows_verb_suites" "rc=$rc"
fi

out="$(aapp test verb matrix 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'ran verb-matrix' && \
   ! printf '%s' "$out" | grep -q 'ran flat-matrix' && ! printf '%s' "$out" | grep -q 'ran verb-draft'; then
  ok "test_verb_token_selects_one_suite"
else
  bad "test_verb_token_selects_one_suite" "rc=$rc"
fi

aapp test verb nosuch >/dev/null 2>&1; rc1=$?
aapp test nosuch >/dev/null 2>&1; rc2=$?
if [ "$rc1" -eq 1 ] && [ "$rc2" -eq 1 ]; then
  ok "test_refuses_unmatched_filter"
else
  bad "test_refuses_unmatched_filter" "verb=$rc1 flat=$rc2"
fi

print_test_summary "$PASS" "$FAIL"
