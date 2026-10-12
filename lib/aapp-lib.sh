# shellcheck shell=bash
# ==============================================================================
# AAPP Shared Library (P-37)
#
# Single source for plan-section parsing, glob matching and platform detection,
# sourced by the CLI (`lib/`) and by both hook engines (`.githooks/`).
#
# Purity rule: arguments or stdin in, stdout out. No top-level side effects, no
# `set` options, no reads of the aapp environment, no repository-root
# resolution. Sourcing this file only defines functions.
#
# Layout: lib/aapp-lib.sh is the only authored copy. templates/aapp-lib.sh is a
# tracked symlink to it; `aapp init` installs a real copy into .githooks/.
# ==============================================================================

# Load sentinel. Consumers assert it after sourcing and fail closed without it.
aapp_lib_loaded() {
    return 0
}

# ------------------------------------------------------------------------------
# Plan section parsing
# ------------------------------------------------------------------------------
# Boundary rules (fail-closed by construction, #82):
#   - Headings count only inside `## <emoji> 4.` (the design-locked section).
#   - Fenced code blocks are skipped everywhere; quoted example headings are prose.
#   - Headings match by full name, optionally followed by ` (...)`.
#   - Any other heading (`^#+ `) ends the region.
#   - Blockquote lines (`>`) are never parsed.
#   - The first backticked token after bullet, checkbox and lifecycle marker is the path.
_aapp_plan_section_paths() {
    local file="$1"
    local mode="$2"
    awk -v mode="$mode" '
        /^[[:space:]]*```/ { fence = !fence; next }
        fence { next }
        /^#+[[:space:]]/ {
            region = 0
            if ($0 ~ /^#[[:space:]]/ || $0 ~ /^##[[:space:]]/) {
                in4 = ($0 ~ /^## ([^0-9]*[[:space:]])?4\./)
                next
            }
            if (!in4) next
            if (mode == "targets") {
                if ($0 ~ /^###[[:space:]]*📂[[:space:]]*Target Files[[:space:]]*(\(.*)?$/ ||
                    $0 ~ /^###[[:space:]]*🚨[[:space:]]*Emergency Hotfix Extensions[[:space:]]*(\(.*)?$/ ||
                    $0 ~ /^###[[:space:]]*🧪[[:space:]]*Required Test Files[[:space:]]*(\(.*)?$/) {
                    region = 1
                }
            } else if (mode == "oob") {
                if ($0 ~ /^###[[:space:]]*🛑[[:space:]]*Out of Bounds[[:space:]]*(\(.*)?$/) {
                    region = 1
                }
            } else if (mode == "req_files") {
                if ($0 ~ /^###[[:space:]]*🧪[[:space:]]*Required Test Files[[:space:]]*(\(.*)?$/) {
                    region = 1
                }
            }
            next
        }
        !region { next }
        /^[[:space:]]*>/ { next }
        {
            line = $0
            sub(/^[[:space:]]*-[[:space:]]*(\[[ xX]\][[:space:]]*)?/, "", line)
            sub(/^[[:space:]]*(`?(NEW FILE|MODIFY|DELETE|ADD|REPLACE)`?)?[[:space:]]*->[[:space:]]*/, "", line)
            if (match(line, /`[^`]+`/)) {
                item = substr(line, RSTART + 1, RLENGTH - 2)
                if (item !~ /^(NEW FILE|MODIFY|DELETE|ADD|REPLACE)$/) {
                    print item
                }
            }
        }
    ' "$file"
}

# Write targets: `### 📂 Target Files`, `### 🚨 Emergency Hotfix Extensions`,
# `### 🧪 Required Test Files` (Option A), all inside §4.
parse_plan_target_paths() {
    _aapp_plan_section_paths "$1" targets
}

# Vetoed paths: `### 🛑 Out of Bounds` inside §4.
parse_plan_oob_paths() {
    _aapp_plan_section_paths "$1" oob
}

# Declared test file paths: `### 🧪 Required Test Files` inside §4.
parse_plan_required_test_files() {
    _aapp_plan_section_paths "$1" req_files
}

# Declared test items: `### 🧪 Required Tests` inside §3 (isolates path prefix before `::`).
parse_plan_required_tests() {
    local file="$1"
    awk '
        /^[[:space:]]*```/ { fence = !fence; next }
        fence { next }
        /^#+[[:space:]]/ {
            region = 0
            if ($0 ~ /^#[[:space:]]/ || $0 ~ /^##[[:space:]]/) {
                in3 = ($0 ~ /^## ([^0-9]*[[:space:]])?3\./)
                next
            }
            if (!in3) next
            if ($0 ~ /^###[[:space:]]*🧪[[:space:]]*Required Tests[[:space:]]*(\(.*)?$/) {
                region = 1
            }
            next
        }
        !region { next }
        /^[[:space:]]*>/ { next }
        /^[[:space:]]*-[[:space:]]*\[[ xX]\]/ {
            line = $0
            sub(/^[[:space:]]*-[[:space:]]*\[[ xX]\][[:space:]]*/, "", line)
            sub(/[[:space:]]*->.*$/, "", line)
            if (match(line, /`[^`]+`/)) {
                line = substr(line, RSTART + 1, RLENGTH - 2)
            }
            sub(/::.*$/, "", line)
            gsub(/[[:space:]]/, "", line)
            if (line != "" && !seen[line]++) {
                print line
            }
        }
    ' "$file"
}

# True when the plan carries `### 🧪 Required Test Files` inside §4.
plan_has_required_test_files() {
    awk '
        /^[[:space:]]*```/ { fence = !fence; next }
        fence { next }
        /^#+[[:space:]]/ {
            if ($0 ~ /^#[[:space:]]/ || $0 ~ /^##[[:space:]]/) {
                in4 = ($0 ~ /^## ([^0-9]*[[:space:]])?4\./)
                next
            }
            if (!in4) next
            if ($0 ~ /^###[[:space:]]*🧪[[:space:]]*Required Test Files[[:space:]]*(\(.*)?$/) {
                found = 1
                exit 0
            }
        }
        END { exit !found }
    ' "$1" 2>/dev/null
}

# Verify bidirectional correspondence between §3 and §4 for TDD-declared plans.
# Returns 0 if:
#   - Plan does not declare `### 🧪 Required Test Files` (opted out)
#   - Both sections exist, are non-empty, and bidirectionally match
# Returns 1 and prints diagnostic to stderr if:
#   - Either section is empty or missing
#   - Any §3 test references a file not in §4
#   - Any §4 declared test file has no assertions in §3
validate_plan_tdd_correspondence() {
    local file="$1"
    local diag_prefix="${2:-TDD Verification}"

    if ! plan_has_required_test_files "$file"; then
        return 0
    fi

    local req_files=()
    while IFS= read -r f; do
        [ -n "$f" ] && req_files+=("$f")
    done < <(parse_plan_required_test_files "$file")

    local req_tests=()
    while IFS= read -r t; do
        [ -n "$t" ] && req_tests+=("$t")
    done < <(parse_plan_required_tests "$file")

    if [ ${#req_files[@]} -eq 0 ]; then
        echo "❌ [$diag_prefix Violation] Plan carries '### 🧪 Required Test Files' but declares no test files." >&2
        return 1
    fi

    if [ ${#req_tests[@]} -eq 0 ]; then
        echo "❌ [$diag_prefix Violation] Plan carries '### 🧪 Required Test Files' but has no test assertions under '### 🧪 Required Tests' in §3." >&2
        return 1
    fi

    for t_path in "${req_tests[@]}"; do
        local found=0
        for f_path in "${req_files[@]}"; do
            if [ "$t_path" = "$f_path" ]; then
                found=1
                break
            fi
        done
        if [ "$found" -eq 0 ]; then
            echo "❌ [$diag_prefix Correspondence Violation] §3 test specifies file '$t_path' not declared under §4 '### 🧪 Required Test Files'." >&2
            return 1
        fi
    done

    for f_path in "${req_files[@]}"; do
        local found=0
        for t_path in "${req_tests[@]}"; do
            if [ "$f_path" = "$t_path" ]; then
                found=1
                break
            fi
        done
        if [ "$found" -eq 0 ]; then
            echo "❌ [$diag_prefix Correspondence Violation] §4 declared test file '$f_path' has no assertions under §3 '### 🧪 Required Tests'." >&2
            return 1
        fi
    done

    return 0
}

# Stdin filter: print numbered section `## ... N.` through the next numbered
# section. Used by the frozen-plan design lock.
extract_plan_section() {
    local sec="$1"
    awk -v s="$sec" '
        $0 ~ "^## ([^0-9]*[[:space:]])?" s "\\." { flag=1; print; next }
        $0 ~ "^## ([^0-9]*[[:space:]])?[0-9]+\\." && flag { flag=0 }
        flag { print }
    '
}

# ------------------------------------------------------------------------------
# Glob matching (Target Files / Out of Bounds patterns)
# ------------------------------------------------------------------------------
glob_to_regex() {
    local p="$1"
    # 1. Escape regex metacharacters: \ . + ^ $ ( ) { } |
    p="${p//\\/\\\\}"
    p="${p//./\\.}"
    p="${p//+/\\+}"
    p="${p//^/\\^}"
    p="${p//\$/\\\$}"
    p="${p//(/\\(}"
    p="${p//)/\\)}"
    p="${p//\{/\\\{}"
    p="${p//\}/\\\}}"
    p="${p//|/\\|}"

    # 2. Protect multi-segment globstars using collision-free sentinels
    p="${p//\/\*\*\//__SLASH_GLOBSTAR_SLASH__}"
    # Leading **/
    if [[ "$p" == \*\** ]]; then
        p="${p/#\*\*\//__LEADING_GLOBSTAR_SLASH__}"
    fi
    # Trailing /**
    if [[ "$p" == *\/\*\* ]]; then
        p="${p/%\/\*\*/__SLASH_TRAILING_GLOBSTAR__}"
    fi
    p="${p//\*\*/__GLOBSTAR__}"

    # 3. Translate single-segment wildcard and single-char tokens
    p="${p//\*/[^/]*}"
    p="${p//\?/[^/]}"

    # 4. Expand sentinels into POSIX regex
    p="${p//__SLASH_GLOBSTAR_SLASH__/\/(.*\/)?}"
    p="${p//__LEADING_GLOBSTAR_SLASH__/(.*\/)?}"
    p="${p//__SLASH_TRAILING_GLOBSTAR__/\/(.*)?}"
    p="${p//__GLOBSTAR__/.*}"

    echo "^${p}\$"
}

match_pattern_list() {
    local target="$1"
    shift
    local pattern
    for pattern in "$@"; do
        [ -z "$pattern" ] && continue
        # Tier 1 (Exact Match)
        if [ "$target" = "$pattern" ]; then
            return 0
        fi
        # Tier 2 (Directory Prefix Match)
        if [[ "$pattern" == */ ]]; then
            if [[ "$target" == "$pattern"* ]]; then
                return 0
            fi
        fi
        # Tier 3 (Glob / Regex Match)
        if [[ "$pattern" == *[*?\[]* ]]; then
            local regex
            regex=$(glob_to_regex "$pattern")
            if [[ "$target" =~ $regex ]]; then
                return 0
            fi
        fi
    done
    return 1
}

# ------------------------------------------------------------------------------
# Platform detection
# ------------------------------------------------------------------------------
# aapp_os [uname_s] [proc_version_path]
# Prints linux | darwin | windows | wsl | bsd | unknown. Arguments default to the
# live `uname -s` and /proc/version, so every branch is testable without mocking.
# `wsl` is a GNU userland: treat it like `linux` for tool flavour (e.g. `sed -i`).
aapp_os() {
    local uname_s="${1:-}"
    local proc_version="${2:-/proc/version}"
    [ -z "$uname_s" ] && uname_s="$(uname -s 2>/dev/null)"
    case "$uname_s" in
        Linux*)
            if [ -r "$proc_version" ] && grep -qi 'microsoft' "$proc_version"; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        Darwin*) echo "darwin" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        FreeBSD*|OpenBSD*|NetBSD*|DragonFly*) echo "bsd" ;;
        *) echo "unknown" ;;
    esac
}

# ------------------------------------------------------------------------------
# Plan Commits & Base header parsing and mutation (P-39)
# ------------------------------------------------------------------------------

# parse_plan_commits <plan_file>
# Outputs `<sha> <branch>` pairs, one per line.
# Backticked SHA and parenthesized branch are required; `none` or prose yield nothing.
# Strictly confined to the plan header (before any ## heading).
parse_plan_commits() {
    local pf="$1"
    [ ! -f "$pf" ] && return 0
    local raw_line
    raw_line="$(awk '/^[[:space:]]*```/ { f = !f; next } f { next } /^##[[:space:]]/ { exit } /^[[:space:]]*[*|-]*[[:space:]]*\*\*Commits:\*\*/ { print; exit }' "$pf" 2>/dev/null || true)"
    [ -z "$raw_line" ] && return 0
    local val
    val="$(echo "$raw_line" | sed -E 's/^[[:space:]]*[\*|-]*[[:space:]]*\*\*Commits:\*\*[[:space:]]*//')"
    [ "$val" = "none" ] && return 0
    [ -z "$val" ] && return 0

    # Split by comma and parse each `sha` (branch)
    local item sha branch
    local commit_re='^`([0-9a-fA-F]+)`[[:space:]]*\(([^)]+)\)$'
    local old_ifs="$IFS"
    IFS=','
    for item in $val; do
        item="$(echo "$item" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
        # Must match `sha` (branch)
        if [[ "$item" =~ $commit_re ]]; then
            sha="${BASH_REMATCH[1]}"
            branch="${BASH_REMATCH[2]}"
            echo "$sha $branch"
        fi
    done
    IFS="$old_ifs"
}

# write_plan_commits <plan_file> <commits_prose>
# Updates the * **Commits:** line in the plan header, or inserts it after Base / Status.
# Strictly confined to the plan header (before any ## heading).
write_plan_commits() {
    local pf="$1"
    local commits_val="$2"
    [ ! -f "$pf" ] && return 1

    local has_hdr_commits
    has_hdr_commits="$(awk '/^[[:space:]]*```/ { f = !f; next } f { next } /^##[[:space:]]/ { exit } /^[[:space:]]*[*|-]*[[:space:]]*\*\*Commits:\*\*/ { print "1"; exit }' "$pf" 2>/dev/null || true)"

    if [ "$has_hdr_commits" = "1" ]; then
        awk -v val="$commits_val" '
            /^[[:space:]]*```/ { f = !f; print; next }
            f { print; next }
            !passed && /^##[[:space:]]/ { passed = 1 }
            !passed && !done && /^[[:space:]]*[*|-]*[[:space:]]*\*\*Commits:\*\*/ {
                print "* **Commits:** " val
                done = 1
                next
            }
            { print }
        ' "$pf" > "$pf.tmp" && mv "$pf.tmp" "$pf"
    else
        local has_hdr_base
        has_hdr_base="$(awk '/^[[:space:]]*```/ { f = !f; next } f { next } /^##[[:space:]]/ { exit } /^[[:space:]]*[*|-]*[[:space:]]*\*\*Base:\*\*/ { print "1"; exit }' "$pf" 2>/dev/null || true)"
        if [ "$has_hdr_base" = "1" ]; then
            awk -v val="$commits_val" '
                /^[[:space:]]*```/ { f = !f; print; next }
                f { print; next }
                !passed && /^##[[:space:]]/ {
                    if (!done) { print "* **Commits:** " val; done = 1 }
                    passed = 1
                }
                !passed && !done && /^[[:space:]]*[*|-]*[[:space:]]*\*\*Base:\*\*/ {
                    print
                    print "* **Commits:** " val
                    done = 1
                    next
                }
                { print }
            ' "$pf" > "$pf.tmp" && mv "$pf.tmp" "$pf"
        else
            awk -v val="$commits_val" '
                /^[[:space:]]*```/ { f = !f; print; next }
                f { print; next }
                !passed && /^##[[:space:]]/ {
                    if (!done) { print "* **Commits:** " val; done = 1 }
                    passed = 1
                }
                !passed && !done && /^[[:space:]]*[*|-]*[[:space:]]*\*\*Status:\*\*/ {
                    print
                    print "* **Commits:** " val
                    done = 1
                    next
                }
                { print }
            ' "$pf" > "$pf.tmp" && mv "$pf.tmp" "$pf"
        fi
    fi
}

# write_plan_base <plan_file> <base_prose>
# parse_plan_base <plan_file>
# Outputs the recorded Base SHA, or nothing when the plan was never started
# (no Base line, or `none`). `start` writes Base once and never overwrites it.
parse_plan_base() {
    awk '/^[[:space:]]*```/ { f = !f; next } f { next } /^##[[:space:]]/ { exit }
         /^[[:space:]]*[*|-]*[[:space:]]*\*\*Base:\*\*/ { print; exit }' "$1" 2>/dev/null |
        sed -nE 's/.*\*\*Base:\*\*[[:space:]]*`([0-9a-fA-F]+)`.*/\1/p'
}

# Updates the * **Base:** line in the plan header, or inserts it before Commits / after Status.
# Strictly confined to the plan header (before any ## heading).
write_plan_base() {
    local pf="$1"
    local base_val="$2"
    [ ! -f "$pf" ] && return 1

    local raw_base cur_base
    raw_base="$(awk '/^[[:space:]]*```/ { f = !f; next } f { next } /^##[[:space:]]/ { exit } /^[[:space:]]*[*|-]*[[:space:]]*\*\*Base:\*\*/ { print; exit }' "$pf" 2>/dev/null || true)"
    if [ -n "$raw_base" ]; then
        cur_base="$(echo "$raw_base" | sed -E 's/^.*\*\*Base:\*\*[[:space:]]*//' | tr -d '[:space:]')"
        if [ -n "$cur_base" ] && [ "$cur_base" != "none" ]; then
            return 0
        fi
        awk -v val="$base_val" '
            /^[[:space:]]*```/ { f = !f; print; next }
            f { print; next }
            !passed && /^##[[:space:]]/ { passed = 1 }
            !passed && !done && /^[[:space:]]*[*|-]*[[:space:]]*\*\*Base:\*\*/ {
                print "* **Base:** " val
                done = 1
                next
            }
            { print }
        ' "$pf" > "$pf.tmp" && mv "$pf.tmp" "$pf"
    else
        local has_hdr_commits
        has_hdr_commits="$(awk '/^[[:space:]]*```/ { f = !f; next } f { next } /^##[[:space:]]/ { exit } /^[[:space:]]*[*|-]*[[:space:]]*\*\*Commits:\*\*/ { print "1"; exit }' "$pf" 2>/dev/null || true)"
        if [ "$has_hdr_commits" = "1" ]; then
            awk -v val="$base_val" '
                /^[[:space:]]*```/ { f = !f; print; next }
                f { print; next }
                !passed && /^##[[:space:]]/ {
                    if (!done) { print "* **Base:** " val; done = 1 }
                    passed = 1
                }
                !passed && !done && /^[[:space:]]*[*|-]*[[:space:]]*\*\*Commits:\*\*/ {
                    print "* **Base:** " val
                    done = 1
                }
                { print }
            ' "$pf" > "$pf.tmp" && mv "$pf.tmp" "$pf"
        else
            awk -v val="$base_val" '
                /^[[:space:]]*```/ { f = !f; print; next }
                f { print; next }
                !passed && /^##[[:space:]]/ {
                    if (!done) { print "* **Base:** " val; done = 1 }
                    passed = 1
                }
                !passed && !done && /^[[:space:]]*[*|-]*[[:space:]]*\*\*Status:\*\*/ {
                    print
                    print "* **Base:** " val
                    done = 1
                    next
                }
                { print }
            ' "$pf" > "$pf.tmp" && mv "$pf.tmp" "$pf"
        fi
    fi
}

# find_worktree_holding_plan <plan_id>
# Checks other worktrees' active buffers for <plan_id>.
# Prints the worktree directory holding the plan if found, otherwise returns 1.
find_worktree_holding_plan() {
    local target_id="$1"
    [ -z "$target_id" ] && return 1
    local cur_top
    cur_top="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

    local wt_path wt_line
    while IFS= read -r wt_line; do
        if [[ "$wt_line" == "worktree "* ]]; then
            wt_path="${wt_line#worktree }"
            # Skip current worktree and internal planning/agent/hook worktrees
            case "$wt_path" in
                "$cur_top") continue ;;
                */.plans|*/.agents|*/.githooks) continue ;;
            esac
            local buf
            buf="$(git -C "$wt_path" rev-parse --git-path aapp_active_plan 2>/dev/null || true)"
            # The primary checkout answers relative to itself (P-54: asked from a plan worktree).
            case "$buf" in /*|'') ;; *) buf="$wt_path/$buf" ;; esac
            if [ -n "$buf" ] && [ -f "$buf" ]; then
                local held_id
                held_id="$(tr -d '[:space:]' < "$buf" 2>/dev/null || true)"
                if [ "$held_id" = "$target_id" ] || [ "P-$held_id" = "$target_id" ] || [ "$held_id" = "P-${target_id#P-}" ]; then
                    echo "$wt_path"
                    return 0
                fi
            fi
        fi
    done < <(git worktree list --porcelain 2>/dev/null || true)

    return 1
}

# aapp_held_plans (P-52)
# One line per plan held by ANOTHER worktree's buffer: "<buffer-id><TAB><worktree>".
# Reads `git worktree list` once and each buffer once; skips the current
# worktree, the kit's own worktrees and worktrees whose directory is gone.
aapp_held_plans() {
    local cur_top wt_line wt_path buf held
    cur_top="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
    while IFS= read -r wt_line; do
        case "$wt_line" in
            "worktree "*) wt_path="${wt_line#worktree }" ;;
            *) continue ;;
        esac
        case "$wt_path" in
            "$cur_top"|*/.plans|*/.agents|*/.githooks) continue ;;
        esac
        [ -d "$wt_path" ] || continue
        buf="$(git -C "$wt_path" rev-parse --git-path aapp_active_plan 2>/dev/null)" || continue
        case "$buf" in /*) ;; *) buf="$wt_path/$buf" ;; esac
        [ -f "$buf" ] || continue
        held="$(tr -d '[:space:]' < "$buf" 2>/dev/null)"
        [ -n "$held" ] && printf '%s\t%s\n' "$held" "$wt_path"
    done < <(git worktree list --porcelain 2>/dev/null)
    return 0
}

# aapp_plan_held_by <plan_file> <held_lines> (P-52)
# Prints the worktree holding <plan_file> (by Plan ID or file name, the forms
# find_worktree_holding_plan accepts) and returns 0; returns 1 when not held.
aapp_plan_held_by() {
    local pf="$1" held="$2" pid b h wt
    [ -n "$held" ] && [ -f "$pf" ] || return 1
    pid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*`?([^[:space:]`]+)`?.*/\1/p' "$pf" | head -n 1)"
    b="$(basename "$pf" .md)"
    while IFS="$(printf '\t')" read -r h wt; do
        [ -n "$h" ] || continue
        if [ -n "$pid" ] && { [ "$h" = "$pid" ] || [ "P-$h" = "$pid" ]; }; then
            echo "$wt"; return 0
        fi
        if [ "$h" = "$b" ] || [[ "$b" == "$h-"* ]] || [[ "$b" == "P${h#P-}-"* ]]; then
            echo "$wt"; return 0
        fi
    done <<< "$held"
    return 1
}

# ------------------------------------------------------------------------------
# Commit and changelog modes (P-51)
# ------------------------------------------------------------------------------
# aapp_commit_mode: `atomic` (default) or `microcommits`, from aapp.commitMode.
aapp_commit_mode() {
    local m
    m="$(git config --get aapp.commitMode 2>/dev/null)" || m=atomic
    case "$m" in microcommits) echo microcommits ;; *) echo atomic ;; esac
}

# aapp_changelog_mode: `plan` (default) or `commit`, from aapp.changelogMode.
aapp_changelog_mode() {
    local m
    m="$(git config --get aapp.changelogMode 2>/dev/null)" || m=plan
    case "$m" in commit) echo commit ;; *) echo plan ;; esac
}

# aapp_plan_stamp_modes <plan_file> [sha]
# Records the modes in effect in the plan header (`* **Commit Mode:**`,
# `* **Changelog Mode:**`), inserting them after the Changelog line (or the
# Status line) when absent. With <sha>, a value that differs from the previous
# record also adds a dated §6 line: "<Field> switched to <value> (config) for <sha>."
# The record is data only: nothing reads it to decide anything.
aapp_plan_stamp_modes() {
    local pf="$1" sha="${2:-}" cm clm prev_cm prev_clm today log="" tmp
    [ -f "$pf" ] || return 1
    cm="$(aapp_commit_mode)"; clm="$(aapp_changelog_mode)"
    prev_cm="$(sed -nE 's/^\* \*\*Commit Mode:\*\*[[:space:]]*//p' "$pf" | head -n 1)"
    prev_clm="$(sed -nE 's/^\* \*\*Changelog Mode:\*\*[[:space:]]*//p' "$pf" | head -n 1)"
    today="$(date +%Y-%m-%d)"
    if [ -n "$sha" ]; then
        [ -n "$prev_cm" ] && [ "$prev_cm" != "$cm" ] && log="* **$today:** Commit Mode switched to $cm (config) for $sha."
        [ -n "$prev_clm" ] && [ "$prev_clm" != "$clm" ] && log="${log:+$log
}* **$today:** Changelog Mode switched to $clm (config) for $sha."
    fi
    tmp="$pf.aapp-modes.$$"
    AAPP_CM="* **Commit Mode:** $cm" AAPP_CLM="* **Changelog Mode:** $clm" AAPP_LOG="$log" awk '
        BEGIN { has_cm = 0; has_clm = 0 }
        FNR == NR { if ($0 ~ /^\* \*\*Commit Mode:\*\*/) has_cm = 1; if ($0 ~ /^\* \*\*Changelog Mode:\*\*/) has_clm = 1
                    if ($0 ~ /^\* \*\*Changelog:\*\*/) anchor_cl = 1; next }
        /^\* \*\*Commit Mode:\*\*/ { print ENVIRON["AAPP_CM"]; next }
        /^\* \*\*Changelog Mode:\*\*/ { print ENVIRON["AAPP_CLM"]; next }
        { print }
        !ins && ((anchor_cl && /^\* \*\*Changelog:\*\*/) || (!anchor_cl && /^\* \*\*Status:\*\*/)) {
            if (!has_cm) print ENVIRON["AAPP_CM"]; if (!has_clm) print ENVIRON["AAPP_CLM"]; ins = 1 }
        /^## 📦 6\. Change Log/ && ENVIRON["AAPP_LOG"] != "" && !logged { pending = 1 }
        pending && /^\*Tracks how/ { print ENVIRON["AAPP_LOG"]; pending = 0; logged = 1 }
        END { }
    ' "$pf" "$pf" > "$tmp" && mv "$tmp" "$pf" || { rm -f "$tmp"; return 1; }
    if [ -n "$log" ] && ! grep -qF "switched to" "$pf"; then
        printf '%s\n' "$log" >> "$pf"
    fi
}

# ------------------------------------------------------------------------------
# Plan worktrees (P-54)
# ------------------------------------------------------------------------------
# aapp_branch_ref <name>: the ref to branch from for <name>: the local branch,
# else the first remote-tracking `<remote>/<name>`; nothing when neither exists.
aapp_branch_ref() {
    local name="$1" r
    [ -n "$name" ] || return 1
    if git show-ref --verify --quiet "refs/heads/$name"; then echo "$name"; return 0; fi
    r="$(git for-each-ref --format='%(refname:short)' "refs/remotes/*/$name" | head -n 1)"
    [ -n "$r" ] && { echo "$r"; return 0; }
    return 1
}

# aapp_dev_branch: the first aapp.devBranch candidate (space-separated, default
# `develop dev development`, as the pre-commit hook reads it) that exists locally
# or on a remote; empty when none does. Callers decide on a fallback.
aapp_dev_branch() {
    local cands c
    cands="$(git config --get aapp.devBranch 2>/dev/null)" || cands="develop dev development"
    for c in $cands; do
        if aapp_branch_ref "$c" >/dev/null; then echo "$c"; return 0; fi
    done
    return 0
}

# aapp_render_plan_template <template> <plan_id> <slug> <repo>: fills {id}
# (`P51`), {num} (`51`), {slug} and {repo}.
aapp_render_plan_template() {
    local out="$1" num="${2#P-}" slug="$3" repo="$4"
    out="${out//\{id\}/P$num}"; out="${out//\{num\}/$num}"
    out="${out//\{slug\}/$slug}"; out="${out//\{repo\}/$repo}"
    printf '%s\n' "$out"
}

# aapp_abs_path <path> [base]: <path> made absolute against [base] (default: the
# current directory), `.` and `..` resolved lexically; the path need not exist.
aapp_abs_path() {
    local p="$1" base="${2:-$PWD}" part out=() IFS=/
    case "$p" in /*) ;; *) p="$base/$p" ;; esac
    for part in $p; do
        case "$part" in
            ''|.) ;;
            ..) [ ${#out[@]} -gt 0 ] && unset 'out[${#out[@]}-1]' ;;
            *) out+=("$part") ;;
        esac
    done
    printf '/%s\n' "${out[*]}"
}

# aapp_rel_path <from_dir> <to_path>: <to_path> relative to <from_dir>; both absolute.
aapp_rel_path() {
    local from to common up="" rest
    from="$(aapp_abs_path "$1")"; to="$(aapp_abs_path "$2")"
    common="$from"
    while [ "$common" != "/" ] && [ "${to#"$common"/}" = "$to" ] && [ "$to" != "$common" ]; do
        common="${common%/*}"; [ -n "$common" ] || common="/"
        up="../$up"
    done
    if [ "$to" = "$common" ]; then rest=""; elif [ "$common" = "/" ]; then rest="${to#/}"; else rest="${to#"$common"/}"; fi
    up="${up%/}"
    if [ -n "$up" ] && [ -n "$rest" ]; then echo "$up/$rest"
    elif [ -n "$up" ]; then echo "$up"
    elif [ -n "$rest" ]; then echo "$rest"
    else echo "."; fi
}

# parse_plan_worktree <plan_file>: "<path><TAB><branch>" from the header's
# `* **Worktree:** <path> (<branch>)`; the path is relative to the primary checkout.
parse_plan_worktree() {
    awk '/^##[[:space:]]/ { exit } /^\* \*\*Worktree:\*\*/ { print; exit }' "$1" 2>/dev/null |
        sed -nE 's/^\* \*\*Worktree:\*\*[[:space:]]*(.+)[[:space:]]+\(([^)]+)\)[[:space:]]*$/\1\t\2/p'
}

# ------------------------------------------------------------------------------
# Plan branch integration (P-55): read-only helpers; the engines that change the
# repository live in cmd_plan.sh.
# ------------------------------------------------------------------------------
# count_plan_emergency_hotfixes <plan_file>: issue IDs in the header's
# append-only `* **Emergency Hotfixes:**` line (P-52).
count_plan_emergency_hotfixes() {
    awk '/^##[[:space:]]/ { exit } /^\* \*\*Emergency Hotfixes:\*\*/ { print; exit }' "$1" 2>/dev/null |
        issue_id_refs | wc -l | tr -d ' '
}

# resolve_plan_integrate_target <plan_file>: the branch the plan integrates into,
# per aapp.integrateTarget: `parent` (default; the branch in `* **Base:**`), `dev`
# (the development branch) or an explicit branch name. Fails when none resolves.
resolve_plan_integrate_target() {
    local mode t
    mode="$(git config --get aapp.integrateTarget 2>/dev/null)" || mode=parent
    case "$mode" in
        parent|'') t="$(awk '/^##[[:space:]]/ { exit } /^\* \*\*Base:\*\*/ { print; exit }' "$1" 2>/dev/null |
                       sed -nE 's/^\* \*\*Base:\*\*[[:space:]]*`[0-9a-fA-F]+`[[:space:]]*\(([^)]+)\).*/\1/p')" ;;
        dev)       t="$(aapp_dev_branch)" ;;
        *)         t="$mode" ;;
    esac
    case "$t" in ''|detached) return 1 ;; esac
    echo "$t"
}

# plan_base_branch <plan_file>: the plan's parent branch, the one it was cut
# from (named in `* **Base:**`); nothing for a plan never started.
plan_base_branch() {
    local t
    t="$(awk '/^##[[:space:]]/ { exit } /^\* \*\*Base:\*\*/ { print; exit }' "$1" 2>/dev/null |
        sed -nE 's/^\* \*\*Base:\*\*[[:space:]]*`[0-9a-fA-F]+`[[:space:]]*\(([^)]+)\).*/\1/p')"
    case "$t" in ''|detached) return 0 ;; esac
    echo "$t"
}

# check_worktree_ignored_files <worktree>: sensitive ignored files a removal
# would delete (`.env*`, `*.pem`, `*.key`, `*secret*`), one path per line.
check_worktree_ignored_files() {
    local line p b
    while IFS= read -r line; do
        case "$line" in '!! '*) p="${line#!! }" ;; *) continue ;; esac
        p="${p%/}"; b="${p##*/}"
        case "$b" in .env*|*.pem|*.key|*secret*) echo "$p" ;; esac
    done < <(git -C "$1" status --porcelain --ignored --untracked-files=all 2>/dev/null)
}

# write_plan_worktree <plan_file> <value>: sets `* **Worktree:** <value>` in the
# header, replacing it or inserting it after Base (else after Status).
write_plan_worktree() {
    local pf="$1" tmp="$1.aapp-wt.$$"
    AAPP_LINE="* **Worktree:** $2" awk '
        FNR == NR { if ($0 ~ /^##[[:space:]]/) hdr_done = 1
                    if (!hdr_done && $0 ~ /^\* \*\*Worktree:\*\*/) has = 1
                    if (!hdr_done && $0 ~ /^\* \*\*Base:\*\*/) has_base = 1; next }
        /^##[[:space:]]/ { passed = 1 }
        !passed && has && /^\* \*\*Worktree:\*\*/ { print ENVIRON["AAPP_LINE"]; next }
        { print }
        !passed && !has && !done && ((has_base && /^\* \*\*Base:\*\*/) || (!has_base && /^\* \*\*Status:\*\*/)) {
            print ENVIRON["AAPP_LINE"]; done = 1 }
    ' "$pf" "$pf" > "$tmp" && mv "$tmp" "$pf" || { rm -f "$tmp"; return 1; }
}

# ------------------------------------------------------------------------------
# Group plans (P-64)
# ------------------------------------------------------------------------------
# aapp_is_group_plan <plan>: the title heading marks a group plan.
aapp_is_group_plan() { head -n 1 "$1" 2>/dev/null | grep -qE '^# 🧩 Group Plan P-[0-9]+:'; }

# parse_plan_field <plan> <Field>: the value of `* **<Field>:**` in the plan header.
parse_plan_field() {
    AAPP_FIELD="$2" awk '/^##[[:space:]]/ { exit }
        index($0, "* **" ENVIRON["AAPP_FIELD"] ":**") == 1 {
            sub(/^\* \*\*[^*]+:\*\*[[:space:]]*/, ""); print; exit }' "$1" 2>/dev/null
}

# write_plan_field <plan> <Field> <value> [<after-Field>]: sets `* **<Field>:** <value>`
# in the header, replacing it or inserting it after <after-Field> (default Status);
# an empty value removes the line.
write_plan_field() {
    local pf="$1" tmp="$1.aapp-field.$$"
    AAPP_FIELD="$2" AAPP_VAL="$3" AAPP_AFTER="${4:-Status}" awk '
        BEGIN { key = "* **" ENVIRON["AAPP_FIELD"] ":**"; after = "* **" ENVIRON["AAPP_AFTER"] ":**"
                line = (ENVIRON["AAPP_VAL"] == "") ? "" : key " " ENVIRON["AAPP_VAL"] }
        FNR == NR { if ($0 ~ /^##[[:space:]]/) hdr = 1; if (!hdr && index($0, key) == 1) has = 1; next }
        /^##[[:space:]]/ { passed = 1 }
        !passed && has && index($0, key) == 1 { if (line != "") print line; next }
        { print }
        !passed && !has && !done && line != "" && index($0, after) == 1 { print line; done = 1 }
    ' "$pf" "$pf" > "$tmp" && mv "$tmp" "$pf" || { rm -f "$tmp"; return 1; }
}

# group_members <group-plan>: the member IDs, one per line.
group_members() {
    parse_plan_field "$1" Members | tr ',' '\n' | awk '{ gsub(/^[[:space:]]+|[[:space:]]+$/, "") } /^P-[0-9]+$/'
}

# group_set_member <group-plan> <id> add|remove: updates the `* **Members:**` list.
group_set_member() {
    local list
    list="$(group_members "$1" | awk -v id="$2" '$0 != id')"
    [ "$3" = add ] && list="$(printf '%s\n%s\n' "$list" "$2")"
    list="$(printf '%s\n' "$list" | awk 'NF' | paste -sd, - | sed 's/,/, /g')"
    write_plan_field "$1" Members "${list:-none}"
}

# ------------------------------------------------------------------------------
# Shared documentation files (P-48)
# ------------------------------------------------------------------------------
# Files every plan may update. They never make two in-flight plans collide, and
# the pre-commit hook builds its always-allowed list from the same names.
# Dependency manifests are always allowed to commit but are NOT shared docs:
# two plans editing them is a real collision.

# aapp_shared_docs_regex -> ERE alternation of shared doc basenames.
aapp_shared_docs_regex() {
    printf '%s\n' 'CHANGELOG\.md|README\.md|MANUAL\.md|CHEATSHEET\.md|CODEMAP\.md|ARCHITECTURE\.md|ISSUES\.md'
}

# aapp_is_shared_doc <path> -> 0 when the path's basename is a shared doc.
aapp_is_shared_doc() {
    local base="${1##*/}"
    printf '%s\n' "$base" | grep -qE "^($(aapp_shared_docs_regex))$"
}

# ------------------------------------------------------------------------------
# Plan-declared changelog entry (P-48)
# ------------------------------------------------------------------------------
# A plan header line `* **Changelog:** <Added|Changed|Fixed>: <text>` declares
# the plan's single CHANGELOG.md entry, rendered as `- <text> (`<plan-id>`)`.

# aapp_plan_changelog_decl <plan-file> -> "<Section>|<text>"; fails when the
# field is missing or malformed.
aapp_plan_changelog_decl() {
    local line section text
    line="$(grep -m 1 -E '^[[:space:]]*\*[[:space:]]*\*\*Changelog:\*\*' "$1" 2>/dev/null)" || return 1
    line="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*\*[[:space:]]*\*\*Changelog:\*\*[[:space:]]*//; s/[[:space:]]+$//')"
    case "$line" in
        Added:*|Changed:*|Fixed:*) ;;
        *) return 1 ;;
    esac
    section="${line%%:*}"
    text="${line#*:}"
    text="${text#"${text%%[![:space:]]*}"}"
    [ -n "$text" ] || return 1
    printf '%s|%s\n' "$section" "$text"
}

# aapp_render_changelog_bullet <text> <plan-id> -> the bullet line.
aapp_render_changelog_bullet() {
    printf -- '- %s (`%s`)\n' "$1" "$2"
}

# aapp_changelog_plan_line <plan-id> < changelog -> the bullet under
# `## [Unreleased]` that carries `(`<plan-id>`)`; fails when there is none.
aapp_changelog_plan_line() {
    awk -v tag="(\`$1\`)" '
        /^## / { in_unrel = ($0 ~ /^## \[Unreleased\]/); next }
        in_unrel && /^[-*] / && index($0, tag) { print; found = 1; exit }
        END { exit found ? 0 : 1 }
    '
}

# ---- Issue ids (P-79) ----
# The one definition of what an issue id is: nothing outside this section
# spells out its pattern (tests/issue_id_test.sh::test_no_id_pattern_outside).
#
# An id is `#` followed by its body, in one of two forms:
#   digits                 #46        the kit's counter, or a tracker that numbers
#   KEY-digits             #PROJ-101  a tracker's own key: a capital letter, then
#                                     capitals or digits, a dash, digits
# Written without the `#` on the command line (`aapp issue fix 46`); a key typed
# in lowercase is uppercased. `ISSUE-46` is read as #46.
AAPP_ISSUE_ID_BODY_RE='([0-9]+|[A-Z][A-Z0-9]*-[0-9]+)'
# A written id; the same, or a bare or ISSUE- number as older ledgers have them;
# and an id that carries its prefix.
AAPP_ISSUE_REF_RE="#(${AAPP_ISSUE_ID_BODY_RE})"
AAPP_ISSUE_REF_LOOSE_RE="((#|ISSUE-)?[0-9]+|#(${AAPP_ISSUE_ID_BODY_RE}))"
AAPP_ISSUE_REF_PREFIXED_RE="((#|ISSUE-)[0-9]+|#(${AAPP_ISSUE_ID_BODY_RE}))"

# issue_id_body <text> -> the id's body, normalised (46, #46, `#046`, ISSUE-46
# all give 46; PROJ-101, #PROJ-101 and proj-101 give PROJ-101). Fails, naming
# the accepted forms, for anything else.
issue_id_body() {
    local raw="$1" n num
    n="${raw//\`/}"
    n="${n#\#}"
    num="$n"
    case "$num" in ISSUE-*|issue-*) num="${num#*-}" ;; esac
    case "$num" in
        ''|*[!0-9]*) ;;
        *) printf '%s\n' "$((10#$num))"; return 0 ;;
    esac
    n="$(printf '%s' "$n" | tr '[:lower:]' '[:upper:]')"
    if printf '%s\n' "$n" | grep -qxE '[A-Z][A-Z0-9]*-[0-9]+'; then
        printf '%s\n' "$n"; return 0
    fi
    echo "❌ [Issue] Not an issue ID: '$raw' (use a number or a tracker's key, e.g. 46 or PROJ-101)." >&2
    return 1
}

# issue_id_normalize <text> -> the id as it is written: #<body>.
issue_id_normalize() {
    local b
    b="$(issue_id_body "$1")" || return 1
    printf '#%s\n' "$b"
}

# issue_id_valid <text>: true for one well-formed id, with or without `#`.
issue_id_valid() { issue_id_body "$1" >/dev/null 2>&1; }

# issue_id_is_numeric <id>: true for an id the kit's counter could have issued.
issue_id_is_numeric() {
    local b="${1#\#}"
    case "$b" in ''|*[!0-9]*) return 1 ;; esac
    return 0
}

# issue_id_refs [<text>] -> the ids written in a line (or in stdin), one per
# line, in order. An id starts at a `#` that begins the text or follows a
# character that is neither `#` nor a letter or digit, and ends before one that
# is not a letter or digit: a Markdown heading and a hex token are not ids.
issue_id_refs() {
    if [ $# -gt 0 ]; then printf '%s\n' "$1"; else cat; fi | AAPP_RE="$AAPP_ISSUE_REF_RE" awk '
        {
            s = $0; pos = 1
            while (match(substr(s, pos), ENVIRON["AAPP_RE"])) {
                st = pos + RSTART - 1; len = RLENGTH
                prev = (st > 1) ? substr(s, st - 1, 1) : ""
                nxt = substr(s, st + len, 1)
                if (prev !~ /[#A-Za-z0-9]/ && nxt !~ /[A-Za-z0-9]/) print substr(s, st, len)
                pos = st + len
            }
        }'
}

# issue_id_at_start <text> -> the body of the id the text begins with (after
# blanks), as a plan's `Target Issue` value does; fails when it begins otherwise.
issue_id_at_start() {
    local t="$1" first
    t="${t#"${t%%[![:space:]]*}"}"
    case "$t" in '#'*) ;; *) return 1 ;; esac
    first="$(issue_id_refs "$t" | head -n 1)"
    [ -n "$first" ] || return 1
    case "$t" in "$first"*) printf '%s\n' "${first#\#}"; return 0 ;; esac
    return 1
}

# issue_id_sort: stdin id bodies -> sorted and unique: numbers by value, then
# keys by name and number.
issue_id_sort() {
    awk '{ if ($0 ~ /^[0-9]+$/) print "0\t-\t" $0 "\t" $0; else { k = $0; n = $0; sub(/-[0-9]+$/, "", k); sub(/^.*-/, "", n); print "1\t" k "\t" n "\t" $0 } }' |
        sort -t "$(printf '\t')" -k1,1n -k2,2 -k3,3n | cut -f4 | awk '!seen[$0]++'
}

# issue_fix_name <id> -> the file name of the id's mini plan; issue_fix_id
# <name> -> the id a mini plan's file name stands for.
issue_fix_name() { printf 'fix-%s.md\n' "${1#\#}"; }
issue_fix_id() {
    local b="${1##*/}"
    b="${b#fix-}"; b="${b%.md}"
    issue_id_normalize "$b"
}
# ---- end issue ids ----

# ---- Issue ledgers (P-73) ----
# The one accessor of ISSUES.md, done/000-issues-archive.md and
# issues_road_map.md: nothing outside this section reads or writes them
# (tests/issue_ledger_test.sh::test_no_direct_ledger_access).
#
# Active:  | # | Sev | Type | Date | Location | Symptom | Target Plan / Fix | Status | [Branch |]
# Archive: | # | Sev | Type | Date Opened | Date Resolved | Target Commit | Summary | [Branch |]
# `Branch` (P-78) is where the issue's fix must land; a ledger without the
# column, or an empty cell, means the development branch.
# Escaped pipes (\|) inside cells are preserved everywhere.

# Road-map lines: an open entry, and a resolved one (the hook's auto-prune).
# What an id looks like comes from the id section above (P-79).
LEDGER_ROADMAP_OPEN_RE='^[[:space:]]*([0-9]+\.|-[[:space:]]*\[[ ]?\]|\*)[[:space:]]*`?'"$AAPP_ISSUE_REF_LOOSE_RE"
LEDGER_ROADMAP_RESOLVED_RE='^[[:space:]]*([0-9]+\.|-[[:space:]]*\[[ xX]?\]|\*)[[:space:]]*`?'"$AAPP_ISSUE_REF_LOOSE_RE"'`?.*(✅|[Rr]esolved)'
# An active row: its first cell is a written id.
LEDGER_ROW_RE='^[[:space:]]*\|[[:space:]]*`?'"$AAPP_ISSUE_REF_RE"
# A resolved row left in the active ledger (the hook's relocation check).
LEDGER_RESOLVED_ROW_RE='^[[:space:]]*\|[[:space:]]*`?'"$AAPP_ISSUE_REF_LOOSE_RE"'`?.*(✅|[Rr]esolved)'

_ledger_rel() {
    case "$1" in
        issues)  echo "ISSUES.md" ;;
        archive) echo "done/000-issues-archive.md" ;;
        roadmap) echo "issues_road_map.md" ;;
        *)       return 2 ;;
    esac
}

# _ledger_row_regex <n> -> ERE matching the ledger row whose first cell is #<n>.
_ledger_row_regex() {
    printf '^[[:space:]]*\\|[[:space:]]*`?#%s`?[[:space:]]*\\|' "$1"
}

# ledger_path <issues|archive|roadmap> [repo-root] -> the ledger's path. Looks
# in $PLANS_DIR, then <root>/.plans/, then <root>/ (the plans worktree itself,
# or a project keeping its ledgers at the root). When the file is nowhere it
# prints where it would be; callers test `-f`. Fails only with no place to look.
ledger_path() {
    local rel root given
    rel="$(_ledger_rel "$1")" || return 2
    # A caller holding the file itself (the health checks take paths) names it.
    case "$1" in
        issues)  given="${AAPP_LEDGER_ISSUES:-}" ;;
        archive) given="${AAPP_LEDGER_ARCHIVE:-}" ;;
        roadmap) given="${AAPP_LEDGER_ROADMAP:-}" ;;
    esac
    if [ -n "$given" ]; then printf '%s\n' "$given"; return 0; fi
    # A named root is looked at alone; $PLANS_DIR serves the callers without one.
    if [ -n "${2:-}" ]; then
        if [ -f "$2/.plans/$rel" ]; then printf '%s\n' "$2/.plans/$rel"; elif [ -f "$2/$rel" ]; then printf '%s\n' "$2/$rel"; else printf '%s\n' "$2/.plans/$rel"; fi
        return 0
    fi
    if [ -n "${PLANS_DIR:-}" ] && [ -f "$PLANS_DIR/$rel" ]; then
        printf '%s\n' "$PLANS_DIR/$rel"; return 0
    fi
    root="${REPO_ROOT:-}"
    [ -n "$root" ] || root="$(git rev-parse --show-toplevel 2>/dev/null)" || root=""
    if [ -n "$root" ] && [ -f "$root/.plans/$rel" ]; then printf '%s\n' "$root/.plans/$rel"; return 0; fi
    if [ -n "$root" ] && [ -f "$root/$rel" ]; then printf '%s\n' "$root/$rel"; return 0; fi
    if [ -n "${PLANS_DIR:-}" ]; then printf '%s\n' "$PLANS_DIR/$rel"; return 0; fi
    if [ -n "$root" ]; then printf '%s\n' "$root/.plans/$rel"; return 0; fi
    return 1
}

# ledger_commit_paths [issues|archive|roadmap]… -> the named ledgers (all three
# by default) that exist, relative to the plans worktree: for plans_commit and
# the done/abort snapshots.
ledger_commit_paths() {
    local which f rel
    [ $# -gt 0 ] || set -- issues archive roadmap
    for which in "$@"; do
        f="$(ledger_path "$which")" || continue
        [ -f "$f" ] || continue
        # P-74: where a tracker keeps the record the ledgers are ignored files:
        # no verb commits them.
        rel="$(_ledger_rel "$which")"
        git -C "${f%/"$rel"}" check-ignore -q "$rel" 2>/dev/null && continue
        echo "$rel"
    done
    return 0
}

# ledger_rel <issues|archive|roadmap> -> the ledger's path inside the plans worktree.
ledger_rel() { _ledger_rel "$1"; }

# ledger_record_external (P-74): true where a tracker keeps the record: the
# ledgers are in place, in the same format, but ignored by Git (`aapp issue
# list` against a provider that lists issues made them so).
ledger_record_external() {
    local f
    f="$(ledger_path issues)" || return 1
    git -C "${f%/ISSUES.md}" check-ignore -q ISSUES.md 2>/dev/null
}

# ledger_ensure_files (P-74): the three ledgers, empty, where one is missing (a
# clone whose ledgers are ignored has none until its first sync).
ledger_ensure_files() {
    local f
    f="$(ledger_path issues)" || return 1
    if [ ! -f "$f" ]; then
        mkdir -p "$(dirname "$f")" || return 1
        printf '%s\n' '# 🐛 Issues: Active Technical Backlog' '' \
            '| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status | Branch |' \
            '| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |' > "$f" || return 1
    fi
    f="$(ledger_path archive)" || return 1
    if [ ! -f "$f" ]; then
        mkdir -p "$(dirname "$f")" || return 1
        printf '%s\n' '# 🏛️ Master Issue Archive Ledger' '' \
            '| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |' \
            '| :--- | :--- | :--- | :--- | :--- | :--- | :--- |' > "$f" || return 1
    fi
    f="$(ledger_path roadmap)" || return 1
    if [ ! -f "$f" ]; then
        printf '%s\n' '# 🗺️ Issue Priority Board' '' '## 📥 Triage (Incoming / Unsequenced)' > "$f" || return 1
    fi
}

# ledger_replace_row <n> <row>: #<n>'s active row becomes <row> (padded to the
# header's cell count); no other line changes. Returns 3 when there is no row.
ledger_replace_row() {
    local f tmp row
    f="$(ledger_path issues)" || return 1
    [ -f "$f" ] || return 1
    row="$(_ledger_pad_row "$f" "$2")"
    tmp="$f.aapp-row.$$"
    AAPP_RE="$(_ledger_row_regex "$1")" AAPP_ROW="$row" awk '
        !d && $0 ~ ENVIRON["AAPP_RE"] { print ENVIRON["AAPP_ROW"]; d = 1; next } { print }
        END { if (!d) exit 3 }' "$f" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; return 3; }
}

# ledger_drop_row <n>: #<n>'s active row and road-map line go, without a trace
# in the archive (a row the tracker's listing no longer brings).
ledger_drop_row() {
    local f tmp
    f="$(ledger_path issues)" || return 1
    [ -f "$f" ] || return 0
    tmp="$f.aapp-drop.$$"
    grep -v -E "$(_ledger_row_regex "$1")" "$f" > "$tmp" || [ $? -eq 1 ]
    mv "$tmp" "$f"
    roadmap_prune "$1"
}

# roadmap_add_entry <n> <text>: a new issue's line, `- [ ] #<n> -> <text>`, at
# the end of the 📥 Triage section (at the end of the board when it has none).
roadmap_add_entry() {
    local f tmp
    f="$(ledger_path roadmap)" || return 1
    [ -f "$f" ] || return 1
    tmp="$f.aapp-entry.$$"
    AAPP_LINE="- [ ] #$1 -> $2" awk '
        function flush() { for (i = 1; i <= nb; i++) print blank[i]; nb = 0 }
        in_t && /^## / { print ENVIRON["AAPP_LINE"]; flush(); in_t = 0; done = 1 }
        in_t && /^[[:space:]]*$/ { blank[++nb] = $0; next }
        in_t { flush() }
        /^## 📥 Triage/ && !done { in_t = 1 }
        { print }
        END { if (!done) print ENVIRON["AAPP_LINE"]; flush() }
    ' "$f" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; return 1; }
}

# ---- Issue text: description and notes (P-74) ----
# An issue's text has three parts. The symptom is the row's cell. The
# description (the text given when the issue is logged) and the notes (added
# later, dated, with their author) may hold real data from a live system: they
# are never in the ledger, never in Git and never in a tracked file. Without a
# tracker that keeps them they are in a file per project on this machine:
#   ${AAPP_STATE_DIR:-~/.local/state}/aapp/<key>/issues-data.md   (0700 / 0600)
# <key> comes from the remote URL (two clones of one project share the file),
# or from the folder name of a repository with no remote.

# issue_text_file -> the store's path (it may not exist yet).
issue_text_file() {
    local base name url key
    base="${AAPP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}}"
    name="$(git config --get aapp.remote 2>/dev/null)" || name="origin"
    if url="$(git remote get-url "$name" 2>/dev/null)" && [ -n "$url" ]; then
        key="$(printf '%s' "$url" | sed -E 's#^[a-z+]+://##; s#^[^/@]*@##; s#\.git$##')"
    else
        key="$(basename "$(cd "$(git rev-parse --git-common-dir 2>/dev/null)/.." 2>/dev/null && pwd)")"
    fi
    key="$(printf '%s' "$key" | tr -c 'A-Za-z0-9._-' '-' | sed -E 's/-+/-/g; s/^-//; s/-$//')"
    [ -n "$key" ] || key="project"
    printf '%s/aapp/%s/issues-data.md\n' "$base" "$key"
}

# issue_text_add <n> description|note <text> [<author>]: appends one entry.
# Fails, writing nothing, when the store cannot be written (a sandbox).
issue_text_add() {
    local f dir head
    f="$(issue_text_file)"; dir="$(dirname "$f")"
    mkdir -p "$dir" 2>/dev/null && chmod 700 "$dir" 2>/dev/null || return 1
    if [ "$2" = "description" ]; then head="### description"; else head="### note $(date +%Y-%m-%d) ${4:-unknown}"; fi
    ( umask 077
      { printf '## #%s\n%s\n' "$1" "$head"
        # A text line that looks like one of the store's headings is indented.
        printf '%s\n' "$3" | sed -E 's/^(#{2,3} )/ \1/'
        echo; } >> "$f" ) 2>/dev/null || return 1
    chmod 600 "$f" 2>/dev/null || return 1
}

# issue_text_get <n> -> the description and notes of #<n>, in the order they
# were written, each under a line naming it; nothing when there is none.
# Returns 1 when the store exists and cannot be read.
issue_text_get() {
    local f
    f="$(issue_text_file)"
    [ -e "$f" ] || return 0
    [ -r "$f" ] || return 1
    AAPP_HEAD="## #$1" awk '
        /^## #/ { on = ($0 == ENVIRON["AAPP_HEAD"]); next }
        !on { next }
        /^### / { sub(/^### /, ""); if (seen) print ""; print "[" $0 "]"; seen = 1; held = 0; next }
        /^[[:space:]]*$/ { held++; next }
        { for (; held > 0; held--) print ""; if ($0 ~ /^ ###? /) $0 = substr($0, 2); print }
    ' "$f"
}
# ---- end issue text ----

# ledger_row <n> -> the active row of #<n>, as written; fails when there is none.
ledger_row() {
    local f
    f="$(ledger_path issues)" || return 1
    [ -f "$f" ] || return 1
    grep -m 1 -E "$(_ledger_row_regex "$1")" "$f"
}

# ledger_table <issues|archive|roadmap> [repo-root] -> the ledger file as it
# is, for the checks that need its line numbers and layout.
ledger_table() {
    local f
    f="$(ledger_path "$1" "${2:-}")" || return 0
    [ -f "$f" ] || return 0
    cat "$f"
}

# ledger_row_lines [<status>] -> every active row, as written, in file order;
# <status> keeps the rows whose status cell contains it.
ledger_row_lines() {
    local f col
    f="$(ledger_path issues)" || return 0
    [ -f "$f" ] || return 0
    if [ -z "${1:-}" ]; then
        grep -E "$LEDGER_ROW_RE" "$f" 2>/dev/null
        return 0
    fi
    col="$(_ledger_col "$f" "Status")"
    AAPP_COL="${col:-9}" AAPP_STATUS="$1" AAPP_ROW_RE="$LEDGER_ROW_RE" awk '
        $0 ~ ENVIRON["AAPP_ROW_RE"] {
            line = $0; gsub(/\\\|/, "\001", line); split(line, c, "|")
            if (index(c[ENVIRON["AAPP_COL"] + 0], ENVIRON["AAPP_STATUS"]) > 0) print
        }' "$f"
}

# ledger_rows [<status>] -> active rows, one per line, tab-separated: id (#<n>),
# sev, type, date, location, symptom, link, status, source (`local`). <status>
# keeps the rows whose status cell contains it (`Incubated`, `Planned`).
ledger_rows() {
    local f
    f="$(ledger_path issues)" || return 0
    [ -f "$f" ] || return 0
    AAPP_STATUS="${1:-}" AAPP_ROW_RE="$LEDGER_ROW_RE" awk '
        $0 ~ ENVIRON["AAPP_ROW_RE"] {
            line = $0; gsub(/\\\|/, "\001", line)
            k = split(line, c, "|")
            if (k < 10) next
            for (i = 2; i <= 9; i++) { gsub(/^[ \t]+|[ \t]+$/, "", c[i]); gsub(/\001/, "\\|", c[i]) }
            if (ENVIRON["AAPP_STATUS"] != "" && index(c[9], ENVIRON["AAPP_STATUS"]) == 0) next
            gsub(/`/, "", c[2])
            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tlocal\n", c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9]
        }' "$f"
}

# ledger_resolved_rows -> rows left in the active ledger although marked
# resolved (the Relocation Invariant: a resolved row moves to the archive).
ledger_resolved_rows() {
    local f
    f="$(ledger_path issues)" || return 0
    [ -f "$f" ] || return 0
    grep -E "$LEDGER_RESOLVED_ROW_RE" "$f" 2>/dev/null
    return 0
}

# ledger_ids <active|archive|roadmap> -> the issue numbers of one ledger, bare
# integers in file order (`#12`, `` `#012` `` and `ISSUE-12` all give 12).
ledger_ids() {
    local f
    case "$1" in
        active)  f="$(ledger_path issues)" || return 0 ;;
        archive) f="$(ledger_path archive)" || return 0 ;;
        roadmap) f="$(ledger_path roadmap)" || return 0 ;;
        *)       return 2 ;;
    esac
    [ -f "$f" ] || return 0
    # The first cell of a table row, or what follows a road-map line's marker.
    if [ "$1" = "roadmap" ]; then
        awk '{ if (sub(/^[[:space:]]*([0-9]+\.|-[[:space:]]*\[[ xX]?\]|\*)[[:space:]]*/, "")) print }' "$f"
    else
        awk -F'|' '/^[[:space:]]*\|/ { print $2 }' "$f"
    fi | AAPP_RE="^\`?${AAPP_ISSUE_REF_LOOSE_RE}" awk '
        {
            t = $0; gsub(/^[ \t]+/, "", t)
            if (!match(t, ENVIRON["AAPP_RE"])) next
            id = substr(t, RSTART, RLENGTH); gsub(/`/, "", id)
            had_hash = (id ~ /^#/); sub(/^#/, "", id); num = id; sub(/^ISSUE-/, "", num)
            if (num ~ /^[0-9]+$/) { sub(/^0+/, "", num); print (num == "") ? "0" : num }
            else if (had_hash) print id
        }'
}

# ledger_locate <n> -> prints "active", "archive" or nothing.
ledger_locate() {
    local re f
    re="$(_ledger_row_regex "$1")"
    f="$(ledger_path issues)" || f=""
    if [ -n "$f" ] && [ -f "$f" ] && grep -qE "$re" "$f"; then echo "active"; return 0; fi
    f="$(ledger_path archive)" || f=""
    if [ -n "$f" ] && [ -f "$f" ] && grep -qE "$re" "$f"; then echo "archive"; fi
    return 0
}

# Cells are found by the header's column names (P-78), so a ledger with or
# without the `Branch` column reads the same. A cell's position is the one
# awk's split on `|` gives it: the first cell is 2.

# _ledger_col_name <cell> -> the header text a cell's column starts with.
_ledger_col_name() {
    case "$1" in
        link)   echo "Target Plan" ;;
        status) echo "Status" ;;
        branch) echo "Branch" ;;
        commit) echo "Target Commit" ;;
        *)      return 2 ;;
    esac
}

# _ledger_col <file> <header-text> -> the column's position; nothing when the
# table has no such column.
_ledger_col() {
    AAPP_NAME="$2" awk '
        /^[[:space:]]*\|[[:space:]]*#[[:space:]]*\|/ {
            line = $0; gsub(/\\\|/, "\001", line); k = split(line, c, "|")
            for (i = 2; i < k; i++) {
                h = c[i]; gsub(/^[ \t]+|[ \t]+$/, "", h)
                if (index(h, ENVIRON["AAPP_NAME"]) == 1) { print i; exit }
            }
            exit
        }' "$1"
}

# _ledger_add_column <file> <header-text>: a further, last column on the table
# whose header begins with `#`; its cells start empty.
_ledger_add_column() {
    local f="$1" tmp="$1.aapp-col.$$"
    AAPP_NAME="$2" awk '
        !t && /^[[:space:]]*\|[[:space:]]*#[[:space:]]*\|/ { t = 1; sub(/[[:space:]]*$/, ""); print $0 " " ENVIRON["AAPP_NAME"] " |"; next }
        t == 1 && /^[[:space:]]*\|/ {
            sub(/[[:space:]]*$/, "")
            if ($0 ~ /^[[:space:]]*\|[[:space:]]*:---/) print $0 " :--- |"; else print $0 "  |"
            next
        }
        t == 1 { t = 2 }
        { print }
        END { if (!t) exit 3 }
    ' "$f" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; return 3; }
}

# _ledger_pad_row <file> <row> -> the row with empty cells added up to the
# header's count.
_ledger_pad_row() {
    AAPP_ROW="$2" awk '
        /^[[:space:]]*\|[[:space:]]*#[[:space:]]*\|/ && !want { line = $0; gsub(/\\\|/, "", line); want = gsub(/\|/, "|", line) }
        END {
            row = ENVIRON["AAPP_ROW"]; line = row; gsub(/\\\|/, "", line); have = gsub(/\|/, "|", line)
            sub(/[[:space:]]*$/, "", row)
            for (; have < want; have++) row = row "  |"
            print row
        }' "$1"
}

# _ledger_write_cell <file> <n> <position> <value>: returns 3 when #<n> has no
# row there.
_ledger_write_cell() {
    local f="$1" tmp="$1.aapp-cell.$$"
    AAPP_N="$2" AAPP_CELL="$3" AAPP_VALUE="$4" awk '
        {
            line = $0; gsub(/\\\|/, "\001", line)
            if (!done && line ~ ("^[[:space:]]*\\|[[:space:]]*`?#" ENVIRON["AAPP_N"] "`?[[:space:]]*\\|")) {
                k = split(line, c, "|")
                if (k > ENVIRON["AAPP_CELL"] + 0) {
                    c[ENVIRON["AAPP_CELL"] + 0] = " " ENVIRON["AAPP_VALUE"] " "
                    out = c[1]; for (j = 2; j <= k; j++) out = out "|" c[j]
                    gsub(/\001/, "\\|", out); print out; done = 1; next
                }
            }
            print
        }
        END { if (!done) exit 3 }
    ' "$f" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; return 3; }
}

# ledger_add_row <row>: inserts an active row under the table's separator line,
# with as many cells as the header has. Returns 3 when the ledger has no table.
ledger_add_row() {
    local f tmp row
    f="$(ledger_path issues)" || return 1
    [ -f "$f" ] || return 1
    row="$(_ledger_pad_row "$f" "$1")"
    tmp="$f.aapp-add.$$"
    AAPP_ROW="$row" awk '{ print } !d && /^\|[[:space:]]*:---/ { print ENVIRON["AAPP_ROW"]; d = 1 } END { if (!d) exit 3 }' \
        "$f" > "$tmp" || { rm -f "$tmp"; return 3; }
    mv "$tmp" "$f"
}

# ledger_cell <n> link|status|branch|commit [issues|archive] -> the cell of
# #<n>'s row, as written; nothing when the ledger has no such row or column.
ledger_cell() {
    local f name col
    name="$(_ledger_col_name "$2")" || return 2
    f="$(ledger_path "${3:-issues}")" || return 0
    [ -f "$f" ] || return 0
    col="$(_ledger_col "$f" "$name")"
    [ -n "$col" ] || return 0
    AAPP_N="$1" AAPP_COL="$col" awk '
        {
            line = $0; gsub(/\\\|/, "\001", line)
            if (line ~ ("^[[:space:]]*\\|[[:space:]]*`?#" ENVIRON["AAPP_N"] "`?[[:space:]]*\\|")) {
                split(line, c, "|"); v = c[ENVIRON["AAPP_COL"] + 0]
                gsub(/^[ \t]+|[ \t]+$/, "", v); gsub(/\001/, "\\|", v); print v; exit
            }
        }' "$f"
}

# ledger_branch <n> -> the branch named in #<n>'s row, active or archived;
# nothing when none is named (the development branch is meant).
ledger_branch() {
    local b
    b="$(ledger_cell "$1" branch issues)"
    [ -n "$b" ] || b="$(ledger_cell "$1" branch archive)"
    printf '%s' "$b" | tr -d '`'
    [ -z "$b" ] || echo
}

# ledger_branch_map -> the active rows that name a branch, one per line:
# id (#<n>), a tab, the branch.
ledger_branch_map() {
    local f col
    f="$(ledger_path issues)" || return 0
    [ -f "$f" ] || return 0
    col="$(_ledger_col "$f" "Branch")"
    [ -n "$col" ] || return 0
    AAPP_COL="$col" AAPP_ROW_RE="$LEDGER_ROW_RE" awk '
        $0 ~ ENVIRON["AAPP_ROW_RE"] {
            line = $0; gsub(/\\\|/, "\001", line); split(line, c, "|")
            id = c[2]; gsub(/[ \t`]/, "", id); b = c[ENVIRON["AAPP_COL"] + 0]; gsub(/[ \t`]/, "", b)
            if (b != "") print id "\t" b
        }' "$f"
}

# ledger_move_branch <old> <new-cell>: every active row whose Branch cell names
# <old> gets <new-cell> (empty: no branch named). Prints the ids it changed.
ledger_move_branch() {
    local id b
    while IFS="$(printf '\t')" read -r id b; do
        [ "$b" = "$1" ] || continue
        ledger_set_cell "${id#\#}" branch "$2" || return 1
        echo "$id"
    done < <(ledger_branch_map)
}

# ledger_set_cell <n> link|status|branch <value>: the cells of an active row
# that change over its life; observation cells never change. The `Branch`
# column is added by the first write that names a branch. Returns 2 for another
# cell, 3 when #<n> is not an active row.
ledger_set_cell() {
    local n="$1" name cell f
    case "$2" in
        link|status|branch) name="$(_ledger_col_name "$2")" ;;
        *)      echo "❌ [Issue] Only the link, status and branch cells of a row change (not '$2')." >&2; return 2 ;;
    esac
    f="$(ledger_path issues)" || return 1
    [ -f "$f" ] || return 1
    cell="$(_ledger_col "$f" "$name")"
    if [ -z "$cell" ] && [ "$2" = "branch" ]; then
        # No branch named and no column: nothing to write.
        if [ -z "$3" ]; then
            if ledger_row "$n" >/dev/null; then return 0; fi
            return 3
        fi
        _ledger_add_column "$f" "Branch" || return 3
        cell="$(_ledger_col "$f" "$name")"
    fi
    # A table without its header row: the positions the template gives them.
    if [ -z "$cell" ]; then
        case "$2" in link) cell=8 ;; status) cell=9 ;; esac
    fi
    _ledger_write_cell "$f" "$n" "$cell" "$3"
}

# ledger_archive_row <n> <sha>|aborted [summary]: moves the active row to the
# top of the archive and prunes its road-map line. Does not commit. Returns 0
# when moved; fails when the row is not active.
ledger_archive_row() {
    local n="$1" sha="$2" summary="${3:-}"
    local active archive re row today archive_row tmp branch col
    active="$(ledger_path issues)" || return 1
    archive="$(ledger_path archive)" || return 1
    re="$(_ledger_row_regex "$n")"
    branch="$(ledger_cell "$n" branch issues)"

    if [ ! -f "$archive" ]; then
        echo "❌ [Issue] Archive not found: $archive" >&2
        return 1
    fi
    row="$(grep -m 1 -E "$re" "$active" 2>/dev/null)" || {
        echo "❌ [Issue] #$n is not an active row in $active." >&2
        return 1
    }

    today="$(date +%Y-%m-%d)"
    archive_row="$(AAPP_SHA="$sha" AAPP_SUMMARY="$summary" AAPP_TODAY="$today" awk '
        {
            gsub(/\\\|/, "\001")
            n = split($0, c, "|")
            for (i = 1; i <= n; i++) {
                gsub(/^[ \t]+|[ \t]+$/, "", c[i])
                gsub("\001", "\\|", c[i])
            }
            s = ENVIRON["AAPP_SUMMARY"]
            if (s == "") s = "Direct fix (no plan)"
            gsub(/\\\|/, "\001", s); gsub(/\|/, "\001", s); gsub("\001", "\\|", s)
            printf "| %s | %s | %s | %s | %s | `%s` | %s |\n", c[2], c[3], c[4], c[5], ENVIRON["AAPP_TODAY"], ENVIRON["AAPP_SHA"], s
        }' <<< "$row")"
    # The branch the fix landed on travels with the row (P-78).
    if [ -n "$branch" ] && [ -z "$(_ledger_col "$archive" "Branch")" ]; then
        _ledger_add_column "$archive" "Branch" || {
            echo "❌ [Issue] No table header found in $archive." >&2; return 1; }
    fi
    archive_row="$(_ledger_pad_row "$archive" "$archive_row")"

    tmp="$archive.aapp-issue.$$"
    AAPP_ROW="$archive_row" awk '
        { print }
        !done && /^\|[[:space:]]*:---/ { print ENVIRON["AAPP_ROW"]; done = 1 }
        END { if (!done) exit 3 }
    ' "$archive" > "$tmp" || {
        rm -f "$tmp"
        echo "❌ [Issue] No table header separator found in $archive." >&2
        return 1
    }
    mv "$tmp" "$archive"
    if [ -n "$branch" ]; then
        col="$(_ledger_col "$archive" "Branch")"
        _ledger_write_cell "$archive" "$n" "$col" "$branch" || return 1
    fi

    tmp="$active.aapp-issue.$$"
    # grep -v exits 1 when every line matched; an emptied table is still valid.
    grep -v -E "$re" "$active" > "$tmp" || [ $? -eq 1 ]
    mv "$tmp" "$active"

    roadmap_prune "$n"
    return 0
}

# ledger_relink <old-rel-path> <new-rel-path> (P-50): rewrites the link target
# `](<old>)` -> `](<new>)` in the active rows' Target Plan / Fix cell (the 7th
# cell; observation cells never change) and in the road map's lines. Prints the
# number of links rewritten; non-zero only on a write failure.
ledger_relink() {
    local old="$1" new="$2" f tmp count=0 n col
    f="$(ledger_path issues)" || f=""
    if [ -n "$f" ] && [ -f "$f" ]; then
        tmp="$f.aapp-relink.$$"
        col="$(_ledger_col "$f" "Target Plan")"
        AAPP_COL="${col:-8}" AAPP_OLD="]($old)" AAPP_NEW="]($new)" AAPP_ROW_RE="$LEDGER_ROW_RE" awk '
            function swap(s,    out, i, o) {
                o = ENVIRON["AAPP_OLD"]; out = ""
                while ((i = index(s, o)) > 0) { out = out substr(s, 1, i - 1) ENVIRON["AAPP_NEW"]; s = substr(s, i + length(o)); n++ }
                return out s
            }
            $0 ~ ENVIRON["AAPP_ROW_RE"] {
                line = $0; gsub(/\\\|/, "\001", line)
                k = split(line, c, "|")
                p = ENVIRON["AAPP_COL"] + 0
                if (k > p) {
                    c[p] = swap(c[p]); out = c[1]
                    for (j = 2; j <= k; j++) out = out "|" c[j]
                    gsub(/\001/, "\\|", out); print out; next
                }
            }
            { print }
            END { print n + 0 > "/dev/stderr" }
        ' "$f" > "$tmp" 2> "$tmp.n" || { rm -f "$tmp" "$tmp.n"; return 1; }
        n="$(cat "$tmp.n")"; rm -f "$tmp.n"
        mv "$tmp" "$f" || return 1
        count=$((count + n))
    fi
    f="$(ledger_path roadmap)" || f=""
    if [ -n "$f" ] && [ -f "$f" ]; then
        n="$(grep -oF "]($old)" "$f" | wc -l | tr -d ' ')"
        if [ "$n" -gt 0 ]; then
            tmp="$f.aapp-relink.$$"
            AAPP_OLD="]($old)" AAPP_NEW="]($new)" awk '
                { s = $0; out = ""; o = ENVIRON["AAPP_OLD"]
                  while ((i = index(s, o)) > 0) { out = out substr(s, 1, i - 1) ENVIRON["AAPP_NEW"]; s = substr(s, i + length(o)) }
                  print out s }
            ' "$f" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; return 1; }
            count=$((count + n))
        fi
    fi
    echo "$count"
}

# roadmap_entries [<cap>] -> the road map's open lines, in file order (the
# template's placeholder and resolved lines left out); at most <cap> of them.
roadmap_entries() {
    local f
    f="$(ledger_path roadmap)" || return 0
    [ -f "$f" ] || return 0
    grep -E "$LEDGER_ROADMAP_OPEN_RE" "$f" 2>/dev/null | grep -v '\[Feature or Problem Title\]' | grep -v -E '✅|[Rr]esolved|DONE' |
        if [ -n "${1:-}" ]; then head -n "$1"; else cat; fi
    return 0
}

# roadmap_entries_by_branch <current> <dev> [<cap>] (P-78) -> the same lines,
# each with its issue's branch, those of <current> first. While no issue names
# a branch every issue is on the development branch: the lines are as they are.
roadmap_entries_by_branch() {
    local map
    map="$(ledger_branch_map)"
    if [ -z "$map" ]; then roadmap_entries "${3:-}"; return 0; fi
    roadmap_entries | AAPP_MAP="$map" AAPP_CUR="$1" AAPP_DEV="$2" AAPP_RE="$AAPP_ISSUE_REF_RE" awk '
        BEGIN { n = split(ENVIRON["AAPP_MAP"], m, "\n"); for (i = 1; i <= n; i++) { split(m[i], kv, "\t"); br[kv[1]] = kv[2] } }
        {
            id = ""; if (match($0, ENVIRON["AAPP_RE"])) id = substr($0, RSTART, RLENGTH)
            b = (id in br) ? br[id] : ENVIRON["AAPP_DEV"]
            line = $0 ((b != "") ? "  (branch: " b ")" : "")
            if (b == ENVIRON["AAPP_CUR"]) print line; else rest[++r] = line
        }
        END { for (i = 1; i <= r; i++) print rest[i] }' |
        if [ -n "${3:-}" ]; then head -n "$3"; else cat; fi
    return 0
}

# roadmap_blockers -> the issue numbers queued under 🧱 Plan Blockers, in order.
roadmap_blockers() {
    local f
    f="$(ledger_path roadmap)" || return 0
    [ -f "$f" ] || return 0
    awk '/^## 🧱 Plan Blockers/ { q = 1; next } /^## / { q = 0 } q' "$f" |
        sed -nE "s/^[[:space:]]*-[[:space:]]*\[[ ]?\][[:space:]]*#(${AAPP_ISSUE_ID_BODY_RE}).*/\1/p"
}

# roadmap_add_blocker <n> <text> <plan-id>: appends to 🧱 Plan Blockers, creating
# the subheader at the top of the board (before the first `## `).
roadmap_add_blocker() {
    local rm line tmp
    rm="$(ledger_path roadmap)" || return 1
    [ -f "$rm" ] || return 1
    line="- [ ] #$1 -> $2 (blocks $3)"
    tmp="$rm.aapp-queue.$$"
    if grep -q '^## 🧱 Plan Blockers' "$rm"; then
        AAPP_LINE="$line" awk '
            function flush() { for (i = 1; i <= nb; i++) print blank[i]; nb = 0 }
            in_q && /^## / { print ENVIRON["AAPP_LINE"]; flush(); in_q = 0; done = 1 }
            in_q && /^[[:space:]]*$/ { blank[++nb] = $0; next }
            in_q { flush() }
            /^## 🧱 Plan Blockers/ { in_q = 1 }
            { print }
            END { if (in_q && !done) print ENVIRON["AAPP_LINE"]; flush() }
        ' "$rm" > "$tmp"
    else
        AAPP_LINE="$line" awk '
            !done && /^## / { print "## 🧱 Plan Blockers"; print ENVIRON["AAPP_LINE"]; print ""; done = 1 }
            { print }
            END { if (!done) { print ""; print "## 🧱 Plan Blockers"; print ENVIRON["AAPP_LINE"] } }
        ' "$rm" > "$tmp"
    fi
    mv "$tmp" "$rm"
}

# roadmap_prune <n>|resolved: removes #<n>'s line, or every line marked
# resolved. An emptied board is still valid.
roadmap_prune() {
    local f tmp re
    f="$(ledger_path roadmap)" || return 0
    [ -f "$f" ] || return 0
    if [ "$1" = "resolved" ]; then
        re="$LEDGER_ROADMAP_RESOLVED_RE"
    else
        re="^[[:space:]]*([0-9]+\.|[-*][[:space:]]*\[[ xX]?\]|\*)[[:space:]]*\`?#$1([^0-9]|\$)"
    fi
    tmp="$f.aapp-prune.$$"
    # grep -v exits 1 when every line matched.
    grep -v -E "$re" "$f" > "$tmp" || [ $? -eq 1 ]
    mv "$tmp" "$f"
}
# ---- end issue ledgers ----
