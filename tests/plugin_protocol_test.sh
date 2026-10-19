#!/usr/bin/env bash
# Suite for the plugin answer protocol (P-77): the exchange between the kit and
# a supported plugin (lib/hook_dispatcher.sh), exercised through the one issue
# step that exists today (`issue.close`) and through the library functions.
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-52s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-52s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1
git config aapp.issueFixWait 0

cat > .plans/ISSUES.md <<'EOF'
# Issues

| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #10 | `Low` | `CLI` | 2026-09-01 | `a.sh` | First defect. |  | 🟡 `Incubated` |
| #11 | `Medium` | `CORE` | 2026-09-02 | `b.sh` | Second defect. |  | 🟡 `Incubated` |
| #12 | `Low` | `CORE` | 2026-09-03 | `c.sh` | Third defect. |  | 🟡 `Incubated` |
| #13 | `Low` | `CORE` | 2026-09-04 | `d.sh` | Fourth defect. |  | 🟡 `Incubated` |
| #14 | `Low` | `CORE` | 2026-09-05 | `e.sh` | Fifth defect. |  | 🟡 `Incubated` |
EOF
cat > .plans/issues_road_map.md <<'EOF'
# Board

## 📋 Queued
- [ ] #10 -> First defect.
- [ ] #11 -> Second defect.
- [ ] #12 -> Third defect.
- [ ] #13 -> Fourth defect.
- [ ] #14 -> Fifth defect.
EOF
git -C .plans add -A >/dev/null 2>&1; git -C .plans commit -qm "test: ledger fixture" >/dev/null 2>&1
git config aapp.issueId 15
SHA="$(git rev-parse --short=7 HEAD)"
PDIR=".agents/skills/aapp-issue-tracker"; mkdir -p "$PDIR"
# plugin <body…>: installs a provider whose script body is the given lines.
plugin() { { echo '#!/bin/sh'; printf '%s\n' "$@"; } > "$PDIR/run"; chmod +x "$PDIR/run"; }
archived() { grep -qE "^\| #$1 \|" .plans/done/000-issues-archive.md; }

echo "== the answer =="
plugin 'cat >/dev/null' 'echo "{\"status\": \"ok\", \"message\": \"Ticket 10 closed on the tracker\"}"'
out="$(aapp issue close 10 sha "$SHA" summary "Fixed." 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -qF "Ticket 10 closed on the tracker"; then
  ok "test_message_is_shown"
else
  bad "test_message_is_shown" "rc=$rc out=$out"
fi

# Library level: the caller learns what is left to the kit.
lib_step() { # <plugin body…> -> runs one step in a subshell, prints the facts
  plugin "$@"
  ( export REPO_ROOT="$R/p"; . "$KIT/lib/hook_dispatcher.sh" >/dev/null 2>&1
    declare -f plugin_step >/dev/null || { echo "missing"; exit 0; }
    set +e
    plugin_step "$R/p/$PDIR/run" "$R/p" log issue.log '{"symptom": "x"}' >/dev/null 2>"$R/step.err"; rc=$?
    h_note=no; plugin_handled note && h_note=yes
    h_id=no; plugin_handled id && h_id=yes
    echo "rc=$rc status=${PLUGIN_STATUS:-} note=$h_note id=$h_id list=$(plugin_list_lines 2>/dev/null | wc -l | tr -d ' ')"
    plugin_list_lines 2>/dev/null | sed 's/^/L:/' )
}
a="$(lib_step 'cat >/dev/null' 'echo "{\"status\": \"ok\", \"handled\": \"id\", \"id\": \"PROJ-1\"}"' | head -1)"
b="$(lib_step 'cat >/dev/null' 'echo "{\"id\": \"PROJ-1\"}"' | head -1)"
if [ "$a" = "rc=0 status=ok note=no id=yes list=0" ] && [ "$b" = "rc=0 status=ok note=no id=no list=0" ]; then
  ok "test_unnamed_part_left_to_kit"
else
  bad "test_unnamed_part_left_to_kit" "a=[$a] b=[$b]"
fi
a="$(lib_step 'cat >/dev/null' 'echo "{\"status\": \"declined\", \"handled\": \"id, note\"}"' | head -1)"
if [ "$a" = "rc=0 status=declined note=no id=no list=0" ]; then
  ok "test_declined_leaves_all_to_kit"
else
  bad "test_declined_leaves_all_to_kit" "a=[$a]"
fi
a="$(lib_step 'cat >/dev/null' 'echo "{\"version\": \"9.0\", \"status\": \"ok\", \"handled\": \"id\"}"' | head -1)"
b="$(lib_step 'cat >/dev/null' 'echo "{\"version\": \"1.0\", \"status\": \"ok\", \"handled\": \"id\"}"' | head -1)"
if echo "$a" | grep -q '^rc=[1-9]' && echo "$a" | grep -q 'id=no' && [ "$b" = "rc=0 status=ok note=no id=yes list=0" ]; then
  ok "test_newer_version_refused"
else
  bad "test_newer_version_refused" "a=[$a] b=[$b]"
fi
a="$(lib_step 'cat >/dev/null' 'printf "%s\n" "{\"id\": \"#7\", \"symptom\": \"one\"}" "{\"id\": \"#8\", \"symptom\": \"two\"}" > "$AAPP_PLUGIN_LIST"' 'echo "{\"status\": \"ok\", \"handled\": \"list\"}"')"
if echo "$a" | head -1 | grep -q 'list=2' && echo "$a" | grep -qF 'L:{"id": "#7", "symptom": "one"}' && echo "$a" | grep -qF 'L:{"id": "#8", "symptom": "two"}'; then
  ok "test_list_file_read_per_line"
else
  bad "test_list_file_read_per_line" "a=[$a]"
fi

echo "== the do list =="
# The plugin asks for two more closes and one command off the whitelist.
plugin 'cat >/dev/null' "echo call >> \"$R/calls\"" \
  'printf "%s\n" "issue close 12 summary \"closed on the tracker\"" "draft sneaky-plan" "issue abort 13 reason \"won'"'"'t fix: superseded\"" > "$AAPP_PLUGIN_DO"' \
  'echo "{\"status\": \"ok\"}"'
: > "$R/calls"
out="$(aapp issue close 11 sha "$SHA" summary "Fixed." 2>&1)"; rc=$?
p11="$(echo "$out" | grep -n 'handed to aapp-issue-tracker' | head -1 | cut -d: -f1)"
p12="$(echo "$out" | grep -n '#12 archived' | head -1 | cut -d: -f1)"
p13="$(echo "$out" | grep -n '#13 withdrawn' | head -1 | cut -d: -f1)"
t_expect "rc" 0 "$rc"
archived 11 && archived 12 && archived 13 || t_fail "not all of #11, #12, #13 archived"
[ -n "$p11" ] && [ -n "$p12" ] && [ -n "$p13" ] && [ "$p11" -lt "$p12" ] && [ "$p12" -lt "$p13" ] || t_fail "order p=$p11/$p12/$p13"
grep -qF '| `aborted` |' .plans/done/000-issues-archive.md || t_fail "#13 not archived as aborted"
echo "$out" | grep -qF "draft sneaky-plan" && echo "$out" | grep -qi "not an accepted" || t_fail "unlisted command not refused by name"
compgen -G ".plans/current/*sneaky*" >/dev/null && t_fail "unlisted command ran"
t_expect "plugin calls" 1 "$(wc -l < "$R/calls" | tr -d ' ')"
[ -z "$T_ERR" ] || t_fail "out=$out"
t_done test_do_list_runs_accepted_commands_in_order

echo "== during a step =="
# (INNER stops the plugin calling itself for ever where the kit does not refuse.)
plugin 'cat >/dev/null' '[ -n "$INNER" ] && { echo "{\"status\": \"ok\"}"; exit 0; }; export INNER=1' \
  "aapp issue close 14 sha $SHA summary direct > \"$R/inner.out\" 2>&1; echo \"rc=\$?\" >> \"$R/inner.out\"" \
  "aapp issue list > \"$R/inner.read\" 2>&1; echo \"rc=\$?\" >> \"$R/inner.read\"" \
  'echo "{\"status\": \"ok\"}"'
git -C .plans checkout -q -- . 2>/dev/null
cat >> .plans/ISSUES.md <<'EOF'
| #20 | `Low` | `CORE` | 2026-09-06 | `f.sh` | Sixth defect. |  | 🟡 `Incubated` |
EOF
echo "- [ ] #20 -> Sixth defect." >> .plans/issues_road_map.md
git config aapp.issueId 21
git -C .plans add -A >/dev/null 2>&1; git -C .plans commit -qm "test: one more" >/dev/null 2>&1
aapp issue close 20 sha "$SHA" summary "Fixed." >/dev/null 2>&1
if grep -q '^rc=[1-9]' "$R/inner.out" 2>/dev/null && grep -q 'AAPP_PLUGIN_DO\|do list' "$R/inner.out" && ! archived 14 && \
   grep -q '^rc=0' "$R/inner.read" 2>/dev/null && grep -q '#14' "$R/inner.read"; then
  ok "test_write_verb_refused_inside_plugin"
else
  bad "test_write_verb_refused_inside_plugin" "inner=$(cat "$R/inner.out" 2>/dev/null) read=$(tail -2 "$R/inner.read" 2>/dev/null)"
fi

echo "== timeout, secrets =="
git config aapp.pluginTimeout 1
plugin 'cat >/dev/null' 'sleep 5' 'echo "{\"status\": \"ok\"}"'
t0="$(date +%s)"
out="$(aapp issue close 14 sha "$SHA" summary "Fixed." 2>&1)"; rc=$?
t1="$(date +%s)"
if [ "$rc" -eq 0 ] && archived 14 && [ $((t1 - t0)) -lt 5 ] && echo "$out" | grep -q 'aapp-issue-tracker failed'; then
  ok "test_timeout_ends_plugin"
else
  bad "test_timeout_ends_plugin" "rc=$rc secs=$((t1 - t0)) out=$out"
fi
git config --unset aapp.pluginTimeout

git remote add origin "https://bot:s3cret@example.com/acme/app.git"
a="$(lib_step "cat > \"$R/env.stdin\"; env > \"$R/env.vars\"" 'echo "{\"status\": \"ok\"}"' | head -1)"
if grep -q '"url": "https://example.com/acme/app.git"' "$R/env.stdin" 2>/dev/null && ! grep -q 's3cret' "$R/env.stdin" && \
   ! grep -q 's3cret' "$R/env.vars" && grep -q '^AAPP_PLUGIN_DO=' "$R/env.vars" && grep -q '^AAPP_PLUGIN_LIST=' "$R/env.vars"; then
  ok "test_envelope_carries_no_secret"
else
  bad "test_envelope_carries_no_secret" "a=$a stdin=$(tr -d '\n' < "$R/env.stdin" 2>/dev/null | cut -c1-200)"
fi

echo "== sample issue tracker queue events =="
SAMPLE_RUN="$KIT/examples/plugins/aapp-issue-tracker/run.sample"
if [ -f "$SAMPLE_RUN" ]; then
  SAMPLE_STORE="$R/sample_tracker.tsv"
  export AAPP_SAMPLE_TRACKER_FILE="$SAMPLE_STORE"
  # 1. issue.log
  out="$(export AAPP_PLUGIN_STEP=issue.log; printf '{"data":{"sev":"Low","type":"CLI","date":"2026-10-16","location":"foo.sh","symptom":"bar"}}\n' | sh "$SAMPLE_RUN")"
  id="$(echo "$out" | grep -oE '"id": *"[^"]+"' | cut -d'"' -f4)"
  # 2. issue.queue
  q_out="$(export AAPP_PLUGIN_STEP=issue.queue; printf '{"data":{"id":"%s"}}\n' "$id" | sh "$SAMPLE_RUN")"
  is_queued="$(grep "^$id" "$SAMPLE_STORE" | cut -f2)"
  # 3. issue.unqueue
  uq_out="$(export AAPP_PLUGIN_STEP=issue.unqueue; printf '{"data":{"id":"%s"}}\n' "$id" | sh "$SAMPLE_RUN")"
  is_unqueued="$(grep "^$id" "$SAMPLE_STORE" | cut -f2)"
  if [ "$is_queued" = "queued" ] && [ "$is_unqueued" = "open" ] && \
     echo "$q_out" | grep -q '"status": *"ok"' && echo "$uq_out" | grep -q '"status": *"ok"'; then
    ok "test_sample_issue_tracker_queue_events"
  else
    bad "test_sample_issue_tracker_queue_events" "q=$is_queued uq=$is_unqueued q_out=$q_out uq_out=$uq_out"
  fi
fi

print_test_summary "$PASS" "$FAIL"
