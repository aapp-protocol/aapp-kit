#!/usr/bin/env bash
# Tests: `aapp commit` behaviour contract (lib/docs/verbs/commit.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1

draft_and_start_plan() {
  local slug="$1"
  aapp draft "$slug" >/dev/null 2>&1 || return 1
  local pf; pf="$(ls -t "$R/p/.plans/current/"*.md | head -1)"
  local pid; pid="$(grep -m1 -E '^\* \*\*Plan ID:\*\*' "$pf" | sed -E 's/^.*\*\*Plan ID:\*\*[[:space:]]*//' | tr -d '[:space:]')"
  # Make target file unique to avoid activation gate collisions
  sed -i -E "s|src/path/to/file.ext|src/${slug}.py|g; /src\/path\/to\/new_file\.ext/d" "$pf"
  sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$pf"
  git -C .plans commit -qam "prep $pid" >/dev/null
  aapp freeze-start "$pid" >/dev/null 2>&1 || return 1
  echo "$pid"
}

plan_file() { ls "$R/p/.plans/current/P${1#P-}-"*.md 2>/dev/null; }

echo "== commit refusals =="
# 1. test_refuses_without_active_plan
aapp active clear >/dev/null 2>&1
echo "change" > file.txt; git add file.txt
out="$(aapp commit "test commit" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -qiE '(No plan|active)'; then
  ok "test_refuses_without_active_plan"
else
  bad "test_refuses_without_active_plan" "rc=$rc out=$out"
fi
git reset -q file.txt; rm -f file.txt

# Start a plan
pid="$(draft_and_start_plan "test-feat")"
pf="$(plan_file "$pid")"

# 2. test_refuses_nothing_staged
out="$(aapp commit "empty index" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -qiE 'nothing staged'; then
  ok "test_refuses_nothing_staged"
else
  bad "test_refuses_nothing_staged" "rc=$rc out=$out"
fi

# 3. test_preflight_fails_before_code_commit (strict mode without identity)
aapp ai strict >/dev/null 2>&1
mkdir -p src
echo "# hello" > "src/test-feat.py"
echo "- hello" >> CHANGELOG.md
git add "src/test-feat.py" CHANGELOG.md
head_before="$(git rev-parse HEAD)"
# Clear any agent identity env
(
  unset AAPP_AGENT_NAME AAPP_AGENT_VENDOR AAPP_AGENT_MODEL
  out="$(aapp commit "feat: strict without id" 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ] && [ "$(git rev-parse HEAD)" = "$head_before" ]; then
    ok "test_preflight_fails_before_code_commit"
  else
    bad "test_preflight_fails_before_code_commit" "rc=$rc head moved or succeeded"
  fi
)
aapp ai lax >/dev/null 2>&1

# 4. test_rejected_commit_records_nothing
# Add a pre-commit hook that rejects
hooks_dir="$(git config core.hooksPath || echo .git/hooks)"
mkdir -p "$hooks_dir"
[ -f "$hooks_dir/pre-commit" ] && cp "$hooks_dir/pre-commit" "$hooks_dir/pre-commit.orig"
cat << 'EOF' > "$hooks_dir/pre-commit"
#!/bin/sh
echo "rejecting commit" >&2
exit 1
EOF
chmod +x "$hooks_dir/pre-commit"
out="$(aapp commit "will fail" 2>&1)"; rc=$?
if [ -f "$hooks_dir/pre-commit.orig" ]; then
  mv "$hooks_dir/pre-commit.orig" "$hooks_dir/pre-commit"
else
  rm -f "$hooks_dir/pre-commit"
fi
if [ "$rc" -ne 0 ] && ! grep -qF "will fail" "$pf"; then
  ok "test_rejected_commit_records_nothing"
else
  bad "test_rejected_commit_records_nothing" "rc=$rc"
fi

echo "== commit happy path =="
# 5. test_records_sha_and_branch
echo "- happy commit" >> CHANGELOG.md; git add CHANGELOG.md
out="$(aapp commit "feat: happy commit")"; rc=$?
sha="$(git rev-parse --short HEAD)"
curr_br="$(git rev-parse --abbrev-ref HEAD)"
if [ "$rc" -eq 0 ] && grep -qF "\`$sha\` ($curr_br)" "$pf" && \
   git -C .plans log -1 --format=%s | grep -qF "plan(record): record $sha for $pid"; then
  ok "test_records_sha_and_branch"
else
  bad "test_records_sha_and_branch" "rc=$rc sha=$sha pf=$(cat "$pf")"
fi

# 6. test_plan_commit_is_pathspec_limited
# Stage another file in .plans
echo "unrelated" > .plans/unrelated.txt
git -C .plans add unrelated.txt
mkdir -p src
echo "# more code" >> "src/test-feat.py"
echo "- second commit" >> CHANGELOG.md
git add "src/test-feat.py" CHANGELOG.md
aapp commit "feat: second code commit" >/dev/null 2>&1
sha2="$(git rev-parse --short HEAD)"
if git -C .plans diff --cached --name-only | grep -q "unrelated.txt"; then
  ok "test_plan_commit_is_pathspec_limited"
else
  bad "test_plan_commit_is_pathspec_limited" "unrelated.txt was swept into commit"
fi
git -C .plans reset -q HEAD unrelated.txt; rm -f .plans/unrelated.txt

# 7. test_amend_replaces_recorded_sha
echo "# amend fix" >> "src/test-feat.py"
echo "- amend fix" >> CHANGELOG.md
git add "src/test-feat.py" CHANGELOG.md
aapp commit amend "feat: second code commit amended" >/dev/null 2>&1; rc=$?
new_sha="$(git rev-parse --short HEAD)"
if [ "$rc" -eq 0 ] && grep -qF "\`$new_sha\` ($curr_br)" "$pf" && ! grep -qF "\`$sha2\`" "$pf"; then
  ok "test_amend_replaces_recorded_sha"
else
  bad "test_amend_replaces_recorded_sha" "rc=$rc new_sha=$new_sha"
fi

# 8. test_strict_attributes_both_commits
aapp ai strict >/dev/null 2>&1
echo "# strict change" >> "src/test-feat.py"
echo "- strict change" >> CHANGELOG.md
git add "src/test-feat.py" CHANGELOG.md
aapp commit "feat: strict commit" agent "TestBot" vendor "Vendor" model "Model-1" >/dev/null 2>&1; rc=$?
code_msg="$(git log -1 --format=%B)"
plan_msg="$(git -C .plans log -1 --format=%B)"
if [ "$rc" -eq 0 ] && echo "$code_msg" | grep -q "AI-Agent: TestBot" && echo "$plan_msg" | grep -q "AI-Agent: TestBot"; then
  ok "test_strict_attributes_both_commits"
else
  bad "test_strict_attributes_both_commits" "rc=$rc code=[$code_msg] plan=[$plan_msg]"
fi
aapp ai lax >/dev/null 2>&1

# 9. test_lax_human_commit_needs_no_identity
echo "# human change" >> "src/test-feat.py"
echo "- human change" >> CHANGELOG.md
git add "src/test-feat.py" CHANGELOG.md
(
  unset AAPP_AGENT_NAME AAPP_AGENT_VENDOR AAPP_AGENT_MODEL
  aapp commit "feat: human change" >/dev/null 2>&1; rc=$?
  code_msg="$(git log -1 --format=%B)"
  if [ "$rc" -eq 0 ] && ! echo "$code_msg" | grep -q "AI-Agent:"; then
    ok "test_lax_human_commit_needs_no_identity"
  else
    bad "test_lax_human_commit_needs_no_identity" "rc=$rc"
  fi
)

# 10. test_note_token_attached_in_notes_mode
aapp ai notes >/dev/null 2>&1
echo "# notes change" >> "src/test-feat.py"
echo "- notes change" >> CHANGELOG.md
git add "src/test-feat.py" CHANGELOG.md
aapp commit "feat: notes commit" agent "NoteBot" vendor "Vendor" model "Model-1" note "reviewed and signed" >/dev/null 2>&1; rc=$?
note_content="$(git notes show HEAD 2>/dev/null)"
if [ "$rc" -eq 0 ] && echo "$note_content" | grep -q "reviewed and signed"; then
  ok "test_note_token_attached_in_notes_mode"
else
  bad "test_note_token_attached_in_notes_mode" "rc=$rc note=[$note_content]"
fi

# 10b. test_note_token_attached_in_strict_mode
aapp ai strict >/dev/null 2>&1
echo "# strict note change" >> "src/test-feat.py"
echo "- strict note change" >> CHANGELOG.md
git add "src/test-feat.py" CHANGELOG.md
aapp commit "feat: strict with note" agent "StrictBot" vendor "Vendor" model "Model-S" note "parallel audit note" >/dev/null 2>&1; rc=$?
msg_body="$(git log -1 --pretty=%B)"
ai_note="$(git notes --ref=refs/notes/ai show HEAD 2>/dev/null)"
if [ "$rc" -eq 0 ] && echo "$msg_body" | grep -q "AI-Agent: StrictBot" && echo "$ai_note" | grep -q "parallel audit note"; then
  ok "test_note_token_attached_in_strict_mode"
else
  bad "test_note_token_attached_in_strict_mode" "rc=$rc msg=[$msg_body] note=[$ai_note]"
fi

# 10c. test_note_token_attached_in_none_mode
aapp ai none >/dev/null 2>&1
echo "# none note change" >> "src/test-feat.py"
echo "- none note change" >> CHANGELOG.md
git add "src/test-feat.py" CHANGELOG.md
aapp commit "feat: none with note" note "general review note" >/dev/null 2>&1; rc=$?
msg_body="$(git log -1 --pretty=%B)"
comm_note="$(git notes --ref=refs/notes/commits show HEAD 2>/dev/null)"
if [ "$rc" -eq 0 ] && ! echo "$msg_body" | grep -q "AI-Agent:" && echo "$comm_note" | grep -q "general review note"; then
  ok "test_note_token_attached_in_none_mode"
else
  bad "test_note_token_attached_in_none_mode" "rc=$rc msg=[$msg_body] note=[$comm_note]"
fi
aapp ai lax >/dev/null 2>&1


# 11. test_detached_head_recorded
orig_branch="$(git rev-parse --abbrev-ref HEAD)"
curr_head="$(git rev-parse HEAD)"
git checkout -q --detach "$curr_head"
mkdir -p src
echo "# detached change" >> "src/test-feat.py"
echo "- detached change" >> CHANGELOG.md
git add "src/test-feat.py" CHANGELOG.md
aapp commit "feat: detached commit" >/dev/null 2>&1; rc=$?
det_sha="$(git rev-parse --short HEAD)"
if [ "$rc" -eq 0 ] && grep -qF "\`$det_sha\` (detached)" "$pf"; then
  ok "test_detached_head_recorded"
else
  bad "test_detached_head_recorded" "rc=$rc pf=$(cat "$pf" 2>/dev/null)"
fi
git checkout -q "$orig_branch"

echo "== adopt repair ==="
mkdir -p src
echo "# raw change" >> "src/test-feat.py"
echo "- raw change" >> CHANGELOG.md
git add "src/test-feat.py" CHANGELOG.md
git commit -qm "raw git commit outside helper"
raw_sha="$(git rev-parse --short HEAD)"
out="$(aapp commit adopt "$raw_sha" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -qF "\`$raw_sha\` ($orig_branch)" "$pf" && echo "$out" | grep -qi "warning"; then
  ok "test_adopt_records_existing_commit"
else
  bad "test_adopt_records_existing_commit" "rc=$rc out=$out"
fi

# 13. test_adopt_refuses_unknown_sha
out="$(aapp commit adopt "deadbeef1234" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ]; then
  ok "test_adopt_refuses_unknown_sha"
else
  bad "test_adopt_refuses_unknown_sha" "rc=$rc"
fi

# 14. test_adopt_skips_recorded_sha
aapp commit adopt "$raw_sha" >/dev/null 2>&1
count="$(grep -oF "\`$raw_sha\`" "$pf" | wc -l)"
if [ "$count" -eq 1 ]; then
  ok "test_adopt_skips_recorded_sha"
else
  bad "test_adopt_skips_recorded_sha" "count=$count"
fi

echo "== linked worktree concurrency =="
# 15. test_linked_worktree_records_its_own_plan
pid2="$(draft_and_start_plan "second-feat")"
pf2="$(plan_file "$pid2")"
aapp active "$pid" >/dev/null 2>&1
# Create linked worktree for feat/wt2 branch
git worktree add -b feat/wt2 "$R/wt2" "$orig_branch" >/dev/null 2>&1
(
  cd "$R/wt2" || exit 1
  aapp active "$pid2" >/dev/null 2>&1
  mkdir -p src
  echo "# wt2 code" > "src/second-feat.py"
  echo "- wt2 code" >> CHANGELOG.md
  git add "src/second-feat.py" CHANGELOG.md
  aapp commit "feat: wt2 commit" >/dev/null 2>&1
  wt2_sha="$(git rev-parse --short HEAD)"
  if grep -qF "\`$wt2_sha\` (feat/wt2)" "$pf2" && ! grep -qF "\`$wt2_sha\`" "$pf"; then
    echo "PASS_WT2"
  else
    echo "wt2_sha=$wt2_sha pf2=$pf2 content=$(cat "$pf2" 2>/dev/null)"
  fi
) > "$R/wt2_out"

if grep -q "PASS_WT2" "$R/wt2_out"; then
  ok "test_linked_worktree_records_its_own_plan"
else
  bad "test_linked_worktree_records_its_own_plan" "linked worktree failed: $(cat "$R/wt2_out")"
fi

echo "== plan-declared changelog entry (P-48) =="
init_sandbox_project "$R/cl"
cd "$R/cl" || exit 1
R_SAVE="$R"; R="$R/cl/.."   # draft_and_start_plan reads "$R/p"; point plan lookups here
cl_plan_file() { ls "$R_SAVE/cl/.plans/current/P${1#P-}-"*.md 2>/dev/null; }
aapp draft entry-feat >/dev/null 2>&1
cpf="$(ls -t "$R_SAVE/cl/.plans/current/"*.md | head -1)"
cpid="$(grep -m1 -E '^\* \*\*Plan ID:\*\*' "$cpf" | sed -E 's/^.*\*\*Plan ID:\*\*[[:space:]]*//' | tr -d '[:space:]')"
sed -i -E "s|src/path/to/file.ext|src/entry.py|g; /src\/path\/to\/new_file\.ext/d" "$cpf"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$cpf"
sed -i -E 's/^(\* \*\*Changelog:\*\*).*/\1 Added: Entry feature works/' "$cpf"
git -C .plans commit -qam "prep $cpid" >/dev/null
aapp freeze-start "$cpid" >/dev/null 2>&1
R="$R_SAVE"
mkdir -p src
bullet="- Entry feature works (\`$cpid\`)"

echo "v1" > src/entry.py; git add src/entry.py
out="$(aapp commit "feat(entry): first" 2>&1)"; rc=$?
first_after_added="$(awk '/^### Added/{f=1; next} f && /^- /{print; exit}' CHANGELOG.md)"
if [ "$rc" -eq 0 ] && git show --name-only --format= HEAD | grep -qx "CHANGELOG.md" && \
   [ "$first_after_added" = "$bullet" ]; then
  ok "test_first_code_commit_writes_declared_entry"
else
  bad "test_first_code_commit_writes_declared_entry" "rc=$rc first=[$first_after_added] out=$out"
fi

echo "v2" > src/entry.py; git add src/entry.py
out="$(aapp commit "fix(entry): second" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && ! git show --name-only --format= HEAD | grep -qx "CHANGELOG.md" && \
   [ "$(grep -cF "(\`$cpid\`)" CHANGELOG.md)" -eq 1 ]; then
  ok "test_later_commit_leaves_changelog_alone"
else
  bad "test_later_commit_leaves_changelog_alone" "rc=$rc out=$out"
fi

sed -i -E 's/^(\* \*\*Changelog:\*\*).*/\1 Added: Entry feature reworded/' "$cpf"
aapp refine "$cpid" "reword changelog entry" >/dev/null 2>&1
echo "v3" > src/entry.py; git add src/entry.py
out="$(aapp commit "fix(entry): third" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -qxF -- "- Entry feature reworded (\`$cpid\`)" CHANGELOG.md && \
   ! grep -qF "Entry feature works" CHANGELOG.md && [ "$(grep -cF "(\`$cpid\`)" CHANGELOG.md)" -eq 1 ]; then
  ok "test_reworded_declaration_replaces_the_line"
else
  bad "test_reworded_declaration_replaces_the_line" "rc=$rc out=$out"
fi

print_test_summary "$PASS" "$FAIL"
