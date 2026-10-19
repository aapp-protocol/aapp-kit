#!/usr/bin/env bash
# Core suite for the documentation: front matter and navigation of the modular
# docs, no machine paths, and relative links that resolve.
set -uo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
PASS=0; FAIL=0

MODULAR=()
while IFS= read -r f; do MODULAR+=("$f"); done < <(find "$KIT/docs" -name "*.md" | sort)
ALL=("$KIT/COOKBOOK.md" "$KIT/MANUAL.md" "$KIT/README.md" "${MODULAR[@]}")

echo "== front matter and navigation =="
for f in "${MODULAR[@]}"; do
  [ "$(head -n 1 "$f")" = "---" ] && sed -n '2,20p' "$f" | grep -q "^---$" && grep -q "^title: " "$f" || \
    t_fail "no front matter (---, title:, ---) in ${f#"$KIT"/}"
done
t_done test_modular_docs_have_frontmatter

for f in "${MODULAR[@]}"; do
  grep -Eq "(Continuous Navigation|Cookbook Catalog|Technical Manual|Manual|Navigation)" "$f" || \
    t_fail "no navigation block in ${f#"$KIT"/}"
done
t_done test_modular_docs_have_navigation

echo "== machine paths =="
for f in "${ALL[@]}"; do
  grep -q "file:///" "$f" && t_fail "file:/// URI in ${f#"$KIT"/}"
  grep -Eq "/home/[a-zA-Z0-9_-]+" "$f" && t_fail "home path in ${f#"$KIT"/}"
done
t_done test_docs_hold_no_machine_paths

echo "== relative links =="
for f in "${ALL[@]}"; do
  dir="$(dirname "$f")"
  # Code blocks and inline code spans hold no links.
  while IFS= read -r link; do
    target="${link%%#*}"
    [ -n "$target" ] || continue
    [ -e "$dir/$target" ] || t_fail "broken link in ${f#"$KIT"/}: $link"
  done < <(sed -e '/```/,/```/d' "$f" | sed -E 's/`[^`]*`//g' | grep -oE '\]\([^)]+\)' | \
           sed -E 's/^\]\(([^)]+)\)/\1/' | grep -vE '^(http|https|mailto):')
done
t_done test_relative_links_resolve

print_test_summary "$PASS" "$FAIL"
