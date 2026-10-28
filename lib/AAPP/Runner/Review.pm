package AAPP::Runner::Review;

use strict;
use warnings;
use utf8;
use 5.026;

use AAPP::Constants qw(RETURN_OK);
use AAPP::Logger ();
use AAPP::Runner ();

# The words of the review noun, in the order help shows them.
our @WORDS = qw(draft flag fix check);

# Usage     : AAPP::Runner::Review->run(@args)
# Purpose   : The review noun: hands its first parameter, the word, to the delegate step; with no word,
#             lists the words.
# Returns   : The word's return number; RETURN_OK for the list; RETURN_FAIL for an unknown word.
sub run
{
    my ( $class, @args ) = @_;
    if ( !@args ) {
        AAPP::Logger::print_msg( 'INFO', 'aapp review <word>: ' . join( ', ', @WORDS ) . '. Arguments: aapp help review.' );
        return RETURN_OK;
    }
    return AAPP::Runner::delegate( 'AAPP::Runner::Review', 'review word', \@WORDS, @args );
}

1;
