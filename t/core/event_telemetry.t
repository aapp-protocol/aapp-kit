package AAPP::T::Core::EventTelemetry;

use strict;
use warnings;
use utf8;
use 5.026;

use Cwd ();
use File::Copy ();
use File::Path ();
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/event_telemetry.md. Run alone: prove -l t/core/event_telemetry.t

# The post-* events the sample logger is registered for.
our @EVENTS = qw(post-draft post-freeze post-start post-refine post-done post-abort post-active post-tdd
    post-commit post-land post-issue post-pause post-resume post-sync);

our $LOGGER   = '.agents/hooks/event-logger';
our $REGISTRY = '.agents/skills/aapp-hooks/registry.tsv';

# Usage     : fixture($self)
# Purpose   : An initialized project whose sample event logger is registered for every post-* event.
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    $self->init_project();
    $self->ok_cmd( 'git', 'add', '-A' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'init project', '--no-verify' );
    File::Path::make_path( '.agents/hooks', '.agents/skills/aapp-hooks' );
    File::Copy::copy( "$self->{kit}/examples/hooks/event-logger.sample", $LOGGER ) or die "cannot copy the event logger: $!\n";
    chmod( 0755, $LOGGER ) or die "cannot chmod $LOGGER: $!\n";
    my $lines = AAPP::Tests::read_text($REGISTRY);
    foreach my $event (@EVENTS) {
        my $out = $self->ok_cmd( 'aapp', 'hook-hash', $LOGGER, $event, '10', 'notify' )->{out};
        $lines .= join( '', map {"$_\n"} grep {/^\Q$event\E\t/} split( /\n/, $out ) );
    }
    AAPP::Tests::write_text( $REGISTRY, $lines );
    $self->ok_cmd( 'git', '-C', '.agents', 'add', '-A' );
    $self->ok_cmd( 'git', '-C', '.agents', 'commit', '-qm', 'chore: register test hooks', '--no-verify' );
    return 1;
}

# Usage     : my $file = log_file()
# Purpose   : Where the logger writes in this test: inside the copy's Git data, outside the work tree.
# Returns   : The absolute path.
sub log_file { return Cwd::getcwd() . '/.git/events.jsonl'; }

# Usage     : last_has($self, $step, @texts)
# Purpose   : The last envelope the logger recorded holds every text.
# Returns   : 1; dies naming the step and the missing text.
sub last_has
{
    my ( $self, $step, @texts ) = @_;
    my @lines = split( /\n/, AAPP::Tests::read_text( log_file() ) );
    my $last  = $lines[-1] // '';
    $self->true_or_die( index( $last, $_ ) >= 0, "$step: the envelope holds $_", $last ) for @texts;
    return 1;
}

# Usage     : my ($id, $file) = drafted($slug)
# Purpose   : The id and file of the plan drafted under the slug.
# Returns   : (id, path); dies when there is none.
sub drafted
{
    my ($slug) = @_;
    my ($file) = glob(".plans/current/P*-$slug.md");
    die "no plan drafted as $slug\n" if !defined $file;
    my ($id) = AAPP::Tests::read_text($file) =~ /^\s*\*\s*\*\*Plan ID:\*\*\s*(\S+)/m;
    return ( $id, $file );
}

# Usage     : ready_to_freeze($file)
# Purpose   : Ticks every open question and leaves main.py as the plan's one Target File.
# Returns   : 1
sub ready_to_freeze
{
    my ($file) = @_;
    my $text = AAPP::Tests::read_text($file);
    $text =~ s/\* \[ \]/* [x]/g;
    $text =~ s/^(### 📂 Target Files[^\n]*\n).*?(?=^### 🛑)/$1- `main.py` -> Target file.\n/ms;
    AAPP::Tests::write_text( $file, $text );
    return 1;
}

sub test_plan_lifecycle_events
{
    my ($self) = @_;
    local $ENV{AAPP_LOG_FILE} = log_file();
    $self->ok_cmd( 'aapp', 'draft', 'telemetry-feature' );
    last_has( $self, 'draft', '"event": "post-draft"', '"command": "plan"', '"event": "draft"' );
    my ( $id, $file ) = drafted('telemetry-feature');
    $self->ok_cmd( 'aapp', 'active', $id );
    last_has( $self, 'active set', '"event": "post-active"', '"command": "plan"', '"action": "set"' );
    $self->ok_cmd( 'aapp', 'active', 'clear' );
    last_has( $self, 'active clear', '"action": "clear"' );
    $self->ok_cmd( 'aapp', 'draft', 'tdd-feature' );
    my ($tdd) = drafted('tdd-feature');
    $self->ok_cmd( 'aapp', 'tdd', $tdd );
    last_has( $self, 'tdd', '"event": "post-tdd"', '"command": "plan"', '"event": "tdd"' );
    $self->ok_cmd( 'aapp', 'plan', 'abort', $tdd, 'reason', 'tdd check complete', 'confirm' );
    last_has( $self, 'abort', '"event": "post-abort"', '"command": "plan"', '"event": "abort"' );
    ready_to_freeze($file);
    $self->ok_cmd( 'aapp', 'refine', $id, 'resolve questions and targets' );
    last_has( $self, 'refine', '"event": "post-refine"', '"command": "plan"', '"event": "refine"' );
    $self->ok_cmd( 'aapp', 'freeze', $id );
    last_has( $self, 'freeze', '"event": "post-freeze"', '"command": "plan"', '"event": "freeze"' );
    $self->ok_cmd( 'aapp', 'start', $id );
    last_has( $self, 'start', '"event": "post-start"', '"command": "plan"', '"event": "start"' );
    AAPP::Tests::write_text( 'main.py', AAPP::Tests::read_text('main.py') . "# app update\n" );
    $self->ok_cmd( 'git', 'add', 'main.py' );
    $self->ok_cmd( 'aapp', 'commit', 'feat: update main', 'agent', 'Antigravity', 'vendor', 'Google', 'model', 'gemini-3.8-flash' );
    last_has( $self, 'commit', '"event": "post-commit"', '"command": "commit"', '"agent": "Antigravity"' );
    $self->ok_cmd( 'aapp', 'done', $id );
    last_has( $self, 'done', '"event": "post-done"', '"command": "plan"', '"event": "done"' );
    return 1;
}

sub test_issue_lifecycle_events
{
    my ($self) = @_;
    local $ENV{AAPP_LOG_FILE} = log_file();
    File::Path::make_path('src');
    AAPP::Tests::write_text( 'src/issue1.txt', '' );
    $self->ok_cmd( 'git', 'add', 'src/issue1.txt' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'feat: add issue1 file', '--no-verify' );
    $self->ok_cmd( 'aapp', 'issue', 'log', 'Medium', 'CLI', 'Telemetry issue symptom', 'file', 'src/issue1.txt' );
    last_has( $self, 'log', '"event": "post-issue"', '"command": "issue"', '"event": "log"' );
    $self->ok_cmd( 'aapp', 'issue', 'queue', '1', 'urgent' );
    last_has( $self, 'queue', '"command": "issue"', '"event": "queue"', '"level": "urgent"' );
    $self->ok_cmd( 'aapp', 'issue', 'queue', '1', 'remove' );
    last_has( $self, 'unqueue', '"command": "issue"', '"event": "unqueue"' );
    $self->ok_cmd( 'aapp', 'issue', 'queue', '1' );
    $self->ok_cmd( 'aapp', 'issue', 'fix', '1' );
    last_has( $self, 'fix', '"command": "issue"', '"event": "fix"' );
    $self->in_dir(
        '.workspace/fix-1',
        sub {
            AAPP::Tests::write_text( 'src/issue1.txt', "# fix 1\n" );
            $self->ok_cmd( 'git', 'add', 'src/issue1.txt' );
            $self->ok_cmd( 'aapp', 'commit', 'fix: fix issue 1', 'changelog', 'fixed telemetry issue' );
        }
    );
    $self->ok_cmd( 'aapp', 'issue', 'close', '1' );
    last_has( $self, 'close', '"command": "issue"', '"event": "close"' );
    $self->ok_cmd( 'aapp', 'issue', 'log', 'Low', 'CLI', 'Withdrawn issue symptom' );
    $self->ok_cmd( 'aapp', 'issue', 'abort', '2', 'reason', 'Not needed', 'confirm' );
    last_has( $self, 'withdraw', '"command": "issue"', '"event": "withdraw"' );
    return 1;
}

sub test_pause_resume_events
{
    my ($self) = @_;
    local $ENV{AAPP_LOG_FILE} = log_file();
    $self->ok_cmd( 'aapp', 'pause', 'switching tasks' );
    last_has( $self, 'pause', '"event": "post-pause"', '"command": "pause"', '"event": "pause"' );
    $self->ok_cmd( 'aapp', 'resume' );
    last_has( $self, 'resume', '"event": "post-resume"', '"command": "pause"', '"event": "resume"' );
    return 1;
}

sub test_sync_event
{
    my ($self) = @_;
    local $ENV{AAPP_LOG_FILE} = log_file();
    my $remote = Cwd::getcwd() . '/.git/remote.git';
    $self->ok_cmd( 'git', 'init', '-q', '--bare', $remote );
    $self->ok_cmd( 'git', 'remote', 'add', 'origin', $remote );
    foreach my $wt (qw(.plans .agents .githooks)) {
        $self->ok_cmd( 'git', '-C', $wt, 'remote', 'add', 'origin', $remote ) if $self->run_cmd( 'git', '-C', $wt, 'remote', 'get-url', 'origin' )->{exit} != 0;
        $self->ok_cmd( 'git', '-C', $wt, 'push', '-q', '-u', 'origin', 'HEAD' );
    }
    $self->ok_cmd( 'git', 'push', '-q', '-u', 'origin', 'HEAD' );
    $self->ok_cmd( 'aapp', 'sync', 'origin' );
    last_has( $self, 'sync', '"event": "post-sync"', '"command": "sync"', '"event": "sync"' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
