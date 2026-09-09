#!/usr/bin/env bash
# ==============================================================================
# Asymmetric Agent Planning Protocol (AAPP) - Write-Time Blast Radius Guard
#
# Hook for Claude Code / Cursor / AI IDE PreToolUse write events:
# - Self-protection: Blocks AI from tampering with enforcement hooks and rules
# - Deterministic Blast Radius: Validates target file against .plans/current/*.md
# - Fail-open: Never bricks the agent on invalid JSON or when no active plans exist
# ==============================================================================
set -e

# Escape hatch
if [ "${SKIP_BLAST_RADIUS:-0}" = "1" ]; then
    exit 0
fi

# ------------------------------------------------------------------------------
# 1. Parse Input (CLI Argument or PreToolUse JSON payload on stdin)
# ------------------------------------------------------------------------------
TARGET_FILE=""
TOOL_NAME=""

if [ $# -ge 1 ]; then
    TARGET_FILE="$1"
elif [ ! -t 0 ]; then
    RAW_INPUT=$(cat)
    if [ -z "$RAW_INPUT" ]; then
        exit 0
    fi
    # Parse JSON payload via python3
    PARSED=$(python3 -c '
import json, sys
try:
    data = json.loads(sys.argv[1])
    tool = data.get("tool_name", "")
    inp = data.get("tool_input", {})
    path = inp.get("file_path") or inp.get("path") or inp.get("target_file") or ""
    print(f"{tool}\t{path}")
except Exception:
    sys.exit(0)
' "$RAW_INPUT" 2>/dev/null || true)
    
    if [ -z "$PARSED" ]; then
        exit 0
    fi
    TOOL_NAME=$(echo "$PARSED" | cut -f1)
    TARGET_FILE=$(echo "$PARSED" | cut -f2)
fi

if [ -z "$TARGET_FILE" ]; then
    exit 0
fi

# Normalize path relative to project root
TARGET_FILE="${TARGET_FILE#./}"

# ------------------------------------------------------------------------------
# 2. Self-Protection Invariants (ALWAYS PROTECTED - Hard Block)
# ------------------------------------------------------------------------------
case "$TARGET_FILE" in
    .claude/settings.json|.claude/settings.local.json|*/.claude/settings.json|*/.claude/settings.local.json)
        DENY_REASON="Tampering with Claude Code hook settings (.claude/settings.json) is strictly prohibited."
        ;;
    .githooks/*|*/.githooks/*|.git/hooks/*|*/.git/hooks/*)
        DENY_REASON="Tampering with AAPP git hooks engine is strictly prohibited."
        ;;
    .cursor/rules/*|*/.cursor/rules/*)
        DENY_REASON="Tampering with agent rule files (.cursor/rules/) is strictly prohibited."
        ;;
esac

if [ -n "${DENY_REASON:-}" ]; then
    if [ -n "$TOOL_NAME" ]; then
        python3 -c '
import json, sys
print(json.dumps({"decision": "deny", "reason": sys.argv[1]}))
' "$DENY_REASON"
    else
        echo "❌ [Blast Radius Guard Violation] $DENY_REASON" >&2
    fi
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. Always-Allowed Invariants (Plans, Rules, Root Anchors)
# ------------------------------------------------------------------------------
case "$TARGET_FILE" in
    .plans/*|.agents/*)
        exit 0
        ;;
    CHANGELOG.md|README.md|MANUAL.md|CODEMAP.md|ARCHITECTURE.md|ISSUES.md|.gitignore)
        exit 0
        ;;
    package.json|package-lock.json|composer.json|composer.lock|go.mod|go.sum|Cargo.toml|Cargo.lock|pyproject.toml|requirements.txt)
        exit 0
        ;;
esac

# ------------------------------------------------------------------------------
# 4. Blast Radius Validation Against Active Plans
# ------------------------------------------------------------------------------
ACTIVE_PLANS=$(ls -1 .plans/current/*.md 2>/dev/null || true)

if [ -z "$ACTIVE_PLANS" ]; then
    # Fail-open: if no active blueprints exist, allow edits to normal project files
    exit 0
fi

parse_plan_section() {
    local file="$1"
    local start_pattern="$2"
    local end_pattern="$3"
    
    awk -v start="$start_pattern" -v end="$end_pattern" '
        $0 ~ start { flag=1; next }
        $0 ~ end && flag { flag=0 }
        flag {
            line = $0
            sub(/^[[:space:]]*-[[:space:]]*\[[ xX]\][[:space:]]*/, "", line)
            sub(/^[[:space:]]*NEW FILE[[:space:]]*->[[:space:]]*/, "", line)
            if (match(line, /`[^`]+`/)) {
                item = substr(line, RSTART+1, RLENGTH-2)
                if (item !~ /^(NEW FILE|MODIFY|DELETE|ADD|REPLACE)$/) {
                    print item
                }
            }
        }
    ' "$file"
}

match_pattern_list() {
    local target="$1"
    shift
    local pattern
    for pattern in "$@"; do
        [ -z "$pattern" ] && continue
        if [ "$target" = "$pattern" ]; then
            return 0
        fi
        local dir_pattern="${pattern%/}/"
        if [[ "$target" == "$dir_pattern"* ]]; then
            return 0
        fi
        if [[ "$target" == $pattern ]]; then
            return 0
        fi
    done
    return 1
}

UNBLOCKED_PLANS=0
HAS_ANY_ACTIVE_TARGETS=0
ALLOWED_BY_A_PLAN=0
DENIED_BY_PLAN=""

while IFS= read -r PLAN; do
    [ -z "$PLAN" ] && continue
    
    # Check if plan is BLOCKED
    if grep -qE "(Status:.*🚫|🚫.*BLOCKED)" "$PLAN"; then
        continue
    fi
    UNBLOCKED_PLANS=$((UNBLOCKED_PLANS + 1))

    PLAN_TARGETS=()
    PLAN_OOB=()

    while IFS= read -r ITEM; do
        [ -n "$ITEM" ] && PLAN_TARGETS+=("$ITEM")
    done < <(parse_plan_section "$PLAN" '^### 📂 Target Files|^### 🚨 Emergency Hotfix' '^### 🛑 Out of Bounds|^## ')

    while IFS= read -r ITEM; do
        [ -n "$ITEM" ] && PLAN_OOB+=("$ITEM")
    done < <(parse_plan_section "$PLAN" '^### 🛑 Out of Bounds' '^## ')

    if [ ${#PLAN_TARGETS[@]} -gt 0 ]; then
        HAS_ANY_ACTIVE_TARGETS=1
    fi

    # Check if this plan's own OOB excludes target
    if [ ${#PLAN_OOB[@]} -gt 0 ] && match_pattern_list "$TARGET_FILE" "${PLAN_OOB[@]}"; then
        DENIED_BY_PLAN="$PLAN"
        continue
    fi

    # Check if this plan allows target
    if [ ${#PLAN_TARGETS[@]} -gt 0 ] && match_pattern_list "$TARGET_FILE" "${PLAN_TARGETS[@]}"; then
        ALLOWED_BY_A_PLAN=1
        break
    fi
done <<< "$ACTIVE_PLANS"

if [ "$ALLOWED_BY_A_PLAN" -eq 1 ]; then
    exit 0
fi

if [ "$UNBLOCKED_PLANS" -gt 0 ] && [ "$HAS_ANY_ACTIVE_TARGETS" -eq 0 ] && [ -z "$DENIED_BY_PLAN" ]; then
    # Out-of-bounds only plans exist, but this file is not in OOB
    exit 0
fi

# Target is outside blast radius or in OOB
if [ -n "$DENIED_BY_PLAN" ]; then
    REASON="File '$TARGET_FILE' is explicitly OUT OF BOUNDS in active plan '$DENIED_BY_PLAN'."
else
    REASON="File '$TARGET_FILE' is outside the declared Target Files of all active plans."
fi

if [ -n "$TOOL_NAME" ]; then
    python3 -c '
import json, sys
print(json.dumps({"decision": "deny", "reason": sys.argv[1]}))
' "$REASON"
else
    echo "❌ [Blast Radius Violation] $REASON" >&2
fi
exit 1
