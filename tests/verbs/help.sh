#!/usr/bin/env bash
# Tests: `aapp help` behaviour contract (lib/docs/verbs/help.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1
contract="$KIT/lib/docs/verbs/commit.md"
synopsis="aapp $(head -n 1 "$contract" | sed 's/^# //')"
ingress="$(awk '/^## Ingress/{r=1; next} /^## /{r=0} r && NF' "$contract")"

echo "== help <verb> =="
out="$(aapp help commit 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | head -n 1)" = "$synopsis" ] && \
   [ "$(printf '%s\n' "$out" | grep -cxF -f <(printf '%s\n' "$ingress"))" -eq "$(printf '%s\n' "$ingress" | wc -l)" ] && \
   ! printf '%s\n' "$out" | grep -qE '^## (Failure modes|Tests)'; then
  ok "test_help_verb_is_short"
else
  bad "test_help_verb_is_short" "rc=$rc out=$(printf '%s\n' "$out" | head -n 3)"
fi

if [ "$(printf '%s\n' "$out" | tail -n 1 | grep -cF 'aapp help commit full')" -eq 1 ]; then
  ok "test_help_names_full"
else
  bad "test_help_names_full" "last=$(printf '%s\n' "$out" | tail -n 1)"
fi

out="$(aapp help commit full 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "$(cat "$contract")" ]; then
  ok "test_help_verb_full"
else
  bad "test_help_verb_full" "rc=$rc lines=$(printf '%s\n' "$out" | wc -l)"
fi

echo "== <verb> help / -h / --help =="
plans0="$(ls .plans/current | wc -l)"; head0="$(git -C .plans rev-parse HEAD)"
errors=""
for v in tdd draft issue commit; do
  for flag in help -h --help; do
    out="$(aapp "$v" "$flag" 2>&1)"; rc=$?
    [ "$rc" -eq 0 ] && [ "$out" = "$(aapp help "$v" 2>&1)" ] || errors="$errors $v($flag,rc=$rc)"
  done
done
if [ -z "$errors" ] && [ "$(ls .plans/current | wc -l)" = "$plans0" ] && [ "$(git -C .plans rev-parse HEAD)" = "$head0" ]; then
  ok "test_help_after_verb"
else
  bad "test_help_after_verb" "errors=$errors plans=$(ls .plans/current | tr '\n' ' ')"
fi

out_full="$(aapp commit --help full 2>&1)"; rc_full=$?
if [ "$rc_full" -eq 0 ] && [ "$out_full" = "$(cat "$contract")" ]; then
  ok "test_help_flag_full"
else
  bad "test_help_flag_full" "rc=$rc_full"
fi

out="$(aapp pause help 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "$(aapp help pause 2>&1)" ] && printf '%s\n' "$out" | grep -qF 'aapp pause' && \
   [ ! -f "$(git rev-parse --git-common-dir)/aapp_paused" ]; then
  ok "test_help_after_verb_without_contract"
else
  bad "test_help_after_verb_without_contract" "rc=$rc out=$out"
fi

echo "== refusals =="
out="$(aapp help nosuch 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -qF "aapp help"; then
  ok "test_help_unknown_verb"
else
  bad "test_help_unknown_verb" "rc=$rc out=$out"
fi

print_test_summary "$PASS" "$FAIL"
