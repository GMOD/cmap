package Bio::GMOD::CMap::Drawer::AppLayout;

# vim: set ft=perl:

# $Id: AppLayout.pm,v 1.2 2006-03-15 13:58:43 mwz444 Exp $

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
require Exporter;
use vars qw( $VERSION @EXPORT @EXPORT_OK );
$VERSION = (qw$Revision: 1.2 $)[-1];

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
            += ( $app_display_data->{'slot_layout'}{$slot_key}{'bounds'}[3]
                - $app_display_data->{'slot_layout'}{$slot_key}{'bounds'}[1]
            );
    }

    $app_display_data->modify_panel_bottom_bound(
        panel_key        => $panel_key,
        bounds_change    => $panel_height_change,
        container_change => $panel_height_change,
    );

    # Handle border
    $panel_layout->{'bounds'}[3]
        = $panel_layout->{'container_bounds'}[3] + $panel_border_width;
    $panel_layout->{'border'} = [
        [   1, undef, 'rectangle',
            [ @{ $panel_layout->{'bounds'} } ],
            { -width => $panel_border_width, }
        ],
    ];

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

    # Initialize bounds to the container bounds of the panel
    # starting at the lowest point available.
    # But have a height of 0.
    $slot_layout->{'bounds'} = [
        $panel_layout->{'container_bounds'}[0],
        $panel_layout->{'container_bounds'}[3],
        $panel_layout->{'container_bounds'}[2],
        $panel_layout->{'container_bounds'}[3],
    ];

    # Make room for slot specific stuff by displacing the container
    $slot_layout->{'container_bounds'} = [
        $slot_layout->{'bounds'}[0], $slot_layout->{'bounds'}[1],
        $slot_layout->{'bounds'}[2],
    ];
    $slot_layout->{'container_bounds'}[3]
        = $slot_layout->{'container_bounds'}[0];

    if ( $app_display_data->{'scaffold'}{$window_key}{$panel_key}{$slot_key}
        {'sub_maps'}
        and my $parent_slot_key
        = $app_display_data->{'scaffold'}{$window_key}{$panel_key}{$slot_key}
        {'parent'} )
    {

        # These maps are features of the parent map

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

Lays out a reference maps in a new slot

=cut

    my %args             = @_;
    my $window_key       = $args{'window_key'};
    my $panel_key        = $args{'panel_key'};
    my $slot_key         = $args{'slot_key'};
    my $app_display_data = $args{'app_display_data'};
    my $slot_layout      = $app_display_data->{'slot_layout'}{$slot_key};

    my $left_bound  = $slot_layout->{'container_bounds'}[0];
    my $right_bound = $slot_layout->{'container_bounds'}[2];
    my $slot_width  = $right_bound - $left_bound;
    my $maps_num    = scalar( keys( %{ $slot_layout->{'maps'} || {} } ) );

    return unless ($slot_width);

    my $start_height = 0;

    #  Options that should be defined elsewhere
    my $stacked       = 1;
    my $min_map_width = 40;
    my $map_x_buffer  = 5;
    my $map_y_buffer  = 5;

    my @ordered_map_ids = map { $app_display_data->{'map_key_to_id'}{$_} }
        @{ $app_display_data->{'map_order'}{$slot_key} || [] };
    my $map_data_hash = $app_display_data->app_data_module()
        ->map_data_hash( map_ids => \@ordered_map_ids, );

    my $length_conversion_factor = 1;
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
        $length_conversion_factor
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
        $length_conversion_factor
            = ( $slot_width - $buffer_space ) / $length_sum;
    }

    my $row_max_x   = $left_bound;
    my $row_min_y   = $slot_layout->{'container_bounds'}[1];
    my $row_max_y   = $row_min_y;
    my $start_min_y = $row_min_y;

    foreach
        my $map_key ( @{ $app_display_data->{'map_order'}{$slot_key} || [] } )
    {
        my $map_id = $app_display_data->{'map_key_to_id'}{$map_key};
        my $map    = $map_data_hash->{$map_id};
        my $length = $map->{'map_stop'} - $map->{'map_start'};
        my $map_container_width = $length * $length_conversion_factor;

        $map_container_width = $min_map_width
            if ( $map_container_width < $min_map_width );

        if ( $stacked or $row_max_x + $map_container_width > $right_bound ) {
            $row_max_x = $left_bound;
            $row_min_y = $row_max_y + $map_y_buffer;
        }
        my $tmp_map_max_y = _layout_contained_map(
            app_display_data         => $app_display_data,
            slot_key                 => $slot_key,
            map_key                  => $map_key,
            map                      => $map,
            min_x                    => $row_max_x,
            width                    => $map_container_width,
            min_y                    => $row_min_y,
            length_conversion_factor => $length_conversion_factor,
        );
        if ( $row_max_y < $tmp_map_max_y ) {
            $row_max_y = $tmp_map_max_y;
        }

        $row_max_x += $map_container_width + $map_x_buffer;
        $slot_layout->{'maps'}{$map_key}{'changed'} = 1;
    }

    my $height_change = $row_max_y - $start_min_y;
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

    my %args                     = @_;
    my $app_display_data         = $args{'app_display_data'};
    my $slot_key                 = $args{'slot_key'};
    my $map_key                  = $args{'map_key'};
    my $map                      = $args{'map'};
    my $min_x                    = $args{'min_x'};
    my $min_y                    = $args{'min_y'};
    my $width                    = $args{'width'};
    my $length_conversion_factor = $args{'length_conversion_factor'};

    my $buffer = 4;

    my $x1 = $min_x;
    my $y1 = $min_y;
    my $x2 = $x1 + $width;
    my $y2;

    my $map_layout
        = $app_display_data->{'slot_layout'}{$slot_key}{'maps'}{$map_key};

    push @{ $map_layout->{'data'} },
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
    push @{ $map_layout->{'data'} },
        (
        [   1, undef,
            'rectangle', [ $x1, $y1, $x2, $y2 ],
            { -fill => 'blue', }
        ]
        );

    $y1 = $y2 + $buffer;

    $y2 = _layout_features(
        app_display_data         => $app_display_data,
        slot_key                 => $slot_key,
        map_key                  => $map_key,
        map                      => $map,
        min_x                    => $x1,
        width                    => $width,
        min_y                    => $y1,
        length_conversion_factor => $length_conversion_factor,
    );

    $map_layout->{'sub_changed'} = 1;

    return $y2;
}

# ----------------------------------------------------
sub _layout_features {

=pod

=head2 _layout_features

Lays out feautures 

=cut

    my %args                     = @_;
    my $app_display_data         = $args{'app_display_data'};
    my $slot_key                 = $args{'slot_key'};
    my $map_key                  = $args{'map_key'};
    my $map                      = $args{'map'};
    my $min_x                    = $args{'min_x'};
    my $min_y                    = $args{'min_y'};
    my $width                    = $args{'width'};
    my $length_conversion_factor = $args{'length_conversion_factor'};

    my $buffer = 4;

    my $x1 = $min_x;
    my $y1 = $min_y;
    my $x2 = $x1 + $width;
    my $max_y;

    my $feature_data = $app_display_data->app_data_module()
        ->feature_data( map_id => $map->{'map_id'} );

    unless ( @{ $feature_data || [] } ) {
        return $min_y;
    }

    my $map_start = $map->{'map_start'};

    foreach my $feature ( @{ $feature_data || [] } ) {
        my $feature_acc   = $feature->{'feature_acc'};
        my $feature_start = $feature->{'feature_start'};
        my $feature_stop  = $feature->{'feature_stop'};
        my $direction     = $feature->{'direction'};
        unless (
            $app_display_data->{'slot_layout'}{$slot_key}{'maps'}{$map_key}
            {'features'}{$feature_acc} )
        {
            $app_display_data->{'slot_layout'}{$slot_key}{'maps'}{$map_key}
                {'features'}{$feature_acc} = {};
        }
        my $feature_layout
            = $app_display_data->{'slot_layout'}{$slot_key}{'maps'}{$map_key}
            {'features'}{$feature_acc};

        my $x1 = $min_x
            + ( ( $feature_start - $map_start ) * $length_conversion_factor );
        my $x2 = $min_x
            + ( ( $feature_stop - $map_start ) * $length_conversion_factor );
        my $y1 = $min_y;

        push @{ $feature_layout->{'data'} },
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
        my $y2 = $y1 + 2;
        push @{ $feature_layout->{'data'} },
            (
            [   1, undef,
                'rectangle', [ $x1, $y1, $x2, $y2 ],
                { -fill => 'red', }
            ]
            );
        $feature_layout->{'changed'} = 1;
    }

   #TEMPORARY until I get some real code in here to do the vertical separation
    $max_y = $min_y + 25;
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

