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
if [ -f "CHANGELOG.md" ]; then
    UNRELEASED=$(awk '/## \[Unreleased\]/ {flag=1; next} /^## / {flag=0} flag' CHANGELOG.md | sed '/^[[:space:]]*$/d' | head -n 5)
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
if [ -f ".plans/issues_road_map.md" ]; then
    TOP_ISSUES=$(grep -E '^[0-9]+\.|^- \[' ".plans/issues_road_map.md" 2>/dev/null | head -n 5 || true)
    if [ -n "$TOP_ISSUES" ]; then
        echo "$TOP_ISSUES" | sed 's/^/  /'
    else
        echo "  (No open issues in .plans/issues_road_map.md)"
    fi
elif [ -f "ISSUES.md" ]; then
    OPEN_ISSUES=$(grep -E '^\| ISSUE-[0-9]+' ISSUES.md 2>/dev/null | grep -v 'DONE' | head -n 5 || true)
    if [ -n "$OPEN_ISSUES" ]; then
        echo "$OPEN_ISSUES" | sed 's/^/  /'
    else
        echo "  (No open issues in ISSUES.md)"
    fi
else
    echo "  (No ISSUES.md or issues_road_map.md found)"
fi

# 3. Plans
echo ""
echo "🗺️  [3/4] PLANS (State Matrix / Active Blueprints)"
if [ -d ".plans/current" ]; then
    CURRENT_PLANS="$(find .plans/current -maxdepth 1 -name "*.md" 2>/dev/null | sort || true)"
    if [ -n "$CURRENT_PLANS" ]; then
        for P in $CURRENT_PLANS; do
            BASENAME="$(basename "$P")"
            STATUS="$(grep -m 1 "^\* \*\*Status:\*\*" "$P" 2>/dev/null || echo "* **Status:** 🟡 Active")"
            STATUS_CLEAN="$(echo "$STATUS" | sed 's/^\* \*\*Status:\*\* //')"
            echo "  • $BASENAME  ($STATUS_CLEAN)"
        done
    else
        echo "  (No active plans in .plans/current/)"
    fi
else
    echo "  (.plans/ worktree not mounted. Run 'aapp init' to mount)"
fi

# 4. Pickup
echo ""
echo "💡 [4/4] PICKUP QUEUE (Unprocessed Ideas)"
if [ -f ".plans/pickup.md" ]; then
    IDEAS=$(grep -E '^[0-9]+\.|^- ' ".plans/pickup.md" 2>/dev/null || true)
    if [ -n "$IDEAS" ]; then
        COUNT=$(echo "$IDEAS" | wc -l)
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
