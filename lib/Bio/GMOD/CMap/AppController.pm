package Bio::GMOD::CMap::AppController;

# vim: set ft=perl:

# $Id: AppController.pm,v 1.1 2006-02-05 04:17:58 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::AppController - Controller for the CMap Application.

=head1 SYNOPSIS


=head1 DESCRIPTION

This is the controlling module for the CMap Application.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.1 $)[-1];

use Data::Dumper;
use Tk;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Data::AppData;
use Bio::GMOD::CMap::Drawer::AppDrawer;
use Bio::GMOD::CMap::Constants;

use base 'Bio::GMOD::CMap';

# ----------------------------------------------------
sub init {

=pod

=head2 init

Initializes the object.

=cut

    my ( $self, $config ) = @_;
    $self->params( $config, qw[ config_dir data_source ] );
    $self->config();
    $self->data_source( $self->{'data_source'} );
    $self->create_application();
    $self->new_reference_maps();    #BF remove after testing is done
    MainLoop();
    return $self;
}

# ----------------------------------------------------
sub create_application {

=pod

=head2 create_application

This method will create the Application.

=cut

    my $self = shift;
    my %args = @_;

    my $main_window = $self->main_window();
    $main_window->title('CMap Application');
    $self->menu_bar();
    my $canvas = $self->canvas();

    return 1;
}

# ----------------------------------------------------
sub main_window {

=pod

=head2 main_window

Returns the TK main_window object.

=cut

    my $self = shift;
    unless ( $self->{'main_window'} ) {
        $self->{'main_window'} = MainWindow->new();
    }
    return $self->{'main_window'};
}

# ----------------------------------------------------
sub menu_bar {

=pod

=head2 menu_bar

Returns the menu_bar object.

=cut

    my $self = shift;
    unless ( $self->{'menu_bar'} ) {
        my $main_window = $self->main_window();
        $self->{'menu_bar'} = $main_window->Menu();
        $main_window->configure( -menu => $self->{'menu_bar'} );
        $self->populate_menu_bar();
    }
    return $self->{'menu_bar'};
}

# ----------------------------------------------------
sub populate_menu_bar {

=pod

=head2 populate_menu_bar

Populates the menu_bar object.

=cut

    my $self = shift;

    my $menu_bar = $self->menu_bar();

    $self->{'menu_buttons'}->{'file'} = $menu_bar->cascade(
        -label     => '~file',
        -menuitems => $self->file_menu_items(),
    );

    return;
}

# ----------------------------------------------------
sub file_menu_items {

=pod

=head2 file_menu_items

Populates the file menu with menu_items

=cut

    my $self = shift;
    return [
        [   'command', '~Load',
            -accelerator => 'Ctrl-l',
            -command     => sub { new_reference_maps($self) },
        ],
        [   'command', '~Quit',
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

    my $self = shift;
    unless ( $self->{'canvas'} ) {
        my $canvas_frame = $self->main_window()->Frame()
            ->pack( -side => 'bottom', -fill => 'both', );
        $self->{'canvas'} = $canvas_frame->Scrolled(
            'Canvas',
            (   '-width'        => '950',
                '-height'       => '500',
                '-relief'       => 'sunken',
                '-borderwidth'  => 2,
                '-scrollbars'   => 'se',
                '-scrollregion' => [qw/0c 0c 30c 24c/],
            ),
        )->pack;
    }
    return $self->{'canvas'};
}

# ----------------------------------------------------
sub zzz {

=pod

=head2 zzz

Returns the zzz object.

=cut

    my $self = shift;
    unless ( $self->{'zzz'} ) {
        $self->{'zzz'} = '';
    }
    return $self->{'zzz'};
}

# ----------------------------------------------------
sub yyy {

=pod

=head2 yyy

Returns the yyy object.

=cut

    my $self = shift;
    return $self->{'yyy'};
}

# ----------------------------------------------------
sub app_data_module {

=pod

=head3 app_data_module

Returns a handle to the data module.

=cut

    my $self = shift;

    $self->{'app_data_module'} = shift if @_;

    unless ( $self->{'app_data_module'} ) {
        $self->{'app_data_module'} = Bio::GMOD::CMap::Data::AppData->new(
            data_source         => $self->data_source,
            config              => $self->config,
            aggregate           => $self->aggregate,
            cluster_corr        => $self->cluster_corr,
            show_intraslot_corr => $self->show_intraslot_corr,
            split_agg_ev        => $self->split_agg_ev,
            ref_map_order       => $self->ref_map_order,
            comp_menu_order     => $self->comp_menu_order,
            )
            or $self->error( Bio::GMOD::CMap::Data::AppData->error );
    }

    return $self->{'app_data_module'};
}

# ----------------------------------------------------
sub app_drawer {

=pod

=head3 app_drawer

Returns a handle to the data module.

=cut

    my $self = shift;

    $self->{'app_drawer'} = shift if @_;

    unless ( $self->{'app_drawer'} ) {
        $self->{'app_drawer'} = Bio::GMOD::CMap::Drawer::AppDrawer->new(
            canvas              => $self->canvas,
            data_source         => $self->data_source,
            data_module         => $self->app_data_module,
            config              => $self->config,
            aggregate           => $self->aggregate,
            cluster_corr        => $self->cluster_corr,
            show_intraslot_corr => $self->show_intraslot_corr,
            split_agg_ev        => $self->split_agg_ev,
            ref_map_order       => $self->ref_map_order,
            comp_menu_order     => $self->comp_menu_order,
            )
            or $self->error( Bio::GMOD::CMap::Data::AppData->error );
    }

    return $self->{'app_drawer'};
}

# ----------------------------------------------------
sub new_reference_maps {

=pod

=head2 new_reference_maps


=cut

    my $self = shift;

    my $reference_maps = $self->get_reference_maps();
    $self->main_window()->withdraw();

    my $ref_selection_window
        = $self->main_window()->Toplevel( -takefocus => 1 );
    $ref_selection_window->title('POP');
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
    my $ref_species_acc         = $reference_maps->[0]->{'species_acc'};
    my $selectable_ref_map_accs = [];

    foreach my $species ( @{ $reference_maps || [] } ) {
        $species_frame->Radiobutton(
            -text     => $species->{'species_common_name'},
            -value    => $species->{'species_acc'},
            -variable => \$ref_species_acc,
            -command  => sub {
                $self->display_reference_map_sets(
                    map_set_frame           => $map_set_frame,
                    map_listbox             => $map_listbox,
                    selectable_ref_map_accs => $selectable_ref_map_accs,
                    map_sets                => $species->{'map_sets'},
                );
            },
        )->pack( -side => 'top', -anchor => 'nw', );
    }
    $species_frame->pack( -side => 'left', -anchor => 'n', );
    $map_set_frame->pack( -side => 'left', -anchor => 'n', );
    $map_frame->pack( -side     => 'left', -anchor => 'n', );
    $self->display_reference_map_sets(
        map_set_frame           => $map_set_frame,
        map_listbox             => $map_listbox,
        selectable_ref_map_accs => $selectable_ref_map_accs,
        map_sets                => $reference_maps->[0]{'map_sets'},
    );
    $selection_frame->pack( -side => 'top', -anchor => 'nw', );

    $ref_selection_window->Button(
        -text    => "Load Maps",
        -command => sub {
            $self->load_maps(
                selectable_ref_map_accs => $selectable_ref_map_accs,
                selections              => [ $map_listbox->curselection() ],
            );
            $self->close_secondary_window($ref_selection_window);
        },
    )->pack( -side => 'bottom', -anchor => 's' );
    $ref_selection_window->Button(
        -text    => "Cancel",
        -command => sub {
            $self->close_secondary_window($ref_selection_window);
        },
    )->pack( -side => 'bottom', -anchor => 's' );
    $ref_selection_window->protocol( 'WM_DELETE_WINDOW',
        sub { $self->close_secondary_window($ref_selection_window); } );

return;

}

# ----------------------------------------------------
sub load_maps {

=pod

=head2 load_maps


=cut

    my ($self,%args)= @_;

    my $selectable_ref_map_accs = $args{'selectable_ref_map_accs'} or return;
    my $selections = $args{'selections'} or return;

    my @selected_map_accs = map { $selectable_ref_map_accs->[$_] } @$selections ; 

    $self->{'slots'} = {
        '0' => {
            min_corrsmap => '',
            maps         =>
                { map { $selectable_ref_map_accs->[$_]=>{} } @$selections },
            map_sets => {},
        }
    };


#    my $slots = {
#        '1' => {
#            'min_corrs' => '',
#            'maps'      => {
#                '18' => {
#                    'start' => undef,
#                    'mag'   => 1,
#                    'stop'  => undef
#                },
#                '17' => {
#                    'start' => undef,
#                    'mag'   => 1,
#                    'stop'  => undef
#                }
#            },
#            'map_sets' => {}
#        },
#        '0' => {
#            'min_corrs' => '0',
#            'maps'      => {
#                '56' => {
#                    'start' => undef,
#                    'mag'   => 1,
#                    'stop'  => undef
#                }
#            },
#            'map_set_acc' => 'MS4',
#            'map_sets'    => {}
#        }
#    };

    my $new_maps = $self->app_data_module()->map_data(map_accs => \@selected_map_accs,);
print STDERR Dumper(\@selected_map_accs)."\n";
print STDERR Dumper($new_maps)."\n";


    ( $self->{'data'}, $self->{'slots'} )
        = $self->app_data_module()
        ->set_data( slots => $self->{'slots'}, url_feature_default_display => 2, );
    my $drawer = $self->app_drawer();
    $drawer->slots($self->{'slots'});
    $drawer->initial_draw( data => $self->{'data'} );

    #exit;
}

# ----------------------------------------------------
sub close_secondary_window {

=pod

=head2 get_reference_maps


=cut

    my $self             = shift;
    my $secondary_window = shift;
    $self->main_window()->deiconify();
    $self->main_window()->raise();
    $secondary_window->destroy();
}

# ----------------------------------------------------
sub slots {

=pod

=head2 slots


=cut

    my $self = shift;
    my $new_slots = shift;

    if (defined $new_slots){
        $self->{'slots'} = $new_slots;
    }
    return $self->{'slots'};

}
# ----------------------------------------------------
sub get_reference_maps {

=pod

=head2 get_reference_maps


=cut

    my $self = shift;

    unless ( $self->{'reference_maps'} ) {
        $self->{'reference_maps'}
            = $self->app_data_module()->get_reference_maps();
    }
    return $self->{'reference_maps'};

}

# ----------------------------------------------------
sub display_reference_map_sets {

=pod

=head2 display_reference_map_sets

=cut

    my ( $self, %args ) = @_;
    my $map_set_frame           = $args{'map_set_frame'};
    my $map_listbox             = $args{'map_listbox'};
    my $selectable_ref_map_accs = $args{'selectable_ref_map_accs'};
    my $map_sets                = $args{'map_sets'};

    $self->clear_buttons($map_set_frame);
    $self->clear_ref_maps( $map_listbox, $selectable_ref_map_accs );

    my $ref_map_set_acc = $map_sets->[0]->{'map_set_acc'};
    foreach my $map_set ( @{ $map_sets || [] } ) {
        $map_set_frame->Radiobutton(
            -text     => $map_set->{'map_set_name'},
            -value    => $map_set->{'map_set_acc'},
            -variable => \$ref_map_set_acc,
            -command  => sub {
                $self->display_reference_maps(
                    map_listbox             => $map_listbox,
                    selectable_ref_map_accs => $selectable_ref_map_accs,
                    maps                    => $map_set->{'maps'},
                );
            },
        )->pack( -side => 'top', -anchor => 'nw', );
    }

    $self->display_reference_maps(
        map_listbox             => $map_listbox,
        selectable_ref_map_accs => $selectable_ref_map_accs,
        maps                    => $map_sets->[0]{'maps'},
    );
}

# ----------------------------------------------------
sub display_reference_maps {

=pod

=head2 display_reference_map_sets

=cut

    my ( $self, %args ) = @_;
    my $map_listbox             = $args{'map_listbox'};
    my $selectable_ref_map_accs = $args{'selectable_ref_map_accs'};
    my $maps                    = $args{'maps'};

    $self->clear_ref_maps( $map_listbox, $selectable_ref_map_accs );

    foreach my $map ( @{ $maps || [] } ) {
        $map_listbox->insert( 'end', $map->{'map_name'}, );
        push @$selectable_ref_map_accs, $map->{'map_acc'};
    }
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

}

# ----------------------------------------------------
sub clear_ref_maps {

=pod

=head2 clear_ref_maps

=cut

    my $self             = shift;
    my $ref_maps_listbox = shift or return;
    my $ref_map_accs     = shift or return;
    $ref_maps_listbox->delete( 0, 'end' );
    @$ref_map_accs = ();

}

# ----------------------------------------------------
sub check_datasource_credentials {

=pod

=head2 check_datasource_credentials

See if we need to prompt for user/pass for the given datasource.  

This seems like it will be useful in the application too.  We'll keep it around
for now.

=cut

    my $self    = shift;
    my $ds      = $self->data_source() or return;
    my $config  = $self->config or return;
    my $db_conf = $config->get_config('database');

    #    if ( my $passwd_file = $db_conf->{'passwd_file'} ) {
    #        if ( my $cookie = $apr->cookie('CMAP_LOGIN') ) {
    #            my $sekrit = 'r1ce1sn2c3';
    #            my ( $user, $ds2, $auth ) = split( /:/, $cookie );
    #            return $ds                          eq $ds2
    #                && md5( $user . $ds . $sekrit ) eq $auth;
    #        }
    #        else {
    #            return 0;
    #        }
    #    }
    #    else {
    return 1;

    #    }
}

sub _order_out_from_zero {
    ###Return the sort in this order (0,1,-1,-2,2,-3,3,)
    return ( abs($a) cmp abs($b) );
}

1;

# ----------------------------------------------------
# If the fool would persist in his folly
# He would become wise.
# William Blake
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

