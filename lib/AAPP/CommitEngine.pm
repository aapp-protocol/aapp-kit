package AAPP::CommitEngine;

use strict;
use warnings;
use utf8;
use 5.026;

use File::Basename ();
use File::Spec ();
use File::Temp ();
use POSIX ();
use Time::HiRes ();
use AAPP::Constants qw(RETURN_OK RETURN_FAIL RETURN_ERROR PLANS_COMMIT_ATTEMPTS PLANS_COMMIT_RETRY_DELAY);
use AAPP::Logger ();
use AAPP::State ();


# Usage     : my $rc = plans_commit('plan(refine): P-12 tick tasks', 'current/P12-x.md')
# Purpose   : The one commit engine of the plans worktree: stages exactly the paths given, adds the
#             attribution trailers the mode asks for, and commits those paths only, retrying while
#             another process holds the index lock.
# Returns   : RETURN_OK; RETURN_FAIL when refused (no paths, strict attribution without identity);
#             RETURN_ERROR when git fails (its output printed).
sub plans_commit
{
    my ( $subject, @paths ) = @_;
    if ( !@paths ) {
        AAPP::Logger::print_msg( 'ERROR', 'plans_commit needs at least one path.' );
        return RETURN_FAIL;
    }
    my $plans = AAPP::State::plans_root();
    if ( !defined $plans || !-d $plans ) {
        AAPP::Logger::print_msg( 'ERROR', 'The .plans worktree was not found.' );
        return RETURN_ERROR;
    }
    if ( system( 'git', '-C', $plans, 'add', '--', @paths ) != 0 ) {
        AAPP::Logger::print_msg( 'ERROR', "Cannot stage in $plans: @paths" );
        return RETURN_ERROR;
    }
    my $msg = File::Temp->new( TEMPLATE => 'aapp-msg-XXXXXX', TMPDIR => 1 );
    binmode( $msg, ':encoding(UTF-8)' );
    print {$msg} "$subject\n";
    close($msg);
    if ( decorate_message( $msg->filename ) != RETURN_OK ) {
        AAPP::Logger::print_msg( 'ERROR', 'Attribution failed: strict mode needs an AI identity (agent, vendor, model).' );
        return RETURN_FAIL;
    }
    for my $attempt ( 1 .. PLANS_COMMIT_ATTEMPTS ) {
        my ( $status, $output ) = _git_with_output( '-C', $plans, 'commit', '-F', $msg->filename, '--', @paths );
        if ( $status == 0 ) {
            AAPP::State::forget("$plans/$_") for @paths;
            return RETURN_OK;
        }
        if ( $output !~ /index\.lock|Unable to create.*lock/i ) {
            print STDERR $output;
            return RETURN_ERROR;
        }
        if ( $attempt == PLANS_COMMIT_ATTEMPTS ) {
            AAPP::Logger::print_msg( 'ERROR', 'The .plans index is still locked after ' . PLANS_COMMIT_ATTEMPTS . ' attempts.' );
            print STDERR $output;
            return RETURN_ERROR;
        }
        AAPP::Logger::print_msg( 'WARN', "The .plans index is locked; attempt $attempt of " . PLANS_COMMIT_ATTEMPTS . ', waiting.' );
        Time::HiRes::sleep(PLANS_COMMIT_RETRY_DELAY);
    }
    return RETURN_ERROR;
}

# Usage     : my $rc = decorate_message($file)
# Purpose   : Adds the AI-Agent/AI-Vendor/AI-Model trailers to a message file as aapp.aiAttribution asks.
#             Runs the kit's attribution.sh beside this module until AAPP::Attribution exists (P-116).
# Returns   : RETURN_OK, or RETURN_FAIL when strict mode finds no identity.
sub decorate_message
{
    my ($file) = @_;
    my $lib    = File::Basename::dirname( File::Basename::dirname( File::Spec->rel2abs(__FILE__) ) );
    my $script = <<'SH';
. "$1/attribution.sh" || exit 3
id="$(resolve_ai_identity "${AAPP_AGENT_NAME:-}" "${AAPP_AGENT_VENDOR:-}" "${AAPP_AGENT_MODEL:-}")"
attribution_decorate "$2" "$id"
SH
    my $status = system( 'bash', '-c', $script, 'aapp-attribution', $lib, $file );
    if ( $status != 0 ) {
        return RETURN_FAIL;
    }
    return RETURN_OK;
}

# Usage     : my ($status, $output) = _git_with_output(@args)
# Purpose   : Runs git and reads what it prints on stdout and stderr together.
# Returns   : (exit status, output text).
sub _git_with_output
{
    my (@args) = @_;
    my $fh;
    my $pid = open( $fh, '-|' );
    if ( !defined $pid ) {
        return ( -1, "cannot start git: $!\n" );
    }
    if ( $pid == 0 ) {
        open( STDERR, '>&', \*STDOUT );
        { exec( 'git', @args ) };
        POSIX::_exit(127);
    }
    binmode( $fh, ':encoding(UTF-8)' );
    my $output = do { local $/; <$fh> } // '';
    close($fh);
    return ( $?, $output );
}

1;
