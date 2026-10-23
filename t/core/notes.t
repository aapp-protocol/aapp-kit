package AAPP::T::Core::Notes;

use strict;
use warnings;
use utf8;
use 5.026;

use Cwd ();
use File::Path ();
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/notes.md. Run alone: prove -l t/core/notes.t

# Usage     : fixture($self)
# Purpose   : An initialized project.
# Returns   : 1
sub fixture { my ($self) = @_; return $self->init_project(); }

# Usage     : my $text = note_of($self, $ref, $sha)
# Purpose   : The note on a commit in refs/notes/<ref>.
# Returns   : The note, or '' when there is none.
sub note_of
{
    my ( $self, $ref, $sha ) = @_;
    my $r = $self->run_cmd( 'git', 'notes', "--ref=refs/notes/$ref", 'show', $sha );
    return $r->{exit} == 0 ? $r->{out} : '';
}

# Usage     : my $sha = head($self)
# Purpose   : HEAD's full SHA.
# Returns   : The SHA.
sub head { my ($self) = @_; return $self->ok_cmd( 'git', 'rev-parse', 'HEAD' )->{out} =~ s/\s+\z//r; }

# Usage     : my $sha = ai_commit($self, $file)
# Purpose   : Commits a new file with a staged AI note naming Claude.
# Returns   : The commit's SHA.
sub ai_commit
{
    my ( $self, $file ) = @_;
    AAPP::Tests::write_text( $file, "$file\n" );
    $self->ok_cmd( 'git', 'add', $file );
    $self->ok_cmd( 'aapp', 'note', 'stage', 'Benchmark score: 98.4%', 'msg', "feat: add $file", 'agent', 'Claude', 'vendor', 'Anthropic', 'model', 'claude-3-5' );
    $self->ok_cmd( 'git', 'commit', '-qm', "feat: add $file" );
    return head($self);
}

# Usage     : my $dir = clone_project($self, $name, $remote)
# Purpose   : Another initialized project in ./<name> whose origin, and notes remote, is $remote.
# Returns   : Its absolute path.
sub clone_project
{
    my ( $self, $name, $remote ) = @_;
    my $dir = Cwd::getcwd() . "/$name";
    File::Path::make_path($dir);
    $self->in_dir(
        $dir,
        sub {
            $self->init_project();
            $self->ok_cmd( 'git', 'remote', 'add', 'origin', $remote );
            $self->ok_cmd( 'git', 'config', 'aapp.notesRemote', 'origin' );
        }
    );
    return $dir;
}

sub test_notes_land_in_their_own_ref
{
    my ($self) = @_;
    AAPP::Tests::write_text( 'alpha.txt', "alpha\n" );
    $self->ok_cmd( 'git', 'add', 'alpha.txt' );
    $self->ok_cmd( 'aapp', 'note', 'stage', 'Peer review: looks good', 'msg', 'feat: commit alpha' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'feat: commit alpha' );
    my $alpha = head($self);
    $self->match_or_die( note_of( $self, 'commits', $alpha ), qr/Peer review: looks good/, 'a developer note goes to refs/notes/commits' );
    $self->eq_or_die( note_of( $self, 'ai', $alpha ), '', 'and not to refs/notes/ai' );
    my $beta = ai_commit( $self, 'beta.txt' );
    $self->eq_or_die( note_of( $self, 'commits', $beta ), '', 'an AI note does not go to refs/notes/commits' );
    my $ai = note_of( $self, 'ai', $beta );
    $self->match_or_die( $ai, qr/AI-Agent: Claude/,  'it goes to refs/notes/ai' );
    $self->match_or_die( $ai, qr/Benchmark score/,   'with its text' );
    $self->eq_or_die( $self->lib_call( 'attribution', 'attribution_note', $alpha, 'Claude (Anthropic)', 'Model: test' )->{exit}, 0, 'an AI note on alpha' );
    $self->ok_cmd( 'git', 'notes', '--ref=refs/notes/commits', 'remove', $alpha );
    $self->eq_or_die( note_of( $self, 'commits', $alpha ), '', 'the developer note is removed' );
    $self->match_or_die( note_of( $self, 'ai', $alpha ), qr/AI-Agent: Claude/, 'the AI note stays' );
    return 1;
}

sub test_note_appends_and_survives_amend
{
    my ($self) = @_;
    my $sha = ai_commit( $self, 'beta.txt' );
    $self->eq_or_die( $self->lib_call( 'attribution', 'attribution_note', $sha, 'Antigravity (Google)', 'Secondary review: pass' )->{exit}, 0, 'a second note' );
    my $note = note_of( $self, 'ai', $sha );
    $self->true_or_die( $note =~ /Claude/ && $note =~ /Antigravity/, 'the note is appended to', $note );
    $self->ok_cmd( 'git', 'config', 'notes.rewriteMode', 'concatenate' );
    $self->ok_cmd( 'git', 'config', '--add', 'notes.rewriteRef', 'refs/notes/ai' );
    AAPP::Tests::write_text( 'beta.txt', "beta.txt\namendment\n" );
    $self->ok_cmd( 'git', 'add', 'beta.txt' );
    $self->ok_cmd( 'git', 'commit', '-q', '--amend', '-m', 'feat: beta amended' );
    $self->match_or_die( note_of( $self, 'ai', head($self) ), qr/AI-Agent: Claude/, 'the amended commit keeps its note' );
    return 1;
}

# Usage     : my ($one, $two, $sha) = shared_notes($self)
# Purpose   : A bare remote, clone 'one' with an AI-noted commit on develop and both note refs pushed, and
#             clone 'two' that pulled them.
# Returns   : (one's path, two's path, the noted commit).
sub shared_notes
{
    my ($self) = @_;
    my $remote = Cwd::getcwd() . '/remote.git';
    $self->ok_cmd( 'git', 'init', '-q', '--bare', $remote );
    my $one = clone_project( $self, 'one', $remote );
    my $sha = $self->in_dir(
        $one,
        sub {
            my $s = ai_commit( $self, 'gamma.txt' );
            $self->ok_cmd( 'git', 'notes', '--ref=refs/notes/commits', 'add', '-m', 'Peer review', $s );
            $self->ok_cmd( 'git', 'push', '-q', 'origin', 'HEAD:develop' );
            $self->ok_cmd( 'aapp', 'note', 'push' );
            return $s;
        }
    );
    $self->match_or_die( $self->ok_cmd( 'git', '-C', $remote, 'notes', '--ref=refs/notes/ai', 'show', $sha )->{out}, qr/AI-Agent: Claude/, 'the remote holds the AI note' );
    my $two = clone_project( $self, 'two', $remote );
    $self->in_dir( $two, sub { $self->ok_cmd( 'aapp', 'note', 'pull' ) } );
    return ( $one, $two, $sha );
}

sub test_note_push_pull_union_merge
{
    my ($self) = @_;
    my ( $one, $two, $sha ) = shared_notes($self);
    $self->in_dir(
        $two,
        sub {
            $self->match_or_die( note_of( $self, 'ai', $sha ), qr/AI-Agent: Claude/, 'pull brings the note' );
            $self->in_dir(
                $one,
                sub {
                    $self->ok_cmd( 'git', 'notes', '--ref=refs/notes/ai', 'append', '-m', 'Note from one', $sha );
                    $self->ok_cmd( 'aapp', 'note', 'push' );
                }
            );
            $self->ok_cmd( 'git', 'notes', '--ref=refs/notes/ai', 'append', '-m', 'Note from two', $sha );
            $self->ok_cmd( 'aapp', 'note', 'pull' );
            my $note = note_of( $self, 'ai', $sha );
            $self->true_or_die( $note =~ /Note from one/ && $note =~ /Note from two/, 'diverging AI notes merge by union', $note );
        }
    );
    return 1;
}

sub test_note_pull_manual_conflict_fails_closed
{
    my ($self) = @_;
    my ( $one, $two, $sha ) = shared_notes($self);
    $self->in_dir(
        $two,
        sub {
            $self->ok_cmd( 'git', 'config', 'notes.commits.mergeStrategy', 'manual' );
            $self->in_dir(
                $one,
                sub {
                    $self->ok_cmd( 'git', 'notes', '--ref=refs/notes/commits', 'append', '-m', 'First party text', $sha );
                    $self->ok_cmd( 'aapp', 'note', 'push' );
                }
            );
            $self->ok_cmd( 'git', 'notes', '--ref=refs/notes/commits', 'append', '-m', 'Conflicting second party text', $sha );
            my $r = $self->fail_cmd( 'aapp', 'note', 'pull' );
            $self->match_or_die( $r->{out} . $r->{err}, qr/conflict|git notes merge --commit/i, 'the refusal says how to resolve it' );
            $self->run_cmd( 'git', 'notes', 'merge', '--abort' );
        }
    );
    return 1;
}

sub test_note_audit_guard
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.aiNotesGuard',          'warn' );
    $self->ok_cmd( 'git', 'config', 'notes.ai.mergeStrategy', 'cat_sort_uniq' );
    my $r = $self->ok_cmd( 'aapp', 'note', 'status' );
    $self->match_or_die( $r->{out} . $r->{err}, qr/Audit Guard: Advisory Warning/, 'warn mode warns about a lossy strategy' );
    $self->ok_cmd( 'git', 'config', 'aapp.aiNotesGuard', 'enforce' );
    $r = $self->fail_cmd( 'aapp', 'note', 'status' );
    $self->match_or_die( $r->{out} . $r->{err}, qr/Audit Guard: ENFORCE Violation/, 'enforce mode refuses it' );
    $self->ok_cmd( 'git', 'config', 'notes.ai.mergeStrategy', 'union' );
    $self->ok_cmd( 'git', 'config', 'notes.rewriteMode',      'concatenate' );
    $r = $self->ok_cmd( 'aapp', 'note', 'status' );
    $self->true_or_die( ( $r->{out} . $r->{err} ) !~ /Audit Guard: ENFORCE Violation/, 'lossless settings pass' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
