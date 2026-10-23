package AAPP::T::Core::TemplateSync;

use strict;
use warnings;
use utf8;
use 5.026;

use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/template_sync.md. Run alone: prove -l t/core/template_sync.t

our $PLAN_TEMPLATE = '.plans/plan-template.md';
our $UNCLOSED      = 'Found unclosed <!-- AAPP-PROTOCOL:START --> marker';

# Usage     : fixture($self)
# Purpose   : A repository with a README committed and the kit initialized.
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    $self->init_repo();
    AAPP::Tests::write_text( 'README.md', "# Starter\n" );
    $self->ok_cmd( 'git', 'add', 'README.md' );
    $self->ok_cmd( 'git', 'commit', '-qm', 'initial commit' );
    $self->ok_cmd( 'aapp', 'init' );
    return 1;
}

# Usage     : my $r = init($self)
# Purpose   : Reruns aapp init.
# Returns   : { exit, out, err, all }.
sub init
{
    my ($self) = @_;
    my $r = $self->run_cmd( 'aapp', 'init' );
    $r->{all} = $r->{out} . $r->{err};
    return $r;
}

# Usage     : append($file, $text) / text($file)
# Purpose   : Appends to a file / reads it.
# Returns   : 1 / the text.
sub append { my ( $file, $text ) = @_; AAPP::Tests::write_text( $file, AAPP::Tests::read_text($file) . $text ); return 1; }
sub text   { my ($file) = @_; return AAPP::Tests::read_text($file); }

sub test_init_provisions_templates
{
    my ($self) = @_;
    $self->file_exists_or_die($_) for $PLAN_TEMPLATE, '.plans/release/release_checklist.md', '.plans/done/000-archive-ledger.md';
    return 1;
}

sub test_block_update_keeps_custom_sections
{
    my ($self) = @_;
    append( $PLAN_TEMPLATE, "\n## 7. Bespoke Project Architecture Matrix\n* custom section *\n" );
    init($self);
    $self->match_or_die( text($PLAN_TEMPLATE), qr/Bespoke Project Architecture Matrix/, 'the custom section is kept' );
    $self->match_or_die( text($PLAN_TEMPLATE), qr/AAPP-PROTOCOL:START/,                 'the protocol block is there' );
    return 1;
}

sub test_safe_mode_writes_new_buffer
{
    my ($self) = @_;
    AAPP::Tests::write_text( $PLAN_TEMPLATE, "# Legacy Plan Template\n* Custom field without delimiter comments *\n" );
    my $out = init($self)->{all};
    $self->file_exists_or_die("$PLAN_TEMPLATE.new");
    $self->match_or_die( text($PLAN_TEMPLATE), qr/Legacy Plan Template/, 'the diverged template is kept' );
    $self->match_or_die( $out, qr/wrote updated template to \.plans\/plan-template\.md\.new/, 'and the buffer named' );
    return 1;
}

sub test_strict_mode_overwrites
{
    my ($self) = @_;
    AAPP::Tests::write_text( $PLAN_TEMPLATE, "# Obsolete Plan Template\n* Diverged content *\n" );
    $self->ok_cmd( 'git', 'config', 'aapp.templateSync', 'strict' );
    my $out = init($self)->{all};
    $self->match_or_die( text($PLAN_TEMPLATE), qr/<!-- AAPP-PROTOCOL:START/, 'the template is restored' );
    $self->true_or_die( text($PLAN_TEMPLATE) !~ /Obsolete Plan Template/, 'the diverged text is gone' );
    $self->match_or_die( $out, qr/\[strict\] Overwrote diverged template/, 'saying so' );
    return 1;
}

sub test_manual_mode_leaves_templates
{
    my ($self) = @_;
    AAPP::Tests::write_text( $PLAN_TEMPLATE, "# Manual Mode Custom Template\n" );
    $self->ok_cmd( 'git', 'config', 'aapp.templateSync', 'manual' );
    init($self);
    $self->match_or_die( text($PLAN_TEMPLATE), qr/Manual Mode Custom Template/, 'the template is unchanged' );
    $self->true_or_die( !-e "$PLAN_TEMPLATE.new", 'no .new buffer' );
    return 1;
}

sub test_inline_marker_mention_ignored
{
    my ($self) = @_;
    my $checklist = '.plans/release/release_checklist.md';
    append( $checklist, "- [ ] Checklist bullet mentioning `<!-- AAPP-PROTOCOL:START v1.0.0 -->` in prose\n" );
    $self->true_or_die( index( init($self)->{all}, $UNCLOSED ) < 0, 'no unclosed-marker warning' );
    $self->match_or_die( text($checklist), qr/Checklist bullet mentioning/, 'the bullet is kept' );
    return 1;
}

sub test_pickup_sync_keeps_ideas
{
    my ($self) = @_;
    append( '.plans/pickup.md', "- [ ] Revolutionary idea: quantum blast radius validation\n" );
    init($self);
    $self->match_or_die( text('.plans/pickup.md'), qr/Revolutionary idea/,     'the idea is kept' );
    $self->match_or_die( text('.plans/pickup.md'), qr/<!-- AAPP-PROTOCOL:START/, 'the protocol block is there' );
    return 1;
}

sub test_agents_sync_keeps_project_rules
{
    my ($self) = @_;
    append( '.agents/AGENTS.md', "\n## 🔒 Bespoke Security Guard\n- Custom policy.\n" );
    init($self);
    $self->match_or_die( text('.agents/AGENTS.md'), qr/Bespoke Security Guard/,   'the rule is kept' );
    $self->match_or_die( text('.agents/AGENTS.md'), qr/<!-- AAPP-PROTOCOL:START/, 'the protocol block is there' );
    return 1;
}

sub test_unclosed_marker_fails_safe
{
    my ($self) = @_;
    AAPP::Tests::write_text( '.plans/pickup.md',
        "<!-- AAPP-PROTOCOL:START v1.0.0 -->\nBroken unclosed instruction block\n- [ ] Precious unbacked idea that must survive\n" );
    my $r = init($self);
    $self->eq_or_die( $r->{exit}, 0, 'init completes' );
    $self->true_or_die( index( $r->{all}, $UNCLOSED ) >= 0, 'the unclosed block is reported', $r->{all} );
    $self->match_or_die( text('.plans/pickup.md'), qr/Precious unbacked idea/, 'the file is left intact' );
    return 1;
}

sub test_project_data_never_overwritten
{
    my ($self) = @_;
    append( '.plans/ISSUES.md', "| #999 | P1 | CORE | 2026-09-21 | lib/a.sh | Active custom bug | Fix | 🟠 Incubated |\n" );
    AAPP::Tests::write_text( '.agents/CODEMAP.md', "# Project Specific Architecture Map\n" );
    AAPP::Tests::write_text( '.agents/PROJECT.MD', "# Project Specific Profile\n" );
    init($self);
    $self->match_or_die( text('.plans/ISSUES.md'),   qr/#999/,                              'ISSUES.md is kept' );
    $self->match_or_die( text('.agents/CODEMAP.md'), qr/Project Specific Architecture Map/, 'CODEMAP.md is kept' );
    $self->match_or_die( text('.agents/PROJECT.MD'), qr/Project Specific Profile/,          'PROJECT.MD is kept' );
    return 1;
}

sub test_status_reports_synced
{
    my ($self) = @_;
    my $r = $self->run_cmd( 'aapp', 'status' );
    $self->match_or_die( $r->{out} . $r->{err}, qr/📑 Templates:  All worktree templates synced/, 'all templates synced' );
    return 1;
}

sub test_status_reports_drift
{
    my ($self) = @_;
    AAPP::Tests::write_text( $PLAN_TEMPLATE, "# Stale Plan Template\n<!-- Status must be exactly ONE of: Draft | In Progress -->\n" );
    my $r = $self->run_cmd( 'aapp', 'status' );
    $self->match_or_die( $r->{out} . $r->{err}, qr/📑 Templates:  1 template drifted.*-> run 'aapp init'/, 'one template drifted' );
    return 1;
}

sub test_start_skill_text
{
    my ($self) = @_;
    my $skill = text("$self->{kit}/templates/skills/aapp/SKILL.md");
    $self->match_or_die( $skill, qr/^name: aapp$/m, 'the skill names itself' );
    $self->true_or_die( index( $skill, $_ ) >= 0, "the skill names $_" ) for '.agents/AGENTS.md', 'aapp status', 'aapp help';
    $self->true_or_die( $skill !~ m{(?:^|[^.A-Za-z])/(?:home|Users)/|view_file|run_command|CommandLine}, 'no machine path or tool' );
    return 1;
}

sub test_init_installs_start_skill_and_onboarding
{
    my ($self) = @_;
    $self->file_exists_or_die('.agents/skills/aapp/SKILL.md');
    $self->true_or_die( -e '.claude/skills/aapp/SKILL.md', 'the skill is linked for Claude' );
    my ($item) = grep { index( $_, 'Onboarding:' ) >= 0 } split( /\n/, text('.plans/pickup.md') );
    $item //= '';
    $self->true_or_die( index( lc($item), lc($_) ) >= 0, "the onboarding item names $_", $item )
        for '.agents/CODEMAP.md', 'ARCHITECTURE.md', '.agents/PROJECT.MD', 'placeholder', 'entry point';
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
