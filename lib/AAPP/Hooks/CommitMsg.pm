package AAPP::Hooks::CommitMsg;

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
use AAPP::Text ();
use AAPP::Logger ();
use AAPP::Attribution ();

# Usage     : my $rc = AAPP::Hooks::CommitMsg->run($msg_file)
# Purpose   : Master entrypoint for commit-msg hook enforcing subject and body limits,
#             blank separator lines, and required semantic AI attribution trailers.
# Returns   : 0 on valid commit message, 1 on refusal.
sub run
{
    my ( $class_or_file, $maybe_file ) = @_;
    my $msg_file = defined $maybe_file ? $maybe_file : $class_or_file;
    return 0 unless defined $msg_file && -f $msg_file && -s $msg_file;

    # Revert Exemption: standard git reverts paste prior commit details
    my $raw_content = do {
        open( my $fh, '<:encoding(UTF-8)', $msg_file ) or return 0;
        local $/;
        my $c = <$fh>;
        close($fh);
        $c // '';
    };

    if ( $raw_content =~ /^(?:>?\s*This reverts commit [0-9a-fA-F]+)/m ) {
        return 0;
    }

    # Extract non-comment lines
    my @non_comment;
    foreach my $line ( split( /\n/, $raw_content ) ) {
        next if $line =~ /^\s*#/;
        push @non_comment, $line;
    }

    # Extract first non-empty line as subject
    my $subject          = '';
    my $subject_line_idx = -1;
    for my $i ( 0 .. $#non_comment ) {
        if ( $non_comment[$i] =~ /\S/ ) {
            $subject          = $non_comment[$i];
            $subject_line_idx = $i;
            last;
        }
    }

    return 0 if $subject eq '';

    if ( $subject =~ /^(?:Revert\s+"(?:[^"\\]|\\.)+"|This\s+reverts\s+commit)/ ) {
        return 0;
    }

    # Check 1: Subject Length & Shape
    my ( undef, $subject_max_len ) = AAPP::Config::get_int( 'aapp.subjectMaxLen', 72 ); $subject_max_len //= 72;
    my $subject_len     = AAPP::Text::char_len($subject);

    if ( $subject_len > $subject_max_len ) {
        print STDERR "\n❌ [Commit-Msg Violation] Commit subject exceeds maximum length ($subject_len > $subject_max_len chars)!\n";
        print STDERR "   Subject: $subject\n\n";
        print STDERR "   👉 The Commit Conciseness Invariant requires concise, imperative subject lines (<= $subject_max_len chars).\n";
        print STDERR "   👉 Move detailed technical analysis and explanations into the commit body.\n\n";
        return 1;
    }

    # Check 1b: Blank Separator Line Invariant
    my $next_line_idx = $subject_line_idx + 1;
    if ( $next_line_idx <= $#non_comment ) {
        my $line2 = $non_comment[$next_line_idx];
        if ( $line2 =~ /\S/ ) {
            print STDERR "\n❌ [Commit-Msg Violation] Missing blank separator line between subject and body!\n";
            print STDERR "   Line 2: $line2\n\n";
            print STDERR "   👉 Git conventions require an empty line separating the subject from the commit body.\n\n";
            return 1;
        }
    }

    # Check 1c: Body Conciseness & Unwrapped Line Ceiling
    my @body_raw;
    if ( $next_line_idx + 1 <= $#non_comment ) {
        @body_raw = @non_comment[ ( $next_line_idx + 1 ) .. $#non_comment ];
    }

    # Strip trailing trailers and trailing blank lines from bottom up
    while (@body_raw) {
        my $last = $body_raw[-1];
        if ( $last !~ /\S/ || $last =~ /^\s*[A-Za-z0-9_-]+:\s+/ ) {
            pop @body_raw;
        } else {
            last;
        }
    }

    # Strip leading blank lines
    while ( @body_raw && $body_raw[0] !~ /\S/ ) {
        shift @body_raw;
    }

    # Check 1c.1: Individual line width
    my ( undef, $max_line_len ) = AAPP::Config::get_int( 'aapp.commitLineMaxLen', 100 ); $max_line_len //= 100;
    foreach my $bline (@body_raw) {
        my $blen = AAPP::Text::char_len($bline);
        if ( $blen > $max_line_len ) {
            if ( $bline !~ m{https?://} ) {
                print STDERR "\n❌ [Commit-Msg Violation] Commit body line exceeds maximum width ($blen > $max_line_len chars)!\n";
                print STDERR "   Line: $bline\n\n";
                print STDERR "   👉 Wrap commit body lines at <= $max_line_len characters to preserve git log readability.\n";
                print STDERR "   👉 (Lines containing URLs are automatically exempt).\n\n";
                return 1;
            }
        }
    }

    # Check 1c.2: Total volume and line count
    my ( undef, $max_body_len ) = AAPP::Config::get_int( 'aapp.bodyMaxLen', 1200 ); $max_body_len //= 1200;
    my ( undef, $max_body_lines ) = AAPP::Config::get_int( 'aapp.maxBodyLines', 20 ); $max_body_lines //= 20;
    my $body_line_cnt  = scalar(@body_raw);
    my $body_chars     = 0;
    foreach my $bline (@body_raw) {
        $body_chars += AAPP::Text::char_len($bline) + 1;
    }

    if ( $body_chars > $max_body_len || $body_line_cnt > $max_body_lines ) {
        print STDERR "\n❌ [Commit-Msg Violation] Commit message body exceeds conciseness limit ($body_chars > $max_body_len chars / $body_line_cnt > $max_body_lines lines)!\n\n";
        print STDERR "   👉 Keep commit bodies focused on *why* and *what* concisely.\n";
        print STDERR "   👉 Detailed technical architecture belongs in canonical blueprints (.plans/current/<plan>.md).\n\n";
        return 1;
    }

    # Check 2: Attribution Policy
    my $attr_mode = AAPP::Config::get('aapp.aiAttribution') // 'none';
    my $has_ai_trailer = 0;
    if ( $raw_content =~ /^\s*AI-(?:Agent|Vendor|Model):/m ) {
        $has_ai_trailer = 1;
    }

    my $valid_trailers = 1;
    if ( $raw_content !~ /^\s*AI-Agent:\s*\S+/m ||
         $raw_content !~ /^\s*AI-Vendor:\s*\S+/m ||
         $raw_content !~ /^\s*AI-Model:\s*\S+/m ) {
        $valid_trailers = 0;
    }

    # Check for banned emails or angle brackets in AI trailers
    my @ai_lines = grep { /^\s*AI-(?:Agent|Vendor|Model):/ } split( /\n/, $raw_content );
    foreach my $ail (@ai_lines) {
        if ( $ail =~ /[@<>]/ ) {
            $valid_trailers = 0;
            last;
        }
    }

    # Check for banned Co-authored-by trailers with synthetic AI emails
    my $banned_coauthor = '';
    foreach my $line ( split( /\n/, $raw_content ) ) {
        if ( $line =~ /^\s*co-authored-by:\s*(.*)/i ) {
            my $coauthor = $1 =~ s/^\s+|\s+$//gr;
            if ( $coauthor =~ /Claude|Antigravity|GPT|Copilot|Codex|Cursor|Gemini|noreply\.anthropic\.com|antigravity\@google\.com/i ) {
                $banned_coauthor = $coauthor;
                last;
            }
        }
    }

    if ( $banned_coauthor ne '' ) {
        print STDERR "\n❌ [Commit-Msg Violation] Prohibited AI co-author trailer detected: '$banned_coauthor'\n";
        print STDERR "   Synthetic email addresses in Co-authored-by: trailers link commits to unvetted\n";
        print STDERR "   or third-party GitHub accounts (e.g. shimonenator).\n\n";
        print STDERR "   👉 Use email-free semantic trailers:\n";
        print STDERR "      AI-Agent: <Agent Name>\n";
        print STDERR "      AI-Vendor: <Vendor Name>\n";
        print STDERR "      AI-Model: <Model ID>\n";
        print STDERR "   👉 Or switch attribution mode via:\n";
        print STDERR "      aapp ai lax      (validates trailers when present, human commits pass)\n";
        print STDERR "      aapp ai strict   (requires trailers on every commit)\n";
        print STDERR "      aapp ai notes    (enable local git notes)\n";
        print STDERR "      aapp ai none     (disable AI attribution)\n\n";
        return 1;
    }

    if ( $attr_mode eq 'lax' ) {
        if ( $has_ai_trailer && !$valid_trailers ) {
            print STDERR "\n❌ [Commit-Msg Violation] Malformed or incomplete AI attribution trailers in 'lax' mode!\n";
            print STDERR "   Trailers present must include all three emailless fields:\n";
            print STDERR "      AI-Agent: <Agent Name>\n";
            print STDERR "      AI-Vendor: <Vendor Name>\n";
            print STDERR "      AI-Model: <Model ID>\n\n";
            return 1;
        }
    } elsif ( $attr_mode eq 'strict' ) {
        if ( !$valid_trailers ) {
            print STDERR "\n❌ [Commit-Msg Violation] Missing or malformed AI attribution trailers in 'strict' mode!\n";
            print STDERR "   Repository attribution mode is set to 'strict' (aapp.aiAttribution=strict).\n";
            print STDERR "   Every commit must carry valid emailless trailers:\n";
            print STDERR "      AI-Agent: <Agent Name>\n";
            print STDERR "      AI-Vendor: <Vendor Name>\n";
            print STDERR "      AI-Model: <Model ID>\n\n";
            print STDERR "   👉 You can set environment variables for automated tooling:\n";
            print STDERR "      AAPP_AGENT_NAME, AAPP_AGENT_VENDOR, AAPP_AGENT_MODEL\n";
            print STDERR "   👉 If this is a purely human commit, switch mode:\n";
            print STDERR "      aapp ai lax\n\n";
            return 1;
        }
    } elsif ( $attr_mode eq 'commit' ) {
        print STDERR "\n❌ [Commit-Msg Violation] 'aapp.aiAttribution=commit' is retired!\n";
        print STDERR "   Repository attribution mode 'commit' has been replaced by 'lax' and 'strict'.\n\n";
        print STDERR "   👉 Run one of the following commands to update your configuration:\n";
        print STDERR "      aapp ai lax     (accepts human commits, validates AI trailers when present)\n";
        print STDERR "      aapp ai strict  (enforces valid AI trailers on every commit)\n\n";
        return 1;
    } elsif ( $attr_mode eq 'notes' ) {
        if ($has_ai_trailer) {
            print STDERR "\n❌ [Commit-Msg Violation] AI attribution trailer detected in 'notes' mode!\n";
            print STDERR "   Repository attribution mode is set to 'notes' (aapp.aiAttribution=notes).\n";
            print STDERR "   Commit messages in 'notes' mode must remain human-only.\n\n";
            print STDERR "   👉 Remove AI trailers from the commit message and stage notes via:\n";
            print STDERR "      aapp note stage \"<content>\" msg \"<commit-msg>\"\n";
            print STDERR "   👉 To include public AI trailers alongside notes, switch mode:\n";
            print STDERR "      aapp ai lax     (optional trailers + notes)\n";
            print STDERR "      aapp ai strict  (mandatory trailers + notes)\n\n";
            return 1;
        }
    } elsif ( $attr_mode eq 'none' ) {
        if ($has_ai_trailer) {
            print STDERR "\n❌ [Commit-Msg Violation] AI attribution trailer detected in 'none' attribution mode!\n";
            print STDERR "   Repository attribution mode is set to 'none' (aapp.aiAttribution=none).\n";
            print STDERR "   👉 Remove the AI trailer, or enable attribution mode:\n";
            print STDERR "      aapp ai lax\n\n";
            return 1;
        }
    } else {
        print STDERR "\n❌ [Commit-Msg Violation] Unknown attribution mode '$attr_mode'!\n";
        print STDERR "   Valid modes: none, lax, strict, notes.\n\n";
        print STDERR "   👉 Run one of:\n";
        print STDERR "      aapp ai lax\n";
        print STDERR "      aapp ai strict\n";
        print STDERR "      aapp ai notes\n";
        print STDERR "      aapp ai none\n\n";
        return 1;
    }

    # Message-Hash Sync (G1)
    my $git_dir = AAPP::Paths::resolve()->{git_dir};
    if ( defined $git_dir && -d $git_dir ) {
        my $stripped = `git stripspace --strip-comments < "$msg_file" 2>/dev/null` // '';
        my $final_hash = Digest::SHA::sha256_hex($stripped);
        if ( $final_hash ne '' && !-f "$git_dir/aapp_pending_note.$final_hash" ) {
            my @pending = glob("$git_dir/aapp_pending_note.*");
            if ( scalar(@pending) == 1 ) {
                rename( $pending[0], "$git_dir/aapp_pending_note.$final_hash" );
            }
        }
    }

    return 0;
}

1;
