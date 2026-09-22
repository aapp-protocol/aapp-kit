#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `test` (Unified Test Runner Orchestrator)
#
# Discovers, executes, and aggregates test suites across the kit with isolated
# subshell execution, assertion metrics, execution timing, and zero double-dash
# CLI modifiers.
#
# Usage:
#   aapp test [modifier] [suite-name...]
#
# Modifiers:
#   list    List available test suites without running them
#   strict  Enforce strict fail-closed sandbox containment (AAPP_TEST_SANDBOX_STRICT=1)
#   quiet   Quiet output: suppress assertion stream, report suite-level status
#   bail    Abort execution immediately upon the first failing suite
#   help    Display usage reference
# ==============================================================================
set -e

cmd_test_help() {
    cat <<'EOF'
Usage: aapp test [modifier] [suite-name...]

Run automated test suites across kit components with consolidated aggregation.

Modifiers (bare-word tokens; zero double-dash flags):
  (default)          Run all discovered test suites with standard output
  list               List all discovered test suites without running them
  strict             Enforce fail-closed sandbox containment (AAPP_TEST_SANDBOX_STRICT=1)
  quiet              Quiet output: suppress assertion stream, report suite status only
  bail               Abort execution immediately upon first failing suite
  help               Display this help text

Arguments:
  [suite-name...]    Specific test suite name or prefix to run (e.g. 'hooks', 'guard')
                     If omitted, all discovered 'tests/*_test.sh' suites are executed.

Examples:
  aapp test                  Run all test suites
  aapp test hooks            Run only tests/hooks_test.sh
  aapp test strict           Run all suites with strict sandbox verification
  aapp test strict hooks     Run hooks suite with strict sandbox verification
  aapp test list             List all available test suites
  aapp test quiet            Run all suites with compact progress
  aapp test bail             Run suites and stop on the first failure
EOF
}

aapp_adopter_test_or_audit() {
    local repo_root="$1"
    local custom_cmd
    custom_cmd="$(git -C "$repo_root" config aapp.testCommand 2>/dev/null || true)"

    if [ -n "$custom_cmd" ]; then
        echo "🚀 Running project test command from git config (aapp.testCommand):"
        echo "   $custom_cmd"
        echo ""
        ( cd "$repo_root" && eval "$custom_cmd" )
        return $?
    fi

    # Auto-detect project test runner
    if [ -f "$repo_root/package.json" ] && grep -qs '"test"' "$repo_root/package.json"; then
        echo "🚀 Auto-detected Node.js project: running 'npm test'..."
        echo ""
        ( cd "$repo_root" && npm test )
        return $?
    elif [ -f "$repo_root/Cargo.toml" ]; then
        echo "🚀 Auto-detected Rust project: running 'cargo test'..."
        echo ""
        ( cd "$repo_root" && cargo test )
        return $?
    elif [ -f "$repo_root/composer.json" ] && grep -qs '"test"' "$repo_root/composer.json"; then
        echo "🚀 Auto-detected PHP project: running 'composer test'..."
        echo ""
        ( cd "$repo_root" && composer test )
        return $?
    elif [ -f "$repo_root/go.mod" ]; then
        echo "🚀 Auto-detected Go project: running 'go test ./...'..."
        echo ""
        ( cd "$repo_root" && go test ./... )
        return $?
    elif [ -f "$repo_root/Makefile" ] && grep -qE '^[[:space:]]*test:' "$repo_root/Makefile" 2>/dev/null; then
        echo "🚀 Auto-detected Makefile test target: running 'make test'..."
        echo ""
        ( cd "$repo_root" && make test )
        return $?
    fi

    # Fallback: Protocol environment health audit
    echo "ℹ️  No project test runner detected and no 'tests/' directory found."
    echo "   Executing AAPP Protocol Environment Health Audit..."
    echo ""

    local audit_failed=0
    for wt in .plans .agents .githooks; do
        if [ -d "$repo_root/$wt" ]; then
            printf "  \033[32m✔\033[0m Worktree '%s' mounted\n" "$wt"
        else
            printf "  \033[31m✘\033[0m Worktree '%s' missing\n" "$wt"
            audit_failed=1
        fi
    done

    local hooks_path
    hooks_path="$(git -C "$repo_root" config core.hooksPath 2>/dev/null || true)"
    if [ "$hooks_path" = ".githooks" ]; then
        printf "  \033[32m✔\033[0m Git hooks path set to '.githooks'\n"
    else
        printf "  \033[33m!\033[0m Git hooks path is '%s' (expected '.githooks')\n" "${hooks_path:-unset}"
    fi

    local aapp_script_dir
    aapp_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
    # Run planning health validation if active plans exist and strict mode is on
    if [ "${AAPP_TEST_SANDBOX_STRICT:-0}" -eq 1 ] && [ -f "$aapp_script_dir/lib/planning_health.sh" ] && [ -d "$repo_root/.plans/current" ]; then
        local plan_count
        plan_count="$(find "$repo_root/.plans/current" -maxdepth 1 -name '*.md' ! -name '000-*' 2>/dev/null | wc -l)"
        if [ "$plan_count" -gt 0 ]; then
            source "$aapp_script_dir/lib/planning_health.sh"
            echo ""
            echo "   Running planning health validation pairs..."
            check_planning_health "$repo_root" || audit_failed=1
        fi
    fi

    echo ""
    if [ "$audit_failed" -eq 0 ]; then
        echo "🎉 AAPP protocol environment is healthy!"
        return 0
    else
        echo "⚠️  AAPP protocol audit detected warnings or failures."
        return 1
    fi
}

cmd_test() {
    local repo_root
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    local test_dir="$repo_root/tests"

    # 1. Adopter repository mode check
    if [ ! -d "$test_dir" ]; then
        aapp_adopter_test_or_audit "$repo_root"
        return $?
    fi

    # 2. Parse bare-word modifiers (zero double-dash flags)
    local mode="run"
    local strict=0
    local bail=0
    local quiet=0
    local suite_filters=()

    while [ $# -gt 0 ]; do
        case "$1" in
            list)   mode="list" ;;
            strict) strict=1 ;;
            bail)   bail=1 ;;
            quiet)  quiet=1 ;;
            help)
                cmd_test_help
                return 0
                ;;
            *)
                suite_filters+=("$1")
                ;;
        esac
        shift
    done

    # Set strict environment variable if requested
    if [ "$strict" -eq 1 ]; then
        export AAPP_TEST_SANDBOX_STRICT=1
    fi

    # 3. Discover test suites
    local all_suites=()
    while IFS= read -r f; do
        [ -n "$f" ] && all_suites+=("$f")
    done < <(find "$test_dir" -maxdepth 1 -name '*_test.sh' | sort)

    if [ ${#all_suites[@]} -eq 0 ]; then
        echo "ℹ️  No test suites found in '$test_dir'."
        return 0
    fi

    # Filter suites if arguments provided
    local selected_suites=()
    if [ ${#suite_filters[@]} -eq 0 ]; then
        selected_suites=("${all_suites[@]}")
    else
        for suite in "${all_suites[@]}"; do
            local bname="${suite##*/}"
            local sname="${bname%_test.sh}"
            local matched=0
            for filter in "${suite_filters[@]}"; do
                # Match against exact filename, basename, slug, or substring
                if [ "$filter" = "$bname" ] || [ "$filter" = "$sname" ] || \
                   [[ "$bname" == *"$filter"* ]]; then
                    matched=1
                    break
                fi
            done
            if [ "$matched" -eq 1 ]; then
                selected_suites+=("$suite")
            fi
        done
    fi

    if [ ${#selected_suites[@]} -eq 0 ]; then
        echo "❌ [Test Runner] No test suites matched filter: ${suite_filters[*]}"
        echo "   Run 'aapp test list' to view available suites."
        return 1
    fi

    # 4. Handle list mode
    if [ "$mode" = "list" ]; then
        echo "============================================================"
        echo "  📋 Available AAPP Test Suites (${#selected_suites[@]} found)"
        echo "  📍 Directory: $test_dir"
        echo "============================================================"
        for suite in "${selected_suites[@]}"; do
            local bname="${suite##*/}"
            local desc=""
            # Extract first comment line after shebang if present
            desc="$(grep -m 1 -E '^#[[:space:]]*Tests:|^#[[:space:]]*Automated' "$suite" 2>/dev/null | sed -E 's/^#[[:space:]]*//' || true)"
            if [ -n "$desc" ]; then
                printf "  • \033[1m%-24s\033[0m %s\n" "$bname" "$desc"
            else
                printf "  • \033[1m%-24s\033[0m\n" "$bname"
            fi
        done
        echo ""
        echo "👉 Run all:              aapp test"
        echo "👉 Run specific suite:   aapp test <name>"
        return 0
    fi

    # 5. Header Banner
    local strict_label="OFF"
    [ "${AAPP_TEST_SANDBOX_STRICT:-0}" = "1" ] && strict_label="ON"

    echo "============================================================"
    echo "  🧪 AAPP Unified Test Runner"
    echo "  📍 Repository: $repo_root"
    echo "  🎯 Execution:  ${#selected_suites[@]} suites selected | Sandbox Strict: $strict_label"
    echo "============================================================"
    echo ""

    local suites_passed=0
    local suites_failed=0
    local total_assertions_passed=0
    local total_assertions_failed=0
    local runner_start
    runner_start="$(date +%s)"

    # Array to collect summary rows
    local summary_rows=()

    for suite in "${selected_suites[@]}"; do
        local bname="${suite##*/}"
        local suite_start
        suite_start="$(date +%s)"
        local suite_out
        local suite_rc=0

        # Execute in subshell, capturing output and exit code
        if [ "$quiet" -eq 1 ]; then
            suite_out="$(( cd "$repo_root" && bash "$suite" ) 2>&1)" || suite_rc=$?
        else
            # Stream output live while also capturing into buffer for metrics extraction
            # Using temporary file for robust, non-blocking capture
            local tmp_out
            tmp_out="$(mktemp "/tmp/aapp-test-suite-XXXXXX")"
            ( cd "$repo_root" && bash "$suite" ) 2>&1 | tee "$tmp_out" || suite_rc=${PIPESTATUS[0]}
            suite_out="$(cat "$tmp_out")"
            rm -f "$tmp_out"
        fi

        local suite_end
        suite_end="$(date +%s)"
        local suite_duration=$((suite_end - suite_start))

        # Dual-layer assertion metrics extraction (strips ANSI codes)
        local clean_output
        clean_output="$(echo "$suite_out" | sed -E 's/\x1b\[[0-9;]*m//g')"
        local suite_pass=0
        local suite_fail=0

        if [[ "$clean_output" =~ Results:[[:space:]]*([0-9]+)[[:space:]]*passed,[[:space:]]*([0-9]+)[[:space:]]*failed ]]; then
            suite_pass="${BASH_REMATCH[1]}"
            suite_fail="${BASH_REMATCH[2]}"
        elif [[ "$clean_output" =~ Passed:[[:space:]]*([0-9]+).*Failed:[[:space:]]*([0-9]+) ]]; then
            suite_pass="${BASH_REMATCH[1]}"
            suite_fail="${BASH_REMATCH[2]}"
        elif [[ "$clean_output" =~ ([0-9]+)[[:space:]]*passed.*([0-9]+)[[:space:]]*failed ]]; then
            suite_pass="${BASH_REMATCH[1]}"
            suite_fail="${BASH_REMATCH[2]}"
        elif [[ "$clean_output" =~ passed=([0-9]+).*failed=([0-9]+) ]]; then
            suite_pass="${BASH_REMATCH[1]}"
            suite_fail="${BASH_REMATCH[2]}"
        else
            if [ "$suite_rc" -eq 0 ]; then
                suite_pass=1
            else
                suite_fail=1
            fi
        fi

        total_assertions_passed=$((total_assertions_passed + suite_pass))
        total_assertions_failed=$((total_assertions_failed + suite_fail))

        if [ "$suite_rc" -eq 0 ] && [ "$suite_fail" -eq 0 ]; then
            suites_passed=$((suites_passed + 1))
            local row
            row="$(printf "  \033[32m✔\033[0m %-26s (%d passed, %d failed) [%ds]" "$bname" "$suite_pass" "$suite_fail" "$suite_duration")"
            summary_rows+=("$row")
            if [ "$quiet" -eq 1 ]; then
                echo "$row"
            fi
        else
            suites_failed=$((suites_failed + 1))
            local row
            row="$(printf "  \033[31m✘\033[0m %-26s (%d passed, %d failed) [%ds] - FAILED (exit %d)" "$bname" "$suite_pass" "$suite_fail" "$suite_duration" "$suite_rc")"
            summary_rows+=("$row")
            if [ "$quiet" -eq 1 ]; then
                echo "$row"
                echo "────────────────────────────────────────────────────────────"
                echo "$suite_out"
                echo "────────────────────────────────────────────────────────────"
            fi

            if [ "$bail" -eq 1 ]; then
                echo ""
                echo "🛑 [Bail] Aborting test execution immediately upon suite failure."
                break
            fi
        fi
    done

    local runner_end
    runner_end="$(date +%s)"
    local total_duration=$((runner_end - runner_start))

    # Consolidated Result Banner
    echo ""
    echo "============================================================"
    echo "  📊 Test Summary: $suites_passed/${#selected_suites[@]} suites passed ($total_assertions_passed passed, $total_assertions_failed failed) in ${total_duration}s"
    echo "============================================================"

    if [ "$quiet" -eq 0 ]; then
        for r in "${summary_rows[@]}"; do
            echo "$r"
        done
        echo "------------------------------------------------------------"
    fi

    if [ "$suites_failed" -eq 0 ]; then
        echo "  🎉 All test suites passed cleanly!"
        return 0
    else
        echo "  ❌ $suites_failed test suite(s) failed."
        return 1
    fi
}
