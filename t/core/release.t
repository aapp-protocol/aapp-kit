package AAPP::T::Core::Release;

use strict;
use warnings;
use utf8;
use 5.026;

use Digest::SHA ();
use File::Path ();
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/release.md. Run alone: prove -l t/core/release.t

# Usage     : fixture($self)
# Purpose   : A repository on main with an Unreleased changelog and empty archive ledgers, tags prefixed 'v'.
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    $self->init_repo();
    $self->ok_cmd( 'git', 'config', 'aapp.tagPrefix', 'v' );
    AAPP::Tests::write_text( 'main.py', "print('hello')\n" );
    AAPP::Tests::write_text( 'CHANGELOG.md',
        "# Changelog\nAll notable changes to this project will be documented in this file.\n\n## [Unreleased]\n### Added\n- Initial project structure.\n" );
    $self->ok_cmd( 'git', 'add', '.' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'initial commit' );
    $self->ok_cmd( 'git', 'branch', '-M', 'main' );
    File::Path::make_path( '.plans/current', '.plans/done' );
    AAPP::Tests::write_text( '.plans/done/000-archive-ledger.md',
        "# 🏛️ Archival Ledger (Completed Plans DB)\n\n| Date Completed | Plan ID | Plan File | Target Issue / Milestone | Verification Commit | Impact Summary (Repo-Relative) |\n| :--- | :--- | :--- | :--- | :--- | :--- |\n" );
    AAPP::Tests::write_text( '.plans/done/000-issues-archive.md',
        "# 🏛️ Master Issue Archive Ledger\n\n| # | Sev | Type | Date Opened | Date Resolved | Target Commit / Release | Plan / Resolution Summary |\n| :--- | :--- | :--- | :--- | :--- | :--- | :--- |\n" );
    return 1;
}

# Usage     : my $r = release($self, @args)
# Purpose   : Runs aapp release.
# Returns   : { exit, out, err, all }.
sub release
{
    my ( $self, @args ) = @_;
    my $r = $self->run_cmd( 'aapp', 'release', @args );
    $r->{all} = $r->{out} . $r->{err};
    return $r;
}

# Usage     : my $value = json_field($self, $field, @args)
# Purpose   : The first value of a field in 'release <args> json check'.
# Returns   : The value, or ''.
sub json_field
{
    my ( $self, $field, @args ) = @_;
    return release( $self, @args, 'json', 'check' )->{out} =~ /"\Q$field\E": "([^"]+)"/ ? $1 : '';
}

# Usage     : my $tag = tag_of($self, $name)
# Purpose   : The tag when it exists.
# Returns   : The tag name, or ''.
sub tag_of { my ( $self, $name ) = @_; return $self->ok_cmd( 'git', 'tag', '-l', $name )->{out} =~ s/\s+\z//r; }

sub test_version_forms
{
    my ($self) = @_;
    $self->eq_or_die( release( $self, $_, 'check' )->{exit}, 0, "$_ is valid" ) for qw(1.0.0 v1.2.3 1.2 v1.2 1.0.1.alpha 1.0.0-rc.1);
    $self->eq_or_die( release( $self, $_, 'check' )->{exit}, 1, "$_ is refused" ) for qw(1 v1 invalid 1.0.0-abcdefghijklmnopqrstuvwxyz0123456789);
    return 1;
}

sub test_bump_tokens_from_last_tag
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'tag', 'v1.0.0' );
    $self->eq_or_die( json_field( $self, 'version', 'patch' ), '1.0.1', 'patch' );
    $self->eq_or_die( json_field( $self, 'version', 'minor' ), '1.1.0', 'minor' );
    $self->eq_or_die( json_field( $self, 'version', 'major' ), '2.0.0', 'major' );
    $self->ok_cmd( 'git', 'tag', '-d', 'v1.0.0' );
    $self->ok_cmd( 'git', 'tag', 'v2.4.9' );
    $self->eq_or_die( json_field( $self, 'version', 'patch' ), '2.4.10', 'patch past 9' );
    $self->ok_cmd( 'git', 'tag', '-d', 'v2.4.9' );
    $self->ok_cmd( 'git', 'tag', 'v1.2' );
    $self->eq_or_die( json_field( $self, 'version', 'minor' ), '1.3.0', 'minor from two segments' );
    return 1;
}

sub test_phase_a_gates
{
    my ($self) = @_;
    $self->eq_or_die( release( $self, '1.0.0', 'check' )->{exit}, 0, 'check passes' );
    $self->eq_or_die( tag_of( $self, 'v1.0.0' ), '', 'check creates no tag' );
    $self->eq_or_die( release( $self, '1.0.0' )->{exit}, 0, 'a non-interactive run without yes' );
    $self->eq_or_die( tag_of( $self, 'v1.0.0' ), '', 'creates no tag' );
    AAPP::Tests::write_text( 'main.py', AAPP::Tests::read_text('main.py') . "dirty modification\n" );
    $self->eq_or_die( release( $self, '1.0.0', 'yes' )->{exit}, 1, 'a dirty tree refuses' );
    $self->ok_cmd( 'git', 'checkout', '--', 'main.py' );
    $self->ok_cmd( 'git', 'config', 'aapp.testCommand', 'exit 1' );
    $self->eq_or_die( release( $self, '1.0.0', 'yes' )->{exit}, 1, 'a failing aapp.testCommand refuses' );
    $self->ok_cmd( 'git', 'config', '--unset', 'aapp.testCommand' );
    $self->ok_cmd( 'git', 'rm', '-q', 'CHANGELOG.md' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'remove changelog for test' );
    $self->eq_or_die( release( $self, '1.0.0', 'check' )->{exit},                 1, 'a missing changelog refuses' );
    $self->eq_or_die( release( $self, '1.0.0', 'check', 'no-changelog' )->{exit}, 0, 'no-changelog lifts it' );
    return 1;
}

sub test_reachability_and_bundling
{
    my ($self) = @_;
    my $sha  = $self->ok_cmd( 'git', 'rev-parse', '--short', 'HEAD' )->{out} =~ s/\s+\z//r;
    my $plan = '.plans/done/P10-feature.md';
    AAPP::Tests::write_text( $plan,
        "# 🗺️ Plan P-10: Feature Plan\n* **Plan ID:** P-10\n* **Commits:** `$sha` (main)\n* **Status:** ✅ Done\n\n## 2. Technical Blueprint\n* **Plan ID:** P-X\n* **Commits:** `cafe123` (feat/example)\n" );
    AAPP::Tests::write_text( '.plans/done/000-issues-archive.md',
        AAPP::Tests::read_text('.plans/done/000-issues-archive.md') . "| #42 | `Low` | `CORE` | 2026-10-01 | 2026-10-05 | `0000000` | [`P10-feature.md`](done/P10-feature.md) |\n" );
    $self->eq_or_die( release( $self, '1.0.0', 'check' )->{exit}, 0, 'an ancestor commit passes' );
    AAPP::Tests::write_text( $plan, AAPP::Tests::read_text($plan) =~ s/`\Q$sha\E` \(main\)/`deadbeef` (main)/r );
    $self->eq_or_die( release( $self, '1.0.0', 'check' )->{exit},               1, 'a foreign commit refuses' );
    $self->eq_or_die( release( $self, '1.0.0', 'check', 'unverified' )->{exit}, 0, 'unverified lifts it' );
    AAPP::Tests::write_text( $plan, AAPP::Tests::read_text($plan) =~ s/`deadbeef` \(main\)/`$sha` (main)/r );
    my $r = release( $self, '1.0.0', 'yes' );
    $self->eq_or_die( $r->{exit}, 0, 'the release runs', $r->{all} );
    $self->eq_or_die( tag_of( $self, 'v1.0.0' ), 'v1.0.0', 'the tag' );
    $self->file_exists_or_die(".plans/release/v1.0.0/$_") for qw(plans/P10-feature.md 000-archive-ledger.md manifest.md manifest.json 000-issues-archive.md);
    $self->true_or_die( !-e $plan, 'the plan left done/' );
    my $ledger = AAPP::Tests::read_text('.plans/done/000-archive-ledger.md');
    $self->match_or_die( $ledger, qr/^## 🏷️ Shipped Releases/m,                        'the master ledger has Shipped Releases' );
    $self->match_or_die( $ledger, qr{\.\./release/v1\.0\.0/000-archive-ledger\.md},      'linking the tag ledger' );
    my $changelog = AAPP::Tests::read_text('CHANGELOG.md');
    $self->match_or_die( $changelog, qr/^## \[1\.0\.0\] -/m,     'the changelog is rolled up' );
    $self->match_or_die( $changelog, qr/^## \[Unreleased\]/m,    'under a fresh Unreleased' );
    return 1;
}

sub test_json_contract
{
    my ($self) = @_;
    my $out = release( $self, '1.0.0', 'json', 'check' )->{out};
    $self->eq_or_die( ( split( /\n/, $out ) )[0] // '', '{', 'a JSON document' );
    my %want = ( schemaVersion => '1.0.0', tag => 'v1.0.0', version => '1.0.0' );
    foreach my $field ( sort keys %want ) {
        $self->eq_or_die( $out =~ /"\Q$field\E": "([^"]+)"/ ? $1 : '', $want{$field}, $field );
    }
    return 1;
}

sub test_rollback_on_hook_failure
{
    my ($self) = @_;
    File::Path::make_path('.agents/skills/aapp-hooks');
    AAPP::Tests::write_text( 'fail_hook.sh', "#!/usr/bin/env bash\necho \"Triggering intentional hook failure\" >&2\nexit 1\n" );
    chmod( 0755, 'fail_hook.sh' ) or die "cannot chmod the hook: $!\n";
    my $sha = Digest::SHA->new(256)->addfile( 'fail_hook.sh', 'b' )->hexdigest;
    AAPP::Tests::write_text( '.agents/skills/aapp-hooks/registry.tsv', "on-release\tfail_hook.sh\tsha256:$sha\t10\tgate\n" );
    AAPP::Tests::write_text( '.plans/done/P20-test.md', "# 🗺️ Plan P-20: Test\n* **Plan ID:** P-20\n* **Commits:** none\n* **Status:** ✅ Done\n" );
    $self->eq_or_die( release( $self, '1.0.0', 'yes' )->{exit}, 1, 'the release aborts' );
    $self->eq_or_die( tag_of( $self, 'v1.0.0' ), '', 'no tag is left' );
    $self->true_or_die( !-d '.plans/release/v1.0.0', 'no bundle is left' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
