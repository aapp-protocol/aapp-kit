package AAPP::Runner::Review::Fix;

use strict;
use warnings;
use utf8;
use 5.026;

use AAPP::Constants qw(RETURN_OK RETURN_FAIL RETURN_ERROR);
use AAPP::CommitEngine ();
use AAPP::Logger ();
use AAPP::Review ();

# The states each form starts from.
our %NEEDS = ( task => ['open'], done => ['planned'], decline => [ 'open', 'planned' ] );

# Usage     : AAPP::Runner::Review::Fix->run($id, 'F<n>', "<task>") | run('done', $id, 'F<n>') | run('decline', $id, 'F<n>', "<reason>")
# Purpose   : The implementer's answer to a finding, from the plan's own checkout: a task in §8 (planned),
#             the task ticked (done), or the finding declined with a reason; one plans commit each.
# Returns   : RETURN_OK; RETURN_FAIL or RETURN_ERROR after an [ ERROR ] line; RETURN_NOT_FOUND for an unknown plan.
sub run
{
    my ( $class, @args ) = @_;
    my $action = 'task';
    if ( @args && ( $args[0] eq 'done' || $args[0] eq 'decline' ) ) {
        $action = shift(@args);
    }
    my ( $id, $label, $text, @extra ) = @args;
    my $wants_text = $action ne 'done';
    if ( !defined $label || @extra || ( $wants_text && !defined $text ) || ( !$wants_text && defined $text ) ) {
        AAPP::Logger::print_msg( 'ERROR', 'Usage: aapp review fix <id> F<n> "<task>" | fix done <id> F<n> | fix decline <id> F<n> "<reason>"' );
        return RETURN_FAIL;
    }
    my ( $rc, $plan ) = AAPP::Review::plan($id);
    if ( $rc != RETURN_OK ) {
        return $rc;
    }
    if ( AAPP::Review::implementing($plan) != RETURN_OK ) {
        return RETURN_FAIL;
    }
    my ( $own, $owner ) = AAPP::Review::owner($plan);
    if ( !$own ) {
        AAPP::Logger::print_msg( 'ERROR', "$plan->{id} is in development; only $owner answers its review." );
        return RETURN_FAIL;
    }
    my $finding = AAPP::Review::finding( $plan->{file}, $label );
    if ( !defined $finding ) {
        AAPP::Logger::print_msg( 'ERROR', "$label is not a finding of $plan->{id}." );
        return RETURN_FAIL;
    }
    my $n = $finding->{n};
    if ( !grep { $finding->{state} eq $_ } @{ $NEEDS{$action} } ) {
        AAPP::Logger::print_msg( 'ERROR', "F$n is $finding->{state}: 'fix" . ( $action eq 'task' ? '' : " $action" ) . "' needs a finding that is " . join( ' or ', @{ $NEEDS{$action} } ) . '.' );
        return RETURN_FAIL;
    }
    if ($wants_text) {
        $text = $text =~ s/\s+/ /gr =~ s/^ | $//gr;
        if ( $text eq '' ) {
            AAPP::Logger::print_msg( 'ERROR', $action eq 'task' ? 'A fix needs its task.' : 'Declining a finding needs its reason.' );
            return RETURN_FAIL;
        }
    }
    my ( $ok, $state );
    if ( $action eq 'task' ) {
        $ok    = AAPP::Review::add_task( $plan, $n, $text ) && AAPP::Review::set_state( $plan, $n, 'planned' );
        $state = 'planned';
    } elsif ( $action eq 'done' ) {
        my ($task) = grep { $_->{n} == $n } AAPP::Review::tasks( $plan->{file} );
        my ( $landed, $why ) = AAPP::Review::amendment_landed( $plan, $finding, $task ? $task->{task} : '' );
        if ( !$landed ) {
            AAPP::Logger::print_msg( 'ERROR', "F$n cannot be done yet: $why." );
            return RETURN_FAIL;
        }
        $ok    = AAPP::Review::tick( $plan, $n ) && AAPP::Review::set_state( $plan, $n, 'done' );
        $state = 'done';
    } else {
        $ok    = AAPP::Review::set_state( $plan, $n, "declined: $text" );
        $state = 'declined';
    }
    if ( !$ok ) {
        return RETURN_ERROR;
    }
    $rc = AAPP::CommitEngine::plans_commit( "plan(review): $plan->{id} F$n $state", $plan->{rel} );
    if ( $rc != RETURN_OK ) {
        return $rc;
    }
    AAPP::Logger::log_event( 'review', 'fix', { plan_id => "$plan->{id}", finding => "F$n", action => $action } );
    AAPP::Logger::print_msg( 'INFO', "F$n on $plan->{id} is $state." );
    return RETURN_OK;
}

1;
