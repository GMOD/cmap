package Bio::GMOD::CMap::Drawer::AppLayout;

# vim: set ft=perl:

# $Id: AppLayout.pm,v 1.70 2008-04-01 20:31:38 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Drawer::AppLayout - Layout Methods

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Drawer::AppLayout;

=head1 DESCRIPTION

This module contains methods to layout the drawing surface

=head1 EXPORTED SUBROUTINES

=cut 

use strict;
use Data::Dumper;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Drawer::AppGlyph;
use Bio::GMOD::CMap::Utils qw[
    simple_column_distribution
    presentable_number
];

require Exporter;
use vars qw( $VERSION @EXPORT @EXPORT_OK );
$VERSION = (qw$Revision: 1.70 $)[-1];

use constant ZONE_SEPARATOR_HEIGHT    => 3;
use constant ZONE_LOCATION_BAR_HEIGHT => 10;
use constant ZONE_Y_BUFFER            => 30;
use constant MAP_Y_BUFFER             => 15;
use constant MAP_X_BUFFER             => 5;
use constant MAP_X_NO_DETAILS_BUFFER  => 0;
use constant SMALL_BUFFER             => 2;
use constant MIN_MAP_WIDTH            => 4;
use constant MIN_MAP_DETAIL_WIDTH     => 50;
use constant BETWEEN_ZONE_BUFFER      => 5;

use base 'Exporter';

my @subs = qw[
    layout_new_window
    layout_zone
    layout_overview
    overview_selected_area
    layout_head_maps
    layout_sub_maps
    add_zone_separator
    add_correspondences
    set_zone_bgcolor
    move_map
    destroy_map_for_relayout
];
@EXPORT_OK = @subs;
@EXPORT    = @subs;

my %SHAPE = (
    'default'  => \&_draw_box,
    'box'      => \&_draw_box,
    'dumbbell' => \&_draw_dumbbell,
    'I-beam'   => \&_draw_i_beam,
    'i-beam'   => \&_draw_i_beam,
    'I_beam'   => \&_draw_i_beam,
    'i_beam'   => \&_draw_i_beam,
);

# ----------------------------------------------------
sub layout_new_window {

=pod

=head2 layout_new_window

=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $head_zone_key    = $args{'head_zone_key'};
    my $app_display_data = $args{'app_display_data'};
    my $width            = $args{'width'} || 900;
    my $window_layout    = $app_display_data->{'window_layout'}{$window_key};

    # Initialize bounds
    # But have a height of 0.
    $window_layout->{'bounds'} = [ 0, 0, $width, 0, ];

    layout_zone(
        window_key       => $window_key,
        zone_key         => $head_zone_key,
        zone_bounds      => $window_layout->{'bounds'},
        app_display_data => $app_display_data,
    );
    my $window_height_change
        = $app_display_data->{'zone_layout'}{$head_zone_key}{'bounds'}[3]
        - $app_display_data->{'zone_layout'}{$head_zone_key}{'bounds'}[1];

    $window_layout->{'changed'}     = 1;
    $window_layout->{'sub_changed'} = 1;

    return;
}

# ----------------------------------------------------
sub layout_overview {

=pod

=head2 layout_overview



=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $app_display_data = $args{'app_display_data'};
    my $width
        = $args{'width'}
        || $app_display_data->{'window_layout'}{$window_key}{'width'}
        ? ( $app_display_data->{'window_layout'}{$window_key}{'width'} - 400 )
        : 500;

    my $overview_layout = $app_display_data->{'overview_layout'}{$window_key};
    my $head_zone_key
        = $app_display_data->{'overview'}{$window_key}{'zone_key'};

    my $map_height = 5;
    $overview_layout->{'map_buffer_y'} = 5;
    my $zone_buffer_y = 15;
    my $zone_buffer_x = 15;

    $overview_layout->{'internal_bounds'} = [ 0, 0, $width, 0 ];

    # zone_max_y is going to be used to place maps.
    my $zone_min_y = 0;
    my $zone_max_y = $zone_min_y;

    # Layout Top Slot
    my $main_zone_layout = $app_display_data->{'zone_layout'}{$head_zone_key};
    my $top_overview_zone_layout
        = $overview_layout->{'zones'}{$head_zone_key};

    my $zone_width = $width - ( $zone_buffer_x * 2 );

    # Set the Bounds for the zone.
    $top_overview_zone_layout->{'bounds'} = [
        $zone_buffer_x,
        $zone_min_y + $zone_buffer_y,
        $width - $zone_buffer_x,
        $zone_min_y + $zone_buffer_y
    ];
    $top_overview_zone_layout->{'internal_bounds'} = [ 0, 0, $zone_width, 0 ];

    # Get the scale diff between the overview and the main view
    my ($top_pixel_factor,
        $overview_vis_x1_in_main_coords,
        $overview_vis_x2_in_main_coords
        )
        = overview_scale_and_visible_regions_from_main(
        overview_zone_layout => $top_overview_zone_layout,
        main_zone_layout     => $main_zone_layout,
        );

    # Sort maps according to height.  This way, maps can be drawn from top to
    # bottom.
    # Exclude maps that haven't been drawn (ie they'be been binned).
    my @sorted_map_keys = sort {
        $app_display_data->{'map_layout'}{$a}{'bounds'}[1]
            <=> $app_display_data->{'map_layout'}{$b}{'bounds'}[1]

        } grep { @{ $app_display_data->{'map_layout'}{$_}{'bounds'} || [] } }
        @{ $app_display_data->{'map_order'}{$head_zone_key} };

    return unless (@sorted_map_keys);

    my $last_y
        = $app_display_data->{'map_layout'}{ $sorted_map_keys[0] }{'bounds'}
        [1];
MAP:
    foreach my $map_key (@sorted_map_keys) {
        my $map_layout   = $app_display_data->{'map_layout'}{$map_key};
        my $draw_sub_ref = $map_layout->{'shape_sub_ref'};
        if (   $overview_vis_x1_in_main_coords > $map_layout->{'bounds'}[2]
            or $overview_vis_x2_in_main_coords < $map_layout->{'bounds'}[0]
            or not $draw_sub_ref )
        {
            next MAP;
        }
        unless ( $last_y == $map_layout->{'bounds'}[1] ) {
            $zone_max_y += $map_height + $overview_layout->{'map_buffer_y'};

            $last_y = $map_layout->{'bounds'}[1];
        }

        my $o_map_x1
            = $top_pixel_factor
            * (
            $map_layout->{'bounds'}[0] - $overview_vis_x1_in_main_coords );
        my $o_map_x2
            = $top_pixel_factor
            * (
            $map_layout->{'bounds'}[2] - $overview_vis_x1_in_main_coords );

        my ( $bounds, $map_coords ) = &$draw_sub_ref(
            map_layout       => $top_overview_zone_layout->{'maps'}{$map_key},
            app_display_data => $app_display_data,
            min_x            => $o_map_x1,
            min_y            => $zone_max_y,
            max_x            => $o_map_x2,
            color            => $map_layout->{'color'},
            thickness        => $map_height,
        );

        $top_overview_zone_layout->{'maps'}{$map_key}{'changed'} = 1;
    }
    $top_overview_zone_layout->{'changed'}     = 1;
    $top_overview_zone_layout->{'sub_changed'} = 1;
    $zone_max_y += $map_height + $zone_buffer_y;

    $top_overview_zone_layout->{'bounds'}[3]
        += $zone_max_y + $overview_layout->{'map_buffer_y'};
    $top_overview_zone_layout->{'internal_bounds'}[3]
        += $zone_max_y + $overview_layout->{'map_buffer_y'};
    $overview_layout->{'internal_bounds'}[3] = $zone_max_y;
    $overview_layout->{'changed'}            = 1;
    $overview_layout->{'sub_changed'}        = 1;

    # create selected region
    overview_selected_area(
        zone_key         => $head_zone_key,
        window_key       => $window_key,
        app_display_data => $app_display_data,
    );

    return;
}

# ----------------------------------------------------
sub layout_zone {

=pod

=head2 layout_zone

Lays out a zone

$new_zone_bounds only needs the first three (min_x,min_y,max_x)

=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $zone_key         = $args{'zone_key'};
    my $new_zone_bounds  = $args{'zone_bounds'};
    my $app_display_data = $args{'app_display_data'};
    my $relayout         = $args{'relayout'} || 0;
    my $move_offset_x    = $args{'move_offset_x'} || 0;
    my $move_offset_y    = $args{'move_offset_y'} || 0;
    my $force_relayout   = $args{'force_relayout'} || 0;
    my $depth            = $args{'depth'} || 0;
    my $zone_layout      = $app_display_data->{'zone_layout'}{$zone_key};
    my $zone_width;

    # Refresh the layout hash if this is the first zone to be layed out.
    unless ($depth) {
        $app_display_data->refresh_zone_visibility_hash();
    }

    # Add the zone to the layout hash letting the world know that it has been
    # layed out.
    $app_display_data->add_zone_to_zone_visibility_hash($zone_key);

    # If the zone has never been layed out, set relayout to 0
    $relayout = 0 unless ( $zone_layout->{'layed_out_once'} );

    # Store the previous bounds.  This might be useful
    my $prior_zone_bounds = $zone_layout->{'bounds'};

    if ($relayout) {

        # Relayout in the same place if no zone_bounds are given
        unless ( @{ $new_zone_bounds || [] } ) {
            $new_zone_bounds = $zone_layout->{'bounds'};
        }

        $zone_width = $new_zone_bounds->[2] - $new_zone_bounds->[0];

        # This is being layed out again
        # Meaning we can reuse some of the work that has been done.
        if ( $depth == 0 ) {

            # This is the head zone for this relayout
            # We just need to modify the x_offset
            $app_display_data->{'scaffold'}{$zone_key}{'x_offset'}
                += $move_offset_x;
        }
        else {

            # This is one of the first levels of children.
            unless ($force_relayout) {

                # Now check to see if the visibility of this slot has changed
                # If not, we can just move the zone.
                my $parent_zone_key
                    = $app_display_data->{'scaffold'}{$zone_key}
                    {'parent_zone_key'};
                my $parent_zone_layout
                    = $app_display_data->{'zone_layout'}{$parent_zone_key};
                my $new_viewable_internal_x1 = 0;
                my $new_viewable_internal_x2 = $zone_width;
                if ( $parent_zone_layout->{'viewable_internal_x1'}
                    > $new_zone_bounds->[0] )
                {
                    $new_viewable_internal_x1
                        = $zone_layout->{'internal_bounds'}[0]
                        + (   $parent_zone_layout->{'viewable_internal_x1'}
                            - $new_zone_bounds->[0] );
                }

                if ( $parent_zone_layout->{'viewable_internal_x2'}
                    < $new_zone_bounds->[2] )
                {
                    $new_viewable_internal_x2
                        = $zone_layout->{'internal_bounds'}[2]
                        - (   $new_zone_bounds->[2]
                            - $parent_zone_layout->{'viewable_internal_x1'} );
                }
                if ( $new_viewable_internal_x1
                    == $zone_layout->{'viewable_internal_x1'}
                    and $new_viewable_internal_x2
                    == $zone_layout->{'viewable_internal_x2'} )
                {

                    # Visibility hasn't changed, simpley move the zone image
                    $app_display_data->app_interface()->int_move_zone(
                        zone_key         => $zone_key,
                        window_key       => $window_key,
                        x                => $move_offset_x,
                        y                => $move_offset_y,
                        app_display_data => $app_display_data,
                    );

                    # let the program know that the child zones are visible
                    $app_display_data->add_child_zones_to_visibility_hash(
                        app_display_data => $app_display_data,
                        zone_key         => $zone_key,
                    );
                    return 0;
                }
            }

            # Redefine the location in the parent zone
            $zone_layout->{'bounds'} = [
                $new_zone_bounds->[0], $new_zone_bounds->[1],
                $new_zone_bounds->[2], $new_zone_bounds->[1],
            ];

        }
    }
    else {

        # Initialize bounds to the bounds of the window
        # starting at the lowest point available.
        # But have a height of 0.
        $zone_layout->{'bounds'} = [
            $new_zone_bounds->[0], $new_zone_bounds->[1],
            $new_zone_bounds->[2], $new_zone_bounds->[1],
        ];
        $zone_layout->{'internal_bounds'} = [ 0, 0, 0, 0, ];
        $zone_width = $new_zone_bounds->[2] - $new_zone_bounds->[0] + 1;
        unless ( $app_display_data->{'scaffold'}{$zone_key}{'is_top'} ) {

            # Make room for border if it is possible to have one.
            $zone_layout->{'bounds'}[3]
                += ZONE_SEPARATOR_HEIGHT + SMALL_BUFFER;
        }
        unless (
            $app_display_data->{'scaffold'}{$zone_key}{'attached_to_parent'} )
        {

            # Make room for location bar if it is possible to have one.
            #$zone_layout->{'bounds'}[1]
            #+= ZONE_LOCATION_BAR_HEIGHT + SMALL_BUFFER;
            #$zone_layout->{'bounds'}[3]
            #+= ZONE_LOCATION_BAR_HEIGHT + SMALL_BUFFER;

        }
    }

    my $zone_height_change = 0;
    if ( $app_display_data->{'scaffold'}{$zone_key}{'is_top'} ) {

        # These maps are "head" maps
        $zone_height_change = layout_head_maps(
            window_key       => $window_key,
            zone_key         => $zone_key,
            zone_width       => $zone_width,
            app_display_data => $app_display_data,
            relayout         => $relayout,
            move_offset_x    => $move_offset_x,
            move_offset_y    => $move_offset_y,
            force_relayout   => $force_relayout,
            depth            => $depth,
        );
    }
    else {

        # These maps are features of the parent map
        $zone_height_change = layout_sub_maps(
            window_key       => $window_key,
            zone_key         => $zone_key,
            zone_width       => $zone_width,
            app_display_data => $app_display_data,
            relayout         => $relayout,
            move_offset_x    => $move_offset_x,
            move_offset_y    => $move_offset_y,
            force_relayout   => $force_relayout,
            depth            => $depth,
        );
    }
    unless ( $app_display_data->{'scaffold'}{$zone_key}{'attached_to_parent'}
        or $app_display_data->{'scaffold'}{$zone_key}{'is_top'} )
    {

        # BF THIS NEEDS TO HANDLE RELAYOUTS
        add_zone_separator( zone_layout => $zone_layout, );
    }

    $zone_layout->{'changed'}        = 1;
    $zone_layout->{'sub_changed'}    = 1;
    $zone_layout->{'layed_out_once'} = 1;

    return $zone_height_change;
}

# ----------------------------------------------------
sub layout_head_maps {

=pod

=head2 layout_head_maps

Lays out head maps in a zone

=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $zone_key         = $args{'zone_key'};
    my $zone_width       = $args{'zone_width'};
    my $app_display_data = $args{'app_display_data'};
    my $relayout         = $args{'relayout'} || 0;
    my $move_offset_x    = $args{'move_offset_x'} || 0;
    my $move_offset_y    = $args{'move_offset_y'} || 0;
    my $force_relayout   = $args{'force_relayout'} || 0;
    my $depth            = $args{'depth'} || 0;
    my $zone_layout      = $app_display_data->{'zone_layout'}{$zone_key};

    my $map_labels_visible = $app_display_data->map_labels_visible($zone_key);

    #  Options that should be defined elsewhere
    my $stacked = 0;

    my $x_offset = $app_display_data->{'scaffold'}{$zone_key}{'x_offset'}
        || 0;

    if ( !$relayout ) {
        $zone_layout->{'internal_bounds'} = [ 0, 0, $zone_width - 1, 0, ];
    }
    else {
        $zone_layout->{'internal_bounds'}[2] = $zone_width - 1;
    }

    # Set the viewable space by using the window
    # Save the last vieable to help with scrolling
    my $window_layout = $app_display_data->{'window_layout'}{$window_key};
    $zone_layout->{'last_viewable_internal_x1'}
        = $zone_layout->{'viewable_internal_x1'};
    $zone_layout->{'last_viewable_internal_x2'}
        = $zone_layout->{'viewable_internal_x2'};
    $zone_layout->{'viewable_internal_x1'} = -1 * $x_offset;
    $zone_layout->{'viewable_internal_x2'} = $zone_width - $x_offset;
    if ( $zone_layout->{'viewable_internal_x1'}
        < $window_layout->{'bounds'}[0] - $x_offset )
    {
        $zone_layout->{'viewable_internal_x1'}
            = $window_layout->{'bounds'}[0] - $x_offset;
    }
    if ( $zone_layout->{'viewable_internal_x2'}
        > $window_layout->{'bounds'}[2] - $x_offset )
    {
        $zone_layout->{'viewable_internal_x2'}
            = $window_layout->{'bounds'}[2] - $x_offset;
    }

    # The left and right bound limit where the maps get layed out to.
    my $left_bound        = 0;
    my $right_bound       = $zone_width - MAP_X_BUFFER;
    my $active_zone_width = $right_bound - $left_bound;
    return 0 unless ($active_zone_width);

    # Get map data for the zone
    my @ordered_map_ids
        = map { $app_display_data->map_key_to_id($_) }
        @{ $app_display_data->{'map_order'}{$zone_key} || [] }
        or return 0;
    my $map_data_hash = $app_display_data->app_data_module()
        ->map_data_hash( map_ids => \@ordered_map_ids, );

    # While we have the map data, make sure we have the map set id
    unless ( $app_display_data->{'scaffold'}{$zone_key}{'map_set_id'} ) {
        my $map_set_id
            = $map_data_hash->{ $ordered_map_ids[0] }{'map_set_id'};
        $app_display_data->{'scaffold'}{$zone_key}{'map_set_id'}
            = $map_set_id;
    }

    # Set the background color
    $app_display_data->zone_bgcolor( zone_key => $zone_key, );

    my $map_type_acc
        = $map_data_hash->{ $ordered_map_ids[0] }{'map_type_acc'};
    my $unit_granularity = $app_display_data->unit_granularity($map_type_acc);
    my $map_units
        = $app_display_data->map_type_data( $map_type_acc, 'map_units' )
        || '';

    # Get the ppu, this is important because it essentially defines the zoom
    # level.
    my $pixels_per_unit = _pixels_per_map_unit(
        map_data_hash    => $map_data_hash,
        ordered_map_ids  => \@ordered_map_ids,
        zone_width       => $active_zone_width,
        zone_key         => $zone_key,
        stacked          => $stacked,
        app_display_data => $app_display_data,
        unit_granularity => $unit_granularity,
    );

    my $map_min_x = $left_bound;
    my $row_min_y = MAP_Y_BUFFER;
    my $row_index = 0;

    # Draw the location bar
    $app_display_data->destroy_items(
        items      => $zone_layout->{'location_bar'},
        window_key => $window_key,
    );
    unless ( $app_display_data->{'scaffold'}{$zone_key}{'scale'} == 1 ) {
        my $location_bar_max_y = _layout_location_bar(
            zone_layout => $zone_layout,
            zone_width  => $zone_width,
        );
        if ( $location_bar_max_y > $row_min_y ) {
            $row_min_y = $location_bar_max_y + SMALL_BUFFER;
        }
    }

    $row_min_y = _layout_zone_scale_bar(
        window_key       => $window_key,
        zone_key         => $zone_key,
        zone_layout      => $zone_layout,
        left_bound       => $left_bound + SMALL_BUFFER,
        right_bound      => $right_bound,
        min_y            => $row_min_y,
        app_display_data => $app_display_data,
        pixels_per_unit  => $pixels_per_unit,
        map_units        => $map_units,
    );
    $row_min_y += SMALL_BUFFER;
    $row_min_y = _layout_zone_buttons(
        window_key       => $window_key,
        zone_key         => $zone_key,
        zone_layout      => $zone_layout,
        app_display_data => $app_display_data,
        left_bound       => $left_bound + SMALL_BUFFER,
        right_bound      => $right_bound,
        min_y            => $row_min_y,
        app_display_data => $app_display_data,
    );

    # The zone level maps_min_x is used for creating the overview
    $zone_layout->{'maps_min_x'} = $map_min_x;
    my $binned_maps = {};
    destroy_binned_maps_for_relayout(
        app_display_data => $app_display_data,
        zone_key         => $zone_key,
        window_key       => $window_key,
    );

    my $row_max_y = $row_min_y;
    my %label_info;
MAP:
    foreach
        my $map_key ( @{ $app_display_data->{'map_order'}{$zone_key} || [] } )
    {
        $label_info{$map_key} = $app_display_data->map_label_info(
            window_key => $window_key,
            map_key    => $map_key,
        );
        my $map_id     = $app_display_data->map_key_to_id($map_key);
        my $map_layout = $app_display_data->{'map_layout'}{$map_key};
        my $map        = $map_data_hash->{$map_id};
        my $length_in_units
            = $map->{'map_stop'} - $map->{'map_start'} + $unit_granularity;
        my $map_container_width = $length_in_units * $pixels_per_unit;
        my $show_details        = 1;
        my $draw_flipped        = $app_display_data->is_map_drawn_flipped(
            map_key  => $map_key,
            zone_key => $zone_key,
        );

        # If the map is the minimum width,
        # Set the individual ppu otherwise clear it.
        if ( $map_container_width < MIN_MAP_WIDTH ) {
            $binned_maps->{'total_size'} += $map_container_width;
            push @{ $binned_maps->{'maps'} },
                { map_key => $map_key, map_id => $map_id, };
            $app_display_data->{'map_pixels_per_unit'}{$map_key}
                = MIN_MAP_WIDTH / $length_in_units;

            # If it breaks the width threshold, lay out all the bins
            if ( $binned_maps->{'total_size'} >= MIN_MAP_WIDTH ) {
                my $token_map_id   = $binned_maps->{'maps'}[0]{'map_id'};
                my $token_map_data = $map_data_hash->{$token_map_id};
                ( $row_max_y, $map_min_x, $binned_maps, )
                    = _layout_binned_maps(
                    app_display_data => $app_display_data,
                    window_key       => $window_key,
                    zone_key         => $zone_key,
                    binned_maps      => $binned_maps,
                    token_map_data   => $token_map_data,
                    row_max_y        => $row_max_y,
                    min_y            => $row_min_y,
                    min_x            => $map_min_x,
                    max_x            => $map_min_x + MIN_MAP_WIDTH,
                    label            => $label_info{$map_key},
                    );
            }
            next MAP;
        }
        elsif ( $app_display_data->{'map_pixels_per_unit'}{$map_key} ) {
            delete $app_display_data->{'map_pixels_per_unit'}{$map_key};
        }

        # This new map is being layed out, clear the last bin if needed
        if ( %{ $binned_maps || {} }
            and my $token_map_id = $binned_maps->{'maps'}[0]{'map_id'} )
        {
            my $token_map_data = $map_data_hash->{$token_map_id};
            ( $row_max_y, $map_min_x, $binned_maps, ) = _layout_binned_maps(
                app_display_data => $app_display_data,
                window_key       => $window_key,
                zone_key         => $zone_key,
                binned_maps      => $binned_maps,
                token_map_data   => $token_map_data,
                row_max_y        => $row_max_y,
                min_y            => $row_min_y,
                min_x            => $map_min_x,
                max_x            => $map_min_x + MIN_MAP_WIDTH,
                label => $label_info{ $binned_maps->{'maps'}[0]{'map_key'} },
            );
        }

        # Clip off the map_container width to the last pixel.
        $map_container_width = int($map_container_width);
        if ( $map_container_width < MIN_MAP_DETAIL_WIDTH ) {
            $show_details = 0;
        }
        $map_layout->{'show_details'} = $show_details;

        if ($show_details) {

            # Since the map has passed the size threshold, add sub maps.
            $app_display_data->add_sub_maps_to_map(
                window_key      => $window_key,
                parent_zone_key => $zone_key,
                parent_map_key  => $map_key,
            );

            # Add buffer on the left
            $map_min_x += MAP_X_BUFFER;
        }

        my $map_pixels_per_unit
            = $app_display_data->{'map_pixels_per_unit'}{$map_key}
            || $pixels_per_unit;

        if ( $stacked and $map_min_x != $left_bound ) {
            $map_min_x = $left_bound;
            $row_min_y = $row_max_y + MAP_Y_BUFFER;
            $row_index++;
        }
        my $map_max_x = $map_min_x + $map_container_width;

        # Set bounds so overview can access it later even if it
        # isn't on the screen.
        $map_layout->{'bounds'}[0] = $map_min_x;
        $map_layout->{'bounds'}[1] = $row_min_y;
        $map_layout->{'bounds'}[2] = $map_max_x;

        # Set the shape of the map
        # Do this now while we have the map data handy
        _map_shape_sub_ref(
            map_layout => $map_layout,
            map        => $map,
        );

        # The zone level maps_max_x is used for creating the overview
        if ( ( not defined $zone_layout->{'maps_max_x'} )
            or $zone_layout->{'maps_max_x'} < $map_max_x )
        {
            $zone_layout->{'maps_max_x'} = $map_max_x;
        }

        # If map is not on the screen, don't lay it out.
        my $left_of_view = ( ( $map_min_x + $map_container_width )
            < $zone_layout->{'viewable_internal_x1'} );
        my $right_of_view
            = ( $map_min_x > $zone_layout->{'viewable_internal_x2'} );
        if ( $left_of_view or $right_of_view ) {

           # The map is off to either the left or right, save that information
            if ($left_of_view) {
                $app_display_data->add_child_zones_to_visibility_hash(
                    app_display_data => $app_display_data,
                    zone_key         => $zone_key,
                    map_key          => $map_key,
                    state            => OFF_TO_THE_LEFT,
                );
            }
            elsif ($right_of_view) {
                $app_display_data->add_child_zones_to_visibility_hash(
                    app_display_data => $app_display_data,
                    zone_key         => $zone_key,
                    map_key          => $map_key,
                    state            => OFF_TO_THE_RIGHT,
                );
            }
            if ( @{ $map_layout->{'items'} || [] } ) {
                destroy_map_for_relayout(
                    app_display_data => $app_display_data,
                    map_key          => $map_key,
                    window_key       => $window_key,
                    cascade          => 1,
                );
            }
            $map_min_x += $map_container_width;
            if ($show_details) {
                $map_min_x += MAP_X_BUFFER;
            }
            else {
                $map_min_x += MAP_X_NO_DETAILS_BUFFER;
            }
            next MAP;
        }

        # Set the row index in case this zone needs to be split
        # BF this may not be needed anymore
        $map_layout->{'row_index'} = $row_index;
        my $hide_label = 0;
        if (    $map_labels_visible
            and $show_details
            and $label_info{$map_key}->{'width'} > $map_container_width )
        {
            $hide_label = 1;
        }

        # Add info to slot_info needed for creation of correspondences
        _add_to_slot_info(
            app_display_data  => $app_display_data,
            zone_key          => $zone_key,
            visible_min_bound => $zone_layout->{'viewable_internal_x1'},
            visible_max_bound => $zone_layout->{'viewable_internal_x2'},
            map_min_x         => $map_min_x,
            map_max_x         => $map_max_x,
            map_start         => $map->{'map_start'},
            map_stop          => $map->{'map_stop'},
            map_id            => $map->{'map_id'},
            x_offset          => $x_offset,
            draw_flipped      => $draw_flipped,
            pixels_per_unit   => $map_pixels_per_unit,
        );

        my $tmp_map_max_y = _layout_contained_map(
            app_display_data => $app_display_data,
            window_key       => $window_key,
            zone_key         => $zone_key,
            map_key          => $map_key,
            map              => $map,
            min_x            => $map_min_x,
            max_x            => $map_max_x,
            min_y            => $row_min_y,
            viewable_x1      => $zone_layout->{'viewable_internal_x1'},
            viewable_x2      => $zone_layout->{'viewable_internal_x2'},
            last_viewable_x1 => $zone_layout->{'last_viewable_internal_x1'},
            last_viewable_x2 => $zone_layout->{'last_viewable_internal_x2'},
            pixels_per_unit  => $map_pixels_per_unit,
            relayout         => $relayout,
            move_offset_x    => $move_offset_x,
            move_offset_y    => $move_offset_y,
            force_relayout   => $force_relayout,
            depth            => $depth,
            label            => $label_info{$map_key},
            hide_label       => $hide_label,
            draw_flipped     => $draw_flipped,
            head_map         => 1,
        );
        if ( $row_max_y < $tmp_map_max_y ) {
            $row_max_y = $tmp_map_max_y;
        }

        $map_min_x += $map_container_width;

        if ($show_details) {
            $map_min_x += MAP_X_BUFFER;
        }
        else {
            $map_min_x += MAP_X_NO_DETAILS_BUFFER;
        }
        $map_layout->{'changed'} = 1;
    }
    if ( %{ $binned_maps || {} }
        and my $token_map_id = $binned_maps->{'maps'}[0]{'map_id'} )
    {
        my $token_map_data = $map_data_hash->{$token_map_id};
        ( $row_max_y, $map_min_x, $binned_maps, ) = _layout_binned_maps(
            app_display_data => $app_display_data,
            window_key       => $window_key,
            zone_key         => $zone_key,
            binned_maps      => $binned_maps,
            token_map_data   => $token_map_data,
            row_max_y        => $row_max_y,
            min_y            => $row_min_y,
            min_x            => $map_min_x,
            max_x            => $map_min_x + MIN_MAP_WIDTH,
            label => $label_info{ $binned_maps->{'maps'}[0]{'map_key'} },
        );
    }

    my $height_change
        = $row_max_y + ZONE_Y_BUFFER - $zone_layout->{'bounds'}[3];
    $app_display_data->modify_zone_bottom_bound(
        window_key    => $window_key,
        zone_key      => $zone_key,
        bounds_change => $height_change,
    );
    if ( $depth == 0 ) {
        $app_display_data->modify_window_bottom_bound(
            window_key    => $window_key,
            bounds_change => $height_change,
        );
    }

    $zone_layout->{'sub_changed'} = 1;
    $zone_layout->{'changed'}     = 1;

    #layout_overview(
    #    window_key       => $window_key,
    #    app_display_data => $app_display_data,
    #);
    $app_display_data->recreate_overview( window_key => $window_key, );

    return $height_change;
}

# ----------------------------------------------------
sub layout_sub_maps {

=pod

=head2 layout_sub_maps

Lays out sub maps in a slot. 

=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $zone_key         = $args{'zone_key'};
    my $zone_width       = $args{'zone_width'};
    my $app_display_data = $args{'app_display_data'};
    my $relayout         = $args{'relayout'} || 0;
    my $move_offset_x    = $args{'move_offset_x'} || 0;
    my $move_offset_y    = $args{'move_offset_y'} || 0;
    my $force_relayout   = $args{'force_relayout'} || 0;
    my $depth            = $args{'depth'} || 0;
    my $zone_layout      = $app_display_data->{'zone_layout'}{$zone_key};

    # Get the parent zone info
    my $parent_zone_key
        = $app_display_data->{'scaffold'}{$zone_key}{'parent_zone_key'};
    my $parent_zone_layout
        = $app_display_data->{'zone_layout'}{$parent_zone_key};

    my $scale = $app_display_data->{'scaffold'}{$zone_key}{'scale'} || 1;
    my $x_offset = $app_display_data->{'scaffold'}{$zone_key}{'x_offset'}
        || 0;

    #my $row_min_y = MAP_Y_BUFFER;
    my $row_min_y = SMALL_BUFFER * 2;

    # Save the last vieable to help with scrolling
    $zone_layout->{'internal_bounds'} = [ 0, 0, $zone_width, 0, ];
    $zone_layout->{'last_viewable_internal_x1'}
        = $zone_layout->{'viewable_internal_x1'};
    $zone_layout->{'last_viewable_internal_x2'}
        = $zone_layout->{'viewable_internal_x2'};
    $zone_layout->{'viewable_internal_x1'} = -1 * $x_offset;
    $zone_layout->{'viewable_internal_x2'} = $zone_width - $x_offset;

    # set the viewable space by looking to see if the parent has been clipped
    if ( $parent_zone_layout->{'viewable_internal_x1'}
        > $zone_layout->{'bounds'}[0] )
    {
        $zone_layout->{'viewable_internal_x1'}
            = $zone_layout->{'internal_bounds'}[0]
            + (   $parent_zone_layout->{'viewable_internal_x1'}
                - $zone_layout->{'bounds'}[0] )
            - $x_offset;
    }
    if ( $parent_zone_layout->{'viewable_internal_x2'}
        < $zone_layout->{'bounds'}[2] )
    {
        $zone_layout->{'viewable_internal_x2'}
            = $zone_layout->{'internal_bounds'}[2]
            - (   $zone_layout->{'bounds'}[2]
                - $parent_zone_layout->{'viewable_internal_x2'} )
            - $x_offset;
    }

    # Get parent map information
    my $parent_map_key
        = $app_display_data->{'scaffold'}{$zone_key}{'parent_map_key'};
    my $parent_map_layout
        = $app_display_data->{'map_layout'}{$parent_map_key};
    my $parent_map_id = $app_display_data->map_key_to_id($parent_map_key);
    my $parent_data   = $app_display_data->app_data_module()
        ->map_data( map_id => $parent_map_id, );
    my $parent_start = $parent_data->{'map_start'};
    my $parent_pixels_per_unit
        = $app_display_data->{'map_pixels_per_unit'}{$parent_map_key}
        || $app_display_data->{'scaffold'}{$parent_zone_key}
        {'pixels_per_unit'};

    # Prepare variables for the PPU subroutine
    my %map_ids_to_map_keys
        = map { $app_display_data->map_key_to_id($_) => $_ }
        @{ $app_display_data->{'map_order'}{$zone_key} || [] }
        or return 0;
    my @map_ids       = keys %map_ids_to_map_keys;
    my $map_data_hash = $app_display_data->app_data_module()
        ->map_data_hash( map_ids => \@map_ids, );

    my $map_type_acc     = $map_data_hash->{ $map_ids[0] }{'map_type_acc'};
    my $unit_granularity = $app_display_data->unit_granularity($map_type_acc);
    my $map_units
        = $app_display_data->map_type_data( $map_type_acc, 'map_units' )
        || '';

    my $pixels_per_unit = _sub_map_pixels_per_map_unit(
        map_data_hash          => $map_data_hash,
        map_ids_to_map_keys    => \%map_ids_to_map_keys,
        zone_width             => $zone_width,
        zone_key               => $zone_key,
        app_display_data       => $app_display_data,
        unit_granularity       => $unit_granularity,
        parent_scale           => $scale,
        parent_pixels_per_unit => $parent_pixels_per_unit,
        scale                  => $scale,
    );

    $row_min_y = _layout_zone_scale_bar(
        window_key  => $window_key,
        zone_key    => $zone_key,
        zone_layout => $zone_layout,
        left_bound  => $zone_layout->{'viewable_internal_x1'} + SMALL_BUFFER,
        right_bound => $zone_layout->{'viewable_internal_x2'},
        min_y       => $row_min_y,
        app_display_data => $app_display_data,
        pixels_per_unit  => $pixels_per_unit,
        map_units        => $map_units,
    );
    $row_min_y += SMALL_BUFFER;
    $row_min_y = _layout_zone_buttons(
        window_key       => $window_key,
        zone_key         => $zone_key,
        zone_layout      => $zone_layout,
        app_display_data => $app_display_data,
        left_bound  => $zone_layout->{'viewable_internal_x1'} + SMALL_BUFFER,
        right_bound => $zone_layout->{'viewable_internal_x2'},
        min_y       => $row_min_y,
        app_display_data => $app_display_data,
    );

    $row_min_y += MAP_Y_BUFFER;
    my $row_max_y = $row_min_y;

    # Sort maps for easier layout
    my @sub_map_keys = sort {
        $app_display_data->{'sub_maps'}{$a}
            {'parent_map_key'} <=> $app_display_data->{'sub_maps'}{$b}
            {'parent_map_key'}
            || $app_display_data->{'sub_maps'}{$a}
            {'feature_start'} <=> $app_display_data->{'sub_maps'}{$b}
            {'feature_start'}
            || $app_display_data->{'sub_maps'}{$a}
            {'feature_stop'} <=> $app_display_data->{'sub_maps'}{$b}
            {'feature_stop'}
            || $a cmp $b
    } @{ $app_display_data->{'map_order'}{$zone_key} || [] };

    # If needed, get the map set id
    unless ( $app_display_data->{'scaffold'}{$zone_key}{'map_set_id'} ) {
        my $first_map_data
            = $app_display_data->app_data_module()
            ->map_data(
            map_id => $app_display_data->map_key_to_id( $sub_map_keys[0] ), );
        $app_display_data->{'scaffold'}{$zone_key}{'map_set_id'}
            = $first_map_data->{'map_set_id'};
    }

    # Set the background color
    $app_display_data->zone_bgcolor( zone_key => $zone_key, );

    my @row_distribution_array = ();
    my @rows;

    # Figure out where the parent start is in this zone's coordinate system
    my $parent_x1
        = $parent_map_layout->{'coords'}[0] - $zone_layout->{'bounds'}[0];
    my $parent_x2
        = $parent_map_layout->{'coords'}[2] - $zone_layout->{'bounds'}[0];
    my $parent_pixel_width = $parent_map_layout->{'coords'}[2]
        - $parent_map_layout->{'coords'}[0] + 1;

    my %label_info;

    # Place each map in a row
    foreach my $sub_map_key (@sub_map_keys) {
        $label_info{$sub_map_key} = $app_display_data->map_label_info(
            window_key => $window_key,
            map_key    => $sub_map_key,
        );
        my $parent_drawn_flipped = $app_display_data->is_map_drawn_flipped(
            map_key  => $parent_map_key,
            zone_key => $zone_key,
        );
        my $sub_map_id   = $app_display_data->map_key_to_id($sub_map_key);
        my $sub_map_data = $app_display_data->app_data_module()
            ->map_data( map_id => $sub_map_id, );

        # feature_start/stop refers to where the sub-map is on the parent
        my $feature_start
            = $app_display_data->{'sub_maps'}{$sub_map_key}{'feature_start'};
        my $feature_stop
            = $app_display_data->{'sub_maps'}{$sub_map_key}{'feature_stop'};

        # $x*_on_parent_map is in relation to the parent map and flipping is
        # not considered
        my $feature_x1_on_parent_map
            = ( ( $feature_start - $parent_start ) * $parent_pixels_per_unit )
            * $scale;
        my $feature_x2_on_parent_map
            = ( ( $feature_stop - $parent_start ) * $parent_pixels_per_unit )
            * $scale;
        my $center_x_on_parent_map
            = ( $feature_x1_on_parent_map + $feature_x2_on_parent_map ) / 2;

        my $map_width_in_pixels
            = (   $sub_map_data->{'map_stop'} 
                - $sub_map_data->{'map_start'}
                + $unit_granularity ) * $pixels_per_unit;

        my $x1_on_parent_map
            = $center_x_on_parent_map - int( $map_width_in_pixels / 2 + 0.5 );
        my $x2_on_parent_map
            = $center_x_on_parent_map + int( $map_width_in_pixels / 2 - 0.5 );

        my $parent_map_width = ($parent_pixel_width) * $scale;

        # Bump the map back if it is overlapping the bounds
        if ( $x1_on_parent_map < 0 ) {
            $x1_on_parent_map = 0;
            $x2_on_parent_map = $map_width_in_pixels;
        }
        elsif ( $x2_on_parent_map > $parent_map_width ) {
            $x1_on_parent_map = $parent_map_width - $map_width_in_pixels + 1;
            $x2_on_parent_map = $parent_map_width;
        }

        # Flipping is considered for $x1 and $x2
        my ( $x1, $x2 );
        if ($parent_drawn_flipped) {
            $x2 = $parent_x2 - $x1_on_parent_map;
            $x1 = $parent_x2 - $x2_on_parent_map;
        }
        else {
            $x1 = $parent_x1 + $x1_on_parent_map;
            $x2 = $parent_x1 + $x2_on_parent_map;
        }

        if ( $app_display_data->map_labels_visible($zone_key) ) {

            # Check if the label goes past the end of the map
            my $label_x2
                = $x1_on_parent_map + $label_info{$sub_map_key}->{'width'};
            $label_x2 = $parent_map_width
                if ( $label_x2 > $parent_map_width );
            $x2_on_parent_map = $label_x2
                if ( $label_x2 > $x2_on_parent_map );
        }

        my $row_index = simple_column_distribution(
            low        => $x1_on_parent_map,
            high       => $x2_on_parent_map,
            columns    => \@row_distribution_array,
            map_height => $parent_map_width,          # actually width
            buffer     => MAP_X_BUFFER,
        );

        # BF DO I NEED TO STORE THIS?
        # Set the row index in case this zone needs to be split
        $app_display_data->{'map_layout'}{$sub_map_key}{'row_index'}
            = $row_index;

        push @{ $rows[$row_index] }, [ $sub_map_key, $x1, $x2, ];
    }

    my $map_pixels_per_unit;

    # Layout each row of maps
    foreach my $row (@rows) {
        foreach my $row_sub_map ( @{ $row || [] } ) {
            my $sub_map_key  = $row_sub_map->[0];
            my $x1           = $row_sub_map->[1];
            my $x2           = $row_sub_map->[2];
            my $sub_map_id   = $app_display_data->map_key_to_id($sub_map_key);
            my $sub_map_data = $app_display_data->app_data_module()
                ->map_data( map_id => $sub_map_id, );

            my $draw_flipped = $app_display_data->is_map_drawn_flipped(
                map_key  => $sub_map_key,
                zone_key => $zone_key,
            );

            # Set map_pixels_per_unit
            $map_pixels_per_unit
                = $app_display_data->{'map_pixels_per_unit'}{$sub_map_key}
                = ( $x2 - $x1 + 1 ) /
                (
                $sub_map_data->{'map_stop'} - $sub_map_data->{'map_start'} );

            # Set bounds so overview can access it later even if it
            # isn't on the screen.
            $app_display_data->{'map_layout'}{$sub_map_key}{'bounds'}[0]
                = $app_display_data->{'map_layout'}{$sub_map_key}{'coords'}[0]
                = $x1;
            $app_display_data->{'map_layout'}{$sub_map_key}{'bounds'}[1]

               #= $app_display_data->{'map_layout'}{$sub_map_key}{'coords'}[1]
                = $row_min_y;
            $app_display_data->{'map_layout'}{$sub_map_key}{'bounds'}[2]
                = $app_display_data->{'map_layout'}{$sub_map_key}{'coords'}[2]
                = $x2;

            # Set the shape of the map
            # Do this now while we have the map data handy
            _map_shape_sub_ref(
                map_layout => $app_display_data->{'map_layout'}{$sub_map_key},
                map        => $sub_map_data,
            );

            # The zone level maps_min_x is used for creating the overview
            if ( ( not defined $zone_layout->{'maps_min_x'} )
                or $zone_layout->{'maps_min_x'} > $x1 )
            {
                $zone_layout->{'maps_min_x'} = $x1;
            }

            # The zone level maps_max_x is used for creating the overview
            if ( ( not defined $zone_layout->{'maps_max_x'} )
                or $zone_layout->{'maps_max_x'} < $x2 )
            {
                $zone_layout->{'maps_max_x'} = $x2;
            }

            # If map is not on the screen, don't lay it out.
            my $left_of_view
                = ( $x2 < $zone_layout->{'viewable_internal_x1'} );
            my $right_of_view
                = ( $x1 > $zone_layout->{'viewable_internal_x2'} );
            if ( $left_of_view or $right_of_view ) {

           # The map is off to either the left or right, save that information
                if ($left_of_view) {
                    $app_display_data->add_child_zones_to_visibility_hash(
                        app_display_data => $app_display_data,
                        zone_key         => $zone_key,
                        map_key          => $sub_map_key,
                        state            => OFF_TO_THE_LEFT,
                    );
                }
                elsif ($right_of_view) {
                    $app_display_data->add_child_zones_to_visibility_hash(
                        app_display_data => $app_display_data,
                        zone_key         => $zone_key,
                        map_key          => $sub_map_key,
                        state            => OFF_TO_THE_RIGHT,
                    );
                }

                destroy_map_for_relayout(
                    app_display_data => $app_display_data,
                    map_key          => $sub_map_key,
                    window_key       => $window_key,
                    cascade          => 1,
                );
                next;
            }

            # Add info to slot_info needed for creation of correspondences
            _add_to_slot_info(
                app_display_data  => $app_display_data,
                zone_key          => $zone_key,
                visible_min_bound => $zone_layout->{'viewable_internal_x1'},
                visible_max_bound => $zone_layout->{'viewable_internal_x2'},
                map_min_x         => $x1,
                map_max_x         => $x2,
                map_start         => $sub_map_data->{'map_start'},
                map_stop          => $sub_map_data->{'map_stop'},
                map_id            => $sub_map_data->{'map_id'},
                x_offset          => $x_offset,
                draw_flipped      => $draw_flipped,
                pixels_per_unit   => $map_pixels_per_unit,
            );

            my $tmp_map_max_y = _layout_contained_map(
                app_display_data => $app_display_data,
                window_key       => $window_key,
                zone_key         => $zone_key,
                map_key          => $sub_map_key,
                map              => $sub_map_data,
                min_x            => $x1,
                max_x            => $x2,
                viewable_x1      => $zone_layout->{'viewable_internal_x1'},
                viewable_x2      => $zone_layout->{'viewable_internal_x2'},
                last_viewable_x1 =>
                    $zone_layout->{'last_viewable_internal_x1'},
                last_viewable_x2 =>
                    $zone_layout->{'last_viewable_internal_x2'},
                min_y           => $row_min_y,
                pixels_per_unit => $map_pixels_per_unit,
                relayout        => $relayout,
                move_offset_x   => $move_offset_x,
                move_offset_y   => $move_offset_y,
                force_relayout  => $force_relayout,
                depth           => $depth,
                draw_flipped    => $draw_flipped,
                label           => $label_info{$sub_map_key},
            );

            if ( $row_max_y < $tmp_map_max_y ) {
                $row_max_y = $tmp_map_max_y;
            }
            $app_display_data->{'map_layout'}{$sub_map_key}{'changed'} = 1;
        }
        $row_min_y = $row_max_y + MAP_Y_BUFFER;
    }

    my $height_change = $row_max_y + ZONE_Y_BUFFER - MAP_Y_BUFFER;
    $app_display_data->modify_zone_bottom_bound(
        window_key    => $window_key,
        zone_key      => $zone_key,
        bounds_change => $height_change,
    );
    if ( $depth == 0 ) {
        $app_display_data->modify_window_bottom_bound(
            window_key    => $window_key,
            bounds_change => $height_change,
        );
    }

    $zone_layout->{'sub_changed'} = 1;
    $zone_layout->{'changed'}     = 1;

    return $height_change;
}

# ----------------------------------------------------
sub _layout_location_bar {

=pod

=head2 _layout_location_bar

Lays out location_bar for a zone.

=cut

    my %args          = @_;
    my $zone_layout   = $args{'zone_layout'};
    my $zone_width    = $args{'zone_width'};
    my $visible_width = $zone_layout->{'viewable_internal_x2'}
        - $zone_layout->{'viewable_internal_x1'} + 1;
    my $location_bar_start = (
        (   (         $zone_layout->{'viewable_internal_x1'}
                    - $zone_layout->{'internal_bounds'}[0] + 1
            ) / ($zone_width)
        ) * $visible_width
    ) + $zone_layout->{'viewable_internal_x1'};
    my $location_bar_stop = (
        (   (         $zone_layout->{'viewable_internal_x2'}
                    - $zone_layout->{'internal_bounds'}[0] + 1
            ) / ($zone_width)
        ) * $visible_width
    ) + $zone_layout->{'viewable_internal_x1'};
    my $max_y
        = $zone_layout->{'internal_bounds'}[1] + ZONE_LOCATION_BAR_HEIGHT;
    $zone_layout->{'location_bar'} = [
        [   1, undef,
            'rectangle',
            [   $location_bar_start, $zone_layout->{'internal_bounds'}[1],
                $location_bar_stop,  $max_y,
            ],
            {   -fillcolor => 'black',
                -linecolor => 'black',
                -linewidth => 1,
                -filled    => 1
            }
        ],
    ];
    return $max_y;
}

# ----------------------------------------------------
sub _layout_zone_scale_bar {

=pod

=head2 _layout_zone_scale_bar

Lays out a scale bar for a zone.

=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'} or return;
    my $zone_key         = $args{'zone_key'} or return;
    my $zone_layout      = $args{'zone_layout'};
    my $app_display_data = $args{'app_display_data'};
    my $left_bound       = $args{'left_bound'};
    my $right_bound      = $args{'right_bound'};
    my $min_y            = $args{'min_y'};
    my $pixels_per_unit  = $args{'pixels_per_unit'} or return;
    my $map_units        = $args{'map_units'} || '';

    # Destroy the old one first
    $app_display_data->destroy_items(
        items      => $zone_layout->{'scale_bar'},
        window_key => $window_key,
    );

    my $max_y      = $min_y;
    my $zone_width = $right_bound - $left_bound + 1;

    # Try to make the bar a certain size but round it to the closest
    # signifigant figures
    my $sig_figs          = 1;
    my $optimal_bar_width = 100;
    my $optimal_bar_units
        = int( 0.5 + $optimal_bar_width / $pixels_per_unit );

    # Do the math to figure out how much needs to be rounded off
    my $digits = int( log( abs($optimal_bar_units) ) / log(10) ) + 1;
    my $places_to_remove = $digits - $sig_figs;
    my $bar_units = int( $optimal_bar_units / 10**($places_to_remove) + .5 )
        * 10**($places_to_remove);
    my $bar_width = $bar_units * $pixels_per_unit;

    my $bar_height = 4;

    return $max_y if ( $zone_width < $bar_width );

    $max_y += $bar_height;
    my $bar_x1 = $left_bound;
    my $bar_x2 = $left_bound + $bar_width;
    my $text_x = $bar_x2 + SMALL_BUFFER;
    my $mid_y  = ( $max_y + $min_y ) / 2;

    $zone_layout->{'scale_bar'} = [

        #[   1, undef,
        #    'rectangle',
        #    [ $left_bound, $min_y, $bar_x2, $max_y, ],
        #    {   -fillcolor => 'black',
        #        -linecolor => 'black',
        #        -linewidth => 1,
        #        -filled    => 1
        #    }
        #],
        # Left vertical bar
        [   1, undef, 'curve',
            [ $left_bound, $min_y, $left_bound, $max_y, ],
            {   -fillcolor => 'black',
                -linecolor => 'black',
                -linewidth => 1,
                -filled    => 1
            }
        ],

        # Main line
        [   1, undef, 'curve',
            [ $left_bound, $mid_y, $bar_x2, $mid_y, ],
            {   -fillcolor => 'black',
                -linecolor => 'black',
                -linewidth => 1,
                -filled    => 1
            }
        ],

        # Right vertical bar
        [   1, undef, 'curve',
            [ $bar_x2, $min_y, $bar_x2, $max_y, ],
            {   -fillcolor => 'black',
                -linecolor => 'black',
                -linewidth => 1,
                -filled    => 1
            }
        ],
        [   1, undef, 'text',
            [ $text_x, $min_y, ],
            {   -text   => $bar_units . ' ' . $map_units,
                -anchor => 'nw',
                -color  => 'black',
            }
        ],
    ];

    return $max_y;
}

# ----------------------------------------------------
sub _layout_zone_buttons {

=pod

=head2 _layout_zone_buttons 

Lays out buttons for a zone

=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'} or return;
    my $zone_key         = $args{'zone_key'} or return;
    my $zone_layout      = $args{'zone_layout'};
    my $left_bound       = $args{'left_bound'};
    my $right_bound      = $args{'right_bound'};
    my $min_y            = $args{'min_y'};
    my $app_display_data = $args{'app_display_data'};

    # Destroy the old one first
    foreach my $button ( @{ $zone_layout->{'buttons'} || [] } ) {
        $app_display_data->destroy_items(
            items      => $button->{'items'},
            window_key => $window_key,
        );
    }
    $zone_layout->{'buttons'} = [];

    my $max_y      = $min_y;
    my $zone_width = $right_bound - $left_bound + 1;

    my @button_info_list = (
        [ 'button_display_features', 'F' ],
        [ 'button_display_labels',   'D' ],
        [ 'button_display_corrs',    'C' ],
        [ 'button_popup_menu',       'M' ],
    );
    my $button_text_buffer = 3;

    # Figure out if the buttons are going to fit.
    my $total_width = 0;
    foreach my $button_info (@button_info_list) {
        my $button_text = $button_info->[1];

        my ( $width, $height )
            = $app_display_data->app_interface()->text_dimensions(
            window_key => $window_key,
            text       => $button_text,
            );
        $button_info->[2] = $width;
        $button_info->[3] = $height;
        $total_width += ( $button_text_buffer * 2 ) + $width + SMALL_BUFFER;
    }
    return $max_y if ( $zone_width < $total_width );

    my $max_x = $left_bound;

    my ( $button_x1, $button_x2, $button_y1, $button_y2, );

    #my $feature_visible = $app_display_data->features_visible($zone_key)
    my ( $char_width, $char_height );
    foreach my $button_info (@button_info_list) {
        my $button_name = $button_info->[0];
        my $button_text = $button_info->[1];
        $char_width  = $button_info->[2];
        $char_height = $button_info->[3];

        $button_x1 = $max_x;
        $button_x2 = $max_x + $char_width + ( $button_text_buffer * 2 );
        $button_y1 = $max_y;
        $button_y2 = $max_y + $char_height + ( $button_text_buffer * 2 );
        push @{ $zone_layout->{'buttons'} },
            {
            button_name => $button_name,
            items       => [
                [   1, undef,
                    'rectangle',
                    [ $button_x1, $button_y1, $button_x2, $button_y2 ],
                    {   -fillcolor => 'lightgrey',
                        -linecolor => 'black',
                        -linewidth => 1,
                        -filled    => 1
                    }
                ],
                [   1, undef, 'text',
                    [   $button_x1 + $button_text_buffer - 1,
                        $button_y1 + $button_text_buffer - 1,
                    ],
                    {   -text   => $button_text,
                        -anchor => 'nw',
                        -color  => 'black',
                    }
                ],
            ],
            };
        $max_x = $button_x2 + SMALL_BUFFER;
    }
    my $button_height = $char_height + ( $button_text_buffer * 2 );

    # End Feature Button

    $max_y += $button_height;
    return $max_y;
}

# ----------------------------------------------------
sub set_zone_bgcolor {

=pod

=head2 set_zone_bgcolor



=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $zone_key         = $args{'zone_key'};
    my $app_display_data = $args{'app_display_data'};

    my $bgcolor = $app_display_data->zone_bgcolor( zone_key => $zone_key, );
    my $border_color
        = (     $app_display_data->{'selected_zone_key'}
            and $zone_key == $app_display_data->{'selected_zone_key'} )
        ? "black"
        : $bgcolor;

    my $background_id
        = defined(
        $app_display_data->{'zone_layout'}{$zone_key}{'background'} )
        ? $app_display_data->{'zone_layout'}{$zone_key}{'background'}[0][1]
        : undef;
    my $zone_layout = $app_display_data->{'zone_layout'}{$zone_key};
    $app_display_data->{'zone_layout'}{$zone_key}{'background'} = [
        [   1,
            $background_id,
            'rectangle',
            [   @{  $app_display_data->{'zone_layout'}{$zone_key}
                        {'internal_bounds'}
                    }
            ],
            {   -fillcolor => $bgcolor,
                -linecolor => $border_color,
                -linewidth => 3,
                -filled    => 1
            }
        ]
    ];

    $app_display_data->{'zone_layout'}{$zone_key}{'changed'}         = 1;
    $app_display_data->{'window_layout'}{$window_key}{'sub_changed'} = 1;

    return;
}

# ----------------------------------------------------
sub add_zone_separator {

=pod

=head2 add_zone_separator

When this method is used again, it'll have to be revisited.

Lays out reference maps in a new zone

=cut

    my %args        = @_;
    my $zone_layout = $args{'zone_layout'};

    my $border_x1 = $zone_layout->{'bounds'}[0];
    my $border_y1 = $zone_layout->{'bounds'}[1];
    my $border_x2 = $zone_layout->{'bounds'}[2];
    $zone_layout->{'separator'} = [
        [   1, undef,
            'rectangle',
            [   $border_x1, $border_y1,
                $border_x2, $border_y1 + ZONE_SEPARATOR_HEIGHT
            ],
            { -fillcolor => 'black', }
        ]
    ];
}

# ----------------------------------------------------
sub _layout_contained_map {

=pod

=head2 _layout_contained_map

Lays out a maps in a contained area.

=cut

    my %args               = @_;
    my $app_display_data   = $args{'app_display_data'};
    my $window_key         = $args{'window_key'};
    my $zone_key           = $args{'zone_key'};
    my $map_key            = $args{'map_key'};
    my $map                = $args{'map'};
    my $min_x              = $args{'min_x'};
    my $max_x              = $args{'max_x'};
    my $min_y              = $args{'min_y'};
    my $viewable_x1        = $args{'viewable_x1'};
    my $viewable_x2        = $args{'viewable_x2'};
    my $last_viewable_x1   = $args{'last_viewable_x1'};
    my $last_viewable_x2   = $args{'last_viewable_x2'};
    my $pixels_per_unit    = $args{'pixels_per_unit'};
    my $relayout           = $args{'relayout'} || 0;
    my $move_offset_x      = $args{'move_offset_x'} || 0;
    my $move_offset_y      = $args{'move_offset_y'} || 0;
    my $force_relayout     = $args{'force_relayout'} || 0;
    my $depth              = $args{'depth'} || 0;
    my $label              = $args{'label'};
    my $hide_label         = $args{'hide_label'} || 0;
    my $head_map           = $args{'head_map'} || 0;
    my $font_height        = $label->{'height'};
    my $draw_flipped       = $args{'draw_flipped'};
    my $map_labels_visible = $app_display_data->map_labels_visible($zone_key);

    my $map_layout = $app_display_data->{'map_layout'}{$map_key};

# BF DEBUG
# return $min_y unless ( $map->{'map_id'} == 2898 or $zone_key == 1 or $map->{'map_id'} == 2870 );

    # Just move if the map has already been laid out based on the $relayout
    # value and whether it has any drawing items.
    if ( $relayout and @{ $map_layout->{'items'} || [] } ) {

        # Check if we just need to move the map
        # If the viewable region is the same and we aren't force_relayout
        # simply move the map
        my $viewable_x1_location_on_map = ( $viewable_x1 < $min_x )
            ? -1    # Before Map
            : ( $viewable_x1 > $max_x ) ? -2                       # After Map
            :                             $viewable_x1 - $min_x;
        my $viewable_x2_location_on_map = ( $viewable_x2 < $min_x )
            ? -1    # Before Map
            : ( $viewable_x2 > $max_x ) ? -2                       # After Map
            :                             $viewable_x2 - $min_x;
        my $last_viewable_x1_location_on_map
            = ( not defined $last_viewable_x1 )
            ? undef
            : ( $last_viewable_x1 < $min_x ) ? -1    # Before Map
            : ( $last_viewable_x1 > $max_x ) ? -2    # After Map
            :                                  $last_viewable_x1 - $min_x;
        my $last_viewable_x2_location_on_map
            = ( not defined $last_viewable_x2 )
            ? undef
            : ( $last_viewable_x2 < $min_x ) ? -1    # Before Map
            : ( $last_viewable_x2 > $max_x ) ? -2    # After Map
            :                                  $last_viewable_x2 - $min_x;

       # I haven't been able to figure out why but simply moving maps seems to
       # cause problems with the sub zones.  The sub zones move fine until
       # they get redrawn then they move over too much.  So until, I can
       # figure that out, I'm setting $force_relayout to 1.
        $force_relayout = 1;

        if (    !$force_relayout
            and defined($last_viewable_x1_location_on_map)
            and defined($last_viewable_x2_location_on_map)
            and @{ $map_layout->{'bounds'} || [] }
            and ( $last_viewable_x1_location_on_map
                == $viewable_x1_location_on_map )
            and ( $last_viewable_x2_location_on_map
                == $viewable_x2_location_on_map )
            )
        {
            my $app_interface = $app_display_data->app_interface();
            move_map(
                app_display_data => $app_display_data,
                app_interface    => $app_interface,
                map_key          => $map_key,
                zone_key         => $zone_key,
                window_key       => $window_key,
                x                => $move_offset_x,
                y                => $move_offset_y,
            );
            $app_display_data->add_child_zones_to_visibility_hash(
                app_display_data => $app_display_data,
                zone_key         => $zone_key,
                map_key          => $map_key,
            );

            # return the lowest point for this map
            return $map_layout->{'bounds'}[3];
        }
        else {
            destroy_map_for_relayout(
                app_display_data => $app_display_data,
                map_key          => $map_key,
                window_key       => $window_key,
            );
        }
    }
    $map_layout->{'bounds'} = [ $min_x, $min_y, $max_x, $min_y ];
    $map_layout->{'coords'} = [ $min_x, $min_y, $max_x, $min_y ];

    my $max_y;

    # Work out truncation
    # 0: No Truncation
    # 1: Left Truncated
    # 2: Right Truncated
    # 3: Both Sides Truncated
    my $truncated = 0;

    # Draw label if there is supposed to be one.
    if (    $map_labels_visible
        and $map_layout->{'show_details'}
        and !$hide_label )
    {
        push @{ $map_layout->{'items'} },
            (
            [   1, undef, 'text',
                [   ( $min_x > $viewable_x1 + MAP_X_BUFFER ) ? $min_x
                    : ( $viewable_x1 + MAP_X_BUFFER + $label->{'width'}
                            > $max_x ) ? $max_x - $label->{'width'}
                    : $viewable_x1 + MAP_X_BUFFER,
                    $min_y
                ],
                {   -text   => $label->{'text'},
                    -anchor => 'nw',
                    -color  => 'black',
                }
            ]
            );
        $min_y += $label->{'height'} * 1.5;
    }
    elsif ( $hide_label or $head_map ) {
        $min_y += $label->{'height'} * 1.5;
    }

    # set the color of the map
    my $color = $map->{'color'}
        || $map->{'default_color'}
        || $app_display_data->config_data('map_color')
        || $map_layout->{'color'};
    $map_layout->{'color'} = $color;

    # Is map in highlight list?
    if ($app_display_data->is_highlighted(
            window_key => $window_key,
            map_name   => $map->{'map_name'},
        )
        )
    {
        $color = 'yellow';
    }

    # set the thickness of the map
    my $thickness = $map->{'width'}
        || $map->{'default_width'}
        || $app_display_data->config_data('map_width');
    $map_layout->{'thickness'} = $thickness;

    # Get the shape of the map
    my $draw_sub_ref = _map_shape_sub_ref( map_layout => $map_layout, );

    my ( $bounds, $map_coords ) = &$draw_sub_ref(
        map_layout       => $map_layout,
        app_display_data => $app_display_data,
        min_x            => int $min_x,
        min_y            => int $min_y,
        max_x            => int $max_x,
        color            => $color,
        thickness        => $thickness,
        truncated        => $truncated,
    );

    $map_layout->{'coords'}[1] = $map_coords->[1];
    $map_layout->{'coords'}[3] = $map_coords->[3];

    if (    0
        and not( $min_x > $viewable_x1 and $max_x < $viewable_x2 )
        and $map_layout->{'show_details'}

        #and $map_labels_visible
        )
    {

        # Unit tick marks
        my $tick_overhang = 8;
        _add_tick_marks(
            map              => $map,
            map_layout       => $map_layout,
            zone_key         => $zone_key,
            map_coords       => $map_coords,
            label_y          => $min_y - $font_height,
            label_x          => $min_x,
            viewable_x1      => $viewable_x1,
            viewable_x2      => $viewable_x2,
            app_display_data => $app_display_data,
            draw_flipped     => $draw_flipped,
        );
    }

    $min_y = $max_y = $map_coords->[3];

    if (    $app_display_data->features_visible($zone_key)
        and $map_layout->{'show_details'} )
    {
        $max_y = _layout_features(
            app_display_data => $app_display_data,
            window_key       => $window_key,
            zone_key         => $zone_key,
            map_key          => $map_key,
            map              => $map,
            min_x            => $min_x,
            max_x            => $max_x,
            min_y            => $min_y,
            viewable_x1      => $viewable_x1,
            viewable_x2      => $viewable_x2,
            pixels_per_unit  => $pixels_per_unit,
            draw_flipped     => $draw_flipped,
        );
    }
    if ( $map_layout->{'show_details'} ) {
        foreach my $child_zone_key (
            $app_display_data->get_children_zones_of_map(
                map_key  => $map_key,
                zone_key => $zone_key,
            )
            )
        {
            my $zone_bounds
                = [ $min_x, $max_y + BETWEEN_ZONE_BUFFER, $max_x, ];

          # The x and y offsets are not needed in the next zone since the zone
          # has it's own coordinate system.
            layout_zone(
                window_key       => $window_key,
                zone_key         => $child_zone_key,
                zone_bounds      => $zone_bounds,
                app_display_data => $app_display_data,
                relayout         => $relayout,
                move_offset_x    => $move_offset_x,
                move_offset_y    => $move_offset_y,
                force_relayout   => $force_relayout,
                depth            => $depth + 1,
            );
            $max_y
                += $app_display_data->{'zone_layout'}{$child_zone_key}
                {'bounds'}[3]
                - $app_display_data->{'zone_layout'}{$child_zone_key}
                {'bounds'}[1];
        }
    }
    $map_layout->{'bounds'}[3] = $max_y;

    $map_layout->{'sub_changed'} = 1;

    return $max_y;
}

# ----------------------------------------------------
sub _layout_binned_maps {

=pod

=head2 _layout_binned_maps

Lays out maps that are in a binned region.  This is when zoomed way out.

=cut

    my %args             = @_;
    my $app_display_data = $args{'app_display_data'};
    my $window_key       = $args{'window_key'};
    my $zone_key         = $args{'zone_key'};
    my $row_max_y        = $args{'row_max_y'};
    my $token_map_data   = $args{'token_map_data'};
    my $min_x            = $args{'min_x'};
    my $binned_maps = $args{'binned_maps'} or return ( $row_max_y, $min_x, );
    my $max_x       = $args{'max_x'};
    my $min_y       = $args{'min_y'};
    my $label       = $args{'label'};
    my $color       = $token_map_data->{'color'}
        || $token_map_data->{'default_color'}
        || $app_display_data->config_data('map_color')
        || 'black';
    my $map_labels_visible = $app_display_data->map_labels_visible($zone_key);

    return ( $row_max_y, $min_x, )
        unless ( %$binned_maps and @{ $binned_maps->{'maps'} || [] } );

    # Leave space for label if they are drawn on other maps
    if ($map_labels_visible) {
        $min_y += $label->{'height'} * 3;
    }

    my $bin_layout = {};
    my $bin_index
        = scalar @{ $app_display_data->{'zone_bin_layouts'}{$zone_key}
            || [] };
    foreach my $maps ( @{ $binned_maps->{'maps'} || [] } ) {
        my $map_key = $maps->{'map_key'};
        push @{ $bin_layout->{'map_keys'} }, $map_key;
        $app_display_data->{'map_key_to_zone_bin'}{$map_key}
            = [ $zone_key, $bin_index ];

        # remove the map drawings if this has already been drawn previously
        if ( $app_display_data->{'map_layout'}{$map_key}
            and
            @{ $app_display_data->{'map_layout'}{$map_key}{'items'} || [] } )
        {
            destroy_map_for_relayout(
                app_display_data => $app_display_data,
                map_key          => $map_key,
                window_key       => $window_key,
                cascade          => 1,
            );
        }
    }

    # One pixel for each map
    my $glyph_height = scalar( @{ $binned_maps->{'maps'} } );
    push @{ $bin_layout->{'items'} },
        (
        [   1,
            undef,
            'rectangle',
            [ $min_x, $min_y, $max_x, $min_y + $glyph_height, ],
            { -fillcolor => $color, -linecolor => $color, -filled => 1 }
        ]
        );
    $bin_layout->{'changed'} = 1;

    $app_display_data->{'zone_bin_layouts'}{$zone_key}[$bin_index]
        = $bin_layout;

    $min_x = $max_x;
    if ( $row_max_y < $min_y + $glyph_height ) {
        $row_max_y = $min_y + $glyph_height;
    }
    $binned_maps = {};

    return ( $row_max_y, $min_x, $binned_maps, );
}

# ----------------------------------------------------
sub _layout_features {

=pod

=head2 _layout_features

Lays out feautures 

=cut

    my %args             = @_;
    my $app_display_data = $args{'app_display_data'};
    my $window_key       = $args{'window_key'};
    my $zone_key         = $args{'zone_key'};
    my $map_key          = $args{'map_key'};
    my $map              = $args{'map'};
    my $min_x            = $args{'min_x'};
    my $min_y            = $args{'min_y'};
    my $max_x            = $args{'max_x'};
    my $viewable_x1      = $args{'viewable_x1'};
    my $viewable_x2      = $args{'viewable_x2'};
    my $pixels_per_unit  = $args{'pixels_per_unit'};
    my $draw_flipped     = $args{'draw_flipped'};

    my $max_y = $min_y;

    my $map_width = $max_x - $min_x + 1;

    my $feature_height = 6;
    my $feature_buffer = 2;

    my $sorted_feature_data = $app_display_data->app_data_module()
        ->sorted_feature_data( map_id => $map->{'map_id'} );

    unless ( %{ $sorted_feature_data || {} } ) {
        return $min_y;
    }

    my $glyph = Bio::GMOD::CMap::Drawer::AppGlyph->new(
        config      => $app_display_data->config(),
        data_source => $app_display_data->data_source(),
    );

    my $map_start = $map->{'map_start'};

    for my $lane ( sort { $a <=> $b } keys %$sorted_feature_data ) {
        my $lane_features = $sorted_feature_data->{$lane};
        my $lane_min_y    = $max_y + SMALL_BUFFER;
        my @fcolumns;

        foreach my $feature ( @{ $lane_features || [] } ) {
            my $feature_acc       = $feature->{'feature_acc'};
            my $feature_start     = $feature->{'feature_start'};
            my $feature_stop      = $feature->{'feature_stop'};
            my $feature_type_acc  = $feature->{'feature_type_acc'};
            my $feature_direction = $feature->{'direction'};
            my ( $x1, $x2 );

            if ($draw_flipped) {
                $x2 = $max_x
                    - ( ( $feature_start - $map_start ) * $pixels_per_unit );
                $x1 = $max_x
                    - ( ( $feature_stop - $map_start ) * $pixels_per_unit );
            }
            else {
                $x1 = $min_x
                    + ( ( $feature_start - $map_start ) * $pixels_per_unit );
                $x2 = $min_x
                    + ( ( $feature_stop - $map_start ) * $pixels_per_unit );
            }

            # Skip if not visible
            if ( $x2 < $viewable_x1 or $x1 > $viewable_x2 ) {
                next;
            }

            unless ( $app_display_data->{'map_layout'}{$map_key}{'features'}
                {$feature_acc} )
            {
                $app_display_data->{'map_layout'}{$map_key}{'features'}
                    {$feature_acc} = {};
            }

            my $column_index;
            my $feature_layout
                = $app_display_data->{'map_layout'}{$map_key}{'features'}
                {$feature_acc};

            my $feature_shape
                = $app_display_data->feature_type_data( $feature_type_acc,
                'shape' )
                || 'line';
            my $feature_glyph = $feature_shape;
            $feature_glyph =~ s/-/_/g;
            if ( $glyph->can($feature_glyph) ) {

                if ( not $glyph->allow_glyph_overlap($feature_glyph) ) {
                    my $adjusted_left  = $x1 - $min_x;
                    my $adjusted_right = $x2 - $min_x;
                    $adjusted_left = 0 if ( $adjusted_left < 0 );
                    $adjusted_right = $map_width
                        if ( $adjusted_right > $map_width );

                    $column_index = simple_column_distribution(
                        low        => $adjusted_left,
                        high       => $adjusted_right,
                        columns    => \@fcolumns,
                        map_height => $map_width,
                        buffer     => SMALL_BUFFER,
                    );
                }
                else {
                    $column_index = 0;
                }

                my $label_features = 0;

                my $offset
                    = $label_features
                    ? ($column_index)
                    * ( $feature_height + $feature_buffer + 15 )
                    : ($column_index) * ( $feature_height + $feature_buffer );
                my $y1 = $lane_min_y + $offset;

                if ($label_features) {
                    push @{ $feature_layout->{'items'} },
                        (
                        [   1, undef, 'text',
                            [ $x1, $y1 ],
                            {   -text   => $feature->{'feature_name'},
                                -anchor => 'nw',
                                -color  => 'black',
                            }
                        ]
                        );

                    $y1 += 15;
                }
                my $y2 = $y1 + $feature_height;

                my $color
                    = $app_display_data->feature_type_data( $feature_type_acc,
                    'color' )
                    || 'black';

                # Highlight features that are also sub maps
                #if ( $feature->{'sub_map_id'} ) {
                #$color = 'red';
                #}

                # Is feature in highlight list?
                if ($app_display_data->is_highlighted(
                        window_key   => $window_key,
                        feature_name => $feature->{'feature_name'},
                    )
                    )
                {
                    $color = 'yellow';
                }
                my $coords;
                ( $coords, $feature_layout->{'items'} )
                    = $glyph->$feature_glyph(
                    items            => $feature_layout->{'items'},
                    x_pos2           => $x2,
                    x_pos1           => $x1,
                    y_pos1           => $y1,
                    y_pos2           => $y2,
                    color            => $color,
                    is_flipped       => $draw_flipped,
                    direction        => $feature_direction,
                    name             => $feature->{'feature_name'},
                    app_display_data => $app_display_data,
                    feature          => $feature,
                    feature_type_acc => $feature_type_acc,
                    );

                $feature_layout->{'changed'} = 1;
                if ( $y2 > $max_y ) {
                    $max_y = $y2;
                }
            }
        }
    }

    return $max_y;
}

# ----------------------------------------------------
sub destroy_zone {

=pod

=head2 destroy_zone

Destroys the drawing items for a zone because it isn't on the screen anymore .

=cut

    my %args             = @_;
    my $app_display_data = $args{'app_display_data'};
    my $zone_key         = $args{'zone_key'};
    my $window_key       = $args{'window_key'};

    my $zone_layout = $app_display_data->{'zone_layout'}{$zone_key};

    # Remove the maps
    foreach
        my $map_key ( @{ $app_display_data->{'map_order'}{$zone_key} || [] } )
    {
        destroy_map_for_relayout(
            app_display_data => $app_display_data,
            map_key          => $map_key,
            window_key       => $window_key,
            cascade          => 1,
        );
    }

    # Remove the zone stuff
    foreach my $descriptor ( 'background', 'scale_bar', 'separator', ) {
        $app_display_data->destroy_items(
            items      => $zone_layout->{$descriptor},
            window_key => $window_key,
        );
        $zone_layout->{$descriptor} = [];
    }

    # Remove the drawn buttons
    foreach my $button ( @{ $zone_layout->{'buttons'} || [] } ) {
        $app_display_data->destroy_items(
            window_key => $window_key,
            items      => $button->{'items'},
        );
    }
    $zone_layout->{'buttons'} = [];

    return;
}

# ----------------------------------------------------
sub destroy_map_for_relayout {

=pod

=head2 destroy_map_for_relayout

Destroys the drawing items for a map so it can be drawn again.

Also, destroys the features.

=cut

    my %args             = @_;
    my $app_display_data = $args{'app_display_data'};
    my $map_key          = $args{'map_key'};
    my $window_key       = $args{'window_key'};
    my $cascade          = $args{'cascade'};

    my $map_layout = $app_display_data->{'map_layout'}{$map_key};

    # Remove the features
    foreach my $feature_acc ( keys %{ $map_layout->{'features'} || {} } ) {
        $app_display_data->destroy_items(
            items      => $map_layout->{'features'}{$feature_acc}{'items'},
            window_key => $window_key,
        );
        $map_layout->{'features'}{$feature_acc}{'items'} = [];
    }

    # Remove the map
    #$map_layout->{'bounds'} = [ 0, 0, 0, 0 ];
    #$map_layout->{'coords'} = [ 0, 0, 0, 0 ];
    $app_display_data->destroy_items(
        items      => $map_layout->{'items'},
        window_key => $window_key,
    );
    $map_layout->{'items'} = [];

    if ($cascade) {
        my $zone_key = $app_display_data->map_key_to_zone_key($map_key);

        # Crawl down the tree
        foreach my $child_zone_key (
            $app_display_data->get_children_zones_of_map(
                map_key  => $map_key,
                zone_key => $zone_key,
            )
            )
        {
            destroy_zone(
                app_display_data => $app_display_data,
                zone_key         => $child_zone_key,
                window_key       => $window_key,
            );
        }
    }

    return;
}

# ----------------------------------------------------
sub destroy_binned_maps_for_relayout {

=pod

=head2 destroy_binned_maps_for_relayout

Destroys the drawing items for a map so it can be drawn again.

Also, destroys the features.

=cut

    my %args             = @_;
    my $app_display_data = $args{'app_display_data'};
    my $zone_key         = $args{'zone_key'};
    my $window_key       = $args{'window_key'};

    my $zone_bin_layouts = $app_display_data->{'zone_bin_layouts'}{$zone_key}
        or return;
    foreach my $bin_layout ( @{ $zone_bin_layouts || [] } ) {
        $app_display_data->destroy_items(
            items      => $bin_layout->{'items'},
            window_key => $window_key,
        );
        foreach my $map ( @{ $bin_layout->{'maps'} || [] } ) {
            delete $app_display_data->{'map_key_to_zone_bin'}
                { $map->{'map_key'} };
        }
    }
    delete $app_display_data->{'zone_bin_layouts'}{$zone_key};

    return;
}

# ----------------------------------------------------
sub add_correspondences {

=pod

=head2 add_correspondences

Lays out correspondences between two zones

=cut

    my %args             = @_;
    my $app_display_data = $args{'app_display_data'};
    my $window_key       = $args{'window_key'};
    my $panel_key        = $args{'panel_key'};
    my $zone_key1        = $args{'zone_key1'};
    my $zone_key2        = $args{'zone_key2'};

    my $app_data_module = $app_display_data->app_data_module();

    ( $zone_key1, $zone_key2 ) = ( $zone_key2, $zone_key1 )
        if ( $zone_key1 > $zone_key2 );
    my $draw_offscreen_corrs = (
               $app_display_data->offscreen_corrs_visible($zone_key1)
            or $app_display_data->offscreen_corrs_visible($zone_key2)
    ) ? 1 : 0;

    # TEMPORARY - don't layout if neither end is visible
    # Put in test here
    return
        unless ( $app_display_data->is_zone_layed_out($zone_key1)
        and $app_display_data->is_zone_layed_out($zone_key2) );

    # These are to be used when drawing corr stubbs for off-screen corrs
    #my $zone1_off_screen_left =
    #    $app_display_data->is_zone_off_screen_left($zone_key1);
    #my $zone2_off_screen_left
    #    = $app_display_data->is_zone_off_screen_left($zone_key2);
    #my $zone1_off_screen_right
    #    = $app_display_data->is_zone_off_screen_right($zone_key1);
    #my $zone2_off_screen_right
    #    = $app_display_data->is_zone_off_screen_right($zone_key2);

    my $zone_layout1 = $app_display_data->{'zone_layout'}{$zone_key1};
    my $zone_layout2 = $app_display_data->{'zone_layout'}{$zone_key2};

    my $allow_intramap = 0;
    if ( $zone_key1 == $zone_key2 ) {
        $allow_intramap = 1;
    }
    my $slot_comparisons = $app_display_data->get_slot_comparisons_for_corrs(
        window_key            => $window_key,
        zone_key1             => $zone_key1,
        zone_key2             => $zone_key2,
        hide_off_screen_corrs => 1,
    );

    # Get Correspondence Data
    my $corrs
        = $app_display_data->app_data_module()
        ->zone_correspondences_using_slot_comparisons(
        slot_comparisons => $slot_comparisons, );

    # Get the zone offsets which reflect the "real" coordinates.
    my ( $zone1_x_offset, $zone1_y_offset )
        = $app_display_data->get_main_zone_offsets( zone_key => $zone_key1, );
    my ( $zone2_x_offset, $zone2_y_offset )
        = $app_display_data->get_main_zone_offsets( zone_key => $zone_key2, );

    if ( @{ $corrs || [] } ) {
        $app_display_data->{'corr_layout'}{'changed'} = 1;
    }

    my $map_data_hash = $app_display_data->app_data_module()->map_data_hash(
        map_ids => [
            (   map { $app_display_data->map_key_to_id($_) }
                    @{ $app_display_data->{'map_order'}{$zone_key1} || [] }
            ),
            (   map { $app_display_data->map_key_to_id($_) }
                    @{ $app_display_data->{'map_order'}{$zone_key2} || [] }
            ),
        ],
    );

    my %map_flipped;
    foreach my $corr ( @{ $corrs || [] } ) {
        my $map_id1     = $corr->{'map_id1'};
        my $map_id2     = $corr->{'map_id2'};
        my $feature_id1 = $corr->{'feature_id1'};
        my $feature_id2 = $corr->{'feature_id2'};

        # BF DEBUG
        # next unless($map_id2 == 2898);
        # next unless($map_id1 == 2870);
        my $map_key1 = $app_display_data->map_id_to_key_by_zone( $map_id1,
            $zone_key1 );
        my $map_key2 = $app_display_data->map_id_to_key_by_zone( $map_id2,
            $zone_key2 );
        my $map1_x1
            = $app_display_data->{'map_layout'}{$map_key1}{'bounds'}[0];
        my $map1_x2
            = $app_display_data->{'map_layout'}{$map_key1}{'bounds'}[2];
        my $map2_x1
            = $app_display_data->{'map_layout'}{$map_key2}{'bounds'}[0];
        my $map2_x2
            = $app_display_data->{'map_layout'}{$map_key2}{'bounds'}[2];

        my $map_start1 = $map_data_hash->{$map_id1}{'map_start'};
        my $map_start2 = $map_data_hash->{$map_id2}{'map_start'};

        # Set the flipped values if needed
        unless ( defined $map_flipped{$map_key1} ) {
            $map_flipped{$map_key1} = $app_display_data->is_map_drawn_flipped(
                map_key  => $map_key1,
                zone_key => $zone_key1,
            );
        }
        unless ( defined $map_flipped{$map_key2} ) {
            $map_flipped{$map_key2} = $app_display_data->is_map_drawn_flipped(
                map_key  => $map_key2,
                zone_key => $zone_key2,
            );
        }

        my ( $corr_y1, $corr_y2, $draw_downward1, $draw_downward2, );

        # Work out the y starting point for each map
        if ( $zone_key1 == $zone_key2 ) {
            $draw_downward1 = 0;
            $draw_downward2 = 0;
            $corr_y1
                = $app_display_data->{'map_layout'}{$map_key1}{'coords'}[1]
                || $app_display_data->{'map_layout'}{$map_key1}{'bounds'}[1];
            $corr_y2
                = $app_display_data->{'map_layout'}{$map_key2}{'coords'}[1]
                || $app_display_data->{'map_layout'}{$map_key1}{'bounds'}[1];
        }
        elsif ( $zone_key1 < $zone_key2 ) {
            $draw_downward1 = 1;
            $draw_downward2 = 0;
            $corr_y1
                = $app_display_data->{'map_layout'}{$map_key1}{'coords'}[3]
                || $app_display_data->{'map_layout'}{$map_key1}{'bounds'}[3];
            $corr_y2
                = $app_display_data->{'map_layout'}{$map_key2}{'coords'}[1]
                || $app_display_data->{'map_layout'}{$map_key1}{'bounds'}[1];
        }
        else {
            $draw_downward1 = 0;
            $draw_downward2 = 1;
            $corr_y1
                = $app_display_data->{'map_layout'}{$map_key1}{'coords'}[1]
                || $app_display_data->{'map_layout'}{$map_key1}{'bounds'}[1];
            $corr_y2
                = $app_display_data->{'map_layout'}{$map_key2}{'coords'}[3]
                || $app_display_data->{'map_layout'}{$map_key1}{'bounds'}[3];
        }
        my $map1_pixels_per_unit
            = $app_display_data->{'map_pixels_per_unit'}{$map_key1}
            || $app_display_data->{'scaffold'}{$zone_key1}{'pixels_per_unit'};
        my $map2_pixels_per_unit
            = $app_display_data->{'map_pixels_per_unit'}{$map_key2}
            || $app_display_data->{'scaffold'}{$zone_key2}{'pixels_per_unit'};
        my $corr_avg_x1
            = ( $corr->{'feature_start1'} + $corr->{'feature_stop1'} ) / 2;
        my $corr_avg_x2
            = ( $corr->{'feature_start2'} + $corr->{'feature_stop2'} ) / 2;

        my ( $corr_x1, $corr_x2 );
        if ( $map_flipped{$map_key1} ) {
            $corr_x1 = $map1_x2
                - ( $map1_pixels_per_unit * ( $corr_avg_x1 - $map_start1 ) );
        }
        else {
            $corr_x1 = $map1_x1
                + ( $map1_pixels_per_unit * ( $corr_avg_x1 - $map_start1 ) );
        }
        if ( $map_flipped{$map_key2} ) {
            $corr_x2 = $map2_x2
                - ( $map2_pixels_per_unit * ( $corr_avg_x2 - $map_start2 ) );
        }
        else {
            $corr_x2 = $map2_x1
                + ( $map2_pixels_per_unit * ( $corr_avg_x2 - $map_start2 ) );
        }

        $corr_x1 = int($corr_x1);
        $corr_x2 = int($corr_x2);

        my $x1_stunted = 0;
        my $x2_stunted = 0;
        if ($draw_offscreen_corrs) {
            if ( $zone_layout1->{'viewable_internal_x1'} > $corr_x1 ) {
                $corr_x1    = $zone_layout1->{'viewable_internal_x1'};
                $x1_stunted = 1;
            }
            if ( $zone_layout1->{'viewable_internal_x2'} < $corr_x1 ) {
                $corr_x1    = $zone_layout1->{'viewable_internal_x2'};
                $x1_stunted = 1;
            }
            if ( $zone_layout2->{'viewable_internal_x1'} > $corr_x2 ) {
                $corr_x2    = $zone_layout2->{'viewable_internal_x1'};
                $x2_stunted = 1;
            }
            if ( $zone_layout2->{'viewable_internal_x2'} < $corr_x2 ) {
                $corr_x2    = $zone_layout2->{'viewable_internal_x2'};
                $x2_stunted = 1;
            }

            $corr_x1 = int($corr_x1);
            $corr_x2 = int($corr_x2);

            # If neither end are on screen, we don't want to see it.
            if ( $x1_stunted and $x2_stunted ) {
                next;
            }

            # The following commented out code places the y value of the
            # stunted correspondence in between the maps rather than in line
            # with the map but I don't really like how that looks.
            #if ($x1_stunted) {
            #    $corr_y1 = int(
            #        (         $corr_y1
            #                + $zone1_y_offset
            #                + $corr_y2
            #                + $zone2_y_offset
            #        ) / 2
            #    ) - $zone1_y_offset;
            #}
            #if ($x2_stunted) {
            #   $corr_y2 = int(
            #        (         $corr_y1
            #                + $zone1_y_offset
            #                + $corr_y2
            #                + $zone2_y_offset
            #        ) / 2
            #    ) - $zone2_y_offset;
            #}
        }
        else {

            # Don't display if one of the ends isn't being displayed
            next
                if (
                (      $zone_layout1->{'viewable_internal_x1'} > $corr_x1
                    or $zone_layout1->{'viewable_internal_x2'} < $corr_x1
                )
                or (   $zone_layout2->{'viewable_internal_x1'} > $corr_x2
                    or $zone_layout2->{'viewable_internal_x2'} < $corr_x2 )
                );
        }

        unless (
            $app_display_data->{'corr_layout'}{'maps'}{$map_key1}{$map_key2} )
        {
            $app_display_data->{'corr_layout'}{'maps'}{$map_key1}{$map_key2}
                = {
                changed       => 1,
                corrs         => [],
                zone_key1     => $zone_key1,
                zone_key2     => $zone_key2,
                map_key1      => $map_key1,
                map_key2      => $map_key2,
                highlight_ids => [],
                };

            # point a reference to the corrs from each map.
            $app_display_data->{'corr_layout'}{'maps'}{$map_key2}{$map_key1}
                = $app_display_data->{'corr_layout'}{'maps'}{$map_key1}
                {$map_key2};
        }
        $app_display_data->{'corr_layout'}{'maps'}{$map_key1}{$map_key2}
            {'changed'} = 1;
        my $end_line_height = 10;
        my $x_end1          = $corr_x1 + $zone1_x_offset;
        my $y_end1          = $corr_y1 + $zone1_y_offset;
        my $x_end2          = $corr_x2 + $zone2_x_offset;
        my $y_end2          = $corr_y2 + $zone2_y_offset;
        my $x_mid1          = $x_end1;
        my $y_mid1
            = $draw_downward1
            ? $y_end1 + $end_line_height
            : $y_end1 - $end_line_height;
        my $x_mid2 = $x_end2;
        my $y_mid2
            = $draw_downward2
            ? $y_end2 + $end_line_height
            : $y_end2 - $end_line_height;
        my $x_mid3 = int( ( $x_end1 + $x_end2 ) / 2 );
        my $y_mid3 = $y_end2 - ( 4 * $end_line_height );

        my $corr_coords = [
            $x_end1, $y_end1, $x_mid1, $y_mid1,
            $x_mid2, $y_mid2, $x_end2, $y_end2,
        ];
        if ( $y_end1 == $y_end2 ) {
            $corr_coords = [
                $x_end1, $y_end1, $x_mid1, $y_mid1, $x_mid3,
                $y_mid3, $x_mid2, $y_mid2, $x_end2, $y_end2,
            ];
        }

        my $corr_color = 'red';
        if ( $x1_stunted or $x2_stunted ) {
            $corr_color = 'pink';
        }
        push @{ $app_display_data->{'corr_layout'}{'maps'}{$map_key1}
                {$map_key2}{'corrs'} },
            {
            map_key1    => $map_key1,
            map_key2    => $map_key2,
            feature_id1 => $feature_id1,
            feature_id2 => $feature_id2,
            items       => [
                [   1, undef, 'curve', $corr_coords,
                    { -linecolor => $corr_color, -linewidth => '2', }
                ],
            ],
            };
    }

    return;
}

# ----------------------------------------------------
sub _add_to_slot_info {

=pod

=head2 _add_to_slot_info

Add info to slot_info needed for creation of correspondences.  This is a data
object used in CMap.

=cut

    my %args              = @_;
    my $app_display_data  = $args{'app_display_data'};
    my $zone_key          = $args{'zone_key'};
    my $map_min_x         = $args{'map_min_x'};
    my $map_max_x         = $args{'map_max_x'};
    my $visible_min_bound = $args{'visible_min_bound'};
    my $visible_max_bound = $args{'visible_max_bound'};
    my $map_start         = $args{'map_start'};
    my $map_stop          = $args{'map_stop'};
    my $map_id            = $args{'map_id'};
    my $x_offset          = $args{'x_offset'};
    my $draw_flipped      = $args{'draw_flipped'};
    my $pixels_per_unit   = $args{'pixels_per_unit'};

    $app_display_data->{'slot_info'}{$zone_key}{$map_id}
        = [ undef, undef, $map_start, $map_stop, 1 ];

    if ($draw_flipped) {
        if ( $map_min_x < $visible_min_bound ) {
            $app_display_data->{'slot_info'}{$zone_key}{$map_id}[1]
                = $map_stop
                - ( ( $visible_min_bound - $map_min_x ) / $pixels_per_unit );
        }
        if ( $map_max_x > $visible_max_bound ) {
            $app_display_data->{'slot_info'}{$zone_key}{$map_id}[0]
                = $map_start
                + ( ( $map_max_x - $visible_max_bound ) / $pixels_per_unit );
        }
    }
    else {
        if ( $map_min_x < $visible_min_bound ) {
            $app_display_data->{'slot_info'}{$zone_key}{$map_id}[0]
                = $map_start
                + ( ( $visible_min_bound - $map_min_x ) / $pixels_per_unit );
        }
        if ( $map_max_x > $visible_max_bound ) {
            $app_display_data->{'slot_info'}{$zone_key}{$map_id}[1]
                = $map_stop
                - ( ( $map_max_x - $visible_max_bound ) / $pixels_per_unit );
        }
    }

    return;
}

# ----------------------------------------------------
sub _pixels_per_map_unit {

=pod

=head2 _pixels_per_map_unit

returns the number of pixesl per map unit. 

=cut

    my %args             = @_;
    my $map_data_hash    = $args{'map_data_hash'};
    my $ordered_map_ids  = $args{'ordered_map_ids'} || [];
    my $zone_width       = $args{'zone_width'};
    my $zone_key         = $args{'zone_key'};
    my $stacked          = $args{'stacked'};
    my $app_display_data = $args{'app_display_data'};
    my $unit_granularity = $args{'unit_granularity'};

    unless ( $app_display_data->{'scaffold'}{$zone_key}{'pixels_per_unit'} ) {
        my $pixels_per_unit = 1;
        if ($stacked) {

            # Layout maps on top of each other
            my $longest_length = 0;
            foreach my $map_id (@$ordered_map_ids) {
                my $map       = $map_data_hash->{$map_id};
                my $map_start = $map->{'map_start'};
                my $map_stop  = $map->{'map_stop'};
                my $length    = $map->{'map_stop'} - $map->{'map_start'};
                $longest_length = $length if ( $length > $longest_length );
            }
            $pixels_per_unit
                = ( $zone_width - ( 2 * MAP_X_BUFFER ) ) / $longest_length;
        }
        else {
            my %map_length;
            my $length_sum = 0;
            foreach my $map_id (@$ordered_map_ids) {
                my $map       = $map_data_hash->{$map_id};
                my $map_start = $map->{'map_start'};
                my $map_stop  = $map->{'map_stop'};
                $map_length{$map_id}
                    = $map->{'map_stop'} 
                    - $map->{'map_start'}
                    + $unit_granularity;
                $length_sum += $map_length{$map_id};
            }

            return 0 unless ($length_sum);
            my $first_pixels_per_unit = ($zone_width) / $length_sum;

            # Check this ppu to see if it how many maps are above minimum and
            # need buffers.  The buffers will be used to create the real ppu.
            my $full_buffer_count  = 0;
            my $small_buffer_count = 0;
            foreach my $map_id (@$ordered_map_ids) {
                if ( $map_length{$map_id} * $first_pixels_per_unit
                    >= MIN_MAP_DETAIL_WIDTH )
                {
                    $full_buffer_count++;
                }
                else {
                    $small_buffer_count++;
                }
            }
            my $buffer_space = ( $full_buffer_count * MAP_X_BUFFER * 2 )
                + ( $small_buffer_count * MAP_X_NO_DETAILS_BUFFER );
            $pixels_per_unit = ( $zone_width - $buffer_space ) / $length_sum;
        }
        $app_display_data->{'scaffold'}{$zone_key}{'pixels_per_unit'}
            = $pixels_per_unit;
    }

    return $app_display_data->{'scaffold'}{$zone_key}{'pixels_per_unit'};
}

# ----------------------------------------------------
sub _sub_map_pixels_per_map_unit {

=pod

=head2 _sub_map_pixels_per_map_unit

returns the number of pixesl per map unit. 

=cut

    my %args                   = @_;
    my $map_data_hash          = $args{'map_data_hash'};
    my $map_ids_to_map_keys    = $args{'map_ids_to_map_keys'};
    my $zone_width             = $args{'zone_width'};
    my $zone_key               = $args{'zone_key'};
    my $app_display_data       = $args{'app_display_data'};
    my $unit_granularity       = $args{'unit_granularity'};
    my $parent_scale           = $args{'parent_scale'};
    my $scale                  = $args{'scale'};
    my $parent_pixels_per_unit = $args{'parent_pixels_per_unit'};

    unless ( $app_display_data->{'scaffold'}{$zone_key}{'pixels_per_unit'} ) {
        my $pixels_per_unit    = 1;
        my $sum_ppu            = 0;
        my $count              = 0;
        my $longest_map_length = 0;
        foreach my $map_id ( keys %{ $map_ids_to_map_keys || {} } ) {
            my $map_key = $map_ids_to_map_keys->{$map_id};
            my $map     = $map_data_hash->{$map_id};
            my $feature_start
                = $app_display_data->{'sub_maps'}{$map_key}{'feature_start'};
            my $feature_stop
                = $app_display_data->{'sub_maps'}{$map_key}{'feature_stop'};
            my $feature_pixel_length
                = (
                ($feature_stop) * $parent_pixels_per_unit * $parent_scale )
                - (
                ($feature_start) * $parent_pixels_per_unit * $parent_scale )
                + 1;

            my $map_length
                = $map->{'map_stop'} 
                - $map->{'map_start'}
                + $unit_granularity;
            my $this_map_ppu = $feature_pixel_length / $map_length;

            $count++;
            $sum_ppu += $this_map_ppu;
            if ( $map_length > $longest_map_length ) {
                $longest_map_length = $map_length;
            }
        }

        $pixels_per_unit = $sum_ppu / $count;

        # If the longest map won't fit, then shrink the ppu
        if ( $longest_map_length * $pixels_per_unit > $zone_width - 1 ) {
            $pixels_per_unit = ( $zone_width - 1 ) / $longest_map_length;
        }

        $app_display_data->{'scaffold'}{$zone_key}{'pixels_per_unit'}
            = $pixels_per_unit;
    }

    return $app_display_data->{'scaffold'}{$zone_key}{'pixels_per_unit'}
        * $scale;
}

# ----------------------------------------------------
sub overview_selected_area {

=pod

=head2 overview_selected_area

Shows the selected region.

=cut

    my %args             = @_;
    my $zone_key         = $args{'zone_key'};
    my $window_key       = $args{'window_key'};
    my $app_display_data = $args{'app_display_data'};

    return
        if (
        $app_display_data->{'scaffold'}{$zone_key}{'attached_to_parent'} );

    # Get all of the info needed
    my $overview_layout = $app_display_data->{'overview_layout'}{$window_key};
    my $overview_zone_layout = $overview_layout->{'zones'}{$zone_key}
        or return;
    my $main_zone_layout = $app_display_data->{'zone_layout'}{$zone_key};
    my $main_offset_x
        = $app_display_data->{'scaffold'}{$zone_key}{'x_offset'};

    my $bracket_y1 = $overview_zone_layout->{'internal_bounds'}[1];
    my $bracket_y2 = $overview_zone_layout->{'internal_bounds'}[3];

    my ($scale_factor_from_main,
        $overview_vis_x1_in_main_coords,
        $overview_vis_x2_in_main_coords
        )
        = overview_scale_and_visible_regions_from_main(
        overview_zone_layout => $overview_zone_layout,
        main_zone_layout     => $main_zone_layout,
        );
    my $min_x = $main_zone_layout->{'viewable_internal_x1'};
    my $max_x = $main_zone_layout->{'viewable_internal_x2'};

    my $bracket_x1 = ( $min_x - $overview_vis_x1_in_main_coords )
        * $scale_factor_from_main;
    my $bracket_x2 = ( $max_x - $overview_vis_x1_in_main_coords )
        * $scale_factor_from_main;

    # rectangle
    push @{ $overview_zone_layout->{'viewed_region'} },
        (
        [   1, undef,
            'rectangle',
            [ ( $bracket_x1, $bracket_y1 ), ( $bracket_x2, $bracket_y2 ), ],
            {   -fillcolor => '#ffdd00',
                -linecolor => '#ff6600',
                -linewidth => 1,
                -filled    => 1
            }
        ]
        );

    $overview_layout->{'sub_changed'}  = 1;
    $overview_zone_layout->{'changed'} = 1;

}

# ----------------------------------------------------
sub move_map {

=pod

=head2 move_map

Move a map

=cut

    my %args             = @_;
    my $map_key          = $args{'map_key'};
    my $zone_key         = $args{'zone_key'};
    my $window_key       = $args{'window_key'};
    my $app_display_data = $args{'app_display_data'};
    my $app_interface    = $args{'app_interface'};
    my $x                = $args{'x'} || 0;
    my $y                = $args{'y'} || 0;

    my $map_layout = $app_display_data->{'map_layout'}{$map_key};

    move_drawing_items(
        window_key    => $window_key,
        items         => $map_layout->{'items'},
        app_interface => $app_interface,
        y             => $y,
        x             => $x,
    );

    # Move features
    foreach my $feature_acc ( keys %{ $map_layout->{'features'} || {} } ) {
        move_drawing_items(
            window_key    => $window_key,
            items         => $map_layout->{'features'}{$feature_acc}{'items'},
            app_interface => $app_interface,
            y             => $y,
            x             => $x,
        );
    }

    # Crawl down the tree
    foreach my $child_zone_key (
        $app_display_data->get_children_zones_of_map(
            map_key  => $map_key,
            zone_key => $zone_key,
        )
        )
    {

        # Move the zone image
        $app_interface->int_move_zone(
            zone_key         => $child_zone_key,
            window_key       => $window_key,
            x                => $x,
            y                => $y,
            app_display_data => $app_display_data,
        );
    }
}

# ----------------------------------------------------
sub move_drawing_items {

=pod

=head2 move_drawing_items

Move drawing_items 

=cut

    my %args          = @_;
    my $window_key    = $args{'window_key'};
    my $app_interface = $args{'app_interface'};
    my $items         = $args{'items'} or return;
    my $x             = $args{'x'} || 0;
    my $y             = $args{'y'} || 0;

    foreach my $item ( @{ $items || [] } ) {
        for ( my $i = 0; $i <= $#{ $item->[3] || [] }; $i = $i + 2 ) {
            $item->[3][$i]       += $x;
            $item->[3][ $i + 1 ] += $y;
        }
    }
    $app_interface->move_items(
        window_key => $window_key,
        items      => $items,
        y          => $y,
        x          => $x,
    );
}

# ----------------------------------------------------
sub _map_shape_sub_ref {

=pod

=head2 _map_shape_sub_ref

return a reference to the map shape subroutine

=cut

    my %args       = @_;
    my $map_layout = $args{'map_layout'};
    my $map        = $args{'map'};

    unless ( $map_layout->{'shape_sub_ref'} ) {
        if ($map) {
            $map_layout->{'shape_sub_ref'} = $SHAPE{ $map->{'shape'} }
                || $SHAPE{ $map->{'default_shape'} }
                || $SHAPE{'default'};
        }
        else {
            print STDERR
                "WARNING: Map shape not found and not map provided\n";
            return $SHAPE{'default'};
        }
    }

    return $map_layout->{'shape_sub_ref'};
}

# ----------------------------------------------------
sub _tick_mark_interval {

=pod

=head2 _tick_mark_interval

This method was copied out of Bio::GMOD::CMap::Drawer::Map but it has diverged
slightly.

Returns the map's tick mark interval.

=cut

    my $visible_map_units = shift;

    # If map length == 0, set scale to 1
    # Contributed by David Shibeci
    if ($visible_map_units) {
        my $map_scale = int( log( abs($visible_map_units) ) / log(10) );
        return ( 10**( $map_scale - 1 ), $map_scale );
    }
    else {

        # default tick_mark_interval for maps of length 0
        return ( 1, 1 );
    }

}

# ----------------------------------------------------
sub overview_scale_and_visible_regions_from_main {

=pod

=head2 overview_scale_and_visible_regions_from_main

Get the scale value between the main layout and the overview.  And get the
region that the overview will be displaying.

=cut

    my %args                 = @_;
    my $overview_zone_layout = $args{'overview_zone_layout'};
    my $main_zone_layout     = $args{'main_zone_layout'};

    my $scale_of_zoom                  = .5;
    my $pixel_scale                    = .5;
    my $overview_vis_x1_in_main_coords = 0;
    my $overview_vis_x2_in_main_coords = 0;

    my $overview_size = $overview_zone_layout->{'internal_bounds'}[2]
        - $overview_zone_layout->{'internal_bounds'}[0] + 1;
    my $main_size
        = (   $main_zone_layout->{'internal_bounds'}[2]
            - $main_zone_layout->{'internal_bounds'}[0] 
            + 1 );
    my $scale_difference = $overview_size / $main_size;
    if ( $scale_of_zoom < $scale_difference ) {

        # Overview can hold the entire thing.
        $pixel_scale = $scale_difference;
        $overview_vis_x1_in_main_coords
            = $main_zone_layout->{'internal_bounds'}[0];
        $overview_vis_x2_in_main_coords
            = $main_zone_layout->{'internal_bounds'}[2];
    }
    else {

        # Need to figure out what the overview can show.
        my $mid_viewable_main = ( $main_zone_layout->{'viewable_internal_x2'}
                + $main_zone_layout->{'viewable_internal_x1'} ) / 2;
        my $viewable_size = $main_zone_layout->{'viewable_internal_x2'}
            - $main_zone_layout->{'viewable_internal_x1'} + 1;
        my $overview_viewable_zize_in_main_coords
            = $viewable_size / $scale_of_zoom;
        $pixel_scale
            = $overview_size / $overview_viewable_zize_in_main_coords;
        my $half_viewable_for_overview
            = $overview_viewable_zize_in_main_coords / 2;
        $overview_vis_x1_in_main_coords
            = $mid_viewable_main - $half_viewable_for_overview;
        $overview_vis_x2_in_main_coords
            = $mid_viewable_main + $half_viewable_for_overview;

        if ( $overview_vis_x1_in_main_coords
            < $main_zone_layout->{'internal_bounds'}[0] )
        {
            my $offset = $main_zone_layout->{'internal_bounds'}[0]
                - $overview_vis_x1_in_main_coords;
            $overview_vis_x1_in_main_coords += $offset;
            $overview_vis_x2_in_main_coords += $offset;
        }
        elsif ( $overview_vis_x2_in_main_coords
            > $main_zone_layout->{'internal_bounds'}[2] )
        {
            my $offset = $main_zone_layout->{'internal_bounds'}[2]
                - $overview_vis_x2_in_main_coords;
            $overview_vis_x1_in_main_coords += $offset;
            $overview_vis_x2_in_main_coords += $offset;
        }
    }

    return (
        $pixel_scale,
        $overview_vis_x1_in_main_coords,
        $overview_vis_x2_in_main_coords,
    );
}

# ----------------------------------------------------
sub _add_tick_marks {

=pod

=head2 _add_tick_marks

Adds tick marks to a map.

=cut

    my %args             = @_;
    my $map              = $args{'map'};
    my $map_layout       = $args{'map_layout'};
    my $zone_key         = $args{'zone_key'};
    my $label_x          = $args{'label_x'};
    my $label_y          = $args{'label_y'};
    my $map_coords       = $args{'map_coords'};
    my $viewable_x1      = $args{'viewable_x1'};
    my $viewable_x2      = $args{'viewable_x2'};
    my $app_display_data = $args{'app_display_data'};
    my $draw_flipped     = $args{'draw_flipped'};
    my $x_offset = $app_display_data->{'scaffold'}{$zone_key}{'x_offset'}
        || 0;

    my $map_key = $app_display_data->map_id_to_key_by_zone( $map->{'map_id'},
        $zone_key );
    my $pixels_per_unit = $app_display_data->{'map_pixels_per_unit'}{$map_key}
        || $app_display_data->{'scaffold'}{$zone_key}{'pixels_per_unit'};

    my $visible_map_start
        = $app_display_data->{'slot_info'}{$zone_key}{ $map->{'map_id'} }[0];
    unless ( defined $visible_map_start ) {
        $visible_map_start
            = $app_display_data->{'slot_info'}{$zone_key}{ $map->{'map_id'} }
            [2];
    }

    my $visible_pixel_start
        = ( $viewable_x1 > $map_coords->[0] )
        ? $viewable_x1
        : $map_coords->[0];

    # BF REMOVED THE COMPLICATED STUFF SINCE COORDS WILL HAVE THE FIRST PIXEL
    #+ (
    #(   $visible_map_start - $app_display_data->{'slot_info'}{$zone_key}
    #{ $map->{'map_id'} }[2]
    #) * $pixels_per_unit
    #);

    my $visible_map_stop
        = $app_display_data->{'slot_info'}{$zone_key}{ $map->{'map_id'} }[1];
    unless ( defined $visible_map_stop ) {
        $visible_map_stop
            = $app_display_data->{'slot_info'}{$zone_key}{ $map->{'map_id'} }
            [3];
    }
    my $visible_pixel_stop
        = ( $viewable_x2 < $map_coords->[2] )
        ? $viewable_x2
        : $map_coords->[2];

    # BF REMOVED THE COMPLICATED STUFF SINCE COORDS WILL HAVE THE LAST PIXEL
    #- (
    #(   $app_display_data->{'slot_info'}{$zone_key}{ $map->{'map_id'} }[3]
    #- $visible_map_stop
    #) * $pixels_per_unit
    #);

    my $visible_map_units = $visible_map_stop - $visible_map_start;
    my ( $interval, $map_scale ) = _tick_mark_interval( $visible_map_units, );

    my $no_intervals = int( $visible_map_units / $interval );

    my $visible_pixel_width = $visible_pixel_stop - $visible_pixel_start + 1;

    my $interval_start
        = int( $visible_map_start / ( 10**( $map_scale - 1 ) ) )
        * ( 10**( $map_scale - 1 ) );
    my @intervals = map { int( $interval_start + ( $_ * $interval ) ) }
        1 .. $no_intervals;

    my $tick_overhang = 3;
    my $min_tick_distance
        = $app_display_data->config_data('min_tick_distance') || 40;
    my $last_tick_rel_pos = undef;

    my $tick_start = $map_coords->[1] - $tick_overhang;
    my $tick_stop  = $map_coords->[3];
    for my $tick_pos (@intervals) {
        my $rel_position
            = ( $tick_pos - $visible_map_start ) / $visible_map_units;

        if ((   (   ( $rel_position * $visible_pixel_width )
                    < $min_tick_distance
                )
                or (defined($last_tick_rel_pos)
                    and ( ( $rel_position * $visible_pixel_width )
                        - ( $last_tick_rel_pos * $visible_pixel_width )
                        < $min_tick_distance )
                )
            )
            )
        {
            next;
        }

        $last_tick_rel_pos = $rel_position;

        my $x_pos;
        if ($draw_flipped) {
            $x_pos
                = $visible_pixel_start
                + ( $visible_pixel_width
                    * ( $rel_position ? ( 1 - $rel_position ) : 0 ) );
        }
        else {
            $x_pos = $visible_pixel_start
                + ( $visible_pixel_width * $rel_position );
        }

        push @{ $map_layout->{'items'} },
            (
            [   1, undef, 'curve',
                [ $x_pos, $tick_start, $x_pos, $tick_stop, ],
                { -linecolor => 'black', }
            ]
            );

        #
        # Figure out how many signifigant figures the number needs by
        # going down to the $interval size.
        #
        my $sig_figs
            = $tick_pos
            ? int( '' . ( log( abs($tick_pos) ) / log(10) ) )
            - int( '' . ( log( abs($interval) ) / log(10) ) ) + 1
            : 1;
        my $tick_pos_str = presentable_number( $tick_pos, $sig_figs );
        my $label_x = $x_pos;  #+ ( $font_width * length($tick_pos_str) ) / 2;

        push @{ $map_layout->{'items'} },
            (
            [   1, undef, 'text',
                [ $label_x, $label_y ],
                {   -text   => $tick_pos_str,
                    -anchor => 'nw',
                    -color  => 'black',
                }
            ]
            );
    }
}

# ----------------------------------------------------
sub _draw_box {

=pod

=head2 _draw_box

Draws the map as a "box" (a filled-in rectangle).  Return the bounds of the
box.

=cut

    my %args             = @_;
    my $map_layout       = $args{'map_layout'};
    my $min_x            = $args{'min_x'};
    my $min_y            = $args{'min_y'};
    my $max_x            = $args{'max_x'};
    my $color            = $args{'color'};
    my $thickness        = $args{'thickness'};
    my $truncated        = $args{'truncated'} || 0;
    my $app_display_data = $args{'app_display_data'};

    my $max_y = $min_y + $thickness;
    my $mid_y = int( 0.5 + ( $min_y + $max_y ) / 2 );
    my ( $left_side_unseen, $right_side_unseen ) = ( 0, 0 );
    my @bounds = ( $min_x, $min_y, $max_x, $max_y );
    my @coords = ( $min_x, $min_y, $max_x, $max_y );
    my $truncation_arrow_width = 20;
    my $is_flipped             = 0;

    my ( $main_line_x1, $main_line_y1, $main_line_x2, $main_line_y2, )
        = ( $min_x, $min_y, $max_x, $max_y, );

    # Left Truncation Arrow
    if ((      $truncated == 3
            or ( $truncated >= 2 and $is_flipped )
            or ( $truncated == 1 and not $is_flipped )
        )
        and not $left_side_unseen
        )
    {
        push @{ $map_layout->{'items'} },
            (
            [   1, undef, 'curve',
                [   $min_x, $mid_y, $min_x + $truncation_arrow_width,
                    $max_y + 3, $min_x + $truncation_arrow_width,
                    $min_y - 3,
                ],
                {   -fillcolor => $color,
                    -linecolor => 'black',
                    -filled    => 1,
                    -closed    => 1,
                }
            ]
            );
        $main_line_x1 += $truncation_arrow_width;
    }

    # Right Truncation Arrow
    if ((      $truncated == 3
            or ( $truncated >= 2 and not $is_flipped )
            or ( $truncated == 1 and $is_flipped )
        )
        and not $right_side_unseen
        )
    {
        push @{ $map_layout->{'items'} },
            (
            [   1, undef, 'curve',
                [   $max_x, $mid_y, $max_x - $truncation_arrow_width,
                    $max_y + 3, $max_x - $truncation_arrow_width,
                    $min_y - 3,
                ],
                {   -fill    => $color,
                    -outline => 'black',
                    -filled  => 1,
                    -closed  => 1,
                }
            ]
            );
        $main_line_x2 -= $truncation_arrow_width;
    }

    # Draw the map
    push @{ $map_layout->{'items'} },
        (
        [   1,
            undef,
            'rectangle',
            [ $main_line_x1, $main_line_y1, $main_line_x2, $main_line_y2 ],
            { -fillcolor => $color, -linecolor => $color, -filled => 1 }
        ]
        );

    return ( \@bounds, \@coords );
}

# ----------------------------------------------------
sub _draw_dumbbell {

=pod

=head2 _draw_dumbbell

Draws the map as a "dumbbell" (a filled-in rectangle with balls at the end).
Return the bounds of the map.

=cut

    my %args             = @_;
    my $map_layout       = $args{'map_layout'};
    my $min_x            = $args{'min_x'};
    my $min_y            = $args{'min_y'};
    my $max_x            = $args{'max_x'};
    my $color            = $args{'color'};
    my $thickness        = $args{'thickness'};
    my $truncated        = $args{'truncated'} || 0;
    my $app_display_data = $args{'app_display_data'};

    my $circle_diameter = $thickness;
    my $max_y           = $min_y + $thickness;
    my $mid_y           = int( 0.5 + ( $min_y + $max_y ) / 2 );
    my @bounds          = ( $min_x, $min_y, $max_x, $max_y );
    my ( $left_side_unseen, $right_side_unseen ) = ( 0, 0 );
    my @coords = ( $min_x, $min_y, $max_x, $max_y );
    my $is_flipped = 0;

    my ( $main_line_x1, $main_line_y1, $main_line_x2, $main_line_y2, )
        = ( $min_x, $min_y, $max_x, $max_y, );

    # Draw Left Circle if not tuncated
    if (not $left_side_unseen
        and not( $truncated == 3
            or ( $truncated >= 2 and $is_flipped )
            or ( $truncated == 1 and not $is_flipped ) )
        )
    {
        push @{ $map_layout->{'items'} },
            (
            [   1,
                undef,
                'arc',
                [ $min_x, $min_y, $min_x + $circle_diameter, $max_y, ],
                { -fillcolor => $color, -linecolor => $color, -filled => 1, }
            ]
            );
    }

    # Draw Right Circle
    if (not $right_side_unseen
        and not( $truncated == 3
            or ( $truncated >= 2 and not $is_flipped )
            or ( $truncated == 1 and $is_flipped ) )
        )
    {
        push @{ $map_layout->{'items'} },
            (
            [   1,
                undef,
                'arc',
                [ $max_x - $circle_diameter, $min_y, $max_x, $max_y, ],
                { -fillcolor => $color, -linecolor => $color, -filled => 1, }
            ]
            );
    }

    $main_line_y1 += int( $thickness / 3 );
    $main_line_y2 -= int( $thickness / 3 );

    # Draw the map
    push @{ $map_layout->{'items'} },
        (
        [   1,
            undef,
            'rectangle',
            [ $main_line_x1, $main_line_y1, $main_line_x2, $main_line_y2 ],
            { -fillcolor => $color, -linecolor => $color, -filled => 1 }
        ]
        );

    return ( \@bounds, \@coords );
}

# ----------------------------------------------------
sub _draw_i_beam {

=pod

=head2 _draw_i_beam

Draws the map as an "i_beam" (a line with cross lines on the end).  Return the
bounds of the map.

=cut

    my %args             = @_;
    my $map_layout       = $args{'map_layout'};
    my $min_x            = $args{'min_x'};
    my $min_y            = $args{'min_y'};
    my $max_x            = $args{'max_x'};
    my $color            = $args{'color'};
    my $thickness        = $args{'thickness'};
    my $truncated        = $args{'truncated'} || 0;
    my $app_display_data = $args{'app_display_data'};
    my $is_flipped       = 0;

    my $max_y  = $min_y + $thickness;
    my $mid_y  = int( 0.5 + ( $min_y + $max_y ) / 2 );
    my @bounds = ( $min_x, $min_y, $max_x, $max_y );
    my ( $left_side_unseen, $right_side_unseen ) = ( 0, 0 );

    my @coords = ( $min_x, $min_y, $max_x, $max_y );

    my ( $main_line_x1, $main_line_y1, $main_line_x2, $main_line_y2, )
        = ( $min_x, $mid_y, $max_x, $mid_y, );

    # Draw Left Bar
    if (not $left_side_unseen
        and not( $truncated == 3
            or ( $truncated >= 2 and $is_flipped )
            or ( $truncated == 1 and not $is_flipped ) )
        )
    {
        push @{ $map_layout->{'items'} },
            (
            [   1, undef, 'curve',
                [ $min_x, $min_y, $min_x, $max_y, ],
                { -linecolor => $color, }
            ]
            );
    }

    # Draw Right Circle
    if (not $right_side_unseen
        and not( $truncated == 3
            or ( $truncated >= 2 and not $is_flipped )
            or ( $truncated == 1 and $is_flipped ) )
        )
    {
        push @{ $map_layout->{'items'} },
            (
            [   1, undef, 'curve',
                [ $max_x, $min_y, $max_x, $max_y, ],
                { -linecolor => $color, }
            ]
            );
    }

    # Draw the map
    push @{ $map_layout->{'items'} },
        (
        [   1, undef, 'curve',
            [ $main_line_x1, $main_line_y1, $main_line_x2, $main_line_y2 ],
            { -linecolor => $color, }
        ]
        );

    return ( \@bounds, \@coords );
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

Copyright (c) 2006-7 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

