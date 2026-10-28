package AAPP::Runner::Review::Check;

use strict;
use warnings;
use utf8;
use 5.026;

use AAPP::Constants qw(RETURN_OK RETURN_FAIL);
use AAPP::Logger ();
use AAPP::Review ();

# Usage     : AAPP::Runner::Review::Check->run($id)
# Purpose   : 'aapp review check <id>', read only: lists each open or planned finding and each unticked task.
# Returns   : RETURN_OK when the review is clear (or there is none); RETURN_FAIL when items are open;
#             RETURN_NOT_FOUND for an unknown plan.
sub run
{
    my ( $class, $id, @extra ) = @_;
    if ( !defined $id || @extra ) {
        AAPP::Logger::print_msg( 'ERROR', 'Usage: aapp review check <id>' );
        return RETURN_FAIL;
    }
    my ( $rc, $plan ) = AAPP::Review::plan($id);
    if ( $rc != RETURN_OK ) {
        return $rc;
    }
    my @open = AAPP::Review::gate( $plan->{file} );
    if ( !@open ) {
        AAPP::Logger::print_msg( 'INFO', "review check: $plan->{id} clear." );
        return RETURN_OK;
    }
    AAPP::Logger::print_msg( 'ERROR', "review check: $plan->{id} has " . scalar(@open) . ' open item(s):' );
    foreach my $item (@open) {
        AAPP::Logger::print_msg( 'ERROR', "  $item" );
    }
    return RETURN_FAIL;
}

1;
