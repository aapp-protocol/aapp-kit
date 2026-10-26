package AAPP::Hooks::PostRewrite;

use strict;
use warnings;
use utf8;
use 5.026;

use File::Basename ();
use File::Spec ();

use AAPP::Constants qw(RETURN_OK RETURN_ERROR RETURN_FAIL);
use AAPP::Paths ();
use AAPP::Config ();
use AAPP::Logger ();
use AAPP::State ();
use AAPP::CommitEngine ();

# Usage     : my $rc = AAPP::Hooks::PostRewrite->run($mode)
# Purpose   : Master entrypoint for post-rewrite hook; remaps active plan commit SHAs after rebase/amend.
# Returns   : 0 on success, non-zero on failure.
sub run
{
    my ( $class_or_mode, $maybe_mode ) = @_;
    my $mode = defined $maybe_mode ? $maybe_mode : ( $class_or_mode // 'rebase' );
    $mode = 'rebase' if $mode eq __PACKAGE__ || $mode eq '';

    return 0 if defined $ENV{AAPP_COMMIT_HELPER} && $ENV{AAPP_COMMIT_HELPER} eq '1';

    # Slurp rewrite mapping from STDIN (old-sha new-sha extra...)
    my @map_lines = <STDIN>;
    return 0 unless @map_lines;

    my %sha_map;
    foreach my $l (@map_lines) {
        $l =~ s/^\s+|\s+$//g;
        next if $l eq '';
        my ( $old, $new ) = split( /\s+/, $l );
        if ( defined $old && defined $new ) {
            $sha_map{$old} = $new;
        }
    }
    return 0 unless %sha_map;

    my $buf_path = AAPP::Paths::resolve()->{git_dir};
    return 0 unless defined $buf_path && -d $buf_path;
    my $active_buf = "$buf_path/aapp_active_plan";
    return 0 unless -f $active_buf;

    my $bound = do {
        open( my $bfh, '<:encoding(UTF-8)', $active_buf );
        my $val = <$bfh>;
        close($bfh);
        $val // '';
    };
    $bound =~ s/^\s+|\s+$//g;
    return 0 if $bound eq '';

    my $plans_dir = AAPP::State::plans_root();
    return 0 unless defined $plans_dir && -d "$plans_dir/current";

    my $plan_file = '';
    if ( $bound =~ /^#([0-9]+)$/ ) {
        my $num = $1;
        $plan_file = "$plans_dir/current/fix-$num.md" if -f "$plans_dir/current/fix-$num.md";
    } else {
        opendir( my $dh, "$plans_dir/current" ) or return 0;
        my @files = sort readdir($dh);
        closedir($dh);

        foreach my $f (@files) {
            next unless $f =~ /\.md$/;
            next if $f =~ /^(?:000-|fix-)/;
            my $pf = "$plans_dir/current/$f";
            my $b = File::Basename::basename( $pf, '.md' );
            my $pid = AAPP::State::plan_id($pf) // '';

            if ( $pid eq $bound || "P-$bound" eq $pid || $b eq $bound ||
                 $b =~ /^\Q$bound\E-/ || ( $bound =~ /^P?-?([0-9]+)$/ && $b =~ /^P$1-/ ) ) {
                $plan_file = $pf;
                last;
            }
        }
    }
    return 0 if $plan_file eq '' || !-f $plan_file;

    my ( $b_ok, $cur_branch_raw ) = AAPP::Paths::git_capture( 'rev-parse', '--abbrev-ref', 'HEAD' );
    my $cur_branch = ( $b_ok && defined $cur_branch_raw ) ? ( $cur_branch_raw =~ s/\s+\z//r ) : '';

    # Parse current commits line
    my $content = do {
        open( my $pfh, '<:encoding(UTF-8)', $plan_file );
        local $/;
        my $c = <$pfh>;
        close($pfh);
        $c // '';
    };

    my $commits_line = '';
    if ( $content =~ /^\s*[*|-]*\s*\*\*Commits:\*\*\s*(.*)/m ) {
        $commits_line = $1 =~ s/^\s+|\s+$//gr;
    }
    return 0 if $commits_line eq '' || $commits_line eq 'none';

    my @tokens;
    my %seen;
    my $changed = 0;

    foreach my $item ( split( /,/, $commits_line ) ) {
        $item =~ s/^\s+|\s+$//g;
        next if $item eq '';

        my ( $sha, $branch ) = ( '', '' );
        if ( $item =~ /^`([0-9a-fA-F]+)`(?:\s*\(([^)]+)\))?/ ) {
            $sha    = $1;
            $branch = $2 // '';
        } else {
            next;
        }

        # Check if mapped
        my $new_sha = '';
        foreach my $old ( keys %sha_map ) {
            if ( index( $old, $sha ) == 0 || index( $sha, $old ) == 0 ) {
                $new_sha = $sha_map{$old};
                last;
            }
        }

        my $s = $sha;
        if ( $new_sha ne '' ) {
            my ( $s_ok, $short_raw ) = AAPP::Paths::git_capture( 'rev-parse', '--short', $new_sha );
            my $short = ( $s_ok && defined $short_raw ) ? ( $short_raw =~ s/\s+\z//r ) : '';
            $s       = $short ne '' ? $short : $new_sha;
            $changed = 1;
        } else {
            if ( $branch ne '' && $branch eq $cur_branch ) {
                # External git merge-base query to verify ancestry in post-rewrite history
                my $rc = system( 'git', 'merge-base', '--is-ancestor', $sha, 'HEAD' );
                if ( $rc != 0 ) {
                    print STDERR "ℹ️  [AAPP Post-Rewrite] $sha left ${bound}'s Commits: the $mode dropped it (already upstream).\n";
                    $changed = 1;
                    next;
                }
            }
        }

        if ( $seen{$s} ) {
            $changed = 1;
            next;
        }
        $seen{$s} = 1;
        if ( $branch ne '' ) {
            push @tokens, "`$s` ($branch)";
        } else {
            push @tokens, "`$s`";
        }
    }

    return 0 unless $changed;

    my $val = @tokens ? join( ', ', @tokens ) : 'none';
    my $new_content = $content;
    if ( $new_content =~ s/^\s*[*|-]*\s*\*\*Commits:\*\*.*$/\* \*\*Commits:\*\* $val/m ) {
        open( my $wfh, '>:encoding(UTF-8)', $plan_file ) or return 0;
        print {$wfh} $new_content;
        close($wfh);
    } else {
        return 0;
    }

    my $rel = 'current/' . File::Basename::basename($plan_file);
    {
        local $ENV{GIT_DIR}        = undef;
        local $ENV{GIT_WORK_TREE}  = undef;
        local $ENV{GIT_INDEX_FILE} = undef;
        local $ENV{GIT_PREFIX}     = undef;

        my $prc = AAPP::CommitEngine::plans_commit( "plan(record): ${bound} commits after $mode", $rel );
        if ( $prc != RETURN_OK ) {
            print STDERR "⚠️  [AAPP Post-Rewrite] Could not record ${bound}'s rewritten commits ($val).\n";
            print STDERR "   Fix the record: set '* **Commits:** $val' in .plans/$rel and run 'aapp refine $bound \"record commits after $mode\"'.\n";
            return 0;
        }
    }

    print STDERR "📝 [AAPP Post-Rewrite] ${bound}'s Commits: now $val.\n";
    return 0;
}

1;
