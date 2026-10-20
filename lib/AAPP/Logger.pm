package AAPP::Logger;

use strict;
use warnings;
use 5.026;

use POSIX ();
use AAPP::Constants qw(DEBUG_LEVEL LOG_KEY);
use AAPP::Config ();
use AAPP::Paths ();

our $quiet = 0;

# Usage     : AAPP::Logger::print_msg('NOTICE', $message)
# Purpose   : Prints one line for the agent in the standard format, and logs it.
#             NOTICE and INFO go to STDOUT (not with $quiet); WARN, ERROR and FATAL to STDERR.
# Returns   : 1
sub print_msg
{
    my ( $tag, $message ) = @_;
    my $to_err = $tag =~ /^(?:WARN|ERROR|FATAL)$/;
    if ($to_err) {
        printf STDERR "[ %-6s ] %s\n", $tag, $message;
    } elsif ( !$quiet ) {
        printf STDOUT "[ %-6s ] %s\n", $tag, $message;
    }
    log_output( 0, $tag, $message );
    return 1;
}

# Usage     : AAPP::Logger::log_output($min_debug, $tag, $message)
# Purpose   : Appends a timestamped line to the log file when aapp.perlLogFile is set and DEBUG_LEVEL >= $min_debug.
# Returns   : 1, or 0 when the log file cannot be written.
sub log_output
{
    my ( $min_debug, $tag, $message ) = @_;
    return 1 if DEBUG_LEVEL < $min_debug;
    my $file = log_file() // return 1;
    open( my $fh, '>>', $file ) or return 0;
    printf {$fh} "%s [%s] %s\n", POSIX::strftime( '%Y-%m-%d %H:%M:%S', localtime ), $tag, $message;
    close($fh) or return 0;
    return 1;
}

# Usage     : my $file = AAPP::Logger::log_file()
# Purpose   : Resolves aapp.perlLogFile; a relative path is taken from the repository's common git dir.
# Returns   : Absolute path, or undef when no log file is configured.
sub log_file
{
    my $file = AAPP::Config::get(LOG_KEY);
    return if !defined $file || $file eq '';
    return $file if $file =~ m{^/};
    my $common = AAPP::Paths::resolve()->{common_dir} // return;
    return "$common/$file";
}

1;
