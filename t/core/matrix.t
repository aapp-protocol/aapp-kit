package AAPP::T::Core::Matrix;

use strict;
use warnings;
use utf8;
use 5.026;

use Cwd ();
use File::Copy ();
use File::Path ();
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/matrix.md. Run alone: prove -l t/core/matrix.t

our $MATRIX = '.plans/state_matrix.md';

# Usage     : fixture($self)
# Purpose   : A repository holding only what the matrix engine reads: .plans/current and lib/ with its two files.
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    File::Path::make_path( '.plans/current', 'lib' );
    File::Copy::copy( "$self->{kit}/lib/$_", "lib/$_" ) or die "cannot copy $_: $!\n" for qw(plan_states.sh cmd_matrix.sh);
    $self->init_repo();
    return 1;
}

# Usage     : make_plan($id, $slug, $status, $title)
# Purpose   : Writes plan P-<id> with the status.
# Returns   : 1
sub make_plan
{
    my ( $id, $slug, $status, $title ) = @_;
    AAPP::Tests::write_text( ".plans/current/P$id-$slug.md", "# 🗺️ Plan P-$id: $title\n* **Plan ID:** P-$id\n* **Status:** $status\n\n## 1. Context\nFixture plan.\n" );
    return 1;
}

# Usage     : set_status($file, $status)
# Purpose   : Rewrites a plan's Status line.
# Returns   : 1
sub set_status
{
    my ( $file, $status ) = @_;
    AAPP::Tests::write_text( $file, AAPP::Tests::read_text($file) =~ s/^\* \*\*Status:\*\*.*$/* **Status:** $status/mr );
    return 1;
}

# Usage     : my $r = run_matrix($self, @args)
# Purpose   : Runs the matrix engine as the kit does, with its library folder.
# Returns   : { exit, out, err, all }.
sub run_matrix
{
    my ( $self, @args ) = @_;
    local $ENV{AAPP_LIB} = Cwd::getcwd() . '/lib';
    my $r = $self->run_cmd( 'bash', 'lib/cmd_matrix.sh', @args );
    $r->{all} = $r->{out} . $r->{err};
    return $r;
}

# Usage     : my $n = count($re)
# Purpose   : How many matrix lines match.
# Returns   : The count.
sub count { my ($re) = @_; return scalar grep { $_ =~ $re } split( /\n/, AAPP::Tests::read_text($MATRIX) ); }

# Usage     : my @lines = section($name_re)
# Purpose   : The lines under the first '## ' heading matching the name, up to the next one.
# Returns   : List of lines.
sub section
{
    my ($name) = @_;
    my ( $on, @lines );
    foreach my $line ( split( /\n/, AAPP::Tests::read_text($MATRIX) ) ) {
        if ( $line =~ /^## / ) {
            last if $on;
            $on = $line =~ $name ? 1 : 0;
            next;
        }
        push @lines, $line if $on;
    }
    return @lines;
}

# Usage     : my $yes = in_section($name_re, $re)
# Purpose   : Whether a line under the section matches.
# Returns   : 1 or ''.
sub in_section { my ( $name, $re ) = @_; return ( grep { $_ =~ $re } section($name) ) ? 1 : ''; }

sub test_derives_sections_in_rank_order
{
    my ($self) = @_;
    make_plan( 1, 'alpha', '🟣 Under Review',   'Alpha Capability' );
    make_plan( 2, 'beta',  '🔷 Frozen',         'Beta Capability' );
    make_plan( 3, 'gamma', '⚡ In Development', 'Gamma Capability' );
    run_matrix($self);
    my @headings = grep {/^## /} split( /\n/, AAPP::Tests::read_text($MATRIX) );
    $self->eq_or_die( scalar(@headings), 6, 'the Roadmap, four sections and the ledger' );
    $self->match_or_die( $headings[2] // '', qr/Greenlight/, 'the third heading is the Greenlight Zone' );
    $self->eq_or_die( count(qr/🟣 \*\*P-1\*\*/), 1, 'a row carries its glyph' );
    $self->true_or_die( in_section( qr/Greenlight/, qr/\*\*P-2\*\*/ ), 'a frozen plan is under Greenlight' );
    $self->true_or_die( AAPP::Tests::read_text($MATRIX) =~ /\n\z/, 'the file ends with a newline' );
    $self->eq_or_die( count(qr/Unrecognized Status/), 0, 'no Unrecognized section' );
    return 1;
}

sub test_orphan_rows_removed
{
    my ($self) = @_;
    make_plan( 10, 'keep', '🟣 Under Review', 'Kept Plan' );
    make_plan( 11, 'drop', '🟣 Under Review', 'Dropped Plan' );
    run_matrix($self);
    $self->eq_or_die( count(qr/^- .+\*\*P-11\*\*/), 1, 'a row while the plan exists' );
    unlink('.plans/current/P11-drop.md') or die "cannot remove the plan: $!\n";
    run_matrix($self);
    $self->eq_or_die( count(qr/^- .+\*\*P-11\*\*/), 0, 'none once it left' );
    $self->eq_or_die( count(qr/^- .+\*\*P-10\*\*/), 1, 'its sibling stays' );
    return 1;
}

sub test_annotation_preserved
{
    my ($self) = @_;
    make_plan( 20, 'noted', '🟣 Under Review', 'Original Title' );
    run_matrix($self);
    AAPP::Tests::write_text( $MATRIX, AAPP::Tests::read_text($MATRIX) =~ s/— Original Title/— ✏️ **SKETCH — do not refine** — blocked on `#64`, `#57`/r );
    run_matrix($self);
    $self->eq_or_die( count(qr/SKETCH — do not refine/),     1, 'the annotation is kept' );
    $self->eq_or_die( count(qr/blocked on `#64`, `#57`/),    1, 'with its em-dashes' );
    set_status( '.plans/current/P20-noted.md', '🔷 Frozen' );
    run_matrix($self);
    $self->true_or_die( in_section( qr/Greenlight/, qr/SKETCH — do not refine/ ), 'the annotation follows its plan' );
    $self->eq_or_die( count(qr/🔷 \*\*P-20\*\*/), 1, 'the glyph follows the status' );
    return 1;
}

sub test_roadmap_preserved
{
    my ($self) = @_;
    make_plan( 30, 'road', '🟣 Under Review', 'Roadmapped Plan' );
    run_matrix($self);
    AAPP::Tests::write_text( $MATRIX,
        AAPP::Tests::read_text($MATRIX) =~ s/^\*No plans currently active on roadmap.*$/1. **P-30** — ship this first\n2. **P-31** — then this/mr );
    run_matrix($self);
    $self->eq_or_die( count(qr/ship this first/), 1, 'the first line' );
    $self->eq_or_die( count(qr/then this/),       1, 'the second line' );
    $self->eq_or_die( count(qr/^---$/),           6, 'no extra separators' );
    return 1;
}

sub test_unrecognized_statuses_bucketed
{
    my ($self) = @_;
    make_plan( 40, 'fine',  '🟣 Under Review',          'Recognized Plan' );
    make_plan( 41, 'stale', '🔴 Ancient Retired Glyph', 'Retired Glyph Plan' );
    make_plan( 42, 'typo',  '🍀 Totally Made Up',       'Typo Status Plan' );
    run_matrix($self);
    $self->eq_or_die( count(qr/Unrecognized Status/), 1, 'an Unrecognized section' );
    $self->eq_or_die( scalar( grep {/^- /} section(qr/Unrecognized Status/) ), 2, 'holding both rows' );
    $self->true_or_die( in_section( qr/Unrecognized Status/, qr/\*\*P-41\*\*/ ), 'the retired glyph is bucketed' );
    $self->eq_or_die( count(qr/^- .+\*\*P-40\*\*/), 1, 'the recognized row stays' );
    $self->eq_or_die( run_matrix( $self, 'check' )->{exit}, 0, 'the matrix checks in sync' );
    return 1;
}

sub test_paused_sync_advisory
{
    my ($self) = @_;
    make_plan( 50, 'pausey', '🟣 Under Review', 'Paused Repo Plan' );
    run_matrix($self);
    AAPP::Tests::write_text( '.git/aapp_paused', '' );
    set_status( '.plans/current/P50-pausey.md', '🔷 Frozen' );
    my $out = run_matrix($self)->{all};
    $self->match_or_die( $out, qr/PAUSED/,      'an advisory while paused' );
    $self->match_or_die( $out, qr/aapp resume/, 'naming aapp resume' );
    $self->eq_or_die( count(qr/🔷 \*\*P-50\*\*/), 1, 'the matrix is written' );
    $self->true_or_die( run_matrix($self)->{all} !~ /PAUSED/, 'a no-op stays silent' );
    unlink('.git/aapp_paused') or die "cannot remove the pause buffer: $!\n";
    $self->true_or_die( run_matrix($self)->{all} !~ /PAUSED/, 'no advisory after resuming' );
    return 1;
}

sub test_empty_current_renders
{
    my ($self) = @_;
    run_matrix($self);
    $self->eq_or_die( count(qr/^## /), 6, 'the headings' );
    $self->eq_or_die( run_matrix( $self, 'check' )->{exit}, 0, 'the matrix checks in sync' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
