package AAPP::T::Core::IssueId;

use strict;
use warnings;
use utf8;
use 5.026;

use AAPP::Constants qw(RETURN_OK);
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/issue_id.md. Run alone: prove -l t/core/issue_id.t

# Usage     : my $value = one($self, $function, @args)
# Purpose   : The first value a library function returns.
# Returns   : The value, or undef.
sub one
{
    my ( $self, $function, @args ) = @_;
    return $self->lib_call( 'state', $function, @args )->{ret}[0];
}

# Usage     : my $text = refs($self, $line)
# Purpose   : The ids issue_id_refs finds in a line, space-separated.
# Returns   : The text ('' when none).
sub refs
{
    my ( $self, $line ) = @_;
    return join( ' ', @{ $self->lib_call( 'state', 'issue_id_refs', $line )->{ret} } );
}

sub test_normalize_numeric_forms
{
    my ($self) = @_;
    $self->eq_or_die( one( $self, 'issue_id_normalize', $_->[0] ), $_->[1], "normalize $_->[0]" )
        for [ '46', '#46' ], [ '#46', '#46' ], [ '`#046`', '#46' ], [ 'ISSUE-79', '#79' ];
    $self->eq_or_die( one( $self, 'issue_id_valid', '46' ),        1, 'valid 46' );
    $self->eq_or_die( one( $self, 'issue_id_valid', '#46' ),       1, 'valid #46' );
    $self->eq_or_die( one( $self, 'issue_id_is_numeric', '#46' ),  1, '#46 is numeric' );
    $self->eq_or_die( one( $self, 'issue_fix_name', '#46' ),       'fix-46.md', 'fix file name' );
    $self->eq_or_die( one( $self, 'issue_fix_id', 'fix-46.md' ),   '#46', 'fix file id' );
    return 1;
}

sub test_refs_from_plan_lines
{
    my ($self) = @_;
    $self->eq_or_die( refs( $self, '* **Blocked On:** #12, #PROJ-7 (was ⚡ In Development); hotfix limit reached (#3)' ),
        '#12 #PROJ-7 #3', 'ids in a Blocked On line' );
    return 1;
}

sub test_refs_ignore_headings_and_hex
{
    my ($self) = @_;
    $self->eq_or_die( refs( $self, '### PROJ-101' ),                '', 'a heading' );
    $self->eq_or_die( refs( $self, 'colour #A1B2C3 here' ),         '', 'a hex colour' );
    $self->eq_or_die( refs( $self, 'x#12 and a#PROJ-9' ),           '', 'ids glued to a word' );
    $self->eq_or_die( refs( $self, 'fix: thing (#PROJ-101)' ),      '#PROJ-101', 'a commit subject' );
    $self->eq_or_die( refs( $self, '- [ ] #45 -> text' ),           '#45', 'a checklist line' );
    return 1;
}

sub test_key_id_valid
{
    my ($self) = @_;
    $self->eq_or_die( one( $self, 'issue_id_normalize', $_->[0] ), $_->[1], "normalize $_->[0]" )
        for [ 'PROJ-101', '#PROJ-101' ], [ '#PROJ-101', '#PROJ-101' ], [ 'proj-101', '#PROJ-101' ], [ 'A1-7', '#A1-7' ];
    $self->eq_or_die( one( $self, 'issue_id_is_numeric', '#PROJ-101' ),  0, 'a key is not numeric' );
    $self->eq_or_die( one( $self, 'issue_fix_name', '#PROJ-101' ),       'fix-PROJ-101.md', 'fix file name' );
    $self->eq_or_die( one( $self, 'issue_fix_id', 'fix-PROJ-101.md' ),   '#PROJ-101', 'fix file id' );
    return 1;
}

sub test_malformed_id_refused
{
    my ($self) = @_;
    foreach my $bad ( 'PROJ-', '#-7', 'PROJ 101', '101-PROJ', '', 'PROJ-1a', '#' ) {
        $self->eq_or_die( one( $self, 'issue_id_valid', $bad ), 0, "[$bad] is not valid" );
        $self->true_or_die( !defined one( $self, 'issue_id_normalize', $bad ), "[$bad] is not normalized" );
    }
    my $err = $self->lib_call( 'state', 'issue_id_normalize', 'PROJ-' )->{err};
    $self->match_or_die( $err, qr/46/,       'the refusal shows the numeric form' );
    $self->match_or_die( $err, qr/PROJ-101/, 'the refusal shows the key form' );
    return 1;
}

sub test_counter_ignores_key_ids
{
    my ($self) = @_;
    $self->init_repo();
    mkdir('.plans') && mkdir('.plans/done') or die "cannot make .plans/done: $!\n";
    AAPP::Tests::write_text( '.plans/ISSUES.md', <<'EOF' );
| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #PROJ-900 | `Low` | `CLI` | 2026-10-01 | `a.sh` | Tracker issue. |  | 🟡 `Incubated` |
| #12 | `Low` | `CLI` | 2026-10-01 | `a.sh` | Local issue. |  | 🟡 `Incubated` |
EOF
    AAPP::Tests::write_text( '.plans/done/000-issues-archive.md', <<'EOF' );
| # | Sev | Type | Date Opened | Date Resolved | Target Commit | Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #CORE-4000 | `Low` | `CLI` | 2026-09-01 | 2026-09-02 | `abc1234` | Fixed. |
| #7 | `Low` | `CLI` | 2026-09-01 | 2026-09-02 | `abc1234` | Fixed. |
EOF
    my $seed = $self->lib_call( 'state', 'seed_issue_id', "$self->{dir}/.plans" )->{ret};
    $self->eq_or_die( $seed->[0], RETURN_OK, 'the counter seeds' );
    $self->eq_or_die( $seed->[1], 13,        'the next number counts numeric ids only' );
    $self->eq_or_die( join( ' ', @{ $self->lib_call( 'state', 'ledger_ids', 'active' )->{ret} } ), 'PROJ-900 12', 'ledger_ids lists keys too' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
