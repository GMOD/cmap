package Bio::GMOD::CMap::Data::Generic;

# vim: set ft=perl:

# $Id: Generic.pm,v 1.81 2005-05-24 18:26:10 mwz444 Exp $

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

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.81 $)[-1];

use Data::Dumper;    # really just for debugging
use Time::ParseDate;
use Regexp::Common;
use Bio::GMOD::CMap::Utils;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap;
use base 'Bio::GMOD::CMap';

use constant STR => 'string';
use constant NUM => 'number';

# ----------------------------------------------------

=pod

=head1 Maintenance Methods

=cut 

sub init {    #ZZZ

=pod

=head2 init()

=over 4

=item * Description

Initialize values that will be needed.

=item * Adaptor Writing Info

This is a handy place to put lookup hashes for object type to table names.

=back

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
    $self->{'OBJECT_TYPES'} = {
        cmap_correspondence_evidence => 'correspondence_evidence',
        cmap_feature                 => 'feature',
        cmap_feature_alias           => 'feature_alias',
        cmap_feature_correspondence  => 'feature_correspondence',
        cmap_map                     => 'map',
        cmap_map_set                 => 'map_set',
        cmap_species                 => 'species',
        cmap_xref                    => 'xref',
    };

    return $self;
}

# ----------------------------------------------------
sub date_format {    #ZZZ

=pod

=head2 date_format()

The strftime string for date format.  This is specific to RDBMS.

=cut

    my $self = shift;
    return '%Y-%m-%d';
}

=pod

=head1 Object Access Methods

=cut 

#-----------------------------------------------
sub acc_id_to_internal_id {    #ZZZ

=pod

=head2 acc_id_to_internal_id()

=over 4

=item * Description

Return the internal id that corresponds to the accession id

=item * Adaptor Writing Info

If you db doesn't have accessions, this function can just accept an id and
return the same id.

Fully implementing this will require conversion from object type to a table.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Accession ID (acc_id)

=item - Object type such as feature or map_set (object_type)

=back

=item * Output

ID Scalar

=item * Cache Level (Not Used): 4

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $object_type = $args{'object_type'}
      or return $self->error('No object name');
    my $acc_id     = $args{'acc_id'} or return $self->error('No accession id');
    my $table_name = $self->{'TABLE_NAMES'}->{$object_type};
    my $id_field   = $self->{'ID_FIELDS'}->{$table_name};
    my $aid_field  = 'accession_id';

    my $db = $cmap_object->db;
    my $return_object;

    my $sql_str = qq[
            select $id_field 
            from   $table_name
            where  $aid_field=?
      ];
    $return_object = $db->selectrow_array( $sql_str, {}, ($acc_id) );

    return $return_object;
}

#-----------------------------------------------
sub internal_id_to_acc_id {    #ZZZ

=pod

=head2 internal_id_to_acc_id()

=over 4

=item * Description

Return the accession id that corresponds to the internal id

=item * Adaptor Writing Info

If you db doesn't have accessions, this function can just accept an id and
return the same id.

Fully implementing this will require conversion from object type to a table.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - ID (id)

=item - Object type such as feature or map_set (object_type)

=back

=item * Output

Accession ID Scalar

=item * Cache Level (If Used): 4

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $object_type = $args{'object_type'}
      or return $self->error('No object name');
    my $id         = $args{'id'} or return $self->error('No id');
    my $table_name = $self->{'TABLE_NAMES'}->{$object_type};
    my $id_field   = $self->{'ID_FIELDS'}->{$table_name};
    my $aid_field  = 'accession_id';

    my $db = $cmap_object->db;
    my $return_object;

    my $sql_str = qq[
            select $aid_field as ] . $object_type . qq[_aid 
            from   $table_name
            where  $id_field=?
      ];
    $return_object = $db->selectrow_array( $sql_str, {}, ($id) )
      or return $self->error(
        qq[Unable to find accession id for id "$id" in table "$table_name"]);

    return $return_object;
}

#-----------------------------------------------
sub get_object_name {    #ZZZ

=pod

=head2 get_object_name()

=over 4

=item * Description

Retrieves the name attached to a database object given the object type and the
object id.

=item * Adaptor Writing Info

This will require conversion from object type to a table.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Object type such as feature or map_set (object_type)

=item - Object ID (object_id) 

=back

=item * Optional Input

=over 4

=item - Order by clause (order_by)

=back

=item * Output

Object Name

=item * Cache Level (Not Used): 4

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $object_type = $args{'object_type'}
      or return $self->error('No object type');
    my $object_id = $args{'object_id'} or return $self->error('No object id');
    my $order_by = $args{'order_by'};
    my $object_name_field = $object_type . "_name";
    my $object_id_field   = $object_type . "_id";

    my $db = $cmap_object->db;
    my $return_object;
    my @identifiers = ();

    my $table_name = $self->{'TABLE_NAMES'}->{$object_type};

    my $sql_str = qq[
        select $object_name_field
        from   $table_name
        where  $object_id_field=$object_id
    ];
    if ( !$order_by || $order_by eq 'display_order' ) {
        $sql_str = 'display_order,attribute_name';
    }

    $return_object = $db->selectrow_array($sql_str);

    return $return_object;
}

=pod

=head1 Table Information Methods

=cut 

# ----------------------------------------------------
sub pk_name {    #ZZZ

=pod

=head2 pk_name()

=over 4

=item * Description

Return the name of the primary key field for an object type.

Example:  $primary_key_field = $sql_object->pk_name('feature');

=item * Adaptor Writing Info

In another db schema, this might be a little more complex than the generic
method.

=item * Input

=over 4

=item - object type (shifted in);

=back

=item * Output

Primary key field

=back

=cut

    my $self        = shift;
    my $object_type = shift;
    $object_type .= '_id';
    return $object_type;
}

#-----------------------------------------------
sub get_table_info {    #ZZZ

=pod

=head2 get_table_info()

=over 4

=item * Description

Give a description of the database for export.

=item * Adaptor Writing Info

Only implement this if you want to export data as sql statements.

=item * Output

Array of Hashes:

  Keys:
    name   - table name
    fields - hash of fields in the table

=back

=cut

    my ( $self, %args ) = @_;
    my @tables = (
        {
            name   => 'cmap_attribute',
            fields => {
                attribute_id    => NUM,
                table_name      => STR,
                object_id       => NUM,
                display_order   => NUM,
                is_public       => NUM,
                attribute_name  => STR,
                attribute_value => STR,
            }
        },
        {
            name   => 'cmap_correspondence_evidence',
            fields => {
                correspondence_evidence_id => NUM,
                accession_id               => STR,
                feature_correspondence_id  => NUM,
                evidence_type_accession    => STR,
                score                      => NUM,
                rank                       => NUM,
            }
        },
        {
            name   => 'cmap_correspondence_lookup',
            fields => {
                feature_id1               => NUM,
                feature_id2               => NUM,
                feature_correspondence_id => NUM,

            }
        },
        {
            name   => 'cmap_correspondence_matrix',
            fields => {
                reference_map_aid     => STR,
                reference_map_name    => STR,
                reference_map_set_aid => STR,
                reference_species_aid => STR,
                link_map_aid          => STR,
                link_map_name         => STR,
                link_map_set_aid      => STR,
                link_species_aid      => STR,
                no_correspondences    => NUM,
            }
        },
        {
            name   => 'cmap_feature',
            fields => {
                feature_id             => NUM,
                accession_id           => STR,
                map_id                 => NUM,
                feature_type_accession => STR,
                feature_name           => STR,
                is_landmark            => NUM,
                start_position         => NUM,
                stop_position          => NUM,
                default_rank           => NUM,
            }
        },
        {
            name   => 'cmap_feature_alias',
            fields => {
                feature_alias_id => NUM,
                feature_id       => NUM,
                alias            => STR,
            }
        },
        {
            name   => 'cmap_feature_correspondence',
            fields => {
                feature_correspondence_id => NUM,
                accession_id              => STR,
                feature_id1               => NUM,
                feature_id2               => NUM,
                is_enabled                => NUM,
            }
        },
        {
            name   => 'cmap_map',
            fields => {
                map_id         => NUM,
                accession_id   => STR,
                map_set_id     => NUM,
                map_name       => STR,
                display_order  => NUM,
                start_position => NUM,
                stop_position  => NUM,
            }
        },
        {
            name   => 'cmap_next_number',
            fields => {
                table_name  => STR,
                next_number => NUM,
            }
        },
        {
            name   => 'cmap_species',
            fields => {
                species_id          => NUM,
                accession_id        => STR,
                species_common_name => STR,
                species_full_name   => STR,
                display_order       => STR,
            }
        },
        {
            name   => 'cmap_map_set',
            fields => {
                map_set_id           => NUM,
                accession_id         => STR,
                map_set_short_name   => STR,
                map_set_short_name   => STR,
                map_type_accession   => STR,
                species_id           => NUM,
                published_on         => STR,
                can_be_reference_map => NUM,
                display_order        => NUM,
                is_enabled           => NUM,
                shape                => STR,
                color                => STR,
                width                => NUM,
                map_units            => STR,
                is_relational_map    => NUM,
            },
        },
        {
            name   => 'cmap_xref',
            fields => {
                xref_id       => NUM,
                table_name    => STR,
                object_id     => NUM,
                display_order => NUM,
                xref_name     => STR,
                xref_url      => STR,
            }
        },
    );

    return \@tables;
}

=pod

=head1 Special Information Methods

=cut 

#-----------------------------------------------
sub get_slot_info {    #ZZZ

=pod

=head2 get_slot_info()

=over 4

=item * Description

Creates and returns map info for each slot in a very specific format.  

It iterates through the slots starting from the inside and going out (0,1,-1,2,-2...).  After slot 0, it makes sure that only maps that have correspondences to the preceding slot.  It uses the map set accessions from the map_sets hash and the information in the maps hash to get the maps.  

The other optional inputs are used to widdle down the correspondences.

=item * Adaptor Writing Info

It might be a good idea to follow the code follows.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Slot information (slots)

 Data Structure
  slots = {
    slot_no => {
        map_set_aid => $map_set_aid,
        map_sets    => { $map_set_aid => () },
        maps        => { $map_id => {
                start => $start,
                stop  => $stop,
                map   => $magnification,
            }
        }
    }
  }

=back

=item * Optional Input

=over 4

=item - Included Evidence Types Accessions (included_evidence_type_aids)

=item - Ev. types that must be less than score (less_evidence_type_aids)

=item - Ev. types that must be greater than score (greater_evidence_type_aids)

=item - Scores for comparing to evidence types (evidence_type_score)

=item - Feature Type Accessions to ignore (ignored_feature_type_aids)

=item - Minimum number of correspondences (min_correspondences)

=back

=item * Output

 Data Structure:
  slot_info  =  {
    slot_no  => {
      map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ]
    }
  }

"current_start" and "current_stop" are undef if using the
original start and stop.

=item * Cache Level: 4

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
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
        my $from         = ' ';
        my $where        = '';
        my $group_by_sql = '';
        my $having       = '';
        my $aid_where    = '';
        my $sql_str      = '';
        my $map_sets     = $slots->{$slot_no}{'map_sets'};
        my $maps         = $slots->{$slot_no}{'maps'};

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

            if (   @$included_evidence_type_aids
                or @$less_evidence_type_aids
                or @$greater_evidence_type_aids )
            {
                $from  .= ", cmap_correspondence_evidence ce ";
                $where .=
                    " and ce.feature_correspondence_id = "
                  . "cl.feature_correspondence_id ";
                $where .= " and ( ";
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
                $group_by_sql = q[ 
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
        $sql_str = "$sql_base $from $where $group_by_sql $having\n";

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

=pod

=head1 Species Methods

=cut 

#-----------------------------------------------
sub get_species {    #ZZZ

=pod

=head2 get_species()

=over 4

=item * Description

Gets species information

=item * Adaptor Writing Info

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - Species ID (species_id)

=item - List of Species Accessions (species_aids)

=item - Boolean: is this a relational map (is_relational_map)

Set to 1 or 0 to select based on the is_relational_map column.  Leave undefined
to ignore that column.

=item - Boolean: Is this enabled (is_enabled) 

Set to 1 or 0 to select based on the is_enabled column.  Leave undefined to
ignore that column.

=back

=item * Output

Array of Hashes:

  Keys:
    species_id,
    species_aid,
    species_common_name,
    species_full_name,
    display_order

=item * Cache Level (Not Used): 1

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object  = $args{'cmap_object'} or die "No CMap Object included";
    my $species_id   = $args{'species_id'};
    my $species_aids = $args{'species_aids'} || [];
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
sub get_species_aid {    #ZZZ

=pod

=head2 get_species_aid()

=over 4

=item * Description

Given a map set get it's species accession.

=item * Adaptor Writing Info

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Map Set Accession (map_set_aid)

=back

=item * Output

Species Accession

=item * Cache Level (Not Used): 1

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
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
sub insert_species {    #ZZZ

=pod

=head2 insert_species()

=over 4

=item * Description

Insert a species into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Species Accession (species_aid)

=item - Species Common Name (species_common_name)

=item - Species Full Name (species_full_name)

=item - Display Order (display_order)

=back

=item * Output

Species id

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $species_aid         = $args{'species_aid'} || $args{'accession_id'};
    my $species_common_name = $args{'species_common_name'};
    my $species_full_name   = $args{'species_full_name'};
    my $display_order       = $args{'display_order'};
    my $db                  = $cmap_object->db;
    my $species_id          = $self->next_number(
        cmap_object => $cmap_object,
        object_type => 'species',
      )
      or return $self->error('No next number for species ');
    $species_aid ||= $species_id;
    my @insert_args = (
        $species_id, $species_aid, $species_common_name, $species_full_name,
        $display_order
    );

    $db->do(
        qq[
        insert into cmap_species
        (species_id,accession_id,species_common_name,species_full_name,display_order )
         values ( ?,?,?,?,? )
        ],
        {},
        (@insert_args)
    );

    return $species_id;
}

#-----------------------------------------------
sub update_species {    #ZZZ

=pod

=head2 update_species()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

If you don't want CMap to update into your database, make this a dummy method.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Species ID (species_id)

=back

=item * Inputs To Update

=over 4

=item - Species Accession (species_aid)

=item - Species Common Name (species_common_name)

=item - Species Full Name (species_full_name)

=item - Display Order (display_order)

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $species_id = $args{'species_id'} || $args{'object_id'} or return;
    my $species_aid = $args{'species_aid'} || $args{'accession_id'};
    my $species_common_name = $args{'species_common_name'};
    my $species_full_name   = $args{'species_full_name'};
    my $display_order       = $args{'display_order'};
    my $db                  = $cmap_object->db;

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_species
    ];
    my $set_sql   = '';
    my $where_sql = " where species_id = ? ";    # ID

    if ($species_aid) {
        push @update_args, $species_aid;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " accession_id = ? ";
    }
    if ($species_common_name) {
        push @update_args, $species_common_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " species_common_name = ? ";
    }
    if ($species_full_name) {
        push @update_args, $species_full_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " species_full_name = ? ";
    }
    if ($display_order) {
        push @update_args, $display_order;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " display_order = ? ";
    }

    push @update_args, $species_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_species {    #ZZZ

=pod

=head2 delete_species()

=over 4

=item * Description

Given the id, delete this object.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Requred Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Species ID (species_id)

=back

=item * Output

1

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $db          = $cmap_object->db;
    my $species_id  = $args{'species_id'}
      or return $self->error('No ID given for species to delete ');
    my @delete_args = ();
    my $delete_sql  = qq[
        delete from cmap_species
    ];
    my $where_sql = '';

    if ($species_id) {
        push @delete_args, $species_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " species_id = ? ";
    }

    return unless ($where_sql);
    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
}

=pod

=head1 Map Set Methods

=cut 

#-----------------------------------------------
sub get_map_sets {    #ZZZ

=pod

=head2 get_map_sets()

=over 4

=item * Description

Get information on map sets including species info.

=item * Adaptor Writing Info

=item * Requred Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - Species ID (species_id)

=item - List of Species IDs (species_ids)

=item - Species Accession (species_aid)

=item - Map Set ID (map_set_id)

=item - List of Map Set IDs (map_set_ids)

=item - Map Set Accession (map_set_aid)

=item - List of Map Set Accessions (map_set_aids)

=item - Map Type Accession (map_type_aid)

=item - Boolean: is this a relational map (is_relational_map)

Set to 1 or 0 to select based on the is_relational_map column.  Leave undefined
to ignore that column.

=item - can_be_reference_map (can_be_reference_map) 

Set to 1 or 0 to select based on the can_be_reference_map column.  Leave
undefined to ignore that column.

=item - Boolean: Is this enabled (is_enabled) 

Set to 1 or 0 to select based on the is_enabled column.  Leave undefined to
ignore that column.

=item - Order by clause (order_by)

=item - Boolean count_maps (count_maps)

Add a map count to the return object

=back

=item * Output

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
    map_count (Only if $map_count is specified)

=item * Cache Level : 1

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object  = $args{'cmap_object'} or die "No CMap Object included";
    my $species_id   = $args{'species_id'};
    my $species_ids  = $args{'species_ids'} || [];
    my $species_aid  = $args{'species_aid'};
    my $map_set_id   = $args{'map_set_id'};
    my $map_set_ids  = $args{'map_set_ids'} || [];
    my $map_set_aid  = $args{'map_set_aid'};
    my $map_set_aids = $args{'map_set_aids'} || [];
    my $map_type_aid = $args{'map_type_aid'};
    my $is_relational_map    = $args{'is_relational_map'};
    my $can_be_reference_map = $args{'can_be_reference_map'};
    my $is_enabled           = $args{'is_enabled'};
    my $order_by             = $args{'order_by'};
    my $count_maps           = $args{'count_maps'};
    my $db                   = $cmap_object->db;
    my $map_type_data        = $cmap_object->map_type_data();
    my $return_object;

    my $select_sql = q[
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
    ];
    my $from_sql = qq[
        from    cmap_map_set ms,
                cmap_species s
    ];
    my $where_sql = qq[
        where   ms.species_id=s.species_id
    ];
    my $group_by_sql = '';
    my $order_by_sql = '';

    if ($map_set_id) {
        $where_sql .= " and ms.map_set_id = '$map_set_id' ";
    }
    elsif (@$map_set_ids) {
        $where_sql .=
          " and ms.map_set_id in (" . join( ",", sort @$map_set_ids ) . ") ";
    }
    elsif ($map_set_aid) {
        $where_sql .= " and ms.accession_id = '$map_set_aid' ";
    }
    elsif (@$map_set_aids) {
        $where_sql .=
          " and ms.accession_id in ('"
          . join( "','", sort @$map_set_aids ) . "') ";
    }
    if ($species_id) {
        $where_sql .= " and s.species_id= '$species_id' ";
    }
    elsif (@$species_ids) {
        $where_sql .=
          " and s.species_id in (" . join( ",", sort @$species_ids ) . ") ";
    }
    elsif ( $species_aid and $species_aid ne '-1' ) {
        $where_sql .= " and s.accession_id= '$species_aid' ";
    }
    if ($map_type_aid) {
        $where_sql .= " and ms.map_type_accession = '$map_type_aid' ";
    }
    if ( defined($is_relational_map) ) {
        $where_sql .= " and ms.is_relational_map = $is_relational_map ";
    }
    if ( defined($can_be_reference_map) ) {
        $where_sql .= " and ms.can_be_reference_map = $can_be_reference_map ";
    }
    if ( defined($is_enabled) ) {
        $where_sql .= " and ms.is_enabled = $is_enabled ";
    }
    if ($count_maps) {
        $select_sql .= ", count(map.map_id) as map_count ";
        $from_sql   .= qq[
            left join   cmap_map map
            on ms.map_set_id=map.map_set_id
        ];
        $group_by_sql = qq[
            group by 
                ms.map_set_id,
                ms.accession_id,
                ms.map_set_name,
                ms.map_set_short_name,
                ms.map_type_accession,
                ms.published_on,
                ms.can_be_reference_map,
                ms.is_enabled,
                ms.is_relational_map,
                ms.map_units,
                ms.display_order,
                s.species_id,
                s.accession_id,
                s.species_common_name,
                s.species_full_name,
                s.display_order,
        ];
    }
    if ($order_by) {
        $order_by_sql = " order by $order_by ";
    }

    my $sql_str =
      $select_sql . $from_sql . $where_sql . $group_by_sql . $order_by_sql;

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
sub get_map_sets_simple {    #ZZZ

=pod

=head2 get_map_sets_simple()

=over 4

=item * Description

Get just the info from the map sets.  This is less data than
get_map_sets() provides and doesn't involve any table joins.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - Map Set ID (map_set_id)

=item - List of Map Set IDs (map_set_ids)

=item - Map Set Accession (map_set_aid)

=item - List of Map Set Accessions (map_set_aids)

=item - Map Type Accession (map_type_aid)

=item - Boolean: is this a relational map (is_relational_map)

Set to 1 or 0 to select based on the is_relational_map column.  Leave undefined
to ignore that column.

=item - can_be_reference_map (can_be_reference_map) 

Set to 1 or 0 to select based on the can_be_reference_map column.  Leave
undefined to ignore that column.

=item - Boolean: Is this enabled (is_enabled) 

Set to 1 or 0 to select based on the is_enabled column.  Leave undefined to
ignore that column.

=back

=item * Output

Array of Hashes:

  Keys:
    map_set_id
    map_set_aid
    map_set_name
    map_set_short_name
    map_type_aid
    published_on
    can_be_reference_map
    is_enabled
    is_relational_map
    map_units
    map_set_display_order
    map_type
    map_type_display_order
    epoch_published_on

=item * Cache Level (Not Used): 1

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object  = $args{'cmap_object'} or die "No CMap Object included";
    my $map_set_id   = $args{'map_set_id'};
    my $map_set_ids  = $args{'map_set_ids'} || [];
    my $map_set_aid  = $args{'map_set_aid'};
    my $map_set_aids = $args{'map_set_aids'} || [];
    my $map_type_aid = $args{'map_type_aid'};
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

    if ($map_set_id) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " ms.map_set_id = $map_set_id ";
    }
    elsif (@$map_set_ids) {
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .=
          " ms.map_set_id in (" . join( ",", sort @$map_set_ids ) . ") ";
    }
    elsif ($map_set_aid) {
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
sub get_map_set_info_by_maps {    #ZZZ

=pod

=head2 get_map_set_info_by_maps()

=over 4

=item * Description

Given a list of map_ids get map set info. 

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - List of Map IDs (map_ids)

=back

=item * Output

Array of Hashes:

  Keys:
    map_set_id
    map_set_short_name
    species_common_name

=item * Cache Level (Not Used): 1

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $map_ids = $args{'map_ids'} || [];
    my $db = $cmap_object->db;
    my $return_object;
    my $sql_str = q[ 
        select distinct ms.map_set_id,
               ms.map_set_short_name,
               s.species_common_name 
        from   cmap_map_set ms,
               cmap_species s,
               cmap_map map 
        where  ms.species_id=s.species_id 
           and map.map_set_id=ms.map_set_id 
    ];
    if (@$map_ids) {

        # Only need to use one map id since all maps must
        # be from the same map set.
        $sql_str .= " and map.map_id = " . $map_ids->[0] . " ";
    }

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );

    return $return_object;
}

#-----------------------------------------------
sub insert_map_set {    #ZZZ

=pod

=head2 insert_map_set()

=over 4

Insert a map set into the database.

=item * Description

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Map Set Accession (map_set_aid)

=item - map_set_name (map_set_name)

=item - map_set_short_name (map_set_short_name)

=item - Map Type Accession (map_type_aid)

=item - Species ID (species_id)

=item - published_on (published_on)

=item - can_be_reference_map (can_be_reference_map)

=item - Display Order (display_order)

=item - Boolean: Is this enabled (is_enabled)

=item - shape (shape)

=item - width (width)

=item - color (color)

=item - map_units (map_units)

=item - Boolean: is this a relational map (is_relational_map)

=back

=item * Output

Map Set id

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $map_set_aid          = $args{'map_set_aid'} || $args{'accession_id'};
    my $map_set_name         = $args{'map_set_name'};
    my $map_set_short_name   = $args{'map_set_short_name'};
    my $map_type_aid         = $args{'map_type_aid'};
    my $species_id           = $args{'species_id'};
    my $published_on         = $args{'published_on'};
    my $can_be_reference_map = $args{'can_be_reference_map'};
    my $display_order        = $args{'display_order'};
    my $is_enabled           = $args{'is_enabled'};
    $is_enabled = 1 unless ( defined($is_enabled) );
    my $shape             = $args{'shape'};
    my $width             = $args{'width'};
    my $color             = $args{'color'};
    my $map_units         = $args{'map_units'};
    my $is_relational_map = $args{'is_relational_map'} || 0;
    my $db                = $cmap_object->db;
    my $map_set_id        = $self->next_number(
        cmap_object => $cmap_object,
        object_type => 'map_set',
      )
      or return $self->error('No next number for map_set ');
    $map_set_aid ||= $map_set_id;
    my @insert_args = (
        $map_set_id,         $map_set_aid,          $map_set_name,
        $map_set_short_name, $map_type_aid,         $species_id,
        $published_on,       $can_be_reference_map, $display_order,
        $is_enabled,         $shape,                $width,
        $color,              $map_units,            $is_relational_map
    );

    $db->do(
        qq[
        insert into cmap_map_set
        (map_set_id,accession_id,map_set_name,map_set_short_name,map_type_accession,species_id,published_on,can_be_reference_map,display_order,is_enabled,shape,width,color,map_units,is_relational_map )
         values ( ?,?,?,?,?,?,?,?,?,?,?,?,?,?,? )
        ],
        {},
        (@insert_args)
    );

    return $map_set_id;
}

#-----------------------------------------------
sub update_map_set {    #ZZZ

=pod

=head2 update_map_set()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

If you don't want CMap to update into your database, make this a dummy method.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Map Set ID (map_set_id)

=back

=item * Inputs To Update

=over 4

=item - Map Set Accession (map_set_aid)

=item - map_set_name (map_set_name)

=item - map_set_short_name (map_set_short_name)

=item - Map Type Accession (map_type_aid)

=item - Species ID (species_id)

=item - published_on (published_on)

=item - can_be_reference_map (can_be_reference_map)

=item - Display Order (display_order)

=item - Boolean: Is this enabled (is_enabled)

=item - shape (shape)

=item - width (width)

=item - color (color)

=item - map_units (map_units)

=item - Boolean: is this a relational map (is_relational_map)

Set to 1 or 0 to select based on the is_relational_map column.  Leave undefined
to ignore that column.

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $map_set_id = $args{'map_set_id'} || $args{'object_id'} or return;
    my $map_set_aid = $args{'map_set_aid'} || $args{'accession_id'};
    my $map_set_name         = $args{'map_set_name'};
    my $map_set_short_name   = $args{'map_set_short_name'};
    my $map_type_aid         = $args{'map_type_aid'};
    my $species_id           = $args{'species_id'};
    my $published_on         = $args{'published_on'};
    my $can_be_reference_map = $args{'can_be_reference_map'};
    my $display_order        = $args{'display_order'};
    my $is_enabled           = $args{'is_enabled'};
    my $shape                = $args{'shape'};
    my $width                = $args{'width'};
    my $color                = $args{'color'};
    my $map_units            = $args{'map_units'};
    my $is_relational_map    = $args{'is_relational_map'};
    my $db                   = $cmap_object->db;

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_map_set
    ];
    my $set_sql   = '';
    my $where_sql = " where map_set_id = ? ";    # ID

    if ($map_set_aid) {
        push @update_args, $map_set_aid;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " accession_id = ? ";
    }
    if ($map_set_name) {
        push @update_args, $map_set_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " map_set_name = ? ";
    }
    if ($map_set_short_name) {
        push @update_args, $map_set_short_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " map_set_short_name = ? ";
    }
    if ($map_type_aid) {
        push @update_args, $map_type_aid;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " map_type_accession = ? ";
    }
    if ($species_id) {
        push @update_args, $species_id;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " species_id = ? ";
    }
    if ($published_on) {
        push @update_args, $published_on;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " published_on = ? ";
    }
    if ($can_be_reference_map) {
        push @update_args, $can_be_reference_map;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " can_be_reference_map = ? ";
    }
    if ($display_order) {
        push @update_args, $display_order;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " display_order = ? ";
    }
    if ($is_enabled) {
        push @update_args, $is_enabled;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " is_enabled = ? ";
    }
    if ($shape) {
        push @update_args, $shape;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " shape = ? ";
    }
    if ($width) {
        push @update_args, $width;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " width = ? ";
    }
    if ($color) {
        push @update_args, $color;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " color = ? ";
    }
    if ($map_units) {
        push @update_args, $map_units;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " map_units = ? ";
    }
    if ($is_relational_map) {
        push @update_args, $is_relational_map;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " is_relational_map = ? ";
    }

    push @update_args, $map_set_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_map_set {    #ZZZ

=pod

=head2 delete_map_set()

=over 4

=item * Description

Given the id, delete this object.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Requred Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Map Set ID (map_set_id)

=back

=item * Output

1

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $db          = $cmap_object->db;
    my $map_set_id  = $args{'map_set_id'}
      or return $self->error('No ID given for map_set to delete ');
    my @delete_args = ();
    my $delete_sql  = qq[
        delete from cmap_map_set
    ];
    my $where_sql = '';

    if ($map_set_id) {
        push @delete_args, $map_set_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map_set_id = ? ";
    }

    return unless ($where_sql);
    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
}

=pod

=head1 Map Methods

=cut 

#-----------------------------------------------
sub get_maps {    #ZZZ

=pod

=head2 get_maps()

=over 4

=item * Description

Get information on map sets including map set and species info.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - Map ID (map_id)

=item - List of Map IDs (map_ids)

=item - Map Set ID (map_set_id)

=item - Map Set Accession (map_set_aid)

=item - List of Map Set Accessions (map_set_aids)

=item - Map Name (map_name)

=item - Map Length (map_length)

=item - Map Type Accession (map_type_aid)

=item - Species Accession (species_aid)

=item - Boolean: is this a relational map (is_relational_map)

Set to 1 or 0 to select based on the is_relational_map column.  Leave undefined
to ignore that column.

=item - Boolean: Is this enabled (is_enabled) 

Set to 1 or 0 to select based on the is_enabled column.  Leave undefined to
ignore that column.

=item - Boolean count_features (count_features)

Add a feature count to the return object

=back

=item * Output

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
    published_on,
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
    default_shape
    default_color
    default_width
    feature_count (Only if $count_features is specified)

=item * Cache Level: 2

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object  = $args{'cmap_object'} or die "No CMap Object included";
    my $map_id       = $args{'map_id'};
    my $map_ids      = $args{'map_ids'} || [];
    my $map_set_id   = $args{'map_set_id'};
    my $map_set_aid  = $args{'map_set_aid'};
    my $map_set_aids = $args{'map_set_aids'} || [];
    my $map_name     = $args{'map_name'};
    my $map_length   = $args{'map_length'};
    my $map_type_aid = $args{'map_type_aid'};
    my $species_aid  = $args{'species_aid'};
    my $is_relational_map = $args{'is_relational_map'};
    my $is_enabled        = $args{'is_enabled'};
    my $count_features    = $args{'count_features'};
    my $db                = $cmap_object->db;
    my $map_type_data     = $cmap_object->map_type_data();
    my $return_object;

    my $select_sql = q[
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
    ];
    my $from_sql = q[
        from    cmap_map_set ms,
                cmap_species s,
                cmap_map map
    ];
    my $where_sql = q[
        where   map.map_set_id=ms.map_set_id
        and     ms.species_id=s.species_id
    ];
    my $group_by_sql = '';
    my $order_by_sql = '';

    if ($map_id) {
        $where_sql .= " and map.map_id = $map_id ";
    }
    elsif (@$map_ids) {
        $where_sql .=
          " and map.map_id in (" . join( ',', sort @$map_ids ) . ") ";
    }
    if ($map_name) {
        $where_sql .= " and map.map_name='$map_name' ";
    }
    if ($map_length) {
        $where_sql .=
          " and (map.stop_position - map.start_position + 1 = $map_length) ";
    }

    if ($map_set_id) {
        $where_sql .= " and ms.map_set_id = '$map_set_id' ";
    }
    elsif ($map_set_aid) {
        $where_sql .= " and ms.accession_id = '$map_set_aid' ";
    }
    elsif (@$map_set_aids) {
        $where_sql .=
          " and ms.accession_id in ('"
          . join( "','", sort @$map_set_aids ) . "') ";
    }

    if ($species_aid) {
        $where_sql .= qq[ and s.accession_id='$species_aid' ];
    }
    if ($map_type_aid) {
        $where_sql .= qq[ and ms.map_type_accession='$map_type_aid' ];
    }
    if ( defined($is_relational_map) ) {
        $where_sql .= " and ms.is_relational_map = $is_relational_map";
    }
    if ( defined($is_enabled) ) {
        $where_sql .= " and ms.is_enabled = $is_enabled";
    }

    if ($count_features) {
        $select_sql .= ", count(f.feature) as feature_count ";
        $from_sql   .= qq[
            left join   cmap_feature f
            on f.map_id=map.map_id
        ];
        $group_by_sql = qq[
            group by 
                map.map_id,
                map.accession_id,
                map.map_name,
                map.start_position,
                map.stop_position,
                map.display_order,
                ms.map_set_id,
                ms.accession_id,
                ms.map_set_name,
                ms.map_set_short_name,
                ms.published_on,
                ms.shape,
                ms.width,
                ms.color,
                ms.map_type_accession,
                ms.map_units,
                ms.is_relational_map,
                s.species_id,
                s.accession_id,
                s.species_common_name
        ];
    }
    $order_by_sql = ' order by map.display_order, map.map_name ';

    my $sql_str =
      $select_sql . $from_sql . $where_sql . $group_by_sql . $order_by_sql;

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
sub get_maps_simple {    #ZZZ

=pod

=head2 get_maps_simple()

=over 4

=item * Description

Get just the info from the maps.  This is less data than
get_maps() provides and doesn't involve any table joins.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - Map ID (map_id)

=item - Map Set ID (map_set_id)

=back

=item * Output

Array of Hashes:

  Keys:
    map_id
    accession_id
    map_name
    display_order
    start_position
    stop_position
    map_set_id

=item * Cache Level (If Used): 2

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $map_id      = $args{'map_id'};
    my $map_set_id  = $args{'map_set_id'};
    my $db          = $cmap_object->db;
    my $return_object;
    my $sql_str = qq[
        select map_id,
               accession_id,
               map_name,
               display_order,
               start_position,
               stop_position,
               map_set_id
        from   cmap_map
    ];
    my $where_sql = '';

    if ($map_id) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map_id = $map_id ";
    }
    elsif ($map_set_id) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map_set_id = $map_set_id ";
    }

    $sql_str .= $where_sql;

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );

    return $return_object;
}

#-----------------------------------------------
sub get_maps_from_map_set {    #ZZZ

=pod

=head2 get_maps_from_map_set()

=over 4

=item * Description

Given a map set accession, give a small amount of info about the maps in that
map set.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Map Set Accession (map_set_aid)

=back

=item * Output

Array of Hashes:

  Keys:
    map_aid
    map_id
    map_name

=item * Cache Level (If Used): 2

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
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
sub get_map_search_info {    #ZZZ

=pod

=head2 get_map_search_info()

=over 4

=item * Description

This is the method that drives the map search page.  Any new search features
will probably wind up here.

=item * Require Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Map Set ID (map_set_id)

=back

=item * Optional Input

=over 4

=item - Map Name (map_name)

=item - min_correspondence_maps (min_correspondence_maps)

=item - Minimum number of correspondences (min_correspondences)

=back

=item * Output

Array of Hashes:

  Keys:
    map_aid
    map_name
    start_position
    stop_position
    map_id
    display_order
    cmap_count
    corr_count

=item * Cache Level (If Used): 4

Not Caching because the calling method will do that.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $map_set_id = $args{'map_set_id'}
      or die "No Map Set Id passed to map search";
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
        $map_set_id );

    return $return_object;
}

#-----------------------------------------------
sub insert_map {    #ZZZ

=pod

=head2 insert_map()

=over 4

=item * Description

Insert a map into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - map_aid (map_aid)

=item - Map Set ID (map_set_id)

=item - Map Name (map_name)

=item - Display Order (display_order)

=item - start_position (start_position)

=item - stop_position (stop_position)

=back

=item * Output

Map id

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $map_aid        = $args{'map_aid'} || $args{'accession_id'};
    my $map_set_id     = $args{'map_set_id'};
    my $map_name       = $args{'map_name'};
    my $display_order  = $args{'display_order'} || 1;
    my $start_position = $args{'start_position'};
    my $stop_position  = $args{'stop_position'};
    my $db             = $cmap_object->db;
    my $map_id         =
      $self->next_number( cmap_object => $cmap_object, object_type => 'map', )
      or return $self->error('No next number for map');
    $map_aid ||= $map_id;
    my @insert_args = (
        $map_id, $map_aid, $map_set_id, $map_name, $display_order,
        $start_position, $stop_position
    );

    $db->do(
        qq[
        insert into cmap_map
        (map_id,accession_id,map_set_id,map_name,display_order,start_position,stop_position )
         values ( ?,?,?,?,?,?,? )
        ],
        {},
        (@insert_args)
    );

    return $map_id;
}

#-----------------------------------------------
sub update_map {    #ZZZ

=pod

=head2 update_map()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

If you don't want CMap to update into your database, make this a dummy method.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Map ID (map_id)

=back

=item * Inputs To Update

=over 4

=item - map_aid (map_aid)

=item - Map Set ID (map_set_id)

=item - Map Name (map_name)

=item - Display Order (display_order)

=item - start_position (start_position)

=item - stop_position (stop_position)

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $map_id = $args{'map_id'} || $args{'object_id'} or return;
    my $map_aid = $args{'map_aid'} || $args{'accession_id'};
    my $map_set_id     = $args{'map_set_id'};
    my $map_name       = $args{'map_name'};
    my $display_order  = $args{'display_order'};
    my $start_position = $args{'start_position'};
    my $stop_position  = $args{'stop_position'};
    my $db             = $cmap_object->db;
    my $return_object;

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_map
    ];
    my $set_sql   = '';
    my $where_sql = " where map_id = ? ";    # ID

    if ($map_aid) {
        push @update_args, $map_aid;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " accession_id = ? ";
    }
    if ($map_set_id) {
        push @update_args, $map_set_id;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " map_set_id = ? ";
    }
    if ($map_name) {
        push @update_args, $map_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " map_name = ? ";
    }
    if ($display_order) {
        push @update_args, $display_order;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " display_order = ? ";
    }
    if ( defined($start_position) ) {
        push @update_args, $start_position;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " start_position = ? ";
    }
    if ( defined($stop_position) ) {
        push @update_args, $stop_position;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " stop_position = ? ";
    }

    push @update_args, $map_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_map {    #ZZZ

=pod

=head2 delete_map()

=over 4

=item * Description

Given the id, delete this object.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Requred Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Map ID (map_id)

=back

=item * Output

1

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $db          = $cmap_object->db;
    my $map_id      = $args{'map_id'}
      or return $self->error('No ID given for map to delete ');
    my @delete_args = ();
    my $delete_sql  = qq[
        delete from cmap_map
    ];
    my $where_sql = '';

    if ($map_id) {
        push @delete_args, $map_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map_id = ? ";
    }

    return unless ($where_sql);
    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
}

=pod

=head1 Feature Methods

=cut 

#-----------------------------------------------
sub get_features {    #ZZZ

=pod

=head2 get_features()

=over 4

=item * Description

This method returns feature details.  At time of writing, this method is only
used in places methods that are only executed once per page view.  It is used
in places like the data_download, correspondence_detail_data and
feature_search_data.  Therefor, I'm not terribly worried about the time to
build the sql query (which increases with extra options).  I'm also not
concerned about the extra columns that are needed by some but not all of the
calling methods.

=item * Caveats

Identifiers that are more specific are used instead of more general ids.  For instance, if a feature_id and a map_id are specified, only the feature_id will be used because the map_id is a more broad search.

=item * Adaptor Writing Info

The aliases_get_rows is used (initially at least) for feature search.  It appends, to the results, feature information for aliases that match the feature_name value.  If there is no feature name supplied, it will repeat the feature info for each alias the identified features have.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - Feature ID (feature_id)

=item - Feature Accession (feature_aid)

=item - Feature Name (feature_name)

=item - Map ID (map_id)

=item - map_aid (map_aid)

=item - Map Set ID (map_set_id)

=item - List of Map Set IDs (map_set_ids)

=item - feature_start (feature_start)

=item - feature_stop (feature_stop)

=item - Direction (direction)

=item - Allowed feature types (feature_type_aids)

=item - Species ID (species_id)

=item - List of Species IDs (species_ids)

=item - List of Species Accessions (species_aids)

=item - Map Start and Map Stop (map_start,map_stop)

These must both be defined in order to to be used.  If defined the method will
return only features that overlap that region.

=item - Aliases get own rows (aliases_get_rows)

Value that dictates if aliases that match get there own rows.  This is mostly
usefull for feature_name searches.

=back

=item * Output

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
    is_relational_map,
    map_type_aid,
    map_units,
    species_id,
    species_aid
    species_common_name,
    feature_type,
    default_rank,
    aliases - a list of aliases (Unless $aliases_get_rows is specified),


=item * Cache Level (If Used): 3

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;

    my $cmap_object   = $args{'cmap_object'} or die "No CMap Object included";
    my $feature_id    = $args{'feature_id'};
    my $feature_aid   = $args{'feature_aid'};
    my $feature_name  = $args{'feature_name'};
    my $map_id        = $args{'map_id'};
    my $map_aid       = $args{'map_aid'};
    my $map_set_id    = $args{'map_set_id'};
    my $map_set_ids   = $args{'map_set_ids'} || [];
    my $feature_start = $args{'feature_start'};
    my $feature_stop  = $args{'feature_stop'};
    my $direction     = $args{'direction'};
    my $map_start     = $args{'map_start'};
    my $map_stop      = $args{'map_stop'};
    my $feature_type_aids = $args{'feature_type_aids'} || [];
    my $species_id        = $args{'species_id'};
    my $species_ids       = $args{'species_ids'} || [];
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
                ms.is_relational_map,
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
          " and f.feature_type_accession in ('"
          . join( "','", sort @$feature_type_aids ) . "')";
    }

    if ( defined($feature_start) ) {
        push @identifiers, $feature_start;
        $where_sql .= " and f.start_position = ? ";
    }
    if ( defined($feature_stop) ) {
        push @identifiers, $feature_stop;
        $where_sql .= " and f.stop_position = ? ";

    }
    if ( defined($direction) ) {
        push @identifiers, $direction;
        $where_sql .= " and f.direction = ? ";
    }
    if ($species_id) {
        push @identifiers, $species_id;
        $where_sql .= " and s.species_id = ? ";

    }
    elsif ( $species_ids and @$species_ids ) {
        $where_sql .=
          " and s.species_id in ('" . join( "','", sort @$species_ids ) . "')";
    }
    elsif ( $species_aids and @$species_aids ) {
        $where_sql .=
          " and s.accession_id in ('"
          . join( "','", sort @$species_aids ) . "')";
    }

    # add the were clause for each possible identifier
    if ($feature_id) {
        push @identifiers, $feature_id;
        $where_sql .= " and f.feature_id = ? ";
    }
    elsif ($feature_aid) {
        my $comparison = $feature_name =~ m/%/ ? 'like' : '=';
        if ( $feature_name ne '%' ) {
            push @identifiers, $feature_aid;
            $where_sql .= " and f.accession_id $comparison ? ";
        }
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
    elsif (@$map_set_ids) {
        $where_sql .=
          " and map.map_set_id in ('"
          . join( "','", sort @$map_set_ids ) . "')";
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
sub get_features_simple {    #ZZZ

=pod

=head2 get_features_simple()

=over 4

=item * Description

Get just the info from the features.  This is less data than
get_features() provides and doesn't involve any table joins.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - Map ID (map_id)

=item - Feature ID (feature_id)

=item - Feature Accession (feature_aid)

=item - Feature Name (feature_name)

=item - Feature Type Accession (feature_type_aid)

=back

=item * Output

Array of Hashes:

  Keys:
    feature_id
    accession_id
    feature_name
    is_landmark
    start_position
    stop_position
    feature_type_aid
    default_rank
    direction

=item * Cache Level (If Used): 3

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object  = $args{'cmap_object'} or die "No CMap Object included";
    my $map_id       = $args{'map_id'};
    my $feature_id   = $args{'feature_id'};
    my $feature_aid  = $args{'feature_aid'};
    my $feature_name = $args{'feature_name'};
    my $feature_type_aid = $args{'feature_type_aid'};
    my $db               = $cmap_object->db;
    my $return_object;
    my $sql_str = qq[
         select feature_id,
               accession_id,
               feature_name,
               is_landmark,
               start_position,
               stop_position,
               feature_type_accession as feature_type_aid,
               default_rank,
               direction
        from   cmap_feature
    ];
    my $where_sql = '';

    if ($feature_id) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " feature_id = $feature_id ";
    }
    elsif ($feature_aid) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " accession_id = '$feature_aid' ";
    }
    if ($map_id) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map_id = $map_id ";
    }
    if ($feature_name) {
        my $comparison = $feature_name =~ m/%/ ? 'like' : '=';
        if ( $feature_name ne '%' ) {
            $feature_name = uc $feature_name;
            $where_sql .= $where_sql ? " and " : " where ";
            $where_sql .= " upper(f.feature_name) $comparison '$feature_name' ";
        }
    }
    if ($feature_type_aid) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " feature_type_accession = '$feature_type_aid' ";
    }

    $sql_str .= $where_sql;
    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );

    return $return_object;
}

#-----------------------------------------------
sub get_feature_bounds_on_map {    #ZZZ

=pod

=head2 get_feature_bounds_on_map()

=over 4

=item * Description

Given a map id, give the bounds of where features lie.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Map ID (map_id)

=back

=item * Output

list ( $min_start, $max_start, $max_stop )

=item * Cache Level (If Used): 3

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $map_id      = $args{'map_id'};
    my $db          = $cmap_object->db;

    my ( $min_start, $max_start, $max_stop ) = $db->selectrow_array(
        q[
            select   min(f.start_position),
                     max(f.start_position),
                     max(f.stop_position)
            from     cmap_feature f
            where    f.map_id=?
            group by f.map_id
        ],
        {},
        ($map_id)
    );

    return ( $min_start, $max_start, $max_stop );
}

#-----------------------------------------------
sub get_features_for_correspondence_making {    #ZZZ

=pod

=head2 get_features_for_correspondence_making()

=over 4

=item * Description

Get feature information for creating correspondences.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - List of Map Set IDs (map_set_ids)

=item - ignore_feature_type_aids (ignore_feature_type_aids)

=back

=item * Output

Array of Hashes:

  Keys:
    feature_id
    feature_name
    feature_type_aid

=item * Cache Level (If Used): 3

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $map_set_ids              = $args{'map_set_ids'}              || [];
    my $ignore_feature_type_aids = $args{'ignore_feature_type_aids'} || [];
    my $db                       = $cmap_object->db;
    my $return_object;

    my $sql_str = q[
        select f.feature_id,
               f.feature_name,
               f.feature_type_accession as feature_type_aid
        from   cmap_feature f,
               cmap_map map
        where  f.map_id=map.map_id
    ];

    if (@$map_set_ids) {
        $sql_str .=
          " and map.map_set_id in (" . join( ",", sort @$map_set_ids ) . ") ";
    }
    if (@$ignore_feature_type_aids) {
        $sql_str .=
          " and f.feature_type_accession not in ('"
          . join( "','", sort @$ignore_feature_type_aids ) . "') ";
    }

    $return_object = $db->selectall_hashref( $sql_str, 'feature_id' );

    return $return_object;
}

#-----------------------------------------------
sub slot_data_features {    #ZZZ

=pod

=head2 slot_data_features()

=over 4

=item * Description

This is a method specifically for Data->slot_data() to call, since it will be called multiple times in most map views.  It does only what Data->slot_data() needs it to do and nothing more. 

It takes into account the corr_only_feature_types, returning only those types with displayed correspondences. 

The way it works, is that it creates one sql query for those types that will always be displayed ($included_feature_type_aids) and a separate query for those types that need a correpsondence in order to be displayed ($corr_only_feature_type_aids).  Then it unions them together.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - The "slot_info" object (slot_info)

 Structure:
    { 
      slot_no => {
        map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ],
      }
    }

=item - Slot number (this_slot_no)

=back

=item * Optional Input

=over 4

=item - Map ID (map_id)

=item - Map Start (map_start)

=item - Map Stop (map_stop)

=item - Included Feature Type Accessions (included_feature_type_aids)

List of feature type aids that will be displayed even if they don't have
correspondences.

=item - Ignored Feature Type Accessions (ingnored_feature_type_aids)

List of feature type aids that will not be displayed.

=item - Correspondence Only Feature Type Accessions (corr_only_feature_type_aids)

List of feature type aids that will be displayed ONLY if they have
correspondences.

=item - show_intraslot_corr (show_intraslot_corr)

Boolean value to check if intraslot correspondences count when deciding to
display a corr_only feature.

=back

=item * Output

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

=item * Cache Level: 4

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $slot_info   = $args{'slot_info'}   or die "no slot info supplied.";
    my $map_id      = $args{'map_id'};
    my $map_start   = $args{'map_start'};
    my $map_stop    = $args{'map_stop'};
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
sub get_feature_count {    #ZZZ

=pod

=head2 get_feature_count()

=over 4

=item * Description

=item * Adaptor Writing Info

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - group_by_map_id (group_by_map_id)

=item - group_by_feature_type (group_by_feature_type)

=item - The "slot_info" object (this_slot_info)

 Structure:
    { 
      slot_no => {
        map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ],
      }
    }

=item - List of Map IDs (map_ids)

=item - Map ID (map_id)

=item - Map Name (map_name)

=item - Map Set ID (map_set_id)

=back

=item * Output

Array of Hashes:

  Keys:
    feature_count
    map_id (only if $group_by_map_id)
    feature_type_aid (only if $group_by_feature_type)

=item * Cache Level (If Used): 

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $group_by_map_id = $args{'group_by_map_id'};
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
sub insert_feature {    #ZZZ

=pod

=head2 insert_feature()

=over 4

Insert a feature into the database.

=item * Description

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Feature Accession (feature_aid)

=item - Map ID (map_id)

=item - Feature Type Accession (feature_type_aid)

=item - Feature Name (feature_name)

=item - is_landmark (is_landmark)

=item - start_position (start_position)

=item - stop_position (stop_position)

=item - default_rank (default_rank)

=item - Direction (direction)

=item - gclass (gclass)

=item - threshold (threshold)

=back

=item * Output

Feature id

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $feature_aid      = $args{'feature_aid'} || $args{'accession_id'};
    my $map_id           = $args{'map_id'};
    my $feature_type_aid = $args{'feature_type_aid'};
    my $feature_name     = $args{'feature_name'};
    my $is_landmark      = $args{'is_landmark'};
    my $start_position   = $args{'start_position'};
    my $stop_position    = $args{'stop_position'};
    my $default_rank     = $args{'default_rank'};
    my $direction        = $args{'direction'};
    my $gclass           = $args{'gclass'};
    my $threshold        = $args{'threshold'} || 0;
    my $db               = $cmap_object->db;

    $gclass = undef unless ( $cmap_object->config_data('gbrowse_compatible') );

    $stop_position = $start_position unless ( defined($stop_position) );

    if ($feature_type_aid) {
        push @{ $self->{'insert_features'} },
          [
            $feature_aid,   $map_id,       $feature_type_aid,
            $feature_name,  $is_landmark,  $start_position,
            $stop_position, $default_rank, $direction
          ];
        push @{ $self->{'insert_features'}[-1] }, $gclass
          if ($gclass);
    }

    if (    scalar( @{ $self->{'insert_features'} } ) >= $threshold
        and scalar( @{ $self->{'insert_features'} } ) )
    {
        my $no_features     = scalar( @{ $self->{'insert_features'} } );
        my $base_feature_id = $self->next_number(
            cmap_object => $cmap_object,
            object_type => 'feature',
            requested   => scalar( @{ $self->{'insert_features'} } )
          )
          or return $self->error('No next number for feature ');
        my $sth;
        if ($gclass) {
            $sth = $db->prepare(
                qq[
                    insert into cmap_feature
                    (
                        feature_id,
                        accession_id,
                        map_id,
                        feature_type_accession,
                        feature_name,
                        is_landmark,
                        start_position,
                        stop_position,
                        default_rank,
                        direction,
                        gclass
                     )
                     values ( ?,?,?,?,?,?,?,?,?,?,? )
                    ]
            );
        }
        else {
            $sth = $db->prepare(
                qq[
                    insert into cmap_feature
                    (
                        feature_id,
                        accession_id,
                        map_id,
                        feature_type_accession,
                        feature_name,
                        is_landmark,
                        start_position,
                        stop_position,
                        default_rank,
                        direction 
                     )
                     values ( ?,?,?,?,?,?,?,?,?,? )
                    ]
            );
        }
        for ( my $i = 0 ; $i < $no_features ; $i++ ) {
            my $feature_id = $base_feature_id + $i;
            $self->{'insert_features'}[$i][0] ||= $feature_id;
            $sth->execute( $feature_id, @{ $self->{'insert_features'}[$i] } );
        }
        $self->{'insert_features'} = [];
        return $base_feature_id + $no_features - 1;
    }
    return undef;
}

#-----------------------------------------------
sub update_feature {    #ZZZ

=pod

=head2 update_feature()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

If you don't want CMap to update into your database, make this a dummy method.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Feature ID (feature_id)

=back

=item * Inputs To Update

=over 4

=item - Feature Accession (feature_aid)

=item - Map ID (map_id)

=item - Feature Type Accession (feature_type_aid)

=item - Feature Name (feature_name)

=item - is_landmark (is_landmark)

=item - start_position (start_position)

=item - stop_position (stop_position)

=item - default_rank (default_rank)

=item - Direction (direction)

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $feature_id  = $args{'feature_id'}  || $args{'object_id'} or return;
    my $feature_aid = $args{'feature_aid'} || $args{'accession_id'};
    my $map_id      = $args{'map_id'};
    my $feature_type_aid = $args{'feature_type_aid'};
    my $feature_name     = $args{'feature_name'};
    my $is_landmark      = $args{'is_landmark'};
    my $start_position   = $args{'start_position'};
    my $stop_position    = $args{'stop_position'};
    my $default_rank     = $args{'default_rank'};
    my $direction        = $args{'direction'};
    my $db               = $cmap_object->db;

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_feature
    ];
    my $set_sql   = '';
    my $where_sql = " where feature_id = ? ";    # ID

    if ($feature_aid) {
        push @update_args, $feature_aid;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " accession_id = ? ";
    }
    if ($map_id) {
        push @update_args, $map_id;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " map_id = ? ";
    }
    if ($feature_type_aid) {
        push @update_args, $feature_type_aid;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " feature_type_accession = ? ";
    }
    if ($feature_name) {
        push @update_args, $feature_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " feature_name = ? ";
    }
    if ($is_landmark) {
        push @update_args, $is_landmark;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " is_landmark = ? ";
    }
    if ($start_position) {
        push @update_args, $start_position;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " start_position = ? ";
    }
    if ($stop_position) {
        push @update_args, $stop_position;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " stop_position = ? ";
    }
    if ($default_rank) {
        push @update_args, $default_rank;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " default_rank = ? ";
    }
    if ($direction) {
        push @update_args, $direction;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " direction = ? ";
    }

    push @update_args, $feature_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_feature {    #ZZZ

=pod

=head2 delete_feature()

=over 4

=item * Description

Given the id or a map id, delete the objects.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Requred Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Requred At Least One Input

=over 4

=item - Feature ID (feature_id)

=item - Map ID (map_id)

=back

=item * Output

1

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $db          = $cmap_object->db;
    my $feature_id  = $args{'feature_id'};
    my $map_id      = $args{'map_id'};
    my @delete_args = ();
    my $delete_sql  = qq[
        delete from cmap_feature
    ];
    my $where_sql = '';

    if ($feature_id) {
        push @delete_args, $feature_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " feature_id = ? ";
    }
    if ($map_id) {
        push @delete_args, $map_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " map_id = ? ";
    }

    return unless ($where_sql);
    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
}

=pod

=head1 Feature Alias Methods

=cut 

#-----------------------------------------------
sub get_feature_aliases {    #ZZZ

=pod

=head2 get_feature_aliases()

=over 4

=item * Description

Gets aliases for features identified by the identification fields.  One row per
alias.

=item * Adaptor Writing Info

If Map information is part of the input, then the map tables need to be brought into the query.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - Feature ID (feature_id)

=item - feature_alias_id (feature_alias_id)

=item - List of Feature IDs (feature_ids)

=item - Feature Accession (feature_aid)

=item - alias (alias)

=item - Map ID (map_id)

=item - map_aid (map_aid)

=item - Map Set ID (map_set_id)

=item - List of Map Set IDs (map_set_ids)

=item - ignore_feature_type_aids (ignore_feature_type_aids)

=back

=item * Output

Array of Hashes:

  Keys:
    feature_alias_id,
    alias,
    feature_id,
    feature_aid,
    feature_name


=item * Cache Level (Not Used): 3

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $feature_id = $args{'feature_id'};
    my $feature_alias_id         = $args{'feature_alias_id'};
    my $feature_ids              = $args{'feature_ids'} || [];
    my $feature_aid              = $args{'feature_aid'};
    my $alias                    = $args{'alias'};
    my $map_id                   = $args{'map_id'};
    my $map_aid                  = $args{'map_aid'};
    my $map_set_id               = $args{'map_set_id'};
    my $map_set_ids              = $args{'map_set_ids'} || [];
    my $ignore_feature_type_aids = $args{'ignore_feature_type_aids'} || [];
    my $db                       = $cmap_object->db;
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
    if ($feature_alias_id) {
        push @identifiers, $feature_alias_id;
        $where_sql .= " and fa.feature_alias_id = ? ";
    }
    elsif (@$feature_ids) {
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
    elsif (@$map_set_ids) {
        $from_sql  .= ", cmap_map map ";
        $where_sql .=
          " and map.map_set_id in (" . join( ",", sort @$map_set_ids ) . ") ";
    }
    if (@$ignore_feature_type_aids) {
        $where_sql .=
          " and f.feature_type_accession not in ('"
          . join( "','", sort @$ignore_feature_type_aids ) . "') ";
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
sub insert_feature_alias {    #ZZZ

=pod

=head2 insert_feature_alias()

=over 4

=item * Description

Insert a feature alias into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Feature ID (feature_id)

=item - alias (alias)

=back

=item * Output

feature_alias_id

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $feature_id  = $args{'feature_id'};
    my $alias       = $args{'alias'};
    my $db          = $cmap_object->db;
    my $feature_alias_id = $self->next_number(
        cmap_object => $cmap_object,
        object_type => 'feature_alias',
      )
      or return $self->error('No next number for feature_alias ');
    my @insert_args = ( $feature_alias_id, $feature_id, $alias );

    $db->do(
        qq[
        insert into cmap_feature_alias
        (feature_alias_id,feature_id,alias )
         values ( ?,?,? )
        ],
        {},
        (@insert_args)
    );

    return $feature_alias_id;
}

#-----------------------------------------------
sub update_feature_alias {    #ZZZ

=pod

=head2 update_feature_alias()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

If you don't want CMap to update into your database, make this a dummy method.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - feature_alias_id (feature_alias_id)

=back

=item * Inputs To Update

=over 4

=item - alias (alias)

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $feature_alias_id = $args{'feature_alias_id'} || $args{'object_id'}
      or return;
    my $alias = $args{'alias'};
    my $db    = $cmap_object->db;

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_feature_alias
    ];
    my $set_sql   = '';
    my $where_sql = " where = ? ";    # ID

    if ($alias) {
        push @update_args, $alias;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " alias = ? ";
    }

    push @update_args, $feature_alias_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_feature_alias {    #ZZZ

=pod

=head2 delete_feature_alias()

=over 4

=item * Description

Given the id or a feature id, delete the objects.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Requred At Least One Input

=over 4

=item - feature_alias_id (feature_alias_id)

=item - Feature ID (feature_id)

=back

=item * Output

1

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $db = $cmap_object->db;
    my $feature_alias_id = $args{'feature_alias_id'};
    my $feature_id       = $args{'feature_id'};
    my @delete_args      = ();
    my $delete_sql       = qq[
        delete from cmap_feature_alias
    ];
    my $where_sql = '';

    if ($feature_alias_id) {
        push @delete_args, $feature_alias_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " feature_alias_id = ? ";
    }
    if ($feature_id) {
        push @delete_args, $feature_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " feature_id = ? ";
    }

    return unless ($where_sql);
    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return $feature_id;
}

=pod

=head1 Feature Correspondence Methods

=cut 

#-----------------------------------------------
sub get_feature_correspondences {    #ZZZ

=pod

=head2 get_feature_correspondences()

=over 4

=item * Description

Get the correspondence information based on the accession id.

This is very similar to get_feature_correspondences_simple.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Required At Least One Of These Input

=over 4

=item - Correspondence ID (feature_correspondence_id)

=item - Correspondence Accession (feature_correspondence_aid)

=back

=item * Output

Hash:

  Keys:
    feature_correspondence_id,
    feature_correspondence_aid,
    feature_id1,
    feature_id2,
    is_enabled

=item * Cache Level (Not Used): 4

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
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
sub get_feature_correspondence_details {    #ZZZ

=pod

=head2 get_feature_correspondence_details()

=over 4

=item * Description

return many details about the correspondences of a feature.

=item * Adaptor Writing Info

If disregard_evidence_type is not true AND no evidence type info is given, return [].

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - feature_correspondence_id (feature_correspondence_id)

=item - feature_id1 (feature_id1)

=item - feature_id2 (feature_id2)

=item - map_set_id2 (map_set_id2)

=item - map_set_aid2 (map_set_aid2)

=item - map_aid2 (map_aid2)

=item - disregard_evidence_type (disregard_evidence_type)

=back

=item * Required if disregard_evidence_type is true

=over 4

=item - Included Evidence Types Accessions (included_evidence_type_aids)

=item - Ev. types that must be less than score (less_evidence_type_aids)

=item - Ev. types that must be greater than score (greater_evidence_type_aids)

=item - Scores for comparing to evidence types (evidence_type_score)

=back

=item * Output

Array of Hashes:

  Keys:
    feature_name2
    feature_id2
    feature_id2
    feature_aid1
    feature_aid2
    start_position2
    stop_position2
    feature_type_aid2
    map_id2
    map_aid2
    map_name2
    map_display_order2
    map_set_id2
    map_set_aid2
    map_set_short_name2
    ms_display_order2
    published_on2
    map_type_aid2
    map_units2
    species_common_name2
    species_display_order2
    feature_correspondence_id
    feature_correspondence_aid
    is_enabled
    evidence_type_aid
    map_type2
    feature_type2
    evidence_type

=item * Cache Level (Not Used): 4

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $feature_correspondence_id   = $args{'feature_correspondence_id'};
    my $feature_id1                 = $args{'feature_id1'};
    my $feature_id2                 = $args{'feature_id2'};
    my $map_set_id2                 = $args{'map_set_id2'};
    my $map_set_aid2                = $args{'map_set_aid2'};
    my $map_aid2                    = $args{'map_aid2'};
    my $included_evidence_type_aids = $args{'included_evidence_type_aids'}
      || [];
    my $less_evidence_type_aids    = $args{'less_evidence_type_aids'}    || [];
    my $greater_evidence_type_aids = $args{'greater_evidence_type_aids'} || [];
    my $evidence_type_score        = $args{'evidence_type_score'}        || {};
    my $disregard_evidence_type    = $args{'disregard_evidence_type'}    || 0;
    my $db                         = $cmap_object->db;
    my $map_type_data              = $cmap_object->map_type_data();
    my $feature_type_data          = $cmap_object->feature_type_data();
    my $evidence_type_data         = $cmap_object->evidence_type_data();
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

    if ($feature_correspondence_id) {
        $sql_str .=
          " and cl.feature_correspondence_id=$feature_correspondence_id ";
    }
    if ($feature_id1) {
        $sql_str .= " and cl.feature_id1=$feature_id1 ";
    }
    if ($feature_id2) {
        $sql_str .= " and cl.feature_id2=$feature_id2 ";
    }

    if ($map_set_id2) {
        $sql_str .= " and map2.map_set_id='" . $map_set_id2 . "' ";
    }
    elsif ($map_set_aid2) {
        $sql_str .= " and ms2.accession_id='" . $map_set_aid2 . "' ";
    }
    elsif ($map_aid2) {
        $sql_str .= " and map2.accession_id='" . $map_aid2 . "' ";
    }

    if (
        !$disregard_evidence_type
        and (  @$included_evidence_type_aids
            or @$less_evidence_type_aids
            or @$greater_evidence_type_aids )
      )
    {
        $sql_str .= " and ( ";
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

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );

    foreach my $row ( @{$return_object} ) {
        $row->{'map_type2'} =
          $map_type_data->{ $row->{'map_type_aid2'} }{'map_type'};
        $row->{'feature_type2'} =
          $feature_type_data->{ $row->{'feature_type_aid2'} }{'feature_type'};
        $row->{'evidence_type'} =
          $evidence_type_data->{ $row->{'evidence_type_aid'} }{'evidence_type'};
    }
    return $return_object;
}

#-----------------------------------------------
sub get_feature_correspondences_simple {    #ZZZ

=pod

=head2 get_feature_correspondences_simple()

=over 4

=item * Description

Get just the info from the correspondences.  This is less data than
get_correspondences() provides and doesn't involve any table joins.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - feature_correspondence_id (feature_correspondence_id)

=item - map_set_ids1 (map_set_ids1)

=item - map_set_ids2 (map_set_ids2)

=back

=item * Output

Array of Hashes:

  Keys:
    feature_correspondence_id
    accession_id
    is_enabled
    feature_aid1
    feature_aid2

=item * Cache Level (If Used): 4

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $feature_correspondence_id = $args{'feature_correspondence_id'};
    my $map_set_ids1              = $args{'map_set_ids1'} || [];
    my $map_set_ids2              = $args{'map_set_ids2'} || [];
    my $db                        = $cmap_object->db;
    my $return_object;

    my $sql_str = q[
        select fc.feature_correspondence_id,
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

    if ($feature_correspondence_id) {
        $sql_str .=
          " and fc.feature_correspondence_id = $feature_correspondence_id ";
    }
    if (@$map_set_ids1) {
        $sql_str .=
          " and map1.map_set_id in (" . join( ",", sort @$map_set_ids1 ) . ") ";
    }

    if (@$map_set_ids2) {
        $sql_str .=
          " and map2.map_set_id in (" . join( ",", sort @$map_set_ids2 ) . ") ";
    }

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );

    return $return_object;
}

#-----------------------------------------------
sub get_feature_correspondences_by_maps {    #ZZZ

=pod

=head2 get_feature_correspondences_by_maps()

=over 4

Gets corr

=item * Description

Given a map and a set of reference maps, this will return the correspondences between the two.

=item * Adaptor Writing Info

If no evidence types are supplied in
included_evidence_type_aids,less_evidence_type_aids or
greater_evidence_type_aids assume that all are ignored and return empty hash.

If the $intraslot variable is set to one, compare the maps in the $ref_map_info
against each other, instead of against the map_id.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - The "slot_info" of the reference maps (ref_map_info)

 Structure:
    {
      map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ],
    }

=back

=item * Optional Input

=over 4

=item - Map id of the comparative map (map_id) 

Required if not intraslot

=item - Comp map Start (map_start)

=item - Comp map stop (map_stop)

=item - Included Evidence Types Accessions (included_evidence_type_aids)

=item - Ev. types that must be less than score (less_evidence_type_aids)

=item - Ev. types that must be greater than score (greater_evidence_type_aids)

=item - Scores for comparing to evidence types (evidence_type_score)

=item - Allowed feature types (feature_type_aids)

=item - Is intraslot? (intraslot)

Set to one to get correspondences between maps in the same slot.

=back

=item * Output

Array of Hashes:

  Keys:
    feature_id, 
    ref_feature_id,
    feature_correspondence_id,
    evidence_type_aid,
    evidence_type,
    line_color,
    evidence_rank,


=item * Cache Level: 4

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";

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
        $sql_str .= " and ( ";
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
sub get_feature_correspondence_count {    #ZZZ

=pod

=head2 get_feature_correspondence_count()

=over 4

=item * Description

This is a complicated little method.  It returns correspondence counts used
when aggregating.  If $split_evidence_types then the evidence type accessions
are used to split the counts, otherwise the
DEFAULT->{'aggregated_type_substitute'} is used as a place holder.  If clustering, don't actually
do the counts in the sql.

=item * Adaptor Writing Info

There are two inputs that change the output.  

$split_evidence_types splits the results into the different evidence types,
otherwise they are all grouped together (with a place holder value
DEFAULT->{'aggregated_type_substitute'}).

If $cluster is true, no counts are taken and the start and stops are returned
for each correspondence.  This way the main code can handle clustering any way
it wants.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - The "slot_info" object (slot_info)

 Structure:
    { 
      slot_no => {
        map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ],
      }
    }

=item - The "slot_info" object (slot_info2)

 Structure:
    { 
      slot_no => {
        map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ],
      }
    }

=back

=item * Optional Input

=over 4

=item - clustering (clustering)

=item - split_evidence_types (split_evidence_types)

=item - show_intraslot_corr (show_intraslot_corr)

=item - List of Map Accessions (map_aids)

=item - List of Map Accessions to Ignore (ignore_map_aids)

=item - Included Evidence Types Accessions (included_evidence_type_aids)

=item - Ignored Evidence Type Accessions (ignored_evidence_type_aids)

=item - Ev. types that must be less than score (less_evidence_type_aids)

=item - Ev. types that must be greater than score (greater_evidence_type_aids)

=item - Scores for comparing to evidence types (evidence_type_score)

=item - Feature Type Accessions to ignore (ignored_feature_type_aids)

=back

=item * Output

Array of Hashes:

If Not $cluster

  Keys:
    map_id1
    map_id2
    evidence_type_aid
    no_corr
    min_start2
    max_start2
    avg_mid2
    start_avg2
    start_avg1
    min_start1
    max_start1
    avg_mid1



If $cluster

  Keys:
    map_id1
    map_id2
    evidence_type_aid
    start_position1
    stop_position1
    start_position2
    stop_position2


=item * Cache Level: 4 

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $clustering = $args{'clustering'};
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
                and defined($this_stop) )
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
sub get_comparative_maps_with_count {    #ZZZ

=pod

=head2 get_comparative_maps_with_count()

=over 4

=item * Description

Gets the comparative maps and includes a count of the number of features.

=item * Adaptor Writing Info

If $include_map1_data is true, then also include information about the starting
map (map1).

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - Minimum number of correspondences (min_correspondences)

=item - The "slot_info" object (slot_info)

 Structure:
    { 
      slot_no => {
        map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ],
      }
    }

=item - List of Map Accessions (map_aids)

=item - List of Map Accessions to Ignore (ignore_map_aids)

=item - Included Evidence Types Accessions (included_evidence_type_aids)

=item - Ignored Evidence Type Accessions (ignored_evidence_type_aids)

=item - Ev. types that must be less than score (less_evidence_type_aids)

=item - Ev. types that must be greater than score (greater_evidence_type_aids)

=item - Scores for comparing to evidence types (evidence_type_score)

=item - Feature Type Accessions to ignore (ignored_feature_type_aids)

=item - Boolean value include_map1_data (include_map1_data)

If information about the starting map is desired, set include_map1_data to
true.

=back

=item * Output

Array of Hashes:

  Keys:
    no_corr
    map_id2
    map_aid2
    map_set_id2

If $include_map1_data also has

     map_id1
     map_aid1
     map_set_id1

=item * Cache Level: 4

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
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
sub get_feature_correspondence_count_for_feature {    #ZZZ

=pod

=head2 get_feature_correspondence_counts_for_feature()

=over 4

=item * Description

Return the number of correspondences that a feature has.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Feature ID (feature_id)

=back

=item * Output

Count

=item * Cache Level (Not Used): 4

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $feature_id  = $args{'feature_id'}  or die "No feature id given";
    my $db          = $cmap_object->db;
    my $return_object;

    my $sql_str = q[
        select count(fc.feature_correspondence_id)
        from   cmap_correspondence_lookup cl,
               cmap_feature_correspondence fc
        where  cl.feature_id1=?
        and    cl.feature_correspondence_id=
               fc.feature_correspondence_id
    ];

    $return_object = $db->selectrow_array( $sql_str, {}, $feature_id );

    return $return_object;
}

#-----------------------------------------------
sub insert_feature_correspondence {    #ZZZ

=pod

=head2 insert_feature_correspondence()

=over 4

=item * Description

Insert a feature correspondence into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - feature_id1 (feature_id1)

=item - feature_id2 (feature_id2)

=item - feature_aid1 (feature_aid1)

=item - feature_aid2 (feature_aid2)

=item - Boolean: Is this enabled (is_enabled)

=item - evidence_type_aid (evidence_type_aid)

=item - evidence (evidence)

=item - feature_correspondence_aid (feature_correspondence_aid)

=item - score (score)

=item - threshold (threshold)

=back

=item * Output

Feature Correspondence id

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object  = $args{'cmap_object'} or die "No CMap Object included";
    my $feature_id1  = $args{'feature_id1'};
    my $feature_id2  = $args{'feature_id2'};
    my $feature_aid1 = $args{'feature_aid1'};
    my $feature_aid2 = $args{'feature_aid2'};
    my $is_enabled   = $args{'is_enabled'};
    $is_enabled = 1 unless ( defined($is_enabled) );
    my $evidence_type_aid = $args{'evidence_type_aid'};
    my $evidence = $args{'evidence'} || $args{'correspondence_evidence'} || [];
    my $feature_correspondence_aid = $args{'feature_correspondence_aid'}
      || $args{'accession_id'};
    my $score = $args{'score'};

    my $threshold = $args{'threshold'} || 0;
    my $db        = $cmap_object->db;

    if ( !$feature_id1 and $feature_aid1 ) {
        $feature_id1 = $self->acc_id_to_internal_id(
            cmap_object => $cmap_object,
            acc_id      => $feature_aid1,
            object_type => 'feature',
        );
    }
    if ( !$feature_id2 and $feature_aid2 ) {
        $feature_id2 = $self->acc_id_to_internal_id(
            cmap_object => $cmap_object,
            acc_id      => $feature_aid2,
            object_type => 'feature',
        );
    }

    if ($evidence_type_aid) {
        push @$evidence,
          {
            evidence_type_aid => $evidence_type_aid,
            score             => $score,
          };
    }

    if ($feature_id1) {
        push @{ $self->{'insert_correspondences'} },
          [
            $feature_correspondence_aid,
            $feature_id1, $feature_id2, $is_enabled, $evidence
          ];
    }

    my $base_corr_id;
    if (    scalar( @{ $self->{'insert_correspondences'} || [] } ) >= $threshold
        and scalar( @{ $self->{'insert_correspondences'} || [] } ) )
    {
        my $no_correspondences =
          scalar( @{ $self->{'insert_correspondences'} } );
        my $base_corr_id = $self->next_number(
            cmap_object => $cmap_object,
            object_type => 'feature_correspondence',
            requested   => $no_correspondences,
          )
          or die 'No next number for correspondence ';
        my $sth_fc = $db->prepare(
            qq[
                insert into cmap_feature_correspondence
                (
                    feature_correspondence_id,
                    accession_id,
                    feature_id1,
                    feature_id2,
                    is_enabled
                 )
                 values ( ?,?,?,?,? )
                ]
        );
        my $sth_cl = $db->prepare(
            qq[
                insert into cmap_correspondence_lookup
                (
                    feature_correspondence_id,
                    feature_id1,
                    feature_id2,
                    start_position1,
                    start_position2,
                    stop_position1,
                    stop_position2,
                    map_id1,
                    map_id2,
                    feature_type_accession1,
                    feature_type_accession2
                 )
                 values ( ?,?,?,?,?,?,?,?,?,?,? )
                ]
        );
        my (
            $corr_id,     $corr_aid,   $feature_id1,
            $feature_id2, $is_enabled, $evidences
        );
        for ( my $i = 0 ; $i < $no_correspondences ; $i++ ) {
            my $corr_id = $base_corr_id + $i;
            ( $corr_aid, $feature_id1, $feature_id2, $is_enabled, $evidences ) =
              @{ $self->{'insert_correspondences'}[$i] };
            $corr_aid ||= $corr_id;

            my $feature1 = $self->get_features(
                cmap_object => $cmap_object,
                feature_id  => $feature_id1,
            );
            $feature1 = $feature1->[0] if $feature1;
            my $feature2 = $self->get_features(
                cmap_object => $cmap_object,
                feature_id  => $feature_id2,
            );
            $feature2 = $feature2->[0] if $feature2;

            #
            # Don't create correspondences among relational maps.
            #
            return -1
              if $feature1->{'map_set_id'} == $feature2->{'map_set_id'}
              && $feature1->{'is_relational_map'} == 1;

            #
            # Don't create correspondences among relational map sets.
            #
            return -1
              if $feature1->{'is_relational_map'}
              && $feature2->{'is_relational_map'};

            $sth_fc->execute(
                $corr_id,     $corr_aid, $feature_id1,
                $feature_id2, $is_enabled
            );

            $sth_cl->execute(
                $corr_id,
                $feature_id1,
                $feature_id2,
                $feature1->{'start_position'},
                $feature2->{'start_position'},
                $feature1->{'stop_position'},
                $feature2->{'stop_position'},
                $feature1->{'map_id'},
                $feature2->{'map_id'},
                $feature1->{'feature_type_aid'},
                $feature2->{'feature_type_aid'},

            );
            $sth_cl->execute(
                $corr_id,
                $feature_id2,
                $feature_id1,
                $feature2->{'start_position'},
                $feature1->{'start_position'},
                $feature2->{'stop_position'},
                $feature1->{'stop_position'},
                $feature2->{'map_id'},
                $feature1->{'map_id'},
                $feature2->{'feature_type_aid'},
                $feature1->{'feature_type_aid'},

            );

            # Deal with Evidence
            foreach my $evidence (@$evidences) {
                $self->insert_correspondence_evidence(
                    cmap_object               => $cmap_object,
                    feature_correspondence_id => $corr_id,
                    evidence_type_aid => $evidence->{'evidence_type_aid'},
                    score             => $evidence->{'score'},
                );
            }
        }
        $self->{'insert_correspondences'} = [];
        return $base_corr_id + $no_correspondences - 1;
    }
    return undef;
}

#-----------------------------------------------
sub update_feature_correspondence {    #ZZZ

=pod

=head2 update_feature_correspondence()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

If you don't want CMap to update into your database, make this a dummy method.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - feature_correspondence_id (feature_correspondence_id)

=back

=item * Inputs To Update

=over 4

=item - feature_correspondence_aid (feature_correspondence_aid)

=item - Boolean: Is this enabled (is_enabled)

=item - feature_id1 (feature_id1)

=item - feature_id2 (feature_id2)

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $feature_correspondence_id = $args{'feature_correspondence_id'}
      || $args{'object_id'}
      or return;
    my $feature_correspondence_aid = $args{'feature_correspondence_aid'}
      || $args{'accession_id'};
    my $is_enabled  = $args{'is_enabled'};
    my $feature_id1 = $args{'feature_id1'};
    my $feature_id2 = $args{'feature_id2'};
    my $db          = $cmap_object->db;

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_feature_correspondence
    ];
    my $set_sql   = '';
    my $where_sql = " where feature_correspondence_id = ? ";    # ID

    if ($feature_correspondence_aid) {
        push @update_args, $feature_correspondence_aid;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " accession_id = ? ";
    }
    if ($feature_id1) {
        push @update_args, $feature_id1;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " feature_id1 = ? ";
    }
    if ($feature_id2) {
        push @update_args, $feature_id2;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " feature_id2 = ? ";
    }
    if ($is_enabled) {
        push @update_args, $is_enabled;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " is_enabled = ? ";
    }

    push @update_args, $feature_correspondence_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_correspondence {    #ZZZ

=pod

=head2 delete_correspondence()

=over 4

=item * Description

Given the id or a feature id, delete the objects.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Requred At Least One Input

=over 4

=item - feature_correspondence_id (feature_correspondence_id)

=item - Feature ID (feature_id)

=back

=item * Output

1

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $db = $cmap_object->db;
    my $feature_correspondence_id = $args{'feature_correspondence_id'};
    my $feature_id                = $args{'feature_id'};
    my @delete_args               = ();
    my $delete_sql_fc             = qq[
        delete from cmap_feature_correspondence
    ];
    my $delete_sql_cl = qq[
        delete from cmap_correspondence_lookup
    ];
    my $where_sql_fc = '';
    my $where_sql_cl = '';

    if ($feature_correspondence_id) {
        push @delete_args, $feature_correspondence_id;
        $where_sql_fc .= $where_sql_fc ? " and " : " where ";
        $where_sql_fc .= " feature_correspondence_id = ? ";
        $where_sql_cl .= $where_sql_cl ? " and " : " where ";
        $where_sql_cl .= " feature_correspondence_id = ? ";
    }
    if ($feature_id) {
        push @delete_args, $feature_id;
        push @delete_args, $feature_id;
        $where_sql_fc .= $where_sql_fc ? " and " : " where ";
        $where_sql_fc .= " ( feature_id1 = ? or feature_id2 = ?) ";
        $where_sql_cl .= $where_sql_cl ? " and " : " where ";
        $where_sql_cl .= " ( feature_id1 = ? or feature_id2 = ?) ";
    }

    return unless ($where_sql_fc);
    $delete_sql_fc .= $where_sql_fc;
    $delete_sql_cl .= $where_sql_cl;
    $db->do( $delete_sql_fc, {}, (@delete_args) );
    $db->do( $delete_sql_cl, {}, (@delete_args) );

    return 1;
}

=pod

=head1 Correspondence Evidence Methods

=cut 

#-----------------------------------------------
sub get_correspondence_evidences {    #ZZZ

=pod

=head2 get_correspondence_evidences()

=over 4

=item * Description

Get information about the correspondence evidences

=item * Adaptor Writing Info

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - feature_correspondence_id (feature_correspondence_id)

=item - correspondence_evidence_id (correspondence_evidence_id)

=item - evidence_type_aid (evidence_type_aid)

=item - Order by clause (order_by)

=back

=item * Output

Array of Hashes:

  Keys:
    correspondence_evidence_id
    feature_correspondence_id
    correspondence_evidence_aid
    score
    evidence_type_aid
    rank
    evidence_type

=item * Cache Level (Not Used): 4

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $feature_correspondence_id  = $args{'feature_correspondence_id'};
    my $correspondence_evidence_id = $args{'correspondence_evidence_id'};
    my $evidence_type_aid          = $args{'evidence_type_aid'};
    my $order_by                   = $args{'order_by'};
    my $db                         = $cmap_object->db;
    my $evidence_type_data         = $cmap_object->evidence_type_data();
    my $return_object;

    my @identifiers = ();
    my $sql_str     = q[
        select   ce.correspondence_evidence_id,
                 ce.feature_correspondence_id,
                 ce.accession_id as correspondence_evidence_aid,
                 ce.score,
                 ce.evidence_type_accession as evidence_type_aid
        from     cmap_correspondence_evidence ce
    ];
    my $where_sql    = '';
    my $order_by_sql = '';

    if ($correspondence_evidence_id) {
        push @identifiers, $correspondence_evidence_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " ce.correspondence_evidence_id = ? ";
    }
    if ($evidence_type_aid) {
        push @identifiers, $evidence_type_aid;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " ce.evidence_type_aid = ? ";
    }
    if ($feature_correspondence_id) {
        push @identifiers, $feature_correspondence_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " ce.feature_correspondence_id = ? ";
    }
    if ($order_by) {
        $order_by_sql = " order by $order_by ";
    }

    $sql_str .= $where_sql;

    $return_object =
      $db->selectall_arrayref( $sql_str, { Columns => {} }, @identifiers );

    foreach my $row ( @{$return_object} ) {
        $row->{'rank'} =
          $evidence_type_data->{ $row->{'evidence_type_aid'} }{'rank'};
        $row->{'evidence_type'} =
          $evidence_type_data->{ $row->{'evidence_type_aid'} }{'evidence_type'};
    }

    return $return_object;
}

#-----------------------------------------------
sub get_correspondence_evidences_simple {    #ZZZ

=pod

=head2 get_correspondence_evidences_simple()

=over 4

=item * Description

Get information about evidences.  This "_simple" method is different from the others because it can take map set ids (which requires table joins) to determine which evidences to return.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - List of Map Set IDs (map_set_ids)

=back

=item * Output

Array of Hashes:

  Keys:
    correspondence_evidence_id
    feature_correspondence_id
    accession_id
    evidence_type_aid
    score
    rank

=item * Cache Level (If Used): 4

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $map_set_ids        = $args{'map_set_ids'} || [];
    my $db                 = $cmap_object->db;
    my $evidence_type_data = $cmap_object->evidence_type_data();
    my $return_object;

    my $sql_str = q[
        select ce.correspondence_evidence_id,
                   ce.feature_correspondence_id,
                   ce.accession_id,
                   ce.evidence_type_accession as evidence_type_aid,
                   ce.score
            from   cmap_correspondence_evidence ce
    ];
    if (@$map_set_ids) {
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
        $sql_str .=
          " and map1.map_set_id in (" . join( ",", sort @$map_set_ids ) . ") ";
        $sql_str .=
          " and map2.map_set_id in (" . join( ",", sort @$map_set_ids ) . ") ";
    }
    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );

    foreach my $row ( @{$return_object} ) {
        $row->{'rank'} =
          $evidence_type_data->{ $row->{'evidence_type_aid'} }{'rank'};
    }

    return $return_object;
}

#-----------------------------------------------
sub insert_correspondence_evidence {    #ZZZ

=pod

=head2 insert_correspondence_evidence()

=over 4

=item * Description

Insert a correspondence evidence into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - evidence_type_aid (evidence_type_aid)

=item - score (score)

=item - correspondence_evidence_aid (correspondence_evidence_aid)

=item - feature_correspondence_id (feature_correspondence_id)

=back

=item * Output

Correspondence Evidence id

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object       = $args{'cmap_object'}       or return;
    my $evidence_type_aid = $args{'evidence_type_aid'} or return;
    my $score             = $args{'score'};
    my $correspondence_evidence_aid = $args{'correspondence_evidence_aid'}
      || $args{'accession_id'};
    my $feature_correspondence_id = $args{'feature_correspondence_id'};
    my $db                        = $cmap_object->db;
    my $evidence_type_data        = $cmap_object->evidence_type_data();
    my $return_object;
    my $corr_evidence_id = $self->next_number(
        cmap_object => $cmap_object,
        object_type => 'correspondence_evidence',
      )
      or return $self->error('No next number for correspondence evidence');
    $correspondence_evidence_aid ||= $corr_evidence_id;
    my $rank = $self->evidence_type_data( $evidence_type_aid, 'rank' ) || 1;
    my @insert_args = (
        $corr_evidence_id, $correspondence_evidence_aid,
        $feature_correspondence_id, $evidence_type_aid, $score, $rank,
    );

    $db->do(
        qq[
            insert into   cmap_correspondence_evidence
                   ( correspondence_evidence_id,
                     accession_id,
                     feature_correspondence_id,
                     evidence_type_accession,
                     score,
                     rank
                   )
            values ( ?, ?, ?, ?, ?, ? )
        ],
        {},
        (@insert_args)
    );

    return $corr_evidence_id;
}

#-----------------------------------------------
sub update_correspondence_evidence {    #ZZZ

=pod

=head2 update_correspondence_evidence()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

If you don't want CMap to update into your database, make this a dummy method.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - correspondence_evidence_id (correspondence_evidence_id)

=back

=item * Inputs To Update

=over 4

=item - evidence_type_aid (evidence_type_aid)

=item - score (score)

=item - rank (rank)

=item - correspondence_evidence_aid (correspondence_evidence_aid)

=item - feature_correspondence_id (feature_correspondence_id)

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $correspondence_evidence_id = $args{'correspondence_evidence_id'}
      || $args{'object_id'}
      or return;
    my $evidence_type_aid           = $args{'evidence_type_aid'};
    my $score                       = $args{'score'};
    my $rank                        = $args{'rank'};
    my $correspondence_evidence_aid = $args{'correspondence_evidence_aid'}
      || $args{'accession_id'};
    my $feature_correspondence_id = $args{'feature_correspondence_id'};
    my $db                        = $cmap_object->db;
    my $evidence_type_data        = $cmap_object->evidence_type_data();
    my $return_object;

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_correspondence_evidence
    ];
    my $set_sql   = '';
    my $where_sql = " where correspondence_evidence_id=? ";

    if ($evidence_type_aid) {
        push @update_args, $evidence_type_aid;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " evidence_type_accession = ? ";
    }
    if ($score) {
        push @update_args, $score;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " score = ? ";
    }
    if ($rank) {
        push @update_args, $rank;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " rank = ? ";
    }
    if ($feature_correspondence_id) {
        push @update_args, $feature_correspondence_id;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " feature_correspondence_id = ? ";
    }
    if ($correspondence_evidence_aid) {
        push @update_args, $correspondence_evidence_aid;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " accession_id = ? ";
    }

    push @update_args, $correspondence_evidence_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_evidence {    #ZZZ

=pod

=head2 delete_evidence()

=over 4

=item * Description

Given the id or a feature correspondence id, delete the objects.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Requred At Least One Input

=over 4

=item - correspondence_evidence_id (correspondence_evidence_id)

=item - feature_correspondence_id (feature_correspondence_id)

=back

=item * Output

1

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $db = $cmap_object->db;
    my $correspondence_evidence_id = $args{'correspondence_evidence_id'};
    my $feature_correspondence_id  = $args{'feature_correspondence_id'};
    my @delete_args                = ();
    my $delete_sql                 = qq[
        delete from cmap_correspondence_evidence
    ];
    my $where_sql = '';

    if ($correspondence_evidence_id) {
        push @delete_args, $correspondence_evidence_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " correspondence_evidence_id = ? ";
    }
    if ($feature_correspondence_id) {
        push @delete_args, $feature_correspondence_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " feature_correspondence_id = ? ";
    }

    return unless ($where_sql);
    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
}

=pod

=head1 Attribute Methods

=cut 

#-----------------------------------------------
sub get_attributes {    #ZZZ

=pod

=head2 get_attributes()

=over 4

=item * Description

Retrieves the attributes attached to a database object.

=item * Adaptor Writing Info

This will require conversion from object type to a table.

See the get_all flag.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - Object type such as feature or map_set (object_type)

=item - Object ID (object_id) 

=item - attribute_id (attribute_id)

=item - is_public (is_public)

=item - attribute_name (attribute_name)

=item - attribute_value (attribute_value)

=item - Order by clause (order_by)

=item - Get All Flag (get_all)

Boolean value.  If set to 1, return all without regard to whether object_id is
null.  Specifying an object_id overrides this.

=back

=item * Output

Array of Hashes:

  Keys:
    attribute_id,
    object_id,
    table_name,
    display_order,
    is_public,
    attribute_name,
    attribute_value
    object_type

=item * Cache Level (Not Used): 4

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object     = $args{'cmap_object'} or die "No CMap Object included";
    my $object_type     = $args{'object_type'};
    my $attribute_id    = $args{'attribute_id'};
    my $is_public       = $args{'is_public'};
    my $attribute_name  = $args{'attribute_name'};
    my $attribute_value = $args{'attribute_value'};
    my $object_id       = $args{'object_id'};
    my $order_by        = $args{'order_by'};
    my $get_all         = $args{'get_all'} || 0;
    my $db              = $cmap_object->db;
    my $return_object;
    my @identifiers = ();

    my $table_name = $self->{'TABLE_NAMES'}->{$object_type};
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
    ];
    my $where_sql    = '';
    my $order_by_sql = '';
    if ($attribute_id) {
        push @identifiers, $attribute_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " attribute_id = ? ";
    }
    if ($attribute_name) {
        push @identifiers, $attribute_name;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " attribute_name = ? ";
    }
    if ($attribute_value) {
        push @identifiers, $attribute_value;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " attribute_value = ? ";
    }
    if ($table_name) {
        push @identifiers, $table_name;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " table_name = ? ";
    }

    if ($object_id) {
        push @identifiers, $object_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " object_id=? ";
    }
    elsif ( !$get_all ) {
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " object_id is not null ";
    }

    if ($order_by) {
        $order_by_sql .= " order by $order_by ";
    }

    $sql_str .= $where_sql . $order_by_sql;

    $return_object =
      $db->selectall_arrayref( $sql_str, { Columns => {} }, @identifiers );

    foreach my $row (@$return_object) {
        $row->{'object_type'} =
          $self->{'OBJECT_TYPES'}->{ $row->{'table_name'} };
        delete( $row->{'table_name'} );
    }

    return $return_object;
}

#-----------------------------------------------
sub insert_attribute {    #ZZZ

=pod

=head2 insert_attribute()

=over 4

=item * Description

Insert an attribute into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

This will require conversion from object type to a table.

=item * Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Display Order (display_order)

=item - Object type such as feature or map_set (object_type)

=item - is_public (is_public)

=item - attribute_name (attribute_name)

=item - attribute_value (attribute_value)

=item - Object ID (object_id)

=back

=item * Output

Attribute id

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object  = $args{'cmap_object'} or die "No CMap Object included";
    my $db           = $cmap_object->db;
    my $attribute_id = $self->next_number(
        cmap_object => $cmap_object,
        object_type => 'attribute',
      )
      or return $self->error('No next number for attribute ');
    my $display_order   = $args{'display_order'};
    my $object_type     = $args{'object_type'};
    my $is_public       = $args{'is_public'};
    my $attribute_name  = $args{'attribute_name'};
    my $attribute_value = $args{'attribute_value'};
    my $object_id       = $args{'object_id'};
    my $table_name      = $self->{'TABLE_NAMES'}->{$object_type};
    my @insert_args     = (
        $attribute_id, $table_name, $object_id, $attribute_value,
        $attribute_name, $is_public, $display_order
    );

    unless ( defined($display_order) ) {
        $display_order = $db->selectrow_array(
            q[
                select max(display_order)
                from   cmap_attribute
                where  table_name=?
                and    object_id=?
            ],
            {},
            ( $table_name, $object_id )
        );
        $display_order++;
    }

    $db->do(
        qq[
        insert into cmap_attribute
        (attribute_id,table_name,object_id,attribute_value,attribute_name,is_public,display_order )
         values ( ?,?,?,?,?,?,?,? )
        ],
        {},
        (@insert_args)
    );

    return $attribute_id;
}

#-----------------------------------------------
sub update_attribute {    #ZZZ

=pod

=head2 update_attribute()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

This will require conversion from object type to a table.

If you don't want CMap to update into your database, make this a dummy method.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - attribute_id (attribute_id)

=back

=item * Inputs To Update

=over 4

=item - Display Order (display_order)

=item - Object type such as feature or map_set (object_type)

=item - is_public (is_public)

=item - attribute_name (attribute_name)

=item - attribute_value (attribute_value)

=item - Object ID (object_id)

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object  = $args{'cmap_object'}  or return;
    my $attribute_id = $args{'attribute_id'} or return;
    my $display_order   = $args{'display_order'};
    my $object_type     = $args{'object_type'};
    my $is_public       = $args{'is_public'};
    my $attribute_name  = $args{'attribute_name'};
    my $attribute_value = $args{'attribute_value'};
    my $object_id       = $args{'object_id'};
    my $db              = $cmap_object->db;

    my $table_name = $self->{'TABLE_NAMES'}->{$object_type};

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_attribute 
    ];
    my $set_sql   = '';
    my $where_sql = " where attribute_id = ? ";    # ID

    if ($display_order) {
        push @update_args, $display_order;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " display_order = ? ";
    }
    if ($is_public) {
        push @update_args, $is_public;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " is_public = ? ";
    }
    if ($table_name) {
        push @update_args, $table_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " table_name = ? ";
    }
    if ($attribute_name) {
        push @update_args, $attribute_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " attribute_name = ? ";
    }
    if ($attribute_value) {
        push @update_args, $attribute_value;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " attribute_value = ? ";
    }
    if ($object_id) {
        push @update_args, $object_id;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " object_id = ? ";
    }

    push @update_args, $attribute_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_attribute {    #ZZZ

=pod

=head2 delete_attribute()

=over 4

=item * Description

Given the id, the object_type or the object_id, delete this object.

=item * Adaptor Writing Info

This will require conversion from object type to a table.

If you don't want CMap to delete from your database, make this a dummy method.

=item * Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Requred At Least One Input

=over 4

=item - attribute_id (attribute_id)

=item - Object type such as feature or map_set (object_type)

=item - Object ID (object_id)

=back

=item * Output

1

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object  = $args{'cmap_object'} or die "No CMap Object included";
    my $db           = $cmap_object->db;
    my $attribute_id = $args{'attribute_id'};
    my $object_type  = $args{'object_type'};
    my $object_id    = $args{'object_id'};
    my $table_name   = $self->{'TABLE_NAMES'}->{$object_type};
    my @delete_args  = ();
    my $delete_sql   = qq[
        delete from cmap_attribute
    ];
    my $where_sql = '';

    if ($object_id) {
        push @delete_args, $object_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " object_id = ? ";
    }
    if ($table_name) {
        push @delete_args, $table_name;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " table_name = ? ";
    }
    if ($attribute_id) {
        push @delete_args, $attribute_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " attribute_id = ? ";
    }

    return unless ($where_sql);
    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
}

=pod

=head1 Xref Methods

=cut 

#-----------------------------------------------
sub get_xrefs {    #ZZZ

=pod

=head2 get_xrefs()

=over 4

=item * Description

Retrieves the attributes attached to a database object.

=item * Adaptor Writing Info

This will require conversion from object type to a table.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - Object type such as feature or map_set (object_type)

=item - Object ID (object_id)

=item - xref_id (xref_id)

=item - xref_name (xref_name)

=item - xref_url (xref_url)

=item - Order by clause (order_by)

=back

=item * Output

Array of Hashes:

  Keys:
    xref_id
    object_id
    display_order
    xref_name
    xref_url
    object_type

=item * Cache Level (Not Used): 4

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $object_type = $args{'object_type'};
    my $xref_id     = $args{'xref_id'};
    my $xref_name   = $args{'xref_name'};
    my $xref_url    = $args{'xref_url'};
    my $object_id   = $args{'object_id'};
    my $order_by    = $args{'order_by'};
    my $db          = $cmap_object->db;
    my $return_object;
    my @identifiers = ();

    my $table_name = $self->{'TABLE_NAMES'}->{$object_type};
    if ( !$order_by || $order_by eq 'display_order' ) {
        $order_by = 'display_order,xref_name';
    }

    my $sql_str = qq[
        select   xref_id,
                 object_id,
                 table_name,
                 display_order,
                 xref_name,
                 xref_url
        from     cmap_xref
    ];
    my $where_sql    = '';
    my $order_by_sql = '';
    if ($table_name) {
        push @identifiers, $table_name;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " table_name = ? ";
    }

    if ($object_id) {
        push @identifiers, $object_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " object_id=? ";
    }
    if ($xref_id) {
        push @identifiers, $xref_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " xref_id=? ";
    }
    if ($xref_url) {
        push @identifiers, $xref_url;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " xref_url=? ";
    }
    if ($xref_name) {
        push @identifiers, $xref_name;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " xref_name=? ";
    }

    if ($order_by) {
        $order_by_sql .= " order by $order_by ";
    }

    $sql_str .= $where_sql . $order_by_sql;

    $return_object =
      $db->selectall_arrayref( $sql_str, { Columns => {} }, @identifiers );

    foreach my $row (@$return_object) {
        $row->{'object_type'} =
          $self->{'OBJECT_TYPES'}->{ $row->{'table_name'} };
        delete( $row->{'table_name'} );
    }

    return $return_object;
}

#-----------------------------------------------
sub get_generic_xrefs {    #ZZZ

=pod

=head2 get_generic_xrefs()

=over 4

=item * Description

Retrieves the attributes attached to all generic objects.  That means
attributes attached to all features and all maps, etc NOT any specific features or maps.

=item * Adaptor Writing Info

Your database may have a different way of handling references to the generic objects.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item * object_type (object_type)
                                                                                                                             
=item * order_by (order_by)

=back

=item * Output

Array of Hashes:

  Keys:
    object_type,
    display_order,
    xref_name,
    xref_url

=item * Cache Level (If Used): 4

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $object_type = $args{'object_type'};
    my $order_by    = $args{'order_by'};
    my $db          = $cmap_object->db;
    my $return_object;

    my $sql_str = qq[
        select table_name,
               display_order,
               xref_name,
               xref_url
        from   cmap_xref
        where  (object_id is null
        or     object_id=0)
    ];
    if ($object_type) {
        my $table_name = $self->{'TABLE_NAMES'}->{$object_type};
        $sql_str .= " and table_name = '$table_name' ";
    }

    if ($order_by) {
        $sql_str .= " order by $order_by ";
    }

    $return_object = $db->selectall_arrayref( $sql_str, { Columns => {} } );
    foreach my $row (@$return_object) {
        $row->{'object_type'} =
          $self->{'OBJECT_NAMES'}->{ $row->{'table_name'} };
        delete( $row->{'table_name'} );
    }

    return $return_object;
}

#-----------------------------------------------
sub insert_xref {    #ZZZ

=pod

=head2 insert_xref()

=over 4

=item * Description

Insert an xref into the database.

=item * Adaptor Writing Info

This will require conversion from object type to a table.

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Display Order (display_order)

=item - Object type such as feature or map_set (object_type)

=item - xref_name (xref_name)

=item - xref_url (xref_url)

=item - Object ID (object_id)

=back

=item * Output

Xref id

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $db          = $cmap_object->db;
    my $xref_id     =
      $self->next_number( cmap_object => $cmap_object, object_type => 'xref', )
      or return $self->error('No next number for xref ');
    my $display_order = $args{'display_order'};
    my $object_type   = $args{'object_type'};
    my $xref_name     = $args{'xref_name'};
    my $xref_url      = $args{'xref_url'};
    my $object_id     = $args{'object_id'};
    my $table_name    = $self->{'TABLE_NAMES'}->{$object_type};
    my @insert_args   = (
        $xref_id,  $table_name, $object_id,
        $xref_url, $xref_name,  $display_order
    );

    unless ( defined($display_order) ) {
        $display_order = $db->selectrow_array(
            q[
                select max(display_order)
                from   cmap_xref
                where  table_name=?
                and    object_id=?
            ],
            {},
            ( $table_name, $object_id )
        );
        $display_order++;
    }

    $db->do(
        qq[
        insert into cmap_xref
        (xref_id,table_name,object_id,xref_url,xref_name,is_public,display_order )
         values ( ?,?,?,?,?,?,?,? )
        ],
        {},
        (@insert_args)
    );

    return $xref_id;
}

#-----------------------------------------------
sub update_xref {    #ZZZ

=pod

=head2 update_xref()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

This will require conversion from object type to a table.

If you don't want CMap to update into your database, make this a dummy method.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - xref_id (xref_id)

=back

=item * Inputs To Update

=over 4

=item - Display Order (display_order)

=item - Object type such as feature or map_set (object_type)

=item - xref_name (xref_name)

=item - xref_url (xref_url)

=item - Object ID (object_id)

=item - is_public (is_public)

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $xref_id     = $args{'xref_id'}     or return;
    my $display_order = $args{'display_order'};
    my $object_type   = $args{'object_type'};
    my $xref_name     = $args{'xref_name'};
    my $xref_url      = $args{'xref_url'};
    my $object_id     = $args{'object_id'};
    my $is_public     = $args{'is_public'};
    my $db            = $cmap_object->db;

    my $table_name = $self->{'TABLE_NAMES'}->{$object_type};

    my @update_args = ();
    my $update_sql  = qq[
        update cmap_xref 
    ];
    my $set_sql   = '';
    my $where_sql = " where xref_id = ? ";    # ID

    if ($display_order) {
        push @update_args, $display_order;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " display_order = ? ";
    }
    if ( defined($is_public) ) {
        push @update_args, $is_public;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " is_public = ? ";
    }
    if ($table_name) {
        push @update_args, $table_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " table_name = ? ";
    }
    if ($xref_name) {
        push @update_args, $xref_name;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " xref_name = ? ";
    }
    if ($xref_url) {
        push @update_args, $xref_url;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " xref_url = ? ";
    }
    if ($object_id) {
        push @update_args, $object_id;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " object_id = ? ";
    }

    push @update_args, $xref_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_xref {    #ZZZ

=pod

=head2 delete_xref()

=over 4

=item * Description

Given the id, the object_type or the object_id, delete this object.

=item * Adaptor Writing Info

This will require conversion from object type to a table.

If you don't want CMap to delete from your database, make this a dummy method.

=item * Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Requred At Least One Input

=over 4

=item - xref_id (xref_id)

=item - Object type such as feature or map_set (object_type)

=item - Object ID (object_id)

=back

=item * Output

1

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $db          = $cmap_object->db;
    my $xref_id     = $args{'xref_id'};
    my $object_type = $args{'object_type'};
    my $object_id   = $args{'object_id'};
    my $table_name  = $self->{'TABLE_NAMES'}->{$object_type};
    my @delete_args = ();
    my $delete_sql  = qq[
        delete from cmap_xref
    ];
    my $where_sql = '';

    if ($object_id) {
        push @delete_args, $object_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " object_id = ? ";
    }
    if ($table_name) {
        push @delete_args, $table_name;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " table_name = ? ";
    }
    if ($xref_id) {
        push @delete_args, $xref_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " xref_id = ? ";
    }

    return unless ($where_sql);
    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
}

=pod

=head1 Object Type Methods

=cut 

#-----------------------------------------------
sub get_used_feature_types {    #ZZZ

=pod

=head2 get_used_feature_types()

=over 4

=item * Description

Get feature type info for features that are actually used.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - List of Map IDs (map_ids)

=item - List of Map Set IDs (map_set_ids)

=item - List of feature types to check (included_feature_type_aids)

=back

=item * Output

Array of Hashes:

  Keys:
    feature_type_aid,
    feature_type,
    shape,
    color

=item * Cache Level: 3

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $map_ids                    = $args{'map_ids'}                    || [];
    my $map_set_ids                = $args{'map_set_ids'}                || [];
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
    if (@$map_set_ids) {
        $sql_str   .= ", cmap_map map ";
        $where_sql .= $where_sql ? ' and ' : ' where ';
        $where_sql .= " f.map_id = map.map_id ";
        $where_sql .=
          " and map.map_set_id in ('"
          . join( "','", sort @$map_set_ids ) . "')";
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
sub get_used_map_types {    #ZZZ

=pod

=head2 get_used_map_types()

=over 4

=item * Description

Get map type info for map sets that are actually used.

=item * Adaptor Writing Info

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - Boolean: is this a relational map (is_relational_map)

Set to 1 or 0 to select based on the is_relational_map column.  Leave undefined
to ignore that column.

=item - Boolean: Is this enabled (is_enabled) 

Set to 1 or 0 to select based on the is_enabled column.  Leave undefined to
ignore that column.

=back

=item * Output

Array of Hashes:

  Keys:
    map_type_aid
    map_type
    display_order

=item * Cache Level (Not Used): 3

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
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
sub get_map_type_aid {    #ZZZ

=pod

=head2 get_map_type_aid()

=over 4

=item * Description

Given a map set get it's map type accession.

=item * Adaptor Writing Info

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Map Set Accession (map_set_aid)

=back

=item * Output

Map Type Accession

=item * Cache Level (Not Used): 2

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
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

=pod

=head1 Matrix Methods

=cut 

#-----------------------------------------------
sub get_matrix_relationships {#ZZZ

=pod

=head2 get_matrix_relationships()

=over 4

=item * Description

Get Matrix data from the matrix table.

This method progressively gives more data depending on the input.  If a
map_set_aid is given, it will count based on individual maps of that map_set
and the results also include those map accessions.  If a link_map_set_aid is
also given it will count based on individual maps of both map sets and the
results include both map accessions. 

=item * Adaptor Writing Info

This method pulls data from the denormalized matrix table.  If you do not have
this table in your db, it might be slow.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Optional Input

=over 4

=item - Map Set Accession (map_set_aid)

=item - Link Map Set Accession (link_map_set_aid)

=item - Species Accession (species_aid)

=item - Map Name (map_name)

=back

=item * Output

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

=item * Cache Level (Not Used): 

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $species_aid = $args{'species_aid'};
    my $map_name    = $args{'map_name'};
    my $map_set_aid = $args{'map_set_aid'};
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
sub reload_correspondence_matrix {    #ZZZ

=pod

=head2 reload_correspondence_matrix()

=over 4

=item * Description

Reloads the correspondence matrix table

=item * Adaptor Writing Info

This method populates a denormalized matrix table.  If you do not have
this table in your db, it dummy up this method.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $db          = $cmap_object->db;

    #
    # Empty the table.
    #
    $db->do('delete from cmap_correspondence_matrix');

    #
    # Select all the reference maps.
    #
    my @reference_maps = @{
        $db->selectall_arrayref(
            q[
                select   map.map_id,
                         map.accession_id as map_aid,
                         map.map_name,
                         ms.accession_id as map_set_aid,
                         ms.map_set_short_name,
                         s.accession_id as species_aid,
                         s.species_common_name
                from     cmap_map map,
                         cmap_map_set ms,
                         cmap_species s
                where    map.map_set_id=ms.map_set_id
                and      ms.can_be_reference_map=1
                and      ms.species_id=s.species_id
                order by map_set_short_name, map_name
            ],
            { Columns => {} }
        )
      };

    #
    # Go through each map and figure the number of correspondences.
    #
    my ( $i, $new_records ) = ( 0, 0 );    # counters
    for my $map (@reference_maps) {
        $i++;
        if ( $i % 50 == 0 ) {
            print(" $i\n");
        }
        else {
            print('#');
        }

        #
        # This gets the number of correspondences to each individual
        # map that can serve as a reference map.
        #
        my $map_correspondences = $db->selectall_arrayref(
            q[
                select   map.accession_id as map_aid,
                         map.map_name,
                         ms.accession_id as map_set_aid,
                         count(f2.feature_id) as no_correspondences,
                         ms.map_set_short_name,
                         s.accession_id as species_aid,
                         s.species_common_name
                from     cmap_feature f1,
                         cmap_feature f2,
                         cmap_correspondence_lookup cl,
                         cmap_feature_correspondence fc,
                         cmap_map map,
                         cmap_map_set ms,
                         cmap_species s
                where    f1.map_id=?
                and      f1.feature_id=cl.feature_id1
                and      cl.feature_correspondence_id=
                         fc.feature_correspondence_id
                and      fc.is_enabled=1
                and      cl.feature_id2=f2.feature_id
                and      f2.map_id<>?
                and      f2.map_id=map.map_id
                and      map.map_set_id=ms.map_set_id
                and      ms.can_be_reference_map=1
                and      ms.species_id=s.species_id
                group by map.accession_id,
                         map.map_name,
                         ms.accession_id,
                         ms.map_set_short_name,
                         s.accession_id,
                         s.species_common_name
                order by map_set_short_name, map_name
            ],
            { Columns => {} },
            ( $map->{'map_id'}, $map->{'map_id'} )
        );

        #
        # This gets the number of correspondences to each whole
        # map set that cannot serve as a reference map.
        #
        my $map_set_correspondences = $db->selectall_arrayref(
            q[
                select   count(f2.feature_id) as no_correspondences,
                         ms.accession_id as map_set_aid,
                         ms.map_set_short_name,
                         s.accession_id as species_aid,
                         s.species_common_name
                from     cmap_feature f1,
                         cmap_feature f2,
                         cmap_correspondence_lookup cl,
                         cmap_feature_correspondence fc,
                         cmap_map map,
                         cmap_map_set ms,
                         cmap_species s
                where    f1.map_id=?
                and      f1.feature_id=cl.feature_id1
                and      cl.feature_id2=f2.feature_id
                and      cl.feature_correspondence_id=
                         fc.feature_correspondence_id
                and      fc.is_enabled=1
                and      f2.map_id=map.map_id
                and      map.map_set_id=ms.map_set_id
                and      ms.can_be_reference_map=0
                and      ms.species_id=s.species_id
                group by ms.accession_id,
                         ms.map_set_short_name,
                         s.accession_id,
                         s.species_common_name
                order by map_set_short_name
            ],
            { Columns => {} },
            ( $map->{'map_id'} )
        );

        for my $corr ( @$map_correspondences, @$map_set_correspondences ) {
            $db->do(
                q[
                    insert
                    into   cmap_correspondence_matrix
                           ( reference_map_aid,
                             reference_map_name,
                             reference_map_set_aid,
                             reference_species_aid,
                             link_map_aid,
                             link_map_name,
                             link_map_set_aid,
                             link_species_aid,
                             no_correspondences
                           )
                    values ( ?, ?, ?, ?, ?, ?, ?, ?, ? )
                ],
                {},
                (
                    $map->{'map_aid'},      $map->{'map_name'},
                    $map->{'map_set_aid'},  $map->{'species_aid'},
                    $corr->{'map_aid'},     $corr->{'map_name'},
                    $corr->{'map_set_aid'}, $corr->{'species_aid'},
                    $corr->{'no_correspondences'},
                )
            );

            $new_records++;
        }
    }
    return $new_records;
}

=pod

=head1 Duplicate Correspondence Methods

=cut 

#-----------------------------------------------
sub get_duplicate_correspondences {    #ZZZ

=pod

=head2 get_duplicate_correspondences()

=over 4

=item * Description

Get duplicate correspondences from the database.  This method is used in order to delete them.

=item * Adaptor Writing Info

Again if you don't want CMap to mess with your db, make this a dummy method.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=back

=item * Output

Array of Hashes:

  Keys:
    original_id
    duplicate_id

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $db          = $cmap_object->db;

    my $dup_sql = q[
        select min(b.feature_correspondence_id) as original_id,
               a.feature_correspondence_id as duplicate_id
        from  cmap_correspondence_lookup a,
              cmap_correspondence_lookup b
        where a.feature_correspondence_id > b.feature_correspondence_id
          and a.feature_id1=b.feature_id1
          and a.feature_id2=b.feature_id2
        group by a.feature_correspondence_id
        ];

    return $db->selectall_arrayref( $dup_sql, { Columns => {} } );

}

#-----------------------------------------------
sub get_moveable_evidence {    #ZZZ

=pod

=head2 get_moveable_evidence()

=over 4

=item * Description

When deleting a duplicate correspondence, we want to make sure that we transfer
the unique evidences from the deleted corr to the remaining corr.  This method
finds the unique evidences that we want to move.

=item * Adaptor Writing Info

Again if you don't want CMap to mess with your db, make this a dummy method.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - original_id (original_id)

=item - duplicate_id (duplicate_id)

=back

=item * Output

Array of correspondence_evidence_ids

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object  = $args{'cmap_object'} or die "No CMap Object included";
    my $original_id  = $args{'original_id'};
    my $duplicate_id = $args{'duplicate_id'};
    my $db           = $cmap_object->db;
    my $return_object;

    my $evidence_move_sql = qq[
        select distinct ce1.correspondence_evidence_id
        from   cmap_correspondence_evidence ce1
        left join cmap_correspondence_evidence ce2
            on ce1.evidence_type_accession=ce2.evidence_type_accession
           and ce2.feature_correspondence_id=$original_id
        where  ce1.feature_correspondence_id=$duplicate_id
           and ce2.feature_correspondence_id is NULL
    ];
    $return_object = $db->selectcol_arrayref( $evidence_move_sql, {}, () );

    return $return_object;
}

=pod

=head1 Internal Methods

=cut 

# ----------------------------------------------------
sub next_number {    #ZZZ

=pod

=head2 next_number()

=over 4

=item * Description

A generic routine for retrieving (and possibly setting) the next number for an
ID field in a table.  Given a table "foo," the expected ID field would be
"foo_id," but this isn't always the case.  Therefore, "id_field" tells us what
field to look at.  Basically, we look to see if there's an entry in the
"next_number" table.  If not we do a MAX on the ID field given (or
ascertained).  Either way, the "next_number" table gets told what the next
number will be (on the next call), and we pass back what is the next number
this time.

So why not just use "auto_increment" (MySQL) or a "sequence" (Oracle)?  Just to
make sure that this stays completely portable.  By coding all this in Perl, I
know that it will work with any database (that supports ANSI-SQL, that is).

=item * Adaptor Writing Info

This is only required for the original CMap database since it doesn't assume
that db has auto incrementing.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $db          = $cmap_object->db     or return;
    my $object_type = $args{'object_type'} or return;
    my $no_requested = $args{'requested'} || 1;
    my $id_field     = $self->pk_name($object_type);
    my $table_name   = $self->{'TABLE_NAMES'}->{$object_type};

    my $next_number = $db->selectrow_array(
        q[
            select next_number
            from   cmap_next_number
            where  table_name=?
        ],
        {}, ($table_name)
    );

    unless ($next_number) {
        $next_number = $db->selectrow_array(
            qq[
                select max( $id_field )
                from   $table_name
            ]
        ) || 0;
        $next_number++;

        $db->do(
            q[
                insert
                into   cmap_next_number ( table_name, next_number )
                values ( ?, ? )
            ],
            {}, ( $table_name, $next_number + $no_requested )
        );
    }
    else {
        $db->do(
            q[
                update cmap_next_number
                set    next_number=?
                where  table_name=?
            ],
            {}, ( $next_number + $no_requested, $table_name )
        );
    }

    return $next_number;
}

#-----------------------------------------------
sub feature_name_to_position {    #ZZZ

=pod

=head2 feature_name_to_position()

=over 4

=item * Description

Turn a feature name into a position.  If start_position_only is true, it
returns the start.  If it is false, return a defined stop (or start if stop in
undef).

=item * Adaptor Writing Info

This is only used in get_slot_info().  An adaptor might find it useful even
still.

=item * Required Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item - Feature Name (feature_name)

=item - Map ID (map_id)

=item - start_position_only (start_position_only)

=back

=item * Output

Start or stop of feature

=item * Cache Level (If Used): 3

Not using cache because this query is quicker.

=back

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
    my $feature_array = $self->get_features(
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
sub orderOutFromZero {    #ZZZ

=pod

=head2 orderOutFromZero()

=over 4

=item * Description

Sorting method: Return the sort in this order (0,1,-1,-2,2,-3,3,)

=item * Adaptor Writing Info

This is probably going to be useful for any adaptor

=back

=cut

    return ( abs($a) cmp abs($b) );
}

=pod

=head1 Method Stubs

=cut 

#-----------------------------------------------
sub stub {    #ZZZ

=pod

=head2 stub()

=over 4

=item * Description

=item * Adaptor Writing Info

=item * Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item -

=back

=item * Output

Array of Hashes:

  Keys:

=item * Cache Level (If Used): 

Not using cache because this query is quicker.

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $x           = $args{''};
    my $db          = $cmap_object->db;
    my $return_object;

    return $return_object;
}

#-----------------------------------------------
sub insert_stub {    #ZZZ

=pod

=head2 insert_stub()

=over 4

=item * Description

Insert into the database.

=item * Adaptor Writing Info

The required inputs are only the ones that the database requires.

If you don't want CMap to insert into your database, make this a dummy method.

=item * Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item -

=back

=item * Output

id

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $db          = $cmap_object->db;
    my $yy_id       =
      $self->next_number( cmap_object => $cmap_object, object_type => 'yy', )
      or return $self->error('No next number for yy ');
    my $yy_aid = $args{'yy_aid'} || $yy_id;
    my @insert_args = ( $yy_id, $yy_aid, );

    $db->do(
        qq[
        insert into cmap_yy
        (yy_id,accession_id )
         values ( ?,?, )
        ],
        {},
        (@insert_args)
    );

    return $yy_id;
}

#-----------------------------------------------
sub update_stub {    #ZZZ

=pod

=head2 update_stub()

=over 4

=item * Description

Given the id and some attributes to modify, updates.

=item * Adaptor Writing Info

=item * Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item -

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $_id         = $args{'_id'}         or return;
    my $x           = $args{'x'};
    my $db          = $cmap_object->db;

    my @update_args = ();
    my $update_sql  = qq[
        update 
    ];
    my $set_sql   = '';
    my $where_sql = " where _id = ? ";    # ID

    if ($x) {
        push @update_args, $x;
        $set_sql .= $set_sql ? ", " : " set ";
        $set_sql .= " x = ? ";
    }

    push @update_args, $_id;

    my $sql_str = $update_sql . $set_sql . $where_sql;
    $db->do( $sql_str, {}, @update_args );

}

#-----------------------------------------------
sub delete_stub {    #ZZZ

=pod

=head2 delete_stub()

=over 4

=item * Description

Given the id, delete this object.

=item * Adaptor Writing Info

If you don't want CMap to delete from your database, make this a dummy method.

=item * Input

=over 4

=item - Object that inherits from CMap.pm (cmap_object)

=item -

=back

=item * Output

1

=back

=cut

    my ( $self, %args ) = @_;
    my $cmap_object = $args{'cmap_object'} or die "No CMap Object included";
    my $db          = $cmap_object->db;
    my $yy_id       = $args{'yy_id'}
      or return $self->error('No ID given for yy to delete ');
    my @delete_args = ();
    my $delete_sql  = qq[
        delete from cmap_yy
    ];
    my $where_sql = '';

    if ($yy_id) {
        push @delete_args, $yy_id;
        $where_sql .= $where_sql ? " and " : " where ";
        $where_sql .= " yy_id = ? ";
    }

    return unless ($where_sql);
    $delete_sql .= $where_sql;
    $db->do( $delete_sql, {}, (@delete_args) );

    return 1;
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

