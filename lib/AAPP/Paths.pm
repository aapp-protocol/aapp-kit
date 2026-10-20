package AAPP::Paths;

use strict;
use warnings;
use 5.026;

use Cwd ();

our %paths;

# Usage     : my $p = AAPP::Paths::resolve()
# Purpose   : Reads the repository root, git dir and common dir with one git rev-parse, once per process.
# Returns   : Hash ref {root, git_dir, common_dir}; empty hash ref outside a repository.
sub resolve
{
    return \%paths if %paths;
    open( my $fh, '-|', 'git', 'rev-parse', '--show-toplevel', '--absolute-git-dir', '--git-common-dir' ) or return {};
    chomp( my @lines = <$fh> );
    close($fh) or return {};
    return {} if @lines != 3;
    # git prints a relative common dir against the current directory, not the root.
    my $common = Cwd::abs_path( $lines[2] ) // return {};
    %paths = ( root => $lines[0], git_dir => $lines[1], common_dir => $common );
    return \%paths;
}

1;
