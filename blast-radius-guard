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
        "permissionDecision": "deny"
    }
}
print(json.dumps(out))
' "$reason"
        else
            local escaped_reason
            escaped_reason=$(printf '%s' "$reason" | awk '{printf "%s%s", (NR>1?" ":""), $0}' | sed 's/\\/\\\\/g; s/"/\\"/g')
            printf '{"decision":"deny","reason":"%s","hookSpecificOutput":{"permissionDecision":"deny"}}\n' "$escaped_reason"
        fi
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
    .claude/skills/aapp-*|*/.claude/skills/aapp-*)
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
# 4. Blast Radius Validation Against Active Plans
# ------------------------------------------------------------------------------
ACTIVE_PLANS=""
if [ -d .plans/current ]; then
    NL='
'
    for plan_file in .plans/current/*.md; do
        [ ! -f "$plan_file" ] && continue
        case "$(basename "$plan_file")" in
            000-*) continue ;;
        esac
        if grep -qE '^[[:space:]]*[\*|-]*[[:space:]]*\*\*Status:\*\*[[:space:]]*.*(🔴|🟡|Under Review|Refining)' "$plan_file" 2>/dev/null; then
            continue
        fi
        ACTIVE_PLANS="${ACTIVE_PLANS:+$ACTIVE_PLANS$NL}$plan_file"
    done
fi

if [ -z "$ACTIVE_PLANS" ]; then
    # Fail-open: if no active blueprints exist, allow edits to normal project files
    case "$CANONICAL_TARGET" in
        "$REPO_ROOT"/*)
            exit 0
            ;;
        *)
            deny_action "File '$ORIGINAL_TARGET' is outside repository and not in the authorized path allowlist."
            ;;
    esac
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
    if grep -qE '^[[:space:]]*[\*|-]*[[:space:]]*\*\*Status:\*\*[[:space:]]*.*(🚫|BLOCKED)' "$PLAN"; then
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
    REASON="File '$ORIGINAL_TARGET' is explicitly OUT OF BOUNDS in active plan '$DENIED_BY_PLAN'."
else
    REASON="File '$ORIGINAL_TARGET' is outside the declared Target Files of all active plans."
fi

deny_action "$REASON"
