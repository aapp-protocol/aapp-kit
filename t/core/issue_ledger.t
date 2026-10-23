package AAPP::T::Core::IssueLedger;

use strict;
use warnings;
use utf8;
use 5.026;

use Cwd ();
use File::Path ();
use POSIX ();
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/issue_ledger.md. Run alone: prove -l t/core/issue_ledger.t

our $ISSUES  = '.plans/ISSUES.md';
our $ARCHIVE = '.plans/done/000-issues-archive.md';
our $ROADMAP = '.plans/issues_road_map.md';

# The symptom of #12, its pipes escaped as the ledger writes them.
our $SYMPTOM12 = 'Lists `🟠\|🔵` rows only; skips `NEW\|OLD`.';

# The fields of an issue record, in the order the contract names them.
our @FIELDS = qw(id severity type status logged location symptom plan blocks queue_section
    queue_level queued branch offline tracker_name tracker_url tracker_release notes);

# Usage     : fixture($self)
# Purpose   : A repository whose .plans/ holds the three ledgers: #12, #11 (planned), #10 (blocks P-8)
#             active, #9 archived, and a road map with a blocker, two queued lines and a ticked one.
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    $self->init_repo();
    File::Path::make_path('.plans/done');
    AAPP::Tests::write_text( $ISSUES, <<"EOF" );
# 🐛 Issues: Active Technical Backlog

| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #12 | `Low` | `CLI` | 2026-10-01 | `lib/a.sh` | $SYMPTOM12 |  | 🟡 `Incubated` |
| #11 | `High` | `CORE` | 2026-09-30 | `lib/b.sh` | Second problem. | [P-7](current/P7-fix-it.md) | 🔵 `Planned` |
| #10 | `Medium` | `DOCS` | 2026-09-29 | `MANUAL.md` | Third problem. | blocks [P-8](current/P8-other.md) | 🟡 `Incubated` |
EOF
    AAPP::Tests::write_text( $ARCHIVE, <<'EOF' );
# Issues Archive

| # | Sev | Type | Date Opened | Date Resolved | Target Commit | Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #9 | `Low` | `CLI` | 2026-09-01 | 2026-09-02 | `abc1234` | Fixed. |
EOF
    AAPP::Tests::write_text( $ROADMAP, <<'EOF' );
# Issues Road Map

## 🧱 Plan Blockers
- [ ] #10 -> Third problem. (blocks P-8)

## 📋 Queued
- [ ] #11 -> Second problem. See [P-7](current/P7-fix-it.md).
- [x] #8 -> Old one. ✅ Resolved
- [ ] #12 -> First problem.
EOF
    return 1;
}

# Usage     : my $r = state_call($self, $function, @args) / bash_call(...)
# Purpose   : A reader of AAPP::State, or a writer of lib/aapp-lib.sh, in the test's repository.
# Returns   : { exit, out, err, ret }.
sub state_call { my ( $self, @call ) = @_; return $self->lib_call( 'state',    @call ); }
sub bash_call  { my ( $self, @call ) = @_; return $self->lib_call( 'aapp_lib', @call ); }

# Usage     : my @rows = rows_of($path, '#12')
# Purpose   : The table rows of a ledger file whose first cell is the id, as written.
# Returns   : List of lines.
sub rows_of
{
    my ( $path, $id ) = @_;
    return grep { /^\|\s*\Q$id\E\s*\|/ } split( /\n/, AAPP::Tests::read_text($path) );
}

# Usage     : my $row = archive_top()
# Purpose   : The first row under the archive table's separator line.
# Returns   : The line, or '' when there is none.
sub archive_top
{
    my @lines = split( /\n/, AAPP::Tests::read_text($ARCHIVE) );
    foreach my $i ( 0 .. $#lines - 1 ) {
        return $lines[ $i + 1 ] if $lines[$i] =~ /^\|\s*:---/;
    }
    return '';
}

# Usage     : my $text = roadmap_text()
# Purpose   : The road map as it is now.
# Returns   : The text.
sub roadmap_text { return AAPP::Tests::read_text($ROADMAP); }

# Usage     : my $day = today()
# Purpose   : Today's date as the ledgers write it.
# Returns   : 'YYYY-MM-DD'.
sub today { return POSIX::strftime( '%Y-%m-%d', localtime ); }

# Usage     : record_is($self, $record, { id => '#12', ... }, $label)
# Purpose   : Checks every field of an issue record against the wanted values ('' where none is given).
# Returns   : 1; dies on the first field that differs.
sub record_is
{
    my ( $self, $got, $want, $label ) = @_;
    $self->true_or_die( defined $got, "$label has a record" );
    $self->eq_or_die( $got->{$_} // '<undef>', $want->{$_} // '', "$label field $_" ) for @FIELDS;
    return 1;
}

sub test_rows_keep_escaped_pipes
{
    my ($self) = @_;
    my ($row) = grep { $_->[0] eq '#12' } @{ state_call( $self, 'ledger_rows' )->{ret} };
    $self->true_or_die( defined $row, 'ledger_rows gives #12' );
    $self->eq_or_die( scalar( @{$row} ), 9,               'nine cells' );
    $self->eq_or_die( $row->[5],         $SYMPTOM12,      'the escaped pipes are kept' );
    $self->eq_or_die( $row->[7],         '🟡 `Incubated`', 'the status cell' );
    $self->eq_or_die( $row->[8],         'local',         'the source' );
    my @planned = map { $_->[0] } @{ state_call( $self, 'ledger_rows', 'Planned' )->{ret} };
    $self->eq_or_die( "@planned", '#11', 'a status filter selects the planned row' );
    return 1;
}

sub test_locate_active_archive_unknown
{
    my ($self) = @_;
    my %want = ( 11 => 'active', 9 => 'archive', 99 => '', 1 => '' );
    foreach my $id ( sort keys %want ) {
        $self->eq_or_die( state_call( $self, 'ledger_locate', $id )->{ret}[0] // '', $want{$id}, "#$id is located" );
    }
    return 1;
}

sub test_locate_finds_release_bundles
{
    my ($self) = @_;
    File::Path::make_path('.plans/release/v1.0.0');
    AAPP::Tests::write_text( '.plans/release/v1.0.0/000-issues-archive.md', <<'EOF' );
| # | Sev | Type | Date Opened | Date Resolved | Target Commit | Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #42 | `Low` | `CLI` | 2026-09-01 | 2026-09-02 | `abc1234` | Bundled. |
EOF
    $self->eq_or_die( state_call( $self, 'ledger_locate', '42' )->{ret}[0] // '', 'archive', 'an id in a release bundle' );
    return 1;
}

sub test_set_cell_changes_lifecycle_only
{
    my ($self) = @_;
    my $others = join( "\n", grep { !/^\| #12 / } split( /\n/, AAPP::Tests::read_text($ISSUES) ) );
    $self->eq_or_die( bash_call( $self, 'ledger_set_cell', '12', 'link',   '[P-9](current/P9-new.md)' )->{exit}, 0, 'the link cell is set' );
    $self->eq_or_die( bash_call( $self, 'ledger_set_cell', '12', 'status', '🔵 `Planned`' )->{exit},            0, 'the status cell is set' );
    my ($row) = rows_of( $ISSUES, '#12' );
    $self->eq_or_die( $row, "| #12 | `Low` | `CLI` | 2026-10-01 | `lib/a.sh` | $SYMPTOM12 | [P-9](current/P9-new.md) | 🔵 `Planned` |",
        'only the lifecycle cells changed' );
    my $snap = AAPP::Tests::read_text($ISSUES);
    $self->true_or_die( bash_call( $self, 'ledger_set_cell', '12', 'symptom', 'changed' )->{exit} != 0, 'an observation cell is refused' );
    $self->true_or_die( bash_call( $self, 'ledger_set_cell', '99', 'status',  'x' )->{exit} != 0,       'an unknown id is refused' );
    $self->eq_or_die( AAPP::Tests::read_text($ISSUES), $snap, 'a refusal leaves the file unchanged' );
    $self->eq_or_die( join( "\n", grep { !/^\| #12 / } split( /\n/, $snap ) ), $others, 'the other lines are unchanged' );
    return 1;
}

sub test_archive_row_moves_and_prunes
{
    my ($self) = @_;
    $self->eq_or_die( bash_call( $self, 'ledger_archive_row', '12', 'def5678', 'Offers by `a|b` name' )->{exit}, 0, 'the row is archived' );
    $self->eq_or_die( archive_top(), '| #12 | `Low` | `CLI` | 2026-10-01 | ' . today() . ' | `def5678` | Offers by `a\|b` name |',
        'it is the archive\'s top row' );
    $self->true_or_die( !rows_of( $ISSUES, '#12' ),          'it left the active ledger' );
    $self->true_or_die( roadmap_text() !~ /#12 /,              'its road map line is pruned' );
    $self->true_or_die( roadmap_text() =~ /#11 /,              'the other road map lines stay' );
    $self->true_or_die( bash_call( $self, 'ledger_archive_row', '99', 'def5678', 'x' )->{exit} != 0, 'an unknown id is refused' );
    return 1;
}

sub test_archive_row_aborted
{
    my ($self) = @_;
    $self->eq_or_die( bash_call( $self, 'ledger_archive_row', '10', 'aborted', 'Aborted: not a bug' )->{exit}, 0, 'the row is archived' );
    $self->eq_or_die( archive_top(), '| #10 | `Medium` | `DOCS` | 2026-09-29 | ' . today() . ' | `aborted` | Aborted: not a bug |',
        'aborted is its commit' );
    $self->true_or_die( roadmap_text() !~ /#10 /, 'its road map line is pruned' );
    return 1;
}

sub test_archive_commit_corrected
{
    my ($self) = @_;
    bash_call( $self, 'ledger_archive_row', '12', 'def5678', 'Offers by `a|b` name' );
    bash_call( $self, 'ledger_archive_row', '10', 'aborted', 'Aborted: not a bug' );
    $self->eq_or_die( bash_call( $self, 'ledger_set_archive_commit', '12', 'abc1234' )->{exit}, 0, 'the commit is corrected' );
    $self->eq_or_die( bash_call( $self, 'ledger_set_archive_commit', '99', 'abc1234' )->{exit}, 3, 'an unknown id exits 3' );
    my ($row) = rows_of( $ARCHIVE, '#12' );
    $self->eq_or_die( $row, '| #12 | `Low` | `CLI` | 2026-10-01 | ' . today() . ' | `abc1234` | Offers by `a\|b` name |', 'the row names the new commit' );
    my ($other) = rows_of( $ARCHIVE, '#10' );
    $self->true_or_die( index( $other, '| `aborted` |' ) >= 0, 'the other row keeps its commit' );
    return 1;
}

sub test_archive_overflow_bound
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.issueArchiveMax', '2' );
    $self->eq_or_die( bash_call( $self, 'ledger_archive_row', '12', 'def5678', 'Archive 12' )->{exit}, 0, '#12 is archived' );
    $self->eq_or_die( bash_call( $self, 'ledger_archive_row', '11', 'def5678', 'Archive 11' )->{exit}, 0, '#11 is archived' );
    my @rows = grep { /^\s*\|\s*`?#[0-9]+/ } split( /\n/, AAPP::Tests::read_text($ARCHIVE) );
    $self->eq_or_die( scalar(@rows), 2, 'the live archive holds two rows' );
    my $overflow = '.plans/done/000-issues-archive-overflow.md';
    $self->file_exists_or_die($overflow);
    $self->true_or_die( rows_of( $overflow, '#9' ) > 0, 'the oldest row moved to the overflow archive' );
    $self->eq_or_die( state_call( $self, 'ledger_locate', $_ )->{ret}[0] // '', 'archive', "#$_ is located as archived" ) for qw(9 11);
    my %ids = map { ( $_ => 1 ) } @{ state_call( $self, 'ledger_ids', 'archive' )->{ret} };
    $self->true_or_die( $ids{$_}, "#$_ is listed as archived" ) for qw(9 11 12);
    return 1;
}

sub test_relink_ledger_and_roadmap
{
    my ($self) = @_;
    my $r = bash_call( $self, 'ledger_relink', 'current/P7-fix-it.md', 'done/P7-fix-it.md' );
    $self->eq_or_die( $r->{exit}, 0,   'relink succeeds' );
    $self->eq_or_die( $r->{out},  "2\n", 'it counts two lines' );
    my $issues = AAPP::Tests::read_text($ISSUES);
    $self->true_or_die( index( $issues, '| [P-7](done/P7-fix-it.md) |' ) >= 0,    'the ledger link is rewritten' );
    $self->true_or_die( index( roadmap_text(), 'See [P-7](done/P7-fix-it.md).' ) >= 0, 'the road map link is rewritten' );
    $self->true_or_die( index( $issues, 'blocks [P-8](current/P8-other.md)' ) >= 0, 'another link is left alone' );
    return 1;
}

sub test_path_resolves_in_each_place
{
    my ($self) = @_;
    my $base = Cwd::getcwd() . '/places';
    my ( $main, $wt, $rootonly ) = map { "$base/$_" } qw(main planswt rootonly);
    File::Path::make_path( "$main/.plans/done", "$main/sub", "$wt/done", $rootonly );
    $self->ok_cmd( 'git', 'init', '-q', $_ ) for $main, $wt, $rootonly;
    AAPP::Tests::write_text( $_, '' ) for "$main/.plans/ISSUES.md", "$main/.plans/done/000-issues-archive.md", "$main/.plans/issues_road_map.md",
        "$wt/ISSUES.md", "$wt/done/000-issues-archive.md", "$rootonly/ISSUES.md";
    my $path = sub { my ( $dir, @args ) = @_; return $self->in_dir( $dir, sub { state_call( $self, 'ledger_path', @args )->{ret}[0] // '' } ); };
    $self->eq_or_die( $path->( "$main/sub", 'issues' ),  "$main/.plans/ISSUES.md",                  'in .plans/, from a subdirectory' );
    $self->eq_or_die( $path->( $main,       'archive' ), "$main/.plans/done/000-issues-archive.md", 'the archive in .plans/' );
    $self->eq_or_die( $path->( $main,       'roadmap' ), "$main/.plans/issues_road_map.md",         'the road map in .plans/' );
    $self->eq_or_die( $path->( $wt,         'issues' ),  "$wt/ISSUES.md",                           'in a plans worktree' );
    $self->eq_or_die( $path->( $wt,         'archive' ), "$wt/done/000-issues-archive.md",          'the archive in a plans worktree' );
    $self->eq_or_die( $path->( $rootonly,   'issues' ),  "$rootonly/ISSUES.md",                     'at the repository root' );
    my $missing = $path->( $rootonly, 'roadmap' );
    $self->true_or_die( $missing ne '' && !-e $missing, 'a missing road map still gets its path', $missing );
    $self->eq_or_die( $path->( $rootonly, 'issues', $main ), "$main/.plans/ISSUES.md", 'under a root the caller names' );
    {
        local $ENV{AAPP_LEDGER_ISSUES} = "$wt/ISSUES.md";
        $self->eq_or_die( $path->( $main, 'issues' ), "$wt/ISSUES.md", 'a file the caller names' );
    }
    return 1;
}

sub test_roadmap_entries_and_blockers
{
    my ($self) = @_;
    my @open = map { /(#[0-9]+)/ ? $1 : () } @{ state_call( $self, 'roadmap_entries' )->{ret} };
    $self->eq_or_die( "@open", '#10 #11 #12', 'the open lines in file order' );
    $self->eq_or_die( scalar( @{ state_call( $self, 'roadmap_entries', 1 )->{ret} } ), 1, 'capped on request' );
    $self->eq_or_die( "@{ state_call( $self, 'roadmap_blockers' )->{ret} }", '10', 'the plan blockers' );
    return 1;
}

sub test_roadmap_prune
{
    my ($self) = @_;
    $self->eq_or_die( bash_call( $self, 'roadmap_prune', '11' )->{exit}, 0, 'one line is pruned' );
    $self->true_or_die( roadmap_text() !~ /#11 /, '#11 is gone' );
    $self->eq_or_die( bash_call( $self, 'roadmap_prune', 'resolved' )->{exit}, 0, 'the ticked lines are pruned' );
    my $text = roadmap_text();
    $self->true_or_die( $text !~ /#8 /,                     'the ticked #8 is gone' );
    $self->true_or_die( $text =~ /#12 / && $text =~ /#10 /, 'the open lines stay' );
    return 1;
}

# Usage     : my @records = issue_fixture($self)
# Purpose   : #12 names a branch, #11 a tracker's entry, #13 is staged offline (a mounted .offline), and #12 has a description
#             and a note in the store; then the records as issue_records gives them.
# Returns   : List of hash refs (the store's directory stays set in AAPP_STATE_DIR by the caller).
sub issue_fixture
{
    my ($self) = @_;
    my $text = AAPP::Tests::read_text($ISSUES);
    $text =~ s/^(\| # \|.*\|)$/$1 Branch |/m;
    $text =~ s/^(\| :--- \|.*\|)$/$1 :--- |/m;
    $text =~ s/^(\| #12 .*\|)$/$1 fix\/x |/m;
    $text =~ s/^(\| #1[01] .*\|)$/$1  |/mg;
    AAPP::Tests::write_text( $ISSUES, $text );
    AAPP::Tests::write_text( '.git/aapp_issue_meta', "#11\tjira\thttps://t.example/11\t2.1\n" );
    $self->ok_cmd( 'git', 'init', '-q', '.offline' );
    AAPP::Tests::write_text( '.offline/ISSUES.md', <<'EOF' );
| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #13 | `Low` | `CLI` | 2026-10-04 | `lib/c.sh` | Staged offline. |  | 🟡 `Incubated` |
EOF
    $self->eq_or_die( bash_call( $self, 'issue_text_add', '12', 'description', 'secret description of twelve', 'tester' )->{exit}, 0, 'a description' );
    $self->eq_or_die( bash_call( $self, 'issue_text_add', '12', 'note',        'secret note of twelve',        'tester' )->{exit}, 0, 'a note' );
    return @{ state_call( $self, 'issue_records' )->{ret} };
}

sub test_issue_records_fields
{
    my ($self) = @_;
    local $ENV{AAPP_STATE_DIR} = Cwd::getcwd() . '/state';
    my %by = map { ( $_->{id} => $_ ) } issue_fixture($self);
    record_is( $self, $by{'#12'},
        {   id => '#12', severity => 'low', type => 'CLI', status => 'incubated', logged => '2026-10-01', location => '`lib/a.sh`',
            symptom => $SYMPTOM12, queue_section => 'queued', queue_level => 'normal', branch => 'fix/x', offline => 0, notes => 2 },
        '#12' );
    record_is( $self, $by{'#11'},
        {   id => '#11', severity => 'high', type => 'CORE', status => 'planned', logged => '2026-09-30', location => '`lib/b.sh`',
            symptom => 'Second problem.', plan => 'P-7', queue_section => 'queued', queue_level => 'normal', offline => 0,
            tracker_name => 'jira', tracker_url => 'https://t.example/11', tracker_release => '2.1', notes => 0 },
        '#11' );
    record_is( $self, $by{'#10'},
        {   id => '#10', severity => 'medium', type => 'DOCS', status => 'incubated', logged => '2026-09-29', location => '`MANUAL.md`',
            symptom => 'Third problem.', blocks => 'P-8', queue_section => 'blockers', offline => 0, notes => 0 },
        '#10' );
    $self->eq_or_die( $by{'#13'}{offline} // '', 1, 'the issue staged offline is flagged' );
    File::Path::make_path('.agents/skills/aapp-issue-tracker');
    my ($provider) = @{ state_call( $self, 'issue_records', '12' )->{ret} };
    $self->eq_or_die( $provider->{notes} // '<undef>', '', 'with a tracker provider no count is given' );
    return 1;
}

sub test_note_count_holds_no_text
{
    my ($self) = @_;
    local $ENV{AAPP_STATE_DIR} = Cwd::getcwd() . '/state';
    my @records = issue_fixture($self);
    my @leaks = grep { /secret/i } map { values %{$_} } @records;
    $self->true_or_die( !@leaks, 'no record holds a description or note', join( ' | ', @leaks ) );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
