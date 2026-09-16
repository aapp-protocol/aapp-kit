#!/usr/bin/env bash
# ==============================================================================
# AAPP Historical Scrubber & SHA Reference Repair Runbook (P-14 §D)
#
# Converts legacy synthetic AI trailers:
#   Co-authored-by: Antigravity <antigravity@google.com>
# into email-free semantic trailers:
#   AI-Agent: Antigravity
#   AI-Vendor: Google
#
# Updates commit SHAs in ledger files (.plans/done/000-archive-ledger.md,
# .plans/done/000-issues-archive.md, .plans/ISSUES.md, CHANGELOG.md) and
# verifies 100% SHA resolution via Planning Health Pair 6.
#
# Usage:
#   ./scripts/scrub-attribution.sh --dry-run
#   ./scripts/scrub-attribution.sh --confirm
# ==============================================================================
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN=0
CONFIRMED=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --confirm)
            CONFIRMED=1
            shift
            ;;
        -h|--help)
            cat <<EOF
Usage: ./scripts/scrub-attribution.sh [options]

Historical AI Attribution Scrubber & SHA Repair Runbook

Options:
  --dry-run   Preview affected commits, notes, and ledger files without modifying history
  --confirm   Execute live conversion and reference repair (requires full repository backup)
  -h, --help  Show this help message

SAFETY NOTICE:
  Live rewriting changes commit hashes and invalidates existing worktrees.
  Ensure a complete offline backup of the repository is made before running with --confirm.
EOF
            exit 0
            ;;
        *)
            echo "❌ Unknown argument: '$1'" >&2
            echo "   Use --dry-run or --confirm (see --help)" >&2
            exit 1
            ;;
    esac
done

if [ "$DRY_RUN" -eq 0 ] && [ "$CONFIRMED" -eq 0 ]; then
    echo "⚠️  [Safety Gate] Historical rewriting alters commit SHAs across all branches."
    echo "   To preview affected commits and ledger files, run:"
    echo "     ./scripts/scrub-attribution.sh --dry-run"
    echo ""
    echo "   To execute live conversion after taking an offline backup, run:"
    echo "     ./scripts/scrub-attribution.sh --confirm"
    exit 1
fi

echo "============================================================"
echo "  AAPP Historical Attribution Scrubber (P-14 §D)"
echo "============================================================"
echo "📍 Repository root: $REPO_ROOT"
echo ""

# ------------------------------------------------------------------------------
# 1. Pre-flight Checks
# ------------------------------------------------------------------------------
echo "🔍 Step 1: Pre-flight Checks & History Scanning..."

# 1a. Working Tree Hygiene
if [ "$DRY_RUN" -eq 0 ] && [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "❌ Error: Working tree has uncommitted changes. Stash or commit before running scrubber." >&2
    git status -s
    exit 1
elif [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "ℹ️  Working tree has uncommitted changes (permitted during --dry-run preview)."
fi

# 1b. Scan for Legacy Co-authored-by Trailers
LEGACY_COMMITS=()
while IFS= read -r c_sha; do
    [ -n "$c_sha" ] && LEGACY_COMMITS+=("$c_sha")
done < <(git log --all --grep="Co-authored-by:.*<.*>" --format="%H" 2>/dev/null || true)

LEGACY_COUNT="${#LEGACY_COMMITS[@]}"
echo "   Found $LEGACY_COUNT commit(s) carrying legacy Co-authored-by trailers."

if [ "$LEGACY_COUNT" -gt 0 ]; then
    echo ""
    echo "   Sample of affected commits:"
    for c in "${LEGACY_COMMITS[@]:0:5}"; do
        local_subj="$(git log -1 --format="%h %s" "$c")"
        echo "     • $local_subj"
    done
    if [ "$LEGACY_COUNT" -gt 5 ]; then
        echo "     ... and $((LEGACY_COUNT - 5)) more."
    fi
    echo ""
fi

# 1c. Notes Pre-flight (§D.1)
NOTES_EXIST=0
NOTES_COUNT="$(git for-each-ref --format="%(refname)" refs/notes/ 2>/dev/null | wc -l || echo 0)"
if [ "$NOTES_COUNT" -gt 0 ]; then
    NOTES_EXIST=1
    echo "ℹ️  Found $NOTES_COUNT git notes reference(s). Note that filter-branch does not"
    echo "   rewrite refs/notes/ automatically; notes backup and migration is required."
else
    echo "   Zero git notes refs found (clean pre-flight)."
fi

# 1d. Scan for Referenced SHAs in Ledgers
LEDGER_FILES=(
    ".plans/done/000-archive-ledger.md"
    ".plans/done/000-issues-archive.md"
    ".plans/ISSUES.md"
    "CHANGELOG.md"
)

FOUND_LEDGERS=()
for lf in "${LEDGER_FILES[@]}"; do
    if [ -f "$REPO_ROOT/$lf" ]; then
        FOUND_LEDGERS+=("$lf")
    fi
done
echo "   Located ${#FOUND_LEDGERS[@]} ledger/changelog file(s) for SHA reference tracking."

# ------------------------------------------------------------------------------
# 2. Dry-Run Reporting
# ------------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 1 ]; then
    echo ""
    echo "============================================================"
    echo "  Dry-Run Summary (No Changes Made)"
    echo "============================================================"
    echo "  • Commits to convert       : $LEGACY_COUNT"
    echo "  • Conversion rule          :"
    echo "      Co-authored-by: Antigravity <antigravity@google.com>"
    echo "      ──> AI-Agent: Antigravity"
    echo "          AI-Vendor: Google"
    echo "  • Existing git notes refs  : $NOTES_COUNT"
    echo "  • Ledgers to repair        : ${#FOUND_LEDGERS[@]}"
    echo ""
    echo "  To execute live conversion after taking a full project backup:"
    echo "    ./scripts/scrub-attribution.sh --confirm"
    exit 0
fi

# ------------------------------------------------------------------------------
# 3. Live Execution (§D.2 - §D.5)
# ------------------------------------------------------------------------------
echo ""
echo "🚀 Step 2: Executing Live History Conversion..."

# 3a. Teardown Extra Worktrees to Prevent Index Lock Collisions
WORKTREES_TO_RESTORE=()
if git worktree list --porcelain 2>/dev/null | grep -q "worktree $REPO_ROOT/\.plans"; then
    echo "   Removing .plans worktree..."
    git worktree remove .plans --force 2>/dev/null || rm -rf .plans
    WORKTREES_TO_RESTORE+=("plans:.plans")
fi
if git worktree list --porcelain 2>/dev/null | grep -q "worktree $REPO_ROOT/\.agents"; then
    echo "   Removing .agents worktree..."
    git worktree remove .agents --force 2>/dev/null || rm -rf .agents
    WORKTREES_TO_RESTORE+=("agents:.agents")
fi
if git worktree list --porcelain 2>/dev/null | grep -q "worktree $REPO_ROOT/\.githooks"; then
    echo "   Removing .githooks worktree..."
    git worktree remove .githooks --force 2>/dev/null || rm -rf .githooks
    WORKTREES_TO_RESTORE+=("githooks:.githooks")
fi

# 3b. Run git filter-branch
echo "   Running git filter-branch across all branches..."
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --msg-filter '
sed -E "
s/^[[:space:]]*[Cc]o-[Aa]uthored-[Bb]y:[[:space:]]*Antigravity[[:space:]]*<antigravity@google\.com>/AI-Agent: Antigravity\nAI-Vendor: Google/g;
s/^[[:space:]]*[Cc]o-[Aa]uthored-[Bb]y:[[:space:]]*Claude[[:space:]]*<.*anthropic.*>/AI-Agent: Claude\nAI-Vendor: Anthropic/g;
"
' -- --all

# 3c. Parse SHA Mapping Table
MAP_DIR="$REPO_ROOT/.git-rewrite/map"
[ ! -d "$MAP_DIR" ] && MAP_DIR="$REPO_ROOT/.git/filter-branch/map"

declare -A SHA_MAP
if [ -d "$MAP_DIR" ]; then
    echo "   Parsing SHA conversion map..."
    for map_file in "$MAP_DIR"/*; do
        [ ! -f "$map_file" ] && continue
        old_sha="$(basename "$map_file")"
        new_sha="$(cat "$map_file")"
        if [ -n "$old_sha" ] && [ -n "$new_sha" ] && [ "$old_sha" != "$new_sha" ]; then
            SHA_MAP["$old_sha"]="$new_sha"
            # Also store 7-character prefix mapping
            SHA_MAP["${old_sha:0:7}"]="${new_sha:0:7}"
        fi
    done
fi
echo "   Mapped ${#SHA_MAP[@]} changed SHA reference(s)."

# 3d. Repair Ledgers on Affected Branches
if [ ${#SHA_MAP[@]} -gt 0 ]; then
    echo "   Repairing ledger references on branches containing archival ledgers..."
    for b in plans develop main; do
        if git show-ref --quiet "refs/heads/$b"; then
            git checkout "$b" --quiet
            REPAIRED=0
            for lf in "${FOUND_LEDGERS[@]}"; do
                if [ -f "$lf" ]; then
                    for old_s in "${!SHA_MAP[@]}"; do
                        new_s="${SHA_MAP[$old_s]}"
                        if grep -q "$old_s" "$lf" 2>/dev/null; then
                            sed -i "s/$old_s/$new_s/g" "$lf"
                            REPAIRED=1
                        fi
                    done
                fi
            done
            if [ "$REPAIRED" -eq 1 ]; then
                git add "${FOUND_LEDGERS[@]}" 2>/dev/null || true
                git commit -m "chore(audit): update historical commit SHAs following attribution scrub" --quiet || true
                echo "     • Repaired ledger SHAs on branch '$b'."
            fi
        fi
    done
    git checkout develop --quiet 2>/dev/null || git checkout main --quiet
fi

# 3e. Reconstruct Worktrees
echo "   Reconstructing worktrees..."
for entry in "${WORKTREES_TO_RESTORE[@]}"; do
    w_branch="${entry%%:*}"
    w_dir="${entry#*:}"
    if git show-ref --quiet "refs/heads/$w_branch"; then
        git worktree add "$w_dir" "$w_branch" --quiet 2>/dev/null || true
        echo "     • Re-mounted worktree '$w_dir' on branch '$w_branch'."
    fi
done

# 3f. Verification with Planning Health Pair 6
if [ -f "$REPO_ROOT/lib/planning_health.sh" ]; then
    echo "   Verifying recorded SHA integrity via Planning Health Pair 6..."
    source "$REPO_ROOT/lib/planning_health.sh"
    if check_recorded_sha_integrity "$REPO_ROOT" >/dev/null 2>&1; then
        echo "   ✅ 100% of recorded commit SHAs resolve in git object database."
    else
        echo "   ⚠️  Warning: One or more recorded SHAs could not be resolved. Review with 'aapp status'."
    fi
fi

echo ""
echo "============================================================"
echo "✅ Historical attribution scrub and SHA repair complete!"
echo "============================================================"
echo "Next actions:"
echo "  1. Review history: git log --all -n 10"
echo "  2. Verify planning health: ./aapp status"
echo "  3. When satisfied, push with lease: git push --force-with-lease --all origin"
echo ""
