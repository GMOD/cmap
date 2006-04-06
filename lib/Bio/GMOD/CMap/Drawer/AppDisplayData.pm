package Bio::GMOD::CMap::Drawer::AppDisplayData;

# vim: set ft=perl:

# $Id: AppDisplayData.pm,v 1.3 2006-04-06 00:37:04 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.3 $)[-1];

use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Drawer::AppLayout
    qw[ layout_new_panel layout_new_window ];
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
sub load_first_slot_of_window {

=pod

=head2 load_first_slot_of_window

Adds the first slot

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $map_ids    = $args{'map_ids'};

    # Remove old info if any 
    if ($self->{'scaffold'}{$window_key}){
        $self->clear_window(window_key=>$window_key,);
    }

    my $panel_key = $self->next_internal_key('panel');
    my $slot_key  = $self->next_internal_key('slot');

    $self->{'panel_order'}{$window_key} = [ $panel_key, ];
    $self->{'slot_order'}{$panel_key}   = [ $slot_key, ];

    $self->{'scaffold'}{$window_key}{$panel_key}{$slot_key} = {
        parent             => undef,
        children           => [],
        scale              => 1,
        attached_to_parent => 0,
        expanded           => 1,
        is_top             => 1,
    };

    my $map_data
        = $self->app_data_module()->map_data_array( map_ids => $map_ids, );

    $self->{'window_layout'}{$window_key} = {
        bounds           => [ 0, 0, 0, 0 ],
        container_bounds => [ 0, 0, 0, 0 ],
        misc_items       => [],
        buttons          => [],
        changed          => 1,
        sub_changed      => 1,
    };
    $self->{'panel_layout'}{$panel_key} = {
        bounds           => [ 0, 0, 0, 0 ],
        container_bounds => [ 0, 0, 0, 0 ],
        misc_items       => [],
        buttons          => [],
        changed          => 1,
        sub_changed      => 1,
    };
    $self->{'slot_layout'}{$slot_key} = {
        bounds           => [ 0, 0, 0, 0 ],
        container_bounds => [ 0, 0, 0, 0 ],
        misc_items       => [],
        buttons          => [],
        changed          => 1,
        sub_changed      => 1,
    };

    foreach my $map_id ( @{ $map_ids || [] } ) {
        my $map_key = $self->next_internal_key('map');
        push @{ $self->{'map_order'}{$slot_key} },   $map_key;
        push @{ $self->{'map_id_to_key'}{$map_id} }, $map_key;
        $self->{'map_key_to_id'}{$map_key} = $map_id;
        $self->{'map_layout'}{$map_key}    = {
            bounds  => [ 0, 0, 0, 0 ],
            buttons => [],
            items    => [],
            changed => 1,
        };
    }

    $self->add_sub_maps(
        window_key      => $window_key,
        panel_key       => $panel_key,
        parent_slot_key => $slot_key,
    );

    layout_new_window(
        window_key       => $window_key,
        app_display_data => $self,
    );

    $self->app_interface()->draw(
        window_key       => $window_key,
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

            push @{ $self->{'map_id_to_key'}{$sub_map_id} }, $sub_map_key;
            $self->{'map_key_to_id'}{$sub_map_key} = $sub_map_id;

            $self->{'sub_maps'}{$sub_map_key} = {
                parent_key    => $map_key,
                feature_start => $sub_map->{'feature_start'},
                feature_stop  => $sub_map->{'feature_stop'},
            };
            push @sub_map_keys, $sub_map_id;

        }
    }
    unless (@sub_map_keys) {

        # No Sub Maps
        return;
    }

    my $slot_order_index;
    for ( my $i = 0; $i <= $#{ $self->{'slot_order'}{$panel_key} }; $i++ ) {
        if ( $parent_slot_key == $self->{'slot_order'}{$panel_key}[$i] ) {
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

    foreach my $set_key ( keys %maps_by_set ) {
        my $child_slot_key = $self->next_internal_key('slot');
        $slot_order_index++;
        splice @{ $self->{'slot_order'}{$panel_key} }, $slot_order_index, 0,
            ($child_slot_key);

        $self->{'slot_layout'}{$child_slot_key} = {
            bounds           => [ 0, 0, 0, 0 ],
            container_bounds => [ 0, 0, 0, 0 ],
            misc_items       => [],
            buttons          => [],
            changed          => 1,
            sub_changed      => 1,
        };
        $self->{'scaffold'}{$window_key}{$panel_key}{$child_slot_key} = {
            parent             => $parent_slot_key,
            children           => [],
            scale              => 1,
            attached_to_parent => 1,
            expanded           => 0,
            is_top             => 0,
        };
        push @{ $self->{'scaffold'}{$window_key}{$panel_key}{$parent_slot_key}
                {'children'} }, $child_slot_key;

        foreach my $map_key ( @{ $maps_by_set{$set_key} || [] } ) {
            push @{ $self->{'map_order'}{$child_slot_key} }, $map_key;
            $self->{'map_layout'}{$map_key} = {
                bounds  => [ 0, 0, 0, 0 ],
                buttons => [],
                items   => [],
                changed => 1,
            };
        }
    }
}

# ----------------------------------------------------
sub modify_window_bottom_bound {

=pod

=head2 modify_window_bottom_bound

Changes the hight of the window

If bounds_change is given, it will change the y2 value of 'bounds'.

If container_change is given, it will change the y2 value of
'container_bounds'.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $bounds_change    = $args{'bounds_change'}    || 0;
    my $container_change = $args{'container_change'} || 0;

    $self->{'window_layout'}{$window_key}{'bounds'}[3] += $bounds_change;
    $self->{'window_layout'}{$window_key}{'container_bounds'}[3]
        += $container_change;
    $self->{'window_layout'}{$window_key}{'changed'} = 1;

    return;
}

# ----------------------------------------------------
sub modify_panel_bottom_bound {

=pod

=head2 modify_panel_bottom_bound

Changes the hight of the panel

If bounds_change is given, it will change the y2 value of 'bounds'.

If container_change is given, it will change the y2 value of
'container_bounds'.

=cut

    my ( $self, %args ) = @_;
    my $panel_key = $args{'panel_key'} or return;
    my $bounds_change    = $args{'bounds_change'}    || 0;
    my $container_change = $args{'container_change'} || 0;

    $self->{'panel_layout'}{$panel_key}{'bounds'}[3] += $bounds_change;
    $self->{'panel_layout'}{$panel_key}{'container_bounds'}[3]
        += $container_change;
    $self->{'panel_layout'}{$panel_key}{'changed'} = 1;

    return;
}

# ----------------------------------------------------
sub modify_slot_bottom_bound {

=pod

=head2 modify_slot_bottom_bound

Changes the hight of the slot

If bounds_change is given, it will change the y2 value of 'bounds'.

If container_change is given, it will change the y2 value of
'container_bounds'.

=cut

    my ( $self, %args ) = @_;
    my $slot_key = $args{'slot_key'} or return;
    my $bounds_change    = $args{'bounds_change'}    || 0;
    my $container_change = $args{'container_change'} || 0;

    $self->{'slot_layout'}{$slot_key}{'bounds'}[3] += $bounds_change;
    $self->{'slot_layout'}{$slot_key}{'container_bounds'}[3]
        += $container_change;
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

    $self->remove_window_data( window_key=>$window_key,);

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
            foreach
                my $map_key ( @{ $self->{'map_order'}{$panel_key} || [] } )
            {
                delete $self->{'map_id_to_key'}
                    { $self->{'map_key_to_id'}{$map_key} };
                delete $self->{'map_key_to_id'}{$map_key};
                delete $self->{'map_layout'}{$map_key};
            }
            delete $self->{'slot_layout'}{$slot_key};
            delete $self->{'map_order'}{$panel_key};
        }
        delete $self->{'panel_layout'}{$panel_key};
        delete $self->{'slot_order'}{$panel_key};
    }
    delete $self->{'panel_order'}{$window_key};

    delete $self->{'sub_maps'}{$window_key};
    delete $self->{'scaffold'}{$window_key};
    delete $self->{'window_layout'}{$window_key};

    return scalar( keys %{ $self->{'scaffold'} || {} } );
}

1;

# ----------------------------------------------------
# It is not all books that are as dull as their readers.
# Henry David Thoreau
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>, L<GD>, L<GD::SVG>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-5 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

