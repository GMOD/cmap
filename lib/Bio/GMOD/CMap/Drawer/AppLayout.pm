package Bio::GMOD::CMap::Drawer::AppLayout;

# vim: set ft=perl:

# $Id: AppLayout.pm,v 1.10 2006-07-12 15:54:24 mwz444 Exp $

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
use Bio::GMOD::CMap::Utils qw[
    simple_column_distribution
];

require Exporter;
use vars qw( $VERSION @EXPORT @EXPORT_OK );
$VERSION = (qw$Revision: 1.10 $)[-1];

use constant SLOT_BACKGROUNDS      => [qw[ white lightblue ]];
use constant SLOT_SEPARATOR_HEIGHT => 3;

use base 'Exporter';

my @subs = qw[
    layout_new_panel
    layout_overview
    overview_selected_area
    layout_reference_maps
    layout_sub_maps
    add_slot_separator
    add_correspondences
];
@EXPORT_OK = @subs;
@EXPORT    = @subs;

# ----------------------------------------------------
sub layout_new_panel {

=pod

=head2 layout_new_panel



=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $panel_key        = $args{'panel_key'};
    my $app_display_data = $args{'app_display_data'};
    my $panel_layout     = $app_display_data->{'panel_layout'}{$panel_key};

    # Initialize bounds
    # But have a height of 0.
    $panel_layout->{'bounds'} = [ 0, 0, 900, 0, ];

    my $panel_height_change = 0;
    my $slot_position       = 0;
    foreach
        my $slot_key ( @{ $app_display_data->{'slot_order'}{$panel_key} } )
    {
        layout_new_slot(
            window_key       => $window_key,
            panel_key        => $panel_key,
            slot_key         => $slot_key,
            slot_position    => $slot_position,
            app_display_data => $app_display_data,
        );
        $slot_position++;
        $panel_height_change
            = ( $app_display_data->{'slot_layout'}{$slot_key}{'bounds'}[3]
                - $app_display_data->{'slot_layout'}{$slot_key}{'bounds'}[1] )
            + 5;
        $app_display_data->modify_panel_bottom_bound(
            panel_key     => $panel_key,
            bounds_change => $panel_height_change,
        );
    }

    $panel_layout->{'changed'} = 1;

    return;
}

# ----------------------------------------------------
sub layout_overview {

=pod

=head2 layout_overview



=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $panel_key        = $args{'panel_key'};
    my $app_display_data = $args{'app_display_data'};

    my $overview_layout = $app_display_data->{'overview_layout'}{$panel_key};
    my $top_slot_key
        = $app_display_data->{'overview'}{$panel_key}{'slot_key'};

    my $map_height = 5;
    $overview_layout->{'map_buffer_y'} = 5;
    my $slot_buffer_y = 15;
    my $slot_buffer_x = 15;

    $overview_layout->{'bounds'} = [ 0, 0, 1100, 0 ];
    $overview_layout->{'maps_min_x'}
        = $overview_layout->{'bounds'}[0] + $slot_buffer_x;
    $overview_layout->{'maps_max_x'}
        = $overview_layout->{'bounds'}[2] - $slot_buffer_x;
    my $slot_min_y = 0;
    my $slot_max_y = 0;

    $slot_min_y += $slot_buffer_y;

    # slot_max_y is going to be used to place maps.
    $slot_max_y = $slot_min_y;

    my $slot_width
        = $overview_layout->{'maps_max_x'} - $overview_layout->{'maps_min_x'}
        + 1;

    # Layout Top Slot
    my $main_slot_layout = $app_display_data->{'slot_layout'}{$top_slot_key};
    my $top_pixel_factor = $slot_width / ( $main_slot_layout->{'maps_max_x'}
            - $main_slot_layout->{'maps_min_x'} );
    my $overview_slot_layout = $overview_layout->{'slots'}{$top_slot_key};
    $overview_slot_layout->{'scale_factor_from_main'} = $top_pixel_factor;
    $overview_slot_layout->{'bounds'}                 = [
        $overview_layout->{'maps_min_x'}, $slot_min_y,
        $overview_layout->{'maps_max_x'}, $slot_min_y
    ];

    $overview_layout->{'main_pixel_offset'}
        = $main_slot_layout->{'maps_min_x'};

    my @sorted_map_keys = sort {
        $app_display_data->{'map_layout'}{$a}{'bounds'}[1]
            <=> $app_display_data->{'map_layout'}{$b}{'bounds'}[1]

    } @{ $app_display_data->{'map_order'}{$top_slot_key} };

    return unless (@sorted_map_keys);

    my $last_y
        = $app_display_data->{'map_layout'}{ $sorted_map_keys[0] }{'bounds'}
        [1];
    foreach my $map_key (@sorted_map_keys) {
        unless ( $last_y
            == $app_display_data->{'map_layout'}{$map_key}{'bounds'}[1] )
        {
            $slot_max_y += $map_height + $overview_layout->{'map_buffer_y'};

            $last_y
                = $app_display_data->{'map_layout'}{$map_key}{'bounds'}[1];
        }
        my $o_map_x1 = $top_pixel_factor
            * ( $app_display_data->{'map_layout'}{$map_key}{'bounds'}[0]
                - $overview_layout->{'main_pixel_offset'} )
            + $overview_layout->{'maps_min_x'};
        my $o_map_x2 = $top_pixel_factor
            * ( $app_display_data->{'map_layout'}{$map_key}{'bounds'}[2]
                - $overview_layout->{'main_pixel_offset'} )
            + $overview_layout->{'maps_min_x'};
        push @{ $overview_slot_layout->{'maps'}{$map_key}{'items'} },
            (
            [   1, undef,
                'rectangle',
                [   $o_map_x1, $slot_max_y,
                    $o_map_x2, $slot_max_y + $map_height
                ],
                { -fill => 'blue', }
            ]
            );
    }
    $overview_slot_layout->{'bounds'}[3]
        = $slot_max_y + $overview_layout->{'map_buffer_y'};
    $slot_max_y += $map_height + $slot_buffer_y;

    # create selected region
    overview_selected_area(
        slot_key         => $top_slot_key,
        panel_key        => $panel_key,
        app_display_data => $app_display_data,
    );

    foreach my $child_slot_key ( @{ $overview_layout->{'child_slot_order'} } )
    {
        $main_slot_layout
            = $app_display_data->{'slot_layout'}{$child_slot_key};
        $overview_slot_layout = $overview_layout->{'slots'}{$child_slot_key};
        $overview_slot_layout->{'bounds'}[0]
            = $overview_layout->{'maps_min_x'};
        $overview_slot_layout->{'bounds'}[1]
            = $slot_max_y - $overview_layout->{'map_buffer_y'};
        $overview_slot_layout->{'bounds'}[2]
            = $overview_layout->{'maps_max_x'};

        my $child_pixel_factor = $top_pixel_factor
            * $app_display_data->{'scaffold'}{$child_slot_key}{'scale'};
        $overview_slot_layout->{'scale_factor_from_main'}
            = $child_pixel_factor;

        @sorted_map_keys = sort {
            $app_display_data->{'map_layout'}{$a}{'bounds'}[1]
                <=> $app_display_data->{'map_layout'}{$b}{'bounds'}[1]

        } @{ $app_display_data->{'map_order'}{$child_slot_key} };

        next unless (@sorted_map_keys);

        my $last_y = $app_display_data->{'map_layout'}{ $sorted_map_keys[0] }
            {'bounds'}[1];
        foreach my $map_key (@sorted_map_keys) {
            unless ( $last_y
                == $app_display_data->{'map_layout'}{$map_key}{'bounds'}[1] )
            {
                $slot_max_y
                    += $map_height + $overview_layout->{'map_buffer_y'};

                $last_y
                    = $app_display_data->{'map_layout'}{$map_key}{'bounds'}
                    [1];
            }
            my $o_map_x1 = $child_pixel_factor
                * ( $app_display_data->{'map_layout'}{$map_key}{'bounds'}[0]
                    - $overview_layout->{'main_pixel_offset'} )
                + $overview_layout->{'maps_min_x'};
            my $o_map_x2 = $child_pixel_factor
                * ( $app_display_data->{'map_layout'}{$map_key}{'bounds'}[2]
                    - $overview_layout->{'main_pixel_offset'} )
                + $overview_layout->{'maps_min_x'};
            push @{ $overview_slot_layout->{'maps'}{$map_key}{'items'} },
                (
                [   1, undef,
                    'rectangle',
                    [   $o_map_x1, $slot_max_y,
                        $o_map_x2, $slot_max_y + $map_height
                    ],
                    { -fill => 'blue', }
                ]
                );
        }

        $slot_max_y += $map_height;
        $overview_slot_layout->{'bounds'}[3] = $slot_max_y;
        $slot_max_y += $slot_buffer_y;

        # create selected region
        overview_selected_area(
            slot_key         => $child_slot_key,
            panel_key        => $panel_key,
            app_display_data => $app_display_data,
        );
    }

    $overview_layout->{'bounds'}[3] = $slot_max_y;

    return;
}

# ----------------------------------------------------
sub layout_new_slot {

=pod

=head2 layout_new_slot

Lays out a brand new slot

=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $panel_key        = $args{'panel_key'};
    my $slot_key         = $args{'slot_key'};
    my $slot_position    = $args{'slot_position'};
    my $app_display_data = $args{'app_display_data'};
    my $panel_layout     = $app_display_data->{'panel_layout'}{$panel_key};
    my $slot_layout      = $app_display_data->{'slot_layout'}{$slot_key};
    my $start_height     = 0;
    my $buffer           = 2;

    # Initialize bounds to the bounds of the panel
    # starting at the lowest point available.
    # But have a height of 0.
    $slot_layout->{'bounds'} = [
        $panel_layout->{'bounds'}[0], $panel_layout->{'bounds'}[3],
        $panel_layout->{'bounds'}[2], $panel_layout->{'bounds'}[3],
    ];

    unless ( $app_display_data->{'scaffold'}{$slot_key}{'attached_to_parent'}
        or $app_display_data->{'scaffold'}{$slot_key}{'is_top'} )
    {
        add_slot_separator( slot_layout => $slot_layout, );
    }
    unless ( $app_display_data->{'scaffold'}{$slot_key}{'is_top'} ) {

        # Make room for border if it is possible to have one.
        $slot_layout->{'bounds'}[3] += SLOT_SEPARATOR_HEIGHT + $buffer;
    }

    if ( $app_display_data->{'scaffold'}{$slot_key}{'attached_to_parent'} ) {

        # These maps are features of the parent map
        layout_sub_maps(
            window_key       => $window_key,
            panel_key        => $panel_key,
            slot_key         => $slot_key,
            app_display_data => $app_display_data,
        );
    }
    else {

        # These maps are "reference" maps
        layout_reference_maps(
            window_key       => $window_key,
            panel_key        => $panel_key,
            slot_key         => $slot_key,
            app_display_data => $app_display_data,
        );
    }
    my $bgcolor = SLOT_BACKGROUNDS->[ $slot_position %
        scalar @{ +SLOT_BACKGROUNDS } ];
    $slot_layout->{'background'} = [
        [   1, undef,
            'rectangle',
            [ @{ $app_display_data->{'slot_layout'}{$slot_key}{'bounds'} } ],
            { -fill => $bgcolor, }
        ]
    ];

    $panel_layout->{'sub_changed'} = 1;
    $slot_layout->{'changed'}      = 1;

    return;
}

# ----------------------------------------------------
sub add_slot_separator {

=pod

=head2 add_slot_separator

Lays out reference maps in a new slot

=cut

    my %args        = @_;
    my $slot_layout = $args{'slot_layout'};

    my $border_x1 = $slot_layout->{'bounds'}[0];
    my $border_y1 = $slot_layout->{'bounds'}[1];
    my $border_x2 = $slot_layout->{'bounds'}[2];
    $slot_layout->{'separator'} = [
        [   1, undef,
            'rectangle',
            [   $border_x1, $border_y1,
                $border_x2, $border_y1 + SLOT_SEPARATOR_HEIGHT
            ],
            { -fill => 'black', }
        ]
    ];
}

# ----------------------------------------------------
sub layout_reference_maps {

=pod

=head2 _layout_reference_maps

Lays out reference maps in a new slot

=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $panel_key        = $args{'panel_key'};
    my $slot_key         = $args{'slot_key'};
    my $app_display_data = $args{'app_display_data'};
    my $slot_layout      = $app_display_data->{'slot_layout'}{$slot_key};

    #  Options that should be defined elsewhere
    my $stacked       = 0;
    my $min_map_width = 40;
    my $map_x_buffer  = 15;
    my $map_y_buffer  = 15;

    my $x_offset = $app_display_data->{'scaffold'}{$slot_key}{'x_offset'}
        || 0;

    my $left_bound  = $slot_layout->{'bounds'}[0] + $map_x_buffer;
    my $right_bound = $slot_layout->{'bounds'}[2] - $map_x_buffer;
    my $slot_width  = $right_bound - $left_bound;
    my $maps_num
        = scalar( @{ $app_display_data->{'map_order'}{$slot_key} || [] } );

    return unless ($slot_width);

    my $start_height = 0;

    my @ordered_map_ids = map { $app_display_data->{'map_key_to_id'}{$_} }
        @{ $app_display_data->{'map_order'}{$slot_key} || [] };
    my $map_data_hash = $app_display_data->app_data_module()
        ->map_data_hash( map_ids => \@ordered_map_ids, );

    my $pixels_per_unit = _pixels_per_map_unit(
        map_data_hash    => $map_data_hash,
        ordered_map_ids  => \@ordered_map_ids,
        map_x_buffer     => $map_x_buffer,
        min_map_width    => $min_map_width,
        slot_width       => $slot_width,
        slot_key         => $slot_key,
        stacked          => $stacked,
        app_display_data => $app_display_data,
    );

    # Store pixels_per_unit
    $app_display_data->{'scaffold'}{$slot_key}{'pixels_per_unit'}
        = $pixels_per_unit;

    my $map_min_x   = $left_bound;
    my $row_min_y   = $slot_layout->{'bounds'}[1];
    my $start_min_y = $row_min_y;
    $row_min_y += $map_y_buffer;
    my $row_max_y = $row_min_y;

    $slot_layout->{'maps_min_x'} = $map_min_x;

    foreach
        my $map_key ( @{ $app_display_data->{'map_order'}{$slot_key} || [] } )
    {
        my $map_id = $app_display_data->{'map_key_to_id'}{$map_key};
        my $map    = $map_data_hash->{$map_id};
        my $length = $map->{'map_stop'} - $map->{'map_start'};
        my $map_container_width = $length * $pixels_per_unit;

        # If the map is the minimum width,
        # Set the individual ppu otherwise clear it.
        if ( $map_container_width < $min_map_width ) {
            $map_container_width = $min_map_width;
            $app_display_data->{'map_pixels_per_unit'}{$map_key}
                = $map_container_width / $length;
        }
        elsif ( $app_display_data->{'map_pixels_per_unit'}{$map_key} ) {
            delete $app_display_data->{'map_pixels_per_unit'}{$map_key};
        }

        my $map_pixels_per_unit
            = $app_display_data->{'map_pixels_per_unit'}{$map_key}
            || $pixels_per_unit;

        if ($stacked) {
            $map_min_x = $left_bound;
            $row_min_y = $row_max_y + $map_y_buffer;
        }
        my $map_max_x = $map_min_x + $map_container_width;

        # Set bounds so overview can access it later even if it
        # isn't on the screen.
        $app_display_data->{'map_layout'}{$map_key}{'bounds'}
            = [ $map_min_x, $row_min_y, $map_max_x, $row_min_y ];

        if ( ( not defined $slot_layout->{'maps_max_x'} )
            or $slot_layout->{'maps_max_x'} < $map_max_x )
        {
            $slot_layout->{'maps_max_x'} = $map_max_x;
        }

        # If map is not on the screen, doen't lay it out.
        if ( ( $map_min_x + $map_container_width - $x_offset )
            < $slot_layout->{'bounds'}[0]
            or $map_min_x - $x_offset > $slot_layout->{'bounds'}[2] )
        {

        }

        # Add info to slot_info needed for creation of correspondences
        _add_to_slot_info(
            app_display_data => $app_display_data,
            slot_key         => $slot_key,
            min_bound        => $slot_layout->{'bounds'}[0],
            max_bound        => $slot_layout->{'bounds'}[2],
            map_min_x        => $map_min_x,
            map_max_x        => $map_max_x,
            map_start        => $map->{'map_start'},
            map_stop         => $map->{'map_stop'},
            map_id           => $map->{'map_id'},
            x_offset         => $x_offset,
            pixels_per_unit  => $map_pixels_per_unit,
        );

        my $tmp_map_max_y = _layout_contained_map(
            app_display_data => $app_display_data,
            window_key       => $window_key,
            panel_key        => $panel_key,
            slot_key         => $slot_key,
            map_key          => $map_key,
            map              => $map,
            min_x            => $map_min_x,
            max_x            => $map_max_x,
            min_y            => $row_min_y,
            pixels_per_unit  => $map_pixels_per_unit,
        );
        if ( $row_max_y < $tmp_map_max_y ) {
            $row_max_y = $tmp_map_max_y;
        }

        $map_min_x += $map_container_width + $map_x_buffer;
        $app_display_data->{'map_layout'}{$map_key}{'changed'} = 1;
    }

    my $height_change = $row_max_y - $start_min_y + $map_y_buffer;
    $app_display_data->modify_slot_bottom_bound(
        slot_key      => $slot_key,
        bounds_change => $height_change,
    );

    $slot_layout->{'sub_changed'} = 1;
    return;
}

# ----------------------------------------------------
sub layout_sub_maps {

=pod

=head2 layout_sub_maps

Lays out sub maps in a slot. 

=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $panel_key        = $args{'panel_key'};
    my $slot_key         = $args{'slot_key'};
    my $app_display_data = $args{'app_display_data'};
    my $slot_layout      = $app_display_data->{'slot_layout'}{$slot_key};

    my $scale = $app_display_data->{'scaffold'}{$slot_key}{'scale'} || 1;
    my $x_offset = $app_display_data->{'scaffold'}{$slot_key}{'x_offset'}
        || 0;

    #  Options that should be defined elsewhere
    my $map_x_buffer = 15;
    my $map_y_buffer = 15;

    my $start_min_y = $slot_layout->{'bounds'}[1];

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
    } @{ $app_display_data->{'map_order'}{$slot_key} || [] };

    my @row_distribution_aray;
    my @rows;

    my $current_parent_map_key = '-1';
    my ( $parent_x1, $parent_x2, $parent_data, $parent_start, $parent_stop,
        $parent_id, $parent_pixels_per_unit, );

    foreach my $sub_map_key (@sub_map_keys) {
        my $parent_map_key
            = $app_display_data->{'sub_maps'}{$sub_map_key}{'parent_map_key'};
        my $feature_start
            = $app_display_data->{'sub_maps'}{$sub_map_key}{'feature_start'};
        my $feature_stop
            = $app_display_data->{'sub_maps'}{$sub_map_key}{'feature_stop'};
        unless ( $parent_map_key eq $current_parent_map_key ) {
            $current_parent_map_key = $parent_map_key;
            $parent_id
                = $app_display_data->{'map_key_to_id'}{$parent_map_key};
            $parent_x1
                = $app_display_data->{'map_layout'}{$current_parent_map_key}
                {'bounds'}[0];
            $parent_x2
                = $app_display_data->{'map_layout'}{$current_parent_map_key}
                {'bounds'}[2];
            $parent_data = $app_display_data->app_data_module()
                ->map_data( map_id => $parent_id, );
            $parent_start = $parent_data->{'map_start'};
            $parent_stop  = $parent_data->{'map_stop'};
            $parent_pixels_per_unit
                = $app_display_data->{'map_pixels_per_unit'}{$parent_map_key}
                || $app_display_data->{'scaffold'}{$parent_map_key}
                {'pixels_per_unit'};
        }

        my $x1_on_map
            = ( ( $feature_start - $parent_start ) * $parent_pixels_per_unit )
            * $scale;
        my $x2_on_map
            = ( ( $feature_stop - $parent_start ) * $parent_pixels_per_unit )
            * $scale;
        my $x1        = $parent_x1 + $x1_on_map;
        my $x2        = $parent_x1 + $x2_on_map;
        my $row_index = simple_column_distribution(
            low        => $x1_on_map,
            high       => $x2_on_map,
            columns    => \@row_distribution_aray,
            map_height => ( $parent_x2 - $parent_x1 + 1 )
                * $scale,    # really width
            buffer => $map_y_buffer,
        );

        push @{ $rows[$row_index] }, [ $sub_map_key, $x1, $x2 ];
    }

    my $row_min_y = $start_min_y + $map_y_buffer;
    my $row_max_y = $row_min_y;
    my $map_pixels_per_unit;

    foreach my $row (@rows) {
        foreach my $row_sub_map ( @{ $row || [] } ) {
            my $sub_map_key = $row_sub_map->[0];
            my $x1          = $row_sub_map->[1];
            my $x2          = $row_sub_map->[2];
            my $sub_map_id
                = $app_display_data->{'map_key_to_id'}{$sub_map_key};
            my $sub_map_data = $app_display_data->app_data_module()
                ->map_data( map_id => $sub_map_id, );
            my $parent_map_key = $app_display_data->{'sub_maps'}{$sub_map_key}
                {'parent_map_key'};

            # Set bounds so overview can access it later even if it
            # isn't on the screen.
            $app_display_data->{'map_layout'}{$sub_map_key}{'bounds'}
                = [ $x1, $row_min_y, $x2, $row_min_y ];

            if ( ( not defined $slot_layout->{'maps_min_x'} )
                or $slot_layout->{'maps_min_x'} > $x1 )
            {
                $slot_layout->{'maps_min_x'} = $x1;
            }
            if ( ( not defined $slot_layout->{'maps_max_x'} )
                or $slot_layout->{'maps_max_x'} < $x2 )
            {
                $slot_layout->{'maps_max_x'} = $x2;
            }

            # If map is not on the screen, doen't lay it out.
            if (   $x2 - $x_offset < $slot_layout->{'bounds'}[0]
                or $x1 - $x_offset > $slot_layout->{'bounds'}[2] )
            {
                next;
            }

            $map_pixels_per_unit
                = $app_display_data->{'map_pixels_per_unit'}{$sub_map_key}
                = ( $x2 - $x1 ) / (
                $sub_map_data->{'map_stop'} - $sub_map_data->{'map_start'} );

            # Add info to slot_info needed for creation of correspondences
            _add_to_slot_info(
                app_display_data => $app_display_data,
                slot_key         => $slot_key,
                min_bound        => $slot_layout->{'bounds'}[0],
                max_bound        => $slot_layout->{'bounds'}[2],
                map_min_x        => $x1,
                map_max_x        => $x2,
                map_start        => $sub_map_data->{'map_start'},
                map_stop         => $sub_map_data->{'map_stop'},
                map_id           => $sub_map_data->{'map_id'},
                x_offset         => $x_offset,
                pixels_per_unit  => $map_pixels_per_unit,
            );

            my $tmp_map_max_y = _layout_contained_map(
                app_display_data => $app_display_data,
                window_key       => $window_key,
                panel_key        => $panel_key,
                slot_key         => $slot_key,
                map_key          => $sub_map_key,
                map              => $sub_map_data,
                min_x            => $x1,
                max_x            => $x2,
                min_y            => $row_min_y,
                pixels_per_unit  => $map_pixels_per_unit,
            );

            if ( $row_max_y < $tmp_map_max_y ) {
                $row_max_y = $tmp_map_max_y;
            }
            $app_display_data->{'map_layout'}{$sub_map_key}{'changed'} = 1;
        }
        $row_min_y = $row_max_y + $map_y_buffer;
    }

    my $height_change = $row_max_y - $start_min_y + $map_y_buffer;
    $app_display_data->modify_slot_bottom_bound(
        slot_key      => $slot_key,
        bounds_change => $height_change,
    );

    $slot_layout->{'sub_changed'} = 1;
    return;
}

# ----------------------------------------------------
sub _layout_contained_map {

=pod

=head2 _layout_contained_map

Lays out a maps in a contained area.

=cut

    my %args             = @_;
    my $app_display_data = $args{'app_display_data'};
    my $window_key       = $args{'window_key'};
    my $panel_key        = $args{'panel_key'};
    my $slot_key         = $args{'slot_key'};
    my $map_key          = $args{'map_key'};
    my $map              = $args{'map'};
    my $min_x            = $args{'min_x'};
    my $max_x            = $args{'max_x'};
    my $min_y            = $args{'min_y'};
    my $pixels_per_unit  = $args{'pixels_per_unit'};

    my $buffer = 2;

    my $max_y;

    my $map_layout = $app_display_data->{'map_layout'}{$map_key};

    push @{ $map_layout->{'items'} },
        (
        [   1, undef, 'text',
            [ $min_x, $min_y ],
            {   -text   => $map->{'map_name'},
                -anchor => 'nw',
                -fill   => 'black',
            }
        ]
        );

    $min_y += 15;
    $max_y = $min_y + 5;
    push @{ $map_layout->{'items'} },
        (
        [   1, undef, 'rectangle',
            [ $min_x, $min_y, $max_x, $max_y ],
            { -fill => 'blue', }
        ]
        );
    $map_layout->{'coords'} = [ $min_x, $min_y, $max_x, $max_y ];

    $min_y = $max_y + $buffer;

    if ( $app_display_data->{'scaffold'}{$slot_key}{'expanded'} ) {
        $max_y = _layout_features(
            app_display_data => $app_display_data,
            slot_key         => $slot_key,
            map_key          => $map_key,
            map              => $map,
            min_x            => $min_x,
            max_x            => $max_x,
            min_y            => $min_y,
            pixels_per_unit  => $pixels_per_unit,
        );
    }
    $map_layout->{'bounds'} = [ $min_x, $min_y, $max_x, $max_y ];

    $map_layout->{'sub_changed'} = 1;

    return $max_y;
}

# ----------------------------------------------------
sub _layout_features {

=pod

=head2 _layout_features

Lays out feautures 

=cut

    my %args             = @_;
    my $app_display_data = $args{'app_display_data'};
    my $slot_key         = $args{'slot_key'};
    my $map_key          = $args{'map_key'};
    my $map              = $args{'map'};
    my $min_x            = $args{'min_x'};
    my $min_y            = $args{'min_y'};
    my $max_x            = $args{'max_x'};
    my $pixels_per_unit  = $args{'pixels_per_unit'};

    my $max_y = $min_y;

    my $sorted_feature_data = $app_display_data->app_data_module()
        ->sorted_feature_data( map_id => $map->{'map_id'} );

    unless ( %{ $sorted_feature_data || {} } ) {
        return $min_y;
    }

    my $map_start = $map->{'map_start'};
    my $buffer    = 2;

    for my $lane ( sort { $a <=> $b } keys %$sorted_feature_data ) {
        my $lane_features = $sorted_feature_data->{$lane};
        my $lane_min_y    = $max_y + $buffer;
        my @fcolumns;

        foreach my $feature ( @{ $lane_features || [] } ) {
            my $feature_acc   = $feature->{'feature_acc'};
            my $feature_start = $feature->{'feature_start'};
            my $feature_stop  = $feature->{'feature_stop'};
            unless ( $app_display_data->{'map_layout'}{$map_key}{'features'}
                {$feature_acc} )
            {
                $app_display_data->{'map_layout'}{$map_key}{'features'}
                    {$feature_acc} = {};
            }
            my $feature_layout
                = $app_display_data->{'map_layout'}{$map_key}{'features'}
                {$feature_acc};

            my $x1 = $min_x
                + ( ( $feature_start - $map_start ) * $pixels_per_unit );
            my $x2 = $min_x
                + ( ( $feature_stop - $map_start ) * $pixels_per_unit );

            my $adjusted_left  = $x1 - $min_x;
            my $adjusted_right = $x2 - $min_x;
            my $column_index   = simple_column_distribution(
                low        => $adjusted_left,
                high       => $adjusted_right,
                columns    => \@fcolumns,
                map_height => $max_x - $min_x + 1,
                buffer     => $buffer,
            );

            my $label_features = 0;

            my $offset =
                $label_features
                ? ($column_index) * 18
                : ($column_index) * 5;
            my $y1 = $lane_min_y + $offset;

            if ($label_features) {
                push @{ $feature_layout->{'items'} },
                    (
                    [   1, undef, 'text',
                        [ $x1, $y1 ],
                        {   -text   => $feature->{'feature_name'},
                            -anchor => 'nw',
                            -fill   => 'black',
                        }
                    ]
                    );

                $y1 += 15;
            }
            my $y2 = $y1 + 2;
            push @{ $feature_layout->{'items'} },
                (
                [   1, undef,
                    'rectangle', [ $x1, $y1, $x2, $y2 ],
                    { -fill => 'red', }
                ]
                );
            $feature_layout->{'changed'} = 1;
            if ( $y2 > $max_y ) {
                $max_y = $y2;
            }
        }
    }

    return $max_y;
}

# ----------------------------------------------------
sub add_correspondences {

=pod

=head2 add_correspondences

Lays out correspondences between two slots

=cut

    my %args             = @_;
    my $app_display_data = $args{'app_display_data'};
    my $window_key       = $args{'window_key'};
    my $panel_key        = $args{'panel_key'};
    my $slot_key1        = $args{'slot_key1'};
    my $slot_key2        = $args{'slot_key2'};

    ( $slot_key1, $slot_key2 ) = ( $slot_key2, $slot_key1 )
        if ( $slot_key1 > $slot_key2 );

    # Get Correspondence Data
    my $corrs = $app_display_data->app_data_module()->slot_correspondences(
        slot_key1  => $slot_key1,
        slot_key2  => $slot_key2,
        slot_info1 => $app_display_data->{'slot_info'}{$slot_key1},
        slot_info2 => $app_display_data->{'slot_info'}{$slot_key2},
    );

    if ( @{ $corrs || [] } ) {
        $app_display_data->{'corr_layout'}{'changed'} = 1;
    }

    foreach my $corr ( @{ $corrs || [] } ) {
        my $map_key1
            = $app_display_data->{'map_id_to_key_by_slot'}{$slot_key1}
            { $corr->{'map_id1'} };
        my $map_key2
            = $app_display_data->{'map_id_to_key_by_slot'}{$slot_key2}
            { $corr->{'map_id2'} };
        my $map1_x1
            = $app_display_data->{'map_layout'}{$map_key1}{'coords'}[0];
        my $map2_x1
            = $app_display_data->{'map_layout'}{$map_key2}{'coords'}[0];
        my ( $corr_y1, $corr_y2 );
        if ( $app_display_data->{'map_layout'}{$map_key1}{'coords'}[1]
            < $app_display_data->{'map_layout'}{$map_key2}{'coords'}[1] )
        {
            $corr_y1
                = $app_display_data->{'map_layout'}{$map_key1}{'coords'}[3];
            $corr_y2
                = $app_display_data->{'map_layout'}{$map_key2}{'coords'}[1];
        }
        else {
            $corr_y1
                = $app_display_data->{'map_layout'}{$map_key1}{'coords'}[1];
            $corr_y2
                = $app_display_data->{'map_layout'}{$map_key2}{'coords'}[3];
        }
        my $map1_pixels_per_unit
            = $app_display_data->{'map_pixels_per_unit'}{$map_key1}
            || $app_display_data->{'scaffold'}{$slot_key1}{'pixels_per_unit'};
        my $map2_pixels_per_unit
            = $app_display_data->{'map_pixels_per_unit'}{$map_key2}
            || $app_display_data->{'scaffold'}{$slot_key2}{'pixels_per_unit'};
        my $corr_avg_x1
            = ( $corr->{'feature_start1'} + $corr->{'feature_stop1'} ) / 2;
        my $corr_x1 = $map1_x1 + ( $map1_pixels_per_unit * $corr_avg_x1 );
        my $corr_avg_x2
            = ( $corr->{'feature_start2'} + $corr->{'feature_stop2'} ) / 2;
        my $corr_x2 = $map2_x1 + ( $map2_pixels_per_unit * $corr_avg_x2 );

        unless (
            $app_display_data->{'corr_layout'}{'maps'}{$map_key1}{$map_key2} )
        {
            $app_display_data->{'corr_layout'}{'maps'}{$map_key1}{$map_key2}
                = {
                changed   => 1,
                items     => [],
                slot_key1 => $slot_key1,
                slot_key2 => $slot_key2,
                map_key1  => $map_key1,
                map_key2  => $map_key2,
                };

            # point a reference to the corrs from each map.
            $app_display_data->{'corr_layout'}{'maps'}{$map_key2}{$map_key1}
                = $app_display_data->{'corr_layout'}{'maps'}{$map_key1}
                {$map_key2};
        }
        $app_display_data->{'corr_layout'}{'maps'}{$map_key1}{$map_key2}
            {'changed'} = 1;
        push @{ $app_display_data->{'corr_layout'}{'maps'}{$map_key1}
                {$map_key2}{'items'} },
            (
            [   1, undef, 'line',
                [ ( $corr_x1, $corr_y1 ), ( $corr_x2, $corr_y2 ), ],
                { -fill => 'red', -width => '1', }
            ]
            );
    }

    return;
}

# ----------------------------------------------------
sub _add_to_slot_info {

=pod

=head2 _add_to_slot_info

Add data to slot_info object

=cut

    my %args             = @_;
    my $app_display_data = $args{'app_display_data'};
    my $slot_key         = $args{'slot_key'};
    my $map_min_x        = $args{'map_min_x'};
    my $map_max_x        = $args{'map_max_x'};
    my $min_bound        = $args{'min_bound'};
    my $max_bound        = $args{'max_bound'};
    my $map_start        = $args{'map_start'};
    my $map_stop         = $args{'map_stop'};
    my $map_id           = $args{'map_id'};
    my $x_offset         = $args{'x_offset'};
    my $pixels_per_unit  = $args{'pixels_per_unit'};

    my $adjusted_map_min_x = $map_min_x - $x_offset;
    my $adjusted_map_max_x = $map_max_x - $x_offset;

    $app_display_data->{'slot_info'}{$slot_key}{$map_id}
        = [ undef, undef, $map_start, $map_stop, 1 ];
    if ( $adjusted_map_min_x < $min_bound ) {
        $app_display_data->{'slot_info'}{$slot_key}{$map_id}[0] = $map_start
            + ( ( $min_bound - $adjusted_map_min_x ) / $pixels_per_unit );
    }
    if ( $adjusted_map_max_x > $max_bound ) {
        $app_display_data->{'slot_info'}{$slot_key}{$map_id}[1] = $map_stop
            - ( ( $adjusted_map_max_x - $max_bound ) / $pixels_per_unit );
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
    my $map_x_buffer     = $args{'map_x_buffer'};
    my $min_map_width    = $args{'min_map_width'};
    my $slot_width       = $args{'slot_width'};
    my $slot_key         = $args{'slot_key'};
    my $stacked          = $args{'stacked'};
    my $app_display_data = $args{'app_display_data'};

    unless ( $app_display_data->{'scaffold'}{$slot_key}{'pixels_per_unit'} ) {
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
                = ( $slot_width - ( 2 * $map_x_buffer ) ) / $longest_length;
        }
        else {
            my %map_length;
            foreach my $map_id (@$ordered_map_ids) {
                my $map       = $map_data_hash->{$map_id};
                my $map_start = $map->{'map_start'};
                my $map_stop  = $map->{'map_stop'};
                $map_length{$map_id}
                    = $map->{'map_stop'} - $map->{'map_start'};
            }

            my $all_maps_fit = 0;
            my %map_is_min_length;
            while ( !$all_maps_fit ) {
                my $length_sum           = 0;
                my $scaled_map_count     = 0;
                my $min_length_map_count = 0;
                foreach my $map_id (@$ordered_map_ids) {
                    if ( $map_is_min_length{$map_id} ) {
                        $min_length_map_count++;
                        next;
                    }
                    else {
                        $scaled_map_count++;
                        $length_sum += $map_length{$map_id};
                    }
                }
                my $other_space
                    = ( 1 + scalar(@$ordered_map_ids) ) * $map_x_buffer
                    + ( $min_map_width * $min_length_map_count );
                $pixels_per_unit = $length_sum
                    ? ( $slot_width - $other_space ) / $length_sum
                    : 0;

                # Check this ppu to see if it makes any
                #   new maps drop below the minimum
                my $redo = 0;
                foreach my $map_id (@$ordered_map_ids) {
                    next if ( $map_is_min_length{$map_id} );
                    if ( $map_length{$map_id} * $pixels_per_unit
                        < $min_map_width )
                    {
                        $redo = 1;
                        $map_is_min_length{$map_id} = 1;
                    }
                }
                unless ($redo) {
                    $all_maps_fit = 1;
                }
            }
        }
        $app_display_data->{'scaffold'}{$slot_key}{'pixels_per_unit'}
            = $pixels_per_unit;
    }

    return $app_display_data->{'scaffold'}{$slot_key}{'pixels_per_unit'};
}

# ----------------------------------------------------
sub overview_selected_area {

=pod

=head2 overview_selected_area

Shows the selected region.

=cut

    my %args             = @_;
    my $slot_key         = $args{'slot_key'};
    my $panel_key        = $args{'panel_key'};
    my $app_display_data = $args{'app_display_data'};

    my $overview_layout = $app_display_data->{'overview_layout'}{$panel_key};
    my $overview_slot_layout = $overview_layout->{'slots'}{$slot_key};
    my $main_slot_layout     = $app_display_data->{'slot_layout'}{$slot_key};
    my $main_offset_x
        = $app_display_data->{'scaffold'}{$slot_key}{'x_offset'};

    my $bracket_y1 = $overview_slot_layout->{'bounds'}[1]
        - $overview_layout->{'map_buffer_y'};
    my $bracket_y2 = $overview_slot_layout->{'bounds'}[3]
        + $overview_layout->{'map_buffer_y'};
    my $scale_factor_from_main
        = $overview_slot_layout->{'scale_factor_from_main'};
    my $min_x =
        (
        $main_slot_layout->{'bounds'}[0] > $main_slot_layout->{'maps_min_x'} )
        ? $main_slot_layout->{'bounds'}[0]
        : $main_slot_layout->{'maps_min_x'};
    my $max_x =
        (
        $main_slot_layout->{'bounds'}[2] < $main_slot_layout->{'maps_max_x'} )
        ? $main_slot_layout->{'bounds'}[2]
        : $main_slot_layout->{'maps_max_x'};
    $min_x -= $overview_layout->{'main_pixel_offset'};
    $max_x -= $overview_layout->{'main_pixel_offset'};

    my $bracket_x1 = ( ( $min_x + $main_offset_x ) * $scale_factor_from_main )
        + $overview_layout->{'maps_min_x'};
    my $bracket_x2 = ( ( $max_x + $main_offset_x ) * $scale_factor_from_main )
        + $overview_layout->{'maps_min_x'};

    my $bracket_width = 5;

    my $use_brackets = 0;
    if ($use_brackets) {

        # Left bracket
        push @{ $overview_slot_layout->{'viewed_region'} },
            (
            [   1, undef, 'line',
                [   ( $bracket_x1 + $bracket_width, $bracket_y1 ),
                    ( $bracket_x1,                  $bracket_y1 ),
                    ( $bracket_x1,                  $bracket_y2 ),
                    ( $bracket_x1 + $bracket_width, $bracket_y2 ),
                ],
                { -fill => 'orange', -width => '3', }
            ]
            );

        # Right bracket
        push @{ $overview_slot_layout->{'viewed_region'} },
            (
            [   1, undef, 'line',
                [   ( $bracket_x2 - $bracket_width, $bracket_y1 ),
                    ( $bracket_x2,                  $bracket_y1 ),
                    ( $bracket_x2,                  $bracket_y2 ),
                    ( $bracket_x2 - $bracket_width, $bracket_y2 ),
                ],
                { -fill => 'orange', -width => '3', }
            ]
            );

        # top line
        push @{ $overview_slot_layout->{'viewed_region'} },
            (
            [   1, undef, 'line',
                [   ( $bracket_x1, $bracket_y1 ),
                    ( $bracket_x2, $bracket_y1 ),
                ],
                { -fill => 'orange', -width => '1', }
            ]
            );

        # bottom line
        push @{ $overview_slot_layout->{'viewed_region'} },
            (
            [   1, undef, 'line',
                [   ( $bracket_x1, $bracket_y2 ),
                    ( $bracket_x2, $bracket_y2 ),
                ],
                { -fill => 'orange', -width => '1', }
            ]
            );
    }
    else {

        # rectangle
        push @{ $overview_slot_layout->{'viewed_region'} }, (
            [   1, undef,
                'rectangle',
                [   ( $bracket_x1, $bracket_y1 ),
                    ( $bracket_x2, $bracket_y2 ),
                ],
                {   -outline => 'orange',

                    #            -fill    => 'orange',
                    -width => '1',
                }
            ]
        );
    }
    $overview_layout->{'sub_changed'}  = 1;
    $overview_slot_layout->{'changed'} = 1;

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

