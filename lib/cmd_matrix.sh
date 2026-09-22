#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `matrix`
#
# Governed by Plan P-30 (Status Registry & Derived State Matrix).
# Derives .plans/state_matrix.md from the authoritative source: the `Status:`
# lines inside .plans/current/*.md. The matrix is a cache, not a record.
#
#   - Population is strictly .plans/current/*.md. A plan that left current/ has
#     no row; the archive ledger takes over. Orphan rows vanish by derivation.
#   - Sections and their order come from the status registry (lib/plan_states.sh).
#   - Statuses matching no registry entry land in a visible Unrecognized section
#     rather than being silently folded into the Incubator.
#   - Human-owned content is preserved: the Roadmap section verbatim, and each
#     row's trailing annotation after the first " — ", keyed by Plan ID.
#   - While paused, the sync still writes but warns that the commit is deferred
#     until `aapp resume` (§2.9): the diff is the record of what reflection did.
# ==============================================================================
set -e

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null || echo ".git")"
if [ -d "$GIT_COMMON_DIR" ]; then
    PRIMARY_ROOT="$(cd "$GIT_COMMON_DIR/.." 2>/dev/null && pwd)"
else
    PRIMARY_ROOT="$REPO_ROOT"
fi

if [ -d "$REPO_ROOT/.plans" ]; then
    PLANS_DIR="$REPO_ROOT/.plans"
elif [ -n "$PRIMARY_ROOT" ] && [ -d "$PRIMARY_ROOT/.plans" ]; then
    PLANS_DIR="$PRIMARY_ROOT/.plans"
else
    PLANS_DIR=""
fi

for _cand in "$AAPP_LIB/plan_states.sh" "$PRIMARY_ROOT/lib/plan_states.sh" "$REPO_ROOT/lib/plan_states.sh"; do
    if [ -n "${_cand:-}" ] && [ -f "$_cand" ]; then
        # shellcheck source=/dev/null
        . "$_cand"
        break
    fi
done

UNRECOGNIZED_HEADING="❓ Unrecognized Status (Not In The Registry)"
ROADMAP_MARKER="## 🚦 Recommended Implementation Roadmap"

matrix_is_paused() {
    local paused_file="$GIT_COMMON_DIR/aapp_paused"
    local shared=""
    if [ -d "$REPO_ROOT/.plans" ]; then
        shared="$REPO_ROOT/.plans/PAUSED.md"
    elif [ -n "$PRIMARY_ROOT" ]; then
        shared="$PRIMARY_ROOT/.plans/PAUSED.md"
    fi
    if [ -f "$paused_file" ] || { [ -n "$shared" ] && [ -f "$shared" ]; }; then
        return 0
    fi
    return 1
}

# Extract the Plan ID declared inside a blueprint, falling back to the filename
# stem so a malformed header still yields a stable annotation key.
matrix_plan_id() {
    local pf="$1" pid
    pid="$(sed -nE 's/^[[:space:]]*\*[[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" 2>/dev/null | head -n 1 || true)"
    if [ -z "$pid" ]; then
        pid="$(basename "$pf" .md)"
    fi
    echo "$pid"
}

# The H1 title, stripped of the "Plan P-NN:" prefix, used as the initial
# annotation for a plan that has no prior row.
matrix_plan_title() {
    local pf="$1" title
    title="$(grep -m1 '^# ' "$pf" 2>/dev/null | sed -E 's/^#[[:space:]]*//' || true)"
    title="$(echo "$title" | sed -E 's/^[^[:alnum:]]*[[:space:]]*Plan[[:space:]]+P-?[0-9]+:[[:space:]]*//')"
    [ -z "$title" ] && title="$(basename "$pf" .md)"
    echo "$title"
}

# Harvest the human-owned suffix of an existing row, keyed by Plan ID. The split
# is on the FIRST " — " only: annotations may themselves contain em-dashes
# (P-15's "SKETCH — do not refine" does) and must survive intact.
matrix_existing_annotation() {
    local sm="$1" pid="$2" row
    [ -f "$sm" ] || return 1

    # Only genuine plan rows carry an annotation. The Roadmap is human prose
    # that routinely names plan IDs, so a whole-file search would mistake a
    # priority line for the plan's annotation and copy it onto the row.
    row="$(awk -v marker="$ROADMAP_MARKER" -v pid="**${pid}**" '
        $0 == marker { skip = 1; next }
        skip && /^## / { skip = 0 }
        skip { next }
        /^-[[:space:]]/ && index($0, pid) { print; exit }
    ' "$sm" 2>/dev/null || true)"
    [ -z "$row" ] && return 1

    case "$row" in
        *" — "*) ;;
        *) return 1 ;;
    esac

    # Strip everything through the first " — ".
    printf '%s' "${row#* — }"
}

# The Roadmap block, verbatim: from its heading to the line before the next
# top-level heading. Human priority ordering is never derived.
matrix_existing_roadmap() {
    local sm="$1"
    [ -f "$sm" ] || return 1
    awk -v marker="$ROADMAP_MARKER" '
        $0 == marker { found = 1; print; next }
        found && /^## / { exit }
        found { print }
    ' "$sm" 2>/dev/null
}

matrix_render() {
    local sm="$1"
    local out roadmap
    out=""

    out="${out}# 📊 State Matrix (Plan Lane / The Planning Brain)
"
    out="${out}
This document is the central dashboard for all active blueprints, drafts, ready plans, and completed architectures.
"
    out="${out}
---

"

    roadmap="$(matrix_existing_roadmap "$sm" || true)"
    if [ -n "$roadmap" ]; then
        # Trim trailing blank lines and any trailing rule the harvested block
        # carried, so the separator below is emitted exactly once.
        roadmap="$(printf '%s\n' "$roadmap" | sed -e :a -e '/^[[:space:]]*$/{$d;N;ba' -e '}')"
        roadmap="$(printf '%s\n' "$roadmap" | sed -e '${/^---$/d;}')"
        roadmap="$(printf '%s\n' "$roadmap" | sed -e :a -e '/^[[:space:]]*$/{$d;N;ba' -e '}')"
        out="${out}${roadmap}
"
    else
        out="${out}${ROADMAP_MARKER}

*No plans currently active on roadmap. Incubate or freeze from backlog below.*
"
    fi
    out="${out}
---

"

    local heading rows
    while IFS= read -r heading; do
        [ -z "$heading" ] && continue
        rows="$(matrix_rows_for_heading "$heading")"
        out="${out}## ${heading}

"
        if [ -n "$rows" ]; then
            out="${out}${rows}

"
        fi
        out="${out}---

"
    done <<EOF
$(plan_state_sections)
EOF

    rows="$(matrix_rows_for_heading "$UNRECOGNIZED_HEADING")"
    if [ -n "$rows" ]; then
        out="${out}## ${UNRECOGNIZED_HEADING}

These plans carry a \`Status:\` line matching no entry in the status registry.
Fix the status in the blueprint, or declare the status via \`git config aapp.planState.<slug>\`.

"
        out="${out}${rows}

---

"
    fi

    out="${out}## 🏛️ 3. Archival Ledger (Completed Plans DB)
"
    out="${out}Completed blueprints are permanently archived in [\`done/000-archive-ledger.md\`](done/000-archive-ledger.md).
"

    printf '%s' "$out"
}

# Populated by matrix_scan: newline-delimited "heading<TAB>row" records.
MATRIX_ROWS=""

matrix_rows_for_heading() {
    local want="$1" line
    local acc=""
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        case "$line" in
            "$want"$'\t'*)
                if [ -z "$acc" ]; then
                    acc="${line#*$'\t'}"
                else
                    acc="${acc}
${line#*$'\t'}"
                fi
                ;;
        esac
    done <<EOF
$MATRIX_ROWS
EOF
    printf '%s' "$acc"
}

matrix_scan() {
    local sm="$1"
    MATRIX_ROWS=""
    plan_states_load

    local pf pid title status slug emoji heading annotation row
    for pf in "$PLANS_DIR"/current/*.md; do
        [ -f "$pf" ] || continue
        case "$(basename "$pf")" in
            000-*) continue ;;
            plan-template.md) continue ;;
        esac

        pid="$(matrix_plan_id "$pf")"
        status="$(grep -E '^[[:space:]]*\*[[:space:]]*\*\*Status:\*\*' "$pf" 2>/dev/null | head -n 1 || true)"

        if slug="$(plan_state_for_status_line "$status" 2>/dev/null)"; then
            emoji="$(plan_state_field "$slug" emoji)"
            heading="$(plan_state_field "$slug" heading)"
        else
            emoji="❓"
            heading="$UNRECOGNIZED_HEADING"
        fi

        annotation="$(matrix_existing_annotation "$sm" "$pid" || true)"
        if [ -z "$annotation" ]; then
            annotation="$(matrix_plan_title "$pf")"
        fi

        row="- ${emoji} **${pid}**: [\`$(basename "$pf")\`](current/$(basename "$pf")) — ${annotation}"
        MATRIX_ROWS="${MATRIX_ROWS}${heading}	${row}
"
    done
}

cmd_matrix() {
    local mode="sync"
    case "${1:-}" in
        --check) mode="check" ;;
        "") ;;
        *)
            echo "❌ [Matrix] Unknown option: $1"
            echo "   Usage: aapp matrix [--check]"
            return 1
            ;;
    esac

    if [ -z "$PLANS_DIR" ] || [ ! -d "$PLANS_DIR/current" ]; then
        echo "❌ [Matrix] No .plans/current/ found. Run 'aapp init' first."
        return 1
    fi

    local sm="$PLANS_DIR/state_matrix.md"
    matrix_scan "$sm"

    local rendered
    rendered="$(matrix_render "$sm")"

    local current=""
    [ -f "$sm" ] && current="$(cat "$sm")"
    # $(...) strips trailing newlines from both sides, so the comparison is on
    # equal footing; the write below restores the single trailing newline.

    if [ "$rendered" = "$current" ]; then
        echo "✅ [Matrix] state_matrix.md is in sync with .plans/current/."
        return 0
    fi

    if [ "$mode" = "check" ]; then
        echo "⚠️  [Matrix] state_matrix.md has drifted from .plans/current/."
        echo "   Run 'aapp matrix' to re-derive it."
        return 1
    fi

    printf '%s\n' "$rendered" > "$sm"
    echo "🔄 [Matrix] Re-derived state_matrix.md from .plans/current/."

    local unrecognized
    unrecognized="$(matrix_rows_for_heading "$UNRECOGNIZED_HEADING")"
    if [ -n "$unrecognized" ]; then
        echo ""
        echo "❓ [Matrix] Plans carrying an unrecognized status:"
        printf '%s\n' "$unrecognized" | sed 's/^/     /'
        echo "   Fix the Status line, or declare the status via 'git config aapp.planState.<slug>'."
    fi

    # §2.9: the pause allowlist (pickup*, ISSUES.md, issues*, current/*) excludes
    # .plans/state_matrix.md, so a paused sync cannot be committed yet. Write it
    # anyway and say so -- the diff records what reflection changed.
    if matrix_is_paused; then
        echo ""
        echo "⏸️  [Matrix] Project is PAUSED. state_matrix.md was updated on disk but"
        echo "   CANNOT be committed until you run 'aapp resume' -- the pause allowlist"
        echo "   covers only .plans/ pickup, issues, and current/ files."
    fi

    return 0
}

# Sourcing with AAPP_MATRIX_LIB_ONLY=1 loads the functions without running the
# command, so callers such as the status briefing can reuse the drift check.
if [ "${AAPP_MATRIX_LIB_ONLY:-0}" != "1" ]; then
    cmd_matrix "$@"
fi
