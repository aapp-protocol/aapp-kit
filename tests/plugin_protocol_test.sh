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
if [ "$rc" -eq 0 ] && archived 11 && archived 12 && archived 13 && \
   [ -n "$p11" ] && [ -n "$p12" ] && [ -n "$p13" ] && [ "$p11" -lt "$p12" ] && [ "$p12" -lt "$p13" ] && \
   grep -qF '| `aborted` |' .plans/done/000-issues-archive.md; then
  ok "test_do_runs_after_step_in_order"
else
  bad "test_do_runs_after_step_in_order" "rc=$rc p=$p11/$p12/$p13 out=$out"
fi
if echo "$out" | grep -qF "draft sneaky-plan" && echo "$out" | grep -qi "not an accepted" && ! ls .plans/current | grep -q sneaky; then
  ok "test_do_refuses_unlisted_command"
else
  bad "test_do_refuses_unlisted_command" "out=$out"
fi
if archived 13; then ok "test_do_continues_after_refusal"; else bad "test_do_continues_after_refusal" "out=$out"; fi
calls="$(wc -l < "$R/calls" | tr -d ' ')"
if [ "$calls" = "1" ]; then ok "test_do_does_not_recall_plugin"; else bad "test_do_does_not_recall_plugin" "plugin called $calls times"; fi

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

echo "== the reference =="
# Every event the code sends, every data field of the issue steps, every answer
# field the kit reads and every `do` command it accepts is in docs/reference/.
P06="$KIT/docs/reference/06-plugin-protocol.md"; P07="$KIT/docs/reference/07-issue-protocol.md"
missing=""
if [ -f "$P06" ] && [ -f "$P07" ] && [ -f "$KIT/lib/plugin_do.tsv" ]; then
  for ev in $(grep -ohE '\bissue\.[a-z][a-z-]*[a-z]\b' "$KIT"/lib/cmd_issue.sh "$KIT"/lib/plan_resolver.sh | sort -u); do
    grep -qF "\`$ev\`" "$P07" || missing="$missing event:$ev"
  done
  for key in $(grep -E 'data="\{' "$KIT/lib/cmd_issue.sh" | grep -oE '\\"[a-z_]+\\":' | tr -d '\\":' | sort -u); do
    grep -qF "\`$key\`" "$P07" || missing="$missing field:$key"
  done
  for key in status message handled version id tracker url error; do
    grep -qF "\`$key\`" "$P06" || missing="$missing answer:$key"
  done
  while IFS="$(printf '\t')" read -r subject cmd; do
    case "$subject" in ''|'#'*) continue ;; esac
    [ "$subject" = "issue" ] || continue
    grep -qF "\`$cmd\`" "$P07" || missing="$missing do:$cmd"
  done < "$KIT/lib/plugin_do.tsv"
  for cmd in $(awk '/^## .*`do`/ { d = 1; next } /^## / { d = 0 } d' "$P07" | grep -oE '^\| `issue [a-z-]+`' | tr -d '|`' | sed 's/^ //; s/ /_/g'); do
    grep -qF "issue	${cmd#issue_}" "$KIT/lib/plugin_do.tsv" 2>/dev/null || grep -qF "$(printf 'issue\tissue %s' "${cmd#issue_}")" "$KIT/lib/plugin_do.tsv" || missing="$missing undocumented-do:$cmd"
  done
  if [ -z "$missing" ]; then ok "test_reference_matches_code"; else bad "test_reference_matches_code" "missing:$missing"; fi
else
  bad "test_reference_matches_code" "docs/reference/06, 07 or lib/plugin_do.tsv not written"
fi

print_test_summary "$PASS" "$FAIL"
