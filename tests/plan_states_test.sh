#!/usr/bin/env bash
# ==============================================================================
# Automated Regression Test Suite: Plan Status Registry (Plan P-30)
# Covers:
#   - Kit default status resolution by canonical name
#   - Status line shape tolerance (cmd_plan.sh:115 and :808 variants)
#   - Many-to-one status -> section mapping (Under Review + Refining share one)
#   - Section emission in rank order, deduplicated
#   - Adopter custom statuses via git config aapp.planState.<slug>
#   - Kit default override by slug, preserving registry order
#   - Malformed config tuples skipped with warning, never fatal
#   - Accessibility invariant §2.8: retired 🔴/🟡 glyphs carry no alias
#   - Idempotency of plan_states_load
# ==============================================================================
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

# Each scenario runs in its own repo so git config state cannot leak between
# tests. The registry is re-sourced per subshell.
in_scratch_repo() {
  local dir="$R/$1"; shift
  mkdir -p "$dir"
  (
    cd "$dir" || exit 1
    git init -q .
    git config user.email test@example.invalid
    git config user.name "Registry Test"
    # shellcheck source=/dev/null
    . "$KIT/lib/plan_states.sh"
    "$@"
  )
}

echo ""
echo "🧪 Plan Status Registry (P-30)"
echo "────────────────────────────────────────────────────────────────────────────"

# --- 1. Syntax ---------------------------------------------------------------
bash -n "$KIT/lib/plan_states.sh" 2>/dev/null && got=ok || got=fail
report "lib/plan_states.sh parses cleanly" "ok" "$got"

# --- 2. Default resolution by canonical name ---------------------------------
t_defaults() {
  plan_states_load
  local out=""
  out="$out$(plan_state_for_status_line '* **Status:** 🟣 Under Review'),"
  out="$out$(plan_state_for_status_line '* **Status:** 📝 Refining'),"
  out="$out$(plan_state_for_status_line '* **Status:** 🔷 Frozen'),"
  out="$out$(plan_state_for_status_line '* **Status:** ⚡ In Development'),"
  out="$out$(plan_state_for_status_line '* **Status:** 🟥 BLOCKED')"
  echo "$out"
}
got="$(in_scratch_repo defaults t_defaults)"
report "kit defaults resolve by canonical name" \
  "under-review,refining,frozen,in-development,blocked" "$got"

# --- 3. Status line shape tolerance ------------------------------------------
# Shapes drawn from cmd_plan.sh:115 (leading *|- with bold) and :808.
t_shapes() {
  plan_states_load
  local n=0
  plan_state_for_status_line '* **Status:** ⚡ In Development' >/dev/null && n=$((n+1))
  plan_state_for_status_line '- **Status:** ⚡ In Development' >/dev/null && n=$((n+1))
  plan_state_for_status_line '  *  **Status:**   ⚡   In Development  ' >/dev/null && n=$((n+1))
  plan_state_for_status_line '**Status:** ⚡ In Development (active)' >/dev/null && n=$((n+1))
  echo "$n"
}
got="$(in_scratch_repo shapes t_shapes)"
report "tolerates leading markers, spacing, trailing prose" "4" "$got"

# --- 4. Many-to-one status -> section ----------------------------------------
t_shared_section() {
  plan_states_load
  local a b
  a="$(plan_state_field under-review heading)"
  b="$(plan_state_field refining heading)"
  [ "$a" = "$b" ] && echo "shared" || echo "split"
}
got="$(in_scratch_repo shared t_shared_section)"
report "Under Review and Refining share one section" "shared" "$got"

# --- 5. Sections emit in rank order, deduplicated ----------------------------
t_section_order() {
  plan_states_load
  plan_state_sections | wc -l | tr -d ' '
}
got="$(in_scratch_repo order t_section_order)"
report "five statuses collapse to four unique sections" "4" "$got"

t_section_first() {
  plan_states_load
  plan_state_sections | head -1
}
got="$(in_scratch_repo order2 t_section_first)"
report "lowest rank emits first" "🧠 Human Thought & Refinement (The Incubator)" "$got"

# --- 6. Custom adopter status ------------------------------------------------
t_custom() {
  git config aapp.planState.awaiting-review "👀|Awaiting Review|👀 Awaiting External Review|25"
  plan_states_load
  plan_state_for_status_line '* **Status:** 👀 Awaiting Review'
}
got="$(in_scratch_repo custom t_custom)"
report "custom status resolves from git config" "awaiting-review" "$got"

t_custom_rank() {
  git config aapp.planState.awaiting-review "👀|Awaiting Review|👀 Awaiting External Review|25"
  plan_states_load
  plan_state_sections | sed -n '3p'
}
got="$(in_scratch_repo custom2 t_custom_rank)"
report "custom status sorts into position by rank" "👀 Awaiting External Review" "$got"

t_custom_emoji_class() {
  git config aapp.planState.awaiting-review "👀|Awaiting Review|👀 Awaiting External Review|25"
  plan_states_load
  plan_state_emoji_class
}
got="$(in_scratch_repo custom3 t_custom_emoji_class)"
report "custom glyph joins the emoji alternation" "🟣|📝|🔷|⚡|🟥|👀" "$got"

# --- 7. Kit default override -------------------------------------------------
t_override() {
  git config aapp.planState.frozen "🔷|Frozen|🔷 Greenlit|20"
  plan_states_load
  plan_state_field frozen heading
}
got="$(in_scratch_repo override t_override)"
report "config entry overrides a kit default by slug" "🔷 Greenlit" "$got"

t_override_order() {
  git config aapp.planState.frozen "🔷|Frozen|🔷 Greenlit|20"
  plan_states_load
  plan_state_sections | sed -n '2p'
}
got="$(in_scratch_repo override2 t_override_order)"
report "override preserves registry position" "🔷 Greenlit" "$got"

# --- 8. Malformed tuples skipped, never fatal --------------------------------
t_malformed_survives() {
  git config aapp.planState.bad1 "only|three|fields"
  git config aapp.planState.bad2 "🔵|Name|Heading|not-a-number"
  git config aapp.planState.bad3 "||Heading|5"
  plan_states_load 2>/dev/null
  plan_state_for_status_line '* **Status:** 🔷 Frozen'
}
got="$(in_scratch_repo malformed t_malformed_survives)"
report "malformed entries do not brick the registry" "frozen" "$got"

t_malformed_warns() {
  git config aapp.planState.bad1 "only|three|fields"
  plan_states_load 2>&1 >/dev/null | grep -c "Skipping" | tr -d ' '
}
got="$(in_scratch_repo malformed2 t_malformed_warns)"
report "malformed entry emits a warning to stderr" "1" "$got"

t_malformed_excluded() {
  git config aapp.planState.bad2 "🔵|Name|Heading|not-a-number"
  plan_states_load 2>/dev/null
  plan_state_emoji_class | grep -c "🔵" | tr -d ' '
}
got="$(in_scratch_repo malformed3 t_malformed_excluded)"
report "rejected entry is absent from the emoji class" "0" "$got"

# --- 9. Accessibility invariant §2.8: no retired glyph aliases ---------------
t_retired_unrecognized() {
  plan_states_load
  if plan_state_for_status_line '* **Status:** 🔴 Something Retired' >/dev/null 2>&1; then
    echo "matched"
  else
    echo "unrecognized"
  fi
}
got="$(in_scratch_repo retired t_retired_unrecognized)"
report "retired 🔴 glyph resolves as unrecognized" "unrecognized" "$got"

t_no_retired_in_class() {
  plan_states_load
  plan_state_emoji_class | grep -cE '🔴|🟡' | tr -d ' '
}
got="$(in_scratch_repo retired2 t_no_retired_in_class)"
report "emoji class carries no retired 🔴/🟡 glyphs" "0" "$got"

# --- 10. Idempotency ---------------------------------------------------------
t_idempotent() {
  plan_states_load
  local a b
  a="$(plan_state_sections)"
  plan_states_load; plan_states_load
  b="$(plan_state_sections)"
  [ "$a" = "$b" ] && echo "stable" || echo "drifted"
}
got="$(in_scratch_repo idem t_idempotent)"
report "repeated plan_states_load is idempotent" "stable" "$got"

t_idempotent_class() {
  git config aapp.planState.awaiting-review "👀|Awaiting Review|👀 Awaiting External Review|25"
  plan_states_load
  local a b
  a="$(plan_state_emoji_class)"
  plan_states_load
  b="$(plan_state_emoji_class)"
  [ "$a" = "$b" ] && echo "stable" || echo "drifted"
}
got="$(in_scratch_repo idem2 t_idempotent_class)"
report "emoji class stable across reloads with custom status" "stable" "$got"

# --- 11. Unknown status is not silently bucketed -----------------------------
t_unknown() {
  plan_states_load
  if plan_state_for_status_line '* **Status:** 🍀 Totally Made Up' >/dev/null 2>&1; then
    echo "matched"
  else
    echo "unrecognized"
  fi
}
got="$(in_scratch_repo unknown t_unknown)"
report "unknown status returns unrecognized, not a default" "unrecognized" "$got"

echo "────────────────────────────────────────────────────────────────────────────"
printf "  Passed: \033[32m%d\033[0m   Failed: \033[31m%d\033[0m\n" "$PASS" "$FAIL"
echo ""
[ "$FAIL" -eq 0 ] || exit 1
exit 0
