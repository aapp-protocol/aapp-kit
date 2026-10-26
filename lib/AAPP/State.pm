package AAPP::State;

use strict;
use warnings;
use utf8;
use 5.026;

use File::Find ();
use AAPP::Constants qw(RETURN_OK RETURN_FAIL RETURN_ERROR RETURN_NOT_FOUND DEFAULT_COMMIT_MODE
    DEFAULT_CHANGELOG_MODE DEFAULT_SUBJECT_MAX_LEN MIN_SUBJECT_MAX_LEN DEFAULT_DEV_BRANCHES
    DEFAULT_INTEGRATE_TARGET DEFAULT_REMOTE STATE_HOME_DEFAULT);
use AAPP::Config ();
use AAPP::Util ();
use AAPP::Logger ();
use AAPP::Paths ();
use AAPP::Text ();

our %files;
our $plans_dir;

# §4 headings that list paths, by what they grant; matched by name, emoji decorative.
our %SECTION_HEADINGS = (
    targets   => [ 'Target Files', 'Required Test Files' ],
    oob       => ['Out of Bounds'],
    req_files => ['Required Test Files'],
);
our $REQUIRED_FILES_HEADING = 'Required Test Files';
our $REQUIRED_TESTS_HEADING = 'Required Tests';

# Words before a Target Files path that are not the path.
our @ACTION_MARKERS = ( 'NEW FILE', 'MODIFY', 'DELETE', 'ADD', 'REPLACE' );

# The work queue's sections (issues_road_map.md), matched by name, emoji decorative.
our $ROADMAP_BLOCKERS = 'Plan Blockers';
our $ROADMAP_QUEUED   = 'Queued';
our @QUEUE_LEVELS     = qw(Urgent Normal Low);

my $MARKER_RE = join( '|', map { quotemeta } @ACTION_MARKERS );
my $LEVEL_RE  = join( '|', map { quotemeta } @QUEUE_LEVELS );

my $ID_BODY      = qr/(?:[0-9]+|[A-Z][A-Z0-9]*-[0-9]+)/;
my $REF_LOOSE    = qr/(?:(?:#|ISSUE-)?[0-9]+|#$ID_BODY)/;
my $ROW_RE       = qr/^\s*\|\s*`?#$ID_BODY/;
my $RESOLVED_ROW = qr/^\s*\|\s*`?$REF_LOOSE`?.*(?:✅|[Rr]esolved)/;
my $ROADMAP_OPEN = qr/^\s*(?:[0-9]+\.|-\s*\[[ ]?\]|\*)\s*`?$REF_LOOSE/;
my $CHECKBOX     = qr/^\s*-\s*\[[ ]?\]\s*/;

my %LEDGER_REL = (
    issues  => 'ISSUES.md',
    archive => 'done/000-issues-archive.md',
    roadmap => 'issues_road_map.md',
);
my %LEDGER_ENV = (
    issues  => 'AAPP_LEDGER_ISSUES',
    archive => 'AAPP_LEDGER_ARCHIVE',
    roadmap => 'AAPP_LEDGER_ROADMAP',
);
my %COLUMN = (
    link   => 'Target Plan',
    status => 'Status',
    branch => 'Branch',
    commit => 'Target Commit',
);
my @SHARED_DOCS = qw(CHANGELOG.md README.md MANUAL.md CHEATSHEET.md COOKBOOK.md CODEMAP.md ARCHITECTURE.md ISSUES.md);

# ------------------------------------------------------------------------------
# Files: read once per process, decoded as UTF-8
# ------------------------------------------------------------------------------

# Usage     : my $lines = file_lines($path)
# Purpose   : The lines of a text file (without newlines), read once per process and cached.
# Returns   : Array ref, or undef when the file does not exist or cannot be read.
sub file_lines
{
    my ($path) = @_;
    if ( exists $files{$path} ) {
        return $files{$path};
    }
    my $fh;
    if ( !-f $path || !open( $fh, '<:encoding(UTF-8)', $path ) ) {
        return;
    }
    my @lines = <$fh>;
    close($fh);
    chomp(@lines);
    $files{$path} = \@lines;
    return \@lines;
}

# Usage     : forget($path)
# Purpose   : Drops a cached file after a writer changed it, so the next read sees the change.
# Returns   : undef
sub forget
{
    my ($path) = @_;
    delete $files{$path};
    return;
}

# Usage     : my $dir = plans_root()
# Purpose   : The plans worktree this process reads: $AAPP::State::plans_dir when a caller set it, else Paths.
# Returns   : The directory, or undef when there is none.
sub plans_root
{
    if ( defined $plans_dir ) {
        return $plans_dir;
    }
    return AAPP::Paths::resolve()->{plans_dir};
}

# ------------------------------------------------------------------------------
# Plan files
# ------------------------------------------------------------------------------

# Usage     : my $lines = _plan_lines($plan_file)
# Purpose   : The lines of a plan file; an unreadable plan reads as no lines.
# Returns   : Array ref.
sub _plan_lines
{
    my ($file) = @_;
    return file_lines($file) // [];
}

# Usage     : my @lines = header_lines($plan_file)
# Purpose   : The plan's header: the lines before the first '## ' heading.
# Returns   : List of lines.
sub header_lines
{
    my ($file) = @_;
    my @header;
    foreach my $line ( @{ _plan_lines($file) } ) {
        if ( $line =~ /^##\s/ ) {
            last;
        }
        push @header, $line;
    }
    return @header;
}

# Usage     : my $line = _header_line($plan_file, qr/.../)
# Purpose   : The first header line outside fenced blocks that matches a pattern.
# Returns   : The line, or undef when none matches.
sub _header_line
{
    my ( $file, $re ) = @_;
    my $fenced = 0;
    foreach my $line ( @{ _plan_lines($file) } ) {
        if ( $line =~ /^\s*```/ ) {
            $fenced = !$fenced;
            next;
        }
        if ($fenced) {
            next;
        }
        if ( $line =~ /^##\s/ ) {
            return;
        }
        if ( $line =~ $re ) {
            return $line;
        }
    }
    return;
}

# Usage     : my $value = plan_field($plan_file, 'Also Closes')
# Purpose   : The value of the header's '* **<Field>:**' line.
# Returns   : The value, or undef when the header has no such line.
sub plan_field
{
    my ( $file, $field ) = @_;
    my $key = "* **$field:**";
    foreach my $line ( header_lines($file) ) {
        if ( index( $line, $key ) == 0 ) {
            my $value = $line;
            $value =~ s/^\* \*\*[^*]+:\*\*\s*//;
            return $value;
        }
    }
    return;
}

# Usage     : my $id = plan_id($plan_file)
# Purpose   : The plan's ID from its '* **Plan ID:**' line, else from a 'P<n>-' file name.
# Returns   : 'P-<n>', or undef when neither gives one.
sub plan_id
{
    my ($file) = @_;
    foreach my $line ( @{ _plan_lines($file) } ) {
        if ( $line =~ /^\s*[*|-]\s*\*\*Plan ID:\*\*\s*(.*?)\s*$/ ) {
            my $id = $1 =~ s/`//gr;
            if ( $id ne '' ) {
                return $id;
            }
            last;
        }
    }
    my $name = $file =~ s{.*/}{}r;
    if ( $name =~ /^[pP]([0-9]+)-/ ) {
        return "P-$1";
    }
    return;
}

# Usage     : if ( is_group_plan($plan_file) ) { ... }
# Purpose   : Tells a group plan by its title's words: 'Group Plan P-<n>:'.
# Returns   : 1 for a group plan, 0 otherwise.
sub is_group_plan
{
    my ($file) = @_;
    my $first = _plan_lines($file)->[0] // '';
    my ( $level, $name ) = AAPP::Text::heading_name($first);
    if ( defined $level && $level == 1 && $name =~ /^Group Plan P-[0-9]+:/ ) {
        return 1;
    }
    return 0;
}

# Usage     : my @shas = plan_commits($plan_file)
# Purpose   : The commits the header records: the backticked hash of each '* **Commits:**' item;
#             anything after the hash (an old '(branch)') is ignored.
# Returns   : List of hashes; empty for 'none' or no line.
sub plan_commits
{
    my ($file) = @_;
    my $line = _header_line( $file, qr/^\s*[*|-]*\s*\*\*Commits:\*\*/ );
    if ( !defined $line ) {
        return ();
    }
    my $value = $line =~ s/^\s*[*|-]*\s*\*\*Commits:\*\*\s*//r;
    if ( $value eq 'none' || $value eq '' ) {
        return ();
    }
    my @commits;
    foreach my $item ( split( /,/, $value ) ) {
        $item =~ s/^\s+//;
        $item =~ s/\s+$//;
        if ( $item =~ /^`([0-9a-fA-F]+)`/ ) {
            push @commits, $1;
        }
    }
    return @commits;
}

# Usage     : my $sha = plan_base($plan_file)
# Purpose   : The commit the plan was started from, as '* **Base:**' records it.
# Returns   : The SHA, or undef for a plan never started.
sub plan_base
{
    my ($file) = @_;
    my $line = _header_line( $file, qr/^\s*[*|-]*\s*\*\*Base:\*\*/ );
    if ( defined $line && $line =~ /\*\*Base:\*\*\s*`([0-9a-fA-F]+)`/ ) {
        return $1;
    }
    return;
}

# Usage     : my $branch = plan_base_branch($plan_file)
# Purpose   : The plan's parent branch, named in '* **Base:**'.
# Returns   : The branch, or undef for a plan never started or started detached.
sub plan_base_branch
{
    my ($file) = @_;
    foreach my $line ( header_lines($file) ) {
        if ( $line =~ /^\* \*\*Base:\*\*/ ) {
            if ( $line =~ /^\* \*\*Base:\*\*\s*`[0-9a-fA-F]+`\s*\(([^)]+)\)/ && $1 ne 'detached' ) {
                return $1;
            }
            return;
        }
    }
    return;
}

# Usage     : my ($path, $branch) = plan_worktree($plan_file)
# Purpose   : The plan's worktree from '* **Worktree:** <path> (<branch>)'; the path is relative to the primary checkout.
# Returns   : (path, branch), or () when the header names none.
sub plan_worktree
{
    my ($file) = @_;
    foreach my $line ( header_lines($file) ) {
        if ( $line =~ /^\* \*\*Worktree:\*\*/ ) {
            if ( $line =~ /^\* \*\*Worktree:\*\*\s*(.+)\s+\(([^)]+)\)\s*$/ ) {
                return ( $1, $2 );
            }
            return ();
        }
    }
    return ();
}

# Usage     : my $n = plan_emergency_hotfix_count($plan_file)
# Purpose   : How many issues the header's '* **Emergency Hotfixes:**' line names.
# Returns   : The count.
sub plan_emergency_hotfix_count
{
    my ($file) = @_;
    foreach my $line ( header_lines($file) ) {
        if ( $line =~ /^\* \*\*Emergency Hotfixes:\*\*/ ) {
            my @ids = issue_id_refs($line);
            return scalar(@ids);
        }
    }
    return 0;
}

# Usage     : my @ids = plan_also_closes($plan_file)
# Purpose   : The further issues a plan closes, from '* **Also Closes:**'.
# Returns   : List of ids ('#<n>').
sub plan_also_closes
{
    my ($file) = @_;
    my $value = plan_field( $file, 'Also Closes' );
    if ( !defined $value ) {
        return ();
    }
    return issue_id_refs($value);
}

# Usage     : my @ids = group_members($group_file)
# Purpose   : The member IDs a group plan lists in '* **Members:**'.
# Returns   : List of 'P-<n>'.
sub group_members
{
    my ($file) = @_;
    my $value = plan_field( $file, 'Members' ) // '';
    my @members;
    foreach my $item ( split( /,/, $value ) ) {
        $item =~ s/^\s+//;
        $item =~ s/\s+$//;
        if ( $item =~ /^P-[0-9]+$/ ) {
            push @members, $item;
        }
    }
    return @members;
}

# Usage     : my ($section, $text) = plan_changelog_decl($plan_file)
# Purpose   : The plan's declared CHANGELOG entry: '* **Changelog:** <Added|Changed|Fixed>: <text>'.
# Returns   : (section, text), or () when the line is missing or malformed.
sub plan_changelog_decl
{
    my ($file) = @_;
    foreach my $line ( @{ _plan_lines($file) } ) {
        if ( $line !~ /^\s*\*\s*\*\*Changelog:\*\*/ ) {
            next;
        }
        my $value = $line =~ s/^\s*\*\s*\*\*Changelog:\*\*\s*//r;
        $value =~ s/\s+$//;
        if ( $value =~ /^(Added|Changed|Fixed):\s*(.+)$/ ) {
            return ( $1, $2 );
        }
        return ();
    }
    return ();
}

# Usage     : my @paths = _section_paths($plan_file, 'targets')
# Purpose   : The backticked paths listed under §4's headings: 'targets' (Target Files and Required
#             Test Files), 'oob' (Out of Bounds) or 'req_files' (Required Test Files). Headings match by
#             name, emoji decorative; fenced blocks and '>' lines are never read; any other heading ends a list.
# Returns   : List of paths, in order.
sub _section_paths
{
    my ( $file, $mode ) = @_;
    my @names  = @{ $SECTION_HEADINGS{$mode} };
    my $fenced = 0;
    my $in4    = 0;
    my $region = 0;
    my @paths;
    foreach my $line ( @{ _plan_lines($file) } ) {
        if ( $line =~ /^\s*```/ ) {
            $fenced = !$fenced;
            next;
        }
        if ($fenced) {
            next;
        }
        if ( $line =~ /^#+\s/ ) {
            $region = 0;
            if ( $line =~ /^##?\s/ ) {
                $in4 = $line =~ /^## (?:[^0-9]*\s)?4\./ ? 1 : 0;
                next;
            }
            if ( !$in4 ) {
                next;
            }
            my ( $level, $name ) = AAPP::Text::heading_name($line);
            if ( $level == 3 && grep { $name =~ /^\Q$_\E\s*(?:\(.*)?$/ } @names ) {
                $region = 1;
            }
            next;
        }
        if ( !$region || $line =~ /^\s*>/ ) {
            next;
        }
        my $item = $line;
        $item =~ s/^\s*-\s*(?:\[[ xX]\]\s*)?//;
        $item =~ s/^\s*(?:`?(?:$MARKER_RE)`?)?\s*->\s*//;
        if ( $item =~ /`([^`]+)`/ && $1 !~ /^(?:$MARKER_RE)$/ ) {
            push @paths, $1;
        }
    }
    return @paths;
}

# Usage     : my @paths = plan_target_paths($plan_file)
# Purpose   : The paths a plan may write: §4's Target Files and Required Test Files.
# Returns   : List of paths.
sub plan_target_paths
{
    my ($file) = @_;
    return _section_paths( $file, 'targets' );
}

# Usage     : my @paths = plan_oob_paths($plan_file)
# Purpose   : The paths §4's Out of Bounds vetoes.
# Returns   : List of paths.
sub plan_oob_paths
{
    my ($file) = @_;
    return _section_paths( $file, 'oob' );
}

# Usage     : my @paths = plan_required_test_files($plan_file)
# Purpose   : The test files §4's Required Test Files declares.
# Returns   : List of paths.
sub plan_required_test_files
{
    my ($file) = @_;
    return _section_paths( $file, 'req_files' );
}

# Usage     : if ( plan_has_required_test_files($plan_file) ) { ... }
# Purpose   : Tells whether §4 carries a Required Test Files heading.
# Returns   : 1 when it does, 0 otherwise.
sub plan_has_required_test_files
{
    my ($file) = @_;
    my $fenced = 0;
    my $in4    = 0;
    foreach my $line ( @{ _plan_lines($file) } ) {
        if ( $line =~ /^\s*```/ ) {
            $fenced = !$fenced;
            next;
        }
        if ( $fenced || $line !~ /^#+\s/ ) {
            next;
        }
        if ( $line =~ /^##?\s/ ) {
            $in4 = $line =~ /^## (?:[^0-9]*\s)?4\./ ? 1 : 0;
            next;
        }
        my ( $level, $name ) = AAPP::Text::heading_name($line);
        if ( $in4 && $level == 3 && $name =~ /^\Q$REQUIRED_FILES_HEADING\E\s*(?:\(.*)?$/ ) {
            return 1;
        }
    }
    return 0;
}

# Usage     : my @files = plan_required_tests($plan_file)
# Purpose   : The test files §3's Required Tests checkboxes name (the part before '::'), each once.
# Returns   : List of paths.
sub plan_required_tests
{
    my ($file) = @_;
    my $fenced = 0;
    my $in3    = 0;
    my $region = 0;
    my %seen;
    my @tests;
    foreach my $line ( @{ _plan_lines($file) } ) {
        if ( $line =~ /^\s*```/ ) {
            $fenced = !$fenced;
            next;
        }
        if ($fenced) {
            next;
        }
        if ( $line =~ /^#+\s/ ) {
            $region = 0;
            if ( $line =~ /^##?\s/ ) {
                $in3 = $line =~ /^## (?:[^0-9]*\s)?3\./ ? 1 : 0;
                next;
            }
            my ( $level, $name ) = AAPP::Text::heading_name($line);
            if ( $in3 && $level == 3 && $name =~ /^\Q$REQUIRED_TESTS_HEADING\E\s*(?:\(.*)?$/ ) {
                $region = 1;
            }
            next;
        }
        if ( !$region || $line =~ /^\s*>/ || $line !~ /^\s*-\s*\[[ xX]\]/ ) {
            next;
        }
        my $item = $line =~ s/^\s*-\s*\[[ xX]\]\s*//r;
        $item =~ s/\s*->.*$//;
        if ( $item =~ /`([^`]+)`/ ) {
            $item = $1;
        }
        $item =~ s/::.*$//;
        $item =~ s/\s//g;
        if ( $item ne '' && !$seen{$item}++ ) {
            push @tests, $item;
        }
    }
    return @tests;
}

# Usage     : my $rc = plan_tdd_correspondence($plan_file, 'Freeze')
# Purpose   : For a plan that declares Required Test Files: §3's tests and §4's files must name the
#             same files, both ways. A plan without the heading passes.
# Returns   : RETURN_OK, or RETURN_FAIL after an [ ERROR ] line naming the first mismatch.
sub plan_tdd_correspondence
{
    my ( $file, $label ) = @_;
    $label //= 'TDD Verification';
    if ( !plan_has_required_test_files($file) ) {
        return RETURN_OK;
    }
    my @files = plan_required_test_files($file);
    my @tests = plan_required_tests($file);
    if ( !@files ) {
        AAPP::Logger::print_msg( 'ERROR', "[$label] The plan carries 'Required Test Files' but declares no test files." );
        return RETURN_FAIL;
    }
    if ( !@tests ) {
        AAPP::Logger::print_msg( 'ERROR', "[$label] The plan carries 'Required Test Files' but §3 'Required Tests' names no test." );
        return RETURN_FAIL;
    }
    my %file_set = map { $_ => 1 } @files;
    my %test_set = map { $_ => 1 } @tests;
    foreach my $test (@tests) {
        if ( !$file_set{$test} ) {
            AAPP::Logger::print_msg( 'ERROR', "[$label] §3 names test file '$test', which §4 'Required Test Files' does not declare." );
            return RETURN_FAIL;
        }
    }
    foreach my $declared (@files) {
        if ( !$test_set{$declared} ) {
            AAPP::Logger::print_msg( 'ERROR', "[$label] §4 declares test file '$declared', which no §3 'Required Tests' line names." );
            return RETURN_FAIL;
        }
    }
    return RETURN_OK;
}

# Usage     : my @lines = plan_section($plan_file, 4)
# Purpose   : A numbered section ('## ... <n>.') up to the next numbered section, heading included.
#             A heading inside a fenced block (a quoted document) neither starts nor ends a section.
# Returns   : List of lines.
sub plan_section
{
    my ( $file, $number ) = @_;
    my $on     = 0;
    my $fenced = 0;
    my @lines;
    foreach my $line ( @{ _plan_lines($file) } ) {
        if ( $line =~ /^\s*```/ ) {
            $fenced = !$fenced;
        }
        if ( $fenced || $line =~ /^\s*```/ ) {
            if ($on) {
                push @lines, $line;
            }
            next;
        }
        if ( $line =~ /^## (?:[^0-9]*\s)?\Q$number\E\./ ) {
            $on = 1;
            push @lines, $line;
            next;
        }
        if ( $on && $line =~ /^## (?:[^0-9]*\s)?[0-9]+\./ ) {
            $on = 0;
        }
        if ($on) {
            push @lines, $line;
        }
    }
    return @lines;
}

# Usage     : my ($done, $total, $unit) = plan_progress($plan_file)
# Purpose   : A plan's progress: §3 checkboxes ('tasks'), or for a group its members archived ('members').
# Returns   : (done, total, unit), or () when nothing counts.
sub plan_progress
{
    my ($file) = @_;
    if ( !-f $file ) {
        return ();
    }
    if ( is_group_plan($file) ) {
        my @members = group_members($file);
        if ( !@members ) {
            return ();
        }
        my $dir = $file =~ m{^(.*)/[^/]*$} ? $1 : '.';
        my ( $done_dir, $current_dir ) = ( "$dir/../done", $dir );
        if ( !-d $done_dir ) {
            ( $done_dir, $current_dir ) = -d '.plans/done' ? ( '.plans/done', '.plans/current' ) : ( 'done', 'current' );
        }
        my $done = 0;
        foreach my $member (@members) {
            my $num     = $member =~ s/^P-//r;
            my @in_done = ( glob("\Q$done_dir\E/P$num-*.md"), glob("\Q$done_dir\E/P$num.md") );
            my @in_curr = ( glob("\Q$current_dir\E/P$num-*.md"), glob("\Q$current_dir\E/P$num.md") );
            if ( ( grep { -f } @in_done ) && !( grep { -f } @in_curr ) ) {
                $done++;
            }
        }
        return ( $done, scalar(@members), 'members' );
    }
    my $code  = 0;
    my $in3   = 0;
    my $total = 0;
    my $done  = 0;
    foreach my $line ( @{ _plan_lines($file) } ) {
        if ( $line =~ /^```/ ) {
            $code = !$code;
            next;
        }
        if ($code) {
            next;
        }
        if ( $line =~ /^## [^#0-9]*3\./ ) {
            $in3 = 1;
            next;
        }
        if ( $in3 && $line =~ /^## / ) {
            $in3 = 0;
        }
        if ( $in3 && $line =~ /^\s*- \[([ xX])\]/ ) {
            $total++;
            if ( $1 ne ' ' ) {
                $done++;
            }
        }
    }
    if ( $total == 0 ) {
        return ();
    }
    return ( $done, $total, 'tasks' );
}

# Usage     : my @files = current_plans()
# Purpose   : The plan files in .plans/current/ (not the 000- registers), sorted by name.
# Returns   : List of paths.
sub current_plans
{
    my $root = plans_root();
    if ( !defined $root ) {
        return ();
    }
    my @plans = AAPP::Util::plan_sort( grep { -f $_ && $_ !~ m{/000-[^/]*$} } glob("\Q$root\E/current/*.md") );
    return @plans;
}

# ------------------------------------------------------------------------------
# Settings read for plans
# ------------------------------------------------------------------------------

# Usage     : my $mode = commit_mode()
# Purpose   : 'microcommits' when aapp.commitMode says so, else 'atomic'.
# Returns   : The mode.
sub commit_mode
{
    my $mode = AAPP::Config::get('aapp.commitMode') // DEFAULT_COMMIT_MODE;
    return $mode eq 'microcommits' ? 'microcommits' : 'atomic';
}

# Usage     : my $mode = plan_commit_mode($plan_file)
# Purpose   : The commit mode a plan is built under: 'microcommits' for a group's amendments member, else commit_mode().
# Returns   : The mode.
sub plan_commit_mode
{
    my ($file) = @_;
    my $kind = plan_field( $file, 'Kind' ) // '';
    if ( $kind eq 'amendments' ) {
        return 'microcommits';
    }
    return commit_mode();
}

# Usage     : my $mode = changelog_mode()
# Purpose   : 'commit' when aapp.changelogMode says so, else 'plan'.
# Returns   : The mode.
sub changelog_mode
{
    my $mode = AAPP::Config::get('aapp.changelogMode') // DEFAULT_CHANGELOG_MODE;
    return $mode eq 'commit' ? 'commit' : 'plan';
}

# Usage     : my ($rc, $max) = subject_max_len()
# Purpose   : The most characters a commit subject may have: aapp.subjectMaxLen, default 72, at least 1.
# Returns   : (RETURN_OK, $max), or (RETURN_ERROR, undef) after an [ ERROR ] line naming the key.
sub subject_max_len
{
    return AAPP::Config::get_int( 'aapp.subjectMaxLen', DEFAULT_SUBJECT_MAX_LEN, MIN_SUBJECT_MAX_LEN );
}

# Usage     : my $ref = branch_ref('develop')
# Purpose   : The ref to branch from for a name: the local branch, else the first remote-tracking one.
# Returns   : The ref, or undef when neither exists.
sub branch_ref
{
    my ($name) = @_;
    if ( !defined $name || $name eq '' ) {
        return;
    }
    my ($local) = AAPP::Paths::git_capture( 'show-ref', '--verify', '--quiet', "refs/heads/$name" );
    if ($local) {
        return $name;
    }
    my ( $ok, $out ) = AAPP::Paths::git_capture( 'for-each-ref', '--format=%(refname:short)', "refs/remotes/*/$name" );
    my ($remote) = split( /\n/, $out );
    if ( $ok && defined $remote && $remote ne '' ) {
        return $remote;
    }
    return;
}

# Usage     : my $branch = dev_branch()
# Purpose   : The first aapp.devBranch candidate (default 'develop dev development') that exists.
# Returns   : The branch, or undef when none does.
sub dev_branch
{
    my $candidates = AAPP::Config::get('aapp.devBranch') // DEFAULT_DEV_BRANCHES;
    foreach my $name ( split( ' ', $candidates ) ) {
        if ( defined branch_ref($name) ) {
            return $name;
        }
    }
    return;
}

# Usage     : my $branch = integrate_target($plan_file)
# Purpose   : The branch a plan integrates into, per aapp.integrateTarget: 'parent' (default, the Base
#             branch), 'dev' (the development branch) or a branch name.
# Returns   : The branch, or undef when none resolves.
sub integrate_target
{
    my ($file) = @_;
    my $mode = AAPP::Config::get('aapp.integrateTarget') // DEFAULT_INTEGRATE_TARGET;
    my $target;
    if ( $mode eq 'parent' || $mode eq '' ) {
        $target = plan_base_branch($file);
    } elsif ( $mode eq 'dev' ) {
        $target = dev_branch();
    } else {
        $target = $mode;
    }
    if ( !defined $target || $target eq '' || $target eq 'detached' ) {
        return;
    }
    return $target;
}

# Usage     : if ( is_shared_doc($path) ) { ... }
# Purpose   : Tells a shared document (any file under docs/, or a kit document such as README.md).
# Returns   : 1 for a shared document, 0 otherwise.
sub is_shared_doc
{
    my ($path) = @_;
    if ( $path =~ m{^docs/} || $path =~ m{/docs/} ) {
        return 1;
    }
    my $base = $path =~ s{.*/}{}r;
    if ( grep { $_ eq $base } @SHARED_DOCS ) {
        return 1;
    }
    return 0;
}

# ------------------------------------------------------------------------------
# Active plan buffers
# ------------------------------------------------------------------------------

# Usage     : my $path = _buffer_path($worktree)
# Purpose   : Where a worktree keeps its active-plan buffer.
# Returns   : The absolute path, or undef when git cannot say.
sub _buffer_path
{
    my ($worktree) = @_;
    my ( $ok, $out ) = AAPP::Paths::git_capture( '-C', $worktree, 'rev-parse', '--git-path', 'aapp_active_plan' );
    chomp($out);
    if ( !$ok || $out eq '' ) {
        return;
    }
    if ( $out !~ m{^/} ) {
        $out = "$worktree/$out";
    }
    return $out;
}

# Usage     : my $id = _read_buffer($path)
# Purpose   : The plan a buffer file names, whitespace removed.
# Returns   : The text, or undef when the file is absent or empty.
sub _read_buffer
{
    my ($path) = @_;
    my $fh;
    if ( !defined $path || !-f $path || !open( $fh, '<:encoding(UTF-8)', $path ) ) {
        return;
    }
    my $text = do { local $/; <$fh> } // '';
    close($fh);
    $text =~ s/\s//g;
    if ( $text eq '' ) {
        return;
    }
    return $text;
}

# Usage     : my $file = active_buffer_file()
# Purpose   : The active-plan buffer of this checkout.
# Returns   : The path (it may not exist), or undef outside a repository.
sub active_buffer_file
{
    my $root = AAPP::Paths::resolve()->{root};
    if ( !defined $root ) {
        return;
    }
    return _buffer_path($root);
}

# Usage     : my $id = active_plan_id()
# Purpose   : The plan this checkout's buffer names.
# Returns   : The text written in the buffer, or undef when none is set.
sub active_plan_id
{
    return _read_buffer( active_buffer_file() );
}

# Usage     : my @held = held_plans()
# Purpose   : The plans held by the buffers of OTHER worktrees of this repository (the kit's own
#             worktrees and vanished ones skipped). "Other" is judged from this checkout.
# Returns   : List of [plan text, worktree path].
sub held_plans
{
    my $root = AAPP::Paths::resolve()->{root};
    if ( !defined $root ) {
        return ();
    }
    my ( $ok, $out ) = AAPP::Paths::git_capture( 'worktree', 'list', '--porcelain' );
    if ( !$ok ) {
        return ();
    }
    my @held;
    foreach my $line ( split( /\n/, $out ) ) {
        if ( $line !~ /^worktree (.+)$/ ) {
            next;
        }
        my $path = $1;
        if ( $path eq $root || $path =~ m{/\.(?:plans|agents|githooks)$} || !-d $path ) {
            next;
        }
        my $id = _read_buffer( _buffer_path($path) );
        if ( defined $id ) {
            push @held, [ $id, $path ];
        }
    }
    return @held;
}

# Usage     : my $worktree = plan_held_by($plan_file, @held)
# Purpose   : The worktree holding a plan, matched by Plan ID or file name as buffers write them.
# Returns   : The worktree path, or undef when no other worktree holds it.
sub plan_held_by
{
    my ( $file, @held ) = @_;
    if ( !@held || !-f $file ) {
        return;
    }
    my $pid;
    foreach my $line ( @{ _plan_lines($file) } ) {
        if ( $line =~ /^\s*\*\s*\*\*Plan ID:\*\*\s*`?([^\s`]+)`?/ ) {
            $pid = $1;
            last;
        }
    }
    my $base = $file =~ s{.*/}{}r;
    $base =~ s/\.md$//;
    foreach my $entry (@held) {
        my ( $h, $worktree ) = @{$entry};
        if ( defined $pid && ( $h eq $pid || "P-$h" eq $pid ) ) {
            return $worktree;
        }
        my $num = $h =~ s/^P-//r;
        if ( $h eq $base || index( $base, "$h-" ) == 0 || index( $base, "P$num-" ) == 0 ) {
            return $worktree;
        }
    }
    return;
}

# ------------------------------------------------------------------------------
# Issue IDs: the one definition of what an id is
# ------------------------------------------------------------------------------

# Usage     : my $body = _id_body($text)
# Purpose   : An id's body, normalised (46, #46, `#046`, ISSUE-46 give 46; proj-101 gives PROJ-101).
# Returns   : The body, or undef for anything else.
sub _id_body
{
    my ($raw) = @_;
    my $n = ( $raw // '' ) =~ s/`//gr;
    $n =~ s/^#//;
    my $num = $n =~ s/^(?:ISSUE|issue)-//r;
    if ( $num =~ /^[0-9]+$/ ) {
        return 0 + $num;
    }
    $n = uc $n;
    if ( $n =~ /^[A-Z][A-Z0-9]*-[0-9]+$/ ) {
        return $n;
    }
    return;
}

# Usage     : my $body = issue_id_body($text)
# Purpose   : An id's body, as _id_body gives it; anything else is refused with an [ ERROR ] line naming the forms.
# Returns   : The body, or undef.
sub issue_id_body
{
    my ($raw) = @_;
    my $body = _id_body($raw);
    if ( !defined $body ) {
        AAPP::Logger::print_msg( 'ERROR', "Not an issue ID: '$raw' (use a number or a tracker's key, e.g. 46 or PROJ-101)." );
        return;
    }
    return $body;
}

# Usage     : my $id = issue_id_normalize($text)
# Purpose   : An id as it is written: '#<body>'.
# Returns   : The id, or undef after an [ ERROR ] line.
sub issue_id_normalize
{
    my ($raw) = @_;
    my $body = issue_id_body($raw);
    if ( !defined $body ) {
        return;
    }
    return "#$body";
}

# Usage     : if ( issue_id_valid($text) ) { ... }
# Purpose   : Tells one well-formed id, with or without '#'; prints nothing.
# Returns   : 1 when valid, 0 otherwise.
sub issue_id_valid
{
    my ($raw) = @_;
    return defined _id_body($raw) ? 1 : 0;
}

# Usage     : if ( issue_id_is_numeric($id) ) { ... }
# Purpose   : Tells an id the kit's counter could have issued (digits only).
# Returns   : 1 when numeric, 0 otherwise.
sub issue_id_is_numeric
{
    my ($id) = @_;
    my $body = ( $id // '' ) =~ s/^#//r;
    return $body =~ /^[0-9]+$/ ? 1 : 0;
}

# Usage     : my @ids = issue_id_refs($text)
# Purpose   : The ids written in a text, in order. An id starts at a '#' not preceded by '#', a letter
#             or a digit, and must not run on into a letter or digit (headings and hex tokens are not ids).
# Returns   : List of ids ('#<body>').
sub issue_id_refs
{
    my ($text) = @_;
    my @ids;
    foreach my $line ( split( /\n/, $text // '' ) ) {
        while ( $line =~ /#$ID_BODY/g ) {
            my $end   = pos($line);
            my $start = $-[0];
            my $id    = substr( $line, $start, $end - $start );
            my $prev  = $start > 0 ? substr( $line, $start - 1, 1 ) : '';
            my $next  = substr( $line, $end, 1 );
            if ( $prev !~ /[#A-Za-z0-9]/ && $next !~ /[A-Za-z0-9]/ ) {
                push @ids, $id;
            }
        }
    }
    return @ids;
}

# Usage     : my $body = issue_id_at_start($text)
# Purpose   : The body of the id a text begins with (after blanks), as a Target Issue value does.
# Returns   : The body, or undef when the text begins otherwise.
sub issue_id_at_start
{
    my ($text) = @_;
    my $t = ( $text // '' ) =~ s/^\s+//r;
    if ( $t !~ /^#/ ) {
        return;
    }
    my ($first) = issue_id_refs($t);
    if ( !defined $first || index( $t, $first ) != 0 ) {
        return;
    }
    return substr( $first, 1 );
}

# Usage     : my @bodies = issue_id_sort(@bodies)
# Purpose   : Id bodies sorted and unique: numbers by value, then keys by name and number.
# Returns   : The sorted list.
sub issue_id_sort
{
    my (@bodies) = @_;
    my %seen;
    my @unique = grep { !$seen{$_}++ } @bodies;
    my @sorted = sort { _id_sort_key($a) cmp _id_sort_key($b) } @unique;
    return @sorted;
}

# Usage     : my $key = _id_sort_key($body)
# Purpose   : A text that sorts numbers by value before keys by name and number.
# Returns   : The sort key.
sub _id_sort_key
{
    my ($body) = @_;
    if ( $body =~ /^[0-9]+$/ ) {
        return sprintf( "0\t%020d", $body );
    }
    my ( $key, $num ) = $body =~ /^(.*)-([0-9]+)$/;
    return sprintf( "1\t%s\t%020d", $key, $num );
}

# Usage     : my $name = issue_fix_name('#46')
# Purpose   : The file name of an issue's mini plan.
# Returns   : 'fix-<body>.md'.
sub issue_fix_name
{
    my ($id) = @_;
    my $body = $id =~ s/^#//r;
    return "fix-$body.md";
}

# Usage     : my $id = issue_fix_id('current/fix-46.md')
# Purpose   : The id a mini plan's file name stands for.
# Returns   : '#<body>', or undef after an [ ERROR ] line.
sub issue_fix_id
{
    my ($name) = @_;
    my $body = $name =~ s{.*/}{}r;
    $body =~ s/^fix-//;
    $body =~ s/\.md$//;
    return issue_id_normalize($body);
}

# ------------------------------------------------------------------------------
# Issue ledgers: ISSUES.md, done/000-issues-archive.md, issues_road_map.md
# ------------------------------------------------------------------------------

# Usage     : my $rel = ledger_rel('archive')
# Purpose   : A ledger's path inside the plans worktree.
# Returns   : The relative path, or undef for an unknown ledger.
sub ledger_rel
{
    my ($which) = @_;
    return $LEDGER_REL{$which};
}

# Usage     : my $path = ledger_path('issues', $root)
# Purpose   : A ledger's path: a caller's AAPP_LEDGER_* override, else <root> alone when given, else the
#             plans worktree, then <checkout>/.plans/, then <checkout>/. When the file is nowhere, where it would be.
# Returns   : The path, or undef with no place to look.
sub ledger_path
{
    my ( $which, $root ) = @_;
    my $rel = $LEDGER_REL{$which};
    if ( !defined $rel ) {
        return;
    }
    my $given = $ENV{ $LEDGER_ENV{$which} };
    if ( defined $given && $given ne '' ) {
        return $given;
    }
    if ( defined $root && $root ne '' ) {
        if ( -f "$root/.plans/$rel" ) {
            return "$root/.plans/$rel";
        }
        if ( -f "$root/$rel" ) {
            return "$root/$rel";
        }
        return "$root/.plans/$rel";
    }
    my $plans = plans_root();
    if ( defined $plans && -f "$plans/$rel" ) {
        return "$plans/$rel";
    }
    my $checkout = AAPP::Paths::resolve()->{root};
    if ( defined $checkout && -f "$checkout/.plans/$rel" ) {
        return "$checkout/.plans/$rel";
    }
    if ( defined $checkout && -f "$checkout/$rel" ) {
        return "$checkout/$rel";
    }
    if ( defined $plans ) {
        return "$plans/$rel";
    }
    if ( defined $checkout ) {
        return "$checkout/.plans/$rel";
    }
    return;
}

# Usage     : my @files = ledger_archive_files($root)
# Purpose   : Every archive ledger: the live one, its overflow files, and the release bundles' archives.
# Returns   : List of paths that exist.
sub ledger_archive_files
{
    my ($root) = @_;
    my $file = ledger_path( 'archive', $root );
    if ( !defined $file ) {
        return ();
    }
    my @files;
    if ( -f $file ) {
        push @files, $file;
    }
    my $dir = $file =~ s{/[^/]*$}{}r;
    push @files, grep { -f } sort glob("\Q$dir\E/000-issues-archive-*.md");
    my $plans = $dir =~ s{/[^/]*$}{}r;
    push @files, grep { -f } sort glob("\Q$plans\E/release/*/000-issues-archive.md");
    return @files;
}

# Usage     : my @lines = ledger_table('archive', $root)
# Purpose   : A ledger as written; for the archive also the rows of its overflow and release files.
# Returns   : List of lines.
sub ledger_table
{
    my ( $which, $root ) = @_;
    my $file = ledger_path( $which, $root );
    my @lines;
    if ( defined $file && -f $file ) {
        push @lines, @{ file_lines($file) // [] };
    }
    if ( $which eq 'archive' && defined $file ) {
        my @all = ledger_archive_files($root);
        foreach my $extra ( grep { $_ ne $file } @all ) {
            push @lines, grep { $_ =~ $ROW_RE } @{ file_lines($extra) // [] };
        }
    }
    return @lines;
}

# Usage     : my @cells = split_row($line)
# Purpose   : The parts of a table row between '|', numbered as awk numbers them: [1] is the text
#             before the first '|', [2] the first cell, the last one the text after the last '|'.
#             Escaped pipes stay inside their cell; every part is trimmed.
# Returns   : List of parts, [0] unused.
sub split_row
{
    my ($line) = @_;
    my $masked = $line =~ s/\\\|/\x01/gr;
    my @parts  = split( /\|/, $masked, -1 );
    foreach my $part (@parts) {
        $part =~ s/^[ \t]+|[ \t]+$//g;
        $part =~ s/\x01/\\|/g;
    }
    return ( '', @parts );
}

# Usage     : my $col = ledger_column($file, 'Branch')
# Purpose   : The position of the column whose header starts with a name, in the table whose header begins with '#'.
# Returns   : The cell index (as split_row numbers it), or undef when the table has no such column.
sub ledger_column
{
    my ( $file, $name ) = @_;
    foreach my $line ( @{ file_lines($file) // [] } ) {
        if ( $line !~ /^\s*\|\s*#\s*\|/ ) {
            next;
        }
        my @cells = split_row($line);
        for my $i ( 2 .. $#cells - 1 ) {
            if ( index( $cells[$i], $name ) == 0 ) {
                return $i;
            }
        }
        return;
    }
    return;
}

# Usage     : my $re = _row_regex('46')
# Purpose   : The pattern of the ledger row whose first cell is #<n>.
# Returns   : A compiled regex.
sub _row_regex
{
    my ($n) = @_;
    return qr/^\s*\|\s*`?#\Q$n\E`?\s*\|/;
}

# Usage     : my $line = _first_match($file, $re)
# Purpose   : The first line of a file that matches a pattern.
# Returns   : The line, or undef.
sub _first_match
{
    my ( $file, $re ) = @_;
    if ( !defined $file ) {
        return;
    }
    foreach my $line ( @{ file_lines($file) // [] } ) {
        if ( $line =~ $re ) {
            return $line;
        }
    }
    return;
}

# Usage     : my $row = ledger_row('46')
# Purpose   : The active row of #<n> as written; else one staged offline; else the row of the id a
#             former offline id now has.
# Returns   : The line, or undef when there is none.
sub ledger_row
{
    my ($n) = @_;
    my $re  = _row_regex($n);
    my $row = _first_match( ledger_path('issues'), $re );
    if ( defined $row ) {
        return $row;
    }
    if ( $ENV{AAPP_LEDGER_OFFLINE} ) {
        return;
    }
    $row = _first_match( offline_ledger_path('issues'), $re );
    if ( defined $row ) {
        return $row;
    }
    my $real = ledger_alias($n);
    if ( !defined $real || $real eq $n ) {
        return;
    }
    return ledger_row($real);
}

# Usage     : my @lines = ledger_row_lines($status)
# Purpose   : Every active row as written, in file order; with $status, the rows whose Status cell contains it.
# Returns   : List of lines.
sub ledger_row_lines
{
    my ($status) = @_;
    my $file = ledger_path('issues');
    if ( !defined $file || !-f $file ) {
        return ();
    }
    my @rows = grep { $_ =~ $ROW_RE } @{ file_lines($file) // [] };
    if ( !defined $status || $status eq '' ) {
        return @rows;
    }
    my $col = ledger_column( $file, 'Status' ) // 9;
    return grep { my @c = split_row($_); index( $c[$col] // '', $status ) >= 0 } @rows;
}

# Usage     : my @rows = ledger_rows($status, $file)
# Purpose   : The active rows as cells: [id, sev, type, date, location, symptom, link, status, 'local'];
#             with $status, the rows whose Status cell contains it. $file defaults to the issues ledger.
# Returns   : List of array refs.
sub ledger_rows
{
    my ( $status, $file, $source ) = @_;
    $file   //= ledger_path('issues');
    $source //= 'local';
    if ( !defined $file || !-f $file ) {
        return ();
    }
    my @rows;
    foreach my $line ( @{ file_lines($file) // [] } ) {
        if ( $line !~ $ROW_RE ) {
            next;
        }
        my @c = split_row($line);
        if ( $#c < 10 ) {
            next;
        }
        if ( defined $status && $status ne '' && index( $c[9], $status ) < 0 ) {
            next;
        }
        my $id = $c[2] =~ s/`//gr;
        push @rows, [ $id, @c[ 3 .. 9 ], $source ];
    }
    return @rows;
}

# Usage     : my @lines = ledger_resolved_rows()
# Purpose   : Rows left in the active ledger although marked resolved (they belong in the archive).
# Returns   : List of lines.
sub ledger_resolved_rows
{
    my $file = ledger_path('issues');
    if ( !defined $file || !-f $file ) {
        return ();
    }
    return grep { $_ =~ $RESOLVED_ROW } @{ file_lines($file) // [] };
}

# Usage     : my @ids = ledger_ids('archive')
# Purpose   : The issue ids of one ledger (active, archive with its overflow and release files, or roadmap),
#             bare and in file order: '#12', '`#012`' and 'ISSUE-12' all give 12.
# Returns   : List of id bodies.
sub ledger_ids
{
    my ( $which, $file ) = @_;
    my %ledger = ( active => 'issues', archive => 'archive', roadmap => 'roadmap' );
    if ( !exists $ledger{$which} ) {
        return ();
    }
    my @scan;
    if ( defined $file ) {
        @scan = ($file);
    } elsif ( $which eq 'archive' ) {
        @scan = ledger_archive_files();
    } else {
        my $path = ledger_path( $ledger{$which} );
        @scan = defined $path && -f $path ? ($path) : ();
    }
    my @texts;
    foreach my $path (@scan) {
        foreach my $line ( @{ file_lines($path) // [] } ) {
            if ( $which eq 'roadmap' ) {
                if ( $line =~ s/^\s*(?:[0-9]+\.|-\s*\[[ xX]?\]|\*)\s*// ) {
                    push @texts, $line;
                }
            } elsif ( $line =~ /^\s*\|/ ) {
                my @parts = split( /\|/, $line, -1 );
                push @texts, $parts[1] // '';
            }
        }
    }
    my @ids;
    foreach my $text (@texts) {
        $text =~ s/^[ \t]+//;
        if ( $text !~ /^(`?$REF_LOOSE)/ ) {
            next;
        }
        my $id       = $1 =~ s/`//gr;
        my $had_hash = $id =~ s/^#// ? 1 : 0;
        my $num      = $id =~ s/^ISSUE-//r;
        if ( $num =~ /^[0-9]+$/ ) {
            push @ids, 0 + $num;
        } elsif ($had_hash) {
            push @ids, $id;
        }
    }
    return @ids;
}

# Usage     : my $where = ledger_locate('46')
# Purpose   : Where an issue's row is: the active ledger, the archive (with overflow and release
#             files), staged offline, or under the id a former offline id now has.
# Returns   : 'active', 'archive', or undef.
sub ledger_locate
{
    my ($n) = @_;
    my $re = _row_regex($n);
    if ( defined _first_match( ledger_path('issues'), $re ) ) {
        return 'active';
    }
    foreach my $file ( ledger_archive_files() ) {
        if ( defined _first_match( $file, $re ) ) {
            return 'archive';
        }
    }
    if ( $ENV{AAPP_LEDGER_OFFLINE} ) {
        return;
    }
    my $offline = ledger_in_offline($n);
    if ( defined $offline ) {
        return $offline;
    }
    my $real = ledger_alias($n);
    if ( defined $real && $real ne $n ) {
        return ledger_locate($real);
    }
    return;
}

# Usage     : my $value = ledger_cell('46', 'branch', 'issues')
# Purpose   : One cell of #<n>'s row (link, status, branch or commit), in the issues or archive ledger.
# Returns   : The cell as written, or undef when there is no such row or column.
sub ledger_cell
{
    my ( $n, $column, $which ) = @_;
    my $name = $COLUMN{$column};
    if ( !defined $name ) {
        return;
    }
    my $file = ledger_path( $which // 'issues' );
    if ( !defined $file || !-f $file ) {
        return;
    }
    my $col = ledger_column( $file, $name );
    if ( !defined $col ) {
        return;
    }
    my $row = _first_match( $file, qr/^\s*\|\s*`?#\Q$n\E`?\s*\|/ );
    if ( !defined $row ) {
        return;
    }
    my @c = split_row($row);
    return $c[$col];
}

# Usage     : my $branch = ledger_branch('46')
# Purpose   : The branch #<n>'s row names, active or archived.
# Returns   : The branch, or undef when none is named (the development branch is meant).
sub ledger_branch
{
    my ($n) = @_;
    my $branch = ledger_cell( $n, 'branch', 'issues' );
    if ( !defined $branch || $branch eq '' ) {
        $branch = ledger_cell( $n, 'branch', 'archive' );
    }
    if ( !defined $branch || $branch eq '' ) {
        return;
    }
    return $branch =~ s/`//gr;
}

# Usage     : my @map = ledger_branch_map()
# Purpose   : The active rows that name a branch.
# Returns   : List of [id, branch].
sub ledger_branch_map
{
    my $file = ledger_path('issues');
    if ( !defined $file || !-f $file ) {
        return ();
    }
    my $col = ledger_column( $file, 'Branch' );
    if ( !defined $col ) {
        return ();
    }
    my @map;
    foreach my $line ( @{ file_lines($file) // [] } ) {
        if ( $line !~ $ROW_RE ) {
            next;
        }
        my @c      = split_row($line);
        my $id     = $c[2] =~ s/[ \t`]//gr;
        my $branch = ( $c[$col] // '' ) =~ s/[ \t`]//gr;
        if ( $branch ne '' ) {
            push @map, [ $id, $branch ];
        }
    }
    return @map;
}

# Usage     : if ( ledger_record_external() ) { ... }
# Purpose   : Tells whether a tracker keeps the record: the ledgers are in place but ignored by Git.
# Returns   : 1 when ignored, 0 otherwise.
sub ledger_record_external
{
    my $file = ledger_path('issues');
    if ( !defined $file ) {
        return 0;
    }
    my $dir = $file =~ s{/ISSUES\.md$}{}r;
    my ($ignored) = AAPP::Paths::git_capture( '-C', $dir, 'check-ignore', '-q', 'ISSUES.md' );
    return $ignored ? 1 : 0;
}

# Usage     : my @paths = ledger_commit_paths('issues', 'archive')
# Purpose   : The named ledgers (all three by default) that exist and Git tracks, relative to the plans
#             worktree, for a plans commit; none while the offline ledgers are in use.
# Returns   : List of relative paths.
sub ledger_commit_paths
{
    my (@which) = @_;
    if ( $ENV{AAPP_LEDGER_OFFLINE} ) {
        return ();
    }
    if ( !@which ) {
        @which = qw(issues archive roadmap);
    }
    my @paths;
    foreach my $name (@which) {
        my $file = ledger_path($name);
        my $rel  = $LEDGER_REL{$name};
        if ( !defined $file || !-f $file ) {
            next;
        }
        my $dir = substr( $file, 0, length($file) - length($rel) - 1 );
        my ($ignored) = AAPP::Paths::git_capture( '-C', $dir, 'check-ignore', '-q', $rel );
        if ($ignored) {
            next;
        }
        push @paths, $rel;
        if ( $name eq 'archive' ) {
            my $done = $file =~ s{/[^/]*$}{}r;
            push @paths, map { 'done/' . ( $_ =~ s{.*/}{}r ) } grep { -f } sort glob("\Q$done\E/000-issues-archive-*.md");
        }
    }
    return @paths;
}

# ------------------------------------------------------------------------------
# The work queue: issues_road_map.md
# ------------------------------------------------------------------------------

# Usage     : my @lines = roadmap_entries($cap)
# Purpose   : The road map's open lines in file order (placeholder and resolved lines left out), at most $cap.
# Returns   : List of lines.
sub roadmap_entries
{
    my ($cap) = @_;
    my $file = ledger_path('roadmap');
    if ( !defined $file || !-f $file ) {
        return ();
    }
    my @open = grep { $_ =~ $ROADMAP_OPEN && index( $_, '[Feature or Problem Title]' ) < 0 && $_ !~ /✅|[Rr]esolved|DONE/ }
        @{ file_lines($file) // [] };
    if ( defined $cap && $cap ne '' && @open > $cap ) {
        @open = @open[ 0 .. $cap - 1 ];
    }
    return @open;
}

# Usage     : my $name = _roadmap_heading($line)
# Purpose   : The name of a road-map heading of the given level, emoji decorative.
# Returns   : The name, or undef when the line is not such a heading.
sub _roadmap_heading
{
    my ( $line, $want ) = @_;
    my ( $level, $name ) = AAPP::Text::heading_name($line);
    if ( !defined $level || $level != $want ) {
        return;
    }
    return $name;
}

# Usage     : my @entries = roadmap_queue_entries()
# Purpose   : Every queued line under 'Queued', with its level ('Urgent', 'Normal', 'Low'; normal by default).
# Returns   : List of [level, line].
sub roadmap_queue_entries
{
    my $file = ledger_path('roadmap');
    if ( !defined $file || !-f $file ) {
        return ();
    }
    my $queued = 0;
    my $level  = 'normal';
    my @entries;
    foreach my $line ( @{ file_lines($file) // [] } ) {
        my $h2 = _roadmap_heading( $line, 2 );
        if ( defined $h2 ) {
            $queued = $h2 =~ /^\Q$ROADMAP_QUEUED\E\b/ ? 1 : 0;
            $level  = 'normal';
            next;
        }
        if ( !$queued ) {
            next;
        }
        my $h3 = _roadmap_heading( $line, 3 );
        if ( defined $h3 ) {
            if ( $h3 =~ /^($LEVEL_RE)\b/ ) {
                $level = lc $1;
            }
            next;
        }
        if ( $line =~ /^\s*-\s*\[[ ]?\]/ ) {
            push @entries, [ $level, $line ];
        }
    }
    return @entries;
}

# Usage     : my $entry = _queue_entry_of('46')
# Purpose   : The queue entry whose first word after the checkbox is #<n>.
# Returns   : [level, line], or undef when #<n> is not queued.
sub _queue_entry_of
{
    my ($n) = @_;
    foreach my $entry ( roadmap_queue_entries() ) {
        my $text = $entry->[1] =~ s/$CHECKBOX//r;
        my ($word) = split( ' ', $text );
        if ( defined $word && $word eq "#$n" ) {
            return $entry;
        }
    }
    return;
}

# Usage     : my $level = roadmap_queue_level('46')
# Purpose   : The level #<n> is queued at.
# Returns   : 'urgent', 'normal' or 'low', or undef when it is not queued.
sub roadmap_queue_level
{
    my ($n) = @_;
    my $entry = _queue_entry_of($n);
    if ( !defined $entry ) {
        return;
    }
    return $entry->[0];
}

# Usage     : my $date = roadmap_queue_date('46')
# Purpose   : The date #<n> was queued, from its '(queued <date>)' mark.
# Returns   : The date, or undef when it is not queued or carries no date.
sub roadmap_queue_date
{
    my ($n) = @_;
    my $entry = _queue_entry_of($n);
    if ( !defined $entry || $entry->[1] !~ /\(queued ([0-9-]+)\)/ ) {
        return;
    }
    return $1;
}

# Usage     : my @ids = _roadmap_section_ids('Plan Blockers')
# Purpose   : The open issue ids of the road-map section with that name, in order.
# Returns   : List of id bodies.
sub _roadmap_section_ids
{
    my ($want) = @_;
    my $file = ledger_path('roadmap');
    if ( !defined $file || !-f $file ) {
        return ();
    }
    my $on = 0;
    my @ids;
    foreach my $line ( @{ file_lines($file) // [] } ) {
        my $h2 = _roadmap_heading( $line, 2 );
        if ( defined $h2 ) {
            $on = index( $h2, $want ) == 0 ? 1 : 0;
            next;
        }
        if ( $on && $line =~ /${CHECKBOX}#($ID_BODY)/ ) {
            push @ids, $1;
        }
    }
    return @ids;
}

# Usage     : my @ids = roadmap_blockers()
# Purpose   : The issues queued under 'Plan Blockers', in order.
# Returns   : List of id bodies.
sub roadmap_blockers
{
    return _roadmap_section_ids($ROADMAP_BLOCKERS);
}

# Usage     : my @ids = roadmap_queued()
# Purpose   : The issues under 'Queued', in order.
# Returns   : List of id bodies.
sub roadmap_queued
{
    my @ids;
    foreach my $entry ( roadmap_queue_entries() ) {
        if ( $entry->[1] =~ /${CHECKBOX}#($ID_BODY)/ ) {
            push @ids, $1;
        }
    }
    return @ids;
}

# Usage     : my @lines = roadmap_sections()
# Purpose   : The '## ' and '### ' headings of the work queue, as written.
# Returns   : List of lines.
sub roadmap_sections
{
    my $file = ledger_path('roadmap');
    if ( !defined $file || !-f $file ) {
        return ();
    }
    return grep { /^###? / } @{ file_lines($file) // [] };
}

# ------------------------------------------------------------------------------
# Offline ledgers (the .offline worktree)
# ------------------------------------------------------------------------------

# Usage     : if ( offline_mounted() ) { ... }
# Purpose   : Tells whether the .offline worktree is there.
# Returns   : 1 when mounted, 0 otherwise.
sub offline_mounted
{
    my $dir = AAPP::Paths::resolve()->{offline_dir};
    return defined $dir && -e "$dir/.git" ? 1 : 0;
}

# Usage     : my $path = offline_ledger_path('issues')
# Purpose   : A ledger's path in the .offline worktree.
# Returns   : The path, or undef when the worktree is not mounted.
sub offline_ledger_path
{
    my ($which) = @_;
    if ( !offline_mounted() || !defined $LEDGER_REL{$which} ) {
        return;
    }
    return AAPP::Paths::resolve()->{offline_dir} . "/$LEDGER_REL{$which}";
}

# Usage     : my $where = ledger_in_offline('46')
# Purpose   : Where an issue staged offline is.
# Returns   : 'active', 'archive', or undef.
sub ledger_in_offline
{
    my ($n) = @_;
    my $re = _row_regex($n);
    if ( defined _first_match( offline_ledger_path('issues'), $re ) ) {
        return 'active';
    }
    if ( defined _first_match( offline_ledger_path('archive'), $re ) ) {
        return 'archive';
    }
    return;
}

# Usage     : my $rc = ledger_use_offline()
# Purpose   : From here on, in this process and its children, the ledger functions use the offline ledgers.
# Returns   : RETURN_OK, or RETURN_ERROR outside a repository.
sub ledger_use_offline
{
    my $dir = AAPP::Paths::resolve()->{offline_dir};
    if ( !defined $dir ) {
        return RETURN_ERROR;
    }
    $ENV{AAPP_LEDGER_ISSUES}  = "$dir/ISSUES.md";
    $ENV{AAPP_LEDGER_ARCHIVE} = "$dir/done/000-issues-archive.md";
    $ENV{AAPP_LEDGER_ROADMAP} = "$dir/issues_road_map.md";
    $ENV{AAPP_LEDGER_OFFLINE} = 1;
    return RETURN_OK;
}

# Usage     : my @rows = ledger_offline_rows($status)
# Purpose   : The active rows staged offline, as ledger_rows gives rows, their source 'offline'.
# Returns   : List of array refs.
sub ledger_offline_rows
{
    my ($status) = @_;
    if ( $ENV{AAPP_LEDGER_OFFLINE} ) {
        return ();
    }
    my $file = offline_ledger_path('issues');
    if ( !defined $file || !-f $file ) {
        return ();
    }
    return ledger_rows( $status, $file, 'offline' );
}

# Usage     : my @ids = ledger_offline_ids('active')
# Purpose   : The ids staged offline (active or archive), bodies in file order.
# Returns   : List of id bodies.
sub ledger_offline_ids
{
    my ($which) = @_;
    my $ledger = $which eq 'archive' ? 'archive' : 'issues';
    my $file   = offline_ledger_path($ledger);
    if ( !defined $file || !-f $file ) {
        return ();
    }
    return ledger_ids( $which eq 'archive' ? 'archive' : 'active', $file );
}

# Usage     : my $real = ledger_alias('900001')
# Purpose   : The id an issue has now when <n> is the temporary id it was logged under offline: from
#             its archive row ('logged offline as #<n>'), else this machine's alias list.
# Returns   : The id body, or undef when <n> is no former offline id.
sub ledger_alias
{
    my ($n) = @_;
    my $hit = _first_match( ledger_path('archive'), qr/logged offline as #\Q$n\E(?:[^A-Za-z0-9-]|$)/ );
    if ( defined $hit ) {
        my @c  = split( /\|/, $hit, -1 );
        my $id = ( $c[1] // '' ) =~ s/[ \t`#]//gr;
        if ( $id ne '' ) {
            return $id;
        }
    }
    my $common = AAPP::Paths::resolve()->{common_dir};
    if ( !defined $common ) {
        return;
    }
    my $real;
    foreach my $line ( @{ file_lines("$common/aapp_issue_aliases") // [] } ) {
        my ( $from, $to ) = split( /\t/, $line );
        if ( defined $to && $from eq "#$n" ) {
            $real = $to;
        }
    }
    if ( !defined $real ) {
        return;
    }
    $real =~ s/^#//;
    if ( $real eq '' ) {
        return;
    }
    return $real;
}

# ------------------------------------------------------------------------------
# Issue text store (description and notes, outside Git) and per-machine state
# ------------------------------------------------------------------------------

# Usage     : my $path = state_file('aapp_issue_meta')
# Purpose   : A per-machine state file beside the repository's Git data, shared by every worktree.
# Returns   : The path, or undef outside a repository.
sub state_file
{
    my ($name) = @_;
    my $common = AAPP::Paths::resolve()->{common_dir};
    if ( !defined $common ) {
        return;
    }
    return "$common/$name";
}

# Usage     : my $path = issue_text_file()
# Purpose   : The project's issue text store: <state dir>/aapp/<key>/issues-data.md, the key from the
#             remote URL, or the checkout's folder name without a remote.
# Returns   : The path (it may not exist).
sub issue_text_file
{
    my $base = $ENV{AAPP_STATE_DIR} // $ENV{XDG_STATE_HOME} // ( ( $ENV{HOME} // '' ) . '/' . STATE_HOME_DEFAULT );
    my $name = AAPP::Config::get('aapp.remote') // DEFAULT_REMOTE;
    my ( $ok, $url ) = AAPP::Paths::git_capture( 'remote', 'get-url', $name );
    chomp($url);
    my $key;
    if ( $ok && $url ne '' ) {
        $key = $url;
        $key =~ s{^[a-z+]+://}{};
        $key =~ s{^[^/@]*@}{};
        $key =~ s{\.git$}{};
    } else {
        my $primary = AAPP::Paths::resolve()->{primary_root} // '';
        $key = $primary =~ s{.*/}{}r;
    }
    {
        use bytes;
        $key =~ s/[^A-Za-z0-9._-]/-/g;
    }
    $key =~ s/-+/-/g;
    $key =~ s/^-//;
    $key =~ s/-$//;
    if ( $key eq '' ) {
        $key = 'project';
    }
    return "$base/aapp/$key/issues-data.md";
}

# Usage     : my ($rc, $text) = issue_text_get('46')
# Purpose   : The description and notes of #<n>, in the order written, each under a '[...]' line naming it.
# Returns   : (RETURN_OK, $text) ('' when there is none), or (RETURN_ERROR, undef) when the store cannot be read.
sub issue_text_get
{
    my ($n) = @_;
    my $file = issue_text_file();
    if ( !-e $file ) {
        return ( RETURN_OK, '' );
    }
    my $lines = file_lines($file);
    if ( !defined $lines ) {
        return ( RETURN_ERROR, undef );
    }
    my $on   = 0;
    my $seen = 0;
    my $held = 0;
    my @out;
    foreach my $line ( @{$lines} ) {
        if ( $line =~ /^## #/ ) {
            $on = $line eq "## #$n" ? 1 : 0;
            next;
        }
        if ( !$on ) {
            next;
        }
        if ( $line =~ /^### (.*)$/ ) {
            if ($seen) {
                push @out, '';
            }
            push @out, "[$1]";
            $seen = 1;
            $held = 0;
            next;
        }
        if ( $line =~ /^\s*$/ ) {
            $held++;
            next;
        }
        while ( $held > 0 ) {
            push @out, '';
            $held--;
        }
        push @out, $line =~ /^ ###? / ? substr( $line, 1 ) : $line;
    }
    if ( !@out ) {
        return ( RETURN_OK, '' );
    }
    return ( RETURN_OK, join( "\n", @out ) . "\n" );
}

# Usage     : my %counts = issue_text_counts()
# Purpose   : How many entries (description and notes) the store holds per issue; no text is read out.
# Returns   : Hash of '#<n>' => count.
sub issue_text_counts
{
    my $file = issue_text_file();
    my %counts;
    my $id = '';
    foreach my $line ( @{ file_lines($file) // [] } ) {
        if ( $line =~ /^## (#.*)$/ ) {
            $id = $1;
            next;
        }
        if ( $line =~ /^### / && $id ne '' ) {
            $counts{$id}++;
        }
    }
    return %counts;
}

# Usage     : if ( issue_notes_counted() ) { ... }
# Purpose   : Tells whether the kit's store holds every description and note: no aapp-issue-tracker provider is installed.
# Returns   : 1 when counted here, 0 otherwise.
sub issue_notes_counted
{
    my $root = AAPP::Paths::resolve()->{root} // '.';
    return -d "$root/.agents/skills/aapp-issue-tracker" ? 0 : 1;
}

# ------------------------------------------------------------------------------
# Issue records: what status and issue list show
# ------------------------------------------------------------------------------

# Usage     : my @records = issue_records(@ids)
# Purpose   : One record per active issue (the active ledger in recorded order, then those staged
#             offline), or the ids given, in that order. Fields as AAPP::Output::ISSUE_FIELDS names them.
# Returns   : List of hash refs.
sub issue_records
{
    my (@wanted) = @_;
    my %queue;
    foreach my $entry ( roadmap_queue_entries() ) {
        my ( $level, $line ) = @{$entry};
        my $id   = $line =~ /(#[A-Za-z0-9-]+)/            ? $1 : '';
        my $date = $line =~ /\(queued ([0-9-]+)\)/        ? $1 : '';
        if ( $id ne '' && !exists $queue{$id} ) {
            $queue{$id} = [ $level, $date ];
        }
    }
    my %blocker  = map { ( "#$_" => 1 ) } roadmap_blockers();
    my %branch   = map { ( $_->[0] => $_->[1] ) } ledger_branch_map();
    my %meta     = _issue_meta();
    my $counted  = issue_notes_counted();
    my %counts   = $counted ? issue_text_counts() : ();

    my %records;
    my @order;
    foreach my $row ( ledger_rows(), ledger_offline_rows() ) {
        my ( $id, $sev, $type, $logged, $location, $symptom, $link, $status, $source ) = @{$row};
        if ( exists $records{$id} ) {
            next;
        }
        my $st = $status =~ s/`//gr;
        $st =~ s/^[^A-Za-z]*//;
        $st = lc $st;
        $st =~ s/ /-/g;
        my ( $plan, $blocks ) = ( '', '' );
        if ( $link =~ /\[(P-[0-9]+)\]/ ) {
            $plan = $1;
        }
        if ( $plan ne '' && $link =~ /^blocks / ) {
            ( $blocks, $plan ) = ( $plan, '' );
        }
        my ( $qsec, $qlv, $qd ) = ( '', '', '' );
        if ( $blocker{$id} ) {
            $qsec = 'blockers';
        } elsif ( exists $queue{$id} ) {
            ( $qsec, $qlv, $qd ) = ( 'queued', @{ $queue{$id} } );
        }
        my $m = $meta{$id} // [ '', '', '' ];
        $records{$id} = {
            id              => $id,
            severity        => lc( $sev =~ s/`//gr ),
            type            => $type =~ s/`//gr,
            status          => $st,
            logged          => $logged,
            location        => $location,
            symptom         => $symptom,
            plan            => $plan,
            blocks          => $blocks,
            queue_section   => $qsec,
            queue_level     => $qlv,
            queued          => $qd,
            branch          => $branch{$id} // '',
            offline         => $source eq 'offline' ? 1 : 0,
            tracker_name    => $m->[0],
            tracker_url     => $m->[1],
            tracker_release => $m->[2],
            notes           => $counted ? ( $counts{$id} // 0 ) : '',
        };
        push @order, $id;
    }
    if (@wanted) {
        my @ids = map { /^#/ ? $_ : "#$_" } @wanted;
        return map { $records{$_} } grep { exists $records{$_} } @ids;
    }
    return map { $records{$_} } @order;
}

# Usage     : my %meta = _issue_meta()
# Purpose   : The tracker names a provider gave (the per-machine aapp_issue_meta file: id, name, url, release; '-' empty).
# Returns   : Hash of '#<n>' => [name, url, release].
sub _issue_meta
{
    my $file = state_file('aapp_issue_meta');
    my %meta;
    if ( !defined $file ) {
        return %meta;
    }
    foreach my $line ( @{ file_lines($file) // [] } ) {
        my @f = split( /\t/, $line, -1 );
        if ( @f < 1 || $f[0] eq '' ) {
            next;
        }
        $meta{ $f[0] } = [ map { ( !defined $_ || $_ eq '-' ) ? '' : $_ } @f[ 1 .. 3 ] ];
    }
    return %meta;
}

# Usage     : my @sorted = records_by_branch(\@records, $current, $dev, $fill)
# Purpose   : Once any issue names a branch, the records whose branch (their own, or $dev) is $current
#             come first; with $fill, a record naming no branch shows $dev. Otherwise unchanged.
# Returns   : The records, as new hash refs.
sub records_by_branch
{
    my ( $records, $current, $dev, $fill ) = @_;
    my @copies = map { { %{$_} } } @{$records};
    if ( !ledger_branch_map() ) {
        return @copies;
    }
    my ( @first, @rest );
    foreach my $r (@copies) {
        my $b = $r->{branch} eq '' ? ( $dev // '' ) : $r->{branch};
        if ($fill) {
            $r->{branch} = $b;
        }
        if ( $b eq ( $current // '' ) ) {
            push @first, $r;
        } else {
            push @rest, $r;
        }
    }
    return ( @first, @rest );
}

# ------------------------------------------------------------------------------
# Plan and issue ID allocation (git config counters)
# ------------------------------------------------------------------------------

# Usage     : my ($rc, $next) = seed_issue_id($plans_dir)
# Purpose   : The next free issue number from the ledgers: the highest id in the active ledger and
#             the archive, plus one; template example rows (YYYY-MM-DD) are skipped.
# Returns   : (RETURN_OK, $next), or (RETURN_NOT_FOUND) when neither ledger exists.
sub seed_issue_id
{
    my ($plans) = @_;
    my $root = $plans =~ s{/?\.plans$}{}r;
    if ( $root eq '' ) {
        $root = '.';
    }
    my $max   = 0;
    my $found = 0;
    foreach my $which (qw(issues archive)) {
        my $file = ledger_path( $which, $root );
        foreach my $line ( ledger_table( $which, $root ) ) {
            if ( index( $line, 'YYYY-MM-DD' ) >= 0 ) {
                next;
            }
            if ( $line =~ /^\|  ?#([0-9]+)/ ) {
                $found = 1;
                if ( $1 > $max ) {
                    $max = $1;
                }
            }
        }
        if ( defined $file && -f $file ) {
            $found = 1;
        }
    }
    if ( !$found ) {
        return (RETURN_NOT_FOUND);
    }
    return ( RETURN_OK, $max + 1 );
}

# Usage     : my ($rc, $first) = _seed_issue_counter()
# Purpose   : The first id for an unset aapp.issueId: the ledgers this clone brought down.
# Returns   : (RETURN_OK, $first), or (RETURN_ERROR) after [ ERROR ] lines when there are no ledgers.
sub _seed_issue_counter
{
    my $root = AAPP::Paths::resolve()->{root};
    if ( !defined $root ) {
        AAPP::Logger::print_msg( 'ERROR', 'Issue ID: not inside a Git repository.' );
        return (RETURN_ERROR);
    }
    my ( $rc, $next ) = seed_issue_id("$root/.plans");
    if ( $rc != RETURN_OK ) {
        AAPP::Logger::print_msg( 'ERROR', 'Issue ID: no issue ledgers in .plans/ and no aapp-issue-tracker provider installed. Issue IDs come from the team provider: install it at .agents/skills/aapp-issue-tracker/run.' );
        return (RETURN_ERROR);
    }
    return ( RETURN_OK, $next );
}

# Usage     : my ($rc, $current) = _counter($key, $label, $seeder)
# Purpose   : A counter's current value: the setting, the seeder's answer when unset (1 without one).
# Returns   : (RETURN_OK, $n), or (RETURN_ERROR) after an [ ERROR ] line when the setting is not a whole number.
sub _counter
{
    my ( $key, $label, $seeder ) = @_;
    my $cur = AAPP::Config::get($key);
    if ( !defined $cur || $cur eq '' ) {
        if ( defined $seeder ) {
            return $seeder->();
        }
        return ( RETURN_OK, 1 );
    }
    if ( $cur !~ /^[0-9]+$/ ) {
        my $hint = defined $seeder ? "Run 'git config --unset $key' to reseed from the ledgers." : "Run 'aapp init' to reseed.";
        AAPP::Logger::print_msg( 'ERROR', "$label: $key is not an integer: '$cur'. $hint" );
        return (RETURN_ERROR);
    }
    return ( RETURN_OK, $cur );
}

# Usage     : my ($rc, $id) = _allocate_id($key, $prefix, $plugin, $label, $seeder, $event)
# Purpose   : Claims the next id from a counter and stores the increment. An installed provider
#             plugin takes precedence via the plugin protocol (action=allocate, event=$event).
# Returns   : (RETURN_OK, $id), or (RETURN_ERROR) after an [ ERROR ] line.
sub _allocate_id
{
    my ( $key, $prefix, $plugin, $label, $seeder, $event ) = @_;
    my $root = AAPP::Paths::resolve()->{root};
    if ( !defined $root ) {
        AAPP::Logger::print_msg( 'ERROR', "$label: not inside a Git repository." );
        return (RETURN_ERROR);
    }
    if ( defined $plugin && $plugin ne '' && -d "$root/.agents/skills/$plugin" ) {
        require AAPP::HookDispatcher;
        my $pdir  = "$root/.agents/skills/$plugin";
        my $entry = AAPP::HookDispatcher::resolve_plugin_entrypoint( $pdir, $plugin );
        if ( defined $entry && -f $entry ) {
            my $ev = $event // 'plan.allocate';
            my ( $rc, $stdout, $stderr ) = AAPP::HookDispatcher::run_action_plugin( $entry, $root, 'allocate', $ev, '{}' );
            require AAPP::JSON;
            if ( $rc != 0 ) {
                my ( $p_ok, $d ) = AAPP::JSON::decode( $stdout // '' );
                my $err_msg = ( $p_ok && ref($d) eq 'HASH' && defined $d->{error} && $d->{error} ne '' ) ? $d->{error} : 'no error text';
                AAPP::Logger::print_msg( 'ERROR', "$label: Provider plugin failed ($err_msg); refusing to allocate locally." );
                return (RETURN_ERROR);
            }
            my ( $j_ok, $res ) = AAPP::JSON::decode( $stdout // '' );
            if ( !$j_ok || ref($res) ne 'HASH' || !defined $res->{id} || $res->{id} eq '' ) {
                my $clean_out = ( $stdout // '' ) =~ s/\r?\n\z//r;
                AAPP::Logger::print_msg( 'ERROR', "$label: Provider must print {\"id\": ...} (got: '$clean_out')" );
                return (RETURN_ERROR);
            }
            my ( $norm_rc, $norm_id );
            if ( $prefix eq 'P-' ) {
                ( $norm_rc, $norm_id ) = normalize_plan_id( $res->{id} );
            } else {
                ( $norm_rc, $norm_id ) = ( RETURN_OK, "$prefix$res->{id}" );
            }
            if ( $norm_rc != RETURN_OK ) {
                return (RETURN_ERROR);
            }
            # Ratchet the local counter past the issued id so the fallback never regresses
            my $issued = $norm_id =~ s/^\Q$prefix\E//r;
            if ( $issued =~ /^[0-9]+$/ ) {
                my $cur = AAPP::Config::get($key);
                $cur = 0 if !defined $cur || $cur !~ /^[0-9]+$/;
                if ( $issued >= $cur ) {
                    AAPP::Config::set( $key, $issued + 1 );
                }
            }
            return ( RETURN_OK, $norm_id );
        }
    }
    my ( $rc, $cur ) = _counter( $key, $label, $seeder );
    if ( $rc != RETURN_OK ) {
        return (RETURN_ERROR);
    }
    if ( AAPP::Config::set( $key, $cur + 1 ) != RETURN_OK ) {
        return (RETURN_ERROR);
    }
    return ( RETURN_OK, "$prefix$cur" );
}

# Usage     : my ($rc, $id) = next_plan_id()
# Purpose   : The next plan ID, read only (aapp.planId, 1 when unset).
# Returns   : (RETURN_OK, 'P-<n>'), or (RETURN_ERROR) after an [ ERROR ] line.
sub next_plan_id
{
    my ( $rc, $n ) = _counter( 'aapp.planId', 'Plan ID', undef );
    if ( $rc != RETURN_OK ) {
        return (RETURN_ERROR);
    }
    return ( RETURN_OK, "P-$n" );
}

# Usage     : my ($rc, $id) = allocate_plan_id()
# Purpose   : Claims the next plan ID (aapp.planId).
# Returns   : (RETURN_OK, 'P-<n>'), or (RETURN_ERROR) after an [ ERROR ] line.
sub allocate_plan_id
{
    return _allocate_id( 'aapp.planId', 'P-', 'aapp-planid', 'Plan ID', undef, 'plan.allocate' );
}

# Usage     : my ($rc, $id) = next_issue_id()
# Purpose   : The next issue ID, read only (aapp.issueId, seeded from the ledgers when unset).
# Returns   : (RETURN_OK, '#<n>'), or (RETURN_ERROR) after an [ ERROR ] line.
sub next_issue_id
{
    my ( $rc, $n ) = _counter( 'aapp.issueId', 'Issue ID', \&_seed_issue_counter );
    if ( $rc != RETURN_OK ) {
        return (RETURN_ERROR);
    }
    return ( RETURN_OK, "#$n" );
}

# Usage     : my ($rc, $id) = allocate_issue_id()
# Purpose   : Claims the next issue ID from the kit's counter (a tracker numbers its own issues elsewhere).
# Returns   : (RETURN_OK, '#<n>'), or (RETURN_ERROR) after an [ ERROR ] line.
sub allocate_issue_id
{
    return _allocate_id( 'aapp.issueId', '#', undef, 'Issue ID', \&_seed_issue_counter );
}

# Usage     : my ($rc, $id) = normalize_plan_id('P-42')
# Purpose   : A provider's plan id as 'P-<n>'; anything but an integer is refused.
# Returns   : (RETURN_OK, 'P-<n>'), or (RETURN_FAIL) after an [ ERROR ] line.
sub normalize_plan_id
{
    my ($raw) = @_;
    my $n = ( $raw // '' ) =~ s/^P-//r;
    if ( $n !~ /^[0-9]+$/ ) {
        AAPP::Logger::print_msg( 'ERROR', "Plan ID: the provider must return an integer id (got: '" . ( $raw // '' ) . "')." );
        return (RETURN_FAIL);
    }
    return ( RETURN_OK, "P-$n" );
}

# ------------------------------------------------------------------------------
# Plan resolver: P-9, 9, a file name or a slug to one plan file
# ------------------------------------------------------------------------------

# Usage     : my @files = _scope_files(@dirs)
# Purpose   : The plan files under the search directories (recursive), registers and mini plans left out.
# Returns   : List of paths.
sub _scope_files
{
    my (@dirs) = @_;
    my @found;
    foreach my $dir ( grep { -d } @dirs ) {
        File::Find::find(
            {
                no_chdir => 1,
                wanted   => sub {
                    my $name = $_ =~ s{.*/}{}r;
                    if ( -f $_ && $name =~ /\.md$/ && $name !~ /^000-/ && $name !~ /^fix-/ ) {
                        push @found, $_;
                    }
                },
            },
            $dir
        );
    }
    my @sorted = sort @found;
    return @sorted;
}

# Usage     : my $re = _name_glob($pattern)
# Purpose   : A file-name glob (* ? [..]) as an anchored regex, as find -name reads it.
# Returns   : A compiled regex.
sub _name_glob
{
    my ($glob) = @_;
    my $re = join( '', map { $_ eq '*' ? '.*' : $_ eq '?' ? '.' : $_ =~ /^\[/ ? $_ : quotemeta($_) } $glob =~ /(\[[^\]]*\]|\*|\?|.)/gs );
    return qr/^$re$/s;
}

# Usage     : my ($rc, $path) = resolve_plan_path($query, $verb, $scope, $root)
# Purpose   : Resolves a plan reference: a path, a file name, P-9 / p9 / 9, or a slug substring, in
#             current/, done/ (with release bundles) or all. An empty query picks the only plan for
#             read-only verbs; '#9' is refused as an issue.
# Returns   : (RETURN_OK, path relative to the checkout); (RETURN_NOT_FOUND) or (RETURN_FAIL) after an [ ERROR ] line.
sub resolve_plan_path
{
    my ( $query, $verb, $scope, $root ) = @_;
    $query //= '';
    $verb  //= 'inspect';
    $scope //= 'current';
    $root  //= AAPP::Paths::resolve()->{root};
    if ( !defined $root ) {
        AAPP::Logger::print_msg( 'ERROR', 'Plan resolver: not inside a Git repository.' );
        return (RETURN_FAIL);
    }
    my $plans = "$root/.plans";
    if ( !-d $plans ) {
        AAPP::Logger::print_msg( 'ERROR', "Plan resolver: .plans/ directory not found in '$root'." );
        return (RETURN_FAIL);
    }
    my @releases = grep { -d } sort glob("\Q$plans\E/release/*/plans");
    my %dirs     = (
        current => ["$plans/current"],
        done    => [ "$plans/done", @releases ],
        all     => [ "$plans/current", "$plans/done", @releases ],
    );
    if ( !exists $dirs{$scope} ) {
        AAPP::Logger::print_msg( 'ERROR', "Plan resolver: invalid search scope '$scope' (must be current, done, or all)." );
        return (RETURN_FAIL);
    }
    my @search = grep { -d } @{ $dirs{$scope} };
    my $rel    = sub { my ($p) = @_; return index( $p, "$root/" ) == 0 ? substr( $p, length($root) + 1 ) : $p };
    my $avail  = sub {
        my %seen;
        my @names = grep { !$seen{$_}++ } sort map { $_ =~ s{.*/}{}r } _scope_files(@search);
        return @names ? join( ', ', @names ) : '(none)';
    };

    if ( $query ne '' && -f $query ) {
        return ( RETURN_OK, $rel->($query) );
    }
    if ( $query ne '' ) {
        my $glob = _name_glob($query);
        foreach my $dir (@search) {
            if ( -f "$dir/$query" ) {
                return ( RETURN_OK, $rel->("$dir/$query") );
            }
            my ($found) = grep { ( $_ =~ s{.*/}{}r ) =~ $glob } _scope_files($dir);
            if ( defined $found ) {
                return ( RETURN_OK, $rel->($found) );
            }
        }
    }

    if ( $query eq '' ) {
        if ( $verb eq 'freeze' || $verb eq 'done' ) {
            AAPP::Logger::print_msg( 'ERROR', "Plan resolver: name the plan for '$verb'. Plans in $scope/: " . $avail->() );
            return (RETURN_FAIL);
        }
        my @files = _scope_files(@search);
        if ( @files == 1 ) {
            return ( RETURN_OK, $rel->( $files[0] ) );
        }
        if ( !@files ) {
            AAPP::Logger::print_msg( 'ERROR', "Plan resolver: no blueprints found in $scope/." );
            return (RETURN_NOT_FOUND);
        }
        AAPP::Logger::print_msg( 'ERROR', "Plan resolver: several blueprints in $scope/; name one: " . $avail->() );
        return (RETURN_FAIL);
    }

    if ( $query =~ /^#/ ) {
        my $body = _id_body($query);
        if ( defined $body && "#$body" eq $query ) {
            my $hint = issue_id_is_numeric($query) ? ' Did you mean ' . ( 'P-' . substr( $query, 1 ) ) . '?' : '';
            AAPP::Logger::print_msg( 'ERROR', "Plan resolver: '$query' is an issue reference, not a plan.$hint" );
            return (RETURN_FAIL);
        }
    }

    my $num;
    if ( $query =~ /^[pP]-?([0-9]+)$/ ) {
        $num = 0 + $1;
    } elsif ( $query =~ /^[0-9]+$/ ) {
        $num = 0 + $query;
    }
    my @matches;
    if ( defined $num ) {
        foreach my $file ( _scope_files(@search) ) {
            my $name = $file =~ s{.*/}{}r;
            if ( $name =~ /^[pP]0*\Q$num\E-/ ) {
                push @matches, $file;
                next;
            }
            if ( grep { /^\s*[*|-]\s*\*\*Plan ID:\*\*\s*`?P-0*\Q$num\E(?![0-9])`?/ } @{ _plan_lines($file) } ) {
                push @matches, $file;
            }
        }
    }
    if ( !@matches ) {
        my $lower = lc $query;
        @matches = grep { index( lc( $_ =~ s{.*/}{}r ), $lower ) >= 0 } _scope_files(@search);
    }
    if ( !@matches ) {
        AAPP::Logger::print_msg( 'ERROR', "Plan resolver: plan '$query' not found. Plans in $scope/: " . $avail->() );
        return (RETURN_NOT_FOUND);
    }
    if ( @matches > 1 ) {
        AAPP::Logger::print_msg( 'ERROR', "Plan resolver: '$query' is ambiguous: " . join( ', ', map { $rel->($_) } @matches ) );
        return (RETURN_FAIL);
    }
    return ( RETURN_OK, $rel->( $matches[0] ) );
}

1;
