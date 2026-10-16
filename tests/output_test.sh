#!/usr/bin/env bash
# Unit suite for lib/output.sh (P-92): terminal width, wrapping and cutting.
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

# shellcheck source=/dev/null
. "$KIT/lib/aapp-lib.sh"
# shellcheck source=/dev/null
[ -f "$KIT/lib/output.sh" ] && . "$KIT/lib/output.sh"

git init -q "$R/repo" && cd "$R/repo" || exit 1

# longest <text>: the most characters on one of its lines.
longest() { local l m=0 n; while IFS= read -r l; do n="$(aapp_char_len "$l")"; [ "$n" -gt "$m" ] && m="$n"; done <<< "$1"; echo "$m"; }
words="$(for i in $(seq 1 50); do printf 'word%02d ' "$i"; done)"; words="${words% }"

echo "== out_wrap =="
if declare -f out_wrap >/dev/null; then
  git config aapp.statusOutputWidth 60
  out="$(printf '%s' "$words" | out_wrap 2 8)"
  first="$(printf '%s\n' "$out" | head -1)"; rest="$(printf '%s\n' "$out" | tail -n +2)"
  joined="$(printf '%s\n' "$out" | sed -E 's/^ +//' | tr '\n' ' ' | sed 's/ $//')"
  if [[ "$first" == "  word01"* ]] && ! printf '%s\n' "$rest" | grep -qvE '^        [^ ]' && \
     [ "$(longest "$out")" -le 60 ] && [ "$joined" = "$words" ] && [ "$(printf '%s\n' "$out" | wc -l)" -gt 3 ]; then
    ok "test_wrap_hanging_indent"
  else
    bad "test_wrap_hanging_indent" "longest=$(longest "$out") out=$out"
  fi

  git config aapp.statusOutputWidth 40
  wide="$(for i in $(seq 1 20); do printf 'é…ü… '; done)"; wide="${wide% }"
  out="$(printf '%s' "$wide" | out_wrap 0 0)"
  if [ "$(longest "$out")" -le 40 ] && [ "$(longest "$out")" -ge 35 ] && [ "$(printf '%s\n' "$out" | wc -l)" -le 3 ]; then
    ok "test_wrap_counts_characters"
  else
    bad "test_wrap_counts_characters" "longest=$(longest "$out") lines=$(printf '%s\n' "$out" | wc -l)"
  fi

  long="$(printf 'x%.0s' $(seq 1 100))"
  out="$(printf '%s' "short $long tail" | out_wrap 2 2)"
  if printf '%s\n' "$out" | grep -qxF "  $long" && printf '%s\n' "$out" | head -1 | grep -qx '  short'; then
    ok "test_wrap_long_word_uncut"
  else
    bad "test_wrap_long_word_uncut" "out=$out"
  fi
else
  for t in test_wrap_hanging_indent test_wrap_counts_characters test_wrap_long_word_uncut; do bad "$t" "out_wrap not implemented"; done
fi

echo "== out_cut =="
if declare -f out_cut >/dev/null; then
  text="$(for i in $(seq 1 40); do printf 'lorem%02d ' "$i"; done)"; text="${text% }"
  out="$(printf '%s' "$text" | out_cut 220)"
  body="${out%…}"
  if [ "$(aapp_char_len "$out")" -le 220 ] && [ "$body" != "$out" ] && [[ "$text" == "$body"* ]] && \
     [[ "${text:${#body}:1}" == " " ]] && [ "$(printf '%s' 'short text' | out_cut 220)" = "short text" ]; then
    ok "test_cut_at_word"
  else
    bad "test_cut_at_word" "len=$(aapp_char_len "$out") out=$out"
  fi
else
  bad "test_cut_at_word" "out_cut not implemented"
fi

echo "== out_width =="
if declare -f out_width >/dev/null; then
  git config aapp.statusOutputWidth 60; w60="$(out_width)"
  git config --unset aapp.statusOutputWidth; wdef="$(out_width)"
  git config aapp.statusOutputWidth abc; ea="$(out_width 2>&1 >/dev/null)"; ra=$?
  git config aapp.statusOutputWidth 39; e39="$(out_width 2>&1 >/dev/null)"; r39=$?
  git config --unset aapp.statusOutputWidth
  if [ "$w60" = "60" ] && [ "$wdef" = "85" ] && [ "$ra" -ne 0 ] && echo "$ea" | grep -q "aapp.statusOutputWidth" && \
     [ "$r39" -ne 0 ] && echo "$e39" | grep -q "aapp.statusOutputWidth"; then
    ok "test_width_setting"
  else
    bad "test_width_setting" "60=$w60 def=$wdef abc=$ra/$ea 39=$r39/$e39"
  fi
else
  bad "test_width_setting" "out_width not implemented"
fi

print_test_summary "$PASS" "$FAIL"
