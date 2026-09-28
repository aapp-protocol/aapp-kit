#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `ai` (AI Attribution Policy & Credits Manager)
#
# Usage:
#   aapp ai [status | none | lax | strict | notes | credits]
# ==============================================================================
set -e

AI_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$AI_LIB_DIR/attribution.sh" ]; then
    # shellcheck source=/dev/null
    source "$AI_LIB_DIR/attribution.sh"
fi

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

cmd_ai_status() {
    local mode
    mode="$(git config aapp.aiAttribution 2>/dev/null || echo "none")"
    local subject_max
    subject_max="$(git config --int aapp.subjectMaxLen 2>/dev/null || echo "72")"
    local credits_enabled
    credits_enabled="$(git config aapp.aiCredits 2>/dev/null || echo "false")"
    local note_dir
    note_dir="$(git rev-parse --git-path . 2>/dev/null || echo ".git")"

    echo "🤖 AAPP AI Attribution Policy Status"
    echo "============================================================"
    echo "  Mode              : $mode"
    case "$mode" in
        lax)
            echo "  Description       : Public semantic trailers when present (human-friendly default)"
            ;;
        strict)
            echo "  Description       : Strict public emailless trailers required on every commit"
            ;;
        notes)
            echo "  Description       : Local-first / private git notes"
            ;;
        none|*)
            echo "  Description       : Disabled (pure human authoring)"
            ;;
    esac
    echo "  Max Subject Length: $subject_max chars (aapp.subjectMaxLen)"
    echo "  Credits Footer    : $credits_enabled (aapp.aiCredits)"
    echo ""

    if [ -d "$note_dir" ]; then
        local pending_notes=()
        while IFS= read -r -d '' pfile; do
            [ -n "$pfile" ] && pending_notes+=("$pfile")
        done < <(find "$note_dir" -maxdepth 1 -name 'aapp_pending_note.*' -print0 2>/dev/null)

        local count="${#pending_notes[@]}"
        echo "📝 Pending Note Buffers ($count):"
        if [ "$count" -eq 0 ]; then
            echo "  (no pending note buffers)"
        else
            for pn in "${pending_notes[@]}"; do
                local bname
                bname="$(basename "$pn")"
                local sha="${bname#aapp_pending_note.}"
                local age="unknown"
                if command -v stat >/dev/null 2>&1; then
                    local mtime
                    mtime=$(stat -c %Y "$pn" 2>/dev/null || stat -f %m "$pn" 2>/dev/null || echo 0)
                    local now
                    now=$(date +%s)
                    if [ "$mtime" -gt 0 ]; then
                        local diff=$((now - mtime))
                        local mins=$((diff / 60))
                        age="${mins}m ago"
                    fi
                fi
                echo "  • Hash: $sha ($age)"
            done
        fi
    fi
}

cmd_ai_lax() {
    git config aapp.aiAttribution lax
    echo "✅ Switched AI attribution to 'lax' mode."
    echo "   Commits with AI trailers will be validated; human commits pass freely."
    echo "   Semantic emailless trailers:"
    echo "     AI-Agent: <Agent Name>"
    echo "     AI-Vendor: <Vendor Name>"
    echo "     AI-Model: <Model ID>"
    echo "   Synthetic email addresses in Co-authored-by: are prohibited."
}

cmd_ai_strict() {
    git config aapp.aiAttribution strict
    echo "✅ Switched AI attribution to 'strict' mode."
    echo "   Every commit will require valid semantic emailless trailers:"
    echo "     AI-Agent: <Agent Name>"
    echo "     AI-Vendor: <Vendor Name>"
    echo "     AI-Model: <Model ID>"
    echo "   Synthetic email addresses in Co-authored-by: are prohibited."
}

cmd_ai_notes() {
    git config aapp.aiAttribution notes
    git config notes.mergeStrategy cat_sort_uniq
    git config notes.rewriteMode concatenate
    git config --replace-all notes.rewriteRef "refs/notes/commits"
    echo "✅ Switched AI attribution to 'notes' mode."
    echo "   Commit messages will remain pristine and human-only."
    echo "   Attribution metadata will be attached to refs/notes/commits."
    echo "   Configured mergeStrategy (cat_sort_uniq) and rewriteRef (refs/notes/commits)."
}

cmd_ai_none() {
    git config aapp.aiAttribution none
    git config aapp.aiCredits false
    echo "✅ AI attribution disabled (mode: none)."
    echo "   Pure human commit authoring; no AI trailers or git notes required."
}

cmd_ai_credits() {
    local mode
    mode="$(git config aapp.aiAttribution 2>/dev/null || echo "none")"

    # §E.8 Mode boundary check
    if [ "$mode" = "none" ]; then
        echo "ℹ️  AI attribution is disabled (mode: none). AI Contributors block is not generated."
        return 0
    elif [ "$mode" = "notes" ]; then
        echo "ℹ️  Notes mode is private-first. AI Contributors block is commit-mode only."
        echo "   See MANUAL.md for mode-boundary rationale. No changes made."
        return 0
    fi

    # Exported by the `aapp` dispatcher, which asserts repository membership (P-33).
    local repo_root="$REPO_ROOT"
    local readme_file="$repo_root/README.md"

    if [ ! -f "$readme_file" ]; then
        echo "⚠️  [Notice] README.md not found at project root; skipping credits block generation." >&2
        return 0
    fi

    # 1. Read existing credits from README block (if present)
    local existing_identities=()
    local start_count=0
    local end_count=0
    start_count="$(grep -c "<!-- AAPP-AI-CREDITS:START -->" "$readme_file" 2>/dev/null || true)"
    end_count="$(grep -c "<!-- AAPP-AI-CREDITS:END -->" "$readme_file" 2>/dev/null || true)"

    if [ "$start_count" -ne "$end_count" ] || [ "$start_count" -gt 1 ]; then
        echo "❌ [Error] Unparseable AAPP-AI-CREDITS block in README.md (mismatched or duplicate START/END tags); aborting to prevent overwrite." >&2
        return 1
    fi

    if [ "$start_count" -eq 1 ] && [ "$end_count" -eq 1 ]; then
        local start_line end_line
        start_line="$(grep -n "<!-- AAPP-AI-CREDITS:START -->" "$readme_file" | head -n1 | cut -d: -f1)"
        end_line="$(grep -n "<!-- AAPP-AI-CREDITS:END -->" "$readme_file" | head -n1 | cut -d: -f1)"
        if [ "$start_line" -ge "$end_line" ]; then
            echo "❌ [Error] Unparseable AAPP-AI-CREDITS block in README.md (START tag appears after END tag); aborting to prevent overwrite." >&2
            return 1
        fi
    fi

    if [ "$start_count" -eq 1 ]; then
        while IFS= read -r line; do
            local clean
            clean="$(echo "$line" | sed -E 's/^[[:space:]]*-[[:space:]]+//; s/[[:space:]]*$//')"
            if [ -n "$clean" ]; then
                clean="$(apply_agent_aliases "$clean")"
                clean="$(normalize_agent_identity "$clean" "")"
                [ -n "$clean" ] && existing_identities+=("$clean")
            fi
        done < <(sed -n '/<!-- AAPP-AI-CREDITS:START -->/,/<!-- AAPP-AI-CREDITS:END -->/p' "$readme_file" | grep -E '^[[:space:]]*-[[:space:]]+')
    fi

    # 2. Extract commit trailers from git history
    local history_identities=()
    if git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
        while IFS='|' read -r raw_agent raw_vendor; do
            [ -z "$raw_agent" ] && continue
            raw_agent="$(apply_agent_aliases "$raw_agent")"
            local norm
            norm="$(normalize_agent_identity "$raw_agent" "$raw_vendor")"
            [ -n "$norm" ] && history_identities+=("$norm")
        done < <(git -C "$repo_root" log --all --format='%(trailers:key=AI-Agent,valueonly)|%(trailers:key=AI-Vendor,valueonly)' 2>/dev/null || true)
    fi

    # 3. Union existing and history (LC_ALL=C sorted & unique)
    local all_identities=()
    all_identities+=("${existing_identities[@]}")
    all_identities+=("${history_identities[@]}")

    local sorted_unique=()
    if [ ${#all_identities[@]} -gt 0 ]; then
        while IFS= read -r item; do
            [ -n "$item" ] && sorted_unique+=("$item")
        done < <(printf "%s\n" "${all_identities[@]}" | LC_ALL=C sort -u)
    fi

    if [ ${#sorted_unique[@]} -eq 0 ]; then
        echo "ℹ️  No AI contributors found in README or commit history. Block unchanged."
        return 0
    fi

    # 4. Construct locked block
    local block_lines=()
    block_lines+=("<!-- AAPP-AI-CREDITS:START -->")
    block_lines+=("## AI Contributors")
    block_lines+=("")
    block_lines+=("The following AI coding agents contributed to this codebase — planning, code, and review.")
    block_lines+=("Listed alphabetically; the ordering carries no meaning, and no division of work is implied.")
    block_lines+=("")
    for item in "${sorted_unique[@]}"; do
        block_lines+=("- $item")
    done
    block_lines+=("")
    block_lines+=("Authorship of, and responsibility for, this code rest with its human contributors.")
    block_lines+=("<!-- AAPP-AI-CREDITS:END -->")

    local block_str
    block_str="$(printf "%s\n" "${block_lines[@]}")"

    # 5. Update README.md
    if grep -q "<!-- AAPP-AI-CREDITS:START -->" "$readme_file"; then
        local tmp_file
        tmp_file="$(mktemp)"
        awk -v block="$block_str" '
            /<!-- AAPP-AI-CREDITS:START -->/ {
                print block
                in_block = 1
                next
            }
            /<!-- AAPP-AI-CREDITS:END -->/ {
                in_block = 0
                next
            }
            !in_block { print }
        ' "$readme_file" > "$tmp_file"

        if cmp -s "$readme_file" "$tmp_file"; then
            rm -f "$tmp_file"
            echo "✅ AI Contributors block in README.md is up to date."
        else
            mv "$tmp_file" "$readme_file"
            echo "✅ Updated AI Contributors block in README.md."
        fi
    else
        local tmp_file
        tmp_file="$(mktemp)"
        cat "$readme_file" > "$tmp_file"
        [ -n "$(tail -c 1 "$readme_file" 2>/dev/null)" ] && echo "" >> "$tmp_file"
        echo "" >> "$tmp_file"
        echo "$block_str" >> "$tmp_file"
        mv "$tmp_file" "$readme_file"
        echo "✅ Generated AI Contributors block in README.md."
    fi

    git config aapp.aiCredits true
    return 0
}

# ------------------------------------------------------------------------------
# Dispatcher Entrypoint
# ------------------------------------------------------------------------------
ACTION="${1:-status}"
shift || true

case "$ACTION" in
    status)
        cmd_ai_status "$@"
        ;;
    lax)
        cmd_ai_lax "$@"
        ;;
    strict)
        cmd_ai_strict "$@"
        ;;
    notes)
        cmd_ai_notes "$@"
        ;;
    none)
        cmd_ai_none "$@"
        ;;
    credits)
        cmd_ai_credits "$@"
        ;;
    help|-h|--help)
        cat <<EOF
Usage: aapp ai [status | none | lax | strict | notes | credits]

AI Attribution Policy Commands:
  status    Display current attribution mode, config, and pending notes
  none      Disable AI attribution (pure human authoring)
  lax       Switch to lax attribution (validates trailers when present; human commits pass)
  strict    Switch to strict attribution (requires valid trailers on every commit)
  notes     Switch to local-first git notes mode
  credits   Generate or update AI Contributors block in README.md
EOF
        ;;
    *)
        echo "❌ Unknown AI mode or command: '$ACTION'. Valid: status, none, lax, strict, notes, credits." >&2
        exit 1
        ;;
esac
