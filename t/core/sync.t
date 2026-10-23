package AAPP::T::Core::Sync;

use strict;
use warnings;
use utf8;
use 5.026;

use Cwd ();
use Digest::SHA ();
use File::Path ();
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/sync.md. Run alone: prove -l t/core/sync.t

# Usage     : fixture($self)
# Purpose   : An initialized project with one commit.
# Returns   : 1
sub fixture { my ($self) = @_; return $self->init_project(); }

# Usage     : my ($origin, $upstream) = remotes($self)
# Purpose   : Two bare repositories inside the Git data, added as origin and upstream.
# Returns   : Their paths.
sub remotes
{
    my ($self) = @_;
    my @paths = map { Cwd::getcwd() . "/.git/$_.git" } qw(origin upstream);
    foreach my $i ( 0, 1 ) {
        $self->ok_cmd( 'git', 'init', '--bare', '-q', $paths[$i] );
        $self->ok_cmd( 'git', 'remote', 'add', (qw(origin upstream))[$i], $paths[$i] );
    }
    return @paths;
}

# Usage     : my $all = aapp_all($self, $ok, @args)
# Purpose   : Runs aapp; with $ok it must succeed, with 0 it must fail, with undef either.
# Returns   : Its two streams together.
sub aapp_all
{
    my ( $self, $ok, @args ) = @_;
    my $r = !defined $ok ? $self->run_cmd( 'aapp', @args ) : $ok ? $self->ok_cmd( 'aapp', @args ) : $self->fail_cmd( 'aapp', @args );
    return $r->{out} . $r->{err};
}

# Usage     : commit_in($self, $dir, $file, $text, $message)
# Purpose   : Appends text to a file of a checkout and commits it.
# Returns   : 1
sub commit_in
{
    my ( $self, $dir, $file, $text, $message ) = @_;
    AAPP::Tests::write_text( "$dir/$file", AAPP::Tests::read_text("$dir/$file") . $text );
    $self->ok_cmd( 'git', '-C', $dir, 'add', $file );
    $self->ok_cmd( 'git', '-C', $dir, 'commit', '-qm', $message );
    return 1;
}

# Usage     : my $name = branch_on($self, $bare, $branch)
# Purpose   : Whether a bare repository has the branch.
# Returns   : The branch name, or ''.
sub branch_on { my ( $self, $bare, $branch ) = @_; return $self->ok_cmd( 'git', '-C', $bare, 'branch', '--list', $branch )->{out} =~ s/[\s*]//gr; }

sub test_init_seeds_sync_defaults
{
    my ($self) = @_;
    my %want = ( 'aapp.remote' => 'origin', 'aapp.syncWorktrees' => 'plans agents githooks', 'aapp.pullStrategy' => 'ff-only', 'aapp.syncStrategy' => 'builtin' );
    $self->eq_or_die( $self->ok_cmd( 'git', 'config', $_ )->{out}, "$want{$_}\n", $_ ) for sort keys %want;
    return 1;
}

sub test_push_pull_sync_round_trip
{
    my ($self) = @_;
    my ( $origin, $upstream ) = remotes($self);
    commit_in( $self, '.plans',  'test.md', "test plan\n", 'add test plan' );
    commit_in( $self, '.agents', 'test.md', "test rule\n", 'add test rule' );
    $self->match_or_die( aapp_all( $self, 1, 'push' ), qr/All AAPP worktrees pushed successfully/, 'push succeeds' );
    $self->eq_or_die( branch_on( $self, $origin, 'plans' ),  'plans',  'the remote has plans' );
    $self->eq_or_die( branch_on( $self, $origin, 'agents' ), 'agents', 'and agents' );
    $self->eq_or_die( $self->ok_cmd( 'git', '-C', '.plans', 'rev-parse', '--abbrev-ref', '@{u}' )->{out}, "origin/plans\n", 'with upstream tracking' );

    my $clone = Cwd::getcwd() . '/.git/tmp_clone';
    $self->ok_cmd( 'git', 'clone', '-q', $origin, '-b', 'plans', $clone );
    commit_in( $self, $clone, 'test.md', "updated from clone\n", 'update plan from remote' );
    $self->ok_cmd( 'git', '-C', $clone, 'push', '-q', 'origin', 'plans' );
    aapp_all( $self, 1, 'pull' );
    $self->match_or_die( AAPP::Tests::read_text('.plans/test.md'), qr/updated from clone/, 'pull fast-forwards' );

    commit_in( $self, $clone, 'test.md', "remote line 2\n", 'update remote line 2' );
    $self->ok_cmd( 'git', '-C', $clone, 'push', '-q', 'origin', 'plans' );
    commit_in( $self, '.agents', 'test.md', "local agent rule\n", 'local agent update' );
    aapp_all( $self, 1, 'sync' );
    $self->match_or_die( AAPP::Tests::read_text('.plans/test.md'), qr/remote line 2/, 'sync pulls' );

    AAPP::Tests::write_text( '.plans/test.md', AAPP::Tests::read_text('.plans/test.md') . "uncommitted dirty content\n" );
    $self->match_or_die( aapp_all( $self, 0, $_ ), qr/Pre-flight check failed/, "a dirty worktree stops $_" ) for qw(pull sync);
    $self->ok_cmd( 'git', '-C', '.plans', 'checkout', '--', 'test.md' );

    aapp_all( $self, 1, 'push', 'upstream' );
    $self->eq_or_die( branch_on( $self, $upstream, 'plans' ), 'plans', 'push <remote> chooses the remote' );

    $self->ok_cmd( 'git', 'config', 'aapp.syncWorktrees', 'plans' );
    my $out = aapp_all( $self, undef, 'push' );
    $self->true_or_die( $out =~ m{\.plans/} && $out !~ m{\.agents/}, 'aapp.syncWorktrees chooses what', $out );
    return 1;
}

sub test_hook_strategy_and_precedence
{
    my ($self) = @_;
    remotes($self);
    $self->true_or_die(
        index( aapp_all( $self, 0, 'push', 'hook' ),
            '❌ aapp.syncStrategy=hook but no executable handler is registered for on-sync in .agents/skills/aapp-hooks/registry.tsv or git config.' ) >= 0,
        'the hook strategy without a handler is refused'
    );
    my $hook = Cwd::getcwd() . '/mock_on_sync.sh';
    AAPP::Tests::write_text( $hook,
        "#!/usr/bin/env bash\nINPUT=\"\$(cat)\"\necho \"HOOK_INVOKED: action=\$AAPP_ACTION remote=\$AAPP_REMOTE event=\$AAPP_EVENT\"\necho \"HOOK_PAYLOAD: \$INPUT\"\n" );
    chmod( 0755, $hook ) or die "cannot chmod the hook: $!\n";
    File::Path::make_path('.agents/skills/aapp-hooks');
    my $sha = Digest::SHA->new(256)->addfile( $hook, 'b' )->hexdigest;
    AAPP::Tests::write_text( '.agents/skills/aapp-hooks/registry.tsv', "on-sync\t$hook\tsha256:$sha\t10\tgate\n" );
    $self->ok_cmd( 'git', 'config', '--unset', 'aapp.syncStrategy' );
    my $out = aapp_all( $self, 1, 'push' );
    $self->match_or_die( $out, qr/HOOK_INVOKED: action=push remote=origin event=on-sync/, 'the registered handler gets the action' );
    $self->true_or_die( $out =~ /"action": "push"/ && $out =~ /"worktrees":/, 'and the envelope', $out );
    $self->ok_cmd( 'git', 'config', 'aapp.syncStrategy', 'builtin' );
    $out = aapp_all( $self, undef, 'push' );
    $self->true_or_die( $out !~ /HOOK_INVOKED/ && $out =~ /All AAPP worktrees pushed successfully/, 'git config overrides the registry', $out );
    $self->match_or_die( aapp_all( $self, undef, 'push', 'origin', 'hook' ), qr/HOOK_INVOKED: action=push remote=origin/, 'a CLI token overrides git config' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
