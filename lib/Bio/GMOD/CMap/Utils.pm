package Bio::GMOD::CMap::Utils;
# vim: set ft=perl:

# $Id: Utils.pm,v 1.33 2004-05-06 14:06:27 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Utils - generalized utilities

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Utils;
  my $next_number = next_number(...);

=head1 DESCRIPTION

This module contains a couple of general-purpose routines, all of
which are exported by default.

=head1 EXPORTED SUBROUTINES

=cut 

use strict;
use Data::Dumper;
use Bio::GMOD::CMap::Constants;
use POSIX;
require Exporter;
use vars qw( $VERSION @EXPORT @EXPORT_OK );
$VERSION = (qw$Revision: 1.33 $)[-1];

use base 'Exporter';

my @subs   = qw[ 
    column_distribution
    column_distribution2 
    commify 
    extract_numbers 
    label_distribution 
    next_number 
    parse_words
    pk_name
    fake_selectall_arrayref
    sort_selectall_arrayref
];
@EXPORT_OK = @subs;
@EXPORT    = @subs;

# ----------------------------------------------------
sub column_distribution {

=pod

=head2 column_distribution

Given a reference to some columns, figure out where something can be inserted.

=cut

    my %args        = @_;
    my $columns     = $args{'columns'}     || []; # array reference
    my $buffer      = $args{'buffer'}      ||  2; # space b/w things
    my $collapse    = $args{'collapse'}    ||  0; # whether to collapse
    my $collapse_on = $args{'collapse_on'} || ''; # on what type of object
    my $col_span    = $args{'col_span'}    ||  1; # how many cols to occupy
    my $top         = $args{'top'};               # the top and bottom of
    my $bottom      = $args{'bottom'};            # the thing being inserted
    $bottom         = $top unless defined $bottom;

    return unless defined $top && defined $bottom;

    my $column_index; # the number of the column chosen, is returned
    if ( @$columns ) {
        my $i = 0;
        for ( ;; ) {
            last if $i > $#{ $columns };
            my $column    = $columns->[ $i ];
            my @used      = sort { $a->[0] <=> $b->[0] } @{ $column };
            my $ok        = 1;
            my $collapsed = 0;

            for my $segment ( @used ) {
                my ( $north, $south, $span, $type ) = @$segment; 
                if ( 
                    $collapse             && 
                    $collapse_on eq $type && 
                    $north == $top        && 
                    $south == $bottom 
                ) {
                    $ok = 1;
                    $collapsed = 1;
                    last;
                }

                next if $south + $buffer < $top;
                next if $north - $buffer > $bottom;
                $i += $span; # jump past the last taken column
                $ok = 0, last;
            }

            #
            # If this column looks OK, see if there is clearance in the others.
            #
            if ( $ok && $col_span > 1 && $i < $#{ $columns } ) {
                for my $n ( $i + 1 .. $i + $col_span - 1 ) {
                    last if $n > $#{ $columns };
                    my $ncol  = $columns->[ $n ];
                    my @nused = sort { $a->[0] <=> $b->[0] } @{ $ncol };
                    my $nok   = 1;

                    for my $nseg ( @nused ) {
                        my ( $n, $s, $nspan ) = @$nseg; 
                        next if $s + $buffer < $top;
                        next if $n - $buffer > $bottom;
                        $i += $nspan; # jump past the last taken column
                        $ok = 0, last;
                    }
                }
            }

            if ( $ok ) {
                $column_index = $i;
                unless ( $collapsed ) {
                    for my $n ( 0 .. $col_span - 1 ) {
                        push @{ $columns->[ $column_index + $n ] }, [ 
                            $top, $bottom, $col_span - $n, $collapse_on 
                        ];
                    }
                }
                last;
            }
        }

        unless ( defined $column_index ) {
            $column_index = $#{ $columns } + 1;
            for my $n ( 0 .. $col_span - 1 ) {
                push @{ $columns->[ $column_index + $n ] }, [ 
                    $top, $bottom, $col_span - $n, $collapse_on
                ];
            }
        }
    }
    else {
        $column_index = 0;
        for my $n ( 0 .. $col_span - 1 ) {
            push @{ $columns->[ $n ] }, [ 
                $top, $bottom, $col_span - $n, $collapse_on
            ];
        }
    }

    return $column_index;
}

# ----------------------------------------------------
=pod

=head2 column_distribution2

Given a reference to some columns, figure out where something can be inserted.

=cut
sub column_distribution2 {

    my %args        = @_;
    my $columns     = $args{'columns'}     || []; # array reference
    my $buffer      = $args{'buffer'}      ||  2; # space b/w things
    my $collapse    = $args{'collapse'}    ||  0; # whether to collapse
    my $collapse_on = $args{'collapse_on'} || ''; # on what type of object
    my $col_span    = $args{'col_span'}    ||  1; # how many cols to occupy
    my $top         = $args{'top'};               # the top and bottom of
    my $bottom      = $args{'bottom'};            # the thing being inserted
    my $bins        = $args{'bins'}        ||  1; # number of bins              
    my $col_top     = $args{'col_top'}     ||  1; # top of the column     
    my $col_bottom  = $args{'col_bottom'};        # top of the column
  
     $bottom         = $top unless defined $bottom;

    return unless defined $top && defined $bottom && defined $col_bottom;

    ###$columns is an array of columns.  Each column is has a hash of bins.
    ###  Each bin is an array of object start and stops.
    my $bin_factor  = ($col_bottom-$col_top)/$bins;
    ###Define the bins that this object lies in. 
    my $index_start = POSIX::ceil(($top-$col_top)/$bin_factor);      #first bin 
    my $index_stop  = POSIX::ceil(($bottom-$col_top)/$bin_factor); #last bin
  
    ###When the top of the object is higher than the column, it results 
    ###  in negative indices.  This fixes the problem by binning them
    ###  all in the first bin. 
    $index_start=0 if $index_start<0; 
    $index_stop=0 if $index_stop<0;

    my $column_index; # the number of the column chosen, is returned
    if ( @$columns ) {
        my $i = 0;
        for ( ;; ) {
            last if $i > $#{ $columns };
	    my $ok        = 1;
	    my $collapsed = 0;
	  BIN:
	    for (my $bin_no=$index_start; $bin_no<=$index_stop;$bin_no++){
		my $bin    = $columns->[ $i ]->[$bin_no];
		if ($bin){
		    my @used      = sort { $a->[0] <=> $b->[0] } @{ $bin };
		    
		    for my $segment ( @used ) {
			my ( $north, $south, $span, $type ) = @$segment; 
			if ( 
			     $collapse             && 
			     $collapse_on eq $type && 
			     $north == $top        && 
			     $south == $bottom 
			     ) {
			    $ok = 1;
			    $collapsed = 1;
			    return $i;
			    last BIN;
			}
			
			next if $south + $buffer < $top;
			next if $north - $buffer > $bottom;
			$i += $span; # jump past the last taken column
			$ok = 0, last;
		    }
		}
		#
		# If this column looks OK, see if there is clearance in the others.
		#
		if ( $ok && $col_span > 1 && $i < $#{ $columns } ) {
		    for my $n ( $i + 1 .. $i + $col_span - 1 ) {
			last if $n > $#{ $columns };
			my $nbin  = $columns->[ $n ]->[$bin_no];
			next unless $nbin;
			my @nused = sort { $a->[0] <=> $b->[0] } @{ $nbin };
			my $nok   = 1;

			for my $nseg ( @nused ) {
			    my ( $n, $s, $nspan ) = @$nseg; 
			    next if $s + $buffer < $top;
			    next if $n - $buffer > $bottom;
			    $i += $nspan; # jump past the last taken column
			    $ok = 0, last;
			}
		    }
		}
	    }
            if ( $ok ) {
                $column_index = $i;
                unless ( $collapsed ) {
                    for my $n ( 0 .. $col_span - 1 ) {
			for (my $k=$index_start; $k<=$index_stop;$k++){
			    push @{ $columns->[ $column_index + $n ]->[$k] }, 
			    [$top, $bottom, $col_span - $n, $collapse_on ];
			}
                    }
                }
                last;
            }
        }

        unless ( defined $column_index ) {
            $column_index = $#{ $columns } + 1;
            for my $n ( 0 .. $col_span - 1 ) {
		for (my $k=$index_start; $k<=$index_stop;$k++){
		    push @{ $columns->[ $column_index + $n ]->[$k] }, 
		    [ $top, $bottom, $col_span - $n, $collapse_on];
		}
            }
        }
    }
    else {
        $column_index = 0;
        for my $n ( 0 .. $col_span - 1 ) {
	    for (my $k=$index_start; $k<=$index_stop;$k++){
		push @{ $columns->[ $n ]->[$k] }, 
		[ $top, $bottom, $col_span - $n, $collapse_on];
	    }
        }

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
    my $no_requested   = $args{'requested'}   || 1;

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
            {}, ( $table_name, $next_number+$no_requested )
        );
    }
    else {
        $db->do(
            q[
                update cmap_next_number
                set    next_number=?
                where  table_name=?
            ],
            {}, ( $next_number+$no_requested, $table_name )
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

    my %args       = @_;
    my $labels     = $args{'labels'};
    my $accepted   = $args{'accepted'};
    my $buffer     = $args{'buffer'}     ||     2;
    my $direction  = $args{'direction'}  || NORTH; # NORTH or SOUTH?
    my $row_height = $args{'row_height'} ||     1; # how tall a row is
    my $used       = $args{'used'}       ||    [];
    my $reverse    = $direction eq NORTH ? -1 : 1;
    my @used       = sort { $reverse * ( $a->[0] <=> $b->[0] ) } @$used;

    for my $label ( @{ $labels || [] } ) {
        my $max_distance = $label->{'has_corr'}       ? 15 : 10;
        my $can_skip     = $label->{'is_highlighted'} ?  0 :  1;
        my $target       = $label->{'target'} || 0; # desired location
        my $top          = $target;
        my $bottom       = $target + $row_height;
        my $ok           = 1; # assume innocent until proven guilty

        SEGMENT:
        for my $i ( 0 .. $#used ) {
            my $segment = $used[ $i ] or next;
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

        if ( $inquote ) {
            push(@words, substr($string, $pos, $nextquote - $pos));
            $pos = $nextquote + 2;
            $inquote = 0;
        } 
        elsif ( $nextspace < $nextquote ) {
            push @words, 
                split /[,\s+]/, substr($string, $pos, $nextspace - $pos);
            $pos = $nextspace + 1;
        } 
        elsif ( $nextspace == $length && $nextquote == $length ) {
            # End of the line
            push @words, 
                map { s/^\s+|\s+$//g; $_ }
                split /,/,
                substr( $string, $pos, $nextspace - $pos );
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

# ----------------------------------------------------
sub pk_name {
    my $table_name = shift;
    $table_name    =~ s/^cmap_//;
    $table_name   .=  '_id';
    return $table_name;
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
    foreach my $column (@columns){
	if ($column=~/(\S+)\s+as\s+(\S+)/){
	    $column=$1;
            $column_name{$1}=$2;
        }
	else{
            $column_name{$column}=$column;
        }
    }
    for my $key ( keys(%$hashref) ) {
        %{ $return_array[$i] } = map { 
            $column_name{$_} => $hashref->{$key}->{$_} } @columns;
        $i++;
    }
    @return_array =
      sort { $a->{ $columns[0] } cmp $b->{ $columns[0] } } @return_array;
    return \@return_array;
}

# ----------------------------------------------------
=pod

=head2 sort_selectall_arrayref


=cut 

sub sort_selectall_arrayref{
    my $arrayref = shift;
    my @columns  = @_;
    my @return   = sort {
        for ( my $i = 0 ; $i < $#columns ; $i++ ) {
            if ( $a->{ $columns[$i] } cmp $b->{ $columns[$i] } ) {
                return $a->{ $columns[$i] } cmp $b->{ $columns[$i] };
            }
        }
        return $a->{ $columns[-1] } cmp $b->{ $columns[-1] };
    } @$arrayref;

    return \@return;
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
