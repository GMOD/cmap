package Bio::GMOD::CMap::Drawer::Feature;

# $Id: Feature.pm,v 1.9 2003-01-08 22:51:57 kycl4rk Exp $

=head1 NAME

Bio::GMOD::CMap::Drawer::Map::Feature - feature object

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Drawer::Map::Feature;
  blah blah blah

=head1 DESCRIPTION

Blah blah blah.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.9 $)[-1];

use Data::Dumper;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Constants;
use base 'Bio::GMOD::CMap';

use constant AUTO_FIELDS => [ 
    qw( map map_id is_visible default_rank feature_type_id feature_type 
        alternate_name feature_id feature_name is_landmark accession_id 
        drawing_lane drawing_priority start_position stop_position 
    )
];

use constant INIT_FIELDS => [
    qw( color shape map )
];

#
# Actually, I'm handling all this elsewhere, so just ignore.
#
use constant SHAPE => {
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
    return $self->{'color'} || $self->config('feature_color');
}

# ----------------------------------------------------
sub feature_details_url {

=pod

=head2 feature_details_url

Returns the URL for the details on the feature.

=cut
    my $self = shift;

    my $url;
    if ( my $mini_template = $self->config('feature_details_url') ) {
        my $t = $self->template or return;
        $t->process( 
            \$mini_template, 
            { feature => $self }, 
            \$url,
        ) or die $t->error;
    }

    return $url || '';
}

# ----------------------------------------------------
sub draw {

=pod

=head2 draw

Draws the feature.

=cut
    my $self          = shift;
    my $shape         = $self->shape || '';
    my $draw_sub_name = SHAPE->{ $shape };
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
sub shape {

=pod

=head2 shape

Returns a string describing how to draw the feature.

=cut
    my $self = shift;

    unless ( $self->{'shape_vetted'} ) {
        my $shape = lc $self->{'shape'} || '';
        $shape    = 'default' unless defined SHAPE->{ $shape };
#        $shape    = LINE 
#            if $self->start_position == $self->stop_position ||
#            !defined $self->stop_position;
        $self->{'shape_vetted'} = $shape;
    }

    return $self->{'shape_vetted'};
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
        my $rel_pos    = sprintf(
            "%.2f", ( $self->start_position - $map_start ) / $map_length
        );
        $self->{'relative_start_position'} = 
            $rel_pos > 1 ? 1 : $rel_pos < 0 ? 0 : $rel_pos;
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
        my $rel_pos    = sprintf(
            "%.2f", ( $self->stop_position - $map_start ) / $map_length
        );
        $self->{'relative_stop_position'} = 
            $rel_pos > 1 ? 1 : $rel_pos < 0 ? 0 : $rel_pos;
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
