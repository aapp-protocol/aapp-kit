#!/usr/bin/env bash
# Tests: `aapp done` for plans with their own worktree (P-54, #119, P-60); a part
# of the done suite (lib/docs/verbs/done.md, P-68).
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

echo "== plan worktrees (P-54) =="
init_sandbox_project "$R/dw"
cd "$R/dw" || exit 1
# Plan worktrees check out the branch: track what init wrote (CHANGELOG.md etc.).
git add -A && git commit -qm "track init files" --no-verify
git branch develop
git config aapp.planWorktrees on
# wt_started <name>: freeze-start a plan into its worktree and commit its file there; prints the id.
wt_started() {
  local id f n
  id="$(draft_plan "$1")"; f="$(plan_file "$id")"; n="${id#P-}"
  # .sh, not .py: the hook's py_compile leaves __pycache__ behind (#106).
  sed -i -E "s|src/path/to/file\.ext|src/$1.sh|g; /src\/path\/to\/new_file\.ext/d" "$f"
  sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$f"
  git -C .plans commit -qam "prepare $id" >/dev/null
  aapp freeze-start "$id" >/dev/null 2>&1
  ( cd "$R/dw/.workspace/P$n" && mkdir -p src && echo "v=1" > "src/$1.sh" && git add "src/$1.sh" && aapp commit "feat: $1" >/dev/null 2>&1 )
  echo "$id"
}
da="$(wt_started dwa)"; dna="${da#P-}"; dfa="$(plan_file "$da")"
echo "v=2" > "$R/dw/.workspace/P$dna/src/dwa.sh"
out="$(aapp done "$da" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qi "uncommitted" && [ -f "$dfa" ]; then
  ok "test_done_refuses_dirty_plan_worktree"
else
  bad "test_done_refuses_dirty_plan_worktree" "rc=$rc out=$out commits=$(grep Commits "$dfa")"
fi
git -C "$R/dw/.workspace/P$dna" checkout -q -- src/dwa.sh
out="$(aapp done "$da" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -f ".plans/done/$(basename "$dfa")" ] && grep -qxF "* **Worktree:** .workspace/P$dna (plan/P$dna-dwa)" ".plans/done/$(basename "$dfa")" && \
   [ ! -s "$(git -C "$R/dw/.workspace/P$dna" rev-parse --git-path aapp_active_plan)" ] && [ -d "$R/dw/.workspace/P$dna" ] && \
   echo "$out" | grep -qF "git worktree remove .workspace/P$dna" && echo "$out" | grep -qi "ignored files" && \
   echo "$out" | grep -qF "git branch -D plan/P$dna-dwa"; then
  ok "test_done_from_primary_clears_holding_buffer_and_advises"
else
  bad "test_done_from_primary_clears_holding_buffer_and_advises" "rc=$rc out=$out"
fi
db="$(wt_started dwb)"; dnb="${db#P-}"; dfb="$(plan_file "$db")"
cd "$R/dw/.workspace/P$dnb" || exit 1
out="$(aapp done "$db" 2>&1)"; rc=$?
cd "$R/dw" || exit 1
if [ "$rc" -eq 0 ] && [ -f ".plans/done/$(basename "$dfb")" ] && [ ! -f "$dfb" ]; then
  ok "test_done_from_plan_worktree_archives"
else
  bad "test_done_from_plan_worktree_archives" "rc=$rc out=$out"
fi

echo "== a TDD plan with a worktree, done from the primary (#119) =="
cd "$R/dw" || exit 1
dt="$(draft_plan dwt)"; dft="$(plan_file "$dt")"; dnt="${dt#P-}"
aapp tdd "$dt" >/dev/null 2>&1
sed -i -E "s|src/path/to/file\.ext|src/dwt.sh|g; s|src/path/to/new_file\.ext|tests/dwt_test.sh|g; s/^\* \[ \] \*\*Question/* [x] **Question/" "$dft"
sed -i -E '/^> Test assertions that must fail/a - [ ] `tests/dwt_test.sh::test_dwt` -> asserts dwt' "$dft"
sed -i -E '/^> Test files that must prove/a - `tests/dwt_test.sh`' "$dft"
git -C .plans commit -qam "prepare $dt" >/dev/null
aapp freeze-start "$dt" >/dev/null 2>&1
( cd "$R/dw/.workspace/P$dnt" && mkdir -p src tests && echo "v=1" > src/dwt.sh && echo "# t" > tests/dwt_test.sh && \
  git add src/dwt.sh tests/dwt_test.sh && aapp commit "feat: dwt" >/dev/null 2>&1 )
sed -i -E 's/^- \[ \] (`tests\/dwt_test\.sh::)/- [x] \1/' "$dft"
git -C .plans commit -qam "tick $dt" >/dev/null
out="$(aapp done "$dt" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -f ".plans/done/$(basename "$dft")" ] && [ ! -f tests/dwt_test.sh ]; then
  ok "test_done_finds_test_files_in_plan_worktree"
else
  bad "test_done_finds_test_files_in_plan_worktree" "rc=$rc out=$out"
fi

echo "== pre-done payload carries the worktree (P-60) =="
mkdir -p .agents/hooks .agents/skills/aapp-hooks
printf '#!/usr/bin/env bash\ngrep -oE %s > "%s/payload"\n' "'\"worktree\": \"[^\"]*\"'" "$R" > .agents/hooks/rec.sh
sed "s|^TEST_CMD=.*|TEST_CMD='pwd > $R/cwd'|" "$KIT/examples/hooks/test-gate.sh.sample" > .agents/hooks/test-gate.sh
chmod +x .agents/hooks/rec.sh .agents/hooks/test-gate.sh
for h in rec.sh test-gate.sh; do
  aapp hook-hash ".agents/hooks/$h" pre-done 20 gate 2>/dev/null | grep "^pre-done"
done > .agents/skills/aapp-hooks/registry.tsv
dc="$(wt_started dwc)"; dnc="${dc#P-}"
out="$(aapp done "$dc" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat "$R/payload")" = "\"worktree\": \"$R/dw/.workspace/P$dnc\"" ] && \
   [ "$(cat "$R/cwd")" = "$R/dw/.workspace/P$dnc" ]; then
  ok "test_pre_done_payload_names_plan_worktree"
else
  bad "test_pre_done_payload_names_plan_worktree" "rc=$rc payload=$(cat "$R/payload" 2>&1) cwd=$(cat "$R/cwd" 2>&1) out=$out"
fi
git config aapp.planWorktrees off
git checkout -q develop
dd="$(draft_plan dwd)"; fd="$(plan_file "$dd")"
sed -i -E "s|src/path/to/file\.ext|src/dwd.sh|g; /src\/path\/to\/new_file\.ext/d; s/^\* \[ \] \*\*Question/* [x] **Question/" "$fd"
git -C .plans commit -qam "prepare $dd" >/dev/null
aapp freeze-start "$dd" >/dev/null 2>&1
mkdir -p src && echo "v=1" > src/dwd.sh && git add src/dwd.sh && aapp commit "feat: dwd" >/dev/null 2>&1
rm -f "$R/payload" "$R/cwd"
out="$(aapp done "$dd" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat "$R/payload")" = '"worktree": ""' ] && [ "$(cat "$R/cwd")" = "$R/dw" ]; then
  ok "test_pre_done_payload_worktree_empty_in_single_checkout"
else
  bad "test_pre_done_payload_worktree_empty_in_single_checkout" "rc=$rc payload=$(cat "$R/payload" 2>&1) cwd=$(cat "$R/cwd" 2>&1) out=$out"
fi

print_test_summary "$PASS" "$FAIL"
