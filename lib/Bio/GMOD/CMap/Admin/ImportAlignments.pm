package Bio::GMOD::CMap::Admin::ImportAlignments;

# vim: set ft=perl:

# $Id: ImportAlignments.pm,v 1.1 2005-02-03 15:22:05 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Admin::ImportAlignments - import alignments such as BLAST

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::ImportAlignments;
  my $importer = Bio::GMOD::CMap::Admin::ImportAlignments->new;
  $importer->import(
      fh       => $fh,
      log_fh   => $self->log_fh,
  ) or return $importer->error;

=head1 DESCRIPTION

This module encapsulates all the logic for importing feature
alignments from blast files.

=cut

use strict;
use vars qw( $VERSION %COLUMNS $LOG_FH );
$VERSION = (qw$Revision: 1.1 $)[-1];

use Data::Dumper;
use Bio::SearchIO;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Admin;

use base 'Bio::GMOD::CMap';

# ----------------------------------------------
sub import_alignments {
    my ( $self, %args ) = @_;
    my $file_name = $args{'file_name'}
      or return $self->error('No file');
    my $query_map_set_id = $args{'query_map_set_id'}
      or return $self->error('No map set');
    my $hit_map_set_id = $args{'hit_map_set_id'}
      || $query_map_set_id;
    my $feature_type_aid = $args{'feature_type_aid'}
      or return $self->error('No feature_type_aid');
    my $evidence_type_aid = $args{'evidence_type_aid'}
      or return $self->error('No evidence_type_aid');
    my $min_identity = $args{'min_identity'} || 0;
    my $min_length   = $args{'min_length'}   || 0;
    my $format       = $args{'format'}       || 'blast';
    my $db           = $self->db;
    $LOG_FH = $args{'log_fh'} || \*STDOUT;
    print $LOG_FH "Importing Alignment\n";

    $self->{'admin'} = Bio::GMOD::CMap::Admin->new(
        config      => $self->config,
        data_source => $self->data_source,
    );

    my $in = new Bio::SearchIO(
        -format => $format,
        -file   => $file_name
    );
    $self->{'added_feature_ids'} = {};

    while ( my $result = $in->next_result ) {
        my $query_map_id = $self->get_map_id(
            object     => $result,
            map_set_id => $query_map_set_id,
          )
          or return $self->error(
            "Unable to find or create map " . $result->query_name() . "\n" );
        while ( my $hit = $result->next_hit ) {
            my $hit_map_id = $self->get_map_id(
                object     => $hit,
                map_set_id => $hit_map_set_id,
              )
              or return $self->error(
                "Unable to find or create map " . $hit->name() . "\n" );
            while ( my $hsp = $hit->next_hsp ) {
                if ( $hsp->length('total') > $min_length ) {
                    if ( $hsp->percent_identity >= $min_identity ) {
                        my @query_range = $hsp->range('query');
                        my @hit_range   = $hsp->range('hit');

                        my $query_feature_id = $self->get_feature_id(
                            feature_type_aid => $feature_type_aid,
                            map_id           => $query_map_id,
                            start            => $query_range[0],
                            end              => $query_range[1],
                            format           => $format,
                          )
                          or return $self->error(
                            "Unable to find or create feature for query \n");
                        my $hit_feature_id = $self->get_feature_id(
                            feature_type_aid => $feature_type_aid,
                            map_id           => $hit_map_id,
                            start            => $hit_range[0],
                            end              => $hit_range[1],
                            format           => $format,
                          )
                          or return $self->error(
                            "Unable to find or create feature for subject \n");

                        $self->{'admin'}->feature_correspondence_create(
                            feature_id1       => $query_feature_id,
                            feature_id2       => $hit_feature_id,
                            evidence_type_aid => $evidence_type_aid,
                        );
                    }
                }
            }
        }
    }
    return 1;
}

# get_map_id
#
# Check if this map needs adding, if so add it.
# Return the map_id of the map.
sub get_map_id {
    my ( $self, %args ) = @_;
    my $object     = $args{'object'};
    my $map_set_id = $args{'map_set_id'};

    my $db = $self->db;

    my ( $map_name, $map_desc, $map_accession, $map_length );

    if ( ref($object) eq 'Bio::Search::Result::BlastResult' ) {
        $map_name      = $object->query_name();
        $map_desc      = $object->query_description();
        $map_accession = $object->query_accession();
        $map_length    = $object->query_length();
    }
    elsif ( ref($object) eq 'Bio::Search::Hit::BlastHit' ) {
        $map_name      = $object->name();
        $map_desc      = $object->description();
        $map_accession = $object->accession();
        $map_length    = $object->length();
    }
    else {
        return 0;
    }
    if ( $map_name =~ /^\S+\|\S+/ and $map_desc) {
        $map_name = $map_desc;
    }

    $map_accession = '' unless defined($map_accession);

    # Check if added before
    my $map_key =
      $map_set_id . ":" . $map_name . ":" . $map_accession . ":" . $map_length;
    if ( $self->{'maps'}->{$map_key} ) {
        return $self->{'maps'}->{$map_key};
    }

    # Check for existance of map in cmap_map

    my $sql_str = qq[
        select map_id 
        from   cmap_map
        where  (stop_position-start_position+1=$map_length)
           and (map_name = '$map_name'
    ];
    if ($map_accession) {
        $sql_str .= " or accession_id = '$map_accession' ";
    }
    $sql_str .= ")";
    my $map_id_results =
      $db->selectall_arrayref( $sql_str, { Columns => {} }, () );

    # Check for existance of map in cmap_attribute
    unless ( $map_id_results and @$map_id_results ) {
        $sql_str = qq[
            select att.object_id as map_id 
            from   cmap_map m,
                   cmap_attribute att
            where  (m.stop_position-m.start_position+1=$map_length)
               and att.table_name = 'cmap_map'
               and att.object_id = m.map_id
               and (att.attribute_value = '$map_name'
        ];
        if ($map_accession) {
            $sql_str .= " or att.attribute_value = '$map_accession' ";
        }
        $sql_str .= ")";
        $map_id_results =
          $db->selectall_arrayref( $sql_str, { Columns => {} }, () );
    }

    my $map_id;
    if ( $map_id_results and @$map_id_results ) {
        $map_id = $map_id_results->[0]{'map_id'};
    }
    else {

        # Map not found, creat it.
        print "Map \"$map_name\" not found.  Creating.\n";
        $map_id = $self->{'admin'}->map_create(
            map_name       => $map_name,
            map_set_id     => $map_set_id,
            accession_id   => $map_accession,
            start_position => '1',
            stop_position  => $map_length,
        );
    }
    $self->{'maps'}->{$map_key} = $map_id;
    return $map_id;
}

# get_feature_id
#
# Check if this feature needs adding, if so add it.
# Return the map_id of the map.
sub get_feature_id {
    my ( $self, %args ) = @_;
    my $feature_type_aid = $args{'feature_type_aid'};
    my $map_id           = $args{'map_id'};
    my $start            = $args{'start'};
    my $end              = $args{'end'};
    my $format           = $args{'format'};
    my $direction        = 1;
    if ( $end < $start ) {
        ( $start, $end ) = ( $end, $start );
        $direction = -1;
    }

    my $db = $self->db;

    my $feature_key = $direction
      . $feature_type_aid . ":"
      . $map_id . ":"
      . $start . ":"
      . $end;
    if ( $self->{'added_feature_ids'}->{$feature_key} ) {
        return $self->{'added_feature_ids'}->{$feature_key};
    }
    my $feature_id;

    # Check for existance of feature in cmap_feature

    my $sql_str = qq[
        select feature_id 
        from   cmap_feature
        where  start_position = $start
           and stop_position  = $end
           and feature_type_accession = '$feature_type_aid'
           and direction = $direction
    ];
    my $feature_id_results =
      $db->selectall_arrayref( $sql_str, { Columns => {} }, () );

    if ( $feature_id_results and @$feature_id_results ) {
        $feature_id = $feature_id_results->[0]{'feature_id'};
    }
    else {

        # Feature not found, creat it.
        my $feature_name = $format . "_hsp:$direction:$start,$end";
        $feature_id = $self->{'admin'}->feature_create(
            map_id           => $map_id,
            feature_name     => $feature_name,
            start_position   => $start,
            stop_position    => $end,
            is_landmark      => 0,
            feature_type_aid => $feature_type_aid,
            direction        => $direction,
        );
    }

    $self->{'added_feature_ids'}->{$feature_key} = $feature_id;
    return $self->{'added_feature_ids'}->{$feature_key};
}
