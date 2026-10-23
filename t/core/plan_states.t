package AAPP::T::Core::PlanStates;

use strict;
use warnings;
use utf8;
use 5.026;

use AAPP::Constants qw(RETURN_OK);
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/plan_states.md. Run alone: prove -l t/core/plan_states.t

our $CUSTOM = '👀|Awaiting Review|👀 Awaiting External Review|25';

# Usage     : fixture($self)
# Purpose   : An empty git repository: each test's copy has its own git config.
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    return $self->init_repo();
}

# Usage     : my @values = config($self, $function, @args)
# Purpose   : The values an AAPP::Config function returns.
# Returns   : The list.
sub config
{
    my ( $self, $function, @args ) = @_;
    return @{ $self->lib_call( 'config', $function, @args )->{ret} };
}

# Usage     : my $value = one($self, $function, @args)
# Purpose   : The first value an AAPP::Config function returns.
# Returns   : The value, or undef.
sub one
{
    my ( $self, $function, @args ) = @_;
    return ( config( $self, $function, @args ) )[0];
}

# Usage     : set($self, $slug, $tuple)
# Purpose   : An aapp.planState.<slug> entry in the test's git config.
# Returns   : 1
sub set
{
    my ( $self, $slug, $tuple ) = @_;
    $self->ok_cmd( 'git', 'config', "aapp.planState.$slug", $tuple );
    return 1;
}

# Usage     : hdr($file, $status)
# Purpose   : A plan whose header carries $status, with a decoy Status line in a fence and one after the first '## '.
# Returns   : 1
sub hdr
{
    my ( $file, $status ) = @_;
    AAPP::Tests::write_text( $file,
        "# Plan\n* **Plan ID:** P-1\n* **Status:** $status\n```\n* **Status:** 🔷 Frozen\n```\n## 1. Context\n* **Status:** 🔷 Frozen\n" );
    return 1;
}

sub test_defaults_resolve_by_name
{
    my ($self) = @_;
    my @slugs = map { one( $self, 'plan_state_for_status_line', "* **Status:** $_" ) // '' }
        ( '🟣 Under Review', '📝 Refining', '🔷 Frozen', '⚡ In Development', '🟥 BLOCKED' );
    $self->eq_or_die( join( ',', @slugs ), 'under-review,refining,frozen,in-development,blocked', 'the kit statuses' );
    return 1;
}

sub test_status_line_shapes
{
    my ($self) = @_;
    foreach my $line ( '* **Status:** ⚡ In Development', '- **Status:** ⚡ In Development', '  *  **Status:**   ⚡   In Development  ',
        '**Status:** ⚡ In Development (active)' )
    {
        $self->eq_or_die( one( $self, 'plan_state_for_status_line', $line ), 'in-development', "[$line]" );
    }
    return 1;
}

sub test_sections_in_rank_order
{
    my ($self) = @_;
    $self->eq_or_die( one( $self, 'plan_state_field', 'under-review', 'heading' ), one( $self, 'plan_state_field', 'refining', 'heading' ),
        'Under Review and Refining share one section' );
    my @sections = config( $self, 'plan_state_sections' );
    $self->eq_or_die( scalar(@sections), 4, 'four sections' );
    $self->eq_or_die( $sections[0], '🧠 Human Thought & Refinement (The Incubator)', 'the Incubator first' );
    return 1;
}

sub test_custom_status_from_config
{
    my ($self) = @_;
    set( $self, 'awaiting-review', $CUSTOM );
    $self->eq_or_die( one( $self, 'plan_state_for_status_line', '* **Status:** 👀 Awaiting Review' ), 'awaiting-review', 'the custom status resolves' );
    $self->eq_or_die( ( config( $self, 'plan_state_sections' ) )[2], '👀 Awaiting External Review', 'it sorts into its rank' );
    return 1;
}

sub test_override_by_slug_keeps_position
{
    my ($self) = @_;
    set( $self, 'frozen', '🔷|Frozen|🔷 Greenlit|20' );
    $self->eq_or_die( one( $self, 'plan_state_field', 'frozen', 'heading' ), '🔷 Greenlit', 'the heading is replaced' );
    $self->eq_or_die( ( config( $self, 'plan_state_sections' ) )[1], '🔷 Greenlit', 'the position is kept' );
    return 1;
}

sub test_malformed_entries_skipped
{
    my ($self) = @_;
    set( $self, 'bad1', 'only|three|fields' );
    set( $self, 'bad2', '🔵|Name|Heading|not-a-number' );
    set( $self, 'bad3', '||Heading|5' );
    my $r = $self->lib_call( 'config', 'plan_states_load' );
    my $warnings = () = $r->{err} =~ /^\[ WARN\s*\] Plan state '[^']+' skipped/mg;
    $self->eq_or_die( $warnings, 3, 'one warning per malformed entry' );
    $self->eq_or_die( one( $self, 'plan_state_for_status_line', '* **Status:** 🔷 Frozen' ), 'frozen', 'the registry still resolves' );
    $self->true_or_die( !defined one( $self, 'plan_state_for_status_line', '* **Status:** 🔵 Name' ), 'a skipped entry resolves to nothing' );
    return 1;
}

sub test_unrecognized_statuses
{
    my ($self) = @_;
    $self->true_or_die( !defined one( $self, 'plan_state_for_status_line', '* **Status:** 🔴 Something Retired' ), 'a retired status resolves to nothing' );
    $self->true_or_die( !defined one( $self, 'plan_state_for_status_line', '* **Status:** 🍀 Totally Made Up' ), 'an unknown status resolves to nothing' );
    return 1;
}

sub test_status_slug_reads_the_header_line_only
{
    my ($self) = @_;
    hdr( 'p.md', '⚡ In Development' );
    $self->eq_or_die( one( $self, 'plan_status_slug', 'p.md' ), 'in-development', 'the slug of the file' );
    my $stdin = $self->lib_call( { stdin => AAPP::Tests::read_text('p.md') }, 'config', 'plan_status_slug', '-' )->{ret}[0];
    $self->eq_or_die( $stdin, 'in-development', 'the slug read from stdin' );
    $self->eq_or_die( one( $self, 'plan_status_text', 'p.md' ), '⚡ In Development', 'the text of the header line' );
    return 1;
}

sub test_status_matched_by_name_whatever_the_glyph
{
    my ($self) = @_;
    hdr( 'a.md', '🛑 BLOCKED' );
    hdr( 'b.md', 'BLOCKED' );
    hdr( 'c.md', '🟥 BLOCKED' );
    AAPP::Tests::write_text( 'd.md', "# Plan\n## 1. Context\n" );
    $self->eq_or_die( one( $self, 'plan_status_slug', $_ ), 'blocked', "$_ is blocked" ) for qw(a.md b.md c.md);
    $self->true_or_die( !defined one( $self, 'plan_status_slug', 'd.md' ), 'a plan without a Status line has no slug' );
    return 1;
}

sub test_status_is_matches_any_given_slug
{
    my ($self) = @_;
    hdr( 'p.md', '🟥 BLOCKED' );
    AAPP::Tests::write_text( 'none.md', "# Plan\n" );
    $self->eq_or_die( one( $self, 'plan_status_is', 'p.md', 'in-development', 'blocked' ), 1, 'one of the slugs matches' );
    $self->eq_or_die( one( $self, 'plan_status_is', 'p.md', 'frozen' ),                    0, 'another slug does not' );
    $self->eq_or_die( one( $self, 'plan_status_is', 'none.md', 'blocked' ),                0, 'a plan without a Status line matches none' );
    return 1;
}

sub test_set_status_rewrites_the_header_line_only
{
    my ($self) = @_;
    hdr( 'p.md', '🔷 Frozen' );
    $self->eq_or_die( one( $self, 'plan_set_status', 'p.md', 'in-development' ), RETURN_OK, 'the status is set' );
    my @lines = split( /\n/, AAPP::Tests::read_text('p.md') );
    $self->eq_or_die( one( $self, 'plan_status_text', 'p.md' ), '⚡ In Development', 'the header line' );
    $self->eq_or_die( $lines[4], '* **Status:** 🔷 Frozen', 'the line in the fence is untouched' );
    $self->eq_or_die( $lines[7], '* **Status:** 🔷 Frozen', 'the line after the first ## is untouched' );
    return 1;
}

sub test_set_status_refuses_unknown_slug_or_missing_line
{
    my ($self) = @_;
    hdr( 'p.md', '🔷 Frozen' );
    my $before = AAPP::Tests::read_text('p.md');
    AAPP::Tests::write_text( 'none.md', "# Plan\n" );
    $self->true_or_die( one( $self, 'plan_set_status', 'p.md', 'done' ) != RETURN_OK,       'an unknown slug is refused' );
    $self->true_or_die( one( $self, 'plan_set_status', 'none.md', 'frozen' ) != RETURN_OK,  'a plan without a Status line is refused' );
    $self->eq_or_die( AAPP::Tests::read_text('p.md'), $before, 'the file is unchanged' );
    return 1;
}

sub test_accessors_follow_adopter_statuses
{
    my ($self) = @_;
    set( $self, 'in-development', '🚧|Under Construction|🚧 Building|30' );
    set( $self, 'awaiting-review', $CUSTOM );
    hdr( 'p.md', '📝 Refining' );
    $self->lib_call( 'config', 'plan_set_status', 'p.md', 'in-development' );
    $self->eq_or_die( one( $self, 'plan_status_text', 'p.md' ), '🚧 Under Construction', 'the adopter text is written' );
    $self->eq_or_die( one( $self, 'plan_status_slug', 'p.md' ), 'in-development',        'and read back' );
    $self->lib_call( 'config', 'plan_set_status', 'p.md', 'awaiting-review' );
    $self->eq_or_die( one( $self, 'plan_status_render', 'awaiting-review' ), '👀 Awaiting Review', 'a custom status renders' );
    $self->eq_or_die( one( $self, 'plan_status_slug', 'p.md' ), 'awaiting-review', 'and is read back' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
