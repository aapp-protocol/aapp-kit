#!/usr/bin/env bash
# ==============================================================================
# AAPP Attribution Layer: Identity Resolution, Decoration & Note Management
# ==============================================================================
# Sourced functions only; no executable main.
# Functions:
#   apply_agent_aliases       - Normalize identities through aapp.aiAlias
#   normalize_agent_identity  - Canonicalize agent name and vendor
#   resolve_ai_identity       - Resolve AI identity by precedence hierarchy
#   attribution_decorate      - Decorate commit message file with trailers
#   attribution_note          - Attach git note with identity and optional text
# ==============================================================================

apply_agent_aliases() {
    local identity="$1"
    local aliases
    aliases="$(git config --get-all aapp.aiAlias 2>/dev/null || true)"
    if [ -z "$aliases" ]; then
        echo "$identity"
        return 0
    fi
    while IFS= read -r rule; do
        [ -z "$rule" ] && continue
        local from_val="${rule%%=*}"
        local to_val="${rule#*=}"
        from_val="$(echo "$from_val" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
        to_val="$(echo "$to_val" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
        [ -z "$from_val" ] && continue

        if [ "$identity" = "$from_val" ]; then
            identity="$to_val"
        elif [[ "$identity" =~ ^"$from_val"[[:space:]]*\((.*)\)$ ]]; then
            local vendor="${BASH_REMATCH[1]}"
            if [[ "$to_val" == *"("* ]]; then
                identity="$to_val"
            else
                identity="$to_val ($vendor)"
            fi
        fi
    done <<< "$aliases"
    echo "$identity"
}

normalize_agent_identity() {
    local raw_agent="$1"
    local raw_vendor="$2"
    local agent vendor
    agent="$(echo "$raw_agent" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    vendor="$(echo "$raw_vendor" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"

    if echo "$agent" | grep -qiE 'antigravity'; then
        echo "Antigravity (Google)"
    elif echo "$agent" | grep -qiE 'claude'; then
        echo "Claude (Anthropic)"
    elif echo "$agent" | grep -qiE 'copilot'; then
        echo "GitHub Copilot (Microsoft)"
    elif echo "$agent" | grep -qiE 'cursor'; then
        echo "Cursor (Anysphere)"
    elif echo "$agent" | grep -qiE 'codex|chatgpt'; then
        echo "Codex (OpenAI)"
    elif [ -n "$vendor" ] && [[ "$agent" != *"("* ]]; then
        echo "$agent ($vendor)"
    else
        echo "$agent"
    fi
}

resolve_ai_identity() {
    local agent="${1:-}"
    local vendor="${2:-}"
    local model="${3:-}"
    local msg_file="${4:-}"

    # 1. Parameter arguments passed directly (already in $agent, $vendor, $model)

    # 2. Environment variables
    if [ -z "$agent" ]; then
        agent="${AAPP_AGENT_NAME:-}"
    fi
    if [ -z "$vendor" ]; then
        vendor="${AAPP_AGENT_VENDOR:-}"
    fi
    if [ -z "$model" ]; then
        model="${AAPP_AGENT_MODEL:-}"
    fi

    # 3. Per-worktree git config (never plain repo config)
    if [ -z "$agent" ]; then
        agent="$(git config --worktree aapp.aiAgent 2>/dev/null || true)"
    fi
    if [ -z "$vendor" ]; then
        vendor="$(git config --worktree aapp.aiVendor 2>/dev/null || true)"
    fi
    if [ -z "$model" ]; then
        model="$(git config --worktree aapp.aiModel 2>/dev/null || true)"
    fi

    # 4. Vendor Co-Authored-By in commit message file
    if [ -z "$agent" ] && [ -n "$msg_file" ] && [ -f "$msg_file" ]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*[Cc]o-[Aa]uthored-[Bb]y:[[:space:]]*(.*) ]]; then
                local coauthor="${BASH_REMATCH[1]}"
                if echo "$coauthor" | grep -qiE 'Claude|Antigravity|GPT|Copilot|Codex|Cursor|Gemini|noreply\.anthropic\.com|antigravity@google\.com'; then
                    echo "⚠️ [Warning] Converted synthetic Co-authored-by email trailer to emailless semantic attribution." >&2
                    local cname="$coauthor"
                    local email_re='^(.*)[[:space:]]*<([^>]+)>'
                    if [[ "$coauthor" =~ $email_re ]]; then
                        cname="${BASH_REMATCH[1]}"
                    fi
                    cname="$(echo "$cname" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
                    agent="$cname"
                    if echo "$cname" | grep -qi "Claude"; then
                        vendor="Anthropic"
                    elif echo "$cname" | grep -qi "Antigravity"; then
                        vendor="Google"
                    elif echo "$cname" | grep -qi "Copilot"; then
                        vendor="Microsoft"
                    elif echo "$cname" | grep -qi "Cursor"; then
                        vendor="Anysphere"
                    elif echo "$cname" | grep -qiE 'Codex|GPT'; then
                        vendor="OpenAI"
                    fi
                    break
                fi
            fi
        done < "$msg_file"
    fi

    # 5. Nothing resolved -> empty
    if [ -z "$agent" ]; then
        return 0
    fi

    # Parse Vendor from Agent string if passed as 'Agent (Vendor)'
    if [[ "$agent" =~ ^(.*)[[:space:]]*\((.*)\)$ ]]; then
        agent="${BASH_REMATCH[1]}"
        if [ -z "$vendor" ]; then
            vendor="${BASH_REMATCH[2]}"
        fi
    fi

    agent="$(echo "$agent" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    vendor="$(echo "$vendor" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    model="$(echo "$model" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"

    [ -z "$vendor" ] && vendor="Unknown"
    [ -z "$model" ] && model="unknown"

    echo "AI-Agent: $agent"
    echo "AI-Vendor: $vendor"
    echo "AI-Model: $model"
}

format_identity_lines() {
    local id="$1"
    if [ -z "$id" ]; then
        return 0
    fi
    if [[ "$id" == *"AI-Agent:"* ]]; then
        echo "$id"
    elif [[ "$id" =~ ^(.*)[[:space:]]*\((.*)\)$ ]]; then
        local a="${BASH_REMATCH[1]}"
        local v="${BASH_REMATCH[2]}"
        a="$(echo "$a" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
        v="$(echo "$v" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
        echo "AI-Agent: $a"
        echo "AI-Vendor: $v"
        echo "AI-Model: unknown"
    else
        id="$(echo "$id" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
        echo "AI-Agent: $id"
        echo "AI-Vendor: Unknown"
        echo "AI-Model: unknown"
    fi
}

attribution_decorate() {
    local msg_file="$1"
    local identity="$2"
    local mode
    mode="$(git config aapp.aiAttribution 2>/dev/null || echo "none")"

    case "$mode" in
        strict)
            if [ -z "$identity" ]; then
                echo "❌ [Error] Strict attribution mode requires an AI identity." >&2
                return 1
            fi
            ;;
        lax)
            if [ -z "$identity" ]; then
                return 0
            fi
            ;;
        *)
            # none or notes: leave message alone
            return 0
            ;;
    esac

    if [ -z "$msg_file" ] || [ ! -f "$msg_file" ]; then
        return 0
    fi

    # Do not duplicate if AI-Agent already present
    if grep -qE '^[[:space:]]*AI-Agent:' "$msg_file" 2>/dev/null; then
        return 0
    fi

    local id_lines
    id_lines="$(format_identity_lines "$identity")"
    if [ -n "$id_lines" ]; then
        [ -n "$(tail -c 1 "$msg_file" 2>/dev/null)" ] && echo "" >> "$msg_file"
        echo "" >> "$msg_file"
        echo "$id_lines" >> "$msg_file"
    fi
    return 0
}

attribution_note() {
    local sha="$1"
    local identity="$2"
    local text="$3"
    local mode
    mode="$(git config aapp.aiAttribution 2>/dev/null || echo "none")"

    if [ "$mode" = "notes" ] && [ -z "$identity" ] && [ -n "$text" ]; then
        echo "❌ [Error] Note text provided without a resolved AI identity in 'notes' mode." >&2
        echo "   👉 Provide an identity via parameters, environment (AAPP_AGENT_*), or worktree config." >&2
        return 1
    fi

    if [ -z "$identity" ] && [ -z "$text" ]; then
        # Pure human commit, no note
        return 0
    fi

    local id_lines=""
    [ -n "$identity" ] && id_lines="$(format_identity_lines "$identity")"

    local note_content=""
    if [ -n "$id_lines" ] && [ -n "$text" ]; then
        note_content="${id_lines}"$'\n\n'"${text}"
    elif [ -n "$id_lines" ]; then
        note_content="${id_lines}"
    else
        note_content="${text}"
    fi

    if [ -z "$note_content" ] || [ -z "$sha" ]; then
        return 0
    fi

    if [ "$mode" = "notes" ]; then
        # In notes mode, primary note is attached to refs/notes/commits (Option C backward-compatible)
        git notes --ref="refs/notes/commits" append -m "$note_content" "$sha" || return $?
        # Also ensure AI trace is securely recorded in refs/notes/ai
        if [ -n "$id_lines" ]; then
            git notes --ref="refs/notes/ai" append -m "$id_lines" "$sha" || return $?
        fi
    else
        # In other modes (none, lax, strict), AI identity traces route to refs/notes/ai;
        # general notes without identity route to refs/notes/commits
        if [ -n "$identity" ]; then
            git notes --ref="refs/notes/ai" append -m "$note_content" "$sha" || return $?
        else
            git notes --ref="refs/notes/commits" append -m "$note_content" "$sha" || return $?
        fi
    fi
    return 0
}
