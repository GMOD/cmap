package Bio::GMOD::CMap::Utils;

# $Id: Utils.pm,v 1.3 2002-08-30 21:02:00 kycl4rk Exp $

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
$VERSION = (qw$Revision: 1.3 $)[-1];

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
    my $reverse = $direction eq NORTH ? -1 : 1;
    my @used    = sort { $reverse * ( $a->[0] <=> $b->[0] ) } @$rows;
    my $ok      = 1; # assume innocent until proven guilty
    warn "Used = ", Dumper( \@used ), "\n" if $debug;
    warn "I want to put this label close to ($top, $bottom)\n" if $debug;

    SEGMENT:
    for my $i ( 0 .. $#used ) {
        my $segment = $used[ $i ];
        my ( $north, $south ) = @$segment; 
        warn "Current segment ($north, $south)\n" if $debug;
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
            my $ftop         = 
                $direction eq NORTH ? $next_segment->[1] || undef : $south;
            my $fbottom      = 
                $direction eq NORTH ? $north : $next_segment->[0] || undef;
            warn "Frame top = $ftop, bottom = $fbottom\n" if $debug;

            #
            # Check if we can fit the label into the frame.
            #
            if ( defined $ftop &&
                 defined $fbottom &&
                 $fbottom - $ftop < $bottom - $top
            ) {
                warn "Frame too small, moving on.\n" if $debug;
                next SEGMENT;
            }
            warn "Open frame is big enough for label\n" if $debug;

            #
            # See if moving the label to the frame would move it too far.
            #
            my $diff = $direction eq NORTH
                ? $fbottom - $bottom - $buffer
                : $ftop - $top + $buffer
            ;
#            next SEGMENT if ( abs $diff > $max_distance ) && $can_skip;
            if ( ( abs $diff > $max_distance ) && $can_skip ) {
                warn "Diff ($diff) is greater than max distance ",
                    "($max_distance) and I can skip\n" if $debug;
                next SEGMENT;
            }
            $_ += $diff for $top, $bottom;
            warn "Applying diff ($diff), new top = $top, bottom = $bottom\n" 
                if $debug;

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
                warn "OK!\n" if $debug;
                $ok = 1; 
                last;
            }
            warn "Skipping...\n" if !$ok && $debug;
            next SEGMENT if !$ok and !$can_skip;
            last;
        }
        else {
            $ok = 1;
        }
    }

    warn "I went through everything, ok = $ok\n" if $debug;

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
        warn "I can't skip, so I'll put it at the end\n" if $debug;
    }

    #
    # If there are no rows, we didn't find a collision, or we didn't
    # move the label too far to make it fit, then record where this one
    # went and return the new location.
    #
    if ( !@$rows || $ok ) {
        warn "I'm going to add a row for ($top, $bottom)\n" if $debug;
        push @$rows, [ $top, $bottom ];
        return $top;
    }

    warn "I didn't find anything, returning nothing\n" if $debug;
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
