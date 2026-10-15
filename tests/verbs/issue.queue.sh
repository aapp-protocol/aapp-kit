#!/usr/bin/env bash
# Tests: `aapp issue` behaviour contract (lib/docs/verbs/issue.md)
# Part: issue.queue.sh (the road map as a work queue: `aapp issue queue`, the
# fix gate, the tracker's queue, P-89).
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
queued() { awk '/^## 📋 Queued/ { q = 1; next } /^## / { q = 0 } q' .plans/issues_road_map.md | grep -oE '#[0-9A-Z-]+' | tr '\n' ' '; }
# project <dir>: develop checked out, issues #1..#4, an empty work queue.
project() {
  init_sandbox_project "$1"
  cd "$1" || exit 1
  mkdir -p src; for f in a b c d; do echo "$f=1" > "src/$f.sh"; done
  git add -A && git commit -qm "sources" --no-verify
  git branch develop; git checkout -q develop
  git config aapp.issueFixWait 0; git config aapp.pluginTimeout 2; git config aapp.offlineEnabled false
  { printf '%s\n' '# Issues' '' "$HDR" "$SEP"; row 1 a; row 2 b; row 3 c; row 4 d; } > .plans/ISSUES.md
  printf '%s\n' '# 🗺️ Issue Work Queue' '' '## 🧱 Plan Blockers' '' '## 📋 Queued' > .plans/issues_road_map.md
  printf '%s\n' '# Archive' '' '| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |' '| :--- | :--- | :--- | :--- | :--- | :--- | :--- |' \
    '| #7 | `Low` | `CLI` | 2026-08-01 | 2026-08-02 | `0000000` | Closed long ago. |' > .plans/done/000-issues-archive.md
  git -C .plans add -A >/dev/null 2>&1; git -C .plans commit -qm fixture --no-verify >/dev/null 2>&1
  git config aapp.issueId 10
}

echo "== aapp issue queue =="
project "$R/q"
h0="$(git -C .plans rev-parse HEAD)"
out="$(aapp issue queue 2 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(queued)" = "#2 " ] && grep -qF -- '- [ ] #2 -> Defect 2 shows.' .plans/issues_road_map.md && \
   [ "$(git -C .plans rev-list --count "$h0"..HEAD)" = "1" ] && git -C .plans log -1 --format=%s | grep -qF 'issue(queue): #2' && \
   [ -z "$(git -C .plans status --porcelain)" ]; then
  ok "test_queue_appends_to_road_map"
else
  bad "test_queue_appends_to_road_map" "rc=$rc queued=$(queued) out=$out"
fi

aapp issue queue 3 >/dev/null 2>&1
h1="$(git -C .plans rev-parse HEAD)"
out="$(aapp issue queue 2 remove 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(queued)" = "#3 " ] && [ "$(git -C .plans rev-list --count "$h1"..HEAD)" = "1" ] && grep -qE '^\| #2 \|' .plans/ISSUES.md; then
  ok "test_queue_remove"
else
  bad "test_queue_remove" "rc=$rc queued=$(queued) out=$out"
fi

h2="$(git -C .plans rev-parse HEAD)"
aapp issue queue 99 >/dev/null 2>&1; r1=$?
aapp issue queue 7 >/dev/null 2>&1; r2=$?
aapp issue queue 3 >/dev/null 2>&1; r3=$?
if [ "$r1" -ne 0 ] && [ "$r2" -ne 0 ] && [ "$r3" -ne 0 ] && [ "$(git -C .plans rev-parse HEAD)" = "$h2" ] && [ "$(queued)" = "#3 " ]; then
  ok "test_queue_refuses_invalid_or_resolved"
else
  bad "test_queue_refuses_invalid_or_resolved" "rc=$r1/$r2/$r3 queued=$(queued)"
fi

echo "== the fix gate =="
h3="$(git -C .plans rev-parse HEAD)"
out="$(aapp issue fix 1 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -qF "not queued" && echo "$out" | grep -qF "aapp issue queue 1" && \
   [ ! -f .plans/current/fix-1.md ] && [ "$(git -C .plans rev-parse HEAD)" = "$h3" ]; then
  ok "test_fix_refuses_unqueued_issue"
else
  bad "test_fix_refuses_unqueued_issue" "rc=$rc out=$out"
fi

out="$(aapp issue fix 3 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -f .plans/current/fix-3.md ] && [ -d .workspace/fix-3 ]; then
  ok "test_fix_accepts_queued_issue"
else
  bad "test_fix_accepts_queued_issue" "rc=$rc out=$out"
fi
aapp issue fix 3 abort >/dev/null 2>&1

aapp issue queue 4 >/dev/null 2>&1
out="$(aapp issue fix next-blocker 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -f .plans/current/fix-3.md ] && [ ! -f .plans/current/fix-4.md ]; then
  ok "test_fix_next_blocker_falls_back_to_queued"
else
  bad "test_fix_next_blocker_falls_back_to_queued" "rc=$rc out=$out"
fi
aapp issue fix 3 abort >/dev/null 2>&1

echo "== logging and the health check =="
cp .plans/issues_road_map.md "$R/rm.before"
out="$(aapp issue log Low CORE "A new defect shows" file src/a.sh 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -qE '^\| #10 \|' .plans/ISSUES.md && cmp -s "$R/rm.before" .plans/issues_road_map.md; then
  ok "test_log_does_not_append_to_road_map"
else
  bad "test_log_does_not_append_to_road_map" "rc=$rc diff=$(diff "$R/rm.before" .plans/issues_road_map.md | tr '\n' ' ') out=$out"
fi

health() { ( . "$KIT/lib/aapp-lib.sh"; . "$KIT/lib/planning_health.sh"; check_planning_health "$PWD" ) 2>&1; }
good="$(health)"; g=$?
printf '%s\n' '' '## Other' '- [ ] #1 -> Defect 1 shows.' >> .plans/issues_road_map.md
badout="$(health)"; b=$?
cp "$R/rm.before" .plans/issues_road_map.md
if [ "$g" -eq 0 ] && [ "$b" -ne 0 ] && echo "$badout" | grep -qF '## Other' && echo "$badout" | grep -qF '📋 Queued'; then
  ok "test_planning_health_validates_queue_format"
else
  bad "test_planning_health_validates_queue_format" "good=$g bad=$b out=$good | $badout"
fi

echo "== the tracker's queue =="
PDIR=".agents/skills/aapp-issue-tracker"
# tracker <dir>: a provider; $R/<dir>.fail.<step> fails a step, $R/<dir>.list is
# its listing (it keeps the record when $R/<dir>.lists exists).
tracker() {
  local c="$R/$(basename "$PWD")"
  mkdir -p "$PDIR"
  cat > "$PDIR/run" <<EOF
#!/bin/sh
tr -d '\n' >> "$c.log"; echo >> "$c.log"
step="\${AAPP_PLUGIN_STEP#issue.}"
[ -f "$c.fail.\$step" ] && exit 3
if [ "\$step" = "list" ]; then
  [ -f "$c.list" ] && cat "$c.list" > "\$AAPP_PLUGIN_LIST"
  if [ -f "$c.lists" ]; then echo '{"status": "ok", "handled": "list"}'; else echo '{"status": "declined"}'; fi
  exit 0
fi
echo '{"status": "ok"}'
EOF
  chmod +x "$PDIR/run"; : > "$c.log"
}
sent() { grep -F "\"event\": \"$1\"" "$R/$(basename "$PWD").log" 2>/dev/null | tail -n 1; }
tracker
aapp issue queue 1 >/dev/null 2>&1; q1=$?
aapp issue queue 1 remove >/dev/null 2>&1; q2=$?
if [ "$q1" -eq 0 ] && [ "$q2" -eq 0 ] && sent issue.queue | grep -qF '"id": "#1"' && sent issue.unqueue | grep -qF '"id": "#1"'; then
  ok "test_queue_sends_provider_steps"
else
  bad "test_queue_sends_provider_steps" "rc=$q1/$q2 log=$(cut -c1-200 "$R/q.log")"
fi
rm -rf "$PDIR"

project "$R/t"
tracker
issue() { printf '{"id": "#%s", "sev": "Low", "type": "CORE", "date": "2026-10-01", "location": "`src/%s.sh`", "symptom": "Defect %s shows.", "status": "open", "queued": %s}\n' "$1" "$2" "$1" "$3"; }
{ issue 1 a false; issue 2 b false; issue 3 c false; issue 4 d false; } > "$R/t.list"; touch "$R/t.lists"
aapp issue list confirm >/dev/null 2>&1
touch "$R/t.fail.queue"; h4="$(git -C .plans rev-parse HEAD)"
aapp issue queue 2 >/dev/null 2>&1; r1=$?
refused=0; [ "$r1" -ne 0 ] && [ -z "$(queued)" ] && refused=1
rm -f "$R/t.fail.queue"
{ issue 1 a false; issue 2 b true; issue 3 c false; issue 4 d true; } > "$R/t.list"
aapp issue list >/dev/null 2>&1
if [ "$refused" -eq 1 ] && [ "$(queued)" = "#2 #4 " ]; then
  ok "test_listing_provider_owns_the_queue"
else
  bad "test_listing_provider_owns_the_queue" "refused=$refused queued=$(queued)"
fi
rm -rf "$PDIR" "$R/t.lists"

echo "== offline =="
project "$R/o"
git config --unset aapp.offlineEnabled
tracker; touch "$R/o.fail.log"
aapp issue log Low CORE "Seen offline" file src/a.sh >/dev/null 2>&1
tmp="$(grep -oE '^\| #[0-9]+ ' .offline/ISSUES.md 2>/dev/null | tail -n 1 | tr -d '|# ')"
aapp issue queue "$tmp" >/dev/null 2>&1
aapp issue log Low CORE "Also seen offline" file src/b.sh >/dev/null 2>&1
rm -f "$R/o.fail.log"
cat > "$PDIR/run" <<EOF
#!/bin/sh
cat >/dev/null
case "\${AAPP_PLUGIN_STEP#issue.}" in
  log)  if [ -f "$R/o.second" ]; then echo '{"status": "ok", "id": "#51"}'; else touch "$R/o.second"; echo '{"status": "ok", "id": "#50"}'; fi ;;
  list) echo '{"status": "declined"}' ;;
  *)    echo '{"status": "ok"}' ;;
esac
EOF
chmod +x "$PDIR/run"
out="$(aapp offline sync 2>&1)"; rc=$?
if [ -n "$tmp" ] && [ "$rc" -eq 0 ] && [ "$(queued)" = "#50 " ] && ! grep -qF "#$tmp" .plans/issues_road_map.md; then
  ok "test_offline_sync_rewrites_queued_id"
else
  bad "test_offline_sync_rewrites_queued_id" "tmp=$tmp rc=$rc queued=$(queued) out=$out"
fi

print_test_summary "$PASS" "$FAIL"
