#!/usr/bin/env bash
# Tests: `aapp plan` behaviour contract (lib/docs/verbs/plan.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-48s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-48s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1

out="$(aapp plan 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'aapp plan-status' && printf '%s' "$out" | grep -q 'aapp active'; then
  ok "test_prints_switchboard"
else
  bad "test_prints_switchboard" "rc=$rc"
fi

# Snapshot every tracked and untracked file state in the project and plans worktree.
snapshot() { { git status --porcelain --ignored; git -C .plans status --porcelain; git -C .plans rev-parse HEAD; } 2>/dev/null; }
before="$(snapshot)"
aapp plan P-1 >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && [ "$(snapshot)" = "$before" ]; then
  ok "test_changes_nothing"
else
  bad "test_changes_nothing" "rc=$rc"
fi

echo "== conflict-check / conflict-free (P-65) =="
init_sandbox_project "$R/c"
cd "$R/c" || exit 1
pfile() { ls .plans/current/P"${1#P-}"-*.md; }
# targets <id> <path>…: the plan's Target Files become exactly these paths.
targets() {
  local id="$1" f t list=""; shift; f="$(pfile "$id")"
  for t in "$@"; do list="$list- [ ] \`$t\` -> target.\n"; done
  awk -v l="$(printf "$list")" '/src\/path\/to\/new_file\.ext/ { next } /src\/path\/to\/file\.ext/ { print l; next } { print }' "$f" > "$f.t" && mv "$f.t" "$f"
}
# mk <slug> <path>… [group <id>]: a drafted plan with these Target Files; prints its ID.
mk() {
  local slug="$1" id paths=() grp=""; shift
  while [ $# -gt 0 ]; do [ "$1" = group ] && { grp="$2"; shift 2; continue; }; paths+=("$1"); shift; done
  id="P-$(git config aapp.planId)"
  if [ -n "$grp" ]; then aapp draft "$slug" group "$grp" >/dev/null 2>&1; else aapp draft "$slug" >/dev/null 2>&1; fi
  targets "$id" "${paths[@]}"; echo "$id"
}
status_to() { sed -i -E "s/^\* \*\*Status:\*\*.*/* **Status:** $2/" "$(pfile "$1")"; }
grp() { local id; id="P-$(git config aapp.planId)"; aapp draft "$1" group >/dev/null 2>&1; echo "$id"; }

a="$(mk ca src/a.sh)"; b="$(mk cb src/b.sh)"; c="$(mk cc src/a.sh)"
out="$(aapp plan conflict-check "$a" "$b" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -qi "disjoint"; then
  ok "test_conflict_check_disjoint_plans_exit_zero"
else
  bad "test_conflict_check_disjoint_plans_exit_zero" "rc=$rc out=$out"
fi
out="$(aapp plan conflict-check "$a" "$c" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -qF "src/a.sh" && echo "$out" | grep -qF "$a" && echo "$out" | grep -qF "$c"; then
  ok "test_conflict_check_overlapping_plans_exit_one_and_names_target"
else
  bad "test_conflict_check_overlapping_plans_exit_one_and_names_target" "rc=$rc out=$out"
fi
d="$(mk cd src/d.sh CHANGELOG.md)"; e="$(mk ce src/e.sh CHANGELOG.md)"
out="$(aapp plan conflict-check "$d" "$e" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q "Shared Doc" && echo "$out" | grep -qF "CHANGELOG.md"; then
  ok "test_conflict_check_exempts_shared_docs"
else
  bad "test_conflict_check_exempts_shared_docs" "rc=$rc out=$out"
fi

status_to "$a" "⚡ In Development"
out="$(aapp plan conflict-free 2>&1)"; rc=$?
free="$(echo "$out" | awk '/Conflict-Free/{f=1; next} /Conflicting/{f=0} f')"
confl="$(echo "$out" | awk '/Conflicting/{f=1} f')"
if [ "$rc" -eq 0 ] && echo "$free" | grep -qF "$b" && ! echo "$free" | grep -qF "$c:" && \
   echo "$confl" | grep -F "$c" | grep -qF "src/a.sh" && echo "$confl" | grep -F "$c" | grep -qF "$a"; then
  ok "test_conflict_free_against_active_in_flight_plans"
else
  bad "test_conflict_free_against_active_in_flight_plans" "rc=$rc out=$out"
fi
status_to "$a" "🟣 Under Review"
out="$(aapp plan conflict-free "$a" 2>&1)"; rc=$?
comp="$(echo "$out" | awk '/Compatible/{f=1; next} /Incompatible/{f=0} f')"
incomp="$(echo "$out" | awk '/Incompatible/{f=1} f')"
if [ "$rc" -eq 0 ] && echo "$comp" | grep -qF "$b" && echo "$incomp" | grep -F "$c" | grep -qF "src/a.sh"; then
  ok "test_conflict_free_with_reference_plan"
else
  bad "test_conflict_free_with_reference_plan" "rc=$rc out=$out"
fi

g="$(grp g-one)"; m1="$(mk gm1 src/m1.sh group "$g")"; m2="$(mk gm2 src/m2.sh group "$g")"
out1="$(aapp plan conflict-check "$a" "$b" "$c" 2>&1)"; r1=$?
out2="$(aapp plan conflict-check "$g" 2>&1)"; r2=$?
if [ "$r1" -eq 1 ] && echo "$out1" | grep -qF "src/a.sh" && [ "$r2" -eq 0 ] && \
   echo "$out2" | grep -qF "$m1" && echo "$out2" | grep -qF "$m2"; then
  ok "test_conflict_check_many_plans_and_group_expands"
else
  bad "test_conflict_check_many_plans_and_group_expands" "rc=$r1/$r2 out=$out1 | $out2"
fi

g2="$(grp g-two)"; x="$(mk gx src/x.sh group "$g2")"; y="$(mk gy src/x.sh group "$g2")"; z="$(mk gz src/z.sh group "$g2")"
out="$(aapp plan conflict-free "$g2" 2>&1)"; rc=$?
w1="$(echo "$out" | grep '^ *Wave 1')"; w2="$(echo "$out" | grep '^ *Wave 2')"
if [ "$rc" -eq 0 ] && echo "$w1" | grep -qF "$x" && echo "$w1" | grep -qF "$z" && ! echo "$w1" | grep -qF "$y" && \
   echo "$w2" | grep -qF "$y" && echo "$out" | grep -F "$y" | grep -F "src/x.sh" | grep -qF "$x"; then
  ok "test_conflict_free_group_orders_members_in_waves"
else
  bad "test_conflict_free_group_orders_members_in_waves" "rc=$rc out=$out"
fi
o="$(mk go src/z.sh)"; status_to "$o" "⚡ In Development"
out="$(aapp plan conflict-free "$g2" 2>&1)"; rc=$?
w1="$(echo "$out" | grep '^ *Wave 1')"; w2="$(echo "$out" | grep '^ *Wave 2')"
if [ "$rc" -eq 0 ] && ! echo "$w1" | grep -qF "$z" && echo "$w2" | grep -qF "$z" && \
   echo "$out" | grep -F "$z" | grep -F "src/z.sh" | grep -qF "$o"; then
  ok "test_group_waves_respect_in_flight_plans"
else
  bad "test_group_waves_respect_in_flight_plans" "rc=$rc out=$out"
fi
status_to "$o" "🟣 Under Review"

g3="$(grp g-three)"; p="$(mk gp src/p.sh group "$g3")"; q="$(mk gq src/q.sh group "$g3")"
r="$(mk gr src/q.sh group "$g3")"; s="$(mk gs src/s.sh group "$g3")"
status_to "$p" "✅ Done"; status_to "$q" "⚡ In Development"
out="$(aapp plan conflict-free "$g3" 2>&1)"; rc=$?
waves="$(echo "$out" | grep '^ *Wave ')"; w1="$(echo "$out" | grep '^ *Wave 1')"; w2="$(echo "$out" | grep '^ *Wave 2')"
if [ "$rc" -eq 0 ] && ! echo "$waves" | grep -qF "$p" && ! echo "$waves" | grep -qF "$q" && \
   echo "$w1" | grep -qF "$s" && ! echo "$w1" | grep -qF "$r" && echo "$w2" | grep -qF "$r" && \
   echo "$out" | grep -F "$r" | grep -qF "$q"; then
  ok "test_group_waves_filters_done_and_inflight_members"
else
  bad "test_group_waves_filters_done_and_inflight_members" "rc=$rc out=$out"
fi

j1="$(aapp plan conflict-check "$a" "$b" json 2>/dev/null)"; r1=$?
j2="$(aapp plan conflict-check "$a" "$c" json 2>/dev/null)"; r2=$?
j3="$(aapp plan conflict-free "$g2" json 2>/dev/null)"; r3=$?
j4="$(aapp plan conflict-free json 2>/dev/null)"; r4=$?
if [ "$r1" -eq 0 ] && echo "$j1" | grep -q '"clean": true' && [ "$r2" -eq 1 ] && echo "$j2" | grep -q '"clean": false' && \
   echo "$j2" | grep -q '"target": "src/a.sh"' && [ "$r3" -eq 0 ] && echo "$j3" | grep -q '"waves"' && \
   echo "$j3" | grep -q "\"group\": \"$g2\"" && [ "$r4" -eq 0 ] && echo "$j4" | grep -q '"conflict_free"' && \
   python3 -c 'import json,sys; [json.loads(s) for s in sys.argv[1:]]' "$j1" "$j2" "$j3" "$j4" 2>/dev/null; then
  ok "test_conflict_subcommands_json_token_output"
else
  bad "test_conflict_subcommands_json_token_output" "rc=$r1/$r2/$r3/$r4 j=$j1 | $j2 | $j3 | $j4"
fi

print_test_summary "$PASS" "$FAIL"
