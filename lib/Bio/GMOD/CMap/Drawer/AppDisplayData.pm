package Bio::GMOD::CMap::Drawer::AppDisplayData;

# vim: set ft=perl:

# $Id: AppDisplayData.pm,v 1.1 2006-03-14 22:16:26 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.1 $)[-1];

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
    my $window_acc = $args{'window_acc'};
    my $map_accs   = $args{'map_accs'};

    # REMOVE OLD INFO XXX

    my $panel_acc = $self->next_panel_acc();
    my $slot_acc  = $self->next_slot_acc();

    $self->{'panel_order'}{$window_acc} = [ $panel_acc, ];
    $self->{'slot_order'}{$panel_acc}   = [ $slot_acc, ];

    $self->{'scaffold'}{$window_acc}{$panel_acc}{$slot_acc} = {
        parent       => undef,
        children     => [],
        scale2parent => 0,
        sub_maps     => 0,
        expanded     => 0,
        is_top       => 1,
    };

    my $map_data
        = $self->app_data_module()->map_data_array( map_accs => $map_accs, );

    $self->{'window_layout'}{$window_acc} = {
        bounds           => [ 0, 0, 0, 0 ],
        container_bounds => [ 0, 0, 0, 0 ],
        border           => [],
        buttons          => [],
        changed          => 1,
        sub_changed      => 1,
    };
    $self->{'panel_layout'}{$panel_acc} = {
        bounds           => [ 0, 0, 0, 0 ],
        container_bounds => [ 0, 0, 0, 0 ],
        border           => [],
        buttons          => [],
        changed          => 1,
        sub_changed      => 1,
    };
    $self->{'slot_layout'}{$slot_acc} = {
        bounds           => [ 0, 0, 0, 0 ],
        container_bounds => [ 0, 0, 0, 0 ],
        border           => [],
        buttons          => [],
        changed          => 1,
        sub_changed      => 1,
        maps             => {},
    };

    my $display_order = 0;
    foreach my $map_acc ( @{ $map_accs || [] } ) {
        $self->{'slot_layout'}{$slot_acc}{'maps'}{$map_acc} = {
            bounds  => [ 0, 0, 0, 0 ],
            buttons => [],
            data    => [],
            changed => 1,
        };
        $display_order++;
    }

    layout_new_window(
        window_acc       => $window_acc,
        app_display_data => $self,
    );

    $self->app_interface()->draw(
        window_acc       => $window_acc,
        app_display_data => $self,
    );

    return;
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
    my $window_acc = $args{'window_acc'} or return;
    my $bounds_change    = $args{'bounds_change'}    || 0;
    my $container_change = $args{'container_change'} || 0;

    $self->{'window_layout'}{$window_acc}{'bounds'}[3] += $bounds_change;
    $self->{'window_layout'}{$window_acc}{'container_bounds'}[3]
        += $container_change;
    $self->{'window_layout'}{$window_acc}{'changed'} = 1;

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
    my $panel_acc = $args{'panel_acc'} or return;
    my $bounds_change    = $args{'bounds_change'}    || 0;
    my $container_change = $args{'container_change'} || 0;

    $self->{'panel_layout'}{$panel_acc}{'bounds'}[3] += $bounds_change;
    $self->{'panel_layout'}{$panel_acc}{'container_bounds'}[3]
        += $container_change;
    $self->{'panel_layout'}{$panel_acc}{'changed'} = 1;

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
    my $slot_acc = $args{'slot_acc'} or return;
    my $bounds_change    = $args{'bounds_change'}    || 0;
    my $container_change = $args{'container_change'} || 0;

    $self->{'slot_layout'}{$slot_acc}{'bounds'}[3] += $bounds_change;
    $self->{'slot_layout'}{$slot_acc}{'container_bounds'}[3]
        += $container_change;
    $self->{'slot_layout'}{$slot_acc}{'changed'} = 1;

    return;
}

# ----------------------------------------------------
sub next_panel_acc {

=pod

=head2 next_panel_acc

Returns the next panel acc

=cut

    my $self = shift;

    if ( $self->{'last_panel_acc'} ) {
        $self->{'last_panel_acc'}++;
    }
    else {
        $self->{'last_panel_acc'} = 1;
    }

    return $self->{'last_panel_acc'};

}

# ----------------------------------------------------
sub next_slot_acc {

=pod

=head2 next_slot_acc

Returns the next slot acc

=cut

    my $self = shift;

    if ( $self->{'last_slot_acc'} ) {
        $self->{'last_slot_acc'}++;
    }
    else {
        $self->{'last_slot_acc'} = 1;
    }

    return $self->{'last_slot_acc'};

}

# ----------------------------------------------------
sub remove_window {

=pod

=head2 remove_window

Deletes the window data of a closed window.

Returns the number of remaining windows.

=cut

    my ( $self, %args ) = @_;
    my $window_acc = $args{'window_acc'};

    foreach my $panel_acc ( @{ $self->{'panel_order'}{$window_acc} || [] } ) {
        foreach my $slot_acc ( @{ $self->{'slot_order'}{$panel_acc} || [] } )
        {
            delete $self->{'slot_layout'}{$slot_acc};
        }
        delete $self->{'panel_layout'}{$panel_acc};
        delete $self->{'slot_order'}{$panel_acc};
    }
    delete $self->{'panel_order'}{$window_acc};

    delete $self->{'scaffold'}{$window_acc};
    delete $self->{'window_layout'}{$window_acc};

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

