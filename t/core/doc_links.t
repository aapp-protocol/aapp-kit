package AAPP::T::Core::DocLinks;

use strict;
use warnings;
use utf8;
use 5.026;

use File::Find ();
use AAPP::Tests ();

# Each test_<name> sub is described by its line in lib/docs/core/doc_links.md. Run alone: prove -l t/core/doc_links.t

# The pages a test reads besides docs/: the kit's top-level manuals.
our @TOP_PAGES = qw(COOKBOOK.md MANUAL.md README.md);

# Usage     : my @files = modular_docs($self)
# Purpose   : Every page under docs/, sorted.
# Returns   : Absolute paths.
sub modular_docs
{
    my ($self) = @_;
    my @files;
    File::Find::find( { no_chdir => 1, wanted => sub { push @files, $File::Find::name if /\.md$/ && -f } }, "$self->{kit}/docs" );
    my @sorted = sort @files;
    return @sorted;
}

# Usage     : my @files = all_docs($self)
# Purpose   : The top-level manuals and every page under docs/.
# Returns   : Absolute paths.
sub all_docs
{
    my ($self) = @_;
    return ( ( map {"$self->{kit}/$_"} @TOP_PAGES ), modular_docs($self) );
}

# Usage     : my $rel = rel($self, $file)
# Purpose   : A kit file's path for a message.
# Returns   : The path below the kit.
sub rel
{
    my ( $self, $file ) = @_;
    return substr( $file, length( $self->{kit} ) + 1 );
}

sub test_modular_docs_have_frontmatter
{
    my ($self) = @_;
    my @bad;
    foreach my $f ( modular_docs($self) ) {
        my @lines = split( /\n/, AAPP::Tests::read_text($f) );
        my $closed = grep { $_ eq '---' } @lines[ 1 .. ( $#lines < 19 ? $#lines : 19 ) ];
        push @bad, rel( $self, $f ) if $lines[0] ne '---' || !$closed || !grep {/^title: /} @lines;
    }
    $self->true_or_die( !@bad, 'every page under docs/ has front matter (---, title:, ---)', join( ', ', @bad ) );
    return 1;
}

sub test_modular_docs_have_navigation
{
    my ($self) = @_;
    my @bad = map { rel( $self, $_ ) }
        grep { AAPP::Tests::read_text($_) !~ /Continuous Navigation|Cookbook Catalog|Technical Manual|Manual|Navigation/ } modular_docs($self);
    $self->true_or_die( !@bad, 'every page under docs/ has a navigation block', join( ', ', @bad ) );
    return 1;
}

sub test_docs_hold_no_machine_paths
{
    my ($self) = @_;
    my @bad;
    foreach my $f ( all_docs($self) ) {
        my $text = AAPP::Tests::read_text($f);
        push @bad, 'file:/// URI in ' . rel( $self, $f ) if index( $text, 'file:///' ) >= 0;
        push @bad, 'home path in ' . rel( $self, $f )     if $text =~ m{/home/[a-zA-Z0-9_-]+};
    }
    $self->true_or_die( !@bad, 'no machine paths', join( '; ', @bad ) );
    return 1;
}

sub test_relative_links_resolve
{
    my ($self) = @_;
    my @bad;
    foreach my $f ( all_docs($self) ) {
        my $dir = $f =~ s{/[^/]+$}{}r;
        # Code blocks (a line holding ``` to the next one) and inline code spans hold no links.
        my ( $in_code, @kept ) = (0);
        foreach my $line ( split( /\n/, AAPP::Tests::read_text($f) ) ) {
            if ( index( $line, '```' ) >= 0 ) {
                $in_code = !$in_code;
                next;
            }
            push @kept, $line if !$in_code;
        }
        my $text = join( "\n", @kept ) =~ s/`[^`]*`//gr;
        foreach my $link ( $text =~ /\]\(([^)]+)\)/g ) {
            next if $link =~ /^(?:https?|mailto):/;
            my $target = $link =~ s/#.*//r;
            next if $target eq '';
            push @bad, rel( $self, $f ) . ": $link" if !-e "$dir/$target";
        }
    }
    $self->true_or_die( !@bad, 'every relative link resolves', join( '; ', @bad ) );
    return 1;
}

AAPP::Tests::run_file(__FILE__) unless caller;

1;
