#!/usr/bin/env bash
# Tests: `aapp done` behaviour contract (lib/docs/verbs/done.md)
# Part: done.squash.sh (the squash on the plan branch: one recorded commit that
# is on the parent branch; a plan made for an issue is always squashed, P-84).
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"
export AAPP_STATE_DIR="$R/state"
unset AAPP_AGENT_NAME AAPP_AGENT_VENDOR AAPP_AGENT_MODEL

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/sq"
cd "$R/sq" || exit 1
PRIM="$(git rev-parse --abbrev-ref HEAD)"
printf '%s\n' '.env' >> .gitignore
git add -A && git commit -qm "track init files" --no-verify
git branch develop
git config aapp.planWorktrees on
git config aapp.commitMode microcommits
git config aapp.issueFixWait 0
git config aapp.offlineEnabled false
git config aapp.pluginTimeout 2

# mk_issue <name>: logs an issue on src/<name>.sh; prints its number.
mk_issue() { aapp issue log Low CORE "Defect in $1 shows." file "src/$1.sh" 2>&1 | sed -nE 's/.*#([0-9]+) logged.*/\1/p' | head -n 1; }
# mk_plan <name> [issue <n>]: drafts and freeze-starts a plan; prints its id.
mk_plan() {
  local name="$1" id f; shift
  id="P-$(git config aapp.planId)"; aapp draft "$name" "$@" >/dev/null 2>&1
  f="$(ls .plans/current/P"${id#P-}"-*.md)"
  sed -i -E "s|src/path/to/file\.ext|src/$name.sh|g; s|src/path/to/new_file\.ext|src/${name}_b.sh|g" "$f"
  sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$f"
  git -C .plans commit -qam "prep $id" >/dev/null 2>&1
  aapp freeze-start "$id" >/dev/null 2>&1
  echo "$id"
}
wt() { echo "$R/sq/.workspace/P${1#P-}"; }
# work <id> <name> <value> [agent tokens…]: one commit on the plan's file, in its worktree.
work() {
  local id="$1" name="$2" v="$3"; shift 3
  ( cd "$(wt "$id")" && mkdir -p src && echo "v=$v" > "src/$name.sh" && git add "src/$name.sh" && aapp commit "feat: $name $v" "$@" >/dev/null 2>&1 )
}
pfile() { ls .plans/current/P"${1#P-}"-*.md 2>/dev/null || ls .plans/done/P"${1#P-}"-*.md; }
pbranch() { git branch --list "plan/P${1#P-}-*" --format='%(refname:short)' | head -n 1; }
# ledger_sha <id>: the commit the plan's archive ledger line names.
ledger_sha() { grep -F "| \`$1\` |" .plans/done/000-archive-ledger.md | head -n 1 | awk -F'|' '{ gsub(/[` ]/, "", $6); print $6 }'; }
# row_sha <n>: the commit the issue's archive row names.
row_sha() { grep -E "^\| #$1 \|" .plans/done/000-issues-archive.md | head -n 1 | awk -F'|' '{ gsub(/[` ]/, "", $7); print $7 }'; }
plan_commits() { sed -nE 's/^\* \*\*Commits:\*\*[[:space:]]*//p' "$(pfile "$1")" | head -n 1; }
on_branch() { [ -n "$1" ] && git merge-base --is-ancestor "$1" "$2" 2>/dev/null; }
short() { git rev-parse --short "$1"; }
PDIR=".agents/skills/aapp-issue-tracker"
plugin_on() { mkdir -p "$PDIR"; { echo '#!/bin/sh'; echo "tr -d '\\n' >> \"$R/log\"; echo >> \"$R/log\""; echo "echo '{\"status\": \"declined\"}'"; } > "$PDIR/run"; chmod +x "$PDIR/run"; : > "$R/log"; }
plugin_off() { rm -rf "$PDIR"; }

echo "== squash setup: the recorded commit is on the parent =="
git config aapp.integrate squash
a="$(mk_plan alpha)"; work "$a" alpha 1; work "$a" alpha 2
abr="$(pbranch "$a")"; dev0="$(git rev-parse develop)"
out="$(aapp done "$a" 2>&1)"; rc=$?
tip="$(short develop)"
if [ "$rc" -eq 0 ] && [ "$(ledger_sha "$a")" = "$tip" ] && [ "$(plan_commits "$a")" = "\`$tip\` (develop)" ]; then
  ok "test_recorded_commit_is_on_parent"
else
  bad "test_recorded_commit_is_on_parent" "rc=$rc tip=$tip ledger=$(ledger_sha "$a") commits=$(plan_commits "$a") out=$out"
fi
if [ "$(git rev-list --count "$dev0"..develop)" = "1" ] && git log -1 --format=%B develop | grep -qx "Plan-ID: $a" && \
   git log -1 --format=%B develop | grep -qx "Plan-Parent: develop" && [ -n "$abr" ] && \
   ! git rev-parse --verify -q "refs/heads/$abr" >/dev/null && [ ! -d "$(wt "$a")" ] && \
   [ "$(git show develop:src/alpha.sh)" = "v=2" ] && [ "$(git rev-parse --abbrev-ref HEAD)" = "$PRIM" ]; then
  ok "test_one_commit_fast_forwarded"
else
  bad "test_one_commit_fast_forwarded" "count=$(git rev-list --count "$dev0"..develop) branch=$abr msg=$(git log -1 --format=%B develop | tr '\n' '/')"
fi

echo "== squash setup: the issue's row, the provider, a waiting plan =="
n1="$(mk_issue beta)"
w="$(mk_plan waiter)"; work "$w" waiter 1
aapp refine "$w" blocked "$n1" >/dev/null 2>&1
blocked0="$(grep -c '^\* \*\*Blocked On' "$(pfile "$w")")"
plugin_on
b="$(mk_plan beta issue "$n1")"; work "$b" beta 1; work "$b" beta 2
out="$(aapp done "$b" 2>&1)"; rc=$?
plugin_off
tip="$(short develop)"
if [ "$rc" -eq 0 ] && [ "$(row_sha "$n1")" = "$tip" ] && on_branch "$(row_sha "$n1")" develop; then
  ok "test_issue_row_names_parent_commit"
else
  bad "test_issue_row_names_parent_commit" "rc=$rc tip=$tip row=$(row_sha "$n1") out=$out"
fi
if grep -F '"event": "issue.close"' "$R/log" | tail -n 1 | grep -qF "\"commit\": \"$tip\""; then
  ok "test_provider_gets_parent_commit"
else
  bad "test_provider_gets_parent_commit" "tip=$tip sent=$(grep -F 'issue.close' "$R/log" | tail -n 1 | cut -c1-300)"
fi
if [ "$blocked0" = "1" ] && ! grep -q '^\* \*\*Blocked On' "$(pfile "$w")" && grep -q '^\* \*\*Status:\*\* ⚡ In Development' "$(pfile "$w")"; then
  ok "test_waiting_plan_is_unblocked"
else
  bad "test_waiting_plan_is_unblocked" "before=$blocked0 after=$(grep -E 'Status|Blocked On' "$(pfile "$w")" | tr '\n' '/') out=$out"
fi

echo "== attribution: the plan's last commit =="
git config aapp.aiAttribution lax
c="$(mk_plan gamma)"; work "$c" gamma 1 agent "First Bot" vendor Acme model one
work "$c" gamma 2 agent "Last Bot" vendor Acme model two
out="$(AAPP_AGENT_NAME=Runner AAPP_AGENT_VENDOR=Other AAPP_AGENT_MODEL=zero aapp done "$c" 2>&1)"; rc=$?
msg="$(git log -1 --format=%B develop)"
d="$(mk_plan delta)"; work "$d" delta 1 agent "First Bot" vendor Acme model one
work "$d" delta 2
out2="$(AAPP_AGENT_NAME=Runner AAPP_AGENT_VENDOR=Other AAPP_AGENT_MODEL=zero aapp done "$d" 2>&1)"; rc2=$?
msg2="$(git log -1 --format=%B develop)"
if [ "$rc" -eq 0 ] && echo "$msg" | grep -qx "AI-Agent: Last Bot" && echo "$msg" | grep -qx "AI-Model: two" && \
   [ "$(echo "$msg" | grep -c '^AI-Agent:')" = "1" ] && ! echo "$msg" | grep -q "Runner" && \
   [ "$rc2" -eq 0 ] && echo "$msg2" | grep -qx "Plan-ID: $d" && ! echo "$msg2" | grep -q '^AI-'; then
  ok "test_attribution_is_the_last_commit"
else
  bad "test_attribution_is_the_last_commit" "rc=$rc/$rc2 msg=$(echo "$msg" | tr '\n' '/') msg2=$(echo "$msg2" | tr '\n' '/') out=$out$out2"
fi
git config --unset aapp.aiAttribution

echo "== attribution kept in git notes =="
git config aapp.aiAttribution notes
o="$(mk_plan omicron)"; work "$o" omicron 1 agent "First Bot" vendor Acme model one note "first audit"
work "$o" omicron 2 agent "Last Bot" vendor Acme model two note "second audit"
out="$(aapp done "$o" 2>&1)"; rc=$?
ai="$(git notes --ref=refs/notes/ai show develop 2>/dev/null)"; cn="$(git notes --ref=refs/notes/commits show develop 2>/dev/null)"
if [ "$rc" -eq 0 ] && git log -1 --format=%B develop | grep -qx "Plan-ID: $o" && echo "$ai" | grep -qF "Last Bot" && \
   ! echo "$ai" | grep -qF "First Bot" && echo "$cn" | grep -qF "first audit" && echo "$cn" | grep -qF "second audit"; then
  ok "test_notes_follow_the_squash"
else
  bad "test_notes_follow_the_squash" "rc=$rc ai=[$ai] commits=[$cn] out=$out"
fi
git config --unset aapp.aiAttribution

echo "== a squash that cannot be made =="
e="$(mk_plan epsilon)"; work "$e" epsilon 1; work "$e" epsilon 2
ebr="$(pbranch "$e")"; tip0="$(git rev-parse "$ebr")"; dev0="$(git rev-parse develop)"; ph0="$(git -C .plans rev-parse HEAD)"
git config commit.gpgsign true; git config gpg.program false
out="$(aapp done "$e" 2>&1)"; rc=$?
git config --unset commit.gpgsign; git config --unset gpg.program
if [ "$rc" -ne 0 ] && [ "$(git rev-parse "$ebr")" = "$tip0" ] && [ "$(git rev-parse develop)" = "$dev0" ] && \
   ls .plans/current/P"${e#P-}"-*.md >/dev/null 2>&1 && [ "$(git -C .plans rev-parse HEAD)" = "$ph0" ] && \
   [ -z "$(git -C "$(wt "$e")" status --porcelain)" ]; then
  ok "test_failed_squash_restores_branch"
else
  bad "test_failed_squash_restores_branch" "rc=$rc tip=$(git rev-parse "$ebr") want=$tip0 out=$out"
fi
aapp done "$e" >/dev/null 2>&1

echo "== ff setup =="
git config aapp.integrate ff
f="$(mk_plan zeta)"; work "$f" zeta 1; work "$f" zeta 2
fbr="$(pbranch "$f")"; f1="$(git rev-parse "$fbr~1")"; f2="$(git rev-parse "$fbr")"; dev0="$(git rev-parse develop)"
out="$(aapp done "$f" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && on_branch "$f1" develop && [ "$(git rev-parse develop)" = "$f2" ] && \
   [ "$(git rev-list --count "$dev0"..develop)" = "2" ] && [ "$(ledger_sha "$f")" = "$(short "$f2")" ]; then
  ok "test_ff_mode_keeps_every_commit"
else
  bad "test_ff_mode_keeps_every_commit" "rc=$rc count=$(git rev-list --count "$dev0"..develop) out=$out"
fi

n2="$(mk_issue eta)"
g="$(mk_plan eta issue "$n2")"; work "$g" eta 1; work "$g" eta 2
dev0="$(git rev-parse develop)"
out="$(aapp done "$g" 2>&1)"; rc=$?
tip="$(short develop)"
if [ "$rc" -eq 0 ] && [ "$(git rev-list --count "$dev0"..develop)" = "1" ] && [ "$(row_sha "$n2")" = "$tip" ] && \
   [ "$(ledger_sha "$g")" = "$tip" ] && git log -1 --format=%B develop | grep -qx "Plan-ID: $g"; then
  ok "test_issue_plan_squashed_in_ff_mode"
else
  bad "test_issue_plan_squashed_in_ff_mode" "rc=$rc count=$(git rev-list --count "$dev0"..develop) row=$(row_sha "$n2") tip=$tip out=$out"
fi

n3="$(mk_issue theta)"
h="$(mk_plan theta)"
sed -i -E "s|^(\* \*\*Target Issue / Milestone:\*\*).*|\1 #$n3|" "$(pfile "$h")"
git -C .plans commit -qam "target by hand" >/dev/null 2>&1
work "$h" theta 1; work "$h" theta 2
hbr="$(pbranch "$h")"; h2="$(git rev-parse "$hbr")"; dev0="$(git rev-parse develop)"
out="$(aapp done "$h" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(git rev-list --count "$dev0"..develop)" = "2" ] && [ "$(git rev-parse develop)" = "$h2" ] && \
   [ "$(row_sha "$n3")" = "$(short "$h2")" ]; then
  ok "test_issue_plan_needs_both_sides"
else
  bad "test_issue_plan_needs_both_sides" "rc=$rc count=$(git rev-list --count "$dev0"..develop) row=$(row_sha "$n3") out=$out"
fi

echo "== manual setup =="
git config aapp.integrate manual
n4="$(mk_issue iota)"
i="$(mk_plan iota issue "$n4")"; work "$i" iota 1; work "$i" iota 2
ibr="$(pbranch "$i")"; dev0="$(git rev-parse develop)"
out="$(aapp done "$i" 2>&1)"; rc=$?
itip="$(short "$ibr")"
if [ "$rc" -eq 0 ] && [ "$(git rev-parse develop)" = "$dev0" ] && [ "$(git rev-list --count develop.."$ibr")" = "1" ] && \
   [ "$(row_sha "$n4")" = "$itip" ] && [ "$(ledger_sha "$i")" = "$itip" ] && [ -d "$(wt "$i")" ] && \
   git log -1 --format=%B "$ibr" | grep -qx "Plan-ID: $i"; then
  ok "test_issue_plan_squashed_under_manual"
else
  bad "test_issue_plan_squashed_under_manual" "rc=$rc count=$(git rev-list --count develop.."$ibr") row=$(row_sha "$n4") tip=$itip out=$out"
fi

n5="$(mk_issue kappa)"
k="$(mk_plan kappa)"
sed -i -E "s|^(\* \*\*Target Issue / Milestone:\*\*).*|\1 #$n5|" "$(pfile "$k")"
git -C .plans commit -qam "target by hand" >/dev/null 2>&1
work "$k" kappa 1; work "$k" kappa 2
kbr="$(pbranch "$k")"; k2="$(short "$kbr")"
aapp done "$k" >/dev/null 2>&1
old_row="$(row_sha "$n5")"; ph0="$(git -C .plans rev-parse HEAD)"; dev0="$(git rev-parse develop)"
out="$(aapp done "$k" integrate squash 2>&1)"; rc=$?
tip="$(short develop)"
if [ "$rc" -eq 0 ] && [ "$old_row" = "$k2" ] && [ "$(git rev-list --count "$dev0"..develop)" = "1" ] && \
   [ "$(ledger_sha "$k")" = "$tip" ] && [ "$(row_sha "$n5")" = "$tip" ] && [ "$(plan_commits "$k")" = "\`$tip\` (develop)" ] && \
   [ "$(git -C .plans rev-list --count "$ph0"..HEAD)" = "1" ] && [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_later_integration_corrects_records"
else
  bad "test_later_integration_corrects_records" "rc=$rc old=$old_row/$k2 tip=$tip ledger=$(ledger_sha "$k") row=$(row_sha "$n5") plans=$(git -C .plans rev-list --count "$ph0"..HEAD) out=$out"
fi

echo "== a plan made for an issue gets its own branch =="
git config aapp.planWorktrees off
n6="$(mk_issue lambda)"
id="P-$(git config aapp.planId)"; aapp draft lambda issue "$n6" >/dev/null 2>&1
pl="$(pfile "$id")"
sed -i -E "s|src/path/to/file\.ext|src/lambda.sh|g; s|src/path/to/new_file\.ext|src/lambda_b.sh|g; s/^\* \[ \] \*\*Question/* [x] **Question/" "$pl"
git -C .plans commit -qam "prep $id" >/dev/null 2>&1
out="$(aapp freeze-start "$id" 2>&1)"; rc=$?
id2="P-$(git config aapp.planId)"; aapp draft mu >/dev/null 2>&1
pl2="$(pfile "$id2")"
sed -i -E "s|src/path/to/file\.ext|src/mu.sh|g; s|src/path/to/new_file\.ext|src/mu_b.sh|g; s/^\* \[ \] \*\*Question/* [x] **Question/" "$pl2"
git -C .plans commit -qam "prep $id2" >/dev/null 2>&1
out2="$(aapp freeze-start "$id2" 2>&1)"; rc2=$?
if [ "$rc" -eq 0 ] && [ -d "$(wt "$id")" ] && [ -n "$(pbranch "$id")" ] && echo "$out" | grep -qF "$(wt "$id")" && \
   grep -qF '**Worktree:**' "$pl" && [ "$rc2" -eq 0 ] && [ ! -d "$(wt "$id2")" ] && [ -z "$(pbranch "$id2")" ]; then
  ok "test_issue_plan_gets_its_own_branch"
else
  bad "test_issue_plan_gets_its_own_branch" "rc=$rc/$rc2 out=$out | $out2"
fi

print_test_summary "$PASS" "$FAIL"
