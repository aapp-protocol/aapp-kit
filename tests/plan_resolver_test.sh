#!/usr/bin/env bash
# ==============================================================================
# Tests: Plan Shorthand Resolver Engine & Health Invariants (Pairs 4 & 5)
# ==============================================================================
set -e

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

source "$KIT/lib/plan_resolver.sh"
source "$KIT/lib/planning_health.sh"

TEST_DIR=$(mktemp -d /tmp/aapp-plan-resolver-test-XXXXXX)
trap 'rm -rf "$TEST_DIR"' EXIT

cd "$TEST_DIR"
git init -q
git branch -M main

mkdir -p .plans/current .plans/done

# Setup test fixtures
cat > .plans/current/P9-guard-path-authorization.md << 'EOF'
# 🗺️ Plan P-9: Guard Path Authorization
* **Plan ID:** P-9
* **Status:** 🔴 Under Review

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/guard.sh` -> Guard updates.
EOF

cat > .plans/current/P13-plan-ids-and-shorthand-resolution.md << 'EOF'
# 🗺️ Plan P-13: Plan IDs and Shorthand Resolution
* **Plan ID:** P-13
* **Status:** 🟢 Ready for Execution

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/plan_resolver.sh` -> Resolver engine.
EOF

cat > .plans/done/plan-feature-aapp-slash-commands.md << 'EOF'
# 🗺️ Plan: Universal Slash Commands
* **Plan ID:** P-7
* **Status:** 🟢 Completed
EOF

echo "== 1. Exact Path & Filename Resolution =="
RES=$(resolve_plan_path ".plans/current/P13-plan-ids-and-shorthand-resolution.md" "inspect" "current" "$PWD")
if [ "$RES" = ".plans/current/P13-plan-ids-and-shorthand-resolution.md" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "exact relative path resolves directly" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want exact path got '%s'\n" "exact relative path resolves directly" "$RES"; FAIL=$((FAIL+1))
fi

RES=$(resolve_plan_path "P13-plan-ids-and-shorthand-resolution.md" "inspect" "current" "$PWD")
if [ "$RES" = ".plans/current/P13-plan-ids-and-shorthand-resolution.md" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "bare filename in current/ resolves directly" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want path got '%s'\n" "bare filename in current/ resolves directly" "$RES"; FAIL=$((FAIL+1))
fi

echo "== 2. Numeric Plan ID Resolution (P-13, p-13, P13, 13) =="
for QUERY in "P-13" "p-13" "P13" "p13" "13" "P013" "P-013"; do
    RES=$(resolve_plan_path "$QUERY" "inspect" "current" "$PWD")
    if [ "$RES" = ".plans/current/P13-plan-ids-and-shorthand-resolution.md" ]; then
        printf "  \033[32m✔\033[0m %-52s %s\n" "query '$QUERY' resolves to P-13" "PASS"; PASS=$((PASS+1))
    else
        printf "  \033[31m✘\033[0m %-52s want P13 got '%s'\n" "query '$QUERY' resolves to P-13" "$RES"; FAIL=$((FAIL+1))
    fi
done

echo "== 3. Slug Substring Resolution =="
RES=$(resolve_plan_path "guard-path" "inspect" "current" "$PWD")
if [ "$RES" = ".plans/current/P9-guard-path-authorization.md" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "slug 'guard-path' resolves to P-9" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want P9 got '%s'\n" "slug 'guard-path' resolves to P-9" "$RES"; FAIL=$((FAIL+1))
fi

echo "== 4. Issue Namespace Collision Guard (#-prefixed rejection) =="
OUT=$(resolve_plan_path "#13" "freeze" "current" "$PWD" 2>&1 || true)
if echo "$OUT" | grep -q "is an Issue reference" && echo "$OUT" | grep -q "Did you mean 'P-13'"; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "#13 rejected with P-13 suggestion" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want rejection with suggestion got '%s'\n" "#13 rejected with P-13 suggestion" "$OUT"; FAIL=$((FAIL+1))
fi

echo "== 5. Empty Query Guard on State Transitions (freeze, done) =="
OUT_FREEZE=$(resolve_plan_path "" "freeze" "current" "$PWD" 2>&1 || true)
if echo "$OUT_FREEZE" | grep -q "You must explicitly specify a target plan for 'freeze'"; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "empty query on freeze refused" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want refusal got '%s'\n" "empty query on freeze refused" "$OUT_FREEZE"; FAIL=$((FAIL+1))
fi

OUT_DONE=$(resolve_plan_path "" "done" "current" "$PWD" 2>&1 || true)
if echo "$OUT_DONE" | grep -q "You must explicitly specify a target plan for 'done'"; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "empty query on done refused" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want refusal got '%s'\n" "empty query on done refused" "$OUT_DONE"; FAIL=$((FAIL+1))
fi

echo "== 6. Plan ID Helpers (get_plan_id, get_next_plan_id) =="
ID9=$(get_plan_id ".plans/current/P9-guard-path-authorization.md")
if [ "$ID9" = "P-9" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "get_plan_id extracts P-9" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want P-9 got '%s'\n" "get_plan_id extracts P-9" "$ID9"; FAIL=$((FAIL+1))
fi

NEXT_ID=$(get_next_plan_id "$PWD")
if [ "$NEXT_ID" = "P-14" ]; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "get_next_plan_id computes next ID (P-14)" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want P-14 got '%s'\n" "get_next_plan_id computes next ID (P-14)" "$NEXT_ID"; FAIL=$((FAIL+1))
fi

echo "== 7. Planning Health Pair 4: Plan ID Integrity =="
if check_pair4_plan_id_integrity "$PWD" >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "pair 4 passes on unique Plan IDs" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want PASS got FAIL\n" "pair 4 passes on unique Plan IDs"; FAIL=$((FAIL+1))
fi

# Duplicate Plan ID fixture
cat > .plans/current/P9-duplicate.md << 'EOF'
# 🗺️ Plan: Duplicate Test
* **Plan ID:** P-9
* **Status:** 🔴 Under Review
EOF

if ! check_pair4_plan_id_integrity "$PWD" >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "pair 4 catches duplicate Plan ID" "BLOCK"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want BLOCK got PASS\n" "pair 4 catches duplicate Plan ID"; FAIL=$((FAIL+1))
fi
rm -f .plans/current/P9-duplicate.md

echo "== 8. Planning Health Pair 5: Target Files vs Section 2 =="
if check_pair5_target_files_self_protection "$PWD" >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "pair 5 passes when target files are safe" "PASS"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want PASS got FAIL\n" "pair 5 passes when target files are safe"; FAIL=$((FAIL+1))
fi

# Violation fixture: blueprint declaring .agents/skills/aapp-freeze/SKILL.md as target
cat > .plans/current/P99-bad-target.md << 'EOF'
# 🗺️ Plan P-99: Bad Target Test
* **Plan ID:** P-99
* **Status:** 🔴 Under Review

### 📂 Target Files (Modifications & Additions)
- [ ] `.agents/skills/aapp-freeze/SKILL.md` -> Attempted direct skill edit.
EOF

if ! check_pair5_target_files_self_protection "$PWD" >/dev/null 2>&1; then
    printf "  \033[32m✔\033[0m %-52s %s\n" "pair 5 catches Section 2 violation in Target Files" "BLOCK"; PASS=$((PASS+1))
else
    printf "  \033[31m✘\033[0m %-52s want BLOCK got PASS\n" "pair 5 catches Section 2 violation in Target Files"; FAIL=$((FAIL+1))
fi
rm -f .plans/current/P99-bad-target.md

echo ""
echo "============================================================"
echo "  Plan Resolver & Health Tests: $PASS passed, $FAIL failed"
echo "============================================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
