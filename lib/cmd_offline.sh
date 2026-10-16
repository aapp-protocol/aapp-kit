#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `offline` (P-75)
#
# The `.offline` worktree: an orphan branch `offline`, never pushed, where
# issues and draft plans are staged while the team's provider is unreachable.
#   aapp offline mount            create or mount the worktree
#   aapp offline unmount [force]  remove it (refused while anything is staged)
#   aapp offline on | off         skip the provider entirely / go back to asking it
#   aapp offline status           what is staged
#   aapp offline sync             publish what is staged, once the provider answers
#
# Offline rows keep the ledgers' format and are written by the ledger functions
# of lib/aapp-lib.sh, pointed at `.offline` (ledger_use_offline). An offline id
# is temporary: at sync the issue gets its real id, references in the plans are
# rewritten, and the former id stays resolvable; commits are never rewritten.
# ==============================================================================

AAPP_OFFLINE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/cmd_issue.sh
if ! declare -f cmd_issue >/dev/null; then
    . "$AAPP_OFFLINE_LIB_DIR/cmd_issue.sh" || {
        echo "❌ [Offline] Cannot load $AAPP_OFFLINE_LIB_DIR/cmd_issue.sh" >&2
        exit 1
    }
fi

# offline_mode -> `off` (aapp.offlineEnabled false: a failing provider refuses),
# `only` (aapp.offlineOnly true: the provider is not asked at all), else `on`
# (the provider is asked first; a failure or a timeout stages offline).
offline_mode() {
    if [ "$(git config --get aapp.offlineEnabled 2>/dev/null)" = "false" ]; then echo off; return 0; fi
    if [ "$(git config --get aapp.offlineOnly 2>/dev/null)" = "true" ]; then echo only; return 0; fi
    echo on
}

# offline_mount [quiet]: the worktree on orphan branch `offline`, its ledgers,
# and `.offline/` in .git/info/exclude (no commit on any shared branch).
offline_mount() {
    local d common exclude tree commit quiet="${1:-}"
    d="$(offline_dir)" || { echo "❌ [Offline] Not inside a Git repository." >&2; return 1; }
    common="$(git rev-parse --git-common-dir)"; case "$common" in /*) ;; *) common="$(cd "$common" && pwd)" ;; esac
    exclude="$common/info/exclude"
    mkdir -p "$(dirname "$exclude")" || return 1
    grep -qxF '.offline/' "$exclude" 2>/dev/null || echo '.offline/' >> "$exclude"
    if [ -e "$d/.git" ]; then
        [ -n "$quiet" ] || echo "ℹ️  [Offline] .offline is already mounted."
    elif [ -e "$d" ]; then
        echo "❌ [Offline] '$d' exists and is not the offline worktree; move it away first." >&2
        return 1
    else
        if ! git show-ref --verify --quiet refs/heads/offline; then
            tree="$(git hash-object -t tree /dev/null)" || return 1
            commit="$(git commit-tree "$tree" -m "chore: initialize orphan offline branch")" || return 1
            git branch offline "$commit" >/dev/null || return 1
        fi
        git worktree add -q "$d" offline >/dev/null 2>&1 || { echo "❌ [Offline] Could not mount .offline on branch 'offline'." >&2; return 1; }
        [ -n "$quiet" ] || echo "📡 [Offline] Mounted .offline on branch 'offline' (never pushed)."
    fi
    mkdir -p "$d/current" "$d/done" || return 1
    ( ledger_use_offline && ledger_ensure_files ) || return 1
    [ -f "$d/outbox" ] || : > "$d/outbox"
    offline_commit "chore: offline worktree" >/dev/null
    return 0
}

# offline_commit <subject>: the offline worktree's own history: an audit trail
# of what was logged, fixed and closed offline. Hooks guard the shared
# branches, not this one.
offline_commit() {
    local d
    d="$(offline_dir)" || return 1
    [ -e "$d/.git" ] || return 0
    git -C "$d" add -A >/dev/null 2>&1 || return 1
    git -C "$d" diff --cached --quiet && return 0
    git -C "$d" -c commit.gpgsign=false commit -q --no-verify -m "$1" >/dev/null 2>&1
}

# offline_keep_closed_row <n>: before an offline issue's row leaves the offline
# backlog for the offline archive, the row is kept as it was: the archive holds
# no symptom, and the tracker gets the whole issue at the sync.
offline_keep_closed_row() {
    local d row
    d="$(offline_dir)" || return 0
    row="$(ledger_row "$1")" || return 0
    printf '%s\n' "$row" >> "$d/closed.rows"
}

# offline_next_issue_id -> the next temporary issue number: one more than the
# highest offline id; for the first one, the highest id in the main ledgers
# plus aapp.offlineIdOffset (default 1000), far from what colleagues may log.
offline_next_issue_id() {
    local max offset root seed
    max="$( { ledger_offline_ids active; ledger_offline_ids archive; } | grep -E '^[0-9]+$' | sort -n | tail -n 1)"
    if [ -n "$max" ]; then echo $((max + 1)); return 0; fi
    offset="$(git config --get aapp.offlineIdOffset 2>/dev/null)" || offset=1000
    case "$offset" in ''|*[!0-9]*) offset=1000 ;; esac
    root="$(cd "$(offline_dir)/.." && pwd)"
    seed="$(seed_issue_id "$root/.plans" 2>/dev/null)" || seed=1
    echo $((seed - 1 + offset))
}

# offline_next_plan_id -> the same rule for a draft plan's temporary number.
offline_next_plan_id() {
    local d max offset root known counter
    d="$(offline_dir)"
    max="$(ls "$d/current" 2>/dev/null | sed -nE 's/^P([0-9]+)-.*/\1/p' | sort -n | tail -n 1)"
    if [ -n "$max" ]; then echo $((max + 1)); return 0; fi
    offset="$(git config --get aapp.offlineIdOffset 2>/dev/null)" || offset=1000
    case "$offset" in ''|*[!0-9]*) offset=1000 ;; esac
    root="$(cd "$d/.." && pwd)"
    known="$(ls "$root/.plans/current" "$root/.plans/done" "$root/.plans/aborted" 2>/dev/null | sed -nE 's/^P([0-9]+)-.*/\1/p' | sort -n | tail -n 1)"
    counter="$(git config --get aapp.planId 2>/dev/null)" || counter=1
    case "$counter" in ''|*[!0-9]*) counter=1 ;; esac
    [ "${known:-0}" -ge $((counter - 1)) ] || known=$((counter - 1))
    echo $(( ${known:-0} + offset ))
}

# offline_staged -> what is staged, one line each: `issue #<n>`, `closed #<n>`,
# `plan <file>`, `step <step> #<n>`.
offline_staged() {
    local d n f
    offline_mounted || return 0
    d="$(offline_dir)"
    for n in $(ledger_offline_ids active); do echo "issue #$n"; done
    for n in $(ledger_offline_ids archive); do echo "closed #$n"; done
    for f in "$d"/current/P*.md; do [ -f "$f" ] && echo "plan $(basename "$f")"; done
    [ -s "$d/outbox" ] && awk -F'\t' 'NF >= 2 { print "step " $1 " #" $2 }' "$d/outbox"
    return 0
}

cmd_offline_unmount() {
    local d staged force=0
    [ "${1:-}" = "force" ] && force=1
    d="$(offline_dir)" || return 1
    if [ ! -e "$d/.git" ]; then echo "ℹ️  [Offline] .offline is not mounted."; return 0; fi
    staged="$(offline_staged)"
    if [ -n "$staged" ] && [ "$force" -eq 0 ]; then
        echo "❌ [Offline] .offline still holds what was not published:" >&2
        printf '%s\n' "$staged" | sed 's/^/   /' >&2
        echo "   Publish it with 'aapp offline sync', or unmount anyway with 'aapp offline unmount force' (the branch 'offline' keeps it)." >&2
        return 1
    fi
    offline_commit "chore: before unmount" >/dev/null
    git worktree remove --force "$d" >/dev/null 2>&1 || { echo "❌ [Offline] Could not remove .offline." >&2; return 1; }
    echo "📡 [Offline] .offline unmounted${staged:+; branch 'offline' keeps what was staged}."
}

cmd_offline_status() {
    local d staged
    if ! offline_mounted; then echo "📡 [Offline] .offline is not mounted. Mode: $(offline_mode)."; return 0; fi
    d="$(offline_dir)"
    staged="$(offline_staged)"
    echo "📡 [Offline] .offline is mounted. Mode: $(offline_mode)."
    if [ -z "$staged" ]; then echo "   Nothing is staged."; return 0; fi
    ( ledger_use_offline; ledger_row_lines ) | sed 's/^/   /'
    printf '%s\n' "$staged" | grep -v '^issue ' | sed 's/^/   /'
    echo "   Publish with 'aapp offline sync' when the provider answers."
}

# _offline_rewrite_id <old> <new> <file>…: `#<old>` becomes `#<new>` wherever
# it stands as an id (not as the start of a longer one).
_offline_rewrite_id() {
    local old="$1" new="$2" f
    shift 2
    for f in "$@"; do
        [ -f "$f" ] || continue
        grep -qF "#$old" "$f" || continue
        sed -i -E "s/#${old}([^A-Za-z0-9-]|\$)/#${new}\\1/g" "$f"
    done
}

# _offline_plan_files <plans>: the files where an issue's id is referenced.
_offline_plan_files() {
    local d
    d="$(offline_dir)"
    ls "$1"/current/*.md "$d"/current/*.md 2>/dev/null
}

# _offline_sync_issue <plans> <n> active|archive: one staged issue gets its
# real id: the `log` step, with its description and notes; then, for one closed
# or withdrawn offline, `close` or `abort`. Returns 1 when it stays staged.
_offline_sync_issue() {
    local plans="$1" n="$2" where="$3" d oi oa cells row members text real raw commit summary orig
    d="$(offline_dir)"; oi="$(_ledger_offline_path issues)"; oa="$(_ledger_offline_path archive)"
    if [ "$where" = "active" ]; then
        cells="$(AAPP_LEDGER_ISSUES="$oi" ledger_rows | awk -F'\t' -v id="#$n" '$1 == id { print; exit }')"
        members="$(_issue_members "" "$(printf '%s' "$cells" | cut -f2)" "$(printf '%s' "$cells" | cut -f3)" "$(printf '%s' "$cells" | cut -f4)" \
            "$(printf '%s' "$cells" | cut -f5)" "$(printf '%s' "$cells" | cut -f6)" "$(printf '%s' "$cells" | cut -f7)" \
            "$(printf '%s' "$cells" | cut -f8)" "$(AAPP_LEDGER_ISSUES="$oi" AAPP_LEDGER_ARCHIVE="$d/none" ledger_branch "$n")")"
    else
        row="$(grep -m 1 -E "$(_ledger_row_regex "$n")" "$oa")"
        cells="$(printf '%s\n' "$row" | sed 's/\\|/\x01/g' | awk -F'|' '{ for (i = 2; i <= 8; i++) { gsub(/^[ \t]+|[ \t]+$/, "", $i); printf "%s\t", $i } print "" }' | sed 's/\x01/\\|/g')"
        commit="$(printf '%s' "$cells" | cut -f6 | tr -d '`')"; summary="$(printf '%s' "$cells" | cut -f7)"
        # The archive keeps no symptom: the row as it was when it left the
        # offline backlog is beside it (offline_keep_closed_row).
        orig="$(grep -m 1 -E "$(_ledger_row_regex "$n")" "$d/closed.rows" 2>/dev/null | sed 's/\\|/\x01/g' | awk -F'|' '{ for (i = 2; i <= 9; i++) { gsub(/^[ \t]+|[ \t]+$/, "", $i); printf "%s\t", $i } print "" }' | sed 's/\x01/\\|/g')"
        if [ -n "$orig" ]; then
            members="$(_issue_members "" "$(printf '%s' "$orig" | cut -f2)" "$(printf '%s' "$orig" | cut -f3)" "$(printf '%s' "$orig" | cut -f4)" "$(printf '%s' "$orig" | cut -f5)" "$(printf '%s' "$orig" | cut -f6)" "" "closed offline")"
        else
            members="$(_issue_members "" "$(printf '%s' "$cells" | cut -f2)" "$(printf '%s' "$cells" | cut -f3)" "$(printf '%s' "$cells" | cut -f4)" "—" "$summary" "" "closed offline")"
        fi
    fi
    # The whole text travels with the issue: what was written while offline.
    text="$(issue_text_get "$n")" || text=""
    [ -z "$text" ] || members="$members, \"description\": \"$(json_escape "$(printf '%s\n' "$text" | awk '/^\[description\]$/ { on = 1; next } /^\[note / { on = 0 } on')")\", \"notes\": [$(printf '%s\n' "$text" | awk '
        /^\[note / { if (cur != "") out = out (out == "" ? "" : "\037") cur; cur = substr($0, 7, length($0) - 7) ":"; next }
        /^\[description\]$/ { skip = 1; next }
        cur != "" && NF { cur = cur " " $0 }
        END { if (cur != "") out = out (out == "" ? "" : "\037") cur; print out }' | tr '\037' '\n' | while IFS= read -r raw; do [ -n "$raw" ] && printf '"%s"\n' "$(json_escape "$raw")"; done | paste -sd, -)]"
    if ! issue_provider log "$members"; then
        echo "⚠️  [Offline] #$n stays staged: aapp-issue-tracker failed on it (${PLUGIN_MESSAGE:-no answer})."
        return 1
    fi
    if [ "$ISSUE_PROVIDER_SEEN" -eq 1 ] && [ "$PLUGIN_STATUS" = "ok" ]; then
        raw="$(json_field "$PLUGIN_OUT" id 2>/dev/null)" || { echo "⚠️  [Offline] #$n stays staged: aapp-issue-tracker answered without an id."; return 1; }
        real="$(issue_id_body "$raw")" || return 1
        if [ -n "$(PLANS_DIR="$plans" ledger_locate "$real")" ]; then echo "⚠️  [Offline] #$n stays staged: #$real is already an issue here."; return 1; fi
        _issue_meta_from_answer "$real" "$PLUGIN_OUT"
        _plugin_files_drop
    else
        if [ "$ISSUE_PROVIDER_SEEN" -eq 1 ] && PLANS_DIR="$plans" ledger_record_external; then
            echo "⚠️  [Offline] #$n stays staged: aapp-issue-tracker did not take it, and the tracker keeps the record."
            return 1
        fi
        real="$(allocate_issue_id)" || return 1
        real="${real#\#}"
    fi
    PLANS_DIR="$plans" ledger_ensure_files || return 1
    if [ "$where" = "active" ]; then
        row="$(grep -m 1 -E "$(_ledger_row_regex "$n")" "$oi" | sed -E "s/^([[:space:]]*\|[[:space:]]*\`?)#$n(\`?[[:space:]]*\|)/\1#$real\2/")"
        PLANS_DIR="$plans" ledger_add_row "$row" || return 1
        # P-89: an issue queued while offline stays queued, under its real id.
        local qlv qday
        qlv="$( ledger_use_offline; roadmap_queue_level "$n" )"
        if [ -n "$qlv" ]; then
            qday="$( ledger_use_offline; roadmap_queue_date "$n" )"
            PLANS_DIR="$plans" roadmap_queue_add "$real" "$(printf '%s' "$cells" | cut -f6)" "$qlv" "$qday"
            _issue_step queue "$real" "\"id\": \"#$real\", \"priority\": \"$qlv\""
        fi
        ( ledger_use_offline; ledger_drop_row "$n" )
    else
        row="| #$real | $(printf '%s' "$cells" | cut -f2) | $(printf '%s' "$cells" | cut -f3) | $(printf '%s' "$cells" | cut -f4) | $(printf '%s' "$cells" | cut -f5) | \`$commit\` | $summary; logged offline as #$n |"
        row="$(_ledger_pad_row "$(PLANS_DIR="$plans" ledger_path archive)" "$row")"
        AAPP_ROW="$row" awk '{ print } !d && /^\|[[:space:]]*:---/ { print ENVIRON["AAPP_ROW"]; d = 1 }' "$(PLANS_DIR="$plans" ledger_path archive)" > "$d/.archive.tmp" && \
            cat "$d/.archive.tmp" > "$(PLANS_DIR="$plans" ledger_path archive)"
        rm -f "$d/.archive.tmp"
        grep -v -E "$(_ledger_row_regex "$n")" "$oa" > "$d/.archive.tmp" || [ $? -eq 1 ]
        mv "$d/.archive.tmp" "$oa"
        # The tracker learns how it ended, with the id the commits name.
        if [ "$commit" = "aborted" ]; then
            _issue_step abort "$real" "\"id\": \"#$real\", \"reason\": \"$(json_escape "$summary; logged offline as #$n")\""
        else
            issue_notify_close "$real" "$commit" "$summary; logged offline as #$n" "" "\"id\": \"#$real\"" >/dev/null
        fi
        if [ -f "$d/closed.rows" ]; then
            grep -v -E "$(_ledger_row_regex "$n")" "$d/closed.rows" > "$d/.rows.tmp" || [ $? -eq 1 ]
            mv "$d/.rows.tmp" "$d/closed.rows"
        fi
    fi
    # shellcheck disable=SC2046
    _offline_rewrite_id "$n" "$real" $(_offline_plan_files "$plans") "$(PLANS_DIR="$plans" ledger_path roadmap)"
    issue_text_rename "$n" "$real"
    ledger_alias_add "$n" "$real"
    echo "   #$n is now #$real."
}

# _offline_sync_plan <plans> <draft>: a draft made while the plan-id provider
# was unreachable gets its real id; its file is renamed, its references follow.
_offline_sync_plan() {
    local plans="$1" f="$2" d b temp slug pid num today new
    d="$(offline_dir)"
    b="$(basename "$f" .md)"; temp="$(printf '%s' "$b" | sed -nE 's/^P([0-9]+)-.*/\1/p')"; slug="${b#P"$temp"-}"
    pid="$(allocate_plan_id)" || { echo "⚠️  [Offline] $b stays staged: no plan id could be had."; return 1; }
    num="${pid#P-}"
    new="P$num-$slug.md"
    if [ -e "$plans/current/$new" ]; then echo "⚠️  [Offline] $b stays staged: current/$new exists."; return 1; fi
    sed -i -E "s/P-$temp([^0-9]|\$)/P-$num\\1/g; s/P$temp-$slug/P$num-$slug/g" "$f"
    today="$(date +%Y-%m-%d)"
    if grep -q '^## 📦 6\. Change Log' "$f"; then
        sed -i -E "/^## 📦 6\. Change Log.*/a \* \*\*$today:\*\* Plan drafted offline as P-$temp." "$f"
    fi
    mv "$f" "$plans/current/$new" || return 1
    # Whatever named the temporary plan id names the real one.
    for b in "$plans"/current/*.md "$d"/current/*.md "$(PLANS_DIR="$plans" ledger_path issues)" "$(PLANS_DIR="$plans" ledger_path roadmap)"; do
        [ -f "$b" ] || continue
        [ "$b" = "$plans/current/$new" ] && continue
        grep -qE "P-?$temp" "$b" || continue
        sed -i -E "s/P-$temp([^0-9]|\$)/P-$num\\1/g; s/P$temp-$slug/P$num-$slug/g" "$b"
    done
    echo "   P-$temp is now P-$num (current/$new)."
}

cmd_offline_sync() {
    local plans d n f left=0 ids paths=() p
    if ! offline_mounted; then echo "ℹ️  [Offline] Nothing is staged: .offline is not mounted."; return 0; fi
    if [ "$(offline_mode)" = "only" ]; then
        echo "❌ [Offline] Offline-only mode is on: the provider is not asked. Run 'aapp offline off' first." >&2
        return 1
    fi
    plans="$(_issue_plans_dir)" || return 1
    _issue_load_plan_lib || return 1
    d="$(offline_dir)"
    echo "📡 [Offline] Publishing what is staged in .offline…"
    # 1. Steps that could not be sent, in the order they happened.
    issue_outbox_flush || { left=1; echo "⚠️  [Offline] Steps remain in the outbox; they are sent first at the next sync."; }
    # 2. Staged issues, in the order they were logged.
    ids="$( { ledger_offline_ids active | sed 's/$/ active/'; ledger_offline_ids archive | sed 's/$/ archive/'; } | sort -n)"
    while read -r n f; do
        [ -n "$n" ] || continue
        _offline_sync_issue "$plans" "$n" "$f" || left=1
    done <<< "$ids"
    # 3. Draft plans.
    for f in "$d"/current/P*.md; do
        [ -f "$f" ] || continue
        _offline_sync_plan "$plans" "$f" || left=1
    done
    sync_state_matrix
    # 4. What is committed depends on where the record is: the ledgers too, or
    #    (the tracker keeping the record) only the plans.
    while IFS= read -r p; do
        p="${p#?? }"; p="${p#\"}"; p="${p%\"}"
        [ -n "$p" ] && paths+=("$p")
    done < <(git -C "$plans" status --porcelain --untracked-files=all -- current state_matrix.md $(PLANS_DIR="$plans" ledger_commit_paths) 2>/dev/null | sed -E 's/^(..) /\1 /')
    if [ ${#paths[@]} -gt 0 ]; then
        PLANS_DIR="$plans" plans_commit "offline(sync): publish what was staged offline" "${paths[@]}" || return 1
    fi
    offline_commit "offline(sync): published" >/dev/null
    if [ "$left" -eq 0 ] && [ -z "$(offline_staged)" ]; then
        echo "✅ [Offline] Everything staged is published. Unmount with 'aapp offline unmount'."
    else
        echo "ℹ️  [Offline] Still staged:"; offline_staged | sed 's/^/   /'
    fi
    return 0
}

cmd_offline() {
    local sub="${1:-status}"
    [ $# -gt 0 ] && shift
    case "$sub" in
        mount)   offline_mount ;;
        unmount) cmd_offline_unmount "$@" ;;
        on)      git config aapp.offlineOnly true && echo "📡 [Offline] Offline-only: the provider is not asked; issues and plans are staged in .offline. 'aapp offline off' ends it." ;;
        off)     git config --unset aapp.offlineOnly 2>/dev/null; echo "📡 [Offline] The provider is asked again. Publish what is staged with 'aapp offline sync'." ;;
        status)  cmd_offline_status ;;
        sync)    cmd_offline_sync ;;
        *)
            echo "❌ [Offline] Unknown subcommand '$sub'." >&2
            echo "Usage: aapp offline [mount | unmount [force] | on | off | status | sync]" >&2
            return 1 ;;
    esac
}
