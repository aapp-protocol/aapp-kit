#!/usr/bin/env bash
# ==============================================================================
# Tests: AI Attribution Suite, Switchboard, Hooks & Credits (P-14)
# ==============================================================================
set -e

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

source "$KIT/tests/test_helpers.sh"

TEST_DIR=$(mktemp -d /tmp/aapp-attribution-test-XXXXXX)
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

# ==============================================================================
echo "== 1. Safe-by-Default Configuration & Hook Installation =="
# ==============================================================================

ATTR_MODE="$(git config aapp.aiAttribution 2>/dev/null || echo "")"
if [ "$ATTR_MODE" = "none" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "default attribution mode is 'none'" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want 'none' got '%s'\n" "default attribution mode is 'none'" "$ATTR_MODE"; FAIL=$((FAIL+1))
fi

CREDITS_CFG="$(git config aapp.aiCredits 2>/dev/null || echo "")"
if [ "$CREDITS_CFG" = "false" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "default credits toggle is 'false'" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want 'false' got '%s'\n" "default credits toggle is 'false'" "$CREDITS_CFG"; FAIL=$((FAIL+1))
fi

HOOKS_OK=1
for h in commit-msg aapp-commit-msg post-commit aapp-post-commit; do
    if [ ! -x ".githooks/$h" ]; then
        HOOKS_OK=0
        break
    fi
done

if [ "$HOOKS_OK" -eq 1 ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "all commit-msg & post-commit hooks installed (+x)" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want executable hooks in .githooks/\n" "all commit-msg & post-commit hooks installed (+x)"; FAIL=$((FAIL+1))
fi

# ==============================================================================
echo "== 2. Switchboard State Transitions & Idempotency =="
# ==============================================================================

# Switch to commit mode
"$KIT/aapp" ai-commit >/dev/null
MODE="$(git config aapp.aiAttribution 2>/dev/null)"
if [ "$MODE" = "commit" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "aapp ai-commit sets mode to 'commit'" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want 'commit' got '%s'\n" "aapp ai-commit sets mode to 'commit'" "$MODE"; FAIL=$((FAIL+1))
fi

# Switch to notes mode
"$KIT/aapp" ai-notes >/dev/null
MODE="$(git config aapp.aiAttribution 2>/dev/null)"
REWRITE_REF="$(git config --get-all notes.rewriteRef 2>/dev/null || echo "")"
MERGE_STRAT="$(git config notes.mergeStrategy 2>/dev/null || echo "")"
if [ "$MODE" = "notes" ] && [ "$REWRITE_REF" = "refs/notes/commits" ] && [ "$MERGE_STRAT" = "cat_sort_uniq" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "aapp ai-notes configures rewriteRef & mergeStrategy" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s mode=%s rewriteRef=%s strat=%s\n" "aapp ai-notes configures rewriteRef & mergeStrategy" "$MODE" "$REWRITE_REF" "$MERGE_STRAT"; FAIL=$((FAIL+1))
fi

# Test refspec idempotency
"$KIT/aapp" ai-notes >/dev/null
"$KIT/aapp" ai-notes >/dev/null
PUSH_REFS="$(git config --get-all remote.origin.push 2>/dev/null | wc -l || echo 0)"
FETCH_REFS="$(git config --get-all remote.origin.fetch 2>/dev/null | wc -l || echo 0)"
if [ "$PUSH_REFS" -eq 2 ] && [ "$FETCH_REFS" -eq 2 ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "repeated ai-notes preserves idempotent refspecs" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want push=2 fetch=2 got push=%s fetch=%s\n" "repeated ai-notes preserves idempotent refspecs" "$PUSH_REFS" "$FETCH_REFS"; FAIL=$((FAIL+1))
fi

# Switch to off
"$KIT/aapp" ai-off >/dev/null
MODE="$(git config aapp.aiAttribution 2>/dev/null)"
CREDITS_TOGGLE="$(git config aapp.aiCredits 2>/dev/null)"
if [ "$MODE" = "none" ] && [ "$CREDITS_TOGGLE" = "false" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "aapp ai-off sets mode to 'none' and credits false" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want mode=none credits=false got mode=%s credits=%s\n" "aapp ai-off sets mode to 'none' and credits false" "$MODE" "$CREDITS_TOGGLE"; FAIL=$((FAIL+1))
fi

# aapp ai-status executes cleanly
if "$KIT/aapp" ai-status >/dev/null; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "aapp ai-status executes cleanly" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want exit 0\n" "aapp ai-status executes cleanly"; FAIL=$((FAIL+1))
fi

# ==============================================================================
echo "== 3. Commit-Msg Validation & Conciseness Invariant =="
# ==============================================================================

run_commit_msg() {
    local msg_file="$1"
    "$TEST_DIR/.githooks/aapp-commit-msg" "$msg_file"
}

# 3a. Subject length: <= 72 chars passes, > 72 chars blocked
cat > "$TEST_DIR/msg_ok.txt" << 'EOF'
feat: add concise subject within seventy two chars limit

This is a valid body.
EOF

if run_commit_msg "$TEST_DIR/msg_ok.txt" >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "subject <= 72 chars passes commit-msg" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want PASS got FAIL\n" "subject <= 72 chars passes commit-msg"; FAIL=$((FAIL+1))
fi

cat > "$TEST_DIR/msg_too_long.txt" << 'EOF'
feat: add concise subject that intentionally exceeds seventy two characters limit by continuing further

This should fail subject validation.
EOF

if ! run_commit_msg "$TEST_DIR/msg_too_long.txt" >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "subject > 72 chars blocked by conciseness rule" "BLOCK"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want BLOCK got PASS\n" "subject > 72 chars blocked by conciseness rule"; FAIL=$((FAIL+1))
fi

# 3b. Custom aapp.subjectMaxLen
git config aapp.subjectMaxLen 50
cat > "$TEST_DIR/msg_len55.txt" << 'EOF'
feat: subject with 55 characters length exceeds fifty

Body.
EOF
if ! run_commit_msg "$TEST_DIR/msg_len55.txt" >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "custom aapp.subjectMaxLen enforces lower limit" "BLOCK"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want BLOCK got PASS\n" "custom aapp.subjectMaxLen enforces lower limit"; FAIL=$((FAIL+1))
fi
git config --unset aapp.subjectMaxLen

# 3c. Banned Co-authored-by trailers
cat > "$TEST_DIR/msg_banned.txt" << 'EOF'
feat: valid subject

Co-authored-by: Antigravity <antigravity@google.com>
EOF

if ! run_commit_msg "$TEST_DIR/msg_banned.txt" >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "synthetic Co-authored-by email blocked across modes" "BLOCK"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want BLOCK got PASS\n" "synthetic Co-authored-by email blocked across modes"; FAIL=$((FAIL+1))
fi

# 3d. Attribution Mode Enforcements
# In 'none' mode: AI-Agent: trailer is blocked
git config aapp.aiAttribution none
cat > "$TEST_DIR/msg_agent.txt" << 'EOF'
feat: valid subject

AI-Agent: Claude
AI-Vendor: Anthropic
EOF

if ! run_commit_msg "$TEST_DIR/msg_agent.txt" >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "AI-Agent trailer blocked when attribution is 'none'" "BLOCK"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want BLOCK got PASS\n" "AI-Agent trailer blocked when attribution is 'none'"; FAIL=$((FAIL+1))
fi

# In 'commit' mode: commit without AI-Agent is blocked
git config aapp.aiAttribution commit
if ! run_commit_msg "$TEST_DIR/msg_ok.txt" >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "commit mode requires AI-Agent trailer" "BLOCK"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want BLOCK got PASS\n" "commit mode requires AI-Agent trailer"; FAIL=$((FAIL+1))
fi

# In 'commit' mode: valid AI-Agent trailer passes
if run_commit_msg "$TEST_DIR/msg_agent.txt" >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "valid semantic trailers pass in commit mode" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want PASS got FAIL\n" "valid semantic trailers pass in commit mode"; FAIL=$((FAIL+1))
fi

# 3e. Git revert bypass
cat > "$TEST_DIR/msg_revert.txt" << 'EOF'
Revert "feat: previous commit"

This reverts commit 1234567890abcdef1234567890abcdef12345678.
EOF

if run_commit_msg "$TEST_DIR/msg_revert.txt" >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "revert commit bypasses attribution requirements" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want PASS got FAIL\n" "revert commit bypasses attribution requirements"; FAIL=$((FAIL+1))
fi

# ==============================================================================
echo "== 4. Option C Staged Notes & Post-Commit Hook =="
# ==============================================================================

git config aapp.aiAttribution notes
# Use pass-through pre-commit for isolated commit testing
echo '#!/bin/sh' > .githooks/pre-commit
echo 'exit 0' >> .githooks/pre-commit
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks

# 4a. Silent no-op when no note is staged
echo "content1" > file1.txt
git add file1.txt
git commit -m "chore: commit without staged note" >/dev/null
NOTE_EXISTS="$(git notes --ref=refs/notes/commits list HEAD 2>/dev/null || echo "")"
if [ -z "$NOTE_EXISTS" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "unstaged commit produces no note (silent no-op)" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s note attached unexpectedly: %s\n" "unstaged commit produces no note (silent no-op)" "$NOTE_EXISTS"; FAIL=$((FAIL+1))
fi

# 4b. Pre-stage note via ai-note --stage and verify byte-faithful attachment
COMMIT_MSG="feat: implement feature with staged note"
"$KIT/aapp" ai-note --stage --msg "$COMMIT_MSG" --agent "Antigravity" --vendor "Google" --model "gemini-1.5-pro" >/dev/null

MSG_HASH="$(echo "$COMMIT_MSG" | git stripspace --strip-comments | sha256sum | awk '{print $1}')"
NOTE_BUFFER="$(git rev-parse --git-path aapp_pending_note).$MSG_HASH"
if [ -f "$NOTE_BUFFER" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "ai-note --stage creates hash-keyed buffer file" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s missing buffer: %s\n" "ai-note --stage creates hash-keyed buffer file" "$NOTE_BUFFER"; FAIL=$((FAIL+1))
fi

echo "content2" > file2.txt
git add file2.txt
git commit -m "$COMMIT_MSG" >/dev/null

NOTE_CONTENT="$(git notes --ref=refs/notes/commits show HEAD 2>/dev/null || echo "")"
if echo "$NOTE_CONTENT" | grep -q "AI-Agent: Antigravity" && echo "$NOTE_CONTENT" | grep -q "AI-Model: gemini-1.5-pro"; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "post-commit attaches staged note to HEAD" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want Antigravity got: %s\n" "post-commit attaches staged note to HEAD" "$NOTE_CONTENT"; FAIL=$((FAIL+1))
fi

if [ ! -f "$NOTE_BUFFER" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "buffer unlinked atomically on success (&&)" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s buffer still present: %s\n" "buffer unlinked atomically on success (&&)" "$NOTE_BUFFER"; FAIL=$((FAIL+1))
fi

# 4c. Custom note content via --content
CUSTOM_MSG="feat: commit with custom note body"
"$KIT/aapp" ai-note --stage --msg "$CUSTOM_MSG" --content "Custom Benchmarking Payload: benchmark_id=42" >/dev/null
echo "content3" > file3.txt
git add file3.txt
git commit -m "$CUSTOM_MSG" >/dev/null

CUSTOM_NOTE="$(git notes --ref=refs/notes/commits show HEAD 2>/dev/null || echo "")"
if [ "$CUSTOM_NOTE" = "Custom Benchmarking Payload: benchmark_id=42" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "custom note body attached faithfully" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want custom body got: %s\n" "custom note body attached faithfully" "$CUSTOM_NOTE"; FAIL=$((FAIL+1))
fi

# 4d. Amend Durability: note survives git commit --amend via notes.rewriteRef
echo "content3_amended" >> file3.txt
git add file3.txt
git commit --amend --no-edit >/dev/null

AMENDED_NOTE="$(git notes --ref=refs/notes/commits show HEAD 2>/dev/null || echo "")"
if [ "$AMENDED_NOTE" = "Custom Benchmarking Payload: benchmark_id=42" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "note survives git commit --amend (rewriteRef)" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s note lost on amend, got: %s\n" "note survives git commit --amend (rewriteRef)" "$AMENDED_NOTE"; FAIL=$((FAIL+1))
fi

# 4e. Failure Safety: buffer preserved when attachment fails
FAIL_MSG="feat: intentional attachment failure test"
"$KIT/aapp" ai-note --stage --msg "$FAIL_MSG" --agent "Claude" >/dev/null
FAIL_HASH="$(echo "$FAIL_MSG" | git stripspace --strip-comments | sha256sum | awk '{print $1}')"
FAIL_BUFFER="$(git rev-parse --git-path aapp_pending_note).$FAIL_HASH"

# Block notes ref updates by creating lock directory
LOCK_FILE="$(git rev-parse --git-path refs/notes/commits.lock)"
mkdir -p "$LOCK_FILE"

echo "test_fail" > fail.txt
git add fail.txt
git commit -m "$FAIL_MSG" >/dev/null 2>&1 || true

rmdir "$LOCK_FILE" 2>/dev/null || true

if [ -f "$FAIL_BUFFER" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "buffer preserved when note attachment fails" "PASS"; PASS=$((PASS+1))
    rm -f "$FAIL_BUFFER"
else
    printf "  \033[31m✘\033[0m %-52s buffer was deleted despite failure\n" "buffer preserved when note attachment fails"; FAIL=$((FAIL+1))
fi

# 4f. Mismatch diagnostics & TTL cleanup
STALE_MSG="feat: uncommitted idea that aged out"
"$KIT/aapp" ai-note --stage --msg "$STALE_MSG" --agent "StaleAgent" >/dev/null
STALE_HASH="$(echo "$STALE_MSG" | git stripspace --strip-comments | sha256sum | awk '{print $1}')"
STALE_BUFFER="$(git rev-parse --git-path aapp_pending_note).$STALE_HASH"

# Age buffer file by 2 days (exceeds default TTL 1440m)
touch -d '2 days ago' "$STALE_BUFFER" 2>/dev/null || touch -t 202001010000 "$STALE_BUFFER" 2>/dev/null || true

echo "ttl_test" > ttl.txt
git add ttl.txt
git commit -m "chore: trigger ttl sweep" >/dev/null 2>&1

if [ ! -f "$STALE_BUFFER" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "expired note buffer reaped by post-commit TTL" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s stale buffer not reaped: %s\n" "expired note buffer reaped by post-commit TTL" "$STALE_BUFFER"; FAIL=$((FAIL+1))
    rm -f "$STALE_BUFFER"
fi

# ==============================================================================
echo "== 5. AI Contributors Footer Generation (ai-credits) =="
# ==============================================================================

# 5a. Mode Boundary: none and notes modes are no-ops
git config aapp.aiAttribution none
cat > README.md << 'EOF'
# Test Project
Initial readme content.
EOF

"$KIT/aapp" ai-credits >/dev/null 2>&1
if ! grep -q "<!-- AAPP-AI-CREDITS:START -->" README.md; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "credits block not generated in 'none' mode" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s block generated unexpectedly in none mode\n" "credits block not generated in 'none' mode"; FAIL=$((FAIL+1))
fi

git config aapp.aiAttribution notes
"$KIT/aapp" ai-credits >/dev/null 2>&1
if ! grep -q "<!-- AAPP-AI-CREDITS:START -->" README.md; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "credits block not generated in 'notes' mode (no-op)" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s block generated unexpectedly in notes mode\n" "credits block not generated in 'notes' mode (no-op)"; FAIL=$((FAIL+1))
fi

# Hand-maintained block in notes mode is preserved untouched
cat >> README.md << 'EOF'

<!-- AAPP-AI-CREDITS:START -->
## AI Contributors

The following AI coding agents contributed to this codebase — planning, code, and review.
Listed alphabetically; the ordering carries no meaning, and no division of work is implied.

- Claude (Anthropic)

Authorship of, and responsibility for, this code rest with its human contributors.
<!-- AAPP-AI-CREDITS:END -->
EOF

README_CHECKSUM="$(sha256sum README.md | awk '{print $1}')"
"$KIT/aapp" ai-credits >/dev/null 2>&1
NEW_CHECKSUM="$(sha256sum README.md | awk '{print $1}')"
if [ "$README_CHECKSUM" = "$NEW_CHECKSUM" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "notes mode preserves hand-maintained block" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s notes mode mutated README.md\n" "notes mode preserves hand-maintained block"; FAIL=$((FAIL+1))
fi

# 5b. Commit mode generation & LC_ALL=C ordering
git config aapp.aiAttribution commit
echo "code" > code.txt
git add code.txt
git commit -m "feat: first agent commit

AI-Agent: Antigravity
AI-Vendor: Google" >/dev/null

"$KIT/aapp" ai-credits >/dev/null 2>&1

# Verify union of existing (Claude) and commit trailer (Antigravity)
if grep -q -- "- Antigravity (Google)" README.md && grep -q -- "- Claude (Anthropic)" README.md; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "ai-credits creates union of existing + git history" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s missing expected contributors in README\n" "ai-credits creates union of existing + git history"; FAIL=$((FAIL+1))
fi

# Verify LC_ALL=C alphabetical ordering (Antigravity before Claude)
FIRST_AGENT="$(grep -E '^[[:space:]]*- ' README.md | head -n1 | sed -E 's/^[[:space:]]*- //')"
if [ "$FIRST_AGENT" = "Antigravity (Google)" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "credits roster sorted alphabetically (LC_ALL=C)" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want Antigravity (Google) got: %s\n" "credits roster sorted alphabetically (LC_ALL=C)" "$FIRST_AGENT"; FAIL=$((FAIL+1))
fi

# 5c. Byte-identical regeneration
README_PRE_REGEN="$(sha256sum README.md | awk '{print $1}')"
"$KIT/aapp" ai-credits >/dev/null 2>&1
README_POST_REGEN="$(sha256sum README.md | awk '{print $1}')"
if [ "$README_PRE_REGEN" = "$README_POST_REGEN" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "ai-credits regeneration is byte-identical" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s regeneration dirtying README.md\n" "ai-credits regeneration is byte-identical"; FAIL=$((FAIL+1))
fi

# 5d. Unparseable block refusal
cat > README.md << 'EOF'
<!-- AAPP-AI-CREDITS:START -->
Broken block missing end tag
EOF

if ! "$KIT/aapp" ai-credits >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "unparseable block refused without corrupting" "BLOCK"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want BLOCK got PASS\n" "unparseable block refused without corrupting"; FAIL=$((FAIL+1))
fi

# Inverted tags refusal
cat > README.md << 'EOF'
<!-- AAPP-AI-CREDITS:END -->
<!-- AAPP-AI-CREDITS:START -->
EOF
if ! "$KIT/aapp" ai-credits >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "inverted START/END tags refused" "BLOCK"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want BLOCK got PASS\n" "inverted START/END tags refused"; FAIL=$((FAIL+1))
fi

# 5e. Alias map merges duplicate identities
cat > README.md << 'EOF'
# Project
<!-- AAPP-AI-CREDITS:START -->
## AI Contributors

The following AI coding agents contributed to this codebase — planning, code, and review.
Listed alphabetically; the ordering carries no meaning, and no division of work is implied.

- Claude Code (Anthropic)

Authorship of, and responsibility for, this code rest with its human contributors.
<!-- AAPP-AI-CREDITS:END -->
EOF

git config --add aapp.aiAlias "Claude Code=Claude"
"$KIT/aapp" ai-credits >/dev/null 2>&1

if grep -q -- "- Claude (Anthropic)" README.md && ! grep -q -- "- Claude Code (Anthropic)" README.md; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "aapp.aiAlias merges duplicate/renamed identities" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s alias map failed to normalize identities\n" "aapp.aiAlias merges duplicate/renamed identities"; FAIL=$((FAIL+1))
fi

# 5f. aapp ai-off stops updating but leaves block intact
"$KIT/aapp" ai-off >/dev/null
BEFORE_OFF="$(sha256sum README.md | awk '{print $1}')"
"$KIT/aapp" ai-credits >/dev/null 2>&1
AFTER_OFF="$(sha256sum README.md | awk '{print $1}')"
if [ "$BEFORE_OFF" = "$AFTER_OFF" ] && grep -q "<!-- AAPP-AI-CREDITS:START -->" README.md; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "ai-off preserves existing credits block untouched" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s ai-off mutated or deleted block\n" "ai-off preserves existing credits block untouched"; FAIL=$((FAIL+1))
fi

echo ""
echo "============================================================"
echo "  AI Attribution Suite Tests: $PASS passed, $FAIL failed"
echo "============================================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
