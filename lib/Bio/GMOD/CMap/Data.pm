package Bio::GMOD::CMap::Data;

# vim: set ft=perl:

# $Id: Data.pm,v 1.198.2.13 2005-03-15 14:40:11 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.198.2.13 $)[-1];

use Cache::FileCache;
use Data::Dumper;
use Date::Format;
use Regexp::Common;
use Time::ParseDate;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Utils;
use Bio::GMOD::CMap::Admin::Export;
use Bio::GMOD::CMap::Admin::ManageLinks;
use Storable qw(freeze thaw);

use base 'Bio::GMOD::CMap';

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->config( $config->{'config'} );
    $self->data_source( $config->{'data_source'} );
    $self->aggregate( $config->{'aggregate'} );

    ### Create the cache objects for each of the levels
    ### For and explaination of the cache levels, see
    ### the comments above the cache subroutines
    ### titled "Query Caching"
    my @level_names = $self->cache_level_names();
    for ( my $i = 0 ; $i <= $#level_names ; $i++ ) {
        my %cache_params = ( 'namespace' => $level_names[$i], );
        $self->{ 'L' . ( $i + 1 ) . '_cache' } =
          new Cache::FileCache( \%cache_params );
    }

    $self->{'disable_cache'} = $self->config_data('disable_cache');
    return $self;
}

# ----------------------------------------------------
sub acc_id_to_internal_id {

=pod

=head2 acc_id_to_internal_id

Given an accession id for a particular table, find the internal id.  Expects:

    table   : the name of the table from which to select 
    acc_id  : the value of the accession id
    id_field: (opt.) the name of the internal id field

=cut

    my ( $self, %args ) = @_;
    my $table  = $args{'table'}  or $self->error('No table');
    my $acc_id = $args{'acc_id'} or $self->error('No accession id');
    my $id_field = $args{'id_field'} || '';

    #
    # If no "id_field" param, then strip "cmap_" off the table
    # name and append "_id".
    #
    unless ($id_field) {
        if ( $table =~ m/^cmap_(.+)$/ ) {
            $id_field = $1 . '_id';
        }
        else {
            $self->error(qq[No id field and I cannot figure it out]);
        }
    }

    my $db      = $self->db or return;
    my $sql_str = qq[
            select $id_field
            from   $table
            where  accession_id=?
	  ];
    my $id;
    if ( my $scalarref = $self->get_cached_results( '', $sql_str . $acc_id ) ) {
        $id = $$scalarref;
    }
    else {
        $id = $db->selectrow_array( $sql_str, {}, ($acc_id) )
          or $self->error(
qq[Unable to find internal id for acc. id "$acc_id" in table "$table"]
          );
        $self->store_cached_results( '', $sql_str . $acc_id, \$id );
    }
    return $id;
}

# ----------------------------------------------------

=pod

=head2 correspondence_detail_data

Gets the specifics on a feature correspondence record.

=cut

sub correspondence_detail_data {

    #p#rint S#TDERR "correspondence_detail_data\n";
    my ( $self, %args ) = @_;
    my $correspondence_aid = $args{'correspondence_aid'}
      or return $self->error('No correspondence accession ID');
    my $evidence_type_data = $self->evidence_type_data();
    my $db                 = $self->db;
    my $sql                = q[
            select feature_correspondence_id,
                   accession_id,
                   feature_id1,
                   feature_id2,
                   is_enabled
            from   cmap_feature_correspondence
            where  accession_id=?
		 ];
    my ( $corr, $feature1, $feature2 );

    if ( my $array_ref =
        $self->get_cached_results( 4, $sql . $correspondence_aid ) )
    {
        ( $corr, $feature1, $feature2 ) = @$array_ref;
    }
    else {
        my $sth = $db->prepare($sql);
        $sth->execute($correspondence_aid);

        $corr = $sth->fetchrow_hashref
          or return $self->error(
            "No record for correspondence accession ID '$correspondence_aid'");

        $corr->{'attributes'} = $self->get_attributes(
            'cmap_feature_correspondence',
            $corr->{'feature_correspondence_id'},
        );

        $corr->{'xrefs'} = $self->get_xrefs(
            'cmap_feature_correspondence',
            $corr->{'feature_correspondence_id'},
        );

        $sth = $db->prepare(
            q[
            select f.feature_id, 
                   f.accession_id as feature_aid, 
                   f.map_id,
                   f.accession_id as map_aid,
                   f.feature_type_accession as feature_type_aid,
                   f.feature_name,
                   f.start_position,
                   f.stop_position,
                   map.map_name,
                   map.accession_id as map_aid,
                   ms.map_set_id,
                   ms.accession_id as map_set_aid,
                   ms.short_name as map_set_name,
                   s.common_name as species_name,
                   ms.map_units
            from   cmap_feature f,
                   cmap_map map,
                   cmap_map_set ms,
                   cmap_species s
            where  f.feature_id=?
            and    f.map_id=map.map_id
            and    map.map_set_id=ms.map_set_id
            and    ms.species_id=s.species_id
	      ]
        );
        $sth->execute( $corr->{'feature_id1'} );
        $feature1 = $sth->fetchrow_hashref;
        $sth->execute( $corr->{'feature_id2'} );
        $feature2 = $sth->fetchrow_hashref;

        for ( $feature1, $feature2 ) {
            $_->{'aliases'} =
              $db->selectcol_arrayref(
                'select alias from cmap_feature_alias where feature_id=?',
                {}, ( $_->{'feature_id'} ) );
        }

        $corr->{'evidence'} = $db->selectall_arrayref(
            qq[
            select   ce.correspondence_evidence_id,
                     ce.accession_id,
                     ce.feature_correspondence_id,
                     ce.score,
                     ce.evidence_type_accession as evidence_type_aid
            from     cmap_correspondence_evidence ce
            where    ce.feature_correspondence_id=?
        ],
            { Columns => {} },
            ( $corr->{'feature_correspondence_id'} )
        );

        foreach my $row ( @{ $corr->{'evidence'} } ) {
            $row->{'rank'} =
              $evidence_type_data->{ $row->{'evidence_type_aid'} }{'rank'};
            $row->{'evidence_type'} =
              $evidence_type_data->{ $row->{'evidence_type_aid'} }
              {'evidence_type'};
        }

        $corr->{'evidence'} =
          sort_selectall_arrayref( $corr->{'evidence'}, '#$rank',
            'evidence_type' );
        $self->store_cached_results(
            4,
            $sql . $correspondence_aid,
            [ $corr, $feature1, $feature2 ]
        );
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

    my $db = $self->db;
    my ( $map_set_id, $map_id );
    if ($map_aid) {
        $map_id =
          $db->selectrow_array(
            'select map_id from cmap_map where accession_id=?',
            {}, ($map_aid) )
          or return $self->error("'$map_aid' is not a valid map accession ID");
    }

    if ($map_set_aid) {
        $map_set_id =
          $db->selectrow_array(
            'select map_set_id from cmap_map_set where accession_id=?',
            {}, ($map_set_aid) )
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
        my $feature_sql = q[
            select map.accession_id as map_accession_id,
                   map.map_name,
                   map.start_position as map_start,
                   map.stop_position as map_stop,
                   f.feature_id,
                   f.accession_id as feature_accession_id,
                   f.feature_name,
                   f.start_position as feature_start,
                   f.stop_position as feature_stop,
                   f.is_landmark,
                   f.feature_type_accession as feature_type_aid
            from   cmap_map map,
                   cmap_feature f
            where  map.%s=?
            and    map.map_id=f.map_id
        ];

        my $alias_sql = q[
            select fa.feature_id, 
                   fa.alias
            from   cmap_map map,
                   cmap_feature f,
                   cmap_feature_alias fa
            where  map.%s=?
            and    map.map_id=f.map_id
            and    f.feature_id=fa.feature_id
        ];

        my ( $field_name, $search_val );
        if ($map_aid) {
            $field_name = 'map_id';
            $search_val = $map_id;
        }
        else {
            $field_name = 'map_set_id';
            $search_val = $map_set_id;
        }

        my $features = $db->selectall_arrayref(
            sprintf( $feature_sql, $field_name ),
            { Columns => {} },
            ($search_val)
        );

        foreach my $row ( @{$features} ) {
            $row->{'feature_type'} =
              $self->feature_type_data( $row->{'feature_type_aid'},
                'feature_type' );
        }

        if ( $format eq 'TAB' ) {
            my $aliases = $db->selectall_arrayref(
                sprintf( $alias_sql, $field_name ),
                { Columns => {} },
                ($search_val)
            );
            my %alias_lookup = ();
            for my $alias (@$aliases) {
                push @{ $alias_lookup{ $alias->{'feature_id'} } },
                  $alias->{'alias'};
            }

            my @cols = qw[ map_accession_id map_name map_start map_stop
              feature_accession_id feature_name feature_aliases feature_start
              feature_stop feature_type_aid is_landmark
            ];

            $return = join( "\t", @cols ) . "\n";

            for my $f (@$features) {
                $f->{'feature_aliases'} = join( ',',
                    sort @{ $alias_lookup{ $f->{'feature_id'} } || [] } );
                $return .= join( "\t", map { $f->{$_} } @cols ) . "\n";
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
    my $corr_only_feature_type_aids = $args{'corr_only_feature_type_aids'} || [];
    my $ignored_feature_type_aids   = $args{'ignored_feature_type_aids'} || [];
    my $ignored_evidence_type_aids  = $args{'ignored_evidence_type_aids'} || [];
    my $included_evidence_type_aids = $args{'included_evidence_type_aids'} || [];
    my $less_evidence_type_aids     = $args{'less_evidence_type_aids'} || [];
    my $greater_evidence_type_aids  = $args{'greater_evidence_type_aids'} || [];
    my $evidence_type_score         = $args{'evidence_type_score'} || {};
    my $db  = $self->db or return;
    my $pid = $$;

    # Fill the default array with any feature types not accounted for.
    my $feature_default_display = $self->feature_default_display;

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
    foreach my $et ( @$included_evidence_type_aids, @$ignored_evidence_type_aids,
                @$less_evidence_type_aids, @$greater_evidence_type_aids,)
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
    $self->slot_info( $slots, $ignored_feature_type_aids,
        $included_evidence_type_aids, $less_evidence_type_aids,
        $greater_evidence_type_aids, $evidence_type_score,
        $min_correspondences,);

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
            feature_type_aids           => $included_feature_type_aids,
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

    my ( $self, %args ) = @_;
    my $db  = $self->db  or return;
    my $sql = $self->sql or return;
    my $this_slot_no                = $args{'slot_no'};
    my $ref_slot_no                 = $args{'ref_slot_no'};
    my $min_correspondences         = $args{'min_correspondences'} || 0;
    my $feature_type_aids           = $args{'feature_type_aids'};
    my $included_evidence_type_aids = $args{'included_evidence_type_aids'};
    my $ignored_evidence_type_aids  = $args{'ignored_evidence_type_aids'};
    my $less_evidence_type_aids     = $args{'less_evidence_type_aids'};
    my $greater_evidence_type_aids  = $args{'greater_evidence_type_aids'};
    my $evidence_type_score         = $args{'evidence_type_score'};
    my $slot_map                    = ${ $args{'map'} };                 # hashref
    my $reference_map               = $args{'reference_map'};
    my $feature_correspondences     = $args{'feature_correspondences'};
    my $intraslot_correspondences   = $args{'intraslot_correspondences'};
    my $map_correspondences         = $args{'map_correspondences'};
    my $correspondence_evidence     = $args{'correspondence_evidence'};
    my $feature_types_seen          = $args{'feature_types'};
    my $corr_only_feature_type_aids = $args{'corr_only_feature_type_aids'};
    my $ignored_feature_type_aids   = $args{'ignored_feature_type_aids'};
    my $map_type_aids               = $args{'map_type_aids'};
    my $pid                         = $args{'pid'};
    my $feature_type_data           = $self->feature_type_data();
    my $map_type_data               = $self->map_type_data();

    my $max_no_features = 200000;

    #print S#TDERR "slot_data $this_slot_no\n";
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
    my $map_sub = sub {
        my $data = shift;
        foreach my $row ( @{$data} ) {
            $row->{'default_shape'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'shape'};
            $row->{'default_color'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'color'};
            $row->{'default_width'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'width'};
            $row->{'map_type'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'map_type'};
        }
    };
    if ( $self->slot_info->{$this_slot_no}
        and %{ $self->slot_info->{$this_slot_no} } )
    {
        my $sql = q[
                    select map.map_id,
                           map.accession_id,
                           map.map_name,
                           map.start_position,
                           map.stop_position,
                           map.display_order,
                           ms.map_set_id,
                           ms.accession_id as map_set_aid,
                           ms.short_name as map_set_name,
                           ms.shape,
                           ms.width,
                           ms.color,
                           ms.map_type_accession as map_type_aid,
                           ms.map_units,
                           ms.is_relational_map,
                           s.species_id,
                           s.accession_id as species_aid,
                           s.common_name as species_name
                    from   cmap_map map,
                           cmap_map_set ms,
                           cmap_species s
                    where  map.map_id in (]
          . join( ',', keys( %{ $self->slot_info->{$this_slot_no} } ) ) . q[)
                    and    map.map_set_id=ms.map_set_id
                    and    ms.species_id=s.species_id
		  ];
        my $tempMap = $self->cache_array_results( 2, $sql, { Columns => {} },
            [], $db, 'selectall_arrayref', $map_sub );

        foreach my $row (@$tempMap) {
            if (
                defined(
                    $self->slot_info->{$this_slot_no}{ $row->{'map_id'} }
                )
                and defined(
                    $self->slot_info->{$this_slot_no}{ $row->{'map_id'} }[0]
                )
                and ( $self->slot_info->{$this_slot_no}{ $row->{'map_id'} }[0] >
                    $row->{'start_position'} )
              )
            {
                $row->{'start_position'} =
                  $self->slot_info->{$this_slot_no}{ $row->{'map_id'} }[0];
            }
            if (
                defined(
                    $self->slot_info->{$this_slot_no}{ $row->{'map_id'} }
                )
                and defined(
                    $self->slot_info->{$this_slot_no}{ $row->{'map_id'} }[1]
                )
                and defined( $row->{'stop_position'} )
                and ( $self->slot_info->{$this_slot_no}{ $row->{'map_id'} }[1] )
                < $row->{'stop_position'}
              )
            {
                $row->{'stop_position'} =
                  $self->slot_info->{$this_slot_no}{ $row->{'map_id'} }[1];
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
    my $ft_sql = qq[
        select   distinct
                 f.feature_type_accession as feature_type_aid
        from     cmap_feature f
        where
    ];
    $ft_sql .=
      " f.map_id in ('"
      . join( "','", keys( %{ $self->slot_info->{$this_slot_no} } ) ) . "')";
    if (@$feature_type_aids) {
        $ft_sql .=
          " and f.feature_type_accession in ('"
          . join( "','", @$feature_type_aids ) . "')";
    }
    my $ft;
    unless ( $ft = $self->get_cached_results( 3, $ft_sql ) ) {
        $ft = $db->selectall_hashref( $ft_sql, 'feature_type_aid', {}, () );
        foreach my $rowKey ( keys %{$ft} ) {
            $ft->{$rowKey}->{'feature_type'} =
              $feature_type_data->{ $ft->{$rowKey}->{'feature_type_aid'} }
              {'feature_type'};
            $ft->{$rowKey}->{'shape'} =
              $feature_type_data->{ $ft->{$rowKey}->{'feature_type_aid'} }
              {'shape'};
            $ft->{$rowKey}->{'color'} =
              $feature_type_data->{ $ft->{$rowKey}->{'feature_type_aid'} }
              {'color'};
        }
        $self->store_cached_results( 3, $ft_sql, $ft );
    }
    $feature_types_seen->{$_} = $ft->{$_} for keys %$ft;

    #
    # check to see if it is compressed
    #
    if ( !$self->{'aggregate'} or !$self->compress_maps($this_slot_no) ) {

        #
        # Figure out how many features are on each map.
        #
        my %count_lookup;
        my $f_count_sql = qq[
            select   count(f.feature_id) as no_features, f.map_id
            from     cmap_feature f
            where    
        ];

        # Include current slot maps
        my $slot_info            = $self->slot_info->{$this_slot_no};
        my @unrestricted_map_ids = ();
        my $unrestricted_sql     = '';
        my $restricted_sql       = '';
        foreach my $slot_map_id ( keys( %{$slot_info} ) ) {

            # $slot_info->{$slot_map_id}->[0] is start [1] is stop
            if (    defined( $slot_info->{$slot_map_id}->[0] )
                and defined( $slot_info->{$slot_map_id}->[1] ) )
            {
                $restricted_sql .=
                    " or (f.map_id="
                  . $slot_map_id
                  . " and (( f.start_position>="
                  . $slot_info->{$slot_map_id}->[0]
                  . " and f.start_position<="
                  . $slot_info->{$slot_map_id}->[1]
                  . " ) or ( f.stop_position is not null and "
                  . "  f.start_position<="
                  . $slot_info->{$slot_map_id}->[0]
                  . " and f.stop_position>="
                  . $slot_info->{$slot_map_id}->[0] . " )))";
            }
            elsif ( defined( $slot_info->{$slot_map_id}->[0] ) ) {
                $restricted_sql .=
                    " or (f.map_id="
                  . $slot_map_id
                  . " and (( f.start_position>="
                  . $slot_info->{$slot_map_id}->[0]
                  . " ) or ( f.stop_position is not null "
                  . " and f.stop_position>="
                  . $slot_info->{$slot_map_id}->[0] . " )))";
            }
            elsif ( defined( $slot_info->{$slot_map_id}->[1] ) ) {
                $restricted_sql .=
                    " or (f.map_id="
                  . $slot_map_id
                  . " and f.start_position<="
                  . $slot_info->{$slot_map_id}->[1] . ") ";
            }
            else {
                push @unrestricted_map_ids, $slot_map_id;
            }
        }
        if (@unrestricted_map_ids) {
            $unrestricted_sql =
              " or f.map_id in (" . join( ',', @unrestricted_map_ids ) . ") ";
        }

        my $combined_sql = $restricted_sql . $unrestricted_sql;
        $combined_sql =~ s/^\s+or//;
        if ($combined_sql) {
            $f_count_sql .= " and (" . $combined_sql . ")";
        }
        else {    #No maps
            $f_count_sql .= " f.feature_id = -1 ";
        }

        # Remove the instance of "where and"
        $f_count_sql =~ s/where\s+and/where /;
        $f_count_sql .= " group by f.map_id";
        my $f_counts =
          $self->cache_array_results( 3, $f_count_sql, { Columns => {} },
            [], $db, 'selectall_arrayref' );

        for my $f (@$f_counts) {
            $count_lookup{ $f->{'map_id'} } = $f->{'no_features'};
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
                db                          => $db,

            )
          };

        for my $map (@maps) {
            my $map_start =
              $self->slot_info->{$this_slot_no}{ $map->{'map_id'} }[0];
            my $map_stop =
              $self->slot_info->{$this_slot_no}{ $map->{'map_id'} }[1];
            $map->{'start_position'} = $map_start if defined($map_start);
            $map->{'stop_position'}  = $map_stop  if defined($map_stop);
            $map->{'no_correspondences'} = $corr_lookup{ $map->{'map_id'} };
            if ( $min_correspondences
                && defined $ref_slot_no
                && $map->{'no_correspondences'} < $min_correspondences ){
                delete $self->{'slot_info'}{$this_slot_no}{ $map->{'map_id'} };
                next;
            }
            $map->{'no_features'} = $count_lookup{ $map->{'map_id'} };
            my $where =
              @$feature_type_aids
              ? " and f.feature_type_accession in ('"
              . join( "','", @$feature_type_aids ) . "')"
              : '';
            ###
            my $sql_base_top = qq[
                    select   f.feature_id,
                             f.accession_id,
                             f.map_id,
                             f.feature_name,
                             f.is_landmark,
                             f.start_position,
                             f.stop_position,
                             f.feature_type_accession as feature_type_aid,
                             f.direction,
                             map.accession_id as map_aid,
                             ms.map_units
                    from     cmap_feature f,
                             cmap_map map,
                             cmap_map_set ms
				];
            my $sql_base_bottom = qq[
                    where    f.map_id=$map->{'map_id'}
				   ];
            my $alias_sql = qq [
                    select  fa.feature_id,
                            fa.alias
                    from    cmap_feature f,
                            cmap_feature_alias fa
                    where   f.map_id=$map->{'map_id'}
                        and f.feature_id = fa.feature_id 
            ];
            if ( defined($map_start) and defined($map_stop) ) {
                my $tmp_sql = qq[
		       and      (
                        ( f.start_position>=$map_start and 
                          f.start_position<=$map_stop )
                        or   (
                            f.stop_position is not null and
                            f.start_position<=$map_start and
                            f.stop_position>=$map_start
                        )
				 )
		        ];
                $sql_base_bottom .= $tmp_sql;
                $alias_sql       .= $tmp_sql;
            }
            elsif ( defined($map_start) ) {
                my $tmp_sql =
                    " and (( f.start_position>="
                  . $map_start
                  . " ) or ( f.stop_position is not null and "
                  . " f.stop_position>="
                  . $map_start . " ))";
                $sql_base_bottom .= $tmp_sql;
                $alias_sql       .= $tmp_sql;
            }
            elsif ( defined($map_stop) ) {
                my $tmp_sql = " and f.start_position<=" . $map_stop . " ";
                $sql_base_bottom .= $tmp_sql;
                $alias_sql       .= $tmp_sql;
            }

            $sql_base_bottom .= qq[
                    and      f.map_id=map.map_id
                    and      map.map_set_id=ms.map_set_id
			   ];
            my $corr_free_sql = $sql_base_top . $sql_base_bottom . $where;
            my $with_corr_sql = '';
            if ( @$corr_only_feature_type_aids or @$ignored_feature_type_aids )
            {
                $corr_free_sql .= " and f.feature_type_accession not in ('"
                  . join( "','",
                    @$corr_only_feature_type_aids,
                    @$ignored_feature_type_aids )
                  . "')";
            }
            my $sql_str = $corr_free_sql;

            #$sql_str .= " and f.feature_id=-1 "
            #  if ( $corr_only_feature_type_aids->[0] == -1 );
            if (
                (@$corr_only_feature_type_aids)
                and (  $self->slot_info->{ $this_slot_no + 1 }
                    || $self->slot_info->{ $this_slot_no - 1 } )
              )
            {
                my $map_id_string .= " and f2.map_id in ("
                  . join(
                    ",",
                    (
                        $self->slot_info->{ $this_slot_no + 1 } ?
                          keys( %{ $self->slot_info->{ $this_slot_no + 1 } } )
                        : ()
                    ),
                    (
                        $self->slot_info->{ $this_slot_no - 1 } ?
                          keys( %{ $self->slot_info->{ $this_slot_no - 1 } } )
                        : ()
                    )
                  )
                  . ")";
                $with_corr_sql = $sql_base_top . q[,
                  cmap_feature f2,
                  cmap_correspondence_lookup cl
                  ] . $sql_base_bottom . q[
                and cl.feature_id1=f.feature_id
                and cl.feature_id2=f2.feature_id];
                if (   @$corr_only_feature_type_aids
                    or @$ignored_feature_type_aids )
                {
                    $with_corr_sql .=
                      " and f.feature_type_accession in ('"
                      . join( "','", @$corr_only_feature_type_aids ) . "')";
                }
                $with_corr_sql .= $map_id_string;
            }

            #
            # Decide what sql will be used
            #
            if ( @$corr_only_feature_type_aids and @$feature_type_aids ) {
                $sql_str = $corr_free_sql;
                $sql_str .= " UNION " . $with_corr_sql if ($with_corr_sql);
            }
            elsif (@$corr_only_feature_type_aids) {
                if ($with_corr_sql) {
                    $sql_str = $with_corr_sql;
                }
                else {
                    ###Return nothing
                    $sql_str = $corr_free_sql . " and map.map_id=-1 ";
                }
            }
            elsif (@$feature_type_aids) {
                $sql_str = $corr_free_sql;
            }
            else {
                ###Return nothing
                $sql_str = $corr_free_sql . " and map.map_id=-1 ";

                #$sql_str = $corr_free_sql . " UNION " . $with_corr_sql;
            }

            unless ( $map->{'features'} =
                $self->get_cached_results( 4, $sql_str ) )
            {

                # Get feature aliases
                my $alias_results =
                  $db->selectall_arrayref( $alias_sql, { Columns => {} }, () );
                my %aliases = ();
                foreach my $row (@$alias_results) {
                    push @{ $aliases{ $row->{'feature_id'} } }, $row->{'alias'};
                }

                $map->{'features'} =
                  $db->selectall_hashref( $sql_str, 'feature_id', {}, () );

                for my $feature_id ( keys %{ $map->{'features'} } ) {
                    my $ft =
                      $feature_type_data->{ $map->{'features'}{$feature_id}
                          {'feature_type_aid'} };

                    $map->{'features'}{$feature_id}{$_} = $ft->{$_} for qw[
                      feature_type default_rank shape color
                      drawing_lane drawing_priority
                    ];

                    $map->{'features'}{$feature_id}{'aliases'} =
                      $aliases{$feature_id};
                }

                $self->store_cached_results( 4, $sql_str, $map->{'features'} );
            }

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
                    [ @$feature_type_aids, @$corr_only_feature_type_aids ],
                    $map_start,
                    $map_stop
                );
            }
            $return->{ $map->{'map_id'} } = $map;
        }
    }
    else {    # more than one map in this slot
              #
              # Figure out how many features are on each map.
              #
        my %count_lookup;
        my $f_count_sql = qq[
            select   count(f.feature_id) as no_features, f.map_id
            from     cmap_feature f
            where    
        ];

        my $slot_maps = '';
        if ( $self->slot_info->{$this_slot_no} ) {
            $slot_maps =
              join( "','", keys( %{ $self->slot_info->{$this_slot_no} } ) );
        }

        $f_count_sql .= " f.map_id in ('" . $slot_maps . "')";
        $f_count_sql .= " group by f.map_id";
        my $f_counts;
        unless ( $f_counts = $self->get_cached_results( 3, $f_count_sql ) ) {
            $f_counts =
              $db->selectall_arrayref( $f_count_sql, { Columns => {} }, () );
            $self->store_cached_results( 3, $f_count_sql, $f_counts );
        }

        for my $f (@$f_counts) {
            $count_lookup{ $f->{'map_id'} } = $f->{'no_features'};
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
                db                          => $db,

            )
          };

        for my $map (@maps) {
            my $map_start =
              $self->slot_info->{$this_slot_no}{ $map->{'map_id'} }[0];
            my $map_stop =
              $self->slot_info->{$this_slot_no}{ $map->{'map_id'} }[1];
            $map->{'start_position'} = $map_start if defined($map_start);
            $map->{'stop_position'}  = $map_stop  if defined($map_stop);
            $map->{'no_correspondences'} = $corr_lookup{ $map->{'map_id'} };
            if ( $min_correspondences
                && defined $ref_slot_no
                && $map->{'no_correspondences'} < $min_correspondences ){
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
                    [ @$feature_type_aids, @$corr_only_feature_type_aids ],
                    $map_start,
                    $map_stop
                );
            }
            $return->{ $map->{'map_id'} } = $map;
        }
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

    ###Get the feature type info
    foreach my $key ( keys %{$feature_types} ) {
        ###First get the code snippets
        $required_string =
          $self->feature_type_data( $key, 'required_page_code' );
        foreach my $snippet_aid ( split( /\s*,\s*/, $required_string ) ) {
            $snippet_aids{$snippet_aid} = 1;
        }
        ###Then get the extra form stuff
        $required_string = $self->feature_type_data( $key, 'extra_forms' );
        foreach my $extra_form_aid ( split( /\s*,\s*/, $required_string ) ) {
            $extra_form_aids{$extra_form_aid} = 1;
        }
    }

    ###Get the map type info
    foreach my $key ( keys %{$map_type_aids} ) {
        ###First get the code snippets
        $required_string = $self->map_type_data( $key, 'required_page_code' );
        foreach my $snippet_aid ( split( /\s*,\s*/, $required_string ) ) {
            $snippet_aids{$snippet_aid} = 1;
        }
        ###Then get the extra form stuff
        $required_string = $self->map_type_data( $key, 'extra_forms' );
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
        $correspondence_evidence,    $value,
        $slot_no,                    $included_evidence_type_aids,
        $ignored_evidence_type_aids, $less_evidence_type_aids, 
        $greater_evidence_type_aids, $evidence_type_score,
        $feature_type_aids,
        $map_start,                  $map_stop
      )
      = @_;
    my $db                 = $self->db;
    my $evidence_type_data = $self->evidence_type_data();
    my $to_restriction     = '';
    my $corr_sql;
    if ( defined $map_start && defined $map_stop ) {
        $to_restriction = qq[
        and      (
        ( cl.start_position2>=$map_start and 
            cl.start_position2<=$map_stop )
          or   (
            cl.stop_position2 is not null and
            cl.start_position2<=$map_start and
            cl.stop_position2>=$map_start
            )
         )
         ];
    }
    elsif ( defined($map_start) ) {
        $to_restriction .=
            " and (( cl.start_position2>="
          . $map_start
          . " ) or ( cl.stop_position2 is not null and "
          . " cl.stop_position2>="
          . $map_start . " ))";
    }
    elsif ( defined($map_stop) ) {
        $to_restriction .= " and cl.start_position2<=" . $map_stop . " ";
    }

    $corr_sql = qq[
        select   cl.feature_id1 as feature_id,
                 f2.feature_id as ref_feature_id, 
                 f2.feature_name as f2_name,
                 f2.start_position as f2_start,
                 f2.map_id,
                 cl.feature_correspondence_id,
                 ce.evidence_type_accession as evidence_type_aid
        from     cmap_feature f2, 
                 cmap_correspondence_lookup cl,
                 cmap_feature_correspondence fc,
                 cmap_correspondence_evidence ce
        where    cl.feature_correspondence_id=
                 fc.feature_correspondence_id
        and      fc.is_enabled=1
        and      fc.feature_correspondence_id=
                 ce.feature_correspondence_id
        and      cl.feature_id2=f2.feature_id
        and      f2.map_id=?
        $to_restriction
    ];

    if ( $self->slot_info->{$slot_no}
        and %{ $self->slot_info->{$slot_no} } )
    {
        $corr_sql .=
          " and cl.map_id1 in ("
          . join( ",", keys( %{ $self->slot_info->{$slot_no} } ) ) . ")";
    }

#xx1
    if ( @$included_evidence_type_aids or @$less_evidence_type_aids
            or @$greater_evidence_type_aids ) {
        $corr_sql .= "and ( ";
        my @join_array;
        if ( @$included_evidence_type_aids ) {
            push @join_array,
              " ce.evidence_type_accession in ('"
              . join( "','", @$included_evidence_type_aids ) . "')";
        }
        foreach my $et_aid (@$less_evidence_type_aids ) {
            push @join_array,
                " ( ce.evidence_type_accession = '$et_aid' "
              . " and ce.score <= ".$evidence_type_score->{$et_aid}." ) ";
        }
        foreach my $et_aid (@$greater_evidence_type_aids ) {
            push @join_array,
                " ( ce.evidence_type_accession = '$et_aid' "
              . " and ce.score >= ".$evidence_type_score->{$et_aid}." ) ";
        }
        $corr_sql .= join (' or ', @join_array). " ) ";
    }
    else {
        $corr_sql .= " and ce.correspondence_evidence_id = -1 ";
    }

    if (@$feature_type_aids) {
        $corr_sql .=
          " and cl.feature_type_accession1 in ('"
          . join( "','", @$feature_type_aids ) . "')";
    }

    my $ref_correspondences;
    unless ( $ref_correspondences =
        $self->get_cached_results( 4, $corr_sql . $value ) )
    {

        $ref_correspondences =
          $db->selectall_arrayref( $corr_sql, { Columns => {} }, ($value) );

        foreach my $row ( @{$ref_correspondences} ) {
            $row->{'evidence_rank'} =
              $evidence_type_data->{ $row->{'evidence_type_aid'} }{'rank'};
            $row->{'line_color'} =
              $evidence_type_data->{ $row->{'evidence_type_aid'} }
              {'line_color'};
            $row->{'evidence_type'} =
              $evidence_type_data->{ $row->{'evidence_type_aid'} }
              {'evidence_type'};
        }
        $self->store_cached_results( 4, $corr_sql . $value,
            $ref_correspondences );
    }
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
sub matrix_correspondence_data {

=pod

=head2 matrix_data

Returns the data for the correspondence matrix.

=cut

    my ( $self, %args ) = @_;
    my $db = $self->db or return;
    my $species_aid      = $args{'species_aid'}      || '';
    my $map_type_aid     = $args{'map_type_aid'}     || '';
    my $map_set_aid      = $args{'map_set_aid'}      || '';
    my $map_name         = $args{'map_name'}         || '';
    my $link_map_set_aid = $args{'link_map_set_aid'} || 0;

    my $map_type_data = $self->map_type_data();

    #
    # Get all the species.
    #
    my $species = $db->selectall_arrayref(
        q[
            select   distinct s.accession_id as species_aid, 
                     s.common_name,
                     s.display_order 
            from     cmap_species s,
                     cmap_map_set ms
            where    s.species_id=ms.species_id
            and      ms.is_relational_map=0
            and      ms.is_enabled=1
            order by s.display_order, s.common_name
        ],
        { Columns => {} }
    );

    #
    # And map types.
    #
    my $map_types = $db->selectall_arrayref(
        q[
            select   distinct ms.map_type_accession as map_type_aid
            from     cmap_map_set ms
            where    ms.is_relational_map=0
            and      ms.is_enabled=1
        ],
        { Columns => {} }
    );
    foreach my $row ( @{$map_types} ) {
        $row->{'map_type'} =
          $map_type_data->{ $row->{'map_type_aid'} }{'map_type'};
        $row->{'display_order'} =
          $map_type_data->{ $row->{'map_type_aid'} }{'display_order'};
    }

    $map_types =
      sort_selectall_arrayref( $map_types, '#display_order', 'map_type' );

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
    if ( $map_set_aid && !$species_aid ) {
        $species_aid = $db->selectrow_array(
            q[
                select s.accession_id
                from   cmap_map_set ms,
                       cmap_species s
                where  ms.accession_id=?
                and    ms.species_id=s.species_id
            ],
            {},
            ($map_set_aid)
        );
    }

    #
    # Make sure that map_type_aid is set if map_set_id is.
    #
    if ( $map_set_aid && !$map_type_aid ) {
        $map_type_aid = $db->selectrow_array(
            q[
                select ms.map_type_accession as map_type_aid
                from   cmap_map_set ms
                where  ms.accession_id=?
            ],
            {},
            ($map_set_aid)
        );
    }

    #
    # Get all the map sets for a given species and/or map type.
    #
    my ( $maps, $map_sets );
    if ( $species_aid || $map_type_aid ) {
        my $sql = q[
            select   s.display_order,
                     s.common_name as species_name, 
                     ms.accession_id as map_set_aid, 
                     ms.display_order,
                     ms.short_name as map_set_name,
                     ms.map_type_accession as map_type_aid
            from     cmap_map_set ms,
                     cmap_species s
            where    ms.is_relational_map=0
            and      ms.is_enabled=1
            and      ms.species_id=s.species_id
        ];

        $sql .= " and s.accession_id='$species_aid' "         if $species_aid;
        $sql .= " and ms.map_type_accession='$map_type_aid' " if $map_type_aid;

        $map_sets = $db->selectall_arrayref( $sql, { Columns => {} } );

        foreach my $row ( @{$map_sets} ) {
            $row->{'default_display_order'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'display_order'};
            $row->{'map_type'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'map_type'};

            $row->{'epoch_published_on'} = parsedate( $row->{'published_on'} );
        }
        $map_sets = sort_selectall_arrayref(
            $map_sets,                  '#default_display_order',
            'map_type',                 '#display_order',
            'common_name',              '#display_order',
            '#epoch_published_on desc', 'short_name'
        );

        my $map_sql = qq[
            select   distinct map.map_name,
                     map.display_order
            from     cmap_map map,
                     cmap_map_set ms,
                     cmap_species s
            where    map.map_set_id=ms.map_set_id
            and      ms.is_relational_map=0
            and      ms.is_enabled=1
            and      ms.species_id=s.species_id
        ];
        $map_sql .= " and ms.map_type_accession='$map_type_aid' "
          if $map_type_aid;
        $map_sql .= " and s.accession_id='$species_aid' "  if $species_aid;
        $map_sql .= " and ms.accession_id='$map_set_aid' " if $map_set_aid;
        $map_sql .= 'order by map.display_order, map.map_name';
        $maps = $db->selectall_arrayref( $map_sql, { Columns => {} } );
    }

    #
    # Select all the map sets for the left-hand column
    # (those which can be reference sets).
    #
    my @reference_map_sets = ();
    if ($map_set_aid) {
        my $map_set_sql = qq[
            select   map.map_id, 
                     map.accession_id as map_aid,
                     map.map_name, 
                     ms.map_set_id, 
                     ms.accession_id as map_set_aid,
                     ms.short_name as map_set_name,
                     ms.map_type_accession as map_type_aid, 
                     s.species_id,
                     s.accession_id as species_aid,
                     s.common_name as species_name
            from     cmap_map map,
                     cmap_map_set ms,
                     cmap_species s
            where    map.map_set_id=ms.map_set_id
            and      ms.is_enabled=1
            and      ms.accession_id='$map_set_aid'
            and      ms.species_id=s.species_id
        ];

        $map_set_sql .= " and map.map_name='$map_name' " if $map_name;
        $map_set_sql .= 'order by map.display_order, map.map_name';

        my $tempMapSet =
          $db->selectall_arrayref( $map_set_sql, { Columns => {} } );

        foreach my $row (@$tempMapSet) {
            $row->{'map_type_display_order'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'display_order'};

            $row->{'map_type'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'map_type'};
        }

        @reference_map_sets = @$tempMapSet;
    }
    else {
        my $map_set_sql;
        if ($map_name) {
            $map_set_sql = qq[
                select   map.map_name,
                         map.accession_id as map_aid, 
                         ms.map_set_id, 
                         ms.accession_id as map_set_aid, 
                         ms.short_name as map_set_name,
                         ms.display_order as map_set_display_order,
                         ms.published_on, 
                         ms.map_type_accession as map_type_aid, 
                         s.species_id,
                         s.accession_id as species_aid,
                         s.common_name as species_name,
                         s.display_order as species_display_order
                from     cmap_map map,
                         cmap_map_set ms,
                         cmap_species s
                where    map.map_name='$map_name'
                and      map.map_set_id=ms.map_set_id
                and      ms.is_enabled=1
                and      ms.species_id=s.species_id
                and      ms.is_relational_map=0
            ];

            $map_set_sql .= " and s.accession_id='$species_aid' "
              if $species_aid;

            $map_set_sql .= " and ms.map_type_accession='$map_type_aid' "
              if $map_type_aid;

            $map_set_sql .= " and ms.accession_id='$map_set_aid' "
              if $map_set_aid;
        }
        else {
            $map_set_sql = q[
                select   ms.map_set_id, 
                         ms.accession_id as map_set_aid,
                         ms.short_name as map_set_name,
                         ms.display_order as map_set_display_order, 
                         ms.map_type_accession as map_type_aid, 
                         s.species_id,
                         s.accession_id as species_aid,
                         s.common_name as species_name,
                         s.display_order as species_display_order
                from     cmap_map_set ms,
                         cmap_species s
                where    ms.is_relational_map=0
                and      ms.is_enabled=1
                and      ms.species_id=s.species_id
            ];

            $map_set_sql .= " and s.accession_id='$species_aid' "
              if $species_aid;

            $map_set_sql .= " and ms.map_type_accession='$map_type_aid' "
              if $map_type_aid;

            $map_set_sql .= " and ms.accession_id='$map_set_aid' "
              if $map_set_aid;

        }

        my $tempMapSet =
          $db->selectall_arrayref( $map_set_sql, { Columns => {} } );

        foreach my $row ( @{$tempMapSet} ) {
            $row->{'map_type_display_order'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'display_order'};

            $row->{'map_type'} =
              $self->map_type_data->{ $row->{'map_type_aid'} }{'map_type'};
            $row->{'epoch_published_on'} = parsedate( $row->{'published_on'} );
        }

        @reference_map_sets = @{
            sort_selectall_arrayref(
                $tempMapSet,    '#map_type_display_order',
                'map_type',     '#species_display_order',
                'species_name', '#map_set_display_order',
                'map_set_name', '#epoch_published_on desc',
                'map_set_name'
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
    if ( $map_set_aid and $link_map_set_aid ) {
        $select_sql = qq[
            select   sum(cm.no_correspondences) as correspondences,
                     count(cm.link_map_aid) as map_count,
                     cm.reference_map_aid,
                     cm.reference_map_set_aid,
                     cm.reference_species_aid,
                     cm.link_map_aid,
                     cm.link_map_set_aid,
                     cm.link_species_aid
            from     cmap_correspondence_matrix cm,
                     cmap_map_set ms
            where    cm.reference_map_set_aid='$map_set_aid'
            and      cm.link_map_set_aid='$link_map_set_aid'
            and      cm.reference_map_set_aid=ms.accession_id
            and      ms.is_enabled=1
        ];

        $select_sql .= " and cm.reference_species_aid='$species_aid' "
          if $species_aid;

        $select_sql .= " and cm.reference_map_name='$map_name' "
          if $map_name;

        $select_sql .= q[
            group by cm.reference_map_aid,
                     cm.reference_map_set_aid,
                     cm.link_map_set_aid,
                     cm.reference_species_aid,
                     cm.link_map_aid,
                     cm.link_species_aid,
                     cm.link_map_set_aid
        ];
    }
    elsif ($map_set_aid) {
        $select_sql = qq[
            select   sum(cm.no_correspondences) as correspondences,
                     count(cm.link_map_aid) as map_count,
                     cm.reference_map_aid,
                     cm.reference_map_set_aid,
                     cm.reference_species_aid,
                     cm.link_map_set_aid,
                     cm.link_species_aid
            from     cmap_correspondence_matrix cm,
                     cmap_map_set ms
            where    cm.reference_map_set_aid='$map_set_aid'
            and      cm.reference_map_set_aid=ms.accession_id
        ];

        $select_sql .= " and cm.reference_species_aid='$species_aid' "
          if $species_aid;

        $select_sql .= " and cm.reference_map_name='$map_name' "
          if $map_name;

        $select_sql .= q[
            group by cm.reference_map_aid,
                     cm.reference_map_set_aid,
                     cm.link_map_set_aid,
                     cm.reference_species_aid,
                     cm.link_species_aid
        ];
    }
    else {

        #
        # This is the most generic SQL, showing all the possible
        # combinations of map sets to map sets.
        #
        $select_sql = q[
            select   sum(cm.no_correspondences) as correspondences,
                     count(cm.link_map_aid) as map_count,
                     cm.reference_map_set_aid,
                     cm.reference_species_aid,
                     cm.link_map_set_aid,
                     cm.link_species_aid
            from     cmap_correspondence_matrix cm
        ];

        #
        # I shouldn't have to worry about not having "WHERE" as
        # the user shouldn't be able to select a map name
        # without having first selected a species.
        #
        $select_sql .= "where cm.reference_species_aid='$species_aid' "
          if $species_aid;

        $select_sql .= " and cm.reference_map_name='$map_name' "
          if $map_name;

        $select_sql .= q[
            group by cm.reference_map_set_aid,
                     cm.link_map_set_aid,
                     cm.reference_species_aid,
                     cm.link_species_aid
        ];
    }
    my $data = $db->selectall_arrayref( $select_sql, { Columns => {} } );

    #
    # Create a lookup hash from the data.
    #
    my %lookup;
    for my $hr (@$data) {
        if ( $map_set_aid && $link_map_set_aid ) {

            #
            # Map sets that can't be references won't have a "link_map_id."
            #
            my $link_aid = $hr->{'link_map_aid'} || $hr->{'link_map_set_aid'};
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
        my $is_rel = $db->selectrow_array(
            q[
                select ms.is_relational_map
                from   cmap_map_set ms
                where  ms.accession_id=?
              ],
            {},
            ($link_map_set_aid)
        );

        $link_map_can_be_reference = $is_rel ? 0 : 1;
    }

    #
    # If given a map set id for a map set that can be a reference map,
    # select the individual map.  Otherwise, if given a map set id for
    # a map set that can't be a reference or if given nothing, grab
    # the entire map set.
    #
    my $link_map_set_sql;
    my $tempMapSet;
    if ( $map_set_aid && $link_map_set_aid && $link_map_can_be_reference ) {
        $link_map_set_sql = qq[
            select   map.map_id,
                     map.accession_id as map_aid,
                     map.map_name,
                     ms.map_set_id, 
                     ms.accession_id as map_set_aid, 
                     ms.short_name as map_set_name,
                     s.species_id,
                     s.accession_id as species_aid,
                     s.common_name as species_name,
                     ms.map_type_accession as map_type_aid
            from     cmap_map map,
                     cmap_map_set ms,
                     cmap_species s
            where    map.map_set_id=ms.map_set_id
            and      ms.is_enabled=1
            and      ms.accession_id='$link_map_set_aid'
            and      ms.species_id=s.species_id
            order by map.display_order, map.map_name
        ];
        $tempMapSet =
          $db->selectall_arrayref( $link_map_set_sql, { Columns => {} } );
        foreach my $row ( @{$tempMapSet} ) {
            $row->{'map_type'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'map_type'};
        }
    }
    else {
        $link_map_set_sql = q[
            select   ms.map_set_id, 
                     ms.accession_id as map_set_aid,
                     ms.short_name as map_set_name,
                     ms.display_order as map_set_display_order,
                     ms.published_on,
                     s.species_id,
                     s.accession_id as species_aid,
                     s.common_name as species_name,
                     s.display_order as species_display_order,
                     ms.map_type_accession as map_type_aid
            from     cmap_map_set ms,
                     cmap_species s
            where    ms.is_enabled=1
            and      ms.species_id=s.species_id
        ];

        $link_map_set_sql .= " and ms.accession_id='$link_map_set_aid' "
          if $link_map_set_aid;

        $tempMapSet =
          $db->selectall_arrayref( $link_map_set_sql, { Columns => {} } );
        foreach my $row ( @{$tempMapSet} ) {
            $row->{'map_type'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'map_type'};
            $row->{'map_type_display_order'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'display_order'};
            $row->{'epoch_published_on'} = parsedate( $row->{'published_on'} );
        }
        $tempMapSet = sort_selectall_arrayref(
            $tempMapSet,                '#map_type_display_order',
            'map_type',                 '#species_display_order',
            'species_name',             '#map_set_display_order',
            '#epoch_published_on desc', 'map_set_name'
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
            if ( $r_map_aid && $comp_map_aid && $r_map_aid eq $comp_map_aid ) {
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

    my ( $self, %args ) = @_;
    my $slots = $args{'slots'} or return;
    my $min_correspondences         = $args{'min_correspondences'}     || 0;
    my $feature_type_aids           = $args{'included_feature_types'}  || [];
    my $ignored_feature_type_aids   = $args{'ignored_feature_types'}   || [];
    my $included_evidence_type_aids = $args{'included_evidence_types'} || [];
    my $ignored_evidence_type_aids  = $args{'ignored_evidence_types'}  || [];
    my $less_evidence_type_aids     = $args{'less_evidence_types'} || [];
    my $greater_evidence_type_aids  = $args{'greater_evidence_types'} || [];
    my $evidence_type_score         = $args{'evidence_type_score'} || {};
    my $ref_species_aid             = $args{'ref_species_aid'}         || '';
    my $ref_map                     = $slots->{0};
    my $ref_map_set_aid             = $args{'ref_map_set_aid'}         || 0;
    my $evidence_type_data          = $self->evidence_type_data();
    my $map_type_data               = $self->map_type_data();
    my $db  = $self->db  or return;
    my $sql = $self->sql or return;

    my $pid = $$;

    my @ref_maps = ();

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
        $sql_str = q[
                select s.accession_id
                from   cmap_map_set ms,
                       cmap_species s
                where  ms.accession_id=?
                and    ms.species_id=s.species_id
		      ];
        if ( my $scalar_ref =
            $self->get_cached_results( 1, $sql_str . $ref_map_set_aid ) )
        {
            $ref_species_aid = $$scalar_ref;
        }
        else {
            $ref_species_aid =
              $db->selectrow_array( $sql_str, {}, ($ref_map_set_aid) );
            $self->store_cached_results( 1, $sql_str . $ref_map_set_aid,
                \$ref_species_aid );
        }
    }

    #
    # Select all the species of map sets that can be reference maps.
    #
    $sql_str = q[
            select   distinct s.accession_id as species_aid,
                     s.display_order,
                     s.common_name as species_common_name,
                     s.full_name as species_full_name
            from     cmap_map_set ms,
                     cmap_species s
            where    ms.is_enabled=1
            and      ms.is_relational_map=0
            and      ms.species_id=s.species_id
            order by s.display_order,
                     s.common_name, 
                     s.full_name
	      ];
    my $ref_species;
    my $scalar_ref;

    if ( $scalar_ref = $self->get_cached_results( 1, $sql_str ) ) {
        $ref_species = $$scalar_ref;
    }
    else {
        $ref_species = $db->selectall_arrayref( $sql_str, { Columns => {} } );
        $self->store_cached_results( 1, $sql_str, \$ref_species );
    }

    if ( @$ref_species && !$ref_species_aid ) {
        $ref_species_aid = $ref_species->[0]{'species_aid'};
    }

    #
    # Select all the map set that can be reference maps.
    #
    my $ref_map_sets = [];
    if ($ref_species_aid) {
        $sql_str = $sql->form_data_ref_map_sets_sql($ref_species_aid);
        unless ( $ref_map_sets = $self->get_cached_results( 1, $sql_str ) ) {
            $ref_map_sets =
              $db->selectall_arrayref( $sql_str, { Columns => {} } );

            foreach my $row (@$ref_map_sets) {
                $row->{'map_type'} =
                  $map_type_data->{ $row->{'map_type_aid'} }{'map_type'};
                $row->{'map_type_display_order'} =
                  $map_type_data->{ $row->{'map_type_aid'} }{'display_order'};
                $row->{'epoch_published_on'} =
                  parsedate( $row->{'published_on'} );
            }

            $ref_map_sets = sort_selectall_arrayref(
                $ref_map_sets,              '#map_type_display_order',
                'map_type',                 '#species_display_order',
                'species_name',             '#map_set_display_order',
                '#epoch_published_on desc', 'map_set_name',
            );

            $self->store_cached_results( 1, $sql_str, $ref_map_sets );
        }
    }

    #
    # If there's only one map set, pretend it was submitted.
    #
    if ( !$ref_map_set_aid && scalar @$ref_map_sets == 1 ) {
        $ref_map_set_aid = $ref_map_sets->[0]{'accession_id'};
    }

    #
    # If the user selected a map set, select all the maps in it.
    #
    my ( $ref_maps, $ref_map_set_info );

    if ($ref_map_set_aid) {
        unless ( ( $ref_map->{'maps'} and %{ $ref_map->{'maps'} } )
            or ( $ref_map->{'map_sets'} and %{ $ref_map->{'map_sets'} } ) )
        {
            $sql_str = $sql->form_data_ref_maps_sql;
            unless ( $ref_maps =
                $self->get_cached_results( 1, $sql_str . "$ref_map_set_aid" ) )
            {
                $ref_maps =
                  $db->selectall_arrayref( $sql_str, { Columns => {} },
                    ("$ref_map_set_aid") );
                $self->store_cached_results( 1, $sql_str . "$ref_map_set_aid",
                    $ref_maps );
            }
            $self->error(
qq[No maps exist for the ref. map set acc. id "$ref_map_set_aid"]
              )
              unless @$ref_maps;
        }

        unless (@ref_maps) {
            $sql_str = q[
                    select   ms.map_set_id, 
                             ms.accession_id as map_set_aid,
                             ms.map_set_name, 
                             ms.short_name,
                             ms.map_type_accession as map_type_aid, 
                             ms.species_id, 
                             ms.can_be_reference_map, 
                             ms.is_relational_map, 
                             ms.map_units, 
                             s.accession_id as species_aid, 
                             s.common_name as species_common_name, 
                             s.full_name as species_full_name
                    from     cmap_map_set ms, 
                             cmap_species s
                    where    ms.accession_id=?
                    and      ms.species_id=s.species_id
		       ];
            unless ( $ref_map_set_info =
                $self->get_cached_results( 1, $sql_str . $ref_map_set_aid ) )
            {
                my $sth = $db->prepare($sql_str);
                $sth->execute($ref_map_set_aid);
                $ref_map_set_info = $sth->fetchrow_hashref;
                $ref_map_set_info->{'attributes'} =
                  $self->get_attributes( 'cmap_map_set',
                    $ref_map_set_info->{'map_set_id'} );
                $ref_map_set_info->{'xrefs'} =
                  $self->get_xrefs( 'cmap_map_set',
                    $ref_map_set_info->{'map_set_id'} );
                $ref_map_set_info->{'map_type'} =
                  $map_type_data->{ $ref_map_set_info->{'map_type_aid'} }
                  {'map_type'};
                $self->store_cached_results( 1, $sql_str . $ref_map_set_aid,
                    $ref_map_set_info );
            }
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
            $evidence_type_data,
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
    my $db                          = $self->db or return;
    my $sql                         = $self->sql or return;
    my $map_type_data               = $self->map_type_data();
    return unless defined $ref_slot_no;

    my ( $ref_map_id, $ref_map_start, $ref_map_stop );
    my $from_restriction = '';
    my $corr_sql;
    my @unrestricted_map_ids = ();
    my $unrestricted_sql     = '';
    my $restricted_sql       = '';
    foreach my $ref_map_id ( keys( %{ $self->slot_info->{$ref_slot_no} } ) ) {
        $ref_map_start = $self->slot_info->{$ref_slot_no}{$ref_map_id}[0];
        $ref_map_stop  = $self->slot_info->{$ref_slot_no}{$ref_map_id}[1];
        if ( defined($ref_map_start) and defined($ref_map_stop) ) {
            $restricted_sql .=
                " or (cl.map_id1="
              . $ref_map_id
              . " and (( cl.start_position1>="
              . $ref_map_start
              . " and cl.start_position1<="
              . $ref_map_stop
              . " ) or ( cl.stop_position1 is not null and "
              . "  cl.start_position1<="
              . $ref_map_start
              . " and cl.stop_position1>="
              . $ref_map_start . " )))";
        }
        elsif ( defined($ref_map_start) ) {
            $restricted_sql .=
                " or (cl.map_id1="
              . $ref_map_id
              . " and (( cl.start_position1>="
              . $ref_map_start
              . " ) or ( cl.stop_position1 is not null and "
              . " cl.stop_position1>="
              . $ref_map_start . " )))";
        }
        elsif ( defined($ref_map_stop) ) {
            $restricted_sql .=
                " or (cl.map_id1="
              . $ref_map_id
              . " and cl.start_position1<="
              . $ref_map_stop . ") ";
        }
        else {
            push @unrestricted_map_ids, $ref_map_id;
        }
    }
    if (@unrestricted_map_ids) {
        $unrestricted_sql =
          " or cl.map_id1 in (" . join( ',', @unrestricted_map_ids ) . ") ";
    }
    $from_restriction = $restricted_sql . $unrestricted_sql;
    $from_restriction =~ s/^\s+or//;
    $from_restriction = " and (" . $from_restriction . ")"
      if $from_restriction;

    my $additional_where  = '';
    my $additional_tables = '';
#xx3
    if ( @$included_evidence_type_aids or @$less_evidence_type_aids
            or @$greater_evidence_type_aids ) {
        $additional_tables = ', cmap_correspondence_evidence ce';
        $additional_where .= q[
            and fc.feature_correspondence_id=ce.feature_correspondence_id
            and  ( ];
        my @join_array;
        if ( @$included_evidence_type_aids ) {
            push @join_array,
              " ce.evidence_type_accession in ('"
              . join( "','", @$included_evidence_type_aids ) . "')";
        }
        foreach my $et_aid (@$less_evidence_type_aids ) {
            push @join_array,
                " ( ce.evidence_type_accession = '$et_aid' "
              . " and ce.score <= ".$evidence_type_score->{$et_aid}." ) ";
        }
        foreach my $et_aid (@$greater_evidence_type_aids ) {
            push @join_array,
                " ( ce.evidence_type_accession = '$et_aid' "
              . " and ce.score >= ".$evidence_type_score->{$et_aid}." ) ";
        }
        $additional_where .= join (' or ', @join_array). " ) ";
    }
    else {    #all are ignored, return nothing
        $additional_where .= " and cl.map_id1 = -1 ";
    }

    if (@$ignored_feature_type_aids) {
        $additional_where .=
          " and cl.feature_type_accession2 not in ('"
          . join( "','", @$ignored_feature_type_aids ) . "') ";
    }

    $corr_sql = qq[ 
        select   count(distinct cl.feature_correspondence_id) as no_corr, 
                 cl.map_id2 as map_id, map.map_set_id
        from     cmap_correspondence_lookup cl,
                 cmap_feature_correspondence fc,
                 cmap_map map
        $additional_tables
        where    cl.feature_correspondence_id=
                 fc.feature_correspondence_id
        and      fc.is_enabled=1
        and      cl.map_id1!=cl.map_id2
        and      map.map_id=cl.map_id2
        $from_restriction
        $additional_where
    ];

    $corr_sql .= " group by cl.map_id2, map.map_set_id";

    my $feature_correspondences;
    unless ( $feature_correspondences =
        $self->get_cached_results( 4, $corr_sql ) )
    {
        $feature_correspondences =
          $db->selectall_arrayref( $corr_sql, { Columns => {} }, () );
        $self->store_cached_results( 4, $corr_sql, $feature_correspondences );
    }

    #
    # Gather info on the maps and map sets.
    #
    my %map_set_ids = map { $_->{'map_set_id'}, 1 } @$feature_correspondences;
    my $ms_sth = $db->prepare(
        q[
            select s.common_name as species_name,
                   s.display_order as species_display_order,
                   ms.map_type_accession as map_type_aid,
                   ms.accession_id as map_set_aid,
                   ms.short_name as map_set_name,
                   ms.published_on,
                   ms.display_order as ms_display_order,
                   ms.is_relational_map, 
                   ms.can_be_reference_map
            from   cmap_map_set ms,
                   cmap_species s
            where  ms.map_set_id=?
            and    ms.species_id=s.species_id
        ]
    );

    my ( %map_sets, %comp_maps );
    for my $map_set_id ( keys %map_set_ids ) {
        $ms_sth->execute($map_set_id);
        my $ms_info = $ms_sth->fetchrow_hashref;
        $ms_info->{'published_on'} = parsedate( $ms_info->{'published_on'} );
        $ms_info->{'map_type'}     =
          $map_type_data->{ $ms_info->{'map_type_aid'} }{'map_type'};
        $ms_info->{'map_type_display_order'} =
          $map_type_data->{ $ms_info->{'map_type_aid'} }{'display_order'};
        $map_sets{ $ms_info->{'map_set_aid'} } = $ms_info;
    }
    if (@$feature_correspondences) {
        my $maps_sql = q[
                select map.map_id,
                       ms.accession_id as map_set_aid,
                       map.accession_id as map_aid,
                       map.map_name,
                       map.display_order
                from   cmap_map map,
                       cmap_map_set ms
                where  map.map_set_id=ms.map_set_id
            ]
          . " and map.map_id in ('"
          . join( "','", map { $_->{'map_id'} } @$feature_correspondences )
          . "')";
        my $maps;
        unless ( $maps = $self->get_cached_results( 2, $maps_sql ) ) {
            $maps = $db->selectall_arrayref( $maps_sql, { Columns => {} } );
            $self->store_cached_results( 2, $maps_sql, $maps ) if ($maps);
        }
        for my $map (@$maps) {
            $comp_maps{ $map->{'map_id'} } = $map;
        }
    }
    for my $fc (@$feature_correspondences) {
        my $comp_map        = $comp_maps{ $fc->{'map_id'} } or next;
        my $ref_map_set_aid = $comp_map->{'map_set_aid'}    or next;

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
              || $a->{'species_name'} cmp $b->{'species_name'}
              || $a->{'ms_display_order'} <=> $b->{'ms_display_order'}
              || $b->{'published_on'} <=> $a->{'published_on'}
              || $a->{'map_set_name'} cmp $b->{'map_set_name'}
        } values %map_sets
      )
    {
        my @maps;                  # the maps for the map set
        my $total_correspondences; # all the correspondences for the map set
        my $is_relational_only;

        for my $map (
            sort {
                     $a->{'display_order'} <=> $b->{'display_order'}
                  || $a->{'map_name'} cmp $b->{'map_name'}
            } @{ $map_set->{'maps'} || [] }
          )
        {
            next
              if $min_correspondences
              && $map->{'no_correspondences'} < $min_correspondences;

            $total_correspondences += $map->{'no_correspondences'};
            $is_relational_only = $map_set->{'is_relational_map'};
            push @maps, $map unless $is_relational_only;
        }

        next unless $total_correspondences;
        next unless @maps || $is_relational_only;

        push @sorted_map_sets,
          {
            map_type           => $map_set->{'map_type'},
            species_name       => $map_set->{'species_name'},
            map_set_name       => $map_set->{'map_set_name'},
            map_set_aid        => $map_set->{'map_set_aid'},
            no_correspondences => $total_correspondences,
            maps               => \@maps,
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

    my $db  = $self->db;
    my $sth = $db->prepare(
        q[
            select fa.feature_alias_id,
                   fa.alias,
                   f.accession_id as feature_aid,
                   f.feature_name
            from   cmap_feature_alias fa,
                   cmap_feature f
            where  fa.alias=?
            and    fa.feature_id=f.feature_id
            and    f.accession_id=?
        ]
    );
    $sth->execute( $feature_alias, $feature_aid );
    my $alias = $sth->fetchrow_hashref or return $self->error('No alias');

    $alias->{'object_id'}  = $alias->{'feature_alias_id'};
    $alias->{'attributes'} =
      $self->get_attributes( 'cmap_feature_alias',
        $alias->{'feature_alias_id'} );

    $self->get_multiple_xrefs(
        table_name => 'cmap_feature_alias',
        objects    => [$alias],
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
sub feature_name_to_position {

=pod

=head2 feature_name_to_position

Turn a feature name into a position.

=cut

    my ( $self, %args ) = @_;
    my $feature_name = $args{'feature_name'} or return;
    my $map_id       = $args{'map_id'}       or return;
    my $start_position_only = $args{'start_position_only'};
    my $db                  = $self->db or return;
    my $upper_name          = uc $feature_name;
    my $sql_str             = q[
            select    f.start_position,
                      f.stop_position
            from      cmap_feature f
            left join cmap_feature_alias fa
            on        f.feature_id=fa.feature_id
            where     f.map_id=?
            and       (
                upper(f.feature_name)=?
                or
                upper(fa.alias)=?
            )
		  ];
    my ( $start, $stop );

    if ( my $arrayref =
        $self->get_cached_results( 3, $sql_str . $map_id . $upper_name ) )
    {
        ( $start, $stop ) = @$arrayref;
    }
    else {
        ( $start, $stop ) =
          $db->selectrow_array( $sql_str, {},
            ( $map_id, $upper_name, $upper_name ) );
        $self->store_cached_results(
            3,
            $sql_str . $map_id . $upper_name,
            [ $start, $stop ]
        );
    }

    return $start_position_only ? $start
      : defined $stop           ? $stop
      : $start;
}

# ----------------------------------------------------

=pod

=head2 fill_out_maps

Gets the names, IDs, etc., of the maps in the slots.

=cut

sub fill_out_maps {

    #p#rint S#TDERR "fill_out_maps\n";
    my ( $self, $slots ) = @_;
    my $db = $self->db or return;
    my @ordered_slot_nos = sort { $a <=> $b } keys %$slots;

    my $base_sql = q[ 
        select distinct ms.map_set_id,
               ms.short_name as map_set_name,
               s.common_name as species_name
        from   cmap_map_set ms,
               cmap_species s,
               cmap_map map 
        where  ms.species_id=s.species_id 
           and map.map_set_id=ms.map_set_id ];

    my @maps;
    for my $i ( 0 .. $#ordered_slot_nos ) {
        my $map;
        my $slot_no   = $ordered_slot_nos[$i];
        my $slot_info = $self->slot_info->{$slot_no};
        next unless ($slot_info and %$slot_info);
        my $sql_str   = $base_sql
          . " and map.map_id in ("
          . join( ",", keys(%$slot_info) ) . ") ";
        my $map_info;
        unless ( $map_info = $self->get_cached_results( 2, $sql_str ) ) {
            $map_info = $db->selectall_arrayref( $sql_str, { Columns => {} } );
            $self->store_cached_results( 2, $sql_str, $map_info )
              if ($map_info);
        }
        my %desc_by_species;
        foreach my $row (@$map_info) {
            if ( $desc_by_species{ $row->{'species_name'} } ) {
                $desc_by_species{ $row->{'species_name'} } .=
                  "," . $row->{'map_set_name'};
            }
            else {
                $desc_by_species{ $row->{'species_name'} } .=
                  $row->{'species_name'} . "-" . $row->{'map_set_name'};
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
                          . $slots->{$cmap_no}{'maps'}{$map_aid}{'mag'}. "]";
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
    my $db          = $self->db            or return;
    my $sql         = $self->sql           or return;
    my $evidence_type_data = $self->evidence_type_data();
    my $map_type_data      = $self->map_type_data();
    my $sth                = $db->prepare( $sql->feature_detail_data_sql );

    $sth->execute($feature_aid);
    my $feature = $sth->fetchrow_hashref
      or return $self->error("Invalid feature accession ID ($feature_aid)");

    $feature->{'feature_type'} =
      $self->feature_type_data( $feature->{'feature_type_aid'},
        'feature_type' );
    $feature->{'object_id'}  = $feature->{'feature_id'};
    $feature->{'attributes'} =
      $self->get_attributes( 'cmap_feature', $feature->{'feature_id'} );
    $feature->{'aliases'} = $db->selectall_arrayref(
        q[
            select   fa.feature_alias_id, 
                     fa.alias,
                     f.accession_id as feature_aid
            from     cmap_feature_alias fa,
                     cmap_feature f
            where    fa.feature_id=?
            and      fa.feature_id=f.feature_id
            order by alias
        ],
        { Columns => {} },
        ( $feature->{'feature_id'} )
    );

    my $correspondences = $db->selectall_arrayref(
        $sql->feature_correspondence_sql(
            disregard_evidence_type => 1,
        ),
        { Columns => {} },
        ( $feature->{'feature_id'} )
    );

    for my $corr (@$correspondences) {
        $corr->{'evidence'} = $db->selectall_arrayref(
            q[
                select   ce.accession_id,
                         ce.score,
                         ce.evidence_type_accession as evidence_type_aid
                from     cmap_correspondence_evidence ce
                where    ce.feature_correspondence_id=?
            ],
            { Columns => {} },
            ( $corr->{'feature_correspondence_id'} )
        );

        foreach my $row ( @{ $corr->{'evidence'} } ) {
            $row->{'rank'} =
              $evidence_type_data->{ $row->{'evidence_type_aid'} }{'rank'};
            $row->{'evidence_type'} =
              $evidence_type_data->{ $row->{'evidence_type_aid'} }{'map_type'};
        }

        $corr->{'evidence'} =
          sort_selectall_arrayref( $corr->{'evidence'}, '#rank',
            'evidence_type' );

        $corr->{'aliases'} = $db->selectcol_arrayref(
            q[
                select   alias 
                from     cmap_feature_alias
                where    feature_id=?
                order by alias
            ],
            {},
            ( $corr->{'feature_id'} )
        );
        $corr->{'map_type'} =
          $map_type_data->{ $corr->{'map_type_aid'} }{'map_type'};
    }

    $feature->{'correspondences'} = $correspondences;

    $self->get_multiple_xrefs(
        table_name => 'cmap_feature',
        objects    => [$feature],
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
    my $db                         = $self->db or return;
    my $species_aids               = $args{'species_aids'};
    my $incoming_feature_type_aids = $args{'feature_type_aids'};
    my $feature_string             = $args{'features'};
    my $page_data                  = $args{'page_data'};
    my $page_size                  = $args{'page_size'};
    my $page_no                    = $args{'page_no'};
    my $pages_per_set              = $args{'pages_per_set'};
    my $feature_type_data          = $self->feature_type_data();
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
      || 'feature_name,species_name,map_set_name,map_name,start_position';
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
        my $comparison = $feature_name =~ m/%/ ? 'like' : '=';
        $feature_name = uc $feature_name;

        my ( $fname_where, $aname_where );
        if ( $feature_name ne '%' ) {
            $fname_where .=
              " and upper(f.feature_name) $comparison '$feature_name' ";
            $aname_where .= " and upper(fa.alias) $comparison '$feature_name' ";
        }

        my $where = '';
        if (@$incoming_feature_type_aids) {
            $where .=
                'and f.feature_type_accession in ('
              . join( ', ', map { qq['$_'] } @$incoming_feature_type_aids )
              . ') ';
        }

        if (@$species_aids) {
            $where .=
              'and s.accession_id in ('
              . join( ', ', map { qq['$_'] } @$species_aids ) . ') ';
        }

        my $sql;
        if ( $search_field eq 'feature_name' ) {
            $sql = qq[
                select   f.feature_id,
                         f.accession_id as feature_aid,
                         f.feature_name, 
                         f.start_position,
                         f.stop_position,
                         f.feature_type_accession as feature_type_aid,
                         map.accession_id as map_aid,
                         map.map_name, 
                         ms.accession_id as map_set_aid, 
                         ms.short_name as map_set_name,
                         ms.can_be_reference_map,
                         s.species_id,
                         s.common_name as species_name,
                         ms.map_units
                from     cmap_feature f,
                         cmap_map map,
                         cmap_map_set ms,
                         cmap_species s
                where    f.map_id=map.map_id
                and      map.map_set_id=ms.map_set_id
                and      ms.species_id=s.species_id
                and      ms.is_enabled=1
                $fname_where
                $where
                UNION
                select f.feature_id,
                       f.accession_id as feature_aid,
                       f.feature_name,
                       f.start_position,
                       f.stop_position,
                       f.feature_type_accession as feature_type_aid,
                       map.accession_id as map_aid,
                       map.map_name,
                       ms.accession_id as map_set_aid,
                       ms.short_name as map_set_name,
                       ms.can_be_reference_map,
                       s.species_id,
                       s.common_name as species_name,
                       ms.map_units
                from   cmap_feature_alias fa,
                       cmap_feature f,
                       cmap_map map,
                       cmap_map_set ms,
                       cmap_species s
                where  fa.feature_id=f.feature_id
                and    f.map_id=map.map_id
                and    map.map_set_id=ms.map_set_id
                and    ms.species_id=s.species_id
                and    ms.is_enabled=1
                $aname_where
                $where
            ];
        }
        else {
            $sql = qq[
                select   f.feature_id,
                         f.accession_id as feature_aid,
                         f.feature_name, 
                         f.start_position,
                         f.stop_position,
                         f.feature_type_accession as feature_type_aid,
                         map.accession_id as map_aid,
                         map.map_name, 
                         ms.accession_id as map_set_aid, 
                         ms.short_name as map_set_name,
                         ms.can_be_reference_map,
                         s.species_id,
                         s.common_name as species_name,
                         ms.map_units
                from     cmap_feature f,
                         cmap_map map,
                         cmap_map_set ms,
                         cmap_species s
                where   f.map_id=map.map_id
                and      map.map_set_id=ms.map_set_id
                and      ms.species_id=s.species_id
                and      ms.is_enabled=1
                $where
            ];
            unless ( $feature_name eq '%' ) {
                $sql .=
                  " and upper(f.accession_id) $comparison '$feature_name'";
            }
        }

        my $features = $db->selectall_arrayref( $sql, { Columns => {} } );
        foreach my $row ( @{$features} ) {
            $row->{'feature_type'} =
              $feature_type_data->{ $row->{'feature_type_aid'} }
              {'feature_type'};
        }
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
        my $aliases = $db->selectall_arrayref(
            q[
                select fa.feature_id, fa.alias
                from   cmap_feature_alias fa
                where  feature_id in (] . join( ',', @feature_ids ) . q[)
            ],
        );

        my %aliases;
        for my $alias (@$aliases) {
            push @{ $aliases{ $alias->[0] } }, $alias->[1];
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
    my $species = $db->selectall_arrayref(
        q[
            select   s.accession_id as species_aid,
                     s.common_name as species_name
            from     cmap_species s
            order by species_name
        ],
        { Columns => {} }
    );

    #
    # Get the feature types.
    #
    my $feature_types = $self->fake_selectall_arrayref(
        $feature_type_data,
        'feature_type',
        'feature_type_accession as feature_type_aid'
    );

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

    my $evidence_type_data = $self->evidence_type_data();
    my @evidence_types     = keys( %{ $self->config_data('evidence_type') } );

    my %supplied_evidence_types;
    if ( $args{'evidence_types'} ) {
        %supplied_evidence_types = map { $_ => 1 } @{ $args{'evidence_types'} };
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

    my $all_evidence_types = $self->fake_selectall_arrayref(
        $self->evidence_type_data(),
        'evidence_type_accession as evidence_type_aid',
        'evidence_type'
    );
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

    my $feature_type_data = $self->feature_type_data();
    my @feature_types     = keys( %{$feature_type_data} );

    my %supplied_feature_types;
    if ( $args{'feature_types'} ) {
        %supplied_feature_types = map { $_ => 1 } @{ $args{'feature_types'} };
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
    my $db            = $self->db or return;
    my $map_type_data = $self->map_type_data();

    for ( $species_aid, $map_type_aid ) {
        $_ = 0 if $_ == -1;
    }

    my $restriction;
    if (@map_set_aids) {
        $restriction .=
          'and ms.accession_id in ('
          . join( ',', map { qq['$_'] } @map_set_aids ) . ') ';
    }

    $restriction .= qq[and s.accession_id='$species_aid' ] if $species_aid;
    $restriction .= qq[and ms.map_type_accession='$map_type_aid' ]
      if $map_type_aid;

    #
    # Map sets
    #
    my $map_set_sql = qq[
        select   ms.map_set_id, 
                 ms.accession_id as map_set_aid,
                 ms.map_set_name, 
                 ms.short_name,
                 ms.map_type_accession as map_type_aid, 
                 ms.species_id, 
                 ms.published_on,
                 ms.can_be_reference_map,
                 ms.map_units, 
                 ms.is_relational_map, 
                 s.accession_id as species_aid, 
                 s.common_name, 
                 s.full_name
        from     cmap_map_set ms,  
                 cmap_species s
        where    ms.species_id=s.species_id
        $restriction
    ];
    my $map_sets = $db->selectall_arrayref( $map_set_sql, { Columns => {} } );
    foreach my $row ( @{$map_sets} ) {
        $row->{'map_type'} =
          $map_type_data->{ $row->{'map_type_aid'} }{'map_type'};
    }

    #
    # Maps in the map sets
    #
    my $map_sql = qq[
        select   map.map_set_id,
                 map.accession_id as map_aid, 
                 map.display_order,
                 map.map_name
        from     cmap_map map,
                 cmap_map_set ms,  
                 cmap_species s
        where    map.map_set_id=ms.map_set_id
        and      ms.is_relational_map=0
        and      ms.species_id=s.species_id
        $restriction
        order by map.map_set_id, 
                 map.display_order, 
                 map.map_name
    ];

    my $maps = $db->selectall_arrayref( $map_sql, { Columns => {} } );
    my %map_lookup;
    for my $map (@$maps) {
        push @{ $map_lookup{ $map->{'map_set_id'} } }, $map;
    }

    #
    # Attributes of the map sets
    #
    my $attributes = $db->selectall_arrayref(
        q[
            select   object_id, display_order, is_public,
                     attribute_name, attribute_value
            from     cmap_attribute
            where    table_name=?
            order by object_id, display_order, attribute_name
        ],
        { Columns => {} },
        ('cmap_map_set')
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
        $map_set->{'maps'} = $map_lookup{ $map_set->{'map_set_id'} } || [];
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
        table_name => 'cmap_map_set',
        objects    => $map_sets,
    );

    #
    # Grab species and map type info for form restriction controls.
    #
    my $species = $db->selectall_arrayref(
        q[
            select   s.accession_id as species_aid,
                     s.common_name as species_name
            from     cmap_species s
            order by s.display_order,
                     species_name
        ],
        { Columns => {} }
    );

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
sub map_stop {

=pod

=head2 map_stop

Given a map acc. id or a map_id, find the highest start or stop position
(remembering that some features span a distance).  Optionally finds the 
lowest stop for a given feature type. (enhancement)

=cut

    my ( $self, %args ) = @_;
    my $db      = $self->db  or return;
    my $sql_obj = $self->sql or return;
    my $map_aid = $args{'map_aid'} || 0;
    my $map_id  = $args{'map_id'}  || 0;
    my $id = ( $map_aid || $map_id )
      or return $self->error("Not enough args to map_stop()");
    my $sql = $sql_obj->map_stop_sql(%args);
    my ( $start, $stop );

    if ( my $arrayref = $self->get_cached_results( 3, $sql . $id ) ) {
        ( $start, $stop ) = @$arrayref;
    }
    else {
        ( $start, $stop ) = $db->selectrow_array( $sql, {}, ($id) )
          or $self->error(qq[Cannot determine map stop for id "$id"]);
        $self->store_cached_results( 3, $sql . $id, [ $start, $stop ] );
    }
    return $start > $stop ? $start : $stop;
}

# ----------------------------------------------------
sub map_start {

=pod

=head2 map_start

Given a map acc. id or a map_id, find the lowest start position.  
Optionally finds the lowest start for a given feature type. (enhancement)

=cut

    ;
    my ( $self, %args ) = @_;
    my $db      = $self->db  or return;
    my $sql_obj = $self->sql or return;
    my $map_aid = $args{'map_aid'} || 0;
    my $map_id  = $args{'map_id'}  || 0;
    my $id = ( $map_aid || $map_id )
      or return $self->error("Not enough args to map_start()");
    my $sql = $sql_obj->map_start_sql(%args);
    my ( $start, $stop );

    if ( my $arrayref = $self->get_cached_results( 3, $sql . $id ) ) {
        ( $start, $stop ) = @$arrayref;
    }
    else {
        defined( my $start = $db->selectrow_array( $sql, {}, ($id) ) )
          or return $self->error(qq[Cannot determine map start for id "$id"]);
        $self->store_cached_results( 3, $sql . $id, [ $start, $stop ] );
    }
    return $start;
}

# ----------------------------------------------------
sub map_detail_data {

=pod

=head2 map_detail_data

Returns the detail info for a map.

=cut

    my ( $self, %args ) = @_;
    my $map                   = $args{'ref_map'};
    my $highlight             = $args{'highlight'} || '';
    my $order_by              = $args{'order_by'} || 'f.start_position';
    my $comparative_map_field = $args{'comparative_map_field'} || '';
    my $comparative_map_aid   = $args{'comparative_map_aid'} || '';
    my $page_size             = $args{'page_size'} || 25;
    my $max_pages             = $args{'max_pages'} || 0;
    my $page_no               = $args{'page_no'} || 1;
    my $page_data             = $args{'page_data'};
    my $db                    = $self->db or return;
    my $sql                   = $self->sql or return;
    my $map_id                = $map->{'map_id'};
    my $map_start             = $map->{'start'};
    my $map_stop              = $map->{'stop'};
    my $feature_type_data     = $self->feature_type_data();
    my $evidence_type_data    = $self->evidence_type_data();

    my $feature_type_aids           = $args{'included_feature_types'}  || [];
    my $corr_only_feature_type_aids = $args{'corr_only_feature_types'}  || [];
    my $ignored_feature_type_aids   = $args{'ignored_feature_types'}   || [];
    my $included_evidence_type_aids = $args{'included_evidence_types'};
    my $ignored_evidence_type_aids  = $args{'ignored_evidence_types'};
    my $less_evidence_type_aids     = $args{'less_evidence_types'};
    my $greater_evidence_type_aids  = $args{'greater_evidence_types'};
    my $evidence_type_score         = $args{'evidence_type_score'};

    #
    # Figure out hightlighted features.
    #
    my $highlight_hash =
      { map { s/^\s+|\s+$//g; defined $_ && $_ ne '' ? ( uc $_, 1 ) : () }
          parse_words($highlight) };

    my $sth = $db->prepare(
        q[
            select s.accession_id as species_aid,
                   s.common_name as species_name,
                   ms.accession_id as map_set_aid,
                   ms.short_name as map_set_name,
                   map.accession_id as map_aid,
                   map.map_name,
                   map.start_position,
                   map.stop_position,
                   ms.map_units,
                   ms.map_type_accession as map_type_aid
            from   cmap_map map,
                   cmap_map_set ms,
                   cmap_species s
            where  map.map_id=?
            and    map.map_set_id=ms.map_set_id
            and    ms.species_id=s.species_id
        ]
    );
    $sth->execute($map_id);
    my $reference_map = $sth->fetchrow_hashref;

    $map_start = $reference_map->{'start_position'}
      unless defined $map_start
      and $map_start =~ /^$RE{'num'}{'real'}$/;
    $map_stop = $reference_map->{'stop_position'}
      unless defined $map_stop
      and $map_stop =~ /^$RE{'num'}{'real'}$/;
    $reference_map->{'start'}      = $map_start;
    $reference_map->{'stop'}       = $map_stop;
    $reference_map->{'object_id'}  = $map_id;
    $reference_map->{'attributes'} =
      $self->get_attributes( 'cmap_map', $map_id );
    $self->get_multiple_xrefs(
        table_name => 'cmap_map',
        objects    => [$reference_map]
    );

    #
    # Get the reference map features.
    #
    my $features = $db->selectall_arrayref(
        $sql->cmap_data_features_sql(
            order_by          => $order_by,
            feature_type_aids => [(@$feature_type_aids,@$corr_only_feature_type_aids)] ,
        ),
        { Columns => {} },
        ( $map_id, $map_start, $map_stop, $map_start, $map_start )
    );

    my $feature_count_by_type = $db->selectall_arrayref(
        q[
             select   count(f.feature_type_accession) as no_by_type, 
                      f.feature_type_accession as feature_type_aid
             from     cmap_feature f
             where    f.map_id=?
             group by f.feature_type_accession
             order by no_by_type desc
         ],
        { Columns => {} },
        ($map_id)
    );
    foreach my $row ( @{$feature_count_by_type} ) {
        $row->{'feature_type'} =
          $feature_type_data->{ $row->{'feature_type_aid'} }{'feature_type'};
    }

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
    $features = [ $pager->splice($features) ] if $page_data && @$features;

    #
    # Feature aliases.
    #
    my $aliases = $db->selectall_arrayref(
        q[
            select f.feature_id,
                   fa.alias
            from   cmap_feature f,
                   cmap_feature_alias fa
            where  f.map_id=?
            and    f.feature_id=fa.feature_id
        ],
        {},
        ($map_id)
    );

    my %alias_lookup;
    for my $alias (@$aliases) {
        push @{ $alias_lookup{ $alias->[0] } }, $alias->[1];
    }

    for my $feature (@$features) {
        $feature->{'aliases'} = $alias_lookup{ $feature->{'feature_id'} } || [];
        $feature->{'feature_type'} =
          $feature_type_data->{ $feature->{'feature_type_aid'} }
          {'feature_type'};

    }

    #
    # Get all the feature types on all the maps.
    #
    my $ft_sql .= q[
        select   distinct 
                 f.feature_type_accession as feature_type_aid
        from     cmap_feature f
        where   
    ];
    $ft_sql .= " f.map_id in ('";

    $ft_sql .= join( "','",
        map { join( "','", keys( %{ $self->slot_info->{$_} } ) ) }
          keys %{ $self->slot_info } )
      . "')";

    my $tempFeatureTypes =
      $db->selectall_arrayref( $ft_sql, { Columns => {} } );
    foreach my $row ( @{$tempFeatureTypes} ) {
        $row->{'feature_type'} =
          $self->feature_type_data( $row->{'feature_type_aid'},
            'feature_type' );
    }
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
        my $positions = $db->selectall_arrayref(
            $sql->feature_correspondence_sql(
                comparative_map_field       => $comparative_map_field,
                comparative_map_aid         => $comparative_map_aid,
                included_evidence_type_aids => \@$included_evidence_type_aids,
                less_evidence_type_aids     => $less_evidence_type_aids,
                greater_evidence_type_aids  => $greater_evidence_type_aids,
                evidence_type_score         => $evidence_type_score,
            ),
            { Columns => {} },
            ( $feature->{'feature_id'} )
        );

        my ( %distinct_positions, %evidence );
        for my $position (@$positions) {
            my $map_set_aid = $position->{'map_set_aid'};
            my $map_aid     = $position->{'map_aid'};
            $position->{'evidence_type'} =
              $evidence_type_data->{ $position->{'evidence_type_aid'} }
              {'evidence_type'};

            unless ( defined $comparative_maps{$map_set_aid} ) {
                for (
                    qw[
                    map_aid
                    map_type_display_order
                    map_type
                    species_display_order
                    species_name
                    ms_display_order
                    map_set
                    species_name
                    map_set_name
                    map_set_aid
                    ]
                  )
                {
                    $comparative_maps{$map_set_aid}{$_} = $position->{$_};
                }

                $comparative_maps{$map_set_aid}{'published_on'} =
                  parsedate( $position->{'published_on'} );
            }

            unless ( defined $comparative_maps{$map_set_aid}{'maps'}{$map_aid} )
            {
                $comparative_maps{$map_set_aid}{'maps'}{$map_aid} = {
                    display_order => $position->{'map_display_order'},
                    map_name      => $position->{'map_name'},
                    map_aid       => $position->{'map_aid'},
                };
            }

            $distinct_positions{ $position->{'feature_id'} } = $position;
            push @{ $evidence{ $position->{'feature_id'} } },
              $position->{'evidence_type'};
        }

        for my $position ( values %distinct_positions ) {
            $position->{'evidence'} = $evidence{ $position->{'feature_id'} };
        }

        $feature->{'no_positions'} = scalar keys %distinct_positions;
        $feature->{'positions'}    = [ values %distinct_positions ];

        for my $val (
            $feature->{'feature_name'},
            @{ $feature->{'aliases'} || [] },
            $feature->{'accession_id'}
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
              || $a->{'species_name'} cmp $b->{'species_name'}
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
            map_set_name => $map_set->{'species_name'} . ' - '
              . $map_set->{'map_set_name'},
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

    my @map_types     = keys( %{ $self->config_data('map_type') } );
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
    my $db            = $self->db or return;
    my $map_type_data = $self->map_type_data();

    my $sql = q[
        select   s.species_id,
                 s.accession_id as species_aid,
                 s.common_name,
                 s.full_name,
                 s.display_order
        from     cmap_species s 
    ];

    if (@species_aids) {
        $sql .=
          'where s.accession_id in ('
          . join( ',', map { qq['$_'] } @species_aids ) . ') ';
    }

    $sql .= 'order by display_order, common_name';

    my $species = $db->selectall_arrayref( $sql, { Columns => {} } );

    my $all_species = $db->selectall_arrayref(
        q[
            select   accession_id as species_aid, common_name, full_name
            from     cmap_species
            order by common_name
        ],
        { Columns => {} }
    );

    my $attributes = $db->selectall_arrayref(
        q[
            select   object_id, display_order, is_public, 
                     attribute_name, attribute_value
            from     cmap_attribute
            where    table_name=?
            order by object_id, display_order, attribute_name
        ],
        { Columns => {} },
        ('cmap_species')
    );

    my %attr_lookup;
    for my $attr (@$attributes) {
        push @{ $attr_lookup{ $attr->{'object_id'} } }, $attr;
    }

    for my $s (@$species) {
        $s->{'object_id'}  = $s->{'species_id'};
        $s->{'attributes'} = $attr_lookup{ $s->{'species_id'} };
        $s->{'map_sets'}   = $db->selectall_arrayref(
            q[
                select   ms.accession_id as map_set_aid,
                         ms.short_name as map_set_name,
                         s.accession_id as species_aid,
                         ms.map_type_accession as map_type_aid,
                         ms.is_relational_map,
                         ms.display_order,
                         ms.published_on
                from     cmap_map_set ms,
                         cmap_species s 
                where    ms.species_id=?
                and      ms.species_id=s.species_id
            ],
            { Columns => {} },
            ( $s->{'species_id'} )
        );
        foreach my $row ( @{ $s->{'map_sets'} } ) {
            $row->{'default_display_order'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'display_order'};
            $row->{'default_color'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'color'};
            $row->{'default_width'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'width'};
            $row->{'map_type'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'map_type'};
            $row->{'epoch_published_on'} = parsedate( $row->{'published_on'} );
        }
        $s->{'map_sets'} =
          sort_selectall_arrayref( $s->{'map_sets'}, '#default_display_order',
            'map_type', '#display_order', '#epoch_published_on desc',
            'map_set_name' );
    }

    $self->get_multiple_xrefs(
        table_name => 'cmap_species',
        objects    => $species,
    );

    return {
        all_species => $all_species,
        species     => $species,
    };
}

# ----------------------------------------------------
sub sql {

=pod

=head2 sql

Returns the correct SQL module driver for the RDBMS we're using.

=cut

    my $self      = shift;
    my $db_driver = lc shift;

    unless ( defined $self->{'sql_module'} ) {
        my $db = $self->db or return;
        $db_driver = lc $db->{'Driver'}->{'Name'} || '';
        $db_driver = DEFAULT->{'sql_driver_module'}
          unless VALID->{'sql_driver_module'}{$db_driver};
        my $sql_module = VALID->{'sql_driver_module'}{$db_driver};

        eval "require $sql_module"
          or return $self->error(
            qq[Unable to require SQL module "$sql_module": $@]);

        $self->{'sql_module'} = $sql_module->new( config => $self->config );
    }

    return $self->{'sql_module'};
}

# ----------------------------------------------------
sub view_feature_on_map {

=pod

=head2 view_feature_on_map


=cut

    my ( $self, $feature_aid ) = @_;
    my $db = $self->db or return;
    my ( $map_set_aid, $map_aid, $feature_name ) = $db->selectrow_array(
        q[
            select ms.accession_id,
                   map.accession_id,
                   f.feature_name
            from   cmap_map_set ms,
                   cmap_map map,
                   cmap_feature f
            where  f.accession_id=?
            and    f.map_id=map.map_id
            and    map.map_set_id=ms.map_set_id
        ],
        {},
        ($feature_aid)
    );

    return ( $map_set_aid, $map_aid, $feature_name );
}

# ----------------------------------------------------
sub count_correspondences {

    my ( $self, %args ) = @_;
    my $included_evidence_type_aids = $args{'included_evidence_type_aids'};
    my $ignored_evidence_type_aids  = $args{'ignored_evidence_type_aids'};
    my $less_evidence_type_aids = $args{'less_evidence_type_aids'};
    my $greater_evidence_type_aids = $args{'greater_evidence_type_aids'};
    my $evidence_type_score = $args{'evidence_type_score'};
    my $map_correspondences         = $args{'map_correspondences'};
    my $this_slot_no                = $args{'this_slot_no'};
    my $ref_slot_no                 = $args{'ref_slot_no'};
    my $maps                        = $args{'maps'};
    my $db                          = $args{'db'};

#
# Query for the counts of correspondences.
#
# All possible evidence types that aren't ignored are in included_evidence_type_aids
#  at this point.  If it is empty, either all are ignored or something is wrong.
#  In the case where all are ignored, the sql is forced to return nothing.
#xx4
    my $where = '';
    if ( @$included_evidence_type_aids or @$less_evidence_type_aids
            or @$greater_evidence_type_aids ) {
        $where .= "and ( ";
        my @join_array;
        if ( @$included_evidence_type_aids ) {
            push @join_array,
              " ce.evidence_type_accession in ('"
              . join( "','", @$included_evidence_type_aids ) . "')";
        }
        foreach my $et_aid (@$less_evidence_type_aids ) {
            push @join_array,
                " ( ce.evidence_type_accession = '$et_aid' "
              . " and ce.score <= ".$evidence_type_score->{$et_aid}." ) ";
        }
        foreach my $et_aid (@$greater_evidence_type_aids ) {
            push @join_array,
                " ( ce.evidence_type_accession = '$et_aid' "
              . " and ce.score >= ".$evidence_type_score->{$et_aid}." ) ";
        }
        $where .= join (' or ', @join_array). " ) ";
    }
    else {
        $where .= " and ce.correspondence_evidence_id = -1 ";
    }

    my ( $count_sql, @query_args );
    if ( defined $ref_slot_no ) {    # multiple reference maps
        my $base_sql;
        $base_sql = qq[ 
            select   %s
                     cl.map_id1, 
                     cl.map_id2
            from     cmap_correspondence_lookup cl,
                     cmap_feature_correspondence fc,
                     cmap_correspondence_evidence ce
            where    cl.feature_correspondence_id=
                     fc.feature_correspondence_id
            and      fc.is_enabled=1
            and      fc.feature_correspondence_id=
                     ce.feature_correspondence_id
            $where
        ];

        # Include current slot maps
        my $slot_info            = $self->slot_info->{$this_slot_no};
        my @unrestricted_map_ids = ();
        my $unrestricted_sql     = '';
        my $restricted_sql       = '';
        foreach my $slot_map_id ( keys( %{$slot_info} ) ) {

            # $slot_info->{$slot_map_id}->[0] is start [1] is stop
            if (    defined( $slot_info->{$slot_map_id}->[0] )
                and defined( $slot_info->{$slot_map_id}->[1] ) )
            {
                $restricted_sql .=
                    " or (cl.map_id2="
                  . $slot_map_id
                  . " and (( cl.start_position2>="
                  . $slot_info->{$slot_map_id}->[0]
                  . " and cl.start_position2<="
                  . $slot_info->{$slot_map_id}->[1]
                  . " ) or ( cl.stop_position2 is not null and "
                  . "  cl.start_position2<="
                  . $slot_info->{$slot_map_id}->[0]
                  . " and cl.stop_position2>="
                  . $slot_info->{$slot_map_id}->[0] . " )))";
            }
            elsif ( defined( $slot_info->{$slot_map_id}->[0] ) ) {
                $restricted_sql .=
                    " or (cl.map_id2="
                  . $slot_map_id
                  . " and (( cl.start_position2>="
                  . $slot_info->{$slot_map_id}->[0]
                  . " ) or ( cl.stop_position2 is not null "
                  . " and cl.stop_position2>="
                  . $slot_info->{$slot_map_id}->[0] . " )))";
            }
            elsif ( defined( $slot_info->{$slot_map_id}->[1] ) ) {
                $restricted_sql .=
                    " or (cl.map_id2="
                  . $slot_map_id
                  . " and cl.start_position2<="
                  . $slot_info->{$slot_map_id}->[1] . ") ";
            }
            else {
                push @unrestricted_map_ids, $slot_map_id;
            }
        }
        if (@unrestricted_map_ids) {
            $unrestricted_sql =
              " or cl.map_id2 in (" . join( ',', @unrestricted_map_ids ) . ") ";
        }
        my $combined_sql = $restricted_sql . $unrestricted_sql;
        $combined_sql =~ s/^\s+or//;
        $base_sql .= " and (" . $combined_sql . ")";

        # Include reference slot maps
        $slot_info            = $self->slot_info->{$ref_slot_no};
        @unrestricted_map_ids = ();
        $unrestricted_sql     = '';
        $restricted_sql       = '';
        foreach my $slot_map_id ( keys( %{$slot_info} ) ) {

            # $slot_info->{$slot_map_id}->[0] is start [1] is stop
            if (    defined( $slot_info->{$slot_map_id}->[0] )
                and defined( $slot_info->{$slot_map_id}->[1] ) )
            {
                $restricted_sql .=
                    " or (cl.map_id1="
                  . $slot_map_id
                  . " and (( cl.start_position1>="
                  . $slot_info->{$slot_map_id}->[0]
                  . " and cl.start_position1<="
                  . $slot_info->{$slot_map_id}->[1]
                  . " ) or ( cl.stop_position1 is not null and "
                  . "  cl.start_position1<="
                  . $slot_info->{$slot_map_id}->[0]
                  . " and cl.stop_position1>="
                  . $slot_info->{$slot_map_id}->[0] . " )))";
            }
            elsif ( defined( $slot_info->{$slot_map_id}->[0] ) ) {
                $restricted_sql .=
                    " or (cl.map_id1="
                  . $slot_map_id
                  . " and (( cl.start_position1>="
                  . $slot_info->{$slot_map_id}->[0]
                  . " ) or ( cl.stop_position1 is not null "
                  . " and cl.stop_position1>="
                  . $slot_info->{$slot_map_id}->[0] . " )))";
            }
            elsif ( defined( $slot_info->{$slot_map_id}->[1] ) ) {
                $restricted_sql .=
                    " or (cl.map_id1="
                  . $slot_map_id
                  . " and cl.start_position1<="
                  . $slot_info->{$slot_map_id}->[1] . ") ";
            }
            else {
                push @unrestricted_map_ids, $slot_map_id;
            }
        }
        if (@unrestricted_map_ids) {
            $unrestricted_sql =
              " or cl.map_id1 in (" . join( ',', @unrestricted_map_ids ) . ") ";
        }
        $combined_sql = $restricted_sql . $unrestricted_sql;
        $combined_sql =~ s/^\s+or//;
        $base_sql .= " and (" . $combined_sql . ")";

        $base_sql .= " group by map_id1,map_id2";

        $count_sql = sprintf( $base_sql,
                'count(distinct cl.feature_correspondence_id) as no_corr, '
              . 'min(cl.start_position1) as min_start, '
              . 'max(cl.start_position1) as max_start , '
              . 'avg(((cl.stop_position1-cl.start_position1)/2)'
              . '+cl.start_position1) as avg_mid, '
              . 'avg(cl.start_position1) as start_avg1,'
              . 'avg(cl.start_position2) as start_avg2,'
              . 'min(cl.start_position2) as min_start2, '
              . 'max(cl.start_position2) as max_start2 , '
              . 'avg(((cl.stop_position2-cl.start_position2)/2)'
              . '+cl.start_position2) as avg_mid2, ' );
    }

    my %map_id_lookup = map { $_->{'map_id'}, 1 } @$maps;
    my %corr_lookup;
    if ($count_sql) {

        my ($map_corr_counts);
        unless (
            $map_corr_counts = $self->get_cached_results(
                4, $count_sql . join( ".", @query_args )
            )
          )
        {
            $map_corr_counts =
              $db->selectall_arrayref( $count_sql, { Columns => {} },
                @query_args );
            $self->store_cached_results( 4,
                $count_sql . join( ".", @query_args ),
                $map_corr_counts );
        }

        for my $count (@$map_corr_counts) {
            next unless $map_id_lookup{ $count->{'map_id2'} };

            $map_correspondences->{$this_slot_no}{ $count->{'map_id2'} }
              { $count->{'map_id1'} } = {
                map_id     => $count->{'map_id2'},
                ref_map_id => $count->{'map_id1'},
                no_corr    => $count->{'no_corr'},
                min_start  => $count->{'min_start'},
                max_start  => $count->{'max_start'},
                avg_mid    => $count->{'avg_mid'},
                min_start2 => $count->{'min_start2'},
                max_start2 => $count->{'max_start2'},
                avg_mid2   => $count->{'avg_mid2'},
                start_avg1 => $count->{'start_avg1'},
                start_avg2 => $count->{'start_avg2'},
              };
            $corr_lookup{ $count->{'map_id2'} } += $count->{'no_corr'};
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
    my $ref_species_aid         = $args{'ref_species_aid'}         || '';
    my $page_index_start        = $args{'page_index_start'}        || 1;
    my $page_index_stop         = $args{'page_index_stop'}         || 20;
    my $name_search             = $args{'name_search'}             || '';
    my $order_by                = $args{'order_by'}                || '';
    my $page_no                 = $args{'page_no'}                 || 1;
    my $ref_map                 = $slots->{0};
    my $ref_map_set_aid         = $ref_map->{'map_set_aid'}        || 0;
    my $db  = $self->db  or return;
    my $sql = $self->sql or return;
    my $map_type_data     = $self->map_type_data();
    my $feature_type_data = $self->feature_type_data();
    my $pid               = $$;
    my $no_maps;

    my @ref_maps;
    if ( $self->slot_info ) {
        foreach my $map_id ( keys( %{ $self->slot_info->{0} } ) ) {
            my %temp_hash = (
                map_id         => $self->slot_info->{0}{$map_id}[0],
                start_position => $self->slot_info->{0}{$map_id}[1],
                stop_position  => $self->slot_info->{0}{$map_id}[2],
            );
            push @ref_maps, \%temp_hash;
        }
    }

    my $sql_str;
    if ( $ref_map_set_aid && !$ref_species_aid ) {
        $sql_str = q[
            select s.accession_id
            from   cmap_map_set ms,
                   cmap_species s
            where  ms.accession_id=?
            and    ms.species_id=s.species_id
        ];

        if ( my $scalar_ref =
            $self->get_cached_results( 1, $sql_str . $ref_map_set_aid ) )
        {
            $ref_species_aid = $$scalar_ref;
        }
        else {
            $ref_species_aid =
              $db->selectrow_array( $sql_str, {}, ($ref_map_set_aid) );
            $self->store_cached_results( 1, $sql_str . $ref_map_set_aid,
                \$ref_species_aid );
        }
    }

    #
    # Select all the map set that can be reference maps.
    #
    $sql_str = q[
        select   distinct s.accession_id as species_aid,
                 s.display_order,
                 s.common_name as species_common_name,
                 s.full_name as species_full_name
        from     cmap_map_set ms,
                 cmap_species s
        where    ms.is_enabled=1
        and      ms.species_id=s.species_id
        order by s.display_order,
                 s.common_name, 
                 s.full_name
    ];

    my $ref_species;
    if ( my $scalar_ref = $self->get_cached_results( 1, $sql_str ) ) {
        $ref_species = $$scalar_ref;
    }
    else {
        $ref_species = $db->selectall_arrayref( $sql_str, { Columns => {} } );
        $self->store_cached_results( 1, $sql_str, \$ref_species );
    }

    if ( @$ref_species && !$ref_species_aid ) {
        $ref_species_aid = $ref_species->[0]{'species_aid'};
    }

    #
    # Select all the map sets that can be reference maps.
    #
    my $ref_map_sets = [];
    if ($ref_species_aid) {
        $sql_str = $sql->form_data_map_sets_sql($ref_species_aid);
        unless ( $ref_map_sets = $self->get_cached_results( 1, $sql_str ) ) {
            $ref_map_sets =
              $db->selectall_arrayref( $sql_str, { Columns => {} } );

            foreach my $row (@$ref_map_sets) {
                $row->{'map_type'} =
                  $map_type_data->{ $row->{'map_type_aid'} }{'map_type'};
            }
            $self->store_cached_results( 1, $sql_str, $ref_map_sets );
        }
    }

    #
    # If there's only one map set, pretend it was submitted.
    #
    if ( !$ref_map_set_aid && scalar @$ref_map_sets == 1 ) {
        $ref_map_set_aid = $ref_map_sets->[0]{'accession_id'};
    }

    my $ref_map_set_id;
    ###Get ref_map_set_id
    if ($ref_map_set_aid) {
        $sql_str = q[
            select ms.map_set_id
            from   cmap_map_set ms
            where  ms.accession_id=?
		];
        if ( my $scalar_ref =
            $self->get_cached_results( 1, $sql_str . $ref_map_set_aid ) )
        {
            $ref_map_set_id = $$scalar_ref;
        }
        else {
            $ref_map_set_id =
              $db->selectrow_array( $sql_str, {}, ($ref_map_set_aid) );
            $self->store_cached_results( 1, $sql_str . $ref_map_set_aid,
                \$ref_map_set_id );
        }
    }

    #
    # If the user selected a map set, select all the maps in it.
    #
    my ( $map_info, @map_ids, $ref_map_set_info );
    my ( $feature_info, @feature_type_aids );
    my $map_sql_str;
    if ($ref_map_set_id) {
        $map_sql_str = q[
            select    map.accession_id,
                      map.map_name,
                      map.start_position,
                      map.stop_position,
                      map.map_id,
                      map.display_order,
                      count(distinct(cl.map_id2)) as cmap_count,
                      count(distinct(cl.feature_correspondence_id)) 
                        as corr_count
            from      cmap_map map
            left join cmap_correspondence_lookup cl
            on        map.map_id=cl.map_id1
            where     map.map_set_id=?
        ];

        if ($name_search) {
            $map_sql_str .= " and map.map_name='$name_search' ";
        }

        $map_sql_str .= q[ 
            group by map.accession_id, map.map_id, map.map_name,
                     map.start_position, map.stop_position, map.display_order 
        ];

        if ( $min_correspondence_maps and $min_correspondences ) {
            $map_sql_str .=
                " having count(distinct(cl.map_id2))>=$min_correspondence_maps "
              . " and count(distinct(cl.feature_correspondence_id))>="
              . "$min_correspondences ";
        }
        elsif ($min_correspondence_maps) {
            $map_sql_str .=
                " having count(distinct(cl.map_id2)) >="
              . "'$min_correspondence_maps' ";
        }
        elsif ($min_correspondences) {
            $map_sql_str .=
                " having count(distinct("
              . "cl.feature_correspondence_id)) >=$min_correspondences ";
        }

        ###Get map info
        unless ( $map_info =
            $self->get_cached_results( 4, $map_sql_str . "$ref_map_set_id" ) )
        {
            $map_info =
              $db->selectall_hashref( $map_sql_str, 'map_id', { Columns => {} },
                ("$ref_map_set_id") );

            $self->error(
qq[No maps exist for the ref. map set acc. id "$ref_map_set_aid"]
              )
              unless %$map_info;

            ### Work out the numbers per unit and reformat them.
            for my $map_id ( keys %$map_info ) {
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

            $self->store_cached_results( 4, $map_sql_str . "$ref_map_set_id",
                $map_info );
        }

        @map_ids = keys %$map_info;

        ### Add feature type information
        $sql_str = q[
            select  map.map_id,
                    f.feature_type_accession as feature_type_aid,
                    count(distinct(f.feature_id)) as feature_count
            from    cmap_map map,
                    cmap_feature f 
            where   map.map_set_id=?
            and     map.map_id=f.map_id
        ];

        if ( ( $min_correspondence_maps || $min_correspondences ) && @map_ids )
        {
            $sql_str .= " and map.map_id in (" . join( ",", @map_ids ) . ") ";
        }

        if ($name_search) {
            $sql_str .= " and map.map_name='$name_search' ";
        }

        $sql_str .= q[ group by map.map_id, f.feature_type_accession ];

        if ( my $array_ref =
            $self->get_cached_results( 3, $sql_str . "$ref_map_set_id" ) )
        {
            $feature_info      = $array_ref->[0];
            @feature_type_aids = @{ $array_ref->[1] };
        }
        else {
            my $feature_info_results =
              $db->selectall_arrayref( $sql_str, { Columns => {} },
                ("$ref_map_set_id") );

            my %feature_type_hash;
            for my $row (@$feature_info_results) {
                $feature_type_hash{ $row->{'feature_type_aid'} } = 1;
                $feature_info->{ $row->{'map_id'} }
                  { $row->{'feature_type_aid'} }{'total'} =
                  $row->{'feature_count'};

                my $raw_no = (
                    $row->{'feature_count'} / (
                        $map_info->{ $row->{'map_id'} }{'stop_position'} -
                          $map_info->{ $row->{'map_id'} }{'start_position'}
                    )
                );

                $feature_info->{ $row->{'map_id'} }
                  { $row->{'feature_type_aid'} }{'raw_per'} = $raw_no;

                $feature_info->{ $row->{'map_id'} }
                  { $row->{'feature_type_aid'} }{'per'} =
                  presentable_number_per($raw_no);
            }

            @feature_type_aids = keys %feature_type_hash;
            $self->store_cached_results(
                3,
                $sql_str . "$ref_map_set_id",
                [ $feature_info, \@feature_type_aids ]
            );
        }

        ###Sort maps
        if (
            my $array_ref = $self->get_cached_results(
                4, $map_sql_str . $order_by . "_" . $ref_map_set_id
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
                $map_sql_str . $order_by . "_" . $ref_map_set_id, \@map_ids );
        }
    }

    my %feature_types =
      map { $_ => $feature_type_data->{$_} } @feature_type_aids;

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
sub get_all_feature_types {
    my $self = shift;

    my $ra;
    my $slot_info         = $self->slot_info;
    my $db                = $self->db;
    my $feature_type_data = $self->feature_type_data();
    my @map_id_list;
    foreach my $slot_no ( keys %{$slot_info} ) {
        push @map_id_list, keys( %{ $slot_info->{$slot_no} } );
    }
    return [] unless @map_id_list;

    my $sql_str = q[
        select distinct feature_type_accession as feature_type_aid 
        from cmap_feature 
        where 
        ];
    $sql_str .= " map_id in (" . join( ',', @map_id_list );
    $sql_str .= ")";
    $sql_str .= "  order by feature_type_aid";

    unless ( $ra = $self->get_cached_results( 3, $sql_str ) ) {
        $ra = $db->selectall_hashref( $sql_str, 'feature_type_aid', {}, () );
        foreach my $rowKey ( keys %{$ra} ) {
            $ra->{$rowKey}->{'feature_type'} =
              $feature_type_data->{ $ra->{$rowKey}->{'feature_type_aid'} }
              {'feature_type'};
            $ra->{$rowKey}->{'shape'} =
              $feature_type_data->{ $ra->{$rowKey}->{'feature_type_aid'} }
              {'shape'};
            $ra->{$rowKey}->{'color'} =
              $feature_type_data->{ $ra->{$rowKey}->{'feature_type_aid'} }
              {'color'};
        }
        $self->store_cached_results( 3, $sql_str, $ra );
    }

    my @return = ();
    foreach my $key ( keys %{$ra} ) {
        push @return, $ra->{$key};
    }

    return \@return;
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

    my %ref_for_unit;
    my %set_by_slot;
    foreach my $slot_id ( sort orderOutFromZero keys %$slots ) {
        foreach my $map_id ( keys %{ $slots->{$slot_id} } ) {
            my $map = $slots->{$slot_id}{$map_id};
            if (    defined( $set_by_slot{ $map->{'map_units'} } )
                and $set_by_slot{ $map->{'map_units'} } != $slot_id
                and $ref_for_unit{ $map->{'map_units'} } )
            {
                last;
            }
            else {
                $set_by_slot{ $map->{'map_units'} } = $slot_id;
                if ( !$ref_for_unit{ $map->{'map_units'} }
                    or $ref_for_unit{ $map->{'map_units'} } <
                    $map->{'stop_position'} - $map->{'start_position'} )
                {
                    $ref_for_unit{ $map->{'map_units'} } =
                      $map->{'stop_position'} - $map->{'start_position'};
                }
            }
        }
    }

    return \%ref_for_unit;
}

# ----------------------------------------------------
sub compress_maps {

=pod

=head2 compress_maps

Decide if the maps should be compressed.
If it is aggregated, compress unless the slot contain only 1 map.
If it is not aggregated don't compress. 

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
          unless ( defined( $map_info->[0] ) or defined( $map_info->[1] ) );

        my $start = $map_info->[0];
        my $stop  = $map_info->[1];

        if ( ( $is_up and not $is_flipped ) or ( $is_flipped and not $is_up ) )
        {

            # Scroll data for up arrow
            return ( undef, undef, $mag ) unless defined($start);
            my $view_length =
              defined($stop) ? ( $stop - $start ) : $map_info->[3] - $start;
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
              defined($start) ? ( $stop - $start ) : $stop - $map_info->[2];
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

    my $self = shift;

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

    my $self                  = shift;
    my $slots                 = shift;
    my $ignored_feature_list  = shift;
    my $included_evidence_type_aids = shift;
    my $less_evidence_type_aids = shift;
    my $greater_evidence_type_aids = shift;
    my $evidence_type_score = shift;
    my $min_correspondences   = shift;
    my $db                    = $self->db;


    # Return slot_info is not setting it.
    return $self->{'slot_info'} unless ($slots);

    my $sql_base = q[
	  select distinct m.map_id,
             m.start_position,
             m.stop_position,
             m.start_position,
             m.stop_position,
             m.accession_id
	  from   cmap_map m
	  ];

    #print S#TDERR Dumper($slots)."\n";
    my $sql_suffix;
    foreach my $slot_no ( sort orderOutFromZero keys %{$slots} ) {
        next unless ( $slots->{$slot_no} );
        my $from      = ' ';
        my $where     = '';
        my $group_by  = '';
        my $having    = '';
        my $aid_where = '';
        my $sql_str   = '';
        my $map_sets  = $slots->{$slot_no}{'map_sets'};
        my $maps      = $slots->{$slot_no}{'maps'};

        if ( $slot_no == 0 ) {
            if ( $map_sets and %{$map_sets} ) {
                $from .= q[,
                  cmap_map_set ms ];
                $where .= " m.map_set_id=ms.map_set_id ";

                #Map set aid
                $aid_where .=
                    " (ms.accession_id = '"
                  . join( "' or ms.accession_id = '", keys( %{$map_sets} ) )
                  . "') ";
            }
            if ( $maps and %{$maps} ) {

                $aid_where .= ' or ' if ($aid_where);
                $aid_where .=
                  " m.accession_id in ('"
                  . join( "','", keys( %{$maps} ) ) . "')";
            }
        }
        else {
            my $slot_modifier = $slot_no > 0 ? -1 : 1;
            $from .= q[,
              cmap_correspondence_lookup cl
              ];
            $where .= q[ m.map_id=cl.map_id1 
                     and cl.map_id1!=cl.map_id2 ];

            ### Add the information about the adjoinint slot
            ### including info about the start and end.
            $where .= " and (";
            my @ref_map_strs = ();
            my $ref_slot_id  = $slot_no + $slot_modifier;
            my $slot_info    = $self->{'slot_info'}{$ref_slot_id};
            next unless $slot_info;
            foreach my $m_id ( keys( %{ $self->{'slot_info'}{$ref_slot_id} } ) )
            {
                my $r_m_str = " (cl.map_id2 = $m_id ";
                if (    defined( $slot_info->{$m_id}->[0] )
                    and defined( $slot_info->{$m_id}->[1] ) )
                {
                    $r_m_str .=
                        " and (( cl.start_position2>="
                      . $slot_info->{$m_id}->[0]
                      . " and cl.start_position2<="
                      . $slot_info->{$m_id}->[1]
                      . " ) or ( cl.stop_position2 is not null and "
                      . "  cl.start_position2<="
                      . $slot_info->{$m_id}->[0]
                      . " and cl.stop_position2>="
                      . $slot_info->{$m_id}->[0] . " ))) ";
                }
                elsif ( defined( $slot_info->{$m_id}->[0] ) ) {
                    $r_m_str .=
                        " and (( cl.start_position2>="
                      . $slot_info->{$m_id}->[0]
                      . " ) or ( cl.stop_position2 is not null "
                      . " and cl.stop_position2>="
                      . $slot_info->{$m_id}->[0] . " ))) ";
                }
                elsif ( defined( $slot_info->{$m_id}->[1] ) ) {
                    $r_m_str .=
                      " and cl.start_position2<="
                      . $slot_info->{$m_id}->[1] . ") ";
                }
                else {
                    $r_m_str .= ") ";
                }

                push @ref_map_strs, $r_m_str;
            }
            $where .= join( ' or ', @ref_map_strs ) . ") ";

            ### Add in considerations for feature and evidence types
            if ( $ignored_feature_list and @$ignored_feature_list ) {
                $where .=
                  " and cl.feature_type_accession1 not in ('"
                  . join( "','", @$ignored_feature_list ) . "') ";
            }
#xx5
            if ( @$included_evidence_type_aids or @$less_evidence_type_aids
                    or @$greater_evidence_type_aids ) {
                $from  .= ", cmap_correspondence_evidence ce ";
                $where .=
                    " and ce.feature_correspondence_id = "
                  . "cl.feature_correspondence_id ";
                $where .= "and ( ";
                my @join_array;
                if ( @$included_evidence_type_aids ) {
                    push @join_array,
                      " ce.evidence_type_accession in ('"
                      . join( "','", @$included_evidence_type_aids ) . "')";
                }
                foreach my $et_aid (@$less_evidence_type_aids ) {
                    push @join_array,
                        " ( ce.evidence_type_accession = '$et_aid' "
                      . " and ce.score <= ".$evidence_type_score->{$et_aid}." ) ";
                }
                foreach my $et_aid (@$greater_evidence_type_aids ) {
                    push @join_array,
                        " ( ce.evidence_type_accession = '$et_aid' "
                      . " and ce.score >= ".$evidence_type_score->{$et_aid}." ) ";
                }
                $where .= join (' or ', @join_array). " ) ";
            }
            else {
                $from  .= ", cmap_correspondence_evidence ce ";
                $where .= " and ce.correspondence_evidence_id = -1 ";
            }

            # Get Map Sets
            if ( $map_sets and %{$map_sets} ) {
                $from .= q[,
                  cmap_map_set ms ];
                $where .= " and m.map_set_id=ms.map_set_id ";

                #Map set aid
                $aid_where .=
                    "(ms.accession_id = '"
                  . join( "' or ms.accession_id = '", keys( %{$map_sets} ) )
                  . "')";
            }
            if ( $maps and %{$maps} ) {
                $aid_where .= ' or ' if ($aid_where);
                $aid_where .=
                  " m.accession_id in ('"
                  . join( "','", keys( %{$maps} ) ) . "')";
                foreach my $map_aid (keys %{$maps} ) {
                    if (defined($maps->{$map_aid}{'start'}) 
                        and defined($maps->{$map_aid}{'stop'} ) ) {
                        $aid_where .= 
                            qq[ and ( not m.accession_id = '$map_aid'  ]
                          . " or (( cl.start_position1>="
                          . $maps->{$map_aid}{'start'}
                          . " and cl.start_position1<="
                          . $maps->{$map_aid}{'stop'} 
                          . " ) or ( cl.stop_position1 is not null and "
                          . "  cl.start_position1<="
                          . $maps->{$map_aid}{'start'}
                          . " and cl.stop_position1>="
                          . $maps->{$map_aid}{'start'} . " ))) ";
                    }
                    elsif ( defined( $maps->{$map_aid}{'start'} ) ) {
                        $aid_where .= 
                            qq[ and ( not m.accession_id = '$map_aid'  ]
                            . " or (( cl.start_position1>="
                          . $maps->{$map_aid}{'start'}
                          . " ) or ( cl.stop_position1 is not null "
                          . " and cl.stop_position1>="
                          . $maps->{$map_aid}{'start'} . " ))) ";
                    }
                    elsif ( defined( $maps->{$map_aid}{'stop'}  ) ) {
                        $aid_where .= 
                            qq[ and ( not m.accession_id = '$map_aid'  ]
                            . " or cl.start_position1<="
                            . $maps->{$map_aid}{'stop'}  . ") ";
                    }
                }
            }
            if ($min_correspondences) {
                $group_by = q[ 
                    group by cl.map_id2,
                             m.start_position,
                             m.stop_position,
                             m.start_position,
                             m.stop_position,
                             m.accession_id
                    ];
                $having   = " having count(cl.feature_correspondence_id)>=$min_correspondences ";
            }
        }
        if ($where) {
            $where = " where $where and ( $aid_where )";
        }
        else {
            $where = " where $aid_where ";
        }
        $sql_str = "$sql_base $from $where $group_by $having\n";

        # The min_correspondences sql code doesn't play nice with distinct
        if ($min_correspondences and $slot_no != 0){
            $sql_str =~ s/distinct//;
        }

        #print S#TDERR "SLOT_INFO SQL \n$sql_str\n";

        my $slot_results;

        unless ( $slot_results = $self->get_cached_results( 4, $sql_str ) ) {
            $slot_results = $db->selectall_arrayref( $sql_str, {}, () );
            $self->store_cached_results( 4, $sql_str, $slot_results );
        }

        # Add start and end values into slot_info
        if ( $maps and %{$maps} ) {
            foreach my $row (@$slot_results) {
                if ( defined( $maps->{ $row->[5] }{'start'} ) ) {
                    $row->[1] = $maps->{ $row->[5] }{'start'};
                    ### If start is a feature, get the positions
                    ### and store in both places.
                    if ( not $row->[1] =~ /^$RE{'num'}{'real'}$/ ) {
                        $row->[1] = $self->feature_name_to_position(
                            feature_name        => $row->[1],
                            map_id              => $row->[0],
                            start_position_only => 1,
                          )
                          || undef;
                        $maps->{ $row->[5] }{'start'} = $row->[1];
                    }
                }
                else {
                    $row->[1] = undef;
                }
                if ( defined( $maps->{ $row->[5] }{'stop'} ) ) {
                    $row->[2] = $maps->{ $row->[5] }{'stop'};
                    ### If stop is a feature, get the positions.
                    ### and store in both places.
                    if ( not $row->[2] =~ /^$RE{'num'}{'real'}$/ ) {
                        $row->[2] = $self->feature_name_to_position(
                            feature_name        => $row->[2],
                            map_id              => $row->[0],
                            start_position_only => 0,
                          )
                          || undef;
                        $maps->{ $row->[5] }{'stop'} = $row->[2];
                    }
                }
                else {
                    $row->[2] = undef;
                }
                ###flip start and end if start>end
                ( $row->[1], $row->[2] ) = ( $row->[2], $row->[1] )
                  if (  defined( $row->[1] )
                    and defined( $row->[2] )
                    and $row->[1] > $row->[2] );
            }
        }
        else {
            ###No Maps specified, make all start/stops undef
            foreach my $row (@$slot_results) {
                $row->[1] = undef;
                $row->[2] = undef;
            }
        }
        foreach my $row (@$slot_results) {
            if ( defined( $row->[1] ) and $row->[1] =~ /(.+)\.0+$/ ) {
                $row->[1] = $1;
            }
            if ( defined( $row->[2] ) and $row->[2] =~ /(.+)\.0+$/ ) {
                $row->[2] = $1;
            }
            if ( $row->[3] =~ /(.+)\.0+$/ ) {
                $row->[3] = $1;
            }
            if ( $row->[4] =~ /(.+)\.0+$/ ) {
                $row->[4] = $1;
            }
            my $magnification = 1;
            if ( defined( $maps->{ $row->[5] }{'mag'} ) ) {
                $magnification = $maps->{ $row->[5] }{'mag'};
            }

            $self->{'slot_info'}{$slot_no}{ $row->[0] } =
              [ $row->[1], $row->[2], $row->[3], $row->[4], $magnification ];
        }
    }

    # If ever a slot has no maps, remove the slot.
    my $delete_pos = 0;
    my $delete_neg = 0;
    foreach my $slot_no ( sort orderOutFromZero keys %{$slots} ) {
        if ( scalar( keys( %{ $self->{'slot_info'}{$slot_no} } ) ) <= 0 ) {
            if ( $slot_no >= 0 ) {
                $delete_pos = 1;
            }
            if ( $slot_no <= 0 ) {
                $delete_neg = 1;
            }
        }
        if ( $slot_no >= 0 and $delete_pos ) {
            delete $self->{'slot_info'}{$slot_no};
            delete $slots->{$slot_no};
        }
        elsif ( $slot_no < 0 and $delete_neg ) {
            delete $self->{'slot_info'}{$slot_no};
            delete $slots->{$slot_no};
        }
    }

    #print S#TDERR Dumper($self->{'slot_info'})."\n";
    return $self->{'slot_info'};
}

sub orderOutFromZero {
    ###Return the sort in this order (0,1,-1,-2,2,-3,3,)
    return ( abs($a) cmp abs($b) );
}
###########################################

=pod
                                                                                
=head2 Query Caching
                                                                                
Query results (and subsequent manipulations) are cached 
in a Cache::FileCache file.

There are four levels of caching.  This is so that if some part of 
the database is changed, the whole chache does not have to be purged.  
Only the cache level and the levels above it need to be cached.

Level 1: Species or Map Sets.
Level 2: Maps
Level 3: Features
Level 4: Correspondences

For example if features are added, then Level 3 and 4 need to be purged.
If a new Map is added, Levels 2,3 and 4 need to be purged.

=cut

# ----------------------------------------------------
sub cache_array_results {

    my ( $self, $cache_level, $sql, $attr, $args, $db, $select_type, $sub ) =
      @_;
    $cache_level = 1 unless $cache_level;
    my $data;
    my $cache_key = $sql . join( '-', @$args );
    unless ( !$self->{'disable_cache'}
        and $data =
        thaw( $self->{ 'L' . $cache_level . '_cache' }->get($cache_key) ) )
    {
        $data = $db->$select_type( $sql, $attr, @$args );
        if ( ref $sub eq 'CODE' ) {
            $sub->( $data, $db );
        }
        $self->{ 'L' . $cache_level . '_cache' }
          ->set( $cache_key, freeze($data) );
    }
    return $data;
}

# ----------------------------------------------------
sub get_cached_results {
    my $self        = shift;
    my $cache_level = shift;
    my $query       = shift;
    return undef if ( $self->{'disable_cache'} );
    $cache_level = 1 unless $cache_level;

    return undef unless ($query);
    return thaw( $self->{ "L" . $cache_level . "_cache" }->get($query) );
}

sub store_cached_results {
    my $self        = shift;
    my $cache_level = shift;
    my $query       = shift;
    my $object      = shift;
    return undef if ( $self->{'disable_cache'} );
    $cache_level = 1 unless $cache_level;

    $self->{ "L" . $cache_level . "_cache" }->set( $query, freeze($object) );
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

