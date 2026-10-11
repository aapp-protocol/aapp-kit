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
#   aapp test [modifier] verb [verb-name...]
#
# Modifiers:
#   list    List available test suites without running them
#   strict  Enforce strict fail-closed sandbox containment (AAPP_TEST_SANDBOX_STRICT=1)
#   quiet   Quiet output: suppress assertion stream, report suite-level status
#   bail    Start no further suite after the first failing one
#   jobs N  Run up to N suites at once (default: CPU count rounded down to a multiple of 4)
#   help    Display usage reference
#   verb    Select contract-derived verb suites in tests/verbs/ (P-34)
# ==============================================================================
set -e

cmd_test_help() {
    cat <<'EOF'
Usage: aapp test [modifier] [suite-name...]
       aapp test [modifier] verb [verb-name...]

Run automated test suites across kit components with consolidated aggregation.

Modifiers (bare-word tokens; zero double-dash flags):
  (default)          Run all discovered test suites with standard output
  list               List all discovered test suites without running them
  strict             Enforce fail-closed sandbox containment (AAPP_TEST_SANDBOX_STRICT=1)
  quiet              Quiet output: suppress assertion stream, report suite status only
  bail               Start no further suite after the first failing one
  jobs <n>           Run up to <n> suites at once; default: the CPU count rounded
                     down to a multiple of 4 (below 4 CPUs, the CPU count); 'jobs 1' is serial
  help               Display this help text
  verb [name...]     Run contract-derived verb suites (tests/verbs/<name>.sh);
                     all of them when no name is given

Arguments:
  [suite-name...]    Specific test suite name or prefix to run (e.g. 'hooks', 'guard')
                     If omitted, every 'tests/*_test.sh' suite and every
                     'tests/verbs/*.sh' verb suite is executed.

Examples:
  aapp test                  Run all test suites
  aapp test hooks            Run only tests/hooks_test.sh
  aapp test strict           Run all suites with strict sandbox verification
  aapp test strict hooks     Run hooks suite with strict sandbox verification
  aapp test list             List all available test suites
  aapp test verb draft       Run only tests/verbs/draft.sh
  aapp test verb             Run every verb suite
  aapp test quiet            Run all suites with compact progress
  aapp test bail             Run suites and stop on the first failure
  aapp test jobs 1           Run suites one at a time
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

# _test_default_jobs: the CPU count rounded down to a multiple of 4 (10 -> 8),
# or the CPU count below 4. An unreadable count runs serially, with a notice.
_test_default_jobs() {
    local n
    n="$(getconf _NPROCESSORS_ONLN 2>/dev/null)" || n=""
    case "$n" in
        ''|*[!0-9]*|0)
            echo "ℹ️  [Test Runner] CPU count unreadable; running suites one at a time (set 'jobs <n>' to override)." >&2
            echo 1; return 0 ;;
    esac
    if [ "$n" -ge 4 ]; then echo $(( n / 4 * 4 )); else echo "$n"; fi
}

# _test_stop <pid>…: stops running suites with everything they started (each
# runs in its own process group).
_test_stop() {
    local p
    for p in "$@"; do kill -TERM -- "-$p" 2>/dev/null || kill -TERM "$p" 2>/dev/null; done
    # A stopped suite exits non-zero by design; under `set -e` that must not end the trap.
    for p in "$@"; do wait "$p" 2>/dev/null || :; done
}

cmd_test() {
    # Exported by the `aapp` dispatcher, which asserts repository membership (P-33).
    local repo_root="$REPO_ROOT"
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
    local verb_mode=0
    local verb_names=()
    local jobs=""

    while [ $# -gt 0 ]; do
        case "$1" in
            list)   mode="list" ;;
            strict) strict=1 ;;
            bail)   bail=1 ;;
            quiet)  quiet=1 ;;
            verb)   verb_mode=1 ;;
            jobs)
                case "${2:-}" in
                    ''|*[!0-9]*|0) echo "❌ [Test Runner] 'jobs' needs a positive number: aapp test jobs <n>." >&2; return 1 ;;
                esac
                jobs="$2"; shift
                ;;
            help)
                cmd_test_help
                return 0
                ;;
            *)
                if [ "$verb_mode" -eq 1 ]; then
                    verb_names+=("$1")
                else
                    suite_filters+=("$1")
                fi
                ;;
        esac
        shift
    done

    # Set strict environment variable if requested
    if [ "$strict" -eq 1 ]; then
        export AAPP_TEST_SANDBOX_STRICT=1
    fi

    # 3. Discover test suites: flat suites, then contract-derived verb suites
    #    (P-34 §2.4). Two passes keep each set addressable on its own.
    local all_suites=()
    while IFS= read -r f; do
        [ -n "$f" ] && all_suites+=("$f")
    done < <(find "$test_dir" -maxdepth 1 -name '*_test.sh' | sort)

    # Verb suites with their parts right after them: `<verb>.sh`, then
    # `<verb>.<part>.sh` (P-68); sorting without `.sh` puts `draft` before `draft.x`.
    local verb_suites=()
    if [ -d "$test_dir/verbs" ]; then
        while IFS= read -r f; do
            [ -n "$f" ] && verb_suites+=("$f.sh")
        done < <(find "$test_dir/verbs" -maxdepth 1 -name '*.sh' | sed 's/\.sh$//' | LC_ALL=C sort)
    fi

    if [ ${#all_suites[@]} -eq 0 ] && [ ${#verb_suites[@]} -eq 0 ]; then
        echo "ℹ️  No test suites found in '$test_dir'."
        return 0
    fi

    # Select suites
    local selected_suites=()
    if [ "$verb_mode" -eq 1 ]; then
        if [ ${#suite_filters[@]} -gt 0 ]; then
            echo "❌ [Test Runner] 'verb' selects verb suites only; flat suite names cannot follow it." >&2
            return 1
        fi
        if [ ${#verb_names[@]} -eq 0 ]; then
            selected_suites=("${verb_suites[@]}")
        else
            local vn
            for vn in "${verb_names[@]}"; do
                if [ ! -f "$test_dir/verbs/$vn.sh" ]; then
                    echo "❌ [Test Runner] No verb suite 'tests/verbs/$vn.sh'." >&2
                    echo "   Run 'aapp test list' to view available suites." >&2
                    return 1
                fi
                selected_suites+=("$test_dir/verbs/$vn.sh")
                local part
                for part in "$test_dir/verbs/$vn".*.sh; do
                    [ -f "$part" ] && selected_suites+=("$part")
                done
            done
        fi
        if [ ${#selected_suites[@]} -eq 0 ]; then
            echo "❌ [Test Runner] No verb suites found in '$test_dir/verbs'." >&2
            return 1
        fi
    elif [ ${#suite_filters[@]} -eq 0 ]; then
        selected_suites=("${all_suites[@]}" "${verb_suites[@]}")
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

    # Verb suites are labelled verb/<name> so the two sets stay distinguishable.
    suite_label() {
        case "$1" in
            "$test_dir"/verbs/*) local v="${1##*/}"; echo "verb/${v%.sh}" ;;
            *) echo "${1##*/}" ;;
        esac
    }

    # 4. Handle list mode
    if [ "$mode" = "list" ]; then
        echo "============================================================"
        echo "  📋 Available AAPP Test Suites (${#selected_suites[@]} found)"
        echo "  📍 Directory: $test_dir"
        echo "============================================================"
        for suite in "${selected_suites[@]}"; do
            local bname
            bname="$(suite_label "$suite")"
            local desc=""
            # Extract first comment line after shebang if present
            desc="$(grep -m 1 -E '^#[[:space:]]*Tests:|^#[[:space:]]*Automated' "$suite" 2>/dev/null | sed -E 's/^#[[:space:]]*//' || true)"
            # A part (verb/<verb>.<part>) is listed under its verb (P-68).
            if [[ "$bname" == verb/*.* ]]; then
                printf "      ↳ %s\n" "$bname"
            elif [ -n "$desc" ]; then
                printf "  • \033[1m%-24s\033[0m %s\n" "$bname" "$desc"
            else
                printf "  • \033[1m%-24s\033[0m\n" "$bname"
            fi
        done
        echo ""
        echo "👉 Run all:              aapp test"
        echo "👉 Run specific suite:   aapp test <name>"
        echo "👉 Run one verb suite:   aapp test verb <verb>"
        return 0
    fi

    # 5. Header Banner
    local strict_label="OFF"
    [ "${AAPP_TEST_SANDBOX_STRICT:-0}" = "1" ] && strict_label="ON"
    [ -n "$jobs" ] || jobs="$(_test_default_jobs)"

    echo "============================================================"
    echo "  🧪 AAPP Unified Test Runner"
    echo "  📍 Repository: $repo_root"
    echo "  🎯 Execution:  ${#selected_suites[@]} suites selected | Jobs: $jobs | Sandbox Strict: $strict_label"
    echo "============================================================"
    echo ""

    local suites_passed=0
    local suites_failed=0
    local total_assertions_passed=0
    local total_assertions_failed=0
    local runner_start
    runner_start="$(date +%s)"

    # Summary rows, indexed in selection order.
    local summary_rows=()

    # P-67: up to $jobs suites at once, each in its own process group (set -m)
    # with its output in its own file; a finished suite's output is read and
    # flushed in one write. One trap stops running suites and removes the files.
    local work total=${#selected_suites[@]} next=0 stop=0 i k done_k
    local run_pids=() run_idx=() run_start=()
    work="$(mktemp -d "${TMPDIR:-/tmp}/aapp-test-XXXXXX")" || return 1
    trap '_test_stop "${run_pids[@]}"; rm -rf "$work"' EXIT
    trap '_test_stop "${run_pids[@]}"; rm -rf "$work"; trap - EXIT; exit 130' INT
    trap '_test_stop "${run_pids[@]}"; rm -rf "$work"; trap - EXIT; exit 143' TERM
    set -m
    while [ "$next" -lt "$total" ] || [ ${#run_pids[@]} -gt 0 ]; do
        while [ "$stop" -eq 0 ] && [ "$next" -lt "$total" ] && [ ${#run_pids[@]} -lt "$jobs" ]; do
            ( cd "$repo_root" && exec bash "${selected_suites[$next]}" ) > "$work/$next.out" 2>&1 &
            run_pids+=("$!"); run_idx+=("$next"); run_start+=("$(date +%s)")
            next=$((next + 1))
        done
        if [ "$stop" -eq 1 ] && [ ${#run_pids[@]} -eq 0 ]; then break; fi
        done_k=-1
        for k in "${!run_pids[@]}"; do
            if ! kill -0 "${run_pids[$k]}" 2>/dev/null; then done_k="$k"; break; fi
        done
        if [ "$done_k" -lt 0 ]; then sleep 0.1; continue; fi

        local suite_rc=0
        wait "${run_pids[$done_k]}" || suite_rc=$?
        i="${run_idx[$done_k]}"
        local suite_start="${run_start[$done_k]}"
        run_pids=("${run_pids[@]:0:$done_k}" "${run_pids[@]:$((done_k + 1))}")
        run_idx=("${run_idx[@]:0:$done_k}" "${run_idx[@]:$((done_k + 1))}")
        run_start=("${run_start[@]:0:$done_k}" "${run_start[@]:$((done_k + 1))}")

        local suite="${selected_suites[$i]}" bname suite_out
        bname="$(suite_label "$suite")"
        suite_out="$(cat "$work/$i.out")"
        if [ "$quiet" -eq 0 ]; then printf '%s\n' "$suite_out"; fi

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
            summary_rows[$i]="$row"
            if [ "$quiet" -eq 1 ]; then
                echo "$row"
            fi
        else
            suites_failed=$((suites_failed + 1))
            local row
            row="$(printf "  \033[31m✘\033[0m %-26s (%d passed, %d failed) [%ds] - FAILED (exit %d)" "$bname" "$suite_pass" "$suite_fail" "$suite_duration" "$suite_rc")"
            summary_rows[$i]="$row"
            if [ "$quiet" -eq 1 ]; then
                echo "$row"
                echo "────────────────────────────────────────────────────────────"
                echo "$suite_out"
                echo "────────────────────────────────────────────────────────────"
            fi

            if [ "$bail" -eq 1 ] && [ "$stop" -eq 0 ]; then
                echo ""
                echo "🛑 [Bail] No further suites start after this failure; running ones finish."
                stop=1
            fi
        fi
    done
    set +m
    rm -rf "$work"
    trap - EXIT INT TERM

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
