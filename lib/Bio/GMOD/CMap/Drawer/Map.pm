package Bio::GMOD::CMap::Drawer::Map;

# $Id: Map.pm,v 1.47 2003-05-23 02:16:38 kycl4rk Exp $

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
$VERSION = (qw$Revision: 1.47 $)[-1];

use URI::Escape;
use Data::Dumper;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Utils qw[ column_distribution label_distribution ];

use base 'Bio::GMOD::CMap';

my @INIT_FIELDS = qw[ drawer base_x base_y slot_no maps ];

my %SHAPE = (
    'default'  => 'draw_box',
    'box'      => 'draw_box',
    'dumbbell' => 'draw_dumbbell',
    'I-beam'   => 'draw_i_beam',
);

BEGIN {
    #
    # Create automatic accessor methods.
    #
    my @AUTO_FIELDS = qw[
        map_set_id map_set_aid map_type accession_id species_id 
        map_id species_name map_units map_name map_set_name 
        map_type_id is_relational_map begin end 
    ];

    foreach my $sub_name ( @AUTO_FIELDS ) {
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
    $self->params( $config, @INIT_FIELDS );
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
    my $buffer      = 15;

    my $base_x;
    if ( 
        ( $slot_no == -1 && $drawer->total_no_slots == 2 )
        ||
        ( $slot_no < 0 )
    ) {
        $base_x = $drawer->min_x - $buffer;
    }
    else {
        $base_x = $drawer->max_x + $buffer;
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
    my $drawing_data     = $args{'drawing_data'};
    my $drawer           = $args{'drawer'} || $self->drawer or 
                           $self->error('No drawer');
    my ( $x1, $y1, $y2 ) = @{ $args{'coords'} || [] } or 
                           $self->error('No coordinates');
    my $color            = $self->color( $args{'map_id'} );
    my $width            = $self->map_width( $args{'map_id'} );
    my $x2               = $x1 + $width;
    my @coords           = ( $x1, $y1, $x2, $y2 ); 

#    $drawer->add_drawing( FILLED_RECT, @coords, $color  );
#    $drawer->add_drawing( RECTANGLE,   @coords, 'black' );

    push @$drawing_data, [ FILLED_RECT, @coords, $color  ];
    push @$drawing_data, [ RECTANGLE,   @coords, 'black' ];
    
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
    my $drawing_data     = $args{'drawing_data'};
    my $drawer           = $args{'drawer'} || $self->drawer or 
                           $self->error('No drawer');
    my ( $x1, $y1, $y2 ) = @{ $args{'coords'} || [] } or 
                           $self->error('No coordinates');
    my $color            = $self->color( $args{'map_id'} );
    my $width            = $self->map_width( $args{'map_id'} );
    my $x2               = $x1 + $width;
    my $mid_x            = $x1 + $width/2;
    my $arc_width        = $width + 6;

#    $drawer->add_drawing(
#        ARC, $mid_x, $y1, $arc_width, $arc_width, 0, 360, $color
#    );
#    $drawer->add_drawing(
#        ARC, $mid_x, $y2, $arc_width, $arc_width, 0, 360, $color
#    );
#    $drawer->add_drawing( FILL_TO_BORDER, $mid_x, $y1, $color, $color );
#    $drawer->add_drawing( FILL_TO_BORDER, $mid_x, $y2, $color, $color );
#    $drawer->add_drawing( FILLED_RECT, $x1, $y1, $x2, $y2, $color );

    push @$drawing_data, [ 
        ARC, $mid_x, $y1, $arc_width, $arc_width, 0, 360, $color
    ];
    push @$drawing_data, [ 
        ARC, $mid_x, $y2, $arc_width, $arc_width, 0, 360, $color
    ];
    push @$drawing_data, [ FILL_TO_BORDER, $mid_x, $y1, $color, $color ];
    push @$drawing_data, [ FILL_TO_BORDER, $mid_x, $y2, $color, $color ];
    push @$drawing_data, [ FILLED_RECT, $x1, $y1, $x2, $y2, $color ];
    
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
    my $drawing_data     = $args{'drawing_data'};
    my $drawer           = $args{'drawer'} || $self->drawer or 
                           $self->error('No drawer');
    my ( $x1, $y1, $y2 ) = @{ $args{'coords'} || [] } or 
                           $self->error('No coordinates');
    my $color            = $self->color( $args{'map_id'} );
    my $width            = $self->map_width( $args{'map_id'} );
    my $x2               = $x1 + $width;
    my $x                = $x1 + $width/2;

#    $drawer->add_drawing( LINE, $x , $y1, $x , $y2, $color );
#    $drawer->add_drawing( LINE, $x1, $y1, $x2, $y1, $color );
#    $drawer->add_drawing( LINE, $x1, $y2, $x2, $y2, $color );

    push @$drawing_data, [ LINE, $x , $y1, $x , $y2, $color ];
    push @$drawing_data, [ LINE, $x1, $y1, $x2, $y1, $color ];
    push @$drawing_data, [ LINE, $x1, $y2, $x2, $y2, $color ];

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
                defined $_->{'start_position'} ? $_->{'start_position'} : 0,
                defined $_->{'stop_position'} ? $_->{'stop_position'} : 0,
            ] }
            values %{ $map->{'features'} } 
        ) {
            push @{ $map->{'feature_store'}{ $data->{'drawing_lane'} } }, 
                $data
            ;
        }
    }

    return $map->{'feature_store'};
}

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
       $shape  = 'default' unless defined $SHAPE{ $shape };
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
            $length ||= 0;
            $longest  = $length if $length > $longest;
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

    #
    # Some common things we'll need later on.
    #
    my $collapse_features      = $drawer->collapse_features;
    my $max_image_pixel_width  = $drawer->config('max_image_pixel_width');
    my $min_map_pixel_height   = $drawer->config('min_map_pixel_height');
    my $default_feature_color  = $drawer->config('feature_color');
    my $feature_details_url    = DEFAULT->{'feature_details_url'};
    my $connecting_line_color  = $drawer->config('connecting_line_color');
    my $map_details_url        = $drawer->config('map_details_url');
    my $map_set_info_url       = $drawer->config('map_set_info_url');
    my $rel_map_show_corr_only =
        $drawer->config('relational_maps_show_only_correspondences') || 0;
    my $feature_corr_color    =
        $drawer->config('feature_correspondence_color') || '';
    my $feature_highlight_fg_color = 
        $drawer->config('feature_highlight_fg_color');
    my $feature_highlight_bg_color = 
        $drawer->config('feature_highlight_bg_color');

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
        my $column_width   = $map_width + 10;
        my $features       = $self->features( $map_id );

        #
        # The map.
        #
        my ( $min_x, $max_x, $area );
        my $draw_sub_name = $SHAPE{ $self->shape( $map_id ) };
        my $map_name      = $self->map_name( $map_id );
        my ( @drawing_data, @map_area_data );

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
                    $drawer->has_correspondence( $_->{'feature_id'} ) 
                    ? $_->{'feature_id'} : ()
                } @{ $features->{ $lane } };
            }
            next unless @corr_feature_ids;

            my @positions   =  sort{ $a <=> $b } $drawer->tick_y_positions(
                slot_no     => $drawer->reference_slot_no( $slot_no ),
                feature_ids => \@corr_feature_ids,
            );

            $pixel_height    = $positions[-1] - $positions[0];
            $pixel_height    = $min_map_pixel_height
                if $pixel_height < $min_map_pixel_height;
            my $midpoint     = ( $positions[0] + $positions[-1] ) / 2;
            $base_y          = $midpoint - $pixel_height/2;
            my $half_label   = (($reg_font->width*length($map_name))/2);
            $base_x = $label_side eq RIGHT 
                ? $original_base_x + $half_label
                : $original_base_x - $half_label;

            my $top          = $base_y - $reg_font->height - 4;
            my $bottom       = $base_y + $pixel_height + 4;
            my $leftmost     = $base_x - $half_label;
            my $rightmost    = $base_x + $half_label;

            push @drawing_data, [
                STRING, $reg_font, $leftmost, $top, $map_name, 'black'
            ];

            $min_x = $leftmost  unless defined $min_x;
            $max_x = $rightmost unless defined $max_x;
            $min_x = $leftmost  if $leftmost  < $min_x;
            $max_x = $rightmost if $rightmost > $max_x;
            $area  = [ $leftmost, $top, $rightmost, $bottom ];
        }

        $top_y = $base_y unless defined $top_y;
        $top_y = $base_y if $base_y < $top_y;

        my @map_bounds   =  $self->$draw_sub_name(
            map_id       => $map_id,
            map_units    => $show_map_units ? $self->map_units( $map_id ) : '',
            drawer       => $drawer,
            coords       => [ $base_x, $base_y, $base_y + $pixel_height ],
            drawing_data => \@drawing_data,
        );

        if ( @{ $area || [] } ) {
            $map_bounds[0] = $area->[0] if $area->[0] < $map_bounds[0];
            $map_bounds[1] = $area->[1] if $area->[1] < $map_bounds[1];
            $map_bounds[2] = $area->[2] if $area->[2] > $map_bounds[2];
            $map_bounds[3] = $area->[3] if $area->[3] > $map_bounds[3];
        }

        if ( $drawer->highlight_feature( $map_name ) ) {
            push @drawing_data, [
                RECTANGLE, @map_bounds, $feature_highlight_fg_color
            ];

            push @drawing_data, [
                FILLED_RECT, @map_bounds, $feature_highlight_bg_color, 0
            ];
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
        my $map_start  = $self->start_position( $map_id );
        my $map_stop   = $self->stop_position ( $map_id );
        my $map_length = $self->map_length    ( $map_id );
        if ( $show_ticks ) {
            my $interval      = $self->tick_mark_interval( $map_id ) || 1;
            my $no_intervals  = int( $map_length / $interval );
            my $tick_overhang = 5;
            my @intervals     = map { 
                int ( $map_start + ( $_ * $interval ) ) 
            } 1 .. $no_intervals;

            for my $tick_pos ( @intervals ) {
                my $rel_position = ( $tick_pos - $map_start ) / $map_length;
                my $y_pos        = $base_y + ( $pixel_height * $rel_position );
                my $tick_start   = $label_side eq RIGHT
                    ? $base_x - $tick_overhang
                    : $base_x
                ;

                my $tick_stop     = $label_side eq RIGHT
                    ? $base_x + $map_width
                    : $base_x + $map_width + $tick_overhang
                ;

                push @drawing_data, [
                    LINE, $tick_start, $y_pos, $tick_stop, $y_pos, 'grey'
                ];

                my $label_x = $label_side eq RIGHT 
                    ? $tick_start - $reg_font->height - 2
                    : $tick_stop  + 2
                ;

                my $label_y = $y_pos + ($reg_font->width*length($tick_pos))/2;

                push @drawing_data, [
                    STRING_UP, $reg_font, $label_x, $label_y, $tick_pos, 'grey'
                ];

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
        my %features_with_corr;       # features w/correspondences
        my ($leftmostf, $rightmostf); # furthest features

        for my $lane ( sort { $a <=> $b } keys %$features ) {
            my (@north_labels,@south_labels); # holds label coordinates
            my $lane_features = $features->{ $lane };
            my $midpoint      = (
                $lane_features->[ 0]->{'start_position'} +
                $lane_features->[-1]->{'start_position'}
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
                    : $base_x
                ;
            }

            for my $feature ( @$lane_features ) {
                #
                # If the map isn't showing labeled features (e.g., it's a
                # relational map and hasn't been expanded), then leave off 
                # drawing features that don't have correspondences.
                #
                my $has_corr = 
                    $drawer->has_correspondence( $feature->{'feature_id'} );

                next if 
                    $is_relational &&          # a relational map
                    $rel_map_show_corr_only && # showing only corr. only
                    $slot_no != 0  &&          # isn't the reference map
                    !$has_corr     &&          # feature has no correspondences
                    !$show_labels;             # not showing labels

                my $fstart = $feature->{'start_position'} || 0;
                my $fstop  = $feature->{'stop_position'};
                my $rstart = sprintf( "%.2f", 
                    ( $fstart - $map_start ) / $map_length
                );
                $rstart    = $rstart > 1 ? 1 : $rstart < 0 ? 0 : $rstart;
                my $rstop  = defined $fstop 
                    ? sprintf( "%.2f", ( $fstop - $map_start ) / $map_length )
                    : undef;
                $rstop     = defined $rstop && $rstop > 1 
                    ? 1 
                    : defined $rstop && $rstop < 0 ? 0 : $rstop;

                my $tick_overhang     = 2;
                my $y_pos1            = $base_y + ( $pixel_height * $rstart );
                my $y_pos2            = defined $rstop
                                        ? $base_y + ( $pixel_height * $rstop  )
                                        : undef;
                   $y_pos2            = $y_pos1 unless 
                                        defined $y_pos2 && $y_pos2 > $y_pos1;
                my $color             = $has_corr ? $feature_corr_color : '';
                   $color           ||= $feature->{'color'} || 
                                        $default_feature_color;
                my $label             = $feature->{'feature_name'};
                my $tick_start        = $base_x - $tick_overhang;
                my $tick_stop         = $base_x + $map_width + $tick_overhang;
                my $feature_shape     = $feature->{'shape'} || LINE;
                my $shape_is_triangle = $feature_shape =~ /triangle$/;

                my ( $label_y, @coords );
                if ( 
                    $shape_is_triangle     ||
                    $feature_shape eq LINE || 
                    $y_pos2 <= $y_pos1
                ) {
                    $label_y               = $y_pos1 - $reg_font->height/2;
                    $feature->{'midpoint'} = $fstart;
                    $feature->{'mid_y'}    = $y_pos1;
                }
                else {
                    $label_y = ( $y_pos1 + ( $y_pos2 - $y_pos1 ) / 2 ) -
                        $reg_font->height/2;

                    $feature->{'midpoint'} = ( $fstop > $fstart )
                        ? ( $fstart + $fstop ) / 2 : $fstart;

                    $feature->{'mid_y'} = ( $y_pos1 + $y_pos2 ) / 2;
                }

                if ( $feature_shape eq LINE ) {
                    push @drawing_data, [
                        LINE, $tick_start, $y_pos1, $tick_stop, $y_pos1, $color
                    ];
                    @coords = ( $tick_start, $y_pos1, $tick_stop, $y_pos1 );
                }
                else {
                    my $buffer       = 2;
                    my $column_index = column_distribution(
                        columns      => \@fcolumns,
                        top          => $y_pos1,
                        bottom       => $y_pos2,
                        buffer       => $buffer,
                        collapse     => $collapse_features,
                        collapse_on  => $feature->{'feature_type'},
                    );
                    my $offset       = ( $column_index + 1 ) * 6;
                    my $vert_line_x1 = $label_side eq RIGHT
                        ? $tick_start : $tick_stop;
                    my $vert_line_x2 = $label_side eq RIGHT 
                        ? $tick_stop + $offset 
                        : $tick_start - $offset;

                    if ( $y_pos1 < $y_pos2 && !$shape_is_triangle ) {
                        push @drawing_data, [
                            LINE, 
                            $vert_line_x2, $y_pos1, 
                            $vert_line_x2, $y_pos2, 
                            $color,
                        ];

                        @coords = (
                            $vert_line_x2, $y_pos1, $vert_line_x2, $y_pos2
                        );
                    }

                    if ( $feature_shape eq 'span' ) {
                        my $reverse = $label_side eq RIGHT ? -1 : 1;
                        push @drawing_data, [
                            LINE, 
                            $vert_line_x2, $y_pos1, 
                            $vert_line_x2 + ( 3 * $reverse ), $y_pos1, 
                            $color,
                        ];

                        push @drawing_data, [
                            LINE, 
                            $vert_line_x2, $y_pos2, 
                            $vert_line_x2 + ( 3 * $reverse ), $y_pos2, 
                            $color,
                        ];

                        @coords = (
                            $vert_line_x2, $y_pos1, $vert_line_x2, $y_pos2
                        );
                    }
                    elsif ( $feature_shape eq 'up-arrow' ) {
                        push @drawing_data, [
                            LINE,
                            $vert_line_x2, $y_pos1,
                            $vert_line_x2 - 2, $y_pos1 + 2,
                            $color
                        ];

                        push @drawing_data, [
                            LINE,
                            $vert_line_x2, $y_pos1,
                            $vert_line_x2 + 2, $y_pos1 + 2,
                            $color
                        ];

                        @coords = (
                            $vert_line_x2 - 2, $y_pos2,
                            $vert_line_x2 + 2, $y_pos1,
                        );
                    }
                    elsif ( $feature_shape eq 'down-arrow' ) {
                        push @drawing_data, [
                            LINE,
                            $vert_line_x2, $y_pos2,
                            $vert_line_x2 - 2, $y_pos2 - 2,
                            $color
                        ];

                        push @drawing_data, [
                            LINE,
                            $vert_line_x2, $y_pos2,
                            $vert_line_x2 + 2, $y_pos2 - 2,
                            $color
                        ];

                        @coords = (
                            $vert_line_x2 - 2, $y_pos2,
                            $vert_line_x2 + 2, $y_pos1,
                        );
                    }
                    elsif ( $feature_shape eq 'double-arrow' ) {
                        push @drawing_data, [
                            LINE,
                            $vert_line_x2, $y_pos1,
                            $vert_line_x2 - 2, $y_pos1 + 2,
                            $color
                        ];
                        push @drawing_data, [
                            LINE,
                            $vert_line_x2, $y_pos1,
                            $vert_line_x2 + 2, $y_pos1 + 2,
                            $color
                        ];
                        push @drawing_data, [
                            LINE,
                            $vert_line_x2, $y_pos2,
                            $vert_line_x2 - 2, $y_pos2 - 2,
                            $color
                        ];
                        push @drawing_data, [
                            LINE,
                            $vert_line_x2, $y_pos2,
                            $vert_line_x2 + 2, $y_pos2 - 2,
                            $color
                        ];

                        @coords = (
                            $vert_line_x2 - 2, $y_pos2,
                            $vert_line_x2 + 2, $y_pos1,
                        );
                    }
                    elsif ( $feature_shape eq 'box' ) {
                        $vert_line_x1 = $label_side eq RIGHT
                            ? $tick_start - $offset : $tick_stop + $offset;
                        $vert_line_x2 = $label_side eq RIGHT 
                            ? $tick_stop + $offset : $tick_start - $offset;

                        @coords = (
                            $vert_line_x2, $y_pos2,
                            $vert_line_x1, $y_pos1, 
                        );

                        push @drawing_data, [ RECTANGLE, @coords, $color ];
                    }
                    elsif ( $feature_shape eq 'dumbbell' ) {
                        my $width = 3;
                        push @drawing_data, [
                            ARC, 
                            $vert_line_x2, $y_pos1,
                            $width, $width, 0, 360, $color
                        ];
                        push @drawing_data, [
                            ARC, 
                            $vert_line_x2, $y_pos2,
                            $width, $width, 0, 360, $color
                        ];

                        @coords = (
                            $vert_line_x2 - $width/2, $y_pos1, 
                            $vert_line_x2 + $width/2, $y_pos2
                        );
                    }
                    elsif ( $feature_shape eq 'filled-box' ) {
                        my $width = 3;
                        push @drawing_data, [
                            FILLED_RECT, 
                            $vert_line_x2, $y_pos1,
                            $vert_line_x2 + $width, $y_pos2,
                            $color,
                        ];
                        push @drawing_data, [
                            RECTANGLE, 
                            $vert_line_x2, $y_pos1,
                            $vert_line_x2 + $width, $y_pos2,
                            'black',
                        ];
                        @coords = (
                            $vert_line_x2 - $width/2, $y_pos1, 
                            $vert_line_x2 + $width/2, $y_pos2
                        );
                    }
                    elsif ( 
                        ( 
                            $feature_shape eq 'in-triangle' &&
                            $label_side eq LEFT
                        )
                        ||
                        ( 
                            $feature_shape eq 'out-triangle' &&
                            $label_side eq RIGHT
                        )
                    ) {
                        my $width = 3;
                        push @drawing_data, [
                            LINE,
                            $vert_line_x2, $y_pos1 - $width,
                            $vert_line_x2, $y_pos1 + $width,
                            $color
                        ];
                        push @drawing_data, [
                            LINE,
                            $vert_line_x2, $y_pos1 - $width,
                            $vert_line_x2 + $width, $y_pos1,
                            $color
                        ];
                        push @drawing_data, [
                            LINE,
                            $vert_line_x2, $y_pos1 + $width,
                            $vert_line_x2 + $width, $y_pos1,
                            $color
                        ];
                        push @drawing_data, [
                            FILL,
                            $vert_line_x2 + 1, $y_pos1 + 1,
                            $color
                        ];

                        @coords = (
                            $vert_line_x2 - $width, $y_pos1 - $width,
                            $vert_line_x2 + $width, $y_pos1 + $width,
                        );
                    }
                    elsif (
                        ( 
                            $feature_shape eq 'in-triangle' &&
                            $label_side eq RIGHT
                        )
                        ||
                        ( 
                            $feature_shape eq 'out-triangle' &&
                            $label_side eq LEFT
                        )
                    ) {
                        my $width = 3;
                        push @drawing_data, [
                            LINE,
                            $vert_line_x2 + $width, $y_pos1 - $width,
                            $vert_line_x2 + $width, $y_pos1 + $width,
                            $color
                        ];
                        push @drawing_data, [
                            LINE,
                            $vert_line_x2 + $width, $y_pos1 - $width,
                            $vert_line_x2, $y_pos1,
                            $color
                        ];
                        push @drawing_data, [
                            LINE,
                            $vert_line_x2, $y_pos1,
                            $vert_line_x2 + $width, $y_pos1 + $width,
                            $color
                        ];
                        push @drawing_data, [
                            FILL,
                            $vert_line_x2 + $width - 1, $y_pos1 + 1,
                            $color
                        ];

                        @coords = (
                            $vert_line_x2 - $width, $y_pos1 - $width,
                            $vert_line_x2 + $width, $y_pos1 + $width,
                        );
                    }
                    
                    push @map_area_data, {
                       coords => \@coords,
                        url    => 
                            $feature_details_url.$feature->{'accession_id'},
                        alt    => 'Details: '.$feature->{'feature_name'},
                    };
                }

                #
                # Register that we saw this type of feature.
                #
                $feature_type_ids{ $feature->{'feature_type_id'} } = 1;

                my $is_highlighted = $drawer->highlight_feature( 
                    $feature->{'feature_name'},
                    $feature->{'alternate_name'},
                    $feature->{'accession_id'},
                );

                if ( $has_corr ) {
                    my $mid_feature = $coords[1] + (($coords[3]-$coords[1])/2);
                    $features_with_corr{ $feature->{'feature_id'} } = {
                        feature_id => $feature->{'feature_id'},
                        slot_no    => $slot_no,
                        map_id     => $map_id,
                        left       => [ $coords[0], $mid_feature ],
                        right      => [ $coords[2], $mid_feature ],
                        tick_y     => $mid_feature,
                    };
                }

                my ( $left_side, $right_side );
                if ( 
                    $show_labels                 && (
                        $has_corr                || 
                        $label_features eq 'all' ||
                        $is_highlighted          || (
                            $label_features eq 'landmarks' && 
                            $feature->{'is_landmark'} 
                        )
                    )
                ) {
                    my $labels = $feature->{'midpoint'} < $midpoint
                        ? \@north_labels : \@south_labels;

                    push @$labels, {
                        priority       => $feature->{'drawing_priority'},
                        text           => $label,
                        target         => $label_y,
                        color          => $color,
                        is_highlighted => $is_highlighted,
                        feature_coords => \@coords,
                        feature_mid_y  => $feature->{'mid_y'},
                        feature_type   => $feature->{'feature_type'},
                        url            => 
                            $feature_details_url.$feature->{'accession_id'},
                        has_corr       => $has_corr,
                        feature_id     => $feature->{'feature_id'},
                        start_position => $feature->{'start_position'},
                        shape          => $feature->{'shape'},
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
            my @accepted_labels; # the labels we keep
            my $buffer    =  2;  # the space between things
            if ( @north_labels || @south_labels ) {
                @north_labels =
                    map  { $_->[0] }
                    sort { 
                        $b->[1] <=> $a->[1] || 
                        $a->[2] <=> $b->[2] ||
                        $b->[3] <=> $a->[3] ||
                        $b->[4] <=> $a->[4]
                    }
                    map  { [ 
                        $_, 
                        $_->{'target'},
                        $_->{'priority'}, 
                        $_->{'is_highlighted'} || 0, 
                        $_->{'has_corr'}       || 0,
                    ] }
                    @north_labels;

                @south_labels =
                    map  { $_->[0] }
                    sort { 
                        $a->[1] <=> $b->[1] || 
                        $b->[2] <=> $a->[2] ||
                        $b->[3] <=> $a->[3] ||
                        $b->[4] <=> $a->[4]
                    }
                    map  { [ 
                        $_, 
                        $_->{'target'},
                        $_->{'priority'}, 
                        $_->{'is_highlighted'} || 0, 
                        $_->{'has_corr'}       || 0,
                    ] }
                    @south_labels
                ;

                my $used = label_distribution( 
                    labels     => \@north_labels, 
                    accepted   => \@accepted_labels,
                    used       => [],
                    buffer     => $buffer,
                    direction  => NORTH,
                    row_height => $reg_font->height,
                );

                label_distribution( 
                    labels     => \@south_labels, 
                    accepted   => \@accepted_labels,
                    used       => $used,
                    buffer     => $buffer,
                    direction  => SOUTH,
                    row_height => $reg_font->height,
                );
            }

            my $label_offset = 15;
            $base_x          = $label_side eq RIGHT 
                ? $rightmostf > $base_x ? $rightmostf : $base_x
                : $leftmostf  < $base_x ? $leftmostf  : $base_x;

            my $font_width  = $reg_font->width;
            my $font_height = $reg_font->height;
            for my $label ( @accepted_labels ) {
                my $text      = $label->{'text'};
                my $label_y   = $label->{'y'};
                my $label_x   = $label_side eq RIGHT 
                    ? $base_x + $label_offset
                    : $base_x - $label_offset - ($font_width * length($text));
                my $label_end = $label_x + $font_width * length( $text );
                my $color     = $label->{'has_corr'}
                    ? $feature_corr_color || $label->{'color'}
                    : $label->{'color'};

                push @drawing_data, [
                    STRING, $reg_font, $label_x, $label_y, $text, $color
                ];

                my @label_bounds = (
                    $label_x - $buffer, 
                    $label_y,
                    $label_end + $buffer, 
                    $label_y + $font_height,
                );

                $leftmostf  = $label_bounds[0] if $label_bounds[0]<$leftmostf;
                $rightmostf = $label_bounds[2] if $label_bounds[2]>$rightmostf;

                #
                # Highlighting.
                #
                if ( $label->{'is_highlighted'} ) {
                    push @drawing_data, [
                        RECTANGLE, @label_bounds, $feature_highlight_fg_color
                    ];

                    push @drawing_data, [
                        FILLED_RECT, @label_bounds, 
                        $feature_highlight_bg_color, 0
                    ];
                }

                push @map_area_data, {
                    coords => \@label_bounds,
                    url    => $label->{'url'},
                    alt    => 'Details: '.$text,
                };

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
                    ? $coords[2]
                    : $label_end + $buffer;

                my $label_connect_y1 = $label_side eq RIGHT
                    ? $label->{'feature_mid_y'}
                    : $label_y + $reg_font->height/2;

                my $label_connect_x2 = $label_side eq RIGHT
                    ? $label_x - $buffer 
                    : $coords[0];

                my $label_connect_y2 = $label_side eq RIGHT
                    ? $label_y + $reg_font->height/2 
                    : $label->{'feature_mid_y'};

                #
                # Back the connection off.
                #
                if ( $label_side eq RIGHT ) {
                    $label_connect_x1 += $buffer;
                }
                else {
                    $label_connect_x2 -= $buffer;
                }

                $drawer->add_connection(
                    $label_connect_x1,
                    $label_connect_y1,
                    $label_connect_x2, 
                    $label_connect_y2,
                    'grey'
                );

                #
                # If the feature got a label, then update the right 
                # or left connection points for linking up to 
                # corresponding features.
                #
                if ( defined $features_with_corr{ $label->{'feature_id'} } ) {
                    if ( $label_side eq RIGHT ) {
                        $features_with_corr{ $label->{'feature_id'} }{'right'} =
                            [ $label_bounds[2], 
                                ($label_bounds[1]+
                                ($label_bounds[3]-$label_bounds[1])/2) 
                            ];
                    }
                    else {
                        $features_with_corr{ $label->{'feature_id'} }{'left'} = 
                            [ $label_bounds[0], 
                                ($label_bounds[1]+
                                ($label_bounds[3]-$label_bounds[1])/2) 
                            ];
                    }
                }
            }

            $min_x = $leftmostf  if $leftmostf  < $min_x;
            $max_x = $rightmostf if $rightmostf > $max_x;

            $lanes{ $lane }{'furthest'} = $label_side eq RIGHT
                ? $rightmostf : $leftmostf;
        }

        #
        # Make sure that the lanes for the maps take into account
        # the span of all the features.
        #
        if ( $is_relational && $slot_no != 0 ) {
            my $last_feature_lane = ( sort { $a <=> $b } keys %lanes )[-1];
            my $furthest_feature  = $lanes{ $last_feature_lane }{'furthest'};
            my ( $leftmostf, $rightmostf );

            if ( $label_side eq RIGHT ) {
                $leftmostf  = $map_bounds[0];
                $rightmostf = $furthest_feature > $map_bounds[2]
                    ? $furthest_feature : $map_bounds[2];
            }
            else {
                $rightmostf = $map_bounds[2];
                $leftmostf  = $furthest_feature < $map_bounds[0]
                    ? $furthest_feature : $map_bounds[0];
            }

            my $map_lane =  column_distribution(
                columns  => \@columns,
                top      => $map_bounds[1],
                bottom   => $map_bounds[3],
                buffer   => 4,
                col_span => sprintf( "%.0f", 
                    ( abs( $leftmostf - $rightmostf ) / $column_width ) + .5
                ),
            );

            if ( $map_lane ) {
                my $shift       = $column_width * $map_lane;
                $shift         *= -1 if $label_side eq LEFT;
                $map_bounds[0] += $shift;
                $map_bounds[2] += $shift;
                $leftmostf     += $shift;
                $rightmostf    += $shift;
                $slot_min_x = $leftmostf  if $leftmostf  < $slot_min_x;
                $slot_max_x = $rightmostf if $rightmostf > $slot_max_x;

                for my $rec ( @drawing_data ) {
                    my $shape = $rec->[0];
                    for my $x_field ( @{ SHAPE_XY->{ $shape }{'x'} } ) {
                        $rec->[ $x_field ] += $shift;
                    }
                }

                for my $rec ( @map_area_data ) {
                    $rec->{'coords'}[ $_ ] += $shift for ( 1, 3 );
                }

                for my $rec ( values %features_with_corr ) {
                    $rec->{'right'}[0] += $shift;
                    $rec->{'left'}[0]  += $shift;
                }
            }
        }

        #
        # Register all the features that have correspondences.
        #
        $drawer->register_feature_position( %$_ ) for 
            values %features_with_corr;

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

        my $url = $map_details_url.
            '?ref_map_set_aid='.$self->map_set_aid( $map_id ).
            ';ref_map_aid='.$self->accession_id( $map_id ).
            ';comparative_maps='.join( ':', @maps ).
            ';label_features='.$drawer->label_features.
            ';feature_types='.
            join(',', @{ $drawer->include_feature_types || [] }).
            ';highlight='.uri_escape( $drawer->highlight );

        if ( $is_relational && $slot_no != 0 ) {
            push @map_area_data, {
                coords => \@map_bounds,
                url    => $url,
                alt    => 'Details: '.$self->map_name,
            };
        }
        else {
            my $map_bottom_x = $map_bounds[0];
            my $map_bottom_y = $map_bounds[3] + 5;

            push @drawing_data, [
                STRING, $reg_font, $map_bottom_x, $map_bottom_y, '?', 'grey'
            ];

            my @area = (
                $map_bottom_x - 2,
                $map_bottom_y - 2,
                $map_bottom_x + $reg_font->width + 2,
                $map_bottom_y + $reg_font->height + 2,
            );

            push @drawing_data, [ RECTANGLE, @area, 'grey' ];
            push @map_area_data, {
                coords => \@area,
                url    => $url,
                alt    => 'Details: '.( $self->map_name || '' ),
            };
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

                push @drawing_data, [
                    STRING, $reg_font, $label_x, $min_y, $label, 'black'
                ];

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

            push @drawing_data, [
                FILLED_RECT, @bounds, 'white', 0 # bottom-most layer
            ];

            push @drawing_data, [
                RECTANGLE, @bounds, 'black'
            ];

            my $url = "$map_set_info_url?map_set_aid=".
                      $self->map_set_aid( $map_id );
            push @map_area_data, {
                coords => \@bounds,
                url    => $url,
                alt    => 'Map Set Info',
            };

            $min_x = $bounds[0] if $bounds[0] < $min_x;
            $top_y = $bounds[1] if $bounds[1] < $top_y;
            $max_x = $bounds[2] if $bounds[2] > $max_x;
        }

        $slot_min_x = $min_x unless defined $slot_min_x;
        $slot_min_x = $min_x if $min_x < $slot_min_x;
        $slot_max_x = $max_x unless defined $slot_max_x;
        $slot_max_x = $max_x if $max_x > $slot_max_x;

        #
        # See if we've exceeded the max width yet.
        #
        if ( $max_image_pixel_width ) {
            return $self->error(
                "Maximum image pixel width ($max_image_pixel_width) ".
                "exceeded.  Please choose fewer maps."
            ) if ( abs $drawer->min_x + $slot_max_x ) > $max_image_pixel_width;
        }

        $drawer->add_drawing( @drawing_data );
        $drawer->add_map_area( @map_area_data );
    }

    # drawing guides
#    for my $i ( 0 .. $#columns ) {
#        my $map_width      = $self->map_width( $map_ids[0] );
#        my $column_width   = $map_width + 10;
#        my $x = $label_side eq RIGHT
#            ? $original_base_x + $column_width * $i
#            : $original_base_x - $column_width * $i;
##        $drawer->add_drawing(LINE, $x, -30, $x, 500, 'lightgrey', 0);
##        $drawer->add_drawing(STRING, $reg_font, $x, -30, $i, 'black', 0);
##        $drawer->add_drawing(STRING, $reg_font, $x, 500, $i, 'black', 0);
#
#        my $col = $columns[$i];
#        for my $segment ( @$col ) {
#            my ( $n, $s, $span ) = @$segment;
#            $drawer->add_drawing(RECTANGLE, $x, $n, 
#                $x + $column_width * $span, $s, 'green');
##            $drawer->add_drawing(LINE, $x - 2, $n, $x + 2, $n, 'red', 0);
##            $drawer->add_drawing(LINE, $x, $n, $x, $s, 'red', 0);
##            $drawer->add_drawing(LINE, $x - 2, $s, $x + 2, $s, 'red', 0);
#        }
#    }

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
            url    => "$map_set_info_url?map_set_aid=$map_set_aid",
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
    return [
        $slot_min_x - $buffer,
        $top_y      - $buffer,
        $slot_max_x + $buffer,
        $bottom_y   + $buffer,
    ];
}

# ----------------------------------------------------
sub map_ids {

=pod

=head2 map_ids

Returns the all the map IDs sorted by the number of correspondences
(to the reference map), highest to lowest.

=cut

    my $self = shift;
    
    unless ( $self->{'sorted_map_ids'} ) {
        my @maps = map { 
            [ $_, $self->{'maps'}{ $_ }{'no_correspondences'} ] 
        } keys %{ $self->{'maps'} || {} };

        if ( @maps ) {
            $self->{'sorted_map_ids'} = [
                map  { $_->[0] }
                sort { $b->[1] <=> $a->[1] } 
                @maps
            ];
        }
    }

    return @{ $self->{'sorted_map_ids'} || [] };
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

# ----------------------------------------------------
sub DESTROY {

=pod

=head2 DESTROY

Break cyclical links.

=cut

    my $self = shift;
    $self->{'drawer'} = undef;
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

=head1 COPYRIGHT

Copyright (c) 2002-3 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
