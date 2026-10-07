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
