package Bio::GMOD::CMap::Drawer::AppDisplayData;

# vim: set ft=perl:

# $Id: AppDisplayData.pm,v 1.40 2007-04-10 14:54:56 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.40 $)[-1];

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
    move_zone
    set_zone_bgcolor
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

    my $zone_key = $self->next_internal_key('zone');

    $self->{'head_zone_key'}{$window_key} = $zone_key;
    $self->{'overview'}{$window_key}{'zone_key'} = $zone_key;

    $self->{'scaffold'}{$zone_key} = {
        window_key         => $window_key,
        map_set_id         => undef,
        parent_zone_key    => undef,
        parent_map_key     => undef,
        children           => [],
        scale              => 1,
        x_offset           => 0,
        attached_to_parent => 0,
        expanded           => 1,
        is_top             => 1,
        pixels_per_unit    => 0,
        show_features      => 1,
    };

    my $map_data
        = $self->app_data_module()->map_data_array( map_ids => $map_ids, );

    $self->set_default_window_layout( window_key => $window_key, );

    $self->initialize_zone_layout( $zone_key, $window_key, );

    foreach my $map_id ( @{ $map_ids || [] } ) {
        my $map_key = $self->next_internal_key('map');
        push @{ $self->{'map_order'}{$zone_key} },    $map_key;
        push @{ $self->{'map_id_to_keys'}{$map_id} }, $map_key;
        $self->{'map_id_to_key_by_zone'}{$zone_key}{$map_id} = $map_key;
        $self->{'map_key_to_id'}{$map_key}                   = $map_id;
        $self->{'map_key_to_zone_key'}{$map_key}             = $zone_key;
        $self->initialize_map_layout($map_key);

        $self->add_sub_maps_to_map(
            window_key      => $window_key,
            parent_zone_key => $zone_key,
            parent_map_key  => $map_key,
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
    layout_overview(
        window_key       => $window_key,
        app_display_data => $self,
    );

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

    my $zone_key = $self->next_internal_key('zone');

    $self->{'head_zone_key'}{$window_key} = $zone_key;
    $self->{'overview'}{$window_key}{'zone_key'} = $zone_key;

    # Store the zone key in the view data
    $self->{'scaffold'}{$zone_key} = {
        window_key         => $window_key,
        map_set_id         => undef,
        parent_zone_key    => undef,
        parent_map_key     => undef,
        children           => [],
        scale              => 1,
        x_offset           => 0,
        attached_to_parent => 0,
        expanded           => 1,
        is_top             => 1,
        pixels_per_unit    => 0,
        show_features      => 1,
    };

    $self->initialize_zone_layout( $zone_key, $window_key, );

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

=head2 add_sub_maps_to_map

Adds sub-maps to the view.  Doesn't do any sanity checking.

=cut

    my ( $self, %args ) = @_;
    my $window_key           = $args{'window_key'}           or return;
    my $zone_view_data_queue = $args{'zone_view_data_queue'} or return;

    my $zone_view_data = shift @{$zone_view_data_queue};
    my @sub_map_keys;

    my $parent_map_id   = $zone_view_data->{'parent_map_id'};
    my $parent_map_key  = $zone_view_data->{'parent_map_key'};
    my $parent_zone_key = $zone_view_data->{'parent_zone_key'};

    # Collect Sub-Maps
    my $sub_maps
        = $self->app_data_module()->sub_maps( map_id => $parent_map_id, );

    my %sub_maps_hash;

    foreach my $sub_map ( @{ $sub_maps || [] } ) {
        my $sub_map_id = $sub_map->{'sub_map_id'};

        $sub_maps_hash{$sub_map_id} = {
            parent_map_key => $parent_map_key,
            feature_start  => $sub_map->{'feature_start'},
            feature_stop   => $sub_map->{'feature_stop'},
            feature_id     => $sub_map->{'feature_id'},
        };
    }

    unless ( $zone_view_data->{'map'} ) {

        # No Sub Maps
        return;
    }
    my $zone_key = $self->next_internal_key('zone');

    $self->initialize_zone_layout( $zone_key, $window_key, );
    $self->{'scaffold'}{$zone_key} = {
        window_key         => $window_key,
        parent_zone_key    => $parent_zone_key,
        parent_map_key     => $parent_map_key,
        map_set_id         => undef,
        children           => [],
        scale              => 1,
        x_offset           => 0,
        attached_to_parent => 1,
        expanded           => 0,
        is_top             => 0,
        pixels_per_unit    => 0,
        show_features      => 0,
    };
    push @{ $self->{'scaffold'}{$parent_zone_key}{'children'} }, $zone_key;

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

=head2 add_sub_maps_to_map

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
        my $map_key = $self->next_internal_key('map');
        push @{ $self->{'map_order'}{$zone_key} },    $map_key;
        push @{ $self->{'map_id_to_keys'}{$map_id} }, $map_key;
        $self->{'map_id_to_key_by_zone'}{$zone_key}{$map_id} = $map_key;
        $self->{'map_key_to_id'}{$map_key}                   = $map_id;
        $self->{'map_key_to_zone_key'}{$map_key}             = $zone_key;
        $self->initialize_map_layout($map_key);

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
    layout_overview(
        window_key       => $window_key,
        app_display_data => $self,
    );

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

    my @sub_map_keys;

    my $parent_map_id = $self->{'map_key_to_id'}{$parent_map_key};

    # Collect Sub-Maps
    my $sub_maps
        = $self->app_data_module()->sub_maps( map_id => $parent_map_id, );

    foreach my $sub_map ( @{ $sub_maps || [] } ) {
        my $sub_map_id  = $sub_map->{'sub_map_id'};
        my $sub_map_key = $self->next_internal_key('map');

        push @{ $self->{'map_id_to_keys'}{$sub_map_id} }, $sub_map_key;
        $self->{'map_key_to_id'}{$sub_map_key} = $sub_map_id;

        $self->{'sub_maps'}{$sub_map_key} = {
            parent_map_key => $parent_map_key,
            feature_start  => $sub_map->{'feature_start'},
            feature_stop   => $sub_map->{'feature_stop'},
            feature_id     => $sub_map->{'feature_id'},
        };
        push @sub_map_keys, $sub_map_key;

    }

    unless (@sub_map_keys) {

        # No Sub Maps
        return;
    }

    # Split maps into zones based on their map set
    my %maps_by_set;
    foreach my $sub_map_key (@sub_map_keys) {
        my $sub_map_id = $self->{'map_key_to_id'}{$sub_map_key};
        my $sub_map_data
            = $self->app_data_module()->map_data( map_id => $sub_map_id, );
        push @{ $maps_by_set{ $sub_map_data->{'map_set_id'} } }, $sub_map_key;
    }

    my @new_zone_keys;
    foreach my $set_key ( keys %maps_by_set ) {
        my $child_zone_key = $self->next_internal_key('zone');
        push @new_zone_keys, $child_zone_key;

        $self->initialize_zone_layout( $child_zone_key, $window_key, );
        $self->{'scaffold'}{$child_zone_key} = {
            window_key         => $window_key,
            parent_zone_key    => $parent_zone_key,
            parent_map_key     => $parent_map_key,
            map_set_id         => undef,
            children           => [],
            scale              => 1,
            x_offset           => 0,
            attached_to_parent => 1,
            expanded           => 0,
            is_top             => 0,
            pixels_per_unit    => 0,
            show_features      => 0,
        };
        push @{ $self->{'scaffold'}{$parent_zone_key}{'children'} },
            $child_zone_key;

        foreach my $map_key ( @{ $maps_by_set{$set_key} || [] } ) {
            push @{ $self->{'map_order'}{$child_zone_key} }, $map_key;
            $self->{'map_key_to_zone_key'}{$map_key} = $child_zone_key;
            $self->{'map_id_to_key_by_zone'}{$child_zone_key}
                { $self->{'map_key_to_id'}{$map_key} } = $map_key;
            $self->initialize_map_layout($map_key);
        }
    }
    return \@new_zone_keys;
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

    $zone_scaffold->{'scale'}           *= $zoom_value;
    $zone_scaffold->{'pixels_per_unit'} *= $zoom_value;
    my $move_offset_x = $self->get_zooming_offset(
        window_key => $window_key,
        zone_key   => $zone_key,
        zoom_value => $zoom_value,
    );

    # Create new zone bounds for this zone, taking into
    my $zone_bounds = $self->{'zone_layout'}{$zone_key}{'bounds'};
    my $zone_width  = $zone_bounds->[2] - $zone_bounds->[0] + 1;
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

    foreach my $map_key ( @{ $self->{'map_order'}{$zone_key} || [] } ) {

        # Add Sub Slots
        $self->add_sub_maps_to_map(
            window_key      => $window_key,
            parent_zone_key => $zone_key,
            parent_map_key  => $map_key,
        );
    }

# This probably should be more elegant but for now, just layout the whole thing
    my $top_zone_key = $self->{'head_zone_key'}{$window_key};
    layout_zone(
        window_key       => $window_key,
        zone_key         => $top_zone_key,    #$zone_key,
        app_display_data => $self,
        relayout         => 1,
        force_relayout   => 1,
    );

    # Maybe RELAYOUT OVERVIEW

    $self->app_interface()->draw_window(
        window_key       => $window_key,
        app_display_data => $self,
    );
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
    layout_overview(
        window_key       => $window_key,
        app_display_data => $self,
        width            => $width - 400,
    );
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

    my $old_width = $self->{'zone_layout'}{$zone_key}{'bounds'}[2]
        - $self->{'zone_layout'}{$zone_key}{'bounds'}[0] + 1;

    my $new_width = $old_width * $zoom_value;

    my $change = ( $new_width - $old_width ) / 2;

    my $old_offset = $self->{'scaffold'}{$zone_key}{'x_offset'};
    my $new_offset = ( $old_offset * $zoom_value );               # - $change;

    return $new_offset;
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

    #$app_interface->destroy_zone_controls(
    #window_key => $window_key,
    #zone_key  => $zone_key,
    #);
    #$app_interface->add_zone_controls(
    #window_key        => $window_key,
    #zone_key         => $zone_key,
    #window_key       => $window_key,
    #app_display_data => $self,
    #);

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
sub initialize_map_layout {

=pod

=head2 initialize_map_layout

Initializes map_layout

=cut

    my $self = shift;

    my $map_key = shift;

    $self->{'map_layout'}{$map_key} = {
        bounds      => [],
        coords      => [],
        buttons     => [],
        features    => {},
        items       => [],
        changed     => 1,
        sub_changed => 1,
        row_index   => undef,
        color       => 'black',
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

    my $top_zone_key = $self->{'overview'}{$window_key}{'zone_key'};

    # Destroy zone information and drawings
    foreach my $zone_key ( $top_zone_key,
        @{ $self->{'overview_layout'}{$window_key}{'child_zone_order'} } )
    {
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

    # Create an ordered list of the zones in the overview.
    my @child_zones;
    foreach my $child_zone_key (
        @{ $self->{'scaffold'}{$top_zone_key}{'children'} || [] } )
    {
        push @child_zones, $child_zone_key;
    }

    $self->{'overview_layout'}{$window_key}{'child_zone_order'}
        = \@child_zones;

    foreach my $zone_key ( $top_zone_key, @child_zones, ) {
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
sub get_move_map_data {

=pod

=head2 get_move_map_data

Move a map from one place on a parent to another

=cut

    my ( $self, %args ) = @_;
    my $map_key         = $args{'map_key'};
    my $ghost_bounds    = $args{'ghost_bounds'};
    my $zone_key        = $self->{'map_key_to_zone_key'}{$map_key};
    my $window_key      = $self->{'scaffold'}{$zone_key}{'window_key'};
    my $parent_zone_key = $self->{'scaffold'}{$zone_key}{'parent_zone_key'};
    my $old_map_coords  = $self->{'map_layout'}{$map_key}{'coords'};

    # Get pixel location on parent map
    my %ghost_location_data = $self->get_ghost_location_coords(
        map_key      => $map_key,
        zone_key     => $zone_key,
        ghost_bounds => $ghost_bounds,
    );

    my $new_parent_map_key = $ghost_location_data{'parent_map_key'};
    $parent_zone_key = $ghost_location_data{'parent_zone_key'};
    my $new_location_coords = $ghost_location_data{'location_coords'};

    my $parent_map_coords
        = $self->{'map_layout'}{$new_parent_map_key}{'coords'};

    # Use start location as basis for locating
    my $relative_pixel_start
        = $new_location_coords->[0] - $parent_map_coords->[0];

    my $relative_unit_start = $relative_pixel_start /
        (      $self->{'map_pixels_per_unit'}{$new_parent_map_key}
            || $self->{'scaffold'}{$parent_zone_key}{'pixels_per_unit'} );
    my $parent_map_data = $self->app_data_module()
        ->map_data( map_id => $self->{'map_key_to_id'}{$new_parent_map_key},
        );

    # Modify the relative unit start to round to the unit granularity
    my $parent_unit_granularity
        = $self->map_type_data( $parent_map_data->{'map_type_acc'},
        'unit_granularity' )
        || DEFAULT->{'unit_granularity'};
    $relative_unit_start = round_to_granularity( $relative_unit_start,
        $parent_unit_granularity );

    my $new_feature_start
        = $relative_unit_start + $parent_map_data->{'map_start'};
    my $new_feature_stop
        = $new_feature_start - $self->{'sub_maps'}{$map_key}{'feature_start'}
        + $self->{'sub_maps'}{$map_key}{'feature_stop'};

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
    my $zone_key           = $self->{'map_key_to_zone_key'}{$map_key};
    my $window_key         = $self->{'scaffold'}{$zone_key}{'window_key'};

    my @action_data = (
        'move_map',
        $map_key,
        $self->{'sub_maps'}{$map_key}{'parent_map_key'},
        $self->{'sub_maps'}{$map_key}{'feature_start'},
        $self->{'sub_maps'}{$map_key}{'feature_stop'},
        $new_parent_map_key,
        $new_feature_start,
        $new_feature_stop,
    );

    $self->add_action(
        window_key  => $window_key,
        action_data => \@action_data,
    );

    $self->move_sub_map_on_parents_in_memory(
        sub_map_key    => $map_key,
        parent_map_key => $new_parent_map_key,
        feature_start  => $new_feature_start,
        feature_stop   => $new_feature_stop,
    );

# This probably should be more elegant but for now, just layout the whole thing
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

    $self->app_interface()->draw_window(
        window_key       => $window_key,
        app_display_data => $self,
    );

    return;

}

# ----------------------------------------------------
sub move_sub_map_on_parents_in_memory {

=pod

=head2 move_sub_map_on_parents_in_memory

Do the actual in memory part of moving a map from one place on a parent to
another (and possibly on a different parrent.

=cut

    my ( $self, %args ) = @_;
    my $sub_map_key    = $args{'sub_map_key'};
    my $parent_map_key = $args{'parent_map_key'};
    my $feature_start  = $args{'feature_start'};
    my $feature_stop   = $args{'feature_stop'};

    # BF POSSIBLY MOVE ZONE TO BE ADDED HERE

    my $sub_zone_key = $self->{'map_key_to_zone_key'}{$sub_map_key};
    my $window_key   = $self->{'scaffold'}{$sub_zone_key}{'window_key'};
    my $parent_zone_key
        = $self->{'scaffold'}{$sub_zone_key}{'parent_zone_key'};

    # Modify Parent
    $self->{'sub_maps'}{$sub_map_key}{'parent_map_key'} = $parent_map_key;
    $self->{'sub_maps'}{$sub_map_key}{'feature_start'}  = $feature_start;
    $self->{'sub_maps'}{$sub_map_key}{'feature_stop'}   = $feature_stop;

    return;
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
    if ( not @{ $self->{'window_actions'}{$window_key}{'actions'} || [] }
        or $last_action_index < 0 )
    {

        # Can't go back any further
        return;
    }

    my $last_action = $window_actions->{'actions'}[$last_action_index];

    # Handle each action type
    if ( $last_action->[0] eq 'move_map' ) {
        $self->move_sub_map_on_parents_in_memory(
            sub_map_key    => $last_action->[1],
            parent_map_key => $last_action->[2],
            feature_start  => $last_action->[3],
            feature_stop   => $last_action->[4],
        );
    }

    $self->{'window_actions'}{$window_key}{'last_action_index'}--;

# This probably should be more elegant but for now, just layout the whole thing
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

    $self->app_interface()->draw_window(
        window_key       => $window_key,
        app_display_data => $self,
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

    my $next_action_index
        = $self->{'window_actions'}{$window_key}{'last_action_index'} + 1;
    my $next_action = $window_actions->{'actions'}[$next_action_index];
    unless ( @{ $next_action || [] } ) {
        return;
    }

    # Handle each action type
    if ( $next_action->[0] eq 'move_map' ) {
        $self->move_sub_map_on_parents_in_memory(
            sub_map_key    => $next_action->[1],
            parent_map_key => $next_action->[5],
            feature_start  => $next_action->[6],
            feature_stop   => $next_action->[7],
        );
    }

    $self->{'window_actions'}{$window_key}{'last_action_index'}++;

# This probably should be more elegant but for now, just layout the whole thing
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

    $self->app_interface()->draw_window(
        window_key       => $window_key,
        app_display_data => $self,
    );

    return;
}

# ----------------------------------------------------
sub condenced_window_actions {

    #print STDERR "ADD_NEEDS_MODDED 39\n";

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
        if ( $action->[0] eq 'move_map' ) {
            my $map_key = $action->[1];
            if ( $moves{$map_key} ) {

                # leave the original loc alone but change the end
                $moves{$map_key}->[5] = $action->[5];
                $moves{$map_key}->[6] = $action->[6];
                $moves{$map_key}->[7] = $action->[7];
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

=head2 move_ghost

Controls how the ghost map moves.

=cut

    my ( $self, %args ) = @_;
    my $map_key = $args{'map_key'};

    my $zone_key        = $self->{'map_key_to_zone_key'}{$map_key};
    my $parent_zone_key = $self->{'scaffold'}{$zone_key}{'parent_zone_key'};
    my $window_key      = $self->{'scaffold'}{$zone_key}{'window_key'};

   # If no parent, don't bother
   # allow movement when the sub-map and parent were at different zoom levels.
    unless ($parent_zone_key
        and $self->{'scaffold'}{$zone_key}{'attached_to_parent'} )
    {
        return;
    }

    my $parent_map_key     = $self->{'scaffold'}{$zone_key}{'parent_map_key'};
    my $parent_zone_layout = $self->{'zone_layout'}{$parent_zone_key};
    my $parent_map_layout  = $self->{'map_layout'}{$parent_map_key};
    my $parent_map_id      = $self->{'map_key_to_id'}{$parent_map_key};
    my $parent_data
        = $self->app_data_module()->map_data( map_id => $parent_map_id, );
    my $parent_start = $parent_data->{'map_start'};
    my $parent_stop  = $parent_data->{'map_stop'};
    my $parent_pixels_per_unit
        = $self->{'map_pixels_per_unit'}{$parent_map_key}
        || $self->{'scaffold'}{$parent_zone_key}{'pixels_per_unit'};

    my $feature_start = $self->{'sub_maps'}{$map_key}{'feature_start'};
    my $feature_stop  = $self->{'sub_maps'}{$map_key}{'feature_stop'};

    my $parent_x_offset = $self->{'scaffold'}{$parent_zone_key}{'x_offset'};

    my $x1 = ( ( $feature_start - $parent_start ) * $parent_pixels_per_unit )
        + $parent_map_layout->{'coords'}[0] + $parent_x_offset;
    my $x2 = ( ( $feature_stop - $parent_start ) * $parent_pixels_per_unit )
        + $parent_map_layout->{'coords'}[0] + $parent_x_offset;

    my $y1 = $parent_map_layout->{'coords'}[1];
    my $y2 = $parent_map_layout->{'coords'}[3];

    my $visible = 1;
    if (   $x2 < $parent_zone_layout->{'viewable_internal_x1'}
        or $x1 > $parent_zone_layout->{'viewable_internal_x2'} )
    {
        $visible = 0;
    }

    # save for later
    $self->{'current_ghost_parent_map_key'} = $parent_map_key;

    my %return_hash = (
        visible         => $visible,
        parent_zone_key => $parent_zone_key,
        window_key      => $window_key,
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

    my $zone_key        = $self->{'map_key_to_zone_key'}{$map_key};
    my $window_key      = $self->{'scaffold'}{$zone_key}{'window_key'};
    my $parent_zone_key = $self->{'scaffold'}{$zone_key}{'parent_zone_key'};
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
        mouse_x           => $mouse_x,
        mouse_y           => $mouse_y,
    );
    my $ghost_parent_zone_key
        = $self->{'map_key_to_zone_key'}{$ghost_parent_map_key};

    my %ghost_location_data = $self->get_ghost_location_coords(
        map_key               => $map_key,
        zone_key              => $zone_key,
        mouse_dx              => $mouse_dx,
        mouse_dy              => $mouse_dy,
        ghost_bounds          => $ghost_bounds,
        ghost_parent_zone_key => $ghost_parent_zone_key,
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
        || $self->{'map_key_to_zone_key'}{$map_key};
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

    return (    $x >= $box_coords->[0]
            and $y >= $box_coords->[1]
            and $x <= $box_coords->[2]
            and $y <= $box_coords->[3] );
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

    $self->{'correspondences_on'}{$zone_key1}{$zone_key2} = 0;
    $self->{'correspondences_on'}{$zone_key2}{$zone_key1} = 0;
    my %zone2_maps;
    map { $zone2_maps{$_} = 1 } @{ $self->{'map_order'}{$zone_key2} || [] };

    foreach my $map_key1 ( @{ $self->{'map_order'}{$zone_key1} || [] } ) {
        foreach my $map_key2 (
            keys %{ $self->{'corr_layout'}{'maps'}{$map_key1} || {} } )
        {
            next unless ( $zone2_maps{$map_key2} );
            $self->destroy_items(
                items => $self->{'corr_layout'}{'maps'}{$map_key1}{$map_key2}
                    {'items'},
                window_key => $window_key,
            );
            delete $self->{'corr_layout'}{'maps'}{$map_key1}{$map_key2};
            delete $self->{'corr_layout'}{'maps'}{$map_key2}{$map_key1};

            unless (
                keys %{ $self->{'corr_layout'}{'maps'}{$map_key2} || {} } )
            {
                delete $self->{'corr_layout'}{'maps'}{$map_key2};
            }
        }
        unless ( keys %{ $self->{'corr_layout'}{'maps'}{$map_key1} || {} } ) {
            delete $self->{'corr_layout'}{'maps'}{$map_key1};
        }
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

    $self->{'correspondences_on'}{$zone_key1}{$zone_key2} = 1;
    $self->{'correspondences_on'}{$zone_key2}{$zone_key1} = 1;

    add_correspondences(
        window_key       => $window_key,
        zone_key1        => $zone_key1,
        zone_key2        => $zone_key2,
        app_display_data => $self,
    );
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
sub delete_slot {

    #print STDERR "ADD_NEEDS_MODDED 47\n";

=pod

=head2 delete_slot

Deletes the slot data and wipes them from the canvas

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $slot_key   = $args{'slot_key'};

    my $slot_layout = $self->{'slot_layout'}{$slot_key};

    # Remove correspondences
    foreach
        my $slot_key2 ( keys %{ $self->{'correspondences_on'}{$slot_key} } )
    {
        $self->clear_slot_corrs(
            window_key => $window_key,
            slot_key1  => $slot_key,
            slot_key2  => $slot_key2,
        );
    }

    # Remove Drawing info
    foreach my $drawing_item_name (qw[ separator background ]) {
        $self->destroy_items(
            window_key => $window_key,
            items      => $slot_layout->{$drawing_item_name},
        );
    }

    foreach my $map_key ( @{ $self->{'map_order'}{$slot_key} || [] } ) {
        ### Someday Add a delet_map method
    }

    # Remove from parent
    my $parent_slot_key = $self->{'scaffold'}{$slot_key}{'parent_zone_key'};
    for (
        my $i = 0;
        $i <= $#{ $self->{'scaffold'}{$parent_slot_key}{'children'} || [] };
        $i++
        )
    {
        if ( $slot_key
            == $self->{'scaffold'}{$parent_slot_key}{'children'}[$i] )
        {
            splice @{ $self->{'scaffold'}{$parent_slot_key}{'children'} }, $i,
                1;
            last;
        }
    }

    delete $self->{'slot_layout'}{$slot_key};
    delete $self->{'scaffold'}{$slot_key};
    delete $self->{'map_order'}{$slot_key};
    delete $self->{'slot_info'}{$slot_key};
    delete $self->{'map_id_to_key_by_slot'}{$slot_key};

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
        foreach my $child_zone_key ( @{ $zone_scaffold->{'children'} || [] } )
        {
            next
                unless ( $map_key
                == $self->{'scaffold'}{$child_zone_key}{'parent_map_key'} );
            push @child_zones,
                $self->create_zone_output_hash(
                window_key => $window_key,
                zone_key   => $child_zone_key
                );
        }

        my $map_data = $self->app_data_module()
            ->map_data( map_id => $self->{'map_key_to_id'}{$map_key}, );
        my $map_acc = $map_data->{'map_acc'};

        push @map, { 'map_acc' => $map_acc, child_zone => \@child_zones, };
    }
    $zone_hash{'map'} = \@map;

    return \%zone_hash;
}

# ----------------------------------------------------
sub get_map_ids {

    #print STDERR "ADD_NEEDS_MODDED 50\n";

=pod

=head2 get_map_ids

returns

=cut

    my ( $self, %args ) = @_;
    my $map_key  = $args{'map_key'};
    my $map_keys = $args{'map_keys'} || [];

    if ($map_key) {
        return $self->{'map_key_to_id'}{$map_key};
    }
    elsif (@$map_keys) {
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
            children           => [$child_slot_key, ],
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

Revisit

    $self->{'window_actions'} = {
        $window_key => {
            last_action_index => -1,
            actions => [[ @action_specific_data ],],
        }
    }

=head4 move_map

Revisit

    @action_specific_data = [
        'move_map',         
        $sub_map_key, 
        $ori_parent_map_key,
        $ori_feature_start, 
        $ori_feature_stop,
        $new_parent_map_key,
        $new_feature_start, 
        $new_feature_stop,
    ];

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

