package Bio::GMOD::CMap::Data::AppData;

# vim: set ft=perl:

# $Id: AppData.pm,v 1.2 2006-03-14 22:16:21 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.2 $)[-1];

use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use Data::Dumper;
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
    my $map_acc = $args{'map_acc'} or return undef;

    my $sql_object = $self->sql();

    unless ( $self->{'map_data'}{$map_acc} ) {

        my $maps = $sql_object->get_maps(
            cmap_object => $self,
            map_acc     => $map_acc,
            )
            || [];
        if (@$maps) {
            $self->{'map_data'}{$map_acc} = $maps->[0];
        }
        else {
            return undef;
        }
    }

    return $self->{'map_data'}{$map_acc};
}

# ----------------------------------------------------

=pod

=head2 map_data_array

Given a list of map accessions, return the information required to draw the
map.

=cut

sub map_data_array {

    my ( $self, %args ) = @_;
    my $map_accs = $args{'map_accs'} || [];

    return undef unless (@$map_accs);

    my $sql_object = $self->sql();

    my @map_data;
    my @new_map_accs;
    foreach my $map_acc (@$map_accs) {
        if ( $self->{'map_data'}{$map_acc} ) {
            push @map_data, $self->{'map_data'}{$map_acc};
        }
        else {
            push @new_map_accs, $map_acc;
        }
    }

    if (@new_map_accs) {
        my $new_maps = $sql_object->get_maps(
            cmap_object => $self,
            map_accs    => \@new_map_accs,
            )
            || [];

        foreach my $new_map (@$new_maps) {
            $self->{'map_data'}{ $new_map->{'map_acc'} } = $new_map;
        }

        push @map_data, (@$new_maps);
    }

    @map_data
        = sort { $a->{'display_order'} <=> $b->{'display_order'} } @map_data;

    return \@map_data;
}

# ----------------------------------------------------

=pod

=head2 feature_data

Given a map accessions, return the information required to draw the
features.  These do NOT include the sub-maps.

=cut

sub feature_data {

    my ( $self, %args ) = @_;
    my $map_acc = $args{'map_acc'} or return undef;

    my $sql_object = $self->sql();

    unless ( $self->{'feature_data'}{$map_acc} ) {

        my $features = $sql_object->get_features_sub_maps_version(
            cmap_object => $self,
            map_acc     => $map_acc,
            no_sub_maps => 1,
            )
            || [];
        if (@$features) {
            $self->{'feature_data'}{$map_acc} = $features;
        }
        else {
            return undef;
        }
    }

    return $self->{'feature_data'}{$map_acc};
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
                species_acc       => $species->{'species_acc'},
                is_relational_map => 0,
                is_enabled        => 1,
            );
            foreach my $map_set ( @{ $species->{'map_sets'} || [] } ) {
                $map_set->{'maps'} = $sql_object->get_maps_from_map_set(
                    cmap_object => $self,
                    map_set_acc => $map_set->{'map_set_acc'},
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

