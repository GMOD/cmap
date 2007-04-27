package Bio::GMOD::CMap::AppController;

# vim: set ft=perl:

# $Id: AppController.pm,v 1.33 2007-04-27 13:40:19 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::AppController - Controller for the CMap Application.

=head1 SYNOPSIS


=head1 DESCRIPTION

This is the controlling module for the CMap Application.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.33 $)[-1];

use Data::Dumper;
use Tk;
use LWP;
use XML::Simple;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Data::AppData;
use Bio::GMOD::CMap::Drawer::AppInterface;
use Bio::GMOD::CMap::Drawer::AppDisplayData;
use Bio::GMOD::CMap::AppPlugins::AppPluginSet;
use Bio::GMOD::CMap::Constants;

use base 'Bio::GMOD::CMap';

# ----------------------------------------------------
sub init {

=pod

=head2 init

Initializes the object.

=cut

    my ( $self, $config ) = @_;

    my $saved_view_data;
    if ( $config->{'saved_view'} ) {
        $saved_view_data
            = $self->open_saved_view( saved_view => $config->{'saved_view'}, )
            or die "Failed to open file: " . $config->{'saved_view'};
        $self->{'remote_url'} = $saved_view_data->{'remote_url'};
        $self->data_source( $saved_view_data->{'data_source'}
                || $config->{'data_source'} );
    }
    else {
        $self->params( $config, qw[ config_dir data_source ] );
        $self->{'remote_url'} = $config->{'remote_url'};
    }

    # The app_data_module will have the remote config if it is needed
    $self->config( $self->app_data_module()->config() );

    # Initiate AppPluginSet
    $self->plugin_set( $config->{'plugins'}, );

    $self->data_source( $self->{'data_source'} );
    my $window_key = $self->start_application();

    if ($saved_view_data) {
        $self->app_display_data()->dd_load_save_in_new_window(
            window_key      => $window_key,
            saved_view_data => $saved_view_data,
        );
    }
    else {
        $self->new_reference_maps( window_key => $window_key, );
    }

    MainLoop();
    return $self;
}

# ----------------------------------------------------
sub open_saved_view {

=pod
                                                                                                                             
=head2 open_saved_view
                                                                                                                             
Read in the saved view
                                                                                                                             
=cut

    my ( $self, %args ) = @_;
    my $saved_view = $args{'saved_view'} or return;

    unless ( $saved_view =~ /^http:\/\// ) {
        $saved_view = "file:" . $saved_view;
    }

    my $ua  = LWP::UserAgent->new;
    my $req = HTTP::Request->new( GET => $saved_view );
    my $res = $ua->request($req);
    if ( $res->is_success ) {
        return XMLin(
            $res->content,
            NoAttr        => 1,
            SuppressEmpty => 1,
        );
    }
    else {
        print STDERR $res->status_line, "\n";
        return undef;
    }

    return undef;
}

# ----------------------------------------------------
sub start_application {

=pod
                                                                                                                             
=head2 start_application
                                                                                                                             
This method will create the Application.
                                                                                                                             
=cut

    my $self = shift;
    my $window_key = $self->create_window( title => "CMap Application", )
        or die "Failed to create interface\n";
    return $window_key;
}

# ----------------------------------------------------
sub create_window {

=pod
                                                                                                                             
=head2 create_application
                                                                                                                             
This method will create the Application.
                                                                                                                             
=cut

    my $self       = shift;
    my $interface  = $self->app_interface();
    my $window_key = $self->app_display_data()
        ->create_window( title => "CMap Application", );
    unless ( defined $window_key ) {
        die "Problem setting up interface\n";
    }

    return $window_key;
}

# ----------------------------------------------------
sub plugin_set {

=pod

=head3 app_data_module

Returns a handle to the data module.

=cut

    my $self = shift;

    my $plugins = shift if @_;

    unless ( $self->{'plugin_set'} ) {
        $self->{'plugin_set'}
            = Bio::GMOD::CMap::AppPlugins::AppPluginSet->new(
            config           => $self->config,
            data_source      => $self->data_source,
            app_data_module  => $self->app_data_module,
            app_interface    => $self->app_interface,
            app_display_data => $self->app_display_data,
            plugins          => $plugins,
            );
    }

    return $self->{'plugin_set'};
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
            app_controller => $self,
            data_source    => $self->{'data_source'},
            config         => $self->{'remote_url'} ? undef: $self->config,
            remote_url     => $self->{'remote_url'},
            )
            or $self->error( Bio::GMOD::CMap::Data::AppData->error );
    }

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

    unless ( $self->{'app_interface'} ) {
        $self->{'app_interface'} = Bio::GMOD::CMap::Drawer::AppInterface->new(
            app_controller => $self, )
            or die "Couldn't initialize AppInterface\n";
    }

    return $self->{'app_interface'};
}

# ----------------------------------------------------
sub app_display_data {

=pod

=head3 app_display_data

Returns a handle to the data module.

=cut

    my ( $self, %args ) = @_;

    unless ( $self->{'app_display_data'} ) {
        $self->{'app_display_data'}
            = Bio::GMOD::CMap::Drawer::AppDisplayData->new(
            data_source     => $self->data_source,
            app_data_module => $self->app_data_module,
            app_interface   => $self->app_interface,
            config          => $self->config,
            )
            or die "failed to create app_display_data\n";
    }

    return $self->{'app_display_data'};
}

# ----------------------------------------------------
sub new_reference_maps {

=pod

=head2 new_reference_maps


=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'}
        or die "no window acc for new_reference_maps";

    $self->app_interface()->select_reference_maps(
        window_key => $window_key,
        controller => $self,
    );

    return;

}

=pod

=head1 CallBack Methods

=cut

# ----------------------------------------------------
sub load_new_window {

=pod

=head2 load_new_window

Load the first slot of a page.

=cut

    my ( $self, %args ) = @_;

    my $selectable_ref_map_ids = $args{'selectable_ref_map_ids'} or return;
    my $selections             = $args{'selections'}             or return;
    my $window_key             = $args{'window_key'}             or return;

    my @selected_map_ids = map { $selectable_ref_map_ids->[$_] } @$selections;

    if (@selected_map_ids) {
        $self->app_display_data()->dd_load_new_window(
            window_key => $window_key,
            map_ids    => \@selected_map_ids,
        );
    }

    return;

}

# ----------------------------------------------------
sub open_new_window {

=pod

=head2 open_new_window

Create another window.

=cut

    my ( $self, %args ) = @_;

    my $selected_map_ids  = $args{'selected_map_ids'}  || [];
    my $selected_map_keys = $args{'selected_map_keys'} || [];
    unless (@$selected_map_ids) {
        $selected_map_ids = $self->app_display_data()
            ->get_map_ids( map_keys => $selected_map_keys ) || [];
    }

    return unless (@$selected_map_ids);

    my $window_key = $self->create_window( title => "CMap Application", );
    unless ($window_key) {
        print STDERR "Failed to create window\n";
        return;
    }

    $self->app_display_data()->dd_load_new_window(
        window_key => $window_key,
        map_ids    => $selected_map_ids,
    );

    return;
}

# ----------------------------------------------------
sub close_window {

=pod

=head2 close_window

When window is closed, delete drawing data and if it is the last window, exit.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};

    $self->app_interface()->clear_interface_window(
        window_key       => $window_key,
        app_display_data => $self->app_display_data(),
    );
    $self->app_interface()
        ->destroy_interface_window( window_key => $window_key, );
    my $remaining_windows_num = $self->app_display_data()
        ->remove_window_data( window_key => $window_key, );

    unless ($remaining_windows_num) {
        exit;
    }

    return;
}

# ----------------------------------------------------
sub zoom_zone {

=pod

=head2 zoom_zone

Handler for zooming a zone.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $zone_key   = $args{'zone_key'};
    my $zoom_value = $args{'zoom_value'} || 1;

    $self->app_display_data()->zoom_zone(
        window_key => $window_key,
        zone_key   => $zone_key,
        zoom_value => $zoom_value,
    );

    return;
}

# ----------------------------------------------------
sub overview_scroll_slot {

=pod

=head2 overview_scroll_slot

Handler for overview scrolling a slot.

=cut

    my ( $self, %args ) = @_;
    my $window_key   = $args{'window_key'};
    my $slot_key     = $args{'slot_key'};
    my $scroll_value = $args{'scroll_value'} || 1;

    $self->app_display_data()->overview_scroll_slot(
        window_key   => $window_key,
        slot_key     => $slot_key,
        scroll_value => $scroll_value,
    );

    return;
}

# ----------------------------------------------------
sub scroll_zone {

=pod

=head2 scroll_zone

Handler for scrolling a zone.

=cut

    my ( $self, %args ) = @_;
    my $window_key   = $args{'window_key'};
    my $zone_key     = $args{'zone_key'};
    my $scroll_value = $args{'scroll_value'} || 1;

    $self->app_display_data()->scroll_zone(
        window_key   => $window_key,
        zone_key     => $zone_key,
        scroll_value => $scroll_value,
    );

    return;
}

# ----------------------------------------------------
sub expand_zone {

=pod

=head2 expand_zone

Handler for expanding a zone.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $zone_key   = $args{'zone_key'};

    $self->app_display_data()->expand_zone(
        window_key => $window_key,
        zone_key   => $zone_key,
    );

    return;
}

# ----------------------------------------------------
sub toggle_corrs_zone {

=pod

=head2 toggle_corrs_zone

Handler for toggling correspondences for a zone.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $zone_key   = $args{'zone_key'};

    $self->app_display_data()->toggle_corrs_zone(
        window_key => $window_key,
        zone_key   => $zone_key,
    );

    return;
}

# ----------------------------------------------------
sub get_map_info_text {

=pod

=head2 get_map_info_text

Create the text to go into the info box when a map is clicked.

=cut

    my ( $self, %args ) = @_;
    my $map_key          = $args{'map_key'};
    my $app_display_data = $self->app_display_data();
    my $map_id           = $app_display_data->map_key_to_id($map_key);

    my $map_data = $self->app_data_module()->map_data( map_id => $map_id, );

#    my $feature_info_str = $self->feature_type_data($feature_data->{'feature_type_acc'},'feature_type').": "
#        . $feature_data->{'feature_name'} . "\n"
#        . "Location: "
#        . $feature_data->{'feature_start'} . "-"
#        . $feature_data->{'feature_stop'} . "\n";
    my $map_info_str = $map_data->{'map_type'} . ": "
        . $map_data->{'map_name'} . "\n"
        . "Start: "
        . $map_data->{'map_start'} . "\n"
        . "Stop: "
        . $map_data->{'map_stop'} . "\n";

    my $sub_map_data = $app_display_data->{'sub_maps'}{$map_key};
    if ($sub_map_data) {
        $map_info_str .= "Start on Parent: "
            . $sub_map_data->{'feature_start'} . "\n"
            . "Stop on Parent: "
            . $sub_map_data->{'feature_stop'} . "\n";
    }

    return $map_info_str;
}

# ----------------------------------------------------
sub get_feature_info_text {

=pod

=head2 get_feature_info_text

Create the text to go into the info box when a feature is clicked.

=cut

    my ( $self, %args ) = @_;
    my $feature_acc      = $args{'feature_acc'};
    my $app_display_data = $self->app_display_data();

    my $feature_data = $self->app_data_module()
        ->feature_data( feature_acc => $feature_acc, );

    my $feature_info_str
        = $self->feature_type_data( $feature_data->{'feature_type_acc'},
        'feature_type' )
        . ": "
        . $feature_data->{'feature_name'} . "\n"
        . "Location: "
        . $feature_data->{'feature_start'} . "-"
        . $feature_data->{'feature_stop'} . "\n";

    return $feature_info_str;
}

# ----------------------------------------------------
sub new_selected_zone {

=pod

=head2 new_selected_zone

Handler for selecting a new zone.

=cut

    my ( $self, %args ) = @_;
    my $zone_key = $args{'zone_key'};

    $self->app_display_data()->change_selected_zone( zone_key => $zone_key, );

    return;
}

# ----------------------------------------------------
sub hide_corrs {

=pod

=head2 hide_corrs

Hide correspondences while moving.

=cut

    my ( $self, %args ) = @_;

    $self->app_display_data()->hide_corrs(
        window_key => $args{'window_key'},
        slot_key   => $args{'slot_key'},
    );

    return;
}

# ----------------------------------------------------
sub unhide_corrs {

=pod

=head2 unhide_corrs

Hide correspondences while moving.

=cut

    my ( $self, %args ) = @_;

    $self->app_display_data()->unhide_corrs(
        window_key => $args{'window_key'},
        slot_key   => $args{'slot_key'},
    );

    return;
}

# ----------------------------------------------------
sub move_ghost_map {

=pod

=head2 move_ghost

Controls how the ghost map moves.

=cut

    my ( $self, %args ) = @_;

    return $self->app_display_data()->move_ghost_map(%args);

}

# ----------------------------------------------------
sub export_map_moves {

=pod

=head2 export_map_moves

Export the map moves to a file.

=cut

    my ( $self, %args ) = @_;
    my $window_key       = $args{'window_key'}       or return;
    my $export_file_name = $args{'export_file_name'} or return;
    my $app_display_data = $self->app_display_data();

    my $fh;
    unless ( open $fh, ">" . $export_file_name ) {
        print "WARNING: Unable to write to $export_file_name.\n";
        return;
    }

    my $condenced_actions = $app_display_data->condenced_window_actions(
        window_key => $window_key, );

    foreach my $action ( @{ $condenced_actions || [] } ) {
        if ( $action->[0] eq 'move_map' ) {
            my @print_array = (
                $action->[0],
                $app_display_data->map_key_to_id( $action->[1] ),
                $app_display_data->map_key_to_id( $action->[2] ),
                $action->[3],
                $action->[4],
                $app_display_data->map_key_to_id( $action->[5] ),
                $action->[6],
                $action->[7],
            );
        }
    }

    close $fh;
    return;
}

# ----------------------------------------------------
sub commit_map_moves {

=pod

=head2 commit_map_moves

Export the map moves to a file.

=cut

    my ( $self, %args ) = @_;
    my $window_key       = $args{'window_key'} or return;
    my $app_display_data = $self->app_display_data();

    my $condenced_actions = $app_display_data->condenced_window_actions(
        window_key => $window_key, );

    my @moved_features;
    foreach my $action ( @{ $condenced_actions || [] } ) {
        if ( $action->[0] eq 'move_map' ) {
            my $map_key = $action->[1];
            push @moved_features,
                {
                feature_id =>
                    $app_display_data->{'sub_maps'}{$map_key}{'feature_id'},
                sub_map_id => $app_display_data->map_key_to_id($map_key),
                original_parent_map_id =>
                    $app_display_data->map_key_to_id( $action->[2] ),
                map_id => $app_display_data->map_key_to_id( $action->[5] ),
                feature_start => $action->[6],
                feature_stop  => $action->[7],
                };
        }
    }

    $self->app_data_module->commit_sub_map_moves(
        features => \@moved_features, );

    return;
}

# ----------------------------------------------------
sub save_view {

=pod

=head2 save_view

Save the view information to a file.

=cut

    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'} or return;
    my $file       = $args{'file'}       or return;
    my $app_display_data = $self->app_display_data();

    #unless ( -w $file ) {
    #$self->app_interface->popup_warning(
    #text => "Cannot write to file '$file'.\n", );
    #return;
    #}

    my $fh;
    if ( open $fh, ">" . $file ) {
        my $data_hash = $app_display_data->save_view_data_hash(
            window_key => $window_key, );
        $data_hash->{'remote_url'}  = $self->{'remote_url'};
        $data_hash->{'data_source'} = $self->data_source();
        print $fh XMLout(
            $data_hash,
            RootName      => 'cmap_editor',
            NoAttr        => 1,
            SuppressEmpty => 1,
            XMLDecl       => 0,
        );
        close $fh;
    }
    else {
        $self->app_interface->popup_warning(
            text => "Unable to open file '$file' for writing.\n", );
        return;
    }

    return;
}

=pod

=head1 Extra Methods

=cut

# ----------------------------------------------------
sub xcheck_datasource_credentials {

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

