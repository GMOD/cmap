package Bio::GMOD::CMap::Drawer::AppInterface;

# vim: set ft=perl:

# $Id: AppInterface.pm,v 1.2 2006-03-15 13:58:43 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Drawer::AppInterface - only draws 

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Drawer::AppInterface;

=head1 DESCRIPTION

The drawing module will keep the actual drawing and the layout separate from
each other in case a better technology than TK comes along.

=head1 Usage

    my $drawer = Bio::GMOD::CMap::Drawer::AppInterface->new();

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.2 $)[-1];

use Bio::GMOD::CMap::Constants;
use Data::Dumper;
use base 'Bio::GMOD::CMap::AppController';
use Tk;

# ----------------------------------------------------
sub init {

=pod

=head2 init

Initializes the drawing object.

=cut

    my ( $self, $config ) = @_;
    $self->app_data_module( $config->{'app_data_module'} )
        or die "Failed to pass app_data_module to AppInterface\n";
    $self->app_controller( $config->{'app_controller'} )
        or die "Failed to pass app_controller to AppInterface\n";

    return $self;
}

# ----------------------------------------------------
sub create_window {

=pod

=head2 create_window

This method will create the Application.

=cut

    my ( $self, %args ) = @_;
    my $title = $args{'title'} || 'Cmap Application';

    # Assign window_key sequentially
    # Start at 1 so it evals to true
    my $window_key = 1 + scalar keys %{ $self->{'windows'} || {} };

    $self->{'windows'}{$window_key}
        = $self->main_window()->Toplevel( -takefocus => 1 );
    $self->{'windows'}{$window_key}->title($title);

    $self->menu_bar( window_key => $window_key, );
    $self->canvas( window_key => $window_key, );

    $self->populate_menu_bar(
        window_key      => $window_key,
        file_menu_items =>
            $self->file_menu_items( window_key => $window_key, ),
    );

    $self->{'windows'}{$window_key}->protocol(
        'WM_DELETE_WINDOW',
        sub {
            $self->app_controller->close_window( window_key => $window_key, );
        }
    );

    return $window_key;
}

# ----------------------------------------------------
sub get_window {

=pod

=head2 get_window

This method returns a window.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return undef;

    return $self->{'windows'}{$window_key};
}

# ----------------------------------------------------
sub main_window {

=pod

=head2 main_window

Returns the TK main_window object.

=cut

    my ( $self, %args ) = @_;
    unless ( $self->{'main_window'} ) {
        $self->{'main_window'} = MainWindow->new();
        $self->{'main_window'}->withdraw();
    }
    return $self->{'main_window'};
}

# ----------------------------------------------------
sub app_controller {

=pod

=head3 app_controller

Returns a handle to the data module.

=cut

    my $self = shift;

    $self->{'app_controller'} = shift if @_;

    return $self->{'app_controller'};
}

# ----------------------------------------------------
sub menu_bar {

=pod

=head2 menu_bar

Returns the menu_bar object.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return undef;
    unless ( $self->{'menu_bar'}{$window_key} ) {
        my $window = $self->{'windows'}{$window_key};
        $self->{'menu_bar'}{$window_key} = $window->Menu();
        $window->configure( -menu => $self->{'menu_bar'}{$window_key} );
    }
    return $self->{'menu_bar'}{$window_key};
}

# ----------------------------------------------------
sub populate_menu_bar {

=pod

=head2 populate_menu_bar

Populates the menu_bar object.

=cut

    my ( $self, %args ) = @_;
    my $window_key      = $args{'window_key'} or return undef;
    my $file_menu_items = $args{'file_menu_items'};

    my $menu_bar = $self->menu_bar( window_key => $window_key, );

    $self->{'menu_buttons'}->{'file'} = $menu_bar->cascade(
        -label     => '~file',
        -menuitems => $file_menu_items,
    );

    return;
}

# ----------------------------------------------------
sub draw {

=pod

=head2 draw

Draws and re-draws on the canvas

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'}
        or die "no window key for file_menu_items";
    my $app_display_data = $args{'app_display_data'};

    my $canvas = $self->canvas( window_key => $window_key, );

    my $window_layout = $app_display_data->{'window_layout'}{$window_key};

    if ( $window_layout->{'changed'} ) {
        foreach my $drawing_section (qw[ border buttons ]) {
            $self->draw_items(
                canvas => $canvas,
                items  => $window_layout->{$drawing_section}
            );
        }
        $window_layout->{'changed'} = 0;
    }
    if ( $window_layout->{'sub_changed'} ) {

        # PANELS
        foreach my $panel_key (
            @{ $app_display_data->{'panel_order'}{$window_key} || [] } )
        {
            my $panel_layout
                = $app_display_data->{'panel_layout'}{$panel_key};
            if ( $panel_layout->{'changed'} ) {
                foreach my $drawing_section (qw[ border buttons ]) {
                    $self->draw_items(
                        canvas => $canvas,
                        items  => $panel_layout->{$drawing_section}
                    );
                }
                $panel_layout->{'changed'} = 0;
            }
            if ( $panel_layout->{'sub_changed'} ) {

                # SLOTS
                foreach my $slot_key (
                    @{ $app_display_data->{'slot_order'}{$panel_key} || [] } )
                {
                    my $slot_layout
                        = $app_display_data->{'slot_layout'}{$slot_key};
                    if ( $slot_layout->{'changed'} ) {
                        foreach my $drawing_section (qw[ border buttons ]) {
                            $self->draw_items(
                                canvas => $canvas,
                                items  => $slot_layout->{$drawing_section}
                            );
                        }
                        $slot_layout->{'changed'} = 0;
                    }
                    if ( $slot_layout->{'sub_changed'} ) {

                        # MAPS
                        foreach my $map_key (
                            keys %{ $slot_layout->{'maps'} || {} } )
                        {
                            my $map_layout = $slot_layout->{'maps'}{$map_key};
                            foreach my $drawing_section (qw[ buttons data ]) {
                                $self->draw_items(
                                    canvas => $canvas,
                                    items  => $map_layout->{$drawing_section}
                                );
                            }
                            if ( $map_layout->{'sub_changed'} ) {

                                # Features
                                foreach my $feature_acc (
                                    keys %{ $map_layout->{'features'}
                                            || {} } )
                                {
                                    my $feature_layout
                                        = $map_layout->{'features'}
                                        {$feature_acc};
                                    foreach my $drawing_section (qw[ data ]) {
                                        $self->draw_items(
                                            canvas => $canvas,
                                            items  => $feature_layout
                                                ->{$drawing_section}
                                        );
                                    }
                                }
                                $map_layout->{'sub_changed'} = 0;
                            }
                        }
                        $slot_layout->{'sub_changed'} = 0;
                    }
                }
                $panel_layout->{'sub_changed'} = 0;
            }
        }
        $window_layout->{'sub_changed'} = 0;
    }

    $canvas->configure( -scrollregion => $window_layout->{'bounds'} );

    return;
}

# ----------------------------------------------------
sub draw_items {

=pod

=head2 draw_items

Draws items on the canvas.

Item structure:

  [ changed, item_id, type, coord_array, options_hash ]

=cut

    my ( $self, %args ) = @_;
    my $canvas = $args{'canvas'};
    my $items  = $args{'items'} || return;

    for ( my $i = 0; $i <= $#{ $items || [] }; $i++ ) {

        # Has item been changed
        next unless ( $items->[$i][0] or not defined( $items->[$i][0] ) );

        my $item_id = $items->[$i][1];
        my $type    = $items->[$i][2];
        my $coords  = $items->[$i][3];
        my $options = $items->[$i][4];

        if ( defined($item_id) ) {
            $canvas->coords( $item_id, @{ $coords || [] } );
            $canvas->itemconfigure( $item_id, %{ $options || {} } );
        }
        else {
            $canvas->coords( $item_id, @{ $coords || [] } );
            my $create_method = "create" . ucfirst lc $type;
            $items->[$i][1]
                = $canvas->$create_method( @{$coords}, %{$options} );
        }
        $items->[$i][0] = 0;
    }
}

# ----------------------------------------------------
sub file_menu_items {

=pod

=head2 file_menu_items

Populates the file menu with menu_items

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'}
        or die "no window key for file_menu_items";
    return [
        [   'command',
            '~Load',
            -accelerator => 'Ctrl-l',
            -command     => sub {
                new_reference_maps( $self->app_controller(),
                    window_key => $window_key, );
            },
        ],
        [   'command',
            '~Quit',
            -accelerator => 'Ctrl-q',
            -command     => sub {exit},
        ],
    ];
}

# ----------------------------------------------------
sub canvas {

=pod

=head2 canvas

Returns the canvas object.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return undef;

    unless ( $self->{'canvas'}{$window_key} ) {
        my $canvas_frame = $self->{'windows'}{$window_key}->Frame()
            ->pack( -side => 'top', -fill => 'both', );
        $self->{'canvas'}{$window_key} = $canvas_frame->Scrolled(
            'Canvas',
            (   '-width'       => 1100,
                '-height'      => 700,
                '-relief'      => 'sunken',
                '-borderwidth' => 2,
                '-background'  => 'white',
                '-scrollbars'  => 'se',

                # '-scrollregion' => [ 0, 0, 100, 100 ],
            ),
        )->pack( -side => 'top', -fill => 'both', );
    }
    return $self->{'canvas'}{$window_key};
}

# ----------------------------------------------------
sub select_reference_maps {

=pod

=head2 select_reference_maps


=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'}
        or die "no window key for new reference_maps";
    my $controller = $args{'controller'};

    my $reference_maps_by_species
        = $self->app_data_module()->get_reference_maps_by_species();

    my $window = $self->get_window( window_key => $window_key, );

    $window->withdraw();

    my $ref_selection_window
        = $self->main_window()->Toplevel( -takefocus => 1 );
    $ref_selection_window->title('Select Maps');
    my $selection_frame
        = $ref_selection_window->Frame( -relief => 'groove', -border => 1, );
    my $species_frame = $selection_frame->Frame(
        -relief => 'groove',
        -border => 1,
        -label  => "Species",
    );
    my $map_set_frame = $selection_frame->Frame(
        -relief => 'groove',
        -border => 1,
        -label  => "Map Sets",
    );
    my $map_frame = $selection_frame->Frame(
        -relief => 'groove',
        -border => 1,
        -label  => "Maps",
    );
    my $map_listbox = $map_frame->Scrolled(
        'Listbox',
        -scrollbars => 'osoe',
        -height     => 7,
        -selectmode => 'multiple',
    )->pack;
    my $ref_species_id = $reference_maps_by_species->[0]->{'species_id'};
    my $selectable_ref_map_ids = [];

    foreach my $species ( @{ $reference_maps_by_species || [] } ) {
        $species_frame->Radiobutton(
            -text     => $species->{'species_common_name'},
            -value    => $species->{'species_id'},
            -variable => \$ref_species_id,
            -command  => sub {
                $self->display_reference_map_sets(
                    map_set_frame          => $map_set_frame,
                    map_listbox            => $map_listbox,
                    selectable_ref_map_ids => $selectable_ref_map_ids,
                    map_sets               => $species->{'map_sets'},
                );
            },
        )->pack( -side => 'top', -anchor => 'nw', );
    }
    $species_frame->pack( -side => 'left', -anchor => 'n', );
    $map_set_frame->pack( -side => 'left', -anchor => 'n', );
    $map_frame->pack( -side     => 'left', -anchor => 'n', );
    $self->display_reference_map_sets(
        map_set_frame          => $map_set_frame,
        map_listbox            => $map_listbox,
        selectable_ref_map_ids => $selectable_ref_map_ids,
        map_sets               => $reference_maps_by_species->[0]{'map_sets'},
    );
    $selection_frame->pack( -side => 'top', -anchor => 'nw', );

    $ref_selection_window->Button(
        -text    => "Load Maps",
        -command => sub {
            $controller->load_first_slot(
                selectable_ref_map_ids => $selectable_ref_map_ids,
                selections             => [ $map_listbox->curselection() ],
                window_key             => $window_key,
            );
            $self->return_to_last_window(
                current_window => $ref_selection_window,
                last_window    => $window,
            );
        },
    )->pack( -side => 'bottom', -anchor => 's' );
    $ref_selection_window->Button(
        -text    => "Cancel",
        -command => sub {
            $self->return_to_last_window(
                current_window => $ref_selection_window,
                last_window    => $window,
            );
        },
    )->pack( -side => 'bottom', -anchor => 's' );
    $ref_selection_window->protocol(
        'WM_DELETE_WINDOW',
        sub {
            $self->return_to_last_window(
                current_window => $ref_selection_window,
                last_window    => $window,
            );
        }
    );

    return;
}

# ----------------------------------------------------
sub display_reference_map_sets {

=pod

=head2 display_reference_map_sets

=cut

    my ( $self, %args ) = @_;
    my $map_set_frame          = $args{'map_set_frame'};
    my $map_listbox            = $args{'map_listbox'};
    my $selectable_ref_map_ids = $args{'selectable_ref_map_ids'};
    my $map_sets               = $args{'map_sets'};

    $self->clear_buttons($map_set_frame);
    $self->clear_ref_maps( $map_listbox, $selectable_ref_map_ids );

    my $ref_map_set_id = $map_sets->[0]->{'map_set_id'};
    foreach my $map_set ( @{ $map_sets || [] } ) {
        $map_set_frame->Radiobutton(
            -text     => $map_set->{'map_set_name'},
            -value    => $map_set->{'map_set_id'},
            -variable => \$ref_map_set_id,
            -command  => sub {
                $self->display_reference_maps(
                    map_listbox            => $map_listbox,
                    selectable_ref_map_ids => $selectable_ref_map_ids,
                    maps                   => $map_set->{'maps'},
                );
            },
        )->pack( -side => 'top', -anchor => 'nw', );
    }

    $self->display_reference_maps(
        map_listbox            => $map_listbox,
        selectable_ref_map_ids => $selectable_ref_map_ids,
        maps                   => $map_sets->[0]{'maps'},
    );

    return;
}

# ----------------------------------------------------
sub display_reference_maps {

=pod

=head2 display_reference_map_sets

=cut

    my ( $self, %args ) = @_;
    my $map_listbox            = $args{'map_listbox'};
    my $selectable_ref_map_ids = $args{'selectable_ref_map_ids'};
    my $maps                   = $args{'maps'};

    $self->clear_ref_maps( $map_listbox, $selectable_ref_map_ids );

    foreach my $map ( @{ $maps || [] } ) {
        $map_listbox->insert( 'end', $map->{'map_name'}, );
        push @$selectable_ref_map_ids, $map->{'map_id'};
    }

    return;
}

# ----------------------------------------------------
sub clear_buttons {

=pod

=head2 clear_buttons

=cut

    my $self   = shift;
    my $widget = shift;
    foreach my $child ( $widget->children() ) {
        if ( $child->class() =~ /button/i ) {
            $child->destroy;
        }
    }

    return;
}

# ----------------------------------------------------
sub clear_ref_maps {

=pod

=head2 clear_ref_maps

=cut

    my $self             = shift;
    my $ref_maps_listbox = shift or return;
    my $ref_map_ids      = shift or return;
    $ref_maps_listbox->delete( 0, 'end' );
    @$ref_map_ids = ();

    return;
}

# ----------------------------------------------------
sub return_to_last_window {

=pod

=head2 return_to_last_window

Destroys current window and raises the last window.

=cut

    my ( $self, %args ) = @_;
    my $current_window = $args{'current_window'};
    my $last_window    = $args{'last_window'};
    $last_window->deiconify();
    $last_window->raise();
    $current_window->destroy();

    return;
}

1;

# ----------------------------------------------------
# It is not all books that are as dull as their readers.
# Henry David Thoreau
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>, 

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-5 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

