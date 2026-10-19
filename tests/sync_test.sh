#!/usr/bin/env bash
# Core suite for remote sync (P-10): `aapp init`'s sync defaults, the
# push/pull/sync round trip of the kit worktrees, and the on-sync hook strategy
# with its precedence (CLI token > git config > committed registry).
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

P="$R/proj1"
mkdir -p "$P" && git init -q "$P" && setup_test_git_identity "$P"
echo "print('hello')" > "$P/main.py"
git -C "$P" add main.py && git -C "$P" commit -qm "initial commit"
git init --bare -q "$R/origin.git"; git init --bare -q "$R/upstream.git"
git -C "$P" remote add origin "$R/origin.git"
git -C "$P" remote add upstream "$R/upstream.git"
in_p() { (cd "$P" && "$@" 2>&1); }

echo "== init defaults =="
in_p aapp init >/dev/null
t_expect "aapp.remote" origin "$(git -C "$P" config aapp.remote)"
t_expect "aapp.syncWorktrees" "plans agents githooks" "$(git -C "$P" config aapp.syncWorktrees)"
t_expect "aapp.pullStrategy" ff-only "$(git -C "$P" config aapp.pullStrategy)"
t_expect "aapp.syncStrategy" builtin "$(git -C "$P" config aapp.syncStrategy)"
t_done test_init_seeds_sync_defaults

echo "== push, pull, sync =="
echo "test plan" > "$P/.plans/test.md"; git -C "$P/.plans" add test.md; git -C "$P/.plans" commit -qm "add test plan"
echo "test rule" > "$P/.agents/test.md"; git -C "$P/.agents" add test.md; git -C "$P/.agents" commit -qm "add test rule"
out="$(in_p aapp push)" || t_fail "push failed: $out"
echo "$out" | grep -q "All AAPP worktrees pushed successfully" || t_fail "push: $out"
t_expect "remote plans branch" plans "$(git -C "$R/origin.git" branch --list plans | tr -d ' *')"
t_expect "remote agents branch" agents "$(git -C "$R/origin.git" branch --list agents | tr -d ' *')"
t_expect "upstream" origin/plans "$(git -C "$P/.plans" rev-parse --abbrev-ref '@{u}' 2>/dev/null)"

C="$R/tmp_clone"
git clone -q "$R/origin.git" -b plans "$C" && setup_test_git_identity "$C"
echo "updated from clone" >> "$C/test.md"; git -C "$C" commit -qam "update plan from remote"; git -C "$C" push -q origin plans
out="$(in_p aapp pull)" || t_fail "pull failed: $out"
grep -q "updated from clone" "$P/.plans/test.md" || t_fail "pull brought nothing"

echo "remote line 2" >> "$C/test.md"; git -C "$C" commit -qam "update remote line 2"; git -C "$C" push -q origin plans
echo "local agent rule" >> "$P/.agents/test.md"; git -C "$P/.agents" commit -qam "local agent update"
out="$(in_p aapp sync)" || t_fail "sync failed: $out"
grep -q "remote line 2" "$P/.plans/test.md" || t_fail "sync pulled nothing"

echo "uncommitted dirty content" >> "$P/.plans/test.md"
for verb in pull sync; do
  out="$(in_p aapp "$verb")" && t_fail "$verb ran on a dirty worktree"
  echo "$out" | grep -q "Pre-flight check failed" || t_fail "$verb: $out"
done
git -C "$P/.plans" checkout -- test.md

out="$(in_p aapp push upstream)" || t_fail "push upstream failed: $out"
t_expect "upstream remote plans branch" plans "$(git -C "$R/upstream.git" branch --list plans | tr -d ' *')"

git -C "$P" config aapp.syncWorktrees plans
out="$(in_p aapp push)"
echo "$out" | grep -q "\.plans/" && ! echo "$out" | grep -q "\.agents/" || t_fail "aapp.syncWorktrees ignored: $out"
git -C "$P" config aapp.syncWorktrees "plans agents githooks"
t_done test_push_pull_sync_round_trip

echo "== on-sync hook strategy =="
out="$(in_p aapp push hook)" && t_fail "hook strategy without a handler ran"
echo "$out" | grep -Fq "❌ aapp.syncStrategy=hook but no executable handler is registered for on-sync in .agents/skills/aapp-hooks/registry.tsv or git config." || t_fail "refusal: $out"
HOOK="$P/mock_on_sync.sh"
printf '%s\n' '#!/usr/bin/env bash' 'INPUT="$(cat)"' 'echo "HOOK_INVOKED: action=$AAPP_ACTION remote=$AAPP_REMOTE event=$AAPP_EVENT"' \
  'echo "HOOK_PAYLOAD: $INPUT"' > "$HOOK"
chmod +x "$HOOK"
mkdir -p "$P/.agents/skills/aapp-hooks"
# The registry pins the handler's SHA-256: the dispatcher enforces it (#109).
printf 'on-sync\t%s\tsha256:%s\t10\tgate\n' "$HOOK" "$(sha256sum "$HOOK" | awk '{print $1}')" > "$P/.agents/skills/aapp-hooks/registry.tsv"
git -C "$P" config --unset aapp.syncStrategy
out="$(in_p aapp push)" || t_fail "registry hook push failed: $out"
echo "$out" | grep -q "HOOK_INVOKED: action=push remote=origin event=on-sync" || t_fail "registry default: $out"
echo "$out" | grep -q '"action": "push"' && echo "$out" | grep -q '"worktrees":' || t_fail "payload: $out"
git -C "$P" config aapp.syncStrategy builtin
out="$(in_p aapp push)"
! echo "$out" | grep -q HOOK_INVOKED && echo "$out" | grep -q "All AAPP worktrees pushed successfully" || t_fail "config over registry: $out"
out="$(in_p aapp push origin hook)"
echo "$out" | grep -q "HOOK_INVOKED: action=push remote=origin" || t_fail "CLI over config: $out"
t_done test_hook_strategy_and_precedence

print_test_summary "$PASS" "$FAIL"
