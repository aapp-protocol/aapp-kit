package AAPP::Util;

use strict;
use warnings;
use utf8;
use 5.026;

use Exporter 'import';

our @EXPORT_OK = qw(plan_number plan_sort);

# Usage     : my $n = plan_number('.plans/current/P128-bash-commits.md')
# Purpose   : The number of a plan from its ID ('P-128', 'P128', 'p-128') or its file name ('P128-slug.md').
# Returns   : The number, or undef when the text names no plan.
sub plan_number
{
    my ($item) = @_;
    if ( !defined $item ) {
        return;
    }
    my $name = $item =~ s{.*/}{}r;
    if ( $name =~ /^[pP]-?0*([0-9]+)(?:-|\.md$|$)/ ) {
        return 0 + $1;
    }
    return;
}

# Usage     : my @sorted = plan_sort(@files_or_ids)
# Purpose   : Sorts plans by their number as a number (P-15 before P-128); ties, and items naming no
#             plan (last), by their text.
# Returns   : The sorted list.
sub plan_sort
{
    my (@items) = @_;
    my %number = map { ( $_ => scalar( plan_number($_) ) ) } @items;
    my @sorted = sort {
        my ( $na, $nb ) = ( $number{$a}, $number{$b} );
        if ( defined $na && defined $nb && $na != $nb ) {
            $na <=> $nb;
        } elsif ( defined $na && !defined $nb ) {
            -1;
        } elsif ( !defined $na && defined $nb ) {
            1;
        } else {
            $a cmp $b;
        }
    } @items;
    return @sorted;
}

1;
