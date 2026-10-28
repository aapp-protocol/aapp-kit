package AAPP::T::Verb::Review;

use strict;
use warnings;
use utf8;
use 5.026;

use File::Path ();
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/verbs/review.md. Run alone: prove -l t/verb/review.t

our $UNDER_REVIEW = '.plans/current/P3-draft-me.md';
our $FROZEN       = '.plans/current/P4-frozen-one.md';
our $WIDGET       = '.plans/current/P5-widget.md';
our $ELSEWHERE    = '.plans/current/P6-elsewhere.md';
our $MEMBER       = '.plans/current/P7-member.md';
our $AMENDMENTS   = '.plans/current/P2-group-amendments.md';

# Usage     : my $text = plan_text($id, $slug, $status, %field)
# Purpose   : A small plan file: header (with any extra '* **<Field>:**' lines), §2, Target Files, §6.
# Returns   : The text.
sub plan_text
{
    my ( $id, $title, $status, $target, @extra ) = @_;
    my $head = join( '', map { "* **$_->[0]:** $_->[1]\n" } @extra );
    return "# 🗺️ Plan P-$id: $title\n* **Plan ID:** P-$id\n* **Changelog:** Added: $title\n$head* **Status:** $status\n* **Commits:** none\n\n"
        . "## 1. Context & Architectural Goal\nFixture plan.\n\n## 2. Technical Blueprint\nNothing yet.\n\n"
        . "## 💥 4. Blast Radius & System Boundaries\n\n### 📂 Target Files (Modifications & Additions)\n- [ ] `$target` -> the change.\n\n"
        . "### 🛑 Out of Bounds (Do Not Touch)\n\n## 📦 6. Change Log & Refinement History\n* **2026-10-28:** Drafted.\n";
}

# Usage     : fixture($self)
# Purpose   : An initialized project with plans in every Status the verb meets, a group with its amendments
#             member and two requests, a pickup topic, P-5 bound to this checkout and an event log.
# Returns   : 1
sub fixture
{
    my ($self) = @_;
    $self->init_project();
    AAPP::Tests::write_text( $UNDER_REVIEW, plan_text( 3, 'Draft Me',   '🟣 Under Review', 'src/draft.py' ) );
    AAPP::Tests::write_text( $FROZEN,       plan_text( 4, 'Frozen One', '🔷 Frozen',       'src/frozen.py' ) );
    AAPP::Tests::write_text( $WIDGET,       plan_text( 5, 'Widget',     '⚡ In Development', 'src/widget.py' ) );
    AAPP::Tests::write_text( $ELSEWHERE,
        plan_text( 6, 'Elsewhere', '⚡ In Development', 'src/elsewhere.py', [ 'Worktree', '.workspace/P6 (plan/P6-elsewhere)' ] ) );
    AAPP::Tests::write_text( $MEMBER, plan_text( 7, 'Member', '⚡ In Development', 'src/member.py', [ 'Group', 'P-1' ] ) );
    AAPP::Tests::write_text( '.plans/current/P1-group.md',
        "# 🧩 Group Plan P-1: Group\n* **Plan ID:** P-1\n* **Status:** ⚡ In Development\n* **Members:** P-7, P-2\n\n## 1. Goal\nFixture group.\n" );
    AAPP::Tests::write_text( $AMENDMENTS,
        "# 🗺️ Plan P-2: Group Amendments\n* **Plan ID:** P-2\n* **Kind:** amendments\n* **Group:** P-1\n* **Status:** ⚡ In Development\n\n"
            . "## 1. Context & Architectural Goal\nFixture ledger.\n\n## Scope Requests\n"
            . "- **R1** 2026-10-28 · P-7 · `lib/pending.py` · needs pending — pending\n"
            . "- **R2** 2026-10-28 · P-7 · `lib/landed.py` · needs landed — committed\n\n## Decisions\n\n## Follow-ups\n" );
    AAPP::Tests::write_text( '.plans/pickup.md', AAPP::Tests::read_text('.plans/pickup.md') . "- [ ] Review Topic: whether the topic needs its own plan\n" );
    $self->ok_cmd( 'git', '-C', '.plans', 'add', '-A' );
    $self->ok_cmd( 'git', '-C', '.plans', 'commit', '-qm', 'fixture plans', '--no-verify' );
    $self->ok_cmd( 'git', 'config', 'aapp.perlLogFile', 'aapp.log' );
    $self->ok_cmd( 'aapp', 'active', 'P-5' );
    return 1;
}

# Usage     : my $r = review($self, @args)
# Purpose   : Runs 'aapp review' with a fixed reviewer identity.
# Returns   : { exit, out, err, all }.
sub review
{
    my ( $self, @args ) = @_;
    local $ENV{AAPP_AGENT_NAME} = 'TestAgent';
    my $r = $self->run_aapp( 'review', @args );
    $r->{all} = $r->{out} . $r->{err};
    return $r;
}

# Usage     : my $sha = plans_head($self)
# Purpose   : The plans worktree's HEAD, to see whether a step committed.
# Returns   : The hash.
sub plans_head
{
    my ($self) = @_;
    return $self->ok_cmd( 'git', '-C', '.plans', 'rev-parse', 'HEAD' )->{out} =~ s/\s+$//r;
}

# Usage     : refused($self, $r, qr/why/, 'what was refused', $head_before, $file, $text_before)
# Purpose   : Asserts a refusal: exit 1 with the reason, no plans commit, the file unchanged.
# Returns   : 1
sub refused
{
    my ( $self, $r, $why, $what, $head, $file, $before ) = @_;
    $self->eq_or_die( $r->{exit}, 1, "$what exits 1" );
    $self->match_or_die( $r->{all}, $why, "$what names the reason" );
    $self->eq_or_die( plans_head($self), $head, "$what commits nothing" );
    $self->eq_or_die( AAPP::Tests::read_text($file), $before, "$what leaves $file unchanged" ) if defined $file;
    return 1;
}

sub test_bare_lists_words
{
    my ($self) = @_;
    my $r = review($self);
    $self->eq_or_die( $r->{exit}, 0, 'bare review exits 0' );
    $self->match_or_die( $r->{all}, qr/\bdraft\b.*\bflag\b.*\bfix\b.*\bcheck\b/s, 'bare review lists the words' );
    $r = review( $self, 'frob', 'P-5' );
    $self->eq_or_die( $r->{exit}, 1, 'an unknown word exits 1' );
    $self->match_or_die( $r->{all}, qr/frob.*draft.*flag.*fix.*check/s, 'an unknown word is refused naming the words' );
    return 1;
}

sub test_draft_by_id_writes_rfc
{
    my ($self) = @_;
    my $head = plans_head($self);
    my $r    = review( $self, 'draft', 'P-3' );
    $self->eq_or_die( $r->{exit}, 0, 'draft <id> exits 0' );
    my $rfc = '.plans/pickup/p3-draft-me-rfc.md';
    $self->file_exists_or_die($rfc);
    my $text = AAPP::Tests::read_text($rfc);
    $self->match_or_die( $text, qr/P-3/, 'the RFC names the plan' );
    $self->match_or_die( $text, qr/^## 1\. Scope & Question.*^## 2\. Current State.*^## 3\. Findings Log.*^## 4\. User Decisions.*^## 5\. Carried Into Plans/ms,
        'the RFC has the template sections' );
    $self->match_or_die( $r->{out}, qr/p3-draft-me-rfc\.md/, 'stdout names the RFC' );
    $self->eq_or_die( plans_head($self), $head, 'draft commits nothing' );
    return 1;
}

sub test_draft_by_slug_quotes_pickup_line
{
    my ($self) = @_;
    my $r = review( $self, 'draft', 'review-topic' );
    $self->eq_or_die( $r->{exit}, 0, 'draft <slug> exits 0' );
    my $rfc = '.plans/pickup/review-topic-rfc.md';
    $self->file_exists_or_die($rfc);
    my ($scope) = AAPP::Tests::read_text($rfc) =~ /^## 1\. Scope & Question\n(.*?)^## 2\./ms;
    $self->match_or_die( $scope // '', qr/whether the topic needs its own plan/, '§1 quotes the pickup line' );
    return 1;
}

sub test_draft_refusals
{
    my ($self) = @_;
    my $head = plans_head($self);
    $self->eq_or_die( review( $self, 'draft', 'P-3' )->{exit}, 0, 'the first draft passes' );
    my $rfc    = '.plans/pickup/p3-draft-me-rfc.md';
    my $before = AAPP::Tests::read_text($rfc);
    refused( $self, review( $self, 'draft', 'P-3' ), qr/p3-draft-me-rfc\.md/, 'an existing RFC', $head, $rfc, $before );
    refused( $self, review( $self, 'draft', '!!!' ), qr/slug/i, 'an empty slug', $head );
    refused( $self, review( $self, 'draft', 'P-5' ), qr/In Development/, 'draft of a ⚡ plan', $head );
    $self->true_or_die( !-e '.plans/pickup/p5-widget-rfc.md', 'no RFC for the ⚡ plan' );
    return 1;
}

sub test_flag_appends_signed_finding
{
    my ($self) = @_;
    my $r = review( $self, 'flag', 'P-5', 'the widget leaks a handle' );
    $self->eq_or_die( $r->{exit}, 0, 'flag exits 0' );
    my $text = AAPP::Tests::read_text($WIDGET);
    $self->match_or_die( $text, qr/^## 🔍 7\. Implementation Review$/m, '§7 heading written' );
    $self->match_or_die( $text, qr/^- \*\*F1\*\* \d{4}-\d\d-\d\d · TestAgent · the widget leaks a handle — open$/m, 'F1 is signed and open' );
    $self->eq_or_die( $self->ok_cmd( 'git', '-C', '.plans', 'log', '-1', '--format=%s' )->{out}, "plan(review): P-5 F1 flagged\n", 'one plans commit' );
    $self->eq_or_die( $self->ok_cmd( 'git', '-C', '.plans', 'show', '--name-only', '--format=', 'HEAD' )->{out}, "current/P5-widget.md\n",
        'the commit holds the plan file only' );
    return 1;
}

sub test_flag_numbers_and_marks_outside_targets
{
    my ($self) = @_;
    $self->eq_or_die( review( $self, 'flag', 'P-5', 'first', 'file', 'src/widget.py' )->{exit}, 0, 'F1 inside targets' );
    $self->eq_or_die( review( $self, 'flag', 'P-5', 'second', 'file', 'lib/other.py' )->{exit}, 0, 'F2 outside targets' );
    my $text = AAPP::Tests::read_text($WIDGET);
    $self->match_or_die( $text, qr/^- \*\*F1\*\* .* · `src\/widget\.py` · first — open$/m, 'a file inside the targets is named plainly' );
    $self->match_or_die( $text, qr/^- \*\*F2\*\* .* · `lib\/other\.py` \(outside targets: needs an amendment\) · second — open$/m,
        'a file outside the targets needs an amendment' );
    return 1;
}

sub test_flag_and_fix_refuse_by_status
{
    my ($self) = @_;
    my $head = plans_head($self);
    my $before = AAPP::Tests::read_text($UNDER_REVIEW);
    refused( $self, review( $self, 'flag', 'P-3', 'x' ), qr/design findings go in the plan's RFC/, 'flag on a 🟣 plan', $head, $UNDER_REVIEW, $before );
    refused( $self, review( $self, 'fix', 'P-3', 'F1', 'x' ), qr/design findings go in the plan's RFC/, 'fix on a 🟣 plan', $head, $UNDER_REVIEW, $before );
    $before = AAPP::Tests::read_text($FROZEN);
    refused( $self, review( $self, 'flag', 'P-4', 'x' ), qr/Frozen/, 'flag on a 🔷 plan', $head, $FROZEN, $before );
    refused( $self, review( $self, 'fix', 'P-4', 'F1', 'x' ), qr/Frozen/, 'fix on a 🔷 plan', $head, $FROZEN, $before );
    return 1;
}

sub test_fix_task_plans_finding
{
    my ($self) = @_;
    review( $self, 'flag', 'P-5', 'the widget leaks a handle' );
    my $r = review( $self, 'fix', 'P-5', 'F1', 'close the handle in finally' );
    $self->eq_or_die( $r->{exit}, 0, 'fix exits 0' );
    my $text = AAPP::Tests::read_text($WIDGET);
    $self->match_or_die( $text, qr/^## 🧩 8\. Review Fixes$/m, '§8 heading written' );
    $self->match_or_die( $text, qr/^- \[ \] F1: close the handle in finally$/m, 'the task is written' );
    $self->match_or_die( $text, qr/^- \*\*F1\*\* .* — planned$/m, 'F1 is planned' );
    return 1;
}

sub test_fix_refuses_non_owner
{
    my ($self) = @_;
    review( $self, 'flag', 'P-6', 'found elsewhere' );
    my $head   = plans_head($self);
    my $before = AAPP::Tests::read_text($ELSEWHERE);
    refused( $self, review( $self, 'fix', 'P-6', 'F1', 'a task' ), qr/only \.workspace\/P6 answers its review/, 'fix from a checkout that does not own the plan',
        $head, $ELSEWHERE, $before );
    return 1;
}

sub test_fix_done_and_decline
{
    my ($self) = @_;
    review( $self, 'flag', 'P-5', 'one' );
    review( $self, 'flag', 'P-5', 'two' );
    my $head   = plans_head($self);
    my $before = AAPP::Tests::read_text($WIDGET);
    refused( $self, review( $self, 'fix', 'done', 'P-5', 'F1' ), qr/F1 is open/, 'fix done on an open finding', $head, $WIDGET, $before );
    refused( $self, review( $self, 'fix', 'decline', 'P-5', 'F1', '' ), qr/reason/, 'fix decline without a reason', $head, $WIDGET, $before );
    $self->eq_or_die( review( $self, 'fix', 'P-5', 'F1', 'do one' )->{exit}, 0, 'F1 planned' );
    $head   = plans_head($self);
    $before = AAPP::Tests::read_text($WIDGET);
    refused( $self, review( $self, 'fix', 'P-5', 'F1', 'again' ), qr/F1 is planned/, 'a second task for a planned finding', $head, $WIDGET, $before );
    $self->eq_or_die( review( $self, 'fix', 'done', 'P-5', 'F1' )->{exit}, 0, 'fix done exits 0' );
    $self->eq_or_die( review( $self, 'fix', 'decline', 'P-5', 'F2', 'by design' )->{exit}, 0, 'fix decline exits 0' );
    my $text = AAPP::Tests::read_text($WIDGET);
    $self->match_or_die( $text, qr/^- \[x\] F1: do one$/m, 'the task is ticked' );
    $self->match_or_die( $text, qr/^- \*\*F1\*\* .* — done$/m, 'F1 is done' );
    $self->match_or_die( $text, qr/^- \*\*F2\*\* .* — declined: by design$/m, 'F2 is declined with its reason' );
    $self->true_or_die( $text !~ /F2:/, 'a declined finding has no task' );
    return 1;
}

sub test_fix_done_waits_for_amendment
{
    my ($self) = @_;
    $self->ok_cmd( 'aapp', 'active', 'P-7' );
    review( $self, 'flag', 'P-7', 'outside one', 'file', 'lib/pending.py' );
    review( $self, 'flag', 'P-7', 'outside two', 'file', 'lib/landed.py' );
    review( $self, 'flag', 'P-7', 'outside three', 'file', 'lib/none.py' );
    review( $self, 'fix', 'P-7', 'F1', 'write pending (R1)' );
    review( $self, 'fix', 'P-7', 'F2', 'write landed (R2)' );
    review( $self, 'fix', 'P-7', 'F3', 'write it without a request' );
    my $head   = plans_head($self);
    my $before = AAPP::Tests::read_text($MEMBER);
    refused( $self, review( $self, 'fix', 'done', 'P-7', 'F1' ), qr/R1/, 'a pending request', $head, $MEMBER, $before );
    refused( $self, review( $self, 'fix', 'done', 'P-7', 'F3' ), qr/lib\/none\.py/, 'no request named', $head, $MEMBER, $before );
    $self->eq_or_die( review( $self, 'fix', 'done', 'P-7', 'F2' )->{exit}, 0, 'a committed request lets the fix pass' );
    $self->match_or_die( AAPP::Tests::read_text($MEMBER), qr/^- \[x\] F2: write landed \(R2\)$/m, 'F2 ticked' );
    return 1;
}

sub test_check_reports_open_items
{
    my ($self) = @_;
    my $r = review( $self, 'check', 'P-5' );
    $self->eq_or_die( $r->{exit}, 0, 'no §7: clear' );
    review( $self, 'flag', 'P-5', 'one' );
    review( $self, 'flag', 'P-5', 'two' );
    review( $self, 'fix', 'P-5', 'F2', 'do two' );
    $r = review( $self, 'check', 'P-5' );
    $self->eq_or_die( $r->{exit}, 1, 'open items: exit 1' );
    $self->match_or_die( $r->{all}, qr/F1.*one/s, 'the open finding is listed' );
    $self->match_or_die( $r->{all}, qr/F2: do two/, 'the unticked task is listed' );
    review( $self, 'fix', 'decline', 'P-5', 'F1', 'not needed' );
    review( $self, 'fix', 'done', 'P-5', 'F2' );
    $r = review( $self, 'check', 'P-5' );
    $self->eq_or_die( $r->{exit}, 0, 'every finding answered: exit 0' );
    $self->match_or_die( $r->{out}, qr/P-5 clear/, 'check says clear' );
    return 1;
}

sub test_events_are_logged
{
    my ($self) = @_;
    review( $self, 'draft', 'P-3' );
    review( $self, 'flag', 'P-5', 'one', 'file', 'lib/other.py' );
    review( $self, 'fix', 'P-5', 'F1', 'do it' );
    my $log = AAPP::Tests::read_text('.git/aapp.log');
    $self->match_or_die( $log, qr/"command":"review".*"event":"draft".*p3-draft-me-rfc\.md/, 'review.draft logged with its file' );
    $self->match_or_die( $log, qr/"command":"review".*"event":"flag".*"finding":"F1".*"outside_targets":true/, 'review.flag logged with its fields' );
    $self->match_or_die( $log, qr/"command":"review".*"event":"fix".*"action":"task"/, 'review.fix logged with its action' );
    return 1;
}

1;
