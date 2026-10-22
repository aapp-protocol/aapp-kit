#!/usr/bin/env bash
# ==============================================================================
# Asymmetric Agent Planning Protocol (AAPP) - Write-Time Blast Radius Guard
#
# Hook for Claude Code / Cursor / AI IDE PreToolUse write events:
# - Self-protection: Blocks AI from tampering with enforcement hooks and rules
# - Deterministic Blast Radius: Validates target file against .plans/current/*.md
# - Fail-open: Never bricks the agent on invalid JSON or when no active plans exist
# ==============================================================================
set -e

# Escape hatch
if [ "${SKIP_BLAST_RADIUS:-0}" = "1" ]; then
    exit 0
fi

# Hook directory, captured before the cd below so a relative $0 still resolves
# (P-37 library load). ${0%/*} rather than dirname: no external binary needed.
case "$0" in
    /*)  AAPP_HOOK_DIR="${0%/*}" ;;
    */*) AAPP_HOOK_DIR="$PWD/${0%/*}" ;;
    *)   AAPP_HOOK_DIR="$PWD" ;;
esac

# The Perl core (P-115) reads the payload and writes the decision. It is loaded
# from the installed kit: $AAPP_LIB when an aapp verb runs the hook, else the
# install location. Without it the guard cannot tell what is written, so it
# refuses (exit 2), never allows.
AAPP_PERL_LIB="${AAPP_LIB:-${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit/lib}"
if ! command -v perl >/dev/null 2>&1 || [ ! -r "$AAPP_PERL_LIB/AAPP/JSON.pm" ]; then
    echo "❌ [Blast Radius Guard Violation] Perl core missing: perl and $AAPP_PERL_LIB/AAPP/JSON.pm are required. Install the kit: aapp install." >&2
    exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

# ------------------------------------------------------------------------------
# 1. Parse Input (CLI Argument or PreToolUse JSON payload on stdin)
# ------------------------------------------------------------------------------
TARGET_FILE=""
TOOL_NAME=""

if [ $# -ge 1 ]; then
    TARGET_FILE="$1"
elif [ ! -t 0 ]; then
    RAW_INPUT=$(cat)
    if [ -z "$RAW_INPUT" ]; then
        exit 0
    fi
    # The PreToolUse payload: tool name and the file it writes. Input that is
    # not a JSON object yields nothing (the single-line path form below).
    PARSED=$(printf '%s' "$RAW_INPUT" | perl -CS -Mutf8 -I"$AAPP_PERL_LIB" -MAAPP::JSON -e '
my $raw = do { local $/; <STDIN> };
my ( $rc, $d ) = AAPP::JSON::decode($raw);
exit 0 if $rc != 1 || ref($d) ne "HASH";
my $in = ref( $d->{tool_input} ) eq "HASH" ? $d->{tool_input} : {};
my ($path) = grep { defined $_ && !ref($_) && $_ ne "" } @{$in}{qw(file_path path target_file)};
print $d->{tool_name} // "", "\t", $path // "", "\n";
') || { echo "❌ [Blast Radius Guard Violation] The Perl core failed reading the tool payload. Run 'aapp init' to reinstall the hook engine." >&2; exit 2; }
    if [ -n "$PARSED" ]; then
        TOOL_NAME=$(printf '%s\n' "$PARSED" | cut -f1)
        TARGET_FILE=$(printf '%s\n' "$PARSED" | cut -f2)
    fi
    # If not JSON, check if RAW_INPUT is a single-line path
    if [ -z "$TARGET_FILE" ] && [ -n "$RAW_INPUT" ]; then
        case "$RAW_INPUT" in
            *"{"*|*"}"*) ;;
            *)
                first_line=$(printf '%s' "$RAW_INPUT" | head -n 1 | tr -d '\r\n')
                [ -n "$first_line" ] && TARGET_FILE="$first_line"
                ;;
        esac
    fi
fi

if [ -z "$TARGET_FILE" ]; then
    exit 0
fi

# POSIX lexical path canonicalization (resolves . and .. without expanding symlinks)
canonicalize_path() {
    local p="$1"
    case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
    local out="" seg
    local IFS=/
    for seg in $p; do
        case "$seg" in
            ''|.) continue ;;
            ..)   out="${out%/*}" ;;
            *)    out="$out/$seg" ;;
        esac
    done
    printf '%s\n' "${out:-/}"
}

ORIGINAL_TARGET="$TARGET_FILE"
CANONICAL_TARGET=$(canonicalize_path "$TARGET_FILE")
REPO_ROOT=$(canonicalize_path "$REPO_ROOT")

# 1. Canonical Worktree & Repository Resolution (#112)
GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null || echo ".git")"
case "$GIT_COMMON_DIR" in /*) ;; *) GIT_COMMON_DIR="$REPO_ROOT/$GIT_COMMON_DIR" ;; esac
GIT_COMMON_DIR=$(canonicalize_path "$GIT_COMMON_DIR")

if [ -d "$GIT_COMMON_DIR" ]; then
    PRIMARY_ROOT="$(cd "$GIT_COMMON_DIR/.." 2>/dev/null && pwd)"
    PRIMARY_ROOT=$(canonicalize_path "$PRIMARY_ROOT")
else
    PRIMARY_ROOT="$REPO_ROOT"
fi

# Detect whether CANONICAL_TARGET belongs to the same repository (primary checkout or linked worktree)
TARGET_DIR="$CANONICAL_TARGET"
[ -d "$TARGET_DIR" ] || TARGET_DIR="${CANONICAL_TARGET%/*}"
while [ -n "$TARGET_DIR" ] && [ ! -d "$TARGET_DIR" ]; do
    TARGET_DIR="${TARGET_DIR%/*}"
done
[ -n "$TARGET_DIR" ] || TARGET_DIR="/"

TARGET_WT_ROOT=""
TARGET_COMMON_DIR=""
if [ -n "$TARGET_DIR" ] && [ -d "$TARGET_DIR" ]; then
    TARGET_COMMON_DIR="$(git -C "$TARGET_DIR" rev-parse --git-common-dir 2>/dev/null || true)"
    if [ -n "$TARGET_COMMON_DIR" ]; then
        case "$TARGET_COMMON_DIR" in /*) ;; *) TARGET_COMMON_DIR="$TARGET_DIR/$TARGET_COMMON_DIR" ;; esac
        TARGET_COMMON_DIR=$(canonicalize_path "$TARGET_COMMON_DIR")
    fi
fi

IS_SAME_REPO=0
if [ -n "$TARGET_COMMON_DIR" ] && [ "$TARGET_COMMON_DIR" = "$GIT_COMMON_DIR" ]; then
    IS_SAME_REPO=1
    TARGET_WT_ROOT="$(git -C "$TARGET_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
    [ -n "$TARGET_WT_ROOT" ] && TARGET_WT_ROOT=$(canonicalize_path "$TARGET_WT_ROOT")
elif [ -z "$TARGET_COMMON_DIR" ]; then
    # No answer from git: a target under REPO_ROOT stays repo-internal (fail closed).
    case "$CANONICAL_TARGET" in "$REPO_ROOT"|"$REPO_ROOT"/*) IS_SAME_REPO=1; TARGET_WT_ROOT="$REPO_ROOT" ;; esac
fi

# Normalize path relative to its own worktree root for repo-internal matching
if [ "$IS_SAME_REPO" -eq 1 ] && [ -n "$TARGET_WT_ROOT" ]; then
    case "$CANONICAL_TARGET" in
        "$TARGET_WT_ROOT")
            TARGET_FILE="."
            ;;
        "$TARGET_WT_ROOT"/*)
            TARGET_FILE="${CANONICAL_TARGET#"$TARGET_WT_ROOT"/}"
            ;;
        *)
            TARGET_FILE="$CANONICAL_TARGET"
            ;;
    esac
else
    case "$CANONICAL_TARGET" in
        "$REPO_ROOT")
            TARGET_FILE="."
            ;;
        "$REPO_ROOT"/*)
            TARGET_FILE="${CANONICAL_TARGET#"$REPO_ROOT"/}"
            ;;
        *)
            TARGET_FILE="$CANONICAL_TARGET"
            ;;
    esac
fi

deny_action() {
    local reason="$1"
    if [ -n "$TOOL_NAME" ]; then
        perl -CSA -Mutf8 -I"$AAPP_PERL_LIB" -MAAPP::JSON -e '
my $r = AAPP::JSON::json_str( $ARGV[0] );
print AAPP::JSON::json_obj(
    decision           => AAPP::JSON::json_str("deny"),
    reason             => $r,
    hookSpecificOutput => AAPP::JSON::json_obj(
        hookEventName            => AAPP::JSON::json_str("PreToolUse"),
        permissionDecision       => AAPP::JSON::json_str("deny"),
        permissionDecisionReason => $r,
    ),
), "\n";
' "$reason" || true
        echo "❌ [Blast Radius Guard Violation] $reason" >&2
    else
        echo "❌ [Blast Radius Guard Violation] $reason" >&2
    fi
    exit 2
}

# ------------------------------------------------------------------------------
# 1b. Shared Library (P-37): plan parsing and glob matching, fail-closed
# ------------------------------------------------------------------------------
# Refused through deny_action (exit 2): a PreToolUse hook exiting 1 is a
# non-blocking error, which would let the write through unguarded.
AAPP_LIB_FILE="$AAPP_HOOK_DIR/aapp-lib.sh"
# shellcheck source=lib/aapp-lib.sh
if ! . "$AAPP_LIB_FILE" 2>/dev/null || ! declare -f aapp_lib_loaded >/dev/null; then
    deny_action "Shared library or status registry missing or unreadable: $AAPP_LIB_FILE, $AAPP_HOOK_DIR/plan_states.sh. Run 'aapp init' to reinstall the hook engine."
fi

# ------------------------------------------------------------------------------
# 2. Self-Protection Invariants (ALWAYS PROTECTED - Hard Block)
# ------------------------------------------------------------------------------
case "$TARGET_FILE" in
    .claude/settings.json|.claude/settings.local.json|*/.claude/settings.json|*/.claude/settings.local.json|\
    .agents/claude/*|*/.agents/claude/*|\
    .agents/skills/aapp-*|*/.agents/skills/aapp-*|\
    .claude/skills/aapp-*|*/.claude/skills/aapp-*|\
    .agents/skills/plan|*/.agents/skills/plan|.agents/skills/plan/*|*/.agents/skills/plan/*|\
    .claude/skills/plan|*/.claude/skills/plan|.claude/skills/plan/*|*/.claude/skills/plan/*)
        deny_action "Tampering with AAPP core configuration or governance skills is strictly prohibited."
        ;;
    .githooks/*|*/.githooks/*|.git/hooks/*|*/.git/hooks/*)
        deny_action "Tampering with AAPP git hooks engine is strictly prohibited."
        ;;
    .git/config|*/.git/config)
        deny_action "Tampering with git configuration (.git/config) is strictly prohibited."
        ;;
    .cursor/rules/*|*/.cursor/rules/*)
        deny_action "Tampering with agent rule files (.cursor/rules/) is strictly prohibited."
        ;;
esac

# ------------------------------------------------------------------------------
# 2b. External Hard-Deny (Credentials, Shell Startup Files, System Binaries)
# ------------------------------------------------------------------------------
case "$CANONICAL_TARGET" in
    */.ssh/*|*/.gnupg/*|*/.aws/*|*/.azure/*|*/.kube/*|*/.docker/config.json|\
    */.netrc|*/.npmrc|*/.pypirc|*/.git-credentials|\
    */.gitconfig|*/.config/git/*|\
    */.bashrc|*/.bash_profile|*/.zshrc|*/.zprofile|*/.profile|\
    */.config/fish/*|*/crontab|*/.local/bin/*)
        deny_action "Modifying sensitive credentials, shell configuration, or external binaries is strictly prohibited."
        ;;
esac

# ------------------------------------------------------------------------------
# 2c. External Path Allowlist (Agent Memory, Scratchpads, and User Allowlist)
# ------------------------------------------------------------------------------
resolve_allowlist() {
    local list=()

    add_prefix() {
        local p="$1"
        [ -z "$p" ] && return 0
        case "$p" in
            "~") p="$HOME" ;;
            "~/"*) p="$HOME/${p#\~/}" ;;
        esac
        if [ -n "$HOME" ]; then
            p="${p/\$HOME/$HOME}"
        fi
        local canon
        canon=$(canonicalize_path "$p")
        if [ -n "$canon" ] && [ "$canon" != "/" ]; then
            # Strictly normalize with trailing slash to prevent prefix-aliasing
            list+=("${canon%/}/")
        fi
    }

    # Built-in multi-agent defaults
    [ -n "$HOME" ] && add_prefix "$HOME/.claude"
    [ -n "$HOME" ] && add_prefix "$HOME/.gemini"
    [ -n "$HOME" ] && add_prefix "$HOME/.codex"
    [ -n "$HOME" ] && add_prefix "$HOME/.cursor"
    if [ -n "$XDG_CONFIG_HOME" ]; then
        add_prefix "$XDG_CONFIG_HOME"
    elif [ -n "$HOME" ]; then
        add_prefix "$HOME/.config"
    fi
    if [ -n "$XDG_DATA_HOME" ]; then
        add_prefix "$XDG_DATA_HOME"
    elif [ -n "$HOME" ]; then
        add_prefix "$HOME/.local/share"
    fi
    [ -n "$TMPDIR" ] && add_prefix "$TMPDIR"
    add_prefix "/tmp"
    [ -d "/var/folders" ] && add_prefix "/var/folders"

    # User-configured additions from git config
    local custom
    while IFS= read -r custom; do
        [ -n "$custom" ] && add_prefix "$custom"
    done < <(git config --get-all aapp.allowPath 2>/dev/null || true)

    printf '%s\n' "${list[@]}"
}

if [ "$IS_SAME_REPO" -eq 1 ]; then
    # Inside repository or linked worktree, proceed to Section 3 and Section 4 blast radius checks
    :
else
    # External path: check registered companion repositories first (G1 delegation)
    c_entry="" c_path="" canon_c_path=""
    while IFS= read -r c_entry; do
        [ -z "$c_entry" ] && continue
        c_path="${c_entry#* }"
        [ -z "$c_path" ] && continue
        canon_c_path="$(canonicalize_path "$c_path")"
        case "$CANONICAL_TARGET" in
            "$canon_c_path"|"$canon_c_path"/*)
                if [ -x "$canon_c_path/.githooks/blast-radius-guard" ]; then
                    if [ -n "$RAW_INPUT" ]; then
                        if printf '%s' "$RAW_INPUT" | (cd "$canon_c_path" && .githooks/blast-radius-guard); then
                            exit 0
                        else
                            exit 2
                        fi
                    else
                        if (cd "$canon_c_path" && .githooks/blast-radius-guard "$CANONICAL_TARGET"); then
                            exit 0
                        else
                            exit 2
                        fi
                    fi
                fi
                exit 0
                ;;
        esac
    done < <(git config --get-regexp '^aapp\.companion\..*\.path$' 2>/dev/null || true)

    # External path: check against authorized allowlist
    while IFS= read -r allowed_prefix; do
        [ -z "$allowed_prefix" ] && continue
        case "$CANONICAL_TARGET" in
            "$allowed_prefix"*)
                exit 0
                ;;
        esac
    done < <(resolve_allowlist)
    deny_action "File '$ORIGINAL_TARGET' is outside repository and not in the authorized path allowlist."
fi

# ------------------------------------------------------------------------------
# 2d. Project Circuit Breaker (Emergency Pause Check)
# ------------------------------------------------------------------------------

PAUSED_FILE="$GIT_COMMON_DIR/aapp_paused"
SHARED_PAUSED_FILE=""
if [ -d "$REPO_ROOT/.plans" ]; then
    SHARED_PAUSED_FILE="$REPO_ROOT/.plans/PAUSED.md"
elif [ -n "$PRIMARY_ROOT" ] && [ -d "$PRIMARY_ROOT/.plans" ]; then
    SHARED_PAUSED_FILE="$PRIMARY_ROOT/.plans/PAUSED.md"
fi

if [ -f "$PAUSED_FILE" ] || { [ -n "$SHARED_PAUSED_FILE" ] && [ -f "$SHARED_PAUSED_FILE" ]; }; then
    # While paused, allow reflections strictly within .plans/ (pickup, issues, current)
    case "$TARGET_FILE" in
        .plans/pickup*|.plans/ISSUES.md|.plans/issues*|.plans/current/*)
            exit 0
            ;;
    esac
    case "$(basename "$REPO_ROOT")" in
        .plans)
            case "$TARGET_FILE" in
                pickup*|ISSUES.md|issues*|current/*)
                    exit 0
                    ;;
            esac
            ;;
    esac

    PAUSE_REASON=""
    if [ -f "$PAUSED_FILE" ]; then
        PAUSE_REASON=$(perl -CSA -Mutf8 -I"$AAPP_PERL_LIB" -MAAPP::JSON -e '
my ( $rc, $d ) = AAPP::JSON::decode_file( $ARGV[0] );
print $d->{reason} // "" if $rc == 1 && ref($d) eq "HASH";
' "$PAUSED_FILE") || PAUSE_REASON=""
    fi
    if [ -z "$PAUSE_REASON" ] && [ -n "$SHARED_PAUSED_FILE" ] && [ -f "$SHARED_PAUSED_FILE" ]; then
        PAUSE_REASON=$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Reason:\*\*[[:space:]]*(.*)/\1/p' "$SHARED_PAUSED_FILE" 2>/dev/null | head -n 1 || true)
    fi
    [ -z "$PAUSE_REASON" ] && PAUSE_REASON="developer paused project"

    deny_action "🛑 [Project Circuit Breaker] The project is currently PAUSED.
   Reason : $PAUSE_REASON
   Stashes: In-flight changes quarantined across worktrees
   Only .plans/ (pickup, issues, current) reflections may be modified while paused.
   All other modifications (codebase, .agents/, templates, hooks) are strictly refused.
   To resume modifications, run 'aapp resume'."
fi

# ------------------------------------------------------------------------------
# 3. Always-Allowed Invariants (Plans, Rules, Root Anchors)
# ------------------------------------------------------------------------------
# #84: from inside the .plans or .agents worktree (or by absolute path from a
# linked worktree) a planning path is relative to that worktree, not to the
# primary checkout; match it against the primary's .plans/.agents instead.
# Code paths keep relativising against the current worktree.
# P-75: `.offline` is the offline worktree (issues and draft plans staged while
# a provider is unreachable): planning paths, like `.plans`.
case "$CANONICAL_TARGET" in
    "${PRIMARY_ROOT:-$REPO_ROOT}"/.plans/*|"${PRIMARY_ROOT:-$REPO_ROOT}"/.agents/*|"${PRIMARY_ROOT:-$REPO_ROOT}"/.offline/*)
        exit 0
        ;;
esac
case "$TARGET_FILE" in
    .plans/*|.agents/*|.offline/*)
        exit 0
        ;;
    CHANGELOG.md|README.md|MANUAL.md|CHEATSHEET.md|COOKBOOK.md|CODEMAP.md|ARCHITECTURE.md|ISSUES.md|.gitignore|docs/*)
        exit 0
        ;;
    package.json|package-lock.json|composer.json|composer.lock|go.mod|go.sum|Cargo.toml|Cargo.lock|pyproject.toml|requirements.txt)
        exit 0
        ;;
esac

# ------------------------------------------------------------------------------
# 4. Blast Radius Validation Against Active Plan
# ------------------------------------------------------------------------------

# 1. Canonical Worktree & .plans/ Resolution
if [ -d "$REPO_ROOT/.plans" ]; then
    PLANS_DIR="$REPO_ROOT/.plans"
elif [ -n "$PRIMARY_ROOT" ] && [ -d "$PRIMARY_ROOT/.plans" ]; then
    PLANS_DIR="$PRIMARY_ROOT/.plans"
else
    PLANS_DIR=""
fi

# 2. Fail-Closed Quarantine in AAPP Repositories
if [ -z "$PLANS_DIR" ] || [ ! -d "$PLANS_DIR/current" ]; then
    if [ -f "$REPO_ROOT/.githooks/blast-radius-guard" ] || [ -f "$PRIMARY_ROOT/.githooks/blast-radius-guard" ] || \
       [ -f "$REPO_ROOT/aapp" ] || [ -f "$PRIMARY_ROOT/aapp" ]; then
        deny_action "AAPP repository detected but .plans/current directory is missing or unmounted."
    else
        if [ "$IS_SAME_REPO" -eq 1 ]; then
            exit 0
        else
            deny_action "File '$ORIGINAL_TARGET' is outside repository and not in the authorized path allowlist."
        fi
    fi
fi

# Determine active plan buffer for this target file
if [ "$IS_SAME_REPO" -eq 1 ] && [ -n "$TARGET_WT_ROOT" ]; then
    ACTIVE_PLAN_FILE="$(git -C "$TARGET_WT_ROOT" rev-parse --git-path aapp_active_plan 2>/dev/null || echo "$TARGET_WT_ROOT/.git/aapp_active_plan")"
    case "$ACTIVE_PLAN_FILE" in /*) ;; *) ACTIVE_PLAN_FILE="$TARGET_WT_ROOT/$ACTIVE_PLAN_FILE" ;; esac
else
    ACTIVE_PLAN_FILE="$(git rev-parse --git-path aapp_active_plan 2>/dev/null || echo ".git/aapp_active_plan")"
fi
MINI_BUF="$ACTIVE_PLAN_FILE"

# Check if target file belongs to any BLOCKED plan in workspace. A bound mini
# plan (P-52) may edit its own files even when a BLOCKED plan lists them: the
# rule stops the blocked plan, not its sanctioned fix.
MINI_TARGETS=()
MINI_ID="$(head -n 1 "$MINI_BUF" 2>/dev/null | tr -d '[:space:]' || true)"
case "$MINI_ID" in
    '#'*) [ -f "$PLANS_DIR/current/fix-${MINI_ID#\#}.md" ] && while IFS= read -r ITEM; do
              [ -n "$ITEM" ] && MINI_TARGETS+=("$ITEM")
          done < <(parse_plan_target_paths "$PLANS_DIR/current/fix-${MINI_ID#\#}.md") ;;
esac
for pf in "$PLANS_DIR"/current/*.md; do
    if [ ${#MINI_TARGETS[@]} -gt 0 ] && match_pattern_list "$TARGET_FILE" "${MINI_TARGETS[@]}"; then
        break
    fi
    [ ! -f "$pf" ] && continue
    case "$(basename "$pf")" in 000-*) continue ;; esac
    if plan_status_is "$pf" blocked; then
        BLOCKED_TARGETS=()
        while IFS= read -r ITEM; do
            [ -n "$ITEM" ] && BLOCKED_TARGETS+=("$ITEM")
        done < <(parse_plan_target_paths "$pf")
        if [ ${#BLOCKED_TARGETS[@]} -gt 0 ] && match_pattern_list "$TARGET_FILE" "${BLOCKED_TARGETS[@]}"; then
            deny_action "Plan '$(basename "$pf")' is BLOCKED. All modifications are refused."
        fi
    fi
done

# 3. Active Plan Context Resolution (Pointer Buffer -> Single 🟠 Auto-Discovery)
DESIGNATED_PLAN_ID=""
if [ -f "$ACTIVE_PLAN_FILE" ]; then
    DESIGNATED_PLAN_ID="$(head -n 1 "$ACTIVE_PLAN_FILE" 2>/dev/null | tr -d '[:space:]')"
fi

ACTIVE_PLAN_PATH=""
if [ -n "$DESIGNATED_PLAN_ID" ]; then
    for pf in "$PLANS_DIR"/current/*.md; do
        [ ! -f "$pf" ] && continue
        case "$(basename "$pf")" in 000-*) continue ;; esac
        local_id="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" 2>/dev/null || true)"
        bname="$(basename "$pf" .md)"
        if [ "$local_id" = "$DESIGNATED_PLAN_ID" ] || [ "$bname" = "$DESIGNATED_PLAN_ID" ] || \
           [[ "$bname" == "$DESIGNATED_PLAN_ID-"* ]] || [[ "$bname" == "P$DESIGNATED_PLAN_ID-"* ]] || \
           [[ "$bname" == "P-$DESIGNATED_PLAN_ID-"* ]]; then
            ACTIVE_PLAN_PATH="$pf"
            break
        fi
    done
    if [ -z "$ACTIVE_PLAN_PATH" ]; then
        deny_action "Designated active plan '$DESIGNATED_PLAN_ID' not found in $PLANS_DIR/current/. Run 'aapp plan-clear' or 'aapp plan <id>'."
    fi
else
    # P-52: plans held by another worktree's buffer are not adopted here, and
    # their files are refused in this unbound checkout (shared docs excepted).
    HELD_PLANS="$(aapp_held_plans)"
    DEV_PLANS=()
    for pf in "$PLANS_DIR"/current/*.md; do
        [ ! -f "$pf" ] && continue
        case "$(basename "$pf")" in 000-*) continue ;; esac
        if plan_status_is "$pf" in-development || [ -z "$(plan_status_line "$pf")" ]; then
            if HOLDER="$(aapp_plan_held_by "$pf" "$HELD_PLANS")"; then
                if ! aapp_is_shared_doc "$TARGET_FILE"; then
                    HELD_TARGETS=()
                    while IFS= read -r ITEM; do
                        [ -n "$ITEM" ] && HELD_TARGETS+=("$ITEM")
                    done < <(parse_plan_target_paths "$pf")
                    if [ ${#HELD_TARGETS[@]} -gt 0 ] && match_pattern_list "$TARGET_FILE" "${HELD_TARGETS[@]}"; then
                        deny_action "File '$ORIGINAL_TARGET' belongs to $(basename "$pf" .md) (in $HOLDER)."
                    fi
                fi
                continue
            fi
            DEV_PLANS+=("$pf")
        fi
    done

    if [ ${#DEV_PLANS[@]} -eq 1 ]; then
        ACTIVE_PLAN_PATH="${DEV_PLANS[0]}"
    elif [ ${#DEV_PLANS[@]} -gt 1 ]; then
        PLAN_LIST=$(for p in "${DEV_PLANS[@]}"; do basename "$p" .md; done | tr '\n' ',' | sed 's/,$//')
        deny_action "Multiple plans in development [$PLAN_LIST]. Run 'aapp plan <id>' to select context."
    else
        # No plan in development: edits are allowed (#98, P-52 Q1); a frozen
        # plan is backlog and restricts nothing.
        if [ "$IS_SAME_REPO" -eq 1 ]; then
            exit 0
        else
            deny_action "File '$ORIGINAL_TARGET' is outside repository and not in the authorized path allowlist."
        fi
    fi
fi

# 4. Enforce Boundaries for Active Plan
if plan_status_is "$ACTIVE_PLAN_PATH" blocked; then
    deny_action "Active plan '$(basename "$ACTIVE_PLAN_PATH")' is BLOCKED. All modifications are refused."
fi

PLAN_TARGETS=()
PLAN_OOB=()

while IFS= read -r ITEM; do
    [ -n "$ITEM" ] && PLAN_TARGETS+=("$ITEM")
done < <(parse_plan_target_paths "$ACTIVE_PLAN_PATH")
# P-129: an approved amendment request's file, until its commit.
while IFS= read -r ITEM; do
    [ -n "$ITEM" ] && PLAN_TARGETS+=("$ITEM")
done < <(amend_approved_files "$ACTIVE_PLAN_PATH")

while IFS= read -r ITEM; do
    [ -n "$ITEM" ] && PLAN_OOB+=("$ITEM")
done < <(parse_plan_oob_paths "$ACTIVE_PLAN_PATH")

# 1. Out of Bounds veto
if [ ${#PLAN_OOB[@]} -gt 0 ] && match_pattern_list "$TARGET_FILE" "${PLAN_OOB[@]}"; then
    deny_action "File '$ORIGINAL_TARGET' is explicitly OUT OF BOUNDS in active plan '$(basename "$ACTIVE_PLAN_PATH")'."
fi

# 2. Target Files allow
if [ ${#PLAN_TARGETS[@]} -gt 0 ] && match_pattern_list "$TARGET_FILE" "${PLAN_TARGETS[@]}"; then
    exit 0
fi

# 3. Out-of-bounds only plan without declared targets
if [ ${#PLAN_TARGETS[@]} -eq 0 ] && [ ${#PLAN_OOB[@]} -gt 0 ]; then
    exit 0
fi

deny_action "File '$ORIGINAL_TARGET' is outside the declared Target Files of active plan '$(basename "$ACTIVE_PLAN_PATH")'."
