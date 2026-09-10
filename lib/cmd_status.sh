#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `status`
#
# Context Recovery briefing across all 4 pillars:
# 1. Shipped   (CHANGELOG.md ## [Unreleased] / recent code)
# 2. Issues    (ISSUES.md and .plans/issues_road_map.md)
# 3. Plans     (.plans/state_matrix.md active plans)
# 4. Pickup    (.plans/pickup.md unprocessed ideas)
# ==============================================================================
set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
    echo "❌ Error: Not inside a git repository."
    exit 1
fi

cd "$REPO_ROOT"

echo "============================================================"
echo "  🧭 AAPP Context Recovery Briefing"
echo "  📍 Repo: $REPO_ROOT"
echo "============================================================"

# 1. Shipped
echo ""
echo "📦 [1/4] SHIPPED (Recently Landed / Unreleased)"
CHANGELOG_PATH=""
if [ -f "CHANGELOG.md" ]; then
    CHANGELOG_PATH="CHANGELOG.md"
elif [ -f ".plans/CHANGELOG.md" ]; then
    CHANGELOG_PATH=".plans/CHANGELOG.md"
fi

if [ -n "$CHANGELOG_PATH" ]; then
    UNRELEASED=$(awk '/## \[Unreleased\]/ {flag=1; next} /^## / {flag=0} flag' "$CHANGELOG_PATH" | sed '/^[[:space:]]*$/d' | head -n 5)
    if [ -z "$UNRELEASED" ]; then
        # Fallback: display entries under the first header section
        UNRELEASED=$(awk '/^## / {if (count++) exit} count {print}' "$CHANGELOG_PATH" | sed '/^[[:space:]]*$/d' | head -n 5)
    fi
    if [ -n "$UNRELEASED" ]; then
        echo "$UNRELEASED" | sed 's/^/  /'
    else
        echo "  (No unreleased changelog entries yet)"
    fi
else
    echo "  (CHANGELOG.md not found)"
fi

# 2. Issues
echo ""
echo "🐛 [2/4] ISSUES (Canonical Bugs & Road Map)"
HAS_ISSUES=0
if [ -f ".plans/issues_road_map.md" ]; then
    TOP_ISSUES=$(grep -E '^[0-9]+\.|^- \[' ".plans/issues_road_map.md" 2>/dev/null | grep -v '\[Feature or Problem Title\]' | grep -v -E '✅|Resolved|DONE|\[x\]|\[X\]' | head -n 5 || true)
    if [ -n "$TOP_ISSUES" ]; then
        echo "$TOP_ISSUES" | sed 's/^/  /'
        HAS_ISSUES=1
    fi
fi

ISSUES_FILE=""
if [ -f ".plans/ISSUES.md" ]; then
    ISSUES_FILE=".plans/ISSUES.md"
elif [ -f "ISSUES.md" ]; then
    ISSUES_FILE="ISSUES.md"
fi

if [ -n "$ISSUES_FILE" ] && [ "$HAS_ISSUES" -eq 0 ]; then
    OPEN_ISSUES=$(grep -E '^\s*\|\s*(\*\*)?ISSUE-[0-9]+' "$ISSUES_FILE" 2>/dev/null | grep -v -E 'Resolved|DONE' | head -n 5 || true)
    if [ -n "$OPEN_ISSUES" ]; then
        echo "$OPEN_ISSUES" | sed 's/^/  /'
        HAS_ISSUES=1
    fi
fi

if [ "$HAS_ISSUES" -eq 0 ]; then
    echo "  (No open issues in issues_road_map.md or ISSUES.md)"
fi

# 3. Plans
echo ""
echo "🗺️  [3/4] PLANS (State Matrix / Active Blueprints)"
if [ -d ".plans/current" ]; then
    HAS_PLANS=0
    while IFS= read -r -d '' P; do
        BASENAME="$(basename "$P")"
        STATUS="$(grep -m 1 -E '^[[:space:]]*[\*|-][[:space:]]*\*\*Status:\*\*' "$P" 2>/dev/null || echo "* **Status:** 🟡 Active")"
        STATUS_CLEAN="$(echo "$STATUS" | sed -E 's/^[[:space:]]*[\*|-][[:space:]]*\*\*Status:\*\*[[:space:]]*//')"
        echo "  • $BASENAME  ($STATUS_CLEAN)"
        HAS_PLANS=1
    done < <(find .plans/current -maxdepth 1 -name "*.md" -print0 2>/dev/null | sort -z)
    
    if [ "$HAS_PLANS" -eq 0 ]; then
        echo "  (No active plans in .plans/current/)"
    fi
else
    echo "  (.plans/ worktree not mounted. Run 'aapp init' to mount)"
fi

# 4. Pickup
echo ""
echo "💡 [4/4] PICKUP QUEUE (Unprocessed Ideas)"
if [ -f ".plans/pickup.md" ]; then
    IDEAS=$(grep -E '^[0-9]+\.|^[\*-] ' ".plans/pickup.md" 2>/dev/null | grep -v '\[Feature or Problem Title\]' | grep -v -E '\[x\]|\[X\]' || true)
    if [ -n "$IDEAS" ]; then
        COUNT=$(echo "$IDEAS" | wc -l | tr -d ' ')
        echo "  ($COUNT unworked ideas found in pickup.md):"
        echo "$IDEAS" | head -n 5 | sed 's/^/  /'
        [ "$COUNT" -gt 5 ] && echo "  ... and $((COUNT - 5)) more"
    else
        echo "  Pickup: empty (All ideas digested!)"
    fi
else
    echo "  Pickup: empty (.plans/pickup.md not found)"
fi

echo ""
echo "============================================================"
echo "➡️  Next Action: Run 'aapp init' to sync worktrees, or use /digest <idea> in chat."
