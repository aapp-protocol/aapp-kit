#!/usr/bin/env bash
# ==============================================================================
# AAPP Plan Status Registry
#
# Governed by Plan P-30 (Status Registry & Derived State Matrix).
# The single source of truth for which plan statuses exist and how each one
# renders. Plan `Status:` lines in .plans/current/*.md are authoritative for a
# given plan's state; this registry declares the vocabulary those lines draw on.
#
#   - Pure module: no top-level side effects, safe to source anywhere.
#   - Four fields per status: emoji, canonical name, matrix heading, sort rank.
#   - Many-to-one status -> heading (Under Review and Refining share a section).
#   - Adopter extension via git config aapp.planState.<slug>.
#   - Bash 3.2 safe: parallel arrays, no associative arrays.
#
# Accessibility invariant (P-30 §2.8): the shipped glyph set is colour-blind
# friendly and is a hard design constraint. The retired 🔴/🟡 pair is exactly
# the red/green-family combination that fails common colour-vision deficiency
# and is NOT carried here, not even as a hidden alias.
# ==============================================================================

# Field separator for config tuples: <emoji>|<name>|<heading>|<rank>
PLAN_STATE_TUPLE_SEP="|"

PLAN_STATE_SLUGS=""
PLAN_STATE_EMOJIS=""
PLAN_STATE_NAMES=""
PLAN_STATE_HEADINGS=""
PLAN_STATE_RANKS=""
PLAN_STATES_LOADED=0

# Record separator: newline-delimited parallel lists keep this dash/bash-3.2
# safe while allowing spaces inside headings and names.
_plan_state_append() {
    PLAN_STATE_SLUGS="${PLAN_STATE_SLUGS}$1
"
    PLAN_STATE_EMOJIS="${PLAN_STATE_EMOJIS}$2
"
    PLAN_STATE_NAMES="${PLAN_STATE_NAMES}$3
"
    PLAN_STATE_HEADINGS="${PLAN_STATE_HEADINGS}$4
"
    PLAN_STATE_RANKS="${PLAN_STATE_RANKS}$5
"
}

_plan_state_index_of() {
    local want="$1" i=1 line
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        if [ "$line" = "$want" ]; then
            echo "$i"
            return 0
        fi
        i=$((i + 1))
    done <<EOF
$PLAN_STATE_SLUGS
EOF
    return 1
}

_plan_state_nth() {
    local list="$1" n="$2" i=1 line
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        if [ "$i" -eq "$n" ]; then
            echo "$line"
            return 0
        fi
        i=$((i + 1))
    done <<EOF
$list
EOF
    return 1
}

# Replace an existing slug's fields in place, preserving registry order so an
# adopter override does not reshuffle sections.
_plan_state_replace() {
    local slug="$1" emoji="$2" name="$3" heading="$4" rank="$5"
    local idx
    idx="$(_plan_state_index_of "$slug")" || return 1

    local new_emojis="" new_names="" new_headings="" new_ranks=""
    local i=1 line
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        if [ "$i" -eq "$idx" ]; then
            new_emojis="${new_emojis}${emoji}
"
        else
            new_emojis="${new_emojis}${line}
"
        fi
        i=$((i + 1))
    done <<EOF
$PLAN_STATE_EMOJIS
EOF

    i=1
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        if [ "$i" -eq "$idx" ]; then
            new_names="${new_names}${name}
"
        else
            new_names="${new_names}${line}
"
        fi
        i=$((i + 1))
    done <<EOF
$PLAN_STATE_NAMES
EOF

    i=1
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        if [ "$i" -eq "$idx" ]; then
            new_headings="${new_headings}${heading}
"
        else
            new_headings="${new_headings}${line}
"
        fi
        i=$((i + 1))
    done <<EOF
$PLAN_STATE_HEADINGS
EOF

    i=1
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        if [ "$i" -eq "$idx" ]; then
            new_ranks="${new_ranks}${rank}
"
        else
            new_ranks="${new_ranks}${line}
"
        fi
        i=$((i + 1))
    done <<EOF
$PLAN_STATE_RANKS
EOF

    PLAN_STATE_EMOJIS="$new_emojis"
    PLAN_STATE_NAMES="$new_names"
    PLAN_STATE_HEADINGS="$new_headings"
    PLAN_STATE_RANKS="$new_ranks"
    return 0
}

_plan_states_load_defaults() {
    PLAN_STATE_SLUGS=""
    PLAN_STATE_EMOJIS=""
    PLAN_STATE_NAMES=""
    PLAN_STATE_HEADINGS=""
    PLAN_STATE_RANKS=""

    _plan_state_append "under-review" "🟣" "Under Review" \
        "🧠 Human Thought & Refinement (The Incubator)" "10"
    _plan_state_append "refining" "📝" "Refining" \
        "🧠 Human Thought & Refinement (The Incubator)" "10"
    _plan_state_append "frozen" "🔷" "Frozen" \
        "🔷 Frozen & Ready for Coding (The Greenlight Zone)" "20"
    _plan_state_append "in-development" "⚡" "In Development" \
        "⚡ In Development (Active Implementation Context)" "30"
    _plan_state_append "blocked" "🟥" "BLOCKED" \
        "🟥 Blocked (Halted on an Issue)" "40"
}

# Merge adopter-defined statuses from git config. A slug matching a kit default
# overrides it; a new slug is appended. Malformed tuples are skipped with a
# warning rather than being fatal: a bad config entry must never brick status.
_plan_states_merge_config() {
    local entries
    entries="$(git config --get-regexp '^aapp\.planState\.' 2>/dev/null || true)"
    [ -z "$entries" ] && return 0

    local line key slug tuple emoji name heading rank field_count
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        key="${line%% *}"
        tuple="${line#* }"
        slug="${key##*.}"

        if [ -z "$slug" ] || [ "$tuple" = "$line" ]; then
            echo "⚠️  [Plan States] Skipping malformed config entry: $line" >&2
            continue
        fi

        field_count="$(awk -F'|' '{print NF}' <<EOF
$tuple
EOF
)"
        if [ "$field_count" -ne 4 ]; then
            echo "⚠️  [Plan States] Skipping '$key': expected 4 fields (<emoji>|<name>|<heading>|<rank>), got $field_count." >&2
            continue
        fi

        emoji="$(awk -F'|' '{print $1}' <<EOF
$tuple
EOF
)"
        name="$(awk -F'|' '{print $2}' <<EOF
$tuple
EOF
)"
        heading="$(awk -F'|' '{print $3}' <<EOF
$tuple
EOF
)"
        rank="$(awk -F'|' '{print $4}' <<EOF
$tuple
EOF
)"

        if [ -z "$emoji" ] || [ -z "$name" ] || [ -z "$heading" ]; then
            echo "⚠️  [Plan States] Skipping '$key': emoji, name, and heading must all be non-empty." >&2
            continue
        fi

        case "$rank" in
            ''|*[!0-9]*)
                echo "⚠️  [Plan States] Skipping '$key': rank '$rank' is not a non-negative integer." >&2
                continue
                ;;
        esac

        if _plan_state_index_of "$slug" >/dev/null 2>&1; then
            _plan_state_replace "$slug" "$emoji" "$name" "$heading" "$rank"
        else
            _plan_state_append "$slug" "$emoji" "$name" "$heading" "$rank"
        fi
    done <<EOF
$entries
EOF
    return 0
}

# Idempotent: repeated calls rebuild the same registry rather than duplicating.
plan_states_load() {
    _plan_states_load_defaults
    _plan_states_merge_config
    PLAN_STATES_LOADED=1
    return 0
}

_plan_states_ensure_loaded() {
    [ "$PLAN_STATES_LOADED" -eq 1 ] || plan_states_load
}

# Resolve a raw `Status:` line to a slug. Matching is by canonical NAME, not
# emoji: the emoji is display, the name is the semantic key. Tolerates the line
# shapes already handled at cmd_plan.sh:115 and :808 (leading * or -, bold
# markers, variable whitespace).
plan_state_for_status_line() {
    local line="$1"
    _plan_states_ensure_loaded

    local i=1 slug name
    while IFS= read -r slug; do
        [ -z "$slug" ] && continue
        name="$(_plan_state_nth "$PLAN_STATE_NAMES" "$i")"
        if echo "$line" | grep -qE "\*\*Status:\*\*[[:space:]]*.*${name}([[:space:]]|\$)"; then
            echo "$slug"
            return 0
        fi
        i=$((i + 1))
    done <<EOF
$PLAN_STATE_SLUGS
EOF
    return 1
}

plan_state_field() {
    local slug="$1" field="$2"
    _plan_states_ensure_loaded

    local idx
    idx="$(_plan_state_index_of "$slug")" || return 1

    case "$field" in
        emoji)   _plan_state_nth "$PLAN_STATE_EMOJIS" "$idx" ;;
        name)    _plan_state_nth "$PLAN_STATE_NAMES" "$idx" ;;
        heading) _plan_state_nth "$PLAN_STATE_HEADINGS" "$idx" ;;
        rank)    _plan_state_nth "$PLAN_STATE_RANKS" "$idx" ;;
        *)       return 1 ;;
    esac
}

# Unique headings in rank order, for matrix section emission. Ties within a rank
# keep registry declaration order so shared sections stay stable.
plan_state_sections() {
    _plan_states_ensure_loaded

    local i=1 slug rank heading
    local pairs=""
    while IFS= read -r slug; do
        [ -z "$slug" ] && continue
        rank="$(_plan_state_nth "$PLAN_STATE_RANKS" "$i")"
        heading="$(_plan_state_nth "$PLAN_STATE_HEADINGS" "$i")"
        pairs="${pairs}$(printf '%010d\t%03d\t%s' "$rank" "$i" "$heading")
"
        i=$((i + 1))
    done <<EOF
$PLAN_STATE_SLUGS
EOF

    echo "$pairs" | grep -v '^$' | sort | cut -f3- | awk '!seen[$0]++'
}

# The emoji alternation consumed by cmd_plan.sh's in-place matrix rewrites.
# Live statuses only — retired glyphs are deliberately absent (§2.8), so a stale
# row surfaces as unrecognized instead of being silently rewritten.
plan_state_emoji_class() {
    _plan_states_ensure_loaded

    local out="" emoji
    while IFS= read -r emoji; do
        [ -z "$emoji" ] && continue
        if [ -z "$out" ]; then
            out="$emoji"
        else
            out="${out}|${emoji}"
        fi
    done <<EOF
$PLAN_STATE_EMOJIS
EOF
    echo "$out"
}
