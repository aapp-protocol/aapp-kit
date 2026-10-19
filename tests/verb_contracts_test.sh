#!/usr/bin/env bash
# Tests: verb contract correspondence (P-34) — lib/verbs.tsv <-> lib/docs/verbs/
# Read-only over the kit tree: every daily verb has a contract, every contract
# has exactly one registry row, every test a contract names exists, and every
# test a verb suite reports is named by its verb's contract (P-81).
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
if [ -z "$errors" ]; then ok "test_contracts_follow_the_shape"; else bad "test_contracts_follow_the_shape" "${errors#
}"; fi

echo "== declared tests =="
errors=""
names_missing=""
for f in "$DOCS"/*.md; do
  [ -f "$f" ] || continue
  while IFS= read -r ident; do
    path="${ident%%::*}"
    name="${ident#*::}"
    verb="${f##*/}"; verb="${verb%.md}"
    # A verb suite file belongs to its own verb: tests/verbs/<verb>.sh or a part <verb>.<part>.sh (P-68).
    case "$path" in
      tests/verbs/*) case "${path#tests/verbs/}" in "$verb".sh|"$verb".*.sh) ;; *) names_missing="$names_missing
${f##*/}: '$path' is not $verb's verb suite or one of its parts" ;; esac ;;
    esac
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
if [ -z "$names_missing" ]; then ok "test_contract_tests_exist_in_suite_or_part"; else bad "test_contract_tests_exist_in_suite_or_part" "${names_missing#
}"; fi

# The other direction (P-81): every test a verb suite or part reports is named
# by that verb's contract, so a test whose behaviour left the contract fails here.
unnamed=""
for s in "$KIT"/tests/verbs/*.sh; do
  [ -f "$s" ] || continue
  base="${s##*/}"; verb="${base%%.*}"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    grep -qF "tests/verbs/$base::$name" "$DOCS/$verb.md" 2>/dev/null || unnamed="$unnamed
tests/verbs/$base::$name is named by no contract (lib/docs/verbs/$verb.md)"
  done < <(grep -oE 'ok "test_[A-Za-z0-9_]+' "$s" | sed 's/^ok "//' | sort -u)
done
if [ -z "$unnamed" ]; then ok "test_every_verb_test_named_by_contract"; else bad "test_every_verb_test_named_by_contract" "${unnamed#
}"; fi

echo "== core contracts (P-113) =="
# Every flat suite tests/<suite>_test.sh has lib/docs/core/<suite>.md, and the
# other way round; its ## Tests names exactly the tests the suite reports.
CORE="$KIT/lib/docs/core"
errors=""
for s in "$KIT"/tests/*_test.sh; do
  [ -f "$s" ] || continue
  base="${s##*/}"; stem="${base%_test.sh}"
  [ -f "$CORE/$stem.md" ] || errors="$errors
tests/$base has no contract lib/docs/core/$stem.md"
done
for f in "$CORE"/*.md; do
  [ -f "$f" ] || continue
  stem="${f##*/}"; stem="${stem%.md}"
  [ -f "$KIT/tests/${stem}_test.sh" ] || errors="$errors
lib/docs/core/$stem.md names no suite tests/${stem}_test.sh"
  head -n 1 "$f" | grep -qx "# $stem" || errors="$errors
lib/docs/core/$stem.md: first line is not '# $stem'"
  [ "$(grep -E '^## ' "$f")" = "## Tests" ] || errors="$errors
lib/docs/core/$stem.md: its only heading is not '## Tests'"
  grep -qx "Run: \`aapp test $stem\`" "$f" || errors="$errors
lib/docs/core/$stem.md: ## Tests has no 'Run: \`aapp test $stem\`' line"
done
if [ -z "$errors" ]; then ok "test_core_contract_per_suite"; else bad "test_core_contract_per_suite" "${errors#
}"; fi

errors=""
for f in "$CORE"/*.md; do
  [ -f "$f" ] || continue
  stem="${f##*/}"; stem="${stem%.md}"; suite="tests/${stem}_test.sh"
  [ -f "$KIT/$suite" ] || continue
  listed="$(awk '/^## Tests/{t=1; next} /^## /{t=0} t && /^- `/ { s=$0; sub(/^- `/, "", s); sub(/`.*/, "", s); print s }' "$f")"
  while IFS= read -r ident; do
    [ -n "$ident" ] || continue
    case "$ident" in "$suite::test_"*) ;; *) errors="$errors
lib/docs/core/$stem.md: '$ident' is not a test of $suite"; continue ;; esac
    grep -qE "(ok \"|t_done \"?)${ident#*::}\b" "$KIT/$suite" || errors="$errors
lib/docs/core/$stem.md: '${ident#*::}' is not reported by $suite"
  done <<< "$listed"
  # A core suite reports only test_<name> results, each named by its contract.
  while IFS= read -r label; do
    [ -n "$label" ] || continue
    case "$label" in
      test_*) printf '%s\n' "$listed" | grep -qxF "$suite::$label" || errors="$errors
$suite::$label is named by no contract (lib/docs/core/$stem.md)" ;;
      *) errors="$errors
$suite reports '$label', not a test_<name>" ;;
    esac
  done < <(grep -oE '(\bok "|\bt_done "?)[^" ]+' "$KIT/$suite" | sed -E 's/^(ok "|t_done "?)//' | grep -E '^[A-Za-z_][A-Za-z0-9_]*$' | sort -u)
done
if [ -z "$errors" ]; then ok "test_every_core_test_named_by_contract"; else bad "test_every_core_test_named_by_contract" "${errors#
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
    want="aapp $(head -n 1 "$KIT/$contract" | sed 's/^# //')"
    "$KIT/aapp" help "$verb" 2>/dev/null | grep -qxF -- "$want" || errors="$errors
'aapp help $verb' does not print $contract's synopsis"
  fi
done < "$MANIFEST"
if [ -z "$errors" ]; then ok "test_daily_verbs_in_agent_reference"; else bad "test_daily_verbs_in_agent_reference" "${errors#
}"; fi

echo "== rules file (P-87) =="
# The rules file holds rules: a verb's procedure is its skill's, its syntax is
# `aapp help <verb>`'s.
if ! grep -qF 'First-Run Repository Onboarding' "$AGENTS_TEMPLATE" && \
   ! grep -qF 'mv .plans/current' "$AGENTS_TEMPLATE" && \
   grep -qF 'Canonical Planning Invariant' "$AGENTS_TEMPLATE"; then
  ok "test_rules_file_has_no_walkthroughs"
else
  bad "test_rules_file_has_no_walkthroughs" "templates/AGENTS.md still walks through verbs, or lost the planning invariant"
fi
if grep -qF '`/aapp`' "$AGENTS_TEMPLATE" && grep -qF 'aapp help <verb>' "$AGENTS_TEMPLATE"; then
  ok "test_rules_file_points_to_help"
else
  bad "test_rules_file_points_to_help" "templates/AGENTS.md names no '/aapp' or no 'aapp help <verb>'"
fi
errors=""
grep -qF '.agents/skills/<name>/SKILL.md' "$AGENTS_TEMPLATE" || errors="
the skill index does not name .agents/skills/<name>/SKILL.md"
for d in "$KIT"/templates/skills/*/; do
  [ -f "${d}SKILL.md" ] || continue
  s="${d%/}"; s="${s##*/}"
  grep -qE "^\| \`/$s\` \|" "$AGENTS_TEMPLATE" || errors="$errors
skill '$s' has no row in the rules file's skill index"
done
if [ -z "$errors" ]; then ok "test_every_skill_in_rules_index"; else bad "test_every_skill_in_rules_index" "${errors#
}"; fi

"$KIT/aapp" help no-such-verb >/dev/null 2>&1; rc=$?
if [ "$rc" -ne 0 ]; then ok "test_help_unknown_verb_refuses"; else bad "test_help_unknown_verb_refuses" "rc=$rc"; fi

print_test_summary "$PASS" "$FAIL"
