package Bio::GMOD::CMap::Data::Generic;

# vim: set ft=perl:

# $Id: Generic.pm,v 1.75 2005-05-05 20:10:07 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.75 $)[-1];

use Data::Dumper;    # really just for debugging
use Time::ParseDate;
use Regexp::Common;
use Bio::GMOD::CMap::Utils;
use Bio::GMOD::CMap::Constants;
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
sub date_format {    #NOTCHANGED

=pod

=head2 date_format

The strftime string for date format.

=cut

    my $self = shift;
    return '%Y-%m-%d';
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
sub internal_id_to_acc_id {    #YYY 1 58

=pod

=head2 internal_id_to_acc_id

=head3 Description

Return the accession id that corresponds to the internal id

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
    my $id          = $args{'id'}          or $self->error('No id');
    my $table_name = $self->{'TABLE_NAMES'}->{$object_name};
    my $id_field   = $self->{'ID_FIELDS'}->{$table_name};
    my $aid_field  = 'accession_id';

    my $db = $cmap_object->db;
    my $return_object;

    my $sql_str = qq[
            select $aid_field as ] . $object_name . qq[_aid 
            from   $table_name
            where  $id_field=?
      ];
    $return_object = $db->selectrow_array( $sql_str, {}, ($id) )
      or $self->error(
        qq[Unable to find accession id for id "$id" in table "$table_name"] );

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

=item * [ Get All Flag (get_all) ]

Boolean value.  If set to 1, return all without regard to whether object_id is
null.  Specifying an object_id overrides this.

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
    my $get_all = $args{'get_all'} || 0;
    my $db = $cmap_object->db;
    my $return_object;
    my @identifiers = ();

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
        where    table_name = ?
    ];
    push @identifiers, $table_name;

    if ($object_id) {
        push @identifiers, $object_id;
        $sql_str .= " and object_id=? ";
    }
    elsif ( !$get_all ) {
        $sql_str .= " object_id is not null ";
    }

    $sql_str .= qq[
            order by $order_by
    ];
    $return_object =
      $db->selectall_arrayref( $sql_str, { Columns => {} }, @identifiers );

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
sub get_correspondences {    #YYY 2

=pod

=head2 get_correspondences

=head3 Description

Get the correspondence information based on the accession id.

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=item * Correspondence ID (feature_correspondence_id)

=item * Correspondence Accession (feature_correspondence_aid)

=back

=head3 Output

Hash:

  Keys:
    feature_correspondence_id,
    feature_correspondence_aid,
    feature_id1,
    feature_id2,
    is_enabled

=head3 Cache Level (If Used): 4

Not using cache because this query is quicker.

=cut

    my ( $self, %args ) = @_;
    my $cmap_object                = $args{'cmap_object'} or return;
    my $feature_correspondence_id  = $args{'feature_correspondence_id'};
    my $feature_correspondence_aid = $args{'feature_correspondence_aid'};
    my $db                         = $cmap_object->db;
    my $return_object;
    my @identifiers = ();

    my $sql_str = q[
      select feature_correspondence_id,
             accession_id as feature_correspondence_aid,
             feature_id1,
             feature_id2,
             is_enabled
      from   cmap_feature_correspondence
      where 
    ];

    if ($feature_correspondence_id) {
        push @identifiers, $feature_correspondence_id;
        $sql_str .= " feature_correspondence_id = ? ";
    }
    elsif ($feature_correspondence_aid) {
        push @identifiers, $feature_correspondence_aid;
        $sql_str .= " accession_id = ? ";
    }
    else {
        return {};
    }

    $return_object = $db->selectrow_hashref( $sql_str, {}, @identifiers )
      or return $self->error("No record for correspondence ");

    return $return_object;
}

#-----------------------------------------------
sub get_correspondences_by_maps {    #YYY

=pod

=head2 get_correspondences_by_maps

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
          " and cl.map_id1 in (" . join( ",", sort keys(%$ref_map_info) ) . ")";

        if ($intraslot) {
            $sql_str .=
              " and cl.map_id2 in ("
              . join( ",", sort keys(%$ref_map_info) ) . ")";

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
              . join( "','", sort @$included_evidence_type_aids ) . "')";
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
          . join( "','", sort @$feature_type_aids ) . "')";
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
              $evidence_type_data->{ $row->{'evidence_type_aid'} }{'line_color'}
              || DEFAULT->{'connecting_line_color'};
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
    map_set_short_name,
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
                ms.map_set_name,
                ms.map_set_short_name,
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
    my $where_sql = qq[
        where   f.map_id=map.map_id
        and     map.map_set_id=ms.map_set_id
        and     ms.species_id=s.species_id
    ];

    if ( $feature_type_aids and @$feature_type_aids ) {
        $where_sql .=
          "and f.feature_type_accession in ('"
          . join( "','", sort @$feature_type_aids ) . "')";
    }

    if ( $species_aids and @$species_aids ) {
        $where_sql .=
          "and s.accession_id in ('"
          . join( "','", sort @$species_aids ) . "')";
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

    # I'm defining the alias sql so late so they can have a true copy
    # of the main sql.
    my $alias_from_sql = $from_sql . qq[,
                cmap_feature_alias fa
    ];
    my $alias_where_sql = $where_sql . qq[
        and     fa.feature_id=f.feature_id
    ];
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
          " and f.feature_id in (" . join( ",", sort @$feature_ids ) . ") ";
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
    feature_aid,
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
                 f.accession_id as feature_aid,
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
        $where_sql .= " and f.start_position<=" . $map_stop . " ";
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
              . join( "','", sort @$included_feature_type_aids ) . "')";
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
              . join( "','", sort @$corr_only_feature_type_aids ) . "') ";
        }
        $with_corr_sql .= " and f2.map_id in ("
          . join(
            ",",
            (
                $slot_info->{ $this_slot_no + 1 } ? sort
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

=item * is_relational_map (is_relational_map) 

Set to 1 or 0 to select based on the is_relational_map column.  Leave undefined
to ignore that column.

=item * is_enabled (is_enabled) 

Set to 1 or 0 to select based on the is_enabled column.  Leave undefined to
ignore that column.

=back

=head3 Output

Array of Hashes:

  Keys:

=head3 Cache Level (If Used): 

Not using cache because this query is quicker.

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or return;
    my $species_id      = $args{'species_id'} ;
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

    if ($species_id) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " s.species_id = $species_id "; 
    }
    elsif (@$species_aids) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .=
          " s.accession_id in ('" . join( "', '", sort @$species_aids ) . "') ";
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

    my $sql_str = $select_sql
      . $distinct_sql
      . $select_values
      . $from_sql
      . $where_sql
      . $order_sql;

    $return_object =
      $db->selectall_arrayref( $sql_str, { Columns => {} }, @identifiers );

    return $return_object;
}

#-----------------------------------------------
sub get_maps {    #YYY

=pod

=head2 get_maps

=head3 Description

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=item * Identification fields

At least one of the following needs to be specified otherwise it will return
all maps in the database,

 Map ID (map_id)
 List of Map IDs (map_ids)
 Map Set Accession (map_set_aid)
 List of Map Set Accessions (map_set_aids)
 Map Name (map_name) 
 Map Type Accession (map_type_aid) 
 Species Accession (species_aid) 

=item * is_relational_map (is_relational_map) 

Set to 1 or 0 to select based on the is_relational_map column.  Leave undefined
to ignore that column.

=item * is_enabled (is_enabled) 

Set to 1 or 0 to select based on the is_enabled column.  Leave undefined to
ignore that column.

=back

=head3 Output

Array of Hashes:

  Keys:
    map_id,
    map_aid,
    map_name,
    start_position,
    stop_position,
    display_order,
    map_set_id,
    map_set_aid,
    map_set_name,
    map_set_short_name,
    ms.published_on,
    shape,
    width,
    color,
    map_type_aid,
    map_units,
    is_relational_map,
    species_id,
    species_aid,
    species_common_name,
    map_type_display_order,
    map_type,
    epoch_published_on,


=head3 Cache Level: 2

=cut

    my ( $self, %args ) = @_;
    my $cmap_object       = $args{'cmap_object'} or return;
    my $map_id            = $args{'map_id'};
    my $map_ids           = $args{'map_ids'} || [];
    my $map_set_aid       = $args{'map_set_aid'};
    my $map_set_aids      = $args{'map_set_aids'} || [];
    my $map_name          = $args{'map_name'};
    my $map_type_aid      = $args{'map_type_aid'};
    my $species_aid       = $args{'species_aid'};
    my $is_relational_map = $args{'is_relational_map'};
    my $is_enabled        = $args{'is_enabled'};
    my $db                = $cmap_object->db;
    my $map_type_data     = $cmap_object->map_type_data();
    my $return_object;

    my $sql_str = q[
        select  map.map_id,
                map.accession_id as map_aid,
                map.map_name,
                map.start_position,
                map.stop_position,
                map.display_order,
                ms.map_set_id,
                ms.accession_id as map_set_aid,
                ms.map_set_name,
                ms.map_set_short_name,
                ms.published_on,
                ms.shape,
                ms.width,
                ms.color,
                ms.map_type_accession as map_type_aid,
                ms.map_units,
                ms.is_relational_map,
                s.species_id,
                s.accession_id as species_aid,
                s.species_common_name
        from    cmap_map map,
                cmap_map_set ms,
                cmap_species s
        where   map.map_set_id=ms.map_set_id
        and     ms.species_id=s.species_id
    ];

    if ($map_id) {
        $sql_str .= " and map.map_id = $map_id ";
    }
    elsif (@$map_ids) {
        $sql_str .= " and map.map_id in (" . join( ',', sort @$map_ids ) . ") ";
    }
    if ($map_name) {
        $sql_str .= " and map.map_name='$map_name' ";
    }

    if ($map_set_aid) {
        $sql_str .= " and ms.accession_id = '$map_set_aid' ";
    }
    elsif (@$map_set_aids) {
        $sql_str .=
          " and ms.accession_id in ('"
          . join( "','", sort @$map_set_aids ) . "') ";
    }

    if ($species_aid) {
        $sql_str .= qq[ and s.accession_id='$species_aid' ];
    }
    if ($map_type_aid) {
        $sql_str .= qq[ and ms.map_type_accession='$map_type_aid' ];
    }
    if ( defined($is_relational_map) ) {
        $sql_str .= " and ms.is_relational_map = $is_relational_map";
    }
    if ( defined($is_enabled) ) {
        $sql_str .= " and ms.is_enabled = $is_enabled";
    }

    $sql_str .= ' order by map.display_order, map.map_name ';

    unless ( $return_object = $cmap_object->get_cached_results( 2, $sql_str ) )
    {
        $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );

        foreach my $row ( @{$return_object} ) {
            $row->{'map_type'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'map_type'};
            $row->{'map_type_display_order'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'display_order'};
            $row->{'epoch_published_on'} = parsedate( $row->{'published_on'} );
            $row->{'default_shape'}      =
              $map_type_data->{ $row->{'map_type_aid'} }{'shape'};
            $row->{'default_color'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'color'};
            $row->{'default_width'} =
              $map_type_data->{ $row->{'map_type_aid'} }{'width'};
        }

        $cmap_object->store_cached_results( 2, $sql_str, $return_object );
    }
    return $return_object;
}

#-----------------------------------------------
sub get_used_feature_types {    #YYY

=pod

=head2 get_used_feature_types

=head3 Description

Get feature type info for features in the db

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=item * List of Map IDs (map_ids)

=item * List of feature types to check (included_feature_type_aids)

=back

=head3 Output

Array of Hashes:

  Keys:
    feature_type_aid,
    feature_type,
    shape,
    color

=head3 Cache Level (If Used): 3

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or return;
    my $map_ids                    = $args{'map_ids'}                    || [];
    my $included_feature_type_aids = $args{'included_feature_type_aids'} || [];
    my $db                         = $cmap_object->db;
    my $feature_type_data          = $cmap_object->feature_type_data();
    my $return_object;

    my $sql_str = qq[
        select   distinct
                 f.feature_type_accession as feature_type_aid
        from     cmap_feature f
    ];
    my $where_sql = '';

    if (@$map_ids) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " f.map_id in ('" . join( "','", sort @$map_ids ) . "')";
    }
    if (@$included_feature_type_aids) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .=
          " f.feature_type_accession in ('"
          . join( "','", sort @$included_feature_type_aids ) . "') ";
    }

    $sql_str .= $where_sql;

    unless ( $return_object = $self->get_cached_results( 3, $sql_str ) ) {
        $return_object =
          $db->selectall_arrayref( $sql_str, { Columns => {} }, () );
        foreach my $row (@$return_object) {
            $row->{'feature_type'} =
              $feature_type_data->{ $row->{'feature_type_aid'} }
              {'feature_type'};
            $row->{'shape'} =
              $feature_type_data->{ $row->{'feature_type_aid'} }{'shape'};
            $row->{'color'} =
              $feature_type_data->{ $row->{'feature_type_aid'} }{'color'};
        }
        $self->store_cached_results( 3, $sql_str, $return_object );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_used_map_types {    #YYY

=pod

=head2 get_used_map_types

=head3 Description

Get map type info for maps in the db

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=item * Map Set Id (map_set_id)

=item * is_relational_map (is_relational_map) 

Set to 1 or 0 to select based on the is_relational_map column.  Leave undefined
to ignore that column.

=item * is_enabled (is_enabled) 

Set to 1 or 0 to select based on the is_enabled column.  Leave undefined to
ignore that column.

=back

=head3 Output

Array of Hashes:

  Keys:

=head3 Cache Level (If Used): 3

=cut

    my ( $self, %args ) = @_;
    my $cmap_object       = $args{'cmap_object'} or return;
    my $is_relational_map = $args{'is_relational_map'};
    my $is_enabled        = $args{'is_enabled'};
    my $db                = $cmap_object->db;
    my $map_type_data     = $cmap_object->map_type_data();
    my $return_object;

    my $sql_str = qq[
        select   distinct
                 ms.map_type_accession as map_type_aid
        from     cmap_map_set ms
    ];
    my $where_sql = '';
    if ( defined($is_relational_map) ) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " ms.is_relational_map = $is_relational_map ";
    }
    if ( defined($is_enabled) ) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " ms.is_enabled = $is_enabled ";
    }

    $sql_str .= $where_sql;

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} }, () );
    foreach my $row (@$return_object) {
        $row->{'map_type'} =
          $map_type_data->{ $row->{'map_type_aid'} }{'map_type'};
        $row->{'display_order'} =
          $map_type_data->{ $row->{'map_type_aid'} }{'display_order'};
    }

    return $return_object;
}

#-----------------------------------------------
sub get_map_sets {    #YYY

=pod

=head2 get_map_sets

=head3 Description

Get information on map sets including species info.

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=item * Identification fields

At least one of the following needs to be specified otherwise it will return
all features in the database,

 Map Set Accession (map_set_aid)
 List of Map Set Accessions (map_set_aids)
 Species ID (species_id)
 Species Accession (species_aid)
 Map Type Accession (map_type_aid)
 

=item * is_relational_map (is_relational_map) 

Set to 1 or 0 to select based on the is_relational_map column.  Leave undefined
to ignore that column.

=item * can_be_reference_map (can_be_reference_map) 

Set to 1 or 0 to select based on the can_be_reference_map column.  Leave
undefined to ignore that column.

=item * is_enabled (is_enabled) 

Set to 1 or 0 to select based on the is_enabled column.  Leave undefined to
ignore that column.

=back

=head3 Output

Array of Hashes:

  Keys:
    map_set_id,
    map_set_aid,
    map_set_name,
    map_set_short_name,
    map_type_aid,
    published_on,
    can_be_reference_map,
    is_enabled,
    is_relational_map,
    map_units,
    map_set_display_order,
    species_id,
    species_aid,
    species_common_name,
    species_full_name,
    species_display_order,
    map_type,
    map_type_display_order,
    epoch_published_on,

=head3 Cache Level (If Used): 1

=cut

    my ( $self, %args ) = @_;
    my $cmap_object          = $args{'cmap_object'} or return;
    my $species_id           = $args{'species_id'};
    my $species_aid          = $args{'species_aid'};
    my $map_set_aid          = $args{'map_set_aid'};
    my $map_set_aids         = $args{'map_set_aids'} || [];
    my $map_type_aid         = $args{'map_type_aid'};
    my $is_relational_map    = $args{'is_relational_map'};
    my $can_be_reference_map = $args{'can_be_reference_map'};
    my $is_enabled           = $args{'is_enabled'};
    my $db                   = $cmap_object->db;
    my $map_type_data        = $cmap_object->map_type_data();
    my $return_object;

    my $sql_str = q[
        select  ms.map_set_id,
                ms.accession_id as map_set_aid,
                ms.map_set_name,
                ms.map_set_short_name,
                ms.map_type_accession as map_type_aid,
                ms.published_on,
                ms.can_be_reference_map,
                ms.is_enabled,
                ms.is_relational_map,
                ms.map_units,
                ms.display_order as map_set_display_order,
                s.species_id,
                s.accession_id as species_aid,
                s.species_common_name,
                s.species_full_name,
                s.display_order as species_display_order
        from    cmap_map_set ms,
                cmap_species s
        where   ms.species_id=s.species_id
    ];

    if ($map_set_aid) {
        $sql_str .= " and ms.accession_id = '$map_set_aid' ";
    }
    elsif (@$map_set_aids) {
        $sql_str .=
          " and ms.accession_id in ('"
          . join( "','", sort @$map_set_aids ) . "') ";
    }
    if ($species_id) {
        $sql_str .= " and s.species_id= '$species_id' ";
    }
    elsif ( $species_aid and $species_aid ne '-1' ) {
        $sql_str .= " and s.accession_id= '$species_aid' ";
    }
    if ($map_type_aid) {
        $sql_str .= " and ms.map_type_accession = '$map_type_aid' ";
    }
    if ( defined($is_relational_map) ) {
        $sql_str .= " and ms.is_relational_map = $is_relational_map ";
    }
    if ( defined($can_be_reference_map) ) {
        $sql_str .= " and ms.can_be_reference_map = $can_be_reference_map ";
    }
    if ( defined($is_enabled) ) {
        $sql_str .= " and ms.is_enabled = $is_enabled ";
    }

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
            'species_common_name',     '#map_set_display_order',
            'epoch_published_on desc', 'map_set_short_name',
        );

        $cmap_object->store_cached_results( 1, $sql_str, $return_object );
    }

    return $return_object;
}

# --------------------------------------------------
sub get_just_map_sets {    #YYY

=pod

=head2 get_just_map_sets

=head3 Description

Get just the info from the map set table.  This is less data than
get_map_sets() provides and doesn't involve any table joins.

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=item * Identification fields

At least one of the following needs to be specified otherwise it will return
all features in the database,

 Map Set Accession (map_set_aid)
 List of Map Set Accessions (map_set_aids)
 Species ID (species_id)
 Species Accession (species_aid)
 Map Type Accession (map_type_aid)
 

=item * is_relational_map (is_relational_map) 

Set to 1 or 0 to select based on the is_relational_map column.  Leave undefined
to ignore that column.

=item * can_be_reference_map (can_be_reference_map) 

Set to 1 or 0 to select based on the can_be_reference_map column.  Leave
undefined to ignore that column.

=item * is_enabled (is_enabled) 

Set to 1 or 0 to select based on the is_enabled column.  Leave undefined to
ignore that column.

=back

=head3 Output

Array of Hashes:

  Keys:
    map_set_id,
    map_set_aid,
    map_set_name,
    map_set_short_name,
    map_type_aid,
    published_on,
    can_be_reference_map,
    is_enabled,
    is_relational_map,
    map_units,
    map_set_display_order,
    species_id,
    species_aid,
    species_common_name,
    species_full_name,
    species_display_order,
    map_type,
    map_type_display_order,
    epoch_published_on,

=head3 Cache Level (If Used): 

Not using cache because this query is quicker.

=cut

    my ( $self, %args ) = @_;
    my $cmap_object          = $args{'cmap_object'} or return;
    my $map_set_aid          = $args{'map_set_aid'};
    my $map_set_aids         = $args{'map_set_aids'} || [];
    my $map_type_aid         = $args{'map_type_aid'};
    my $is_relational_map    = $args{'is_relational_map'};
    my $can_be_reference_map = $args{'can_be_reference_map'};
    my $is_enabled           = $args{'is_enabled'};
    my $db                   = $cmap_object->db;
    my $map_type_data        = $cmap_object->map_type_data();
    my $return_object;

    my $sql_str = q[
        select  ms.map_set_id,
                ms.accession_id as map_set_aid,
                ms.map_set_name,
                ms.map_set_short_name,
                ms.map_type_accession as map_type_aid,
                ms.published_on,
                ms.can_be_reference_map,
                ms.is_enabled,
                ms.is_relational_map,
                ms.map_units,
                ms.display_order as map_set_display_order
        from    cmap_map_set ms
    ];
    my $where_sql = '';

    if ($map_set_aid) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " ms.accession_id = '$map_set_aid' ";
    }
    elsif (@$map_set_aids) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .=
          " ms.accession_id in ('" . join( "','", sort @$map_set_aids ) . "') ";
    }
    if ($map_type_aid) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " ms.map_type_accession = '$map_type_aid' ";
    }
    if ( defined($is_relational_map) ) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " ms.is_relational_map = $is_relational_map ";
    }
    if ( defined($can_be_reference_map) ) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " ms.can_be_reference_map = $can_be_reference_map ";
    }
    if ( defined($is_enabled) ) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " ms.is_enabled = $is_enabled ";
    }

    $sql_str .= $where_sql;

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} }, );

    foreach my $row (@$return_object) {
        $row->{'map_type'} =
          $map_type_data->{ $row->{'map_type_aid'} }{'map_type'};
        $row->{'map_type_display_order'} =
          $map_type_data->{ $row->{'map_type_aid'} }{'display_order'};
        $row->{'epoch_published_on'} = parsedate( $row->{'published_on'} );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_feature_count {    #YYY

=pod

=head2 get_feature_count

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
    my $cmap_object           = $args{'cmap_object'} or return;
    my $group_by_map_id       = $args{'group_by_map_id'};
    my $group_by_feature_type = $args{'group_by_feature_type'};
    my $this_slot_info        = $args{'this_slot_info'};
    my $map_ids               = $args{'map_ids'} || [];
    my $map_id                = $args{'map_id'};
    my $map_name              = $args{'map_name'};
    my $map_set_id            = $args{'map_set_id'};
    my $db                    = $cmap_object->db;
    my $return_object;

    my $select_sql        = " select  count(f.feature_id) as feature_count ";
    my $from_sql          = " from cmap_feature f ";
    my $where_sql         = '';
    my $group_by_sql      = '';
    my $added_map_to_from = 0;

    if ($group_by_map_id) {
        $select_sql   .= ", f.map_id ";
        $group_by_sql .= $group_by_sql ? "," : " group by ";
        $group_by_sql .= " f.map_id ";
    }
    if ($group_by_feature_type) {
        $select_sql   .= ", f.feature_type_accession as feature_type_aid ";
        $group_by_sql .= $group_by_sql ? "," : " group by ";
        $group_by_sql .= " f.feature_type_accession ";
    }

    if ($map_id) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " f.map_id = $map_id ";
    }
    elsif (@$map_ids) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " f.map_id in ('" . join( "','", sort @$map_ids ) . "')";
    }
    elsif ($this_slot_info) {

        # Use start and stop info on maps if this_slot_info is given
        my @unrestricted_map_ids = ();
        my $unrestricted_sql     = '';
        my $restricted_sql       = '';
        foreach my $slot_map_id ( sort keys( %{$this_slot_info} ) ) {

            # $this_slot_info->{$slot_map_id}->[0] is start [1] is stop
            if (    defined( $this_slot_info->{$slot_map_id}->[0] )
                and defined( $this_slot_info->{$slot_map_id}->[1] ) )
            {
                $restricted_sql .=
                    " or (f.map_id="
                  . $slot_map_id
                  . " and (( f.start_position>="
                  . $this_slot_info->{$slot_map_id}->[0]
                  . " and f.start_position<="
                  . $this_slot_info->{$slot_map_id}->[1]
                  . " ) or ( f.stop_position is not null and "
                  . "  f.start_position<="
                  . $this_slot_info->{$slot_map_id}->[0]
                  . " and f.stop_position>="
                  . $this_slot_info->{$slot_map_id}->[0] . " )))";
            }
            elsif ( defined( $this_slot_info->{$slot_map_id}->[0] ) ) {
                $restricted_sql .=
                    " or (f.map_id="
                  . $slot_map_id
                  . " and (( f.start_position>="
                  . $this_slot_info->{$slot_map_id}->[0]
                  . " ) or ( f.stop_position is not null "
                  . " and f.stop_position>="
                  . $this_slot_info->{$slot_map_id}->[0] . " )))";
            }
            elsif ( defined( $this_slot_info->{$slot_map_id}->[1] ) ) {
                $restricted_sql .=
                    " or (f.map_id="
                  . $slot_map_id
                  . " and f.start_position<="
                  . $this_slot_info->{$slot_map_id}->[1] . ") ";
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
        unless ($combined_sql) {
            return [];
        }
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " (" . $combined_sql . ")";
    }
    elsif ($map_set_id) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= qq[
            map.map_set_id = $map_set_id
        ];
        unless ($added_map_to_from) {
            $from_sql  .= ", cmap_map map ";
            $where_sql .= qq[
                and map.map_id=f.map_id
            ];
            $added_map_to_from = 1;
        }
    }

    if ($map_name) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map.map_name='$map_name' ";
        unless ($added_map_to_from) {
            $from_sql  .= ", cmap_map map ";
            $where_sql .= qq[
                and map.map_id=f.map_id
            ];
            $added_map_to_from = 1;
        }
    }

    my $sql_str = $select_sql . $from_sql . $where_sql . $group_by_sql;

    unless ( $return_object = $self->get_cached_results( 3, $sql_str ) ) {
        $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );

        if ($group_by_feature_type) {
            my $feature_type_data = $cmap_object->feature_type_data();
            foreach my $row ( @{$return_object} ) {
                $row->{'feature_type'} =
                  $feature_type_data->{ $row->{'feature_type_aid'} }
                  {'feature_type'};
            }
        }

        $self->store_cached_results( 3, $sql_str, $return_object );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_species_aid {    #YYY

=pod

=head2 get_species_aid

=head3 Description

Given a map set get it's species accession.

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
    my $map_set_aid = $args{'map_set_aid'};
    my $db          = $cmap_object->db;
    my $return_object;
    my $select_sql = " select s.accession_id as species_aid ";
    my $from_sql   = qq[
        from   cmap_map_set ms,
               cmap_species s
    ];
    my $where_sql = qq[
        where ms.species_id=s.species_id
    ];

    if ($map_set_aid) {
        $where_sql .= " and ms.accession_id = '$map_set_aid' ";
    }
    else {
        return;
    }

    my $sql_str = $select_sql . $from_sql . $where_sql;

    $return_object = $db->selectrow_array( $sql_str, {} );

    return $return_object;
}

#-----------------------------------------------
sub get_map_type_aid {    #YYY

=pod

=head2 get_map_type_aid

=head3 Description

Given a map set get it's species accession.

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
    my $map_set_aid = $args{'map_set_aid'};
    my $db          = $cmap_object->db;
    my $return_object;
    my $select_sql = " select ms.map_type_accession as map_type_aid ";
    my $from_sql   = qq[
        from   cmap_map_set ms
    ];
    my $where_sql = '';

    if ($map_set_aid) {
        $where_sql .= " where ms.accession_id = '$map_set_aid' ";
    }
    else {
        return;
    }

    my $sql_str = $select_sql . $from_sql . $where_sql;

    $return_object = $db->selectrow_array( $sql_str, {} );

    return $return_object;
}

#-----------------------------------------------
sub get_matrix_relationships {    #YYY

=pod

=head2 get_matrix_relationships

=head3 Description

Get Matrix data from the matrix table.

This method progressively gives more data depending on the input.  If a
map_set_aid is given, it will count based on individual maps of that map_set
and the results also include those map accessions.  If a link_map_set_aid is
also given it will count based on individual maps of both map sets and the
results include both map accessions.  

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=item * Map Aet Accession (map_set_aid)

=item * Link Map Aet Accession (map_set_aid)

=item * Species Accession (species_aid)

=item * Map Name (map_name)

=back

=head3 Output

Array of Hashes:

  Keys:
    correspondences,
    map_count,
    reference_map_aid (Only if $map_set_aid is given),
    reference_map_set_aid,
    reference_species_aid,
    link_map_aid (Only if $map_set_aid and $link_map_set are given),
    link_map_set_aid,
    link_species_aid

Two of the keys are conditional to what the input is.

=head3 Cache Level (If Used): 

Not using cache because this query is quicker.

=cut

    my ( $self, %args ) = @_;
    my $cmap_object      = $args{'cmap_object'} or return;
    my $species_aid      = $args{'species_aid'};
    my $map_name         = $args{'map_name'};
    my $map_set_aid      = $args{'map_set_aid'};
    my $link_map_set_aid = $args{'link_map_set_aid'};
    my $db               = $cmap_object->db;
    my $return_object;

    my $select_sql = qq[
        select   sum(cm.no_correspondences) as correspondences,
                 count(cm.link_map_aid) as map_count,
                 cm.reference_map_set_aid,
                 cm.reference_species_aid,
                 cm.link_map_set_aid,
                 cm.link_species_aid

    ];
    my $from_sql = qq[
        from     cmap_correspondence_matrix cm
    ];
    my $where_sql = '';
    my $group_by  = qq[
        group by cm.reference_map_set_aid,
                 cm.link_map_set_aid,
                 cm.reference_species_aid,
                 cm.link_species_aid
    ];

    if ( $map_set_aid and $link_map_set_aid ) {
        $select_sql .= qq[ 
            , cm.reference_map_aid
            , cm.link_map_aid
        ];
        $from_sql  .= ", cmap_map_set ms ";
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= qq[
                cm.reference_map_set_aid='$map_set_aid'
            and cm.link_map_set_aid='$link_map_set_aid'
            and cm.reference_map_set_aid=ms.accession_id
            and ms.is_enabled=1
        ];
        $group_by .= ", cm.reference_map_aid, cm.link_map_aid ";
    }
    elsif ($map_set_aid) {
        $select_sql .= " , cm.reference_map_aid ";
        $from_sql   .= ", cmap_map_set ms ";
        $where_sql  .= $where_sql ? " and " : " where ";
        $where_sql  .= qq[
                cm.reference_map_set_aid='$map_set_aid'
            and cm.reference_map_set_aid=ms.accession_id
        ];
        $group_by .= ", cm.reference_map_aid ";
    }

    if ($species_aid) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " cm.reference_species_aid='$species_aid' ";
    }
    if ($map_name) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " cm.reference_map_name='$map_name' ";
    }
    my $sql_str = $select_sql . $from_sql . $where_sql . $group_by;

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );

    return $return_object;
}

#-----------------------------------------------
sub get_correspondence_details {    #YYY

=pod

=head2 get_correspondence_details

=head3 Description

return many details about the correspondences of a feature.

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
    my $cmap_object                 = $args{'cmap_object'} or return;
    my $feature_id1                  = $args{'feature_id1'};
    my $map_set_aid2                 = $args{'map_set_aid2'};
    my $map_aid2                     = $args{'map_aid2'};
    my $included_evidence_type_aids = $args{'included_evidence_type_aids'}
      || [];
    my $less_evidence_type_aids    = $args{'less_evidence_type_aids'}    || [];
    my $greater_evidence_type_aids = $args{'greater_evidence_type_aids'} || [];
    my $evidence_type_score        = $args{'evidence_type_score'}        || {};
    my $disregard_evidence_type    = $args{'disregard_evidence_type'}    || 0;
    my $db                         = $cmap_object->db;
    my $map_type_data              = $cmap_object->map_type_data();
    my $feature_type_data              = $cmap_object->feature_type_data();
    my $evidence_type_data              = $cmap_object->evidence_type_data();
    my $return_object;

    my $sql_str = q[
        select   f2.feature_name as feature_name2,
                 cl.feature_id2,
                 cl.feature_id2,
                 f1.accession_id as feature_aid1,
                 f2.accession_id as feature_aid2,
                 cl.start_position2,
                 cl.stop_position2,
                 f2.feature_type_accession as feature_type_aid2,
                 map2.map_id as map_id2,
                 map2.accession_id as map_aid2,
                 map2.map_name as map_name2,
                 map2.display_order as map_display_order2,
                 ms2.map_set_id as map_set_id2,
                 ms2.accession_id as map_set_aid2,
                 ms2.map_set_short_name as map_set_short_name2,
                 ms2.display_order as ms_display_order2,
                 ms2.published_on as published_on2,
                 ms2.map_type_accession as map_type_aid2,
                 ms2.map_units as map_units2,
                 s2.species_common_name as species_common_name2,
                 s2.display_order as species_display_order2,
                 fc.feature_correspondence_id,
                 fc.accession_id as feature_correspondence_aid,
                 fc.is_enabled,
                 ce.evidence_type_accession as evidence_type_aid
        from     cmap_correspondence_lookup cl, 
                 cmap_feature_correspondence fc,
                 cmap_correspondence_evidence ce,
                 cmap_feature f1,
                 cmap_feature f2,
                 cmap_map map2,
                 cmap_map_set ms2,
                 cmap_species s2
        where    cl.feature_correspondence_id=fc.feature_correspondence_id
        and      fc.feature_correspondence_id=ce.feature_correspondence_id
        and      cl.feature_id1=f1.feature_id
        and      cl.feature_id2=f2.feature_id
        and      f2.map_id=map2.map_id
        and      map2.map_set_id=ms2.map_set_id
        and      ms2.is_enabled=1
        and      ms2.species_id=s2.species_id
    ];

    if ($feature_id1){ 
        $sql_str .= " and cl.feature_id1=$feature_id1 ";
    }

    if ($map_set_aid2) {
        $sql_str .= " and ms2.accession_id='" . $map_set_aid2 . "' ";
    }
    elsif ($map_aid2) {
        $sql_str .= "and map2.accession_id='" . $map_aid2 . "' ";
    }

    if (
        !$disregard_evidence_type
        and (  @$included_evidence_type_aids
            or @$less_evidence_type_aids
            or @$greater_evidence_type_aids )
      )
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
    elsif ( !$disregard_evidence_type ) {
        $sql_str .= " and ce.evidence_type_accession = '-1' ";
    }

    $sql_str .= q[
            order by s2.display_order, s2.species_common_name, 
            ms2.display_order, ms2.map_set_short_name, map2.display_order,
            map2.map_name, f2.start_position, f2.feature_name
    ];

    $return_object =
      $db->selectall_arrayref( $sql_str, { Columns => {} } );

    foreach my $row ( @{$return_object} ) {
        $row->{'map_type2'} =
          $map_type_data->{ $row->{'map_type_aid2'} }{'map_type'};
        $row->{'feature_type2'} =
          $feature_type_data->{ $row->{'feature_type_aid2'} }
          {'feature_type'};
        $row->{'evidence_type'} =
          $evidence_type_data->{ $row->{'evidence_type_aid'} }
          {'evidence_type'};
    }
    return $return_object;
}

#-----------------------------------------------
sub get_correspondences_for_export {    #YYY

=pod

=head2 get_correspondences_for_export

=head3 Description

return export details about the correspondences 

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
    my $cmap_object                 = $args{'cmap_object'} or return;
    my $map_set_ids1                 = $args{'map_set_ids1'} || [];
    my $map_set_ids2                 = $args{'map_set_ids2'} || [];
    my $db                         = $cmap_object->db;
    my $return_object;

    my $sql_str = q[
        select fc.feature_correspondence_id as object_id,
               fc.accession_id,
               fc.is_enabled,
               f1.accession_id as feature_aid1,
               f2.accession_id as feature_aid2
        from    cmap_feature_correspondence fc,
                 cmap_feature f1,
                 cmap_feature f2,
                 cmap_map map1,
                 cmap_map map2
        where    fc.feature_id1=f1.feature_id
        and      fc.feature_id2=f2.feature_id
        and      f1.map_id=map1.map_id
        and      f2.map_id=map2.map_id
    ];

    if (@$map_set_ids1){
        $sql_str .= "and map1.map_set_id in ("
          . join(",",sort @$map_set_ids1)
          . ") ";
    }

    if (@$map_set_ids2){
        $sql_str .= "and map2.map_set_id in ("
          . join(",",sort @$map_set_ids2)
          . ") ";
    }

    $return_object =
      $db->selectall_arrayref( $sql_str, { Columns => {} } );

    return $return_object;
}

#-----------------------------------------------
sub get_maps_from_map_set {    #YYY

=pod

=head2 get_maps_from_map_set

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
    my $map_set_aid = $args{'map_set_aid'};
    my $db          = $cmap_object->db;
    my $return_object;

    my $sql_str = q[
        select   map.accession_id as map_aid,
                 map.map_id,
                 map.map_name
        from     cmap_map map,
                 cmap_map_set ms
        where    map.map_set_id=ms.map_set_id
        and      ms.accession_id=?
        order by map.display_order,
                 map.map_name
    ];

    $return_object =
      $db->selectall_arrayref( $sql_str, { Columns => {} }, ($map_set_aid) );

    return $return_object;
}

#-----------------------------------------------
sub get_slot_info {    #YYY

=pod

=head2 get_slot_info

=head3 Description

Creates and returns some map info for each slot.
                                                                                                                             
 Data Structure:
  slot_info  =  {
    slot_no  => {
      map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ]
    }
  }
                                                                                                                             
"current_start" and "current_stop" are undef if using the
original start and stop.

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
    my $slots = $args{'slots'} || {};
    my $ignored_feature_type_aids = $args{'ignored_feature_type_aids'} || [];
    my $included_evidence_type_aids = $args{'included_evidence_type_aids'}
      || [];
    my $less_evidence_type_aids    = $args{'less_evidence_type_aids'}    || [];
    my $greater_evidence_type_aids = $args{'greater_evidence_type_aids'} || [];
    my $evidence_type_score        = $args{'evidence_type_score'}        || {};
    my $min_correspondences        = $args{'min_correspondences'};
    my $db                         = $cmap_object->db;
    my $return_object              = {};

    # Return slot_info is not setting it.
    return {} unless ($slots);

    my $sql_base = q[
      select distinct m.map_id,
             m.start_position,
             m.stop_position,
             m.start_position,
             m.stop_position,
             m.accession_id as map_set_aid
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
            my $slot_info    = $return_object->{$ref_slot_id};
            next unless $slot_info;
            foreach my $m_id ( keys( %{ $return_object->{$ref_slot_id} } ) ) {
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
            if ( $ignored_feature_type_aids and @$ignored_feature_type_aids ) {
                $where .=
                  " and cl.feature_type_accession1 not in ('"
                  . join( "','", @$ignored_feature_type_aids ) . "') ";
            }

            #xx5
            if (   @$included_evidence_type_aids
                or @$less_evidence_type_aids
                or @$greater_evidence_type_aids )
            {
                $from  .= ", cmap_correspondence_evidence ce ";
                $where .=
                    " and ce.feature_correspondence_id = "
                  . "cl.feature_correspondence_id ";
                $where .= "and ( ";
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
                $where .= join( ' or ', @join_array ) . " ) ";
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
                foreach my $map_aid ( keys %{$maps} ) {
                    if (    defined( $maps->{$map_aid}{'start'} )
                        and defined( $maps->{$map_aid}{'stop'} ) )
                    {
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
                    elsif ( defined( $maps->{$map_aid}{'stop'} ) ) {
                        $aid_where .=
                            qq[ and ( not m.accession_id = '$map_aid'  ]
                          . " or cl.start_position1<="
                          . $maps->{$map_aid}{'stop'} . ") ";
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
                $having =
                    " having count(cl.feature_correspondence_id) "
                  . ">=$min_correspondences ";
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
        if ( $min_correspondences and $slot_no != 0 ) {
            $sql_str =~ s/distinct//;
        }

        #print S#TDERR "SLOT_INFO SQL \n$sql_str\n";

        my $slot_results;

        unless ( $slot_results =
            $cmap_object->get_cached_results( 4, $sql_str ) )
        {
            $slot_results = $db->selectall_arrayref( $sql_str, {}, () );
            $cmap_object->store_cached_results( 4, $sql_str, $slot_results );
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
                            cmap_object         => $cmap_object,
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
                            cmap_object         => $cmap_object,
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

            $return_object->{$slot_no}{ $row->[0] } =
              [ $row->[1], $row->[2], $row->[3], $row->[4], $magnification ];
        }
    }

    # If ever a slot has no maps, remove the slot.
    my $delete_pos = 0;
    my $delete_neg = 0;
    foreach my $slot_no ( sort orderOutFromZero keys %{$slots} ) {
        if ( scalar( keys( %{ $return_object->{$slot_no} } ) ) <= 0 ) {
            if ( $slot_no >= 0 ) {
                $delete_pos = 1;
            }
            if ( $slot_no <= 0 ) {
                $delete_neg = 1;
            }
        }
        if ( $slot_no >= 0 and $delete_pos ) {
            delete $return_object->{$slot_no};
            delete $slots->{$slot_no};
        }
        elsif ( $slot_no < 0 and $delete_neg ) {
            delete $return_object->{$slot_no};
            delete $slots->{$slot_no};
        }
    }

    return $return_object;
}

#-----------------------------------------------
sub feature_name_to_position {    #YYY

=pod

=head2 feature_name_to_position

=head3 Description

ONLY USED IN get_slot_info().

Turn a feature name into a position.

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
    my $cmap_object  = $args{'cmap_object'}  or return;
    my $feature_name = $args{'feature_name'} or return;
    my $map_id       = $args{'map_id'}       or return;
    my $start_position_only = $args{'start_position_only'};

    # REPLACE 33 YYY
    # Using get_feature_detail is a little overkill
    # but this method isn't used much and it makes for
    # simplified code.
    my $feature_array = $self->get_feature_details(
        cmap_object      => $self,
        map_id           => $map_id,
        feature_name     => $feature_name,
        aliases_get_rows => 1,
    );
    unless ( $feature_array and @$feature_array ) {
        return undef;
    }

    my $start = $feature_array->[0]{'start_position'};
    my $stop  = $feature_array->[0]{'stop_position'};

    return $start_position_only ? $start
      : defined $stop           ? $stop
      : $start;
}

#-----------------------------------------------
sub orderOutFromZero {    #YYY

=pod

=head2 orderOutFromZero

=head3 Description

Sorting method: Return the sort in this order (0,1,-1,-2,2,-3,3,)

=cut

    return ( abs($a) cmp abs($b) );
}

#-----------------------------------------------
sub get_map_search_info {    #YYY

=pod

=head2 get_map_search_info

=head3 Description

=head3 Input

=over 4

=item * Object that inherits from CMap.pm (cmap_object)

=item *

=back

=head3 Output

Array of Hashes:

  Keys:

=head3 Cache Level (If Used): 4

Not Caching because the calling method will do that.

=cut

    my ( $self, %args ) = @_;
    my $cmap_object             = $args{'cmap_object'} or return;
    my $map_set_id              = $args{'map_set_id'};
    my $map_name                = $args{'map_name'};
    my $min_correspondence_maps = $args{'min_correspondence_maps'};
    my $min_correspondences     = $args{'min_correspondences'};

    my $db = $cmap_object->db;
    my $return_object;

    my $sql_str = q[
        select  map.accession_id as map_aid,
                map.map_name,
                map.start_position,
                map.stop_position,
                map.map_id,
                map.display_order,
                count(distinct(cl.map_id2)) as cmap_count,
                count(distinct(cl.feature_correspondence_id))
                    as corr_count
        from    cmap_map map
        Left join cmap_correspondence_lookup cl
                on map.map_id=cl.map_id1
        where    map.map_set_id=?
    ];
    if ($map_name) {
        my $comparison = $map_name =~ m/%/ ? 'like' : '=';
        if ( $map_name ne '%' ) {
            $sql_str .= " and map.map_name $comparison '$map_name' ";
        }
    }
    $sql_str .= q[
        group by map.accession_id,map.map_id, map.map_name,
            map.start_position,map.stop_position,map.display_order
    ];
    if ( $min_correspondence_maps and $min_correspondences ) {
        $sql_str .=
            " having count(distinct(cl.map_id2)) >=$min_correspondence_maps "
          . " and count(distinct(cl.feature_correspondence_id)) >=$min_correspondences ";
    }
    elsif ($min_correspondence_maps) {
        $sql_str .=
          " having count(distinct(cl.map_id2)) >='$min_correspondence_maps' ";
    }
    elsif ($min_correspondences) {
        $sql_str .=
            " having count(distinct(cl.feature_correspondence_id)) "
          . " >=$min_correspondences ";
    }
    $return_object =
      $db->selectall_hashref( $sql_str, 'map_id', { Columns => {} },
        ("$map_set_id") );

    return $return_object;
}

#-----------------------------------------------
sub get_evidence {    #YYY

=pod

=head2 get_evidence

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
    my $cmap_object               = $args{'cmap_object'} or return;
    my $feature_correspondence_id = $args{'feature_correspondence_id'};
    my $db                        = $cmap_object->db;
    my $evidence_type_data        = $cmap_object->evidence_type_data();
    my $return_object;

    my $sql_str = q[
        select   ce.correspondence_evidence_id,
                 ce.accession_id as correspondence_evidence_aid,
                 ce.score,
                 ce.evidence_type_accession as evidence_type_aid
        from     cmap_correspondence_evidence ce
        where    ce.feature_correspondence_id=?
    ];
    $return_object = $db->selectall_arrayref(
        $sql_str,
        { Columns => {} },
        ($feature_correspondence_id)
    );

    foreach my $row ( @{$return_object} ) {
        $row->{'rank'} =
          $evidence_type_data->{ $row->{'evidence_type_aid'} }{'rank'};
        $row->{'evidence_type'} =
          $evidence_type_data->{ $row->{'evidence_type_aid'} }{'evidence_type'};
    }

    return $return_object;
}

#-----------------------------------------------
sub get_evidence_for_export {    #YYY

=pod

=head2 get_evidence_for_export

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
    my $cmap_object               = $args{'cmap_object'} or return;
    my $map_set_ids = $args{'map_set_ids'}||[];
    my $db                        = $cmap_object->db;
    my $evidence_type_data        = $cmap_object->evidence_type_data();
    my $return_object;

    my $sql_str = q[
        select ce.correspondence_evidence_id as object_id,
                   ce.feature_correspondence_id,
                   ce.accession_id,
                   ce.evidence_type_accession as evidence_type_aid,
                   ce.score
            from   cmap_correspondence_evidence ce
    ];
    if (@$map_set_ids){
        $sql_str .= q[
                 , cmap_feature_correspondence fc,
                   cmap_feature f1,
                   cmap_feature f2,
                   cmap_map map1,
                   cmap_map map2
            where  ce.feature_correspondence_id=fc.feature_correspondence_id
            and    fc.feature_id1=f1.feature_id
            and    f1.map_id=map1.map_id
            and    fc.feature_id2=f2.feature_id
            and    f2.map_id=map2.map_id
        ];
        $sql_str .= "and map1.map_set_id in ("
          . join(",",sort @$map_set_ids)
          . ") ";
        $sql_str .= "and map2.map_set_id in ("
          . join(",",sort @$map_set_ids)
          . ") ";
    }
    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} });

    foreach my $row ( @{$return_object} ) {
        $row->{'rank'} =
          $evidence_type_data->{ $row->{'evidence_type_aid'} }{'rank'};
    }

    return $return_object;
}

#-----------------------------------------------
sub get_comparative_maps_with_count {    #YYY

=pod

=head2 get_comparative_maps_with_count

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
    my $cmap_object                 = $args{'cmap_object'} or return;
    my $min_correspondences         = $args{'min_correspondences'};
    my $slot_info                   = $args{'slot_info'} || {};
    my $map_aids                    = $args{'map_aids'} || [];
    my $ignore_map_aids             = $args{'ignore_map_aids'} || [];
    my $included_evidence_type_aids = $args{'included_evidence_type_aids'}
      || [];
    my $ignored_evidence_type_aids = $args{'ignored_evidence_type_aids'}
      || [];
    my $less_evidence_type_aids    = $args{'less_evidence_type_aids'}    || [];
    my $greater_evidence_type_aids = $args{'greater_evidence_type_aids'} || [];
    my $evidence_type_score        = $args{'evidence_type_score'}        || {};
    my $ignored_feature_type_aids  = $args{'ignored_feature_type_aids'}  || [];
    my $include_map1_data          = $args{'include_map1_data'};
    $include_map1_data = 1 unless ( defined $include_map1_data );

    my $db = $cmap_object->db;
    my $return_object;

    my $select_sql = qq[
        select   count(distinct cl.feature_correspondence_id) as no_corr,
                 cl.map_id2,
                 map2.accession_id as map_aid2,
                 map2.map_set_id as map_set_id2
    ];
    my $from_sql = qq[
        from     cmap_correspondence_lookup cl,
                 cmap_feature_correspondence fc,
                 cmap_map map1,
                 cmap_map map2
    ];
    my $where_sql = qq[
        where    cl.feature_correspondence_id=
                 fc.feature_correspondence_id
        and      fc.is_enabled=1
        and      cl.map_id1!=cl.map_id2
        and      map1.map_id=cl.map_id1
        and      map2.map_id=cl.map_id2
    ];
    my $group_by_sql = qq[
        group by cl.map_id2,
                 map2.accession_id,
                 map2.map_set_id 
    ];

    if ($include_map1_data) {
        $select_sql .= qq[
                 cl.map_id1,
                 map1.accession_id as map_aid1,
                 map1.map_set_id as map_set_id1
        ];
        $group_by_sql .= qq[
                 , cl.map_id1,
                 map1.accession_id,
                 map1.map_set_id
        ];
    }
    my $having_sql = '';

    if (@$map_aids) {
        $where_sql .=
          " and map1.accession_id in ('"
          . join( "','", sort @{$map_aids} ) . "') \n";
    }

    if (@$ignore_map_aids) {
        $where_sql .=
          " and map2.accession_id not in ('"
          . join( "','", sort @{$ignore_map_aids} ) . "') ";
    }

    my @unrestricted_map_ids;
    my $restricted_sql   = '';
    my $unrestricted_sql = '';
    foreach my $ref_map_id ( keys( %{$slot_info} ) ) {
        my $ref_map_start = $slot_info->{$ref_map_id}[0];
        my $ref_map_stop  = $slot_info->{$ref_map_id}[1];
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
    my $from_restriction = $restricted_sql . $unrestricted_sql;
    $from_restriction =~ s/^\s+or//;
    $where_sql .= " and (" . $from_restriction . ")"
      if $from_restriction;

    if (   @$included_evidence_type_aids
        or @$less_evidence_type_aids
        or @$greater_evidence_type_aids )
    {
        $from_sql  .= ', cmap_correspondence_evidence ce';
        $where_sql .= q[
            and fc.feature_correspondence_id=ce.feature_correspondence_id
            and  ( ];
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
        $where_sql .= join( ' or ', @join_array ) . " ) ";
    }
    elsif (@$ignored_evidence_type_aids) {

        #all are ignored, return nothing
        return [];
    }

    if (@$ignored_feature_type_aids) {
        $where_sql .=
          " and cl.feature_type_accession2 not in ('"
          . join( "','", @$ignored_feature_type_aids ) . "') ";
    }

    if ($min_correspondences) {
        $having_sql .= qq[
              having count(cl.feature_correspondence_id)>$min_correspondences
            ];
    }

    my $sql_str =
      $select_sql . $from_sql . $where_sql . $group_by_sql . $having_sql;

    unless ( $return_object = $cmap_object->get_cached_results( 4, $sql_str ) )
    {
        $return_object =
          $db->selectall_arrayref( $sql_str, { Columns => {} }, );
        $self->store_cached_results( 4, $sql_str, $return_object );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_correspondence_count {    #YYY

=pod

=head2 get_correspondence_count

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
    my $cmap_object                 = $args{'cmap_object'} or return;
    my $clustering                  = $args{'clustering'};
    my $split_evidence_types        = $args{'split_evidence_types'};
    my $show_intraslot_corr         = $args{'show_intraslot_corr'};
    my $slot_info                   = $args{'slot_info'} || {};
    my $slot_info2                  = $args{'slot_info2'} || {};
    my $map_aids                    = $args{'map_aids'} || [];
    my $ignore_map_aids             = $args{'ignore_map_aids'} || [];
    my $included_evidence_type_aids = $args{'included_evidence_type_aids'}
      || [];
    my $ignored_evidence_type_aids = $args{'ignored_evidence_type_aids'}
      || [];
    my $less_evidence_type_aids    = $args{'less_evidence_type_aids'}    || [];
    my $greater_evidence_type_aids = $args{'greater_evidence_type_aids'} || [];
    my $evidence_type_score        = $args{'evidence_type_score'}        || {};
    my $ignored_feature_type_aids  = $args{'ignored_feature_type_aids'}  || [];
    my $db                         = $cmap_object->db;
    my $return_object;

    my $select_sql = qq[
        select   cl.map_id1,
                 cl.map_id2
    ];

    my $from_sql = qq[
        from     cmap_correspondence_lookup cl,
                 cmap_feature_correspondence fc,
                 cmap_correspondence_evidence ce
    ];
    my $where_sql = qq[
        where    cl.feature_correspondence_id=
                 fc.feature_correspondence_id
        and      fc.is_enabled=1
        and      fc.feature_correspondence_id=
                 ce.feature_correspondence_id
        and      cl.map_id1!=cl.map_id2
    ];

    my $group_by_sql = qq[
        group by cl.map_id1,
                 cl.map_id2,
                 ce.evidence_type_accession
    ];

    if ($split_evidence_types) {
        $select_sql .= ", ce.evidence_type_accession as evidence_type_aid \n";
    }
    else {
        $select_sql .= ", '"
          . DEFAULT->{'aggregated_type_substitute'}
          . "' as evidence_type_aid \n ";
    }
    if ($clustering) {
        $select_sql .=
            ', cl.start_position1,cl.stop_position1,'
          . 'cl.start_position2,cl.stop_position2';
        $group_by_sql = '';
    }
    else {
        $select_sql .= qq[
            , count(distinct cl.feature_correspondence_id) as no_corr, 
            min(cl.start_position2) as min_start2, 
            max(cl.start_position2) as max_start2, 
            avg(((cl.stop_position2-cl.start_position2)/2)
            +cl.start_position2) as avg_mid2, 
            avg(cl.start_position2) as start_avg2,
            avg(cl.start_position1) as start_avg1,
            min(cl.start_position1) as min_start1, 
            max(cl.start_position1) as max_start1 , 
            avg(((cl.stop_position1-cl.start_position1)/2)
            +cl.start_position1) as avg_mid1 
        ];
    }

    # Deal with slot_info
    my @unrestricted_map_ids = ();
    my $unrestricted_sql_1   = '';
    my $restricted_sql_1     = '';
    my $unrestricted_sql_2   = '';
    my $restricted_sql_2     = '';
    foreach my $slot_map_id ( keys( %{$slot_info} ) ) {
        my $this_start = $slot_info->{$slot_map_id}->[0];
        my $this_stop  = $slot_info->{$slot_map_id}->[1];

        if (    defined($this_start)
            and defined($this_stop) )
        {
            $restricted_sql_1 .=
                " or (cl.map_id1="
              . $slot_map_id
              . " and (( cl.start_position1>="
              . $this_start
              . " and cl.start_position1<="
              . $this_stop
              . " ) or ( cl.stop_position1 is not null and "
              . "  cl.start_position1<="
              . $this_start
              . " and cl.stop_position1>="
              . $this_start . " )))";
            if ($show_intraslot_corr) {
                $restricted_sql_2 .=
                    " or (cl.map_id2="
                  . $slot_map_id
                  . " and (( cl.start_position2>="
                  . $this_start
                  . " and cl.start_position2<="
                  . $this_stop
                  . " ) or ( cl.stop_position2 is not null and "
                  . "  cl.start_position2<="
                  . $this_start
                  . " and cl.stop_position2>="
                  . $this_start . " )))";
            }

        }
        elsif ( defined($this_start) ) {
            $restricted_sql_1 .=
                " or (cl.map_id1="
              . $slot_map_id
              . " and (( cl.start_position1>="
              . $this_start
              . " ) or ( cl.stop_position1 is not null "
              . " and cl.stop_position1>="
              . $this_start . " )))";
            if ($show_intraslot_corr) {
                $restricted_sql_2 .=
                    " or (cl.map_id2="
                  . $slot_map_id
                  . " and (( cl.start_position2>="
                  . $this_start
                  . " ) or ( cl.stop_position2 is not null "
                  . " and cl.stop_position2>="
                  . $this_start . " )))";
            }
        }
        elsif ( defined($this_stop) ) {
            $restricted_sql_1 .=
                " or (cl.map_id1="
              . $slot_map_id
              . " and cl.start_position1<="
              . $this_stop . ") ";
            if ($show_intraslot_corr) {
                $restricted_sql_2 .=
                    " or (cl.map_id2="
                  . $slot_map_id
                  . " and cl.start_position2<="
                  . $this_stop . ") ";
            }
        }
        else {
            push @unrestricted_map_ids, $slot_map_id;
        }
    }
    if (@unrestricted_map_ids) {
        $unrestricted_sql_1 .=
          " or cl.map_id1 in (" . join( ',', @unrestricted_map_ids ) . ") ";
        if ($show_intraslot_corr) {
            $unrestricted_sql_2 .=
              " or cl.map_id2 in (" . join( ',', @unrestricted_map_ids ) . ") ";
        }
    }
    my $combined_sql = $restricted_sql_1 . $unrestricted_sql_1;
    $combined_sql =~ s/^\s+or//;
    $where_sql .= " and (" . $combined_sql . ")";

    if (%$slot_info2) {

        # Include reference slot maps
        @unrestricted_map_ids = ();
        foreach my $slot_map_id ( keys( %{$slot_info2} ) ) {
            my $this_start = $slot_info2->{$slot_map_id}->[0];
            my $this_stop  = $slot_info2->{$slot_map_id}->[1];

            # $this_start is start [1] is stop
            if (    defined($this_start)
                and defined($this_start) )
            {
                $restricted_sql_2 .=
                    " or (cl.map_id2="
                  . $slot_map_id
                  . " and (( cl.start_position2>="
                  . $this_start
                  . " and cl.start_position2<="
                  . $this_stop
                  . " ) or ( cl.stop_position2 is not null and "
                  . "  cl.start_position2<="
                  . $this_start
                  . " and cl.stop_position2>="
                  . $this_start . " )))";
            }
            elsif ( defined($this_start) ) {
                $restricted_sql_2 .=
                    " or (cl.map_id2="
                  . $slot_map_id
                  . " and (( cl.start_position2>="
                  . $this_start
                  . " ) or ( cl.stop_position2 is not null "
                  . " and cl.stop_position2>="
                  . $this_start . " )))";
            }
            elsif ( defined($this_stop) ) {
                $restricted_sql_2 .=
                    " or (cl.map_id2="
                  . $slot_map_id
                  . " and cl.start_position2<="
                  . $this_stop . ") ";
            }
            else {
                push @unrestricted_map_ids, $slot_map_id;
            }
        }
        if (@unrestricted_map_ids) {
            $unrestricted_sql_2 .=
              " or cl.map_id2 in (" . join( ',', @unrestricted_map_ids ) . ") ";
        }
    }
    $combined_sql = $restricted_sql_2 . $unrestricted_sql_2;
    $combined_sql =~ s/^\s+or//;
    $where_sql .= " and (" . $combined_sql . ")";

    if (   @$included_evidence_type_aids
        or @$less_evidence_type_aids
        or @$greater_evidence_type_aids )
    {
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
        $where_sql .= " and ( " . join( ' or ', @join_array ) . " ) ";
    }
    elsif (@$ignored_evidence_type_aids) {

        #all are ignored, return nothing
        return [];
    }

    my $sql_str = $select_sql . $from_sql . $where_sql . $group_by_sql;

    unless ( $return_object = $cmap_object->get_cached_results( 4, $sql_str ) )
    {
        $return_object =
          $db->selectall_arrayref( $sql_str, { Columns => {} }, );
        $self->store_cached_results( 4, $sql_str, $return_object );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_map_sets_for_export {    #YYY

=pod

=head2 get_map_sets_for_export

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
    my $map_set_ids           = $args{'map_set_ids'}||[];
    my $db          = $cmap_object->db;
    my $return_object;
    my $sql_str = qq[
        select map_set_id as object_id,
               accession_id,
               map_set_name,
               map_set_short_name,
               map_type_accession as map_type_aid,
               species_id,
               published_on,
               can_be_reference_map,
               display_order,
               is_enabled,
               shape,
               color,
               width,
               is_relational_map,
               map_units
        from   cmap_map_set ms
    ];
    if (@$map_set_ids){
        $sql_str .= 'where map_set_id in (' . join( ',', @$map_set_ids ) . ')';
    }

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );

    return $return_object;
}

#-----------------------------------------------
sub get_maps_for_export {    #YYY

=pod

=head2 get_maps_for_export

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
    my $map_set_id           = $args{'map_set_id'} or return [];
    my $db          = $cmap_object->db;
    my $return_object;
    my $sql_str = qq[
        select map_id as object_id,
               accession_id,
               map_name,
               display_order,
               start_position,
               stop_position
        from   cmap_map
        where  map_set_id=?
    ];

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} },$map_set_id );

    return $return_object;
}

#-----------------------------------------------
sub get_features_for_export {    #YYY

=pod

=head2 get_features_for_export

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
    my $map_id           = $args{'map_id'} or return [];
    my $db          = $cmap_object->db;
    my $return_object;
    my $sql_str = qq[
         select feature_id as object_id,
               accession_id,
               feature_name,
               is_landmark,
               start_position,
               stop_position,
               feature_type_accession as feature_type_aid,
               default_rank,
               direction
        from   cmap_feature
        where  map_id=?
    ];

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} },$map_id );

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
    my $x           = $args{''};
    my $db          = $cmap_object->db;
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

