package AAPP::T::Core::Integrate;

use strict;
use warnings;
use utf8;
use 5.026;

use Cwd ();
use File::Path ();
use POSIX ();
use Time::HiRes ();
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/integrate.md. Run alone: prove -l t/core/integrate.t

our $HOOKS = '.agents/skills/aapp-hooks';

# Usage     : fixture($self)
# Purpose   : An initialized project with its init files tracked, .env ignored, a develop branch, plan
#             worktrees on, microcommits, and no wait for issue fixes.
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    $self->init_project();
    AAPP::Tests::write_text( '.gitignore', AAPP::Tests::read_text('.gitignore') . ".env\n" );
    $self->ok_cmd( 'git', 'add', '-A' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'track init files', '--no-verify' );
    $self->ok_cmd( 'git', 'branch', 'develop' );
    $self->ok_cmd( 'git', 'config', 'aapp.planWorktrees', 'on' );
    $self->ok_cmd( 'git', 'config', 'aapp.commitMode',    'microcommits' );
    $self->ok_cmd( 'git', 'config', 'aapp.issueFixWait',  '0' );
    return 1;
}

# Usage     : my $text = trim($text)
# Purpose   : A command's output without its final whitespace.
# Returns   : The text.
sub trim { my ($text) = @_; return $text =~ s/\s+\z//r; }

# Usage     : my $sha = rev($self, $ref)
# Purpose   : What a ref points at.
# Returns   : The SHA, or '' when it does not exist.
sub rev { my ( $self, $ref ) = @_; my $r = $self->run_cmd( 'git', 'rev-parse', '--verify', '-q', $ref ); return $r->{exit} == 0 ? trim( $r->{out} ) : ''; }

# Usage     : my $yes = has_file($self, $ref, $path)
# Purpose   : Whether a commit holds a file.
# Returns   : 1 or ''.
sub has_file { my ( $self, $ref, $path ) = @_; return $self->run_cmd( 'git', 'cat-file', '-e', "$ref:$path" )->{exit} == 0 ? 1 : ''; }

# Usage     : my $branch = current($self)
# Purpose   : The checked-out branch.
# Returns   : Its name.
sub current { my ($self) = @_; return trim( $self->ok_cmd( 'git', 'rev-parse', '--abbrev-ref', 'HEAD' )->{out} ); }

# Usage     : my $path = pfile($id)
# Purpose   : A plan's file, current or archived.
# Returns   : The path, or undef.
sub pfile
{
    my ($id) = @_;
    my ($n) = $id =~ /([0-9]+)/;
    my ($file) = ( glob(".plans/current/P$n-*.md"), glob(".plans/done/P$n-*.md") );
    return $file;
}

# Usage     : my $wt = wt_of($id)
# Purpose   : A plan's worktree path.
# Returns   : The absolute path.
sub wt_of { my ($id) = @_; my ($n) = $id =~ /([0-9]+)/; return Cwd::getcwd() . "/.workspace/P$n"; }

# Usage     : my $r = done($self, @args)
# Purpose   : Runs aapp done.
# Returns   : { exit, out, err, all }.
sub done
{
    my ( $self, @args ) = @_;
    my $r = $self->run_cmd( 'aapp', 'done', @args );
    $r->{all} = $r->{out} . $r->{err};
    return $r;
}

# Usage     : prep($self, $file, $target, $second)
# Purpose   : Points the drafted plan's example targets at src/<target> (the second one at $second, or
#             dropped when undef), ticks its questions, and commits the plans worktree.
# Returns   : 1
sub prep
{
    my ( $self, $file, $target, $second ) = @_;
    my $text = AAPP::Tests::read_text($file);
    $text =~ s{src/path/to/file\.ext}{src/$target}g;
    if ( defined $second ) {
        $text =~ s{src/path/to/new_file\.ext}{src/$second}g;
    } else {
        $text =~ s{^.*src/path/to/new_file\.ext.*\n}{}mg;
    }
    $text =~ s/^\* \[ \] \*\*Question/* [x] **Question/mg;
    AAPP::Tests::write_text( $file, $text );
    $self->ok_cmd( 'git', '-C', '.plans', 'commit', '-qam', "prep $file" );
    return 1;
}

# Usage     : commit_in($self, $dir, $file, $text, $message)
# Purpose   : Writes a file in a checkout and commits it with aapp commit there.
# Returns   : 1
sub commit_in
{
    my ( $self, $dir, $file, $text, $message ) = @_;
    $self->in_dir(
        $dir,
        sub {
            my ($folder) = $file =~ m{^(.*)/};
            File::Path::make_path($folder) if defined $folder;
            AAPP::Tests::write_text( $file, $text );
            $self->ok_cmd( 'git', 'add', $file );
            $self->ok_cmd( 'aapp', 'commit', $message );
        }
    );
    return 1;
}

# Usage     : my $id = wt_plan($self, $name)
# Purpose   : A plan frozen and started into its worktree with src/<name>.sh committed there.
# Returns   : Its id.
sub wt_plan
{
    my ( $self, $name ) = @_;
    my $id = 'P-' . trim( $self->ok_cmd( 'git', 'config', 'aapp.planId' )->{out} );
    $self->ok_cmd( 'aapp', 'draft', $name );
    prep( $self, pfile($id), "$name.sh", "${name}_b.sh" );
    $self->ok_cmd( 'aapp', 'freeze-start', $id );
    commit_in( $self, wt_of($id), "src/$name.sh", "v=1\n", "feat: $name" );
    return $id;
}

# Usage     : on_branch($self, $branch, $file, $text, $message)
# Purpose   : Commits a file on another branch from the main checkout, then returns to its branch.
# Returns   : 1
sub on_branch
{
    my ( $self, $branch, $file, $text, $message ) = @_;
    my $back = current($self);
    $self->ok_cmd( 'git', 'checkout', '-q', $branch );
    my ($folder) = $file =~ m{^(.*)/};
    File::Path::make_path($folder) if defined $folder;
    AAPP::Tests::write_text( $file, $text );
    $self->ok_cmd( 'git', 'add', $file );
    $self->ok_cmd( 'git', 'commit', '-qm', $message, '--no-verify' );
    $self->ok_cmd( 'git', 'checkout', '-q', $back );
    return 1;
}

# Usage     : my $path = lock_path($self, $name)
# Purpose   : Where a named lock lives.
# Returns   : The path.
sub lock_path { my ( $self, $name ) = @_; return trim( $self->lib_call( 'aapp_lib', 'aapp_lock_path', $name )->{out} ); }

# Usage     : hold_lock($self, $name, $pid)
# Purpose   : Writes a named lock held by the PID.
# Returns   : The lock's path.
sub hold_lock
{
    my ( $self, $name, $pid ) = @_;
    my $lock = lock_path( $self, $name );
    File::Path::make_path($lock);
    AAPP::Tests::write_text( "$lock/pid", "$pid\n" );
    return $lock;
}

sub test_manual_default_archives_without_integrating
{
    my ($self) = @_;
    my $id  = wt_plan( $self, 'alpha' );
    my $dev = rev( $self, 'develop' );
    my $r   = done( $self, $id );
    $self->eq_or_die( $r->{exit}, 0, 'done succeeds', $r->{all} );
    $self->eq_or_die( trim( $self->ok_cmd( 'git', 'config', 'aapp.integrate' )->{out} ), 'manual', 'the seeded setting is manual' );
    $self->eq_or_die( rev( $self, 'develop' ), $dev, 'nothing is integrated' );
    $self->true_or_die( -d wt_of($id), 'the worktree stays' );
    $self->true_or_die( pfile($id) =~ m{/done/}, 'the plan is archived' );
    $self->true_or_die( index( $r->{all}, "aapp done $id integrate" ) >= 0, 'the integrate advice is printed', $r->{all} );
    return 1;
}

sub test_squash_integrates_with_trailers_and_cleans_up
{
    my ($self) = @_;
    my $prim = current($self);
    $self->ok_cmd( 'git', 'config', 'aapp.integrate', 'squash' );
    my $id = wt_plan( $self, 'sq' );
    my ($n) = $id =~ /([0-9]+)/;
    my $r = done( $self, $id );
    $self->eq_or_die( $r->{exit}, 0, 'done succeeds', $r->{all} );
    $self->true_or_die( has_file( $self, 'develop', 'src/sq.sh' ), 'the work is on develop' );
    my $msg = $self->ok_cmd( 'git', 'log', '-1', '--format=%B', 'develop' )->{out};
    $self->match_or_die( $msg, qr/^Plan-ID: \Q$id\E$/m,     'the Plan-ID trailer' );
    $self->match_or_die( $msg, qr/^Plan-Parent: develop$/m, 'the Plan-Parent trailer' );
    $self->true_or_die( !-d wt_of($id), 'the worktree is removed' );
    $self->eq_or_die( rev( $self, "plan/P$n-sq" ), '', 'the branch is removed' );
    $self->eq_or_die( current($self), $prim, 'the main checkout is back on its branch' );
    $self->eq_or_die( $self->ok_cmd( 'git', 'status', '--porcelain', '--untracked-files=no' )->{out}, '', 'and clean' );
    return 1;
}

sub test_integrates_into_module_parent_not_develop
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.integrate', 'squash' );
    $self->ok_cmd( 'git', 'branch', 'module/auth', 'develop' );
    $self->ok_cmd( 'git', 'config', 'aapp.devBranch', 'module/auth' );
    my $id = wt_plan( $self, 'mod' );
    $self->ok_cmd( 'git', 'config', 'aapp.devBranch', 'develop' );
    my $dev = rev( $self, 'develop' );
    my $r   = done( $self, $id );
    $self->eq_or_die( $r->{exit}, 0, 'done succeeds', $r->{all} );
    $self->true_or_die( has_file( $self, 'module/auth', 'src/mod.sh' ), 'the work lands on module/auth' );
    $self->eq_or_die( rev( $self, 'develop' ), $dev, 'not on develop' );
    $self->match_or_die( $self->ok_cmd( 'git', 'log', '-1', '--format=%B', 'module/auth' )->{out}, qr/^Plan-Parent: module\/auth$/m, 'naming its parent' );
    return 1;
}

sub test_ff_keeps_microcommits_and_deletes_branch
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.integrate', 'ff' );
    my $id = wt_plan( $self, 'ffp' );
    my ($n) = $id =~ /([0-9]+)/;
    commit_in( $self, wt_of($id), 'src/ffp_b.sh', "w=1\n", 'feat: ffp two' );
    my $tip = rev( $self, "plan/P$n-ffp" );
    my $r   = done( $self, $id );
    $self->eq_or_die( $r->{exit}, 0, 'done succeeds', $r->{all} );
    $self->eq_or_die( rev( $self, 'develop' ), $tip, 'develop is the plan tip' );
    $self->eq_or_die( rev( $self, "plan/P$n-ffp" ), '', 'the branch is deleted' );
    $self->true_or_die( !-d wt_of($id), 'the worktree is removed' );
    return 1;
}

sub test_preflight_failure_archives_nothing
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.integrate', 'squash' );
    my $id   = wt_plan( $self, 'behind' );
    my $file = pfile($id);
    my $head = trim( $self->ok_cmd( 'git', '-C', '.plans', 'rev-parse', 'HEAD' )->{out} );
    on_branch( $self, 'develop', 'moved.txt', "d=1\n", 'develop moves' );
    my $r = done( $self, $id );
    $self->true_or_die( $r->{exit} != 0, 'done is refused' );
    $self->match_or_die( $r->{all}, qr/rebase/i, 'asking for a rebase' );
    $self->file_exists_or_die($file);
    $self->eq_or_die( trim( $self->ok_cmd( 'git', '-C', '.plans', 'rev-parse', 'HEAD' )->{out} ), $head, 'nothing is committed' );
    return 1;
}

sub test_hotfix_cap_vetoes_without_override
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.integrate', 'squash' );
    my $id   = wt_plan( $self, 'behind' );
    my $file = pfile($id);
    AAPP::Tests::write_text( $file, AAPP::Tests::read_text($file) =~ s/^(\* \*\*Status:\*\* ⚡ In Development)$/$1\n* **Emergency Hotfixes:** #1, #2, #3/mr );
    $self->ok_cmd( 'git', '-C', '.plans', 'commit', '-qam', 'three hotfixes' );
    my $r = done( $self, $id );
    $self->true_or_die( $r->{exit} != 0, 'done is refused past the cap' );
    $self->true_or_die( index( $r->{all}, 'override-hotfix-cap' ) >= 0, 'naming the override', $r->{all} );
    $r = done( $self, $id, 'integrate', 'override-hotfix-cap' );
    $self->eq_or_die( $r->{exit}, 0, 'the override integrates', $r->{all} );
    $self->true_or_die( has_file( $self, 'develop', 'src/behind.sh' ), 'the work is on develop' );
    return 1;
}

sub test_ignored_files_refuse_cleanup_then_quarantine
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.integrate', 'squash' );
    my $id = wt_plan( $self, 'envp' );
    my $wt = wt_of($id);
    AAPP::Tests::write_text( "$wt/.env", "SECRET=1\n" );
    my $r = done( $self, $id );
    $self->eq_or_die( $r->{exit}, 0, 'done integrates', $r->{all} );
    $self->true_or_die( has_file( $self, 'develop', 'src/envp.sh' ), 'the work is on develop' );
    $self->true_or_die( -f "$wt/.env", 'the worktree is kept' );
    $self->true_or_die( index( $r->{all}, '.env' ) >= 0 && index( $r->{all}, 'force-cleanup' ) >= 0, 'naming the file and force-cleanup', $r->{all} );
    $self->ok_cmd( 'git', 'config', 'aapp.quarantineIgnored', 'true' );
    my $dev = rev( $self, 'develop' );
    $r = done( $self, $id, 'integrate' );
    $self->eq_or_die( $r->{exit}, 0, 'the retry succeeds', $r->{all} );
    $self->eq_or_die( rev( $self, 'develop' ), $dev, 'without merging again' );
    $self->true_or_die( !-d $wt, 'the worktree is cleaned up' );
    my $common = trim( $self->ok_cmd( 'git', 'rev-parse', '--git-common-dir' )->{out} );
    $self->eq_or_die( AAPP::Tests::read_text("$common/aapp_quarantine/$id/.env"), "SECRET=1\n", 'the file is in quarantine' );
    return 1;
}

sub test_no_integrate_token_archives_only
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.integrate', 'squash' );
    my $id  = wt_plan( $self, 'noint' );
    my $dev = rev( $self, 'develop' );
    my $r   = done( $self, $id, 'no-integrate' );
    $self->eq_or_die( $r->{exit}, 0, 'done succeeds', $r->{all} );
    $self->eq_or_die( rev( $self, 'develop' ), $dev, 'the parent is left' );
    $self->true_or_die( -d wt_of($id), 'and the worktree' );
    return 1;
}

sub test_plan_without_worktree_never_integrated
{
    my ($self) = @_;
    my $prim = current($self);
    $self->ok_cmd( 'git', 'config', 'aapp.integrate',     'squash' );
    $self->ok_cmd( 'git', 'config', 'aapp.planWorktrees', 'off' );
    my $id = 'P-' . trim( $self->ok_cmd( 'git', 'config', 'aapp.planId' )->{out} );
    $self->ok_cmd( 'aapp', 'draft', 'plain' );
    prep( $self, pfile($id), 'plain.sh', undef );
    $self->ok_cmd( 'aapp', 'freeze-start', $id );
    $self->ok_cmd( 'git', 'checkout', '-q', 'develop' );
    commit_in( $self, Cwd::getcwd(), 'src/plain.sh', "p=1\n", 'feat: plain' );
    my ( $dev, $head ) = ( rev( $self, 'develop' ), rev( $self, 'HEAD' ) );
    my $root = Cwd::getcwd();
    my $r    = done( $self, $id );
    $r->{all} =~ s/\Q$root\E//g;
    my $after = rev( $self, 'HEAD' );
    $self->ok_cmd( 'git', 'checkout', '-q', $prim );
    $self->eq_or_die( $r->{exit}, 0, 'done succeeds', $r->{all} );
    $self->eq_or_die( rev( $self, 'develop' ), $dev, 'develop is unchanged' );
    $self->eq_or_die( $after, $head, 'HEAD is unchanged' );
    $self->true_or_die( $r->{all} !~ /integrat/i, 'no integration is mentioned', $r->{all} );
    return 1;
}

sub test_hook_strategy_refuses_without_handler_then_delegates
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.integrate', 'hook' );
    my $id   = wt_plan( $self, 'hk' );
    my ($n)  = $id =~ /([0-9]+)/;
    my $file = pfile($id);
    my $r    = done( $self, $id );
    $self->true_or_die( $r->{exit} != 0 && index( $r->{all}, 'on-integrate' ) >= 0, 'without a handler done is refused', $r->{all} );
    $self->file_exists_or_die($file);
    File::Path::make_path($HOOKS);
    AAPP::Tests::write_text( "$HOOKS/integ.sh",
        "#!/usr/bin/env bash\np=\"\$(cat)\"\n[ -f \"\$AAPP_HOOK_FAIL\" ] && exit 1\nprintf \"%s\\n\" \"\$p\" > \"\$AAPP_HOOK_OUT\"\nexit 0\n" );
    chmod( 0755, "$HOOKS/integ.sh" ) or die "cannot chmod the handler: $!\n";
    my $line = $self->ok_cmd( 'aapp', 'hook-hash', "$HOOKS/integ.sh", 'on-integrate', '10', 'gate' )->{out};
    AAPP::Tests::write_text( "$HOOKS/registry.tsv", join( '', map {"$_\n"} grep {/^on-integrate\t/} split( /\n/, $line ) ) );
    local $ENV{AAPP_HOOK_OUT}  = Cwd::getcwd() . '/.git/integ.json';
    local $ENV{AAPP_HOOK_FAIL} = Cwd::getcwd() . '/.git/integ.fail';
    AAPP::Tests::write_text( $ENV{AAPP_HOOK_FAIL}, '' );
    my $dev = rev( $self, 'develop' );
    $r = done( $self, $id );
    $self->true_or_die( $r->{exit} != 0, 'a failing handler fails done', $r->{all} );
    $self->true_or_die( pfile($id) =~ m{/done/}, 'after archiving' );
    unlink( $ENV{AAPP_HOOK_FAIL} ) or die "cannot remove the fail flag: $!\n";
    $r = done( $self, $id, 'integrate' );
    $self->eq_or_die( $r->{exit}, 0, 'the retry with integrate succeeds', $r->{all} );
    my $json = AAPP::Tests::read_text( $ENV{AAPP_HOOK_OUT} );
    $self->true_or_die( index( $json, qq{"plan_branch": "plan/P$n-hk"} ) >= 0, 'the handler gets the plan branch', $json );
    $self->true_or_die( index( $json, '"target_branch": "develop"' ) >= 0,     'and the target branch',            $json );
    $self->eq_or_die( rev( $self, 'develop' ), $dev, 'the kit merges nothing itself' );
    $self->true_or_die( -d wt_of($id), 'and keeps the worktree' );
    return 1;
}

# Usage     : my $flags = group_setup($self)
# Purpose   : The group tests' project: module/m beside develop, ff integration, and a pre-done recorder
#             that, for the group named in <flags>/gi-group, writes what the gate saw to <flags>/gi-gate
#             and vetoes while <flags>/gi-veto exists.
# Returns   : The flags folder.
sub group_setup
{
    my ($self) = @_;
    my $flags = Cwd::getcwd() . '/.git';
    my $root  = Cwd::getcwd();
    $self->ok_cmd( 'git', 'branch', 'module/m' );
    $self->ok_cmd( 'git', 'config', 'aapp.integrate', 'ff' );
    File::Path::make_path($HOOKS);
    AAPP::Tests::write_text( "$HOOKS/rec.sh", <<"EOF" );
#!/usr/bin/env bash
p="\$(cat)"
id="\$(printf '%s' "\$p" | sed -nE 's/.*"plan_id": *"([^"]*)".*/\\1/p' | head -1)"
wt="\$(printf '%s' "\$p" | sed -nE 's/.*"worktree": *"([^"]*)".*/\\1/p' | head -1)"
ch="\$(printf '%s' "\$p" | sed -nE 's/.*"commit_hash": *"([^"]*)".*/\\1/p' | head -1)"
[ "\$id" = "\$(cat "$flags/gi-group" 2>/dev/null)" ] || exit 0
{ echo "wt=\$wt"
  grep -q GROUP-ARCH "\$wt/ARCHITECTURE.md" 2>/dev/null && echo arch=yes || echo arch=no
  grep -q GROUP-MAP "$root/.agents/CODEMAP.md" && echo map=yes || echo map=no
  [ -f "\$wt/src/moved.sh" ] && echo moved=yes || echo moved=no
  echo "ch=\$ch"; echo "head=\$(git -C "\$wt" rev-parse HEAD 2>/dev/null)"; } > "$flags/gi-gate"
[ ! -f "$flags/gi-veto" ]
EOF
    chmod( 0755, "$HOOKS/rec.sh" ) or die "cannot chmod the recorder: $!\n";
    my $line = $self->ok_cmd( 'aapp', 'hook-hash', "$HOOKS/rec.sh", 'pre-done', '30', 'gate' )->{out};
    AAPP::Tests::write_text( "$HOOKS/registry.tsv", join( '', map {"$_\n"} grep {/^pre-done\t/} split( /\n/, $line ) ) );
    return $flags;
}

# Usage     : my $id = g_plan($self, $flags, $slug, $parent)
# Purpose   : A started group with one ARCHITECTURE.md and one CODEMAP.md section and its changelog line,
#             named as the recorder's group.
# Returns   : Its id.
sub g_plan
{
    my ( $self, $flags, $slug, $parent ) = @_;
    my $id = 'P-' . trim( $self->ok_cmd( 'git', 'config', 'aapp.planId' )->{out} );
    $self->ok_cmd( 'aapp', 'draft', $slug, 'group' );
    my $file = pfile($id);
    my $sections = "### ARCHITECTURE.md\n````markdown\n## Group Arch $slug\nGROUP-ARCH\n````\n### .agents/CODEMAP.md\n````markdown\n## Group Map $slug\nGROUP-MAP\n````\n";
    my ( @out, $skip );
    foreach my $line ( split( /\n/, AAPP::Tests::read_text($file) ) ) {
        if ( $line =~ /^## Architecture & Codemap/ ) {
            push @out, $line, split( /\n/, $sections );
            $skip = 1;
            next;
        }
        $skip = 0 if $line =~ /^## /;
        push @out, $line if !$skip;
    }
    my $text = join( "\n", @out ) . "\n";
    $text =~ s/^\* \*\*Changelog:\*\*.*$/* **Changelog:** Added: umbrella $slug/m;
    $text =~ s/^\* \[ \] \*\*Question/* [x] **Question/mg;
    AAPP::Tests::write_text( $file, $text );
    $self->ok_cmd( 'aapp', 'refine', $id, 'sections' );
    $self->ok_cmd( 'aapp', 'freeze', $id );
    $self->ok_cmd( 'aapp', 'start', $id, 'base', $parent );
    AAPP::Tests::write_text( "$flags/gi-group", "$id\n" );
    return $id;
}

# Usage     : my $id = g_member($self, $slug, $group)
# Purpose   : A member started into the group with src/<slug>.sh committed.
# Returns   : Its id.
sub g_member
{
    my ( $self, $slug, $group ) = @_;
    my $id = 'P-' . trim( $self->ok_cmd( 'git', 'config', 'aapp.planId' )->{out} );
    $self->ok_cmd( 'aapp', 'draft', $slug, 'group', $group );
    prep( $self, pfile($id), "$slug.sh", undef );
    $self->ok_cmd( 'aapp', 'freeze-start', $id );
    commit_in( $self, wt_of($id), "src/$slug.sh", "v=1\n", "feat: $slug" );
    return $id;
}

# Usage     : g_amend_done($self, $group)
# Purpose   : Archives the group's amendments member (drafted and started with the group, empty here).
# Returns   : 1
sub g_amend_done
{
    my ( $self, $group ) = @_;
    my ($n) = $group =~ /([0-9]+)/;
    my $r = done( $self, 'P-' . ( $n + 1 ), 'integrate', 'ff' );
    $self->eq_or_die( $r->{exit}, 0, 'the amendments member is archived', $r->{all} );
    return 1;
}

# Usage     : on_worktree($self, $branch, $file, $text, $message)
# Purpose   : Commits a file on a branch through a temporary worktree.
# Returns   : 1
sub on_worktree
{
    my ( $self, $branch, $file, $text, $message ) = @_;
    my $tmp = Cwd::getcwd() . '/.git/tmp-wt';
    $self->ok_cmd( 'git', 'worktree', 'add', '-q', $tmp, $branch );
    File::Path::make_path("$tmp/src");
    AAPP::Tests::write_text( "$tmp/$file", $text );
    $self->ok_cmd( 'git', '-C', $tmp, 'add', $file );
    $self->ok_cmd( 'git', '-C', $tmp, 'commit', '-qm', $message, '--no-verify' );
    $self->ok_cmd( 'git', 'worktree', 'remove', $tmp );
    return 1;
}

sub test_member_integrates_into_feature_branch
{
    my ($self) = @_;
    my $flags = group_setup($self);
    my $g     = g_plan( $self, $flags, 'grp', 'module/m' );
    my $a     = g_member( $self, 'mem-a', $g );
    my $r     = done( $self, $a );
    $self->eq_or_die( $r->{exit}, 0, 'the member is done', $r->{all} );
    $self->true_or_die( has_file( $self, 'feature/grp', 'src/mem-a.sh' ), 'its work is on the feature branch' );
    $self->true_or_die( !has_file( $self, 'module/m', 'src/mem-a.sh' ),  'not on the parent' );
    return 1;
}

sub test_group_done_refuses_open_member
{
    my ($self) = @_;
    my $flags = group_setup($self);
    my $g     = g_plan( $self, $flags, 'grp', 'module/m' );
    my $a     = g_member( $self, 'mem-a', $g );
    $self->eq_or_die( done( $self, $a )->{exit}, 0, 'the first member is done' );
    my $b = g_member( $self, 'mem-b', $g );
    my ( $mod, $fb ) = ( rev( $self, 'module/m' ), rev( $self, 'feature/grp' ) );
    my $r = done( $self, $g );
    $self->true_or_die( $r->{exit} != 0 && index( $r->{all}, $b ) >= 0, 'the group is refused, naming the open member', $r->{all} );
    $self->eq_or_die( rev( $self, 'module/m' ),    $mod, 'the parent is unchanged' );
    $self->eq_or_die( rev( $self, 'feature/grp' ), $fb,  'the feature branch is unchanged' );
    $self->true_or_die( pfile($g) =~ m{/current/}, 'the group stays current' );
    return 1;
}

sub test_group_done_gates_merges_and_writes_docs
{
    my ($self) = @_;
    my $flags = group_setup($self);
    my $g     = g_plan( $self, $flags, 'grp', 'module/m' );
    my $a     = g_member( $self, 'mem-a', $g );
    $self->eq_or_die( done( $self, $a )->{exit}, 0, 'member a is done' );
    my $b = g_member( $self, 'mem-b', $g );
    $self->eq_or_die( done( $self, $b )->{exit}, 0, 'member b is done' );
    on_worktree( $self, 'module/m', 'src/moved.sh', "m=1\n", 'parent moved' );
    my $text = AAPP::Tests::read_text( pfile($a) );
    my ($asha) = $text =~ /^- `([0-9a-f]+)`/m;
    ($asha) = $text =~ /Commits:\*\* `([0-9a-f]+)`/ if !defined $asha;
    g_amend_done( $self, $g );
    my $r    = done( $self, $g );
    my $gate = AAPP::Tests::read_text("$flags/gi-gate");
    $self->eq_or_die( $r->{exit}, 0, 'the group is done', $r->{all} );
    $self->true_or_die( has_file( $self, 'module/m', 'src/mem-a.sh' ) && has_file( $self, 'module/m', 'src/mem-b.sh' ), 'both members are on the parent' );
    $self->eq_or_die( rev( $self, 'feature/grp' ), '', 'the feature branch is gone' );
    $self->true_or_die( defined $asha && $self->run_cmd( 'git', 'merge-base', '--is-ancestor', $asha, 'module/m' )->{exit} == 0, "member a's commit is in the parent" );
    $self->true_or_die( pfile($g) =~ m{/done/}, 'the group is archived' );
    my $root = Cwd::getcwd();
    $self->match_or_die( $gate, qr/^wt=\Q$root\E\//m, 'the gate ran in the project' );
    $self->true_or_die( $gate =~ /^moved=yes$/m && has_file( $self, 'module/m', 'src/moved.sh' ), 'the moved parent was merged in before the gate', $gate );
    $self->true_or_die( $gate =~ /^arch=no$/m && $gate =~ /^map=no$/m, 'the docs come after the gate', $gate );
    my ($gch)   = $gate =~ /^ch=(.*)$/m;
    my ($ghead) = $gate =~ /^head=(.*)$/m;
    $self->true_or_die( defined $gch && $gch ne '' && index( $ghead // '', $gch ) == 0, 'the gate ran on the head it names', $gate );
    $self->match_or_die( $self->ok_cmd( 'git', 'show', 'module/m:ARCHITECTURE.md' )->{out}, qr/GROUP-ARCH/, 'the ARCHITECTURE.md section is committed' );
    $self->match_or_die( AAPP::Tests::read_text('.agents/CODEMAP.md'), qr/GROUP-MAP/, 'the CODEMAP.md section is written' );
    $self->eq_or_die( $self->ok_cmd( 'git', '-C', '.agents', 'status', '--porcelain', 'CODEMAP.md' )->{out}, '', 'and committed' );
    my @lines = split( /\n/, $r->{all} );
    my ($map_at)   = grep { $lines[$_] =~ /CODEMAP\.md/ } 0 .. $#lines;
    my ($clean_at) = grep { $lines[$_] =~ /\[Cleanup\]/ } 0 .. $#lines;
    $self->true_or_die( defined $map_at && defined $clean_at && $map_at < $clean_at && $lines[-1] =~ /\[Cleanup\]/, 'cleanup comes last', $r->{all} );
    my $changelog = $self->ok_cmd( 'git', 'show', 'module/m:CHANGELOG.md' )->{out};
    $self->true_or_die( index( $changelog, "umbrella grp (`$g`)" ) >= 0 && index( $changelog, "(`$a`)" ) >= 0, 'the umbrella changelog entry', $changelog );
    return 1;
}

sub test_group_done_conflict_refuses_unchanged
{
    my ($self) = @_;
    my $prim  = current($self);
    my $flags = group_setup($self);
    my $g     = g_plan( $self, $flags, 'grp-two', 'develop' );
    my $c     = g_member( $self, 'mem-c', $g );
    $self->eq_or_die( done( $self, $c )->{exit}, 0, 'the member is done' );
    g_amend_done( $self, $g );
    on_worktree( $self, 'develop', 'src/mem-c.sh', "conflict=1\n", 'conflicting' );
    my ( $dev, $fb ) = ( rev( $self, 'develop' ), rev( $self, 'feature/grp-two' ) );
    my $r = done( $self, $g );
    $self->true_or_die( $r->{exit} != 0, 'the group is refused', $r->{all} );
    $self->eq_or_die( rev( $self, 'develop' ),         $dev, 'the parent is unchanged' );
    $self->eq_or_die( rev( $self, 'feature/grp-two' ), $fb,  'the feature branch is unchanged' );
    $self->true_or_die( pfile($g) =~ m{/current/}, 'the group stays current' );
    $self->eq_or_die( current($self), $prim, 'the main checkout is on its branch' );
    $self->true_or_die( AAPP::Tests::read_text('.agents/CODEMAP.md') !~ /Group Map grp-two/, 'no CODEMAP.md section is written' );
    return 1;
}

sub test_group_done_commits_nothing_before_every_check_passed
{
    my ($self) = @_;
    my $flags = group_setup($self);
    my $g     = g_plan( $self, $flags, 'grp-three', 'module/m' );
    my $d     = g_member( $self, 'mem-d', $g );
    $self->eq_or_die( done( $self, $d )->{exit}, 0, 'the member is done' );
    g_amend_done( $self, $g );
    my $gwt = wt_of($g);
    AAPP::Tests::write_text( "$flags/gi-veto", '' );
    my $fb = rev( $self, 'feature/grp-three' );
    my $r  = done( $self, $g );
    unlink("$flags/gi-veto") or die "cannot remove the veto: $!\n";
    $self->true_or_die( $r->{exit} != 0, 'a gate veto refuses', $r->{all} );
    $self->eq_or_die( rev( $self, 'feature/grp-three' ), $fb, 'the feature branch is unchanged' );
    $self->true_or_die( pfile($g) =~ m{/current/}, 'the group stays current' );
    $self->eq_or_die( $self->run_cmd( 'git', '-C', $gwt, 'status', '--porcelain' )->{out}, '', 'its worktree is clean' );
    my $hook = AAPP::Tests::read_text('.githooks/pre-commit');
    AAPP::Tests::write_text( '.githooks/pre-commit', "#!/usr/bin/env bash\nexit 1\n" );
    $r = done( $self, $g );
    AAPP::Tests::write_text( '.githooks/pre-commit', $hook );
    my $dirty = $self->run_cmd( 'git', '-C', $gwt, 'status', '--porcelain' )->{out};
    $self->true_or_die( $r->{exit} != 0 && index( $r->{all}, "Could not commit the group's ARCHITECTURE.md" ) >= 0, 'a refused docs commit refuses', $r->{all} );
    $self->eq_or_die( $dirty, '', 'leaving the worktree clean' );
    $r = done( $self, $g );
    $self->eq_or_die( $r->{exit}, 0, 'the next run lands it', $r->{all} );
    $self->match_or_die( $self->ok_cmd( 'git', 'show', 'module/m:ARCHITECTURE.md' )->{out}, qr/Group Arch grp-three/, 'with its section' );
    return 1;
}

sub test_auto_rebase_setting_refuses_or_rebases
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.autoRebase', 'false' );
    $self->ok_cmd( 'git', 'config', 'aapp.integrate',  'ff' );
    my $id = wt_plan( $self, 'arb_optout' );
    on_branch( $self, 'develop', 'dev_adv.txt', "dev_adv=1\n", 'dev advances' );
    my $r = done( $self, $id );
    $self->true_or_die( $r->{exit} != 0 && $r->{all} =~ /rebase it first/i, 'aapp.autoRebase false refuses', $r->{all} );
    $self->true_or_die( -d wt_of($id), 'the worktree stays' );
    $self->ok_cmd( 'git', 'config', 'aapp.autoRebase', 'true' );
    $r = done( $self, $id );
    $self->eq_or_die( $r->{exit}, 0, 'aapp.autoRebase true integrates', $r->{all} );
    $self->true_or_die( !-d wt_of($id), 'the worktree is cleaned up' );
    $self->true_or_die( has_file( $self, 'develop', 'src/arb_optout.sh' ), 'the work is on develop' );
    $self->true_or_die( index( $r->{all}, 'Successfully rebased' ) >= 0, 'after a rebase', $r->{all} );
    return 1;
}

sub test_auto_rebase_conflict_aborts_cleanly
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.autoRebase', 'true' );
    $self->ok_cmd( 'git', 'config', 'aapp.integrate',  'ff' );
    my $id = wt_plan( $self, 'arb_conflict' );
    my $wt = wt_of($id);
    on_branch( $self, 'develop', 'src/arb_conflict.sh', "conflict=1\n", 'conflict advance' );
    my $r = done( $self, $id );
    $self->true_or_die( $r->{exit} != 0 && $r->{all} =~ /Automated rebase encountered merge conflicts/i, 'the conflicting rebase aborts', $r->{all} );
    $self->true_or_die( -d $wt, 'the worktree stays' );
    $self->eq_or_die( $self->run_cmd( 'git', '-C', $wt, 'status', '--porcelain' )->{out}, '', 'clean' );
    $self->true_or_die( pfile($id) =~ m{/current/}, 'the plan stays open' );
    return 1;
}

sub test_named_lock_acquire_and_release
{
    my ($self) = @_;
    my $script = <<'EOF';
aapp_lock_acquire "test/foo" 2 "Test Lock" || exit 1
[ -d "$(aapp_lock_path "test/foo")" ] || exit 2
[ "$(cat "$(aapp_lock_path "test/foo")/pid")" = "$$" ] || exit 3
aapp_lock_release "test/foo"
[ ! -d "$(aapp_lock_path "test/foo")" ] || exit 4
EOF
    $self->eq_or_die( $self->lib_call( 'aapp_lib', 'eval', $script )->{exit}, 0, 'the lock holds its PID and is removed on release' );
    return 1;
}

sub test_named_lock_reentrancy
{
    my ($self) = @_;
    my $script = "aapp_lock_acquire \"test/reentrant\" 2 || exit 1\naapp_lock_acquire \"test/reentrant\" 2 || exit 2\naapp_lock_release \"test/reentrant\"\n";
    $self->eq_or_die( $self->lib_call( 'aapp_lib', 'eval', $script )->{exit}, 0, 'the holder acquires its lock again' );
    return 1;
}

sub test_named_lock_stale_pid_takeover
{
    my ($self) = @_;
    hold_lock( $self, 'test/stale', 999999 );
    my $r = $self->lib_call( 'aapp_lib', 'eval', "aapp_lock_acquire \"test/stale\" 2 \"Stale Lock\"; rc=\$?; aapp_lock_release \"test/stale\"; exit \$rc\n" );
    $self->eq_or_die( $r->{exit}, 0, 'a dead holder is taken over' );
    $self->match_or_die( $r->{out} . $r->{err}, qr/Taking over stale/, 'with a notice' );
    return 1;
}

sub test_concurrent_integrations_different_parents_proceed
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.integrate', 'ff' );
    my $lock = hold_lock( $self, 'integrate/module/auth', $$ );
    my $id   = wt_plan( $self, 'iso' );
    my $r    = done( $self, $id );
    File::Path::remove_tree($lock);
    $self->eq_or_die( $r->{exit}, 0, 'done integrates', $r->{all} );
    $self->true_or_die( has_file( $self, 'develop', 'src/iso.sh' ), 'into develop' );
    return 1;
}

sub test_precommit_rejects_raw_commit_on_locked_parent
{
    my ($self) = @_;
    my $prim = current($self);
    $self->ok_cmd( 'git', 'checkout', '-q', 'develop' );
    my $lock = hold_lock( $self, 'integrate/develop', $$ );
    AAPP::Tests::write_text( 'raw_test.txt', "raw=1\n" );
    $self->ok_cmd( 'git', 'add', 'raw_test.txt' );
    my $r = $self->run_cmd( 'git', 'commit', '-m', 'raw commit attempt' );
    File::Path::remove_tree($lock);
    $self->ok_cmd( 'git', 'reset', '-q', 'HEAD', 'raw_test.txt' );
    unlink('raw_test.txt');
    $self->ok_cmd( 'git', 'checkout', '-q', $prim );
    $self->true_or_die( $r->{exit} != 0, 'the raw commit is refused' );
    $self->match_or_die( $r->{out} . $r->{err}, qr/is currently locked for integration/, 'naming the lock' );
    return 1;
}

sub test_parent_lock_contended_wait_and_integration
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.integrate', 'ff' );
    my $id   = wt_plan( $self, 'pwait' );
    my $lock = lock_path( $self, 'integrate/develop' );
    my $pid  = fork();
    die "cannot fork the lock holder: $!\n" if !defined $pid;
    if ( $pid == 0 ) {
        File::Path::make_path($lock);
        AAPP::Tests::write_text( "$lock/pid", "$$\n" );
        sleep 3;
        File::Path::remove_tree($lock);
        POSIX::_exit(0);
    }
    Time::HiRes::sleep(0.5);
    my $r = done( $self, $id );
    waitpid( $pid, 0 );
    $self->eq_or_die( $r->{exit}, 0, 'done integrates once the lock is free', $r->{all} );
    $self->true_or_die( index( $r->{all}, 'lock held by PID' ) >= 0, 'saying it waits', $r->{all} );
    $self->true_or_die( has_file( $self, 'develop', 'src/pwait.sh' ), 'the work is on develop' );
    return 1;
}

sub test_archive_failure_rolls_back_cas_and_preserves_active_buffer
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.integrate', 'ff' );
    my $id  = wt_plan( $self, 'rollb' );
    my ($n) = $id =~ /([0-9]+)/;
    my $dev = rev( $self, 'develop' );
    my $wt  = wt_of($id);
    my $buf = trim( $self->ok_cmd( 'git', '-C', $wt, 'rev-parse', '--git-path', 'aapp_active_plan' )->{out} );
    $buf = "$wt/$buf" if $buf !~ m{^/};
    chmod( 0555, '.plans' ) or die "cannot lock .plans: $!\n";
    my $r = done( $self, $id );
    chmod( 0755, '.plans' ) or die "cannot unlock .plans: $!\n";
    $self->true_or_die( $r->{exit} != 0, 'the archive fails', $r->{all} );
    $self->eq_or_die( rev( $self, 'develop' ), $dev, 'the parent is put back' );
    $self->eq_or_die( trim( AAPP::Tests::read_text($buf) ), $id, 'the plan stays bound' );
    $self->file_exists_or_die(".plans/current/P$n-rollb.md");
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
