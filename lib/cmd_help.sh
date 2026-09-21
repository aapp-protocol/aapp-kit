#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `help`
#
# Tiered CLI Discovery & Help Catalog (Plan P-27)
# Renders commands grouped into 5 visual tiers backed by lib/verbs.tsv.
# ==============================================================================
set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AAPP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"

VERBS_TSV=""
if [ -n "$AAPP_LIB" ] && [ -f "$AAPP_LIB/verbs.tsv" ]; then
    VERBS_TSV="$AAPP_LIB/verbs.tsv"
elif [ -f "$AAPP_SCRIPT_DIR/lib/verbs.tsv" ]; then
    VERBS_TSV="$AAPP_SCRIPT_DIR/lib/verbs.tsv"
elif [ -f "${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit/lib/verbs.tsv" ]; then
    VERBS_TSV="${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit/lib/verbs.tsv"
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
        while IFS="$TAB" read -r verb tier standalone desc || [ -n "$verb" ]; do
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
  aapp plugins           # Inspect discovered standalone action plugins
  aapp ai-commit         # Enable public emailless trailers (AI-Agent:)
  aapp ai-notes          # Enable local git notes attribution
  aapp ai-off            # Disable AI attribution (pure human commits)
  aapp ai-credits        # Update AI Contributors block in README.md
  aapp ai-note --stage   # Pre-stage customizable note buffer for next commit
  aapp init              # Set up or sync worktrees in current repository
  aapp develop           # Link local development clone globally (live editable)
  aapp install           # Install aapp globally into ~/.local/bin
  aapp upgrade           # Pull latest upstream release into ~/.local/share
  aapp uninstall         # Remove global installation

For documentation, see: https://github.com/aapp-protocol/aapp-kit
EOF
