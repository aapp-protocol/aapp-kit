package AAPP::Runner::Review::Draft;

use strict;
use warnings;
use utf8;
use 5.026;

use File::Path ();
use POSIX ();
use AAPP::Constants qw(RETURN_OK RETURN_FAIL RETURN_ERROR);
use AAPP::Logger ();
use AAPP::Paths ();
use AAPP::Review ();
use AAPP::State ();
use AAPP::Text ();

# The RFC template, relative to the kit, and the local folder RFCs live in, relative to the plans worktree.
our $TEMPLATE   = 'templates/rfc-template.md';
our $PICKUP_DIR = 'pickup';

# Usage     : AAPP::Runner::Review::Draft->run($target)
# Purpose   : 'aapp review draft <id> | <slug>': writes the RFC of a plan in design, or of a topic with no
#             plan, from the template; local, never committed.
# Returns   : RETURN_OK; RETURN_FAIL or RETURN_ERROR after an [ ERROR ] line; RETURN_NOT_FOUND for an unknown plan.
sub run
{
    my ( $class, $target, @extra ) = @_;
    if ( !defined $target || @extra ) {
        AAPP::Logger::print_msg( 'ERROR', 'Usage: aapp review draft <id> | <slug>' );
        return RETURN_FAIL;
    }
    my ( $rc, $rel );
    if ( _names_a_plan($target) ) {
        my ( $prc, $plan ) = AAPP::Review::plan($target);
        if ( $prc != RETURN_OK ) {
            return $prc;
        }
        if ( !AAPP::Review::status_is( $plan, @AAPP::Review::DESIGN_STATUSES ) ) {
            AAPP::Logger::print_msg( 'ERROR', "$plan->{id} is $plan->{status}: an RFC is for a plan in design (Under Review or Refining)." );
            return RETURN_FAIL;
        }
        ( $rc, $rel ) = _for_plan($plan);
    } else {
        ( $rc, $rel ) = _for_topic($target);
    }
    if ( $rc != RETURN_OK ) {
        return $rc;
    }
    AAPP::Logger::log_event( 'review', 'draft', { target => "$target", file => "$rel" } );
    AAPP::Logger::print_msg( 'INFO', "RFC written: $rel (local, not committed)." );
    return RETURN_OK;
}

# Usage     : my $yes = _names_a_plan($target)
# Purpose   : Whether a draft target names a plan in current/: an id (P-9, 9), a file stem or a plan's slug.
# Returns   : 1 or 0.
sub _names_a_plan
{
    my ($target) = @_;
    if ( $target =~ /^(?:[Pp]-?)?[0-9]+$/ ) {
        return 1;
    }
    foreach my $file ( AAPP::State::current_plans() ) {
        my ($base) = $file =~ m{([^/]+)\.md$};
        if ( defined $base && ( $base eq $target || $base =~ /^P[0-9]+-\Q$target\E$/ ) ) {
            return 1;
        }
    }
    return 0;
}

# Usage     : my ($rc, $rel) = _for_plan($plan)
# Purpose   : The RFC of a plan in design: <plans>/pickup/p<n>-<slug>-rfc.md, titled with the plan's heading.
# Returns   : (RETURN_OK, path relative to the checkout); (RETURN_FAIL) or (RETURN_ERROR) after an [ ERROR ] line.
sub _for_plan
{
    my ($plan) = @_;
    my $heading = ( @{ AAPP::State::file_lines( $plan->{file} ) // [] } )[0] // '';
    $heading = AAPP::Text::strip_leading_emoji( $heading =~ s/^#+\s*//r );
    return _write_rfc(
        "p$plan->{num}-$plan->{slug}-rfc.md",
        {
            TITLE   => $heading ne '' ? $heading : $plan->{id},
            SUBJECT => "plan $plan->{id} (`$plan->{rel}`)",
            SCOPE   => "Design review of $plan->{id}: what it builds, whether its design and Blast Radius hold, and what it leaves open.",
        }
    );
}

# Usage     : my ($rc, $rel) = _for_topic('Review Topic')
# Purpose   : The RFC of a topic with no plan yet: <plans>/pickup/<slug>-rfc.md, its §1 quoting the open
#             pickup line whose title normalises to the slug.
# Returns   : (RETURN_OK, path relative to the checkout); (RETURN_FAIL) or (RETURN_ERROR) after an [ ERROR ] line.
sub _for_topic
{
    my ($raw) = @_;
    my $slug = _slug($raw);
    if ( $slug eq '' ) {
        AAPP::Logger::print_msg( 'ERROR', "'$raw' leaves an empty slug: name the topic with letters or digits." );
        return (RETURN_FAIL);
    }
    my ( $title, $text ) = _pickup_topic($slug);
    my $scope = defined $title ? "From the pickup idea **$title**: $text" : "Topic `$slug`: the question this RFC settles.";
    return _write_rfc( "$slug-rfc.md", { TITLE => $title // $slug, SUBJECT => "topic `$slug`", SCOPE => $scope } );
}

# Usage     : my $slug = _slug('Review Topic')
# Purpose   : A slug as 'aapp draft' writes it: lowercase, spaces and '_' to '-', other signs dropped,
#             runs of '-' collapsed, no '-' at either end.
# Returns   : The slug ('' when nothing is left).
sub _slug
{
    my ($text) = @_;
    my $s = lc( $text // '' );
    $s =~ s/[ _]/-/g;
    $s =~ s/[^a-z0-9-]//g;
    $s =~ s/-+/-/g;
    $s =~ s/^-|-$//g;
    return $s;
}

# Usage     : my ($title, $text) = _pickup_topic('review-topic')
# Purpose   : The open pickup line whose title normalises to the slug.
# Returns   : (title, text), or () when there is none.
sub _pickup_topic
{
    my ($slug) = @_;
    my $plans = AAPP::State::plans_root();
    if ( !defined $plans ) {
        return ();
    }
    foreach my $line ( @{ AAPP::State::file_lines("$plans/pickup.md") // [] } ) {
        if ( $line !~ /^\s*[-*+]\s+\[ \]\s/ ) {
            next;
        }
        my ( $title, $text ) = AAPP::Text::pickup_entry_split($line);
        if ( $title ne '' && _slug($title) eq $slug ) {
            return ( $title, $text );
        }
    }
    return ();
}

# Usage     : my ($rc, $rel) = _write_rfc($name, \%fields)
# Purpose   : Writes <plans>/pickup/<name> from the kit's RFC template, its {{FIELD}}s filled; refuses an
#             existing file.
# Returns   : (RETURN_OK, path relative to the checkout); (RETURN_FAIL) or (RETURN_ERROR) after an [ ERROR ] line.
sub _write_rfc
{
    my ( $name, $fields ) = @_;
    my $plans = AAPP::State::plans_root();
    if ( !defined $plans || !-d $plans ) {
        AAPP::Logger::print_msg( 'ERROR', 'The .plans worktree was not found.' );
        return (RETURN_ERROR);
    }
    my $kit      = AAPP::Paths::kit_dir();
    my $template = defined $kit ? "$kit/$TEMPLATE" : '';
    if ( !-r $template ) {
        AAPP::Logger::print_msg( 'ERROR', "The RFC template is missing: $TEMPLATE in the kit. Reinstall the kit: aapp install." );
        return (RETURN_ERROR);
    }
    my $file = "$plans/$PICKUP_DIR/$name";
    my $rel  = AAPP::Paths::rel_path( AAPP::Paths::resolve()->{root}, $file );
    if ( -e $file ) {
        AAPP::Logger::print_msg( 'ERROR', "$rel exists: an RFC is drafted once; edit it, or delete it to start again." );
        return (RETURN_FAIL);
    }
    my $in;
    if ( !open( $in, '<:encoding(UTF-8)', $template ) ) {
        AAPP::Logger::print_msg( 'ERROR', "Cannot read $template: $!" );
        return (RETURN_ERROR);
    }
    my $text = do { local $/; <$in> };
    close($in);
    my %f = ( %{$fields}, DATE => POSIX::strftime( '%Y-%m-%d', localtime ) );
    $text =~ s/\{\{([A-Z]+)\}\}/$f{$1} \/\/ ''/ge;
    File::Path::make_path("$plans/$PICKUP_DIR");
    my $out;
    if ( !open( $out, '>:encoding(UTF-8)', $file ) ) {
        AAPP::Logger::print_msg( 'ERROR', "Cannot write $rel: $!" );
        return (RETURN_ERROR);
    }
    print {$out} $text;
    close($out);
    return ( RETURN_OK, $rel );
}

1;
