#!/usr/bin/env bash
# ==============================================================================
# Adopter Showcase Hook: `test-gate.sh`
#
# Quality Gate (mode: gate) triggered on `pre-done`.
# Runs the project's test command where the plan's code lives (its worktree, or
# the repository root) and refuses `aapp done` unless it passes.
#
# Setup:
#   cp examples/hooks/test-gate.sh.sample .agents/hooks/test-gate.sh
#   set TEST_CMD below, then register (timeout covers the whole suite):
#   aapp hook-hash .agents/hooks/test-gate.sh pre-done 900 gate
#
# The registry pins this file by SHA-256: changing TEST_CMD is a reviewed commit.
#
# Exit codes: 0 green; 1 red, TEST_CMD unset, or uncommitted tracked changes.
# ==============================================================================
set -u

TEST_CMD='./aapp test strict quiet'

envelope="$(cat)"
field() { printf '%s\n' "$envelope" | sed -nE "s/.*\"$1\":[[:space:]]*\"([^\"]*)\".*/\1/p" | head -n 1; }
plan_id="$(field plan_id)"
worktree="$(field worktree)"
root="${AAPP_REPO_ROOT:-$(git rev-parse --show-toplevel)}"

if [ -z "$TEST_CMD" ]; then
    echo "❌ [Test Gate] TEST_CMD is not set in ${BASH_SOURCE[0]}." >&2
    exit 1
fi

dir="${worktree:-$root}"
cd "$dir" || { echo "❌ [Test Gate] Cannot enter $dir." >&2; exit 1; }

# Plan worktrees are clean-checked by `done`; a single checkout is checked here.
if [ -z "$worktree" ] && [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    echo "❌ [Test Gate] Uncommitted tracked changes in $dir: tests must run on committed code." >&2
    exit 1
fi

log="$(mktemp)"
trap 'rm -f "$log"' EXIT
bash -c "$TEST_CMD" >"$log" 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
    echo "✅ [Test Gate] tests green for ${plan_id}."
    exit 0
fi
{
    echo "❌ [Test Gate] '$TEST_CMD' failed in $dir (exit $rc). Last 20 lines:"
    tail -n 20 "$log"
} >&2
exit 1
