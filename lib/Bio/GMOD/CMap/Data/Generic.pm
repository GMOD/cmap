package Bio::GMOD::CMap::Data::Generic;

# vim: set ft=perl:

# $Id: Generic.pm,v 1.66 2005-04-22 21:21:31 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.66 $)[-1];

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
    $self->{'ID_FIELDS'}  = { 
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
sub cmap_data_features_sql { #NOTCHANGED 70

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
sub date_format { #NOTCHANGED

=pod

=head2 date_format

The strftime string for date format.

=cut

    my $self = shift;
    return '%Y-%m-%d';
}

# ----------------------------------------------------
sub feature_correspondence_sql { #NOTCHANGED 67 71

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
                 s.common_name as species_name,
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

    my $included_evidence_type_aids = $args{'included_evidence_type_aids'} || [];
    my $less_evidence_type_aids     = $args{'less_evidence_type_aids'}     || [];
    my $greater_evidence_type_aids  = $args{'greater_evidence_type_aids'}  || [];
    my $evidence_type_score         = $args{'evidence_type_score'}         || {};
    my $disregard_evidence_type     = $args{'disregard_evidence_type'}     || 0;

    if ( !$disregard_evidence_type 
        and (@$included_evidence_type_aids or @$less_evidence_type_aids
            or @$greater_evidence_type_aids) ) {
        $sql .= "and ( ";
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
        $sql .= join (' or ', @join_array). " ) ";
    }
    elsif( !$disregard_evidence_type ) {
        $sql .= " and ce.evidence_type_accession = '-1' ";
    }

    $sql .= q[
            order by species_display_order, species_name, 
            ms_display_order, map_set_name, map_display_order,
            map_name, start_position, feature_name
    ];

    return $sql;
}

# ----------------------------------------------------
sub feature_detail_data_sql { #NOTCHANGED 66

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
                   s.common_name as species_name,
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

    my ($self,%args)    = @_;
    my $ref_species_aid = $args{'ref_species_aid'} || 0;
    my $cmap_object     = $args{'cmap_object'} or return;
    my $db              = $args{'db'} or return;
    my $return_object;
    my $map_type_data   = $self->map_type_data();

    my $sql_str             = q[
        select   ms.accession_id, 
                 ms.map_set_id,
                 ms.short_name as map_set_name,
                 ms.display_order as map_set_display_order,
                 ms.published_on,
                 s.common_name as species_name,
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
                 species_name,
                 ms.published_on desc,
                 ms.map_set_name
    ];

    unless ( $return_object = $cmap_object->get_cached_results( 1, $sql_str ) ) {
        $return_object =
          $db->selectall_arrayref( $sql_str, { Columns => {} }, );
                                                                                                                             
        foreach my $row (@$return_object) {
            $row->{'map_type'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'map_type'};
            $row->{'map_type_display_order'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'display_order'};
            $row->{'epoch_published_on'} =
              parsedate( $row->{'published_on'} );
        }
                                                                                                                             
        $return_object = sort_selectall_arrayref(
            $return_object,             '#map_type_display_order',
            'map_type',                '#species_display_order',
            'species_name',            '#map_set_display_order',
            'epoch_published_on desc', 'map_set_name',
        );
                                                                                                                             
        $cmap_object->store_cached_results( 1, $sql_str, $return_object );
    }

    return $return_object;
}

# ----------------------------------------------------
sub form_data_map_sets_sql { #NOTCHANGED 72

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
                 s.common_name as species_name,
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
                 species_name,
                 ms.published_on desc,
                 ms.map_set_name
    ];

    return $sql;
}

# ----------------------------------------------------
sub form_data_ref_maps_sql { #NOTCHANGED 65

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
sub map_stop_sql { #NOTCHANGED 68

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
sub map_start_sql { #NOTCHANGED 69

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
sub acc_id_to_internal_id { #YYY 1 58

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
print STDERR "acc_id_to_internal_id\n";
print STDERR Dumper(\%args)."\n";
    my $cmap_object = $args{'cmap_object'} or return;
    my $object_name = $args{'object_name'}       or $self->error('No object name');
    my $acc_id      = $args{'acc_id'}      or $self->error('No accession id');
    my $table_name = $self->{'TABLE_NAMES'}->{$object_name};
    my $id_field  = $self->{'ID_FIELDS'}->{$table_name};
    my $aid_field = 'accession_id';

print STDERR "$object_name $acc_id $table_name $id_field\n";
    my $db = $cmap_object->db;
    my $return_object;

    my $sql_str = qq[
            select $id_field
            from   $table_name
            where  $aid_field=?
      ];
    $return_object = $db->selectrow_array( $sql_str, {}, ($acc_id) )
      or $self->error(
        qq[Unable to find internal id for acc. id "$acc_id" in table "$table_name"]);

print STDERR Dumper($return_object)."\n";
    return $return_object;
}

#-----------------------------------------------
sub get_attributes { #YYY 

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

    my ($self,%args)    = @_;
    my $cmap_object     = $args{'cmap_object'} or return;
    my $object_name          = $args{'object_name'} or return;
    my $object_id       = $args{'object_id'};
    my $order_by        = $args{'order_by'};
    my $db              = $cmap_object->db;
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
    $sql_str .= $object_id ?
        " object_id=? " :
        " object_id is not null ";
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
sub get_xrefs { #YYY 

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

    my ($self,%args)    = @_;
    my $cmap_object     = $args{'cmap_object'} or return;
    my $object_name          = $args{'object_name'} or return;
    my $object_id       = $args{'object_id'};
    my $order_by        = $args{'order_by'};
    my $db              = $cmap_object->db;
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
    $sql_str .= $object_id ?
        " object_id=? " :
        " object_id is not null ";
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
sub get_generic_xrefs { #YYY 

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

    my ($self,%args)    = @_;
    my $cmap_object     = $args{'cmap_object'} or return;
    my $db              = $cmap_object->db;
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
sub get_correspondence_by_accession { #YYY 2

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

    $return_object =
      $db->selectrow_hashref( $sql_str, {}, $correspondence_aid )
      or return $self->error(
        "No record for correspondence accession ID '$correspondence_aid'");

    return $return_object;
}

#-----------------------------------------------
sub get_correspondences { #YYY 

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

    my ($self,%args)    = @_;
    my $cmap_object     = $args{'cmap_object'} or return;

    my $map_id          = $args{'map_id'};
    my $ref_map_info     = $args{'ref_map_info'};
    my $map_start       = $args{'map_start'};
    my $map_stop        = $args{'map_stop'};
    my $included_evidence_type_aids = $args{'included_evidence_type_aids'} || [];
    my $less_evidence_type_aids     = $args{'less_evidence_type_aids'} || [];
    my $greater_evidence_type_aids  = $args{'greater_evidence_type_aids'} || [];
    my $evidence_type_score         = $args{'evidence_type_score'} || {};
    my $feature_type_aids           = $args{'feature_type_aids'} || [];
    my $intraslot       = $args{'intraslot'};

    unless ($map_id or $intraslot){
        return $self->error("No map_id in query for specific map's correspondences\n");
    }
    my $db              = $cmap_object->db;
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
    if (!$intraslot){
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


    if ( $ref_map_info
        and %$ref_map_info )
    {
        $sql_str .=
          " and cl.map_id1 in ("
          . join( ",", keys(%$ref_map_info) ) . ")";

        if ($intraslot){
            $sql_str .=
              " and cl.map_id2 in ("
              . join( ",", keys(%$ref_map_info) ) . ")";
            # We don't want intramap corrs
            $sql_str .= ' and cl.map_id1 < cl.map_id2 ';
        }
    }

    if ( @$included_evidence_type_aids or @$less_evidence_type_aids
            or @$greater_evidence_type_aids ) {
        $sql_str .= "and ( ";
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
        $sql_str .= join (' or ', @join_array). " ) ";
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

        if ($intraslot){
            $return_object =
              $db->selectall_arrayref( $sql_str, { Columns => {} }, () );
        }
        else{
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
        $self->store_cached_results( 4, $sql_str . $map_id,
            $return_object );
    }

    return $return_object;
}

#-----------------------------------------------
sub stub { #YYY 

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

    my ($self,%args)    = @_;
    my $cmap_object     = $args{'cmap_object'} or return;
    my $db              = $cmap_object->db;
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

