package AAPP::Hooks::PostCommit;

use strict;
use warnings;
use utf8;
use 5.026;

use Digest::SHA ();
use File::Spec ();
use File::Basename ();

use AAPP::Constants qw(RETURN_OK RETURN_ERROR RETURN_FAIL);
use AAPP::Paths ();
use AAPP::Config ();
use AAPP::Logger ();

# Usage     : my $rc = AAPP::Hooks::PostCommit->run()
# Purpose   : Master entrypoint for post-commit hook; attaches pending git notes to HEAD.
# Returns   : 0 on success, non-zero on failure.
sub run
{
    my ($class) = @_;
    my $git_dir = AAPP::Paths::resolve()->{git_dir};
    return 0 unless defined $git_dir && -d $git_dir;

    my @pending = glob("$git_dir/aapp_pending_note.*");
    my $pending_count = scalar(@pending);
    return 0 if $pending_count == 0;

    my ( $ok_c, $raw_commit ) = AAPP::Paths::git_capture( 'cat-file', 'commit', 'HEAD' );
    $raw_commit //= '';
    return 0 if !$ok_c || $raw_commit eq '';

    my ( $ok_s, $head_sha_raw ) = AAPP::Paths::git_capture( 'rev-parse', 'HEAD' );
    my $head_sha = ( $ok_s && defined $head_sha_raw ) ? ( $head_sha_raw =~ s/\s+\z//r ) : '';

    # Extract byte-faithful commit body hash (everything after first blank line)
    my $head_hash = '';
    if ( $raw_commit =~ /\n\n(.*)\z/s ) {
        my $body = $1;
        $head_hash = Digest::SHA::sha256_hex($body);
    }

    my $note_file = "$git_dir/aapp_pending_note.$head_hash";
    if ( $head_hash ne '' && -f $note_file ) {
        my $target_ref = 'refs/notes/commits';
        my $note_content = do {
            open( my $fh, '<:encoding(UTF-8)', $note_file );
            local $/;
            my $c = <$fh>;
            close($fh);
            $c // '';
        };

        if ( $note_content =~ /^X-AAPP-Ref:\s*([^\r\n]+)/m ) {
            $target_ref = $1 =~ s/^\s+|\s+$//gr;
            $note_content =~ s/^X-AAPP-Ref:[^\r\n]*\r?\n?//m;
            open( my $wfh, '>:encoding(UTF-8)', $note_file );
            print {$wfh} $note_content;
            close($wfh);
        }

        # External git notes execution required to attach out-of-band note to commit ref
        my $rc = system( 'git', 'notes', "--ref=$target_ref", 'append', '-F', $note_file, 'HEAD' );
        if ( $rc == 0 ) {
            unlink($note_file);
            AAPP::Logger::log_event( 'notes', 'attach', {
                sha    => "$head_sha",
                ref    => $target_ref,
                action => 'add',
                text   => $note_content,
            } );
        } else {
            print STDERR "⚠️  [Post-Commit Warning] Failed to attach git note to HEAD from $note_file\n";
        }
    } else {
        print STDERR "⚠️  [Post-Commit Warning] Found $pending_count pending AI note buffer(s) in $git_dir, but none matched commit message hash ($head_hash).\n";
    }

    # Reaping sweep for expired notes (B5)
    my ( undef, $ttl_mins ) = AAPP::Config::get_int( 'aapp.noteTTL', 1440 );
    $ttl_mins //= 1440;
    my $now = time();
    foreach my $f (@pending) {
        next unless -f $f;
        my $mtime = ( stat($f) )[9] // $now;
        if ( ( $now - $mtime ) > ( $ttl_mins * 60 ) ) {
            unlink($f);
        }
    }

    return 0;
}

1;
