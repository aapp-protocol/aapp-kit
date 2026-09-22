#!/usr/bin/env bash
# ==============================================================================
# AAPP Test Harness Helper: Sandbox Confinement & Test Identity Envelope
#
# Governed by Plan P-26 (Test Harness Sandbox Confinement & Universal Worktree Hooks).
#
# Functions:
#   assert_test_sandbox [target_dir]
#     Fail-closed verification: aborts execution if target_dir belongs to the
#     host repository or any of its linked worktrees (.plans, .agents, .githooks).
#
#   setup_test_git_identity [target_dir]
#     Configures git user.name and user.email inheriting from developer's global
#     git environment or falling back to safe synthetic CI identity. Disables
#     commit.gpgsign and tag.gpgsign in disposable sandboxes.
#
#   make_test_sandbox [prefix]
#     Creates a secure disposable temporary directory in /tmp and returns its path.
# ==============================================================================

# Ensure strict sandbox mode by default unless explicitly disabled
export AAPP_TEST_SANDBOX_STRICT="${AAPP_TEST_SANDBOX_STRICT:-1}"

assert_test_sandbox() {
    local target="${1:-$(pwd)}"
    local target_abs host_root
    target_abs="$(cd "$target" 2>/dev/null && pwd || echo "$target")"
    host_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"

    local host_git_common target_git_common
    host_git_common="$(cd "$host_root" 2>/dev/null && cd "$(git rev-parse --git-common-dir 2>/dev/null || echo .git)" 2>/dev/null && pwd)"
    target_git_common="$(cd "$target_abs" 2>/dev/null && cd "$(git rev-parse --git-common-dir 2>/dev/null || true)" 2>/dev/null && pwd)"

    if [ -n "$target_git_common" ] && [ "$target_git_common" = "$host_git_common" ]; then
        echo "❌ [FATAL Test Sandbox Violation] Attempted Git operation in host repository or linked worktree!" >&2
        echo "   Target:  $target_abs" >&2
        echo "   Host:    $host_root" >&2
        echo "   Common:  $host_git_common" >&2
        exit 1
    fi
}

setup_test_git_identity() {
    local target_dir="${1:-$(pwd)}"

    # 1. Enforce sandbox confinement
    assert_test_sandbox "$target_dir"

    # 2. Inherit developer identity or safe CI fallback with empty-string protection
    local dev_name dev_email
    dev_name="$(git config --global user.name 2>/dev/null || true)"
    [ -z "$dev_name" ] && dev_name="$(git config user.name 2>/dev/null || true)"
    [ -z "$dev_name" ] && dev_name="AAPP Test Runner"

    dev_email="$(git config --global user.email 2>/dev/null || true)"
    [ -z "$dev_email" ] && dev_email="$(git config user.email 2>/dev/null || true)"
    [ -z "$dev_email" ] && dev_email="test-runner@aapp.internal"

    git -C "$target_dir" config user.name "$dev_name"
    git -C "$target_dir" config user.email "$dev_email"
    git -C "$target_dir" config commit.gpgsign false
    git -C "$target_dir" config tag.gpgsign false
}

make_test_sandbox() {
    local prefix="${1:-aapp-test}"
    mktemp -d "/tmp/${prefix}-XXXXXX"
}

print_test_summary() {
    local pass="${1:-$PASS}"
    local fail="${2:-$FAIL}"
    echo ""
    echo "============================================================"
    echo "  Results: $pass passed, $fail failed"
    echo "============================================================"
    [ "$fail" -eq 0 ] || exit 1
}

