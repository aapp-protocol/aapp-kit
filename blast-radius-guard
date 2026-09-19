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

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

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
    if command -v python3 >/dev/null 2>&1; then
        PARSED=$(printf '%s' "$RAW_INPUT" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    tool = data.get("tool_name", "")
    inp = data.get("tool_input", {})
    path = inp.get("file_path") or inp.get("path") or inp.get("target_file") or ""
    print(f"{tool}\t{path}")
except Exception:
    sys.exit(0)
' 2>/dev/null || true)
        if [ -n "$PARSED" ]; then
            TOOL_NAME=$(echo "$PARSED" | cut -f1)
            TARGET_FILE=$(echo "$PARSED" | cut -f2)
        fi
    else
        # POSIX fallback
        TARGET_FILE=$(echo "$RAW_INPUT" | grep -oE '"(file_path|path|target_file)"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n 1 | sed -E 's/.*:[[:space:]]*"([^"]+)".*/\1/')
        TOOL_NAME=$(echo "$RAW_INPUT" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n 1 | sed -E 's/.*:[[:space:]]*"([^"]+)".*/\1/')
    fi
fi

if [ -z "$TARGET_FILE" ]; then
    exit 0
fi

# POSIX lexical path canonicalization (resolves . and .. without expanding symlinks)
canonicalize_path() {
    local p="$1"
    case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
    local out="" seg
    local IFS=/
    for seg in $p; do
        case "$seg" in
            ''|.) continue ;;
            ..)   out="${out%/*}" ;;
            *)    out="$out/$seg" ;;
        esac
    done
    printf '%s\n' "${out:-/}"
}

ORIGINAL_TARGET="$TARGET_FILE"
CANONICAL_TARGET=$(canonicalize_path "$TARGET_FILE")
REPO_ROOT=$(canonicalize_path "$REPO_ROOT")

# Normalize path relative to project root for repo-internal matching
case "$CANONICAL_TARGET" in
    "$REPO_ROOT")
        TARGET_FILE="."
        ;;
    "$REPO_ROOT"/*)
        TARGET_FILE="${CANONICAL_TARGET#"$REPO_ROOT"/}"
        ;;
    *)
        TARGET_FILE="$CANONICAL_TARGET"
        ;;
esac

deny_action() {
    local reason="$1"
    if [ -n "$TOOL_NAME" ]; then
        if command -v python3 >/dev/null 2>&1; then
            python3 -c '
import json, sys
out = {
    "decision": "deny",
    "reason": sys.argv[1],
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": sys.argv[1]
    }
}
print(json.dumps(out))
' "$reason"
        else
            local escaped_reason
            escaped_reason=$(printf '%s' "$reason" | awk '{printf "%s%s", (NR>1?" ":""), $0}' | sed 's/\\/\\\\/g; s/"/\\"/g')
            printf '{"decision":"deny","reason":"%s","hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$escaped_reason" "$escaped_reason"
        fi
        echo "❌ [Blast Radius Guard Violation] $reason" >&2
    else
        echo "❌ [Blast Radius Guard Violation] $reason" >&2
    fi
    exit 2
}

# ------------------------------------------------------------------------------
# 2. Self-Protection Invariants (ALWAYS PROTECTED - Hard Block)
# ------------------------------------------------------------------------------
case "$TARGET_FILE" in
    .claude/settings.json|.claude/settings.local.json|*/.claude/settings.json|*/.claude/settings.local.json|\
    .agents/claude/*|*/.agents/claude/*|\
    .agents/skills/aapp-*|*/.agents/skills/aapp-*|\
    .claude/skills/aapp-*|*/.claude/skills/aapp-*|\
    .agents/skills/plan|*/.agents/skills/plan|.agents/skills/plan/*|*/.agents/skills/plan/*|\
    .claude/skills/plan|*/.claude/skills/plan|.claude/skills/plan/*|*/.claude/skills/plan/*)
        deny_action "Tampering with AAPP core configuration or governance skills is strictly prohibited."
        ;;
    .githooks/*|*/.githooks/*|.git/hooks/*|*/.git/hooks/*)
        deny_action "Tampering with AAPP git hooks engine is strictly prohibited."
        ;;
    .git/config|*/.git/config)
        deny_action "Tampering with git configuration (.git/config) is strictly prohibited."
        ;;
    .cursor/rules/*|*/.cursor/rules/*)
        deny_action "Tampering with agent rule files (.cursor/rules/) is strictly prohibited."
        ;;
esac

# ------------------------------------------------------------------------------
# 2b. External Hard-Deny (Credentials, Shell Startup Files, System Binaries)
# ------------------------------------------------------------------------------
case "$CANONICAL_TARGET" in
    */.ssh/*|*/.gnupg/*|*/.aws/*|*/.azure/*|*/.kube/*|*/.docker/config.json|\
    */.netrc|*/.npmrc|*/.pypirc|*/.git-credentials|\
    */.gitconfig|*/.config/git/*|\
    */.bashrc|*/.bash_profile|*/.zshrc|*/.zprofile|*/.profile|\
    */.config/fish/*|*/crontab|*/.local/bin/*)
        deny_action "Modifying sensitive credentials, shell configuration, or external binaries is strictly prohibited."
        ;;
esac

# ------------------------------------------------------------------------------
# 2c. External Path Allowlist (Agent Memory, Scratchpads, and User Allowlist)
# ------------------------------------------------------------------------------
resolve_allowlist() {
    local list=()

    add_prefix() {
        local p="$1"
        [ -z "$p" ] && return 0
        case "$p" in
            "~") p="$HOME" ;;
            "~/"*) p="$HOME/${p#\~/}" ;;
        esac
        if [ -n "$HOME" ]; then
            p="${p/\$HOME/$HOME}"
        fi
        local canon
        canon=$(canonicalize_path "$p")
        if [ -n "$canon" ] && [ "$canon" != "/" ]; then
            # Strictly normalize with trailing slash to prevent prefix-aliasing
            list+=("${canon%/}/")
        fi
    }

    # Built-in multi-agent defaults
    [ -n "$HOME" ] && add_prefix "$HOME/.claude"
    [ -n "$HOME" ] && add_prefix "$HOME/.gemini"
    [ -n "$HOME" ] && add_prefix "$HOME/.codex"
    [ -n "$HOME" ] && add_prefix "$HOME/.cursor"
    if [ -n "$XDG_CONFIG_HOME" ]; then
        add_prefix "$XDG_CONFIG_HOME"
    elif [ -n "$HOME" ]; then
        add_prefix "$HOME/.config"
    fi
    if [ -n "$XDG_DATA_HOME" ]; then
        add_prefix "$XDG_DATA_HOME"
    elif [ -n "$HOME" ]; then
        add_prefix "$HOME/.local/share"
    fi
    [ -n "$TMPDIR" ] && add_prefix "$TMPDIR"
    add_prefix "/tmp"
    [ -d "/var/folders" ] && add_prefix "/var/folders"

    # User-configured additions from git config
    local custom
    while IFS= read -r custom; do
        [ -n "$custom" ] && add_prefix "$custom"
    done < <(git config --get-all aapp.allowPath 2>/dev/null || true)

    printf '%s\n' "${list[@]}"
}

case "$CANONICAL_TARGET" in
    "$REPO_ROOT"/*)
        # Inside repository, proceed to Section 3 and Section 4 blast radius checks
        ;;
    *)
        # External path: check against authorized allowlist
        while IFS= read -r allowed_prefix; do
            [ -z "$allowed_prefix" ] && continue
            case "$CANONICAL_TARGET" in
                "$allowed_prefix"*)
                    exit 0
                    ;;
            esac
        done < <(resolve_allowlist)
        ;;
esac

# ------------------------------------------------------------------------------
# 2d. Project Circuit Breaker (Emergency Pause Check)
# ------------------------------------------------------------------------------
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
    # While paused, allow reflections strictly within .plans/ (pickup, issues, current)
    case "$TARGET_FILE" in
        .plans/pickup*|.plans/ISSUES.md|.plans/issues*|.plans/current/*)
            exit 0
            ;;
    esac
    case "$(basename "$REPO_ROOT")" in
        .plans)
            case "$TARGET_FILE" in
                pickup*|ISSUES.md|issues*|current/*)
                    exit 0
                    ;;
            esac
            ;;
    esac

    PAUSE_REASON=""
    if [ -f "$PAUSED_FILE" ]; then
        if command -v python3 >/dev/null 2>&1; then
            PAUSE_REASON=$(python3 -c 'import json, sys; d=json.load(open(sys.argv[1])); print(d.get("reason", ""))' "$PAUSED_FILE" 2>/dev/null || true)
        else
            PAUSE_REASON=$(grep -oE '"reason"[[:space:]]*:[[:space:]]*"[^"]+"' "$PAUSED_FILE" 2>/dev/null | head -n 1 | sed -E 's/.*:[[:space:]]*"([^"]+)".*/\1/' || true)
        fi
    fi
    if [ -z "$PAUSE_REASON" ] && [ -n "$SHARED_PAUSED_FILE" ] && [ -f "$SHARED_PAUSED_FILE" ]; then
        PAUSE_REASON=$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Reason:\*\*[[:space:]]*(.*)/\1/p' "$SHARED_PAUSED_FILE" 2>/dev/null | head -n 1 || true)
    fi
    [ -z "$PAUSE_REASON" ] && PAUSE_REASON="developer paused project"

    deny_action "🛑 [Project Circuit Breaker] The project is currently PAUSED.
   Reason : $PAUSE_REASON
   Stashes: In-flight changes quarantined across worktrees
   Only .plans/ (pickup, issues, current) reflections may be modified while paused.
   All other modifications (codebase, .agents/, templates, hooks) are strictly refused.
   To resume modifications, run 'aapp resume'."
fi

# ------------------------------------------------------------------------------
# 3. Always-Allowed Invariants (Plans, Rules, Root Anchors)
# ------------------------------------------------------------------------------
case "$TARGET_FILE" in
    .plans/*|.agents/*)
        exit 0
        ;;
    CHANGELOG.md|README.md|MANUAL.md|CHEATSHEET.md|CODEMAP.md|ARCHITECTURE.md|ISSUES.md|.gitignore)
        exit 0
        ;;
    package.json|package-lock.json|composer.json|composer.lock|go.mod|go.sum|Cargo.toml|Cargo.lock|pyproject.toml|requirements.txt)
        exit 0
        ;;
esac

# ------------------------------------------------------------------------------
# 4. Blast Radius Validation Against Active Plan
# ------------------------------------------------------------------------------
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
            sub(/^[[:space:]]*(`?(NEW FILE|MODIFY|DELETE|ADD|REPLACE)`?)?[[:space:]]*->[[:space:]]*/, "", line)
            if (match(line, /`[^`]+`/)) {
                item = substr(line, RSTART+1, RLENGTH-2)
                if (item !~ /^(NEW FILE|MODIFY|DELETE|ADD|REPLACE)$/) {
                    print item
                }
            }
        }
    ' "$file"
}

glob_to_regex() {
    local p="$1"
    # 1. Escape regex metacharacters: \ . + ^ $ ( ) { } |
    p="${p//\\/\\\\}"
    p="${p//./\\.}"
    p="${p//+/\\+}"
    p="${p//^/\\^}"
    p="${p//\$/\\\$}"
    p="${p//(/\\(}"
    p="${p//)/\\)}"
    p="${p//\{/\\\{}"
    p="${p//\}/\\\}}"
    p="${p//|/\\|}"

    # 2. Protect multi-segment globstars using collision-free sentinels
    p="${p//\/\*\*\//__SLASH_GLOBSTAR_SLASH__}"
    # Leading **/
    if [[ "$p" == \*\** ]]; then
        p="${p/#\*\*\//__LEADING_GLOBSTAR_SLASH__}"
    fi
    # Trailing /**
    if [[ "$p" == *\/\*\* ]]; then
        p="${p/%\/\*\*/__SLASH_TRAILING_GLOBSTAR__}"
    fi
    p="${p//\*\*/__GLOBSTAR__}"

    # 3. Translate single-segment wildcard and single-char tokens
    p="${p//\*/[^/]*}"
    p="${p//\?/[^/]}"

    # 4. Expand sentinels into POSIX regex
    p="${p//__SLASH_GLOBSTAR_SLASH__/\/(.*\/)?}"
    p="${p//__LEADING_GLOBSTAR_SLASH__/(.*\/)?}"
    p="${p//__SLASH_TRAILING_GLOBSTAR__/\/(.*)?}"
    p="${p//__GLOBSTAR__/.*}"

    echo "^${p}\$"
}

match_pattern_list() {
    local target="$1"
    shift
    local pattern
    for pattern in "$@"; do
        [ -z "$pattern" ] && continue
        # Tier 1 (Exact Match)
        if [ "$target" = "$pattern" ]; then
            return 0
        fi
        # Tier 2 (Directory Prefix Match)
        if [[ "$pattern" == */ ]]; then
            if [[ "$target" == "$pattern"* ]]; then
                return 0
            fi
        fi
        # Tier 3 (Glob / Regex Match)
        if [[ "$pattern" == *[*?\[]* ]]; then
            local regex
            regex=$(glob_to_regex "$pattern")
            if [[ "$target" =~ $regex ]]; then
                return 0
            fi
        fi
    done
    return 1
}

# 1. Canonical Worktree & .plans/ Resolution
GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null || echo ".git")"
if [ -d "$GIT_COMMON_DIR" ]; then
    PRIMARY_ROOT="$(cd "$GIT_COMMON_DIR/.." 2>/dev/null && pwd)"
else
    PRIMARY_ROOT="$REPO_ROOT"
fi

if [ -d "$REPO_ROOT/.plans" ]; then
    PLANS_DIR="$REPO_ROOT/.plans"
elif [ -n "$PRIMARY_ROOT" ] && [ -d "$PRIMARY_ROOT/.plans" ]; then
    PLANS_DIR="$PRIMARY_ROOT/.plans"
else
    PLANS_DIR=""
fi

# 2. Fail-Closed Quarantine in AAPP Repositories
if [ -z "$PLANS_DIR" ] || [ ! -d "$PLANS_DIR/current" ]; then
    if [ -f "$REPO_ROOT/.githooks/blast-radius-guard" ] || [ -f "$PRIMARY_ROOT/.githooks/blast-radius-guard" ] || \
       [ -f "$REPO_ROOT/aapp" ] || [ -f "$PRIMARY_ROOT/aapp" ]; then
        deny_action "AAPP repository detected but .plans/current directory is missing or unmounted."
    else
        case "$CANONICAL_TARGET" in
            "$REPO_ROOT"/*) exit 0 ;;
            *) deny_action "File '$ORIGINAL_TARGET' is outside repository and not in the authorized path allowlist." ;;
        esac
    fi
fi

# Check if target file belongs to any BLOCKED plan in workspace
for pf in "$PLANS_DIR"/current/*.md; do
    [ ! -f "$pf" ] && continue
    case "$(basename "$pf")" in 000-*) continue ;; esac
    if grep -qE '^[[:space:]]*[\*|-]*[[:space:]]*\*\*Status:\*\*[[:space:]]*.*(🚫|🟥|BLOCKED)' "$pf" 2>/dev/null; then
        BLOCKED_TARGETS=()
        while IFS= read -r ITEM; do
            [ -n "$ITEM" ] && BLOCKED_TARGETS+=("$ITEM")
        done < <(parse_plan_section "$pf" '^### 📂 Target Files|^### 🚨 Emergency Hotfix' '^### 🛑 Out of Bounds|^## ')
        if [ ${#BLOCKED_TARGETS[@]} -gt 0 ] && match_pattern_list "$TARGET_FILE" "${BLOCKED_TARGETS[@]}"; then
            deny_action "Plan '$(basename "$pf")' is BLOCKED. All modifications are refused."
        fi
    fi
done

# 3. Active Plan Context Resolution (Pointer Buffer -> Single 🟠 Auto-Discovery)
ACTIVE_PLAN_FILE="$(git rev-parse --git-path aapp_active_plan 2>/dev/null || echo ".git/aapp_active_plan")"
DESIGNATED_PLAN_ID=""
if [ -f "$ACTIVE_PLAN_FILE" ]; then
    DESIGNATED_PLAN_ID="$(head -n 1 "$ACTIVE_PLAN_FILE" 2>/dev/null | tr -d '[:space:]')"
fi

ACTIVE_PLAN_PATH=""
if [ -n "$DESIGNATED_PLAN_ID" ]; then
    for pf in "$PLANS_DIR"/current/*.md; do
        [ ! -f "$pf" ] && continue
        case "$(basename "$pf")" in 000-*) continue ;; esac
        local_id="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" 2>/dev/null || true)"
        bname="$(basename "$pf" .md)"
        if [ "$local_id" = "$DESIGNATED_PLAN_ID" ] || [ "$bname" = "$DESIGNATED_PLAN_ID" ] || \
           [[ "$bname" == "$DESIGNATED_PLAN_ID-"* ]] || [[ "$bname" == "P$DESIGNATED_PLAN_ID-"* ]] || \
           [[ "$bname" == "P-$DESIGNATED_PLAN_ID-"* ]]; then
            ACTIVE_PLAN_PATH="$pf"
            break
        fi
    done
    if [ -z "$ACTIVE_PLAN_PATH" ]; then
        deny_action "Designated active plan '$DESIGNATED_PLAN_ID' not found in $PLANS_DIR/current/. Run 'aapp plan-clear' or 'aapp plan <id>'."
    fi
else
    DEV_PLANS=()
    for pf in "$PLANS_DIR"/current/*.md; do
        [ ! -f "$pf" ] && continue
        case "$(basename "$pf")" in 000-*) continue ;; esac
        if grep -qE '^[[:space:]]*[\*|-]*[[:space:]]*\*\*Status:\*\*[[:space:]]*.*⚡[[:space:]]*In Development' "$pf" 2>/dev/null; then
            DEV_PLANS+=("$pf")
        elif ! grep -qE '^[[:space:]]*[\*|-]*[[:space:]]*\*\*Status:\*\*' "$pf" 2>/dev/null; then
            DEV_PLANS+=("$pf")
        fi
    done

    if [ ${#DEV_PLANS[@]} -eq 1 ]; then
        ACTIVE_PLAN_PATH="${DEV_PLANS[0]}"
    elif [ ${#DEV_PLANS[@]} -gt 1 ]; then
        PLAN_LIST=$(for p in "${DEV_PLANS[@]}"; do basename "$p" .md; done | tr '\n' ',' | sed 's/,$//')
        deny_action "Multiple plans in development [$PLAN_LIST]. Run 'aapp plan <id>' to select context."
    else
        # Check if any frozen blueprints exist in .plans/current
        has_frozen_plans=0
        for pf in "$PLANS_DIR"/current/*.md; do
            [ ! -f "$pf" ] && continue
            case "$(basename "$pf")" in 000-*) continue ;; esac
            if grep -qE '^[[:space:]]*[\*|-]*[[:space:]]*\*\*Status:\*\*[[:space:]]*.*🔷[[:space:]]*Frozen' "$pf" 2>/dev/null; then
                has_frozen_plans=1
                break
            fi
        done

        if [ "$has_frozen_plans" -eq 1 ]; then
            deny_action "No plan is currently in development. Run 'aapp start <id>' or 'aapp freeze-start <id>' to begin execution."
        fi

        case "$CANONICAL_TARGET" in
            "$REPO_ROOT"/*)
                exit 0
                ;;
            *)
                deny_action "File '$ORIGINAL_TARGET' is outside repository and not in the authorized path allowlist."
                ;;
        esac
    fi
fi

# 4. Enforce Boundaries for Active Plan
if grep -qE '^[[:space:]]*[\*|-]*[[:space:]]*\*\*Status:\*\*[[:space:]]*.*(🚫|🟥|BLOCKED)' "$ACTIVE_PLAN_PATH"; then
    deny_action "Active plan '$(basename "$ACTIVE_PLAN_PATH")' is BLOCKED. All modifications are refused."
fi

PLAN_TARGETS=()
PLAN_OOB=()

while IFS= read -r ITEM; do
    [ -n "$ITEM" ] && PLAN_TARGETS+=("$ITEM")
done < <(parse_plan_section "$ACTIVE_PLAN_PATH" '^### 📂 Target Files|^### 🚨 Emergency Hotfix' '^### 🛑 Out of Bounds|^## ')

while IFS= read -r ITEM; do
    [ -n "$ITEM" ] && PLAN_OOB+=("$ITEM")
done < <(parse_plan_section "$ACTIVE_PLAN_PATH" '^### 🛑 Out of Bounds' '^## ')

# 1. Out of Bounds veto
if [ ${#PLAN_OOB[@]} -gt 0 ] && match_pattern_list "$TARGET_FILE" "${PLAN_OOB[@]}"; then
    deny_action "File '$ORIGINAL_TARGET' is explicitly OUT OF BOUNDS in active plan '$(basename "$ACTIVE_PLAN_PATH")'."
fi

# 2. Target Files allow
if [ ${#PLAN_TARGETS[@]} -gt 0 ] && match_pattern_list "$TARGET_FILE" "${PLAN_TARGETS[@]}"; then
    exit 0
fi

# 3. Out-of-bounds only plan without declared targets
if [ ${#PLAN_TARGETS[@]} -eq 0 ] && [ ${#PLAN_OOB[@]} -gt 0 ]; then
    exit 0
fi

deny_action "File '$ORIGINAL_TARGET' is outside the declared Target Files of active plan '$(basename "$ACTIVE_PLAN_PATH")'."
