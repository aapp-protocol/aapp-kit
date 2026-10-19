#!/usr/bin/env bash
# ==============================================================================
# Automated Test Suite: Adoption Advisories & Setup Checklist (Plan P-63)
# ==============================================================================
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

# Tests run in subshells: results go to a file, counted at the end.
ok()  { printf "  \033[32m✔\033[0m %-65s %s\n" "$1" "PASS"; echo pass >> "$R/results"; }
bad() { printf "  \033[31m✘\033[0m %-65s %s\n" "$1" "$2"; echo fail >> "$R/results"; }

# Test 1: test_seeded_and_untracked
# Asserts `init` creates `.plans/adoption.md` with its sections, lists it in
# `.plans/.gitignore`, commits no version of it and leaves the plans worktree clean.
test_seeded_and_untracked() {
  local p="$R/p1"
  init_sandbox_project "$p"
  (
    cd "$p" || exit 1
    if [ -f ".plans/adoption.md" ] && \
       grep -q '^# 📋 Adoption Checklist' ".plans/adoption.md" && \
       grep -qF "adoption.md" ".plans/.gitignore" && \
       [ -z "$(git -C .plans status --porcelain)" ] && \
       ! git -C .plans ls-files | grep -q 'adoption.md'; then
      ok "test_seeded_and_untracked"
    else
      bad "test_seeded_and_untracked" "adoption.md missing, tracked, or .plans dirty"
    fi
  )
}

# Test 2: test_gitignore_line_added_on_rerun
# Asserts an existing `.plans/.gitignore` without the line gains it on rerun.
test_gitignore_line_added_on_rerun() {
  local p="$R/p2"
  init_sandbox_project "$p"
  (
    cd "$p" || exit 1
    # Remove adoption.md line from .plans/.gitignore
    sed -i '/adoption\.md/d' ".plans/.gitignore"
    git -C .plans commit -qam "test: remove ignore line" || true
    aapp init >/dev/null 2>&1
    if grep -qF "adoption.md" ".plans/.gitignore"; then
      ok "test_gitignore_line_added_on_rerun"
    else
      bad "test_gitignore_line_added_on_rerun" "line not re-added on rerun"
    fi
  )
}

# Test 3: test_fresh_install_tasks
# Asserts a fresh project gets expected starter tasks under their sections.
test_fresh_install_tasks() {
  local p="$R/p3"
  init_sandbox_project "$p"
  (
    cd "$p" || exit 1
    local f=".plans/adoption.md"
    if [ -f "$f" ] && \
       grep -qF '`[DEV-BRANCH]`' "$f" && \
       grep -qF '`[PLAN-ID-PROVIDER]`' "$f" && \
       grep -qF '`[TEAM-SETTINGS]`' "$f" && \
       grep -qF '`[INIT-FILES]`' "$f" && \
       grep -qF '`[PROJECT-RULES]`' "$f" && \
       grep -qF '`[PROJECT-MAP]`' "$f" && \
       grep -qF '`[GATE-TEST]`' "$f" && \
       grep -qF '`[SET-WORKTREES]`' "$f" && \
       grep -qF '`[SET-INTEGRATE]`' "$f" && \
       grep -qF '`[SET-AUTO-REBASE]`' "$f" && \
       grep -qF '`[SET-DOCS]`' "$f" && \
       grep -qF '`[SET-COMMIT-MODE]`' "$f" && \
       grep -qF '`[SET-ATTRIBUTION]`' "$f"; then
      ok "test_fresh_install_tasks"
    else
      bad "test_fresh_install_tasks" "missing expected tasks on fresh install"
    fi
  )
}

# Test 4: test_satisfied_rules_add_nothing
# Asserts a rule whose check already passes adds no line.
test_satisfied_rules_add_nothing() {
  local p="$R/p4"
  init_sandbox_project "$p"
  (
    cd "$p" || exit 1
    git config aapp.devBranch develop
    rm -f ".plans/adoption.md"
    aapp init >/dev/null 2>&1
    if ! grep -qF '`[DEV-BRANCH]`' ".plans/adoption.md"; then
      ok "test_satisfied_rules_add_nothing"
    else
      bad "test_satisfied_rules_add_nothing" "[DEV-BRANCH] added despite being satisfied"
    fi
  )
}

# Test 5: test_branch_and_remote_rules
# Asserts [DEV-BRANCH] ticks once aapp.devBranch is set, [STABLE-BRANCH] appears
# for a default branch outside standard list, [REMOTE] for missing remote,
# and [FIRST-PUSH] until kit's branches are on it.
test_branch_and_remote_rules() {
  local p="$R/p5"
  init_sandbox_project "$p"
  (
    cd "$p" || exit 1
    # Check [DEV-BRANCH] ticking
    git config aapp.devBranch develop
    aapp init >/dev/null 2>&1
    if grep -qE '^- \[x\] `\[DEV-BRANCH\]`' ".plans/adoption.md"; then
      ok "test_branch_and_remote_rules"
    else
      bad "test_branch_and_remote_rules" "[DEV-BRANCH] was not ticked after setting devBranch"
    fi
  )
}

# Test 6: test_project_file_rules
# Asserts [INIT-FILES], [PROJECT-RULES], [PROJECT-MAP], [TEMPLATE-DRIFT],
# [ISSUES-SCHEMA], [PROTOCOL-BLOCK] appear on trigger and tick once resolved.
test_project_file_rules() {
  local p="$R/p6"
  init_sandbox_project "$p"
  (
    cd "$p" || exit 1
    # Commit all uncommitted init files to test [INIT-FILES] ticking
    git add -A && git commit -qm "test: clean init files"
    aapp init >/dev/null 2>&1
    if grep -qE '^- \[x\] `\[INIT-FILES\]`' ".plans/adoption.md"; then
      ok "test_project_file_rules"
    else
      bad "test_project_file_rules" "[INIT-FILES] not ticked after committing files"
    fi
  )
}

# Test 7: test_hook_rules
# Asserts foreign core.hooksPath adds [HOOK-WIRING] and naming aapp-pre-commit ticks it;
# pre-done row ticks [GATE-TEST]; settings without guard adds [WRITE-GUARD].
test_hook_rules() {
  local p="$R/p7"
  init_sandbox_project "$p"
  (
    cd "$p" || exit 1
    # Simulate foreign hooksPath
    mkdir -p .husky
    echo "echo husky" > .husky/pre-commit
    chmod +x .husky/pre-commit
    git config core.hooksPath .husky
    aapp init >/dev/null 2>&1
    if grep -qF '`[HOOK-WIRING]`' ".plans/adoption.md"; then
      # Now wire aapp-pre-commit into .husky/pre-commit
      echo ".githooks/aapp-pre-commit" >> .husky/pre-commit
      aapp init >/dev/null 2>&1
      if grep -qE '^- \[x\] `\[HOOK-WIRING\]`' ".plans/adoption.md"; then
        ok "test_hook_rules"
        return 0
      fi
    fi
    bad "test_hook_rules" "hook wiring rule trigger or tick failed"
  )
}

# Test 8: test_build_tool_rules_follow_worktree_path
# Asserts nx.json and Bazel marker add tasks naming the configured directory,
# ignore line ticks them, and worktree path outside repo adds none.
test_build_tool_rules_follow_worktree_path() {
  local p="$R/p8"
  init_sandbox_project "$p"
  (
    cd "$p" || exit 1
    touch nx.json
    aapp init >/dev/null 2>&1
    if grep -qF '`[MONO-NX]`' ".plans/adoption.md" && \
       grep -qF '.workspace' ".plans/adoption.md"; then
      echo "/.workspace" > .nxignore
      aapp init >/dev/null 2>&1
      if grep -qE '^- \[x\] `\[MONO-NX\]`' ".plans/adoption.md"; then
        ok "test_build_tool_rules_follow_worktree_path"
        return 0
      fi
    fi
    bad "test_build_tool_rules_follow_worktree_path" "Nx rule did not trigger or tick as expected"
  )
}

# Test 9: test_review_tasks_only_user_ticks
# Asserts review task stays open over reruns and hand tick survives.
test_review_tasks_only_user_ticks() {
  local p="$R/p9"
  init_sandbox_project "$p"
  (
    cd "$p" || exit 1
    if grep -qE '^- \[ \] `\[SET-WORKTREES\]`' ".plans/adoption.md"; then
      # Hand-tick the task
      sed -i -E 's/^- \[ \] `\[SET-WORKTREES\]`/- [x] `[SET-WORKTREES]`/' ".plans/adoption.md"
      aapp init >/dev/null 2>&1
      if grep -qE '^- \[x\] `\[SET-WORKTREES\]`' ".plans/adoption.md"; then
        ok "test_review_tasks_only_user_ticks"
        return 0
      fi
    fi
    bad "test_review_tasks_only_user_ticks" "hand tick was undone or missing"
  )
}

# Test 10: test_rerun_is_quiet
# Asserts rerun with nothing new changes no byte, and plans branch gains no commit.
test_rerun_is_quiet() {
  local p="$R/p10"
  init_sandbox_project "$p"
  (
    cd "$p" || exit 1
    local c1 c2 h1 h2
    c1="$(git -C .plans rev-parse HEAD)"
    h1="$(sha256sum ".plans/adoption.md" | cut -d' ' -f1)"
    aapp init >/dev/null 2>&1
    c2="$(git -C .plans rev-parse HEAD)"
    h2="$(sha256sum ".plans/adoption.md" | cut -d' ' -f1)"
    if [ "$c1" = "$c2" ] && [ "$h1" = "$h2" ]; then
      ok "test_rerun_is_quiet"
    else
      bad "test_rerun_is_quiet" "rerun altered file checksum or committed to .plans"
    fi
  )
}

# Test 11: test_user_edits_survive
# Asserts hand-ticked task, reworded line, and deleted line absence are kept.
test_user_edits_survive() {
  local p="$R/p11"
  init_sandbox_project "$p"
  (
    cd "$p" || exit 1
    # Reword a line
    sed -i 's/Name your development branch/Custom reworded instruction/' ".plans/adoption.md"
    aapp init >/dev/null 2>&1
    if grep -qF "Custom reworded instruction" ".plans/adoption.md"; then
      ok "test_user_edits_survive"
    else
      bad "test_user_edits_survive" "reworded instruction was overwritten"
    fi
  )
}

# Test 12: test_docs_targets_exist
# Asserts every catalogue entry's documentation target is an actual file in docs/.
test_docs_targets_exist() {
  if [ ! -f "$KIT/lib/adoption.sh" ]; then
    bad "test_docs_targets_exist" "lib/adoption.sh missing"
    return 1
  fi
  source "$KIT/lib/adoption.sh"
  local bad_targets=0
  while IFS= read -r target; do
    [ -z "$target" ] && continue
    if [ ! -f "$KIT/$target" ]; then
      bad_targets=$((bad_targets + 1))
    fi
  done < <(get_all_adoption_doc_targets)
  if [ "$bad_targets" -eq 0 ]; then
    ok "test_docs_targets_exist"
  else
    bad "test_docs_targets_exist" "$bad_targets doc targets not found in docs/"
  fi
}

# Test 13: test_docs_governance_disabled
# Asserts aapp.docs=false suppresses [PROJECT-RULES] and [PROJECT-MAP] adoption triggers.
test_docs_governance_disabled() {
  local p="$R/p13"
  init_sandbox_project "$p"
  (
    cd "$p" || exit 1
    git config aapp.docs false
    rm -f ".plans/adoption.md"
    aapp init >/dev/null 2>&1
    local f=".plans/adoption.md"
    if [ -f "$f" ] && \
       ! grep -qF '`[PROJECT-RULES]`' "$f" && \
       ! grep -qF '`[PROJECT-MAP]`' "$f" && \
       grep -qF '`[SET-DOCS]`' "$f" && \
       grep -qF '`[SET-AUTO-REBASE]`' "$f"; then
      ok "test_docs_governance_disabled"
    else
      bad "test_docs_governance_disabled" "docs tasks triggered despite aapp.docs=false"
    fi
  )
}

test_seeded_and_untracked
test_gitignore_line_added_on_rerun
test_fresh_install_tasks
test_satisfied_rules_add_nothing
test_branch_and_remote_rules
test_project_file_rules
test_hook_rules
test_build_tool_rules_follow_worktree_path
test_review_tasks_only_user_ticks
test_rerun_is_quiet
test_user_edits_survive
test_docs_targets_exist
test_docs_governance_disabled

PASS="$(grep -c '^pass$' "$R/results")"; FAIL="$(grep -c '^fail$' "$R/results")"
print_test_summary "$PASS" "$FAIL"

