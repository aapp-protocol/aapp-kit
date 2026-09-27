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
    grep -qE '^[[:space:]]*###[[:space:]]*🧪[[:space:]]*Required Test Files' "$1" 2>/dev/null
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
