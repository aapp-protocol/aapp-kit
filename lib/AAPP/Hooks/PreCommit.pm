package AAPP::Hooks::PreCommit;

use strict;
use warnings;
use utf8;
use 5.026;

use File::Basename ();
use File::Spec ();
use File::Temp ();
use Cwd ();

use AAPP::Constants qw(RETURN_OK RETURN_ERROR RETURN_FAIL RETURN_NOT_FOUND);
use AAPP::Paths ();
use AAPP::Config ();
use AAPP::Text ();
use AAPP::JSON ();
use AAPP::Logger ();
use AAPP::State ();
use AAPP::Health ();

our $ALWAYS_ALLOWED_REGEX = qr{^(?:README\.md|MANUAL\.md|CHEATSHEET\.md|COOKBOOK\.md|CODEMAP\.md|ARCHITECTURE\.md|CHANGELOG\.md|ISSUES\.md|\.plans/.*|\.agents/.*|\.offline/.*|docs/.*|\.gitignore|\.gitattributes|package\.json|package-lock\.json|composer\.json|composer\.lock|go\.mod|go\.sum|Cargo\.toml|Cargo\.lock|pyproject\.toml|requirements\.txt)$};
our $CORE_CODE_REGEX     = qr{\.(?:php|js|jsx|ts|tsx|py|go|rs|c|cpp|h|hpp|java|rb|css|scss|sql|html|sh|bash|zsh)$|^schema/.*\.json$|^aapp$};
my $_f_uri = "file:" . "///";
our $PORTABILITY_PATTERN  = qr{(\]\($_f_uri|<$_f_uri|$_f_uri(?:home|Users|root|tmp|var|etc|opt|usr|srv|[a-zA-Z]:)|\]\((?:/home/|/Users/|/root/|[a-zA-Z]:[/\\\\]))};

# Usage     : my $text = _read_text($filepath)
# Purpose   : Reads an entire file as UTF-8 encoded text.
# Returns   : String content on success, undef if file is missing or unreadable.
sub _read_text
{
    my ($file) = @_;
    return undef unless defined $file && -f $file;
    open my $fh, '<:encoding(UTF-8)', $file or return undef;
    my $content = do { local $/; <$fh> };
    close $fh;
    return $content;
}

# Usage     : my $section_text = _extract_plan_section($content, $section_num)
# Purpose   : Extracts the markdown content of a numbered plan section (e.g. 2, 4).
#             Properly handles code block fences so nested headings are preserved.
# Returns   : String containing the lines belonging to the section.
sub _extract_plan_section
{
    my ( $content, $sec ) = @_;
    my @lines  = split( /\r?\n/, $content );
    my $on     = 0;
    my $fenced = 0;
    my @res;
    foreach my $line (@lines) {
        if ( $line =~ /^\s*```/ ) {
            $fenced = !$fenced;
            if ($on) {
                push @res, $line;
            }
            next;
        }
        if ($fenced) {
            if ($on) {
                push @res, $line;
            }
            next;
        }
        if ( $line =~ /^## (?:[^0-9]*\s)?\Q$sec\E\./ ) {
            $on = 1;
            push @res, $line;
            next;
        }
        if ( $on && $line =~ /^## (?:[^0-9]*\s)?[0-9]+\./ ) {
            $on = 0;
        }
        if ($on) {
            push @res, $line;
        }
    }
    return join( "\n", @res );
}

# Usage     : my $res = _with_temp_plan($content, sub { my ($tmp_file) = @_; ... })
# Purpose   : Writes plan content into a temporary UTF-8 file and executes a callback with its path.
# Returns   : The return value of the executed callback.
sub _with_temp_plan
{
    my ( $content, $code ) = @_;
    my $tmp = File::Temp->new();
    binmode( $tmp, ':encoding(UTF-8)' );
    print $tmp $content;
    close($tmp);
    return $code->( $tmp->filename );
}

# Usage     : my $matched = _changelog_plan_matches($changelog_text, $plan_id)
# Purpose   : Scans ## [Unreleased] in CHANGELOG.md to verify whether the plan's entry exists.
# Returns   : 1 if the plan ID is referenced in an unreleased bullet, 0 otherwise.
sub _changelog_plan_matches
{
    my ( $content, $plan_id ) = @_;
    return 0 unless defined $content && defined $plan_id && $plan_id ne '';
    my $in_unreleased = 0;
    foreach my $line ( split( /\n/, $content ) ) {
        if ( $line =~ /^##\s+\[Unreleased\]/i ) {
            $in_unreleased = 1;
            next;
        }
        if ( $in_unreleased && $line =~ /^##\s+/ ) {
            last;
        }
        if ( $in_unreleased && $line =~ /^\s*[-*]\s+/ ) {
            my $bare_id = $plan_id =~ s/^P-//r;
            if ( index( $line, "`$plan_id`" ) >= 0 ||
                 index( $line, "($plan_id)" ) >= 0 ||
                 index( $line, "(`$plan_id`)" ) >= 0 ||
                 index( $line, "`P-$bare_id`" ) >= 0 ||
                 index( $line, "(`P-$bare_id`)" ) >= 0 ||
                 index( $line, "(P-$bare_id)" ) >= 0 ||
                 $line =~ /\b\Q$plan_id\E\b/ ||
                 $line =~ /\bP-\Q$bare_id\E\b/ ) {
                return 1;
            }
        }
    }
    return 0;
}

# Usage     : my $valid = _lock_only_added_targets($head_sec4, $index_sec4)
# Purpose   : Verifies that staged Section 4 edits only append target file lines without changing existing ones.
# Returns   : 1 if edits are append-only target file checkboxes, 0 otherwise.
sub _lock_only_added_targets
{
    my ( $head_sec4, $idx_sec4 ) = @_;
    my @h_lines = split /\r?\n/, $head_sec4;
    my @i_lines = split /\r?\n/, $idx_sec4;
    my $h_idx = 0;
    my @added;
    foreach my $line (@i_lines) {
        if ( $h_idx < scalar(@h_lines) && $line eq $h_lines[$h_idx] ) {
            $h_idx++;
        } else {
            push @added, $line;
        }
    }
    return 0 unless $h_idx == scalar(@h_lines) && @added;
    foreach my $l (@added) {
        return 0 unless $l =~ /^\s*-\s*\[[ xX]\]\s*`([^`]+)`/;
    }
    return 1;
}

# Usage     : my ($fences, $outside) = _lock_group_fences($group_plan_text)
# Purpose   : Parses Architecture & Codemap four-backtick code fences and non-fenced content.
# Returns   : List of (hash ref of heading => body, string of content outside code fences).
sub _lock_group_fences
{
    my ($text) = @_;
    my %fences;
    my $outside = '';
    my $in_sec  = 0;
    my $infence = 0;
    my $cur_heading = '';
    my @cur_body;

    foreach my $line ( split( /\n/, $text ) ) {
        if ( $line =~ /^##\s+Architecture\s+&\s+Codemap/ ) {
            $in_sec = 1;
            next;
        }
        if ( $in_sec && $line =~ /^##\s+/ && !$infence ) {
            $in_sec = 0;
        }
        next unless $in_sec;
        next if $line =~ /^<!--\s*aapp-base:/ && !$infence;

        if ( $line =~ /^````/ ) {
            if ($infence) {
                $fences{$cur_heading} = join( "\n", @cur_body );
                $infence = 0;
                $cur_heading = '';
                @cur_body = ();
            } else {
                $infence = 1;
            }
            next;
        }

        if ($infence) {
            if ( $cur_heading eq '' && $line =~ /\S/ ) {
                $cur_heading = $line;
            }
            push @cur_body, $line;
        } else {
            $outside .= "\n$line" if $line =~ /\S/;
        }
    }
    return ( \%fences, $outside );
}

# Usage     : my $rc = AAPP::Hooks::PreCommit->run()
# Purpose   : Authoritative pre-commit hook enforcing blast radius, circuit breakers, and commit rules.
# Returns   : 0 on success; non-zero exit code on refusal or failure.
sub run
{
    my ($class) = @_;
    binmode( STDOUT, ':utf8' );
    binmode( STDERR, ':utf8' );

    # 0. Pre-Flight: Runtime Reachability
    my $aapp_bin = '';
    my $home = $ENV{HOME} // '';
    if ( $home ne '' && -x "$home/.local/bin/aapp" ) {
        $aapp_bin = "$home/.local/bin/aapp";
    } else {
        foreach my $p ( split( /:/, $ENV{PATH} // '' ) ) {
            if ( -x "$p/aapp" && !-d "$p/aapp" ) {
                $aapp_bin = "$p/aapp";
                last;
            }
        }
    }

    if ( $aapp_bin eq '' ) {
        print STDERR "❌ [AAPP Guard] 'aapp' command not found in PATH or ~/.local/bin.\n\n";
        print STDERR "   This repository is governed by the Asymmetric Agent Planning Protocol.\n";
        print STDERR "   Without the 'aapp' toolchain installed, this clone is in INSPECTION-ONLY mode.\n";
        print STDERR "   Commits are locked to prevent un-guarded code and plan desynchronization.\n\n";
        print STDERR "   To enable development and commits, install AAPP globally:\n";
        print STDERR "     git clone https://github.com/aapp-protocol/aapp-kit.git && ./aapp-kit/aapp install\n\n";
        return 1;
    }

    if ( ( $ENV{SKIP_BLAST_RADIUS} // '0' ) eq '1' ) {
        print STDOUT "⚡ [Pre-Commit Notice] Blast Radius and CHANGELOG verification skipped via SKIP_BLAST_RADIUS=1.\n";
        return 0;
    }

    # Resolve checkout root from path cache, querying git rev-parse only when unset
    my $repo_root = AAPP::Paths::resolve()->{root};
    if ( !defined $repo_root || !-d $repo_root ) {
        my ( $ok, $out ) = AAPP::Paths::git_capture('rev-parse', '--show-toplevel');
        $repo_root = $out =~ s/\s+\z//r if $ok;
    }
    return 0 unless defined $repo_root && -d $repo_root;
    my $current_wt_name = File::Basename::basename($repo_root);

    # Collect staged files via git diff-index (safe array exec, null-delimited)
    my ( $diff_ok, $diff_null ) = AAPP::Paths::git_capture('diff', '--cached', '--name-only', '-z', '--diff-filter=ACMRD');
    $diff_null //= '';
    my @staged_files = grep { defined $_ && $_ ne '' } split( /\0/, $diff_null );
    return 0 unless @staged_files;

    # Query current branch via git rev-parse
    my ( $br_ok, $br_out ) = AAPP::Paths::git_capture('rev-parse', '--abbrev-ref', 'HEAD');
    my $cur_branch = ( $br_ok && defined $br_out ) ? ( $br_out =~ s/\s+\z//r ) : '';

    # P-75: offline worktree protection
    if ( $cur_branch ne 'offline' ) {
        foreach my $f (@staged_files) {
            if ( $f =~ m{^\.offline/} ) {
                print STDOUT "\n❌ [Pre-Commit] '$f' is staged from the offline worktree.\n";
                print STDOUT "   Files under .offline/ are never committed here: publish them with 'aapp offline sync'.\n";
                print STDOUT "   Unstage it with: git restore --staged -- '$f'\n\n";
                return 1;
            }
        }
    }

    # Adaptive branch protection
    if ( ( $ENV{ALLOW_MAIN_COMMIT} // '0' ) ne '1' ) {
        my $protect_stable = AAPP::Config::get('aapp.protectStable') // 'true';
        if ( $protect_stable ne 'false' && $cur_branch ne '' ) {
            my %protected = map { $_ => 1 } split( /\s+/, AAPP::Config::get('aapp.protectedBranches') // 'main master production' );
            if ( $protected{$cur_branch} ) {
                my @dev_candidates = split( /\s+/, AAPP::Config::get('aapp.devBranch') // 'develop dev development' );
                my $dev_found = '';
                foreach my $db (@dev_candidates) {
                    # Verify branch ref existence via git show-ref
                    my ( $r1 ) = AAPP::Paths::git_capture('show-ref', '--verify', '--quiet', "refs/heads/$db");
                    my ( $r2 ) = $r1 ? 0 : ( AAPP::Paths::git_capture('show-ref', '--verify', '--quiet', "refs/remotes/origin/$db") )[0];
                    my ( $r3 ) = ( $r1 || $r2 ) ? 0 : ( AAPP::Paths::git_capture('show-ref', '--quiet', '--', "refs/remotes/*/$db") )[0];
                    if ( $r1 || $r2 || $r3 ) {
                        $dev_found = $db;
                        last;
                    }
                }
                if ( $dev_found ne '' ) {
                    print STDOUT "\n❌ [AAPP Branch Protection] Direct commits to '$cur_branch' are prohibited!\n";
                    print STDOUT "   A development branch ('$dev_found') exists for active engineering.\n\n";
                    print STDOUT "   👉 Switch to your development branch before committing:\n";
                    print STDOUT "      git checkout $dev_found\n\n";
                    print STDOUT "   💡 If this is an intentional release or hotfix commit on '$cur_branch':\n";
                    print STDOUT "      ALLOW_MAIN_COMMIT=1 git commit -m \"...\"\n";
                    print STDOUT "   💡 To permanently allow commits on '$cur_branch':\n";
                    print STDOUT "      git config aapp.protectStable false\n\n";
                    return 1;
                }
            }
        }
    }

    # 0a. Integration lock check (prevent raw commits to parent being integrated)
    if ( defined $cur_branch && $cur_branch ne '' ) {
        my $target_lock_name = "integrate/$cur_branch";
        if ( AAPP::Paths::lock_held($target_lock_name) ) {
            my $lock_dir = AAPP::Paths::lock_path($target_lock_name);
            my $holder_pid = '';
            if ( defined $lock_dir && open( my $fh, '<', "$lock_dir/pid" ) ) {
                $holder_pid = <$fh> // '';
                chomp($holder_pid);
                close($fh);
            }
            my $by_pid = $holder_pid ne '' ? " by PID $holder_pid" : '';
            print STDERR "\n❌ [AAPP Guard] Branch '$cur_branch' is currently locked for integration$by_pid.\n";
            print STDERR "   Raw commits to a landing parent branch are prohibited during active integration.\n\n";
            return 1;
        }
    }

    # Integration lock check (general)
    if ( AAPP::Paths::lock_held('integration') ) {
        print STDOUT "\n❌ [Pre-Commit Concurrency Lock] Project integration lock is engaged!\n";
        print STDOUT "   Another autonomous worker or terminal is currently integrating or merging.\n\n";
        print STDOUT "   👉 Wait for the other process to finish, or inspect stale locks in .git/aapp_*.lock.\n\n";
        return 1;
    }

    # Project pause circuit breaker
    my $paused_file = ( AAPP::Paths::resolve()->{common_dir} // "$repo_root/.git" ) . "/aapp_paused";
    my $shared_paused = -d "$repo_root/.plans" ? "$repo_root/.plans/PAUSED.md" : "";
    if ( -f $paused_file || ( $shared_paused ne "" && -f $shared_paused ) ) {
        my $disallowed_in_pause = 0;
        foreach my $f (@staged_files) {
            next if $f =~ m{^\.plans/(?:pickup\.md|pickup/.*|ISSUES\.md|issues/.*|current/.*)};
            next if $f =~ m{^(?:CHANGELOG\.md|CODEMAP\.md|ARCHITECTURE\.md)$};
            $disallowed_in_pause = 1;
            last;
        }
        if ($disallowed_in_pause) {
            print STDOUT "\n❌ [Project Circuit Breaker] Commits are refused while the project is PAUSED.\n";
            print STDOUT "   All production code modifications are quarantined.\n\n";
            print STDOUT "   👉 To inspect pause state: aapp pause status\n";
            print STDOUT "   👉 To resume work:        aapp pause resume\n\n";
            return 1;
        }
    }

    # Resolve active plans and blast radius context
    my $plans_root = AAPP::State::plans_root();
    my $plans_dir  = defined $plans_root && -d $plans_root ? $plans_root : ( -d "$repo_root/.plans" ? "$repo_root/.plans" : '' );

    # Fail-closed quarantine in AAPP repositories
    if ( $plans_dir eq '' || !-d "$plans_dir/current" ) {
        my $has_kit = -f "$repo_root/.githooks/blast-radius-guard" || -f "$repo_root/aapp" || -f "$repo_root/.agents/AGENTS.md";
        if ($has_kit) {
            print STDOUT "\n❌ [Pre-Commit Quarantine] AAPP repository detected, but .plans/current is missing or unmounted.\n";
            print STDOUT "   Commits are blocked until planning structure is restored. Run 'aapp init'.\n\n";
            return 1;
        }
    }

    # Check if any non-bypassed files are staged
    my $non_bypass_count = 0;
    foreach my $staged (@staged_files) {
        next if $staged =~ $ALWAYS_ALLOWED_REGEX;
        next if $staged =~ m{^\.(?:plans|agents|offline)/};
        next if $current_wt_name eq '.plans' || $current_wt_name eq '.agents';
        $non_bypass_count++;
    }

    # Active plan buffer pointer resolution via git rev-parse
    my ( $buf_ok, $buf_out ) = AAPP::Paths::git_capture('rev-parse', '--git-path', 'aapp_active_plan');
    my $active_buf = ( $buf_ok && defined $buf_out && $buf_out ne '' ) ? ( $buf_out =~ s/\s+\z//r ) : '.git/aapp_active_plan';
    $active_buf = "$repo_root/$active_buf" unless $active_buf =~ m{^/};

    my $designated_id = '';
    if ( -f $active_buf ) {
        $designated_id = do { open( my $f, '<', $active_buf ); my $l = <$f>; close($f); defined $l ? ( $l =~ s/^\s+|\s+$//gr ) : '' };
    }

    my $active_plan_path = '';
    my $active_id        = '';

    if ( $designated_id ne '' && $plans_dir ne '' ) {
        opendir( my $dh, "$plans_dir/current" );
        my @pfs = sort grep { /\.md$/ && !/^000-/ } readdir($dh);
        closedir($dh);

        foreach my $pf (@pfs) {
            my $full = "$plans_dir/current/$pf";
            my $b    = File::Basename::basename( $full, '.md' );
            my $pid  = AAPP::State::plan_id($full) // '';
            if ( $pid eq $designated_id || $b eq $designated_id || $b =~ /^\Q$designated_id\E-/ ||
                 $b =~ /^P\Q$designated_id\E-/ || $b =~ /^P-\Q$designated_id\E-/ ) {
                $active_plan_path = $full;
                $active_id        = $pid ne '' ? $pid : $designated_id;
                last;
            }
        }
        if ( $active_plan_path eq '' ) {
            print STDOUT "\n❌ [Pre-Commit Error] Designated active plan '$designated_id' not found in $plans_dir/current/.\n";
            print STDOUT "   Run 'aapp plan-clear' to clear pointer, or 'aapp plan <id>' to switch context.\n\n";
            return 1;
        }
    } elsif ( $plans_dir ne '' ) {
        # Query plans held across other worktrees (fail closed on failure, no eval swallow)
        my @held = AAPP::State::held_plans();
        opendir( my $dh, "$plans_dir/current" );
        my @pfs = sort grep { /\.md$/ && !/^(?:000-|fix-)/ } readdir($dh);
        closedir($dh);

        my @dev_plans;
        foreach my $pf (@pfs) {
            my $full    = "$plans_dir/current/$pf";
            my $st      = AAPP::Config::plan_status_slug($full);
            my $st_line = AAPP::Config::plan_status_line($full);
            my $b       = File::Basename::basename( $full, '.md' );

            if ( ( defined $st && $st eq 'in-development' ) || !defined $st_line ) {
                my $holder = AAPP::State::plan_held_by( $full, @held );
                if ( defined $holder && $holder ne '' ) {
                    my @ht = AAPP::State::plan_target_paths($full);
                    if (@ht) {
                        foreach my $staged (@staged_files) {
                            next if AAPP::State::is_shared_doc($staged);
                            if ( AAPP::Paths::match_pattern_list( $staged, @ht ) ) {
                                print STDOUT "\n❌ [Pre-Commit Blast Radius Violation] Staged file '$staged' belongs to $b (in $holder).\n";
                                print STDOUT "   Commit it from that worktree, or make the fix inside that plan.\n\n";
                                return 1;
                            }
                        }
                    }
                    next;
                }
                push @dev_plans, $full;
            }
        }

        if ( scalar(@dev_plans) == 1 ) {
            $active_plan_path = $dev_plans[0];
            $active_id        = AAPP::State::plan_id($active_plan_path) // File::Basename::basename( $active_plan_path, '.md' );
        } elsif ( scalar(@dev_plans) > 1 ) {
            if ( $non_bypass_count > 0 ) {
                my $list = join( ',', map { File::Basename::basename( $_, '.md' ) } @dev_plans );
                print STDOUT "\n❌ [Pre-Commit Blast Radius Violation] Multiple plans are currently in development [$list]!\n";
                print STDOUT "   Run 'aapp plan <id>' to designate the active commit context.\n\n";
                return 1;
            }
        }
    }

    # CHANGELOG enforcement
    my $staged_core_count = 0;
    foreach my $f (@staged_files) {
        if ( $f =~ $CORE_CODE_REGEX ) {
            $staged_core_count++;
        }
    }

    if ( $staged_core_count > 0 ) {
        my $changelog_updated = 0;
        foreach my $f (@staged_files) {
            if ( $f eq 'CHANGELOG.md' || $f eq '.plans/CHANGELOG.md' ) {
                $changelog_updated = 1;
                last;
            }
        }

        if ( !$changelog_updated && -d '.plans' ) {
            # Query uncommitted status of CHANGELOG in .plans worktree
            my ( $pst_ok, $p_status ) = AAPP::Paths::git_capture('-C', '.plans', 'status', '--porcelain');
            $p_status //= '';
            if ( $pst_ok && $p_status =~ /CHANGELOG\.md/ ) {
                $changelog_updated = 1;
            } else {
                # Query last commit in .plans worktree to see if it touched CHANGELOG
                my ( $plog_ok, $p_log ) = AAPP::Paths::git_capture('-C', '.plans', 'log', '-1', '--name-only', '--format=');
                if ( $plog_ok && defined $p_log && $p_log =~ /^CHANGELOG\.md$/m ) {
                    $changelog_updated = 1;
                }
            }
        }

        if ( !$changelog_updated ) {
            my $cl_mode = AAPP::Config::get('aapp.changelogMode') // 'plan';
            if ( $cl_mode eq 'plan' ) {
                # Read staged CHANGELOG.md; fallback to .plans/CHANGELOG.md when not present
                my ( $cl_ok, $staged_cl ) = AAPP::Paths::git_capture('show', ':CHANGELOG.md');
                if ( !$cl_ok || !defined $staged_cl || $staged_cl eq '' ) {
                    ( $cl_ok, $staged_cl ) = AAPP::Paths::git_capture('show', ':.plans/CHANGELOG.md');
                }
                $staged_cl //= '';
                if ( $active_id ne '' && _changelog_plan_matches( $staged_cl, $active_id ) ) {
                    $changelog_updated = 1;
                }
                if ( !$changelog_updated && defined $ENV{AAPP_AMENDMENT_OWNER} && $ENV{AAPP_AMENDMENT_OWNER} ne '' ) {
                    if ( _changelog_plan_matches( $staged_cl, $ENV{AAPP_AMENDMENT_OWNER} ) ) {
                        $changelog_updated = 1;
                    }
                }
            }
        }

        if ( !$changelog_updated ) {
            print STDOUT "\n❌ [Pre-Commit Error] Core code files were modified, but CHANGELOG.md was not updated!\n";
            if ( $active_id ne '' ) {
                print STDOUT "   👉 Plan $active_id has no entry under ## [Unreleased] yet. Commit with 'aapp commit',\n";
                print STDOUT "      which writes the plan's declared **Changelog:** entry, or declare it with 'aapp refine'.\n";
            } else {
                print STDOUT "   👉 Please document your changes in CHANGELOG.md (or .plans/CHANGELOG.md) and stage it:\n";
                print STDOUT "      git add CHANGELOG.md\n";
            }
            print STDOUT "\n";
            return 1;
        }
    }

    # CHANGELOG conciseness and single-line bullet invariant
    my ( undef, $max_cl_len ) = AAPP::Config::get_int( 'aapp.changelogMaxLen', 300 );
    $max_cl_len //= 300;
    foreach my $cl_name ( 'CHANGELOG.md', '.plans/CHANGELOG.md' ) {
        # Query cached diff for changelog entry
        my ( $cd_ok, $cl_diff ) = AAPP::Paths::git_capture('diff', '--cached', '-U0', '--', $cl_name);
        $cl_diff //= '';
        if ( $cl_diff eq '' && $cl_name eq '.plans/CHANGELOG.md' && -d '.plans' ) {
            # Query diff in .plans worktree checkout
            my ( $pd_ok, $p_diff ) = AAPP::Paths::git_capture('-C', '.plans', 'diff', '--cached', '-U0', '--', 'CHANGELOG.md');
            if ( !$pd_ok || !defined $p_diff || $p_diff eq '' ) {
                ( $pd_ok, $p_diff ) = AAPP::Paths::git_capture('-C', '.plans', 'diff', '-U0', '--', 'CHANGELOG.md');
            }
            $cl_diff = $p_diff if $pd_ok && defined $p_diff && $p_diff ne '';
        }
        next if $cl_diff eq '';

        foreach my $raw_line ( split( /\n/, $cl_diff ) ) {
            next unless $raw_line =~ /^\+[^+]/;
            my $line = substr( $raw_line, 1 );
            next if $line !~ /\S/;
            next if $line =~ /^(?:#|<!--|---|___|\*\*\*|\[.*?\]:|All notable changes|.*Keep a Changelog|.*Semantic Versioning)/;

            # Rule 1: Shape Invariant
            if ( $line !~ /^\s*[-*]\s+/ ) {
                print STDOUT "\n❌ [Pre-Commit Error] Changelog entry has unbulleted continuation line!\n";
                print STDOUT "   File: $cl_name\n";
                print STDOUT "   Line: $line\n\n";
                print STDOUT "   👉 Changelog entries must be concise, single-line bullets starting with '- '.\n";
                print STDOUT "   👉 Multi-line paragraphs or unbulleted continuation lines are prohibited.\n\n";
                return 1;
            }

            # Rule 2: Bullet Length Ceiling
            my $line_len = AAPP::Text::char_len($line);
            if ( $line_len > $max_cl_len ) {
                print STDOUT "\n❌ [Pre-Commit Error] Changelog bullet exceeds maximum length ($line_len > $max_cl_len chars)!\n";
                print STDOUT "   File: $cl_name\n";
                print STDOUT "   Line: $line\n\n";
                print STDOUT "   👉 Keep a Changelog requires concise, single-line bullet points (<= $max_cl_len chars).\n";
                print STDOUT "   👉 Move technical blueprints, file lists, and internal implementation mechanics to .plans/ blueprints.\n\n";
                return 1;
            }
        }
    }

    # Portability check
    foreach my $f (@staged_files) {
        next unless -f $f;
        next if $f =~ m{(?:tests/|test/|spec/|.*/tests/|.*pre[-_]?commit.*|\.githooks/)}i;
        next if $f =~ m{(?:_test\.|\.test\.|test_)};

        # Query staged file content safely via git show without shell interpolation
        my ( $show_ok, $content ) = AAPP::Paths::git_capture('show', ":$f");
        next unless $show_ok && defined $content && $content ne '';
        my @match_lines;
        my $ln = 0;
        foreach my $line ( split /\r?\n/, $content ) {
            $ln++;
            if ( $line =~ $PORTABILITY_PATTERN ) {
                push @match_lines, "$ln:$line";
            }
        }
        if (@match_lines) {
            print STDOUT "\n❌ [Pre-Commit Portability Violation] Machine-specific URI or absolute path in '$f'!\n";
            print STDOUT "   Violations found:\n";
            foreach my $m (@match_lines) {
                print STDOUT "     $m\n";
            }
            print STDOUT "\n   👉 Use repository-relative paths or markdown backticks for repo portability.\n\n";
            return 1;
        }
    }

    # Blast radius validation
    if ( $plans_dir ne '' && -d "$plans_dir/current" ) {
        opendir( my $dh, "$plans_dir/current" );
        my @all_pfs = sort grep { /\.md$/ } readdir($dh);
        closedir($dh);

        # Check mini plan exemption
        my @mini_targets;
        if ( $designated_id ne '' ) {
            my $mini_id = $designated_id;
            if ( $mini_id =~ /^#([0-9]+)$/ && -f "$plans_dir/current/fix-$1.md" ) {
                @mini_targets = AAPP::State::plan_target_paths("$plans_dir/current/fix-$1.md");
            }
        }

        foreach my $pf (@all_pfs) {
            my $full = "$plans_dir/current/$pf";
            if ( AAPP::Config::plan_status_is( $full, 'blocked' ) ) {
                my @bt = AAPP::State::plan_target_paths($full);
                if (@bt) {
                    foreach my $staged (@staged_files) {
                        next if $staged =~ $ALWAYS_ALLOWED_REGEX;
                        next if $staged =~ m{^\.(?:plans|agents|offline)/};
                        next if $current_wt_name eq '.plans' || $current_wt_name eq '.agents';
                        if ( @mini_targets && AAPP::Paths::match_pattern_list( $staged, @mini_targets ) ) {
                            next;
                        }
                        if ( AAPP::Paths::match_pattern_list( $staged, @bt ) ) {
                            print STDOUT "\n❌ [Pre-Commit Blast Radius Violation] Plan '$pf' is BLOCKED! Staged file '$staged' belongs to a blocked plan.\n";
                            print STDOUT "   All commits against a BLOCKED plan are refused.\n\n";
                            AAPP::Logger::log_event( 'guard', 'check', { decision => 'deny', path => $staged, reason => 'blocked' } );
                            return 1;
                        }
                    }
                }
            }
        }

        # Enforce blast radius for active plan
        if ( $active_plan_path ne '' ) {
            my $active_bname = File::Basename::basename($active_plan_path);
            if ( AAPP::Config::plan_status_is( $active_plan_path, 'blocked' ) ) {
                print STDOUT "\n❌ [Pre-Commit Blast Radius Violation] Active plan '$active_bname' is BLOCKED!\n";
                print STDOUT "   All commits are refused while a plan is marked 🟥 BLOCKED.\n\n";
                AAPP::Logger::log_event( 'guard', 'check', { decision => 'deny', path => '', active_plan => $active_id, reason => 'blocked' } );
                return 1;
            }

            # TDD checks
            if ( AAPP::State::plan_has_required_test_files($active_plan_path) ) {
                my $plan_st = AAPP::Config::plan_status_slug($active_plan_path) // '';
                if ( $plan_st eq 'frozen' || $plan_st eq 'in-development' ) {
                    my $rc = AAPP::State::plan_tdd_correspondence( $active_plan_path, 'Pre-Commit TDD' );
                    if ( $rc != RETURN_OK ) {
                        AAPP::Logger::log_event( 'guard', 'check', { decision => 'deny', path => '', active_plan => $active_id, reason => 'tdd_correspondence' } );
                        return 1;
                    }
                    if ( $plan_st eq 'in-development' && $current_wt_name ne '.plans' && $current_wt_name ne '.agents' ) {
                        my $paths = AAPP::Paths::resolve();
                        my $primary_root = $paths ? ( $paths->{primary_root} // '' ) : '';
                        my @req_test_files = AAPP::State::plan_required_test_files($active_plan_path);
                        foreach my $tf (@req_test_files) {
                            if ( !-f "$repo_root/$tf" && ( $primary_root eq '' || !-f "$primary_root/$tf" ) && !-f $tf ) {
                                print STDOUT "\n❌ [Pre-Commit TDD Violation] Required test file '$tf' is missing from disk!\n";
                                print STDOUT "   Active plan : $active_bname\n";
                                print STDOUT "   Status      : ⚡ In Development\n\n";
                                AAPP::Logger::log_event( 'guard', 'check', { decision => 'deny', path => $tf, active_plan => $active_id, reason => 'missing_test_file' } );
                                return 1;
                            }
                        }
                    }
                }
            }

            my @targets = AAPP::State::plan_target_paths($active_plan_path);
            my @oob     = AAPP::State::plan_oob_paths($active_plan_path);

            # Approved amendments (P-129)
            my $group = AAPP::State::plan_field( $active_plan_path, 'Group' );
            my $norm_active = $active_id =~ s/^[pP]-?//r;
            my $is_grp = eval { AAPP::State::plan_is_group($active_plan_path) } // 0;
            if ( ( defined $group && $group ne '' ) || $is_grp ) {
                my $target_group = ( defined $group && $group ne '' ) ? $group : $active_id;
                my $norm_group   = $target_group =~ s/^[pP]-?//r;
                if ( opendir( my $dh_amend, "$plans_dir/current" ) ) {
                    my @cand = sort grep { /\.md$/ && !/^000-/ } readdir($dh_amend);
                    closedir($dh_amend);
                    foreach my $cand_file (@cand) {
                        my $af = "$plans_dir/current/$cand_file";
                        my $af_kind = AAPP::State::plan_field( $af, 'Kind' ) // '';
                        next unless $af_kind eq 'amendments' || $cand_file =~ /-amendments\.md$/;
                        my $af_group = AAPP::State::plan_field( $af, 'Group' ) // '';
                        my $norm_afg = $af_group =~ s/^[pP]-?//r;
                        if ( $af_group eq $target_group || ( $norm_afg ne '' && $norm_afg eq $norm_group ) ) {
                            if ( open( my $afh, '<:encoding(UTF-8)', $af ) ) {
                                while ( my $l = <$afh> ) {
                                    if ( $l =~ /^\s*-\s*\*\*R[0-9]+\*\*\s+[^·]+·\s*([^·]+)·\s*`([^`]+)`\s*·.*?—\s*approved/i ) {
                                        my ( $req, $p ) = ( $1, $2 );
                                        $req =~ s/^\s+|\s+$//g;
                                        my $norm_req = $req =~ s/^[pP]-?//r;
                                        if ( $req eq $active_id || $norm_req eq $norm_active ) {
                                            push @targets, $p;
                                        }
                                    }
                                }
                                close($afh);
                            }
                        }
                    }
                }
            }

            # Boundary checks on staged files
            foreach my $staged (@staged_files) {
                next if $staged =~ $ALWAYS_ALLOWED_REGEX;
                next if $staged =~ m{^\.(?:plans|agents|offline)/};
                next if $current_wt_name eq '.plans' || $current_wt_name eq '.agents';

                # Mini plan exemption
                if ( @mini_targets && AAPP::Paths::match_pattern_list( $staged, @mini_targets ) ) {
                    next;
                }

                # 1. Out of Bounds veto
                if ( @oob && AAPP::Paths::match_pattern_list( $staged, @oob ) ) {
                    print STDOUT "\n❌ [Pre-Commit Blast Radius Violation] File '$staged' is explicitly OUT OF BOUNDS in active plan '$active_bname'.\n";
                    print STDOUT "   All modifications to this path are strictly prohibited by protocol.\n\n";
                    AAPP::Logger::log_event( 'guard', 'check', { decision => 'deny', path => $staged, active_plan => $active_id, reason => 'out_of_bounds' } );
                    return 1;
                }

                # 2. Target Files allow
                if ( @targets && AAPP::Paths::match_pattern_list( $staged, @targets ) ) {
                    AAPP::Logger::log_event( 'guard', 'check', { decision => 'allow', path => $staged, active_plan => $active_id, reason => 'target' } );
                    next;
                }

                # 3. Out-of-bounds only plan
                if ( !@targets && @oob ) {
                    AAPP::Logger::log_event( 'guard', 'check', { decision => 'allow', path => $staged, active_plan => $active_id, reason => 'oob_only' } );
                    next;
                }

                # Undeclared code modification
                print STDOUT "\n❌ [Pre-Commit Blast Radius Violation] File '$staged' is outside declared Target Files of active plan '$active_bname'.\n";
                print STDOUT "   Modify Section 4 (Blast Radius) of the active blueprint before touching this file.\n\n";
                AAPP::Logger::log_event( 'guard', 'check', { decision => 'deny', path => $staged, active_plan => $active_id, reason => 'undeclared_target' } );
                return 1;
            }
        }
    }

    # Frozen plan design lock & group plan Architecture & Codemap check
    foreach my $staged (@staged_files) {
        next unless $staged =~ m{^\.plans/current/([^/]+)\.md$};
        my $stem = $1;
        next if $stem =~ /^(?:000-|fix-)/;

        # Query HEAD content of staged plan file safely via git show
        my ( $h_ok, $head_content ) = AAPP::Paths::git_capture('show', "HEAD:$staged");
        next unless $h_ok && defined $head_content && $head_content ne '';
        utf8::decode($head_content);

        my $head_line = AAPP::Config::status_line_of_lines( split( /\n/, $head_content ) );
        my $head_st   = defined $head_line ? ( AAPP::Config::plan_state_for_status_line($head_line) // '' ) : '';
        next unless $head_st eq 'frozen' || $head_st eq 'in-development';

        # Query staged index content of plan file safely via git show
        my ( $i_ok, $idx_content ) = AAPP::Paths::git_capture('show', ":$staged");
        next unless $i_ok && defined $idx_content && $idx_content ne '';
        utf8::decode($idx_content);

        my $head_sec2 = _extract_plan_section( $head_content, 2 );
        my $idx_sec2  = _extract_plan_section( $idx_content,  2 );
        my $head_sec4 = _extract_plan_section( $head_content, 4 );
        my $idx_sec4  = _extract_plan_section( $idx_content,  4 );

        my $design_violation = '';
        if ( $head_sec2 ne $idx_sec2 ) {
            $design_violation = 'Section 2 (Technical Blueprint)';
        }
        if ( $head_sec4 ne $idx_sec4 ) {
            $design_violation = $design_violation ne '' ? "$design_violation and Section 4 (Blast Radius & System Boundaries)" : 'Section 4 (Blast Radius & System Boundaries)';
        }

        # Amendment lines and added targets exemptions
        if ( $head_sec4 ne $idx_sec4 && $head_sec2 eq $idx_sec2 ) {
            if ( $idx_content =~ /^\*\s+\*\*Kind:\*\*\s+amendments\b/m && _lock_only_added_targets( $head_sec4, $idx_sec4 ) ) {
                $design_violation = '';
            }
        }

        # Group plan Architecture & Codemap check
        if ( $head_content =~ /^#\s+.*?Group\s+Plan/m ) {
            my ( $h_fences, $h_out ) = _lock_group_fences($head_content);
            my ( $i_fences, $i_out ) = _lock_group_fences($idx_content);
            if ( $h_out ne $i_out ) {
                $design_violation = ( $design_violation ne '' ? "$design_violation and " : '' ) . "the group's ## Architecture & Codemap (text outside its sections)";
            } else {
                my %all_keys = map { $_ => 1 } ( keys %$h_fences, keys %$i_fences );
                my @changed_sec;
                foreach my $k ( keys %all_keys ) {
                    if ( ( $h_fences->{$k} // '' ) ne ( $i_fences->{$k} // '' ) ) {
                        push @changed_sec, $k;
                    }
                }
                if (@changed_sec) {
                    # Check if Decisions lines exist in staged amendments member
                    my $gid = _with_temp_plan( $head_content, sub { AAPP::State::plan_id($_[0]) // '' } );
                    my $approved_decisions = '';
                    foreach my $other (@staged_files) {
                        next if $other eq $staged;
                        # Query staged index content of other candidate member
                        my ( $other_i_ok, $ic ) = AAPP::Paths::git_capture('show', ":$other");
                        next unless $other_i_ok && defined $ic && $ic =~ /^\*\s+\*\*Kind:\*\*\s+amendments\b/m;
                        my $og = _with_temp_plan( $ic, sub { AAPP::State::plan_field( $_[0], 'Group' ) // '' } );
                        next unless $og eq $gid;
                        # Query HEAD content of other candidate member
                        my ( $other_h_ok, $head_other ) = AAPP::Paths::git_capture('show', "HEAD:$other");
                        $head_other //= '';
                        my %h_lines    = map { $_ => 1 } split( /\r?\n/, $head_other );
                        my @added      = grep { !$h_lines{$_} } split( /\r?\n/, $ic );
                        $approved_decisions .= join( "\n", @added ) . "\n";
                    }
                    my @missing;
                    foreach my $cs (@changed_sec) {
                        my $clean_cs = $cs =~ s/^#+\s*//r;
                        if ( index( $approved_decisions, $clean_cs ) < 0 ) {
                            push @missing, $clean_cs;
                        }
                    }
                    if (@missing) {
                        $design_violation = ( $design_violation ne '' ? "$design_violation and " : '' ) . "the group's ## Architecture & Codemap (no Decisions line in its amendments member for: " . join( ', ', @missing ) . ")";
                    }
                }
            }
        }

        if ( $design_violation ne '' ) {
            print STDOUT "\n❌ [Pre-Commit Design Lock Violation] Cannot edit locked design sections of a frozen plan!\n";
            print STDOUT "   Staged plan : $staged\n";
            print STDOUT "   Violation   : Attempted modifications to $design_violation\n";
            print STDOUT "   Status      : 🔷 Frozen (Design Locked)\n\n";
            print STDOUT "   👉 To resolve this:\n";
            print STDOUT "      1. Revert changes to Section 2 and Section 4.\n";
            print STDOUT "      2. Or unfreeze the plan by changing status back to '📝 Refining' before amending the design.\n\n";
            AAPP::Logger::log_event( 'health', 'veto', { pair => 'pair1', file => $staged, reason => 'frozen_design_lock' } );
            return 1;
        }
    }

    # Group member ARCHITECTURE.md rule
    if ( $active_plan_path ne '' ) {
        my $member_group = AAPP::State::plan_field( $active_plan_path, 'Group' );
        if ( defined $member_group && $member_group ne '' ) {
            foreach my $f (@staged_files) {
                if ( $f eq 'ARCHITECTURE.md' ) {
                    my $b = File::Basename::basename( $active_plan_path, '.md' );
                    print STDOUT "\n❌ [Pre-Commit Group Rule] $b is a member of group $member_group.\n";
                    print STDOUT "   ARCHITECTURE.md changes go into ${member_group}'s '## Architecture & Codemap' section; its 'done' applies them.\n\n";
                    return 1;
                }
            }
        }
    }

    # Documentation reminder
    my $docs_updated = 0;
    foreach my $f (@staged_files) {
        if ( $f =~ m{^(?:README\.md|MANUAL\.md|COOKBOOK\.md|docs/.*|CODEMAP\.md|ARCHITECTURE\.md|\.agents/CODEMAP\.md|\.agents/ARCHITECTURE\.md)$} ) {
            $docs_updated = 1;
            last;
        }
    }
    if ( !$docs_updated && -d '.agents' ) {
        # Query .agents worktree status via safe git_capture
        my ( $ag_ok, $ag_status ) = AAPP::Paths::git_capture('-C', '.agents', 'status', '--porcelain');
        $ag_status //= '';
        if ( $ag_ok && $ag_status =~ /(?:CODEMAP|ARCHITECTURE)\.md/ ) {
            $docs_updated = 1;
        }
    }
    my $docs_gov = AAPP::Config::get('aapp.docs') // 'true';
    if ( $docs_gov ne 'false' ) {
        my $member_group = $active_plan_path ne '' ? AAPP::State::plan_field( $active_plan_path, 'Group' ) : undef;
        if ( $staged_core_count > 0 && defined $member_group && $member_group ne '' ) {
            print STDOUT "ℹ️  [Pre-Commit Reminder] ARCHITECTURE.md and CODEMAP.md changes for this work go into ${member_group}'s '## Architecture & Codemap' section.\n";
        } elsif ( $staged_core_count > 0 && !$docs_updated ) {
            print STDOUT "⚠️  [Pre-Commit Reminder] Documentation (README.md, ARCHITECTURE.md, or .agents/CODEMAP.md) was not updated.\n";
            print STDOUT "   If this commit introduces new interfaces, routes, or behaviors, ensure documentation stays in sync.\n";
        }
    }

    # Issue roadmap & ledger hygiene
    my $roadmap_file = AAPP::State::ledger_path( 'roadmap', $repo_root );
    my $ROADMAP_RESOLVED_RE = qr{^[ \t]*(?:[0-9]+\.|-[ \t]*\[[ xX]?\]|\*)[ \t]*`?(?:(?:#|ISSUE-)?[0-9]+|#(?:[0-9]+|[A-Z][A-Z0-9]*-[0-9]+))`?.*(?:✅|[Rr]esolved)}m;
    if ( defined $roadmap_file && -f $roadmap_file ) {
        my $content = _read_text($roadmap_file) // '';
        if ( $content =~ $ROADMAP_RESOLVED_RE ) {
            my @lines = grep { $_ !~ $ROADMAP_RESOLVED_RE } split( /\r?\n/, $content );
            open my $fh, '>:encoding(UTF-8)', $roadmap_file;
            print $fh join( "\n", @lines ), "\n";
            close $fh;
            # Re-stage pruned roadmap file safely
            AAPP::Paths::git_capture('add', '--', $roadmap_file);
            print STDOUT "🧹 [Pre-Commit Notice] Auto-pruned resolved issues from " . File::Basename::basename($roadmap_file) . "\n";
        }
    }

    my $issues_file = AAPP::State::ledger_path( 'issues', $repo_root );
    my $ISSUES_RESOLVED_ROW_RE = qr{^[ \t]*\|[ \t]*`?(?:(?:#|ISSUE-)?[0-9]+|#(?:[0-9]+|[A-Z][A-Z0-9]*-[0-9]+))`?.*(?:✅|[Rr]esolved)}m;
    if ( defined $issues_file && -f $issues_file ) {
        my $active_issues_text = _read_text($issues_file) // '';
        if ( $active_issues_text =~ $ISSUES_RESOLVED_ROW_RE ) {
            print STDOUT "\n❌ [Pre-Commit Violation] Found resolved issue in active " . File::Basename::basename($issues_file) . ".\n";
            print STDOUT "   The Relocation Invariant requires resolved rows to be moved to .plans/done/000-issues-archive.md.\n";
            print STDOUT "   Resolution is a physical row relocation, never an in-place status badge.\n\n";
            AAPP::Logger::log_event( 'health', 'veto', { pair => 'pair8', file => $issues_file, reason => 'resolved_row_in_active_ledger' } );
            return 1;
        }
    }

    # Atomic commit mode check
    if ( ( $ENV{AAPP_COMMIT_HELPER} // '0' ) ne '1' && $active_plan_path ne '' ) {
        my $active_st = AAPP::Config::plan_status_slug($active_plan_path) // '';
        if ( $active_st eq 'in-development' ) {
            my $commit_mode = AAPP::Config::get('aapp.commitMode') // 'atomic';
            if ( $commit_mode eq 'atomic' ) {
                my @commits = AAPP::State::plan_commits($active_plan_path);
                if (@commits) {
                    my $first_sha = $commits[0];
                    my $touches_code = 0;
                    foreach my $s (@staged_files) {
                        next if $s =~ $ALWAYS_ALLOWED_REGEX;
                        next if $s =~ m{^\.(?:plans|agents)/};
                        next if $current_wt_name eq '.plans' || $current_wt_name eq '.agents';
                        $touches_code = 1;
                        last;
                    }
                    if ($touches_code) {
                        print STDOUT "\n❌ [Pre-Commit Commit Mode] aapp.commitMode=atomic: $active_id already has commit $first_sha.\n";
                        print STDOUT "   Fold changes in with 'aapp commit amend', or set aapp.commitMode=microcommits.\n\n";
                        return 1;
                    }
                }
            }
            print STDOUT "💡 $active_id is active: record this commit with 'aapp commit adopt <sha>' (or commit through 'aapp commit').\n";
        }
    }

    # Syntax checks
    foreach my $f (@staged_files) {
        next unless -f $f;

        if ( $f =~ /\.(?:sh|bash)$/ ) {
            my $rc = system( 'bash', '-n', $f );
            if ( $rc != 0 ) {
                print STDERR "❌ [Pre-Commit Error] Bash Syntax Error in staged file: $f\n";
                system( 'bash', '-n', $f );
                return 1;
            }
        }

        if ( $f =~ /\.py$/ ) {
            my $rc = system( 'python3', '-c', 'import sys; compile(open(sys.argv[1], "rb").read(), sys.argv[1], "exec")', $f );
            if ( $rc != 0 ) {
                print STDERR "❌ [Pre-Commit Error] Python Syntax Error in staged file: $f\n";
                system( 'python3', '-c', 'import sys; compile(open(sys.argv[1], "rb").read(), sys.argv[1], "exec")', $f );
                return 1;
            }
        }

        if ( $f =~ /\.php$/ ) {
            my $rc = system( 'php', '-l', $f );
            if ( $rc != 0 ) {
                print STDERR "❌ [Pre-Commit Error] PHP Syntax Error in staged file: $f\n";
                system( 'php', '-l', $f );
                return 1;
            }
        }

        if ( $f =~ m{^schema/.*\.json$} ) {
            my $rc = system( 'python3', '-c', 'import json, sys; json.load(open(sys.argv[1], encoding="utf-8"))', $f );
            if ( $rc != 0 ) {
                print STDERR "❌ [Pre-Commit Error] Invalid JSON syntax in schema file: $f\n";
                return 1;
            }
        }
    }

    print STDOUT "✅ [Git Pre-Commit] Pre-commit checks passed successfully!\n";
    return 0;
}

1;
