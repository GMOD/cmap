package Bio::GMOD::CMap::Drawer::AppInterface;

# vim: set ft=perl:

# $Id: AppInterface.pm,v 1.36 2007-03-14 15:09:30 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.36 $)[-1];

use Bio::GMOD::CMap::Constants;
use Data::Dumper;
use base 'Bio::GMOD::CMap::AppController';
use Tk;
use Tk::Zinc;
use Tk::Pane;
use Tk::Dialog;
use Tk::LabEntry;

use constant BETWEEN_SLOT_BUFFER => 5;

# ----------------------------------------------------
sub init {

=pod

=head2 init

Initializes the drawing object.

=cut

    my ( $self, $config ) = @_;
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
    $self->{'windows'}{$window_key}->bind(
        '<Configure>' => sub {
            my $event = $self->{'windows'}{$window_key}->XEvent;
            if ($event) {
                $self->window_configure_event( $event, $window_key,
                    $app_display_data, );
            }
        },
    );

    $self->menu_bar( window_key => $window_key, );
    $self->populate_menu_bar( window_key => $window_key, );
    $self->top_pane( window_key => $window_key, );
    $self->bottom_pane( window_key => $window_key, );
    $self->middle_pane( window_key => $window_key, );
    $self->pack_panes( $window_key, $app_display_data, );

    # Window Bindings
    $self->{'windows'}{$window_key}->protocol(
        'WM_DELETE_WINDOW',
        sub {
            $self->app_controller->close_window( window_key => $window_key, );
        }
    );
    $self->{'windows'}{$window_key}
        ->bind( '<Control-Key-q>' => sub { exit; }, );

# BF RE ADD THESE
#    $self->{'windows'}{$window_key}->bind(
#        '<Control-Key-l>' => sub {
#            $self->app_controller()
#                ->new_reference_maps( window_key => $window_key, );
#        },
#    );
#    $self->{'windows'}{$window_key}->bind(
#        '<Control-Key-e>' => sub {
#            $self->export_map_moves( window_key => $window_key, );
#        },
#    );
#    $self->{'windows'}{$window_key}->bind(
#        '<Control-Key-z>' => sub {
#            $self->app_controller()
#                ->app_display_data->undo_action( window_key => $window_key, );
#        },
#    );
#    $self->{'windows'}{$window_key}->bind(
#        '<Control-Key-y>' => sub {
#            $self->app_controller()
#                ->app_display_data->redo_action( window_key => $window_key, );
#        },
#    );
    return $window_key;
}

# ----------------------------------------------------
sub int_create_zone_controls {

    #print STDERR "AI_NEEDS_MODDED 1\n";

=pod

=head2 int_create_zone_controls

This method will create the zone controls for the panel.

=cut

    my ( $self, %args ) = @_;
    my $window_key       = $args{'window_key'} or return;
    my $app_display_data = $args{'app_display_data'};

    foreach
        my $zone_key ( @{ $app_display_data->{'zone_order'}{$window_key} } )
    {
        $self->add_zone_controls(
            window_key       => $window_key,
            zone_key         => $zone_key,
            app_display_data => $app_display_data,
        );
    }
    ${ $self->{'selected_zone_key_scalar'} }
        = $app_display_data->{'zone_order'}{$window_key}[0] || 0;

    return;
}

# ----------------------------------------------------
sub add_zone_controls {

    #print STDERR "AI_NEEDS_MODDED 2\n";

=pod

=head2 add_zone_controls

This method will create the zone controls for one zone

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $zone_key   = $args{'zone_key'}   or return;
    my $app_display_data = $args{'app_display_data'};

    $self->toggle_zone_pane(
        zone_key         => $zone_key,
        app_display_data => $app_display_data,
    );

    my $zone_label = $self->_get_zone_label(
        window_key       => $window_key,
        zone_key         => $zone_key,
        app_display_data => $app_display_data,
    );

    Tk::grid( $zone_label, -sticky => "ne", );

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
sub app_data_module {

=pod

=head3 app_data_module

Returns a handle to the data module.

Gets the data module from the controller.  It is done here rather than during
init so avoid infinite loops.

=cut

    my $self = shift;

    unless ( $self->{'app_data_module'} ) {
        $self->{'app_data_module'}
            = $self->app_controller()->app_data_module();
    }

    return $self->{'app_data_module'};
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
sub top_pane {

=pod

=head2 top_pane

Returns the top_pane object.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return undef;
    unless ( $self->{'top_pane'}{$window_key} ) {
        my $window_key = $args{'window_key'} or return undef;
        my $window = $self->{'windows'}{$window_key};
        $self->{'top_pane'}{$window_key} = $window->Frame(
            -relief     => 'groove',
            -border     => 1,
            -background => "white",
        );

        # Pack later in pack_panes()
        $self->overview_zinc( window_key => $window_key, );
    }
    return $self->{'top_pane'}{$window_key};
}

# ----------------------------------------------------
sub zinc_pane {

=pod

=head2 zinc_pane

Returns the zinc_pane object.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return undef;
    unless ( $self->{'zinc_pane'}{$window_key} ) {
        my $middle_pane = $self->{'middle_pane'}{$window_key};
        $self->{'zinc_pane'}{$window_key} = $middle_pane->Frame(
            -relief     => 'groove',
            -border     => 0,
            -background => "blue",
        );
        $self->zinc( window_key => $window_key, );

        # Pack later in pack_panes()
    }
    return $self->{'zinc_pane'}{$window_key};
}

# ----------------------------------------------------
sub middle_pane {

=pod

=head2 middle_pane

Returns the middle_pane object.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return undef;

    unless ( $self->{'middle_pane'}{$window_key} ) {
        my $y_val  = $args{'y_val'};
        my $height = $args{'height'};
        my $window = $self->{'windows'}{$window_key};
        $self->{'middle_pane'}{$window_key} = $window->Scrolled(
            "Pane",
            -scrollbars => "oe",
            -background => "white",
            -height     => $window->screenheight(),
        );
        $self->zinc_pane( window_key => $window_key, );

        # Pack later in pack_panes()
    }
    return $self->{'middle_pane'}{$window_key};
}

# ----------------------------------------------------
sub bottom_pane {

=pod

=head2 bottom_pane

Returns the bottom_pane object.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return undef;
    unless ( $self->{'bottom_pane'}{$window_key} ) {
        my $y_val  = $args{'y_val'};
        my $height = $args{'height'};
        my $window = $self->{'windows'}{$window_key};
        $self->{'bottom_pane'}{$window_key} = $window->Frame(
            -borderwidth => 0,
            -relief      => 'groove',
            -background  => "white",
        );
        $self->info_pane(
            window_key => $window_key,
            window_key => $window_key,
        );
        $self->controls_pane(
            window_key => $window_key,
            window_key => $window_key,
        );

        # Pack later in pack_panes()
    }
    return $self->{'bottom_pane'}{$window_key};
}

# ----------------------------------------------------
sub info_pane {

=pod

=head2 info_pane

Returns the info_pane object.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return undef;
    unless ( $self->{'info_pane'}{$window_key} ) {
        my $y_val    = $args{'y_val'};
        my $height   = $args{'height'};
        my $top_pane = $self->{'top_pane'}{$window_key};
        $self->{'info_pane'}{$window_key} = $top_pane->Frame(
            -borderwidth => 0,
            -relief      => 'groove',
            -background  => "white",
        );
        $self->_add_info_widgets( window_key => $window_key, );

        # Pack later in pack_panes()
    }
    return $self->{'info_pane'}{$window_key};
}

# ----------------------------------------------------
sub controls_pane {

=pod

=head2 controls_pane

Returns the controls_pane object.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return undef;
    unless ( $self->{'controls_pane'}{$window_key} ) {
        my $y_val       = $args{'y_val'};
        my $height      = $args{'height'};
        my $bottom_pane = $self->{'bottom_pane'}{$window_key};
        if (1) {
            $self->{'controls_pane'}{$window_key} = $bottom_pane->Frame(
                -borderwidth => 0,
                -relief      => 'groove',
                -background  => "white",
            );
        }
        else {
            $self->{'controls_pane'}{$window_key} = $bottom_pane->Scrolled(
                "Pane",

                #-scrollbars => "oe",
                #-relief     => 'groove',
                -background => "blue",
            );
        }
        $self->_add_zone_control_widgets( window_key => $window_key, );

        # Pack later in pack_panes()
    }
    return $self->{'controls_pane'}{$window_key};
}

# ----------------------------------------------------
sub _get_zone_label {

    #print STDERR "AI_NEEDS_MODDED 4\n";

=pod

=head2 _get_zone_label

Gets Map set label 

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $zone_key   = $args{'zone_key'}   or return;
    my $app_display_data = $args{'app_display_data'};
    my $toggle_zone_pane = $self->{'toggle_zone_pane'}{$zone_key};
    my $font             = [
        -family => 'Times',
        -size   => 12,
    ];
    my $controller = $self->app_controller();
    my $map_set_id = $controller->app_display_data->{'scaffold'}{$zone_key}
        {'map_set_id'};
    my $map_set_data = $self->app_data_module()
        ->get_map_set_data( map_set_id => $map_set_id, );

    return $toggle_zone_pane->Label(
        -text => $map_set_data->{'species_common_name'} . " "
            . $map_set_data->{'map_set_short_name'},
        -background => "white",
    );

}

# ----------------------------------------------------
sub _add_info_widgets {

=pod

=head2 _add_info_widgets

Adds information widgets to the info pane 

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $info_pane  = $self->{'info_pane'}{$window_key};
    my $font       = [ 'Times', 12, ];

    $self->{'information_text'} = $info_pane->Text(
        -font       => $font,
        -background => "white",
        -width      => 40,
        -height     => 3,
    );
    $self->{'information_text'}
        ->insert( 'end', "Click on a map to display information." );
    $self->{'information_text'}->configure( -state => 'disabled', );

    Tk::grid( $self->{'information_text'}, -sticky => "nw", );
    return;
}

# ----------------------------------------------------
sub _add_zone_control_widgets {

=pod

=head2 _add_zone_control_widgets

Adds control buttons to the controls_pane.

=cut

    my ( $self, %args ) = @_;
    my $window_key    = $args{'window_key'} or return;
    my $controls_pane = $self->{'controls_pane'}{$window_key};
    my $font          = [
        -family => 'Times',
        -size   => 12,
    ];

    $self->{'selected_map_set_text_box'} = $controls_pane->Text(
        -font       => $font,
        -background => "white",
        -width      => 40,
        -height     => 1,
    );
    my $zoom_button1 = $controls_pane->Button(
        -text    => "Zoom In",
        -command => sub {
            $self->app_controller()->zoom_zone(
                window_key => $window_key,
                zone_key   => ${ $self->{'selected_zone_key_scalar'} },
                zoom_value => 2,
            );
        },
        -font => $font,
    );
    my $zoom_button2 = $controls_pane->Button(
        -text    => "Zoom Out",
        -command => sub {
            $self->app_controller()->zoom_zone(
                window_key => $window_key,
                zone_key   => ${ $self->{'selected_zone_key_scalar'} },
                zoom_value => .5,
            );
        },
        -font => $font,
    );
    my $toggle_corrs_button = $controls_pane->Button(
        -text    => "Toggle Correspondences",
        -command => sub {
            $self->app_controller()->toggle_corrs_zone(
                window_key => $window_key,
                zone_key   => ${ $self->{'selected_zone_key_scalar'} },
            );
        },
        -font => $font,
    );
    my $expand_button = $controls_pane->Button(
        -text    => "Add Sub Maps",
        -command => sub {
            $self->app_controller()->expand_zone(
                window_key => $window_key,
                zone_key   => ${ $self->{'selected_zone_key_scalar'} },
            );
        },
        -font => $font,
    );
    my $reattach_button = $controls_pane->Button(
        -text    => "Reattach Slot to Parent",
        -command => sub {
            $self->app_controller()->app_display_data()->reattach_zone(
                window_key => $window_key,
                zone_key   => ${ $self->{'selected_zone_key_scalar'} },
            );
        },
        -font => $font,
    );
    my $scroll_left_button = $controls_pane->Button(
        -text    => "<",
        -command => sub {
            $self->app_controller()->scroll_zone(
                window_key   => $window_key,
                zone_key     => ${ $self->{'selected_zone_key_scalar'} },
                scroll_value => 10,
            );
        },
        -font => $font,
    );
    my $scroll_type_1 = $controls_pane->Button(
        -text    => ">",
        -command => sub {
            $self->app_controller()->scroll_zone(
                window_key   => $window_key,
                zone_key     => ${ $self->{'selected_zone_key_scalar'} },
                scroll_value => -10,
            );
        },
        -font => $font,
    );
    my $scroll_far_left_button = $controls_pane->Button(
        -text    => "<<",
        -command => sub {
            $self->app_controller()->scroll_zone(
                window_key   => $window_key,
                zone_key     => ${ $self->{'selected_zone_key_scalar'} },
                scroll_value => 200,
            );
        },
        -font => $font,
    );
    my $scroll_far_type_1 = $controls_pane->Button(
        -text    => ">>",
        -command => sub {
            $self->app_controller()->scroll_zone(
                window_key   => $window_key,
                zone_key     => ${ $self->{'selected_zone_key_scalar'} },
                scroll_value => -200,
            );
        },
        -font => $font,
    );

    my $show_features_check_box = $controls_pane->Checkbutton(
        -text     => "Show Features",
        -variable => \$self->{'show_features'},
        -command  => sub {
            $self->app_controller()->app_display_data()
                ->change_feature_status(
                zone_key      => ${ $self->{'selected_zone_key_scalar'} },
                show_features => $self->{'show_features'},
                );
        },
        -font => $font,
    );
    $self->{'attach_to_parent_check_box'} = $controls_pane->Checkbutton(
        -text     => "Attached to Parent",
        -variable => \$self->{'attached_to_parent'},
        -command  => sub {
            if ( $self->{'attached_to_parent'} ) {
                print STDERR "DETACH\n";

                #$self->app_controller()->app_display_data()->reattach_zone(
                #window_key => $window_key,
                #zone_key   => ${ $self->{'selected_zone_key_scalar'} },
                #);
            }
            else {
                print STDERR "ATTACH\n";

                #$self->app_controller()->app_display_data()->reattach_zone(
                #window_key => $window_key,
                #zone_key   => ${ $self->{'selected_zone_key_scalar'} },
                #);
            }
        },
        -font => $font,
    );
    Tk::grid(
        $self->{'selected_map_set_text_box'}, '-', '-', '-', '-',
        '-', $toggle_corrs_button,    #$reattach_button,
        -sticky => "nw",
    );
    Tk::grid(
        $scroll_far_left_button, $scroll_left_button,
        $zoom_button1,           $zoom_button2,
        $scroll_type_1,          $scroll_far_type_1,

        $expand_button,               # $show_features_check_box,
            # $self->{'attach_to_parent_check_box'}, -sticky => "nw",
    );
    return;
}

# ----------------------------------------------------
sub populate_menu_bar {

=pod

=head2 populate_menu_bar

Populates the menu_bar object.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return undef;

    $self->{'menu_bar_order'}{$window_key} = [ 'file', 'edit', ];

    $self->file_menu_items( window_key => $window_key, );
    $self->edit_menu_items( window_key => $window_key, ),

        $self->app_controller()->plugin_set()
        ->modify_main_menu( window_key => $window_key, );

    my $menu_bar = $self->menu_bar( window_key => $window_key, );

    foreach my $menu_title ( @{ $self->{'menu_bar_order'}{$window_key} } ) {
        $self->{'menu_buttons'}{$window_key}{$menu_title}
            = $menu_bar->cascade(
            -label     => '~' . $menu_title,
            -menuitems => $self->{'menu_items'}{$window_key}{$menu_title},
            );
    }

    return;
}

# ----------------------------------------------------
sub draw_window {

=pod

=head2 draw

Draws and re-draws on the zinc

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'}
        or die 'no window key for draw';
    my $app_display_data = $args{'app_display_data'};

    my $zinc = $self->zinc( window_key => $window_key, );

    my $window_layout = $app_display_data->{'window_layout'}{$window_key};
    if ( $window_layout->{'changed'} ) {
        foreach my $drawing_section (qw[ misc_items ]) {
            $self->draw_items(
                zinc  => $zinc,
                items => $window_layout->{$drawing_section},
                tags  => [ 'on_top', ],
            );
        }
        $window_layout->{'changed'} = 0;
    }
    if ( $window_layout->{'sub_changed'} ) {

        # SLOTS
        foreach my $zone_key (
            sort { $a cmp $b }
            keys %{ $app_display_data->{'zone_in_window'}{$window_key} || {} }
            )
        {
            $self->draw_zone(
                zone_key         => $zone_key,
                zinc             => $zinc,
                app_display_data => $app_display_data,
            );
        }
        $window_layout->{'sub_changed'} = 0;
    }

    my $zinc_width
        = $window_layout->{'bounds'}[2] - $window_layout->{'bounds'}[0] + 1;
    my $zinc_height
        = $window_layout->{'bounds'}[3] - $window_layout->{'bounds'}[1] + 1;

    $zinc->configure(
        -scrollregion => $window_layout->{'bounds'},
        -height       => $zinc_height,
        -width        => $zinc_width,
    );

    $self->draw_corrs(
        zinc             => $zinc,
        app_display_data => $app_display_data,
    );

    $self->draw_overview(
        window_key       => $window_key,
        app_display_data => $app_display_data,
    );

    $self->layer_tagged_items( zinc => $zinc, );

    return;
}

# ----------------------------------------------------
sub draw_overview {

=pod

=head2 draw_overview

Draws and re-draws on the overview zinc

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'}
        or die 'no panel key for draw_overview';
    my $app_display_data = $args{'app_display_data'};

    my $zinc = $self->overview_zinc( window_key => $window_key, );

    my $overview_layout = $app_display_data->{'overview_layout'}{$window_key};
    my $top_zone_key
        = $app_display_data->{'overview'}{$window_key}{'zone_key'};

    if ( $overview_layout->{'changed'} ) {
        foreach my $drawing_section (qw[ misc_items]) {
            $self->draw_items(
                zinc  => $zinc,
                items => $overview_layout->{$drawing_section},
                tags  => [ 'on_top', ],
            );
        }
        $overview_layout->{'changed'} = 0;
    }
    if ( $overview_layout->{'sub_changed'} ) {

        foreach my $zone_key ( $top_zone_key,
            @{ $overview_layout->{'child_zone_order'} || [] } )
        {
            $self->draw_overview_zone(
                window_key           => $window_key,
                zone_key             => $zone_key,
                zinc                 => $zinc,
                app_display_data     => $app_display_data,
                overview_zone_layout =>
                    $overview_layout->{'zones'}{$zone_key},
            );
        }
        $overview_layout->{'sub_changed'} = 0;
    }

    my $zinc_width = $overview_layout->{'internal_bounds'}[2]
        - $overview_layout->{'internal_bounds'}[0] + 1;
    my $zinc_height = $overview_layout->{'internal_bounds'}[3]
        - $overview_layout->{'internal_bounds'}[1] + 1;

    $zinc->configure(
        -scrollregion => $overview_layout->{'bounds'},
        -height       => $zinc_height,
        -width        => $zinc_width,
    );

    $self->layer_tagged_items(
        zinc => $self->overview_zinc( window_key => $window_key, ) );

    return;
}

# ----------------------------------------------------
sub draw_overview_zone {

=pod

=head2 draw_overview_zone

Draws and re-draws on the zinc

=cut

    my ( $self, %args ) = @_;
    my $zone_key = $args{'zone_key'}
        or die 'no zone key for draw';
    my $window_key = $args{'window_key'};
    my $zinc       = $args{'zinc'}
        || $self->zinc( window_key => $args{'window_key'}, );
    my $depth                = $args{'depth'} || 0;
    my $app_display_data     = $args{'app_display_data'};
    my $overview_zone_layout = $args{'overview_zone_layout'};

    my $zone_group_id = $self->get_zone_group_id(
        window_key       => $window_key,
        zone_key         => $zone_key,
        zinc             => $zinc,
        overview         => 1,
        app_display_data => $app_display_data,
    );

    $zinc->coords(
        $zone_group_id,
        [   $overview_zone_layout->{'bounds'}[0],
            $overview_zone_layout->{'bounds'}[1]
        ]
    );

    if ( $overview_zone_layout->{'changed'} ) {
        $self->draw_items(
            zinc     => $zinc,
            items    => $overview_zone_layout->{'viewed_region'},
            group_id => $zone_group_id,
            tags     => [
                'on_bottom', 'viewed_region_' . $window_key . '_' . $zone_key,
            ],
        );
        $self->draw_items(
            zinc     => $zinc,
            items    => $overview_zone_layout->{'misc_items'},
            group_id => $zone_group_id,
            tags     => [ 'on_top', ],
        );
        $overview_zone_layout->{'changed'} = 0;
    }
    if ( $overview_zone_layout->{'sub_changed'} ) {

        # MAPS
        foreach my $map_key (
            @{ $app_display_data->{'map_order'}{$zone_key} || {} } )
        {
            my $map_layout = $overview_zone_layout->{'maps'}{$map_key};
            next unless ( $map_layout->{'changed'} );
            $self->draw_items(
                zinc     => $zinc,
                items    => $map_layout->{'items'},
                group_id => $zone_group_id,
                tags     => [ 'on_top', 'overview_map', ],
            );
            $map_layout->{'changed'} = 0;
        }
        $overview_zone_layout->{'sub_changed'} = 0;
    }

    return;
}

# ----------------------------------------------------
sub draw_zone {

=pod

=head2 draw_zone

Draws and re-draws on the zinc

=cut

    my ( $self, %args ) = @_;
    my $zone_key = $args{'zone_key'}
        or die 'no zone key for draw';
    my $zinc = $args{'zinc'}
        || $self->zinc( window_key => $args{'window_key'}, );
    my $app_display_data = $args{'app_display_data'};
    my $window_key = $app_display_data->{'scaffold'}{$zone_key}{'window_key'};

    my $parent_zone_key
        = $app_display_data->{'scaffold'}{$zone_key}{'parent_zone_key'};

    my $zone_x_offset
        = $app_display_data->{'scaffold'}{$zone_key}->{'x_offset'};
    my $zone_y_offset = 0;

    my $parent_zone_x_offset =
        ($parent_zone_key)
        ? $app_display_data->{'scaffold'}{$parent_zone_key}->{'x_offset'}
        : 0;

    my $zone_group_id = $self->get_zone_group_id(
        window_key       => $window_key,
        zone_key         => $zone_key,
        zinc             => $zinc,
        app_display_data => $app_display_data,
    );

    my $zone_layout = $app_display_data->{'zone_layout'}{$zone_key};
    if ( $zone_layout->{'changed'} ) {
        $zinc->coords(
            $zone_group_id,
            [   $parent_zone_x_offset + $zone_layout->{'bounds'}[0],
                $zone_layout->{'bounds'}[1]
            ]
        );
        $self->set_zone_clip(
            zone_key      => $zone_key,
            zone_group_id => $zone_group_id,
            zinc          => $zinc,
            zone_layout   => $zone_layout,
        );

        $self->draw_items(
            zinc     => $zinc,
            x_offset => $zone_x_offset,
            y_offset => $zone_y_offset,
            items    => $zone_layout->{'separator'},
            group_id => $zone_group_id,
            tags     => [ 'on_top', ],
        );

        $self->draw_items(
            zinc     => $zinc,
            x_offset => 0,                              #$zone_x_offset,
            y_offset => 0,                              #$zone_y_offset,
            items    => $zone_layout->{'background'},
            group_id => $zone_group_id,
            tags     => [
                'on_bottom', 'background_' . $window_key . '_' . $zone_key
            ],
        );

# The following places bars on the slot for debugging
#my @colors = ('red','black','blue','green','yellow','purple','orange','black','green','red','blue',);
#for ( my $i = 1; $i <= 10; $i++ ) {
#    $self->draw_items(
#        zinc     => $zinc,
#        x_offset => 0,       #$zone_x_offset,
#        y_offset => 0,       #$zone_y_offset,
#        items    => [
#            [   1, undef, 'curve',
#                [ $i*100, 10, $i*100, 100 ],
#                { -linecolor => $colors[$i-1], -linewidth => '3', }
#            ],
#            [   1, undef, 'text',
#            [ $i*100, 2 ],
#        {   -text   => $i*100,
#            -anchor => 'nw',
#            -color  => 'black',
#        }
#    ],
#        ],
#        group_id => $zone_group_id,
#        tags     => [ 'on_top', ],
#    );
#}
        $zone_layout->{'changed'} = 0;
    }
    if ( $zone_layout->{'sub_changed'} ) {

        # MAPS
        foreach my $map_key (
            @{ $app_display_data->{'map_order'}{$zone_key} || {} } )
        {
            my $map_layout = $app_display_data->{'map_layout'}{$map_key};

            # Debug
            #    $self->draw_items(
            #        zinc     => $zinc,
            #        x_offset => $zone_x_offset,
            #        y_offset => $zone_y_offset,
            #        items    => [
            #            [   1, undef, 'rectangle',
            #                $map_layout->{'bounds'},
            #                { -linecolor => 'red', -linewidth => '3', }
            #            ],
            #        ],
            #        group_id => $zone_group_id,
            #        tags     => [ 'on_top', ],
            #    );
            foreach my $drawing_section (qw[ items ]) {
                $self->draw_items(
                    zinc     => $zinc,
                    x_offset => $zone_x_offset,
                    y_offset => $zone_y_offset,
                    items    => $map_layout->{$drawing_section},
                    tags     => [
                        'middle_layer',
                        'display',
                        'map_'
                            . $window_key . '_'
                            . $zone_key . '_'
                            . $map_key
                    ],
                    group_id => $zone_group_id,
                );
            }
            $self->record_map_key_drawn_id(
                map_key => $map_key,
                items   => $map_layout->{'items'},
            );
            if ( $map_layout->{'sub_changed'} ) {

                # Features
                foreach my $feature_acc (
                    keys %{ $map_layout->{'features'} || {} } )
                {
                    my $feature_layout
                        = $map_layout->{'features'}{$feature_acc};
                    $self->draw_items(
                        zinc     => $zinc,
                        x_offset => $zone_x_offset,
                        y_offset => $zone_y_offset,
                        items    => $feature_layout->{'items'},
                        group_id => $zone_group_id,
                        tags     => [ 'feature', 'display', ],
                    );
                    $self->record_feature_acc_drawn_id(
                        feature_acc => $feature_acc,
                        items       => $feature_layout->{'items'},
                    );
                }
                $map_layout->{'sub_changed'} = 0;
            }
            $map_layout->{'changed'} = 0;
        }
        $zone_layout->{'sub_changed'} = 0;
    }

    # Raise this zone above the earlier zones
    $zinc->raise( $zone_group_id, );

    return;
}

# ----------------------------------------------------
sub draw_corrs {

=pod

=head2 draw_corrs

Draws and re-draws correspondences on the zinc

This has it's own item drawing code because the offsets for each end of the
corr can be different.

=cut

    my ( $self, %args ) = @_;
    my $zinc = $args{'zinc'}
        || $self->zinc( window_key => $args{'window_key'}, );
    my $app_display_data = $args{'app_display_data'};

    # The group id will be 1 because we are drawing this right on the zinc
    # surface.
    my $group_id = 1;

    my $corr_layout = $app_display_data->{'corr_layout'};

    return unless ( $corr_layout->{'changed'} );

MAP1:
    foreach my $tmp_map_key1 ( keys %{ $corr_layout->{'maps'} || {} } ) {
    MAP2:
        foreach my $tmp_map_key2 (
            keys %{ $corr_layout->{'maps'}{$tmp_map_key1} || {} } )
        {
            next MAP2
                unless ( $corr_layout->{'maps'}{$tmp_map_key1}{$tmp_map_key2}
                {'changed'} );
            my $map_corr_layout
                = $corr_layout->{'maps'}{$tmp_map_key1}{$tmp_map_key2};
            my $zone_key1 = $map_corr_layout->{'zone_key1'};
            my $zone_key2 = $map_corr_layout->{'zone_key2'};
            my $map_key1  = $map_corr_layout->{'map_key1'};
            my $map_key2  = $map_corr_layout->{'map_key2'};
            my $x_offset1
                = $app_display_data->{'scaffold'}{$zone_key1}{'x_offset'};
            my $x_offset2
                = $app_display_data->{'scaffold'}{$zone_key2}{'x_offset'};
            my $tags = [];

            foreach my $item ( @{ $map_corr_layout->{'items'} || [] } ) {

                # Has item been changed
                next unless ( $item->[0] or not defined( $item->[0] ) );

                my $item_id = $item->[1];
                my $type    = $item->[2];
                my @coords  = @{ $item->[3] };    # creates duplicate array
                my $options = $item->[4];

                $coords[0] += $x_offset1;
                $coords[2] += $x_offset2;

                if ( defined($item_id) ) {
                    $zinc->coords( $item_id, \@coords );
                    $zinc->itemconfigure( $item_id, %{ $options || {} } );
                }
                else {
                    if ( $type eq 'text' ) {
                        $item->[1] = $zinc->add(
                            $type, $group_id,
                            -position => \@coords,
                            %{$options},
                        );
                    }
                    else {
                        $item->[1] = $zinc->add( $type, $group_id, \@coords,
                            %{$options}, );
                    }

                    foreach my $tag (@$tags) {
                        $zinc->addtag( $tag, 'withtag', $item->[1] );
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

    #print STDERR "AI_NEEDS_MODDED 11\n";

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

    my $zinc = $self->zinc( window_key => $window_key, );

    my $item_id = $zinc->createText(
        ( $x1, $y1 ),
        (   '-text'   => $text,
            '-anchor' => 'nw',

            #-font => $font_string,
        )
    );
    return ( $item_id, [ $zinc->bbox($item_id) ] );
}

# ----------------------------------------------------
sub get_zone_key_from_drawn_id {

    #print STDERR "AI_NEEDS_MODDED 13\n";

=pod

=head2 get_zone_key_from_drawn_id

Given a zinc object ID, return the zone_key that it belongs to.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $drawn_id   = $args{'drawn_id'};
    my $zinc       = $args{'zinc'};

    return;

}

# ----------------------------------------------------
sub get_zone_group_id {

=pod

=head2 get_zone_group_id

Gets the group_id for a zone.  If it doesn't exist, this will create a new
group.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $zone_key   = $args{'zone_key'}
        or die 'no zone key for draw';
    my $zinc = $args{'zinc'}
        || $self->zinc( window_key => $args{'window_key'}, );
    my $overview         = $args{'overview'} || 0;
    my $app_display_data = $args{'app_display_data'};

    my $storage_key = $overview ? 'ov_zone_group_id' : 'zone_group_id';
    my $rev_storage_key
        = $overview ? 'ov_group_to_zone_key' : 'zone_group_to_zone_key';

    unless ( $self->{$storage_key}{$window_key}{$zone_key} ) {
        my $parent_group_id;
        if (    $overview
            and $app_display_data->{'overview'}
            { $app_display_data->{'scaffold'}{$zone_key}{'window_key'} }
            {'zone_key'} == $zone_key )
        {
            $parent_group_id = 1;
        }
        elsif ( my $parent_zone_key
            = $app_display_data->{'scaffold'}{$zone_key}{'parent_zone_key'} )
        {
            $parent_group_id = $self->get_zone_group_id(
                window_key       => $window_key,
                zone_key         => $parent_zone_key,
                zinc             => $zinc,
                overview         => $overview,
                app_display_data => $app_display_data,
            );
        }
        else {
            $parent_group_id = 1;
        }
        my $group_id = $zinc->add( "group", $parent_group_id, );
        $self->{$storage_key}{$window_key}{$zone_key}     = $group_id;
        $self->{$rev_storage_key}{$window_key}{$group_id} = $zone_key;
    }

    return $self->{$storage_key}{$window_key}{$zone_key};
}

# ----------------------------------------------------
sub set_zone_clip {

=pod

=head2 set_zone_clip

Sets the group clip object

=cut

    my ( $self, %args ) = @_;
    my $zone_key = $args{'zone_key'}
        or die 'no zone key set_zone_clip';
    my $zone_group_id = $args{'zone_group_id'}
        or die 'no zone group_id set_zone_clip';
    my $zinc = $args{'zinc'}
        || $self->zinc( window_key => $args{'window_key'}, );
    my $zone_layout = $args{'zone_layout'};

    #my $fillcolor = ( $zone_key == 1 ) ? 'green' : 'red';
    my $clip_bounds = [

        #$zone_layout->{'viewable_internal_x1'},
        $zone_layout->{'internal_bounds'}[0],
        $zone_layout->{'internal_bounds'}[1],
        $zone_layout->{'internal_bounds'}[2],

        #$zone_layout->{'viewable_internal_x2'},
        $zone_layout->{'internal_bounds'}[3]
    ];
    unless ( $self->{'zone_group_clip_id'}{$zone_key} ) {
        $self->{'zone_group_clip_id'}{$zone_key} = $zinc->add(
            'rectangle', $zone_group_id,
            $clip_bounds,
            -visible => 0,

            #-filled    => 1,
            #-fillcolor => $fillcolor,
        );
        $zinc->itemconfigure( $zone_group_id,
            -clip => $self->{'zone_group_clip_id'}{$zone_key}, );
    }
    else {
        $zinc->coords( $self->{'zone_group_clip_id'}{$zone_key}, $clip_bounds,
        );
    }
    $zinc->itemconfigure( $zone_group_id,
        -clip => $self->{'zone_group_clip_id'}{$zone_key}, );

    return $self->{'zone_group_id'}{$zone_key};
}

# ----------------------------------------------------
sub draw_items {

=pod

=head2 draw_items

Draws items on the zinc.

Item structure:

  [ changed, item_id, type, coord_array, options_hash ]

=cut

    my ( $self, %args ) = @_;
    my $zinc     = $args{'zinc'};
    my $x_offset = $args{'x_offset'} || 0;
    my $y_offset = $args{'y_offset'} || 0;
    my $group_id = $args{'group_id'} || 1;
    my $items    = $args{'items'} || return;
    my $tags     = $args{'tags'} || [];

    for ( my $i = 0; $i <= $#{ $items || [] }; $i++ ) {

        # Has item been changed
        next unless ( $items->[$i][0] or not defined( $items->[$i][0] ) );

        my $item_id = $items->[$i][1];
        my $type    = $items->[$i][2];
        my @coords  = @{ $items->[$i][3] };    # creates duplicate array
        my $options = $items->[$i][4];

        for ( my $i = 0; $i <= $#coords; $i += 2 ) {
            $coords[$i]       += $x_offset;
            $coords[ $i + 1 ] += $y_offset;
        }

        if ( defined($item_id) ) {
            $zinc->coords( $item_id, \@coords );
            $zinc->itemconfigure( $item_id, %{ $options || {} } );
        }
        else {
            if ( $type eq 'text' ) {
                $items->[$i][1] = $zinc->add(
                    $type, $group_id,
                    -position => \@coords,
                    %{$options},
                );
            }
            else {
                $items->[$i][1]
                    = $zinc->add( $type, $group_id, \@coords, %{$options}, );
            }

            foreach my $tag (@$tags) {
                $zinc->addtag( $tag, 'withtag', $items->[$i][1] );
            }
        }
        $items->[$i][0] = 0;
    }

}

# ----------------------------------------------------
sub record_map_key_drawn_id {

=pod

=head2 record_map_key_drawn_id

Create a hash lookup for ids to a map key

Item structure:

  [ changed, item_id, type, coord_array, options_hash ]

=cut

    my ( $self, %args ) = @_;
    my $map_key = $args{'map_key'};
    my $items   = $args{'items'} || return;

    $self->{'map_key_to_drawn_ids'}{$map_key} = [];
    for ( my $i = 0; $i <= $#{ $items || [] }; $i++ ) {
        $self->{'drawn_id_to_map_key'}{ $items->[$i][1] } = $map_key;
        push @{ $self->{'map_key_to_drawn_ids'}{$map_key} }, $items->[$i][1];
    }
    @{ $self->{'map_key_to_drawn_ids'}{$map_key} }
        = sort { $b <=> $a } @{ $self->{'map_key_to_drawn_ids'}{$map_key} };
}

# ----------------------------------------------------
sub drawn_id_to_map_key {

    #print STDERR "AI_NEEDS_MODDED 16\n";

=pod

=head2 drawn_id_to_map_key

Accessor method to map_keys from drawn ids

=cut

    my ( $self, $drawn_id, ) = @_;

    return $self->{'drawn_id_to_map_key'}{$drawn_id};
}

# ----------------------------------------------------
sub map_key_to_drawn_ids {

    #print STDERR "AI_NEEDS_MODDED 17\n";

=pod

=head2 map_key_to_drawn_ids

Accessor method to drawn ids from a map_key

=cut

    my ( $self, $map_key, ) = @_;

    return @{ $self->{'map_key_to_drawn_ids'}{$map_key} || [] };
}

# ----------------------------------------------------
sub record_feature_acc_drawn_id {

=pod

=head2 record_feature_acc_drawn_id

Create a hash lookup for ids to a feature key

Item structure:

  [ changed, item_id, type, coord_array, options_hash ]

=cut

    my ( $self, %args ) = @_;
    my $feature_acc = $args{'feature_acc'};
    my $items = $args{'items'} || return;
    $self->{'feature_acc_to_drawn_ids'}{$feature_acc} = [];
    for ( my $i = 0; $i <= $#{ $items || [] }; $i++ ) {
        $self->{'drawn_id_to_feature_acc'}{ $items->[$i][1] } = $feature_acc;
        push @{ $self->{'feature_acc_to_drawn_ids'}{$feature_acc} },
            $items->[$i][1];
    }
    @{ $self->{'feature_acc_to_drawn_ids'}{$feature_acc} }
        = sort { $a <=> $b }
        @{ $self->{'feature_acc_to_drawn_ids'}{$feature_acc} };
}

# ----------------------------------------------------
sub drawn_id_to_feature_acc {

    #print STDERR "AI_NEEDS_MODDED 19\n";

=pod

=head2 drawn_id_to_feature_acc

Accessor method to feature_accs from drawn ids

=cut

    my ( $self, $drawn_id, ) = @_;

    return $self->{'drawn_id_to_feature_acc'}{$drawn_id};
}

# ----------------------------------------------------
sub feature_acc_to_drawn_ids {

    #print STDERR "AI_NEEDS_MODDED 20\n";

=pod

=head2 feature_acc_to_drawn_ids

Accessor method to drawn ids from a feature_acc

=cut

    my ( $self, $feature_acc, ) = @_;

    return @{ $self->{'feature_acc_to_drawn_ids'}{$feature_acc} || [] };
}

# ----------------------------------------------------
sub move_items {

=pod

=head2 move_items

Move items on the zinc rather than redraw it

The underlying coords in the data structure must be changed externally.

Item structure:

  [ changed, item_id, type, coord_array, options_hash ]

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $zinc       = $args{'zinc'}
        || $self->zinc( window_key => $args{'window_key'}, );
    my $x = $args{'x'} || 0;
    my $y = $args{'y'} || 0;
    my $items = $args{'items'} or return;

    for ( my $i = 0; $i <= $#{ $items || [] }; $i++ ) {

        # make sure item has been drawn
        next unless ( defined( $items->[$i][1] ) );

        my $item_id = $items->[$i][1];
        $zinc->translate( $item_id, $x, $y );
    }
}

# ----------------------------------------------------
sub add_tags_to_items {

    #print STDERR "AI_NEEDS_MODDED 22\n";

=pod

=head2 add_tags_to_items

Adds tags to items on the zinc.

Item structure:

  [ changed, item_id, type, coord_array, options_hash ]

=cut

    my ( $self, %args ) = @_;
    my $zinc  = $args{'zinc'};
    my $items = $args{'items'} || [];
    my $tags  = $args{'tags'} || [];

    foreach my $item ( @{ $items || [] } ) {
        next unless ( $item->[1] );
        foreach my $tag (@$tags) {
            $zinc->addtag( $tag, 'withtag', $item->[1] );
        }
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
        or die 'no window key for file_menu_items';
    my $new_menu_item_list = $args{'new_menu_item_list'};
    unless ( $self->{'menu_items'}{$window_key}{'file'} ) {
        $self->{'menu_items'}{$window_key}{'file'} = [
            [   'command',
                '~Load',
                -accelerator => 'Ctrl-l',
                -command     => sub {
                    $self->app_controller()
                        ->new_reference_maps( window_key => $window_key, );
                },
            ],
            [   'command',
                '~Export Map Moves',
                -accelerator => 'Ctrl-e',
                -command     => sub {
                    $self->export_map_moves( window_key => $window_key, );
                },
            ],
            [   'command',
                '~Commit Map Moves',
                -command => sub {
                    $self->commit_map_moves( window_key => $window_key, );
                },
            ],
            [   'command',
                '~Quit',
                -accelerator => 'Ctrl-q',
                -command     => sub {exit},
            ],
        ];
    }

    # If a new list is specified, overwrite the old list.
    if ($new_menu_item_list) {
        $self->{'menu_items'}{$window_key}{'file'} = $new_menu_item_list;
    }

    return $self->{'menu_items'}{$window_key}{'file'};
}

# ----------------------------------------------------
sub edit_menu_items {

=pod

=head2 edit_menu_items

Populates the edit menu with menu_items

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'}
        or die 'no window key for edit_menu_items';
    my $new_menu_item_list = $args{'new_menu_item_list'};
    unless ( $self->{'menu_items'}{$window_key}{'edit'} ) {
        $self->{'menu_items'}{$window_key}{'edit'} = [
            [   'command',
                '~Undo',
                -accelerator => 'Ctrl-z',
                -command     => sub {
                    $self->app_controller()
                        ->app_display_data->undo_action(
                        window_key => $window_key, );
                },
            ],
            [   'command',
                '~Redo',
                -accelerator => 'Ctrl-y',
                -command     => sub {
                    $self->app_controller()
                        ->app_display_data->redo_action(
                        window_key => $window_key, );
                },
            ],
        ];
    }

    # If a new list is specified, overwrite the old list.
    if ($new_menu_item_list) {
        $self->{'menu_items'}{$window_key}{'edit'} = $new_menu_item_list;
    }

    return $self->{'menu_items'}{$window_key}{'edit'};
}

# ----------------------------------------------------
sub zinc {

=pod

=head2 zinc

Returns the zinc object.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return undef;

    unless ( $self->{'zinc'}{$window_key} ) {
        my $zinc_frame = $self->{'zinc_pane'}{$window_key};

        #        $self->{'zinc'}{$window_key} = $zinc_frame->Scrolled(
        #            'Canvas',
        #            (   '-width'       => 1100,
        #                '-height'      => 800,
        #                '-relief'      => 'sunken',
        #                '-borderwidth' => 2,
        #                '-background'  => 'white',
        #                '-scrollbars'  => 's',
        #            ),
        #        )->pack( -side => 'top', -fill => 'both', );
        #        $self->{'zinc'}{$window_key} = $zinc_frame->Canvas(
        #            '-width'       => 1100,
        #            '-height'      => 800,
        #            '-relief'      => 'sunken',
        #            '-borderwidth' => 2,
        #            '-background'  => 'white',
        #        );

        $self->{'zinc'}{$window_key} = $zinc_frame->Zinc(
            -width       => 1100,
            -height      => 800,
            -backcolor   => 'white',
            -borderwidth => 2,
            -relief      => 'sunken'
        );

        # Pack later in pack_panes()
        # BF ADD BACK LATER
        $self->bind_zinc( zinc => $self->{'zinc'}{$window_key} );
    }
    return $self->{'zinc'}{$window_key};
}

# ----------------------------------------------------
sub bind_zinc {

=pod

=head2 bind_zinc

Bind events to a zinc

=cut

    my ( $self, %args ) = @_;
    my $zinc = $args{'zinc'} or return undef;

    $zinc->Tk::bind(
        '<1>' => sub {
            my ($zinc) = @_;
            my $e = $zinc->XEvent;
            $self->start_drag_type_1( $zinc, $e->x, $e->y, );
        }
    );

    $zinc->Tk::bind(
        '<3>' => sub {
            my ($zinc) = @_;
            my $e = $zinc->XEvent;
            $self->start_drag_type_2( $zinc, $e->x, $e->y, );
        }
    );
    $zinc->Tk::bind(
        '<B1-ButtonRelease>' => sub {
            my ($zinc) = @_;
            my $e = $zinc->XEvent;
            $self->stop_drag_type_1( $zinc, $e->x, $e->y, );
        }
    );
    $zinc->Tk::bind(
        '<B3-ButtonRelease>' => sub {
            my ($zinc) = @_;
            my $e = $zinc->XEvent;
            $self->stop_drag_type_2( $zinc, $e->x, $e->y, );
        }
    );
    $zinc->Tk::bind(
        '<B1-Motion>' => sub {
            $self->drag_type_1( shift, $Tk::event->x, $Tk::event->y, );
        }
    );
    $zinc->Tk::bind(
        '<B3-Motion>' => sub {
            $self->drag_type_2( shift, $Tk::event->x, $Tk::event->y, );
        }
    );

    # BF READD THESE BINDINGS
    #    if ( $^O eq 'MSWin32' ) {
    #        $zinc->CanvasBind(
    #            '<MouseWheel>' => sub {
    #                $self->mouse_wheel_event( $zinc,
    #                    ( Ev('D') < 0 ) ? 0.5 : 2 );
    #            }
    #        );
    #    }
    #    else {
    #        $zinc->CanvasBind(
    #            '<4>' => sub {
    #                $self->mouse_wheel_event( $zinc, 0.5 );
    #            }
    #        );
    #        $zinc->CanvasBind(
    #            '<5>' => sub {
    #                $self->mouse_wheel_event( $zinc, 2 );
    #            }
    #        );
    #
    #    }

}

# ----------------------------------------------------
sub bind_overview_zinc {

    #print STDERR "AI_NEEDS_MODDED 28\n";

=pod

=head2 bind_overview_zinc

Bind events to the overview zinc

=cut

    my ( $self, %args ) = @_;
    my $zinc = $args{'zinc'} or return undef;

    $zinc->CanvasBind(
        '<1>' => sub {
            my ($zinc) = @_;
            my $e = $zinc->XEvent;
            $self->start_drag_type_2( $zinc, $e->x, $e->y, );
        }
    );
    $zinc->CanvasBind(
        '<B1-ButtonRelease>' => sub {
            my ($zinc) = @_;
            my $e = $zinc->XEvent;
            $self->stop_drag_type_2( $zinc, $e->x, $e->y, );
        }
    );
    $zinc->CanvasBind(
        '<B1-Motion>' => sub {
            $self->drag_type_2( shift, $Tk::event->x, $Tk::event->y, );
        }
    );

}

# ----------------------------------------------------
sub overview_zinc {

=pod

=head2 overview_zinc

Returns the overview_zinc object.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return undef;

    unless ( $self->{'overview_zinc'}{$window_key} ) {
        my $overview_zinc_frame = $self->{'top_pane'}{$window_key};

        $self->{'overview_zinc'}{$window_key} = $overview_zinc_frame->Zinc(
            -width       => 300,
            -height      => 300,
            -backcolor   => 'white',
            -borderwidth => 2,
            -relief      => 'sunken'
        );

        # Pack later in pack_panes()
        # BF ADD BACK LATER
        #$self->bind_overview_zinc(
        #zinc => $self->{'overview_zinc'}{$window_key} );
    }
    return $self->{'overview_zinc'}{$window_key};
}

# ----------------------------------------------------
sub popup_map_menu {

    #print STDERR "AI_NEEDS_MODDED 30\n";

=pod

=head2 popup_map_menu


=cut

    my ( $self, %args ) = @_;
    my $drawn_id = $args{'drawn_id'};
    my $zinc     = $args{'zinc'};
    my $moved    = $args{'moved'};
    my $map_key  = $args{'map_key'} || $self->drawn_id_to_map_key($drawn_id);
    my $controller = $self->app_controller();

    my $map_menu_window = $self->main_window()->Toplevel( -takefocus => 1 );
    if ($map_key) {

        # Moved
        if ($moved) {

            my $move_button = $map_menu_window->Button(
                -text    => 'Move Map',
                -command => sub {
                    $self->{'moving_map'} = 1;
                    $map_menu_window->destroy();
                    $self->{'movng_map'} = 0;
                    $self->move_map_popup(
                        map_key => $map_key,
                        zinc    => $zinc,
                    );
                },
            )->pack( -side => 'top', -anchor => 'nw' );
        }
        my $new_window_button = $map_menu_window->Button(
            -text    => 'New Window',
            -command => sub {
                $map_menu_window->destroy();
                $controller->open_new_window( selected_map_keys => [$map_key],
                );

            },
        )->pack( -side => 'top', -anchor => 'nw' );

    }

    my $cancel_button = $map_menu_window->Button(
        -text    => 'Cancel',
        -command => sub {
            $map_menu_window->destroy();
        },
    )->pack( -side => 'bottom', -anchor => 'sw' );

    $map_menu_window->bind(
        '<FocusOut>',
        sub {
            $map_menu_window->destroy();
        },
    );
    $map_menu_window->bind(
        '<Destroy>',
        sub {
            $self->destroy_ghosts($zinc) unless ( $self->{'moving_map'} );
        },
    );
    $map_menu_window->bind(
        '<Map>',
        sub {
            my $width  = $map_menu_window->reqwidth();
            my $height = $map_menu_window->reqheight();
            my $x      = $map_menu_window->pointerx();
            my $y      = $map_menu_window->pointery();
            my $new_geometry_string
                = $width . "x" . $height . "+" . $x . "+" . $y;
            $map_menu_window->geometry($new_geometry_string);

        },
    );

    return;
}

# ----------------------------------------------------
sub fill_map_info_box {

    #print STDERR "AI_NEEDS_MODDED 31\n";

=pod

=head2 fill_map_info_box


=cut

    my ( $self, %args ) = @_;
    my $drawn_id = $args{'drawn_id'};
    my $map_key = $args{'map_key'} || $self->drawn_id_to_map_key($drawn_id)
        or return;
    my $controller       = $self->app_controller();
    my $app_display_data = $controller->app_display_data();
    my $zone_key   = $app_display_data->{'map_key_to_zone_key'}{$map_key};
    my $window_key = $app_display_data->{'scaffold'}{$zone_key}{'window_key'};

    my $text_box = $self->{'information_text'};
    $text_box->configure( -state => 'normal', );

    # Wipe old info
    $text_box->delete( "1.0", 'end' );

    my $new_text = $controller->get_map_info_text(
        map_key    => $map_key,
        window_key => $window_key,
    );

    $text_box->insert( 'end', $new_text );
    $text_box->configure( -state => 'disabled', );

    return;
}

# ----------------------------------------------------
sub fill_feature_info_box {

    #print STDERR "AI_NEEDS_MODDED 32\n";

=pod

=head2 fill_feature_info_box


=cut

    my ( $self, %args ) = @_;
    my $drawn_id    = $args{'drawn_id'};
    my $feature_acc = $args{'feature_acc'}
        || $self->drawn_id_to_feature_acc($drawn_id)
        or return;
    my $controller       = $self->app_controller();
    my $app_display_data = $controller->app_display_data();

    my $text_box = $self->{'information_text'};
    $text_box->configure( -state => 'normal', );

    # Wipe old info
    $text_box->delete( "1.0", 'end' );

    my $new_text
        = $controller->get_feature_info_text( feature_acc => $feature_acc, );

    $text_box->insert( 'end', $new_text );
    $text_box->configure( -state => 'disabled', );

    return;
}

# ----------------------------------------------------
sub export_map_moves {

    #print STDERR "AI_NEEDS_MODDED 33\n";

=pod

=head2 export_map_moves

Popup a getSaveFile dialog and pass the file info to the controller for
exporting the map moves.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};

    my $export_file_name = $self->main_window()->getSaveFile(
        -title       => 'Export Map Moves',
        -initialfile => 'cmap_map_moves.dat'
    );
    return unless ($export_file_name);

    $self->app_controller()->export_map_moves(
        window_key       => $window_key,
        export_file_name => $export_file_name,
    );

    return;
}

# ----------------------------------------------------
sub commit_map_moves {

    #print STDERR "AI_NEEDS_MODDED 34\n";

=pod

=head2 commit_map_moves


=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};

    my $answer = $self->main_window()->Dialog(
        -title => 'Commit Map Moves?',
        -text  => 'Would you like to commit the Map moves to the database?',
        -default_button => 'Cancel',
        -buttons        => [ 'OK', 'Cancel', ],
    )->Show();

    if ( $answer eq 'OK' ) {
        $self->app_controller()
            ->commit_map_moves( window_key => $window_key, );
    }

    return;
}

# ----------------------------------------------------
sub move_map_popup {

    #print STDERR "AI_NEEDS_MODDED 35\n";

=pod

=head2 move_map_popup

=cut

    my ( $self, %args ) = @_;
    my $map_key    = $args{'map_key'};
    my $zinc       = $args{'zinc'};
    my $controller = $self->app_controller();

    my $move_map_data = $controller->app_display_data->get_move_map_data(
        map_key      => $map_key,
        ghost_bounds => $self->{'ghost_bounds'},
    );

    my $new_parent_map_key = $move_map_data->{'new_parent_map_key'};
    my $new_feature_start  = $move_map_data->{'new_feature_start'};
    my $new_feature_stop   = $move_map_data->{'new_feature_stop'};
    my $popup              = $self->main_window()->Dialog(
        -title          => 'Move Map',
        -default_button => 'OK',
        -buttons        => [ 'OK', 'Cancel', ],
    );
    $popup->add(
        'LabEntry',
        -textvariable => \$new_feature_start,
        -width        => 10,
        -label        => 'Start',
        -labelPack    => [ -side => 'left' ],
    )->pack();
    $popup->add(
        'LabEntry',
        -textvariable => \$new_feature_stop,
        -width        => 10,
        -label        => 'Stop',
        -labelPack    => [ -side => 'left' ],
    )->pack();
    my $answer = $popup->Show();

    if ( $answer eq 'OK' ) {
        $controller->app_display_data->move_map(
            map_key            => $map_key,
            new_parent_map_key => $new_parent_map_key,
            new_feature_start  => $new_feature_start,
            new_feature_stop   => $new_feature_stop,
        );
    }
    $self->destroy_ghosts($zinc);

    return;
}

# ----------------------------------------------------
sub password_box {

    #print STDERR "AI_NEEDS_MODDED 36\n";

=pod

=head2 commit_map_moves


=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};

    my $user;
    my $password;
    my $popup = $self->main_window()->Dialog(
        -title          => 'Login',
        -default_button => 'OK',
        -buttons        => [ 'OK', 'Cancel', ],
    );
    $popup->add(
        'LabEntry',
        -textvariable => \$user,
        -width        => 20,
        -label        => 'User Name',
        -labelPack    => [ -side => 'left' ],
    )->pack();
    $popup->add(
        'LabEntry',
        -textvariable => \$password,
        -width        => 20,
        -label        => 'Password',
        -labelPack    => [ -side => 'left' ],
        -show         => '*',
    )->pack();
    my $answer = $popup->Show();

    if ( $answer eq 'OK' ) {
        return ( $user, $password, );
    }

    return ( undef, undef );
}

# ----------------------------------------------------
sub select_reference_maps {

    #print STDERR "AI_NEEDS_MODDED 37\n";

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

    #print STDERR "AI_NEEDS_MODDED 38\n";

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

    #print STDERR "AI_NEEDS_MODDED 39\n";

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

    #print STDERR "AI_NEEDS_MODDED 40\n";

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

    #print STDERR "AI_NEEDS_MODDED 41\n";

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

    #print STDERR "AI_NEEDS_MODDED 42\n";

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
    my $window_key  = $args{'window_key'};
    my $items       = $args{'items'} || return;
    my $is_overview = $args{'is_overview'};

    my $zinc =
          $is_overview
        ? $self->overview_zinc( window_key => $window_key, )
        : $self->zinc( window_key => $window_key, );

    #$zinc->remove( map { $_->[1] } @$items );
    map { $zinc->remove( $_->[1] ) } @$items;

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

    $self->{'top_pane'}{$window_key}->destroy();
    $self->{'bottom_pane'}{$window_key}->destroy();
    $self->{'middle_pane'}{$window_key}->destroy();

    # Maybe clear bindings if they aren't destroyed with delete.

    return;
}

# ----------------------------------------------------
sub destroy_interface_window {

=pod

=head2 clear_interface_window

Deletes all widgets in the current window.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};

    $self->{'windows'}{$window_key}->destroy();

    return;
}

# ----------------------------------------------------
sub layer_tagged_items {

=pod

=head2 layer_tagged_items

Handle the placement of tagged items in layers

=cut

    my ( $self, %args ) = @_;
    my $zinc = $args{'zinc'};

    $zinc->raise( 'on_top', );
    $zinc->lower( 'on_bottom', );

    return;
}

# ----------------------------------------------------
sub destroy_zone_controls {

    #print STDERR "AI_NEEDS_MODDED 47\n";

=pod

=head2 destroy_zone_controls

Remove the interface buttons for a zone.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $zone_key   = $args{'zone_key'};
    if ( $self->{'toggle_zone_pane'}{$zone_key} ) {
        $self->toggle_zone_pane(
            window_key => $window_key,
            zone_key   => $zone_key,
        )->destroy();
        $self->{'toggle_zone_pane'}{$zone_key} = undef;
    }
    return;
}

=pod

=head1 Drag and Drop Methods

head2 Type 1

=over 4 

=item Highlight map

=item Eventually draw select box

=back

head2 Type 2

=over 4 

=item Drag around window

=item Move maps

=item Bring up map menu

=back

=cut

# ----------------------------------------------------
sub start_drag_type_1 {

    #print STDERR "AI_NEEDS_MODDED 48\n";

=pod

=head2 start_drag_type_1

Handle starting drag


=cut

    my $self = shift;
    my ( $zinc, $x, $y, ) = @_;

    # Remove previous highlighting
    $self->destroy_ghosts($zinc);

    $self->{'drag_last_x'} = $x;
    $self->{'drag_last_y'} = $y;
    $self->{'drag_ori_id'} = $zinc->find( 'withtag', 'current' );
    if ( ref( $self->{'drag_ori_id'} ) eq 'ARRAY' ) {
        $self->{'drag_ori_id'} = $self->{'drag_ori_id'}[0];
    }
    return unless ( $self->{'drag_ori_id'} );

    my @tags;
    my $ghost_color = 'red';
    if ( @tags = grep /^map_/, $zinc->gettags( $self->{'drag_ori_id'} ) ) {
        $tags[0] =~ /^map_(\S+)_(\S+)_(\S+)/;
        $self->{'drag_window_key'} = $1;
        $self->{'drag_zone_key'}   = $2;
        $self->{'drag_map_key'}    = $3;

        my $map_key = $self->drawn_id_to_map_key( $self->{'drag_ori_id'} );

        $self->create_ghost( zinc => $zinc, map_key => $map_key, );
        $self->create_ghost_location_on_map(
            zinc    => $zinc,
            map_key => $map_key,
        );

        $self->fill_map_info_box( drawn_id => $self->{'drag_ori_id'}, );
    }
    elsif ( grep /^feature/, $zinc->gettags( $self->{'drag_ori_id'} ) ) {

        my $feature_acc
            = $self->drawn_id_to_feature_acc( $self->{'drag_ori_id'} );

        $self->create_ghost( zinc => $zinc, feature_acc => $feature_acc, );

        $self->fill_feature_info_box( drawn_id => $self->{'drag_ori_id'}, );
    }
    elsif ( @tags = grep /^background_/,
        $zinc->gettags( $self->{'drag_ori_id'} ) )
    {
        $tags[0] =~ /^background_(\S+)_(\S+)/;
        $self->{'drag_window_key'} = $1;
        $self->{'drag_zone_key'}   = $2;
    }

    # BF ADD THIS BACK LATER
    #    elsif ( @tags = grep /^viewed_region_/,
    #        $zinc->gettags( $self->{'drag_ori_id'} ) )
    #    {
    #        $tags[0] =~ /^viewed_region_(\S+)_(\S+)/;
    #        $self->{'drag_window_key'} = $1;
    #        $self->{'drag_zone_key'}   = $2;
    #    }
    #
    if ( $self->{'drag_zone_key'} ) {
        $self->app_controller()
            ->new_selected_zone( zone_key => $self->{'drag_zone_key'}, );
    }

}    # end start_drag

# ----------------------------------------------------
sub start_drag_type_2 {

    #print STDERR "AI_NEEDS_MODDED 49\n";

=pod

=head2 start_drag_type_2

Handle starting drag

=cut

    my $self = shift;
    my ( $zinc, $x, $y, ) = @_;

    # Remove previous highlighting
    $self->destroy_ghosts($zinc);

    $self->{'drag_last_x'} = $x;
    $self->{'drag_last_y'} = $y;
    $self->{'drag_ori_id'} = $zinc->find( 'withtag', 'current' );
    if ( ref( $self->{'drag_ori_id'} ) eq 'ARRAY' ) {
        $self->{'drag_ori_id'} = $self->{'drag_ori_id'}[0];
    }
    return unless ( $self->{'drag_ori_id'} );
    my @tags;
    my $ghost_color = 'red';
    if ( @tags = grep /^map_/, $zinc->gettags( $self->{'drag_ori_id'} ) ) {
        $tags[0] =~ /^map_(\S+)_(\S+)_(\S+)/;
        $self->{'drag_window_key'} = $1;
        $self->{'drag_zone_key'}   = $2;
        $self->{'drag_map_key'}    = $3;
        $self->{'drag_obj'}        = 'map';

        my $map_key = $self->drawn_id_to_map_key( $self->{'drag_ori_id'} );

        $self->create_ghost( zinc => $zinc, map_key => $map_key, );
        $self->create_ghost_location_on_map(
            zinc    => $zinc,
            map_key => $map_key,
        );

        $self->fill_map_info_box( drawn_id => $self->{'drag_ori_id'}, );
        $self->{'drag_mouse_to_edge_x'} = $x - $self->{'ghost_bounds'}[0];

    }
    elsif ( @tags = grep /^background_/,
        $zinc->gettags( $self->{'drag_ori_id'} ) )
    {
        $tags[0] =~ /^background_(\S+)_(\S+)/;
        $self->{'drag_window_key'} = $1;
        $self->{'drag_zone_key'}   = $2;
        $self->{'drag_obj'}        = 'background';
        $self->app_controller()->hide_corrs(
            window_key => $self->{'drag_window_key'},
            zone_key   => $self->{'drag_zone_key'},
        );
    }

    # BF ADD THIS BACK LATER
    #    elsif ( @tags = grep /^viewed_region_/,
    #        $zinc->gettags( $self->{'drag_ori_id'} ) )
    #    {
    #        $tags[0] =~ /^viewed_region_(\S+)_(\S+)/;
    #        $self->{'drag_window_key'} = $1;
    #        $self->{'drag_zone_key'}   = $2;
    #        $self->{'drag_obj'}        = 'viewed_region';
    #        $self->app_controller()->hide_corrs(
    #            window_key => $self->{'drag_window_key'},
    #            zone_key   => $self->{'drag_zone_key'},
    #        );
    #    }
    #
    if ( $self->{'drag_zone_key'} ) {
        $self->app_controller()
            ->new_selected_zone( zone_key => $self->{'drag_zone_key'}, );
    }

}    # end start_drag

# ----------------------------------------------------
sub drag_type_1 {

    #print STDERR "AI_NEEDS_MODDED 50\n";

=pod

=head2 drag_type_1

Handle the drag event

Stubbed out, not currently used.

=cut

    my $self = shift;
    my ( $zinc, $x, $y, ) = @_;
    return unless ( $self->{'drag_ori_id'} );
    my $dx = $x - $self->{'drag_last_x'};
    my $dy = $y - $self->{'drag_last_y'};

    #    my $new_zone_key = $self->get_zone_key_from_drawn_id(
    #        window_key =>$window_key,
    #        drawn_id =>$zinc->find( 'closest', $x,$y ),
    #        zinc => $zinc,
    #);
    if ( $self->{'drag_obj'} ) {
    }

    $self->{drag_last_x} = $x;
    $self->{drag_last_y} = $y;

}

# ----------------------------------------------------
sub drag_type_2 {

    #print STDERR "AI_NEEDS_MODDED 51\n";

=pod

=head2 drag_type_2

Handle the drag event

=cut

    my $self = shift;
    my ( $zinc, $x, $y, ) = @_;
    return unless ( $self->{'drag_ori_id'} );
    my $dx = $x - $self->{'drag_last_x'};
    my $dy = $y - $self->{'drag_last_y'};

    if ( $self->{'drag_obj'} ) {
        if ( $self->{'drag_obj'} eq 'map' ) {

            $self->{'ghost_map_moved'} = 1;

            # BF ADD THIS FEATURE BACK AT SOME POINT
            $self->drag_ghost(
                zinc => $zinc,
                x    => $x,
                y    => $y,
                dx   => $dx,
                dy   => $dy,
            );
        }
        elsif ( $self->{'drag_obj'} eq 'background' ) {
            $self->app_controller()->scroll_zone(
                window_key   => $self->{'drag_window_key'},
                zone_key     => $self->{'drag_zone_key'},
                scroll_value => $dx,
            );
        }
        elsif ( $self->{'drag_obj'} eq 'viewed_region' ) {

            # BF ADD THIS FEATURE BACK AT SOME POINT
            return;
            $self->app_controller()->overview_scroll_zone(
                window_key   => $self->{'drag_window_key'},
                zone_key     => $self->{'drag_zone_key'},
                scroll_value => $dx * 1,
            );
        }
    }

    $self->{drag_last_x} = $x;
    $self->{drag_last_y} = $y;

}

# ----------------------------------------------------
sub stop_drag_type_1 {

=pod

=head2 stop_drag_type_1

Handle the stopping drag event

Stubbed out, Not currently used.

=cut

    my $self = shift;
    my ( $zinc, $x, $y, ) = @_;

    return unless ( $self->{'drag_ori_id'} );

    # Move original object
    if ( $self->{'drag_obj'} ) {
        $self->app_controller()->app_display_data()->end_drag_ghost();
    }

    foreach (
        qw{
        drag_ori_id
        drag_obj    drag_window_key drag_zone_key
        }
        )
    {
        $self->{$_} = '';
    }

}    # end start_drag

# ----------------------------------------------------
sub stop_drag_type_2 {

    #print STDERR "AI_NEEDS_MODDED 53\n";

=pod

=head2 stop_drag_type_2

Handle the stopping drag event

=cut

    my $self = shift;
    my ( $zinc, $x, $y, ) = @_;

    return unless ( $self->{'drag_ori_id'} );

    # Move original object
    if ( $self->{'drag_obj'} ) {
        if ( $self->{'drag_obj'} eq 'map' ) {
            my $map_key = $self->{'drag_map_key'};

            $self->popup_map_menu(
                zinc     => $zinc,
                moved    => $self->{'ghost_map_moved'},
                drawn_id => ( $self->{'drag_ori_id'} ),
            );
        }
        elsif ($self->{'drag_obj'} eq 'background'
            or $self->{'drag_obj'} eq 'viewed_region' )
        {
            $self->app_controller()->unhide_corrs(
                window_key => $self->{'drag_window_key'},
                zone_key   => $self->{'drag_zone_key'},
            );
        }
    }

    foreach (
        qw{
        drag_ori_id
        drag_obj    drag_window_key drag_zone_key
        }
        )
    {
        $self->{$_} = '';
    }

}    # end start_drag

# ----------------------------------------------------
sub create_ghost_location_on_map {

    #print STDERR "AI_NEEDS_MODDED 54\n";

=pod

=head2 create_ghost_location_on_map

Handle the ghost map dragging

=cut

    my ( $self, %args ) = @_;
    my $zinc    = $args{'zinc'};
    my $map_key = $args{'map_key'};

    my $ghost_color = 'red';

    my %ghost_location_data = $self->app_controller()->app_display_data()
        ->place_ghost_location_on_parent_map( map_key => $map_key, );

    return unless (%ghost_location_data);

    my $parent_group_id = $self->get_zone_group_id(
        window_key       => $ghost_location_data{'window_key'},
        zone_key         => $ghost_location_data{'parent_zone_key'},
        zinc             => $zinc,
        app_display_data => $self->app_controller()->app_display_data(),
    );

    $self->{'ghost_loc_id'} = $zinc->add(
        'rectangle',
        $parent_group_id,
        $ghost_location_data{'location_coords'},
        -linecolor => $ghost_color,
        -linewidth => 2,
        -filled    => 0,
        -visible   => $ghost_location_data{'visible'},

    );
    $zinc->addtag( 'on_top', 'withtag', $self->{'ghost_loc_id'} );

    $self->{'ghost_loc_parent_zone_key'}
        = $ghost_location_data{'parent_zone_key'};

    return;
}

# ----------------------------------------------------
sub create_ghost {

    #print STDERR "AI_NEEDS_MODDED 54\n";

=pod

=head2 create_ghost

Handle the ghost map dragging

=cut

    my ( $self, %args ) = @_;
    my $zinc        = $args{'zinc'};
    my $map_key     = $args{'map_key'};
    my $feature_acc = $args{'feature_acc'};

    my $ghost_color = 'red';

    # Create a ghost item for each item in the original feature glyph
    my @ori_ids;
    if ($map_key) {
        @ori_ids = $self->map_key_to_drawn_ids($map_key);
    }
    elsif ($feature_acc) {
        @ori_ids = $self->feature_acc_to_drawn_ids($feature_acc);
    }
    else {
        return;
    }

    my $app_display_data = $self->app_controller()->app_display_data();
    $self->{'ghost_bounds'} = [];
    my ( $main_x_offset, $main_y_offset );
    if ($map_key) {
        my $zone_key = $app_display_data->{'map_key_to_zone_key'}{$map_key};
        ( $main_x_offset, $main_y_offset )
            = $app_display_data->get_main_zone_offsets( zone_key => $zone_key,
            );
    }

    foreach my $ori_id (@ori_ids) {
        my $type = $zinc->type($ori_id);
        next if ( $type eq 'text' );
        my $ghost_id = $zinc->clone($ori_id);
        push @{ $self->{'ghost_ids'} }, $ghost_id;

        # Make ghost a different color.
        $zinc->itemconfigure(
            $ghost_id,
            -linecolor => $ghost_color,
            -fillcolor => $ghost_color,
        );
        if ($map_key) {
            $zinc->chggroup( $ghost_id, 1, 1, );

            # modify the coords to be universial because chggroup won't.
            my @coords = $zinc->coords($ghost_id);

            # Flatten the coords array
            @coords = map { ( ref($_) eq 'ARRAY' ) ? @$_ : $_ } @coords;
            $coords[0] += $main_x_offset;
            $coords[1] += $main_y_offset;
            $coords[2] += $main_x_offset;
            $coords[3] += $main_y_offset;
            $self->{ghost_bounds}
                = $self->expand_bounds( $self->{ghost_bounds}, \@coords );
        }
    }

    return;
}

# ----------------------------------------------------
sub drag_ghost {

    #print STDERR "AI_NEEDS_MODDED 54\n";

=pod

=head2 drag_ghost

Handle the ghost map dragging

=cut

    my ( $self, %args ) = @_;
    my $zinc = $args{'zinc'};
    my $x    = $args{'x'};
    my $dx   = $args{'dx'};
    my $y    = $args{'y'};
    my $dy   = $args{'dy'};
    return unless ( $dx or $dy );

    my %ghost_data = $self->app_controller()->app_display_data()->move_ghosts(
        map_key      => $self->drawn_id_to_map_key( $self->{'drag_ori_id'} ),
        mouse_x      => $x,
        mouse_y      => $y,
        mouse_dx     => $dx,
        mouse_dy     => $dy,
        ghost_bounds => $self->{'ghost_bounds'},
        mouse_to_edge_x => $self->{'drag_mouse_to_edge_x'},
    );
    return unless (%ghost_data);

    my $new_dx = $ghost_data{'ghost_dx'};
    my $new_dy = $ghost_data{'ghost_dy'};
    return unless ( $new_dx or $new_dy );

    # Move the ghost
    foreach my $ghost_id ( @{ $self->{'ghost_ids'} || [] } ) {
        $zinc->translate( $ghost_id, $new_dx, $new_dy, );
    }

    #Move the ghost bounds
    $self->{'ghost_bounds'}[0] += $new_dx;
    $self->{'ghost_bounds'}[2] += $new_dx;

    # Move the ghost loc
    unless ( $ghost_data{'ghost_loc_parent_zone_key'}
        == $self->{'ghost_loc_parent_zone_key'} )
    {
        $self->{'ghost_loc_parent_zone_key'}
            = $ghost_data{'ghost_loc_parent_zone_key'};

        my $parent_group_id = $self->get_zone_group_id(
            window_key       => $ghost_data{'window_key'},
            zone_key         => $ghost_data{'ghost_loc_parent_zone_key'},
            zinc             => $zinc,
            app_display_data => $self->app_controller()->app_display_data(),
        );
        $zinc->chggroup( $self->{'ghost_loc_id'}, $parent_group_id, 1, );
    }
    $zinc->coords(
        $self->{'ghost_loc_id'},
        $ghost_data{'ghost_loc_location_coords'},
    );
    $zinc->itemconfigure( $self->{'ghost_loc_id'},
        -visible => $ghost_data{'ghost_loc_visible'}, );

}    # end drag_ghost

# ----------------------------------------------------
sub mouse_wheel_event {

    #print STDERR "AI_NEEDS_MODDED 55\n";

=pod

=head2 mouse_wheel_event

Handle the mouse wheel events

=cut

    my $self = shift;
    my ( $zinc, $value ) = @_;

    if ( my @tags = grep /^background_/, $zinc->gettags("current") ) {
        $tags[0] =~ /^background_(\S+)_(\S+)/;
        my $window_key = $1;
        my $zone_key   = $2;

        $self->app_controller()->zoom_zone(
            window_key => $window_key,
            zone_key   => $zone_key,
            zoom_value => $value,
        );
    }

}

# ----------------------------------------------------
sub int_new_selected_zone {

=pod

=head2 int_new_selected_zone

Handler for selecting a new zone.

Modifies the controls to act on this slot.

=cut

    my ( $self, %args ) = @_;
    my $app_display_data = $args{'app_display_data'};
    my $zone_key         = $args{'zone_key'};
    my $map_set_data     = $args{'map_set_data'};

    ${ $self->{'selected_zone_key_scalar'} } = $zone_key;
    $self->{'show_features'}
        = $app_display_data->{'scaffold'}{$zone_key}{'show_features'};
    $self->{'attached_to_parent'}
        = $app_display_data->{'scaffold'}{$zone_key}{'attached_to_parent'};
    if ( $app_display_data->{'scaffold'}{$zone_key}{'is_top'} ) {
        $self->{'attach_to_parent_check_box'}
            ->configure( -state => 'disable', );
    }
    else {
        $self->{'attach_to_parent_check_box'}
            ->configure( -state => 'normal', );
    }
    my $text_box = $self->{'selected_map_set_text_box'};
    $text_box->configure( -state => 'normal', );

    # Wipe old info
    $text_box->delete( "1.0", 'end' );

    my $new_text = $map_set_data->{'map_set_name'};

    $text_box->insert( 'end', $new_text );
    $text_box->configure( -state => 'disabled', );

    return;
}

# ----------------------------------------------------
sub int_move_zone {

    #print STDERR "AI_NEEDS_MODDED 57\n";

=pod

=head2 int_move_zone

Does what the interface needs to do to move the zone

=cut

    my ( $self, %args ) = @_;
    my $app_display_data = $args{'app_display_data'};
    my $window_key       = $args{'window_key'};
    my $zone_key         = $args{'zone_key'};
    my $x                = $args{'x'};
    my $y                = $args{'y'};

    my $zinc = $self->zinc( window_key => $window_key, );
    my $zone_group_id = $self->get_zone_group_id(
        window_key       => $window_key,
        zone_key         => $zone_key,
        zinc             => $zinc,
        app_display_data => $app_display_data,
    );

    $zinc->translate( $zone_group_id, $x, $y );

    return;
}

# ----------------------------------------------------
sub window_configure_event {

=pod

=head2 window_configure_event

Handle window resizing

=cut

    my $self = shift;
    my ( $event, $window_key, $app_display_data, ) = @_;

    if ( not $app_display_data->{'window_layout'}{$window_key}{'width'} ) {
        $app_display_data->{'window_layout'}{$window_key}{'width'}
            = $event->w;
    }
    elsif ( $event->w
        != $app_display_data->{'window_layout'}{$window_key}{'width'} )
    {
        $app_display_data->change_width(
            window_key => $window_key,
            width      => $event->w,
        );
        $self->pack_panes( $window_key, $app_display_data, );
    }
    return;
}

# ----------------------------------------------------
sub destroy_ghosts {

    #print STDERR "AI_NEEDS_MODDED 59\n";

=pod

=head2 destroy_ghosts

Destroy the ghost image

=cut

    my $self = shift;
    my $zinc = shift;

    foreach my $ghost_id ( @{ $self->{'ghost_ids'} || [] } ) {
        $zinc->remove($ghost_id);
    }

    $self->{'ghost_ids'}       = undef;
    $self->{'ghost_bounds'}    = [];
    $self->{'ghost_map_moved'} = undef;

    $zinc->remove( $self->{'ghost_loc_id'} ) if $self->{'ghost_loc_id'};
    $self->{'ghost_loc_id'}              = undef;
    $self->{'ghost_loc_parent_zone_key'} = undef;
    $self->app_controller()->app_display_data()->end_drag_ghost();
}

# ----------------------------------------------------
sub pack_panes {

=pod

=head2 pack_panes

Pack the frames

=cut

    my $self = shift;
    my ( $window_key, $app_display_data, ) = @_;

    # Top Pane
    $self->{'overview_zinc'}{$window_key}->pack(
        -side => 'left',
        -fill => 'both',
    );
    $self->{'info_pane'}{$window_key}->pack( -side => 'right', );
    $self->{'top_pane'}{$window_key}->pack(
        -side   => 'top',
        -fill   => 'x',
        -anchor => 'n',
        -expand => 1,
    );

    # Bottom Pane
    $self->{'controls_pane'}{$window_key}->pack(
        -side => 'left',
        -fill => 'both',
    );
    $self->{'bottom_pane'}{$window_key}->pack(
        -side => 'bottom',
        -fill => 'both',
    );

    # Middle Pane
    $self->{'zinc'}{$window_key}->pack(
        -side => 'top',
        -fill => 'both',
    );
    $self->{'zinc_pane'}{$window_key}->pack(
        -side   => 'left',
        -fill   => 'x',
        -anchor => 'n',
    );
    $self->{'middle_pane'}{$window_key}->pack(
        -side => 'top',
        -fill => 'both',
    );

}

sub expand_bounds {

=pod

=head2 expand_bounds

Take two arrays of coordinates and expand the first by any of the values in the
second;

=cut

    my $self = shift;
    my ( $bounds, $new_coords, ) = @_;

    return unless @{ $new_coords || [] };

    # Flatten the coords array
    $new_coords = [ map { ( ref($_) eq 'ARRAY' ) ? @$_ : $_ }
            @{ $new_coords || [] } ];

    unless ( defined( $bounds->[0] ) ) {
        $bounds->[0] = $new_coords->[0];
    }
    unless ( defined( $bounds->[1] ) ) {
        $bounds->[1] = $new_coords->[1];
    }
    unless ( defined( $bounds->[2] ) ) {
        $bounds->[2] = $new_coords->[0];
    }
    unless ( defined( $bounds->[3] ) ) {
        $bounds->[3] = $new_coords->[1];
    }

    for ( my $i = 0; $i <= $#{ $new_coords || [] }; $i = $i + 2 ) {

        # Expand the x values if needed
        if ( $bounds->[0] > $new_coords->[$i] ) {
            $bounds->[0] = $new_coords->[$i];
        }
        elsif ( $bounds->[2] < $new_coords->[$i] ) {
            $bounds->[2] = $new_coords->[$i];
        }

        # Expand the y values if needed
        if ( $bounds->[1] > $new_coords->[ $i + 1 ] ) {
            $bounds->[1] = $new_coords->[ $i + 1 ];
        }
        elsif ( $bounds->[3] < $new_coords->[ $i + 1 ] ) {
            $bounds->[3] = $new_coords->[ $i + 1 ];
        }

    }
    return $bounds;
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

