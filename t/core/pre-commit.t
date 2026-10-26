package AAPP::T::Core::PreCommit;

use strict;
use warnings;
use utf8;
use 5.026;

use Cwd ();
use File::Copy ();
use File::Path ();
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/pre-commit.md. Run alone: prove -l t/core/pre-commit.t

our $SECTION4 = '## 💥 4. Blast Radius & System Boundaries';

# A counter that makes every changelog bump and file touch a change.
my $STAMP = 0;

# Usage     : fixture($self)
# Purpose   : The repository every test starts in (see build_repo).
# Returns   : 1
sub fixture { my ($self) = @_; return build_repo($self); }

# Usage     : build_repo($self)
# Purpose   : In the current directory: a repository on main with src/a.py, src/secret.py and CHANGELOG.md
#             committed, and the kit's pre-commit hook with its two libraries in .git/hooks.
# Returns   : 1
sub build_repo
{
    my ($self) = @_;
    $self->init_repo();
    File::Path::make_path( 'src', '.plans/current' );
    AAPP::Tests::write_text( 'src/a.py',      "x=1\n" );
    AAPP::Tests::write_text( 'src/secret.py', "secret=1\n" );
    AAPP::Tests::write_text( 'CHANGELOG.md',  "# CL\n" );
    $self->ok_cmd( 'git', 'add', '-A' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'init' );
    $self->ok_cmd( 'git', 'branch', '-M', 'main' );
    File::Copy::copy( "$self->{kit}/templates/aapp-pre-commit", '.git/hooks/pre-commit' ) or die "cannot copy the hook: $!\n";
    chmod( 0755, '.git/hooks/pre-commit' ) or die "cannot chmod the hook: $!\n";
    return 1;
}

# Usage     : fresh($self, $name, sub { ... })
# Purpose   : Builds another such repository in ./<name> and runs the code there.
# Returns   : What the code returns.
sub fresh
{
    my ( $self, $name, $code ) = @_;
    my $dir = Cwd::getcwd() . "/$name";
    File::Path::make_path($dir);
    return $self->in_dir( $dir, sub { build_repo($self); $code->() } );
}

# Usage     : plan($name, $body)
# Purpose   : Writes a plan from a §4 body: its leading '* **Field:**' lines go above the §4 heading, as a header.
# Returns   : 1
sub plan
{
    my ( $name, $body ) = @_;
    my ( @header, @rest );
    foreach my $line ( split( /\n/, $body ) ) {
        if ( !@rest && $line =~ /^\* \*\*[^*]+:\*\*/ ) {
            push @header, $line;
        } else {
            push @rest, $line;
        }
    }
    File::Path::make_path('.plans/current');
    AAPP::Tests::write_text( ".plans/current/$name", join( "\n", @header, $SECTION4, @rest ) . "\n" );
    return 1;
}

# Usage     : plan_full($name, $text)
# Purpose   : Writes a plan as given.
# Returns   : 1
sub plan_full
{
    my ( $name, $text ) = @_;
    File::Path::make_path('.plans/current');
    AAPP::Tests::write_text( ".plans/current/$name", $text );
    return 1;
}

# Usage     : simple_plan($target, $oob)
# Purpose   : A plan without header: one target and, when given, one Out of Bounds file.
# Returns   : 1
sub simple_plan
{
    my ( $target, $oob ) = @_;
    my $out = defined $oob ? "- [ ] `$oob` -> excluded\n" : '';
    return plan( 'p.md', "### 📂 Target Files (Modifications & Additions)\n- [ ] `$target` -> target\n### 🛑 Out of Bounds (Do Not Touch)\n$out## end\n" );
}

# Usage     : dev_plan($name, $id, $target)
# Purpose   : A plan in development with one target.
# Returns   : 1
sub dev_plan
{
    my ( $name, $id, $target ) = @_;
    return plan( $name, "* **Plan ID:** $id\n* **Status:** ⚡ In Development\n### 📂 Target Files (Modifications & Additions)\n- [ ] `$target` -> target\n### 🛑 Out of Bounds (Do Not Touch)\n## end\n" );
}

# Usage     : append($file, $text)
# Purpose   : Appends text to a file, creating it and its folder.
# Returns   : 1
sub append
{
    my ( $file, $text ) = @_;
    my ($dir) = $file =~ m{^(.*)/};
    File::Path::make_path($dir) if defined $dir;
    AAPP::Tests::write_text( $file, AAPP::Tests::read_text($file) . $text );
    return 1;
}

# Usage     : bump()
# Purpose   : Adds a changelog line.
# Returns   : 1
sub bump { $STAMP++; return append( 'CHANGELOG.md', "- bump $$ $STAMP\n" ); }

# Usage     : my $r = commit_says($self, $label, 'PASS'|'BLOCK', $message, $pattern)
# Purpose   : Commits what is staged; the outcome must match, and the output hold the pattern when given.
# Returns   : The command's result, its streams together in 'all'.
sub commit_says
{
    my ( $self, $label, $want, $message, $pattern ) = @_;
    my $r = $self->run_cmd( 'git', 'commit', '-m', $message );
    $r->{all} = $r->{out} . $r->{err};
    my $got = $r->{exit} == 0 ? 'PASS' : 'BLOCK';
    $self->true_or_die( $got eq $want, "$label: want $want", "got $got\n$r->{all}" );
    $self->match_or_die( $r->{all}, qr/$pattern/i, "$label: the output" ) if defined $pattern && $pattern ne '';
    return $r;
}

# Usage     : clean($self)
# Purpose   : Drops what is staged and changed, and untracked files outside .plans.
# Returns   : 1
sub clean
{
    my ($self) = @_;
    $self->run_cmd( 'git', 'reset', '-q' );
    $self->run_cmd( 'git', 'checkout', '-q', '.' );
    $self->run_cmd( 'git', 'clean', '-qfd', '-e', '.plans' );
    return 1;
}

# Usage     : check($self, $label, 'PASS'|'BLOCK', @files)
# Purpose   : Commits changes to the files (created when missing) with a changelog line, then cleans up.
# Returns   : 1; dies when the outcome differs.
sub check
{
    my ( $self, $label, $want, @files ) = @_;
    bump();
    foreach my $file (@files) {
        $STAMP++;
        if ( -e $file ) {
            append( $file, "# touch $STAMP\n" );
        } else {
            append( $file, "x=1\n" );
        }
    }
    $self->run_cmd( 'git', 'add', 'CHANGELOG.md', @files );
    my $r   = $self->run_cmd( 'git', 'commit', '-m', 't' );
    my $got = $r->{exit} == 0 ? 'PASS' : 'BLOCK';
    clean($self);
    $self->true_or_die( $got eq $want, "$label: want $want", "got $got\n" . join( "\n", grep {/❌|Staged file/} split( /\n/, $r->{out} . $r->{err} ) ) );
    return 1;
}

sub test_spaced_target_path
{
    my ($self) = @_;
    simple_plan('src/my dir/c.py');
    append( 'src/my dir/c.py', "z=1\n" );
    check( $self, 'a spaced target path', 'PASS', 'src/my dir/c.py' );
    return 1;
}

sub test_target_line_parsing
{
    my ($self) = @_;
    plan( 'p.md', <<'EOF' );
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> Refactor to use `src/legacy/old.py` helper.
- [ ] NEW FILE -> `src/new_mod.py` -> Fresh helper.
- [ ] `NEW FILE` -> `src/backticked_new.py` -> Fresh component.
- [ ] `MODIFY` -> `src/modified_target.py` -> Modify component.
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
    append( 'src/legacy/old.py', "w=1\n" );
    check( $self, 'a path named only in prose', 'BLOCK', 'src/legacy/old.py' );
    check( $self, 'the target itself',          'PASS',  'src/a.py' );
    check( $self, 'NEW FILE resolves to the path',             'PASS', 'src/new_mod.py' );
    check( $self, 'a backticked NEW FILE resolves to the path', 'PASS', 'src/backticked_new.py' );
    check( $self, 'a backticked MODIFY resolves to the path',   'PASS', 'src/modified_target.py' );
    return 1;
}

sub test_concurrent_plans_and_shared_docs
{
    my ($self) = @_;
    plan( 'a.md', "### 📂 Target Files (Modifications & Additions)\n- [ ] `src/a.py` -> change a\n### 🛑 Out of Bounds (Do Not Touch)\n- [ ] `src/b.py` -> belongs to plan B\n## end\n" );
    plan( 'b.md', "### 📂 Target Files (Modifications & Additions)\n- [ ] `src/b.py` -> change b\n### 🛑 Out of Bounds (Do Not Touch)\n## end\n" );
    check( $self, 'CHEATSHEET.md is an anchor', 'PASS', 'CHEATSHEET.md' );
    check( $self, 'COOKBOOK.md is an anchor',   'PASS', 'COOKBOOK.md' );
    check( $self, 'docs/ is shared',            'PASS', 'docs/concepts/arch.md' );
    AAPP::Tests::write_text( '.git/aapp_active_plan', "b\n" );
    check( $self, "plan b's target despite plan a's Out of Bounds", 'PASS',  'src/b.py' );
    check( $self, 'a file in no plan',                            'BLOCK', 'src/c.py' );
    unlink('.git/aapp_active_plan') or die "cannot remove the buffer: $!\n";
    check( $self, 'two plans in development, no binding', 'BLOCK', 'src/b.py' );
    return 1;
}

sub test_own_out_of_bounds_wins
{
    my ($self) = @_;
    simple_plan( 'src/', 'src/secret.py' );
    check( $self, 'own Out of Bounds over a broad target', 'BLOCK', 'src/secret.py' );
    check( $self, 'another file under the target',        'PASS',  'src/ok.py' );
    return 1;
}

sub test_out_of_bounds_only_plan
{
    my ($self) = @_;
    plan( 'p.md', "### 📂 Target Files (Modifications & Additions)\n### 🛑 Out of Bounds (Do Not Touch)\n- [ ] `src/danger.py` -> strictly excluded\n## end\n" );
    check( $self, 'Out of Bounds without targets', 'BLOCK', 'src/danger.py' );
    check( $self, 'an unrelated file',             'PASS',  'src/unrelated.py' );
    return 1;
}

sub test_blocked_plan_refused
{
    my ($self) = @_;
    plan( 'blocked.md', <<'EOF' );
* **Status:** 🟥 BLOCKED
* **Blocked On:** BUG-042
### 📂 Target Files (Modifications & Additions)
- [ ] `src/blocked_target.py` -> would be allowed if not blocked
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
    check( $self, "a blocked plan's own target", 'BLOCK', 'src/blocked_target.py' );
    return 1;
}

sub test_hook_follows_adopter_statuses
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.planState.blocked',        '⛔|Halted|⛔ Halted|40' );
    $self->ok_cmd( 'git', 'config', 'aapp.planState.in-development', '🚧|Building|🚧 Building|30' );
    plan( 'halted.md', "* **Status:** ⛔ Halted\n### 📂 Target Files (Modifications & Additions)\n- [ ] `src/halted_target.py` -> halted\n### 🛑 Out of Bounds (Do Not Touch)\n## end\n" );
    check( $self, 'an adopter blocked status', 'BLOCK', 'src/halted_target.py' );
    unlink('.plans/current/halted.md') or die "cannot remove halted.md: $!\n";
    plan( 'building.md', "* **Plan ID:** P-40\n* **Status:** 🚧 Building\n### 📂 Target Files (Modifications & Additions)\n- [ ] `src/building_target.py` -> building\n### 🛑 Out of Bounds (Do Not Touch)\n## end\n" );
    check( $self, "an adopter in-development plan's target", 'PASS',  'src/building_target.py' );
    check( $self, 'an adopter in-development plan confines', 'BLOCK', 'src/elsewhere.py' );
    return 1;
}

sub test_syntax_check_spaced_path
{
    my ($self) = @_;
    simple_plan('src/my dir/bad.py');
    append( 'src/my dir/bad.py', "def bad(: pass\n" );
    check( $self, 'broken Python in a spaced path', 'BLOCK', 'src/my dir/bad.py' );
    return 1;
}

sub test_deleting_out_of_bounds_file_refused
{
    my ($self) = @_;
    simple_plan( 'src/a.py', 'src/secret.py' );
    $self->ok_cmd( 'git', 'rm', '-q', 'src/secret.py' );
    bump();
    $self->ok_cmd( 'git', 'add', 'CHANGELOG.md' );
    commit_says( $self, 'deleting an Out of Bounds file', 'BLOCK', 'delete secret' );
    return 1;
}

sub test_skip_blast_radius_escape
{
    my ($self) = @_;
    simple_plan('src/a.py');
    append( 'src/a.py', "hotfix=1\n" );
    $self->ok_cmd( 'git', 'add', 'src/a.py' );
    local $ENV{SKIP_BLAST_RADIUS} = 1;
    $self->ok_cmd( 'git', 'commit', '-qm', 'emergency hotfix' );
    return 1;
}

sub test_plans_changelog_satisfies_rule
{
    my ($self) = @_;
    unlink('CHANGELOG.md') or die "cannot remove CHANGELOG.md: $!\n";
    $self->ok_cmd( 'git', 'commit', '-qm', 'remove root changelog', '--allow-empty' );
    simple_plan('src/a.py');
    AAPP::Tests::write_text( '.plans/CHANGELOG.md', '' );
    AAPP::Tests::write_text( 'src/a.py',            "x=2\n" );
    $self->ok_cmd( 'git', 'add', 'src/a.py', '.plans/CHANGELOG.md' );
    commit_says( $self, 'a staged .plans/CHANGELOG.md', 'PASS', 'code with .plans changelog' );
    $self->ok_cmd( 'git', 'init', '-q', '.plans' );
    append( '.plans/CHANGELOG.md', "uncommitted changelog entry\n" );
    AAPP::Tests::write_text( 'src/a.py', "x=3\n" );
    $self->ok_cmd( 'git', 'add', 'src/a.py' );
    commit_says( $self, 'a changed .plans worktree changelog', 'PASS', 'code with .plans worktree changelog' );
    File::Path::remove_tree('.plans/.git');
    return 1;
}

sub test_hook_runs_without_exec_bit
{
    my ($self) = @_;
    simple_plan('src/a.py');
    File::Path::make_path('.githooks');
    File::Copy::copy( "$self->{kit}/templates/aapp-pre-commit", '.githooks/aapp-pre-commit' ) or die "cannot copy the hook: $!\n";
    chmod( 0644, '.githooks/aapp-pre-commit' ) or die "cannot chmod: $!\n";
    File::Copy::copy( "$self->{kit}/templates/pre-commit", '.git/hooks/pre-commit' ) or die "cannot copy the dispatcher: $!\n";
    chmod( 0755, '.git/hooks/pre-commit' ) or die "cannot chmod: $!\n";
    append( 'src/untracked.py', "bad=1\n" );
    bump();
    $self->ok_cmd( 'git', 'add', 'src/untracked.py', 'CHANGELOG.md' );
    commit_says( $self, 'a violation without the exec bit', 'BLOCK', 'commit untracked', 'Pre-Commit Blast Radius Violation' );
    return 1;
}

sub test_branch_protection
{
    my ($self) = @_;
    simple_plan('src/a.py');
    check( $self, 'a single-branch repository commits on main', 'PASS', 'src/a.py' );
    $self->ok_cmd( 'git', 'branch', 'develop' );
    AAPP::Tests::write_text( 'src/a.py', "x=11\n" );
    bump();
    $self->ok_cmd( 'git', 'add', 'src/a.py', 'CHANGELOG.md' );
    commit_says( $self, 'main with develop present', 'BLOCK', 'direct to main', q{Direct commits to 'main' are prohibited} );
    clean($self);
    $self->ok_cmd( 'git', 'checkout', '-q', 'develop' );
    check( $self, 'a commit on develop', 'PASS', 'src/a.py' );
    $self->ok_cmd( 'git', 'checkout', '-q', 'main' );
    AAPP::Tests::write_text( 'src/a.py', "x=13\n" );
    bump();
    $self->ok_cmd( 'git', 'add', 'src/a.py', 'CHANGELOG.md' );
    {
        local $ENV{ALLOW_MAIN_COMMIT} = 1;
        $self->ok_cmd( 'git', 'commit', '-qm', 'emergency commit on main' );
    }
    $self->ok_cmd( 'git', 'config', '--bool', 'aapp.protectStable', 'false' );
    AAPP::Tests::write_text( 'src/a.py', "x=14\n" );
    bump();
    $self->ok_cmd( 'git', 'add', 'src/a.py', 'CHANGELOG.md' );
    commit_says( $self, 'aapp.protectStable false', 'PASS', 'commit on main with protectStable=false' );
    fresh(
        $self, 'staging',
        sub {
            $self->ok_cmd( 'git', 'branch', 'staging' );
            $self->ok_cmd( 'git', 'config', 'aapp.devBranch', 'staging' );
            simple_plan('src/a.py');
            AAPP::Tests::write_text( 'src/a.py', "x=15\n" );
            bump();
            $self->ok_cmd( 'git', 'add', 'src/a.py', 'CHANGELOG.md' );
            commit_says( $self, 'aapp.devBranch protects main', 'BLOCK', 'direct to main with staging dev', 'staging' );
            clean($self);
            $self->ok_cmd( 'git', 'checkout', '-q', 'staging' );
            check( $self, 'a commit on the named development branch', 'PASS', 'src/a.py' );
        }
    );
    return 1;
}

sub test_roadmap_auto_prune
{
    my ($self) = @_;
    AAPP::Tests::write_text( '.plans/issues_road_map.md', <<'EOF' );
# 🗺️ Issue Work Queue
> **Role:** Resolved issues are auto-pruned.
## 📋 Queued
1. `ISSUE-001` -> Still open
2. `ISSUE-002` -> All done ✅ `Resolved`
- [ ] `ISSUE-003` -> Open edge case
3. #2 -> All done ✅ Resolved
- [ ] #3 -> Done Resolved
EOF
    simple_plan('src/a.py');
    AAPP::Tests::write_text( 'src/a.py', "x=20\n" );
    bump();
    $self->ok_cmd( 'git', 'add', 'src/a.py', 'CHANGELOG.md' );
    commit_says( $self, 'a commit with resolved road map lines', 'PASS', 'commit with resolved issue in roadmap' );
    my $text = AAPP::Tests::read_text('.plans/issues_road_map.md');
    $self->true_or_die( index( $text, $_ ) < 0,  "the resolved line [$_] is pruned", $text ) for 'ISSUE-002', '#2 ', '#3 ';
    $self->true_or_die( index( $text, $_ ) >= 0, "the line [$_] is kept",            $text ) for 'ISSUE-001', 'ISSUE-003', 'Resolved issues are auto-pruned';
    return 1;
}

sub test_resolved_issue_row_refused
{
    my ($self) = @_;
    AAPP::Tests::write_text( '.plans/ISSUES.md', <<'EOF' );
# 🐛 Issues: Active Technical Backlog
| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #1 | `Critical` | `SEC` | 2026-09-09 | `src/a.py:1` | Issue symptom. |  | ✅ `Resolved` |
EOF
    simple_plan('src/a.py');
    AAPP::Tests::write_text( 'src/a.py', "x=22\n" );
    bump();
    $self->ok_cmd( 'git', 'add', 'src/a.py', 'CHANGELOG.md' );
    commit_says( $self, 'a resolved row in the active ledger', 'BLOCK', 'commit with resolved issue in ISSUES.md', 'Found resolved issue in active' );
    return 1;
}

sub test_glob_targets
{
    my ($self) = @_;
    plan( 'glob.md', <<'EOF' );
### 📂 Target Files (Modifications & Additions)
- [ ] `src/*.py` -> single segment wildcard
- [ ] `pkg/**/*.go` -> recursive wildcard
- [ ] `scripts/?.sh` -> single character wildcard
- [ ] `migrations/[0-9]*.sql` -> bracket class range
- [ ] `docs/` -> recursive directory prefix
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/forbidden_*.py` -> single segment oob wildcard
## end
EOF
    check( $self, @{$_} )
        for [ '* in its directory', 'PASS', 'src/app.py' ], [ '* across directories', 'BLOCK', 'src/deep/nested/app.py' ],
        [ '** at its root', 'PASS', 'pkg/main.go' ], [ '** nested', 'PASS', 'pkg/sub/deep/worker.go' ],
        [ '? one character', 'PASS', 'scripts/a.sh' ], [ '? two characters', 'BLOCK', 'scripts/ab.sh' ],
        [ 'a bracket class digit', 'PASS', 'migrations/001_init.sql' ], [ 'a bracket class non-digit', 'BLOCK', 'migrations/test.sql' ],
        [ 'a directory prefix', 'PASS', 'docs/guide.md' ], [ 'a directory prefix, nested', 'PASS', 'docs/api/v1/spec.md' ],
        [ 'an Out of Bounds wildcard', 'BLOCK', 'src/forbidden_test.py' ];
    return 1;
}

# Usage     : my $base = lock_plan($self, $status)
# Purpose   : Commits plan P-1 with the status, a §2 blueprint, two tasks, §4 and an open question.
# Returns   : The commit's SHA.
sub lock_plan
{
    my ( $self, $status ) = @_;
    plan_full( 'p.md', <<"EOF" );
# 🗺️ Plan P-1: Test Plan
* **Plan ID:** P-1
* **Status:** $status

## 1. Context & Goal
Original context.

## 2. Technical Blueprint
Original technical blueprint architecture.

## 🔨 3. Implementation Steps & Checklist
- [ ] Task 1.1
- [ ] Task 1.2

## 💥 4. Blast Radius & System Boundaries
### 📂 Target Files
- [ ] `src/a.py`
### 🛑 Out of Bounds
- [ ] `src/secret.py`

## ❓ 5. Open Questions
* [ ] Question 1

## 📦 6. Change Log & Refinement History
* 2026-09-17: Initial entry.
EOF
    $self->ok_cmd( 'git', 'add', '.plans/current/p.md' );
    $self->ok_cmd( 'git', 'commit', '-qm', "add plan with status $status" );
    return $self->ok_cmd( 'git', 'rev-parse', 'HEAD' )->{out} =~ s/\s+\z//r;
}

# Usage     : plans_commit($self, $base, $label, 'PASS'|'BLOCK', [$file, $from, $to], ...)
# Purpose   : Edits plan files (each regex $from replaced by $to; $from undef appends $to), commits
#             them, checks the outcome, and resets to $base.
# Returns   : 1
sub plans_commit
{
    my ( $self, $base, $label, $want, @edits ) = @_;
    my %files;
    foreach my $edit (@edits) {
        my ( $file, $from, $to ) = @{$edit};
        my $path = ".plans/current/$file";
        my $text = AAPP::Tests::read_text($path);
        if ( defined $from ) {
            $text =~ s/$from/$to/ or die "$label: no match for $from in $file\n";
        } else {
            $text .= $to;
        }
        AAPP::Tests::write_text( $path, $text );
        $files{$path} = 1;
    }
    $self->ok_cmd( 'git', 'add', sort keys %files );
    my $r   = $self->run_cmd( 'git', 'commit', '-m', 'update plans' );
    my $got = $r->{exit} == 0 ? 'PASS' : 'BLOCK';
    $self->ok_cmd( 'git', 'reset', '-q', '--hard', $base );
    $self->true_or_die( $got eq $want, "$label: want $want", "got $got\n" . join( "\n", grep {/❌|Violation/} split( /\n/, $r->{out} . $r->{err} ) ) );
    return 1;
}

sub test_frozen_design_lock
{
    my ($self) = @_;
    my $base = lock_plan( $self, '🔷 Frozen' );
    plans_commit( $self, $base, 'a tick on a frozen plan',            'PASS', [ 'p.md', qr/- \[ \] Task 1\.1/, '- [x] Task 1.1' ] );
    plans_commit( $self, $base, 'a change log line on a frozen plan', 'PASS', [ 'p.md', undef, "* 2026-09-17: Verified phase 1.\n" ] );
    plans_commit( $self, $base, 'an answered question',               'PASS', [ 'p.md', qr/\* \[ \] Question 1/, '* [x] Question 1: answered' ] );
    plans_commit( $self, $base, 'a §2 edit on a frozen plan',         'BLOCK', [ 'p.md', qr/Original technical blueprint architecture\./, 'Tampered architecture.' ] );
    plans_commit( $self, $base, 'a §4 edit on a frozen plan',         'BLOCK', [ 'p.md', qr{src/a\.py}, 'src/extra.py' ] );
    plans_commit( $self, $base, 'an unfreeze with the design unchanged', 'PASS', [ 'p.md', qr/🔷 Frozen/, '📝 Refining' ] );
    plans_commit( $self, $base, 'a §2 edit smuggled into an unfreeze', 'BLOCK',
        [ 'p.md', qr/🔷 Frozen/, '📝 Refining' ], [ 'p.md', qr/Original technical blueprint architecture\./, 'Smuggled architecture.' ] );
    $base = lock_plan( $self, '🟣 Under Review' );
    plans_commit( $self, $base, 'a §2 edit on a draft plan', 'PASS', [ 'p.md', qr/Original technical blueprint architecture\./, 'Refined draft architecture.' ] );
    plans_commit( $self, $base, 'a §4 edit on a draft plan', 'PASS', [ 'p.md', qr{src/a\.py}, 'src/draft.py' ] );
    return 1;
}

sub test_group_and_amendments_lock
{
    my ($self) = @_;
    plan_full( 'g.md', <<'EOF' );
# 🧩 Group Plan P-2: Grp
* **Plan ID:** P-2
* **Status:** ⚡ In Development

## 1. Goal
Group goal.

## Architecture & Codemap
### ARCHITECTURE.md
<!-- aapp-base: new -->
````markdown
## Sec One
text one
````

## 💥 4. Blast Radius & System Boundaries
### 📂 Target Files
- [ ] `ARCHITECTURE.md`
### 🛑 Out of Bounds

## 📦 6. Change Log & Refinement History
* 2026-10-17: Initial entry.
EOF
    plan_full( 'a.md', <<'EOF' );
# 🗺️ Plan P-3: Grp Amendments
* **Plan ID:** P-3
* **Kind:** amendments
* **Group:** P-2
* **Status:** ⚡ In Development

## 2. Technical Blueprint
Amendments.

## 💥 4. Blast Radius & System Boundaries
### 📂 Target Files
- [ ] `src/x.py` -> approved R1
### 🛑 Out of Bounds

## 📦 6. Change Log & Refinement History
* 2026-10-17: Initial entry.

## Decisions
EOF
    $self->ok_cmd( 'git', 'add', '.plans/current/g.md', '.plans/current/a.md' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'group and amendments' );
    my $base    = $self->ok_cmd( 'git', 'rev-parse', 'HEAD' )->{out} =~ s/\s+\z//r;
    my $section = [ 'g.md', qr/^text one$/m, 'text two' ];
    plans_commit( $self, $base, 'a group section change alone', 'BLOCK', $section );
    plans_commit( $self, $base, 'a group section change with its decision', 'PASS', $section, [ 'a.md', undef, "- **D1** 2026-10-17 · § Sec One · R1 · reason\n" ] );
    plans_commit( $self, $base, 'a decision for another heading', 'BLOCK', $section, [ 'a.md', undef, "- **D1** 2026-10-17 · § Other Sec · R1 · reason\n" ] );
    plans_commit( $self, $base, 'group text outside the section', 'PASS', [ 'g.md', qr/^Group goal\.$/m, 'Group goal, reworded.' ] );
    plans_commit( $self, $base, 'an amendments target added', 'PASS', [ 'a.md', qr/^### 🛑 Out of Bounds$/m, "- [ ] `src/y.py` -> approved R2\n### 🛑 Out of Bounds" ] );
    plans_commit( $self, $base, 'an amendments target changed', 'BLOCK', [ 'a.md', qr{src/x\.py}, 'src/z.py' ] );
    plans_commit( $self, $base, 'the amendments blueprint changed', 'BLOCK', [ 'a.md', qr/^Amendments\.$/m, 'Amendments, reworded.' ] );
    plans_commit( $self, $base, 'a target added to another plan in development', 'BLOCK',
        [ 'g.md', qr/^### 🛑 Out of Bounds$/m, "- [ ] `ARCHITECTURE2.md`\n### 🛑 Out of Bounds" ] );
    return 1;
}

sub test_active_plan_buffer
{
    my ($self) = @_;
    AAPP::Tests::write_text( 'aapp', '' );
    File::Path::remove_tree('.plans/current');
    AAPP::Tests::write_text( 'src/a.py', "bad=1\n" );
    check( $self, 'a kit repository without .plans/current', 'BLOCK', 'src/a.py' );
    plan( 'p17.md', "* **Plan ID:** P-17\n* **Status:** 🔷 Frozen\n### 📂 Target Files (Modifications & Additions)\n- [ ] `src/p17.py` -> plan 17 target\n### 🛑 Out of Bounds (Do Not Touch)\n## end\n" );
    check( $self, 'a frozen plan restricts nothing', 'PASS', 'src/p17.py' );
    $self->run_cmd( 'aapp', 'start', '17' );
    check( $self, 'the started plan commits', 'PASS', 'src/p17.py' );
    $self->ok_cmd( 'aapp', 'active', 'clear' );
    check( $self, 'one plan in development is found without a binding', 'PASS', 'src/p17.py' );
    dev_plan( 'p18.md', 'P-18', 'src/p18.py' );
    check( $self, 'two plans in development, no binding', 'BLOCK', 'src/p18.py' );
    $self->ok_cmd( 'aapp', 'active', '18' );
    check( $self, 'bound to P-18: its target',     'PASS',  'src/p18.py' );
    check( $self, "bound to P-18: P-17's target", 'BLOCK', 'src/p17.py' );
    $self->ok_cmd( 'aapp', 'active', 'swap' );
    check( $self, 'swapped to P-17: its target',     'PASS',  'src/p17.py' );
    check( $self, "swapped to P-17: P-18's target", 'BLOCK', 'src/p18.py' );
    return 1;
}

sub test_portability_paths
{
    my ($self) = @_;
    plan( 'p_port.md',
        "* **Plan ID:** P-30\n* **Status:** ⚡ In Development\n### 📂 Target Files (Modifications & Additions)\n- [ ] `doc.md` -> doc target\n- [ ] `README.md` -> readme target\n### 🛑 Out of Bounds (Do Not Touch)\n## end\n" );
    $self->ok_cmd( 'aapp', 'active', '30' );
    foreach my $case (
        [ 'a file:/// URI',          'BLOCK', 'See [doc](file:///home/user/repo/doc.md)' ],
        [ 'a /home/ link',           'BLOCK', 'See [doc](/home/user/repo/doc.md)' ],
        [ 'relative links',          'PASS',  'See [doc](doc.md) and [other](../other.md)' ],
        [ 'file:// named in prose',  'PASS',  'Never use file:// URIs in repository files.' ] )
    {
        AAPP::Tests::write_text( 'doc.md', "$case->[2]\n" );
        bump();
        $self->ok_cmd( 'git', 'add', 'CHANGELOG.md', 'doc.md' );
        commit_says( $self, $case->[0], $case->[1], 't' );
        clean($self);
    }
    return 1;
}

sub test_pause_blocks_code_commits
{
    my ($self) = @_;
    dev_plan( 'p_pause.md', 'P-60', 'src/pause_code.py' );
    AAPP::Tests::write_text( 'src/pause_code.py', "def f(): pass\n" );
    bump();
    $self->ok_cmd( 'git', 'add', 'src/pause_code.py', 'CHANGELOG.md', '.plans' );
    commit_says( $self, 'before pause', 'PASS', 'feat: add pause target' );
    $self->ok_cmd( 'aapp', 'pause', 'focusing on another project' );
    append( 'src/pause_code.py', "def f2(): pass\n" );
    bump();
    $self->ok_cmd( 'git', 'add', 'src/pause_code.py', 'CHANGELOG.md' );
    commit_says( $self, 'code while paused', 'BLOCK', 'feat: modify code while paused', 'Project Circuit Breaker' );
    $self->run_cmd( 'git', 'reset', '-q' );
    $self->run_cmd( 'git', 'checkout', '-q', '.' );
    AAPP::Tests::write_text( '.plans/pickup.md', "new note\n" );
    $self->ok_cmd( 'git', 'add', '.plans/pickup.md' );
    commit_says( $self, 'pickup while paused', 'PASS', 'chore(plans): add note while paused' );
    append( '.agents/AGENTS.md', "rule\n" );
    $self->ok_cmd( 'git', 'add', '.agents/AGENTS.md' );
    commit_says( $self, '.agents while paused', 'BLOCK', 'chore(agents): add rule while paused', 'Project Circuit Breaker' );
    $self->run_cmd( 'git', 'reset', '-q', '.agents/AGENTS.md' );
    File::Path::remove_tree('.agents');
    append( '.plans/done/P01.md', "done plan\n" );
    $self->ok_cmd( 'git', 'add', '.plans/done/P01.md' );
    commit_says( $self, '.plans/done while paused', 'BLOCK', 'chore(plans): archive while paused', 'Project Circuit Breaker' );
    $self->run_cmd( 'git', 'reset', '-q', '.plans/done/P01.md' );
    File::Path::remove_tree('.plans/done');
    $self->ok_cmd( 'aapp', 'resume' );
    my $merge = $self->ok_cmd( 'git', 'rev-parse', '--git-path', 'MERGE_HEAD' )->{out} =~ s/\s+\z//r;
    AAPP::Tests::write_text( $merge, '' );
    $self->fail_cmd( 'aapp', 'pause', 'in-flight test' );
    unlink($merge) or die "cannot remove $merge: $!\n";
    append( 'src/pause_code.py', "def f3(): pass\n" );
    bump();
    $self->ok_cmd( 'git', 'add', 'src/pause_code.py', 'CHANGELOG.md' );
    commit_says( $self, 'after resume', 'PASS', 'feat: commit after resume' );
    return 1;
}

sub test_pause_quarantines_every_worktree
{
    my ($self) = @_;
    my $other = Cwd::getcwd() . '-wt-branch2';
    $self->ok_cmd( 'git', 'worktree', 'add', '-q', $other, '-b', 'branch2' );
    AAPP::Tests::write_text( 'src/dirty_dev.txt',       "dirty develop\n" );
    AAPP::Tests::write_text( "$other/src/dirty_wt.txt", "dirty wt2\n" );
    $self->ok_cmd( 'aapp', 'pause', 'quarantine multi-worktree' );
    $self->eq_or_die( $self->ok_cmd( 'git', 'status', '--porcelain' )->{out},                 '', 'the main checkout is clean' );
    $self->eq_or_die( $self->ok_cmd( 'git', '-C', $other, 'status', '--porcelain' )->{out}, '', 'the second worktree is clean' );
    $self->ok_cmd( 'aapp', 'resume' );
    $self->file_exists_or_die('src/dirty_dev.txt');
    $self->file_exists_or_die("$other/src/dirty_wt.txt");
    $self->ok_cmd( 'git', 'worktree', 'remove', '--force', $other );
    return 1;
}

sub test_resume_conflict_loses_nothing
{
    my ($self) = @_;
    AAPP::Tests::write_text( 'src/conflict.txt', "conflict base\n" );
    $self->ok_cmd( 'git', 'add', 'src/conflict.txt' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'add conflict base', '--no-verify' );
    AAPP::Tests::write_text( 'src/conflict.txt', "modified for stash\n" );
    $self->ok_cmd( 'aapp', 'pause', 'conflict test' );
    AAPP::Tests::write_text( 'src/conflict.txt', "conflicting change while away\n" );
    $self->ok_cmd( 'git', 'commit', '--no-verify', '-qam', 'upstream conflicting commit' );
    $self->fail_cmd( 'aapp', 'resume' );
    my $common = $self->ok_cmd( 'git', 'rev-parse', '--git-common-dir' )->{out} =~ s/\s+\z//r;
    $self->file_exists_or_die("$common/aapp_paused");
    $self->true_or_die( $self->ok_cmd( 'git', 'stash', 'list' )->{out} ne '', 'the stash is kept' );
    return 1;
}

sub test_runtime_reachability
{
    my ($self) = @_;
    plan( 'p_reach.md', "### 📂 Target Files (Modifications & Additions)\n- [ ] `src/reach.py` -> reachability test\n### 🛑 Out of Bounds (Do Not Touch)\n## end\n" );
    my $empty = Cwd::getcwd() . '/.git/reach_empty_home';
    File::Path::make_path($empty);
    File::Copy::copy( "$ENV{HOME}/.gitconfig", "$empty/.gitconfig" ) or die "cannot copy the git identity: $!\n";
    my $bin   = "$ENV{HOME}/.local/bin";
    my $clean = join( ':', grep { $_ ne $bin } split( /:/, $ENV{PATH} ) );
    my $stage = sub {
        my ( $n, $with_changelog ) = @_;
        AAPP::Tests::write_text( 'src/reach.py', "reach=$n\n" );
        bump() if $with_changelog;
        $self->ok_cmd( 'git', 'add', 'src/reach.py', 'CHANGELOG.md' );
    };
    {
        local $ENV{HOME} = $empty;
        local $ENV{PATH} = $clean;
        $stage->( 1, 1 );
        my $r = $self->fail_cmd( 'git', 'commit', '-m', 'feat: reach neg' );
        $self->match_or_die( $r->{out} . $r->{err}, qr/INSPECTION-ONLY mode/, 'no reachable aapp: inspection-only' );
        clean($self);
        $stage->( 2, 1 );
        local $ENV{SKIP_BLAST_RADIUS} = 1;
        $r = $self->fail_cmd( 'git', 'commit', '-m', 'feat: reach skip' );
        $self->match_or_die( $r->{out} . $r->{err}, qr/INSPECTION-ONLY mode/, 'SKIP_BLAST_RADIUS does not bypass it' );
        clean($self);
    }
    $stage->( 3, 1 );
    $self->ok_cmd( 'git', 'commit', '-qm', 'feat: reach positive' );
    $stage->( 4, 1 );
    {
        local $ENV{PATH} = $clean;
        $self->ok_cmd( 'git', 'commit', '-qm', 'feat: reach fallback' );
    }
    $stage->( 5, 0 );
    {
        local $ENV{HOME} = $empty;
        local $ENV{PATH} = $clean;
        $self->ok_cmd( 'git', 'commit', '--no-verify', '-qm', 'feat: reach native bypass' );
    }
    return 1;
}

sub test_parser_boundaries
{
    my ($self) = @_;
    plan( 'p.md', <<'EOF' );
### 📂 Target Files (Modifications & Additions)
> **Authoring rule:** a quoted `src/quoted.py` in blockquote prose is never a target.
- [ ] `src/a.py` -> allowed
### 📝 Implementation Notes
- `src/notes.py` -> named under a non-target heading
### 🧪 Required Test Files
> Test files that must prove this plan's failure cases.
- `tests/boundary_test.sh`
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/secret.py` -> excluded
## end
EOF
    check( $self, 'a blockquote path',              'BLOCK', 'src/quoted.py' );
    check( $self, 'a foreign subsection path',      'BLOCK', 'src/notes.py' );
    check( $self, 'a Required Test Files path',     'PASS',  'tests/boundary_test.sh' );
    check( $self, 'a declared target beside them',  'PASS',  'src/a.py' );
    return 1;
}

sub test_missing_library_refuses_commit
{
    my ($self) = @_;
    fresh(
        $self, 'missing-perl-core',
        sub {
            local $ENV{AAPP_LIB} = '/tmp/nonexistent_aapp_lib';
            plan( 'p.md', "### 📂 Target Files (Modifications & Additions)\n- [ ] `src/a.py` -> allowed\n## end\n" );
            check( $self, 'missing perl core', 'BLOCK', 'src/a.py' );
            my $r = $self->fail_cmd( 'git', 'commit', '--allow-empty', '-m', 't' );
            $self->match_or_die( $r->{out} . $r->{err}, qr/Perl core missing/, 'missing perl core: the refusal names it' );
        }
    );
    return 1;
}

# Usage     : tdd_plan($status, $s3_test, @s4_files)
# Purpose   : A plan with one §3 required test (in $s3_test) and the §4 Required Test Files given.
# Returns   : 1
sub tdd_plan
{
    my ( $status, $s3, @s4 ) = @_;
    my $text = "* **Status:** $status\n## 🔨 3. Implementation Steps & Execution Checklist\n### 🧪 Required Tests (Failure & Boundary Assertions)\n"
        . "- [ ] `${s3}::test_fail` -> asserts error\n"
        . "$SECTION4\n### 📂 Target Files (Modifications & Additions)\n- [ ] `src/a.py`\n### 🧪 Required Test Files\n"
        . join( '', map {"- `$_`\n"} @s4 )
        . "### 🛑 Out of Bounds (Do Not Touch)\n";
    return plan_full( 'tdd.md', $text );
}

sub test_failure_test_declaration
{
    my ($self) = @_;
    plan( 'no_tdd.md', "### 📂 Target Files (Modifications & Additions)\n- [ ] `src/a.py`\n" );
    check( $self, 'a plan without required tests', 'PASS', 'src/a.py' );
    my $tests = sub { AAPP::Tests::write_text( $_, '' ) for @_ };
    foreach my $case (
        [ 's3-not-s4', 'a §3 test not in §4', 'BLOCK', '⚡ In Development', [ 'tests/b_test.py', 'tests/a_test.py' ], [ 'tests/a_test.py', 'tests/b_test.py' ] ],
        [ 's4-not-s3', 'a §4 file not in §3', 'BLOCK', '⚡ In Development', [ 'tests/a_test.py', 'tests/a_test.py', 'tests/b_test.py' ], [ 'tests/a_test.py', 'tests/b_test.py' ] ],
        [ 'refining', 'a refining plan with unwritten tests', 'PASS', '📝 Refining', [ 'tests/a_test.py', 'tests/a_test.py' ], [] ],
        [ 'missing', 'in development with a missing test file', 'BLOCK', '⚡ In Development', [ 'tests/a_test.py', 'tests/a_test.py' ], [] ] )
    {
        my ( $dir, $label, $want, $status, $plan, $written ) = @{$case};
        fresh(
            $self, $dir,
            sub {
                tdd_plan( $status, @{$plan} );
                File::Path::make_path('tests');
                $tests->( @{$written} );
                check( $self, $label, $want, 'src/a.py' );
            }
        );
    }
    return 1;
}

sub test_reminder_outside_helper_is_warning_only
{
    my ($self) = @_;
    plan_full( 'p_remind.md', <<"EOF" );
# Plan P-12: Reminder Test
* **Plan ID:** P-12
* **Status:** ⚡ In Development
$SECTION4
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py`
### 🛑 Out of Bounds (Do Not Touch)
EOF
    AAPP::Tests::write_text( '.git/aapp_active_plan', "P-12\n" );
    bump();
    append( 'src/a.py', "# change\n" );
    $self->ok_cmd( 'git', 'add', 'src/a.py', 'CHANGELOG.md' );
    commit_says( $self, 'a raw commit', 'PASS', 'raw commit', '(record this commit with|aapp commit adopt)' );
    bump();
    append( 'src/a.py', "# change 2\n" );
    $self->ok_cmd( 'git', 'add', 'src/a.py', 'CHANGELOG.md' );
    local $ENV{AAPP_COMMIT_HELPER} = 1;
    my $r = $self->ok_cmd( 'git', 'commit', '-m', 'helper commit' );
    $self->true_or_die( ( $r->{out} . $r->{err} ) !~ /record this commit with|aapp commit adopt/i, "the helper's commit prints no reminder" );
    return 1;
}

sub test_changelog_bullet_rules
{
    my ($self) = @_;
    my $long = '- long bullet: ';
    $long .= 'word ' while length($long) < 350;
    foreach my $case (
        [ 'short',  'a short bullet', 'PASS', '', [ '- short valid bullet within limits' ] ],
        [ 'long',   'a bullet over 300', 'BLOCK', 'Changelog bullet exceeds maximum length', [$long] ],
        [ 'cont',   'an unbulleted continuation', 'BLOCK', 'unbulleted continuation line', [ '- valid bullet', '  unbulleted continuation line that should be refused' ] ] )
    {
        my ( $dir, $label, $want, $pattern, $lines ) = @{$case};
        fresh(
            $self, $dir,
            sub {
                append( 'CHANGELOG.md', join( '', map {"$_\n"} @{$lines} ) );
                $self->ok_cmd( 'git', 'add', 'CHANGELOG.md' );
                commit_says( $self, $label, $want, 'changelog', $pattern );
            }
        );
    }
    $self->ok_cmd( 'git', 'config', 'aapp.changelogMaxLen', '80' );
    append( 'CHANGELOG.md', "- mid length bullet that easily exceeds eighty characters in total length for this test\n" );
    $self->ok_cmd( 'git', 'add', 'CHANGELOG.md' );
    commit_says( $self, 'a bullet over aapp.changelogMaxLen', 'BLOCK', 'custom threshold changelog', 'Changelog bullet exceeds maximum length' );
    return 1;
}

sub test_plan_declared_changelog_entry
{
    my ($self) = @_;
    my $code = sub {
        my ( $label, $want ) = @_;
        $STAMP++;
        append( 'src/a.py', "# touch $STAMP\n" );
        $self->ok_cmd( 'git', 'add', 'src/a.py' );
        my $r = commit_says( $self, $label, $want, 't' );
        $self->run_cmd( 'git', 'reset', '-q' );
        $self->run_cmd( 'git', 'checkout', '-q', '.' );
        return $r;
    };
    plan( 'P7-entry.md',
        "* **Plan ID:** P-7\n* **Status:** ⚡ In Development\n* **Changelog:** Added: Entry thing\n### 📂 Target Files (Modifications & Additions)\n- [ ] `src/a.py` -> change a\n### 🛑 Out of Bounds (Do Not Touch)\n## end\n" );
    AAPP::Tests::write_text( 'CHANGELOG.md', "# Changelog\n\n## [Unreleased]\n\n### Added\n- Other thing (`P-3`)\n" );
    $self->ok_cmd( 'git', 'add', 'CHANGELOG.md' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'changelog without P-7', '--no-verify' );
    $self->ok_cmd( 'git', 'commit', '-q', '--allow-empty', '-m', 'spacer', '--no-verify' );
    my $r = $code->( 'plan mode, no entry', 'BLOCK' );
    $self->match_or_die( $r->{all}, qr/aapp commit/, "the refusal names 'aapp commit'" );
    append( 'CHANGELOG.md', "- Entry thing (`P-7`)\n" );
    $self->ok_cmd( 'git', 'add', 'CHANGELOG.md' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'add P-7 entry', '--no-verify' );
    $self->ok_cmd( 'git', 'commit', '-q', '--allow-empty', '-m', 'spacer', '--no-verify' );
    $code->( 'plan mode, entry present', 'PASS' );
    $self->ok_cmd( 'git', 'config', 'aapp.changelogMode', 'commit' );
    $code->( 'commit mode, entry present', 'BLOCK' );
    $self->ok_cmd( 'git', 'config', '--unset', 'aapp.changelogMode' );
    unlink('.plans/current/P7-entry.md') or die "cannot remove the plan: $!\n";
    $code->( 'no active plan', 'BLOCK' );
    return 1;
}

sub test_plans_held_by_another_worktree
{
    my ($self) = @_;
    dev_plan( 'p60.md', 'P-60', 'src/held.py' );
    $self->ok_cmd( 'git', 'add', '-A' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'add p60', '--no-verify' );
    my $other = Cwd::getcwd() . '-wt-held';
    $self->ok_cmd( 'git', 'worktree', 'add', '-q', $other, 'HEAD' );
    $self->in_dir( $other, sub { $self->ok_cmd( 'aapp', 'active', 'P-60' ) } );
    check( $self, "a held plan's file from an unbound checkout", 'BLOCK', 'src/held.py' );
    check( $self, 'another file from an unbound checkout',      'PASS',  'src/free.py' );
    $self->ok_cmd( 'git', 'worktree', 'remove', '--force', $other );
    return 1;
}

sub test_gitattributes_always_allowed
{
    my ($self) = @_;
    dev_plan( 'p97.md', 'P-97', 'src/other.py' );
    check( $self, '.gitattributes while a plan is in development', 'PASS', '.gitattributes' );
    return 1;
}

sub test_atomic_commit_mode
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.commitMode', 'atomic' );
    my $head   = $self->ok_cmd( 'git', 'rev-parse', '--short', 'HEAD' )->{out} =~ s/\s+\z//r;
    my $branch = $self->ok_cmd( 'git', 'branch', '--show-current' )->{out} =~ s/\s+\z//r;
    plan_full( 'p51.md',
        "* **Plan ID:** P-51\n* **Status:** ⚡ In Development\n* **Commits:** `$head` ($branch)\n\n$SECTION4\n### 📂 Target Files (Modifications & Additions)\n- [ ] `src/a.py` -> target\n### 🛑 Out of Bounds (Do Not Touch)\n## end\n" );
    check( $self, 'atomic: a raw commit once the plan has one', 'BLOCK', 'src/a.py' );
    {
        local $ENV{AAPP_COMMIT_HELPER} = 1;
        check( $self, "atomic: the helper's commit", 'PASS', 'src/a.py' );
    }
    $self->ok_cmd( 'git', 'config', 'aapp.commitMode', 'microcommits' );
    check( $self, 'microcommits: a raw commit', 'PASS', 'src/a.py' );
    $self->ok_cmd( 'git', 'config', 'aapp.commitMode', 'atomic' );
    unlink('.plans/current/p51.md') or die "cannot remove the plan: $!\n";
    check( $self, 'atomic with no plan in development', 'PASS', 'src/a.py' );
    return 1;
}

sub test_member_leaves_architecture_to_group
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.commitMode', 'microcommits' );
    my $member = sub {
        my ($group) = @_;
        my $line = $group ne '' ? "* **Group:** $group\n" : '';
        plan_full( 'p71.md',
            "* **Plan ID:** P-71\n* **Status:** ⚡ In Development\n$line$SECTION4\n### 📂 Target Files (Modifications & Additions)\n- [ ] `src/a.py` -> target\n### 🛑 Out of Bounds (Do Not Touch)\n## end\n" );
    };
    $member->('P-70');
    bump();
    append( 'ARCHITECTURE.md', "# arch\n" );
    $self->ok_cmd( 'git', 'add', 'CHANGELOG.md', 'ARCHITECTURE.md' );
    commit_says( $self, 'a member commits ARCHITECTURE.md', 'BLOCK', 't', 'P-70' );
    $self->run_cmd( 'git', 'reset', '-q' );
    $self->run_cmd( 'git', 'checkout', '-q', '.' );
    unlink('ARCHITECTURE.md');
    $member->('');
    check( $self, 'a plan without a group commits ARCHITECTURE.md', 'PASS', 'ARCHITECTURE.md' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
