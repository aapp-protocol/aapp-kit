#!/usr/bin/env bash
# ==============================================================================
# Tests: Worktree Hook Execution & Attribution Confinement (P-26)
# ==============================================================================
set -e

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

source "$KIT/tests/test_helpers.sh"

SANDBOX_ROOT=$(mktemp -d /tmp/aapp-worktree-hooks-test-XXXXXX)
trap 'rm -rf "$SANDBOX_ROOT"' EXIT
confine_test_runtime "$SANDBOX_ROOT"

TEST_DIR="$SANDBOX_ROOT/repo"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"
git init -q
git branch -M main
setup_test_git_identity "$TEST_DIR"

# Setup AAPP via installed aapp init
(
    cd "$TEST_DIR"
    aapp init >/dev/null 2>&1
)

# Helper reporting function
report() {
    local desc="$1" want="$2" got="$3"
    if [ "$got" = "$want" ]; then
        printf "  \033[32m✔\033[0m %-58s %s\n" "$desc" "PASS"
        PASS=$((PASS+1))
    else
        printf "  \033[31m✘\033[0m %-58s want '%s' got '%s'\n" "$desc" "$want" "$got"
        FAIL=$((FAIL+1))
    fi
}

echo "== 1. Worktree Hook Symlink Seeding & Ignore Hygiene =="

# 1.1 Check .plans/.githooks symlink
if [ -L "$TEST_DIR/.plans/.githooks" ] && [ "$(readlink "$TEST_DIR/.plans/.githooks")" = "../.githooks" ]; then
    got="PASS"
else
    got="FAIL"
fi
report ".plans/.githooks symlink points to ../.githooks" "PASS" "$got"

# 1.2 Check .agents/.githooks symlink
if [ -L "$TEST_DIR/.agents/.githooks" ] && [ "$(readlink "$TEST_DIR/.agents/.githooks")" = "../.githooks" ]; then
    got="PASS"
else
    got="FAIL"
fi
report ".agents/.githooks symlink points to ../.githooks" "PASS" "$got"

# 1.3 Check .plans/.gitignore ignores .githooks
if grep -qE '^\.githooks' "$TEST_DIR/.plans/.gitignore"; then
    got="PASS"
else
    got="FAIL"
fi
report ".plans/.gitignore ignores .githooks" "PASS" "$got"

# 1.4 Check .agents/.gitignore ignores .githooks
if grep -qE '^\.githooks' "$TEST_DIR/.agents/.gitignore"; then
    got="PASS"
else
    got="FAIL"
fi
report ".agents/.gitignore ignores .githooks" "PASS" "$got"

echo "== 2. Hook Execution Inside .plans Worktree =="

# 2.1 Banned co-author trailer rejected in .plans
(
    cd "$TEST_DIR/.plans"
    echo "test idea" >> pickup.md
    git add pickup.md
)
if (
    cd "$TEST_DIR/.plans"
    git commit -m "docs: add test idea

Co-authored-by: Claude <noreply@anthropic.com>" >/dev/null 2>&1
); then
    got="COMMITTED"
else
    got="BLOCKED"
fi
report ".plans commit rejects banned Claude co-author trailer" "BLOCKED" "$got"

# 2.2 Banned Antigravity co-author trailer rejected in .plans
if (
    cd "$TEST_DIR/.plans"
    git commit -m "docs: add test idea

Co-authored-by: Antigravity <antigravity@google.com>" >/dev/null 2>&1
); then
    got="COMMITTED"
else
    got="BLOCKED"
fi
report ".plans commit rejects banned Antigravity co-author trailer" "BLOCKED" "$got"

# 2.3 Subject length invariant (> 72 chars) enforced in .plans
LONG_SUBJ="docs: this is an excessively long commit subject line that surely exceeds the maximum allowed seventy-two characters"
if (
    cd "$TEST_DIR/.plans"
    git commit -m "$LONG_SUBJ" >/dev/null 2>&1
); then
    got="COMMITTED"
else
    got="BLOCKED"
fi
report ".plans commit rejects subject exceeding 72 chars" "BLOCKED" "$got"

# 2.4 Clean commit succeeds in .plans
if (
    cd "$TEST_DIR/.plans"
    git commit -m "docs: add test idea in pickup" >/dev/null 2>&1
); then
    got="PASS"
else
    got="FAIL"
fi
report ".plans clean commit succeeds" "PASS" "$got"

echo "== 3. Hook Execution Inside .agents Worktree =="

# 3.1 Banned co-author trailer rejected in .agents
(
    cd "$TEST_DIR/.agents"
    echo "# Note" >> PROJECT.MD
    git add PROJECT.MD
)
if (
    cd "$TEST_DIR/.agents"
    git commit -m "chore: update project context

Co-authored-by: Claude <noreply@anthropic.com>" >/dev/null 2>&1
); then
    got="COMMITTED"
else
    got="BLOCKED"
fi
report ".agents commit rejects banned Claude co-author trailer" "BLOCKED" "$got"

# 3.2 Clean commit succeeds in .agents
if (
    cd "$TEST_DIR/.agents"
    git commit -m "chore: update project context cleanly" >/dev/null 2>&1
); then
    got="PASS"
else
    got="FAIL"
fi
report ".agents clean commit succeeds" "PASS" "$got"

echo "== 4. Attribution Mode Switchboard in Worktrees =="

# Switch to strict attribution mode
(
    cd "$TEST_DIR"
    git config aapp.aiAttribution "strict"
)

# 4.1 In strict mode, missing AI-Agent trailer rejected in .plans
(
    cd "$TEST_DIR/.plans"
    echo "note2" >> pickup.md
    git add pickup.md
)
if (
    cd "$TEST_DIR/.plans"
    git commit -m "docs: missing AI trailer in strict mode" >/dev/null 2>&1
); then
    got="COMMITTED"
else
    got="BLOCKED"
fi
report "strict mode: missing AI-Agent trailer rejected in .plans" "BLOCKED" "$got"

# 4.2 In strict mode, valid AI trailers succeed in .plans
if (
    cd "$TEST_DIR/.plans"
    git commit -m "docs: update test idea with valid trailers

AI-Agent: Claude
AI-Vendor: Anthropic
AI-Model: claude-3-5-sonnet" >/dev/null 2>&1
); then
    got="PASS"
else
    got="FAIL"
fi
report "strict mode: valid AI trailers accepted in .plans" "PASS" "$got"

# 4.3 test_lax_accepts_human_plans_commit: in lax mode, trailer-less human commit succeeds in .plans (#81)
(
    cd "$TEST_DIR"
    git config aapp.aiAttribution "lax"
)
(
    cd "$TEST_DIR/.plans"
    echo "note3" >> pickup.md
    git add pickup.md
)
if (
    cd "$TEST_DIR/.plans"
    git commit -m "docs: human commit without trailers in lax mode" >/dev/null 2>&1
); then
    got="PASS"
else
    got="FAIL"
fi
report "test_lax_accepts_human_plans_commit: trailer-less commit inside .plans passes in lax (#81)" "PASS" "$got"

echo "== 5. Idempotent Re-Init and Stability =="

# Run aapp init again
(
    cd "$TEST_DIR"
    aapp init >/dev/null 2>&1
)

if [ -L "$TEST_DIR/.plans/.githooks" ] && [ -L "$TEST_DIR/.agents/.githooks" ]; then
    got="PASS"
else
    got="FAIL"
fi
report "re-init preserves worktree symlinks without corruption" "PASS" "$got"

# Verify gitignore has no duplicates
plans_ignore_count=$(grep -cx "\.githooks" "$TEST_DIR/.plans/.gitignore" || true)
if [ "$plans_ignore_count" -eq 1 ]; then
    got="PASS"
else
    got="FAIL"
fi
report ".plans/.gitignore retains exactly one .githooks entry" "PASS" "$got"

echo "== 6. Plan worktrees: hooks, guard, commits, rebase (P-54) =="
PW="$SANDBOX_ROOT/pw"
init_sandbox_project "$PW"
cd "$PW"
PRIM="$(git rev-parse --abbrev-ref HEAD)"
# Plan worktrees check out the branch: track what init wrote (CHANGELOG.md etc.);
# ignore the bytecode the hook's py_compile leaves behind (#106).
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
# commits_list: the SHAs recorded in the plan, one per line.
commits_list() { sed -nE 's/^\* \*\*Commits:\*\*[[:space:]]*//p' "$WF" | grep -oE '`[0-9a-f]+`' | tr -d '`'; }
all_reachable() { local c; for c in $(commits_list); do git -C "$W" merge-base --is-ancestor "$c" HEAD || return 1; done; }
# on_develop <file> <content> <msg>: commit on develop without touching the plan worktree.
on_develop() { git checkout -q develop && mkdir -p "$(dirname "$1")" && echo "$2" > "$1" && git add "$1" && git commit -qm "$3" --no-verify && git checkout -q "$PRIM"; }

cd "$W"
g1=FAIL; .githooks/blast-radius-guard src/wt.py >/dev/null 2>&1 && g1=PASS
g2=FAIL; .githooks/blast-radius-guard src/other.py >/dev/null 2>&1 || g2=PASS
g3=FAIL; .githooks/blast-radius-guard "$PW/.plans/pickup.md" >/dev/null 2>&1 && g3=PASS
report "plan worktree: guard allows targets, refuses others, allows primary .plans" "PASS PASS PASS" "$g1 $g2 $g3"

# Cross-worktree guard checks from primary session (P-61, #112)
cd "$PW"
cg1=FAIL; .githooks/blast-radius-guard "$W/src/wt.py" >/dev/null 2>&1 && cg1=PASS
cg2=FAIL; .githooks/blast-radius-guard "$W/src/other.py" >/dev/null 2>&1 || cg2=PASS
report "primary session: guard allows plan worktree target, refuses plan worktree out-of-bounds" "PASS PASS" "$cg1 $cg2"
cd "$W"

mkdir -p src; echo "o = 1" > src/other.py; git add src/other.py
h=FAIL; git commit -qm "outside the plan" >/dev/null 2>&1 || h=PASS
git reset -q; rm -f src/other.py
report "plan worktree: pre-commit runs and refuses files outside the plan" "PASS" "$h"

echo "w = 1" > src/wt.py; git add src/wt.py
aapp commit "feat: wt one" >/dev/null 2>&1 || true
c1="$(git rev-parse --short HEAD)"
got=FAIL; grep -qF "\`$c1\` (plan/P${WID#P-}-wt-hooks)" "$WF" && got=PASS
report "plan worktree: aapp commit records the commit in the plan" "PASS" "$got"

cd "$PW"; on_develop dev2.py "d = 2" "develop moves"; cd "$W"
r=0; git rebase -q develop >/dev/null 2>&1 || r=$?
got=FAIL; [ "$r" -eq 0 ] && [ "$(commits_list)" = "$(git rev-parse --short HEAD)" ] && all_reachable && got=PASS
report "post-rewrite: rebase maps the recorded commit to its new SHA" "PASS" "$got"

echo "w = 2" > src/wt.py; git add src/wt.py; aapp commit "feat: wt two" >/dev/null 2>&1 || true
r=0; GIT_SEQUENCE_EDITOR="sed -i '2s/^pick/squash/'" GIT_EDITOR=true git rebase -q -i develop >/dev/null 2>&1 || r=$?
got=FAIL; [ "$r" -eq 0 ] && [ "$(commits_list)" = "$(git rev-parse --short HEAD)" ] && got=PASS
report "post-rewrite: an interactive squash leaves one SHA, no duplicates" "PASS" "$got"

# A new file, so the cherry-pick onto develop applies cleanly and the rebase drops it.
echo "e = 1" > src/wt_extra.py; git add src/wt_extra.py; aapp commit "feat: wt extra" >/dev/null 2>&1 || true
x="$(git rev-parse HEAD)"
cd "$PW"; git checkout -q develop && git cherry-pick "$x" >/dev/null 2>&1; git checkout -q "$PRIM"; cd "$W"
r=0; git rebase develop >/dev/null 2>&1 || r=$?
got=FAIL; [ "$r" -eq 0 ] && ! commits_list | grep -q "^${x:0:7}" && all_reachable && [ -n "$(commits_list)" ] && got=PASS
report "post-rewrite: a commit dropped as already upstream leaves the record" "PASS" "$got"

echo "w = 4" > src/wt.py; git add src/wt.py
aapp commit amend >/dev/null 2>&1 || true
got=FAIL; [ "$(commits_list | grep -c "^$(git rev-parse --short HEAD)$")" -eq 1 ] && all_reachable && got=PASS
report "aapp commit amend records its SHA exactly once" "PASS" "$got"

cd "$PW"; git checkout -q develop && echo "w = 99" > src/wt.py && echo "d = 3" > dev3.py && git add src/wt.py dev3.py && \
  git commit -qm "develop edits wt" --no-verify && git checkout -q "$PRIM"; cd "$W"
git merge develop >/dev/null 2>&1 || true
echo "w = 4" > src/wt.py; git add src/wt.py
m=FAIL; git commit -q --no-edit >/dev/null 2>&1 || m=PASS
git merge --abort >/dev/null 2>&1 || git reset -q --hard HEAD
report "plan worktree: finishing a conflicted merge is refused (rebase only)" "PASS" "$m"
cd "$TEST_DIR"

echo ""
echo "============================================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================================"
[ $FAIL -eq 0 ] || exit 1
