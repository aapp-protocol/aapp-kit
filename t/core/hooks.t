package AAPP::T::Core::Hooks;

use strict;
use warnings;
use utf8;
use 5.026;

use Cwd ();
use Digest::SHA ();
use File::Copy ();
use File::Path ();
use AAPP::JSON ();
use AAPP::Tests ();
use AAPP::HookDispatcher ();

# Each test_<name> sub is described by its line in lib/docs/core/hooks.md. Run alone: prove -l t/core/hooks.t

our $REGISTRY = '.agents/skills/aapp-hooks/registry.tsv';
our $DELIM    = '==========================';

# Usage     : fixture($self)
# Purpose   : An initialized project with the hook registry's folder.
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    $self->init_project();
    File::Path::make_path('.agents/skills/aapp-hooks');
    return 1;
}

# Usage     : my $path = script($name, $body, $dir)
# Purpose   : Writes an executable script (in $dir, default the project) from its body.
# Returns   : The absolute path.
sub script
{
    my ( $name, $body, $dir ) = @_;
    my $path = ( $dir // Cwd::getcwd() ) . "/$name";
    AAPP::Tests::write_text( $path, $body );
    chmod( 0755, $path ) or die "cannot chmod $path: $!\n";
    return $path;
}

# Usage     : my $hex = sha_of($path)
# Purpose   : A file's SHA-256, as the registry records it.
# Returns   : The hex digest.
sub sha_of { my ($path) = @_; return Digest::SHA->new(256)->addfile( $path, 'b' )->hexdigest; }

# Usage     : register([$event, $path, $timeout, $mode, @extra], ...)
# Purpose   : Writes the registry: one line per hook, its hash taken from the file now.
# Returns   : 1
sub register
{
    my (@rows) = @_;
    my $text = '';
    foreach my $row (@rows) {
        my ( $event, $path, $timeout, $mode, @extra ) = @{$row};
        $text .= join( "\t", $event, $path, 'sha256:' . sha_of($path), $timeout, $mode, @extra ) . "\n";
    }
    AAPP::Tests::write_text( $REGISTRY, $text );
    return 1;
}

# Usage     : my $r = hook_test($self, @args)
# Purpose   : Runs aapp hook-test.
# Returns   : { exit, out, err, all } with all the two streams together.
sub hook_test { my ( $self, @args ) = @_; return both( $self->run_cmd( 'aapp', 'hook-test', @args ) ); }

# Usage     : my $r = both($r)
# Purpose   : Adds 'all': stdout and stderr together.
# Returns   : The result.
sub both { my ($r) = @_; $r->{all} = $r->{out} . $r->{err}; return $r; }

# Usage     : my $all = aapp_all($self, @args)
# Purpose   : Runs aapp and gives its two streams together.
# Returns   : The text.
sub aapp_all { my ( $self, @args ) = @_; return both( $self->run_cmd( 'aapp', @args ) )->{all}; }

# The hooks the exit-code tests register.
sub pass_hook { return script( 'hook_pass.sh', "#!/bin/sh\nINPUT=\"\$(cat)\"\necho \"PASS_HOOK: event=\$AAPP_EVENT mode=\$AAPP_MODE plan=\$AAPP_PLAN_ID\"\necho \"PAYLOAD: \$INPUT\"\nexit 0\n" ); }
sub fail_hook { return script( 'hook_fail.sh', "#!/bin/sh\necho \"Quality gate rejected transition: unlisted fallback detected\" >&2\nexit 1\n" ); }
sub warn_hook { return script( 'hook_warn.sh', "#!/bin/sh\necho \"Advisory warning from hook\" >&2\nexit 2\n" ); }
sub slow_hook { return script( 'hook_slow.sh', "#!/bin/sh\nsleep 5\nexit 0\n" ); }
sub veto_hook { return script( 'hook_veto.sh', "#!/bin/sh\necho \"Pre-mutation gate veto: quality policy violation\" >&2\nexit 1\n" ); }

# Usage     : tools()
# Purpose   : Two action plugins: tool-bin (extensionless run, with help and SKILL.md) and tool-pl (a Perl script).
# Returns   : 1
sub tools
{
    File::Path::make_path( '.agents/skills/tool-bin', '.agents/skills/tool-pl/scripts' );
    script( 'run', <<'EOF', Cwd::getcwd() . '/.agents/skills/tool-bin' );
#!/bin/sh
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "help" ]; then
  echo "Usage: aapp tool-bin [options]"
  exit 0
fi
echo "EXEC_TOOL_BIN: args=$* root=${AAPP_REPO_ROOT:-missing}"
exit 0
EOF
    AAPP::Tests::write_text( '.agents/skills/tool-bin/SKILL.md',
        "---\nname: tool-bin\ndescription: Binary execution tool for unit tests.\n---\n# Tool Bin\nFull documentation for tool-bin.\n" );
    script( 'tool-pl.pl', "#!/usr/bin/env perl\nprint 'EXEC_TOOL_PL: args=' . join( ' ', \@ARGV ) . \"\\n\";\n", Cwd::getcwd() . '/.agents/skills/tool-pl/scripts' );
    return 1;
}

sub test_hook_hash_formats_registry_line
{
    my ($self) = @_;
    my $file = script( 'test_script.sh', "echo \"hello\"\n" );
    my $sha  = AAPP::HookDispatcher::compute_file_sha256($file) =~ s/\s+\z//r;
    $self->match_or_die( $sha, qr/^[0-9a-f]{64}$/, 'compute_file_sha256 gives a 64-character hash' );
    $self->eq_or_die( $sha, sha_of($file), 'the SHA-256 of the file' );
    my $out = aapp_all( $self, 'hook-hash', 'test_script.sh', 'pre-freeze', '25', 'gate' );
    $self->match_or_die( $out, qr/^pre-freeze\ttest_script\.sh\tsha256:\Q$sha\E\t25\tgate$/m, 'hook-hash prints the five-column line' );
    return 1;
}

sub test_gate_hook_receives_envelope_and_environment
{
    my ($self) = @_;
    register( [ 'pre-freeze', pass_hook(), 10, 'gate' ] );
    my $r = hook_test( $self, 'pre-freeze', 'P-99' );
    $self->eq_or_die( $r->{exit}, 0, 'the step proceeds' );
    $self->match_or_die( $r->{all}, qr/PASS_HOOK: event=pre-freeze mode=gate plan=P-99/, 'the event is in the environment' );
    $self->match_or_die( $r->{all}, qr/PAYLOAD: \{/,                                     'the envelope arrives on stdin' );
    return 1;
}

sub test_tampered_hook_aborts
{
    my ($self) = @_;
    my $hook = pass_hook();
    register( [ 'pre-freeze', $hook, 10, 'gate' ] );
    AAPP::Tests::write_text( $hook, AAPP::Tests::read_text($hook) . "echo \"tampered\"\n" );
    my $r = hook_test( $self, 'pre-freeze' );
    $self->true_or_die( $r->{exit} != 0, 'the step aborts' );
    $self->match_or_die( $r->{all}, qr/SHA256 mismatch/, 'naming the integrity violation' );
    return 1;
}

sub test_gate_hook_failure_halts
{
    my ($self) = @_;
    register( [ 'pre-freeze', fail_hook(), 10, 'gate' ] );
    my $r = hook_test( $self, 'pre-freeze' );
    $self->true_or_die( $r->{exit} != 0, 'the step halts' );
    $self->match_or_die( $r->{all}, qr/Quality gate rejected transition/, "the hook's stderr is shown" );
    return 1;
}

sub test_notify_hook_failure_warns
{
    my ($self) = @_;
    register( [ 'pre-freeze', fail_hook(), 10, 'notify' ] );
    my $r = hook_test( $self, 'pre-freeze' );
    $self->eq_or_die( $r->{exit}, 0, 'the step proceeds' );
    $self->match_or_die( $r->{all}, qr/Quality gate rejected transition/, 'with the warning' );
    return 1;
}

sub test_exit_two_warns_in_gate_mode
{
    my ($self) = @_;
    register( [ 'pre-freeze', warn_hook(), 10, 'gate' ] );
    my $r = hook_test( $self, 'pre-freeze' );
    $self->eq_or_die( $r->{exit}, 0, 'the step proceeds' );
    $self->match_or_die( $r->{all}, qr/Advisory warning from hook/, 'with the warning' );
    return 1;
}

sub test_watchdog_timeout
{
    my ($self) = @_;
    my $slow = slow_hook();
    register( [ 'pre-freeze', $slow, 1, 'gate' ] );
    my $r = hook_test( $self, 'pre-freeze' );
    $self->true_or_die( $r->{exit} != 0, 'a gate past its timeout halts' );
    $self->match_or_die( $r->{all}, qr/exceeded timeout/, 'naming the timeout' );
    register( [ 'pre-freeze', $slow, 1, 'notify' ] );
    $r = hook_test( $self, 'pre-freeze' );
    $self->eq_or_die( $r->{exit}, 0, 'a notify hook past its timeout warns' );
    $self->match_or_die( $r->{all}, qr/exceeded timeout/, 'naming the timeout' );
    return 1;
}

sub test_malformed_registry_line_refused
{
    my ($self) = @_;
    register( [ 'pre-freeze', warn_hook(), 10, 'gate', 'unexpected_6th_field' ] );
    my $r = hook_test( $self, 'pre-freeze' );
    $self->true_or_die( $r->{exit} != 0, 'the line is refused' );
    $self->match_or_die( $r->{all}, qr/unexpected 6th field/, 'naming the sixth field' );
    return 1;
}

sub test_local_config_hooks
{
    my ($self) = @_;
    AAPP::Tests::write_text( $REGISTRY, "\n" );
    $self->ok_cmd( 'git', 'config', '--add', 'aapp.hook.post-done', fail_hook() );
    my $r = hook_test( $self, 'post-done' );
    $self->eq_or_die( $r->{exit}, 0, 'a local hook cannot gate' );
    $self->match_or_die( $r->{all}, qr/Quality gate rejected transition/, 'but runs, in notify mode' );
    $self->ok_cmd( 'git', 'config', 'aapp.allowLocalHooks', 'false' );
    $self->true_or_die( hook_test( $self, 'post-done' )->{all} !~ /Quality gate rejected transition/, 'aapp.allowLocalHooks false turns them off' );
    return 1;
}

sub test_hooks_inspector_audits_hashes
{
    my ($self) = @_;
    register( [ 'pre-freeze', pass_hook(), 10, 'gate' ] );
    my $out = aapp_all( $self, 'hooks' );
    $self->match_or_die( $out, qr/pre-freeze/, 'the hook is listed' );
    $self->match_or_die( $out, qr/VALID/,      'with its hash check' );
    return 1;
}

sub test_plugins_inspector_discovers_plugins
{
    my ($self) = @_;
    tools();
    my $out = aapp_all( $self, 'plugins' );
    $self->match_or_die( $out, qr/tool-bin/, 'the extensionless plugin' );
    $self->match_or_die( $out, qr/tool-pl/,  'the Perl plugin' );
    return 1;
}

sub test_action_plugin_fallthrough
{
    my ($self) = @_;
    tools();
    my $root = Cwd::getcwd();
    $self->match_or_die( aapp_all( $self, 'tool-bin', 'foo', 'bar' ), qr/EXEC_TOOL_BIN: args=foo bar root=\Q$root\E/, 'aapp <plugin> runs it with AAPP_REPO_ROOT' );
    my $help = aapp_all( $self, 'help', 'tool-bin' );
    $self->match_or_die( $help, qr/Usage: aapp tool-bin \[options\]/,             'aapp help <plugin> shows its help' );
    $self->match_or_die( $help, qr/Full skill documentation: aapp help tool-bin full/, 'and points to the full text' );
    $self->match_or_die( aapp_all( $self, 'tool-bin', 'help' ), qr/Usage: aapp tool-bin \[options\]/, 'aapp <plugin> help shows its help' );
    $self->match_or_die( aapp_all( $self, 'help', 'tool-bin', 'full' ), qr/Full documentation for tool-bin/, 'help <plugin> full shows SKILL.md' );
    $self->match_or_die( aapp_all( $self, 'tool-pl', 'alpha', 'beta' ), qr/EXEC_TOOL_PL: args=alpha beta/, 'a plugin in another language runs' );
    return 1;
}

sub test_sample_plugins_never_run
{
    my ($self) = @_;
    File::Path::make_path('.agents/skills/sample-tool');
    my $dir = Cwd::getcwd() . '/.agents/skills/sample-tool';
    script( 'run.sample', "#!/bin/sh\necho \"SAMPLE_TOOL_SHOULD_NOT_RUN\"\n", $dir );
    $self->eq_or_die( AAPP::HookDispatcher::resolve_plugin_entrypoint( $dir, 'sample-tool' ) // '', '', 'run.sample is no entry point' );
    my $out = aapp_all( $self, 'sample-tool' );
    $self->true_or_die( $out !~ /SAMPLE_TOOL_SHOULD_NOT_RUN/, 'the sample does not run', $out );
    $self->match_or_die( $out, qr/Unknown command/, 'aapp refuses it' );
    return 1;
}

sub test_inspectors_show_samples
{
    my ($self) = @_;
    AAPP::Tests::write_text( $REGISTRY,
        join( "\t", 'pre-freeze', 'examples/hooks/fallback-ratchet.sh.sample', 'sha256:' . ( '0' x 64 ), '10', 'gate' ) . "\n" );
    my $hooks = aapp_all( $self, 'hooks' );
    $self->match_or_die( $hooks, qr/INERT SAMPLE/,                     'a registered sample is marked inert' );
    $self->match_or_die( $hooks, qr/Hook Samples|Reference Samples/,  'aapp hooks shows the samples available' );
    my $plugins = aapp_all( $self, 'plugins' );
    $self->match_or_die( $plugins, qr/Kit Plugins/, 'aapp plugins shows the extension points' );
    $self->match_or_die( $plugins, qr/aapp-planid/, 'and the plugins available' );
    return 1;
}

sub test_plugin_registry_listing
{
    my ($self) = @_;
    my @names = map { ( split(/\t/) )[0] } grep { !/^#/ && /\S/ } split( /\n/, AAPP::Tests::read_text("$self->{kit}/lib/plugins.tsv") );
    File::Path::make_path('.agents/skills/aapp-deploy');
    script( 'run', "#!/bin/sh\necho deploy\n", Cwd::getcwd() . '/.agents/skills/aapp-deploy' );
    my $out   = aapp_all( $self, 'plugins' );
    my @lines = split( /\n/, $out );
    my ($kit_n)   = grep { $lines[$_] =~ /Kit Plugins/ } 0 .. $#lines;
    my ($delim_n) = grep { $lines[$_] eq $DELIM } 0 .. $#lines;
    my ($your_n)  = grep { $lines[$_] =~ /Your Plugins/ } 0 .. $#lines;
    $self->true_or_die( defined $kit_n && defined $delim_n && defined $your_n && $kit_n < $delim_n && $delim_n < $your_n
            && $lines[ $delim_n - 1 ] eq '' && $lines[ $delim_n + 1 ] eq '',
        'Kit Plugins, a blank line, the delimiter, a blank line, Your Plugins', $out );
    my $kit_part  = join( "\n", @lines[ 0 .. $delim_n ] );
    my $your_part = join( "\n", @lines[ $delim_n .. $#lines ] );
    foreach my $name (@names) {
        $self->true_or_die( index( $kit_part, "• $name " ) >= 0, "$name is listed under Kit Plugins", $out );
        $self->true_or_die( index( $your_part, "• $name " ) < 0, "$name is not listed under Your Plugins", $out );
    }
    my ($review) = grep { index( $_, '• aapp-review ' ) >= 0 } split( /\n/, $kit_part );
    $self->match_or_die( $review // '', qr/RESERVED \(planned, P-15\)/, 'a planned row is RESERVED' );
    $self->match_or_die( $your_part, qr/aapp-deploy uses the reserved aapp- prefix/, 'an unregistered aapp-* plugin is warned about' );
    $self->eq_or_die( scalar( () = $out =~ /uses the reserved aapp- prefix/g ), 1, 'kit skills without an entry point are not' );
    File::Path::remove_tree('.agents/skills/aapp-deploy');

    File::Path::make_path('.agents/skills/aapp-review');
    script( 'run', "#!/bin/sh\nexit 0\n", Cwd::getcwd() . '/.agents/skills/aapp-review' );
    ($review) = grep { index( $_, '• aapp-review ' ) >= 0 } split( /\n/, aapp_all( $self, 'plugins' ) );
    $self->match_or_die( $review // '', qr/ACTIVE.*reserved for P-15/, 'a reserved name installed early shows its state' );
    File::Path::remove_tree('.agents/skills/aapp-review');

    my $empty = Cwd::getcwd() . '/proj-no-plugins';
    File::Path::make_path($empty);
    my $empty_out = $self->in_dir( $empty, sub { $self->init_project(); aapp_all( $self, 'plugins' ) } );
    $self->true_or_die( grep( { $_ eq $DELIM } split( /\n/, $empty_out ) ) && $empty_out =~ /No plugins of your own installed/,
        'with no plugins of your own: the delimiter and the empty note', $empty_out );

    my $clone = Cwd::getcwd() . '/kit-no-registry';
    File::Path::make_path($clone);
    File::Copy::copy( "$self->{kit}/aapp", "$clone/aapp" ) or die "cannot copy aapp: $!\n";
    chmod( 0755, "$clone/aapp" ) or die "cannot chmod the clone's aapp: $!\n";
    AAPP::Tests::copy_tree( "$self->{kit}/$_", "$clone/$_" ) for qw(lib templates examples);
    unlink("$clone/lib/plugins.tsv") or die "cannot remove the registry: $!\n";
    my $r = $self->in_dir( $empty, sub { both( $self->run_cmd( "$clone/aapp", 'plugins' ) ) } );
    $self->true_or_die( $r->{exit} != 0, 'a missing plugins.tsv fails closed' );
    $self->match_or_die( $r->{all}, qr/plugins\.tsv/, 'naming the file' );
    return 1;
}

sub test_event_envelope
{
    my ($self) = @_;
    my $repo = Cwd::getcwd() . '/envelope-repo';
    File::Path::make_path($repo);
    $self->ok_cmd( 'git', 'init', '-q', $repo );
    $self->ok_cmd( 'git', '-C', $repo, 'remote', 'add', 'origin', 'https://bot:s3cret@example.com/acme/app.git' );
    local $ENV{REPO_ROOT} = $repo;
    my $envelope = sub {
        my @args = @_;
        return $self->in_dir( $repo, sub { AAPP::HookDispatcher::build_event_envelope(@args) } );
    };
    my $e = $envelope->( 'issue.close', '{"id": "#7"}' );
    $self->true_or_die( index( $e, '"remote": { "name": "origin", "url": "https://example.com/acme/app.git" }' ) >= 0, 'the remote without credentials', $e );
    $self->true_or_die( index( $e, 's3cret' ) < 0, 'no secret' );
    $self->match_or_die( $e, qr/^  "data": \{"id": "#7"\},$/m, 'the data as given' );
    $self->match_or_die( $e, qr/^  "extra": \{\}$/m,           'the reserved extra' );
    $self->ok_cmd( 'git', '-C', $repo, 'remote', 'remove', 'origin' );
    $e = $envelope->('post-done');
    $self->true_or_die( index( $e, '"remote": null' ) >= 0, 'no remote is null', $e );
    $self->match_or_die( $e, qr/^  "data": \{\},$/m, 'empty data is {}' );
    return 1;
}

sub test_pre_hooks_abort_with_no_change
{
    my ($self) = @_;
    my $veto = veto_hook();
    my $plan = '.plans/current/P90-pre-gate.md';
    File::Path::make_path('.plans/current');
    AAPP::Tests::write_text( $plan, <<'EOF' );
# 🗺️ Plan P-90: Pre Gate Test
* **Plan ID:** P-90
* **Status:** 🟣 Under Review
* **Commits:** none
* **Changelog:** Added: pre gate test

## 2. Technical Blueprint
Design details.

## 3. Implementation Steps
- [ ] Step 1

## 4. Blast Radius & System Boundaries
### 📂 Target Files
- [ ] `main.py`

## ❓ 5. Open Questions
* [x] Question 1 resolved

## 📦 6. Change Log
EOF
    $self->ok_cmd( 'git', '-C', '.plans', 'add', 'current/P90-pre-gate.md' );
    $self->ok_cmd( 'git', '-C', '.plans', 'commit', '-qm', 'add P-90' );
    my $head = sub { $self->ok_cmd( 'git', '-C', '.plans', 'rev-parse', 'HEAD' )->{out} };
    my $before = $head->();
    register( [ 'pre-freeze', $veto, 10, 'gate' ] );
    $self->true_or_die( $self->run_cmd( 'aapp', 'freeze', 'P-90' )->{exit} != 0, 'pre-freeze stops the freeze' );
    $self->eq_or_die( $head->(), $before, 'no plans commit' );
    $self->match_or_die( AAPP::Tests::read_text($plan), qr/Status.*🟣 Under Review/, 'the plan is unchanged' );

    AAPP::Tests::write_text( $plan, AAPP::Tests::read_text($plan) =~ s/🟣 Under Review/🔷 Frozen/r );
    $self->ok_cmd( 'git', '-C', '.plans', 'commit', '-qam', 'freeze P-90' );
    unlink('.git/aapp_active_plan');
    $self->ok_cmd( 'git', 'config', 'aapp.planWorktrees', 'off' );
    register( [ 'pre-start', $veto, 10, 'gate' ] );
    $self->true_or_die( $self->run_cmd( 'aapp', 'start', 'P-90' )->{exit} != 0, 'pre-start stops the start' );
    $self->true_or_die( !-e '.git/aapp_active_plan', 'no plan is bound' );
    $self->match_or_die( AAPP::Tests::read_text($plan), qr/Status.*🔷 Frozen/, 'the plan stays frozen' );

    AAPP::Tests::write_text( $REGISTRY, "\n" );
    $self->ok_cmd( 'aapp', 'start', 'P-90' );
    AAPP::Tests::write_text( 'main.py',      AAPP::Tests::read_text('main.py') . "# test\n" );
    AAPP::Tests::write_text( 'CHANGELOG.md', AAPP::Tests::read_text('CHANGELOG.md') . "- Added: test line\n" );
    $self->ok_cmd( 'git', 'add', 'main.py', 'CHANGELOG.md' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'code update' );
    my $sha = $self->ok_cmd( 'git', 'rev-parse', '--short', 'HEAD' )->{out} =~ s/\s+\z//r;
    AAPP::Tests::write_text( $plan, AAPP::Tests::read_text($plan) =~ s/Commits:.*/Commits: `$sha` (main)/r );
    $self->ok_cmd( 'git', '-C', '.plans', 'commit', '-qam', 'record commit' );
    register( [ 'pre-done', $veto, 10, 'gate' ] );
    $self->true_or_die( $self->run_cmd( 'aapp', 'done', 'P-90' )->{exit} != 0, 'pre-done stops done' );
    $self->file_exists_or_die($plan);
    $self->true_or_die( !-e '.plans/done/P90-pre-gate.md', 'nothing is archived' );

    $self->ok_cmd( 'git', 'remote', 'add', 'origin', 'https://example.com/repo.git' );
    register( [ 'pre-sync', $veto, 10, 'gate' ] );
    $self->ok_cmd( 'git', '-C', '.agents', 'add', '-A' );
    $self->ok_cmd( 'git', '-C', '.agents', 'commit', '-qm', 'register pre-sync' );
    my $r = both( $self->run_cmd( 'aapp', 'sync', 'origin' ) );
    $self->true_or_die( $r->{exit} != 0, 'pre-sync stops the sync' );
    $self->match_or_die( $r->{all}, qr/pre-sync/, 'naming the hook' );
    return 1;
}

# Usage     : tg_install($self, $command, $timeout)
# Purpose   : The sample test gate as the project's pre-done gate, running $command.
# Returns   : 1
sub tg_install
{
    my ( $self, $command, $timeout ) = @_;
    File::Path::make_path('.agents/hooks');
    my $sample = AAPP::Tests::read_text("$self->{kit}/examples/hooks/test-gate.sh.sample");
    $sample =~ s/^TEST_CMD=.*$/TEST_CMD='$command'/m;
    script( 'test-gate.sh', $sample, Cwd::getcwd() . '/.agents/hooks' );
    my $out = $self->ok_cmd( 'aapp', 'hook-hash', '.agents/hooks/test-gate.sh', 'pre-done', $timeout // 20, 'gate' )->{out};
    AAPP::Tests::write_text( $REGISTRY, join( '', map {"$_\n"} grep {/^pre-done\t/} split( /\n/, $out ) ) );
    return 1;
}

# Usage     : my $id = tg_plan($self, $name)
# Purpose   : A started plan with one recorded commit (src/<name>.sh).
# Returns   : Its id.
sub tg_plan
{
    my ( $self, $name ) = @_;
    my $num = $self->ok_cmd( 'git', 'config', 'aapp.planId' )->{out} =~ s/\s+\z//r;
    $self->ok_cmd( 'aapp', 'draft', $name );
    my ($file) = glob(".plans/current/P$num-*.md");
    my $text = AAPP::Tests::read_text($file);
    $text =~ s{src/path/to/file\.ext}{src/$name.sh}g;
    $text =~ s{^.*src/path/to/new_file\.ext.*\n}{}mg;
    $text =~ s/^\* \[ \] \*\*Question/* [x] **Question/mg;
    AAPP::Tests::write_text( $file, $text );
    $self->ok_cmd( 'git', '-C', '.plans', 'commit', '-qam', "prep P-$num" );
    $self->ok_cmd( 'aapp', 'freeze-start', "P-$num" );
    File::Path::make_path('src');
    AAPP::Tests::write_text( "src/$name.sh", "v=1\n" );
    $self->ok_cmd( 'git', 'add', "src/$name.sh" );
    $self->ok_cmd( 'aapp', 'commit', "feat: $name" );
    return "P-$num";
}

sub test_pre_done_test_gate_sample
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'add', '-A' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'track init files', '--no-verify' );
    my $archived = sub { my ($id) = @_; my ($n) = $id =~ /([0-9]+)/; return scalar glob(".plans/done/P$n-*.md"); };
    tg_install( $self, 'true' );
    my $id = tg_plan( $self, 'green' );
    my $r  = both( $self->run_cmd( 'aapp', 'done', $id ) );
    $self->true_or_die( $r->{exit} == 0 && $archived->($id), 'a passing command lets done archive', $r->{all} );
    $self->match_or_die( $r->{all}, qr/tests green/, 'saying so' );

    tg_install( $self, 'echo boom-output; exit 3' );
    $id = tg_plan( $self, 'red' );
    $r  = both( $self->run_cmd( 'aapp', 'done', $id ) );
    $self->true_or_die( $r->{exit} != 0 && !$archived->($id), 'a failing command refuses', $r->{all} );
    $self->match_or_die( $r->{all}, qr/boom-output/, 'with the output tail' );
    $self->match_or_die( $r->{all}, qr/exit 3/,      'and the status' );

    AAPP::Tests::write_text( 'src/red.sh', "v=2\n" );
    tg_install( $self, 'true' );
    $r = both( $self->run_cmd( 'aapp', 'done', $id ) );
    $self->ok_cmd( 'git', 'checkout', '-q', '--', 'src/red.sh' );
    $self->true_or_die( $r->{exit} != 0 && !$archived->($id), 'a dirty tracked file refuses', $r->{all} );
    $self->match_or_die( $r->{all}, qr/uncommitted/i, 'naming it' );

    tg_install( $self, '' );
    $r = both( $self->run_cmd( 'aapp', 'done', $id ) );
    $self->true_or_die( $r->{exit} != 0 && !$archived->($id), 'an unset command refuses', $r->{all} );
    $self->match_or_die( $r->{all}, qr/TEST_CMD/, 'with the instruction' );

    tg_install( $self, 'sleep 6', 2 );
    $r = both( $self->run_cmd( 'aapp', 'done', $id ) );
    $self->true_or_die( $r->{exit} != 0 && !$archived->($id), 'a timeout refuses', $r->{all} );
    return 1;
}

# Usage     : my ($id, $file, $flags) = refine_setup($self)
# Purpose   : A drafted plan, and pre-refine, on-refine and post-refine hooks: the first two fail while
#             <flags>/rf-veto or <flags>/rf-fail exists, the third copies its envelope to <flags>/rf-post.json.
# Returns   : (plan id, plan file, flags directory).
sub refine_setup
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'add', '-A' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'track init files', '--no-verify' );
    my $flags = Cwd::getcwd() . '/.git';
    my $dir   = Cwd::getcwd() . '/.agents/hooks';
    File::Path::make_path($dir);
    script( 'rf-pre.sh',  "#!/usr/bin/env bash\ncat > /dev/null\n[ ! -f \"$flags/rf-veto\" ]\n", $dir );
    script( 'rf-on.sh',   "#!/usr/bin/env bash\ncat > /dev/null\n[ ! -f \"$flags/rf-fail\" ]\n", $dir );
    script( 'rf-post.sh', "#!/usr/bin/env bash\ncat > \"$flags/rf-post.json\"\n", $dir );
    my $lines = '';
    foreach my $h ( [ 'rf-pre.sh', 'pre-refine', 'gate' ], [ 'rf-on.sh', 'on-refine', 'gate' ], [ 'rf-post.sh', 'post-refine', 'notify' ] ) {
        my $out = $self->ok_cmd( 'aapp', 'hook-hash', ".agents/hooks/$h->[0]", $h->[1], '10', $h->[2] )->{out};
        $lines .= join( '', map {"$_\n"} grep {/^\Q$h->[1]\E\t/} split( /\n/, $out ) );
    }
    AAPP::Tests::write_text( $REGISTRY, $lines );
    my $num = $self->ok_cmd( 'git', 'config', 'aapp.planId' )->{out} =~ s/\s+\z//r;
    $self->ok_cmd( 'aapp', 'draft', 'rf-plan' );
    my ($file) = glob(".plans/current/P$num-*.md");
    AAPP::Tests::write_text( $file, AAPP::Tests::read_text($file) . "* note one\n" );
    return ( "P-$num", $file, $flags );
}

sub test_pre_refine_gate_vetoes_the_refine
{
    my ($self) = @_;
    my ( $id, $file, $flags ) = refine_setup($self);
    my $head = $self->ok_cmd( 'git', '-C', '.plans', 'rev-parse', 'HEAD' )->{out};
    AAPP::Tests::write_text( "$flags/rf-veto", '' );
    my $r = both( $self->run_cmd( 'aapp', 'refine', $id, 'note one' ) );
    $self->true_or_die( $r->{exit} != 0, 'the refine is stopped' );
    $self->eq_or_die( $self->ok_cmd( 'git', '-C', '.plans', 'rev-parse', 'HEAD' )->{out}, $head, 'nothing is committed' );
    $self->match_or_die( $r->{all}, qr/pre-refine/, 'naming the hook' );
    return 1;
}

sub test_on_refine_failure_commits_nothing
{
    my ($self) = @_;
    my ( $id, $file, $flags ) = refine_setup($self);
    my $head = $self->ok_cmd( 'git', '-C', '.plans', 'rev-parse', 'HEAD' )->{out};
    AAPP::Tests::write_text( "$flags/rf-fail", '' );
    my $r = both( $self->run_cmd( 'aapp', 'refine', $id, 'note one' ) );
    $self->true_or_die( $r->{exit} != 0, 'the refine fails' );
    $self->eq_or_die( $self->ok_cmd( 'git', '-C', '.plans', 'rev-parse', 'HEAD' )->{out}, $head, 'nothing is committed' );
    $self->match_or_die( $r->{all}, qr/on-refine/, 'naming the handler' );
    return 1;
}

sub test_post_refine_receives_kind_and_commit
{
    my ($self) = @_;
    my ( $id, $file, $flags ) = refine_setup($self);
    $self->ok_cmd( 'aapp', 'refine', $id, 'note one' );
    my $sha = $self->ok_cmd( 'git', '-C', '.plans', 'rev-parse', '--short', 'HEAD' )->{out} =~ s/\s+\z//r;
    my $pj  = AAPP::Tests::read_text("$flags/rf-post.json");
    $self->true_or_die( index( $pj, qq{"plan_id": "$id"} ) >= 0, 'the plan id', $pj );
    $self->true_or_die( index( $pj, '"kind": "message"' ) >= 0,  'the kind',    $pj );
    $self->true_or_die( index( $pj, qq{"commit": "$sha"} ) >= 0, 'the commit',  $pj );
    $self->true_or_die( index( $pj, '"note one"' ) >= 0,         'the notes',   $pj );
    return 1;
}

sub test_event_logger_sample
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'add', '-A' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'init project', '--no-verify' );
    File::Path::make_path('.agents/hooks');
    File::Copy::copy( "$self->{kit}/examples/hooks/event-logger.sample", '.agents/hooks/event-logger' ) or die "cannot copy the logger: $!\n";
    chmod( 0755, '.agents/hooks/event-logger' ) or die "cannot chmod the logger: $!\n";
    my ($line) = grep {/^post-freeze\t/} split( /\n/, $self->ok_cmd( 'aapp', 'hook-hash', '.agents/hooks/event-logger', 'post-freeze', '10', 'notify' )->{out} );
    $self->match_or_die( $line // '', qr/^post-freeze\s+\.agents\/hooks\/event-logger\s+sha256:[0-9a-f]{64}\s+10\s+notify$/, 'the registration line' );
    AAPP::Tests::write_text( $REGISTRY, "$line\n" );
    my $log = $self->ok_cmd( 'git', 'rev-parse', '--git-path', 'aapp_events.jsonl' )->{out} =~ s/\s+\z//r;
    unlink($log);
    $self->run_cmd( 'aapp', 'hook-test', 'post-freeze', 'P-999' );
    my @lines = split( /\n/, AAPP::Tests::read_text($log) );
    $self->eq_or_die( scalar(@lines), 1, 'one line in the git dir by default' );
    my ( $rc, $event ) = AAPP::JSON::decode( $lines[0] // '' );
    $self->eq_or_die( ref($event) eq 'HASH' ? $event->{event} // '' : '', 'post-freeze', 'a JSON line naming the event' );
    $self->true_or_die( index( $lines[0], '"plan_id": "P-999"' ) >= 0, 'and the plan', $lines[0] // '' );
    my $custom = Cwd::getcwd() . '/.git/custom_events.jsonl';
    $self->ok_cmd( 'git', 'config', 'aapp.logFile', $custom );
    $self->run_cmd( 'aapp', 'hook-test', 'post-freeze', 'P-888' );
    $self->true_or_die( index( AAPP::Tests::read_text($custom), '"plan_id": "P-888"' ) >= 0, 'aapp.logFile names the destination' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
