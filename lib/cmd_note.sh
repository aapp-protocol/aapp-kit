#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `note`
#
# Dedicated Git Notes engine and CLI handler.
# Governed by Plan P-44 (General-Purpose Git Notes Infrastructure).
# Supports subcommands:
#   - status: inspect remotes, strategies, guard status, and pending buffers
#   - stage:  pre-stage a hash-keyed note buffer for next commit
#   - push:   push local notes refs to configured notesRemote without force
#   - pull:   fetch remote notes and merge safely (union by default)
# ==============================================================================
set -e

ensure_note_setup() {
    # Ensure notes.rewriteRef includes both refs/notes/commits and refs/notes/ai when unset
    local existing_rewrite
    existing_rewrite="$(git config --get-all notes.rewriteRef 2>/dev/null || true)"
    if ! echo "$existing_rewrite" | grep -qx "refs/notes/commits"; then
        git config --add notes.rewriteRef "refs/notes/commits" 2>/dev/null || true
    fi
    if ! echo "$existing_rewrite" | grep -qx "refs/notes/ai"; then
        git config --add notes.rewriteRef "refs/notes/ai" 2>/dev/null || true
    fi

    # Ensure notes.displayRef includes refs/notes/ai
    local existing_display
    existing_display="$(git config --get-all notes.displayRef 2>/dev/null || true)"
    if ! echo "$existing_display" | grep -qx "refs/notes/ai"; then
        git config --add notes.displayRef "refs/notes/ai" 2>/dev/null || true
    fi

    # Default merge strategy for refs/notes/ai is union when unset
    if [ -z "$(git config --get notes.ai.mergeStrategy 2>/dev/null)" ]; then
        git config notes.ai.mergeStrategy "union" 2>/dev/null || true
    fi

    # If guard is enforce, verify and explicitly set rewriteMode concatenate
    local guard
    guard="$(git config aapp.aiNotesGuard 2>/dev/null || echo "warn")"
    if [ "$guard" = "enforce" ]; then
        if [ "$(git config --get notes.rewriteMode 2>/dev/null)" != "concatenate" ]; then
            git config notes.rewriteMode "concatenate" 2>/dev/null || true
        fi
    fi
}

cmd_note_status() {
    ensure_note_setup

    local remote
    remote="$(git config aapp.notesRemote 2>/dev/null || true)"
    local guard
    guard="$(git config aapp.aiNotesGuard 2>/dev/null || echo "warn")"

    echo "📋 AAPP Git Notes Subsystem Status"
    echo "============================================================"
    if [ -n "$remote" ]; then
        echo "  🌐 Notes Remote   : $remote"
    else
        echo "  🌐 Notes Remote   : (unset / local-first)"
    fi
    echo "  🛡️ Audit Guard    : $guard"
    echo ""
    echo "  📍 Configured Note Refs:"

    # Check commits ref
    local commits_merge
    commits_merge="$(git config notes.commits.mergeStrategy 2>/dev/null || git config notes.mergeStrategy 2>/dev/null || echo "git default (manual)")"
    echo "     • refs/notes/commits (General Notes)"
    echo "       Merge Strategy: $commits_merge"

    # Check ai ref
    local ai_merge
    ai_merge="$(git config notes.ai.mergeStrategy 2>/dev/null || git config notes.mergeStrategy 2>/dev/null || echo "union")"
    echo "     • refs/notes/ai      (AI Audit Traces)"
    echo "       Merge Strategy: $ai_merge"

    local rewrite_refs
    rewrite_refs="$(git config --get-all notes.rewriteRef 2>/dev/null | tr '\n' ' ' || true)"
    local rewrite_mode
    rewrite_mode="$(git config notes.rewriteMode 2>/dev/null || echo "concatenate (git default)")"
    echo ""
    echo "  🔄 Rewrite Config :"
    echo "     • rewriteRef   : ${rewrite_refs:-none}"
    echo "     • rewriteMode  : $rewrite_mode"

    # Audit Guard Checks for refs/notes/ai
    local guard_violations=()
    case "$ai_merge" in
        ours|theirs|cat_sort_uniq)
            guard_violations+=("Lossy merge strategy for refs/notes/ai: '$ai_merge' (may drop audit records or scramble headers).")
            ;;
    esac

    if [ "$rewrite_mode" = "ignore" ] || [ "$rewrite_mode" = "overwrite" ]; then
        guard_violations+=("Lossy rewriteMode: '$rewrite_mode' (will lose historical notes on amend/rebase).")
    fi

    if ! echo "$rewrite_refs" | grep -q "refs/notes/ai"; then
        guard_violations+=("refs/notes/ai is missing from notes.rewriteRef (amends will drop AI audit notes).")
    fi

    # Environment variable check
    if [ -n "$GIT_NOTES_REWRITE_MODE" ] && [ "$GIT_NOTES_REWRITE_MODE" != "concatenate" ]; then
        guard_violations+=("Environment override GIT_NOTES_REWRITE_MODE='$GIT_NOTES_REWRITE_MODE' is lossy.")
    fi

    if [ ${#guard_violations[@]} -gt 0 ]; then
        echo ""
        if [ "$guard" = "enforce" ]; then
            echo "❌ [Audit Guard: ENFORCE Violation]" >&2
            for v in "${guard_violations[@]}"; do
                echo "   • $v" >&2
            done
            return 1
        else
            echo "⚠️  [Audit Guard: Advisory Warning]"
            for v in "${guard_violations[@]}"; do
                echo "   • $v"
            done
        fi
    fi

    # Pending staged notes
    local note_dir
    note_dir="$(git rev-parse --git-path . 2>/dev/null || echo ".git")"
    local pending_count=0
    local pending_files=()
    if [ -d "$note_dir" ]; then
        while IFS= read -r -d '' pfile; do
            pending_files+=("$pfile")
        done < <(find "$note_dir" -maxdepth 1 -name 'aapp_pending_note.*' -print0 2>/dev/null)
        pending_count=${#pending_files[@]}
    fi

    echo ""
    echo "  📝 Staged Note Buffers: $pending_count pending"
    if [ "$pending_count" -gt 0 ]; then
        for pf in "${pending_files[@]}"; do
            local bname
            bname="$(basename "$pf")"
            local hash="${bname#aapp_pending_note.}"
            local is_ai="General"
            if grep -qE '^AI-Agent:' "$pf" 2>/dev/null; then
                is_ai="AI Trace"
            fi
            echo "     • SHA256: $hash ($is_ai)"
        done
    fi
    echo "============================================================"
    return 0
}

cmd_note_stage() {
    ensure_note_setup

    local raw_msg=""
    local msg_file=""
    local content=""
    local agent=""
    local vendor=""
    local model=""

    while [ $# -gt 0 ]; do
        case "$1" in
            msg)
                raw_msg="$2"
                shift 2
                ;;
            msg-file)
                msg_file="$2"
                shift 2
                ;;
            agent)
                agent="$2"
                shift 2
                ;;
            vendor)
                vendor="$2"
                shift 2
                ;;
            model)
                model="$2"
                shift 2
                ;;
            *)
                if [ -z "$content" ]; then
                    content="$1"
                elif [ -z "$raw_msg" ]; then
                    raw_msg="$1"
                fi
                shift
                ;;
        esac
    done

    if [ -n "$msg_file" ] && [ -f "$msg_file" ]; then
        raw_msg="$(cat "$msg_file")"
    fi

    if [ -z "$raw_msg" ]; then
        echo "❌ [Error] A planned commit message is required to key the staged note buffer." >&2
        echo "   Usage: aapp note stage \"<content>\" msg \"<commit-message>\" [agent <A> vendor <V> model <M>]" >&2
        return 1
    fi

    local msg_hash
    msg_hash="$(echo "$raw_msg" | git stripspace --strip-comments 2>/dev/null | sha256sum | awk '{print $1}')"
    if [ -z "$msg_hash" ]; then
        echo "❌ [Error] Failed to compute commit message hash." >&2
        return 1
    fi

    # Read from stdin if content is empty and stdin is piped
    if [ -z "$content" ] && [ ! -t 0 ]; then
        content="$(cat)"
    fi

    local note_body=""
    local target_ref="refs/notes/commits"

    if [ -n "$agent" ] || [ -n "$vendor" ] || [ -n "$model" ]; then
        target_ref="refs/notes/ai"
        local id_lines=()
        [ -n "$agent" ] && id_lines+=("AI-Agent: $agent")
        [ -n "$vendor" ] && id_lines+=("AI-Vendor: $vendor")
        [ -n "$model" ] && id_lines+=("AI-Model: $model")

        local header
        header="$(printf "%s\n" "${id_lines[@]}")"
        if [ -n "$content" ]; then
            note_body="X-AAPP-Ref: refs/notes/ai"$'\n'"${header}"$'\n\n'"${content}"
        else
            note_body="X-AAPP-Ref: refs/notes/ai"$'\n'"${header}"
        fi
    else
        note_body="X-AAPP-Ref: refs/notes/commits"$'\n'"${content}"
    fi

    if [ -z "$note_body" ]; then
        echo "❌ [Error] Note body content is empty." >&2
        return 1
    fi

    local note_base
    note_base="$(git rev-parse --git-path aapp_pending_note 2>/dev/null || echo ".git/aapp_pending_note")"
    local note_dir
    note_dir="$(dirname "$note_base")"
    mkdir -p "$note_dir"
    local target_buffer="${note_base}.${msg_hash}"

    printf "%s\n" "$note_body" > "$target_buffer"
    echo "✅ Staged note buffer for message SHA-256 ($msg_hash):"
    echo "   Target Ref : $target_ref"
    echo "   Buffer File: $target_buffer"
    echo "   Next commit matching this message will automatically attach this note."
}

cmd_note_push() {
    ensure_note_setup

    local target_remote="${1:-$(git config aapp.notesRemote 2>/dev/null || true)}"
    if [ -z "$target_remote" ]; then
        echo "❌ [Error] No notes remote configured." >&2
        echo "   Set 'aapp.notesRemote' (e.g. 'git config aapp.notesRemote origin') or pass [remote] explicitly." >&2
        return 1
    fi

    local refs_to_push=()
    if git rev-parse --verify refs/notes/commits >/dev/null 2>&1; then
        refs_to_push+=("refs/notes/commits")
    fi
    if git rev-parse --verify refs/notes/ai >/dev/null 2>&1; then
        refs_to_push+=("refs/notes/ai")
    fi

    if [ ${#refs_to_push[@]} -eq 0 ]; then
        echo "ℹ️  No local notes refs (refs/notes/commits or refs/notes/ai) exist to push."
        return 0
    fi

    echo "🚀 Pushing notes to '$target_remote' (${refs_to_push[*]})..."
    git push "$target_remote" "${refs_to_push[@]}"
    echo "✨ Notes pushed successfully."
}

cmd_note_pull() {
    ensure_note_setup

    local target_remote="${1:-$(git config aapp.notesRemote 2>/dev/null || true)}"
    if [ -z "$target_remote" ]; then
        echo "❌ [Error] No notes remote configured." >&2
        echo "   Set 'aapp.notesRemote' (e.g. 'git config aapp.notesRemote origin') or pass [remote] explicitly." >&2
        return 1
    fi

    echo "📥 Fetching notes from '$target_remote'..."
    # Fetch into isolated tracking refs
    git fetch "$target_remote" \
        "+refs/notes/commits:refs/notes/remote/$target_remote/commits" \
        "+refs/notes/ai:refs/notes/remote/$target_remote/ai" 2>/dev/null || true

    for ref in commits ai; do
        local remote_ref="refs/notes/remote/$target_remote/$ref"
        if git rev-parse --verify "$remote_ref" >/dev/null 2>&1; then
            local local_ref="refs/notes/$ref"
            local strat
            if [ "$ref" = "ai" ]; then
                strat="$(git config notes.ai.mergeStrategy 2>/dev/null || git config notes.mergeStrategy 2>/dev/null || echo "union")"
            else
                strat="$(git config notes.commits.mergeStrategy 2>/dev/null || git config notes.mergeStrategy 2>/dev/null || echo "union")"
            fi

            echo "  🔄 Merging $ref (strategy: $strat)..."
            if ! git rev-parse --verify "$local_ref" >/dev/null 2>&1; then
                # Local ref does not exist yet; initialize directly from remote
                local remote_sha
                remote_sha="$(git rev-parse "$remote_ref")"
                git update-ref "$local_ref" "$remote_sha"
                echo "     • Initialized $local_ref from $remote_ref"
            else
                if [ "$strat" = "manual" ]; then
                    if ! git notes --ref="$local_ref" merge "$remote_ref"; then
                        echo "❌ [Error] Merge conflict in $local_ref." >&2
                        echo "   👉 Resolve conflict with 'git notes merge --commit' or abort with 'git notes merge --abort'." >&2
                        return 1
                    fi
                else
                    git notes --ref="$local_ref" merge -s "$strat" "$remote_ref"
                fi
            fi
        fi
    done
    echo "✨ Notes pulled and merged successfully."
}

cmd_note() {
    local subcmd="${1:-status}"
    shift || true

    case "$subcmd" in
        status)
            cmd_note_status "$@"
            ;;
        stage)
            cmd_note_stage "$@"
            ;;
        push)
            cmd_note_push "$@"
            ;;
        pull)
            cmd_note_pull "$@"
            ;;
        help|-h|--help)
            echo "Usage: aapp note [status | stage | push | pull]"
            echo ""
            echo "Manage general developer notes and AI audit traces."
            echo ""
            echo "Commands:"
            echo "  status                       Display notes remote, merge strategies, and pending buffers"
            echo "  stage \"<text>\" [options]     Pre-stage a note buffer for the next commit"
            echo "  push [remote]                Push notes refs (refs/notes/commits, refs/notes/ai) to remote"
            echo "  pull [remote]                Fetch and merge remote notes safely (union default)"
            echo ""
            echo "Stage Options:"
            echo "  msg \"<commit-message>\"       Planned commit message (required to key the buffer)"
            echo "  agent <name>                 AI Agent name (targets refs/notes/ai)"
            echo "  vendor <vendor>              AI Vendor name"
            echo "  model <model>                AI Model identifier"
            echo ""
            echo "Configuration:"
            echo "  git config aapp.notesRemote <remote>     Set remote for notes push/pull (unset = local only)"
            echo "  git config aapp.aiNotesGuard warn|enforce Audit guard level (default: warn)"
            ;;
        *)
            echo "❌ [Error] Unknown note command: '$subcmd'" >&2
            echo "   Usage: aapp note [status | stage | push | pull]" >&2
            return 1
            ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    cmd_note "$@"
fi
