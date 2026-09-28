#!/usr/bin/env bash
# Tests: `aapp note` behaviour contract (lib/docs/verbs/note.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1

echo "== note status =="
# 1. test_note_status_runs_cleanly
out="$(aapp note status 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q "AAPP Git Notes Subsystem Status"; then
  ok "test_note_status_runs_cleanly"
else
  bad "test_note_status_runs_cleanly" "rc=$rc out=$out"
fi

echo "== note stage =="
# 2. test_note_stage_requires_message
out="$(aapp note stage "Some note content" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qiE '(commit message.*required|planned commit)'; then
  ok "test_note_stage_requires_message"
else
  bad "test_note_stage_requires_message" "rc=$rc out=$out"
fi

# 3. test_note_stage_creates_buffer
commit_msg="feat: sample commit for notes"
out="$(aapp note stage "Developer review note" msg "$commit_msg" 2>&1)"; rc=$?
expected_hash="$(echo "$commit_msg" | git stripspace --strip-comments | sha256sum | awk '{print $1}')"
buffer_file=".git/aapp_pending_note.$expected_hash"
if [ "$rc" -eq 0 ] && [ -f "$buffer_file" ] && grep -q "Developer review note" "$buffer_file"; then
  ok "test_note_stage_creates_buffer"
else
  bad "test_note_stage_creates_buffer" "rc=$rc file=$buffer_file out=$out"
fi
rm -f "$buffer_file"

# 4. test_note_stage_ai_routes_to_ai_ref
out="$(aapp note stage "AI analysis text" msg "$commit_msg" agent "Claude" vendor "Anthropic" model "claude-3-5" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -f "$buffer_file" ] && grep -q "AI-Agent: Claude" "$buffer_file"; then
  ok "test_note_stage_ai_routes_to_ai_ref"
else
  bad "test_note_stage_ai_routes_to_ai_ref" "rc=$rc file=$buffer_file out=$out"
fi
rm -f "$buffer_file"

echo "== note push / pull refusals =="
# 5. test_note_push_refuses_without_remote
git config --unset aapp.notesRemote 2>/dev/null || true
out="$(aapp note push 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qiE 'No notes remote configured'; then
  ok "test_note_push_refuses_without_remote"
else
  bad "test_note_push_refuses_without_remote" "rc=$rc out=$out"
fi

# 6. test_note_pull_refuses_without_remote
out="$(aapp note pull 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qiE 'No notes remote configured'; then
  ok "test_note_pull_refuses_without_remote"
else
  bad "test_note_pull_refuses_without_remote" "rc=$rc out=$out"
fi

print_test_summary "$PASS" "$FAIL"
