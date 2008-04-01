package Bio::GMOD::CMap::Drawer::AppInterface;

# vim: set ft=perl:

# $Id: AppInterface.pm,v 1.87 2008-04-01 20:31:38 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.87 $)[-1];

use Bio::GMOD::CMap::Constants;
use Data::Dumper;
use base 'Bio::GMOD::CMap::AppController';
use Tk;
use Tk::Zinc;
use Tk::Pane;
use Tk::Dialog;
use Tk::LabEntry;
use Tk::TableMatrix::Spreadsheet;

use constant BETWEEN_SLOT_BUFFER   => 5;
use constant TOP_LAYER_ZONE_KEY    => -1;
use constant MIN_ZINC_X_COORD      => -32868;
use constant MAX_ZINC_CLIP_X_COORD => 32756;

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
    my $window_key = $args{'window_key'} or return;
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
    $self->zinc( window_key => $window_key, );
    $self->pack_panes( $window_key, $app_display_data, );

    # Window Bindings
    $self->{'windows'}{$window_key}->protocol(
        'WM_DELETE_WINDOW',
        sub {
            $self->app_controller->close_window( window_key => $window_key, );
        }
    );

    $self->quick_keys( window_key => $window_key, );

    return $window_key;
}

# ----------------------------------------------------
sub quick_keys {

=pod

=head2 quick_keys

Add the quck keys;

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;

    # Quick Keys
    # File:

    # New View
    $self->{'windows'}{$window_key}
        ->bind( '<Control-Key-n>' => sub { $self->new_view(); }, );

    # Open View
    $self->{'windows'}{$window_key}
        ->bind( '<Control-Key-o>' => sub { $self->open_saved_view(); }, );

    # Save View
    $self->{'windows'}{$window_key}->bind( '<Control-Key-s>' =>
            sub { $self->save_view( window_key => $window_key ); }, );

    # Export Moves
    $self->{'windows'}{$window_key}->bind(
        '<Control-Key-e>' => sub {
            $self->export_changes( window_key => $window_key, );
        },
    );

    # Quit
    $self->{'windows'}{$window_key}
        ->bind( '<Control-Key-q>' => sub { exit; }, );

    # Edit:

    # Undo
    $self->{'windows'}{$window_key}->bind(
        '<Control-Key-z>' => sub {
            $self->app_controller()
                ->app_display_data->undo_action( window_key => $window_key, );
            $self->reset_object_selections( window_key => $window_key, );
        },
    );

    # Redo
    $self->{'windows'}{$window_key}->bind(
        '<Control-Key-y>' => sub {
            $self->app_controller()
                ->app_display_data->redo_action( window_key => $window_key, );
            $self->reset_object_selections( window_key => $window_key, );
        },
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
sub bottom_pane {

=pod

=head2 bottom_pane

Returns the bottom_pane object.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return undef;
    unless ( $self->{'bottom_pane'}{$window_key} ) {
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
sub _add_info_widgets {

=pod

=head2 _add_info_widgets

Adds information widgets to the info pane 

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $info_pane  = $self->{'info_pane'}{$window_key};
    my $font       = [ 'Times', 12, ];

    $self->{'information_text'}{$window_key} = $info_pane->Text(
        -font       => $font,
        -background => "white",
        -width      => 40,
        -height     => 3,
    );
    $self->{'information_text'}{$window_key}
        ->insert( 'end', "Click on a map to display information." );
    $self->{'information_text'}{$window_key}
        ->configure( -state => 'disabled', );

    Tk::grid( $self->{'information_text'}{$window_key}, -sticky => "nw", );
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

    $self->{'attach_to_parent_check_box'} = $controls_pane->Checkbutton(
        -text     => "Attached to Parent",
        -variable => \$self->{'attached_to_parent'},
        -command  => sub {
            if ( $self->{'attached_to_parent'} ) {

                #print S#TDERR "DETACH\n";

                #$self->app_controller()->app_display_data()->reattach_zone(
                #window_key => $window_key,
                #zone_key   => ${ $self->{'selected_zone_key_scalar'} },
                #);
            }
            else {

                #print S#TDERR "ATTACH\n";

                #$self->app_controller()->app_display_data()->reattach_zone(
                #window_key => $window_key,
                #zone_key   => ${ $self->{'selected_zone_key_scalar'} },
                #);
            }
        },
        -font => $font,
    );
    my $debug_button1 = $controls_pane->Button(
        -text    => "Debug",
        -command => sub {

            my $zinc = $self->zinc( window_key => $window_key, );

#print STDERR "---------------------------------\n";
#print STDERR
#  "           --------------BEFORE MOVE-------------------\n";
#$self->app_controller->app_display_data->move_map(
#    map_key            => 16,
#    new_parent_map_key => 1,
#    new_feature_start  => 1039.96,
#    new_feature_stop   => 3239.97,
#);
#print STDERR
#    "            --------------BEFORE DISPLAY LABELS------------\n";
#$self->app_controller()->app_display_data()
#    ->set_map_labels_visibility( 2, 1, );
#print STDERR
#    "            --------------BEFORE DISPLAY FEATURES------------\n";
#$self->app_controller()->app_display_data()
#    ->set_features_visibility( 2, 1, );
#print STDERR
#    "           --------------BEFORE MERGE-------------------\n";
#my ( $selected_map_keys, $zone_key )
#    = $self->app_controller()->app_display_data()->merge_maps(
#    overlap_amount => 0,
#    first_map_key  => 3,
#    second_map_key => 4,
#    );
#print STDERR
#    "           --------------BEFORE UNDO-------------------\n";
#$self->app_controller()
#    ->app_display_data->undo_action( window_key => $window_key, );
#
#print STDERR
#    "            --------------BEFORE SELECT-------------------\n";
#$self->app_controller()->new_selected_zone( zone_key => 2, );
#print STDERR
#    "            --------------BEFORE SHOW SELF CORRS---------\n";
#$self->app_controller()->app_display_data()->set_corrs_map_set(
#    'map_set_ids' =>[
#                      '1',
#                      '3'
#                    ],
#    'zone_key'   => 2,
#    'corrs_on'   => 1,
#    'window_key' => 1
#);
#print STDERR
#    "            --------------BEFORE MOVE SUBSECTION------------\n";
#$self->app_controller()->app_display_data()->move_map_subsection(
#    'gap_stop'            => '50467.00',
#    'gap_start'           => '50466.00',
#    'destination_map_key' => 1,
#    'subsection_map_key'  => '13'
#);
#
#print STDERR
#    "            --------------BEFORE SHOW ALL CORRS------------\n";
#$self->app_controller()->app_display_data()->set_corrs_map_set(
#    'map_set_ids' => [ '1', '3' ],
#    'zone_key'    => 2,
#    'corrs_on'    => 1,
#    'window_key'  => 1,
#);
#print STDERR
#    "            -----------BEFORE HIDE ONE CORR-----------------\n";
#$self->app_controller()->app_display_data()->set_corrs_map_set(
#    'map_set_id' => '1',
#    'zone_key'   => 2,
#    'corrs_on'   => 0,
#    'window_key' => 1,
#);
#print STDERR
#    "           --------------BEFORE ZOOM-------------------\n";
#$self->app_controller()->zoom_zone(
#    window_key => $window_key,
#    zone_key   => ${ $self->{'selected_zone_key_scalar'} },
#    zoom_value => 2,
#);
#print STDERR
#    "            ----------------BEFORE SET OFFSCREEN CORRS-----------------\n";
#$self->app_controller()->app_display_data()->set_offscreen_corrs_visibility( 2, 1, );
#print STDERR
#    "            --------------BEFORE SELECT-------------------\n";
#  $self->add_object_selection(
#      zinc       => $zinc,
#      zone_key   => 2,
#      map_key    => 34,
#      window_key => $window_key,
#  );
#print STDERR
#    "            ----------------BEFORE SELECT ZONE---\n";
#$self->app_controller()->new_selected_zone( zone_key => 3, );
#print STDERR
#    "            -----------BEFORE DISPLAY LABELS-----\n";
#$self->app_controller()->app_display_data()
#    ->set_map_labels_visibility( 2, 1, );
#print STDERR
#    "            -----------BEFORE flip-----------------\n";
#$self->app_controller()->app_display_data()->flip_map(
#    'map_key'   => 4,
#);
#print STDERR
#    "            ----------------BEFORE SCROLL-----------------\n";
#$self->app_controller()->scroll_zone(
#    window_key   => $window_key,
#    zone_key     => 1,
#    scroll_value => -140,
#);
#print STDERR
#    "            ----------------BEFORE SCROLL2-----------------\n";
#$self->app_controller()->scroll_zone(
#    window_key   => $window_key,
#    zone_key     => 1,
#    scroll_value => -10,
#);
#print STDERR
#    "            ----------------BEFORE SPLIT-----------------\n";
#$self->app_controller->app_display_data->split_map(
#    map_key        => 4,
#    split_position => 1000,
#    );
#print STDERR "  ------------------DONE-----------------------\n";
#exit;
        },
        -font => $font,
    );
    my $debug_button2 = $controls_pane->Button(
        -text    => "Debug2",
        -command => sub {
            my $zinc = $self->zinc( window_key => $window_key, );

          #print STDERR "---------------------------------\n";
          #print STDERR
          #    "           --------------BEFORE ZOOM-------------------\n";
          #$self->app_controller()->zoom_zone(
          #    window_key => $window_key,
          #    zone_key   => ${ $self->{'selected_zone_key_scalar'} },
          #    zoom_value => 2,
          #);
          #print STDERR
          #    "           --------------BEFORE MERGE-------------------\n";
          #my ( $selected_map_keys, $zone_key )
          #    = $self->app_controller()->app_display_data()->merge_maps(
          #    overlap_amount => 0,
          #    first_map_key  => 2,
          #    second_map_key => 3,
          #    );
          #print STDERR
          #    "            ----------------BEFORE SCROLL-----------------\n";
          #$self->app_controller()->scroll_zone(
          #    window_key   => $window_key,
          #    zone_key     => 1,
          #    scroll_value => -140,
          #);
          #print STDERR
          #    "           --------------BEFORE COMMIT-------------------\n";
          #$self->app_controller()
          #    ->commit_changes( window_key => 1, );
          #print STDERR "  ------------------DONE-----------------------\n";
          #exit;
        },
        -font => $font,
    );
    Tk::grid(
        $self->{'selected_map_set_text_box'}, '-', '-', '-', '-',
        '-',                                  '-', '-',

        #$reattach_button,
        -sticky => "nw",
    );
    Tk::grid(
        $scroll_far_left_button, $scroll_left_button,
        $zoom_button1,           $zoom_button2,
        $scroll_type_1,          $scroll_far_type_1,

        #$debug_button1, #$debug_button2,

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

    $self->{'menu_bar_order'}{$window_key} = [ 'File', 'Edit', ];

    $self->file_menu_items( window_key => $window_key, );
    $self->edit_menu_items( window_key => $window_key, );

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
            next unless $app_display_data->{'scaffold'}{$zone_key}{'is_top'};
            $self->recursive_draw_zone(
                zone_key            => $zone_key,
                zinc                => $zinc,
                app_display_data    => $app_display_data,
                cumulative_x_offset => 0,
                cumulative_y_offset => 0,
            );

        }
        $window_layout->{'sub_changed'} = 0;
    }

    # Raise the top layer above the earlier zones
    my $top_group_id = $self->get_zone_group_id(
        window_key       => $window_key,
        zone_key         => TOP_LAYER_ZONE_KEY,
        zinc             => $zinc,
        app_display_data => $app_display_data,
    );
    $zinc->raise($top_group_id);

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
        window_key       => $window_key,
        zinc             => $zinc,
        app_display_data => $app_display_data,
    );

    $self->draw_overview(
        window_key       => $window_key,
        app_display_data => $app_display_data,
    );

    # Only add back if using the -render flag
    #$zinc->itemconfigure($top_group_id, -alpha => 50);

    $self->reselect_object_selections( window_key => $window_key, );
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

        foreach my $zone_key ( $top_zone_key, ) {
            $self->draw_overview_zone(
                window_key       => $window_key,
                zone_key         => $zone_key,
                zinc             => $zinc,
                app_display_data => $app_display_data,
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
sub recursive_draw_zone {

=pod

=head2 recursive_draw_zone

Handles the recursion for draw zone.  This accumulates the zone offset.

=cut

    my ( $self, %args ) = @_;
    my $zone_key = $args{'zone_key'}
        or die 'no zone key for draw';
    my $cumulative_x_offset = $args{'cumulative_x_offset'};
    my $cumulative_y_offset = $args{'cumulative_y_offset'};
    my $zinc                = $args{'zinc'}
        || $self->zinc( window_key => $args{'window_key'}, );
    my $app_display_data = $args{'app_display_data'};

    my $zone_scaffold = $app_display_data->{'scaffold'}{$zone_key};
    my $zone_layout   = $app_display_data->{'zone_layout'}{$zone_key};

    my $zone_x_offset = $cumulative_x_offset + $zone_layout->{'bounds'}[0];
    my $zone_y_offset = $cumulative_y_offset + $zone_layout->{'bounds'}[1];

    my $zone_scroll_x_offset
        = $app_display_data->{'scaffold'}{$zone_key}->{'x_offset'};

    my $zone_group_id = $self->draw_zone(
        zone_key             => $zone_key,
        zinc                 => $zinc,
        app_display_data     => $app_display_data,
        zone_x_offset        => $zone_x_offset,
        zone_y_offset        => $zone_y_offset,
        zone_scroll_x_offset => $zone_scroll_x_offset,
    );

    # Raise this zone above the earlier zones
    $zinc->raise( $zone_group_id, );

    # Draw Children Zones
    foreach my $child_zone_key ( @{ $zone_scaffold->{'children'} || [] } ) {
        $self->recursive_draw_zone(
            zone_key            => $child_zone_key,
            zinc                => $zinc,
            app_display_data    => $app_display_data,
            cumulative_x_offset => $zone_x_offset + $zone_scroll_x_offset,
            cumulative_y_offset => $zone_y_offset,
        );
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
    my $zone_layout          = $app_display_data->{'zone_layout'}{$zone_key};
    my $zone_x_offset        = $args{'zone_x_offset'};
    my $zone_y_offset        = $args{'zone_y_offset'};
    my $zone_scroll_x_offset = $args{'zone_scroll_x_offset'};

    #my $parent_zone_key
    #    = $app_display_data->{'scaffold'}{$zone_key}{'parent_zone_key'};
    #my $parent_zone_x_offset
    #    = ($parent_zone_key)
    #    ? $app_display_data->{'scaffold'}{$parent_zone_key}->{'x_offset'}
    #    : 0;

    my $zone_scroll_y_offset = 0;

    my $total_x_offset = $zone_x_offset + $zone_scroll_x_offset;
    my $total_y_offset = $zone_y_offset + $zone_scroll_y_offset;

    my $zone_group_id = $self->get_zone_group_id(
        window_key       => $window_key,
        zone_key         => $zone_key,
        zinc             => $zinc,
        app_display_data => $app_display_data,
    );

    if ( $zone_layout->{'changed'} ) {

        # Move the zone to where it is supposed to be
        #        $zinc->coords(
        #            $zone_group_id,
        #            [   $parent_zone_x_offset + $zone_layout->{'bounds'}[0],
        #                $zone_layout->{'bounds'}[1]
        #            ]
        #        );

        #$self->set_zone_clip(
        #    zone_key      => $zone_key,
        #    zone_group_id => $zone_group_id,
        #    zinc          => $zinc,
        #    zone_layout   => $zone_layout,
        #);

        $self->draw_items(
            zinc     => $zinc,
            x_offset => $total_x_offset,
            y_offset => $total_y_offset,
            items    => $zone_layout->{'separator'},
            group_id => $zone_group_id,
            tags     => [ 'on_top', ],
        );

        $self->draw_items(
            zinc     => $zinc,
            x_offset => $zone_x_offset,                #$zone_scroll_x_offset,
            y_offset => $zone_y_offset,                #$total_y_offset,
            items    => $zone_layout->{'background'},
            group_id => $zone_group_id,
            tags     => [
                'on_bottom', 'background_' . $window_key . '_' . $zone_key
            ],
        );

        # Draw the buttons
        foreach my $button ( @{ $zone_layout->{'buttons'} || [] } ) {
            my $button_name = $button->{'button_name'};
            $self->draw_items(
                zinc     => $zinc,
                x_offset => $zone_x_offset,       #$zone_scroll_x_offset,
                y_offset => $zone_y_offset,       #$total_y_offset,
                items    => $button->{'items'},
                group_id => $zone_group_id,
                tags =>
                    [ $button_name . '_' . $window_key . '_' . $zone_key ],
            );
        }

        # Draw the scale bar
        $self->draw_items(
            zinc     => $zinc,
            x_offset => $zone_x_offset,                #$zone_scroll_x_offset,
            y_offset => $zone_y_offset,                #$total_y_offset,
            items    => $zone_layout->{'scale_bar'},
            group_id => $zone_group_id,
            tags => [ 'background_' . $window_key . '_' . $zone_key ],
        );

        $self->draw_items(
            zinc     => $zinc,
            x_offset => $total_x_offset,
            y_offset => $total_y_offset,
            items    => $zone_layout->{'location_bar'},
            group_id => $zone_group_id,
            tags =>
                [ 'on_top', 'location_bar_' . $window_key . '_' . $zone_key ],
        );

# The following places bars on the slot for debugging
#my @colors = ('red','black','blue','green','yellow','purple','orange','black','green','red','blue',);
#for ( my $i = 1; $i <= 10; $i++ ) {
#    $self->draw_items(
#        zinc     => $zinc,
#        x_offset => 0,       #$zone_scroll_x_offset,
#        y_offset => 0,       #$total_y_offset,
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

            # Debug - Draws marks every 100 pixels
            #foreach my $i ( 1 .. 6 ) {
            #    my $color = ($i ==1)?'red': 'blue';
            #    $self->draw_items(
            #        zinc     => $zinc,
            #        x_offset => $total_x_offset,
            #        y_offset => $total_y_offset,
            #        items    => [
            #            [   1, undef, 'rectangle',
            #                [ 1, 1, $i * 100, $i * 100 ],
            #                { -linecolor => $color, -linewidth => '1', }
            #            ],
            #        ],
            #        group_id => $zone_group_id,
            #        tags     => [ 'on_top', ],
            #    ) if ( $zone_key == 1 or $i == 1 );
            #}
            foreach my $drawing_section (qw[ items ]) {
                $self->draw_items(
                    zinc     => $zinc,
                    x_offset => $total_x_offset,
                    y_offset => $total_y_offset,
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
                        x_offset => $total_x_offset,
                        y_offset => $total_y_offset,
                        items    => $feature_layout->{'items'},
                        group_id => $zone_group_id,
                        tags     => [
                            'feature_'
                                . $zone_key . '_'
                                . $map_key . '_'
                                . $feature_acc,
                            'display',
                        ],
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

        # Binned Maps
        foreach (
            my $bin_index = 0;
            $bin_index <=
            $#{ $app_display_data->{'zone_bin_layouts'}{$zone_key} || [] };
            $bin_index++
            )
        {
            my $bin_layout
                = $app_display_data->{'zone_bin_layouts'}{$zone_key}
                [$bin_index];
            $self->draw_items(
                zinc     => $zinc,
                x_offset => $total_x_offset,
                y_offset => $total_y_offset,
                items    => $bin_layout->{'items'},
                tags     => [
                    'middle_layer',
                    'display',
                    'bin_maps_'
                        . $window_key . '_'
                        . $zone_key . '_'
                        . $bin_index
                ],
                group_id => $zone_group_id,
            );
            $self->record_zone_bin_drawn_id(
                bin_index => $bin_index,
                zone_key  => $zone_key,
                items     => $bin_layout->{'items'},
            );
            $bin_layout->{'changed'} = 0;
        }
        $zone_layout->{'sub_changed'} = 0;
    }

    return $zone_group_id;
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
    my $window_key = $args{'window_key'};
    my $zinc       = $args{'zinc'}
        || $self->zinc( window_key => $window_key, );
    my $app_display_data = $args{'app_display_data'};

    # The group id will be the top layer so that it can span zones
    my $group_id = $self->get_zone_group_id(
        window_key => $window_key,
        zone_key   => TOP_LAYER_ZONE_KEY,
        zinc       => $zinc,
    );

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
            my $map_key1  = $map_corr_layout->{'map_key1'};
            my $map_key2  = $map_corr_layout->{'map_key2'};
            my $zone_key1 = $app_display_data->map_key_to_zone_key($map_key1);
            my $zone_key2 = $app_display_data->map_key_to_zone_key($map_key2);
            my $x_offset1
                = $app_display_data->{'scaffold'}{$zone_key1}{'x_offset'};
            my $x_offset2
                = $app_display_data->{'scaffold'}{$zone_key2}{'x_offset'};
            my $tags = [ 'on_bottom', ];

            foreach my $corr ( @{ $map_corr_layout->{'corrs'} || [] } ) {
                foreach my $item ( @{ $corr->{'items'} || [] } ) {

                    # Has item been changed
                    next unless ( $item->[0] or not defined( $item->[0] ) );

                    my $item_id = $item->[1];
                    my $type    = $item->[2];
                    my @coords  = @{ $item->[3] };   # creates duplicate array
                    my $options = $item->[4];

                    $coords[0] += $x_offset1;
                    $coords[2] += $x_offset1;
                    $coords[4] += $x_offset2;
                    $coords[6] += $x_offset2;
                    if ( defined( $coords[8] ) ) {
                        $coords[8] += $x_offset2;
                    }

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
                            $item->[1]
                                = $zinc->add( $type, $group_id, \@coords,
                                %{$options}, );
                        }

                        foreach my $tag (@$tags) {
                            $zinc->addtag( $tag, 'withtag', $item->[1] );
                        }
                    }
                    $item->[0] = 0;
                }
            }
            $map_corr_layout->{'changed'} = 0;

        }
    }
    $corr_layout->{'changed'} = 0;

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
    my $overview = $args{'overview'} || 0;
    my $app_display_data = $args{'app_display_data'};

    my $storage_key = $overview ? 'ov_zone_group_id' : 'zone_group_id';
    my $rev_storage_key
        = $overview ? 'ov_group_to_zone_key' : 'zone_group_to_zone_key';

    unless ( $self->{$storage_key}{$window_key}{$zone_key} ) {
        my $parent_group_id;
        if ( $zone_key == TOP_LAYER_ZONE_KEY ) {

            # The TOP_LAYER is a special group that will share the same coords
            # as the root group but be kept on top of all the other groups
            $parent_group_id = 1;
        }
        elsif ( $overview
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

    # return unless it has been layed out.
    return unless ( defined $zone_layout->{'internal_bounds'}[0] );

    #my $fillcolor = ( $zone_key == 1 ) ? 'blue' : 'red';
    my $clip_bounds = [
        $zone_layout->{'internal_bounds'}[0],
        $zone_layout->{'internal_bounds'}[1],
        $zone_layout->{'internal_bounds'}[2],
        $zone_layout->{'internal_bounds'}[3]
    ];

    if ( $clip_bounds->[0] < MIN_ZINC_X_COORD ) {
        $clip_bounds->[0] = MIN_ZINC_X_COORD;
    }
    if ( $clip_bounds->[2] > MAX_ZINC_CLIP_X_COORD ) {
        $clip_bounds->[2] = MAX_ZINC_CLIP_X_COORD;
    }

    if ( $self->{'zone_group_clip_id'}{$zone_key} ) {
        $zinc->coords( $self->{'zone_group_clip_id'}{$zone_key}, $clip_bounds,
        );
    }
    else {
        $self->{'zone_group_clip_id'}{$zone_key} = $zinc->add(
            'rectangle', $zone_group_id,
            $clip_bounds,
            -visible => 0,

            #-filled    => 1,
            #-fillcolor => $fillcolor,
        );
        $zinc->addtag( 'on_top', 'withtag',
            $self->{'zone_group_clip_id'}{$zone_key} );
        $zinc->itemconfigure( $zone_group_id,
            -clip => $self->{'zone_group_clip_id'}{$zone_key}, );
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
    my $debug    = $args{'debug'} || 0;

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

        ## Maybe don't let it draw out of bounds
        #my $min_zinc_value = -32868;
        #my $max_zinc_value = 32756;
        my $min_zinc_value = -30868;
        my $max_zinc_value = 30756;
        for ( my $i = 0; $i <= $#coords; $i++ ) {
            if ( $coords[$i] <= $min_zinc_value ) {
                $coords[$i] = $min_zinc_value;
            }
            if ( $coords[$i] >= $max_zinc_value ) {
                $coords[$i] = $max_zinc_value;
            }
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
    my $items = $args{'items'} || return;

    $self->{'map_key_to_drawn_ids'}{$map_key} = [];
    for ( my $i = 0; $i <= $#{ $items || [] }; $i++ ) {
        $self->{'drawn_id_to_map_key'}{ $items->[$i][1] } = $map_key;
        push @{ $self->{'map_key_to_drawn_ids'}{$map_key} }, $items->[$i][1];
    }
    @{ $self->{'map_key_to_drawn_ids'}{$map_key} }
        = sort { $b <=> $a } @{ $self->{'map_key_to_drawn_ids'}{$map_key} };
}

# ----------------------------------------------------
sub record_zone_bin_drawn_id {

=pod

=head2 record_zone_bin_drawn_id

Create a hash lookup for ids to a zone bin

Item structure:

  [ changed, item_id, type, coord_array, options_hash ]

=cut

    my ( $self, %args ) = @_;
    my $zone_key  = $args{'zone_key'};
    my $bin_index = $args{'bin_index'};
    my $items     = $args{'items'} || return;

    $self->{'zone_bin_to_drawn_ids'}{$zone_key}[$bin_index] = [];
    for ( my $i = 0; $i <= $#{ $items || [] }; $i++ ) {
        $self->{'drawn_id_to_zone_bin'}{ $items->[$i][1] }
            = [ $zone_key, $bin_index ];
        push @{ $self->{'zone_bin_to_drawn_ids'}{$zone_key}[$bin_index] },
            $items->[$i][1];
    }
    @{ $self->{'zone_bin_to_drawn_ids'}{$zone_key}[$bin_index] }
        = sort { $b <=> $a }
        @{ $self->{'zone_bin_to_drawn_ids'}{$zone_key}[$bin_index] };
}

# ----------------------------------------------------
sub drawn_id_to_map_key {

=pod

=head2 drawn_id_to_map_key

Accessor method to map_keys from drawn ids

=cut

    my ( $self, $drawn_id, ) = @_;

    return $self->{'drawn_id_to_map_key'}{$drawn_id};
}

# ----------------------------------------------------
sub drawn_id_to_zone_bin_info {

=pod

=head2 drawn_id_to_zone_bin_info

Accessor method to zone_bin_infos from drawn ids

=cut

    my ( $self, $drawn_id, ) = @_;

    return $self->{'drawn_id_to_zone_bin_info'}{$drawn_id};
}

# ----------------------------------------------------
sub map_key_to_drawn_ids {

=pod

=head2 map_key_to_drawn_ids

Accessor method to drawn ids from a map_key

=cut

    my ( $self, $map_key, ) = @_;

    return @{ $self->{'map_key_to_drawn_ids'}{$map_key} || [] };
}

# ----------------------------------------------------
sub zone_bin_to_drawn_ids {

=pod

=head2 map_key_to_drawn_ids

Accessor method to drawn ids from a map_key

=cut

    my ( $self, $zone_key, $bin_index, ) = @_;

    return @{ $self->{'zone_bin_to_drawn_ids'}{$zone_key}[$bin_index] || [] };
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

=pod

=head2 drawn_id_to_feature_acc

Accessor method to feature_accs from drawn ids

=cut

    my ( $self, $drawn_id, ) = @_;

    return $self->{'drawn_id_to_feature_acc'}{$drawn_id};
}

# ----------------------------------------------------
sub feature_acc_to_drawn_ids {

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
sub file_menu_items {

=pod

=head2 file_menu_items

Populates the file menu with menu_items

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'}
        or die 'no window key for file_menu_items';
    my $new_menu_item_list = $args{'new_menu_item_list'};
    unless ( $self->{'menu_items'}{$window_key}{'File'} ) {
        $self->{'menu_items'}{$window_key}{'File'} = [
            [   'command',
                '~New View',
                -accelerator => 'Ctrl-n',
                -command     => sub {
                    $self->new_view();
                },
            ],
            [   'command',
                '~Open View',
                -accelerator => 'Ctrl-o',
                -command     => sub {
                    $self->open_saved_view();
                },
            ],
            [   'command',
                '~Save View',
                -accelerator => 'Ctrl-s',
                -command     => sub {
                    $self->save_view( window_key => $window_key, );
                },
            ],

            #[   'command',
            #    '~Export Changes',
            #    -accelerator => 'Ctrl-e',
            #    -command     => sub {
            #        $self->export_changes( window_key => $window_key, );
            #    },
            #],
            [   'command',
                '~Refresh From Database',
                -command => sub {
                    my $answer = $self->main_window()->Dialog(
                        -title => 'Refresh From the Database?',
                        -text => 'Are you certain that you want to refresh?  '
                            . 'Any changes that you have made will be lost.  '
                            . 'This cannot be undone.',
                        -default_button => 'Cancel',
                        -buttons        => [ 'OK', 'Cancel', ],
                    )->Show();

                    if ( $answer eq 'OK' ) {
                        $self->app_controller()->app_display_data()
                            ->refresh_program_from_database();
                    }
                },
            ],
            [   'command',
                '~Commit Changes',
                -command => sub {
                    $self->commit_changes( window_key => $window_key, );
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
        $self->{'menu_items'}{$window_key}{'File'} = $new_menu_item_list;
    }

    return $self->{'menu_items'}{$window_key}{'File'};
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
    unless ( $self->{'menu_items'}{$window_key}{'Edit'} ) {
        $self->{'menu_items'}{$window_key}{'Edit'} = [
            [   'command',
                '~Undo',
                -accelerator => 'Ctrl-z',
                -command     => sub {
                    $self->app_controller()
                        ->app_display_data->undo_action(
                        window_key => $window_key, );
                    $self->reset_object_selections( window_key => $window_key,
                    );
                },
            ],
            [   'command',
                '~Redo',
                -accelerator => 'Ctrl-y',
                -command     => sub {
                    $self->app_controller()
                        ->app_display_data->redo_action(
                        window_key => $window_key, );
                    $self->reset_object_selections( window_key => $window_key,
                    );
                },
            ],
            [   'command',
                '~Highlight',
                -accelerator => 'Ctrl-h',
                -command     => sub {
                    $self->highlight_menu_popup( window_key => $window_key, );
                    $self->app_controller()
                        ->app_display_data->redraw_the_whole_window(
                        window_key => $window_key, );
                },
            ],
        ];
    }

    # If a new list is specified, overwrite the old list.
    if ($new_menu_item_list) {
        $self->{'menu_items'}{$window_key}{'Edit'} = $new_menu_item_list;
    }

    return $self->{'menu_items'}{$window_key}{'Edit'};
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

        #my $zinc_frame = $self->{'zinc_pane'}{$window_key};

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

        # Using the -render flag allows transparency but slows it down
        # considerably
        #$self->{'zinc'}{$window_key} = $zinc_frame->Zinc(
        #    -width       => 1100,
        #    -height      => 800,
        #    -backcolor   => 'white',
        #    -borderwidth => 2,
        #    -relief      => 'sunken',
        #    #-render      => 1,
        #);
        my $window = $self->{'windows'}{$window_key};
        $self->{'zinc'}{$window_key} = $window->Scrolled(
            "Zinc",
            -width       => 1100,
            -height      => 800,
            -backcolor   => 'white',
            -borderwidth => 0,
            -relief      => 'sunken',
            -scrollbars  => 'oe',

            #-render      => 1,
        );

        $self->{'zinc'}{$window_key}
            ->addtag( 'window_key_' . $window_key, 'withtag', 1 );

        $self->bind_zinc(
            zinc => $self->{'zinc'}{$window_key}->Subwidget("zinc") );
    }
    return $self->{'zinc'}{$window_key}->Subwidget("zinc");
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
            $self->start_drag_left_mouse( $zinc, $e->x, $e->y, 0, );
        }
    );

    $zinc->Tk::bind(
        '<3>' => sub {
            my ($zinc) = @_;
            my $e = $zinc->XEvent;
            $self->start_drag_right_mouse( $zinc, $e->x, $e->y, 0, );
        }
    );
    $zinc->Tk::bind(
        '<Control-1>' => sub {
            my ($zinc) = @_;
            my $e = $zinc->XEvent;
            $self->start_drag_left_mouse( $zinc, $e->x, $e->y, 1, );
        }
    );

    $zinc->Tk::bind(
        '<Control-3>' => sub {
            my ($zinc) = @_;
            my $e = $zinc->XEvent;
            $self->start_drag_right_mouse( $zinc, $e->x, $e->y, 1, );
        }
    );
    $zinc->Tk::bind(
        '<B1-ButtonRelease>' => sub {
            my ($zinc) = @_;
            my $e = $zinc->XEvent;
            $self->stop_drag_left_mouse( $zinc, $e->x, $e->y, );
        }
    );
    $zinc->Tk::bind(
        '<B3-ButtonRelease>' => sub {
            my ($zinc) = @_;
            my $e = $zinc->XEvent;
            $self->stop_drag_right_mouse( $zinc, $e->x, $e->y, );
        }
    );
    $zinc->Tk::bind(
        '<B1-Motion>' => sub {
            $self->drag_left_mouse( shift, $Tk::event->x, $Tk::event->y, );
        }
    );
    $zinc->Tk::bind(
        '<B3-Motion>' => sub {
            $self->drag_right_mouse( shift, $Tk::event->x, $Tk::event->y, );
        }
    );
    if ( $^O eq 'MSWin32' ) {
        $zinc->Tk::bind(
            '<MouseWheel>' => sub {
                $self->mouse_wheel_event( $zinc, ( Ev('D') < 0 ) ? 0.5 : 2 );
            }
        );
    }
    else {
        $zinc->Tk::bind(
            '<4>' => sub {
                $self->mouse_wheel_event( $zinc, 0.5 );
            }
        );
        $zinc->Tk::bind(
            '<5>' => sub {
                $self->mouse_wheel_event( $zinc, 2 );
            }
        );

    }

}

# ----------------------------------------------------
sub get_window_key_from_zinc {

=pod

=head2 get_window_key_from_zinc

Return the window key from the zinc object, this is stored as a tag to the root
group on the zinc.

=cut

    my ( $self, %args ) = @_;
    my $zinc = $args{'zinc'} or return undef;

    my $root_group_id = 1;

    if ( my @tags = grep /^window_key_/, $zinc->gettags($root_group_id) ) {
        $tags[0] =~ /^window_key_(\S+)/;
        return $1;
    }

    return undef;
}

# ----------------------------------------------------
sub bind_overview_zinc {

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
            $self->start_drag_right_mouse( $zinc, $e->x, $e->y, );
        }
    );
    $zinc->CanvasBind(
        '<B1-ButtonRelease>' => sub {
            my ($zinc) = @_;
            my $e = $zinc->XEvent;
            $self->stop_drag_right_mouse( $zinc, $e->x, $e->y, );
        }
    );
    $zinc->CanvasBind(
        '<B1-Motion>' => sub {
            $self->drag_right_mouse( shift, $Tk::event->x, $Tk::event->y, );
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

        # Using the -render flag allows transparency but slows it down
        # considerably
        $self->{'overview_zinc'}{$window_key} = $overview_zinc_frame->Zinc(
            -width       => 300,
            -height      => 300,
            -backcolor   => 'white',
            -borderwidth => 2,
            -relief      => 'sunken',

            #-render      => 1,
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

=pod

=head2 popup_map_menu


=cut

    my ( $self, %args ) = @_;
    my $zinc             = $args{'zinc'};
    my $moved            = $args{'moved'};
    my $map_key          = $args{'map_key'};
    my $mouse_x          = $args{'mouse_x'};
    my $mouse_y          = $args{'mouse_y'};
    my $controller       = $self->app_controller();
    my $app_display_data = $controller->app_display_data();

    my $window_key = $self->get_window_key_from_zinc( zinc => $zinc, );
    my $menu_items = [];
    if ($map_key) {
        my $zone_key = $app_display_data->map_key_to_zone_key($map_key);
        my $map_num  = $self->number_of_object_selections( $window_key, );

        my $map_layout = $app_display_data->{'map_layout'}{$map_key};

        push @$menu_items, [
            Button => $map_layout->{'flipped'} ? 'Unflip' : 'Flip',
            -command => sub {
                $app_display_data->flip_map( map_key => $map_key, );
            },
        ];

        # Map has been moved
        if ( $moved
            and not $app_display_data->{'scaffold'}{$zone_key}{'is_top'} )
        {
            my $map_id = $self->app_controller()->app_display_data()
                ->map_key_to_id($map_key);
            my $map_data
                = $self->app_data_module()->map_data( map_id => $map_id, );
            my $map_type_acc = $map_data->{'map_type_acc'};
            if ( $self->map_type_data( $map_type_acc, 'subsection' ) ) {
                push @$menu_items, [
                    Button   => 'Move Subsection',
                    -command => sub {
                        $self->move_map_subsection_popup(
                            map_key    => $map_key,
                            window_key => $window_key,
                            zinc       => $zinc,
                            mouse_x    => $mouse_x,
                            mouse_y    => $mouse_y,
                        );
                    },
                ];
            }
            else {
                push @$menu_items, [
                    Button   => 'Move Map',
                    -command => sub {
                        $self->move_map_popup(
                            map_key    => $map_key,
                            window_key => $window_key,
                            zinc       => $zinc,
                        );
                    },
                ];
            }
        }
        push @$menu_items, [
            Button   => 'New Window',
            -command => sub {
                my @object_selection_keys
                    = $self->object_selection_keys($window_key);
                my $selected_type
                    = $self->object_selected_type( window_key => $window_key,
                    );
                if ( $selected_type eq 'map' and @object_selection_keys ) {
                    $controller->open_new_window(
                        selected_map_keys => \@object_selection_keys, );
                }
                else {
                    $controller->open_new_window(
                        selected_map_keys => [$map_key], );
                }
            },
        ];
        if ( !$moved ) {
            if ( $map_num == 1 ) {
                push @$menu_items, [
                    Button   => 'Split Map',
                    -command => sub {
                        $self->split_map_popup(
                            map_key    => $map_key,
                            window_key => $window_key,
                            zinc       => $zinc,
                            mouse_x    => $mouse_x,
                        );
                    },
                ];
            }
            elsif ( $map_num == 2 ) {
                my @object_selection_keys
                    = $self->object_selection_keys($window_key);
                push @$menu_items, [
                    Button   => 'Merge Maps',
                    -command => sub {
                        $self->merge_maps_popup(
                            map_key1   => $object_selection_keys[0],
                            map_key2   => $object_selection_keys[1],
                            window_key => $window_key,
                            zinc       => $zinc,
                        );
                    },
                ];
            }
        }
    }

    my $report_menu_items = [];
    push @$report_menu_items, [
        Button   => 'Correspondences',
        -command => sub {
            my @map_ids = map { $app_display_data->map_key_to_id($_) }
                $self->object_selection_keys($window_key);
            my ( $report_string, $table_data, )
                = $controller->app_data_module()
                ->map_correspondence_report_data( map_ids => \@map_ids, );
            $self->display_report(
                table_data      => $table_data,
                report_string   => $report_string,
                table_title_row => 1,
            );

            return;
        },
    ];

    $self->app_controller()->plugin_set()->modify_right_click_menu(
        window_key        => $window_key,
        menu_items        => $menu_items,
        report_menu_items => $report_menu_items,
        type              => 'map',
    );

    push @$menu_items,
        [
         cascade   => 'Reports',
        -tearoff   => 0,
        -menuitems => $report_menu_items,
        ];
    push @$menu_items, [
        Button   => 'Cancel',
        -command => sub {
            return;
        },
    ];

    my $menu = $self->main_window()->Menu(
        -tearoff   => 0,
        -menuitems => $menu_items,
    );

    $menu->bind(
        '<FocusOut>',
        sub {
            $self->reset_object_selections(
                zinc       => $zinc,
                window_key => $window_key,
            ) if ($moved);
            $menu->destroy();
        },
    );
    $menu->Popup( -popover => "cursor", -popanchor => 'nw' );

    return;
}

# ----------------------------------------------------
sub popup_feature_menu {

=pod

=head2 popup_feature_menu


=cut

    my ( $self, %args ) = @_;
    my $zinc             = $args{'zinc'};
    my $moved            = $args{'moved'};
    my $feature_acc      = $args{'feature_acc'};
    my $mouse_x          = $args{'mouse_x'};
    my $mouse_y          = $args{'mouse_y'};
    my $controller       = $self->app_controller();
    my $app_display_data = $controller->app_display_data();

    my $window_key = $self->get_window_key_from_zinc( zinc => $zinc, );

    my $menu_items        = [];
    my $report_menu_items = [];

    $self->app_controller()->plugin_set()->modify_right_click_menu(
        window_key        => $window_key,
        menu_items        => $menu_items,
        report_menu_items => $report_menu_items,
        type              => 'feature',
    );

    push @$menu_items,
        [
         cascade   => 'Reports',
        -tearoff   => 0,
        -menuitems => $report_menu_items,
        ]
        if (@$report_menu_items);

    if (@$menu_items) {
        push @$menu_items, [
            Button   => 'Cancel',
            -command => sub {
                return;
            },
        ];

        my $menu = $self->main_window()->Menu(
            -tearoff   => 0,
            -menuitems => $menu_items,
        );

        $menu->bind(
            '<FocusOut>',
            sub {
                $self->reset_object_selections(
                    zinc       => $zinc,
                    window_key => $window_key,
                ) if ($moved);
                $menu->destroy();
            },
        );
        $menu->Popup( -popover => "cursor", -popanchor => 'nw' );
    }

    return;
}

# ----------------------------------------------------
sub popup_background_menu {

=pod

=head2 popup_background_menu


=cut

    my ( $self, %args ) = @_;
    my $zinc             = $args{'zinc'};
    my $window_key       = $args{'window_key'};
    my $zone_key         = $args{'zone_key'};
    my $mouse_x          = $args{'mouse_x'};
    my $mouse_y          = $args{'mouse_y'};
    my $controller       = $self->app_controller();
    my $app_display_data = $controller->app_display_data();

    my $menu_items = [];

    #push @$menu_items,
    #    [
    #     cascade   => 'Correspondence Options',
    #    -tearoff   => 0,
    #    -menuitems => $self->popup_corr_menu(
    #        window_key => $window_key,
    #        zone_key   => ${ $self->{'selected_zone_key_scalar'} },
    #    ),
    #    ];
    #}

    push @$menu_items, [
        Button   => '+Correspondence Options',
        -command => sub {
            $self->popup_corr_menu(
                window_key => $window_key,
                zone_key   => ${ $self->{'selected_zone_key_scalar'} },
            );
        },
    ];
    push @$menu_items, [
        Button   => '+Display Options',
        -command => sub {
            $self->popup_display_options_menu(
                window_key => $window_key,
                zone_key   => ${ $self->{'selected_zone_key_scalar'} },
            );
        },
    ];
    push @$menu_items, [
        Button   => 'Add Sub Maps',
        -command => sub {
            $self->app_controller()->expand_zone(
                window_key => $window_key,
                zone_key   => ${ $self->{'selected_zone_key_scalar'} },
            );
        },
    ];

    my $report_menu_items = [];

    $self->app_controller()->plugin_set()->modify_right_click_menu(
        window_key        => $window_key,
        menu_items        => $menu_items,
        report_menu_items => $report_menu_items,
        type              => 'zone',
    );

    push @$menu_items,
        [
         cascade   => 'Reports',
        -tearoff   => 0,
        -menuitems => $report_menu_items,
        ]
        if (@$report_menu_items);

    push @$menu_items, [
        Button   => 'Cancel',
        -command => sub {
            return;
        },
    ];

    my $menu = $self->main_window()->Menu(
        -title => 'Dude',
        -type  => 'tearoff',

        #-type => 'normal',
        -tearoff   => 0,
        -menuitems => $menu_items,
    );

    $menu->bind(
        '<FocusOut>',
        sub {
            $menu->destroy();
        },
    );
    $menu->Popup( -popover => "cursor", -popanchor => 'nw' );

    return;
}

# ----------------------------------------------------
sub popup_corr_menu {

=pod

=head2 popup_corr_menu


=cut

    my ( $self, %args ) = @_;
    my $window_key       = $args{'window_key'};
    my $zone_key         = $args{'zone_key'};
    my $controller       = $self->app_controller();
    my $app_display_data = $controller->app_display_data();

    my ( $corr_menu_data, $zone_map_set_data )
        = $app_display_data->get_correspondence_menu_data(
        zone_key => $zone_key, );

    my $menu_items = [];
    push @$menu_items, [
        Button   => 'Show All Correspondences',
        -command => sub {
            $app_display_data->set_corrs_map_set(
                zone_key   => $zone_key,
                window_key => $window_key,
                map_set_ids =>
                    [ map { $_->{'map_set_id'} } @$corr_menu_data ],
                corrs_on => 1,
            );
        },
    ];
    push @$menu_items, [
        Button   => 'Hide All Correspondences',
        -command => sub {
            $app_display_data->set_corrs_map_set(
                zone_key   => $zone_key,
                window_key => $window_key,
                map_set_ids =>
                    [ map { $_->{'map_set_id'} } @$corr_menu_data ],
                corrs_on => 0,
            );
        },
    ];

    my $map_set_id = $zone_map_set_data->{'map_set_id'};
    my $corrs_on = ( $zone_map_set_data->{'corrs_on'} ) ? 1 : 0;

    push @$menu_items, [
        'checkbutton' => '',
        -variable     => \$corrs_on,
        -onvalue      => 1,
        -offvalue     => 0,
        -label        => 'Self',
        -command      => sub {
            $app_display_data->set_corrs_map_set(
                zone_key   => $zone_key,
                window_key => $window_key,
                map_set_id => $map_set_id,
                corrs_on   => $corrs_on,
            );
        },
    ];

    foreach my $individual_corr_data (
        sort {
            $a->{'map_set_data'}{'map_set_name'}
                cmp $b->{'map_set_data'}{'map_set_name'}
        } @$corr_menu_data
        )
    {
        my $map_set_id = $individual_corr_data->{'map_set_id'};
        my $corrs_on = ( $individual_corr_data->{'corrs_on'} ) ? 1 : 0;

        push @$menu_items, [
            'checkbutton' => '',
            -variable     => \$corrs_on,
            -onvalue      => 1,
            -offvalue     => 0,
            -label => $individual_corr_data->{'map_set_data'}{'map_set_name'},
            -command => sub {
                $app_display_data->set_corrs_map_set(
                    zone_key   => $zone_key,
                    window_key => $window_key,
                    map_set_id => $map_set_id,
                    corrs_on   => $corrs_on,
                );
            },
        ];
    }
    my $offscreen_corrs_visible
        = $app_display_data->offscreen_corrs_visible($zone_key);
    push @$menu_items, [
        'checkbutton' => '',
        -variable     => \$offscreen_corrs_visible,
        -onvalue      => 1,
        -offvalue     => 0,
        -label        => 'Show Correspondences that lead off-screen',
        -command      => sub {
            $app_display_data->set_offscreen_corrs_visibility( $zone_key,
                $offscreen_corrs_visible, );
        },
    ];

    push @$menu_items, [
        Button   => 'Cancel',
        -command => sub {
            return;
        },
    ];

    my $menu = $self->main_window()->Menu(
        -tearoff   => 0,
        -menuitems => $menu_items,
    );

    $menu->Popup( -popover => "cursor", -popanchor => 'nw' );
    return $menu_items;
}

# ----------------------------------------------------
sub popup_display_options_menu {

=pod

=head2 popup_display_options_menu


=cut

    my ( $self, %args ) = @_;
    my $window_key       = $args{'window_key'};
    my $zone_key         = $args{'zone_key'};
    my $controller       = $self->app_controller();
    my $app_display_data = $controller->app_display_data();

    my $menu_items = [];

    my $map_labels_visible = $app_display_data->map_labels_visible($zone_key);
    push @$menu_items, [
        'checkbutton' => '',
        -variable     => \$map_labels_visible,
        -onvalue      => 1,
        -offvalue     => 0,
        -label        => 'Display Map Labels',
        -command      => sub {
            $app_display_data->set_map_labels_visibility( $zone_key,
                $map_labels_visible, );
        },
    ];

    my $features_visible = $app_display_data->features_visible($zone_key);
    push @$menu_items, [
        'checkbutton' => '',
        -variable     => \$features_visible,
        -onvalue      => 1,
        -offvalue     => 0,
        -label        => 'Display Features',
        -command      => sub {
            $app_display_data->set_features_visibility( $zone_key,
                $features_visible, );
        },
    ];

    push @$menu_items, [
        Button   => 'Cancel',
        -command => sub {
            return;
        },
    ];

    my $menu = $self->main_window()->Menu(
        -tearoff   => 0,
        -menuitems => $menu_items,
    );

    $menu->Popup( -popover => "cursor", -popanchor => 'nw' );

    return;
}

# ----------------------------------------------------
sub fill_info_box {

=pod

=head2 fill_info_box


=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;

    my $controller       = $self->app_controller();
    my $app_display_data = $controller->app_display_data();
    my $object_selected_type
        = $self->object_selected_type( window_key => $window_key );
    my $object_selections = $self->{'object_selections'}{$window_key};
    my $new_text;

    # prepare the info box
    my $text_box = $self->{'information_text'}{$window_key};
    $text_box->configure( -state => 'normal', );

    # Wipe old info
    $text_box->delete( "1.0", 'end' );

    # Blank the info box if no selections are made
    if ( not $object_selected_type or not keys %{ $object_selections || {} } )
    {
        $new_text = '';
    }
    elsif ( $object_selected_type eq 'map' ) {
        if ( $self->number_of_object_selections( $window_key, ) == 1 ) {
            my ( $map_key, ) = keys %{ $object_selections || {} };
            my $zone_key
                = $self->{'first_object_selection_zone_key'}{$window_key};

            $new_text = $controller->get_map_info_text(
                map_key    => $map_key,
                window_key => $window_key,
            );

            #$new_text = "$map_key:". $new_text;###DEBUG
        }
        else {
            $new_text = $self->number_of_object_selections( $window_key, )
                . ' Maps Selected';
        }
    }
    elsif ( $object_selected_type eq 'feature' ) {
        if ( $self->number_of_object_selections( $window_key, ) == 1 ) {
            my ( $feature_acc, ) = keys %{ $object_selections || {} };
            $new_text = $controller->get_feature_info_text(
                feature_acc => $feature_acc, );
        }
        else {
            $new_text = $self->number_of_object_selections( $window_key, )
                . ' Features Selected';
        }
    }

    $text_box->insert( 'end', $new_text );
    $text_box->configure( -state => 'disabled', );

    return;
}

# ----------------------------------------------------
sub highlight_map_corrs {

=pod

=head2 highlight_map_corrs


=cut

    my ( $self, %args ) = @_;
    my $zinc       = $args{'zinc'}       or return;
    my $map_key    = $args{'map_key'}    or return;
    my $zone_key   = $args{'zone_key'}   or return;
    my $window_key = $args{'window_key'} or return;
    my $color      = $args{'color'}      or return;

    my $controller       = $self->app_controller();
    my $app_display_data = $controller->app_display_data();
    my $app_data_module  = $controller->app_data_module();

    my $map_corrs = $app_display_data->{'corr_layout'}{'maps'}{$map_key}
        || {};
    foreach my $map_key2 ( keys %$map_corrs ) {
        foreach my $corr ( @{ $map_corrs->{$map_key2}{'corrs'} || [] } ) {
            my $feature_id1   = $corr->{'feature_id1'};
            my $feature_id2   = $corr->{'feature_id2'};
            my $corr_map_key1 = $corr->{'map_key1'};
            my $corr_map_key2 = $corr->{'map_key2'};
            my $feature_acc1
                = $app_data_module->feature_id_to_acc($feature_id1);
            my $feature_acc2
                = $app_data_module->feature_id_to_acc($feature_id2);
            my @corr_drawn_ids;
            foreach my $item ( @{ $corr->{'items'} || [] } ) {
                next unless ( $item->[1] );
                push @corr_drawn_ids, $item->[1];
            }
            my ( $tmp_bounds, $tmp_highlight_ids ) = $self->highlight_object(
                zinc       => $zinc,
                ori_ids    => \@corr_drawn_ids,
                zone_key   => $zone_key,
                window_key => $window_key,
                color      => $color,
            );
            push @{ $map_corrs->{$map_key2}{'highlight_ids'} },
                @{ $tmp_highlight_ids || [] };

            my @feature_drawn_ids;
            foreach my $vals (
                [ $feature_acc1, $corr_map_key1 ],
                [ $feature_acc2, $corr_map_key2 ]
                )
            {
                my $feature_acc  = $vals->[0];
                my $corr_map_key = $vals->[1];
                if (    $feature_acc
                    and $app_display_data->{'map_layout'}{$corr_map_key}
                    {'features'}
                    and $app_display_data->{'map_layout'}{$corr_map_key}
                    {'features'}{$feature_acc} )
                {
                    foreach my $item (
                        @{  $app_display_data->{'map_layout'}{$corr_map_key}
                                {'features'}{$feature_acc}{'items'} || []
                        }
                        )
                    {
                        next unless ( $item->[1] );
                        push @feature_drawn_ids, $item->[1];
                    }
                }
                my $corr_zone_key
                    = $app_display_data->map_key_to_zone_key($corr_map_key);
                my ( $tmp_bounds, $tmp_highlight_ids )
                    = $self->highlight_object(
                    zinc       => $zinc,
                    ori_ids    => \@feature_drawn_ids,
                    zone_key   => $corr_zone_key,
                    window_key => $window_key,
                    color      => 'green'
                    );
                push @{ $map_corrs->{$map_key2}{'highlight_ids'} },
                    @{ $tmp_highlight_ids || [] };
            }
        }
    }

    return;
}

# ----------------------------------------------------
sub unhighlight_map_corrs {

=pod

=head2 unhighlight_map_corrs


=cut

    my ( $self, %args ) = @_;
    my $zinc    = $args{'zinc'}    or return;
    my $map_key = $args{'map_key'} or return;

    my $controller       = $self->app_controller();
    my $app_display_data = $controller->app_display_data();

    my $map_corrs = $app_display_data->{'corr_layout'}{'maps'}{$map_key}
        || {};

    foreach my $map_key2 ( keys %$map_corrs ) {
        foreach my $highlight_id (
            @{ $map_corrs->{$map_key2}{'highlight_ids'} || [] } )
        {
            $zinc->remove($highlight_id);
        }
        $map_corrs->{$map_key2}{'highlight_ids'} = [];
    }

    return;
}

# ----------------------------------------------------
sub export_changes {

=pod

=head2 export_changes

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

    $self->app_controller()->export_changes(
        window_key       => $window_key,
        export_file_name => $export_file_name,
    );

    return;
}

# ----------------------------------------------------
sub commit_changes {

=pod

=head2 commit_changes


=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};

    my $answer = $self->main_window()->Dialog(
        -title => 'Commit Changes?',
        -text =>
            'Would you like to commit the changes you have made to the database?  This cannot be undone.',
        -default_button => 'Cancel',
        -buttons        => [ 'OK', 'Cancel', ],
    )->Show();

    if ( $answer eq 'OK' ) {
        $self->app_controller()->commit_changes( window_key => $window_key, );
    }

    return;
}

# ----------------------------------------------------
sub highlight_menu_popup {

=pod

=head2 highlight_menu_popup

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $controller = $self->app_controller();

    my $highlight_string
        = $controller->app_display_data->get_highlight_string(
        window_key => $window_key, );

    my $popup = $self->main_window()->Dialog(
        -title          => 'Highlight Maps and Features',
        -default_button => 'OK',
        -buttons        => [ 'OK', 'Cancel', ],
    );
    $popup->add(
        'LabEntry',
        -textvariable => \$highlight_string,
        -width        => 50,
        -label =>
            'Highlight (comma separated list of map and/or feature names)',
        -labelPack => [ -side => 'top' ],
    )->pack();
    my $answer = $popup->Show();

    if ( $answer eq 'OK' ) {
        $controller->app_display_data->parse_highlight(
            window_key       => $window_key,
            highlight_string => $highlight_string,
        );
    }

    return;
}

# ----------------------------------------------------
sub popup_warning {

=pod

=head2 popup_warning


=cut

    my ( $self, %args ) = @_;
    my $text = $args{'text'};

    $self->main_window()->Dialog(
        -title          => 'Warning',
        -text           => $text,
        -default_button => 'OK',
        -buttons        => [ 'OK', ],
    )->Show();

    return;
}

# ----------------------------------------------------
sub display_report {

=pod

=head2 display_report

=cut

    my ( $self, %args ) = @_;
    my $title            = $args{'title'} || 'Report';
    my $report_string    = $args{'report_string'};
    my $table_data       = $args{'table_data'};
    my $table_title_rows = $args{'table_title_row'} ? 1 : 0;
    my $table_title_cols = $args{'table_title_col'} ? 1 : 0;

    my $report_window = $self->main_window()->Toplevel( -takefocus => 1 );
    $report_window->title($title);
    if ($report_string) {
        my $font = [ 'Times', 12, ];
        my $text_box = $report_window->Scrolled(
            'Text',
            -font       => $font,
            -background => "white",
            -width      => 40,
            -height     => 8,
        )->pack( -fill => 'both' );
        $text_box->insert( 'end', $report_string );
        $text_box->configure( -state => 'disabled', );
    }
    if ($table_data) {
        my $cells     = {};
        my $row_index = 0;
        my $col_num   = 0;
        my $row_num   = 0;
        my @col_width;
        foreach my $report_row ( @{ $table_data || [] } ) {
            my $cell_index = 0;
            foreach my $report_cell ( @{ $report_row || [] } ) {
                $cells->{ $row_index . ',' . $cell_index } = $report_cell;
                if ( !$col_width[$cell_index]
                    or $col_width[$cell_index] < length($report_cell) )
                {
                    $col_width[$cell_index] = length($report_cell);
                }
                $cell_index++;
            }
            $col_num = $cell_index if ( $cell_index > $col_num );
            $row_index++;
        }
        $row_num = $row_index;
        my $spreadsheet = $report_window->Scrolled(
            'Spreadsheet',
            -cols           => $col_num,
            -rows           => $row_num,
            -rowheight      => 2,
            -titlerows      => $table_title_rows,
            -titlecols      => $table_title_cols,
            -variable       => $cells,
            -borderwidth    => [ 0, 1, 0, 1, ],
            -selecttype     => 'cell',
            -background     => 'white',
            -justify        => 'left',
            -drawmode       => 'compatible',
            -wrap           => 1,
            -relief         => 'solid',
            -colstretchmode => 'all',
            -rowstretchmode => 'all',
            -state          => 'disabled',
        )->pack( -fill => 'both' );
        $spreadsheet->rowHeight( 0, 2 );
        $spreadsheet->tagRow( 'title', 0 ) if ($table_title_rows);
        $spreadsheet->tagCol( 'title', 0 ) if ($table_title_cols);
        $spreadsheet->tagConfigure( 'title', -bd => 2, -relief => 'raised' );

        #$spreadsheet->colWidth(@col_width);

    }

    return;
}

# ----------------------------------------------------
sub move_map_popup {

=pod

=head2 move_map_popup

=cut

    my ( $self, %args ) = @_;
    my $map_key    = $args{'map_key'};
    my $window_key = $args{'window_key'};
    my $zinc       = $args{'zinc'};
    my $controller = $self->app_controller();

    my $move_map_data = $controller->app_display_data->get_move_map_data(
        map_key          => $map_key,
        highlight_bounds => $self->highlight_bounds(
            window_key => $window_key,
            object_key => $map_key,
        ),
    );
    return unless ( $move_map_data and %$move_map_data );

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
    $self->reset_object_selections(
        zinc       => $zinc,
        window_key => $window_key,
    );

    return;
}

# ----------------------------------------------------
sub move_map_subsection_popup {

=pod

=head2 move_map_subsection_popup

=cut

    my ( $self, %args ) = @_;
    my $map_key    = $args{'map_key'};
    my $window_key = $args{'window_key'};
    my $zinc       = $args{'zinc'};
    my $controller = $self->app_controller();
    my $mouse_x    = $args{'mouse_x'};
    my $mouse_y    = $args{'mouse_y'};

    my $move_map_data
        = $controller->app_display_data->get_move_subsection_data(
        map_key          => $map_key,
        mouse_x          => $mouse_x,
        mouse_y          => $mouse_y,
        highlight_bounds => $self->highlight_bounds(
            window_key => $window_key,
            object_key => $map_key,
        ),
        );
    return unless ( $move_map_data and %$move_map_data );

    my $new_parent_map_key = $move_map_data->{'new_parent_map_key'};
    my $gap_start          = $move_map_data->{'gap_start'};
    my $gap_stop           = $move_map_data->{'gap_stop'};
    my $text               = q{};
    if ( defined $gap_stop ) {
        $text = "Insert this map subsection at position " . $gap_stop . "?";
    }
    else {
        $text = "Insert this map subsection at position " . $gap_start . "?";
    }

    my $popup = $self->main_window()->Dialog(
        -title          => 'Move Map',
        -default_button => 'OK',
        -buttons        => [ 'OK', 'Cancel', ],
        -text           => $text,
    );
    my $answer = $popup->Show();

    if ( $answer eq 'OK' ) {
        $controller->app_display_data->move_map_subsection(
            subsection_map_key  => $map_key,
            destination_map_key => $new_parent_map_key,
            gap_start           => $gap_start,
            gap_stop            => $gap_stop,
        );
    }
    $self->reset_object_selections(
        zinc       => $zinc,
        window_key => $window_key,
    );

    return;
}

# ----------------------------------------------------
sub split_map_popup {

=pod

=head2 split_map_popup

=cut

    my ( $self, %args ) = @_;
    my $map_key    = $args{'map_key'};
    my $window_key = $args{'window_key'};
    my $zinc       = $args{'zinc'};
    my $mouse_x    = $args{'mouse_x'};
    my $controller = $self->app_controller();

    my $split_position = $controller->app_display_data->get_position_on_map(
        map_key => $map_key,
        mouse_x => $mouse_x,
    );

    my $popup = $self->main_window()->Dialog(
        -title          => 'Split Map',
        -default_button => 'OK',
        -buttons        => [ 'OK', 'Cancel', ],
    );
    $popup->add(
        'LabEntry',
        -textvariable => \$split_position,
        -width        => 10,
        -label        => 'Position',
        -labelPack    => [ -side => 'left' ],
    )->pack();
    my $answer = $popup->Show();

    if ( $answer eq 'OK' ) {
        my ( $selected_map_keys, $zone_key )
            = $controller->app_display_data->split_map(
            map_key        => $map_key,
            split_position => $split_position,
            );
        $self->reassign_object_selection(
            window_key => $window_key,
            zone_key   => $zone_key,
            map_keys   => $selected_map_keys,
        );
    }

    return;
}

# ----------------------------------------------------
sub merge_maps_popup {

=pod

=head2 merge_maps_popup

=cut

    my ( $self, %args ) = @_;
    my $map_key1 = $args{'map_key1'};
    my $map_key2 = $args{'map_key2'};

    # Keep the order consistent.
    if ( $map_key1 > $map_key2 ) {
        ( $map_key1, $map_key2 ) = ( $map_key2, $map_key1 );
    }
    my $window_key       = $args{'window_key'};
    my $zinc             = $args{'zinc'};
    my $overlap_amount   = $args{'overlap_amount'} || 0;
    my $order            = $args{'order'} || 0;
    my $app_display_data = $self->app_controller()->app_display_data();

    my $map_id1       = $app_display_data->map_key_to_id($map_key1);
    my $map_id2       = $app_display_data->map_key_to_id($map_key2);
    my $zone_key1     = $app_display_data->map_key_to_zone_key($map_key1);
    my $zone_key2     = $app_display_data->map_key_to_zone_key($map_key2);
    my @map_ids       = ( $map_id1, $map_id2 );
    my $map_data_hash = $app_display_data->app_data_module()
        ->map_data_hash( map_ids => \@map_ids, );
    unless ( $map_data_hash->{$map_id1}{'map_set_id'}
        == $map_data_hash->{$map_id2}{'map_set_id'} )
    {
        $self->popup_warning(
            text => "Cannot merge maps that are not in the same map set.", );
        return;
    }
    unless ( $zone_key1 == $zone_key2 ) {
        $self->popup_warning( text =>
                "This program does not allow merges between maps with different parents.  Please move one map first.",
        );
        return;
    }

    my $popup = $self->main_window()->Dialog(
        -title          => 'Merge Maps',
        -default_button => 'OK',
        -buttons        => [ 'OK', 'Cancel', ],
    );
    $popup->add(
        'LabEntry',
        -textvariable => \$overlap_amount,
        -width        => 10,
        -label        => 'Overlap',
        -labelPack    => [ -side => 'left' ],
    )->pack();
    $popup->add(
        'Radiobutton',
        -variable => \$order,
        -value    => 1,
        -text     => $map_data_hash->{$map_id1}{'map_name'} . "-"
            . $map_data_hash->{$map_id2}{'map_name'},
    )->pack();
    $popup->add(
        'Radiobutton',
        -variable => \$order,
        -value    => -1,
        -text     => $map_data_hash->{$map_id2}{'map_name'} . "-"
            . $map_data_hash->{$map_id1}{'map_name'},
    )->pack();
    my $answer = $popup->Show();

    if ( $answer eq 'OK' ) {
        if ( !$order ) {
            $self->popup_warning( text => "Please select an order of maps.",
            );
            return $self->merge_maps_popup(
                map_key1       => $map_key1,
                map_key2       => $map_key2,
                window_key     => $window_key,
                zinc           => $zinc,
                order          => $order,
                overlap_amount => $overlap_amount,
            );
        }
        elsif ( $order == -1 ) {
            ( $map_key1, $map_key2 ) = ( $map_key2, $map_key1 );
            ( $map_id1,  $map_id2 )  = ( $map_id2,  $map_id1 );
        }

        my ( $selected_map_keys, $zone_key ) = $app_display_data->merge_maps(
            overlap_amount => $overlap_amount,
            first_map_key  => $map_key1,
            second_map_key => $map_key2,
        );
        $self->reassign_object_selection(
            window_key => $window_key,
            zone_key   => $zone_key,
            map_keys   => $selected_map_keys,
        );
    }

    return 1;
}

# ----------------------------------------------------
sub password_box {

=pod

=head2 password_box


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
sub start_menu {

=pod

=head2 start_menu


=cut

    my ( $self, %args ) = @_;
    my $data_source = $args{'data_source'};
    my $remote_url  = $args{'remote_url'};

    my $start_window = $self->main_window()->Toplevel( -takefocus => 1 );
    $start_window->title('Start CMAE');

    my $button_items = [
        {   -text    => 'Open a Saved View',
            -command => sub {
                my $saved_view = $self->main_window()->getOpenFile();

                my $saved_view_data = $self->app_controller()
                    ->open_saved_view( saved_view => $saved_view, );

                return {
                    saved_view_data => $saved_view_data,
                    remote_url      => $saved_view_data->{'remote_url'},
                    data_source     => $saved_view_data->{'data_source'},
                };
            },
        },
        {   -text    => 'Browse a Data Source',
            -command => sub {
                if ($data_source) {
                    $self->app_controller->finish_init(
                        remote_url  => $remote_url,
                        data_source => $data_source,
                    );
                    $start_window->destroy();
                }
                else {
                    $self->select_data_source(
                        remote_url  => $remote_url,
                        data_source => $data_source,
                    );
                    $start_window->destroy();
                }
            },
            -button_handles_finishing => 1,
        },
    ];

    $self->app_controller()->plugin_set()
        ->modify_start_up_menu( button_items => $button_items, );

    push @$button_items, {
        -text    => 'Exit',
        -command => sub {
            exit;
        },
    };

    foreach my $button_item ( @{$button_items} ) {
        $start_window->Button(
            -text    => $button_item->{'-text'},
            -command => $button_item->{'-button_handles_finishing'}
            ? sub {
                &{  $button_item->{'-command'}
                        || sub { }
                    };
                }
            : sub {
                my $returned_data = &{
                    $button_item->{'-command'}
                        || sub { }
                    } || {};
                $self->app_controller->finish_init(
                    saved_view_data => $returned_data->{'saved_view_data'},
                    remote_url      => $returned_data->{'remote_url'},
                    data_source     => $returned_data->{'data_source'},
                );
                $start_window->destroy();
            },
        )->pack( -side => 'top', -anchor => 'nw' );
    }

    return;
}

# ----------------------------------------------------
sub select_data_source {

=pod

=head2 select_data_source


=cut

    my ( $self, %args ) = @_;
    my $remote_url  = $args{'remote_url'};
    my $data_source = $args{'data_source'};

    my $data_sources = $self->data_sources();

    my $data_source_window
        = $self->main_window()->Toplevel( -takefocus => 1 );
    $data_source_window->title('Select Data Source');

    foreach my $data_source_info ( @{ $data_sources || [] } ) {
        my $data_source_name = $data_source_info->{'name'};
        $data_source_window->Button(
            -text    => $data_source_name,
            -command => sub {
                $self->app_controller->finish_init(
                    remote_url  => $remote_url,
                    data_source => $data_source_name,
                );
                $data_source_window->destroy();
            },
        )->pack( -side => 'top', -anchor => 'nw' );
    }
    $data_source_window->Button(
        -text    => 'Exit',
        -command => sub {
            exit;
        },
    )->pack( -side => 'bottom', -anchor => 'nw' );

    return;
}

# ----------------------------------------------------
sub select_reference_maps {

=pod

=head2 select_reference_maps


=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'}
        or die 'no window key for new reference_maps';
    my $app_controller = $self->app_controller();

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
                $app_controller->load_new_window(
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
            $app_controller->close_window( window_key => $window_key, );
            $ref_selection_window->destroy();
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
    my $window_key  = $args{'window_key'};
    my $items       = $args{'items'} || return;
    my $is_overview = $args{'is_overview'};

    my $zinc
        = $is_overview
        ? $self->overview_zinc( window_key => $window_key, )
        : $self->zinc( window_key => $window_key, );

    map { $zinc->remove( $_->[1] ) } @$items;

    # Maybe clear the ties to a map or zone_bin

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
    $self->{'zinc'}{$window_key}->destroy();

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
    $zinc->raise( 'tmp_on_top', );
    $zinc->lower( 'on_bottom', );

    return;
}

=pod

=head1 Drag and Drop Methods

head2 Type Left

=over 4 

=item Highlight map

=item Eventually draw select box

=back

head2 Type Right

=over 4 

=item Drag around window

=item Move maps

=item Bring up map menu

=back

=cut

# ----------------------------------------------------
sub start_drag_left_mouse {

=pod

=head2 start_drag_left_mouse

Handle down click of the left mouse button

=cut

    my $self = shift;
    my ( $zinc, $x, $y, $control, ) = @_;

    my $window_key = $self->{'drag_window_key'}
        = $self->get_window_key_from_zinc( zinc => $zinc, );

    unless ($control) {
        $self->reset_object_selections(
            zinc       => $zinc,
            window_key => $window_key,
        );
    }
    $self->{'drag_last_x'} = $x;
    $self->{'drag_last_y'} = $y;
    $self->{'drag_ori_id'} = $zinc->find( 'withtag', 'current' );
    if ( ref( $self->{'drag_ori_id'} ) eq 'ARRAY' ) {
        $self->{'drag_ori_id'} = $self->{'drag_ori_id'}[0];
    }
    return unless ( $self->{'drag_ori_id'} );

    # If this object is a highlight, modify so the code uses the original id
    if ( $self->{'highlight_id_to_ori_id'}{$window_key}
        { $self->{'drag_ori_id'} } )
    {
        $self->{'drag_ori_id'}
            = $self->{'highlight_id_to_ori_id'}{$window_key}
            { $self->{'drag_ori_id'} };
    }

    my @tags;
    my @tags_gotten = $zinc->gettags( $self->{'drag_ori_id'} );
    if ( @tags = grep /^map_/, @tags_gotten ) {
        $tags[0] =~ /^map_(\S+)_(\S+)_(\S+)/;
        $self->{'drag_zone_key'} = $2;
        my $map_key = $3;

        my $object_selected_type
            = $self->object_selected_type( window_key => $window_key );

        # User is trying to combine features and maps.  We can't have that.
        if (    $control
            and $object_selected_type
            and $object_selected_type ne 'map' )
        {
            return;
        }
        $self->{'drag_obj'} = 'map';

        my $object_selected = $self->object_selected(
            window_key => $window_key,
            map_key    => $map_key,
        );

        # If it was previously highlighted, remove it
        if ($object_selected) {
            $self->remove_object_selection(
                zinc       => $zinc,
                object_key => $map_key,
                window_key => $window_key,
            );
        }
        else {

            # Add to the object_selection list
            $self->add_object_selection(
                zinc       => $zinc,
                zone_key   => $self->{'drag_zone_key'},
                map_key    => $map_key,
                window_key => $window_key,
            );
        }

        $self->fill_info_box( window_key => $window_key, );
    }
    elsif ( @tags = grep /^bin_maps_/, @tags_gotten ) {
        $tags[0] =~ /^bin_maps_(\S+)_(\S+)_(\S+)/;
        my $zone_key  = $2;
        my $bin_index = $3;

        my $object_selected_type
            = $self->object_selected_type( window_key => $window_key );

        # User is trying to combine features and maps.  We can't have that.
        if (    $control
            and $object_selected_type
            and $object_selected_type ne 'map' )
        {
            return;
        }

        my $app_display_data = $self->app_controller()->app_display_data();
        my $bin_layout
            = $app_display_data->get_zone_bin_layouts( $zone_key, $bin_index,
            );

        my $bin_key = $app_display_data->create_bin_key(
            bin_index => $bin_index,
            zone_key  => $zone_key,
        );
        my $object_selected = $self->object_selected(
            window_key => $window_key,
            bin_key    => $bin_key,
        );

        # If it was previously highlighted, remove it
        if ($object_selected) {
            $self->remove_object_selection(
                zinc       => $zinc,
                object_key => $bin_key,
                window_key => $window_key,
            );
        }
        else {

            # Add each to the object_selection list
            $self->add_object_selection(
                zinc       => $zinc,
                zone_key   => $zone_key,
                bin_key    => $bin_key,
                window_key => $window_key,
            );
        }

        $self->fill_info_box( window_key => $window_key, );
    }
    elsif ( @tags = grep /^feature_/, @tags_gotten ) {
        $tags[0] =~ /^feature_(\d+?)_(\d+?)_(\S+)/;
        $self->{'drag_zone_key'}    = $1;
        $self->{'drag_map_key'}     = $2;
        $self->{'drag_feature_acc'} = $3;

        my $feature_acc
            = $self->drawn_id_to_feature_acc( $self->{'drag_ori_id'} )
            or return;

        my $object_selected_type
            = $self->object_selected_type( window_key => $window_key );

        # User is trying to combine features and maps.  We can't have that.
        if (    $control
            and $object_selected_type
            and $object_selected_type ne 'feature' )
        {
            return;
        }
        $self->{'drag_obj'} = 'feature';

        my $object_selected = $self->object_selected(
            window_key  => $window_key,
            feature_acc => $feature_acc,
        );

        # If it was previously highlighted, remove it
        if ($object_selected) {
            $self->remove_object_selection(
                zinc       => $zinc,
                object_key => $feature_acc,
                window_key => $window_key,
            );
            $self->fill_info_box( window_key => $window_key, );
        }
        else {

            # Add to the object_selection list
            $self->add_object_selection(
                zinc        => $zinc,
                zone_key    => $self->{'drag_zone_key'},
                feature_acc => $feature_acc,
                window_key  => $window_key,
            );
        }

        $self->fill_info_box( window_key => $window_key, );
    }
    elsif ( @tags = grep /^location_bar_/, @tags_gotten ) {
        unless ($control) {
            $self->reset_object_selections(
                zinc       => $zinc,
                window_key => $window_key,
            );
        }
        $tags[0] =~ /^location_bar_(\S+)_(\S+)/;
        $self->{'drag_zone_key'} = $2;
        $self->{'drag_obj'}      = 'location_bar';

        #$self->app_controller()->hide_corrs(
        #    window_key => $self->{'drag_window_key'},
        #    zone_key   => $self->{'drag_zone_key'},
        #);
    }
    elsif ( @tags = grep /^background_/, @tags_gotten ) {
        $tags[0] =~ /^background_(\S+)_(\S+)/;
        $self->{'drag_zone_key'} = $2;
        $self->{'drag_obj'}      = 'background';
    }
    elsif ( @tags = grep /^button_/, @tags_gotten ) {
        my $controller       = $self->app_controller();
        my $app_display_data = $controller->app_display_data();
        if ( $tags[0] =~ /^button_display_features_(\S+)_(\S+)/ ) {
            $self->{'drag_zone_key'} = $2;
            $self->{'drag_obj'}      = 'button';
            my $toggled_features_visible
                = $app_display_data->features_visible(
                $self->{'drag_zone_key'} ) ? 0 : 1;
            $app_display_data->set_features_visibility(
                $self->{'drag_zone_key'},
                $toggled_features_visible, );
        }
        elsif ( $tags[0] =~ /^button_display_labels_(\S+)_(\S+)/ ) {
            $self->{'drag_zone_key'} = $2;
            $self->{'drag_obj'}      = 'button';
            my $toggled_label_visibility
                = $app_display_data->map_labels_visible(
                $self->{'drag_zone_key'} ) ? 0 : 1;
            $app_display_data->set_map_labels_visibility(
                $self->{'drag_zone_key'},
                $toggled_label_visibility, );
        }
        elsif ( $tags[0] =~ /^button_display_corrs(\S+)_(\S+)/ ) {
            $self->{'drag_zone_key'} = $2;
            $self->{'drag_obj'}      = 'button';
            $self->popup_corr_menu(
                window_key => $window_key,
                zone_key   => $self->{'drag_zone_key'},
            );
        }
        elsif ( $tags[0] =~ /^button_popup_menu_(\S+)_(\S+)/ ) {
            $self->{'drag_window_key'} = $1;
            $self->{'drag_zone_key'}   = $2;
            $self->{'drag_obj'}        = 'button';
            $self->popup_background_menu(
                zinc       => $zinc,
                window_key => $self->{'drag_window_key'},
                zone_key   => $self->{'drag_zone_key'},
                mouse_x    => $x,
                mouse_y    => $y,
            );
        }
    }

    # BF ADD THIS BACK LATER
    #    elsif ( @tags = grep /^viewed_region_/,
    #        @tags_gotten )
    #    {
    #        $tags[0] =~ /^viewed_region_(\S+)_(\S+)/;
    #        $self->{'drag_zone_key'}   = $2;
    #    }
    #
    if ( $self->{'drag_zone_key'} ) {
        $self->app_controller()
            ->new_selected_zone( zone_key => $self->{'drag_zone_key'}, );
    }

}

# ----------------------------------------------------
sub start_drag_right_mouse {

=pod

=head2 start_drag_right_mouse

Handle down click of the right mouse button

=cut

    my $self = shift;
    my ( $zinc, $x, $y, $control, ) = @_;

    my $window_key = $self->{'drag_window_key'}
        = $self->get_window_key_from_zinc( zinc => $zinc, );

    $self->{'draggable'}   = 0;
    $self->{'drag_last_x'} = $x;
    $self->{'drag_last_y'} = $y;
    $self->{'drag_ori_x'}  = $x;
    $self->{'drag_ori_y'}  = $y;
    $self->{'drag_ori_id'} = $zinc->find( 'withtag', 'current' );
    if ( ref( $self->{'drag_ori_id'} ) eq 'ARRAY' ) {
        $self->{'drag_ori_id'} = $self->{'drag_ori_id'}[0];
    }
    return unless ( $self->{'drag_ori_id'} );

    # If this object is a highlight, modify so the code uses the original id
    if ( $self->{'highlight_id_to_ori_id'}{$window_key}
        { $self->{'drag_ori_id'} } )
    {
        $self->{'drag_ori_id'}
            = $self->{'highlight_id_to_ori_id'}{$window_key}
            { $self->{'drag_ori_id'} };
    }

    my @tags;
    my @tags_gotten = $zinc->gettags( $self->{'drag_ori_id'} );
    if ( @tags = grep /^map_/, @tags_gotten ) {
        $tags[0] =~ /^map_(\S+)_(\S+)_(\S+)/;
        $self->{'drag_zone_key'} = $2;
        $self->{'drag_map_key'}  = $3;
        $self->{'drag_obj'}      = 'map';

        my $map_key = $self->{'drag_map_key'};

        my $object_selected_type
            = $self->object_selected_type( window_key => $window_key );

       # User is trying to combine features and maps.  We can't have that.  If
       # control is not pressed, wipe the selections and keep going.
        if (    $object_selected_type
            and $object_selected_type ne 'map' )
        {
            if ($control) {
                return;
            }
            else {
                $self->reset_object_selections(
                    zinc       => $zinc,
                    window_key => $window_key,
                );
            }
        }

        my $object_selected = $self->object_selected(
            window_key => $window_key,
            map_key    => $map_key,
        );

        # Clicking on a new map w/out control
        # Reset the selections
        if ( !$control and !$object_selected ) {
            $self->reset_object_selections(
                zinc       => $zinc,
                window_key => $window_key,
            );
        }

        # Add to the object_selection list if it isn't already selected
        if ( !$object_selected ) {
            $self->add_object_selection(
                zinc       => $zinc,
                zone_key   => $self->{'drag_zone_key'},
                map_key    => $map_key,
                window_key => $window_key,
            );
        }

        # Only allow dragging the map if a single map is selected
        if ( $self->number_of_object_selections( $window_key, ) == 1 ) {
            $self->{'draggable'} = 1;
        }

        $self->fill_info_box( window_key => $window_key, );

        my $highlight_bounds = $self->highlight_bounds(
            window_key => $window_key,
            object_key => $map_key,
        );
        $self->{'drag_mouse_to_edge_x'} = $x - $highlight_bounds->[0];
    }
    elsif ( @tags = grep /^feature_/, @tags_gotten ) {
        $tags[0] =~ /^feature_(\d+?)_(\d+?)_(\S+)/;
        $self->{'drag_zone_key'}    = $1;
        $self->{'drag_map_key'}     = $2;
        $self->{'drag_feature_acc'} = $3;

        my $feature_acc
            = $self->drawn_id_to_feature_acc( $self->{'drag_ori_id'} )
            or return;

        my $object_selected_type
            = $self->object_selected_type( window_key => $window_key );

        # User is trying to combine features and maps.  We can't have that.
        if (    $control
            and $object_selected_type
            and $object_selected_type ne 'feature' )
        {
            return;
        }
        $self->{'drag_obj'} = 'feature';

        my $object_selected = $self->object_selected(
            window_key  => $window_key,
            feature_acc => $feature_acc,
        );

        # If it was previously highlighted, remove it
        if ($object_selected) {
            $self->remove_object_selection(
                zinc       => $zinc,
                object_key => $feature_acc,
                window_key => $window_key,
            );
            $self->fill_info_box( window_key => $window_key, );
        }
        else {

            # Add to the object_selection list
            $self->add_object_selection(
                zinc        => $zinc,
                zone_key    => $self->{'drag_zone_key'},
                feature_acc => $feature_acc,
                window_key  => $window_key,
            );
        }

        $self->fill_info_box( window_key => $window_key, );
    }
    elsif ( @tags = grep /^location_bar_/, @tags_gotten ) {
        unless ($control) {
            $self->reset_object_selections(
                zinc       => $zinc,
                window_key => $window_key,
            );
        }
        $tags[0] =~ /^location_bar_(\S+)_(\S+)/;
        $self->{'drag_zone_key'} = $2;
        $self->{'drag_obj'}      = 'location_bar';

        #$self->app_controller()->hide_corrs(
        #    window_key => $self->{'drag_window_key'},
        #    zone_key   => $self->{'drag_zone_key'},
        #);
    }
    elsif ( @tags = grep /^background_/, @tags_gotten ) {
        unless ($control) {
            $self->reset_object_selections(
                zinc       => $zinc,
                window_key => $window_key,
            );
        }
        $tags[0] =~ /^background_(\S+)_(\S+)/;
        $self->{'drag_zone_key'} = $2;
        $self->{'drag_obj'}      = 'background';

        #$self->app_controller()->hide_corrs(
        #    window_key => $self->{'drag_window_key'},
        #    zone_key   => $self->{'drag_zone_key'},
        #);
    }
    else {
        unless ($control) {
            $self->reset_object_selections(
                zinc       => $zinc,
                window_key => $window_key,
            );
        }
    }

    # BF ADD THIS BACK LATER
    #    elsif ( @tags = grep /^viewed_region_/,
    #        @tags_gotten )
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

}

# ----------------------------------------------------
sub drag_left_mouse {

=pod

=head2 drag_left_mouse

Handle the drag event

Stubbed out, not currently used.

=cut

    my $self = shift;
    my ( $zinc, $x, $y, ) = @_;
    return unless ( $self->{'drag_ori_id'} );
    my $dx = $x - $self->{'drag_last_x'};
    my $dy = $y - $self->{'drag_last_y'};

    if ( $self->{'drag_obj'} eq 'location_bar' ) {
        $self->app_controller()->app_display_data->location_bar_drag(
            window_key => $self->{'drag_window_key'},
            zone_key   => $self->{'drag_zone_key'},
            drag_value => $dx,
        );
    }

    $self->{drag_last_x} = $x;
    $self->{drag_last_y} = $y;

}

# ----------------------------------------------------
sub drag_right_mouse {

=pod

=head2 drag_right_mouse

Handle the drag event

=cut

    my $self = shift;
    my ( $zinc, $x, $y, ) = @_;
    return unless ( $self->{'drag_ori_id'} );
    my $dx = $x - $self->{'drag_last_x'};
    my $dy = $y - $self->{'drag_last_y'};

    if ( $self->{'drag_obj'} ) {
        if ( $self->{'drag_obj'} eq 'map' ) {
            unless ( $self->{'draggable'} ) {
                return;
            }

            $self->{'highlight_map_moved'}{ $self->{'drag_window_key'} } = 1;
            my $map_key = $self->{'drag_map_key'};
            my $map_id  = $self->app_controller()->app_display_data()
                ->map_key_to_id($map_key);
            my $map_data
                = $self->app_data_module()->map_data( map_id => $map_id, );
            my $map_type_acc = $map_data->{'map_type_acc'};
            if ( $self->map_type_data( $map_type_acc, 'subsection' ) ) {
                $self->drag_subsection_highlight(
                    zinc => $zinc,
                    x    => $x,
                    y    => $y,
                    dx   => $dx,
                    dy   => $dy,
                );
            }
            else {
                $self->drag_highlight(
                    zinc => $zinc,
                    x    => $x,
                    y    => $y,
                    dx   => $dx,
                    dy   => $dy,
                );
            }
        }
        elsif ( $self->{'drag_obj'} eq 'location_bar' ) {
            $self->app_controller()->app_display_data->location_bar_drag(
                window_key => $self->{'drag_window_key'},
                zone_key   => $self->{'drag_zone_key'},
                drag_value => $dx,
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
sub stop_drag_left_mouse {

=pod

=head2 stop_drag_left_mouse

Handle the stopping drag event

Stubbed out, Not currently used.

=cut

    my $self = shift;
    my ( $zinc, $x, $y, ) = @_;

    return unless ( $self->{'drag_ori_id'} );

    # Move original object
    if ( $self->{'drag_obj'} ) {
        $self->app_controller()->app_display_data()->end_drag_highlight();
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

}

# ----------------------------------------------------
sub stop_drag_right_mouse {

=pod

=head2 stop_drag_right_mouse

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
                zinc  => $zinc,
                moved => $self->{'highlight_map_moved'}
                    { $self->{'drag_window_key'} },
                map_key => $map_key,
                mouse_x => $x,
                mouse_y => $y,
            );
        }
        elsif ( $self->{'drag_obj'} eq 'feature' ) {
            $self->{'drag_feature_acc'} = $3;
            my $feature_acc = $self->{'drag_feature_acc'};

            $self->popup_feature_menu(
                zinc  => $zinc,
                moved => $self->{'highlight_map_moved'}
                    { $self->{'drag_window_key'} },
                feature_acc => $feature_acc,
                mouse_x     => $x,
                mouse_y     => $y,
            );
        }
        elsif ($self->{'drag_obj'} eq 'background'
            or $self->{'drag_obj'} eq 'viewed_region' )
        {
            if ( $self->{'drag_ori_x'} == $x and $self->{'drag_ori_y'} == $y )
            {
                $self->popup_background_menu(
                    zinc       => $zinc,
                    window_key => $self->{'drag_window_key'},
                    zone_key   => $self->{'drag_zone_key'},
                    mouse_x    => $x,
                    mouse_y    => $y,
                );
            }

            #$self->app_controller()->unhide_corrs(
            #    window_key => $self->{'drag_window_key'},
            #    zone_key   => $self->{'drag_zone_key'},
            #);
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

}

# ----------------------------------------------------
sub reassign_object_selection {

=pod

=head2 reassign_object_selection

Reset old selections and add map or feature selections when given a list of map keys or feature accessions.

This can be used by other modules but probably shouldn't be.

    $app_interface->reassign_object_selection(
        window_key => $window_key,
        zone_key   => $zone_key,
        map_keys   => $map_keys,
    );

    or

    $app_interface->reassign_object_selection(
        window_key   => $window_key,
        zone_key     => $zone_key,
        feature_accs => $feature_accs,
    );

=cut

    my ( $self, %args ) = @_;
    my $window_key   = $args{'window_key'};
    my $map_keys     = $args{'map_keys'} || [];
    my $feature_accs = $args{'feature_accs'} || [];
    my $zone_key     = $args{'zone_key'};

    my $zinc = $self->zinc( window_key => $window_key, );

    $self->reset_object_selections(
        zinc       => $zinc,
        window_key => $window_key,
    );
    if (@$map_keys) {
        foreach my $map_key (@$map_keys) {
            $self->add_object_selection(
                zinc       => $zinc,
                zone_key   => $zone_key,
                map_key    => $map_key,
                window_key => $window_key,
            );
        }
    }
    elsif (@$feature_accs) {
        foreach my $feature_acc (@$feature_accs) {
            $self->add_object_selection(
                zinc        => $zinc,
                zone_key    => $zone_key,
                feature_acc => $feature_acc,
                window_key  => $window_key,
            );
        }
    }

    $self->fill_info_box( window_key => $window_key, );

    $self->layer_tagged_items( zinc => $zinc, );

    return;
}

# ----------------------------------------------------
sub add_object_selection {

=pod

=head2 add_object_selection

Add map or feature selection

=cut

    my ( $self, %args ) = @_;
    my $zinc        = $args{'zinc'};
    my $map_key     = $args{'map_key'};
    my $feature_acc = $args{'feature_acc'};
    my $bin_key     = $args{'bin_key'};
    my $zone_key    = $args{'zone_key'};
    my $window_key  = $args{'window_key'};

    my $bin_index;
    if ( $bin_key and $bin_key =~ /^bin_(\d+)_(\d+)/ ) {
        $bin_index = $2;
    }

    my $object_key = $map_key || $feature_acc || $bin_key;
    my $object_type = $feature_acc ? 'feature' : 'map';

    my $selected_type
        = $self->object_selected_type( window_key => $window_key, );

    # Return if the object is already selected or if the object is a new type.
    if (( $selected_type and $selected_type ne $object_type )
        or $self->object_selected(
            window_key => $window_key,
            object_key => $object_key,
        )
        )
    {
        return;
    }

    # Set object type
    $self->object_selected_type(
        window_key => $window_key,
        value      => $object_type,
    );

    # Add to object_selected list
    $self->{'object_selections'}{$window_key}{$object_key} = {
        zone_key    => $zone_key,
        map_key     => $map_key || '',
        feature_acc => $feature_acc || '',
        bin_key     => $bin_key || '',

    };
    $self->{'object_selections'}{$window_key}{$object_key}{$zone_key}
        = $zone_key;

    # figure out if this is a new zone.
    if ( $self->{'first_object_selection_zone_key'}{$window_key} ) {
        unless ( $zone_key
            == $self->{'first_object_selection_zone_key'}{$window_key} )
        {
            $self->{'object_selections_in_same_zone'}{$window_key} = 0;
        }
    }
    else {
        $self->{'first_object_selection_zone_key'}{$window_key} = $zone_key;
        $self->{'object_selections_in_same_zone'}{$window_key}  = 1;
    }

    # Create a highlight item for each item in the original feature glyph
    my @ori_ids;
    if ($bin_key) {
        @ori_ids = $self->zone_bin_to_drawn_ids( $zone_key, $bin_index, );
    }
    elsif ($map_key) {
        @ori_ids = $self->map_key_to_drawn_ids($map_key);
    }
    elsif ($feature_acc) {
        @ori_ids = $self->feature_acc_to_drawn_ids($feature_acc);
    }
    else {
        return;
    }
    (   $self->{'object_selections'}{$window_key}{$object_key}
            {'highlight_bounds'},
        $self->{'object_selections'}{$window_key}{$object_key}
            {'highlight_ids'}
        )
        = $self->highlight_object(
        zinc       => $zinc,
        ori_ids    => \@ori_ids,
        zone_key   => $zone_key,
        window_key => $window_key,
        );

    return
        unless (
        @{  $self->{'object_selections'}{$window_key}{$object_key}
                {'highlight_ids'} || []
        }
        );
    if ($map_key) {
        $self->{'object_selections'}{$window_key}{$object_key}
            {'highlight_loc'} = $self->create_highlight_location_on_map(
            zinc       => $zinc,
            map_key    => $map_key,
            window_key => $self->{'drag_window_key'},
            highlight_bounds =>
                $self->{'object_selections'}{$window_key}{$object_key}
                {'highlight_bounds'},
            );
        $self->highlight_map_corrs(
            zinc       => $zinc,
            map_key    => $map_key,
            color      => 'black',
            zone_key   => $zone_key,
            window_key => $window_key,
        );
    }

    return;
}

# ----------------------------------------------------
sub object_selected_type {

=pod

=head2 object_selected_type

Get/Set the object selected type

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $value      = $args{'value'};

    if ($value) {
        $self->{'object_selected_type'}{$window_key} = $value;
    }
    return $self->{'object_selected_type'}{$window_key};
}

# ----------------------------------------------------
sub object_selected {

=pod

=head2 object_selected

Test if a map or feautre is selected

=cut

    my ( $self, %args ) = @_;
    my $map_key     = $args{'map_key'};
    my $object_key  = $args{'object_key'};
    my $feature_acc = $args{'feature_acc'};
    my $bin_key     = $args{'bin_key'};
    my $window_key  = $args{'window_key'};

    $object_key = $object_key || $map_key || $feature_acc || $bin_key;
    my $object_type = $feature_acc ? 'feature' : 'map';

    # Return if the object is already selected or if the object is a new type.
    my $selected_type
        = $self->object_selected_type( window_key => $window_key, );
    if (( $map_key or $feature_acc or $bin_key )
        and ( !$selected_type
            or $selected_type ne $object_type )
        )
    {
        return 0;
    }
    elsif ( $self->{'object_selections'}{$window_key}{$object_key} ) {
        return 1;
    }
    return 0;
}

# ----------------------------------------------------
sub object_selection_keys {

=pod

=head2 object_selection_keys

Returns a list of the object selection keys

=cut

    my $self       = shift;
    my $window_key = shift;

    return keys %{ $self->{'object_selections'}{$window_key} || {} };
}

# ----------------------------------------------------
sub number_of_object_selections {

=pod

=head2 number_of_object_selections

Test if a map or feautre is selected

=cut

    my $self       = shift;
    my $window_key = shift;
    my $count      = 0;
    foreach my $object_key (
        keys %{ $self->{'object_selections'}{$window_key} || {} } )
    {
        if ( $object_key =~ /^bin_(\d+)_(\d+)/ ) {
            my $zone_key   = $1;
            my $bin_index  = $2;
            my $bin_layout = $self->app_controller()->app_display_data()
                ->get_zone_bin_layouts( $zone_key, $bin_index );
            $count += scalar @{ $bin_layout->{'map_keys'} || [] };
        }
        else {
            $count++;
        }
    }

    return $count;
}

# ----------------------------------------------------
sub remove_object_selection {

=pod

=head2 remove_object_selection

Remove selected object from the selection list

=cut

    my ( $self, %args ) = @_;
    my $object_key = $args{'object_key'};
    my $zinc       = $args{'zinc'};
    my $window_key = $args{'window_key'};

    my $selection_info;
    unless ( $selection_info
        = $self->{'object_selections'}{$window_key}{$object_key} )
    {
        return;
    }

    foreach my $highlight_id ( @{ $selection_info->{'highlight_ids'} || [] } )
    {
        $zinc->remove($highlight_id);
    }

    foreach my $highlight_loc_id (
        @{ $selection_info->{'highlight_loc'}{'highlight_loc_ids'} || [] } )
    {
        $zinc->remove($highlight_loc_id);
    }

    delete $self->{'object_selections'}{$window_key}{$object_key};
    $self->{'first_object_selection_zone_key'}{$window_key} = undef;
    $self->{'object_selections_in_same_zone'}{$window_key}  = undef;

    # If there are no more selections, return things to normal.
    unless ( keys %{ $self->{'object_selections'}{$window_key} || {} } ) {
        $self->{'highlight_map_moved'}{$window_key}  = undef;
        $self->{'object_selected_type'}{$window_key} = undef;
    }

    # If a subsection move was started, remove the location marker
    if ( $selection_info->{'subsection_highlight_loc'} ) {
        foreach my $subsection_location_id (
            @{  $selection_info->{'subsection_highlight_loc'}
                    {'subsection_loc_ids'} || []
            }
            )
        {
            $zinc->remove($subsection_location_id);
        }
        $self->{'subsection_highlight_loc'} = undef;
    }

    return;
}

# ----------------------------------------------------
sub reset_object_selections {

=pod

=head2 reset_object_selections

Remove all selected objects from the selection list

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $zinc = $args{'zinc'} || $self->zinc( window_key => $window_key, );

    my $selected_type
        = $self->object_selected_type( window_key => $window_key, );

    foreach my $object_key (
        keys %{ $self->{'object_selections'}{$window_key} || {} } )
    {
        $self->remove_object_selection(
            zinc       => $zinc,
            object_key => $object_key,
            window_key => $window_key,
        );
        if ( $selected_type eq 'map' ) {

            # Unhighlight the correspondences for the map
            $self->unhighlight_map_corrs(
                zinc    => $zinc,
                map_key => $object_key,
            );
        }
    }

    return;
}

# ----------------------------------------------------
sub reselect_object_selections {

=pod

=head2 reselect_object_selections



=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $zinc = $args{'zinc'} || $self->zinc( window_key => $window_key, );

    my $selected_type
        = $self->object_selected_type( window_key => $window_key, );

    return unless ($selected_type);
    my @selected_objects;
    foreach my $object_key (
        keys %{ $self->{'object_selections'}{$window_key} || {} } )
    {
        my $selected_data
            = $self->{'object_selections'}{$window_key}{$object_key};
        push @selected_objects,
            {
            zone_key    => $selected_data->{'zone_key'},
            map_key     => $selected_data->{'map_key'},
            feature_acc => $selected_data->{'feature_acc'},
            bin_key     => $selected_data->{'bin_key'},
            };
    }

    $self->reset_object_selections( window_key => $window_key, );
    foreach my $selected_object_data (@selected_objects) {
        $self->add_object_selection(
            zinc       => $zinc,
            window_key => $window_key,
            %{ $selected_object_data || {} },
        );
    }

    return;
}

# ----------------------------------------------------
sub create_subsection_location_on_map {

=pod

=head2 create_subsection_location_on_map

Create the subsection line on the parent map

=cut

    my ( $self, %args ) = @_;
    my $zinc             = $args{'zinc'};
    my $map_key          = $args{'map_key'};
    my $window_key       = $args{'window_key'};
    my $highlight_bounds = $args{'highlight_bounds'};
    my $mouse_x          = $args{'mouse_x'};
    my $mouse_y          = $args{'mouse_y'};

    my $subsection_color = 'purple';

    my %subsection_location_data
        = $self->app_controller()->app_display_data()
        ->place_subsection_location_on_parent_map(
        map_key  => $map_key,
        initiate => 1,
        mouse_x  => $mouse_x,
        mouse_y  => $mouse_y,
        );

    return unless (%subsection_location_data);

    my $parent_group_id = $self->get_zone_group_id(
        window_key       => $subsection_location_data{'window_key'},
        zone_key         => $subsection_location_data{'parent_zone_key'},
        zinc             => $zinc,
        app_display_data => $self->app_controller()->app_display_data(),
    );

    my @subsection_loc_ids;
    my $subsection_loc_id;
    my $coords = [
        $subsection_location_data{'location_coords'}->[0] - 4,
        $subsection_location_data{'location_coords'}->[1] - 6,
        $subsection_location_data{'location_coords'}->[2] + 4,
        $subsection_location_data{'location_coords'}->[3] + 6,
    ];
    $subsection_loc_id = $zinc->add(
        'rectangle',
        $parent_group_id,
        $coords,
        -linecolor => $subsection_color,
        -linewidth => 2,
        -filled    => 0,
        -visible   => $subsection_location_data{'visible'},

    );
    push @subsection_loc_ids, $subsection_loc_id;
    $zinc->addtag( 'tmp_on_top', 'withtag', $subsection_loc_id );

    return {
        subsection_loc_ids => \@subsection_loc_ids,
        location_coords    => $subsection_location_data{'location_coords'},
        parent_zone_key    => $subsection_location_data{'parent_zone_key'},
    };
}

# ----------------------------------------------------
sub create_highlight_location_on_map {

=pod

=head2 create_highlight_location_on_map

Create the highlight box on the parent map

=cut

    my ( $self, %args ) = @_;
    my $zinc             = $args{'zinc'};
    my $map_key          = $args{'map_key'};
    my $window_key       = $args{'window_key'};
    my $highlight_bounds = $args{'highlight_bounds'};

    my $highlight_color = 'red';

    my %highlight_location_data
        = $self->app_controller()->app_display_data()
        ->place_highlight_location_on_parent_map(
        map_key          => $map_key,
        highlight_bounds => $highlight_bounds,
        initiate         => 1,
        );

    return unless (%highlight_location_data);

    my $parent_group_id = $self->get_zone_group_id(
        window_key       => $highlight_location_data{'window_key'},
        zone_key         => $highlight_location_data{'parent_zone_key'},
        zinc             => $zinc,
        app_display_data => $self->app_controller()->app_display_data(),
    );

    my @highlight_loc_ids;
    push @highlight_loc_ids, $zinc->add(
        'rectangle',
        $parent_group_id,
        $highlight_location_data{'location_coords'},
        -linecolor => $highlight_color,
        -linewidth => 2,
        -filled    => 0,
        -visible   => $highlight_location_data{'visible'},

    );
    $zinc->addtag( 'tmp_on_top', 'withtag', $highlight_loc_ids[0] );

    return {
        highlight_loc_ids => \@highlight_loc_ids,
        parent_zone_key   => $highlight_location_data{'parent_zone_key'}
    };
}

# ----------------------------------------------------
sub highlight_object {

=pod

=head2 highlight_object

Draw a highlight over the object

=cut

    my ( $self, %args ) = @_;
    my $zinc            = $args{'zinc'};
    my $zone_key        = $args{'zone_key'};
    my $window_key      = $args{'window_key'};
    my $ori_ids         = $args{'ori_ids'} || [];
    my $highlight_color = $args{'color'} || 'red';

    my $app_display_data = $self->app_controller()->app_display_data();
    my $highlight_bounds = [];
    my @highlight_ids    = ();

    my ( $main_x_offset, $main_y_offset )
        = $app_display_data->get_main_zone_offsets( zone_key => $zone_key, );

    my $top_layer_group_id = $self->get_zone_group_id(
        window_key => $window_key,
        zone_key   => TOP_LAYER_ZONE_KEY,
        zinc       => $zinc,
    );

    foreach my $ori_id (@$ori_ids) {
        my $type = $zinc->type($ori_id);
        next if ( $type eq 'text' );
        my $highlight_id = $zinc->clone(
            $ori_id,
            -tags => [
                'tmp_on_top', grep {/feature_|map_/} $zinc->gettags($ori_id),
            ],
        );
        $self->{'highlight_id_to_ori_id'}{$window_key}{$highlight_id}
            = $ori_id;

        push @highlight_ids, $highlight_id;

        # Make highlight a different color.
        $zinc->itemconfigure(
             $highlight_id,
            -linecolor => $highlight_color,
            -fillcolor => $highlight_color,
        );
        $zinc->chggroup( $highlight_id, $top_layer_group_id, 1, );

        # modify the coords to be universial because chggroup won't.
        my @coords = $zinc->coords($highlight_id);

        # Flatten the coords array
        @coords = map { ( ref($_) eq 'ARRAY' ) ? @$_ : $_ } @coords;

        # The highlight bounds are now in the universal coordinate system
        # $coords[0] += $main_x_offset;
        # $coords[1] += $main_y_offset;
        # $coords[2] += $main_x_offset;
        # $coords[3] += $main_y_offset;
        $highlight_bounds
            = $self->expand_bounds( $highlight_bounds, \@coords );
    }

    return ( $highlight_bounds, \@highlight_ids );
}

# ----------------------------------------------------
sub highlight_loc {

=pod

=head2 highlight_loc

Access the highlight location object.

=cut

    my ( $self, %args ) = @_;
    my $object_key = $args{'object_key'};
    my $window_key = $args{'window_key'};

    return $self->{'object_selections'}{$window_key}{$object_key}
        {'highlight_loc'};
}

# ----------------------------------------------------
sub subsection_highlight_loc {

=pod

=head2 highlight_loc

Access the highlight location object.

=cut

    my ( $self, %args ) = @_;
    my $object_key = $args{'object_key'};
    my $window_key = $args{'window_key'};

    return $self->{'object_selections'}{$window_key}{$object_key}
        {'subsection_highlight_loc'};
}

# ----------------------------------------------------
sub highlight_bounds {

=pod

=head2 highlight_bounds

Access the highlight bounds.

Also, move the bounds if given a dx or dy

=cut

    my ( $self, %args ) = @_;
    my $object_key = $args{'object_key'};
    my $window_key = $args{'window_key'};
    my $dx         = $args{'dx'};
    my $dy         = $args{'dy'};

    if ($dx) {
        $self->{'object_selections'}{$window_key}{$object_key}
            {'highlight_bounds'}[0] += $dx;
        $self->{'object_selections'}{$window_key}{$object_key}
            {'highlight_bounds'}[2] += $dx;
    }
    if ($dy) {
        $self->{'object_selections'}{$window_key}{$object_key}
            {'highlight_bounds'}[1] += $dy;
        $self->{'object_selections'}{$window_key}{$object_key}
            {'highlight_bounds'}[3] += $dy;
    }

    return $self->{'object_selections'}{$window_key}{$object_key}
        {'highlight_bounds'};
}

# ----------------------------------------------------
sub highlight_ids {

=pod

=head2 highlight_ids

Access the highlight bounds.

=cut

    my ( $self, %args ) = @_;
    my $object_key = $args{'object_key'};
    my $window_key = $args{'window_key'};

    return $self->{'object_selections'}{$window_key}{$object_key}
        {'highlight_ids'};
}

# ----------------------------------------------------
sub drag_highlight {

=pod

=head2 drag_highlight

Handle the highlight map dragging

=cut

    my ( $self, %args ) = @_;
    my $zinc = $args{'zinc'};
    my $x    = $args{'x'};
    my $dx   = $args{'dx'};
    my $y    = $args{'y'};
    my $dy   = $args{'dy'};
    return unless ( $dx or $dy );

    my $window_key = $self->{'drag_window_key'};
    my $map_key    = $self->{'drag_map_key'};

    # Move the highlight
    foreach my $highlight_id (
        @{  $self->highlight_ids(
                window_key => $window_key,
                object_key => $map_key,
                )
                || []
        }
        )
    {
        $zinc->translate( $highlight_id, $dx, $dy, );
    }

    # Move the bounds and get the new ones
    my $new_highlight_bounds = $self->highlight_bounds(
        window_key => $window_key,
        object_key => $map_key,
        dx         => $dx,
    );

    my %location_highlight_data
        = $self->app_controller()->app_display_data()
        ->move_location_highlights(
        map_key          => $map_key,
        mouse_x          => $x,
        mouse_y          => $y,
        highlight_bounds => $new_highlight_bounds,
        mouse_to_edge_x  => $self->{'drag_mouse_to_edge_x'},
        );
    return unless (%location_highlight_data);

    # Move the highlight loc
    my $highlight_loc = $self->highlight_loc(
        window_key => $window_key,
        object_key => $map_key,
    );
    my $selection_info = $self->{'object_selections'}{$window_key}{$map_key};
    unless ( $location_highlight_data{'highlight_loc_parent_zone_key'}
        == $highlight_loc->{'parent_zone_key'} )
    {
        $highlight_loc->{'parent_zone_key'}
            = $location_highlight_data{'highlight_loc_parent_zone_key'};

        my $parent_group_id = $self->get_zone_group_id(
            window_key => $window_key,
            zone_key =>
                $location_highlight_data{'highlight_loc_parent_zone_key'},
            zinc             => $zinc,
            app_display_data => $self->app_controller()->app_display_data(),
        );
        foreach my $highlight_loc_id (
            @{ $selection_info->{'highlight_loc'}{'highlight_loc_ids'}
                    || [] } )
        {
            $zinc->chggroup( $highlight_loc_id, $parent_group_id, 1, );
        }
    }
    foreach my $highlight_loc_id (
        @{ $selection_info->{'highlight_loc'}{'highlight_loc_ids'} || [] } )
    {
        $zinc->coords( $highlight_loc_id,
            $location_highlight_data{'highlight_loc_location_coords'},
        );
        $zinc->itemconfigure( $highlight_loc_id,
            -visible => $location_highlight_data{'highlight_loc_visible'}, );
    }

}

# ----------------------------------------------------
sub drag_subsection_highlight {

=pod

=head2 drag_subsection_highlight

Handle the highlight map dragging

=cut

    my ( $self, %args ) = @_;
    my $zinc = $args{'zinc'};
    my $x    = $args{'x'};
    my $dx   = $args{'dx'};
    my $y    = $args{'y'};
    my $dy   = $args{'dy'};
    return unless ( $dx or $dy );

    my $window_key = $self->{'drag_window_key'};
    my $map_key    = $self->{'drag_map_key'};

    # Move the highlight
    foreach my $highlight_id (
        @{  $self->highlight_ids(
                window_key => $window_key,
                object_key => $map_key,
                )
                || []
        }
        )
    {
        $zinc->translate( $highlight_id, $dx, $dy, );
    }

    # Move the bounds and get the new ones
    my $new_highlight_bounds = $self->highlight_bounds(
        window_key => $window_key,
        object_key => $map_key,
        dx         => $dx,
    );

    my $selection_info = $self->{'object_selections'}{$window_key}{$map_key};

    # Change the color of the highlight loc to
    # black to indicate it would be missing.
    foreach my $highlight_loc_id (
        @{ $selection_info->{'highlight_loc'}{'highlight_loc_ids'} || [] } )
    {
        $zinc->itemconfigure( $highlight_loc_id,
            ( '-linecolor' => 'black' ) );
    }

    # Create or Move the subsection loc
    my $subsection_location;
    if ( $subsection_location
        = $self->{'object_selections'}{$window_key}{$map_key}
        {'subsection_highlight_loc'} )
    {
        my %subsection_location_highlight_data
            = $self->app_controller()->app_display_data()
            ->move_subsection_location_highlights(
            map_key => $map_key,
            mouse_x => $x,
            mouse_y => $y,
            previous_subsection_location_coords =>
                $subsection_location->{'location_coords'},
            mouse_to_edge_x => $self->{'drag_mouse_to_edge_x'},
            );
        return unless (%subsection_location_highlight_data);
        $subsection_location->{'location_coords'}
            = $subsection_location_highlight_data{'subsection_loc_coords'};
        unless (
            $subsection_location_highlight_data{
                'subsection_loc_parent_zone_key'}
            == $subsection_location->{'parent_zone_key'} )
        {
            $subsection_location->{'parent_zone_key'}
                = $subsection_location_highlight_data{
                'subsection_loc_parent_zone_key'};

            my $parent_group_id = $self->get_zone_group_id(
                window_key => $window_key,
                zone_key   => $subsection_location_highlight_data{
                    'subsection_loc_parent_zone_key'},
                zinc => $zinc,
                app_display_data =>
                    $self->app_controller()->app_display_data(),
            );
            foreach my $subsection_loc_id (
                @{ $subsection_location->{'subsection_loc_ids'} || [] } )
            {
                $zinc->chggroup( $subsection_loc_id, $parent_group_id, 1, );
            }
        }

        # Move the subsection location marker
        foreach my $subsection_loc_id (
            @{ $subsection_location->{'subsection_loc_ids'} || [] } )
        {
            $zinc->translate(
                $subsection_loc_id,
                $subsection_location_highlight_data{'dx'},
                $subsection_location_highlight_data{'dy'}
            );
            $zinc->itemconfigure( $subsection_loc_id,
                -visible => $subsection_location_highlight_data{
                    'subsection_loc_visible'}, );
        }
    }
    else {
        $subsection_location
            = $self->{'object_selections'}{$window_key}{$map_key}
            {'subsection_highlight_loc'}
            = $self->create_subsection_location_on_map(
            zinc       => $zinc,
            map_key    => $map_key,
            window_key => $self->{'drag_window_key'},
            mouse_x    => $x,
            mouse_y    => $y,
            );
    }

}

# ----------------------------------------------------
sub mouse_wheel_event {

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

    my $new_text = $map_set_data->{'map_type'} . ": "
        . $map_set_data->{'map_set_name'};

    $text_box->insert( 'end', $new_text );
    $text_box->configure( -state => 'disabled', );

    return;
}

# ----------------------------------------------------
sub int_move_zone {

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
sub new_view {

=pod

=head2 new_view


=cut

    my ( $self, %args ) = @_;

    my $new_window_key = $self->app_controller()->create_window();
    $self->app_controller()
        ->new_reference_maps( window_key => $new_window_key, );

    return;
}

# ----------------------------------------------------
sub open_saved_view {

=pod

=head2 open_saved_view


=cut

    my ( $self, %args ) = @_;

    my $saved_view = $self->main_window()->getOpenFile();

    my $saved_view_data = $self->app_controller()
        ->open_saved_view( saved_view => $saved_view, );
    if ($saved_view_data) {
        my $new_window_key = $self->app_controller()->create_window();
        $self->app_controller()->app_display_data()
            ->dd_load_save_in_new_window(
            window_key      => $new_window_key,
            saved_view_data => $saved_view_data,
            );
    }
    else {
        $self->popup_warning( text => "Failed to open file: $saved_view", );
    }

    return;
}

# ----------------------------------------------------
sub save_view {

=pod

=head2 save_view


=cut

    my ( $self, %args ) = @_;
    my $app_display_data = $args{'app_display_data'};
    my $window_key       = $args{'window_key'};

    my $file = $self->main_window()->getSaveFile();
    if ($file) {
        $self->app_controller()->save_view(
            window_key => $window_key,
            file       => $file,
        );
    }
    return;
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
        -expand => 0,
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

    # Zinc Pane
    $self->{'zinc'}{$window_key}->pack(
        -side   => 'top',
        -anchor => 'n',
        -fill   => 'both',
        -expand => 1,
    );
}

sub text_dimensions {

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $text = $args{'text'} || q{};

    my $font_name = $self->get_font_name( window_key => $window_key, );
    my $zinc      = $self->zinc( window_key          => $window_key, );

    my $height = $zinc->fontConfigure( $font_name, '-size' ) * -1;
    my $width  = $zinc->fontMeasure( $font_name,   $text );

    return ( $width, $height, );
}

sub get_font_name {

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;

    unless ( $self->{'font_name'}{$window_key} ) {
        my $font_size = -10;
        my $font_name = 'cmap_font';
        my $family    = "courier";
        my $zinc      = $self->zinc( window_key => $window_key, );

        unless ( $self->{'font_name_created'}{$font_name} ) {
            my %fontDesc = ( -size => $font_size, -family => $family, );
            $zinc->fontCreate( $font_name, %fontDesc );
            $self->{'font_name_created'}{$font_name} = 1;
        }
        $self->{'font_name'}{$window_key} = $font_name;
    }

    return $self->{'font_name'}{$window_key};
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

Copyright (c) 2006-7 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

