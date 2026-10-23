package AAPP::T::Core::AiAttribution;

use strict;
use warnings;
use utf8;
use 5.026;

use Cwd ();
use Digest::SHA ();
use Encode ();
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/ai_attribution.md. Run alone: prove -l t/core/ai_attribution.t

our $OK_MSG   = "feat: add concise subject within seventy two chars limit\n\nThis is a valid body.";
our $FULL_MSG = "feat: valid subject\n\nAI-Agent: Claude\nAI-Vendor: Anthropic\nAI-Model: claude-3-5-sonnet";

# The credits block as the kit writes it; %s is the one roster line.
our $BLOCK = <<'EOF';
<!-- AAPP-AI-CREDITS:START -->
## AI Contributors

The following AI coding agents contributed to this codebase — planning, code, and review.
Listed alphabetically; the ordering carries no meaning, and no division of work is implied.

- %s

Authorship of, and responsibility for, this code rest with its human contributors.
<!-- AAPP-AI-CREDITS:END -->
EOF

# Usage     : fixture($self)
# Purpose   : A repository on main with the kit initialized and no commit of its own.
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    $self->init_repo();
    $self->ok_cmd( 'git', 'branch', '-M', 'main' );
    $self->ok_cmd( 'aapp', 'init' );
    return 1;
}

# Usage     : my $path = msg($name, $text)
# Purpose   : Writes a commit message file inside the Git data.
# Returns   : Its absolute path.
sub msg
{
    my ( $name, $text ) = @_;
    my $path = Cwd::getcwd() . "/.git/msg-$name.txt";
    AAPP::Tests::write_text( $path, "$text\n" );
    return $path;
}

# Usage     : my $verdict = hook_says($self, $file)
# Purpose   : What the commit-msg hook says about a message file.
# Returns   : 'PASS' or 'BLOCK'.
sub hook_says
{
    my ( $self, $file ) = @_;
    return $self->run_cmd( Cwd::getcwd() . '/.githooks/aapp-commit-msg', $file )->{exit} == 0 ? 'PASS' : 'BLOCK';
}

# Usage     : my $text = lines_of($n)
# Purpose   : n body lines 'Line 1' .. 'Line n'.
# Returns   : The text, no final newline.
sub lines_of { my ($n) = @_; return join( "\n", map {"Line $_"} 1 .. $n ); }

# Usage     : plain_hooks($self, $mode)
# Purpose   : Sets the attribution mode and a pass-through pre-commit, so commits test the message and note hooks alone.
# Returns   : 1
sub plain_hooks
{
    my ( $self, $mode ) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.aiAttribution', $mode );
    AAPP::Tests::write_text( '.githooks/pre-commit', "#!/bin/sh\nexit 0\n" );
    chmod( 0755, '.githooks/pre-commit' ) or die "cannot chmod the pre-commit: $!\n";
    $self->ok_cmd( 'git', 'config', 'core.hooksPath', '.githooks' );
    return 1;
}

# Usage     : commit_file($self, $name, $message)
# Purpose   : Commits a new file <name>.txt with the message, through the hooks.
# Returns   : The command's result.
sub commit_file
{
    my ( $self, $name, $message ) = @_;
    AAPP::Tests::write_text( "$name.txt", "$name\n" );
    $self->ok_cmd( 'git', 'add', "$name.txt" );
    return $self->run_cmd( 'git', 'commit', '-m', $message );
}

# Usage     : my $path = buffer_of($self, $message)
# Purpose   : Where a note staged for the message waits: the pending-note path, keyed by the message's hash.
# Returns   : The path.
sub buffer_of
{
    my ( $self, $message ) = @_;
    my $base = $self->ok_cmd( 'git', 'rev-parse', '--git-path', 'aapp_pending_note' )->{out} =~ s/\s+\z//r;
    my $clean = $self->ok_cmd( { stdin => "$message\n" }, 'git', 'stripspace', '--strip-comments' )->{out};
    return "$base." . Digest::SHA::sha256_hex( Encode::encode( 'UTF-8', $clean ) );
}

# Usage     : my $text = note_on($self, $ref)
# Purpose   : The note on HEAD in refs/notes/<ref>.
# Returns   : The note without its final newline, or ''.
sub note_on
{
    my ( $self, $ref ) = @_;
    my $r = $self->run_cmd( 'git', 'notes', "--ref=refs/notes/$ref", 'show', 'HEAD' );
    return $r->{exit} == 0 ? $r->{out} =~ s/\s+\z//r : '';
}

# Usage     : my $sum = readme_sum()
# Purpose   : The README's content hash.
# Returns   : Hex digest ('' when there is none).
sub readme_sum { return Digest::SHA::sha256_hex( Encode::encode( 'UTF-8', AAPP::Tests::read_text('README.md') ) ); }

# Usage     : my $text = block_with($line)
# Purpose   : The credits block naming one contributor.
# Returns   : The text.
sub block_with { my ($line) = @_; return sprintf( $BLOCK, $line ); }

sub test_init_defaults_and_hooks
{
    my ($self) = @_;
    $self->eq_or_die( $self->ok_cmd( 'git', 'config', 'aapp.aiAttribution' )->{out}, "none\n",  'attribution none' );
    $self->eq_or_die( $self->ok_cmd( 'git', 'config', 'aapp.aiCredits' )->{out},     "false\n", 'credits false' );
    $self->true_or_die( -x ".githooks/$_", ".githooks/$_ is executable" ) for qw(commit-msg aapp-commit-msg post-commit aapp-post-commit);
    return 1;
}

sub test_ai_notes_leaves_remote_refspecs
{
    my ($self) = @_;
    $self->ok_cmd( 'aapp', 'ai', 'notes' ) for 1 .. 2;
    $self->eq_or_die( $self->run_cmd( 'git', 'config', '--get-all', 'remote.origin.push' )->{out},  '', 'no push refspec' );
    $self->eq_or_die( $self->run_cmd( 'git', 'config', '--get-all', 'remote.origin.fetch' )->{out}, '', 'no fetch refspec' );
    return 1;
}

sub test_commit_msg_conciseness
{
    my ($self) = @_;
    $self->eq_or_die( hook_says( $self, msg( 'ok', $OK_MSG ) ), 'PASS', 'a subject within 72' );
    $self->eq_or_die(
        hook_says( $self, msg( 'long', "feat: add concise subject that intentionally exceeds seventy two characters limit by continuing further\n\nBody." ) ),
        'BLOCK', 'a subject over 72' );
    $self->ok_cmd( 'git', 'config', 'aapp.subjectMaxLen', '50' );
    $self->eq_or_die( hook_says( $self, msg( 'len55', "feat: subject with 55 characters length exceeds fifty\n\nBody." ) ), 'BLOCK',
        'a subject over aapp.subjectMaxLen' );
    $self->ok_cmd( 'git', 'config', '--unset', 'aapp.subjectMaxLen' );
    $self->eq_or_die( hook_says( $self, msg( 'noblank', "feat: valid subject\nThis is line 2 without an empty line separator." ) ), 'BLOCK',
        'no blank line 2' );
    $self->eq_or_die(
        hook_says(
            $self,
            msg( 'wide',
                "feat: valid subject\n\nThis line is intentionally constructed to exceed one hundred characters in length without wrapping onto the next line." )
        ),
        'BLOCK', 'a body line over 100'
    );
    $self->eq_or_die(
        hook_says(
            $self,
            msg( 'url',
                "feat: valid subject\n\nHere is a link: https://github.com/aapp-protocol/agent-planning-kit/issues/very-long-issue-identifier-that-exceeds-one-hundred-chars"
            )
        ),
        'PASS', 'a long line holding a URL'
    );
    $self->eq_or_die( hook_says( $self, msg( 'many', "feat: valid subject\n\n" . lines_of(21) ) ), 'BLOCK', 'a body over 20 lines' );
    $self->eq_or_die( hook_says( $self, msg( 'revert', "Revert \"feat: something\"\n\nThis reverts commit 1234567890abcdef.\n" . lines_of(21) ) ),
        'PASS', 'a revert with a long body' );
    return 1;
}

sub test_coauthor_refused_in_every_mode
{
    my ($self) = @_;
    my $banned = msg( 'banned', "feat: valid subject\n\nCo-authored-by: Antigravity <antigravity\@google.com>" );
    foreach my $mode (qw(none lax strict notes)) {
        $self->ok_cmd( 'git', 'config', 'aapp.aiAttribution', $mode );
        $self->eq_or_die( hook_says( $self, $banned ), 'BLOCK', "a co-author in $mode" );
    }
    return 1;
}

sub test_attribution_modes
{
    my ($self) = @_;
    my ( $ok, $full ) = ( msg( 'ok', $OK_MSG ), msg( 'full', $FULL_MSG ) );
    my $partial = msg( 'partial', "feat: valid subject\n\nAI-Agent: Claude" );
    my $mode    = sub { $self->ok_cmd( 'git', 'config', 'aapp.aiAttribution', $_[0] ) };
    $mode->('none');
    $self->eq_or_die( hook_says( $self, $full ), 'BLOCK', 'none refuses trailers' );
    $mode->('lax');
    $self->eq_or_die( hook_says( $self, $ok ),      'PASS',  'lax takes a human commit' );
    $self->eq_or_die( hook_says( $self, $partial ), 'BLOCK', 'lax checks partial trailers' );
    $self->eq_or_die( hook_says( $self, $full ),    'PASS',  'lax takes full trailers' );
    $mode->('strict');
    my $r = $self->run_cmd( Cwd::getcwd() . '/.githooks/aapp-commit-msg', $ok );
    $self->true_or_die( $r->{exit} != 0, 'strict refuses no trailers' );
    $self->match_or_die( $r->{out} . $r->{err}, qr/aapp ai lax/, 'the refusal names aapp ai lax' );
    $self->eq_or_die( hook_says( $self, $full ), 'PASS', 'strict takes full trailers' );
    $self->eq_or_die( hook_says( $self, msg( 'revert2', "Revert \"feat: previous commit\"\n\nThis reverts commit 1234567890abcdef1234567890abcdef12345678." ) ),
        'PASS', 'strict lets a revert through' );
    $mode->('commit');
    $r = $self->run_cmd( Cwd::getcwd() . '/.githooks/aapp-commit-msg', $full );
    $self->true_or_die( $r->{exit} != 0, 'the retired commit mode is refused' );
    $self->match_or_die( $r->{out} . $r->{err}, qr/ai lax|ai strict/i, 'the refusal names the modes to use' );
    return 1;
}

sub test_staged_note_attaches_to_its_commit
{
    my ($self) = @_;
    plain_hooks( $self, 'notes' );
    commit_file( $self, 'c1', 'chore: commit without staged note' );
    $self->eq_or_die( $self->run_cmd( 'git', 'notes', '--ref=refs/notes/commits', 'list', 'HEAD' )->{out}, '', 'no staged note, no note' );
    my $m = 'feat: implement feature with staged note';
    $self->ok_cmd( 'aapp', 'note', 'stage', 'msg', $m, 'agent', 'Antigravity', 'vendor', 'Google', 'model', 'gemini-1.5-pro' );
    $self->file_exists_or_die( buffer_of( $self, $m ) );
    commit_file( $self, 'c2', $m );
    my $note = note_on( $self, 'ai' );
    $self->match_or_die( $note, qr/AI-Agent: Antigravity/,    'the note names the agent' );
    $self->match_or_die( $note, qr/AI-Model: gemini-1\.5-pro/, 'and the model' );
    $self->true_or_die( !-e buffer_of( $self, $m ), 'the buffer is unlinked' );
    $m = 'feat: commit with custom note body';
    $self->ok_cmd( 'aapp', 'note', 'stage', 'Custom Benchmarking Payload: benchmark_id=42', 'msg', $m );
    commit_file( $self, 'c3', $m );
    $self->eq_or_die( note_on( $self, 'commits' ), 'Custom Benchmarking Payload: benchmark_id=42', 'the note is verbatim' );
    AAPP::Tests::write_text( 'c3.txt', "c3\namended\n" );
    $self->ok_cmd( 'git', 'add', 'c3.txt' );
    $self->ok_cmd( 'git', 'commit', '-q', '--amend', '--no-edit' );
    $self->eq_or_die( note_on( $self, 'commits' ), 'Custom Benchmarking Payload: benchmark_id=42', 'the note survives an amend' );
    return 1;
}

sub test_staged_note_kept_when_attaching_fails
{
    my ($self) = @_;
    plain_hooks( $self, 'notes' );
    my $m = 'feat: intentional attachment failure test';
    $self->ok_cmd( 'aapp', 'note', 'stage', 'msg', $m, 'agent', 'Claude' );
    my $lock = $self->ok_cmd( 'git', 'rev-parse', '--git-path', 'refs/notes/ai.lock' )->{out} =~ s/\s+\z//r;
    $self->ok_cmd( 'mkdir', '-p', $lock );
    commit_file( $self, 'fail', $m );
    rmdir($lock) or die "cannot remove $lock: $!\n";
    $self->file_exists_or_die( buffer_of( $self, $m ) );
    return 1;
}

sub test_stale_note_buffer_reaped
{
    my ($self) = @_;
    plain_hooks( $self, 'notes' );
    my $m = 'feat: uncommitted idea that aged out';
    $self->ok_cmd( 'aapp', 'note', 'stage', 'msg', $m, 'agent', 'StaleAgent' );
    my $buffer = buffer_of( $self, $m );
    my $old    = time() - 2 * 24 * 3600;
    utime( $old, $old, $buffer ) or die "cannot age $buffer: $!\n";
    commit_file( $self, 'ttl', 'chore: trigger ttl sweep' );
    $self->true_or_die( !-e $buffer, 'the stale buffer is removed' );
    return 1;
}

sub test_credits_follow_mode_and_history
{
    my ($self) = @_;
    plain_hooks( $self, 'none' );
    AAPP::Tests::write_text( 'README.md', "# Test Project\nInitial readme content.\n" );
    foreach my $mode (qw(none notes)) {
        $self->ok_cmd( 'git', 'config', 'aapp.aiAttribution', $mode );
        $self->run_cmd( 'aapp', 'ai', 'credits' );
        $self->true_or_die( index( AAPP::Tests::read_text('README.md'), '<!-- AAPP-AI-CREDITS:START -->' ) < 0, "no block written in $mode" );
    }
    AAPP::Tests::write_text( 'README.md', AAPP::Tests::read_text('README.md') . "\n" . block_with('Claude (Anthropic)') );
    my $before = readme_sum();
    $self->run_cmd( 'aapp', 'ai', 'credits' );
    $self->eq_or_die( readme_sum(), $before, 'notes mode keeps a hand-written block' );
    $self->ok_cmd( 'git', 'config', 'aapp.aiAttribution', 'strict' );
    AAPP::Tests::write_text( 'code.txt', "code\n" );
    $self->ok_cmd( 'git', 'add', 'code.txt' );
    $self->ok_cmd( 'git', 'commit', '-qm', "feat: first agent commit\n\nAI-Agent: Antigravity\nAI-Vendor: Google\nAI-Model: gemini-1.5-pro" );
    $self->ok_cmd( 'aapp', 'ai', 'credits' );
    my $text = AAPP::Tests::read_text('README.md');
    $self->true_or_die( index( $text, '- Antigravity (Google)' ) >= 0 && index( $text, '- Claude (Anthropic)' ) >= 0, 'the roster is the union of block and history' );
    my ($first) = $text =~ /^\s*- (.*)$/m;
    $self->eq_or_die( $first // '', 'Antigravity (Google)', 'listed in byte order' );
    $before = readme_sum();
    $self->ok_cmd( 'aapp', 'ai', 'credits' );
    $self->eq_or_die( readme_sum(), $before, 'regeneration is stable' );
    $self->ok_cmd( 'aapp', 'ai', 'none' );
    $before = readme_sum();
    $self->run_cmd( 'aapp', 'ai', 'credits' );
    $self->eq_or_die( readme_sum(), $before, 'after ai none nothing changes' );
    return 1;
}

sub test_credits_refuse_broken_block
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.aiAttribution', 'strict' );
    AAPP::Tests::write_text( 'README.md', "<!-- AAPP-AI-CREDITS:START -->\nBroken block missing end tag\n" );
    $self->fail_cmd( 'aapp', 'ai', 'credits' );
    AAPP::Tests::write_text( 'README.md', "<!-- AAPP-AI-CREDITS:END -->\n<!-- AAPP-AI-CREDITS:START -->\n" );
    $self->fail_cmd( 'aapp', 'ai', 'credits' );
    return 1;
}

sub test_credits_alias_map
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.aiAttribution', 'strict' );
    AAPP::Tests::write_text( 'README.md', "# Project\n" . block_with('Claude Code (Anthropic)') );
    $self->ok_cmd( 'git', 'config', '--add', 'aapp.aiAlias', 'Claude Code=Claude' );
    $self->run_cmd( 'aapp', 'ai', 'credits' );
    my $text = AAPP::Tests::read_text('README.md');
    $self->true_or_die( index( $text, '- Claude (Anthropic)' ) >= 0 && index( $text, '- Claude Code (Anthropic)' ) < 0, 'the alias merges the identity', $text );
    return 1;
}

sub test_identity_precedence
{
    my ($self) = @_;
    my $resolve = sub { $self->lib_call( 'attribution', 'resolve_ai_identity', @_ )->{out} };
    $self->ok_cmd( 'git', 'config', "aapp.$_->[0]", $_->[1] ) for [ aiAgent => 'RepoAgent' ], [ aiVendor => 'RepoVendor' ], [ aiModel => 'RepoModel' ];
    $self->eq_or_die( $resolve->( '', '', '', '' ), '', 'the repository config is ignored' );
    $self->ok_cmd( 'git', 'config', 'extensions.worktreeConfig', 'true' );
    $self->ok_cmd( 'git', 'config', '--worktree', "aapp.$_->[0]", $_->[1] ) for [ aiAgent => 'WkAgent' ], [ aiVendor => 'WkVendor' ], [ aiModel => 'WkModel' ];
    $self->match_or_die( $resolve->( '', '', '', '' ), qr/WkAgent/, 'the worktree config is used' );
    local $ENV{AAPP_AGENT_NAME}   = 'EnvAgent';
    local $ENV{AAPP_AGENT_VENDOR} = 'EnvVendor';
    local $ENV{AAPP_AGENT_MODEL}  = 'EnvModel';
    $self->match_or_die( $resolve->( '', '', '', '' ),                             qr/EnvAgent/,   'the environment beats the worktree config' );
    $self->match_or_die( $resolve->( 'ParamAgent', 'ParamVendor', 'ParamModel', '' ), qr/ParamAgent/, 'parameters beat the environment' );
    return 1;
}

sub test_coauthor_converted_with_warning
{
    my ($self) = @_;
    my $co = msg( 'coauthor', "feat: test subject\n\nCo-authored-by: Claude <noreply.anthropic.com>" );
    my $r  = $self->lib_call( 'attribution', 'resolve_ai_identity', '', '', '', $co );
    $self->match_or_die( $r->{err}, qr/warning/i, 'a warning' );
    $self->match_or_die( $r->{out}, qr/Claude/,   'the co-author becomes the identity' );
    return 1;
}

sub test_strict_decorate_without_identity_refused
{
    my ($self) = @_;
    $self->ok_cmd( 'git', 'config', 'aapp.aiAttribution', 'strict' );
    $self->true_or_die( $self->lib_call( 'attribution', 'attribution_decorate', msg( 'decorate', $OK_MSG ), '' )->{exit} != 0, 'decorating without an identity fails' );
    return 1;
}

sub test_note_text_without_identity_refused
{
    my ($self) = @_;
    plain_hooks( $self, 'notes' );
    commit_file( $self, 'base', 'chore: a commit to note' );
    my $head = $self->ok_cmd( 'git', 'rev-parse', 'HEAD' )->{out} =~ s/\s+\z//r;
    my $r    = $self->lib_call( 'attribution', 'attribution_note', $head, '', 'some text' );
    $self->true_or_die( $r->{exit} != 0, 'note text without an identity fails' );
    $self->true_or_die( $r->{err} ne '', 'and says why' );
    return 1;
}

sub test_note_identity_only_passes
{
    my ($self) = @_;
    plain_hooks( $self, 'notes' );
    commit_file( $self, 'base', 'chore: a commit to note' );
    my $head = $self->ok_cmd( 'git', 'rev-parse', 'HEAD' )->{out} =~ s/\s+\z//r;
    $self->eq_or_die( $self->lib_call( 'attribution', 'attribution_note', $head, 'Claude (Anthropic)', '' )->{exit}, 0, 'an identity-only note is written' );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
