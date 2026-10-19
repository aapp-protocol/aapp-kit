#!/usr/bin/env bash
# Core suite for the derived state matrix (lib/cmd_matrix.sh, P-30): sections
# in registry order, orphan rows, annotations, the Roadmap, unrecognized
# statuses, the pause advisory and an empty current/. Idempotency and `check`
# are the verb's (tests/verbs/matrix.sh).
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT

# make_fixture <name>: a repository holding only what the engine reads.
make_fixture() {
  local dir="$R/$1"
  mkdir -p "$dir/.plans/current" "$dir/lib"
  cp "$KIT/lib/plan_states.sh" "$KIT/lib/cmd_matrix.sh" "$dir/lib/"
  git init -q "$dir"
  echo "$dir"
}
make_plan() {
  local dir="$1" id="$2" slug="$3" status="$4" title="$5"
  printf '# 🗺️ Plan P-%s: %s\n* **Plan ID:** P-%s\n* **Status:** %s\n\n## 1. Context\nFixture plan.\n' \
    "$id" "$title" "$id" "$status" > "$dir/.plans/current/P${id}-${slug}.md"
}
run_matrix() { local dir="$1"; shift; ( cd "$dir" && AAPP_LIB="$dir/lib" bash lib/cmd_matrix.sh "$@" 2>&1 ); }
run_matrix_rc() { run_matrix "$@" >/dev/null; echo $?; }
count() { grep -cE "$1" "$2" | tr -d ' '; }
# in_section <section> <pattern> <file>: yes when <pattern> is under <section>.
in_section() { awk -v s="$1" -v p="$2" '$0 ~ s {f=1; next} /^## /{f=0} f && $0 ~ p {print "yes"; exit}' "$3"; }

echo "== derivation =="
D="$(make_fixture derive)"; M="$D/.plans/state_matrix.md"
make_plan "$D" 1 alpha "🟣 Under Review" "Alpha Capability"
make_plan "$D" 2 beta  "🔷 Frozen"       "Beta Capability"
make_plan "$D" 3 gamma "⚡ In Development" "Gamma Capability"
run_matrix "$D" >/dev/null
t_expect "Roadmap, 4 sections, ledger" 6 "$(count '^## ' "$M")"
t_expect "third heading is the Greenlight Zone" 1 "$(grep -n '^## ' "$M" | sed -n '3p' | grep -c Greenlight)"
t_expect "row glyph" 1 "$(count '🟣 \*\*P-1\*\*' "$M")"
t_expect "frozen plan under Greenlight" yes "$(in_section Greenlight '\*\*P-2\*\*' "$M")"
t_expect "trailing newline" 0 "$(printf '%s' "$(tail -c 1 "$M")" | wc -c | tr -d ' ')"
t_expect "no Unrecognized section" 0 "$(count 'Unrecognized Status' "$M")"
t_done test_derives_sections_in_rank_order

echo "== orphan rows =="
D="$(make_fixture orphan)"; M="$D/.plans/state_matrix.md"
make_plan "$D" 10 keep "🟣 Under Review" "Kept Plan"
make_plan "$D" 11 drop "🟣 Under Review" "Dropped Plan"
run_matrix "$D" >/dev/null
t_expect "row while the plan exists" 1 "$(count '^- .+\*\*P-11\*\*' "$M")"
rm "$D/.plans/current/P11-drop.md"
run_matrix "$D" >/dev/null
t_expect "row after the plan left" 0 "$(count '^- .+\*\*P-11\*\*' "$M")"
t_expect "sibling row" 1 "$(count '^- .+\*\*P-10\*\*' "$M")"
t_done test_orphan_rows_removed

echo "== annotations =="
D="$(make_fixture annot)"; M="$D/.plans/state_matrix.md"
make_plan "$D" 20 noted "🟣 Under Review" "Original Title"
run_matrix "$D" >/dev/null
sed -i 's|— Original Title|— ✏️ **SKETCH — do not refine** — blocked on `#64`, `#57`|' "$M"
run_matrix "$D" >/dev/null
t_expect "annotation kept" 1 "$(count 'SKETCH — do not refine' "$M")"
t_expect "em-dashes kept" 1 "$(count 'blocked on `#64`, `#57`' "$M")"
sed -i 's/^\* \*\*Status:\*\*.*/* **Status:** 🔷 Frozen/' "$D/.plans/current/P20-noted.md"
run_matrix "$D" >/dev/null
t_expect "annotation follows the plan" yes "$(in_section Greenlight 'SKETCH — do not refine' "$M")"
t_expect "row glyph follows the status" 1 "$(count '🔷 \*\*P-20\*\*' "$M")"
t_done test_annotation_preserved

echo "== Roadmap =="
D="$(make_fixture roadmap)"; M="$D/.plans/state_matrix.md"
make_plan "$D" 30 road "🟣 Under Review" "Roadmapped Plan"
run_matrix "$D" >/dev/null
sed -i 's|^\*No plans currently active on roadmap.*|1. **P-30** — ship this first\n2. **P-31** — then this|' "$M"
run_matrix "$D" >/dev/null
t_expect "first line" 1 "$(count 'ship this first' "$M")"
t_expect "second line" 1 "$(count 'then this' "$M")"
t_expect "separators" 6 "$(count '^---$' "$M")"
t_done test_roadmap_preserved

echo "== unrecognized statuses =="
D="$(make_fixture unknown)"; M="$D/.plans/state_matrix.md"
make_plan "$D" 40 fine  "🟣 Under Review" "Recognized Plan"
make_plan "$D" 41 stale "🔴 Ancient Retired Glyph" "Retired Glyph Plan"
make_plan "$D" 42 typo  "🍀 Totally Made Up" "Typo Status Plan"
run_matrix "$D" >/dev/null
t_expect "Unrecognized section" 1 "$(count 'Unrecognized Status' "$M")"
t_expect "rows bucketed" 2 "$(awk '/Unrecognized Status/{f=1;next} /^## /{f=0} f && /^- /{n++} END{print n+0}' "$M")"
t_expect "retired glyph bucketed" yes "$(in_section 'Unrecognized Status' '\*\*P-41\*\*' "$M")"
t_expect "recognized row" 1 "$(count '^- .+\*\*P-40\*\*' "$M")"
t_expect "check rc" 0 "$(run_matrix_rc "$D" check)"
t_done test_unrecognized_statuses_bucketed

echo "== pause advisory =="
D="$(make_fixture paused)"; M="$D/.plans/state_matrix.md"
make_plan "$D" 50 pausey "🟣 Under Review" "Paused Repo Plan"
run_matrix "$D" >/dev/null
touch "$D/.git/aapp_paused"
sed -i 's/^\* \*\*Status:\*\*.*/* **Status:** 🔷 Frozen/' "$D/.plans/current/P50-pausey.md"
out="$(run_matrix "$D")"
printf '%s\n' "$out" | grep -q PAUSED || t_fail "no advisory: $out"
printf '%s\n' "$out" | grep -q 'aapp resume' || t_fail "advisory names no 'aapp resume'"
t_expect "matrix written while paused" 1 "$(count '🔷 \*\*P-50\*\*' "$M")"
t_expect "no-op while paused" 0 "$(run_matrix "$D" | grep -c PAUSED)"
rm -f "$D/.git/aapp_paused"
t_expect "after resume" 0 "$(run_matrix "$D" | grep -c PAUSED)"
t_done test_paused_sync_advisory

echo "== empty current/ =="
D="$(make_fixture empty)"
run_matrix "$D" >/dev/null
t_expect "headings" 6 "$(count '^## ' "$D/.plans/state_matrix.md")"
t_expect "check rc" 0 "$(run_matrix_rc "$D" check)"
t_done test_empty_current_renders

print_test_summary "$PASS" "$FAIL"
