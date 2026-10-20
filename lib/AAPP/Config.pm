package AAPP::Config;

use strict;
use warnings;
use 5.026;

use AAPP::Constants qw(RETURN_OK RETURN_ERROR);
use AAPP::Logger ();

our %config;
our $loaded = 0;

# Usage     : AAPP::Config::load()
# Purpose   : Reads every git config value of the repository once (git config --list -z) into %config.
# Returns   : RETURN_OK, or RETURN_ERROR when git config cannot be read.
sub load
{
    return RETURN_OK if $loaded;
    open( my $fh, '-|', 'git', 'config', '--list', '-z' ) or return RETURN_ERROR;
    local $/ = "\0";
    while ( my $entry = <$fh> ) {
        chomp($entry);
        my ( $key, $value ) = split( /\n/, $entry, 2 );
        push @{ $config{ lc $key } }, $value // '';
    }
    close($fh) or return RETURN_ERROR;
    $loaded = 1;
    return RETURN_OK;
}

# Usage     : my $v = AAPP::Config::get('aapp.perlLogFile')
# Purpose   : Returns the last value of a key, as git does for single-valued keys.
# Returns   : The value, or undef when unset.
sub get
{
    my ($key) = @_;
    load();
    my $all = $config{ lc $key } or return;
    return $all->[-1];
}

# Usage     : my @v = AAPP::Config::get_all('aapp.allowPath')
# Purpose   : Returns every value of a multi-valued key, in config order.
# Returns   : List of values; empty when unset.
sub get_all
{
    my ($key) = @_;
    load();
    return @{ $config{ lc $key } // [] };
}

# Usage     : my ($rc, $n) = AAPP::Config::get_int('aapp.statusOutputWidth', 85, 40)
# Purpose   : Returns a whole-number setting, its default when unset; a value below $min or not a number is an error.
# Returns   : (RETURN_OK, $value), or (RETURN_ERROR, undef) after an [ ERROR ] line naming the key.
sub get_int
{
    my ( $key, $default, $min ) = @_;
    my $v = get($key);
    return ( RETURN_OK, $default ) if !defined $v;
    if ( $v !~ /^\d+$/ || ( defined $min && $v < $min ) ) {
        AAPP::Logger::say( 'ERROR', sprintf( "%s is '%s'; it must be a whole number%s.", $key, $v, defined $min ? " of at least $min" : '' ) );
        return ( RETURN_ERROR, undef );
    }
    return ( RETURN_OK, $v );
}

# Usage     : my @keys = AAPP::Config::keys_with_prefix('aapp.planState.')
# Purpose   : Lists the keys that start with a prefix, for registries such as aapp.planState.*.
# Returns   : Sorted list of keys.
sub keys_with_prefix
{
    my ($prefix) = @_;
    load();
    return sort grep { index( $_, lc $prefix ) == 0 } keys %config;
}

1;
