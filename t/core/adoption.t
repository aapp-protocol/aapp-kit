package AAPP::T::Core::Adoption;

use strict;
use warnings;
use utf8;
use 5.026;

use Digest::SHA ();
use Encode ();
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/adoption.md. Run alone: prove -l t/core/adoption.t

our $LIST = '.plans/adoption.md';

# The starter tasks a fresh project gets.
our @STARTER = qw(DEV-BRANCH PLAN-ID-PROVIDER TEAM-SETTINGS INIT-FILES PROJECT-RULES PROJECT-MAP GATE-TEST
    SET-WORKTREES SET-INTEGRATE SET-AUTO-REBASE SET-DOCS SET-COMMIT-MODE SET-ATTRIBUTION);

# Usage     : fixture($self)
# Purpose   : A project with the kit initialized (aapp init): every test reruns init in its own copy.
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    return $self->init_project();
}

# Usage     : my $text = checklist()
# Purpose   : The adoption checklist as it is now.
# Returns   : The text ('' when missing).
sub checklist { return AAPP::Tests::read_text($LIST); }

# Usage     : has_task($text, 'DEV-BRANCH') / ticked($text, 'DEV-BRANCH')
# Purpose   : Whether the checklist names a task, or names it ticked.
# Returns   : 1 or ''.
sub has_task { my ( $text, $task ) = @_; return index( $text, "`[$task]`" ) >= 0; }
sub ticked   { my ( $text, $task ) = @_; return $text =~ /^- \[x\] `\[\Q$task\E\]`/m; }

# Usage     : init($self)
# Purpose   : Reruns aapp init in the test's copy.
# Returns   : 1
sub init { my ($self) = @_; $self->ok_cmd( 'aapp', 'init' ); return 1; }

sub test_seeded_and_untracked
{
    my ($self) = @_;
    $self->file_exists_or_die($LIST);
    $self->match_or_die( checklist(), qr/^# 📋 Adoption Checklist/m, 'the checklist heading' );
    $self->match_or_die( AAPP::Tests::read_text('.plans/.gitignore'), qr/adoption\.md/, '.plans/.gitignore lists it' );
    $self->eq_or_die( $self->ok_cmd( 'git', '-C', '.plans', 'status', '--porcelain' )->{out}, '', 'the plans worktree is clean' );
    $self->true_or_die( $self->ok_cmd( 'git', '-C', '.plans', 'ls-files' )->{out} !~ /adoption\.md/, 'no version of it is committed' );
    return 1;
}

sub test_gitignore_line_added_on_rerun
{
    my ($self) = @_;
    AAPP::Tests::write_text( '.plans/.gitignore', AAPP::Tests::read_text('.plans/.gitignore') =~ s/^.*adoption\.md.*\n//mr );
    $self->run_cmd( 'git', '-C', '.plans', 'commit', '-qam', 'test: remove ignore line' );
    init($self);
    $self->match_or_die( AAPP::Tests::read_text('.plans/.gitignore'), qr/adoption\.md/, 'the line is added again' );
    return 1;
}

sub test_fresh_install_tasks
{
    my ($self) = @_;
    my $text = checklist();
    $self->true_or_die( has_task( $text, $_ ), "the starter task [$_]" ) for @STARTER;
    return 1;
}

sub test_satisfied_rules_add_nothing
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.devBranch', 'develop' );
    unlink($LIST) or die "cannot remove $LIST: $!\n";
    init($self);
    $self->true_or_die( !has_task( checklist(), 'DEV-BRANCH' ), '[DEV-BRANCH] is not added once satisfied' );
    return 1;
}

sub test_branch_and_remote_rules
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.devBranch', 'develop' );
    init($self);
    $self->true_or_die( ticked( checklist(), 'DEV-BRANCH' ), '[DEV-BRANCH] is ticked once aapp.devBranch is set' );
    return 1;
}

sub test_project_file_rules
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'add', '-A' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'test: clean init files' );
    init($self);
    $self->true_or_die( ticked( checklist(), 'INIT-FILES' ), '[INIT-FILES] is ticked once the files are committed' );
    return 1;
}

sub test_hook_rules
{
    my ($self) = @_;
    mkdir('.husky') or die "cannot make .husky: $!\n";
    AAPP::Tests::write_text( '.husky/pre-commit', "echo husky\n" );
    chmod( 0755, '.husky/pre-commit' ) or die "cannot chmod: $!\n";
    $self->ok_cmd( 'git', 'config', 'core.hooksPath', '.husky' );
    init($self);
    $self->true_or_die( has_task( checklist(), 'HOOK-WIRING' ), 'a foreign core.hooksPath adds [HOOK-WIRING]' );
    AAPP::Tests::write_text( '.husky/pre-commit', AAPP::Tests::read_text('.husky/pre-commit') . ".githooks/aapp-pre-commit\n" );
    init($self);
    $self->true_or_die( ticked( checklist(), 'HOOK-WIRING' ), 'naming aapp-pre-commit there ticks it' );
    return 1;
}

sub test_build_tool_rules_follow_worktree_path
{
    my ($self) = @_;
    AAPP::Tests::write_text( 'nx.json', '' );
    init($self);
    my $text = checklist();
    $self->true_or_die( has_task( $text, 'MONO-NX' ),       'nx.json adds [MONO-NX]' );
    $self->true_or_die( index( $text, '.workspace' ) >= 0, 'naming the worktree directory' );
    AAPP::Tests::write_text( '.nxignore', "/.workspace\n" );
    init($self);
    $self->true_or_die( ticked( checklist(), 'MONO-NX' ), 'an ignore line ticks it' );
    return 1;
}

sub test_review_tasks_only_user_ticks
{
    my ($self) = @_;
    $self->match_or_die( checklist(), qr/^- \[ \] `\[SET-WORKTREES\]`/m, 'the review task is open' );
    AAPP::Tests::write_text( $LIST, checklist() =~ s/^- \[ \] `\[SET-WORKTREES\]`/- [x] `[SET-WORKTREES]`/mr );
    init($self);
    $self->true_or_die( ticked( checklist(), 'SET-WORKTREES' ), 'the hand tick survives a rerun' );
    return 1;
}

sub test_rerun_is_quiet
{
    my ($self) = @_;
    my $head = sub { $self->ok_cmd( 'git', '-C', '.plans', 'rev-parse', 'HEAD' )->{out} };
    my $sum  = sub { Digest::SHA::sha256_hex( Encode::encode( 'UTF-8', checklist() ) ) };
    my ( $c1, $h1 ) = ( $head->(), $sum->() );
    init($self);
    $self->eq_or_die( $head->(), $c1, 'no plans commit' );
    $self->eq_or_die( $sum->(),  $h1, 'no changed byte' );
    return 1;
}

sub test_user_edits_survive
{
    my ($self) = @_;
    AAPP::Tests::write_text( $LIST, checklist() =~ s/Name your development branch/Custom reworded instruction/r );
    init($self);
    $self->true_or_die( index( checklist(), 'Custom reworded instruction' ) >= 0, 'a reworded line is kept' );
    return 1;
}

sub test_docs_targets_exist
{
    my ($self) = @_;
    my @targets = @{ $self->lib_call( 'adoption', 'get_all_adoption_doc_targets' )->{ret} };
    $self->true_or_die( scalar(@targets), 'the catalogue names documentation targets' );
    my @missing = grep { $_ ne '' && !-f "$self->{kit}/$_" } @targets;
    $self->true_or_die( !@missing, 'every documentation target is a file in the kit', join( ', ', @missing ) );
    return 1;
}

sub test_docs_governance_disabled
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.docs', 'false' );
    unlink($LIST) or die "cannot remove $LIST: $!\n";
    init($self);
    my $text = checklist();
    $self->true_or_die( !has_task( $text, 'PROJECT-RULES' ), '[PROJECT-RULES] is left out' );
    $self->true_or_die( !has_task( $text, 'PROJECT-MAP' ),   '[PROJECT-MAP] is left out' );
    $self->true_or_die( has_task( $text, 'SET-DOCS' ),        '[SET-DOCS] is still there' );
    $self->true_or_die( has_task( $text, 'SET-AUTO-REBASE' ), '[SET-AUTO-REBASE] is still there' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
