package AAPP::Health;

use strict;
use warnings;
use utf8;
use 5.026;

use IPC::Open2 ();
use AAPP::Constants qw(RETURN_OK);
use AAPP::Config ();
use AAPP::Logger ();
use AAPP::Paths ();
use AAPP::State ();
use AAPP::Text ();
use AAPP::Util ();

my $ID_BODY      = qr/(?:[0-9]+|[A-Z][A-Z0-9]*-[0-9]+)/;
my $REF_PREFIXED = qr/(?:(?:#|ISSUE-)[0-9]+|#$ID_BODY)/;

# Issue severities the schema check accepts, and the shape of an issue type token.
our @SEVERITIES = qw(Critical High Medium Low);
our $TYPE_RE    = qr/^[A-Z0-9_-]+$/;

# How long a recorded commit hash may be, in hex digits (Pair 6).
our $SHA_MIN_LEN = 7;
our $SHA_MAX_LEN = 40;

# Paths the write guard protects; a plan may not list them as Target Files (Pair 5).
our @SELF_PROTECTED = (
    [ qr{(?:^|/)\.claude/settings(?:\.local)?\.json$|(?:^|/)\.agents/claude/|(?:^|/)\.agents/skills/aapp-|(?:^|/)\.claude/skills/aapp-}, 'Tampering with AAPP core configuration or governance skills is strictly prohibited. Move it to Out of Bounds and edit templates/ instead.' ],
    [ qr{(?:^|/)\.githooks/|(?:^|/)\.git/hooks/}, 'Tampering with the AAPP git hooks engine is strictly prohibited. Move it to Out of Bounds.' ],
    [ qr{(?:^|/)\.cursor/rules/}, 'Tampering with agent rule files (.cursor/rules/) is strictly prohibited. Move it to Out of Bounds.' ],
);

my $SEVERITY_RE = join( '|', map { quotemeta } @SEVERITIES );
my $MARKER_RE   = join( '|', map { quotemeta } @AAPP::State::ACTION_MARKERS );

# Usage     : my $root = repo_root($explicit)
# Purpose   : The repository the checks look at: the one given, else this checkout.
# Returns   : The path, or undef after an [ ERROR ] line outside a repository.
sub repo_root
{
    my ($explicit) = @_;
    if ( defined $explicit && $explicit ne '' ) {
        return $explicit;
    }
    my $root = AAPP::Paths::resolve()->{root};
    if ( !defined $root ) {
        AAPP::Logger::print_msg( 'ERROR', '[Planning Health] Not inside a Git repository.' );
        return;
    }
    return $root;
}

# Usage     : my $file = find_file('pickup', $root)
# Purpose   : Where a planning file is: the issue ledgers (issues, archive, roadmap), pickup, the
#             archive ledger ('ledger') or the changelog.
# Returns   : The path of an existing file, or undef.
sub find_file
{
    my ( $name, $root ) = @_;
    my @candidates;
    if ( $name eq 'issues' || $name eq 'archive' || $name eq 'roadmap' ) {
        @candidates = ( AAPP::State::ledger_path( $name, $root ) );
    } elsif ( $name eq 'pickup' ) {
        @candidates = ( "$root/.plans/pickup.md", "$root/pickup.md" );
    } elsif ( $name eq 'ledger' ) {
        @candidates = ( "$root/.plans/done/000-archive-ledger.md", "$root/done/000-archive-ledger.md" );
    } elsif ( $name eq 'changelog' ) {
        @candidates = ( "$root/CHANGELOG.md", "$root/.plans/CHANGELOG.md" );
    }
    foreach my $file (@candidates) {
        if ( defined $file && -f $file ) {
            return $file;
        }
    }
    return;
}

# Usage     : my @files = _archive_files($archive_file, $issues_file)
# Purpose   : The archive ledger given, then every other archive (overflow, release bundles) of the
#             repository the two files belong to.
# Returns   : List of existing paths, each once.
sub _archive_files
{
    my ( $archive_file, $issues_file ) = @_;
    my @files;
    if ( defined $archive_file && -f $archive_file ) {
        push @files, $archive_file;
    }
    my $root;
    foreach my $file ( $archive_file, $issues_file ) {
        if ( !defined $file ) {
            next;
        }
        if ( $file =~ m{^(.*)/\.plans/} ) {
            $root = $1;
            last;
        }
        if ( $file =~ m{^\.plans/} ) {
            $root = '.';
            last;
        }
    }
    $root //= AAPP::Paths::resolve()->{root};
    if ( defined $root ) {
        foreach my $file ( AAPP::State::ledger_archive_files($root) ) {
            if ( !grep { $_ eq $file } @files ) {
                push @files, $file;
            }
        }
    }
    return @files;
}

# Usage     : my $n = check_pair1_disjointness($issues_file, $archive_file)
# Purpose   : Pair 1: no resolved row left in the active ledger, and no id in both the active ledger and an archive.
# Returns   : The number of violations.
sub check_pair1_disjointness
{
    my ( $issues_file, $archive_file ) = @_;
    my $errors = 0;
    if ( defined $issues_file && -f $issues_file ) {
        local $ENV{AAPP_LEDGER_ISSUES} = $issues_file;
        if ( AAPP::State::ledger_resolved_rows() ) {
            AAPP::Logger::print_msg( 'ERROR', "[Pair 1 Invariant Violation] Found resolved issue in active $issues_file. The Relocation Invariant requires resolved rows to be moved to .plans/done/000-issues-archive.md: a physical row relocation, never an in-place status badge." );
            $errors++;
        }
    }
    if ( !defined $issues_file || !-f $issues_file ) {
        return $errors;
    }
    my %active = map { ( $_ => 1 ) } AAPP::State::ledger_ids( 'active', $issues_file );
    foreach my $archive ( _archive_files( $archive_file, $issues_file ) ) {
        my %seen;
        my @shared = sort grep { $active{$_} && !$seen{$_}++ } AAPP::State::ledger_ids( 'archive', $archive );
        foreach my $id (@shared) {
            AAPP::Logger::print_msg( 'ERROR', "[Pair 1 Collision] Issue #$id exists in both active $issues_file and $archive!" );
            $errors++;
        }
    }
    return $errors;
}

# Usage     : my $n = check_pair2_referential_integrity($roadmap_file, $issues_file)
# Purpose   : Pair 2: every issue on the work queue is in the active ledger.
# Returns   : The number of drifted entries.
sub check_pair2_referential_integrity
{
    my ( $roadmap_file, $issues_file ) = @_;
    if ( !defined $roadmap_file || !-f $roadmap_file || !defined $issues_file || !-f $issues_file ) {
        return 0;
    }
    my %active = map { ( $_ => 1 ) } AAPP::State::ledger_ids( 'active', $issues_file );
    my $errors = 0;
    foreach my $id ( AAPP::State::issue_id_sort( AAPP::State::ledger_ids( 'roadmap', $roadmap_file ) ) ) {
        if ( !$active{$id} ) {
            AAPP::Logger::print_msg( 'WARN', "[Roadmap Drift] #$id is on the work queue but missing from $issues_file." );
            $errors++;
        }
    }
    return $errors;
}

# Usage     : my $n = check_roadmap_sections($roadmap_file)
# Purpose   : The work queue holds only 'Plan Blockers' and 'Queued' with its levels Urgent, Normal and Low;
#             headings are compared by name, emoji decorative.
# Returns   : The number of foreign headings.
sub check_roadmap_sections
{
    my ($roadmap_file) = @_;
    if ( !defined $roadmap_file || !-f $roadmap_file ) {
        return 0;
    }
    my $name   = $roadmap_file =~ s{.*/}{}r;
    my $errors = 0;
    local $ENV{AAPP_LEDGER_ROADMAP} = $roadmap_file;
    foreach my $heading ( AAPP::State::roadmap_sections() ) {
        my ( $level, $text ) = AAPP::Text::heading_name($heading);
        my $blockers = $AAPP::State::ROADMAP_BLOCKERS;
        my $queued   = $AAPP::State::ROADMAP_QUEUED;
        my @levels   = @AAPP::State::QUEUE_LEVELS;
        my $allowed  = ( $level == 2 && $text =~ /^(?:\Q$blockers\E|\Q$queued\E)\b/ ) || ( $level == 3 && grep { $text eq $_ } @levels );
        if ( !$allowed ) {
            my $level_list = join( ', ', map {"'$_'"} @levels );
            AAPP::Logger::print_msg( 'ERROR', "[Work Queue] '$heading' is not a section of $name: it holds only '$blockers' and '$queued' with its levels $level_list. Issues stay in ISSUES.md; queue one with 'aapp issue queue <num> [urgent | low]'." );
            $errors++;
        }
    }
    return $errors;
}

# Usage     : check_pair3_pickup_routing($pickup_file, $issues_file, $archive_file)
# Purpose   : Pair 3: warns about a pickup entry whose title names an issue already logged or archived.
# Returns   : 0 (warnings only).
sub check_pair3_pickup_routing
{
    my ( $pickup_file, $issues_file, $archive_file ) = @_;
    if ( !defined $pickup_file || !-f $pickup_file ) {
        return 0;
    }
    my %known;
    if ( defined $issues_file && -f $issues_file ) {
        $known{$_} = 1 for AAPP::State::ledger_ids( 'active', $issues_file );
    }
    if ( defined $archive_file && -f $archive_file ) {
        $known{$_} = 1 for AAPP::State::ledger_ids( 'archive', $archive_file );
    }
    my $bullet = qr/^\s*(?:[0-9]+\.|-\s*\[[ xX]?\]|\*)\s*(?:\*\*)?[\p{Alnum}\s]*(?:\p{S}\x{FE0F}?)?\s*$REF_PREFIXED/;
    foreach my $line ( @{ AAPP::State::file_lines($pickup_file) // [] } ) {
        if ( $line !~ $bullet ) {
            next;
        }
        my $title = ( split( /:/, $line, 2 ) )[0];
        while ( $title =~ /($REF_PREFIXED)/g ) {
            my $raw  = $1 =~ s/ //gr;
            my $body = AAPP::State::_id_body($raw);
            if ( defined $body && $known{$body} ) {
                AAPP::Logger::print_msg( 'WARN', "[Pickup Routing] Issue #$body is already logged in ISSUES.md or archive, but still drafted as an unworked note in $pickup_file." );
            }
        }
    }
    return 0;
}

# Usage     : my $n = check_taxonomy_and_schema($issues_file)
# Purpose   : Each active row's Severity is Critical/High/Medium/Low (a warning otherwise) and its Type an
#             uppercase token (an error otherwise).
# Returns   : The number of errors.
sub check_taxonomy_and_schema
{
    my ($issues_file) = @_;
    if ( !defined $issues_file || !-f $issues_file ) {
        return 0;
    }
    my $errors = 0;
    local $ENV{AAPP_LEDGER_ISSUES} = $issues_file;
    foreach my $line ( AAPP::State::ledger_row_lines() ) {
        my @parts = split( /\|/, $line, -1 );
        my $id    = ( $parts[1] // '' ) =~ s/ //gr;
        my $sev   = ( $parts[2] // '' ) =~ s/[ `]//gr;
        my $type  = ( $parts[3] // '' ) =~ s/[ `]//gr;
        if ( $sev ne '' && $sev !~ /^(?:$SEVERITY_RE)$/ ) {
            AAPP::Logger::print_msg( 'WARN', "[Schema Warning] Issue $id has non-standard Severity: '$sev' (expected " . join( '|', @SEVERITIES ) . ')' );
        }
        if ( $type ne '' && $type !~ $TYPE_RE ) {
            AAPP::Logger::print_msg( 'ERROR', "[Schema Error] Issue $id has invalid Type token: '$type' (must match ^[A-Z0-9_-]+\$)" );
            $errors++;
        }
    }
    return $errors;
}

# Usage     : my @plans = _plans_in($dir, $skip_fix)
# Purpose   : The plan files directly in a folder (not 000- registers; not fix- mini plans when asked), sorted.
# Returns   : List of paths.
sub _plans_in
{
    my ( $dir, $skip_fix ) = @_;
    my @plans = AAPP::Util::plan_sort( grep { -f $_ && $_ !~ m{/000-[^/]*$} && !( $skip_fix && $_ =~ m{/fix-[^/]*$} ) } glob("\Q$dir\E/*.md") );
    return @plans;
}

# Usage     : my $n = check_pair4_plan_id_integrity($root)
# Purpose   : Pair 4: in current/, a header Plan ID agrees with the file name's P<n>, and no two plans share an id.
# Returns   : The number of violations.
sub check_pair4_plan_id_integrity
{
    my ($root) = @_;
    $root = repo_root($root) // return 1;
    my $dir = "$root/.plans/current";
    if ( !-d $dir ) {
        return 0;
    }
    my $errors = 0;
    my %seen;
    my $norm = sub { my ($id) = @_; return $id =~ s/^[pP]-?0*//r };
    foreach my $plan ( _plans_in( $dir, 1 ) ) {
        my $name = $plan =~ s{.*/}{}r;
        my $header;
        foreach my $line ( @{ AAPP::State::file_lines($plan) // [] } ) {
            if ( $line =~ /^\s*[*|-]\s*\*\*Plan ID:\*\*\s*(.*?)\s*$/ ) {
                $header = $1 =~ s/`//gr;
                last;
            }
        }
        my $from_name = $name =~ /^[pP]([0-9]+)-/ ? "P-$1" : undef;
        my $id = ( defined $header && $header ne '' ) ? $header : $from_name;
        if ( !defined $id ) {
            next;
        }
        if ( defined $header && $header ne '' && defined $from_name && $norm->($header) ne $norm->($from_name) ) {
            AAPP::Logger::print_msg( 'ERROR', "[Pair 4 Violation] Plan '$name' header ID ($header) does not match filename prefix ($from_name)!" );
            $errors++;
        }
        my $key = $norm->($id);
        if ( exists $seen{$key} ) {
            AAPP::Logger::print_msg( 'ERROR', "[Pair 4 Violation] Duplicate Plan ID '$id' detected in '$name' and '$seen{$key}'!" );
            $errors++;
            next;
        }
        $seen{$key} = $name;
    }
    return $errors;
}

# Usage     : my $n = check_pair8_issue_id_integrity($issues_file, $archive_file)
# Purpose   : Pair 8: no id appears twice within the active ledger, nor within one archive file.
# Returns   : The number of repeated ids.
sub check_pair8_issue_id_integrity
{
    my ( $issues_file, $archive_file ) = @_;
    my $errors = 0;
    if ( defined $issues_file && -f $issues_file ) {
        foreach my $id ( _repeated( AAPP::State::ledger_ids( 'active', $issues_file ) ) ) {
            AAPP::Logger::print_msg( 'ERROR', "[Pair 8 Violation] Issue #$id appears more than once in active $issues_file!" );
            $errors++;
        }
    }
    foreach my $archive ( _archive_files( $archive_file, $issues_file ) ) {
        foreach my $id ( _repeated( AAPP::State::ledger_ids( 'archive', $archive ) ) ) {
            AAPP::Logger::print_msg( 'ERROR', "[Pair 8 Violation] Issue #$id appears more than once in archive $archive!" );
            $errors++;
        }
    }
    return $errors;
}

# Usage     : my @ids = _repeated(@ids)
# Purpose   : The ids that occur more than once, in id order.
# Returns   : List of ids.
sub _repeated
{
    my (@ids) = @_;
    my %count;
    $count{$_}++ for @ids;
    return AAPP::State::issue_id_sort( grep { $count{$_} > 1 } keys %count );
}

# Usage     : my $n = check_pair5_target_files_self_protection($root)
# Purpose   : Pair 5: no plan in current/ lists a file the write guard protects (kit settings, skills,
#             hooks, agent rules) under a Target Files heading.
# Returns   : The number of violations.
sub check_pair5_target_files_self_protection
{
    my ($root) = @_;
    $root = repo_root($root) // return 1;
    my $dir = "$root/.plans/current";
    if ( !-d $dir ) {
        return 0;
    }
    my $errors = 0;
    foreach my $plan ( _plans_in( $dir, 0 ) ) {
        my $name   = $plan =~ s{.*/}{}r;
        my $inside = 0;
        foreach my $line ( @{ AAPP::State::file_lines($plan) // [] } ) {
            if ( $line =~ /^###\s+.*Target\s+Files/ ) {
                $inside = 1;
                next;
            }
            if ( !$inside ) {
                next;
            }
            if ( $line =~ /^###\s+/ || $line =~ /^##\s+/ ) {
                $inside = 0;
                next;
            }
            if ( $line !~ /^\s*[-*]/ ) {
                next;
            }
            my @ticked = $line =~ /`([^`]+)`/g;
            my $target = shift @ticked;
            if ( defined $target && $target =~ /^(?:$MARKER_RE)$/ && @ticked ) {
                $target = shift @ticked;
            }
            if ( !defined $target ) {
                next;
            }
            foreach my $rule (@SELF_PROTECTED) {
                if ( $target =~ $rule->[0] ) {
                    AAPP::Logger::print_msg( 'ERROR', "[Pair 5 Violation] Plan '$name' declares Target File '$target' which violates Guard Section 2 self-protection! $rule->[1]" );
                    $errors++;
                    last;
                }
            }
        }
    }
    return $errors;
}

# Usage     : my @shas = file_commit_shas($file)
# Purpose   : The commit hashes a Markdown file records: backticked hex of 7-40 characters, and bare hex
#             words of 7-40 characters that mix digits and letters (or are 40 long). Lowercased, sorted, unique.
# Returns   : List of hashes.
sub file_commit_shas
{
    my ($file) = @_;
    my %found;
    foreach my $line ( @{ AAPP::State::file_lines($file) // [] } ) {
        while ( $line =~ /`([0-9a-fA-F]{$SHA_MIN_LEN,$SHA_MAX_LEN})`/g ) {
            $found{ lc $1 } = 1;
        }
        foreach my $word ( split( /[^0-9a-zA-Z]/, $line ) ) {
            my $len = length($word);
            if ( $len < $SHA_MIN_LEN || $len > $SHA_MAX_LEN || $word !~ /^[0-9a-fA-F]+$/ ) {
                next;
            }
            if ( $len == $SHA_MAX_LEN || ( $word =~ /[0-9]/ && $word =~ /[a-fA-F]/ ) ) {
                $found{ lc $word } = 1;
            }
        }
    }
    my @shas = sort keys %found;
    return @shas;
}

# Usage     : my @missing = _missing_commits($root, @shas)
# Purpose   : The hashes git cannot resolve to a commit, asked in one git cat-file --batch-check run.
# Returns   : List of hashes, in the order given.
sub _missing_commits
{
    my ( $root, @shas ) = @_;
    if ( !@shas ) {
        return ();
    }
    my ( $out, $in );
    my $pid = IPC::Open2::open2( $out, $in, 'git', '-C', $root, 'cat-file', '--batch-check' );
    print {$in} map { "$_^{commit}\n" } @shas;
    close($in);
    my @answers = <$out>;
    close($out);
    waitpid( $pid, 0 );
    my @missing;
    for my $i ( 0 .. $#shas ) {
        my $answer = $answers[$i] // 'missing';
        if ( $answer =~ /missing$/ || $answer !~ / commit / ) {
            push @missing, $shas[$i];
        }
    }
    return @missing;
}

# Usage     : my $n = check_pair6_recorded_sha_integrity($root)
# Purpose   : Pair 6: every commit hash the archive ledgers, release ledgers, issue ledgers and changelogs
#             record exists in git.
# Returns   : The number of unresolved hashes.
sub check_pair6_recorded_sha_integrity
{
    my ($root) = @_;
    $root = repo_root($root) // return 1;
    my ($is_repo) = AAPP::Paths::git_capture( '-C', $root, 'rev-parse', '--git-dir' );
    if ( !$is_repo ) {
        return 0;
    }
    my @scan = (
        find_file( 'ledger', $root ),
        find_file( 'archive', $root ),
        AAPP::State::ledger_archive_files($root),
        sort( glob("\Q$root\E/.plans/release/*/000-archive-ledger.md") ),
        find_file( 'issues', $root ),
        "$root/CHANGELOG.md",
        "$root/.plans/CHANGELOG.md",
    );
    my %seen;
    my @files = grep { defined $_ && -f $_ && !$seen{$_}++ } @scan;
    my $errors = 0;
    foreach my $file (@files) {
        my $name = $file =~ s{.*/}{}r;
        foreach my $sha ( _missing_commits( $root, file_commit_shas($file) ) ) {
            AAPP::Logger::print_msg( 'ERROR', "[Pair 6 Violation] Recorded commit SHA '$sha' in $name cannot be resolved in git! File: $file. Every commit hash recorded in archival ledgers, issues, and changelogs must exist in git." );
            $errors++;
        }
    }
    return $errors;
}

# Usage     : my $n = check_pair7_inflight_boundary_collision($root)
# Purpose   : Pair 7: plans In Development share no Target File (shared documents excepted, noted only).
# Returns   : The number of collisions.
sub check_pair7_inflight_boundary_collision
{
    my ($root) = @_;
    $root = repo_root($root) // return 1;
    my $dir = "$root/.plans/current";
    if ( !-d $dir && -d "$root/current" ) {
        $dir = "$root/current";
    }
    if ( !-d $dir ) {
        return 0;
    }
    my @dev = grep { AAPP::Config::plan_status_is( $_, 'in-development' ) } _plans_in( $dir, 0 );
    if ( @dev < 2 ) {
        return 0;
    }
    my $errors = 0;
    my $id_of  = sub {
        my ($plan) = @_;
        foreach my $line ( @{ AAPP::State::file_lines($plan) // [] } ) {
            if ( $line =~ /^\s*\*\s*\*\*Plan ID:\*\*\s*(\S+)/ ) {
                return $1;
            }
        }
        return ( $plan =~ s{.*/}{}r ) =~ s/\.md$//r;
    };
    for my $i ( 0 .. $#dev ) {
        my @a  = AAPP::State::plan_target_paths( $dev[$i] );
        my $ia = $id_of->( $dev[$i] );
        for my $j ( $i + 1 .. $#dev ) {
            my @b  = AAPP::State::plan_target_paths( $dev[$j] );
            my $ib = $id_of->( $dev[$j] );
            foreach my $ta (@a) {
                foreach my $tb (@b) {
                    if ( $ta ne $tb ) {
                        next;
                    }
                    if ( AAPP::State::is_shared_doc($ta) ) {
                        AAPP::Logger::print_msg( 'INFO', "[Shared Doc] Plans '$ia' and '$ib' both update '$ta' (shared docs never block; see union merge)." );
                        next;
                    }
                    my ( $na, $nb ) = map { $_ =~ s{.*/}{}r } ( $dev[$i], $dev[$j] );
                    AAPP::Logger::print_msg( 'ERROR', "[Pair 7 Violation] In-Flight Blueprint Collision! Plan '$ia' ($na) and plan '$ib' ($nb) both target '$ta'. In-flight plans in the same workspace cannot share target files: isolate them on separate worktrees/branches, or finish $ia first." );
                    $errors++;
                }
            }
        }
    }
    return $errors;
}

# Usage     : my $n = check_issues_table_shape($issues_file)
# Purpose   : The issues table is one unbroken table, every row with as many cells as the header (8 at least).
# Returns   : The number of problems.
sub check_issues_table_shape
{
    my ($issues_file) = @_;
    if ( !defined $issues_file || !-f $issues_file ) {
        return 0;
    }
    local $ENV{AAPP_LEDGER_ISSUES} = $issues_file;
    my ( $started, $gap, $want, $bad ) = ( 0, 0, 0, 0 );
    my $n = 0;
    foreach my $line ( AAPP::State::ledger_table('issues') ) {
        $n++;
        if ( $line =~ /^\s*\|/ ) {
            if ( $started && $gap ) {
                AAPP::Logger::print_msg( 'ERROR', "[Issues Table] Line $n: an empty line splits the table (line $gap); remove it." );
                $bad++;
            }
            ( $started, $gap ) = ( 1, 0 );
            my $cells = ( () = ( $line =~ s/\\\|//gr ) =~ /\|/g ) - 1;
            if ( !$want ) {
                $want = $cells > 8 ? $cells : 8;
            }
            if ( $cells != $want ) {
                AAPP::Logger::print_msg( 'ERROR', "[Issues Table] Line $n has $cells cells; every row needs $want." );
                $bad++;
            }
            next;
        }
        if ( $started && $line =~ /^\s*$/ ) {
            if ( !$gap ) {
                $gap = $n;
            }
            next;
        }
        if ($started) {
            ( $started, $gap ) = ( 0, 0 );
        }
    }
    return $bad;
}

# Usage     : my $n = check_pickup_entries($pickup_file)
# Purpose   : Every pickup list entry is a '- [ ] ' line; an unworked one is '- [ ] <title>: <text>' with a
#             title within aapp.pickupTitleMax, a text, and (for new or changed entries) the .plans/pickup/ files it names present.
# Returns   : The number of problems (1 when the title limit setting is invalid).
sub check_pickup_entries
{
    my ($pickup_file) = @_;
    if ( !defined $pickup_file || !-f $pickup_file ) {
        return 0;
    }
    my ( $rc, $max ) = AAPP::Text::pickup_title_max();
    if ( $rc != RETURN_OK ) {
        return 1;
    }
    my $dir  = $pickup_file =~ m{^(.*)/[^/]*$} ? $1 : '.';
    my $base = $pickup_file =~ s{.*/}{}r;
    my ( $ok, $committed ) = AAPP::Paths::git_capture( '-C', $dir, 'show', "HEAD:./$base" );
    my %old  = $ok ? map { ( $_ => 1 ) } split( /\n/, $committed ) : ();
    my $form = '"- [ ] <title>: <text>"';
    my $bad  = 0;
    my $n    = 0;
    foreach my $line ( @{ AAPP::State::file_lines($pickup_file) // [] } ) {
        $n++;
        if ( $line !~ /^(?:[*+-]|[0-9]+\.)\s/ ) {
            next;
        }
        if ( $line !~ /^- \[[ xX]\] / ) {
            AAPP::Logger::print_msg( 'ERROR', "[Pickup] Line $n is not a \"- [ ] \" entry: $line" );
            $bad++;
            next;
        }
        if ( $line !~ /^- \[ \] / ) {
            next;
        }
        my ( $title, $text ) = AAPP::Text::pickup_entry_split($line);
        if ( $title eq '' ) {
            AAPP::Logger::print_msg( 'ERROR', "[Pickup] Line $n has no title; write it as $form: $line" );
            $bad++;
            next;
        }
        my $len = AAPP::Text::char_len($title);
        if ( $len > $max ) {
            AAPP::Logger::print_msg( 'ERROR', "[Pickup] Line $n: title is $len characters; at most $max (aapp.pickupTitleMax): $title" );
            $bad++;
        }
        if ( $text eq '' ) {
            AAPP::Logger::print_msg( 'ERROR', "[Pickup] Line $n: no text after the title; write it as $form" );
            $bad++;
        }
        if ( $old{$line} ) {
            next;
        }
        foreach my $path ( AAPP::Text::pickup_entry_files($text) ) {
            my $rel = $path =~ s{^\.plans/}{}r;
            if ( !-e "$dir/$rel" ) {
                AAPP::Logger::print_msg( 'ERROR', "[Pickup] Line $n names $path, which does not exist" );
                $bad++;
            }
        }
    }
    return $bad;
}

# Usage     : my $n = check_issues_added_rows($issues_file, $committed_issues_file)
# Purpose   : No row is added by hand: every id in the ledger was already in the committed one ('aapp issue log' writes new rows).
# Returns   : The number of hand-added rows.
sub check_issues_added_rows
{
    my ( $issues_file, $old_file ) = @_;
    if ( !defined $issues_file || !-f $issues_file || !defined $old_file || !-f $old_file ) {
        return 0;
    }
    my %known = map { ( $_ => 1 ) } AAPP::State::ledger_ids( 'active', $old_file );
    my $bad   = 0;
    foreach my $id ( AAPP::State::issue_id_sort( AAPP::State::ledger_ids( 'active', $issues_file ) ) ) {
        if ( $known{$id} ) {
            next;
        }
        AAPP::Logger::print_msg( 'ERROR', "[Issue Row] #$id was added by hand; log an issue with 'aapp issue log <sev> <type> \"<symptom>\" [file <path>]…', which numbers it and writes the row." );
        $bad++;
    }
    return $bad;
}

# Usage     : my $n = check_fix_cells($issues_file)
# Purpose   : A row's Target Plan / Fix cell is empty or a plan link a verb wrote ('[P-n](…)', 'blocks [P-n](…)').
# Returns   : The number of cells holding anything else.
sub check_fix_cells
{
    my ($issues_file) = @_;
    if ( !defined $issues_file || !-f $issues_file ) {
        return 0;
    }
    local $ENV{AAPP_LEDGER_ISSUES} = $issues_file;
    my $bad = 0;
    foreach my $line ( AAPP::State::ledger_row_lines() ) {
        my @parts = split( /\|/, $line =~ s/\\\|//gr, -1 );
        my $cell  = ( $parts[7] // '' ) =~ s/^\s+|\s+$//gr;
        my $id    = ( $parts[1] // '' ) =~ s/[\s`]//gr;
        if ( $cell ne '' && $cell !~ /^(?:blocks )?\[P-[0-9]+\]\([^)]*\)$/ ) {
            AAPP::Logger::print_msg( 'ERROR', "[Fix Cell] $id: the Target Plan / Fix cell holds \"$cell\"; leave it empty (the fix writes its changelog entry) or a plan link written by a verb." );
            $bad++;
        }
    }
    return $bad;
}

# Usage     : my $n = check_ledger_issues($issues_file, $archive_file, $roadmap_file)
# Purpose   : Everything 'aapp refine issues' requires before it commits a hand-made ledger edit.
# Returns   : The number of checks that found problems.
sub check_ledger_issues
{
    my ( $issues_file, $archive_file, $roadmap_file ) = @_;
    my $failed = 0;
    $failed++ if check_issues_table_shape($issues_file);
    $failed++ if check_fix_cells($issues_file);
    $failed++ if check_pair1_disjointness( $issues_file, $archive_file );
    $failed++ if check_pair8_issue_id_integrity( $issues_file, $archive_file );
    $failed++ if check_pair2_referential_integrity( $roadmap_file, $issues_file );
    $failed++ if check_roadmap_sections($roadmap_file);
    return $failed;
}

# Usage     : my $n = check_planning_health($root)
# Purpose   : Runs every planning check (Pairs 1-8, fix cells, schema) over a repository and says the result.
# Returns   : The total number of violations.
sub check_planning_health
{
    my ($root) = @_;
    $root = repo_root($root) // return 1;
    my $issues  = find_file( 'issues',  $root );
    my $archive = find_file( 'archive', $root );
    my $roadmap = find_file( 'roadmap', $root );
    my $pickup  = find_file( 'pickup',  $root );
    AAPP::Logger::print_msg( 'INFO', "Checking planning health of $root." );
    my $total = 0;
    $total += check_pair1_disjointness( $issues, $archive );
    $total += check_pair2_referential_integrity( $roadmap, $issues );
    $total += check_roadmap_sections($roadmap);
    check_pair3_pickup_routing( $pickup, $issues, $archive );
    $total += check_pair4_plan_id_integrity($root);
    $total += check_pair5_target_files_self_protection($root);
    $total += check_pair6_recorded_sha_integrity($root);
    $total += check_pair7_inflight_boundary_collision($root);
    $total += check_pair8_issue_id_integrity( $issues, $archive );
    $total += check_fix_cells($issues) ? 1 : 0;
    $total += check_taxonomy_and_schema($issues);
    if ( $total == 0 ) {
        AAPP::Logger::print_msg( 'INFO', 'Planning health: all integrity checks passed.' );
    } else {
        AAPP::Logger::print_msg( 'ERROR', "Planning health: found $total integrity violation(s)." );
    }
    return $total;
}

1;
