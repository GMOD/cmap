package Bio::GMOD::CMap::Drawer::Map;

# $Id: Map.pm,v 1.29 2003-02-11 00:22:22 kycl4rk Exp $

=pod

=head1 NAME

Bio::GMOD::CMap::Drawer::Map - draw a map

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Drawer::Map;
  blah blah blah

=head1 DESCRIPTION

You'll never directly use this module.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.29 $)[-1];

use Data::Dumper;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Drawer::Feature;
use Bio::GMOD::CMap::Utils qw[ column_distribution label_distribution ];

use base 'Bio::GMOD::CMap';

use constant AUTO_FIELDS => [
    qw( map_set_id map_set_aid map_type accession_id species_id map_id 
        species_name map_units map_name map_set_name map_type_id 
        is_relational_map begin end 
    )
];

use constant INIT_FIELDS => [
    qw( drawer base_x base_y slot_no maps )
];

use constant SHAPE => {
    'default'  => 'draw_box',
    'box'      => 'draw_box',
    'dumbbell' => 'draw_dumbbell',
    'I-beam'   => 'draw_i_beam',
};

BEGIN {
    #
    # Create automatic accessor methods.
    #
    foreach my $sub_name ( @{ +AUTO_FIELDS } ) {
        no strict 'refs';
        unless ( defined &$sub_name ) {
            *{ $sub_name } = sub { 
                my $self   = shift;
                my $map_id = shift;
                return $self->{'maps'}{ $map_id }{ $sub_name } 
            };
        }
    }
}

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->params( $config, @{ +INIT_FIELDS } );
    return $self;
}

# ----------------------------------------------------
sub base_x {

=pod

=head2 base_x

Figure out where right-to-left this map belongs.

=cut

    my $self        = shift;
    my $slot_no     = $self->slot_no or return 0; # slot "0" is in the middle
    my $drawer      = $self->drawer;
#    my $ref_slot_no = $drawer->reference_slot_no( $slot_no );
    my $buffer      = 15;
#    my ( $ref_left, $ref_right ) = 
#        $drawer->slot_sides( slot_no => $ref_slot_no );

    my $base_x;
    if ( 
        ( $slot_no == -1 && $drawer->total_no_slots == 2 )
        ||
        ( $slot_no < 0 )
    ) {
        $base_x = $drawer->min_x - $buffer;
#        $base_x = $ref_left - $buffer;
    }
    else {
        $base_x = $drawer->max_x + $buffer;
#        $base_x = $ref_right + $buffer;
    }

    return $base_x;
}

# ----------------------------------------------------
sub base_y {

=pod

=head2 base_y

Return the base y coordinate.

=cut

    my $self = shift;
    return $self->{'base_y'} || 0;
}

# ----------------------------------------------------
sub color {

=pod

=head2 color

Returns the color of the map.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map( $map_id );
    return 
        $map->{'color'}         || 
        $map->{'default_color'} || 
        $self->config('map_color');
}

# ----------------------------------------------------
sub drawer {

=pod

=head2 drawer

Returns the Bio::GMOD::CMap::Drawer object.

=cut

    my $self = shift;
    return $self->{'drawer'};
}

# ----------------------------------------------------
sub draw_box {

=pod

=head2 draw_box

Draws the map as a "box" (a filled-in rectangle).  Return the bounds of the
box.

=cut

    my ( $self, %args )  = @_;
    my $drawer           = $args{'drawer'} || $self->drawer or 
                           $self->error('No drawer');
    my ( $x1, $y1, $y2 ) = @{ $args{'coords'} || [] } or 
                           $self->error('No coordinates');
    my $color            = $self->color( $args{'map_id'} );
    my $width            = $self->map_width( $args{'map_id'} );
    my $x2               = $x1 + $width;
    my @coords           = ( $x1, $y1, $x2, $y2 ); 

    $drawer->add_drawing( FILLED_RECT, @coords, $color  );
    $drawer->add_drawing( RECTANGLE,   @coords, 'black' );
    
    if ( my $map_units = $args{'map_units'} ) {
        my $buf  = 2;
        my $font = $drawer->regular_font;
        my $x    = $x1 + ( ( $x2 - $x1 ) / 2 ) -
                   ( ( $font->width * length( $map_units ) ) / 2 );
        my $y    = $y2 + $buf;
        $drawer->add_drawing( STRING, $font, $x, $y, $map_units, 'grey' );
        $coords[3] += $font->height;
    }

    return @coords;
}

# ----------------------------------------------------
sub draw_dumbbell {

=pod

=head2 draw_dumbbell

Draws the map as a "dumbbell" (a line with circles on the ends).  Return the
bounds of the image.

=cut

    my ( $self, %args )  = @_;
    my $drawer           = $args{'drawer'} || $self->drawer or 
                           $self->error('No drawer');
    my ( $x1, $y1, $y2 ) = @{ $args{'coords'} || [] } or 
                           $self->error('No coordinates');
    my $color            = $self->color( $args{'map_id'} );
    my $width            = $self->map_width( $args{'map_id'} );
    my $x2               = $x1 + $width;
    my $mid_x            = $x1 + $width/2;
    my $arc_width        = $width + 6;

    $drawer->add_drawing(
        ARC, $mid_x, $y1, $arc_width, $arc_width, 0, 360, $color
    );
    $drawer->add_drawing(
        ARC, $mid_x, $y2, $arc_width, $arc_width, 0, 360, $color
    );
    $drawer->add_drawing( FILL_TO_BORDER, $mid_x, $y1, $color, $color );
    $drawer->add_drawing( FILL_TO_BORDER, $mid_x, $y2, $color, $color );
    $drawer->add_drawing( FILLED_RECT, $x1, $y1, $x2, $y2, $color );
    
    if ( my $map_units = $args{'map_units'} ) {
        my $buf  = 2;
        my $font = $drawer->regular_font;
        my $x    = $x1 + ( ( $x2 - $x1 ) / 2 ) -
                   ( ( $font->width * length( $map_units ) ) / 2 );
        my $y    = $y2 + $buf;
        $drawer->add_drawing( STRING, $font, $x, $y, $map_units, 'grey' );
        $y2 += $font->height;
    }

    return ( 
        $mid_x - $arc_width/2, $y1 - $arc_width/2,
        $mid_x + $arc_width/2, $y2 + $arc_width/2,
    );
}

# ----------------------------------------------------
sub draw_i_beam {

=pod

=head2 draw_i_beam

Draws the map as an "I-beam."  Return the bounds of the image.

=cut

    my ( $self, %args )  = @_;
    my $drawer           = $args{'drawer'} || $self->drawer or 
                           $self->error('No drawer');
    my ( $x1, $y1, $y2 ) = @{ $args{'coords'} || [] } or 
                           $self->error('No coordinates');
    my $color            = $self->color( $args{'map_id'} );
    my $width            = $self->map_width( $args{'map_id'} );
    my $x2               = $x1 + $width;
    my $x                = $x1 + $width/2;

    $drawer->add_drawing( LINE, $x , $y1, $x , $y2, $color );
    $drawer->add_drawing( LINE, $x1, $y1, $x2, $y1, $color );
    $drawer->add_drawing( LINE, $x1, $y2, $x2, $y2, $color );

    if ( my $map_units = $args{'map_units'} ) {
        my $buf  = 2;
        my $font = $drawer->regular_font;
        my $x    = $x1 + ( ( $x2 - $x1 ) / 2 ) -
                   ( ( $font->width * length( $map_units ) ) / 2 );
        my $y    = $y2 + $buf;
        $drawer->add_drawing( STRING, $font, $x, $y, $map_units, 'grey' );
        $y2 += $font->height;
    }

    return ( $x1, $y1, $x2, $y2 ); 
}

# ----------------------------------------------------
sub features {

=pod

=head2 features

Returns all the features on the map (as objects).  Features are stored
in raw format as a hashref keyed on feature_id.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map( $map_id );

    unless ( defined $map->{'feature_store'} ) {
        for my $data ( 
            map  { $_->[0] }
            sort { 
                $a->[1] <=> $b->[1]
                ||
                $a->[2] <=> $b->[2]
                ||
                $a->[3] <=> $b->[3] 
                ||
                $a->[4] <=> $b->[4] 
            }
            map  { [
                $_, 
                $_->{'drawing_lane'}, 
                $_->{'drawing_priority'}, 
                $_->{'start_position'},
                $_->{'stop_position'}
            ] }
            values %{ $map->{'features'} } 
        ) {
            push @{ $map->{'feature_store'}{ $data->{'drawing_lane'} } }, 
                Bio::GMOD::CMap::Drawer::Feature->new( 
                    map    => $self,
                    map_id => $map_id,
                    %$data,
                )
            ;
        }
    }

    return $map->{'feature_store'};
}

# ----------------------------------------------------
#sub feature_positions {
#
#=pod
#
#=head2 feature_positions
#
#Returns the feature positions on the map.
#
#=cut
#    my $self   = shift;
#    my $map_id = shift or return;
#    my $map    = $self->map( $map_id );
#
#    unless ( $map->{'feature_positions'} ) {
#        $map->{'feature_positions'} = 
#            [ sort { $a <=> $b } keys %{ $map->{'features'} } ];
#    }
#
#    return @{ $map->{'feature_positions'} || [] };
#}

# ----------------------------------------------------
sub shape {

=pod

=head2 shape

Returns a string describing how to draw the map.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map( $map_id );
    my $shape  = $map->{'shape'} || $map->{'default_shape'} || '';
       $shape  = 'default' unless defined SHAPE->{ $shape };
    return $shape;
}

# ----------------------------------------------------
sub layout {

=pod

=head2 layout

Lays out the map.

=cut

    my $self           = shift;
    my $base_y         = $self->base_y;
    my $slot_no        = $self->slot_no;
    my $drawer         = $self->drawer;
    my $label_side     = $drawer->label_side( $slot_no );
    my $pixel_height   = $drawer->pixel_height;
    my $label_font     = $drawer->label_font;
    my $reg_font       = $drawer->regular_font;
    my $slots          = $drawer->slots;
    my @map_ids        = $self->map_ids;
    my $no_of_maps     = scalar @map_ids;
    my @columns        = ();
    my $label_features = $drawer->label_features;

    #
    # The title is often the widest thing we'll draw, so we need
    # to figure out which is the longest and take half its length
    # into account when deciding where to start with the map(s).
    #
    my @config_map_titles = $self->config('map_titles');
    my $longest;
    for my $map_id ( @map_ids ) {
        for my $length ( 
            map { length $self->$_($map_id) } @config_map_titles 
        ) {
            $longest = $length if $length > $longest;
        }
    }
    my $half_title_length = ( $reg_font->width * $longest ) / 2 + 10;
    my $original_base_x = $label_side eq RIGHT
        ? $self->base_x + $half_title_length
        : $self->base_x - $half_title_length;

    #
    # These are for drawing the map titles last if this is a relational map.
    #
    my ( 
        $is_relational,    # if one map is relational, the whole map set is
        $top_y,            # northernmost coord for the slot
        $bottom_y,         # southernmost coord for the slot
        $slot_min_x,       # easternmost coord for the slot
        $slot_max_x,       # westernmost coord for the slot
        @map_titles,       # the titles to put above - for relational maps
        $map_set_aid,      # the map set acc. ID - for relational maps
        %feature_type_ids, # the distinct feature type IDs
    );

    for my $map_id ( @map_ids ) {
        $is_relational     = $self->is_relational_map( $map_id );
        my $base_x         = $label_side eq RIGHT
                             ? $self->base_x + $half_title_length + 10
                             : $self->base_x - $half_title_length - 20;
        my $show_labels    = $is_relational && $slot_no != 0 ? 0 :
                             $label_features eq 'none' ? 0 : 1 ;
        my $show_ticks     = $is_relational && $slot_no != 0 ? 0 : 1;
        my $show_map_title = $is_relational && $slot_no != 0 ? 0 : 1;
        my $show_map_units = $is_relational && $slot_no != 0 ? 0 : 1;
        my $map_width      = $self->map_width( $map_id );
        my $column_width   = $map_width + $reg_font->height + 20;
        my $features       = $self->features( $map_id );

        #
        # The map.
        #
        my ( $min_x, $max_x, $area );
        my $draw_sub_name = SHAPE->{ $self->shape( $map_id ) };
        if ( $is_relational && $slot_no != 0 ) {
            #
            # Relational maps are drawn to a size relative to the distance
            # their features correspond to features on the reference map.
            # So, we need to find all the features with correspondences and
            # find the "tick_y" position any have in the reference slot.
            # Put them in ascending numerical order and use the first and last
            # to find the height.
            #
            my @corr_feature_ids;
            for my $lane ( keys %$features ) {
                push @corr_feature_ids, map { 
                    $drawer->has_correspondence( $_->feature_id ) 
                    ? $_->feature_id : ()
                } @{ $features->{ $lane } };
            }
            next unless @corr_feature_ids;

            my @positions   =  sort{ $a <=> $b } $drawer->tick_y_positions(
                slot_no     => $drawer->reference_slot_no( $slot_no ),
                feature_ids => \@corr_feature_ids,
            );

            my $min_map_pixel_height = $self->config('min_map_pixel_height');
            $pixel_height    = $positions[-1] - $positions[0];
            $pixel_height    = $min_map_pixel_height
                if $pixel_height < $min_map_pixel_height;
            my $midpoint     = ( $positions[0] + $positions[-1] ) / 2;
            $base_y          = $midpoint - $pixel_height/2;
            my $map_name     = $self->map_name( $map_id );
            my $half_label   = ( $reg_font->width * length( $map_name ) ) / 2;
            my $label_top    = $midpoint - $half_label;
            my $label_bottom = $midpoint + $half_label;
            my $top          = $base_y < $label_top ? $base_y : $label_top;
            my $bottom       = $base_y + $pixel_height > $label_bottom ?
                               $base_y + $pixel_height : $label_bottom ;
            my $buffer       = 4;
            my $column_index = column_distribution(
                columns      => \@columns,
                top          => $top,
                bottom       => $bottom,
                buffer       => $buffer,
            );

            $base_x = $label_side eq RIGHT 
                ? $original_base_x + ( $column_width * $column_index )
                : $original_base_x - ( $column_width * $column_index );

            my $label_x = $label_side eq RIGHT
                ? $base_x + $map_width + 6 
                : $base_x - $reg_font->height - 6;

            $drawer->add_drawing(
                STRING_UP, $reg_font, $label_x, $label_bottom,
                $map_name, 'black'
            );

            my $leftmost = $label_side eq RIGHT
                ? $base_x
                : $label_x;
            my $rightmost = $label_side eq RIGHT
                ? $label_x + $reg_font->height
                : $base_x + $map_width + 6;

            $min_x = $leftmost  unless defined $min_x;
            $max_x = $rightmost unless defined $max_x;
            $min_x = $leftmost  if $leftmost  < $min_x;
            $max_x = $rightmost if $rightmost > $max_x;
            $area  = [ $leftmost, $top, $rightmost, $bottom ];
        }

        $top_y = $base_y unless defined $top_y;
        $top_y = $base_y if $base_y < $top_y;

        my @map_bounds =  $self->$draw_sub_name(
            map_id     => $map_id,
            map_units  => $show_map_units ? $self->map_units( $map_id ) : '',
            drawer     => $drawer,
            coords     => [ $base_x, $base_y, $base_y + $pixel_height ],
            area       => $area,
        );

        if ( $drawer->highlight_feature( $self->map_name( $map_id ) ) ) {
            $drawer->add_drawing(
                RECTANGLE, @map_bounds, 
                $self->config('feature_highlight_fg_color')
            );

            $drawer->add_drawing(
                FILLED_RECT, @map_bounds, 
                $self->config('feature_highlight_bg_color'),
                0
            );
        }

        $min_x    = $map_bounds[0] unless defined $min_x;
        $min_x    = $map_bounds[0] if $map_bounds[0] < $min_x;
        $max_x    = $map_bounds[2] unless defined $max_x;
        $max_x    = $map_bounds[2] if $map_bounds[2] > $max_x;
        $bottom_y = $map_bounds[3] unless defined $bottom_y;
        $bottom_y = $map_bounds[3] if $map_bounds[3] > $bottom_y;

        #
        # Tick marks.
        #
        if ( $show_ticks ) {
            my $interval      = $self->tick_mark_interval( $map_id ) || 1;
            my $map_length    = $self->map_length( $map_id );
            my $no_intervals  = int( $map_length / $interval );
            my $tick_overhang = 5;
            my $start         = $self->start_position( $map_id );
            my @intervals     = map { 
                int ( $start + ( $_ * $interval ) ) 
            } 1 .. $no_intervals;

            for my $tick_pos ( @intervals ) {
                my $rel_position = ( $tick_pos - $start ) / $map_length;
                my $y_pos        = $base_y + ( $pixel_height * $rel_position );
                my $tick_start   = $label_side eq RIGHT
                    ? $base_x - $tick_overhang
                    : $base_x
                ;

                my $tick_stop     = $label_side eq RIGHT
                    ? $base_x + $map_width
                    : $base_x + $map_width + $tick_overhang
                ;

                $drawer->add_drawing(
                    LINE, $tick_start, $y_pos, $tick_stop, $y_pos, 'grey'
                );

                my $label_x = $label_side eq RIGHT 
                    ? $tick_start - $reg_font->height - 2
                    : $tick_stop  + 2
                ;

                my $label_y = $y_pos + ($reg_font->width*length($tick_pos))/2;

                $drawer->add_drawing(
                    STRING_UP, $reg_font, $label_x, $label_y, $tick_pos, 'grey'
                );

                my $right = $label_x + $reg_font->height;
                $max_x    = $right   if $right  > $max_x;
                $min_x    = $label_x if $label_x < $min_x;
            }
        }

#        #
#        # Add "Delete" and "Flip" if appropriate.
#        #
#        unless ( 
#            ( $is_relational && $slot_no != 0 )
#            ||
#            $slot_no == 0
#            ||
#            $slots->{ $slot_no }{'field'} eq 'map_set_aid'
#        ) {
#            my $buffer     = 4;
#            my $map_left   = $map_bounds[0];
#            my $map_right  = $map_bounds[2];
#            my $map_bottom = $map_bounds[3] + $reg_font->height;
#            my $map_middle = $map_left + ( ( $map_right - $map_left ) / 2 );
#            my $string     = '(Delete)';
#            my $string_x   =
#                $map_middle - ( $reg_font->width * ( length( $string ) ) / 2 );
#            my $string_y   = $map_bottom + $buffer;
#            $drawer->add_drawing(
#                STRING,
#                $reg_font,
#                $string_x,
#                $string_y,
#                $string,
#                'black',
#            );
#
#            #
#            # To select the other comparative maps, we have to cut off
#            # everything after the current map.  E.g., if there are maps in
#            # slots -2, -1, 0, 1, and 2, for slot 1 we should choose everything
#            # less than it (and non-zero).  The opposite is true for negative
#            # slots.
#            #
#            my @ordered_slot_nos = sort { $a <=> $b } keys %$slots;
#            my @cmap_nos;
#            if ( $slot_no < 0 ) {
#                push @cmap_nos, grep { $_>$slot_no && $_!=0 } @ordered_slot_nos;
#            }
#            else {
#                push @cmap_nos, grep { $_<$slot_no && $_!=0 } @ordered_slot_nos;
#            }
#
#            my $cmaps = join('%3a',
#                map { 
#                    join('%3d', $_, $slots->{$_}{'field'}, $slots->{$_}{'aid'})
#                } @cmap_nos
#            );
#
#            my $url = $self->config('cmap_viewer_url').
#                '?ref_map_set_aid='.$slots->{0}{'map_set_aid'}.
#                ';ref_map_aid='.$slots->{0}{'aid'}.
#                ';ref_map_start='.$slots->{0}{'start'}.
#                ';ref_map_stop='.$slots->{0}{'stop'}.
#                ";comparative_maps=$cmaps";
#
#            my $string_bottom = $string_y + $reg_font->height;
#            $drawer->add_map_area(
#                coords => [
#                    $string_x, 
#                    $string_y, 
#                    $string_x + ( $reg_font->width * length( $string ) ),
#                    $string_bottom,
#                ], 
#                url    => $url,
#                alt    => 'Delete '.$self->map_name,
#            );
#            $bottom_y = $string_bottom if $string_bottom > $bottom_y;
#        }
    
        #
        # Features.
        #
        my $min_y = $base_y;          # remembers the northermost position
        my %lanes;                    # associate priority with a lane
        my $prev_lane_no;             # the previous lane
        my ($leftmostf, $rightmostf); # furthest features

        for my $lane ( sort { $a <=> $b } keys %$features ) {
            my %features_with_corr;           # features w/correspondences
            my (@north_labels,@south_labels); # holds label coordinates
            my $lane_features       = $features->{ $lane };
            my $midpoint            = (
                $lane_features->[ 0]->start_position +
                $lane_features->[-1]->start_position
            ) / 2;

            my $prev_label_y;   # the y value of previous label
            my @fcolumns  = (); # for feature east-to-west

            #
            # Use the "drawing_lane" to determine where to draw the feature.
            #
            unless ( exists $lanes{ $lane } ) {
                $lanes{ $lane } = {
                    order    => ( scalar keys %lanes ) + 1,
                    furthest => $label_side eq RIGHT 
                                ? $rightmostf : $leftmostf,
                };

                my $lane = $lanes{ $lane };
                $base_x  = $lane->{'furthest'} 
                    ? $label_side eq RIGHT
                        ? $lane->{'furthest'} + 2
                        : $lane->{'furthest'} - 2
                    : $base_x;
            }

            for my $feature ( @$lane_features ) {
                #
                # If the map isn't showing labeled features (e.g., it's a
                # relational map and hasn't been expanded), then leave off 
                # drawing features that don't have correspondences.
                #
                my $has_corr = 
                    $drawer->has_correspondence( $feature->feature_id );

                next if 
                    $is_relational && # a relational map
                    $slot_no != 0  && # that isn't the reference map
                    !$has_corr     && # it has no correspondences
                    !$show_labels;    # we're not showing labels

                my $tick_overhang = 2;
                my $y_pos1        = $base_y +
                    ( $pixel_height * $feature->relative_start_position );
                my $y_pos2        = $base_y +
                    ( $pixel_height * $feature->relative_stop_position );

                my $color      = $has_corr 
                    ? $self->config('feature_correspondence_color') ||
                      $feature->color
                    : $feature->color;
                my $label      = $feature->feature_name;
                my $tick_start = $base_x - $tick_overhang;
                my $tick_stop  = $base_x + $map_width + $tick_overhang;
                my $label_y;
                my @coords;

                if ( $feature->shape eq LINE ) {
                    $drawer->add_drawing(
                        LINE, $tick_start, $y_pos1, $tick_stop, $y_pos1, $color
                    );
                    $label_y = $y_pos1 - $reg_font->height/2;
                    @coords  = ( $tick_start, $y_pos1, $tick_stop, $y_pos1 );
                }
                else {
                    my $buffer       = 2;
                    my $column_index = column_distribution(
                        columns      => \@fcolumns,
                        top          => $y_pos1,
                        bottom       => $y_pos2,
                        buffer       => $buffer,
                    );
                    my $offset       = ( $column_index + 1 ) * 6;
                    my $vert_line_x1 = $label_side eq RIGHT
                        ? $tick_start : $tick_stop;
                    my $vert_line_x2 = $label_side eq RIGHT 
                        ? $tick_stop + $offset : $tick_start - $offset;
                    $label_y = ( $y_pos1 + ( $y_pos2 - $y_pos1 ) / 2 ) -
                        $reg_font->height/2;

                    if ( $y_pos1 < $y_pos2 ) {
                        $drawer->add_drawing(
                            LINE, 
                            $vert_line_x2, $y_pos1, 
                            $vert_line_x2, $y_pos2, 
                            $color,
                        );
                    }

                    if ( $feature->shape eq 'span' ) {
                        $drawer->add_drawing(
                            LINE, 
                            $vert_line_x1, $y_pos1, 
                            $vert_line_x2, $y_pos1, 
                            $color,
                        );

                        $drawer->add_drawing(
                            LINE, 
                            $vert_line_x2, $y_pos2, 
                            $vert_line_x1, $y_pos2, 
                            $color,
                        );
                        @coords = (
                            $vert_line_x2, $y_pos1, $vert_line_x2, $y_pos2
                        );
                    }
                    elsif ( $feature->shape eq 'up-arrow' ) {
                        $drawer->add_drawing(
                            LINE,
                            $vert_line_x2, $y_pos1,
                            $vert_line_x2 - 2, $y_pos1 + 2,
                            $color
                        );

                        $drawer->add_drawing(
                            LINE,
                            $vert_line_x2, $y_pos1,
                            $vert_line_x2 + 2, $y_pos1 + 2,
                            $color
                        );

                        @coords = (
                            $vert_line_x2 - 2, $y_pos2,
                            $vert_line_x2 + 2, $y_pos1, $color
                        );
                    }
                    elsif ( $feature->shape eq 'down-arrow' ) {
                        $drawer->add_drawing(
                            LINE,
                            $vert_line_x2, $y_pos2,
                            $vert_line_x2 - 2, $y_pos2 - 2,
                            $color
                        );

                        $drawer->add_drawing(
                            LINE,
                            $vert_line_x2, $y_pos2,
                            $vert_line_x2 + 2, $y_pos2 - 2,
                            $color
                        );

                        @coords = (
                            $vert_line_x2 - 2, $y_pos2,
                            $vert_line_x2 + 2, $y_pos1, $color
                        );
                    }
                    elsif ( $feature->shape eq 'box' ) {
                        $vert_line_x1 = $label_side eq RIGHT
                            ? $tick_start - $offset : $tick_stop + $offset;
                        $vert_line_x2 = $label_side eq RIGHT 
                            ? $tick_stop + $offset : $tick_start - $offset;

                        @coords = (
                            $vert_line_x2, $y_pos2,
                            $vert_line_x1, $y_pos1, 
                        );

                        $drawer->add_drawing( RECTANGLE, @coords, $color );
                    }
                    else { # dumbbell
                        my $width = 3;
                        $drawer->add_drawing(
                            ARC, 
                            $vert_line_x2, $y_pos1,
                            $width, $width, 0, 360, $color
                        );

                        $drawer->add_drawing(
                            ARC, 
                            $vert_line_x2, $y_pos2,
                            $width, $width, 0, 360, $color
                        );
                        @coords = (
                            $vert_line_x2 - $width/2, $y_pos1, 
                            $vert_line_x2 + $width/2, $y_pos2
                        );
                    }

                    $drawer->add_map_area(
                        coords => \@coords,
                        url    => $feature->feature_details_url,
                        alt    => 'Details: '.$feature->feature_name,
                    );
                }

                #
                # Register that we saw this type of feature.
                #
                $feature_type_ids{ $feature->feature_type_id } = 1;

                my $is_highlighted = 
                    $drawer->highlight_feature( $feature->feature_name );

                if ( $has_corr ) {
                    my $mid_feature = ( $coords[1] + $coords[3] ) / 2;
                    $features_with_corr{ $feature->feature_id } = {
                        feature_id => $feature->feature_id,
                        slot_no    => $slot_no,
                        map_id     => $map_id,
                        left       => [ $coords[0], $mid_feature ],
                        right      => [ $coords[2], $mid_feature ],
                        tick_y     => $mid_feature,
#                        feature_correspondence_id => $,r
                    };
                }

                my ( $left_side, $right_side );
                if ( 
                    $show_labels                 && (
                        $has_corr                || 
                        $label_features eq 'all' ||
                        $is_highlighted          || (
                            $label_features eq 'landmarks' && 
                            $feature->is_landmark 
                        )
                    )
                ) {
                    my $labels = $feature->start_position < $midpoint
                        ? \@north_labels : \@south_labels;
                    push @$labels, {
                        priority       => $feature->drawing_priority,
                        text           => $label,
                        target         => $label_y,
                        color          => $color,
                        font           => $reg_font,
                        is_highlighted => $is_highlighted,
                        feature_coords => \@coords,
                        feature_type   => $feature->feature_type,
                        url            => $feature->feature_details_url,
                        has_corr       => $has_corr,
                        feature_id     => $feature->feature_id,
                        start_position => $feature->start_position,
                        shape          => $feature->shape,
                    };
                }

                my $buffer  = 2;
                $left_side  = $coords[0] - $buffer;
                $right_side = $coords[2] + $buffer;
                $leftmostf  = $left_side  unless defined $leftmostf;
                $rightmostf = $right_side unless defined $rightmostf;
                $leftmostf  = $left_side  if $left_side  < $leftmostf;
                $rightmostf = $right_side if $right_side > $rightmostf;
            }

            #
            # We have to wait until all the features for the lane are 
            # drawn before placing the labels.  Labels moving north
            # must be reverse sorted by start position;  moving south,
            # they should be in ascending order.
            #
            my @labels;
            push @labels, 
                map  { $_->[0]->{'direction'} = NORTH; $_->[0] }
                sort { 
                    $b->[1] <=> $a->[1] || 
                    $a->[2] <=> $b->[2] ||
                    $b->[3] <=> $a->[3] ||
                    $b->[4] <=> $a->[4]
                }
                map  { [ 
                    $_, 
                    $_->{'start_position'},
                    $_->{'priority'}, 
                    $_->{'is_highlighted'} || 0, 
                    $_->{'has_corr'}       || 0,
                ] }
                @north_labels;

            push @labels, 
                map  { $_->[0]->{'direction'} = SOUTH; $_->[0] }
                sort { 
                    $a->[1] <=> $b->[1] || 
                    $b->[2] <=> $a->[2] ||
                    $b->[3] <=> $a->[3] ||
                    $b->[4] <=> $a->[4]
                }
                map  { [ 
                    $_, 
                    $_->{'start_position'},
                    $_->{'priority'}, 
                    $_->{'is_highlighted'} || 0, 
                    $_->{'has_corr'}       || 0,
                ] }
                @south_labels;

            my @accepted_labels;   # the labels we keep
            my @rows      =    (); # for labels north-to-south
            my $buffer    = 2;
            for my $label ( @labels ) {
                my $label_y      = label_distribution(
                    rows         => \@rows,
                    target       => $label->{'target'},
                    row_height   => $label->{'font'}->height,
                    max_distance => $label->{'has_corr'}       ? 15 : 10, 
                    can_skip     => $label->{'is_highlighted'} ?  0 :  1,
                    direction    => $label->{'direction'},
                    buffer       => $buffer,
                );
                $bottom_y = $label_y if $label_y > $bottom_y;

                if ( defined $label_y ) {
                    $label->{'y'} = $label_y;
                    push @accepted_labels, $label;
                }
            }

            my $label_offset = 15;
            $base_x          = $label_side eq RIGHT 
                ? $rightmostf > $base_x ? $rightmostf : $base_x
                : $leftmostf  < $base_x ? $leftmostf  : $base_x;

            for my $label ( @accepted_labels ) {
                my $font      = $label->{'font'};
                my $text      = $label->{'text'};
                my $label_y   = $label->{'y'};
                my $label_x   = $label_side eq RIGHT 
                    ? $base_x + $label_offset
                    : $base_x - $label_offset - ($font->width * length($text));
                my $label_end = $label_x + $font->width * length( $text );
                my $color     = $label->{'has_corr'}
                    ? $self->config('feature_correspondence_color') ||
                        $label->{'color'}
                    : $label->{'color'};
                $drawer->add_drawing( 
                    STRING, $font, $label_x, $label_y, $text, $color
                );

                my @label_bounds = (
                    $label_x - $buffer, 
                    $label_y,
                    $label_end + $buffer, 
                    $label_y + $font->height,
                );

                $leftmostf  = $label_bounds[0] if $label_bounds[0]<$leftmostf;
                $rightmostf = $label_bounds[2] if $label_bounds[2]>$rightmostf;

                #
                # If the feature got a label, then update the right 
                # or left connection points for linking up to 
                # corresponding features.
                #
                if ( $label_side eq RIGHT ) {
                    $features_with_corr{ $label->{'feature_id'} }{'right'} = 
                        [ $label_bounds[2], 
                          ($label_bounds[1]+$label_bounds[3])/2 ];
                }
                else {
                    $features_with_corr{ $label->{'feature_id'} }{'left'} = 
                        [ $label_bounds[0], 
                          ($label_bounds[1]+$label_bounds[3])/2 ];
                }

                #
                # Highlighting.
                #
                if ( $label->{'is_highlighted'} ) {
                    $drawer->add_drawing(
                        RECTANGLE, @label_bounds, 
                        $self->config('feature_highlight_fg_color')
                    );

                    $drawer->add_drawing(
                        FILLED_RECT, @label_bounds, 
                        $self->config('feature_highlight_bg_color'),
                        0
                    );
                }

                $drawer->add_map_area(
                    coords => \@label_bounds,
                    url    => $label->{'url'},
                    alt    => 'Details: '.$text,
                );

                $min_x    = $label_bounds[0] if $label_bounds[0] < $min_x;
                $top_y    = $label_bounds[1] if $label_bounds[1] < $top_y;
                $max_x    = $label_bounds[2] if $label_bounds[2] > $max_x;
                $bottom_y = $label_bounds[3] if $label_bounds[3] > $bottom_y;
                $min_y    = $label_y         if $label_y         < $min_y;

                #
                # Now connect the label to the middle of the feature.
                #
                my @coords           = @{ $label->{'feature_coords'} || [] };
                my $label_connect_x1 = $label_side eq RIGHT
                    ? $coords[2]# + $buffer 
                    : $label_end + $buffer;
                my $label_connect_y1 = $label_side eq RIGHT
                    ? ($coords[1] + $coords[3])/2 
                    : $label_y + $font->height/2;
                my $label_connect_x2 = $label_side eq RIGHT
                    ? $label_x - $buffer 
                    : $coords[0];# - $buffer;
                my $label_connect_y2 = $label_side eq RIGHT
                    ? $label_y + $font->height/2 
                    : ($coords[1] + $coords[3])/2;

                #
                # If the feature is a horz. line, then back the connection off.
                #
                if ( $label->{'shape'} eq LINE ) {
                    if ( $label_side eq RIGHT ) {
                        $label_connect_x1 += $buffer;
                    }
                    else {
                        $label_connect_x2 -= $buffer;
                    }
                }

                $drawer->add_connection(
                    $label_connect_x1,
                    $label_connect_y1,
                    $label_connect_x2, 
                    $label_connect_y2,
                    $label->{'color'} || $self->config('connecting_line_color')
                );
            }

            #
            # Register all the features that have correspondences.
            #
            $drawer->register_feature_position( %$_ ) for 
                values %features_with_corr;

            $min_x = $leftmostf  if $leftmostf  < $min_x;
            $max_x = $rightmostf if $rightmostf > $max_x;
            $lanes{ $lane }{'furthest'} = $label_side eq RIGHT
                ? $rightmostf : $leftmostf;
        }

        #
        # Make map clickable.
        #
        my $slots = $drawer->slots;
        my @maps;
        for my $side ( qw[ left right ] ) {
            my $no      = $side eq 'left' ? $slot_no - 1 : $slot_no + 1;
            my $new_no  = $side eq 'left' ? -1 : 1;
            my $map     = $slots->{ $no } or next; 
            my $link    = 
                join( '%3d', $new_no, map { $map->{$_} } qw[ field aid ] );

            my @ref_positions = sort { $a <=> $b }
                $drawer->feature_correspondence_map_positions(
                    slot_no      => $slot_no,
                    map_id       => $map_id,
                    comp_slot_no => $no,
                )
            ;

            if ( @ref_positions ) {
                my $first = $ref_positions[0];
                my $last  = $ref_positions[-1];
                $link    .= "[$first,$last]";
            }

            push @maps, $link;
        }

        my $url = $self->config('map_details_url').
            '?ref_map_set_aid='.$self->map_set_aid( $map_id ).
            ';ref_map_aid='.$self->accession_id( $map_id ).
            ';comparative_maps='.join( ':', @maps ).
            ';label_features='.$drawer->label_features.
            ';feature_types='.
            join(',', @{ $drawer->include_feature_types || [] }).
            ';highlight='.$drawer->highlight;

        if ( $is_relational && $slot_no != 0 ) {
            $drawer->add_map_area(
                coords => \@map_bounds,
                url    => $url,
                alt    => 'Details: '.$self->map_name,
            );
        }
        else {
            my $map_bottom_x = $map_bounds[0];
            my $map_bottom_y = $map_bounds[3] + 5;
            $drawer->add_drawing(
                STRING, $reg_font, $map_bottom_x, $map_bottom_y, '?', 'grey'
            );
            my @area = (
                $map_bottom_x - 2,
                $map_bottom_y - 2,
                $map_bottom_x + $reg_font->width + 2,
                $map_bottom_y + $reg_font->height + 2,
            );
            $drawer->add_drawing( RECTANGLE, @area, 'grey' );
            $drawer->add_map_area(
                coords => \@area,
                url    => $url,
                alt    => 'Details: '.$self->map_name,
            );
            $bottom_y = $area[3] if $area[3] > $bottom_y;
        }

        #
        # The map title(s).
        #
        if ( $is_relational && $slot_no != 0 ) {
            unless ( @map_titles ) {
                push @map_titles,
                    map  { $self->$_( $map_id ) } 
                    grep { !/map_name/ }
                    reverse @config_map_titles
                ;
            }
            $map_set_aid = $self->map_set_aid( $map_id );
        }
        else {
            my $buffer = 4;
            $min_y    -= $reg_font->height + $buffer * 2;
            my $mid_x  = $min_x + ( ( $max_x - $min_x ) / 2 );
            my ( $leftmost, $rightmost, $topmost, $bottommost );

            for my $label ( 
                map { $self->$_( $map_id ) } reverse @config_map_titles
            ) {
                my $label_x = $mid_x - 
                    ( ( $reg_font->width * length( $label ) ) / 2 );

                $drawer->add_drawing( 
                    STRING, $reg_font, $label_x, $min_y, $label, 'black'
                );

                my $label_end = $label_x + ($reg_font->width * length($label));
                my $bottom    = $min_y + $reg_font->height;
                $bottommost   = $bottom     unless defined $bottommost;
                $topmost      = $min_y      unless defined $topmost;
                $leftmost     = $label_x    unless defined $leftmost;
                $rightmost    = $label_end  unless defined $rightmost;
                $bottommost   = $bottom     if $bottom     > $bottommost;
                $topmost      = $min_y      if $min_y      < $topmost;
                $leftmost     = $label_x    if $label_x    < $leftmost;
                $rightmost    = $label_end  if $label_end  > $rightmost;
                $min_y       -= $reg_font->height;
            }

            my @bounds = (
                $leftmost   - $buffer, 
                $topmost    - $buffer,
                $rightmost  + $buffer, 
                $bottommost + $buffer,
            );

            $drawer->add_drawing( 
                FILLED_RECT, @bounds, 'white', 0 # bottom-most layer
            );

            $drawer->add_drawing( 
                RECTANGLE, @bounds, 'black'
            );

            my $url = $self->config('map_set_info_url').
                      '?map_set_aid='.
                      $self->map_set_aid( $map_id );
            $drawer->add_map_area(
                coords => \@bounds,
                url    => $url,
                alt    => 'Map Set Info',
            );

            $min_x = $bounds[0] if $bounds[0] < $min_x;
            $top_y = $bounds[1] if $bounds[1] < $top_y;
            $max_x = $bounds[2] if $bounds[2] > $max_x;
        }

        #
        # Draw feature correspondences to reference map.
        # This could be moved into the Drawer and be done at the end (?).
        #
        for my $position_set ( 
            $drawer->feature_correspondence_positions( slot_no => $slot_no ) 
        ) {
            my @positions     = @{ $position_set->{'positions'} || [] } or next;
            my $evidence_info = $drawer->feature_correspondence_evidence(
                $position_set->{'feature_id1'},
                $position_set->{'feature_id2'}
            );
            $drawer->add_connection(
                @positions,
                $evidence_info->{'line_color'} || 
                    $self->config('connecting_line_color'),
            );
        }

        $slot_min_x = $min_x unless defined $slot_min_x;
        $slot_min_x = $min_x if $min_x < $slot_min_x;
        $slot_max_x = $max_x unless defined $slot_max_x;
        $slot_max_x = $max_x if $max_x > $slot_max_x;
    }

    #
    # Draw the map titles last for relational maps, 
    # centered over all the maps.
    #
    if ( $is_relational && $slot_no != 0 ) {
        my $base_x  = $label_side eq RIGHT
                      ? $self->base_x + $half_title_length + 10
                      : $self->base_x - $half_title_length - 20;
        $slot_min_x = $base_x unless defined $slot_min_x;
        $slot_max_x = $base_x unless defined $slot_max_x;

        my $buffer = 4;
        my $min_y = $top_y - 10 - ( $reg_font->height + $buffer * 2 );
        my $mid_x = ( $slot_min_x + $slot_max_x ) / 2; 

        unless ( @map_titles ) {
            push @map_titles,
                map  { $self->$_( $map_ids[0] ) } 
                grep { !/map_name/ }
                reverse @config_map_titles
            ;
        }
        
        my ( $leftmost, $rightmost, $topmost, $bottommost );
        for my $label ( @map_titles ) {
            my $label_x = $mid_x - 
                ( ( $reg_font->width * length( $label ) ) / 2 );

            $drawer->add_drawing( 
                STRING, $reg_font, $label_x, $min_y, $label, 'black'
            );

            my $label_end = $label_x + ($reg_font->width * length($label));
            my $bottom    = $min_y + $reg_font->height;
            $bottommost   = $bottom     unless defined $bottommost;
            $topmost      = $min_y      unless defined $topmost;
            $leftmost     = $label_x    unless defined $leftmost;
            $rightmost    = $label_end  unless defined $rightmost;
            $bottommost   = $bottom     if $bottom     > $bottommost;
            $topmost      = $min_y      if $min_y      < $topmost;
            $leftmost     = $label_x    if $label_x    < $leftmost;
            $rightmost    = $label_end  if $label_end  > $rightmost;
            $min_y       -= $reg_font->height;
        }

        my @bounds = (
            $leftmost   - $buffer, 
            $topmost    - $buffer,
            $rightmost  + $buffer, 
            $bottommost + $buffer,
        );

        $drawer->add_drawing( 
            FILLED_RECT, @bounds, 'white', 0 # bottom-most layer
        );

        $drawer->add_drawing( 
            RECTANGLE, @bounds, 'black'
        );

        $drawer->add_map_area(
            coords => \@bounds,
            url    => $self->config('map_set_info_url').
                      "?map_set_aid=$map_set_aid",
            alt    => 'Map Set Info',
        );

        $slot_min_x = $bounds[0] if $bounds[0] < $slot_min_x;
        $top_y      = $bounds[1] if $bounds[1] < $top_y;
        $slot_max_x = $bounds[2] if $bounds[2] > $slot_max_x;
    }

    #
    # Register the feature types we saw.
    #
    $drawer->register_feature_type( keys %feature_type_ids );

    #
    # Background color
    #
    my $buffer = 10;
    return (
        $slot_min_x - $buffer,
        $top_y      - $buffer,
        $slot_max_x + $buffer,
        $bottom_y   + $buffer,
    );
}

# ----------------------------------------------------
sub map_ids {

=pod

=head2 map_ids

Returns the all the map IDs.

=cut

    my $self = shift;
    
    unless ( $self->{'sorted_map_ids'} ) {
        my @maps = map { 
            [ $_, $self->{'maps'}{ $_ }{'no_correspondences'} ] 
        } keys %{ $self->{'maps'} };

        $self->{'sorted_map_ids'} = [
            map  { $_->[0] }
            sort { $b->[1] <=> $a->[1] } 
            @maps
        ];
    }

    return @{ $self->{'sorted_map_ids'} };
}

# ----------------------------------------------------
sub map {

=pod

=head2 map

Returns one map.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    return $self->{'maps'}{ $map_id };
}

# ----------------------------------------------------
sub maps {

=pod

=head2 maps

Gets/sets all the maps.

=cut

    my $self = shift;
    $self->{'maps'} = shift if @_;
    return $self->{'maps'};
}

# ----------------------------------------------------
sub map_length {

=pod

=head2 map_length

Returns the map's length (stop - start).

=cut

    my $self   = shift;
    my $map_id = shift or return;
    return $self->stop_position($map_id) - $self->start_position($map_id);
}

# ----------------------------------------------------
sub map_width {

=pod

=head2 map_width

Returns a string describing how to draw the map.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map( $map_id );
    return 
        $map->{'width'}         || 
        $map->{'default_width'} || 
        $self->config('map_width');
}

# ----------------------------------------------------
sub real_map_length {

=pod

=head2 real_map_length

Returns the entiry map's length.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    return $self->real_stop_position($map_id) - 
        $self->real_start_position($map_id);
}

# ----------------------------------------------------
sub real_start_position {

=pod

=head2 real_start_position

Returns a map's start position.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map( $map_id );
    return $map->{'start_position'};
}

# ----------------------------------------------------
sub real_stop_position {

=pod

=head2 real_stop_position

Returns a map's stop position.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map( $map_id );
    return $map->{'stop_position'};
}


# ----------------------------------------------------
sub slot_no {

=pod

=head2 slot_no

Returns the slot number.

=cut

    my $self = shift;
    return $self->{'slot_no'};
}

# ----------------------------------------------------
sub start_position {

=pod

=head2 start_position

Returns a map's start position for the range selected.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map( $map_id );
    return $map->{'start'};
}

# ----------------------------------------------------
sub stop_position {

=pod

=head2 stop_position

Returns a map's stop position for the range selected.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map( $map_id );
    return $map->{'stop'};
}

# ----------------------------------------------------
sub tick_mark_interval {

=pod

=head2 tick_mark_interval

Returns the map's tick mark interval.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map( $map_id );

    unless ( defined $map->{'tick_mark_interval'} ) {
        my $map_length = 
            $self->stop_position( $map_id ) - $self->start_position( $map_id );
        $map->{'tick_mark_interval'} = int ( $map_length / 5 );
    }

    return $map->{'tick_mark_interval'};
}

1;

# ----------------------------------------------------
# The hours of folly are measur'd by the clock,
# but of wisdom: no clock can measure.
# William Blake
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
