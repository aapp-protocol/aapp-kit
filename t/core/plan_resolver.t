package AAPP::T::Core::PlanResolver;

use strict;
use warnings;
use utf8;
use 5.026;

use File::Copy ();
use File::Path ();
use AAPP::Constants qw(RETURN_OK RETURN_NOT_FOUND);
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/plan_resolver.md. Run alone: prove -l t/core/plan_resolver.t

our $P13 = '.plans/current/P13-plan-ids-and-shorthand-resolution.md';

# Usage     : fixture($self)
# Purpose   : A repository on main with two current plans and one archived plan.
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    $self->init_repo();
    $self->ok_cmd( 'git', 'branch', '-M', 'main' );
    File::Path::make_path( '.plans/current', '.plans/done' );
    AAPP::Tests::write_text( '.plans/current/P9-guard-path-authorization.md', <<'EOF' );
# 🗺️ Plan P-9: Guard Path Authorization
* **Plan ID:** P-9
* **Status:** 🟣 Under Review

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/guard.sh` -> Guard updates.
EOF
    AAPP::Tests::write_text( $P13, <<'EOF' );
# 🗺️ Plan P-13: Plan IDs and Shorthand Resolution
* **Plan ID:** P-13
* **Status:** 🔷 Frozen

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/plan_resolver.sh` -> Resolver engine.
EOF
    AAPP::Tests::write_text( '.plans/done/plan-feature-aapp-slash-commands.md', "# 🗺️ Plan: Universal Slash Commands\n* **Plan ID:** P-7\n* **Status:** ✅ Done\n" );
    return 1;
}

# Usage     : issue_ledgers()
# Purpose   : Active ids #93 and #76, archived #91 and #97.
# Returns   : 1
sub issue_ledgers
{
    AAPP::Tests::write_text( '.plans/ISSUES.md', <<'EOF' );
| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #93 | `Low` | `CLI` | 2026-09-28 | `a` | top by priority |  | 🟡 `Incubated` |
| #76 | `Low` | `CLI` | 2026-09-21 | `b` | bottom row, lower id |  | 🟡 `Incubated` |
EOF
    AAPP::Tests::write_text( '.plans/done/000-issues-archive.md', <<'EOF' );
| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #91 | `Low` | `CORE` | 2026-09-28 | 2026-09-28 | `0000000` | archived |
| #97 | `Low` | `CORE` | 2026-09-28 | 2026-09-28 | `0000000` | highest id is archived |
EOF
    return 1;
}

# Usage     : my $r = state_call($self, $function, @args) / health_call(...)
# Purpose   : An AAPP::State or AAPP::Health function in the test's repository.
# Returns   : { exit, out, err, ret }.
sub state_call  { my ( $self, @call ) = @_; return $self->lib_call( 'state',  @call ); }
sub health_call { my ( $self, @call ) = @_; return $self->lib_call( 'health', @call ); }

# Usage     : my $path = resolve($self, $query, $verb, $scope)
# Purpose   : The plan path resolve_plan_path finds, or undef.
# Returns   : The path.
sub resolve
{
    my ( $self, $query, $verb, $scope ) = @_;
    my $ret = state_call( $self, 'resolve_plan_path', $query, $verb // 'inspect', $scope // 'current', $self->{dir} )->{ret};
    return $ret->[0] == RETURN_OK ? $ret->[1] : undef;
}

# Usage     : my $n = violations($self, $check, @args)
# Purpose   : The violation count of a planning health check (0: it passes).
# Returns   : The count.
sub violations
{
    my ( $self, $check, @args ) = @_;
    return health_call( $self, $check, @args )->{ret}[0];
}

sub test_resolve_exact_path_and_filename
{
    my ($self) = @_;
    $self->eq_or_die( resolve( $self, $P13 ),                                         $P13, 'a relative path' );
    $self->eq_or_die( resolve( $self, 'P13-plan-ids-and-shorthand-resolution.md' ),   $P13, 'a bare file name' );
    return 1;
}

sub test_resolve_numeric_id_forms
{
    my ($self) = @_;
    $self->eq_or_die( resolve( $self, $_ ), $P13, "query $_" ) for qw(P-13 p-13 P13 p13 13 P013 P-013);
    return 1;
}

sub test_resolve_slug_substring
{
    my ($self) = @_;
    $self->eq_or_die( resolve( $self, 'guard-path' ), '.plans/current/P9-guard-path-authorization.md', 'a slug' );
    return 1;
}

sub test_resolve_refuses_issue_reference
{
    my ($self) = @_;
    my $r = state_call( $self, 'resolve_plan_path', '#13', 'freeze', 'current', $self->{dir} );
    $self->true_or_die( $r->{ret}[0] != RETURN_OK, '#13 is refused' );
    $self->match_or_die( $r->{err}, qr/'#13' is an issue reference/, 'as an issue reference' );
    $self->match_or_die( $r->{err}, qr/Did you mean P-13\?/,         'suggesting P-13' );
    return 1;
}

sub test_resolve_refuses_empty_query_on_transitions
{
    my ($self) = @_;
    foreach my $verb (qw(freeze done)) {
        my $r = state_call( $self, 'resolve_plan_path', '', $verb, 'current', $self->{dir} );
        $self->true_or_die( $r->{ret}[0] != RETURN_OK, "an empty query is refused for $verb" );
        $self->match_or_die( $r->{err}, qr/name the plan for '$verb'/, "the refusal for $verb" );
    }
    return 1;
}

sub test_get_plan_id
{
    my ($self) = @_;
    $self->eq_or_die( state_call( $self, 'plan_id', '.plans/current/P9-guard-path-authorization.md' )->{ret}[0], 'P-9', 'the plan id' );
    return 1;
}

sub test_mini_plans_are_not_plans
{
    my ($self) = @_;
    AAPP::Tests::write_text( '.plans/current/fix-98.md', "* **Plan ID:** #98\n* **Target Issue / Milestone:** #98\n* **Status:** ⚡ In Development\n" );
    $self->true_or_die( ( resolve( $self, 'fix' ) // '' ) ne '.plans/current/fix-98.md', 'the resolver does not pick fix-98.md' );
    my $r = health_call( $self, 'check_pair4_plan_id_integrity', $self->{dir} );
    $self->true_or_die( ( $r->{out} . $r->{err} ) !~ /fix-98/, 'pair 4 does not name fix-98.md' );
    return 1;
}

sub test_plan_counter_peek_and_allocate
{
    my ($self) = @_;
    my $id = sub { my $ret = state_call( $self, @_ )->{ret}; return $ret->[0] == RETURN_OK ? $ret->[1] : 'refused' };
    my $counter = sub { $self->run_cmd( 'git', 'config', '--get', 'aapp.planId' )->{out} =~ s/\s+$//r };
    $self->eq_or_die( $id->('next_plan_id'), 'P-1', 'unset: P-1' );
    $self->ok_cmd( 'git', 'config', 'aapp.planId', '25' );
    $self->eq_or_die( $id->('next_plan_id') . ' ' . $id->('next_plan_id') . ' ' . $counter->(), 'P-25 P-25 25', 'peeking twice leaves the counter' );
    $self->eq_or_die( state_call( $self, 'next_plan_id' )->{err}, '', 'peeking prints nothing' );
    $self->eq_or_die( $id->('allocate_plan_id'), 'P-25', 'allocate' );
    $self->eq_or_die( $counter->(),              '26',   'the counter after allocating' );
    $self->eq_or_die( $id->('allocate_plan_id'), 'P-26', 'allocate again' );
    $self->ok_cmd( 'git', 'config', 'aapp.planId', 'corrupt' );
    $self->eq_or_die( $id->('allocate_plan_id'), 'refused', 'a corrupt counter refuses allocating' );
    $self->eq_or_die( $counter->(),              'corrupt', 'and is left as it is' );
    $self->eq_or_die( $id->('next_plan_id'),     'refused', 'a corrupt counter refuses peeking' );
    return 1;
}

sub test_normalize_plan_id
{
    my ($self) = @_;
    $self->eq_or_die( state_call( $self, 'normalize_plan_id', 'P-42' )->{ret}[1], 'P-42', 'P-42' );
    $self->eq_or_die( state_call( $self, 'normalize_plan_id', '42' )->{ret}[1],   'P-42', '42' );
    $self->true_or_die( state_call( $self, 'normalize_plan_id', 'not-an-int' )->{ret}[0] != RETURN_OK, 'a non-integer is refused' );
    $self->true_or_die( state_call( $self, 'normalize_plan_id', '' )->{ret}[0] != RETURN_OK,           'empty is refused' );
    return 1;
}

sub test_plan_id_provider
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.planId', '30' );
    $self->eq_or_die( state_call( $self, 'allocate_plan_id' )->{ret}[1], 'P-30', 'no provider: local counter used' );

    my $prov_dir = '.agents/skills/aapp-planid';
    File::Path::make_path($prov_dir);

    # 1. Provider returns string ID {"id": "P-88"}
    my $script = <<"EOF";
#!/bin/sh
cat > planid.stdin
echo '{"id": "P-88", "extra": {"k": 1}}'
EOF
    AAPP::Tests::write_text( "$prov_dir/run", $script );
    chmod( 0755, "$prov_dir/run" );

    $self->eq_or_die( state_call( $self, 'allocate_plan_id' )->{ret}[1], 'P-88', 'provider string id accepted' );
    $self->eq_or_die( $self->run_cmd( 'git', 'config', '--get', 'aapp.planId' )->{out} =~ s/\s+$//r, '89', 'counter ratchets past issued id' );
    my $stdin_content = do { open( my $fh, '<', 'planid.stdin' ); local $/; my $c = <$fh>; close($fh); $c // '' };
    $self->true_or_die( index( $stdin_content, '"event": "plan.allocate"' ) >= 0, 'plan.allocate event in envelope' );
    $self->true_or_die( index( $stdin_content, '"extra": {}' ) >= 0, 'envelope carries reserved extra' );

    # 2. Bare integer id accepted
    AAPP::Tests::write_text( "$prov_dir/run", "#!/bin/sh\necho '{\"id\": 90}'\n" );
    chmod( 0755, "$prov_dir/run" );
    $self->eq_or_die( state_call( $self, 'allocate_plan_id' )->{ret}[1], 'P-90', 'bare integer id accepted' );
    $self->eq_or_die( $self->run_cmd( 'git', 'config', '--get', 'aapp.planId' )->{out} =~ s/\s+$//r, '91', 'counter ratchets past 90' );

    # 3. Plain text response rejected
    AAPP::Tests::write_text( "$prov_dir/run", "#!/bin/sh\necho P-91\n" );
    chmod( 0755, "$prov_dir/run" );
    my $r_plain = state_call( $self, 'allocate_plan_id' );
    $self->true_or_die( $r_plain->{ret}[0] != RETURN_OK, 'plain-text response rejected' );
    $self->match_or_die( $r_plain->{err}, qr/Provider must print \{"id": \.\.\.\}/, 'plain text diagnostic' );

    # 4. Error text shown on failure
    AAPP::Tests::write_text( "$prov_dir/run", "#!/bin/sh\necho '{\"error\": \"authority offline\"}'\nexit 1\n" );
    chmod( 0755, "$prov_dir/run" );
    my $r_err = state_call( $self, 'allocate_plan_id' );
    $self->true_or_die( $r_err->{ret}[0] != RETURN_OK, 'failing provider is fatal' );
    $self->match_or_die( $r_err->{err}, qr/authority offline/, 'provider error text shown' );

    # 5. Failing provider without error text: no local fallback
    AAPP::Tests::write_text( "$prov_dir/run", "#!/bin/sh\nexit 3\n" );
    chmod( 0755, "$prov_dir/run" );
    my $r_fail = state_call( $self, 'allocate_plan_id' );
    $self->true_or_die( $r_fail->{ret}[0] != RETURN_OK, 'failing provider without json error is fatal' );
    $self->eq_or_die( $self->run_cmd( 'git', 'config', '--get', 'aapp.planId' )->{out} =~ s/\s+$//r, '91', 'no local fallback on failure' );

    # 6. Malformed id rejected
    AAPP::Tests::write_text( "$prov_dir/run", "#!/bin/sh\necho '{\"id\": \"not-a-number\"}'\n" );
    chmod( 0755, "$prov_dir/run" );
    my $r_mal = state_call( $self, 'allocate_plan_id' );
    $self->true_or_die( $r_mal->{ret}[0] != RETURN_OK, 'malformed id rejected' );
    $self->match_or_die( $r_mal->{err}, qr/must return an integer id/, 'malformed id diagnostic' );

    File::Path::remove_tree('.agents');
    unlink('planid.stdin');
    $self->ok_cmd( 'git', 'config', '--unset', 'aapp.planId' );
    return 1;
}

sub test_issue_counter_peek_and_allocate
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.issueId', '7' );
    $self->ok_cmd( 'git', 'config', 'aapp.planId',  '3' );
    $self->eq_or_die( state_call( $self, 'next_issue_id' )->{ret}[1],     '#7', 'peek' );
    $self->eq_or_die( state_call( $self, 'allocate_issue_id' )->{ret}[1], '#7', 'allocate' );
    my $counters = join( ' ', map { $self->run_cmd( 'git', 'config', '--get', $_ )->{out} =~ s/\s+$//r } qw(aapp.issueId aapp.planId) );
    $self->eq_or_die( $counters, '8 3', 'the issue counter moves, the plan counter does not' );
    return 1;
}

sub test_seed_issue_id
{
    my ($self) = @_;
    $self->eq_or_die( state_call( $self, 'seed_issue_id', '.plans' )->{ret}[0], RETURN_NOT_FOUND, 'no ledgers: not found' );
    File::Copy::copy( "$self->{kit}/templates/issues.md",              '.plans/ISSUES.md' )                  or die "copy: $!\n";
    File::Copy::copy( "$self->{kit}/templates/done-issues-archive.md", '.plans/done/000-issues-archive.md' ) or die "copy: $!\n";
    $self->eq_or_die( state_call( $self, 'seed_issue_id', '.plans' )->{ret}[1], 1, 'template example rows are ignored' );
    issue_ledgers();
    $self->eq_or_die( state_call( $self, 'seed_issue_id', '.plans' )->{ret}[1], 98, 'past the highest numeric id in both ledgers' );
    return 1;
}

sub test_pair4_plan_id_integrity
{
    my ($self) = @_;
    $self->eq_or_die( violations( $self, 'check_pair4_plan_id_integrity', $self->{dir} ), 0, 'unique ids pass' );
    AAPP::Tests::write_text( '.plans/current/P9-duplicate.md', "# 🗺️ Plan: Duplicate Test\n* **Plan ID:** P-9\n* **Status:** 🟣 Under Review\n" );
    $self->true_or_die( violations( $self, 'check_pair4_plan_id_integrity', $self->{dir} ) > 0, 'a duplicate is refused' );
    return 1;
}

sub test_pair5_self_protection
{
    my ($self) = @_;
    $self->eq_or_die( violations( $self, 'check_pair5_target_files_self_protection', $self->{dir} ), 0, 'safe targets pass' );
    AAPP::Tests::write_text( '.plans/current/P99-bad-target.md', <<'EOF' );
# 🗺️ Plan P-99: Bad Target Test
* **Plan ID:** P-99
* **Status:** 🟣 Under Review

### 📂 Target Files (Modifications & Additions)
- [ ] `.agents/skills/aapp-freeze/SKILL.md` -> Attempted direct skill edit.
EOF
    $self->true_or_die( violations( $self, 'check_pair5_target_files_self_protection', $self->{dir} ) > 0, 'a self-protected target is refused' );
    return 1;
}

sub test_pair6_recorded_sha_integrity
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'add', '-A' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'fixture commit' );
    my $sha    = $self->ok_cmd( 'git', 'rev-parse', '--short', 'HEAD' )->{out} =~ s/\s+$//r;
    my $ledger = sub {
        AAPP::Tests::write_text( '.plans/done/000-archive-ledger.md', join( "\n", '# 🏛️ Archival Ledger',
            '| Date Completed | Plan ID | Plan File | Target Issue | Verification Commit | Impact Summary |', '| :--- | :--- | :--- | :--- | :--- | :--- |',
            "| 2026-09-15 | `P-7` | [`plan.md`](plan.md) | `#61` | `$_[0]` | Completed feature. |" ) . "\n" );
    };
    my $check = sub { violations( $self, 'check_pair6_recorded_sha_integrity', $self->{dir} ) };
    $ledger->($sha);
    $self->eq_or_die( $check->(), 0, 'a ledger commit the repository holds passes' );
    $ledger->('deadbeef12');
    $self->true_or_die( $check->() > 0, 'a dangling ledger commit is refused' );
    $ledger->($sha);
    AAPP::Tests::write_text( 'CHANGELOG.md', "# Changelog\n## [Unreleased]\n- Bugfix recorded in commit `cafebabe99`.\n" );
    $self->true_or_die( $check->() > 0, 'a dangling changelog commit is refused' );
    AAPP::Tests::write_text( 'CHANGELOG.md', "# Changelog\n## [Unreleased]\n- Bugfix recorded in commit `$sha`.\n" );
    $self->eq_or_die( $check->(), 0, 'a changelog commit the repository holds passes' );
    return 1;
}

sub test_pair7_shared_docs_exempt
{
    my ($self) = @_;
    my $plan = sub {
        my ( $n, $code ) = @_;
        AAPP::Tests::write_text( ".plans/current/P$n-p7.md", <<"EOF" );
# 🗺️ Plan P-$n: Pair 7 fixture
* **Plan ID:** P-$n
* **Status:** ⚡ In Development

## 💥 4. Blast Radius & System Boundaries
### 📂 Target Files (Modifications & Additions)
- [ ] `$code` -> Code.
- [ ] `CHANGELOG.md` -> Record.
- [ ] `.agents/CODEMAP.md` -> Map.
EOF
    };
    $plan->( 90, 'lib/a.sh' );
    $plan->( 91, 'lib/b.sh' );
    my $r = health_call( $self, 'check_pair7_inflight_boundary_collision', $self->{dir} );
    $self->eq_or_die( $r->{ret}[0], 0, 'plans sharing only shared docs pass' );
    my $notices = () = ( $r->{out} . $r->{err} ) =~ /Shared Doc.*CHANGELOG\.md/g;
    $self->eq_or_die( $notices, 1, 'one shared-doc notice' );
    $self->eq_or_die( state_call( $self, 'is_shared_doc', '.agents/CODEMAP.md' )->{ret}[0], 1, 'a nested shared doc' );
    $self->eq_or_die( state_call( $self, 'is_shared_doc', 'lib/a.sh' )->{ret}[0],           0, 'a code file' );
    $self->eq_or_die( state_call( $self, 'is_shared_doc', 'package.json' )->{ret}[0],       0, 'a manifest' );
    $plan->( 92, 'lib/a.sh' );
    $self->true_or_die( violations( $self, 'check_pair7_inflight_boundary_collision', $self->{dir} ) > 0, 'a shared code file is refused' );
    return 1;
}

sub test_pair8_issue_id_integrity
{
    my ($self) = @_;
    issue_ledgers();
    my @ledgers = ( '.plans/ISSUES.md', '.plans/done/000-issues-archive.md' );
    $self->eq_or_die( violations( $self, 'check_pair8_issue_id_integrity', @ledgers ), 0, 'unique issue ids pass' );
    AAPP::Tests::write_text( $ledgers[0], AAPP::Tests::read_text( $ledgers[0] ) . "| #93 | `Low` | `CLI` | 2026-09-29 | `c` | reused id | fix | 🟡 `Incubated` |\n" );
    my $r = health_call( $self, 'check_pair8_issue_id_integrity', @ledgers );
    $self->true_or_die( $r->{ret}[0] > 0, 'an id twice in the active ledger is refused' );
    $self->match_or_die( $r->{out} . $r->{err}, qr/Issue #93 appears more than once in active/, 'naming it' );
    issue_ledgers();
    AAPP::Tests::write_text( $ledgers[1], AAPP::Tests::read_text( $ledgers[1] ) . "| #91 | `Low` | `CORE` | 2026-09-29 | 2026-09-29 | `0000000` | reused archived id |\n" );
    $r = health_call( $self, 'check_pair8_issue_id_integrity', @ledgers );
    $self->true_or_die( $r->{ret}[0] > 0, 'an id twice in the archive is refused' );
    $self->match_or_die( $r->{out} . $r->{err}, qr/Issue #91 appears more than once in archive/, 'naming it' );
    return 1;
}

sub test_planning_health_overall
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'add', '-A' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'fixture commit' );
    my $sha = $self->ok_cmd( 'git', 'rev-parse', '--short', 'HEAD' )->{out} =~ s/\s+$//r;
    AAPP::Tests::write_text( '.plans/ISSUES.md', join( "\n", '# 🐛 Issues: Active Technical Backlog',
        '| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |', '| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |',
        '| #1 | `Critical` | `CORE` | 2026-09-10 | `src/a.py:1` | Issue symptom. |  | 🟡 `Incubated` |' ) . "\n" );
    AAPP::Tests::write_text( '.plans/done/000-issues-archive.md', join( "\n", '# 🏛️ Master Issue Archive Ledger',
        '| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |', '| :--- | :--- | :--- | :--- | :--- | :--- | :--- |',
        "| #2 | `High` | `CLI` | 2026-09-09 | 2026-09-09 | `$sha` | Resolved description. |" ) . "\n" );
    AAPP::Tests::write_text( '.plans/issues_road_map.md', "# 🗺️ Issue Work Queue\n1. #1 -> Active issue\n" );
    $self->eq_or_die( violations( $self, 'check_planning_health', $self->{dir} ), 0, 'consistent ledgers pass' );
    AAPP::Tests::write_text( '.plans/done/000-issues-archive.md',
        AAPP::Tests::read_text('.plans/done/000-issues-archive.md') . "| #1 | `High` | `CLI` | 2026-09-09 | 2026-09-09 | `$sha` | Collision summary. |\n" );
    $self->true_or_die( violations( $self, 'check_planning_health', $self->{dir} ) > 0, 'an id in both ledgers is refused' );
    return 1;
}

sub test_release_bundles_resolved_and_seeded
{
    my ($self) = @_;
    File::Path::make_path('.plans/release/v1.0.0/plans');
    AAPP::Tests::write_text( '.plans/release/v1.0.0/plans/P99-release-test.md', "# Plan P-99: Release Test\n* **Plan ID:** P-99\n* **Status:** ✅ Done\n" );
    AAPP::Tests::write_text( '.plans/release/v1.0.0/000-issues-archive.md', <<'EOF' );
| # | Sev | Type | Date Opened | Date Resolved | Target Commit | Summary |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #150 | `Low` | `CLI` | 2026-09-01 | 2026-09-02 | `abc1234` | Released fix. |
EOF
    my $rel = '.plans/release/v1.0.0/plans/P99-release-test.md';
    $self->eq_or_die( resolve( $self, 'P-99', 'inspect', 'done' ),        $rel, 'by id, done scope' );
    $self->eq_or_die( resolve( $self, 'release-test', 'inspect', 'all' ), $rel, 'by slug, all scope' );
    $self->eq_or_die( state_call( $self, 'seed_issue_id', '.plans' )->{ret}[1], 151, 'the issue seed counts the bundle' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
