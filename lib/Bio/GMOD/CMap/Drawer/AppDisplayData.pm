package Bio::GMOD::CMap::Drawer::AppDisplayData;

# vim: set ft=perl:

# $Id: AppDisplayData.pm,v 1.12 2006-09-12 15:10:32 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.12 $)[-1];

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
use Data::Dumper;
use base 'Bio::GMOD::CMap';

# ----------------------------------------------------
sub init {

=pod

=head2 init

Initializes the drawing object.

=cut

    my ( $self, $config ) = @_;

    for my $param (qw[ data_source config app_interface app_data_module ]) {
        $self->$param( $config->{$param} )
            or die "Failed to pass $param to AppDisplayData\n";
    }
    $self->{'next_map_set_color_index'}=0;

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
        $self->{'map_key_to_id'}{$map_key} = $map_id;
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

    $self->app_interface()->int_create_slot_controls(
        window_key       => $window_key,
        panel_key        => $panel_key,
        app_display_data => $self,
    );

    $self->app_interface()->draw_panel(
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
        push @new_slot_keys,$child_slot_key;
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
                parent_key => $slot_scaffold->{'parent'},
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
                    parent_key => $slot_scaffold->{'parent'},
                );
            }
            else {

                # Reset correspondences
                $self->reset_slot_corrs(
                    window_key => $window_key,
                    panel_key  => $panel_key,
                    slot_key1  => $slot_key,
                    slot_key2  => $slot_scaffold->{'parent'},
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
            parent_key => $slot_scaffold->{'parent'},
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
            app_display_data => $self,
        );
    }
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
                parent_key => $slot_scaffold->{'parent'},
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
                    parent_key => $slot_scaffold->{'parent'},
                );
            }
            else {

                # Reset correspondences
                $self->reset_slot_corrs(
                    window_key => $window_key,
                    panel_key  => $panel_key,
                    slot_key1  => $slot_key,
                    slot_key2  => $slot_scaffold->{'parent'},
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
            parent_key => $slot_scaffold->{'parent'},
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
    my @corresponding_slot_keys = keys %{$self->{'correspondences_on'}{$old_slot_key}};

    unless ( defined $old_slot_order_pos ) {
        die "Slot Order position not found for slot $old_slot_key\n";
    }
    my $old_slot_y1 = $old_slot_layout->{'bounds'}[1];
    my $old_slot_y2 = $old_slot_layout->{'bounds'}[3];

    my $start_min_y   = $old_slot_y1;
    my $slot_buffer_y = 15;
    my $slot_position = $old_slot_order_pos;
    foreach my $row_index ( sort {$a <=> $b } keys %row_index_maps ) {
        # Create Slot
        my $new_slot_key = $self->next_internal_key('slot');
        $self->initialize_slot_layout($new_slot_key);

        #Copy important slot info
        $self->copy_slot_scaffold(
            old_slot_key => $old_slot_key,
            new_slot_key => $new_slot_key,
        );

        # Add as child of parent
        push @{$self->{'scaffold'}{$parent_slot_key}{'children'}},$new_slot_key;

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

        $start_min_y = $self->{'slot_layout'}{$new_slot_key}{'bounds'}[3] + $slot_buffer_y;

        # Add Sub Slots
        my $sub_slot_keys = $self->add_sub_maps(
            window_key       => $window_key,
            panel_key        => $panel_key,
            parent_slot_key  => $new_slot_key,
            slot_order_array => \@slot_order_insert,
        );

        foreach my $sub_slot_key (@$sub_slot_keys){
            $slot_position++;
            layout_new_slot(
                window_key       => $window_key,
                panel_key        => $panel_key,
                slot_key         => $sub_slot_key,
                slot_position    => $slot_position,
                start_min_y      => $start_min_y,
                app_display_data => $self,
            );
            $start_min_y = $self->{'slot_layout'}{$sub_slot_key}{'bounds'}[3] + $slot_buffer_y;
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
    foreach my $slot_key (@slot_order_insert){
        $self->app_interface()->add_slot_controls(
            window_key       => $window_key,
            panel_key        => $panel_key,
            slot_key         => $slot_key,
            app_display_data => $self,
        );
    }

    $self->app_interface()->draw_panel(
        panel_key        => $panel_key,
        app_display_data => $self,
    );

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
    my $parent_key = $args{'parent_key'} or return;

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
        slot_key1  => $slot_key,
        slot_key2  => $parent_key,
    );

    return;
}

# ----------------------------------------------------
sub change_selected_slot {

=pod

=head2 change_selected_slot

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $panel_key  = $args{'panel_key'}  or return;
    my $slot_key   = $args{'slot_key'}   or return;

    my $old_selected_slot_key = $self->{'selected_slot_key'};
    $self->{'selected_slot_key'} = $slot_key;

    if ($old_selected_slot_key and $self->{'scaffold'}{$old_selected_slot_key}) {
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
    my $slot_key   = $args{'slot_key'}   or return;

    my $map_set_id = $self->{'scaffold'}{$slot_key}{'map_set_id'};

    unless ( $self->{'map_set_bgcolor'} and $self->{'map_set_bgcolor'}{$map_set_id} ) {

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
        row_index   => 0,
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
    my $panel_key = $args{'panel_key'} or return;

    my $top_slot_key = $self->{'overview'}{$panel_key}{'slot_key'};

    # Destroy slot information and drawings
    foreach my $slot_key ( $top_slot_key,
        @{ $self->{'overview_layout'}{$panel_key}{'child_slot_order'} } )
    {
        foreach my $map_key (
            keys %{ $self->{'overview_layout'}{$panel_key}{'slots'}{$slot_key}{'maps'} || {} } )
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
        panel_key => $panel_key,
        items     =>
            $self->{'overview_layout'}{$panel_key}{'misc_items'},
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
        $self->initialize_overview_slot_layout($panel_key, $slot_key,);
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

    $self->{'window_layout'}{$window_key} = { title => $title, };

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
    my $slot_key1  = $args{'slot_key1'}  or return;
    my $slot_key2  = $args{'slot_key2'}  or return;

    return unless ( $self->{'correspondences_on'}{$slot_key1}{$slot_key2} );

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
    foreach my $slot_key2 (keys %{$self->{'correspondences_on'}{$slot_key}}){
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
            title => $title,
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
            row_index => 0,
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

