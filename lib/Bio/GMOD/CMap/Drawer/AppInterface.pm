package Bio::GMOD::CMap::Drawer::AppInterface;

# vim: set ft=perl:

# $Id: AppInterface.pm,v 1.4 2006-04-27 20:16:14 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.4 $)[-1];

use Bio::GMOD::CMap::Constants;
use Data::Dumper;
use base 'Bio::GMOD::CMap::AppController';
use Tk;
use Tk::Pane;

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
sub int_create_window {

=pod

=head2 int_create_window

This method will create the Application.

=cut

    my ( $self, %args ) = @_;
    my $window_key       = $args{'window_key'} or return;
    my $app_display_data = $args{'app_display_data'};

    my $title = $app_display_data->{'window_layout'}{$window_key}{'title'}
        || '';

    $self->{'windows'}{$window_key}
        = $self->main_window()->Toplevel( -takefocus => 1 );
    $self->{'windows'}{$window_key}->title($title);

    $self->menu_bar( window_key => $window_key, );
    $self->populate_menu_bar(
        window_key      => $window_key,
        file_menu_items =>
            $self->file_menu_items( window_key => $window_key, ),
    );
    $self->window_pane( window_key => $window_key, );

    $self->{'windows'}{$window_key}->protocol(
        'WM_DELETE_WINDOW',
        sub {
            $self->app_controller->close_window( window_key => $window_key, );
        }
    );
    return $window_key;
}

# ----------------------------------------------------
sub int_create_panel {

=pod

=head2 int_create_panel

This method will create the Application.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $panel_key  = $args{'panel_key'}  or return;
    my $app_display_data = $args{'app_display_data'};

    $self->panel_pane(
        window_key => $window_key,
        panel_key  => $panel_key,
    );
    $self->panel_controls_pane( panel_key => $panel_key, );
    $self->panel_slot_controls_pane( panel_key => $panel_key, );
    $self->panel_canvas_pane( panel_key => $panel_key, );
    $self->canvas( panel_key => $panel_key, );

    return;
}

# ----------------------------------------------------
sub int_create_slot_controls {

=pod

=head2 int_create_slot_controls

This method will create the slot controls for the panel.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $panel_key  = $args{'panel_key'}  or return;
    my $app_display_data = $args{'app_display_data'};

    foreach
        my $slot_key ( @{ $app_display_data->{'slot_order'}{$panel_key} } )
    {
        my $y_val
            = $app_display_data->{'slot_layout'}{$slot_key}{'bounds'}[1];
        my $height
            = $app_display_data->{'slot_layout'}{$slot_key}{'bounds'}[3]
            - $app_display_data->{'slot_layout'}{$slot_key}{'bounds'}[1] + 1;
        $self->slot_controls_pane(
            panel_key => $panel_key,
            slot_key  => $slot_key,
            y_val     => $y_val,
            height    => $height,
        );
        $self->_add_slot_control_buttons(
            window_key       => $window_key,
            panel_key        => $panel_key,
            slot_key         => $slot_key,
            app_display_data => $app_display_data,
        );
    }

    return;
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
sub window_pane {

=pod

=head2 window_pane

Returns the window_pane object.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return undef;
    unless ( $self->{'window_pane'}{$window_key} ) {
        my $window = $self->{'windows'}{$window_key};
        $self->{'window_pane'}{$window_key} = $window->Scrolled(
            "Pane",
            -scrollbars => "oe",
            -background => "white",
            -height     => $window->screenheight(),
            -width      => $window->screenwidth(),
        );
        $self->{'window_pane'}{$window_key}
            ->pack( -side => 'top', -fill => 'both', );
    }
    return $self->{'window_pane'}{$window_key};
}

# ----------------------------------------------------
sub panel_pane {

=pod

=head2 panel_pane

Returns the panel_pane object.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return undef;
    my $panel_key  = $args{'panel_key'}  or return undef;
    unless ( $self->{'panel_pane'}{$panel_key} ) {
        my $window_pane = $self->{'window_pane'}{$window_key};
        $self->{'panel_pane'}{$panel_key} = $window_pane->Frame(
            -relief     => 'groove',
            -border     => 1,
            -background => "white"
        );
        $self->{'panel_pane'}{$panel_key}
            ->pack( -side => 'top', -fill => 'both', );
    }
    return $self->{'panel_pane'}{$panel_key};
}

# ----------------------------------------------------
sub panel_controls_pane {

=pod

=head2 panel_controls_pane

Returns the panel_controls_pane object.

=cut

    my ( $self, %args ) = @_;
    my $panel_key = $args{'panel_key'} or return undef;
    unless ( $self->{'panel_controls_pane'}{$panel_key} ) {
        my $panel_pane = $self->{'panel_pane'}{$panel_key};
        $self->{'panel_controls_pane'}{$panel_key} = $panel_pane->Frame(
            -relief     => 'groove',
            -border     => 1,
            -background => "white",
        );
        $self->{'panel_controls_pane'}{$panel_key}
            ->pack( -side => 'top', -fill => 'x', );
    }
    return $self->{'panel_controls_pane'}{$panel_key};
}

# ----------------------------------------------------
sub panel_slot_controls_pane {

=pod

=head2 panel_slot_controls_pane

Returns the panel_slot_controls_pane object.

=cut

    my ( $self, %args ) = @_;
    my $panel_key = $args{'panel_key'} or return undef;
    unless ( $self->{'panel_slot_controls_pane'}{$panel_key} ) {
        my $panel_pane = $self->{'panel_pane'}{$panel_key};
        $self->{'panel_slot_controls_pane'}{$panel_key} = $panel_pane->Frame(
            -relief     => 'groove',
            -border     => 1,
            -height     => 500,
            -width      => 200,
            -background => "white",
        );
        $self->{'panel_slot_controls_pane'}{$panel_key}
            ->pack( -side => 'left', -fill => 'both', );
    }
    return $self->{'panel_slot_controls_pane'}{$panel_key};
}

# ----------------------------------------------------
sub panel_canvas_pane {

=pod

=head2 panel_canvas_pane

Returns the panel_canvas_pane object.

=cut

    my ( $self, %args ) = @_;
    my $panel_key = $args{'panel_key'} or return undef;
    unless ( $self->{'panel_canvas_pane'}{$panel_key} ) {
        my $panel_pane = $self->{'panel_pane'}{$panel_key};
        $self->{'panel_canvas_pane'}{$panel_key} = $panel_pane->Frame(
            -relief     => 'groove',
            -border     => 1,
            -background => "white",
        );
        $self->{'panel_canvas_pane'}{$panel_key}
            ->pack( -side => 'top', -fill => 'x', );
    }
    return $self->{'panel_canvas_pane'}{$panel_key};
}

# ----------------------------------------------------
sub slot_controls_pane {

=pod

=head2 slot_controls_pane

Returns the slot_controls_pane object.

=cut

    my ( $self, %args ) = @_;
    my $panel_key = $args{'panel_key'} or return undef;
    my $slot_key  = $args{'slot_key'}  or return undef;
    unless ( $self->{'slot_controls_pane'}{$slot_key} ) {
        my $y_val  = $args{'y_val'};
        my $height = $args{'height'};
        my $panel_slot_controls_pane
            = $self->{'panel_slot_controls_pane'}{$panel_key};
        if (1) {
            $self->{'slot_controls_pane'}{$slot_key}
                = $panel_slot_controls_pane->Frame(
                -borderwidth => 1,
                -relief      => 'groove',
                -background  => "yellow",
                );
        }
        else {
            $self->{'slot_controls_pane'}{$slot_key}
                = $panel_slot_controls_pane->Scrolled(
                "Pane",

                #-scrollbars => "oe",
                #-relief     => 'groove',
                -background => "green",
                );
        }
        $self->{'slot_controls_pane'}{$slot_key}->place(
            -x        => 5,
            -y        => $y_val,
            -relwidth => .89,
            -height   => $height
        );
    }
    return $self->{'slot_controls_pane'}{$slot_key};
}

# ----------------------------------------------------
sub _add_slot_control_buttons {

=pod

=head2 _add_slot_control_buttons

Adds control buttons to the slot_controls_pane.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $panel_key  = $args{'panel_key'}  or return;
    my $slot_key   = $args{'slot_key'}   or return;
    my $app_display_data   = $args{'app_display_data'};
    my $slot_controls_pane = $self->{'slot_controls_pane'}{$slot_key};
    my $font               = [
        -family => 'Times',
        -size   => 12,
    ];
    my $zoom_label1 = $slot_controls_pane->Label(
        -text       => "Zoom",
        -font       => $font,
        -background => 'grey',
    );
    my $zoom_button1 = $slot_controls_pane->Button(
        -text    => "+",
        -command => sub {
            $self->app_controller()->zoom_slot(
                window_key => $window_key,
                panel_key  => $panel_key,
                slot_key   => $slot_key,
                zoom_value => 2,
            );
        },
        -font => $font,
    );
    my $zoom_button2 = $slot_controls_pane->Button(
        -text    => "-",
        -command => sub {
            $self->app_controller()->zoom_slot(
                window_key => $window_key,
                panel_key  => $panel_key,
                slot_key   => $slot_key,
                zoom_value => .5,
            );
        },
        -font => $font,
    );
    Tk::grid( $zoom_label1, -sticky => "nw", );
    Tk::grid( $zoom_button1, $zoom_button2, -sticky => "nw", );
    return;
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
sub draw_panel {

=pod

=head2 draw

Draws and re-draws on the canvas

=cut

    my ( $self, %args ) = @_;
    my $panel_key = $args{'panel_key'}
        or die 'no panel key for draw';
    my $app_display_data = $args{'app_display_data'};

    my $canvas = $self->canvas( panel_key => $panel_key, );

    my $panel_layout = $app_display_data->{'panel_layout'}{$panel_key};
    if ( $panel_layout->{'changed'} ) {
        foreach my $drawing_section (qw[ misc_items ]) {
            $self->draw_items(
                canvas => $canvas,
                items  => $panel_layout->{$drawing_section},
                tags   => [ 'on_top', ],
            );
        }
        foreach my $button ( @{ $panel_layout->{'buttons'} || [] } ) {
            $self->draw_button(
                canvas => $canvas,
                button => $button,
            );

        }
        $panel_layout->{'changed'} = 0;
    }
    if ( $panel_layout->{'sub_changed'} ) {

        # SLOTS
        foreach my $slot_key (
            @{ $app_display_data->{'slot_order'}{$panel_key} || [] } )
        {
            $self->draw_slot(
                slot_key         => $slot_key,
                canvas           => $canvas,
                app_display_data => $app_display_data,
            );
        }
        $panel_layout->{'sub_changed'} = 0;
    }

    $canvas->configure( -scrollregion => $panel_layout->{'bounds'} );

    return;
}

# ----------------------------------------------------
sub draw_slot {

=pod

=head2 draw_slot

Draws and re-draws on the canvas

=cut

    my ( $self, %args ) = @_;
    my $slot_key = $args{'slot_key'}
        or die 'no slot key for draw';
    my $canvas = $args{'canvas'}
        || $self->canvas( panel_key => $args{'panel_key'}, );
    my $app_display_data = $args{'app_display_data'};

    my $slot_layout = $app_display_data->{'slot_layout'}{$slot_key};
    if ( $slot_layout->{'changed'} ) {
        foreach my $drawing_section (qw[ background separator ]) {
            $self->draw_items(
                canvas => $canvas,
                items  => $slot_layout->{$drawing_section},
                tags   => [ 'on_top', ],
            );
        }
        foreach my $button ( @{ $slot_layout->{'buttons'} || [] } ) {
            $self->draw_button(
                canvas => $canvas,
                button => $button,
            );
        }
        $slot_layout->{'changed'} = 0;
    }
    if ( $slot_layout->{'sub_changed'} ) {
        my $x_offset
            = $app_display_data->{'scaffold'}{$slot_key}->{'x_offset'};

        # MAPS
        foreach my $map_key (
            @{ $app_display_data->{'map_order'}{$slot_key} || {} } )
        {
            my $map_layout = $app_display_data->{'map_layout'}{$map_key};
            foreach my $drawing_section (qw[ buttons items ]) {
                $self->draw_items(
                    canvas   => $canvas,
                    x_offset => $x_offset,
                    items    => $map_layout->{$drawing_section},
                    tags     => [ 'display', ],
                );
            }
            foreach my $button ( @{ $map_layout->{'buttons'} || [] } ) {
                $self->draw_button(
                    canvas   => $canvas,
                    x_offset => $x_offset,
                    button   => $button,
                );
            }
            if ( $map_layout->{'sub_changed'} ) {

                # Features
                foreach my $feature_acc (
                    keys %{ $map_layout->{'features'} || {} } )
                {
                    my $feature_layout
                        = $map_layout->{'features'}{$feature_acc};
                    foreach my $drawing_section (qw[ items ]) {
                        $self->draw_items(
                            canvas   => $canvas,
                            x_offset => $x_offset,
                            items    => $feature_layout->{$drawing_section},
                            tags     => [ 'display', ],
                        );
                    }
                }
                $map_layout->{'sub_changed'} = 0;
            }
        }
        $slot_layout->{'sub_changed'} = 0;
    }

    return;
}

sub pre_draw_text {

=pod

=head2 pre_draw_text

Draw text and return the id and the boundaries.
This is an effort to reserve the text space for the app_display_data.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'}
        or die 'no window key for file_menu_items';
    my $app_display_data = $args{'app_display_data'};
    my $x1               = $args{'x1'};
    my $y1               = $args{'y1'};
    my $text             = $args{'text'};

    my $canvas = $self->canvas( window_key => $window_key, );

    my $item_id = $canvas->createText(
        ( $x1, $y1 ),
        (   '-text'   => $text,
            '-anchor' => 'nw',

            #-font => $font_string,
        )
    );
    return ( $item_id, [ $canvas->bbox($item_id) ] );
}

sub pre_draw_button {

=pod

=head2 pre_draw_button

Draw button and return the id and the boundaries.
This is an effort to reserve the button space for the app_display_data.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'}
        or die 'no window key for file_menu_items';
    my $panel_key        = $args{'panel_key'};
    my $slot_key         = $args{'slot_key'};
    my $app_display_data = $args{'app_display_data'};
    my $x1               = $args{'x1'};
    my $y1               = $args{'y1'};
    my $text             = $args{'text'};
    my $type             = $args{'type'};

    my $canvas      = $self->canvas( window_key => $window_key, );
    my $command_ref = $self->get_button_command( %args, );

    my $button_win_id = $canvas->createWindow(
        $x1, $y1,
        -anchor => 'nw',
        -window => $canvas->Button(
            -text    => $text,
            -command => $command_ref,
        ),
        -tags => [ 'button', ],
    );

    return ( $button_win_id, [ $canvas->bbox($button_win_id) ] );
}

sub get_button_command {

=pod

=head2 get_button_command

Returns the subroutine to use for a button

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $panel_key  = $args{'panel_key'};
    my $slot_key   = $args{'slot_key'};
    my $type       = $args{'type'};

    if ( $type eq 'zoom_in' ) {
        return sub {
            $self->app_controller()->zoom_slot(
                window_key => $window_key,
                panel_key  => $panel_key,
                slot_key   => $slot_key,
                zoom_value => $args{'zoom_value'},
            );
        };
    }

    return
        sub { print STDERR "This Button Type, $type, is not yet defined\n"; };
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
    my $canvas   = $args{'canvas'};
    my $x_offset = $args{'x_offset'} || 0;
    my $items    = $args{'items'} || return;
    my $tags     = $args{'tags'} || [];

    for ( my $i = 0; $i <= $#{ $items || [] }; $i++ ) {

        # Has item been changed
        next unless ( $items->[$i][0] or not defined( $items->[$i][0] ) );

        my $item_id = $items->[$i][1];
        my $type    = $items->[$i][2];
        my @coords  = @{ $items->[$i][3] };    # creates duplicate array
        my $options = $items->[$i][4];

        $coords[0] -= $x_offset;
        $coords[2] -= $x_offset if ( defined $coords[2] );

        if ( defined($item_id) ) {
            $canvas->coords( $item_id, @coords );
            $canvas->itemconfigure( $item_id, %{ $options || {} } );
        }
        else {
            $canvas->coords( $item_id, @coords );
            my $create_method = 'create' . ucfirst lc $type;
            $items->[$i][1] = $canvas->$create_method( @coords, %{$options} );
            foreach my $tag (@$tags) {
                $canvas->addtag( $tag, 'withtag', $items->[$i][1] );
            }
        }
        $items->[$i][0] = 0;
    }
}

# ----------------------------------------------------
sub add_tags_to_items {

=pod

=head2 add_tags_to_items

Adds tags to items on the canvas.

Item structure:

  [ changed, item_id, type, coord_array, options_hash ]

=cut

    my ( $self, %args ) = @_;
    my $canvas = $args{'canvas'};
    my $items  = $args{'items'} || [];
    my $tags   = $args{'tags'} || [];

    foreach my $item ( @{ $items || [] } ) {
        next unless ( $item->[1] );
        foreach my $tag (@$tags) {
            $canvas->addtag( $tag, 'withtag', $item->[1] );
        }
    }
}

# ----------------------------------------------------
sub draw_button {

=pod

=head2 draw_button

Draws a button on the canvas and associates callbacks to it.

Item structure:

  [ changed, item_id, type, coord_array, options_hash ]

=cut

    my ( $self, %args ) = @_;
    my $canvas = $args{'canvas'};
    my $button = $args{'button'} || return;

    my $button_id   = $button->{'item_id'};
    my $button_type = $button->{'type'};

    # Add Tags
    my @tags;
    if ( $button_type eq 'test' ) {

        #could add special tags.
    }
    $self->add_tags_to_items(
        canvas => $canvas,
        items  => $button->{'items'},
        tags   => \@tags,
    );

}

# ----------------------------------------------------
sub file_menu_items {

=pod

=head2 file_menu_items

Populates the file menu with menu_items

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'}
        or die 'no window key for file_menu_items';
    return [
        [   'command',
            '~Load',
            -accelerator => 'Ctrl-l',
            -command     => sub {
                $self->app_controller()
                    ->new_reference_maps( window_key => $window_key, );
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
    my $panel_key = $args{'panel_key'} or return undef;

    unless ( $self->{'canvas'}{$panel_key} ) {
        my $canvas_frame = $self->{'panel_canvas_pane'}{$panel_key};
        $self->{'canvas'}{$panel_key} = $canvas_frame->Scrolled(
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
    return $self->{'canvas'}{$panel_key};
}

# ----------------------------------------------------
sub select_reference_maps {

=pod

=head2 select_reference_maps


=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'}
        or die 'no window key for new reference_maps';
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
        -label  => 'Species',
    );
    my $map_set_frame = $selection_frame->Frame(
        -relief => 'groove',
        -border => 1,
        -label  => 'Map Sets',
    );
    my $map_frame = $selection_frame->Frame(
        -relief => 'groove',
        -border => 1,
        -label  => 'Maps',
    );
    my $map_listbox = $map_frame->Scrolled(
        'Listbox',
        -scrollbars => 'osoe',
        -height     => 7,
        -selectmode => 'multiple',
    )->pack;
    my $selectable_ref_map_ids = [];
    my $load_button            = $ref_selection_window->Button(
        -text    => 'Load Maps',
        -command => sub {

            if ( $map_listbox->curselection() ) {
                $controller->load_first_slot(
                    selectable_ref_map_ids => $selectable_ref_map_ids,
                    selections => [ $map_listbox->curselection() ],
                    window_key => $window_key,
                );
                $self->return_to_last_window(
                    current_window => $ref_selection_window,
                    last_window    => $window,
                );
            }
        },
    )->pack( -side => 'bottom', -anchor => 's' );
    $ref_selection_window->Button(
        -text    => 'Cancel',
        -command => sub {
            $self->return_to_last_window(
                current_window => $ref_selection_window,
                last_window    => $window,
            );
        },
    )->pack( -side => 'bottom', -anchor => 's' );
    my $map_button_frame = $map_frame->Frame(
        -relief => 'flat',
        -border => 0,
    )->pack;
    $map_button_frame->Button(
        -text    => 'Select All',
        -command => sub {
            $map_listbox->selectionSet( 0, 'end' );
            $load_button->configure( -state => 'normal' );
        },
    )->pack( -side => 'left', -anchor => 'center' );
    $map_button_frame->Button(
        -text    => 'Clear',
        -command => sub {
            $map_listbox->selectionClear( 0, 'end' );
            $load_button->configure( -state => 'disabled' );
        },
    )->pack( -side => 'right', -anchor => 'center' );

    my $ref_species_id = $reference_maps_by_species->[0]->{'species_id'};

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

    $map_listbox->bind(
        '<Button-1>',
        sub {
            if ( $map_listbox->curselection() ) {
                $load_button->configure( -state => 'normal' );
            }
            else {
                $load_button->configure( -state => 'disabled' );
            }
        },
    );

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

# ----------------------------------------------------
sub int_destroy_items {

=pod

=head2 destroy_items

Deletes all widgets in the provided list

=cut

    my ( $self, %args ) = @_;
    my $panel_key = $args{'panel_key'};
    my $items     = $args{'items'} || return;

    $self->canvas( panel_key => $panel_key, )
        ->delete( map { $_->[1] } @$items );

    # Maybe clear bindings if they aren't destroyed with delete.

    return;
}

# ----------------------------------------------------
sub clear_interface_window {

=pod

=head2 clear_interface_window

Deletes all widgets in the current window.

=cut

    my ( $self, %args ) = @_;
    my $window_key       = $args{'window_key'};
    my $app_display_data = $args{'app_display_data'};

    foreach
        my $panel_key ( @{ $app_display_data->{'panel_order'}{$window_key} } )
    {
        $self->{'panel_pane'}{$panel_key}->destroy();
    }

    # Maybe clear bindings if they aren't destroyed with delete.

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

