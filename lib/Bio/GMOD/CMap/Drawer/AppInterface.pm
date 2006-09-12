package Bio::GMOD::CMap::Drawer::AppInterface;

# vim: set ft=perl:

# $Id: AppInterface.pm,v 1.11 2006-09-12 15:10:32 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.11 $)[-1];

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
    $self->panel_overview_pane( panel_key => $panel_key, );
    $self->panel_slot_toggle_pane( panel_key => $panel_key, );
    $self->panel_slot_controls_pane(
        panel_key  => $panel_key,
        window_key => $window_key,
    );
    $self->panel_canvas_pane( panel_key => $panel_key, );
    $self->overview_canvas( panel_key => $panel_key, );
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
        $self->add_slot_controls(
            window_key       => $window_key,
            panel_key        => $panel_key,
            slot_key         => $slot_key,
            app_display_data => $app_display_data,
        );
    }
    ${$self->{'selected_slot_key_scalar'}} = $app_display_data->{'slot_order'}{$panel_key}[0] || 0;

    return;
}

# ----------------------------------------------------
sub add_slot_controls {

=pod

=head2 add_slot_controls

This method will create the slot controls for one slot

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $panel_key  = $args{'panel_key'}  or return;
    my $slot_key  = $args{'slot_key'}  or return;
    my $app_display_data = $args{'app_display_data'};

    $self->toggle_slot_pane(
        panel_key => $panel_key,
        slot_key  => $slot_key,
        app_display_data => $app_display_data,
    );
    $self->_add_slot_toggle_buttons(
        window_key       => $window_key,
        panel_key        => $panel_key,
        slot_key         => $slot_key,
        app_display_data => $app_display_data,
    );

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
            -background => "grey",
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
            -border     => 0,
            -background => "white"
        );
        $self->{'panel_pane'}{$panel_key}
            ->pack( -side => 'left', -fill => 'none', );
    }
    return $self->{'panel_pane'}{$panel_key};
}

# ----------------------------------------------------
sub panel_overview_pane {

=pod

=head2 panel_overview_pane

Returns the panel_overview_pane object.

=cut

    my ( $self, %args ) = @_;
    my $panel_key = $args{'panel_key'} or return undef;
    unless ( $self->{'panel_overview_pane'}{$panel_key} ) {
        my $panel_pane = $self->{'panel_pane'}{$panel_key};
        $self->{'panel_overview_pane'}{$panel_key} = $panel_pane->Frame(
            -relief     => 'groove',
            -border     => 1,
            -background => "white",
        );
        $self->{'panel_overview_pane'}{$panel_key}
            ->pack( -side => 'top', -fill => 'x', );
    }
    return $self->{'panel_overview_pane'}{$panel_key};
}

# ----------------------------------------------------
sub panel_slot_toggle_pane {

=pod

=head2 panel_slot_toggle_pane

Returns the panel_slot_toggle_pane object.

=cut

    my ( $self, %args ) = @_;
    my $panel_key = $args{'panel_key'} or return undef;
    unless ( $self->{'panel_slot_toggle_pane'}{$panel_key} ) {
        my $panel_pane = $self->{'panel_pane'}{$panel_key};
        $self->{'panel_slot_toggle_pane'}{$panel_key} = $panel_pane->Frame(
            -relief     => 'groove',
            -border     => 0,
            -height     => 500,
            -width      => 200,
            -background => "white",
        );
        $self->{'panel_slot_toggle_pane'}{$panel_key}
            ->pack( -side => 'left', -fill => 'both', );
    }
    return $self->{'panel_slot_toggle_pane'}{$panel_key};
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
            -border     => 0,
            -background => "white",
        );
        $self->{'panel_canvas_pane'}{$panel_key}
            ->pack( -side => 'top', -fill => 'x', );
    }
    return $self->{'panel_canvas_pane'}{$panel_key};
}

# ----------------------------------------------------
sub panel_slot_controls_pane {

=pod

=head2 panel_slot_controls_pane

Returns the panel_slot_controls_pane object.

=cut

    my ( $self, %args ) = @_;
    my $panel_key = $args{'panel_key'} or return undef;
    my $window_key = $args{'window_key'} or return undef;
    unless ( $self->{'panel_slot_controls_pane'}{$panel_key} ) {
        my $y_val  = $args{'y_val'};
        my $height = $args{'height'};
        my $panel_pane = $self->{'panel_pane'}{$panel_key};
        if (1) {
            $self->{'panel_slot_controls_pane'}{$panel_key}
                = $panel_pane->Frame(
                -borderwidth => 0,
                -relief      => 'groove',
                -background  => "white",
                );
        }
        else {
            $self->{'panel_slot_controls_pane'}{$panel_key}
                = $panel_pane->Scrolled(
                "Pane",

                #-scrollbars => "oe",
                #-relief     => 'groove',
                -background => "blue",
                );
        }
        $self->_add_slot_control_buttons(
            window_key       => $window_key,
            panel_key        => $panel_key,
        );
        $self->{'panel_slot_controls_pane'}{$panel_key}->pack( -side => 'bottom', -fill => 'x', );
    }
    return $self->{'panel_slot_controls_pane'}{$panel_key};
}

# ----------------------------------------------------
sub toggle_slot_pane {

=pod

=head2 toggle_slot_pane

Returns the toggle_slot_pane object.

=cut

    my ( $self, %args ) = @_;
    my $panel_key = $args{'panel_key'} or return undef;
    my $slot_key  = $args{'slot_key'}  or return undef;
    unless ( $self->{'toggle_slot_pane'}{$slot_key} ) {
        my $app_display_data = $args{'app_display_data'} or return undef;
        my $y_val
            = $app_display_data->{'slot_layout'}{$slot_key}{'bounds'}[1];
        my $height
            = $app_display_data->{'slot_layout'}{$slot_key}{'bounds'}[3]
            - $app_display_data->{'slot_layout'}{$slot_key}{'bounds'}[1] + 1;
        my $panel_slot_toggle_pane
            = $self->{'panel_slot_toggle_pane'}{$panel_key};
        if (1) {
            $self->{'toggle_slot_pane'}{$slot_key}
                = $panel_slot_toggle_pane->Frame(
                -borderwidth => 1,
                -relief      => 'groove',
                -background  => "white",
                );
        }
        else {
            $self->{'toggle_slot_pane'}{$slot_key}
                = $panel_slot_toggle_pane->Scrolled(
                "Pane",

                #-scrollbars => "oe",
                #-relief     => 'groove',
                -background => "green",
                );
        }
        $self->{'toggle_slot_pane'}{$slot_key}->place(
            -x        => 5,
            -y        => $y_val,
            -relwidth => .89,
            -height   => $height +10
        );
    }
    return $self->{'toggle_slot_pane'}{$slot_key};
}

# ----------------------------------------------------
sub _add_slot_toggle_buttons {

=pod

=head2 _add_slot_toggle_buttons

Adds control buttons to the toggle_slot_pane.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $panel_key  = $args{'panel_key'}  or return;
    my $slot_key   = $args{'slot_key'}   or return;
    my $app_display_data   = $args{'app_display_data'};
    my $toggle_slot_pane = $self->{'toggle_slot_pane'}{$slot_key};
    my $font               = [
        -family => 'Times',
        -size   => 12,
    ];

    my $toggle_button = $toggle_slot_pane->Radiobutton(
        -text    => "Select",
        -background => "white",
        -value   => $slot_key,
        -command => sub {
            $self->app_controller()->new_selected_slot(
                window_key => $window_key,
                panel_key  => $panel_key,
                slot_key   => $slot_key,
            );
        },
        -variable   => \${$self->{'selected_slot_key_scalar'}}
    );
    
    #    Tk::grid( $zoom_label1, -sticky => "nw", );
    Tk::grid(
        $toggle_button, -sticky        => "ne",
    );
    return;
}

# ----------------------------------------------------
sub _add_slot_control_buttons {

=pod

=head2 _add_slot_control_buttons

Adds control buttons to the panel_slot_controls_pane.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $panel_key  = $args{'panel_key'}  or return;
    my $panel_slot_controls_pane = $self->{'panel_slot_controls_pane'}{$panel_key};
    my $font               = [
        -family => 'Times',
        -size   => 12,
    ];

    #    my $zoom_label1 = $panel_slot_controls_pane->Label(
    #        -text       => "Zoom",
    #        -font       => $font,
    #        -background => 'grey',
    #    );
    my $zoom_button1 = $panel_slot_controls_pane->Button(
        -text    => "Zoom In",
        -command => sub {
            $self->app_controller()->zoom_slot(
                window_key => $window_key,
                panel_key  => $panel_key,
                slot_key   => ${$self->{'selected_slot_key_scalar'}},
                zoom_value => 2,
            );
        },
        -font => $font,
    );
    my $zoom_button2 = $panel_slot_controls_pane->Button(
        -text    => "Zoom Out",
        -command => sub {
            $self->app_controller()->zoom_slot(
                window_key => $window_key,
                panel_key  => $panel_key,
                slot_key   => ${$self->{'selected_slot_key_scalar'}},
                zoom_value => .5,
            );
        },
        -font => $font,
    );
    my $toggle_corrs_button = $panel_slot_controls_pane->Button(
        -text    => "Toggle Correspondences",
        -command => sub {
            $self->app_controller()->toggle_corrs_slot(
                window_key => $window_key,
                panel_key  => $panel_key,
                slot_key   => ${$self->{'selected_slot_key_scalar'}},
            );
        },
        -font => $font,
    );
    my $expand_button = $panel_slot_controls_pane->Button(
        -text    => "Add Sub Maps",
        -command => sub {
            $self->app_controller()->expand_slot(
                window_key => $window_key,
                panel_key  => $panel_key,
                slot_key   => ${$self->{'selected_slot_key_scalar'}},
            );
        },
        -font => $font,
    );
    my $scroll_left_button = $panel_slot_controls_pane->Button(
        -text    => "<",
        -command => sub {
            $self->app_controller()->scroll_slot(
                window_key   => $window_key,
                panel_key    => $panel_key,
                slot_key   => ${$self->{'selected_slot_key_scalar'}},
                scroll_value => -10,
            );
        },
        -font => $font,
    );
    my $scroll_right_button = $panel_slot_controls_pane->Button(
        -text    => ">",
        -command => sub {
            $self->app_controller()->scroll_slot(
                window_key   => $window_key,
                panel_key    => $panel_key,
                slot_key   => ${$self->{'selected_slot_key_scalar'}},
                scroll_value => 10,
            );
        },
        -font => $font,
    );
    my $scroll_far_left_button = $panel_slot_controls_pane->Button(
        -text    => "<<",
        -command => sub {
            $self->app_controller()->scroll_slot(
                window_key   => $window_key,
                panel_key    => $panel_key,
                slot_key   => ${$self->{'selected_slot_key_scalar'}},
                scroll_value => -200,
            );
        },
        -font => $font,
    );
    my $scroll_far_right_button = $panel_slot_controls_pane->Button(
        -text    => ">>",
        -command => sub {
            $self->app_controller()->scroll_slot(
                window_key   => $window_key,
                panel_key    => $panel_key,
                slot_key   => ${$self->{'selected_slot_key_scalar'}},
                scroll_value => 200,
            );
        },
        -font => $font,
    );
#    my $test_button = $panel_slot_controls_pane->Button(
#        -text    => "TEST",
#        -command => sub {
#            print STDERR ${$self->{'selected_slot_key_scalar'}} . "\n";
#        },
#        -font => $font,
#    );

    #    Tk::grid( $zoom_label1, -sticky => "nw", );
#    Tk::grid(
#        $test_button, -sticky        => "nw",
#    );
    Tk::grid( $scroll_far_left_button, $scroll_left_button, 'x', 'x',
        $scroll_right_button, $scroll_far_right_button, -sticky => "nw", );
    Tk::grid( 'x','x',$zoom_button1, $toggle_corrs_button, -sticky => "nw", );
    Tk::grid( 'x','x',$zoom_button2, $expand_button,       -sticky => "nw", );
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

    my $canvas_width
        = $panel_layout->{'bounds'}[2] - $panel_layout->{'bounds'}[0] + 1;
    my $canvas_height
        = $panel_layout->{'bounds'}[3] - $panel_layout->{'bounds'}[1] + 1;

    $canvas->configure(
        -scrollregion => $panel_layout->{'bounds'},
       # -height       => 800,#$canvas_height, BF
        -height       => $canvas_height, 
        -width        => $canvas_width,
    );
    $canvas->pack( -side => 'top', -fill => 'both', );

    $self->draw_corrs(
        canvas           => $canvas,
        app_display_data => $app_display_data,
    );

    $self->draw_overview(
        panel_key        => $panel_key,
        canvas           => $canvas,
        app_display_data => $app_display_data,
    );

    $self->layer_tagged_items( canvas => $canvas, );

    return;
}

# ----------------------------------------------------
sub draw_overview {

=pod

=head2 draw_overview

Draws and re-draws on the overview canvas

=cut

    my ( $self, %args ) = @_;
    my $panel_key = $args{'panel_key'}
        or die 'no panel key for draw_overview';
    my $app_display_data = $args{'app_display_data'};

    my $canvas = $self->overview_canvas( panel_key => $panel_key, );

    my $overview_layout = $app_display_data->{'overview_layout'}{$panel_key};
    my $top_slot_key
        = $app_display_data->{'overview'}{$panel_key}{'slot_key'};

    if ( $overview_layout->{'changed'} ) {
        foreach my $drawing_section (qw[ misc_items]) {
            $self->draw_items(
                canvas => $canvas,
                items  => $overview_layout->{$drawing_section},
                tags   => [ 'on_top', ],
            );
        }
        foreach my $button ( @{ $overview_layout->{'buttons'} || [] } ) {
            $self->draw_button(
                canvas => $canvas,
                button => $button,
            );
        }
        $overview_layout->{'changed'} = 0;
    }
    if ( $overview_layout->{'sub_changed'} ) {

        # SLOTS
        foreach my $slot_key ( $top_slot_key,
            @{ $overview_layout->{'child_slot_order'} || [] } )
        {
            $self->draw_overview_slot(
                slot_key             => $slot_key,
                canvas               => $canvas,
                app_display_data     => $app_display_data,
                overview_slot_layout =>
                    $overview_layout->{'slots'}{$slot_key},
            );
        }
        $overview_layout->{'sub_changed'} = 0;
    }

    my $canvas_width
        = $overview_layout->{'bounds'}[2] - $overview_layout->{'bounds'}[0]
        + 1;
    my $canvas_height
        = $overview_layout->{'bounds'}[3] - $overview_layout->{'bounds'}[1]
        + 1;

    $canvas->configure(
        -scrollregion => $overview_layout->{'bounds'},
        -height       => $canvas_height,
        -width        => $canvas_width,
    );

    return;
}

# ----------------------------------------------------
sub draw_overview_slot {

=pod

=head2 draw_overview_slot

Draws and re-draws on the canvas

=cut

    my ( $self, %args ) = @_;
    my $slot_key = $args{'slot_key'}
        or die 'no slot key for draw';
    my $canvas = $args{'canvas'}
        || $self->canvas( panel_key => $args{'panel_key'}, );
    my $app_display_data     = $args{'app_display_data'};
    my $overview_slot_layout = $args{'overview_slot_layout'};

    if ( $overview_slot_layout->{'changed'} ) {
        $self->draw_items(
            canvas => $canvas,
            items  => $overview_slot_layout->{'viewed_region'},
            tags   => [ 'on_bottom', ],
        );
        $self->draw_items(
            canvas => $canvas,
            items  => $overview_slot_layout->{'misc_items'},
            tags   => [ 'on_top', ],
        );
        foreach my $button ( @{ $overview_slot_layout->{'buttons'} || [] } ) {
            $self->draw_button(
                canvas => $canvas,
                button => $button,
            );
        }
        $overview_slot_layout->{'changed'} = 0;
    }
    if ( $overview_slot_layout->{'sub_changed'} ) {

        # MAPS
        foreach my $map_key (
            @{ $app_display_data->{'map_order'}{$slot_key} || {} } )
        {
            my $map_layout = $overview_slot_layout->{'maps'}{$map_key};
            next unless ( $map_layout->{'changed'} );
            $self->draw_items(
                canvas => $canvas,
                items  => $map_layout->{'items'},
                tags   => [ 'on_top', 'overview_map', ],
            );
            $map_layout->{'changed'} = 0;
        }
        $overview_slot_layout->{'sub_changed'} = 0;
    }

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
    my $window_key = $app_display_data->{'scaffold'}{$slot_key}{'window_key'};
    my $panel_key  = $app_display_data->{'scaffold'}{$slot_key}{'panel_key'};

    my $slot_layout = $app_display_data->{'slot_layout'}{$slot_key};
    if ( $slot_layout->{'changed'} ) {
        $self->draw_items(
            canvas => $canvas,
            items  => $slot_layout->{'separator'},
            tags   => [ 'on_top', ],
        );
        $self->draw_items(
            canvas => $canvas,
            items  => $slot_layout->{'background'},
            tags   => [
                'on_bottom',
                'background_'
                    . $window_key . '_'
                    . $panel_key . '_'
                    . $slot_key
            ],
        );
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
                    tags     => [ 'middle_layer', 'display', 'map'],
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
            $map_layout->{'changed'} = 0;
        }
        $slot_layout->{'sub_changed'} = 0;
    }

    return;
}

# ----------------------------------------------------
sub draw_corrs {

=pod

=head2 draw_corrs

Draws and re-draws correspondences on the canvas

This has it's own item drawing code because the offsets for each end of the
corr can be different.

=cut

    my ( $self, %args ) = @_;
    my $canvas = $args{'canvas'}
        || $self->canvas( panel_key => $args{'panel_key'}, );
    my $app_display_data = $args{'app_display_data'};

    my $corr_layout = $app_display_data->{'corr_layout'};

    return unless ( $corr_layout->{'changed'} );

MAP1:
    foreach my $tmp_map_key1 ( keys %{ $corr_layout->{'maps'} || {} } )
    {
    MAP2:
        foreach my $tmp_map_key2 (
            keys %{ $corr_layout->{'maps'}{$tmp_map_key1} || {} } )
        {
            next MAP2
                unless ( $corr_layout->{'maps'}{$tmp_map_key1}{$tmp_map_key2}
                {'changed'} );
            my $map_corr_layout
                = $corr_layout->{'maps'}{$tmp_map_key1}{$tmp_map_key2};
            my $slot_key1 = $map_corr_layout->{'slot_key1'};
            my $slot_key2 = $map_corr_layout->{'slot_key2'};
            my $map_key1  = $map_corr_layout->{'map_key1'};
            my $map_key2  = $map_corr_layout->{'map_key2'};
            my $x_offset1
                = $app_display_data->{'scaffold'}{$slot_key1}{'x_offset'};
            my $x_offset2
                = $app_display_data->{'scaffold'}{$slot_key2}{'x_offset'};
            my $tags = [];

            foreach my $item ( @{ $map_corr_layout->{'items'} || [] } ) {

                # Has item been changed
                next unless ( $item->[0] or not defined( $item->[0] ) );

                my $item_id = $item->[1];
                my $type    = $item->[2];
                my @coords  = @{ $item->[3] };    # creates duplicate array
                my $options = $item->[4];

                $coords[0] -= $x_offset1;
                $coords[2] -= $x_offset2;

                if ( defined($item_id) ) {
                    $canvas->coords( $item_id, @coords );
                    $canvas->itemconfigure( $item_id, %{ $options || {} } );
                }
                else {
                    $canvas->coords( $item_id, @coords );
                    my $create_method = 'create' . ucfirst lc $type;
                    $item->[1]
                        = $canvas->$create_method( @coords, %{$options} );
                    foreach my $tag (@$tags) {
                        $canvas->addtag( $tag, 'withtag', $item->[1] );
                    }
                }
                $item->[0] = 0;
            }
            $map_corr_layout->{'changed'} = 0;

        }
    }
    $corr_layout->{'changed'} = 0;

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
sub move_items {

=pod

=head2 move_items

Move items on the canvas rather than redraw it

The underlying coords in the data structure must be changed externally.

Item structure:

  [ changed, item_id, type, coord_array, options_hash ]

=cut

    my ( $self, %args ) = @_;
    my $panel_key = $args{'panel_key'};
    my $canvas = $args{'canvas'}
        || $self->canvas( panel_key => $args{'panel_key'}, );
    my $x = $args{'x'} || 0;
    my $y = $args{'y'} || 0;
    my $items    = $args{'items'} or return;

    for ( my $i = 0; $i <= $#{ $items || [] }; $i++ ) {
        # make sure item has been drawn
        next unless ( defined( $items->[$i][1] ) );

        my $item_id = $items->[$i][1];
        $canvas->move($item_id, $x, $y);
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
#        $self->{'canvas'}{$panel_key} = $canvas_frame->Scrolled(
#            'Canvas',
#            (   '-width'       => 1100,
#                '-height'      => 800,
#                '-relief'      => 'sunken',
#                '-borderwidth' => 2,
#                '-background'  => 'white',
#                '-scrollbars'  => 's',
#            ),
#        )->pack( -side => 'top', -fill => 'both', );
        $self->{'canvas'}{$panel_key} = $canvas_frame->Canvas(
               '-width'       => 1100,
                '-height'      => 800,
                '-relief'      => 'sunken',
                '-borderwidth' => 2,
                '-background'  => 'white',
           
        )->pack( -side => 'top', -fill => 'both', );
        $self->bind_canvas( canvas => $self->{'canvas'}{$panel_key} );
    }
    return $self->{'canvas'}{$panel_key};
}

# ----------------------------------------------------
sub bind_canvas {

=pod

=head2 bind_canvas

Bind events to a canvas

=cut

    my ( $self, %args ) = @_;
    my $canvas = $args{'canvas'} or return undef;

    $canvas->CanvasBind(
        '<1>' => sub {
            my ($canvas) = @_;
            my $e = $canvas->XEvent;
            $self->start_drag( $canvas, $e->x, $e->y,);
        }
    );
    $canvas->CanvasBind(
        '<B1-ButtonRelease>' => sub {
            my ($canvas) = @_;
            my $e = $canvas->XEvent;
            $self->stop_drag( $canvas, $e->x, $e->y,);
        }
    );
    $canvas->CanvasBind(
        '<B1-Motion>' => sub {
            $self->drag( shift, $Tk::event->x, $Tk::event->y,);
        }
    );
    if ( $^O eq 'MSWin32' ) {
        $canvas->CanvasBind(
            '<MouseWheel>' => sub {
                $self->mouse_wheel_event( $canvas, ( Ev('D') < 0 ) ? 0.5 : 2 );
            }
        );
    }
    else{
        $canvas->CanvasBind(
            '<4>' => sub {
                $self->mouse_wheel_event($canvas, 0.5);
            }
        );
        $canvas->CanvasBind(
            '<5>' => sub {
                $self->mouse_wheel_event($canvas, 2);
            }
        );
        
    }
    
}

# ----------------------------------------------------
sub overview_canvas {

=pod

=head2 overview_canvas

Returns the overview_canvas object.

=cut

    my ( $self, %args ) = @_;
    my $panel_key = $args{'panel_key'} or return undef;

    unless ( $self->{'overview_canvas'}{$panel_key} ) {
        my $overview_canvas_frame
            = $self->{'panel_overview_pane'}{$panel_key};
#        $self->{'overview_canvas'}{$panel_key}
#            = $overview_canvas_frame->Scrolled(
#            'Canvas',
#            (   '-width'       => 1100,
#                '-height'      => 300,
#                '-relief'      => 'sunken',
#                '-borderwidth' => 2,
#                '-background'  => 'white',
#                '-scrollbars'  => 's',
#            ),
#            )->pack( -side => 'top', -fill => 'both', );
        $self->{'overview_canvas'}{$panel_key}
            = $overview_canvas_frame->Canvas(
            '-width'       => 1100,
            '-height'      => 300,
            '-relief'      => 'sunken',
            '-borderwidth' => 2,
            '-background'  => 'white',

            )->pack( -side => 'top', -fill => 'both', );
    }
    return $self->{'overview_canvas'}{$panel_key};
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
        -state   => 'disabled',    # Disabled until map is selected
        -command => sub {

            if ( $map_listbox->curselection() ) {
                $controller->load_new_window(
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
    my $panel_key   = $args{'panel_key'};
    my $items       = $args{'items'} || return;
    my $is_overview = $args{'is_overview'};

    my $canvas =
          $is_overview
        ? $self->overview_canvas( panel_key => $panel_key, )
        : $self->canvas( panel_key => $panel_key, );
    $canvas->delete( map { $_->[1] } @$items );

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

# ----------------------------------------------------
sub layer_tagged_items {

=pod

=head2 layer_tagged_items

Handle the placement of tagged items in layers

=cut

    my ( $self, %args ) = @_;
    my $canvas      = $args{'canvas'};
    #my $real_canvas = $canvas->Subwidget("canvas");
    my $real_canvas = $canvas;

    $real_canvas->raise( 'on_top', 'middle_layer' );
    $real_canvas->lower( 'on_bottom', 'middle_layer' );

    return;
}

# ----------------------------------------------------
sub destroy_slot_controls {

=pod

=head2 destroy_slot_controls

Remove the interface buttons for a slot.

=cut

    my ( $self, %args ) = @_;
    my $panel_key      = $args{'panel_key'};
    my $slot_key      = $args{'slot_key'};
    $self->toggle_slot_pane(
        panel_key => $panel_key,
        slot_key  => $slot_key,
    )->destroy();
    $self->{'toggle_slot_pane'}{$slot_key} = undef;
    return;
}

=pod

=head1 Drag and Drop Methods

=cut

# ----------------------------------------------------
sub start_drag {

=pod

=head2 start_drag

Handle starting drag

=cut

    my $self = shift;
    my ( $canvas, $x, $y, ) = @_;

    $self->{'drag_ori_x'} = $x;
    $self->{'drag_ori_y'} = $y;
    $self->{'drag_ori_id'} = $canvas->find('withtag','current');
    $self->{'drag_last_x'} = $canvas->canvasx($x);
    $self->{'drag_last_y'} = $canvas->canvasy($y);
    if (grep /^map/, $canvas->gettags("current")){
        return unless ($self->{'drag_ori_id'});
        $self->{'drag_obj'} = 'map';
        $self->{'ghost_map_id'} = $canvas->createRectangle(
            ( $canvas->bbox('current') ),
            ( '-outline' => 'grey', ),
        );
    }
    elsif (my @tags = grep /^background_/, $canvas->gettags("current")){
        $tags[0] =~ /^background_(\S+)_(\S+)_(\S+)/;
        $self->{'drag_window_key'} = $1;
        $self->{'drag_panel_key'} = $2;
        $self->{'drag_slot_key'} = $3;
        $self->{'drag_obj'} = 'background';
    }

}    # end start_drag

# ----------------------------------------------------
sub drag {

=pod

=head2 drag

Handle the drag event

=cut

    my $self = shift;
    my ( $canvas, $x, $y, ) = @_;
    return unless ($self->{'drag_ori_id'});
    $x = $canvas->canvasx($x);
    $y = $canvas->canvasy($y);
    my $dx = $x - $self->{'drag_last_x'};
    my $dy = $y - $self->{'drag_last_y'};

    if ($self->{'drag_obj'} eq 'map'){
        $canvas->move( $self->{'ghost_map_id'}, $dx,0, );
        $canvas->configure(-scrollregion =>[$canvas->bbox('all')]);
    }
    elsif ( $self->{'drag_obj'} eq 'background' ) {
        $self->app_controller()->scroll_slot(
            window_key   => $self->{'drag_window_key'},
            panel_key    => $self->{'drag_panel_key'},
            slot_key     => $self->{'drag_slot_key'},
            scroll_value => $dx * -1,
        );
    }

    $self->{drag_last_x} = $x;
    $self->{drag_last_y} = $y;

}

# ----------------------------------------------------
sub stop_drag {

=pod

=head2 stop_drag

Handle the stopping drag event

=cut

    my $self = shift;
    my ( $canvas, $x, $y, ) = @_;

    return unless ($self->{'drag_ori_id'});
    # Move original object
    $x = $canvas->canvasx($x);
    my $dx = $x - $self->{'drag_ori_x'};
    if ($self->{'drag_obj'} eq 'map'){
    #    $canvas->move( $self->{'drag_ori_id'}, $dx,0, );
        $canvas->delete($self->{'ghost_map_id'});
        $self->{'ghost_map_id'} = undef;

    }
    $self->{'drag_ori_id'} = undef;
    $self->{'drag_ori_x'} = undef;
    $self->{'drag_ori_y'} = undef;
    $self->{'drag_obj'} = undef;

}    # end start_drag

# ----------------------------------------------------
sub mouse_wheel_event {

=pod

=head2 mouse_wheel_event

Handle the mouse wheel events

=cut

    my $self = shift;
    my ( $canvas, $value ) = @_;

    if ( my @tags = grep /^background_/, $canvas->gettags("current") ) {
        $tags[0] =~ /^background_(\S+)_(\S+)_(\S+)/;
        my $window_key = $1;
        my $panel_key  = $2;
        my $slot_key   = $3;
        
        $self->app_controller()->zoom_slot(
            window_key => $window_key,
            panel_key  => $panel_key,
            slot_key   => $slot_key,
            zoom_value => $value,
        );
    }

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

