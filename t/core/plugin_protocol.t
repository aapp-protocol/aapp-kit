package AAPP::T::Core::PluginProtocol;

use strict;
use warnings;
use utf8;
use 5.026;

use Cwd ();
use File::Path ();
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/plugin_protocol.md. Run alone: prove -l t/core/plugin_protocol.t

our $PDIR    = '.agents/skills/aapp-issue-tracker';
our $ARCHIVE = '.plans/done/000-issues-archive.md';

# Usage     : fixture($self)
# Purpose   : A project with issues #10 to #14 logged and queued, the next id 15, and the tracker's folder.
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    $self->init_project();
    $self->ok_cmd( 'git', 'config', 'aapp.issueFixWait', '0' );
    AAPP::Tests::write_text( '.plans/ISSUES.md', <<'EOF' );
# Issues

| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #10 | `Low` | `CLI` | 2026-09-01 | `a.sh` | First defect. |  | 🟡 `Incubated` |
| #11 | `Medium` | `CORE` | 2026-09-02 | `b.sh` | Second defect. |  | 🟡 `Incubated` |
| #12 | `Low` | `CORE` | 2026-09-03 | `c.sh` | Third defect. |  | 🟡 `Incubated` |
| #13 | `Low` | `CORE` | 2026-09-04 | `d.sh` | Fourth defect. |  | 🟡 `Incubated` |
| #14 | `Low` | `CORE` | 2026-09-05 | `e.sh` | Fifth defect. |  | 🟡 `Incubated` |
EOF
    AAPP::Tests::write_text( '.plans/issues_road_map.md', <<'EOF' );
# Board

## 📋 Queued
- [ ] #10 -> First defect.
- [ ] #11 -> Second defect.
- [ ] #12 -> Third defect.
- [ ] #13 -> Fourth defect.
- [ ] #14 -> Fifth defect.
EOF
    $self->ok_cmd( 'git', '-C', '.plans', 'add', '-A' );
    $self->ok_cmd( 'git', '-C', '.plans', 'commit', '-qm', 'test: ledger fixture' );
    $self->ok_cmd( 'git', 'config', 'aapp.issueId', '15' );
    File::Path::make_path($PDIR);
    return 1;
}

# Usage     : plugin(@lines)
# Purpose   : Installs the tracker's run script: a POSIX shell script of the given lines.
# Returns   : 1
sub plugin
{
    my (@lines) = @_;
    AAPP::Tests::write_text( "$PDIR/run", join( "\n", '#!/bin/sh', @lines ) . "\n" );
    chmod( 0755, "$PDIR/run" ) or die "cannot chmod $PDIR/run: $!\n";
    return 1;
}

# Usage     : my $sha = short_head($self)
# Purpose   : The project's HEAD, as a close names its fix commit.
# Returns   : The 7-character SHA.
sub short_head { my ($self) = @_; return $self->ok_cmd( 'git', 'rev-parse', '--short=7', 'HEAD' )->{out} =~ s/\s+\z//r; }

# Usage     : my $yes = archived($id)
# Purpose   : Whether the archive holds #<id>'s row.
# Returns   : 1 or ''.
sub archived { my ($id) = @_; return AAPP::Tests::read_text($ARCHIVE) =~ /^\| #\Q$id\E \|/m ? 1 : ''; }

# Usage     : my $here = here($name)
# Purpose   : A scratch file of this test, inside the copy's Git data.
# Returns   : The absolute path.
sub here { my ($name) = @_; return Cwd::getcwd() . "/.git/$name"; }

# Usage     : my ($facts, @list) = lib_step($self, @plugin_lines)
# Purpose   : Installs the plugin, runs one issue.log step through plugin_step in one shell, and reads
#             what it left: its exit, PLUGIN_STATUS, whether 'note' and 'id' are handled, the list lines.
# Returns   : ('rc=<n> status=<s> note=<yes|no> id=<yes|no> list=<n>', list lines).
sub lib_step
{
    my ( $self, @lines ) = @_;
    plugin(@lines);
    my $root   = Cwd::getcwd();
    my $script = <<'EOF';
set +e
plugin_step "$STEP_RUN" "$REPO_ROOT" log issue.log '{"symptom": "x"}' >/dev/null 2>"$STEP_ERR"; rc=$?
h_note=no; plugin_handled note && h_note=yes
h_id=no; plugin_handled id && h_id=yes
echo "rc=$rc status=${PLUGIN_STATUS:-} note=$h_note id=$h_id list=$(plugin_list_lines 2>/dev/null | wc -l | tr -d ' ')"
plugin_list_lines 2>/dev/null | sed 's/^/L:/'
EOF
    local $ENV{REPO_ROOT} = $root;
    local $ENV{STEP_RUN}  = "$root/$PDIR/run";
    local $ENV{STEP_ERR}  = here('step.err');
    my @out = @{ $self->lib_call( 'hook_dispatcher', 'eval', $script )->{ret} };
    my $facts = shift(@out) // '';
    return ( $facts, map { s/^L://r } @out );
}

sub test_message_is_shown
{
    my ($self) = @_;
    plugin( 'cat >/dev/null', 'echo \'{"status": "ok", "message": "Ticket 10 closed on the tracker"}\'' );
    my $r = $self->ok_cmd( 'aapp', 'issue', 'close', '10', 'sha', short_head($self), 'summary', 'Fixed.' );
    $self->match_or_die( $r->{out} . $r->{err}, qr/Ticket 10 closed on the tracker/, 'the message is shown' );
    return 1;
}

sub test_unnamed_part_left_to_kit
{
    my ($self) = @_;
    my ($named) = lib_step( $self, 'cat >/dev/null', 'echo \'{"status": "ok", "handled": "id", "id": "PROJ-1"}\'' );
    $self->eq_or_die( $named, 'rc=0 status=ok note=no id=yes list=0', 'only the named part is taken over' );
    my ($bare) = lib_step( $self, 'cat >/dev/null', 'echo \'{"id": "PROJ-1"}\'' );
    $self->eq_or_die( $bare, 'rc=0 status=ok note=no id=no list=0', 'without handled all is left to the kit' );
    return 1;
}

sub test_declined_leaves_all_to_kit
{
    my ($self) = @_;
    my ($facts) = lib_step( $self, 'cat >/dev/null', 'echo \'{"status": "declined", "handled": "id, note"}\'' );
    $self->eq_or_die( $facts, 'rc=0 status=declined note=no id=no list=0', 'declined leaves every part' );
    return 1;
}

sub test_newer_version_refused
{
    my ($self) = @_;
    my ($newer) = lib_step( $self, 'cat >/dev/null', 'echo \'{"version": "9.0", "status": "ok", "handled": "id"}\'' );
    $self->match_or_die( $newer, qr/^rc=[1-9]/, 'a newer version is refused' );
    $self->match_or_die( $newer, qr/id=no/,     'and takes nothing over' );
    my ($current) = lib_step( $self, 'cat >/dev/null', 'echo \'{"version": "1.0", "status": "ok", "handled": "id"}\'' );
    $self->eq_or_die( $current, 'rc=0 status=ok note=no id=yes list=0', 'the current version is accepted' );
    return 1;
}

sub test_list_file_read_per_line
{
    my ($self) = @_;
    my ( $facts, @list ) = lib_step( $self, 'cat >/dev/null',
        'printf "%s\n" \'{"id": "#7", "symptom": "one"}\' \'{"id": "#8", "symptom": "two"}\' > "$AAPP_PLUGIN_LIST"',
        'echo \'{"status": "ok", "handled": "list"}\'' );
    $self->match_or_die( $facts, qr/list=2/, 'two list lines' );
    $self->eq_or_die( "@list", '{"id": "#7", "symptom": "one"} {"id": "#8", "symptom": "two"}', 'each line one item' );
    return 1;
}

sub test_do_list_runs_accepted_commands_in_order
{
    my ($self) = @_;
    my $calls = here('calls');
    AAPP::Tests::write_text( $calls, '' );
    plugin( 'cat >/dev/null', qq{echo call >> "$calls"},
        q{printf "%s\n" 'issue close 12 summary "closed on the tracker"' 'draft sneaky-plan' 'issue abort 13 reason "won'"'"'t fix: superseded"' > "$AAPP_PLUGIN_DO"},
        'echo \'{"status": "ok"}\'' );
    my $r   = $self->ok_cmd( 'aapp', 'issue', 'close', '11', 'sha', short_head($self), 'summary', 'Fixed.' );
    my @out = split( /\n/, $r->{out} . $r->{err} );
    my %at;
    foreach my $i ( 0 .. $#out ) {
        $at{handed} //= $i if $out[$i] =~ /handed to aapp-issue-tracker/;
        $at{12}     //= $i if $out[$i] =~ /#12 archived/;
        $at{13}     //= $i if $out[$i] =~ /#13 withdrawn/;
    }
    $self->true_or_die( archived($_), "#$_ is archived" ) for qw(11 12 13);
    $self->true_or_die( defined $at{handed} && defined $at{12} && defined $at{13} && $at{handed} < $at{12} && $at{12} < $at{13},
        'the do list runs after the step, in order', join( "\n", @out ) );
    $self->true_or_die( index( AAPP::Tests::read_text($ARCHIVE), '| `aborted` |' ) >= 0, '#13 is archived as aborted' );
    my $text = join( "\n", @out );
    $self->true_or_die( index( $text, 'draft sneaky-plan' ) >= 0 && $text =~ /not an accepted/i, 'the unlisted command is refused by name', $text );
    $self->true_or_die( !glob('.plans/current/*sneaky*'), 'the unlisted command did not run' );
    $self->eq_or_die( scalar( split( /\n/, AAPP::Tests::read_text($calls) ) ), 1, 'the plugin is called once' );
    return 1;
}

sub test_write_verb_refused_inside_plugin
{
    my ($self) = @_;
    my ( $inner, $read ) = ( here('inner.out'), here('inner.read') );
    my $sha = short_head($self);
    plugin( 'cat >/dev/null', '[ -n "$INNER" ] && { echo \'{"status": "ok"}\'; exit 0; }; export INNER=1',
        qq{aapp issue close 14 sha $sha summary direct > "$inner" 2>&1; echo "rc=\$?" >> "$inner"},
        qq{aapp issue list > "$read" 2>&1; echo "rc=\$?" >> "$read"},
        'echo \'{"status": "ok"}\'' );
    AAPP::Tests::write_text( '.plans/ISSUES.md',
        AAPP::Tests::read_text('.plans/ISSUES.md') . "| #20 | `Low` | `CORE` | 2026-09-06 | `f.sh` | Sixth defect. |  | 🟡 `Incubated` |\n" );
    AAPP::Tests::write_text( '.plans/issues_road_map.md', AAPP::Tests::read_text('.plans/issues_road_map.md') . "- [ ] #20 -> Sixth defect.\n" );
    $self->ok_cmd( 'git', 'config', 'aapp.issueId', '21' );
    $self->ok_cmd( 'git', '-C', '.plans', 'add', '-A' );
    $self->ok_cmd( 'git', '-C', '.plans', 'commit', '-qm', 'test: one more' );
    $self->run_cmd( 'aapp', 'issue', 'close', '20', 'sha', $sha, 'summary', 'Fixed.' );
    my $in = AAPP::Tests::read_text($inner);
    $self->match_or_die( $in, qr/^rc=[1-9]/m,                'the writing verb exits non-zero' );
    $self->match_or_die( $in, qr/AAPP_PLUGIN_DO|do list/,     'it points to the do list' );
    $self->true_or_die( !archived(14), 'the writing verb changed nothing' );
    my $rd = AAPP::Tests::read_text($read);
    $self->match_or_die( $rd, qr/^rc=0/m, 'the reading verb runs' );
    $self->match_or_die( $rd, qr/#14/,    'and lists the issues' );
    return 1;
}

sub test_timeout_ends_plugin
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.pluginTimeout', '1' );
    plugin( 'cat >/dev/null', 'sleep 5', 'echo \'{"status": "ok"}\'' );
    my $t0 = time();
    my $r  = $self->ok_cmd( 'aapp', 'issue', 'close', '14', 'sha', short_head($self), 'summary', 'Fixed.' );
    my $secs = time() - $t0;
    $self->true_or_die( archived(14), 'the step completes' );
    $self->true_or_die( $secs < 5,    'the plugin is stopped', "$secs s" );
    $self->match_or_die( $r->{out} . $r->{err}, qr/aapp-issue-tracker failed/, 'it is reported as failed' );
    return 1;
}

sub test_envelope_carries_no_secret
{
    my ($self) = @_;
    my ( $stdin, $vars ) = ( here('env.stdin'), here('env.vars') );
    $self->ok_cmd( 'git', 'remote', 'add', 'origin', 'https://bot:s3cret@example.com/acme/app.git' );
    lib_step( $self, qq{cat > "$stdin"; env > "$vars"}, 'echo \'{"status": "ok"}\'' );
    my ( $in, $env ) = ( AAPP::Tests::read_text($stdin), AAPP::Tests::read_text($vars) );
    $self->match_or_die( $in, qr{"url": "https://example\.com/acme/app\.git"}, 'the envelope names the remote without credentials' );
    $self->true_or_die( index( $in,  's3cret' ) < 0, 'no secret in the envelope' );
    $self->true_or_die( index( $env, 's3cret' ) < 0, 'no secret in the environment' );
    $self->match_or_die( $env, qr/^AAPP_PLUGIN_DO=/m,   'the do file path' );
    $self->match_or_die( $env, qr/^AAPP_PLUGIN_LIST=/m, 'the list file path' );
    return 1;
}

sub test_sample_issue_tracker_queue_events
{
    my ($self) = @_;
    my $run   = "$self->{kit}/examples/plugins/aapp-issue-tracker/run.sample";
    my $store = here('sample_tracker.tsv');
    local $ENV{AAPP_SAMPLE_TRACKER_FILE} = $store;
    my $step = sub {
        my ( $name, $json ) = @_;
        local $ENV{AAPP_PLUGIN_STEP} = $name;
        return $self->ok_cmd( { stdin => "$json\n" }, 'sh', $run )->{out};
    };
    my $state = sub {
        my ($id) = @_;
        my ($line) = grep { index( $_, $id ) == 0 } split( /\n/, AAPP::Tests::read_text($store) );
        return ( split( /\t/, $line // '' ) )[1] // '';
    };
    my ($id) = $step->( 'issue.log', '{"data":{"sev":"Low","type":"CLI","date":"2026-10-16","location":"foo.sh","symptom":"bar"}}' ) =~ /"id": *"([^"]+)"/;
    $self->true_or_die( defined $id, 'the sample logs the issue' );
    $self->match_or_die( $step->( 'issue.queue', qq{{"data":{"id":"$id"}}} ), qr/"status": *"ok"/, 'issue.queue answers ok' );
    $self->eq_or_die( $state->($id), 'queued', 'the issue is marked queued' );
    $self->match_or_die( $step->( 'issue.unqueue', qq{{"data":{"id":"$id"}}} ), qr/"status": *"ok"/, 'issue.unqueue answers ok' );
    $self->eq_or_die( $state->($id), 'open', 'the issue is open again' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
