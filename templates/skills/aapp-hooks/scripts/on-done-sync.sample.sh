#!/usr/bin/env bash
# ==============================================================================
# Sample AAPP Hook: `on-done-sync`
#
# Triggered upon plan completion (on-done). Automatically pushes all active
# AAPP worktrees (.plans, .agents, .githooks) to the remote repository.
# Resolves P-10 Open Question 3 via clean lifecycle decoupling.
# ==============================================================================
set -e

# Discard STDIN payload if present
cat >/dev/null 2>&1 || true

echo "🚀 [Sample on-done-sync Hook] Synchronizing worktrees with remote..."

# Execute automated worktree push using aapp CLI
if command -v aapp >/dev/null 2>&1; then
    aapp push
elif [ -x "./aapp" ]; then
    ./aapp push
else
    echo "⚠️  Could not find 'aapp' binary to trigger push." >&2
    exit 0
fi

echo "✨ Automated post-completion remote push complete."
exit 0
