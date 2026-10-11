#!/usr/bin/env bash
# Tests: `aapp start` plan worktrees and base-branch resolution (P-54); a part of
# the start suite (lib/docs/verbs/start.md, P-68).
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-48s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-48s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

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
# targets_only <id> <code-file>: the plan targets one code file plus the shared docs.
targets_only() {
  local f; f="$(plan_file "$1")"
  sed -i -E "s|src/path/to/file\.ext|$2|; /src\/path\/to\/new_file\.ext/d" "$f"
  sed -i -E "s|^(- \[ \] \`$2\`.*)$|\1\n- [ ] \`CHANGELOG.md\` -> Record.\n- [ ] \`.agents/CODEMAP.md\` -> Map.|" "$f"
}

echo "== plan worktrees at start (P-54) =="
init_sandbox_project "$R/w"
cd "$R/w" || exit 1
prim="$(git rev-parse --abbrev-ref HEAD)"
git checkout -q -b develop && echo "d = 1" > dev.py && git add dev.py && git commit -qm "develop moves" --no-verify && git checkout -q "$prim"
dev_sha="$(git rev-parse --short develop)"
git config aapp.planWorktrees on
# wt_plan <code-file>: a frozen plan targeting one code file; prints its id.
wt_plan() { local id; id="$(draft_plan "wt-$1")"; targets_only "$id" "src/$1.py"; freeze_plan "$id"; echo "$id"; }
slug_of() { local b; b="$(basename "$(plan_file "$1")" .md)"; echo "${b#P${1#P-}-}"; }
pbuf() { cat "$(git rev-parse --git-path aapp_active_plan)" 2>/dev/null; }

wa="$(wt_plan alpha)"; na="${wa#P-}"; sa="$(slug_of "$wa")"; fa="$(plan_file "$wa")"
wpath="$R/w/.workspace/P$na"; wbr="plan/P$na-$sa"
out="$(aapp start "$wa" 2>&1)"; rc=$?
links_ok=1
for l in .githooks .agents .plans .claude; do
  [ -L "$wpath/$l" ] || links_ok=0
  case "$(readlink "$wpath/$l")" in /*|'') links_ok=0 ;; esac
  grep -qxF "/$l" "$(git rev-parse --git-common-dir)/info/exclude" || links_ok=0
done
grep -qxF "/.workspace" "$(git rev-parse --git-common-dir)/info/exclude" || links_ok=0
if [ "$rc" -eq 0 ] && [ -d "$wpath" ] && [ "$(git -C "$wpath" rev-parse --abbrev-ref HEAD)" = "$wbr" ] && \
   ! git -C "$wpath" rev-parse --abbrev-ref "$wbr@{upstream}" >/dev/null 2>&1 && \
   [ "$(git -C "$wpath" rev-parse --short HEAD)" = "$dev_sha" ] && [ "$links_ok" -eq 1 ] && \
   [ -z "$(git -C "$wpath" status --porcelain)" ] && \
   [ "$(cat "$(git -C "$wpath" rev-parse --git-path aapp_active_plan)")" = "$wa" ] && [ -z "$(pbuf)" ] && \
   grep -qxF "* **Worktree:** .workspace/P$na ($wbr)" "$fa" && grep -qxF "* **Base:** \`$dev_sha\` (develop)" "$fa" && \
   echo "$out" | grep -qF "$wpath" && status_of "$fa" | grep -q '⚡ In Development'; then
  ok "test_worktree_start_creates_branch_links_and_records"
else
  bad "test_worktree_start_creates_branch_links_and_records" "rc=$rc links=$links_ok out=$out $(grep -E 'Worktree|Base' "$fa" | tr '\n' ' ')"
fi
# The plan worktree is its own checkout; keep the primary free for the next tests.

wb="$(wt_plan beta)"; nb="${wb#P-}"; fb="$(plan_file "$wb")"
git branch "plan/P$nb-$(slug_of "$wb")"
before="$(cksum < "$fb")"
out="$(aapp start "$wb" 2>&1)"; rc1=$?
git branch -D "plan/P$nb-$(slug_of "$wb")" >/dev/null; mkdir -p "$R/w/.workspace/P$nb"
out2="$(aapp start "$wb" 2>&1)"; rc2=$?
rmdir "$R/w/.workspace/P$nb"
if [ "$rc1" -ne 0 ] && [ "$rc2" -ne 0 ] && echo "$out" | grep -qi "exists" && echo "$out2" | grep -qi "exists" && \
   [ "$(cksum < "$fb")" = "$before" ] && [ -z "$(pbuf)" ]; then
  ok "test_worktree_start_refuses_existing_branch_or_path"
else
  bad "test_worktree_start_refuses_existing_branch_or_path" "rc=$rc1/$rc2 out=$out | $out2"
fi

echo "scratch" > scratch.txt
out="$(aapp start "$wb" 2>&1)"; rc=$?
rm -f scratch.txt
if [ "$rc" -eq 0 ] && echo "$out" | grep -qi "uncommitted changes stay in the primary"; then
  ok "test_worktree_start_dirty_primary_only_notice"
else
  bad "test_worktree_start_dirty_primary_only_notice" "rc=$rc out=$out"
fi

git config aapp.planWorktrees off
wc_="$(wt_plan gamma)"; fc="$(plan_file "$wc_")"
out="$(aapp start "$wc_" worktree ../custom-gamma branch feat/gamma 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -d "$R/custom-gamma" ] && [ "$(git -C "$R/custom-gamma" rev-parse --abbrev-ref HEAD)" = "feat/gamma" ] && \
   grep -qxF "* **Worktree:** ../custom-gamma (feat/gamma)" "$fc"; then
  ok "test_worktree_tokens_override_templates"
else
  bad "test_worktree_tokens_override_templates" "rc=$rc out=$out"
fi
wo="$(wt_plan omega)"; fo="$(plan_file "$wo")"
nwt="$(git worktree list | wc -l)"
aapp start "$wo" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && ! grep -q '^\* \*\*Worktree:\*\*' "$fo" && [ "$(git worktree list | wc -l)" = "$nwt" ] && [ "$(pbuf)" = "$wo" ]; then
  ok "test_worktree_off_changes_nothing"
else
  bad "test_worktree_off_changes_nothing" "rc=$rc"
fi
aapp active clear >/dev/null 2>&1
git config aapp.planWorktrees on

# on-start (a registered gate) renames the branch and moves the worktree.
hookdir=".agents/skills/aapp-hooks"; mkdir -p "$hookdir"
cat > "$hookdir/rename.sh" <<'EOF'
#!/usr/bin/env bash
p="$(cat)"
wt="$(printf '%s' "$p" | sed -nE 's/.*"worktree": *"([^"]*)".*/\1/p')"
[ -n "$wt" ] || exit 0
br="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
git branch -m "$br" "team/$br" && git worktree move "$wt" "$wt-moved"
EOF
chmod +x "$hookdir/rename.sh"
aapp hook-hash "$hookdir/rename.sh" on-start 10 gate 2>/dev/null | grep "^on-start" > "$hookdir/registry.tsv"
wd="$(wt_plan delta)"; nd="${wd#P-}"; fd="$(plan_file "$wd")"; sd="$(slug_of "$wd")"
out="$(aapp start "$wd" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -d "$R/w/.workspace/P$nd-moved" ] && [ ! -d "$R/w/.workspace/P$nd" ] && \
   grep -qxF "* **Worktree:** .workspace/P$nd-moved (team/plan/P$nd-$sd)" "$fd" && echo "$out" | grep -qF "$R/w/.workspace/P$nd-moved"; then
  ok "test_worktree_on_start_rename_is_recorded"
else
  bad "test_worktree_on_start_rename_is_recorded" "rc=$rc out=$out $(grep Worktree "$fd")"
fi

# A failing on-start rolls back everything, keeping prior uncommitted plan edits.
printf '%s\n' '#!/usr/bin/env bash' 'cat >/dev/null; exit 1' > "$hookdir/fail.sh"; chmod +x "$hookdir/fail.sh"
aapp hook-hash "$hookdir/fail.sh" on-start 10 gate 2>/dev/null | grep "^on-start" > "$hookdir/registry.tsv"
we="$(wt_plan epsilon)"; ne="${we#P-}"; fe="$(plan_file "$we")"
echo "<!-- my uncommitted note -->" >> "$fe"
before="$(cksum < "$fe")"; sm_before="$(cksum < .plans/state_matrix.md)"; head0="$(git -C .plans rev-parse HEAD)"
out="$(aapp start "$we" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && [ ! -d "$R/w/.workspace/P$ne" ] && ! git rev-parse --verify -q "plan/P$ne-$(slug_of "$we")" >/dev/null && \
   [ "$(cksum < "$fe")" = "$before" ] && [ "$(cksum < .plans/state_matrix.md)" = "$sm_before" ] && \
   [ "$(git -C .plans rev-parse HEAD)" = "$head0" ] && [ -z "$(pbuf)" ]; then
  ok "test_worktree_failing_on_start_rolls_back"
else
  bad "test_worktree_failing_on_start_rolls_back" "rc=$rc out=$out"
fi
rm -f "$hookdir/registry.tsv" "$hookdir/fail.sh" "$hookdir/rename.sh"
git -C .plans checkout -q -- "current/$(basename "$fe")"

# A link that cannot be made (develop tracks .claude) and a failing start
# commit (.plans index locked) roll back the same way.
git worktree add -q "$R/tmpdev" develop && mkdir -p "$R/tmpdev/.claude" && echo x > "$R/tmpdev/.claude/x" && git -C "$R/tmpdev" add -f .claude/x && git -C "$R/tmpdev" commit -qm "track .claude" --no-verify
before="$(cksum < "$fe")"
out="$(aapp start "$we" 2>&1)"; rc1=$?
gone1=0; [ ! -d "$R/w/.workspace/P$ne" ] && ! git rev-parse --verify -q "plan/P$ne-$(slug_of "$we")" >/dev/null && [ "$(cksum < "$fe")" = "$before" ] && gone1=1
git -C "$R/tmpdev" rm -rq .claude && git -C "$R/tmpdev" commit -qm "untrack .claude" --no-verify && git worktree remove --force "$R/tmpdev"
lock="$(git -C .plans rev-parse --git-path index.lock)"; case "$lock" in /*) ;; *) lock=".plans/$lock" ;; esac
touch "$lock"
out2="$(aapp start "$we" 2>&1)"; rc2=$?
rm -f "$lock"
if [ "$rc1" -ne 0 ] && [ "$gone1" -eq 1 ] && echo "$out" | grep -qF ".claude" && [ "$rc2" -ne 0 ] && [ ! -d "$R/w/.workspace/P$ne" ] && \
   ! git rev-parse --verify -q "plan/P$ne-$(slug_of "$we")" >/dev/null && [ "$(cksum < "$fe")" = "$before" ] && [ -z "$(pbuf)" ]; then
  ok "test_worktree_failing_link_or_commit_rolls_back"
else
  bad "test_worktree_failing_link_or_commit_rolls_back" "rc=$rc1/$rc2 gone1=$gone1 out=$out | $out2"
fi

# aapp.planSession: run detached in the worktree with quoted placeholders and
# the environment; start does not wait; a failing launch only warns. The session
# waits for a marker the test creates after start returned (P-68): if start
# waited for it, start would hang (cut by `timeout`).
git config aapp.planSession 'while [ ! -f {path}/../../../session-go ]; do sleep 0.1; done; printf "%s|%s|%s\n" {id} "$AAPP_BRANCH" "$AAPP_PLAN_FILE" > {path}/../../../session-{id}.out'
wf_="$(wt_plan zeta)"; nf="${wf_#P-}"; sf="$(slug_of "$wf_")"
out="$(timeout 20 aapp start "$wf_" 2>&1)"; rc=$?
early=0; [ -f "$R/session-P$nf.out" ] && early=1
touch "$R/session-go"
for _ in $(seq 1 50); do [ -f "$R/session-P$nf.out" ] && break; sleep 0.1; done
if [ "$rc" -eq 0 ] && [ "$early" -eq 0 ] && \
   [ "$(cat "$R/session-P$nf.out" 2>/dev/null)" = "P$nf|plan/P$nf-$sf|.plans/current/P$nf-$sf.md" ]; then
  ok "test_worktree_session_runs_detached_with_placeholders"
else
  bad "test_worktree_session_runs_detached_with_placeholders" "rc=$rc early=$early got=$(cat "$R/session-P$nf.out" 2>/dev/null) out=$out"
fi
git config aapp.planSession 'no-such-session-tool-xyz {path}'
wg="$(wt_plan eta)"
out="$(aapp start "$wg" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -qi "session" && echo "$out" | grep -qF "cd "; then
  ok "test_worktree_session_failure_only_warns"
else
  bad "test_worktree_session_failure_only_warns" "rc=$rc out=$out"
fi
git config --unset aapp.planSession

echo "== base branch resolution (P-54) =="
init_sandbox_project "$R/rb"
cd "$R/rb" || exit 1
git config aapp.planWorktrees on
git init -q --bare "$R/rb-remote.git"
git remote add origin "$R/rb-remote.git"
git checkout -q -b develop && git push -q origin develop 2>/dev/null && git checkout -q - && git branch -D develop >/dev/null
git fetch -q origin
ra="$(wt_plan remote)"; fra="$(plan_file "$ra")"; nra="${ra#P-}"
out="$(aapp start "$ra" 2>&1)"; rc=$?
rbr="plan/P$nra-$(slug_of "$ra")"
if [ "$rc" -eq 0 ] && [ "$(git rev-parse "$rbr")" = "$(git rev-parse origin/develop)" ] && \
   ! git rev-parse --abbrev-ref "$rbr@{upstream}" >/dev/null 2>&1 && grep -qE '^\* \*\*Base:\*\* `[0-9a-f]+` \(develop\)$' "$fra"; then
  ok "test_worktree_base_remote_only_no_track"
else
  bad "test_worktree_base_remote_only_no_track" "rc=$rc out=$out base=$(grep Base "$fra")"
fi
git config aapp.devBranch "nonexistent-dev"
rd="$(wt_plan default)"; frd="$(plan_file "$rd")"
dflt="$(git rev-parse --abbrev-ref HEAD)"
out="$(aapp start "$rd" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -qE "^\* \*\*Base:\*\* \`[0-9a-f]+\` \($dflt\)$" "$frd"; then
  ok "test_worktree_base_falls_back_to_default_branch"
else
  bad "test_worktree_base_falls_back_to_default_branch" "rc=$rc out=$out base=$(grep Base "$frd")"
fi
git remote remove origin; git branch -m "$dflt" trunk
rn="$(wt_plan none)"; frn="$(plan_file "$rn")"; before="$(cksum < "$frn")"
out="$(aapp start "$rn" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qi "base branch" && [ "$(cksum < "$frn")" = "$before" ]; then
  ok "test_worktree_refuses_without_base_branch"
else
  bad "test_worktree_refuses_without_base_branch" "rc=$rc out=$out"
fi

print_test_summary "$PASS" "$FAIL"
