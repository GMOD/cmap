package Bio::GMOD::CMap::Data::AppData;

# vim: set ft=perl:

# $Id: AppData.pm,v 1.1 2006-02-05 04:17:59 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Data::AppData - draw maps 

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Data::AppData;
  my $data = Bio::GMOD::CMap::Data::AppData();
  $data->image_name;

=head1 DESCRIPTION

The base map drawing module.

=head1 Usage

    my $data = Bio::GMOD::CMap::Data::AppData->new(
    );

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.1 $)[-1];

use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use Data::Dumper;
use base 'Bio::GMOD::CMap::Data';

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->config( $config->{'config'} );
    $self->data_source( $config->{'data_source'} );
    $self->aggregate( $config->{'aggregate'} );
    $self->cluster_corr( $config->{'cluster_corr'} );
    $self->show_intraslot_corr( $config->{'show_intraslot_corr'} );
    $self->split_agg_ev( $config->{'split_agg_ev'} );
    $self->ref_map_order( $config->{'ref_map_order'} );
    $self->comp_menu_order( $config->{'comp_menu_order'} );

    return $self;
}

# ----------------------------------------------------

=pod

=head2 set_data

Organizes the data for drawing comparative maps.

=cut

sub set_data {

    #p#rint S#TDERR "set_data\n";
    my ( $self, %args ) = @_;
    my $slots                      = $args{'slots'};
    my $slots_min_corrs            = $args{'slots_min_corrs'} || {};
    my $included_feature_type_accs = $args{'included_feature_type_accs'}
        || [];
    my $corr_only_feature_type_accs = $args{'corr_only_feature_type_accs'}
        || [];
    my $ignored_feature_type_accs = $args{'ignored_feature_type_accs'} || [];
    my $url_feature_default_display = $args{'url_feature_default_display'};
    my $ignored_evidence_type_accs  = $args{'ignored_evidence_type_accs'}
        || [];
    my $included_evidence_type_accs = $args{'included_evidence_type_accs'}
        || [];
    my $less_evidence_type_accs = $args{'less_evidence_type_accs'} || [];
    my $greater_evidence_type_accs = $args{'greater_evidence_type_accs'}
        || [];
    my $evidence_type_score = $args{'evidence_type_score'} || {};
    my $pid                 = $$;

    $self->fill_type_arrays(
        included_feature_type_accs  => $included_feature_type_accs,
        corr_only_feature_type_accs => $corr_only_feature_type_accs,
        ignored_feature_type_accs   => $ignored_feature_type_accs,
        url_feature_default_display => $url_feature_default_display,
        ignored_evidence_type_accs  => $ignored_evidence_type_accs,
        included_evidence_type_accs => $included_evidence_type_accs,
        less_evidence_type_accs     => $less_evidence_type_accs,
        greater_evidence_type_accs  => $greater_evidence_type_accs,
    );

    my ($data,                      %feature_correspondences,
        %intraslot_correspondences, %map_correspondences,
        %correspondence_evidence,   %feature_types,
        %map_type_accs
    );
    $self->slot_info(
        $slots,                       $ignored_feature_type_accs,
        $included_evidence_type_accs, $less_evidence_type_accs,
        $greater_evidence_type_accs,  $evidence_type_score,
        $slots_min_corrs,
        )
        or return;
    $self->update_slots( $slots, $slots_min_corrs, );

    my @slot_nos         = keys %$slots;
    my @pos              = sort { $a <=> $b } grep { $_ >= 0 } @slot_nos;
    my @neg              = sort { $b <=> $a } grep { $_ < 0 } @slot_nos;
    my @ordered_slot_nos = ( @pos, @neg );
    for my $slot_no (@ordered_slot_nos) {
        my $cur_map     = $slots->{$slot_no};
        my $ref_slot_no =
              $slot_no == 0 ? undef
            : $slot_no > 0  ? $slot_no - 1
            : $slot_no + 1;
        my $ref_map = defined $ref_slot_no ? $slots->{$ref_slot_no} : undef;

        $data->{'slot_data'}{$slot_no} = $self->slot_data(
            map                       => \$cur_map,                     # pass
            feature_correspondences   => \%feature_correspondences,     # by
            intraslot_correspondences => \%intraslot_correspondences,   #
            map_correspondences       => \%map_correspondences,         # ref
            correspondence_evidence   => \%correspondence_evidence,     # "
            feature_types             => \%feature_types,               # "
            reference_map             => $ref_map,
            slot_no                   => $slot_no,
            ref_slot_no               => $ref_slot_no,

            #min_correspondences         => $min_correspondences,
            included_feature_type_accs  => $included_feature_type_accs,
            corr_only_feature_type_accs => $corr_only_feature_type_accs,
            ignored_feature_type_accs   => $ignored_feature_type_accs,
            ignored_evidence_type_accs  => $ignored_evidence_type_accs,
            included_evidence_type_accs => $included_evidence_type_accs,
            less_evidence_type_accs     => $less_evidence_type_accs,
            greater_evidence_type_accs  => $greater_evidence_type_accs,
            evidence_type_score         => $evidence_type_score,
            pid                         => $pid,
            map_type_accs               => \%map_type_accs,
            )
            or last;

        #Set the map order for this slot
        $self->sorted_map_ids( $slot_no, $data->{'slot_data'}{$slot_no} );

    }
    ###Get the extra javascript that goes along with the feature_types.
    ### and get extra forms
    my ( $extra_code, $extra_form );
    ( $extra_code, $extra_form )
        = $self->get_web_page_extras( \%feature_types, \%map_type_accs,
        $extra_code, $extra_form );

    #
    # Allow only one correspondence evidence per (the top-most ranking).
    #
    for my $fc_id ( keys %correspondence_evidence ) {
        my @evidence =
            sort { $a->{'evidence_rank'} <=> $b->{'evidence_rank'} }
            @{ $correspondence_evidence{$fc_id} };
        $correspondence_evidence{$fc_id} = $evidence[0];
    }

    $data->{'correspondences'}             = \%feature_correspondences;
    $data->{'intraslot_correspondences'}   = \%intraslot_correspondences;
    $data->{'map_correspondences'}         = \%map_correspondences;
    $data->{'correspondence_evidence'}     = \%correspondence_evidence;
    $data->{'feature_types'}               = \%feature_types;
    $data->{'included_feature_type_accs'}  = $included_feature_type_accs;
    $data->{'corr_only_feature_type_accs'} = $corr_only_feature_type_accs;
    $data->{'ignored_feature_type_accs'}   = $ignored_feature_type_accs;
    $data->{'included_evidence_type_accs'} = $included_evidence_type_accs;
    $data->{'ignored_evidence_type_accs'}  = $ignored_evidence_type_accs;
    $data->{'less_evidence_type_accs'}     = $less_evidence_type_accs;
    $data->{'greater_evidence_type_accs'}  = $greater_evidence_type_accs;
    $data->{'evidence_type_score'}         = $evidence_type_score;
    $data->{'extra_code'}                  = $extra_code;
    $data->{'extra_form'}                  = $extra_form;
    $data->{'max_unit_size'}
        = $self->get_max_unit_size( $data->{'slot_data'} );
    $data->{'ref_unit_size'}
        = $self->get_ref_unit_size( $data->{'slot_data'} );
    $data->{'feature_default_display'}
        = $self->feature_default_display($url_feature_default_display);

    return ( $data, $slots );
}

# ----------------------------------------------------

=pod

=head2 map_data

Given a list of map accessions, return the information required to draw the
map.

=cut

sub map_data {

    my ( $self, %args ) = @_;
    my $map_accs = $args{'map_accs'} || [];

    return undef unless (@$map_accs);

    my $sql_object = $self->sql();

    # Get all species first
    my $maps = $sql_object->get_maps(
        cmap_object => $self,
        map_accs    => $map_accs,
        )
        || [];

    foreach my $map (@$maps) {
        $map->{features} = $sql_object->get_features(
            cmap_object => $self,
            map_id      => $map->{'map_id'},
            )
            || [];
    }

    return $maps;
}

# ----------------------------------------------------

=pod

=head2 get_reference_maps

Returns information about all possible reference maps.

=cut

sub get_reference_maps {

    my ( $self, %args ) = @_;
    my $sql_object = $self->sql();

    # Get all species first
    my $ref_species = $sql_object->get_species(
        cmap_object       => $self,
        is_relational_map => 0,
        is_enabled        => 1,
    );

    foreach my $species ( @{ $ref_species || [] } ) {
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

    return $ref_species;

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

