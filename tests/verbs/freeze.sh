#!/usr/bin/env bash
# Tests: `aapp freeze` behaviour contract (lib/docs/verbs/freeze.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-48s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-48s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

# A project holding one drafted plan; prints the plan's ID. The template ships
# one unchecked §5 question and example Target Files.
init_sandbox_project "$R/p"
cd "$R/p" || exit 1
draft_plan() {
  local id; id="$(git config --get aapp.planId)"
  aapp draft "$1" >/dev/null 2>&1 || return 1
  echo "P-$id"
}
plan_file() { ls .plans/current/P"${1#P-}"-*.md; }
resolve_questions() { sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$1"; git -C .plans commit -qam "resolve questions" >/dev/null; }
status_of() { grep -m1 '^\* \*\*Status:\*\*' "$1"; }

echo "== refusals =="
id="$(draft_plan open-questions)"; f="$(plan_file "$id")"
before="$(cksum < "$f")"
aapp freeze "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ] && [ "$(cksum < "$f")" = "$before" ]; then ok "test_refuses_unresolved_questions"; else bad "test_refuses_unresolved_questions" "rc=$rc"; fi

id="$(draft_plan no-targets)"; f="$(plan_file "$id")"
resolve_questions "$f"
sed -i -E '/^### 📂 Target Files/,/^### 🛑 Out of Bounds/{/^- \[ \] `/d}' "$f"; git -C .plans commit -qam "drop targets" >/dev/null
before="$(cksum < "$f")"
aapp freeze "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ] && [ "$(cksum < "$f")" = "$before" ]; then ok "test_refuses_without_target_files"; else bad "test_refuses_without_target_files" "rc=$rc"; fi

aapp freeze P-999 >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ]; then ok "test_refuses_unknown_plan"; else bad "test_refuses_unknown_plan" "rc=$rc"; fi

echo "== happy path =="
id="$(draft_plan ready-plan)"; f="$(plan_file "$id")"
resolve_questions "$f"
aapp freeze "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && status_of "$f" | grep -q '🔷 Frozen' && \
   grep -q "Plan locked and frozen into 🔷 Frozen via freeze." "$f" && \
   awk '/^## /{s=$0} s ~ /Frozen/ && /ready-plan/ {found=1} END{exit !found}' .plans/state_matrix.md && \
   git -C .plans log -1 --format=%s | grep -qF "plan(freeze): lock blast radius and greenlight $id" && \
   [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_freezes_and_commits"
else
  bad "test_freezes_and_commits" "rc=$rc status=[$(status_of "$f")]"
fi

echo "== source status (#89) =="
# ready-plan is now Frozen: freezing it again must refuse and change nothing.
before="$(cksum < "$f")"
aapp freeze "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ] && [ "$(cksum < "$f")" = "$before" ]; then
  ok "test_refuses_non_incubator_plan"
else
  bad "test_refuses_non_incubator_plan" "rc=$rc"
fi

echo "== commit failure & lax mode (#81 / P-39) =="
# 1. test_human_freeze_commits_in_lax
aapp ai lax >/dev/null 2>&1
id_lax="$(draft_plan lax-plan)"
f_lax="$(plan_file "$id_lax")"
resolve_questions "$f_lax"
(
  unset AAPP_AGENT_NAME AAPP_AGENT_VENDOR AAPP_AGENT_MODEL
  aapp freeze "$id_lax" >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq 0 ] && status_of "$f_lax" | grep -q '🔷 Frozen'; then
    ok "test_human_freeze_commits_in_lax"
  else
    bad "test_human_freeze_commits_in_lax" "rc=$rc"
  fi
)

# 2. test_commit_failure_is_loud
id_fail="$(draft_plan loud-fail-plan)"
f_fail="$(plan_file "$id_fail")"
resolve_questions "$f_fail"
mkdir -p .plans/.githooks
cat << 'EOF' > .plans/.githooks/pre-commit
#!/bin/sh
if [ -f "$GIT_DIR/plans_fail_hook" ]; then
  echo "pre-commit hook refusing plans commit" >&2
  exit 1
fi
exit 0
EOF
chmod +x .plans/.githooks/pre-commit
git -C .plans config core.hooksPath .githooks
touch "$(git -C .plans rev-parse --git-dir)/plans_fail_hook"
out="$(aapp freeze "$id_fail" 2>&1)"; rc=$?
rm -f "$(git -C .plans rev-parse --git-dir)/plans_fail_hook"
git -C .plans config --unset core.hooksPath
if [ "$rc" -ne 0 ] && echo "$out" | grep -qiE '(refusing|failed|error)'; then
  ok "test_commit_failure_is_loud"
else
  bad "test_commit_failure_is_loud" "swallowed failure with rc=$rc out=$out"
fi

echo "== changelog declaration (P-48) =="
# freeze_with_changelog <slug> <field-line or ''>: rc of aapp freeze with that header field.
freeze_with_changelog() {
  local id f; id="$(draft_plan "$1")"; f="$(plan_file "$id")"
  if [ -n "$2" ]; then
    sed -i -E "s|^\* \*\*Changelog:\*\*.*|$2|" "$f"
  else
    sed -i -E '/^\* \*\*Changelog:\*\*/d' "$f"
  fi
  resolve_questions "$f"
  aapp freeze "$id" >/dev/null 2>&1; echo "$? $(status_of "$f" | grep -c Frozen)"
}
long="$(printf 'x%.0s' $(seq 1 320))"
r_missing="$(freeze_with_changelog cl-missing '')"
r_bad="$(freeze_with_changelog cl-bad '* **Changelog:** Shipped a thing')"
r_long="$(freeze_with_changelog cl-long "* **Changelog:** Added: $long")"
if [ "$r_missing" = "1 0" ] && [ "$r_bad" = "1 0" ] && [ "$r_long" = "1 0" ]; then
  ok "test_freeze_refuses_bad_changelog_declaration"
else
  bad "test_freeze_refuses_bad_changelog_declaration" "missing=$r_missing bad=$r_bad long=$r_long"
fi
r_ok="$(freeze_with_changelog cl-ok '* **Changelog:** Fixed: Parser handles empty input')"
if [ "$r_ok" = "0 1" ]; then ok "test_freeze_accepts_valid_changelog_declaration"; else bad "test_freeze_accepts_valid_changelog_declaration" "$r_ok"; fi

echo "== uncommitted plan edits (#107) =="
id="$(draft_plan uncommitted-edit)"; f="$(plan_file "$id")"
resolve_questions "$f"
echo "<!-- design edit not yet committed -->" >> "$f"
before="$(cksum < "$f")"; head0="$(git -C .plans rev-parse HEAD)"
out="$(aapp freeze "$id" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -qF "aapp refine" && [ "$(cksum < "$f")" = "$before" ] && \
   [ "$(git -C .plans rev-parse HEAD)" = "$head0" ] && ! status_of "$f" | grep -q '🔷 Frozen'; then
  ok "test_refuses_uncommitted_plan_edits"
else
  bad "test_refuses_uncommitted_plan_edits" "rc=$rc out=$out"
fi

print_test_summary "$PASS" "$FAIL"
