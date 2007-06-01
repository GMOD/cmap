package Bio::GMOD::CMap::Data::AppData;

# vim: set ft=perl:

# $Id: AppData.pm,v 1.22 2007-06-01 14:54:00 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Data::AppData - draw maps 

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Data::AppData;

=head1 DESCRIPTION

Retrieves and caches the data from the database.

=head1 Usage

    my $data = Bio::GMOD::CMap::Data::AppData->new();

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.22 $)[-1];

use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use Bio::GMOD::CMap::Admin;
use LWP::UserAgent;
use Storable qw(nfreeze thaw);
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use Clone qw(clone);
use base 'Bio::GMOD::CMap::Data';

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->{'app_controller'} = $config->{'app_controller'};
    $self->{'remote_url'} = $config->{'remote_url'} || q{};
    if ( $self->{'remote_url'} ) {
        $self->config( $self->get_remote_config() );
    }
    else {
        $self->config( $config->{'config'} );
    }
    $self->data_source( $config->{'data_source'} );

    return $self;
}

# ----------------------------------------------------
sub get_remote_config {

=pod

=head2 get_remote_config

Given a map accessions, return the information required to draw the
map.

=cut

    my ( $self, %args ) = @_;

    my $config = undef;
    if ( my $url = $self->{'remote_url'} ) {
        $url .= ';action=get_config';
        $config = $self->request_remote_data(
            url       => $url,
            want_hash => 'want_hash',
            thaw      => 1,
        );
    }

    return $config;

}

# ----------------------------------------------------
sub map_data {

=pod

=head2 map_data

Given a map accessions, return the information required to draw the
map.

=cut

    my ( $self, %args ) = @_;
    my $map_id  = $args{'map_id'};
    my $map_acc = $args{'map_acc'};

    if (   ( $map_id and not $self->{'map_data'}{$map_id} )
        or ( $map_acc and not $map_id ) )
    {

        my $maps;
        if ($map_id) {
            $maps = $self->sql_get_maps( map_id => $map_id, )
                || [];
            return undef unless (@$maps);
        }
        else {
            $maps = $self->sql_get_maps( map_accs => [ $map_acc, ], )
                || [];
            return undef unless (@$maps);
            $map_id = $maps->[0]{'map_id'};
        }

        $self->{'map_data'}{$map_id} = $maps->[0];
    }

    return $self->{'map_data'}{$map_id};
}

# ----------------------------------------------------
sub remove_map_data {

=pod

=head2 map_data

Remove map data from memory;

=cut

    my ( $self, %args ) = @_;
    my $map_id = $args{'map_id'} or return undef;

    delete $self->{'map_data'}{$map_id};

    return 1;
}

# ----------------------------------------------------
sub generate_map_data {

=pod

=head2 map_data

Given a map accessions, return the information required to draw the
map.

=cut

    my ( $self, %args ) = @_;
    my $old_map_id = $args{'old_map_id'} or return undef;
    my $new_map_id = $args{'new_map_id'} or return undef;
    my $map_acc   = $args{'map_acc'} || $new_map_id;
    my $map_start = $args{'map_start'};
    my $map_stop  = $args{'map_stop'};
    my $map_name  = $args{'map_name'};

    $self->{'map_data'}{$new_map_id} = clone $self->{'map_data'}{$old_map_id};
    $self->{'map_data'}{$new_map_id}{'map_id'}    = $new_map_id;
    $self->{'map_data'}{$new_map_id}{'map_acc'}   = $map_acc;
    $self->{'map_data'}{$new_map_id}{'map_start'} = $map_start;
    $self->{'map_data'}{$new_map_id}{'map_stop'}  = $map_stop;
    $self->{'map_data'}{$new_map_id}{'map_name'}  = $map_name if ($map_name);

    return $self->{'map_data'}{$new_map_id};
}

# ----------------------------------------------------
sub map_data_array {

=pod

=head2 map_data_array

Given a list of map ids or accessions, return the information required to draw the
map as an array.

Note: the maps are stored by id so any map_accs will hit the database no matter what.

=cut

    my ( $self, %args ) = @_;
    my $map_ids  = $args{'map_ids'}  || [];
    my $map_accs = $args{'map_accs'} || [];

    return undef unless ( @$map_ids or @$map_accs );

    my @map_data;
    my @new_map_ids;
    foreach my $map_id (@$map_ids) {
        if ( $self->{'map_data'}{$map_id} ) {
            push @map_data, $self->{'map_data'}{$map_id};
        }
        else {
            push @new_map_ids, $map_id;
        }
    }

    if ( @new_map_ids || @$map_accs ) {
        my $new_maps = $self->sql_get_maps(
            map_ids  => \@new_map_ids,
            map_accs => $map_accs,
            )
            || [];

        foreach my $new_map (@$new_maps) {
            $self->{'map_data'}{ $new_map->{'map_id'} } = $new_map;
        }

        push @map_data, (@$new_maps);
    }

    @map_data
        = sort { $a->{'display_order'} <=> $b->{'display_order'} } @map_data;

    return \@map_data;
}

# ----------------------------------------------------
sub map_data_hash {

=pod

=head2 map_data_hash

Given a list of map accessions, return the information required to draw the
map as a hash.

=cut

    my ( $self, %args ) = @_;
    my $map_ids = $args{'map_ids'} || [];

    return undef unless (@$map_ids);

    my %map_data;
    my @new_map_ids;
    foreach my $map_id (@$map_ids) {
        if ( $self->{'map_data'}{$map_id} ) {
            $map_data{$map_id} = $self->{'map_data'}{$map_id};
        }
        else {
            push @new_map_ids, $map_id;
        }
    }

    if (@new_map_ids) {
        my $new_maps = $self->sql_get_maps( map_ids => \@new_map_ids, )
            || [];

        foreach my $new_map (@$new_maps) {
            $self->{'map_data'}{ $new_map->{'map_id'} } = $new_map;
            $map_data{ $new_map->{'map_id'} } = $new_map;
        }
    }

    return \%map_data;
}

# ----------------------------------------------------
sub feature_data_by_map {

=pod

=head2 feature_data

Given a map accessions, return the information required to draw the
features.  These do NOT include the sub-maps.

=cut

    my ( $self, %args ) = @_;
    my $map_id = $args{'map_id'} or return undef;

    unless ( $self->{'feature_data_by_map'}{$map_id} ) {

        my $features = $self->sql_get_features_sub_maps_version(
            cmap_object => $self,
            map_id      => $map_id,
            no_sub_maps => 1,
            )
            || [];
        if ( @{ $features || [] } ) {
            $self->{'feature_data_by_map'}{$map_id} = $features;
            foreach my $feature (@$features) {
                $self->{'feature_data_by_acc'}{ $feature->{'feature_acc'} }
                    = $feature;
            }
        }
        else {
            return undef;
        }
    }

    return $self->{'feature_data_by_map'}{$map_id};
}

# ----------------------------------------------------
sub copy_feature_data_to_new_map {

=pod

=head2 copy_feature_data

Given a hash of feature_accs, copy them in memory to a new map_id 

=cut

    my ( $self, %args ) = @_;
    my $old_map_id       = $args{'old_map_id'};
    my $new_map_id       = $args{'new_map_id'};
    my $feature_acc_hash = $args{'feature_acc_hash'};

    foreach (
        my $i = 0;
        $i <= $#{ $self->{'feature_data_by_map'}{$old_map_id} || [] };
        $i++
        )
    {
        if ($feature_acc_hash->{ $self->{'feature_data_by_map'}{$old_map_id}
                    [$i] } )
        {
            push @{ $self->{'feature_data_by_map'}{$new_map_id} },
                $self->{'feature_data_by_map'}{$old_map_id}[$i];

           # uncomment the following to make this a move instead of a copy.
           #splice( @{ $self->{'feature_data_by_map'}{$old_map_id} }, $i, 1,);
           #$i--;
        }
    }
    $self->{'sorted_feature_data'}{$old_map_id} = undef;

    return 1;
}

# ----------------------------------------------------
sub move_feature_data_on_map {

=pod

=head2 move_feature_data_on_map

Given a list of feature_accs, move them in memory 

=cut

    my ( $self, %args ) = @_;
    my $feature_acc_array = $args{'feature_acc_array'} || [];
    my $offset            = $args{'offset'};

    foreach my $feature_acc (@$feature_acc_array) {
        $self->{'feature_data_by_acc'}{$feature_acc}{'feature_start'}
            += $offset;
        $self->{'feature_data_by_acc'}{$feature_acc}{'feature_stop'}
            += $offset;
    }

    return 1;
}

# ----------------------------------------------------
sub feature_data {

=pod

=head2 feature_data

Given a map accessions, return the information required to draw the
features.  These do NOT include the sub-maps.

=cut

    my ( $self, %args ) = @_;
    my $feature_acc = $args{'feature_acc'} or return undef;

    unless ( $self->{'feature_data_by_acc'}{$feature_acc} ) {
        return undef;

        #my $features = $self->sql_get_features_sub_maps_version(
        #cmap_object => $self,
        #map_id      => $map_id,
        #no_sub_maps => 1,
        #)
        #|| [];
        #if (@{$features||[]}) {
        #$self->{'feature_data_by_map'}{$map_id} = $features;
        #foreach my $feature (@$features){
        #$self->{'feature_data_by_map'}{$feature->{'feature_acc'}} = $feature;
        #}
        #}
        #else {
        #return undef;
        #}
    }

    return $self->{'feature_data_by_acc'}{$feature_acc};
}

# ----------------------------------------------------
sub sub_maps {

=pod

=head2 sub_maps

Given a map id, return the information required to draw the
sub-maps.  These do NOT include the regular features;

=cut

    my ( $self, %args ) = @_;
    my $map_id = $args{'map_id'} or return undef;

    unless ( $self->{'sub_map_data'}{$map_id} ) {

        my $features = $self->sql_get_features_sub_maps_version(
            cmap_object  => $self,
            map_id       => $map_id,
            get_sub_maps => 1,
            )
            || [];
        if (@$features) {
            $self->{'sub_map_data'}{$map_id} = $features;
        }
        else {
            return undef;
        }
    }

    return $self->{'sub_map_data'}{$map_id};
}

# ----------------------------------------------------
sub sorted_feature_data {

=pod

=head2 sorted_feature_data

Given a map accessions, return the information required to draw the
features.  These do NOT include the sub-maps.

=cut

    my ( $self, %args ) = @_;
    my $map_id = $args{'map_id'} or return undef;

    unless ( $self->{'sorted_feature_data'}{$map_id} ) {

        my $features = $self->feature_data_by_map( map_id => $map_id, )
            || [];
        if (@$features) {

            # The features are already sorted by start and stop.
            # All we need to do now is break them apart by lane and priority

            my $feature_type_data = $self->feature_type_data();
            my %sorting_hash;

            for my $feature ( @{$features} ) {
                my $this_feature_type_data
                    = $feature_type_data->{ $feature->{'feature_type_acc'} };
                push @{
                    $sorting_hash{ $this_feature_type_data->{'drawing_lane'}
                            || 1 }->{
                        $this_feature_type_data->{'drawing_priority'} || 1
                        }
                    },
                    $feature;
            }
            foreach my $lane ( sort { $a <=> $b } keys(%sorting_hash) ) {
                foreach my $priority (
                    sort { $a <=> $b }
                    keys( %{ $sorting_hash{$lane} } )
                    )
                {
                    push @{ $self->{'sorted_feature_data'}{$map_id}{$lane} },
                        @{ $sorting_hash{$lane}->{$priority} };
                }
            }
        }
        else {
            return undef;
        }
    }

    return $self->{'sorted_feature_data'}{$map_id};
}

# ----------------------------------------------------
sub zone_correspondences {

=pod

=head2 zone_correspondences

Given a map id, return the information required to draw the
sub-maps.  These do NOT include the regular features;

Takes two slot_infos which are defined as:

 Structure:
    {
        map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ],
    }

Requires zone_key1 to be less than zone_key2.

=cut

    my ( $self, %args ) = @_;
    my $zone_key1  = $args{'zone_key1'}  or return undef;
    my $zone_key2  = $args{'zone_key2'}  or return undef;
    my $slot_info1 = $args{'slot_info1'} or return undef;
    my $slot_info2 = $args{'slot_info2'} or return undef;
    my $allow_intramap = $args{'allow_intramap'} || 0;

    if ( $zone_key1 > $zone_key2 ) {
        die "AppData->zone_correspondences called with zone1 > zone2\n";
    }
    my $cache_key = md5_hex( Dumper( $slot_info1, $slot_info2 ) );

    unless ($self->{'zone_corr_data'}{$zone_key1}{$zone_key2}
        and $self->{'zone_corr_data'}{$zone_key1}{$zone_key2}{'cache_key'} eq
        $cache_key )
    {

        my $corrs = $self->sql_get_feature_correspondence_for_counting(
            slot_info      => $slot_info1,
            slot_info2     => $slot_info2,
            allow_intramap => $allow_intramap,
            )
            || [];
        $self->{'zone_corr_data'}{$zone_key1}{$zone_key2}{'corrs'} = $corrs;
        $self->{'zone_corr_data'}{$zone_key1}{$zone_key2}{'cache_key'}
            = $cache_key;
    }

    return $self->{'zone_corr_data'}{$zone_key1}{$zone_key2}{'corrs'};
}

# ----------------------------------------------------
sub get_map_set_data {

=pod

=head2 get_map_set_data

Returns information about map set

=cut

    my ( $self, %args ) = @_;
    my $map_set_id = $args{'map_set_id'};

    unless ( $self->{'map_set_data'}{$map_set_id} ) {

        my $map_set_data_array = $self->sql_get_map_sets(
            cmap_object => $self,
            map_set_id  => $map_set_id,
            )
            || [];
        $self->{'map_set_data'}{$map_set_id} = $map_set_data_array->[0];

    }
    return $self->{'map_set_data'}{$map_set_id};
}

# ----------------------------------------------------
sub get_reference_maps_by_species {

=pod

=head2 get_reference_maps_by_species

Returns information about all possible reference maps.

=cut

    my ( $self, %args ) = @_;

    unless ( $self->{'reference_maps_by_species'} ) {

        # Get all species first
        $self->{'reference_maps_by_species'} = $self->sql_get_species(
            cmap_object       => $self,
            is_relational_map => 0,
            is_enabled        => 1,
        );

        foreach
            my $species ( @{ $self->{'reference_maps_by_species'} || [] } )
        {
            $species->{'map_sets'} = $self->sql_get_map_sets(
                cmap_object       => $self,
                species_id        => $species->{'species_id'},
                is_relational_map => 0,
                is_enabled        => 1,
            );
            foreach my $map_set ( @{ $species->{'map_sets'} || [] } ) {
                $self->{'map_set_data'}{ $map_set->{'map_set_id'} }
                    = $map_set;
                $map_set->{'maps'} = $self->sql_get_maps_from_map_set(
                    cmap_object => $self,
                    map_set_id  => $map_set->{'map_set_id'},
                );
            }
        }

    }
    return $self->{'reference_maps_by_species'};
}

# ----------------------------------------------------
sub user_agent {

=pod

=head2 user_agent

get or create a LWP user agent

=cut

    my ( $self, %args ) = @_;
    unless ( $self->{'user_agent'} ) {
        $self->{'user_agent'} = LWP::UserAgent->new;
        $self->{'user_agent'}->agent("CMap_Editor/0.1 ");
        unless ( $self->authenticate_user_agent() ) {
            print STDERR "Failed to give a correct login.  Exiting...\n";
            exit;
        }
    }
    return $self->{'user_agent'};

}

# ----------------------------------------------------
sub authenticate_user_agent {

=pod

=head2 authenticate_user_agent

=cut

    my ( $self, %args ) = @_;
    if ( $self->{'user_agent'} ) {
        my $req = HTTP::Request->new( GET => $self->{'remote_url'} );
        $req->content_type('application/x-www-form-urlencoded');
        $req->content('query=libwww-perl&mode=dist');

        # Pass request to the user agent and get a response back
        my $res = $self->{'user_agent'}->request($req);

        # Check the outcome of the response
        if ( $res->is_success ) {
            return 1;
        }
        elsif ( $res->status_line() =~ /401/ ) {
            my $res_header = $res->header('WWW-Authenticate');
            my ( $user, $password )
                = $self->{'app_controller'}->app_interface()->password_box();
            unless ( defined $user ) {
                return 0;
            }
            $self->give_user_agent_credentials(
                user       => $user,
                password   => $password,
                res_header => $res_header,
            );
            return $self->authenticate_user_agent();
        }
        else {
        }
    }
    return undef;

}

# ----------------------------------------------------
sub give_user_agent_credentials {

=pod

=head2 give_user_agent_credentials

=cut

    my ( $self, %args ) = @_;
    if ( $self->{'user_agent'} ) {
        my $user       = $args{'user'};
        my $password   = $args{'password'};
        my $res_header = $args{'res_header'};
        my $url        = $self->{'remote_url'};

        my ( $service, $port_num, );
        if ( $url =~ m{\w+://([^/:]+):?(\d+)?} ) {
            $service = $1;
            $port_num = $2 || 80;
        }
        else {
            die "URL $url did not parse correctly\n";
        }

        my $realm = '';
        if ( $res_header =~ /realm="([^"]+)"/ ) {
            $realm = $1;
        }

        $self->{'user_agent'}->credentials( $service . ":" . $port_num,
            $realm, $user => $password, );

    }
    return;
}

# ----------------------------------------------------
sub request_remote_data {

=pod

=head2 request_remote_data

Does the actual call for the data

=cut

    my ( $self, %args ) = @_;
    my $url       = $args{'url'};
    my $want_hash = $args{'want_hash'} || 0;
    my $thaw      = $args{'thaw'};

    # Create a request
    my $req = HTTP::Request->new( GET => $url );
    $req->content_type('application/x-www-form-urlencoded');
    $req->content('query=libwww-perl&mode=dist');

    # Pass request to the user agent and get a response back
    my $res = $self->user_agent()->request($req);

    # Check the outcome of the response
    if ( $res->is_success ) {
        if ( my $content = $res->content ) {
            return $thaw ? thaw($content) : $content;
        }
        else {
            return $want_hash ? {}
                : $thaw       ? []
                : '';
        }
    }
    else {
        print STDERR $res->status_line, "\n";
        return $want_hash ? {}
            : $thaw       ? []
            : '';
    }
}

# ----------------------------------------------------
sub stringify_slot_info {

=pod

=head2 stringify_slot_info

Turn a slot_info object into a url string

  Structure:
    {
        map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ],
    }

  URL Structure
    ;param_name=:map_id*current_start*current_stop*ori_start*ori_stop*magnification

=cut

    my ( $self, %args ) = @_;
    my $slot_info  = $args{'slot_info'};
    my $param_name = $args{'param_name'};

    my $return_str = ";$param_name=";

    foreach my $map_id ( keys %{ $slot_info || {} } ) {
        $return_str .= ":$map_id*" . join "*",
            map { defined($_) ? $_ : q{} } @{ $slot_info->{$map_id} || [] };
    }

    return $return_str;
}

# ----------------------------------------------------
sub sql_get_maps {

=pod

=head2 sql_get_maps

Calls get_maps either locally or remotely

=cut

    my ( $self, %args ) = @_;
    my $map_id   = $args{'map_id'};
    my $map_ids  = $args{'map_ids'};
    my $map_accs = $args{'map_accs'};

    if ( my $url = $self->{'remote_url'} ) {
        $url .= ';action=get_maps';

        if ($map_id) {
            $url .= ";map_id=$map_id";
        }
        elsif ( @{ $map_ids || [] } ) {
            $url .= ";map_id=$_" foreach @{$map_ids};
        }

        if ( @{ $map_accs || [] } ) {
            $url .= ";map_accs=$_" foreach @{$map_accs};
        }

        return $self->request_remote_data( url => $url, thaw => 1, );
    }
    else {
        return $self->sql()->get_maps(
            cmap_object => $self,
            map_id      => $map_id,
            map_ids     => $map_ids,
            map_accs    => $map_accs,
            )
            || [];
    }

}

# ----------------------------------------------------
sub sql_get_features_sub_maps_version {

=pod

=head2 sql_get_features_sub_maps_version

Calls get_features_sub_maps_version either locally or remotely

=cut

    my ( $self, %args ) = @_;
    my $map_id       = $args{'map_id'};
    my $no_sub_maps  = $args{'no_sub_maps'};
    my $get_sub_maps = $args{'get_sub_maps'};

    if ( my $url = $self->{'remote_url'} ) {
        $url .= ';action=get_features_sub_maps_version';

        if ($map_id) {
            $url .= ";map_id=$map_id";
        }
        if ($no_sub_maps) {
            $url .= ";no_sub_maps=$no_sub_maps";
        }
        if ($get_sub_maps) {
            $url .= ";get_sub_maps=$get_sub_maps";
        }

        return $self->request_remote_data( url => $url, thaw => 1, );
    }
    else {
        return $self->sql()->get_features_sub_maps_version(
            cmap_object  => $self,
            map_id       => $map_id,
            no_sub_maps  => $no_sub_maps,
            get_sub_maps => $get_sub_maps,
            )
            || [];
    }

}

# ----------------------------------------------------
sub sql_get_feature_correspondence_for_counting {

=pod

=head2 sql_get_feature_correspondence_for_counting

Calls get_feature_correspondence_for_counting either locally or remotely

=cut

    my ( $self, %args ) = @_;
    my $slot_info      = $args{'slot_info'};
    my $slot_info2     = $args{'slot_info2'};
    my $allow_intramap = $args{'allow_intramap'} || 0;

    if ( my $url = $self->{'remote_url'} ) {
        $url .= ';action=get_feature_correspondence_for_counting;'
            . 'allow_intramap='
            . $allow_intramap . ';';
        $url .= $self->stringify_slot_info(
            slot_info  => $slot_info,
            param_name => 'slot_info',
        );
        $url .= $self->stringify_slot_info(
            slot_info  => $slot_info2,
            param_name => 'slot_info2',
        );

        return $self->request_remote_data( url => $url, thaw => 1, );
    }
    else {
        return $self->sql()->get_feature_correspondence_for_counting(
            cmap_object    => $self,
            slot_info      => $slot_info,
            slot_info2     => $slot_info2,
            allow_intramap => $allow_intramap,
            )
            || [];
    }

}

# ----------------------------------------------------
sub sql_get_species {

=pod

=head2 sql_get_species

Calls get_species either locally or remotely

=cut

    my ( $self, %args ) = @_;
    my $is_relational_map = $args{'is_relational_map'};
    my $is_enabled        = $args{'is_enabled'};

    if ( my $url = $self->{'remote_url'} ) {
        $url .= ';action=get_species';

        if ( defined $is_relational_map ) {
            $url .= ";is_relational_map=$is_relational_map";
        }
        if ( defined $is_enabled ) {
            $url .= ";is_enabled=$is_enabled";
        }

        return $self->request_remote_data( url => $url, thaw => 1, );
    }
    else {
        return $self->sql()->get_species(
            cmap_object       => $self,
            is_relational_map => $is_relational_map,
            is_enabled        => $is_enabled,
            )
            || [];
    }

}

# ----------------------------------------------------
sub sql_get_map_sets {

=pod

=head2 sql_get_map_sets

Calls get_map_sets either locally or remotely

=cut

    my ( $self, %args ) = @_;
    my $species_id        = $args{'species_id'};
    my $map_set_id        = $args{'map_set_id'};
    my $is_relational_map = $args{'is_relational_map'};
    my $is_enabled        = $args{'is_enabled'};

    if ( my $url = $self->{'remote_url'} ) {
        $url .= ';action=get_map_sets';

        if ($species_id) {
            $url .= ";species_id=$species_id";
        }
        if ($map_set_id) {
            $url .= ";map_set_id=$map_set_id";
        }
        if ( defined $is_relational_map ) {
            $url .= ";is_relational_map=$is_relational_map";
        }
        if ( defined $is_enabled ) {
            $url .= ";is_enabled=$is_enabled";
        }

        return $self->request_remote_data( url => $url, thaw => 1, );
    }
    else {
        return $self->sql()->get_map_sets(
            cmap_object       => $self,
            species_id        => $species_id,
            map_set_id        => $map_set_id,
            is_relational_map => $is_relational_map,
            is_enabled        => $is_enabled,
            )
            || [];
    }

}

# ----------------------------------------------------
sub sql_get_maps_from_map_set {

=pod

=head2 sql_get_maps_from_map_set

Calls get_maps_from_map_set either locally or remotely

=cut

    my ( $self, %args ) = @_;
    my $map_set_id = $args{'map_set_id'};

    if ( my $url = $self->{'remote_url'} ) {
        $url .= ';action=get_maps_from_map_set';

        if ($map_set_id) {
            $url .= ";map_set_id=$map_set_id";
        }

        return $self->request_remote_data( url => $url, thaw => 1, );
    }
    else {
        return $self->sql()->get_maps_from_map_set(
            cmap_object => $self,
            map_set_id  => $map_set_id,
            )
            || [];
    }

}

# ----------------------------------------------------
sub sql_commit_changes {

=pod

=head2 sql_update_features

Update the db.

=cut

    my ( $self, %args ) = @_;
    my $actions = $args{'actions'} or return;

    if ( my $url = $self->{'remote_url'} ) {
        $url .= ';action=commit_changes';

        $url .= ';change_actions=' . nfreeze($actions);

        return $self->request_remote_data( url => $url, thaw => 0, );
    }
    else {
        my $admin = Bio::GMOD::CMap::Admin->new(
            data_source => $self->data_source() );
        $admin->commit_changes($actions);
    }

}

# ----------------------------------------------------
sub sql_update_features {

=pod

=head2 sql_update_features

Update the features table in the db.

Data Structures:

  $features = [{
    feature_id       => $sub_map_feature_id,
    map_id           => $opt_new_parent_map_id,
    feature_start    => $opt_new_feature_start, 
    feature_stop     => $opt_new_feature_stop, 
    feature_acc      => $opt_new_feature_acc,
    feature_type_acc => $opt_new_feature_type_acc,
    feature_name     => $opt_new_feature_name,
    is_landmark      => $opt_new_is_landmark,
    feature_start    => $opt_new_feature_start,
    feature_stop     => $opt_new_feature_stop,
    default_rank     => $opt_new_default_rank,
    direction        => $opt_new_direction,
  },];

=cut

    my ( $self, %args ) = @_;
    my $features = $args{'features'} or return;

    my %component_shorthand = (
        feature_id       => 'id',
        map_id           => 'map_id',
        feature_acc      => 'acc',
        feature_type_acc => 'type_acc',
        feature_name     => 'name',
        is_landmark      => 'is_landmark',
        feature_start    => 'start',
        feature_stop     => 'stop',
        default_rank     => 'rank',
        direction        => 'dir',
    );

    if ( my $url = $self->{'remote_url'} ) {
        $url .= ';action=update_features';

        my @feature_str_array;
        foreach my $feature ( @{$features} ) {
            my @components;
            unless ( $feature->{'feature_id'} ) {
                next;
            }
            push @components, $component_shorthand{'feature_id'} . ','
                . $feature->{'feature_id'};
            foreach my $component_name (
                qw[
                map_id
                feature_acc
                feature_type_acc
                feature_name
                is_landmark
                feature_start
                feature_stop
                default_rank
                direction
                ]
                )
            {

                if ( defined $feature->{$component_name} ) {
                    push @components,
                        $component_shorthand{$component_name} . ','
                        . $feature->{$component_name};
                }
            }
            push @feature_str_array, join( ',', @components );
        }
        my $feature_str = join( ':', @feature_str_array, );
        return unless ($feature_str);

        $url .= ';feature_str=' . $feature_str;

        return $self->request_remote_data( url => $url, thaw => 0, );
    }
    else {
        foreach my $feature ( @{$features} ) {
            unless ( $feature->{'feature_id'} ) {
                next;
            }
            $self->sql()->update_feature(
                cmap_object      => $self,
                feature_id       => $feature->{'feature_id'},
                map_id           => $feature->{'map_id'},
                feature_acc      => $feature->{'feature_acc'},
                feature_type_acc => $feature->{'feature_type_acc'},
                feature_name     => $feature->{'feature_name'},
                is_landmark      => $feature->{'is_landmark'},
                feature_start    => $feature->{'feature_start'},
                feature_stop     => $feature->{'feature_stop'},
                default_rank     => $feature->{'default_rank'},
                direction        => $feature->{'direction'},
            );
        }
    }

}

# ----------------------------------------------------
sub commit_changes {

=pod

=head2 commit_changes

=cut

    my ( $self, %args ) = @_;
    my $actions = $args{'actions'} or return;

    $self->sql_commit_changes( actions => $actions, );

    return;
}

# ----------------------------------------------------
sub commit_sub_map_moves {

=pod

=head2 commit_sub_map_moves

Data Structure

  $features = [{
    feature_id             => $sub_map_feature_id,
    sub_map_id             => $sub_map_id,
    original_parent_map_id => $original_parent_map_id,
    map_id                 => $new_parent_map_id,
    feature_start          => $new_feature_start, 
    feature_stop           => $new_feature_stop, 
  },];

=cut

    my ( $self, %args ) = @_;
    my $features = $args{'features'} or return;

    foreach my $feature (@$features) {
        $self->{'sub_map_data'}{ $feature->{'map_id'} } = undef;
        $self->{'sub_map_data'}{ $feature->{'original_parent_map_id'} }
            = undef;
    }
    $self->sql_update_features( features => $features, );

    return;
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

