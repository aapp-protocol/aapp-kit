package AAPP::Hooks::PreCommitDevelop;

use strict;
use warnings;
use utf8;
use 5.026;

use AAPP::Constants qw(RETURN_OK RETURN_ERROR RETURN_FAIL);
use AAPP::Paths ();

# Usage     : my $rc = AAPP::Hooks::PreCommitDevelop->run()
# Purpose   : Master entrypoint for develop-only kit authoring pre-commit gate.
#             Verifies kit Perl syntax and correspondence between lib/verbs.tsv and documentation / test suites.
# Returns   : 0 on success, 1 on compilation or correspondence failure.
sub run
{
    my ($class) = @_;
    my $root = AAPP::Paths::resolve()->{root};
    return 0 unless defined $root && -d $root;

    my ( $ok, $diff ) = AAPP::Paths::git_capture( 'diff', '--cached', '--name-only' );
    $diff //= '';
    my @staged = grep { $_ ne '' && -f "$root/$_" } split( /\n/, $diff );
    return 0 unless @staged;

    # 1. Kit-specific Perl syntax compilation check
    my @perl_files = grep {
        m{\.(?:pm|pl|t)$} ||
        ( -x "$root/$_" && do {
            open( my $fh, '<', "$root/$_" );
            my $first = <$fh> // '';
            close($fh);
            $first =~ /^#!\s*\/.*perl/;
        } )
    } @staged;

    my $lib_dir = -d "$root/lib" ? "$root/lib" : '';
    foreach my $pf (@perl_files) {
        my $full_p = "$root/$pf";
        my @cmd = ('perl');
        push @cmd, "-I$lib_dir" if $lib_dir ne '';
        push @cmd, ( '-c', $full_p );
        # External perl execution required for kit perl compilation syntax check
        my $rc = system(@cmd);
        if ( $rc != 0 ) {
            print STDERR "❌ [AAPP Develop Error] Perl Compilation Error in staged kit file: $pf\n";
            return 1;
        }
    }

    # 2. Verb contract correspondence check
    my @touched_contracts = grep { m{^(?:lib/verbs\.tsv|lib/docs/verbs/|tests/verbs/|tests/verb_contracts_test\.sh|lib/docs/core/|t/core/|t/verb/)} } @staged;
    return 0 unless @touched_contracts;

    my $check = "$root/tests/verb_contracts_test.sh";
    if ( !-f $check ) {
        print STDERR "❌ [AAPP Develop] Contract check missing: $check\n";
        print STDERR "   This engine belongs to the kit repository; remove .githooks/aapp-pre-commit-develop elsewhere.\n";
        return 1;
    }

    # External bash execution required to execute the kit developer contract test suite
    my $out = `bash "$check" 2>&1`;
    my $rc  = $? >> 8;
    if ( $rc != 0 ) {
        print STDERR "\n❌ [AAPP Develop] Verb contract correspondence failed (lib/verbs.tsv <-> lib/docs/verbs/):\n";
        foreach my $line ( split( /\n/, $out ) ) {
            if ( $line =~ /✘/ || $line =~ /^\s{7}/ ) {
                print STDERR "$line\n";
            }
        }
        print STDERR "   Every daily verb needs a contract, and every test a contract names must exist.\n\n";
        return 1;
    }

    return 0;
}

1;
