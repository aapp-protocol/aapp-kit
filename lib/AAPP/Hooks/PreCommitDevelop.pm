package AAPP::Hooks::PreCommitDevelop;

use strict;
use warnings;
use utf8;
use 5.026;

use AAPP::Constants qw(RETURN_OK RETURN_ERROR RETURN_FAIL);
use AAPP::Paths ();

# Usage     : my $rc = run()
# Purpose   : Master entrypoint for aapp-pre-commit-develop hook.
sub run
{
    my ($class) = @_;
    my $root = AAPP::Paths::resolve()->{root};
    return 0 unless defined $root && -d $root;

    my $diff = `git diff --cached --name-only 2>/dev/null` // '';
    my @touched = grep { m{^(?:lib/verbs\.tsv|lib/docs/verbs/|tests/verbs/|tests/verb_contracts_test\.sh|lib/docs/core/|t/core/|t/verb/)} } split( /\n/, $diff );
    return 0 unless @touched;

    my $check = "$root/tests/verb_contracts_test.sh";
    if ( !-f $check ) {
        print STDERR "❌ [AAPP Develop] Contract check missing: $check\n";
        print STDERR "   This engine belongs to the kit repository; remove .githooks/aapp-pre-commit-develop elsewhere.\n";
        return 1;
    }

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
