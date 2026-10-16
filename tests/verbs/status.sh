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
if echo "$out" | grep -qE '^[[:space:]]*📊 Overview:.*\| 1 adoption' && \
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
want_shipped='📦 [1/4] SHIPPED (Recently Landed / Unreleased)
  ### Added
  - Initial project architecture and foundation.
  - A second added entry that is long enough to show how the briefing prints a long changelog line today.
  ### Changed
  ### Fixed'
want_issues='🐛 [2/4] ISSUES (Work Queue & Ledger)
  #1     Medium   Incubated  logged 2026-10-01  queued 2026-10-04 (Urgent)   First symptom, queued urgently, with a long text that runs well past the width of a narrow terminal pane to show wrapping.
  #2     Low      Incubated  logged 2026-10-02  queued 2026-10-05 (Normal)   Second symptom, queued.
  ℹ️  1 more issue(s) logged, not queued for work: aapp issue list'
want_pickup="💡 [4/4] PICKUP QUEUE (Unprocessed Ideas)
  (3 unworked ideas found in pickup.md):
  - [ ] Onboarding: Inspect repository codebase to populate .agents/CODEMAP.md, ARCHITECTURE.md, and .agents/PROJECT.MD: read the directory layout, build manifests, dependencies and entry points, and replace the template placeholders with the real modules, exported interfaces, runtime rules and milestones. The plan's Target Files are those three files only.
  - [ ] Fixture Idea: an idea with a text long enough to pass the width of a narrow terminal pane when printed whole on one line.
  - [ ] Second Idea: short."
if [ "$(pillar '📦 [1/4]' "$out")" = "$want_shipped" ] && [ "$(pillar '🐛 [2/4]' "$out")" = "$want_issues" ] && \
   [ "$(pillar '💡 [4/4]' "$out")" = "$want_pickup" ]; then
  ok "test_briefing_unchanged_for_pillars"
else
  bad "test_briefing_unchanged_for_pillars" "$(diff <(printf '%s\n' "$want_shipped" "" "$want_issues" "" "$want_pickup") <(pillar '📦 [1/4]' "$out"; echo; pillar '🐛 [2/4]' "$out"; echo; pillar '💡 [4/4]' "$out"))"
fi

# 60 columns; a plan in a worktree under a long path; the notices and the next
# action are long. Only Shipped, the issue lines and Pickup keep their form.
git branch develop >/dev/null 2>&1
git config aapp.planWorktrees on
git config aapp.planWorktreePath ".workspace/a-rather-long-folder-name-for-every-plan-worktree-{id}"
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
cd "$R/p" || exit 1

print_test_summary "$PASS" "$FAIL"
