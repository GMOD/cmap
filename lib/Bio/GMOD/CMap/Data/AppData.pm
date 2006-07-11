package Bio::GMOD::CMap::Data::AppData;

# vim: set ft=perl:

# $Id: AppData.pm,v 1.6 2006-07-11 19:15:31 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.6 $)[-1];

use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use base 'Bio::GMOD::CMap::Data';

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->config( $config->{'config'} );
    $self->data_source( $config->{'data_source'} );

    return $self;
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

    my $sql_object = $self->sql();

    unless ( $self->{'map_data'}{$map_id} ) {

        my $maps = $sql_object->get_maps(
            cmap_object => $self,
            map_id      => $map_id,
            )
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

    my $sql_object = $self->sql();

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
        my $new_maps = $sql_object->get_maps(
            cmap_object => $self,
            map_ids     => \@new_map_ids,
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

=pod

=head2 map_data_hash

Given a list of map accessions, return the information required to draw the
map as a hash.

=cut

sub map_data_hash {

    my ( $self, %args ) = @_;
    my $map_ids = $args{'map_ids'} || [];

    return undef unless (@$map_ids);

    my $sql_object = $self->sql();

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
        my $new_maps = $sql_object->get_maps(
            cmap_object => $self,
            map_ids     => \@new_map_ids,
            )
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

    my $sql_object = $self->sql();

    unless ( $self->{'feature_data'}{$map_id} ) {

        my $features = $sql_object->get_features_sub_maps_version(
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

    my $sql_object = $self->sql();

    unless ( $self->{'sub_map_data'}{$map_id} ) {

        my $features = $sql_object->get_features_sub_maps_version(
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

    my $sql_object = $self->sql();

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
                push @{ $sorting_hash{ $this_feature_type_data->{
                            'drawing_lane'} }
                        ->{ $this_feature_type_data->{'drawing_priority'} } },
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
    my $sql_object = $self->sql();
    my $cache_key  = md5_hex( Dumper( $slot_info1, $slot_info2 ) );

    unless ($self->{'slot_corr_data'}{$slot_key1}{$slot_key2}
        and $self->{'slot_corr_data'}{$slot_key1}{$slot_key2}{'cache_key'} eq
        $cache_key )
    {

        my $corrs = $sql_object->get_feature_correspondence_for_counting(
            cmap_object => $self,
            slot_info   => $slot_info1,
            slot_info2  => $slot_info2,
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

        my $sql_object = $self->sql();

        # Get all species first
        $self->{'reference_maps_by_species'} = $sql_object->get_species(
            cmap_object       => $self,
            is_relational_map => 0,
            is_enabled        => 1,
        );

        foreach
            my $species ( @{ $self->{'reference_maps_by_species'} || [] } )
        {
            $species->{'map_sets'} = $sql_object->get_map_sets(
                cmap_object       => $self,
                species_id        => $species->{'species_id'},
                is_relational_map => 0,
                is_enabled        => 1,
            );
            foreach my $map_set ( @{ $species->{'map_sets'} || [] } ) {
                $map_set->{'maps'} = $sql_object->get_maps_from_map_set(
                    cmap_object => $self,
                    map_set_id  => $map_set->{'map_set_id'},
                );
            }
        }

    }
    return $self->{'reference_maps_by_species'};
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

