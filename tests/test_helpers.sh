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

confine_test_runtime() {
    local sandbox_root="$1"
    [ -z "$sandbox_root" ] && { echo "❌ confine_test_runtime requires sandbox root directory" >&2; exit 1; }

    # 1. Assert sandbox isolation
    assert_test_sandbox "$sandbox_root"

    # 2. Inherit developer global identity before swapping HOME (Rule 7)
    local dev_name dev_email
    dev_name="$(git config --global user.name 2>/dev/null || true)"
    [ -z "$dev_name" ] && dev_name="$(git config user.name 2>/dev/null || true)"
    [ -z "$dev_name" ] && dev_name="AAPP Test Runner"

    dev_email="$(git config --global user.email 2>/dev/null || true)"
    [ -z "$dev_email" ] && dev_email="$(git config user.email 2>/dev/null || true)"
    [ -z "$dev_email" ] && dev_email="test-runner@aapp.internal"

    # 3. Setup sandbox directories
    local sandbox_home="$sandbox_root/home"
    local sandbox_bin="$sandbox_home/.local/bin"
    local sandbox_share="$sandbox_home/.local/share/aapp-kit"
    mkdir -p "$sandbox_bin" "$sandbox_share"

    # 4. Populate sandbox .gitconfig with captured developer identity
    local default_branch
    default_branch="$(git config --global init.defaultBranch 2>/dev/null || true)"
    [ -z "$default_branch" ] && default_branch="main"

    cat > "$sandbox_home/.gitconfig" <<EOF
[user]
	name = $dev_name
	email = $dev_email
[commit]
	gpgsign = false
[tag]
	gpgsign = false
[init]
	defaultBranch = $default_branch
EOF

    # 5. Populate sandbox installed AAPP toolchain
    local kit_root
    kit_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
    cp "$kit_root/aapp" "$sandbox_bin/aapp"
    chmod +x "$sandbox_bin/aapp"
    rm -rf "$sandbox_share/lib" "$sandbox_share/templates" "$sandbox_share/tests" "$sandbox_share/examples"
    cp -r "$kit_root/lib" "$kit_root/templates" "$kit_root/tests" "$kit_root/examples" "$sandbox_share/"

    # 6. Toolchain-preserving PATH filtering:
    # Prepend sandbox_bin and filter out any PATH entry containing a host aapp binary
    local clean_path="" old_ifs="$IFS"
    IFS=':'
    for p in $PATH; do
        [ -z "$p" ] && continue
        if [ ! -x "$p/aapp" ] || [ "$p" = "$sandbox_bin" ]; then
            clean_path="${clean_path:+$clean_path:}$p"
        fi
    done
    IFS="$old_ifs"

    export HOME="$sandbox_home"
    export XDG_DATA_HOME="$sandbox_home/.local/share"
    export PATH="$sandbox_bin:$clean_path"
    export SANDBOX_BIN="$sandbox_bin"
    export SANDBOX_CLEAN_PATH="$clean_path"

    # 7. Fail-closed assertion: verify aapp resolves strictly inside sandbox
    local resolved_aapp
    resolved_aapp="$(command -v aapp 2>/dev/null || true)"
    if [ "$resolved_aapp" != "$sandbox_bin/aapp" ]; then
        echo "❌ [FATAL Test Runtime Confinement Failure] 'aapp' does not resolve to sandbox binary!" >&2
        echo "   Expected: $sandbox_bin/aapp" >&2
        echo "   Resolved: $resolved_aapp" >&2
        echo "   PATH:     $PATH" >&2
        exit 1
    fi
}

init_sandbox_project() {
    local proj_dir="$1"
    mkdir -p "$proj_dir"
    (
        cd "$proj_dir"
        git init -q .
        setup_test_git_identity "$proj_dir"
        echo "print('hello')" > main.py
        git add main.py
        git commit -qm "initial commit"
        aapp init >/dev/null 2>&1
    )
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

