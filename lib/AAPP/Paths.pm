package AAPP::Paths;

use strict;
use warnings;
use utf8;
use 5.026;

use Cwd ();
use POSIX ();
use AAPP::Constants qw(RETURN_OK RETURN_FAIL RETURN_ERROR DEFAULT_LOCK_WAIT LOCK_STALE_SECONDS LOCK_FIRST_STEP
    KIT_DIR_NAME DATA_HOME_DEFAULT);
use AAPP::Logger ();

our %paths;
our %held_locks;

# Usage     : my ($ok, $out) = git_capture('rev-parse', '--show-toplevel')
# Purpose   : Runs git with the given arguments, its stderr discarded, and reads its stdout as UTF-8.
#             For calls whose failure is an answer (outside a repository, no such remote).
# Returns   : (1, $stdout) when git exits 0; (0, $stdout) otherwise.
sub git_capture
{
    my (@args) = @_;
    my $fh;
    my $pid = open( $fh, '-|' );
    if ( !defined $pid ) {
        AAPP::Logger::print_msg( 'ERROR', "Cannot start git: $!" );
        return ( 0, '' );
    }
    if ( $pid == 0 ) {
        open( STDERR, '>', '/dev/null' );
        { exec( 'git', @args ) };
        POSIX::_exit(127);
    }
    binmode( $fh, ':encoding(UTF-8)' );
    my $out = do { local $/; <$fh> } // '';
    my $ok = close($fh) ? 1 : 0;
    return ( $ok, $out );
}

# Usage     : my $p = AAPP::Paths::resolve()
# Purpose   : Reads the repository paths with one git rev-parse, once per process: root, git_dir,
#             common_dir, primary_root, and plans_dir/agents_dir/hooks_dir/offline_dir.
# Returns   : Hash ref; empty hash ref outside a repository. A worktree that is absent is undef.
sub resolve
{
    if (%paths) {
        return \%paths;
    }
    my ( $ok, $out ) = git_capture( 'rev-parse', '--show-toplevel', '--absolute-git-dir', '--git-common-dir' );
    my @lines = split( /\n/, $out );
    if ( !$ok || @lines != 3 ) {
        return {};
    }
    my ( $root, $git_dir, $common_raw ) = @lines;
    # git prints a relative common dir against the current directory, not the root.
    my $common = Cwd::abs_path($common_raw);
    if ( !defined $common ) {
        return {};
    }
    my $primary = $root;
    if ( $common =~ m{/\.git$} ) {
        $primary = substr( $common, 0, -5 );
    }
    %paths = (
        root         => $root,
        git_dir      => $git_dir,
        common_dir   => $common,
        primary_root => $primary,
        plans_dir    => scalar( _worktree_dir( $root, $primary, '.plans' ) ),
        agents_dir   => scalar( _worktree_dir( $root, $primary, '.agents' ) ),
        hooks_dir    => scalar( _worktree_dir( $root, $primary, '.githooks' ) ),
        offline_dir  => ( $common =~ s{/\.git$}{}r ) . '/.offline',
    );
    return \%paths;
}

# Usage     : my $dir = _worktree_dir($root, $primary, '.plans')
# Purpose   : Finds a kit worktree in the current checkout first, then in the primary checkout.
# Returns   : The directory, or undef when neither has it.
sub _worktree_dir
{
    my ( $root, $primary, $name ) = @_;
    if ( -d "$root/$name" ) {
        return "$root/$name";
    }
    if ( -d "$primary/$name" ) {
        return "$primary/$name";
    }
    return;
}

# Usage     : my $p = native_path('/c/Users/me/x')
# Purpose   : Writes a Git Bash path ('/c/...') as this Perl can open it: unchanged everywhere except
#             under a native Windows Perl, which gets 'C:/...'.
# Returns   : The path.
sub native_path
{
    my ($path) = @_;
    if ( $^O eq 'MSWin32' && $path =~ m{^/([a-zA-Z])(/.*)?$} ) {
        return uc($1) . ':' . ( $2 // '/' );
    }
    return $path;
}

# Usage     : my $dir = kit_dir()
# Purpose   : The one answer to where the kit is: the kit whose lib/ is $AAPP_LIB (the aapp dispatcher
#             exports it), else <data home>/aapp-kit, the data home being $XDG_DATA_HOME, else
#             <home>/.local/share; home is $HOME, else %USERPROFILE% on Windows.
# Returns   : The kit folder, or undef when no kit with lib/AAPP/JSON.pm is found.
sub kit_dir
{
    if ( defined $ENV{AAPP_LIB} && $ENV{AAPP_LIB} ne '' ) {
        my $lib = native_path( $ENV{AAPP_LIB} );
        if ( -r "$lib/AAPP/JSON.pm" ) {
            return $lib =~ s{/+lib/*$}{}r;
        }
    }
    my $data = $ENV{XDG_DATA_HOME};
    if ( !defined $data || $data eq '' ) {
        my $home = $ENV{HOME};
        if ( ( !defined $home || $home eq '' ) && $^O eq 'MSWin32' ) {
            $home = $ENV{USERPROFILE};
        }
        if ( !defined $home || $home eq '' ) {
            return;
        }
        $data = "$home/" . DATA_HOME_DEFAULT;
    }
    my $kit = native_path($data) . '/' . KIT_DIR_NAME;
    if ( !-r "$kit/lib/AAPP/JSON.pm" ) {
        return;
    }
    return $kit;
}

# Usage     : my $abs = abs_path('a/../b', '/base')
# Purpose   : Makes a path absolute against a base (default: the current directory) and folds
#             '.', '..' and repeated slashes, as strings only; nothing is resolved on disk.
# Returns   : The absolute path.
sub abs_path
{
    my ( $path, $base ) = @_;
    if ( $path !~ m{^/} ) {
        $base //= Cwd::getcwd();
        $path = "$base/$path";
    }
    my @out;
    foreach my $part ( split( m{/}, $path ) ) {
        if ( $part eq '' || $part eq '.' ) {
            next;
        }
        if ( $part eq '..' ) {
            pop @out;
            next;
        }
        push @out, $part;
    }
    return '/' . join( '/', @out );
}

# Usage     : my $rel = rel_path('/a/b', '/a/c/d')
# Purpose   : The second path relative to the first directory; both are made absolute first.
# Returns   : The relative path ('.' when they are the same).
sub rel_path
{
    my ( $from, $to ) = @_;
    my @from = grep { $_ ne '' } split( m{/}, abs_path($from) );
    my @to   = grep { $_ ne '' } split( m{/}, abs_path($to) );
    while ( @from && @to && $from[0] eq $to[0] ) {
        shift @from;
        shift @to;
    }
    my @parts = ( ('..') x scalar(@from), @to );
    if ( !@parts ) {
        return '.';
    }
    return join( '/', @parts );
}

# Usage     : my $re = glob_to_regex('lib/**/*.pm')
# Purpose   : Turns a Target Files glob into an anchored regex: '*' and '?' stay in one segment,
#             '**' crosses segments, '/**/' and a leading '**/' also match no segment.
# Returns   : The regex source string.
sub glob_to_regex
{
    my ($glob) = @_;
    my $re = '';
    my $i  = 0;
    my $n  = length($glob);
    while ( $i < $n ) {
        my $rest = substr( $glob, $i );
        if ( $i == 0 && $rest =~ m{^\*\*/} ) {
            $re .= '(.*/)?';
            $i += 3;
        } elsif ( $rest =~ m{^/\*\*/} ) {
            $re .= '/(.*/)?';
            $i += 4;
        } elsif ( $rest eq '/**' ) {
            $re .= '/(.*)?';
            $i += 3;
        } elsif ( $rest =~ m{^\*\*} ) {
            $re .= '.*';
            $i += 2;
        } elsif ( $rest =~ m{^\*} ) {
            $re .= '[^/]*';
            $i += 1;
        } elsif ( $rest =~ m{^\?} ) {
            $re .= '[^/]';
            $i += 1;
        } elsif ( $rest =~ m{^\[} ) {
            $re .= '[';
            $i += 1;
        } elsif ( $rest =~ m{^\]} ) {
            $re .= ']';
            $i += 1;
        } else {
            $re .= quotemeta( substr( $glob, $i, 1 ) );
            $i += 1;
        }
    }
    return "^$re\$";
}

# Usage     : if ( match_pattern_list($path, @patterns) ) { ... }
# Purpose   : Matches a repository path against Target Files patterns: exact path, a directory
#             prefix ending in '/', or a glob containing * ? or [.
# Returns   : 1 on the first match, 0 when none matches.
sub match_pattern_list
{
    my ( $target, @patterns ) = @_;
    foreach my $pattern (@patterns) {
        if ( !defined $pattern || $pattern eq '' ) {
            next;
        }
        if ( $target eq $pattern ) {
            return 1;
        }
        if ( $pattern =~ m{/$} && index( $target, $pattern ) == 0 ) {
            return 1;
        }
        if ( $pattern =~ /[*?\[]/ ) {
            my $re = glob_to_regex($pattern);
            if ( $target =~ /$re/ ) {
                return 1;
            }
        }
    }
    return 0;
}

# Usage     : my $os = aapp_os($uname_s, $proc_version_path)
# Purpose   : Names the platform: linux, wsl, darwin, windows, bsd or unknown. Both arguments
#             default to the live system, so every branch is testable.
# Returns   : The platform name.
sub aapp_os
{
    my ( $uname_s, $proc_version ) = @_;
    $uname_s      //= ( POSIX::uname() )[0];
    $proc_version //= '/proc/version';
    if ( $uname_s =~ /^Linux/ ) {
        my $fh;
        if ( -r $proc_version && open( $fh, '<', $proc_version ) ) {
            my $text = do { local $/; <$fh> };
            close($fh);
            if ( $text =~ /microsoft/i ) {
                return 'wsl';
            }
        }
        return 'linux';
    }
    if ( $uname_s =~ /^Darwin/ ) {
        return 'darwin';
    }
    if ( $uname_s =~ /^(?:MINGW|MSYS|CYGWIN)/ ) {
        return 'windows';
    }
    if ( $uname_s =~ /^(?:FreeBSD|OpenBSD|NetBSD|DragonFly)/ ) {
        return 'bsd';
    }
    return 'unknown';
}

# Usage     : my $dir = lock_path('integrate/develop')
# Purpose   : The lock directory for a name, in the repository's common git dir ('/' and ':' escaped).
# Returns   : The path, or undef outside a repository.
sub lock_path
{
    my ($name) = @_;
    my $common = resolve()->{common_dir};
    if ( !defined $common ) {
        return;
    }
    my $safe = $name =~ s{/}{%2F}gr;
    $safe =~ s{:}{%3A}g;
    return "$common/aapp_$safe.lock";
}

# Usage     : my $rc = lock_acquire('integrate/develop', 15, 'develop integration')
# Purpose   : Takes a named lock, waiting up to $limit seconds (default 15) with growing steps; a lock
#             whose holder is gone is taken over. Re-entrant within one process.
# Returns   : RETURN_OK; RETURN_FAIL after an [ ERROR ] line when still held at the limit; RETURN_ERROR outside a repository.
sub lock_acquire
{
    my ( $name, $limit, $label ) = @_;
    $limit //= DEFAULT_LOCK_WAIT;
    $label //= $name;
    my $lock = lock_path($name);
    if ( !defined $lock ) {
        AAPP::Logger::print_msg( 'ERROR', "Cannot place the $label lock: not in a git repository." );
        return RETURN_ERROR;
    }
    if ( defined $held_locks{$lock} && $held_locks{$lock} == $$ ) {
        return RETURN_OK;
    }
    my $waited = 0;
    my $step   = LOCK_FIRST_STEP;
    while ( !mkdir($lock) ) {
        my $pid = _lock_holder($lock);
        if ( !defined $pid ) {
            my $mtime = ( stat($lock) )[9] // time();
            if ( time() - $mtime >= LOCK_STALE_SECONDS ) {
                AAPP::Logger::print_msg( 'WARN', "Taking over the stale $label lock (no holder PID)." );
                _remove_lock($lock);
                next;
            }
        } elsif ( !kill( 0, $pid ) ) {
            AAPP::Logger::print_msg( 'WARN', "Taking over the stale $label lock (holder PID $pid is gone)." );
            _remove_lock($lock);
            next;
        }
        if ( $waited >= $limit ) {
            my $by   = defined $pid ? " by process $pid" : '';
            my $info = _lock_info($lock);
            AAPP::Logger::print_msg( 'ERROR', "The $label lock is still held$by$info; waited ${waited}s (limit ${limit}s). Retry when the holder finishes, or raise the limit with 'git config aapp.integrateWait <seconds>'." );
            return RETURN_FAIL;
        }
        my $by = defined $pid ? " by PID $pid" : '';
        AAPP::Logger::print_msg( 'WARN', "The $label lock is held$by; waiting ${step}s (elapsed ${waited}s)." );
        sleep($step);
        $waited += $step;
        $step   += 1;
    }
    my $fh;
    if ( !open( $fh, '>', "$lock/pid" ) ) {
        AAPP::Logger::print_msg( 'ERROR', "Cannot write $lock/pid: $!" );
        _remove_lock($lock);
        return RETURN_ERROR;
    }
    print {$fh} "$$\n";
    close($fh);
    $held_locks{$lock} = $$;
    return RETURN_OK;
}

# Usage     : lock_release('integrate/develop')
# Purpose   : Removes a named lock and forgets it.
# Returns   : RETURN_OK, or RETURN_ERROR outside a repository.
sub lock_release
{
    my ($name) = @_;
    my $lock = lock_path($name);
    if ( !defined $lock ) {
        return RETURN_ERROR;
    }
    _remove_lock($lock);
    delete $held_locks{$lock};
    return RETURN_OK;
}

# Usage     : if ( lock_held('integrate/develop') ) { ... }
# Purpose   : Tells whether a named lock is held by a live process.
# Returns   : 1 when held, 0 otherwise.
sub lock_held
{
    my ($name) = @_;
    my $lock = lock_path($name);
    if ( !defined $lock || !-d $lock ) {
        return 0;
    }
    my $pid = _lock_holder($lock);
    if ( defined $pid && kill( 0, $pid ) ) {
        return 1;
    }
    return 0;
}

# Usage     : my $pid = _lock_holder($lock)
# Purpose   : Reads the PID written into a lock directory.
# Returns   : The PID, or undef when none is written.
sub _lock_holder
{
    my ($lock) = @_;
    my $fh;
    if ( !open( $fh, '<', "$lock/pid" ) ) {
        return;
    }
    my $pid = <$fh>;
    close($fh);
    if ( !defined $pid || $pid !~ /^(\d+)/ ) {
        return;
    }
    return $1;
}

# Usage     : my $text = _lock_info($lock)
# Purpose   : Reads the holder's description from the lock's info file, for the refusal line.
# Returns   : ' (<info>)', or '' when there is none.
sub _lock_info
{
    my ($lock) = @_;
    my $fh;
    if ( !open( $fh, '<:encoding(UTF-8)', "$lock/info" ) ) {
        return '';
    }
    my $info = do { local $/; <$fh> } // '';
    close($fh);
    chomp($info);
    if ( $info eq '' ) {
        return '';
    }
    return " ($info)";
}

# Usage     : _remove_lock($lock)
# Purpose   : Deletes a lock directory and its files.
# Returns   : 1 when the directory is gone, 0 otherwise.
sub _remove_lock
{
    my ($lock) = @_;
    foreach my $file ( glob("\Q$lock\E/*") ) {
        unlink($file);
    }
    rmdir($lock);
    if ( -d $lock ) {
        return 0;
    }
    return 1;
}

END {
    foreach my $lock ( keys %held_locks ) {
        if ( $held_locks{$lock} == $$ ) {
            _remove_lock($lock);
        }
    }
}

1;
