package Bio::GMOD::CMap::Drawer::AppLayout;

# vim: set ft=perl:

# $Id: AppLayout.pm,v 1.3 2006-04-06 00:37:04 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.3 $)[-1];

use base 'Exporter';

my @subs = qw[
    layout_new_window
    layout_new_panel
    layout_new_slot
];
@EXPORT_OK = @subs;
@EXPORT    = @subs;

# ----------------------------------------------------
sub layout_new_window {

=pod

=head2 layout_new_window



=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $app_display_data = $args{'app_display_data'};
    $app_display_data->{'window_layout'}{$window_key}{'bounds'}
        = [ 0, 0, 900, 0 ];
    $app_display_data->{'window_layout'}{$window_key}{'container_bounds'}
        = [ 0, 0, 900, 0 ];    # width is defined, height is changable

    my $panel_buffer = 10;

    my $window_height_change = 0;
    foreach
        my $panel_key ( @{ $app_display_data->{'panel_order'}{$window_key} } )
    {
        layout_new_panel(
            window_key       => $window_key,
            panel_key        => $panel_key,
            app_display_data => $app_display_data,
        );
        $window_height_change
            += ( $app_display_data->{'panel_layout'}{$panel_key}{'bounds'}[3]
                - $app_display_data->{'panel_layout'}{$panel_key}{'bounds'}[1]
            );
    }

    $app_display_data->modify_window_bottom_bound(
        window_key       => $window_key,
        bounds_change    => $window_height_change,
        container_change => $window_height_change,
    );

    return;
}

# ----------------------------------------------------
sub layout_new_panel {

=pod

=head2 layout_new_panel



=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $panel_key        = $args{'panel_key'};
    my $app_display_data = $args{'app_display_data'};
    my $window_layout    = $app_display_data->{'window_layout'}{$window_key};
    my $panel_layout     = $app_display_data->{'panel_layout'}{$panel_key};

    my $panel_border_width = 4;

    # Initialize bounds to the container bounds of the window
    # starting at the lowest point available.
    # But have a height of 0.
    $panel_layout->{'bounds'} = [
        $window_layout->{'container_bounds'}[0],
        $window_layout->{'container_bounds'}[3],
        $window_layout->{'container_bounds'}[2],
        $window_layout->{'container_bounds'}[3],
    ];

    # Make room for panel specific stuff by displacing the container
    $panel_layout->{'container_bounds'} = [
        $panel_layout->{'bounds'}[0] + $panel_border_width,
        $panel_layout->{'bounds'}[1] + $panel_border_width,
        $panel_layout->{'bounds'}[2] - $panel_border_width,
    ];
    $panel_layout->{'container_bounds'}[3]
        = $panel_layout->{'container_bounds'}[0];

    my $panel_height_change = 0;
    foreach
        my $slot_key ( @{ $app_display_data->{'slot_order'}{$panel_key} } )
    {
        layout_new_slot(
            window_key       => $window_key,
            panel_key        => $panel_key,
            slot_key         => $slot_key,
            app_display_data => $app_display_data,
        );
        $panel_height_change
            = ( $app_display_data->{'slot_layout'}{$slot_key}{'bounds'}[3]
                - $app_display_data->{'slot_layout'}{$slot_key}{'bounds'}[1] )
            + 5;
        $app_display_data->modify_panel_bottom_bound(
            panel_key        => $panel_key,
            bounds_change    => $panel_height_change,
            container_change => $panel_height_change,
        );
    }

    # Handle border
    $panel_layout->{'bounds'}[3]
        = $panel_layout->{'container_bounds'}[3] + $panel_border_width;
    $panel_layout->{'misc_items'} = [
        [   1, undef,
            'rectangle',
            [   $panel_layout->{'bounds'}[0] + ( $panel_border_width / 2 ),
                $panel_layout->{'bounds'}[1] - ( $panel_border_width / 2 ),
                $panel_layout->{'bounds'}[2] - ( $panel_border_width / 2 ),
                $panel_layout->{'bounds'}[3] + ( $panel_border_width / 2 ),

            ],
            { -width => $panel_border_width, }
        ],
    ];

    #    push @{ $panel_layout->{'misc_items'} },
    #        [
    #        1, undef, 'rectangle',
    #        [ @{ $panel_layout->{'bounds'} } ],
    #        { -width => 10, -outline => 'black', }
    #        ];
    #    push @{ $panel_layout->{'misc_items'} },
    #        [
    #        1, undef, 'rectangle',
    #        [ @{ $panel_layout->{'bounds'} } ],
    #        { -width => 1, -outline => 'yellow', }
    #        ];
    #
    #    push @{ $panel_layout->{'misc_items'} },
    #        [
    #        1, undef, 'line',
    #        [ 100, 300, 400,300 ],
    #        { -width => 10, -fill => 'black', }
    #        ];
    #    push @{ $panel_layout->{'misc_items'} },
    #        [
    #        1, undef, 'line',
    #        [ 100, 300, 400,300 ],
    #        { -width => 1, -fill => 'yellow', }
    #        ];

    $window_layout->{'sub_changed'} = 1;
    $panel_layout->{'changed'}      = 1;

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
    my $app_display_data = $args{'app_display_data'};
    my $panel_layout     = $app_display_data->{'panel_layout'}{$panel_key};
    my $slot_layout      = $app_display_data->{'slot_layout'}{$slot_key};
    my $start_height     = 0;
    my $buffer           = 2;

    # Initialize bounds to the container bounds of the panel
    # starting at the lowest point available.
    # But have a height of 0.
    $slot_layout->{'bounds'} = [
        $panel_layout->{'container_bounds'}[0],
        $panel_layout->{'container_bounds'}[3],
        $panel_layout->{'container_bounds'}[2],
        $panel_layout->{'container_bounds'}[3],
    ];

    unless (
        $app_display_data->{'scaffold'}{$window_key}{$panel_key}{$slot_key}
        {'is_top'} )
    {
        my $border_x1     = $slot_layout->{'bounds'}[0];
        my $border_y1     = $slot_layout->{'bounds'}[3];
        my $border_x2     = $slot_layout->{'bounds'}[2];
        my $border_height = 3;
        $slot_layout->{'misc_items'} = [
            [   1, undef,
                'rectangle',
                [   $border_x1, $border_y1,
                    $border_x2, $border_y1 + $border_height
                ],
                { -fill => 'black', }
            ]
        ];
        $slot_layout->{'bounds'}[3] += $border_height + $buffer;
    }

    # Make room for slot specific stuff by displacing the container
    $slot_layout->{'container_bounds'} = [
        $slot_layout->{'bounds'}[0], $slot_layout->{'bounds'}[3],
        $slot_layout->{'bounds'}[2],
    ];
    $slot_layout->{'container_bounds'}[3]
        = $slot_layout->{'container_bounds'}[0];

    # Buttons
    my $button_buffer = 5;
    my $button_x1 = $slot_layout->{'bounds'}[0]+$button_buffer;
    my $button_y1 = $slot_layout->{'bounds'}[3]+$button_buffer;
    my ($button_x2, $button_y2, $button_id,$button_bounds,$button_text, $button_type);

    
    # Zoom In Button
    $button_type = 'zoom_in';
    $button_text = 'Zoom In';
    ($button_id, $button_bounds) = $app_display_data->app_interface()->pre_draw_button(
        window_key => $window_key,
        panel_key => $panel_key,
        slot_key => $slot_key,
        app_display_data=>$app_display_data,
        x1 => $button_x1,
        y1 => $button_y1,
        zoom_value => 2,
        text => $button_text,
        type => $button_type, 
    );
    $button_x2 = $button_bounds->[2]+$button_buffer;
    $button_y2 = $button_bounds->[3]+$button_buffer;
    push @{ $slot_layout->{'buttons'} },
        {
        changed    => 0,
        text       => $button_text,
        type       => $button_type,
        zoom_value => 2,
        window_key => $window_key,
        panel_key  => $panel_key,
        slot_key   => $slot_key,
        item_id    => $button_id,
        };
    $slot_layout->{'container_bounds'}[0] = $button_x2;
    
    


    if ( $app_display_data->{'scaffold'}{$window_key}{$panel_key}{$slot_key}
        {'attached_to_parent'} )
    {

        # These maps are features of the parent map
        _layout_sub_maps(
            window_key       => $window_key,
            panel_key        => $panel_key,
            slot_key         => $slot_key,
            app_display_data => $app_display_data,
        );
    }
    else {

        # These maps are "reference" maps
        _layout_reference_maps(
            window_key       => $window_key,
            panel_key        => $panel_key,
            slot_key         => $slot_key,
            app_display_data => $app_display_data,
        );
    }

    $panel_layout->{'sub_changed'} = 1;
    $slot_layout->{'changed'}      = 1;

    return;
}

# ----------------------------------------------------
sub _layout_reference_maps {

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

    my $left_bound  = $slot_layout->{'container_bounds'}[0] + $map_x_buffer;
    my $right_bound = $slot_layout->{'container_bounds'}[2] - $map_x_buffer;
    my $slot_width  = $right_bound - $left_bound;
    my $maps_num
        = scalar( @{ $app_display_data->{'map_order'}{$slot_key} || [] } );

    return unless ($slot_width);

    my $start_height = 0;

    my @ordered_map_ids = map { $app_display_data->{'map_key_to_id'}{$_} }
        @{ $app_display_data->{'map_order'}{$slot_key} || [] };
    my $map_data_hash = $app_display_data->app_data_module()
        ->map_data_hash( map_ids => \@ordered_map_ids, );

    my $pixels_per_unit = 1;
    if ($stacked) {

        # Layout maps on top of each other
        my $longest_length = 0;
        foreach my $map_id (@ordered_map_ids) {
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
        my $length_sum = 0;
        foreach my $map_id (@ordered_map_ids) {
            my $map       = $map_data_hash->{$map_id};
            my $map_start = $map->{'map_start'};
            my $map_stop  = $map->{'map_stop'};
            $length_sum += $map->{'map_stop'} - $map->{'map_start'};
        }
        my $buffer_space = ( 1 + scalar(@ordered_map_ids) ) * $map_x_buffer;
        $pixels_per_unit = ( $slot_width - $buffer_space ) / $length_sum;
    }

    my $row_max_x   = $left_bound;
    my $row_min_y   = $slot_layout->{'container_bounds'}[1];
    my $start_min_y = $row_min_y;
    $row_min_y += $map_y_buffer;
    my $row_max_y = $row_min_y;

    foreach
        my $map_key ( @{ $app_display_data->{'map_order'}{$slot_key} || [] } )
    {
        my $map_id = $app_display_data->{'map_key_to_id'}{$map_key};
        my $map    = $map_data_hash->{$map_id};
        my $length = $map->{'map_stop'} - $map->{'map_start'};
        my $map_container_width = $length * $pixels_per_unit;

        $map_container_width = $min_map_width
            if ( $map_container_width < $min_map_width );

        if ( $stacked or $row_max_x + $map_container_width > $right_bound ) {
            $row_max_x = $left_bound;
            $row_min_y = $row_max_y + $map_y_buffer;
        }
        my $tmp_map_max_y = _layout_contained_map(
            app_display_data => $app_display_data,
            window_key       => $window_key,
            panel_key        => $panel_key,
            slot_key         => $slot_key,
            map_key          => $map_key,
            map              => $map,
            min_x            => $row_max_x,
            width            => $map_container_width,
            min_y            => $row_min_y,
            pixels_per_unit  => $pixels_per_unit,
        );
        if ( $row_max_y < $tmp_map_max_y ) {
            $row_max_y = $tmp_map_max_y;
        }

        $row_max_x += $map_container_width + $map_x_buffer;
        $app_display_data->{'map_layout'}{$map_key}{'changed'} = 1;
    }

    my $height_change = $row_max_y - $start_min_y + $map_y_buffer;
    $app_display_data->modify_slot_bottom_bound(
        slot_key         => $slot_key,
        bounds_change    => $height_change,
        container_change => $height_change,
    );

    $slot_layout->{'sub_changed'} = 1;
    return;
}

# ----------------------------------------------------
sub _layout_sub_maps {

=pod

=head2 _layout_sub_maps

Lays out sub maps in a new slot.  They are assumed to be
attached to and of the same scale as the parent slot.

=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $panel_key        = $args{'panel_key'};
    my $slot_key         = $args{'slot_key'};
    my $app_display_data = $args{'app_display_data'};
    my $slot_layout      = $app_display_data->{'slot_layout'}{$slot_key};

    #  Options that should be defined elsewhere
    my $map_x_buffer = 15;
    my $map_y_buffer = 15;

    my $start_min_y = $slot_layout->{'container_bounds'}[1];

    # Sort maps for easier layout
    my @sub_map_keys = sort {
        $app_display_data->{'sub_maps'}{$a}{'parent_key'}
            < $app_display_data->{'sub_maps'}{$b}{'parent_key'}
            || $app_display_data->{'sub_maps'}{$a}{'feature_start'}
            < $app_display_data->{'sub_maps'}{$b}{'feature_start'}
            || $app_display_data->{'sub_maps'}{$a}{'feature_stop'}
            < $app_display_data->{'sub_maps'}{$b}{'feature_stop'}

    } @{ $app_display_data->{'map_order'}{$slot_key} || [] };

    my @row_distribution_aray;
    my @rows;

    my $current_parent_key = '-1';
    my ( $parent_x1, $parent_x2, $parent_data, $parent_start, $parent_stop,
        $parent_id, $pixels_per_unit, );
    my %pixels_per_unit;

    foreach my $sub_map_key (@sub_map_keys) {
        my $parent_key
            = $app_display_data->{'sub_maps'}{$sub_map_key}{'parent_key'};
        my $feature_start
            = $app_display_data->{'sub_maps'}{$sub_map_key}{'feature_start'};
        my $feature_stop
            = $app_display_data->{'sub_maps'}{$sub_map_key}{'feature_stop'};
        unless ( $parent_key eq $current_parent_key ) {
            $current_parent_key = $parent_key;
            $parent_id = $app_display_data->{'map_key_to_id'}{$parent_key};
            $parent_x1
                = $app_display_data->{'map_layout'}{$current_parent_key}
                {'bounds'}[0];
            $parent_x2
                = $app_display_data->{'map_layout'}{$current_parent_key}
                {'bounds'}[2];
            $parent_data = $app_display_data->app_data_module()
                ->map_data( map_id => $parent_id, );
            $parent_start    = $parent_data->{'map_start'};
            $parent_stop     = $parent_data->{'map_stop'};
            $pixels_per_unit = ( $parent_x2 - $parent_x1 + 1 ) /
                ( $parent_data->{'map_stop'} - $parent_data->{'map_start'} );
            $pixels_per_unit{$parent_key} = $pixels_per_unit;
        }

        my $x1 = $parent_x1
            + ( ( $feature_start - $parent_start ) * $pixels_per_unit );
        my $x2 = $parent_x1
            + ( ( $feature_stop - $parent_start ) * $pixels_per_unit );

        my $adjusted_left  = $x1 - $parent_x1;
        my $adjusted_right = $x2 - $parent_x1;
        my $row_index      = simple_column_distribution(
            low        => $adjusted_left,
            high       => $adjusted_right,
            columns    => \@row_distribution_aray,
            map_height => $parent_x2 - $parent_x1 + 1,
            buffer     => $map_y_buffer,
        );

        push @{ $rows[$row_index] }, [ $sub_map_key, $x1, $x2 ];
    }

    my $row_min_y = $start_min_y + $map_y_buffer;
    my $row_max_y = $row_min_y;

    foreach my $row (@rows) {
        foreach my $row_sub_map ( @{ $row || [] } ) {
            my $sub_map_key = $row_sub_map->[0];
            my $x1          = $row_sub_map->[1];
            my $x2          = $row_sub_map->[2];
            my $sub_map_id
                = $app_display_data->{'map_key_to_id'}{$sub_map_key};
            my $sub_map_data = $app_display_data->app_data_module()
                ->map_data( map_id => $sub_map_id, );
            my $parent_key
                = $app_display_data->{'sub_maps'}{$sub_map_key}{'parent_key'};

            my $tmp_map_max_y = _layout_contained_map(
                app_display_data => $app_display_data,
                window_key       => $window_key,
                panel_key        => $panel_key,
                slot_key         => $slot_key,
                map_key          => $sub_map_key,
                map              => $sub_map_data,
                min_x            => $x1,
                width            => $x2 - $x1 + 1,
                min_y            => $row_min_y,
                pixels_per_unit  => $pixels_per_unit{$parent_key},
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
        slot_key         => $slot_key,
        bounds_change    => $height_change,
        container_change => $height_change,
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
    my $min_y            = $args{'min_y'};
    my $width            = $args{'width'};
    my $pixels_per_unit  = $args{'pixels_per_unit'};

    my $buffer = 2;

    my $x1 = $min_x;
    my $y1 = $min_y;
    my $x2 = $x1 + $width;
    my $y2;

    my $map_layout = $app_display_data->{'map_layout'}{$map_key};

    push @{ $map_layout->{'items'} },
        (
        [   1, undef, 'text',
            [ $x1, $y1 ],
            {   -text   => $map->{'map_name'},
                -anchor => 'nw',
                -fill   => 'black',
            }
        ]
        );

    $y1 += 15;
    $y2 = $y1 + 5;
    push @{ $map_layout->{'items'} },
        (
        [   1, undef,
            'rectangle', [ $x1, $y1, $x2, $y2 ],
            { -fill => 'blue', }
        ]
        );

    $y1 = $y2 + $buffer;

    if ( $app_display_data->{'scaffold'}{$window_key}{$panel_key}{$slot_key}
        {'expanded'} )
    {
        $y2 = _layout_features(
            app_display_data => $app_display_data,
            slot_key         => $slot_key,
            map_key          => $map_key,
            map              => $map,
            min_x            => $x1,
            width            => $width,
            min_y            => $y1,
            pixels_per_unit  => $pixels_per_unit,
        );
    }
    $map_layout->{'bounds'} = [ $x1, $min_y, $x2, $y2 ];

    $map_layout->{'sub_changed'} = 1;

    return $y2;
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
    my $width            = $args{'width'};
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
                map_height => $width,
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

