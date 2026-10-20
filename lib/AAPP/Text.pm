package AAPP::Text;

use strict;
use warnings;
use utf8;
use 5.026;

use AAPP::Config ();

# Usage     : my $name = strip_leading_emoji('📂 Target Files')
# Purpose   : Removes the decorative emoji, joiners, variation selectors and spaces before a text,
#             so headings, statuses and cells are compared by their words only.
# Returns   : The text without them.
sub strip_leading_emoji
{
    my ($text) = @_;
    $text =~ s/^(?:(?=[^\x00-\x7F])[\p{S}\p{Me}\x{2139}]|[\x{200D}\x{FE0E}\x{FE0F}\s]+)+//;
    return $text;
}

# Usage     : my ($level, $name) = heading_name('## 📂 Target Files')
# Purpose   : Splits a Markdown heading into its level and its name, the name without emoji
#             and without trailing spaces.
# Returns   : (level, name), or () when the line is not a heading.
sub heading_name
{
    my ($line) = @_;
    if ( $line !~ /^(#{1,6})\s+(.*?)\s*$/ ) {
        return ();
    }
    my $level = length($1);
    my $name  = strip_leading_emoji($2);
    return ( $level, $name );
}

# Usage     : my $n = char_len($text)
# Purpose   : The length of a text in characters (the text is decoded UTF-8).
# Returns   : The number of characters.
sub char_len
{
    my ($text) = @_;
    return length($text);
}

# Usage     : my @lines = out_wrap($text, $first_indent, $hang_indent, $width)
# Purpose   : Wraps one paragraph at spaces: the first line indented by $first_indent spaces, the
#             rest by $hang_indent, none wider than $width. A word longer than the room stays whole.
# Returns   : The lines, without newlines; empty for an empty text.
sub out_wrap
{
    my ( $text, $first, $hang, $width ) = @_;
    my $para = join( ' ', split( /\n/, $text ) );
    $para =~ s/\t/ /g;
    $para =~ s/^ +//;
    $para =~ s/ +$//;
    my @words = split( /(?<! ) /, $para );
    my @lines;
    my $line;
    foreach my $word (@words) {
        if ( $word eq '' ) {
            next;
        }
        if ( !defined $line ) {
            $line = ( ' ' x $first ) . $word;
            next;
        }
        if ( length($line) + 1 + length($word) <= $width ) {
            $line .= " $word";
            next;
        }
        push @lines, $line;
        $line = ( ' ' x $hang ) . $word;
    }
    if ( defined $line ) {
        push @lines, $line;
    }
    return @lines;
}

# Usage     : my $short = out_cut($text, 220)
# Purpose   : Cuts one paragraph at the last space that keeps it within $limit characters, ending
#             it with '…'; shorter text is unchanged, and a first word longer than the limit is cut inside.
# Returns   : The text.
sub out_cut
{
    my ( $text, $limit ) = @_;
    my $para = join( ' ', split( /\n/, $text ) );
    if ( length($para) <= $limit ) {
        return $para;
    }
    my $out = '';
    foreach my $word ( split( / /, $para ) ) {
        my $try = $out eq '' ? $word : "$out $word";
        if ( length($try) > $limit - 1 ) {
            last;
        }
        $out = $try;
    }
    if ( $out eq '' ) {
        $out = substr( $para, 0, $limit - 1 );
    }
    return $out . '…';
}

# Usage     : my ($title, $text) = pickup_entry_split('- [ ] Title: the text')
# Purpose   : Splits a pickup line at its first ': ' outside backticks; a leading '- [ ] ' marker is dropped.
# Returns   : (title, text); the title is '' when the entry has none.
sub pickup_entry_split
{
    my ($line) = @_;
    chomp($line);
    $line =~ s/^\s*[-*+]\s+\[[ xX]?\]\s*//;
    $line =~ s/\s+$//;
    my $tick = 0;
    my $cut  = -1;
    for my $i ( 0 .. length($line) - 1 ) {
        my $c = substr( $line, $i, 1 );
        if ( $c eq '`' ) {
            $tick = !$tick;
            next;
        }
        if ( !$tick && $c eq ':' && ( $i == length($line) - 1 || substr( $line, $i + 1, 1 ) eq ' ' ) ) {
            $cut = $i;
            last;
        }
    }
    if ( $cut < 0 ) {
        return ( '', $line );
    }
    my $title = substr( $line, 0, $cut );
    my $text  = substr( $line, $cut + 1 );
    $title =~ s/\s+$//;
    $text  =~ s/^\s+//;
    return ( $title, $text );
}

# Usage     : my ($rc, $max) = pickup_title_max()
# Purpose   : The most characters a pickup title may have: aapp.pickupTitleMax, default 72, at least 10.
# Returns   : (RETURN_OK, $max), or (RETURN_ERROR, undef) after an [ ERROR ] line naming the key.
sub pickup_title_max
{
    return AAPP::Config::get_int( 'aapp.pickupTitleMax', 72, 10 );
}

# Usage     : my @files = pickup_entry_files($text)
# Purpose   : The .plans/pickup/ paths a pickup text names, in order; a closing '.' or ':' is not part of a path.
# Returns   : List of paths.
sub pickup_entry_files
{
    my ($text) = @_;
    my @files;
    while ( $text =~ m{(\.plans/pickup/[^\]\[\s`'"(),;<>]+)}g ) {
        my $path = $1;
        $path =~ s/[.:]+$//;
        push @files, $path;
    }
    return @files;
}

1;
