package AAPP::Runner;

use strict;
use warnings;
use 5.026;

use AAPP::Constants qw(DEBUG_LEVEL RETURN_OK RETURN_ERROR RETURN_FAIL %EXIT_FOR);
use AAPP::Logger ();

our $return = RETURN_OK;
our @args;
our $global_json  = 0;
our $global_quiet = 0;
our @cleanups;

# Usage     : init_signals()
# Purpose   : Registers signal handlers (HUP, TERM, INT) and error hooks (__WARN__, __DIE__).
# Returns   : undef
sub init_signals
{
    $SIG{HUP} = $SIG{TERM} = $SIG{INT} = \&cleanup;

    $SIG{__WARN__} = sub
    {
        my $msg = shift;
        chomp($msg);
        AAPP::Logger::log_output( 0, 'WARN', "[Perl::Warning] " . $msg );
        printf STDERR "[ %-6s ] %s\n", 'WARN', $msg;
    };

    $SIG{__DIE__} = sub
    {
        my $msg = shift;
        return if $^S;

        $msg =~ s/ at .*? line \d+\.?\n?$//s;
        $msg =~ s/\n$//;
        chomp($msg);

        $msg = "[FATAL ERROR]:[Perl] " . $msg if ( $msg !~ /^(?:AAPP|System)/ );
        $msg =~ s/^AAPP[:]?/[FATAL ERROR]:[AAPP]/;
        $msg =~ s/^System[:]?/[FATAL ERROR]:[System]/;

        my ( undef, $filename, $line ) = caller(0);

        my $stack = '';
        if ( DEBUG_LEVEL >= 1 ) {
            $stack = "    Full stack:\n";
            my $i = 0;
            while ( my @info = caller( $i++ ) ) {
                $stack .= "    Called from $info[1] at line $info[2] in subroutine $info[3]\n";
            }
        }

        logger( $msg, $filename, $line, $stack );
    };
    return;
}

# Usage     : exit_code()
# Purpose   : Maps $return status value to OS process exit code and terminates execution.
#             A value not declared in AAPP::Constants is itself a crash.
# Returns   : Does not return (calls exit).
sub exit_code
{
    die( "AAPP: undeclared return value '" . ( $return // 'undef' ) . "'" ) if !defined $return || !exists $EXIT_FOR{$return};
    exit $EXIT_FOR{$return};
}

# Usage     : return_on_error()
# Purpose   : Sets return status to RETURN_ERROR and exits with failure.
# Returns   : Does not return.
sub return_on_error
{
    $return = RETURN_ERROR;
    exit_code();
    return;
}

# Usage     : cleanup()
# Purpose   : Runs the registered cleanups (temporary files, child process groups) on termination signals.
# Returns   : Does not return (exits with failure).
sub cleanup
{
    $_->() for reverse @cleanups;
    @cleanups = ();
    return_on_error();
    return;
}

# Usage     : no_log_file($msg, $file, $line, $stack, $syserr)
# Purpose   : Prints a fatal error to STDERR when no log file is configured.
# Returns   : Does not return.
sub no_log_file
{
    my ( $msg, $file, $line, $stack, $syserr ) = @_;
    my $text = sprintf( "%s (file: %s line: %s)%s", $msg, $file, $line, $syserr ? " ($syserr)" : '' );
    printf STDERR "[ %-6s ] %s\n%s", 'FATAL', $text, $stack;
    return_on_error();
    return;
}

# Usage     : unopened_log_file($syserr)
# Purpose   : Prints a warning when the log file cannot be written, then exits with failure.
# Returns   : Does not return.
sub unopened_log_file
{
    my ($syserr) = @_;
    printf STDERR "[ %-6s ] Could not write to log file %s%s\n", 'WARN', AAPP::Logger::log_file() // '', $syserr ? ": $syserr" : '';
    return_on_error();
    return;
}

# Usage     : print_error_msg($message, $file, $line, $stack)
# Purpose   : Appends the fatal error to the log file and prints it to STDERR, so the agent sees it.
# Returns   : Does not return.
sub print_error_msg
{
    my ( $message, $file, $line, $stack ) = @_;
    my $text = sprintf( "%s (file: %s line: %s)", $message, $file, $line );
    printf STDERR "[ %-6s ] %s\n%s", 'FATAL', $text, $stack;
    unopened_log_file($!) if !AAPP::Logger::log_output( 0, 'FATAL', $text . ( $stack ? "\n$stack" : '' ) );
    return_on_error();
    return;
}

# Usage     : logger($message, $file, $line, $stack)
# Purpose   : Routes an uncaught fatal error to the configured log file, or to STDERR alone.
# Returns   : undef
sub logger
{
    my ( $message, $file, $line, $stack ) = @_;
    local $! = 0;
    if ( defined AAPP::Logger::log_file() ) {
        print_error_msg( $message, $file, $line, $stack );
    } else {
        no_log_file( $message, $file, $line, $stack, $! );
    }
    return;
}

# Usage     : AAPP::Runner::run(@run_args)
# Purpose   : CLI entry point. Takes the global tokens (json, quiet), installs the handlers,
#             dispatches the verb to AAPP::Cmd::<Verb>->run(@args), and exits with its return number.
# Returns   : Does not return.
sub run
{
    my (@run_args) = @_;
    @args = ();
    foreach my $arg (@run_args) {
        if    ( $arg eq 'json' )  { $global_json  = 1; }
        elsif ( $arg eq 'quiet' ) { $global_quiet = 1; }
        else                      { push @args, $arg; }
    }
    $AAPP::Logger::quiet = $global_quiet;

    init_signals();

    my $verb = shift(@args) // 'help';
    ( my $module = join( '', map { ucfirst } split( /-/, $verb ) ) ) =~ s/[^A-Za-z]//g;
    my $class = "AAPP::Cmd::$module";
    if ( eval "require $class; 1" ) {
        $return = $class->run(@args);
    } else {
        AAPP::Logger::say( 'ERROR', "Unknown verb '$verb'. Run 'aapp help'." );
        $return = RETURN_FAIL;
    }
    exit_code();
    return;
}

1;
