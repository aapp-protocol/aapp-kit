#!/usr/bin/env bash
# Tests: verb contract correspondence (P-34) — lib/verbs.tsv <-> lib/docs/verbs/
# Read-only over the kit tree: every daily verb has a contract, every contract
# has exactly one registry row, and every test a contract names exists.
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
PASS=0; FAIL=0
MANIFEST="$KIT/lib/verbs.tsv"
DOCS="$KIT/lib/docs/verbs"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "FAIL"; FAIL=$((FAIL+1)); printf '%s\n' "$2" | sed 's/^/       /'; }

TAB="$(printf '\t')"

echo "== registry <-> contracts =="
errors=""
refs=""
while IFS="$TAB" read -r verb tier standalone desc contract rest || [ -n "$verb" ]; do
  [ -z "$verb" ] && continue
  [ "${verb#\#}" != "$verb" ] && continue
  [ "$tier" = "daily" ] || continue
  if [ -z "$contract" ]; then
    errors="$errors
daily verb '$verb' has no contract column"
  elif [ ! -f "$KIT/$contract" ]; then
    errors="$errors
daily verb '$verb' names missing contract '$contract'"
  else
    refs="$refs
$contract"
  fi
done < "$MANIFEST"
for f in "$DOCS"/*.md; do
  [ -f "$f" ] || continue
  rel="lib/docs/verbs/${f##*/}"
  n="$(printf '%s\n' "$refs" | grep -cxF "$rel")"
  [ "$n" -eq 1 ] || errors="$errors
contract '$rel' is referenced by $n registry rows (want exactly 1)"
done
if [ -z "$errors" ]; then ok "test_registry_contract_correspondence"; else bad "test_registry_contract_correspondence" "${errors#
}"; fi

echo "== contract shape =="
errors=""
for f in "$DOCS"/*.md; do
  [ -f "$f" ] || continue
  want="## Ingress
## Preconditions
## Failure modes
## Effects (happy path)
## Exit
## Tests"
  got="$(grep -E '^## ' "$f")"
  [ "$got" = "$want" ] || errors="$errors
${f##*/}: headings are not the §2.1 shape"
  head -n 1 "$f" | grep -q '^# ' || errors="$errors
${f##*/}: first line is not '# <verb> [args]'"
  grep -q "^Run: \`aapp test verb " "$f" || errors="$errors
${f##*/}: ## Tests has no 'Run: \`aapp test verb <verb>\`' line"
done
if [ -z "$errors" ]; then ok "contracts follow the §2.1 shape"; else bad "contracts follow the §2.1 shape" "${errors#
}"; fi

echo "== declared tests =="
errors=""
names_missing=""
for f in "$DOCS"/*.md; do
  [ -f "$f" ] || continue
  while IFS= read -r ident; do
    path="${ident%%::*}"
    name="${ident#*::}"
    if [ ! -f "$KIT/$path" ]; then
      errors="$errors
${f##*/}: names missing test file '$path'"
    elif [ "$name" != "$ident" ] && ! grep -qF "$name" "$KIT/$path"; then
      names_missing="$names_missing
${f##*/}: '$name' not found in $path"
    fi
  done < <(awk '/^## Tests/{t=1; next} /^## /{t=0} t && /^- `/ { s=$0; sub(/^- `/, "", s); sub(/`.*/, "", s); print s }' "$f")
done
if [ -z "$errors" ]; then ok "test_declared_test_files_exist"; else bad "test_declared_test_files_exist" "${errors#
}"; fi
if [ -z "$names_missing" ]; then ok "declared test names appear in their files"; else bad "declared test names appear in their files" "${names_missing#
}"; fi

echo "== agent CLI reference (P-47) =="
# Every daily verb is reachable by agents without a skill: one line in the
# AGENTS.md CLI Reference, and its contract printed by `aapp help <verb>`.
AGENTS_TEMPLATE="$KIT/templates/AGENTS.md"
reference="$(awk '/^## .*CLI Reference/{r=1; next} /^## /{r=0} r' "$AGENTS_TEMPLATE")"
errors=""
[ -n "$reference" ] || errors="
templates/AGENTS.md has no '## … CLI Reference' section"
while IFS="$TAB" read -r verb tier standalone desc contract rest || [ -n "$verb" ]; do
  [ -z "$verb" ] && continue
  [ "${verb#\#}" != "$verb" ] && continue
  [ "$tier" = "daily" ] || continue
  printf '%s\n' "$reference" | grep -qE "aapp $verb([^a-z-]|\$)" || errors="$errors
'$verb' is missing from the AGENTS.md CLI Reference"
  if [ -n "$contract" ] && [ -f "$KIT/$contract" ]; then
    want="$(head -n 1 "$KIT/$contract")"
    "$KIT/aapp" help "$verb" 2>/dev/null | grep -qxF "$want" || errors="$errors
'aapp help $verb' does not print $contract"
  fi
done < "$MANIFEST"
if [ -z "$errors" ]; then ok "test_daily_verbs_in_agent_reference"; else bad "test_daily_verbs_in_agent_reference" "${errors#
}"; fi

"$KIT/aapp" help no-such-verb >/dev/null 2>&1; rc=$?
if [ "$rc" -ne 0 ]; then ok "test_help_unknown_verb_refuses"; else bad "test_help_unknown_verb_refuses" "rc=$rc"; fi

print_test_summary "$PASS" "$FAIL"
