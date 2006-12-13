package Bio::GMOD::CMap::Drawer::AppDisplayData;

# vim: set ft=perl:

# $Id: AppDisplayData.pm,v 1.24 2006-12-13 19:57:47 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.24 $)[-1];

use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Drawer::AppLayout qw[
    layout_new_panel
    layout_new_slot
    layout_overview
    overview_selected_area
    layout_reference_maps
    layout_sub_maps
    layout_slot_with_current_maps
    add_correspondences
    add_slot_separator
    move_slot
    set_slot_bgcolor
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
    if ( $self->{'panel_order'}{$window_key} ) {
        $self->clear_window( window_key => $window_key, );
    }

    my $panel_key = $self->next_internal_key('panel');
    my $slot_key  = $self->next_internal_key('slot');

    $self->{'panel_order'}{$window_key} = [ $panel_key, ];
    $self->{'slot_order'}{$panel_key}   = [ $slot_key, ];

    $self->{'scaffold'}{$slot_key} = {
        window_key         => $window_key,
        panel_key          => $panel_key,
        map_set_id         => undef,
        parent             => undef,
        children           => [],
        scale              => 1,
        x_offset           => 0,
        attached_to_parent => 0,
        expanded           => 1,
        is_top             => 1,
        pixels_per_unit    => 0,
    };

    my $map_data
        = $self->app_data_module()->map_data_array( map_ids => $map_ids, );

    $self->set_default_window_layout( window_key => $window_key, );

    $self->initialize_panel_layout($panel_key);
    $self->initialize_slot_layout($slot_key);
    $self->app_interface()->int_create_panel(
        window_key       => $window_key,
        panel_key        => $panel_key,
        app_display_data => $self,
    );

    foreach my $map_id ( @{ $map_ids || [] } ) {
        my $map_key = $self->next_internal_key('map');
        push @{ $self->{'map_order'}{$slot_key} },    $map_key;
        push @{ $self->{'map_id_to_keys'}{$map_id} }, $map_key;
        $self->{'map_id_to_key_by_slot'}{$slot_key}{$map_id} = $map_key;
        $self->{'map_key_to_id'}{$map_key}                   = $map_id;
        $self->{'map_key_to_slot_key'}{$map_key}             = $slot_key;
        $self->initialize_map_layout($map_key);
    }

    $self->add_sub_maps(
        window_key      => $window_key,
        panel_key       => $panel_key,
        parent_slot_key => $slot_key,
    );

    # Handle overview after the regular slots, so we can use that info
    $self->{'overview'}{$panel_key} = {
        slot_key   => $slot_key,     # top slot in overview
        window_key => $window_key,
    };
    $self->initialize_overview_layout($panel_key);

    layout_new_panel(
        window_key       => $window_key,
        panel_key        => $panel_key,
        app_display_data => $self,
    );
    layout_overview(
        window_key       => $window_key,
        panel_key        => $panel_key,
        app_display_data => $self,
    );

    $self->change_selected_slot(
        window_key => $window_key,
        panel_key  => $panel_key,
        slot_key   => $slot_key,
    );
    $self->app_interface()->int_create_slot_controls(
        window_key       => $window_key,
        panel_key        => $panel_key,
        app_display_data => $self,
    );

    $self->app_interface()->draw_panel(
        window_key       => $window_key,
        panel_key        => $panel_key,
        app_display_data => $self,
    );

    return;
}

# ----------------------------------------------------
sub add_sub_maps {

=pod

=head2 add_sub_maps

Adds sub-maps to the view.  Doesn't do any sanity checking.

=cut

    my ( $self, %args ) = @_;
    my $window_key      = $args{'window_key'}      or return;
    my $panel_key       = $args{'panel_key'}       or return;
    my $parent_slot_key = $args{'parent_slot_key'} or return;
    my $slot_order_array = $args{'slot_order_array'}
        || $self->{'slot_order'}{$panel_key};

    my @sub_map_keys;
    foreach my $map_key ( @{ $self->{'map_order'}{$parent_slot_key} || [] } )
    {
        my $map_id = $self->{'map_key_to_id'}{$map_key};

        # Collect Sub-Maps
        my $sub_maps
            = $self->app_data_module()->sub_maps( map_id => $map_id, );

        foreach my $sub_map ( @{ $sub_maps || [] } ) {
            my $sub_map_id  = $sub_map->{'sub_map_id'};
            my $sub_map_key = $self->next_internal_key('map');

            push @{ $self->{'map_id_to_keys'}{$sub_map_id} }, $sub_map_key;
            $self->{'map_key_to_id'}{$sub_map_key} = $sub_map_id;

            $self->{'sub_maps'}{$sub_map_key} = {
                parent_map_key => $map_key,
                feature_start  => $sub_map->{'feature_start'},
                feature_stop   => $sub_map->{'feature_stop'},
                feature_id     => $sub_map->{'feature_id'},
            };
            push @sub_map_keys, $sub_map_key;

        }
    }
    unless (@sub_map_keys) {

        # No Sub Maps
        return;
    }

    my $slot_order_index;
    for ( my $i = 0; $i <= $#{$slot_order_array}; $i++ ) {
        if ( $parent_slot_key == $slot_order_array->[$i] ) {
            $slot_order_index = $i;
            last;
        }
    }
    unless ( defined $slot_order_index ) {
        die "Slot $parent_slot_key not in Panel $panel_key\n";
    }

    # Split maps into slots based on their map set
    my %maps_by_set;
    foreach my $sub_map_key (@sub_map_keys) {
        my $sub_map_id = $self->{'map_key_to_id'}{$sub_map_key};
        my $sub_map_data
            = $self->app_data_module()->map_data( map_id => $sub_map_id, );
        push @{ $maps_by_set{ $sub_map_data->{'map_set_id'} } }, $sub_map_key;
    }

    my $parent_x_offset = $self->{'scaffold'}{$parent_slot_key}{'x_offset'};
    my @new_slot_keys;
    foreach my $set_key ( keys %maps_by_set ) {
        my $child_slot_key = $self->next_internal_key('slot');
        push @new_slot_keys, $child_slot_key;
        $slot_order_index++;
        splice @{$slot_order_array}, $slot_order_index, 0, ($child_slot_key);

        $self->initialize_slot_layout($child_slot_key);
        $self->{'scaffold'}{$child_slot_key} = {
            window_key         => $window_key,
            panel_key          => $panel_key,
            map_set_id         => undef,
            parent             => $parent_slot_key,
            children           => [],
            scale              => 1,
            x_offset           => $parent_x_offset,
            attached_to_parent => 1,
            expanded           => 0,
            is_top             => 0,
            pixels_per_unit    => 0,
        };
        push @{ $self->{'scaffold'}{$parent_slot_key}{'children'} },
            $child_slot_key;

        foreach my $map_key ( @{ $maps_by_set{$set_key} || [] } ) {
            push @{ $self->{'map_order'}{$child_slot_key} }, $map_key;
            $self->{'map_key_to_slot_key'}{$map_key} = $child_slot_key;
            $self->{'map_id_to_key_by_slot'}{$child_slot_key}
                { $self->{'map_key_to_id'}{$map_key} } = $map_key;
            $self->initialize_map_layout($map_key);
        }
    }
    return \@new_slot_keys;
}

# ----------------------------------------------------
sub zoom_slot {

=pod

=head2 zoom_slot

Zoom slots

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $panel_key  = $args{'panel_key'};
    my $slot_key   = $args{'slot_key'};
    my $cascading  = $args{'cascading'} || 0;
    my $zoom_value = $args{'zoom_value'} or return;

    my $slot_scaffold = $self->{'scaffold'}{$slot_key};
    my $overview_slot_layout
        = $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key};

    if ($cascading) {
        if ( $slot_scaffold->{'attached_to_parent'} ) {
            $overview_slot_layout->{'scale_factor_from_main'} /= $zoom_value
                if ($overview_slot_layout);

            # Get Offset from parent
            $slot_scaffold->{'x_offset'}
                = $self->{'scaffold'}{ $slot_scaffold->{'parent'} }
                {'x_offset'};

            $self->relayout_sub_map_slot(
                window_key => $window_key,
                panel_key  => $panel_key,
                slot_key   => $slot_key,
            );
        }
        else {
            $slot_scaffold->{'scale'} /= $zoom_value;
            if ($slot_scaffold->{'scale'} == 1
                and ( $slot_scaffold->{'x_offset'}
                    == $self->{'scaffold'}{ $slot_scaffold->{'parent'} }
                    {'x_offset'} )
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
                $self->reset_slot_corrs(
                    window_key => $window_key,
                    panel_key  => $panel_key,
                    slot_key   => $slot_key,
                );
            }
        }
    }
    elsif ( $slot_scaffold->{'is_top'} ) {
        $slot_scaffold->{'scale'}           *= $zoom_value;
        $slot_scaffold->{'pixels_per_unit'} *= $zoom_value;
        $overview_slot_layout->{'scale_factor_from_main'} /= $zoom_value
            if ($overview_slot_layout);
        $self->set_new_zoomed_offset(
            window_key => $window_key,
            panel_key  => $panel_key,
            slot_key   => $slot_key,
            zoom_value => $zoom_value,
        );
        $self->relayout_ref_map_slot(
            window_key => $window_key,
            panel_key  => $panel_key,
            slot_key   => $slot_key,
        );
    }
    else {
        $overview_slot_layout->{'scale_factor_from_main'} /= $zoom_value
            if ($overview_slot_layout);
        $slot_scaffold->{'scale'} *= $zoom_value;
        if ( $slot_scaffold->{'attached_to_parent'} ) {
            $self->detach_slot_from_parent( slot_key => $slot_key, );
        }
        elsif (
            $slot_scaffold->{'scale'} == 1
            and ( $slot_scaffold->{'x_offset'}
                == $self->{'scaffold'}{ $slot_scaffold->{'parent'} }
                {'x_offset'} )
            )
        {
            $self->attach_slot_to_parent(
                slot_key  => $slot_key,
                panel_key => $panel_key,
            );
        }

        $self->set_new_zoomed_offset(
            window_key => $window_key,
            panel_key  => $panel_key,
            slot_key   => $slot_key,
            zoom_value => $zoom_value,
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
        $self->zoom_slot(
            window_key => $window_key,
            panel_key  => $panel_key,
            slot_key   => $child_slot_key,
            zoom_value => $zoom_value,
            cascading  => 1,
        );
    }

    unless ($cascading) {
        $self->{'panel_layout'}{$panel_key}{'sub_changed'} = 1;
        $self->app_interface()->draw_panel(
            panel_key        => $panel_key,
            window_key       => $window_key,
            app_display_data => $self,
        );
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
        $slot_key = $self->{'scaffold'}{$slot_key}{'parent'};
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
sub scroll_slot {

=pod

=head2 scroll_slot

Scroll slots

=cut

    my ( $self, %args ) = @_;
    my $window_key   = $args{'window_key'};
    my $panel_key    = $args{'panel_key'};
    my $slot_key     = $args{'slot_key'};
    my $cascading    = $args{'cascading'} || 0;
    my $scroll_value = $args{'scroll_value'} or return;

    my $slot_scaffold = $self->{'scaffold'}{$slot_key};
    my $overview_slot_layout
        = $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key};

    if ($cascading) {
        if ( $slot_scaffold->{'attached_to_parent'} ) {

            # Get Offset from parent
            $slot_scaffold->{'x_offset'}
                = $self->{'scaffold'}{ $slot_scaffold->{'parent'} }
                {'x_offset'};

            $self->relayout_sub_map_slot(
                window_key => $window_key,
                panel_key  => $panel_key,
                slot_key   => $slot_key,
            );
        }
        else {
            if ($slot_scaffold->{'scale'} == 1
                and ( $slot_scaffold->{'x_offset'} + $scroll_value
                    == $self->{'scaffold'}{ $slot_scaffold->{'parent'} }
                    {'x_offset'} )
                )
            {
                $slot_scaffold->{'x_offset'} += $scroll_value;
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
                $self->reset_slot_corrs(
                    window_key => $window_key,
                    panel_key  => $panel_key,
                    slot_key   => $slot_key,
                );
            }
        }
    }
    elsif ( $slot_scaffold->{'is_top'} ) {
        $slot_scaffold->{'x_offset'} += $scroll_value;
        $self->relayout_ref_map_slot(
            window_key => $window_key,
            panel_key  => $panel_key,
            slot_key   => $slot_key,
        );
    }
    else {
        $slot_scaffold->{'x_offset'} += $scroll_value;
        if ( $slot_scaffold->{'attached_to_parent'} ) {
            $self->detach_slot_from_parent( slot_key => $slot_key, );
        }
        elsif (
            $slot_scaffold->{'scale'} == 1
            and ( $slot_scaffold->{'x_offset'}
                == $self->{'scaffold'}{ $slot_scaffold->{'parent'} }
                {'x_offset'} )
            )
        {
            $self->attach_slot_to_parent(
                slot_key  => $slot_key,
                panel_key => $panel_key,
            );
        }

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
        $self->scroll_slot(
            window_key   => $window_key,
            panel_key    => $panel_key,
            slot_key     => $child_slot_key,
            scroll_value => $scroll_value,
            cascading    => 1,
        );
    }

    unless ($cascading) {
        $self->{'panel_layout'}{$panel_key}{'sub_changed'} = 1;
        $self->app_interface()->draw_panel(
            panel_key        => $panel_key,
            window_key       => $window_key,
            app_display_data => $self,
        );
    }
    return;
}

# ----------------------------------------------------
sub toggle_corrs_slot {

=pod

=head2 toggle_corrs_slot

toggle the correspondences for a slot

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $panel_key  = $args{'panel_key'};
    my $slot_key1  = $args{'slot_key'};

    my $slot_key2 = $self->{'scaffold'}{$slot_key1}{'parent'};
    return unless ($slot_key2);

    if ( $self->{'correspondences_on'}{$slot_key1}{$slot_key2} ) {
        $self->clear_slot_corrs(
            panel_key => $panel_key,
            slot_key1 => $slot_key1,
            slot_key2 => $slot_key2,
        );
    }
    else {
        $self->add_slot_corrs(
            window_key => $window_key,
            panel_key  => $panel_key,
            slot_key1  => $slot_key1,
            slot_key2  => $slot_key2,
        );
    }

    return;
}

# ----------------------------------------------------
sub expand_slot {

=pod

=head2 expand_slot

expand slots

=cut

    my ( $self, %args ) = @_;
    my $window_key   = $args{'window_key'};
    my $panel_key    = $args{'panel_key'};
    my $old_slot_key = $args{'slot_key'};

    my $old_slot_scaffold = $self->{'scaffold'}{$old_slot_key};
    my $old_slot_layout   = $self->{'slot_layout'}{$old_slot_key};

    return if $old_slot_scaffold->{'expanded'};

    my $parent_slot_key = $old_slot_scaffold->{'parent'};

    my %row_index_maps;

    foreach my $map_key ( @{ $self->{'map_order'}{$old_slot_key} || [] } ) {
        push @{ $row_index_maps{ $self->{'map_layout'}{$map_key}
                    {'row_index'} } }, $map_key;
    }
    my @slot_order_insert;

    # Get Old slot order position
    my $old_slot_order_pos = undef;
    for (
        my $i = 0;
        $i <= $#{ $self->{'slot_order'}{$panel_key} || [] };
        $i++
        )
    {
        if ( $old_slot_key == $self->{'slot_order'}{$panel_key}[$i] ) {
            $old_slot_order_pos = $i;
            last;
        }
    }

    # Get the Slots where the old slot had corrs with
    my @corresponding_slot_keys
        = keys %{ $self->{'correspondences_on'}{$old_slot_key} };

    unless ( defined $old_slot_order_pos ) {
        die "Slot Order position not found for slot $old_slot_key\n";
    }
    my $old_slot_y1 = $old_slot_layout->{'bounds'}[1];
    my $old_slot_y2 = $old_slot_layout->{'bounds'}[3];

    my $start_min_y   = $old_slot_y1;
    my $slot_buffer_y = 15;
    my $slot_position = $old_slot_order_pos;
    foreach my $row_index ( sort { $a <=> $b } keys %row_index_maps ) {

        # Create Slot
        my $new_slot_key = $self->next_internal_key('slot');
        $self->initialize_slot_layout($new_slot_key);

        #Copy important slot info
        $self->copy_slot_scaffold(
            old_slot_key => $old_slot_key,
            new_slot_key => $new_slot_key,
        );

        # Add as child of parent
        push @{ $self->{'scaffold'}{$parent_slot_key}{'children'} },
            $new_slot_key;

        # Add Slot to order
        push @slot_order_insert, $new_slot_key;

        # Move Maps to slot and adjust Y value
        layout_slot_with_current_maps(
            window_key       => $window_key,
            panel_key        => $panel_key,
            old_slot_key     => $old_slot_key,
            new_slot_key     => $new_slot_key,
            row_index        => $row_index,
            start_min_y      => $start_min_y,
            map_keys         => $row_index_maps{$row_index},
            app_display_data => $self,
        );
        $self->{'scaffold'}{$new_slot_key}{'expanded'} = 1;

        # Move slot_info to new slot
        # and add map_id_to_key_by_slot
        foreach my $map_key ( @{ $row_index_maps{$row_index} } ) {
            $self->{'map_key_to_slot_key'}{$map_key} = $new_slot_key;
            $self->{'map_id_to_key_by_slot'}{$new_slot_key}
                { $self->{'map_key_to_id'}{$map_key} } = $map_key;
            my $map_id = $self->{'map_key_to_id'}{$map_key};
            $self->{'slot_info'}{$new_slot_key}{$map_id}
                = $self->{'slot_info'}{$old_slot_key}{$map_id};
            $self->{'slot_info'}{$old_slot_key}{$map_id} = undef;
        }

        # Handle inherited correspondences
        foreach my $slot_key2 (@corresponding_slot_keys) {
            $self->clear_slot_corrs(
                panel_key => $panel_key,
                slot_key1 => $new_slot_key,
                slot_key2 => $slot_key2,
            );
            $self->add_slot_corrs(
                window_key => $window_key,
                panel_key  => $panel_key,
                slot_key1  => $new_slot_key,
                slot_key2  => $slot_key2,
            );
        }

        $start_min_y = $self->{'slot_layout'}{$new_slot_key}{'bounds'}[3]
            + $slot_buffer_y;

        # Add Sub Slots
        my $sub_slot_keys = $self->add_sub_maps(
            window_key       => $window_key,
            panel_key        => $panel_key,
            parent_slot_key  => $new_slot_key,
            slot_order_array => \@slot_order_insert,
        );

        foreach my $sub_slot_key (@$sub_slot_keys) {
            $slot_position++;
            layout_new_slot(
                window_key       => $window_key,
                panel_key        => $panel_key,
                slot_key         => $sub_slot_key,
                slot_position    => $slot_position,
                start_min_y      => $start_min_y,
                app_display_data => $self,
            );
            $start_min_y = $self->{'slot_layout'}{$sub_slot_key}{'bounds'}[3]
                + $slot_buffer_y;
        }
        $slot_position++;
    }

    # Insert new slots into slot_order in place of the old one.
    splice @{ $self->{'slot_order'}{$panel_key} }, $old_slot_order_pos, 1,
        @slot_order_insert;

    # Wipe 'map_order' for this slot so removing slot doesn't kill the maps
    delete $self->{'map_order'}{$old_slot_key};

    # Remove Old Slot
    $self->delete_slot(
        panel_key => $panel_key,
        slot_key  => $old_slot_key,
    );
    $self->app_interface()->destroy_slot_controls(
        panel_key => $panel_key,
        slot_key  => $old_slot_key,
    );

    my $height_change = $start_min_y - $old_slot_y2;

    # Move Lower Slots and re-add their slot menu for recreation later
    my $first_lower_slot_pos
        = $old_slot_order_pos + scalar(@slot_order_insert);
    for (
        my $i = $first_lower_slot_pos;
        $i <= $#{ $self->{'slot_order'}{$panel_key} || [] };
        $i++
        )
    {
        my $slot_key = $self->{'slot_order'}{$panel_key}[$i];
        move_slot(
            panel_key        => $panel_key,
            slot_key         => $slot_key,
            y                => $height_change,
            app_display_data => $self,
            app_interface    => $self->app_interface(),
        );
        $self->app_interface()->destroy_slot_controls(
            panel_key => $panel_key,
            slot_key  => $slot_key,
        );
        $self->app_interface()->add_slot_controls(
            window_key       => $window_key,
            panel_key        => $panel_key,
            slot_key         => $slot_key,
            app_display_data => $self,
        );
    }
    $self->{'panel_layout'}{$panel_key}{'bounds'}[3] += $height_change;

    # Handle Overview
    $self->recreate_overview(
        window_key => $window_key,
        panel_key  => $panel_key,
    );

    # Add the New Slot Controls
    foreach my $slot_key (@slot_order_insert) {
        $self->app_interface()->add_slot_controls(
            window_key       => $window_key,
            panel_key        => $panel_key,
            slot_key         => $slot_key,
            app_display_data => $self,
        );
    }

    $self->app_interface()->draw_panel(
        panel_key        => $panel_key,
        window_key       => $window_key,
        app_display_data => $self,
    );

    return;
}

# ----------------------------------------------------
sub reattach_slot {

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
                = $self->{'scaffold'}{ $slot_scaffold->{'parent'} }
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
                and ( $slot_scaffold->{'x_offset'} + $scroll_value
                    == $self->{'scaffold'}{ $slot_scaffold->{'parent'} }
                    {'x_offset'} )
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
                $self->reset_slot_corrs(
                    window_key => $window_key,
                    panel_key  => $panel_key,
                    slot_key   => $slot_key,
                );
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
            = $self->{'scaffold'}{ $slot_scaffold->{'parent'} }{'x_offset'};

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
        $self->app_interface()->draw_panel(
            panel_key        => $panel_key,
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

    # Redraw everything
    foreach my $panel_key ( @{ $self->{'panel_order'}{$window_key} || [] } ) {
        layout_new_panel(
            window_key       => $window_key,
            panel_key        => $panel_key,
            app_display_data => $self,
            width            => $width - 200,
        );
        layout_overview(
            window_key       => $window_key,
            panel_key        => $panel_key,
            app_display_data => $self,
            width            => $width - 10,
        );
        $self->app_interface()->draw_panel(
            window_key       => $window_key,
            panel_key        => $panel_key,
            app_display_data => $self,
        );
    }

    return;
}

# ----------------------------------------------------
sub set_new_zoomed_offset {

=pod

=head2 set_new_zoomed_offset

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $panel_key  = $args{'panel_key'}  or return;
    my $slot_key   = $args{'slot_key'}   or return;
    my $zoom_value = $args{'zoom_value'} or return;

    my $old_width = $self->{'slot_layout'}{$slot_key}{'bounds'}[2]
        - $self->{'slot_layout'}{$slot_key}{'bounds'}[0] + 1;

    my $new_width = $old_width * $zoom_value;

    my $change = ( $new_width - $old_width ) / 2;

    $self->{'scaffold'}{$slot_key}{'x_offset'} *= $zoom_value;
    $self->{'scaffold'}{$slot_key}{'x_offset'} += $change;

    return;
}

# ----------------------------------------------------
sub relayout_ref_map_slot {

=pod

=head2 relayout_ref_map_slot

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $panel_key  = $args{'panel_key'}  or return;
    my $slot_key   = $args{'slot_key'}   or return;

    $self->clear_slot_maps(
        panel_key => $panel_key,
        slot_key  => $slot_key,
    );

    # These maps are features of the parent map
    layout_reference_maps(
        window_key       => $window_key,
        panel_key        => $panel_key,
        slot_key         => $slot_key,
        app_display_data => $self,
    );

    return;
}

# ----------------------------------------------------
sub relayout_sub_map_slot {

=pod

=head2 relayout_sub_map_slot

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $panel_key  = $args{'panel_key'}  or return;
    my $slot_key   = $args{'slot_key'}   or return;

    $self->clear_slot_maps(
        panel_key => $panel_key,
        slot_key  => $slot_key,
    );

    # These maps are features of the parent map
    layout_sub_maps(
        window_key       => $window_key,
        panel_key        => $panel_key,
        slot_key         => $slot_key,
        app_display_data => $self,
    );

    # Reset correspondences
    $self->reset_slot_corrs(
        window_key => $window_key,
        panel_key  => $panel_key,
        slot_key   => $slot_key,
    );

    return;
}

# ----------------------------------------------------
sub create_slot_coverage_array {

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
sub change_selected_slot {

=pod

=head2 change_selected_slot

=cut

    my ( $self, %args ) = @_;
    my $slot_key   = $args{'slot_key'} or return;
    my $panel_key  = $self->{'scaffold'}{$slot_key}{'panel_key'};
    my $window_key = $self->{'scaffold'}{$slot_key}{'window_key'};

    my $old_selected_slot_key = $self->{'selected_slot_key'};
    $self->{'selected_slot_key'} = $slot_key;

    return
        if ( $old_selected_slot_key and $old_selected_slot_key == $slot_key );

    if (    $old_selected_slot_key
        and $self->{'scaffold'}{$old_selected_slot_key} )
    {
        set_slot_bgcolor(
            panel_key        => $panel_key,
            slot_key         => $old_selected_slot_key,
            app_display_data => $self,
        );
    }
    set_slot_bgcolor(
        panel_key        => $panel_key,
        slot_key         => $slot_key,
        app_display_data => $self,
    );

    $self->app_interface()->draw_panel(
        panel_key        => $panel_key,
        window_key       => $window_key,
        app_display_data => $self,
    );

    return;
}

# ----------------------------------------------------
sub slot_bgcolor {

=pod

=head2 slot_bgcolor

=cut

    my ( $self, %args ) = @_;
    my $slot_key = $args{'slot_key'} or return;

    my $map_set_id = $self->{'scaffold'}{$slot_key}{'map_set_id'};

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
sub detach_slot_from_parent {

=pod

=head2 detach_slot_from_parent

=cut

    my ( $self, %args ) = @_;
    my $slot_key = $args{'slot_key'} or return;

    $self->{'scaffold'}{$slot_key}{'attached_to_parent'} = 0;
    $self->{'slot_layout'}{$slot_key}{'changed'}         = 1;

    add_slot_separator( slot_layout => $self->{'slot_layout'}{$slot_key}, );

    return;
}

# ----------------------------------------------------
sub attach_slot_to_parent {

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
sub modify_panel_bottom_bound {

=pod

=head2 modify_panel_bottom_bound

Changes the hight of the panel

If bounds_change is given, it will change the y2 value of 'bounds'.

=cut

    my ( $self, %args ) = @_;
    my $panel_key = $args{'panel_key'} or return;
    my $bounds_change = $args{'bounds_change'} || 0;

    $self->{'panel_layout'}{$panel_key}{'bounds'}[3] += $bounds_change;
    $self->{'panel_layout'}{$panel_key}{'changed'} = 1;

    return;
}

# ----------------------------------------------------
sub modify_slot_bottom_bound {

=pod

=head2 modify_slot_bottom_bound

Changes the hight of the slot

If bounds_change is given, it will change the y2 value of 'bounds'.


=cut

    my ( $self, %args ) = @_;
    my $slot_key = $args{'slot_key'} or return;
    my $bounds_change = $args{'bounds_change'} || 0;

    $self->{'slot_layout'}{$slot_key}{'bounds'}[3] += $bounds_change;
    $self->{'slot_layout'}{$slot_key}{'changed'} = 1;

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
        bounds      => [ 0, 0, 0, 0 ],
        coords      => [ 0, 0, 0, 0 ],
        buttons     => [],
        features    => {},
        items       => [],
        changed     => 1,
        sub_changed => 1,
        row_index   => undef,
    };

    return;
}

# ----------------------------------------------------
sub initialize_slot_layout {

=pod

=head2 initialize_slot_layout

Initializes slot_layout

=cut

    my $self     = shift;
    my $slot_key = shift;

    $self->{'slot_layout'}{$slot_key} = {
        bounds      => [ 0, 0, 0, 0 ],
        separator   => [],
        background  => [],
        buttons     => [],
        changed     => 1,
        sub_changed => 1,
    };

    return;
}

# ----------------------------------------------------
sub initialize_panel_layout {

=pod

=head2 initialize_panel_layout

Initializes panel_layout

=cut

    my $self      = shift;
    my $panel_key = shift;

    $self->{'panel_layout'}{$panel_key} = {
        bounds      => [ 0, 0, 0, 0 ],
        misc_items  => [],
        buttons     => [],
        changed     => 1,
        sub_changed => 1,
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
    my $panel_key  = $args{'panel_key'}  or return;

    my $top_slot_key = $self->{'overview'}{$panel_key}{'slot_key'};

    # Destroy slot information and drawings
    foreach my $slot_key ( $top_slot_key,
        @{ $self->{'overview_layout'}{$panel_key}{'child_slot_order'} } )
    {
        foreach my $map_key (
            keys %{
                $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key}
                    {'maps'} || {}
            }
            )
        {
            $self->destroy_items(
                panel_key => $panel_key,
                items     =>
                    $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key}
                    {'maps'}{$map_key}{'items'},
                is_overview => 1,
            );
        }
        foreach my $item_name (qw[ misc_items viewed_region ]) {
            $self->destroy_items(
                panel_key => $panel_key,
                items     =>
                    $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key}
                    {$item_name},
                is_overview => 1,
            );
        }
        delete $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key};
    }

    # Destroy overview itself
    $self->destroy_items(
        panel_key   => $panel_key,
        items       => $self->{'overview_layout'}{$panel_key}{'misc_items'},
        is_overview => 1,
    );
    delete $self->{'overview_layout'}{$panel_key};

    # Recreate Overveiw
    $self->initialize_overview_layout($panel_key);

    layout_overview(
        window_key       => $window_key,
        panel_key        => $panel_key,
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

    my $self      = shift;
    my $panel_key = shift;

    my $top_slot_key = $self->{'overview'}{$panel_key}{'slot_key'};

    $self->{'overview_layout'}{$panel_key} = {
        bounds           => [ 0, 0, 0, 0 ],
        misc_items       => [],
        buttons          => [],
        changed          => 1,
        sub_changed      => 1,
        slots            => {},
        child_slot_order => [],
    };

    # Create an ordered list of the slots in the overview.
    my %child_slots;
    foreach my $child_slot_key (
        @{ $self->{'scaffold'}{$top_slot_key}{'children'} || [] } )
    {
        $child_slots{$child_slot_key} = 1;
    }
    foreach
        my $ordered_slot_key ( @{ $self->{'slot_order'}{$panel_key} || [] } )
    {
        if ( $child_slots{$ordered_slot_key} ) {
            push @{ $self->{'overview_layout'}{$panel_key}
                    {'child_slot_order'} }, $ordered_slot_key;
        }
    }

    foreach my $slot_key ( $top_slot_key,
        @{ $self->{'overview_layout'}{$panel_key}{'child_slot_order'} } )
    {
        $self->initialize_overview_slot_layout( $panel_key, $slot_key, );
    }

    return;
}

# ----------------------------------------------------
sub initialize_overview_slot_layout {

=pod

=head2 initialize_overview_slot_layout

Initializes overview_layout

=cut

    my $self      = shift;
    my $panel_key = shift;
    my $slot_key  = shift;

    $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key} = {
        bounds                 => [ 0, 0, 0, 0 ],
        misc_items             => [],
        buttons                => [],
        viewed_region          => [],
        changed                => 1,
        sub_changed            => 1,
        maps                   => {},
        scale_factor_from_main => 0,
    };
    foreach my $map_key ( @{ $self->{'map_order'}{$slot_key} || [] } ) {
        $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key}{'maps'}
            {$map_key} = {
            items   => [],
            changed => 1,
            };
    }

    return;
}

# ----------------------------------------------------
sub copy_slot_scaffold {

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
        map_set_id  window_key  panel_key
        children
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
        title  => $title,
        height => 0,
        width  => 0,
    };

}

# ----------------------------------------------------
sub clear_slot_maps {

=pod

=head2 clear_slot_maps

Clears a slot of map data and calls on the interface to remove the drawings.

=cut

    my ( $self, %args ) = @_;
    my $panel_key = $args{'panel_key'} or return;
    my $slot_key  = $args{'slot_key'}  or return;

    delete $self->{'slot_info'}{$slot_key};
    foreach my $map_key ( @{ $self->{'map_order'}{$slot_key} || [] } ) {
        foreach my $feature_acc (
            keys %{ $self->{'map_layout'}{$map_key}{'features'} || {} } )
        {
            $self->destroy_items(
                items =>
                    $self->{'map_layout'}{$map_key}{'features'}{$feature_acc}
                    {'items'},
                panel_key => $panel_key,
            );
        }
        $self->destroy_items(
            items     => $self->{'map_layout'}{$map_key}{'items'},
            panel_key => $panel_key,
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
    my $panel_key  = $args{'panel_key'}  or return;
    my $slot_key1  = $args{'slot_key'}   or return;

    # Record the current corrs
    foreach my $slot_key2 (
        keys %{ $self->{'correspondences_on'}{$slot_key1} || {} } )
    {
        if ( $self->{'correspondences_on'}{$slot_key1}{$slot_key2} ) {
            push @{ $self->{'correspondences_hidden'}{$slot_key1} },
                $slot_key2;
            $self->clear_slot_corrs(
                panel_key => $panel_key,
                slot_key1 => $slot_key1,
                slot_key2 => $slot_key2,
            );
        }
    }

    foreach my $child_slot_key (
        @{ $self->{'scaffold'}{$slot_key1}{'children'} || [] } )
    {
        if ( $self->{'scaffold'}{$child_slot_key}{'attached_to_parent'} ) {
            $self->hide_corrs(
                window_key => $window_key,
                panel_key  => $panel_key,
                slot_key   => $child_slot_key,
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
    my $panel_key  = $args{'panel_key'}  or return;
    my $slot_key1  = $args{'slot_key'}   or return;

    return unless ( $self->{'correspondences_hidden'} );

    foreach my $slot_key2 (
        @{ $self->{'correspondences_hidden'}{$slot_key1} || {} } )
    {
        delete $self->{'correspondences_hidden'}{$slot_key1};
        $self->add_slot_corrs(
            window_key => $window_key,
            panel_key  => $panel_key,
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
                panel_key  => $panel_key,
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
    my $slot_key        = $self->{'map_key_to_slot_key'}{$map_key};
    my $window_key      = $self->{'scaffold'}{$slot_key}{'window_key'};
    my $parent_slot_key = $self->{'scaffold'}{$slot_key}{'parent'};
    my $old_map_coords  = $self->{'map_layout'}{$map_key}{'coords'};
    my $dx              = $ghost_bounds->[0] - $old_map_coords->[0];

    # Get Parent
    my $new_parent_map_key;
    my $parent_coords;
    foreach my $potential_parent_map_key (
        @{ $self->{'map_order'}{$parent_slot_key} || [] } )
    {
        my $coords
            = $self->{'map_layout'}{$potential_parent_map_key}{'coords'};
        if (    $coords->[0] <= $ghost_bounds->[0]
            and $coords->[2] >= $ghost_bounds->[2] )
        {
            $new_parent_map_key = $potential_parent_map_key;
            $parent_coords      = $coords;
            last;
        }
    }

    # Get location on parent
    # Use start location as basis for locating
    my $relative_pixel_start = $ghost_bounds->[0] - $parent_coords->[0];

    my $relative_unit_start = $relative_pixel_start /
        (      $self->{'map_pixels_per_unit'}{$new_parent_map_key}
            || $self->{'scaffold'}{$parent_slot_key}{'pixels_per_unit'} );
    my $parent_map_data = $self->app_data_module()
        ->map_data( map_id => $self->{'map_key_to_id'}{$map_key}, );

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
    my $slot_key           = $self->{'map_key_to_slot_key'}{$map_key};
    my $window_key         = $self->{'scaffold'}{$slot_key}{'window_key'};

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

    return;

}

# ----------------------------------------------------
sub move_map_old {

=pod

=head2 move_map

Move a map from one place on a parent to another

=cut

    my ( $self, %args ) = @_;
    my $map_key         = $args{'map_key'};
    my $ghost_bounds    = $args{'ghost_bounds'};
    my $slot_key        = $self->{'map_key_to_slot_key'}{$map_key};
    my $window_key      = $self->{'scaffold'}{$slot_key}{'window_key'};
    my $parent_slot_key = $self->{'scaffold'}{$slot_key}{'parent'};
    my $old_map_coords  = $self->{'map_layout'}{$map_key}{'coords'};
    my $dx              = $ghost_bounds->[0] - $old_map_coords->[0];

    # Get Parent
    my $new_parent_map_key;
    my $parent_coords;
    foreach my $potential_parent_map_key (
        @{ $self->{'map_order'}{$parent_slot_key} || [] } )
    {
        my $coords
            = $self->{'map_layout'}{$potential_parent_map_key}{'coords'};
        if (    $coords->[0] <= $ghost_bounds->[0]
            and $coords->[2] >= $ghost_bounds->[2] )
        {
            $new_parent_map_key = $potential_parent_map_key;
            $parent_coords      = $coords;
            last;
        }
    }

    # Get location on parent
    # Use start location as basis for locating
    my $relative_pixel_start = $ghost_bounds->[0] - $parent_coords->[0];

    my $relative_unit_start = $relative_pixel_start /
        (      $self->{'map_pixels_per_unit'}{$new_parent_map_key}
            || $self->{'scaffold'}{$parent_slot_key}{'pixels_per_unit'} );
    my $parent_map_data = $self->app_data_module()
        ->map_data( map_id => $self->{'map_key_to_id'}{$map_key}, );
    my $new_feature_start
        = $relative_unit_start + $parent_map_data->{'map_start'};
    my $new_feature_stop
        = $new_feature_start - $self->{'sub_maps'}{$map_key}{'feature_start'}
        + $self->{'sub_maps'}{$map_key}{'feature_stop'};

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

    my $sub_slot_key    = $self->{'map_key_to_slot_key'}{$sub_map_key};
    my $window_key      = $self->{'scaffold'}{$sub_slot_key}{'window_key'};
    my $panel_key       = $self->{'scaffold'}{$sub_slot_key}{'panel_key'};
    my $parent_slot_key = $self->{'scaffold'}{$sub_slot_key}{'parent'};

    # Modify Parent
    $self->{'sub_maps'}{$sub_map_key}{'parent_map_key'} = $parent_map_key;
    $self->{'sub_maps'}{$sub_map_key}{'feature_start'}  = $feature_start;
    $self->{'sub_maps'}{$sub_map_key}{'feature_stop'}   = $feature_stop;

    $self->cascade_relayout_sub_map_slot(
        window_key => $window_key,
        panel_key  => $panel_key,
        slot_key   => $sub_slot_key,
    );

    return;
}

# ----------------------------------------------------
sub cascade_relayout_sub_map_slot {

=pod

=head2 relayout_sub_map_slot

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $panel_key  = $args{'panel_key'}  or return;
    my $slot_key   = $args{'slot_key'}   or return;
    my $cascading = $args{'cascading'} || 0;

    # relayout the sub map
    $self->relayout_sub_map_slot(
        window_key => $window_key,
        panel_key  => $panel_key,
        slot_key   => $slot_key,
    );

    # cascade to attached children
    foreach my $child_slot_key (
        @{ $self->{'scaffold'}{$slot_key}{'children'} || [] } )
    {
        next
            unless (
            $self->{'scaffold'}{$child_slot_key}{'attached_to_parent'} );

        $self->cascade_relayout_sub_map_slot(
            window_key => $window_key,
            panel_key  => $panel_key,
            slot_key   => $child_slot_key,
            cascading  => 1,
        );
    }

    # Finish by drawing the panel
    unless ($cascading) {
        $self->{'panel_layout'}{$panel_key}{'sub_changed'} = 1;
        $self->app_interface()->draw_panel(
            panel_key        => $panel_key,
            window_key       => $window_key,
            app_display_data => $self,
        );
    }

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

    unless ( @{ $self->{'window_actions'}{$window_key}{'actions'} || [] } ) {
        return;
    }

    my $last_action_index
        = $self->{'window_actions'}{$window_key}{'last_action_index'};
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
sub move_ghost_map {

=pod

=head2 move_ghost

Controls how the ghost map moves.

=cut

    my ( $self, %args ) = @_;
    my $map_key         = $args{'map_key'};
    my $mouse_x         = $args{'mouse_x'};
    my $ghost_bounds    = $args{'ghost_bounds'};
    my $mouse_to_edge_x = $args{'mouse_to_edge_x'};

    my $slot_key        = $self->{'map_key_to_slot_key'}{$map_key};
    my $parent_slot_key = $self->{'scaffold'}{$slot_key}{'parent'};

    # If no parent, don't let it move.
    unless ($parent_slot_key
        and $self->{'scaffold'}{$slot_key}{'attached_to_parent'} )
    {
        return 0;
    }

    my $new_x1 = $mouse_x - $mouse_to_edge_x;
    my $new_x2 = $new_x1 + ( $ghost_bounds->[2] - $ghost_bounds->[0] + 1 );
    my $dx     = ( $mouse_x - $mouse_to_edge_x ) - $ghost_bounds->[0];
    my $slot_coverage = $self->{'slot_coverage'}{$parent_slot_key};

    my $ghost_is_before_index = 0;
    my $ghost_is_after_index  = 0;
    my $ghost_is_covered      = 0;
    my $index                 = 0;
COVERAGE_LOOP:
    for ( my $i = 0; $i <= $#{$slot_coverage}; $i++ ) {
        if ( $new_x1 < $slot_coverage->[$i][0] ) {
            $ghost_is_before_index = 1;
            $index                 = $i;
            last COVERAGE_LOOP;
        }
        elsif ( $new_x2 < $slot_coverage->[$i][1] ) {

            # Covered
            $ghost_is_covered = 1;
            last COVERAGE_LOOP;
        }
        elsif ( $new_x1 < $slot_coverage->[$i][1]
            and $new_x2 > $slot_coverage->[$i][1] )
        {
            $ghost_is_after_index = 1;
            $index                = $i;
            last COVERAGE_LOOP;
        }
    }

    # each case is handled separately since the behaviors may be different in
    # the future and I don't want to have to figure out how to separate the
    # cases then.

    if ($ghost_is_covered) {

        # Ghost is on a map
        return $dx;
    }
    elsif ( $ghost_is_before_index and $index == 0 ) {

        # Before begining of all maps
        return $slot_coverage->[$index][0] - $ghost_bounds->[0];
    }
    elsif ($ghost_is_before_index) {

        # Ghost is between maps
        return $slot_coverage->[$index][0] - $ghost_bounds->[0];
    }
    elsif ( $ghost_is_after_index and $index == $#{$slot_coverage} ) {

        # After end of all maps (but overlapping the last map)
        return $slot_coverage->[$index][1] - $ghost_bounds->[2];
    }
    elsif ($ghost_is_after_index) {

        # Ghost is between maps
        return $slot_coverage->[$index][1] - $ghost_bounds->[2];
    }
    else {

        # After end of all maps
        return $slot_coverage->[-1][1] - $ghost_bounds->[2];
    }

    return $dx;
}

# ----------------------------------------------------
sub clear_slot_corrs {

=pod

=head2 clear_slot_corrs

Clears a slot of correspondences and calls on the interface to remove the drawings.

=cut

    my ( $self, %args ) = @_;
    my $panel_key = $args{'panel_key'} or return;
    my $slot_key1 = $args{'slot_key1'} or return;
    my $slot_key2 = $args{'slot_key2'} or return;

    $self->{'correspondences_on'}{$slot_key1}{$slot_key2} = 0;
    $self->{'correspondences_on'}{$slot_key2}{$slot_key1} = 0;
    my %slot2_maps;
    map { $slot2_maps{$_} = 1 } @{ $self->{'map_order'}{$slot_key2} || [] };

    foreach my $map_key1 ( @{ $self->{'map_order'}{$slot_key1} || [] } ) {
        foreach my $map_key2 (
            keys %{ $self->{'corr_layout'}{'maps'}{$map_key1} || {} } )
        {
            next unless ( $slot2_maps{$map_key2} );
            $self->destroy_items(
                items => $self->{'corr_layout'}{'maps'}{$map_key1}{$map_key2}
                    {'items'},
                panel_key => $panel_key,
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
sub add_slot_corrs {

=pod

=head2 add_slot_corrs

Adds a slot of correspondences

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $panel_key  = $args{'panel_key'}  or return;
    my $slot_key1  = $args{'slot_key1'}  or return;
    my $slot_key2  = $args{'slot_key2'}  or return;

    $self->{'correspondences_on'}{$slot_key1}{$slot_key2} = 1;
    $self->{'correspondences_on'}{$slot_key2}{$slot_key1} = 1;

    add_correspondences(
        window_key       => $window_key,
        panel_key        => $panel_key,
        slot_key1        => $slot_key1,
        slot_key2        => $slot_key2,
        app_display_data => $self,
    );
    $self->app_interface()->draw_corrs(
        panel_key        => $panel_key,
        app_display_data => $self,
    );

    return;
}

# ----------------------------------------------------
sub reset_slot_corrs {

=pod

=head2 reset_slot_corrs

reset  a slot of correspondences

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $panel_key  = $args{'panel_key'}  or return;
    my $slot_key1  = $args{'slot_key'}   or return;

    foreach my $slot_key2 (
        keys %{ $self->{'correspondences_on'}{$slot_key1} || {} } )
    {
        next unless ( $self->{'correspondences_on'}{$slot_key1}{$slot_key2} );

        $self->clear_slot_corrs(
            panel_key => $panel_key,
            slot_key1 => $slot_key1,
            slot_key2 => $slot_key2,
        );
        $self->add_slot_corrs(
            window_key => $window_key,
            panel_key  => $panel_key,
            slot_key1  => $slot_key1,
            slot_key2  => $slot_key2,
        );
    }

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
    my $panel_key   = $args{'panel_key'};
    my $items       = $args{'items'};
    my $is_overview = $args{'is_overview'};

    $self->app_interface()->int_destroy_items(
        panel_key   => $panel_key,
        items       => $items,
        is_overview => $is_overview,
    );
}

# ----------------------------------------------------
sub delete_slot {

=pod

=head2 delete_slot

Deletes the slot data and wipes them from the canvas

=cut

    my ( $self, %args ) = @_;
    my $panel_key = $args{'panel_key'};
    my $slot_key  = $args{'slot_key'};

    my $slot_layout = $self->{'slot_layout'}{$slot_key};

    # Remove correspondences
    foreach
        my $slot_key2 ( keys %{ $self->{'correspondences_on'}{$slot_key} } )
    {
        $self->clear_slot_corrs(
            panel_key => $panel_key,
            slot_key1 => $slot_key,
            slot_key2 => $slot_key2,
        );
    }

    # Remove Drawing info
    foreach my $drawing_item_name (qw[ separator background ]) {
        $self->destroy_items(
            panel_key => $panel_key,
            items     => $slot_layout->{$drawing_item_name},
        );
    }

    foreach my $map_key ( @{ $self->{'map_order'}{$slot_key} || [] } ) {
        ### Someday Add a delet_map method
    }

    # Remove from parent
    my $parent_slot_key = $self->{'scaffold'}{$slot_key}{'parent'};
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

    # Remove from slot_order if it hasn't already been done
    for (
        my $i = 0;
        $i <= $#{ $self->{'slot_order'}{$panel_key} || [] };
        $i++
        )
    {
        if ( $slot_key == $self->{'slot_order'}{$panel_key}[$i] ) {
            splice @{ $self->{'slot_order'}{$panel_key} }, $i, 1;
            last;
        }
    }

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

    foreach my $panel_key ( @{ $self->{'panel_order'}{$window_key} || [] } ) {
        foreach my $slot_key ( @{ $self->{'slot_order'}{$panel_key} || [] } )
        {
            foreach my $map_key ( @{ $self->{'map_order'}{$slot_key} || [] } )
            {
                foreach my $feature_acc (
                    keys %{ $self->{'map_layout'}{$map_key}{'features'}
                            || {} } )
                {
                    $self->destroy_items(
                        items => $self->{'map_layout'}{$map_key}{'features'}
                            {$feature_acc}{'items'},
                        panel_key => $panel_key,
                    );
                    $self->{'map_layout'}{$map_key}{'features'}{$feature_acc}
                        {'items'} = [];
                }
                $self->{'map_pixels_per_unit'}{$map_key} = undef;
                $self->{'map_layout'}{$map_key}{'bounds'} = [ 0, 0, 0, 0 ];
                $self->{'map_layout'}{$map_key}{'coords'} = [ 0, 0, 0, 0 ];
                $self->destroy_items(
                    items     => $self->{'map_layout'}{$map_key}{'items'},
                    panel_key => $panel_key,
                );
                $self->{'map_layout'}{$map_key}{'items'} = [];
                if ( $self->{'corr_layout'}{'maps'}{$map_key} ) {
                    $self->destroy_items(
                        items =>
                            $self->{'corr_layout'}{'maps'}{$map_key}{'items'},
                        panel_key => $panel_key,
                    );
                    $self->{'corr_layout'}{'maps'}{$map_key}{'items'} = [];
                }
            }
            $self->{'slot_layout'}{$slot_key}{'bounds'}     = [ 0, 0, 0, 0 ];
            $self->{'slot_layout'}{$slot_key}{'maps_min_x'} = undef;
            $self->{'slot_layout'}{$slot_key}{'maps_max_x'} = undef;
            foreach my $field (qw[ separator background ]) {
                $self->destroy_items(
                    items     => $self->{'slot_layout'}{$slot_key}{$field},
                    panel_key => $panel_key,
                );
                $self->{'slot_layout'}{$slot_key}{$field} = [];
            }
        }
        $self->{'panel_layout'}{$panel_key}{'bounds'} = [ 0, 0, 0, 0 ];
        $self->destroy_items(
            items     => $self->{'panel_layout'}{$panel_key}{'misc_items'},
            panel_key => $panel_key,
        );
        $self->{'panel_layout'}{$panel_key}{'misc_items'} = [];

        # Overview
        $self->{'overview_layout'}{$panel_key}{'bounds'} = [ 0, 0, 0, 0 ];
        $self->destroy_items(
            items     => $self->{'overview_layout'}{$panel_key}{'misc_items'},
            panel_key => $panel_key,
            is_overview => 1,
        );
        $self->{'overview_layout'}{$panel_key}{'misc_items'} = [];
        foreach my $slot_key (
            keys %{ $self->{'overview_layout'}{$panel_key}{'slots'} || {} } )
        {
            $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key}
                {'bounds'} = [ 0, 0, 0, 0 ];
            $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key}
                {'scale_factor_from_main'} = 0;
            foreach my $field (qw[ viewed_region misc_items ]) {
                $self->destroy_items(
                    items => $self->{'overview_layout'}{$panel_key}{'slots'}
                        {$slot_key}{$field},
                    panel_key   => $panel_key,
                    is_overview => 1,
                );
                $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key}
                    {$field} = [];
            }

            foreach my $map_key (
                keys %{
                    $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key}
                        {'maps'} || {}
                }
                )
            {
                $self->destroy_items(
                    items => $self->{'overview_layout'}{$panel_key}{'slots'}
                        {$slot_key}{'maps'}{$map_key}{'items'},
                    panel_key   => $panel_key,
                    is_overview => 1,
                );
                $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key}
                    {'maps'}{$map_key}{'items'} = [];
            }
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

    foreach my $panel_key ( @{ $self->{'panel_order'}{$window_key} || [] } ) {
        foreach my $slot_key ( @{ $self->{'slot_order'}{$panel_key} || [] } )
        {
            foreach my $map_key ( @{ $self->{'map_order'}{$slot_key} || [] } )
            {
                delete $self->{'map_id_to_keys'}
                    { $self->{'map_key_to_id'}{$map_key} };
                delete $self->{'map_key_to_id'}{$map_key};
                delete $self->{'map_layout'}{$map_key};
            }
            delete $self->{'slot_layout'}{$slot_key};
            delete $self->{'scaffold'}{$slot_key};
            delete $self->{'map_order'}{$slot_key};
            delete $self->{'slot_info'}{$slot_key};
            delete $self->{'map_id_to_key_by_slot'}{$slot_key};
        }
        delete $self->{'panel_layout'}{$panel_key};
        delete $self->{'slot_order'}{$panel_key};
        delete $self->{'overview'}{$panel_key};
        delete $self->{'overview_layout'}{$panel_key};
    }
    delete $self->{'panel_order'}{$window_key};

    delete $self->{'sub_maps'}{$window_key};

    return scalar( keys %{ $self->{'scaffold'} || {} } );
}

# ----------------------------------------------------
sub get_map_ids {

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

Set when correspondences are on on between two slots.  Both directions are
stored.

    $self->{'correspondences_on'} = { 
        $slot_key1 => { 
            $slot_key2 => 1,
        } 
    }

=head3 Pixels Per Unit for each map

This is a conversion factor to get from map units to pixels.

    $self->{'map_pixels_per_unit'} = {
        $map_key => $pixels_per_unit,
    }

=head2 Map ID and Key Translators

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
    $self->{'map_order'} = {
        $slot_key => [ $map_key, ]
    }

=head3 Slot Order in Panel
    $self->{'slot_order'} = {
        $panel_key => [ $slot_key, ]
    }

=head3 Panel Order in Window
    $self->{'panel_order'} = {
        $window_key => [ $panel_key, ]
    }

=head2 Scaffold Stuff

=head3 Overview Slot Info

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
            panel_key          => $panel_key,
            map_set_id         => undef,
            parent             => $parent_slot_key,
            children           => [$child_slot_key, ],
            scale              => 1,
            x_offset           => 0,
            attached_to_parent => 1,
            expanded           => 0,
            is_top             => 0,
            pixels_per_unit    => 0,
        }
    }

=head2 Stored Bio Data

=head3 Slot Info

Slot info is needed for correspondence finding.  It stores the visible region
of each map in the slot and this gets passed to the slot_correspondences()
method in AppData.

    $self->{'slot_info'} = {
        $slot_key => {
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

    $self->{'window_layout'} = {
        $window_key => {
            title  => $title,
            height => $height,
            width  => $width,
        }
    }

=head3 Panel Layout

    $self->{'panel_layout'} = {
        $panel_key => {
            bounds      => [ 0, 0, 0, 0 ],
            misc_items  => [],
            buttons     => [],
            changed     => 1,
            sub_changed => 1,
        }
    }

=head3 Slot Layout

    $self->{'slot_layout'} = {
        $slot_key => {
            bounds      => [ 0, 0, 0, 0 ],
            separator   => [],
            background  => [],
            buttons     => [],
            changed     => 1,
            sub_changed => 1,
            maps_min_x  => $maps_min_x,
            maps_max_x  => $maps_max_x,
        }
    }

=head3 Map Layout

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

    $self->{'overview_layout'} = {
        $panel_key => {
            bounds           => [ 0, 0, 0, 0 ],
            misc_items       => [],
            buttons          => [],
            changed          => 1,
            sub_changed      => 1,
            child_slot_order => [ $child_slot_key, ],
            slots            => {
                $slot_key => {
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

=head3 selected_slot_key

    $self->{'selected_slot_key'} = $slot_key;

=head3 next_map_set_color_index

The next index for the background color array.

    $self->{'next_map_set_color_index'} = 0;

=head1 SEE ALSO

L<perl>, L<GD>, L<GD::SVG>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-5 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

