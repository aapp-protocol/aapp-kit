#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `ai-*` (AI Attribution Switchboard & Credits Manager)
#
# Subcommands:
#   ai-status   Display current attribution mode and pending note buffers
#   ai-commit   Switch to public semantic trailer mode (commit)
#   ai-notes    Switch to local-first git notes mode (notes)
#   ai-off      Disable AI attribution (none)
#   ai-note     Pre-stage customizable note buffer for upcoming commit (--stage)
#   ai-credits  Generate or update AI Contributors block in README.md
# ==============================================================================
set -e

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

    echo "🤖 AAPP AI Attribution Status"
    echo "============================================================"
    echo "  Mode              : $mode"
    case "$mode" in
        commit)
            echo "  Description       : Public emailless semantic trailers (AI-Agent:)"
            ;;
        notes)
            echo "  Description       : Local-first / private git notes (refs/notes/commits)"
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

cmd_ai_commit() {
    git config aapp.aiAttribution commit
    echo "✅ Switched AI attribution to 'commit' mode."
    echo "   All AI commits will require semantic emailless trailers:"
    echo "     AI-Agent: <Agent Name>"
    echo "     AI-Vendor: <Vendor Name>"
    echo "     AI-Model: <Model ID>"
    echo "   Synthetic email addresses in Co-authored-by: are prohibited."
}

cmd_ai_notes() {
    git config aapp.aiAttribution notes

    # Safe, idempotent git-notes configuration
    git config --replace-all remote.origin.push "+refs/heads/*:refs/heads/*" 2>/dev/null || true
    git config --add remote.origin.push "+refs/notes/*:refs/notes/*" 2>/dev/null || true
    git config --replace-all remote.origin.fetch "+refs/heads/*:refs/heads/*" 2>/dev/null || true
    git config --add remote.origin.fetch "+refs/notes/*:refs/notes/*" 2>/dev/null || true

    git config notes.mergeStrategy cat_sort_uniq
    git config notes.rewriteMode concatenate
    git config --replace-all notes.rewriteRef "refs/notes/commits"

    echo "✅ Switched AI attribution to 'notes' mode."
    echo "   Commit messages will remain pristine and human-only."
    echo "   Attribution metadata will be attached to refs/notes/commits."
    echo "   Configured push/fetch refspecs, mergeStrategy (cat_sort_uniq), and rewriteRef (refs/notes/commits)."
}

cmd_ai_off() {
    git config aapp.aiAttribution none
    echo "✅ AI attribution disabled (mode: none)."
    echo "   Pure human commit authoring; no AI trailers or git notes required."
}

cmd_ai_note() {
    local is_stage=0
    local msg=""
    local msg_file=""
    local agent=""
    local vendor=""
    local model=""
    local content=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --stage)
                is_stage=1
                shift
                ;;
            --msg|--message)
                msg="$2"
                shift 2
                ;;
            --msg-file)
                msg_file="$2"
                shift 2
                ;;
            --agent)
                agent="$2"
                shift 2
                ;;
            --vendor)
                vendor="$2"
                shift 2
                ;;
            --model)
                model="$2"
                shift 2
                ;;
            --content)
                content="$2"
                shift 2
                ;;
            *)
                if [ -z "$msg" ]; then
                    msg="$1"
                fi
                shift
                ;;
        esac
    done

    if [ "$is_stage" -eq 0 ]; then
        echo "Usage: aapp ai-note --stage --msg \"<commit message>\" [options]"
        echo ""
        echo "Options:"
        echo "  --agent <name>       Agent name (e.g. Antigravity, Claude)"
        echo "  --vendor <vendor>   Vendor name (e.g. Google, Anthropic)"
        echo "  --model <model>     Model identifier (e.g. gemini-1.5-pro)"
        echo "  --content <text>    Custom note body (or pipe via stdin)"
        echo "  --msg-file <file>   Read planned commit message from file"
        exit 1
    fi

    local raw_msg="$msg"
    if [ -n "$msg_file" ] && [ -f "$msg_file" ]; then
        raw_msg="$(cat "$msg_file")"
    fi

    if [ -z "$raw_msg" ]; then
        echo "❌ Error: A commit message or --msg-file is required to key the staged note buffer." >&2
        echo "   Usage: aapp ai-note --stage --msg \"<commit message>\" ..." >&2
        exit 1
    fi

    local msg_hash
    msg_hash="$(echo "$raw_msg" | git stripspace --strip-comments 2>/dev/null | sha256sum | awk '{print $1}')"
    if [ -z "$msg_hash" ]; then
        echo "❌ Error: Failed to compute message hash." >&2
        exit 1
    fi

    local note_body="$content"
    if [ -z "$note_body" ] && [ ! -t 0 ]; then
        note_body="$(cat)"
    fi

    if [ -z "$note_body" ]; then
        local note_lines=()
        [ -n "$agent" ] && note_lines+=("AI-Agent: $agent")
        [ -n "$vendor" ] && note_lines+=("AI-Vendor: $vendor")
        [ -n "$model" ] && note_lines+=("AI-Model: $model")

        if [ ${#note_lines[@]} -eq 0 ]; then
            note_lines+=("AI-Agent: ${AAPP_AGENT_NAME:-Antigravity}")
            note_lines+=("AI-Vendor: ${AAPP_AGENT_VENDOR:-Google}")
        fi
        note_body="$(printf "%s\n" "${note_lines[@]}")"
    fi

    local note_base
    note_base="$(git rev-parse --git-path aapp_pending_note 2>/dev/null || echo ".git/aapp_pending_note")"
    local note_dir
    note_dir="$(dirname "$note_base")"
    mkdir -p "$note_dir"
    local target_buffer="${note_base}.${msg_hash}"

    printf "%s\n" "$note_body" > "$target_buffer"
    echo "✅ Staged AI note buffer for message SHA-256 ($msg_hash):"
    echo "   Buffer file: $target_buffer"
    echo "   Next commit with matching message will automatically attach this note."
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

    local repo_root
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
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
    ai-status|status)
        cmd_ai_status "$@"
        ;;
    ai-commit|commit)
        cmd_ai_commit "$@"
        ;;
    ai-notes|notes)
        cmd_ai_notes "$@"
        ;;
    ai-off|off|none)
        cmd_ai_off "$@"
        ;;
    ai-note|note)
        cmd_ai_note "$@"
        ;;
    ai-credits|credits)
        cmd_ai_credits "$@"
        ;;
    help|-h|--help)
        cat <<EOF
Usage: aapp ai-<command> [options]

AI Attribution Switchboard Commands:
  ai-status   Display current attribution mode, config, and pending notes
  ai-commit   Switch to public semantic trailers mode (commit)
  ai-notes    Switch to local-first git notes mode (notes)
  ai-off      Disable AI attribution (none)
  ai-note     Pre-stage customizable attribution note for next commit (--stage)
  ai-credits  Generate or update AI Contributors block in README.md
EOF
        ;;
    *)
        echo "❌ Unknown AI command: '$ACTION'" >&2
        echo "   Available commands: ai-status, ai-commit, ai-notes, ai-off, ai-credits, ai-note" >&2
        exit 1
        ;;
esac
