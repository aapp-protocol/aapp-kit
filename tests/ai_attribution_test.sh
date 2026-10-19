#!/usr/bin/env bash
# Core suite for AI attribution (P-14): init defaults, the commit-msg hook's
# conciseness and attribution rules, staged notes and the post-commit hook,
# `aapp ai credits`, and the attribution layer (lib/attribution.sh). Mode
# switching and `ai status` are the verb's (tests/verbs/ai.sh).
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
source "$KIT/tests/test_helpers.sh"
SANDBOX_ROOT=$(mktemp -d /tmp/aapp-attribution-test-XXXXXX)
trap 'rm -rf "$SANDBOX_ROOT"' EXIT
confine_test_runtime "$SANDBOX_ROOT"

T="$SANDBOX_ROOT/repo"
mkdir -p "$T" && cd "$T" || exit 1
git init -q && git branch -M main && setup_test_git_identity "$T"
aapp init >/dev/null 2>&1

# msg <name> <text>: writes a commit message file; prints its path.
msg() { printf '%s\n' "$2" > "$T/$1.txt"; echo "$T/$1.txt"; }
# hook_says <name> <file>: PASS or BLOCK from the commit-msg hook.
hook_says() { "$T/.githooks/aapp-commit-msg" "$1" >/dev/null 2>&1 && echo PASS || echo BLOCK; }
lines() { local i; for i in $(seq 1 "$1"); do echo "Line $i"; done; }
sum() { sha256sum "$1" | awk '{print $1}'; }

OK="$(msg ok "feat: add concise subject within seventy two chars limit

This is a valid body.")"
FULL="$(msg full "feat: valid subject

AI-Agent: Claude
AI-Vendor: Anthropic
AI-Model: claude-3-5-sonnet")"

echo "== init defaults =="
t_expect "aapp.aiAttribution" none "$(git config aapp.aiAttribution)"
t_expect "aapp.aiCredits" false "$(git config aapp.aiCredits)"
for h in commit-msg aapp-commit-msg post-commit aapp-post-commit; do
  [ -x ".githooks/$h" ] || t_fail ".githooks/$h is not executable"
done
t_done test_init_defaults_and_hooks

# `aapp ai notes`, run twice, sets no remote refspecs (#91).
aapp ai notes >/dev/null 2>&1; aapp ai notes >/dev/null 2>&1
t_expect "push refspecs" "" "$(git config --get-all remote.origin.push)"
t_expect "fetch refspecs" "" "$(git config --get-all remote.origin.fetch)"
aapp ai none >/dev/null 2>&1
t_done test_ai_notes_leaves_remote_refspecs

echo "== commit-msg conciseness =="
t_expect "subject within 72" PASS "$(hook_says "$OK")"
t_expect "subject over 72" BLOCK "$(hook_says "$(msg long "feat: add concise subject that intentionally exceeds seventy two characters limit by continuing further

Body.")")"
git config aapp.subjectMaxLen 50
t_expect "subject over aapp.subjectMaxLen" BLOCK "$(hook_says "$(msg len55 "feat: subject with 55 characters length exceeds fifty

Body.")")"
git config --unset aapp.subjectMaxLen
t_expect "no blank line 2" BLOCK "$(hook_says "$(msg noblank "feat: valid subject
This is line 2 without an empty line separator.")")"
t_expect "body line over 100" BLOCK "$(hook_says "$(msg wide "feat: valid subject

This line is intentionally constructed to exceed one hundred characters in length without wrapping onto the next line.")")"
t_expect "long URL line" PASS "$(hook_says "$(msg url "feat: valid subject

Here is a link: https://github.com/aapp-protocol/agent-planning-kit/issues/very-long-issue-identifier-that-exceeds-one-hundred-chars")")"
t_expect "body over 20 lines" BLOCK "$(hook_says "$(msg many "feat: valid subject

$(lines 21)")")"
t_expect "revert with a long body" PASS "$(hook_says "$(msg revert "Revert \"feat: something\"

This reverts commit 1234567890abcdef.
$(lines 21)")")"
t_done test_commit_msg_conciseness

echo "== attribution modes =="
BANNED="$(msg banned "feat: valid subject

Co-authored-by: Antigravity <antigravity@google.com>")"
for m in none lax strict notes; do
  git config aapp.aiAttribution "$m"
  t_expect "co-author in $m" BLOCK "$(hook_says "$BANNED")"
done
t_done test_coauthor_refused_in_every_mode

PARTIAL="$(msg partial "feat: valid subject

AI-Agent: Claude")"
git config aapp.aiAttribution none
t_expect "none: trailers" BLOCK "$(hook_says "$FULL")"
git config aapp.aiAttribution lax
t_expect "lax: human commit" PASS "$(hook_says "$OK")"
t_expect "lax: partial trailers" BLOCK "$(hook_says "$PARTIAL")"
t_expect "lax: full trailers" PASS "$(hook_says "$FULL")"
git config aapp.aiAttribution strict
t_expect "strict: no trailers" BLOCK "$(hook_says "$OK")"
"$T/.githooks/aapp-commit-msg" "$OK" 2>&1 | grep -q "aapp ai lax" || t_fail "strict refusal names no 'aapp ai lax'"
t_expect "strict: full trailers" PASS "$(hook_says "$FULL")"
t_expect "strict: revert" PASS "$(hook_says "$(msg revert2 "Revert \"feat: previous commit\"

This reverts commit 1234567890abcdef1234567890abcdef12345678.")")"
git config aapp.aiAttribution commit
t_expect "retired commit mode" BLOCK "$(hook_says "$FULL")"
"$T/.githooks/aapp-commit-msg" "$FULL" 2>&1 | grep -qiE 'ai lax|ai strict' || t_fail "retired mode refusal names neither 'ai lax' nor 'ai strict'"
t_done test_attribution_modes

echo "== staged notes =="
git config aapp.aiAttribution notes
# A pass-through pre-commit, so commits test the note hooks alone.
printf '#!/bin/sh\nexit 0\n' > .githooks/pre-commit; chmod +x .githooks/pre-commit
git config core.hooksPath .githooks
# buffer_of <message>: the staged note buffer for <message>.
buffer_of() { echo "$(git rev-parse --git-path aapp_pending_note).$(echo "$1" | git stripspace --strip-comments | sha256sum | awk '{print $1}')"; }
commit_file() { echo "$1" > "$1.txt"; git add "$1.txt"; git commit -m "$2" >/dev/null 2>&1; }

commit_file c1 "chore: commit without staged note"
t_expect "no staged note" "" "$(git notes --ref=refs/notes/commits list HEAD 2>/dev/null)"
M="feat: implement feature with staged note"
aapp note stage msg "$M" agent Antigravity vendor Google model gemini-1.5-pro >/dev/null
[ -f "$(buffer_of "$M")" ] || t_fail "no buffer $(buffer_of "$M")"
commit_file c2 "$M"
note="$(git notes --ref=refs/notes/ai show HEAD 2>/dev/null)"
echo "$note" | grep -q "AI-Agent: Antigravity" && echo "$note" | grep -q "AI-Model: gemini-1.5-pro" || t_fail "attached note: $note"
[ ! -f "$(buffer_of "$M")" ] || t_fail "buffer left after attaching"
M="feat: commit with custom note body"
aapp note stage "Custom Benchmarking Payload: benchmark_id=42" msg "$M" >/dev/null
commit_file c3 "$M"
t_expect "custom note" "Custom Benchmarking Payload: benchmark_id=42" "$(git notes --ref=refs/notes/commits show HEAD 2>/dev/null)"
echo amended >> c3.txt; git add c3.txt; git commit -q --amend --no-edit >/dev/null 2>&1
t_expect "note after amend" "Custom Benchmarking Payload: benchmark_id=42" "$(git notes --ref=refs/notes/commits show HEAD 2>/dev/null)"
t_done test_staged_note_attaches_to_its_commit

M="feat: intentional attachment failure test"
aapp note stage msg "$M" agent Claude >/dev/null
LOCK="$(git rev-parse --git-path refs/notes/ai.lock)"; mkdir -p "$LOCK"
commit_file fail "$M"
rmdir "$LOCK"
[ -f "$(buffer_of "$M")" ] || t_fail "buffer deleted although the note was not attached"
rm -f "$(buffer_of "$M")"
t_done test_staged_note_kept_when_attaching_fails

M="feat: uncommitted idea that aged out"
aapp note stage msg "$M" agent StaleAgent >/dev/null
touch -d '2 days ago' "$(buffer_of "$M")"
commit_file ttl "chore: trigger ttl sweep"
[ ! -f "$(buffer_of "$M")" ] || t_fail "stale buffer kept"
t_done test_stale_note_buffer_reaped

echo "== credits =="
BLOCK_TEXT='<!-- AAPP-AI-CREDITS:START -->
## AI Contributors

The following AI coding agents contributed to this codebase — planning, code, and review.
Listed alphabetically; the ordering carries no meaning, and no division of work is implied.

- %s

Authorship of, and responsibility for, this code rest with its human contributors.
<!-- AAPP-AI-CREDITS:END -->'
printf '# Test Project\nInitial readme content.\n' > README.md
for m in none notes; do
  git config aapp.aiAttribution "$m"
  aapp ai credits >/dev/null 2>&1
  grep -q "<!-- AAPP-AI-CREDITS:START -->" README.md && t_fail "block written in $m mode"
done
printf "\n$BLOCK_TEXT\n" "Claude (Anthropic)" >> README.md
before="$(sum README.md)"; aapp ai credits >/dev/null 2>&1
t_expect "notes mode keeps a hand block" "$before" "$(sum README.md)"
git config aapp.aiAttribution strict
echo code > code.txt; git add code.txt
git commit -qm "feat: first agent commit

AI-Agent: Antigravity
AI-Vendor: Google
AI-Model: gemini-1.5-pro" >/dev/null
aapp ai credits >/dev/null 2>&1
grep -q -- "- Antigravity (Google)" README.md && grep -q -- "- Claude (Anthropic)" README.md || t_fail "roster is not the union of block and history"
t_expect "first in byte order" "Antigravity (Google)" "$(grep -E '^[[:space:]]*- ' README.md | head -n1 | sed -E 's/^[[:space:]]*- //')"
before="$(sum README.md)"; aapp ai credits >/dev/null 2>&1
t_expect "regeneration" "$before" "$(sum README.md)"
aapp ai none >/dev/null
before="$(sum README.md)"; aapp ai credits >/dev/null 2>&1
t_expect "after ai none" "$before" "$(sum README.md)"
t_done test_credits_follow_mode_and_history

git config aapp.aiAttribution strict
printf '%s\n' '<!-- AAPP-AI-CREDITS:START -->' 'Broken block missing end tag' > README.md
aapp ai credits >/dev/null 2>&1 && t_fail "block without END accepted"
printf '%s\n' '<!-- AAPP-AI-CREDITS:END -->' '<!-- AAPP-AI-CREDITS:START -->' > README.md
aapp ai credits >/dev/null 2>&1 && t_fail "inverted tags accepted"
t_done test_credits_refuse_broken_block

git config aapp.aiAttribution strict
printf "# Project\n$BLOCK_TEXT\n" "Claude Code (Anthropic)" > README.md
git config --add aapp.aiAlias "Claude Code=Claude"
aapp ai credits >/dev/null 2>&1
grep -q -- "- Claude (Anthropic)" README.md && ! grep -q -- "- Claude Code (Anthropic)" README.md || t_fail "alias not applied: $(grep -E '^- ' README.md)"
t_done test_credits_alias_map

echo "== attribution layer =="
# shellcheck source=/dev/null
source "$KIT/lib/attribution.sh"
git config aapp.aiAgent RepoAgent; git config aapp.aiVendor RepoVendor; git config aapp.aiModel RepoModel
t_expect "repository config ignored" "" "$(resolve_ai_identity "" "" "" "" 2>/dev/null)"
git config extensions.worktreeConfig true
git config --worktree aapp.aiAgent WkAgent; git config --worktree aapp.aiVendor WkVendor; git config --worktree aapp.aiModel WkModel
[[ "$(resolve_ai_identity "" "" "" "" 2>/dev/null)" == *WkAgent* ]] || t_fail "worktree config not used"
[[ "$(AAPP_AGENT_NAME=EnvAgent AAPP_AGENT_VENDOR=EnvVendor AAPP_AGENT_MODEL=EnvModel resolve_ai_identity "" "" "" "" 2>/dev/null)" == *EnvAgent* ]] || \
  t_fail "environment does not beat worktree config"
[[ "$(AAPP_AGENT_NAME=EnvAgent AAPP_AGENT_VENDOR=EnvVendor AAPP_AGENT_MODEL=EnvModel resolve_ai_identity ParamAgent ParamVendor ParamModel "" 2>/dev/null)" == *ParamAgent* ]] || \
  t_fail "parameters do not beat the environment"
for k in aiAgent aiVendor aiModel; do git config --unset "aapp.$k"; git config --worktree --unset "aapp.$k"; done
t_done test_identity_precedence

CO="$(msg coauthor "feat: test subject

Co-authored-by: Claude <noreply.anthropic.com>")"
warn="$(resolve_ai_identity "" "" "" "$CO" 2>&1 >"$T/coauthor_id.txt")"
echo "$warn" | grep -qi warning || t_fail "no warning: $warn"
[[ "$(cat "$T/coauthor_id.txt")" == *Claude* ]] || t_fail "identity: $(cat "$T/coauthor_id.txt")"
t_done test_coauthor_converted_with_warning

git config aapp.aiAttribution strict
cp "$OK" "$T/msg_to_decorate.txt"
attribution_decorate "$T/msg_to_decorate.txt" "" >/dev/null 2>&1 && t_fail "decorated without an identity"
t_done test_strict_decorate_without_identity_refused

git config aapp.aiAttribution notes
HEAD_SHA="$(git rev-parse HEAD)"
err="$(attribution_note "$HEAD_SHA" "" "some text" 2>&1 >/dev/null)" && t_fail "note text without identity accepted"
[ -n "$err" ] || t_fail "refusal says nothing"
t_done test_note_text_without_identity_refused

attribution_note "$HEAD_SHA" "Claude (Anthropic)" "" >/dev/null 2>&1 || t_fail "identity-only note refused"
t_done test_note_identity_only_passes

print_test_summary "$PASS" "$FAIL"
