package Bio::GMOD::CMap::Drawer::Map;

# vim: set ft=perl:

# $Id: Map.pm,v 1.83 2004-05-16 19:38:10 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.83 $)[-1];

use URI::Escape;
use Data::Dumper;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Utils qw[ 
    even_label_distribution 
    ];

use base 'Bio::GMOD::CMap';

my @INIT_FIELDS = qw[ drawer base_x base_y slot_no maps config ];

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
      map_type_id begin end
    ];

    foreach my $sub_name (@AUTO_FIELDS) {
        no strict 'refs';
        unless ( defined &$sub_name ) {
            *{$sub_name} = sub {
                my $self   = shift;
                my $map_id = shift;
                return $self->{'maps'}{$map_id}{$sub_name};
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

    my $self    = shift;
    my $slot_no = $self->slot_no;
    my $drawer  = $self->drawer;
    my $buffer  = 15;

    my $base_x;
    if ( $slot_no < 0 || ( $slot_no == 0 && $drawer->label_side eq LEFT ) ) {
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
    my $map    = $self->map($map_id);
    return $map->{'color'}
      || $map->{'default_color'}
      || $self->config_data('map_color');
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

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $drawer = $args{'drawer'} || $self->drawer
      or $self->error('No drawer');
    my ( $x1, $y1, $y2 ) = @{ $args{'coords'} || [] }
      or $self->error('No coordinates');
    my $color  = $self->color( $args{'map_id'} );
    my $width  = $self->map_width( $args{'map_id'} );
    my $x2     = $x1 + $width;
    my @coords = ( $x1, $y1, $x2, $y2 );

    push @$drawing_data, [ FILLED_RECT, @coords, $color ];
    push @$drawing_data, [ RECTANGLE,   @coords, 'black' ];

    if ( my $map_units = $args{'map_units'} ) {
        my $buf  = 2;
        my $font = $drawer->regular_font;
        my $x    = $x1 + ( ( $x2 - $x1 ) / 2 ) -
          ( ( $font->width * length($map_units) ) / 2 );
        my $y = $y2 + $buf;
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

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $drawer = $args{'drawer'} || $self->drawer
      or $self->error('No drawer');
    my ( $x1, $y1, $y2 ) = @{ $args{'coords'} || [] }
      or $self->error('No coordinates');
    my $color     = $self->color( $args{'map_id'} );
    my $width     = $self->map_width( $args{'map_id'} );
    my $x2        = $x1 + $width;
    my $mid_x     = $x1 + $width / 2;
    my $arc_width = $width + 6;

    push @$drawing_data,
      [ ARC, $mid_x, $y1, $arc_width, $arc_width, 0, 360, $color ];
    push @$drawing_data,
      [ ARC, $mid_x, $y2, $arc_width, $arc_width, 0, 360, $color ];
    push @$drawing_data, [ FILL_TO_BORDER, $mid_x, $y1, $color, $color ];
    push @$drawing_data, [ FILL_TO_BORDER, $mid_x, $y2, $color, $color ];
    push @$drawing_data, [ FILLED_RECT,    $x1,    $y1, $x2,    $y2, $color ];

    if ( my $map_units = $args{'map_units'} ) {
        my $buf  = 2;
        my $font = $drawer->regular_font;
        my $x    = $x1 + ( ( $x2 - $x1 ) / 2 ) -
          ( ( $font->width * length($map_units) ) / 2 );
        my $y = $y2 + $buf;
        $drawer->add_drawing( STRING, $font, $x, $y, $map_units, 'grey' );
        $y2 += $font->height;
    }

    return (
        $mid_x - $arc_width / 2,
        $y1 - $arc_width / 2,
        $mid_x + $arc_width / 2,
        $y2 + $arc_width / 2,
    );
}

# ----------------------------------------------------
sub draw_i_beam {

=pod

=head2 draw_i_beam

Draws the map as an "I-beam."  Return the bounds of the image.

=cut

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $drawer = $args{'drawer'} || $self->drawer
      or $self->error('No drawer');
    my ( $x1, $y1, $y2 ) = @{ $args{'coords'} || [] }
      or $self->error('No coordinates');
    my $color = $self->color( $args{'map_id'} );
    my $width = $self->map_width( $args{'map_id'} );
    my $x2    = $x1 + $width;
    my $x     = $x1 + $width / 2;

    push @$drawing_data, [ LINE, $x,  $y1, $x,  $y2, $color ];
    push @$drawing_data, [ LINE, $x1, $y1, $x2, $y1, $color ];
    push @$drawing_data, [ LINE, $x1, $y2, $x2, $y2, $color ];

    if ( my $map_units = $args{'map_units'} ) {
        my $buf  = 2;
        my $font = $drawer->regular_font;
        my $x    = $x1 + ( ( $x2 - $x1 ) / 2 ) -
          ( ( $font->width * length($map_units) ) / 2 );
        my $y = $y2 + $buf;
        $drawer->add_drawing( STRING, $font, $x, $y, $map_units, 'grey' );
        $y2 += $font->height;
    }

    return ( $x1, $y1, $x2, $y2 );
}

# ----------------------------------------------------
sub draw_map_title {

=pod

=head2 draw_map_title

Draws the map title.

=cut

    my $self    = shift;
    my %args    = @_;
    my $min_y   = $args{'min_y'} || 0;
    my $left_x  = $args{'left_x'} || 0;
    my $right_x = $args{'right_x'} || 0;
    my $lines   = $args{'lines'} || [];
    my $buttons = $args{'buttons'} || [];
    my $font    = $args{'font'};
    my $buffer  = 4;
    my $mid_x   = $left_x + ( ( $right_x - $left_x ) / 2 );
    my $top_y   =
      $min_y - ( scalar @$lines + 1 ) * ( $font->height + $buffer ) - 4;
    my $leftmost  = $mid_x;
    my $rightmost = $mid_x;

    #
    # Place the titles.
    #
    my ( @drawing_data, @map_area_data );
    my $y = $top_y;
    for my $label (@$lines) {
        my $len     = $font->width * length($label);
        my $label_x = $mid_x - $len / 2;
        my $end     = $label_x + $len;

        push @drawing_data, [ STRING, $font, $label_x, $y, $label, 'black' ];

        $y += $font->height + $buffer;
        $leftmost  = $label_x if $label_x < $leftmost;
        $rightmost = $end     if $end > $rightmost;
    }

    #
    # Figure out how much room left-to-right the buttons will take.
    #
    my $buttons_width;
    for my $button (@$buttons) {
        $buttons_width += $font->width * length( $button->{'label'} );
    }
    $buttons_width += 6 * ( scalar @$buttons - 1 );

    #
    # Place the buttons.
    #
    my $label_x = $mid_x - $buttons_width / 2;
    my $sep_x   = $label_x;
    my $sep_y   = $y;
    $y += 6;

    for my $button (@$buttons) {
        my $len  = $font->width * length( $button->{'label'} );
        my $end  = $label_x + $len;
        my @area = ( $label_x - 2, $y - 2, $end + 2, $y + $font->height + 2 );
        push @drawing_data,
          [ STRING, $font, $label_x, $y, $button->{'label'}, 'grey' ],
          [ RECTANGLE, @area, 'grey' ],;

        $leftmost  = $label_x if $label_x < $leftmost;
        $rightmost = $end     if $end > $rightmost;
        $label_x += $len + 6;

        push @map_area_data,
          {
            coords => \@area,
            url    => $button->{'url'},
            alt    => $button->{'alt'},
          };
    }

    push @drawing_data, [ LINE, $sep_x, $sep_y, $label_x - 6, $sep_y, 'grey' ];

    #
    # Enclose the whole area in black-edged white box.
    #
    my @bounds = (
        $leftmost - $buffer,
        $top_y - $buffer,
        $rightmost + $buffer,
        $min_y + $buffer,
    );

    push @drawing_data, [
        FILLED_RECT, @bounds, 'white', 0    # bottom-most layer
    ];

    push @drawing_data, [ RECTANGLE, @bounds, 'black' ];

    return ( \@bounds, \@drawing_data, \@map_area_data );
}

# ----------------------------------------------------
sub features {

=pod

=head2 features

Returns all the features on the map.  Features are stored in raw format as 
a hashref keyed on feature_id.

=cut

    my $self       = shift;
    my $map_id     = shift or return;
    my $map        = $self->map($map_id);

    unless ( defined $map->{'feature_store'} ) {
        for my $data (
            map  { $_->[0] }
            sort {
                     $a->[1] <=> $b->[1]
                  || $a->[2] <=> $b->[2]
                  || $a->[3] <=> $b->[3]
                  || $a->[4] <=> $b->[4]
            }
            map {
                [
                    $_,
                    $_->{'drawing_lane'},
                    $_->{'drawing_priority'},
                    defined $_->{'start_position'} ? $_->{'start_position'} : 0,
                    defined $_->{'stop_position'}  ? $_->{'stop_position'}  : 0,
                ]
            } values %{ $map->{'features'} }
          )
        {

            push @{ $map->{'feature_store'}{ $data->{'drawing_lane'} } }, $data;
        }
    }

    return $map->{'feature_store'};
}

# ----------------------------------------------------
sub no_features {

=pod

=head2 no_features

Returns the number features on the map.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    return $map->{'no_features'};
}

# ----------------------------------------------------
sub shape {

=pod

=head2 shape

Returns a string describing how to draw the map.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    my $shape  = $map->{'shape'} || $map->{'default_shape'} || '';
    $shape = 'default' unless defined $SHAPE{$shape};
    return $shape;
}

# ----------------------------------------------------
sub layout {

=pod

=head2 layout

Lays out the map.

=cut

    my $self         = shift;
    my $base_y       = $self->base_y;
    my $slot_no      = $self->slot_no;
    my $drawer       = $self->drawer;
    my $label_side   = $drawer->label_side($slot_no);
    my $pixel_height = $drawer->pixel_height;
    my $reg_font     = $drawer->regular_font
      or return $self->error( $drawer->error );
    my $slots       = $drawer->slots;
    my @map_ids     = $self->map_ids;
    my $font_width  = $reg_font->width;
    my $font_height = $reg_font->height;
    my $no_of_maps  = scalar @map_ids;

    # if more than one map in slot, compress all
    my $is_compressed  = $no_of_maps > 1;
    my $label_features = $drawer->label_features;
    my $config         = $self->config or return;

    #
    # The title is often the widest thing we'll draw, so we need
    # to figure out which is the longest and take half its length
    # into account when deciding where to start with the map(s).
    #
    my @config_map_titles = $config->get_config('map_titles');
    my $longest;
    for my $map_id (@map_ids) {
        for my $length ( map { length $self->$_($map_id) } @config_map_titles )
        {
            $length ||= 0;
            $longest = $length if $length > $longest;
        }
    }
    my $half_title_length = ( $font_width * $longest ) / 2 + 10;
    my $original_base_x   =
        $label_side eq RIGHT
      ? $self->base_x + $half_title_length
      : $self->base_x - $half_title_length;

    #
    # These are for drawing the map titles last if this is a relational map.
    #
    my (
        $top_y,                # northernmost coord for the slot
        $bottom_y,             # southernmost coord for the slot
        $slot_min_x,           # easternmost coord for the slot
        $slot_max_x,           # westernmost coord for the slot
        @map_titles,           # the titles to put above - for relational maps
        $map_set_aid,          # the map set acc. ID - for relational maps
        %feature_type_aids,    # the distinct feature type IDs
    );

    #
    # Some common things we'll need later on.
    #
    my $connecting_line_color  = $drawer->config_data('connecting_line_color');
    my $apr                    = $drawer->apr;
    my $url                    = $apr->url;
    my $map_viewer_url         = $url . '/viewer';
    my $map_details_url        = $url . '/map_details';
    my $map_set_info_url       = $url . '/map_set_info';
    my $rel_map_show_corr_only =
      $drawer->config_data('relational_maps_show_only_correspondences') || 0;
    my $feature_highlight_fg_color =
      $drawer->config_data('feature_highlight_fg_color');
    my $feature_highlight_bg_color =
      $drawer->config_data('feature_highlight_bg_color');

    my $self_url =
      $drawer->map_view eq 'details' ? $map_details_url : $map_viewer_url;

    my @ordered_slot_nos = sort { $a <=> $b } grep { $_ != 0 } keys %$slots;

    my ( @map_buttons, $last_map_x );
    my $last_map_y  = $base_y;
    my $show_labels =
        $is_compressed ? 0
      : $label_features eq 'none' ? 0
      : 1;
    my $show_ticks     = $is_compressed ? 0 : 1;
    my $show_map_title = $is_compressed ? 0 : 1;
    my $show_map_units = $is_compressed ? 0 : 1;

    my $base_x =
        $slot_no == 0 ? $self->base_x
      : $slot_no > 0  ? $self->base_x + $half_title_length + 10
      : $self->base_x - $half_title_length - 20;

    my @map_columns = ();
  MAP:
    for my $map_id (@map_ids) {
        my $map_width    = $self->map_width($map_id);
        my $is_flipped   = 0;
        my @drawing_data = ();
        my $max_x;
        my @map_area_data = ();

        unless ($is_compressed) {
            for my $rec ( @{ $drawer->flip } ) {
                if (   $rec->{'slot_no'} == $slot_no
                    && $rec->{'map_aid'} == $self->accession_id($map_id) )
                {
                    $is_flipped = 1;
                    last;
                }
            }
        }

        my $features = $self->features($map_id);

        #
        # Reset map buttons.
        #
        @map_buttons = (
            {
                url => $map_set_info_url
                  . '?map_set_aid='
                  . $self->map_set_aid($map_id)
                  . ';data_source='
                  . $drawer->data_source,
                alt   => 'Map Set Info',
                label => 'i',
            }
        );

        #
        # The map.
        #
        ###########################################
        my ( $min_x, $map_base_y, $area );
        (
            $base_x, $min_x, $map_base_y, $area, $last_map_x, $last_map_y,
            $pixel_height
          )
          = $self->layout_map_foundation(
            base_x          => $base_x,
            base_y          => $base_y,
            top_y           => $top_y,
            map_id          => $map_id,
            is_compressed   => $is_compressed,
            slot_no         => $slot_no,
            drawer          => $drawer,
            map_columns     => \@map_columns,
            drawing_data    => \@drawing_data,
            original_base_x => $original_base_x,
            last_map_x      => $last_map_x,
            last_map_y      => $last_map_y,
            no_of_maps      => $no_of_maps,
          );
        ###########################################

        my $map_y_end     = $map_base_y + $pixel_height;
        my $draw_sub_name = $SHAPE{ $self->shape($map_id) };
        my @map_bounds    = $self->$draw_sub_name(
            map_id       => $map_id,
            map_units    => $show_map_units ? $self->map_units($map_id) : '',
            drawer       => $drawer,
            coords       => [ $base_x, $map_base_y, $map_y_end ],
            drawing_data => \@drawing_data,
        );

	my $map_details_url = DEFAULT->{'map_details_url'};
	my $map    = $self->map($map_id);
	my $code='';
	eval $self->map_type_data(
	     $map->{'map_type_aid'},'area_code');
	push @map_area_data,
	{
	    coords => \@map_bounds,
	    url    => $map_details_url ."?ref_map_aid=".$map->{'accession_id'},
	    alt    => 'Map Details: '
		. $map->{'map_name'},
                code   => $code,
	    };
	

        $last_map_y = $map_y_end + 2;

        my $map_start         = $self->start_position($map_id);
        my $map_stop          = $self->stop_position($map_id);
        my $actual_map_length = $self->map_length($map_id);
        my $map_length        = $actual_map_length || 1;

        $drawer->register_map_y_coords(
            $slot_no,    $map_id,    $map_start, $map_stop,
            $map_base_y, $map_y_end, $base_x
        );

        if ( @{ $area || [] } ) {
            $map_bounds[0] = $area->[0] if $area->[0] < $map_bounds[0];
            $map_bounds[1] = $area->[1] if $area->[1] < $map_bounds[1];
            $map_bounds[2] = $area->[2] if $area->[2] > $map_bounds[2];
            $map_bounds[3] = $area->[3] if $area->[3] > $map_bounds[3];
        }

        my $map_name = $self->map_name($map_id);
        if ( $drawer->highlight_feature($map_name) ) {
            push @drawing_data,
              [ RECTANGLE, @map_bounds, $feature_highlight_fg_color ];

            push @drawing_data,
              [ FILLED_RECT, @map_bounds, $feature_highlight_bg_color, 0 ];
        }

        $min_x = $map_bounds[0] unless defined $min_x;
        $min_x = $map_bounds[0] if $map_bounds[0] < $min_x;
        $max_x = $map_bounds[2] unless defined $max_x;
        $max_x = $map_bounds[2] if $map_bounds[2] > $max_x;
        $bottom_y = $map_bounds[3] unless defined $bottom_y;
        $bottom_y = $map_bounds[3] if $map_bounds[3] > $bottom_y;

        #
        # Tick marks.
        #
        #############################################
        if ($show_ticks) {
            ( $max_x, $min_x ) = $self->add_tick_marks(
                base_x            => $base_x,
                map_base_y        => $map_base_y,
                drawer            => $drawer,
                map_id            => $map_id,
                slot_no           => $slot_no,
                drawing_data      => \@drawing_data,
                pixel_height      => $pixel_height,
                is_flipped        => $is_flipped,
                actual_map_length => $actual_map_length,
                map_length        => $map_length,
                max_x             => $max_x,
                min_x             => $min_x,
                map_bounds        => \@map_bounds,
            );
        }
        #############################################

        #
        # Features.
        #
        my $min_y = $map_base_y;    # remembers the northermost position
        my %lanes;                  # associate priority with a lane
        my %features_with_corr;     # features w/correspondences
        my ( $leftmostf, $rightmostf );    # furthest features

        for my $lane ( sort { $a <=> $b } keys %$features ) {
	    my %even_labels; # holds label coordinates
            #my ( @north_labels, @south_labels );    # holds label coordinates
            my $lane_features = $features->{$lane};
            my $midpoint      =
              ( $lane_features->[0]->{'start_position'} +
                  $lane_features->[-1]->{'start_position'} ) / 2;
            my $prev_label_y;    # the y value of previous label
            my @fcolumns = ();   # for feature east-to-west

            #
            # Use the "drawing_lane" to determine where to draw the feature.
            #
            unless ( exists $lanes{$lane} ) {
                $lanes{$lane} = {
                    order    => ( scalar keys %lanes ) + 1,
                    furthest => $label_side eq RIGHT ? $rightmostf : $leftmostf,
                };

                my $lane = $lanes{$lane};
                $base_x =
                    $lane->{'furthest'}
                  ? $label_side eq RIGHT
                  ? $lane->{'furthest'} + 2
                  : $lane->{'furthest'} - 2
                  : $base_x;
            }
	    my %drawn_glyphs;
            for my $feature (@$lane_features) {
                ########################################
                my $coords;
                my $color;
                my $label_y;

                ( $leftmostf, $rightmostf, $coords, $color, $label_y ) =
                  $self->add_feature_to_map(
                    base_x            => $base_x,
                    map_base_y        => $map_base_y,
                    drawer            => $drawer,
                    feature           => $feature,
                    map_id            => $map_id,
                    slot_no           => $slot_no,
                    drawing_data      => \@drawing_data,
                    map_area_data     => \@map_area_data,
                    fcolumns          => \@fcolumns,
                    pixel_height      => $pixel_height,
                    is_flipped        => $is_flipped,
                    map_length        => $map_length,
                    leftmostf         => $leftmostf,
                    rightmostf        => $rightmostf,
		    drawn_glyphs      => \%drawn_glyphs,
                    feature_type_aids => \%feature_type_aids,
                  );
                $self->collect_labels_to_display(
                    #north_labels      => \@north_labels,
                    #south_labels      => \@south_labels,
                    even_labels       => \%even_labels,
                    map_id            => $map_id,
                    slot_no           => $slot_no,
                    is_flipped        => $is_flipped,
                    show_labels       => $show_labels,
                    drawer            => $drawer,
                    feature           => $feature,
                    coords            => $coords,
                    color             => $color,
                    midpoint          => $midpoint,
                    label_y           => $label_y,
                    feature_type_aids => \%feature_type_aids,
                    features_with_corr => \%features_with_corr,
                );
                ########################################
            }
            #
            # We have to wait until all the features for the lane are
            # drawn before placing the labels.
            ##############################################
            ( $base_x, $leftmostf, $rightmostf, $max_x, $min_x, $top_y,
	      $bottom_y, $min_y )=$self->add_labels_to_map(
                base_x        => $base_x,
		base_y        => $base_y,
                even_labels  => \%even_labels,
                #north_labels  => \@north_labels,
                #south_labels  => \@south_labels,
                drawer        => $drawer,
                rightmostf    => $rightmostf,
                leftmostf     => $leftmostf,
                map_id        => $map_id,
                slot_no       => $slot_no,
                drawing_data  => \@drawing_data,
                map_area_data => \@map_area_data,
                features_with_corr => \%features_with_corr,
                max_x              => $max_x,
                min_x              => $min_x,
                top_y              => $top_y,
                bottom_y           => $bottom_y,
                min_y              => $min_y,
                pixel_height       => $pixel_height,
            );
            ##############################################
            $lanes{$lane}{'furthest'} =
              $label_side eq RIGHT ? $rightmostf : $leftmostf;
        }

  #
  # Make sure that the lanes for the maps take into account
  # the span of all the features.
  #
  #        if ( $is_compressed ) {
  #            my $last_feature_lane = ( sort { $a <=> $b } keys %lanes )[-1];
  #            my $furthest_feature  = $lanes{ $last_feature_lane }{'furthest'};
  #            my ( $leftmostf, $rightmostf );
  #
  #            if ( $label_side eq RIGHT ) {
  #                $leftmostf  = $map_bounds[0];
  #                $rightmostf = $furthest_feature > $map_bounds[2]
  #                    ? $furthest_feature : $map_bounds[2];
  #            }
  #            else {
  #                $rightmostf = $map_bounds[2];
  #                $leftmostf  = $furthest_feature < $map_bounds[0]
  #                    ? $furthest_feature : $map_bounds[0];
  #            }
  #
  #            my $map_lane =  column_distribution(
  #                columns  => \@columns,
  #                top      => $map_bounds[1],
  #                bottom   => $map_bounds[3],
  #                buffer   => 4,
  #                col_span => sprintf( "%.0f",
  #                    ( abs( $leftmostf - $rightmostf ) / $column_width ) + .5
  #                ),
  #            );
  #
  #            if ( $map_lane ) {
  #                my $shift       = $column_width * $map_lane;
  #                $shift         *= -1 if $label_side eq LEFT;
  #                $map_bounds[0] += $shift;
  #                $map_bounds[2] += $shift;
  #                $leftmostf     += $shift;
  #                $rightmostf    += $shift;
  #                $slot_min_x = $leftmostf  if $leftmostf  < $slot_min_x;
  #                $slot_max_x = $rightmostf if $rightmostf > $slot_max_x;
  #
  #                for my $rec ( @drawing_data ) {
  #                    my $shape = $rec->[0];
  #                    for my $x_field ( @{ SHAPE_XY->{ $shape }{'x'} } ) {
  #                        $rec->[ $x_field ] += $shift;
  #                    }
  #                }
  #
  #                for my $rec ( @map_area_data ) {
  #                    $rec->{'coords'}[ $_ ] += $shift for ( 1, 3 );
  #                }
  #
  #                for my $rec ( values %features_with_corr ) {
  #                    $rec->{'right'}[0] += $shift;
  #                    $rec->{'left'}[0]  += $shift;
  #                }
  #            }
  #        }

        #
        # Register all the features that have correspondences.
        #
        $drawer->register_feature_position(%$_) for values %features_with_corr;

        #
        # Map details button.
        #
        my $slots = $drawer->slots;
        my @maps;
        for my $side (qw[ left right ]) {
            my $no     = $side eq 'left' ? $slot_no - 1 : $slot_no + 1;
            my $new_no = $side eq 'left' ? -1           : 1;
            my $map   = $slots->{$no} or next;
            my $field = $map->{'field'};
            my $aid   =
              ref $map->{'aid'} eq 'ARRAY'
              ? join( ',', @{ $map->{'aid'} } )
              : $map->{'aid'};
            my $link = join( '%3d', $new_no, $field, $aid );

            my @ref_positions =
              sort { $a->[0] <=> $b->[0] }
              $drawer->feature_correspondence_map_positions(
                slot_no      => $slot_no,
                map_id       => $map_id,
                comp_slot_no => $no,
              );

            if (@ref_positions) {
                my $first = $ref_positions[0]->[0];
                my $last  =
                  defined $ref_positions[-1]->[1]
                  ? $ref_positions[-1]->[1]
                  : $ref_positions[-1]->[0];
                @ref_positions = ( $first, $last );
            }
            else {
                my $ref_corrs =
                  $drawer->map_correspondences( $slot_no, $map_id );
                my ( $k, $v ) = each %$ref_corrs;
                @ref_positions = ( $v->{'min_start'}, $v->{'max_start'} );
            }

            if (@ref_positions) {
                $link .= '[' . join( ',', @ref_positions ) . ']';
            }

            push @maps, $link;
        }

        my $details_url =
            $map_details_url
          . '?ref_map_set_aid='
          . $self->map_set_aid($map_id)
          . ';ref_map_aid='
          . $self->accession_id($map_id)
          . ';comparative_maps='
          . join( ':', @maps )
          . ';label_features='
          . $drawer->label_features
          . ';include_feature_types='
          . join( ',', @{ $drawer->include_feature_types || [] } )
          . ';include_evidence_types='
          . join( ',', @{ $drawer->include_evidence_types || [] } )
          . ';highlight='
          . uri_escape( $drawer->highlight )
          . ';min_correspondences='
          . $drawer->min_correspondences
          . ';image_type='
          . $drawer->image_type
          . ';data_source='
          . $drawer->data_source;

        if ($is_compressed) {
            push @map_area_data,
              {
                coords => \@map_bounds,
                url    => $details_url,
                alt    => 'Details: ' . $self->map_name,
              };
        }
        else {
            push @map_buttons,
              {
                label => '?',
                url   => $details_url,
                alt   => 'Details: ' . ( $self->map_name || '' ),
              };
        }

        #
        # Delete button.
        #
        if ( $slot_no != 0 ) {
            my @cmap_nos;
            if ( $slot_no < 0 ) {
                push @cmap_nos, grep { $_ > $slot_no } @ordered_slot_nos;
            }
            else {
                push @cmap_nos, grep { $_ < $slot_no } @ordered_slot_nos;
            }

            my @flips =
              map { $_->{'slot_no'} . '%3d' . $_->{'map_aid'} }
              @{ $drawer->flip };

            my @cmaps;
            for my $slot_no (@cmap_nos) {
                my $s = join( '%3d',
                    $slot_no,
                    $slots->{$slot_no}{'field'},
                    $slots->{$slot_no}{'aid'} );
                if (   defined $slots->{$slot_no}{'show_start'}
                    && defined $slots->{$slot_no}{'show_stop'} )
                {
                    $s .= '['
                      . $slots->{$slot_no}{'show_start'} . ','
                      . $slots->{$slot_no}{'show_stop'} . ']';
                }
                push @cmaps, $s;
            }

            my $delete_url = $self_url
              . '?ref_map_set_aid='
              . $slots->{'0'}{'map_set_aid'}
              . ';ref_map_aid='
              . $slots->{'0'}{'aid'}
              . ';ref_map_start='
              . $slots->{'0'}{'show_start'}
              . ';ref_map_stop='
              . $slots->{'0'}{'show_stop'}
              . ';comparative_maps='
              . join( ':', @cmaps )
              . ';label_features='
              . $drawer->label_features
              . ';include_feature_types='
              . join( ',', @{ $drawer->include_feature_types || [] } )
              . ';include_evidence_types='
              . join( ',', @{ $drawer->include_evidence_types || [] } )
              . ';highlight='
              . uri_escape( $drawer->highlight )
              . ';min_correspondences='
              . $drawer->min_correspondences
              . ';flip='
              . join( ':', @flips )
              . ';image_type='
              . $drawer->image_type
              . ';data_source='
              . $drawer->data_source;

            push @map_buttons,
              {
                label => 'X',
                url   => $delete_url,
                alt   => 'Delete Map',
              };
        }

        #
        # Flip button.
        #
        unless ($is_compressed) {
            my @cmaps;
            for my $slot_no (@ordered_slot_nos) {
                my $s = join( '%3d',
                    $slot_no,
                    $slots->{$slot_no}{'field'},
                    $slots->{$slot_no}{'aid'} );
                if (   defined $slots->{$slot_no}{'show_start'}
                    && defined $slots->{$slot_no}{'show_stop'} )
                {
                    $s .= '['
                      . $slots->{$slot_no}{'show_start'} . ','
                      . $slots->{$slot_no}{'show_stop'} . ']';
                }
                push @cmaps, $s;
            }

            my @flips;
            my $acc_id = $self->accession_id($map_id);
            for my $rec ( @{ $drawer->flip } ) {
                if (   $rec->{'slot_no'} != $slot_no
                    && $rec->{'map_aid'} != $acc_id )
                {
                    push @flips, $rec->{'slot_no'} . '%3d' . $rec->{'map_aid'};
                }
            }
            push @flips, "$slot_no%3d$acc_id" unless $is_flipped;

            my $ref_map_aid =
              $slots->{'0'}{'field'} eq 'map_set_aid'
              ? '-1'
              : $slots->{'0'}{'aid'};
            my $flip_url = $self_url
              . '?ref_map_set_aid='
              . $slots->{'0'}{'map_set_aid'}
              . ";ref_map_aid=$ref_map_aid"
              . ';ref_map_start='
              . $slots->{'0'}{'show_start'}
              . ';ref_map_stop='
              . $slots->{'0'}{'show_stop'}
              . ';comparative_maps='
              . join( ':', @cmaps )
              . ';label_features='
              . $drawer->label_features
              . ';include_feature_types='
              . join( ',', @{ $drawer->include_feature_types || [] } )
              . ';include_evidence_types='
              . join( ',', @{ $drawer->include_evidence_types || [] } )
              . ';highlight='
              . uri_escape( $drawer->highlight )
              . ';min_correspondences='
              . $drawer->min_correspondences
              . ';image_type='
              . $drawer->image_type
              . ';flip='
              . join( ':', @flips )
              . ';data_source='
              . $drawer->data_source;

            push @map_buttons,
              {
                label => 'F',
                url   => $flip_url,
                alt   => 'Flip Map',
              };
        }

        #
        # New View button.
        #
        unless ($is_compressed) {
            my $new_url =
                $map_viewer_url
              . '?ref_map_set_aid='
              . $self->map_set_aid($map_id)
              . ';ref_map_aid='
              . $self->accession_id($map_id)
              . ';ref_map_start='
              . $self->start_position($map_id)
              . ';ref_map_stop='
              . $self->stop_position($map_id)
              . ';label_features='
              . $drawer->label_features
              . ';include_feature_types='
              . join( ',', @{ $drawer->include_feature_types || [] } )
              . ';include_evidence_types='
              . join( ',', @{ $drawer->include_evidence_types || [] } )
              . ';highlight='
              . uri_escape( $drawer->highlight )
              . ';image_type='
              . $drawer->image_type
              . ';data_source='
              . $drawer->data_source;

            push @map_buttons,
              {
                label => 'N',
                url   => $new_url,
                alt   => 'New Map View',
              };
        }

        #
        # The map title(s).
        #
        if ($is_compressed) {    #&& $slot_no != 0 ) {
            unless (@map_titles) {
                push @map_titles, map { $self->$_($map_id) }
                  grep { !/map_name/ }
                  reverse @config_map_titles;
            }
            $map_set_aid = $self->map_set_aid($map_id);
        }
        else {
            my @lines = map { $self->$_($map_id) } @config_map_titles;
            my ( $bounds, $drawing_data, $map_data ) = $self->draw_map_title(
                left_x  => $min_x,
                right_x => $max_x,
                min_y   => $min_y - $font_height - 8,
                lines   => \@lines,
                buttons => \@map_buttons,
                font    => $reg_font,
            );

            $min_x = $bounds->[0] unless defined $min_x;
            $min_x = $bounds->[0] if $bounds->[0] < $min_x;
            $top_y = $bounds->[1] if $bounds->[1] < $top_y;
            $max_x = $bounds->[2] if $bounds->[2] > $max_x;

            push @drawing_data,  @$drawing_data;
            push @map_area_data, @$map_data;
        }

        $slot_min_x = $min_x unless defined $slot_min_x;
        $slot_min_x = $min_x if $min_x < $slot_min_x;
        $slot_max_x = $max_x unless defined $slot_max_x;
        $slot_max_x = $max_x if $max_x > $slot_max_x;

        $drawer->add_drawing(@drawing_data);
        $drawer->add_map_area(@map_area_data);
    }

    #
    # Draw the map titles last for compressed maps,
    # centered over all the maps.
    #
    if ($is_compressed) {
        my $base_x =
            $label_side eq RIGHT
          ? $self->base_x + $half_title_length + 10
          : $self->base_x - $half_title_length - 20;
        $slot_min_x = $base_x unless defined $slot_min_x;
        $slot_max_x = $base_x unless defined $slot_max_x;

        unless (@map_titles) {
            push @map_titles, map { $self->$_( $map_ids[0] ) }
              grep { !/map_name/ } @config_map_titles;
        }

        my ( $bounds, $drawing_data, $map_data ) = $self->draw_map_title(
            left_x  => $slot_min_x,
            right_x => $slot_max_x,
            min_y   => $top_y - 10 - ( $font_height + 8 ),
            lines   => \@map_titles,
            buttons => \@map_buttons,
            font    => $reg_font,
        );

        $slot_min_x = $bounds->[0] if $bounds->[0] < $slot_min_x;
        $top_y      = $bounds->[1] if $bounds->[1] < $top_y;
        $slot_max_x = $bounds->[2] if $bounds->[2] > $slot_max_x;

        $drawer->add_drawing(@$drawing_data);
        $drawer->add_map_area(@$map_data);
    }

    #
    # Register the feature types we saw.
    #
    $drawer->register_feature_type( keys %feature_type_aids );

    #
    # Background color
    #
    my $buffer = 10;
    return [
        $slot_min_x - $buffer,
        $top_y - $buffer,
        $slot_max_x + $buffer,
        $bottom_y + $buffer,
    ];
}

# ----------------------------------------

=pod

=head2 layout_map_foundation{

Lays out the base map

=cut

sub layout_map_foundation {

    my ( $self, %args ) = @_;

    my ( $min_x, $area );
    my $base_x          = $args{'base_x'};
    my $base_y          = $args{'base_y'};
    my $map_base_y      = $args{'base_y'};
    my $top_y           = $args{'top_y'};
    my $map_id          = $args{'map_id'};
    my $is_compressed   = $args{'is_compressed'};
    my $slot_no         = $args{'slot_no'};
    my $drawer          = $args{'drawer'};
    my $map_columns     = $args{'map_columns'};
    my $drawing_data    = $args{'drawing_data'};
    my $original_base_x = $args{'original_base_x'};
    my $last_map_x      = $args{'last_map_x'};
    my $last_map_y      = $args{'last_map_y'};
    my $no_of_maps      = $args{'no_of_maps'};

    my $pixel_height = $drawer->pixel_height;
    my $label_side   = $drawer->label_side($slot_no);
    my $reg_font     = $drawer->regular_font
      or return $self->error( $drawer->error );
    my $font_width  = $reg_font->width;
    my $font_height = $reg_font->height;

    my $column_width         = 50;
    my $topper_height        = ( $font_height + 2 ) * 2;
    my $map_name             = $self->map_name($map_id);
    my $no_features          = $self->no_features($map_id);
    my $min_map_pixel_height = $drawer->config_data('min_map_pixel_height');
    my $compressed_map_pix_height = int(
        (
            $drawer->pixel_height -
              ( ( ( $font_height + 4 ) * 2 ) * $no_of_maps )
        ) / $no_of_maps
    );
    $compressed_map_pix_height = $min_map_pixel_height
      if $compressed_map_pix_height < $min_map_pixel_height;
    my $compressed_map_pix_width = 4;

    #
    # Indicate total number of features on the map.
    #
    my @map_toppers = $is_compressed ? ($map_name) : ();
    push @map_toppers, "[$no_features]" if defined $no_features;

    #
    # If drawing compressed maps in the first slot, then draw them
    # in "display_order," else we'll try to line them up.
    #
    if ( $is_compressed && $slot_no == 0 ) {
        my ( $this_map_y, $this_map_x );
        if ( $last_map_y > $drawer->pixel_height ) {
            $this_map_y = $base_y;
            $this_map_x = $last_map_x + 50;
        }
        else {
            $this_map_y = $last_map_y;
            $this_map_x = $last_map_x;
        }
        $this_map_x ||= $original_base_x;
        $last_map_x = $this_map_x;
        my $half_label = ( ( $font_width * length($map_name) ) / 2 );
        $base_x       = $this_map_x - $half_label;
        $map_base_y   = $this_map_y;
        $pixel_height = $compressed_map_pix_height;
        $area         = [
            $base_x,
            $this_map_y + $font_height,
            $base_x + $font_width * length($map_name),
            $this_map_y + $font_height + $pixel_height
        ];
    }
    elsif ($is_compressed) {
        my $ref_slot_no = $drawer->reference_slot_no($slot_no);
        my $ref_corrs = $drawer->map_correspondences( $slot_no, $map_id );
        my ( $min_ref_y, $max_ref_y, @ref_connections,$ref_top,$ref_bottom );
        for my $ref_corr ( values %$ref_corrs ) {
            my $pos =
              $drawer->reference_map_y_coords( $ref_slot_no,
                $ref_corr->{'ref_map_id'} );
            my $ref_map_pixel_len = $pos->{'y2'} - $pos->{'y1'};
            my $ref_map_unit_len  = $pos->{'map_stop'} - $pos->{'map_start'};
	    $ref_top              = $pos->{'y1'};
	    $ref_bottom           = $pos->{'y2'};
	    
            my $ref_map_y1 =
              $pos->{'y1'} +
              ( ( $ref_corr->{'min_start'} - $pos->{'map_start'} ) /
                  $ref_map_unit_len ) * $ref_map_pixel_len;
            my $ref_map_y2 =
              $pos->{'y1'} +
              ( ( $ref_corr->{'max_start'} - $pos->{'map_start'} ) /
                  $ref_map_unit_len ) * $ref_map_pixel_len;

            my $ref_map_mid_y =
              $ref_map_y1 + ( ( $ref_map_y2 - $ref_map_y1 ) / 2 );

            push @ref_connections,
              [ $pos->{'x'}, $ref_map_mid_y, $ref_corr->{'no_corr'}, ];

          #
          # This causes the map to span the distance covered on the ref.
          #
          #                $min_ref_y = $ref_map_y1 unless defined $min_ref_y;
          #                $min_ref_y = $ref_map_y1 if $ref_map_y1 < $min_ref_y;
          #                $max_ref_y = $ref_map_y2 unless defined $min_ref_y;
          #                $max_ref_y = $ref_map_y2 if $ref_map_y2 > $max_ref_y;

            #
            # This keeps the map a consistent height.
            #
            $min_ref_y = $ref_map_mid_y - $min_map_pixel_height;
            $max_ref_y = $ref_map_mid_y + $min_map_pixel_height;
        }

        my $map_pix_len = $max_ref_y - $min_ref_y;
        if ( $map_pix_len < $min_map_pixel_height ) {
            $pixel_height = $min_map_pixel_height;
            my $mid_ref_y = $min_ref_y + ( $max_ref_y - $min_ref_y );
            $min_ref_y = $mid_ref_y - ( $pixel_height / 2 );
            $max_ref_y = $mid_ref_y + ( $pixel_height / 2 );
        }
        else {
            $pixel_height = $map_pix_len;
        }
        $map_base_y = $min_ref_y;

        my $map_lane;
	my $buffer = 4;

	if ( @$map_columns ) {        
	    for my $i ( 0..$#{$map_columns} ) {
		if ( $map_columns->[ $i ] < $min_ref_y - $topper_height ) {
		    $map_lane = $i;
		    last;
		}
	    }
	}
	else {
	    $map_lane = 0;
	}
	$map_lane = scalar @$map_columns
	    unless defined $map_lane;
	$map_columns->[ $map_lane ] = $max_ref_y + $buffer;

        $base_x = $original_base_x + ( $column_width * $map_lane );
        $area = [
            $base_x,                                   $min_ref_y,
            $base_x + $font_width * length($map_name), $max_ref_y,
        ];

        my $map_mid_pix = [ $base_x, $min_ref_y + ( $pixel_height / 2 ) ];

        for my $ref_connect (@ref_connections) {
            my $line_color =
                $ref_connect->[2] <= 5  ? 'lightblue'
              : $ref_connect->[2] <= 25 ? 'grey'
              : $ref_connect->[2] <= 50 ? 'brown'
              : 'black';
            push @$drawing_data,
              [
                LINE,              $ref_connect->[0],
                $ref_connect->[1], @$map_mid_pix,
                $line_color,       0
              ];
        }
    }
    $top_y = $map_base_y unless defined $top_y;
    $top_y = $map_base_y if $map_base_y < $top_y;

    for my $i ( 0 .. $#map_toppers ) {
        my $topper = $map_toppers[$i];
        my $f_x    = $base_x - ( ( length($topper) * $font_width ) / 2 );

        my $topper_y;
        if ( $slot_no == 0 ) {
            $topper_y = $map_base_y;
            $map_base_y += $font_height + 2;
            $last_map_y += $font_height + 2;
        }
        else {
            $topper_y =
              $map_base_y - ( $font_height * ( scalar @map_toppers - $i ) + 4 );
        }

        push @$drawing_data,
          [ STRING, $reg_font, $f_x, $topper_y, $topper, 'black' ];
        $min_x = $f_x if ((not defined($min_x)) or $f_x < $min_x);
    }
    return ( $base_x, $min_x, $map_base_y, $area, $last_map_x, $last_map_y,
        $pixel_height );

}

# ---------------------------------------------------
sub add_tick_marks {

    my ( $self, %args ) = @_;
    my $base_x            = $args{'base_x'};
    my $map_base_y        = $args{'map_base_y'};
    my $drawer            = $args{'drawer'};
    my $map_id            = $args{'map_id'};
    my $slot_no           = $args{'slot_no'};
    my $drawing_data      = $args{'drawing_data'};
    my $pixel_height      = $args{'pixel_height'};
    my $is_flipped        = $args{'is_flipped'};
    my $map_start         = $self->start_position($map_id);
    my $actual_map_length = $args{'actual_map_length'};
    my $map_length        = $args{'map_length'};
    my $map_width         = $self->map_width($map_id);
    my $max_x             = $args{'max_x'};
    my $min_x             = $args{'min_x'};
    my $map_bounds        = $args{'map_bounds'};

    my $label_side = $drawer->label_side($slot_no);
    my $reg_font   = $drawer->regular_font
      or return $self->error( $drawer->error );
    my $font_width  = $reg_font->width;
    my $font_height = $reg_font->height;

    my $interval      = $self->tick_mark_interval($map_id) || 1;
    my $no_intervals  = int( $actual_map_length / $interval );
    my $tick_overhang = 5;
    my @intervals     =
      map { int( $map_start + ( $_ * $interval ) ) } 1 .. $no_intervals;

    for my $tick_pos (@intervals) {
        my $rel_position = ( $tick_pos - $map_start ) / $map_length;

        my $y_pos = $is_flipped
          ? $map_bounds->[3] - ( $pixel_height * $rel_position )
          : $map_base_y + ( $pixel_height * $rel_position );

        my $tick_start =
            $label_side eq RIGHT
          ? $base_x - $tick_overhang
          : $base_x;

        my $tick_stop =
            $label_side eq RIGHT
          ? $base_x + $map_width
          : $base_x + $map_width + $tick_overhang;

        push @$drawing_data,
          [ LINE, $tick_start, $y_pos, $tick_stop, $y_pos, 'grey' ];

        my $label_x =
            $label_side eq RIGHT
          ? $tick_start - $font_height - 2
          : $tick_stop + 2;

        my $label_y = $y_pos + ( $font_width * length($tick_pos) ) / 2;

        push @$drawing_data,
          [ STRING_UP, $reg_font, $label_x, $label_y, $tick_pos, 'grey' ];

        my $right = $label_x + $font_height;
        $max_x = $right   if $right > $max_x;
        $min_x = $label_x if $label_x < $min_x;
    }
    return ( $max_x, $min_x );
}

# ---------------------------------------------------
sub add_feature_to_map {

    my ( $self, %args ) = @_;
    my $base_x            = $args{'base_x'};
    my $map_base_y        = $args{'map_base_y'};
    my $drawer            = $args{'drawer'};
    my $feature           = $args{'feature'};
    my $map_id            = $args{'map_id'};
    my $slot_no           = $args{'slot_no'};
    my $drawing_data      = $args{'drawing_data'};
    my $map_area_data     = $args{'map_area_data'};
    my $pixel_height      = $args{'pixel_height'};
    my $is_flipped        = $args{'is_flipped'};
    my $map_length        = $args{'map_length'};
    my $rightmostf        = $args{'rightmostf'};
    my $leftmostf         = $args{'leftmostf'};
    my $fcolumns          = $args{'fcolumns'};
    my $feature_type_aids = $args{'feature_type_aids'};
    my $drawn_glyphs      = $args{'drawn_glyphs'};

    my $map_width = $self->map_width($map_id);
    my $reg_font  = $drawer->regular_font
      or return $self->error( $drawer->error );
    my $font_width            = $reg_font->width;
    my $font_height           = $reg_font->height;
    my $default_feature_color = $drawer->config_data('feature_color');
    my $map_start             = $self->start_position($map_id);
    my $label_side            = $drawer->label_side($slot_no);
    my $feature_corr_color    =
      $drawer->config_data('feature_correspondence_color') || '';
    my $collapse_features   = $drawer->collapse_features;
    my $feature_details_url = DEFAULT->{'feature_details_url'};

    # If the map isn't showing labeled features (e.g., it's a
    # relational map and hasn't been expanded), then leave off
    # drawing features that don't have correspondences.
    #
    my $has_corr = $drawer->has_correspondence( $feature->{'feature_id'} );

#                return if
#                    $is_compressed &&          # a relational map
#                    $rel_map_show_corr_only && # showing only corr. only
#                    $slot_no != 0  &&          # isn't the reference map
#                    !$has_corr     &&          # feature has no correspondences
#                    !$show_labels;             # not showing labels

    my $feature_shape = $feature->{'shape'} || LINE;
    my $shape_is_triangle = $feature_shape =~ /triangle$/;
    my $fstart = $feature->{'start_position'} || 0;
    my $fstop = $shape_is_triangle ? undef: $feature->{'stop_position'};
    $fstop = undef if $fstop < $fstart;

    my $rstart = sprintf( "%.2f", ( $fstart - $map_start ) / $map_length );
    $rstart = $rstart > 1 ? 1 : $rstart < 0 ? 0 : $rstart;
    my $rstop =
      defined $fstop
      ? sprintf( "%.2f", ( $fstop - $map_start ) / $map_length )
      : undef;
    if ( defined $rstop ) {
        $rstop = $rstop > 1 ? 1 : $rstop < 0 ? 0 : $rstop;
    }

    my $tick_overhang = 2;
    my $y_pos1        = $is_flipped
      ? $map_base_y + $pixel_height - ( $pixel_height * $rstart )
      : $map_base_y + ( $pixel_height * $rstart );

    my $y_pos2 =
        defined $rstop
      ? $is_flipped
      ? $map_base_y + $pixel_height - ( $pixel_height * $rstop )
      : $map_base_y + ( $pixel_height * $rstop )
      : undef;

    if ( $is_flipped && defined $y_pos2 ) {
        ( $y_pos2, $y_pos1 ) = ( $y_pos1, $y_pos2 );
    }
    $y_pos2 = $y_pos1 unless defined $y_pos2 && $y_pos2 > $y_pos1;
    my $color = $has_corr ? $feature_corr_color : '';
    $color ||= $feature->{'color'}
      || $default_feature_color;
    my $label      = $feature->{'feature_name'};
    my $tick_start = $base_x - $tick_overhang;
    my $tick_stop  = $base_x + $map_width + $tick_overhang;

    my  $label_y; 
    my @coords=();
    if ( $shape_is_triangle || $y_pos2 <= $y_pos1 ) {
        $label_y               = $y_pos1 - $font_height / 2;
        $feature->{'midpoint'} = $fstart;
        $feature->{'mid_y'}    = $y_pos1;
    }
    else {
        $label_y = ( $y_pos1 + ( $y_pos2 - $y_pos1 ) / 2 ) - $font_height / 2;

        $feature->{'midpoint'} =
          ( $fstop > $fstart ) ? ( $fstart + $fstop ) / 2 : $fstart;

        $feature->{'mid_y'} = ( $y_pos1 + $y_pos2 ) / 2;
    }
    #
    # Here we try to reduce the redundant drawing of glyphs.
    # However, if a feature has a correspondence, we want to
    # make sure to draw it so it will show up highlighted.
    #
    my $glyph_key = int($y_pos1) . $feature_shape . int($y_pos2);
    my $draw_this = 1;
    #print STDERR "$glyph_key\n";
    if ( $drawn_glyphs->{$glyph_key} ) {
        $draw_this = $has_corr ? 1 : 0;
	#print STDERR "$drawn_glyphs->{$glyph_key}\n";
    }

    if ($draw_this) {
        $drawn_glyphs->{$glyph_key} = 1;
    my (  @temp_drawing_data );
    if ( $feature_shape eq LINE ) {
        $y_pos1 = ( $y_pos1 + $y_pos2 ) / 2;
        push @temp_drawing_data,
          [ LINE, $tick_start, $y_pos1, $tick_stop, $y_pos1, $color ];

        @coords = ( $tick_start, $y_pos1, $tick_stop, $y_pos1 );
    }
    else {
	
        my $buffer       = 2;
        my $column_index; 
	if ( @$fcolumns ) {        
	    for my $i ( 0..$#{$fcolumns} ) {
		if ( $fcolumns->[ $i ] < $y_pos1 ) {
		    $column_index = $i;
		    last;
		}
	    }
	}
	else {
	    $column_index = 0;
	}
	$column_index = scalar @$fcolumns
	    unless defined $column_index;
	$fcolumns->[ $column_index ] = $y_pos2 + $buffer;
	
        my $offset       = ( $column_index + 1 ) * 7;
        my $vert_line_x1 = $label_side eq RIGHT ? $tick_start : $tick_stop;
        my $vert_line_x2 =
            $label_side eq RIGHT
          ? $tick_stop + $offset
          : $tick_start - $offset;

        unless ($shape_is_triangle) {
            push @temp_drawing_data,
              [ LINE, $vert_line_x2, $y_pos1, $vert_line_x2, $y_pos2, $color, ];

            @coords = ( $vert_line_x2, $y_pos1, $vert_line_x2, $y_pos2 );
        }

        if ( $feature_shape eq 'span' ) {
            my $reverse = $label_side eq RIGHT ? -1 : 1;
            push @temp_drawing_data,
              [
                LINE, $vert_line_x2,
                $y_pos1, $vert_line_x2 + ( 3 * $reverse ),
                $y_pos1, $color,
              ];

            push @temp_drawing_data,
              [
                LINE, $vert_line_x2,
                $y_pos2, $vert_line_x2 + ( 3 * $reverse ),
                $y_pos2, $color,
              ];
            if ($reverse >0){
                @coords = ( $vert_line_x2, $y_pos1, $vert_line_x2+3, $y_pos2 );
            }
            else{
                @coords = ( $vert_line_x2-3, $y_pos1, $vert_line_x2, $y_pos2 );
            }
        }
        elsif ( $feature_shape eq 'up-arrow' ) {
            push @temp_drawing_data,
              [
                LINE,        $vert_line_x2,
                $y_pos1,     $vert_line_x2 - 2,
                $y_pos1 + 2, $color
              ];

            push @temp_drawing_data,
              [
                LINE,        $vert_line_x2,
                $y_pos1,     $vert_line_x2 + 2,
                $y_pos1 + 2, $color
              ];

            @coords =
              ( $vert_line_x2 - 2, $y_pos2, $vert_line_x2 + 2, $y_pos1, );
        }
        elsif ( $feature_shape eq 'down-arrow' ) {
            push @temp_drawing_data,
              [
                LINE,        $vert_line_x2,
                $y_pos2,     $vert_line_x2 - 2,
                $y_pos2 - 2, $color
              ];

            push @temp_drawing_data,
              [
                LINE,        $vert_line_x2,
                $y_pos2,     $vert_line_x2 + 2,
                $y_pos2 - 2, $color
              ];

            @coords =
              ( $vert_line_x2 - 2, $y_pos2, $vert_line_x2 + 2, $y_pos1, );
        }
        elsif ( $feature_shape eq 'double-arrow' ) {
            push @temp_drawing_data,
              [
                LINE,        $vert_line_x2,
                $y_pos1,     $vert_line_x2 - 2,
                $y_pos1 + 2, $color
              ];
            push @temp_drawing_data,
              [
                LINE,        $vert_line_x2,
                $y_pos1,     $vert_line_x2 + 2,
                $y_pos1 + 2, $color
              ];
            push @temp_drawing_data,
              [
                LINE,        $vert_line_x2,
                $y_pos2,     $vert_line_x2 - 2,
                $y_pos2 - 2, $color
              ];
            push @temp_drawing_data,
              [
                LINE,        $vert_line_x2,
                $y_pos2,     $vert_line_x2 + 2,
                $y_pos2 - 2, $color
              ];

            @coords =
              ( $vert_line_x2 - 2, $y_pos2, $vert_line_x2 + 2, $y_pos1, );
        }
        elsif ( $feature_shape eq 'box' ) {
            $vert_line_x1 =
                $label_side eq RIGHT
              ? $tick_start - $offset
              : $tick_stop + $offset;
            $vert_line_x2 =
                $label_side eq RIGHT
              ? $tick_stop + $offset
              : $tick_start - $offset;

            @coords = ( $vert_line_x2, $y_pos2, $vert_line_x1, $y_pos1, );

            push @temp_drawing_data, [ RECTANGLE, @coords, $color ];
        }
        elsif ( $feature_shape eq 'dumbbell' ) {
            my $width = 4;
            unless ( $y_pos1 == $y_pos2 ) {
                $y_pos1 += 2;
                $y_pos2 -= 2;
            }

            push @temp_drawing_data,
              [ ARC, $vert_line_x2, $y_pos1, $width, $width, 0, 360, $color ];
            push @temp_drawing_data,
              [ ARC, $vert_line_x2, $y_pos2, $width, $width, 0, 360, $color ];

            @coords = (
                $vert_line_x2 - $width / 2, $y_pos1,
                $vert_line_x2 + $width / 2, $y_pos2
            );
        }
        elsif ( $feature_shape eq 'filled-box' ) {
            my $width = 3;
            push @temp_drawing_data,
              [
                FILLED_RECT,            $vert_line_x2, $y_pos1,
                $vert_line_x2 + $width, $y_pos2,       $color,
              ];
            push @temp_drawing_data,
              [
                RECTANGLE, $vert_line_x2,
                $y_pos1,   $vert_line_x2 + $width,
                $y_pos2,   'black',
              ];
            @coords = (
                $vert_line_x2 - $width / 2, $y_pos1,
                $vert_line_x2 + $width / 2, $y_pos2
            );
        }
        elsif (
            ( $feature_shape eq 'in-triangle' && $label_side eq LEFT )
            || (   $feature_shape eq 'out-triangle'
                && $label_side eq RIGHT )
          )
        {
            my $width = 3;
            push @temp_drawing_data,
              [
                LINE,          $vert_line_x2,    $y_pos1 - $width,
                $vert_line_x2, $y_pos1 + $width, $color
              ];
            push @temp_drawing_data,
              [
                LINE,             $vert_line_x2,
                $y_pos1 - $width, $vert_line_x2 + $width,
                $y_pos1,          $color
              ];
            push @temp_drawing_data,
              [
                LINE,             $vert_line_x2,
                $y_pos1 + $width, $vert_line_x2 + $width,
                $y_pos1,          $color
              ];
            push @temp_drawing_data,
              [ FILL, $vert_line_x2 + 1, $y_pos1 + 1, $color ];

            @coords = (
                $vert_line_x2 - $width,
                $y_pos1 - $width,
                $vert_line_x2 + $width,
                $y_pos1 + $width,
            );
        }
        elsif (
            ( $feature_shape eq 'in-triangle' && $label_side eq RIGHT )
            || (   $feature_shape eq 'out-triangle'
                && $label_side eq LEFT )
          )
        {
            my $width = 3;
            push @temp_drawing_data,
              [
                LINE,
                $vert_line_x2 + $width,
                $y_pos1 - $width,
                $vert_line_x2 + $width,
                $y_pos1 + $width,
                $color
              ];
            push @temp_drawing_data,
              [
                LINE,             $vert_line_x2 + $width,
                $y_pos1 - $width, $vert_line_x2,
                $y_pos1,          $color
              ];
            push @temp_drawing_data,
              [
                LINE,             $vert_line_x2,
                $y_pos1,          $vert_line_x2 + $width,
                $y_pos1 + $width, $color
              ];
            push @temp_drawing_data,
              [ FILL, $vert_line_x2 + $width - 1, $y_pos1 + 1, $color ];

            @coords = (
                $vert_line_x2 - $width,
                $y_pos1 - $width,
                $vert_line_x2 + $width,
                $y_pos1 + $width,
            );
        }


        if ( $feature->{'feature_type'} eq 'chunk' ) {
            push @$map_area_data,
              {
                coords => \@coords,
                url    => 'viewer?',
                alt    => 'Zoom: '
                  . $feature->{'start_position'} . '-'
                  . $feature->{'stop_position'}
              };
        }
        else {
            my $code='';
            eval $self->feature_type_data(
                          $feature->{'feature_type_aid'},'area_code');
            push @$map_area_data,
              {
                coords => \@coords,
                url    => $feature_details_url . $feature->{'accession_id'},
                alt    => 'Feature Details: '
                  . $feature->{'feature_name'} . ' ['
                  . $feature->{'accession_id'} . ']',
                code   => $code,
              };
        }

	
    }

    
        push @$drawing_data, @temp_drawing_data;
    

    #
    # Register that we saw this type of feature.
    #
    $feature_type_aids->{ $feature->{'feature_type_aid'} } = 1;

    ####
    my ( $left_side, $right_side );
    my $buffer = 2;
    $left_side  = $coords[0] - $buffer;
    $right_side = $coords[2] + $buffer;
    $leftmostf  = $left_side unless defined $leftmostf;
    $rightmostf = $right_side unless defined $rightmostf;
    $leftmostf  = $left_side if $left_side < $leftmostf;
    $rightmostf = $right_side if $right_side > $rightmostf;
}
    return ( $leftmostf, $rightmostf, \@coords, $color, $label_y );
}

# ----------------------------------------------------
sub collect_labels_to_display {

    my ( $self, %args ) = @_;

    my $coords             = $args{'coords'};
    #my $north_labels       = $args{'north_labels'};
    #my $south_labels       = $args{'south_labels'};
    my $even_labels        = $args{'even_labels'};
    my $drawer             = $args{'drawer'};
    my $feature            = $args{'feature'};
    my $color              = $args{'color'};
    my $label_y            = $args{'label_y'};
    my $is_flipped         = $args{'is_flipped'};
    my $map_id             = $args{'map_id'};
    my $slot_no            = $args{'slot_no'};
    my $show_labels        = $args{'show_labels'};
    my $midpoint           = $args{'midpoint'};
    my $feature_type_aids  = $args{'feature_type_aids'};
    my $features_with_corr = $args{'features_with_corr'};

    my $label    = $feature->{'feature_name'};
    my $has_corr = $drawer->has_correspondence( $feature->{'feature_id'} );
    my $feature_details_url = DEFAULT->{'feature_details_url'};

    my $is_highlighted = $drawer->highlight_feature(
        $feature->{'feature_name'},
        @{ $feature->{'aliases'} || [] },
        $feature->{'accession_id'},
    );

    if ($has_corr) {
        my $mid_feature =
          $coords->[1] + ( ( $coords->[3] - $coords->[1] ) / 2 );
        $features_with_corr->{ $feature->{'feature_id'} } = {
            feature_id => $feature->{'feature_id'},
            slot_no    => $slot_no,
            map_id     => $map_id,
            left       => [ $coords->[0], $mid_feature ],
            right      => [ $coords->[2], $mid_feature ],
            tick_y     => $mid_feature,
        };
    }

    if (
        $show_labels
        && (
               $has_corr
            || $drawer->label_features eq 'all'
            || $is_highlighted
            || (   $drawer->label_features eq 'landmarks'
                && $feature->{'is_landmark'} )
        )
      )
    {
#        my $labels =
#             $feature->{'midpoint'} < $midpoint && $is_flipped
#          || $feature->{'midpoint'} > $midpoint && $is_flipped
#          || $feature->{'midpoint'} < $midpoint && !$is_flipped
#          ? $north_labels
#          : $south_labels;
#
#        push @$labels,
#          {
#            priority       => $feature->{'drawing_priority'},
#            text           => $label,
#            target         => $label_y,
#            color          => $color,
#            is_highlighted => $is_highlighted,
#            feature_coords => $coords,
#            feature_mid_y  => $feature->{'mid_y'},
#            feature_type   => $feature->{'feature_type'},
#            has_corr       => $has_corr,
#            feature_id     => $feature->{'feature_id'},
#            start_position => $feature->{'start_position'},
#            shape          => $feature->{'shape'},
#            url            => $feature_details_url . $feature->{'accession_id'},
#            alt            => 'Feature Details: '
#              . $feature->{'feature_name'} . ' ['
#              . $feature->{'accession_id'} . ']',
#          };
	my $even_label_key = $is_highlighted ? 'highlights'
	    : $has_corr ? 'correspondences' : 'normal';
	push @{ $even_labels->{ $even_label_key } }, {
	    priority       => $feature->{'drawing_priority'},
	    text           => $label,
	    target         => $label_y,
	    color          => $color,
	    is_highlighted => $is_highlighted,
	    feature_coords => $coords,
	    feature_mid_y  => $feature->{'mid_y'},
	    feature_type   => $feature->{'feature_type'},
	    has_corr       => $has_corr,
	    feature_id     => $feature->{'feature_id'},
	    start_position => $feature->{'start_position'},
	    shape          => $feature->{'shape'},
	    url            => 
		$feature_details_url.$feature->{'accession_id'},
		alt            => 
		'Feature Details: ' . $feature->{'feature_name'}.
		' [' . $feature->{'accession_id'} . ']',
	    };
    } 
    
}

# ----------------------------------------------------
sub add_labels_to_map {

    # Labels moving north
    # must be reverse sorted by start position;  moving south,
    # they should be in ascending order.
    #
    my ( $self, %args ) = @_;

    my $base_x             = $args{'base_x'};
    my $base_y             = $args{'base_y'};
    my $even_labels        = $args{'even_labels'};
    #my $north_labels       = $args{'north_labels'};
    #my $south_labels       = $args{'south_labels'};
    my $drawer             = $args{'drawer'};
    my $rightmostf         = $args{'rightmostf'};
    my $leftmostf          = $args{'leftmostf'};
    my $map_id             = $args{'map_id'};
    my $slot_no            = $args{'slot_no'};
    my $drawing_data       = $args{'drawing_data'};
    my $map_area_data      = $args{'map_area_data'};
    my $features_with_corr = $args{'features_with_corr'};
    my $max_x              = $args{'max_x'};
    my $min_x              = $args{'min_x'};
    my $top_y              = $args{'top_y'};
    my $bottom_y           = $args{'bottom_y'};
    my $min_y              = $args{'min_y'};
    my $pixel_height       = $args{'pixel_height'};

    my $label_side = $drawer->label_side($slot_no);
    my $reg_font   = $drawer->regular_font
      or return $self->error( $drawer->error );
    my $font_width         = $reg_font->width;
    my $font_height        = $reg_font->height;
    my $feature_corr_color =
      $drawer->config_data('feature_correspondence_color') || '';
    my $feature_highlight_fg_color =
      $drawer->config_data('feature_highlight_fg_color');
    my $feature_highlight_bg_color =
      $drawer->config_data('feature_highlight_bg_color');

    #my @accepted_labels;    # the labels we keep
    my $buffer = 2;         # the space between things
    #if ( $north_labels || $south_labels ) {
    #    @$north_labels =
    #      map  { $_->[0] }
    #      sort {
    #             $b->[1] <=> $a->[1]
    #          || $a->[2] <=> $b->[2]
    #          || $b->[3] <=> $a->[3]
    #          || $b->[4] <=> $a->[4]
    #      }
    #      map {
    #        [
    #            $_, $_->{'target'},
    #            $_->{'priority'}, $_->{'is_highlighted'} || 0,
    #            $_->{'has_corr'} || 0,
    #        ]
    #      } @$north_labels;
    #
    #    @$south_labels =
    #      map  { $_->[0] }
    #      sort {
    #             $a->[1] <=> $b->[1]
    #          || $b->[2] <=> $a->[2]
    #          || $b->[3] <=> $a->[3]
    #          || $b->[4] <=> $a->[4]
    #      }
    #      map {
    #        [
    #            $_, $_->{'target'},
    #            $_->{'priority'}, $_->{'is_highlighted'} || 0,
    #            $_->{'has_corr'} || 0,
    #        ]
    #      } @$south_labels;
    #
    #    my $used = label_distribution(
    #        labels     => $north_labels,
    #        accepted   => \@accepted_labels,
    #        used       => [],
    #        buffer     => $buffer,
    #        direction  => NORTH,
    #        row_height => $font_height,
    #    );
    #
    #    label_distribution(
    #        labels     => $south_labels,
    #        accepted   => \@accepted_labels,
    #        used       => $used,
    #        buffer     => $buffer,
    #        direction  => SOUTH,
    #        row_height => $font_height,
    #    );
    #}
    my $accepted_labels = even_label_distribution
	( 
	  labels          => $even_labels,
	  map_height      => $pixel_height,
	  font_height     => $font_height,
	  start_y         => $base_y,
	  );
    my $label_offset = 15;
    $base_x =
        $label_side eq RIGHT
      ? $rightmostf > $base_x ? $rightmostf : $base_x
      : $leftmostf < $base_x
      ? $leftmostf
      : $base_x;

    for my $label (@$accepted_labels) {
        my $text    = $label->{'text'};
        my $label_y = $label->{'y'};
        my $label_x =
            $label_side eq RIGHT
          ? $base_x + $label_offset
          : $base_x - $label_offset - ( $font_width * length($text) );
        my $label_end = $label_x + $font_width * length($text);
        my $color     =
            $label->{'has_corr'}
          ? $feature_corr_color || $label->{'color'}
          : $label->{'color'};

        push @$drawing_data,
          [ STRING, $reg_font, $label_x, $label_y, $text, $color ];

        my @label_bounds = (
            $label_x - $buffer,
            $label_y,
            $label_end + $buffer,
            $label_y + $font_height,
        );

        $leftmostf = $label_bounds[0] if $label_bounds[0] < $leftmostf;
        $rightmostf = $label_bounds[2]
          if $label_bounds[2] > $rightmostf;

        #
        # Highlighting.
        #
        if ( $label->{'is_highlighted'} ) {
            push @$drawing_data,
              [ RECTANGLE, @label_bounds, $feature_highlight_fg_color ];

            push @$drawing_data,
              [ FILLED_RECT, @label_bounds, $feature_highlight_bg_color, 0 ];
        }

        push @$map_area_data,
          {
            coords => \@label_bounds,
            url    => $label->{'url'},
            alt    => $label->{'alt'},
          };

        $min_x    = $label_bounds[0] if $label_bounds[0] < $min_x;
        $top_y    = $label_bounds[1] if $label_bounds[1] < $top_y;
        $max_x    = $label_bounds[2] if $label_bounds[2] > $max_x;
        $bottom_y = $label_bounds[3] if $label_bounds[3] > $bottom_y;
        $min_y    = $label_y         if $label_y < $min_y;

        #
        # Now connect the label to the middle of the feature.
        #
        my @coords = @{ $label->{'feature_coords'} || [] };
        my $label_connect_x1 =
            $label_side eq RIGHT
          ? $coords[2]
          : $label_end + $buffer;

        my $label_connect_y1 =
            $label_side eq RIGHT
          ? $label->{'feature_mid_y'}
          : $label_y + $font_height / 2;

        my $label_connect_x2 =
            $label_side eq RIGHT
          ? $label_x - $buffer
          : $coords[0];

        my $label_connect_y2 =
            $label_side eq RIGHT
          ? $label_y + $font_height / 2
          : $label->{'feature_mid_y'};

        #
        # Back the connection off.
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
            $label_connect_x1, $label_connect_y1, $label_connect_x2,
            $label_connect_y2, 'grey'
        );

        #
        # If the feature got a label, then update the right
        # or left connection points for linking up to
        # corresponding features.
        #
        if ( defined $features_with_corr->{ $label->{'feature_id'} } ) {
            if ( $label_side eq RIGHT ) {
                $features_with_corr->{ $label->{'feature_id'} }{'right'} = [
                    $label_bounds[2],
                    (
                        $label_bounds[1] +
                          ( $label_bounds[3] - $label_bounds[1] ) / 2
                    )
                ];
            }
            else {
                $features_with_corr->{ $label->{'feature_id'} }{'left'} = [
                    $label_bounds[0],
                    (
                        $label_bounds[1] +
                          ( $label_bounds[3] - $label_bounds[1] ) / 2
                    )
                ];
            }
        }
    }

    $min_x = $leftmostf  if $leftmostf < $min_x;
    $max_x = $rightmostf if $rightmostf > $max_x;

    return ( $base_x, $leftmostf, $rightmostf, $max_x, $min_x, $top_y,
        $bottom_y, $min_y );

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
        my @map_ids = keys %{ $self->{'maps'} || {} };

        if ( $self->slot_no == 0 && scalar @map_ids > 1 ) {
            $self->{'sorted_map_ids'} = [
                map { $_->[0] }
                  sort { $a->[1] <=> $b->[1] || $a->[2] cmp $b->[2] }
                  map {
                    [
                        $_,
                        $self->{'maps'}{$_}{'display_order'},
                        $self->{'maps'}{$_}{'map_name'}
                    ]
                  } @map_ids
            ];
        }
        else {
            $self->{'sorted_map_ids'} = [
                map    { $_->[0] }
                  sort { $b->[1] <=> $a->[1] }
                  map  { [ $_, $self->{'maps'}{$_}{'no_correspondences'} ] }
                  @map_ids
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

    my $self = shift;
    my $map_id = shift or return;
    return $self->{'maps'}{$map_id};
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
    my $map    = $self->map($map_id);
    return $map->{'width'}
      || $map->{'default_width'}
      || $self->config_data('map_width');
}

# ----------------------------------------------------
sub real_map_length {

=pod

=head2 real_map_length

Returns the entiry map's length.

=cut

    my $self = shift;
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
    my $map    = $self->map($map_id);
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
    my $map    = $self->map($map_id);
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
    my $map    = $self->map($map_id);
    return $map->{'start_position'};
}

# ----------------------------------------------------
sub stop_position {

=pod

=head2 stop_position

Returns a map's stop position for the range selected.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    return $map->{'stop_position'};
}

# ----------------------------------------------------
sub tick_mark_interval {

=pod

=head2 tick_mark_interval

Returns the map's tick mark interval.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);

    unless ( defined $map->{'tick_mark_interval'} ) {
        my $map_length =
          $self->stop_position($map_id) - $self->start_position($map_id);
        $map->{'tick_mark_interval'} = int( $map_length / 5 );
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

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

