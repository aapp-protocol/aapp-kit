#!/usr/bin/env bash
# ==============================================================================
# Tests: AI Attribution Suite, Switchboard, Hooks & Credits (P-14)
# ==============================================================================
set -e

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

source "$KIT/tests/test_helpers.sh"

SANDBOX_ROOT=$(mktemp -d /tmp/aapp-attribution-test-XXXXXX)
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

# test_setup_verbs_switch_modes: ai none/ai lax/ai strict/ai notes set the value
"$KIT/aapp" ai lax >/dev/null 2>&1 || true
MODE_LAX="$(git config aapp.aiAttribution 2>/dev/null)"

"$KIT/aapp" ai strict >/dev/null 2>&1 || true
MODE_STRICT="$(git config aapp.aiAttribution 2>/dev/null)"

"$KIT/aapp" ai notes >/dev/null 2>&1 || true
MODE_NOTES="$(git config aapp.aiAttribution 2>/dev/null)"
REWRITE_REF="$(git config --get-all notes.rewriteRef 2>/dev/null || echo "")"
MERGE_STRAT="$(git config notes.mergeStrategy 2>/dev/null || echo "")"

"$KIT/aapp" ai none >/dev/null 2>&1 || true
MODE_NONE="$(git config aapp.aiAttribution 2>/dev/null)"
CREDITS_TOGGLE="$(git config aapp.aiCredits 2>/dev/null)"

if [ "$MODE_LAX" = "lax" ] && [ "$MODE_STRICT" = "strict" ] && \
   [ "$MODE_NOTES" = "notes" ] && [ "$REWRITE_REF" = "refs/notes/commits" ] && [ "$MERGE_STRAT" = "cat_sort_uniq" ] && \
   [ "$MODE_NONE" = "none" ] && [ "$CREDITS_TOGGLE" = "false" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "test_setup_verbs_switch_modes: verbs switch modes" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s switchboard modes failed\n" "test_setup_verbs_switch_modes: verbs switch modes"; FAIL=$((FAIL+1))
fi

# Test that ai notes does not clobber or configure remote refspecs (#91)
"$KIT/aapp" ai notes >/dev/null 2>&1 || true
"$KIT/aapp" ai notes >/dev/null 2>&1 || true
PUSH_REFS="$(git config --get-all remote.origin.push 2>/dev/null || true)"
FETCH_REFS="$(git config --get-all remote.origin.fetch 2>/dev/null || true)"
if [ -z "$PUSH_REFS" ] && [ -z "$FETCH_REFS" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "ai notes leaves remote refspecs untouched" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want empty push/fetch got push=%s fetch=%s\n" "ai notes leaves remote refspecs untouched" "$PUSH_REFS" "$FETCH_REFS"; FAIL=$((FAIL+1))
fi

# aapp ai status executes cleanly
if "$KIT/aapp" ai status >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "aapp ai status executes cleanly" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want exit 0\n" "aapp ai status executes cleanly"; FAIL=$((FAIL+1))
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

# 3c. test_banned_coauthor_rejected_in_every_mode: prohibited in none, lax, strict, notes
cat > "$TEST_DIR/msg_banned.txt" << 'EOF'
feat: valid subject

Co-authored-by: Antigravity <antigravity@google.com>
EOF

banned_every_mode=1
for m in none lax strict notes; do
    git config aapp.aiAttribution "$m"
    if run_commit_msg "$TEST_DIR/msg_banned.txt" >/dev/null 2>&1; then
        banned_every_mode=0
        break
    fi
done

if [ "$banned_every_mode" -eq 1 ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "test_banned_coauthor_rejected_in_every_mode" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s failed in mode $m\n" "test_banned_coauthor_rejected_in_every_mode"; FAIL=$((FAIL+1))
fi

# 3d. Attribution Mode Enforcements
cat > "$TEST_DIR/msg_agent_full.txt" << 'EOF'
feat: valid subject

AI-Agent: Claude
AI-Vendor: Anthropic
AI-Model: claude-3-5-sonnet
EOF

cat > "$TEST_DIR/msg_agent_partial.txt" << 'EOF'
feat: valid subject

AI-Agent: Claude
EOF

# In 'none' mode: AI trailers are blocked
git config aapp.aiAttribution none
if ! run_commit_msg "$TEST_DIR/msg_agent_full.txt" >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "AI trailers blocked when attribution is 'none'" "BLOCK"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want BLOCK got PASS\n" "AI trailers blocked when attribution is 'none'"; FAIL=$((FAIL+1))
fi

# test_lax_accepts_human_commit: lax mode accepts commit without trailers
git config aapp.aiAttribution lax
if run_commit_msg "$TEST_DIR/msg_ok.txt" >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "test_lax_accepts_human_commit: no trailers passes in lax" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want PASS got FAIL\n" "test_lax_accepts_human_commit: no trailers passes in lax"; FAIL=$((FAIL+1))
fi

# test_lax_validates_present_trailers: lax mode validates present trailers (malformed refused, valid accepted)
lax_val_ok=1
if ! run_commit_msg "$TEST_DIR/msg_agent_partial.txt" >/dev/null 2>&1; then
    : # partial trailer correctly refused
else
    lax_val_ok=0
fi
if run_commit_msg "$TEST_DIR/msg_agent_full.txt" >/dev/null 2>&1; then
    : # full valid trailers accepted
else
    lax_val_ok=0
fi
if [ "$lax_val_ok" -eq 1 ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "test_lax_validates_present_trailers" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s lax validation of present trailers failed\n" "test_lax_validates_present_trailers"; FAIL=$((FAIL+1))
fi

# test_strict_requires_trailers: strict mode refuses trailerless commit, prints hints
git config aapp.aiAttribution strict
strict_out=$(run_commit_msg "$TEST_DIR/msg_ok.txt" 2>&1 || true)
if ! run_commit_msg "$TEST_DIR/msg_ok.txt" >/dev/null 2>&1 && echo "$strict_out" | grep -q "aapp ai lax"; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "test_strict_requires_trailers" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want refusal with ai lax hint\n" "test_strict_requires_trailers"; FAIL=$((FAIL+1))
fi

# test_strict_accepts_valid_trailers: strict mode accepts valid 3 trailers
if run_commit_msg "$TEST_DIR/msg_agent_full.txt" >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "test_strict_accepts_valid_trailers" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want PASS in strict mode\n" "test_strict_accepts_valid_trailers"; FAIL=$((FAIL+1))
fi

# test_retired_commit_mode_refuses: retired commit mode refused, naming ai lax / ai strict
git config aapp.aiAttribution commit
retired_commit_out=$(run_commit_msg "$TEST_DIR/msg_agent_full.txt" 2>&1 || true)
if ! run_commit_msg "$TEST_DIR/msg_agent_full.txt" >/dev/null 2>&1 && echo "$retired_commit_out" | grep -qiE 'ai lax|ai strict'; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "test_retired_commit_mode_refuses" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want refusal naming ai lax/ai strict\n" "test_retired_commit_mode_refuses"; FAIL=$((FAIL+1))
fi

# 3e. Git revert bypass
cat > "$TEST_DIR/msg_revert.txt" << 'EOF'
Revert "feat: previous commit"

This reverts commit 1234567890abcdef1234567890abcdef12345678.
EOF

git config aapp.aiAttribution strict
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

# 4b. Pre-stage note via note stage and verify byte-faithful attachment
COMMIT_MSG="feat: implement feature with staged note"
"$KIT/aapp" note stage msg "$COMMIT_MSG" agent "Antigravity" vendor "Google" model "gemini-1.5-pro" >/dev/null

MSG_HASH="$(echo "$COMMIT_MSG" | git stripspace --strip-comments | sha256sum | awk '{print $1}')"
NOTE_BUFFER="$(git rev-parse --git-path aapp_pending_note).$MSG_HASH"
if [ -f "$NOTE_BUFFER" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "note stage creates hash-keyed buffer file" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s missing buffer: %s\n" "note stage creates hash-keyed buffer file" "$NOTE_BUFFER"; FAIL=$((FAIL+1))
fi

echo "content2" > file2.txt
git add file2.txt
git commit -m "$COMMIT_MSG" >/dev/null

NOTE_CONTENT="$(git notes --ref=refs/notes/ai show HEAD 2>/dev/null || echo "")"
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

# 4c. Custom note content via note stage
CUSTOM_MSG="feat: commit with custom note body"
"$KIT/aapp" note stage "Custom Benchmarking Payload: benchmark_id=42" msg "$CUSTOM_MSG" >/dev/null
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
"$KIT/aapp" note stage msg "$FAIL_MSG" agent "Claude" >/dev/null
FAIL_HASH="$(echo "$FAIL_MSG" | git stripspace --strip-comments | sha256sum | awk '{print $1}')"
FAIL_BUFFER="$(git rev-parse --git-path aapp_pending_note).$FAIL_HASH"

# Block notes ref updates by creating lock directory
LOCK_FILE="$(git rev-parse --git-path refs/notes/ai.lock)"
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
"$KIT/aapp" note stage msg "$STALE_MSG" agent "StaleAgent" >/dev/null
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

"$KIT/aapp" ai credits >/dev/null 2>&1
if ! grep -q "<!-- AAPP-AI-CREDITS:START -->" README.md; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "credits block not generated in 'none' mode" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s block generated unexpectedly in none mode\n" "credits block not generated in 'none' mode"; FAIL=$((FAIL+1))
fi

git config aapp.aiAttribution notes
"$KIT/aapp" ai credits >/dev/null 2>&1
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
"$KIT/aapp" ai credits >/dev/null 2>&1
NEW_CHECKSUM="$(sha256sum README.md | awk '{print $1}')"
if [ "$README_CHECKSUM" = "$NEW_CHECKSUM" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "notes mode preserves hand-maintained block" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s notes mode mutated README.md\n" "notes mode preserves hand-maintained block"; FAIL=$((FAIL+1))
fi

# 5b. Public trailer mode generation & LC_ALL=C ordering
git config aapp.aiAttribution strict
echo "code" > code.txt
git add code.txt
git commit -m "feat: first agent commit

AI-Agent: Antigravity
AI-Vendor: Google
AI-Model: gemini-1.5-pro" >/dev/null

"$KIT/aapp" ai credits >/dev/null 2>&1

# Verify union of existing (Claude) and commit trailer (Antigravity)
if grep -q -- "- Antigravity (Google)" README.md && grep -q -- "- Claude (Anthropic)" README.md; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "ai credits creates union of existing + git history" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s missing expected contributors in README\n" "ai credits creates union of existing + git history"; FAIL=$((FAIL+1))
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
"$KIT/aapp" ai credits >/dev/null 2>&1
README_POST_REGEN="$(sha256sum README.md | awk '{print $1}')"
if [ "$README_PRE_REGEN" = "$README_POST_REGEN" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "ai credits regeneration is byte-identical" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s regeneration dirtying README.md\n" "ai credits regeneration is byte-identical"; FAIL=$((FAIL+1))
fi

# 5d. Unparseable block refusal
cat > README.md << 'EOF'
<!-- AAPP-AI-CREDITS:START -->
Broken block missing end tag
EOF

if ! "$KIT/aapp" ai credits >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "unparseable block refused without corrupting" "BLOCK"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want BLOCK got PASS\n" "unparseable block refused without corrupting"; FAIL=$((FAIL+1))
fi

# Inverted tags refusal
cat > README.md << 'EOF'
<!-- AAPP-AI-CREDITS:END -->
<!-- AAPP-AI-CREDITS:START -->
EOF
if ! "$KIT/aapp" ai credits >/dev/null 2>&1; then
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
"$KIT/aapp" ai credits >/dev/null 2>&1

if grep -q -- "- Claude (Anthropic)" README.md && ! grep -q -- "- Claude Code (Anthropic)" README.md; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "aapp.aiAlias merges duplicate/renamed identities" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s alias map failed to normalize identities\n" "aapp.aiAlias merges duplicate/renamed identities"; FAIL=$((FAIL+1))
fi

# 5f. aapp ai none stops updating but leaves block intact
"$KIT/aapp" ai none >/dev/null
BEFORE_OFF="$(sha256sum README.md | awk '{print $1}')"
"$KIT/aapp" ai credits >/dev/null 2>&1
AFTER_OFF="$(sha256sum README.md | awk '{print $1}')"
if [ "$BEFORE_OFF" = "$AFTER_OFF" ] && grep -q "<!-- AAPP-AI-CREDITS:START -->" README.md; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "ai none preserves existing credits block untouched" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s ai none mutated or deleted block\n" "ai none preserves existing credits block untouched"; FAIL=$((FAIL+1))
fi

# ==============================================================================
echo "== 6. Attribution Layer (lib/attribution.sh) =="
# ==============================================================================

if [ -f "$KIT/lib/attribution.sh" ]; then
    # shellcheck source=/dev/null
    source "$KIT/lib/attribution.sh"
fi

# 6a. test_identity_precedence: parameters beat environment beat worktree config; repository config is ignored
precedence_ok=1
if command -v resolve_ai_identity >/dev/null 2>&1; then
    # 1. Repo config set - should be ignored
    git config aapp.aiAgent "RepoAgent"
    git config aapp.aiVendor "RepoVendor"
    git config aapp.aiModel "RepoModel"

    # With nothing else, should resolve to empty (repo config ignored)
    id_repo="$(resolve_ai_identity "" "" "" "" 2>/dev/null || true)"
    [ -n "$id_repo" ] && precedence_ok=0

    # 2. Worktree config
    git config extensions.worktreeConfig true 2>/dev/null || true
    git config --worktree aapp.aiAgent "WkAgent" 2>/dev/null || true
    git config --worktree aapp.aiVendor "WkVendor" 2>/dev/null || true
    git config --worktree aapp.aiModel "WkModel" 2>/dev/null || true
    id_wk="$(resolve_ai_identity "" "" "" "" 2>/dev/null || true)"
    [[ "$id_wk" != *"WkAgent"* ]] && precedence_ok=0

    # 3. Environment beats worktree config
    id_env="$(AAPP_AGENT_NAME="EnvAgent" AAPP_AGENT_VENDOR="EnvVendor" AAPP_AGENT_MODEL="EnvModel" resolve_ai_identity "" "" "" "" 2>/dev/null || true)"
    [[ "$id_env" != *"EnvAgent"* ]] && precedence_ok=0

    # 4. Parameters beat environment
    id_param="$(AAPP_AGENT_NAME="EnvAgent" AAPP_AGENT_VENDOR="EnvVendor" AAPP_AGENT_MODEL="EnvModel" resolve_ai_identity "ParamAgent" "ParamVendor" "ParamModel" "" 2>/dev/null || true)"
    [[ "$id_param" != *"ParamAgent"* ]] && precedence_ok=0

    # Clean up configs
    git config --unset aapp.aiAgent 2>/dev/null || true
    git config --unset aapp.aiVendor 2>/dev/null || true
    git config --unset aapp.aiModel 2>/dev/null || true
    git config --worktree --unset aapp.aiAgent 2>/dev/null || true
    git config --worktree --unset aapp.aiVendor 2>/dev/null || true
    git config --worktree --unset aapp.aiModel 2>/dev/null || true
else
    precedence_ok=0
fi

if [ "$precedence_ok" -eq 1 ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "test_identity_precedence" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s identity precedence failed\n" "test_identity_precedence"; FAIL=$((FAIL+1))
fi

# 6b. test_coauthor_converted_with_warning: resolve_ai_identity turns a Co-Authored-By into emailless trailers and warns
coauthor_ok=1
if command -v resolve_ai_identity >/dev/null 2>&1; then
    cat > "$TEST_DIR/msg_coauthor.txt" << 'EOF'
feat: test subject

Co-authored-by: Claude <noreply.anthropic.com>
EOF
    warn_out=$(resolve_ai_identity "" "" "" "$TEST_DIR/msg_coauthor.txt" 2>&1 > "$TEST_DIR/coauthor_id.txt" || true)
    coauthor_id=$(cat "$TEST_DIR/coauthor_id.txt")
    if ! echo "$warn_out" | grep -qi "warning"; then
        coauthor_ok=0
    fi
    if [[ "$coauthor_id" != *"Claude"* ]]; then
        coauthor_ok=0
    fi
else
    coauthor_ok=0
fi
if [ "$coauthor_ok" -eq 1 ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "test_coauthor_converted_with_warning" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s coauthor conversion failed\n" "test_coauthor_converted_with_warning"; FAIL=$((FAIL+1))
fi

# 6c. test_strict_decorate_without_identity_exits_1: attribution_decorate in strict with no identity exits 1
strict_dec_ok=0
if command -v attribution_decorate >/dev/null 2>&1; then
    git config aapp.aiAttribution strict
    cp "$TEST_DIR/msg_ok.txt" "$TEST_DIR/msg_to_decorate.txt"
    if ! attribution_decorate "$TEST_DIR/msg_to_decorate.txt" "" >/dev/null 2>&1; then
        strict_dec_ok=1
    fi
fi
if [ "$strict_dec_ok" -eq 1 ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "test_strict_decorate_without_identity_exits_1" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s strict decoration without identity should exit 1\n" "test_strict_decorate_without_identity_exits_1"; FAIL=$((FAIL+1))
fi

# 6d. test_note_text_without_identity_exits_1: notes mode, text but no identity exits 1 with stderr
note_text_ok=0
if command -v attribution_note >/dev/null 2>&1; then
    git config aapp.aiAttribution notes
    dummy_sha="$(git rev-parse HEAD)"
    note_err=$(attribution_note "$dummy_sha" "" "some text" 2>&1 || true)
    if [ -n "$note_err" ]; then
        if ! attribution_note "$dummy_sha" "" "some text" >/dev/null 2>&1; then
            note_text_ok=1
        fi
    fi
fi
if [ "$note_text_ok" -eq 1 ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "test_note_text_without_identity_exits_1" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s notes mode text without identity should exit 1\n" "test_note_text_without_identity_exits_1"; FAIL=$((FAIL+1))
fi

# 6e. test_note_identity_only_passes: notes mode, identity and no text writes note without warning
note_id_ok=0
if command -v attribution_note >/dev/null 2>&1; then
    git config aapp.aiAttribution notes
    dummy_sha="$(git rev-parse HEAD)"
    if attribution_note "$dummy_sha" "Claude (Anthropic)" "" >/dev/null 2>&1; then
        note_id_ok=1
    fi
fi
if [ "$note_id_ok" -eq 1 ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "test_note_identity_only_passes" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s notes mode identity only failed\n" "test_note_identity_only_passes"; FAIL=$((FAIL+1))
fi

print_test_summary "$PASS" "$FAIL"


