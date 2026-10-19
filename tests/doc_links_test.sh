#!/usr/bin/env bash
# tests/doc_links_test.sh - Verification suite for documentation integrity, relative links, and frontmatter
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0

pass() {
  PASS=$((PASS + 1))
}

fail() {
  echo "FAIL: $1" >&2
  FAIL=$((FAIL + 1))
}

echo "=== Running Documentation Link & Frontmatter Verification Suite ==="

MODULAR_DOC_FILES=()
while IFS= read -r f; do
  [[ -f "$f" ]] && MODULAR_DOC_FILES+=("$f")
done < <(find "$REPO_ROOT/docs" -name "*.md" 2>/dev/null || true)

ALL_DOC_FILES=(
  "$REPO_ROOT/COOKBOOK.md"
  "$REPO_ROOT/MANUAL.md"
  "$REPO_ROOT/README.md"
)
for f in "${MODULAR_DOC_FILES[@]}"; do
  ALL_DOC_FILES+=("$f")
done

# 1. Frontmatter Verification on Modular Docs
echo "--- Checking Frontmatter ---"
for file in "${MODULAR_DOC_FILES[@]}"; do
  rel="${file#$REPO_ROOT/}"
  first_line="$(head -n 1 "$file")"
  if [[ "$first_line" == "---" ]] && sed -n '2,20p' "$file" | grep -q "^---$" && grep -q "^title: " "$file"; then
    pass
  else
    fail "Valid frontmatter (opening ---, closing ---, title:) missing in $rel"
  fi
done

# 2. Continuous Navigation Check
echo "--- Checking Continuous Navigation Links ---"
for file in "${MODULAR_DOC_FILES[@]}"; do
  rel="${file#$REPO_ROOT/}"
  if grep -E -q "(Continuous Navigation|Cookbook Catalog|Technical Manual|Manual|Navigation)" "$file"; then
    pass
  else
    fail "Continuous navigation block missing in $rel"
  fi
done

# 3. Absolute Paths & file:/// Link Invariant
echo "--- Checking for Absolute Paths or file:/// URIs ---"
for file in "${ALL_DOC_FILES[@]}"; do
  rel="${file#$REPO_ROOT/}"
  if grep -n -E "file:///" "$file" >/dev/null; then
    fail "file:/// URI found in $rel"
  else
    pass
  fi
  if grep -n -E "/home/[a-zA-Z0-9_-]+" "$file" >/dev/null; then
    fail "Machine-specific home path found in $rel"
  else
    pass
  fi
done

# 4. Relative Link Validation
echo "--- Checking Relative Links Resolution ---"
for file in "${ALL_DOC_FILES[@]}"; do
  dir="$(dirname "$file")"
  rel="${file#$REPO_ROOT/}"
  
  # Strip multiline code blocks and inline code spans before extracting links
  cleaned_content=$(sed -e '/```/,/```/d' "$file" | sed -E 's/`[^`]*`//g')
  
  while IFS= read -r link; do
    [[ -z "$link" ]] && continue
    # Ignore anchors (#anchor)
    link_target="${link%%#*}"
    [[ -z "$link_target" ]] && continue
    
    # Resolve relative to current file's directory
    target_path="$dir/$link_target"
    if [[ ! -e "$target_path" ]]; then
      fail "Broken relative link in $rel: $link -> target not found at $target_path"
    else
      pass
    fi
  done < <(echo "$cleaned_content" | grep -o -E '\]\([^)]+\)' | sed -E 's/^\]\(([^)]+)\)/\1/' | grep -v -E '^(http|https|mailto):')
done

echo "=== Documentation Verification Completed ==="
echo "Passed: $PASS, Failed: $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
