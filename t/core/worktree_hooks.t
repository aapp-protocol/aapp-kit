package AAPP::T::Core::WorktreeHooks;

use strict;
use warnings;
use utf8;
use 5.026;

use Cwd ();
use File::Path ();
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/worktree_hooks.md. Run alone: prove -l t/core/worktree_hooks.t

our $LONG_SUBJECT = 'docs: this is an excessively long commit subject line that surely exceeds the maximum allowed seventy-two characters';

# Usage     : fixture($self)
# Purpose   : A repository on main with the kit initialized and no commit of its own.
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    $self->init_repo();
    $self->ok_cmd( 'git', 'branch', '-M', 'main' );
    $self->ok_cmd( 'aapp', 'init' );
    return 1;
}

# Usage     : my $verdict = commits_in($self, $worktree, $message)
# Purpose   : Commits what is staged in a worktree.
# Returns   : 'COMMITTED' or 'BLOCKED'.
sub commits_in
{
    my ( $self, $wt, $message ) = @_;
    return $self->run_cmd( 'git', '-C', $wt, 'commit', '-m', $message )->{exit} == 0 ? 'COMMITTED' : 'BLOCKED';
}

# Usage     : stage_line($self, $worktree, $file, $line)
# Purpose   : Appends a line to a worktree's file and stages it.
# Returns   : 1
sub stage_line
{
    my ( $self, $wt, $file, $line ) = @_;
    AAPP::Tests::write_text( "$wt/$file", AAPP::Tests::read_text("$wt/$file") . "$line\n" );
    $self->ok_cmd( 'git', '-C', $wt, 'add', $file );
    return 1;
}

# Usage     : check_links($self, $step)
# Purpose   : .plans and .agents each link .githooks to ../.githooks and ignore it once.
# Returns   : 1
sub check_links
{
    my ( $self, $step ) = @_;
    foreach my $wt (qw(.plans .agents)) {
        $self->eq_or_die( readlink("$wt/.githooks") // '', '../.githooks', "$step: $wt/.githooks links to ../.githooks" );
        my $count = grep { $_ eq '.githooks' } split( /\n/, AAPP::Tests::read_text("$wt/.gitignore") );
        $self->eq_or_die( $count, 1, "$step: $wt/.gitignore names .githooks once" );
    }
    return 1;
}

# Usage     : my $pw = plan_worktree($self)
# Purpose   : A project in ./pw, develop beside its primary branch, worktrees and microcommits on, and plan
#             'wt-hooks' (targets src/wt.py and src/wt_extra.py) frozen and started in its own worktree.
# Returns   : Hash ref: root, primary (branch), id, file (the plan), wt (the plan worktree).
sub plan_worktree
{
    my ($self) = @_;
    my $root = Cwd::getcwd() . '/pw';
    File::Path::make_path($root);
    return $self->in_dir(
        $root,
        sub {
            $self->init_project();
            my $primary = $self->ok_cmd( 'git', 'rev-parse', '--abbrev-ref', 'HEAD' )->{out} =~ s/\s+\z//r;
            AAPP::Tests::write_text( '.gitignore', AAPP::Tests::read_text('.gitignore') . "__pycache__/\n" );
            $self->ok_cmd( 'git', 'add', '-A' );
            $self->ok_cmd( 'git', 'commit', '-qm', 'track init files', '--no-verify' );
            $self->ok_cmd( 'git', 'branch', 'develop' );
            $self->ok_cmd( 'git', 'config', 'aapp.planWorktrees', 'on' );
            $self->ok_cmd( 'git', 'config', 'aapp.commitMode',    'microcommits' );
            $self->ok_cmd( 'aapp', 'draft', 'wt-hooks' );
            my ($file) = glob('.plans/current/P*-wt-hooks.md');
            die "no plan drafted as wt-hooks\n" if !defined $file;
            my ($num) = $file =~ m{/P([0-9]+)-};
            my $text = AAPP::Tests::read_text($file);
            $text =~ s{src/path/to/new_file\.ext}{src/wt_extra.py}g;
            $text =~ s{src/path/to/file\.ext}{src/wt.py}g;
            $text =~ s/^\* \[ \] \*\*Question/* [x] **Question/mg;
            AAPP::Tests::write_text( $file, $text );
            $self->ok_cmd( 'git', '-C', '.plans', 'commit', '-qam', "prep P-$num" );
            $self->ok_cmd( 'aapp', 'freeze-start', "P-$num" );
            return { root => $root, primary => $primary, id => "P-$num", file => "$root/$file", wt => "$root/.workspace/P$num" };
        }
    );
}

# Usage     : my @shas = commits_list($pw)
# Purpose   : The short SHAs the plan's Commits line records, in order.
# Returns   : List of SHAs.
sub commits_list
{
    my ($pw) = @_;
    my ($line) = AAPP::Tests::read_text( $pw->{file} ) =~ /^\* \*\*Commits:\*\*\s*(.*)$/m;
    return ( $line // '' ) =~ /`([0-9a-f]+)`/g;
}

# Usage     : all_reachable($self, $pw)
# Purpose   : Every recorded SHA is an ancestor of the plan worktree's HEAD.
# Returns   : 1 or ''.
sub all_reachable
{
    my ( $self, $pw ) = @_;
    foreach my $sha ( commits_list($pw) ) {
        return '' if $self->run_cmd( 'git', '-C', $pw->{wt}, 'merge-base', '--is-ancestor', $sha, 'HEAD' )->{exit} != 0;
    }
    return 1;
}

# Usage     : my $short = head_short($self, $dir)
# Purpose   : The short SHA of HEAD in a checkout.
# Returns   : The SHA.
sub head_short { my ( $self, $dir ) = @_; return $self->ok_cmd( 'git', '-C', $dir, 'rev-parse', '--short', 'HEAD' )->{out} =~ s/\s+\z//r; }

# Usage     : on_develop($self, $pw, $file, $content, $message)
# Purpose   : Commits a file on develop from the primary checkout, without touching the plan worktree.
# Returns   : 1
sub on_develop
{
    my ( $self, $pw, $file, $content, $message ) = @_;
    my $root = $pw->{root};
    $self->ok_cmd( 'git', '-C', $root, 'checkout', '-q', 'develop' );
    AAPP::Tests::write_text( "$root/$file", "$content\n" );
    $self->ok_cmd( 'git', '-C', $root, 'add', $file );
    $self->ok_cmd( 'git', '-C', $root, 'commit', '-qm', $message, '--no-verify' );
    $self->ok_cmd( 'git', '-C', $root, 'checkout', '-q', $pw->{primary} );
    return 1;
}

# Usage     : my $verdict = guard($self, $dir, $path)
# Purpose   : What the write guard says, run from $dir, about writing $path.
# Returns   : 'allow' or 'refuse'.
sub guard
{
    my ( $self, $dir, $path ) = @_;
    return $self->in_dir( $dir, sub { $self->run_cmd( '.githooks/blast-radius-guard', $path )->{exit} == 0 ? 'allow' : 'refuse' } );
}

sub test_init_links_hooks_into_worktrees
{
    my ($self) = @_;
    check_links( $self, 'init' );
    $self->ok_cmd( 'aapp', 'init' );
    check_links( $self, 're-init' );
    return 1;
}

sub test_plans_worktree_runs_commit_hooks
{
    my ($self) = @_;
    stage_line( $self, '.plans', 'pickup.md', 'test idea' );
    $self->eq_or_die( commits_in( $self, '.plans', "docs: add test idea\n\nCo-authored-by: Claude <noreply\@anthropic.com>" ), 'BLOCKED', 'a Claude co-author' );
    $self->eq_or_die( commits_in( $self, '.plans', "docs: add test idea\n\nCo-authored-by: Antigravity <antigravity\@google.com>" ),
        'BLOCKED', 'an Antigravity co-author' );
    $self->eq_or_die( commits_in( $self, '.plans', $LONG_SUBJECT ),                   'BLOCKED',   'a subject over 72 characters' );
    $self->eq_or_die( commits_in( $self, '.plans', 'docs: add test idea in pickup' ), 'COMMITTED', 'a clean commit' );
    return 1;
}

sub test_agents_worktree_runs_commit_hooks
{
    my ($self) = @_;
    stage_line( $self, '.agents', 'PROJECT.MD', '# Note' );
    $self->eq_or_die( commits_in( $self, '.agents', "chore: update project context\n\nCo-authored-by: Claude <noreply\@anthropic.com>" ),
        'BLOCKED', 'a Claude co-author' );
    $self->eq_or_die( commits_in( $self, '.agents', 'chore: update project context cleanly' ), 'COMMITTED', 'a clean commit' );
    return 1;
}

sub test_attribution_modes_in_worktrees
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.aiAttribution', 'strict' );
    stage_line( $self, '.plans', 'pickup.md', 'note2' );
    $self->eq_or_die( commits_in( $self, '.plans', 'docs: missing AI trailer in strict mode' ), 'BLOCKED', 'strict without trailers' );
    $self->eq_or_die(
        commits_in( $self, '.plans', "docs: update test idea with valid trailers\n\nAI-Agent: Claude\nAI-Vendor: Anthropic\nAI-Model: claude-3-5-sonnet" ),
        'COMMITTED', 'strict with trailers' );
    $self->ok_cmd( 'git', 'config', 'aapp.aiAttribution', 'lax' );
    stage_line( $self, '.plans', 'pickup.md', 'note3' );
    $self->eq_or_die( commits_in( $self, '.plans', 'docs: human commit without trailers in lax mode' ), 'COMMITTED', 'lax takes a human commit' );
    return 1;
}

sub test_plan_worktree_guard
{
    my ($self) = @_;
    my $pw = plan_worktree($self);
    my ( $root, $wt ) = @{$pw}{qw(root wt)};
    $self->eq_or_die( guard( $self, $wt,   'src/wt.py' ),             'allow',  'a target, from the plan worktree' );
    $self->eq_or_die( guard( $self, $wt,   'src/other.py' ),          'refuse', 'another file, from the plan worktree' );
    $self->eq_or_die( guard( $self, $wt,   "$root/.plans/pickup.md" ), 'allow',  'the primary .plans, from the plan worktree' );
    $self->eq_or_die( guard( $self, $root, "$wt/src/wt.py" ),         'allow',  'a plan worktree target, from the primary' );
    $self->eq_or_die( guard( $self, $root, "$wt/src/other.py" ),      'refuse', 'another plan worktree file, from the primary' );
    return 1;
}

sub test_plan_worktree_pre_commit_refuses_outside_files
{
    my ($self) = @_;
    my $wt = plan_worktree($self)->{wt};
    File::Path::make_path("$wt/src");
    AAPP::Tests::write_text( "$wt/src/other.py", "o = 1\n" );
    $self->ok_cmd( 'git', '-C', $wt, 'add', 'src/other.py' );
    $self->fail_cmd( 'git', '-C', $wt, 'commit', '-qm', 'outside the plan' );
    return 1;
}

sub test_plan_worktree_commit_record_follows_rewrites
{
    my ($self) = @_;
    my $pw = plan_worktree($self);
    my $wt = $pw->{wt};
    my $record = sub { join( ' ', commits_list($pw) ) };
    $self->in_dir(
        $wt,
        sub {
            File::Path::make_path('src');
            AAPP::Tests::write_text( 'src/wt.py', "w = 1\n" );
            $self->ok_cmd( 'git', 'add', 'src/wt.py' );
            $self->ok_cmd( 'aapp', 'commit', 'feat: wt one' );
            my $branch = "plan/P" . ( $pw->{id} =~ s/^P-//r ) . '-wt-hooks';
            $self->true_or_die( index( AAPP::Tests::read_text( $pw->{file} ), '`' . head_short( $self, '.' ) . "` ($branch)" ) >= 0,
                'aapp commit recorded the commit' );

            on_develop( $self, $pw, 'dev2.py', 'd = 2', 'develop moves' );
            $self->ok_cmd( 'git', 'rebase', '-q', 'develop' );
            $self->eq_or_die( $record->(), head_short( $self, '.' ), 'after a rebase the record holds the new SHA' );
            $self->true_or_die( all_reachable( $self, $pw ), 'after a rebase every recorded SHA is reachable' );

            AAPP::Tests::write_text( 'src/wt.py', "w = 2\n" );
            $self->ok_cmd( 'git', 'add', 'src/wt.py' );
            $self->ok_cmd( 'aapp', 'commit', 'feat: wt two' );
            {
                local $ENV{GIT_SEQUENCE_EDITOR} = "sed -i '2s/^pick/squash/'";
                local $ENV{GIT_EDITOR}          = 'true';
                $self->ok_cmd( 'git', 'rebase', '-q', '-i', 'develop' );
            }
            $self->eq_or_die( $record->(), head_short( $self, '.' ), 'after a squash the record holds the squashed SHA' );

            AAPP::Tests::write_text( 'src/wt_extra.py', "e = 1\n" );
            $self->ok_cmd( 'git', 'add', 'src/wt_extra.py' );
            $self->ok_cmd( 'aapp', 'commit', 'feat: wt extra' );
            my $extra = $self->ok_cmd( 'git', 'rev-parse', 'HEAD' )->{out} =~ s/\s+\z//r;
            $self->ok_cmd( 'git', '-C', $pw->{root}, 'checkout', '-q', 'develop' );
            $self->ok_cmd( 'git', '-C', $pw->{root}, 'cherry-pick', $extra );
            $self->ok_cmd( 'git', '-C', $pw->{root}, 'checkout', '-q', $pw->{primary} );
            $self->ok_cmd( 'git', 'rebase', 'develop' );
            my $short = substr( $extra, 0, 7 );
            $self->true_or_die( !grep( { index( $_, $short ) == 0 } commits_list($pw) ), 'a commit dropped as upstream leaves the record', $record->() );
            $self->true_or_die( $record->() ne '' && all_reachable( $self, $pw ), 'the rest of the record is reachable', $record->() );

            AAPP::Tests::write_text( 'src/wt.py', "w = 4\n" );
            $self->ok_cmd( 'git', 'add', 'src/wt.py' );
            $self->ok_cmd( 'aapp', 'commit', 'amend' );
            my $head = head_short( $self, '.' );
            $self->eq_or_die( scalar( grep { $_ eq $head } commits_list($pw) ), 1, 'the amended SHA is recorded once' );
            $self->true_or_die( all_reachable( $self, $pw ), 'after an amend every recorded SHA is reachable', $record->() );
        }
    );
    return 1;
}

sub test_plan_worktree_refuses_merge
{
    my ($self) = @_;
    my $pw   = plan_worktree($self);
    my $root = $pw->{root};
    my $wt   = $pw->{wt};
    $self->in_dir(
        $wt,
        sub {
            File::Path::make_path('src');
            AAPP::Tests::write_text( 'src/wt.py', "w = 1\n" );
            $self->ok_cmd( 'git', 'add', 'src/wt.py' );
            $self->ok_cmd( 'aapp', 'commit', 'feat: wt one' );
        }
    );
    $self->ok_cmd( 'git', '-C', $root, 'checkout', '-q', 'develop' );
    File::Path::make_path("$root/src");
    AAPP::Tests::write_text( "$root/src/wt.py", "w = 99\n" );
    AAPP::Tests::write_text( "$root/dev3.py",   "d = 3\n" );
    $self->ok_cmd( 'git', '-C', $root, 'add', 'src/wt.py', 'dev3.py' );
    $self->ok_cmd( 'git', '-C', $root, 'commit', '-qm', 'develop edits wt', '--no-verify' );
    $self->ok_cmd( 'git', '-C', $root, 'checkout', '-q', $pw->{primary} );
    $self->fail_cmd( 'git', '-C', $wt, 'merge', 'develop' );
    AAPP::Tests::write_text( "$wt/src/wt.py", "w = 4\n" );
    $self->ok_cmd( 'git', '-C', $wt, 'add', 'src/wt.py' );
    $self->fail_cmd( 'git', '-C', $wt, 'commit', '-q', '--no-edit' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
