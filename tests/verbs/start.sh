#!/usr/bin/env bash
# Tests: `aapp start` behaviour contract (lib/docs/verbs/start.md)
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
freeze_plan() {
  sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$(plan_file "$1")"
  git -C .plans commit -qam "resolve questions" >/dev/null
  aapp freeze "$1" >/dev/null 2>&1
}
status_of() { grep -m1 '^\* \*\*Status:\*\*' "$1"; }
buffer() { cat "$(git rev-parse --git-path aapp_active_plan)" 2>/dev/null; }

echo "== refusals =="
id="$(draft_plan still-draft)"; f="$(plan_file "$id")"
before="$(cksum < "$f")"
aapp start "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 1 ] && [ "$(cksum < "$f")" = "$before" ]; then ok "test_refuses_unfrozen_plan"; else bad "test_refuses_unfrozen_plan" "rc=$rc"; fi

echo "== happy path =="
id="$(draft_plan first-plan)"; f="$(plan_file "$id")"
freeze_plan "$id"
aapp start "$id" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && status_of "$f" | grep -q '⚡ In Development' && [ "$(buffer)" = "$id" ] && \
   grep -q "Plan activated into ⚡ In Development via start." "$f" && \
   git -C .plans log -1 --format=%s | grep -qF "plan(start): activate $id into development" && \
   [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_activates_frozen_plan"
else
  bad "test_activates_frozen_plan" "rc=$rc buffer=[$(buffer)]"
fi

echo "== disjointness gate =="
# Every drafted plan inherits the template's example Target Files, so a second
# plan shares them with the one already in development.
id2="$(draft_plan second-plan)"; f2="$(plan_file "$id2")"
freeze_plan "$id2"
before="$(cksum < "$f2")"
out="$(aapp start "$id2" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -q "Activation Gate" && [ "$(cksum < "$f2")" = "$before" ] && [ "$(buffer)" = "$id" ]; then
  ok "test_refuses_shared_target"
else
  bad "test_refuses_shared_target" "rc=$rc"
fi

echo "== base recording & worktree confinement (P-39) =="
# 1. test_records_base_sha_and_branch
id_base="$(draft_plan base-plan)"
f_base="$(plan_file "$id_base")"
sed -i -E "s|src/path/to/file\.ext|src/base_test.py|g; /src\/path\/to\/new_file\.ext/d" "$f_base"
freeze_plan "$id_base"
head_sha="$(git rev-parse --short HEAD)"
head_br="$(git rev-parse --abbrev-ref HEAD)"
aapp start "$id_base" >/dev/null 2>&1
if grep -qF "* **Base:** \`$head_sha\` ($head_br)" "$f_base"; then
  ok "test_records_base_sha_and_branch"
else
  bad "test_records_base_sha_and_branch" "base not recorded: $(grep -F '**Base:**' "$f_base" 2>/dev/null)"
fi

# 2. test_restart_keeps_first_base
mkdir -p src
echo "# new code" > src/base_test.py; echo "- advance head" >> CHANGELOG.md; git add src/base_test.py CHANGELOG.md; git commit -qm "advance head"
aapp start "$id_base" >/dev/null 2>&1
if grep -qF "* **Base:** \`$head_sha\` ($head_br)" "$f_base"; then
  ok "test_restart_keeps_first_base"
else
  bad "test_restart_keeps_first_base" "base changed on re-run: $(grep -F '**Base:**' "$f_base" 2>/dev/null)"
fi

# 3. test_refuses_from_planning_worktree
id_pw="$(draft_plan pw-plan)"
f_pw="$(plan_file "$id_pw")"
freeze_plan "$id_pw"
(
  cd .plans || exit 1
  aapp start "$id_pw" >/dev/null 2>&1; echo $? > "$R/pw_rc"
)
if [ "$(cat "$R/pw_rc")" -eq 1 ] && status_of "$f_pw" | grep -q '🔷 Frozen'; then
  ok "test_refuses_from_planning_worktree"
else
  bad "test_refuses_from_planning_worktree" "rc=$(cat "$R/pw_rc")"
fi

# 4. test_refuses_plan_bound_in_other_worktree
git worktree add -b feat/start-wt "$R/start_wt" >/dev/null 2>&1
(
  cd "$R/start_wt" || exit 1
  # Bind id_base in start_wt
  aapp active "$id_base" >/dev/null 2>&1
)
out="$(aapp start "$id_base" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -qiE '(bound|worktree)'; then
  ok "test_refuses_plan_bound_in_other_worktree"
else
  bad "test_refuses_plan_bound_in_other_worktree" "rc=$rc out=$out"
fi

print_test_summary "$PASS" "$FAIL"
