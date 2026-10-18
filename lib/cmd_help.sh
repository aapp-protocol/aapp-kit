#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `help`
#
# Tiered CLI Discovery & Help Catalog (Plan P-27)
# Renders commands grouped into 5 visual tiers backed by lib/verbs.tsv.
# ==============================================================================
set -e

AAPP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"

VERBS_TSV=""
if [ -n "$AAPP_LIB" ] && [ -f "$AAPP_LIB/verbs.tsv" ]; then
    VERBS_TSV="$AAPP_LIB/verbs.tsv"
elif [ -f "$AAPP_SCRIPT_DIR/lib/verbs.tsv" ]; then
    VERBS_TSV="$AAPP_SCRIPT_DIR/lib/verbs.tsv"
elif [ -f "${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit/lib/verbs.tsv" ]; then
    VERBS_TSV="${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit/lib/verbs.tsv"
fi

# `aapp help <verb> [full]` (P-47, P-87): from the verb's contract in the
# installed kit, its synopsis and arguments; `full` prints the whole contract.
if [ -n "${1:-}" ]; then
    HELP_VERB="$1"
    HELP_FULL="${2:-}"
    if [ -z "$VERBS_TSV" ]; then
        echo "❌ [Help] lib/verbs.tsv not found; reinstall the kit ('aapp install')." >&2
        exit 1
    fi
    HELP_TAB="$(printf '\t')"
    while IFS="$HELP_TAB" read -r verb tier standalone desc contract rest || [ -n "$verb" ]; do
        [ "$verb" = "$HELP_VERB" ] || continue
        if [ -n "$contract" ]; then
            HELP_CONTRACT="$(dirname "$VERBS_TSV")/../$contract"
            if [ ! -f "$HELP_CONTRACT" ]; then
                echo "❌ [Help] Contract for '$HELP_VERB' missing: $contract" >&2
                exit 1
            fi
            if [ "$HELP_FULL" = "full" ]; then
                cat "$HELP_CONTRACT"
            else
                awk -v verb="$HELP_VERB" '
                    NR == 1 { sub(/^# /, ""); print "aapp " $0; next }
                    /^## Ingress/ { r = 1; print ""; next }
                    /^## / { r = 0 }
                    r && NF
                    END { print ""; print "Refusals, effects and tests: aapp help " verb " full" }
                ' "$HELP_CONTRACT"
            fi
        else
            echo "aapp $HELP_VERB — $desc"
        fi
        exit 0
    done < "$VERBS_TSV"

    # Fallback: Action plugin or skill discovery in .agents/skills/$HELP_VERB (P-95)
    HELP_GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$HELP_GIT_ROOT" ] && [ -d "$HELP_GIT_ROOT/.agents/skills/$HELP_VERB" ]; then
        HELP_PLUGIN_DIR="$HELP_GIT_ROOT/.agents/skills/$HELP_VERB"
        HELP_CANDIDATE=""
        if command -v resolve_plugin_entrypoint >/dev/null 2>&1; then
            HELP_CANDIDATE="$(resolve_plugin_entrypoint "$HELP_PLUGIN_DIR" "$HELP_VERB" || true)"
        elif [ -f "${AAPP_LIB:-$AAPP_SCRIPT_DIR/lib}/hook_dispatcher.sh" ]; then
            # shellcheck source=/dev/null
            source "${AAPP_LIB:-$AAPP_SCRIPT_DIR/lib}/hook_dispatcher.sh"
            HELP_CANDIDATE="$(resolve_plugin_entrypoint "$HELP_PLUGIN_DIR" "$HELP_VERB" || true)"
        fi

        if [ "$HELP_FULL" = "full" ] && [ -f "$HELP_PLUGIN_DIR/SKILL.md" ]; then
            cat "$HELP_PLUGIN_DIR/SKILL.md"
            exit 0
        fi

        # Try executable help first
        if [ -n "$HELP_CANDIDATE" ] && [ -x "$HELP_CANDIDATE" ]; then
            PLUGIN_HELP_OUT="$("$HELP_CANDIDATE" --help 2>&1 || "$HELP_CANDIDATE" help 2>&1 || true)"
            if [ -n "$PLUGIN_HELP_OUT" ]; then
                printf "%s\n" "$PLUGIN_HELP_OUT"
                if [ -f "$HELP_PLUGIN_DIR/SKILL.md" ]; then
                    echo ""
                    echo "Full skill documentation: aapp help $HELP_VERB full"
                fi
                exit 0
            fi
        fi

        # Fallback to SKILL.md metadata if present
        if [ -f "$HELP_PLUGIN_DIR/SKILL.md" ]; then
            SKILL_DESC="$(sed -nE 's/^description: *(.*)/\1/p' "$HELP_PLUGIN_DIR/SKILL.md" | head -n 1)"
            if [ -n "$SKILL_DESC" ]; then
                echo "aapp $HELP_VERB — $SKILL_DESC"
            else
                SKILL_NAME="$(sed -nE 's/^# *(.*)/\1/p' "$HELP_PLUGIN_DIR/SKILL.md" | head -n 1)"
                echo "aapp $HELP_VERB — ${SKILL_NAME:-Action plugin $HELP_VERB}"
            fi
            echo ""
            echo "Full skill documentation: aapp help $HELP_VERB full"
            exit 0
        fi

        if [ -n "$HELP_CANDIDATE" ] && [ -x "$HELP_CANDIDATE" ]; then
            echo "aapp $HELP_VERB — Custom action plugin ($HELP_CANDIDATE)"
            exit 0
        fi
    fi

    echo "❌ Unknown command: '$HELP_VERB'. Run 'aapp help' for the catalog." >&2
    exit 1
fi

cat <<EOF
Usage: aapp <command> [options]

Asymmetric Agent Planning Protocol (AAPP v${AAPP_VERSION:-1.0.0})
A deterministic protocol decoupling planning, agent behavioral rules,
and git hooks from application source code using isolated Git worktrees.

EOF

print_tier() {
    local target_tier="$1"
    local title="$2"

    echo "$title:"
    if [ -n "$VERBS_TSV" ] && [ -f "$VERBS_TSV" ]; then
        local TAB
        TAB="$(printf '\t')"
        # `read` assigns leftover fields to its last variable: name the fifth
        # (contract) column and a catch-all so neither leaks into the description.
        while IFS="$TAB" read -r verb tier standalone desc contract rest || [ -n "$verb" ]; do
            [ -z "$verb" ] && continue
            [ "${verb#\#}" != "$verb" ] && continue
            if [ "$tier" = "$target_tier" ]; then
                printf "  %-13s %s\n" "$verb" "$desc"
            fi
        done < "$VERBS_TSV"
    fi
    echo ""
}

print_tier "daily" "Daily Working Loop (Core)"
print_tier "setup" "Setup & Maintenance"
print_tier "sync" "Team Sync & Emergency Controls"
print_tier "hooks" "Extensibility & Automation (Hooks & Plugins)"
print_tier "ai" "Attribution & Metadata (AI Switchboard)"

cat <<EOF
Examples:
  aapp status            # Print Shipped, Issues, Plans, and Pickup briefing
  aapp draft my-feature  # Scaffold new blueprint in .plans/current/
  aapp freeze P-20       # Lock blueprint into frozen backlog spec
  aapp start P-20        # Activate frozen blueprint into development
  aapp freeze-start P-20 # Atomically freeze and start in one command
  aapp done P-20         # Archive implemented blueprint and update ledger
  aapp active P-20       # Designate P-20 as active execution plan buffer
  aapp plan-status       # Inspect current plan lane matrix
  aapp pause "away"      # Engage emergency brake and quarantine in-flight changes
  aapp resume            # Disengage brake, verify drift, and restore stashed work
  aapp push              # Push all active worktrees (.plans, .agents, .githooks)
  aapp pull              # Pull remote changes with --ff-only
  aapp sync              # Pull then push active worktrees
  aapp hooks             # Audit registered lifecycle hooks and verify SHA256 hashes
  aapp ai lax            # Enable lax attribution (recommended when opting in; human commits pass freely)
  aapp ai strict         # Enable strict attribution (trailers required on every commit)
  aapp ai notes          # Enable local git notes attribution
  aapp ai none           # Disable AI attribution (default; pure human commits)
  aapp ai-credits        # Update AI Contributors block in README.md
  aapp ai-note --stage   # Pre-stage customizable note buffer for next commit
  aapp init              # Set up or sync worktrees in current repository
  aapp develop           # Link local development clone globally (live editable)
  aapp install           # Install aapp globally into ~/.local/bin
  aapp upgrade           # Pull latest upstream release into ~/.local/share
  aapp uninstall         # Remove global installation

For documentation, see: https://github.com/aapp-protocol/aapp-kit
EOF
