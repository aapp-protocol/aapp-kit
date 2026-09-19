#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `status`
#
# Context Recovery briefing across all 4 pillars:
# 1. Shipped   (CHANGELOG.md ## [Unreleased] / recent code)
# 2. Issues    (ISSUES.md and .plans/issues_road_map.md)
# 3. Plans     (.plans/state_matrix.md active plans)
# 4. Pickup    (.plans/pickup.md unprocessed ideas)
#
# Strictly read-only observer: never writes to disk or dirties working trees.
# ==============================================================================
set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
    echo "❌ Error: Not inside a git repository."
    exit 1
fi

cd "$REPO_ROOT"

# Source planning_health and plan_resolver engines if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/planning_health.sh" ]; then
    source "$SCRIPT_DIR/planning_health.sh"
elif [ -f "$REPO_ROOT/lib/planning_health.sh" ]; then
    source "$REPO_ROOT/lib/planning_health.sh"
fi
if [ -f "$SCRIPT_DIR/plan_resolver.sh" ]; then
    source "$SCRIPT_DIR/plan_resolver.sh"
elif [ -f "$REPO_ROOT/lib/plan_resolver.sh" ]; then
    source "$REPO_ROOT/lib/plan_resolver.sh"
fi

echo "============================================================"
echo "  🧭 AAPP Context Recovery Briefing"
echo "  📍 Repo: $REPO_ROOT"
echo "============================================================"

# 0. Master Emergency Brake / Pause Banner
GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null || echo ".git")"
if [ -d "$GIT_COMMON_DIR" ]; then
    PRIMARY_ROOT="$(cd "$GIT_COMMON_DIR/.." 2>/dev/null && pwd)"
else
    PRIMARY_ROOT="$REPO_ROOT"
fi

PAUSED_FILE="$GIT_COMMON_DIR/aapp_paused"
SHARED_PAUSED_FILE=""
if [ -d "$REPO_ROOT/.plans" ]; then
    SHARED_PAUSED_FILE="$REPO_ROOT/.plans/PAUSED.md"
elif [ -n "$PRIMARY_ROOT" ] && [ -d "$PRIMARY_ROOT/.plans" ]; then
    SHARED_PAUSED_FILE="$PRIMARY_ROOT/.plans/PAUSED.md"
fi

if [ -f "$PAUSED_FILE" ] || { [ -n "$SHARED_PAUSED_FILE" ] && [ -f "$SHARED_PAUSED_FILE" ]; }; then
    echo ""
    if [ -f "$PAUSED_FILE" ] && command -v python3 >/dev/null 2>&1; then
        python3 -c '
import json, sys, datetime, os

try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    reason = d.get("reason", "unspecified")
    ts_str = d.get("timestamp", "")
    time_info = ts_str
    if ts_str:
        try:
            clean_ts = ts_str.replace("Z", "+00:00")
            dt = datetime.datetime.fromisoformat(clean_ts)
            now = datetime.datetime.now(datetime.timezone.utc)
            diff = now - dt
            mins = int(diff.total_seconds() // 60)
            if mins < 1:
                rel = "just now"
            elif mins == 1:
                rel = "1 minute ago"
            elif mins < 60:
                rel = f"{mins} minutes ago"
            elif mins < 1440:
                rel = f"{mins // 60} hour(s) ago"
            else:
                rel = f"{mins // 1440} day(s) ago"
            time_info = f"{dt.strftime(\"%Y-%m-%d %H:%M:%S\")} ({rel})"
        except Exception:
            time_info = ts_str

    stashes = d.get("snapshot", {}).get("stashes", [])
    stashes_count = len(stashes)
    stash_names = []
    for s in stashes:
        wt = s.get("worktree", "")
        name = os.path.basename(wt)
        if s.get("branch"):
            name = f"{name} ({s.get(\"branch\")})"
        stash_names.append(name)

    print("🛑 PROJECT STATUS: PAUSED")
    print(f"   Reason : {reason}")
    print(f"   Paused : {time_info}")
    if stashes_count > 0:
        names_str = ", ".join(stash_names)
        print(f"   Stashes: {stashes_count} worktree(s) quarantined ({names_str})")
    else:
        print("   Stashes: 0 worktrees quarantined (clean on pause)")
    print("   Notice : All codebase modifications and commits are strictly refused.")
    print("   To resume: aapp resume")
except Exception as e:
    print("🛑 PROJECT STATUS: PAUSED")
    print(f"   (Failed to parse pause buffer: {e})")
' "$PAUSED_FILE"
    elif [ -n "$SHARED_PAUSED_FILE" ] && [ -f "$SHARED_PAUSED_FILE" ]; then
        echo "🛑 PROJECT STATUS: PAUSED"
        echo "   Scope  : Team-Wide (.plans/PAUSED.md)"
        grep -E '^\*[[:space:]]+\*\*(Reason|Timestamp|Initiator):\*\*' "$SHARED_PAUSED_FILE" | sed 's/^\*[[:space:]]*\*\*/   /; s/\*\*:[[:space:]]*/ : /' || true
        echo "   Notice : All codebase modifications and commits are strictly refused."
        echo "   To resume: aapp resume"
    else
        echo "🛑 PROJECT STATUS: PAUSED"
        echo "   Buffer : $PAUSED_FILE"
        echo "   Notice : All codebase modifications and commits are strictly refused."
        echo "   To resume: aapp resume"
    fi
fi

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
ROADMAP_FILE=""
if [ -f ".plans/issues_road_map.md" ]; then
    ROADMAP_FILE=".plans/issues_road_map.md"
elif [ -f "issues_road_map.md" ]; then
    ROADMAP_FILE="issues_road_map.md"
fi

if [ -n "$ROADMAP_FILE" ]; then
    ROADMAP_ACTIVE_REGEX='^[[:space:]]*([0-9]+\.|-[[:space:]]*\[[ ]?\]|\*)[[:space:]]*`?#?[0-9]+'
    TOP_ISSUES=$(grep -E "$ROADMAP_ACTIVE_REGEX" "$ROADMAP_FILE" 2>/dev/null | grep -v '\[Feature or Problem Title\]' | grep -v -E '✅|[Rr]esolved|DONE' | head -n 5 || true)
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
    # Active ISSUES.md holds only active rows
    OPEN_ISSUES=$(grep -E '^[[:space:]]*\|[[:space:]]*`?#?[0-9]+' "$ISSUES_FILE" 2>/dev/null | head -n 5 || true)
    if [ -n "$OPEN_ISSUES" ]; then
        echo "$OPEN_ISSUES" | sed 's/^/  /'
        HAS_ISSUES=1
    fi
fi

if [ "$HAS_ISSUES" -eq 0 ]; then
    echo "  (No open issues in issues_road_map.md or ISSUES.md)"
fi

# Non-destructive drift and unsequenced reporting
if [ -n "$ROADMAP_FILE" ] && [ -n "$ISSUES_FILE" ]; then
    if command -v check_pair2_referential_integrity >/dev/null 2>&1; then
        DRIFT_OUT=$(check_pair2_referential_integrity "$ROADMAP_FILE" "$ISSUES_FILE" 2>/dev/null || true)
        if [ -n "$DRIFT_OUT" ]; then
            echo "$DRIFT_OUT" | sed 's/^/  /'
        fi
    fi
    if command -v get_unsequenced_issues >/dev/null 2>&1; then
        UNSEQ=$(get_unsequenced_issues "$ROADMAP_FILE" "$ISSUES_FILE" 2>/dev/null || true)
        if [ -n "$UNSEQ" ]; then
            echo "  ℹ️  [Unsequenced] Active issues ($UNSEQ) are not yet on the priority board."
        fi
    fi
fi

# 3. Plans
echo ""
echo "🗺️  [3/4] PLANS (State Matrix / Active Blueprints)"
if [ -d ".plans/current" ]; then
    HAS_PLANS=0
    while IFS= read -r -d '' P; do
        BASENAME="$(basename "$P")"
        STATUS="$(grep -m 1 -E '^[[:space:]]*[\*|-][[:space:]]*\*\*Status:\*\*' "$P" 2>/dev/null || echo "* **Status:** 🟣 Active")"
        STATUS_CLEAN="$(echo "$STATUS" | sed -E 's/^[[:space:]]*[\*|-][[:space:]]*\*\*Status:\*\*[[:space:]]*//')"
        PLAN_ID=""
        if command -v get_plan_id >/dev/null 2>&1; then
            PLAN_ID="$(get_plan_id "$P" 2>/dev/null || true)"
        fi
        if [ -n "$PLAN_ID" ]; then
            echo "  • $PLAN_ID: $BASENAME  ($STATUS_CLEAN)"
        else
            echo "  • $BASENAME  ($STATUS_CLEAN)"
        fi
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
echo "➡️  Next Action: Run 'aapp init' to sync worktrees, or use /aapp-digest <idea> in chat."
