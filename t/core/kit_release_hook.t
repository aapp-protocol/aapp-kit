package AAPP::T::Core::KitReleaseHook;

use strict;
use warnings;
use utf8;
use 5.026;

use File::Copy ();
use File::Path ();
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/kit_release_hook.md. Run alone: prove -l t/core/kit_release_hook.t

our @TEMPLATES = qw(AGENTS plan-template pickup release_checklist);
our $HOOK      = './scripts/kit-on-release.sh';

# Usage     : fixture($self)
# Purpose   : A mock kit at version 1.0.0: its aapp, four managed templates and the kit's on-release hook, committed.
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    $self->init_repo();
    File::Path::make_path( 'templates', 'scripts' );
    AAPP::Tests::write_text( 'aapp', "#!/usr/bin/env bash\nAAPP_VERSION=\"1.0.0\"\necho \"AAPP Kit \$AAPP_VERSION\"\n" );
    chmod( 0755, 'aapp' ) or die "cannot chmod aapp: $!\n";
    AAPP::Tests::write_text( "templates/$_.md", "# $_\n<!-- AAPP-PROTOCOL:START v1.0.0 -->\nBody\n<!-- AAPP-PROTOCOL:END -->\n" ) for @TEMPLATES;
    File::Copy::copy( "$self->{kit}/scripts/kit-on-release.sh", $HOOK ) or die "cannot copy the hook: $!\n";
    chmod( 0755, $HOOK ) or die "cannot chmod the hook: $!\n";
    $self->ok_cmd( 'git', 'add', '.' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'initial kit structure' );
    return 1;
}

# Usage     : bumped($self, $version)
# Purpose   : The CLI and the four templates carry the version.
# Returns   : 1
sub bumped
{
    my ( $self, $version ) = @_;
    $self->match_or_die( AAPP::Tests::read_text('aapp'), qr/^AAPP_VERSION="\Q$version\E"$/m, "the CLI is at $version" );
    my $count = grep { index( AAPP::Tests::read_text("templates/$_.md"), "<!-- AAPP-PROTOCOL:START v$version -->" ) >= 0 } @TEMPLATES;
    $self->eq_or_die( $count, scalar(@TEMPLATES), "every template is at v$version" );
    return 1;
}

sub test_version_from_environment
{
    my ($self) = @_;
    local $ENV{AAPP_RAW_VERSION}     = '1.2.0';
    local $ENV{AAPP_RELEASE_VERSION} = 'v1.2.0';
    $self->ok_cmd($HOOK);
    bumped( $self, '1.2.0' );
    return 1;
}

sub test_version_from_stdin_json
{
    my ($self) = @_;
    $self->ok_cmd( { stdin => qq({"event":"on-release","tag":"v1.3.0","rawVersion":"1.3.0","version":"1.3.0"}\n) }, $HOOK );
    bumped( $self, '1.3.0' );
    return 1;
}

sub test_refuses_missing_or_invalid_version
{
    my ($self) = @_;
    $self->eq_or_die( $self->run_cmd($HOOK)->{exit}, 1, 'no version exits 1' );
    {
        local $ENV{AAPP_RAW_VERSION} = 'invalid.version.format!!';
        $self->eq_or_die( $self->run_cmd($HOOK)->{exit}, 1, 'a malformed version exits 1' );
    }
    bumped( $self, '1.0.0' );
    return 1;
}

sub test_release_runs_kit_hook
{
    my ($self) = @_;
    File::Path::make_path('.plans/done');
    AAPP::Tests::write_text( '.plans/done/000-archive-ledger.md',
        "# 🗄️ Master Archive Ledger\n| Date | Plan ID | Blueprint / Specification | Target Issue / Milestone | Verification Commit | Impact Summary |\n| :--- | :--- | :--- | :--- | :--- | :--- |\n" );
    AAPP::Tests::write_text( 'CHANGELOG.md', "# Changelog\n## [Unreleased]\n### Added\n- Sample feature\n" );
    $self->ok_cmd( 'git', 'add', '.plans', 'CHANGELOG.md' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'setup for release' );
    $self->ok_cmd( 'git', 'config', 'aapp.hook.on-release', 'scripts/kit-on-release.sh' );
    $self->ok_cmd( 'git', 'config', 'aapp.testCommand',     'true' );
    $self->ok_cmd( 'git', 'branch', '-M', 'main' );
    $self->ok_cmd( 'aapp', 'release', '1.5.0', 'yes' );
    bumped( $self, '1.5.0' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
