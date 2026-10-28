package AAPP::Review;

use strict;
use warnings;
use utf8;
use 5.026;

use POSIX ();
use AAPP::Constants qw(RETURN_OK RETURN_FAIL RETURN_ERROR RETURN_NOT_FOUND);
use AAPP::Attribution ();
use AAPP::Logger ();
use AAPP::Paths ();
use AAPP::State ();
use AAPP::Text ();

# A plan's implementation review lives in two sections after its §6, written on first use.
our $FINDINGS_HEADING = '## 🔍 7. Implementation Review';
our $FIXES_HEADING    = '## 🧩 8. Review Fixes';

# The Status a form applies to, by name (never by glyph).
our @DESIGN_STATUSES      = ( 'Under Review', 'Refining' );
our @IMPLEMENTING_STATUSES = ('In Development');

# A request state that means its amendment commit has landed.
our $LANDED_STATE = qr/^(?:committed|landed\b|closed · landed\b|applied\b)/;

our $OUTSIDE_MARK = ' (outside targets: needs an amendment)';

# Usage     : my ($rc, $plan) = AAPP::Review::plan($query)
# Purpose   : Resolves a plan for a review form: its file (absolute and relative to the plans worktree),
#             Plan ID, number, slug and Status name.
# Returns   : (RETURN_OK, hashref); (RETURN_NOT_FOUND) or (RETURN_FAIL) after an [ ERROR ] line.
sub plan
{
    my ($query) = @_;
    if ( !defined $query || $query eq '' ) {
        AAPP::Logger::print_msg( 'ERROR', 'No plan given.' );
        return (RETURN_FAIL);
    }
    my $root = AAPP::Paths::resolve()->{root};
    my ( $rc, $rel ) = AAPP::State::resolve_plan_path( $query, 'review', 'current', $root );
    if ( $rc != RETURN_OK ) {
        return ($rc);
    }
    my $file = "$root/$rel";
    my $id   = AAPP::State::plan_id($file) // '';
    my ($num) = $id =~ /^P-([0-9]+)$/;
    my ($base) = $rel =~ m{([^/]+)\.md$};
    my $slug = ( $base // '' ) =~ s/^P[0-9]+-//r;
    my $status = AAPP::Text::strip_leading_emoji( AAPP::State::plan_field( $file, 'Status' ) // '' );
    return ( RETURN_OK, { file => $file, rel => $rel =~ s{^\.plans/}{}r, id => $id, num => $num, slug => $slug, status => $status } );
}

# Usage     : my $ok = AAPP::Review::status_is($plan, @names)
# Purpose   : Whether the plan's Status is one of the names.
# Returns   : 1 or 0.
sub status_is
{
    my ( $plan, @names ) = @_;
    foreach my $name (@names) {
        if ( index( $plan->{status}, $name ) == 0 ) {
            return 1;
        }
    }
    return 0;
}

# Usage     : my $rc = AAPP::Review::implementing($plan)
# Purpose   : The Status check of flag and fix: a design plan names its RFC, any other Status is named.
# Returns   : RETURN_OK when the plan is in development; RETURN_FAIL after an [ ERROR ] line.
sub implementing
{
    my ($plan) = @_;
    if ( status_is( $plan, @IMPLEMENTING_STATUSES ) ) {
        return RETURN_OK;
    }
    if ( status_is( $plan, @DESIGN_STATUSES ) ) {
        AAPP::Logger::print_msg( 'ERROR', "$plan->{id} is $plan->{status}: design findings go in the plan's RFC: aapp review draft $plan->{id}" );
        return RETURN_FAIL;
    }
    AAPP::Logger::print_msg( 'ERROR', "$plan->{id} is $plan->{status}: implementation review needs a plan in development." );
    return RETURN_FAIL;
}

# Usage     : my ($ok, $owner) = AAPP::Review::owner($plan)
# Purpose   : The P-99 owner rule: a plan in development is answered from its recorded worktree, else
#             from the checkout whose active buffer holds it.
# Returns   : (1) for this checkout; (0, the owner as text) otherwise.
sub owner
{
    my ($plan) = @_;
    my $paths = AAPP::Paths::resolve();
    my ($worktree) = AAPP::State::plan_worktree( $plan->{file} );
    if ( defined $worktree ) {
        my $want = AAPP::Paths::abs_path( $worktree, $paths->{primary_root} );
        if ( $want eq AAPP::Paths::abs_path( $paths->{root} ) ) {
            return (1);
        }
        return ( 0, $worktree );
    }
    my $held = AAPP::State::plan_held_by( $plan->{file}, AAPP::State::held_plans() );
    if ( defined $held ) {
        return ( 0, AAPP::Paths::rel_path( $paths->{primary_root}, $held ) );
    }
    my $active = AAPP::State::active_plan_id() // '';
    if ( $active ne '' && ( $active eq $plan->{id} || "P-$active" eq $plan->{id} || index( $plan->{rel}, $active ) >= 0 ) ) {
        return (1);
    }
    return ( 0, "the checkout whose active buffer holds it (aapp active $plan->{id})" );
}

# Usage     : my @findings = AAPP::Review::findings($file)
# Purpose   : The findings of §7, in file order.
# Returns   : List of { n, state, path, outside, text, line }.
sub findings
{
    my ($file) = @_;
    my @found;
    foreach my $line ( AAPP::State::plan_section( $file, 7 ) ) {
        if ( $line !~ /^- \*\*F([0-9]+)\*\* (.*) — (open|planned|done|declined: .*)$/ ) {
            next;
        }
        my ( $n, $body, $state ) = ( $1, $2, $3 );
        my ( $path, $outside );
        if ( $body =~ / · `([^`]+)`(\Q$OUTSIDE_MARK\E)? · / ) {
            ( $path, $outside ) = ( $1, defined $2 ? 1 : 0 );
        }
        push @found, { n => $n, state => $state, path => $path, outside => $outside // 0, text => $body, line => $line };
    }
    return @found;
}

# Usage     : my @tasks = AAPP::Review::tasks($file)
# Purpose   : The fix tasks of §8, in file order.
# Returns   : List of { n, done, task, line }.
sub tasks
{
    my ($file) = @_;
    my @found;
    foreach my $line ( AAPP::State::plan_section( $file, 8 ) ) {
        if ( $line =~ /^- \[([ xX])\] F([0-9]+): (.*)$/ ) {
            push @found, { n => $2, done => $1 eq ' ' ? 0 : 1, task => $3, line => $line };
        }
    }
    return @found;
}

# Usage     : my $finding = AAPP::Review::finding($file, 'F3')
# Purpose   : One finding of §7 by its label (F3 or 3).
# Returns   : The finding, or undef.
sub finding
{
    my ( $file, $label ) = @_;
    my ($n) = ( $label // '' ) =~ /^F?([0-9]+)$/;
    if ( !defined $n ) {
        return;
    }
    foreach my $f ( findings($file) ) {
        if ( $f->{n} == $n ) {
            return $f;
        }
    }
    return;
}

# Usage     : my $who = AAPP::Review::reviewer()
# Purpose   : The reviewer's name: the agent identity, else git's user.name.
# Returns   : The name ('unknown' when neither is set).
sub reviewer
{
    my $lines = AAPP::Attribution::resolve_ai_identity( '', '', '', undef ) // '';
    if ( $lines =~ /^AI-Agent:\s*(.+?)\s*$/m ) {
        return $1;
    }
    my ( $ok, $name ) = AAPP::Paths::git_capture( 'config', 'user.name' );
    if ( $ok && defined $name && $name =~ /\S/ ) {
        return $name =~ s/^\s+|\s+$//gr;
    }
    return 'unknown';
}

# Usage     : my $n = AAPP::Review::add_finding($plan, $text, $path)
# Purpose   : Appends a signed, open finding to §7 (written on first use); a path outside the Target
#             Files is marked as needing an amendment.
# Returns   : The finding's number, or undef when the file cannot be written.
sub add_finding
{
    my ( $plan, $text, $path ) = @_;
    my $max = 0;
    foreach my $f ( findings( $plan->{file} ) ) {
        $max = $f->{n} if $f->{n} > $max;
    }
    my $n     = $max + 1;
    my $where = '';
    if ( defined $path && $path ne '' ) {
        $where = "`$path`" . ( is_target( $plan, $path ) ? '' : $OUTSIDE_MARK ) . ' · ';
    }
    my $date = POSIX::strftime( '%Y-%m-%d', localtime );
    my $line = "- **F$n** $date · " . reviewer() . " · $where$text — open";
    return _append_to( $plan->{file}, $FINDINGS_HEADING, 7, $line ) ? $n : undef;
}

# Usage     : my $ok = AAPP::Review::is_target($plan, $path)
# Purpose   : Whether a path is one of the plan's Target Files (or under a target folder).
# Returns   : 1 or 0.
sub is_target
{
    my ( $plan, $path ) = @_;
    foreach my $target ( AAPP::State::plan_target_paths( $plan->{file} ) ) {
        if ( $path eq $target || ( $target =~ m{/$} && index( $path, $target ) == 0 ) ) {
            return 1;
        }
    }
    return 0;
}

# Usage     : my $ok = AAPP::Review::add_task($plan, $n, $task)
# Purpose   : Appends '- [ ] F<n>: <task>' to §8 (written on first use).
# Returns   : 1, or 0 when the file cannot be written.
sub add_task
{
    my ( $plan, $n, $task ) = @_;
    return _append_to( $plan->{file}, $FIXES_HEADING, 8, "- [ ] F$n: $task" );
}

# Usage     : my $ok = AAPP::Review::set_state($plan, $n, $state)
# Purpose   : Changes finding F<n>'s state, the only part of its line that ever changes.
# Returns   : 1, or 0 when the finding or the file is missing.
sub set_state
{
    my ( $plan, $n, $state ) = @_;
    return _rewrite( $plan->{file}, sub { $_[0] =~ s/^(- \*\*F\Q$n\E\*\* .* — )(?:open|planned|done|declined: .*)$/$1$state/ } );
}

# Usage     : my $ok = AAPP::Review::tick($plan, $n)
# Purpose   : Ticks F<n>'s task in §8.
# Returns   : 1, or 0 when the task or the file is missing.
sub tick
{
    my ( $plan, $n ) = @_;
    return _rewrite( $plan->{file}, sub { $_[0] =~ s/^- \[ \] (F\Q$n\E: )/- [x] $1/ } );
}

# Usage     : my ($ok, $why) = AAPP::Review::amendment_landed($plan, $finding, $task)
# Purpose   : The amendment a fix needs: every '(R<n>)' its task names has landed in the group's
#             amendments member, and a finding outside the Target Files names at least one.
# Returns   : (1) when the fix may be ticked; (0, the reason) otherwise.
sub amendment_landed
{
    my ( $plan, $finding, $task ) = @_;
    my @named = ( $task // '' ) =~ /\(R([0-9]+)\)/g;
    if ( !@named ) {
        if ( $finding->{outside} ) {
            return ( 0, "F$finding->{n} is about `$finding->{path}`, outside the Target Files: name its amendment request in the task, as (R<n>)" );
        }
        return (1);
    }
    my %state = requests($plan);
    foreach my $r (@named) {
        if ( !exists $state{$r} ) {
            return ( 0, "R$r is not a request of this plan's group" );
        }
        if ( $state{$r} !~ $LANDED_STATE ) {
            return ( 0, "R$r has not landed (it is $state{$r})" );
        }
    }
    return (1);
}

# Usage     : my %state = AAPP::Review::requests($plan)
# Purpose   : The request states of the plan's group amendments member ('## Scope Requests').
# Returns   : Map of request number to state; empty when the plan is in no group.
sub requests
{
    my ($plan) = @_;
    my $group = AAPP::State::plan_field( $plan->{file}, 'Group' ) // '';
    if ( $group !~ /^P-[0-9]+$/ ) {
        return ();
    }
    my $root = AAPP::Paths::resolve()->{root};
    my ( $rc, $rel ) = AAPP::State::resolve_plan_path( $group, 'review', 'current', $root );
    if ( $rc != RETURN_OK ) {
        return ();
    }
    my %state;
    foreach my $member ( AAPP::State::group_members("$root/$rel") ) {
        my ( $mrc, $mrel ) = AAPP::State::resolve_plan_path( $member, 'review', 'current', $root );
        if ( $mrc != RETURN_OK || ( AAPP::State::plan_field( "$root/$mrel", 'Kind' ) // '' ) ne 'amendments' ) {
            next;
        }
        my $in = 0;
        foreach my $line ( @{ AAPP::State::file_lines("$root/$mrel") // [] } ) {
            if ( $line =~ /^## / ) {
                $in = $line =~ /^## Scope Requests\s*$/ ? 1 : 0;
            } elsif ( $in && $line =~ /^- \*\*R([0-9]+)\*\* .* — (.+?)\s*$/ ) {
                $state{$1} = $2;
            }
        }
    }
    return %state;
}

# Usage     : my ($done, $total) = AAPP::Review::counts($file)
# Purpose   : A plan's review fixes as 'fixes <done>/<total>': ticked tasks of all tasks.
# Returns   : (done, total).
sub counts
{
    my ($file) = @_;
    my @tasks = tasks($file);
    return ( scalar( grep { $_->{done} } @tasks ), scalar(@tasks) );
}

# Usage     : my @open = AAPP::Review::gate($file)
# Purpose   : What stops a plan from landing: each open or planned finding and each unticked task.
# Returns   : List of lines to show; empty when the review is clear (or there is none).
sub gate
{
    my ($file) = @_;
    my @open;
    foreach my $f ( findings($file) ) {
        if ( $f->{state} eq 'open' || $f->{state} eq 'planned' ) {
            push @open, "F$f->{n} $f->{state}: $f->{text}";
        }
    }
    foreach my $t ( tasks($file) ) {
        if ( !$t->{done} ) {
            push @open, "F$t->{n}: $t->{task} (task not ticked)";
        }
    }
    return @open;
}

# Usage     : my $ok = _append_to($file, $heading, $number, $line)
# Purpose   : Appends a line to the end of a numbered section, writing the section at the end of the
#             file when it does not exist yet.
# Returns   : 1, or 0 when the file cannot be read or written.
sub _append_to
{
    my ( $file, $heading, $number, $line ) = @_;
    my @lines = @{ _read($file) // return 0 };
    my ( $start, $end );
    for my $i ( 0 .. $#lines ) {
        if ( !defined $start && $lines[$i] =~ /^## (?:[^0-9]*\s)?\Q$number\E\./ ) {
            $start = $i;
        } elsif ( defined $start && !defined $end && $lines[$i] =~ /^## / ) {
            $end = $i;
        }
    }
    if ( !defined $start ) {
        pop @lines while @lines && $lines[-1] eq '';
        push @lines, '', $heading, $line;
    } else {
        $end //= scalar(@lines);
        my $at = $end;
        $at-- while $at > $start + 1 && $lines[ $at - 1 ] eq '';
        splice( @lines, $at, 0, $line );
    }
    return _write( $file, \@lines );
}

# Usage     : my $ok = _rewrite($file, sub { $_[0] =~ s/…/…/ })
# Purpose   : Applies a substitution to the first line it changes.
# Returns   : 1 when a line changed and the file was written; 0 otherwise.
sub _rewrite
{
    my ( $file, $edit ) = @_;
    my @lines = @{ _read($file) // return 0 };
    foreach my $line (@lines) {
        if ( $edit->($line) ) {
            return _write( $file, \@lines );
        }
    }
    return 0;
}

# Usage     : my $lines = _read($file)
# Purpose   : A plan file's lines, read fresh from disk.
# Returns   : Array ref, or undef when it cannot be read.
sub _read
{
    my ($file) = @_;
    open( my $fh, '<:encoding(UTF-8)', $file ) or return;
    my @lines = map { s/\r?\n\z//r } <$fh>;
    close($fh);
    return \@lines;
}

# Usage     : my $ok = _write($file, \@lines)
# Purpose   : Writes a plan file's lines and drops State's cached copy.
# Returns   : 1, or 0 after an [ ERROR ] line.
sub _write
{
    my ( $file, $lines ) = @_;
    my $fh;
    if ( !open( $fh, '>:encoding(UTF-8)', $file ) ) {
        AAPP::Logger::print_msg( 'ERROR', "Cannot write $file: $!" );
        return 0;
    }
    print {$fh} join( "\n", @{$lines} ), "\n";
    close($fh);
    AAPP::State::forget($file);
    return 1;
}

1;
