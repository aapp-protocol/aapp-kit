package AAPP::T::Core::Output;

use strict;
use warnings;
use utf8;
use 5.026;

use AAPP::Constants qw(RETURN_OK);
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/output.md. Run alone: prove -l t/core/output.t

# Usage     : fixture($self)
# Purpose   : An empty git repository: the width is read from its git config.
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    return $self->init_repo();
}

# Usage     : my $n = longest(@lines)
# Purpose   : The most characters on one of the lines.
# Returns   : The count.
sub longest
{
    my (@lines) = @_;
    my $max = 0;
    foreach my $line (@lines) {
        $max = length($line) if length($line) > $max;
    }
    return $max;
}

# Usage     : my $width = width($self, 60)
# Purpose   : Sets aapp.statusOutputWidth and reads it back through out_width, as a view does.
# Returns   : The width out_width answers.
sub width
{
    my ( $self, $setting ) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.statusOutputWidth', $setting );
    my $r = $self->lib_call( 'output', 'out_width' );
    $self->eq_or_die( $r->{ret}[0], RETURN_OK, 'out_width answers' );
    return $r->{ret}[1];
}

sub test_wrap_hanging_indent
{
    my ($self) = @_;
    my $words = join( ' ', map { sprintf( 'word%02d', $_ ) } 1 .. 50 );
    my @out   = @{ $self->lib_call( 'text', 'out_wrap', $words, 2, 8, width( $self, 60 ) )->{ret} };
    my $all   = join( "\n", @out );
    $self->match_or_die( $out[0], qr/^  word01(?: |$)/, 'the first line is indented by 2' );
    $self->true_or_die( !grep( { !/^        [^ ]/ } @out[ 1 .. $#out ] ), 'the other lines hang at 8', $all );
    $self->true_or_die( longest(@out) <= 60, 'every line within 60 characters', $all );
    $self->eq_or_die( join( ' ', map { s/^ +//r } @out ), $words, 'no word lost' );
    $self->true_or_die( @out > 3, 'the text wraps over more than 3 lines', $all );
    return 1;
}

sub test_wrap_counts_characters
{
    my ($self) = @_;
    my $wide = join( ' ', ('é…ü…') x 20 );
    my @out  = @{ $self->lib_call( 'text', 'out_wrap', $wide, 0, 0, width( $self, 40 ) )->{ret} };
    my $all  = join( "\n", @out );
    $self->true_or_die( longest(@out) <= 40 && longest(@out) >= 35, 'lines fill 35 to 40 characters', $all );
    $self->true_or_die( @out <= 3, 'at most 3 lines', $all );
    return 1;
}

sub test_wrap_long_word_uncut
{
    my ($self) = @_;
    my $long = 'x' x 100;
    my @out  = @{ $self->lib_call( 'text', 'out_wrap', "short $long tail", 2, 2, width( $self, 40 ) )->{ret} };
    my $all  = join( "\n", @out );
    $self->eq_or_die( $out[0], '  short', 'the first line' );
    $self->true_or_die( grep( { $_ eq "  $long" } @out ), 'the long word stands alone, uncut', $all );
    return 1;
}

sub test_cut_at_word
{
    my ($self) = @_;
    my $text = join( ' ', map { sprintf( 'lorem%02d', $_ ) } 1 .. 40 );
    my $out  = $self->lib_call( 'text', 'out_cut', $text, 220 )->{ret}[0];
    $self->true_or_die( length($out) <= 220, 'within 220 characters', $out );
    $self->match_or_die( $out, qr/…$/, 'the cut is marked' );
    my $body = $out =~ s/…$//r;
    $self->eq_or_die( substr( $text, 0, length($body) ), $body, 'the cut keeps the start' );
    $self->eq_or_die( substr( $text, length($body), 1 ), ' ', 'the cut falls at a word boundary' );
    $self->eq_or_die( $self->lib_call( 'text', 'out_cut', 'short text', 220 )->{ret}[0], 'short text', 'short text unchanged' );
    return 1;
}

sub test_width_setting
{
    my ($self) = @_;
    $self->eq_or_die( width( $self, 60 ), 60, 'the set width' );
    $self->ok_cmd( 'git', 'config', '--unset', 'aapp.statusOutputWidth' );
    my $r = $self->lib_call( 'output', 'out_width' );
    $self->eq_or_die( $r->{ret}[1], 85, 'the default width' );
    foreach my $bad ( 'abc', '39' ) {
        $self->ok_cmd( 'git', 'config', 'aapp.statusOutputWidth', $bad );
        $r = $self->lib_call( 'output', 'out_width' );
        $self->true_or_die( $r->{ret}[0] != RETURN_OK, "'$bad' is refused", 'ret=' . join( ',', map { $_ // 'undef' } @{ $r->{ret} } ) );
        $self->match_or_die( $r->{err}, qr/aapp\.statusOutputWidth/, "the refusal of '$bad' names the setting" );
    }
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
