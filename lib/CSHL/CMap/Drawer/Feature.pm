package CSHL::CMap::Drawer::Feature;

# $Id: Feature.pm,v 1.1.1.1 2002-07-31 23:27:28 kycl4rk Exp $

=head1 NAME

CSHL::CMap::Drawer::Map::Feature - feature object

=head1 SYNOPSIS

  use CSHL::CMap::Drawer::Map::Feature;
  blah blah blah

=head1 DESCRIPTION

Blah blah blah.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.1.1.1 $)[-1];

use Data::Dumper;
use CSHL::CMap;
use CSHL::CMap::Constants;
use base 'CSHL::CMap';

use constant AUTO_FIELDS => [ 
    qw( map map_id is_visible default_rank feature_type alternate_name
        feature_id feature_name is_landmark accession_id
        start_position stop_position 
    )
];

use constant INIT_FIELDS => [
    qw( color how_to_draw map )
];

#
# Actually, I'm handling all this elsewhere, so just ignore.
#
use constant HOW_TO_DRAW => {
    default  => 'draw_line', #'draw_span',
    box      => 'draw_line', #'draw_box',
    line     => 'draw_line',
    span     => 'draw_line', #'draw_span',
    dumbbell => 1,
};

BEGIN {
    #
    # Create automatic accessor methods.
    #
    foreach my $sub_name ( @{ +AUTO_FIELDS } ) {
        no strict 'refs';
        unless ( defined &$sub_name ) {
            *{ $sub_name } = sub { shift()->{ $sub_name } };
        }
    }
}

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->params( $config, @{ +AUTO_FIELDS }, @{ +INIT_FIELDS } );
    return $self;
}

# ----------------------------------------------------
sub color {

=pod

=head2 color

Returns the color of the feature.

=cut
    my $self = shift;
    return lc $self->{'color'} || lc DEFAULT->{'feature_color'};
}

# ----------------------------------------------------
sub draw {

=pod

=head2 draw

Draws the feature.

=cut
    my $self          = shift;
    my $how_to_draw   = $self->how_to_draw || '';
    my $draw_sub_name = HOW_TO_DRAW->{ $how_to_draw };
    $self->$draw_sub_name( @_ );
}

# ----------------------------------------------------
sub draw_line {

=pod

=head2 draw_line

Draws the feature as a line.

=cut
    my ( $self, %args ) = @_;
    my $drawer          = $args{'drawer'} or $self->error('No drawer');
    my @coords          = @{ $args{'coords'} || [] } or 
                          $self->error('No coords');
    my $color           = $self->color;

    $drawer->add_drawing( LINE, @coords, $color );

    return 1;
}

# ----------------------------------------------------
sub how_to_draw {

=pod

=head2 how_to_draw

Returns a string describing how to draw the feature.

=cut
    my $self = shift;

    unless ( $self->{'how_to_draw_vetted'} ) {
        my $how_to_draw = lc $self->{'how_to_draw'} || '';
        $how_to_draw    = 'default' 
            unless defined HOW_TO_DRAW->{ $how_to_draw };
        $how_to_draw    = 'line' 
            if $self->start_position == $self->stop_position ||
            !defined $self->stop_position;
#        $how_to_draw = 'span' 
#            if $how_to_draw eq 'line' && 
#            $self->stop_position > $self->start_position;
        $self->{'how_to_draw_vetted'} = $how_to_draw;
    }

    return $self->{'how_to_draw_vetted'};
}

# ----------------------------------------------------
sub relative_start_position {

=pod

=head2 relative_start_position

Returns the start position of the feature relative to the overall 
length of the map.

=cut
    my $self = shift;

    unless ( defined $self->{'relative_start_position'} ) {
        my $map        = $self->map;
        my $map_id     = $self->map_id;
        my $map_start  = $map->start_position( $map_id );
        my $map_stop   = $map->stop_position( $map_id );
        my $map_length = ( $map_stop - $map_start ) || 1;
        $self->{'relative_start_position'} = sprintf(
            "%.2f", ( $self->start_position - $map_start ) / $map_length
        );
    }

    return $self->{'relative_start_position'};
}

# ----------------------------------------------------
sub relative_stop_position {

=pod

=head2 relative_stop_position

Returns the stop position of the feature relative to the overall 
length of the map.

=cut
    my $self = shift;

    unless ( defined $self->{'relative_stop_position'} ) {
        my $map        = $self->map;
        my $map_id     = $self->map_id;
        my $map_start  = $map->start_position( $map_id );
        my $map_stop   = $map->stop_position( $map_id );
        my $map_length = ( $map_stop - $map_start ) || 1;
        $self->{'relative_stop_position'} = sprintf(
            "%.2f", ( $self->stop_position - $map_start ) / $map_length
        );
    }

    return $self->{'relative_stop_position'};
}

1;

# ----------------------------------------------------
# And all that's best of dark and bright
# Meet in her aspect and her eyes.
# Lord Byron
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
