#!/usr/bin/env bash
# ==============================================================================
# Tests: Worktree Hook Execution & Attribution Confinement (P-26)
# ==============================================================================
set -e

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

source "$KIT/tests/test_helpers.sh"

TEST_DIR=$(mktemp -d /tmp/aapp-worktree-hooks-test-XXXXXX)
trap 'rm -rf "$TEST_DIR"' EXIT

cd "$TEST_DIR"
git init -q
git branch -M main
setup_test_git_identity "$TEST_DIR"

# Setup AAPP via drop-in init
cp -r "$KIT" "$TEST_DIR/aapp-kit"
(
    cd "$TEST_DIR"
    ./aapp-kit/aapp init >/dev/null 2>&1
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

# Switch to commit attribution mode
(
    cd "$TEST_DIR"
    git config aapp.aiAttribution "commit"
)

# 4.1 In commit mode, missing AI-Agent trailer rejected in .plans
(
    cd "$TEST_DIR/.plans"
    echo "note2" >> pickup.md
    git add pickup.md
)
if (
    cd "$TEST_DIR/.plans"
    git commit -m "docs: missing AI trailer in commit mode" >/dev/null 2>&1
); then
    got="COMMITTED"
else
    got="BLOCKED"
fi
report "commit mode: missing AI-Agent trailer rejected in .plans" "BLOCKED" "$got"

# 4.2 In commit mode, valid AI trailers succeed in .plans
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
report "commit mode: valid AI trailers accepted in .plans" "PASS" "$got"

echo "== 5. Idempotent Re-Init and Stability =="

# Run aapp init again
(
    cd "$TEST_DIR"
    ./aapp-kit/aapp init >/dev/null 2>&1
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

echo ""
echo "============================================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================================"
[ $FAIL -eq 0 ] || exit 1
