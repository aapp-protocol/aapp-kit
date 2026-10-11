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

echo "== suite parts (P-68) =="
stub tests/verbs/draft.extra.sh verb-draft-extra
out="$(aapp test verb draft 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'ran verb-draft$' && printf '%s' "$out" | grep -q 'ran verb-draft-extra' && \
   printf '%s' "$out" | grep -q 'verb/draft ' && printf '%s' "$out" | grep -q 'verb/draft.extra' && \
   ! printf '%s' "$out" | grep -q 'ran verb-matrix'; then
  ok "test_verb_runs_all_its_parts"
else
  bad "test_verb_runs_all_its_parts" "rc=$rc out=$out"
fi
out="$(aapp test list 2>&1)"
vline="$(printf '%s\n' "$out" | grep -n 'verb/draft$\|verb/draft ' | head -1 | cut -d: -f1)"
pline="$(printf '%s\n' "$out" | grep -n 'verb/draft.extra' | head -1 | cut -d: -f1)"
if [ -n "$vline" ] && [ -n "$pline" ] && [ "$pline" -eq $((vline + 1)) ] && \
   printf '%s\n' "$out" | sed -n "${pline}p" | grep -qE '^ {4,}'; then
  ok "test_parts_listed_under_their_verb"
else
  bad "test_parts_listed_under_their_verb" "$(printf '%s\n' "$out" | grep 'verb/')"
fi
rm -f tests/verbs/draft.extra.sh

printf '#!/usr/bin/env bash\necho "aborted early"\nexit 1\n' > tests/verbs/abort.sh
out="$(aapp test verb abort 2>&1)"; rc=$?
rm -f tests/verbs/abort.sh
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'FAILED (exit 1)'; then
  ok "test_aborted_suite_fails_in_default_mode"
else
  bad "test_aborted_suite_fails_in_default_mode" "rc=$rc"
fi

echo "== parallel suites (P-67) =="
# proj <name>: a stand-in kit tree; prints its path.
proj() { local d="$R/$1"; mkdir -p "$d/tests/verbs"; git -C "$d" init -q . && setup_test_git_identity "$d"; echo "$d"; }
# st <file> <body>: a stub suite running <body>, then reporting one pass.
st() { printf '#!/usr/bin/env bash\n%s\necho "Results: 1 passed, 0 failed"\n' "$2" > "$1"; }
secs() { date +%s.%N; }
elapsed() { awk -v a="$1" -v b="$2" 'BEGIN { printf "%.1f", b - a }'; }

cd "$(proj par)" || exit 1
for n in 1 2 3 4; do st "tests/s${n}_test.sh" "sleep 2"; done
t0="$(secs)"; out="$(aapp test jobs 4 2>&1)"; rc=$?; t1="$(secs)"
if [ "$rc" -eq 0 ] && awk -v e="$(elapsed "$t0" "$t1")" 'BEGIN { exit !(e < 5) }'; then
  ok "test_suites_run_concurrently"
else
  bad "test_suites_run_concurrently" "rc=$rc took=$(elapsed "$t0" "$t1")s"
fi

cd "$(proj ser)" || exit 1
for n in 1 2 3; do st "tests/s${n}_test.sh" "sleep 1"; done
t0="$(secs)"; out="$(aapp test jobs 1 2>&1)"; rc=$?; t1="$(secs)"
if [ "$rc" -eq 0 ] && awk -v e="$(elapsed "$t0" "$t1")" 'BEGIN { exit !(e >= 3) }'; then
  ok "test_jobs_one_runs_serially"
else
  bad "test_jobs_one_runs_serially" "rc=$rc took=$(elapsed "$t0" "$t1")s"
fi

cd "$(proj fail)" || exit 1
st tests/good_test.sh "sleep 1"; printf '#!/usr/bin/env bash\necho boom\nexit 1\n' > tests/bad_test.sh
out="$(aapp test jobs 2 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep 'bad_test' | grep -q 'FAILED (exit 1)' && \
   printf '%s' "$out" | grep 'good_test' | grep -q '✔'; then
  ok "test_parallel_failure_fails_the_run"
else
  bad "test_parallel_failure_fails_the_run" "rc=$rc"
fi

cd "$(proj inter)" || exit 1
st tests/a_test.sh 'echo A1; sleep 0.6; echo A2'; st tests/b_test.sh 'sleep 0.3; echo B1; sleep 0.6; echo B2'
out="$(aapp test jobs 2 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | grep -A1 -x 'A1' | tail -1)" = "A2" ] && \
   [ "$(printf '%s\n' "$out" | grep -A1 -x 'B1' | tail -1)" = "B2" ]; then
  ok "test_suite_output_not_interleaved"
else
  bad "test_suite_output_not_interleaved" "rc=$rc out=$out"
fi

cd "$(proj order)" || exit 1
st tests/a_test.sh "sleep 1.5"; st tests/b_test.sh ":"
out="$(aapp test jobs 2 2>&1)"; rc=$?
rows="$(printf '%s\n' "$out" | sed -n '/Test Summary/,$p' | grep -E '(a|b)_test')"
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$rows" | head -1 | grep -c 'a_test')" -eq 1 ] && \
   [ "$(printf '%s\n' "$rows" | sed -n 2p | grep -c 'b_test')" -eq 1 ]; then
  ok "test_summary_in_selection_order"
else
  bad "test_summary_in_selection_order" "rows=$rows"
fi

cd "$(proj trap)" || exit 1
mkdir -p "$R/traptmp"
st tests/a_test.sh "touch '$R/trap-a'; bash -c 'sleep 30' aapp-trap-marker"
st tests/b_test.sh "touch '$R/trap-b'; bash -c 'sleep 30' aapp-trap-marker"
TMPDIR="$R/traptmp" aapp test jobs 2 >/dev/null 2>&1 &
tp=$!
for _ in $(seq 1 50); do [ -f "$R/trap-a" ] && [ -f "$R/trap-b" ] && break; sleep 0.2; done
kill -TERM "$tp"; wait "$tp"; rc=$?
sleep 1
if [ "$rc" -ne 0 ] && [ -z "$(ls -A "$R/traptmp")" ] && ! pgrep -f aapp-trap-marker >/dev/null; then
  ok "test_interrupt_cleans_up"
else
  bad "test_interrupt_cleans_up" "rc=$rc left=$(ls -A "$R/traptmp" | tr '\n' ' ') procs=$(pgrep -fc aapp-trap-marker)"
fi
pkill -f aapp-trap-marker 2>/dev/null

cd "$(proj cpus)" || exit 1
st tests/a_test.sh ":"
mkdir -p "$R/fakebin"
printf '#!/usr/bin/env bash\n[ -n "$FAKE_CPUS" ] || exit 1\necho "$FAKE_CPUS"\n' > "$R/fakebin/getconf"; chmod +x "$R/fakebin/getconf"
jobs_for() { FAKE_CPUS="$1" PATH="$R/fakebin:$PATH" aapp test 2>&1; }
o10="$(jobs_for 10)"; o12="$(jobs_for 12)"; o2="$(jobs_for 2)"; o0="$(jobs_for '')"
if printf '%s' "$o10" | grep -q 'Jobs: 8' && printf '%s' "$o12" | grep -q 'Jobs: 12' && \
   printf '%s' "$o2" | grep -q 'Jobs: 2' && printf '%s' "$o0" | grep -q 'Jobs: 1' && printf '%s' "$o0" | grep -qi 'cpu count'; then
  ok "test_default_jobs_multiple_of_four"
else
  bad "test_default_jobs_multiple_of_four" "$(printf '%s\n' "$o10" "$o12" "$o2" "$o0" | grep -iE 'Jobs:|cpu' | tr '\n' ' ')"
fi

aapp test jobs 0 >/dev/null 2>&1; r1=$?
aapp test jobs x >/dev/null 2>&1; r2=$?
aapp test jobs >/dev/null 2>&1; r3=$?
if [ "$r1" -eq 1 ] && [ "$r2" -eq 1 ] && [ "$r3" -eq 1 ]; then
  ok "test_jobs_refuses_non_number"
else
  bad "test_jobs_refuses_non_number" "rc=$r1/$r2/$r3"
fi

print_test_summary "$PASS" "$FAIL"
