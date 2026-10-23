package AAPP::T::Core::GroupDocs;

use strict;
use warnings;
use utf8;
use 5.026;

use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/group_docs.md. Run alone: prove -l t/core/group_docs.t

our $ARCH = <<'EOF';
# Arch
## Intro
intro
## Modules
old
### Old Sub
old sub
## Tail
tail
EOF

our $GROUP = <<'EOF';
# 🧩 Group Plan P-9: Grp
## Architecture & Codemap
### ARCHITECTURE.md
````markdown
## Modules
new modules
### New Sub
new sub
````
````markdown
## Brand New
added
````
### .agents/CODEMAP.md
No changes.
## 5. Open Questions
EOF

# Usage     : files($self)
# Purpose   : The target file and a group plan with one replaced and one new section, in the test's directory.
# Returns   : 1
sub files
{
    my ($self) = @_;
    AAPP::Tests::write_text( 'ARCH.md',  $ARCH );
    AAPP::Tests::write_text( 'group.md', $GROUP );
    return 1;
}

# Usage     : my $r = docs($self, $function, @args)
# Purpose   : A lib/group_docs.sh function on the test's files.
# Returns   : { exit, out, err, ret }.
sub docs
{
    my ( $self, $function, @args ) = @_;
    return $self->lib_call( 'group_docs', $function, @args );
}

sub test_base_lines_recorded_for_new_sections
{
    my ($self) = @_;
    files($self);
    my $r   = docs( $self, 'group_docs_stamp', 'group.md', 'ARCHITECTURE.md', 'ARCH.md' );
    my $sum = $self->lib_call( { stdin => "## Modules\nold\n### Old Sub\nold sub\n" }, 'group_docs', 'group_docs_sum' )->{out} =~ s/\s+$//r;
    my @bases = grep {/aapp-base:/} split( /\n/, AAPP::Tests::read_text('group.md') );
    $self->eq_or_die( $r->{exit}, 0, 'stamp exit' );
    $self->eq_or_die( $bases[0], "<!-- aapp-base: $sum -->", 'the replacing fence carries the section checksum' );
    $self->eq_or_die( $bases[1], '<!-- aapp-base: new -->',  'the added fence carries new' );
    my $stamped = AAPP::Tests::read_text('group.md');
    docs( $self, 'group_docs_stamp', 'group.md', 'ARCHITECTURE.md', 'ARCH.md' );
    $self->eq_or_die( AAPP::Tests::read_text('group.md'), $stamped, 'stamping again changes nothing' );
    return 1;
}

sub test_apply_replaces_adds_and_reports
{
    my ($self) = @_;
    files($self);
    docs( $self, 'group_docs_stamp', 'group.md', 'ARCHITECTURE.md', 'ARCH.md' );
    my $want = "# Arch\n## Intro\nintro\n## Modules\nnew modules\n### New Sub\nnew sub\n## Tail\ntail\n## Brand New\nadded\n";
    my $r    = docs( $self, 'group_docs_apply', 'group.md', 'ARCHITECTURE.md', 'ARCH.md' );
    my $all  = $r->{out} . $r->{err};
    $self->eq_or_die( $r->{exit}, 0, 'apply exit' );
    $self->eq_or_die( AAPP::Tests::read_text('ARCH.md'), $want, 'the applied file' );
    $self->match_or_die( $all, qr/^replaced: ## Modules$/m, 'the replaced section is reported' );
    $self->match_or_die( $all, qr/^added: ## Brand New$/m,  'the added section is reported' );
    $r   = docs( $self, 'group_docs_apply', 'group.md', 'ARCHITECTURE.md', 'ARCH.md' );
    $all = $r->{out} . $r->{err};
    $self->eq_or_die( $r->{exit}, 0, 'reapply exit' );
    $self->eq_or_die( AAPP::Tests::read_text('ARCH.md'), $want, 'the file after applying again' );
    $self->match_or_die( $all, qr/^unchanged: ## Modules$/m,   'an applied section is reported unchanged' );
    $self->match_or_die( $all, qr/^unchanged: ## Brand New$/m, 'an added section is reported unchanged' );
    return 1;
}

sub test_no_changes_leaves_files_untouched
{
    my ($self) = @_;
    files($self);
    AAPP::Tests::write_text( 'MAP.md', "# Map\n## A\na\n" );
    my $r = docs( $self, 'group_docs_apply', 'group.md', '.agents/CODEMAP.md', 'MAP.md' );
    $self->eq_or_die( $r->{exit}, 0, 'apply exit' );
    $self->eq_or_die( AAPP::Tests::read_text('MAP.md'), "# Map\n## A\na\n", 'the file is untouched' );
    $self->eq_or_die( $r->{out} . $r->{err}, '', 'nothing is reported' );
    return 1;
}

sub test_changed_section_refuses
{
    my ($self) = @_;
    files($self);
    docs( $self, 'group_docs_stamp', 'group.md', 'ARCHITECTURE.md', 'ARCH.md' );
    AAPP::Tests::write_text( 'ARCH.md', AAPP::Tests::read_text('ARCH.md') =~ s/^old$/old, edited meanwhile/mr );
    my $before = AAPP::Tests::read_text('ARCH.md');
    my $r      = docs( $self, 'group_docs_apply', 'group.md', 'ARCHITECTURE.md', 'ARCH.md' );
    $self->true_or_die( $r->{exit} != 0, 'a section changed since its base line is refused' );
    $self->eq_or_die( AAPP::Tests::read_text('ARCH.md'), $before, 'the file is left as it was' );
    $self->match_or_die( $r->{out} . $r->{err}, qr/## Modules/, 'the refusal names the section' );

    files($self);
    docs( $self, 'group_docs_stamp', 'group.md', 'ARCHITECTURE.md', 'ARCH.md' );
    AAPP::Tests::write_text( 'ARCH.md', AAPP::Tests::read_text('ARCH.md') . "## Brand New\nsomeone else\n" );
    $before = AAPP::Tests::read_text('ARCH.md');
    $r      = docs( $self, 'group_docs_apply', 'group.md', 'ARCHITECTURE.md', 'ARCH.md' );
    $self->true_or_die( $r->{exit} != 0, 'an added heading someone else wrote is refused' );
    $self->eq_or_die( AAPP::Tests::read_text('ARCH.md'), $before, 'the file is left as it was' );
    $self->match_or_die( $r->{out} . $r->{err}, qr/## Brand New/, 'the refusal names the heading' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
