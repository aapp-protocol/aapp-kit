#!/usr/bin/env bash
# Tests: `aapp done` behaviour contract (lib/docs/verbs/done.md)
# Part: done.worktree.sh (plans with their own worktree).
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-48s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-48s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1
git config aapp.commitMode microcommits   # fixtures record a commit, then make raw commits and amends (P-51)
# The Target Issue the plans below name must exist: done refuses a dangling one (P-32).
sed -i '/^| #2 |/a | #42 | `Low` | `CORE` | 2026-09-01 | `src/x.py` | Fixture issue. | Fix it. | 🔵 `Planned` |' .plans/ISSUES.md
git -C .plans commit -qam "fixture issue #42" >/dev/null 2>&1
draft_plan() {
  local id; id="$(git config --get aapp.planId)"
  aapp draft "$1" >/dev/null 2>&1 || return 1
  echo "P-$id"
}
plan_file() { ls .plans/current/P"${1#P-}"-*.md; }
# An in-development plan with a named Target Issue.
started_plan() {
  local slug="$1"
  local id; id="$(draft_plan "$slug")"
  local f; f="$(plan_file "$id")"
  sed -i -E "s|src/path/to/file\.ext|src/${slug}.py|g; /src\/path\/to\/new_file\.ext/d" "$f"
  sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$f"
  sed -i -E 's/^(\* \*\*Target Issue \/ Milestone:\*\*).*/\1 #42/' "$f"
  local c_sha; c_sha="$(git rev-parse --short HEAD)"
  local c_br; c_br="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "develop")"
  [ "$c_br" = "HEAD" ] && c_br="develop"
  sed -i -E "s/^\* \*\*Commits:\*\*.*/\* \*\*Commits:\*\* \`$c_sha\` ($c_br)/" "$f"
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

echo "== plan-bound recorded commits (P-39) =="
# 1. test_refuses_empty_commit_list
id_empty="$(started_plan empty-commits)"
f_empty="$(plan_file "$id_empty")"
# Header has no commits
sed -i -E 's/^\* \*\*Commits:\*\*.*/\* \*\*Commits:\*\* none/' "$f_empty" 2>/dev/null || true
out="$(aapp done "$id_empty" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -qiE '(No commits|adopt)' && [ -f "$f_empty" ]; then
  ok "test_refuses_empty_commit_list"
else
  bad "test_refuses_empty_commit_list" "rc=$rc out=$out"
fi
aapp active clear >/dev/null 2>&1

# 2. test_ledger_uses_recorded_commit
id_rec="$(started_plan rec)"
f_rec="$(plan_file "$id_rec")"
mkdir -p src
echo "# rec" > src/rec.py; echo "- rec" >> CHANGELOG.md; git add src/rec.py CHANGELOG.md; git commit -qm "rec commit"
rec_sha="$(git rev-parse --short HEAD)"
# Write recorded commit to header
sed -i -E "s/^\* \*\*Commits:\*\*.*/\* \*\*Commits:\*\* \`$rec_sha\` (develop)/" "$f_rec"
# Make an unrelated commit later
echo "# other" > src/other.py; echo "- other" >> CHANGELOG.md; git add src/other.py CHANGELOG.md; SKIP_BLAST_RADIUS=1 git commit -qm "later unrelated commit"
aapp done "$id_rec" >/dev/null 2>&1; rc=$?
row_rec="$(ledger_row "$id_rec")"
if [ "$rc" -eq 0 ] && echo "$row_rec" | grep -qF "\`$rec_sha\`"; then
  ok "test_ledger_uses_recorded_commit"
else
  bad "test_ledger_uses_recorded_commit" "rc=$rc row=$row_rec"
fi

# 3. test_refuses_unreachable_commit
id_unreach="$(started_plan unreach)"
f_unreach="$(plan_file "$id_unreach")"
echo "# unreach code" > src/unreach.py; echo "- unreach" >> CHANGELOG.md; git add src/unreach.py CHANGELOG.md; git commit -qm "unreach commit"
unreach_sha="$(git rev-parse --short HEAD)"
sed -i -E "s/^\* \*\*Commits:\*\*.*/\* \*\*Commits:\*\* \`$unreach_sha\` (develop)/" "$f_unreach"
# Amend it away so unreach_sha is no longer in branch history. Hooks off: the
# post-rewrite hook would otherwise repair the record (P-54).
echo "# amend away" >> src/unreach.py; echo "- amend" >> CHANGELOG.md; git add src/unreach.py CHANGELOG.md; git -c core.hooksPath=/dev/null commit --amend -qm "amended commit"
out="$(aapp done "$id_unreach" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -qF "$unreach_sha" && [ -f "$f_unreach" ]; then
  ok "test_refuses_unreachable_commit"
else
  bad "test_refuses_unreachable_commit" "rc=$rc out=$out"
fi
aapp active clear >/dev/null 2>&1

# 4. test_accepts_commit_on_deleted_branch
id_delbr="$(started_plan temp)"
f_delbr="$(plan_file "$id_delbr")"
git checkout -qb feat/temp-branch
echo "# temp code" > src/temp.py; echo "- temp" >> CHANGELOG.md; git add src/temp.py CHANGELOG.md; git commit -qm "temp branch commit"
temp_sha="$(git rev-parse --short HEAD)"
sed -i -E "s/^\* \*\*Commits:\*\*.*/\* \*\*Commits:\*\* \`$temp_sha\` (feat\/temp-branch)/" "$f_delbr"
git checkout -q main 2>/dev/null || git checkout -q develop
# Merge temp branch into current branch, then delete temp branch
git merge -q --no-ff feat/temp-branch -m "merge temp"
git branch -D feat/temp-branch >/dev/null
aapp done "$id_delbr" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && [ -f ".plans/done/$(basename "$f_delbr")" ]; then
  ok "test_accepts_commit_on_deleted_branch"
else
  bad "test_accepts_commit_on_deleted_branch" "rc=$rc"
fi

# 5. test_detached_commit_needs_a_branch
id_det="$(started_plan det)"
f_det="$(plan_file "$id_det")"
git checkout -q --detach HEAD
echo "# det code" > src/det.py; echo "- det" >> CHANGELOG.md; git add src/det.py CHANGELOG.md; git commit -qm "det code"
det_sha="$(git rev-parse --short HEAD)"
sed -i -E "s/^\* \*\*Commits:\*\*.*/\* \*\*Commits:\*\* \`$det_sha\` (detached)/" "$f_det"
out="$(aapp done "$id_det" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -qF "$det_sha"; then
  # Now attach it to a branch
  git branch feat/contained-det
  aapp done "$id_det" >/dev/null 2>&1; rc2=$?
  if [ "$rc2" -eq 0 ] && [ -f ".plans/done/$(basename "$f_det")" ]; then
    ok "test_detached_commit_needs_a_branch"
  else
    bad "test_detached_commit_needs_a_branch" "rc2=$rc2 after branch creation"
  fi
else
  bad "test_detached_commit_needs_a_branch" "rc=$rc expected failure on detached"
fi
git checkout -q main 2>/dev/null || git checkout -q develop

# 6. test_commit_takes_only_its_paths
id_path="$(started_plan path)"
f_path="$(plan_file "$id_path")"
echo "# path" > src/path.py; echo "- path" >> CHANGELOG.md; git add src/path.py CHANGELOG.md; git commit -qm "path code"
p_sha="$(git rev-parse --short HEAD)"
sed -i -E "s/^\* \*\*Commits:\*\*.*/\* \*\*Commits:\*\* \`$p_sha\` (develop)/" "$f_path"
# Stage unrelated file in .plans
echo "staged outside" > .plans/staged_outside.txt
git -C .plans add staged_outside.txt
aapp done "$id_path" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && git -C .plans diff --cached --name-only | grep -q "staged_outside.txt"; then
  ok "test_commit_takes_only_its_paths"
else
  bad "test_commit_takes_only_its_paths" "rc=$rc staged_outside was swept into done commit"
fi
git -C .plans reset -q HEAD staged_outside.txt; rm -f .plans/staged_outside.txt

# 7. test_pre_done_veto_blocks_archive
id_veto="$(started_plan veto)"
f_veto="$(plan_file "$id_veto")"
echo "# veto code" > src/veto.py; echo "- veto" >> CHANGELOG.md; git add src/veto.py CHANGELOG.md; git commit -qm "veto code"
v_sha="$(git rev-parse --short HEAD)"
sed -i -E "s/^\* \*\*Commits:\*\*.*/\* \*\*Commits:\*\* \`$v_sha\` (develop)/" "$f_veto"
# Register a pre-done hook that fails in protected registry
mkdir -p .agents/hooks .agents/skills/aapp-hooks
cat << 'EOF' > .agents/hooks/veto_hook.sh
#!/bin/sh
echo "vetoing done for $1" >&2
exit 1
EOF
chmod +x .agents/hooks/veto_hook.sh
v_hash="$(sha256sum .agents/hooks/veto_hook.sh | awk '{print $1}')"
printf "pre-done\t.agents/hooks/veto_hook.sh\tsha256:%s\t10\tgate\n" "$v_hash" >> .agents/skills/aapp-hooks/registry.tsv
out="$(aapp done "$id_veto" 2>&1)"; rc=$?
sed -i '/veto_hook\.sh/d' .agents/skills/aapp-hooks/registry.tsv
if [ "$rc" -eq 1 ] && [ -f "$f_veto" ] && [ ! -f ".plans/done/$(basename "$f_veto")" ]; then
  ok "test_pre_done_veto_blocks_archive"
else
  bad "test_pre_done_veto_blocks_archive" "rc=$rc out=$out"
fi

echo "== link repair (P-50) =="
lid="$(started_plan relink-me)"; lb="$(basename "$(plan_file "$lid")")"
sed -i "/^| #42 |/a | #43 | \`Low\` | \`CORE\` | 2026-09-01 | \`src/y.py\` | Linked elsewhere. | [$lid](current/$lb) | 🔵 \`Planned\` |" .plans/ISSUES.md
grep -q '^| #43 |' .plans/ISSUES.md || printf '| #43 | `Low` | `CORE` | 2026-09-01 | `src/y.py` | Linked elsewhere. | [%s](current/%s) | 🔵 `Planned` |\n' "$lid" "$lb" >> .plans/ISSUES.md
git -C .plans commit -qam "fixture issue #43" >/dev/null 2>&1
out="$(aapp done "$lid" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -qF "| [$lid](done/$lb) |" .plans/ISSUES.md && ! grep -qF "](current/$lb)" .plans/ISSUES.md && \
   git -C .plans log -1 --format=%s | grep -qF "plan(done): archive $lid" && \
   git -C .plans show --name-only --format= HEAD | grep -qx "ISSUES.md"; then
  ok "test_done_repairs_issue_links"
else
  bad "test_done_repairs_issue_links" "rc=$rc row=$(grep '^| #43 |' .plans/ISSUES.md)"
fi

echo "== a failed archive commit restores everything (#121) =="
cd "$R/p" || exit 1
rf="$(started_plan restore-me)"; rff="$(plan_file "$rf")"
st0="$(git -C .plans status --porcelain)"; led0="$(cksum < .plans/done/000-archive-ledger.md)"
sm0="$(cksum < .plans/state_matrix.md)"; iss0="$(cksum < .plans/ISSUES.md)"; pl0="$(cksum < "$rff")"
lock="$(git -C .plans rev-parse --git-path index.lock)"; case "$lock" in /*) ;; *) lock=".plans/$lock" ;; esac
touch "$lock"
out="$(aapp done "$rf" 2>&1)"; rc=$?
rm -f "$lock"
restored=0
[ "$rc" -ne 0 ] && [ -f "$rff" ] && [ "$(cksum < "$rff")" = "$pl0" ] && [ ! -f ".plans/done/$(basename "$rff")" ] && \
  [ "$(cksum < .plans/done/000-archive-ledger.md)" = "$led0" ] && [ "$(cksum < .plans/state_matrix.md)" = "$sm0" ] && \
  [ "$(cksum < .plans/ISSUES.md)" = "$iss0" ] && [ "$(git -C .plans status --porcelain)" = "$st0" ] && restored=1
out2="$(aapp done "$rf" 2>&1)"; rc2=$?
if [ "$restored" -eq 1 ] && [ "$rc2" -eq 0 ] && [ -f ".plans/done/$(basename "$rff")" ] && \
   git -C .plans log -1 --format=%s | grep -qF "plan(done): archive $rf"; then
  ok "test_failed_archive_commit_restores_and_retry_archives"
else
  bad "test_failed_archive_commit_restores_and_retry_archives" "rc=$rc/$rc2 restored=$restored out=$out | $out2 status=$(git -C .plans status --porcelain | tr '\n' ' ')"
fi

echo "== amendments are closed by the requester's done (P-129) =="
init_sandbox_project "$R/ga"
cd "$R/ga" || exit 1
git add -A && git commit -qm "track init files" --no-verify
git config aapp.planWorktrees on; git config aapp.commitMode microcommits
gid="P-$(git config aapp.planId)"; aapp draft ga group >/dev/null 2>&1; aid="P-$(( ${gid#P-} + 1 ))"
gfile="$(ls .plans/current/P"${gid#P-}"-ga.md)"; sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$gfile"
git -C .plans commit -qam "prep $gid" >/dev/null 2>&1
aapp freeze "$gid" >/dev/null 2>&1; aapp start "$gid" base "$(git rev-parse --abbrev-ref HEAD)" >/dev/null 2>&1
af="$(ls .plans/current/P"${aid#P-}"-*.md)"; fb="feature/ga"
# ga_member <slug>: a member freeze-started into its worktree, its own file committed; prints its id.
ga_member() {
  local id f; id="P-$(git config aapp.planId)"; aapp draft "$1" group "$gid" >/dev/null 2>&1
  f="$(ls .plans/current/P"${id#P-}"-"$1".md)"
  sed -i -E "s|src/path/to/file\.ext|src/$1.sh|g; /src\/path\/to\/new_file\.ext/d; s/^\* \[ \] \*\*Question/* [x] **Question/" "$f"
  git -C .plans commit -qam "prep $id" >/dev/null 2>&1; aapp freeze-start "$id" >/dev/null 2>&1
  ( cd "$R/ga/.workspace/P${id#P-}" && mkdir -p src && echo "v=1" > "src/$1.sh" && git add "src/$1.sh" && aapp commit "feat: $1" >/dev/null 2>&1 )
  echo "$id"
}
# ga_amend <member> <n> <file> <summary> [for <owner>]: requested, approved; committed as R<n> unless <n> is '-'.
ga_amend() {
  local m="$1" n="$2" p="$3" s="$4"; shift 4
  ( cd "$R/ga/.workspace/P${m#P-}" && aapp refine "$aid" request "$s" file "$p" "$@" >/dev/null 2>&1 )
  aapp refine "$aid" approve "$(grep -c '^- \*\*R[0-9]' "$af")" >/dev/null 2>&1
  [ "$n" = "-" ] && return 0
  ( cd "$R/ga/.workspace/P${m#P-}" && echo "a=$n" > "$p" && git add "$p" && aapp commit "feat: $s" amendment "$n" >/dev/null 2>&1 )
}
m1="$(ga_member ga-one)"
ga_amend "$m1" 1 src/own.sh "own helper"
ga_amend "$m1" - src/unused.sh "never used"
ga_amend "$m1" 3 src/shared.sh "shared" for "$gid"
( cd "$R/ga/.workspace/P${m1#P-}" && aapp refine "$aid" request "still pending" file src/pend.sh >/dev/null 2>&1 \
  && git rebase -q --autostash "$fb" >/dev/null 2>&1 )
r1=0; out1="$(aapp done "$m1" integrate ff 2>&1)" || r1=$?
s1="$(git log --format=%h --grep='^Amendment: R1$' "$fb" | head -n 1)"; s3="$(git log --format=%h --grep='^Amendment: R3$' "$fb" | head -n 1)"
d1="$(ls .plans/done/P"${m1#P-}"-*.md)"
if [ "$r1" -eq 0 ] && [ -n "$s1" ] && grep -qF "· own helper — closed · landed \`$s1\`" "$af" && grep -qF "· never used — closed · unused" "$af" && \
   grep -qF "· for $gid — closed · landed \`$s3\`" "$af" && grep -qF "· still pending — closed · withdrawn" "$af" && \
   grep -qF -- "- [x] \`src/own.sh\` -> R1 (by $m1)" "$d1" && grep -qF "· \`src/own.sh\` · own helper (by $m1, landed \`$s1\`)" "$d1" && \
   ! grep -qF "src/shared.sh" "$d1" && ! grep -m1 'Commits:' "$d1" | grep -qF "$s1"; then
  ok "test_done_closes_the_requests"
else
  bad "test_done_closes_the_requests" "r1=$r1 out1=$out1 s1=$s1 s3=$s3"
fi
# A squash integration: the requester's own amendment is recorded with the squash commit.
m2="$(ga_member ga-two)"
ga_amend "$m2" 5 src/own2.sh "own two"
r2=0; out2="$(aapp done "$m2" integrate squash 2>&1)" || r2=$?
d2="$(ls .plans/done/P"${m2#P-}"-*.md)"; s2="$(git log -1 --format=%h "$fb")"
if [ "$r2" -eq 0 ] && grep -qF "· own two — closed · landed \`$s2\`" "$af" && grep -qF "· own two (by $m2, landed \`$s2\`)" "$d2" && \
   git show --name-only --format= "$fb" | grep -qx "src/own2.sh"; then
  ok "test_done_records_own_amendment_in_the_squash"
else
  bad "test_done_records_own_amendment_in_the_squash" "r2=$r2 out2=$out2 s2=$s2"
fi
cd "$R/p" || exit 1

print_test_summary "$PASS" "$FAIL"
