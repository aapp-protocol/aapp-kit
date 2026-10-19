#!/usr/bin/env bash
# Core suite for hooks inside the kit worktrees and plan worktrees (P-26,
# P-54): hook links, the commit hooks in .plans and .agents, attribution modes,
# and a plan worktree's guard, pre-commit, commit record and rebase-only rule.
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
source "$KIT/tests/test_helpers.sh"
SANDBOX_ROOT=$(mktemp -d /tmp/aapp-worktree-hooks-test-XXXXXX)
trap 'rm -rf "$SANDBOX_ROOT"' EXIT
confine_test_runtime "$SANDBOX_ROOT"

T="$SANDBOX_ROOT/repo"
mkdir -p "$T" && cd "$T" || exit 1
git init -q && git branch -M main && setup_test_git_identity "$T"
aapp init >/dev/null 2>&1

# commits_in <worktree> <message>: prints COMMITTED or BLOCKED.
commits_in() { (cd "$T/$1" && git commit -m "$2" >/dev/null 2>&1) && echo COMMITTED || echo BLOCKED; }

echo "== hook links =="
check_links() {
  local wt
  for wt in .plans .agents; do
    [ -L "$T/$wt/.githooks" ] && [ "$(readlink "$T/$wt/.githooks")" = "../.githooks" ] || t_fail "$1: $wt/.githooks is not a link to ../.githooks"
    t_expect "$1: $wt/.gitignore .githooks lines" 1 "$(grep -cx '\.githooks' "$T/$wt/.gitignore")"
  done
}
check_links "init"
aapp init >/dev/null 2>&1
check_links "re-init"
t_done test_init_links_hooks_into_worktrees

echo "== commit hooks in .plans and .agents =="
echo "test idea" >> "$T/.plans/pickup.md"; git -C "$T/.plans" add pickup.md
t_expect "Claude co-author" BLOCKED "$(commits_in .plans "docs: add test idea

Co-authored-by: Claude <noreply@anthropic.com>")"
t_expect "Antigravity co-author" BLOCKED "$(commits_in .plans "docs: add test idea

Co-authored-by: Antigravity <antigravity@google.com>")"
t_expect "subject over 72" BLOCKED "$(commits_in .plans "docs: this is an excessively long commit subject line that surely exceeds the maximum allowed seventy-two characters")"
t_expect "clean commit" COMMITTED "$(commits_in .plans "docs: add test idea in pickup")"
t_done test_plans_worktree_runs_commit_hooks

echo "# Note" >> "$T/.agents/PROJECT.MD"; git -C "$T/.agents" add PROJECT.MD
t_expect "Claude co-author" BLOCKED "$(commits_in .agents "chore: update project context

Co-authored-by: Claude <noreply@anthropic.com>")"
t_expect "clean commit" COMMITTED "$(commits_in .agents "chore: update project context cleanly")"
t_done test_agents_worktree_runs_commit_hooks

echo "== attribution modes in worktrees =="
git -C "$T" config aapp.aiAttribution strict
echo "note2" >> "$T/.plans/pickup.md"; git -C "$T/.plans" add pickup.md
t_expect "strict, no trailers" BLOCKED "$(commits_in .plans "docs: missing AI trailer in strict mode")"
t_expect "strict, trailers" COMMITTED "$(commits_in .plans "docs: update test idea with valid trailers

AI-Agent: Claude
AI-Vendor: Anthropic
AI-Model: claude-3-5-sonnet")"
# lax takes a human commit without trailers (#81).
git -C "$T" config aapp.aiAttribution lax
echo "note3" >> "$T/.plans/pickup.md"; git -C "$T/.plans" add pickup.md
t_expect "lax, human commit" COMMITTED "$(commits_in .plans "docs: human commit without trailers in lax mode")"
t_done test_attribution_modes_in_worktrees

echo "== plan worktrees (P-54) =="
PW="$SANDBOX_ROOT/pw"
init_sandbox_project "$PW"
cd "$PW" || exit 1
PRIM="$(git rev-parse --abbrev-ref HEAD)"
# Plan worktrees check out the branch: track what init wrote; ignore the
# bytecode the hook's py_compile leaves behind (#106).
echo "__pycache__/" >> .gitignore
git add -A && git commit -qm "track init files" --no-verify
git branch develop
git config aapp.planWorktrees on
git config aapp.commitMode microcommits
WID="P-$(git config aapp.planId)"
aapp draft wt-hooks >/dev/null 2>&1
WF="$(ls .plans/current/P"${WID#P-}"-*.md)"
sed -i -E "s|src/path/to/file\.ext|src/wt.py|g; s|src/path/to/new_file\.ext|src/wt_extra.py|g" "$WF"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$WF"
git -C .plans commit -qam "prep $WID" >/dev/null
aapp freeze-start "$WID" >/dev/null 2>&1
W="$PW/.workspace/P${WID#P-}"
commits_list() { sed -nE 's/^\* \*\*Commits:\*\*[[:space:]]*//p' "$WF" | grep -oE '`[0-9a-f]+`' | tr -d '`'; }
all_reachable() { local c; for c in $(commits_list); do git -C "$W" merge-base --is-ancestor "$c" HEAD || return 1; done; }
# on_develop <file> <content> <msg>: commits on develop without touching the plan worktree.
on_develop() { git -C "$PW" checkout -q develop && echo "$2" > "$PW/$1" && git -C "$PW" add "$1" && git -C "$PW" commit -qm "$3" --no-verify && git -C "$PW" checkout -q "$PRIM"; }
guard() { (cd "$1" && .githooks/blast-radius-guard "$2" >/dev/null 2>&1) && echo allow || echo refuse; }

t_expect "target, from the plan worktree" allow "$(guard "$W" src/wt.py)"
t_expect "other file, from the plan worktree" refuse "$(guard "$W" src/other.py)"
t_expect "primary .plans, from the plan worktree" allow "$(guard "$W" "$PW/.plans/pickup.md")"
# From the primary session too (P-61, #112).
t_expect "plan worktree target, from the primary" allow "$(guard "$PW" "$W/src/wt.py")"
t_expect "plan worktree other file, from the primary" refuse "$(guard "$PW" "$W/src/other.py")"
t_done test_plan_worktree_guard

cd "$W" || exit 1
mkdir -p src; echo "o = 1" > src/other.py; git add src/other.py
git commit -qm "outside the plan" >/dev/null 2>&1 && t_fail "commit outside the plan passed"
git reset -q; rm -f src/other.py
t_done test_plan_worktree_pre_commit_refuses_outside_files

echo "w = 1" > src/wt.py; git add src/wt.py
aapp commit "feat: wt one" >/dev/null 2>&1
grep -qF "\`$(git rev-parse --short HEAD)\` (plan/P${WID#P-}-wt-hooks)" "$WF" || t_fail "aapp commit recorded nothing"
on_develop dev2.py "d = 2" "develop moves"
git rebase -q develop >/dev/null 2>&1 || t_fail "rebase failed"
[ "$(commits_list)" = "$(git rev-parse --short HEAD)" ] && all_reachable || t_fail "rebase: record $(commits_list | tr '\n' ' ')"
echo "w = 2" > src/wt.py; git add src/wt.py; aapp commit "feat: wt two" >/dev/null 2>&1
GIT_SEQUENCE_EDITOR="sed -i '2s/^pick/squash/'" GIT_EDITOR=true git rebase -q -i develop >/dev/null 2>&1 || t_fail "squash failed"
[ "$(commits_list)" = "$(git rev-parse --short HEAD)" ] || t_fail "squash: record $(commits_list | tr '\n' ' ')"
# A new file, so the cherry-pick onto develop applies cleanly and the rebase drops it.
echo "e = 1" > src/wt_extra.py; git add src/wt_extra.py; aapp commit "feat: wt extra" >/dev/null 2>&1
x="$(git rev-parse HEAD)"
git -C "$PW" checkout -q develop && git -C "$PW" cherry-pick "$x" >/dev/null 2>&1; git -C "$PW" checkout -q "$PRIM"
git rebase develop >/dev/null 2>&1 || t_fail "rebase over the cherry-pick failed"
! commits_list | grep -q "^${x:0:7}" && all_reachable && [ -n "$(commits_list)" ] || t_fail "dropped commit: record $(commits_list | tr '\n' ' ')"
echo "w = 4" > src/wt.py; git add src/wt.py
aapp commit amend >/dev/null 2>&1
t_expect "amended SHA recorded once" 1 "$(commits_list | grep -c "^$(git rev-parse --short HEAD)$")"
all_reachable || t_fail "amend: record $(commits_list | tr '\n' ' ')"
t_done test_plan_worktree_commit_record_follows_rewrites

git -C "$PW" checkout -q develop && echo "w = 99" > "$PW/src/wt.py" && echo "d = 3" > "$PW/dev3.py" && \
  git -C "$PW" add src/wt.py dev3.py && git -C "$PW" commit -qm "develop edits wt" --no-verify && git -C "$PW" checkout -q "$PRIM"
git merge develop >/dev/null 2>&1
echo "w = 4" > src/wt.py; git add src/wt.py
git commit -q --no-edit >/dev/null 2>&1 && t_fail "a conflicted merge was finished"
git merge --abort >/dev/null 2>&1 || git reset -q --hard HEAD
t_done test_plan_worktree_refuses_merge
cd "$T" || exit 1

print_test_summary "$PASS" "$FAIL"
