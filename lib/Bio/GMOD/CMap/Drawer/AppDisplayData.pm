package Bio::GMOD::CMap::Drawer::AppDisplayData;

# vim: set ft=perl:

# $Id: AppDisplayData.pm,v 1.57 2007-08-08 15:43:34 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.57 $)[-1];

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
        attached_to_parent => 0,
        expanded           => 1,
        is_top             => 1,
        show_features      => 1,
        map_labels_visible => 1,
    );

    $self->{'head_zone_key'}{$window_key} = $zone_key;
    $self->{'overview'}{$window_key}{'zone_key'} = $zone_key;

    $self->set_default_window_layout( window_key => $window_key, );

    foreach my $map_id ( @{ $map_ids || [] } ) {
        my $map_key = $self->initialize_map(
            map_id   => $map_id,
            zone_key => $zone_key,
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
        window_key         => $window_key,
        map_set_id         => $map_data->{'map_set_id'},
        attached_to_parent => 0,
        expanded           => 0,
        is_top             => 1,
        show_features      => 1,
        map_labels_visible => 1,
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
            parent_map_key => $parent_map_key,
            feature_start  => $sub_map->{'feature_start'},
            feature_stop   => $sub_map->{'feature_stop'},
            feature_id     => $sub_map->{'feature_id'},
            feature_length => (
                $sub_map->{'feature_stop'} - $sub_map->{'feature_start'}
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
        parent_zone_key    => $parent_zone_key,
        parent_map_key     => $parent_map_key,
        attached_to_parent => 1,
        expanded           => 0,
        is_top             => 0,
        show_features      => 0,
        map_labels_visible => 0,
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

    foreach my $map ( @{ $map_data || [] } ) {
        my $map_id  = $map->{'map_id'};
        my $map_key = $self->initialize_map(
            map_id   => $map_id,
            zone_key => $zone_key,
        );

        # set the sub_maps data
        if ( $sub_maps_hash->{$map_id} ) {
            $self->{'sub_maps'}{$map_key} = $sub_maps_hash->{$map_id};
        }

        foreach my $zone_view_map ( @{ $zone_view_data->{'map'} || [] } ) {
            next unless ( $map->{'map_acc'} eq $zone_view_map->{'map_acc'} );
            if ( ref( $zone_view_map->{'child_zone'} ) eq 'HASH' ) {
                $zone_view_map->{'child_zone'}
                    = [ $zone_view_map->{'child_zone'} ];
            }
            foreach
                my $child_zone ( @{ $zone_view_map->{'child_zone'} || [] } )
            {
                $child_zone->{'parent_zone_key'} = $zone_key;
                $child_zone->{'parent_map_key'}  = $map_key;
                $child_zone->{'parent_map_id'}   = $map_id;
                push @{$zone_view_data_queue}, $child_zone;
            }
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
                window_key         => $window_key,
                map_set_id         => $map_set_id,
                parent_zone_key    => $parent_zone_key,
                parent_map_key     => $parent_map_key,
                attached_to_parent => 1,
                expanded           => 0,
                is_top             => 0,
                show_features      => 0,
                map_labels_visible => 0,
            );
        }

        foreach my $sub_map_id ( @{ $map_ids_by_set{$set_key} || [] } ) {
            my $sub_map_key = $self->initialize_map(
                map_id   => $sub_map_id,
                zone_key => $child_zone_key,
            );
            $map_id_to_map_key{$sub_map_id} = $sub_map_key;

            my $sub_map = $sub_map_hash{$sub_map_id};
            $self->{'sub_maps'}{$sub_map_key} = {
                parent_map_key => $parent_map_key,
                feature_start  => $sub_map->{'feature_start'},
                feature_stop   => $sub_map->{'feature_stop'},
                feature_id     => $sub_map->{'feature_id'},
                feature_length => (
                    $sub_map->{'feature_stop'} - $sub_map->{'feature_start'}
                        + $parent_unit_granularity
                ),
            };

        }
    }
    return \%map_id_to_map_key;
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
    my $x_offset    = $self->{'scaffold'}{$zone_key}{'x_offset'};
    my $zone_layout = $self->{'zone_layout'}{$zone_key};

    if ( $zone_layout->{'internal_bounds'}[0] + $scroll_value
        > $zone_layout->{'viewable_internal_x1'} )
    {
        $scroll_value = -1 * $x_offset;
    }
    if ( $zone_layout->{'internal_bounds'}[2] + $scroll_value
        < $zone_layout->{'viewable_internal_x2'} )
    {
        $scroll_value = $zone_layout->{'viewable_internal_x2'}
            - $zone_layout->{'internal_bounds'}[2];
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
    $self->app_interface()->draw_window(
        window_key       => $window_key,
        app_display_data => $self,
    );
    $self->cascade_reset_zone_corrs(
        window_key => $window_key,
        zone_key   => $zone_key,
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
    my $zoom_value = $args{'zoom_value'} or return;

    $zone_key = $self->get_top_attached_parent( zone_key => $zone_key );

    my $zone_scaffold = $self->{'scaffold'}{$zone_key};

    # Don't let it zoom out farther than is useful.
    if ( $zone_scaffold->{'scale'} == 1 and $zoom_value < 1 ) {
        return;
    }

    my $zone_bounds = $self->{'zone_layout'}{$zone_key}{'bounds'};
    my $zone_width  = $zone_bounds->[2] - $zone_bounds->[0] + 1;

    my $old_scale = $zone_scaffold->{'scale'};
    $zone_scaffold->{'scale'}           *= $zoom_value;
    $zone_scaffold->{'pixels_per_unit'} *= $zoom_value;
    my $move_offset_x = $self->get_zooming_offset(
        window_key => $window_key,
        zone_key   => $zone_key,
        zoom_value => $zoom_value,
        old_scale  => $old_scale,
    );

    # Create new zone bounds for this zone, taking into
    $zone_bounds->[2] += ( $zone_width * $zoom_value ) - $zone_width;

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
    $self->app_interface()->draw_window(
        window_key       => $window_key,
        app_display_data => $self,
    );

    $self->cascade_reset_zone_corrs(
        window_key => $window_key,
        zone_key   => $zone_key,
    );
    return;
}

# ----------------------------------------------------
sub overview_scroll_slot {

=pod

=head2 overview_scroll_slot

Scroll slots based on the overview scrolling

=cut

    #print STDERR "ADD_NEEDS_MODDED 2\n";

    my ( $self, %args ) = @_;
    my $window_key   = $args{'window_key'};
    my $panel_key    = $args{'panel_key'};
    my $slot_key     = $args{'slot_key'};
    my $scroll_value = $args{'scroll_value'} or return;

    # Don't let the overview break attachment to parent
    if ( $self->{'scaffold'}{$slot_key}{'attached_to_parent'} ) {
        $slot_key = $self->{'scaffold'}{$slot_key}{'parent_zone_key'};
    }

    my $main_scroll_value = int( $scroll_value /
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
                $self->clear_zone_corrs(
                    window_key => $window_key,
                    zone_key1  => $zone_key1,
                    zone_key2  => $zone_key2,
                );
            }
        }
    }

    return;
}

# ----------------------------------------------------
sub toggle_corrs_zone {

=pod

=head2 toggle_corrs_zone

toggle the correspondences for a zone

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $zone_key1  = $args{'zone_key'};

    my $zone_key2 = $self->{'scaffold'}{$zone_key1}{'parent_zone_key'};
    return unless ($zone_key2);

    if ( $self->{'correspondences_on'}{$zone_key1}{$zone_key2} ) {
        $self->clear_zone_corrs(
            window_key => $window_key,
            zone_key1  => $zone_key1,
            zone_key2  => $zone_key2,
        );
    }
    else {
        $self->add_zone_corrs(
            window_key => $window_key,
            zone_key1  => $zone_key1,
            zone_key2  => $zone_key2,
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
    my $window_key = $args{'window_key'};
    my $zone_key1  = $args{'zone_key1'};
    my $zone_key2  = $args{'zone_key2'};

    ( $zone_key1, $zone_key2 ) = ( $zone_key2, $zone_key1 )
        if ( $zone_key1 > $zone_key2 );

    my $allow_intramap = 0;
    if ( $zone_key1 == $zone_key2 ) {
        $allow_intramap = 1;
    }
    my $slot_info1 = $self->{'slot_info'}{$zone_key1};
    my @slot_comparisons;
    foreach my $map_key1 ( @{ $self->map_order($zone_key1) } ) {
        my $map_id1       = $self->map_key_to_id($map_key1);
        my $map_pedigree1 = $self->map_pedigree($map_key1);
        my $info_start    =
            defined $slot_info1->{$map_id1}[0]
            ? $slot_info1->{$map_id1}[0]
            : $slot_info1->{$map_id1}[2];
        my $info_stop =
            defined $slot_info1->{$map_id1}[1]
            ? $slot_info1->{$map_id1}[1]
            : $slot_info1->{$map_id1}[3];
        if ($map_pedigree1) {
            foreach my $fragment (@$map_pedigree1) {
                my $fragment_start  = $fragment->[0];
                my $fragment_stop   = $fragment->[1];
                my $ancestor_map_id = $fragment->[2];
                my $ancestor_start  = $fragment->[3];
                my $ancestor_stop   = $fragment->[4];

                next
                    if ( $fragment_stop < $info_start
                    or $fragment_start > $info_stop );
                if ( $info_stop < $fragment_stop ) {
                    $ancestor_start -= ( $fragment_stop - $info_stop );
                }
                if ( $info_start > $fragment_start ) {
                    $ancestor_start += ( $info_start - $fragment_start );
                }
                my $map_info1 = [
                    $ancestor_start, $ancestor_stop, $ancestor_start,
                    $ancestor_stop,  1,
                ];
                my $fragment_offset1 = $fragment_start - $ancestor_start;
                push @slot_comparisons,
                    $self->_get_slot_comparisons_for_corrs_helper1(
                    map_id1          => $map_id1,
                    ancestor_map_id1 => $ancestor_map_id,
                    map_info1        => $map_info1,
                    fragment_offset1 => $fragment_offset1,
                    zone_key1        => $zone_key1,
                    zone_key2        => $zone_key2,
                    allow_intramap   => $allow_intramap,
                    );
            }
        }
        else {
            my $map_info1 = $slot_info1->{$map_id1};
            push @slot_comparisons,
                $self->_get_slot_comparisons_for_corrs_helper1(
                map_id1          => $map_id1,
                map_info1        => $map_info1,
                fragment_offset1 => 0,
                zone_key1        => $zone_key1,
                zone_key2        => $zone_key2,
                allow_intramap   => $allow_intramap,
                );
        }
    }

    return \@slot_comparisons;
}

# ----------------------------------------------------
sub _get_slot_comparisons_for_corrs_helper1 {

=pod

=head2 get_slot_comparisons_for_corrs_helper1

Get a list of all the information needed for correspondences, taking into
account the posibility of split/merged maps.

=cut

    my ( $self, %args ) = @_;
    my $window_key       = $args{'window_key'};
    my $zone_key1        = $args{'zone_key1'};
    my $zone_key2        = $args{'zone_key2'};
    my $map_id1          = $args{'map_id1'};
    my $ancestor_map_id1 = $args{'ancestor_map_id1'} || $map_id1;
    my $map_info1        = $args{'map_info1'};
    my $fragment_offset1 = $args{'fragment_offset1'};
    my $allow_intramap   = $args{'allow_intramap'};

    my $slot_info2 = $self->{'slot_info'}{$zone_key2};
    my @slot_comparisons;
    foreach my $map_key2 ( @{ $self->map_order($zone_key2) } ) {
        my $map_id2       = $self->map_key_to_id($map_key2);
        my $map_pedigree2 = $self->map_pedigree($map_key2);
        my $info_start    =
            defined $slot_info2->{$map_id2}[0]
            ? $slot_info2->{$map_id2}[0]
            : $slot_info2->{$map_id2}[2];
        my $info_stop =
            defined $slot_info2->{$map_id2}[1]
            ? $slot_info2->{$map_id2}[1]
            : $slot_info2->{$map_id2}[3];
        if ($map_pedigree2) {
            foreach my $fragment (@$map_pedigree2) {
                my $fragment_start   = $fragment->[0];
                my $fragment_stop    = $fragment->[1];
                my $ancestor_map_id2 = $fragment->[2];
                my $ancestor_start   = $fragment->[3];
                my $ancestor_stop    = $fragment->[4];
                next
                    if ( $fragment_stop < $info_start
                    or $fragment_start > $info_stop );
                if ( $info_stop < $fragment_stop ) {
                    $ancestor_start -= ( $fragment_stop - $info_stop );
                }
                if ( $info_start > $fragment_start ) {
                    $ancestor_start += ( $info_start - $fragment_start );
                }
                my $map_info2 = [
                    $ancestor_start, $ancestor_stop, $ancestor_start,
                    $ancestor_stop,  1,
                ];
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
            my $map_info2 = $slot_info2->{$map_id2};
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
    $self->redraw_the_whole_window( window_key => $window_key, );

    return;
}

# ----------------------------------------------------
sub reattach_slot {

    #print STDERR "ADD_NEEDS_MODDED 6\n";

=pod

=head2 reattach_slot

Reattach a map and recursively handle the children

=cut

    my ( $self, %args ) = @_;
    my $window_key                  = $args{'window_key'};
    my $panel_key                   = $args{'panel_key'};
    my $slot_key                    = $args{'slot_key'};
    my $cascading                   = $args{'cascading'} || 0;
    my $unattached_child_zoom_value = $args{'unattached_child_zoom_value'}
        || 0;
    my $scroll_value = $args{'scroll_value'} || 0;

    my $slot_scaffold = $self->{'scaffold'}{$slot_key};
    my $overview_slot_layout
        = $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key};

    if ($cascading) {
        if ( $slot_scaffold->{'attached_to_parent'} ) {
            if ($overview_slot_layout) {
                $overview_slot_layout->{'scale_factor_from_main'}
                    /= $unattached_child_zoom_value;
            }

            # Get Offset from parent
            $slot_scaffold->{'x_offset'}
                = $self->{'scaffold'}{ $slot_scaffold->{'parent_zone_key'} }
                {'x_offset'};

            $self->relayout_sub_map_slot(
                window_key => $window_key,
                panel_key  => $panel_key,
                slot_key   => $slot_key,
            );
        }
        else {
            if ($unattached_child_zoom_value) {
                $slot_scaffold->{'scale'} /= $unattached_child_zoom_value;
            }
            if ($slot_scaffold->{'scale'} == 1
                and ( $slot_scaffold->{'x_offset'} - $scroll_value
                    == $self->{'scaffold'}
                    { $slot_scaffold->{'parent_zone_key'} }{'x_offset'} )
                )
            {
                $self->attach_slot_to_parent(
                    slot_key  => $slot_key,
                    panel_key => $panel_key,
                );
                $self->relayout_sub_map_slot(
                    window_key => $window_key,
                    panel_key  => $panel_key,
                    slot_key   => $slot_key,
                );
            }
            else {

                # Reset correspondences
                # BF ADD THIS BACK
                #$self->reset_slot_corrs(
                #    window_key => $window_key,
                #    panel_key  => $panel_key,
                #    slot_key   => $slot_key,
                #);
            }
        }
    }
    elsif ( $slot_scaffold->{'is_top'} ) {
        return;
    }
    else {

        # Get Zoom level from parent
        $unattached_child_zoom_value = 1 / $slot_scaffold->{'scale'};
        $slot_scaffold->{'scale'} = 1;

        # Get Offset from parent
        $slot_scaffold->{'x_offset'}
            = $self->{'scaffold'}{ $slot_scaffold->{'parent_zone_key'} }
            {'x_offset'};

        $overview_slot_layout->{'scale_factor_from_main'}
            /= $unattached_child_zoom_value
            if ($overview_slot_layout);

        $self->attach_slot_to_parent(
            slot_key  => $slot_key,
            panel_key => $panel_key,
        );

        $self->relayout_sub_map_slot(
            window_key => $window_key,
            panel_key  => $panel_key,
            slot_key   => $slot_key,
        );
    }

    # handle overview highlighting
    if ( $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key} ) {
        $self->destroy_items(
            items =>
                $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key}
                {'viewed_region'},
            panel_key   => $panel_key,
            is_overview => 1,
        );
        $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key}
            {'viewed_region'} = [];
        overview_selected_area(
            slot_key         => $slot_key,
            panel_key        => $panel_key,
            app_display_data => $self,
        );
    }

    foreach my $child_slot_key ( @{ $slot_scaffold->{'children'} || [] } ) {
        $self->reattach_slot(
            window_key                  => $window_key,
            panel_key                   => $panel_key,
            slot_key                    => $child_slot_key,
            unattached_child_zoom_value => $unattached_child_zoom_value,
            cascading                   => 1,
        );
    }

    unless ($cascading) {
        $self->{'panel_layout'}{$panel_key}{'sub_changed'} = 1;
        $self->app_interface()->draw_window(
            window_key       => $window_key,
            app_display_data => $self,
        );
    }
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

    #layout_overview(
    #    window_key       => $window_key,
    #    app_display_data => $self,
    #    width            => $width - 400,
    #);
    $self->app_interface()->draw_window(
        window_key       => $window_key,
        app_display_data => $self,
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

    my $zone_bounds = $self->{'zone_layout'}{$zone_key}{'bounds'};

    my $old_width      = $zone_bounds->[2] - $zone_bounds->[0] + 1;
    my $viewable_width = $old_width / $old_scale;

    my $new_width = $old_width * $zoom_value;

    #my $change = ( $new_width - $old_width ) / 2;
    my $viewable_section_change
        = ( ( $viewable_width * $zoom_value ) - $viewable_width ) / 2;

    my $old_offset = $self->{'scaffold'}{$zone_key}{'x_offset'};
    my $new_offset = ( $old_offset * $zoom_value ) - $viewable_section_change;

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

    my $map_data = $self->app_data_module()
        ->map_data( map_id => $self->map_key_to_id($map_key), );
    my $text = $map_data->{'map_name'};
    my ( $width, $height, ) = $self->app_interface()->text_dimensions(
        window_key => $window_key,
        text       => $text,
    );

    return {
        text   => $text,
        width  => $width,
        height => $height,
    };
}

# ----------------------------------------------------
sub relayout_ref_map_zone {

    #print STDERR "ADD_NEEDS_MODDED 9\n";

=pod

=head2 relayout_ref_map_zone

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $zone_key   = $args{'zone_key'}   or return;

    $self->clear_zone_maps(
        window_key => $window_key,
        zone_key   => $zone_key,
    );

    # These maps are features of the parent map
    layout_head_maps(
        window_key       => $window_key,
        zone_key         => $zone_key,
        app_display_data => $self,
    );

    return;
}

# ----------------------------------------------------
sub relayout_sub_map_zone {

    #print STDERR "ADD_NEEDS_MODDED 10\n";

=pod

=head2 relayout_sub_map_zone

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $zone_key   = $args{'zone_key'}   or return;

    $self->clear_zone_maps(
        window_key => $window_key,
        zone_key   => $zone_key,
    );

    # These maps are features of the parent map
    layout_sub_maps(
        window_key       => $window_key,
        zone_key         => $zone_key,
        app_display_data => $self,
    );

    # Reset correspondences
    # BF ADD THIS BACK
    #    $self->reset_zone_corrs(
    #        window_key => $window_key,
    #        zone_key   => $zone_key,
    #    );

    return;
}

# ----------------------------------------------------
sub create_slot_coverage_array {

    #print STDERR "ADD_NEEDS_MODDED 11\n";

=pod

=head2 create_slot_coverage_array

=cut

    my ( $self, %args ) = @_;
    my $slot_key = $args{'slot_key'} or return;

    $self->{'slot_coverage'}{$slot_key} = [];
    my @slot_coverage = ();

    # Maps are ordered by start and then stop positions
    # Once that's done, maps that overlap the end of the
    #  previous map extend the coverage, otherwise its
    #  a new coverage zone

    # Keep the x_offset in mind
    my $x_offset = $self->{'scaffold'}{$slot_key}{'x_offset'};
MAP_KEY:
    foreach my $map_key (
        sort {
            $self->{'map_layout'}{$a}{'coords'}[0]
                <=> $self->{'map_layout'}{$b}{'coords'}[0]
                || $self->{'map_layout'}{$a}{'coords'}[2]
                <=> $self->{'map_layout'}{$b}{'coords'}[2]
        } @{ $self->{'map_order'}{$slot_key} || [] }
        )
    {
        my $coords = $self->{'map_layout'}{$map_key}{'coords'};
        $coords->[0] += $x_offset;
        $coords->[2] += $x_offset;
        unless (@slot_coverage) {
            push @slot_coverage, [ $coords->[0], $coords->[2] ];
            next MAP_KEY;
        }

        if (    $coords->[0] <= $slot_coverage[-1][1]
            and $coords->[2] > $slot_coverage[-1][1] )
        {
            $slot_coverage[-1][1] = $coords->[2];
        }
        else {
            push @slot_coverage, [ $coords->[0], $coords->[2] ];
        }
    }

    $self->{'slot_coverage'}{$slot_key} = \@slot_coverage;

    return;
}

# ----------------------------------------------------
sub change_selected_zone {

=pod

=head2 change_selected_zone

=cut

    my ( $self, %args ) = @_;
    my $zone_key   = $args{'zone_key'} or return;
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

    #return if ( $self->{'debug_thing'} );
    #$self->{'debug_thing'} = 1;
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
sub change_feature_status {

    #print STDERR "ADD_NEEDS_MODDED 13\n";

=pod

=head2 change_feature_status

=cut

    my ( $self, %args ) = @_;
    my $slot_key      = $args{'slot_key'} or return;
    my $show_features = $args{'show_features'};
    my $panel_key     = $self->{'scaffold'}{$slot_key}{'panel_key'};
    my $window_key    = $self->{'scaffold'}{$slot_key}{'window_key'};

    my $slot_scaffold = $self->{'scaffold'}{$slot_key};
    $slot_scaffold->{'show_features'} = $show_features;

    if ( $slot_scaffold->{'is_top'} ) {
        $self->relayout_ref_map_slot(
            window_key => $window_key,
            panel_key  => $panel_key,
            slot_key   => $slot_key,
        );
    }
    else {
        $self->relayout_sub_map_slot(
            window_key => $window_key,
            panel_key  => $panel_key,
            slot_key   => $slot_key,
        );
    }

    $self->{'panel_layout'}{$panel_key}{'sub_changed'} = 1;
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

    #print STDERR "ADD_NEEDS_MODDED 15\n";

=pod

=head2 detach_zone_from_parent

=cut

    # No longer allowing zones to detach
    return;

    my ( $self, %args ) = @_;
    my $zone_key = $args{'zone_key'} or return;

    $self->{'scaffold'}{$zone_key}{'attached_to_parent'} = 0;
    $self->{'zone_layout'}{$zone_key}{'changed'}         = 1;

    add_zone_separator( zone_layout => $self->{'zone_layout'}{$zone_key}, );

    return;
}

# ----------------------------------------------------
sub attach_slot_to_parent {

    #print STDERR "ADD_NEEDS_MODDED 16\n";

=pod

=head2 attach_slot_to_parent

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
sub move_lower_slots {

    #print STDERR "ADD_NEEDS_MODDED 19\n";

=pod

=head2 move_lower_slots

Crawls through the panel and move all of the slots below the given slot.

=cut

    my ( $self, %args ) = @_;
    my $stationary_slot_key = $args{'stationary_slot_key'} or return;
    my $panel_key           = $args{'panel_key'}           or return;
    my $height_change = $args{'height_change'} || 0;

    my $seen_stationary_slot = 0;
    foreach my $slot_key ( @{ $self->{'slot_order'}{$panel_key} || [] } ) {

        # Don't move it if there isn't a map set id (and it hasn't been drawn
        if (    $seen_stationary_slot
            and $self->{'scaffold'}{$slot_key}{'map_set_id'} )
        {
            move_slot(
                panel_key        => $panel_key,
                slot_key         => $slot_key,
                y                => $height_change,
                app_display_data => $self,
                app_interface    => $self->app_interface(),
            );
        }
        elsif ( $stationary_slot_key == $slot_key ) {
            $seen_stationary_slot = 1;
        }
    }

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
        bounds         => [],
        separator      => [],
        background     => [],
        buttons        => [],
        layed_out_once => 0,
        changed        => 0,
        sub_changed    => 0,
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

    #BF DEBUG
    #return;
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
sub copy_slot_scaffold {

    #print STDERR "ADD_NEEDS_MODDED 26\n";

=pod

=head2 copy_slot_scaffold

Copies important info to a new slot.

=cut

    my ( $self, %args ) = @_;
    my $old_slot_key = $args{'old_slot_key'};
    my $new_slot_key = $args{'new_slot_key'};

    # Scaffold Info
    foreach my $key (
        qw[
        parent      scale       attached_to_parent
        x_offset    is_top      pixels_per_unit
        map_set_id  window_key
        children    show_features
        ]
        )
    {
        $self->{'scaffold'}{$new_slot_key}{$key}
            = $self->{'scaffold'}{$old_slot_key}{$key};
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
    my $title      = $args{'title'} || 'CMap';

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
sub clear_zone_maps {

    #print STDERR "ADD_NEEDS_MODDED 28\n";

=pod

=head2 clear_zone_maps

Clears a zone of map data and calls on the interface to remove the drawings.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $zone_key   = $args{'zone_key'}   or return;

    delete $self->{'slot_info'}{$zone_key};
    foreach my $map_key ( @{ $self->{'map_order'}{$zone_key} || [] } ) {
        foreach my $feature_acc (
            keys %{ $self->{'map_layout'}{$map_key}{'features'} || {} } )
        {
            $self->destroy_items(
                items =>
                    $self->{'map_layout'}{$map_key}{'features'}{$feature_acc}
                    {'items'},
                window_key => $window_key,
            );
        }
        $self->destroy_items(
            items      => $self->{'map_layout'}{$map_key}{'items'},
            window_key => $window_key,
        );
        $self->initialize_map_layout($map_key);
    }

    return;
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
            $self->clear_zone_corrs(
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
    my $slot_key1  = $args{'slot_key'}   or return;

    return unless ( $self->{'correspondences_hidden'} );

    foreach my $slot_key2 (
        @{ $self->{'correspondences_hidden'}{$slot_key1} || {} } )
    {
        delete $self->{'correspondences_hidden'}{$slot_key1};
        $self->add_slot_corrs(
            window_key => $window_key,
            slot_key1  => $slot_key1,
            slot_key2  => $slot_key2,
        );
        $self->{'correspondences_on'}{$slot_key1}{$slot_key2} = 1;
        $self->{'correspondences_on'}{$slot_key2}{$slot_key1} = 1;
    }

    foreach my $child_slot_key (
        @{ $self->{'scaffold'}{$slot_key1}{'children'} || [] } )
    {
        if ( $self->{'scaffold'}{$child_slot_key}{'attached_to_parent'} ) {
            $self->unhide_corrs(
                window_key => $window_key,
                slot_key   => $child_slot_key,
            );
        }
    }

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
            corrs_on     =>
                $self->{'zone_to_map_set_correspondences_on'}{$zone_key}
                {$map_set_id} || 0,
        };
        if ( $map_set_id == $self_map_set_id ) {
            $self_return_hash = $return_ref;
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
    my $map_key         = $args{'map_key'};
    my $ghost_bounds    = $args{'ghost_bounds'};
    my $zone_key        = $self->map_key_to_zone_key($map_key);
    my $window_key      = $self->{'scaffold'}{$zone_key}{'window_key'};
    my $parent_zone_key = $self->{'scaffold'}{$zone_key}{'parent_zone_key'};
    my $old_map_coords  = $self->{'map_layout'}{$map_key}{'coords'};

    # Get pixel location on parent map
    my %ghost_location_data = $self->place_ghost_location_on_parent_map(
        map_key          => $map_key,
        zone_key         => $zone_key,
        highlight_bounds => $ghost_bounds,
    );

    # Get parent offsets
    my ( $parent_main_x_offset, $parent_main_y_offset )
        = $self->get_main_zone_offsets( zone_key => $parent_zone_key, );
    my $parent_x_offset = $self->{'scaffold'}{$parent_zone_key}{'x_offset'};

    my $new_parent_map_key = $ghost_location_data{'parent_map_key'};
    $parent_zone_key = $ghost_location_data{'parent_zone_key'};
    my $new_location_coords = $ghost_location_data{'location_coords'};

    $new_location_coords->[0] -= ( $parent_main_x_offset + $parent_x_offset );
    $new_location_coords->[2] -= ( $parent_main_x_offset + $parent_x_offset );

    my $parent_map_coords
        = $self->{'map_layout'}{$new_parent_map_key}{'coords'};

    # Use start location as basis for locating
    my $relative_pixel_start
        = $new_location_coords->[0] - $parent_map_coords->[0];

    my $relative_unit_start = $relative_pixel_start /
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

    my $new_feature_start
        = $relative_unit_start + $parent_map_data->{'map_start'};
    my $new_feature_stop = $new_feature_start
        + $self->{'sub_maps'}{$map_key}{'feature_length'};

# If the feature end is at the end of the map, simply make the feature end the map end
    if (    $new_location_coords->[0] == $parent_map_coords->[0]
        and $new_location_coords->[2] == $parent_map_coords->[2] )
    {
        $new_feature_start = $parent_map_data->{'map_start'};
        $new_feature_stop  = $parent_map_data->{'map_stop'};
    }
    elsif ( $new_location_coords->[0] == $parent_map_coords->[0] ) {
        $new_feature_start = $parent_map_data->{'map_start'};
        $new_feature_stop  = $new_feature_start
            + $self->{'sub_maps'}{$map_key}{'feature_length'};
    }
    elsif ( $new_location_coords->[2] == $parent_map_coords->[2] ) {
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
            action             => 'move_map',
            map_key            => $map_key,
            map_id             => $self->map_key_to_id($map_key),
            feature_id         => $self->{'sub_maps'}{$map_key}{'feature_id'},
            old_parent_map_key =>
                $self->{'sub_maps'}{$map_key}{'parent_map_key'},
            old_parent_map_id => $self->map_key_to_id(
                $self->{'sub_maps'}{$map_key}{'parent_map_key'}
            ),
            old_feature_start =>
                $self->{'sub_maps'}{$map_key}{'feature_start'},
            feature_stop => $self->{'sub_maps'}{$map_key}{'feature_stop'},
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
        = $self->map_type_data( $ori_map_data->{'map_type_acc'},
        'unit_granularity' )
        || DEFAULT->{'unit_granularity'};

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
                    if ( $feature->{'sub_map_id'} ) {
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

    # Get the identifiers for the two new maps
    my $first_map_id  = $self->create_temp_id();
    my $first_map_key = $self->initialize_map(
        map_id   => $first_map_id,
        zone_key => $zone_key,
    );
    my $second_map_id  = $self->create_temp_id();
    my $second_map_key = $self->initialize_map(
        map_id   => $second_map_id,
        zone_key => $zone_key,
    );

    # Handle sub map information if it is a sub map
    my $first_feature_start;
    my $first_feature_stop;
    my $second_feature_start;
    my $second_feature_stop;
    if ( $self->{'sub_maps'}{$ori_map_key} ) {
        my $ori_feature_start
            = $self->{'sub_maps'}{$ori_map_key}{'feature_start'};
        my $ori_feature_stop
            = $self->{'sub_maps'}{$ori_map_key}{'feature_stop'};
        my $ori_feature_length = $ori_feature_stop - $ori_feature_start;
        my $first_feature_id   = $self->create_temp_id();
        my $second_feature_id  = $self->create_temp_id();
        $first_feature_start = $ori_feature_start;
        $first_feature_stop = $ori_feature_start + (
            $ori_feature_length * ( $first_map_length / $ori_map_length ) );
        $second_feature_start = $ori_feature_stop - (
            $ori_feature_length * ( $second_map_length / $ori_map_length ) );
        $second_feature_stop = $ori_feature_stop;

        $self->{'sub_maps'}{$first_map_key} = {
            parent_map_key =>
                $self->{'sub_maps'}{$ori_map_key}{'parent_map_key'},
            feature_start  => $first_feature_start,
            feature_stop   => $first_feature_stop,
            feature_id     => $first_feature_id,
            feature_length => (
                $first_feature_stop - $ori_feature_start + $unit_granularity
            ),
        };
        $self->{'sub_maps'}{$second_map_key} = {
            parent_map_key =>
                $self->{'sub_maps'}{$ori_map_key}{'parent_map_key'},
            feature_start  => $second_feature_start,
            feature_stop   => $second_feature_stop,
            feature_id     => $second_feature_id,
            feature_length => (
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
    $self->redraw_the_whole_window( window_key => $window_key, );

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
    my $ori_map_key    = $args{'ori_map_key'};
    my $first_map_key  = $args{'first_map_key'};
    my $second_map_key = $args{'second_map_key'};

    my $zone_key   = $self->map_key_to_zone_key($first_map_key);
    my $window_key = $self->{'scaffold'}{$zone_key}{'window_key'};

    # Reattach original map to the zone
    push @{ $self->{'map_order'}{$zone_key} }, $ori_map_key;

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

    return;
}

# ----------------------------------------------------
sub merge_maps {

=pod

=head2 merge_maps

Merge two maps

Create one new map and hide the original maps

=cut

    my ( $self, %args ) = @_;
    my $first_map_key  = $args{'first_map_key'};
    my $second_map_key = $args{'second_map_key'};
    my $overlap_amount = $args{'overlap_amount'};
    my $undo_or_redo   = $args{'undo_or_redo'} || 0;
    my $zone_key       = $self->map_key_to_zone_key($first_map_key);
    my $window_key     = $self->{'scaffold'}{$zone_key}{'window_key'};

    my $first_map_id  = $self->map_key_to_id($first_map_key);
    my $second_map_id = $self->map_key_to_id($second_map_key);
    my $first_map_data
        = $self->app_data_module()->map_data( map_id => $first_map_id );
    my $first_map_start = $first_map_data->{'map_start'};
    my $first_map_stop  = $first_map_data->{'map_stop'};
    my $second_map_data
        = $self->app_data_module()->map_data( map_id => $second_map_id );
    my $second_map_start = $second_map_data->{'map_start'};
    my $second_map_stop  = $second_map_data->{'map_stop'};

    my $second_map_offset = $first_map_data->{'map_stop'} - $overlap_amount;
    if ( $second_map_offset < $first_map_data->{'map_start'} ) {
        $self->app_interface()
            ->popup_warning( window_key => 'Overlap is too big.', );
        return;
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
    my $unit_granularity
        = $self->map_type_data( $first_map_data->{'map_type_acc'},
        'unit_granularity' )
        || DEFAULT->{'unit_granularity'};
    my $merged_map_start = $first_map_data->{'map_start'};
    my $merged_map_stop = $second_map_data->{'map_stop'} + $second_map_offset;
    my $merged_map_name = $first_map_data->{'map_name'} . "-"
        . $second_map_data->{'map_name'};
    if ( $merged_map_stop < $first_map_data->{'map_stop'} ) {
        $merged_map_stop = $first_map_data->{'map_stop'};
    }
    my $merged_map_id  = $self->create_temp_id();
    my $merged_map_key = $self->initialize_map(
        map_id   => $merged_map_id,
        zone_key => $zone_key,
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
        offset            => $second_map_offset,
    );

    # Handle sub map information if they are sub_maps
    my $merged_feature_start;
    my $merged_feature_stop;
    if ( $self->{'sub_maps'}{$first_map_key} ) {
        my $first_feature_start
            = $self->{'sub_maps'}{$first_map_key}{'feature_start'};
        my $first_feature_stop
            = $self->{'sub_maps'}{$first_map_key}{'feature_stop'};
        my $second_feature_start
            = $self->{'sub_maps'}{$second_map_key}{'feature_start'};
        my $second_feature_stop
            = $self->{'sub_maps'}{$second_map_key}{'feature_stop'};
        $merged_feature_start =
            ( $first_feature_start < $second_feature_start )
            ? $first_feature_start
            : $second_feature_start;
        $merged_feature_stop =
            ( $first_feature_stop > $second_feature_stop )
            ? $first_feature_stop
            : $second_feature_stop;

        my $merged_feature_id = $self->create_temp_id();

        $self->{'sub_maps'}{$merged_map_key} = {
            parent_map_key =>
                $self->{'sub_maps'}{$first_map_key}{'parent_map_key'},
            feature_start  => $merged_feature_start,
            feature_stop   => $merged_feature_stop,
            feature_id     => $merged_feature_id,
            feature_length => (
                $merged_feature_stop - $merged_feature_start
                    + $unit_granularity
            ),
        };

        # BF Potentially Merge the feature as well
    }

    # Move the sub maps over to the new merged map
    #First create lists of sub maps
    my @first_sub_map_keys;
    my @first_sub_map_ids;
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
            push @first_sub_map_ids,  $self->map_key_to_id($sub_map_key);
        }
    }
    my @second_sub_map_keys;
    my @second_sub_map_ids;
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
            push @second_sub_map_ids,  $self->map_key_to_id($sub_map_key);
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
        first_sub_map_ids       => \@first_sub_map_ids,
        second_sub_map_ids      => \@second_sub_map_ids,
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
    $self->redraw_the_whole_window( window_key => $window_key, );

    return ( [ $merged_map_key, ], $zone_key );

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
    my $merged_map_key      = $args{'merged_map_key'};
    my $first_map_key       = $args{'first_map_key'};
    my $second_map_key      = $args{'second_map_key'};
    my $second_map_offset   = $args{'second_map_offset'};
    my $first_sub_map_keys  = $args{'first_sub_map_keys'};
    my $second_sub_map_keys = $args{'second_sub_map_keys'};

    my $zone_key   = $self->map_key_to_zone_key($merged_map_key);
    my $window_key = $self->{'scaffold'}{$zone_key}{'window_key'};

    # Reattach original maps to the zone
    push @{ $self->{'map_order'}{$zone_key} }, $first_map_key;
    push @{ $self->{'map_order'}{$zone_key} }, $second_map_key;

    destroy_map_for_relayout(
        app_display_data => $self,
        map_key          => $merged_map_key,
        window_key       => $window_key,
        cascade          => 1,
    );

    foreach my $loop_array (
        [ $first_sub_map_keys,  $first_map_key,  0, ],
        [ $second_sub_map_keys, $second_map_key, $second_map_offset, ],
        )
    {

        # Move sub maps back to their original maps
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
                $ancestor_start, $ancestor_stop
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
                $ancestor_start, $ancestor_stop
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
sub get_map_keys_from_id_and_a_list_of_zones {

=pod

=head2 get_map_keys_from_id_and_a_list_of_zones

=cut

    my ( $self, %args ) = @_;
    my $map_id    = $args{'map_id'};
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
    elsif ( $last_action->{'action'} eq 'split_map' ) {
        $self->undo_split_map(
            ori_map_key    => $last_action->{'ori_map_key'},
            first_map_key  => $last_action->{'first_map_key'},
            second_map_key => $last_action->{'second_map_key'},
        );
    }
    elsif ( $last_action->{'action'} eq 'merge_maps' ) {

        $self->undo_merge_maps(
            first_map_key       => $last_action->{'first_map_key'},
            second_map_key      => $last_action->{'second_map_key'},
            merged_map_key      => $last_action->{'merged_map_key'},
            second_map_offset   => $last_action->{'second_map_offset'},
            first_sub_map_keys  => $last_action->{'first_sub_map_keys'},
            second_sub_map_keys => $last_action->{'second_sub_map_keys'},
        );
    }

    $self->{'window_actions'}{$window_key}{'last_action_index'}--;

    # Redraw
    $self->redraw_the_whole_window( window_key => $window_key, );

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
    unless ( @{ $next_action || [] } ) {
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

    # Redraw
    $self->redraw_the_whole_window( window_key => $window_key, );

    return;
}

# ----------------------------------------------------
sub condenced_window_actions {

=pod

=head2 condenced_window_actions

Condence redundant window actions for commits and exporting.  

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return undef;

    my %moves;
    my @return_array;
    my $window_actions = $self->{'window_actions'}{$window_key};
    for ( my $i = 0; $i <= $window_actions->{'last_action_index'}; $i++ ) {
        my $action = $window_actions->{'actions'}[$i];
        if ( $action->{'action'} eq 'move_map' ) {
            my $map_key = $action->{'map_key'};
            if ( $moves{$map_key} ) {

                # leave the original loc alone but change the end
                $moves{$map_key}->{'new_parent_map_key'}
                    = $action->{'new_parent_map_key'};
                $moves{$map_key}->{'new_parent_map_id'}
                    = $action->{'new_parent_map_id'};
                $moves{$map_key}->{'new_feature_start'}
                    = $action->{'new_feature_start'};
                $moves{$map_key}->{'new_feature_stop'}
                    = $action->{'new_feature_stop'};
            }
            else {
                $moves{$map_key} = $action;
            }
        }
    }

    # Add Moves to the return array
    foreach my $map_key ( keys %moves ) {
        push @return_array, $moves{$map_key};
    }

    return \@return_array;
}

# ----------------------------------------------------
sub remove_from_map_order {

=pod

=head2 remove_from_map_order

=cut

    my ( $self, %args ) = @_;
    my $map_key  = $args{'map_key'};
    my $zone_key = $args{'zone_key'};

    for (
        my $i = 0;
        $i <= $#{ $self->{'map_order'}{$zone_key} || [] };
        $i++
        )
    {
        if ( $map_key == $self->{'map_order'}{$zone_key}[$i] ) {
            splice @{ $self->{'map_order'}{$zone_key} }, $i, 1;
            $i--;
        }
    }

    return;
}

# ----------------------------------------------------
sub window_actions {

    #print STDERR "ADD_NEEDS_MODDED 76\n";

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
    my $x_offset = $bounds->[0];
    my $y_offset = $bounds->[1];

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
sub place_ghost_location_on_parent_map {

=pod

=head2 place_ghost_location_on_parent_map

Controls how the parent map is highlighted

=cut

    my ( $self, %args ) = @_;
    my $map_key          = $args{'map_key'};
    my $highlight_bounds = $args{'highlight_bounds'};
    my $mouse_dx         = $args{'mouse_dx'} || 0;
    my $mouse_dy         = $args{'mouse_dy'} || 0;
    my $initiate         = $args{'initiate'} || 0;
    my $zone_key         = $args{'$zone_key'}
        || $self->map_key_to_zone_key($map_key);
    my $parent_map_key = $initiate
        ? $self->{'scaffold'}{$zone_key}{'parent_map_key'}
        : $args{'parent_map_key'}
        || $self->{'current_ghost_parent_map_key'}
        || $self->{'scaffold'}{$zone_key}{'parent_map_key'};
    return unless ($parent_map_key);
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
        return;
    }

    # Center highlight on center of ghost map but using the corrds on the
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

    # Get the center x of the ghost bounds and translate into the parents
    # coords
    my $ghost_center_x = int(
        ( $highlight_bounds->[2] + $highlight_bounds->[0] ) / 2 + 0.5 );
    my $center_x
        = $ghost_center_x - ( $parent_main_x_offset + $parent_x_offset );

    # Work out x coords
    my $x1_on_parent
        = $center_x - int( $feature_pixel_length / 2 ) + $mouse_dx;
    my $x2_on_parent = $x1_on_parent + $feature_pixel_length;
    my $x1 = $ghost_center_x - int( $feature_pixel_length / 2 ) + $mouse_dx;
    my $x2 = $x1 + $feature_pixel_length;

    if (    $parent_map_layout->{'coords'}[0] > $x1_on_parent
        and $parent_map_layout->{'coords'}[2] < $x2_on_parent )
    {

        # Feature bigger than the map, shrink the feature to the map length.
        my $x1_offset = $parent_map_layout->{'coords'}[0] - $x1_on_parent;
        my $x2_offset = $parent_map_layout->{'coords'}[2] - $x2_on_parent;

        $x1_on_parent += $x1_offset;
        $x2_on_parent += $x2_offset;
        $x1           += $x1_offset;
        $x2           += $x2_offset;
    }
    elsif ( $parent_map_layout->{'coords'}[0] > $x1_on_parent ) {

        # Not on the map to the right, push to the left
        my $offset = $parent_map_layout->{'coords'}[0] - $x1_on_parent;
        $x1_on_parent += $offset;
        $x2_on_parent += $offset;
        $x1           += $offset;
        $x2           += $offset;
    }
    elsif ( $parent_map_layout->{'coords'}[2] < $x2_on_parent ) {

        # Not on the map to the left, push to the right
        my $offset = $x2_on_parent - $parent_map_layout->{'coords'}[2];
        $x1_on_parent -= $offset;
        $x2_on_parent -= $offset;
        $x1           -= $offset;
        $x2           -= $offset;
    }

    # Get y coords
    my $y1 = $parent_map_layout->{'coords'}[1];
    my $y2 = $parent_map_layout->{'coords'}[3];

    my $visible = 1;
    if (   $x2_on_parent < $parent_zone_layout->{'viewable_internal_x1'}
        or $x1_on_parent > $parent_zone_layout->{'viewable_internal_x2'} )
    {
        $visible = 0;
    }

    # save for later
    $self->{'current_ghost_parent_map_key'} = $parent_map_key;

    my %return_hash = (
        visible         => $visible,
        parent_zone_key => $parent_zone_key,
        window_key      => $window_key,
        parent_map_key  => $parent_map_key,
        location_coords => [ $x1, $y1, $x2, $y2 ]
    );

    return %return_hash;
}

# ----------------------------------------------------
sub move_ghosts {

=pod

=head2 move_ghosts

Controls how the ghost map moves.

=cut

    my ( $self, %args ) = @_;
    my $map_key         = $args{'map_key'};
    my $mouse_x         = $args{'mouse_x'};
    my $mouse_dx        = $args{'mouse_dx'};
    my $mouse_y         = $args{'mouse_y'};
    my $mouse_dy        = $args{'mouse_dy'};
    my $ghost_bounds    = $args{'ghost_bounds'};
    my $mouse_to_edge_x = $args{'mouse_to_edge_x'};

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
    my $ghost_parent_map_key = $self->find_ghost_parent_map(
        ghost_zone_key    => $zone_key,
        ghost_map_key     => $map_key,
        parent_map_set_id => $parent_map_set_id,
        parent_zone_key   => $parent_zone_key,
        mouse_x           => $mouse_x,
        mouse_y           => $mouse_y,
    );
    my $ghost_parent_zone_key
        = $self->map_key_to_zone_key($ghost_parent_map_key);

    my %ghost_location_data = $self->place_ghost_location_on_parent_map(
        map_key          => $map_key,
        zone_key         => $zone_key,
        mouse_dx         => $mouse_dx,
        mouse_dy         => $mouse_dy,
        highlight_bounds => $ghost_bounds,
        parent_zone_key  => $ghost_parent_zone_key,
    );

    my %return_hash = (
        ghost_dx                  => $mouse_dx,
        ghost_dy                  => $mouse_dy,
        ghost_loc_visible         => $ghost_location_data{'visible'},
        ghost_loc_parent_zone_key => $ghost_parent_zone_key,
        window_key                => $window_key,
        ghost_loc_location_coords => $ghost_location_data{'location_coords'},
    );

    return %return_hash;

}

# ----------------------------------------------------
sub get_ghost_location_coords {

=pod

=head2 get_ghost_location_coords

Controls how the ghost map moves.

=cut

    my ( $self, %args ) = @_;
    my $map_key      = $args{'map_key'};
    my $mouse_dx     = $args{'mouse_dx'} || 0;
    my $mouse_dy     = $args{'mouse_dy'} || 0;
    my $ghost_bounds = $args{'ghost_bounds'};

    my $zone_key = $args{'$zone_key'}
        || $self->map_key_to_zone_key($map_key);
    my $ghost_parent_zone_key = $args{'$ghost_parent_zone_key'}
        || $self->{'scaffold'}{$zone_key}{'parent_zone_key'};
    my $ghost_parent_map_key = $args{'ghost_parent_map_key'}
        || $self->{'current_ghost_parent_map_key'};

    my $ghost_parent_map_layout
        = $self->{'map_layout'}{$ghost_parent_map_key};
    my $ghost_parent_zone_layout
        = $self->{'zone_layout'}{$ghost_parent_zone_key};
    my $ghost_parent_x_offset
        = $self->{'scaffold'}{$ghost_parent_zone_key}{'x_offset'};
    my ( $ghost_parent_main_x_offset, $ghost_parent_main_y_offset )
        = $self->get_main_zone_offsets( zone_key => $ghost_parent_zone_key, );

    # Translate the ghost bounds into the parents coords
    my $ghost_loc_x1
        = $ghost_bounds->[0] + $mouse_dx - $ghost_parent_main_x_offset
        + $ghost_parent_x_offset;
    my $ghost_loc_x2
        = $ghost_bounds->[2] + $mouse_dx - $ghost_parent_main_x_offset
        + $ghost_parent_x_offset;
    my $ghost_loc_y1 = $ghost_parent_map_layout->{'coords'}[1];
    my $ghost_loc_y2 = $ghost_parent_map_layout->{'coords'}[3];

    if ( $ghost_loc_x1 < $ghost_parent_map_layout->{'coords'}[0] ) {
        my $diff = $ghost_parent_map_layout->{'coords'}[0] - $ghost_loc_x1;
        $ghost_loc_x1 += $diff;
        $ghost_loc_x2 += $diff;
    }
    elsif ( $ghost_loc_x2 > $ghost_parent_map_layout->{'coords'}[2] ) {
        my $diff = $ghost_loc_x2 - $ghost_parent_map_layout->{'coords'}[2];
        $ghost_loc_x1 -= $diff;
        $ghost_loc_x2 -= $diff;
    }
    my $visible = 1;
    if (   $ghost_loc_x2 < $ghost_parent_zone_layout->{'viewable_internal_x1'}
        or $ghost_loc_x1
        > $ghost_parent_zone_layout->{'viewable_internal_x2'} )
    {
        $visible = 0;
    }

    my %return_hash = (
        visible         => $visible,
        parent_zone_key => $ghost_parent_zone_key,
        parent_map_key  => $ghost_parent_map_key,
        location_coords =>
            [ $ghost_loc_x1, $ghost_loc_y1, $ghost_loc_x2, $ghost_loc_y2, ],
    );

    return %return_hash;

}

# ----------------------------------------------------
sub find_ghost_parent_map {

=pod

=head2 find_ghost_parent_map

Given a map_key and x and y coords, figure out if the mouse is in a new parent.

=cut

    my ( $self, %args ) = @_;
    my $ghost_zone_key    = $args{'ghost_zone_key'};
    my $ghost_map_key     = $args{'ghost_map_key'};
    my $parent_map_set_id = $args{'parent_map_set_id'};
    my $parent_zone_key   = $args{'parent_zone_key'};
    my $mouse_x           = $args{'mouse_x'};
    my $mouse_y           = $args{'mouse_y'};

    my $ghost_parent_maps = $self->get_ghost_parent_maps(
        parent_map_set_id => $parent_map_set_id,
        ghost_zone_key    => $ghost_zone_key,
    );

   # If not still in the current parent, check to see if it has entered any of
   # the other parents trigger space (their bounds).
    foreach my $ghost_parent_map ( @{ $ghost_parent_maps || [] } ) {
        if ($self->point_in_box(
                zone_key   => $parent_zone_key,
                x          => $mouse_x,
                y          => $mouse_y,
                box_coords => $ghost_parent_map->{'main_bounds'},
            )
            )
        {
            $self->{'current_ghost_parent_map_key'}
                = $ghost_parent_map->{'map_key'};
            return $self->{'current_ghost_parent_map_key'};
        }
    }

    return $self->{'current_ghost_parent_map_key'};
}

# ----------------------------------------------------
sub get_ghost_parent_maps {

=pod

=head2 ghost_parent_maps

Given a map_key and x and y coords, figure out if the mouse is in a new parent.

=cut

    my ( $self, %args ) = @_;

    unless ( $self->{'ghost_parent_maps'} ) {
        my $parent_map_set_id = $args{'parent_map_set_id'};
        my $ghost_zone_key    = $args{'ghost_zone_key'};
        my $window_key = $self->{'scaffold'}{$ghost_zone_key}{'window_key'};

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

                push @{ $self->{'ghost_parent_maps'} },
                    ( { map_key => $map_key, main_bounds => $main_bounds, } );
            }
        }
    }

    return $self->{'ghost_parent_maps'};
}

# ----------------------------------------------------
sub end_drag_ghost {

=pod

=head2 end_drag_ghost

Clear all of the values used during the ghost dragging so they don't muck up
the works next time.

=cut

    my ( $self, %args ) = @_;

    #$self->{'current_ghost_parent_map_key'} = undef;
    $self->{'ghost_parent_maps'} = undef;

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
    my $x_offset   = $self->{'scaffold'}{$zone_key}{'x_offset'} || 0;
    my $y_offset   = $self->{'scaffold'}{$zone_key}{'y_offset'} || 0;

    return (    $x >= $box_coords->[0] + $x_offset
            and $y >= $box_coords->[1] + $y_offset
            and $x <= $box_coords->[2] + $x_offset
            and $y <= $box_coords->[3] + $y_offset );
}

# ----------------------------------------------------
sub clear_zone_corrs {

=pod

=head2 clear_zone_corrs

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

    $self->destroy_items(
        items =>
            $self->{'corr_layout'}{'maps'}{$map_key1}{$map_key2}{'items'},
        window_key => $window_key,
    );
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

=head2 clear_zone_corrs

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
    $self->app_interface()->draw_corrs(
        window_key       => $window_key,
        app_display_data => $self,
    );

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
        next unless ( $self->{'correspondences_on'}{$zone_key1}{$zone_key2} );

        $self->clear_zone_corrs(
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
sub clear_window {

    #print STDERR "ADD_NEEDS_MODDED 45\n";

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

    # Remove Drawing info
    foreach my $drawing_item_name (qw[ separator background ]) {
        $self->destroy_items(
            window_key => $window_key,
            items      => $zone_layout->{$drawing_item_name},
        );
    }

    # Remove zone from window
    delete $self->{'zone_in_window'}{$window_key}{$zone_key};

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

    #print STDERR "ADD_NEEDS_MODDED 48\n";

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
                $self->destroy_items(
                    items =>
                        $self->{'corr_layout'}{'maps'}{$map_key}{'items'},
                    window_key => $window_key,
                );
                $self->{'corr_layout'}{'maps'}{$map_key}{'items'} = [];
            }
        }
        $self->{'zone_layout'}{$zone_key}{'bounds'}          = [ 0, 0, 0, 0 ];
        $self->{'zone_layout'}{$zone_key}{'internal_bounds'} = [ 0, 0, 0, 0 ];
        $self->{'zone_layout'}{$zone_key}{'maps_min_x'}   = undef;
        $self->{'zone_layout'}{$zone_key}{'maps_max_x'}   = undef;
        $self->{'scaffold'}{$zone_key}{'pixels_per_unit'} = undef;
        foreach my $field (qw[ separator background ]) {
            $self->destroy_items(
                items      => $self->{'zone_layout'}{$zone_key}{$field},
                window_key => $window_key,
            );
            $self->{'zone_layout'}{$zone_key}{$field} = [];
        }
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
        $self->redraw_the_whole_window( window_key => $window_key, );
    }
}

# ----------------------------------------------------
sub refresh_zone_children_from_database {

=pod

=head2 refresh_zone_children_from_database

=cut

    my ( $self, %args ) = @_;
    my $parent_zone_key = $args{'parent_zone_key'} or return;
    my $window_key      = $args{'window_key'};

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
        $map_ids_lost_in_db{$old_map_id} = 1;
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
    my $window_key = $args{'window_key'};

    # This probably should be more elegant but for now,
    # just layout the whole thing
    my $top_zone_key = $self->{'head_zone_key'}{$window_key};
    layout_zone(
        window_key       => $window_key,
        zone_key         => $top_zone_key,    #$zone_key,
        app_display_data => $self,
        relayout         => 1,
        force_relayout   => 1,
    );

    #RELAYOUT OVERVIEW
    $self->recreate_overview( window_key => $window_key, );

    $self->app_interface->reset_object_selections( window_key => $window_key,
    );
    $self->app_interface()->draw_window(
        window_key       => $window_key,
        app_display_data => $self,
    );
    $self->cascade_reset_zone_corrs(
        window_key => $window_key,
        zone_key   => $top_zone_key,
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
sub get_children_zones_of_map {

=pod

=head2 get_children_zones_of_map

returns

=cut

    my ( $self, %args ) = @_;
    my $map_key  = $args{'map_key'};
    my $zone_key = $args{'zone_key'};

    my @child_zone_keys;
    foreach my $child_zone_key (
        @{ $self->{'scaffold'}{$zone_key}{'children'} || [] } )
    {
        if ( $map_key
            == $self->{'scaffold'}{$child_zone_key}{'parent_map_key'} )
        {
            push @child_zone_keys, $child_zone_key;
        }
    }

    return @child_zone_keys;
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
    my $relative_pixel_position
        = $mouse_x - $self->{'map_layout'}{$map_key}{'coords'}[0]
        - $zone_x_offset;

    return undef if ( $relative_pixel_position < 0 );

    my $relative_unit_position = $relative_pixel_position /
        (      $self->{'map_pixels_per_unit'}{$map_key}
            || $self->{'scaffold'}{$zone_key}{'pixels_per_unit'} );
    my $map_data = $self->app_data_module()
        ->map_data( map_id => $self->map_key_to_id($map_key), );

    # Modify the relative unit start to round to the unit granularity
    my $unit_granularity = $self->map_type_data( $map_data->{'map_type_acc'},
        'unit_granularity' )
        || DEFAULT->{'unit_granularity'};
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

    my $self   = shift;
    my $map_id = shift or return undef;

    my $map_data = $self->app_data_module()->map_data( map_id => $map_id, );
    return undef unless ( %{ $map_data || {} } );

    return $map_data->{'map_set_id'};
}

# ----------------------------------------------------
sub get_map_ids {

    #print STDERR "ADD_NEEDS_MODDED 50\n";

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
sub map_truncated {

    #print STDERR "ADD_NEEDS_MODDED 51\n";

=pod

=head2 map_truncated

Test if the map is truncated (taken from Bio::GMOD::CMAP::Data ).

=cut

    my $self     = shift;
    my $slot_key = shift;
    my $map_id   = shift;
    return undef
        unless ( defined($slot_key) and defined($map_id) );

    if (    $self->{'slot_info'}->{$slot_key}
        and %{ $self->{'slot_info'}->{$slot_key} }
        and @{ $self->{'slot_info'}->{$slot_key}{$map_id} } )
    {
        my $map_info          = $self->{'slot_info'}->{$slot_key}{$map_id};
        my $map_top_truncated = ( defined( $map_info->[0] )
                and $map_info->[0] != $map_info->[2] );
        my $map_bottom_truncated = ( defined( $map_info->[1] )
                and $map_info->[1] != $map_info->[3] );
        if ( $map_top_truncated and $map_bottom_truncated ) {
            return 3;
        }
        elsif ($map_top_truncated) {
            return 1;
        }
        elsif ($map_bottom_truncated) {
            return 2;
        }
        return 0;
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
    );

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return undef;
    my $zone_key = $args{'zone_key'} || $self->next_internal_key('zone');
    my $map_set_id = $args{'map_set_id'};
    my $parent_zone_key    = $args{'parent_zone_key'};          # Can be undef
    my $parent_map_key     = $args{'parent_map_key'};           # Can be undef
    my $attached_to_parent = $args{'attached_to_parent'} || 0;
    my $expanded           = $args{'expanded'} || 0;
    my $is_top             = $args{'is_top'} || 0;
    my $show_features      = $args{'show_features'} || 0;
    my $map_labels_visible = $args{'map_labels_visible'} || 0;

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
    $self->initialize_zone_layout( $zone_key, $window_key, );

    $self->map_set_id_to_zone_keys( $map_set_id, $zone_key, );
    $self->map_labels_visible( $zone_key, $map_labels_visible, );

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
    my $map_id   = $args{'map_id'};
    my $zone_key = $args{'zone_key'};
    my $map_key  = $args{'map_key'} || $self->next_internal_key('map');

    push @{ $self->{'map_order'}{$zone_key} }, $map_key;
    $self->map_id_to_keys( $map_id, $map_key );
    $self->map_id_to_key_by_zone( $map_id, $zone_key, $map_key );
    $self->map_key_to_id( $map_key, $map_id );
    $self->map_key_to_zone_key( $map_key, $zone_key );
    $self->initialize_map_layout($map_key);

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
        }
    }

=head3 Map Layout

Revisit

    $self->{'map_layout'} = {
        $map_key => {
            bounds   => [ 0, 0, 0, 0 ],
            coords   => [ 0, 0, 0, 0 ],
            buttons  => [],
            items    => [],
            changed  => 1,
            sub_changed => 1,
            row_index => undef,
            features => {
                $feature_acc => {
                    changed => 1,
                    items => [],
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
        feature_stop       => $self->{'sub_maps'}{$map_key}{'feature_stop'},
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
        first_sub_map_ids       => \@first_sub_map_ids,
        second_sub_map_ids      => \@second_sub_map_ids,
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

Copyright (c) 2002-7 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

