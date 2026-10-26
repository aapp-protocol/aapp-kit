package AAPP::Hooks::WriteGuard;

use strict;
use warnings;
use utf8;
use 5.026;

use Cwd ();
use File::Spec ();
use File::Basename ();
use POSIX ();

use AAPP::Constants qw(RETURN_OK RETURN_ERROR RETURN_FAIL RETURN_NOT_FOUND);
use AAPP::Paths ();
use AAPP::Config ();
use AAPP::JSON ();
use AAPP::Logger ();
use AAPP::State ();

# Usage     : my $canon = canonicalize_path($path)
# Purpose   : Lexical path canonicalization (resolves . and .. without expanding symlinks).
# Returns   : Canonical absolute path string, or empty string on undefined input.
sub canonicalize_path
{
    my ($p) = @_;
    return '' unless defined $p && $p ne '';
    $p = Cwd::getcwd() . "/$p" unless $p =~ m{^/};
    my @segs;
    foreach my $seg ( split( m{/+}, $p ) ) {
        next if $seg eq '' || $seg eq '.';
        if ( $seg eq '..' ) {
            pop @segs;
        } else {
            push @segs, $seg;
        }
    }
    return '/' . join( '/', @segs );
}

# Usage     : deny_action($reason, $tool_name, $decision_reason, $path, $active_plan)
# Purpose   : Emits guard.check deny telemetry, prints formatted refusal, and exits 2.
# Returns   : Never returns (exits process with code 2).
sub deny_action
{
    my ( $reason, $tool_name, $decision_reason, $path, $active_plan ) = @_;
    $decision_reason //= 'out_of_bounds';
    $path            //= '';
    $active_plan     //= '';

    AAPP::Logger::log_event( 'guard', 'check', {
        decision    => 'deny',
        path        => $path,
        active_plan => $active_plan,
        reason      => $decision_reason,
    } );

    if ( defined $tool_name && $tool_name ne '' ) {
        my $r = AAPP::JSON::json_str($reason);
        print STDOUT AAPP::JSON::json_obj(
            decision           => AAPP::JSON::json_str('deny'),
            reason             => $r,
            hookSpecificOutput => AAPP::JSON::json_obj(
                hookEventName            => AAPP::JSON::json_str('PreToolUse'),
                permissionDecision       => AAPP::JSON::json_str('deny'),
                permissionDecisionReason => $r,
            ),
        ), "\n";
    }
    print STDERR "❌ [Blast Radius Guard Violation] $reason\n";
    exit 2;
}

# Usage     : allow_action($path, $active_plan, $reason)
# Purpose   : Emits guard.check allow telemetry and exits cleanly with code 0.
# Returns   : Never returns (exits process with code 0).
sub allow_action
{
    my ( $path, $active_plan, $reason ) = @_;
    $path        //= '';
    $active_plan //= '';
    $reason      //= 'target';

    AAPP::Logger::log_event( 'guard', 'check', {
        decision    => 'allow',
        path        => $path,
        active_plan => $active_plan,
        reason      => $reason,
    } );
    exit 0;
}

# Usage     : my @prefixes = resolve_allowlist()
# Purpose   : Collects system scratchpads, agent directories, and user-configured allow paths.
# Returns   : List of canonical directory prefix strings ending in a slash.
sub resolve_allowlist
{
    my @list;
    my $add_prefix = sub {
        my ($p) = @_;
        return unless defined $p && $p ne '';
        my $home = $ENV{HOME} // '';
        $p =~ s{^~(?=/|$)}{$home};
        $p =~ s{\$HOME\b}{$home}g if $home ne '';
        my $canon = canonicalize_path($p);
        if ( $canon ne '' && $canon ne '/' ) {
            $canon =~ s{/+$}{};
            push @list, "$canon/";
        }
    };

    my $home = $ENV{HOME};
    if ( defined $home && $home ne '' ) {
        $add_prefix->("$home/.claude");
        $add_prefix->("$home/.gemini");
        $add_prefix->("$home/.codex");
        $add_prefix->("$home/.cursor");
    }

    if ( defined $ENV{XDG_CONFIG_HOME} && $ENV{XDG_CONFIG_HOME} ne '' ) {
        $add_prefix->($ENV{XDG_CONFIG_HOME});
    } elsif ( defined $home && $home ne '' ) {
        $add_prefix->("$home/.config");
    }

    if ( defined $ENV{XDG_DATA_HOME} && $ENV{XDG_DATA_HOME} ne '' ) {
        $add_prefix->($ENV{XDG_DATA_HOME});
    } elsif ( defined $home && $home ne '' ) {
        $add_prefix->("$home/.local/share");
    }

    if ( defined $ENV{TMPDIR} && $ENV{TMPDIR} ne '' ) {
        $add_prefix->($ENV{TMPDIR});
    }
    $add_prefix->('/tmp');
    $add_prefix->('/var/folders') if -d '/var/folders';

    # Layered configuration additions from aapp.allowPath (P-132)
    foreach my $c ( AAPP::Config::get_all('aapp.allowPath') ) {
        $c =~ s/^\s+|\s+$//g;
        $add_prefix->($c) if $c ne '';
    }

    return @list;
}

# Usage     : AAPP::Hooks::WriteGuard->run(@args)
# Purpose   : Intercepts PreToolUse tool execution to guard target files and enforce blast radius.
# Returns   : Never returns directly (exits 0 on allow, exits 2 on deny).
sub run
{
    my ( $class, @args ) = @_;

    # 0. Escape hatch
    if ( defined $ENV{SKIP_BLAST_RADIUS} && $ENV{SKIP_BLAST_RADIUS} eq '1' ) {
        exit 0;
    }

    my $target_file = '';
    my $tool_name   = '';
    my $raw_input   = '';

    if ( @args ) {
        $target_file = $args[0];
    } elsif ( !-t STDIN ) {
        $raw_input = do { local $/; <STDIN> };
        if ( defined $raw_input && $raw_input ne '' ) {
            my ( $rc, $d ) = AAPP::JSON::decode($raw_input);
            if ( $rc == 1 && ref($d) eq 'HASH' ) {
                $tool_name = $d->{tool_name} // '';
                my $in = ref( $d->{tool_input} ) eq 'HASH' ? $d->{tool_input} : {};
                foreach my $k (qw(file_path path target_file)) {
                    if ( defined $in->{$k} && !ref( $in->{$k} ) && $in->{$k} ne '' ) {
                        $target_file = $in->{$k};
                        last;
                    }
                }
            } else {
                # Single-line path
                if ( index( $raw_input, '{' ) < 0 && index( $raw_input, '}' ) < 0 ) {
                    my ($first) = split( /\r?\n/, $raw_input );
                    $target_file = $first if defined $first && $first ne '';
                }
            }
        }
    }

    exit 0 if !defined $target_file || $target_file eq '';

    my $original_target  = $target_file;
    my $canonical_target = canonicalize_path($target_file);

    my $paths_info = AAPP::Paths::resolve();
    my $repo_root  = $paths_info->{root};
    if ( !defined $repo_root || $repo_root eq '' ) {
        foreach my $allowed ( resolve_allowlist() ) {
            if ( index( $canonical_target, $allowed ) == 0 ) {
                allow_action( $target_file, '', 'external_allow' );
            }
        }
        deny_action( "File '$original_target' is outside repository and not in the authorized path allowlist.", $tool_name, 'out_of_bounds', $target_file );
    }
    $repo_root = canonicalize_path($repo_root);

    my $git_common   = canonicalize_path( $paths_info->{common_dir} // "$repo_root/.git" );
    my $primary_root = canonicalize_path( $paths_info->{primary_root} // $repo_root );
    my $plans_dir    = $paths_info->{plans_dir} // '';

    # Detect if canonical_target belongs to same repository
    my $target_dir = -d $canonical_target ? $canonical_target : File::Basename::dirname($canonical_target);
    while ( defined $target_dir && $target_dir ne '' && !-d $target_dir ) {
        $target_dir = File::Basename::dirname($target_dir);
    }
    $target_dir = '/' if !defined $target_dir || $target_dir eq '';

    my $target_common = '';
    my $target_wt_root = '';
    if ( -d $target_dir ) {
        # Query target common directory safely via array exec git capture
        my ( $ok, $tc ) = AAPP::Paths::git_capture( '-C', $target_dir, 'rev-parse', '--git-common-dir' );
        if ( $ok && defined $tc && $tc ne '' ) {
            $tc =~ s/\s+\z//;
            $target_common = canonicalize_path( $tc =~ m{^/} ? $tc : "$target_dir/$tc" );
        }
    }

    my $is_same_repo = 0;
    if ( $target_common ne '' && $target_common eq $git_common ) {
        $is_same_repo = 1;
        # Query target worktree toplevel safely via array exec git capture
        my ( $ok, $twr ) = AAPP::Paths::git_capture( '-C', $target_dir, 'rev-parse', '--show-toplevel' );
        if ( $ok && defined $twr && $twr ne '' ) {
            $twr =~ s/\s+\z//;
            $target_wt_root = canonicalize_path($twr);
        }
    } elsif ( $target_common eq '' ) {
        if ( $canonical_target eq $repo_root || index( $canonical_target, "$repo_root/" ) == 0 ) {
            $is_same_repo   = 1;
            $target_wt_root = $repo_root;
        }
    }

    # Normalize target_file relative to worktree root
    if ( $is_same_repo && $target_wt_root ne '' ) {
        if ( $canonical_target eq $target_wt_root ) {
            $target_file = '.';
        } elsif ( index( $canonical_target, "$target_wt_root/" ) == 0 ) {
            $target_file = substr( $canonical_target, length($target_wt_root) + 1 );
        } else {
            $target_file = $canonical_target;
        }
    } else {
        if ( $canonical_target eq $repo_root ) {
            $target_file = '.';
        } elsif ( index( $canonical_target, "$repo_root/" ) == 0 ) {
            $target_file = substr( $canonical_target, length($repo_root) + 1 );
        } else {
            $target_file = $canonical_target;
        }
    }

    # 2. Self-Protection Invariants
    if ( $target_file =~ m{^(?:\.claude/settings(?:\.local)?\.json|.*?/\.claude/settings(?:\.local)?\.json)$} ||
         $target_file =~ m{^(?:\.agents/claude/|.*?/\.agents/claude/)} ||
         $target_file =~ m{^(?:\.agents/skills/aapp-|.*?/\.agents/skills/aapp-)} ||
         $target_file =~ m{^(?:\.claude/skills/aapp-|.*?/\.claude/skills/aapp-)} ||
         $target_file =~ m{^(?:\.agents/skills/plan(?:/.*)?|.*?/\.agents/skills/plan(?:/.*)?)$} ||
         $target_file =~ m{^(?:\.claude/skills/plan(?:/.*)?|.*?/\.claude/skills/plan(?:/.*)?)$} ) {
        deny_action( "Tampering with AAPP core configuration or governance skills is strictly prohibited.", $tool_name, "self_protection", $target_file );
    }
    if ( $target_file =~ m{^(?:\.githooks/|.*?/\.githooks/|\.git/hooks/|.*?/\.git/hooks/)} ) {
        deny_action( "Tampering with AAPP git hooks engine is strictly prohibited.", $tool_name, "self_protection", $target_file );
    }
    if ( $target_file =~ m{^(?:\.git/config|.*?/\.git/config)$} ) {
        deny_action( "Tampering with git configuration (.git/config) is strictly prohibited.", $tool_name, "self_protection", $target_file );
    }
    if ( $target_file =~ m{^(?:\.cursor/rules/|.*?/\.cursor/rules/)} ) {
        deny_action( "Tampering with agent rule files (.cursor/rules/) is strictly prohibited.", $tool_name, "self_protection", $target_file );
    }

    # 2b. External Hard-Deny
    if ( $canonical_target =~ m{/(?:\.ssh|\.gnupg|\.aws|\.azure|\.kube)(?:/|$)} ||
         $canonical_target =~ m{/\.docker/config\.json$} ||
         $canonical_target =~ m{/(?:\.netrc|\.npmrc|\.pypirc|\.git-credentials|\.gitconfig)$} ||
         $canonical_target =~ m{/\.config/git/} ||
         $canonical_target =~ m{/(?:\.bashrc|\.bash_profile|\.zshrc|\.zprofile|\.profile)$} ||
         $canonical_target =~ m{/\.config/fish/} ||
         $canonical_target =~ m{/crontab$} ||
         $canonical_target =~ m{/\.local/bin/} ) {
        deny_action( "Modifying sensitive credentials, shell configuration, or external binaries is strictly prohibited.", $tool_name, "hard_deny", $target_file );
    }

    # 2c. External Path Allowlist
    if ( !$is_same_repo ) {
        # Check companion repositories (G1 delegation)
        # Query companion repositories safely via array exec git capture
        my ( $ok_comp, $companions ) = AAPP::Paths::git_capture( 'config', '--get-regexp', '^aapp\\.companion\\..*\\.path$' );
        $companions //= '';
        foreach my $c_entry ( split( /\n/, $companions ) ) {
            $c_entry =~ s/^\s+|\s+$//g;
            next if $c_entry eq '';
            my ( $k, $c_path ) = split( /\s+/, $c_entry, 2 );
            next unless defined $c_path && $c_path ne '';
            my $canon_c = canonicalize_path($c_path);
            if ( $canonical_target eq $canon_c || index( $canonical_target, "$canon_c/" ) == 0 ) {
                my $c_guard = "$canon_c/.githooks/blast-radius-guard";
                if ( -x $c_guard ) {
                    my $rc;
                    if ( $raw_input ne '' ) {
                        # Stream input to companion guard on stdin in companion working directory
                        my $pid = open( my $pipe, '|-' );
                        if ( !defined $pid ) {
                            $rc = 2;
                        } elsif ( $pid == 0 ) {
                            chdir($canon_c) or POSIX::_exit(2);
                            exec($c_guard) or POSIX::_exit(2);
                        } else {
                            print {$pipe} $raw_input;
                            close($pipe);
                            $rc = $? >> 8;
                        }
                    } else {
                        # Execute companion guard directly in companion working directory
                        my $pid = fork();
                        if ( !defined $pid ) {
                            $rc = 2;
                        } elsif ( $pid == 0 ) {
                            chdir($canon_c) or POSIX::_exit(2);
                            exec( $c_guard, $canonical_target ) or POSIX::_exit(2);
                        } else {
                            waitpid( $pid, 0 );
                            $rc = $? >> 8;
                        }
                    }
                    if ( $rc == 0 ) {
                        allow_action( $target_file, '', 'companion' );
                    } else {
                        exit 2;
                    }
                }
                allow_action( $target_file, '', 'companion' );
            }
        }

        # Check authorized allowlist prefixes
        foreach my $allowed ( resolve_allowlist() ) {
            if ( index( $canonical_target, $allowed ) == 0 ) {
                allow_action( $target_file, '', 'external_allow' );
            }
        }

        deny_action( "File '$original_target' is outside repository and not in the authorized path allowlist.", $tool_name, 'out_of_bounds', $target_file );
    }

    # 2d. Circuit Breaker (Emergency Pause Check)
    my $paused_file = "$git_common/aapp_paused";
    my $shared_paused_file = ( $plans_dir ne '' && -f "$plans_dir/PAUSED.md" ) ? "$plans_dir/PAUSED.md" : '';

    if ( -f $paused_file || ( $shared_paused_file ne '' && -f $shared_paused_file ) ) {
        # While paused, allow reflections strictly within .plans/ (pickup, issues, current)
        if ( ( $plans_dir ne '' && index( $canonical_target, "$plans_dir/" ) == 0 && substr( $canonical_target, length($plans_dir) + 1 ) =~ m{^(?:pickup|ISSUES\.md|issues|current/)} ) ||
             $target_file =~ m{^\.plans/(?:pickup|ISSUES\.md|issues|current/)} ||
             ( File::Basename::basename($repo_root) eq '.plans' && $target_file =~ m{^(?:pickup|ISSUES\.md|issues|current/)} ) ) {
            exit 0;
        }

        my $pause_reason = '';
        if ( -f $paused_file ) {
            my ( $rc, $d ) = AAPP::JSON::decode_file($paused_file);
            $pause_reason = $d->{reason} if $rc == 1 && ref($d) eq 'HASH' && defined $d->{reason};
        }
        if ( $pause_reason eq '' && $shared_paused_file ne '' && -f $shared_paused_file ) {
            my $content = do { open( my $f, '<:encoding(UTF-8)', $shared_paused_file ); local $/; my $c = <$f>; close($f); $c // '' };
            if ( $content =~ /^\s*\*\s*\*\*Reason:\*\*\s*(.*)/m ) {
                $pause_reason = $1 =~ s/^\s+|\s+$//gr;
            }
        }
        $pause_reason = 'developer paused project' if $pause_reason eq '';

        deny_action( "🛑 [Project Circuit Breaker] The project is currently PAUSED.\n" .
                     "   Reason : $pause_reason\n" .
                     "   Stashes: In-flight changes quarantined across worktrees\n" .
                     "   Only .plans/ (pickup, issues, current) reflections may be modified while paused.\n" .
                     "   All other modifications (codebase, .agents/, templates, hooks) are strictly refused.\n" .
                     "   To resume modifications, run 'aapp resume'.", $tool_name, 'circuit_breaker', $target_file );
    }

    # 3. Always-Allowed Invariants
    if ( ( $plans_dir ne '' && ( $canonical_target eq $plans_dir || index( $canonical_target, "$plans_dir/" ) == 0 ) ) ||
         ( $paths_info->{agents_dir} && ( $canonical_target eq $paths_info->{agents_dir} || index( $canonical_target, "$paths_info->{agents_dir}/" ) == 0 ) ) ||
         ( $paths_info->{offline_dir} && ( $canonical_target eq $paths_info->{offline_dir} || index( $canonical_target, "$paths_info->{offline_dir}/" ) == 0 ) ) ||
         index( $canonical_target, "$primary_root/.plans/" ) == 0 ||
         index( $canonical_target, "$primary_root/.agents/" ) == 0 ||
         index( $canonical_target, "$primary_root/.offline/" ) == 0 ) {
        exit 0;
    }
    if ( $target_file =~ m{^(?:\.plans/|\.agents/|\.offline/)} ||
         $target_file =~ m{^(?:CHANGELOG\.md|README\.md|MANUAL\.md|CHEATSHEET\.md|COOKBOOK\.md|CODEMAP\.md|ARCHITECTURE\.md|ISSUES\.md|\.gitignore|docs/)} ||
         $target_file =~ m{^(?:package\.json|package-lock\.json|composer\.json|composer\.lock|go\.mod|go\.sum|Cargo\.toml|Cargo\.lock|pyproject\.toml|requirements\.txt)$} ) {
        exit 0;
    }

    # 4. Blast Radius Validation Against Active Plan
    if ( $plans_dir eq '' || !-d "$plans_dir/current" ) {
        if ( -f "$repo_root/.githooks/blast-radius-guard" || -f "$primary_root/.githooks/blast-radius-guard" ||
             -f "$repo_root/aapp" || -f "$primary_root/aapp" ) {
            deny_action( "AAPP repository detected but .plans/current directory is missing or unmounted.", $tool_name, 'unmounted', $target_file );
        } else {
            if ($is_same_repo) {
                exit 0;
            } else {
                deny_action( "File '$original_target' is outside repository and not in the authorized path allowlist.", $tool_name, 'out_of_bounds', $target_file );
            }
        }
    }

    my $active_buf = '';
    if ( $target_wt_root ne '' ) {
        my ( $ok, $buf ) = AAPP::Paths::git_capture( '-C', $target_wt_root, 'rev-parse', '--git-path', 'aapp_active_plan' );
        $active_buf = ( $ok && defined $buf && $buf ne '' ) ? ( $buf =~ s/\s+\z//r ) : "$target_wt_root/.git/aapp_active_plan";
        $active_buf = "$target_wt_root/$active_buf" if $active_buf !~ m{^/};
    } else {
        my ( $ok, $buf ) = AAPP::Paths::git_capture( 'rev-parse', '--git-path', 'aapp_active_plan' );
        $active_buf = ( $ok && defined $buf && $buf ne '' ) ? ( $buf =~ s/\s+\z//r ) : ".git/aapp_active_plan";
    }

    my $mini_id = '';
    if ( -f $active_buf ) {
        $mini_id = do { open( my $f, '<', $active_buf ); my $l = <$f>; close($f); defined $l ? ( $l =~ s/^\s+|\s+$//gr ) : '' };
    }

    my @mini_targets;
    if ( $mini_id =~ /^#/ ) {
        my $fix_num = $mini_id =~ s/^#//r;
        my $fix_file = "$plans_dir/current/fix-$fix_num.md";
        if ( -f $fix_file ) {
            @mini_targets = AAPP::State::plan_target_paths($fix_file);
        }
    }

    # Check blocked plans
    my @plan_files = glob("$plans_dir/current/*.md");
    foreach my $pf (@plan_files) {
        my $bname = File::Basename::basename($pf);
        next if $bname =~ /^000-/;
        if ( @mini_targets && AAPP::Paths::match_pattern_list( $target_file, @mini_targets ) ) {
            last;
        }
        if ( AAPP::Config::plan_status_is( $pf, 'blocked' ) ) {
            my @bt = AAPP::State::plan_target_paths($pf);
            if ( @bt && AAPP::Paths::match_pattern_list( $target_file, @bt ) ) {
                deny_action( "Plan '$bname' is BLOCKED. All modifications are refused.", $tool_name, 'blocked', $target_file, $bname );
            }
        }
    }

    # Resolve active plan
    my $active_plan_path = '';
    my $active_id = '';
    if ( $mini_id ne '' ) {
        foreach my $pf (@plan_files) {
            my $bname = File::Basename::basename($pf, '.md');
            next if $bname =~ /^000-/;
            my $pid = AAPP::State::plan_id($pf) // '';
            if ( $pid eq $mini_id || $bname eq $mini_id || $bname =~ /^\Q$mini_id\E-/ ||
                 $bname =~ /^P\Q$mini_id\E-/ || $bname =~ /^P-\Q$mini_id\E-/ ) {
                $active_plan_path = $pf;
                $active_id        = $pid ne '' ? $pid : $mini_id;
                last;
            }
        }
        if ( $active_plan_path eq '' ) {
            deny_action( "Designated active plan '$mini_id' not found in $plans_dir/current/. Run 'aapp plan-clear' or 'aapp plan <id>'.", $tool_name, 'not_found', $target_file );
        }
    } else {
        # Unbound context: check held plans across other worktrees (fail closed)
        my @held = AAPP::State::held_plans();
        my @dev_plans;
        foreach my $pf (@plan_files) {
            my $bname = File::Basename::basename($pf, '.md');
            next if $bname =~ /^000-/;
            my $st      = AAPP::Config::plan_status_slug($pf);
            my $st_line = AAPP::Config::plan_status_line($pf);
            if ( ( defined $st && $st eq 'in-development' ) || !defined $st_line ) {
                my $holder = AAPP::State::plan_held_by( $pf, @held );
                if ( defined $holder && $holder ne '' ) {
                    if ( !AAPP::State::is_shared_doc($target_file) ) {
                        my @ht = AAPP::State::plan_target_paths($pf);
                        if ( @ht && AAPP::Paths::match_pattern_list( $target_file, @ht ) ) {
                            deny_action( "File '$original_target' belongs to $bname (in $holder).", $tool_name, 'held', $target_file, $bname );
                        }
                    }
                    next;
                }
                push @dev_plans, $pf;
            }
        }

        if ( scalar(@dev_plans) == 1 ) {
            $active_plan_path = $dev_plans[0];
            $active_id        = AAPP::State::plan_id($active_plan_path) // File::Basename::basename($active_plan_path, '.md');
        } elsif ( scalar(@dev_plans) > 1 ) {
            my $list = join( ',', map { File::Basename::basename($_, '.md') } @dev_plans );
            deny_action( "Multiple plans in development [$list]. Run 'aapp plan <id>' to select context.", $tool_name, 'multiple_dev', $target_file );
        } else {
            # Zero plans in development
            if ($is_same_repo) {
                exit 0;
            } else {
                deny_action( "File '$original_target' is outside repository and not in the authorized path allowlist.", $tool_name, 'out_of_bounds', $target_file );
            }
        }
    }

    my $active_bname = File::Basename::basename($active_plan_path);
    if ( AAPP::Config::plan_status_is( $active_plan_path, 'blocked' ) ) {
        deny_action( "Active plan '$active_bname' is BLOCKED. All modifications are refused.", $tool_name, 'blocked', $target_file, $active_id );
    }

    my @targets = AAPP::State::plan_target_paths($active_plan_path);
    my @oob     = AAPP::State::plan_oob_paths($active_plan_path);

    # Approved amendments (P-129)
    my $group = AAPP::State::plan_field( $active_plan_path, 'Group' );
    my $norm_active = $active_id =~ s/^[pP]-?//r;
    my $is_grp = AAPP::State::is_group_plan($active_plan_path);
    if ( ( defined $group && $group ne '' ) || $is_grp ) {
        my $target_group = ( defined $group && $group ne '' ) ? $group : $active_id;
        my $norm_group   = $target_group =~ s/^[pP]-?//r;
        my @cand = glob("$plans_dir/current/*.md");
        foreach my $cand_file (@cand) {
            next if $cand_file =~ m{/000-};
            my $af_kind = AAPP::State::plan_field( $cand_file, 'Kind' ) // '';
            next unless $af_kind eq 'amendments' || $cand_file =~ /-amendments\.md$/;
            my $af_group = AAPP::State::plan_field( $cand_file, 'Group' ) // '';
            my $norm_afg = $af_group =~ s/^[pP]-?//r;
            if ( $af_group eq $target_group || ( $norm_afg ne '' && $norm_afg eq $norm_group ) ) {
                if ( open( my $afh, '<:encoding(UTF-8)', $cand_file ) ) {
                    while ( my $l = <$afh> ) {
                        # - **R<n>** <date> · <req_id> · `<path>` · <summary> — approved ...
                        if ( $l =~ /^\s*-\s*\*\*R[0-9]+\*\*\s+[^·]+·\s*([^·]+)·\s*`([^`]+)`\s*·.*?—\s*approved/i ) {
                            my ( $req, $p ) = ( $1, $2 );
                            $req =~ s/^\s+|\s+$//g;
                            my $norm_req = $req =~ s/^[pP]-?//r;
                            if ( $req eq $active_id || ( $norm_req ne '' && $norm_req eq $norm_active ) ) {
                                push @targets, $p;
                            }
                        }
                    }
                    close($afh);
                }
            }
        }
    }

    # 1. Out of Bounds veto
    if ( @oob && AAPP::Paths::match_pattern_list( $target_file, @oob ) ) {
        deny_action( "File '$original_target' is explicitly OUT OF BOUNDS in active plan '$active_bname'.", $tool_name, 'out_of_bounds', $target_file, $active_id );
    }

    # 2. Target Files allow
    if ( @targets && AAPP::Paths::match_pattern_list( $target_file, @targets ) ) {
        allow_action( $target_file, $active_id, 'target' );
    }

    # 3. Out-of-bounds only plan without declared targets
    if ( !@targets && @oob ) {
        allow_action( $target_file, $active_id, 'target' );
    }

    deny_action( "File '$original_target' is outside the declared Target Files of active plan '$active_bname'.", $tool_name, 'out_of_bounds', $target_file, $active_id );
}

1;
