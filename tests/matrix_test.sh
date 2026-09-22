#!/usr/bin/env bash
# ==============================================================================
# Automated Regression Test Suite: Derived State Matrix (Plan P-30)
# Covers:
#   - Full derivation from .plans/current/ into registry-ordered sections
#   - Orphan row deletion (a row with no backing plan file simply vanishes)
#   - Annotation preservation, including across a section change
#   - Annotation em-dash integrity (split on the FIRST " — " only)
#   - Roadmap block preserved verbatim (human-owned priority ordering)
#   - Unrecognized status bucketing, including retired 🔴/🟡 glyphs
#   - --check exit codes (0 clean, 1 drifted) and read-only guarantee
#   - Pause advisory: still writes, reports deferred commit, silent on no-op
#   - Idempotency: sync -> sync produces a byte-identical file
# ==============================================================================
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT

report() {
  local name="$1" expect="$2" got="$3" details="${4:-}"
  if [ "$got" = "$expect" ]; then
    printf "  \033[32m✔\033[0m %-65s %s\n" "$name" "$got"; PASS=$((PASS+1))
  else
    printf "  \033[31m✘\033[0m %-65s want %s got %s\n" "$name" "$expect" "$got"; FAIL=$((FAIL+1))
    [ -n "$details" ] && echo "$details" | sed 's/^/       /'
  fi
}

# A minimal repo carrying only what the engine reads: .plans/current/ plus the
# two lib modules. Avoids depending on a full kit install.
make_fixture() {
  local dir="$R/$1"
  mkdir -p "$dir/.plans/current" "$dir/lib"
  cp "$KIT/lib/plan_states.sh" "$KIT/lib/cmd_matrix.sh" "$dir/lib/"
  (
    cd "$dir" || exit 1
    git init -q .
    git config user.email test@example.invalid
    git config user.name "Matrix Test"
  )
  echo "$dir"
}

make_plan() {
  local dir="$1" id="$2" slug="$3" status="$4" title="$5"
  cat > "$dir/.plans/current/P${id}-${slug}.md" <<EOF
# 🗺️ Plan P-${id}: ${title}
* **Plan ID:** P-${id}
* **Status:** ${status}

## 1. Context
Fixture plan.
EOF
}

run_matrix() {
  local dir="$1"; shift
  ( cd "$dir" && AAPP_LIB="$dir/lib" bash lib/cmd_matrix.sh "$@" 2>&1 )
}

run_matrix_rc() {
  local dir="$1"; shift
  ( cd "$dir" && AAPP_LIB="$dir/lib" bash lib/cmd_matrix.sh "$@" >/dev/null 2>&1 )
  echo $?
}

echo ""
echo "🧪 Derived State Matrix (P-30)"
echo "────────────────────────────────────────────────────────────────────────────"

# --- 1. Syntax ---------------------------------------------------------------
bash -n "$KIT/lib/cmd_matrix.sh" 2>/dev/null && got=ok || got=fail
report "lib/cmd_matrix.sh parses cleanly" "ok" "$got"

# --- 2. Full derivation into registry-ordered sections -----------------------
D="$(make_fixture derive)"
make_plan "$D" 1 alpha "🟣 Under Review" "Alpha Capability"
make_plan "$D" 2 beta  "🔷 Frozen"       "Beta Capability"
make_plan "$D" 3 gamma "⚡ In Development" "Gamma Capability"
run_matrix "$D" >/dev/null

got="$(grep -c '^## ' "$D/.plans/state_matrix.md" | tr -d ' ')"
report "emits Roadmap + 4 registry sections + ledger" "6" "$got"

got="$(grep -n '^## ' "$D/.plans/state_matrix.md" | sed -n '3p' | grep -c 'Greenlight' | tr -d ' ')"
report "sections appear in registry rank order" "1" "$got"

got="$(grep -c '🟣 \*\*P-1\*\*' "$D/.plans/state_matrix.md" | tr -d ' ')"
report "plan row carries the status emoji from its Status line" "1" "$got"

# A plan's row must sit under the section its status maps to.
got="$(awk '/Greenlight/{f=1;next} /^## /{f=0} f && /\*\*P-2\*\*/{print "yes";exit}' "$D/.plans/state_matrix.md")"
report "frozen plan lands under the Greenlight section" "yes" "$got"

# --- 3. Idempotency ----------------------------------------------------------
cp "$D/.plans/state_matrix.md" "$R/idem_a"
run_matrix "$D" >/dev/null
cp "$D/.plans/state_matrix.md" "$R/idem_b"
diff -q "$R/idem_a" "$R/idem_b" >/dev/null 2>&1 && got=identical || got=drifted
report "repeated sync produces a byte-identical file" "identical" "$got"

got="$(run_matrix "$D" | grep -c 'in sync' | tr -d ' ')"
report "second sync reports already in sync" "1" "$got"

got="$(printf '%s' "$(tail -c 1 "$D/.plans/state_matrix.md")" | wc -c | tr -d ' ')"
report "file ends with a trailing newline" "0" "$got"

# --- 4. --check exit codes and read-only guarantee ---------------------------
got="$(run_matrix_rc "$D" --check)"
report "--check exits 0 when in sync" "0" "$got"

sed -i 's/^- 🔷 \*\*P-2\*\*/- 🟣 **P-2**/' "$D/.plans/state_matrix.md"
cp "$D/.plans/state_matrix.md" "$R/check_before"
got="$(run_matrix_rc "$D" --check)"
report "--check exits 1 when drifted" "1" "$got"

diff -q "$R/check_before" "$D/.plans/state_matrix.md" >/dev/null 2>&1 && got=unchanged || got=written
report "--check never writes the matrix" "unchanged" "$got"

run_matrix "$D" >/dev/null   # restore

# --- 5. Orphan row deletion --------------------------------------------------
D2="$(make_fixture orphan)"
make_plan "$D2" 10 keep "🟣 Under Review" "Kept Plan"
make_plan "$D2" 11 drop "🟣 Under Review" "Dropped Plan"
run_matrix "$D2" >/dev/null
got="$(grep -cE '^\- .+\*\*P-11\*\*' "$D2/.plans/state_matrix.md" | tr -d ' ')"
report "row present while its plan file exists" "1" "$got"

rm "$D2/.plans/current/P11-drop.md"
run_matrix "$D2" >/dev/null
got="$(grep -cE '^\- .+\*\*P-11\*\*' "$D2/.plans/state_matrix.md" | tr -d ' ')"
report "orphan row is deleted once the plan leaves current/" "0" "$got"

got="$(grep -cE '^\- .+\*\*P-10\*\*' "$D2/.plans/state_matrix.md" | tr -d ' ')"
report "sibling rows survive an orphan deletion" "1" "$got"

# --- 6. Annotation preservation ----------------------------------------------
D3="$(make_fixture annot)"
make_plan "$D3" 20 noted "🟣 Under Review" "Original Title"
run_matrix "$D3" >/dev/null

# Replace the derived title with a human annotation containing em-dashes.
sed -i 's|— Original Title|— ✏️ **SKETCH — do not refine** — blocked on `#64`, `#57`|' \
  "$D3/.plans/state_matrix.md"
run_matrix "$D3" >/dev/null
got="$(grep -c 'SKETCH — do not refine' "$D3/.plans/state_matrix.md" | tr -d ' ')"
report "annotation survives a sync" "1" "$got"

got="$(grep -c 'blocked on `#64`, `#57`' "$D3/.plans/state_matrix.md" | tr -d ' ')"
report "annotation em-dashes survive (splits on first only)" "1" "$got"

# The same annotation must follow the plan when its status moves it elsewhere.
sed -i 's/^\* \*\*Status:\*\*.*/* **Status:** 🔷 Frozen/' "$D3/.plans/current/P20-noted.md"
run_matrix "$D3" >/dev/null
got="$(awk '/Greenlight/{f=1;next} /^## /{f=0} f && /SKETCH — do not refine/{print "yes";exit}' \
  "$D3/.plans/state_matrix.md")"
report "annotation follows its plan across a section change" "yes" "$got"

got="$(grep -c '🔷 \*\*P-20\*\*' "$D3/.plans/state_matrix.md" | tr -d ' ')"
report "row emoji updates to the new status" "1" "$got"

# --- 7. Roadmap preservation -------------------------------------------------
D4="$(make_fixture roadmap)"
make_plan "$D4" 30 road "🟣 Under Review" "Roadmapped Plan"
run_matrix "$D4" >/dev/null
sed -i 's|^\*No plans currently active on roadmap.*|1. **P-30** — ship this first\n2. **P-31** — then this|' \
  "$D4/.plans/state_matrix.md"
run_matrix "$D4" >/dev/null
got="$(grep -c 'ship this first' "$D4/.plans/state_matrix.md" | tr -d ' ')"
report "human Roadmap ordering is preserved verbatim" "1" "$got"

got="$(grep -c 'then this' "$D4/.plans/state_matrix.md" | tr -d ' ')"
report "multi-line Roadmap content survives" "1" "$got"

got="$(grep -c '^---$' "$D4/.plans/state_matrix.md" | tr -d ' ')"
report "no duplicated separators after Roadmap harvest" "6" "$got"

# --- 8. Unrecognized status bucketing ----------------------------------------
D5="$(make_fixture unknown)"
make_plan "$D5" 40 fine  "🟣 Under Review" "Recognized Plan"
make_plan "$D5" 41 stale "🔴 Ancient Retired Glyph" "Retired Glyph Plan"
make_plan "$D5" 42 typo  "🍀 Totally Made Up" "Typo Status Plan"
run_matrix "$D5" >/dev/null

got="$(grep -c 'Unrecognized Status' "$D5/.plans/state_matrix.md" | tr -d ' ')"
report "Unrecognized section appears when needed" "1" "$got"

got="$(awk '/Unrecognized Status/{f=1;next} /^## /{f=0} f && /^\- /{n++} END{print n+0}' \
  "$D5/.plans/state_matrix.md")"
report "both unrecognized plans are bucketed, not dropped" "2" "$got"

got="$(awk '/Unrecognized Status/{f=1;next} /^## /{f=0} f && /\*\*P-41\*\*/{print "yes";exit}' \
  "$D5/.plans/state_matrix.md")"
report "retired 🔴 glyph lands in Unrecognized (no legacy alias)" "yes" "$got"

got="$(grep -cE '^\- .+\*\*P-40\*\*' "$D5/.plans/state_matrix.md" | tr -d ' ')"
report "recognized plan is unaffected by unrecognized siblings" "1" "$got"

got="$(run_matrix "$D5" --check >/dev/null 2>&1; echo $?)"
report "a matrix with unrecognized rows still reports in sync" "0" "$got"

# Section is omitted entirely when every status resolves.
got="$(grep -c 'Unrecognized Status' "$D/.plans/state_matrix.md" | tr -d ' ')"
report "Unrecognized section omitted when all statuses resolve" "0" "$got"

# --- 9. Pause behaviour (§2.9) -----------------------------------------------
D6="$(make_fixture paused)"
make_plan "$D6" 50 pausey "🟣 Under Review" "Paused Repo Plan"
run_matrix "$D6" >/dev/null
touch "$D6/.git/aapp_paused"

sed -i 's/^\* \*\*Status:\*\*.*/* **Status:** 🔷 Frozen/' "$D6/.plans/current/P50-pausey.md"
OUT="$(run_matrix "$D6")"
got="$(echo "$OUT" | grep -c 'PAUSED' | tr -d ' ')"
report "paused sync emits the deferred-commit advisory" "1" "$got"

got="$(echo "$OUT" | grep -c 'aapp resume' | tr -d ' ')"
report "advisory names 'aapp resume' as the prerequisite" "1" "$got"

got="$(grep -c '🔷 \*\*P-50\*\*' "$D6/.plans/state_matrix.md" | tr -d ' ')"
report "paused sync still writes the matrix" "1" "$got"

got="$(run_matrix "$D6" | grep -c 'PAUSED' | tr -d ' ')"
report "no-op sync while paused stays silent" "0" "$got"

rm -f "$D6/.git/aapp_paused"
got="$(run_matrix "$D6" | grep -c 'PAUSED' | tr -d ' ')"
report "advisory disappears once resumed" "0" "$got"

# --- 10. Empty current/ ------------------------------------------------------
D7="$(make_fixture empty)"
run_matrix "$D7" >/dev/null
got="$(grep -c '^## ' "$D7/.plans/state_matrix.md" | tr -d ' ')"
report "empty current/ still renders a well-formed matrix" "6" "$got"

got="$(run_matrix_rc "$D7" --check)"
report "empty current/ is idempotent and in sync" "0" "$got"

print_test_summary "$PASS" "$FAIL"

