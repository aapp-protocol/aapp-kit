#!/usr/bin/env bash
# Tests: `aapp offline` behaviour contract (lib/docs/verbs/offline.md)
# The `.offline` worktree: issues and draft plans staged while a provider is
# unreachable, and their promotion at `aapp offline sync` (P-75).
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"
export AAPP_STATE_DIR="$R/state"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

HDR='| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |'
SEP='| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |'
row() { printf '| #%s | `Low` | `CORE` | 2026-10-01 | `src/%s.sh` | Defect %s shows. |  | 🟡 `Incubated` |\n' "$1" "$2" "$1"; }
pf() { ls .plans/current/P"${1#P-}"-*.md 2>/dev/null; }
resolve_q() { sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$1"; }
blocked_on() { sed -nE 's/^\* \*\*Blocked On:\*\*[[:space:]]*//p' "$1" | head -n 1; }
off_row() { grep -qE "^\| #$1 \|" .offline/ISSUES.md 2>/dev/null; }
off_archived() { grep -qE "^\| #$1 \|" .offline/done/000-issues-archive.md 2>/dev/null; }
main_row() { grep -qE "^\| #$1 \|" .plans/ISSUES.md 2>/dev/null; }
main_archived() { grep -qE "^\| #$1 \|" .plans/done/000-issues-archive.md 2>/dev/null; }
lib() { ( cd "$PWD" && REPO_ROOT="$PWD" PLANS_DIR="$PWD/.plans" bash -c ". '$KIT/lib/cmd_issue.sh'; $1" 2>/dev/null ); }
# sandbox <dir>: a project on develop; ledger #1..#3, archive #7; a tracker and
# a plan-id provider driven by files in $R/<name>/:
#   fail.<step>  exit non-zero   hang.<step>  answer too late
#   ids          next ids for issue.log, one per line   planids  the same for plan.allocate
#   list, do     what issue.list brings (with "handled": "list" when `lists` exists)
sandbox() {
  local d="$1" name; name="$(basename "$1")"
  init_sandbox_project "$d"
  cd "$d" || exit 1
  mkdir -p src "$R/$name"; for f in a b c d; do echo "$f=1" > "src/$f.sh"; done
  git add -A && git commit -qm "sources" --no-verify
  git branch develop; git checkout -q develop
  git config aapp.planWorktrees off; git config aapp.issueFixWait 0; git config aapp.pluginTimeout 2
  { printf '%s\n' '# Issues' '' "$HDR" "$SEP"; row 1 a; row 2 b; row 3 c; } > .plans/ISSUES.md
  printf '%s\n' '# Issue Priority Board' '' '## 📥 Triage (Incoming / Unsequenced)' '- [ ] #1 -> Defect 1.' '- [ ] #2 -> Defect 2.' '- [ ] #3 -> Defect 3.' > .plans/issues_road_map.md
  printf '%s\n' '# Archive' '' '| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- |' \
    '| #7 | `Low` | `CLI` | 2026-08-01 | 2026-08-02 | `0000000` | Closed long ago. |' > .plans/done/000-issues-archive.md
  git -C .plans add -A >/dev/null 2>&1; git -C .plans commit -qm fixture >/dev/null 2>&1
  git config aapp.issueId 8
  local s="$R/ctl-$name"
  mkdir -p "$s" .agents/skills/aapp-issue-tracker
  cat > .agents/skills/aapp-issue-tracker/run <<EOF
#!/bin/sh
env="\$(cat | tr -d '\n')"
step="\${AAPP_PLUGIN_STEP#issue.}"
[ -f "$s/hang.\$step" ] && sleep 6
[ -f "$s/fail.\$step" ] && exit 3
if [ -f "$s/failword" ] && printf '%s' "\$env" | grep -qF "\$(cat "$s/failword")"; then exit 3; fi
printf '%s\n' "\$env" >> "$s/log"
case "\$step" in
  log)  id="\$(sed -n 1p "$s/ids" 2>/dev/null)"; [ -n "\$id" ] || { echo '{"status": "declined"}'; exit 0; }
        sed -i 1d "$s/ids"; printf '{"status": "ok", "id": "%s"}\n' "\$id" ;;
  list) [ -f "$s/list" ] && cat "$s/list" > "\$AAPP_PLUGIN_LIST"; [ -f "$s/do" ] && cat "$s/do" > "\$AAPP_PLUGIN_DO"
        if [ -f "$s/lists" ]; then echo '{"status": "ok", "handled": "list"}'; else echo '{"status": "declined"}'; fi ;;
  *)    echo '{"status": "ok"}' ;;
esac
EOF
  chmod +x .agents/skills/aapp-issue-tracker/run
  : > "$s/log"
}
# planid_provider <ctl-dir>: a plan-id provider for the sandbox we are in.
planid_provider() {
  mkdir -p .agents/skills/aapp-planid
  cat > .agents/skills/aapp-planid/run <<EOF
#!/bin/sh
cat >/dev/null
[ -f "$1/fail.plan" ] && exit 3
id="\$(sed -n 1p "$1/planids" 2>/dev/null)"; [ -n "\$id" ] || exit 3
sed -i 1d "$1/planids"; printf '{"id": "%s"}\n' "\$id"
EOF
  chmod +x .agents/skills/aapp-planid/run
}
calls() { grep -c . "$R/ctl-$1/log" 2>/dev/null; }

sandbox "$R/p"; S="$R/ctl-p"

echo "== the worktree =="
dev0="$(git rev-parse develop)"; plans0="$(git -C .plans rev-parse HEAD)"
out="$(aapp offline mount 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -e .offline/.git ] && [ "$(git -C .offline rev-parse --abbrev-ref HEAD)" = "offline" ] && \
   ! git merge-base develop offline >/dev/null 2>&1 && [ -f .offline/ISSUES.md ] && [ -f .offline/done/000-issues-archive.md ] && [ -d .offline/current ]; then
  ok "test_mount_creates_orphan_worktree"
else
  bad "test_mount_creates_orphan_worktree" "rc=$rc out=$out"
fi
if grep -qxF '.offline/' "$(git rev-parse --git-common-dir)/info/exclude" && [ -z "$(git status --porcelain)" ] && \
   [ "$(git rev-parse develop)" = "$dev0" ] && [ "$(git -C .plans rev-parse HEAD)" = "$plans0" ]; then
  ok "test_offline_dir_excluded_locally"
else
  bad "test_offline_dir_excluded_locally" "status=$(git status --porcelain | tr '\n' ' ')"
fi

echo "== staging while the provider is unreachable =="
touch "$S/fail.log"
out="$(aapp issue log Low CLI "Logged on the plane" file src/a.sh note "Body of the first one." 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && off_row 1007 && ! main_row 1007 && [ "$(git -C .plans rev-parse HEAD)" = "$plans0" ] && echo "$out" | grep -qiF "offline" && \
   [ -z "$(git -C .offline status --porcelain)" ]; then
  ok "test_allocate_uses_offset"
else
  bad "test_allocate_uses_offset" "rc=$rc rows=$(grep -oE '^\| #[0-9]+' .offline/ISSUES.md | tr '\n' ' ') out=$out"
fi
aapp issue log Low CLI "The second one" file src/b.sh >/dev/null 2>&1
aapp issue log Low CLI "The third one" file src/c.sh >/dev/null 2>&1
if off_row 1008 && off_row 1009; then
  ok "test_allocate_subsequent_increments_by_one"
else
  bad "test_allocate_subsequent_increments_by_one" "rows=$(grep -oE '^\| #[0-9]+' .offline/ISSUES.md | tr '\n' ' ')"
fi

echo "== offline issues are issues =="
P="P-$(git config aapp.planId)"; aapp draft waits >/dev/null 2>&1
out="$(aapp refine "$P" blocked 1008 2>&1)"; rc=$?
lout="$(aapp issue list all 2>&1)"; sout="$(aapp status 2>&1)"
if [ "$rc" -eq 0 ] && blocked_on "$(pf "$P")" | grep -qF '#1008' && echo "$lout" | grep -F '#1007' | grep -qiF 'offline' && \
   echo "$sout" | grep -F '#1008' | grep -qiF 'offline'; then
  ok "test_offline_issue_in_every_view"
else
  bad "test_offline_issue_in_every_view" "rc=$rc plan=[$(blocked_on "$(pf "$P")")] list=$(echo "$lout" | grep -F '#100') out=$out"
fi
if echo "$sout" | grep -qF 'Staged Offline Work' && echo "$sout" | grep -F 'staged' | grep -qF '#1007' && echo "$sout" | grep -qF 'aapp offline sync'; then
  ok "test_status_reports_staged_offline_work"
else
  bad "test_status_reports_staged_offline_work" "$(echo "$sout" | grep -iF offline)"
fi

echo "== closing and withdrawing offline =="
echo "a=2" > src/a.sh; git add src/a.sh; git commit -qm "fix: the plane bug (#1007)" --no-verify
SHA7="$(git rev-parse --short=7 HEAD)"
out="$(aapp issue close 1007 sha "$SHA7" summary "Fixed on the plane." 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && off_archived 1007 && ! off_row 1007 && ! main_archived 1007 && grep -E '^\| #1007 \|' .offline/done/000-issues-archive.md | grep -qF "$SHA7"; then
  ok "test_offline_issue_local_archive"
else
  bad "test_offline_issue_local_archive" "rc=$rc out=$out"
fi
out="$(aapp issue abort 1008 reason "Not a defect" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && off_archived 1008 && grep -E '^\| #1008 \|' .offline/done/000-issues-archive.md | grep -qF 'aborted' && \
   ! grep -q '^\* \*\*Blocked On:\*\*' "$(pf "$P")"; then
  ok "test_offline_issue_abort_archives_row"
else
  bad "test_offline_issue_abort_archives_row" "rc=$rc plan=[$(blocked_on "$(pf "$P")")] out=$out"
fi

out="$(aapp offline unmount 2>&1)"; rc=$?
kept=0; [ "$rc" -ne 0 ] && [ -d .offline ] && echo "$out" | grep -qF '#1009' && kept=1
# `force` unmounts anyway; the branch keeps what was staged, and mounting brings it back.
out2="$(aapp offline unmount force 2>&1)"; rc2=$?
gone=0; [ "$rc2" -eq 0 ] && [ ! -e .offline ] && gone=1
aapp offline mount >/dev/null 2>&1
if [ "$kept" -eq 1 ] && [ "$gone" -eq 1 ] && off_row 1009 && off_archived 1007; then
  ok "test_unmount_refuses_when_dirty"
else
  bad "test_unmount_refuses_when_dirty" "refused=$kept forced=$gone rc=$rc/$rc2 out=$out | $out2"
fi

echo "== the sync =="
aapp refine "$P" blocked 1009 >/dev/null 2>&1
aapp refine issues "a clue for 1009" note 1009 "Seen twice over the Atlantic." >/dev/null 2>&1
aapp issue log Low CLI "This one is BADWORD for the tracker" file src/d.sh >/dev/null 2>&1
rm -f "$S/fail.log"; echo "BADWORD" > "$S/failword"
printf '%s\n' '#501' '#502' '#503' > "$S/ids"
: > "$S/log"; plans0="$(git -C .plans rev-parse HEAD)"; subj0="$(git log -1 --format=%s)"
out="$(aapp offline sync 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && main_row 503 && grep -E '^\| #503 \|' .plans/ISSUES.md | grep -qF 'The third one' && blocked_on "$(pf "$P")" | grep -qF '#503' && \
   ! blocked_on "$(pf "$P")" | grep -qF '#1009' && ! off_row 1009 && grep -qE '#503 -> ' .plans/issues_road_map.md; then
  ok "test_offline_sync_promotes_and_relinks"
else
  bad "test_offline_sync_promotes_and_relinks" "rc=$rc plan=[$(blocked_on "$(pf "$P")")] main=$(grep -oE '^\| #[0-9]+' .plans/ISSUES.md | tr '\n' ' ') out=$out"
fi
if main_archived 501 && grep -E '^\| #501 \|' .plans/done/000-issues-archive.md | grep -qF 'logged offline as #1007' && \
   grep -E '^\| #501 \|' .plans/done/000-issues-archive.md | grep -qF "$SHA7" && [ "$(git log -1 --format=%s)" = "$subj0" ] && \
   git log --format=%s | grep -qF '(#1007)' && main_archived 502 && grep -E '^\| #502 \|' .plans/done/000-issues-archive.md | grep -qF 'aborted'; then
  ok "test_sync_preserves_offline_commit_messages"
else
  bad "test_sync_preserves_offline_commit_messages" "archive=$(grep -E '^\| #50' .plans/done/000-issues-archive.md)"
fi
if [ "$(lib 'ledger_locate 1007')" = "archive" ] && [ "$(lib 'ledger_locate 1009')" = "active" ] && lib 'ledger_row 1009' | grep -qE '^\| #503 \|'; then
  ok "test_former_id_lookup_resolves_to_canonical"
else
  bad "test_former_id_lookup_resolves_to_canonical" "1007=$(lib 'ledger_locate 1007') 1009=$(lib 'ledger_locate 1009') row=$(lib 'ledger_row 1009')"
fi
d="$(grep -F '"event": "issue.log"' "$S/log" | grep -F 'The third one')"; st="$(find "$R/state" -name issues-data.md | head -n 1)"
if echo "$d" | grep -qF 'Seen twice over the Atlantic.' && grep -F '"event": "issue.log"' "$S/log" | grep -F 'Logged on the plane' | grep -qF '"description": "Body of the first one."' && \
   grep -qxF '## #501' "$st" && grep -qxF '## #503' "$st" && ! grep -qxF '## #1007' "$st" && ! grep -qxF '## #1009' "$st"; then
  ok "test_sync_sends_description_and_notes"
else
  bad "test_sync_sends_description_and_notes" "log=$d store=$(grep '^## #' "$st" | tr '\n' ' ')"
fi
names="$(git -C .plans log --name-only --format= "$plans0"..HEAD | sort -u | tr '\n' ' ')"
if echo "$names" | grep -qF 'ISSUES.md' && echo "$names" | grep -qF 'done/000-issues-archive.md' && echo "$names" | grep -qF "current/$(basename "$(pf "$P")")" && \
   [ -z "$(git -C .plans status --porcelain)" ]; then c1=1; else c1=0; fi
if off_row 1010 && ! main_row 1010 && echo "$out" | grep -F '#1010' | grep -qiE 'stays|staged'; then
  ok "test_sync_keeps_failed_row_staged"
else
  bad "test_sync_keeps_failed_row_staged" "1010 offline=$(off_row 1010 && echo y) out=$out"
fi

echo "== the modes =="
sandbox "$R/q"; S="$R/ctl-q"
git config aapp.offlineIdOffset 5000
touch "$S/hang.log"
out="$(aapp issue log Low CLI "The tracker hangs" file src/a.sh 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && off_row 5007 && echo "$out" | grep -qiF "offline"; then
  ok "test_plugin_smart_fallback_on_timeout"
else
  bad "test_plugin_smart_fallback_on_timeout" "rc=$rc rows=$(grep -oE '^\| #[0-9]+' .offline/ISSUES.md 2>/dev/null | tr '\n' ' ') out=$out"
fi
if off_row 5007 && ! off_row 1007; then
  ok "test_custom_offset_configuration"
else
  bad "test_custom_offset_configuration" "rows=$(grep -oE '^\| #[0-9]+' .offline/ISSUES.md 2>/dev/null | tr '\n' ' ')"
fi
rm -f "$S/hang.log"; printf '%s\n' '#900' > "$S/ids"; : > "$S/log"
aapp offline on >/dev/null 2>&1; on="$(git config --get aapp.offlineOnly)"
t0="$(date +%s)"; out="$(aapp issue log Low CLI "No network wanted" file src/b.sh 2>&1)"; rc=$?; t1="$(date +%s)"
aapp offline off >/dev/null 2>&1
if [ "$on" = "true" ] && [ "$rc" -eq 0 ] && off_row 5008 && [ "$(calls q)" = "0" ] && [ $((t1 - t0)) -le 2 ] && [ "$(git config --get aapp.offlineOnly)" != "true" ]; then
  ok "test_offline_only_skips_network"
else
  bad "test_offline_only_skips_network" "on=$on rc=$rc calls=$(calls q) out=$out"
fi
git config aapp.offlineEnabled false; touch "$S/fail.log"
n0="$(grep -cE '^\| #[0-9]' .offline/ISSUES.md)"
out="$(aapp issue log Low CLI "Strict project" file src/c.sh 2>&1)"; rc=$?
git config --unset aapp.offlineEnabled; rm -f "$S/fail.log"
if [ "$rc" -ne 0 ] && [ "$(grep -cE '^\| #[0-9]' .offline/ISSUES.md)" = "$n0" ] && ! grep -qF 'Strict project' .plans/ISSUES.md; then
  ok "test_offline_disabled_fails_closed"
else
  bad "test_offline_disabled_fails_closed" "rc=$rc out=$out"
fi

echo "== draft plans =="
planid_provider "$S"; touch "$S/fail.plan"
# The highest plan id known here: the files', or the one before the counter's next.
hi="$(ls .plans/current/ .plans/done/ 2>/dev/null | sed -nE 's/^P([0-9]+)-.*/\1/p' | sort -n | tail -n 1)"; hi="${hi:-0}"
next="$(git config --get aapp.planId || echo 1)"; [ "$hi" -ge $((next - 1)) ] || hi=$((next - 1))
out="$(aapp draft over-the-ocean 2>&1)"; rc=$?
out2="$(aapp draft second-thought 2>&1)"; rc2=$?
t1="$((hi + 5000))"; t2="$((t1 + 1))"
if [ "$rc" -eq 0 ] && [ "$rc2" -eq 0 ] && [ -f ".offline/current/P$t1-over-the-ocean.md" ] && [ -f ".offline/current/P$t2-second-thought.md" ] && \
   [ ! -f ".plans/current/P$t1-over-the-ocean.md" ] && grep -qF "* **Plan ID:** P-$t1" ".offline/current/P$t1-over-the-ocean.md"; then
  ok "test_offline_draft_takes_temporary_plan_id"
else
  bad "test_offline_draft_takes_temporary_plan_id" "rc=$rc/$rc2 want P$t1 P$t2 have=$(ls .offline/current 2>/dev/null | tr '\n' ' ') out=$out"
fi
rm -f "$S/fail.plan"; printf '%s\n' 'P-77' 'P-78' > "$S/planids"; printf '%s\n' '#901' '#902' > "$S/ids"
out="$(aapp offline sync 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -f .plans/current/P77-over-the-ocean.md ] && grep -qF '* **Plan ID:** P-77' .plans/current/P77-over-the-ocean.md && \
   grep -qF "drafted offline as P-$t1" .plans/current/P77-over-the-ocean.md && [ -f .plans/current/P78-second-thought.md ] && \
   ! grep -rF "P-$t1" .plans/current .plans/state_matrix.md | grep -vqF "drafted offline as P-$t1" && ! grep -rqF "P$t1-" .plans/current .plans/state_matrix.md && \
   [ -z "$(ls .offline/current 2>/dev/null)" ] && [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_sync_gives_draft_real_plan_id"
else
  bad "test_sync_gives_draft_real_plan_id" "rc=$rc plans=$(ls .plans/current | tr '\n' ' ') left=$(ls .offline/current 2>/dev/null | tr '\n' ' ') out=$out"
fi

echo "== the record, the outbox, the push verbs =="
sandbox "$R/t"; S="$R/ctl-t"
issue() { printf '{"id": "#%s", "sev": "Low", "type": "CORE", "date": "2026-10-01", "location": "`src/%s.sh`", "symptom": "Defect %s shows.", "status": "%s"}\n' "$1" "$2" "$1" "${3:-open}"; }
touch "$S/lists"; { issue 1 a; issue 2 b; issue 3 c; } > "$S/list"
aapp issue list confirm >/dev/null 2>&1
SHA="$(git rev-parse --short=7 develop)"
touch "$S/fail.close"
aapp issue close 1 sha "$SHA" summary "Closed while the tracker was away." >/dev/null 2>&1; crc=$?
queued=0; [ -s .offline/outbox ] && grep -qF 'close' .offline/outbox && queued=1
aapp issue list >/dev/null 2>&1
kept=0; ! main_row 1 && main_archived 1 && [ -s .offline/outbox ] && kept=1
rm -f "$S/fail.close"; : > "$S/log"; { issue 2 b; issue 3 c; } > "$S/list"
aapp issue list >/dev/null 2>&1
first="$(grep -nF '"event": "issue.close"' "$S/log" | head -n 1 | cut -d: -f1)"; listed="$(grep -nF '"event": "issue.list"' "$S/log" | head -n 1 | cut -d: -f1)"
if [ "$crc" -eq 0 ] && [ "$queued" -eq 1 ] && [ "$kept" -eq 1 ] && [ -n "$first" ] && [ -n "$listed" ] && [ "$first" -lt "$listed" ] && [ ! -s .offline/outbox ]; then
  ok "test_outbox_sent_before_tracker_read"
else
  bad "test_outbox_sent_before_tracker_read" "close=$crc queued=$queued kept=$kept close@$first list@$listed"
fi

{ issue 2 b; issue 3 c; } > "$S/list"
P2="P-$(git config aapp.planId)"; aapp draft waits-too >/dev/null 2>&1
touch "$S/fail.log"
aapp issue log Low CLI "Staged where the tracker keeps the record" file src/d.sh >/dev/null 2>&1
tmp="$(grep -oE '^\| #[0-9]+' .offline/ISSUES.md | tr -d '| #' | head -n 1)"
aapp refine "$P2" blocked "$tmp" >/dev/null 2>&1
rm -f "$S/fail.log"; printf '%s\n' '#601' > "$S/ids"; plans0="$(git -C .plans rev-parse HEAD)"
aapp offline sync >/dev/null 2>&1; rc=$?
names="$(git -C .plans log --name-only --format= "$plans0"..HEAD | sort -u | tr '\n' ' ')"
if [ "$c1" -eq 1 ] && [ "$rc" -eq 0 ] && main_row 601 && blocked_on "$(pf "$P2")" | grep -qF '#601' && echo "$names" | grep -qF "current/$(basename "$(pf "$P2")")" && \
   ! echo "$names" | grep -qE 'ISSUES\.md|issues_road_map\.md|000-issues-archive\.md' && [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_sync_commits_by_record"
else
  bad "test_sync_commits_by_record" "committed-ledgers=$c1 rc=$rc names=[$names]"
fi

git init -q --bare "$R/remote.git"; git remote add origin "$R/remote.git"
aapp offline mount >/dev/null 2>&1
out="$(aapp push 2>&1 </dev/null)"; rc=$?
left_alone=0; [ -z "$(git ls-remote origin offline 2>/dev/null)" ] && left_alone=1
git config aapp.syncWorktrees "plans agents githooks offline"
out2="$(aapp push 2>&1 </dev/null)"; rc2=$?
out3="$(aapp sync 2>&1 </dev/null)"; rc3=$?
if [ "$left_alone" -eq 1 ] && [ "$rc2" -ne 0 ] && echo "$out2" | grep -qF "offline" && [ "$rc3" -ne 0 ] && [ -z "$(git ls-remote origin offline 2>/dev/null)" ]; then
  ok "test_push_verbs_refuse_offline"
else
  bad "test_push_verbs_refuse_offline" "default rc=$rc alone=$left_alone named rc=$rc2/$rc3 out=$out2"
fi

print_test_summary "$PASS" "$FAIL"
