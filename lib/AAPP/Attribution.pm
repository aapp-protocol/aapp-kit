package AAPP::Attribution;

use strict;
use warnings;
use utf8;
use 5.026;

use AAPP::Constants qw(RETURN_OK RETURN_ERROR RETURN_FAIL);
use AAPP::Paths ();
use AAPP::Config ();
use AAPP::Logger ();

# Usage     : my $norm = apply_agent_aliases($identity)
# Purpose   : Normalizes AI identities through git config aapp.aiAlias.
sub apply_agent_aliases
{
    my ($identity) = @_;
    return $identity unless defined $identity && $identity ne '';

    my $raw = `git config --get-all aapp.aiAlias 2>/dev/null` // '';
    return $identity if $raw eq '';

    foreach my $rule ( split( /\n/, $raw ) ) {
        $rule =~ s/^\s+|\s+$//g;
        next if $rule eq '' || index( $rule, '=' ) < 0;
        my ( $from_val, $to_val ) = split( /=/, $rule, 2 );
        $from_val =~ s/^\s+|\s+$//g;
        $to_val   =~ s/^\s+|\s+$//g;
        next if $from_val eq '';

        if ( $identity eq $from_val ) {
            $identity = $to_val;
        } elsif ( $identity =~ /^\Q$from_val\E\s*\((.*)\)$/ ) {
            my $vendor = $1;
            if ( index( $to_val, '(' ) >= 0 ) {
                $identity = $to_val;
            } else {
                $identity = "$to_val ($vendor)";
            }
        }
    }
    return $identity;
}

# Usage     : my $norm = normalize_agent_identity($agent, $vendor)
# Purpose   : Canonicalizes agent name and vendor string.
sub normalize_agent_identity
{
    my ( $raw_agent, $raw_vendor ) = @_;
    my $agent  = defined $raw_agent  ? ( $raw_agent  =~ s/^\s+|\s+$//gr ) : '';
    my $vendor = defined $raw_vendor ? ( $raw_vendor =~ s/^\s+|\s+$//gr ) : '';

    if ( $agent =~ /antigravity/i ) {
        return 'Antigravity (Google)';
    } elsif ( $agent =~ /claude/i ) {
        return 'Claude (Anthropic)';
    } elsif ( $agent =~ /copilot/i ) {
        return 'GitHub Copilot (Microsoft)';
    } elsif ( $agent =~ /cursor/i ) {
        return 'Cursor (Anysphere)';
    } elsif ( $agent =~ /codex|chatgpt/i ) {
        return 'Codex (OpenAI)';
    } elsif ( $vendor ne '' && index( $agent, '(' ) < 0 ) {
        return "$agent ($vendor)";
    } else {
        return $agent;
    }
}

# Usage     : my $lines = resolve_ai_identity($agent, $vendor, $model, $msg_file)
# Purpose   : Resolves AI identity following the precedence hierarchy.
sub resolve_ai_identity
{
    my ( $agent, $vendor, $model, $msg_file ) = @_;
    $agent  = defined $agent  ? ( $agent  =~ s/^\s+|\s+$//gr ) : '';
    $vendor = defined $vendor ? ( $vendor =~ s/^\s+|\s+$//gr ) : '';
    $model  = defined $model  ? ( $model  =~ s/^\s+|\s+$//gr ) : '';

    # 1. Parameter arguments passed directly (already in $agent, $vendor, $model)

    # 2. Environment variables
    if ( $agent eq '' ) {
        $agent = $ENV{AAPP_AGENT_NAME} // '';
        $agent =~ s/^\s+|\s+$//g;
    }
    if ( $vendor eq '' ) {
        $vendor = $ENV{AAPP_AGENT_VENDOR} // '';
        $vendor =~ s/^\s+|\s+$//g;
    }
    if ( $model eq '' ) {
        $model = $ENV{AAPP_AGENT_MODEL} // '';
        $model =~ s/^\s+|\s+$//g;
    }

    # 3. Per-worktree git config (never plain repo config)
    if ( $agent eq '' ) {
        my $val = `git config --worktree aapp.aiAgent 2>/dev/null` =~ s/\s+\z//r;
        $agent = $val if defined $val && $val ne '';
    }
    if ( $vendor eq '' ) {
        my $val = `git config --worktree aapp.aiVendor 2>/dev/null` =~ s/\s+\z//r;
        $vendor = $val if defined $val && $val ne '';
    }
    if ( $model eq '' ) {
        my $val = `git config --worktree aapp.aiModel 2>/dev/null` =~ s/\s+\z//r;
        $model = $val if defined $val && $val ne '';
    }

    # 4. Vendor Co-Authored-By in commit message file
    if ( $agent eq '' && defined $msg_file && -f $msg_file ) {
        open( my $fh, '<:encoding(UTF-8)', $msg_file );
        if ($fh) {
            while ( my $line = <$fh> ) {
                if ( $line =~ /^\s*co-authored-by:\s*(.*)/i ) {
                    my $coauthor = $1;
                    $coauthor =~ s/^\s+|\s+$//g;
                    if ( $coauthor =~ /Claude|Antigravity|GPT|Copilot|Codex|Cursor|Gemini|noreply\.anthropic\.com|antigravity\@google\.com/i ) {
                        print STDERR "⚠️ [Warning] Converted synthetic Co-authored-by email trailer to emailless semantic attribution.\n";
                        my $cname = $coauthor;
                        if ( $coauthor =~ /^(.*?)\s*<([^>]+)>/ ) {
                            $cname = $1;
                        }
                        $cname =~ s/^\s+|\s+$//g;
                        $agent = $cname;
                        if ( $cname =~ /Claude/i ) {
                            $vendor = 'Anthropic';
                        } elsif ( $cname =~ /Antigravity/i ) {
                            $vendor = 'Google';
                        } elsif ( $cname =~ /Copilot/i ) {
                            $vendor = 'Microsoft';
                        } elsif ( $cname =~ /Cursor/i ) {
                            $vendor = 'Anysphere';
                        } elsif ( $cname =~ /Codex|GPT/i ) {
                            $vendor = 'OpenAI';
                        }
                        last;
                    }
                }
            }
            close($fh);
        }
    }

    # 5. Nothing resolved
    return '' if $agent eq '';

    # Parse Vendor from Agent string if passed as 'Agent (Vendor)'
    if ( $agent =~ /^(.*?)\s*\((.*)\)$/ ) {
        $agent = $1;
        $vendor = $2 if $vendor eq '';
    }

    $agent  =~ s/^\s+|\s+$//g;
    $vendor =~ s/^\s+|\s+$//g;
    $model  =~ s/^\s+|\s+$//g;

    $vendor = 'Unknown' if $vendor eq '';
    $model  = 'unknown' if $model eq '';

    return "AI-Agent: $agent\nAI-Vendor: $vendor\nAI-Model: $model\n";
}

# Usage     : my $lines = format_identity_lines($identity)
sub format_identity_lines
{
    my ($id) = @_;
    return '' unless defined $id && $id ne '';

    if ( index( $id, 'AI-Agent:' ) >= 0 ) {
        return $id =~ s/\s+\z//r . "\n";
    } elsif ( $id =~ /^(.*?)\s*\((.*)\)$/ ) {
        my $a = $1 =~ s/^\s+|\s+$//gr;
        my $v = $2 =~ s/^\s+|\s+$//gr;
        return "AI-Agent: $a\nAI-Vendor: $v\nAI-Model: unknown\n";
    } else {
        my $clean = $id =~ s/^\s+|\s+$//gr;
        return "AI-Agent: $clean\nAI-Vendor: Unknown\nAI-Model: unknown\n";
    }
}

# Usage     : my $rc = attribution_decorate($msg_file, $identity)
# Purpose   : Decorates a commit message file with trailers according to configured attribution mode.
sub attribution_decorate
{
    my ( $msg_file, $identity ) = @_;
    my $mode = `git config aapp.aiAttribution 2>/dev/null` =~ s/\s+\z//r;
    $mode = 'none' if !defined $mode || $mode eq '';

    my ( $agent, $vendor, $model ) = ( '', '', '' );
    if ( defined $identity && $identity ne '' ) {
        if ( $identity =~ /AI-Agent:\s*(.*)/ ) {
            $agent = $1 =~ s/^\s+|\s+$//gr;
        } elsif ( $identity =~ /^(.*?)\s*\((.*)\)$/ ) {
            $agent  = $1 =~ s/^\s+|\s+$//gr;
            $vendor = $2 =~ s/^\s+|\s+$//gr;
        } else {
            $agent = $identity =~ s/^\s+|\s+$//gr;
        }
        if ( $identity =~ /AI-Vendor:\s*(.*)/ ) {
            $vendor = $1 =~ s/^\s+|\s+$//gr;
        }
        if ( $identity =~ /AI-Model:\s*(.*)/ ) {
            $model = $1 =~ s/^\s+|\s+$//gr;
        }
    }

    if ( $mode eq 'strict' ) {
        if ( !defined $identity || $identity eq '' ) {
            print STDERR "❌ [Error] Strict attribution mode requires an AI identity.\n";
            AAPP::Logger::log_event( 'commits', 'decorate', {
                mode           => 'strict',
                agent          => '',
                vendor         => '',
                model          => '',
                trailers_added => 0,
                status         => 'missing_identity',
            } );
            return 1;
        }
    } elsif ( $mode eq 'lax' ) {
        if ( !defined $identity || $identity eq '' ) {
            AAPP::Logger::log_event( 'commits', 'decorate', {
                mode           => 'lax',
                agent          => '',
                vendor         => '',
                model          => '',
                trailers_added => 0,
                status         => 'ok',
            } );
            return 0;
        }
    } else {
        # none or notes: leave message alone
        return 0;
    }

    return 0 unless defined $msg_file && -f $msg_file;

    # Do not duplicate if AI-Agent already present
    my $content = do { open( my $f, '<:encoding(UTF-8)', $msg_file ); local $/; my $c = <$f>; close($f); $c // '' };
    if ( $content =~ /^\s*AI-Agent:/m ) {
        AAPP::Logger::log_event( 'commits', 'decorate', {
            mode           => $mode,
            agent          => $agent,
            vendor         => $vendor,
            model          => $model,
            trailers_added => 0,
            status         => 'ok',
        } );
        return 0;
    }

    my $id_lines = format_identity_lines($identity);
    if ( $id_lines ne '' ) {
        open( my $fh, '>>:encoding(UTF-8)', $msg_file ) or return 1;
        if ( $content ne '' && $content !~ /\n\z/ ) {
            print {$fh} "\n";
        }
        print {$fh} "\n$id_lines";
        close($fh);

        AAPP::Logger::log_event( 'commits', 'decorate', {
            mode           => $mode,
            agent          => $agent,
            vendor         => $vendor,
            model          => $model,
            trailers_added => 1,
            status         => 'ok',
        } );
    }

    return 0;
}

# Usage     : my $rc = attribution_note($sha, $identity, $text)
# Purpose   : Attaches git note with identity and optional text.
sub attribution_note
{
    my ( $sha, $identity, $text ) = @_;
    my $mode = `git config aapp.aiAttribution 2>/dev/null` =~ s/\s+\z//r;
    $mode = 'none' if !defined $mode || $mode eq '';

    if ( $mode eq 'notes' && ( !defined $identity || $identity eq '' ) && ( defined $text && $text ne '' ) ) {
        print STDERR "❌ [Error] Note text provided without a resolved AI identity in 'notes' mode.\n";
        print STDERR "   👉 Provide an identity via parameters, environment (AAPP_AGENT_*), or worktree config.\n";
        return 1;
    }

    if ( ( !defined $identity || $identity eq '' ) && ( !defined $text || $text eq '' ) ) {
        return 0;
    }

    my $id_lines = format_identity_lines($identity);
    $id_lines =~ s/\s+\z//;

    my $note_content = '';
    if ( $id_lines ne '' && defined $text && $text ne '' ) {
        $note_content = "$id_lines\n\n$text";
    } elsif ( $id_lines ne '' ) {
        $note_content = $id_lines;
    } else {
        $note_content = $text;
    }

    return 0 if $note_content eq '' || !defined $sha || $sha eq '';

    if ( $mode eq 'notes' ) {
        my $rc = system( 'git', 'notes', '--ref=refs/notes/commits', 'append', '-m', $note_content, $sha );
        return $rc >> 8 if $rc != 0;
        AAPP::Logger::log_event( 'notes', 'attach', {
            sha    => "$sha",
            ref    => 'refs/notes/commits',
            action => 'add',
            text   => $note_content,
        } );

        if ( $id_lines ne '' ) {
            my $ai_rc = system( 'git', 'notes', '--ref=refs/notes/ai', 'append', '-m', $id_lines, $sha );
            return $ai_rc >> 8 if $ai_rc != 0;
            AAPP::Logger::log_event( 'notes', 'attach', {
                sha    => "$sha",
                ref    => 'refs/notes/ai',
                action => 'add',
                text   => $id_lines,
            } );
        }
    } else {
        if ( defined $identity && $identity ne '' ) {
            my $rc = system( 'git', 'notes', '--ref=refs/notes/ai', 'append', '-m', $note_content, $sha );
            return $rc >> 8 if $rc != 0;
            AAPP::Logger::log_event( 'notes', 'attach', {
                sha    => "$sha",
                ref    => 'refs/notes/ai',
                action => 'add',
                text   => $note_content,
            } );
        } else {
            my $rc = system( 'git', 'notes', '--ref=refs/notes/commits', 'append', '-m', $note_content, $sha );
            return $rc >> 8 if $rc != 0;
            AAPP::Logger::log_event( 'notes', 'attach', {
                sha    => "$sha",
                ref    => 'refs/notes/commits',
                action => 'add',
                text   => $note_content,
            } );
        }
    }

    return 0;
}

1;
