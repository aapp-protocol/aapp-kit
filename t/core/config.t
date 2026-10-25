package AAPP::T::Core::Config;

use strict;
use warnings;
use utf8;
use 5.026;

use File::Path ();
use AAPP::Constants qw(RETURN_OK RETURN_ERROR);
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/config.md. Run alone: prove -l t/core/config.t

# Usage     : fixture($self)
# Purpose   : Initializes an empty git repository in the sandbox.
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    return $self->init_repo();
}

# Usage     : write_conf($dir, $text)
# Purpose   : Writes main.conf into the specified directory.
# Returns   : Path to main.conf
sub write_conf
{
    my ( $dir, $text ) = @_;
    File::Path::make_path($dir);
    my $file = "$dir/main.conf";
    open( my $fh, '>:encoding(UTF-8)', $file ) or die "Cannot write $file: $!";
    print {$fh} $text;
    close($fh);
    return $file;
}

sub test_system_overrides_user_and_repo
{
    my ($self) = @_;
    my $sys_dir  = "$self->{scratch}/sys_test1";
    my $user_dir = "$self->{scratch}/user_test1";
    write_conf( $sys_dir, "[aapp]\ngovernance = hitl\n" );
    write_conf( $user_dir, "[aapp]\ngovernance = autonomous\n" );
    $self->ok_cmd( 'git', 'config', 'aapp.governance', 'lax' );

    local $ENV{AAPP_SYS_CONF_DIR}  = $sys_dir;
    local $ENV{AAPP_USER_CONF_DIR} = $user_dir;

    my $r_val = $self->lib_call( 'config', 'get', 'aapp.governance' );
    $self->eq_or_die( $r_val->{ret}[0], 'hitl', 'system overrides user and repo' );

    my $r_src = $self->lib_call( 'config', 'source', 'aapp.governance' );
    $self->eq_or_die( $r_src->{ret}[0], 'system:global', 'source is system:global' );
    return 1;
}

sub test_user_overrides_repo
{
    my ($self) = @_;
    my $sys_dir  = "$self->{scratch}/sys_empty2";
    my $user_dir = "$self->{scratch}/user_test2";
    File::Path::make_path($sys_dir);
    write_conf( $user_dir, "[aapp]\ngovernance = autonomous\n" );
    $self->ok_cmd( 'git', 'config', 'aapp.governance', 'lax' );

    local $ENV{AAPP_SYS_CONF_DIR}  = $sys_dir;
    local $ENV{AAPP_USER_CONF_DIR} = $user_dir;

    my $r_val = $self->lib_call( 'config', 'get', 'aapp.governance' );
    $self->eq_or_die( $r_val->{ret}[0], 'autonomous', 'user overrides repo' );

    my $r_src = $self->lib_call( 'config', 'source', 'aapp.governance' );
    $self->eq_or_die( $r_src->{ret}[0], 'user:global', 'source is user:global' );
    return 1;
}

sub test_repo_subsection_overrides_global
{
    my ($self) = @_;
    my $repo_root = Cwd::abs_path( Cwd::getcwd() );
    my $sys_dir   = "$self->{scratch}/sys_test3";
    my $user_dir  = "$self->{scratch}/user_empty3";
    File::Path::make_path($user_dir);
    write_conf(
        $sys_dir,
        qq{[aapp]\ngovernance = hitl\n\n[aapp "repo:$repo_root"]\ngovernance = strict\n}
    );

    local $ENV{AAPP_SYS_CONF_DIR}  = $sys_dir;
    local $ENV{AAPP_USER_CONF_DIR} = $user_dir;

    my $r_val = $self->lib_call( 'config', 'get', 'aapp.governance' );
    $self->eq_or_die( $r_val->{ret}[0], 'strict', 'repo subsection overrides global block' );

    my $r_src = $self->lib_call( 'config', 'source', 'aapp.governance' );
    $self->eq_or_die( $r_src->{ret}[0], 'system:repo', 'source is system:repo' );
    return 1;
}

sub test_absent_keys_fallthrough
{
    my ($self) = @_;
    my $sys_dir  = "$self->{scratch}/sys_test4";
    my $user_dir = "$self->{scratch}/user_test4";
    write_conf( $sys_dir,  "[aapp]\ngovernance = hitl\n" );
    write_conf( $user_dir, "[aapp]\naiAttribution = strict\n" );
    $self->ok_cmd( 'git', 'config', 'aapp.subjectMaxLen', '50' );

    local $ENV{AAPP_SYS_CONF_DIR}  = $sys_dir;
    local $ENV{AAPP_USER_CONF_DIR} = $user_dir;

    my $r_val = $self->lib_call( 'config', 'get', 'aapp.subjectMaxLen' );
    $self->eq_or_die( $r_val->{ret}[0], '50', 'absent key falls through to local git config' );

    my $r_src = $self->lib_call( 'config', 'source', 'aapp.subjectMaxLen' );
    $self->eq_or_die( $r_src->{ret}[0], 'repository', 'source is repository' );
    return 1;
}

sub test_source_origin_tracking
{
    my ($self) = @_;
    my $repo_root = Cwd::abs_path( Cwd::getcwd() );
    my $sys_dir   = "$self->{scratch}/sys_test5";
    my $user_dir  = "$self->{scratch}/user_test5";

    write_conf(
        $sys_dir,
        qq{[aapp]\ngovernance = hitl\n\n[aapp "repo:$repo_root"]\ngovernanceTimeout = 30\n}
    );
    write_conf(
        $user_dir,
        qq{[aapp]\naiAttribution = strict\n\n[aapp "repo:$repo_root"]\naiNotes = true\n}
    );
    $self->ok_cmd( 'git', 'config', 'aapp.fixMaxLines', '500' );

    local $ENV{AAPP_SYS_CONF_DIR}  = $sys_dir;
    local $ENV{AAPP_USER_CONF_DIR} = $user_dir;

    $self->eq_or_die( $self->lib_call( 'config', 'source', 'aapp.governance' )->{ret}[0],        'system:global', 'track system:global' );
    $self->eq_or_die( $self->lib_call( 'config', 'source', 'aapp.governanceTimeout' )->{ret}[0], 'system:repo',   'track system:repo' );
    $self->eq_or_die( $self->lib_call( 'config', 'source', 'aapp.aiAttribution' )->{ret}[0],     'user:global',   'track user:global' );
    $self->eq_or_die( $self->lib_call( 'config', 'source', 'aapp.aiNotes' )->{ret}[0],           'user:repo',     'track user:repo' );
    $self->eq_or_die( $self->lib_call( 'config', 'source', 'aapp.fixMaxLines' )->{ret}[0],       'repository',    'track repository' );
    $self->eq_or_die( $self->lib_call( 'config', 'source', 'aapp.nonexistent' )->{ret}[0],       undef,           'unset key source is undef' );
    return 1;
}

sub test_multivalued_highest_level_wins
{
    my ($self) = @_;
    my $sys_dir  = "$self->{scratch}/sys_test6";
    my $user_dir = "$self->{scratch}/user_test6";

    write_conf( $sys_dir,  "[aapp]\nallowPath = /sys/p1\nallowPath = /sys/p2\n" );
    write_conf( $user_dir, "[aapp]\nallowPath = /user/p1\n" );
    $self->ok_cmd( 'git', 'config', '--add', 'aapp.allowPath', '/repo/p1' );

    local $ENV{AAPP_SYS_CONF_DIR}  = $sys_dir;
    local $ENV{AAPP_USER_CONF_DIR} = $user_dir;

    my @paths = @{ $self->lib_call( 'config', 'get_all', 'aapp.allowPath' )->{ret} };
    $self->eq_or_die( scalar(@paths), 2, 'multi-valued key takes entire set from highest level' );
    $self->eq_or_die( $paths[0], '/sys/p1', 'first path from system' );
    $self->eq_or_die( $paths[1], '/sys/p2', 'second path from system' );
    return 1;
}

sub test_disallowed_key_refusal
{
    my ($self) = @_;
    my $sys_dir  = "$self->{scratch}/sys_disallowed";
    my $user_dir = "$self->{scratch}/user_empty7";
    File::Path::make_path($user_dir);
    write_conf( $sys_dir, "[aapp]\nplanId = 999\n" );

    local $ENV{AAPP_SYS_CONF_DIR}  = $sys_dir;
    local $ENV{AAPP_USER_CONF_DIR} = $user_dir;

    my $r = $self->lib_call( 'config', 'load' );
    $self->eq_or_die( $r->{ret}[0], RETURN_ERROR, 'refuses disallowed key in upper-level config' );
    $self->match_or_die( $r->{err}, qr/Config Refusal.*aapp\.planid.*not allowed/i, 'diagnostic names refusal and key' );
    $self->match_or_die( $r->{err}, qr/line 2/i, 'diagnostic names line number' );
    return 1;
}

sub test_malformed_syntax_refusal
{
    my ($self) = @_;
    my $sys_dir  = "$self->{scratch}/sys_malformed";
    my $user_dir = "$self->{scratch}/user_empty8";
    File::Path::make_path($user_dir);
    write_conf( $sys_dir, "[aapp\ngovernance = hitl\n" );

    local $ENV{AAPP_SYS_CONF_DIR}  = $sys_dir;
    local $ENV{AAPP_USER_CONF_DIR} = $user_dir;

    my $r = $self->lib_call( 'config', 'load' );
    $self->eq_or_die( $r->{ret}[0], RETURN_ERROR, 'refuses malformed syntax' );
    $self->match_or_die( $r->{err}, qr/line 1: malformed section header/i, 'diagnostic names line 1 malformed header' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
