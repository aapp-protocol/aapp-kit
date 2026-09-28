#!/usr/bin/env bash
# ==============================================================================
# Tests: Git Notes Subsystem Integration Suite (P-44)
#
# Covers:
#   1. Two-ref isolation (refs/notes/commits vs refs/notes/ai)
#   2. Appending without data loss on amend
#   3. aapp.notesRemote push and pull with union merge
#   4. Fail closed on manual merge conflicts
#   5. aapp.aiNotesGuard enforcement of lossless settings (warn vs enforce)
# ==============================================================================
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/repo1"
cd "$R/repo1" || exit 1

echo "== 1. Two-Ref Isolation (commits vs ai) =="

# 1a. Stage general developer note
echo "alpha" > alpha.txt; git add alpha.txt
aapp note stage "Peer review: looks good" msg "feat: commit alpha" >/dev/null 2>&1
git commit -m "feat: commit alpha" >/dev/null 2>&1
SHA_ALPHA="$(git rev-parse HEAD)"

# Check that note is in refs/notes/commits and NOT in refs/notes/ai
COMMITS_NOTE="$(git notes --ref=refs/notes/commits show "$SHA_ALPHA" 2>/dev/null || true)"
AI_NOTE="$(git notes --ref=refs/notes/ai show "$SHA_ALPHA" 2>/dev/null || true)"

if echo "$COMMITS_NOTE" | grep -q "Peer review: looks good" && [ -z "$AI_NOTE" ]; then
    ok "general note attaches to refs/notes/commits"
else
    bad "general note attaches to refs/notes/commits" "commits='$COMMITS_NOTE' ai='$AI_NOTE'"
fi

# 1b. Stage AI attribution trace note
echo "beta" > beta.txt; git add beta.txt
aapp note stage "Benchmark score: 98.4%" msg "feat: commit beta" agent "Claude" vendor "Anthropic" model "claude-3-5" >/dev/null 2>&1
git commit -m "feat: commit beta" >/dev/null 2>&1
SHA_BETA="$(git rev-parse HEAD)"

COMMITS_NOTE_BETA="$(git notes --ref=refs/notes/commits show "$SHA_BETA" 2>/dev/null || true)"
AI_NOTE_BETA="$(git notes --ref=refs/notes/ai show "$SHA_BETA" 2>/dev/null || true)"

if [ -z "$COMMITS_NOTE_BETA" ] && echo "$AI_NOTE_BETA" | grep -q "AI-Agent: Claude" && echo "$AI_NOTE_BETA" | grep -q "Benchmark score"; then
    ok "AI note attaches to refs/notes/ai"
else
    bad "AI note attaches to refs/notes/ai" "commits='$COMMITS_NOTE_BETA' ai='$AI_NOTE_BETA'"
fi

# 1c. Removing general note leaves AI note untouched
# Add an AI note to alpha commit as well
aapp note status >/dev/null 2>&1
source "$KIT/lib/attribution.sh"
attribution_note "$SHA_ALPHA" "Claude (Anthropic)" "Model: test" >/dev/null 2>&1
git notes --ref=refs/notes/commits remove "$SHA_ALPHA" >/dev/null 2>&1 || true

ALPHA_COMMITS_AFTER="$(git notes --ref=refs/notes/commits show "$SHA_ALPHA" 2>/dev/null || true)"
ALPHA_AI_AFTER="$(git notes --ref=refs/notes/ai show "$SHA_ALPHA" 2>/dev/null || true)"

if [ -z "$ALPHA_COMMITS_AFTER" ] && echo "$ALPHA_AI_AFTER" | grep -q "AI-Agent: Claude"; then
    ok "removing refs/notes/commits leaves refs/notes/ai intact"
else
    bad "removing refs/notes/commits leaves refs/notes/ai intact" "commits='$ALPHA_COMMITS_AFTER' ai='$ALPHA_AI_AFTER'"
fi

echo "== 2. Appending Without Data Loss on Amend =="

# 2a. Note appending on existing note
attribution_note "$SHA_BETA" "Antigravity (Google)" "Secondary review: pass" >/dev/null 2>&1
BETA_COMBINED="$(git notes --ref=refs/notes/ai show "$SHA_BETA" 2>/dev/null || true)"

if echo "$BETA_COMBINED" | grep -q "Claude" && echo "$BETA_COMBINED" | grep -q "Antigravity"; then
    ok "attribution_note appends without overwriting existing note"
else
    bad "attribution_note appends without overwriting existing note" "got: $BETA_COMBINED"
fi

# 2b. Post-commit rewriteRef copies note on amend
git config notes.rewriteMode concatenate
git config --add notes.rewriteRef "refs/notes/ai" 2>/dev/null || true
echo "beta amendment" >> beta.txt; git add beta.txt
git commit --amend -m "feat: commit beta amended" >/dev/null 2>&1
SHA_BETA_AMENDED="$(git rev-parse HEAD)"

AMENDED_NOTE="$(git notes --ref=refs/notes/ai show "$SHA_BETA_AMENDED" 2>/dev/null || true)"
if echo "$AMENDED_NOTE" | grep -q "AI-Agent: Claude"; then
    ok "amend preserves notes across rewriteRef"
else
    bad "amend preserves notes across rewriteRef" "amended note was empty"
fi

echo "== 3. aapp.notesRemote Push and Pull with Union Merge =="

# Set up bare upstream remote
git init --bare "$R/remote.git" >/dev/null 2>&1
git remote add origin "$R/remote.git" 2>/dev/null || true
git push -u origin develop:develop >/dev/null 2>&1 || git push origin HEAD:master >/dev/null 2>&1 || true

# 3a. aapp note push pushes notes refs
git config aapp.notesRemote origin
out_push="$(aapp note push 2>&1)"; rc_push=$?
REMOTE_AI_NOTE="$(git -C "$R/remote.git" notes --ref=refs/notes/ai show "$SHA_BETA_AMENDED" 2>/dev/null || true)"

if [ "$rc_push" -eq 0 ] && echo "$REMOTE_AI_NOTE" | grep -q "AI-Agent: Claude"; then
    ok "aapp note push pushes refs/notes/ai to remote"
else
    bad "aapp note push pushes refs/notes/ai to remote" "rc=$rc_push out=$out_push remote_note=$REMOTE_AI_NOTE"
fi

# 3b. Clone into repo2 and pull notes
init_sandbox_project "$R/repo2"
cd "$R/repo2" || exit 1
git remote add origin "$R/remote.git" 2>/dev/null || true
git config aapp.notesRemote origin
out_pull="$(aapp note pull 2>&1)"; rc_pull=$?
REPO2_AI_NOTE="$(git notes --ref=refs/notes/ai show "$SHA_BETA_AMENDED" 2>/dev/null || true)"

if [ "$rc_pull" -eq 0 ] && echo "$REPO2_AI_NOTE" | grep -q "AI-Agent: Claude"; then
    ok "aapp note pull retrieves remote notes into local refs"
else
    bad "aapp note pull retrieves remote notes into local refs" "rc=$rc_pull out=$out_pull repo2_note=$REPO2_AI_NOTE"
fi

# 3c. Union merge on divergent notes
# Repo1 adds note content
cd "$R/repo1"
git notes --ref=refs/notes/ai append -m "Note from Repo1" "$SHA_BETA_AMENDED" >/dev/null 2>&1
aapp note push >/dev/null 2>&1

# Repo2 adds different note content to same commit
cd "$R/repo2"
git notes --ref=refs/notes/ai append -m "Note from Repo2" "$SHA_BETA_AMENDED" >/dev/null 2>&1

# Repo2 pulls: union merge combines both
out_union="$(aapp note pull 2>&1)"; rc_union=$?
UNION_NOTE="$(git notes --ref=refs/notes/ai show "$SHA_BETA_AMENDED" 2>/dev/null || true)"

if [ "$rc_union" -eq 0 ] && echo "$UNION_NOTE" | grep -q "Note from Repo1" && echo "$UNION_NOTE" | grep -q "Note from Repo2"; then
    ok "aapp note pull executes union merge preserving both notes"
else
    bad "aapp note pull executes union merge preserving both notes" "rc=$rc_union note=$UNION_NOTE"
fi

echo "== 4. Fail Closed on Manual Merge Conflicts =="

# Configure manual merge strategy for refs/notes/commits
git config notes.commits.mergeStrategy manual

# Create conflict in commits ref
cd "$R/repo1"
git notes --ref=refs/notes/commits append -m "First party text" "$SHA_BETA_AMENDED" >/dev/null 2>&1
aapp note push >/dev/null 2>&1

cd "$R/repo2"
git notes --ref=refs/notes/commits append -m "Conflicting second party text" "$SHA_BETA_AMENDED" >/dev/null 2>&1

out_conflict="$(aapp note pull 2>&1)"; rc_conflict=$?
if [ "$rc_conflict" -ne 0 ] && echo "$out_conflict" | grep -qiE '(conflict|git notes merge --commit)'; then
    ok "manual merge conflict fails closed with diagnostic"
    # Abort the conflicting merge to restore clean state
    git notes merge --abort 2>/dev/null || true
else
    bad "manual merge conflict fails closed with diagnostic" "rc=$rc_conflict out=$out_conflict"
fi

echo "== 5. aapp.aiNotesGuard Enforcement (warn vs enforce) =="

cd "$R/repo1"
# 5a. Lossy strategy triggers advisory warning under warn
git config aapp.aiNotesGuard warn
git config notes.ai.mergeStrategy cat_sort_uniq

out_warn="$(aapp note status 2>&1)"; rc_warn=$?
if [ "$rc_warn" -eq 0 ] && echo "$out_warn" | grep -q "Audit Guard: Advisory Warning"; then
    ok "lossy strategy under guard=warn produces advisory warning"
else
    bad "lossy strategy under guard=warn produces advisory warning" "rc=$rc_warn out=$out_warn"
fi

# 5b. Lossy strategy triggers refusal under enforce
git config aapp.aiNotesGuard enforce
out_enforce="$(aapp note status 2>&1)"; rc_enforce=$?
if [ "$rc_enforce" -ne 0 ] && echo "$out_enforce" | grep -q "Audit Guard: ENFORCE Violation"; then
    ok "lossy strategy under guard=enforce fails closed (exit 1)"
else
    bad "lossy strategy under guard=enforce fails closed (exit 1)" "rc=$rc_enforce out=$out_enforce"
fi

# 5c. Valid configuration passes under enforce
git config notes.ai.mergeStrategy union
git config notes.rewriteMode concatenate
out_valid="$(aapp note status 2>&1)"; rc_valid=$?
if [ "$rc_valid" -eq 0 ] && ! echo "$out_valid" | grep -q "Audit Guard: ENFORCE Violation"; then
    ok "lossless strategy under guard=enforce passes cleanly"
else
    bad "lossless strategy under guard=enforce passes cleanly" "rc=$rc_valid out=$out_valid"
fi

print_test_summary "$PASS" "$FAIL"
