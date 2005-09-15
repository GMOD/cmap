package Bio::GMOD::CMap::Utils;

# vim: set ft=perl:

# $Id: Utils.pm,v 1.50 2005-09-15 20:27:00 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Utils - generalized utilities

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Utils;

=head1 DESCRIPTION

This module contains a couple of general-purpose routines, all of
which are exported by default.

=head1 EXPORTED SUBROUTINES

=cut 

use strict;
use Algorithm::Numerical::Sample 'sample';
use Bit::Vector;
use Data::Dumper;
use Bio::GMOD::CMap::Constants;
use POSIX;
require Exporter;
use vars qw( $VERSION @EXPORT @EXPORT_OK );
$VERSION = (qw$Revision: 1.50 $)[-1];

use base 'Exporter';

my @subs = qw[
  commify
  presentable_number
  presentable_number_per
  extract_numbers
  even_label_distribution
  label_distribution
  parse_words
  simple_column_distribution
  fake_selectall_arrayref
  sort_selectall_arrayref
];
@EXPORT_OK = @subs;
@EXPORT    = @subs;

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
sub even_label_distribution {

=pod

=head2 even_label_distribution

Simply space (a sample of) the labels evenly in the given vertical space.

Given:

  labels: a hashref of arrayrefs, the keys of the hashref being one of
    "highlights" - highlighted features, all will be taken
    "correspondences" - features with correspondences
    "normal" - all other features

  map_height: the pixel height of the map (the bounds in which 
    labels can be drawn

  buffer: the space between labels (optional, default = "2")

  start_y: the starting Y value from which to start assigning labels Y values

  font_height: how many pixels tall the label font is

Basically, we just divide the total vertical pixel space available 
(map_height) by the number of labels we want to place and decide how many 
will fit.  For each of the keys of the "labels" hashref, we try to add
as many labels as will fit.  As space becomes limited, we start taking an
even sampling of the available labels.  Once we've selected all the labels
that will fit, we sort them (if needed) by "feature_start," figure out the
gaps to put b/w the labels, and then space them evenly from top to bottom
using the gap interval.

Special thanks to Noel Yap for suggesting this strategy.

=cut

    my %args        = @_;
    my $labels      = $args{'labels'};
    my $map_height  = $args{'map_height'} || 0;
    my $buffer      = $args{'buffer'} || 2;
    my $start_y     = $args{'start_y'} || 0;
    my $font_height = $args{'font_height'} || 0;
    $font_height += $buffer;
    my @accepted = @{ $labels->{'highlights'} || [] };    # take all highlights
    my $no_added = @accepted ? 1 : 0;

    for my $priority (qw/ correspondences normal /) {

        #
        # See if there's enough room available for all the labels;
        # if not, just take an even sampling.
        #
        my $no_accepted = scalar @accepted;
        my $no_present  = scalar @{ $labels->{$priority} || [] } or next;
        my $available   = $map_height - ( $no_accepted * $font_height );
        last if $available < $font_height;

        my $no_possible = int( $available / $font_height );
        if ( $no_present > $no_possible ) {
            my $skip_val = int( $no_present / $no_possible );
            if ( $skip_val > 1 ) {
                for ( my $i = 0 ; $i < $no_present ; $i += $skip_val ) {
                    push @accepted, $labels->{$priority}[$i];
                }
            }
            else {
                my @sample = sample(
                    set         => [ 0 .. $no_present - 1 ],
                    sample_size => $no_possible,
                );
                push @accepted, @{ $labels->{$priority} }[@sample];
            }
        }
        else {
            push @accepted, @{ $labels->{$priority} };
        }

        $no_added++;
    }

    my $no_accepted = scalar @accepted;
    my $no_possible = int( $map_height / $font_height );

    #
    # If there's only one label, put it right next to the one feature.
    #
    if ( $no_accepted == 1 ) {
        my $label = $accepted[0];
        $label->{'y'} = $label->{'target'};
    }

    #
    # If we took fewer than was possible, try to sort them nicely.
    #
    elsif ( $no_accepted > 1 && $no_accepted <= ( $no_possible * .5 ) ) {
        @accepted =
          map { $_->[0] }
          sort { $a->[1] <=> $b->[1] || $b->[2] <=> $a->[2] }
          map { [ $_, $_->{'target'}, $_->{'feature'}{'column'} ] } @accepted;

        my $bin_size  = 2;
        my $half_font = $font_height / 2;
        my $no_bins   = sprintf( "%d", $map_height / $bin_size );
        my $bins      = Bit::Vector->new($no_bins);

        my $i = 1;
        for my $label (@accepted) {
            my $target  = $label->{'target'};
            my $low_bin =
              sprintf( "%d", ( $target - $start_y - $half_font ) / $bin_size );
            my $high_bin =
              sprintf( "%d", ( $target - $start_y + $half_font ) / $bin_size );

            if ( $low_bin < 0 ) {
                my $diff = 0 - $low_bin;
                $low_bin  += $diff;
                $high_bin += $diff;
            }

            my ( $hmin, $hmax ) = $bins->Interval_Scan_inc($low_bin);
            my ( $lmin, $lmax, $next_lmin, $next_lmax );
            if ( $low_bin > 0 ) {
                ( $lmin, $lmax ) = $bins->Interval_Scan_dec( $low_bin - 1 );

                if ( $lmin > 1 && $lmax == $low_bin - 1 ) {
                    ( $next_lmin, $next_lmax ) =
                      $bins->Interval_Scan_dec( $lmin - 1 );
                }
            }

            my $bin_span      = $high_bin - $low_bin;
            my $bins_occupied = $bin_span + 1;

            my ( $gap_below, $gap_above, $diff_to_gap_below,
                $diff_to_gap_above );

            # nothing below and enough open space
            if ( !defined $lmax && $low_bin - $bin_span > 1 ) {
                $gap_below         = $low_bin - 1;
                $diff_to_gap_below = $bin_span;
            }

            # something below but enough space b/w it and this
            elsif ( defined $lmax && $low_bin - $lmax > $bin_span ) {
                $gap_below         = $low_bin - $lmax;
                $diff_to_gap_below = $bins_occupied;
            }

            # something immediately below but enough space in next gap
            elsif (defined $lmax
                && $lmax == $low_bin - 1
                && defined $next_lmax
                && $lmin - $next_lmax >= $bins_occupied )
            {
                $gap_below         = $lmin - $next_lmax;
                $diff_to_gap_below = ( $low_bin - $lmin ) + $bins_occupied;
            }

            # something below and enough space beyond it w/o going past 0
            elsif (!defined $next_lmax
                && defined $lmin
                && $lmin - $bin_span > 0 )
            {
                $gap_below         = $lmin;
                $diff_to_gap_below = $low_bin - $lmin + $bins_occupied;
            }

            # nothing above and space w/in the bins
            if ( !defined $hmin && $high_bin + $bin_span < $no_bins ) {
                $gap_above         = $no_bins - $low_bin;
                $diff_to_gap_above = 0;
            }

            # inside an occupied bin but space just above it
            elsif (defined $hmax
                && $hmax <= $high_bin
                && $hmax + 1 + $bin_span < $no_bins )
            {
                $gap_above         = $no_bins - $hmax;
                $diff_to_gap_above = ( $hmax - $low_bin ) + 1;
            }

            # collision but space afterwards
            elsif ( defined $hmax && $hmax + $bin_span < $no_bins ) {
                $gap_above = $no_bins - ( $hmax + 1 );
                $diff_to_gap_above = ( $hmax + 1 ) - $low_bin;
            }

            my $below_open = $gap_below >= $bins_occupied;
            my $above_open = $gap_above >= $bins_occupied;
            my $closer_gap =
              $diff_to_gap_below == $diff_to_gap_above ? 'neither'
              : defined $diff_to_gap_below
              && ( $diff_to_gap_below < $diff_to_gap_above ) ? 'below'
              : 'above';

            my $diff = 0;
            if ( !defined $hmin ) {
                ;    # do nothing
            }
            elsif (
                $below_open
                && ( $closer_gap =~ /^(neither|below)$/
                    || !$above_open )
              )
            {
                $low_bin  -= $diff_to_gap_below;
                $high_bin -= $diff_to_gap_below;
                $diff = -( $bin_size * $diff_to_gap_below );
            }
            else {
                $diff_to_gap_above ||= ( $hmax - $low_bin ) + 1;
                $low_bin  += $diff_to_gap_above;
                $high_bin += $diff_to_gap_above;
                $diff = $bin_size * $diff_to_gap_above;
            }

            if ( defined $low_bin && defined $high_bin ) {
                if ( $high_bin >= $bins->Size ) {
                    my $cur  = $bins->Size;
                    my $diff = ( $high_bin - $cur ) + 1;
                    $bins->Resize( $cur + $diff );
                }
                $bins->Interval_Fill( $low_bin, $high_bin );
            }

            $label->{'y'} = $target + $diff;
            $i++;
        }

        #
        # Double-check to see if any look out of place.  To do this,
        # sort the labels by their "y" position and then see if the
        # "targets" are in ascending order.  If we find a pair where
        # this is not the case, then switch the "y" positions until
        # they're in ascending order.  It's necessary to make multiple
        # passes, so keep doing it until they're all determined to be
        # OK.
        #
        my $ok = 0;
        while ( !$ok ) {
            $ok       = 1;
            @accepted =
              map  { $_->[0] }
              sort { $a->[1] <=> $b->[1] }
              map  { [ $_, $_->{'y'} ] } @accepted;

            my $last_target = $accepted[0]->{'target'};
            $i = 0;
            for my $label (@accepted) {
                my $this_target = $label->{'target'};
                if ( $this_target < $last_target ) {
                    $ok = 0;
                    my $j    = $i;
                    my $this = $accepted[ $j - 1 ];    # back up
                    my $next = $accepted[$j];          # start switching here

                    while ($this->{'target'} > $next->{'target'}
                        && $this->{'y'} < $next->{'y'} )
                    {
                        ( $this->{'y'}, $next->{'y'} ) =
                          ( $next->{'y'}, $this->{'y'} );
                        $next = $accepted[ ++$j ];
                    }
                }

                $last_target = $this_target;
                $i++;
            }
        }
    }

    #
    # If we used all available space, just space evenly.
    #
    else {

        #
        # Figure the gap to evenly space the labels in the space.
        #
        @accepted =
          map { $_->[0] }
          sort { $a->[1] <=> $b->[1] || $a->[2] <=> $b->[2] }
          map { [ $_, $_->{'target'}, $_->{'feature'}{'column'} ] } @accepted;

        my $gap = $map_height / ( $no_accepted - 1 );
        my $i = 0;
        for my $label (@accepted) {
            $label->{'y'} = sprintf( "%.2f", $start_y + ( $gap * $i++ ) );
        }
    }

    return \@accepted;
}

# ----------------------------------------------------
sub label_distribution {

=pod

=head2 label_distribution

Given a reference to an array containing labels, figure out where a new
label can be inserted.

=cut

    my %args       = @_;
    my $labels     = $args{'labels'};
    my $accepted   = $args{'accepted'};
    my $buffer     = $args{'buffer'} || 2;
    my $direction  = $args{'direction'} || NORTH;    # NORTH or SOUTH?
    my $row_height = $args{'row_height'} || 1;       # how tall a row is
    my $used       = $args{'used'} || [];
    my $reverse    = $direction eq NORTH ? -1 : 1;
    my @used = sort { $reverse * ( $a->[0] <=> $b->[0] ) } @$used;

    for my $label ( @{ $labels || [] } ) {
        my $max_distance = $label->{'has_corr'}       ? 15 : 10;
        my $can_skip     = $label->{'is_highlighted'} ? 0  : 1;
        my $target = $label->{'target'} || 0;        # desired location
        my $top    = $target;
        my $bottom = $target + $row_height;
        my $ok = 1;    # assume innocent until proven guilty

      SEGMENT:
        for my $i ( 0 .. $#used ) {
            my $segment = $used[$i] or next;
            my ( $north, $south ) = @$segment;
            next if $south + $buffer <= $top;     # segment is above our target.
            next if $north - $buffer >= $bottom;  # segment is below our target.

            #
            # If there's some overlap, see if it will fit above or below.
            #
            if (   ( $north - $buffer <= $bottom )
                || ( $south + $buffer >= $top ) )
            {
                $ok = 0;    # now we're guilty until we can prove innocence

                #
                # Figure out the current frame.
                #
                my $prev_segment = $i > 0      ? $used[ $i - 1 ] : undef;
                my $next_segment = $i < $#used ? $used[ $i + 1 ] : undef;
                my $ftop         =
                  $direction eq NORTH
                  ? defined $next_segment->[1] ? $next_segment->[1] : undef
                  : $south;
                my $fbottom =
                    $direction eq NORTH ? $north
                  : defined $next_segment->[0] ? $next_segment->[0]
                  : undef;

                #
                # Check if we can fit the label into the frame.
                #
                if (   defined $ftop
                    && defined $fbottom
                    && $fbottom - $ftop < $bottom - $top )
                {
                    next SEGMENT;
                }

                #
                # See if moving the label to the frame would move it too far.
                #
                my $diff =
                    $direction eq NORTH
                  ? $fbottom - $bottom - $buffer
                  : $ftop - $top + $buffer;
                if ( ( abs $diff > $max_distance ) && $can_skip ) {
                    next SEGMENT;
                }
                $_ += $diff for $top, $bottom;

                #
                # See if it will fit.  Same as two above?
                #
                if (
                    (
                           defined $ftop
                        && defined $fbottom
                        && $top - $buffer >= $ftop
                        && $bottom + $buffer <= $fbottom
                    )
                    || ( defined $ftop    && $top - $buffer >= $ftop )
                    || ( defined $fbottom && $bottom + $buffer <= $fbottom )
                  )
                {
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
            my ( $last_top, $last_bottom ) = @{ $used[-1] };
            if ( $direction eq NORTH ) {
                $bottom = $last_top - $buffer;
                $top    = $bottom - $row_height;
            }
            else {
                $top    = $last_bottom + $buffer;
                $bottom = $top + $row_height;
            }
            $ok = 1;
        }

        #
        # If there are no rows, we didn't find a collision, or we didn't
        # move the label too far to make it fit, then record where this one
        # went and return the new location.
        #
        if ( !@used || $ok ) {
            push @used, [ $top, $bottom ];
            $label->{'y'} = $top;
            push @$accepted, $label;
        }
    }

    return \@used;
    return 1;
}

# ----------------------------------------------------
sub parse_words {

    #
    # Stole this from String::ParseWords::parse by Christian Gilmore
    # (CPAN ID: CGILMORE), modified to split on commas or spaces.  Allows
    # quoted phrases within a string to count as a "word," e.g.:
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

        if ($inquote) {
            push( @words, substr( $string, $pos, $nextquote - $pos ) );
            $pos     = $nextquote + 2;
            $inquote = 0;
        }
        elsif ( $nextspace < $nextquote ) {
            push @words, split /[,\s+]/,
              substr( $string, $pos, $nextspace - $pos );
            $pos = $nextspace + 1;
        }
        elsif ( $nextspace == $length && $nextquote == $length ) {

            # End of the line
            push @words, map { s/^\s+|\s+$//g; $_ }
              split /,/, substr( $string, $pos, $nextspace - $pos );
            $pos = $nextspace;
        }
        else {
            $inquote = 1;
            $pos     = $nextquote + 1;
        }
    }

    push( @words, $string ) unless scalar(@words);

    return @words;
}

# ----------------------------------------------------

=pod

=head2 simple_column_distribution

Assumes that items will fit into just one column.

=cut 

sub simple_column_distribution {
    my %args       = @_;
    my $columns    = $args{'columns'} || []; # arrayref of columns on horizontal
    my $map_height = $args{'map_height'};    # in pixels
    my $low        = $args{'low'};           # lowest pixel value occuppied
    my $high       = $args{'high'};          # highest pixel value occuppied
    my $buffer     = $args{'buffer'} || 2;   # min pixel distance b/w items
    my $selected;                            # the column number returned

    $map_height = int($map_height);
    $low        = int($low);
    $high       = int($high);

    #
    # Calculate the effect of the buffer.
    #
    my ( $scan_low, $scan_high ) = ( $low, $high );
    $scan_low -= $buffer if $low - $buffer >= 0;
    $scan_high += $buffer if $high + $buffer <= $map_height;
    $map_height += $buffer;

    if ( scalar @$columns == 0 ) {
        my $col = Bit::Vector->new($map_height);
        $col->Interval_Fill( $low, $high );
        push @$columns, $col;
        $selected = 0;
    }
    else {
        for my $i ( 0 .. $#{$columns} ) {
            my $col = $columns->[$i];
            my ( $min, $max ) = $col->Interval_Scan_inc($scan_low);
            if ( !defined $min || $min > $scan_high ) {
                $col->Interval_Fill( $low, $high );
                $selected = $i;
                last;
            }
        }

        unless ( defined $selected ) {
            my $col = Bit::Vector->new($map_height);
            $col->Interval_Fill( $low, $high );
            push @$columns, $col;
            $selected = $#{$columns};
        }
    }

    return $selected;
}

# ----------------------------------------------------
sub fake_selectall_arrayref {

=pod

=head2 fake_selectall_arrayref

takes a hash of hashes and makes it look like return from 
the DBI selectall_arrayref()

=cut 

    my $self    = shift;
    my $hashref = shift;
    my @columns = @_;
    my $i       = 0;
    my @return_array;
    my %column_name;
    foreach my $column (@columns) {
        if ( $column =~ /(\S+)\s+as\s+(\S+)/ ) {
            $column = $1;
            $column_name{$1} = $2;
        }
        else {
            $column_name{$column} = $column;
        }
    }
    for my $key ( keys(%$hashref) ) {
        %{ $return_array[$i] } =
          map { $column_name{$_} => $hashref->{$key}->{$_} } @columns;
        $i++;
    }
    @return_array =
      sort { $a->{ $columns[0] } cmp $b->{ $columns[0] } } @return_array;
    return \@return_array;
}

# ----------------------------------------------------

=pod

=head2 sort_selectall_arrayref

give array ref of a hash and a list of keys and it will sort 
based on the list of keys.  Add a '#' to the front of a key 
to make it use '<=>' instead of 'cmp'.

=cut 

sub sort_selectall_arrayref {
    my $arrayref = shift;
    my @columns  = @_;
    my @return   = sort {
        for ( my $i = 0 ; $i < $#columns ; $i++ )
        {
            my $col = $columns[$i];
            my $dir = 1;
            if ( $col =~ /^(\S+)\s+(\S+)/ ) {
                $col = $1;
                $dir = -1 if ( $2 eq ( uc 'DESC' ) );
            }
            if ( $col =~ /^#(\S+)/ ) {
                $col = $1;
                if ( $dir * ( $a->{$col} <=> $b->{$col} ) ) {
                    return $dir * ( $a->{$col} <=> $b->{$col} );
                }
            }
            else {
                if ( $dir * ( $a->{$col} cmp $b->{$col} ) ) {
                    return $dir * ( $a->{$col} cmp $b->{$col} );
                }
            }
        }
        my $col = $columns[-1];
        my $dir = 1;
        if ( $col =~ /^(\S+)\s+(\S+)/ ) {
            $col = $1;
            $dir = -1 if ( $2 eq ( uc 'DESC' ) );
        }

        if ( $col =~ /^#(\S+)/ ) {
            $col = $1;
            return $dir * ( $a->{$col} <=> $b->{$col} );
        }
        else {
            return $dir * ( $a->{$col} cmp $b->{$col} );
        }
    } @$arrayref;

    return \@return;
}

# --------------------------
# calculate_units() was swiped from Lincoln Steins
# Bio::Graphics::Glyph::arrow which is distributed
# with Bioperl
# Modified slightly
sub calculate_units {
    my ($length) = @_;
    return 'G' if $length >= 1e9;
    return 'M' if $length >= 1e6;
    return 'K' if $length >= 1e3;
    return ''  if $length >= 1;
    return 'c' if $length >= 1e-2;
    return 'm' if $length >= 1e-3;
    return 'u' if $length >= 1e-6;
    return 'n' if $length >= 1e-9;
    return 'p';
}

# ----------------------------------------------------
sub presentable_number {

=pod
                                                                                
=head2 presentable_number 

Takes a number and makes it pretty. 
example: 10000 becomes 10K

=cut

    my $num = shift;
    my $sig_digits = shift || 2;
    return unless defined($num);
    my $num_str;

    # the "''." is to fix a rounding error in perl
    my $scale          = $num ? int( '' . ( log( abs($num) ) / log(10) ) ) : 0;
    my $rounding_power = $scale - $sig_digits + 1;
    my $rounded_temp   = int( ( $num / ( 10**$rounding_power ) ) + .5 );
    my $printable_num  =
      $rounded_temp / ( 10**( ( $scale - ( $scale % 3 ) ) - $rounding_power ) );
    my $unit = calculate_units( 10**( $scale - ( $scale % 3 ) ) );
    $num_str = $printable_num . " " . $unit;

    return $num_str;
}

# ----------------------------------------------------
sub presentable_number_per {

=pod
                                                                                
=head2 presentable_number_per 

Takes a number and makes it pretty. 
example: .001 becomes "1/K"

=cut

    my $num = shift;
    my $num_str;

    return "0/unit" unless $num;

    # the "''." is to fix a rounding error in perl
    my $scale = $num ? int( '' . ( log( abs($num) ) / log(10) ) ) : 0;
    my $denom_power = $scale - ( $scale % 3 );

    my $printable_num = $num ? $num / ( 10**$denom_power ) : 0;
    $printable_num = sprintf( "%.2f", $printable_num ) if $printable_num;

    my $unit = calculate_units( 10**( -1 * $denom_power ) );
    $num_str = $unit
      ? $printable_num . "/" . $unit
      : $printable_num . "/unit";
    return $num_str;
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

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

