package AAPP::T::Core::WriteGuard;

use strict;
use warnings;
use utf8;
use 5.026;

use Cwd ();
use File::Copy ();
use File::Path ();
use AAPP::JSON ();
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/write-guard.md. Run alone: prove -l t/core/write-guard.t

our $SECTION4 = '## 💥 4. Blast Radius & System Boundaries';

# Usage     : fixture($self)
# Purpose   : A repository with src/a.py and the three doc anchors committed, and the guard's files in .githooks.
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    $self->init_repo();
    File::Path::make_path( 'src', '.plans/current', '.agents', '.githooks' );
    AAPP::Tests::write_text( 'src/a.py',        "x=1\n" );
    AAPP::Tests::write_text( 'CHANGELOG.md',    "# CL\n" );
    AAPP::Tests::write_text( 'CODEMAP.md',      "# CM\n" );
    AAPP::Tests::write_text( 'ARCHITECTURE.md', "# AR\n" );
    $self->ok_cmd( 'git', 'add', '-A' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'init' );
    File::Copy::copy( "$self->{kit}/templates/blast-radius-guard.sh", '.githooks/blast-radius-guard' ) or die "cannot copy the guard: $!\n";
    chmod( 0755, '.githooks/blast-radius-guard' ) or die "cannot chmod the guard: $!\n";
    return 1;
}

# Usage     : my $guard = guard_path($self)
# Purpose   : The kit's guard template, run as the bash suite ran it.
# Returns   : The path.
sub guard_path { my ($self) = @_; return "$self->{kit}/templates/blast-radius-guard.sh"; }

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

# Usage     : my $json = payload($tool, $path, $content)
# Purpose   : A PreToolUse payload naming the tool and file (and content when given).
# Returns   : The JSON text.
sub payload
{
    my ( $tool, $path, $content ) = @_;
    my $input = '"file_path": ' . AAPP::JSON::json_str($path) . ( defined $content ? ', "content": ' . AAPP::JSON::json_str($content) : '' );
    return '{"tool_name": ' . AAPP::JSON::json_str($tool) . ', "tool_input": {' . $input . "}}\n";
}

# Usage     : my $rc = json_rc($self, $tool, $path)
# Purpose   : The guard's exit for a JSON payload.
# Returns   : The exit code.
sub json_rc { my ( $self, $tool, $path ) = @_; return $self->run_cmd( { stdin => payload( $tool, $path ) }, guard_path($self) )->{exit}; }

# Usage     : decision($self, $label, 'ALLOW'|'DENY', $path)
# Purpose   : The guard decides the same for the path by command line and by an Edit payload with the absolute path.
# Returns   : 1; dies naming both decisions when either differs.
sub decision
{
    my ( $self, $label, $want, $path ) = @_;
    my $cli  = $self->run_cmd( guard_path($self), $path )->{exit} == 0 ? 'ALLOW' : 'DENY';
    my $abs  = $path =~ m{^/} ? $path : Cwd::getcwd() . "/$path";
    my $json = json_rc( $self, 'Edit', $abs ) == 0 ? 'ALLOW' : 'DENY';
    $self->true_or_die( $cli eq $want && $json eq $want, "$label: want $want", "cli=$cli json=$json" );
    return 1;
}

# Usage     : decisions($self, [$label, $want, $path], ...)
# Purpose   : Several decisions in a row.
# Returns   : 1
sub decisions { my ( $self, @rows ) = @_; decision( $self, @{$_} ) for @rows; return 1; }

# Usage     : simple_plan()
# Purpose   : A plan without header: three targets, src/secret.py out of bounds.
# Returns   : 1
sub simple_plan
{
    return plan( 'p.md', <<'EOF' );
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> allowed
- [ ] `NEW FILE` -> `src/new_mod.py` -> allowed with backticks
- [ ] `src/my dir/b.py` -> allowed with spaces
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/secret.py` -> excluded
## end
EOF
}

# Usage     : forbidden_plan()
# Purpose   : A plan without targets whose Out of Bounds names src/forbidden.py.
# Returns   : 1
sub forbidden_plan
{
    return plan( 'p.md', <<'EOF' );
### 📂 Target Files (Modifications & Additions)
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/forbidden.py` -> denied
## end
EOF
}

# Usage     : dev_plan($name, $id, $target, $oob)
# Purpose   : A plan in development with one target and, when given, one Out of Bounds file.
# Returns   : 1
sub dev_plan
{
    my ( $name, $id, $target, $oob ) = @_;
    my $out = defined $oob ? "- [ ] `$oob` -> excluded\n" : '';
    return plan( $name, "* **Plan ID:** $id\n* **Status:** ⚡ In Development\n### 📂 Target Files (Modifications & Additions)\n- [ ] `$target` -> target\n### 🛑 Out of Bounds (Do Not Touch)\n$out## end\n" );
}

sub test_targets_and_shared_docs_decide
{
    my ($self) = @_;
    simple_plan();
    decisions(
        $self,
        [ 'declared target',                    'ALLOW', 'src/a.py' ],
        [ 'backticked new target',              'ALLOW', 'src/new_mod.py' ],
        [ 'file no plan targets',               'DENY',  'src/untracked.py' ],
        [ 'out of bounds',                      'DENY',  'src/secret.py' ],
        [ 'path named only in prose',           'DENY',  'src/prose.py' ],
        [ 'agent may write plans',              'ALLOW', '.plans/current/new.md' ],
        [ 'agent may write its rules',          'ALLOW', '.agents/AGENTS.md' ],
        [ 'invariant anchor',                   'ALLOW', 'CHANGELOG.md' ],
        [ 'invariant anchor CHEATSHEET.md',     'ALLOW', 'CHEATSHEET.md' ],
        [ 'invariant anchor COOKBOOK.md',       'ALLOW', 'COOKBOOK.md' ],
        [ 'shared documentation docs/concepts', 'ALLOW', 'docs/concepts/01-test.md' ],
        [ 'shared documentation docs/recipes',  'ALLOW', 'docs/recipes/workflow.md' ],
        [ 'second stray file',                  'DENY',  'src/other.py' ],
    );
    return 1;
}

sub test_self_protection
{
    my ($self) = @_;
    simple_plan();
    decisions(
        $self,
        [ 'settings that wire up the hook',      'DENY',  '.claude/settings.json' ],
        [ 'local settings override',             'DENY',  '.claude/settings.local.json' ],
        [ 'canonical claude settings',           'DENY',  '.agents/claude/settings.json' ],
        [ 'canonical aapp governance skill',     'DENY',  '.agents/skills/aapp-freeze/SKILL.md' ],
        [ 'bridged aapp governance skill',       'DENY',  '.claude/skills/aapp-freeze/SKILL.md' ],
        [ 'canonical plan governance skill',     'DENY',  '.agents/skills/plan/SKILL.md' ],
        [ 'bridged plan governance skill',       'DENY',  '.claude/skills/plan/SKILL.md' ],
        [ 'user custom skill allowed',           'ALLOW', '.agents/skills/custom-deploy/SKILL.md' ],
        [ 'the commit-time hook',                'DENY',  '.githooks/pre-commit' ],
        [ 'the namespaced commit-time hook',     'DENY',  '.githooks/aapp-pre-commit' ],
        [ 'the guard itself',                    'DENY',  '.githooks/blast-radius-guard' ],
        [ 'raw git hooks dir',                   'DENY',  '.git/hooks/pre-commit' ],
        [ "another agent's rule file",           'DENY',  '.cursor/rules/aapp.mdc' ],
        [ 'plans still writable',                'ALLOW', '.plans/state_matrix.md' ],
        [ 'agent rules still writable',          'ALLOW', '.agents/PROJECT.MD' ],
    );
    return 1;
}

sub test_active_buffer_picks_the_plan
{
    my ($self) = @_;
    dev_plan( 'a.md', 'P-1', 'src/a.py', 'src/b.py' );
    dev_plan( 'b.md', 'P-2', 'src/b.py' );
    AAPP::Tests::write_text( '.git/aapp_active_plan', "P-2\n" );
    decision( $self, 'P-2 bound: its target allowed, P-1 exclusion ignored', 'ALLOW', 'src/b.py' );
    decision( $self, "P-2 bound: P-1's target denied",                      'DENY',  'src/a.py' );
    AAPP::Tests::write_text( '.git/aapp_active_plan', "P-1\n" );
    decision( $self, 'P-1 bound: its target allowed',      'ALLOW', 'src/a.py' );
    decision( $self, 'P-1 bound: its exclusion enforced', 'DENY',  'src/b.py' );
    unlink('.git/aapp_active_plan') or die "cannot remove the buffer: $!\n";
    decision( $self, 'two plans in development, no binding', 'DENY', 'src/b.py' );
    return 1;
}

sub test_blocked_plan_grants_nothing
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
    decision( $self, 'own target refused while blocked', 'DENY', 'src/blocked_target.py' );
    return 1;
}

sub test_guard_follows_adopter_statuses
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.planState.blocked',        '⛔|Halted|⛔ Halted|40' );
    $self->ok_cmd( 'git', 'config', 'aapp.planState.in-development', '🚧|Building|🚧 Building|30' );
    plan( 'halted.md', <<'EOF' );
* **Status:** ⛔ Halted
### 📂 Target Files (Modifications & Additions)
- [ ] `src/halted_target.py` -> would be allowed if not halted
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
    decision( $self, 'adopter blocked status', 'DENY', 'src/halted_target.py' );
    unlink('.plans/current/halted.md') or die "cannot remove halted.md: $!\n";
    plan( 'building.md', <<'EOF' );
* **Plan ID:** P-40
* **Status:** 🚧 Building
### 📂 Target Files (Modifications & Additions)
- [ ] `src/building_target.py` -> the plan in development
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
    decision( $self, "adopter in-development plan's target", 'ALLOW', 'src/building_target.py' );
    decision( $self, 'adopter in-development plan confines', 'DENY',  'src/elsewhere.py' );
    return 1;
}

sub test_fails_open_on_bad_input
{
    my ($self) = @_;
    decision( $self, 'no active plans',                       'ALLOW', 'src/any.py' );
    decision( $self, 'self-protection holds with no plans',  'DENY',  '.githooks/blast-radius-guard' );
    my $guard = guard_path($self);
    foreach my $input ( [ 'garbage stdin', "garbage json\n" ], [ 'empty object', "{}\n" ],
        [ 'non-file tool', qq({"tool_name":"Read","tool_input":{"file_path":"a.py"}}\n) ], [ 'empty stdin', '' ] ) {
        $self->eq_or_die( $self->run_cmd( { stdin => $input->[1] }, $guard )->{exit}, 0, "$input->[0] is allowed" );
    }
    local $ENV{SKIP_BLAST_RADIUS} = 1;
    $self->eq_or_die( $self->run_cmd( $guard, 'src/forbidden.py' )->{exit}, 0, 'SKIP_BLAST_RADIUS=1 lets the write through' );
    return 1;
}

sub test_deny_payload_schema
{
    my ($self) = @_;
    forbidden_plan();
    my $r = $self->run_cmd( { stdin => payload( 'Write', Cwd::getcwd() . '/src/forbidden.py' ) }, guard_path($self) );
    my ( $rc, $d, $why ) = AAPP::JSON::decode( $r->{out} );
    $self->true_or_die( defined $d && ref($d) eq 'HASH', 'the decision is a JSON object', $why // $r->{out} );
    my $hso = $d->{hookSpecificOutput} // {};
    $self->eq_or_die( $d->{decision} // '', 'deny', 'decision deny' );
    $self->true_or_die( ( $d->{reason} // '' ) ne '', 'a reason' );
    $self->eq_or_die( $hso->{hookEventName}            // '', 'PreToolUse', 'the event name' );
    $self->eq_or_die( $hso->{permissionDecision}       // '', 'deny',       'the permission decision' );
    $self->eq_or_die( $hso->{permissionDecisionReason} // '', $d->{reason}, 'the same reason' );
    $self->match_or_die( $r->{err}, qr/Blast Radius Guard Violation/, 'stderr names the violation' );
    return 1;
}

sub test_large_payload_denied
{
    my ($self) = @_;
    forbidden_plan();
    my $r = $self->run_cmd( { stdin => payload( 'Write', Cwd::getcwd() . '/src/forbidden.py', 'x' x 350000 ) }, guard_path($self) );
    $self->eq_or_die( $r->{exit}, 2, 'a payload over 300 KB is denied' );
    return 1;
}

sub test_external_paths_and_precedence
{
    my ($self) = @_;
    plan( 'p.md', <<'EOF' );
### 📂 Target Files (Modifications & Additions)
- [ ] `src/a.py` -> allowed
### 🛑 Out of Bounds (Do Not Touch)
- [ ] `src/forbidden.py` -> forbidden
## end
EOF
    my $home = $ENV{HOME};
    my $repo = Cwd::getcwd();
    my $custom = "$self->{scratch}/custom_external";
    File::Path::make_path($custom);
    $self->ok_cmd( 'git', 'config', '--add', 'aapp.allowPath', $custom );
    decisions(
        $self,
        [ 'claude memory path allowlisted',       'ALLOW', "$home/.claude/projects/test/memory/note.md" ],
        [ 'antigravity brain path allowlisted',   'ALLOW', "$home/.gemini/antigravity-ide/brain/test.md" ],
        [ 'temp scratchpad allowlisted',          'ALLOW', '/tmp/scratchpad_aapp_test.txt' ],
        [ 'aapp.allowPath',                       'ALLOW', "$custom/notes.md" ],
        [ 'external path without allowlist entry', 'DENY', '/var/data/arbitrary/file.txt' ],
        [ 'claude settings win over the allowlist',   'DENY', "$home/.claude/settings.json" ],
        [ 'governance skill wins over the allowlist', 'DENY', "$home/.claude/skills/aapp-done/SKILL.md" ],
        [ 'git config wins over the allowlist',       'DENY', "$repo/.git/config" ],
    );
    $self->ok_cmd( 'git', 'config', '--add', 'aapp.allowPath', $home );
    decisions(
        $self,
        [ 'ssh keys denied with HOME allowed',  'DENY', "$home/.ssh/authorized_keys" ],
        [ 'shell rc denied with HOME allowed',  'DENY', "$home/.bashrc" ],
        [ 'local bin denied with HOME allowed', 'DENY', "$home/.local/bin/evil_script" ],
        [ 'traversal into the repository closed', 'DENY', "/tmp/..$repo/src/forbidden.py" ],
    );
    $self->eq_or_die( json_rc( $self, 'MultiEdit', "$repo/src/forbidden.py" ), 2, 'MultiEdit out of bounds is denied' );
    $self->eq_or_die( json_rc( $self, 'MultiEdit', "$repo/src/a.py" ),         0, 'MultiEdit on a target is allowed' );
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
    decisions(
        $self,
        [ '* matches in its directory',          'ALLOW', 'src/app.py' ],
        [ '* does not cross directories',        'DENY',  'src/deep/nested/app.py' ],
        [ '** matches at its root',              'ALLOW', 'pkg/main.go' ],
        [ '** matches nested directories',       'ALLOW', 'pkg/sub/deep/worker.go' ],
        [ '? matches one character',             'ALLOW', 'scripts/a.sh' ],
        [ '? rejects two characters',            'DENY',  'scripts/ab.sh' ],
        [ 'a bracket class matches a digit',     'ALLOW', 'migrations/001_init.sql' ],
        [ 'a bracket class rejects a non-digit', 'DENY',  'migrations/test.sql' ],
        [ 'a directory prefix matches its files', 'ALLOW', 'docs/guide.md' ],
        [ 'and nested files',                    'ALLOW', 'docs/api/v1/spec.md' ],
        [ 'an Out of Bounds wildcard blocks',    'DENY',  'src/forbidden_test.py' ],
    );
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
    decisions(
        $self,
        [ 'blockquote path',                     'DENY',  'src/quoted.py' ],
        [ 'foreign subsection path',             'DENY',  'src/notes.py' ],
        [ 'Required Test Files path',            'ALLOW', 'tests/boundary_test.sh' ],
        [ 'a declared target beside them',       'ALLOW', 'src/a.py' ],
    );
    return 1;
}

sub test_only_in_development_plans_grant
{
    my ($self) = @_;
    plan( 'frozen.md', <<'EOF' );
* **Plan ID:** P-10
* **Status:** 🔷 Frozen
### 📂 Target Files (Modifications & Additions)
- [ ] `src/frozen_target.py` -> in backlog, not in dev
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
    decision( $self, 'a frozen plan alone restricts nothing', 'ALLOW', 'src/frozen_target.py' );
    dev_plan( 'active.md', 'P-11', 'src/active_target.py' );
    decision( $self, "the plan in development's target",            'ALLOW', 'src/active_target.py' );
    decision( $self, "the frozen plan's target beside it is denied", 'DENY',  'src/frozen_target.py' );
    unlink('.plans/current/active.md') or die "cannot remove active.md: $!\n";
    plan( 'legacy.md', <<'EOF' );
* **Plan ID:** P-11
* **Status:** 🟠 In Development
### 📂 Target Files (Modifications & Additions)
- [ ] `src/legacy_target.py` -> legacy in flight
### 🛑 Out of Bounds (Do Not Touch)
## end
EOF
    dev_plan( 'dev.md', 'P-12', 'src/dev_target.py' );
    decision( $self, 'a retired status grants nothing', 'DENY', 'src/legacy_target.py' );
    return 1;
}

sub test_active_verb_switches_plan
{
    my ($self) = @_;
    dev_plan( 'p1.md', 'P-20', 'src/p1_target.py' );
    dev_plan( 'p2.md', 'P-21', 'src/p2_target.py' );
    $self->ok_cmd( 'aapp', 'active', 'P-20' );
    decision( $self, 'P-20 bound: its target allowed',    'ALLOW', 'src/p1_target.py' );
    decision( $self, "P-20 bound: P-21's target denied", 'DENY',  'src/p2_target.py' );
    $self->ok_cmd( 'aapp', 'active', 'P-21' );
    decision( $self, 'P-21 bound: its target allowed',    'ALLOW', 'src/p2_target.py' );
    decision( $self, "P-21 bound: P-20's target denied", 'DENY',  'src/p1_target.py' );
    $self->ok_cmd( 'aapp', 'active', 'swap' );
    decision( $self, 'swap returns to P-20',             'ALLOW', 'src/p1_target.py' );
    decision( $self, "swap: P-21's target denied again", 'DENY',  'src/p2_target.py' );
    $self->ok_cmd( 'aapp', 'active', 'clear' );
    decision( $self, 'clear: two plans in development, no binding', 'DENY', 'src/p1_target.py' );
    return 1;
}

sub test_freeze_start_grants_at_once
{
    my ($self) = @_;
    plan( 'draft.md', <<'EOF' );
* **Plan ID:** P-30
* **Changelog:** Added: Fast feature
* **Status:** 📝 Refining
### 📂 Target Files (Modifications & Additions)
- [ ] `src/fast_feature.py` -> feature target
### 🛑 Out of Bounds (Do Not Touch)
## ❓ 5. Open Questions
* [x] Question 1 resolved
## 📦 6. Change Log
EOF
    $self->ok_cmd( 'aapp', 'freeze-start', 'P-30' );
    decision( $self, 'its target is allowed at once', 'ALLOW', 'src/fast_feature.py' );
    decision( $self, 'an undeclared file is denied',  'DENY',  'src/other.py' );
    return 1;
}

sub test_linked_worktree_and_held_plans
{
    my ($self) = @_;
    dev_plan( 'p_wt.md', 'P-40', 'src/wt_target.py' );
    $self->ok_cmd( 'git', 'add', '-A' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'add wt plan' );
    my $other = Cwd::getcwd() . '-wt-agent2';
    $self->ok_cmd( 'git', 'worktree', 'add', '-q', $other, 'HEAD' );
    $self->in_dir(
        $other,
        sub {
            $self->ok_cmd( 'aapp', 'plan', 'P-40' );
            decision( $self, "a linked worktree reads the primary's plans", 'ALLOW', 'src/wt_target.py' );
            decision( $self, 'and denies an undeclared file',               'DENY',  'src/secret_wt.py' );
            $self->ok_cmd( 'aapp', 'active', 'P-40' );
        }
    );
    decision( $self, 'an unbound checkout refuses a plan held elsewhere', 'DENY',  'src/wt_target.py' );
    decision( $self, 'and does not adopt it',                             'ALLOW', 'src/free_main.py' );
    $self->ok_cmd( 'git', 'worktree', 'remove', '--force', $other );
    return 1;
}

sub test_workspace_worktree_reads_its_buffer
{
    my ($self) = @_;
    dev_plan( 'p_ws1.md', 'P-41', 'src/deep/ws_one.py', 'src/deep/ws_two.py' );
    dev_plan( 'p_ws2.md', 'P-42', 'src/deep/ws_two.py', 'src/deep/ws_one.py' );
    dev_plan( 'p_ws3.md', 'P-43', 'src/deep/ws_three.py' );
    File::Path::make_path('src/deep');
    AAPP::Tests::write_text( 'src/deep/ws_one.py', "x=1\n" );
    AAPP::Tests::write_text( 'src/deep/ws_two.py', "x=2\n" );
    $self->ok_cmd( 'git', 'add', '-A' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'add ws plans' );
    $self->ok_cmd( 'git', 'worktree', 'add', '-q', '.workspace/P41', 'HEAD' );
    my $gitdir = $self->ok_cmd( 'git', '-C', '.workspace/P41', 'rev-parse', '--absolute-git-dir' )->{out} =~ s/\s+\z//r;
    AAPP::Tests::write_text( "$gitdir/aapp_active_plan", "P-41\n" );
    AAPP::Tests::write_text( '.git/aapp_active_plan',   "P-42\n" );
    $self->in_dir(
        '.workspace/P41',
        sub {
            decision( $self, 'workspace worktree: its own target in a subdirectory', 'ALLOW', 'src/deep/ws_one.py' );
            decision( $self, "workspace worktree: the other plan's target",           'DENY',  'src/deep/ws_two.py' );
        }
    );
    decision( $self, 'primary: its own target in a subdirectory', 'ALLOW', 'src/deep/ws_two.py' );
    decision( $self, "primary: the other plan's target",           'DENY',  'src/deep/ws_one.py' );
    $self->ok_cmd( 'git', 'worktree', 'remove', '--force', '.workspace/P41' );
    return 1;
}

sub test_plans_as_linked_worktree
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'branch', '-q', 'plans-wt' );
    File::Path::remove_tree('.plans');
    $self->ok_cmd( 'git', 'worktree', 'add', '-q', '.plans', 'plans-wt' );
    dev_plan( 'p84.md', 'P-84', 'src/feature.py' );
    $self->in_dir(
        '.plans',
        sub {
            decision( $self, 'inside .plans: a relative planning write', 'ALLOW', 'current/notes.md' );
            decision( $self, 'inside .plans: ISSUES.md',                 'ALLOW', 'ISSUES.md' );
        }
    );
    decision( $self, 'primary: code outside the plan is still denied', 'DENY', 'src/other.py' );
    return 1;
}

sub test_pause_blocks_code_writes
{
    my ($self) = @_;
    plan( 'p_pause.md', <<'EOF' );
* **Plan ID:** P-50
* **Status:** ⚡ In Development
### 📂 Target Files (Modifications & Additions)
- [ ] `src/paused_target.py` -> target file
### 🛑 Out of Bounds (Do Not Touch)
EOF
    $self->ok_cmd( 'aapp', 'active', 'P-50' );
    decision( $self, 'before pause: the target', 'ALLOW', 'src/paused_target.py' );
    $self->ok_cmd( 'aapp', 'pause', 'away on vacation' );
    decisions(
        $self,
        [ 'paused: the target',               'DENY',  'src/paused_target.py' ],
        [ 'paused: an untracked file',        'DENY',  'src/random.py' ],
        [ 'paused: README.md',                'DENY',  'README.md' ],
        [ 'paused: ISSUES.md',                'ALLOW', '.plans/ISSUES.md' ],
        [ 'paused: the road map',             'ALLOW', '.plans/issues_road_map.md' ],
        [ 'paused: pickup',                   'ALLOW', '.plans/pickup.md' ],
        [ 'paused: a pickup file',            'ALLOW', '.plans/pickup/note.md' ],
        [ 'paused: a current plan',           'ALLOW', '.plans/current/P99.md' ],
        [ 'paused: done/',                    'DENY',  '.plans/done/000-archive-ledger.md' ],
        [ 'paused: the state matrix',         'DENY',  '.plans/state_matrix.md' ],
        [ 'paused: agent rules',              'DENY',  '.agents/AGENTS.md' ],
        [ 'paused: the codemap',              'DENY',  '.agents/CODEMAP.md' ],
        [ 'paused: an external scratch file', 'ALLOW', '/tmp/scratch.txt' ],
    );
    $self->ok_cmd( 'aapp', 'resume' );
    decision( $self, 'after resume: the target', 'ALLOW', 'src/paused_target.py' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
