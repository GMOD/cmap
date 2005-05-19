package Bio::GMOD::CMap::Data;

# vim: set ft=perl:

# $Id: Data.pm,v 1.235 2005-05-19 18:45:36 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Data - base data module

=head1 SYNOPSIS

use Bio::GMOD::CMap::Data;
my $data = Bio::GMOD::CMap::Data->new;
my $foo  = $data->foo_data;

=head1 DESCRIPTION

A module for getting data from a database.  Think DBI for whatever
RDBMS you want to use underneath.  I'll try to write generic SQL to
work with anything, and customize it in subclasses.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.235 $)[-1];

use Data::Dumper;
use Date::Format;
use Regexp::Common;
use Time::ParseDate;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Utils;
use Bio::GMOD::CMap::Admin::Export;
use Bio::GMOD::CMap::Admin::ManageLinks;
use Algorithm::Cluster qw/kcluster/;

use base 'Bio::GMOD::CMap';

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
#sub acc_id_to_internal_id {
#
##REPLACE 1
#}

# ----------------------------------------------------

=pod

=head2 correspondence_detail_data

Gets the specifics on a feature correspondence record.

=cut

sub correspondence_detail_data {

    #REPLACE 2
    #p#rint S#TDERR "correspondence_detail_data\n";
    my ( $self, %args ) = @_;
    my $correspondence_aid = $args{'correspondence_aid'}
      or return $self->error('No correspondence accession ID');
    my $sql_object = $self->sql;
    my $cache_key  = "correspondence_detail_data_" . $correspondence_aid;
    my ( $corr, $feature1, $feature2 );

    if ( my $array_ref = $self->get_cached_results( 4, $cache_key ) ) {
        ( $corr, $feature1, $feature2 ) = @$array_ref;
    }
    else {
        $corr = $sql_object->get_feature_correspondences(
            cmap_object                => $self,
            feature_correspondence_aid => $correspondence_aid,
          )
          or return $sql_object->error();

        $corr->{'attributes'} = $sql_object->get_attributes(
            cmap_object => $self,
            object_type => 'feature_correspondence',
            object_id   => $corr->{'feature_correspondence_id'},
        );

        $corr->{'xrefs'} = $sql_object->get_xrefs(
            cmap_object => $self,
            object_type => 'feature_correspondence',
            object_id   => $corr->{'feature_correspondence_id'},
        );

        $feature1 = $sql_object->get_features(
            cmap_object => $self,
            feature_id  => $corr->{'feature_id1'},
        );
        $feature1 = $feature1->[0] if $feature1;
        $feature2 = $sql_object->get_features(
            cmap_object => $self,
            feature_id  => $corr->{'feature_id2'},
        );
        $feature2 = $feature2->[0] if $feature2;

        $corr->{'evidence'} = $sql_object->get_correspondence_evidences(
            cmap_object               => $self,
            feature_correspondence_id => $corr->{'feature_correspondence_id'},
        );

        $corr->{'evidence'} =
          sort_selectall_arrayref( $corr->{'evidence'}, '#rank',
            'evidence_type' );
        $self->store_cached_results( 4, $cache_key,
            [ $corr, $feature1, $feature2 ] );
    }
    return {
        correspondence => $corr,
        feature1       => $feature1,
        feature2       => $feature2,
    };
}

# ----------------------------------------------------
sub data_download {

=pod

=head2 data_download

Returns a string of tab-delimited data for either a map or map set.

=cut

    my ( $self, %args ) = @_;
    my $map_set_aid = $args{'map_set_aid'} || '';
    my $map_aid     = $args{'map_aid'}     || '';
    my $format      = uc $args{'format'}   || 'TAB';
    return $self->error("Not enough arguments for data_download")
      unless $map_set_aid || $map_aid;

    return $self->error("'$format' not a valid download format")
      unless $format =~ /^(TAB|GFF|XML)$/;

    return $self->error("XML format only valid for map sets")
      if $format eq 'XML' && !$map_set_aid;

    my $sql_object = $self->sql;
    my ( $map_set_id, $map_id );

    #REPLACE 3 YYY
    if ($map_aid) {
        $map_id = $sql_object->acc_id_to_internal_id(
            cmap_object => $self,
            object_type => 'map',
            acc_id      => $map_aid,
          )
          or return $self->error("'$map_aid' is not a valid map accession ID");
    }

    #REPLACE 4 YYY
    if ($map_set_aid) {
        $map_set_id = $sql_object->acc_id_to_internal_id(
            cmap_object => $self,
            object_type => 'map_set',
            acc_id      => $map_set_aid,
          )
          or return $self->error(
            "'$map_set_aid' is not a valid map set accession ID");
    }

    my $return;
    if ( $format eq 'XML' ) {
        my $object = $map_set_aid ? 'cmap_map_set' : 'cmap_map';
        my $exporter =
          Bio::GMOD::CMap::Admin::Export->new(
            data_source => $self->data_source )
          or return $self->error( Bio::GMOD::CMap::Admin::Export->error );

        $exporter->export(
            objects  => [$object],
            output   => \$return,
            map_sets => $map_set_id ? [ { map_set_id => $map_set_id } ] : [],
            no_attributes => 1,
          )
          or do {
            print "Error: ", $exporter->error, "\n";
            return;
          };
    }
    else {

        #REPLACE 5 map_id YYY
        #REPLACE 6 map_set_id YYY

        #REPLACE 73 map_id ALIAS YYY
        #REPLACE 74 map_set_id ALIAS YYY

        my $features;
        if ($map_aid) {
            $features = $sql_object->get_features(
                cmap_object => $self,
                map_id      => $map_id,
            );
        }
        else {
            $features = $sql_object->get_features(
                cmap_object => $self,
                map_set_id  => $map_set_id,
            );
        }

        if ( $format eq 'TAB' ) {

            my @col_headers = qw[ map_accession_id map_name map_start map_stop
              feature_accession_id feature_name feature_aliases feature_start
              feature_stop feature_type_aid is_landmark
            ];
            my @col_names = qw[ map_aid map_name map_start map_stop
              feature_aid feature_name feature_aliases start_position
              stop_position feature_type_aid is_landmark
            ];

            $return = join( "\t", @col_headers ) . "\n";

            for my $f (@$features) {
                $f->{'feature_aliases'} =
                  join( ',', sort @{ $f->{'aliases'} || [] } );
                $return .= join( "\t", map { $f->{$_} } @col_names ) . "\n";
            }
        }
        elsif ( $format eq 'GFF' ) {

            #
            # Fields are: <seqname> <source> <feature> <start> <end>
            # <score> <strand> <frame> [attributes] [comments]
            # http://www.sanger.ac.uk/Software/formats/GFF/GFF_Spec.shtml
            #
            for my $f (@$features) {
                $return .= join( "\t",
                    $f->{'feature_name'},     'CMap',
                    $f->{'feature_type_aid'}, $f->{'start_position'},
                    $f->{'stop_position'},    '.',
                    '.',                      '.',
                    $f->{'map_name'} )
                  . "\n";
            }

        }
    }

    return $return;
}

# ----------------------------------------------------

=pod

=head2 cmap_data

Organizes the data for drawing comparative maps.

=cut

sub cmap_data {

    #p#rint S#TDERR "cmap_data\n";
    my ( $self, %args ) = @_;
    my $slots                       = $args{'slots'};
    my $min_correspondences         = $args{'min_correspondences'} || 0;
    my $included_feature_type_aids  = $args{'included_feature_type_aids'} || [];
    my $corr_only_feature_type_aids = $args{'corr_only_feature_type_aids'}
      || [];
    my $ignored_feature_type_aids   = $args{'ignored_feature_type_aids'} || [];
    my $url_feature_default_display = $args{'url_feature_default_display'};
    my $ignored_evidence_type_aids  = $args{'ignored_evidence_type_aids'} || [];
    my $included_evidence_type_aids = $args{'included_evidence_type_aids'}
      || [];
    my $less_evidence_type_aids    = $args{'less_evidence_type_aids'}    || [];
    my $greater_evidence_type_aids = $args{'greater_evidence_type_aids'} || [];
    my $evidence_type_score        = $args{'evidence_type_score'}        || {};
    my $pid                        = $$;

    # Fill the default array with any feature types not accounted for.
    my $feature_default_display =
      $self->feature_default_display($url_feature_default_display);

    my %found_feature_type;
    foreach
      my $ft ( @$included_feature_type_aids, @$corr_only_feature_type_aids,
        @$ignored_feature_type_aids )
    {
        $found_feature_type{$ft} = 1;
    }
    my $feature_type_data = $self->feature_type_data();

    foreach my $key ( keys(%$feature_type_data) ) {
        my $aid = $feature_type_data->{$key}{'feature_type_accession'};
        unless ( $found_feature_type{$aid} ) {
            if ( $feature_default_display eq 'corr_only' ) {
                push @$corr_only_feature_type_aids, $aid;
            }
            elsif ( $feature_default_display eq 'ignore' ) {
                push @$ignored_feature_type_aids, $aid;
            }
            else {
                push @$included_feature_type_aids, $aid;
            }
        }
    }

    # Fill the default array with any evidence types not accounted for.
    my $evidence_default_display = $self->evidence_default_display;

    my %found_evidence_type;
    foreach my $et (
        @$included_evidence_type_aids, @$ignored_evidence_type_aids,
        @$less_evidence_type_aids,     @$greater_evidence_type_aids,
      )
    {
        $found_evidence_type{$et} = 1;
    }
    my $evidence_type_data = $self->evidence_type_data();

    foreach my $key ( keys(%$evidence_type_data) ) {
        my $aid = $evidence_type_data->{$key}{'evidence_type_accession'};
        unless ( $found_evidence_type{$aid} ) {
            if ( $evidence_default_display eq 'ignore' ) {
                push @$ignored_evidence_type_aids, $aid;
            }
            else {
                push @$included_evidence_type_aids, $aid;
            }
        }
    }

    my (
        $data,                      %feature_correspondences,
        %intraslot_correspondences, %map_correspondences,
        %correspondence_evidence,   %feature_types,
        %map_type_aids
    );
    $self->slot_info(
        $slots,                       $ignored_feature_type_aids,
        $included_evidence_type_aids, $less_evidence_type_aids,
        $greater_evidence_type_aids,  $evidence_type_score,
        $min_correspondences,
    );

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

        $data->{'slots'}{$slot_no} = $self->slot_data(
            map                         => \$cur_map,                     # pass
            feature_correspondences     => \%feature_correspondences,     # by
            intraslot_correspondences   => \%intraslot_correspondences,   #
            map_correspondences         => \%map_correspondences,         # ref
            correspondence_evidence     => \%correspondence_evidence,     # "
            feature_types               => \%feature_types,               # "
            reference_map               => $ref_map,
            slot_no                     => $slot_no,
            ref_slot_no                 => $ref_slot_no,
            min_correspondences         => $min_correspondences,
            included_feature_type_aids  => $included_feature_type_aids,
            corr_only_feature_type_aids => $corr_only_feature_type_aids,
            ignored_feature_type_aids   => $ignored_feature_type_aids,
            ignored_evidence_type_aids  => $ignored_evidence_type_aids,
            included_evidence_type_aids => $included_evidence_type_aids,
            less_evidence_type_aids     => $less_evidence_type_aids,
            greater_evidence_type_aids  => $greater_evidence_type_aids,
            evidence_type_score         => $evidence_type_score,
            pid                         => $pid,
            map_type_aids               => \%map_type_aids,
          )
          or last;

        #Set the map order for this slot
        $self->sorted_map_ids( $slot_no, $data->{'slots'}{$slot_no} );

    }
    ###Get the extra javascript that goes along with the feature_types.
    ### and get extra forms
    my ( $extra_code, $extra_form );
    ( $extra_code, $extra_form ) =
      $self->get_web_page_extras( \%feature_types, \%map_type_aids, $extra_code,
        $extra_form );

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
    $data->{'included_feature_type_aids'}  = $included_feature_type_aids;
    $data->{'corr_only_feature_type_aids'} = $corr_only_feature_type_aids;
    $data->{'ignored_feature_type_aids'}   = $ignored_feature_type_aids;
    $data->{'included_evidence_type_aids'} = $included_evidence_type_aids;
    $data->{'ignored_evidence_type_aids'}  = $ignored_evidence_type_aids;
    $data->{'less_evidence_type_aids'}     = $less_evidence_type_aids;
    $data->{'greater_evidence_type_aids'}  = $greater_evidence_type_aids;
    $data->{'evidence_type_score'}         = $evidence_type_score;
    $data->{'extra_code'}                  = $extra_code;
    $data->{'extra_form'}                  = $extra_form;
    $data->{'max_unit_size'} = $self->get_max_unit_size( $data->{'slots'} );
    $data->{'ref_unit_size'} = $self->get_ref_unit_size( $data->{'slots'} );
    $data->{'feature_default_display'} = $feature_default_display;

    return $data;
}

# ----------------------------------------------------

=pod

=head2 slot_data

Returns the feature and correspondence data for the maps in a slot.

=cut

sub slot_data {

    #print S#TDERR "slot_data\n";
    my ( $self, %args ) = @_;
    my $this_slot_no                = $args{'slot_no'};
    my $ref_slot_no                 = $args{'ref_slot_no'};
    my $min_correspondences         = $args{'min_correspondences'} || 0;
    my $included_feature_type_aids  = $args{'included_feature_type_aids'};
    my $included_evidence_type_aids = $args{'included_evidence_type_aids'};
    my $ignored_evidence_type_aids  = $args{'ignored_evidence_type_aids'};
    my $less_evidence_type_aids     = $args{'less_evidence_type_aids'};
    my $greater_evidence_type_aids  = $args{'greater_evidence_type_aids'};
    my $evidence_type_score         = $args{'evidence_type_score'};
    my $slot_map                  = ${ $args{'map'} };                 # hashref
    my $reference_map             = $args{'reference_map'};
    my $feature_correspondences   = $args{'feature_correspondences'};
    my $intraslot_correspondences = $args{'intraslot_correspondences'};
    my $map_correspondences       = $args{'map_correspondences'};
    my $correspondence_evidence   = $args{'correspondence_evidence'};
    my $feature_types_seen        = $args{'feature_types'};
    my $corr_only_feature_type_aids = $args{'corr_only_feature_type_aids'};
    my $ignored_feature_type_aids   = $args{'ignored_feature_type_aids'};
    my $map_type_aids               = $args{'map_type_aids'};
    my $pid                         = $args{'pid'};
    my $max_no_features             = 200000;
    my $sql_object                  = $self->sql or return;
    my $slot_info                   = $self->slot_info or return;

    #
    # If there is more than 1 map in this slot, we will return totals
    # for all the features on every map and the number of
    # correspondences on them to the reference map.
    #
    # If there is just one map in this slot, then we will look to see
    # if the total number of features on the map exceeds some number
    # -- 200 for now.  If so, we will chunk the map's features and
    # correspondences;  if not, we will show all.
    #

    #
    # Sort out the map(s) in the current slot ("this" map) -- are we
    # looking at just one map or all the maps in the set?
    #
    my @map_aids              = keys( %{ $slot_map->{'maps'} } );
    my @map_set_aids          = keys( %{ $slot_map->{'map_sets'} } );
    my $no_flanking_positions = $slot_map->{'no_flanking_positions'} || 0;

    #
    # Gather necessary info on all the maps in this slot.
    #
    my @maps = ();

    #REPLACE 7 MAPS YYY
    if ( $slot_info->{$this_slot_no}
        and %{ $slot_info->{$this_slot_no} } )
    {
        my $tempMap = $sql_object->get_maps(
            cmap_object => $self,
            map_ids     => [ keys( %{ $slot_info->{$this_slot_no} } ) ],
        );

        foreach my $row (@$tempMap) {
            if (
                $slot_info->{$this_slot_no}{ $row->{'map_id'} }
                and
                defined( $slot_info->{$this_slot_no}{ $row->{'map_id'} }[0] )
                and ( $slot_info->{$this_slot_no}{ $row->{'map_id'} }[0] >
                    $row->{'start_position'} )
              )
            {
                $row->{'start_position'} =
                  $slot_info->{$this_slot_no}{ $row->{'map_id'} }[0];
            }
            if ( $slot_info->{$this_slot_no}{ $row->{'map_id'} }
                and
                defined( $slot_info->{$this_slot_no}{ $row->{'map_id'} }[1] )
                and defined( $row->{'stop_position'} )
                and ( $slot_info->{$this_slot_no}{ $row->{'map_id'} }[1] ) <
                $row->{'stop_position'} )
            {
                $row->{'stop_position'} =
                  $slot_info->{$this_slot_no}{ $row->{'map_id'} }[1];
            }
        }
        push @maps, @{$tempMap};
    }

    #
    # Store all the map types
    #
    if ( scalar @maps == 1 ) {
        $map_type_aids->{ $maps[0]{'map_type_aid'} } = 1;
    }
    else {
        for (@maps) {
            $map_type_aids->{ $_->{'map_type_aid'} } = 1;
        }
    }

    my $return;

    #
    # Register the feature types on the maps in this slot.
    #
    #REPLACE 8 FT YYY
    my $ft = $sql_object->get_used_feature_types(
        cmap_object => $self,
        map_ids     => [ keys( %{ $slot_info->{$this_slot_no} } ) ],
        included_feature_type_aids => $included_feature_type_aids,
    );
    $feature_types_seen->{ $_->{'feature_type_aid'} } = $_ for @$ft;

    #
    # check to see if it is compressed
    #
    if ( !$self->{'aggregate'} or !$self->compress_maps($this_slot_no) ) {

        #
        # Figure out how many features are on each map.
        #
        #REPLACE 9 FCOUNT YYY
        my %count_lookup;

        # Include current slot maps
        my $f_counts = $sql_object->get_feature_count(
            cmap_object     => $self,
            this_slot_info  => $slot_info->{$this_slot_no},
            group_by_map_id => 1,
        );

        for my $f (@$f_counts) {
            $count_lookup{ $f->{'map_id'} } = $f->{'feature_count'};
        }

        my %corr_lookup = %{
            $self->count_correspondences(
                included_evidence_type_aids => $included_evidence_type_aids,
                ignored_evidence_type_aids  => $ignored_evidence_type_aids,
                less_evidence_type_aids     => $less_evidence_type_aids,
                greater_evidence_type_aids  => $greater_evidence_type_aids,
                evidence_type_score         => $evidence_type_score,
                map_correspondences         => $map_correspondences,
                this_slot_no                => $this_slot_no,
                ref_slot_no                 => $ref_slot_no,
                maps                        => \@maps,

            )
          };

        for my $map (@maps) {
            my $map_start = $slot_info->{$this_slot_no}{ $map->{'map_id'} }[0];
            my $map_stop  = $slot_info->{$this_slot_no}{ $map->{'map_id'} }[1];
            $map->{'start_position'} = $map_start if defined($map_start);
            $map->{'stop_position'}  = $map_stop  if defined($map_stop);
            $map->{'no_correspondences'} = $corr_lookup{ $map->{'map_id'} };
            if (   $min_correspondences
                && defined $ref_slot_no
                && $map->{'no_correspondences'} < $min_correspondences )
            {
                delete $self->{'slot_info'}{$this_slot_no}{ $map->{'map_id'} };
                next;
            }
            $map->{'no_features'} = $count_lookup{ $map->{'map_id'} };

            # REPLACE 10 YYY
            # REPLACE 75 ALIAS YYY
            $map->{'features'} = $sql_object->slot_data_features(
                cmap_object                 => $self,
                map_id                      => $map->{'map_id'},
                map_start                   => $map_start,
                map_stop                    => $map_stop,
                slot_info                   => $slot_info,
                this_slot_no                => $this_slot_no,
                included_feature_type_aids  => $included_feature_type_aids,
                ignored_feature_type_aids   => $ignored_feature_type_aids,
                corr_only_feature_type_aids => $corr_only_feature_type_aids,
                show_intraslot_corr         => $self->show_intraslot_corr,
            );

            ###set $feature_correspondences and$correspondence_evidence
            if ( defined $ref_slot_no ) {
                $self->get_feature_correspondences(
                    $feature_correspondences,
                    $correspondence_evidence,
                    $map->{'map_id'},
                    $ref_slot_no,
                    $included_evidence_type_aids,
                    $ignored_evidence_type_aids,
                    $less_evidence_type_aids,
                    $greater_evidence_type_aids,
                    $evidence_type_score,
                    [
                        @$included_feature_type_aids,
                        @$corr_only_feature_type_aids
                    ],
                    $map_start,
                    $map_stop
                );
            }
            $return->{ $map->{'map_id'} } = $map;
        }
    }
    else {

        #
        # Figure out how many features are on each map.
        #
        # REPLACE 11 FCOUNT YYY
        my %count_lookup;
        my $f_counts = $sql_object->get_feature_count(
            cmap_object     => $self,
            map_ids         => [ keys( %{ $slot_info->{$this_slot_no} } ) ],
            group_by_map_id => 1,
        );

        for my $f (@$f_counts) {
            $count_lookup{ $f->{'map_id'} } = $f->{'feature_count'};
        }

        my %corr_lookup = %{
            $self->count_correspondences(
                included_evidence_type_aids => $included_evidence_type_aids,
                ignored_evidence_type_aids  => $ignored_evidence_type_aids,
                less_evidence_type_aids     => $less_evidence_type_aids,
                greater_evidence_type_aids  => $greater_evidence_type_aids,
                evidence_type_score         => $evidence_type_score,
                map_correspondences         => $map_correspondences,
                this_slot_no                => $this_slot_no,
                ref_slot_no                 => $ref_slot_no,
                maps                        => \@maps,

            )
          };

        for my $map (@maps) {
            my $map_start = $slot_info->{$this_slot_no}{ $map->{'map_id'} }[0];
            my $map_stop  = $slot_info->{$this_slot_no}{ $map->{'map_id'} }[1];
            $map->{'start_position'} = $map_start if defined($map_start);
            $map->{'stop_position'}  = $map_stop  if defined($map_stop);
            $map->{'no_correspondences'} = $corr_lookup{ $map->{'map_id'} };
            if (   $min_correspondences
                && defined $ref_slot_no
                && $map->{'no_correspondences'} < $min_correspondences )
            {
                delete $self->{'slot_info'}{$this_slot_no}{ $map->{'map_id'} };
                next;
            }
            $map->{'no_features'} = $count_lookup{ $map->{'map_id'} };

            ###set $feature_correspondences and$correspondence_evidence
            if ( defined $ref_slot_no ) {
                $self->get_feature_correspondences(
                    $feature_correspondences,
                    $correspondence_evidence,
                    $map->{'map_id'},
                    $ref_slot_no,
                    $included_evidence_type_aids,
                    $ignored_evidence_type_aids,
                    $less_evidence_type_aids,
                    $greater_evidence_type_aids,
                    $evidence_type_score,
                    [
                        @$included_feature_type_aids,
                        @$corr_only_feature_type_aids
                    ],
                    $map_start,
                    $map_stop
                );
            }
            $return->{ $map->{'map_id'} } = $map;
        }
    }

    # Get the intra-slot correspondence
    if ( $self->show_intraslot_corr ) {
        $self->get_intraslot_correspondences(
            $intraslot_correspondences,
            $correspondence_evidence,
            $this_slot_no,
            $included_evidence_type_aids,
            $ignored_evidence_type_aids,
            $less_evidence_type_aids,
            $greater_evidence_type_aids,
            $evidence_type_score,
            [ @$included_feature_type_aids, @$corr_only_feature_type_aids ],
        );
    }

    return $return;

}

# ----------------------------------------------------

=pod

=head2 get_web_page_extras

Gets the extra javascript code that needs to go on the web
page for these features.

=cut

sub get_web_page_extras {
    my $self          = shift;
    my $feature_types = shift;
    my $map_type_aids = shift;
    my $extra_code    = shift;
    my $extra_form    = shift;

    my %snippet_aids;
    my %extra_form_aids;
    my $required_string;
    my $map_type_data     = $self->map_type_data();
    my $feature_type_data = $self->feature_type_data();

    ###Get the feature type info
    foreach my $key ( keys %{$feature_types} ) {
        ###First get the code snippets
        $required_string = $feature_type_data->{$key}{'required_page_code'};
        foreach my $snippet_aid ( split( /\s*,\s*/, $required_string ) ) {
            $snippet_aids{$snippet_aid} = 1;
        }
        ###Then get the extra form stuff
        $required_string = $feature_type_data->{$key}{'extra_forms'};
        foreach my $extra_form_aid ( split( /\s*,\s*/, $required_string ) ) {
            $extra_form_aids{$extra_form_aid} = 1;
        }
    }

    ###Get the map type info
    foreach my $key ( keys %{$map_type_aids} ) {
        ###First get the code snippets
        $required_string = $map_type_data->{$key}{'required_page_code'};
        foreach my $snippet_aid ( split( /\s*,\s*/, $required_string ) ) {
            $snippet_aids{$snippet_aid} = 1;
        }
        ###Then get the extra form stuff
        $required_string = $map_type_data->{$key}{'extra_forms'};
        foreach my $extra_form_aid ( split( /\s*,\s*/, $required_string ) ) {
            $extra_form_aids{$extra_form_aid} = 1;
        }

    }

    foreach my $snippet_aid ( keys(%snippet_aids) ) {
        $extra_code .=
          $self->config_data('page_code')->{$snippet_aid}->{'page_code'};
    }
    foreach my $extra_form_aid ( keys(%extra_form_aids) ) {
        $extra_form .=
          $self->config_data('extra_form')->{$extra_form_aid}->{'extra_form'};
    }
    return ( $extra_code, $extra_form );
}

# ----------------------------------------------------

=pod
    
=head2 get_feature_correspondences

inserts correspondence info into $feature_correspondence and 
$correspondence_evidence based on corrs from the slot
and the provided id.

=cut

sub get_feature_correspondences {

    #p#rint S#TDERR "get_feature_correspondences\n";
    my (
        $self,                       $feature_correspondences,
        $correspondence_evidence,    $map_id,
        $slot_no,                    $included_evidence_type_aids,
        $ignored_evidence_type_aids, $less_evidence_type_aids,
        $greater_evidence_type_aids, $evidence_type_score,
        $feature_type_aids,          $map_start,
        $map_stop
      )
      = @_;
    my $sql_object = $self->sql;

    my $ref_correspondences = $sql_object->get_feature_correspondences_by_maps(
        cmap_object                 => $self,
        map_id                      => $map_id,
        ref_map_info                => $self->slot_info->{$slot_no},
        map_start                   => $map_start,
        map_stop                    => $map_stop,
        included_evidence_type_aids => $included_evidence_type_aids,
        less_evidence_type_aids     => $less_evidence_type_aids,
        greater_evidence_type_aids  => $greater_evidence_type_aids,
        evidence_type_score         => $evidence_type_score,
        feature_type_aids           => $feature_type_aids,
    );

    for my $corr ( @{$ref_correspondences} ) {
        $feature_correspondences->{ $corr->{'feature_id'} }
          { $corr->{'ref_feature_id'} } = $corr->{'feature_correspondence_id'};

        $feature_correspondences->{ $corr->{'ref_feature_id'} }
          { $corr->{'feature_id'} } = $corr->{'feature_correspondence_id'};

        push @{ $correspondence_evidence
              ->{ $corr->{'feature_correspondence_id'} } },
          {
            evidence_type_aid => $corr->{'evidence_type_aid'},
            evidence_type     => $corr->{'evidence_type'},
            evidence_rank     => $corr->{'evidence_rank'},
            line_color        => $corr->{'line_color'},
          };
    }

}

# ----------------------------------------------------

=pod
    
=head2 get_intraslot_correspondences

inserts correspondence info into $intraslot_correspondence and 
$correspondence_evidence based on corrs from the slot

This is basically the same as get_feature_correspondences (but with the
intraslot value) but I am keeping it separate in case we decide to make it
fancier.

=cut

sub get_intraslot_correspondences {

    my (
        $self,                        $intraslot_correspondences,
        $correspondence_evidence,     $slot_no,
        $included_evidence_type_aids, $ignored_evidence_type_aids,
        $less_evidence_type_aids,     $greater_evidence_type_aids,
        $evidence_type_score,         $feature_type_aids
      )
      = @_;

    my $ref_correspondences = $self->sql->get_feature_correspondences_by_maps(
        cmap_object                 => $self,
        ref_map_info                => $self->slot_info->{$slot_no},
        included_evidence_type_aids => $included_evidence_type_aids,
        less_evidence_type_aids     => $less_evidence_type_aids,
        greater_evidence_type_aids  => $greater_evidence_type_aids,
        evidence_type_score         => $evidence_type_score,
        feature_type_aids           => $feature_type_aids,
        intraslot                   => 1,
    );

    for my $corr ( @{$ref_correspondences} ) {
        $intraslot_correspondences->{ $corr->{'feature_id'} }
          { $corr->{'ref_feature_id'} } = $corr->{'feature_correspondence_id'};

        $intraslot_correspondences->{ $corr->{'ref_feature_id'} }
          { $corr->{'feature_id'} } = $corr->{'feature_correspondence_id'};

        push @{ $correspondence_evidence
              ->{ $corr->{'feature_correspondence_id'} } },
          {
            evidence_type_aid => $corr->{'evidence_type_aid'},
            evidence_type     => $corr->{'evidence_type'},
            evidence_rank     => $corr->{'evidence_rank'},
            line_color        => $corr->{'line_color'},
          };
    }

}

# ----------------------------------------------------
sub matrix_correspondence_data {

=pod

=head2 matrix_data

Returns the data for the correspondence matrix.

=cut

    my ( $self, %args ) = @_;
    my $species_aid      = $args{'species_aid'}      || '';
    my $map_type_aid     = $args{'map_type_aid'}     || '';
    my $map_set_aid      = $args{'map_set_aid'}      || '';
    my $map_name         = $args{'map_name'}         || '';
    my $link_map_set_aid = $args{'link_map_set_aid'} || 0;
    my $sql_object = $self->sql or return;

    #
    # Get all the species.
    #
    # REPLACE 14 YYY
    my $species = $sql_object->get_species(
        cmap_object       => $self,
        is_relational_map => 0,
        is_enabled        => 1,
    );

    #
    # And map types.
    #
    # REPLACE 15 YYY
    my $map_types = $sql_object->get_used_map_types(
        cmap_object       => $self,
        is_relational_map => 0,
        is_enabled        => 1,
    );

    unless ( $args{'show_matrix'} ) {
        return {
            species_aid => $species_aid,
            map_types   => $map_types,
            species     => $species,
        };
    }

    #
    # Make sure that species_aid is set if map_set_id is.
    #
    # REPLACE 16 SPID YYY
    if ( $map_set_aid && !$species_aid ) {
        $species_aid = $sql_object->get_species_aid(
            cmap_object => $self,
            map_set_aid => $map_set_aid,
        );
    }

    #
    # Make sure that map_type_aid is set if map_set_id is.
    #
    # REPLACE 17
    if ( $map_set_aid && !$map_type_aid ) {
        $map_type_aid = $sql_object->get_map_type_aid(
            cmap_object => $self,
            map_set_aid => $map_set_aid,
        );
    }

    #
    # Get all the map sets for a given species and/or map type.
    #
    my ( $maps, $map_sets );
    if ( $species_aid || $map_type_aid ) {

        # REPLACE 18 MAP_SET YYY
        $map_sets = $sql_object->get_map_sets(
            cmap_object       => $self,
            species_aid       => $species_aid,
            map_type_aid      => $map_type_aid,
            is_relational_map => 0,
            is_enabled        => 1,
        );

        # REPLACE 19 MAPS YYY
        $maps = $sql_object->get_maps(
            cmap_object       => $self,
            is_relational_map => 0,
            is_enabled        => 1,
            map_type_aid      => $map_type_aid,
            species_aid       => $species_aid,
            map_set_aid       => $map_set_aid,
        );
    }

    #
    # Select all the map sets for the left-hand column
    # (those which can be reference sets).
    #
    my @reference_map_sets = ();
    if ($map_set_aid) {

        # REPLACE 20 MAPS YYY
        my $tempMapSet = $sql_object->get_maps(
            cmap_object => $self,
            is_enabled  => 1,
            map_set_aid => $map_set_aid,
            map_name    => $map_name,
        );

        @reference_map_sets = @$tempMapSet;
    }
    else {

        my $tempMapSet;
        if ($map_name) {

            # REPLACE 21 MAPS YYY
            $tempMapSet = $sql_object->get_maps(
                cmap_object       => $self,
                is_enabled        => 1,
                is_relational_map => 0,
                map_type_aid      => $map_type_aid,
                species_aid       => $species_aid,
                map_set_aid       => $map_set_aid,
                map_name          => $map_name,
            );
        }
        else {

            # REPLACE 22 MAP_SET YYY
            $tempMapSet = $sql_object->get_map_sets(
                cmap_object       => $self,
                map_set_aid       => $map_set_aid,
                species_aid       => $species_aid,
                map_type_aid      => $map_type_aid,
                is_relational_map => 0,
                is_enabled        => 1,
            );
        }

        @reference_map_sets = @{
            sort_selectall_arrayref(
                $tempMapSet,           '#map_type_display_order',
                'map_type',            '#species_display_order',
                'species_common_name', '#map_set_display_order',
                'map_set_short_name',  'epoch_published_on desc',
            )
          };
    }

    #
    # Select the relationships from the pre-computed table.
    # If there's a map_set_id, then we should break down the
    # results by map, else we sum it all up on map set ids.
    # If there's both a map_set_id and a link_map_set_id, then we should
    # break down the results by map by map, else we sum it
    # all up on map set ids.
    #
    my $select_sql;

    # REPLACE 23 YYY
    my $data = $sql_object->get_matrix_relationships(
        cmap_object      => $self,
        map_set_aid      => $map_set_aid,
        link_map_set_aid => $link_map_set_aid,
        species_aid      => $species_aid,
        map_name         => $map_name,
    );

    #
    # Create a lookup hash from the data.
    #
    my %lookup;
    for my $hr (@$data) {
        if ( $map_set_aid && $link_map_set_aid ) {

            #
            # Map sets that can't be references won't have a "link_map_id."
            #
            my $link_aid = $hr->{'link_map_aid'}
              || $hr->{'link_map_set_aid'};
            $lookup{ $hr->{'reference_map_aid'} }{$link_aid}[0] =
              $hr->{'correspondences'};
            $lookup{ $hr->{'reference_map_aid'} }{$link_aid}[1] =
              $hr->{'map_count'};
        }
        elsif ($map_set_aid) {
            $lookup{ $hr->{'reference_map_aid'} }{ $hr->{'link_map_set_aid'} }
              [0] = $hr->{'correspondences'};
            $lookup{ $hr->{'reference_map_aid'} }{ $hr->{'link_map_set_aid'} }
              [1] = $hr->{'map_count'};
        }
        else {
            $lookup{ $hr->{'reference_map_set_aid'} }
              { $hr->{'link_map_set_aid'} }[0] = $hr->{'correspondences'};
            $lookup{ $hr->{'reference_map_set_aid'} }
              { $hr->{'link_map_set_aid'} }[1] = $hr->{'map_count'};
        }
    }

    #
    # Select ALL the map sets to go across.
    #

    my $link_map_can_be_reference;
    if ($link_map_set_aid) {

        # REPLACE 24 MAP_SET YYY
        my $map_sets = $sql_object->get_map_sets_simple(
            cmap_object => $self,
            map_set_aid => $link_map_set_aid,
        );
        my $is_rel;
        $is_rel = $map_sets->[0]{'is_relational_map'} if $map_sets;

        $link_map_can_be_reference = ( !$is_rel );
    }

    #
    # If given a map set id for a map set that can be a reference map,
    # select the individual map.  Otherwise, if given a map set id for
    # a map set that can't be a reference or if given nothing, grab
    # the entire map set.
    #
    my $link_map_set_sql;
    my $tempMapSet;
    if (   $map_set_aid
        && $link_map_set_aid
        && $link_map_can_be_reference )
    {

        # REPLACE 25 MAPS YYY
        $tempMapSet = $sql_object->get_maps(
            cmap_object => $self,
            is_enabled  => 1,
            map_set_aid => $link_map_set_aid,
        );
    }
    else {

        # REPLACE 26 MAP_SET YYY
        $tempMapSet = $sql_object->get_map_sets(
            cmap_object => $self,
            map_set_aid => $link_map_set_aid,
            is_enabled  => 1,
        );
    }

    my @all_map_sets = @$tempMapSet;

    #
    # Figure out the number by type and species.
    #
    my ( %no_by_type, %no_by_type_and_species );
    for my $map_set (@all_map_sets) {
        my $map_type_aid = $map_set->{'map_type_aid'};
        my $species_aid  = $map_set->{'species_aid'};

        $no_by_type{$map_type_aid}++;
        $no_by_type_and_species{$map_type_aid}{$species_aid}++;
    }

    #
    # The top row of the table is a listing of all the map sets.
    #
    my $top_row = {
        no_by_type             => \%no_by_type,
        no_by_type_and_species => \%no_by_type_and_species,
        map_sets               => \@all_map_sets
    };

    #
    # Fill in the matrix with the reference set and all it's correspondences.
    # Herein lies madness.
    #
    my ( @matrix, %no_ref_by_species_and_type, %no_ref_by_type );
    for my $map_set (@reference_map_sets) {
        my $r_map_aid      = $map_set->{'map_aid'} || '';
        my $r_map_set_aid  = $map_set->{'map_set_aid'};
        my $r_map_type_aid = $map_set->{'map_type_aid'};
        my $r_species_aid  = $map_set->{'species_aid'};
        my $reference_aid  =
            $map_name && $map_set_aid ? $r_map_aid
          : $map_name ? $r_map_set_aid
          : $r_map_aid || $r_map_set_aid;

        $no_ref_by_type{$r_map_type_aid}++;
        $no_ref_by_species_and_type{$r_species_aid}{$r_map_type_aid}++;

        for my $comp_map_set (@all_map_sets) {
            my $comp_map_set_aid = $comp_map_set->{'map_set_aid'};
            my $comp_map_aid     = $comp_map_set->{'map_aid'} || '';
            my $comparative_aid  = $comp_map_aid || $comp_map_set_aid;
            my $correspondences;
            my $map_count;
            if (   $r_map_aid
                && $comp_map_aid
                && $r_map_aid eq $comp_map_aid )
            {
                $correspondences = 'N/A';
                $map_count       = 'N/A';
            }
            else {
                $correspondences = $lookup{$reference_aid}{$comparative_aid}[0]
                  || 0;
                $map_count = $lookup{$reference_aid}{$comparative_aid}[1] || 0;
            }

            push @{ $map_set->{'correspondences'} },
              {
                map_set_aid => $comp_map_set_aid,
                map_aid     => $comp_map_aid,
                number      => $correspondences,
                map_count   => $map_count,
              };
        }

        push @matrix, $map_set;
    }

    my $matrix_data = {
        data                   => \@matrix,
        no_by_type             => \%no_ref_by_type,
        no_by_species_and_type => \%no_ref_by_species_and_type,
    };

    return {
        top_row      => $top_row,
        species_aid  => $species_aid,
        map_set_aid  => $map_set_aid,
        map_type_aid => $map_type_aid,
        map_name     => $map_name,
        matrix       => $matrix_data,
        data         => $data,
        species      => $species,
        map_sets     => $map_sets,
        map_types    => $map_types,
        maps         => $maps,
    };
}

# ----------------------------------------------------

=pod

=head2 cmap_form_data

Returns the data for the main comparative map HTML form.

=cut

sub cmap_form_data {

    #p#rint S#TDERR "cmap_form_data\n";
    my ( $self, %args ) = @_;
    my $slots = $args{'slots'} or return;
    my $min_correspondences         = $args{'min_correspondences'}     || 0;
    my $feature_type_aids           = $args{'included_feature_types'}  || [];
    my $ignored_feature_type_aids   = $args{'ignored_feature_types'}   || [];
    my $included_evidence_type_aids = $args{'included_evidence_types'} || [];
    my $ignored_evidence_type_aids  = $args{'ignored_evidence_types'}  || [];
    my $less_evidence_type_aids     = $args{'less_evidence_types'}     || [];
    my $greater_evidence_type_aids  = $args{'greater_evidence_types'}  || [];
    my $evidence_type_score         = $args{'evidence_type_score'}     || {};
    my $ref_species_aid             = $args{'ref_species_aid'}         || '';
    my $ref_slot_data               = $args{'ref_slot_data'}           || {};
    my $ref_map                     = $slots->{0};
    my $ref_map_set_aid             = $args{'ref_map_set_aid'}         || 0;
    my $sql_object = $self->sql or return;

    my $pid = $$;

    my @ref_maps = ();

    if ( @{ $self->sorted_map_ids(0) } ) {
        foreach my $map_id ( @{ $self->sorted_map_ids(0) } ) {
            my %temp_hash = (
                'map_id'         => $map_id,
                'map_aid'        => $ref_slot_data->{$map_id}{'map_aid'},
                'map_name'       => $ref_slot_data->{$map_id}{'map_name'},
                'start_position' => $self->slot_info->{0}{$map_id}[0],
                'stop_position'  => $self->slot_info->{0}{$map_id}[1],
            );
            push @ref_maps, \%temp_hash;
        }
    }

    my $sql_str;
    if ( $ref_map_set_aid && !$ref_species_aid ) {

        # REPLACE 27 SPID YYY
        $ref_species_aid = $sql_object->get_species_aid(
            cmap_object => $self,
            map_set_aid => $ref_map_set_aid,
        );
    }

    #
    # Select all the map set that can be reference maps.
    #

    # REPLACE 28 YYY
    my $ref_species = $sql_object->get_species(
        cmap_object       => $self,
        is_relational_map => 0,
        is_enabled        => 1,
    );

    if ( @$ref_species && !$ref_species_aid ) {
        $ref_species_aid = $ref_species->[0]{'species_aid'};
    }

    #
    # Select all the map set that can be reference maps.
    #
    my $ref_map_sets = [];
    if ($ref_species_aid) {

        # REPLACE 64 MAP_SET YYY
        $ref_map_sets = $sql_object->get_map_sets(
            cmap_object          => $self,
            species_aid          => $ref_species_aid,
            is_relational_map    => 0,
            can_be_reference_map => 1,
            is_enabled           => 1,
        );
    }

    #
    # If there's only one map set, pretend it was submitted.
    #
    if ( !$ref_map_set_aid && scalar @$ref_map_sets == 1 ) {
        $ref_map_set_aid = $ref_map_sets->[0]{'map_set_aid'};
    }

    #
    # If the user selected a map set, select all the maps in it.
    #
    my ( $ref_maps, $ref_map_set_info );

    if ($ref_map_set_aid) {
        unless ( ( $ref_map->{'maps'} and %{ $ref_map->{'maps'} } )
            or ( $ref_map->{'map_sets'} and %{ $ref_map->{'map_sets'} } ) )
        {

            # REPLACE 65 YYY
            $ref_maps = $sql_object->get_maps_from_map_set(
                cmap_object => $self,
                map_set_aid => $ref_map_set_aid,
            );
            $self->error(
qq[No maps exist for the ref. map set acc. id "$ref_map_set_aid"]
              )
              unless @$ref_maps;
        }

        unless (@ref_maps) {

            # REPLACE 29 MAP_SET YYY
            my $tempMapSet = $sql_object->get_map_sets(
                cmap_object => $self,
                map_set_aid => $ref_map_set_aid,
            );
            $ref_map_set_info = $tempMapSet->[0];

            $ref_map_set_info->{'attributes'} = $sql_object->get_attributes(
                cmap_object => $self,
                object_type => 'map_set',
                object_id   => $ref_map_set_info->{'map_set_id'},
            );
            $ref_map_set_info->{'xrefs'} = $sql_object->get_xrefs(
                cmap_object => $self,
                object_type => 'map_set',
                object_id   => $ref_map_set_info->{'map_set_id'},
            );
        }
    }

    my @slot_nos = sort { $a <=> $b } keys %$slots;
    my ( $comp_maps_right, $comp_maps_left );
    if ( $self->slot_info and @slot_nos ) {
        $comp_maps_right = $self->get_comparative_maps(
            min_correspondences         => $min_correspondences,
            feature_type_aids           => $feature_type_aids,
            ignored_feature_type_aids   => $ignored_feature_type_aids,
            included_evidence_type_aids => $included_evidence_type_aids,
            ignored_evidence_type_aids  => $ignored_evidence_type_aids,
            less_evidence_type_aids     => $less_evidence_type_aids,
            greater_evidence_type_aids  => $greater_evidence_type_aids,
            evidence_type_score         => $evidence_type_score,
            ref_slot_no                 => $slot_nos[-1],
            pid                         => $pid,
        );

        $comp_maps_left =
            $slot_nos[0] == $slot_nos[-1]
          ? $comp_maps_right
          : $self->get_comparative_maps(
            min_correspondences         => $min_correspondences,
            feature_type_aids           => $feature_type_aids,
            ignored_feature_type_aids   => $ignored_feature_type_aids,
            included_evidence_type_aids => $included_evidence_type_aids,
            ignored_evidence_type_aids  => $ignored_evidence_type_aids,
            less_evidence_type_aids     => $less_evidence_type_aids,
            greater_evidence_type_aids  => $greater_evidence_type_aids,
            evidence_type_score         => $evidence_type_score,
            ref_slot_no                 => $slot_nos[0],
            pid                         => $pid,
          );
    }

    #
    # Correspondence evidence types.
    #
    my @evidence_types = @{
        $self->fake_selectall_arrayref(
            $self->evidence_type_data(),
            'evidence_type_accession as evidence_type_aid',
            'evidence_type'
        )
      };

    #
    # Fill out all the info we have on every map.
    #
    my $map_info;
    if ( scalar @ref_maps >= 1 ) {
        $map_info = $self->fill_out_maps($slots);
    }

    return {
        ref_species_aid        => $ref_species_aid,
        ref_species            => $ref_species,
        ref_map_sets           => $ref_map_sets,
        ref_map_set_aid        => $ref_map_set_aid,
        ref_maps               => $ref_maps,
        ordered_ref_maps       => \@ref_maps,
        ref_map_set_info       => $ref_map_set_info,
        comparative_maps_right => $comp_maps_right,
        comparative_maps_left  => $comp_maps_left,
        map_info               => $map_info,
        evidence_types         => \@evidence_types,
    };
}

# ----------------------------------------------------
sub get_comparative_maps {

=pod

=head2 get_comparative_maps

Given a reference map and (optionally) start and stop positions, figure
out which maps have relationships.

=cut

    my ( $self, %args ) = @_;
    my $min_correspondences         = $args{'min_correspondences'};
    my $feature_type_aids           = $args{'feature_type_aids'};
    my $ignored_feature_type_aids   = $args{'ignored_feature_type_aids'};
    my $included_evidence_type_aids = $args{'included_evidence_type_aids'};
    my $ignored_evidence_type_aids  = $args{'ignored_evidence_type_aids'};
    my $less_evidence_type_aids     = $args{'less_evidence_type_aids'};
    my $greater_evidence_type_aids  = $args{'greater_evidence_type_aids'};
    my $evidence_type_score         = $args{'evidence_type_score'};
    my $ref_slot_no                 = $args{'ref_slot_no'};
    my $pid                         = $args{'pid'};
    my $sql_object                  = $self->sql or return;
    return unless defined $ref_slot_no;

    # REPLACE 30 CORRCOUNTS YYY
    my $feature_correspondences = $sql_object->get_comparative_maps_with_count(
        cmap_object                 => $self,
        slot_info                   => $self->slot_info->{$ref_slot_no},
        included_evidence_type_aids => $included_evidence_type_aids,
        ignored_evidence_type_aids  => $ignored_evidence_type_aids,
        less_evidence_type_aids     => $less_evidence_type_aids,
        greater_evidence_type_aids  => $greater_evidence_type_aids,
        evidence_type_score         => $evidence_type_score,
        ignored_feature_type_aids   => $ignored_feature_type_aids,
        include_map1_data           => 0,
    );

    #
    # Gather info on the maps and map sets.
    #
    my %map_set_ids =
      map { $_->{'map_set_id2'}, 1 } @$feature_correspondences;

    # REPLACE 31 MAP_SET YYY

    my ( %map_sets, %comp_maps );
    for my $map_set_id ( keys %map_set_ids ) {
        my $tempMapSet = $sql_object->get_map_sets(
            cmap_object => $self,
            map_set_id  => $map_set_id,
        );
        my $ms_info = $tempMapSet->[0];
        $map_sets{ $ms_info->{'map_set_aid'} } = $ms_info;
    }
    if (@$feature_correspondences) {
        my $maps = $sql_object->get_maps(
            cmap_object => $self,
            map_ids => [ map { $_->{'map_id2'} } @$feature_correspondences ],
        );
        for my $map (@$maps) {
            $comp_maps{ $map->{'map_id'} } = $map;
        }
    }
    for my $fc (@$feature_correspondences) {
        my $comp_map        = $comp_maps{ $fc->{'map_id2'} } or next;
        my $ref_map_set_aid = $comp_map->{'map_set_aid'}     or next;

        $comp_map->{'no_correspondences'} = $fc->{'no_corr'};

        push @{ $map_sets{$ref_map_set_aid}{'maps'} }, $comp_map;
    }

    #
    # Sort the map sets and maps for display, count up correspondences.
    #
    my @sorted_map_sets;
    for my $map_set (
        sort {
            $a->{'map_type_display_order'} <=> $b->{'map_type_display_order'}
              || $a->{'map_type'} cmp $b->{'map_type'}
              || $a->{'species_display_order'} <=> $b->{'species_display_order'}
              || $a->{'species_common_name'} cmp $b->{'species_common_name'}
              || $a->{'ms_display_order'} <=> $b->{'ms_display_order'}
              || $b->{'published_on'} <=> $a->{'published_on'}
              || $a->{'map_set_name'} cmp $b->{'map_set_name'}
        } values %map_sets
      )
    {
        my @maps;                     # the maps for the map set
        my $total_correspondences;    # all the correspondences for the map set
        my $can_be_reference_map;     # whether or not it can

        my $display_order_sort = sub {
            $a->{'display_order'} <=> $b->{'display_order'}
              || $a->{'map_name'} cmp $b->{'map_name'};
        };
        my $no_corr_sort = sub {
            $b->{'no_correspondences'} <=> $a->{'no_correspondences'}
              || $a->{'display_order'} <=> $b->{'display_order'}
              || $a->{'map_name'} cmp $b->{'map_name'};
        };

        my $sort_sub;
        if ( $self->comp_menu_order eq 'corrs' ) {
            $sort_sub = $no_corr_sort;
        }
        else {
            $sort_sub = $display_order_sort;
        }

        for my $map ( sort $sort_sub @{ $map_set->{'maps'} || [] } ) {
            next
              if $min_correspondences
              && $map->{'no_correspondences'} < $min_correspondences;

            $total_correspondences += $map->{'no_correspondences'};
            push @maps, $map if $map_set->{'can_be_reference_map'};
        }

        next unless $total_correspondences;
        next if !@maps and $can_be_reference_map;

        push @sorted_map_sets,
          {
            map_type            => $map_set->{'map_type'},
            species_common_name => $map_set->{'species_common_name'},
            map_set_name        => $map_set->{'map_set_name'},
            map_set_aid         => $map_set->{'map_set_aid'},
            no_correspondences  => $total_correspondences,
            maps                => \@maps,
          };
    }

    return \@sorted_map_sets;
}

# ----------------------------------------------------
sub feature_alias_detail_data {

=pod

=head2 feature_alias_detail_data

Returns the data for the feature alias detail page.

=cut

    my ( $self, %args ) = @_;
    my $feature_aid = $args{'feature_aid'}
      or return $self->error('No feature acc. id');
    my $feature_alias = $args{'feature_alias'}
      or return $self->error('No feature alias');

    my $sql_object = $self->sql;

    # REPLACE 32 ALIAS YYY
    my $alias_array = $sql_object->get_feature_aliases(
        cmap_object => $self,
        feature_aid => $feature_aid,
        alias       => $feature_alias,
      )
      or return $self->error('No alias');
    my $alias = $alias_array->[0];

    $alias->{'object_id'}  = $alias->{'feature_alias_id'};
    $alias->{'attributes'} = $self->sql->get_attributes(
        cmap_object => $self,
        object_type => 'feature_alias',
        object_id   => $alias->{'feature_alias_id'},
    );
    $self->get_multiple_xrefs(
        object_type => 'feature_alias',
        objects     => [$alias],
    );

    return $alias;
}

# ----------------------------------------------------
sub feature_correspondence_data {

=pod

=head2 feature_correspondence_data

Retrieve the data for a feature correspondence.

=cut

    my ( $self, %args ) = @_;
    my $feature_correspondence_id = $args{'feature_correspondence_id'}
      or return;
}

# ----------------------------------------------------

=pod

=head2 fill_out_maps

Gets the names, IDs, etc., of the maps in the slots.

=cut

sub fill_out_maps {

    #p#rint S#TDERR "fill_out_maps\n";
    my ( $self, $slots ) = @_;
    my $sql_object = $self->sql or return;
    my @ordered_slot_nos = sort { $a <=> $b } keys %$slots;

    # REPLACE 34 MAP_SET YYY

    my @maps;
    for my $i ( 0 .. $#ordered_slot_nos ) {
        my $map;
        my $slot_no   = $ordered_slot_nos[$i];
        my $slot_info = $self->slot_info->{$slot_no};
        my $map_sets  = $sql_object->get_map_set_info_by_maps(
            cmap_object => $self,
            map_ids     => [ keys(%$slot_info) ],
        );
        my %desc_by_species;
        foreach my $row (@$map_sets) {
            if ( $desc_by_species{ $row->{'species_common_name'} } ) {
                $desc_by_species{ $row->{'species_common_name'} } .=
                  "," . $row->{'map_set_short_name'};
            }
            else {
                $desc_by_species{ $row->{'species_common_name'} } .=
                    $row->{'species_common_name'} . "-"
                  . $row->{'map_set_short_name'};
            }
        }
        $map->{'description'} =
          join( ";", map { $desc_by_species{$_} } keys(%desc_by_species) );

        #
        # To select the other comparative maps, we have to cut off everything
        # after the current map.  E.g., if there are maps in slots -2, -1, 0,
        # 1, and 2, for slot 1 we should choose everything less than it (and
        # non-zero).  The opposite is true for negative slots.
        #
        my @cmap_nos;
        if ( $slot_no == 0 ) {
            $map->{'is_reference_map'} = 1;
        }
        elsif ( $slot_no < 0 ) {
            push @cmap_nos, grep { $_ > $slot_no && $_ != 0 } @ordered_slot_nos;
        }
        else {
            push @cmap_nos, grep { $_ < $slot_no && $_ != 0 } @ordered_slot_nos;
        }

        foreach my $cmap_no (@cmap_nos) {
            if ( $slots->{$cmap_no}{'maps'}
                and %{ $slots->{$cmap_no}{'maps'} } )
            {
                my @aids;
                foreach my $map_aid ( keys %{ $slots->{$cmap_no}{'maps'} } ) {
                    my $aid_line = $map_aid;
                    if (
                        defined(
                            $slots->{$cmap_no}{'maps'}{$map_aid}{'start'}
                        )
                        or
                        defined( $slots->{$cmap_no}{'maps'}{$map_aid}{'stop'} )
                      )
                    {
                        $aid_line .= "["
                          . $slots->{$cmap_no}{'maps'}{$map_aid}{'start'} . "*"
                          . $slots->{$cmap_no}{'maps'}{$map_aid}{'stop'} . "x"
                          . $slots->{$cmap_no}{'maps'}{$map_aid}{'mag'} . "]";
                    }
                    push @aids, $aid_line;
                }
                push @{ $map->{'cmaps'} },
                  {
                    field   => 'map_aid',
                    aid     => join( ",", @aids ),
                    slot_no => $cmap_no,
                  };
            }
            if ( $slots->{$cmap_no}{'map_sets'}
                and %{ $slots->{$cmap_no}{'map_sets'} } )
            {
                push @{ $map->{'cmaps'} },
                  {
                    field => 'map_set_aid',
                    aid   =>
                      join( ",", keys %{ $slots->{$cmap_no}{'map_sets'} } ),
                    slot_no => $cmap_no,
                  };
            }
        }
        $map->{'slot_no'} = $slot_no;
        push @maps, $map;
    }

    return \@maps;
}

# ----------------------------------------------------
sub feature_detail_data {

=pod

=head2 feature_detail_data

Given a feature acc. id, find out all the details on it.

=cut

    my ( $self, %args ) = @_;
    my $feature_aid = $args{'feature_aid'} or die 'No accession id';
    my $sql_object  = $self->sql           or return;

    # REPLACE 66 YYY
    my $feature_array = $sql_object->get_features(
        cmap_object => $self,
        feature_aid => $feature_aid,
    );
    my $feature = $feature_array->[0];

    $feature->{'object_id'}  = $feature->{'feature_id'};
    $feature->{'attributes'} = $self->sql->get_attributes(
        cmap_object => $self,
        object_type => 'feature',
        object_id   => $feature->{'feature_id'},
    );

    # REPLACE 35 ALIAS YYY

    # REPLACE 67 FCS YYY
    my $correspondences = $sql_object->get_feature_correspondence_details(
        cmap_object             => $self,
        feature_id              => $feature->{'feature_id'},
        disregard_evidence_type => 1,
    );

    for my $corr (@$correspondences) {

        # REPLACE 36 YYY
        $corr->{'evidence'} = $sql_object->get_correspondence_evidences(
            cmap_object               => $self,
            feature_correspondence_id => $corr->{'feature_correspondence_id'},
        );
        $corr->{'evidence'} =
          sort_selectall_arrayref( $corr->{'evidence'}, '#rank',
            'evidence_type' );

        # REPLACE 37 ALIAS YYY
        my $aliases = $sql_object->get_feature_aliases(
            cmap_object => $self,
            feature_id  => $corr->{'feature_id'},
        );
        $corr->{'aliases'} = [ map { $_->{'alias'} } @$aliases ];
    }

    $feature->{'correspondences'} = $correspondences;

    $self->get_multiple_xrefs(
        object_type => 'feature',
        objects     => [$feature],
    );

    return $feature;
}

# ----------------------------------------------------
sub link_viewer_data {

=pod

=head2 link_viewer_data

Given a list of feature names, find any maps they occur on.

=cut

    my ( $self, %args ) = @_;
    my $selected_link_set = $args{'selected_link_set'};

    my $link_manager =
      Bio::GMOD::CMap::Admin::ManageLinks->new(
        data_source => $self->data_source );

    my @link_set_names =
      $link_manager->list_set_names( name_space => $self->get_link_name_space );

    my @links = $link_manager->output_links(
        name_space    => $self->get_link_name_space,
        link_set_name => $selected_link_set,
    );

    return {
        links     => \@links,
        link_sets => \@link_set_names,
    };
}

# ----------------------------------------------------
sub feature_search_data {

=pod

=head2 feature_search_data

Given a list of feature names, find any maps they occur on.

=cut

    my ( $self, %args ) = @_;
    my $species_aids               = $args{'species_aids'};
    my $incoming_feature_type_aids = $args{'feature_type_aids'};
    my $feature_string             = $args{'features'};
    my $page_data                  = $args{'page_data'};
    my $page_size                  = $args{'page_size'};
    my $page_no                    = $args{'page_no'};
    my $pages_per_set              = $args{'pages_per_set'};
    my $feature_type_data          = $self->feature_type_data();
    my $sql_object                 = $self->sql or return;
    my @feature_names              = (
        map {
            s/\*/%/g;          # turn stars into SQL wildcards
            s/,//g;            # remove commas
            s/^\s+|\s+$//g;    # remove leading/trailing whitespace
            s/"//g;            # remove double quotes"
            s/'/\\'/g;         # backslash escape single quotes
            $_ || ()
          } parse_words($feature_string)
    );
    my $order_by = $args{'order_by'}
      || 'feature_name,species_common_name,map_set_name,map_name,start_position';
    my $search_field = $args{'search_field'}
      || $self->config_data('feature_search_field');
    $search_field = DEFAULT->{'feature_search_field'}
      unless VALID->{'feature_search_field'}{$search_field};

    #
    # We'll get the feature ids first.  Use "like" in case they've
    # included wildcard searches.
    #
    my %features = ();
    for my $feature_name (@feature_names) {

        # REPLACE 38 YYY
        # REPLACE 39 YYY
        my $features = $sql_object->get_features(
            cmap_object       => $self,
            feature_name      => $feature_name,
            feature_type_aids => $incoming_feature_type_aids,
            species_aids      => $species_aids,
            aliases_get_rows  => 1,
        );

        for my $f (@$features) {
            $features{ $f->{'feature_id'} } = $f;
        }
    }

    #
    # Perform sort on accumulated results.
    #
    my @found_features = ();
    if ( $order_by eq 'start_position' ) {
        @found_features =
          map  { $_->[1] }
          sort { $a->[0] <=> $b->[0] }
          map  { [ $_->{$order_by}, $_ ] } values %features;
    }
    else {
        my @sort_fields = split( /,/, $order_by );
        @found_features =
          map  { $_->[1] }
          sort { $a->[0] cmp $b->[0] }
          map  { [ join( '', @{$_}{@sort_fields} ), $_ ] } values %features;
    }

    #
    # Page the data here so as to make the "IN" statement
    # below managable.
    #
    my $pager = Data::Pageset->new(
        {
            total_entries    => scalar @found_features,
            entries_per_page => $page_size,
            current_page     => $page_no,
            pages_per_set    => $pages_per_set,
        }
    );

    if ( $page_data && @found_features ) {
        @found_features = $pager->splice( \@found_features );
    }

    my @feature_ids = map { $_->{'feature_id'} } @found_features;
    if (@feature_ids) {

        # REPLACE 40 YYY
        my $aliases = $sql_object->get_feature_aliases(
            cmap_object => $self,
            feature_ids => \@feature_ids,
        );
        my %aliases;
        for my $alias (@$aliases) {
            push @{ $aliases{ $alias->{'feature_id'} } }, $alias->{'alias'};
        }

        for my $f (@found_features) {
            $f->{'aliases'} =
              [ sort { lc $a cmp lc $b }
                  @{ $aliases{ $f->{'feature_id'} } || [] } ];
        }
    }

    #
    # If no species was selected, then look at what's in the search
    # results so they can narrow down what they have.  If no search
    # results, then just show all.
    #
    # REPLACE 41 YYY
    my $species = $sql_object->get_species( cmap_object => $self, );

    #
    # Get the feature types.
    #
    my $feature_types =
      $self->fake_selectall_arrayref( $feature_type_data, 'feature_type',
        'feature_type_accession as feature_type_aid' );

    return {
        data          => \@found_features,
        species       => $species,
        feature_types => $feature_types,
        pager         => $pager,
    };
}

# ----------------------------------------------------
sub evidence_type_info_data {

=pod

=head2 evidence_type_info_data

Return data for a list of evidence type acc. IDs.

=cut

    my ( $self, %args ) = @_;

    my @return_array;

    my @evidence_types =
      keys( %{ $self->config_data('evidence_type') } );

    my $evidence_type_data = $self->evidence_type_data();
    my %supplied_evidence_types;
    if ( $args{'evidence_types'} ) {
        %supplied_evidence_types =
          map { $_ => 1 } @{ $args{'evidence_types'} };
    }
    foreach my $evidence_type (@evidence_types) {
        if (%supplied_evidence_types) {
            next unless ( $supplied_evidence_types{$evidence_type} );
        }
        my @attributes = ();
        my @xrefs      = ();

        # Get Attributes from config file
        my $configured_attributes =
          $evidence_type_data->{$evidence_type}{'attribute'};
        if ( ref($configured_attributes) ne 'ARRAY' ) {
            $configured_attributes = [ $configured_attributes, ];
        }
        foreach my $att (@$configured_attributes) {
            next
              unless ( defined( $att->{'name'} )
                and defined( $att->{'value'} ) );
            push @attributes,
              {
                attribute_name  => $att->{'name'},
                attribute_value => $att->{'value'},
                is_public       => defined( $att->{'is_public'} )
                ? $att->{'is_public'}
                : 1,
              };
        }

        # Get Xrefs from config file
        my $configured_xrefs = $evidence_type_data->{$evidence_type}{'xref'};
        if ( ref($configured_xrefs) ne 'ARRAY' ) {
            $configured_xrefs = [ $configured_xrefs, ];
        }
        foreach my $xref (@$configured_xrefs) {
            next
              unless ( defined( $xref->{'name'} )
                and defined( $xref->{'url'} ) );
            push @xrefs,
              {
                xref_name => $xref->{'name'},
                xref_url  => $xref->{'url'},
              };
        }

        $return_array[ ++$#return_array ] = {
            'evidence_type_aid' => $evidence_type,
            'evidence_type'     =>
              $evidence_type_data->{$evidence_type}{'evidence_type'},
            'rank'       => $evidence_type_data->{$evidence_type}{'rank'},
            'line_color' => $evidence_type_data->{$evidence_type}{'line_color'},
            'attributes' => \@attributes,
            'xrefs'      => \@xrefs,
        };
    }
    my $default_color = $self->config_data('connecting_line_color');

    for my $ft (@return_array) {
        $ft->{'line_color'} ||= $default_color;
    }

    my $all_evidence_types =
      $self->fake_selectall_arrayref( $evidence_type_data,
        'evidence_type_accession as evidence_type_aid',
        'evidence_type' );
    $all_evidence_types =
      sort_selectall_arrayref( $all_evidence_types, 'evidence_type' );

    return {
        all_evidence_types => $all_evidence_types,
        evidence_types     => \@return_array,
      }

}

# ----------------------------------------------------
sub feature_type_info_data {

=pod

=head2 feature_type_info_data

Return data for a list of feature type acc. IDs.

=cut

    my ( $self, %args ) = @_;

    my @return_array;

    my @feature_types = keys( %{ $self->config_data('feature_type') } );

    my $feature_type_data = $self->feature_type_data();
    my %supplied_feature_types;
    if ( $args{'feature_types'} ) {
        %supplied_feature_types =
          map { $_ => 1 } @{ $args{'feature_types'} };
    }
    foreach my $feature_type (@feature_types) {
        if (%supplied_feature_types) {
            next unless ( $supplied_feature_types{$feature_type} );
        }
        my @attributes = ();
        my @xrefs      = ();

        # Get Attributes from config file
        my $configured_attributes =
          $feature_type_data->{$feature_type}{'attribute'};
        if ( ref($configured_attributes) ne 'ARRAY' ) {
            $configured_attributes = [ $configured_attributes, ];
        }
        foreach my $att (@$configured_attributes) {
            next
              unless ( defined( $att->{'name'} )
                and defined( $att->{'value'} ) );
            push @attributes,
              {
                attribute_name  => $att->{'name'},
                attribute_value => $att->{'value'},
                is_public       => defined( $att->{'is_public'} )
                ? $att->{'is_public'}
                : 1,
              };
        }

        # Get Xrefs from config file
        my $configured_xrefs = $feature_type_data->{$feature_type}{'xref'};
        if ( ref($configured_xrefs) ne 'ARRAY' ) {
            $configured_xrefs = [ $configured_xrefs, ];
        }
        foreach my $xref (@$configured_xrefs) {
            next
              unless ( defined( $xref->{'name'} )
                and defined( $xref->{'url'} ) );
            push @xrefs,
              {
                xref_name => $xref->{'name'},
                xref_url  => $xref->{'url'},
              };
        }

        $return_array[ ++$#return_array ] = {
            'feature_type_aid' => $feature_type,
            'feature_type'     =>
              $feature_type_data->{$feature_type}{'feature_type'},
            'shape'      => $feature_type_data->{$feature_type}{'shape'},
            'color'      => $feature_type_data->{$feature_type}{'color'},
            'attributes' => \@attributes,
            'xrefs'      => \@xrefs,
        };
    }

    my $default_color = $self->config_data('feature_color');

    for my $ft (@return_array) {
        $ft->{'color'} ||= $default_color;
    }

    @return_array =
      sort { lc $a->{'feature_type'} cmp lc $b->{'feature_type'} }
      @return_array;

    my $all_feature_types =
      $self->fake_selectall_arrayref( $feature_type_data,
        'feature_type_accession as feature_type_aid',
        'feature_type' );
    $all_feature_types =
      sort_selectall_arrayref( $all_feature_types, 'feature_type' );

    return {
        all_feature_types => $all_feature_types,
        feature_types     => \@return_array,
    };
}

# ----------------------------------------------------
sub map_set_viewer_data {

=pod

=head2 map_set_viewer_data

Returns the data for drawing comparative maps.

=cut

    my ( $self, %args ) = @_;
    my @map_set_aids = @{ $args{'map_set_aids'} || [] };
    my $species_aid  = $args{'species_aid'}  || 0;
    my $map_type_aid = $args{'map_type_aid'} || 0;
    my $sql_object = $self->sql or return;

    my $map_type_data = $self->map_type_data();
    for ( $species_aid, $map_type_aid ) {
        $_ = 0 if $_ == -1;
    }

    #
    # Map sets
    #
    # REPLACE 42 MAP_SET YYY
    my $map_sets = $sql_object->get_map_sets(
        cmap_object  => $self,
        map_set_aids => \@map_set_aids,
        species_aid  => $species_aid,
        map_type_aid => $map_type_aid,
    );

    #
    # Maps in the map sets
    #
    # REPLACE 43 MAPS YYY
    my $maps = $sql_object->get_maps(
        cmap_object       => $self,
        is_relational_map => 0,
        map_set_aids      => \@map_set_aids,
        species_aid       => $species_aid,
        map_type_aid      => $map_type_aid,
    );
    my %map_lookup;
    for my $map (@$maps) {
        push @{ $map_lookup{ $map->{'map_set_id'} } }, $map;
    }

    #
    # Attributes of the map sets
    #
    # REPLACE 44 ATT YYY
    my $attributes = $sql_object->get_attributes(
        cmap_object => $self,
        object_type => 'map_set',
        get_all     => 1,
        order_by    => ' object_id, display_order, attribute_name ',
    );
    my %attr_lookup;
    for my $attr (@$attributes) {
        push @{ $attr_lookup{ $attr->{'object_id'} } }, $attr;
    }

    #
    # Make sure we have something
    #
    if ( @map_set_aids && scalar @$map_sets == 0 ) {
        return $self->error( 'No map sets match the following accession IDs: '
              . join( ', ', @map_set_aids ) );
    }

    #
    # Sort it all out
    #
    for my $map_set (@$map_sets) {
        $map_set->{'object_id'}  = $map_set->{'map_set_id'};
        $map_set->{'attributes'} = $attr_lookup{ $map_set->{'map_set_id'} };
        $map_set->{'maps'}       = $map_lookup{ $map_set->{'map_set_id'} }
          || [];
        if ( $map_set->{'published_on'} ) {
            if ( my $pubdate =
                parsedate( $map_set->{'published_on'}, VALIDATE => 1 ) )
            {
                my @time = localtime($pubdate);
                $map_set->{'published_on'} = strftime( "%d %B, %Y", @time );
            }
            else {
                $map_set->{'published_on'} = '';
            }
        }
    }

    $self->get_multiple_xrefs(
        object_type => 'map_set',
        objects     => $map_sets,
    );

    #
    # Grab species and map type info for form restriction controls.
    #
    # REPLACE 45 YYY
    my $species = $sql_object->get_species( cmap_object => $self, );

    my $map_types =
      $self->fake_selectall_arrayref( $map_type_data,
        'map_type_accession as map_type_aid', 'map_type' );
    $map_types =
      sort_selectall_arrayref( $map_types, '#display_order', 'map_type' );

    return {
        species   => $species,
        map_types => $map_types,
        map_sets  => $map_sets,
    };
}

# ----------------------------------------------------
sub map_detail_data {

=pod

=head2 map_detail_data

Returns the detail info for a map.

=cut

    my ( $self, %args ) = @_;
    my $map                       = $args{'ref_map'};
    my $highlight                 = $args{'highlight'} || '';
    my $order_by                  = $args{'order_by'} || 'f.start_position';
    my $comparative_map_field     = $args{'comparative_map_field'} || '';
    my $comparative_map_field_aid = $args{'comparative_map_field_aid'} || '';
    my $page_size                 = $args{'page_size'} || 25;
    my $max_pages                 = $args{'max_pages'} || 0;
    my $page_no                   = $args{'page_no'} || 1;
    my $page_data                 = $args{'page_data'};
    my $sql_object                = $self->sql or return;
    my $map_id                    = $map->{'map_id'};
    my $map_start                 = $map->{'start'};
    my $map_stop                  = $map->{'stop'};
    my $feature_type_data         = $self->feature_type_data();
    my $evidence_type_data        = $self->evidence_type_data();

    my $feature_type_aids           = $args{'included_feature_types'}  || [];
    my $corr_only_feature_type_aids = $args{'corr_only_feature_types'} || [];
    my $ignored_feature_type_aids   = $args{'ignored_feature_types'}   || [];
    my $included_evidence_type_aids = $args{'included_evidence_types'};
    my $ignored_evidence_type_aids  = $args{'ignored_evidence_types'};
    my $less_evidence_type_aids     = $args{'less_evidence_types'};
    my $greater_evidence_type_aids  = $args{'greater_evidence_types'};
    my $evidence_type_score         = $args{'evidence_type_score'};

    my ( $comparative_map_aid, $comparative_map_set_aid );
    if ( $comparative_map_field eq 'map_set_aid' ) {
        $comparative_map_set_aid = $comparative_map_field_aid;
    }
    elsif ( $comparative_map_field eq 'map_aid' ) {
        $comparative_map_aid = $comparative_map_field_aid;
    }

    #
    # Figure out hightlighted features.
    #
    my $highlight_hash = {
        map {
            s/^\s+|\s+$//g;
            defined $_ && $_ ne '' ? ( uc $_, 1 ) : ()
          } parse_words($highlight)
    };

    # REPLACE 46 MAPS YYY
    my $maps = $sql_object->get_maps(
        cmap_object => $self,
        map_id      => $map_id,
    );
    my $reference_map = $maps->[0] if $maps;

    $map_start = $reference_map->{'start_position'}
      unless defined $map_start
      and $map_start =~ /^$RE{'num'}{'real'}$/;
    $map_stop = $reference_map->{'stop_position'}
      unless defined $map_stop
      and $map_stop =~ /^$RE{'num'}{'real'}$/;
    $reference_map->{'start'}      = $map_start;
    $reference_map->{'stop'}       = $map_stop;
    $reference_map->{'object_id'}  = $map_id;
    $reference_map->{'attributes'} = $self->sql->get_attributes(
        cmap_object => $self,
        object_type => 'map',
        object_id   => $map_id,
    );
    $self->get_multiple_xrefs(
        object_type => 'map',
        objects     => [$reference_map]
    );

    #
    # Get the reference map features.
    #
    # REPLACE 70 YYY
    my $features = $sql_object->get_features(
        cmap_object       => $self,
        fmap_id           => $map_id,
        feature_type_aids =>
          [ ( @$feature_type_aids, @$corr_only_feature_type_aids ) ],
        map_start => $map_start,
        map_stop  => $map_stop,
    );

    # REPLACE 47 FCOUNT YYY
    my $feature_count_by_type = $sql_object->get_feature_count(
        cmap_object           => $self,
        map_id                => $map_id,
        group_by_feature_type => 1,
    );

    #
    # Page the data here so as to reduce the calls below
    # for the comparative map info.
    #
    my $pager = Data::Pageset->new(
        {
            total_entries    => scalar @$features,
            entries_per_page => $page_size,
            current_page     => $page_no,
            pages_per_set    => $max_pages,
        }
    );
    $features = [ $pager->splice($features) ]
      if $page_data && @$features;

    # REPLACE 48 ALIAS YYY

    #
    # Get all the feature types on all the maps.
    #
    # REPLACE 49 FT YYY
    my $tempFeatureTypes = $sql_object->get_used_feature_types(
        cmap_object => $self,
        map_ids     => [
            map { keys( %{ $self->slot_info->{$_} } ) }
              keys %{ $self->slot_info }
        ],
    );

    my @feature_types =
      sort { lc $a->{'feature_type'} cmp lc $b->{'feature_type'} }
      @{$tempFeatureTypes};

    #
    # Correspondence evidence types.
    #
    my @evidence_types =
      sort { lc $a->{'evidence_type'} cmp lc $b->{'evidence_type'} } @{
        $self->fake_selectall_arrayref(
            $self->evidence_type_data(),
            'evidence_type_accession as evidence_type_aid',
            'evidence_type'
        )
      };

    #
    # Find every other map position for the features on this map.
    #
    my %comparative_maps;
    for my $feature (@$features) {

        # REPLACE 71 FCS
        my $positions = $sql_object->get_feature_correspondence_details(
            cmap_object                 => $self,
            feature_id1                 => $feature->{'feature_id'},
            map_set_aid2                => $comparative_map_set_aid,
            map_aid2                    => $comparative_map_aid,
            included_evidence_type_aids => \@$included_evidence_type_aids,
            less_evidence_type_aids     => $less_evidence_type_aids,
            greater_evidence_type_aids  => $greater_evidence_type_aids,
            evidence_type_score         => $evidence_type_score,
        );

        my ( %distinct_positions, %evidence );
        for my $position (@$positions) {
            my $map_set_aid = $position->{'map_set_aid2'};
            my $map_aid     = $position->{'map_aid2'};
            $comparative_maps{$map_set_aid}{'map_aid'} =
              $position->{'map_aid2'};
            $comparative_maps{$map_set_aid}{'map_type_display_order'} =
              $position->{'map_type_display_order2'};
            $comparative_maps{$map_set_aid}{'map_type'} =
              $position->{'map_type2'};
            $comparative_maps{$map_set_aid}{'species_display_order'} =
              $position->{'species_display_order2'};
            $comparative_maps{$map_set_aid}{'species_common_name'} =
              $position->{'species_common_name2'};
            $comparative_maps{$map_set_aid}{'ms_display_order'} =
              $position->{'ms_display_order2'};
            $comparative_maps{$map_set_aid}{'map_set'} =
              $position->{'map_set2'};
            $comparative_maps{$map_set_aid}{'map_set_name'} =
              $position->{'map_set_name2'};
            $comparative_maps{$map_set_aid}{'map_set_aid'} =
              $position->{'map_set_aid2'};
            $comparative_maps{$map_set_aid}{'published_on'} =
              parsedate( $position->{'published_on'} );

            unless ( defined $comparative_maps{$map_set_aid}{'maps'}{$map_aid} )
            {
                $comparative_maps{$map_set_aid}{'maps'}{$map_aid} = {
                    display_order => $position->{'map_display_order2'},
                    map_name      => $position->{'map_name2'},
                    map_aid       => $position->{'map_aid2'},
                };
            }

            $distinct_positions{ $position->{'feature_id2'} } = $position;
            push @{ $evidence{ $position->{'feature_id2'} } },
              $position->{'evidence_type2'};
        }

        for my $position ( values %distinct_positions ) {
            $position->{'evidence'} = $evidence{ $position->{'feature_id2'} };
        }

        $feature->{'no_positions'} = scalar keys %distinct_positions;
        $feature->{'positions'}    = [ values %distinct_positions ];

        for my $val (
            $feature->{'feature_name'},
            @{ $feature->{'aliases'} || [] },
            $feature->{'feature_aid'}
          )
        {
            if ( $highlight_hash->{ uc $val } ) {
                $feature->{'highlight_color'} =
                  $self->config_data('feature_highlight_bg_color');
            }
        }
    }

    my @comparative_maps;
    for my $map_set (
        sort {
            $a->{'map_type_display_order'} <=> $b->{'map_type_display_order'}
              || $a->{'map_type'} cmp $b->{'map_type'}
              || $a->{'species_display_order'} <=> $b->{'species_display_order'}
              || $a->{'species_common_name'} cmp $b->{'species_common_name'}
              || $a->{'ms_display_order'} <=> $b->{'ms_display_order'}
              || $b->{'published_on'} <=> $a->{'published_on'}
              || $a->{'map_set_name'} cmp $b->{'map_set_name'}
        } values %comparative_maps
      )
    {
        my @maps = sort {
                 $a->{'display_order'} <=> $b->{'display_order'}
              || $a->{'map_name'} cmp $b->{'map_name'}
        } values %{ $map_set->{'maps'} };

        push @comparative_maps,
          {
            map_set_name => $map_set->{'species_common_name'} . ' - '
              . $map_set->{'map_set_short_name'},
            map_set_aid => $map_set->{'map_set_aid'},
            map_type    => $map_set->{'map_type'},
            maps        => \@maps,
          };
    }

    return {
        features              => $features,
        feature_count_by_type => $feature_count_by_type,
        feature_types         => \@feature_types,
        evidence_types        => \@evidence_types,
        reference_map         => $reference_map,
        comparative_maps      => \@comparative_maps,
        pager                 => $pager,
    };
}

# ----------------------------------------------------
sub map_type_viewer_data {

=pod

=head2 map_type_viewer_data

Returns data on map types.

=cut

    my ( $self, %args ) = @_;
    my @return_array;

    my @map_types = keys( %{ $self->config_data('map_type') } );

    my $map_type_data = $self->map_type_data();
    my %supplied_map_types;
    if ( $args{'map_types'} ) {
        %supplied_map_types = map { $_ => 1 } @{ $args{'map_types'} };
    }

    foreach my $map_type (@map_types) {
        if (%supplied_map_types) {
            next unless $supplied_map_types{$map_type};
        }
        my @attributes = ();
        my @xrefs      = ();

        # Get Attributes from config file
        my $configured_attributes = $map_type_data->{$map_type}{'attribute'};
        if ( ref($configured_attributes) ne 'ARRAY' ) {
            $configured_attributes = [ $configured_attributes, ];
        }
        foreach my $att (@$configured_attributes) {
            next
              unless ( defined( $att->{'name'} )
                and defined( $att->{'value'} ) );
            push @attributes,
              {
                attribute_name  => $att->{'name'},
                attribute_value => $att->{'value'},
                is_public       => defined( $att->{'is_public'} )
                ? $att->{'is_public'}
                : 1,
              };
        }

        # Get Xrefs from config file
        my $configured_xrefs = $map_type_data->{$map_type}{'xref'};
        if ( ref($configured_xrefs) ne 'ARRAY' ) {
            $configured_xrefs = [ $configured_xrefs, ];
        }
        foreach my $xref (@$configured_xrefs) {
            next
              unless ( defined( $xref->{'name'} )
                and defined( $xref->{'url'} ) );
            push @xrefs,
              {
                xref_name => $xref->{'name'},
                xref_url  => $xref->{'url'},
              };
        }

        $return_array[ ++$#return_array ] = {
            map_type_aid      => $map_type,
            map_type          => $map_type_data->{$map_type}{'map_type'},
            shape             => $map_type_data->{$map_type}{'shape'},
            color             => $map_type_data->{$map_type}{'color'},
            width             => $map_type_data->{$map_type}{'width'},
            display_order     => $map_type_data->{$map_type}{'display_order'},
            map_units         => $map_type_data->{$map_type}{'map_units'},
            is_relational_map =>
              $map_type_data->{$map_type}{'is_relational_map'},
            'attributes' => \@attributes,
            'xrefs'      => \@xrefs,
        };
    }

    my $default_color = $self->config_data('map_color');

    my $all_map_types =
      $self->fake_selectall_arrayref( $map_type_data,
        'map_type_accession as map_type_aid', 'map_type' );
    $all_map_types = sort_selectall_arrayref( $all_map_types, 'map_type' );

    for my $mt (@return_array) {
        $mt->{'width'} ||= DEFAULT->{'map_width'};
        $mt->{'shape'} ||= DEFAULT->{'map_shape'};
        $mt->{'color'} ||= DEFAULT->{'map_color'};
    }

    @return_array =
      sort { lc $a->{'feature_type'} cmp lc $b->{'feature_type'} }
      @return_array;

    return {
        all_map_types => $all_map_types,
        map_types     => \@return_array,
    };
}

# ----------------------------------------------------
sub species_viewer_data {

=pod

=head2 species_viewer_data

Returns data on species.

=cut

    my ( $self, %args ) = @_;
    my @species_aids = @{ $args{'species_aids'} || [] };
    my $sql_object   = $self->sql;

    # REPLACE 50 YYY
    my $species = $sql_object->get_species(
        cmap_object  => $self,
        species_aids => \@species_aids,
    );

    # REPLACE 51 YYY
    my $all_species = $sql_object->get_species( cmap_object => $self, );

    # REPLACE 52 ATT YYY
    my $attributes = $sql_object->get_attributes(
        cmap_object => $self,
        object_type => 'species',
        get_all     => 1,
        order_by    => ' object_id, display_order, attribute_name ',
    );

    my %attr_lookup;
    for my $attr (@$attributes) {
        push @{ $attr_lookup{ $attr->{'object_id'} } }, $attr;
    }

    for my $s (@$species) {
        $s->{'object_id'}  = $s->{'species_id'};
        $s->{'attributes'} = $attr_lookup{ $s->{'species_id'} };

        # REPLACE 53 MAP_SET YYY
        $s->{'map_sets'} = $sql_object->get_map_sets(
            cmap_object => $self,
            species_id  => $s->{'species_id'},
        );
    }

    $self->get_multiple_xrefs(
        object_type => 'species',
        objects     => $species,
    );

    return {
        all_species => $all_species,
        species     => $species,
    };
}

# ----------------------------------------------------
sub view_feature_on_map {

=pod

=head2 view_feature_on_map


=cut

    my ( $self, $feature_aid ) = @_;
    my $sql_object = $self->sql or return;

    # REPLACE 54 YYY
    my ( $map_set_aid, $map_aid, $feature_name );
    my $return_object = $sql_object->get_features(
        cmap_object => $self,
        feature_aid => $feature_aid,
    );

    if ( $return_object and $return_object->[0] ) {
        $map_set_aid  = $return_object->[0]{'map_set_aid'};
        $map_aid      = $return_object->[0]{'map_aid'};
        $feature_name = $return_object->[0]{'feature_name'};
    }

    return ( $map_set_aid, $map_aid, $feature_name );
}

# ----------------------------------------------------
sub count_correspondences {

    my ( $self, %args ) = @_;
    my $included_evidence_type_aids = $args{'included_evidence_type_aids'};
    my $ignored_evidence_type_aids  = $args{'ignored_evidence_type_aids'};
    my $less_evidence_type_aids     = $args{'less_evidence_type_aids'};
    my $greater_evidence_type_aids  = $args{'greater_evidence_type_aids'};
    my $evidence_type_score         = $args{'evidence_type_score'};
    my $map_correspondences         = $args{'map_correspondences'};
    my $this_slot_no                = $args{'this_slot_no'};
    my $ref_slot_no                 = $args{'ref_slot_no'};
    my $maps                        = $args{'maps'};
    my $sql_object                  = $self->sql;

    my $cluster_no          = $self->cluster_corr;
    my $show_intraslot_corr =
      ( $self->show_intraslot_corr
          and scalar( keys( %{ $self->slot_info->{$this_slot_no} } ) ) > 1 );

    #
    # Query for the counts of correspondences.
    #
    my $map_corr_counts = [];
    if ( defined $ref_slot_no or $show_intraslot_corr ) {

        # REPLACE 55 CORRCOUNTS YYY
        $map_corr_counts = $sql_object->get_feature_correspondence_count(
            cmap_object => $self,
            slot_info   => $self->slot_info->{$this_slot_no},
            slot_info2  => defined($ref_slot_no)
            ? $self->slot_info->{$ref_slot_no}
            : {},
            clustering                  => $cluster_no,
            split_evidence_types        => $self->split_agg_ev,
            show_intraslot_corr         => $show_intraslot_corr,
            included_evidence_type_aids => $included_evidence_type_aids,
            ignored_evidence_type_aids  => $ignored_evidence_type_aids,
            less_evidence_type_aids     => $less_evidence_type_aids,
            greater_evidence_type_aids  => $greater_evidence_type_aids,
            evidence_type_score         => $evidence_type_score,
        );

    }

    my %map_id_lookup = map { $_->{'map_id'}, 1 } @$maps;
    my %corr_lookup;
    if (@$map_corr_counts) {
        if ($cluster_no) {

            # Make the position values
            foreach my $row (@$map_corr_counts) {
                $row->{'position1'} =
                  defined( $row->{'stop_position1'} )
                  ? ( ( $row->{'stop_position1'} - $row->{'start_position1'} ) /
                      2 ) + $row->{'start_position1'}
                  : $row->{'start_position1'};
                $row->{'position2'} =
                  defined( $row->{'stop_position2'} )
                  ? ( ( $row->{'stop_position2'} - $row->{'start_position2'} ) /
                      2 ) + $row->{'start_position2'}
                  : $row->{'start_position2'};
                if ( $row->{'map_id1'} == 55571 ) {
                }

            }

            my %params = (
                nclusters => $cluster_no,
                transpose => 0,
                npass     => 100,
                method    => 'a',
                dist      => 'e',
            );

            my %corr_data;
            my $cluster_array;
            my $weight = [ 1, 1 ];
            my $mask;
            my ( $no_corr, $min_pos1, $max_pos1, $min_pos2, $max_pos2 );
            my ( $avg_pos1, $avg_pos2, $total_pos1, $total_pos2 );

            for my $count (@$map_corr_counts) {
                next unless $map_id_lookup{ $count->{'map_id1'} };
                push @{ $corr_data{ $count->{'map_id1'} }{ $count->{'map_id2'} }
                      { $count->{'evidence_type_aid'} } },
                  [ $count->{'position1'}, $count->{'position2'} ];
            }
            foreach my $map_id1 ( keys(%corr_data) ) {
                foreach my $map_id2 ( keys( %{ $corr_data{$map_id1} } ) ) {
                    foreach
                      my $et_aid ( keys( %{ $corr_data{$map_id1}{$map_id2} } ) )
                    {
                        $cluster_array =
                          $corr_data{$map_id1}{$map_id2}{$et_aid};
                        foreach (@$cluster_array) {
                            push @$mask, [ 1, 1 ];
                        }
                        my ( $clusters, $centroids, $error, $found ) = kcluster(
                            %params,
                            data   => $cluster_array,
                            mask   => $mask,
                            weight => $weight,
                        );
                        foreach my $cluster_id ( 0 .. $cluster_no - 1 ) {
                            ### Get the positions of the corrs in this cluster.
                            my @cluster_positions = map { $cluster_array->[$_] }
                              grep { $clusters->[$_] == $cluster_id }
                              ( 0 .. $#{$cluster_array} );
                            $no_corr    = 0;
                            $total_pos1 = 0;
                            $total_pos2 = 0;
                            ( $min_pos1, $max_pos1, $min_pos2, $max_pos2 ) =
                              ( undef, undef, undef, undef );
                            foreach my $pos_array (@cluster_positions) {
                                my ( $pos1, $pos2 ) = @$pos_array;
                                $no_corr++;
                                $total_pos1 += $pos1;
                                $total_pos2 += $pos2;
                                $min_pos1 = $pos1
                                  if ( not defined($min_pos1)
                                    or $min_pos1 > $pos1 );
                                $max_pos1 = $pos1
                                  if ( not defined($max_pos1)
                                    or $max_pos1 < $pos1 );
                                $min_pos2 = $pos2
                                  if ( not defined($min_pos2)
                                    or $min_pos2 > $pos2 );
                                $max_pos2 = $pos2
                                  if ( not defined($max_pos2)
                                    or $max_pos2 < $pos2 );
                            }
                            $avg_pos1 = $no_corr ? $total_pos1 / $no_corr : 0;
                            $avg_pos2 = $no_corr ? $total_pos2 / $no_corr : 0;

                            # The reference map is now number 2
                            # meaning that map_id2 is the old ref_map_id
                            push
                              @{ $map_correspondences->{$this_slot_no}{$map_id1}
                                  {$map_id2} },
                              {
                                evidence_type_aid => $et_aid,
                                map_id1           => $map_id1,
                                map_id2           => $map_id2,
                                no_corr           => $no_corr,
                                min_start1        => $min_pos1,
                                max_start1        => $max_pos1,
                                min_start2        => $min_pos2,
                                max_start2        => $max_pos2,
                                avg_mid1          => $avg_pos1,
                                avg_mid2          => $avg_pos2,
                                start_avg2        => $avg_pos1,
                                start_avg1        => $avg_pos2,
                              };
                            $corr_lookup{$map_id1} += $no_corr;
                        }

                    }
                }
            }
        }
        else {
            for my $count (@$map_corr_counts) {
                next unless $map_id_lookup{ $count->{'map_id1'} };

                # The reference map is now number 2
                # meaning that map_id2 is the old ref_map_id
                push @{ $map_correspondences->{$this_slot_no}
                      { $count->{'map_id1'} }{ $count->{'map_id2'} } },
                  {
                    evidence_type_aid => $count->{'evidence_type_aid'},
                    map_id1           => $count->{'map_id1'},
                    map_id2           => $count->{'map_id2'},
                    no_corr           => $count->{'no_corr'},
                    min_start1        => $count->{'min_start1'},
                    max_start1        => $count->{'max_start1'},
                    min_start2        => $count->{'min_start2'},
                    max_start2        => $count->{'max_start2'},
                    avg_mid1          => $count->{'avg_mid1'},
                    avg_mid2          => $count->{'avg_mid2'},
                    start_avg2        => $count->{'start_avg2'},
                    start_avg1        => $count->{'start_avg1'},
                  };
                $corr_lookup{ $count->{'map_id1'} } += $count->{'no_corr'};
            }
        }
    }
    return \%corr_lookup;
}

# ----------------------------------------------------

=pod

=head2 cmap_map_search_data

Returns the data for the map_search page.

=cut

sub cmap_map_search_data {

    my ( $self, %args ) = @_;
    my $slots = $args{'slots'} or return;
    my $min_correspondence_maps = $args{'min_correspondence_maps'} || 0;
    my $min_correspondences     = $args{'min_correspondences'}     || 0;
    my $feature_type_aids       = $args{'included_feature_types'}  || [];
    my $ref_species_aid         = $args{'ref_species_aid'}         || '';
    my $page_no                 = $args{'page_no'}                 || 1;
    my $name_search             = $args{'name_search'}             || '';
    my $order_by                = $args{'order_by'}                || '';
    my $ref_map                 = $slots->{0};
    my $ref_map_set_aid         = $ref_map->{'map_set_aid'}        || 0;
    my $sql_object = $self->sql or return;
    my $pid = $$;
    my $no_maps;

    my @ref_maps;

    if ( $self->slot_info ) {
        foreach my $map_id ( keys( %{ $self->slot_info->{0} } ) ) {
            my %temp_hash = (
                'map_id'         => $self->slot_info->{0}{$map_id}[0],
                'start_position' => $self->slot_info->{0}{$map_id}[1],
                'stop_position'  => $self->slot_info->{0}{$map_id}[2],
            );
            push @ref_maps, \%temp_hash;
        }
    }

    my $sql_str;
    if ( $ref_map_set_aid && !$ref_species_aid ) {

        # REPLACE 56 SPID YYY
        $ref_species_aid = $sql_object->get_species_aid(
            cmap_object => $self,
            map_set_aid => $ref_map_set_aid,
        );
    }

    #
    # Select all Species with map set
    #

    # REPLACE 57 YYY
    my $ref_species = $sql_object->get_species(
        cmap_object => $self,
        is_enabled  => 1,
    );

    if ( @$ref_species && !$ref_species_aid ) {
        $ref_species_aid = $ref_species->[0]{'species_aid'};
    }

    #
    # Select all the map sets that can be reference maps.
    #
    my $ref_map_sets = [];
    if ($ref_species_aid) {

        # REPLACE 72 MAP_SET YYY
        $ref_map_sets = $sql_object->get_map_sets(
            cmap_object => $self,
            species_aid => $ref_species_aid,
            is_enabled  => 1,
        );
    }

    #
    # If there's only one map set, pretend it was submitted.
    #
    if ( !$ref_map_set_aid && scalar @$ref_map_sets == 1 ) {
        $ref_map_set_aid = $ref_map_sets->[0]{'map_set_aid'};
    }
    my $ref_map_set_id;
    ###Get ref_map_set_id
    if ($ref_map_set_aid) {

        # REPLACE 58 YYY
        $ref_map_set_id = $self->sql->acc_id_to_internal_id(
            cmap_object => $self,
            object_type => 'map_set',
            acc_id      => $ref_map_set_aid,
        );
    }

    #
    # If the user selected a map set, select all the maps in it.
    #
    my ( $map_info, @map_ids, $ref_map_set_info );
    my ( $feature_info, @feature_type_aids );

    # REPLACE 59
    my $cache_key =
        $ref_map_set_id . "-"
      . $name_search . "-"
      . $min_correspondence_maps . "-"
      . $min_correspondences;
    if ($ref_map_set_id) {
        ###Get map info
        unless ( $map_info =
            $self->get_cached_results( 4, "get_map_search_info" . $cache_key ) )
        {
            $map_info = $sql_object->get_map_search_info(
                cmap_object             => $self,
                map_set_id              => $ref_map_set_id,
                map_name                => $name_search,
                min_correspondence_maps => $min_correspondence_maps,
                min_correspondences     => $min_correspondences,
            );
            $self->error(
qq[No maps exist for the ref. map set acc. id "$ref_map_set_aid"]
              )
              unless %$map_info;

            ### Work out the numbers per unit and reformat them.
            foreach my $map_id ( keys(%$map_info) ) {
                ### Comp Map Count
                my $raw_no = (
                    $map_info->{$map_id}{'cmap_count'} / (
                        $map_info->{$map_id}{'stop_position'} -
                          $map_info->{$map_id}{'start_position'}
                    )
                );
                $map_info->{$map_id}{'cmap_count_per'} =
                  presentable_number_per($raw_no);
                $map_info->{$map_id}{'cmap_count_per_raw'} = $raw_no;
                ### Correspondence Count
                $raw_no = (
                    $map_info->{$map_id}{'corr_count'} / (
                        $map_info->{$map_id}{'stop_position'} -
                          $map_info->{$map_id}{'start_position'}
                    )
                );
                $map_info->{$map_id}{'corr_count_per'} =
                  presentable_number_per($raw_no);
                $map_info->{$map_id}{'corr_count_per_raw'} = $raw_no;

            }
            $self->store_cached_results( 4, "get_map_search_info" . $cache_key,
                $map_info );
        }
        @map_ids = keys(%$map_info);

        ### Add feature type information
        # REPLACE 60 FCOUNT YYY
        my $feature_info_results;
        if ( @map_ids and ( $min_correspondence_maps or $min_correspondences ) )
        {
            $feature_info_results = $sql_object->get_feature_count(
                cmap_object           => $self,
                map_ids               => [ keys(%$map_info) ],
                map_name              => $name_search,
                group_by_map_id       => 1,
                group_by_feature_type => 1,
            );
        }
        else {
            $feature_info_results = $sql_object->get_feature_count(
                cmap_object           => $self,
                map_set_id            => $ref_map_set_id,
                map_name              => $name_search,
                group_by_map_id       => 1,
                group_by_feature_type => 1,
            );
        }

        my %feature_type_hash;
        foreach my $row (@$feature_info_results) {
            $feature_type_hash{ $row->{'feature_type_aid'} } = 1;
            $feature_info->{ $row->{'map_id'} }{ $row->{'feature_type_aid'} }
              {'total'} = $row->{'feature_count'};
            my $devisor =
              $map_info->{ $row->{'map_id'} }{'stop_position'} -
              $map_info->{ $row->{'map_id'} }{'start_position'}
              || 1;

            my $raw_no = ( $row->{'feature_count'} / $devisor );
            $feature_info->{ $row->{'map_id'} }{ $row->{'feature_type_aid'} }
              {'raw_per'} = $raw_no;
            $feature_info->{ $row->{'map_id'} }{ $row->{'feature_type_aid'} }
              {'per'} = presentable_number_per($raw_no);
        }
        @feature_type_aids = keys(%feature_type_hash);

        ###Sort maps
        if (
            my $array_ref = $self->get_cached_results(
                4, "sort_maps_" . $cache_key . $order_by
            )
          )
        {
            @map_ids = @$array_ref;
        }
        else {
            if ( $order_by =~ /^feature_total_(\S+)/ ) {
                my $ft_aid = $1;
                @map_ids = sort {
                    $feature_info->{$b}{$ft_aid}
                      {'total'} <=> $feature_info->{$a}{$ft_aid}{'total'}
                } @map_ids;
            }
            elsif ( $order_by =~ /^feature_per_(\S+)/ ) {
                my $ft_aid = $1;
                @map_ids = sort {
                    $feature_info->{$b}{$ft_aid}
                      {'raw_per'} <=> $feature_info->{$a}{$ft_aid}{'raw_per'}
                } @map_ids;
            }
            elsif ( $order_by eq "display_order" or !$order_by ) {
                ###DEFAULT sort
                @map_ids = sort {
                    $map_info->{$a}{'display_order'} <=> $map_info->{$b}
                      {'display_order'}
                } @map_ids;
            }
            else {
                @map_ids = sort {
                    $map_info->{$b}{$order_by} <=> $map_info->{$a}{$order_by}
                } @map_ids;
            }
            $self->store_cached_results( 4,
                "sort_maps_" . $cache_key . $order_by, \@map_ids );
        }
    }

    my %feature_types =
      map { $_ => $self->feature_type_data($_) } @feature_type_aids;

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $pager = Data::Pageset->new(
        {
            total_entries    => scalar @map_ids,
            current_page     => $page_no,
            entries_per_page => 25,
            pages_per_set    => 1,
        }
    );
    @map_ids = $pager->splice( \@map_ids ) if @map_ids;
    $no_maps = scalar @map_ids;

    return {
        ref_species_aid   => $ref_species_aid,
        ref_species       => $ref_species,
        ref_map_sets      => $ref_map_sets,
        ref_map_set_aid   => $ref_map_set_aid,
        map_info          => $map_info,
        feature_info      => $feature_info,
        no_maps           => $no_maps,
        map_ids           => \@map_ids,
        feature_type_aids => \@feature_type_aids,
        feature_types     => \%feature_types,
        pager             => $pager,
    };
}

# ----------------------------------------------------

=pod

=head2 cmap_spider_links

Returns the links for the spider page.

=cut

sub cmap_spider_links {

    my ( $self, %args ) = @_;
    my $map_aid          = $args{'map_aid'};
    my $degrees_to_crawl = $args{'degrees_to_crawl'};
    my $min_corrs        = $args{'min_corrs'};
    my $apr              = $args{'apr'};

    return []
      unless ( $map_aid
        and defined($degrees_to_crawl)
        and $degrees_to_crawl =~ /^\d+$/ );

    my $sql_object = $self->sql or return;

    my %seen_map_ids        = ();
    my %map_aids_per_degree = ();
    my @links               = ();

    my $url;
    if ($apr) {
        $url = $apr->url . '/';
    }
    else {
        $url = '';
    }
    my $map_viewer_url = $url . 'viewer';

    # Set up degree 0.
    $seen_map_ids{$map_aid} = {};
    $map_aids_per_degree{0} = [ $map_aid, ];

    my $link = $self->create_viewer_link(
        ref_map_aids        => \%seen_map_ids,
        data_source         => $self->data_source,
        url                 => $map_viewer_url,
        min_correspondences => $min_corrs,
    );
    push @links,
      {
        link       => $link,
        tier_maps  => scalar( @{ $map_aids_per_degree{0} } ),
        total_maps => scalar( keys %seen_map_ids ),
      };
    for ( my $i = 1 ; $i <= $degrees_to_crawl ; $i++ ) {
        last unless ( defined( $map_aids_per_degree{ $i - 1 } ) );

        # REPLACE 61 CORRCOUNTS YYY
        my $query_results = $sql_object->get_comparative_maps_with_count(
            cmap_object         => $self,
            map_aids            => $map_aids_per_degree{ $i - 1 },
            ignore_map_aids     => [ keys(%seen_map_ids) ],
            min_correspondences => $min_corrs,
        );

        # Add results to data structures.
        foreach my $row ( @{$query_results} ) {
            unless ( $seen_map_ids{ $row->{'map_aid2'} } ) {
                push @{ $map_aids_per_degree{$i} }, $row->{'map_aid2'};
                $seen_map_ids{ $row->{'map_aid2'} } = {};
            }
        }

        # We're done if there are no new maps
        last unless ( defined( $map_aids_per_degree{$i} ) );

        my $map_order = '';
        for ( my $j = 0 ; $j <= $i ; $j++ ) {
            $map_order .= join( ":", sort @{ $map_aids_per_degree{$j} } ) . ",";
        }

        $link = $self->create_viewer_link(
            ref_map_aids        => \%seen_map_ids,
            data_source         => $self->data_source,
            url                 => $map_viewer_url,
            ref_map_order       => $map_order,
            min_correspondences => $min_corrs,
        );
        push @links,
          {
            link       => $link,
            tier_maps  => scalar( @{ $map_aids_per_degree{$i} } ),
            total_maps => scalar( keys %seen_map_ids ),
          };
    }

    return \@links;
}

# ----------------------------------------------------
sub get_all_feature_types {
    my $self = shift;

    my $slot_info  = $self->slot_info;
    my $sql_object = $self->sql;
    my @map_id_list;
    foreach my $slot_no ( keys %{$slot_info} ) {
        push @map_id_list, keys( %{ $slot_info->{$slot_no} } );
    }
    return [] unless @map_id_list;

    # REPLACE 62 FT YYY
    my $return = $sql_object->get_used_feature_types(
        cmap_object => $self,
        map_ids     => \@map_id_list,
    );

    return $return;
}

# ----------------------------------------------------
sub get_max_unit_size {
    my $self  = shift;
    my $slots = shift;

    my %max_per_unit;

    foreach my $slot_id ( keys %$slots ) {
        foreach my $map_id ( keys %{ $slots->{$slot_id} } ) {
            my $map = $slots->{$slot_id}{$map_id};
            unless ($max_per_unit{ $map->{'map_units'} }
                and $max_per_unit{ $map->{'map_units'} } >
                ( $map->{'stop_position'} - $map->{'start_position'} ) )
            {
                $max_per_unit{ $map->{'map_units'} } =
                  $map->{'stop_position'} - $map->{'start_position'};
            }
        }
    }

    return \%max_per_unit;
}

# ----------------------------------------------------
sub get_ref_unit_size {
    my $self  = shift;
    my $slots = shift;

    my $scale_conversion = $self->scale_conversion;
    my %ref_for_unit;
    my %set_by_slot;
    foreach my $slot_id ( sort orderOutFromZero keys %$slots ) {
      MAPID: foreach my $map_id ( keys %{ $slots->{$slot_id} } ) {
            my $map      = $slots->{$slot_id}{$map_id};
            my $map_unit = $map->{'map_units'};

            # If the unit size is already defined by a different
            # slot, we don't want to redifine it.
            if (    defined( $set_by_slot{$map_unit} )
                and $set_by_slot{$map_unit} != $slot_id
                and $ref_for_unit{$map_unit} )
            {
                last MAPID;
            }

            $set_by_slot{$map_unit} = $slot_id;

            # If there is a unit defined that we have a conversion
            # factor for, use that.
            if ( $scale_conversion->{$map_unit} ) {
                while ( my ( $unit, $conversion ) =
                    each %{ $scale_conversion->{$map_unit} } )
                {
                    if ( $ref_for_unit{$unit} ) {
                        $ref_for_unit{$map_unit} =
                          $ref_for_unit{$unit} * $conversion;
                        last MAPID;
                    }
                }
            }

            # If the unit hasn't been defined or
            # this map is bigger, set ref_for_unit
            if ( !$ref_for_unit{$map_unit}
                or $ref_for_unit{$map_unit} <
                $map->{'stop_position'} - $map->{'start_position'} )
            {
                $ref_for_unit{$map_unit} =
                  $map->{'stop_position'} - $map->{'start_position'};
            }
        }
    }

    return \%ref_for_unit;
}

# ----------------------------------------------------
sub scale_conversion {

=pod

=head2 scale_conversion

Returns a hash with the conversion factors between unit types as defined in the
config file.

=cut

    my $self = shift;

    unless ( $self->{'scale_conversion'} ) {
        my $config_scale = $self->config_data('scale_conversion');
        if ($config_scale) {
            while ( my ( $unit1, $convs ) = each %$config_scale ) {
                while ( my ( $unit2, $factor ) = each %$convs ) {
                    $self->{'scale_conversion'}{$unit2}{$unit1} = $factor;
                    $self->{'scale_conversion'}{$unit1}{$unit2} = 1 / $factor;
                }
            }
        }
    }
    return $self->{'scale_conversion'};
}

# ----------------------------------------------------
sub compress_maps {

=pod

=head2 compress_maps

Decide if the maps should be compressed.
If it is aggregated, compress unless the slot contain only 1 map.
If it is not aggregated, don't compress 

=cut

    my $self         = shift;
    my $this_slot_no = shift;

    return unless defined $this_slot_no;
    return 0 if ( $this_slot_no == 0 );
    return $self->{'compressed_maps'}{$this_slot_no}
      if defined( $self->{'compressed_maps'}{$this_slot_no} );

    if ( scalar( keys( %{ $self->slot_info->{$this_slot_no} } ) ) > 1
        and $self->aggregate )
    {
        $self->{'compressed_maps'}{$this_slot_no} = 1;
    }
    else {
        $self->{'compressed_maps'}{$this_slot_no} = 0;

    }

    return $self->{'compressed_maps'}{$this_slot_no};
}

# ----------------------------------------------------
sub getDisplayedStartStop {

=pod

=head2 getDisplayedStartStop

get start and stop of a map set.

=cut

    my $self    = shift;
    my $slot_no = shift;
    my $map_id  = shift;
    return ( undef, undef )
      unless ( defined($slot_no) and defined($map_id) );

    my ( $start, $stop );
    if (    $self->slot_info->{$slot_no}
        and %{ $self->slot_info->{$slot_no} }
        and @{ $self->slot_info->{$slot_no}{$map_id} } )
    {
        my $map_info = $self->slot_info->{$slot_no}{$map_id};
        if ( defined( $map_info->[0] ) ) {
            $start = $map_info->[0];
        }
        else {
            $start = $map_info->[2];
        }
        if ( defined( $map_info->[1] ) ) {
            $stop = $map_info->[1];
        }
        else {
            $stop = $map_info->[3];
        }
    }
    return ( $start, $stop );

}

# ----------------------------------------------------
sub truncatedMap {

=pod

=head2 truncatedMap

test if the map is truncated

=cut

    my $self    = shift;
    my $slot_no = shift;
    my $map_id  = shift;
    return undef
      unless ( defined($slot_no) and defined($map_id) );

    if (    $self->slot_info->{$slot_no}
        and %{ $self->slot_info->{$slot_no} }
        and @{ $self->slot_info->{$slot_no}{$map_id} } )
    {
        my $map_info = $self->slot_info->{$slot_no}{$map_id};
        if ( defined( $map_info->[0] ) and defined( $map_info->[1] ) ) {
            return 3;
        }
        elsif ( defined( $map_info->[0] ) ) {
            return 1;
        }
        elsif ( defined( $map_info->[1] ) ) {
            return 2;
        }
        return 0;
    }
    return undef;
}

# ----------------------------------------------------
sub scroll_data {

=pod

=head2 scroll_data

return the start and stop for the scroll buttons

=cut

    my $self       = shift;
    my $slot_no    = shift;
    my $map_id     = shift;
    my $is_flipped = shift;
    my $dir        = shift;
    my $is_up      = ( $dir eq 'UP' );
    return ( undef, undef, 1 )
      unless ( defined($slot_no) and defined($map_id) );

    if (    $self->slot_info->{$slot_no}
        and %{ $self->slot_info->{$slot_no} }
        and @{ $self->slot_info->{$slot_no}{$map_id} } )
    {
        my $map_info = $self->slot_info->{$slot_no}{$map_id};

        my $mag = $map_info->[4] || 1;
        return ( undef, undef, $mag )
          unless ( defined( $map_info->[0] )
            or defined( $map_info->[1] ) );

        my $start = $map_info->[0];
        my $stop  = $map_info->[1];

        if (   ( $is_up and not $is_flipped )
            or ( $is_flipped and not $is_up ) )
        {

            # Scroll data for up arrow
            return ( undef, undef, $mag ) unless defined($start);
            my $view_length =
              defined($stop)
              ? ( $stop - $start )
              : $map_info->[3] - $start;
            my $new_start = $start - ( $view_length / 2 );
            my $new_stop = $new_start + $view_length;
            if ( $new_start <= $map_info->[2] ) {

                # Start is smaller than real map start.  Use the real map start;
                $new_start = "''";
                $new_stop  = $map_info->[2] + $view_length;
            }
            if ( $new_stop >= $map_info->[3] ) {

                # Stop is greater than the real end.
                $new_stop = "''";
            }

            return ( $new_start, $new_stop, $mag );
        }
        else {

            # Scroll data for down arrow
            return ( undef, undef, $mag ) unless defined($stop);
            my $view_length =
              defined($start)
              ? ( $stop - $start )
              : $stop - $map_info->[2];
            my $new_stop = $stop + ( $view_length / 2 );
            my $new_start = $new_stop - $view_length;
            if ( $new_stop >= $map_info->[3] ) {

                # Start is smaller than real map start.  Use the real map start;
                $new_stop  = "''";
                $new_start = $map_info->[3] - $view_length;
            }
            if ( $new_start <= $map_info->[2] ) {

                # Stop is greater than the real end.
                $new_stop = "''";
            }

            return ( $new_start, $new_stop, $mag );
        }
    }
    return ( undef, undef, 1 );
}

# ----------------------------------------------------
sub magnification {

=pod

=head2 magnification

Given the slot_no and map_id

=cut

    my $self    = shift;
    my $slot_no = shift;
    my $map_id  = shift;
    return 1 unless defined $slot_no and defined $map_id;

    if (    $self->slot_info->{$slot_no}
        and %{ $self->slot_info->{$slot_no} }
        and @{ $self->slot_info->{$slot_no}{$map_id} } )
    {
        my $map_info = $self->slot_info->{$slot_no}{$map_id};
        if ( defined( $map_info->[4] ) ) {
            return $map_info->[4];
        }
    }

    return 1;
}

# ----------------------------------------------------
sub feature_default_display {

=pod

=head2 feature_default_display

Given the slot_no and map_id

=cut

    my $self                        = shift;
    my $url_feature_default_display = shift;

    if ( defined($url_feature_default_display) ) {
        if ( $url_feature_default_display == 0 ) {
            $self->{'feature_default_display'} = 'ignore';
        }
        elsif ( $url_feature_default_display == 1 ) {
            $self->{'feature_default_display'} = 'corr_only';
        }
        elsif ( $url_feature_default_display == 2 ) {
            $self->{'feature_default_display'} = 'display';
        }
    }

    unless ( $self->{'feature_default_display'} ) {
        my $feature_default_display =
          $self->config_data('feature_default_display');
        $feature_default_display = lc($feature_default_display);
        unless ( $feature_default_display eq 'corr_only'
            or $feature_default_display eq 'ignore' )
        {
            $feature_default_display = 'display';    #Default value
        }
        $self->{'feature_default_display'} = $feature_default_display;
    }

    return $self->{'feature_default_display'};
}

# ----------------------------------------------------
sub evidence_default_display {

=pod

=head2 evidence_default_display

Given the slot_no and map_id

=cut

    my $self = shift;

    unless ( $self->{'evidence_default_display'} ) {
        my $evidence_default_display =
          $self->config_data('evidence_default_display');
        $evidence_default_display = lc($evidence_default_display);
        unless ( $evidence_default_display eq 'ignore' ) {
            $evidence_default_display = 'display';    #Default value
        }
        $self->{'evidence_default_display'} = $evidence_default_display;
    }

    return $self->{'evidence_default_display'};
}

# ----------------------------------------------------
sub ref_map_order_hash {

=pod

=head2 ref_map_order_hash

Uses ref_map_order() to create a hash designating the maps order.

=cut

    my $self = shift;

    unless ( $self->{'ref_map_order_hash'} ) {
        my %return_hash      = ();
        my $ref_map_order    = $self->ref_map_order();
        my @ref_map_aid_list = split( /[,]/, $ref_map_order );
        for ( my $i = 0 ; $i <= $#ref_map_aid_list ; $i++ ) {
            my @ref_map_aids = split( /[:]/, $ref_map_aid_list[$i] );
            foreach my $aid (@ref_map_aids) {
                my $map_id = $self->sql->acc_id_to_internal_id(
                    cmap_object => $self,
                    object_type => 'map',
                    acc_id      => $aid,
                );
                $return_hash{$map_id} = $i + 1;
            }
        }
        $self->{'ref_map_order_hash'} = \%return_hash;
    }

    return $self->{'ref_map_order_hash'};
}

# ----------------------------------------------------
sub ref_maps_equal {

=pod

=head2 ref_maps_equal

Uses ref_map_order_hash() to compare the placement of each map
in the order.  returns 1 if they are equally placed.

=cut

    my $self          = shift;
    my $first_map_id  = shift;
    my $second_map_id = shift;
    my %map_order     = %{ $self->ref_map_order_hash };

    return 0 unless (%map_order);

    if ( $map_order{$first_map_id} and $map_order{$second_map_id} ) {
        return ( $map_order{$first_map_id} == $map_order{$second_map_id} );
    }

    return 0;
}

# ----------------------------------------------------
sub cmp_ref_map_order {

=pod

=head2 cmp_ref_map_order

Uses ref_map_order_hash() to compare the placement of each map
in the order.  returns -1, 0 or 1 as cmp does.

=cut

    my $self          = shift;
    my $first_map_id  = shift;
    my $second_map_id = shift;
    my %map_order     = %{ $self->ref_map_order_hash };

    return 0 unless (%map_order);

    if ( $map_order{$first_map_id} and $map_order{$second_map_id} ) {
        return ( $map_order{$first_map_id} <=> $map_order{$second_map_id} );
    }
    elsif ( $map_order{$first_map_id} ) {
        return -1;
    }
    else {
        return 1;
    }
}

# ----------------------------------------------------
sub sorted_map_ids {

=pod

=head2 sorted_map_ids

Sets and returns the sorted map ids for each slot

=cut

    my $self      = shift;
    my $slot_no   = shift;
    my $slot_data = shift;

    if ($slot_data) {
        my @map_ids = keys(%$slot_data);
        if ( $slot_no == 0 ) {
            @map_ids =
              map  { $_->[0] }
              sort {
                (        $self->cmp_ref_map_order( $a->[0], $b->[0] )
                      || $a->[1] <=> $b->[1]
                      || $a->[2] cmp $b->[2]
                      || $a->[0] <=> $b->[0] )
              }
              map {
                [
                    $_,
                    $slot_data->{$_}{'display_order'},
                    $slot_data->{$_}{'map_name'},
                ]
              } @map_ids;
        }
        else {
            @map_ids =
              map  { $_->[0] }
              sort { $b->[1] <=> $a->[1] }
              map  { [ $_, $self->{'maps'}{$_}{'no_correspondences'} ] }
              @map_ids;
        }
        $self->{'sorted_map_ids'}{$slot_no} = \@map_ids;
    }
    if ( defined($slot_no) ) {
        return $self->{'sorted_map_ids'}{$slot_no} || [];
    }
    return $self->{'sorted_map_ids'} || [];
}

# ----------------------------------------------------
sub slot_info {

=pod
                                                                                
=head2 slot_info

Stores and retrieve the slot info.

Creates and returns some map info for each slot.

Data Structure:
  slot_info  =  {
    slot_no  => {
      map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ]
    }
  }

"current_start" and "current_stop" are undef if using the 
original start and stop. 

=cut

    my $self                        = shift;
    my $slots                       = shift;
    my $ignored_feature_list        = shift;
    my $included_evidence_type_aids = shift;
    my $less_evidence_type_aids     = shift;
    my $greater_evidence_type_aids  = shift;
    my $evidence_type_score         = shift;
    my $min_correspondences         = shift;
    my $sql_object                  = $self->sql;

    # Return slot_info is not setting it.
    return $self->{'slot_info'} unless ($slots);

    # REPLACE 63 YYY
    $self->{'slot_info'} = $sql_object->get_slot_info(
        cmap_object                 => $self,
        slots                       => $slots,
        ignored_feature_type_aids   => $ignored_feature_list,
        included_evidence_type_aids => $included_evidence_type_aids,
        less_evidence_type_aids     => $less_evidence_type_aids,
        greater_evidence_type_aids  => $greater_evidence_type_aids,
        evidence_type_score         => $evidence_type_score,
        min_correspondences         => $min_correspondences,
    );

    #print S#TDERR Dumper($self->{'slot_info'})."\n";
    return $self->{'slot_info'};
}

sub orderOutFromZero {
    ###Return the sort in this order (0,1,-1,-2,2,-3,3,)
    return ( abs($a) cmp abs($b) );
}

1;

# ----------------------------------------------------
# An aged man is but a paltry thing,
# A tattered coat upon a stick.
# William Butler Yeats
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>, L<DBI>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

