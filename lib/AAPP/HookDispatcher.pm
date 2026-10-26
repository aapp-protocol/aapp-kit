package AAPP::HookDispatcher;

use strict;
use warnings;
use utf8;
use 5.026;

use Digest::SHA ();
use File::Spec ();
use File::Path ();
use File::Basename ();
use POSIX qw(:sys_wait_h);
use Time::HiRes qw(sleep);

use AAPP::Constants qw(RETURN_OK RETURN_ERROR RETURN_FAIL RETURN_NOT_FOUND);
use AAPP::Paths ();
use AAPP::Config ();
use AAPP::JSON ();
use AAPP::Logger ();

our $PROTOCOL_VERSION = '1.0';

# Usage     : my $hex = compute_file_sha256($target_file)
# Purpose   : Computes lowercase 64-char hex SHA256 of a file in-process via Digest::SHA.
# Returns   : Hex string on success, or undef if unreadable/missing.
sub compute_file_sha256
{
    my ($file) = @_;
    return undef unless defined $file && -f $file;
    open( my $fh, '<:raw', $file ) or return undef;
    my $digest = eval { Digest::SHA->new(256)->addfile($fh)->hexdigest };
    close($fh);
    return defined $digest ? lc($digest) : undef;
}

# Usage     : my ($rc, $stdout, $stderr) = execute_with_watchdog($max_time, $cmd, \@args, $stdin_str, \%env)
# Purpose   : Executes an external command in a dedicated process group with a timeout watchdog.
# Returns   : ($exit_code, $stdout, $stderr). Exit code is 124 on timeout.
sub execute_with_watchdog
{
    my ( $max_time, $cmd, $args, $stdin_str, $env ) = @_;
    $args      //= [];
    $stdin_str //= '';
    $env       //= {};
    $max_time  = 10 unless defined $max_time && $max_time =~ /^[0-9]+$/ && $max_time > 0;

    my $scratch = AAPP::Paths::resolve()->{git_dir} // File::Spec->tmpdir();
    my $cmd_name = File::Basename::basename($cmd) =~ s{[^\w.-]}{_}gr;
    my $file_prefix = "watchdog.$$.${cmd_name}." . int( rand(100000) );
    my $in_f  = "$scratch/$file_prefix.in";
    my $out_f = "$scratch/$file_prefix.out";
    my $err_f = "$scratch/$file_prefix.err";

    my $fh;
    if ( !open( $fh, '>:raw', $in_f ) ) {
        return ( 1, '', "Cannot write input buffer: $!" );
    }
    print {$fh} $stdin_str;
    close($fh);

    my $pid = fork();
    if ( !defined $pid ) {
        unlink( $in_f );
        return ( 1, '', "Cannot fork for execution: $!" );
    }

    if ( $pid == 0 ) {
        # Child process: establish dedicated process group
        POSIX::setpgid( 0, 0 );
        $SIG{$_} = 'DEFAULT' for qw(INT TERM HUP ALRM);

        foreach my $k ( keys %$env ) {
            if ( defined $env->{$k} ) {
                $ENV{$k} = $env->{$k};
            } else {
                delete $ENV{$k};
            }
        }

        open( STDIN,  '<:raw', $in_f )  or POSIX::_exit(126);
        open( STDOUT, '>:raw', $out_f ) or POSIX::_exit(126);
        open( STDERR, '>:raw', $err_f ) or POSIX::_exit(126);

        exec { $cmd } $cmd, @$args or POSIX::_exit(127);
    }

    # Parent process: watchdog timeout loop
    POSIX::setpgid( $pid, $pid );
    my $timed_out = 0;
    my $rc        = 0;

    eval {
        local $SIG{ALRM} = sub {
            $timed_out = 1;
            kill( 'TERM', -$pid );
            sleep(0.1);
            kill( 'KILL', -$pid );
            die "timeout\n";
        };
        alarm($max_time);
        waitpid( $pid, 0 );
        $rc = $?;
        alarm(0);
    };
    alarm(0);

    if ($timed_out) {
        $rc = 124 << 8;
    }

    my $exit_code = $rc >> 8;
    my $stdout    = -f $out_f ? do { open( my $f, '<:raw', $out_f ); local $/; my $c = <$f>; close($f); $c // '' } : '';
    my $stderr    = -f $err_f ? do { open( my $f, '<:raw', $err_f ); local $/; my $c = <$f>; close($f); $c // '' } : '';

    unlink( $in_f, $out_f, $err_f );
    return ( $exit_code, $stdout, $stderr );
}

# Usage     : my $remote_json = _envelope_remote_json($root)
# Purpose   : Resolves remote name and url without credentials, or prints 'null'.
sub _envelope_remote_json
{
    my ($root) = @_;
    # Read configured remote name in-process via AAPP::Config (default 'origin')
    my $name = AAPP::Config::get('aapp.remote') // 'origin';
    $name = 'origin' if $name eq '';

    # Query remote URL safely via array exec git capture
    my ( $ok, $url ) = AAPP::Paths::git_capture( '-C', $root, 'remote', 'get-url', $name );
    return 'null' if !$ok || !defined $url || $url eq '';
    $url =~ s/\s+\z//;

    # Strip credentials: http://user:secret@host -> http://host, etc.
    $url =~ s{^(https?://)[^/@]*@}{$1};
    $url =~ s{^([a-z+]+://[^/:@]*):[^/@]*@}{$1@};

    my $esc_name = $name =~ s/\\/\\\\/gr =~ s/"/\\"/gr;
    my $esc_url  = $url  =~ s/\\/\\\\/gr =~ s/"/\\"/gr;
    return qq/{ "name": "$esc_name", "url": "$esc_url" }/;
}

# Usage     : my $json = build_event_envelope($event, $data_json, $root)
# Purpose   : Generates the canonical JSON event envelope for lifecycle hooks and plugins.
sub build_event_envelope
{
    my ( $event, $data_json, $root ) = @_;
    $root //= AAPP::Paths::resolve()->{root};
    if ( !defined $root || $root eq '' ) {
        my ( $r_ok, $r_out ) = AAPP::Paths::git_capture('rev-parse', '--show-toplevel');
        $root = ( $r_ok && defined $r_out && $r_out ne '' ) ? ( $r_out =~ s/\s+\z//r ) : Cwd::getcwd();
    }
    $data_json = '{}' if !defined $data_json || $data_json eq '';

    my $actor     = $ENV{AAPP_ACTOR} // 'developer';
    my $timestamp = AAPP::JSON::utc_now();
    # Query current branch safely via array exec git capture
    my ( $b_ok, $branch_out ) = AAPP::Paths::git_capture( '-C', $root, 'rev-parse', '--abbrev-ref', 'HEAD' );
    my $branch = ( $b_ok && defined $branch_out && $branch_out ne '' ) ? ( $branch_out =~ s/\s+\z//r ) : 'unknown';

    my $esc_root = $root =~ s/\\/\\\\/gr =~ s/"/\\"/gr;
    my $remote   = _envelope_remote_json($root);

    return <<"EOF";
{
  "version": "$PROTOCOL_VERSION",
  "event": "$event",
  "timestamp": "$timestamp",
  "actor": "$actor",
  "repository": {
    "root": "$esc_root",
    "branch": "$branch",
    "remote": $remote
  },
  "data": $data_json,
  "extra": {}
}
EOF
}

# Usage     : my $path = resolve_plugin_entrypoint($pdir, $name)
# Purpose   : Extension-agnostic action plugin resolution.
sub resolve_plugin_entrypoint
{
    my ( $pdir, $name ) = @_;
    return undef if defined $ENV{AAPP_PLUGIN_MUTED} && $ENV{AAPP_PLUGIN_MUTED} eq $name;
    return undef unless defined $pdir && -d $pdir;

    # 1. Canonical extensionless
    if ( -f "$pdir/run" && -x "$pdir/run" ) {
        return "$pdir/run";
    }
    if ( -f "$pdir/$name" && -x "$pdir/$name" ) {
        return "$pdir/$name";
    }

    # 2. Subdirectory extensionless
    if ( -f "$pdir/scripts/run" && -x "$pdir/scripts/run" ) {
        return "$pdir/scripts/run";
    }
    if ( -f "$pdir/scripts/$name" && -x "$pdir/scripts/$name" ) {
        return "$pdir/scripts/$name";
    }

    # 3. Extension-agnostic search (skipping .sample, .bak, *~)
    opendir( my $dh, $pdir ) or return undef;
    my @files = sort readdir($dh);
    closedir($dh);

    foreach my $f (@files) {
        next if $f =~ /\.(?:sample|bak)$/ || $f =~ /~$/;
        if ( ( $f =~ /^\Q$name\E\./ || $f =~ /^run\./ ) && -f "$pdir/$f" && -x "$pdir/$f" ) {
            return "$pdir/$f";
        }
    }

    if ( -d "$pdir/scripts" ) {
        opendir( my $sdh, "$pdir/scripts" ) or return undef;
        my @sfiles = sort readdir($sdh);
        closedir($sdh);
        foreach my $f (@sfiles) {
            next if $f =~ /\.(?:sample|bak)$/ || $f =~ /~$/;
            if ( ( $f =~ /^\Q$name\E\./ || $f =~ /^run\./ ) && -f "$pdir/scripts/$f" && -x "$pdir/scripts/$f" ) {
                return "$pdir/scripts/$f";
            }
        }
    }

    return undef;
}

# Usage     : my ($rc, $handled) = dispatch_single_handler(...)
# Purpose   : Dispatches a single lifecycle hook handler with integrity verification.
sub dispatch_single_handler
{
    my ( $event, $handler_rel, $expected_hash, $timeout, $mode, $source_type, $payload, $root ) = @_;
    $root //= AAPP::Paths::resolve()->{root};
    if ( !defined $root || $root eq '' ) {
        my ( $r_ok, $r_out ) = AAPP::Paths::git_capture('rev-parse', '--show-toplevel');
        $root = ( $r_ok && defined $r_out && $r_out ne '' ) ? ( $r_out =~ s/\s+\z//r ) : Cwd::getcwd();
    }

    my $handler_path = $handler_rel =~ m{^/} ? $handler_rel : "$root/$handler_rel";

    if ( !-f $handler_path || !-x $handler_path ) {
        if ( $mode eq 'gate' ) {
            print STDERR "❌ [Hook Refusal] Handler '$handler_rel' for event '$event' does not exist or is not executable.\n";
            return 1;
        } else {
            print STDERR "⚠️  [Hook Warning] Handler '$handler_rel' for event '$event' is missing or not executable (skipping).\n";
            return 0;
        }
    }

    if ( $source_type eq 'registry' && defined $expected_hash && $expected_hash ne '' ) {
        my $clean_expected = $expected_hash =~ s/^sha256://r;
        my $actual_hash    = compute_file_sha256($handler_path);
        if ( !defined $actual_hash ) {
            print STDERR "❌ [Hook Integrity Violation] Failed to compute SHA256 for handler '$handler_rel'.\n";
            return 1;
        }
        if ( lc($clean_expected) ne lc($actual_hash) ) {
            print STDERR "❌ [Hook Integrity Violation] SHA256 mismatch for handler '$handler_rel' (event: $event)!\n";
            print STDERR "   Expected : sha256:$clean_expected\n";
            print STDERR "   Computed : sha256:$actual_hash\n";
            print STDERR "   Tamper-evident gate: Handler script cannot be altered without updating registry.tsv.\n";
            return 1;
        }
    }

    my %env = (
        AAPP_EVENT     => $event,
        AAPP_PLAN_ID   => $ENV{AAPP_PLAN_ID}   // '',
        AAPP_PLAN_FILE => $ENV{AAPP_PLAN_FILE} // '',
        AAPP_ACTION    => $ENV{AAPP_ACTION}    // '',
        AAPP_REMOTE    => $ENV{AAPP_REMOTE}    // '',
        AAPP_MODE      => $mode,
        AAPP_TIMEOUT   => $timeout,
        AAPP_ACTOR     => $ENV{AAPP_ACTOR}     // 'developer',
    );

    my ( $rc, $out, $err ) = execute_with_watchdog( $timeout, $handler_path, [], $payload, \%env );

    if ( $rc == 0 ) {
        print STDERR $err if defined $err && $err ne '';
        print STDOUT $out if defined $out && $out ne '';
        return 0;
    } elsif ( $rc == 2 ) {
        print STDERR "⚠️  [Hook Notice] Handler '$handler_rel' emitted advisory warning (exit 2):\n";
        print STDERR $err if defined $err && $err ne '';
        print STDOUT $out if defined $out && $out ne '';
        return 0;
    } elsif ( $rc == 124 ) {
        if ( $mode eq 'gate' ) {
            print STDERR "❌ [Hook Timeout Gate] Handler '$handler_rel' exceeded timeout (${timeout}s) during '$event'.\n";
            print STDERR $err if defined $err && $err ne '';
            return 1;
        } else {
            print STDERR "⚠️  [Hook Timeout Warning] Handler '$handler_rel' exceeded timeout (${timeout}s) during '$event' (notify mode).\n";
            print STDERR $err if defined $err && $err ne '';
            return 0;
        }
    } else {
        if ( $mode eq 'gate' ) {
            print STDERR "❌ [Hook Gate Refusal] Handler '$handler_rel' rejected event '$event' (exit $rc):\n";
            print STDERR $err if defined $err && $err ne '';
            return 1;
        } else {
            print STDERR "⚠️  [Hook Warning] Handler '$handler_rel' failed for event '$event' (exit $rc, notify mode):\n";
            print STDERR $err if defined $err && $err ne '';
            return 0;
        }
    }
}

# Usage     : my $rc = dispatch_hook($event, $data_json, $root)
# Purpose   : Master lifecycle hook dispatcher.
sub dispatch_hook
{
    my ( $event, $data_json, $root ) = @_;
    $root //= AAPP::Paths::resolve()->{root};
    if ( !defined $root || $root eq '' ) {
        my ( $r_ok, $r_out ) = AAPP::Paths::git_capture('rev-parse', '--show-toplevel');
        $root = ( $r_ok && defined $r_out && $r_out ne '' ) ? ( $r_out =~ s/\s+\z//r ) : Cwd::getcwd();
    }
    $data_json = '{}' if !defined $data_json || $data_json eq '';

    my $payload  = build_event_envelope( $event, $data_json, $root );
    my $reg_file = "$root/.agents/skills/aapp-hooks/registry.tsv";
    my $handlers = 0;

    my ( $d_rc, $dec_data ) = AAPP::JSON::decode($data_json);
    my $payload_keys = ( $d_rc && ref($dec_data) eq 'HASH' ) ? [ sort keys %$dec_data ] : [];

    if ( -f $reg_file ) {
        open( my $fh, '<:encoding(UTF-8)', $reg_file );
        if ($fh) {
            while ( my $line = <$fh> ) {
                $line =~ s/\r?\n\z//;
                next if $line =~ /^\s*$/ || $line =~ /^\s*#/;
                my @cols = split( /\t/, $line, -1 );
                if ( scalar(@cols) > 5 ) {
                    print STDERR "❌ Malformed registry line in $reg_file: unexpected 6th field\n";
                    close($fh);
                    AAPP::Logger::log_event( 'hook', 'dispatch', {
                        kind         => 'hook',
                        name         => 'registry',
                        step         => $event,
                        called       => 0,
                        skip_reason  => '',
                        status       => 'failed',
                        payload_keys => $payload_keys,
                        response     => { error => 'malformed registry line' },
                    } );
                    return 1;
                }
                my ( $ev, $hp, $expected_hash, $to, $md ) = @cols;
                if ( defined $ev && $ev eq $event ) {
                    $to = 10 if !defined $to || $to eq '';
                    if ( !defined $md || $md eq '' ) {
                        $md = $ev =~ /^post-/ ? 'notify' : 'gate';
                    }
                    $handlers++;
                    my $h_rc = dispatch_single_handler( $event, $hp, $expected_hash, $to, $md, 'registry', $payload, $root );
                    my $status = $h_rc == 0 ? 'ok' : ( $h_rc == 124 ? 'timeout' : 'veto' );
                    AAPP::Logger::log_event( 'hook', 'dispatch', {
                        kind         => 'hook',
                        name         => $hp,
                        step         => $event,
                        called       => 1,
                        skip_reason  => '',
                        status       => $status,
                        payload_keys => $payload_keys,
                        response     => {},
                    } );
                    if ( $h_rc != 0 ) {
                        close($fh);
                        return 1;
                    }
                }
            }
            close($fh);
        }
    }

    # Local overrides via git config aapp.hook.<event>
    my $allow_local = AAPP::Config::get('aapp.allowLocalHooks') // 'true';
    $allow_local = 'true' if $allow_local eq '';
    if ( $allow_local ne 'false' ) {
        # Query configured local hooks safely via array exec git capture
        my ( $ok, $local_raw ) = AAPP::Paths::git_capture( '-C', $root, 'config', '--get-all', "aapp.hook.$event" );
        $local_raw //= '';
        my $timeout = AAPP::Config::get('aapp.hookTimeout') // 10;
        $timeout = 10 if $timeout !~ /^[0-9]+$/;

        foreach my $hp ( split( /\n/, $local_raw ) ) {
            $hp =~ s/^\s+|\s+$//g;
            next if $hp eq '';
            $handlers++;
            dispatch_single_handler( $event, $hp, '', $timeout, 'notify', 'local_config', $payload, $root );
            AAPP::Logger::log_event( 'hook', 'dispatch', {
                kind         => 'hook',
                name         => $hp,
                step         => $event,
                called       => 1,
                skip_reason  => '',
                status       => 'ok',
                payload_keys => $payload_keys,
                response     => {},
            } );
        }
    }

    if ( $handlers == 0 ) {
        AAPP::Logger::log_event( 'hook', 'dispatch', {
            kind         => 'hook',
            name         => '',
            step         => $event,
            called       => 0,
            skip_reason  => 'none_registered',
            status       => 'ok',
            payload_keys => $payload_keys,
            response     => {},
        } );
    }

    return 0;
}

# Usage     : my ($rc, $stdout, $stderr) = run_action_plugin($entry, $root, $action, $event, $data_json, %extra_env)
# Purpose   : Runs an action plugin streaming the envelope to STDIN with timeout watchdog.
sub run_action_plugin
{
    my ( $entry, $root, $action, $event, $data_json, %extra_env ) = @_;
    $root //= AAPP::Paths::resolve()->{root};
    if ( !defined $root || $root eq '' ) {
        my ( $r_ok, $r_out ) = AAPP::Paths::git_capture('rev-parse', '--show-toplevel');
        $root = ( $r_ok && defined $r_out && $r_out ne '' ) ? ( $r_out =~ s/\s+\z//r ) : Cwd::getcwd();
    }
    my $timeout = AAPP::Config::get('aapp.pluginTimeout') // 10;
    $timeout = 10 if $timeout !~ /^[0-9]+$/;

    my $payload = build_event_envelope( $event, $data_json, $root );
    my %env = (
        AAPP_ACTION      => $action,
        AAPP_REPO_ROOT   => $root,
        AAPP_PLUGIN_STEP => $event,
        %extra_env,
    );

    return execute_with_watchdog( $timeout, $entry, [], $payload, \%env );
}

# Usage     : my ($rc, $res) = plugin_step($entry, $root, $action, $event, $data_json, %extra_env)
# Purpose   : Evaluates one step of the plugin protocol (P-77).
sub plugin_step
{
    my ( $entry, $root, $action, $event, $data_json, %extra_env ) = @_;
    $root //= AAPP::Paths::resolve()->{root};
    if ( !defined $root || $root eq '' ) {
        my ( $r_ok, $r_out ) = AAPP::Paths::git_capture('rev-parse', '--show-toplevel');
        $root = ( $r_ok && defined $r_out && $r_out ne '' ) ? ( $r_out =~ s/\s+\z//r ) : Cwd::getcwd();
    }
    my $pname = File::Basename::basename( File::Basename::dirname($entry) );

    my $scratch = AAPP::Paths::resolve()->{git_dir} // File::Spec->tmpdir();
    my $list_f  = "$scratch/plugin_list.$$.$pname";
    my $do_f    = "$scratch/plugin_do.$$.$pname";

    my ( $rc, $stdout, $stderr ) = run_action_plugin(
        $entry, $root, $action, $event, $data_json,
        AAPP_PLUGIN_LIST => $list_f,
        AAPP_PLUGIN_DO   => $do_f,
        %extra_env,
    );

    my ( $d_rc, $dec_data ) = AAPP::JSON::decode( $data_json // '{}' );
    my $payload_keys = ( $d_rc && ref($dec_data) eq 'HASH' ) ? [ sort keys %$dec_data ] : [];

    if ( $rc != 0 ) {
        my $msg = '';
        my ( $p_rc, $parsed ) = AAPP::JSON::decode($stdout);
        if ( $p_rc && ref($parsed) eq 'HASH' && defined $parsed->{error} ) {
            $msg = $parsed->{error};
        }
        if ( $rc == 124 ) {
            my $timeout = AAPP::Config::get('aapp.pluginTimeout') // 10;
            $timeout = 10 if $timeout !~ /^[0-9]+$/;
            $msg = "no answer within ${timeout}s";
        }
        unlink( $list_f, $do_f );
        AAPP::Logger::log_event( 'hook', 'dispatch', {
            kind         => 'plugin',
            name         => $pname,
            step         => $event,
            called       => 1,
            skip_reason  => '',
            status       => ( $rc == 124 ? 'timeout' : 'failed' ),
            payload_keys => $payload_keys,
            response     => { error => $msg },
        } );
        return ( $rc, { status => 'failed', message => $msg, out => $stdout, err => $stderr } );
    }

    my ( $j_rc, $out_obj ) = AAPP::JSON::decode($stdout);
    $out_obj = {} unless $j_rc && ref($out_obj) eq 'HASH';

    my $ver = $out_obj->{version};
    if ( defined $ver && $ver ne '' ) {
        my @v = split( /\./, $ver );
        my @p = split( /\./, $PROTOCOL_VERSION );
        if ( ( $v[0] // 0 ) > ( $p[0] // 0 ) || ( ( $v[0] // 0 ) == ( $p[0] // 0 ) && ( $v[1] // 0 ) > ( $p[1] // 0 ) ) ) {
            unlink( $list_f, $do_f );
            my $v_err = "answer is protocol version $ver; this kit speaks $PROTOCOL_VERSION";
            print STDERR "❌ [Plugin] The plugin's $v_err.\n";
            return ( 1, { status => 'failed', message => $v_err, out => $stdout } );
        }
    }

    my $status  = $out_obj->{status} // 'ok';
    my $message = $out_obj->{message} // '';
    if ( $message ne '' ) {
        print STDOUT "💬 [Plugin] $message\n";
    }

    my @list_lines;
    if ( -f $list_f ) {
        open( my $lfh, '<:encoding(UTF-8)', $list_f );
        if ($lfh) {
            while ( my $l = <$lfh> ) {
                $l =~ s/\r?\n\z//;
                push @list_lines, $l if $l =~ /\S/;
            }
            close($lfh);
        }
    }

    if ( -f $do_f && -s $do_f ) {
        plugin_run_do( $event =~ s/\..*//r, $pname, $do_f, $root );
    }

    unlink( $list_f, $do_f );

    AAPP::Logger::log_event( 'hook', 'dispatch', {
        kind         => 'plugin',
        name         => $pname,
        step         => $event,
        called       => 1,
        skip_reason  => '',
        status       => $status,
        payload_keys => $payload_keys,
        response     => $out_obj,
    } );

    if ( $status eq 'declined' ) {
        return ( 0, { status => 'declined', message => $message, out => $stdout, response => $out_obj } );
    } elsif ( $status eq 'failed' ) {
        return ( 1, { status => 'failed', message => $message, out => $stdout, response => $out_obj } );
    }

    return ( 0, {
        status     => 'ok',
        message    => $message,
        handled    => $out_obj->{handled} // '',
        out        => $stdout,
        response   => $out_obj,
        list_lines => \@list_lines,
    } );
}

# Usage     : my $bool = plugin_handled($part, $handled_str)
sub plugin_handled
{
    my ( $part, $handled_str ) = @_;
    return 0 unless defined $handled_str && defined $part;
    my %set = map { $_ => 1 } grep { $_ ne '' } split( /\s*,\s*/, $handled_str );
    return $set{$part} ? 1 : 0;
}

# Usage     : plugin_run_do($subject, $plugin_name, $do_file, $root)
# Purpose   : Runs whitelisted commands from lib/plugin_do.tsv.
sub plugin_run_do
{
    my ( $subject, $name, $do_file, $root ) = @_;
    return unless defined $do_file && -s $do_file;

    my $tsv_file = "$root/lib/plugin_do.tsv";
    my %allowed_cmds;
    if ( -f $tsv_file ) {
        open( my $tfh, '<:encoding(UTF-8)', $tsv_file );
        if ($tfh) {
            while ( my $line = <$tfh> ) {
                $line =~ s/\r?\n\z//;
                my ( $s, $cmd ) = split( /\t/, $line );
                if ( defined $s && defined $cmd && $s eq $subject ) {
                    $allowed_cmds{$cmd} = 1;
                }
            }
            close($tfh);
        }
    }

    open( my $dfh, '<:encoding(UTF-8)', $do_file ) or return;
    my @lines = <$dfh>;
    close($dfh);

    foreach my $line (@lines) {
        $line =~ s/\r?\n\z//;
        $line =~ s/^\s+|\s+$//g;
        next if $line eq '';

        my $is_allowed = 0;
        foreach my $cand ( keys %allowed_cmds ) {
            if ( $line eq $cand || $line =~ /^\Q$cand\E\s/ ) {
                $is_allowed = 1;
                break;
            }
        }

        if ( !$is_allowed ) {
            print STDERR "⛔ [Plugin] do: '$line' is not an accepted $subject command; skipped.\n";
            next;
        }

        # Tokenize line without shell injection
        my @args = $line =~ /"([^"\\]*(?:\\.[^"\\]*)*)"|'([^'\\]*(?:\\.[^'\\]*)*)'|(\S+)/g;
        @args = grep { defined $_ && $_ ne '' } @args;
        if ( !@args ) {
            print STDERR "⛔ [Plugin] do: '$line' cannot be read as a command; skipped.\n";
            next;
        }

        print STDOUT "▶️  [Plugin] do: $line\n";
        my $bin = "$root/aapp";
        local $ENV{AAPP_PLUGIN_MUTED} = $name;
        # Execute plugin action directly via array exec without invoking shell
        my $rc = system( $bin, @args );
        if ( $rc != 0 ) {
            my $code = $rc >> 8;
            print STDERR "⚠️  [Plugin] do: '$line' was refused (exit $code).\n";
        }
    }
}

1;
