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

# Compute Overview Metrics
ISSUES_FILE=""
if [ -f ".plans/ISSUES.md" ]; then
    ISSUES_FILE=".plans/ISSUES.md"
elif [ -f "ISSUES.md" ]; then
    ISSUES_FILE="ISSUES.md"
fi
TOTAL_ISSUES=0
if [ -n "$ISSUES_FILE" ]; then
    TOTAL_ISSUES=$(grep -E '^[[:space:]]*\|[[:space:]]*`?#[0-9]+' "$ISSUES_FILE" 2>/dev/null | wc -l | tr -d ' ')
fi

ROADMAP_FILE=""
if [ -f ".plans/issues_road_map.md" ]; then
    ROADMAP_FILE=".plans/issues_road_map.md"
elif [ -f "issues_road_map.md" ]; then
    ROADMAP_FILE="issues_road_map.md"
fi
TOP_ROADMAP_ISSUES=""
if [ -n "$ROADMAP_FILE" ]; then
    TOP_ROADMAP_ISSUES=$(grep -E '^[[:space:]]*([0-9]+\.|-[[:space:]]*\[[ ]?\]|\*)[[:space:]]*`?#?[0-9]+' "$ROADMAP_FILE" 2>/dev/null | grep -v '\[Feature or Problem Title\]' | grep -v -E '✅|[Rr]esolved|DONE' | grep -o -E '#[0-9]+' | head -n 3 | tr '\n' ',' | sed 's/,$//; s/,/, /g')
fi

TOTAL_PLANS=0
if [ -d ".plans/current" ]; then
    TOTAL_PLANS=$(find .plans/current -maxdepth 1 -name "*.md" ! -name "000-*" 2>/dev/null | wc -l | tr -d ' ')
fi

# Re-derive the matrix before anything reads it, so the briefing reports the
# real board rather than a stale cache (P-30 §2.10). While paused this still
# writes: the uncommittable diff is the visible record of what reflection
# changed, and the advisory below says the commit waits for 'aapp resume'.
MATRIX_SYNCED=0
MATRIX_PAUSED_DEFER=0
if [ -n "${AAPP_LIB:-}" ] && [ -f "$AAPP_LIB/cmd_matrix.sh" ] && [ -d ".plans/current" ]; then
    MATRIX_OUT="$(
        AAPP_MATRIX_LIB_ONLY=1
        export AAPP_MATRIX_LIB_ONLY
        # shellcheck source=/dev/null
        . "$AAPP_LIB/cmd_matrix.sh" 2>/dev/null || exit 0
        cmd_matrix 2>/dev/null || true
    )"
    case "$MATRIX_OUT" in
        *"Re-derived"*) MATRIX_SYNCED=1 ;;
    esac
    case "$MATRIX_OUT" in
        *"PAUSED"*) MATRIX_PAUSED_DEFER=1 ;;
    esac
fi

STATE_MATRIX=""
if [ -f ".plans/state_matrix.md" ]; then
    STATE_MATRIX=".plans/state_matrix.md"
elif [ -f "state_matrix.md" ]; then
    STATE_MATRIX="state_matrix.md"
fi
ROADMAP_PLANS=""
if [ -n "$STATE_MATRIX" ]; then
    ROADMAP_PLANS=$(awk '/## 🚦 Recommended Implementation Roadmap/ {flag=1; next} /^## / {flag=0} flag' "$STATE_MATRIX" 2>/dev/null | grep -o -E 'P-[0-9]+' | head -n 3 | tr '\n' ',' | sed 's/,$//; s/,/, /g')
fi
[ -z "$ROADMAP_PLANS" ] && ROADMAP_PLANS="none"

PICKUP_COUNT=0
if [ -f ".plans/pickup.md" ]; then
    PICKUP_COUNT=$(grep -E '^[0-9]+\.|^[\*-] ' ".plans/pickup.md" 2>/dev/null | grep -v '\[Feature or Problem Title\]' | grep -v -E '\[x\]|\[X\]' | wc -l | tr -d ' ')
fi

OVERVIEW_LINE="📊 Overview: $TOTAL_ISSUES issues (Next: ${TOP_ROADMAP_ISSUES:-none}) | $TOTAL_PLANS plans (Roadmap: $ROADMAP_PLANS) | $PICKUP_COUNT pickup"

if [ "$1" = "short" ] || [ "$1" = "summary" ]; then
    echo "$OVERVIEW_LINE"
    return 0 2>/dev/null || exit 0
fi

echo "============================================================"
echo "  🧭 AAPP Context Recovery Briefing"
echo "  📍 Repo: $REPO_ROOT"
echo "  $OVERVIEW_LINE"
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
            formatted_date = dt.strftime("%Y-%m-%d %H:%M:%S")
            time_info = f"{formatted_date} ({rel})"
        except Exception:
            time_info = ts_str

    stashes = d.get("snapshot", {}).get("stashes", [])
    stashes_count = len(stashes)
    stash_names = []
    for s in stashes:
        wt = s.get("worktree", "")
        name = os.path.basename(wt)
        branch = s.get("branch")
        if branch:
            name = f"{name} ({branch})"
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

    # Report what the pre-read sync did (P-30 §2.10). Silent when the matrix was
    # already in sync, so a correct board adds no noise to the briefing.
    if [ "$MATRIX_SYNCED" -eq 1 ]; then
        if [ "$MATRIX_PAUSED_DEFER" -eq 1 ]; then
            echo "  🔄 [Matrix] state_matrix.md re-derived from .plans/current/ (uncommittable until 'aapp resume')"
        else
            echo "  🔄 [Matrix] state_matrix.md re-derived from .plans/current/ (review and commit the diff)"
        fi
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
# Evaluate Next Action Dynamically
WORKTREES_SYNCED=0
if [ -d ".plans" ] && [ -d ".agents" ] && [ -d ".githooks" ]; then
    WORKTREES_SYNCED=1
fi

ACTIVE_PLAN_BUFFER="$(git rev-parse --git-path aapp_active_plan 2>/dev/null || true)"
ACTIVE_PLAN_ID=""
if [ -f "$ACTIVE_PLAN_BUFFER" ]; then
    ACTIVE_PLAN_ID="$(cat "$ACTIVE_PLAN_BUFFER" 2>/dev/null | tr -d '[:space:]' || true)"
fi

# Resolved from each plan's own Status line via the status registry (P-30
# §2.6), not by matching matrix headings. Headings are generated and vary by
# adopter, so anchoring on them silently returned nothing when they changed.
FROZEN_PLAN=""
INCUBATOR_PLAN=""
if [ -n "${AAPP_LIB:-}" ] && [ -f "$AAPP_LIB/plan_states.sh" ] && [ -d ".plans/current" ]; then
    PLAN_LANE="$(
        # shellcheck source=/dev/null
        . "$AAPP_LIB/plan_states.sh" 2>/dev/null || exit 0
        plan_states_load 2>/dev/null || exit 0
        INCUBATOR_HEADING="$(plan_state_field under-review heading 2>/dev/null || true)"
        for PF in .plans/current/*.md; do
            [ -f "$PF" ] || continue
            case "$(basename "$PF")" in 000-*|plan-template.md) continue ;; esac
            PID="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$PF" 2>/dev/null | head -n 1)"
            [ -z "$PID" ] && continue
            SLINE="$(grep -E '^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*' "$PF" 2>/dev/null | head -n 1)"
            SLUG="$(plan_state_for_status_line "$SLINE" 2>/dev/null || true)"
            [ -z "$SLUG" ] && continue
            if [ "$SLUG" = "frozen" ]; then
                echo "frozen $PID"
            elif [ -n "$INCUBATOR_HEADING" ] && \
                 [ "$(plan_state_field "$SLUG" heading 2>/dev/null || true)" = "$INCUBATOR_HEADING" ]; then
                echo "incubator $PID"
            fi
        done
    )"
    FROZEN_PLAN="$(echo "$PLAN_LANE" | awk '$1=="frozen"{print $2; exit}')"
    INCUBATOR_PLAN="$(echo "$PLAN_LANE" | awk '$1=="incubator"{print $2; exit}')"
fi

FIRST_ISSUE=""
if [ -n "$TOP_ROADMAP_ISSUES" ] && [ "$TOP_ROADMAP_ISSUES" != "none" ]; then
    FIRST_ISSUE="$(echo "$TOP_ROADMAP_ISSUES" | cut -d',' -f1 | tr -d '[:space:]')"
fi

if [ -f "$PAUSED_FILE" ] || { [ -n "$SHARED_PAUSED_FILE" ] && [ -f "$SHARED_PAUSED_FILE" ]; }; then
    echo "➡️  Next Action: Project is PAUSED. Run 'aapp resume' to wake, or refine notes in .plans/ (pickup, issues, current)."
elif [ "$WORKTREES_SYNCED" -ne 1 ]; then
    echo "➡️  Next Action: Run 'aapp init' to complete AAPP worktree setup."
elif [ "$PICKUP_COUNT" -gt 0 ]; then
    echo "➡️  Next Action: Run '/aapp-digest <idea>' (or 'aapp digest <idea>') to work a queued pickup idea."
elif [ -n "$ACTIVE_PLAN_ID" ]; then
    echo "➡️  Next Action: In development on $ACTIVE_PLAN_ID. Run 'aapp active' to inspect boundaries."
elif [ -n "$FROZEN_PLAN" ]; then
    echo "➡️  Next Action: Activate frozen plan $FROZEN_PLAN: run '/aapp-start $FROZEN_PLAN' (or 'aapp start $FROZEN_PLAN')."
elif [ -n "$FIRST_ISSUE" ]; then
    echo "➡️  Next Action: Promote or resolve next open issue $FIRST_ISSUE, or inspect .plans/issues_road_map.md."
elif [ -n "$INCUBATOR_PLAN" ]; then
    echo "➡️  Next Action: Review incubator plan $INCUBATOR_PLAN, or run '/aapp-freeze $INCUBATOR_PLAN' when ready."
else
    echo "➡️  Next Action: Run '/aapp-plan' to draft a new blueprint, or 'aapp help' to browse available commands."
fi
