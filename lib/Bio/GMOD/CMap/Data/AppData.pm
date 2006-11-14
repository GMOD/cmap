package Bio::GMOD::CMap::Data::AppData;

# vim: set ft=perl:

# $Id: AppData.pm,v 1.10 2006-11-14 14:37:09 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.10 $)[-1];

use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use LWP::UserAgent;
use Storable qw(freeze thaw);
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use base 'Bio::GMOD::CMap::Data';

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
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

=pod

=head2 get_remote_config

Given a map accessions, return the information required to draw the
map.

=cut

sub get_remote_config {

    my ( $self, %args ) = @_;

    my $config = undef;
    if ( my $url = $self->{'remote_url'} ) {
        $url .= ';action=get_config';
        $config = $self->request_remote_data( $url, 'want_hash' );
    }

    return $config;

}

# ----------------------------------------------------

=pod

=head2 map_data

Given a map accessions, return the information required to draw the
map.

=cut

sub map_data {

    my ( $self, %args ) = @_;
    my $map_id = $args{'map_id'} or return undef;

    unless ( $self->{'map_data'}{$map_id} ) {

        my $maps = $self->sql_get_maps( map_id => $map_id, )
            || [];
        if (@$maps) {
            $self->{'map_data'}{$map_id} = $maps->[0];
        }
        else {
            return undef;
        }
    }

    return $self->{'map_data'}{$map_id};
}

# ----------------------------------------------------

=pod

=head2 map_data_array

Given a list of map accessions, return the information required to draw the
map as an array.

=cut

sub map_data_array {

    my ( $self, %args ) = @_;
    my $map_ids = $args{'map_ids'} || [];

    return undef unless (@$map_ids);

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

    if (@new_map_ids) {
        my $new_maps = $self->sql_get_maps( map_ids => \@new_map_ids, )
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

=pod

=head2 map_data_hash

Given a list of map accessions, return the information required to draw the
map as a hash.

=cut

sub map_data_hash {

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

=pod

=head2 feature_data

Given a map accessions, return the information required to draw the
features.  These do NOT include the sub-maps.

=cut

sub feature_data {

    my ( $self, %args ) = @_;
    my $map_id = $args{'map_id'} or return undef;

    unless ( $self->{'feature_data'}{$map_id} ) {

        my $features = $self->sql_get_features_sub_maps_version(
            cmap_object => $self,
            map_id      => $map_id,
            no_sub_maps => 1,
            )
            || [];
        if (@$features) {
            $self->{'feature_data'}{$map_id} = $features;
        }
        else {
            return undef;
        }
    }

    return $self->{'feature_data'}{$map_id};
}

# ----------------------------------------------------

=pod

=head2 sub_maps

Given a map id, return the information required to draw the
sub-maps.  These do NOT include the regular features;

=cut

sub sub_maps {

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

=pod

=head2 sorted_feature_data

Given a map accessions, return the information required to draw the
features.  These do NOT include the sub-maps.

=cut

sub sorted_feature_data {

    my ( $self, %args ) = @_;
    my $map_id = $args{'map_id'} or return undef;

    unless ( $self->{'sorted_feature_data'}{$map_id} ) {

        my $features = $self->feature_data( map_id => $map_id, )
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

=pod

=head2 slot_correspondences

Given a map id, return the information required to draw the
sub-maps.  These do NOT include the regular features;

Takes two slot_infos which are defined as:

 Structure:
    {
        map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ],
    }

Requires slot_key1 to be less than slot_key2.

=cut

sub slot_correspondences {

    my ( $self, %args ) = @_;
    my $slot_key1  = $args{'slot_key1'}  or return undef;
    my $slot_key2  = $args{'slot_key2'}  or return undef;
    my $slot_info1 = $args{'slot_info1'} or return undef;
    my $slot_info2 = $args{'slot_info2'} or return undef;

    if ( $slot_key1 > $slot_key2 ) {
        die "AppData->slot_correspondences called with slot1 > slot2\n";
    }
    my $cache_key = md5_hex( Dumper( $slot_info1, $slot_info2 ) );

    unless ($self->{'slot_corr_data'}{$slot_key1}{$slot_key2}
        and $self->{'slot_corr_data'}{$slot_key1}{$slot_key2}{'cache_key'} eq
        $cache_key )
    {

        my $corrs = $self->sql_get_feature_correspondence_for_counting(
            slot_info  => $slot_info1,
            slot_info2 => $slot_info2,
            )
            || [];
        $self->{'slot_corr_data'}{$slot_key1}{$slot_key2}{'corrs'} = $corrs;
        $self->{'slot_corr_data'}{$slot_key1}{$slot_key2}{'cache_key'}
            = $cache_key;
    }

    return $self->{'slot_corr_data'}{$slot_key1}{$slot_key2}{'corrs'};
}

# ----------------------------------------------------

=pod

=head2 get_reference_maps_by_species

Returns information about all possible reference maps.

=cut

sub get_reference_maps_by_species {

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

=pod

=head2 user_agent

get or create a LWP user agent

=cut

sub user_agent {

    my ( $self, %args ) = @_;
    unless ( $self->{'user_agent'} ) {
        $self->{'user_agent'} = LWP::UserAgent->new;
        $self->{'user_agent'}->agent("CMap_Editor/0.1 ");
    }
    return $self->{'user_agent'};

}

# ----------------------------------------------------

=pod

=head2 request_remote_data

Does the actual call for the data

=cut

sub request_remote_data {

    my ( $self, $url, $want_hash ) = @_;

    # Create a request
    my $req = HTTP::Request->new( GET => $url );
    $req->content_type('application/x-www-form-urlencoded');
    $req->content('query=libwww-perl&mode=dist');

    # Pass request to the user agent and get a response back
    my $res = $self->user_agent()->request($req);

    # Check the outcome of the response
    if ( $res->is_success ) {
        if ( my $content = $res->content ) {
            return thaw($content);
        }
        else {
            return $want_hash ? {} : [];
        }
    }
    else {
        print STDERR $res->status_line, "\n";
        return $want_hash ? {} : [];
    }
}

# ----------------------------------------------------

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

sub stringify_slot_info {

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

=pod

=head2 sql_get_maps

Calls get_maps either locally or remotely

=cut

sub sql_get_maps {

    my ( $self, %args ) = @_;
    my $map_id  = $args{'map_id'};
    my $map_ids = $args{'map_ids'};

    if ( my $url = $self->{'remote_url'} ) {
        $url .= ';action=get_maps';

        if ($map_id) {
            $url .= ";map_id=$map_id";
        }
        elsif ( @{ $map_ids || [] } ) {
            $url .= ";map_id=$_" foreach @{$map_ids};
        }

        return $self->request_remote_data($url);
    }
    else {
        return $self->sql()->get_maps(
            cmap_object => $self,
            map_id      => $map_id,
            map_ids     => $map_ids,
            )
            || [];
    }

}

# ----------------------------------------------------

=pod

=head2 sql_get_features_sub_maps_version

Calls get_features_sub_maps_version either locally or remotely

=cut

sub sql_get_features_sub_maps_version {

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

        return $self->request_remote_data($url);
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

=pod

=head2 sql_get_feature_correspondence_for_counting

Calls get_feature_correspondence_for_counting either locally or remotely

=cut

sub sql_get_feature_correspondence_for_counting {

    my ( $self, %args ) = @_;
    my $slot_info  = $args{'slot_info'};
    my $slot_info2 = $args{'slot_info2'};

    if ( my $url = $self->{'remote_url'} ) {
        $url .= ';action=get_feature_correspondence_for_counting';
        $url .= $self->stringify_slot_info(
            slot_info  => $slot_info,
            param_name => 'slot_info',
        );
        $url .= $self->stringify_slot_info(
            slot_info  => $slot_info2,
            param_name => 'slot_info2',
        );

        return $self->request_remote_data($url);
    }
    else {
        return $self->sql()->get_feature_correspondence_for_counting(
            cmap_object => $self,
            slot_info   => $slot_info,
            slot_info2  => $slot_info2,
            )
            || [];
    }

}

# ----------------------------------------------------

=pod

=head2 sql_get_species

Calls get_species either locally or remotely

=cut

sub sql_get_species {

    my ( $self, %args ) = @_;
    my $is_relational_map = $args{'is_relational_map'};
    my $is_enabled        = $args{'is_enabled'};

    if ( my $url = $self->{'remote_url'} ) {
        $url .= ';action=get_species';

        if (defined $is_relational_map) {
            $url .= ";is_relational_map=$is_relational_map";
        }
        if (defined $is_enabled) {
            $url .= ";is_enabled=$is_enabled";
        }

        return $self->request_remote_data($url);
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

=pod

=head2 sql_get_map_sets

Calls get_map_sets either locally or remotely

=cut

sub sql_get_map_sets {

    my ( $self, %args ) = @_;
    my $species_id        = $args{'species_id'};
    my $is_relational_map = $args{'is_relational_map'};
    my $is_enabled        = $args{'is_enabled'};

    if ( my $url = $self->{'remote_url'} ) {
        $url .= ';action=get_map_sets';

        if ($species_id) {
            $url .= ";species_id=$species_id";
        }
        if (defined $is_relational_map) {
            $url .= ";is_relational_map=$is_relational_map";
        }
        if (defined $is_enabled) {
            $url .= ";is_enabled=$is_enabled";
        }

        return $self->request_remote_data($url);
    }
    else {
        return $self->sql()->get_map_sets(
            cmap_object       => $self,
            species_id        => $species_id,
            is_relational_map => $is_relational_map,
            is_enabled        => $is_enabled,
            )
            || [];
    }

}

# ----------------------------------------------------

=pod

=head2 sql_get_maps_from_map_set

Calls get_maps_from_map_set either locally or remotely

=cut

sub sql_get_maps_from_map_set {

    my ( $self, %args ) = @_;
    my $map_set_id = $args{'map_set_id'};

    if ( my $url = $self->{'remote_url'} ) {
        $url .= ';action=get_maps_from_map_set';

        if ($map_set_id) {
            $url .= ";map_set_id=$map_set_id";
        }

        return $self->request_remote_data($url);
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

=pod

=head2 move_sub_map_in_memory

Given a map id, return the information required to draw the
sub-maps.  These do NOT include the regular features;

=cut

sub move_sub_maps_in_memory {

    my ( $self, %args ) = @_;
    my $map_id = $args{'map_id'} or return undef;

    if ( $self->{'sub_map_data'}{$map_id} ) {
#
#            $self->{'sub_map_data'}{$map_id} = $features;
#        }
#        else {
#            return undef;
#        }
    }

    return $self->{'sub_map_data'}{$map_id};
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

