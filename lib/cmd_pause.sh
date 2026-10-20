#!/usr/bin/env bash
# ==============================================================================
# AAPP Command: `pause`, `resume`
#
# Master Emergency Brake & Multi-Worktree State Preserver ("Hibernate & Wake")
# ==============================================================================
set -e

# REPO_ROOT is exported by the `aapp` dispatcher (P-33).
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

PAUSED_FILE="$GIT_COMMON_DIR/aapp_paused"
SHARED_PAUSED_FILE="$PLANS_DIR/PAUSED.md"

AAPP_HOOK_DISPATCHER="$(dirname "${BASH_SOURCE[0]}")/hook_dispatcher.sh"
[ -f "$AAPP_HOOK_DISPATCHER" ] || AAPP_HOOK_DISPATCHER="$REPO_ROOT/lib/hook_dispatcher.sh"

# ------------------------------------------------------------------------------
# Helpers: Worktree Discovery & In-Flight Operations Check
# ------------------------------------------------------------------------------
discover_worktrees() {
    local list=()
    while IFS= read -r line; do
        [ -n "$line" ] && [ -d "$line" ] && list+=("$line")
    done < <(git worktree list --porcelain 2>/dev/null | sed -nE 's/^worktree[[:space:]]+(.*)/\1/p')

    if [ ${#list[@]} -eq 0 ]; then
        echo "$REPO_ROOT"
    else
        printf '%s\n' "${list[@]}" | sort -u
    fi
}

check_in_flight_operations() {
    local wt="$1"
    local merge_file rebase_dir rebase_apply cherry_file revert_file

    merge_file=$(git -C "$wt" rev-parse --git-path MERGE_HEAD 2>/dev/null || true)
    rebase_dir=$(git -C "$wt" rev-parse --git-path rebase-merge 2>/dev/null || true)
    rebase_apply=$(git -C "$wt" rev-parse --git-path rebase-apply 2>/dev/null || true)
    cherry_file=$(git -C "$wt" rev-parse --git-path CHERRY_PICK_HEAD 2>/dev/null || true)
    revert_file=$(git -C "$wt" rev-parse --git-path REVERT_HEAD 2>/dev/null || true)

    if [ -n "$merge_file" ] && [ -f "$merge_file" ]; then
        echo "merge in progress"
        return 1
    fi
    if [ -n "$rebase_dir" ] && [ -d "$rebase_dir" ]; then
        echo "rebase in progress"
        return 1
    fi
    if [ -n "$rebase_apply" ] && [ -d "$rebase_apply" ]; then
        echo "rebase-apply in progress"
        return 1
    fi
    if [ -n "$cherry_file" ] && [ -f "$cherry_file" ]; then
        echo "cherry-pick in progress"
        return 1
    fi
    if [ -n "$revert_file" ] && [ -f "$revert_file" ]; then
        echo "revert in progress"
        return 1
    fi

    return 0
}

is_project_paused() {
    if [ -f "$PAUSED_FILE" ]; then
        return 0
    fi
    if [ -n "$PLANS_DIR" ] && [ -f "$SHARED_PAUSED_FILE" ]; then
        return 0
    fi
    return 1
}

# ------------------------------------------------------------------------------
# Inspector & State Output
# ------------------------------------------------------------------------------
show_pause_inspection() {
    echo "🛑 Project Status: PAUSED"
    echo "--------------------------------------------------"

    local reason="unspecified"
    local timestamp=""
    local user_name=""
    local stashes_count=0

    if [ -f "$PAUSED_FILE" ]; then
        perl -CSA -Mutf8 -I"$AAPP_LIB" -MAAPP::JSON -e '
my ( $rc, $d, $why ) = AAPP::JSON::decode_file( $ARGV[0] );
if ( $rc != 1 || ref($d) ne "HASH" ) {
    print "   (Failed to parse snapshot: ", $why // "not a JSON object", ")\n";
    exit 0;
}
my $snap = ref( $d->{snapshot} ) eq "HASH" ? $d->{snapshot} : {};
my @stashes = ref( $snap->{stashes} ) eq "ARRAY" ? @{ $snap->{stashes} } : ();
print "   Reason  : ", $d->{reason} // "unspecified", "\n";
print "   Paused  : ", $d->{timestamp} // "unknown", " by ", $d->{user} // "unknown", "\n";
print "   Stashes : ", scalar(@stashes), " worktree(s) quarantined\n";
foreach my $s (@stashes) {
    printf "     • %s: %s (%s)\n", $s->{worktree} // "", $s->{tag} // "", substr( $s->{sha} // "", 0, 8 );
}
my $wts = ref( $snap->{worktrees} ) eq "HASH" ? $snap->{worktrees} : {};
my @names = AAPP::JSON::key_order($wts);
if (@names) {
    print "   Worktrees Monitored:\n";
    foreach my $name (@names) {
        my $w = $wts->{$name};
        my @details;
        push @details, scalar( @{ $w->{staged_files} } ) . " staged" if ref( $w->{staged_files} ) eq "ARRAY" && @{ $w->{staged_files} };
        push @details, scalar( @{ $w->{unstaged_files} } ) . " unstaged" if ref( $w->{unstaged_files} ) eq "ARRAY" && @{ $w->{unstaged_files} };
        my $summary = @details ? " (" . join( ", ", @details ) . ")" : "";
        printf "     • %s @ %s%s\n", $name, substr( $w->{head_sha} // "", 0, 8 ), $summary;
    }
}
' "$PAUSED_FILE"
    elif [ -f "$SHARED_PAUSED_FILE" ]; then
        echo "   Scope   : Team-Wide (Shared in .plans/PAUSED.md)"
        sed 's/^/   /' "$SHARED_PAUSED_FILE"
    fi

    echo ""
    echo "To resume project velocity: aapp resume"
}

# ------------------------------------------------------------------------------
# Command: `pause`
# ------------------------------------------------------------------------------
cmd_pause() {
    local shared=0
    local reason_parts=()

    while [ $# -gt 0 ]; do
        case "$1" in
            shared)
                shared=1
                shift
                ;;
            help|-h|--help)
                cat <<EOF
Usage: aapp pause [shared] [reason]

Engage the Project Emergency Brake & Multi-Worktree State Preserver.
Quarantines uncommitted code per-worktree into SHA-addressed stashes
and locks all codebase modifications.

Arguments:
  shared      Commit pause marker to .plans/PAUSED.md for remote team freeze
  [reason]    Explanation for pausing operations

Examples:
  aapp pause "switching to project-2"
  aapp pause shared "DB schema migration in progress"
EOF
                return 0
                ;;
            *)
                reason_parts+=("$1")
                shift
                ;;
        esac
    done

    local reason="${reason_parts[*]:-developer paused project}"

    # Idempotent inspector check
    if is_project_paused; then
        echo "ℹ️  Project is ALREADY PAUSED."
        show_pause_inspection
        return 0
    fi

    local worktrees=()
    while IFS= read -r wt; do
        [ -n "$wt" ] && worktrees+=("$wt")
    done < <(discover_worktrees)

    # 1. In-flight operation guard across all worktrees
    for wt in "${worktrees[@]}"; do
        local op_status
        if ! op_status=$(check_in_flight_operations "$wt"); then
            echo "❌ [Pause Refusal] Cannot pause while a $op_status in worktree '$wt'." >&2
            echo "   Please complete or abort the operation before pausing." >&2
            exit 1
        fi
    done

    # 2. Per-worktree Stash Quarantine & Forensics
    local created_stashes=() # tuples: wt|branch|sha|tag
    local stashes_json=()
    local worktrees_json=()
    local now_iso
    now_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")
    local ts_clean
    ts_clean=$(date +"%Y%m%d-%H%M%S")
    local current_user
    current_user="$(git config user.name 2>/dev/null || whoami 2>/dev/null || echo "developer")"

    rollback_stashes() {
        echo "⚠️  [Pause Rollback] Rolling back captured stashes due to failure..." >&2
        for item in "${created_stashes[@]}"; do
            local swt sbranch ssha stag
            swt="$(echo "$item" | cut -d'|' -f1)"
            sbranch="$(echo "$item" | cut -d'|' -f2)"
            ssha="$(echo "$item" | cut -d'|' -f3)"
            stag="$(echo "$item" | cut -d'|' -f4)"
            
            echo "   Rolling back stash $ssha in '$swt'..." >&2
            git -C "$swt" stash apply "$ssha" >/dev/null 2>&1 || true
            local sidx
            sidx=$(git -C "$swt" stash list --format='%gd %H' 2>/dev/null | grep -F "$ssha" | head -n 1 | cut -d' ' -f1 || true)
            [ -n "$sidx" ] && git -C "$swt" stash drop "$sidx" >/dev/null 2>&1 || true
        done
        rm -f "$PAUSED_FILE"
    }

    for wt in "${worktrees[@]}"; do
        local wt_name
        wt_name="$(basename "$wt")"
        [ "$wt" = "$REPO_ROOT" ] && wt_name="develop"
        [ "$wt" = "$PRIMARY_ROOT" ] && wt_name="develop"

        local head_sha branch
        head_sha="$(git -C "$wt" rev-parse HEAD 2>/dev/null || echo "0000000000000000000000000000000000000000")"
        branch="$(git -C "$wt" branch --show-current 2>/dev/null || echo "detached")"
        [ -z "$branch" ] && branch="detached"

        local staged_files unstaged_files
        staged_files=$(git -C "$wt" diff --name-only --cached 2>/dev/null | tr '\n' ',' | sed 's/,$//')
        unstaged_files=$(git -C "$wt" diff --name-only 2>/dev/null | tr '\n' ',' | sed 's/,$//')

        local dirty_output
        dirty_output=$(git -C "$wt" status --porcelain 2>/dev/null || true)

        if [ -n "$dirty_output" ]; then
            local stash_tag="aapp-pause-${ts_clean}:${branch}"
            if ! git -C "$wt" stash push --include-untracked -m "$stash_tag" >/dev/null 2>&1; then
                echo "❌ [Pause Refusal] Failed to execute stash in worktree '$wt'." >&2
                rollback_stashes
                exit 1
            fi

            local stash_sha
            stash_sha=$(git -C "$wt" stash list --format='%H %gs' 2>/dev/null | grep -F "$stash_tag" | head -n 1 | cut -d' ' -f1 || true)

            if ! [[ "$stash_sha" =~ ^[0-9a-f]{40}$ ]]; then
                echo "❌ [Pause Refusal] Failed to capture valid 40-character stash SHA for '$wt'." >&2
                rollback_stashes
                exit 1
            fi

            created_stashes+=("${wt}|${branch}|${stash_sha}|${stash_tag}")
        fi
    done

    # 3. Assemble Snapshot JSON
    perl -CSA -Mutf8 -I"$AAPP_LIB" -MAAPP::JSON -e '
my ( $file, $reason, $timestamp, $user, $shared, $stashes_raw, $worktrees_raw ) = @ARGV;
my @stashes;
foreach my $item ( grep { /\S/ } split( /\n/, $stashes_raw ) ) {
    my @p = split( /\|/, $item, -1 );
    next if @p < 4;
    push @stashes, AAPP::JSON::json_obj( worktree => AAPP::JSON::json_str( $p[0] ), branch => AAPP::JSON::json_str( $p[1] ),
        sha => AAPP::JSON::json_str( $p[2] ), tag => AAPP::JSON::json_str( $p[3] ) );
}
my @worktrees;
foreach my $item ( grep { /\S/ } split( /\n/, $worktrees_raw ) ) {
    my @p = split( /\|/, $item, -1 );
    next if @p < 5;
    push @worktrees, $p[0], AAPP::JSON::json_obj( path => AAPP::JSON::json_str( $p[1] ), head_sha => AAPP::JSON::json_str( $p[2] ),
        staged_files => AAPP::JSON::json_strlist( split( /,/, $p[3] ) ), unstaged_files => AAPP::JSON::json_strlist( split( /,/, $p[4] ) ) );
}
my $doc = AAPP::JSON::json_obj(
    paused    => "true",
    timestamp => AAPP::JSON::json_str($timestamp),
    reason    => AAPP::JSON::json_str($reason),
    user      => AAPP::JSON::json_str($user),
    shared    => AAPP::JSON::json_bool( $shared eq "1" ),
    snapshot  => AAPP::JSON::json_obj( worktrees => AAPP::JSON::json_obj(@worktrees), stashes => AAPP::JSON::json_list(@stashes) ),
);
my $fh;
if ( !open( $fh, ">:encoding(UTF-8)", $file ) ) {
    print STDERR "❌ [Pause] Cannot write $file: $!\n";
    exit 1;
}
print {$fh} AAPP::JSON::pretty($doc);
if ( !close($fh) ) {
    print STDERR "❌ [Pause] Cannot write $file: $!\n";
    exit 1;
}
' "$PAUSED_FILE" "$reason" "$now_iso" "$current_user" "$shared" \
  "$(printf '%s\n' "${created_stashes[@]}")" \
  "$(
      for wt in "${worktrees[@]}"; do
          wname="$(basename "$wt")"
          [ "$wt" = "$REPO_ROOT" ] || [ "$wt" = "$PRIMARY_ROOT" ] && wname="develop"
          hsha="$(git -C "$wt" rev-parse HEAD 2>/dev/null || echo "")"
          stg="$(git -C "$wt" diff --name-only --cached 2>/dev/null | tr '\n' ',' | sed 's/,$//')"
          unstg="$(git -C "$wt" diff --name-only 2>/dev/null | tr '\n' ',' | sed 's/,$//')"
          printf '%s|%s|%s|%s|%s\n' "$wname" "$wt" "$hsha" "$stg" "$unstg"
      done
  )"

    # 4. Handle Shared Mode (--shared)
    if [ "$shared" -eq 1 ] && [ -n "$PLANS_DIR" ] && [ -d "$PLANS_DIR" ]; then
        cat <<EOF > "$SHARED_PAUSED_FILE"
# 🛑 PROJECT PAUSED (Circuit Breaker Active)
* **Status:** PAUSED
* **Timestamp:** $now_iso
* **Initiator:** $current_user
* **Reason:** $reason

All codebase modifications and commits are frozen across all worktrees.
To resume normal operations, run:
\`\`\`bash
aapp resume
\`\`\`
EOF
        if [ -d "$PLANS_DIR/.git" ] || git -C "$PLANS_DIR" rev-parse --git-dir >/dev/null 2>&1; then
            git -C "$PLANS_DIR" add PAUSED.md 2>/dev/null || true
            git -C "$PLANS_DIR" commit -m "chore(pause): project paused - $reason" 2>/dev/null || true
        fi
    fi

    echo "🛑 [Project Circuit Breaker] Project is now PAUSED."
    echo "   Reason  : $reason"
    echo "   Scope   : $( [ "$shared" -eq 1 ] && echo "Team-Wide (shared via .plans/PAUSED.md)" || echo "Repo-Wide ($PAUSED_FILE)" )"
    echo "   Stashes : ${#created_stashes[@]} worktree(s) quarantined into SHA-addressed stashes"
    for item in "${created_stashes[@]}"; do
        local swt sbranch ssha stag
        swt="$(echo "$item" | cut -d'|' -f1)"
        ssha="$(echo "$item" | cut -d'|' -f3)"
        stag="$(echo "$item" | cut -d'|' -f4)"
        echo "     • $(basename "$swt"): $stag (${ssha:0:8})"
    done
    echo "   All codebase modifications and commits are strictly refused."
    echo "   To resume: aapp resume"

    # Dispatch post-pause observer lifecycle event
    if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
        # shellcheck source=/dev/null
        source "$AAPP_HOOK_DISPATCHER"
        dispatch_hook "post-pause" "{\"command\": \"pause\", \"event\": \"pause\", \"reason\": \"$reason\", \"shared\": $( [ "$shared" -eq 1 ] && echo "true" || echo "false" )}" || true
    fi
}

# ------------------------------------------------------------------------------
# Command: `resume`
# ------------------------------------------------------------------------------
cmd_resume() {
    if ! is_project_paused; then
        echo "ℹ️  Project is already active (not paused)."
        return 0
    fi

    echo "🔄 [Project Circuit Breaker] Initiating resumption sequence..."

    local stashes_to_restore=()
    local worktrees_snapshot=()
    local reason=""

    if [ -f "$PAUSED_FILE" ]; then
        local parse_output
        parse_output=$(perl -CSA -Mutf8 -I"$AAPP_LIB" -MAAPP::JSON -e '
my ( $rc, $d, $why ) = AAPP::JSON::decode_file( $ARGV[0] );
if ( $rc != 1 || ref($d) ne "HASH" ) {
    print STDERR "❌ [Resume] Cannot read the pause snapshot $ARGV[0]: ", $why // "not a JSON object", ". Nothing was restored; fix or remove the file, then run aapp resume again.\n";
    exit 1;
}
my $snap = ref( $d->{snapshot} ) eq "HASH" ? $d->{snapshot} : {};
print "REASON=", $d->{reason} // "", "\n";
foreach my $s ( ref( $snap->{stashes} ) eq "ARRAY" ? @{ $snap->{stashes} } : () ) {
    print "STASH=", join( "|", map { $s->{$_} // "" } qw(worktree branch sha tag) ), "\n";
}
my $wts = ref( $snap->{worktrees} ) eq "HASH" ? $snap->{worktrees} : {};
foreach my $name ( AAPP::JSON::key_order($wts) ) {
    my $w   = $wts->{$name};
    my $stg = ref( $w->{staged_files} ) eq "ARRAY" ? join( ",", @{ $w->{staged_files} } ) : "";
    my $uns = ref( $w->{unstaged_files} ) eq "ARRAY" ? join( ",", @{ $w->{unstaged_files} } ) : "";
    print "WORKTREE=", join( "|", $name, $w->{path} // "", $w->{head_sha} // "", $stg, $uns ), "\n";
}
' "$PAUSED_FILE") || exit 1

        while IFS= read -r line; do
            case "$line" in
                REASON=*)
                    reason="${line#REASON=}"
                    ;;
                STASH=*)
                    stashes_to_restore+=("${line#STASH=}")
                    ;;
                WORKTREE=*)
                    worktrees_snapshot+=("${line#WORKTREE=}")
                    ;;
            esac
        done <<< "$parse_output"
    fi

    # 1. Forensic Drift Detection
    local drift_found=0
    for wt_info in "${worktrees_snapshot[@]}"; do
        local wname wpath expected_sha
        wname="$(echo "$wt_info" | cut -d'|' -f1)"
        wpath="$(echo "$wt_info" | cut -d'|' -f2)"
        expected_sha="$(echo "$wt_info" | cut -d'|' -f3)"

        if [ -d "$wpath" ]; then
            local current_sha
            current_sha="$(git -C "$wpath" rev-parse HEAD 2>/dev/null || echo "")"
            if [ -n "$expected_sha" ] && [ -n "$current_sha" ] && [ "$expected_sha" != "$current_sha" ]; then
                echo "⚠️  [Forensic Drift Notice] Worktree '$wname' moved while project was paused:"
                echo "     Expected : ${expected_sha:0:8}"
                echo "     Current  : ${current_sha:0:8}"
                drift_found=1
            fi
        fi
    done

    # 2. SHA-Addressed Stash Restoration (Pause Buffer Survival Invariant)
    local restored_count=0
    for s_info in "${stashes_to_restore[@]}"; do
        local swt sbranch ssha stag
        swt="$(echo "$s_info" | cut -d'|' -f1)"
        sbranch="$(echo "$s_info" | cut -d'|' -f2)"
        ssha="$(echo "$s_info" | cut -d'|' -f3)"
        stag="$(echo "$s_info" | cut -d'|' -f4)"

        if [ -d "$swt" ]; then
            echo "   Restoring quarantined stash for $(basename "$swt") (${ssha:0:8})..."
            if ! git -C "$swt" stash apply "$ssha" >/dev/null 2>&1; then
                echo "" >&2
                echo "❌ [Resume Refusal] Merge conflict encountered while restoring stash for worktree '$swt'!" >&2
                echo "   Stash commit : $ssha ($stag)" >&2
                echo "   The stash entry has been PRESERVED in git stash list (No-Loss Guarantee)." >&2
                echo "   The project REMAINS PAUSED to protect repository integrity." >&2
                echo "   Please resolve conflicts manually in '$swt', then re-run 'aapp resume'." >&2
                exit 1
            fi

            # Successful apply -> drop stash entry
            local sidx
            sidx=$(git -C "$swt" stash list --format='%gd %H' 2>/dev/null | grep -F "$ssha" | head -n 1 | cut -d' ' -f1 || true)
            if [ -n "$sidx" ]; then
                git -C "$swt" stash drop "$sidx" >/dev/null 2>&1 || true
            fi
            restored_count=$((restored_count + 1))
        fi
    done

    # Output forensic notes about files that were staged prior to pause
    for wt_info in "${worktrees_snapshot[@]}"; do
        local wname stg
        wname="$(echo "$wt_info" | cut -d'|' -f1)"
        stg="$(echo "$wt_info" | cut -d'|' -f4)"
        if [ -n "$stg" ]; then
            echo "   ℹ️  Note: The following files were staged in '$wname' prior to pause:"
            echo "$stg" | tr ',' '\n' | sed 's/^/     • /'
            echo "     (Restored as unstaged for review)"
        fi
    done

    # 3. Sanity Health Verification
    local health_script=""
    if [ -f "$PRIMARY_ROOT/lib/planning_health.sh" ]; then
        health_script="$PRIMARY_ROOT/lib/planning_health.sh"
    elif [ -f "$REPO_ROOT/lib/planning_health.sh" ]; then
        health_script="$REPO_ROOT/lib/planning_health.sh"
    fi

    if [ -n "$health_script" ]; then
        echo "   Verifying planning health integrity..."
        if ! bash "$health_script" >/dev/null 2>&1; then
            echo "⚠️  [Resume Warning] Planning health check reported integrity warnings."
        fi
    fi

    # 4. Deactivate Pause Buffer
    rm -f "$PAUSED_FILE"
    if [ -n "$PLANS_DIR" ] && [ -f "$SHARED_PAUSED_FILE" ]; then
        rm -f "$SHARED_PAUSED_FILE"
        if [ -d "$PLANS_DIR/.git" ] || git -C "$PLANS_DIR" rev-parse --git-dir >/dev/null 2>&1; then
            git -C "$PLANS_DIR" add -u PAUSED.md 2>/dev/null || true
            git -C "$PLANS_DIR" commit -m "chore(resume): project resumed" 2>/dev/null || true
        fi
    fi

    echo ""
    echo "✨ [Project Resumed] Emergency brake disengaged. Full velocity restored."
    [ "$restored_count" -gt 0 ] && echo "   Restored : $restored_count worktree stash(es)"
    [ "$drift_found" -eq 0 ] && echo "   Drift    : 0 foreign changes detected while paused"
    echo "   Status   : Active"

    # Dispatch post-resume observer lifecycle event
    if [ -f "$AAPP_HOOK_DISPATCHER" ]; then
        # shellcheck source=/dev/null
        source "$AAPP_HOOK_DISPATCHER"
        dispatch_hook "post-resume" "{\"command\": \"pause\", \"event\": \"resume\", \"restored_count\": $restored_count, \"drift_found\": $drift_found}" || true
    fi
}

# ------------------------------------------------------------------------------
# Dispatcher
# ------------------------------------------------------------------------------
ACTION="${1:-pause}"
shift || true

case "$ACTION" in
    pause)
        cmd_pause "$@"
        ;;
    resume|unpause)
        cmd_resume "$@"
        ;;
    inspect|status)
        if is_project_paused; then
            show_pause_inspection
        else
            echo "ℹ️  Project is active (not paused)."
        fi
        ;;
    *)
        echo "❌ Unknown action '$ACTION' for cmd_pause." >&2
        echo "   Available: pause, resume, inspect" >&2
        exit 1
        ;;
esac
