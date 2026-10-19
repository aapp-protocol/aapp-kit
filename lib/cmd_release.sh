#!/usr/bin/env bash
# ==============================================================================
# lib/cmd_release.sh - Milestone Release Bundling & Hook-Based Versioning (P-38)
#
# Standalone CLI orchestration for:
#   1. Version validation & SemVer bump calculation (patch, minor, major)
#   2. Pre-flight verification (worktree cleanliness, test gate, pre-release hook,
#      tag signing capability, changelog existence, commit reachability, branch parity)
#   3. Atomic release mutation (on-release hook Dual Delivery, changelog rollup,
#      milestone bundling to .plans/release/<tag>/, master ledger rollup, parity merge,
#      tagging, push, and post-release observer)
#   4. Fail-closed transactional rollback trap (_release_rollback)
# ==============================================================================

# Ensure dependencies are loaded
_RELEASE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[ -f "$_RELEASE_LIB_DIR/aapp-lib.sh" ] && . "$_RELEASE_LIB_DIR/aapp-lib.sh"
# shellcheck source=/dev/null
[ -f "$_RELEASE_LIB_DIR/commit_engine.sh" ] && . "$_RELEASE_LIB_DIR/commit_engine.sh"
# shellcheck source=/dev/null
[ -f "$_RELEASE_LIB_DIR/hook_dispatcher.sh" ] && . "$_RELEASE_LIB_DIR/hook_dispatcher.sh"

# Global transaction state for rollback
_AAPP_REL_DEV_SNAP=""
_AAPP_REL_DEV_BRANCH=""
_AAPP_REL_RELEASE_SNAP=""
_AAPP_REL_RELEASE_BRANCH=""
_AAPP_REL_PLANS_SNAP=""
_AAPP_REL_PLANS_DIR=""
_AAPP_REL_CURRENT_BRANCH=""
_AAPP_REL_TARGET_TAG=""
_AAPP_REL_BUNDLE_DIR=""
_AAPP_REL_ACTIVE_MUTATION=0

_release_rollback() {
    local exit_code=$?
    if [ "$exit_code" -ne 0 ] && [ "$_AAPP_REL_ACTIVE_MUTATION" -eq 1 ]; then
        echo "🚨 [Release Failure] Release aborted during Phase B. Rolling back transaction..." >&2
        
        # 1. Delete partial tag if created
        if [ -n "$_AAPP_REL_TARGET_TAG" ] && git rev-parse --verify "refs/tags/$_AAPP_REL_TARGET_TAG" >/dev/null 2>&1; then
            git tag -d "$_AAPP_REL_TARGET_TAG" >/dev/null 2>&1 || echo "⚠️  Failed to delete partial tag $_AAPP_REL_TARGET_TAG" >&2
        fi
        
        # 2. Unwind Git branch refs
        if [ -n "$_AAPP_REL_DEV_SNAP" ] && [ -n "$_AAPP_REL_DEV_BRANCH" ]; then
            git update-ref "refs/heads/$_AAPP_REL_DEV_BRANCH" "$_AAPP_REL_DEV_SNAP" 2>/dev/null || true
        fi
        if [ -n "$_AAPP_REL_RELEASE_SNAP" ] && [ -n "$_AAPP_REL_RELEASE_BRANCH" ]; then
            git update-ref "refs/heads/$_AAPP_REL_RELEASE_BRANCH" "$_AAPP_REL_RELEASE_SNAP" 2>/dev/null || true
        fi
        if [ -n "$_AAPP_REL_PLANS_SNAP" ] && [ -d "$_AAPP_REL_PLANS_DIR" ]; then
            git -C "$_AAPP_REL_PLANS_DIR" update-ref refs/heads/plans "$_AAPP_REL_PLANS_SNAP" 2>/dev/null || true
            git -C "$_AAPP_REL_PLANS_DIR" checkout -f 2>/dev/null || true
        fi
        
        # 3. Restore working tree and checkout
        if [ -n "$_AAPP_REL_CURRENT_BRANCH" ]; then
            git checkout -f "$_AAPP_REL_CURRENT_BRANCH" >/dev/null 2>&1 || true
        fi
        
        # 4. Remove partially created bundle directory
        if [ -n "$_AAPP_REL_BUNDLE_DIR" ] && [ -d "$_AAPP_REL_BUNDLE_DIR" ]; then
            rm -rf "$_AAPP_REL_BUNDLE_DIR" 2>/dev/null || true
        fi
        
        echo "✅ [Release Rollback] Repository restored cleanly to pre-release state." >&2
    fi
}

# Version validation regex
# ^v?[0-9]+\.[0-9]+(\.[0-9]+)?([.-][a-zA-Z0-9_.-]{1,30})?$
_release_validate_version() {
    local v="$1"
    if [[ ! "$v" =~ ^v?[0-9]+\.[0-9]+(\.[0-9]+)?([.-][a-zA-Z0-9_.-]{1,30})?$ ]]; then
        return 1
    fi
    # Check suffix length explicitly if suffix exists
    if [[ "$v" =~ ^v?[0-9]+\.[0-9]+(\.[0-9]+)?([.-].*)$ ]]; then
        local suffix="${BASH_REMATCH[2]}"
        # Strip leading separator (. or -)
        suffix="${suffix:1}"
        if [ "${#suffix}" -gt 30 ]; then
            return 1
        fi
    fi
    return 0
}

_release_calc_bump() {
    local bump="$1"
    local prev="$2"
    local p_raw="${prev#v}"
    
    local maj=0 min=0 patch=0
    if [[ "$p_raw" =~ ^([0-9]+)\.([0-9]+)(\.([0-9]+))? ]]; then
        maj="${BASH_REMATCH[1]}"
        min="${BASH_REMATCH[2]}"
        patch="${BASH_REMATCH[4]:-0}"
    else
        echo "❌ [Release] Cannot calculate bump from non-numeric previous version: $prev" >&2
        return 1
    fi

    case "$bump" in
        patch)
            echo "$maj.$min.$((patch + 1))"
            ;;
        minor)
            echo "$maj.$((min + 1)).0"
            ;;
        major)
            echo "$((maj + 1)).0.0"
            ;;
        *)
            echo "❌ [Release] Unknown bump type: $bump (must be patch, minor, or major)" >&2
            return 1
            ;;
    esac
}

cmd_release() {
    local repo_root
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -z "$repo_root" ]; then
        echo "❌ [Release] Not inside a Git repository." >&2
        return 1
    fi

    # Parse arguments and bare tokens
    local version_arg=""
    local opt_unverified=0
    local opt_yes=0
    local opt_check=0
    local opt_push=0
    local opt_json=0
    local opt_no_archive=0
    local opt_no_changelog=0

    while [ $# -gt 0 ]; do
        case "$1" in
            unverified)   opt_unverified=1 ;;
            yes)          opt_yes=1 ;;
            check)        opt_check=1 ;;
            push)         opt_push=1 ;;
            json)         opt_json=1 ;;
            no-archive)   opt_no_archive=1 ;;
            no-changelog) opt_no_changelog=1 ;;
            --help|-h)
                echo "Usage: aapp release <version-or-bump> [unverified] [yes] [check] [push] [json] [no-archive] [no-changelog]"
                echo ""
                echo "Execute milestone release bundling, changelog rollup, and hook-based versioning."
                echo ""
                echo "Arguments:"
                echo "  <version-or-bump>  Explicit version (e.g. 1.2.0, v1.0.1.alpha) or bump token (patch, minor, major)"
                echo "  unverified         Bypass commit reachability gate and record unverified status"
                echo "  yes                Bypass interactive confirmation prompt"
                echo "  check              Execute Phase A pre-flight simulation only without mutating"
                echo "  push               Push release branch, tags, and plans branch to remote after release"
                echo "  json               Output machine-readable JSON release manifest/simulation"
                echo "  no-archive         Skip bundling completed plans and archived issues into release folder"
                echo "  no-changelog       Skip root CHANGELOG.md existence check and rollup"
                return 0
                ;;
            *)
                if [ -z "$version_arg" ]; then
                    version_arg="$1"
                else
                    echo "❌ [Release] Unexpected argument: $1" >&2
                    return 1
                fi
                ;;
        esac
        shift
    done

    # 1. Resolve Plans directory
    local plans_dir=""
    if [ -d "$repo_root/.plans" ]; then
        plans_dir="$repo_root/.plans"
    elif [ -d "$repo_root/current" ] && [ -d "$repo_root/done" ]; then
        plans_dir="$repo_root"
    else
        plans_dir="$repo_root/.plans"
    fi

    # 2. Resolve Tag Prefix
    local tag_prefix
    if git config --get aapp.tagPrefix >/dev/null 2>&1; then
        tag_prefix="$(git config --get aapp.tagPrefix)"
    else
        tag_prefix="v"
    fi

    # 3. Resolve Previous Version / Tag
    local prev_tag="" prev_version=""
    prev_tag="$(git describe --tags --abbrev=0 2>/dev/null || true)"
    if [ -n "$prev_tag" ]; then
        prev_version="${prev_tag#"$tag_prefix"}"
        prev_version="${prev_version#v}"
    else
        local init_v
        init_v="$(git config --get aapp.initialVersion 2>/dev/null || true)"
        if [ -n "$init_v" ]; then
            prev_version="${init_v#v}"
            prev_tag="${tag_prefix}${prev_version}"
        fi
    fi

    # 4. Resolve Target Version & Bump Type
    local target_raw="" bump_type="release"
    if [ -z "$version_arg" ]; then
        if [ -z "$prev_version" ]; then
            if [ -t 0 ]; then
                printf "Enter initial release version [default: v1.0.0]: "
                read -r user_v
                user_v="${user_v:-v1.0.0}"
                version_arg="$user_v"
            else
                echo "❌ [Release] No previous release tag found. Specify an explicit version or set 'git config aapp.initialVersion <ver>'." >&2
                return 1
            fi
        else
            echo "❌ [Release] Missing version or bump token. Specify <version-or-bump> (e.g. patch, minor, major, 1.0.0)." >&2
            return 1
        fi
    fi

    case "$version_arg" in
        patch|minor|major)
            bump_type="$version_arg"
            if [ -z "$prev_version" ]; then
                if [ -t 0 ]; then
                    printf "Enter initial release version [default: v1.0.0]: "
                    read -r user_v
                    user_v="${user_v:-v1.0.0}"
                    version_arg="$user_v"
                    target_raw="${version_arg#v}"
                else
                    echo "❌ [Release] No previous release tag found. Specify an explicit version or set 'git config aapp.initialVersion <ver>'." >&2
                    return 1
                fi
            else
                target_raw="$(_release_calc_bump "$bump_type" "$prev_version")" || return 1
            fi
            ;;
        *)
            if ! _release_validate_version "$version_arg"; then
                echo "❌ [Release] Invalid version format: '$version_arg'." >&2
                echo "   Supported: 3-segment (1.0.0), 2-segment (1.0), with optional suffix up to 30 chars (1.0.0-rc.1)." >&2
                return 1
            fi
            target_raw="${version_arg#v}"
            bump_type="explicit"
            ;;
    esac

    local target_tag="${tag_prefix}${target_raw}"
    local previous_tag="${prev_tag:-none}"
    local previous_version="${prev_version:-none}"

    # Verify tag does not already exist
    if git rev-parse --verify "refs/tags/$target_tag" >/dev/null 2>&1; then
        echo "❌ [Release Refusal] Tag '$target_tag' already exists in the repository." >&2
        return 1
    fi

    # 5. Resolve Branches and Topology
    local current_branch dev_branch release_branch
    current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")"
    
    dev_branch="$(aapp_dev_branch)" || dev_branch=""
    
    release_branch="$(git config aapp.releaseBranch 2>/dev/null || true)"
    if [ -z "$release_branch" ]; then
        local prot_candidates
        prot_candidates="$(git config aapp.protectedBranches 2>/dev/null || echo "main master production")"
        for pb in $prot_candidates; do
            if git show-ref --verify --quiet "refs/heads/$pb" 2>/dev/null || git show-ref --verify --quiet "refs/remotes/origin/$pb" 2>/dev/null; then
                release_branch="$pb"
                break
            fi
        done
        [ -z "$release_branch" ] && release_branch="main"
    fi

    # Determine topology
    local is_multibranch=0
    if [ -n "$dev_branch" ] && [ "$dev_branch" != "$release_branch" ] && git show-ref --verify --quiet "refs/heads/$dev_branch" 2>/dev/null; then
        is_multibranch=1
    fi

    # --------------------------------------------------------------------------
    # PHASE A: Mandatory Read-Only Pre-Flight Gate & Simulation (Non-Mutating)
    # --------------------------------------------------------------------------
    if [ "$opt_json" -eq 0 ]; then
        echo "🔍 [Release Pre-Flight] Initiating validation for $target_tag..."
    fi

    # Check 1: Primary and Kit Worktree Cleanliness
    # Primary repo
    local dirty_files
    dirty_files="$(git status --porcelain 2>/dev/null | grep -v '^[?][?]' || true)"
    if [ -n "$dirty_files" ]; then
        echo "❌ [Release Refusal] Uncommitted changes detected in primary working tree. Aborting release to preserve uncommitted work." >&2
        [ "$opt_json" -eq 0 ] && echo "$dirty_files" | sed 's/^/   /' >&2
        return 1
    fi

    # Kit worktrees
    if [ -d "$plans_dir" ] && [ "$plans_dir" != "$repo_root" ]; then
        local plans_dirty
        plans_dirty="$(git -C "$plans_dir" status --porcelain 2>/dev/null | grep -v '^[?][?]' || true)"
        if [ -n "$plans_dirty" ]; then
            echo "❌ [Release Refusal] Uncommitted changes detected in .plans worktree. Aborting release to preserve uncommitted work." >&2
            [ "$opt_json" -eq 0 ] && echo "$plans_dirty" | sed 's/^/   /' >&2
            return 1
        fi
    fi

    local agents_dir="$repo_root/.agents"
    if [ -d "$agents_dir/.git" ]; then
        local agents_dirty
        agents_dirty="$(git -C "$agents_dir" status --porcelain 2>/dev/null | grep -v '^[?][?]' || true)"
        if [ -n "$agents_dirty" ]; then
            echo "❌ [Release Refusal] Uncommitted changes detected in .agents worktree. Aborting release to preserve uncommitted work." >&2
            return 1
        fi
    fi

    local hooks_dir="$repo_root/.githooks"
    if [ -d "$hooks_dir/.git" ]; then
        local hooks_dirty
        hooks_dirty="$(git -C "$hooks_dir" status --porcelain 2>/dev/null | grep -v '^[?][?]' || true)"
        if [ -n "$hooks_dirty" ]; then
            echo "❌ [Release Refusal] Uncommitted changes detected in .githooks worktree. Aborting release to preserve uncommitted work." >&2
            return 1
        fi
    fi

    # Check 2: Automated Test Suite Quality Gate
    local test_cmd
    test_cmd="$(git config aapp.testCommand 2>/dev/null || true)"
    if [ -n "$test_cmd" ]; then
        [ "$opt_json" -eq 0 ] && echo "🧪 [Test Gate] Executing configured test command: $test_cmd"
        if ! eval "$test_cmd"; then
            echo "❌ [Release Refusal] Test suite failed. Releases require all test suites to pass 100%." >&2
            return 1
        fi
    fi

    # Check 3: Pre-Release Lifecycle Quality Gate Hook
    local pre_rel_payload
    pre_rel_payload="{\"event\":\"pre-release\",\"tag\":\"$target_tag\",\"version\":\"$target_raw\",\"previousVersion\":\"$previous_version\",\"bump\":\"$bump_type\"}"
    if declare -f dispatch_hook >/dev/null; then
        if ! dispatch_hook "pre-release" "$pre_rel_payload"; then
            echo "❌ [pre-release Refusal] Pre-release hook rejected release." >&2
            return 1
        fi
    fi

    # Check 4: Tag Signing Capability Inspection
    local is_signed=0
    local gpg_sign signing_key
    gpg_sign="$(git config --bool tag.gpgSign 2>/dev/null || echo "false")"
    signing_key="$(git config user.signingkey 2>/dev/null || true)"
    if [ "$gpg_sign" = "true" ] || [ -n "$signing_key" ]; then
        is_signed=1
    fi

    # Check 5: Changelog Existence Gate
    if [ "$opt_no_changelog" -eq 0 ]; then
        if [ ! -f "$repo_root/CHANGELOG.md" ]; then
            echo "❌ [Release Refusal] Repository root CHANGELOG.md missing. Add CHANGELOG.md or pass 'no-changelog' token." >&2
            return 1
        fi
    fi

    # Check 6: Archive Commit Reachability Gate (Strict 2-Tier Ladder & Override)
    local check_branch="$current_branch"
    [ "$is_multibranch" -eq 1 ] && check_branch="$dev_branch"

    local done_plans=()
    local done_plan_ids=()
    local done_plan_shas=()
    local done_plan_slugs=()

    if [ "$opt_no_archive" -eq 0 ] && [ -d "$plans_dir/done" ]; then
        while IFS= read -r pf; do
            [ -f "$pf" ] || continue
            local bname
            bname="$(basename "$pf")"
            case "$bname" in
                000-*) continue ;;
            esac
            done_plans+=("$pf")

            local pid psha pslug
            pid="$(sed -nE 's/^[[:space:]]*[\*|-][[:space:]]*\*\*Plan ID:\*\*[[:space:]]*([^[:space:]]+).*/\1/p' "$pf" 2>/dev/null || true)"
            [ -z "$pid" ] && pid="$(basename "$pf" .md)"
            done_plan_ids+=("$pid")

            psha="$(sed -nE 's/^[[:space:]]*[\*|-][[:space:]]*\*\*Commits:\*\*[[:space:]]*`?([0-9a-fA-F]{7,40})`?.*/\1/p' "$pf" 2>/dev/null || true)"
            if [ -z "$psha" ]; then
                if grep -qE '^[[:space:]]*[\*|-][[:space:]]*\*\*Commits:\*\*[[:space:]]*none' "$pf" 2>/dev/null; then
                    psha="none"
                fi
            fi
            done_plan_shas+=("${psha:-none}")

            pslug="${bname%.md}"
            pslug="$(echo "$pslug" | sed -E 's/^[pP]-?[0-9]+-//')"
            done_plan_slugs+=("$pslug")

            # Reachability evaluation
            if [ "$psha" = "none" ] || [ -z "$psha" ]; then
                [ "$opt_json" -eq 0 ] && echo "ℹ️  [Reachability] Plan $pid has no recorded code commits; skipping reachability check."
            else
                local reachable=0
                # Tier 1: Git Ancestry
                if git merge-base --is-ancestor "$psha" "$check_branch" 2>/dev/null; then
                    reachable=1
                else
                    # Tier 2: Plan-ID Trailer
                    if git log "$check_branch" --format="%(trailers:key=Plan-ID,valueonly)" 2>/dev/null | grep -qw "$pid"; then
                        reachable=1
                    fi
                fi

                if [ "$reachable" -eq 0 ]; then
                    if [ "$opt_unverified" -eq 1 ]; then
                        [ "$opt_json" -eq 0 ] && echo "⚠️  [Reachability Warning] Plan $pid commit '$psha' not reachable in $check_branch; bypassing via 'unverified' token."
                    else
                        echo "❌ [Release Refusal] Plan $pid commit '$psha' is not reachable in $check_branch (Tier 1 ancestry and Tier 2 trailer checks failed)." >&2
                        echo "   Run with 'unverified' token to override reachability verification." >&2
                        return 1
                    fi
                fi
            fi
        done < <(find "$plans_dir/done" -maxdepth 1 -name "*.md" 2>/dev/null | sort)
    fi

    # Check 7: Branch Parity & Fast-Forward Gate
    if [ "$is_multibranch" -eq 1 ]; then
        if git show-ref --verify --quiet "refs/heads/$release_branch" 2>/dev/null; then
            if ! git merge-base --is-ancestor "$release_branch" "$dev_branch" 2>/dev/null; then
                echo "❌ [Release Refusal] Development branch '$dev_branch' cannot be fast-forward merged into release branch '$release_branch'." >&2
                return 1
            fi
        fi
    fi

    # Check 8: Unmerged Branches Advisory Inspection (Non-Blocking)
    local unmerged_branches=""
    if [ -n "$check_branch" ]; then
        unmerged_branches="$(git branch --no-merged "$check_branch" 2>/dev/null | sed 's/^[ *]*//' | grep -E '^(plan/|feature/)' || true)"
    fi

    # Count defects in done/000-issues-archive.md
    local bundled_issues=()
    local done_archive_file="$plans_dir/done/000-issues-archive.md"
    if [ "$opt_no_archive" -eq 0 ] && [ -f "$done_archive_file" ]; then
        while IFS= read -r iid; do
            [ -n "$iid" ] && bundled_issues+=("$iid")
        done < <(AAPP_LEDGER_ARCHIVE="$done_archive_file" ledger_ids archive)
    fi

    # In-flight active plans count
    local inflight_plans=()
    if [ -d "$plans_dir/current" ]; then
        while IFS= read -r cur_pf; do
            [ -f "$cur_pf" ] || continue
            case "$(basename "$cur_pf")" in 000-*|fix-*) continue ;; esac
            inflight_plans+=("$(basename "$cur_pf")")
        done < <(find "$plans_dir/current" -maxdepth 1 -name "*.md" 2>/dev/null | sort)
    fi

    # Simulation representation
    local head_sha
    head_sha="$(git rev-parse --short HEAD 2>/dev/null || echo "0000000")"
    local rel_date
    rel_date="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    if [ "$opt_json" -eq 1 ]; then
        # Machine-readable JSON output
        local plans_json_arr=()
        for ((idx=0; idx<${#done_plans[@]}; idx++)); do
            plans_json_arr+=("{\"id\":\"${done_plan_ids[idx]}\",\"slug\":\"${done_plan_slugs[idx]}\",\"file\":\"$(basename "${done_plans[idx]}")\",\"commit\":\"${done_plan_shas[idx]}\"}")
        done
        local plans_joined
        plans_joined="$(IFS=,; echo "${plans_json_arr[*]}")"

        local issues_json_arr=()
        for ((idx=0; idx<${#bundled_issues[@]}; idx++)); do
            issues_json_arr+=("{\"id\":\"#${bundled_issues[idx]}\"}")
        done
        local issues_joined
        issues_joined="$(IFS=,; echo "${issues_json_arr[*]}")"

        local json_output
        json_output=$(cat << EOF
{
  "schemaVersion": "1.0.0",
  "tag": "$target_tag",
  "version": "$target_raw",
  "rawVersion": "$target_raw",
  "previousVersion": "$previous_version",
  "bump": "$bump_type",
  "releaseDate": "$rel_date",
  "devBranch": "${dev_branch:-$current_branch}",
  "releaseBranch": "$release_branch",
  "commitSha": "$head_sha",
  "signedTag": $( [ "$is_signed" -eq 1 ] && echo "true" || echo "false" ),
  "unverified": $( [ "$opt_unverified" -eq 1 ] && echo "true" || echo "false" ),
  "metrics": {
    "plansCount": ${#done_plans[@]},
    "issuesCount": ${#bundled_issues[@]},
    "inFlightPlansCount": ${#inflight_plans[@]}
  },
  "plans": [
    $plans_joined
  ],
  "issues": [
    $issues_joined
  ]
}
EOF
)
        echo "$json_output"
    else
        echo "════════════════════════════════════════════════════════════════════════════"
        echo "📋 Release Simulation: $previous_tag ➔ $target_tag ($bump_type)"
        echo "════════════════════════════════════════════════════════════════════════════"
        echo "  • Tag:              $target_tag ($([ "$is_signed" -eq 1 ] && echo "cryptographically signed" || echo "annotated"))"
        echo "  • Reachability:     $([ "$opt_unverified" -eq 1 ] && echo "⚠️  unverified override" || echo "✅ verified ancestry")"
        echo "  • Bundled Plans:    ${#done_plans[@]} completed blueprints moving to release bundle"
        for dp in "${done_plans[@]}"; do
            echo "      - $(basename "$dp")"
        done
        echo "  • In-Flight Plans:  ${#inflight_plans[@]} active blueprints carrying over to next cycle"
        echo "  • Bundled Defects:  ${#bundled_issues[@]} defects in 000-issues-archive.md"
        if [ -n "$unmerged_branches" ]; then
            echo "  • Unmerged Branches (Advisory):"
            echo "$unmerged_branches" | sed 's/^/      - /'
        fi
        echo "════════════════════════════════════════════════════════════════════════════"
    fi

    # Check mode exit contract
    if [ "$opt_check" -eq 1 ]; then
        [ "$opt_json" -eq 0 ] && echo "✅ [Check Contract] Pre-flight simulation completed successfully. Zero mutations applied."
        return 0
    fi

    # Confirmation safety contract
    if [ "$opt_yes" -eq 0 ]; then
        if [ -t 0 ]; then
            printf "Proceed with release %s? [y/N]: " "$target_tag"
            read -r confirm
            case "$confirm" in
                [yY]|[yY][eE][sS]) ;;
                *)
                    echo "Release cancelled by user."
                    return 0
                    ;;
            esac
        else
            echo "ℹ️  Non-interactive session: pass 'yes' bare token to proceed with mutations."
            return 0
        fi
    fi

    # --------------------------------------------------------------------------
    # PHASE B: Atomic Release Mutation (Mutating)
    # --------------------------------------------------------------------------
    _AAPP_REL_ACTIVE_MUTATION=1
    _AAPP_REL_TARGET_TAG="$target_tag"
    _AAPP_REL_CURRENT_BRANCH="$current_branch"
    _AAPP_REL_DEV_BRANCH="$dev_branch"
    _AAPP_REL_RELEASE_BRANCH="$release_branch"
    _AAPP_REL_PLANS_DIR="$plans_dir"

    # Step 1: Capture transaction snapshots and install fail-closed trap
    _AAPP_REL_DEV_SNAP="$(git rev-parse "refs/heads/$dev_branch" 2>/dev/null || true)"
    _AAPP_REL_RELEASE_SNAP="$(git rev-parse "refs/heads/$release_branch" 2>/dev/null || true)"
    if [ -d "$plans_dir/.git" ] || [ -f "$plans_dir/.git" ]; then
        _AAPP_REL_PLANS_SNAP="$(git -C "$plans_dir" rev-parse refs/heads/plans 2>/dev/null || true)"
    fi

    trap '_release_rollback' ERR EXIT

    [ "$opt_json" -eq 0 ] && echo "🚀 [Phase B] Executing release mutations for $target_tag..."

    # Step 2: Hook-Based Version Increment (on-release Action Delegate)
    local on_rel_payload
    on_rel_payload="{\"event\":\"on-release\",\"tag\":\"$target_tag\",\"version\":\"$target_raw\",\"previousVersion\":\"$previous_version\",\"bump\":\"$bump_type\"}"
    export AAPP_RELEASE_VERSION="$target_tag"
    export AAPP_RAW_VERSION="$target_raw"
    export AAPP_PREVIOUS_VERSION="$previous_version"
    export AAPP_VERSION_BUMP="$bump_type"

    if declare -f dispatch_hook >/dev/null; then
        if ! dispatch_hook "on-release" "$on_rel_payload"; then
            echo "❌ [on-release Refusal] on-release hook handler failed." >&2
            return 1
        fi
    fi

    # Step 3: Changelog Rollup (Skipped if no-changelog)
    local cl_file="$repo_root/CHANGELOG.md"
    local cl_date
    cl_date="$(date +"%Y-%m-%d")"
    local cl_content=""
    if [ "$opt_no_changelog" -eq 0 ] && [ -f "$cl_file" ]; then
        local tmp_cl="$cl_file.aapp-rel.$$"
        awk -v ver="$target_raw" -v cdate="$cl_date" '
            BEGIN { rolled = 0; in_unrel = 0 }
            /^## \[Unreleased\]/ {
                print "## [Unreleased]"
                print ""
                printf "## [%s] - %s\n", ver, cdate
                rolled = 1
                in_unrel = 1
                next
            }
            /^## \[/ && in_unrel {
                in_unrel = 0
            }
            { print }
        ' "$cl_file" > "$tmp_cl" && mv "$tmp_cl" "$cl_file"

        # Stage changelog in primary working tree
        git add "$cl_file" 2>/dev/null || true
    fi

    # Step 4: Milestone Bundling (Skipped if no-archive or zero plans)
    local bundle_dir="$plans_dir/release/$target_tag"
    _AAPP_REL_BUNDLE_DIR="$bundle_dir"

    local plans_committed_list=()
    if [ "$opt_no_archive" -eq 0 ] && [ ${#done_plans[@]} -gt 0 ]; then
        mkdir -p "$bundle_dir/plans"

        # 4.1 Move blueprints into bundle
        for dp in "${done_plans[@]}"; do
            local fn
            fn="$(basename "$dp")"
            mv "$dp" "$bundle_dir/plans/$fn"
            plans_committed_list+=("release/$target_tag/plans/$fn" "done/$fn")
        done

        # 4.2 Move and relink defects
        if [ -f "$done_archive_file" ]; then
            mv "$done_archive_file" "$bundle_dir/000-issues-archive.md"
            # Update links inside relocated archive: done/Pxx -> ../release/<tag>/plans/Pxx
            for ((idx=0; idx<${#done_plans[@]}; idx++)); do
                local old_link="done/$(basename "${done_plans[idx]}")"
                local new_link="release/$target_tag/plans/$(basename "${done_plans[idx]}")"
                sed -i -E "s#$old_link#$new_link#g" "$bundle_dir/000-issues-archive.md" 2>/dev/null || true
            done
            plans_committed_list+=("release/$target_tag/000-issues-archive.md")
        fi

        # 4.3 Generate Tag Archive Ledger: 000-archive-ledger.md
        local tag_ledger="$bundle_dir/000-archive-ledger.md"
        {
            echo "# 🏛️ Archival Ledger ($target_tag)"
            echo ""
            echo "Verified, shipped, and archived architecture blueprints for milestone \`$target_tag\`."
            echo ""
            echo "| Date Completed | Plan ID | Plan File | Target Issue / Milestone | Verification Commit | Impact Summary (Repo-Relative) |"
            echo "| :--- | :--- | :--- | :--- | :--- | :--- |"
            for ((idx=0; idx<${#done_plans[@]}; idx++)); do
                local pfile="${done_plans[idx]}"
                local pfname
                pfname="$(basename "$pfile")"
                local pid="${done_plan_ids[idx]}"
                local psha="${done_plan_shas[idx]}"
                local pdate
                pdate="$(sed -nE 's/^[[:space:]]*[\*|-][[:space:]]*\*\*Created:\*\*[[:space:]]*([0-9-]+).*/\1/p' "$bundle_dir/plans/$pfname" 2>/dev/null || echo "$cl_date")"
                local pissue
                pissue="$(sed -nE 's/^[[:space:]]*[\*|-][[:space:]]*\*\*Target Issue \/ Milestone:\*\*[[:space:]]*(.*)/\1/p' "$bundle_dir/plans/$pfname" 2>/dev/null || echo "none")"
                [ -z "$pissue" ] && pissue="none"
                local ptitle
                ptitle="$(sed -nE 's/^#[[:space:]]+(🗺️[[:space:]]+Plan[[:space:]]+[^:]+:[[:space:]]+)?(.*)/\2/p' "$bundle_dir/plans/$pfname" 2>/dev/null | head -n 1 || echo "$pfname")"
                [ -z "$ptitle" ] && ptitle="$pfname"

                echo "| $pdate | \`$pid\` | [\`$pfname\`](plans/$pfname) | $pissue | \`$psha\` | $ptitle |"
            done
        } > "$tag_ledger"
        plans_committed_list+=("release/$target_tag/000-archive-ledger.md")

        # 4.4 Generate manifest.md
        local manifest_md="$bundle_dir/manifest.md"
        {
            echo "# 📦 Release Milestone: $target_tag"
            echo ""
            echo "* **Version:** $target_raw"
            echo "* **Release Date:** $rel_date"
            echo "* **Commit SHA:** \`$head_sha\`"
            echo "* **Development Branch:** \`${dev_branch:-$current_branch}\`"
            echo "* **Release Branch:** \`$release_branch\`"
            echo "* **Cryptographic Signature:** $( [ "$is_signed" -eq 1 ] && echo "Signed" || echo "Annotated" )"
            echo "* **Reachability Status:** $( [ "$opt_unverified" -eq 1 ] && echo "Unverified Override" || echo "Verified Ancestry" )"
            echo ""
            echo "## 📊 Milestone Metrics"
            echo "* **Bundled Plans:** ${#done_plans[@]}"
            echo "* **Resolved Issues:** ${#bundled_issues[@]}"
            echo ""
            echo "## 🗺️ Bundled Architecture Plans"
            for ((idx=0; idx<${#done_plans[@]}; idx++)); do
                echo "* \`${done_plan_ids[idx]}\`: [\`$(basename "${done_plans[idx]}")\`](plans/$(basename "${done_plans[idx]}"))"
            done
            echo ""
            echo "## 🐛 Resolved Issues"
            for ((idx=0; idx<${#bundled_issues[@]}; idx++)); do
                echo "* #${bundled_issues[idx]}"
            done
        } > "$manifest_md"
        plans_committed_list+=("release/$target_tag/manifest.md")

        # 4.5 Generate manifest.json
        local manifest_json="$bundle_dir/manifest.json"
        cat << EOF > "$manifest_json"
{
  "schemaVersion": "1.0.0",
  "tag": "$target_tag",
  "version": "$target_raw",
  "rawVersion": "$target_raw",
  "previousVersion": "$previous_version",
  "bump": "$bump_type",
  "releaseDate": "$rel_date",
  "devBranch": "${dev_branch:-$current_branch}",
  "releaseBranch": "$release_branch",
  "commitSha": "$head_sha",
  "signedTag": $( [ "$is_signed" -eq 1 ] && echo "true" || echo "false" ),
  "unverified": $( [ "$opt_unverified" -eq 1 ] && echo "true" || echo "false" ),
  "metrics": {
    "plansCount": ${#done_plans[@]},
    "issuesCount": ${#bundled_issues[@]}
  },
  "plans": [
    $(IFS=,; echo "${plans_json_arr[*]}")
  ],
  "issues": [
    $(IFS=,; echo "${issues_json_arr[*]}")
  ]
}
EOF
        plans_committed_list+=("release/$target_tag/manifest.json")
    else
        [ "$opt_json" -eq 0 ] && echo "ℹ️  No unreleased plans or issues to bundle (skipping plan migration)."
    fi

    # Step 5: Master Ledger Rollup & Truncation
    local master_ledger="$plans_dir/done/000-archive-ledger.md"
    if [ -f "$master_ledger" ]; then
        local tmp_ml="$master_ledger.aapp-rel.$$"
        local summary_row="| \`$target_tag\` | $cl_date | [\`$target_tag Ledger\`](../release/$target_tag/000-archive-ledger.md) | ${#done_plans[@]} | ${#bundled_issues[@]} | \`$head_sha\` | Release milestone $target_tag |"
        
        # Check if master ledger already has ## 🏷️ Shipped Releases
        if grep -q '^## 🏷️ Shipped Releases' "$master_ledger"; then
            awk -v srow="$summary_row" '
                /^## 🏷️ Shipped Releases/ {
                    print; in_shipped = 1; next
                }
                in_shipped && /^\|[[:space:]]*:---/ {
                    print; print srow; in_shipped = 0; next
                }
                /^## ⚡ Current Unreleased Cycle/ {
                    in_unrel = 1; print; next
                }
                in_unrel && /^\|[[:space:]]*:---/ {
                    print; in_unrel = 0; skip_unrel = 1; next
                }
                skip_unrel && /^\|/ { next }
                skip_unrel && !/^\|/ { skip_unrel = 0 }
                { print }
            ' "$master_ledger" > "$tmp_ml" && mv "$tmp_ml" "$master_ledger"
        else
            # Reconstruct with two clear sections
            {
                echo "# 🏛️ Archival Ledger (Master Release Index)"
                echo ""
                echo "## 🏷️ Shipped Releases"
                echo "| Release | Release Date | Tag Ledger | Plans | Issues | Verification Commit | Impact Summary |"
                echo "| :--- | :--- | :--- | :---: | :---: | :--- | :--- |"
                echo "$summary_row"
                echo ""
                echo "## ⚡ Current Unreleased Cycle"
                echo "| Date Completed | Plan ID | Plan File | Target Issue / Milestone | Verification Commit | Impact Summary (Repo-Relative) |"
                echo "| :--- | :--- | :--- | :--- | :--- | :--- |"
            } > "$master_ledger"
        fi
        plans_committed_list+=("done/000-archive-ledger.md")
    fi

    # Reset lean done/000-issues-archive.md
    if [ "$opt_no_archive" -eq 0 ] && [ ! -f "$done_archive_file" ]; then
        mkdir -p "$plans_dir/done"
        {
            echo "# 🏛️ Master Issue Archive Ledger"
            echo ""
            echo "| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |"
            echo "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |"
        } > "$done_archive_file"
        plans_committed_list+=("done/000-issues-archive.md")
    fi

    # Step 6: Commit .plans worktree
    if [ ${#plans_committed_list[@]} -gt 0 ]; then
        # Filter duplicates
        local unique_plans_targets=()
        for pt in "${plans_committed_list[@]}"; do
            [ -e "$plans_dir/$pt" ] || continue
            local already=0
            for u in "${unique_plans_targets[@]}"; do [ "$u" = "$pt" ] && { already=1; break; }; done
            [ "$already" -eq 0 ] && unique_plans_targets+=("$pt")
        done
        PLANS_DIR="$plans_dir" plans_commit "release(plans): bundle $target_tag milestone and roll ledgers" "${unique_plans_targets[@]}" || {
            echo "❌ [Release Error] Failed to commit .plans milestone bundle." >&2
            return 1
        }
    fi

    # Step 7: Git Parity Merge & Tagging
    # 7.1 Commit working tree version updates if any exist
    local wt_status
    wt_status="$(git status --porcelain 2>/dev/null | grep -v '^[?][?]' || true)"
    if [ -n "$wt_status" ]; then
        git add -u
        git commit -m "chore(release): bump version to $target_tag" || true
    fi

    # 7.2 Parity Merge on multi-branch topology
    if [ "$is_multibranch" -eq 1 ]; then
        local merge_source="$current_branch"
        [ -n "$dev_branch" ] && merge_source="$dev_branch"
        git checkout "$release_branch" || return 1
        ALLOW_MAIN_COMMIT=1 git merge --ff-only "$merge_source" || {
            echo "❌ [Release Error] Fast-forward merge of $merge_source into $release_branch failed." >&2
            return 1
        }
    fi

    # 7.3 Create Tag
    local tag_cmd=(git tag)
    if [ "$is_signed" -eq 1 ]; then
        tag_cmd+=(-s "$target_tag" -m "Release $target_tag")
    else
        tag_cmd+=(-a "$target_tag" -m "Release $target_tag")
    fi

    "${tag_cmd[@]}" || {
        echo "❌ [Release Error] Failed to create git tag $target_tag." >&2
        return 1
    }

    # Step 8: Disarm Rollback Trap
    trap - ERR EXIT
    _AAPP_REL_ACTIVE_MUTATION=0

    # Step 9: Publication Guidance / Push
    if [ "$opt_push" -eq 1 ]; then
        [ "$opt_json" -eq 0 ] && echo "🚀 Pushing release branch, tag, and plans to remote..."
        git push origin "$release_branch"
        git push origin "$target_tag"
        if [ -d "$plans_dir/.git" ] || [ -f "$plans_dir/.git" ]; then
            git -C "$plans_dir" push origin plans 2>/dev/null || true
        fi
    else
        if [ "$opt_json" -eq 0 ]; then
            echo ""
            echo "════════════════════════════════════════════════════════════════════════════"
            echo "🚀 Release $target_tag successfully created locally!"
            echo "To publish release commits and tags to remote, run:"
            echo "  git push origin $release_branch && git push origin $target_tag && git push origin plans"
            echo "════════════════════════════════════════════════════════════════════════════"
        fi
    fi

    # Step 10: Post-Release Notification Hook
    local post_rel_payload
    post_rel_payload="{\"event\":\"post-release\",\"tag\":\"$target_tag\",\"version\":\"$target_raw\",\"previousVersion\":\"$previous_version\",\"bump\":\"$bump_type\",\"commitSha\":\"$head_sha\"}"
    if declare -f dispatch_hook >/dev/null; then
        dispatch_hook "post-release" "$post_rel_payload" || true
    fi

    return 0
}

# If run directly as script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    cmd_release "$@"
fi
