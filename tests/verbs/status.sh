#!/usr/bin/env bash
# Tests: `aapp status` behaviour contract (lib/docs/verbs/status.md)
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

ok()  { printf "  \033[32m✔\033[0m %-48s %s\n" "$1" "PASS"; PASS=$((PASS+1)); }
bad() { printf "  \033[31m✘\033[0m %-48s %s\n" "$1" "$2"; FAIL=$((FAIL+1)); }

init_sandbox_project "$R/p"
cd "$R/p" || exit 1

out="$(aapp status short 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | wc -l)" -eq 1 ] && printf '%s' "$out" | grep -q '^📊 Overview:'; then
  ok "test_short_is_one_line"
else
  bad "test_short_is_one_line" "rc=$rc lines=$(printf '%s\n' "$out" | wc -l)"
fi

# P-94: the overview is the JSON's `overview`; the two tokens do not combine.
# P-100: the refusal is the error document on stdout, the message on stderr.
sout="$(aapp status short json 2>/dev/null)"; src=$?
serr="$(aapp status short json 2>&1 >/dev/null)"
if [ "$src" -ne 0 ] && printf '%s\n' "$sout" | grep -q '"error": {' && printf '%s\n' "$sout" | grep -qF '"code": "usage"' && \
   ! printf '%s\n' "$sout" | grep -qF '"overview"' && echo "$serr" | grep -qi 'usage'; then
  ok "test_short_json_refused"
else
  bad "test_short_json_refused" "rc=$src out=$sout err=$serr"
fi

out="$(aapp status 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s\n' "$out" | grep -c 'Next Action:')" -eq 1 ]; then
  ok "test_briefing_has_next_action"
else
  bad "test_briefing_has_next_action" "rc=$rc"
fi

# P-54: a plan's worktree is shown next to it.
git branch develop
git config aapp.planWorktrees on
sid="P-$(git config aapp.planId)"; aapp draft shown-wt >/dev/null 2>&1
sf="$(ls .plans/current/P"${sid#P-}"-*.md)"
sed -i -E "s|src/path/to/file\.ext|src/shown.py|g; /src\/path\/to\/new_file\.ext/d" "$sf"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$sf"; git -C .plans commit -qam prep >/dev/null 2>&1
aapp freeze-start "$sid" >/dev/null 2>&1
out="$(aapp status 2>&1)"
if echo "$out" | grep -qF "$sid: $(basename "$sf")  (⚡ In Development → .workspace/P${sid#P-})"; then
  ok "test_plan_worktree_shown_next_to_plan"
else
  bad "test_plan_worktree_shown_next_to_plan" "$(echo "$out" | grep -F "$sid")"
fi

# P-64: members are listed under their group.
gid="P-$(git config aapp.planId)"; aapp draft grouped group >/dev/null 2>&1
mid="P-$(git config aapp.planId)"; aapp draft in-group group "$gid" >/dev/null 2>&1
out="$(aapp status 2>&1)"
gline="$(printf '%s\n' "$out" | grep -n "$gid: " | head -1 | cut -d: -f1)"
mline="$(printf '%s\n' "$out" | grep -n "$mid: " | head -1 | cut -d: -f1)"
if [ -n "$gline" ] && [ -n "$mline" ] && [ "$mline" -eq $((gline + 1)) ] && \
   printf '%s\n' "$out" | sed -n "${mline}p" | grep -qE "^ {4,}.*$mid: "; then
  ok "test_members_listed_under_group"
else
  bad "test_members_listed_under_group" "$(printf '%s\n' "$out" | grep -E "$gid|$mid")"
fi

# P-63: open adoption tasks show in overview and briefing; none when none open.
cat <<'EOF' > .plans/adoption.md
# 📋 Adoption Checklist
- [ ] `[TEST-TASK]` Test open task → MANUAL: Overview
- [x] `[DONE-TASK]` Done task → MANUAL: Overview
EOF
out="$(aapp status 2>&1)"
# The Overview line keeps to the width (P-92): read it with its wrapped part.
if echo "$out" | tr '\n' ' ' | tr -s ' ' | grep -qE '📊 Overview:[^=]*\| 1 adoption' && \
   echo "$out" | grep -qF '📋 Adoption: 1 open task(s) in .plans/adoption.md'; then
  ok "test_overview_counts_open_adoption_tasks"
else
  bad "test_overview_counts_open_adoption_tasks" "$(echo "$out" | grep -E 'Overview|Adoption')"
fi

# With no open tasks, neither is printed
sed -i -E 's/^- \[ \]/- [x]/' .plans/adoption.md
out="$(aapp status 2>&1)"
if ! echo "$out" | grep -q 'adoption' && ! echo "$out" | grep -q '📋 Adoption:'; then
  ok "test_no_adoption_output_when_none_open"
else
  bad "test_no_adoption_output_when_none_open" "$(echo "$out" | grep -E 'Overview|Adoption')"
fi
rm -f .plans/adoption.md

# pillar_fixture: a changelog with entries in three sections, three issues
# (#1 queued urgent, #2 queued normal, #3 not queued) and two pickup ideas.
pillar_fixture() {
  git config aapp.issueFixWait 0; git config aapp.offlineEnabled false
  sed -i 's/^- Initial project architecture and foundation\.$/- Initial project architecture and foundation.\n- A second added entry that is long enough to show how the briefing prints a long changelog line today./' CHANGELOG.md
  sed -i 's/^### Fixed$/### Fixed\n- A fixed entry./' CHANGELOG.md
  git add CHANGELOG.md && git commit -qm "docs: changelog fixture" --no-verify
  local hdr='| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |'
  local sep='| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |'
  { printf '%s\n' '# Issues' '' "$hdr" "$sep"
    printf '%s\n' '| #1 | `Medium` | `CLI` | 2026-10-01 | `src/a.sh` | First symptom, queued urgently, with a long text that runs well past the width of a narrow terminal pane to show wrapping. |  | 🟡 `Incubated` |'
    printf '%s\n' '| #2 | `Low` | `CORE` | 2026-10-02 | `src/b.sh` | Second symptom, queued. |  | 🟡 `Incubated` |'
    printf '%s\n' '| #3 | `High` | `HOOK` | 2026-10-03 | `src/c.sh` | Third symptom, not queued. |  | 🟡 `Incubated` |'
  } > .plans/ISSUES.md
  printf '%s\n' '# 🗺️ Issue Work Queue' '' '## 🧱 Plan Blockers' '' '## 📋 Queued' '' '### 🔺 Urgent' \
    '- [ ] #1 -> First symptom, queued urgently, with a long text that runs well past the width of a narrow terminal pane to show wrapping. (queued 2026-10-04)' \
    '' '### Normal' '- [ ] #2 -> Second symptom, queued. (queued 2026-10-05)' '' '### Low' > .plans/issues_road_map.md
  printf '%s\n' "- [ ] Fixture Idea: an idea with a text long enough to pass the width of a narrow terminal pane when printed whole on one line." "- [ ] Second Idea: short." >> .plans/pickup.md
  git -C .plans add -A >/dev/null 2>&1; git -C .plans commit -qm fixture --no-verify >/dev/null 2>&1
  git config aapp.issueId 10
}
# pillar <heading start> <briefing>: the pillar's lines, from its heading to the blank line after it.
pillar() { printf '%s\n' "$2" | awk -v h="$1" 'index($0, h) == 1 { on = 1 } on && /^$/ { exit } on'; }

echo "== records and width (P-92) =="
# shellcheck source=/dev/null
. "$KIT/lib/aapp-lib.sh"
init_sandbox_project "$R/w"
cd "$R/w" || exit 1
export AAPP_STATE_DIR="$R/state"
pillar_fixture >/dev/null 2>&1
out="$(aapp status 2>&1)"
want_issues='🐛 [2/4] ISSUES (Work Queue & Ledger)
  #1  Medium  Incubated  logged 2026-10-01  queued 2026-10-04 (Urgent)
        First symptom, queued urgently, with a long text that runs well past the
        width of a narrow terminal pane to show wrapping.
  #2  Low  Incubated  logged 2026-10-02  queued 2026-10-05 (Normal)
        Second symptom, queued.
  ℹ️  1 more issue(s) logged, not queued for work: aapp issue list'
if [ "$(pillar '🐛 [2/4]' "$out")" = "$want_issues" ]; then
  ok "test_issues_pillar_layout"
else
  bad "test_issues_pillar_layout" "$(diff <(printf '%s\n' "$want_issues") <(pillar '🐛 [2/4]' "$out"))"
fi

# 60 columns; a plan in a worktree under a long path; the notices and the next
# action are long. Only Shipped, the issue lines and Pickup keep their form.
git branch develop >/dev/null 2>&1
git config aapp.planWorktrees on
# A path is one word: it moves to a line of its own, it is never cut.
git config aapp.planWorktreePath ".workspace/a-long-plan-folder-{id}"
wid="P-$(git config aapp.planId)"; aapp draft wide-plan >/dev/null 2>&1
wf="$(ls .plans/current/P"${wid#P-}"-*.md)"
sed -i -E "s|src/path/to/file\.ext|src/wide.py|g; /src\/path\/to\/new_file\.ext/d" "$wf"
sed -i -E 's/^\* \[ \] \*\*Question/* [x] **Question/' "$wf"; git -C .plans commit -qam prep >/dev/null 2>&1
aapp freeze-start "$wid" >/dev/null 2>&1
git config aapp.statusOutputWidth 60
out="$(aapp status 2>&1)"
git config --unset aapp.statusOutputWidth
over="$(printf '%s\n' "$out" | awk '
    index($0, "📦 [1/4]") == 1 || index($0, "💡 [4/4]") == 1 { skip = 1 }
    skip && /^$/ { skip = 0 }
    !skip && !/^  #[0-9]/' | while IFS= read -r l; do [ "$(aapp_char_len "$l")" -gt 60 ] && printf '%s\n' "$l"; done)"
if [ -z "$over" ] && printf '%s\n' "$out" | grep -qF "$wid: " && printf '%s\n' "$out" | grep -q 'Next Action:'; then
  ok "test_briefing_lines_within_width"
else
  bad "test_briefing_lines_within_width" "over 60: $over"
fi

# The pickup records: title, text, files; a missing file is a warning notice.
mkdir -p .plans/pickup && echo notes > .plans/pickup/kept.md
printf '%s\n' '- [ ] Config CLI (`aapp config: set`): manage keys' \
  '- [ ] an entry left without a title' \
  '- [ ] Linked Idea: see `.plans/pickup/kept.md` and `.plans/pickup/gone.md`.' >> .plans/pickup.md
recs="$(REPO_ROOT="$PWD" AAPP_LIB="$KIT/lib" AAPP_STATUS_LIB_ONLY=1 bash -c '. "$AAPP_LIB/aapp-lib.sh"; . "$AAPP_LIB/cmd_status.sh"; status_records_pickup' 2>&1)"
notes="$(REPO_ROOT="$PWD" AAPP_LIB="$KIT/lib" AAPP_STATUS_LIB_ONLY=1 bash -c '. "$AAPP_LIB/aapp-lib.sh"; . "$AAPP_LIB/cmd_status.sh"; status_notices' 2>&1)"
if printf '%s\n' "$recs" | grep -qxF "$(printf 'Config CLI (`aapp config: set`)\tmanage keys\t')" && \
   printf '%s\n' "$recs" | grep -qxF "$(printf '\tan entry left without a title\t')" && \
   printf '%s\n' "$recs" | grep -qxF "$(printf 'Linked Idea\tsee `.plans/pickup/kept.md` and `.plans/pickup/gone.md`.\t.plans/pickup/kept.md')" && \
   printf '%s\n' "$notes" | grep -qE "^warning	pickup	.*\.plans/pickup/gone\.md"; then
  ok "test_pickup_records"
else
  bad "test_pickup_records" "recs=$recs notes=$notes"
fi
git -C .plans checkout -q -- pickup.md

echo "== shipped: what landed last (P-88) =="
init_sandbox_project "$R/s"
cd "$R/s" || exit 1
# cl_add <section> <entry>: adds the entry under the section of [Unreleased] and commits it.
cl_add() {
  awk -v sec="### $1" -v e="- $2" '{ print } $0 == sec && !done { print e; done = 1 }' CHANGELOG.md > CHANGELOG.md.new && mv CHANGELOG.md.new CHANGELOG.md
  git add CHANGELOG.md && git commit -qm "docs: $2" --no-verify
}
shipped_lines() { pillar '📦 [1/4]' "$(aapp status 2>&1)" | tail -n +2; }
for i in $(seq 1 30); do printf -- '- Added entry %02d.\n' "$i"; done > "$R/added"
awk -v f="$R/added" '{ print } $0 == "### Added" { while ((getline l < f) > 0) print l }' CHANGELOG.md > CHANGELOG.md.new && mv CHANGELOG.md.new CHANGELOG.md
git add CHANGELOG.md && git commit -qm "docs: thirty entries" --no-verify
cl_add Fixed "A fix that landed last."
if [ "$(shipped_lines | head -1)" = "  - A fix that landed last." ]; then
  ok "test_shipped_shows_latest_landed"
else
  bad "test_shipped_shows_latest_landed" "$(shipped_lines | head -3)"
fi

cl_add Added "Entry one."; cl_add Fixed "Entry two."; cl_add Changed "Entry three."
if [ "$(shipped_lines | head -3)" = "$(printf '  - %s\n' 'Entry three.' 'Entry two.' 'Entry one.')" ]; then
  ok "test_shipped_newest_first_across_sections"
else
  bad "test_shipped_newest_first_across_sections" "$(shipped_lines | head -4)"
fi

cl_add Fixed "Removed later."; cl_add Fixed "Worded first."
sed -i '/^- Removed later\.$/d' CHANGELOG.md; git commit -qam "docs: drop an entry" --no-verify
sed -i 's/^- Worded first\.$/- Worded again./' CHANGELOG.md; git commit -qam "docs: reword" --no-verify
s="$(shipped_lines)"
if ! printf '%s\n' "$s" | grep -qF 'Removed later.' && ! printf '%s\n' "$s" | grep -qF 'Worded first.' && \
   [ "$(printf '%s\n' "$s" | grep -cF 'Worded again.')" = "1" ]; then
  ok "test_shipped_skips_removed_entry"
else
  bad "test_shipped_skips_removed_entry" "$s"
fi

if [ "$(shipped_lines | tail -1)" = "  (more in CHANGELOG.md)" ] && [ "$(shipped_lines | grep -c '^  - ')" = "5" ]; then
  ok "test_shipped_points_to_changelog"
else
  bad "test_shipped_points_to_changelog" "$(shipped_lines)"
fi

long="$(for i in $(seq 1 40); do printf 'lengthy%02d ' "$i"; done)"; long="${long% }"
cl_add Changed "$long"
s="$(shipped_lines | awk '/^  - lengthy01/ { on = 1 } on && /^  - / && !/lengthy01/ { exit } on')"
first="$(printf '%s\n' "$s" | head -1)"
over="$(printf '%s\n' "$s" | while IFS= read -r l; do [ "$(aapp_char_len "$l")" -gt 85 ] && echo "$l"; done)"
body="$(printf '%s\n' "$s" | sed -E 's/^ +(- )?//' | tr '\n' ' ' | sed 's/ $//')"
if [[ "$first" == "  - lengthy01"* ]] && ! printf '%s\n' "$s" | tail -n +2 | grep -qvE '^    [^ ]' && [ -z "$over" ] && \
   [[ "$body" == *"…" ]] && [ "$(aapp_char_len "$body")" -le 220 ]; then
  ok "test_shipped_entry_wrapped"
else
  bad "test_shipped_entry_wrapped" "len=$(aapp_char_len "$body") $s"
fi

# The records: from history with commit and date; from the file without them.
cl_add Fixed "Tagged entry (P-7)"
sha="$(git rev-parse --short HEAD)"; day="$(git log -1 --format=%ad --date=short)"
rec="$(REPO_ROOT="$PWD" AAPP_LIB="$KIT/lib" AAPP_STATUS_LIB_ONLY=1 bash -c '. "$AAPP_LIB/aapp-lib.sh"; . "$AAPP_LIB/cmd_status.sh"; status_records_shipped' 2>&1 | head -1)"
mkdir -p "$R/nohist" && cp CHANGELOG.md "$R/nohist/" && git init -q "$R/nohist"
frec="$(cd "$R/nohist" && REPO_ROOT="$PWD" AAPP_LIB="$KIT/lib" AAPP_STATUS_LIB_ONLY=1 bash -c '. "$AAPP_LIB/aapp-lib.sh"; . "$AAPP_LIB/cmd_status.sh"; status_records_shipped' 2>&1)"
if [ "$rec" = "$(printf 'entry\tfixed\tTagged entry (P-7)\tP-7\t\t%s\t%s' "$sha" "$day")" ] && \
   printf '%s\n' "$frec" | head -1 | grep -qE '^entry	[a-z]+	.+			$' && ! printf '%s\n' "$frec" | grep -q '^heading'; then
  ok "test_shipped_record_fields"
else
  bad "test_shipped_record_fields" "rec=[$rec] want sha=$sha day=$day fallback=[$(printf '%s\n' "$frec" | head -2)]"
fi
if printf '%s\n' "$frec" | grep -q '^entry' && ! printf '%s\n' "$frec" | grep -q '^heading' && \
   [ "$(printf '%s\n' "$frec" | grep '^entry' | head -1 | cut -f3)" = "$(awk '/## \[Unreleased\]/ { u = 1; next } /^## / { u = 0 } u && /^- / { sub(/^- /, ""); print; exit }' CHANGELOG.md)" ]; then
  ok "test_shipped_fallback_without_history"
else
  bad "test_shipped_fallback_without_history" "$frec"
fi

echo "== pickup: bounded and wrapped (P-88) =="
pickup_lines() { pillar '💡 [4/4]' "$(aapp status 2>&1)"; }
for i in 1 2 3 4 5 6; do printf -- '- [ ] Idea %s: text %s.\n' "$i" "$i"; done >> .plans/pickup.md
p="$(pickup_lines)"
if [ "$(printf '%s\n' "$p" | grep -c '^  - \[ \] ')" = "5" ] && printf '%s\n' "$p" | grep -qxF '  ... and 2 more (see .plans/pickup.md)'; then
  ok "test_pickup_capped_with_more"
else
  bad "test_pickup_capped_with_more" "$p"
fi
git -C .plans checkout -q -- pickup.md

big="$(for i in $(seq 1 90); do printf 'detail%02d ' "$i"; done)"; big="${big% }"
printf -- '- [ ] Large Idea: %s\n' "$big" > "$R/large"
awk -v f="$R/large" '/^## 🆕 New Ideas/ { print; while ((getline l < f) > 0) print l; next } { print }' .plans/pickup.md > "$R/pk" && cp "$R/pk" .plans/pickup.md
p="$(pickup_lines)"
item="$(printf '%s\n' "$p" | awk '/^  - \[ \] Large Idea$/ { on = 1; print; next } on && /^        / { print; next } on { exit }')"
text="$(printf '%s\n' "$item" | tail -n +2 | sed -E 's/^ +//' | tr '\n' ' ' | sed 's/ $//')"
over="$(printf '%s\n' "$item" | while IFS= read -r l; do [ "$(aapp_char_len "$l")" -gt 85 ] && echo "$l"; done)"
if [ "$(printf '%s\n' "$item" | head -1)" = "  - [ ] Large Idea" ] && [ "$(printf '%s\n' "$item" | wc -l)" -ge 3 ] && \
   [ -z "$over" ] && [[ "$text" == "detail01"*"…" ]] && [ "$(aapp_char_len "$text")" -le 220 ]; then
  ok "test_pickup_bounded_and_wrapped"
else
  bad "test_pickup_bounded_and_wrapped" "len=$(aapp_char_len "$text") $item"
fi
git -C .plans checkout -q -- pickup.md

git config aapp.pickupTitleMax 150
ltitle="$(for i in $(seq 1 14); do printf 'Titleword%02d ' "$i"; done)"; ltitle="${ltitle% }"
printf -- '- [ ] %s: short text.\n' "$ltitle" > "$R/large"
awk -v f="$R/large" '/^## 🆕 New Ideas/ { print; while ((getline l < f) > 0) print l; next } { print }' .plans/pickup.md > "$R/pk" && cp "$R/pk" .plans/pickup.md
p="$(pickup_lines)"
item="$(printf '%s\n' "$p" | awk '/^  - \[ \] Titleword01/ { on = 1; print; next } on && /^        / { print; next } on { exit }')"
over="$(printf '%s\n' "$item" | while IFS= read -r l; do [ "$(aapp_char_len "$l")" -gt 85 ] && echo "$l"; done)"
if [ -z "$over" ] && printf '%s\n' "$item" | sed -n 2p | grep -qE '^        Titleword' && printf '%s\n' "$item" | grep -qxF '        short text.'; then
  ok "test_pickup_long_title_wraps"
else
  bad "test_pickup_long_title_wraps" "$item"
fi
git config --unset aapp.pickupTitleMax
git -C .plans checkout -q -- pickup.md

mkdir -p .plans/pickup && echo notes > .plans/pickup/linked-notes.md
printf -- '%s\n' '- [ ] Linked Idea: see `.plans/pickup/linked-notes.md`.' '- [ ] an idea without a title' > "$R/large"
awk -v f="$R/large" '/^## 🆕 New Ideas/ { print; while ((getline l < f) > 0) print l; next } { print }' .plans/pickup.md > "$R/pk" && cp "$R/pk" .plans/pickup.md
p="$(pickup_lines)"
if printf '%s\n' "$p" | grep -A2 -xF '  - [ ] Linked Idea' | grep -qxF '        files: .plans/pickup/linked-notes.md' && \
   printf '%s\n' "$p" | grep -qxF '  - [ ] an idea without a title'; then
  ok "test_pickup_files_line"
else
  bad "test_pickup_files_line" "$p"
fi
git -C .plans checkout -q -- pickup.md

git config aapp.statusItemsMax 2; git config aapp.statusTextMax 50
for i in 1 2 3; do printf -- '- [ ] Idea %s: %s\n' "$i" "$big"; done >> .plans/pickup.md
s="$(shipped_lines)"; p="$(pickup_lines)"
t1="$(printf '%s\n' "$p" | awk '/^  - \[ \] Idea 1$/ { on = 1; next } on && /^        / { print; next } on { exit }' | sed -E 's/^ +//' | tr '\n' ' ' | sed 's/ $//')"
git config aapp.statusItemsMax many
bout="$(aapp status 2>&1)"; brc=$?
git config --unset aapp.statusItemsMax; git config aapp.statusTextMax 0
cout="$(aapp status 2>&1)"; crc=$?
git config --unset aapp.statusTextMax
git -C .plans checkout -q -- pickup.md
if [ "$(printf '%s\n' "$s" | grep -c '^  - ')" = "2" ] && [ "$(printf '%s\n' "$p" | grep -c '^  - \[ \] ')" = "2" ] && \
   [ "$(aapp_char_len "$t1")" -le 50 ] && [[ "$t1" == *"…" ]] && \
   [ "$brc" -ne 0 ] && echo "$bout" | grep -q "aapp.statusItemsMax" && [ "$crc" -ne 0 ] && echo "$cout" | grep -q "aapp.statusTextMax"; then
  ok "test_status_limit_settings"
else
  bad "test_status_limit_settings" "shipped=$(printf '%s\n' "$s" | grep -c '^  - ') ideas=$(printf '%s\n' "$p" | grep -c '^  - \[ \] ') t1=[$t1] many=$brc zero=$crc"
fi
cd "$R/p" || exit 1

print_test_summary "$PASS" "$FAIL"
