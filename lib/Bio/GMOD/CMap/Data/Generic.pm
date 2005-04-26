package Bio::GMOD::CMap::Data::Generic;

# vim: set ft=perl:

# $Id: Generic.pm,v 1.69 2005-04-26 23:26:29 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Data::Generic - generic SQL module

=head1 SYNOPSIS

  package Bio::GMOD::CMap::Data::FooDB;

  use Bio::GMOD::CMap::Data::Generic;
  use base 'Bio::GMOD::CMap::Data::Generic';

  sub sql_method_that_doesnt_work {
      return $sql_tailored_to_my_db;
  }

  1; 

=head1 DESCRIPTION

This module will hold what is meant to be database-independent, ANSI
SQL.  Whenever this doesn't work for a specific RDBMS, then you can
drop into the derived class and override a method.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.69 $)[-1];

use Data::Dumper;    # really just for debugging
use Time::ParseDate;
use Bio::GMOD::CMap::Utils;
use Bio::GMOD::CMap;
use base 'Bio::GMOD::CMap';

# ----------------------------------------------------
sub init {

=pod

=head2 init 

Initialize values that will be needed.

=cut

    my ( $self, $config ) = @_;
    $self->{'ID_FIELDS'} = {
        cmap_attribute               => 'attribute_id',
        cmap_correspondence_evidence => 'correspondence_evidence_id',
        cmap_feature                 => 'feature_id',
        cmap_feature_alias           => 'feature_alias_id',
        cmap_feature_correspondence  => 'feature_correspondence_id',
        cmap_map                     => 'map_id',
        cmap_map_set                 => 'map_set_id',
        cmap_species                 => 'species_id',
        cmap_xref                    => 'xref_id',
    };
    $self->{'TABLE_NAMES'} = {
        correspondence_evidence => 'cmap_correspondence_evidence',
        feature                 => 'cmap_feature',
        feature_alias           => 'cmap_feature_alias',
        feature_correspondence  => 'cmap_feature_correspondence',
        map                     => 'cmap_map',
        map_set                 => 'cmap_map_set',
        species                 => 'cmap_species',
        xref                    => 'cmap_xref',
    };

    return $self;
}

# ----------------------------------------------------
sub cmap_data_features_sql {    #NOTCHANGED 70

=pod

=head2 cmap_data_features_sql

The SQL for finding all the features on a map.

=cut

    my ( $self, %args ) = @_;
    my $order_by    = $args{'order_by'}    || '';
    my $restrict_by = $args{'restrict_by'} || '';
    my @feature_type_aids = @{ $args{'feature_type_aids'} || [] };

    my $sql = qq[
        select   f.feature_id,
                 f.accession_id,
                 f.feature_name,
                 f.is_landmark,
                 f.start_position,
                 f.stop_position,
                 f.feature_type_accession as feature_type_aid,
                 f.default_rank,
                 map.accession_id as map_aid,
                 ms.map_units
        from     cmap_feature f,
                 cmap_map map,
                 cmap_map_set ms
        where    f.map_id=?
        and      (
            ( f.start_position>=? and f.start_position<=? )
            or   (
                f.stop_position is not null and
                f.start_position<=? and
                f.stop_position>=?
            )
        )
        and      f.map_id=map.map_id
        and      map.map_set_id=ms.map_set_id
    ];

    if (@feature_type_aids) {
        $sql .=
          "and f.feature_type_accession in ('"
          . join( "','", @feature_type_aids ) . "')";
    }

    $sql .= "order by $order_by" if $order_by;

    return $sql;
}

# ----------------------------------------------------
sub date_format {    #NOTCHANGED

=pod

=head2 date_format

The strftime string for date format.

=cut

    my $self = shift;
    return '%Y-%m-%d';
}

# ----------------------------------------------------
sub feature_correspondence_sql {    #NOTCHANGED 67 71

=pod

=head2 feature_correspondence_sql

The SQL for finding correspondences for a feature.

=cut

    my $self = shift;
    my %args = @_;

    my $sql = q[
        select   f.feature_name,
                 f.feature_id,
                 f.accession_id as feature_aid,
                 f.start_position,
                 f.stop_position,
                 f.feature_type_accession as feature_type_aid,
                 map.map_id,
                 map.accession_id as map_aid,
                 map.map_name,
                 map.display_order as map_display_order,
                 ms.map_set_id,
                 ms.accession_id as map_set_aid,
                 ms.short_name as map_set_name,
                 ms.display_order as ms_display_order,
                 ms.published_on,
                 ms.map_type_accession as map_type_aid,
                 ms.map_units,
                 s.species_common_name,
                 s.display_order as species_display_order,
                 fc.feature_correspondence_id,
                 fc.accession_id as feature_correspondence_aid,
                 ce.evidence_type_accession as evidence_type_aid
        from     cmap_correspondence_lookup cl, 
                 cmap_feature_correspondence fc,
                 cmap_correspondence_evidence ce,
                 cmap_feature f,
                 cmap_map map,
                 cmap_map_set ms,
                 cmap_species s
        where    cl.feature_correspondence_id=fc.feature_correspondence_id
        and      fc.feature_correspondence_id=ce.feature_correspondence_id
        and      cl.feature_id1=?
        and      cl.feature_id2=f.feature_id
        and      f.map_id=map.map_id
        and      map.map_set_id=ms.map_set_id
        and      ms.is_enabled=1
        and      ms.species_id=s.species_id
    ];

    if ( $args{'comparative_map_field'} eq 'map_set_aid' ) {
        $sql .= "and ms.accession_id='" . $args{'comparative_map_aid'} . "' ";
    }
    elsif ( $args{'comparative_map_field'} eq 'map_aid' ) {
        $sql .= "and map.accession_id='" . $args{'comparative_map_aid'} . "' ";
    }

    my $included_evidence_type_aids = $args{'included_evidence_type_aids'}
      || [];
    my $less_evidence_type_aids    = $args{'less_evidence_type_aids'}    || [];
    my $greater_evidence_type_aids = $args{'greater_evidence_type_aids'} || [];
    my $evidence_type_score        = $args{'evidence_type_score'}        || {};
    my $disregard_evidence_type    = $args{'disregard_evidence_type'}    || 0;

    if (
        !$disregard_evidence_type
        and (  @$included_evidence_type_aids
            or @$less_evidence_type_aids
            or @$greater_evidence_type_aids )
      )
    {
        $sql .= "and ( ";
        my @join_array;
        if (@$included_evidence_type_aids) {
            push @join_array,
              " ce.evidence_type_accession in ('"
              . join( "','", @$included_evidence_type_aids ) . "')";
        }
        foreach my $et_aid (@$less_evidence_type_aids) {
            push @join_array,
              " ( ce.evidence_type_accession = '$et_aid' "
              . " and ce.score <= "
              . $evidence_type_score->{$et_aid} . " ) ";
        }
        foreach my $et_aid (@$greater_evidence_type_aids) {
            push @join_array,
              " ( ce.evidence_type_accession = '$et_aid' "
              . " and ce.score >= "
              . $evidence_type_score->{$et_aid} . " ) ";
        }
        $sql .= join( ' or ', @join_array ) . " ) ";
    }
    elsif ( !$disregard_evidence_type ) {
        $sql .= " and ce.evidence_type_accession = '-1' ";
    }

    $sql .= q[
            order by species_display_order, species_common_name, 
            ms_display_order, map_set_name, map_display_order,
            map_name, start_position, feature_name
    ];

    return $sql;
}

# ----------------------------------------------------
sub feature_detail_data_sql {    #NOTCHANGED 66

=pod

=head2 feature_detail_data_sql

The SQL for finding basic info on a feature.

=cut

    my $self = shift;
    return q[
        select     f.feature_id, 
                   f.accession_id as feature_aid, 
                   f.map_id,
                   f.feature_name,
                   f.is_landmark,
                   f.start_position,
                   f.stop_position,
                   f.feature_type_accession as feature_type_aid,
                   map.map_name,
                   map.accession_id as map_aid,
                   ms.map_set_id,
                   ms.accession_id as map_set_aid,
                   ms.short_name as map_set_name,
                   s.species_id,
                   s.accession_id as species_aid,
                   s.species_common_name,
                   ms.map_type_accession as map_type_aid,
                   ms.map_units
        from       cmap_feature f
        inner join cmap_map map
        on         f.map_id=map.map_id
        inner join cmap_map_set ms
        on         map.map_set_id=ms.map_set_id
        inner join cmap_species s
        on         ms.species_id=s.species_id
        where      f.accession_id=?
    ];
}

# ----------------------------------------------------
sub form_data_ref_map_sets {

=pod

=head2 form_data_ref_map_sets

The SQL for finding all reference map sets.

=cut

    my ( $self, %args ) = @_;
    my $ref_species_aid = $args{'ref_species_aid'} || 0;
    my $cmap_object = $args{'cmap_object'} or return;
    my $db          = $args{'db'}          or return;
    my $return_object;
    my $map_type_data = $self->map_type_data();

    my $sql_str = q[
        select   ms.accession_id, 
                 ms.map_set_id,
                 ms.short_name as map_set_name,
                 ms.display_order as map_set_display_order,
                 ms.published_on,
                 s.species_common_name,
                 s.display_order as species_display_order,
                 ms.map_type_accession as map_type_aid
        from     cmap_map_set ms,
                 cmap_species s
        where    ms.can_be_reference_map=1
        and      ms.is_enabled=1
        and      ms.species_id=s.species_id
    ];
    $sql_str .= "and s.accession_id='$ref_species_aid' "
      if $ref_species_aid
      and $ref_species_aid ne '-1';
    $sql_str .= q[
        and      ms.is_relational_map=0
        order by ms.display_order,
                 ms.map_type_accession,
                 s.display_order,
                 species_common_name,
                 ms.published_on desc,
                 ms.map_set_name
    ];

    unless ( $return_object = $cmap_object->get_cached_results( 1, $sql_str ) )
    {
        $return_object =
          $db->selectall_arrayref( $sql_str, { Columns => {} }, );

        foreach my $row (@$return_object) {
            $row->{'map_type'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'map_type'};
            $row->{'map_type_display_order'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'display_order'};
            $row->{'epoch_published_on'} = parsedate( $row->{'published_on'} );
        }

        $return_object = sort_selectall_arrayref(
            $return_object,            '#map_type_display_order',
            'map_type',                '#species_display_order',
            'species_common_name',            '#map_set_display_order',
            'epoch_published_on desc', 'map_set_name',
        );

        $cmap_object->store_cached_results( 1, $sql_str, $return_object );
    }

    return $return_object;
}

# ----------------------------------------------------
sub form_data_map_sets_sql {    #NOTCHANGED 72

=pod

=head2 form_data_map_sets_sql

The SQL for finding all map sets.

=cut

    my $self            = shift;
    my $ref_species_aid = shift || 0;
    my $sql             = q[
        select   ms.accession_id, 
                 ms.map_set_id,
                 ms.short_name as map_set_name,
                 ms.display_order as map_set_display_order,
                 ms.published_on,
                 s.species_common_name,
                 s.display_order as species_display_order,
                 ms.map_type_accession as map_type_aid
        from     cmap_map_set ms,
                 cmap_species s
        where    ms.is_enabled=1
        and      ms.species_id=s.species_id
    ];
    $sql .= "and s.accession_id='$ref_species_aid' "
      if $ref_species_aid
      and $ref_species_aid ne '-1';
    $sql .= q[
        order by ms.display_order,
                 ms.map_type_accession,
                 s.display_order,
                 species_common_name,
                 ms.published_on desc,
                 ms.map_set_name
    ];

    return $sql;
}

# ----------------------------------------------------
sub form_data_ref_maps_sql {    #NOTCHANGED 65

=pod

=head2 form_data_ref_maps_sql

The SQL for finding all reference maps.

=cut

    my $self = shift;

    return q[
        select   map.accession_id,
                 map.map_name
        from     cmap_map map,
                 cmap_map_set ms
        where    map.map_set_id=ms.map_set_id
        and      ms.accession_id=?
        order by map.display_order,
                 map.map_name
    ];
}

# ----------------------------------------------------
sub map_stop_sql {    #NOTCHANGED 68

=pod

=head2 map_stop_sql

The SQL for finding the maximum position of features.

=cut

    my ( $self, %args ) = @_;
    my $sql;

    if ( $args{'map_aid'} ) {
        $sql .= q[
            select   max(f.start_position), 
                     max(f.stop_position)
            from     cmap_feature f,
                     cmap_map map
            where    f.map_id=map.map_id
            and      map.accession_id=?
            group by f.map_id
        ];
    }
    else {
        $sql .= q[
            select   max(f.start_position), 
                     max(f.stop_position)
            from     cmap_feature f
            where    f.map_id=?
            group by f.map_id
        ];
    }

    return $sql;
}

# ----------------------------------------------------
sub map_start_sql {    #NOTCHANGED 69

=pod

=head2 map_start_sql

The SQL for finding the minimum position of features.

=cut

    my ( $self, %args ) = @_;
    my $sql;

    if ( $args{'map_aid'} ) {
        $sql .= q[
            select   min(f.start_position)
            from     cmap_feature f,
                     cmap_map map
            where    f.map_id=map.map_id
            and      map.accession_id=?
            group by f.map_id
        ];
    }
    else {
        $sql .= q[
            select   min(f.start_position)
            from     cmap_feature f
            where    f.map_id=?
            group by f.map_id
        ];
    }

    return $sql;
}

#------------NEW METHODS--------------------------------------------------

#-----------------------------------------------
sub acc_id_to_internal_id {    #YYY 1 58

=pod

=head2 acc_id_to_internal_id

=head3 Description

Return the internal id that corresponds to the accession id

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=item * Accession ID (acc_id)

=item * table name (table)

=back

=head3 Output

ID Scalar

=head3 Cache Level (If Used): 4  

Not using cache because this query is quicker.

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or return;
    my $object_name = $args{'object_name'} or $self->error('No object name');
    my $acc_id      = $args{'acc_id'}      or $self->error('No accession id');
    my $table_name = $self->{'TABLE_NAMES'}->{$object_name};
    my $id_field   = $self->{'ID_FIELDS'}->{$table_name};
    my $aid_field  = 'accession_id';

    my $db = $cmap_object->db;
    my $return_object;

    my $sql_str = qq[
            select $id_field
            from   $table_name
            where  $aid_field=?
      ];
    $return_object = $db->selectrow_array( $sql_str, {}, ($acc_id) )
      or $self->error(
qq[Unable to find internal id for acc. id "$acc_id" in table "$table_name"]
      );

    return $return_object;
}

#-----------------------------------------------
sub get_attributes {    #YYY

=pod

=head2 get_attributes

=head3 Description

Retrieves the attributes attached to a database object.

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=item * Object such as feature or map_set (object_name)

=item * [ Object ID (object_id) ]

If object_id is not supplied, this will return all attributes for this object_name
that have non-null object_ids.

=item * [ Order by clause (order_by) ]

=back

=head3 Output

Array of Hashes:

  Keys:
    attribute_id,
    object_id,
    table_name,
    display_order,
    is_public,
    attribute_name,
    attribute_value

=head3 Cache Level (If Used): 4

Not using cache because this query is quicker.

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or return;
    my $object_name = $args{'object_name'} or return;
    my $object_id   = $args{'object_id'};
    my $order_by    = $args{'order_by'};
    my $db          = $cmap_object->db;
    my $return_object;

    my $table_name = $self->{'TABLE_NAMES'}->{$object_name};
    if ( !$order_by || $order_by eq 'display_order' ) {
        $order_by = 'display_order,attribute_name';
    }

    my $sql_str = qq[
        select   attribute_id,
                 object_id,
                 table_name,
                 display_order,
                 is_public,
                 attribute_name,
                 attribute_value
        from     cmap_attribute
        where    
    ];
    $sql_str .= $object_id
      ? " object_id=? "
      : " object_id is not null ";
    $sql_str .= qq[
            and      table_name=?
            order by $order_by
    ];
    if ($object_id) {
        $return_object = $db->selectall_arrayref(
            $sql_str,
            { Columns => {} },
            ( $object_id, $table_name )
        );
    }
    else {
        $return_object =
          $db->selectall_arrayref( $sql_str, { Columns => {} }, ($table_name) );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_xrefs {    #YYY

=pod

=head2 get_xrefs

=head3 Description

etrieves the attributes attached to a database object.

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=item * Object such as feature or map_set (object_name)

=item * [ Object ID (object_id) ]

If object_id is not supplied, this will return all attributes for this object_name
that have non-null object_ids.

=item * [ Order by clause (order_by) ]

=back

=head3 Output

Array of Hashes:

  Keys:
    xref_id
    object_id
    display_order
    xref_name
    xref_url

=head3 Cache Level (If Used): 4

Not using cache because this query is quicker.

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or return;
    my $object_name = $args{'object_name'} or return;
    my $object_id   = $args{'object_id'};
    my $order_by    = $args{'order_by'};
    my $db          = $cmap_object->db;
    my $return_object;

    my $table_name = $self->{'TABLE_NAMES'}->{$object_name};
    if ( !$order_by || $order_by eq 'display_order' ) {
        $order_by = 'display_order,xref_name';
    }

    my $sql_str = qq[
            select   xref_id,
                     object_id,
                     display_order,
                     xref_name,
                     xref_url
            from     cmap_xref
            where    
    ];
    $sql_str .= $object_id
      ? " object_id=? "
      : " object_id is not null ";
    $sql_str .= qq[
            and      table_name=?
            order by $order_by
    ];
    if ($object_id) {
        $return_object = $db->selectall_arrayref(
            $sql_str,
            { Columns => {} },
            ( $object_id, $table_name )
        );
    }
    else {
        $return_object =
          $db->selectall_arrayref( $sql_str, { Columns => {} }, ($table_name) );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_generic_xrefs {    #YYY

=pod

=head2 get_generic_xrefs

=head3 Description

Retrieves the attributes attached to all generic objects.  That means
attributes attached to all features and all maps, etc.

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=back

=head3 Output

Array of Hashes:

  Keys:
    table_name,
    display_order,
    xref_name,
    xref_url

=head3 Cache Level (If Used): 4

Not using cache because this query is quicker.

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or return;
    my $db = $cmap_object->db;
    my $return_object;

    $return_object = $db->selectall_arrayref(
        q[
            select table_name,
                   display_order,
                   xref_name,
                   xref_url
            from   cmap_xref
            where  object_id is null
            or     object_id=0
        ],
        { Columns => {} }
    );

    return $return_object;
}

#-----------------------------------------------
sub get_correspondence_by_accession {    #YYY 2

=pod

=head2 get_correspondence_by_accession

=head3 Description

Get the correspondence information based on the accession id.

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=item * Correspondence Accession (correspondence_aid)

=back

=head3 Output

Hash:

  Keys:
    feature_correspondence_id,
    accession_id,
    feature_id1,
    feature_id2,
    is_enabled

=head3 Cache Level (If Used): 4

Not using cache because this query is quicker.

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or return;
    my $correspondence_aid = $args{'correspondence_aid'}
      or return $self->error('No correspondence accession ID');
    my $db = $cmap_object->db;
    my $return_object;

    my $sql_str = q[
      select feature_correspondence_id,
             accession_id,
             feature_id1,
             feature_id2,
             is_enabled
      from   cmap_feature_correspondence
      where  accession_id=?
    ];

    $return_object = $db->selectrow_hashref( $sql_str, {}, $correspondence_aid )
      or return $self->error(
        "No record for correspondence accession ID '$correspondence_aid'");

    return $return_object;
}

#-----------------------------------------------
sub get_correspondences {    #YYY

=pod

=head2 get_correspondences

Gets corr

=head3 Description

Given a map and a set of reference maps, this will return the correspondences between the two.

=head3 Caveats

If no evidence types are supplied in
included_evidence_type_aids,less_evidence_type_aids or
greater_evidence_type_aids assume that all are ignored and return empty hash.

If the $intraslot variable is set to one, compare the maps in the $ref_map_info
against each other, instead of against the map_id.

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=item * Map id of the comparative map (map_id)

=item * The "slot_info" of the reference maps (ref_map_info)

 Structure:
    {
      map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ],
    }

=item * [Comp map Start (map_start)]

=item * [Comp map stop (map_stop)]

=item * Included evidence types (included_evidence_type_aids)

=item * Ev. types that must be less than score (less_evidence_type_aids)

=item * Ev. types that must be greater than score (greater_evidence_type_aids)

=item * Scores for comparing to evidence types (evidence_type_score)

=item * [Allowed feature types (feature_type_aids)]

=item * Is intraslot? (intraslot)

Set to one to get correspondences between maps in the same slot.

=back

=head3 Output

Array of Hashes:

  Keys:
    feature_id, 
    ref_feature_id,
    feature_correspondence_id,
    evidence_type_aid,
    evidence_type,
    line_color,
    evidence_rank,


=head3 Cache Level (If Used): 

Not using cache because this query is quicker.

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or return;

    my $map_id                      = $args{'map_id'};
    my $ref_map_info                = $args{'ref_map_info'};
    my $map_start                   = $args{'map_start'};
    my $map_stop                    = $args{'map_stop'};
    my $included_evidence_type_aids = $args{'included_evidence_type_aids'}
      || [];
    my $less_evidence_type_aids    = $args{'less_evidence_type_aids'}    || [];
    my $greater_evidence_type_aids = $args{'greater_evidence_type_aids'} || [];
    my $evidence_type_score        = $args{'evidence_type_score'}        || {};
    my $feature_type_aids          = $args{'feature_type_aids'}          || [];
    my $intraslot                  = $args{'intraslot'};

    unless ( $map_id or $intraslot ) {
        return $self->error(
            "No map_id in query for specific map's correspondences\n");
    }
    my $db                 = $cmap_object->db;
    my $evidence_type_data = $cmap_object->evidence_type_data();
    my $return_object;

    my $sql_str = qq[
        select   cl.feature_id1 as feature_id,
                 f2.feature_id as ref_feature_id, 
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
    ];
    if ( !$intraslot ) {
        $sql_str .= q[
            and      f2.map_id=?
        ];
    }

    if ( defined $map_start && defined $map_stop ) {
        $sql_str .= qq[
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
        $sql_str .=
            " and (( cl.start_position2>="
          . $map_start
          . " ) or ( cl.stop_position2 is not null and "
          . " cl.stop_position2>="
          . $map_start . " ))";
    }
    elsif ( defined($map_stop) ) {
        $sql_str .= " and cl.start_position2<=" . $map_stop . " ";
    }

    if (    $ref_map_info
        and %$ref_map_info )
    {
        $sql_str .=
          " and cl.map_id1 in (" . join( ",", keys(%$ref_map_info) ) . ")";

        if ($intraslot) {
            $sql_str .=
              " and cl.map_id2 in (" . join( ",", keys(%$ref_map_info) ) . ")";

            # We don't want intramap corrs
            $sql_str .= ' and cl.map_id1 < cl.map_id2 ';
        }
    }

    if (   @$included_evidence_type_aids
        or @$less_evidence_type_aids
        or @$greater_evidence_type_aids )
    {
        $sql_str .= "and ( ";
        my @join_array;
        if (@$included_evidence_type_aids) {
            push @join_array,
              " ce.evidence_type_accession in ('"
              . join( "','", @$included_evidence_type_aids ) . "')";
        }
        foreach my $et_aid (@$less_evidence_type_aids) {
            push @join_array,
              " ( ce.evidence_type_accession = '$et_aid' "
              . " and ce.score <= "
              . $evidence_type_score->{$et_aid} . " ) ";
        }
        foreach my $et_aid (@$greater_evidence_type_aids) {
            push @join_array,
              " ( ce.evidence_type_accession = '$et_aid' "
              . " and ce.score >= "
              . $evidence_type_score->{$et_aid} . " ) ";
        }
        $sql_str .= join( ' or ', @join_array ) . " ) ";
    }
    else {
        $sql_str .= " and ce.correspondence_evidence_id = -1 ";
    }

    if (@$feature_type_aids) {
        $sql_str .=
          " and cl.feature_type_accession1 in ('"
          . join( "','", @$feature_type_aids ) . "')";
    }

    unless ( $return_object =
        $self->get_cached_results( 4, $sql_str . $map_id ) )
    {

        if ($intraslot) {
            $return_object =
              $db->selectall_arrayref( $sql_str, { Columns => {} }, () );
        }
        else {
            $return_object =
              $db->selectall_arrayref( $sql_str, { Columns => {} }, ($map_id) );
        }

        foreach my $row ( @{$return_object} ) {
            $row->{'evidence_rank'} =
              $evidence_type_data->{ $row->{'evidence_type_aid'} }{'rank'};
            $row->{'line_color'} =
              $evidence_type_data->{ $row->{'evidence_type_aid'} }
              {'line_color'};
            $row->{'evidence_type'} =
              $evidence_type_data->{ $row->{'evidence_type_aid'} }
              {'evidence_type'};
        }
        $self->store_cached_results( 4, $sql_str . $map_id, $return_object );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_feature_details {    #YYY

=pod

=head2 get_feature_details

=head3 Description

This method returns feature details.  At time of writing, this method is only used in places methods that are only executed once per page view.  It is used in places like the data_download, correspondence_detail_data and feature_search_data.  Therefor, I'm not terribly worried about the time to build the sql query (which increases with extra options).  I'm also not concerned about the extra columns that are needed by some but not all of the calling methods.

=head3 Caveats

Identifiers that are more specific are used instead of more general ids.  For instance, if a feature_id and a map_id are specified, only the feature_id will be used because the map_id is a more broad search.

The aliases_get_rows is used (initially at least) for feature search.  It appends, to the results, feature information for aliases that match the feature_name value.  If there is no feature name supplied, it will repeat the feature info for each alias the identified features have.

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=item * Identification fields

At least one of the following needs to be specified otherwise it will return
all features in the database,

 Feature ID (feature_id)
 Feature Accession (feature_aid)
 Feature Name, including '%' as wildcard (feature_name)
 Map ID (map_id)
 Map Accession (map_aid)
 Map Set ID (map_set_id)

=item * [An array of feature type accessions (feature_type_aids)]

=item * [An array of species accessions (species_aids)]

=item * [Aliases get own rows (aliases_get_rows)]

Value that dictates if aliases that match get there own rows.  This is mostly
usefull for feature_name searches.

=item * Map Start and Map Stop (map_start,map_stop)

These must both be defined in order to to be used.  If defined the method will
return only features that overlap that region.

=back

=head3 Output

Array of Hashes:

  Keys:
    feature_id,
    feature_aid,
    feature_type_aid,
    feature_name,
    start_position,
    stop_position,
    map_id,
    is_landmark,
    map_aid,
    map_name,
    map_start,
    map_stop,
    map_set_id,
    map_set_aid,
    map_set_name,
    can_be_reference_map,
    map_type_aid,
    map_units,
    species_id,
    species_aid
    species_common_name,
    feature_type,
    default_rank,
    aliases - a list of aliases,

    
=head3 Cache Level (If Used): 

Not using cache because this query is quicker.

=cut

    my ( $self, %args ) = @_;

    my $cmap_object       = $args{'cmap_object'} or return;
    my $feature_id        = $args{'feature_id'};
    my $feature_aid       = $args{'feature_aid'};
    my $feature_name      = $args{'feature_name'};
    my $map_id            = $args{'map_id'};
    my $map_aid           = $args{'map_aid'};
    my $map_set_id        = $args{'map_set_id'};
    my $map_start         = $args{'map_start'};
    my $map_stop          = $args{'map_stop'};
    my $feature_type_aids = $args{'feature_type_aids'} || [];
    my $species_aids      = $args{'species_aids'} || [];
    my $aliases_get_rows  = $args{'aliases_get_rows'} || 0;

    $aliases_get_rows = 0 if ( $feature_name eq '%' );

    my $db                = $cmap_object->db;
    my $feature_type_data = $cmap_object->feature_type_data();
    my $return_object;
    my %alias_lookup;

    my @identifiers = ();    #holds the value of the feature_id or map_id, etc
    my $select_sql  = qq[
        select  f.feature_id,
                f.accession_id as feature_aid,
                f.feature_type_accession as feature_type_aid,
                f.feature_name,
                f.start_position,
                f.stop_position,
                f.map_id,
                f.is_landmark,
                map.accession_id as map_aid,
                map.map_name,
                map.start_position as map_start,
                map.stop_position as map_stop,
                ms.map_set_id,
                ms.accession_id as map_set_aid,
                ms.short_name as map_set_name,
                ms.can_be_reference_map,
                ms.map_type_accession as map_type_aid,
                ms.map_units,
                s.species_id,
                s.accession_id as species_aid,
                s.species_common_name
    ];
    my $from_sql = qq[
        from    cmap_feature f,
                cmap_map map,
                cmap_map_set ms,
                cmap_species s
    ];
    my $alias_from_sql = $from_sql . qq[,
                cmap_feature_alias fa
    ];
    my $where_sql = qq[
        where   f.map_id=map.map_id
        and     map.map_set_id=ms.map_set_id
        and     ms.species_id=s.species_id
    ];
    my $alias_where_sql = $where_sql . qq[
        and     fa.feature_id=f.feature_id
    ];

    if ( $feature_type_aids and @$feature_type_aids ) {
        $where_sql .=
          "and f.feature_type_accession in ('"
          . join( "','", @$feature_type_aids ) . "')";
    }

    if ( $species_aids and @$species_aids ) {
        $where_sql .=
          'and s.accession_id in (' . join( "','", @$species_aids ) . "')";
    }

    # add the were clause for each possible identifier
    if ($feature_id) {
        push @identifiers, $feature_id;
        $where_sql .= " and f.feature_id = ? ";
    }
    elsif ($feature_aid) {
        push @identifiers, $feature_aid;
        $where_sql .= " and f.accession_id = ? ";
    }
    if ($map_id) {
        push @identifiers, $map_id;
        $where_sql .= " and map.map_id = ? ";
    }
    elsif ($map_aid) {
        push @identifiers, $map_aid;
        $where_sql .= " and map.accession_id = ? ";
    }
    elsif ($map_set_id) {
        push @identifiers, $map_set_id;
        $where_sql .= " and map.map_set_id = ? ";
    }

    if ($feature_name) {
        my $comparison = $feature_name =~ m/%/ ? 'like' : '=';
        if ( $feature_name ne '%' ) {
            push @identifiers, uc $feature_name;
            $where_sql       .= " and upper(f.feature_name) $comparison ? ";
            $alias_where_sql .= " and upper(fa.alias) $comparison ? ";
        }
    }

    if ( defined($map_start) and defined($map_stop) ) {
        push @identifiers, ( $map_start, $map_stop, $map_start, $map_stop );
        $where_sql .= qq[
            and      (
                ( f.start_position>=? and f.start_position<=? )
                or   (
                    f.stop_position is not null and
                    f.start_position<=? and
                    f.stop_position>=?
                )
            )
        ];
    }

    my $sql_str = $select_sql . $from_sql . $where_sql;

    if ($aliases_get_rows) {
        $sql_str .=
          " UNION " . $select_sql . $alias_from_sql . $alias_where_sql;
        push @identifiers, @identifiers;
    }

    $return_object =
      $db->selectall_arrayref( $sql_str, { Columns => {} }, @identifiers );

    if ( !$aliases_get_rows ) {
        my @feature_ids = map { $_->{'feature_id'} } @$return_object;
        my $aliases = $self->get_feature_aliases(
            cmap_object => $cmap_object,
            feature_ids => \@feature_ids,
        );
        for my $alias (@$aliases) {
            push @{ $alias_lookup{ $alias->{'feature_id'} } },
              $alias->{'alias'};
        }

    }

    foreach my $row ( @{$return_object} ) {
        $row->{'feature_type'} =
          $feature_type_data->{ $row->{'feature_type_aid'} }{'feature_type'};
        $row->{'default_rank'} =
          $feature_type_data->{ $row->{'feature_type_aid'} }{'default_rank'};

        #add Aliases
        $row->{'aliases'} = $alias_lookup{ $row->{'feature_id'} } || [];
    }
    return $return_object;
}

#-----------------------------------------------
sub get_feature_aliases {    #YYY

=pod

=head2 get_feature_aliases

=head3 Description

Gets aliases for features identified by the identification fields.  One row per
alias.

=head3 Caveats

It must check for "alias" separately since at least one call gives it both
feature_aid and alias to match.

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=item * Identification fields

At least one of the following needs to be specified otherwise it will return
all features in the database,

 Feature ID (feature_id)
 List of Feature IDs (feature_ids)
 Feature Accession (feature_aid)
 alias, including '%' as wildcard (alias)
 Map ID (map_id)
 Map Accession (map_aid)
 Map Set ID (map_set_id)

=back

=head3 Output

Array of Hashes:

  Keys:
    feature_alias_id,
    alias,
    feature_id,
    feature_aid,
    feature_name


=head3 Cache Level (If Used): 3

Not using cache because this query is quicker.

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or return;
    my $feature_id  = $args{'feature_id'};
    my $feature_ids = $args{'feature_ids'} || [];
    my $feature_aid = $args{'feature_aid'};
    my $alias       = $args{'alias'};
    my $map_id      = $args{'map_id'};
    my $map_aid     = $args{'map_aid'};
    my $map_set_id  = $args{'map_set_id'};
    my $db          = $cmap_object->db;
    my $return_object;
    my @identifiers = ();

    my $select_sql = qq[
            select  fa.feature_alias_id,
                    fa.alias,
                    f.feature_id,
                    f.accession_id as feature_aid,
                    f.feature_name
    ];
    my $from_sql = qq[
            from    cmap_feature_alias fa,
                    cmap_feature f
    ];
    my $where_sql = qq[
            where   fa.feature_id=f.feature_id
    ];

    # add the were clause for each possible identifier
    if (@$feature_ids) {
        $where_sql .=
          " and f.feature_id in (" . join( ",", @$feature_ids ) . ") ";
    }
    elsif ($feature_id) {
        push @identifiers, $feature_id;
        $where_sql .= " and f.feature_id = ? ";
    }
    elsif ($feature_aid) {
        push @identifiers, $feature_aid;
        $where_sql .= " and f.accession_id = ? ";
    }

    if ($alias) {
        my $comparison = $alias =~ m/%/ ? 'like' : '=';
        if ( $alias ne '%' ) {
            push @identifiers, uc $alias;
            $where_sql .= " and upper(fa.alias) $comparison ? ";
        }
    }

    if ($map_id) {
        push @identifiers, $map_id;
        $from_sql  .= ", cmap_map map ";
        $where_sql .= " and map.map_id = ? ";
    }
    elsif ($map_aid) {
        push @identifiers, $map_aid;
        $from_sql  .= ", cmap_map map ";
        $where_sql .= " and map.accession_id = ? ";
    }
    elsif ($map_set_id) {
        push @identifiers, $map_set_id;
        $from_sql  .= ", cmap_map map ";
        $where_sql .= " and map.map_set_id = ? ";
    }

    my $sql_str = $select_sql . $from_sql . $where_sql;
    $sql_str .= qq[
            order by alias
    ];

    $return_object =
      $db->selectall_arrayref( $sql_str, { Columns => {} }, @identifiers );

    return $return_object;
}

#-----------------------------------------------
sub slot_data_features {    #YYY

=pod

=head2 slot_data_features

=head3 Description

This is a method specifically for slot_data to call, since it will be called multiple times in most map views.  It does only what slot_data needs it to do and nothing more.  

It takes into account the corr_only_feature_types, returning only those types with displayed correspondences.  

The way it works, is that it creates one sql query for those types that will always be displayed ($included_feature_type_aids) and a separate query for those types that need a correpsondence in order to be displayed ($corr_only_feature_type_aids).  Then it unions them together.

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=item * Map ID (map_id)

=item * [Map Start (map_start)]

=item * [Map Stop (map_stop)]

=item * The "slot_info" object (slot_info)

 Structure:
    { 
      slot_no => {
        map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ],
      }
    }

=item * Slot number (this_slot_no)

=item * Included Feature Type Accessions (included_feature_type_aids)

List of feature type aids that will be displayed even if they don't have
correspondences.

=item * Ignored Feature Type Accessions (ingnored_feature_type_aids)

List of feature type aids that will not be displayed.

=item * Correspondence Only Feature Type Accessions (corr_only_feature_type_aids)

List of feature type aids that will be displayed ONLY if they have
correspondences.

=item * [show_intraslot_corr (show_intraslot_corr)]

Boolean value to check if intraslot correspondences count when deciding to
display a corr_only feature.

=back

=head3 Output

Array of Hashes:

  Keys:
    feature_id,
    accession_id,
    map_id,
    feature_name,
    is_landmark,
    start_position,
    stop_position,
    feature_type_aid,
    direction,
    map_aid,
    map_units,
    feature_type,
    default_rank,
    shape color
    drawing_lane,
    drawing_priority,
    aliases - a list of aliases,

=head3 Cache Level: 4

=cut

    my ( $self, %args ) = @_;
    my $cmap_object                 = $args{'cmap_object'} or return;
    my $map_id                      = $args{'map_id'};
    my $map_start                   = $args{'map_start'};
    my $map_stop                    = $args{'map_stop'};
    my $slot_info                   = $args{'slot_info'};
    my $this_slot_no                = $args{'this_slot_no'};
    my $included_feature_type_aids  = $args{'included_feature_type_aids'} || [];
    my $ignored_feature_type_aids   = $args{'ingnored_feature_type_aids'} || [];
    my $corr_only_feature_type_aids = $args{'corr_only_feature_type_aids'}
      || [];
    my $show_intraslot_corr = $args{'show_intraslot_corr'};

    my $db                = $cmap_object->db;
    my $feature_type_data = $cmap_object->feature_type_data();
    my $return_object;
    my $sql_str;

    my $select_sql = qq[
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
    ];
    my $from_sql = qq[
        from     cmap_feature f,
                 cmap_map map,
                 cmap_map_set ms
    ];
    my $where_sql = qq[
        where    f.map_id=$map_id
        and      f.map_id=map.map_id
        and      map.map_set_id=ms.map_set_id
    ];

    # Handle Map Start and Stop
    if ( defined($map_start) and defined($map_stop) ) {
        $where_sql .= qq[
            and (
                 ( f.start_position>=$map_start and
                   f.start_position<=$map_stop )
                 or (
                   f.stop_position is not null and
                   f.start_position<=$map_start and
                   f.stop_position>=$map_start
                 )
                )
        ];
    }
    elsif ( defined($map_start) ) {
        $where_sql .=
            " and (( f.start_position>="
          . $map_start
          . " ) or ( f.stop_position is not null and "
          . " f.stop_position>="
          . $map_start . " ))";
    }
    elsif ( defined($map_stop) ) {
        $where_sql = " and f.start_position<=" . $map_stop . " ";
    }

    # Create the query that doesn't get any of the correspondence
    # only features.
    my $corr_free_sql = $select_sql . $from_sql . $where_sql;
    if (   @$corr_only_feature_type_aids
        or @$ignored_feature_type_aids )
    {
        if (@$included_feature_type_aids) {
            $corr_free_sql .=
              " and f.feature_type_accession in ('"
              . join( "','", @$included_feature_type_aids ) . "')";
        }
        else {    #return nothing
            $corr_free_sql .= " and f.feature_type_accession = -1 ";
        }
    }

    # Create the query that gets the corr only features.
    my $with_corr_sql = '';
    if (
        (@$corr_only_feature_type_aids)
        and (  $show_intraslot_corr
            || $slot_info->{ $this_slot_no + 1 }
            || $slot_info->{ $this_slot_no - 1 } )
      )
    {
        $with_corr_sql = $select_sql . $from_sql . q[,
                  cmap_feature f2,
                  cmap_correspondence_lookup cl
                  ] . $where_sql . q[
                  and cl.feature_id1=f.feature_id
                  and cl.feature_id2=f2.feature_id
                  and cl.map_id1!=cl.map_id2
                ];
        if (   @$included_feature_type_aids
            or @$ignored_feature_type_aids )
        {
            $with_corr_sql .=
              " and f.feature_type_accession in ('"
              . join( "','", @$corr_only_feature_type_aids ) . "') ";
        }
        $with_corr_sql .= " and f2.map_id in ("
          . join(
            ",",
            (
                $slot_info->{ $this_slot_no + 1 } ?
                  keys( %{ $slot_info->{ $this_slot_no + 1 } } )
                : ()
            ),
            (
                $slot_info->{ $this_slot_no - 1 } ?
                  keys( %{ $slot_info->{ $this_slot_no - 1 } } )
                : ()
            ),
            (
                $show_intraslot_corr ? keys( %{ $slot_info->{$this_slot_no} } )
                : ()
            ),
          )
          . ")";
    }

    #
    # Decide what sql will be used
    #
    if ( @$corr_only_feature_type_aids and @$included_feature_type_aids ) {
        $sql_str = $corr_free_sql;

        # If $with_corr_sql is blank, that likely means that there
        # are no slots to have corrs with.
        $sql_str .= " UNION " . $with_corr_sql if ($with_corr_sql);
    }
    elsif (@$corr_only_feature_type_aids) {
        if ($with_corr_sql) {
            $sql_str = $with_corr_sql;
        }
        else {
            ###Return nothing because there are no maps to correspond with
            return {};
        }
    }
    elsif (@$included_feature_type_aids) {
        $sql_str = $corr_free_sql;
    }
    else {
        ###Return nothing because all features are ignored
        return {};
    }

    unless ( $return_object = $self->get_cached_results( 4, $sql_str ) ) {

        # Get feature aliases
        my %aliases = ();

        $return_object =
          $db->selectall_hashref( $sql_str, 'feature_id', {}, () );
        return {} unless $return_object;

        my @feature_ids = keys(%$return_object);
        if (@feature_ids) {
            my $aliases_array = $self->get_feature_aliases(
                cmap_object => $cmap_object,
                feature_ids => \@feature_ids,
            );

            for my $alias (@$aliases_array) {
                push @{ $aliases{ $alias->{'feature_id'} } }, $alias->{'alias'};
            }
        }

        for my $feature_id ( keys %{$return_object} ) {
            my $ft =
              $feature_type_data->{ $return_object->{$feature_id}
                  {'feature_type_aid'} };

            $return_object->{$feature_id}{$_} = $ft->{$_} for qw[
              feature_type default_rank shape color
              drawing_lane drawing_priority
            ];

            $return_object->{$feature_id}{'aliases'} = $aliases{$feature_id};
        }

        $self->store_cached_results( 4, $sql_str, $return_object );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_species {    #YYY

=pod

=head2 get_species

=head3 Description

Gets species information

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=item *

=back

=head3 Output

Array of Hashes:

  Keys:

=head3 Cache Level (If Used): 

Not using cache because this query is quicker.

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or return;
    my $species_aids      = $args{'species_aids'} || [];
    my $is_relational_map = $args{'is_relational_map'};
    my $is_enabled        = $args{'is_enabled'};
    my $db                = $cmap_object->db;
    my $return_object;
    my @identifiers  = ();
    my $join_map_set = ( defined($is_relational_map) or defined($is_enabled) );

    my $select_sql    = "select ";
    my $distinct_sql  = '';
    my $select_values = q[
                 s.species_id,
                 s.accession_id as species_aid,
                 s.species_common_name,
                 s.species_full_name,
                 s.display_order
    ];
    my $from_sql = q[
        from     cmap_species s
    ];
    my $where_sql = '';
    my $order_sql = q[
        order by s.display_order,
                 species_common_name
    ];

    if (@$species_aids) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .=
          ' s.accession_id in (' . join( "', '", @$species_aids ) . ') ';
    }

    if ($join_map_set) {

        # cmap_map_set needs to be joined
        $distinct_sql = ' distinct ';
        $from_sql  .= ", cmap_map_set ms ";
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " s.species_id=ms.species_id ";

        if ( defined($is_relational_map) ) {
            $where_sql .= " and ms.is_relational_map = $is_relational_map";
        }
        if ( defined($is_enabled) ) {
            $where_sql .= " and ms.is_enabled = $is_enabled";
        }
    }

    my $sql_str =
      $select_sql . $distinct_sql . $select_values . $from_sql . $where_sql . $order_sql;

    $return_object =
      $db->selectall_arrayref( $sql_str, { Columns => {} }, @identifiers );

    return $return_object;
}

#-----------------------------------------------
sub stub {    #YYY

=pod

=head2 stub

=head3 Description

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=item *

=back

=head3 Output

Array of Hashes:

  Keys:

=head3 Cache Level (If Used): 

Not using cache because this query is quicker.

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or return;
    my $db = $cmap_object->db;
    my $return_object;

    return $return_object;
}

1;

# ----------------------------------------------------
# He who desires but acts not, breeds pestilence.
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

