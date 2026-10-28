package AAPP::Runner::Review::Flag;

use strict;
use warnings;
use utf8;
use 5.026;

use AAPP::Constants qw(RETURN_OK RETURN_FAIL RETURN_ERROR);
use AAPP::CommitEngine ();
use AAPP::JSON ();
use AAPP::Logger ();
use AAPP::Review ();

# Usage     : AAPP::Runner::Review::Flag->run($id, $finding, ['file', $path])
# Purpose   : 'aapp review flag <id> "<finding>" [file <path>]': appends a signed finding to the §7 of a plan
#             in development, from any checkout, in one plans commit.
# Returns   : RETURN_OK; RETURN_FAIL or RETURN_ERROR after an [ ERROR ] line; RETURN_NOT_FOUND for an unknown plan.
sub run
{
    my ( $class, $id, $text, @rest ) = @_;
    my $path;
    if ( @rest == 2 && $rest[0] eq 'file' && $rest[1] ne '' ) {
        $path = $rest[1];
    } elsif (@rest) {
        AAPP::Logger::print_msg( 'ERROR', 'Usage: aapp review flag <id> "<finding>" [file <path>]' );
        return RETURN_FAIL;
    }
    my ( $rc, $plan ) = AAPP::Review::plan($id);
    if ( $rc != RETURN_OK ) {
        return $rc;
    }
    if ( AAPP::Review::implementing($plan) != RETURN_OK ) {
        return RETURN_FAIL;
    }
    $text = ( $text // '' ) =~ s/\s+/ /gr =~ s/^ | $//gr;
    if ( $text eq '' ) {
        AAPP::Logger::print_msg( 'ERROR', 'A finding needs its text: aapp review flag <id> "<finding>"' );
        return RETURN_FAIL;
    }
    my $n = AAPP::Review::add_finding( $plan, $text, $path );
    if ( !defined $n ) {
        return RETURN_ERROR;
    }
    $rc = AAPP::CommitEngine::plans_commit( "plan(review): $plan->{id} F$n flagged", $plan->{rel} );
    if ( $rc != RETURN_OK ) {
        return $rc;
    }
    my $outside = defined $path && !AAPP::Review::is_target( $plan, $path );
    AAPP::Logger::log_event( 'review', 'flag',
        { plan_id => "$plan->{id}", finding => "F$n", file => $path // '', outside_targets => $outside ? $AAPP::JSON::true : $AAPP::JSON::false } );
    AAPP::Logger::print_msg( 'INFO', "F$n flagged on $plan->{id}" . ( $outside ? ": `$path` is outside its Target Files; the fix needs an amendment request." : '.' ) );
    return RETURN_OK;
}

1;
