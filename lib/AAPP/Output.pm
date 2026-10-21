package AAPP::Output;

use strict;
use warnings;
use utf8;
use 5.026;

use AAPP::Constants qw(DEFAULT_OUTPUT_WIDTH MIN_OUTPUT_WIDTH);
use AAPP::Config ();
use AAPP::JSON qw();
use AAPP::Text ();

our @ISSUE_FIELDS = qw(id severity type status logged location symptom plan blocks queue_section
    queue_level queued branch offline tracker_name tracker_url tracker_release notes);

# Usage     : my ($rc, $width) = out_width()
# Purpose   : The most characters on an output line: aapp.statusOutputWidth (default and minimum in Constants).
# Returns   : (RETURN_OK, $width), or (RETURN_ERROR, undef) after an [ ERROR ] line naming the key.
sub out_width
{
    return AAPP::Config::get_int( 'aapp.statusOutputWidth', DEFAULT_OUTPUT_WIDTH, MIN_OUTPUT_WIDTH );
}

# Usage     : my $word = issue_word('in-progress')
# Purpose   : A record's slug as the views print it: 'in-progress' becomes 'In Progress'.
# Returns   : The words.
sub issue_word
{
    my ($slug) = @_;
    return join( ' ', map { ucfirst } split( /-/, $slug // '', -1 ) );
}

# Usage     : my @lines = issue_render_terminal(\@records, $width, $cut)
# Purpose   : Each issue as the views show it: a facts line at 2 spaces, the tracker's names at 8 when
#             a provider gave them, and the symptom at 8 (cut at $cut characters when $cut > 0).
# Returns   : The lines, none wider than $width (a single long word excepted).
sub issue_render_terminal
{
    my ( $records, $width, $cut ) = @_;
    my @lines;
    foreach my $r ( @{$records} ) {
        my $facts = join( '  ', $r->{id}, issue_word( $r->{severity} ), issue_word( $r->{status} ), "logged $r->{logged}" );
        if ( ( $r->{queue_section} // '' ) eq 'queued' ) {
            my $date = ( $r->{queued} // '' ) ne '' ? "$r->{queued} " : '';
            $facts .= "  queued $date(" . issue_word( $r->{queue_level} ) . ')';
        }
        if ( ( $r->{plan} // '' ) ne '' ) {
            $facts .= "  [$r->{plan}]";
        }
        if ( ( $r->{blocks} // '' ) ne '' ) {
            $facts .= "  [blocks $r->{blocks}]";
        }
        if ( ( $r->{branch} // '' ) ne '' ) {
            $facts .= "  (branch: $r->{branch})";
        }
        if ( $r->{offline} ) {
            $facts .= '  offline';
        }
        my $notes = $r->{notes} // '';
        if ( $notes ne '' && $notes ne '0' ) {
            $facts .= $notes eq '1' ? '  1 note' : "  $notes notes";
        }
        push @lines, AAPP::Text::out_wrap( $facts, 2, 8, $width );

        my $tracker = _tracker_text($r);
        if ( $tracker ne '' ) {
            push @lines, AAPP::Text::out_wrap( "· $tracker", 8, 10, $width );
        }
        my $symptom = $r->{symptom} // '';
        if ( ( $cut // 0 ) > 0 ) {
            $symptom = AAPP::Text::out_cut( $symptom, $cut );
        }
        push @lines, AAPP::Text::out_wrap( $symptom, 8, 8, $width );
    }
    return @lines;
}

# Usage     : my $text = _tracker_text($record)
# Purpose   : The tracker's name, URL and release as one line: 'NAME URL (release)'.
# Returns   : The text, '' when the record has none of them.
sub _tracker_text
{
    my ($r) = @_;
    my $name    = $r->{tracker_name}    // '';
    my $url     = $r->{tracker_url}     // '';
    my $release = $r->{tracker_release} // '';
    my $text    = $name;
    if ( $url ne '' ) {
        $text .= $text ne '' ? " $url" : $url;
    }
    if ( $release ne '' ) {
        $text .= " ($release)";
    }
    return $text;
}

# Usage     : my $json = issue_render_json(\@records)
# Purpose   : The records as the JSON list of issue objects (docs/reference/08-output-json.md).
# Returns   : The compact JSON text.
sub issue_render_json
{
    my ($records) = @_;
    my @items;
    foreach my $r ( @{$records} ) {
        my $queue = 'null';
        if ( ( $r->{queue_section} // '' ) ne '' ) {
            $queue = AAPP::JSON::json_obj(
                section => AAPP::JSON::json_str( $r->{queue_section} ),
                level   => AAPP::JSON::json_strn( $r->{queue_level} ),
                queued  => AAPP::JSON::json_strn( $r->{queued} ),
            );
        }
        my $tracker = 'null';
        if ( join( '', map { $_ // '' } @{$r}{qw(tracker_name tracker_url tracker_release)} ) ne '' ) {
            $tracker = AAPP::JSON::json_obj(
                name    => AAPP::JSON::json_strn( $r->{tracker_name} ),
                url     => AAPP::JSON::json_strn( $r->{tracker_url} ),
                release => AAPP::JSON::json_strn( $r->{tracker_release} ),
            );
        }
        push @items, AAPP::JSON::json_obj(
            id       => AAPP::JSON::json_str( $r->{id} ),
            severity => AAPP::JSON::json_str( $r->{severity} ),
            type     => AAPP::JSON::json_str( $r->{type} ),
            status   => AAPP::JSON::json_str( $r->{status} ),
            logged   => AAPP::JSON::json_strn( $r->{logged} ),
            location => AAPP::JSON::json_str( $r->{location} ),
            symptom  => AAPP::JSON::json_str( $r->{symptom} ),
            plan     => AAPP::JSON::json_strn( $r->{plan} ),
            blocks   => AAPP::JSON::json_strn( $r->{blocks} ),
            queue    => $queue,
            branch   => AAPP::JSON::json_strn( $r->{branch} ),
            offline  => AAPP::JSON::json_bool( $r->{offline} ),
            tracker  => $tracker,
            notes    => AAPP::JSON::json_numn( $r->{notes} ),
        );
    }
    return AAPP::JSON::json_list(@items);
}

1;
