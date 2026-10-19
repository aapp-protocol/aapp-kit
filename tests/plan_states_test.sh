#!/usr/bin/env bash
# Core suite for lib/plan_states.sh (P-30, #85): the plan status registry and
# the Status-line accessors. Each scenario runs in its own repository, so git
# config cannot leak between tests.
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT

in_scratch_repo() {
  local dir="$R/$1"; shift
  mkdir -p "$dir"
  (
    cd "$dir" || exit 1
    git init -q .
    # shellcheck source=/dev/null
    . "$KIT/lib/plan_states.sh"
    "$@"
  )
}

CUSTOM="👀|Awaiting Review|👀 Awaiting External Review|25"

echo "== registry =="
t_defaults() {
  plan_states_load
  local s out=""
  for s in '🟣 Under Review' '📝 Refining' '🔷 Frozen' '⚡ In Development' '🟥 BLOCKED'; do
    out="$out$(plan_state_for_status_line "* **Status:** $s"),"
  done
  echo "${out%,}"
}
t_expect "slugs" "under-review,refining,frozen,in-development,blocked" "$(in_scratch_repo defaults t_defaults)"
t_done test_defaults_resolve_by_name

t_shapes() {
  plan_states_load
  local n=0
  plan_state_for_status_line '* **Status:** ⚡ In Development' >/dev/null && n=$((n+1))
  plan_state_for_status_line '- **Status:** ⚡ In Development' >/dev/null && n=$((n+1))
  plan_state_for_status_line '  *  **Status:**   ⚡   In Development  ' >/dev/null && n=$((n+1))
  plan_state_for_status_line '**Status:** ⚡ In Development (active)' >/dev/null && n=$((n+1))
  echo "$n"
}
t_expect "shapes resolved" 4 "$(in_scratch_repo shapes t_shapes)"
t_done test_status_line_shapes

t_sections() {
  plan_states_load
  [ "$(plan_state_field under-review heading)" = "$(plan_state_field refining heading)" ] && echo shared || echo split
  plan_state_sections | wc -l | tr -d ' '
  plan_state_sections | head -1
}
t_expect "sections" "shared
4
🧠 Human Thought & Refinement (The Incubator)" "$(in_scratch_repo sections t_sections)"
t_done test_sections_in_rank_order

t_custom() {
  git config aapp.planState.awaiting-review "$CUSTOM"
  plan_states_load
  plan_state_for_status_line '* **Status:** 👀 Awaiting Review'
  plan_state_sections | sed -n '3p'
  plan_state_emoji_class
}
t_expect "custom" "awaiting-review
👀 Awaiting External Review
🟣|📝|🔷|⚡|🟥|👀" "$(in_scratch_repo custom t_custom)"
t_done test_custom_status_from_config

t_override() {
  git config aapp.planState.frozen "🔷|Frozen|🔷 Greenlit|20"
  plan_states_load
  plan_state_field frozen heading
  plan_state_sections | sed -n '2p'
}
t_expect "override" "🔷 Greenlit
🔷 Greenlit" "$(in_scratch_repo override t_override)"
t_done test_override_by_slug_keeps_position

t_malformed() {
  git config aapp.planState.bad1 "only|three|fields"
  git config aapp.planState.bad2 "🔵|Name|Heading|not-a-number"
  git config aapp.planState.bad3 "||Heading|5"
  local warns
  warns="$(plan_states_load 2>&1 >/dev/null | grep -c "Skipping" | tr -d ' ')"
  plan_states_load 2>/dev/null
  echo "$warns"
  plan_state_for_status_line '* **Status:** 🔷 Frozen'
  plan_state_emoji_class | grep -c "🔵" | tr -d ' '
}
t_expect "warnings, frozen, rejected glyph" "3
frozen
0" "$(in_scratch_repo malformed t_malformed)"
t_done test_malformed_entries_skipped

t_unrecognized() {
  plan_states_load
  plan_state_for_status_line '* **Status:** 🔴 Something Retired' >/dev/null 2>&1 && echo matched || echo unrecognized
  plan_state_for_status_line '* **Status:** 🍀 Totally Made Up' >/dev/null 2>&1 && echo matched || echo unrecognized
  plan_state_emoji_class | grep -cE '🔴|🟡' | tr -d ' '
}
t_expect "retired, unknown, retired glyphs in class" "unrecognized
unrecognized
0" "$(in_scratch_repo unrecognized t_unrecognized)"
t_done test_unrecognized_statuses

echo "== Status-line accessors (#85) =="
# hdr <file> <status>: a plan whose header carries <status>, with a decoy
# Status line in a fence and one after the first `## `.
hdr() {
  printf '# Plan\n* **Plan ID:** P-1\n* **Status:** %s\n```\n* **Status:** 🔷 Frozen\n```\n## 1. Context\n* **Status:** 🔷 Frozen\n' "$2" > "$1"
}

t_slug_reads_header_only() {
  hdr p.md "⚡ In Development"
  echo "$(plan_status_slug p.md),$(plan_status_slug < p.md),$(plan_status_text p.md)"
}
t_expect "slug" "in-development,in-development,⚡ In Development" "$(in_scratch_repo acc1 t_slug_reads_header_only)"
t_done test_status_slug_reads_the_header_line_only

t_name_alone_decides() {
  hdr a.md "🛑 BLOCKED"; hdr b.md "BLOCKED"; hdr c.md "🟥 BLOCKED"
  printf '# Plan\n## 1. Context\n' > d.md
  echo "[$(plan_status_slug a.md)][$(plan_status_slug b.md)][$(plan_status_slug c.md)][$(plan_status_slug d.md)]"
}
t_expect "slugs" "[blocked][blocked][blocked][]" "$(in_scratch_repo acc2 t_name_alone_decides)"
t_done test_status_matched_by_name_whatever_the_glyph

t_status_is() {
  hdr p.md "🟥 BLOCKED"
  local r=""
  plan_status_is p.md in-development blocked && r="${r}y" || r="${r}n"
  plan_status_is p.md frozen && r="${r}y" || r="${r}n"
  printf '# Plan\n' > none.md
  plan_status_is none.md blocked && r="${r}y" || r="${r}n"
  echo "$r"
}
t_expect "matches" "ynn" "$(in_scratch_repo acc3 t_status_is)"
t_done test_status_is_matches_any_given_slug

t_set_status() {
  hdr p.md "🔷 Frozen"
  plan_set_status p.md in-development || { echo "refused"; return; }
  echo "$(plan_status_text p.md)|$(sed -n 5p p.md)|$(sed -n 8p p.md)"
}
t_expect "header, fence, after" "⚡ In Development|* **Status:** 🔷 Frozen|* **Status:** 🔷 Frozen" "$(in_scratch_repo acc4 t_set_status)"
t_done test_set_status_rewrites_the_header_line_only

t_set_status_refusals() {
  hdr p.md "🔷 Frozen"; cp p.md before.md
  local r=""
  plan_set_status p.md done 2>/dev/null && r="${r}w" || r="${r}r"
  printf '# Plan\n' > none.md
  plan_set_status none.md frozen 2>/dev/null && r="${r}w" || r="${r}r"
  cmp -s p.md before.md && r="${r}=" || r="${r}!"
  echo "$r"
}
t_expect "refusals" "rr=" "$(in_scratch_repo acc5 t_set_status_refusals)"
t_done test_set_status_refuses_unknown_slug_or_missing_line

t_adopter_status() {
  git config aapp.planState.in-development "🚧|Under Construction|🚧 Building|30"
  git config aapp.planState.awaiting-review "$CUSTOM"
  plan_states_load
  hdr p.md "📝 Refining"
  plan_set_status p.md in-development
  local a
  a="$(plan_status_text p.md):$(plan_status_slug p.md)"
  plan_set_status p.md awaiting-review
  echo "$a|$(plan_status_render awaiting-review):$(plan_status_slug p.md)"
}
t_expect "adopter statuses" "🚧 Under Construction:in-development|👀 Awaiting Review:awaiting-review" "$(in_scratch_repo acc6 t_adopter_status)"
t_done test_accessors_follow_adopter_statuses

print_test_summary "$PASS" "$FAIL"
