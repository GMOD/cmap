package Bio::GMOD::CMap::Utils;

# $Id: Utils.pm,v 1.2 2002-08-30 02:49:55 kycl4rk Exp $

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
$VERSION = (qw$Revision: 1.2 $)[-1];

use base 'Exporter';

my @subs   = qw[ 
    column_distribution 
    commify 
    extract_numbers 
    label_distribution 
    next_number 
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
    my $debug        = $args{'debug'} || 0;
#    warn "label dist args =\n", Dumper( \%args ), "\n" if $debug;
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
    my @used = sort { $a->[0] <=> $b->[0] } @$rows;
    warn "used = ", Dumper( \@used ), "\n" if $debug;
    my $ok   = 1;

    for my $i ( 0 .. $#used ) {
        my $segment = $used[ $i ];
        my ( $north, $south ) = @$segment; 

#        next if $south + $buffer < $top;    
#        next if $north - $buffer > $bottom;

        #
        # See if this segment is above our target.
        #
        next if $south + $buffer <= $top;

        #
        # See if this segment is below our target.
        #
        next if $north - $buffer >= $bottom; 

        #
        # If there's some overlap, see if it will fit above or below.
        #
        if (
            ( $north - $buffer <= $bottom )
            ||
            ( $south + $buffer >= $top    )
        ) {
            $ok = 0;
            warn "target = $target, can skip = $can_skip\n" if $debug;
            warn "north = $north, south = $south\n" if $debug;
            warn "top = $top, bottom = $bottom\n" if $debug;

            my ( $ftop, $fbottom ); # the open frame
            while ( 1 ) { 
                my $prev_segment = $i > 0      ? $used[ $i - 1 ] : undef;
                my $next_segment = $i < $#used ? $used[ $i + 1 ] : undef;
#                my $frame        = $direction eq NORTH 
#                    ? [ $prev_segment->[1] || undef, $north ]
#                    : [ $south, $next_segment->[0] || undef ]
#                ;
                $ftop    = $direction eq NORTH ? $prev_segment->[1] : $south;
                $fbottom = $direction eq NORTH ? $north : $next_segment->[0];

                #
                # If the frame is too small, rewind or advance, if possible.
                #
                if ( defined $ftop && defined $fbottom ) {
                    $i--, next if $fbottom - $ftop < $bottom - $top;
                }
                last;
            }

            my $diff;
            warn "frame top = $ftop, bottom = $fbottom\n" if $debug;
            while ( 1 ) {
                last if abs ( $diff > $max_distance ) && $can_skip;
                my $inc = $direction eq NORTH ? -1 : 1;
                $_     += $inc for $top, $bottom, $diff;
                warn "top = $top, bottom = $bottom, diff = $diff\n" if $debug;

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
                    warn "OK!\n" if $debug;
                    $ok = 1; 
                    last;
                }
            }
            warn ">>>DIFF = $diff\n" if $debug;
            warn "skipping...\n" if !$ok && $debug;
            next if !$ok and !$can_skip;
            last;
        }
        else {
            $ok = 1;
        }
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

Copyright (c) 2002 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
