#!/usr/bin/env bash
# ==============================================================================
# Automated Regression Test Suite: Delimited Template Sync & Document Governance
# Governed by Plan P-25 (Issue #73).
#
# Covers:
#   - Tier 1: Pure Reusable Template sync, checksum comparison, and .new buffer
#   - Tier 2: Hybrid document delimited block update preserving custom rules/ideas
#   - Tier 3: Pure project domain data isolation (never overwritten)
#   - Safety: Unclosed marker detection prevents data corruption
#   - Switchboard: aapp.templateSync modes (safe, strict, manual)
#   - Status: Fast template drift probe in 'aapp status'
# ==============================================================================
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KIT/tests/test_helpers.sh"
R=$(mktemp -d); PASS=0; FAIL=0
trap 'rm -rf "$R"' EXIT
confine_test_runtime "$R"

report() {
  local name="$1" expect="$2" got="$3" details="${4:-}"
  if [ "$got" = "$expect" ]; then
    printf "  \033[32m✔\033[0m %-65s %s\n" "$name" "$got"; PASS=$((PASS+1))
  else
    printf "  \033[31m✘\033[0m %-65s want %s got %s\n" "$name" "$expect" "$got"; FAIL=$((FAIL+1))
    [ -n "$details" ] && echo "$details" | sed 's/^/       /'
  fi
}

make_dummy_project() {
  local proj_dir="$1"
  mkdir -p "$proj_dir"
  (
    cd "$proj_dir"
    git init -q .
    setup_test_git_identity "$proj_dir"
    echo "# Starter" > README.md
    git add README.md
    git commit -qm "initial commit"
  )
}

echo "== 1. Tier 1 Template Synchronization & Conflict Resolution =="

# Test 1: Initial aapp init provisions Tier 1 templates
PROJ_1="$R/proj1"; make_dummy_project "$PROJ_1"
(cd "$PROJ_1" && aapp init >/dev/null 2>&1)
if [ -f "$PROJ_1/.plans/plan-template.md" ] && \
   [ -f "$PROJ_1/.plans/release/release_checklist.md" ] && \
   [ -f "$PROJ_1/.plans/done/000-archive-ledger.md" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "tier1_init: provisions plan-template, release_checklist, and archive ledger" "PASS" "$got"

# Test 2: Tier 1 delimited block update preserves bespoke template sections
PROJ_2="$R/proj2"; make_dummy_project "$PROJ_2"
(cd "$PROJ_2" && aapp init >/dev/null 2>&1)
# Add custom section outside delimited block in plan-template.md
cat >> "$PROJ_2/.plans/plan-template.md" <<'EOF'

## 7. Bespoke Project Architecture Matrix
* This custom section was authored by developer and must not be erased *
EOF
# Run aapp init again
(cd "$PROJ_2" && aapp init >/dev/null 2>&1)
if grep -q "Bespoke Project Architecture Matrix" "$PROJ_2/.plans/plan-template.md" && \
   grep -q "AAPP-PROTOCOL:START" "$PROJ_2/.plans/plan-template.md"; then
  got="PASS"
else
  got="FAIL"
fi
report "tier1_delimiters: in-place protocol block update preserves custom sections" "PASS" "$got"

# Test 3: Tier 1 undelimited divergence in safe mode writes .new buffer
PROJ_3="$R/proj3"; make_dummy_project "$PROJ_3"
(cd "$PROJ_3" && aapp init >/dev/null 2>&1)
# Replace plan-template.md with a heavily customized undelimited template
cat > "$PROJ_3/.plans/plan-template.md" <<'EOF'
# Legacy Plan Template
* Custom field without delimiter comments *
EOF
init_out_3=$(cd "$PROJ_3" && aapp init 2>&1)
if [ -f "$PROJ_3/.plans/plan-template.md.new" ] && \
   grep -q "Legacy Plan Template" "$PROJ_3/.plans/plan-template.md" && \
   echo "$init_out_3" | grep -q "wrote updated template to .plans/plan-template.md.new"; then
  got="PASS"
else
  got="FAIL"
fi
report "tier1_safe_drift: writes .new buffer without overwriting undelimited template" "PASS" "$got" "$init_out_3"

# Test 4: Tier 1 undelimited divergence in strict mode overwrites diverged template
PROJ_4="$R/proj4"; make_dummy_project "$PROJ_4"
(cd "$PROJ_4" && aapp init >/dev/null 2>&1)
cat > "$PROJ_4/.plans/plan-template.md" <<'EOF'
# Obsolete Plan Template
* Diverged content *
EOF
git -C "$PROJ_4" config aapp.templateSync "strict"
init_out_4=$(cd "$PROJ_4" && aapp init 2>&1)
if grep -q "<!-- AAPP-PROTOCOL:START" "$PROJ_4/.plans/plan-template.md" && \
   ! grep -q "Obsolete Plan Template" "$PROJ_4/.plans/plan-template.md" && \
   echo "$init_out_4" | grep -q "\[strict\] Overwrote diverged template"; then
  got="PASS"
else
  got="FAIL"
fi
report "tier1_strict_mode: overwrites diverged template when aapp.templateSync=strict" "PASS" "$got" "$init_out_4"

echo ""
echo "== 2. Tier 2 Hybrid Document Governance =="

# Test 5: pickup.md delimited block update preserves user ideas
PROJ_5="$R/proj5"; make_dummy_project "$PROJ_5"
(cd "$PROJ_5" && aapp init >/dev/null 2>&1)
cat >> "$PROJ_5/.plans/pickup.md" <<'EOF'
- [ ] Revolutionary idea: quantum blast radius validation
EOF
(cd "$PROJ_5" && aapp init >/dev/null 2>&1)
if grep -q "Revolutionary idea: quantum blast radius validation" "$PROJ_5/.plans/pickup.md" && \
   grep -q "<!-- AAPP-PROTOCOL:START" "$PROJ_5/.plans/pickup.md"; then
  got="PASS"
else
  got="FAIL"
fi
report "tier2_pickup: in-place delimiter sync preserves user backlog ideas" "PASS" "$got"

# Test 6: AGENTS.md delimited block update preserves bespoke rules
PROJ_6="$R/proj6"; make_dummy_project "$PROJ_6"
(cd "$PROJ_6" && aapp init >/dev/null 2>&1)
cat >> "$PROJ_6/.agents/AGENTS.md" <<'EOF'

## 🔒 Bespoke Security Guard
- Custom policy: Never run rm -rf in production scripts.
EOF
(cd "$PROJ_6" && aapp init >/dev/null 2>&1)
if grep -q "Bespoke Security Guard" "$PROJ_6/.agents/AGENTS.md" && \
   grep -q "<!-- AAPP-PROTOCOL:START" "$PROJ_6/.agents/AGENTS.md"; then
  got="PASS"
else
  got="FAIL"
fi
report "tier2_agents: in-place delimiter sync preserves custom project rules" "PASS" "$got"

# Test 7: Unclosed START delimiter aborts safely without corrupting file
PROJ_7="$R/proj7"; make_dummy_project "$PROJ_7"
(cd "$PROJ_7" && aapp init >/dev/null 2>&1)
cat > "$PROJ_7/.plans/pickup.md" <<'EOF'
<!-- AAPP-PROTOCOL:START v1.0.0 -->
Broken unclosed instruction block
- [ ] Precious unbacked idea that must survive
EOF
out_corrupt_7=$(cd "$PROJ_7" && aapp init 2>&1)
exit_corrupt_7=$?
if [ "$exit_corrupt_7" -eq 0 ] && \
   echo "$out_corrupt_7" | grep -q "Found unclosed <!-- AAPP-PROTOCOL:START --> marker" && \
   grep -q "Precious unbacked idea that must survive" "$PROJ_7/.plans/pickup.md"; then
  got="PASS"
else
  got="FAIL"
fi
report "tier2_unclosed_marker: fails safe and preserves file content" "PASS" "$got" "$out_corrupt_7"

# Test 7b: Inline delimiter mention in checklist does not false-trigger unclosed marker warning
PROJ_7B="$R/proj7b"; make_dummy_project "$PROJ_7B"
(cd "$PROJ_7B" && aapp init >/dev/null 2>&1)
cat >> "$PROJ_7B/.plans/release/release_checklist.md" <<'EOF'
- [ ] Checklist bullet mentioning `<!-- AAPP-PROTOCOL:START v1.0.0 -->` in prose
EOF
out_prose_7b=$(cd "$PROJ_7B" && aapp init 2>&1)
if ! echo "$out_prose_7b" | grep -q "Found unclosed <!-- AAPP-PROTOCOL:START --> marker" && \
   grep -q "Checklist bullet mentioning" "$PROJ_7B/.plans/release/release_checklist.md"; then
  got="PASS"
else
  got="FAIL"
fi
report "tier1_prose_marker: inline delimiter mention does not false-trigger unclosed warning" "PASS" "$got" "$out_prose_7b"

echo ""
echo "== 3. Tier 3 Pure Project Data Isolation =="

# Test 8: Live ledgers and CODEMAP/PROJECT.MD are never touched by init
PROJ_8="$R/proj8"; make_dummy_project "$PROJ_8"
(cd "$PROJ_8" && aapp init >/dev/null 2>&1)
echo "| #999 | P1 | CORE | 2026-09-21 | lib/a.sh | Active custom bug | Fix | 🟠 Incubated |" >> "$PROJ_8/.plans/ISSUES.md"
echo "# Project Specific Architecture Map" > "$PROJ_8/.agents/CODEMAP.md"
echo "# Project Specific Profile" > "$PROJ_8/.agents/PROJECT.MD"
(cd "$PROJ_8" && aapp init >/dev/null 2>&1)
if grep -q "#999" "$PROJ_8/.plans/ISSUES.md" && \
   grep -q "Project Specific Architecture Map" "$PROJ_8/.agents/CODEMAP.md" && \
   grep -q "Project Specific Profile" "$PROJ_8/.agents/PROJECT.MD"; then
  got="PASS"
else
  got="FAIL"
fi
report "tier3_isolation: ISSUES.md, CODEMAP.md, and PROJECT.MD are never overwritten" "PASS" "$got"

echo ""
echo "== 4. Template Sync Git Configuration Switchboard =="

# Test 9: manual mode leaves existing templates untouched without .new buffer
PROJ_9="$R/proj9"; make_dummy_project "$PROJ_9"
(cd "$PROJ_9" && aapp init >/dev/null 2>&1)
cat > "$PROJ_9/.plans/plan-template.md" <<'EOF'
# Manual Mode Custom Template
EOF
git -C "$PROJ_9" config aapp.templateSync "manual"
(cd "$PROJ_9" && aapp init >/dev/null 2>&1)
if grep -q "Manual Mode Custom Template" "$PROJ_9/.plans/plan-template.md" && \
   [ ! -f "$PROJ_9/.plans/plan-template.md.new" ]; then
  got="PASS"
else
  got="FAIL"
fi
report "switchboard_manual: manual mode preserves existing files without .new buffer" "PASS" "$got"

echo ""
echo "== 5. Status Briefing Template Drift Health Indicator =="

# Test 10: aapp status reports synced templates when up-to-date
PROJ_10="$R/proj10"; make_dummy_project "$PROJ_10"
(cd "$PROJ_10" && aapp init >/dev/null 2>&1)
status_out_10=$(cd "$PROJ_10" && aapp status 2>&1)
if echo "$status_out_10" | grep -q "📑 Templates:  All worktree templates synced"; then
  got="PASS"
else
  got="FAIL"
fi
report "status_synced: reports 'All worktree templates synced' when healthy" "PASS" "$got" "$status_out_10"

# Test 11: aapp status detects template drift and points to aapp init
PROJ_11="$R/proj11"; make_dummy_project "$PROJ_11"
(cd "$PROJ_11" && aapp init >/dev/null 2>&1)
# Intentionally replace with a template missing the protocol block
cat > "$PROJ_11/.plans/plan-template.md" <<'EOF'
# Stale Plan Template
<!-- Status must be exactly ONE of: Draft | In Progress -->
EOF
status_out_11=$(cd "$PROJ_11" && aapp status 2>&1)
if echo "$status_out_11" | grep -q "📑 Templates:  1 template drifted.*-> run 'aapp init'"; then
  got="PASS"
else
  got="FAIL"
fi
report "status_drift: reports drift advisory directing developer to 'aapp init'" "PASS" "$got" "$status_out_11"

echo ""
echo "============================================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================================"
[ "$FAIL" -eq 0 ] || exit 1
