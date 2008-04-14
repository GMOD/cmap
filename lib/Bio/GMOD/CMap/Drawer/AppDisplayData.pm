package Bio::GMOD::CMap::Drawer::AppDisplayData;

# vim: set ft=perl:

# $Id: AppDisplayData.pm,v 1.91 2008-04-14 18:46:03 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Drawer::AppDisplayData - Holds display data

=head1 SYNOPSIS

=head1 DESCRIPTION

Holds and modifies the display data.

=head1 Usage

=head2 Fields

=over 4

=item * data_source

The "data_source" parameter is a string of the name of the data source
to be used.  This information is found in the config file as the
"<database>" name field.

Defaults to the default database.

=item * config

A Bio::GMOD::CMap::Config object that can be passed to this module if
it has already been created.  Otherwise, AppDisplayData will create it from 
the data_source.

=item * app_data_module

A Bio::GMOD::CMap::Data::AppData object
it has already been created.  

=item * app_interface

A Bio::GMOD::CMap::Drawer::AppInterface object.
it has already been created.  

=back

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.91 $)[-1];

use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Drawer::AppLayout qw[
    layout_new_window
    layout_zone
    layout_overview
    overview_selected_area
    layout_head_maps
    layout_sub_maps
    add_correspondences
    add_zone_separator
    set_zone_bgcolor
    destroy_map_for_relayout
];
use Bio::GMOD::CMap::Utils qw[
    round_to_granularity
];

use Data::Dumper;
use base 'Bio::GMOD::CMap';

# ----------------------------------------------------
sub init {

=pod

=head2 init

Initializes the drawing object.

=cut

    my ( $self, $config ) = @_;

    for my $param (qw[ config data_source app_interface app_data_module ]) {
        $self->$param( $config->{$param} )
            or die "Failed to pass $param to AppDisplayData\n";
    }
    $self->{'next_map_set_color_index'} = 0;

    return $self;
}

# ----------------------------------------------------
sub app_data_module {

=pod

=head3 app_data_module

Returns a handle to the data module.

=cut

    my $self = shift;

    $self->{'app_data_module'} = shift if @_;

    return $self->{'app_data_module'};
}

# ----------------------------------------------------
sub app_interface {

=pod

=head3 app_interface

Returns a handle to the data module.

=cut

    my $self = shift;

    $self->{'app_interface'} = shift if @_;

    return $self->{'app_interface'};
}

# ----------------------------------------------------
sub create_window {

=pod

=head2 create_window

Adds the first slot

=cut

    my ( $self, %args ) = @_;
    my $title = $args{'title'};

    my $window_key = $self->next_internal_key('window');

    $self->set_default_window_layout( window_key => $window_key, );

    $self->app_interface()->int_create_window(
        window_key       => $window_key,
        app_display_data => $self,
    );

    return $window_key;
}

# ----------------------------------------------------
sub dd_load_new_window {

=pod

=head2 dd_load_new_window

Adds the first slot

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $map_ids    = $args{'map_ids'};

    # Remove old info if any
    if ( $self->{'zone_in_window'}{$window_key} ) {
        $self->clear_window( window_key => $window_key, );
    }

    my $zone_key = $self->initialize_zone(
        window_key => $window_key,
        map_set_id => $self->get_map_set_id_from_map_id( $map_ids->[0] ),
        attached_to_parent      => 0,
        expanded                => 1,
        is_top                  => 1,
        show_features           => 1,
        map_labels_visible      => 1,
        offscreen_corrs_visible => 0,
    );

    $self->{'head_zone_key'}{$window_key} = $zone_key;
    $self->{'overview'}{$window_key}{'zone_key'} = $zone_key;

    $self->set_default_window_layout( window_key => $window_key, );

    # Initialize maps in the head zone
    foreach my $map_id ( @{ $map_ids || [] } ) {
        my $map_key = $self->initialize_map(
            map_id       => $map_id,
            zone_key     => $zone_key,
            draw_flipped => 0,
        );
    }

    # Handle overview after the regular zones, so we can use that info
    $self->{'overview'}{$window_key} = {
        zone_key => $zone_key,    # top zone in overview
    };
    $self->initialize_overview_layout($window_key);

    layout_new_window(
        window_key       => $window_key,
        head_zone_key    => $zone_key,
        app_display_data => $self,
    );

    #layout_overview(
    #    window_key       => $window_key,
    #    app_display_data => $self,
    #);

    $self->change_selected_zone( zone_key => $zone_key, );

    return;
}

# ----------------------------------------------------
sub create_head_zone_from_saved_view {

=pod

=head2 create_zone_from_saved_view

Do a breadth first traversal of the structure to keep the zone keys ordered by
hierarchy

  # this contains the granular details.
  $zone_hash = {
    map_set_acc => $map_set_acc,
    map=>[
      {
        map_acc=> $map_acc,
        child_zone => [
          {
            recursive call;
          },
        ],
      },
    ],
  };


=cut

    my ( $self, %args ) = @_;
    my $window_key     = $args{'window_key'};
    my $zone_view_data = $args{'zone_view_data'};

    if ( ref( $zone_view_data->{'map'} ) eq 'HASH' ) {
        $zone_view_data->{'map'} = [ $zone_view_data->{'map'} ];
    }
    return unless ( @{ $zone_view_data->{'map'} || [] } );

    my $representative_map_acc = $zone_view_data->{'map'}[0]{'map_acc'};
    my $map_data               = $self->app_data_module()
        ->map_data( map_acc => $representative_map_acc, );
    return unless ( %{ $map_data || {} } );

    my $zone_key = $self->initialize_zone(
        window_key              => $window_key,
        map_set_id              => $map_data->{'map_set_id'},
        attached_to_parent      => 0,
        expanded                => 0,
        is_top                  => 1,
        show_features           => 1,
        map_labels_visible      => 1,
        offscreen_corrs_visible => 0,
    );

    $self->{'head_zone_key'}{$window_key} = $zone_key;
    $self->{'overview'}{$window_key}{'zone_key'} = $zone_key;

    my $zone_view_data_queue = [];

    $zone_view_data_queue = $self->create_maps_from_saved_view(
        zone_key             => $zone_key,
        zone_view_data       => $zone_view_data,
        zone_view_data_queue => $zone_view_data_queue,
    );

    while ( @{ $zone_view_data_queue || [] } ) {
        $zone_view_data_queue = $self->create_sub_zone_from_saved_view(
            window_key           => $window_key,
            zone_view_data_queue => $zone_view_data_queue,
        );
    }

    return $zone_key;
}

# ----------------------------------------------------
sub create_sub_zone_from_saved_view {

=pod

=head2 create_sub_zone_from_saved_view

=cut

    my ( $self, %args ) = @_;
    my $window_key           = $args{'window_key'}           or return;
    my $zone_view_data_queue = $args{'zone_view_data_queue'} or return;

    my $zone_view_data = shift @{$zone_view_data_queue};
    my @sub_map_keys;

    my $parent_map_id   = $zone_view_data->{'parent_map_id'};
    my $parent_map_key  = $zone_view_data->{'parent_map_key'};
    my $parent_zone_key = $zone_view_data->{'parent_zone_key'};

    $self->{'scaffold'}{$parent_zone_key}{'expanded'}  = 1;
    $self->{'map_layout'}{$parent_map_key}{'expanded'} = 1;

    my $parent_map_data = $self->app_data_module()
        ->map_data( map_id => $self->map_key_to_id($parent_map_key), );
    my $parent_unit_granularity
        = $self->map_type_data( $parent_map_data->{'map_type_acc'},
        'unit_granularity' )
        || 0;

    # Collect Sub-Maps
    my $sub_maps
        = $self->app_data_module()->sub_maps( map_id => $parent_map_id, );
    return unless ( @{ $sub_maps || [] } );

    my %sub_maps_hash;

    foreach my $sub_map (@$sub_maps) {
        my $sub_map_id = $sub_map->{'sub_map_id'};

        $sub_maps_hash{$sub_map_id} = {
            parent_map_key    => $parent_map_key,
            feature_start     => $sub_map->{'feature_start'},
            feature_stop      => $sub_map->{'feature_stop'},
            feature_id        => $sub_map->{'feature_id'},
            feature_type_acc  => $sub_map->{'feature_type_acc'},
            feature_direction => $sub_map->{'direction'},
            feature_length    => (
                      $sub_map->{'feature_stop'} 
                    - $sub_map->{'feature_start'}
                    + $parent_unit_granularity
            ),
        };
    }

    unless ( $zone_view_data->{'map'} ) {

        # No Sub Maps
        return;
    }
    my $zone_key = $self->initialize_zone(
        window_key => $window_key,
        map_set_id =>
            $self->get_map_set_id_from_map_id( $sub_maps->[0]{'sub_map_id'} ),
        parent_zone_key         => $parent_zone_key,
        parent_map_key          => $parent_map_key,
        attached_to_parent      => 1,
        expanded                => 0,
        is_top                  => 0,
        show_features           => 0,
        map_labels_visible      => 1,
        offscreen_corrs_visible => 0,
    );

    $zone_view_data_queue = $self->create_maps_from_saved_view(
        zone_key             => $zone_key,
        zone_view_data       => $zone_view_data,
        zone_view_data_queue => $zone_view_data_queue,
        sub_maps_hash        => \%sub_maps_hash,
    );

    return $zone_view_data_queue;
}

# ----------------------------------------------------
sub create_maps_from_saved_view {

=pod

=head2 create_maps_from_saved_view

Adds sub-maps to the view.  Doesn't do any sanity checking.

=cut

    my ( $self, %args ) = @_;
    my $zone_key             = $args{'zone_key'};
    my $zone_view_data       = $args{'zone_view_data'};
    my $zone_view_data_queue = $args{'zone_view_data_queue'} or return;
    my $sub_maps_hash        = $args{'sub_maps_hash'} || {};

    if ( ref( $zone_view_data->{'map'} ) eq 'HASH' ) {
        $zone_view_data->{'map'} = [ $zone_view_data->{'map'} ];
    }

    my @map_accs
        = map { $_->{'map_acc'} } @{ $zone_view_data->{'map'} || [] };
    my $map_data
        = $self->app_data_module()->map_data_array( map_accs => \@map_accs, );

    my %zone_view_by_map_acc
        = map { $_->{'map_acc'} => $_ } @{ $zone_view_data->{'map'} || [] };

    foreach my $map ( @{ $map_data || [] } ) {
        my $map_id  = $map->{'map_id'};
        my $map_key = $self->initialize_map(
            map_id   => $map_id,
            zone_key => $zone_key,
            feature_direction =>
                $sub_maps_hash->{$map_id}{'feature_direction'}
        );

        # set the sub_maps data
        if ( $sub_maps_hash->{$map_id} ) {
            $self->{'sub_maps'}{$map_key} = $sub_maps_hash->{$map_id};
        }

        my $zone_view_map = $zone_view_by_map_acc{ $map->{'map_acc'} };
        if ( ref( $zone_view_map->{'child_zone'} ) eq 'HASH' ) {
            $zone_view_map->{'child_zone'}
                = [ $zone_view_map->{'child_zone'} ];
        }
        foreach my $child_zone ( @{ $zone_view_map->{'child_zone'} || [] } ) {
            $child_zone->{'parent_zone_key'} = $zone_key;
            $child_zone->{'parent_map_key'}  = $map_key;
            $child_zone->{'parent_map_id'}   = $map_id;
            push @{$zone_view_data_queue}, $child_zone;
        }
    }
    return $zone_view_data_queue;
}

# ----------------------------------------------------
sub dd_load_save_in_new_window {

=pod

=head2 dd_load_save_in_new_window

  # this contains the granular details.
  $zone_hash = {
    map_set_acc => $map_set_acc,
    map=>[
      {
        map_acc=> $map_acc,
        child_zone => [
          {
            recursive call;
          },
        ],
      },
    ],
  };


=cut

    my ( $self, %args ) = @_;
    my $window_key      = $args{'window_key'};
    my $saved_view_data = $args{'saved_view_data'};

    # Remove old info if any
    if ( $self->{'zone_in_window'}{$window_key} ) {
        $self->clear_window( window_key => $window_key, );
    }

    $self->set_default_window_layout( window_key => $window_key, );

    my $zone_key = $self->create_head_zone_from_saved_view(
        window_key     => $window_key,
        zone_view_data => $saved_view_data->{'head_zone'},
    );

    $self->initialize_overview_layout($window_key);

    layout_new_window(
        window_key       => $window_key,
        head_zone_key    => $zone_key,
        app_display_data => $self,
    );

    #layout_overview(
    #    window_key       => $window_key,
    #    app_display_data => $self,
    #);

    $self->change_selected_zone( zone_key => $zone_key, );

}

# ----------------------------------------------------
sub add_sub_maps_to_map {

=pod

=head2 add_sub_maps_to_map

Adds sub-maps to the view.  Doesn't do any sanity checking.

=cut

    my ( $self, %args ) = @_;
    my $window_key      = $args{'window_key'}      or return;
    my $parent_zone_key = $args{'parent_zone_key'} or return;
    my $parent_map_key  = $args{'parent_map_key'}  or return;

    return if ( $self->{'map_layout'}{$parent_map_key}{'expanded'} );

    # Mark as expanded
    $self->{'map_layout'}{$parent_map_key}{'expanded'} = 1;

    my $parent_map_id = $self->map_key_to_id($parent_map_key);

    # Collect Sub-Maps
    my $sub_maps
        = $self->app_data_module()->sub_maps( map_id => $parent_map_id, );

    unless ( @{ $sub_maps || [] } ) {

        # No Sub Maps
        return;
    }

    return $self->assign_and_initialize_new_maps(
        window_key      => $window_key,
        sub_maps        => $sub_maps,
        parent_zone_key => $parent_zone_key,
        parent_map_key  => $parent_map_key,
    );
}

# ----------------------------------------------------
sub assign_and_initialize_new_maps {

=pod

=head2 assign_and_initialize_new_maps

=cut

    my ( $self, %args ) = @_;
    my $window_key      = $args{'window_key'}      or return;
    my $sub_maps        = $args{'sub_maps'}        or return;
    my $parent_zone_key = $args{'parent_zone_key'} or return;
    my $parent_map_key  = $args{'parent_map_key'}  or return;

    my $parent_map_data = $self->app_data_module()
        ->map_data( map_id => $self->map_key_to_id($parent_map_key), );
    my $parent_unit_granularity
        = $self->map_type_data( $parent_map_data->{'map_type_acc'},
        'unit_granularity' )
        || 0;

    # Split maps into zones based on their map set
    my %map_ids_by_set;
    my %sub_map_hash;
    foreach my $sub_map ( @{ $sub_maps || [] } ) {
        my $sub_map_id = $sub_map->{'sub_map_id'};
        push @{ $map_ids_by_set{ $sub_map->{'map_set_id'} } }, $sub_map_id;
        $sub_map_hash{$sub_map_id} = $sub_map;
    }

    my %map_id_to_map_key;
    foreach my $set_key ( keys %map_ids_by_set ) {
        my $map_set_id = $self->get_map_set_id_from_map_id(
            $sub_maps->[0]{'sub_map_id'} );

        my $child_zone_key = $self->find_child_zone_for_map_set(
            map_set_id      => $map_set_id,
            parent_map_key  => $parent_map_key,
            parent_zone_key => $parent_zone_key,
        );

        # If it's in a new zone, create the zone
        unless ($child_zone_key) {
            $child_zone_key = $self->initialize_zone(
                window_key              => $window_key,
                map_set_id              => $map_set_id,
                parent_zone_key         => $parent_zone_key,
                parent_map_key          => $parent_map_key,
                attached_to_parent      => 1,
                expanded                => 0,
                is_top                  => 0,
                show_features           => 0,
                map_labels_visible      => 1,
                offscreen_corrs_visible => 0,
            );
        }

        foreach my $sub_map_id ( @{ $map_ids_by_set{$set_key} || [] } ) {
            my $sub_map     = $sub_map_hash{$sub_map_id};
            my $sub_map_key = $self->initialize_map(
                map_id            => $sub_map_id,
                zone_key          => $child_zone_key,
                feature_direction => $sub_map->{'direction'}
            );
            $map_id_to_map_key{$sub_map_id} = $sub_map_key;

            $self->{'sub_maps'}{$sub_map_key} = {
                parent_map_key    => $parent_map_key,
                feature_start     => $sub_map->{'feature_start'},
                feature_stop      => $sub_map->{'feature_stop'},
                feature_id        => $sub_map->{'feature_id'},
                feature_type_acc  => $sub_map->{'feature_type_acc'},
                feature_direction => $sub_map->{'direction'},
                feature_length    => (
                          $sub_map->{'feature_stop'} 
                        - $sub_map->{'feature_start'}
                        + $parent_unit_granularity
                ),
            };

        }
    }
    return \%map_id_to_map_key;
}

=pod

=head2 parse_highlight

Checks to see if what objects are to be highlighted

=cut

# ----------------------------------------------------
sub parse_highlight {

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $highlight_string = $args{'highlight_string'};

    # Wipe highlighted maps first
    $self->{'highlighted_by_name'}{$window_key} = {};

    my @names = map { chomp $_; $_ } split( /\s*,\s*/, $highlight_string );
    foreach my $name (@names) {
        $self->{'highlighted_by_name'}{$window_key}{$name} = 1;
    }

    $self->{'highlight_string'}{$window_key} = join( ", ", @names );

    return;
}

=pod

=head2 get_highlight_string

Return the highlight string

=cut

# ----------------------------------------------------
sub get_highlight_string {

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;

    return $self->{'highlight_string'}{$window_key};
}

# ----------------------------------------------------
sub location_bar_drag {

=pod

=head2 location_bar_drag

The location bar is being dragged, figure out how much to scroll and then do
it.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $zone_key   = $args{'zone_key'};
    my $drag_value = $args{'drag_value'} or return;

    my $zone_layout   = $self->{'zone_layout'}{$zone_key};
    my $zone_scaffold = $self->{'scaffold'}{$zone_key};

    my $scroll_value = -1 * $zone_scaffold->{'scale'} * $drag_value;

    $self->scroll_zone(
        window_key   => $window_key,
        zone_key     => $zone_key,
        scroll_value => $scroll_value,
    );

    return;
}

# ----------------------------------------------------
sub scroll_zone {

=pod

=head2 scroll_zone

Scroll zones

=cut

    my ( $self, %args ) = @_;
    my $window_key   = $args{'window_key'};
    my $zone_key     = $args{'zone_key'};
    my $scroll_value = $args{'scroll_value'} or return;

    $zone_key = $self->get_top_attached_parent( zone_key => $zone_key );
    my $x_offset          = $self->{'scaffold'}{$zone_key}{'x_offset'};
    my $zone_layout       = $self->{'zone_layout'}{$zone_key};
    my $half_screen_width = ( $zone_layout->{'viewable_internal_x2'}
            - $zone_layout->{'viewable_internal_x1'} ) / 2;

    my $scroll_buffer = 50;

    # Halt movement right when on left edge
    if ( $zone_layout->{'internal_bounds'}[0] + $scroll_value + $scroll_buffer
        > $zone_layout->{'viewable_internal_x2'} )
    {
        $scroll_value = $zone_layout->{'viewable_internal_x2'}
            - ( $zone_layout->{'internal_bounds'}[0] + $scroll_buffer );
    }

    # Halt movement left when on right edge
    if ( $zone_layout->{'internal_bounds'}[2] + $scroll_value - $scroll_buffer
        < $zone_layout->{'viewable_internal_x1'} )
    {
        $scroll_value = $zone_layout->{'viewable_internal_x1'}
            - ( $zone_layout->{'internal_bounds'}[2] - $scroll_buffer );
    }

    return unless ($scroll_value);

    layout_zone(
        window_key       => $window_key,
        zone_key         => $zone_key,
        app_display_data => $self,
        relayout         => 1,
        move_offset_x    => $scroll_value,
        move_offset_y    => 0,
    );

    # handle overview highlighting
    if ( $self->{'overview_layout'}{$window_key}{'zones'}{$zone_key} ) {
        $self->destroy_items(
            items =>
                $self->{'overview_layout'}{$window_key}{'zones'}{$zone_key}
                {'viewed_region'},
            window_key  => $window_key,
            is_overview => 1,
        );
        $self->{'overview_layout'}{$window_key}{'zones'}{$zone_key}
            {'viewed_region'} = [];
        overview_selected_area(
            zone_key         => $zone_key,
            window_key       => $window_key,
            app_display_data => $self,
        );
    }

    $self->{'window_layout'}{$window_key}{'sub_changed'} = 1;
    $self->cascade_reset_zone_corrs(
        window_key => $window_key,
        zone_key   => $zone_key,
    );
    $self->app_interface()->draw_window(
        window_key       => $window_key,
        app_display_data => $self,
    );
    return;
}

# ----------------------------------------------------
sub zoom_zone {

=pod

=head2 zoom_zone

Zoom zones

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $zone_key   = $args{'zone_key'};
    my $center_x   = $args{'center_x'};
    my $zoom_value = $args{'zoom_value'} or return;

    $zone_key = $self->get_top_attached_parent( zone_key => $zone_key );

    my $zone_scaffold = $self->{'scaffold'}{$zone_key};

    unless ( $zone_scaffold->{'is_top'} ) {
        return;
    }

    # Don't let it zoom out farther than is useful.
    # Maybe Let it zoom out one farther than to scale
    if ( $zone_scaffold->{'scale'} <= 1 and $zoom_value < 1 ) {
        return;
    }

    my $zone_bounds = $self->{'zone_layout'}{$zone_key}{'bounds'};
    my $zone_width  = $zone_bounds->[2] - $zone_bounds->[0] + 1;

    my $old_scale = $zone_scaffold->{'scale'};
    $self->{'scaffold'}{$zone_key}{'scale'} *= $zoom_value;
    $self->recursively_modify_ppu_for_zoom(
        window_key => $window_key,
        zone_key   => $zone_key,
        zoom_value => $zoom_value,
    );

    my $move_offset_x = $self->get_zooming_offset(
        window_key => $window_key,
        zone_key   => $zone_key,
        zoom_value => $zoom_value,
        old_scale  => $old_scale,
        center_x   => ( $zoom_value > 1 ) ? $center_x : undef,
    );

    # Create new zone bounds for this zone, taking into
    if ( $zone_scaffold->{'is_top'} ) {
        $zone_bounds->[2] += ( $zone_width * $zoom_value ) - $zone_width;
    }

    layout_zone(
        window_key       => $window_key,
        zone_key         => $zone_key,
        app_display_data => $self,
        relayout         => 1,
        zone_bounds      => $zone_bounds,
        move_offset_x    => $move_offset_x,
        move_offset_y    => 0,
        force_relayout   => 1,
    );

    # handle overview highlighting
    if ( $self->{'overview_layout'}{$window_key}{'zones'}{$zone_key} ) {
        $self->destroy_items(
            items =>
                $self->{'overview_layout'}{$window_key}{'zones'}{$zone_key}
                {'viewed_region'},
            window_key  => $window_key,
            is_overview => 1,
        );
        $self->{'overview_layout'}{$window_key}{'zones'}{$zone_key}
            {'viewed_region'} = [];
        overview_selected_area(
            zone_key         => $zone_key,
            window_key       => $window_key,
            app_display_data => $self,
        );
    }

    $self->{'window_layout'}{$window_key}{'sub_changed'} = 1;
    $self->cascade_reset_zone_corrs(
        window_key => $window_key,
        zone_key   => $zone_key,
    );
    $self->app_interface()->draw_window(
        window_key       => $window_key,
        app_display_data => $self,
    );

    return;
}

# ----------------------------------------------------
sub recursively_modify_ppu_for_zoom {

=pod

=head2 recursively_modify_ppu_for_zoom

Zoom zones

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $zone_key   = $args{'zone_key'};
    my $zoom_value = $args{'zoom_value'} or return;

    $self->{'scaffold'}{$zone_key}{'pixels_per_unit'} *= $zoom_value;

    foreach my $child_zone_key (
        @{ $self->{'scaffold'}{$zone_key}{'children'} || [] } )
    {
        if ( $self->{'scaffold'}{$child_zone_key}{'attached_to_parent'} ) {
            $self->recursively_modify_ppu_for_zoom(
                window_key => $window_key,
                zone_key   => $child_zone_key,
                zoom_value => $zoom_value,
            );

            #$self->recursively_wipe_ppu(
            #    window_key => $window_key,
            #    zone_key   => $child_zone_key,
            #    zoom_value => $zoom_value,
            #);
        }
    }

    return;
}

# ----------------------------------------------------
sub recursively_wipe_ppu {

=pod

=head2 recursively_modify_scale_for_zoom

Zoom zones

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $zone_key   = $args{'zone_key'};

    $self->{'scaffold'}{$zone_key}{'pixels_per_unit'} = undef;

    foreach my $child_zone_key (
        @{ $self->{'scaffold'}{$zone_key}{'children'} || [] } )
    {
        if ( $self->{'scaffold'}{$child_zone_key}{'attached_to_parent'} ) {
            $self->recursively_wipe_ppu(
                window_key => $window_key,
                zone_key   => $child_zone_key,
            );
        }
    }

    return;
}

# ----------------------------------------------------
sub overview_scroll_slot {

=pod

=head2 overview_scroll_slot

Scroll slots based on the overview scrolling

=cut

    my ( $self, %args ) = @_;
    my $window_key   = $args{'window_key'};
    my $panel_key    = $args{'panel_key'};
    my $slot_key     = $args{'slot_key'};
    my $scroll_value = $args{'scroll_value'} or return;

    # Don't let the overview break attachment to parent
    if ( $self->{'scaffold'}{$slot_key}{'attached_to_parent'} ) {
        $slot_key = $self->{'scaffold'}{$slot_key}{'parent_zone_key'};
    }

    my $main_scroll_value
        = int( $scroll_value /
            $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key}
            {'scale_factor_from_main'} );

    $self->scroll_slot(
        window_key   => $window_key,
        panel_key    => $panel_key,
        slot_key     => $slot_key,
        scroll_value => $main_scroll_value,
    );

    return;

}

# ----------------------------------------------------
sub get_top_attached_parent {

=pod

=head2 get_top_attached_parent

Crawl the scaffold to find the top zone that is attached.

=cut

    my ( $self, %args ) = @_;
    my $zone_key = $args{'zone_key'};

    while ( $self->{'scaffold'}{$zone_key}{'attached_to_parent'}
        and $self->{'scaffold'}{$zone_key}{'parent_zone_key'}
        and not $self->{'scaffold'}{$zone_key}{'is_top'} )
    {
        $zone_key = $self->{'scaffold'}{$zone_key}{'parent_zone_key'};
    }

    return $zone_key;
}

# ----------------------------------------------------
sub set_corrs_map_set {

=pod

=head2 set_corrs_map_set

Modify the correspondences for a zone

=cut

    my ( $self, %args ) = @_;
    my $window_key   = $args{'window_key'};
    my $zone_key1    = $args{'zone_key'};
    my $map_set_id2  = $args{'map_set_id'};
    my $map_set_ids2 = $args{'map_set_ids'} || [];
    my $corrs_on     = $args{'corrs_on'};

    if ($map_set_id2) {
        push @$map_set_ids2, $map_set_id2;
    }
    foreach $map_set_id2 (@$map_set_ids2) {
        if ($corrs_on) {
            $self->{'zone_to_map_set_correspondences_on'}{$zone_key1}
                {$map_set_id2} = 1;
        }
        else {
            $self->{'zone_to_map_set_correspondences_on'}{$zone_key1}
                {$map_set_id2} = 0;
        }

        foreach my $zone_key2 (
            @{ $self->map_set_id_to_zone_keys($map_set_id2) || [] } )
        {
            if ($corrs_on) {
                $self->add_zone_corrs(
                    window_key => $window_key,
                    zone_key1  => $zone_key1,
                    zone_key2  => $zone_key2,
                );
            }
            else {
                $self->clear_corrs_between_zones(
                    window_key => $window_key,
                    zone_key1  => $zone_key1,
                    zone_key2  => $zone_key2,
                );
            }
        }
    }
    if ($corrs_on) {
        $self->app_interface()->draw_corrs(
            window_key       => $window_key,
            app_display_data => $self,
        );
    }

    return;
}

# ----------------------------------------------------
sub get_slot_comparisons_for_corrs {

=pod

=head2 get_slot_comparisons_for_corrs

Get a list of all the information needed for correspondences, taking into
account the posibility of split/merged maps.

The data structure looks like this

    @slot_comparisons = (
        {   map_id1          => $map_id1,
            slot_info1       => $slot_info1,
            fragment_offset1 => $fragment_offset1,
            slot_info2       => $slot_info2,
            fragment_offset2 => $fragment_offset2,
            map_id2          => $map_id2,
        },
    );

=cut

    my ( $self, %args ) = @_;
    my $window_key            = $args{'window_key'};
    my $zone_key1             = $args{'zone_key1'};
    my $zone_key2             = $args{'zone_key2'};
    my $hide_off_screen_corrs = $args{'hide_off_screen_corrs'};

    ( $zone_key1, $zone_key2 ) = ( $zone_key2, $zone_key1 )
        if ( $zone_key1 > $zone_key2 );

    my $zone1_displayed = $self->is_zone_layed_out($zone_key1);
    my $zone2_displayed = $self->is_zone_layed_out($zone_key2);

    # If neither zone is displayed, just skip it
    # If hiding off screen corrs, make sure both are visible
    return []
        if (
        not( $zone1_displayed or $zone2_displayed )
        or ( $hide_off_screen_corrs
            and not( $zone1_displayed and $zone2_displayed ) )
        );

    my $allow_intramap = 0;
    if ( $zone_key1 == $zone_key2 ) {
        $allow_intramap = 1;
    }
    my $slot_info1 = $self->{'slot_info'}{$zone_key1};
    my @slot_comparisons;
    foreach my $map_key1 ( @{ $self->map_order($zone_key1) } ) {
        my $map_id1       = $self->map_key_to_id($map_key1);
        my $map_pedigree1 = $self->map_pedigree($map_key1);
        my $info_start
            = defined $slot_info1->{$map_id1}[0]
            ? $slot_info1->{$map_id1}[0]
            : $slot_info1->{$map_id1}[2];
        my $info_stop
            = defined $slot_info1->{$map_id1}[1]
            ? $slot_info1->{$map_id1}[1]
            : $slot_info1->{$map_id1}[3];
        if ($map_pedigree1) {
            foreach my $fragment (@$map_pedigree1) {
                my $fragment_start  = $fragment->[0];
                my $fragment_stop   = $fragment->[1];
                my $ancestor_map_id = $fragment->[2];
                my $ancestor_start  = $fragment->[3];
                my $ancestor_stop   = $fragment->[4];

                my $map1_displayed = 0;
                if ($zone1_displayed) {
                    if (   $fragment_stop < $info_start
                        or $fragment_start > $info_stop )
                    {
                        $map1_displayed = 1;
                    }
                }

                # Skip if there are no on screen corrs
                next unless ( $map1_displayed or $zone2_displayed );

                # If hiding off screen corrs, make sure fragment is visible
                next if ( $hide_off_screen_corrs and not $map1_displayed );

                if ( $info_stop < $fragment_stop ) {
                    $ancestor_start -= ( $fragment_stop - $info_stop );
                }
                if ( $info_start > $fragment_start ) {
                    $ancestor_start += ( $info_start - $fragment_start );
                }
                my $map_info1
                    = [ undef, undef, $ancestor_start, $ancestor_stop, 1, ];
                my $fragment_offset1 = $fragment_start - $ancestor_start;
                push @slot_comparisons,
                    $self->_get_slot_comparisons_for_corrs_slot2(
                    map_id1               => $map_id1,
                    map1_displayed        => $map1_displayed,
                    zone2_displayed       => $zone2_displayed,
                    ancestor_map_id1      => $ancestor_map_id,
                    map_info1             => $map_info1,
                    fragment_offset1      => $fragment_offset1,
                    zone_key1             => $zone_key1,
                    zone_key2             => $zone_key2,
                    allow_intramap        => $allow_intramap,
                    hide_off_screen_corrs => $hide_off_screen_corrs,
                    );
            }
        }
        else {
            my $map1_displayed = 0;
            if ( @{ $self->{'map_layout'}{$map_key1}{'items'} || [] } ) {
                $map1_displayed = 1;
            }

            # Skip if there are no on screen corrs
            next unless ( $map1_displayed or $zone2_displayed );

            # If hiding off screen corrs, make sure fragment is visible
            next if ( $hide_off_screen_corrs and not $map1_displayed );

            my $map_info1 = [
                undef, undef,
                $slot_info1->{$map_id1}[2],
                $slot_info1->{$map_id1}[3], 1,
            ];
            push @slot_comparisons,
                $self->_get_slot_comparisons_for_corrs_slot2(
                map_id1               => $map_id1,
                map_info1             => $map_info1,
                map1_displayed        => $map1_displayed,
                zone2_displayed       => $zone2_displayed,
                fragment_offset1      => 0,
                zone_key1             => $zone_key1,
                zone_key2             => $zone_key2,
                allow_intramap        => $allow_intramap,
                hide_off_screen_corrs => $hide_off_screen_corrs,
                );
        }
    }

    return \@slot_comparisons;
}

# ----------------------------------------------------
sub _get_slot_comparisons_for_corrs_slot2 {

=pod

=head2 get_slot_comparisons_for_corrs_slot2

Get a list of all the information needed for correspondences, taking into
account the posibility of split/merged maps.

=cut

    my ( $self, %args ) = @_;
    my $window_key            = $args{'window_key'};
    my $zone_key1             = $args{'zone_key1'};
    my $zone_key2             = $args{'zone_key2'};
    my $map_id1               = $args{'map_id1'};
    my $map1_displayed        = $args{'map1_displayed'};
    my $zone2_displayed       = $args{'zone2_displayed'};
    my $ancestor_map_id1      = $args{'ancestor_map_id1'} || $map_id1;
    my $map_info1             = $args{'map_info1'};
    my $fragment_offset1      = $args{'fragment_offset1'};
    my $allow_intramap        = $args{'allow_intramap'};
    my $hide_off_screen_corrs = $args{'hide_off_screen_corrs'};

    my $slot_info2 = $self->{'slot_info'}{$zone_key2};
    my @slot_comparisons;
    foreach my $map_key2 ( @{ $self->map_order($zone_key2) } ) {
        my $map_id2       = $self->map_key_to_id($map_key2);
        my $map_pedigree2 = $self->map_pedigree($map_key2);
        my $info_start
            = defined $slot_info2->{$map_id2}[0]
            ? $slot_info2->{$map_id2}[0]
            : $slot_info2->{$map_id2}[2];
        my $info_stop
            = defined $slot_info2->{$map_id2}[1]
            ? $slot_info2->{$map_id2}[1]
            : $slot_info2->{$map_id2}[3];
        if ($map_pedigree2) {
            foreach my $fragment (@$map_pedigree2) {
                my $fragment_start   = $fragment->[0];
                my $fragment_stop    = $fragment->[1];
                my $ancestor_map_id2 = $fragment->[2];
                my $ancestor_start   = $fragment->[3];
                my $ancestor_stop    = $fragment->[4];

                my $map2_displayed = 0;
                if ($zone2_displayed) {
                    if (   $fragment_stop < $info_start
                        or $fragment_start > $info_stop )
                    {
                        $map2_displayed = 1;
                    }
                }

                # Skip if there are no on screen corrs
                next unless ( $map1_displayed or $map2_displayed );

                # If hiding off screen corrs, make sure fragment is visible
                next if ( $hide_off_screen_corrs and not $map2_displayed );

                if ( $info_stop < $fragment_stop ) {
                    $ancestor_start -= ( $fragment_stop - $info_stop );
                }
                if ( $info_start > $fragment_start ) {
                    $ancestor_start += ( $info_start - $fragment_start );
                }
                my $map_info2
                    = [ undef, undef, $ancestor_start, $ancestor_stop, 1, ];
                my $fragment_offset2 = $fragment_start - $ancestor_start;
                push @slot_comparisons,
                    {
                    map_id1          => $map_id1,
                    slot_info1       => { $ancestor_map_id1 => $map_info1 },
                    fragment_offset1 => $fragment_offset1,
                    map_id2          => $map_id2,
                    slot_info2       => { $ancestor_map_id2 => $map_info2 },
                    fragment_offset2 => $fragment_offset2,
                    allow_intramap   => $allow_intramap,
                    };
            }
        }
        else {
            my $map2_displayed = 0;
            if ( @{ $self->{'map_layout'}{$map_key2}{'items'} || [] } ) {
                $map2_displayed = 1;
            }

            # Skip if there are no on screen corrs
            next unless ( $map1_displayed or $map2_displayed );

            # If hiding off screen corrs, make sure fragment is visible
            next if ( $hide_off_screen_corrs and not $map2_displayed );

            my $map_info2 = [
                undef, undef,
                $slot_info2->{$map_id1}[2],
                $slot_info2->{$map_id1}[3], 1,
            ];
            push @slot_comparisons,
                {
                map_id1          => $map_id1,
                slot_info1       => { $map_id1 => $map_info1 },
                fragment_offset1 => $fragment_offset1,
                map_id2          => $map_id2,
                slot_info2       => { $map_id2 => $map_info2 },
                fragment_offset2 => 0,
                allow_intramap   => $allow_intramap,
                };
        }
    }

    return @slot_comparisons;
}

# ----------------------------------------------------
sub expand_zone {

=pod

=head2 expand_zone

expand zones

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $zone_key   = $args{'zone_key'};

    my $zone_scaffold = $self->{'scaffold'}{$zone_key};
    my $zone_layout   = $self->{'zone_layout'}{$zone_key};

    return if $zone_scaffold->{'expanded'};
    $zone_scaffold->{'expanded'} = 1;

    foreach my $map_key ( @{ $self->map_order($zone_key) || [] } ) {

        # Add Sub Slots
        $self->add_sub_maps_to_map(
            window_key      => $window_key,
            parent_zone_key => $zone_key,
            parent_map_key  => $map_key,
        );
    }

    # Redraw
    $self->redraw_the_whole_window(
        window_key       => $window_key,
        reset_selections => 1,
    );

    return;
}

# ----------------------------------------------------
sub change_width {

=pod

=head2 change_width

When the width of the window changes, this method will change the size of the
canvases.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $width      = $args{'width'}      or return;

    # Clear canvases
    $self->wipe_window_canvases( window_key => $window_key );

    # Set new width
    $self->{'window_layout'}{$window_key}{'width'} = $width;

    my $head_zone_key = $self->{'head_zone_key'}{$window_key};

    layout_new_window(
        window_key       => $window_key,
        width            => $width,
        head_zone_key    => $head_zone_key,
        app_display_data => $self,
    );

    $self->redraw_the_whole_window(
        window_key  => $window_key,
        skip_layout => 1,
    );

    return;
}

# ----------------------------------------------------
sub get_zooming_offset {

=pod

=head2 get_zooming_offset

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $zone_key   = $args{'zone_key'}   or return;
    my $zoom_value = $args{'zoom_value'} or return;
    my $old_scale  = $args{'old_scale'}  or return;
    my $center_x   = $args{'center_x'};

    my $zone_bounds = $self->{'zone_layout'}{$zone_key}{'bounds'};

    my $old_width      = $zone_bounds->[2] - $zone_bounds->[0] + 1;
    my $viewable_width = $old_width / $old_scale;

    my $new_width = $old_width * $zoom_value;

    my $viewable_section_change
        = ( ( $viewable_width * $zoom_value ) - $viewable_width ) / 2;

    my $center_offset = 0;
    if ( defined $center_x ) {
        $center_offset = int( $center_x - ( $viewable_width / 2 ) + 0.5 );
    }

    my $old_offset = $self->{'scaffold'}{$zone_key}{'x_offset'};
    my $new_offset = ( ( $old_offset - $center_offset ) * $zoom_value )
        - $viewable_section_change;

    # If it zooms out to the point of viewing past the end, push the view over
    my $new_offset_plus_viewable_width
        = ( -1 * $new_offset ) + $viewable_width;
    if ( $new_offset > 0 ) {
        $new_offset = 0;
    }
    if ( $new_offset_plus_viewable_width > $new_width ) {
        $new_offset += $new_offset_plus_viewable_width - $new_width;
    }

    my $offset_dx = $new_offset - $old_offset;

    return $offset_dx;
}

# ----------------------------------------------------
sub map_label_info {

=pod

=head2 map_label_info

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $map_key    = $args{'map_key'}    or return;

    unless ( $self->{'map_label_info'}{$map_key} ) {
        my $map_data = $self->app_data_module()
            ->map_data( map_id => $self->map_key_to_id($map_key), );
        my $text = $map_data->{'map_name'};
        my ( $width, $height, ) = $self->app_interface()->text_dimensions(
            window_key => $window_key,
            text       => $text,
        );
        $self->{'map_label_info'}{$map_key} = {
            text   => $text,
            width  => $width,
            height => $height,
        };
    }

    return $self->{'map_label_info'}{$map_key};
}

# ----------------------------------------------------
sub change_selected_zone {

=pod

=head2 change_selected_zone

=cut

    my ( $self, %args ) = @_;
    my $zone_key = $args{'zone_key'} or return;
    my $window_key = $self->{'scaffold'}{$zone_key}{'window_key'};

    my $old_selected_zone_key = $self->{'selected_zone_key'};
    $self->{'selected_zone_key'} = $zone_key;

    return
        if ( $old_selected_zone_key and $old_selected_zone_key == $zone_key );

    if (    $old_selected_zone_key
        and $self->{'scaffold'}{$old_selected_zone_key} )
    {
        set_zone_bgcolor(
            window_key       => $window_key,
            zone_key         => $old_selected_zone_key,
            app_display_data => $self,
        );
    }
    set_zone_bgcolor(
        window_key       => $window_key,
        zone_key         => $zone_key,
        app_display_data => $self,
    );

    my $map_set_id   = $self->{'scaffold'}{$zone_key}{'map_set_id'};
    my $map_set_data = $self->app_data_module()
        ->get_map_set_data( map_set_id => $map_set_id, );

    $self->app_interface()->int_new_selected_zone(
        map_set_data     => $map_set_data,
        zone_key         => $zone_key,
        app_display_data => $self,
    );

    $self->app_interface()->draw_window(
        window_key       => $window_key,
        app_display_data => $self,
    );

    return;
}

# ----------------------------------------------------
sub zone_bgcolor {

=pod

=head2 zone_bgcolor

=cut

    my ( $self, %args ) = @_;
    my $zone_key = $args{'zone_key'} or return;

    my $map_set_id = $self->{'scaffold'}{$zone_key}{'map_set_id'};

    unless ($self->{'map_set_bgcolor'}
        and $self->{'map_set_bgcolor'}{$map_set_id} )
    {

        my $ms_color_index = $self->{'next_map_set_color_index'} ||= 0;

        $self->{'map_set_bgcolor'}{$map_set_id}
            = APP_BACKGROUND_COLORS->[$ms_color_index];

        # Create new next ms color index
        $self->{'next_map_set_color_index'}++;
        if ($self->{'next_map_set_color_index'} > $#{&APP_BACKGROUND_COLORS} )
        {
            $self->{'next_map_set_color_index'} = 0;
        }
    }

    return $self->{'map_set_bgcolor'}{$map_set_id};
}

# ----------------------------------------------------
sub detach_zone_from_parent {

=pod

=head2 detach_zone_from_parent

FUTURE_FEATURE

=cut

    # No longer allowing zones to detach

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $zone_key   = $args{'zone_key'}   or return;

    $self->{'scaffold'}{$zone_key}{'attached_to_parent'} = 0;
    $self->{'zone_layout'}{$zone_key}{'changed'}         = 1;

    set_zone_bgcolor(
        window_key       => $window_key,
        zone_key         => $zone_key,
        app_display_data => $self,
    );
    $self->app_interface()->draw_window(
        window_key       => $window_key,
        app_display_data => $self,
    );

    return;
}

# ----------------------------------------------------
sub reattach_zone {

=pod

=head2 reattach_zone

Reattach a zone

=cut

    my ( $self, %args ) = @_;
    my $window_key                  = $args{'window_key'};
    my $zone_key                    = $args{'zone_key'};
    my $cascading                   = $args{'cascading'} || 0;
    my $unattached_child_zoom_value = $args{'unattached_child_zoom_value'}
        || 0;
    my $scroll_value = $args{'scroll_value'} || 0;

    my $zone_scaffold = $self->{'scaffold'}{$zone_key};

    if ( $zone_scaffold->{'is_top'} ) {
        return;
    }

    $zone_scaffold->{'scale'}    = 1;
    $zone_scaffold->{'x_offset'} = 0;

    $zone_scaffold->{'attached_to_parent'} = 1;
    $self->{'zone_layout'}{$zone_key}{'changed'} = 1;

    $self->{'window_layout'}{$window_key}{'sub_changed'} = 1;
    $self->cascade_reset_zone_corrs(
        window_key => $window_key,
        zone_key   => $zone_key,
    );

    layout_zone(
        window_key       => $window_key,
        zone_key         => $zone_key,
        app_display_data => $self,
        relayout         => 1,
        move_offset_x    => 0,
        move_offset_y    => 0,
    );
    set_zone_bgcolor(
        window_key       => $window_key,
        zone_key         => $zone_key,
        app_display_data => $self,
    );
    $self->app_interface()->draw_window(
        window_key       => $window_key,
        app_display_data => $self,
    );

    return;
}

# ----------------------------------------------------
sub attach_slot_to_parent {

=pod

=head2 attach_slot_to_parent

FUTURE_FEATURE

=cut

    my ( $self, %args ) = @_;
    my $slot_key  = $args{'slot_key'}  or return;
    my $panel_key = $args{'panel_key'} or return;

    $self->{'scaffold'}{$slot_key}{'attached_to_parent'} = 1;
    $self->{'slot_layout'}{$slot_key}{'changed'}         = 1;

    $self->destroy_items(
        items     => $self->{'slot_layout'}{$slot_key}{'separator'},
        panel_key => $panel_key,
    );
    $self->{'slot_layout'}{$slot_key}{'separator'} = [];

    return;
}

# ----------------------------------------------------
sub map_labels_visible {

=pod

=head2 map_labels_visible

=cut

    my $self     = shift;
    my $zone_key = shift or return;
    my $value    = shift;

    if ( defined $value ) {
        $self->{'map_labels_visible'}{$zone_key} = $value;
    }

    return $self->{'map_labels_visible'}{$zone_key};
}

# ----------------------------------------------------
sub set_map_labels_visibility {

=pod

=head2 set_map_labels_visibility

=cut

    my $self     = shift;
    my $zone_key = shift or return;
    my $value    = shift;

    $self->map_labels_visible( $zone_key, $value, );

    my $window_key = $self->{'scaffold'}{$zone_key}{'window_key'};

    # Redraw
    $self->redraw_the_whole_window( window_key => $window_key, );

    return 1;
}

# ----------------------------------------------------
sub offscreen_corrs_visible {

=pod

=head2 offscreen_corrs_visible

=cut

    my $self     = shift;
    my $zone_key = shift or return;
    my $value    = shift;

    if ( defined $value ) {
        $self->{'offscreen_corrs_visible'}{$zone_key} = $value;
    }

    return $self->{'offscreen_corrs_visible'}{$zone_key};
}

# ----------------------------------------------------
sub set_offscreen_corrs_visibility {

=pod

=head2 set_offscreen_corrs_visility

=cut

    my $self     = shift;
    my $zone_key = shift or return;
    my $value    = shift;

    $self->offscreen_corrs_visible( $zone_key, $value, );

    my $window_key = $self->{'scaffold'}{$zone_key}{'window_key'};

    # Redraw
    $self->redraw_the_whole_window( window_key => $window_key, );

    return 1;
}

# ----------------------------------------------------
sub features_visible {

=pod

=head2 features_visible

=cut

    my $self     = shift;
    my $zone_key = shift or return;
    my $value    = shift;

    if ( defined $value ) {
        $self->{'scaffold'}{$zone_key}{'show_features'} = $value;
    }

    return $self->{'scaffold'}{$zone_key}{'show_features'};
}

# ----------------------------------------------------
sub set_features_visibility {

=pod

=head2 set_features_visibility

=cut

    my $self     = shift;
    my $zone_key = shift or return;
    my $value    = shift;

    $self->features_visible( $zone_key, $value, );

    my $window_key = $self->{'scaffold'}{$zone_key}{'window_key'};

    # Redraw
    $self->redraw_the_whole_window( window_key => $window_key, );

    return 1;
}

# ----------------------------------------------------
sub modify_window_bottom_bound {

=pod

=head2 modify_window_bottom_bound

Changes the hight of the window

If bounds_change is given, it will change the y2 value of 'bounds'.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $bounds_change = $args{'bounds_change'} || 0;

    $self->{'window_layout'}{$window_key}{'bounds'}[3] += $bounds_change;
    $self->{'window_layout'}{$window_key}{'changed'} = 1;

    return;
}

# ----------------------------------------------------
sub modify_zone_bottom_bound {

=pod

=head2 modify_zone_bottom_bound

Changes the hight of the zone

If bounds_change is given, it will change the y2 value of 'bounds'.


=cut

    my ( $self, %args ) = @_;
    my $zone_key      = $args{'zone_key'}      or return;
    my $window_key    = $args{'window_key'}    or return;
    my $bounds_change = $args{'bounds_change'} or return;
    my $app_interface = $self->app_interface();

    $self->{'zone_layout'}{$zone_key}{'bounds'}[3]          += $bounds_change;
    $self->{'zone_layout'}{$zone_key}{'internal_bounds'}[3] += $bounds_change;
    $self->{'zone_layout'}{$zone_key}{'changed'} = 1;

    set_zone_bgcolor(
        window_key       => $window_key,
        zone_key         => $zone_key,
        app_display_data => $self,
    );

    # BF DO THIS SOMETIME
    #$self->move_lower_zones(
    #    stationary_zone_key => $zone_key,
    #    window_key           => $window_key,
    #    height_change       => $bounds_change,
    #);

    return;
}

# ----------------------------------------------------
sub next_internal_key {

=pod

=head2 next_internal_key

Returns the next key for the given item.

=cut

    my $self = shift;
    my $key_type = shift or die "Failed to give type to next_internal_key\n";
    my $access_str = 'last_' . $key_type . '_key';

    if ( $self->{$access_str} ) {
        $self->{$access_str}++;
    }
    else {
        $self->{$access_str} = 1;
    }

    return $self->{$access_str};

}

# ----------------------------------------------------
sub create_temp_id {

=pod

=head2 create_temp_id

Returns the next temparary id for maps or features.

When maps are split, one part needs a new map id.  To avoid conflict with real
map_ids (since we don't have access to the db to create a new one) the
temparary map ids will be negative.

=cut

    my $self       = shift;
    my $access_str = 'last_temp_id';

    if ( $self->{$access_str} ) {
        $self->{$access_str}--;
    }
    else {

        # Start with -2 to avoid any unforseen conflicts with -1
        $self->{$access_str} = -2;
    }

    return $self->{$access_str};

}

# ----------------------------------------------------
sub initialize_map_layout {

=pod

=head2 initialize_map_layout

Initializes map_layout

=cut

    my $self = shift;

    my $map_key = shift;

    $self->{'map_layout'}{$map_key} = {
        bounds       => [],
        coords       => [],
        buttons      => [],
        features     => {},
        items        => [],
        changed      => 1,
        sub_changed  => 1,
        row_index    => undef,
        color        => 'black',
        expanded     => 0,
        show_details => 1,
        flipped      => 0,
    };

    return;
}

# ----------------------------------------------------
sub initialize_zone_layout {

=pod

=head2 initialize_zone_layout

Initializes zone_layout

=cut

    my $self       = shift;
    my $zone_key   = shift;
    my $window_key = shift;
    $self->{'zone_in_window'}{$window_key}{$zone_key} = 1;

    $self->{'zone_layout'}{$zone_key} = {
        bounds            => [],
        separator         => [],
        background        => [],
        buttons           => [],
        layed_out_once    => 0,
        changed           => 0,
        sub_changed       => 0,
        flipped           => 0,
        border_line_width => 1,
    };

    return;
}

# ----------------------------------------------------
sub recreate_overview {

=pod

=head2 recreate_overview

Destroys then recreates the overview

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;

    return;    ### BF RMOVERVIEW
    my $top_zone_key = $self->{'overview'}{$window_key}{'zone_key'};

    foreach my $zone_key ( $top_zone_key, ) {
        foreach my $map_key (
            keys %{
                $self->{'overview_layout'}{$window_key}{'zones'}{$zone_key}
                    {'maps'} || {}
            }
            )
        {
            $self->destroy_items(
                window_key => $window_key,
                items      => $self->{'overview_layout'}{$window_key}{'zones'}
                    {$zone_key}{'maps'}{$map_key}{'items'},
                is_overview => 1,
            );
        }
        foreach my $item_name (qw[ misc_items viewed_region ]) {
            $self->destroy_items(
                window_key => $window_key,
                items      => $self->{'overview_layout'}{$window_key}{'zones'}
                    {$zone_key}{$item_name},
                is_overview => 1,
            );
        }
        delete $self->{'overview_layout'}{$window_key}{'zones'}{$zone_key};
    }

    # Destroy overview itself
    $self->destroy_items(
        window_key  => $window_key,
        items       => $self->{'overview_layout'}{$window_key}{'misc_items'},
        is_overview => 1,
    );
    delete $self->{'overview_layout'}{$window_key};

    # Recreate Overveiw
    $self->initialize_overview_layout($window_key);

    layout_overview(
        window_key       => $window_key,
        app_display_data => $self,
    );

    return;
}

# ----------------------------------------------------
sub initialize_overview_layout {

=pod

=head2 initialize_overview_layout

Initializes overview_layout

=cut

    my $self       = shift;
    my $window_key = shift;

    my $top_zone_key = $self->{'overview'}{$window_key}{'zone_key'};

    $self->{'overview_layout'}{$window_key} = {
        bounds           => [ 0, 0, 0, 0 ],
        misc_items       => [],
        buttons          => [],
        changed          => 1,
        sub_changed      => 1,
        zones            => {},
        child_zone_order => [],
    };

    foreach my $zone_key ( $top_zone_key, ) {
        $self->initialize_overview_zone_layout( $window_key, $zone_key, );
    }

    return;
}

# ----------------------------------------------------
sub initialize_overview_zone_layout {

=pod

=head2 initialize_overview_zone_layout

Initializes overview_layout

=cut

    my $self       = shift;
    my $window_key = shift;
    my $zone_key   = shift;

    $self->{'overview_layout'}{$window_key}{'zones'}{$zone_key} = {
        bounds                 => [ 0, 0, 0, 0 ],
        misc_items             => [],
        buttons                => [],
        viewed_region          => [],
        changed                => 1,
        sub_changed            => 1,
        maps                   => {},
        scale_factor_from_main => 0,
    };
    foreach my $map_key ( @{ $self->{'map_order'}{$zone_key} || [] } ) {
        $self->{'overview_layout'}{$window_key}{'zones'}{$zone_key}{'maps'}
            {$map_key} = {
            items   => [],
            changed => 1,
            };
    }

    return;
}

# ----------------------------------------------------
sub set_default_window_layout {

=pod

=head2 set_default_window_layout

Set the default window layout.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $title = $args{'title'} || 'CMap';

    $self->{'window_layout'}{$window_key} = {
        title       => $title,
        bounds      => [ 0, 0, 0, 0 ],
        misc_items  => [],
        buttons     => [],
        changed     => 1,
        sub_changed => 1,
        width       => 0,
    };

}

# ----------------------------------------------------
sub hide_corrs {

=pod

=head2 hide_corrs

Hide Corrs for moving

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $zone_key1  = $args{'zone_key'}   or return;

    # Record the current corrs
    foreach my $zone_key2 (
        keys %{ $self->{'correspondences_on'}{$zone_key1} || {} } )
    {
        if ( $self->{'correspondences_on'}{$zone_key1}{$zone_key2} ) {
            push @{ $self->{'correspondences_hidden'}{$zone_key1} },
                $zone_key2;
            $self->clear_corrs_between_zones(
                window_key => $window_key,
                zone_key1  => $zone_key1,
                zone_key2  => $zone_key2,
            );
        }
    }

    foreach my $child_zone_key (
        @{ $self->{'scaffold'}{$zone_key1}{'children'} || [] } )
    {
        if ( $self->{'scaffold'}{$child_zone_key}{'attached_to_parent'} ) {
            $self->hide_corrs(
                window_key => $window_key,
                zone_key   => $child_zone_key,
            );
        }
    }

    return;
}

# ----------------------------------------------------
sub unhide_corrs {

=pod

=head2 hide_corrs

Hide Corrs for moving

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $zone_key1  = $args{'zone_key'}   or return;

    return unless ( $self->{'correspondences_hidden'} );

    foreach my $zone_key2 (
        @{ $self->{'correspondences_hidden'}{$zone_key1} || [] } )
    {
        delete $self->{'correspondences_hidden'}{$zone_key1};
        $self->add_zone_corrs(
            window_key => $window_key,
            zone_key1  => $zone_key1,
            zone_key2  => $zone_key2,
        );
        $self->{'correspondences_on'}{$zone_key1}{$zone_key2} = 1;
        $self->{'correspondences_on'}{$zone_key2}{$zone_key1} = 1;
    }

    foreach my $child_zone_key (
        @{ $self->{'scaffold'}{$zone_key1}{'children'} || [] } )
    {
        if ( $self->{'scaffold'}{$child_zone_key}{'attached_to_parent'} ) {
            $self->unhide_corrs(
                window_key => $window_key,
                zone_key   => $child_zone_key,
            );
        }
    }
    $self->app_interface()->draw_corrs(
        window_key       => $window_key,
        app_display_data => $self,
    );

    return;
}

# ----------------------------------------------------
sub get_correspondence_menu_data {

=pod

=head2 get_correspondence_menu_data

Return information about correspondences for the menu

=cut

    my ( $self, %args ) = @_;
    my $zone_key = $args{'zone_key'};

    my $self_map_set_id = $self->{'scaffold'}{$zone_key}{'map_set_id'};

    my $self_return_hash;
    my @return_array;
    foreach
        my $map_set_id ( keys %{ $self->map_set_id_to_zone_keys() || {} } )
    {
        my $map_set_data = $self->app_data_module()
            ->get_map_set_data( map_set_id => $map_set_id, );
        my $return_ref = {
            map_set_id   => $map_set_id,
            map_set_data => $map_set_data,
            map_set_name => $map_set_data->{'map_set_name'},
            corrs_on =>
                $self->{'zone_to_map_set_correspondences_on'}{$zone_key}
                {$map_set_id} || 0,
        };
        if ( $map_set_id == $self_map_set_id ) {
            $self_return_hash = $return_ref;
            $return_ref->{'map_set_name'} .= " (Self)";
            push @return_array, $return_ref;
        }
        else {
            push @return_array, $return_ref;
        }
    }

    return ( \@return_array, $self_return_hash );
}

# ----------------------------------------------------
sub get_move_map_data {

=pod

=head2 get_move_map_data

Move a map from one place on a parent to another

=cut

    my ( $self, %args ) = @_;
    my $map_key          = $args{'map_key'};
    my $highlight_bounds = $args{'highlight_bounds'};
    my $zone_key         = $self->map_key_to_zone_key($map_key);
    my $window_key       = $self->{'scaffold'}{$zone_key}{'window_key'};
    my $parent_zone_key  = $self->{'scaffold'}{$zone_key}{'parent_zone_key'};
    my $old_map_coords   = $self->{'map_layout'}{$map_key}{'coords'};

    # Get pixel location on parent map
    my %highlight_location_data
        = $self->place_highlight_location_on_parent_map(
        map_key          => $map_key,
        zone_key         => $zone_key,
        highlight_bounds => $highlight_bounds,
        );

    # Get parent offsets
    my ( $parent_main_x_offset, $parent_main_y_offset )
        = $self->get_main_zone_offsets( zone_key => $parent_zone_key, );
    my $parent_x_offset = $self->{'scaffold'}{$parent_zone_key}{'x_offset'};

    my $new_parent_map_key = $highlight_location_data{'parent_map_key'};
    $parent_zone_key = $highlight_location_data{'parent_zone_key'};
    my $new_location_coords = $highlight_location_data{'location_coords'};

    $new_location_coords->[0] -= ( $parent_main_x_offset + $parent_x_offset );
    $new_location_coords->[2] -= ( $parent_main_x_offset + $parent_x_offset );

    my $parent_map_coords
        = $self->{'map_layout'}{$new_parent_map_key}{'coords'};

    # Use start location as basis for locating
    my $relative_pixel_start
        = $new_location_coords->[0] - $parent_map_coords->[0];

    my $relative_unit_start
        = $relative_pixel_start /
        (      $self->{'map_pixels_per_unit'}{$new_parent_map_key}
            || $self->{'scaffold'}{$parent_zone_key}{'pixels_per_unit'} );
    my $parent_map_data = $self->app_data_module()
        ->map_data( map_id => $self->map_key_to_id($new_parent_map_key), );

    # Modify the relative unit start to round to the unit granularity
    my $parent_unit_granularity
        = $self->map_type_data( $parent_map_data->{'map_type_acc'},
        'unit_granularity' )
        || DEFAULT->{'unit_granularity'};
    $relative_unit_start = round_to_granularity( $relative_unit_start,
        $parent_unit_granularity );

    my ( $new_feature_start, $new_feature_stop );

    my $parent_map_flipped = $self->is_map_drawn_flipped(
        map_key  => $new_parent_map_key,
        zone_key => $parent_zone_key,
    );
    if ($parent_map_flipped) {
        $new_feature_stop
            = $parent_map_data->{'map_stop'} - $relative_unit_start;
        $new_feature_start = $new_feature_stop
            - $self->{'sub_maps'}{$map_key}{'feature_length'};
    }
    else {
        $new_feature_start
            = $relative_unit_start + $parent_map_data->{'map_start'};
        $new_feature_stop = $new_feature_start
            + $self->{'sub_maps'}{$map_key}{'feature_length'};
    }

    # If the feature end is at the end of the map, simply make the feature end
    # the map end
    if (    $new_location_coords->[0] == $parent_map_coords->[0]
        and $new_location_coords->[2] == $parent_map_coords->[2] )
    {
        $new_feature_start = $parent_map_data->{'map_start'};
        $new_feature_stop  = $parent_map_data->{'map_stop'};
    }
    elsif (
        (   !$parent_map_flipped
            and $new_location_coords->[0] == $parent_map_coords->[0]
        )
        or (    $parent_map_flipped
            and $new_location_coords->[2] == $parent_map_coords->[2] )

        )
    {
        $new_feature_start = $parent_map_data->{'map_start'};
        $new_feature_stop  = $new_feature_start
            + $self->{'sub_maps'}{$map_key}{'feature_length'};
    }
    elsif (
        (   !$parent_map_flipped
            and $new_location_coords->[2] == $parent_map_coords->[2]
        )
        or (    $parent_map_flipped
            and $new_location_coords->[0] == $parent_map_coords->[0] )
        )
    {
        $new_feature_stop  = $parent_map_data->{'map_stop'};
        $new_feature_start = $new_feature_stop
            - $self->{'sub_maps'}{$map_key}{'feature_length'};
    }

    my %return_hash = (
        map_key            => $map_key,
        new_parent_map_key => $new_parent_map_key,
        new_feature_start  => $new_feature_start,
        new_feature_stop   => $new_feature_stop,
    );

    return \%return_hash;
}

# ----------------------------------------------------
sub get_move_subsection_data {

=pod

=head2 get_move_subsection_data

Move a map representing a chunk of the parent map from one place on a parent to
another

=cut

    my ( $self, %args ) = @_;
    my $map_key         = $args{'map_key'};
    my $zone_key        = $self->map_key_to_zone_key($map_key);
    my $window_key      = $self->{'scaffold'}{$zone_key}{'window_key'};
    my $parent_zone_key = $self->{'scaffold'}{$zone_key}{'parent_zone_key'};
    my $old_map_coords  = $self->{'map_layout'}{$map_key}{'coords'};
    my $mouse_x         = $args{'mouse_x'};
    my $mouse_y         = $args{'mouse_y'};

    # Get pixel location on parent map
    my %subsection_location_data
        = $self->place_subsection_location_on_parent_map(
        map_key  => $map_key,
        zone_key => $zone_key,
        mouse_x  => $mouse_x,
        mouse_y  => $mouse_y,
        );
    return () unless (%subsection_location_data);

    if ( $subsection_location_data{'map_did_not_move'} ) {
        $self->app_interface()
            ->popup_warning( text => 'The map was not moved', );
        return undef;
    }

    my $new_parent_map_key = $subsection_location_data{'parent_map_key'};
    my $gap_start          = $subsection_location_data{'gap_start'};
    my $gap_stop           = $subsection_location_data{'gap_stop'};

    my %return_hash = (
        map_key            => $map_key,
        new_parent_map_key => $new_parent_map_key,
        gap_start          => $gap_start,
        gap_stop           => $gap_stop,
    );

    return \%return_hash;
}

# ----------------------------------------------------
sub is_map_drawn_flipped {

=pod

=head2 is_map_drawn_flipped

Test a map to see if it needs to be drawn as flipped.  This means that either it is flipped or the zone it is in is flipped.

=cut

    my ( $self, %args ) = @_;
    my $map_key  = $args{'map_key'};
    my $zone_key = $self->map_key_to_zone_key($map_key);

    my $map_flipped  = $self->{'map_layout'}{$map_key}{'flipped'}   || 0;
    my $zone_flipped = $self->{'zone_layout'}{$zone_key}{'flipped'} || 0;

    return ( $zone_flipped != $map_flipped );

}

# ----------------------------------------------------
sub flip_map {

=pod

=head2 flip_map

Flip a map

=cut

    my ( $self, %args ) = @_;
    my $map_key      = $args{'map_key'};
    my $zone_key     = $self->map_key_to_zone_key($map_key);
    my $window_key   = $self->{'scaffold'}{$zone_key}{'window_key'};
    my $undo_or_redo = $args{'undo_or_redo'} || 0;

    my $map_layout = $self->{'map_layout'}{$map_key};

    return
        if (defined( $args{'value'} )
        and defined( $map_layout->{'flipped'} )
        and $args{'value'} == $map_layout->{'flipped'} );

    # Handle subsections
    my $map_id = $self->map_key_to_id($map_key);
    my $map_data = $self->app_data_module()->map_data( map_id => $map_id, );
    my $map_type_acc = $map_data->{'map_type_acc'};

    # Set the basic action_data
    my $feature_id = 0;
    if ( $self->{'sub_maps'}{$map_key} ) {
        $feature_id = $self->{'sub_maps'}{$map_key}{'feature_id'};
    }
    my %action_data = (
        action     => 'flip_map',
        feature_id => $feature_id,
        map_key    => $map_key,
        map_id     => $map_id,
    );

    if ( $self->map_type_data( $map_type_acc, 'subsection' ) ) {

        my $super_map_key = $self->{'sub_maps'}{$map_key}{'parent_map_key'};
        my $super_map_id  = $self->map_key_to_id($super_map_key);
        my $subsection_feature_start
            = $self->{'sub_maps'}{$map_key}{'feature_start'};
        my $subsection_feature_stop
            = $self->{'sub_maps'}{$map_key}{'feature_stop'};

        my $feature_data
            = $self->app_data_module()
            ->feature_data_by_map( map_id => $super_map_id, )
            || [];
        my @subsection_feature_accs;
        foreach my $feature (@$feature_data) {

            # If features overlap into the subsection, abort
            if ((   $feature->{'feature_start'} < $subsection_feature_start
                    and $feature->{'feature_stop'} > $subsection_feature_start
                )
                or (    $feature->{'feature_start'} < $subsection_feature_stop
                    and $feature->{'feature_stop'}
                    > $subsection_feature_stop )
                )
            {
                $self->app_interface()
                    ->popup_warning(
                    text => 'Cannot flip this subsection because features '
                        . 'overlap into the subsection.', );
                return undef;
            }
            elsif ( $feature->{'feature_stop'} <= $subsection_feature_stop
                and $feature->{'feature_start'} >= $subsection_feature_start )
            {
                push @subsection_feature_accs, $feature->{'feature_acc'};
            }
        }

        my $super_map_data
            = $self->app_data_module()->map_data( map_id => $super_map_id );
        my $super_unit_granularity
            = $self->unit_granularity( $super_map_data->{'map_type_acc'} );
        $self->reverse_map_section(
            map_key          => $super_map_key,
            map_data         => $super_map_data,
            unit_granularity => $super_unit_granularity,
            feature_accs     => \@subsection_feature_accs,
            reverse_start    => $subsection_feature_start,
            reverse_stop     => $subsection_feature_stop,
        );

        # Add subsection specific info to the action_data
        $action_data{'subsection'}              = 1;
        $action_data{'super_map_id'}            = $super_map_id;
        $action_data{'reverse_start'}           = $subsection_feature_start;
        $action_data{'reverse_stop'}            = $subsection_feature_stop;
        $action_data{'super_unit_granularity'}  = $super_unit_granularity;
        $action_data{'subsection_feature_accs'} = \@subsection_feature_accs;
    }
    else {

        # If a value was passed, use it, otherwise toggle the flip value
        my $new_flip_value
            = defined( $args{'value'} ) ? $args{'value'}
            : $map_layout->{'flipped'}  ? 0
            :                             1;

        $map_layout->{'flipped'} = $new_flip_value;

        # Flip the child zones
        foreach my $child_zone_key (
            $self->get_children_zones_of_map(
                map_key  => $map_key,
                zone_key => $zone_key,
            )
            )
        {
            $self->cascade_flip_zone_toggle( zone_key => $child_zone_key, );
        }
    }

    # Add Action Data to be able to undo and redo
    unless ($undo_or_redo) {
        $self->add_action(
            window_key  => $window_key,
            action_data => \%action_data,
        );
    }

    # Redraw
    $self->redraw_the_whole_window( window_key => $window_key, );

    return;

}

# ----------------------------------------------------
sub cascade_flip_zone_toggle {

=pod

=head2 cascade_flip_zone_toggle

Toggle a zone's flip value

=cut

    my ( $self, %args ) = @_;
    my $zone_key = $args{'zone_key'} or return;

    my $flip_value = $self->{'zone_layout'}{$zone_key}{'flipped'} ? 0 : 1;
    $self->{'zone_layout'}{$zone_key}{'flipped'} = $flip_value;

    foreach my $child_zone_key (
        @{ $self->{'scaffold'}{$zone_key}{'children'} || [] } )
    {
        $self->cascade_flip_zone_toggle( zone_key => $child_zone_key, );
    }

    return;
}

# ----------------------------------------------------
sub move_map {

=pod

=head2 move_map

Move a map from one place on a parent to another

=cut

    my ( $self, %args ) = @_;
    my $map_key            = $args{'map_key'};
    my $new_parent_map_key = $args{'new_parent_map_key'};
    my $new_feature_start  = $args{'new_feature_start'};
    my $new_feature_stop   = $args{'new_feature_stop'};
    my $undo_or_redo       = $args{'undo_or_redo'} || 0;
    my $zone_key           = $self->map_key_to_zone_key($map_key);
    my $window_key         = $self->{'scaffold'}{$zone_key}{'window_key'};

    unless ($undo_or_redo) {
        my %action_data = (
            action     => 'move_map',
            map_key    => $map_key,
            map_id     => $self->map_key_to_id($map_key),
            feature_id => $self->{'sub_maps'}{$map_key}{'feature_id'},
            old_parent_map_key =>
                $self->{'sub_maps'}{$map_key}{'parent_map_key'},
            old_parent_map_id => $self->map_key_to_id(
                $self->{'sub_maps'}{$map_key}{'parent_map_key'}
            ),
            old_feature_start =>
                $self->{'sub_maps'}{$map_key}{'feature_start'},
            old_feature_stop => $self->{'sub_maps'}{$map_key}{'feature_stop'},
            new_parent_map_key => $new_parent_map_key,
            new_parent_map_id  => $self->map_key_to_id($new_parent_map_key),
            new_feature_start  => $new_feature_start,
            new_feature_stop   => $new_feature_stop,
        );

        $self->add_action(
            window_key  => $window_key,
            action_data => \%action_data,
        );
    }

    $self->move_sub_map_on_parents_in_memory(
        window_key     => $window_key,
        sub_map_key    => $map_key,
        parent_map_key => $new_parent_map_key,
        feature_start  => $new_feature_start,
        feature_stop   => $new_feature_stop,
    );

    # Redraw
    $self->redraw_the_whole_window( window_key => $window_key, );

    return;

}

# ----------------------------------------------------
sub split_map {

=pod

=head2 split_map

Split a map into two.

Create two new maps and hide the original

=cut

    my ( $self, %args ) = @_;
    my $ori_map_key    = $args{'map_key'};
    my $split_position = $args{'split_position'};
    my $undo_or_redo   = $args{'undo_or_redo'} || 0;
    my $zone_key       = $self->map_key_to_zone_key($ori_map_key);
    my $window_key     = $self->{'scaffold'}{$zone_key}{'window_key'};

    my $ori_map_id = $self->map_key_to_id($ori_map_key);
    my $ori_map_data
        = $self->app_data_module()->map_data( map_id => $ori_map_id );

    my $ori_map_start = $ori_map_data->{'map_start'};
    my $ori_map_stop  = $ori_map_data->{'map_stop'};
    my $unit_granularity
        = $self->unit_granularity( $ori_map_data->{'map_type_acc'} );

    # Remove the drawing data for the old map, do this now so that it will
    # affect sub-maps before they are re-assigned.
    destroy_map_for_relayout(
        app_display_data => $self,
        map_key          => $ori_map_key,
        window_key       => $window_key,
        cascade          => 1,
    );

    # Figure out the break points, the two maps will probably overlap some.
    # Simultaniously, place the features on one or the other.
    my $first_map_name   = $ori_map_data->{'map_name'} . ".1";
    my $first_map_start  = $ori_map_start;
    my $first_map_stop   = $split_position;
    my $second_map_name  = $ori_map_data->{'map_name'} . ".2";
    my $second_map_start = $split_position;
    my $second_map_stop  = $ori_map_stop;
    my %feature_accs_for_first_map;
    my %feature_accs_for_second_map;
    my %sub_map_ids_for_first_map;
    my %sub_map_ids_for_second_map;
    my $sorted_feature_data = $self->app_data_module()
        ->sorted_feature_data( map_id => $ori_map_id, );

    foreach my $lane ( keys %{ $sorted_feature_data || {} } ) {
        foreach my $feature ( @{ $sorted_feature_data->{$lane} || [] } ) {
            if ( $feature->{'feature_stop'} <= $split_position ) {
                $feature_accs_for_first_map{ $feature->{'feature_acc'} } = 1;
                if ( $feature->{'sub_map_id'} ) {
                    $sub_map_ids_for_first_map{ $feature->{'sub_map_id'} }
                        = 1;
                }
            }
            elsif ( $feature->{'feature_start'} >= $split_position ) {
                $feature_accs_for_second_map{ $feature->{'feature_acc'} } = 1;
                if ( $feature->{'sub_map_id'} ) {
                    $sub_map_ids_for_second_map{ $feature->{'sub_map_id'} }
                        = 1;
                }
            }
            else {

                # Overlapping feature, Figure out which it should be on and
                # extend that map.
                if ( $split_position - $feature->{'feature_start'}
                    > $feature->{'feature_stop'} - $split_position )
                {
                    $feature_accs_for_first_map{ $feature->{'feature_acc'} }
                        = 1;
                    $first_map_stop = $feature->{'feature_stop'}
                        if ( $feature->{'feature_stop'} > $first_map_stop );
                    if     ( $feature->{'sub_map_id'} ) {
                        $sub_map_ids_for_first_map{ $feature->{'sub_map_id'} }
                            = 1;
                    }
                }
                else {
                    $feature_accs_for_second_map{ $feature->{'feature_acc'} }
                        = 1;
                    $second_map_start = $feature->{'feature_start'}
                        if (
                        $feature->{'feature_start'} < $second_map_start );
                    if ( $feature->{'sub_map_id'} ) {
                        $sub_map_ids_for_second_map{ $feature->{
                                'sub_map_id'} } = 1;
                    }
                }
            }
        }
    }

    my $ori_map_length = $ori_map_stop - $ori_map_start + $unit_granularity;
    my $first_map_length
        = $first_map_stop - $ori_map_start + $unit_granularity;
    my $second_map_length
        = $ori_map_stop - $second_map_start + $unit_granularity;

    # Determine if the new maps need to be flipped or not
    my $ori_flipped = $self->{'map_layout'}{$ori_map_key}{'flipped'};

    # Get the identifiers for the two new maps
    my $first_map_id  = $self->create_temp_id();
    my $first_map_key = $self->initialize_map(
        map_id       => $first_map_id,
        zone_key     => $zone_key,
        draw_flipped => $ori_flipped,
    );
    my $second_map_id  = $self->create_temp_id();
    my $second_map_key = $self->initialize_map(
        map_id       => $second_map_id,
        zone_key     => $zone_key,
        draw_flipped => $ori_flipped,
    );

    # Handle sub map information if it is a sub map
    my $first_feature_start;
    my $first_feature_stop;
    my $second_feature_start;
    my $second_feature_stop;
    if ( %{ $self->{'sub_maps'}{$ori_map_key} || {} } ) {
        my $ori_feature_start
            = $self->{'sub_maps'}{$ori_map_key}{'feature_start'};
        my $ori_feature_stop
            = $self->{'sub_maps'}{$ori_map_key}{'feature_stop'};
        my $ori_feature_direction
            = $self->{'sub_maps'}{$ori_map_key}{'feature_direction'};
        my $ori_feature_length = $ori_feature_stop - $ori_feature_start;
        my $first_feature_id   = $self->create_temp_id();
        my $second_feature_id  = $self->create_temp_id();
        $first_feature_start = $ori_feature_start;
        $first_feature_stop
            = $ori_feature_start
            + (
            $ori_feature_length * ( $first_map_length / $ori_map_length ) );
        $second_feature_start
            = $ori_feature_stop
            - (
            $ori_feature_length * ( $second_map_length / $ori_map_length ) );
        $second_feature_stop = $ori_feature_stop;
        my $first_feature_type_acc
            = $self->{'sub_maps'}{$ori_map_key}{'feature_type_acc'};
        my $second_feature_type_acc = $first_feature_type_acc;

        $self->{'sub_maps'}{$first_map_key} = {
            parent_map_key =>
                $self->{'sub_maps'}{$ori_map_key}{'parent_map_key'},
            feature_start     => $first_feature_start,
            feature_stop      => $first_feature_stop,
            feature_direction => $ori_feature_direction,
            feature_id        => $first_feature_id,
            feature_type_acc  => $first_feature_type_acc,
            feature_length    => (
                $first_feature_stop - $ori_feature_start + $unit_granularity
            ),
        };
        $self->{'sub_maps'}{$second_map_key} = {
            parent_map_key =>
                $self->{'sub_maps'}{$ori_map_key}{'parent_map_key'},
            feature_start     => $second_feature_start,
            feature_stop      => $second_feature_stop,
            feature_direction => $ori_feature_direction,
            feature_type_acc  => $second_feature_type_acc,
            feature_length    => (
                $ori_feature_stop - $second_feature_start + $unit_granularity
            ),
        };

        # BF Potentially Split the feature as well
    }

# Always save the action and wipe any later changes.  A split will kill the redo path.
    my %action_data = (
        action                  => 'split_map',
        ori_map_key             => $ori_map_key,
        ori_map_id              => $self->map_key_to_id($ori_map_key),
        first_map_key           => $first_map_key,
        first_map_id            => $self->map_key_to_id($first_map_key),
        first_map_name          => $first_map_name,
        first_map_start         => $first_map_start,
        first_map_stop          => $first_map_stop,
        first_feature_start     => $first_feature_start,
        first_feature_stop      => $first_feature_stop,
        second_map_key          => $second_map_key,
        second_map_id           => $self->map_key_to_id($second_map_key),
        second_map_name         => $second_map_name,
        second_map_start        => $second_map_start,
        second_map_stop         => $second_map_stop,
        second_feature_start    => $second_feature_start,
        second_feature_stop     => $second_feature_stop,
        split_position          => $split_position,
        first_map_feature_accs  => [ keys %feature_accs_for_first_map ],
        second_map_feature_accs => [ keys %feature_accs_for_second_map ],
    );
    $self->add_action(
        window_key  => $window_key,
        action_data => \%action_data,
    );

    # Create the new pedigrees
    $self->split_map_pedigree(
        ori_map_key      => $ori_map_key,
        ori_map_start    => $ori_map_start,
        ori_map_stop     => $ori_map_stop,
        first_map_key    => $first_map_key,
        first_map_start  => $first_map_start,
        first_map_stop   => $first_map_stop,
        second_map_key   => $second_map_key,
        second_map_start => $second_map_start,
        second_map_stop  => $second_map_stop,
    );

    # Move the features to the new map in Memory
    # We don't need to change the locations of these features because the maps
    # are going to keep the same coords
    $self->app_data_module()->copy_feature_data_to_new_map(
        old_map_id       => $ori_map_id,
        new_map_id       => $first_map_id,
        feature_acc_hash => \%feature_accs_for_first_map,
    );
    $self->app_data_module()->copy_feature_data_to_new_map(
        old_map_id       => $ori_map_id,
        new_map_id       => $second_map_id,
        feature_acc_hash => \%feature_accs_for_second_map,
    );

    # Move the sub maps
    my @possible_zone_keys = $self->get_children_zones_of_map(
        zone_key => $zone_key,
        map_key  => $ori_map_key,
    );
    foreach my $sub_map_id ( keys %sub_map_ids_for_first_map ) {
        my @sub_map_keys = $self->get_map_keys_from_id_and_a_list_of_zones(
            map_id    => $sub_map_id,
            zone_keys => \@possible_zone_keys,
        );
        foreach my $sub_map_key (@sub_map_keys) {
            my $sub_map_info = $self->{'sub_maps'}{$sub_map_key};
            next unless ($sub_map_info);
            $self->move_sub_map_on_parents_in_memory(
                window_key     => $window_key,
                sub_map_key    => $sub_map_key,
                parent_map_key => $first_map_key,
                feature_start  => $sub_map_info->{'feature_start'},
                feature_stop   => $sub_map_info->{'feature_stop'},
            );
        }
    }
    foreach my $sub_map_id ( keys %sub_map_ids_for_second_map ) {
        my @sub_map_keys = $self->get_map_keys_from_id_and_a_list_of_zones(
            map_id    => $sub_map_id,
            zone_keys => \@possible_zone_keys,
        );
        foreach my $sub_map_key (@sub_map_keys) {
            my $sub_map_info = $self->{'sub_maps'}{$sub_map_key};
            next unless ($sub_map_info);
            $self->move_sub_map_on_parents_in_memory(
                window_key     => $window_key,
                sub_map_key    => $sub_map_key,
                parent_map_key => $second_map_key,
                feature_start  => $sub_map_info->{'feature_start'},
                feature_stop   => $sub_map_info->{'feature_stop'},
            );
        }
    }

    # Create the new map data
    $self->app_data_module()->generate_map_data(
        old_map_id => $ori_map_id,
        new_map_id => $first_map_id,
        map_start  => $first_map_start,
        map_stop   => $first_map_stop,
        map_name   => $first_map_name,
    );
    $self->app_data_module()->generate_map_data(
        old_map_id => $ori_map_id,
        new_map_id => $second_map_id,
        map_start  => $second_map_start,
        map_stop   => $second_map_stop,
        map_name   => $second_map_name,
    );

    # Cut the maps ties with the other zones so it doesn't get re-drawn
    $self->remove_from_map_order(
        map_key  => $ori_map_key,
        zone_key => $zone_key,
    );

    # Remove any drawn correspondences
    $self->remove_corrs_to_map(
        window_key => $window_key,
        map_key    => $ori_map_key,
    );

    # Redraw
    $self->redraw_the_whole_window(
        window_key       => $window_key,
        reset_selections => 1,
    );

    return ( [ $first_map_key, $second_map_key, ], $zone_key );

}

# ----------------------------------------------------
sub undo_split_map {

=pod

=head2 undo_split_map

Undo the splitting of a map into two.

Destroy the two new maps and show the original

=cut

    my ( $self, %args ) = @_;
    my $ori_map_key             = $args{'ori_map_key'};
    my $first_map_key           = $args{'first_map_key'};
    my $second_map_key          = $args{'second_map_key'};
    my $first_map_feature_accs  = $args{'first_map_feature_accs'} || [];
    my $second_map_feature_accs = $args{'second_map_feature_accs'} || [];

    my $zone_key   = $self->map_key_to_zone_key($first_map_key);
    my $window_key = $self->{'scaffold'}{$zone_key}{'window_key'};

    my $ori_map_id    = $self->map_key_to_id($ori_map_key);
    my $first_map_id  = $self->map_key_to_id($first_map_key);
    my $second_map_id = $self->map_key_to_id($second_map_key);

    # Reattach original map to the zone
    push @{ $self->{'map_order'}{$zone_key} }, $ori_map_key;

    # Copy the features back onto the original maps
    $self->app_data_module()->copy_feature_data_to_new_map(
        old_map_id       => $first_map_id,
        new_map_id       => $ori_map_id,
        feature_acc_hash => { map { ( $_ => 1 ) } @$first_map_feature_accs },
    );
    $self->app_data_module()->copy_feature_data_to_new_map(
        old_map_id       => $second_map_id,
        new_map_id       => $ori_map_id,
        feature_acc_hash => { map { ( $_ => 1 ) } @$second_map_feature_accs },
    );

    foreach my $tmp_map_key ( $first_map_key, $second_map_key ) {

        destroy_map_for_relayout(
            app_display_data => $self,
            map_key          => $tmp_map_key,
            window_key       => $window_key,
            cascade          => 1,
        );

        # Move sub maps back
        foreach my $child_zone_key (
            $self->get_children_zones_of_map(
                map_key  => $tmp_map_key,
                zone_key => $zone_key,
            )
            )
        {
            my @map_order = @{ $self->map_order($child_zone_key) || [] };
            foreach my $sub_map_key (@map_order) {
                my $sub_map_info = $self->{'sub_maps'}{$sub_map_key};
                next unless ($sub_map_info);
                $self->move_sub_map_on_parents_in_memory(
                    window_key     => $window_key,
                    sub_map_key    => $sub_map_key,
                    parent_map_key => $ori_map_key,
                    feature_start  => $sub_map_info->{'feature_start'},
                    feature_stop   => $sub_map_info->{'feature_stop'},
                );
            }
        }

        if ( $self->{'sub_maps'}{$tmp_map_key} ) {
            delete $self->{'sub_maps'}{$tmp_map_key};
        }

        # Delete temporary Biological data for the new maps
        $self->app_data_module()
            ->remove_map_data( map_id => $self->map_key_to_id($tmp_map_key),
            );

        # Detach new maps from the zone
        $self->uninitialize_map(
            map_key  => $tmp_map_key,
            zone_key => $zone_key,
        );
    }
    $self->cascade_reset_zone_corrs(
        window_key => $window_key,
        zone_key   => $zone_key,
    );
    $self->app_interface()->draw_window(
        window_key       => $window_key,
        app_display_data => $self,
    );

    return;
}

# ----------------------------------------------------
sub merge_maps {

=pod

=head2 merge_maps

Merge two maps

Create one new map and hide the original maps

Merging/Flipped logic:

=over 4

=item * If original_map1 is flipped, make the finished product flipped

=item * If the maps are of opposite flippage, then set_map2 to reverse

=item * If the final map is going to be flipped, modify the offset to place map2 in front of map1

=item * If reversing second map, reverse it now.

=item * Do the merge

=back

=cut

    my ( $self, %args ) = @_;
    my $first_map_key  = $args{'first_map_key'};
    my $second_map_key = $args{'second_map_key'};
    my $overlap_amount = $args{'overlap_amount'};
    my $undo_or_redo   = $args{'undo_or_redo'} || 0;
    my $zone_key       = $self->map_key_to_zone_key($first_map_key);
    my $window_key     = $self->{'scaffold'}{$zone_key}{'window_key'};

    my $first_map_flipped = $self->is_map_drawn_flipped(
        map_key  => $first_map_key,
        zone_key => $zone_key,
    );
    my $second_map_flipped = $self->is_map_drawn_flipped(
        map_key  => $second_map_key,
        zone_key => $zone_key,
    );

    my $merged_map_flipped = 0;
    if ($first_map_flipped) {
        $merged_map_flipped = 1;
    }
    my $reverse_second_map = 0;
    if ( $first_map_flipped != $second_map_flipped ) {
        $reverse_second_map = 1;
    }
    my $second_before_first = 0;
    if ($merged_map_flipped) {
        $second_before_first = 1;
    }

    my $first_map_id = $self->map_key_to_id($first_map_key);
    my $first_map_data
        = $self->app_data_module()->map_data( map_id => $first_map_id );
    my $first_map_start = $first_map_data->{'map_start'};
    my $first_map_stop  = $first_map_data->{'map_stop'};

    my $second_map_id = $self->map_key_to_id($second_map_key);
    my $second_map_data
        = $self->app_data_module()->map_data( map_id => $second_map_id );
    my $second_map_start = $second_map_data->{'map_start'};
    my $second_map_stop  = $second_map_data->{'map_stop'};

    my $unit_granularity
        = $self->unit_granularity( $first_map_data->{'map_type_acc'} );

    my $first_map_length
        = $first_map_stop - $first_map_start + $unit_granularity;
    my $second_map_length
        = $second_map_stop - $second_map_start + $unit_granularity;

    if ( $overlap_amount > $first_map_length ) {
        $self->app_interface()
            ->popup_warning( text => 'Overlap is too big.', );
        return;
    }

    my $second_map_offset = 0;
    if ($second_before_first) {
        $second_map_offset
            = $first_map_data->{'map_start'} 
            - $second_map_data->{'map_stop'}
            - $unit_granularity 
            + $overlap_amount;
    }
    else {
        $second_map_offset
            = $first_map_data->{'map_stop'} 
            - $second_map_data->{'map_start'}
            + $unit_granularity 
            - $overlap_amount;
    }

    # Remove the drawing data for the old maps, do this now so that it will
    # affect sub-maps before they are re-assigned.
    destroy_map_for_relayout(
        app_display_data => $self,
        map_key          => $first_map_key,
        window_key       => $window_key,
        cascade          => 1,
    );
    destroy_map_for_relayout(
        app_display_data => $self,
        map_key          => $second_map_key,
        window_key       => $window_key,
        cascade          => 1,
    );

    # Merged map info
    my ( $merged_map_start, $merged_map_stop, );
    if ($second_before_first) {
        $merged_map_start
            = $second_map_data->{'map_start'} + $second_map_offset;
        $merged_map_stop = $first_map_data->{'map_stop'};
        if ( $merged_map_start > $first_map_data->{'map_start'} ) {
            $merged_map_start = $first_map_data->{'map_start'};
        }
    }
    else {
        $merged_map_start = $first_map_data->{'map_start'};
        $merged_map_stop
            = $second_map_data->{'map_stop'} + $second_map_offset;
        if ( $merged_map_stop < $first_map_data->{'map_stop'} ) {
            $merged_map_stop = $first_map_data->{'map_stop'};
        }
    }
    my $merged_map_name = $first_map_data->{'map_name'} . "-"
        . $second_map_data->{'map_name'};
    my $merged_map_id = $self->create_temp_id();

    my $merged_map_key = $self->initialize_map(
        map_id       => $merged_map_id,
        zone_key     => $zone_key,
        draw_flipped => $merged_map_flipped,
    );

    # Reassign Features
    # First get the feature accs for each map
    my @first_map_feature_accs;
    my $first_feature_data = $self->app_data_module()
        ->feature_data_by_map( map_id => $first_map_id, ) || [];
    foreach my $feature (@$first_feature_data) {
        push @first_map_feature_accs, $feature->{'feature_acc'};
    }
    my @second_map_feature_accs;
    my $second_feature_data = $self->app_data_module()
        ->feature_data_by_map( map_id => $second_map_id, ) || [];
    foreach my $feature (@$second_feature_data) {
        push @second_map_feature_accs, $feature->{'feature_acc'};
    }

    # Reverse second map in memory if needed
    if ($reverse_second_map) {
        $self->reverse_map_section(
            map_key          => $second_map_key,
            map_data         => $second_map_data,
            unit_granularity => $unit_granularity,
            feature_accs     => \@second_map_feature_accs,
        );
    }

    # Then copy the features onto the new map
    $self->app_data_module()->copy_feature_data_to_new_map(
        old_map_id       => $first_map_id,
        new_map_id       => $merged_map_id,
        feature_acc_hash => { map { ( $_ => 1 ) } @first_map_feature_accs },
    );
    $self->app_data_module()->copy_feature_data_to_new_map(
        old_map_id       => $second_map_id,
        new_map_id       => $merged_map_id,
        feature_acc_hash => { map { ( $_ => 1 ) } @second_map_feature_accs },
    );

    # Finally move the second map's features by the offset
    $self->app_data_module()->move_feature_data_on_map(
        feature_acc_array => \@second_map_feature_accs,
        map_id            => $merged_map_id,
        offset            => $second_map_offset,
    );

    # Handle sub map information if they are sub_maps
    my $merged_feature_start;
    my $merged_feature_stop;
    if ( %{ $self->{'sub_maps'}{$first_map_key} || {} } ) {
        my $first_feature_start
            = $self->{'sub_maps'}{$first_map_key}{'feature_start'};
        my $first_feature_direction
            = $self->{'sub_maps'}{$first_map_key}{'feature_direction'};
        my $first_feature_stop
            = $self->{'sub_maps'}{$first_map_key}{'feature_stop'};
        my $second_feature_start
            = $self->{'sub_maps'}{$second_map_key}{'feature_start'};
        my $second_feature_stop
            = $self->{'sub_maps'}{$second_map_key}{'feature_stop'};
        my $second_feature_direction
            = $self->{'sub_maps'}{$second_map_key}{'feature_direction'};
        my $merged_feature_type_acc
            = $self->{'sub_maps'}{$first_map_key}{'feature_type_acc'};
        my $merged_feature_direction = $first_feature_direction;
        $merged_feature_start
            = ( $first_feature_start < $second_feature_start )
            ? $first_feature_start
            : $second_feature_start;
        $merged_feature_stop
            = ( $first_feature_stop > $second_feature_stop )
            ? $first_feature_stop
            : $second_feature_stop;

        my $merged_feature_id = $self->create_temp_id();

        $self->{'sub_maps'}{$merged_map_key} = {
            parent_map_key =>
                $self->{'sub_maps'}{$first_map_key}{'parent_map_key'},
            feature_start     => $merged_feature_start,
            feature_stop      => $merged_feature_stop,
            feature_id        => $merged_feature_id,
            feature_type_acc  => $merged_feature_type_acc,
            feature_direction => $merged_feature_direction,
            feature_length    => (
                      $merged_feature_stop 
                    - $merged_feature_start
                    + $unit_granularity
            ),
        };

        # BF Potentially Merge the feature as well
    }

    # Move the sub maps over to the new merged map
    #First create lists of sub maps
    my @first_sub_map_keys;
    foreach my $child_zone_key (
        $self->get_children_zones_of_map(
            map_key  => $first_map_key,
            zone_key => $zone_key,
        )
        )
    {
        foreach my $sub_map_key (
            @{ $self->{'map_order'}{$child_zone_key} || [] } )
        {
            push @first_sub_map_keys, $sub_map_key;
        }
    }
    my @second_sub_map_keys;
    foreach my $child_zone_key (
        $self->get_children_zones_of_map(
            map_key  => $second_map_key,
            zone_key => $zone_key,
        )
        )
    {
        foreach my $sub_map_key (
            @{ $self->{'map_order'}{$child_zone_key} || [] } )
        {
            push @second_sub_map_keys, $sub_map_key;
        }
    }

    # Then actually move the sub maps
    foreach my $sub_map_key (@first_sub_map_keys) {
        my $sub_map_info = $self->{'sub_maps'}{$sub_map_key};
        next unless ($sub_map_info);
        $self->move_sub_map_on_parents_in_memory(
            window_key     => $window_key,
            sub_map_key    => $sub_map_key,
            parent_map_key => $merged_map_key,
            feature_start  => $sub_map_info->{'feature_start'},
            feature_stop   => $sub_map_info->{'feature_stop'},
        );
    }
    foreach my $sub_map_key (@second_sub_map_keys) {
        my $sub_map_info = $self->{'sub_maps'}{$sub_map_key};
        next unless ($sub_map_info);
        $self->move_sub_map_on_parents_in_memory(
            window_key     => $window_key,
            sub_map_key    => $sub_map_key,
            parent_map_key => $merged_map_key,
            feature_start  => $second_map_offset
                + $sub_map_info->{'feature_start'},
            feature_stop => $second_map_offset
                + $sub_map_info->{'feature_stop'},
        );
    }

   # Always save the action and wipe any later changes.  A merge will kill the
   # redo path.
    my %action_data = (
        action                  => 'merge_maps',
        reverse_second_map      => $reverse_second_map,
        second_before_first     => $second_before_first,
        first_map_key           => $first_map_key,
        first_map_id            => $self->map_key_to_id($first_map_key),
        second_map_key          => $second_map_key,
        second_map_id           => $self->map_key_to_id($second_map_key),
        merged_map_key          => $merged_map_key,
        merged_map_id           => $self->map_key_to_id($merged_map_key),
        merged_map_name         => $merged_map_name,
        merged_map_start        => $merged_map_start,
        merged_map_stop         => $merged_map_stop,
        merged_feature_start    => $merged_feature_start,
        merged_feature_stop     => $merged_feature_stop,
        merged_map_flipped      => $merged_map_flipped,
        overlap_amount          => $overlap_amount,
        second_map_offset       => $second_map_offset,
        first_map_feature_accs  => \@first_map_feature_accs,
        second_map_feature_accs => \@second_map_feature_accs,
        first_sub_map_keys      => \@first_sub_map_keys,
        second_sub_map_keys     => \@second_sub_map_keys,
    );
    $self->add_action(
        window_key  => $window_key,
        action_data => \%action_data,
    );

    # Create the new pedigree
    $self->merge_map_pedigrees(
        merged_map_key    => $merged_map_key,
        merged_map_start  => $merged_map_start,
        merged_map_stop   => $merged_map_stop,
        first_map_key     => $first_map_key,
        first_map_start   => $first_map_start,
        first_map_stop    => $first_map_stop,
        second_map_key    => $second_map_key,
        second_map_start  => $second_map_start,
        second_map_stop   => $second_map_stop,
        second_map_offset => $second_map_offset,
    );

    # Create the new map data
    $self->app_data_module()->generate_map_data(
        old_map_id => $first_map_id,
        new_map_id => $merged_map_id,
        map_start  => $merged_map_start,
        map_stop   => $merged_map_stop,
        map_name   => $merged_map_name,
    );

    # Cut the ties with the other zones so the maps don't get re-drawn
    $self->remove_from_map_order(
        map_key  => $first_map_key,
        zone_key => $zone_key,
    );
    $self->remove_from_map_order(
        map_key  => $second_map_key,
        zone_key => $zone_key,
    );

    # Remove any drawn correspondences
    $self->remove_corrs_to_map(
        window_key => $window_key,
        map_key    => $first_map_key,
    );
    $self->remove_corrs_to_map(
        window_key => $window_key,
        map_key    => $second_map_key,
    );

    # Redraw
    $self->redraw_the_whole_window(
        window_key       => $window_key,
        reset_selections => 1,
    );

    return ( [ $merged_map_key, ], $zone_key );

    return;

}

# ----------------------------------------------------
sub move_map_subsection {

=pod

=head2 move_map_subsection

Move a chunk of one map into this one.

Create new maps and hide the original maps

=cut

    my ( $self, %args ) = @_;
    my $subsection_map_key    = $args{'subsection_map_key'};
    my $destination_map_key   = $args{'destination_map_key'};
    my $destination_gap_start = $args{'gap_start'};
    my $destination_gap_stop  = $args{'gap_stop'};

    my $insert_gap = 1;

    my $insertion_point
        = defined $destination_gap_stop
        ? $destination_gap_stop
        : $destination_gap_start;

    my $starting_map_key
        = $self->{'sub_maps'}{$subsection_map_key}{'parent_map_key'};
    my $subsection_feature_start
        = $self->{'sub_maps'}{$subsection_map_key}{'feature_start'};
    my $subsection_feature_stop
        = $self->{'sub_maps'}{$subsection_map_key}{'feature_stop'};

    my $starting_zone_key = $self->map_key_to_zone_key($starting_map_key);
    my $destination_zone_key
        = $self->map_key_to_zone_key($destination_map_key);
    my $ori_subsection_zone_key
        = $self->map_key_to_zone_key($subsection_map_key);

    my $window_key = $self->{'scaffold'}{$starting_zone_key}{'window_key'};

    # If the maps are in an opposite orientation, reverse the subsection
    my $reverse_subsection = 0;
    unless (
        $self->is_map_drawn_flipped(
            map_key  => $starting_map_key,
            zone_key => $starting_zone_key,
        ) == $self->is_map_drawn_flipped(
            map_key  => $destination_map_key,
            zone_key => $destination_zone_key,
        )
        )
    {
        $reverse_subsection = 1;
    }

    # Erase the subsection zone corrs because they will be untouchable later
    $self->erase_corrs_of_zone(
        window_key => $window_key,
        zone_key   => $ori_subsection_zone_key,
    );

    my $starting_map_id    = $self->map_key_to_id($starting_map_key);
    my $destination_map_id = $self->map_key_to_id($destination_map_key);

    my $starting_map_data
        = $self->app_data_module()->map_data( map_id => $starting_map_id );
    my $destination_map_data
        = $self->app_data_module()->map_data( map_id => $destination_map_id );

    my $same_parent_map = ( $starting_map_id == $destination_map_id ) ? 1 : 0;

    my $starting_feature_data = $self->app_data_module()
        ->feature_data_by_map( map_id => $starting_map_id, ) || [];
    my %feature_id_to_acc;

    # Check for overlapping features and return if that happens
    foreach my $feature (@$starting_feature_data) {
        $feature_id_to_acc{ $feature->{'feature_id'} }
            = $feature->{'feature_acc'};

        # If features overlap into the subsection, abort
        if ((       $feature->{'feature_start'} < $subsection_feature_start
                and $feature->{'feature_stop'} > $subsection_feature_start
            )
            or (    $feature->{'feature_start'} < $subsection_feature_stop
                and $feature->{'feature_stop'} > $subsection_feature_stop )
            )
        {
            $self->app_interface()
                ->popup_warning(
                text => 'Cannot move subsection because features '
                    . 'overlap into the subsection.', );
            return;
        }
    }
    my $destination_feature_data = $self->app_data_module()
        ->feature_data_by_map( map_id => $destination_map_id, ) || [];
    foreach my $feature (@$destination_feature_data) {
        $feature_id_to_acc{ $feature->{'feature_id'} }
            = $feature->{'feature_acc'};

        # If features overlap the gap, abort
        if (    $feature->{'feature_start'} < $insertion_point
            and $feature->{'feature_stop'} > $insertion_point )
        {
            $self->app_interface()
                ->popup_warning(
                text => 'Cannot move subsection because features '
                    . 'overlap the insertion position.', );
            return;
        }
    }

    my $excision_data = $self->excise_map_subsection(
        map_key                  => $starting_map_key,
        subsection_feature_start => $subsection_feature_start,
        subsection_feature_stop  => $subsection_feature_stop,
    );
    unless ($excision_data) {
        $self->app_interface()
            ->popup_warning( text => 'Problem excising the subsection.', );
        return;
    }

    my $new_starting_map_id     = $excision_data->{'new_map_id'};
    my $new_starting_map_key    = $excision_data->{'new_map_key'};
    my $subsection_feature_accs = $excision_data->{'subsection_feature_accs'};
    my $subsection_feature_id_to_acc
        = $excision_data->{'subsection_feature_id_to_acc'};
    my $starting_front_sub_map_keys
        = $excision_data->{'map_front_sub_map_keys'};
    my $starting_back_sub_map_keys
        = $excision_data->{'map_back_sub_map_keys'};
    my $starting_back_offset = $excision_data->{'map_back_offset'};

    if ($same_parent_map) {
        $destination_map_id  = $new_starting_map_id;
        $destination_map_key = $new_starting_map_key;

        if ( $subsection_feature_stop < $insertion_point ) {
            $insertion_point += $excision_data->{'map_back_offset'};
        }
    }

    if ($reverse_subsection) {
        my $starting_unit_granularity
            = $self->unit_granularity( $starting_map_data->{'map_type_acc'} );
        $self->reverse_map_section(
            map_key          => $starting_map_key,
            map_data         => $starting_map_data,
            unit_granularity => $starting_unit_granularity,
            feature_accs     => $subsection_feature_accs,
            reverse_start    => $subsection_feature_start,
            reverse_stop     => $subsection_feature_stop,
        );
    }

    my $subsection_offset = $insertion_point
        - ( $subsection_feature_start - $starting_map_data->{'map_start'} );
    my $insertion_data = $self->insert_map_subsection(
        map_key                      => $destination_map_key,
        ori_subsection_feature_start => $subsection_feature_start,
        ori_subsection_feature_stop  => $subsection_feature_stop,
        insertion_point              => $insertion_point,
        original_map_id              => $starting_map_id,
        original_map_key             => $starting_map_key,
        original_zone_key            => $starting_zone_key,
        insert_gap                   => $insert_gap,
        subsection_feature_accs      => $subsection_feature_accs,
        subsection_feature_id_to_acc => $subsection_feature_id_to_acc,
        subsection_offset            => $subsection_offset,
    );
    unless ($insertion_data) {
        $self->app_interface()
            ->popup_warning( text => 'Problem inserting the subsection.', );
        return;
    }

    my $new_destination_map_id  = $insertion_data->{'new_map_id'};
    my $new_destination_map_key = $insertion_data->{'new_map_key'};
    my $subsection_sub_map_keys
        = $insertion_data->{'subsection_sub_map_keys'};
    my $destination_front_sub_map_keys
        = $insertion_data->{'map_front_sub_map_keys'};
    my $destination_back_sub_map_keys
        = $insertion_data->{'map_back_sub_map_keys'};
    my $destination_back_offset = $insertion_data->{'map_back_offset'};

    # Always save the action and wipe any later changes.
    # This will kill the redo path.
    my %action_data = (
        action                  => 'move_map_subsection',
        subsection_map_key      => $subsection_map_key,
        subsection_map_id       => $self->map_key_to_id($subsection_map_key),
        starting_map_key        => $starting_map_key,
        starting_map_id         => $self->map_key_to_id($starting_map_key),
        new_starting_map_key    => $new_starting_map_key,
        new_starting_map_id     => $new_starting_map_id,
        destination_map_key     => $destination_map_key,
        destination_map_id      => $self->map_key_to_id($destination_map_key),
        new_destination_map_key => $new_destination_map_key,
        new_destination_map_id  => $new_destination_map_id,
        subsection_offset       => $subsection_offset,
        starting_back_offset    => $starting_back_offset,
        destination_back_offset => $destination_back_offset,
        destination_gap_start   => $destination_gap_start,
        destination_gap_stop    => $destination_gap_stop,
        same_parent_map         => $same_parent_map,
        insertion_point         => $insertion_point,
        excision_point          => $excision_data->{'excision_point'},
        insertion_start         => $insertion_data->{'insertion_start'},
        insertion_stop          => $insertion_data->{'insertion_stop'},
        delete_starting_map     => $excision_data->{'delete_starting_map'},
        starting_map_order_index =>
            $excision_data->{'starting_map_order_index'},
        starting_front_sub_map_keys    => $starting_front_sub_map_keys,
        starting_back_sub_map_keys     => $starting_back_sub_map_keys,
        subsection_sub_map_keys        => $subsection_sub_map_keys,
        subsection_feature_start       => $subsection_feature_start,
        subsection_feature_stop        => $subsection_feature_stop,
        destination_front_sub_map_keys => $destination_front_sub_map_keys,
        destination_back_sub_map_keys  => $destination_back_sub_map_keys,
        reverse_subsection             => $reverse_subsection,
    );
    $self->add_action(
        window_key  => $window_key,
        action_data => \%action_data,
    );

    # Create the new pedigree
    $self->move_subsection_pedigree(
        starting_map_key         => $starting_map_key,
        starting_map_start       => $starting_map_data->{'map_start'},
        starting_map_stop        => $starting_map_data->{'map_stop'},
        new_starting_map_key     => $new_starting_map_key,
        destination_map_key      => $destination_map_key,
        destination_map_start    => $destination_map_data->{'map_start'},
        destination_map_stop     => $destination_map_data->{'map_stop'},
        new_destination_map_key  => $new_destination_map_key,
        subsection_feature_start => $subsection_feature_start,
        subsection_feature_stop  => $subsection_feature_stop,
        insertion_point          => $insertion_point,
        starting_back_offset     => $starting_back_offset,
        destination_back_offset  => $destination_back_offset,
        subsection_offset        => $subsection_offset,
        same_parent_map          => $same_parent_map,
    );

    # Select the destination zone
    my $new_subsection_zone_key
        = $self->map_key_to_zone_key($subsection_map_key);
    my $new_subsection_map_set_id
        = $self->{'scaffold'}{$new_subsection_zone_key}{'map_set_id'};
    my $new_subsection_map_set_data = $self->app_data_module()
        ->get_map_set_data( map_set_id => $new_subsection_map_set_id, );
    $self->app_interface()->int_new_selected_zone(
        map_set_data     => $new_subsection_map_set_data,
        zone_key         => $new_subsection_zone_key,
        app_display_data => $self,
    );

    # Redraw
    $self->redraw_the_whole_window( window_key => $window_key, );

    return;

}

# ----------------------------------------------------
sub excise_map_subsection {

=pod

=head2 excise_map_subsection

Remove a chunk of one map and return the feature ids of the excised section
and the new map_id.

This method is not self-sufficient.  A calling method will have to do the
redraw.

Create new map and hide the original map.

=cut

    my ( $self, %args ) = @_;
    my $map_key                  = $args{'map_key'};
    my $subsection_feature_start = $args{'subsection_feature_start'};
    my $subsection_feature_stop  = $args{'subsection_feature_stop'};

    my $zone_key = $self->map_key_to_zone_key($map_key);

    my $window_key = $self->{'scaffold'}{$zone_key}{'window_key'};

    my $map_id = $self->map_key_to_id($map_key);

    # Reassign Features
    # Do this now because it might discover reasons to abort.
    my @map_front_feature_accs;
    my @map_back_feature_accs;
    my @subsection_feature_accs;

    my $feature_data
        = $self->app_data_module()->feature_data_by_map( map_id => $map_id, )
        || [];
    my %feature_id_to_acc;
    my %subsection_feature_id_to_acc;
    foreach my $feature (@$feature_data) {
        $feature_id_to_acc{ $feature->{'feature_id'} }
            = $feature->{'feature_acc'};

        # If features overlap into the subsection, abort
        if ((       $feature->{'feature_start'} < $subsection_feature_start
                and $feature->{'feature_stop'} > $subsection_feature_start
            )
            or (    $feature->{'feature_start'} < $subsection_feature_stop
                and $feature->{'feature_stop'} > $subsection_feature_stop )
            )
        {
            $self->app_interface()
                ->popup_warning(
                text => 'Cannot move subsection because features '
                    . 'overlap into the subsection.', );
            return undef;
        }
        elsif ( $feature->{'feature_stop'} < $subsection_feature_start ) {
            push @map_front_feature_accs, $feature->{'feature_acc'};
        }
        elsif ( $feature->{'feature_start'} > $subsection_feature_stop ) {
            push @map_back_feature_accs, $feature->{'feature_acc'};
        }
        else {
            push @subsection_feature_accs, $feature->{'feature_acc'};
            $subsection_feature_id_to_acc{ $feature->{'feature_id'} }
                = $feature->{'feature_acc'};
        }
    }

    # If there are no features outside of the subsection
    # Delete the starting map
    my $delete_starting_map = 0;
    unless ( @map_front_feature_accs or @map_back_feature_accs ) {
        $delete_starting_map = 1;
    }

    my $map_data = $self->app_data_module()->map_data( map_id => $map_id );

    my $unit_granularity
        = $self->unit_granularity( $map_data->{'map_type_acc'} );

    my $subsection_length
        = $subsection_feature_stop 
        - $subsection_feature_start
        + $unit_granularity;

    # Remove the drawing data for the old maps, do this now so that it will
    # affect sub-maps before they are re-assigned.
    destroy_map_for_relayout(
        app_display_data => $self,
        map_key          => $map_key,
        window_key       => $window_key,
        cascade          => 1,
    );

    my $map_back_offset = -1 * $subsection_length;

    my $new_map_id  = undef;
    my $new_map_key = undef;
    my @map_front_sub_map_keys;
    my @map_back_sub_map_keys;
    my $starting_map_order_index;

    if ($delete_starting_map) {
        $starting_map_order_index = $self->remove_from_map_order(
            map_key  => $map_key,
            zone_key => $zone_key,
        );
    }
    else {

        # The new maps info
        my $new_map_start = $map_data->{'map_start'};
        my $new_map_stop  = $map_data->{'map_stop'} - $subsection_length;
        my $new_map_name  = $map_data->{'map_name'};

        # Determine if the new map need to be flipped or not
        my $flipped = $self->{'map_layout'}{$map_key}{'flipped'};

        # Initialize the new maps
        $new_map_id  = $self->create_temp_id();
        $new_map_key = $self->initialize_map(
            map_id       => $new_map_id,
            zone_key     => $zone_key,
            draw_flipped => $flipped,
        );

        # Create the new map data
        $self->app_data_module()->generate_map_data(
            old_map_id => $map_id,
            new_map_id => $new_map_id,
            map_start  => $new_map_start,
            map_stop   => $new_map_stop,
            map_name   => $new_map_name,
        );

        # create hashes out of the feature acc lists
        my %map_front_feature_accs
            = map { ( $_ => 1 ) } @map_front_feature_accs;
        my %map_back_feature_accs
            = map { ( $_ => 1 ) } @map_back_feature_accs;
        my %subsection_feature_accs
            = map { ( $_ => 1 ) } @subsection_feature_accs;

        # Copy the features onto the new maps and then move them apropriately
        $self->app_data_module()->copy_feature_data_to_new_map(
            old_map_id => $map_id,
            new_map_id => $new_map_id,
            feature_acc_hash =>
                { %map_front_feature_accs, %map_back_feature_accs, },
        );
        $self->app_data_module()->move_feature_data_on_map(
            feature_acc_array => \@map_back_feature_accs,
            map_id            => $new_map_id,
            offset            => $map_back_offset,
        );

        # Handle sub map information if they are sub_maps
        my $sub_map_info = $self->{'sub_maps'}{$map_key};
        if ( %{ $sub_map_info || {} } ) {
            my $feature_start    = $sub_map_info->{'feature_start'};
            my $feature_type_acc = $sub_map_info->{'feature_type_acc'};

            my $feature_id = $self->create_temp_id();

            $self->{'sub_maps'}{$new_map_key} = {
                parent_map_key    => $sub_map_info->{'parent_map_key'},
                feature_start     => $sub_map_info->{'feature_start'},
                feature_stop      => $sub_map_info->{'feature_stop'},
                feature_id        => $sub_map_info->{'feature_id'},
                feature_direction => $sub_map_info->{'feature_direction'},
                feature_type_acc  => $sub_map_info->{'feature_type_acc'},
                feature_length    => $sub_map_info->{'feature_length'},
            };

            # BF Potentially link to the oritinal feature
        }

        # Move the sub maps over to the new maps
        foreach my $child_zone_key (
            $self->get_children_zones_of_map(
                map_key  => $map_key,
                zone_key => $zone_key,
            ),
            )
        {

            my @map_front_args_list;
            my @map_back_args_list;
            foreach my $sub_map_key (
                @{ $self->{'map_order'}{$child_zone_key} || [] } )
            {
                my $sub_map_info = $self->{'sub_maps'}{$sub_map_key};
                next unless ($sub_map_info);
                my $feature_acc
                    = $feature_id_to_acc{ $sub_map_info->{'feature_id'} };
                if ( $map_front_feature_accs{$feature_acc} ) {
                    push @map_front_sub_map_keys, $sub_map_key;
                    push @map_front_args_list,
                        {
                        window_key     => $window_key,
                        sub_map_key    => $sub_map_key,
                        parent_map_key => $new_map_key,
                        feature_start  => $sub_map_info->{'feature_start'},
                        feature_stop   => $sub_map_info->{'feature_stop'},
                        };
                }
                elsif ( $map_back_feature_accs{$feature_acc} ) {
                    push @map_back_sub_map_keys, $sub_map_key;
                    push @map_back_args_list,
                        {
                        window_key     => $window_key,
                        sub_map_key    => $sub_map_key,
                        parent_map_key => $new_map_key,
                        feature_start  => $sub_map_info->{'feature_start'}
                            + $map_back_offset,
                        feature_stop => $sub_map_info->{'feature_stop'}
                            + $map_back_offset,
                        };
                }
            }
            foreach my $sub_map_move_args (@map_front_args_list) {
                $self->move_sub_map_on_parents_in_memory( %$sub_map_move_args,
                );
            }
            foreach my $sub_map_move_args (@map_back_args_list) {
                $self->move_sub_map_on_parents_in_memory( %$sub_map_move_args,
                );
            }
        }

        # Cut the ties with the other zones so the maps don't get re-drawn
        $self->replace_in_map_order(
            old_map_key => $map_key,
            new_map_key => $new_map_key,
            zone_key    => $zone_key,
        );
    }

    # Remove any drawn correspondences
    $self->remove_corrs_to_map(
        window_key => $window_key,
        map_key    => $map_key,
    );

    return {
        subsection_feature_accs      => \@subsection_feature_accs,
        new_map_id                   => $new_map_id,
        new_map_key                  => $new_map_key,
        subsection_feature_id_to_acc => \%subsection_feature_id_to_acc,
        map_front_sub_map_keys       => \@map_front_sub_map_keys,
        map_back_sub_map_keys        => \@map_back_sub_map_keys,
        map_back_offset              => $map_back_offset,
        excision_point               => $subsection_feature_start,
        delete_starting_map          => $delete_starting_map,
        starting_map_order_index     => $starting_map_order_index,
    };

}

# ----------------------------------------------------
sub insert_map_subsection {

=pod

=head2 insert_map_subsection

Move a chunk of one map into this one.

This method is not self-sufficient.  A calling method will have to do the
redraw.

Create new map and hide the original map.

=cut

    my ( $self, %args ) = @_;
    my $map_key                 = $args{'map_key'};
    my $subsection_feature_accs = $args{'subsection_feature_accs'} || [];
    my $subsection_offset       = $args{'subsection_offset'};
    my %feature_id_to_acc = %{ $args{'subsection_feature_id_to_acc'} || {} };
    my $ori_subsection_feature_start = $args{'ori_subsection_feature_start'};
    my $ori_subsection_feature_stop  = $args{'ori_subsection_feature_stop'};
    my $original_map_id              = $args{'original_map_id'};
    my $original_map_key             = $args{'original_map_key'};
    my $original_zone_key            = $args{'original_zone_key'};
    my $insertion_point              = $args{'insertion_point'};
    my $insert_gap                   = $args{'insert_gap'} || 2;

    my $map_id     = $self->map_key_to_id($map_key);
    my $zone_key   = $self->map_key_to_zone_key($map_key);
    my $window_key = $self->{'scaffold'}{$zone_key}{'window_key'};
    my $map_data   = $self->app_data_module()->map_data( map_id => $map_id );

    if ( $insertion_point == $map_data->{'map_stop'} ) {
        $insertion_point += $insert_gap;
    }

    # Reassign Features
    # Do this now because it might discover reasons to abort.
    my @map_front_feature_accs;
    my @map_back_feature_accs;

    my $feature_data
        = $self->app_data_module()->feature_data_by_map( map_id => $map_id, )
        || [];
    foreach my $feature (@$feature_data) {
        $feature_id_to_acc{ $feature->{'feature_id'} }
            = $feature->{'feature_acc'};

        # If features overlap the gap, abort
        if (    $feature->{'feature_start'} < $insertion_point
            and $feature->{'feature_stop'} > $insertion_point )
        {
            $self->app_interface()
                ->popup_warning(
                text => 'Cannot move subsection because features '
                    . 'overlap the insertion position.', );
            return undef;
        }
        elsif ( $feature->{'feature_stop'} <= $insertion_point ) {
            push @map_front_feature_accs, $feature->{'feature_acc'};
        }
        else {
            push @map_back_feature_accs, $feature->{'feature_acc'};
        }
    }

    my $unit_granularity
        = $self->unit_granularity( $map_data->{'map_type_acc'} );

    my $subsection_length
        = $ori_subsection_feature_stop 
        - $ori_subsection_feature_start
        + $unit_granularity;

    # Remove the drawing data for the old maps, do this now so that it will
    # affect sub-maps before they are re-assigned.
    destroy_map_for_relayout(
        app_display_data => $self,
        map_key          => $map_key,
        window_key       => $window_key,
        cascade          => 1,
    );

    # New map info
    my $new_map_start = $map_data->{'map_start'};
    my $new_map_stop
        = $map_data->{'map_stop'} + $subsection_length + $insert_gap;
    my $new_map_name = $map_data->{'map_name'};

    # Determine if the new map need to be flipped or not
    my $flipped = $self->{'map_layout'}{$map_key}{'flipped'};

    # Initialize the new maps
    my $new_map_id  = $self->create_temp_id();
    my $new_map_key = $self->initialize_map(
        map_id       => $new_map_id,
        zone_key     => $zone_key,
        draw_flipped => $flipped,
    );

    # Create the new map data
    $self->app_data_module()->generate_map_data(
        old_map_id => $map_id,
        new_map_id => $new_map_id,
        map_start  => $new_map_start,
        map_stop   => $new_map_stop,
        map_name   => $new_map_name,
    );

    # create hashes out of the feature acc lists
    my %subsection_feature_accs
        = map { ( $_ => 1 ) } @$subsection_feature_accs;
    my %map_front_feature_accs = map { ( $_ => 1 ) } @map_front_feature_accs;
    my %map_back_feature_accs  = map { ( $_ => 1 ) } @map_back_feature_accs;

    my $map_back_offset = $subsection_length + $insert_gap;

    # Copy the features onto the new maps and then move them apropriately
    $self->app_data_module()->copy_feature_data_to_new_map(
        old_map_id       => $original_map_id,
        new_map_id       => $new_map_id,
        feature_acc_hash => \%subsection_feature_accs,
    );
    $self->app_data_module()->move_feature_data_on_map(
        feature_acc_array => $subsection_feature_accs,
        map_id            => $new_map_id,
        offset            => $subsection_offset,
    );
    $self->app_data_module()->copy_feature_data_to_new_map(
        old_map_id => $map_id,
        new_map_id => $new_map_id,
        feature_acc_hash =>
            { %map_front_feature_accs, %map_back_feature_accs, },
    );
    $self->app_data_module()->move_feature_data_on_map(
        feature_acc_array => \@map_back_feature_accs,
        map_id            => $new_map_id,
        offset            => $map_back_offset,
    );

    # Handle sub map information if they are sub_maps
    my $sub_map_info = $self->{'sub_maps'}{$map_key};
    if ( %{ $sub_map_info || {} } ) {
        my $feature_start    = $sub_map_info->{'feature_start'};
        my $feature_type_acc = $sub_map_info->{'feature_type_acc'};

        my $feature_id = $self->create_temp_id();

        $self->{'sub_maps'}{$new_map_key} = {
            parent_map_key   => $sub_map_info->{'parent_map_key'},
            feature_start    => $sub_map_info->{'feature_start'},
            feature_stop     => $sub_map_info->{'feature_stop'},
            feature_id       => $sub_map_info->{'feature_id'},
            feature_type_acc => $sub_map_info->{'feature_type_acc'},
            feature_length   => $sub_map_info->{'feature_length'},
        };

        # BF Potentially link to the oritinal feature
    }

    my @subsection_sub_map_keys;
    my @map_front_sub_map_keys;
    my @map_back_sub_map_keys;

    # Move the sub maps over to the new maps
    foreach my $child_zone_key (
        $self->get_children_zones_of_map(
            map_key  => $map_key,
            zone_key => $zone_key,
        ),
        $self->get_children_zones_of_map(
            map_key  => $original_map_key,
            zone_key => $original_zone_key,
        ),
        )
    {
        my @subsection_args_list;
        my @map_front_args_list;
        my @map_back_args_list;
        foreach my $sub_map_key (
            @{ $self->{'map_order'}{$child_zone_key} || [] } )
        {
            my $sub_map_info = $self->{'sub_maps'}{$sub_map_key};
            next unless ($sub_map_info);
            my $feature_acc
                = $feature_id_to_acc{ $sub_map_info->{'feature_id'} };
            if ( $subsection_feature_accs{$feature_acc} ) {
                push @subsection_sub_map_keys, $sub_map_key;
                push @subsection_args_list,
                    {
                    window_key     => $window_key,
                    sub_map_key    => $sub_map_key,
                    parent_map_key => $new_map_key,
                    feature_start  => $sub_map_info->{'feature_start'}
                        + $subsection_offset,
                    feature_stop => $sub_map_info->{'feature_stop'}
                        + $subsection_offset,
                    };
            }
            elsif ( $map_front_feature_accs{$feature_acc} ) {
                push @map_front_sub_map_keys, $sub_map_key;
                push @map_front_args_list,
                    {
                    window_key     => $window_key,
                    sub_map_key    => $sub_map_key,
                    parent_map_key => $new_map_key,
                    feature_start  => $sub_map_info->{'feature_start'},
                    feature_stop   => $sub_map_info->{'feature_stop'},
                    };
            }
            elsif ( $map_back_feature_accs{$feature_acc} ) {
                push @map_back_sub_map_keys, $sub_map_key;
                push @map_back_args_list,
                    {
                    window_key     => $window_key,
                    sub_map_key    => $sub_map_key,
                    parent_map_key => $new_map_key,
                    feature_start  => $sub_map_info->{'feature_start'}
                        + $map_back_offset,
                    feature_stop => $sub_map_info->{'feature_stop'}
                        + $map_back_offset,
                    };
            }
        }
        foreach my $sub_map_move_args (@subsection_args_list) {
            $self->move_sub_map_on_parents_in_memory( %$sub_map_move_args, );
        }
        foreach my $sub_map_move_args (@map_front_args_list) {
            $self->move_sub_map_on_parents_in_memory( %$sub_map_move_args, );
        }
        foreach my $sub_map_move_args (@map_back_args_list) {
            $self->move_sub_map_on_parents_in_memory( %$sub_map_move_args, );
        }
    }

    # Cut the ties with the other zones so the maps don't get re-drawn
    $self->replace_in_map_order(
        old_map_key => $map_key,
        new_map_key => $new_map_key,
        zone_key    => $zone_key,
    );

    # Remove any drawn correspondences
    $self->remove_corrs_to_map(
        window_key => $window_key,
        map_key    => $map_key,
    );

    return {
        new_map_id              => $new_map_id,
        new_map_key             => $new_map_key,
        subsection_sub_map_keys => \@subsection_sub_map_keys,
        map_front_sub_map_keys  => \@map_front_sub_map_keys,
        map_back_sub_map_keys   => \@map_back_sub_map_keys,
        map_back_offset         => $map_back_offset,
        insertion_start         => $insertion_point,
        insertion_stop          => $insertion_point + $subsection_length,
    };

}

# ----------------------------------------------------
sub undo_move_map_subsection {

=pod

=head2 undo_move_map_subsection

Undo the moving of a chunk of map

Destroy the new map and show the original

=cut

    my ( $self, %args ) = @_;
    my $subsection_map_key          = $args{'subsection_map_key'};
    my $starting_map_key            = $args{'starting_map_key'};
    my $destination_map_key         = $args{'destination_map_key'};
    my $new_starting_map_key        = $args{'new_starting_map_key'};
    my $new_destination_map_key     = $args{'new_destination_map_key'};
    my $excision_point              = $args{'excision_point'};
    my $insertion_start             = $args{'insertion_start'};
    my $insertion_stop              = $args{'insertion_stop'};
    my $subsection_offset           = $args{'subsection_offset'};
    my $starting_back_offset        = $args{'starting_back_offset'};
    my $destination_back_offset     = $args{'destination_back_offset'};
    my $starting_front_sub_map_keys = $args{'starting_front_sub_map_keys'};
    my $starting_back_sub_map_keys  = $args{'starting_back_sub_map_keys'};
    my $subsection_sub_map_keys     = $args{'subsection_sub_map_keys'};
    my $delete_starting_map         = $args{'delete_starting_map'};
    my $starting_map_order_index    = $args{'starting_map_order_index'};
    my $destination_front_sub_map_keys
        = $args{'destination_front_sub_map_keys'};
    my $destination_back_sub_map_keys
        = $args{'destination_back_sub_map_keys'};

    my $starting_zone_key = $self->map_key_to_zone_key($starting_map_key);
    my $destination_zone_key
        = $self->map_key_to_zone_key($destination_map_key);
    my $window_key = $self->{'scaffold'}{$starting_zone_key}{'window_key'};

    my $starting_map_id     = $self->map_key_to_id($starting_map_key);
    my $new_starting_map_id = $self->map_key_to_id($new_starting_map_key);
    my $destination_map_id  = $self->map_key_to_id($destination_map_key);
    my $new_destination_map_id
        = $self->map_key_to_id($new_destination_map_key);

    my $same_parent_map
        = ( $starting_map_key == $destination_map_key ) ? 1 : 0;

    if ($same_parent_map) {

        if ($delete_starting_map) {
            $self->insert_into_map_order(
                map_key  => $starting_map_key,
                index    => $starting_map_order_index,
                zone_key => $starting_zone_key,
            );
        }
        else {

            # Replace the new map with the original in the map order
            $self->replace_in_map_order(
                old_map_key => $new_destination_map_key,
                new_map_key => $starting_map_key,
                zone_key    => $starting_zone_key,
            );
            destroy_map_for_relayout(
                app_display_data => $self,
                map_key          => $new_starting_map_key,
                window_key       => $window_key,
                cascade          => 1,
            );
        }
    }
    else {

        if ($delete_starting_map) {
            $self->insert_into_map_order(
                map_key  => $starting_map_key,
                index    => $starting_map_order_index,
                zone_key => $starting_zone_key,
            );
        }
        else {

            # Replace the new maps with the original in the map order
            $self->replace_in_map_order(
                old_map_key => $new_starting_map_key,
                new_map_key => $starting_map_key,
                zone_key    => $starting_zone_key,
            );
            destroy_map_for_relayout(
                app_display_data => $self,
                map_key          => $new_starting_map_key,
                window_key       => $window_key,
                cascade          => 1,
            );
        }
        $self->replace_in_map_order(
            old_map_key => $new_destination_map_key,
            new_map_key => $destination_map_key,
            zone_key    => $destination_zone_key,
        );
        destroy_map_for_relayout(
            app_display_data => $self,
            map_key          => $new_destination_map_key,
            window_key       => $window_key,
            cascade          => 1,
        );
    }

    # Move the features back
    my @starting_map_front_feature_accs;
    my @starting_map_back_feature_accs;
    my @subsection_feature_accs;
    my @destination_map_front_feature_accs;
    my @destination_map_back_feature_accs;
    unless ($delete_starting_map) {
        foreach my $feature (
            @{  $self->app_data_module()
                    ->feature_data_by_map( map_id => $new_starting_map_id, )
                    || []
            }
            )
        {
            if ( $feature->{'feature_start'} < $excision_point ) {
                push @starting_map_front_feature_accs,
                    $feature->{'feature_acc'};
            }
            else {
                push @starting_map_back_feature_accs,
                    $feature->{'feature_acc'};
            }
        }
    }
    foreach my $feature (
        @{  $self->app_data_module()
                ->feature_data_by_map( map_id => $new_destination_map_id, )
                || []
        }
        )
    {
        if ( $feature->{'feature_stop'} < $insertion_start ) {
            push @destination_map_front_feature_accs,
                $feature->{'feature_acc'};
        }
        elsif ( $feature->{'feature_start'} > $insertion_stop ) {
            push @destination_map_back_feature_accs,
                $feature->{'feature_acc'};
        }
        else {
            push @subsection_feature_accs, $feature->{'feature_acc'};
        }
    }

    # Copy the features back onto the original maps
    unless ($delete_starting_map) {
        $self->app_data_module()->copy_feature_data_to_new_map(
            old_map_id => $new_starting_map_id,
            new_map_id => $starting_map_id,
            feature_acc_hash =>
                { map { ( $_ => 1 ) } @starting_map_front_feature_accs },
        );
        $self->app_data_module()->copy_feature_data_to_new_map(
            old_map_id => $new_starting_map_id,
            new_map_id => $starting_map_id,
            feature_acc_hash =>
                { map { ( $_ => 1 ) } @starting_map_back_feature_accs },
        );
    }
    $self->app_data_module()->copy_feature_data_to_new_map(
        old_map_id       => $new_destination_map_id,
        new_map_id       => $starting_map_id,
        feature_acc_hash => { map { ( $_ => 1 ) } @subsection_feature_accs },
    );
    $self->app_data_module()->copy_feature_data_to_new_map(
        old_map_id => $new_destination_map_id,
        new_map_id => $destination_map_id,
        feature_acc_hash =>
            { map { ( $_ => 1 ) } @destination_map_front_feature_accs },
    );
    $self->app_data_module()->copy_feature_data_to_new_map(
        old_map_id => $new_destination_map_id,
        new_map_id => $destination_map_id,
        feature_acc_hash =>
            { map { ( $_ => 1 ) } @destination_map_back_feature_accs },
    );

    # Move the appropriate features back by the offset
    $self->app_data_module()->move_feature_data_on_map(
        feature_acc_array => \@starting_map_back_feature_accs,
        map_id            => $starting_map_id,
        offset            => -1 * $starting_back_offset,
    );
    $self->app_data_module()->move_feature_data_on_map(
        feature_acc_array => \@subsection_feature_accs,
        map_id            => $starting_map_id,
        offset            => -1 * $subsection_offset,
    );
    $self->app_data_module()->move_feature_data_on_map(
        feature_acc_array => \@destination_map_back_feature_accs,
        map_id            => $destination_map_id,
        offset            => -1 * $destination_back_offset,
    );

    # Move sub maps back to their original maps
    foreach my $loop_array (
        [ $subsection_sub_map_keys, $starting_map_key, $subsection_offset ],
        [ $destination_front_sub_map_keys, $destination_map_key, 0 ],
        [   $destination_back_sub_map_keys, $destination_map_key,
            $destination_back_offset
        ],
        [ $starting_front_sub_map_keys, $starting_map_key, 0 ],
        [   $starting_back_sub_map_keys, $starting_map_key,
            $starting_back_offset
        ],
        )
    {
        my $sub_map_keys   = $loop_array->[0];
        my $parent_map_key = $loop_array->[1];
        my $offset         = $loop_array->[2];
        foreach my $sub_map_key ( @{ $sub_map_keys || [] } ) {
            my $sub_map_info = $self->{'sub_maps'}{$sub_map_key};
            next unless ($sub_map_info);
            $self->move_sub_map_on_parents_in_memory(
                window_key     => $window_key,
                sub_map_key    => $sub_map_key,
                parent_map_key => $parent_map_key,
                feature_start  => $sub_map_info->{'feature_start'} - $offset,
                feature_stop   => $sub_map_info->{'feature_stop'} - $offset,
            );
        }
    }

    unless ($delete_starting_map) {
        delete $self->{'sub_maps'}{$new_starting_map_key};
    }
    delete $self->{'sub_maps'}{$new_destination_map_key};

    # Delete temporary Biological data for the new map
    unless ($delete_starting_map) {
        $self->app_data_module()
            ->remove_map_data(
            map_id => $self->map_key_to_id($new_starting_map_key), );
    }
    $self->app_data_module()
        ->remove_map_data(
        map_id => $self->map_key_to_id($new_destination_map_key), );

    # Detach new map from the zone
    unless ($delete_starting_map) {
        $self->uninitialize_map(
            map_key  => $new_starting_map_key,
            zone_key => $starting_zone_key,
        );
    }
    $self->uninitialize_map(
        map_key  => $new_destination_map_key,
        zone_key => $destination_zone_key,
    );
    $self->cascade_reset_zone_corrs(
        window_key => $window_key,
        zone_key   => $starting_zone_key,
    );
    $self->cascade_reset_zone_corrs(
        window_key => $window_key,
        zone_key   => $destination_zone_key,
    );
    $self->app_interface()->draw_window(
        window_key       => $window_key,
        app_display_data => $self,
    );

    return;
}

# ----------------------------------------------------
sub undo_merge_maps {

=pod

=head2 undo_merge_maps

Undo the merging of two maps into one.

Destroy the new map and show the original

=cut

    my ( $self, %args ) = @_;
    my $reverse_second_map      = $args{'reverse_second_map'};
    my $merged_map_key          = $args{'merged_map_key'};
    my $first_map_key           = $args{'first_map_key'};
    my $second_map_key          = $args{'second_map_key'};
    my $second_map_offset       = $args{'second_map_offset'};
    my $first_sub_map_keys      = $args{'first_sub_map_keys'} || [];
    my $second_sub_map_keys     = $args{'second_sub_map_keys'} || [];
    my $first_map_feature_accs  = $args{'first_map_feature_accs'} || [];
    my $second_map_feature_accs = $args{'second_map_feature_accs'} || [];

    my $zone_key   = $self->map_key_to_zone_key($merged_map_key);
    my $window_key = $self->{'scaffold'}{$zone_key}{'window_key'};

    my $merged_map_id = $self->map_key_to_id($merged_map_key);
    my $first_map_id  = $self->map_key_to_id($first_map_key);
    my $second_map_id = $self->map_key_to_id($second_map_key);

    my $second_map_data
        = $self->app_data_module()->map_data( map_id => $second_map_id );

    # Reattach original maps to the zone
    push @{ $self->{'map_order'}{$zone_key} }, $first_map_key;
    push @{ $self->{'map_order'}{$zone_key} }, $second_map_key;

    destroy_map_for_relayout(
        app_display_data => $self,
        map_key          => $merged_map_key,
        window_key       => $window_key,
        cascade          => 1,
    );

    # Copy the features back onto the original maps
    $self->app_data_module()->copy_feature_data_to_new_map(
        old_map_id       => $merged_map_id,
        new_map_id       => $first_map_id,
        feature_acc_hash => { map { ( $_ => 1 ) } @$first_map_feature_accs },
    );
    $self->app_data_module()->copy_feature_data_to_new_map(
        old_map_id       => $merged_map_id,
        new_map_id       => $second_map_id,
        feature_acc_hash => { map { ( $_ => 1 ) } @$second_map_feature_accs },
    );

    # Move the second map's features back by the offset
    $self->app_data_module()->move_feature_data_on_map(
        feature_acc_array => $second_map_feature_accs,
        map_id            => $second_map_id,
        offset            => -1 * $second_map_offset,
    );

    # If second map was reversed, reverse it back now.
    if ($reverse_second_map) {
        $self->reverse_map_section(
            map_key      => $second_map_key,
            map_data     => $second_map_data,
            feature_accs => $second_map_feature_accs,
        );
    }

    # Move sub maps back to their original maps
    foreach my $loop_array (
        [ $first_sub_map_keys,  $first_map_key,  0, ],
        [ $second_sub_map_keys, $second_map_key, $second_map_offset, ],
        )
    {
        my $sub_map_keys   = $loop_array->[0];
        my $parent_map_key = $loop_array->[1];
        my $offset         = $loop_array->[2];
        foreach my $sub_map_key ( @{ $sub_map_keys || [] } ) {
            my $sub_map_info = $self->{'sub_maps'}{$sub_map_key};
            next unless ($sub_map_info);
            $self->move_sub_map_on_parents_in_memory(
                window_key     => $window_key,
                sub_map_key    => $sub_map_key,
                parent_map_key => $parent_map_key,
                feature_start  => $sub_map_info->{'feature_start'} - $offset,
                feature_stop   => $sub_map_info->{'feature_stop'} - $offset,
            );
        }
    }

    if ( $self->{'sub_maps'}{$merged_map_key} ) {
        delete $self->{'sub_maps'}{$merged_map_key};
    }

    # Delete temporary Biological data for the new map
    $self->app_data_module()
        ->remove_map_data( map_id => $self->map_key_to_id($merged_map_key), );

    # Detach new map from the zone
    $self->uninitialize_map(
        map_key  => $merged_map_key,
        zone_key => $zone_key,
    );
    $self->cascade_reset_zone_corrs(
        window_key => $window_key,
        zone_key   => $zone_key,
    );
    $self->app_interface()->draw_window(
        window_key       => $window_key,
        app_display_data => $self,
    );

    return;
}

# ----------------------------------------------------
sub map_pedigree {

=pod

=head2 map_pedigree

Get/Set the liniage of a map.  If the map is unmodified it will return undef;

=cut

    my $self         = shift;
    my $map_key      = shift or return undef;
    my $map_pedigree = shift;

    if ($map_pedigree) {
        $self->{'map_pedigree'}{$map_key} = $map_pedigree;
    }

    return $self->{'map_pedigree'}{$map_key};
}

# ----------------------------------------------------
sub split_map_pedigree {

=pod

=head2 split_map_pedigree

Assumes that the split maps keep the same coordinate system as the original.

=cut

    my ( $self, %args ) = @_;
    my $ori_map_key      = $args{'ori_map_key'} or return undef;
    my $ori_map_start    = $args{'ori_map_start'};
    my $ori_map_stop     = $args{'ori_map_stop'};
    my $first_map_key    = $args{'first_map_key'} or return undef;
    my $first_map_start  = $args{'first_map_start'};
    my $first_map_stop   = $args{'first_map_stop'};
    my $second_map_key   = $args{'second_map_key'} or return undef;
    my $second_map_start = $args{'second_map_start'};
    my $second_map_stop  = $args{'second_map_stop'};

    my $ori_map_id = $self->map_key_to_id($ori_map_key);

    my $ori_map_pedigree = $self->map_pedigree( $ori_map_key, );
    my @first_map_pedigree;
    my @second_map_pedigree;
    if ($ori_map_pedigree) {
        foreach my $fragment (@$ori_map_pedigree) {
            my $fragment_start  = $fragment->[0];
            my $fragment_stop   = $fragment->[1];
            my $ancestor_map_id = $fragment->[2];
            my $ancestor_start  = $fragment->[3];
            my $ancestor_stop   = $fragment->[4];

            # Is fragment on the first map
            if ( $fragment_stop < $first_map_stop ) {
                push @first_map_pedigree,
                    [
                    $fragment_start, $fragment_stop, $ancestor_map_id,
                    $ancestor_start, $ancestor_stop,
                    ];
            }
            elsif ( $fragment_start < $first_map_stop ) {
                push @first_map_pedigree,
                    [
                    $fragment_start,
                    $first_map_stop,
                    $ancestor_map_id,
                    $ancestor_start,
                    $ancestor_start + $first_map_stop - $fragment_start,
                    ];
            }

            # Is fragment on the second map
            if ( $fragment_start > $second_map_start ) {
                push @second_map_pedigree,
                    [
                    $fragment_start, $fragment_stop, $ancestor_map_id,
                    $ancestor_start, $ancestor_stop,
                    ];
            }
            elsif ( $fragment_stop > $second_map_start ) {
                push @second_map_pedigree,
                    [
                    $second_map_start,
                    $fragment_stop,
                    $ancestor_map_id,
                    $ancestor_stop - ( $fragment_stop - $second_map_start ),
                    $ancestor_stop,
                    ];
            }

        }
    }
    else {
        @first_map_pedigree = (
            [   $first_map_start, $first_map_stop, $ori_map_id,
                $first_map_start, $first_map_stop,
            ],
        );
        @second_map_pedigree = (
            [   $second_map_start, $second_map_stop, $ori_map_id,
                $second_map_start, $second_map_stop,
            ],
        );
    }

    # Save the new pedigrees
    $self->map_pedigree( $first_map_key,  \@first_map_pedigree, );
    $self->map_pedigree( $second_map_key, \@second_map_pedigree, );

    return 1;
}

# ----------------------------------------------------
sub merge_map_pedigrees {

=pod

=head2 merge_map_pedigrees

=cut

    my ( $self, %args ) = @_;
    my $merged_map_key    = $args{'merged_map_key'} or return undef;
    my $merged_map_start  = $args{'merged_map_start'};
    my $merged_map_stop   = $args{'merged_map_stop'};
    my $first_map_key     = $args{'first_map_key'} or return undef;
    my $first_map_start   = $args{'first_map_start'};
    my $first_map_stop    = $args{'first_map_stop'};
    my $second_map_key    = $args{'second_map_key'} or return undef;
    my $second_map_start  = $args{'second_map_start'};
    my $second_map_stop   = $args{'second_map_stop'};
    my $second_map_offset = $args{'second_map_offset'} || 0;

    my $first_map_id  = $self->map_key_to_id($first_map_key);
    my $second_map_id = $self->map_key_to_id($second_map_key);

    my $first_map_pedigree  = $self->map_pedigree( $first_map_key, );
    my $second_map_pedigree = $self->map_pedigree( $second_map_key, );

    my @merged_map_pedigree;
    if ($first_map_pedigree) {

        # Simply copy the first pedigree
        foreach my $fragment (@$first_map_pedigree) {
            my $fragment_start  = $fragment->[0];
            my $fragment_stop   = $fragment->[1];
            my $ancestor_map_id = $fragment->[2];
            my $ancestor_start  = $fragment->[3];
            my $ancestor_stop   = $fragment->[4];
            push @merged_map_pedigree,
                [
                $fragment_start, $fragment_stop, $ancestor_map_id,
                $ancestor_start, $ancestor_stop,
                ];
        }
    }
    else {
        push @merged_map_pedigree,
            [
            $first_map_start, $first_map_stop, $first_map_id,
            $first_map_start, $first_map_stop,
            ];
    }

    if ($second_map_pedigree) {

        # Copy the second pedigree but with the offset added
        foreach my $fragment (@$first_map_pedigree) {
            my $fragment_start  = $fragment->[0] + $second_map_offset;
            my $fragment_stop   = $fragment->[1] + $second_map_offset;
            my $ancestor_map_id = $fragment->[2];
            my $ancestor_start  = $fragment->[3];
            my $ancestor_stop   = $fragment->[4];
            push @merged_map_pedigree,
                [
                $fragment_start, $fragment_stop, $ancestor_map_id,
                $ancestor_start, $ancestor_stop,
                ];
        }
    }
    else {
        push @merged_map_pedigree,
            [
            $second_map_start + $second_map_offset,
            $second_map_stop + $second_map_offset,
            $second_map_id,
            $second_map_start,
            $second_map_stop,
            ];
    }

    # Save the new pedigree
    $self->map_pedigree( $merged_map_key, \@merged_map_pedigree, );

    return 1;
}

# ----------------------------------------------------
sub move_subsection_pedigree {

=pod

=head2 move_subsection_pedigree

=cut

    my ( $self, %args ) = @_;
    my $starting_map_key      = $args{'starting_map_key'} or return undef;
    my $starting_map_start    = $args{'starting_map_start'};
    my $starting_map_stop     = $args{'starting_map_stop'};
    my $new_starting_map_key  = $args{'new_starting_map_key'} or return undef;
    my $destination_map_key   = $args{'destination_map_key'} or return undef;
    my $destination_map_start = $args{'destination_map_start'};
    my $destination_map_stop  = $args{'destination_map_stop'};
    my $new_destination_map_key = $args{'new_destination_map_key'}
        or return undef;
    my $subsection_feature_start = $args{'subsection_feature_start'};
    my $subsection_feature_stop  = $args{'subsection_feature_stop'};
    my $insertion_point          = $args{'insertion_point'};
    my $starting_back_offset     = $args{'starting_back_offset'};
    my $destination_back_offset  = $args{'destination_back_offset'};
    my $subsection_offset        = $args{'subsection_offset'};
    my $same_parent_map          = $args{'same_parent_map'};

    my $starting_map_id       = $self->map_key_to_id($starting_map_key);
    my $starting_map_pedigree = $self->map_pedigree( $starting_map_key, );
    my $starting_map_data
        = $self->app_data_module()->map_data( map_id => $starting_map_id );

    my $unit_granularity
        = $self->unit_granularity( $starting_map_data->{'map_type_acc'} );

    my @new_starting_map_pedigree;
    my @subsection_pedigree;
    unless ($starting_map_pedigree) {
        $starting_map_pedigree = [];
        push @$starting_map_pedigree,
            [
            $starting_map_start, $starting_map_stop, $starting_map_id,
            $starting_map_start, $starting_map_stop,
            ];
    }

    # Excise the subsection from the starting pedigree
    foreach my $fragment (@$starting_map_pedigree) {
        my $fragment_start  = $fragment->[0];
        my $fragment_stop   = $fragment->[1];
        my $ancestor_map_id = $fragment->[2];
        my $ancestor_start  = $fragment->[3];
        my $ancestor_stop   = $fragment->[4];

        # Does this fragment end before the subsection
        if ( $fragment_stop < $subsection_feature_start ) {
            push @new_starting_map_pedigree,
                [
                $fragment_start, $fragment_stop, $ancestor_map_id,
                $ancestor_start, $ancestor_stop,
                ];
        }

        # Does this fragment start after the subsection
        elsif ( $fragment_start > $subsection_feature_stop ) {
            push @new_starting_map_pedigree,
                [
                $fragment_start + $starting_back_offset,
                $fragment_stop + $starting_back_offset,
                $ancestor_map_id,
                $ancestor_start,
                $ancestor_stop,
                ];
        }

        # Else the subsection and fragment overlap in some way.
        else {

            # Does the subsection cover the fragment
            if (    $subsection_feature_start <= $fragment_start
                and $subsection_feature_stop >= $fragment_stop )
            {
                push @subsection_pedigree,
                    [
                    $fragment_start, $fragment_stop, $ancestor_map_id,
                    $ancestor_start, $ancestor_stop,
                    ];
            }

            # Does the subsection overlap the start of the fragment
            elsif ( $subsection_feature_start <= $fragment_start ) {
                push @subsection_pedigree,
                    [
                    $fragment_start,
                    $subsection_feature_stop,
                    $ancestor_map_id,
                    $ancestor_start,
                    $ancestor_stop
                        - ( $fragment_stop - $subsection_feature_stop ),
                    ];
                push @new_starting_map_pedigree,
                    [
                    $subsection_feature_stop + $unit_granularity,
                    $fragment_stop,
                    $ancestor_map_id,
                    $ancestor_start
                        + ( $subsection_feature_stop - $fragment_start )
                        + $unit_granularity,
                    $ancestor_stop,
                    ];
            }

            # Does the subsection overlap the stop of the fragment
            elsif ( $subsection_feature_stop >= $fragment_stop ) {
                push @new_starting_map_pedigree,
                    [
                    $fragment_start,
                    $subsection_feature_stop - $unit_granularity,
                    $ancestor_map_id,
                    $ancestor_start,
                    $ancestor_stop
                        - ( $fragment_stop - $subsection_feature_start )
                        - $unit_granularity,
                    ];
                push @subsection_pedigree,
                    [
                    $subsection_feature_start,
                    $fragment_stop,
                    $ancestor_map_id,
                    $ancestor_start
                        + ( $subsection_feature_start - $fragment_start ),
                    $ancestor_stop,
                    ];
            }

            # Else the subsection is encased in this fragment
            else {
                push @new_starting_map_pedigree,
                    [
                    $fragment_start,
                    $subsection_feature_start - $unit_granularity,
                    $ancestor_map_id,
                    $ancestor_start,
                    $ancestor_stop
                        - ( $fragment_stop - $subsection_feature_start )
                        - $unit_granularity,
                    ];
                push @subsection_pedigree,
                    [
                    $subsection_feature_start,
                    $subsection_feature_stop,
                    $ancestor_map_id,
                    $ancestor_start
                        + ( $subsection_feature_start - $fragment_start ),
                    $ancestor_stop
                        - ( $fragment_stop - $subsection_feature_stop ),
                    ];
                push @new_starting_map_pedigree,
                    [
                    $subsection_feature_stop + $unit_granularity,
                    $fragment_stop,
                    $ancestor_map_id,
                    $ancestor_start
                        + ( $subsection_feature_stop - $fragment_start )
                        + $unit_granularity,
                    $ancestor_stop,
                    ];
            }
        }
    }

    # Prepare the subsection pedigree for insertion
    foreach my $fragment (@subsection_pedigree) {
        $fragment->[0] += $subsection_offset;
        $fragment->[1] += $subsection_offset;
    }

    # Insert the subsection into the destination map pedigree
    my $destination_map_pedigree;
    my $destination_map_id = $self->map_key_to_id($destination_map_key);
    if ($same_parent_map) {
        $destination_map_pedigree = \@new_starting_map_pedigree;
    }
    else {
        $destination_map_pedigree
            = $self->map_pedigree( $destination_map_key, );
    }

    unless ($destination_map_pedigree) {
        $destination_map_pedigree = [];
        push @$destination_map_pedigree,
            [
            $destination_map_start, $destination_map_stop,
            $destination_map_id,    $destination_map_start,
            $destination_map_stop,
            ];
    }

    my @new_destination_map_pedigree;
    foreach my $fragment (@$destination_map_pedigree) {
        my $fragment_start  = $fragment->[0];
        my $fragment_stop   = $fragment->[1];
        my $ancestor_map_id = $fragment->[2];
        my $ancestor_start  = $fragment->[3];
        my $ancestor_stop   = $fragment->[4];

        # Does this fragment end before the subsection
        if ( $fragment_stop < $insertion_point ) {
            push @new_destination_map_pedigree,
                [
                $fragment_start, $fragment_stop, $ancestor_map_id,
                $ancestor_start, $ancestor_stop,
                ];
        }

        # Does this fragment start after the subsection
        elsif ( $fragment_start > $subsection_feature_stop ) {
            push @new_destination_map_pedigree,
                [
                $fragment_start + $destination_back_offset,
                $fragment_stop + $destination_back_offset,
                $ancestor_map_id,
                $ancestor_start,
                $ancestor_stop,
                ];
        }

        # Else the subsection and fragment overlap in some way.
        else {
            if ( $fragment_start == $insertion_point ) {
                push @new_destination_map_pedigree, @subsection_pedigree;
                push @new_destination_map_pedigree,
                    [
                    $fragment_start + $destination_back_offset,
                    $fragment_stop + $destination_back_offset,
                    $ancestor_map_id,
                    $ancestor_start,
                    $ancestor_stop,
                    ];
            }
            elsif ( $fragment_stop == $insertion_point ) {
                push @new_destination_map_pedigree, $fragment;
                push @new_destination_map_pedigree, @subsection_pedigree;
            }
            else {
                push @new_destination_map_pedigree,
                    [
                    $fragment_start,
                    $insertion_point - $unit_granularity,
                    $ancestor_map_id,
                    $ancestor_start,
                    $ancestor_stop 
                        - ( $fragment_stop - $insertion_point )
                        - $unit_granularity,
                    ];
                push @new_destination_map_pedigree, @subsection_pedigree;
                push @new_destination_map_pedigree,
                    [
                    $insertion_point + $unit_granularity,
                    $fragment_stop,
                    $ancestor_map_id,
                    $ancestor_start 
                        + ( $insertion_point - $fragment_start )
                        + $unit_granularity,
                    $ancestor_stop,
                    ];
            }
        }
    }

    # Save the new pedigrees
    $self->map_pedigree( $new_destination_map_key,
        \@new_destination_map_pedigree,
    );
    unless ($same_parent_map) {
        $self->map_pedigree( $new_starting_map_key,
            \@new_starting_map_pedigree, );
    }

    return 1;
}

# ----------------------------------------------------
sub get_map_keys_from_id_and_a_list_of_zones {

=pod

=head2 get_map_keys_from_id_and_a_list_of_zones

=cut

    my ( $self, %args ) = @_;
    my $map_id = $args{'map_id'};
    my $zone_keys = $args{'zone_keys'} || [];

    my @map_keys;
    foreach my $zone_key (@$zone_keys) {
        if ( my $map_key
            = $self->map_id_to_key_by_zone( $map_id, $zone_key, ) )
        {
            push @map_keys, $map_key;
        }
    }

    return @map_keys;
}

# ----------------------------------------------------
sub move_sub_map_on_parents_in_memory {

=pod

=head2 move_sub_map_on_parents_in_memory

Do the actual in memory part of moving a map from one place on a parent to
another (and possibly on a different parent).

=cut

    my ( $self, %args ) = @_;
    my $sub_map_key        = $args{'sub_map_key'};
    my $new_parent_map_key = $args{'parent_map_key'};
    my $feature_start      = $args{'feature_start'};
    my $feature_stop       = $args{'feature_stop'};

    my $old_sub_zone_key    = $self->map_key_to_zone_key($sub_map_key);
    my $new_parent_zone_key = $self->map_key_to_zone_key($new_parent_map_key);
    my $window_key = $self->{'scaffold'}{$old_sub_zone_key}{'window_key'};

    my $old_sub_zone_scaffold = $self->{'scaffold'}{$old_sub_zone_key};
    my $old_parent_map_key    = $old_sub_zone_scaffold->{'parent_map_key'};

    # If it's on a new parent, change the sub map's parent
    unless ( $new_parent_map_key == $old_parent_map_key ) {
        my $map_set_id       = $old_sub_zone_scaffold->{'map_set_id'};
        my $new_sub_zone_key = $self->find_child_zone_for_map_set(
            map_set_id      => $map_set_id,
            parent_map_key  => $new_parent_map_key,
            parent_zone_key => $new_parent_zone_key,
        );

        # If it's in a new zone, change the sub map's zone
        unless ($new_sub_zone_key) {

            $new_sub_zone_key = $self->initialize_zone(
                window_key         => $window_key,
                map_set_id         => $map_set_id,
                parent_zone_key    => $new_parent_zone_key,
                parent_map_key     => $new_parent_map_key,
                attached_to_parent => 1,
                expanded           => 0,
                is_top             => 0,
                show_features => $old_sub_zone_scaffold->{'show_features'},
                map_labels_visible =>
                    $self->map_labels_visible($old_sub_zone_key),
                offscreen_corrs_visible =>
                    $self->offscreen_corrs_visible($old_sub_zone_key),
                copy_zone_key => $old_sub_zone_key,
            );
        }

        # Remove from old zone map order
        $self->remove_from_map_order(
            map_key  => $sub_map_key,
            zone_key => $old_sub_zone_key,
        );

        # Remove Zone if no more maps
        unless (
            scalar( @{ $self->{'map_order'}{$old_sub_zone_key} || [] } ) )
        {
            $self->delete_zone(
                window_key => $window_key,
                zone_key   => $old_sub_zone_key,
            );
        }

        # Add to new parent zone map order
        push @{ $self->{'map_order'}{$new_sub_zone_key} }, $sub_map_key;

        my $sub_map_id = $self->map_key_to_id($sub_map_key);
        $self->map_id_to_key_by_zone( $sub_map_id, $new_sub_zone_key,
            $sub_map_key );
        $self->map_key_to_zone_key( $sub_map_key, $new_sub_zone_key );
    }

    # Modify Parent
    $self->{'sub_maps'}{$sub_map_key}{'parent_map_key'} = $new_parent_map_key;
    $self->{'sub_maps'}{$sub_map_key}{'feature_start'}  = $feature_start;
    $self->{'sub_maps'}{$sub_map_key}{'feature_stop'}   = $feature_stop;

    return;
}

# ----------------------------------------------------
sub find_child_zone_for_map_set {

=pod

=head2 find_child_zone_for_map_set

=cut

    my ( $self, %args ) = @_;
    my $map_set_id       = $args{'map_set_id'};
    my $parent_map_key   = $args{'parent_map_key'};
    my $parent_zone_key  = $args{'parent_zone_key'};
    my $new_sub_zone_key = undef;

    foreach my $child_zone_key (
        $self->get_children_zones_of_map(
            map_key  => $parent_map_key,
            zone_key => $parent_zone_key,
        )
        )
    {
        if ( $map_set_id
            == $self->{'scaffold'}{$child_zone_key}{'map_set_id'} )
        {
            return $child_zone_key;
        }
    }
    return undef;
}

# ----------------------------------------------------
sub add_action {

=pod

=head2 add_action

Add an action to the action list for this window.  Remove any actions that may
be after this action (because of undoing).

=cut

    my ( $self, %args ) = @_;
    my $window_key  = $args{'window_key'};
    my $action_data = $args{'action_data'};

    if ( @{ $self->{'window_actions'}{$window_key}{'actions'} || [] } ) {
        $self->{'window_actions'}{$window_key}{'last_action_index'}++;
        my $last_action_index
            = $self->{'window_actions'}{$window_key}{'last_action_index'};
        $self->{'window_actions'}{$window_key}{'actions'}[$last_action_index]
            = $action_data;

        # Remove any actions following this one
        if ( $self->{'window_actions'}{$window_key}{'actions'}
            [ $last_action_index + 1 ] )
        {
            splice @{ $self->{'window_actions'}{$window_key}{'actions'}
                    || [] }, ( $last_action_index + 1 );
        }
    }
    else {
        $self->{'window_actions'}{$window_key}{'last_action_index'} = 0;
        $self->{'window_actions'}{$window_key}{'actions'} = [ $action_data, ];
    }

    return;
}

# ----------------------------------------------------
sub clear_actions {

=pod

=head2 clear_actions

Clear the action list for this window.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};

    $self->{'window_actions'}{$window_key}{'last_action_index'} = 0;
    $self->{'window_actions'}{$window_key}{'actions'}           = [];

    return;
}

# ----------------------------------------------------
sub undo_action {

=pod

=head2 undo_action

Undo the action that was just performed.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};

    my $window_actions = $self->{'window_actions'}{$window_key};

    my $last_action_index
        = $self->{'window_actions'}{$window_key}{'last_action_index'};
    return
        unless (
        defined $self->{'window_actions'}{$window_key}{'last_action_index'} );
    if ( not @{ $self->{'window_actions'}{$window_key}{'actions'} || [] }
        or $last_action_index < 0 )
    {

        # Can't go back any further
        return;
    }

    my $last_action = $window_actions->{'actions'}[$last_action_index];

    # Handle each action type
    if ( $last_action->{'action'} eq 'move_map' ) {
        $self->move_sub_map_on_parents_in_memory(
            window_key     => $window_key,
            sub_map_key    => $last_action->{'map_key'},
            parent_map_key => $last_action->{'old_parent_map_key'},
            feature_start  => $last_action->{'old_feature_start'},
            feature_stop   => $last_action->{'old_feature_stop'},
            undo_or_redo   => 1,
        );
    }
    elsif ( $last_action->{'action'} eq 'flip_map' ) {
        $self->flip_map(
            map_key      => $last_action->{'map_key'},
            undo_or_redo => 1,
        );
    }
    elsif ( $last_action->{'action'} eq 'split_map' ) {
        $self->undo_split_map(
            ori_map_key    => $last_action->{'ori_map_key'},
            first_map_key  => $last_action->{'first_map_key'},
            second_map_key => $last_action->{'second_map_key'},
            first_map_feature_accs =>
                $last_action->{'first_map_feature_accs'},
            second_map_feature_accs =>
                $last_action->{'second_map_feature_accs'},
        );
    }
    elsif ( $last_action->{'action'} eq 'merge_maps' ) {
        $self->undo_merge_maps(
            reverse_second_map  => $last_action->{'reverse_second_map'},
            first_map_key       => $last_action->{'first_map_key'},
            second_map_key      => $last_action->{'second_map_key'},
            merged_map_key      => $last_action->{'merged_map_key'},
            second_map_offset   => $last_action->{'second_map_offset'},
            first_sub_map_keys  => $last_action->{'first_sub_map_keys'},
            second_sub_map_keys => $last_action->{'second_sub_map_keys'},
            first_map_feature_accs =>
                $last_action->{'first_map_feature_accs'},
            second_map_feature_accs =>
                $last_action->{'second_map_feature_accs'},
        );
    }
    elsif ( $last_action->{'action'} eq 'move_map_subsection' ) {
        $self->undo_move_map_subsection(
            subsection_map_key   => $last_action->{'subsection_map_key'},
            starting_map_key     => $last_action->{'starting_map_key'},
            destination_map_key  => $last_action->{'destination_map_key'},
            new_starting_map_key => $last_action->{'new_starting_map_key'},
            new_destination_map_key =>
                $last_action->{'new_destination_map_key'},
            excision_point       => $last_action->{'excision_point'},
            insertion_start      => $last_action->{'insertion_start'},
            insertion_stop       => $last_action->{'insertion_stop'},
            insertion_point      => $last_action->{'insertion_point'},
            subsection_offset    => $last_action->{'subsection_offset'},
            starting_back_offset => $last_action->{'starting_back_offset'},
            delete_starting_map  => $last_action->{'delete_starting_map'},
            starting_map_order_index =>
                $last_action->{'starting_map_order_index'},
            destination_back_offset =>
                $last_action->{'destination_back_offset'},
            starting_front_sub_map_keys =>
                $last_action->{'starting_front_sub_map_keys'},
            starting_back_sub_map_keys =>
                $last_action->{'starting_back_sub_map_keys'},
            subsection_sub_map_keys =>
                $last_action->{'subsection_sub_map_keys'},
            destination_front_sub_map_keys =>
                $last_action->{'destination_front_sub_map_keys'},
            destination_back_sub_map_keys =>
                $last_action->{'destination_back_sub_map_keys'},
        );
    }

    $self->{'window_actions'}{$window_key}{'last_action_index'}--;

    # Redraw
    $self->redraw_the_whole_window(
        window_key       => $window_key,
        reset_selections => 1,
    );

    return;
}

# ----------------------------------------------------
sub redo_action {

=pod

=head2 redo_action

Redo the action that was last undone.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};

    my $window_actions = $self->{'window_actions'}{$window_key};

    return
        unless (
        defined $self->{'window_actions'}{$window_key}{'last_action_index'} );
    my $next_action_index
        = $self->{'window_actions'}{$window_key}{'last_action_index'} + 1;
    my $next_action = $window_actions->{'actions'}[$next_action_index];
    unless ( %{ $next_action || {} } ) {
        return;
    }

    # Handle each action type
    if ( $next_action->{'action'} eq 'move_map' ) {
        $self->move_sub_map_on_parents_in_memory(
            window_key     => $window_key,
            sub_map_key    => $next_action->{'map_key'},
            parent_map_key => $next_action->{'new_parent_map_key'},
            feature_start  => $next_action->{'new_feature_start'},
            feature_stop   => $next_action->{'new_feature_stop'},
            undo_or_redo   => 1,
        );
        $self->{'window_actions'}{$window_key}{'last_action_index'}++;
    }
    elsif ( $next_action->{'action'} eq 'flip_map' ) {
        $self->flip_map(
            map_key      => $next_action->{'map_key'},
            undo_or_redo => 1,
        );
        $self->{'window_actions'}{$window_key}{'last_action_index'}++;
    }
    elsif ( $next_action->{'action'} eq 'split_map' ) {
        $self->split_map(
            map_key        => $next_action->{'ori_map_key'},
            split_position => $next_action->{'split_position'},
            undo_or_redo   => 1,
        );
    }
    elsif ( $next_action->{'action'} eq 'merge_maps' ) {
        $self->merge_maps(
            first_map_key  => $next_action->{'first_map_key'},
            second_map_key => $next_action->{'second_map_key'},
            overlap_amount => $next_action->{'overlap_amount'},
        );
    }
    elsif ( $next_action->{'action'} eq 'move_map_subsection' ) {
        $self->move_map_subsection(
            subsection_map_key  => $next_action->{'subsection_map_key'},
            destination_map_key => $next_action->{'destination_map_key'},
            gap_start           => $next_action->{'destination_gap_start'},
            gap_stop            => $next_action->{'destination_gap_stop'},
        );
    }

    # Redraw
    $self->redraw_the_whole_window(
        window_key       => $window_key,
        reset_selections => 1,
    );

    return;
}

# ----------------------------------------------------
sub remove_from_map_order {

=pod

=head2 remove_from_map_order

=cut

    my ( $self, %args ) = @_;
    my $map_key  = $args{'map_key'};
    my $zone_key = $args{'zone_key'};

    my $old_index;
    for (
        my $i = 0;
        $i <= $#{ $self->{'map_order'}{$zone_key} || [] };
        $i++
        )
    {
        if ( $map_key == $self->{'map_order'}{$zone_key}[$i] ) {
            $old_index = $i;
            splice @{ $self->{'map_order'}{$zone_key} }, $i, 1;
            $i--;
        }
    }

    return $old_index;
}

# ----------------------------------------------------
sub insert_into_map_order {

=pod

=head2 insert_into_map_order

=cut

    my ( $self, %args ) = @_;
    my $map_key  = $args{'map_key'};
    my $index    = $args{'index'};
    my $zone_key = $args{'zone_key'};

    unless ( defined $index ) {
        $index = @{ $self->{'map_order'}{$zone_key} };
    }

    splice @{ $self->{'map_order'}{$zone_key} }, $index, 0, $map_key;

    return $index;
}

# ----------------------------------------------------
sub replace_in_map_order {

=pod

=head2 replace_in_map_order

This will replace the old map key with a new map key in the map order.  

If the both the new and old map keys are in the order, the old map key is
replaced and the original position of the new map key is spliced out.

If the if the old map key is not in the list, then the new map key will be
pushed onto the end (unless it is already in the list, in which case it will be
left alone).

=cut

    my ( $self, %args ) = @_;
    my $old_map_key = $args{'old_map_key'};
    my $new_map_key = $args{'new_map_key'};
    my $zone_key    = $args{'zone_key'};

    my $replaced_old_map = 0;
    my $new_map_index    = undef;
    for (
        my $i = 0;
        $i <= $#{ $self->{'map_order'}{$zone_key} || [] };
        $i++
        )
    {
        if ( $old_map_key == $self->{'map_order'}{$zone_key}[$i] ) {
            $self->{'map_order'}{$zone_key}[$i] = $new_map_key;
            $replaced_old_map = 1;
        }
        elsif ( $new_map_key == $self->{'map_order'}{$zone_key}[$i] ) {
            $new_map_index = $i;
        }
    }
    if ( $replaced_old_map and defined $new_map_index ) {
        splice @{ $self->{'map_order'}{$zone_key} }, $new_map_index, 1;
    }
    elsif ( not $replaced_old_map and not defined $new_map_index ) {
        push @{ $self->{'map_order'}{$zone_key} }, $new_map_index;
    }

    return;
}

# ----------------------------------------------------
sub window_actions {

=pod

=head2 window_actions

Accessor method for window actions;

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};

    if ($window_key) {
        return $self->{'window_actions'}{$window_key};
    }
    else {
        return $self->{'window_actions'};
    }

    return;
}

# ----------------------------------------------------
sub get_main_zone_offsets {

=pod

=head2 get_main_zone_offsets

Given a zone, figure out the coordinates on the main window.

=cut

    my ( $self, %args ) = @_;
    my $zone_key = $args{'zone_key'};
    my $bounds   = $self->{'zone_layout'}{$zone_key}{'bounds'};
    my $x_offset
        = $bounds->[0];    # + $self->{'scaffold'}{$zone_key}{'x_offset'};
    my $y_offset
        = $bounds->[1] + ( $self->{'scaffold'}{$zone_key}{'y_offset'} || 0 );

    if ( my $parent_zone_key
        = $self->{'scaffold'}{$zone_key}{'parent_zone_key'} )
    {
        my ( $parent_x_offset, $parent_y_offset )
            = $self->get_main_zone_offsets( zone_key => $parent_zone_key, );
        $x_offset += $parent_x_offset
            + ( $self->{'scaffold'}{$parent_zone_key}{'x_offset'} || 0 );
        $y_offset += $parent_y_offset
            + ( $self->{'scaffold'}{$parent_zone_key}{'y_offset'} || 0 );
    }

    return ( $x_offset, $y_offset );
}

# ----------------------------------------------------
sub reverse_map_section {

=pod

=head2 reverse_map_section

=cut

    my ( $self, %args ) = @_;
    my $map_key          = $args{'map_key'};
    my $map_data         = $args{'map_data'};
    my $feature_accs     = $args{'feature_accs'};
    my $unit_granularity = $args{'unit_granularity'}
        || $self->unit_granularity( $map_data->{'map_type_acc'} );
    my $zone_key = $args{'$zone_key'}
        || $self->map_key_to_zone_key($map_key);

    my $map_id = $map_data->{'map_id'};
    my $reverse_start
        = defined( $args{'reverse_start'} )
        ? $args{'reverse_start'}
        : $map_data->{'map_start'};
    my $reverse_stop
        = defined( $args{'reverse_stop'} )
        ? $args{'reverse_stop'}
        : $map_data->{'map_stop'};

    # Handle features first and get the modifier from it
    my $modifier_to_be_subtracted_from
        = $self->app_data_module()->reverse_features_on_map(
        map_id            => $map_id,
        unit_granularity  => $unit_granularity,
        feature_acc_array => $feature_accs,
        reverse_start     => $reverse_start,
        reverse_stop      => $reverse_stop,
        );

    # Handle sub maps
    my @sub_map_feature_ids;
    foreach my $child_zone_key (
        $self->get_children_zones_of_map(
            map_key  => $map_key,
            zone_key => $zone_key,
        )
        )
    {
        foreach my $sub_map_key (
            @{ $self->{'map_order'}{$child_zone_key} || [] } )
        {

            next
                unless ( $self->{'sub_maps'}{$sub_map_key}{'feature_stop'} <=
                    $reverse_stop
                and $self->{'sub_maps'}{$sub_map_key}{'feature_start'}
                >= $reverse_start );

            (   $self->{'sub_maps'}{$sub_map_key}{'feature_start'},
                $self->{'sub_maps'}{$sub_map_key}{'feature_stop'},
                $self->{'sub_maps'}{$sub_map_key}{'feature_direction'},
                )
                = $self->app_data_module()->reverse_feature_logic(
                modifier_to_be_subtracted_from =>
                    $modifier_to_be_subtracted_from,
                feature_start =>
                    $self->{'sub_maps'}{$sub_map_key}{'feature_start'},
                feature_stop =>
                    $self->{'sub_maps'}{$sub_map_key}{'feature_stop'},
                feature_direction =>
                    $self->{'sub_maps'}{$sub_map_key}{'feature_direction'},
                );

            push @sub_map_feature_ids,
                $self->{'sub_maps'}{$sub_map_key}{'feature_id'};
        }
    }

    $self->app_data_module()->reverse_sub_maps_on_map(
        modifier_to_be_subtracted_from => $modifier_to_be_subtracted_from,
        map_id                         => $map_id,
        sub_map_feature_ids            => \@sub_map_feature_ids,
    );

    return;
}
## ----------------------------------------------------
#sub move_drawing_items {
#
#=pod
#
#=head2 move_drawing_items
#
#moves drawing items by x and y
#
#Item structure:
#
#  [ changed, item_id, type, coord_array, options_hash ]
#
#
#=cut
#
#    my ( $self, %args ) = @_;
#    my $items         = $args{'items'};
#    my $dx         = $args{'dx'} || 0;
#    my $dy         = $args{'dy'} || 0;
#
#    foreach my $item ( @{ $items || [] } ) {
#        $item->[0] = 1;
#        $item->[3][0] += $dx;
#        $item->[3][2] += $dx;
#        $item->[3][1] += $dy;
#        $item->[3][3] += $dy;
#    }
#
#    return;
#}

# ----------------------------------------------------
sub place_highlight_location_on_parent_map {

=pod

=head2 place_highlight_location_on_parent_map

Controls how the parent map is highlighted

The main highlight bounds must already have been moved.

=cut

    my ( $self, %args ) = @_;
    my $map_key          = $args{'map_key'};
    my $highlight_bounds = $args{'highlight_bounds'};
    my $initiate         = $args{'initiate'} || 0;
    my $zone_key         = $args{'$zone_key'}
        || $self->map_key_to_zone_key($map_key);
    my $parent_map_key
        = $initiate
        ? $self->{'scaffold'}{$zone_key}{'parent_map_key'}
        : $args{'parent_map_key'}
        || $self->{'current_highlight_parent_map_key'}
        || $self->{'scaffold'}{$zone_key}{'parent_map_key'};
    return () unless ($parent_map_key);
    my $parent_zone_key = $args{'$parent_zone_key'}
        || $self->{'scaffold'}{$zone_key}{'parent_zone_key'};
    my $window_key = $self->{'scaffold'}{$zone_key}{'window_key'};

    my $parent_map_layout  = $self->{'map_layout'}{$parent_map_key};
    my $parent_zone_layout = $self->{'zone_layout'}{$parent_zone_key};

   # If no parent, don't bother
   # allow movement when the sub-map and parent were at different zoom levels.
    unless ($parent_zone_key
        and $self->{'scaffold'}{$zone_key}{'attached_to_parent'} )
    {
        return ();
    }

    # Center highlight on center of highlight map but using the corrds on the
    # parent map
    my $feature_length = $self->{'sub_maps'}{$map_key}{'feature_length'};

    my $parent_pixels_per_unit
        = $self->{'map_pixels_per_unit'}{$parent_map_key}
        || $self->{'scaffold'}{$parent_zone_key}{'pixels_per_unit'};
    my $feature_pixel_length = $parent_pixels_per_unit * $feature_length;

    # Get parent offsets
    my ( $parent_main_x_offset, $parent_main_y_offset )
        = $self->get_main_zone_offsets( zone_key => $parent_zone_key, );
    my $parent_x_offset = $self->{'scaffold'}{$parent_zone_key}{'x_offset'};

    # Get the center x of the highlight bounds and translate into the parents
    # coords
    my $highlight_center_x = int(
        ( $highlight_bounds->[2] + $highlight_bounds->[0] ) / 2 + 0.5 );
    my $center_x
        = $highlight_center_x - ( $parent_main_x_offset + $parent_x_offset );

    my $parent_start
        = $parent_map_layout->{'coords'}[0] 
        + $parent_main_x_offset
        + $parent_x_offset;
    my $parent_stop
        = $parent_map_layout->{'coords'}[2] 
        + $parent_main_x_offset
        + $parent_x_offset;

    # Work out x coords
    my $x1_on_parent = $highlight_center_x - int( $feature_pixel_length / 2 );
    my $x2_on_parent = $x1_on_parent + $feature_pixel_length;
    my $x1           = $highlight_center_x - int( $feature_pixel_length / 2 );
    my $x2           = $x1 + $feature_pixel_length;

    if (    $parent_start > $x1_on_parent
        and $parent_stop < $x2_on_parent )
    {

        # Feature bigger than the map, shrink the feature to the map length.
        my $x1_offset = $parent_start - $x1_on_parent;
        my $x2_offset = $parent_stop - $x2_on_parent;

        $x1_on_parent += $x1_offset;
        $x2_on_parent += $x2_offset;
        $x1           += $x1_offset;
        $x2           += $x2_offset;
    }
    elsif ( $parent_start > $x1_on_parent ) {

        # Not on the map to the right, push to the left
        my $offset = $parent_start - $x1_on_parent;
        $x1_on_parent += $offset;
        $x2_on_parent += $offset;
        $x1           += $offset;
        $x2           += $offset;
    }
    elsif ( $parent_stop < $x2_on_parent ) {

        # Not on the map to the left, push to the right
        my $offset = $x2_on_parent - $parent_stop;
        $x1_on_parent -= $offset;
        $x2_on_parent -= $offset;
        $x1           -= $offset;
        $x2           -= $offset;
    }

    # Get y coords
    my $y1 = $parent_map_layout->{'coords'}[1] + $parent_main_y_offset;
    my $y2 = $parent_map_layout->{'coords'}[3] + $parent_main_y_offset;

    my $visible = 1;
    if ($x2_on_parent < (
                  $parent_zone_layout->{'viewable_internal_x1'}
                + $parent_main_x_offset
                + $parent_x_offset
        )
        or $x1_on_parent > (
                  $parent_zone_layout->{'viewable_internal_x2'}
                + $parent_main_x_offset
                + $parent_x_offset
        )
        )
    {
        $visible = 0;
    }

    # save for later
    $self->{'current_highlight_parent_map_key'} = $parent_map_key;

    my %return_hash = (
        visible         => $visible,
        parent_zone_key => $parent_zone_key,
        window_key      => $window_key,
        parent_map_key  => $parent_map_key,
        location_coords => [ $x1_on_parent, $y1, $x2_on_parent, $y2 ],

        #location_coords => [ $x1, $y1, $x2, $y2 ],
    );

    return %return_hash;
}

# ----------------------------------------------------
sub place_subsection_location_on_parent_map {

=pod

=head2 place_subsection_location_on_parent_map

Controls where the parent map is highlighted

The main highlight bounds must already have been moved.

=cut

    my ( $self, %args ) = @_;
    my $map_key  = $args{'map_key'};
    my $mouse_x  = $args{'mouse_x'};
    my $mouse_y  = $args{'mouse_y'};
    my $initiate = $args{'initiate'} || 0;
    my $zone_key = $args{'$zone_key'}
        || $self->map_key_to_zone_key($map_key);
    my $map_id = $self->map_key_to_id($map_key);
    my $parent_map_key
        = $initiate
        ? $self->{'scaffold'}{$zone_key}{'parent_map_key'}
        : $args{'parent_map_key'}
        || $self->{'current_highlight_parent_map_key'}
        || $self->{'scaffold'}{$zone_key}{'parent_map_key'};
    return () unless ($parent_map_key);
    my $parent_map_id   = $self->map_key_to_id($parent_map_key);
    my $parent_zone_key = $args{'$parent_zone_key'}
        || $self->{'scaffold'}{$zone_key}{'parent_zone_key'};
    my $window_key = $self->{'scaffold'}{$zone_key}{'window_key'};

    my $parent_map_layout  = $self->{'map_layout'}{$parent_map_key};
    my $parent_zone_layout = $self->{'zone_layout'}{$parent_zone_key};

    # If no parent, don't bother.  Don't allow movement when the sub-map and
    # parent were at different zoom levels.
    unless ($parent_zone_key
        and $self->{'scaffold'}{$zone_key}{'attached_to_parent'} )
    {
        return ();
    }

    # Center highlight on center of highlight map but using the corrds on the
    # parent map
    my $feature_length   = $self->{'sub_maps'}{$map_key}{'feature_length'};
    my $feature_type_acc = $self->{'sub_maps'}{$map_key}{'feature_type_acc'};

    my $parent_pixels_per_unit
        = $self->{'map_pixels_per_unit'}{$parent_map_key}
        || $self->{'scaffold'}{$parent_zone_key}{'pixels_per_unit'};
    my $feature_pixel_length = $parent_pixels_per_unit * $feature_length;

    # Get parent offsets
    my ( $parent_main_x_offset, $parent_main_y_offset )
        = $self->get_main_zone_offsets( zone_key => $parent_zone_key, );
    my $parent_x_offset = $self->{'scaffold'}{$parent_zone_key}{'x_offset'};

    my $drawn_flipped = $self->is_map_drawn_flipped(
        map_key  => $parent_map_key,
        zone_key => $parent_zone_key,
    );

    my $center_in_parent_units = $self->convert_pixel_position_to_map_units(
        position      => $mouse_x,
        map_key       => $parent_map_key,
        zone_key      => $parent_zone_key,
        drawn_flipped => $drawn_flipped,
    );

    return () unless ( defined $center_in_parent_units );

    # Find a gap in the features
    my ( $gap_start, $gap_stop, $gap_feature_id1, $gap_feature_id2, )
        = $self->app_data_module()->find_closest_feature_gap(
        feature_type_acc => $feature_type_acc,
        map_position     => $center_in_parent_units,
        map_id           => $parent_map_id,
        );

    my $final_placement_in_parent_units;
    return () unless ( defined $gap_start or defined $gap_stop );
    if ( defined $gap_start and defined $gap_stop ) {
        $final_placement_in_parent_units = ( $gap_start + $gap_stop ) / 2;
    }
    elsif ( defined $gap_start ) {
        $final_placement_in_parent_units = $gap_start;
    }
    elsif ( defined $gap_stop ) {
        $final_placement_in_parent_units = $gap_stop;
    }

    # Figure out of the map actually moved
    my $map_did_not_move = 0;
    if ((       $gap_feature_id1
            and $gap_feature_id1
            == $self->{'sub_maps'}{$map_key}{'feature_id'}
        )
        or (    $gap_feature_id2
            and $gap_feature_id2
            == $self->{'sub_maps'}{$map_key}{'feature_id'} )
        )
    {
        $map_did_not_move = 1;
    }

    # Convert placement to pixel coords
    my $placement_in_pixels = $self->convert_map_position_to_pixels(
        position      => $final_placement_in_parent_units,
        map_key       => $parent_map_key,
        zone_key      => $parent_zone_key,
        drawn_flipped => $drawn_flipped,
    );

    my $y1 = $parent_map_layout->{'coords'}[1];
    my $y2 = $parent_map_layout->{'coords'}[3];

    my $visible = 1;
    if ( $placement_in_pixels
        < $parent_zone_layout->{'viewable_internal_x1'} + $parent_x_offset
        or $placement_in_pixels
        > $parent_zone_layout->{'viewable_internal_x2'} + $parent_x_offset )
    {
        $visible = 0;
    }

    # save for later
    $self->{'current_highlight_parent_map_key'} = $parent_map_key;

    my %return_hash = (
        visible          => $visible,
        parent_zone_key  => $parent_zone_key,
        window_key       => $window_key,
        parent_map_key   => $parent_map_key,
        gap_start        => $gap_start,
        gap_stop         => $gap_stop,
        map_did_not_move => $map_did_not_move,
        location_coords =>
            [ $placement_in_pixels, $y1, $placement_in_pixels, $y2 ],
    );

    return %return_hash;
}

# ----------------------------------------------------
sub convert_map_position_to_pixels {

=pod

=head2 convert_map_position_to_pixels

=cut

    my ( $self, %args ) = @_;
    my $zone_key      = $args{'zone_key'};
    my $map_key       = $args{'map_key'};
    my $drawn_flipped = $args{'drawn_flipped'};
    my $position      = $args{'position'};
    my $positions     = $args{'positions'} || [];

    my $return_single_val = 0;
    if ( defined $position ) {
        $return_single_val = 1;
        push @$positions, $position;
    }
    return undef unless (@$positions);

    my ( $x_offset, $y_offset )
        = $self->get_main_zone_offsets( zone_key => $zone_key, );
    my $map_id     = $self->map_key_to_id($map_key);
    my $map_data   = $self->app_data_module()->map_data( map_id => $map_id, );
    my $map_coords = $self->{'map_layout'}{$map_key}{'coords'};
    my $map_pixels_per_unit = ( $self->{'map_pixels_per_unit'}{$map_key}
            || $self->{'scaffold'}{$zone_key}{'pixels_per_unit'} );

    # Convert placement to pixel coords
    my @pixel_array;
    foreach my $pos (@$positions) {
        my $relative_placement_in_units;
        if ($drawn_flipped) {
            $relative_placement_in_units = $map_data->{'map_stop'} - $pos;
        }
        else {
            $relative_placement_in_units = $pos - $map_data->{'map_start'};
        }
        my $relative_pixel_placement
            = $relative_placement_in_units * $map_pixels_per_unit;

        push @pixel_array,
            ( $relative_pixel_placement + $map_coords->[0] + $x_offset );
    }

    # If only asking for this one, just return it
    if ($return_single_val) {
        return $pixel_array[0];
    }

    return @pixel_array if (wantarray);
    return \@pixel_array;

}

# ----------------------------------------------------
sub convert_pixel_position_to_map_units {

=pod

=head2 convert_pixel_position_to_map_units

=cut

    my ( $self, %args ) = @_;
    my $zone_key      = $args{'zone_key'};
    my $map_key       = $args{'map_key'};
    my $drawn_flipped = $args{'drawn_flipped'};
    my $position      = $args{'position'};
    my $positions     = $args{'positions'} || [];

    my $return_single_val = 0;
    if ( defined $position ) {
        $return_single_val = 1;
        push @$positions, $position;
    }
    return undef unless (@$positions);

    my ( $x_offset, $y_offset )
        = $self->get_main_zone_offsets( zone_key => $zone_key, );
    my $map_id     = $self->map_key_to_id($map_key);
    my $map_data   = $self->app_data_module()->map_data( map_id => $map_id, );
    my $map_coords = $self->{'map_layout'}{$map_key}{'coords'};
    my $map_pixels_per_unit = ( $self->{'map_pixels_per_unit'}{$map_key}
            || $self->{'scaffold'}{$zone_key}{'pixels_per_unit'} );

    my @unit_array;
    foreach my $pos (@$positions) {

        # Check if the position is off the map.
        if ( $pos < $map_coords->[0] or $pos > $map_coords->[2] ) {
            push @unit_array, undef;
        }
        else {
            my $relative_pixel_loc = $pos - $map_coords->[0] - $x_offset;

            my $relative_unit_loc
                = $relative_pixel_loc / $map_pixels_per_unit;
            my $position_in_units;
            if ($drawn_flipped) {
                $position_in_units
                    = ( $map_data->{'map_stop'} - $relative_unit_loc );
            }
            else {
                $position_in_units
                    = ( $relative_unit_loc + $map_data->{'map_start'} );
            }

            push @unit_array, $position_in_units;
        }
    }

    # If only asking for this one, just return it
    if ($return_single_val) {
        return $unit_array[0];
    }

    return @unit_array if (wantarray);
    return \@unit_array;
}

# ----------------------------------------------------
sub move_location_highlights {

=pod

=head2 move_location_highlights

Controls how the highlight map moves on the parents.

=cut

    my ( $self, %args ) = @_;
    my $map_key          = $args{'map_key'};
    my $mouse_x          = $args{'mouse_x'};
    my $mouse_y          = $args{'mouse_y'};
    my $highlight_bounds = $args{'highlight_bounds'};
    my $mouse_to_edge_x  = $args{'mouse_to_edge_x'};

    my $zone_key        = $self->map_key_to_zone_key($map_key);
    my $window_key      = $self->{'scaffold'}{$zone_key}{'window_key'};
    my $parent_zone_key = $self->{'scaffold'}{$zone_key}{'parent_zone_key'};
    return unless ($parent_zone_key);
    my $parent_map_set_id
        = $self->{'scaffold'}{$parent_zone_key}{'map_set_id'};

   # If no parent, don't let it move. This is because it would be confusing to
   # allow movement when the sub-map and parent were at different zoom levels.
    unless ($parent_zone_key
        and $self->{'scaffold'}{$zone_key}{'attached_to_parent'} )
    {
        return;
    }
    my $highlight_parent_map_key = $self->find_highlight_parent_map(
        highlight_zone_key => $zone_key,
        highlight_map_key  => $map_key,
        parent_map_set_id  => $parent_map_set_id,
        parent_zone_key    => $parent_zone_key,
        mouse_x            => $mouse_x,
        mouse_y            => $mouse_y,
    );
    my $highlight_parent_zone_key
        = $self->map_key_to_zone_key($highlight_parent_map_key);

    my %highlight_location_data
        = $self->place_highlight_location_on_parent_map(
        map_key          => $map_key,
        zone_key         => $zone_key,
        highlight_bounds => $highlight_bounds,
        parent_zone_key  => $highlight_parent_zone_key,
        );

    my %return_hash = (
        highlight_loc_visible         => $highlight_location_data{'visible'},
        highlight_loc_parent_zone_key => $highlight_parent_zone_key,
        window_key                    => $window_key,
        highlight_loc_location_coords =>
            $highlight_location_data{'location_coords'},
    );

    return %return_hash;

}

# ----------------------------------------------------
sub move_subsection_location_highlights {

=pod

=head2 move_subsection_location_highlights

Controls how the highlight map moves on the parents.

=cut

    my ( $self, %args ) = @_;
    my $map_key = $args{'map_key'};
    my $mouse_x = $args{'mouse_x'};
    my $mouse_y = $args{'mouse_y'};
    my $previous_subsection_location_coords
        = $args{'previous_subsection_location_coords'};
    my $mouse_to_edge_x = $args{'mouse_to_edge_x'};

    my $zone_key        = $self->map_key_to_zone_key($map_key);
    my $window_key      = $self->{'scaffold'}{$zone_key}{'window_key'};
    my $parent_zone_key = $self->{'scaffold'}{$zone_key}{'parent_zone_key'};
    return () unless ($parent_zone_key);
    my $parent_map_set_id
        = $self->{'scaffold'}{$parent_zone_key}{'map_set_id'};

   # If no parent, don't let it move. This is because it would be confusing to
   # allow movement when the sub-map and parent were at different zoom levels.
    unless ($parent_zone_key
        and $self->{'scaffold'}{$zone_key}{'attached_to_parent'} )
    {
        return ();
    }
    my $highlight_parent_map_key = $self->find_highlight_parent_map(
        highlight_zone_key => $zone_key,
        highlight_map_key  => $map_key,
        parent_map_set_id  => $parent_map_set_id,
        parent_zone_key    => $parent_zone_key,
        mouse_x            => $mouse_x,
        mouse_y            => $mouse_y,
    );
    my $highlight_parent_zone_key
        = $self->map_key_to_zone_key($highlight_parent_map_key);

    my %subsection_location_data
        = $self->place_subsection_location_on_parent_map(
        map_key         => $map_key,
        zone_key        => $zone_key,
        mouse_x         => $mouse_x,
        mouse_y         => $mouse_y,
        parent_zone_key => $highlight_parent_zone_key,
        );
    return () unless (%subsection_location_data);
    my $dx = $subsection_location_data{'location_coords'}->[0]
        - $previous_subsection_location_coords->[0];
    my $dy = $subsection_location_data{'location_coords'}->[1]
        - $previous_subsection_location_coords->[1];

    my %return_hash = (
        subsection_loc_visible => $subsection_location_data{'visible'},
        subsection_loc_parent_zone_key => $highlight_parent_zone_key,
        window_key                     => $window_key,
        subsection_loc_coords => $subsection_location_data{'location_coords'},
        dx                    => $dx,
        dy                    => $dy,
    );

    return %return_hash;

}

# ----------------------------------------------------
sub find_highlight_parent_map {

=pod

=head2 find_highlight_parent_map

Given a map_key and x and y coords, figure out if the mouse is in a new parent.

=cut

    my ( $self, %args ) = @_;
    my $highlight_zone_key = $args{'highlight_zone_key'};
    my $highlight_map_key  = $args{'highlight_map_key'};
    my $parent_map_set_id  = $args{'parent_map_set_id'};
    my $parent_zone_key    = $args{'parent_zone_key'};
    my $mouse_x            = $args{'mouse_x'};
    my $mouse_y            = $args{'mouse_y'};

    my $highlight_parent_maps = $self->get_highlight_parent_maps(
        parent_map_set_id  => $parent_map_set_id,
        highlight_zone_key => $highlight_zone_key,
    );

   # If not still in the current parent, check to see if it has entered any of
   # the other parents trigger space (their bounds).
    foreach my $highlight_parent_map ( @{ $highlight_parent_maps || [] } ) {
        if ($self->point_in_box(
                zone_key   => $parent_zone_key,
                x          => $mouse_x,
                y          => $mouse_y,
                box_coords => $highlight_parent_map->{'main_bounds'},
            )
            )
        {
            $self->{'current_highlight_parent_map_key'}
                = $highlight_parent_map->{'map_key'};
            return $self->{'current_highlight_parent_map_key'};
        }
    }

    return $self->{'current_highlight_parent_map_key'};
}

# ----------------------------------------------------
sub get_highlight_parent_maps {

=pod

=head2 highlight_parent_maps

Given a map_key and x and y coords, figure out if the mouse is in a new parent.

=cut

    my ( $self, %args ) = @_;
    my $parent_map_set_id  = $args{'parent_map_set_id'};
    my $highlight_zone_key = $args{'highlight_zone_key'};

    unless ( $self->{'highlight_parent_maps'}{$highlight_zone_key} ) {
        my $window_key
            = $self->{'scaffold'}{$highlight_zone_key}{'window_key'};

        # Get only zones in this window and have the parent map set id
        foreach my $zone_key (
            grep {
                        $self->{'scaffold'}{$_}
                    and $self->{'scaffold'}{$_}{'window_key'} eq $window_key
                    and $self->{'scaffold'}{$_}{'map_set_id'}
                    == $parent_map_set_id
            } keys %{ $self->{'scaffold'} || {} }
            )
        {
            my ( $x_offset, $y_offset )
                = $self->get_main_zone_offsets( zone_key => $zone_key, );
            foreach my $map_key ( @{ $self->{'map_order'}{$zone_key} || [] } )
            {
                my $map_bounds = $self->{'map_layout'}{$map_key}{'bounds'};
                my $main_bounds;
                $main_bounds->[0] = $x_offset + $map_bounds->[0];
                $main_bounds->[1] = $y_offset + $map_bounds->[1];
                $main_bounds->[2] = $x_offset + $map_bounds->[2];
                $main_bounds->[3] = $y_offset + $map_bounds->[3];

                push @{ $self->{'highlight_parent_maps'}
                        {$highlight_zone_key} },
                    ( { map_key => $map_key, main_bounds => $main_bounds, } );
            }
        }

    }

    return $self->{'highlight_parent_maps'}{$highlight_zone_key};
}

# ----------------------------------------------------
sub end_drag_highlight {

=pod

=head2 end_drag_highlight

Clear all of the values used during the highlight dragging so they don't muck
up the works next time.

=cut

    my ( $self, %args ) = @_;

    $self->{'current_highlight_parent_map_key'} = undef;

    return;
}

# ----------------------------------------------------
sub point_in_box {

=pod

=head2 point_in_box

Given box coords and x and y coords, figure out if the mouse is in a the box.

=cut

    my ( $self, %args ) = @_;
    my $x          = $args{'x'};
    my $y          = $args{'y'};
    my $box_coords = $args{'box_coords'};
    my $zone_key   = $args{'zone_key'};

    #my $x_offset   = $self->{'scaffold'}{$zone_key}{'x_offset'} || 0;
    #my $y_offset   = $self->{'scaffold'}{$zone_key}{'y_offset'} || 0;
    my $x_offset = 0;
    my $y_offset = 0;

    return (    $x >= $box_coords->[0] + $x_offset
            and $y >= $box_coords->[1] + $y_offset
            and $x <= $box_coords->[2] + $x_offset
            and $y <= $box_coords->[3] + $y_offset );
}

# ----------------------------------------------------
sub erase_corrs_of_zone {

=pod

=head2 erase_corrs_of_zone

Erase the corrs of a zone without turning corrs off.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $zone_key1  = $args{'zone_key'}   or return;

    foreach my $map_key1 ( @{ $self->{'map_order'}{$zone_key1} || [] } ) {
        foreach my $map_key2 (
            keys %{ $self->{'corr_layout'}{'maps'}{$map_key1} || {} } )
        {
            $self->remove_corrs_between_maps(
                window_key => $window_key,
                map_key1   => $map_key1,
                map_key2   => $map_key2,
            );
        }
    }

    return;
}

# ----------------------------------------------------
sub clear_corrs_of_zone {

=pod

=head2 clear_corrs_of_zone

Clears a zone of correspondences and calls on the interface to remove the drawings.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $zone_key1  = $args{'zone_key'}   or return;

    foreach my $zone_key2 (
        keys %{ $self->{'correspondences_on'}{$zone_key1} || {} } )
    {
        $self->clear_corrs_between_zones(
            window_key => $window_key,
            zone_key1  => $zone_key1,
            zone_key2  => $zone_key2,
        );
    }

    return;
}

# ----------------------------------------------------
sub clear_corrs_between_zones {

=pod

=head2 clear_corrs_between_zones

Clears a zone of correspondences and calls on the interface to remove the drawings.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $zone_key1  = $args{'zone_key1'}  or return;
    my $zone_key2  = $args{'zone_key2'}  or return;

    return unless ( $self->{'correspondences_on'}{$zone_key1}{$zone_key2} );

    $self->{'correspondences_on'}{$zone_key1}{$zone_key2} = 0;
    $self->{'correspondences_on'}{$zone_key2}{$zone_key1} = 0;
    my %zone2_maps;
    map { $zone2_maps{$_} = 1 } @{ $self->{'map_order'}{$zone_key2} || [] };

    foreach my $map_key1 ( @{ $self->{'map_order'}{$zone_key1} || [] } ) {
        foreach my $map_key2 (
            keys %{ $self->{'corr_layout'}{'maps'}{$map_key1} || {} } )
        {

            # Skip this one if the map2 is not in the target zone2
            next unless ( $zone2_maps{$map_key2} );
            $self->remove_corrs_between_maps(
                window_key => $window_key,
                map_key1   => $map_key1,
                map_key2   => $map_key2,
            );
        }
    }

    return;
}

# ----------------------------------------------------
sub remove_corrs_between_maps {

=pod

=head2 remove_corrs_between_maps

Removes correspondences between two maps.


=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $map_key1   = $args{'map_key1'}   or return;
    my $map_key2   = $args{'map_key2'}   or return;

    foreach my $corr (
        @{  $self->{'corr_layout'}{'maps'}{$map_key1}{$map_key2}{'corrs'}
                || []
        }
        )
    {
        $self->destroy_items(
            items      => $corr->{'items'},
            window_key => $window_key,
        );
    }

    # Unhighlight one of the maps since that will get any that connect to the
    # other.
    $self->app_interface()->unhighlight_map_corrs(
        window_key => $window_key,
        map_key    => $map_key1,
    );

    foreach my $corr (
        @{  $self->{'corr_layout'}{'maps'}{$map_key1}{$map_key2}
                {'highlight_ids'} || []
        }
        )
    {
        $self->destroy_items(
            items      => $corr->{'items'},
            window_key => $window_key,
        );
    }
    delete $self->{'corr_layout'}{'maps'}{$map_key1}{$map_key2};
    delete $self->{'corr_layout'}{'maps'}{$map_key2}{$map_key1};

    unless ( %{ $self->{'corr_layout'}{'maps'}{$map_key2} || {} } ) {
        delete $self->{'corr_layout'}{'maps'}{$map_key2};
    }
    unless ( %{ $self->{'corr_layout'}{'maps'}{$map_key1} || {} } ) {
        delete $self->{'corr_layout'}{'maps'}{$map_key1};
    }

    return;
}

# ----------------------------------------------------
sub remove_corrs_to_map {

=pod

=head2 remove_corrs_to_map

Removes all the correspondences to a single map

    $self->remove_corrs_to_map(
        window_key => $window_key,
        map_key  => $map_key,
    );


=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $map_key1   = $args{'map_key'}    or return;

    foreach my $map_key2 (
        keys %{ $self->{'corr_layout'}{'maps'}{$map_key1} || {} } )
    {
        $self->remove_corrs_between_maps(
            window_key => $window_key,
            map_key1   => $map_key1,
            map_key2   => $map_key2,
        );
    }

    return;
}

# ----------------------------------------------------
sub add_zone_corrs {

=pod

=head2 add_zone_corrs

Adds a zone of correspondences

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $zone_key1  = $args{'zone_key1'}  or return;
    my $zone_key2  = $args{'zone_key2'}  or return;

    unless ( $self->{'correspondences_on'}{$zone_key1}{$zone_key2} ) {
        $self->{'correspondences_on'}{$zone_key1}{$zone_key2} = 1;
        $self->{'correspondences_on'}{$zone_key2}{$zone_key1} = 1;

        add_correspondences(
            window_key       => $window_key,
            zone_key1        => $zone_key1,
            zone_key2        => $zone_key2,
            app_display_data => $self,
        );
    }

    return;
}

# ----------------------------------------------------
sub cascade_reset_zone_corrs {

=pod

=head2 cascade_reset_zone_corrs

Reset a zone's correspondences and it's childrens.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $zone_key   = $args{'zone_key'}   or return;

    $self->reset_zone_corrs(
        window_key => $window_key,
        zone_key   => $zone_key,
    );
    foreach my $child_zone_key (
        @{ $self->{'scaffold'}{$zone_key}{'children'} || [] } )
    {
        $self->cascade_reset_zone_corrs(
            window_key => $window_key,
            zone_key   => $child_zone_key,
        );
    }

    return;
}

# ----------------------------------------------------
sub reset_zone_corrs {

=pod

=head2 reset_zone_corrs

reset  a zone of correspondences

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $zone_key1  = $args{'zone_key'}   or return;

    foreach my $zone_key2 (
        keys %{ $self->{'correspondences_on'}{$zone_key1} || {} } )
    {

       # Stop drawing Corrs twice by only drawing when zone_key1 is less than
       # or equal to zone_key2.  Since each relationship is in there twice, it
       # will still hit every one.
       #next if ( $zone_key1 > $zone_key2 );

        next unless ( $self->{'correspondences_on'}{$zone_key1}{$zone_key2} );

        $self->clear_corrs_between_zones(
            window_key => $window_key,
            zone_key1  => $zone_key1,
            zone_key2  => $zone_key2,
        );
        $self->add_zone_corrs(
            window_key => $window_key,
            zone_key1  => $zone_key1,
            zone_key2  => $zone_key2,
        );
    }
    return;
}

# ----------------------------------------------------
sub delete_zone_corrs {

=pod

=head2 delete_zone_corrs

copy a zone of correspondences

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $zone_key   = $args{'zone_key'}   or return;

    $self->clear_corrs_of_zone(
        window_key => $window_key,
        zone_key   => $zone_key,
    );

    foreach my $zone_key2 (
        keys %{ $self->{'correspondences_on'}{$zone_key} || {} } )
    {
        delete $self->{'correspondences_on'}{$zone_key2}{$zone_key};
    }
    delete $self->{'correspondences_on'}{$zone_key};
    delete $self->{'zone_to_map_set_correspondences_on'}{$zone_key};

    return;
}

# ----------------------------------------------------
sub copy_zone_corrs {

=pod

=head2 copy_zone_corrs

copy a zone of correspondences

=cut

    my ( $self, %args ) = @_;
    my $window_key   = $args{'window_key'}   or return;
    my $ori_zone_key = $args{'ori_zone_key'} or return;
    my $new_zone_key = $args{'new_zone_key'} or return;

    foreach my $zone_key2 (
        keys %{ $self->{'correspondences_on'}{$ori_zone_key} || {} } )
    {
        my $value = $self->{'correspondences_on'}{$ori_zone_key}{$zone_key2};
        next unless ($value);

        # If it is a self corr, adjust zk2 to be the new zone
        if ( $zone_key2 == $ori_zone_key ) {
            $zone_key2 = $new_zone_key;
        }

        $self->{'correspondences_on'}{$new_zone_key}{$zone_key2} = $value;
        $self->{'correspondences_on'}{$zone_key2}{$new_zone_key} = $value;
    }
    $self->{'zone_to_map_set_correspondences_on'}{$new_zone_key}
        = $self->{'zone_to_map_set_correspondences_on'}{$ori_zone_key};

    return;
}

# ----------------------------------------------------
sub clear_window {

=pod

=head2 clear_window

Clears a window of data and calls on the interface to remove the drawings.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};

    $self->app_interface()->clear_interface_window(
        window_key       => $window_key,
        app_display_data => $self,
    );

    $self->remove_window_data( window_key => $window_key, );

}

# ----------------------------------------------------
sub destroy_items {

=pod

=head2 destroy_items

Destroys items that were drawn

=cut

    my ( $self, %args ) = @_;
    my $window_key  = $args{'window_key'};
    my $items       = $args{'items'};
    my $is_overview = $args{'is_overview'};

    $self->app_interface()->int_destroy_items(
        window_key  => $window_key,
        items       => $items,
        is_overview => $is_overview,
    );
}

# ----------------------------------------------------
sub delete_map {

=pod

=head2 delete_map

Deletes the map data and wipes them from the canvas

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $map_key    = $args{'map_key'};
    my $zone_key   = $args{'zone_key'};
    my $map_id     = $self->map_key_to_id($map_key);

    # Follow the tree first
    foreach my $child_zone_key (
        $self->get_children_zones_of_map(
            map_key  => $map_key,
            zone_key => $zone_key,
        )
        )
    {
        $self->delete_zone(
            window_key => $window_key,
            zone_key   => $child_zone_key,
        );
    }

    my $map_layout = $self->{'map_layout'}{$map_key};

    # Remove from zone
    $self->remove_from_map_order(
        map_key  => $map_key,
        zone_key => $zone_key,
    );

    # Remove correspondences
    $self->remove_corrs_to_map(
        window_key => $window_key,
        map_key    => $map_key,
    );

    # Remove Drawing info
    $self->destroy_items(
        window_key => $window_key,
        items      => $map_layout->{'items'},
    );

    delete $self->{'map_id_to_key_by_zone'}{$zone_key}{$map_id};
    delete $self->{'map_key_to_id'}{$map_key};
    delete $self->{'map_key_to_zone_key'}{$map_key};
    delete $self->{'map_layout'}{$map_key};

    return;
}

# ----------------------------------------------------
sub delete_zone {

=pod

=head2 delete_zone

Deletes the zone data and wipes them from the canvas

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $zone_key   = $args{'zone_key'};

    my $zone_layout = $self->{'zone_layout'}{$zone_key};
    my $map_set_id  = $self->{'scaffold'}{$zone_key}{'map_set_id'};

    # Remove Drawing info
    foreach my $drawing_item_name ( 'separator', 'background', 'scale_bar', )
    {
        $self->destroy_items(
            window_key => $window_key,
            items      => $zone_layout->{$drawing_item_name},
        );
        $zone_layout->{$drawing_item_name} = [];
    }

    # Remove the drawn buttons
    foreach my $button ( @{ $zone_layout->{'buttons'} || [] } ) {
        $self->destroy_items(
            window_key => $window_key,
            items      => $button->{'items'},
        );
    }
    $zone_layout->{'buttons'} = [];

    # Remove zone from window
    delete $self->{'zone_in_window'}{$window_key}{$zone_key};

    # Remove from map_set_id list
    for (
        my $i = 0;
        $i <= $#{ $self->{'map_set_id_to_zone_keys'}{$map_set_id} || [] };
        $i++
        )
    {
        if ($zone_key == $self->{'map_set_id_to_zone_keys'}{$map_set_id}[$i] )
        {
            splice @{ $self->{'map_set_id_to_zone_keys'}{$map_set_id} }, $i,
                1;
            $i--;
        }
    }

    $self->delete_zone_corrs(
        window_key => $window_key,
        zone_key   => $zone_key,
    );

    # Delete the maps in this zone
    my @map_keys = @{ $self->{'map_order'}{$zone_key} || [] };
    foreach my $map_key (@map_keys) {
        $self->delete_map(
            window_key => $window_key,
            map_key    => $map_key,
            zone_key   => $zone_key,
        );
    }

    # Remove from parent
    my $parent_zone_key = $self->{'scaffold'}{$zone_key}{'parent_zone_key'};
    for (
        my $i = 0;
        $i <= $#{ $self->{'scaffold'}{$parent_zone_key}{'children'} || [] };
        $i++
        )
    {
        if ( $zone_key
            == $self->{'scaffold'}{$parent_zone_key}{'children'}[$i] )
        {
            splice @{ $self->{'scaffold'}{$parent_zone_key}{'children'} }, $i,
                1;
            last;
        }
    }

    delete $self->{'zone_layout'}{$zone_key};
    delete $self->{'scaffold'}{$zone_key};
    delete $self->{'map_order'}{$zone_key};
    delete $self->{'slot_info'}{$zone_key};
    delete $self->{'map_id_to_key_by_zone'}{$zone_key};

    return;
}

# ----------------------------------------------------
sub wipe_window_canvases {

=pod

=head2 wipe_window_canvases

Removes only the drawing data from a window and clears the window using
AppInterface.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};

    foreach my $zone_key (
        keys %{ $self->{'zone_in_window'}{$window_key} || {} } )
    {
        foreach my $map_key ( @{ $self->{'map_order'}{$zone_key} || [] } ) {
            foreach my $feature_acc (
                keys %{ $self->{'map_layout'}{$map_key}{'features'} || {} } )
            {
                $self->destroy_items(
                    items => $self->{'map_layout'}{$map_key}{'features'}
                        {$feature_acc}{'items'},
                    window_key => $window_key,
                );
                $self->{'map_layout'}{$map_key}{'features'}{$feature_acc}
                    {'items'} = [];
            }
            $self->{'map_pixels_per_unit'}{$map_key} = undef;
            $self->{'map_layout'}{$map_key}{'bounds'} = [ 0, 0, 0, 0 ];
            $self->{'map_layout'}{$map_key}{'coords'} = [ 0, 0, 0, 0 ];
            $self->destroy_items(
                items      => $self->{'map_layout'}{$map_key}{'items'},
                window_key => $window_key,
            );
            $self->{'map_layout'}{$map_key}{'items'} = [];
            if ( $self->{'corr_layout'}{'maps'}{$map_key} ) {
                foreach my $map_key2 (
                    keys %{ $self->{'corr_layout'}{'maps'}{$map_key} || {} } )
                {
                    foreach my $corr (
                        @{  $self->{'corr_layout'}{'maps'}{$map_key}
                                {$map_key2}{'corrs'} || []
                        }
                        )
                    {
                        $self->destroy_items(
                            items      => $corr->{'items'},
                            window_key => $window_key,
                        );
                    }
                    $self->{'corr_layout'}{'maps'}{$map_key}{$map_key2}
                        {'items'} = [];
                }
            }
        }
        $self->{'zone_layout'}{$zone_key}{'bounds'}          = [ 0, 0, 0, 0 ];
        $self->{'zone_layout'}{$zone_key}{'internal_bounds'} = [ 0, 0, 0, 0 ];
        $self->{'zone_layout'}{$zone_key}{'maps_min_x'}   = undef;
        $self->{'zone_layout'}{$zone_key}{'maps_max_x'}   = undef;
        $self->{'scaffold'}{$zone_key}{'pixels_per_unit'} = undef;

        # Remove Drawing info
        foreach my $field ( 'separator', 'background', 'scale_bar', ) {
            $self->destroy_items(
                items      => $self->{'zone_layout'}{$zone_key}{$field},
                window_key => $window_key,
            );
            $self->{'zone_layout'}{$zone_key}{$field} = [];
        }

        # Remove the drawn buttons
        foreach my $button (
            @{ $self->{'zone_layout'}{$zone_key}{'buttons'} || [] } )
        {
            $self->destroy_items(
                window_key => $window_key,
                items      => $button->{'items'},
            );
        }
        $self->{'zone_layout'}{$zone_key}{'buttons'} = [];

    }
    $self->{'window_layout'}{$window_key}{'bounds'} = [ 0, 0, 0, 0 ];
    $self->destroy_items(
        items      => $self->{'window_layout'}{$window_key}{'misc_items'},
        window_key => $window_key,
    );
    $self->{'window_layout'}{$window_key}{'misc_items'} = [];

    # Overview
    $self->{'overview_layout'}{$window_key}{'bounds'} = [ 0, 0, 0, 0 ];
    $self->destroy_items(
        items       => $self->{'overview_layout'}{$window_key}{'misc_items'},
        window_key  => $window_key,
        is_overview => 1,
    );
    $self->{'overview_layout'}{$window_key}{'misc_items'} = [];
    foreach my $zone_key (
        keys %{ $self->{'overview_layout'}{$window_key}{'zones'} || {} } )
    {
        $self->{'overview_layout'}{$window_key}{'zones'}{$zone_key}{'bounds'}
            = [ 0, 0, 0, 0 ];
        $self->{'overview_layout'}{$window_key}{'zones'}{$zone_key}
            {'scale_factor_from_main'} = 0;
        foreach my $field (qw[ viewed_region misc_items ]) {
            $self->destroy_items(
                items => $self->{'overview_layout'}{$window_key}{'zones'}
                    {$zone_key}{$field},
                window_key  => $window_key,
                is_overview => 1,
            );
            $self->{'overview_layout'}{$window_key}{'zones'}{$zone_key}
                {$field} = [];
        }

        foreach my $map_key (
            keys %{
                $self->{'overview_layout'}{$window_key}{'zones'}{$zone_key}
                    {'maps'} || {}
            }
            )
        {
            $self->destroy_items(
                items => $self->{'overview_layout'}{$window_key}{'zones'}
                    {$zone_key}{'maps'}{$map_key}{'items'},
                window_key  => $window_key,
                is_overview => 1,
            );
            $self->{'overview_layout'}{$window_key}{'zones'}{$zone_key}
                {'maps'}{$map_key}{'items'} = [];
        }
    }

    return;
}

# ----------------------------------------------------
sub remove_window_data {

=pod

=head2 remove_window_data

Deletes the window data of a closed window.

Returns the number of remaining windows.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};

    foreach my $zone_key (
        keys %{ $self->{'zone_in_window'}{$window_key} || {} } )
    {
        foreach my $map_key ( @{ $self->{'map_order'}{$zone_key} || [] } ) {
            delete $self->{'map_id_to_keys'}
                { $self->{'map_key_to_id'}{$map_key} };
            delete $self->{'map_key_to_id'}{$map_key};
            delete $self->{'map_layout'}{$map_key};
        }
        delete $self->{'zone_layout'}{$zone_key};
        delete $self->{'scaffold'}{$zone_key};
        delete $self->{'map_order'}{$zone_key};
        delete $self->{'slot_info'}{$zone_key};
        delete $self->{'map_id_to_key_by_zone'}{$zone_key};
    }
    delete $self->{'window_layout'}{$window_key};
    delete $self->{'zone_in_window'}{$window_key};
    delete $self->{'overview'}{$window_key};
    delete $self->{'overview_layout'}{$window_key};
    delete $self->{'window_order'}{$window_key};

    delete $self->{'sub_maps'}{$window_key};

    return scalar( keys %{ $self->{'window_layout'} || {} } );
}

# ----------------------------------------------------
sub replace_temp_map_ids {

=pod

=head2 replace_temp_map_ids

Replace the temp map ids with the ones found in the database (or more specifically, the ones in the data structure that is passed).

=cut

    my $self = shift;
    my $temp_id_to_real_map_id = shift || {};

    foreach my $temp_id ( keys %$temp_id_to_real_map_id ) {
        my $real_map_id = $temp_id_to_real_map_id->{$temp_id};

        $self->{'map_id_to_keys'}{$real_map_id} = undef;
        foreach my $map_key ( @{ $self->map_id_to_keys($temp_id) || [] } ) {
            my $zone_key = $self->map_key_to_zone_key($map_key);

            $self->map_id_to_keys( $real_map_id, $map_key );
            $self->map_key_to_id( $map_key, $real_map_id );
            $self->map_id_to_key_by_zone( $real_map_id, $zone_key, $map_key );
        }
    }
}

# ----------------------------------------------------
sub refresh_program_from_database {

=pod

=head2 refresh_program_from_database

Refresh the views to reflect the database.

This will act on all open windows which are using the same instance.

The Action history will be cleared

Any view modifications on maps that were split/merged or children of the same
will be reset.

=cut

    my ( $self, %args ) = @_;

    # Clear AppData
    $self->app_data_module()->clear_stored_data();

    # Refresh each window
    foreach my $window_key ( keys %{ $self->{'window_layout'} || {} } ) {
        my $top_zone_key = $self->{'head_zone_key'}{$window_key};

        # Clear Action History
        $self->clear_actions( window_key => $window_key, );

        # Refresh the Children (this will recurse down the whole tree)
        $self->refresh_zone_children_from_database(
            parent_zone_key => $top_zone_key,
            window_key      => $window_key,
        );

        # Redraw the window
        $self->redraw_the_whole_window(
            window_key       => $window_key,
            reset_selections => 1,
        );
    }
}

# ----------------------------------------------------
sub refresh_zone_children_from_database {

=pod

=head2 refresh_zone_children_from_database

=cut

    my ( $self, %args ) = @_;
    my $parent_zone_key = $args{'parent_zone_key'} or return;
    my $window_key = $args{'window_key'};

    # Get New Sub Map List
    my %db_sub_maps_by_parent_key;
    my @db_sub_map_ids;
    my %parent_map_id_to_key;
    foreach my $parent_map_key ( @{ $self->map_order($parent_zone_key) } ) {
        my $parent_map_id = $self->map_key_to_id($parent_map_key);
        $parent_map_id_to_key{$parent_map_id} = $parent_map_key;

        next unless ( $self->{'map_layout'}{$parent_map_key}{'expanded'} );

        push @{ $db_sub_maps_by_parent_key{$parent_map_key} },
            @{ $self->app_data_module()->sub_maps( map_id => $parent_map_id, )
                || [] };

        push @db_sub_map_ids,
            map { $_->{'sub_map_id'} }
            @{ $db_sub_maps_by_parent_key{$parent_map_key} || [] };
    }

    # Get Old Sub Map List
    my @old_sub_map_ids;
    my %old_sub_map_id_to_map_key;
    foreach my $child_zone_key (
        @{ $self->{'scaffold'}{$parent_zone_key}{'children'} || [] } )
    {
        foreach
            my $sub_map_key ( @{ $self->map_order($child_zone_key) || [] } )
        {
            my $sub_map_id = $self->map_key_to_id($sub_map_key);
            push @old_sub_map_ids, $sub_map_id;
            $old_sub_map_id_to_map_key{$sub_map_id} = $sub_map_key;
            destroy_map_for_relayout(
                app_display_data => $self,
                map_key          => $sub_map_key,
                window_key       => $window_key,
                cascade          => 0,
            );
        }
    }

    # Work out which maps are still there, which are new and which have been
    # lost
    my %map_ids_new_in_db;
    my %map_ids_still_in_db;
    my %map_ids_lost_in_db;

    @db_sub_map_ids  = sort { $a <=> $b } @db_sub_map_ids;
    @old_sub_map_ids = sort { $a <=> $b } @old_sub_map_ids;

    my $db_index  = 0;
    my $old_index = 0;

    my ( $db_map_id, $old_map_id );
    while ( $db_index <= $#db_sub_map_ids
        and $old_index <= $#old_sub_map_ids )
    {
        $db_map_id  = $db_sub_map_ids[$db_index];
        $old_map_id = $old_sub_map_ids[$old_index];
        if ( $db_map_id == $old_map_id ) {
            $map_ids_still_in_db{$db_map_id} = 1;
            $db_index++;
            $old_index++;
        }
        elsif ( $db_map_id < $old_map_id ) {
            $map_ids_new_in_db{$db_map_id} = 1;
            $db_index++;
        }
        else {
            $map_ids_lost_in_db{$old_map_id} = 1;
            $old_index++;
        }
    }

    # Get any remaining in the db list
    for ( my $i = $db_index; $i <= $#db_sub_map_ids; $i++ ) {
        $map_ids_new_in_db{ $db_sub_map_ids[$i] } = 1;
    }

    # Get any remaining in the old list
    for ( my $i = $old_index; $i <= $#old_sub_map_ids; $i++ ) {
        $map_ids_lost_in_db{ $old_sub_map_ids[$i] } = 1;
    }

    # Handle the maps in the db
    my %new_sub_maps_by_parent_map_key;
    foreach my $parent_map_key ( keys %db_sub_maps_by_parent_key ) {
        foreach my $sub_map (
            @{ $db_sub_maps_by_parent_key{$parent_map_key} || [] } )
        {
            my $sub_map_id = $sub_map->{'sub_map_id'};

            # Prepare for adding the new maps
            if ( $map_ids_new_in_db{$sub_map_id} ) {
                push @{ $new_sub_maps_by_parent_map_key{$parent_map_key} },
                    $sub_map;
            }

            # Move the remaining maps
            elsif ( $map_ids_still_in_db{$sub_map_id} ) {
                $self->move_sub_map_on_parents_in_memory(
                    window_key     => $window_key,
                    sub_map_key    => $old_sub_map_id_to_map_key{$sub_map_id},
                    parent_map_key => $parent_map_key,
                    feature_start  => $sub_map->{'feature_start'},
                    feature_stop   => $sub_map->{'feature_stop'},
                );
            }
            else {
                print STDERR "Sub-map not classified: " . $sub_map_id . "\n";
            }
        }
    }

    # Add new Maps
    my $zone_expanded = $self->{'scaffold'}{$parent_zone_key}{'expanded'};
    foreach my $parent_map_key ( keys %new_sub_maps_by_parent_map_key ) {
        my $map_id_to_map_key = $self->assign_and_initialize_new_maps(
            window_key => $window_key,
            sub_maps   => $new_sub_maps_by_parent_map_key{$parent_map_key},
            parent_zone_key => $parent_zone_key,
            parent_map_key  => $parent_map_key,
        );
        if ($zone_expanded) {
            foreach my $sub_map (
                @{ $new_sub_maps_by_parent_map_key{$parent_map_key} || [] } )
            {
                my $sub_map_id   = $sub_map->{'sub_map_id'};
                my $sub_map_key  = $map_id_to_map_key->{$sub_map_id};
                my $sub_zone_key = $self->map_key_to_zone_key($sub_map_key);

                $self->add_sub_maps_to_map(
                    window_key      => $window_key,
                    parent_zone_key => $sub_zone_key,
                    parent_map_key  => $sub_map_key,
                );
            }
        }
    }

    # Remove the lost maps
    foreach my $map_id ( keys %map_ids_lost_in_db ) {
        my $map_key  = $old_sub_map_id_to_map_key{$map_id};
        my $zone_key = $self->map_key_to_zone_key($map_key);
        $self->delete_map(
            window_key => $window_key,
            map_key    => $map_key,
            zone_key   => $zone_key,
        );
    }

    # Refresh the children zones of each of these zones
    foreach my $child_zone_key (
        @{ $self->{'scaffold'}{$parent_zone_key}{'children'} || [] } )
    {
        $self->refresh_zone_children_from_database(
            parent_zone_key => $child_zone_key,
            window_key      => $window_key,
        );
    }

    return;
}

# ----------------------------------------------------
sub redraw_the_whole_window {

=pod

=head2 redraw_the_whole_window

Redraws the whole window

=cut

    my ( $self, %args ) = @_;
    my $window_key       = $args{'window_key'};
    my $skip_layout      = $args{'skip_layout'} || 0;
    my $reset_selections = $args{'reset_selections'} || 0;

    #$self->{'highlight_parent_maps'} = undef;

    # This probably should be more elegant but for now,
    # just layout the whole thing
    my $top_zone_key = $self->{'head_zone_key'}{$window_key};
    unless ($skip_layout) {
        layout_zone(
            window_key       => $window_key,
            zone_key         => $top_zone_key,    #$zone_key,
            app_display_data => $self,
            relayout         => 1,
            force_relayout   => 1,
        );
    }

    #RELAYOUT OVERVIEW
    $self->recreate_overview( window_key => $window_key, );

    $self->cascade_reset_zone_corrs(
        window_key => $window_key,
        zone_key   => $top_zone_key,
    );
    $self->app_interface()->draw_window(
        window_key       => $window_key,
        app_display_data => $self,
        reset_selections => $reset_selections,
    );
}

# ----------------------------------------------------
sub save_view_data_hash {

=pod

=head2 save_view_data_hash

Creates part of the hash that will be converted into XML that can be read in
later to create this view again.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};

    my $head_zone_key = $self->{'head_zone_key'}{$window_key};
    my $output_hash   = {
        head_zone => $self->create_zone_output_hash(
            window_key => $window_key,
            zone_key   => $head_zone_key,
        )
    };

    return $output_hash;
}

# ----------------------------------------------------
sub create_zone_output_hash {

=pod

=head2 create_zone_output_hash

Recursive method that creates a zone in the hash that will be converted into XML that can be read in
later to create this view again.

  # this contains the granular details.
  $zone_hash = {
    map_set_acc => $map_set_acc,
    map=>[
      {
        map_acc=> $map_acc,
        child_zone => [
          {
            recursive call;
          },
        ],
      },
    ],
  };

  # Contains map set info in case the individual maps are not listed above.
  # Will add Later
  $map_sets_hash = {
    $map_set_acc => {
      child_map_set_accs => [ $cmsa1, $cmsa2,],
    },
  };

=cut

    my ( $self, %args ) = @_;
    my $window_key    = $args{'window_key'};
    my $zone_key      = $args{'zone_key'};
    my $zone_scaffold = $self->{'scaffold'}{$zone_key};

    my %zone_hash = ();

    # Get map_set_acc for this zone
    my $map_set_data = $self->app_data_module()
        ->get_map_set_data( map_set_id => $zone_scaffold->{'map_set_id'}, );
    $zone_hash{'map_set_acc'} = $map_set_data->{'map_set_acc'};

    my @map;
    foreach my $map_key ( @{ $self->{'map_order'}{$zone_key} || [] } ) {

        my @child_zones;
        foreach my $child_zone_key (
            $self->get_children_zones_of_map(
                map_key  => $map_key,
                zone_key => $zone_key,
            )
            )
        {
            push @child_zones,
                $self->create_zone_output_hash(
                window_key => $window_key,
                zone_key   => $child_zone_key
                );
        }

        my $map_data = $self->app_data_module()
            ->map_data( map_id => $self->map_key_to_id($map_key), );
        my $map_acc = $map_data->{'map_acc'};

        push @map, { 'map_acc' => $map_acc, child_zone => \@child_zones, };
    }
    $zone_hash{'map'} = \@map;

    return \%zone_hash;
}

# ----------------------------------------------------
sub create_bin_key {

=pod

=head2 create_bin_key

Creates the key used to identify a map bin.

=cut

    my ( $self, %args ) = @_;
    my $zone_key  = $args{'zone_key'};
    my $bin_index = $args{'bin_index'};

    return 'bin_' . $zone_key . '_' . $bin_index;
}

# ----------------------------------------------------
sub get_children_zones_of_zone {

=pod

=head2 get_children_zones_of_zone

returns

=cut

    my ( $self, %args ) = @_;
    my $zone_key = $args{'zone_key'};

    return @{ $self->{'scaffold'}{$zone_key}{'children'} || [] };
}

# ----------------------------------------------------
sub get_children_zones_of_map {

=pod

=head2 get_children_zones_of_map

returns

=cut

    my ( $self, %args ) = @_;
    my $map_key  = $args{'map_key'};
    my $zone_key = $args{'zone_key'};

    return @{ $self->{'map_key_to_child_zones'}{$map_key} || [] };
}

# ----------------------------------------------------
sub get_position_on_map {

=pod

=head2 get_position_on_map

returns

=cut

    my ( $self, %args ) = @_;
    my $map_key  = $args{'map_key'};
    my $mouse_x  = $args{'mouse_x'};
    my $zone_key = $self->map_key_to_zone_key($map_key);

    my ( $zone_x_offset, $zone_y_offset )
        = $self->get_main_zone_offsets( zone_key => $zone_key, );

    my $x_offset = $self->{'scaffold'}{$zone_key}{'x_offset'};

    my $map_pixel_start = $self->{'map_layout'}{$map_key}{'coords'}[0];
    my $map_pixel_stop  = $self->{'map_layout'}{$map_key}{'coords'}[2];
    my $map_pixel_width = $map_pixel_stop - $map_pixel_start + 1;

    my $relative_pixel_position_from_map_start;
    if ($self->is_map_drawn_flipped(
            map_key  => $map_key,
            zone_key => $zone_key,
        )
        )
    {
        $relative_pixel_position_from_map_start
            = ( $map_pixel_stop + $zone_x_offset + $x_offset ) - $mouse_x;
    }
    else {
        $relative_pixel_position_from_map_start
            = $mouse_x - ( $map_pixel_start + $zone_x_offset + $x_offset );
    }

    my $map_data = $self->app_data_module()
        ->map_data( map_id => $self->map_key_to_id($map_key), );
    return $map_data->{'map_start'}
        if ( $relative_pixel_position_from_map_start < 0 );
    return $map_data->{'map_stop'}
        if ( $relative_pixel_position_from_map_start > $map_pixel_width );

    my $relative_unit_position
        = $relative_pixel_position_from_map_start /
        (      $self->{'map_pixels_per_unit'}{$map_key}
            || $self->{'scaffold'}{$zone_key}{'pixels_per_unit'} );

    # Modify the relative unit start to round to the unit granularity
    my $unit_granularity
        = $self->unit_granularity( $map_data->{'map_type_acc'} );

    $relative_unit_position
        = round_to_granularity( $relative_unit_position, $unit_granularity );

    return $relative_unit_position + $map_data->{'map_start'};
}

# ----------------------------------------------------
sub get_zone_bin_layouts {

=pod

=head2 get_zone_bin_layouts

returns

=cut

    my $self      = shift;
    my $zone_key  = shift;
    my $bin_index = shift;

    if ( defined $bin_index ) {
        return $self->{'zone_bin_layouts'}{$zone_key}[$bin_index];
    }
    elsif ($zone_key) {
        return $self->{'zone_bin_layouts'}{$zone_key};
    }

    return $self->{'zone_bin_layouts'};
}

# ----------------------------------------------------
sub get_map_set_id_from_map_id {

=pod

=head2 get_map_set_id_from_map_id

returns

=cut

    my $self = shift;
    my $map_id = shift or return undef;

    my $map_data = $self->app_data_module()->map_data( map_id => $map_id, );
    return undef unless ( %{ $map_data || {} } );

    return $map_data->{'map_set_id'};
}

# ----------------------------------------------------
sub get_map_ids {

=pod

=head2 get_map_ids

returns

=cut

    my ( $self, %args ) = @_;
    my $map_keys = $args{'map_keys'} || [];

    if (@$map_keys) {
        return [ map { $self->{'map_key_to_id'}{$_} } @$map_keys ];
    }

    return undef;
}

# ----------------------------------------------------
sub initialize_zone {

=pod

=head2 initialize_zone

Initializes zone

    my $zone_key = $self->initialize_zone(
        window_key         => $window_key,
        zone_key           => $zone_key,
        parent_zone_key    => $parent_zone_key,
        parent_map_key     => $parent_map_key,
        attached_to_parent => $attached_to_parent,
        expanded           => $expanded,
        is_top             => $is_top,
        show_features      => $show_features,
        copy_zone_key      => $zone_key_to_copy,
        border_line_width  => $border_line_width,
    );

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return undef;
    my $zone_key = $args{'zone_key'} || $self->next_internal_key('zone');
    my $map_set_id = $args{'map_set_id'};
    my $parent_zone_key    = $args{'parent_zone_key'};      # Can be undef
    my $parent_map_key     = $args{'parent_map_key'};       # Can be undef
    my $attached_to_parent = $args{'attached_to_parent'};
    my $expanded           = $args{'expanded'};
    my $is_top             = $args{'is_top'};
    my $flipped            = $args{'flipped'};
    my $show_features      = $args{'show_features'};
    my $map_labels_visible = $args{'map_labels_visible'};
    my $offscreen_corrs_visible = $args{'offscreen_corrs_visible'};
    my $copy_zone_key           = $args{'copy_zone_key'};
    my $border_line_width       = $args{'border_line_width'} || 1;

    unless ( defined $flipped ) {
        $flipped = 0;
        if ($parent_map_key) {
            $flipped = $self->{'map_layout'}{$parent_map_key}{'flipped'};
        }
    }

    if ($copy_zone_key) {
        my $copy_scaffold = $self->{'scaffold'}{$copy_zone_key};
        $attached_to_parent = $copy_scaffold->{'attached_to_parent'}
            unless ( defined $attached_to_parent );
        $expanded = $copy_scaffold->{'expanded'} unless ( defined $expanded );
        $is_top   = $copy_scaffold->{'is_top'}   unless ( defined $is_top );
        $flipped  = $copy_scaffold->{'flipped'}  unless ( defined $flipped );
        $show_features = $copy_scaffold->{'show_features'}
            unless ( defined $show_features );
        $map_labels_visible = $copy_scaffold->{'map_labels_visible'}
            unless ( defined $map_labels_visible );
        $offscreen_corrs_visible = $copy_scaffold->{'offscreen_corrs_visible'}
            unless ( defined $offscreen_corrs_visible );
    }

    $attached_to_parent ||= 0;
    $expanded           ||= 0;
    $is_top             ||= 0;
    $show_features      ||= 0;
    $map_labels_visible
        = defined($map_labels_visible) ? $map_labels_visible : 1;
    $offscreen_corrs_visible ||= 0;
    $self->{'scaffold'}{$zone_key} = {
        window_key         => $window_key,
        map_set_id         => $map_set_id,
        parent_zone_key    => $parent_zone_key,
        parent_map_key     => $parent_map_key,
        children           => [],
        scale              => 1,
        x_offset           => 0,
        attached_to_parent => $attached_to_parent,
        expanded           => $expanded,
        is_top             => $is_top,
        pixels_per_unit    => 0,
        show_features      => $show_features,
    };
    push @{ $self->{'map_key_to_child_zones'}{$parent_map_key} }, $zone_key
        if ($parent_map_key);
    $self->initialize_zone_layout( $zone_key, $window_key, );
    $self->{'zone_layout'}{$zone_key}{'flipped'} = $flipped;
    $self->{'zone_layout'}{$zone_key}{'border_line_width'}
        = $border_line_width;

    $self->map_set_id_to_zone_keys( $map_set_id, $zone_key, );
    $self->map_labels_visible( $zone_key, $map_labels_visible, );
    $self->offscreen_corrs_visible( $zone_key, $offscreen_corrs_visible, );
    $self->features_visible( $zone_key, $show_features, );

    if ($copy_zone_key) {
        $self->copy_zone_corrs(
            window_key   => $window_key,
            ori_zone_key => $copy_zone_key,
            new_zone_key => $zone_key,
        );

    }
    if ($parent_zone_key) {
        push @{ $self->{'scaffold'}{$parent_zone_key}{'children'} },
            $zone_key;
    }

    return $zone_key;
}

# ----------------------------------------------------
sub initialize_map {

=pod

=head2 initialize_map

Initializes map

=cut

    my ( $self, %args ) = @_;
    my $map_id       = $args{'map_id'};
    my $zone_key     = $args{'zone_key'};
    my $map_key      = $args{'map_key'} || $self->next_internal_key('map');
    my $draw_flipped = $args{'draw_flipped'};
    my $feature_direction = $args{'feature_direction'} || 1;

    unless ( defined $draw_flipped ) {

        # Default the direction to 1 (-1 is for reverse)
        $feature_direction ||= 1;
        my $zone_flipped = $self->{'zone_layout'}{$zone_key}{'flipped'};
        $draw_flipped = 0;
        if ( $feature_direction < 0 ) {
            $draw_flipped = 1;
        }
    }

    push @{ $self->{'map_order'}{$zone_key} }, $map_key;
    $self->map_id_to_keys( $map_id, $map_key );
    $self->map_id_to_key_by_zone( $map_id, $zone_key, $map_key );
    $self->map_key_to_id( $map_key, $map_id );
    $self->map_key_to_zone_key( $map_key, $zone_key );
    $self->initialize_map_layout($map_key);
    $self->{'map_layout'}{$map_key}{'flipped'} = $draw_flipped;

    return $map_key;
}

# ----------------------------------------------------
sub uninitialize_map {

=pod

=head2 uninitialize_map

Removes a map

=cut

    my ( $self, %args ) = @_;
    my $zone_key = $args{'zone_key'};
    my $map_key  = $args{'map_key'} || $self->next_internal_key('map');
    my $map_id   = $self->map_key_to_id($map_key);

    # Detach new maps from the zone
    $self->remove_from_map_order(
        map_key  => $map_key,
        zone_key => $zone_key,
    );

    # Remove any drawn correspondences
    my $window_key = $self->{'scaffold'}{$zone_key}{'window_key'};
    $self->remove_corrs_to_map(
        window_key => $window_key,
        map_key    => $map_key,
    );

    foreach (
        my $i = 0;
        $i <= $#{ $self->{'map_id_to_keys'}{$map_id} || [] };
        $i++
        )
    {
        if ( $map_key == $self->{'map_id_to_keys'}{$map_id}[$i] ) {
            splice( @{ $self->{'map_id_to_keys'}{$map_id} }, $i, 1 );
            $i--;
        }
    }
    delete $self->{'map_id_to_key_by_zone'}{$zone_key}{$map_id};
    delete $self->{'map_key_to_id'}{$map_key};
    delete $self->{'map_key_to_zone_key'}{$map_key};
    delete $self->{'map_layout'}{$map_key};

    return $map_key;
}

# --------------------------------

=pod

=head1 Accessor Methods 

returns

=cut

# ----------------------------------------------------
sub map_key_to_id {

=pod

=head2 map_key_to_id

Gets/sets map id 

=cut

    my $self    = shift;
    my $map_key = shift;
    my $map_id  = shift;

    if ($map_id) {
        $self->{'map_key_to_id'}{$map_key} = $map_id;
    }

    return $self->{'map_key_to_id'}{$map_key};
}

# ----------------------------------------------------
sub map_key_to_zone_key {

=pod

=head2 map_key_to_zone_key

Gets/sets zone_key 

=cut

    my $self     = shift;
    my $map_key  = shift;
    my $zone_key = shift;

    if ($zone_key) {
        $self->{'map_key_to_zone_key'}{$map_key} = $zone_key;
    }

    return $self->{'map_key_to_zone_key'}{$map_key};
}

# ----------------------------------------------------
sub map_id_to_keys {

=pod

=head2 map_id_to_keys

Gets/sets map keys 

=cut

    my $self    = shift;
    my $map_id  = shift;
    my $map_key = shift;

    if ($map_key) {
        my $found = 0;
        foreach my $key ( @{ $self->{'map_id_to_keys'}{$map_id} || [] } ) {
            if ( $key == $map_key ) {
                $found = 1;
                last;
            }
        }
        unless ($found) {
            push @{ $self->{'map_id_to_keys'}{$map_id} }, $map_key;
        }
    }

    return $self->{'map_id_to_keys'}{$map_id};
}

# ----------------------------------------------------
sub map_id_to_key_by_zone {

=pod

=head2 map_id_to_key_by_zone

Gets/sets map keys 

=cut

    my $self     = shift;
    my $map_id   = shift or return;
    my $zone_key = shift or return;
    my $map_key  = shift;

    if ($map_key) {
        $self->{'map_id_to_key_by_zone'}{$zone_key}{$map_id} = $map_key;
    }

    return $self->{'map_id_to_key_by_zone'}{$zone_key}{$map_id};
}

# ----------------------------------------------------
sub map_set_id_to_zone_keys {

=pod

=head2 map_set_id_to_zone_keys

Gets/sets the zones associated with a map set

=cut

    my $self       = shift;
    my $map_set_id = shift;
    my $zone_key   = shift;

    if ( $map_set_id and $zone_key ) {

        # Return if it is already entered
        foreach my $previously_entered_zone_key (
            @{ $self->{'map_set_id_to_zone_keys'}{$map_set_id} || [] } )
        {
            if ( $previously_entered_zone_key == $zone_key ) {
                return $self->{'map_set_id_to_zone_keys'}{$map_set_id};
            }
        }

        # If it made it through the gauntlet, add it to the list
        push @{ $self->{'map_set_id_to_zone_keys'}{$map_set_id} }, $zone_key;
        return $self->{'map_set_id_to_zone_keys'}{$map_set_id};
    }
    elsif ($map_set_id) {
        return $self->{'map_set_id_to_zone_keys'}{$map_set_id};
    }

    return $self->{'map_set_id_to_zone_keys'};
}

# ----------------------------------------------------
sub map_order {

=pod

=head2 map_order

Gets/sets map_order

=cut

    my $self     = shift;
    my $zone_key = shift;
    my $map_key  = shift;

    if ($map_key) {
        my $found = 0;
        foreach my $key ( @{ $self->{'map_order'}{$zone_key} || [] } ) {
            if ( $key == $map_key ) {
                $found = 1;
                last;
            }
        }
        unless ($found) {
            push @{ $self->{'map_order'}{$zone_key} }, $map_key;
        }
    }

    return $self->{'map_order'}{$zone_key};
}

=pod

=head1 layed_out_zones methods

These methods are to let the layout methods know if a zone has been layed out
durint this call or if it is off screen to the right or left.

=cut

=pod

=head2 refresh_zone_visibility_hash

Refreshes the layout hash for the begining of a layout.  No zones have been
layed out yet.

=cut

# ----------------------------------------------------
sub refresh_zone_visibility_hash {
    my $self     = shift;
    my $zone_key = shift;

    delete $self->{'zone_visibility_hash'}{$zone_key};
    foreach my $child_zone_key (
        $self->get_children_zones_of_zone( zone_key => $zone_key, ) )
    {
        $self->refresh_zone_visibility_hash($child_zone_key);
    }
    return;
}

=pod

=head2 add_zone_to_zone_visibility_hash

Adds a zone to the layout hash.

=cut

# ----------------------------------------------------
sub add_zone_to_zone_visibility_hash {
    my $self     = shift;
    my $zone_key = shift or return;
    my $state    = shift || ON_SCREEN;
    $self->{'zone_visibility_hash'}{$zone_key}{$state} = 1;
    return;
}

=pod

=head2 add_child_zones_to_visibility_hash

Recursively adds children zone to the layout hash.

=cut

# ----------------------------------------------------
sub add_child_zones_to_visibility_hash {
    my $self     = shift;
    my %args     = @_;
    my $zone_key = $args{'zone_key'} or return;
    my $map_key  = $args{'map_key'};
    my $state    = $args{'state'} || ON_SCREEN;

    # Get the child zones differently if a map key is given
    my @children_zone_keys;
    if ($map_key) {
        @children_zone_keys = $self->get_children_zones_of_map(
            map_key  => $map_key,
            zone_key => $zone_key,
        );
    }
    else {
        @children_zone_keys
            = $self->get_children_zones_of_zone( zone_key => $zone_key, );
    }

    foreach my $child_zone_key (@children_zone_keys) {
        $self->add_zone_to_zone_visibility_hash( $child_zone_key, $state, );
        $self->add_child_zones_to_visibility_hash(
            zone_key => $child_zone_key, );
    }

    return;
}

=pod

=head2 _is_zone_layed_out

Tests a zone to see if it's been layed out.

=cut

# ----------------------------------------------------
sub is_zone_layed_out {
    my $self           = shift;
    my $zone_key       = shift or return;
    my $visibility_key = ON_SCREEN;
    return $self->{'zone_visibility_hash'}{$zone_key}{$visibility_key};
}

=pod

=head2 _is_zone_off_screen_left

Tests a zone to see if off the screen to the left

=cut

# ----------------------------------------------------
sub is_zone_off_screen_left {
    my $self           = shift;
    my $zone_key       = shift or return;
    my $visibility_key = OFF_TO_THE_LEFT;
    return $self->{'zone_visibility_hash'}{$zone_key}{$visibility_key};
}

=pod

=head2 _is_zone_off_screen_right

Tests a zone to see if off the screen to the left

=cut

# ----------------------------------------------------
sub is_zone_off_screen_right {
    my $self           = shift;
    my $zone_key       = shift or return;
    my $visibility_key = OFF_TO_THE_RIGHT;
    return $self->{'zone_visibility_hash'}{$zone_key}{$visibility_key};
}

=pod

=head2 is_highlighted

Checks to see if an object is highlighted

=cut

# ----------------------------------------------------
sub is_highlighted {

    my ( $self, %args ) = @_;
    my $window_key   = $args{'window_key'} or return;
    my $map_name     = $args{'map_name'};
    my $feature_name = $args{'feature_name'};

    if ( my $name = $map_name || $feature_name ) {
        return $self->{'highlighted_by_name'}{$window_key}{$name};
    }
}

=pod

=head2 _zone_visibility_hash

Simply returns the layout hash.

=cut

# ----------------------------------------------------
sub zone_visibility_hash {
    my $self = shift;
    return $self->{'zone_visibility_hash'};
}

1;

# ----------------------------------------------------
# It is not all books that are as dull as their readers.
# Henry David Thoreau
# ----------------------------------------------------

=pod

=head1 INTERNAL DATA STRUCTURES

=head2 Other Module Handles

=head3 Data Module Handle

    $self->{'app_data_module'};  # data module

=head3 Interface Module Handle

    $self->{'app_interface'};

=head2 Parameters

=head3 Correspondences On

Revisit 

Set when correspondences are on on between two slots.  Both directions are
stored.

    $self->{'correspondences_on'} = { 
        $slot_key1 => { 
            $slot_key2 => 1,
        } 
    }

=head3 Pixels Per Unit for each map

Revisit 

This is a conversion factor to get from map units to pixels.

    $self->{'map_pixels_per_unit'} = {
        $map_key => $pixels_per_unit,
    }

=head2 Map ID and Key Translators

Revisit 

    $self->{'map_id_to_keys'} = { 
        $map_id => [ $map_key, ],
    }

    $self->{'map_id_to_key_by_slot'} = {
        $slot_key => {
            $map_id => $map_key,
        }
    }

    $self->{'map_key_to_id'} = {
        $map_key => $map_id,
    }

    $self->{'map_key_to_slot_key'} = {
        $map_key => $slot_key,
    }
    

=head2 Order

=head3 Map Order in Slot

Revisit 

    $self->{'map_order'} = {
        $slot_key => [ $map_key, ]
    }

=head3 Panel Order in Window

Revisit 

    $self->{'panel_order'} = {
        $window_key => [ $panel_key, ]
    }

=head2 Scaffold Stuff

=head3 Overview Slot Info

Revisit 

    $self->{'overview'} = {
        $panel_key => {
            slot_key   => $slot_key,     # top slot in overview
            window_key => $window_key,
        }
    }

=head3 Main Scaffold

    $self->{'scaffold'} = {
        $slot_key => {
            window_key         => $window_key,
            map_set_id         => undef,
            parent_zone_key    => $parent_zone_key,
            parent_map_key     => $parent_map_key,
            children           => [$child_zone_key, ],
            scale              => 1,
            x_offset           => 0,
            attached_to_parent => 0,
            expanded           => 1,
            is_top             => 1,
            pixels_per_unit    => 0,
            show_features      => 1,
        }
    }

=head2 Stored Bio Data

=head3 Zone Info

Zone info is needed for correspondence finding.  It stores the visible region
of each map in the zone and this gets passed to the slot_correspondences()
method in AppData.

    $self->{'zone_info'} = {
        $zone_key => {
            map_id => [ 
                current_start, 
                current_stop, 
                ori_start, 
                ori_stop,
                magnification, 
            ]
        } 
    }

=head3 Sub Maps Info

This stores the location of a sub map on the parent.

    self->{'sub_maps'} = {
        $map_key => {
            parent_key    => $parent_map_key,
            feature_start => $feature_start,
            feature_stop  => $feature_stop,
            feature_id  => $feature_id,
            feature_length  => $feature_length,
        }
    }

=head2 Layout Objects

The layout objects hold the drawing information as well as other info relevant
to drawing.

=head3 Window Layout

Revisit

    $self->{'window_layout'} = {
        $window_key => {
            title       => $title,
            bounds      => [ 0, 0, 0, 0 ],
            misc_items  => [],
            buttons     => [],
            changed     => 1,
            sub_changed => 1,
            width       => 0,
        }
    }

=head3 Panel Layout

Revisit

    $self->{'panel_layout'} = {
        $panel_key => {
            bounds      => [ 0, 0, 0, 0 ],
            misc_items  => [],
            buttons     => [],
            changed     => 1,
            sub_changed => 1,
        }
    }

=head3 Zone Layout

    $self->{'zone_layout'} = {
        $zone_key => {
            bounds         => [],
            separator      => [],
            background     => [],
            buttons        => [],
            layed_out_once => 0,
            changed        => 0,
            sub_changed    => 0,
            flipped        => 0,
            border_line_width => 1,
        }
    }

=head3 Map Layout

Revisit

    $self->{'map_layout'} = {
        $map_key => {
            bounds      => [ 0, 0, 0, 0 ],
            coords      => [ 0, 0, 0, 0 ],
            buttons     => [],
            items       => [],
            changed     => 1,
            sub_changed => 1,
            flipped     => 0,
            row_index   => undef,
            features    => {
                $feature_acc => {
                    changed => 1,
                    items   => [],
                }
            },
        }
    }

=head3 Overview Layout

Revisit

    $self->{'overview_layout'} = {
        $window_key => {
            bounds           => [ 0, 0, 0, 0 ],
            misc_items       => [],
            buttons          => [],
            changed          => 1,
            sub_changed      => 1,
            zones            => {
                $zone_key => {
                    bounds                 => [ 0, 0, 0, 0 ],
                    misc_items             => [],
                    buttons                => [],
                    viewed_region          => [],
                    changed                => 1,
                    sub_changed            => 1,
                    scale_factor_from_main => 0,
                    maps                   => {
                        $map_key => {
                            items   => [],
                            changed => 1,
                        }
                    }
                }
            }
        }
    }

=head3 Correspondence Layout

Revisit

    $self->{'corr_layout'} = {
        changed = 1,
        maps => {
            $map_key => { 
                changed   => 1,
                items     => [],
                slot_key1 => $slot_key1,
                slot_key2 => $slot_key2,
                map_key1  => $map_key1,
                map_key2  => $map_key2,
            }
        }
    }

=head2 Keeping Track of actions

=head3 window_actions

    $self->{'window_actions'} = {
        $window_key => {
            last_action_index => -1,
            actions => [[ @action_specific_data ],],
        }
    }

=head4 move_map

    my %action_data = (
        action             => 'move_map',
        map_key            => $map_key,
        map_id             => $self->map_key_to_id($map_key),
        feature_id         => $self->{'sub_maps'}{$map_key}{'feature_id'},
        old_parent_map_key => $self->{'sub_maps'}{$map_key}{'parent_map_key'},
        old_parent_map_id  => $self->map_key_to_id(
            $self->{'sub_maps'}{$map_key}{'parent_map_key'}
        ),
        old_feature_start  => $self->{'sub_maps'}{$map_key}{'feature_start'},
        old_feature_stop   => $self->{'sub_maps'}{$map_key}{'feature_stop'},
        new_parent_map_key => $new_parent_map_key,
        new_parent_map_id  => $self->map_key_to_id($new_parent_map_key),
        new_feature_start  => $new_feature_start,
        new_feature_stop   => $new_feature_stop,
    );

=head4 split_map

    my %action_data = (
        action                  => 'split_map',
        ori_map_key             => $ori_map_key,
        ori_map_id              => $self->map_key_to_id($ori_map_key),
        first_map_key           => $first_map_key,
        first_map_id            => $self->map_key_to_id($first_map_key),
        first_map_name          => $first_map_name,
        first_map_start         => $first_map_start,
        first_map_stop          => $first_map_stop,
        first_feature_start     => $first_feature_start,
        first_feature_stop      => $first_feature_stop,
        second_map_key          => $second_map_key,
        second_map_id           => $self->map_key_to_id($second_map_key),
        second_map_name         => $second_map_name,
        second_map_start        => $second_map_start,
        second_map_stop         => $second_map_stop,
        second_feature_start    => $second_feature_start,
        second_feature_stop     => $second_feature_stop,
        split_position          => $split_position,
        first_map_feature_accs  => [ keys %feature_accs_for_first_map ],
        second_map_feature_accs => [ keys %feature_accs_for_second_map ],
    );

=head4 merge_maps

    my %action_data = (
        action                  => 'merge_maps',
        first_map_key           => $first_map_key,
        first_map_id            => $self->map_key_to_id($first_map_key),
        second_map_key          => $second_map_key,
        second_map_id           => $self->map_key_to_id($second_map_key),
        merged_map_key          => $merged_map_key,
        merged_map_id           => $self->map_key_to_id($merged_map_key),
        merged_map_name         => $merged_map_name,
        merged_map_start        => $merged_map_start,
        merged_map_stop         => $merged_map_stop,
        merged_feature_start    => $merged_feature_start,
        merged_feature_stop     => $merged_feature_stop,
        overlap_amount          => $overlap_amount,
        second_map_offset       => $second_map_offset,
        first_map_feature_accs  => \@first_map_feature_accs,
        second_map_feature_accs => \@second_map_feature_accs,
        first_sub_map_keys      => \@first_sub_map_keys,
        second_sub_map_keys     => \@second_sub_map_keys,
    );

=head2 Other Values

=head3 selected_zone_key

    $self->{'selected_zone_key'} = $zone_key;

=head3 next_map_set_color_index

Revisit

The next index for the background color array.

    $self->{'next_map_set_color_index'} = 0;

=head1 SEE ALSO

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2006-7 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

