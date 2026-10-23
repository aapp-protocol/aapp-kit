package AAPP::Tests;

use strict;
use warnings;
use utf8;
use 5.026;

use Cwd            ();
use Encode         ();
use File::Basename ();
use File::Copy     ();
use File::Find     ();
use File::Path     ();
use File::Spec     ();
use File::Temp     ();
use IO::Handle     ();
use POSIX          ();
use Storable       ();
use Time::HiRes    ();

use AAPP::Constants qw(RETURN_OK RETURN_FAIL RETURN_ERROR TEST_WATCHDOG_SECONDS TEST_STOP_GRACE_SECONDS
    TEST_JOBS_STEP TEST_SANDBOX_PREFIX TEST_GIT_NAME TEST_GIT_EMAIL TEST_DEFAULT_BRANCH TEST_RECAP_LINES);
use AAPP::Logger ();
use AAPP::Paths  ();
use AAPP::Runner ();

# The kit's test folder, as in any Perl project: t/<area>/<name>.t.
our $TEST_DIR = 't';

# Test areas: the selection word, its folder under t/, and the contracts naming its tests.
our @AREAS = ( [ 'core', 'core', 'lib/docs/core' ], [ 'verb', 'verb', 'lib/docs/verbs' ] );

# Libraries for lib_call: a Perl module is called in a fork of the test process, a bash library
# through bash. A member that ports a library changes its line here; the tests stay as they are.
our %LIBRARIES = (
    util            => 'AAPP::Util',
    config          => 'AAPP::Config',
    paths           => 'AAPP::Paths',
    text            => 'AAPP::Text',
    json            => 'AAPP::JSON',
    output          => 'AAPP::Output',
    state           => 'AAPP::State',
    commit_engine   => 'AAPP::CommitEngine',
    health          => 'AAPP::Health',
    aapp_lib        => 'lib/aapp-lib.sh',
    hook_dispatcher => 'lib/hook_dispatcher.sh',
    attribution     => 'lib/attribution.sh',
    adoption        => 'lib/adoption.sh',
    group_docs      => 'lib/group_docs.sh',
);

# The bash library sourced before any bash library a test calls.
our $BASH_BASE_LIBRARY = 'lib/aapp-lib.sh';

# Kit parts installed into a sandbox kit, next to the aapp executable: what an install ships (no tests).
our @KIT_PARTS = qw(lib templates examples);

# The worktree pointer files a fixture copy rewrites to its own root.
our @POINTER_FILES = (
    '.git/worktrees/-plans/gitdir', '.git/worktrees/-agents/gitdir', '.git/worktrees/-githooks/gitdir',
    '.plans/.git',                  '.agents/.git',                  '.githooks/.git',
);

# Environment a test never inherits from its caller (a git hook, an aapp run).
our @ENV_DROP_PREFIXES = qw(GIT_ AAPP_);

# Bare-word modifiers of t/test-run.
our @MODIFIERS = qw(strict quiet bail list help);

# The summary line's title; the test gate prints from this line to the end.
our $SUMMARY_TITLE = 'Test Summary';

my $RULE = '=' x 60;

# Usage     : AAPP::Tests::main(@ARGV)
# Purpose   : t/test-run's entry: installs the Runner's handlers, runs the selection, and exits
#             with the run's return number.
# Returns   : Does not return.
sub main
{
    my (@argv) = map { Encode::decode( 'UTF-8', $_ ) } @_;
    AAPP::Runner::init_signals();
    binmode( $_, ':encoding(UTF-8)' ) for \*STDOUT, \*STDERR;
    STDOUT->autoflush(1);
    STDERR->autoflush(1);
    my $self = __PACKAGE__->new();
    $AAPP::Runner::return = $self->run_cli(@argv);
    AAPP::Runner::exit_code();
    return;
}

# Usage     : AAPP::Tests::run_file(__FILE__) unless caller;   (the last line of a t/<area>/<name>.t)
# Purpose   : Runs one test file alone, as 'prove -l t/' or 'perl -Ilib t/core/output.t' does: its tests
#             in contract order, numbered 1..N after a TAP plan, the recap as TAP comments.
# Returns   : Does not return.
sub run_file
{
    my ($file) = @_;
    AAPP::Runner::init_signals();
    binmode( $_, ':encoding(UTF-8)' ) for \*STDOUT, \*STDERR;
    STDOUT->autoflush(1);
    STDERR->autoflush(1);
    my $self = __PACKAGE__->new();
    $self->{tap} = 1;
    $AAPP::Runner::return = RETURN_FAIL;
    # The file runs as the program already: load_tests must not compile it a second time.
    my $abs = Cwd::abs_path($file);
    $INC{$abs} = $abs;
    if ( $self->load_tests() ) {
        my $n   = 0;
        my @tests = map { +{ %{$_}, index => ++$n } } grep { Cwd::abs_path( $_->{file} ) eq $abs } @{ $self->{tests} };
        if (@tests) {
            $AAPP::Runner::return = $self->run_tests( { jobs => 1 }, @tests );
        } else {
            AAPP::Logger::print_msg( 'ERROR', "No contract names a test of $file." );
        }
    }
    # A run stopped before its plan says why in TAP's own words, so prove shows it.
    print "Bail out! $file: see the [ ERROR ] lines above.\n" if $AAPP::Runner::return != RETURN_OK && !$self->{planned};
    AAPP::Runner::exit_code();
    return;
}

# Usage     : my $tests = AAPP::Tests->new()
# Purpose   : The harness object: the kit it tests, and the state of one run. Each test gets it as $self.
# Returns   : The object.
sub new
{
    my ($class) = @_;
    my $kit = Cwd::abs_path( File::Basename::dirname( Cwd::abs_path(__FILE__) ) . '/../..' );
    return bless { kit => $kit, owner => $$, live => {}, counter => 0 }, $class;
}

# Usage     : my $rc = $tests->run_cli(@argv)
# Purpose   : Parses the selection and modifiers, checks every contract against its module both ways,
#             and lists or runs the selected tests.
# Returns   : RETURN_OK when every selected test passed or was skipped, RETURN_FAIL otherwise.
sub run_cli
{
    my ( $self, @argv ) = @_;
    if ( $^O eq 'MSWin32' ) {
        AAPP::Logger::print_msg( 'ERROR', 't/test-run needs a POSIX Perl (fork and process groups): run it from Git Bash, WSL, Linux, macOS or BSD.' );
        return RETURN_FAIL;
    }
    my $opt = parse_args(@argv) // return RETURN_FAIL;
    if ( $opt->{help} ) {
        print_help();
        return RETURN_OK;
    }
    $self->load_tests() or return RETURN_FAIL;
    my @selected = $self->select_tests($opt);
    if ( !@selected ) {
        return RETURN_FAIL;
    }
    if ( $opt->{list} ) {
        print_list(@selected);
        return RETURN_OK;
    }
    return $self->run_tests( $opt, @selected );
}

# Usage     : my $opt = parse_args(@argv)
# Purpose   : Reads the bare-word modifiers, 'jobs <n>', 'verb [<name>…]' and the selectors.
# Returns   : The options hash, or undef after an [ ERROR ] line.
sub parse_args
{
    my (@argv) = @_;
    my %is_modifier = map { $_ => 1 } @MODIFIERS;
    my %opt         = ( select => [] );
    while (@argv) {
        my $arg = shift @argv;
        if ( $is_modifier{$arg} ) {
            $opt{$arg} = 1;
        } elsif ( $arg eq 'jobs' ) {
            my $n = shift @argv;
            if ( !defined $n || $n !~ /^[1-9][0-9]*$/ ) {
                AAPP::Logger::print_msg( 'ERROR', "'jobs' needs a positive number: t/test-run jobs <n>." );
                return;
            }
            $opt{jobs} = $n;
        } elsif ( $arg eq 'verb' ) {
            $opt{verbs} //= [];
        } elsif ( defined $opt{verbs} ) {
            push @{ $opt{verbs} }, $arg;
        } else {
            push @{ $opt{select} }, $arg;
        }
    }
    if ( defined $opt{verbs} && @{ $opt{select} } ) {
        AAPP::Logger::print_msg( 'ERROR', "'verb' selects verb files only; other selectors cannot come with it." );
        return;
    }
    return \%opt;
}

# Usage     : print_help()
# Purpose   : Prints t/test-run's usage.
# Returns   : 1
sub print_help
{
    print <<'EOF';
Usage: t/test-run [modifier…] [selector…]
       t/test-run [modifier…] verb [<verb>…]

Runs the kit's Perl test files (t/core/*.t, t/verb/*.t) in the order their
contracts list them (lib/docs/core, lib/docs/verbs). One file alone, with a
TAP plan: prove -l t/core/output.t

Selectors (any number; a test matching one of them runs):
  core | verb        every file of the area
  <file>             one file, e.g. output, pre-commit
  <n>                the n-th test as 'list' numbers it
  <text>             tests whose name or description contains the text
  verb <verb>…       the verb files of the named verbs

Modifiers:
  strict             fail-closed sandbox containment (AAPP_TEST_SANDBOX_STRICT=1)
  quiet              one line per file instead of one per test
  bail               start nothing more after the first failure
  list               list the selected tests without running them
  jobs <n>           run up to <n> files at once (default: the CPU count
                     rounded down to a multiple of 4)
  help               this text
EOF
    return 1;
}

# Usage     : $tests->load_tests() or return RETURN_FAIL
# Purpose   : Reads every contract's '## Tests' lines naming t/<area>/<name>.t::test_<name>, loads
#             each test file, and checks both ways: every listed test is a sub, every test_ sub is listed.
# Returns   : 1, or 0 after an [ ERROR ] line per mismatch.
sub load_tests
{
    my ($self) = @_;
    my ( @tests, @errors, %listed, %file_order );
    foreach my $area (@AREAS) {
        my ( $word, $folder, $docs ) = @{$area};
        foreach my $contract ( sort glob("$self->{kit}/$docs/*.md") ) {
            my $rel = "$docs/" . File::Basename::basename($contract);
            foreach my $entry ( contract_tests($contract) ) {
                my ( $entry_folder, $stem, $name, $desc ) = @{$entry};
                my $ident = "$TEST_DIR/$entry_folder/$stem.t::$name";
                if ( $entry_folder ne $folder ) {
                    push @errors, "$rel: '$ident' is not a file of $TEST_DIR/$folder/";
                    next;
                }
                if ( $listed{$ident}++ ) {
                    push @errors, "$rel: '$ident' is listed twice";
                    next;
                }
                $file_order{"$folder/$stem"} //= scalar keys %file_order;
                push @tests, { area => $word, folder => $folder, module => $stem, name => $name, desc => $desc, contract => $rel };
            }
        }
    }
    my %package_of;
    foreach my $area (@AREAS) {
        my ( $word, $folder, $docs ) = @{$area};
        foreach my $file ( sort glob("$self->{kit}/$TEST_DIR/$folder/*.t") ) {
            my $stem    = File::Basename::basename( $file, '.t' );
            my $rel     = "$TEST_DIR/$folder/$stem.t";
            my $package = test_package( $folder, $stem );
            my $loaded  = eval { require $file; 1 };
            if ( !$loaded ) {
                push @errors, "$rel does not load: " . ( $@ =~ s/\s+$//r );
                next;
            }
            if ( !package_stash($package) ) {
                push @errors, "$rel does not declare package $package";
                next;
            }
            $package_of{"$folder/$stem"} = $package;
            foreach my $sub ( test_subs($package) ) {
                push @errors, "${rel}::$sub is named by no contract ($docs/)" if !$listed{"${rel}::$sub"};
            }
        }
    }
    foreach my $test (@tests) {
        my $key     = "$test->{folder}/$test->{module}";
        my $package = $package_of{$key};
        if ( !defined $package ) {
            push @errors, "$test->{contract}: names $TEST_DIR/$key.t, which does not exist";
            next;
        }
        if ( !$package->can( $test->{name} ) ) {
            push @errors, "$test->{contract}: '$test->{name}' is not a sub of $TEST_DIR/$key.t";
            next;
        }
        $test->{package} = $package;
        $test->{key}     = $key;
        $test->{file}    = "$self->{kit}/$TEST_DIR/$key.t";
    }
    if (@errors) {
        AAPP::Logger::print_msg( 'ERROR', $_ ) for @errors;
        AAPP::Logger::print_msg( 'ERROR', 'Contracts and test files disagree; nothing was run.' );
        return 0;
    }
    my $n = 0;
    my @ordered = map { $_->[1] } sort { $a->[0] <=> $b->[0] } map { [ $file_order{ $_->{key} }, $_ ] } @tests;
    $_->{index} = ++$n for @ordered;
    $self->{tests} = \@ordered;
    return 1;
}

# Usage     : my $package = test_package('core', 'pre-commit')
# Purpose   : The package a test file declares: AAPP::T::<Area>::<Name>, each part of the file name
#             capitalised ('pre-commit' -> 'PreCommit', 'done.worktree' -> 'DoneWorktree').
# Returns   : The package name.
sub test_package
{
    my ( $folder, $stem ) = @_;
    return 'AAPP::T::' . ucfirst($folder) . '::' . join( '', map { ucfirst } split( /[^A-Za-z0-9]+/, $stem ) );
}

# Usage     : my @entries = contract_tests($contract_file)
# Purpose   : The '## Tests' lines of one contract that name a Perl test file in t/.
# Returns   : A list of [area folder, file name without .t, test name, description].
sub contract_tests
{
    my ($file) = @_;
    open( my $fh, '<:encoding(UTF-8)', $file ) or die "AAPP: cannot read $file: $!\n";
    my ( $in_tests, @entries );
    while ( my $line = <$fh> ) {
        chomp($line);
        if ( $line =~ /^## / ) {
            $in_tests = $line =~ /^## Tests\s*$/;
            next;
        }
        if ( $in_tests && $line =~ m{^- `\Q$TEST_DIR\E/(\w+)/([\w.-]+)\.t::(test_\w+)` -> (.+)$} ) {
            push @entries, [ $1, $2, $3, $4 ];
        }
    }
    close($fh);
    return @entries;
}

# Usage     : my @names = test_subs('AAPP::Core::Output')
# Purpose   : The test_<name> subs a test module defines.
# Returns   : The sub names, sorted.
sub test_subs
{
    my ($package) = @_;
    my $stash = package_stash($package) // {};
    my @names = sort grep { /^test_\w+$/ && $package->can($_) } keys %{$stash};
    return @names;
}

# Usage     : my $stash = package_stash('AAPP::Core::Output')
# Purpose   : A package's symbol table, reached through %main:: one name part at a time.
# Returns   : A hash reference, or undef when the package does not exist.
sub package_stash
{
    my ($package) = @_;
    my $stash = \%main::;
    foreach my $part ( split( /::/, $package ) ) {
        my $glob = $stash->{"${part}::"} // return;
        $stash = *{$glob}{HASH} // return;
    }
    return $stash;
}

# Usage     : my @tests = $tests->select_tests($opt)
# Purpose   : The tests the selectors name, in list order: an area, a module, a list number, or text
#             in a test's name or description; or the verb modules 'verb' names.
# Returns   : The selected tests; empty after an [ ERROR ] line.
sub select_tests
{
    my ( $self, $opt ) = @_;
    my @all = @{ $self->{tests} };
    my %picked;
    if ( defined $opt->{verbs} ) {
        my @verb = grep { $_->{area} eq 'verb' } @all;
        if ( !@{ $opt->{verbs} } ) {
            $picked{ $_->{index} } = 1 for @verb;
        }
        foreach my $name ( @{ $opt->{verbs} } ) {
            my @match = grep { squash( $_->{module} ) eq squash($name) } @verb;
            if ( !@match ) {
                AAPP::Logger::print_msg( 'ERROR', "No verb file for '$name' ($TEST_DIR/verb/)." );
                return;
            }
            $picked{ $_->{index} } = 1 for @match;
        }
    } elsif ( !@{ $opt->{select} } ) {
        $picked{ $_->{index} } = 1 for @all;
    }
    my %area = map { $_->[0] => 1 } @AREAS;
    foreach my $token ( @{ $opt->{select} } ) {
        my @match;
        if ( $area{$token} ) {
            @match = grep { $_->{area} eq $token } @all;
        } elsif ( my @module = grep { squash( $_->{module} ) eq squash($token) } @all ) {
            @match = @module;
        } elsif ( $token =~ /^[0-9]+$/ ) {
            @match = grep { $_->{index} == $token } @all;
        } else {
            @match = grep { index( lc( $_->{name} ), lc($token) ) >= 0 || index( lc( $_->{desc} ), lc($token) ) >= 0 } @all;
        }
        if ( !@match ) {
            AAPP::Logger::print_msg( 'ERROR', "No test matches '$token'. See: t/test-run list" );
            return;
        }
        $picked{ $_->{index} } = 1 for @match;
    }
    my @selected = grep { $picked{ $_->{index} } } @all;
    if ( !@selected ) {
        AAPP::Logger::print_msg( 'ERROR', "No tests selected: no contract names a $TEST_DIR/ file of this selection." );
    }
    return @selected;
}

# Usage     : my $key = squash('pre-commit')
# Purpose   : A module or verb name compared loosely: lowercase, letters and digits only.
# Returns   : The squashed name.
sub squash
{
    my ($name) = @_;
    return lc($name) =~ s/[^a-z0-9]//gr;
}

# Usage     : print_list(@tests)
# Purpose   : Prints the tests by module, each with its list number and description.
# Returns   : 1
sub print_list
{
    my (@tests) = @_;
    my $module = '';
    foreach my $test (@tests) {
        if ( $test->{key} ne $module ) {
            $module = $test->{key};
            print "  $module\n";
        }
        printf "  %5d  %s -> %s\n", $test->{index}, $test->{name}, $test->{desc};
    }
    printf "  %d test(s) in %d file(s)\n", scalar(@tests), scalar( modules(@tests) );
    return 1;
}

# Usage     : my @modules = modules(@tests)
# Purpose   : Groups tests by their module, keeping the order.
# Returns   : A list of { key, package, tests => [...] }.
sub modules
{
    my (@tests) = @_;
    my ( @modules, %at );
    foreach my $test (@tests) {
        if ( !defined $at{ $test->{key} } ) {
            push @modules, { key => $test->{key}, package => $test->{package}, tests => [] };
            $at{ $test->{key} } = $#modules;
        }
        push @{ $modules[ $at{ $test->{key} } ]{tests} }, $test;
    }
    return @modules;
}

# Usage     : my $rc = $tests->run_tests($opt, @tests)
# Purpose   : Builds the run's sandbox, runs one worker per module (up to 'jobs' at once, each in its
#             own process group), prints each module's results as it ends, then the summary and recap.
# Returns   : RETURN_OK when nothing failed, RETURN_FAIL otherwise.
sub run_tests
{
    my ( $self, $opt, @tests ) = @_;
    my @modules = modules(@tests);
    my $wall0   = Time::HiRes::time();
    my @cpu0    = times();

    push @AAPP::Runner::cleanups, sub { $self->stop_live(); $self->remove_sandbox(); };
    $self->make_sandbox() or return RETURN_ERROR;
    if ( $opt->{strict} ) {
        $ENV{AAPP_TEST_SANDBOX_STRICT} = 1;
    }
    my $jobs = $opt->{jobs} // $self->default_jobs();
    $jobs = @modules if $jobs > @modules;

    if ( $self->{tap} ) {
        print '1..' . scalar(@tests) . "\n";
        $self->{planned} = 1;
    }
    print "$RULE\n";
    print "  AAPP Perl Test Engine\n";
    print "  Kit tests: $self->{kit}/$TEST_DIR\n";
    printf "  Execution: %d tests in %d files | Jobs: %d | Sandbox Strict: %s\n", scalar(@tests), scalar(@modules), $jobs,
        $opt->{strict} ? 'ON' : 'OFF';
    print "$RULE\n";

    my @queue = @modules;
    my ( %running, @rows, @failed );
    my %count = ( pass => 0, fail => 0, skip => 0 );
    my ( $modules_passed, $stop ) = ( 0, 0 );
    while ( @queue || %running ) {
        while ( !$stop && @queue && keys %running < $jobs ) {
            my $module = shift @queue;
            my $pid    = $self->start_worker( $module, $opt );
            if ( !defined $pid ) {
                $stop = 1;
                push @rows, sprintf( '  FAIL  %-28s cannot start a worker', $module->{key} );
                last;
            }
            $running{$pid} = $module;
        }
        last if !%running;
        my $pid = waitpid( -1, 0 );
        next if $pid <= 0 || !$running{$pid};
        my $status = $?;
        my $module = delete $running{$pid};
        delete $self->{live}{$pid};
        kill 'KILL', -$pid;
        my $result = $self->worker_result( $module, $status );

        my %n = ( pass => 0, fail => 0, skip => 0 );
        foreach my $r ( @{ $result->{tests} } ) {
            $n{ $r->{status} }++;
            push @failed, $r if $r->{status} eq 'fail';
            print tap_line($r) if !$opt->{quiet};
        }
        $count{$_} += $n{$_} for keys %n;
        my $ok  = !$n{fail} && !$result->{error};
        my $row = sprintf( '  %-4s  %-28s (%d passed, %d failed, %d skipped) [%.1fs]', $ok ? 'ok' : 'FAIL', $module->{key},
            $n{pass}, $n{fail}, $n{skip}, $result->{secs} // 0 );
        $row .= " - $result->{error}" if $result->{error};
        push @rows, $row;
        print "$row\n" if $opt->{quiet};
        if ($ok) {
            $modules_passed++;
        } elsif ( $opt->{bail} && !$stop ) {
            $stop = 1;
            AAPP::Logger::print_msg( 'NOTICE', 'Bail: no further file starts after this failure; running ones finish.' );
        }
    }

    my @cpu1 = times();
    my $cpu  = 0;
    $cpu += $cpu1[$_] - $cpu0[$_] for 0 .. 3;
    my $wall = Time::HiRes::time() - $wall0;

    print "\n$RULE\n";
    printf "  %s: %d/%d files passed (%d passed, %d failed, %d skipped) in %.1fs wall, %.1fs cpu\n", $SUMMARY_TITLE, $modules_passed,
        scalar(@modules), $count{pass}, $count{fail}, $count{skip}, $wall, $cpu;
    print "$RULE\n";
    if ( !$opt->{quiet} ) {
        print "$_\n" for @rows;
    }
    if (@failed) {
        print "  Failed tests:\n";
        foreach my $r ( sort { $a->{index} <=> $b->{index} } @failed ) {
            # Under a TAP plan the recap is comments: a second 'not ok N' would count twice.
            print $self->{tap} ? tap_line($r) =~ s/^/# /gmr : tap_line($r);
        }
    }
    $self->remove_sandbox();
    if ( $modules_passed == @modules ) {
        AAPP::Logger::print_msg( 'INFO', 'All tests passed.' );
        return RETURN_OK;
    }
    AAPP::Logger::print_msg( 'ERROR', sprintf( '%d test(s) failed in %d file(s).', $count{fail}, @modules - $modules_passed ) );
    return RETURN_FAIL;
}

# Usage     : print tap_line($result)
# Purpose   : One test's result as a TAP line, an error indented below it.
# Returns   : The text, ending with a newline.
sub tap_line
{
    my ($r) = @_;
    my $where = "$r->{key}::$r->{name}";
    if ( $r->{status} eq 'pass' ) {
        return "ok $r->{index} - $r->{desc}\n";
    }
    if ( $r->{status} eq 'skip' ) {
        return "ok $r->{index} - $r->{desc} # SKIP $r->{reason}\n";
    }
    my @lines = split( /\n/, $r->{error} // 'failed' );
    my $first = shift(@lines) // 'failed';
    my $text  = "not ok $r->{index} - $r->{desc} ($where) (Error: $first)\n";
    $text .= join( '', map { "      $_\n" } @lines );
    return $text;
}

# Usage     : my $pid = $tests->start_worker($module, $opt)
# Purpose   : Forks the worker that runs one module's tests in its own process group; its results go
#             to a file the parent reads when it ends.
# Returns   : The worker's PID (its process group), or undef after an [ ERROR ] line.
sub start_worker
{
    my ( $self, $module, $opt ) = @_;
    my $file = "$self->{sandbox}/run/" . ( $module->{key} =~ s{/}{-}gr ) . '.result';
    $module->{result_file} = $file;
    my $pid = fork();
    if ( !defined $pid ) {
        AAPP::Logger::print_msg( 'ERROR', "Cannot start a worker for $module->{key}: $!" );
        return;
    }
    if ( $pid == 0 ) {
        POSIX::setpgid( 0, 0 );
        @AAPP::Runner::cleanups = ( sub { $self->stop_live() } );
        $self->{live} = {};
        my $result = $self->run_module( $module, $opt );
        Storable::nstore( $result, $file );
        POSIX::_exit(0);
    }
    # Set by both sides, so the group exists before either uses it; the second call may find it set.
    POSIX::setpgid( $pid, $pid );
    $self->{live}{$pid} = 1;
    return $pid;
}

# Usage     : my $result = $tests->worker_result($module, $wait_status)
# Purpose   : Reads a finished worker's results; a worker that left none fails each of its tests.
# Returns   : { tests => [...], secs, error }.
sub worker_result
{
    my ( $self, $module, $status ) = @_;
    my $file = $module->{result_file};
    if ( -f $file ) {
        return Storable::retrieve($file);
    }
    my $why = 'the worker ended (' . wait_text($status) . ') without results';
    return { secs => 0, error => $why, tests => [ map { result_of( $_, 'fail', error => $why ) } @{ $module->{tests} } ] };
}

# Usage     : my $text = wait_text($?)
# Purpose   : A wait status in words.
# Returns   : 'exit N' or 'signal N'.
sub wait_text
{
    my ($status) = @_;
    return $status & 127 ? 'signal ' . ( $status & 127 ) : 'exit ' . ( $status >> 8 );
}

# Usage     : my $r = result_of($test, 'fail', error => $text)
# Purpose   : One test's result record.
# Returns   : The record.
sub result_of
{
    my ( $test, $status, %extra ) = @_;
    return { ( map { $_ => $test->{$_} } qw(index key name desc) ), status => $status, %extra };
}

# Usage     : my $result = $tests->run_module($module, $opt)
# Purpose   : In the worker: builds the module's fixture once (in its own sandbox when the module asks for
#             one), then runs each test in a fresh copy of it under the watchdog.
# Returns   : { tests => [...], secs, error }.
sub run_module
{
    my ( $self, $module, $opt ) = @_;
    my $t0      = Time::HiRes::time();
    my $package = $module->{package};
    my $base    = "$self->{sandbox}/work/" . ( $module->{key} =~ s{/}{-}gr );
    File::Path::make_path("$base/scratch");
    if ( $package->can('own_sandbox') && $package->own_sandbox() ) {
        $self->{shared_sandbox} = $self->{sandbox};
        $self->make_sandbox() or return { secs => 0, error => 'own sandbox failed', tests => [] };
    }
    my $fixture = "$base/fixture";
    File::Path::make_path($fixture);
    my @results;
    my $fixture_error;
    if ( $package->can('fixture') ) {
        my $r = $self->run_isolated( $package->can('fixture'), $fixture, "$base/scratch", TEST_WATCHDOG_SECONDS );
        $fixture_error = "fixture failed: $r->{error}" if $r->{status} ne 'pass';
    }
    foreach my $test ( @{ $module->{tests} } ) {
        if ( defined $fixture_error ) {
            push @results, result_of( $test, 'fail', error => $fixture_error );
            next;
        }
        my $dir = "$base/t$test->{index}";
        my $copied = eval { copy_fixture( $fixture, $dir ); 1 };
        if ( !$copied ) {
            push @results, result_of( $test, 'fail', error => "fixture copy failed: $@" );
            next;
        }
        my $timeout = test_timeout( $package, $test->{name} );
        $self->{test} = $test;
        my $r = $self->run_isolated( $package->can( $test->{name} ), $dir, "$base/scratch", $timeout );
        push @results, result_of( $test, $r->{status}, error => $r->{error}, reason => $r->{reason} );
        File::Path::remove_tree($dir);
        last if $opt->{bail} && $r->{status} eq 'fail';
    }
    if ( $self->{shared_sandbox} ) {
        $self->remove_sandbox();
    }
    return { secs => Time::HiRes::time() - $t0, tests => \@results };
}

# Usage     : my $seconds = test_timeout($package, 'test_name')
# Purpose   : A test's watchdog: the module's %TIMEOUT entry, else the harness default.
# Returns   : Seconds.
sub test_timeout
{
    my ( $package, $name ) = @_;
    my $glob = ( package_stash($package) // {} )->{TIMEOUT};
    my $own  = defined $glob && *{$glob}{HASH} ? *{$glob}{HASH}->{$name} : undef;
    return defined $own ? $own : TEST_WATCHDOG_SECONDS;
}

# Usage     : my $r = $tests->run_isolated($code, $dir, $scratch, $timeout)
# Purpose   : Runs $code->($self) in a child of its own process group, in $dir, under a $timeout
#             watchdog. A timeout or an interrupt kills the whole group, so no git or aapp child survives.
# Returns   : { status => 'pass'|'fail'|'skip', error, reason }.
sub run_isolated
{
    my ( $self, $code, $dir, $scratch, $timeout ) = @_;
    my $n           = ++$self->{counter};
    my $result_file = "$scratch/result.$n";
    my $output_file = "$scratch/output.$n";
    my $pid         = fork();
    if ( !defined $pid ) {
        return { status => 'fail', error => "cannot fork: $!" };
    }
    if ( $pid == 0 ) {
        POSIX::setpgid( 0, 0 );
        @AAPP::Runner::cleanups = ();
        $SIG{$_} = 'DEFAULT' for qw(INT TERM HUP ALRM);
        open( STDIN,  '<', File::Spec->devnull() ) or POSIX::_exit(126);
        open( STDOUT, '>', $output_file )          or POSIX::_exit(126);
        open( STDERR, '>&', \*STDOUT )             or POSIX::_exit(126);
        STDOUT->autoflush(1);
        STDERR->autoflush(1);
        $self->{dir}     = $dir;
        $self->{scratch} = $scratch;
        my %r;
        if ( !chdir($dir) ) {
            %r = ( status => 'fail', error => "cannot enter $dir: $!" );
        } else {
            my $ret = eval { $code->($self) };
            my $err = $@;
            if ( $err ne '' ) {
                %r = ( status => 'fail', error => $err =~ s/\s+$//r );
            } elsif ( ref($ret) eq 'SCALAR' ) {
                %r = ( status => 'skip', reason => ${$ret} );
            } elsif ( defined $ret && !ref($ret) && $ret eq '1' ) {
                %r = ( status => 'pass' );
            } else {
                %r = ( status => 'fail', error => 'the test returned ' . ( defined $ret ? "'$ret'" : 'nothing' ) . ' instead of 1' );
            }
        }
        Storable::nstore( \%r, $result_file );
        exit 0;
    }
    POSIX::setpgid( $pid, $pid );
    $self->{live}{$pid} = 1;
    my $timed_out = 0;
    {
        local $SIG{ALRM} = sub { $timed_out = 1; kill 'TERM', -$pid; kill 'KILL', -$pid; };
        alarm($timeout);
        waitpid( $pid, 0 );
        alarm(0);
    }
    my $status = $?;
    delete $self->{live}{$pid};
    kill 'KILL', -$pid;
    my $output = read_text($output_file);
    unlink($output_file);
    my $r;
    if ($timed_out) {
        $r = { status => 'fail', error => "timed out after ${timeout}s; the watchdog killed its process group" };
    } elsif ( -f $result_file ) {
        $r = Storable::retrieve($result_file);
    } else {
        $r = { status => 'fail', error => 'the test process ended (' . wait_text($status) . ') without a result' };
    }
    unlink($result_file);
    if ( $r->{status} eq 'fail' && $output ne '' ) {
        my @lines = split( /\n/, $output );
        splice( @lines, 0, @lines - TEST_RECAP_LINES ) if @lines > TEST_RECAP_LINES;
        $r->{error} .= "\noutput:\n" . join( "\n", @lines );
    }
    return $r;
}

# Usage     : $tests->stop_live()
# Purpose   : Stops the process group of every running worker or test: TERM, up to TEST_STOP_GRACE_SECONDS
#             for each to end (a worker then stops its own test's group), then KILL for what is left.
# Returns   : 1
sub stop_live
{
    my ($self) = @_;
    my @pids = keys %{ $self->{live} };
    kill 'TERM', -$_ for @pids;
    my %left  = map { $_ => 1 } @pids;
    my $until = Time::HiRes::time() + TEST_STOP_GRACE_SECONDS;
    while ( %left && Time::HiRes::time() < $until ) {
        foreach my $pid ( keys %left ) {
            delete $left{$pid} if waitpid( $pid, POSIX::WNOHANG() ) != 0;
        }
        Time::HiRes::sleep(0.05) if %left;
    }
    kill 'KILL', -$_ for @pids;
    $self->{live} = {};
    return 1;
}

# Usage     : $tests->make_sandbox() or return RETURN_ERROR
# Purpose   : One disposable home with an installed kit (HOME/.local/bin/aapp, HOME/.local/share/aapp-kit)
#             and the developer's git identity, gpg signing off; the environment points into it.
# Returns   : 1, or 0 after an [ ERROR ] line.
sub make_sandbox
{
    my ($self) = @_;
    my $root = Cwd::abs_path( File::Temp::tempdir( TEST_SANDBOX_PREFIX . '-XXXXXX', TMPDIR => 1, CLEANUP => 0 ) );
    $self->{sandbox} = $root;
    if ( index( "$root/", "$self->{kit}/" ) == 0 ) {
        AAPP::Logger::print_msg( 'ERROR', "The sandbox $root lies inside the kit checkout; set TMPDIR elsewhere." );
        return 0;
    }
    my $name   = git_global('user.name')          // TEST_GIT_NAME;
    my $email  = git_global('user.email')         // TEST_GIT_EMAIL;
    my $branch = git_global('init.defaultBranch') // TEST_DEFAULT_BRANCH;
    my $home   = "$root/home";
    my $bin    = "$home/.local/bin";
    my $share  = "$home/.local/share";
    File::Path::make_path( $bin, "$share/aapp-kit", "$home/.config", "$home/.local/state", "$root/run", "$root/work" );
    write_text( "$home/.gitconfig",
        "[user]\n\tname = $name\n\temail = $email\n[commit]\n\tgpgsign = false\n[tag]\n\tgpgsign = false\n[init]\n\tdefaultBranch = $branch\n" );
    my $installed = eval {
        File::Copy::copy( "$self->{kit}/aapp", "$bin/aapp" ) or die "cannot copy aapp: $!\n";
        chmod( 0755, "$bin/aapp" ) or die "cannot make aapp executable: $!\n";
        copy_tree( "$self->{kit}/$_", "$share/aapp-kit/$_" ) for @KIT_PARTS;
        1;
    };
    if ( !$installed ) {
        AAPP::Logger::print_msg( 'ERROR', "Cannot install the kit into the sandbox: $@" );
        return 0;
    }
    foreach my $key ( keys %ENV ) {
        delete $ENV{$key} if grep { index( $key, $_ ) == 0 } @ENV_DROP_PREFIXES;
    }
    my @path = grep { $_ ne '' && !-x "$_/aapp" } split( /:/, $ENV{PATH} // '' );
    $ENV{HOME}                = $home;
    $ENV{XDG_DATA_HOME}       = $share;
    $ENV{XDG_CONFIG_HOME}     = "$home/.config";
    $ENV{XDG_STATE_HOME}      = "$home/.local/state";
    $ENV{GIT_CONFIG_NOSYSTEM} = 1;
    $ENV{PATH}                = join( ':', $bin, @path );
    my $found = which('aapp') // '';
    if ( $found ne "$bin/aapp" ) {
        AAPP::Logger::print_msg( 'ERROR', "aapp resolves to '$found', not the sandbox's $bin/aapp; nothing was run." );
        return 0;
    }
    return 1;
}

# Usage     : $tests->remove_sandbox()
# Purpose   : Removes the current sandbox (in the process that made it) and returns to the shared one.
# Returns   : 1
sub remove_sandbox
{
    my ($self) = @_;
    my $root = $self->{sandbox};
    if ( defined $root && -d $root && ( $$ == $self->{owner} || $self->{shared_sandbox} ) ) {
        chdir('/');
        File::Path::remove_tree($root);
    }
    $self->{sandbox} = delete $self->{shared_sandbox};
    return 1;
}

# Usage     : my $value = git_global('user.name')
# Purpose   : A setting of the developer's global git configuration, read before the sandbox replaces HOME.
# Returns   : The value, or undef when unset or empty.
sub git_global
{
    my ($key) = @_;
    my ( $ok, $out ) = AAPP::Paths::git_capture( 'config', '--global', $key );
    chomp($out);
    return $ok && $out ne '' ? $out : undef;
}

# Usage     : my $path = which('aapp')
# Purpose   : The first executable of that name on PATH (':'-separated: the harness runs on POSIX Perls only).
# Returns   : Its path, or undef.
sub which
{
    my ($name) = @_;
    foreach my $dir ( split( /:/, $ENV{PATH} // '' ) ) {
        return "$dir/$name" if $dir ne '' && -f "$dir/$name" && -x _;
    }
    return;
}

# Usage     : my $n = $tests->default_jobs()
# Purpose   : The CPU count rounded down to a multiple of TEST_JOBS_STEP (below it, the CPU count);
#             an unreadable count runs one module at a time, with a notice.
# Returns   : The number of workers.
sub default_jobs
{
    my ($self) = @_;
    my $n = $self->cpu_count();
    if ( !$n ) {
        AAPP::Logger::print_msg( 'NOTICE', "CPU count unreadable; running files one at a time (set 'jobs <n>' to override)." );
        return 1;
    }
    return $n >= TEST_JOBS_STEP ? int( $n / TEST_JOBS_STEP ) * TEST_JOBS_STEP : $n;
}

# Usage     : my $n = $tests->cpu_count()
# Purpose   : The online CPUs: getconf (Linux, macOS, BSD), else sysctl (macOS, BSD), else
#             NUMBER_OF_PROCESSORS (Windows shells).
# Returns   : The count, or 0 when none of them answers.
sub cpu_count
{
    my ($self) = @_;
    foreach my $cmd ( [ 'getconf', '_NPROCESSORS_ONLN' ], [ 'sysctl', '-n', 'hw.ncpu' ] ) {
        next if !defined which( $cmd->[0] );
        my $r = $self->run_cmd( { scratch => "$self->{sandbox}/run" }, @{$cmd} );
        my $n = $r->{out} =~ s/\s+$//r;
        return $n if $r->{exit} == 0 && $n =~ /^[1-9][0-9]*$/;
    }
    my $env = $ENV{NUMBER_OF_PROCESSORS} // '';
    return $env =~ /^[1-9][0-9]*$/ ? $env : 0;
}

# Usage     : copy_fixture($from, $to)
# Purpose   : Copies a module's fixture into a test's directory and points its worktree files at the copy.
# Returns   : 1; dies when the copy fails.
sub copy_fixture
{
    my ( $from, $to ) = @_;
    copy_tree( $from, $to );
    foreach my $rel (@POINTER_FILES) {
        my $file = "$to/$rel";
        next if !-f $file;
        my $text = read_text($file);
        $text =~ s/\Q$from\E/$to/g;
        write_text( $file, $text );
    }
    return 1;
}

# Usage     : copy_tree($from, $to)
# Purpose   : Copies a directory tree, keeping file modes and symbolic links as links.
# Returns   : 1; dies when an entry cannot be copied.
sub copy_tree
{
    my ( $from, $to ) = @_;
    File::Path::make_path($to);
    File::Find::find(
        {
            no_chdir => 1,
            wanted   => sub {
                my $src = $File::Find::name;
                return if $src eq $from;
                my $dst = $to . substr( $src, length($from) );
                if ( -l $src ) {
                    symlink( readlink($src), $dst ) or die "cannot link $dst: $!\n";
                } elsif ( -d $src ) {
                    mkdir($dst) or die "cannot make $dst: $!\n";
                } else {
                    File::Copy::copy( $src, $dst ) or die "cannot copy $src: $!\n";
                    chmod( ( stat($src) )[2] & oct(7777), $dst ) or die "cannot set the mode of $dst: $!\n";
                }
            },
        },
        $from
    );
    return 1;
}

# Usage     : my $text = read_text($file)
# Purpose   : A file's content as text (UTF-8; a malformed byte becomes a replacement character).
# Returns   : The text; '' when the file is missing.
sub read_text
{
    my ($file) = @_;
    open( my $fh, '<:raw', $file ) or return '';
    my $bytes = do { local $/; <$fh> } // '';
    close($fh);
    return Encode::decode( 'UTF-8', $bytes );
}

# Usage     : write_text($file, $text)
# Purpose   : Writes text to a file as UTF-8.
# Returns   : 1; dies when the file cannot be written.
sub write_text
{
    my ( $file, $text ) = @_;
    open( my $fh, '>:encoding(UTF-8)', $file ) or die "cannot write $file: $!\n";
    print {$fh} $text;
    close($fh) or die "cannot write $file: $!\n";
    return 1;
}

# ---------------------------------------------------------
# Helpers for test modules ($self in a test_ sub)
# ---------------------------------------------------------

# Usage     : my $where = where()
# Purpose   : The test file line that called a helper (the first caller outside AAPP::Tests).
# Returns   : 't/<area>/<name>.t:<line>'.
sub where
{
    my $i = 0;
    while ( my @frame = caller( $i++ ) ) {
        next if $frame[0] eq __PACKAGE__;
        my $file = $frame[1] =~ s{^.*/(\Q$TEST_DIR\E/[^/]+/[^/]+\.t)$}{$1}r;
        return "$file:$frame[2]";
    }
    return 'unknown';
}

# Usage     : my $r = $self->run_cmd([{ stdin => $text },] @command)
# Purpose   : Runs a command in the test's directory (in the test's process group), stdin empty unless given.
# Returns   : { exit, out, err }: the exit code (128 + signal when killed) and the decoded output.
sub run_cmd
{
    my ( $self, @cmd ) = @_;
    my $opt     = ref( $cmd[0] ) eq 'HASH' ? shift(@cmd) : {};
    my $scratch = $opt->{scratch} // $self->{scratch};
    my $n       = ++$self->{counter};
    my ( $in, $out, $err ) = map { "$scratch/cmd.$$.$n.$_" } qw(in out err);
    write_text( $in, $opt->{stdin} // '' );
    my $pid = fork();
    die where() . ": cannot fork for '$cmd[0]': $!\n" if !defined $pid;
    if ( $pid == 0 ) {
        open( STDIN,  '<', $in )  or POSIX::_exit(126);
        open( STDOUT, '>', $out ) or POSIX::_exit(126);
        open( STDERR, '>', $err ) or POSIX::_exit(126);
        { exec { $cmd[0] } @cmd };
        print STDERR "cannot run '$cmd[0]': $!\n";
        POSIX::_exit(127);
    }
    waitpid( $pid, 0 );
    my $status = $?;
    my %r = ( exit => $status & 127 ? 128 + ( $status & 127 ) : $status >> 8, out => read_text($out), err => read_text($err) );
    unlink( $in, $out, $err );
    return \%r;
}

# Usage     : my $r = $self->run_aapp(@args)
# Purpose   : Runs the sandbox's aapp with the arguments.
# Returns   : { exit, out, err }.
sub run_aapp
{
    my ( $self, @args ) = @_;
    my $opt = ref( $args[0] ) eq 'HASH' ? shift(@args) : {};
    return $self->run_cmd( $opt, 'aapp', @args );
}

# Usage     : my $r = $self->ok_cmd(@command)
# Purpose   : Runs a command that must succeed; dies naming the test line, the command, its exit and output.
# Returns   : { exit, out, err }.
sub ok_cmd
{
    my ( $self, @cmd ) = @_;
    my $r = $self->run_cmd(@cmd);
    die where() . ': `' . cmd_text(@cmd) . "` exited $r->{exit}\n" . output_text($r) if $r->{exit} != 0;
    return $r;
}

# Usage     : my $r = $self->fail_cmd(@command)
# Purpose   : Runs a command that must fail; dies naming the test line and the command when it succeeds.
# Returns   : { exit, out, err }.
sub fail_cmd
{
    my ( $self, @cmd ) = @_;
    my $r = $self->run_cmd(@cmd);
    die where() . ': `' . cmd_text(@cmd) . "` succeeded but must fail\n" . output_text($r) if $r->{exit} == 0;
    return $r;
}

# Usage     : $self->eq_or_die($got, $want, 'what is compared')
# Purpose   : Dies naming the test line, the label and both values when they differ.
# Returns   : 1
sub eq_or_die
{
    my ( $self, $got, $want, $label ) = @_;
    my ( $g, $w ) = map { defined $_ ? $_ : '(undef)' } ( $got, $want );
    die where() . ": $label: want [$w] got [$g]\n" if $g ne $w;
    return 1;
}

# Usage     : $self->match_or_die($got, qr/.../, 'what is matched')
# Purpose   : Dies naming the test line, the label, the pattern and the text when it does not match.
# Returns   : 1
sub match_or_die
{
    my ( $self, $got, $re, $label ) = @_;
    my $text = defined $got ? $got : '(undef)';
    die where() . ": $label: [$text] does not match $re\n" if $text !~ $re;
    return 1;
}

# Usage     : $self->true_or_die($condition, 'what must hold', $detail)
# Purpose   : Dies naming the test line, the label and an optional detail when the condition is false.
# Returns   : 1
sub true_or_die
{
    my ( $self, $condition, $label, $detail ) = @_;
    die where() . ": $label" . ( defined $detail ? ": $detail" : '' ) . "\n" if !$condition;
    return 1;
}

# Usage     : $self->file_exists_or_die('path/in/the/test')
# Purpose   : Dies naming the test line when the file does not exist.
# Returns   : 1
sub file_exists_or_die
{
    my ( $self, $path ) = @_;
    die where() . ": file '$path' does not exist\n" if !-e $path;
    return 1;
}

# Usage     : return $self->skip('why this test cannot run here')
# Purpose   : Marks the test as skipped, printed as 'ok N - <description> # SKIP <reason>'.
# Returns   : A reference to the reason.
sub skip
{
    my ( $self, $reason ) = @_;
    my $text = defined $reason && $reason ne '' ? $reason : 'no reason given';
    return \$text;
}

# Usage     : my $r = $self->lib_call([{ stdin => $text },] 'text', 'out_wrap', $text, 2, 8, 60)
# Purpose   : Calls a kit library function the way %LIBRARIES says: a Perl module's function in a fork of
#             the test process (fresh caches, as in a new aapp run), a bash library's through bash; stdin
#             is empty unless given.
# Returns   : { exit, out, err, ret }: ret holds a Perl function's return list, or a bash function's
#             stdout lines. Dies when the library is unknown or the Perl function dies.
sub lib_call
{
    my ( $self, @call ) = @_;
    my $opt = ref( $call[0] ) eq 'HASH' ? shift(@call) : {};
    my ( $library, $function, @args ) = @call;
    my $target = $LIBRARIES{$library};
    die where() . ": lib_call: unknown library '$library' (see \%AAPP::Tests::LIBRARIES)\n" if !defined $target;
    if ( $target =~ /^AAPP::/ ) {
        return $self->perl_call( $opt, $target, $function, @args );
    }
    my $r = $self->run_cmd( $opt, 'bash', '-c', '. "$1"; . "$2"; shift 2; "$@"', 'bash', "$self->{kit}/$BASH_BASE_LIBRARY",
        "$self->{kit}/$target", $function, @args );
    $r->{ret} = [ split( /\n/, $r->{out} ) ];
    return $r;
}

# Usage     : my $r = $self->perl_call({ stdin => $text }, 'AAPP::Text', 'out_wrap', @args)
# Purpose   : lib_call's Perl side: the function runs in a forked child with its output captured and
#             its stdin read from the given text as UTF-8 (as 'perl -CSA' gives an aapp run).
# Returns   : { exit, out, err, ret }; dies when the function does not exist or dies.
sub perl_call
{
    my ( $self, $opt, $package, $function, @args ) = @_;
    my $n = ++$self->{counter};
    my ( $in, $out, $err, $ret ) = map { "$self->{scratch}/call.$$.$n.$_" } qw(in out err ret);
    write_text( $in, $opt->{stdin} // '' );
    my $pid = fork();
    die where() . ": cannot fork for ${package}::$function: $!\n" if !defined $pid;
    if ( $pid == 0 ) {
        open( STDIN,  '<:encoding(UTF-8)', $in ) or POSIX::_exit(126);
        open( STDOUT, '>', $out )                or POSIX::_exit(126);
        open( STDERR, '>', $err )                or POSIX::_exit(126);
        binmode( $_, ':encoding(UTF-8)' ) for \*STDOUT, \*STDERR;
        my %r;
        my $done = eval {
            require( ( $package =~ s{::}{/}gr ) . '.pm' );
            my $code = $package->can($function) or die "${package}::$function does not exist\n";
            $r{ret} = [ $code->(@args) ];
            1;
        };
        $r{died} = $@ if !$done;
        STDOUT->flush();
        STDERR->flush();
        Storable::nstore( \%r, $ret );
        exit 0;
    }
    waitpid( $pid, 0 );
    my $status = $?;
    my %r = ( exit => $status & 127 ? 128 + ( $status & 127 ) : $status >> 8, out => read_text($out), err => read_text($err), ret => [] );
    my $got = -f $ret ? Storable::retrieve($ret) : {};
    unlink( $in, $out, $err, $ret );
    die where() . ": ${package}::$function died: $got->{died}" if defined $got->{died};
    $r{ret} = $got->{ret} // [];
    return \%r;
}

# Usage     : $self->init_repo()
# Purpose   : A fixture step: an empty git repository in the current directory.
# Returns   : 1; dies when git fails.
sub init_repo
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'init', '-q', '.' );
    return 1;
}

# Usage     : $self->init_project()
# Purpose   : A fixture step: a git repository with one commit and the kit initialized (aapp init).
# Returns   : 1; dies when a step fails.
sub init_project
{
    my ($self) = @_;
    $self->init_repo();
    write_text( 'main.py', "print('hello')\n" );
    $self->ok_cmd( 'git', 'add', 'main.py' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'initial commit' );
    $self->ok_cmd( 'aapp', 'init' );
    return 1;
}

# Usage     : my $text = cmd_text(@command)
# Purpose   : A command as one readable line.
# Returns   : The text.
sub cmd_text
{
    my (@cmd) = @_;
    return join( ' ', map { /^[\w.\/:=@+-]+$/ ? $_ : "'" . s/'/'\\''/gr . "'" } @cmd );
}

# Usage     : my $text = output_text($r)
# Purpose   : A command's output for a failure message: stdout and stderr, at most TEST_RECAP_LINES lines each.
# Returns   : The text, ending with a newline, or '' when there was none.
sub output_text
{
    my ($r) = @_;
    my $text = '';
    foreach my $stream (qw(out err)) {
        my @lines = split( /\n/, $r->{$stream} // '' );
        next if !@lines;
        splice( @lines, 0, @lines - TEST_RECAP_LINES ) if @lines > TEST_RECAP_LINES;
        $text .= "$stream:\n" . join( '', map { "  $_\n" } @lines );
    }
    return $text;
}

1;
