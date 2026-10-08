#!/usr/bin/env bash
# Tests: plan branch integration on `aapp done` (P-55; contract lib/docs/verbs/done.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-58s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-58s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/ig"
cd "$R/ig" || exit 1
PRIM="$(git rev-parse --abbrev-ref HEAD)"
# Plan worktrees check out the branch: track what init wrote; ignore local env files.
printf '%s\n' '.env' >> .gitignore
git add -A && git commit -qm "track init files" --no-verify
git branch develop
git config aapp.planWorktrees on
git config aapp.commitMode microcommits
git config aapp.issueFixWait 0

# wt_plan <name> [files…]: freeze-start a plan into its worktree and commit one
# file there per extra argument (default: src/<name>.sh); prints the id.
wt_plan() {
  local name="$1" id f n wt
  id="P-$(git config aapp.planId)"; aapp draft "$name" >/dev/null 2>&1
  f="$(ls .plans/current/P"${id#P-}"-*.md)"; n="${id#P-}"
  sed -i -E "s|src/path/to/file\.ext|src/$name.sh|g; s|src/path/to/new_file\.ext|src/${name}_b.sh|g" "$f"
  sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$f"
  git -C .plans commit -qam "prep $id" >/dev/null 2>&1
  aapp freeze-start "$id" >/dev/null 2>&1
  wt="$R/ig-P$n"
  ( cd "$wt" && mkdir -p src && echo "v=1" > "src/$name.sh" && git add "src/$name.sh" && aapp commit "feat: $name" >/dev/null 2>&1 )
  echo "$id"
}
pfile() { ls .plans/current/P"${1#P-}"-*.md 2>/dev/null || ls .plans/done/P"${1#P-}"-*.md; }
pbranch() { echo "plan/P${1#P-}-$2"; }

echo "== seeded manual: archive only (Q1) =="
a="$(wt_plan alpha)"; dev0="$(git rev-parse develop)"
out="$(aapp done "$a" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(git config aapp.integrate)" = "manual" ] && [ "$(git rev-parse develop)" = "$dev0" ] && \
   [ -d "$R/ig-P${a#P-}" ] && ls .plans/done/P"${a#P-}"-*.md >/dev/null 2>&1 && echo "$out" | grep -qF "aapp done $a integrate"; then
  ok "test_manual_default_archives_without_integrating"
else
  bad "test_manual_default_archives_without_integrating" "rc=$rc out=$out"
fi

echo "== squash into the parent branch =="
git config aapp.integrate squash
s="$(wt_plan sq)"; sbr="$(pbranch "$s" sq)"
out="$(aapp done "$s" 2>&1)"; rc=$?
msg="$(git log -1 --format=%B develop)"
if [ "$rc" -eq 0 ] && git show develop:src/sq.sh >/dev/null 2>&1 && echo "$msg" | grep -qx "Plan-ID: $s" && \
   echo "$msg" | grep -qx "Plan-Parent: develop" && [ ! -d "$R/ig-P${s#P-}" ] && \
   ! git rev-parse --verify -q "$sbr" >/dev/null && [ "$(git rev-parse --abbrev-ref HEAD)" = "$PRIM" ] && \
   [ -z "$(git status --porcelain --untracked-files=no)" ]; then
  ok "test_squash_integrates_with_trailers_and_cleans_up"
else
  bad "test_squash_integrates_with_trailers_and_cleans_up" "rc=$rc out=$out msg=$msg"
fi

echo "== parent-branch fidelity (module branch) =="
git branch module/auth develop
git config aapp.devBranch "module/auth"
m="$(wt_plan mod)"
git config aapp.devBranch "develop"
dev1="$(git rev-parse develop)"
out="$(aapp done "$m" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && git show module/auth:src/mod.sh >/dev/null 2>&1 && [ "$(git rev-parse develop)" = "$dev1" ] && \
   git log -1 --format=%B module/auth | grep -qx "Plan-Parent: module/auth"; then
  ok "test_integrates_into_module_parent_not_develop"
else
  bad "test_integrates_into_module_parent_not_develop" "rc=$rc out=$out"
fi

echo "== fast-forward keeps microcommits =="
git config aapp.integrate ff
f_="$(wt_plan ffp)"; fbr="$(pbranch "$f_" ffp)"
( cd "$R/ig-P${f_#P-}" && echo "w=1" > src/ffp_b.sh && git add src/ffp_b.sh && aapp commit "feat: ffp two" >/dev/null 2>&1 )
tip="$(git rev-parse "$fbr")"
out="$(aapp done "$f_" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(git rev-parse develop)" = "$tip" ] && ! git rev-parse --verify -q "$fbr" >/dev/null && \
   [ ! -d "$R/ig-P${f_#P-}" ]; then
  ok "test_ff_keeps_microcommits_and_deletes_branch"
else
  bad "test_ff_keeps_microcommits_and_deletes_branch" "rc=$rc out=$out"
fi

echo "== pre-flight runs before the archive =="
git config aapp.integrate squash
b="$(wt_plan behind)"; bf="$(pfile "$b")"; h0="$(git -C .plans rev-parse HEAD)"
git checkout -q develop && echo "d=1" > moved.txt && git add moved.txt && git commit -qm "develop moves" --no-verify && git checkout -q "$PRIM"
out="$(aapp done "$b" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qi "rebase" && [ -f "$bf" ] && [ "$(git -C .plans rev-parse HEAD)" = "$h0" ]; then
  ok "test_preflight_failure_archives_nothing"
else
  bad "test_preflight_failure_archives_nothing" "rc=$rc out=$out"
fi
( cd "$R/ig-P${b#P-}" && git rebase -q develop >/dev/null 2>&1 )

printf '%s\n' '# 🩹 Issue Fix #99: x' '* **Plan ID:** #99' '* **Status:** ⚡ In Development' '* **Commits:** none' > .plans/current/fix-99.md
git -C .plans add current/fix-99.md && git -C .plans commit -qm "open mini" >/dev/null 2>&1
out="$(aapp done "$b" 2>&1)"; rc=$?
git -C .plans rm -q current/fix-99.md && git -C .plans commit -qm "close mini" >/dev/null 2>&1
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "#99" && [ -f "$bf" ]; then
  ok "test_open_mini_plan_refuses_with_wait_zero"
else
  bad "test_open_mini_plan_refuses_with_wait_zero" "rc=$rc out=$out"
fi

sed -i 's/^\* \*\*Status:\*\* ⚡ In Development$/&\n* **Emergency Hotfixes:** #1, #2, #3/' "$bf"
git -C .plans commit -qam "three hotfixes" >/dev/null 2>&1
out="$(aapp done "$b" 2>&1)"; rc1=$?
out2="$(aapp done "$b" integrate override-hotfix-cap 2>&1)"; rc2=$?
if [ "$rc1" -ne 0 ] && echo "$out" | grep -qF "override-hotfix-cap" && [ "$rc2" -eq 0 ] && git show develop:src/behind.sh >/dev/null 2>&1; then
  ok "test_hotfix_cap_vetoes_without_override"
else
  bad "test_hotfix_cap_vetoes_without_override" "rc=$rc1/$rc2 out=$out | $out2"
fi

echo "== ignored files: refuse cleanup, opt-in quarantine (Q2) =="
e="$(wt_plan envp)"; ewt="$R/ig-P${e#P-}"
echo "SECRET=1" > "$ewt/.env"
out="$(aapp done "$e" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && git show develop:src/envp.sh >/dev/null 2>&1 && [ -f "$ewt/.env" ] && echo "$out" | grep -qF ".env" && \
   echo "$out" | grep -qF "force-cleanup"; then
  ok "test_ignored_env_refuses_cleanup_keeps_integration"
else
  bad "test_ignored_env_refuses_cleanup_keeps_integration" "rc=$rc out=$out"
fi
git config aapp.quarantineIgnored true
dev2="$(git rev-parse develop)"
out="$(aapp done "$e" integrate 2>&1)"; rc=$?
qdir="$(git rev-parse --git-common-dir)/aapp_quarantine/$e"
if [ "$rc" -eq 0 ] && [ "$(git rev-parse develop)" = "$dev2" ] && [ ! -d "$ewt" ] && [ "$(cat "$qdir/.env" 2>/dev/null)" = "SECRET=1" ]; then
  ok "test_retry_on_archived_plan_quarantines_then_cleans"
else
  bad "test_retry_on_archived_plan_quarantines_then_cleans" "rc=$rc out=$out"
fi
git config aapp.quarantineIgnored false

echo "== tokens and plans without a worktree =="
n_="$(wt_plan noint)"; devn="$(git rev-parse develop)"
out="$(aapp done "$n_" no-integrate 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(git rev-parse develop)" = "$devn" ] && [ -d "$R/ig-P${n_#P-}" ]; then
  ok "test_no_integrate_token_archives_only"
else
  bad "test_no_integrate_token_archives_only" "rc=$rc out=$out"
fi
git config aapp.planWorktrees off
pl="P-$(git config aapp.planId)"; aapp draft plain >/dev/null 2>&1
plf="$(pfile "$pl")"
sed -i -E "s|src/path/to/file\.ext|src/plain.sh|g; /src\/path\/to\/new_file\.ext/d; s/^\* \[ \] \*\*Question/* [x] **Question/" "$plf"
git -C .plans commit -qam "prep plain" >/dev/null 2>&1
aapp freeze-start "$pl" >/dev/null 2>&1
# Single-checkout work happens on the development branch (branch protection).
git checkout -q develop
mkdir -p src && echo "p=1" > src/plain.sh && git add src/plain.sh && aapp commit "feat: plain" >/dev/null 2>&1
devp="$(git rev-parse develop)"; headp="$(git rev-parse HEAD)"
out="$(aapp done "$pl" 2>&1)"; rc=$?
heada="$(git rev-parse HEAD)"; git checkout -q "$PRIM"
if [ "$rc" -eq 0 ] && [ "$(git rev-parse develop)" = "$devp" ] && [ "$heada" = "$headp" ] && ! echo "$out" | grep -qi "integrat"; then
  ok "test_plan_without_worktree_never_integrated"
else
  bad "test_plan_without_worktree_never_integrated" "rc=$rc out=$out"
fi
git config aapp.planWorktrees on

echo "== on-integrate delegate (aapp.integrate = hook) =="
git config aapp.integrate hook
k="$(wt_plan hk)"; kf="$(pfile "$k")"
out="$(aapp done "$k" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "on-integrate" && [ -f "$kf" ]; then
  ok "test_hook_without_handler_refuses_before_archive"
else
  bad "test_hook_without_handler_refuses_before_archive" "rc=$rc out=$out"
fi
hd=".agents/skills/aapp-hooks"; mkdir -p "$hd"
printf '%s\n' '#!/usr/bin/env bash' 'p="$(cat)"' '[ -f "$AAPP_HOOK_FAIL" ] && exit 1' 'printf "%s\n" "$p" > "$AAPP_HOOK_OUT"' 'exit 0' > "$hd/integ.sh"
chmod +x "$hd/integ.sh"
aapp hook-hash "$hd/integ.sh" on-integrate 10 gate 2>/dev/null | grep "^on-integrate" > "$hd/registry.tsv"
export AAPP_HOOK_OUT="$R/integ.json" AAPP_HOOK_FAIL="$R/integ.fail"
touch "$AAPP_HOOK_FAIL"
devk="$(git rev-parse develop)"
out="$(aapp done "$k" 2>&1)"; rc1=$?
archived=0; ls .plans/done/P"${k#P-}"-*.md >/dev/null 2>&1 && archived=1
rm -f "$AAPP_HOOK_FAIL"
out2="$(aapp done "$k" integrate 2>&1)"; rc2=$?
if [ "$rc1" -ne 0 ] && [ "$archived" -eq 1 ] && [ "$rc2" -eq 0 ] && grep -qF "\"plan_branch\": \"$(pbranch "$k" hk)\"" "$R/integ.json" && \
   grep -qF '"target_branch": "develop"' "$R/integ.json" && [ "$(git rev-parse develop)" = "$devk" ] && [ -d "$R/ig-P${k#P-}" ]; then
  ok "test_hook_delegate_replaces_builtin_and_retries"
else
  bad "test_hook_delegate_replaces_builtin_and_retries" "rc=$rc1/$rc2 archived=$archived out=$out | $out2 json=$(cat "$R/integ.json" 2>/dev/null)"
fi
rm -f "$hd/registry.tsv" "$hd/integ.sh"

print_test_summary "$PASS" "$FAIL"
