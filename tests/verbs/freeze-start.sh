#!/usr/bin/env bash
# Tests: `aapp freeze-start` behaviour contract (lib/docs/verbs/freeze-start.md)
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
status_of() { grep -m1 '^\* \*\*Status:\*\*' "$1"; }
buffer_file() { git rev-parse --git-path aapp_active_plan; }

echo "== refusals =="
id="$(draft_plan open-questions)"; f="$(plan_file "$id")"
before="$(cksum < "$f")"
aapp freeze-start "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ] && [ "$(cksum < "$f")" = "$before" ] && [ ! -f "$(buffer_file)" ]; then
  ok "test_refuses_unresolved_questions"
else
  bad "test_refuses_unresolved_questions" "rc=$rc"
fi

echo "== happy path =="
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$f"; git -C .plans commit -qam "resolve questions" >/dev/null
aapp freeze-start "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && status_of "$f" | grep -q '⚡ In Development' && [ "$(cat "$(buffer_file)")" = "$id" ] && \
   grep -q "Plan frozen and activated into ⚡ In Development via freeze-start." "$f" && \
   git -C .plans log -1 --format=%s | grep -qF "plan(start): freeze and activate $id into development" && \
   [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_freezes_and_activates"
else
  bad "test_freezes_and_activates" "rc=$rc"
fi

echo "== source status (#89) =="
# The plan is now In Development: freeze-start must refuse and change nothing.
before="$(cksum < "$f")"
aapp freeze-start "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ] && [ "$(cksum < "$f")" = "$before" ]; then
  ok "test_refuses_non_incubator_plan"
else
  bad "test_refuses_non_incubator_plan" "rc=$rc"
fi

echo "== base recording (P-39) =="
id_fs="$(draft_plan fs-base)"
f_fs="$(plan_file "$id_fs")"
sed -i -E "s|src/path/to/file\.ext|src/fs_base_test.py|g; /src\/path\/to\/new_file\.ext/d" "$f_fs"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$f_fs"
git -C .plans commit -qam "prep $id_fs" >/dev/null
fs_head_sha="$(git rev-parse --short HEAD)"
fs_head_br="$(git rev-parse --abbrev-ref HEAD)"
aapp freeze-start "$id_fs" >/dev/null 2>&1
if grep -qF "* **Base:** \`$fs_head_sha\` ($fs_head_br)" "$f_fs"; then
  ok "test_records_base_sha_and_branch"
else
  bad "test_records_base_sha_and_branch" "base not recorded: $(grep -F '**Base:**' "$f_fs" 2>/dev/null)"
fi

echo "== queued plan blockers gate the start (P-58) =="
printf '%s\n' '# Issues' '' '| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |' \
  '| #20 | `High` | `CORE` | 2026-10-01 | `src/fs_q.py` | Q breaks. | blocks [P-1](current/P1-x.md) | 🟡 `Incubated` |' > .plans/ISSUES.md
printf '%s\n' '# Issue Priority Board' '' '## 🧱 Plan Blockers' '- [ ] #20 -> Q breaks. (blocks P-1)' '' '## 🔴 High Priority (Technical Urgency)' > .plans/issues_road_map.md
git -C .plans add ISSUES.md issues_road_map.md >/dev/null 2>&1; git -C .plans commit -qm fixture >/dev/null 2>&1
id_q="$(draft_plan fs-queued)"; f_q="$(plan_file "$id_q")"
sed -i -E "s|src/path/to/file\.ext|src/fs_q.py|g; /src\/path\/to\/new_file\.ext/d" "$f_q"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$f_q"
git -C .plans commit -qam "prep $id_q" >/dev/null
before="$(cksum < "$f_q")"
out="$(aapp freeze-start "$id_q" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -qF "src/fs_q.py has a pending fix (#20)" && [ "$(cksum < "$f_q")" = "$before" ]; then
  ok "test_refuses_target_with_pending_fix"
else
  bad "test_refuses_target_with_pending_fix" "rc=$rc out=$out"
fi

print_test_summary "$PASS" "$FAIL"
