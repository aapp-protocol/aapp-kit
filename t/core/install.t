package AAPP::T::Core::Install;

use strict;
use warnings;
use utf8;
use 5.026;

use Cwd ();
use File::Compare ();
use File::Copy ();
use File::Path ();
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/install.md. Run alone: prove -l t/core/install.t

# The kit's governance skills.
our @SKILLS = qw(aapp-status aapp-digest aapp-freeze aapp-start aapp-done aapp-pause aapp-release aapp-plan aapp-tdd aapp-fix plan);

# What a kit clone holds, when the kit has it.
our @CLONE_PARTS = qw(lib templates tests examples docs COOKBOOK.md MANUAL.md);

# A path with only the system's binaries: no aapp, and the bin directory not on it.
our $SYSTEM_PATH = '/usr/bin:/bin';

# Tests that install or copy the kit several times.
our %TIMEOUT = map { ( $_ => 240 ) } qw(test_install_keeps_folders_it_must_not_consume test_installed_kit_runs_from_path
    test_develop_hook_seeding test_install_after_develop test_install_copies_examples_and_docs test_test_verb_runs_a_named_suite
    test_front_door_repository_check test_init_seeds_settings_only_when_absent);

# Usage     : own_sandbox()
# Purpose   : This file moves the installed kit's library aside for a moment, so it gets a sandbox of its own.
# Returns   : 1
sub own_sandbox { return 1; }

# Usage     : my $text = trim($text)
# Purpose   : Output without its final whitespace.
# Returns   : The text.
sub trim { my ($text) = @_; return $text =~ s/\s+\z//r; }

# Usage     : my $path = here($name)
# Purpose   : A path in the test's folder.
# Returns   : The absolute path.
sub here { my ($name) = @_; return Cwd::getcwd() . "/$name"; }

# Usage     : my $version = kit_version($self)
# Purpose   : The kit's version, as its aapp declares it.
# Returns   : The version.
sub kit_version { my ($self) = @_; return AAPP::Tests::read_text("$self->{kit}/aapp") =~ /^AAPP_VERSION="(.*)"$/m ? $1 : ''; }

# Usage     : my $dir = project($self, $name)
# Purpose   : A repository in ./<name> with main.py committed.
# Returns   : Its absolute path.
sub project
{
    my ( $self, $name ) = @_;
    my $dir = here($name);
    File::Path::make_path($dir);
    $self->in_dir(
        $dir,
        sub {
            $self->init_repo();
            AAPP::Tests::write_text( 'main.py', "print('hello')\n" );
            $self->ok_cmd( 'git', 'add', 'main.py' );
            $self->ok_cmd( 'git', 'commit', '-qm', 'initial commit' );
        }
    );
    return $dir;
}

# Usage     : my $dir = kit_clone($self, $name)
# Purpose   : A copy of the kit in ./<name>, committed as a repository of its own.
# Returns   : Its absolute path.
sub kit_clone
{
    my ( $self, $name ) = @_;
    my $dir = here($name);
    File::Path::make_path($dir);
    File::Copy::copy( "$self->{kit}/aapp", "$dir/aapp" ) or die "cannot copy aapp: $!\n";
    chmod( 0755, "$dir/aapp" ) or die "cannot chmod aapp: $!\n";
    foreach my $part (@CLONE_PARTS) {
        my $src = "$self->{kit}/$part";
        if ( -d $src ) {
            AAPP::Tests::copy_tree( $src, "$dir/$part" );
        } elsif ( -f $src ) {
            File::Copy::copy( $src, "$dir/$part" ) or die "cannot copy $part: $!\n";
        }
    }
    $self->in_dir(
        $dir,
        sub {
            $self->init_repo();
            $self->ok_cmd( 'git', 'add', '.' );
            $self->ok_cmd( 'git', 'commit', '-qm', 'kit clone' );
        }
    );
    return $dir;
}

# Usage     : my $r = run_in($self, $dir, \%env, @command)
# Purpose   : Runs a command in a folder, with environment variables set for it.
# Returns   : { exit, out, err, all }.
sub run_in
{
    my ( $self, $dir, $env, @cmd ) = @_;
    local @ENV{ keys %{$env} } = values %{$env};
    my $r = $self->in_dir( $dir, sub { $self->run_cmd(@cmd) } );
    $r->{all} = $r->{out} . $r->{err};
    return $r;
}

# Usage     : my %env = home_env($home, $path)
# Purpose   : The environment of a separate home: HOME, its share directory, and PATH when given.
# Returns   : The variables.
sub home_env
{
    my ( $home, $path ) = @_;
    return ( HOME => $home, XDG_DATA_HOME => "$home/.local/share", defined $path ? ( PATH => $path ) : () );
}

# Usage     : my $home = new_home($name)
# Purpose   : An empty home folder.
# Returns   : Its path.
sub new_home { my ($name) = @_; my $home = here($name); File::Path::make_path($home); return $home; }

# Usage     : my $r = init_in($self, $dir)
# Purpose   : Runs aapp init in a folder.
# Returns   : { exit, out, err, all }.
sub init_in { my ( $self, $dir ) = @_; return run_in( $self, $dir, {}, 'aapp', 'init' ); }

# Usage     : orphan_branch($self, $dir, $branch, \%files)
# Purpose   : Commits the files on a new orphan branch of the project, then returns to main.
# Returns   : 1
sub orphan_branch
{
    my ( $self, $dir, $branch, $files ) = @_;
    $self->in_dir(
        $dir,
        sub {
            my $back = trim( $self->ok_cmd( 'git', 'rev-parse', '--abbrev-ref', 'HEAD' )->{out} );
            $self->ok_cmd( 'git', 'checkout', '--orphan', $branch, '-q' );
            $self->run_cmd( 'git', 'rm', '-rf', '.', '-q' );
            foreach my $file ( sort keys %{$files} ) {
                my ($folder) = $file =~ m{^(.*)/};
                File::Path::make_path($folder) if defined $folder;
                AAPP::Tests::write_text( $file, $files->{$file} );
            }
            $self->ok_cmd( 'git', 'add', '.' );
            $self->ok_cmd( 'git', 'commit', '-qm', "$branch branch" );
            $self->ok_cmd( 'git', 'checkout', $back, '-q' );
        }
    );
    return 1;
}

# Usage     : put($path, $text)
# Purpose   : Writes a file, making its folder first.
# Returns   : 1
sub put
{
    my ( $path, $text ) = @_;
    my ($folder) = $path =~ m{^(.*)/};
    File::Path::make_path($folder) if defined $folder;
    return AAPP::Tests::write_text( $path, $text );
}

# Usage     : my $text = text($path)
# Purpose   : A file's text.
# Returns   : The text.
sub text { my ($path) = @_; return AAPP::Tests::read_text($path); }

sub test_version_and_help
{
    my ($self) = @_;
    my $want = 'aapp version ' . kit_version($self);
    $self->eq_or_die( trim( $self->ok_cmd( "$self->{kit}/aapp", $_ )->{out} ), $want, "aapp $_" ) for qw(version -v --version);
    my $help = $self->ok_cmd( "$self->{kit}/aapp", 'help' )->{out};
    $self->true_or_die( $help =~ /Usage: aapp <command>/ && $help =~ /init/ && $help =~ /upgrade/, 'aapp help prints the catalog', $help );
    return 1;
}

sub test_init_confinement
{
    my ($self) = @_;
    my $self_kit = kit_clone( $self, 'kit_self' );
    $self->eq_or_die( run_in( $self, $self_kit, {}, './aapp', 'init' )->{exit}, 0, 'an uninstalled kit clone initializes itself' );
    $self->true_or_die( -d "$self_kit/$_", "it has $_" ) for qw(.plans .agents .githooks);
    my $proj = project( $self, 't_ext_proj' );
    my $kit  = kit_clone( $self, 't_ext_kit' );
    $self->match_or_die( run_in( $self, $proj, {}, "$kit/aapp", 'init' )->{all}, qr/AAPP must be installed globally before initializing projects/,
        'an uninstalled clone refuses another project' );
    my $none = here('non_git_dir');
    File::Path::make_path($none);
    $self->match_or_die( run_in( $self, $none, {}, 'aapp', 'init' )->{all}, qr/must be run inside a Git repository/, 'init outside a repository fails' );
    return 1;
}

sub test_agents_protocol_block_adopt_upgrade_migrate
{
    my ($self) = @_;
    my $start = '<!-- AAPP-PROTOCOL:START v' . kit_version($self) . ' -->';

    my $p7 = project( $self, 't7_proj' );
    orphan_branch( $self, $p7, 'agents', { 'AGENTS.md' => "# Custom Project Rules (No Markers)\nrule 1: always write tests\n" } );
    init_in( $self, $p7 );
    my $agents = text("$p7/.agents/AGENTS.md");
    $self->true_or_die( index( $agents, $start ) >= 0 && index( $agents, '# Custom Project Rules (No Markers)' ) >= 0, 'an unmanaged AGENTS.md gets the block appended', $agents );

    my $p8 = project( $self, 't8_proj' );
    orphan_branch(
        $self, $p8, 'agents',
        {   'AGENTS.md' => "# Project Custom Rules\nCustom rule: always use snake_case for functions.\n\n<!-- AAPP-PROTOCOL:START v0.0.1 -->\n"
                . "Old protocol block v0.0.1 content that should be replaced.\n<!-- AAPP-PROTOCOL:END -->\n\n# Post-Protocol Custom Rules\nCustom rule: enforce 80 chars max line length.\n"
        }
    );
    init_in( $self, $p8 );
    $agents = text("$p8/.agents/AGENTS.md");
    $self->true_or_die(
        index( $agents, $start ) >= 0
            && index( $agents, 'Custom rule: always use snake_case for functions.' ) >= 0
            && index( $agents, 'Custom rule: enforce 80 chars max line length.' ) >= 0
            && index( $agents, 'Old protocol block v0.0.1 content' ) < 0,
        'an old block is upgraded in place, the rules around it kept', $agents
    );

    my $p9 = project( $self, 't9_proj' );
    AAPP::Tests::write_text( "$p9/AGENTS.md", "# Legacy Root AGENTS File\n" );
    init_in( $self, $p9 );
    $agents = text("$p9/.agents/AGENTS.md");
    $self->true_or_die( !-e "$p9/AGENTS.md" && index( $agents, '# Legacy Root AGENTS File' ) >= 0 && index( $agents, $start ) >= 0,
        'a root AGENTS.md moves into .agents/', $agents );

    my $p10 = project( $self, 't10_proj' );
    AAPP::Tests::write_text( "$p10/CODEMAP.md",      "# User Custom CODEMAP\n" );
    AAPP::Tests::write_text( "$p10/ARCHITECTURE.md", "# User Custom ARCHITECTURE\n" );
    init_in( $self, $p10 );
    $self->eq_or_die( text("$p10/.agents/CODEMAP.md"), "# User Custom CODEMAP\n",      'a root CODEMAP.md is kept in .agents/' );
    $self->eq_or_die( text("$p10/ARCHITECTURE.md"),    "# User Custom ARCHITECTURE\n", 'ARCHITECTURE.md is kept' );
    return 1;
}

sub test_init_installs_hook_engines
{
    my ($self) = @_;
    my $p = project( $self, 't11_proj' );
    orphan_branch( $self, $p, 'githooks',
        { 'pre-commit' => "#!/usr/bin/env bash\n# Custom Project Perl / Linter Hook\nperl -e 'print \"custom check\\n\"' || exit 1\n", 'blast-radius-guard' => "# old guard\n" } );
    init_in( $self, $p );
    $self->true_or_die( -x "$p/.githooks/$_", "$_ is executable" ) for qw(aapp-pre-commit blast-radius-guard pre-commit);
    my $hook = text("$p/.githooks/pre-commit");
    $self->true_or_die( $hook =~ /custom check/ && $hook =~ /aapp-pre-commit/, 'the custom pre-commit is kept and wired', $hook );
    my $installed = "$ENV{XDG_DATA_HOME}/aapp-kit/lib/aapp-lib.sh";
    $self->true_or_die( -f "$p/.githooks/aapp-lib.sh" && !-l "$p/.githooks/aapp-lib.sh" && File::Compare::compare( "$p/.githooks/aapp-lib.sh", $installed ) == 0,
        'the library is installed as a real file' );

    my $p2   = project( $self, 't11b_proj' );
    my $away = here('aapp-lib.sh.away');
    rename( $installed, $away ) or die "cannot move the library aside: $!\n";
    my $r = eval { init_in( $self, $p2 ) };
    my $error = $@;
    rename( $away, $installed ) or die "cannot put the library back: $!\n";
    die $error if $error;
    $self->true_or_die( $r->{exit} != 0 && $r->{all} =~ /aapp-lib\.sh/ && $r->{all} =~ /Detected OS/, 'a kit without the library fails loudly', $r->{all} );
    return 1;
}

sub test_claude_settings_merged
{
    my ($self) = @_;
    my $p12 = project( $self, 't12_proj' );
    init_in( $self, $p12 );
    $self->match_or_die( text("$p12/.claude/settings.json"), qr/blast-radius-guard/, 'a fresh init writes the guard' );
    my $p13 = project( $self, 't13_proj' );
    File::Path::make_path("$p13/.claude");
    AAPP::Tests::write_text( "$p13/.claude/settings.json",
        qq({\n  "userCustomSetting": true,\n  "hooks": {\n    "PostToolUse": [\n      {\n        "matcher": ".*",\n        "hooks": [{"type": "command", "command": "echo done"}]\n      }\n    ]\n  }\n}\n) );
    init_in( $self, $p13 );
    my $settings = text("$p13/.claude/settings.json");
    $self->true_or_die( $settings =~ /"userCustomSetting": true/ && $settings =~ /blast-radius-guard/ && $settings =~ /PostToolUse/, 'existing settings are merged', $settings );
    init_in( $self, $p13 );
    $self->eq_or_die( scalar( () = text("$p13/.claude/settings.json") =~ /blast-radius-guard/g ), 1, 'a rerun adds no duplicate' );
    return 1;
}

sub test_hooks_path_interop
{
    my ($self) = @_;
    my $warn  = 'existing hook configuration was detected';
    my $hooks = sub { my ($dir) = @_; return trim( run_in( $self, $dir, {}, 'git', 'config', '--get', 'core.hooksPath' )->{out} ); };

    my $p15 = project( $self, 't15_proj' );
    my $out = init_in( $self, $p15 )->{all};
    $self->true_or_die( $hooks->($p15) eq '.githooks' && index( $out, $warn ) < 0, 'an unset hooks path is set quietly', $out );

    my $p16 = project( $self, 't16_proj' );
    run_in( $self, $p16, {}, 'git', 'config', 'core.hooksPath', '.githooks' );
    $out = init_in( $self, $p16 )->{all};
    $self->true_or_die( $hooks->($p16) eq '.githooks' && index( $out, $warn ) < 0, 'the kit hooks path is left quietly', $out );

    my $p17 = project( $self, 't17_proj' );
    run_in( $self, $p17, {}, 'git', 'config', 'core.hooksPath', '.husky' );
    $out = init_in( $self, $p17 )->{all};
    $self->true_or_die( $hooks->($p17) eq '.husky' && -f "$p17/.githooks/pre-commit" && index( $out, q{core.hooksPath is currently set to: '.husky'} ) >= 0,
        'a foreign hooks path is left, with the wiring line', $out );

    my $p18 = project( $self, 't18_proj' );
    AAPP::Tests::write_text( "$p18/.git/hooks/pre-commit", "#!/bin/sh\n" );
    chmod( 0755, "$p18/.git/hooks/pre-commit" ) or die "cannot chmod: $!\n";
    $out = init_in( $self, $p18 )->{all};
    $self->true_or_die( $hooks->($p18) eq '' && index( $out, q{Executable hook found at '.git/hooks/pre-commit'} ) >= 0, 'an executable .git/hooks/pre-commit is left, with the wiring line', $out );

    my $p19 = project( $self, 't19_proj' );
    File::Path::make_path("$p19/.husky");
    AAPP::Tests::write_text( "$p19/.husky/pre-commit", "#!/bin/sh\n\"\$(git rev-parse --show-toplevel)/.githooks/pre-commit\" || exit 1\n" );
    chmod( 0755, "$p19/.husky/pre-commit" ) or die "cannot chmod: $!\n";
    run_in( $self, $p19, {}, 'git', 'config', 'core.hooksPath', '.husky' );
    init_in( $self, $p19 );
    File::Path::make_path("$p19/.plans/current");
    AAPP::Tests::write_text( "$p19/.plans/current/plan.md",
        "## 💥 4. Blast Radius & System Boundaries\n### 📂 Target Files (Modifications & Additions)\n- [ ] `a.py` -> modify\n### 🛑 Out of Bounds (Do Not Touch)\n" );
    AAPP::Tests::write_text( "$p19/forbidden.py", "unauthorized\n" );
    run_in( $self, $p19, {}, 'git', 'add', 'forbidden.py' );
    $self->true_or_die( run_in( $self, $p19, {}, 'git', 'commit', '-m', 'violating commit' )->{exit} != 0, 'the wired custom hook refuses a violation' );
    return 1;
}

sub test_init_collisions_and_restore
{
    my ($self) = @_;
    my $p21 = project( $self, 't21_proj' );
    File::Path::make_path("$p21/templates");
    AAPP::Tests::write_text( "$p21/templates/index.html", "<h1>Flask App</h1>\n" );
    init_in( $self, $p21 );
    $self->file_exists_or_die("$p21/templates/index.html");

    my $p22 = project( $self, 't22_proj' );
    File::Path::make_path("$p22/.plans");
    AAPP::Tests::write_text( "$p22/.plans/custom.txt", "custom non-worktree content\n" );
    $self->match_or_die( init_in( $self, $p22 )->{all}, qr/exists as a normal directory, not an AAPP worktree/, 'a plain .plans/ is refused' );

    my $remote = project( $self, 't23_remote' );
    orphan_branch( $self, $remote, 'plans', { 'current/p.md' => "# Remote Plan\n" } );
    my $local = here('t23_local');
    $self->ok_cmd( 'git', 'clone', '-q', $remote, $local );
    my $r = init_in( $self, $local );
    $self->eq_or_die( $r->{exit}, 0, 'init in a clone succeeds', $r->{all} );
    $self->file_exists_or_die("$local/.plans/current/p.md");
    return 1;
}

# Usage     : my ($home, $r) = install_into($self, $name)
# Purpose   : Installs a fresh kit clone ./<name>_installer into the new home ./<name>_home.
# Returns   : (the home, the install's result).
sub install_into
{
    my ( $self, $name, $path ) = @_;
    my $home      = new_home("${name}_home");
    my $installer = kit_clone( $self, "${name}_installer" );
    my $r         = run_in( $self, $installer, { home_env( $home, $path ) }, './aapp', 'install' );
    return ( $home, $r, $installer );
}

sub test_install_creates_and_consumes
{
    my ($self) = @_;
    my ( $home, $r, $installer ) = install_into( $self, 't24' );
    my $share = "$home/.local/share/aapp-kit";
    $self->eq_or_die( $r->{exit}, 0, 'install succeeds', $r->{all} );
    $self->true_or_die( -x "$home/.local/bin/aapp", 'the binary is installed' );
    $self->file_exists_or_die("$share/$_") for qw(templates/pre-commit lib/cmd_init.sh);
    my $link = "$share/templates/aapp-lib.sh";
    $self->true_or_die( -l $link && readlink($link) eq '../lib/aapp-lib.sh' && File::Compare::compare( $link, "$share/lib/aapp-lib.sh" ) == 0, 'the template library link is kept' );
    $self->true_or_die( !-d $installer, 'the installer clone is consumed' );
    return 1;
}

sub test_install_keeps_folders_it_must_not_consume
{
    my ($self) = @_;
    my $home = new_home('t25b_home');
    my $kit  = kit_clone( $self, 't25b_installer' );
    my $r    = run_in( $self, $kit, { home_env($home) }, './aapp', 'install', '--keep' );
    $self->true_or_die( $r->{all} =~ /Unknown option '--keep'/ && -d $kit, '--keep is refused, the folder kept', $r->{all} );

    $home = new_home('t25c_home');
    $kit  = kit_clone( $self, 't25c_installer' );
    AAPP::Tests::write_text( "$kit/user_data.txt", '' );
    $r = run_in( $self, $kit, { home_env($home) }, './aapp', 'install' );
    $self->true_or_die( $r->{exit} == 0 && -f "$kit/user_data.txt", 'a folder with extra files is kept', $r->{all} );

    $home = new_home('t25d_home');
    $kit  = kit_clone( $self, 't25d_installer' );
    AAPP::Tests::write_text( "$kit/templates/pre-commit", text("$kit/templates/pre-commit") . "# uncommitted change\n" );
    $r = run_in( $self, $kit, { home_env($home) }, './aapp', 'install' );
    $self->true_or_die( $r->{exit} == 0 && -d $kit, 'a folder with uncommitted changes is kept', $r->{all} );

    $home = new_home('t25e_home');
    my $parent = kit_clone( $self, 't25e_parent' );
    my $wt     = here('t25e_wt');
    run_in( $self, $parent, {}, 'git', 'worktree', 'add', $wt, '-b', 'wt_branch', '-q' );
    $r = run_in( $self, $wt, { home_env($home) }, './aapp', 'install' );
    $self->true_or_die( $r->{exit} == 0 && -d $wt && -f "$wt/.git", 'a linked worktree is kept', $r->{all} );
    return 1;
}

sub test_installed_kit_runs_from_path
{
    my ($self) = @_;
    my ( $home, $r ) = install_into( $self, 't26' );
    $self->eq_or_die( $r->{exit}, 0, 'install succeeds', $r->{all} );
    my $share = "$home/.local/share/aapp-kit";
    $self->true_or_die( -d "$share/tests" && -f "$share/lib/cmd_status.sh", 'the installed kit holds lib/ and tests/' );
    my $p   = project( $self, 't27_proj' );
    my %env = home_env( $home, "$home/.local/bin:$ENV{PATH}" );
    $r = run_in( $self, $p, \%env, 'aapp', 'init' );
    $self->true_or_die( $r->{exit} == 0 && -d "$p/.plans" && -d "$p/.agents" && -x "$home/.local/bin/aapp", 'aapp init runs from the path', $r->{all} );
    my $kit = kit_clone( $self, 't28_kit' );
    $r = run_in( $self, $kit, \%env, './aapp', 'install' );
    $self->match_or_die( $r->{all}, qr/is already in your PATH/, 'a bin directory on the path is reported' );
    return 1;
}

sub test_install_fresh_bin_advises_relogin
{
    my ($self) = @_;
    my ( $home, $r ) = install_into( $self, 't29', $SYSTEM_PATH );
    $self->true_or_die( $r->{all} =~ /logging out and/ && $r->{all} =~ /back in will automatically add it/, 'advice to log in again', $r->{all} );
    $self->true_or_die( !-e "$home/.bashrc" && !-e "$home/.profile", 'no rc file is written' );
    return 1;
}

sub test_uninstall_leaves_no_trace
{
    my ($self) = @_;
    my $home = new_home('t30_home');
    my $rc   = qq{export PATH="\$HOME/.local/bin:\$PATH"\n};
    AAPP::Tests::write_text( "$home/.bashrc", $rc );
    my $kit = kit_clone( $self, 't30_installer' );
    run_in( $self, $kit, { home_env( $home, $SYSTEM_PATH ) }, './aapp', 'install' );
    my $r = run_in( $self, Cwd::getcwd(), { home_env( $home, $SYSTEM_PATH ) }, "$home/.local/bin/aapp", 'uninstall' );
    $self->eq_or_die( $r->{exit}, 0, 'uninstall succeeds', $r->{all} );
    $self->true_or_die( !-e "$home/.local/bin/aapp" && !-e "$home/.local/share/aapp-kit", 'the binary and the share directory are gone' );
    $self->true_or_die( -d "$home/.local/bin" && -d "$home/.local/share", 'the shared directories stay' );
    $self->eq_or_die( text("$home/.bashrc"), $rc, 'the rc file is untouched' );
    return 1;
}

sub test_status_prints_four_pillars
{
    my ($self) = @_;
    my $p = project( $self, 't31_proj' );
    init_in( $self, $p );
    my $out = run_in( $self, $p, {}, 'aapp', 'status' )->{all};
    $self->match_or_die( $out, qr/\Q$_\E/, "the $_ pillar" ) for 'SHIPPED', 'ISSUES', 'PLANS', 'PICKUP QUEUE';
    return 1;
}

sub test_install_keeps_develop_kit_folder
{
    my ($self) = @_;
    my $kit  = kit_clone( $self, 'aapp-develop-kit' );
    my $home = new_home('t32_home');
    run_in( $self, $kit, { home_env( $home, $SYSTEM_PATH ) }, './aapp', 'install' );
    $self->true_or_die( -d $kit && -f "$kit/aapp", 'the develop folder is kept' );
    return 1;
}

sub test_unclosed_protocol_marker_preserves_file
{
    my ($self) = @_;
    my $p = project( $self, 't33_proj' );
    init_in( $self, $p );
    AAPP::Tests::write_text( "$p/.agents/AGENTS.md",
        "# Custom Header\n<!-- AAPP-PROTOCOL:START v1.0.0 -->\nSome content that was not closed properly\n# Important custom notes that must not be deleted\n" );
    my $out = init_in( $self, $p )->{all};
    $self->true_or_die( index( $out, 'Found unclosed <!-- AAPP-PROTOCOL:START --> marker' ) >= 0, 'the unclosed block is reported', $out );
    $self->match_or_die( text("$p/.agents/AGENTS.md"), qr/Important custom notes that must not be deleted/, 'the file is left intact' );
    return 1;
}

sub test_develop_links_live_clone
{
    my ($self) = @_;
    my $home = new_home('t34_home');
    my $kit  = kit_clone( $self, 't34_dev_kit' );
    my $r    = run_in( $self, $kit, { home_env( $home, $SYSTEM_PATH ) }, './aapp', 'develop' );
    my $share = "$home/.local/share/aapp-kit";
    $self->true_or_die( -l "$home/.local/bin/aapp" && -l $share, 'the binary and the share directory are links', $r->{all} );
    AAPP::Tests::write_text( "$kit/lib/cmd_status.sh", text("$kit/lib/cmd_status.sh") . "# test_live_marker=1\n" );
    $self->match_or_die( text("$share/lib/cmd_status.sh"), qr/test_live_marker=1/, 'an edit in the clone is live' );
    $self->true_or_die( -d $kit, 'the clone is not consumed' );
    return 1;
}

sub test_develop_hook_seeding
{
    my ($self) = @_;
    my $home  = new_home('t34b_home');
    my $kit   = kit_clone( $self, 't34b_dev_kit' );
    my %env   = home_env( $home, $SYSTEM_PATH );
    my $block = qr/^# >>> aapp-pre-commit-develop \(P-34\) >>>$/m;
    init_in( $self, $kit );
    $self->true_or_die( -d "$kit/.githooks" && !-e "$kit/.githooks/aapp-pre-commit-develop", 'absent after init' );
    run_in( $self, $kit, \%env, './aapp', 'develop' );
    my $first = text("$kit/.githooks/pre-commit");
    $self->true_or_die( -x "$kit/.githooks/aapp-pre-commit-develop" && scalar( () = $first =~ /$block/g ) == 1, 'seeded once by develop', $first );
    run_in( $self, $kit, \%env, './aapp', 'develop' );
    $self->eq_or_die( text("$kit/.githooks/pre-commit"), $first, 'a second develop changes nothing' );
    run_in( $self, $kit, \%env, './aapp', 'uninstall' );
    $self->true_or_die( !-e "$kit/.githooks/aapp-pre-commit-develop" && text("$kit/.githooks/pre-commit") !~ /aapp-pre-commit-develop/,
        'uninstall removes the engine and its wrapper block' );
    return 1;
}

sub test_install_after_develop
{
    my ($self) = @_;
    my $home = new_home('t35_home');
    my $dev  = kit_clone( $self, 't35_dev_kit' );
    my %env  = home_env( $home, $SYSTEM_PATH );
    run_in( $self, $dev, \%env, './aapp', 'develop' );
    my $installer = kit_clone( $self, 't35_installer' );
    run_in( $self, $installer, \%env, './aapp', 'install' );
    my $share = "$home/.local/share/aapp-kit";
    $self->true_or_die( -f "$dev/lib/cmd_init.sh", 'the develop source is kept' );
    $self->true_or_die( -d $share && !-l $share && !-l "$home/.local/bin/aapp", 'the links are replaced with copies' );
    return 1;
}

sub test_uninstall_cleans_dangling_links
{
    my ($self) = @_;
    my $home = new_home('t36_home');
    my $kit  = kit_clone( $self, 't36_dev_kit' );
    my %env  = home_env( $home, $SYSTEM_PATH );
    run_in( $self, $kit, \%env, './aapp', 'develop' );
    File::Path::remove_tree($kit);
    my $outside = here('t36_outside');
    File::Path::make_path($outside);
    my $r = run_in( $self, $outside, \%env, "$self->{kit}/aapp", 'uninstall' );
    $self->true_or_die( !-e "$home/.local/bin/aapp" && !-l "$home/.local/bin/aapp", 'the binary link is gone', $r->{all} );
    $self->true_or_die( !-e "$home/.local/share/aapp-kit" && !-l "$home/.local/share/aapp-kit", 'the share link is gone', $r->{all} );
    $self->match_or_die( $r->{all}, qr/Removed/, 'saying so' );
    return 1;
}

sub test_claude_settings_decoupled
{
    my ($self) = @_;
    my $p = project( $self, 't37_proj' );
    init_in( $self, $p );
    my $link = "$p/.claude/settings.json";
    $self->true_or_die( -l $link && readlink($link) eq '../.agents/claude/settings.json' && -f "$p/.agents/claude/settings.json", 'the settings link to .agents/claude' );
    $self->match_or_die( text($link), qr/blast-radius-guard/, 'holding the guard' );
    $self->true_or_die( grep( { $_ eq '.claude/' } split( /\n/, text("$p/.gitignore") ) ), '.claude/ is ignored on the code branch' );
    return 1;
}

sub test_skills_installed_and_bridged
{
    my ($self) = @_;
    my $p = project( $self, 't39_proj' );
    init_in( $self, $p );
    foreach my $skill (@SKILLS) {
        my $link = "$p/.claude/skills/$skill";
        $self->true_or_die( -f "$p/.agents/skills/$skill/SKILL.md" && -l $link && readlink($link) eq "../../.agents/skills/$skill" && -s "$link/SKILL.md",
            "$skill is installed and bridged" );
    }
    my $p40 = project( $self, 't40_proj' );
    File::Path::make_path("$p40/.claude/skills/custom-deploy");
    AAPP::Tests::write_text( "$p40/.claude/skills/custom-deploy/SKILL.md", "# Custom Deploy\n" );
    AAPP::Tests::write_text( "$p40/.claude/settings.local.json",           qq({"localSecret": "123"}\n) );
    init_in( $self, $p40 );
    $self->true_or_die( !-l "$p40/.claude/skills/custom-deploy" && text("$p40/.claude/skills/custom-deploy/SKILL.md") =~ /Custom Deploy/, "a user's skill is kept" );
    $self->match_or_die( text("$p40/.claude/settings.local.json"), qr/localSecret/, 'local settings are kept' );
    my $p41 = project( $self, 't41_proj' );
    init_in( $self, $p41 );
    AAPP::Tests::write_text( "$p41/.agents/skills/aapp-status/stale-old-file.txt", '' );
    init_in( $self, $p41 );
    $self->true_or_die( !-e "$p41/.agents/skills/aapp-status/stale-old-file.txt" && -f "$p41/.agents/skills/aapp-status/SKILL.md", 'stale files go on resync' );
    return 1;
}

sub test_skill_frontmatter
{
    my ($self) = @_;
    my $dir = "$self->{kit}/templates/skills";
    foreach my $skill (@SKILLS) {
        my $t = text("$dir/$skill/SKILL.md");
        $self->true_or_die( $t =~ /^name: \Q$skill\E$/m && $t =~ /^description: /m && $t =~ /^disable-model-invocation: false$/m, "$skill has its frontmatter" );
    }
    $self->true_or_die( !-e "$dir/$_/SKILL.md", "the retired $_ is gone" ) for qw(aapp-freeze-start aapp-active aapp-hooks);
    $self->match_or_die( text("$dir/aapp-release/SKILL.md"), qr/^context: fork$/m, 'aapp-release runs in a fork' );
    $self->true_or_die( text("$dir/$_/SKILL.md") !~ /context: fork/, "$_ runs inline" ) for qw(aapp-digest aapp-status);
    $self->match_or_die( text("$dir/plan/SKILL.md"), qr/aapp-plan/, 'plan delegates to aapp-plan' );
    my $fix = text("$dir/aapp-fix/SKILL.md");
    $self->true_or_die( index( $fix, $_ ) >= 0, "aapp-fix names '$_'" )
        for 'aapp issue fix next-blocker', 'aapp issue fix <num>', 'aapp commit', 'aapp issue close <num>', 'aapp issue fix <num> abort', 'Fail Closed';
    return 1;
}

sub test_init_issue_ledgers
{
    my ($self) = @_;
    my $p = project( $self, 't43_proj' );
    init_in( $self, $p );
    my $archive = text("$p/.plans/done/000-issues-archive.md");
    $self->true_or_die( $archive =~ /Master Issue Archive Ledger/ && index( $archive, '| Date Opened | Date Resolved |' ) >= 0, 'init provides the issue archive' );
    my $p44 = project( $self, 't44_proj' );
    AAPP::Tests::write_text( "$p44/ISSUES.md", "# Custom Jira Export\n- ISSUE-1234: Custom issue description in prose format\n" );
    run_in( $self, $p44, {}, 'git', 'add', 'ISSUES.md' );
    run_in( $self, $p44, {}, 'git', 'commit', '-qm', 'add custom issues' );
    my $out = init_in( $self, $p44 )->{all};
    $self->match_or_die( text("$p44/.plans/ISSUES.md"), qr/Custom Jira Export/, 'a custom ISSUES.md is kept' );
    $self->match_or_die( $out, qr{Found existing custom \.plans/ISSUES\.md}, 'with a notice' );
    return 1;
}

sub test_template_shapes
{
    my ($self) = @_;
    my $t = "$self->{kit}/templates";
    my $issues = text("$t/issues.md");
    $self->true_or_die( $issues !~ /^## /m, 'the issue table has no subheadings' );
    $self->true_or_die( index( $issues, '| # | Sev | Type | Date | Location | Symptom / Problem | Target Plan / Fix | Status |' ) >= 0, 'and its eight columns' );
    $self->match_or_die( text("$t/plan-template.md"),     qr/\* \*\*Plan ID:\*\* P-XX/, 'the plan template has its Plan ID' );
    $self->match_or_die( text("$t/000-archive-ledger.md"), qr/\| Plan ID \|/,           'the archive ledger its Plan ID column' );
    $self->match_or_die( text("$t/pickup.md"),
        qr/- \[ \] Onboarding: Inspect repository codebase to populate \.agents\/CODEMAP\.md, ARCHITECTURE\.md, and \.agents\/PROJECT\.MD/, 'the pickup template its onboarding item' );
    return 1;
}

sub test_init_banner
{
    my ($self) = @_;
    my $out = init_in( $self, project( $self, 't49_proj' ) )->{all};
    $self->true_or_die( $out =~ /Experience Your First AAPP Loop/ && $out =~ /\/aapp-digest Onboarding/, 'init prints the first-loop guidance', $out );
    return 1;
}

sub test_skill_sync_and_pruning
{
    my ($self) = @_;
    my $p = project( $self, 't50_proj' );
    $self->eq_or_die( init_in( $self, $p )->{exit}, 0, 'init succeeds' );
    $self->true_or_die( -f "$p/.agents/skills/aapp-pause/SKILL.md" && -e "$p/.claude/skills/aapp-pause/SKILL.md", 'aapp-pause is installed and bridged' );
    my $pause = text("$self->{kit}/templates/skills/aapp-pause/SKILL.md");
    $self->true_or_die( $pause =~ /^name: aapp-pause/m && $pause =~ /^argument-hint:/m, 'its skill has its frontmatter' );
    my $p52 = project( $self, 't52_proj' );
    init_in( $self, $p52 );
    foreach my $retired (qw(aapp-freeze-start aapp-active)) {
        put( "$p52/$_/$retired/SKILL.md", '' ) for '.agents/skills', '.claude/skills';
    }
    put( "$p52/.agents/skills/aapp-hooks/SKILL.md", '' );
    put( "$p52/.claude/skills/aapp-hooks/SKILL.md", '' );
    put( "$p52/.agents/skills/aapp-hooks/registry.tsv", "on-sync\tcustom_handler.sh\tsha256:dummy\t10\tgate\n" );
    init_in( $self, $p52 );
    foreach my $retired (qw(aapp-freeze-start aapp-active)) {
        $self->true_or_die( !-d "$p52/.agents/skills/$retired" && !-d "$p52/.claude/skills/$retired", "$retired and its link are removed" );
    }
    $self->true_or_die( !-f "$p52/.agents/skills/aapp-hooks/SKILL.md" && !-d "$p52/.claude/skills/aapp-hooks", 'the retired aapp-hooks skill is removed' );
    $self->match_or_die( text("$p52/.agents/skills/aapp-hooks/registry.tsv"), qr/custom_handler\.sh/, 'registry.tsv is kept' );
    return 1;
}

sub test_manifest_and_help_tiers
{
    my ($self) = @_;
    my $manifest = text("$self->{kit}/lib/verbs.tsv");
    my $rows     = grep { /\S/ && !/^\s*#/ } split( /\n/, $manifest );
    $self->true_or_die( $rows >= 30, 'lib/verbs.tsv holds the verbs', $rows );
    $self->match_or_die( $manifest, qr/\Q$_\E/, "the $_ tier" ) for qw(daily setup sync hooks ai);
    my $r    = $self->run_cmd( "$self->{kit}/aapp", 'help' );
    my $help = $r->{out} . $r->{err};
    $self->match_or_die( $help, qr/\Q$_\E/, "help groups under '$_'" )
        for 'Daily Working Loop (Core):', 'Setup & Maintenance:', 'Team Sync & Emergency Controls:', 'Extensibility & Automation (Hooks & Plugins):',
        'Attribution & Metadata (AI Switchboard):';
    $self->true_or_die( $help !~ m{lib/docs/verbs/}, 'the contract column never shows' );
    $self->match_or_die( $help, qr/^  draft +Scaffold blueprint from template, stamp ID & date, register in matrix$/m, 'a verb line' );
    return 1;
}

sub test_hooks_events_catalog
{
    my ($self) = @_;
    my $out = run_in( $self, project( $self, 't57_proj' ), {}, "$self->{kit}/aapp", 'hooks', 'events' )->{all};
    $self->match_or_die( $out, qr/\Q$_\E/, "the catalog names $_" ) for 'Supported Lifecycle Events Catalog', 'pre-freeze', 'on-sync', 'post-freeze';
    return 1;
}

sub test_cheatsheet_lists_every_verb
{
    my ($self) = @_;
    my $cheatsheet = text("$self->{kit}/CHEATSHEET.md");
    my @missing;
    foreach my $line ( split( /\n/, text("$self->{kit}/lib/verbs.tsv") ) ) {
        my ($verb) = split( /\t/, $line );
        next if !defined $verb || $verb eq '' || $verb =~ /^#/;
        push @missing, $verb if index( $cheatsheet, "`aapp $verb" ) < 0 && index( $cheatsheet, "`$verb" ) < 0;
    }
    $self->true_or_die( !@missing, 'every verb is in CHEATSHEET.md', "@missing" );
    return 1;
}

sub test_install_copies_examples_and_docs
{
    my ($self) = @_;
    my $home  = new_home('t61_home');
    my $share = "$home/.local/share/aapp-kit";
    put( "$share/examples/stale/stale.txt", '' );
    my $kit = kit_clone( $self, 't61_installer' );
    run_in( $self, $kit, { home_env($home) }, './aapp', 'install' );
    $self->file_exists_or_die("$share/$_")
        for qw(examples/plugins/hello-tool/run.sample examples/hooks/registry.tsv.sample COOKBOOK.md MANUAL.md
        docs/recipes/getting-started/adopt-existing-repo.md docs/concepts/01-worktree-architecture.md docs/reference/12-git-plumbing.md);
    $self->true_or_die( !-d "$share/examples/stale", 'stale examples are dropped' );
    return 1;
}

sub test_init_installs_no_samples
{
    my ($self) = @_;
    my $p = project( $self, 't62_proj' );
    init_in( $self, $p );
    $self->true_or_die( !-d "$p/.agents/skills/$_", "no $_" ) for qw(hello-tool aapp-planid);
    $self->true_or_die( !glob("$p/.agents/skills/*.sample"), 'no sample file' );
    return 1;
}

sub test_test_verb_runs_a_named_suite
{
    my ($self) = @_;
    my $p   = project( $self, 't65_proj' );
    my $out = run_in( $self, $p, {}, "$self->{kit}/aapp", 'test', 'quiet', 'verb_contracts' )->{all};
    $self->match_or_die( $out, qr/\Q$_\E/, "the run says '$_'" ) for '1 suites selected', 'verb_contracts_test.sh', 'Test Summary: 1/1 suites passed';
    return 1;
}

sub test_front_door_repository_check
{
    my ($self) = @_;
    my $none = here('t67_nongit');
    File::Path::make_path($none);
    foreach my $verb (qw(status plan test freeze ai-status init)) {
        my $r = run_in( $self, $none, {}, "$self->{kit}/aapp", $verb );
        $self->eq_or_die( $r->{exit}, 1, "'$verb' outside a repository exits 1" );
        $self->match_or_die( $r->{all}, qr/must be run inside a Git repository/, "'$verb' says why" );
    }
    $self->eq_or_die( run_in( $self, $none, {}, "$self->{kit}/aapp", $_ )->{exit}, 0, "'$_' works outside a repository" ) for qw(version help);
    my $home = new_home('t68_home');
    my $r    = run_in( $self, $none, { HOME => $home }, "$self->{kit}/aapp", 'install' );
    $self->eq_or_die( $r->{exit}, 0, "'install' works outside a repository", $r->{all} );
    return 1;
}

sub test_init_seeds_settings_only_when_absent
{
    my ($self) = @_;
    my $config = sub { my ( $dir, $key ) = @_; return trim( run_in( $self, $dir, {}, 'git', 'config', $key )->{out} ); };
    my $set    = sub { my ( $dir, @kv ) = @_; run_in( $self, $dir, {}, 'git', 'config', @kv ); };

    my $fresh = project( $self, 't69d_proj' );
    init_in( $self, $fresh );
    my %seeded = (
        'aapp.aiAttribution' => 'none', 'aapp.changelogMode' => 'plan', 'aapp.issueFixWait' => '5', 'aapp.maxEmergencyHotfixes' => '2',
        'aapp.commitMode' => 'atomic', 'aapp.planWorktrees' => 'off', 'aapp.planBranch' => 'plan/{id}-{slug}', 'aapp.planWorktreePath' => '.workspace/{id}',
    );
    $self->eq_or_die( $config->( $fresh, $_ ), $seeded{$_}, "$_ is seeded" ) for sort keys %seeded;
    $self->eq_or_die( $config->( $fresh, 'aapp.planSession' ), '', 'aapp.planSession is never seeded' );

    my $kept = project( $self, 't69b_proj' );
    $set->( $kept, 'aapp.aiAttribution', 'notes' );
    $set->( $kept, 'aapp.changelogMode', 'commit' );
    $set->( $kept, 'aapp.issueFixWait',  '0' );
    $set->( $kept, 'aapp.commitMode',    'microcommits' );
    $set->( $kept, 'aapp.planBranch',    'feature/{num}' );
    AAPP::Tests::write_text( "$kept/.gitattributes", "*.png binary\n" );
    init_in( $self, $kept );
    init_in( $self, $kept );
    my %kept = ( 'aapp.aiAttribution' => 'notes', 'aapp.changelogMode' => 'commit', 'aapp.issueFixWait' => '0', 'aapp.commitMode' => 'microcommits', 'aapp.planBranch' => 'feature/{num}' );
    $self->eq_or_die( $config->( $kept, $_ ), $kept{$_}, "an existing $_ is kept" ) for sort keys %kept;
    my @attributes = split( /\n/, text("$kept/.gitattributes") );
    $self->eq_or_die( scalar( grep { $_ eq 'CHANGELOG.md merge=union' } @attributes ), 1, 'the union merge line is added once' );
    $self->eq_or_die( scalar( grep { $_ eq '*.png binary' } @attributes ),             1, 'existing .gitattributes lines are kept' );
    return 1;
}

sub test_init_installs_and_wires_post_rewrite
{
    my ($self) = @_;
    my $fresh = project( $self, 't69d_proj' );
    init_in( $self, $fresh );
    $self->true_or_die( -x "$fresh/.githooks/post-rewrite" && text("$fresh/.githooks/post-rewrite") =~ /aapp-post-rewrite/, 'the post-rewrite master is installed' );
    $self->true_or_die( -x "$fresh/.githooks/aapp-post-rewrite" && -f "$fresh/.githooks/commit_engine.sh", 'with its engine and the commit engine' );
    my $p = project( $self, 't69h_proj' );
    init_in( $self, $p );
    AAPP::Tests::write_text( "$p/.githooks/post-rewrite", "#!/bin/sh\necho custom-rewrite\n" );
    chmod( 0755, "$p/.githooks/post-rewrite" ) or die "cannot chmod: $!\n";
    init_in( $self, $p );
    my $hook = text("$p/.githooks/post-rewrite");
    $self->true_or_die( $hook =~ /custom-rewrite/ && $hook =~ /aapp-post-rewrite/, 'an existing hook is wired, not overwritten', $hook );
    return 1;
}

sub test_init_seeds_plan_counter_past_release_bundles
{
    my ($self) = @_;
    my $p = project( $self, 'tseed_proj' );
    init_in( $self, $p );
    put( "$p/.plans/release/v1.0.0/plans/P99-release-test.md", "# Plan P-99: Release Test\n* **Plan ID:** P-99\n* **Status:** ✅ Done\n" );
    run_in( $self, $p, {}, 'git', 'config', '--unset', 'aapp.planId' );
    init_in( $self, $p );
    $self->eq_or_die( trim( run_in( $self, $p, {}, 'git', 'config', 'aapp.planId' )->{out} ), '100', 'the counter starts past P-99' );
    return 1;
}

sub test_skills_drive_the_verbs
{
    my ($self) = @_;
    my $dir   = "$self->{kit}/templates/skills";
    my $done  = text("$dir/aapp-done/SKILL.md");
    my $freeze = text("$dir/aapp-freeze/SKILL.md");
    my $start = text("$dir/aapp-start/SKILL.md");
    $self->true_or_die( index( $done, 'aapp done' ) >= 0 && index( $done, 'sed -i' ) < 0 && index( $done, 'mv ".plans/current' ) < 0 && index( $done, 'git -C .plans commit' ) < 0,
        'aapp-done calls aapp done and edits nothing by hand' );
    $self->true_or_die( index( $freeze, 'aapp freeze' ) >= 0 && index( $freeze, 'sed -i' ) < 0 && index( $freeze, 'git -C .plans commit' ) < 0,
        'aapp-freeze calls aapp freeze and edits nothing by hand' );
    $self->true_or_die( index( $start, 'aapp start' ) >= 0 && index( $start, 'echo "<plan-id>" >' ) < 0 && index( $start, 'git -C .plans commit' ) < 0,
        'aapp-start calls aapp start and writes no buffer by hand' );
    $self->match_or_die( text("$dir/aapp-status/SKILL.md"), qr/aapp status/, 'aapp-status calls aapp status' );
    $self->match_or_die( text("$dir/aapp-digest/SKILL.md"), qr/aapp draft/,  'aapp-digest calls aapp draft' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
