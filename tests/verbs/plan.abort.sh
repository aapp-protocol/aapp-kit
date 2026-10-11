#!/usr/bin/env bash
# Tests: `aapp plan abort` (P-69); a part of the plan suite
# (lib/docs/verbs/plan.md, P-68).
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-48s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-48s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

draft_plan() {
  local id; id="$(git config --get aapp.planId)"
  aapp draft "$@" >/dev/null 2>&1 || return 1
  echo "P-$id"
}
plan_file() { ls .plans/current/P"${1#P-}"-*.md; }
aborted_file() { ls .plans/aborted/P"${1#P-}"-*.md 2>/dev/null; }
# prepare <id> <slug>: one code target, questions resolved, committed.
prepare() {
  local f; f="$(plan_file "$1")"
  sed -i -E "s|src/path/to/file\.ext|src/$2.sh|g; /src\/path\/to\/new_file\.ext/d; s/^\* \[ \] \*\*Question/* [x] **Question/" "$f"
  git -C .plans commit -qam "prepare $1" >/dev/null
}
buffer() { cat "$(git rev-parse --git-path aapp_active_plan)" 2>/dev/null; }
LEDGER=".plans/aborted/000-aborted-ledger.md"
today="$(date +%Y-%m-%d)"

echo "== drafts and frozen plans =="
init_sandbox_project "$R/s"
cd "$R/s" || exit 1
git config aapp.issueId 30; git config aapp.issueFixWait 0
cat > .plans/ISSUES.md <<'EOF'
# Issues

| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #7 | `High` | `CORE` | 2026-10-07 | `a.sh` | Needs a plan. |  | 🟡 `Incubated` |
EOF
git -C .plans add ISSUES.md >/dev/null 2>&1; git -C .plans commit -qm "fixture" >/dev/null 2>&1

a="$(draft_plan ab-draft)"; af="$(plan_file "$a")"; ab="$(basename "$af")"
had_ledger=0; [ -f "$LEDGER" ] && had_ledger=1
out="$(aapp plan abort "$a" reason "Wrong | approach" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$af" ] && [ -f ".plans/aborted/$ab" ] && \
   grep -qxF "* **Status:** ❌ Aborted" ".plans/aborted/$ab" && \
   grep -qxF "* **Aborted:** $today | **Reason:** Wrong | approach" ".plans/aborted/$ab" && \
   grep -qF "* **$today:** Plan aborted: Wrong | approach" ".plans/aborted/$ab" && \
   ! grep -qF "$ab" .plans/state_matrix.md && [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_abort_draft_moves_to_aborted_and_cleans_matrix"
else
  bad "test_abort_draft_moves_to_aborted_and_cleans_matrix" "rc=$rc out=$out"
fi
if [ "$had_ledger" -eq 0 ] && grep -qxF "| Date Aborted | Plan ID | Plan File | Target Issue / Milestone | Reason | Commits |" "$LEDGER" 2>/dev/null && \
   grep -qF "| $today | \`$a\` | [\`$ab\`]($ab) |" "$LEDGER" && grep -F "\`$a\`" "$LEDGER" | grep -qF 'Wrong \| approach | none |'; then
  ok "test_abort_writes_ledger_row"
else
  bad "test_abort_writes_ledger_row" "ledger=$(cat "$LEDGER" 2>&1)"
fi

b="$(draft_plan ab-frozen)"; prepare "$b" ab-frozen; bb="$(basename "$(plan_file "$b")")"
aapp freeze "$b" >/dev/null 2>&1
out="$(aapp plan abort "$b" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -f ".plans/aborted/$bb" ] && grep -qF "**Reason:** Abandoned" ".plans/aborted/$bb" && \
   [ "$(git -C .plans log -1 --format=%s)" = "plan(abort): archive $b to aborted/" ] && \
   git -C .plans show --no-renames --name-only --format= HEAD | grep -qxF "aborted/$bb" && \
   git -C .plans show --no-renames --name-only --format= HEAD | grep -qxF "current/$bb" && [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_abort_frozen_plan"
else
  bad "test_abort_frozen_plan" "rc=$rc out=$out subj=$(git -C .plans log -1 --format=%s)"
fi

head0="$(git -C .plans rev-parse HEAD)"
out="$(aapp plan abort "$a" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qi "not found" && [ "$(git -C .plans rev-parse HEAD)" = "$head0" ]; then
  ok "test_abort_refuses_archived_plan"
else
  bad "test_abort_refuses_archived_plan" "rc=$rc out=$out"
fi

printf '# 🩹 Fix #21\n* **Status:** ⚡ In Development\n* **Commits:** none\n' > .plans/current/fix-21.md
git -C .plans add current/fix-21.md >/dev/null 2>&1; git -C .plans commit -qm "mini fixture" >/dev/null 2>&1
out="$(aapp plan abort fix-21 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "aapp issue fix 21 abort" && [ -f .plans/current/fix-21.md ]; then
  ok "test_abort_refuses_mini_plan"
else
  bad "test_abort_refuses_mini_plan" "rc=$rc out=$out"
fi
git -C .plans rm -q current/fix-21.md >/dev/null 2>&1; git -C .plans commit -qm "drop mini fixture" >/dev/null 2>&1

echo "== single checkout: commits, buffer =="
c="$(draft_plan ab-single)"; prepare "$c" ab-single
aapp freeze-start "$c" >/dev/null 2>&1
mkdir -p src && echo "v=1" > src/ab-single.sh && git add src/ab-single.sh && aapp commit "feat: ab-single" >/dev/null 2>&1
csha="$(sed -nE "s/^\* \*\*Commits:\*\*[[:space:]]*\`([0-9a-f]+)\`.*/\1/p" "$(plan_file "$c")")"
buf0="$(buffer)"
out="$(aapp plan abort "$c" reason "Pivot" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -n "$csha" ] && git merge-base --is-ancestor "$csha" HEAD && [ -f src/ab-single.sh ] && \
   echo "$out" | grep -qF "$csha" && grep -F "\`$c\`" "$LEDGER" | grep -qF "\`$csha\`"; then
  ok "test_abort_single_checkout_keeps_commits"
else
  bad "test_abort_single_checkout_keeps_commits" "rc=$rc sha=$csha out=$out"
fi
if [ "$buf0" = "$c" ] && [ -z "$(buffer)" ]; then
  ok "test_abort_clears_buffers"
else
  bad "test_abort_clears_buffers" "before=$buf0 after=$(buffer)"
fi

echo "== issues =="
d="$(draft_plan ab-promoted issue 7)"; db="$(basename "$(plan_file "$d")")"
out="$(aapp plan abort "$d" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -qF "| [$d](aborted/$db) | 🟡 \`Incubated\` |" .plans/ISSUES.md && \
   [ -z "$(git -C .plans status --porcelain)" ] && git -C .plans show --name-only --format= HEAD | grep -qxF "ISSUES.md"; then
  ok "test_abort_target_issue_incubated_with_aborted_link"
else
  bad "test_abort_target_issue_incubated_with_aborted_link" "rc=$rc out=$out row=$(grep '^| #7 |' .plans/ISSUES.md)"
fi

e="$(draft_plan ab-blocked)"; prepare "$e" ab-blocked; eb="$(basename "$(plan_file "$e")")"
aapp freeze-start "$e" >/dev/null 2>&1
mkdir -p src && echo "v=1" > src/ab-blocked.sh && git add src/ab-blocked.sh && aapp commit "feat: ab-blocked" >/dev/null 2>&1
echo "v=2" > src/ab-blocked.sh
aapp issue hotfix "Parser crashes" file src/ab-blocked.sh >/dev/null 2>&1
printf -- '- [ ] #7 -> see [the plan](current/%s)\n' "$eb" >> .plans/issues_road_map.md
git -C .plans commit -qam "road-map link fixture" >/dev/null 2>&1
STASH="$(git rev-parse --git-path aapp_hotfix_stash)"
stash0="$(grep -c '#30' "$STASH" 2>/dev/null)"
out="$(aapp plan abort "$e" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -qF "| blocks [$e](aborted/$eb) |" .plans/ISSUES.md && \
   grep -qF "](aborted/$eb)" .plans/issues_road_map.md && ! grep -qF "current/$eb" .plans/ISSUES.md .plans/issues_road_map.md; then
  ok "test_abort_relinks_other_issue_rows"
else
  bad "test_abort_relinks_other_issue_rows" "rc=$rc out=$out row=$(grep '^| #30 |' .plans/ISSUES.md)"
fi
if [ "$rc" -eq 0 ] && [ "$stash0" = "1" ] && ! grep -q '#30' "$STASH" 2>/dev/null && grep -q '^| #30 |' .plans/ISSUES.md && \
   git stash list | grep -qF "aapp-hotfix:$e:#30" && echo "$out" | grep -qF "stash"; then
  ok "test_abort_blocked_plan_drops_stash_record"
else
  bad "test_abort_blocked_plan_drops_stash_record" "rc=$rc stash0=$stash0 buf=$(cat "$STASH" 2>&1) out=$out"
fi

echo "== post-abort hook =="
mkdir -p .agents/hooks .agents/skills/aapp-hooks
printf '#!/usr/bin/env bash\ncat > "%s/payload"\n' "$R" > .agents/hooks/rec.sh
chmod +x .agents/hooks/rec.sh
aapp hook-hash .agents/hooks/rec.sh post-abort 20 notify 2>/dev/null | grep "^post-abort" > .agents/skills/aapp-hooks/registry.tsv
h="$(draft_plan ab-hook)"; hb="$(basename "$(plan_file "$h")")"
out="$(aapp plan abort "$h" reason "Hooked" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -qF "\"plan_id\": \"$h\"" "$R/payload" 2>/dev/null && grep -qF '"reason": "Hooked"' "$R/payload" && \
   grep -qF "\"plan_file\": \"aborted/$hb\"" "$R/payload"; then
  ok "test_abort_dispatches_post_abort"
else
  bad "test_abort_dispatches_post_abort" "rc=$rc payload=$(cat "$R/payload" 2>&1) out=$out"
fi

echo "== plan worktrees =="
init_sandbox_project "$R/w"
cd "$R/w" || exit 1
printf '%s\n' '.env' >> .gitignore
git add -A && git commit -qm "track init files" --no-verify
git branch develop
git config aapp.planWorktrees on
git config aapp.commitMode microcommits
git config aapp.integrate ff
# wt_started <slug> [group <id>]: a plan started into its worktree with one commit; prints its id.
wt_started() {
  local id n slug="$1"
  id="$(draft_plan "$@")"; n="${id#P-}"
  prepare "$id" "$slug"
  aapp freeze-start "$id" >/dev/null 2>&1
  ( cd "$R/w/.workspace/P$n" && mkdir -p src && echo "v=1" > "src/$slug.sh" && git add "src/$slug.sh" && aapp commit "feat: $slug" >/dev/null 2>&1 )
  echo "$id"
}
wt_of() { echo "$R/w/.workspace/P${1#P-}"; }
has_branch() { git show-ref --verify --quiet "refs/heads/$1"; }

wa="$(wt_started wa)"; waf="$(plan_file "$wa")"
echo "v=2" > "$(wt_of "$wa")/src/wa.sh"
out1="$(aapp plan abort "$wa" 2>&1)"; rc1=$?
git -C "$(wt_of "$wa")" checkout -q -- src/wa.sh; echo "new" > "$(wt_of "$wa")/untracked.txt"
out2="$(aapp plan abort "$wa" 2>&1)"; rc2=$?
kept=0; [ -f "$waf" ] && [ -d "$(wt_of "$wa")" ] && has_branch "plan/P${wa#P-}-wa" && kept=1
out3="$(aapp plan abort "$wa" force 2>&1)"; rc3=$?
if [ "$rc1" -ne 0 ] && echo "$out1" | grep -qF "src/wa.sh" && [ "$rc2" -ne 0 ] && echo "$out2" | grep -qF "untracked.txt" && \
   [ "$kept" -eq 1 ] && [ "$rc3" -eq 0 ] && [ ! -d "$(wt_of "$wa")" ] && [ -n "$(aborted_file "$wa")" ]; then
  ok "test_abort_refuses_dirty_worktree_without_force"
else
  bad "test_abort_refuses_dirty_worktree_without_force" "rc=$rc1/$rc2/$rc3 kept=$kept out=$out1 | $out2 | $out3"
fi

wb="$(wt_started wb)"; wbr="plan/P${wb#P-}-wb"; wbsha="$(git rev-parse --short "$wbr")"
out="$(aapp plan abort "$wb" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ ! -d "$(wt_of "$wb")" ] && ! has_branch "$wbr" && ! git worktree list | grep -qF "$(wt_of "$wb")" && \
   echo "$out" | grep -qF "$wbr" && echo "$out" | grep -qF "$wbsha" && [ -n "$(aborted_file "$wb")" ]; then
  ok "test_abort_removes_worktree_and_branch"
else
  bad "test_abort_removes_worktree_and_branch" "rc=$rc out=$out"
fi

wc_="$(wt_started wc)"; wcr="plan/P${wc_#P-}-wc"
out="$(aapp plan abort "$wc_" keep-branch 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ ! -d "$(wt_of "$wc_")" ] && has_branch "$wcr" && echo "$out" | grep -qF "preserved"; then
  ok "test_abort_keep_branch_preserves_ref"
else
  bad "test_abort_keep_branch_preserves_ref" "rc=$rc out=$out"
fi

wd="$(wt_started wd)"; wdf="$(plan_file "$wd")"
echo "SECRET=1" > "$(wt_of "$wd")/.env"
out1="$(aapp plan abort "$wd" 2>&1)"; rc1=$?
kept=0; [ -f "$wdf" ] && [ -f "$(wt_of "$wd")/.env" ] && kept=1
git config aapp.quarantineIgnored true
out2="$(aapp plan abort "$wd" 2>&1)"; rc2=$?
git config aapp.quarantineIgnored false
qdir="$(cd "$(git rev-parse --git-common-dir)" && pwd)/aapp_quarantine/$wd"
if [ "$rc1" -ne 0 ] && echo "$out1" | grep -qF ".env" && echo "$out1" | grep -qF "force-cleanup" && [ "$kept" -eq 1 ] && \
   [ "$rc2" -eq 0 ] && [ ! -d "$(wt_of "$wd")" ] && [ "$(cat "$qdir/.env" 2>/dev/null)" = "SECRET=1" ]; then
  ok "test_abort_refuses_sensitive_ignored_files"
else
  bad "test_abort_refuses_sensitive_ignored_files" "rc=$rc1/$rc2 kept=$kept out=$out1 | $out2"
fi

we="$(wt_started we)"; wef="$(plan_file "$we")"; wer="plan/P${we#P-}-we"
cd "$(wt_of "$we")" || exit 1
out="$(aapp plan abort "$we" 2>&1)"; rc=$?
cd "$R/w" || exit 1
if [ "$rc" -ne 0 ] && [ -f "$wef" ] && [ -d "$(wt_of "$we")" ] && echo "$out" | grep -qF "$R/w"; then
  ok "test_abort_refuses_inside_plan_worktree"
else
  bad "test_abort_refuses_inside_plan_worktree" "rc=$rc out=$out"
fi

st0="$(git -C .plans status --porcelain)"; led0="$(cksum < "$LEDGER")"
sm0="$(cksum < .plans/state_matrix.md)"; iss0="$(cksum < .plans/ISSUES.md)"; pl0="$(cksum < "$wef")"
lock="$(git -C .plans rev-parse --git-path index.lock)"; case "$lock" in /*) ;; *) lock=".plans/$lock" ;; esac
touch "$lock"
out="$(aapp plan abort "$we" 2>&1)"; rc=$?
rm -f "$lock"
if [ "$rc" -ne 0 ] && [ -f "$wef" ] && [ "$(cksum < "$wef")" = "$pl0" ] && [ -z "$(aborted_file "$we")" ] && \
   [ "$(cksum < "$LEDGER")" = "$led0" ] && [ "$(cksum < .plans/state_matrix.md)" = "$sm0" ] && \
   [ "$(cksum < .plans/ISSUES.md)" = "$iss0" ] && [ "$(git -C .plans status --porcelain)" = "$st0" ] && \
   [ -d "$(wt_of "$we")" ] && has_branch "$wer"; then
  ok "test_abort_commit_failure_restores"
else
  bad "test_abort_commit_failure_restores" "rc=$rc out=$out status=$(git -C .plans status --porcelain | tr '\n' ' ')"
fi
aapp plan abort "$we" >/dev/null 2>&1

echo "== groups =="
# started_group <slug>: a group plan started on feature/<slug> from develop; prints its id.
started_group() {
  local id; id="$(draft_plan "$1" group)"
  sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$(plan_file "$id")"
  git -C .plans commit -qam "prepare $id" >/dev/null
  aapp freeze "$id" >/dev/null 2>&1; aapp start "$id" >/dev/null 2>&1
  echo "$id"
}
members_of() { sed -nE 's/^\* \*\*Members:\*\*[[:space:]]*//p' "$1"; }

g="$(started_group grp-a)"; gf="$(plan_file "$g")"; gb="$(basename "$gf")"
m1="$(draft_plan mem-one group "$g")"
listed=0; members_of "$gf" | grep -qF "$m1" && listed=1
out="$(aapp plan abort "$m1" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$listed" -eq 1 ] && ! members_of "$gf" | grep -qF "$m1" && [ -n "$(aborted_file "$m1")" ] && \
   [ -z "$(git -C .plans status --porcelain)" ] && git -C .plans show --name-only --format= HEAD | grep -qxF "current/$gb"; then
  ok "test_abort_group_member_unlinked"
else
  bad "test_abort_group_member_unlinked" "rc=$rc listed=$listed members=$(members_of "$gf") out=$out"
fi

m2="$(wt_started mem-two group "$g")"; fb0="$(git rev-parse feature/grp-a)"
commits2="$(sed -nE 's/^\* \*\*Commits:\*\*[[:space:]]*//p' "$(plan_file "$m2")")"
out="$(aapp plan abort "$m2" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$commits2" != "none" ] && [ ! -d "$(wt_of "$m2")" ] && ! has_branch "plan/P${m2#P-}-mem-two" && \
   [ "$(git rev-parse feature/grp-a)" = "$fb0" ] && ! members_of "$gf" | grep -qF "$m2" && [ -f "$gf" ]; then
  ok "test_abort_group_member_with_commits"
else
  bad "test_abort_group_member_with_commits" "rc=$rc commits=$commits2 out=$out"
fi

m3="$(wt_started mem-three group "$g")"
aapp done "$m3" >/dev/null 2>&1
m4="$(wt_started mem-four group "$g")"; m4f="$(plan_file "$m4")"
m5="$(draft_plan mem-five group "$g")"
fbsha="$(git rev-parse --short feature/grp-a)"; head0="$(git -C .plans rev-parse HEAD)"
out="$(aapp plan abort "$g" </dev/null 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "$m4" && echo "$out" | grep -qF "$m5" && echo "$out" | grep -qF "$m3" && \
   echo "$out" | grep -qF "feature/grp-a" && echo "$out" | grep -qF "$fbsha" && echo "$out" | grep -qF "confirm" && \
   [ -f "$gf" ] && [ -f "$m4f" ] && has_branch feature/grp-a && [ -d "$(wt_of "$m4")" ] && \
   [ "$(git -C .plans rev-parse HEAD)" = "$head0" ] && [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_abort_group_needs_confirm"
else
  bad "test_abort_group_needs_confirm" "rc=$rc out=$out"
fi

out="$(aapp plan abort "$g" reason "Dropped" confirm </dev/null 2>&1)"; rc=$?
names="$(git -C .plans show --name-only --format= HEAD)"
if [ "$rc" -eq 0 ] && [ -n "$(aborted_file "$g")" ] && [ -n "$(aborted_file "$m4")" ] && [ -n "$(aborted_file "$m5")" ] && \
   [ "$(git -C .plans log -1 --format=%s)" = "plan(abort): archive group $g to aborted/" ] && \
   echo "$names" | grep -qxF "aborted/$gb" && echo "$names" | grep -qxF "aborted/$(basename "$m4f")" && \
   grep -qF "\`$g\`" "$LEDGER" && grep -qF "\`$m4\`" "$LEDGER" && grep -qF "\`$m5\`" "$LEDGER" && \
   grep -F "\`$m4\`" "$LEDGER" | grep -qF "Group $g aborted: Dropped" && [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_abort_group_aborts_open_members"
else
  bad "test_abort_group_aborts_open_members" "rc=$rc out=$out subj=$(git -C .plans log -1 --format=%s)"
fi
if [ "$rc" -eq 0 ] && ls .plans/done/P"${m3#P-}"-*.md >/dev/null 2>&1 && [ -z "$(aborted_file "$m3")" ] && echo "$out" | grep -qF "$m3"; then
  ok "test_abort_group_lists_archived_members"
else
  bad "test_abort_group_lists_archived_members" "rc=$rc out=$out"
fi

g2="$(started_group grp-b)"
m6="$(wt_started mem-six group "$g2")"
out2="$(aapp plan abort "$g2" keep-branch confirm </dev/null 2>&1)"; rc2=$?
if [ "$rc" -eq 0 ] && ! has_branch feature/grp-a && ! has_branch "plan/P${m4#P-}-mem-four" && [ ! -d "$(wt_of "$m4")" ] && \
   [ "$rc2" -eq 0 ] && has_branch feature/grp-b && has_branch "plan/P${m6#P-}-mem-six" && [ ! -d "$(wt_of "$m6")" ]; then
  ok "test_abort_group_removes_feature_branch"
else
  bad "test_abort_group_removes_feature_branch" "rc=$rc/$rc2 out=$out | $out2"
fi

print_test_summary "$PASS" "$FAIL"
