#!/usr/bin/env bash
# Tests: `aapp draft` behaviour contract (lib/docs/verbs/draft.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-48s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-48s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

# fresh <name>: a new initialised project; the caller cds into it.
fresh() { init_sandbox_project "$R/$1"; echo "$R/$1"; }

# placeholders_left <file>: prints any surviving template placeholder.
placeholders_left() { grep -nE 'P-XX|\[YYYY-MM-DD\]|\[Feature or Refactor Name\]' "$1"; }

echo "== happy path =="
cd "$(fresh named)" || exit 1
id_before="$(git config --get aapp.planId)"
out="$(aapp draft fix-the-parser 2>&1)"; rc=$?
f=".plans/current/P${id_before}-fix-the-parser.md"
if [ "$rc" -eq 0 ] && [ -f "$f" ] && grep -q "^# 🗺️ Plan P-${id_before}: Fix The Parser$" "$f" && \
   grep -q "Created:\*\* $(date +%Y-%m-%d)" "$f" && [ -z "$(placeholders_left "$f")" ] && \
   [ "$(git config --get aapp.planId)" -gt "$id_before" ] && grep -q "fix-the-parser.md" .plans/state_matrix.md && \
   [ -z "$(git -C .plans status --porcelain)" ] && \
   git -C .plans log -1 --format=%s | grep -q "^plan(draft): scaffold P-${id_before} fix-the-parser$"; then
  ok "test_named_draft_scaffolds_and_commits"
else
  bad "test_named_draft_scaffolds_and_commits" "rc=$rc"; echo "$out" | tail -3 | sed 's/^/       /'
fi

echo "== titles with sed metacharacters (D1) =="
cd "$(fresh slash)" || exit 1
id="$(git config --get aapp.planId)"
aapp draft "fix/the-parser" >/dev/null 2>&1; rc=$?
f="$(ls .plans/current/P"${id}"-*.md 2>/dev/null | head -1)"
if [ "$rc" -eq 0 ] && [ -n "$f" ] && grep -qF "Plan P-${id}: Fix/the Parser" "$f" && [ -z "$(placeholders_left "$f")" ] && \
   [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_title_with_slash"
else
  bad "test_title_with_slash" "rc=$rc file=${f:-none}"
fi

cd "$(fresh amp)" || exit 1
id="$(git config --get aapp.planId)"
aapp draft "salt-&-pepper" >/dev/null 2>&1; rc=$?
f="$(ls .plans/current/P"${id}"-*.md 2>/dev/null | head -1)"
if [ "$rc" -eq 0 ] && [ -n "$f" ] && grep -qF "Plan P-${id}: Salt & Pepper" "$f" && ! grep -qF "Plan P-XX" "$f"; then
  ok "test_title_with_ampersand"
else
  bad "test_title_with_ampersand" "rc=$rc file=${f:-none}"
fi

cd "$(fresh meta)" || exit 1
all_clean=1
# <argument>|<fragment that must appear literally in the title line>
while IFS='|' read -r t frag; do
  id="$(git config --get aapp.planId)"
  aapp draft "$t" >/dev/null 2>&1 || { all_clean=0; echo "       '$t': exit non-zero"; continue; }
  f="$(ls .plans/current/P"${id}"-*.md 2>/dev/null | head -1)"
  if [ -z "$f" ] || [ -n "$(placeholders_left "$f")" ]; then all_clean=0; echo "       '$t': placeholders survive"; continue; fi
  grep -m1 '^# ' "$f" | grep -qF -- "$frag" || { all_clean=0; echo "       '$t': title lost '$frag'"; }
done <<'EOF'
path/to-thing|Path/to Thing
back\slash|Back\slash
brackets-[x]|[x]
star-*-glob|*
dollar-$HOME|$home
EOF
if [ "$all_clean" -eq 1 ]; then ok "test_no_placeholders_survive"; else bad "test_no_placeholders_survive" "see above"; fi

echo "== bare path =="
cd "$(fresh bare)" || exit 1
printf '1. Map the codebase into .agents/CODEMAP.md & friends\n' > .plans/pickup.md
git -C .plans add pickup.md >/dev/null 2>&1; git -C .plans commit -qm "pickup note" >/dev/null 2>&1
id="$(git config --get aapp.planId)"
aapp draft </dev/null >/dev/null 2>&1; rc=$?
f="$(ls .plans/current/P"${id}"-*.md 2>/dev/null | head -1)"
if [ "$rc" -eq 0 ] && [ -n "$f" ] && [ -z "$(placeholders_left "$f")" ] && \
   [ -z "$(git -C .plans status --porcelain -- current/)" ]; then
  ok "test_bare_draft_commits"
else
  bad "test_bare_draft_commits" "rc=$rc untracked=[$(git -C .plans status --porcelain -- current/ | tr '\n' ' ')]"
fi

cd "$(fresh bare_empty)" || exit 1
: > .plans/pickup.md
before="$(ls .plans/current | wc -l)"
aapp draft </dev/null >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ] && [ "$(ls .plans/current | wc -l)" -eq "$before" ]; then
  ok "test_bare_draft_without_notes_refuses"
else
  bad "test_bare_draft_without_notes_refuses" "rc=$rc"
fi

print_test_summary "$PASS" "$FAIL"
