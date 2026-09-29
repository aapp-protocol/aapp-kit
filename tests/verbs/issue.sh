#!/usr/bin/env bash
# Tests: `aapp issue` behaviour contract (lib/docs/verbs/issue.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1

# Known ledgers: three active issues (one with an escaped pipe), one archived.
cat > .plans/ISSUES.md <<'EOF'
# Issues

| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #10 | `Low` | `CLI` | 2026-09-01 | `a.sh` | Pipe `a\|b` breaks. | Escape the pipe. | 🟡 `Incubated` |
| #11 | `Medium` | `CORE` | 2026-09-02 | `b.sh` | Second defect. | Fix b. | 🟡 `Incubated` |
| #12 | `Low` | `CORE` | 2026-09-03 | `c.sh` | Third defect. | Fix c. | 🟡 `Incubated` |
EOF
cat > .plans/done/000-issues-archive.md <<'EOF'
# Archive

| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #5 | `Low` | `CLI` | 2026-08-01 | 2026-08-02 | `0000000` | Old. |
EOF
cat > .plans/issues_road_map.md <<'EOF'
# Board

## High
1. #11 -> Second defect.

## Triage
- [ ] #10 -> Pipe breaks.
- [ ] #12 -> Third defect.
EOF
git -C .plans add -A && git -C .plans commit -qm "fixture ledgers" >/dev/null 2>&1
git config aapp.issueId 13
SHA="$(git rev-parse --short=7 HEAD)"

echo "== next / allocate =="
out="$(aapp issue next 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q '#13' && [ "$(git config aapp.issueId)" = "13" ]; then
  ok "test_next_peeks_without_claiming"
else
  bad "test_next_peeks_without_claiming" "rc=$rc out=$out"
fi

out="$(aapp issue allocate 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "#13" ] && [ "$(git config aapp.issueId)" = "14" ]; then
  ok "test_allocate_claims_and_advances"
else
  bad "test_allocate_claims_and_advances" "rc=$rc out=$out"
fi

git config aapp.issueId abc
out="$(aapp issue allocate 2>&1)"; rc1=$?
aapp issue next >/dev/null 2>&1; rc2=$?
if [ "$rc1" -ne 0 ] && [ "$rc2" -ne 0 ] && [ "$(git config aapp.issueId)" = "abc" ] && \
   echo "$out" | grep -qF "git config --unset aapp.issueId"; then
  ok "test_non_integer_counter_fails_closed"
else
  bad "test_non_integer_counter_fails_closed" "rc1=$rc1 rc2=$rc2"
fi
git config aapp.issueId 14

echo "== provider plugin =="
mkdir -p .agents/skills/aapp-issue
printf '#!/bin/sh\n[ "$AAPP_ACTION" = allocate ] && echo "#40"\n' > .agents/skills/aapp-issue/run
chmod +x .agents/skills/aapp-issue/run
out="$(aapp issue allocate 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "#40" ] && [ "$(git config aapp.issueId)" = "41" ]; then
  ok "test_provider_allocate_ratchets_counter"
else
  bad "test_provider_allocate_ratchets_counter" "rc=$rc out=$out counter=$(git config aapp.issueId)"
fi

printf '#!/bin/sh\nexit 1\n' > .agents/skills/aapp-issue/run
aapp issue allocate >/dev/null 2>&1; rc=$?
if [ "$rc" -ne 0 ] && [ "$(git config aapp.issueId)" = "41" ]; then
  ok "test_failing_provider_refuses_allocation"
else
  bad "test_failing_provider_refuses_allocation" "rc=$rc"
fi

echo "== close =="
out="$(aapp issue close 10 sha "$SHA" 2>&1)"; rc=$?
arow="$(grep -E '^\| #10 \|' .plans/done/000-issues-archive.md)"
if [ "$rc" -eq 0 ] && ! grep -qE '^\| #10 \|' .plans/ISSUES.md && \
   echo "$arow" | grep -qF "| \`$SHA\` | Direct fix (no plan): Escape the pipe. |" && \
   [ "$(grep -E '^\| #[0-9]' .plans/done/000-issues-archive.md | head -n 1 | cut -d'|' -f2 | tr -d ' ')" = "#10" ] && \
   ! grep -q '#10 ->' .plans/issues_road_map.md && \
   git -C .plans log -1 --format=%s | grep -qF 'issue(close): archive #10' && \
   [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_close_relocates_prunes_and_commits"
else
  bad "test_close_relocates_prunes_and_commits" "rc=$rc row=$arow log=$(git -C .plans log -1 --format=%s) status=$(git -C .plans status --porcelain)"
fi
if echo "$out" | grep -q 'plugin reported a failure'; then
  ok "test_close_plugin_failure_only_warns"
else
  bad "test_close_plugin_failure_only_warns" "out=$out"
fi
rm -rf .agents/skills/aapp-issue

aapp issue close 11 sha "$SHA" summary "Fixed a\|b and c|d" >/dev/null 2>&1; rc=$?
arow="$(grep -E '^\| #11 \|' .plans/done/000-issues-archive.md)"
if [ "$rc" -eq 0 ] && echo "$arow" | grep -qF 'Fixed a\|b and c\|d |' && ! grep -q '#11 ->' .plans/issues_road_map.md; then
  ok "test_close_summary_escapes_pipes"
else
  bad "test_close_summary_escapes_pipes" "rc=$rc row=$arow"
fi

out="$(aapp issue close '#10' 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q 'already archived' && \
   [ "$(grep -cE '^\| #10 \|' .plans/done/000-issues-archive.md)" -eq 1 ]; then
  ok "test_close_archived_is_idempotent"
else
  bad "test_close_archived_is_idempotent" "rc=$rc out=$out"
fi

aapp issue close 99 >/dev/null 2>&1; rc1=$?
aapp issue close 12 bogus >/dev/null 2>&1; rc2=$?
aapp issue close >/dev/null 2>&1; rc3=$?
if [ "$rc1" -ne 0 ] && [ "$rc2" -ne 0 ] && [ "$rc3" -ne 0 ] && grep -qE '^\| #12 \|' .plans/ISSUES.md; then
  ok "test_close_refuses_unknown_id_and_tokens"
else
  bad "test_close_refuses_unknown_id_and_tokens" "rc1=$rc1 rc2=$rc2 rc3=$rc3"
fi

echo "== list =="
for n in $(seq 20 44); do echo "- [ ] #$n -> Filler $n." >> .plans/issues_road_map.md; done
out="$(aapp issue list 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(echo "$out" | grep -c ' -> ')" -eq 20 ] && echo "$out" | tail -n 1 | grep -q '6 more (aapp issue list all)' && \
   echo "$out" | head -n 1 | grep -q '#12 ->'; then
  ok "test_list_default_cap_in_roadmap_order"
else
  bad "test_list_default_cap_in_roadmap_order" "rc=$rc out=$out"
fi
out1="$(aapp issue list 3 2>&1)"; out2="$(aapp issue list all 2>&1)"
aapp issue list -n >/dev/null 2>&1; rc=$?
if [ "$(echo "$out1" | grep -c ' -> ')" -eq 3 ] && [ "$(echo "$out2" | grep -c ' -> ')" -eq 26 ] && [ "$rc" -ne 0 ]; then
  ok "test_list_cap_tokens"
else
  bad "test_list_cap_tokens" "rc=$rc"
fi
git -C .plans checkout -q -- issues_road_map.md

echo "== done closes its target issue =="
id="P-$(git config aapp.planId)"
aapp draft close-twelve >/dev/null 2>&1
f="$(ls .plans/current/P"${id#P-}"-*.md)"
sed -i -E "s|src/path/to/file\.ext|src/twelve.py|g; /src\/path\/to\/new_file\.ext/d" "$f"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$f"
sed -i -E 's/^(\* \*\*Target Issue \/ Milestone:\*\*).*/\1 #12/' "$f"
sed -i -E "s/^\* \*\*Commits:\*\*.*/\* \*\*Commits:\*\* \`$SHA\` ($(git rev-parse --abbrev-ref HEAD))/" "$f"
git -C .plans commit -qam "prepare $id" >/dev/null 2>&1
aapp freeze-start "$id" >/dev/null 2>&1
aapp done "$id" >/dev/null 2>&1; rc=$?
arow="$(grep -E '^\| #12 \|' .plans/done/000-issues-archive.md)"
if [ "$rc" -eq 0 ] && ! grep -qE '^\| #12 \|' .plans/ISSUES.md && echo "$arow" | grep -qF "[$id](" && \
   ! grep -q '#12 ->' .plans/issues_road_map.md && [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_done_closes_target_issue"
else
  bad "test_done_closes_target_issue" "rc=$rc row=$arow"
fi

id="P-$(git config aapp.planId)"
aapp draft dangling-target >/dev/null 2>&1
f="$(ls .plans/current/P"${id#P-}"-*.md)"
sed -i -E "s|src/path/to/file\.ext|src/dangling.py|g; /src\/path\/to\/new_file\.ext/d" "$f"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$f"
sed -i -E 's/^(\* \*\*Target Issue \/ Milestone:\*\*).*/\1 #77/' "$f"
sed -i -E "s/^\* \*\*Commits:\*\*.*/\* \*\*Commits:\*\* \`$SHA\` ($(git rev-parse --abbrev-ref HEAD))/" "$f"
git -C .plans commit -qam "prepare $id" >/dev/null 2>&1
aapp freeze-start "$id" >/dev/null 2>&1
out="$(aapp done "$id" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && [ -f "$f" ] && echo "$out" | grep -q 'Target issue #77 is in neither'; then
  ok "test_done_refuses_dangling_target_issue"
else
  bad "test_done_refuses_dangling_target_issue" "rc=$rc"
fi

echo "== first use without a counter (config is not cloned) =="
# New project: init installs the template ledgers; the first issue is #1.
init_sandbox_project "$R/new"
cd "$R/new" || exit 1
git config --unset aapp.issueId 2>/dev/null
out1="$(aapp issue next 2>&1)"; out2="$(aapp issue allocate 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out1" | grep -q '#1$' && [ "$out2" = "#1" ] && [ "$(git config aapp.issueId)" = "2" ]; then
  ok "test_new_project_first_issue_is_1"
else
  bad "test_new_project_first_issue_is_1" "rc=$rc next=$out1 alloc=$out2"
fi

# Clone: ledgers arrive with real rows, the counter does not.
init_sandbox_project "$R/clone"
cd "$R/clone" || exit 1
cat > .plans/ISSUES.md <<'EOF'
| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #3 | `Low` | `CLI` | 2026-09-01 | `a.sh` | Open. | Fix. | 🟡 `Incubated` |
EOF
cat > .plans/done/000-issues-archive.md <<'EOF'
| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #7 | `Low` | `CLI` | 2026-08-01 | 2026-08-02 | `0000000` | Closed. |
EOF
git config --unset aapp.issueId 2>/dev/null
out1="$(aapp issue next 2>&1)"; unset_after_peek="$(git config --get aapp.issueId || echo unset)"
out2="$(aapp issue allocate 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out1" | grep -q '#8$' && [ "$unset_after_peek" = "unset" ] && \
   [ "$out2" = "#8" ] && [ "$(git config aapp.issueId)" = "9" ]; then
  ok "test_clone_first_allocate_continues_ledgers"
else
  bad "test_clone_first_allocate_continues_ledgers" "rc=$rc next=$out1 peek_left=$unset_after_peek alloc=$out2"
fi

# Remote-authority clone: no ledger files and no provider -> refuse, never #1.
rm -f .plans/ISSUES.md .plans/done/000-issues-archive.md
git config --unset aapp.issueId 2>/dev/null
out1="$(aapp issue next 2>&1)"; rc1=$?
out2="$(aapp issue allocate 2>&1)"; rc2=$?
if [ "$rc1" -ne 0 ] && [ "$rc2" -ne 0 ] && echo "$out2" | grep -q 'aapp-issue' && \
   [ -z "$(git config --get aapp.issueId)" ]; then
  ok "test_no_ledgers_without_provider_refuses"
else
  bad "test_no_ledgers_without_provider_refuses" "rc1=$rc1 rc2=$rc2 out=$out2"
fi

# Same clone once the team provider is installed: the provider issues the id.
mkdir -p .agents/skills/aapp-issue
printf '#!/bin/sh\n[ "$AAPP_ACTION" = allocate ] && echo "#120"\n' > .agents/skills/aapp-issue/run
chmod +x .agents/skills/aapp-issue/run
out="$(aapp issue allocate 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "#120" ]; then
  ok "test_no_ledgers_with_provider_allocates"
else
  bad "test_no_ledgers_with_provider_allocates" "rc=$rc out=$out"
fi

print_test_summary "$PASS" "$FAIL"
