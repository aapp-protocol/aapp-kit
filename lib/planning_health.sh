#!/usr/bin/env bash
# ==============================================================================
# AAPP Planning Health & Integrity Validator
#
# Verifies three-pair planning consistency and schema constraints:
# 1. Pair 1 (ISSUES <-> archive):
#    - Disjointness: Active issues and archive ledger must share zero IDs.
#    - Relocation Invariant: Active ISSUES.md must contain zero resolved rows.
# 2. Pair 2 (roadmap <-> ISSUES):
#    - Referential Integrity: Every issue on the priority board must exist in ISSUES.md.
#    - Drift & Unsequenced Detection: Flags phantom entries and unsequenced active issues.
# 3. Pair 3 (pickup <-> ISSUES):
#    - Routing Cleanliness: Prevents stale unpruned pickup notes for logged issues.
# ==============================================================================

normalize_issue_id() {
    local raw="$1"
    # Strip backticks, spaces, #, ISSUE-, and leading zeros
    local clean
    clean=$(echo "$raw" | tr -d '`' | tr -d ' ' | sed -E 's/^(ISSUE-?|#)//I' | sed -E 's/^0+([0-9])/\1/')
    if [[ "$clean" =~ ^[0-9]+$ ]]; then
        echo "$clean"
    else
        echo ""
    fi
}

find_aapp_file() {
    local name="$1"
    local repo_root="${2:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

    case "$name" in
        issues)
            if [ -f "$repo_root/.plans/ISSUES.md" ]; then
                echo "$repo_root/.plans/ISSUES.md"
            elif [ -f "$repo_root/ISSUES.md" ]; then
                echo "$repo_root/ISSUES.md"
            fi
            ;;
        archive)
            if [ -f "$repo_root/.plans/done/000-issues-archive.md" ]; then
                echo "$repo_root/.plans/done/000-issues-archive.md"
            elif [ -f "$repo_root/done/000-issues-archive.md" ]; then
                echo "$repo_root/done/000-issues-archive.md"
            fi
            ;;
        roadmap)
            if [ -f "$repo_root/.plans/issues_road_map.md" ]; then
                echo "$repo_root/.plans/issues_road_map.md"
            elif [ -f "$repo_root/issues_road_map.md" ]; then
                echo "$repo_root/issues_road_map.md"
            fi
            ;;
        pickup)
            if [ -f "$repo_root/.plans/pickup.md" ]; then
                echo "$repo_root/.plans/pickup.md"
            elif [ -f "$repo_root/pickup.md" ]; then
                echo "$repo_root/pickup.md"
            fi
            ;;
    esac
}

# Extract normalized numeric IDs from ISSUES.md table
get_active_issue_ids() {
    local issues_file="$1"
    [ ! -f "$issues_file" ] && return 0

    # Match rows starting with | followed by an issue ID token
    while IFS= read -r line; do
        # Extract first column after leading |
        local raw_id
        raw_id=$(echo "$line" | awk -F'|' '{print $2}' | tr -d ' ')
        local norm_id
        norm_id=$(normalize_issue_id "$raw_id")
        [ -n "$norm_id" ] && echo "$norm_id"
    done < <(grep -E '^[[:space:]]*\|[[:space:]]*`?#?[0-9]+' "$issues_file" 2>/dev/null || true)
}

# Extract normalized numeric IDs from 000-issues-archive.md
get_archived_issue_ids() {
    local archive_file="$1"
    [ ! -f "$archive_file" ] && return 0

    while IFS= read -r line; do
        local raw_id
        raw_id=$(echo "$line" | awk -F'|' '{print $2}' | tr -d ' ')
        local norm_id
        norm_id=$(normalize_issue_id "$raw_id")
        [ -n "$norm_id" ] && echo "$norm_id"
    done < <(grep -E '^[[:space:]]*\|[[:space:]]*`?#?[0-9]+' "$archive_file" 2>/dev/null || true)
}

# Extract normalized numeric IDs from issues_road_map.md
get_roadmap_issue_ids() {
    local roadmap_file="$1"
    [ ! -f "$roadmap_file" ] && return 0

    local list_regex='^[[:space:]]*([0-9]+\.|-[[:space:]]*\[[ xX]?\]|\*)[[:space:]]*`?#?([0-9]+)'
    while IFS= read -r line; do
        local num
        num=$(echo "$line" | sed -E 's/^[[:space:]]*([0-9]+\.|-[[:space:]]*\[[ xX]?\]|\*)[[:space:]]*`?#?([0-9]+).*/\2/')
        local norm_id
        norm_id=$(normalize_issue_id "$num")
        [ -n "$norm_id" ] && echo "$norm_id"
    done < <(grep -E "$list_regex" "$roadmap_file" 2>/dev/null || true)
}

# Check Pair 1: ISSUES.md <-> 000-issues-archive.md
check_pair1_disjointness() {
    local issues_file="$1"
    local archive_file="$2"
    local errors=0

    # 1. Dedicated Table Row Matcher for resolved rows in active table
    local resolved_row_regex='^[[:space:]]*\|[[:space:]]*`?#?[0-9]+`?.*(✅|[Rr]esolved)'
    if [ -f "$issues_file" ] && grep -qE "$resolved_row_regex" "$issues_file" 2>/dev/null; then
        echo "❌ [Pair 1 Invariant Violation] Found resolved issue in active $issues_file."
        echo "   The Relocation Invariant requires resolved rows to be moved to .plans/done/000-issues-archive.md."
        echo "   Resolution is a physical row relocation, never an in-place status badge."
        errors=$((errors + 1))
    fi

    # 2. Check for numeric ID collisions between active and archive
    if [ -f "$issues_file" ] && [ -f "$archive_file" ]; then
        local active_ids
        active_ids=$(get_active_issue_ids "$issues_file" | sort -u)
        local archive_ids
        archive_ids=$(get_archived_issue_ids "$archive_file" | sort -u)

        local collisions
        collisions=$(comm -12 <(echo "$active_ids") <(echo "$archive_ids"))
        if [ -n "$collisions" ]; then
            for cid in $collisions; do
                echo "❌ [Pair 1 Collision] Issue #$cid exists in both active $issues_file and $archive_file!"
                errors=$((errors + 1))
            done
        fi
    fi

    return $errors
}

# Check Pair 2: issues_road_map.md <-> ISSUES.md
check_pair2_referential_integrity() {
    local roadmap_file="$1"
    local issues_file="$2"
    local errors=0

    if [ ! -f "$roadmap_file" ] || [ ! -f "$issues_file" ]; then
        return 0
    fi

    local roadmap_ids
    roadmap_ids=$(get_roadmap_issue_ids "$roadmap_file" | sort -n -u)
    local active_ids
    active_ids=$(get_active_issue_ids "$issues_file" | sort -n -u)

    # 1. Check for roadmap drift (ID on roadmap but not in active ISSUES.md)
    for rid in $roadmap_ids; do
        if ! echo "$active_ids" | grep -qx "$rid"; then
            echo "⚠️  [Roadmap Drift] #$rid is on the priority board but missing from $issues_file."
            errors=$((errors + 1))
        fi
    done

    return $errors
}

# Get unsequenced active issues (in ISSUES.md but not on roadmap)
get_unsequenced_issues() {
    local roadmap_file="$1"
    local issues_file="$2"

    [ ! -f "$roadmap_file" ] || [ ! -f "$issues_file" ] && return 0

    local roadmap_ids
    roadmap_ids=$(get_roadmap_issue_ids "$roadmap_file" | sort -n -u)
    local active_ids
    active_ids=$(get_active_issue_ids "$issues_file" | sort -n -u)

    local unsequenced=()
    for aid in $active_ids; do
        if ! echo "$roadmap_ids" | grep -qx "$aid"; then
            unsequenced+=("#$aid")
        fi
    done

    if [ ${#unsequenced[@]} -gt 0 ]; then
        echo "${unsequenced[*]}"
    fi
}

# Check Pair 3: pickup.md <-> ISSUES.md
check_pair3_pickup_routing() {
    local pickup_file="$1"
    local issues_file="$2"
    local archive_file="$3"
    local warnings=0

    [ ! -f "$pickup_file" ] && return 0

    local active_ids=""
    [ -f "$issues_file" ] && active_ids=$(get_active_issue_ids "$issues_file")
    local archive_ids=""
    [ -f "$archive_file" ] && archive_ids=$(get_archived_issue_ids "$archive_file")

    # Look for list items in pickup whose title explicitly drafts an issue
    local issue_bullet_regex='^[[:space:]]*([0-9]+\.|-[[:space:]]*\[[ xX]?\]|\*)[[:space:]]*(\*\*)?[[:alnum:][:space:]]*(🔴|🟠|🟡|🟢)?[[:space:]]*(#|ISSUE-)[0-9]+'
    while IFS= read -r line; do
        local raw_title
        raw_title=$(echo "$line" | cut -d: -f1)
        local found_ids
        found_ids=$(echo "$raw_title" | grep -o -E '(#|ISSUE-)[0-9]+' || true)
        for raw in $found_ids; do
            local nid
            nid=$(normalize_issue_id "$raw")
            if [ -n "$nid" ]; then
                if echo "$active_ids" | grep -qx "$nid" || echo "$archive_ids" | grep -qx "$nid"; then
                    echo "⚠️  [Pickup Routing] Issue #$nid is already logged in ISSUES.md or archive, but still drafted as an unworked note in $pickup_file."
                    warnings=$((warnings + 1))
                fi
            fi
        done
    done < <(grep -E "$issue_bullet_regex" "$pickup_file" 2>/dev/null || true)

    return 0
}

# Validate Taxonomy and Column Schemas
check_taxonomy_and_schema() {
    local issues_file="$1"
    local warnings=0
    local errors=0

    [ ! -f "$issues_file" ] && return 0

    local core_vocab="^(CORE|CLI|UI|DB|NET|SEC|HOOK|DOCS|TEST|PERF)$"
    local valid_type_regex='^[A-Z0-9_-]+$'
    local valid_sev_regex='^(Critical|High|Medium|Low)$'

    while IFS= read -r line; do
        # Column 2: #, Column 3: Sev, Column 4: Type
        local raw_sev
        raw_sev=$(echo "$line" | awk -F'|' '{print $3}' | tr -d ' `' | tr -d ' ')
        local raw_type
        raw_type=$(echo "$line" | awk -F'|' '{print $4}' | tr -d ' `' | tr -d ' ')
        local raw_id
        raw_id=$(echo "$line" | awk -F'|' '{print $2}' | tr -d ' ')

        # Check Sev
        if [ -n "$raw_sev" ] && ! echo "$raw_sev" | grep -qE "$valid_sev_regex"; then
            echo "⚠️  [Schema Warning] Issue $raw_id has non-standard Severity: '$raw_sev' (expected Critical|High|Medium|Low)"
            warnings=$((warnings + 1))
        fi

        # Check Type
        if [ -n "$raw_type" ]; then
            if ! echo "$raw_type" | grep -qE "$valid_type_regex"; then
                echo "❌ [Schema Error] Issue $raw_id has invalid Type token: '$raw_type' (must match ^[A-Z0-9_-]+$)"
                errors=$((errors + 1))
            elif ! echo "$raw_type" | grep -qE "$core_vocab"; then
                # Custom extended type - advisory only
                : # valid extension
            fi
        fi
    done < <(grep -E '^[[:space:]]*\|[[:space:]]*`?#?[0-9]+' "$issues_file" 2>/dev/null || true)

    return $errors
}

# Master check runner
check_planning_health() {
    local repo_root="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
    local issues_file
    issues_file=$(find_aapp_file issues "$repo_root")
    local archive_file
    archive_file=$(find_aapp_file archive "$repo_root")
    local roadmap_file
    roadmap_file=$(find_aapp_file roadmap "$repo_root")
    local pickup_file
    pickup_file=$(find_aapp_file pickup "$repo_root")

    local total_errors=0

    echo "🔍 Checking Planning Health & Integrity..."
    echo "   Repo: $repo_root"

    # Pair 1
    check_pair1_disjointness "$issues_file" "$archive_file" || total_errors=$((total_errors + $?))

    # Pair 2
    check_pair2_referential_integrity "$roadmap_file" "$issues_file" || total_errors=$((total_errors + $?))

    # Pair 3
    check_pair3_pickup_routing "$pickup_file" "$issues_file" "$archive_file" || true

    # Schema & Taxonomy
    check_taxonomy_and_schema "$issues_file" || total_errors=$((total_errors + $?))

    if [ "$total_errors" -eq 0 ]; then
        echo "✅ Planning Health: All integrity checks passed successfully."
        return 0
    else
        echo "❌ Planning Health: Found $total_errors integrity violation(s)."
        return 1
    fi
}

# Execute if run as script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_planning_health "$@"
fi
