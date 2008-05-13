package Bio::GMOD::CMap::Admin::GFFProducer;

# vim: set ft=perl:

# $Id: GFFProducer.pm,v 1.1 2008-05-13 20:48:29 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Admin::GFFProducer - import alignments such as BLAST

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::GFFProducer;
  my $gff_producer = Bio::GMOD::CMap::Admin::GFFProducer->new;
  $gff_producer->export() or return $gff_producer->error;

=head1 DESCRIPTION

This module encapsulates the logic for exporting the cmap data in GFF3 format
(cmap-gff-version 1).

=cut

use strict;
use vars qw( $VERSION %COLUMNS $LOG_FH );
$VERSION = (qw$Revision: 1.1 $)[-1];

use Data::Dumper;
use Bio::GMOD::CMap;
use URI::Escape;

use base 'Bio::GMOD::CMap::Admin';

# ----------------------------------------------

=pod

=head2 export

=cut

sub export {
    my ( $self, %args ) = @_;

    # my $map_set_ids = $args{'map_set_ids'};
    my $output_file = $args{'output_file'} || '-';

    $self->file_handle($output_file);
    $self->write_header();
    $self->export_species();

    return 1;
}

# ----------------------------------------------

=pod

=head2 export_species

=cut

sub write_header {
    my ( $self, %args ) = @_;

    my $fh = $self->file_handle();
    print $fh "##gff-version 3\n";
    print $fh "##cmap-gff-version 1\n";
    print $fh
        "# This file was produced from a CMap database using Bio::GMOD::CMap::Admin::GFFProducer\n";

}

# ----------------------------------------------

=pod

=head2 export_species

=cut

sub export_species {
    my ( $self, %args ) = @_;

    my $species_list = $self->sql->get_species();

    unless ( @{ $species_list || [] } ) {
        print STDERR "WARNING - No Species in the database.\n";
    }

    foreach my $species_data ( @{ $species_list || [] } ) {
        $self->write_species( species_data => $species_data );
        $self->export_map_sets( species_id => $species_data->{'species_id'},
        );
    }

    return 1;
}

# ----------------------------------------------

=pod

=head2 export_map_sets

=cut

sub export_map_sets {
    my ( $self, %args ) = @_;
    my $species_id = $args{'species_id'};

    my $map_set_list = $self->sql->get_map_sets( species_id => $species_id, );

    foreach my $map_set_data ( @{ $map_set_list || [] } ) {
        $self->write_map_set( map_set_data => $map_set_data );
        $self->export_maps( map_set_id => $map_set_data->{'map_set_id'}, );
    }

    return 1;
}

# ----------------------------------------------

=pod

=head2 export_maps

=cut

sub export_maps {
    my ( $self, %args ) = @_;
    my $map_set_id = $args{'map_set_id'};

    my $map_list = $self->sql->get_maps( map_set_id => $map_set_id, );
    return unless ( @{ $map_list || [] } );

    my $map_type_acc     = $map_list->[0]{'map_type_acc'};
    my $unit_granularity = $self->unit_granularity($map_type_acc);

    foreach my $map_data ( @{ $map_list || [] } ) {
        $self->write_map(
            map_data         => $map_data,
            unit_granularity => $unit_granularity,
        );
        $self->export_features( map_id => $map_data->{'map_id'}, );
    }

    return 1;
}

# ----------------------------------------------

=pod

=head2 export_features

=cut

sub export_features {
    my ( $self, %args ) = @_;
    my $map_id = $args{'map_id'};

    my $feature_list = $self->sql->get_features( map_id => $map_id, );
    return unless ( @{ $feature_list || [] } );
    my $correspondence_list = $self->sql->get_feature_correspondence_details(
        map_id1                 => $map_id,
        disregard_evidence_type => 1,
    );

    my %corrs_by_feature_id;
    foreach my $corr_data ( @{ $correspondence_list || [] } ) {
        push @{ $corrs_by_feature_id{ $corr_data->{'feature_id1'} } },
            $corr_data;
    }

    my $map_type_acc     = $feature_list->[0]{'map_type_acc'};
    my $unit_granularity = $self->unit_granularity($map_type_acc);

    foreach my $feature_data ( @{ $feature_list || [] } ) {
        $self->write_feature(
            feature_data        => $feature_data,
            corrs_by_feature_id => \%corrs_by_feature_id,
            unit_granularity    => $unit_granularity,
            file_handle         => $self->file_handle(),
        );
    }

    return 1;
}

# ----------------------------------------------

=pod

=head2 write_generic_pragma

=cut

sub write_generic_pragma {
    my ( $self, %args ) = @_;
    my $data        = $args{'data'};
    my $pragma_name = $args{'pragma_name'};
    my $acc_name    = $args{'acc_name'};
    my $param_list  = $args{'param_list'} || [];

    my $fh = $self->file_handle();

   # If the accession is a number, then it is not an external accession and is
   # not worth keeping.
    if ( $data->{$acc_name} =~ /^\d+$/ ) {
        $data->{$acc_name} = undef;
    }

    my $pragma_string = "##" . $pragma_name . "\t";

    # Create a key=value pair for each defined param and separate them with a
    # semi-colon
    $pragma_string .= join(
        ";",
        (   map {
                defined( $data->{$_} )
                    ? $_ . "=" . uri_escape( $data->{$_} )
                    : ()
                } @$param_list
        )
    );
    $pragma_string .= "\n";

    print $fh $pragma_string;

    return 1;
}

# ----------------------------------------------

=pod

=head2 write_species

=cut

sub write_species {
    my ( $self, %args ) = @_;
    my $species_data = $args{'species_data'};

    my @species_params = qw(
        species_acc
        species_common_name
        species_full_name
        display_order
    );

    my $fh = $self->file_handle();
    print $fh "\n";
    return $self->write_generic_pragma(
        data        => $species_data,
        param_list  => \@species_params,
        acc_name    => 'species_acc',
        pragma_name => 'cmap_species',
    );

}

# ----------------------------------------------

=pod

=head2 write_map_set

=cut

sub write_map_set {
    my ( $self, %args ) = @_;
    my $map_set_data = $args{'map_set_data'};

    my @map_set_params = qw(
        map_set_name
        map_set_short_name
        map_type_acc
        map_set_acc
        display_order
        shape
        color
        width
        published_on
    );

    # Print the ### before the map set to make sure the previous features are
    # cleared.
    my $fh = $self->file_handle();
    print $fh "\n###\n";

    return $self->write_generic_pragma(
        data        => $map_set_data,
        param_list  => \@map_set_params,
        acc_name    => 'map_set_acc',
        pragma_name => 'cmap_map_set',
    );

}

# ----------------------------------------------

=pod

=head2 write_map

=cut

sub write_map {
    my ( $self, %args ) = @_;
    my $map_data         = $args{'map_data'};
    my $unit_granularity = $args{'unit_granularity'};

    my @map_params = qw(
        map_acc
        map_name
        map_start
        map_stop
        display_order
    );

    $map_data->{'map_start'}
        = int( $map_data->{'map_start'} / $unit_granularity );
    $map_data->{'map_stop'}
        = int( $map_data->{'map_stop'} / $unit_granularity );

    $self->write_generic_pragma(
        data        => $map_data,
        param_list  => \@map_params,
        acc_name    => 'map_acc',
        pragma_name => 'cmap_map',
    );

    # A map also needs a sequence-region pragma to be viewed in GBrowse
    my $fh = $self->file_handle();
    print $fh "##sequence-region\t"
        . uri_escape( $map_data->{'map_name'} ) . "\t"
        . $map_data->{'map_start'} . "\t"
        . $map_data->{'map_stop'} . "\n";
    return 1;
}

# ----------------------------------------------

=pod

=head2 write_feature

=cut

sub write_feature {
    my ( $self, %args ) = @_;
    my $feature_data        = $args{'feature_data'};
    my $corrs_by_feature_id = $args{'corrs_by_feature_id'};
    my $unit_granularity    = $args{'unit_granularity'};
    my $fh                  = $args{'file_handle'};

    my $feature_type_acc = $feature_data->{'feature_type_acc'};
    my $feature_id       = $feature_data->{'feature_id'};

    my $seq_id = uri_escape( $feature_data->{'map_name'} );
    my $source
        = uri_escape(
        $self->feature_type_data( $feature_type_acc, 'gbrowse_source' )
            || "CMap" );
    my $type = $self->feature_type_data( $feature_type_acc, 'gbrowse_type' )
        || $feature_type_acc;
    my $start   = int( $feature_data->{'feature_start'} / $unit_granularity );
    my $stop    = int( $feature_data->{'feature_stop'} / $unit_granularity );
    my $score   = ".";
    my $strand  = $feature_data->{'direction'} == -1 ? "-" : "+";
    my $phase   = ".";
    my $column9 = '';

    # Fill Column 9
    $column9 .= "ID="
        . $self->create_load_id(
        type_acc => $feature_type_acc,
        id       => $feature_id,
        ) . ";";
    $column9 .= "Name=" . uri_escape( $feature_data->{'feature_name'} );

    # Aliases
    foreach my $alias ( @{ $feature_data->{'aliases'} || [] } ) {
        $column9 .= ";Alias=" . uri_escape($alias);
    }

    # Correspondences
    foreach my $corr_data ( @{ $corrs_by_feature_id->{$feature_id} || [] } ) {
        $column9 .= ";corr_by_id="
            . $self->create_load_id(
            type_acc => $corr_data->{'feature_type_acc2'},
            id       => $corr_data->{'feature_id2'},
            )
            . " "
            . $corr_data->{'evidence_type_acc'};
        if ( $corr_data->{'score'} ) {
            $column9 .= " " . uri_escape( $corr_data->{'score'} );
        }
    }

    # A map also needs a sequence-region pragma to be viewed in GBrowse
    my $fh = $self->file_handle();
    print $fh join(
        "\t",
        (   $seq_id, $source, $type,  $start, $stop,
            $score,  $strand, $phase, $column9,
        )
    ) . "\n";
    return 1;
}

# ----------------------------------------------

=pod

=head2 create_load_id

=cut

sub create_load_id {
    my ( $self, %args ) = @_;
    my $type_acc = $args{'type_acc'} or return;
    my $id       = $args{'id'}       or return;

    return $type_acc . $id;

}

# ----------------------------------------------

=pod

=head2 file_handle

=cut

sub file_handle {
    my ( $self, $file_name ) = @_;

    if ($file_name) {
        if ( $self->{'file_handle'} ) {
            close $self->{'file_handle'};
        }
        open $self->{'file_handle'}, ">" . $file_name;

    }
    return $self->{'file_handle'};
}

1;

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2008 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

