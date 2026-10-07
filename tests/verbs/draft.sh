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
if grep -qx '\* \*\*Changelog:\*\* Changed: Fix The Parser' "$f"; then
  ok "test_draft_prefills_changelog_entry"
else
  bad "test_draft_prefills_changelog_entry" "line=[$(grep -m1 'Changelog:' "$f")]"
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

echo "== pathspec-limited plan commit (P-39) =="
cd "$(fresh path_limit)" || exit 1
echo "outside file" > .plans/staged_outside.txt
git -C .plans add staged_outside.txt
aapp draft "path-limit-feat" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && git -C .plans diff --cached --name-only | grep -q "staged_outside.txt"; then
  ok "test_commit_takes_only_its_paths"
else
  bad "test_commit_takes_only_its_paths" "rc=$rc staged_outside was swept into draft commit"
fi

echo "== plan-recorded modes (P-51) =="
cd "$(fresh modes)" || exit 1
git config aapp.commitMode microcommits; git config aapp.changelogMode commit
mid="$(git config --get aapp.planId)"
aapp draft modes-plan >/dev/null 2>&1
mf=".plans/current/P${mid}-modes-plan.md"
if grep -qxF "* **Commit Mode:** microcommits" "$mf" && grep -qxF "* **Changelog Mode:** commit" "$mf"; then
  ok "test_draft_records_modes"
else
  bad "test_draft_records_modes" "$(grep -E 'Mode:' "$mf" | tr '\n' ' ')"
fi

echo "== promotion: issue <num> (P-50) =="
cd "$(fresh promote)" || exit 1
cat > .plans/ISSUES.md <<'EOF'
# Issues

| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #7 | `High` | `CORE` | 2026-10-07 | `a.sh` | Needs a plan. | Promote it. | 🟡 `Incubated` |
EOF
cat > .plans/done/000-issues-archive.md <<'EOF'
# Archive

| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #5 | `Low` | `CLI` | 2026-08-01 | 2026-08-02 | `0000000` | Old. |
EOF
git -C .plans add ISSUES.md done/000-issues-archive.md >/dev/null 2>&1; git -C .plans commit -qm "fixture" >/dev/null 2>&1
rm_before="$(cat .plans/issues_road_map.md)"
pid="$(git config --get aapp.planId)"
out="$(aapp draft promote-me issue 7 2>&1)"; rc=$?
pf=".plans/current/P${pid}-promote-me.md"
if [ "$rc" -eq 0 ] && grep -qxF "* **Target Issue / Milestone:** #7" "$pf" && \
   grep -qF "| [P-${pid}](current/P${pid}-promote-me.md) | 🔵 \`Planned\` |" .plans/ISSUES.md && \
   [ "$(cat .plans/issues_road_map.md)" = "$rm_before" ] && [ -z "$(git -C .plans status --porcelain)" ] && \
   git -C .plans log -1 --format=%s | grep -q "^plan(draft): scaffold P-${pid} promote-me$" && \
   git -C .plans show --name-only --format= HEAD | grep -qx "ISSUES.md"; then
  ok "test_draft_issue_promotes"
else
  bad "test_draft_issue_promotes" "rc=$rc out=$out row=$(grep '^| #7 |' .plans/ISSUES.md)"
fi
pid="$(git config --get aapp.planId)"
aapp draft from-archive issue 5 >/dev/null 2>&1; r1=$?
aapp draft from-nowhere issue 99 >/dev/null 2>&1; r2=$?
if [ "$r1" -ne 0 ] && [ "$r2" -ne 0 ] && [ "$(git config --get aapp.planId)" = "$pid" ] && \
   [ -z "$(ls .plans/current | grep -E 'from-(archive|nowhere)')" ]; then
  ok "test_draft_issue_refuses_archived_or_unknown"
else
  bad "test_draft_issue_refuses_archived_or_unknown" "rc=$r1/$r2 planId=$(git config --get aapp.planId) want=$pid"
fi

print_test_summary "$PASS" "$FAIL"
