#!/usr/bin/env bash
# ==============================================================================
# Adopter Showcase Hook: `on-done-sync.sh`
#
# Automatically synchronizes all active AAPP worktrees (.plans, .agents, .githooks)
# with origin upon plan completion.
#
# Registration:
#   aapp hook-hash examples/hooks/on-done-sync.sh on-done 30 notify
# ==============================================================================
set -e

# Discard STDIN envelope
cat >/dev/null 2>&1 || true

echo "🔄 [Hook: on-done-sync] Archival detected for ${AAPP_PLAN_ID:-plan}. Initiating push..."

if command -v aapp >/dev/null 2>&1; then
    aapp push origin
elif [ -x "./aapp" ]; then
    ./aapp push origin
fi

echo "✅ [Hook: on-done-sync] Remote sync completed."
exit 0
