package Bio::GMOD::CMap::Utils;

# $Id: Utils.pm,v 1.16 2003-03-17 20:26:49 kycl4rk Exp $

=head1 NAME

Bio::GMOD::CMap::Utils - generalized utilities

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Utils;
  my $next_number = next_number(...);

=head1 DESCRIPTION

This module contains a couple of general-purpose routines, all of
which are exported by default.

=head1 Exported Subroutines

=cut 

use strict;
use Data::Dumper;
use Bio::GMOD::CMap::Constants;
require Exporter;
use vars qw( $VERSION @EXPORT @EXPORT_OK );
$VERSION = (qw$Revision: 1.16 $)[-1];

use base 'Exporter';

my @subs   = qw[ 
    column_distribution 
    commify 
    extract_numbers 
    label_distribution 
    next_number 
    paginate
    parse_words
];
@EXPORT_OK = @subs;
@EXPORT    = @subs;

# ----------------------------------------------------
sub column_distribution {

=pod

=head2 column_distribution

Given a reference to some columns, figure out where something can be inserted.

=cut

    my %args    = @_;
    my $columns = $args{'columns'} || []; # array reference
    my $top     = $args{'top'}     ||  0; # the top and bottom
    my $bottom  = $args{'bottom'}  ||  0; # of the thing being inserted
    my $buffer  = $args{'buffer'}  ||  2; # space b/w things

    return unless defined $top && defined $bottom;

    my $column_index;
    if ( @$columns ) {
        for my $i ( 0..$#{ $columns } ) {
            my $column = $columns->[ $i ];
            my @used   = sort { $a->[0] <=> $b->[0] } @{ $column };
            my $ok     = 1;

            for my $segment ( @used ) {
                my ( $north, $south ) = @$segment; 
                next if $south + $buffer < $top;
                next if $north - $buffer > $bottom;
                $ok = 0, last;
            }

            if ( $ok ) {
                $column_index = $i;
                push @{ $column }, [ $top, $bottom ];
                last;
            }
        }

        unless ( defined $column_index ) {
            push @$columns, [ [ $top, $bottom ] ];
            $column_index = $#{ $columns };
        }
    }
    else {
        $column_index = 0;
        push @$columns, [ [ $top, $bottom ] ];
    }

    return $column_index;
}

# ----------------------------------------------------
sub next_number {

=pod

=head2 next_number

A generic routine for retrieving (and possibly setting) the next
number for an ID field in a table.  Given a table "foo," the
expected ID field would be "foo_id," but this isn't always the case.
Therefore, "id_field" tells us what field to look at.  Basically, we
look to see if there's an entry in the "next_number" table.  If not
we do a MAX on the ID field given (or ascertained).  Either way, the
"next_number" table gets told what the next number will be (on the
next call), and we pass back what is the next number this time.

So why not just use "auto_increment" (MySQL) or a "sequence"
(Oracle)?  Just to make sure that this stays completely portable.
By coding all this in Perl, I know that it will work with any
database (that supports ANSI-SQL, that is).

=cut

    my %args       = @_;
    my $db         = $args{'db'}         or return;
    my $table_name = $args{'table_name'} or return;
    my $id_field   = $args{'id_field'}   || $table_name.'_id';

    my $next_number = $db->selectrow_array(
        q[
            select next_number
            from   cmap_next_number
            where  table_name=?
        ],
        {}, ( $table_name )
    );

    unless ( $next_number ) {
        $next_number = $db->selectrow_array(
            qq[
                select max( $id_field )
                from   $table_name
            ]
        ) || 0;
        $next_number++;

        $db->do(
            q[
                insert
                into   cmap_next_number ( table_name, next_number )
                values ( ?, ? )
            ],
            {}, ( $table_name, $next_number+1 )
        );
    }
    else {
        $db->do(
            q[
                update cmap_next_number
                set    next_number=?
                where  table_name=?
            ],
            {}, ( $next_number + 1, $table_name )
        );
    }

    return $next_number;
}

# ----------------------------------------------------
sub extract_numbers {

=pod

=head2 extract_numbers

Returns only the number portion at the beginning of a string.

=cut

    my $arg = shift;
    $arg =~ s/[^\d]//g;
    return $arg;
}

# ----------------------------------------------------
sub commify {

=pod

=head2 commify

Turns "12345" into "12,345"

=cut

    my $number = shift;
    1 while $number =~ s/^(-?\d+)(\d{3})/$1,$2/;
    return $number;
}

# ----------------------------------------------------
sub label_distribution {

=pod

=head2 label_distribution

Given a reference to an array containing labels, figure out where a new
label can be inserted.

=cut

    my %args         = @_;
    my $rows         = $args{'rows'}         ||    []; # array ref
    my $target       = $args{'target'}       ||     0; # desired location
    my $row_height   = $args{'row_height'}   ||     1; # how tall a row is
    my $buffer       = $args{'buffer'}       ||     2; # space b/w things
    my $max_distance = $args{'max_distance'} ||     5; # how far from target
    my $can_skip     = $args{'can_skip'}     ||     0; # skip or not?
    my $direction    = $args{'direction'}    || NORTH; # NORTH or SOUTH?
    my $top          = $target;
    my $bottom       = $target + $row_height;

    #
    # Sort what's been used by the first field.  Go through all
    # and see if the label will fit directly across, a little 
    # above, or a little below.
    #
    my $reverse = $direction eq NORTH ? -1 : 1;
    my @used    = sort { $reverse * ( $a->[0] <=> $b->[0] ) } @$rows;
    my $ok      = 1; # assume innocent until proven guilty

    SEGMENT:
    for my $i ( 0 .. $#used ) {
        my $segment = $used[ $i ];
        my ( $north, $south ) = @$segment; 
        next if $south + $buffer <= $top;    # segment is above our target.
        next if $north - $buffer >= $bottom; # segment is below our target.

        #
        # If there's some overlap, see if it will fit above or below.
        #
        if (
            ( $north - $buffer <= $bottom )
            ||
            ( $south + $buffer >= $top    )
        ) {
            $ok = 0; # now we're guilty until we can prove innocence

            #
            # Figure out the current frame.
            #
            my $prev_segment = $i > 0      ? $used[ $i - 1 ] : undef;
            my $next_segment = $i < $#used ? $used[ $i + 1 ] : undef;
            my $ftop         = $direction eq NORTH  
                    ? defined $next_segment->[1] ? $next_segment->[1] : undef 
                    : $south
            ;
            my $fbottom      = $direction eq NORTH 
                    ? $north 
                    : defined $next_segment->[0] ? $next_segment->[0] : undef
            ;

            #
            # Check if we can fit the label into the frame.
            #
            if ( defined $ftop &&
                 defined $fbottom &&
                 $fbottom - $ftop < $bottom - $top
            ) {
                next SEGMENT;
            }

            #
            # See if moving the label to the frame would move it too far.
            #
            my $diff = $direction eq NORTH
                ? $fbottom - $bottom - $buffer
                : $ftop - $top + $buffer
            ;
            if ( ( abs $diff > $max_distance ) && $can_skip ) {
                next SEGMENT;
            }
            $_ += $diff for $top, $bottom;

            #
            # See if it will fit.  Same as two above?
            #
            if ( 
                ( defined $ftop && 
                  defined $fbottom && 
                  $top - $buffer >= $ftop &&
                  $bottom + $buffer <= $fbottom 
                )
                ||
                ( defined $ftop && $top - $buffer >= $ftop )
                ||
                ( defined $fbottom && $bottom + $buffer <= $fbottom )
            ) {
                $ok = 1; 
                last;
            }
            next SEGMENT if !$ok and !$can_skip;
            last;
        }
        else {
            $ok = 1;
        }
    }

    #
    # If nothing was found but we can't skip, then move the
    # label to just beyond the last segment.
    #
    if ( !$ok and !$can_skip ) {
        my ( $last_top, $last_bottom ) = @{ $used[ -1 ] };
        if ( $direction eq NORTH ) {
            $bottom = $last_top - $buffer;
            $top    = $bottom - $row_height;
        }
        else {
            $top    = $last_bottom + $buffer;
            $bottom = $top + $row_height;
        }
        $ok         = 1;
    }

    #
    # If there are no rows, we didn't find a collision, or we didn't
    # move the label too far to make it fit, then record where this one
    # went and return the new location.
    #
    if ( !@$rows || $ok ) {
        push @$rows, [ $top, $bottom ];
        return $top;
    }

    return undef;
}

# ----------------------------------------------------
sub paginate {

=pod

=head2 paginate

Given a result set, break it up into pages.

=cut

    my %args        = @_;
    my $self        = $args{'self'};
    my $data        = $args{'data'}        || [];
    my $limit_start = $args{'limit_start'} || 1;
    my $page_size   = $args{'page_size'}   || 
                      $self->config('max_child_elements') || 0;
    my $max_pages   = $args{'max_pages'}   ||
                      $self->config('max_search_pages')   || 1;    
    my $no_elements = $args{'no_elements'} || @$data;

    my $limit_stop;
    if ( $no_elements > $page_size ) {
        $limit_start  = 1 if $limit_start < 1;
        $limit_start  = $no_elements if $limit_start > $no_elements;
        $limit_stop   = ( $limit_start + $page_size >= $no_elements )
            ? $no_elements
            : $limit_start + $page_size - 1;
        $data         = [ @$data[ $limit_start - 1 .. $limit_stop - 1 ] ];
    }
    elsif ( $no_elements ) {
        $limit_stop = $no_elements;
    }
    else {
        $limit_stop = 0;
    }

    my $no_pages = $no_elements
        ? sprintf( "%.0f", ( $no_elements / $page_size ) + .5 ) : 0;
    my $step     = ( $no_pages > $max_pages ) 
        ? sprintf( "%.0f", ($no_pages/$max_pages) + .5 ) : 1;
    my $cur_page = int( ( $limit_start + 1 ) / $page_size ) + 1;
    my ( $done, $prev_page, @pages );
    for ( my $page = 1; $page <= $no_pages; $page += $step ) {
        if ( 
            !$done              &&
            $page != $cur_page  && 
            $page  > $cur_page  && 
            $page  > $prev_page
        ) {
            push @pages, $cur_page unless $pages[-1] == $cur_page;
            $done = 1;
        }
        $done = $cur_page == $page unless $done;
        push @pages, $page;
    }

    if ( @pages ) {
        push @pages, $cur_page unless $done;
        push @pages, $no_pages unless $pages[-1] == $no_pages;
    }
        
    return {
        data        => $data,
        no_elements => $no_elements,
        pages       => \@pages,
        cur_page    => $cur_page,
        page_size   => $page_size,
        no_pages    => $no_pages,
        show_start  => $limit_start,
        show_stop   => $limit_stop,
    }
}

# ----------------------------------------------------
sub parse_words {
#
# Stole this from String::ParseWords::parse by Christian Gilmore 
# (CPAN ID: CGILMORE).  Allows quoted phrases within a string to 
# count as a "word," e.g.:
#
# "Foo bar" baz
# 
# Becomes:
# 
# Foo bar
# baz
#
    my $string    = shift;
    my @words     = ();
    my $inquote   = 0;
    my $length    = length($string);
    my $nextquote = 0;
    my $nextspace = 0;
    my $pos       = 0;
  
    # shrink whitespace sets to just a single space
    $string =~ s/\s+/ /g;
  
    # Extract words from list
    while ( $pos < $length ) {
        $nextquote = index( $string, '"', $pos );
        $nextspace = index( $string, ' ', $pos );
        $nextspace = $length if $nextspace < 0;
        $nextquote = $length if $nextquote < 0;

        if ( $inquote ) {
            push(@words, substr($string, $pos, $nextquote - $pos));
            $pos = $nextquote + 2;
            $inquote = 0;
        } 
        elsif ( $nextspace < $nextquote ) {
            push(@words, substr($string, $pos, $nextspace - $pos));
            $pos = $nextspace + 1;
        } 
        elsif ( $nextspace == $length && $nextquote == $length ) {
            # End of the line
            push( @words, substr( $string, $pos, $nextspace - $pos ) );
            $pos = $nextspace;
        } 
        else {
            $inquote = 1;
            $pos = $nextquote + 1;
        }
    }
  
    push( @words, $string ) unless scalar( @words );
  
    return @words;
}


1;

# ----------------------------------------------------
# I have never yet met a man who was quite awake.
# How could I have looked him in the face?
# Henry David Thoreau
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2002-3 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
