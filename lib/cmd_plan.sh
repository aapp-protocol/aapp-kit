#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `active`, `plan-status`, `plan`, `start`, `freeze-start`
#
# Multi-Agent Planning Switchboard & Active Execution Buffer Manager
# ==============================================================================
set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
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

ACTIVE_FILE="$(git rev-parse --git-path aapp_active_plan 2>/dev/null || echo ".git/aapp_active_plan")"
PREV_FILE="$(git rev-parse --git-path aapp_active_plan.prev 2>/dev/null || echo ".git/aapp_active_plan.prev")"

# Source plan resolver for shorthand resolution if available
if [ -f "$AAPP_LIB/plan_resolver.sh" ]; then
    source "$AAPP_LIB/plan_resolver.sh"
elif [ -f "$PRIMARY_ROOT/lib/plan_resolver.sh" ]; then
    source "$PRIMARY_ROOT/lib/plan_resolver.sh"
elif [ -f "$REPO_ROOT/lib/plan_resolver.sh" ]; then
    source "$REPO_ROOT/lib/plan_resolver.sh"
fi

resolve_plan_file() {
    local query="$1"
    local verb="${2:-inspect}"

    if [ -z "$PLANS_DIR" ] || [ ! -d "$PLANS_DIR/current" ]; then
        echo "❌ [Plan Switchboard] .plans/current directory not found." >&2
        return 1
    fi

    if [ -z "$query" ]; then
        echo "❌ [Plan Switchboard] You must specify a target plan for '$verb'." >&2
        return 1
    fi

    if declare -f resolve_plan_path >/dev/null 2>&1; then
        local rel_path
        rel_path=$(resolve_plan_path "$query" "$verb" current "$PRIMARY_ROOT" 2>/dev/null || true)
        if [ -n "$rel_path" ] && [ -f "$PRIMARY_ROOT/$rel_path" ]; then
            echo "$PRIMARY_ROOT/$rel_path"
            return 0
        fi
    fi

    # Fallback resolution
    for pf in "$PLANS_DIR"/current/*.md; do
        [ ! -f "$pf" ] && continue
        case "$(basename "$pf")" in 000-*) continue ;; esac
        local pid bname
        pid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" 2>/dev/null || true)"
        bname="$(basename "$pf" .md)"
        if [ "$query" = "$pid" ] || [ "$query" = "$bname" ] || \
           [[ "$bname" == "$query-"* ]] || [[ "$bname" == "P$query-"* ]] || \
           [[ "$bname" == "P-$query-"* ]]; then
            echo "$pf"
            return 0
        fi
    done

    echo "❌ [Plan Switchboard] Plan '$query' not found in $PLANS_DIR/current/." >&2
    return 1
}

parse_plan_target_paths() {
    local file="$1"
    awk '
        /^### 📂 Target Files/ { flag=1; next }
        (/^### 🛑 Out of Bounds/ || /^## /) && flag { flag=0 }
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

check_disjointness_activation_gate() {
    local target_plan="$1"
    local target_bname
    target_bname="$(basename "$target_plan")"

    local my_targets=()
    while IFS= read -r t; do
        [ -n "$t" ] && my_targets+=("$t")
    done < <(parse_plan_target_paths "$target_plan")

    [ ${#my_targets[@]} -eq 0 ] && return 0

    for pf in "$PLANS_DIR"/current/*.md; do
        [ ! -f "$pf" ] && continue
        [ "$(basename "$pf")" = "$target_bname" ] && continue
        case "$(basename "$pf")" in 000-*) continue ;; esac

        if grep -qE '^[[:space:]]*[\*|-]*[[:space:]]*\*\*Status:\*\*[[:space:]]*.*(⚡|🟠|In Development)' "$pf" 2>/dev/null; then
            local other_targets=()
            while IFS= read -r ot; do
                [ -n "$ot" ] && other_targets+=("$ot")
            done < <(parse_plan_target_paths "$pf")

            for mt in "${my_targets[@]}"; do
                for ot in "${other_targets[@]}"; do
                    if [ "$mt" = "$ot" ]; then
                        echo "❌ [Activation Gate] Cannot activate $(basename "$target_plan" .md):" >&2
                        echo "   Shares Target File '$mt' with in-flight plan '$(basename "$pf" .md)'!" >&2
                        echo "   Finish '$(basename "$pf" .md)' first or isolate on a separate git worktree/branch." >&2
                        return 1
                    fi
                done
            done
        fi
    done

    return 0
}

write_active_buffer() {
    local plan_id="$1"
    mkdir -p "$(dirname "$ACTIVE_FILE")"
    if [ -f "$ACTIVE_FILE" ]; then
        local cur
        cur="$(head -n 1 "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')"
        if [ -n "$cur" ] && [ "$cur" != "$plan_id" ]; then
            echo "$cur" > "$PREV_FILE"
        fi
    fi
    echo "$plan_id" > "$ACTIVE_FILE"
}

cmd_freeze_start() {
    local query="$1"
    local plan_file
    plan_file="$(resolve_plan_file "$query" "freeze-start")" || exit 1

    # Verify Open Questions
    local unresolved_q
    unresolved_q=$(awk '
        /^## ❓ 5\. Open Questions/ { in_q=1; next }
        /^## / && in_q { in_q=0 }
        in_q && /^[[:space:]]*\*[[:space:]]*\[[[:space:]]\]/ { print $0 }
    ' "$plan_file")

    if [ -n "$unresolved_q" ]; then
        echo "❌ [Freeze-Start Refusal] Plan has unresolved open questions in ## ❓ 5. Open Questions:" >&2
        echo "$unresolved_q" | sed 's/^/     /' >&2
        echo "   All open questions must be resolved and checked off ([x]) before freeze-start." >&2
        exit 1
    fi

    # Verify Target Files declared
    local targets
    targets="$(parse_plan_target_paths "$plan_file")"
    if [ -z "$targets" ]; then
        echo "❌ [Freeze-Start Refusal] Plan declares no Target Files under '### 📂 Target Files'." >&2
        exit 1
    fi

    # Disjointness check
    check_disjointness_activation_gate "$plan_file" || exit 1

    local plan_id
    plan_id="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$plan_file" 2>/dev/null || true)"
    [ -z "$plan_id" ] && plan_id="$(basename "$plan_file" .md)"

    # Update plan header & lock status
    sed -i -E 's/^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*.*/\* \*\*Status:\*\* ⚡ In Development/' "$plan_file"
    sed -i -E 's/\*\(Marked:[[:space:]]*\*\*PROPOSED\*\*.*\)/\*(Marked: **LOCKED** — Greenlit for implementation)*/' "$plan_file"

    local today
    today="$(date +%Y-%m-%d)"
    if grep -q '^## 📦 6\. Change Log' "$plan_file"; then
        sed -i -E "/^## 📦 6\. Change Log.*/a \* \*\*$today:\*\* Plan frozen and activated into ⚡ In Development via freeze-start." "$plan_file"
    fi

    # Update state matrix if present
    local sm_file="$PLANS_DIR/state_matrix.md"
    if [ -f "$sm_file" ]; then
        sed -i -E "/$plan_id/s/🔴|🟡|🟢|🟣|🔷|🟠/⚡/g" "$sm_file"
    fi

    # Write buffer
    write_active_buffer "$plan_id"

    # Commit transition in plans worktree if available
    if [ -d "$PLANS_DIR/.git" ] || git -C "$PLANS_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        git -C "$PLANS_DIR" add "current/$(basename "$plan_file")" 2>/dev/null || true
        [ -f "$sm_file" ] && git -C "$PLANS_DIR" add "state_matrix.md" 2>/dev/null || true
        git -C "$PLANS_DIR" commit -m "plan(start): freeze and activate $plan_id into development" 2>/dev/null || true
    fi

    echo "⚡ [Freeze-Start] Plan '$plan_id' frozen and activated into ⚡ In Development."
    echo "   Blueprint    : $plan_file"
    echo "   Active Buffer: $ACTIVE_FILE"
}

cmd_start() {
    local query="$1"
    local plan_file
    plan_file="$(resolve_plan_file "$query" "start")" || exit 1

    # Verify status is 🟢 Frozen / Ready for Execution or already 🟠
    local cur_status
    cur_status="$(grep -E '^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*' "$plan_file" | head -n 1 || true)"
    if ! echo "$cur_status" | grep -qE '🟢|🔷|Ready for Execution|Frozen|⚡|🟠|In Development'; then
        echo "❌ [Start Refusal] Plan is not frozen (current status: $cur_status)." >&2
        echo "   Freeze the plan first with 'aapp freeze $query' or run 'aapp freeze-start $query'." >&2
        exit 1
    fi

    # Disjointness check
    check_disjointness_activation_gate "$plan_file" || exit 1

    local plan_id
    plan_id="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$plan_file" 2>/dev/null || true)"
    [ -z "$plan_id" ] && plan_id="$(basename "$plan_file" .md)"

    # Update status
    sed -i -E 's/^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*.*/\* \*\*Status:\*\* ⚡ In Development/' "$plan_file"
    sed -i -E 's/\*\(Marked:[[:space:]]*\*\*PROPOSED\*\*.*\)/\*(Marked: **LOCKED** — Greenlit for implementation)*/' "$plan_file"

    local today
    today="$(date +%Y-%m-%d)"
    if grep -q '^## 📦 6\. Change Log' "$plan_file"; then
        sed -i -E "/^## 📦 6\. Change Log.*/a \* \*\*$today:\*\* Plan activated into ⚡ In Development via start." "$plan_file"
    fi

    local sm_file="$PLANS_DIR/state_matrix.md"
    if [ -f "$sm_file" ]; then
        sed -i -E "/$plan_id/s/🔴|🟡|🟢|🟣|🔷|🟠/⚡/g" "$sm_file"
    fi

    write_active_buffer "$plan_id"

    if [ -d "$PLANS_DIR/.git" ] || git -C "$PLANS_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        git -C "$PLANS_DIR" add "current/$(basename "$plan_file")" 2>/dev/null || true
        [ -f "$sm_file" ] && git -C "$PLANS_DIR" add "state_matrix.md" 2>/dev/null || true
        git -C "$PLANS_DIR" commit -m "plan(start): activate $plan_id into development" 2>/dev/null || true
    fi

    echo "⚡ [Start] Plan '$plan_id' activated into ⚡ In Development."
    echo "   Active Buffer: $ACTIVE_FILE"
}

cmd_active() {
    local sub="$1"
    case "$sub" in
        swap)
            if [ ! -f "$PREV_FILE" ]; then
                echo "ℹ️  No previous active plan found to swap to."
                return 0
            fi

            local prev_val cur_val
            prev_val="$(head -n 1 "$PREV_FILE" 2>/dev/null | tr -d '[:space:]')"
            cur_val="$(head -n 1 "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]' || true)"

            if [ -z "$prev_val" ]; then
                echo "ℹ️  Previous active plan buffer is empty."
                return 0
            fi

            if [ -n "$cur_val" ]; then
                echo "$cur_val" > "$PREV_FILE"
            else
                rm -f "$PREV_FILE"
            fi
            echo "$prev_val" > "$ACTIVE_FILE"

            echo "🔄 [Active Buffer] Swapped active execution plan to '$prev_val' (previous: '${cur_val:-none}')."
            ;;
        clear)
            if [ -f "$ACTIVE_FILE" ]; then
                local cur_val
                cur_val="$(head -n 1 "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')"
                [ -n "$cur_val" ] && echo "$cur_val" > "$PREV_FILE"
                rm -f "$ACTIVE_FILE"
                echo "🧹 [Active Buffer] Active plan buffer cleared. Reverted to auto-discovery mode."
            else
                echo "ℹ️  Active plan buffer is already empty."
            fi
            ;;
        "")
            # Show current active plan or auto-discovery
            local active_id=""
            if [ -f "$ACTIVE_FILE" ]; then
                active_id="$(head -n 1 "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')"
            fi

            if [ -n "$active_id" ]; then
                echo "🎯 Active Plan Buffer: '$active_id'"
                echo "   Buffer File       : $ACTIVE_FILE"
                if [ -n "$PLANS_DIR" ] && [ -d "$PLANS_DIR/current" ]; then
                    for pf in "$PLANS_DIR"/current/*.md; do
                        [ ! -f "$pf" ] && continue
                        local pid bname
                        pid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" 2>/dev/null || true)"
                        bname="$(basename "$pf" .md)"
                        if [ "$pid" = "$active_id" ] || [ "$bname" = "$active_id" ] || \
                           [[ "$bname" == "$active_id-"* ]] || [[ "$bname" == "P$active_id-"* ]]; then
                            echo "   Blueprint File    : $pf"
                            local status
                            status="$(grep -E '^\* \*\*Status:\*\*' "$pf" | head -n 1 | sed 's/^\* \*\*Status:\*\*[[:space:]]*//')"
                            echo "   Status            : $status"
                            echo "   Declared Targets  :"
                            parse_plan_target_paths "$pf" | sed 's/^/     • /'
                            break
                        fi
                    done
                fi
                return 0
            fi

            # Auto-discovery inspection
            if [ -n "$PLANS_DIR" ] && [ -d "$PLANS_DIR/current" ]; then
                local dev_plans=()
                for pf in "$PLANS_DIR"/current/*.md; do
                    [ ! -f "$pf" ] && continue
                    case "$(basename "$pf")" in 000-*) continue ;; esac
                    if grep -qE '^[[:space:]]*[\*|-]*[[:space:]]*\*\*Status:\*\*[[:space:]]*.*(⚡|🟠|In Development)' "$pf" 2>/dev/null; then
                        dev_plans+=("$pf")
                    fi
                done

                if [ ${#dev_plans[@]} -eq 1 ]; then
                    local auto_pf="${dev_plans[0]}"
                    local auto_id
                    auto_id="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$auto_pf" 2>/dev/null || true)"
                    [ -z "$auto_id" ] && auto_id="$(basename "$auto_pf" .md)"
                    echo "🎯 Active Plan Buffer: '$auto_id' (auto-discovered in ⚡ In Development)"
                    echo "   Blueprint File    : $auto_pf"
                    echo "   Declared Targets  :"
                    parse_plan_target_paths "$auto_pf" | sed 's/^/     • /'
                    return 0
                elif [ ${#dev_plans[@]} -gt 1 ]; then
                    echo "⚠️  Multiple plans are currently in development:"
                    for dp in "${dev_plans[@]}"; do
                        echo "     • $(basename "$dp" .md)"
                    done
                    echo "   Run 'aapp active <id>' to designate the active execution plan."
                    return 0
                fi
            fi

            echo "ℹ️  No active plan in buffer or in development. (Auto-discovery / fail-open mode)"
            ;;
        *)
            # Set active plan
            local plan_file
            plan_file="$(resolve_plan_file "$sub" "active")" || exit 1
            local plan_id
            plan_id="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$plan_file" 2>/dev/null || true)"
            [ -z "$plan_id" ] && plan_id="$(basename "$plan_file" .md)"

            write_active_buffer "$plan_id"
            echo "🎯 [Active Buffer] Active execution plan set to '$plan_id'."
            echo "   Blueprint: $plan_file"
            echo "   Buffer   : $ACTIVE_FILE"
            echo "   Declared Targets:"
            parse_plan_target_paths "$plan_file" | sed 's/^/     • /'
            ;;
    esac
}

cmd_plan_status() {
    local query="$1"

    if [ -n "$query" ]; then
        local plan_file
        plan_file="$(resolve_plan_file "$query" "plan-status")" || exit 1
        local plan_id status title
        plan_id="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$plan_file" 2>/dev/null || true)"
        [ -z "$plan_id" ] && plan_id="$(basename "$plan_file" .md)"
        status="$(grep -E '^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*' "$plan_file" | head -n 1 | sed 's/^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*[[:space:]]*//')"
        title="$(grep -E '^# ' "$plan_file" | head -n 1 | sed 's/^# [[:space:]]*//')"

        echo "📄 Plan: $plan_id — $title"
        echo "   Status      : $status"
        echo "   Blueprint   : $plan_file"

        local open_q
        open_q=$(awk '
            /^## ❓ 5\. Open Questions/ { in_q=1; next }
            /^## / && in_q { in_q=0 }
            in_q && /^[[:space:]]*\*[[:space:]]*\[[[:space:]]\]/ { print $0 }
        ' "$plan_file")
        if [ -n "$open_q" ]; then
            echo "   Open Questions: (unresolved)"
            echo "$open_q" | sed 's/^/     • /'
        else
            echo "   Open Questions: All resolved"
        fi

        echo "   Declared Targets:"
        local targets
        targets="$(parse_plan_target_paths "$plan_file")"
        if [ -n "$targets" ]; then
            echo "$targets" | sed 's/^/     • /'
        else
            echo "     (none declared)"
        fi
        return 0
    fi

    # Matrix overview
    echo "📊 Plan Lane Matrix (.plans/current/)"
    if [ -z "$PLANS_DIR" ] || [ ! -d "$PLANS_DIR/current" ]; then
        echo "   (no .plans/current directory found)"
        return 0
    fi

    local in_dev=()
    local frozen=()
    local incubator=()

    for pf in "$PLANS_DIR"/current/*.md; do
        [ ! -f "$pf" ] && continue
        case "$(basename "$pf")" in 000-*) continue ;; esac
        local pid status
        pid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" 2>/dev/null || true)"
        [ -z "$pid" ] && pid="$(basename "$pf" .md)"
        status="$(grep -E '^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*' "$pf" | head -n 1 || true)"

        if echo "$status" | grep -qE '⚡|🟠|In Development'; then
            in_dev+=("$pid ($(basename "$pf"))")
        elif echo "$status" | grep -qE '🟢|🔷|Ready for Execution|Frozen'; then
            frozen+=("$pid ($(basename "$pf"))")
        else
            incubator+=("$pid ($(basename "$pf"))")
        fi
    done

    echo "   ⚡ In Development : ${#in_dev[@]}"
    for item in "${in_dev[@]}"; do echo "      • $item"; done

    echo "   🔷 Frozen Backlog : ${#frozen[@]}"
    for item in "${frozen[@]}"; do echo "      • $item"; done

    echo "   🟣 Incubator      : ${#incubator[@]}"
    for item in "${incubator[@]}"; do echo "      • $item"; done

    if [ -f "$ACTIVE_FILE" ]; then
        local active_id
        active_id="$(head -n 1 "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')"
        echo ""
        echo "🎯 Active Execution Buffer: '$active_id'"
    fi
}

cmd_plan_switchboard() {
    local query="$1"

    echo "🗺️  AAPP Planning Switchboard"
    echo "--------------------------------------------------"
    if [ -n "$query" ]; then
        echo "ℹ️  To inspect plan status: aapp plan-status $query"
        echo "ℹ️  To set execution buffer: aapp active $query"
        echo "ℹ️  To draft a blueprint: use '/plan <idea>' in chat"
        echo ""
    fi
    echo "To inspect plans or the active matrix:"
    echo "  aapp plan-status              Inspect plan lane matrix"
    echo "  aapp plan-status <plan-id>    Inspect specific plan details & targets"
    echo ""
    echo "To manage the execution buffer:"
    echo "  aapp active <plan-id>         Set active plan buffer for guard enforcement"
    echo "  aapp active swap              Swap active buffer with previous plan"
    echo "  aapp active clear             Clear buffer (revert to auto-discovery)"
    echo ""
    echo "To draft or execute blueprints:"
    echo "  Use '/plan <idea>' or '/aapp-plan <idea>' in your AI agent chat."
}

# Dispatcher
ACTION="${1:-plan}"
shift || true

case "$ACTION" in
    freeze-start)
        cmd_freeze_start "$@"
        ;;
    start)
        cmd_start "$@"
        ;;
    active)
        cmd_active "$@"
        ;;
    plan-status)
        cmd_plan_status "$@"
        ;;
    plan)
        cmd_plan_switchboard "$@"
        ;;
    help|-h|--help)
        cat <<EOF
Usage: aapp <command> [args]

Multi-Agent Planning & Execution Commands:
  freeze-start <id>  Atomically freeze blueprint, transition to ⚡ In Development, and bind buffer
  start <id>         Transition 🔷 Frozen blueprint to ⚡ In Development and bind buffer
  active [id]        Display or set active execution plan buffer (.git/aapp_active_plan)
  active swap        Swap between current and previous active plan
  active clear       Clear active plan buffer (revert to auto-discovery)
  plan-status [id]   Inspect plan matrix or specific blueprint (read-only)
  plan [query]       Display educational planning switchboard
EOF
        ;;
    *)
        echo "❌ Unknown plan command: '$ACTION'" >&2
        echo "   Available: freeze-start, start, active, plan-status, plan" >&2
        exit 1
        ;;
esac
