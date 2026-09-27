#!/usr/bin/env bash
# Tests: `aapp done` behaviour contract (lib/docs/verbs/done.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-48s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-48s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1
draft_plan() {
  local id; id="$(git config --get aapp.planId)"
  aapp draft "$1" >/dev/null 2>&1 || return 1
  echo "P-$id"
}
plan_file() { ls .plans/current/P"${1#P-}"-*.md; }
# An in-development plan with a named Target Issue.
started_plan() {
  local id f; id="$(draft_plan "$1")"; f="$(plan_file "$id")"
  sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$f"
  sed -i -E 's/^(\* \*\*Target Issue \/ Milestone:\*\*).*/\1 #42/' "$f"
  git -C .plans commit -qam "prepare $id" >/dev/null
  aapp freeze-start "$id" >/dev/null 2>&1
  echo "$id"
}
ledger_row() { grep -F "\`$1\`" .plans/done/000-archive-ledger.md; }

echo "== refusals =="
aapp done P-999 >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ] && [ -z "$(ls .plans/done | grep -v '^000-')" ]; then ok "test_refuses_unknown_plan"; else bad "test_refuses_unknown_plan" "rc=$rc"; fi

echo "== source status (#89) =="
draft_id="$(draft_plan not-started)"; draft_f="$(plan_file "$draft_id")"
aapp done "$draft_id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ] && [ -f "$draft_f" ] && [ ! -e ".plans/done/$(basename "$draft_f")" ]; then
  ok "test_refuses_plan_not_in_development"
else
  bad "test_refuses_plan_not_in_development" "rc=$rc"
fi

echo "== happy path =="
id="$(started_plan archive-me)"; bname="$(basename "$(plan_file "$id")")"
aapp done "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && [ ! -e ".plans/current/$bname" ] && [ -f ".plans/done/$bname" ] && \
   grep -q '^\* \*\*Status:\*\* ✅ Done' ".plans/done/$bname" && \
   [ ! -f "$(git rev-parse --git-path aapp_active_plan)" ] && \
   git -C .plans log -1 --format=%s | grep -qF "plan(done): archive $id" && \
   [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_archives_and_commits"
else
  bad "test_archives_and_commits" "rc=$rc"
fi

echo "== ledger row (D2) =="
row="$(ledger_row "$id")"
issue_col="$(printf '%s' "$row" | awk -F'|' '{gsub(/^ +| +$/, "", $5); print $5}')"
summary_col="$(printf '%s' "$row" | awk -F'|' '{gsub(/^ +| +$/, "", $7); print $7}')"
if [ -n "$row" ] && [ "$issue_col" = "#42" ] && [ -n "$summary_col" ]; then
  ok "test_ledger_row_populated"
else
  bad "test_ledger_row_populated" "issue=[$issue_col] summary=[$summary_col]"
fi

echo "== matrix row removal (#88) =="
# IDs that collide as substrings: archiving P-3 must not touch P-30's row.
git config aapp.planId 3
short="$(started_plan short-id)"
git config aapp.planId 30
long="$(draft_plan long-id)"
aapp done "$short" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && [ "$short" = "P-3" ] && [ "$long" = "P-30" ] && \
   grep -q "long-id" .plans/state_matrix.md && ! grep -q "short-id" .plans/state_matrix.md; then
  ok "test_matrix_row_removed_exactly"
else
  bad "test_matrix_row_removed_exactly" "rc=$rc short=$short long=$long"
fi

print_test_summary "$PASS" "$FAIL"
