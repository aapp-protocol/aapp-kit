#!/usr/bin/env bash
# Core suite for the git notes subsystem (P-44): the two note refs, appending
# and amending, push and pull with union merge, and the AI notes audit guard.
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"
# shellcheck source=/dev/null
source "$KIT/lib/attribution.sh"

# note_of <ref> <sha>: the note on <sha> in refs/notes/<ref>, or nothing.
note_of() { git notes --ref="refs/notes/$1" show "$2" 2>/dev/null; }

# ai_commit <file>: commits <file> with a staged AI note; prints the commit.
ai_commit() {
  echo "$1" > "$1"; git add "$1"
  aapp note stage "Benchmark score: 98.4%" msg "feat: add $1" agent Claude vendor Anthropic model claude-3-5 >/dev/null 2>&1
  git commit -qm "feat: add $1" >/dev/null 2>&1
  git rev-parse HEAD
}

echo "== two refs =="
init_sandbox_project "$R/refs"; cd "$R/refs" || exit 1
echo alpha > alpha.txt; git add alpha.txt
aapp note stage "Peer review: looks good" msg "feat: commit alpha" >/dev/null 2>&1
git commit -qm "feat: commit alpha" >/dev/null 2>&1
alpha="$(git rev-parse HEAD)"
note_of commits "$alpha" | grep -q "Peer review: looks good" || t_fail "general note not in refs/notes/commits"
[ -z "$(note_of ai "$alpha")" ] || t_fail "general note in refs/notes/ai"
beta="$(ai_commit beta.txt)"
[ -z "$(note_of commits "$beta")" ] || t_fail "AI note in refs/notes/commits"
note_of ai "$beta" | grep -q "AI-Agent: Claude" && note_of ai "$beta" | grep -q "Benchmark score" || t_fail "AI note: $(note_of ai "$beta")"
attribution_note "$alpha" "Claude (Anthropic)" "Model: test" >/dev/null 2>&1
git notes --ref=refs/notes/commits remove "$alpha" >/dev/null 2>&1
[ -z "$(note_of commits "$alpha")" ] && note_of ai "$alpha" | grep -q "AI-Agent: Claude" || t_fail "removing the commits note touched the AI note"
t_done test_notes_land_in_their_own_ref

echo "== append and amend =="
init_sandbox_project "$R/amend"; cd "$R/amend" || exit 1
sha="$(ai_commit beta.txt)"
attribution_note "$sha" "Antigravity (Google)" "Secondary review: pass" >/dev/null 2>&1
note_of ai "$sha" | grep -q Claude && note_of ai "$sha" | grep -q Antigravity || t_fail "append: $(note_of ai "$sha")"
git config notes.rewriteMode concatenate
git config --add notes.rewriteRef refs/notes/ai
echo amendment >> beta.txt; git add beta.txt
git commit -q --amend -m "feat: beta amended" >/dev/null 2>&1
note_of ai "$(git rev-parse HEAD)" | grep -q "AI-Agent: Claude" || t_fail "amended commit lost its AI note"
t_done test_note_appends_and_survives_amend

echo "== push and pull =="
git init -q --bare "$R/remote.git"
init_sandbox_project "$R/one"; cd "$R/one" || exit 1
sha="$(ai_commit gamma.txt)"
# The remote holds both note refs: with one alone, pull fetches nothing (#176).
git notes --ref=refs/notes/commits add -m "Peer review" "$sha"
git remote add origin "$R/remote.git"; git config aapp.notesRemote origin
git push -q origin HEAD:develop >/dev/null 2>&1
out="$(aapp note push 2>&1)" || t_fail "push: $out"
git -C "$R/remote.git" notes --ref=refs/notes/ai show "$sha" 2>/dev/null | grep -q "AI-Agent: Claude" || t_fail "remote lacks the AI note"
init_sandbox_project "$R/two"; cd "$R/two" || exit 1
git remote add origin "$R/remote.git"; git config aapp.notesRemote origin
out="$(aapp note pull 2>&1)" || t_fail "pull: $out"
note_of ai "$sha" | grep -q "AI-Agent: Claude" || t_fail "pulled note missing"
( cd "$R/one" && git notes --ref=refs/notes/ai append -m "Note from one" "$sha" && aapp note push ) >/dev/null 2>&1
git notes --ref=refs/notes/ai append -m "Note from two" "$sha" >/dev/null 2>&1
out="$(aapp note pull 2>&1)" || t_fail "union pull: $out"
note_of ai "$sha" | grep -q "Note from one" && note_of ai "$sha" | grep -q "Note from two" || t_fail "union: $(note_of ai "$sha")"
t_done test_note_push_pull_union_merge

git config notes.commits.mergeStrategy manual
( cd "$R/one" && git notes --ref=refs/notes/commits append -m "First party text" "$sha" && aapp note push ) >/dev/null 2>&1
git notes --ref=refs/notes/commits append -m "Conflicting second party text" "$sha" >/dev/null 2>&1
out="$(aapp note pull 2>&1)" && t_fail "conflicting pull passed"
echo "$out" | grep -qiE '(conflict|git notes merge --commit)' || t_fail "diagnostic: $out"
git notes merge --abort >/dev/null 2>&1
t_done test_note_pull_manual_conflict_fails_closed

echo "== audit guard =="
init_sandbox_project "$R/guard"; cd "$R/guard" || exit 1
git config aapp.aiNotesGuard warn; git config notes.ai.mergeStrategy cat_sort_uniq
out="$(aapp note status 2>&1)" || t_fail "warn mode exited non-zero"
echo "$out" | grep -q "Audit Guard: Advisory Warning" || t_fail "warn: $out"
git config aapp.aiNotesGuard enforce
out="$(aapp note status 2>&1)" && t_fail "enforce mode passed a lossy strategy"
echo "$out" | grep -q "Audit Guard: ENFORCE Violation" || t_fail "enforce: $out"
git config notes.ai.mergeStrategy union; git config notes.rewriteMode concatenate
out="$(aapp note status 2>&1)" || t_fail "lossless settings refused: $out"
echo "$out" | grep -q "Audit Guard: ENFORCE Violation" && t_fail "lossless settings flagged"
t_done test_note_audit_guard

print_test_summary "$PASS" "$FAIL"
