package Bio::GMOD::CMap::Data::Generic;

# $Id: Generic.pm,v 1.32 2003-08-11 19:45:02 kycl4rk Exp $

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
$VERSION = (qw$Revision: 1.32 $)[-1];

use Data::Dumper; # really just for debugging
use Bio::GMOD::CMap;
use base 'Bio::GMOD::CMap';

# ----------------------------------------------------
sub cmap_data_feature_count_sql {

=pod

=head2 cmap_data_feature_count_sql

The SQL for finding the number of features on a map.

=cut

    my ( $self, %args ) = @_;

    return q[
        select count(f.feature_id)
        from   cmap_feature f
        where  f.map_id=?
        and    f.start_position>=?
        and    f.start_position<=?
    ];
}

# ----------------------------------------------------
sub cmap_data_features_sql {

=pod

=head2 cmap_data_features_sql

The SQL for finding all the features on a map.

=cut

    my ( $self, %args )  = @_;
    my $order_by         = $args{'order_by'}            || '';
    my $restrict_by      = $args{'restrict_by'}         || '';
    my @feature_type_ids = @{ $args{'feature_type_ids'} || [] };
    my $sql              = qq[
        select   f.feature_id,
                 f.accession_id,
                 f.feature_name,
                 f.alternate_name,
                 f.is_landmark,
                 f.start_position,
                 f.stop_position,
                 ft.feature_type_id,
                 ft.feature_type,
                 ft.default_rank,
                 ft.shape,
                 ft.color,
                 ft.drawing_lane,
                 ft.drawing_priority,
                 map.accession_id as map_aid,
                 mt.map_units
        from     cmap_feature f,
                 cmap_feature_type ft,
                 cmap_map map,
                 cmap_map_set ms,
                 cmap_map_type mt
        where    f.map_id=?
        and      (
            ( f.start_position>=? and f.start_position<=? )
            or   (
                f.stop_position is not null and
                f.start_position<=? and
                f.stop_position>=?
            )
        )
        and      f.feature_type_id=ft.feature_type_id
        and      f.map_id=map.map_id
        and      map.map_set_id=ms.map_set_id
        and      ms.map_type_id=mt.map_type_id
    ];

    if ( @feature_type_ids ) {
        $sql .= 'and ft.feature_type_id in ('.
            join( ',', @feature_type_ids ).
        ')';
    }

    $sql .= "order by $order_by" if $order_by;

    return $sql;
}

# ----------------------------------------------------
sub cmap_data_map_info_sql {

=pod

=head2 cmap_data_map_info_sql

The SQL for finding info on a map.

=cut

    my $self = shift;
    return q[
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
               mt.map_type_id,
               mt.map_type,
               mt.map_units,
               mt.is_relational_map,
               mt.shape as default_shape,
               mt.width as default_width,
               mt.color as default_color,
               s.species_id,
               s.common_name as species_name
        from   cmap_map map,
               cmap_map_set ms,
               cmap_species s,
               cmap_map_type mt
        where  map.map_id=?
        and    map.map_set_id=ms.map_set_id
        and    ms.map_type_id=mt.map_type_id
        and    ms.species_id=s.species_id
    ];
}

# ----------------------------------------------------
sub date_format {

=pod

=head2 date_format

The strftime string for date format.

=cut

    my $self = shift;
    return '%Y-%m-%d';
}

# ----------------------------------------------------
sub feature_correspondence_sql {

=pod

=head2 feature_correspondence_sql

The SQL for finding correspondences for a feature.

=cut

    my $self = shift;
    my %args = @_;
    my $sql  = q[
        select   f.feature_name,
                 f.alternate_name,
                 f.feature_id,
                 f.accession_id as feature_aid,
                 f.start_position,
                 f.stop_position,
                 ft.feature_type,
                 map.map_id,
                 map.accession_id as map_aid,
                 map.map_name,
                 map.display_order as map_display_order,
                 ms.map_set_id,
                 ms.accession_id as map_set_aid,
                 ms.short_name as map_set_name,
                 ms.display_order as ms_display_order,
                 ms.published_on,
                 mt.map_type,
                 mt.display_order as map_type_display_order,
                 mt.map_units,
                 s.common_name as species_name,
                 s.display_order as species_display_order,
                 fc.feature_correspondence_id,
                 fc.accession_id as feature_correspondence_aid,
                 et.evidence_type
        from     cmap_correspondence_lookup cl, 
                 cmap_feature_correspondence fc,
                 cmap_correspondence_evidence ce,
                 cmap_evidence_type et,
                 cmap_feature f,
                 cmap_feature_type ft,
                 cmap_map map,
                 cmap_map_set ms,
                 cmap_map_type mt,
                 cmap_species s
        where    cl.feature_correspondence_id=fc.feature_correspondence_id
        and      fc.feature_correspondence_id=ce.feature_correspondence_id
        and      ce.evidence_type_id=et.evidence_type_id
        and      cl.feature_id1=?
        and      cl.feature_id2=f.feature_id
        and      f.feature_type_id=ft.feature_type_id
        and      f.map_id=map.map_id
        and      map.map_set_id=ms.map_set_id
        and      ms.is_enabled=1
        and      ms.species_id=s.species_id
        and      ms.map_type_id=mt.map_type_id
    ];

    if ( $args{'comparative_map_field'} eq 'map_set_aid' ) {
        $sql .= "and ms.accession_id='".$args{'comparative_map_aid'}."' ";
    }
    elsif ( $args{'comparative_map_field'} eq 'map_aid' ) {
        $sql .= "and map.accession_id='".$args{'comparative_map_aid'}."' ";
    }

    $sql .= 'and ce.evidence_type_id in ('.$args{'evidence_type_ids'}.') ' 
        if $args{'evidence_type_ids'};

    $sql .= q[
                 order by map_set_name, 
                 map_name, 
                 start_position, 
                 feature_name
    ];

    return $sql;
}

# ----------------------------------------------------
sub feature_name_to_position_sql {

=pod

=head2 feature_name_to_position_sql

The SQL for finding the position of a given feature name.

=cut

    my $self = shift;
    return q[
        select f.start_position
        from   cmap_feature f
        where  (
            upper(f.feature_name)=?
            or
            upper(f.alternate_name)=?
        )
        and    f.map_id=?
    ];
}

# ----------------------------------------------------
sub fill_out_maps_by_map_sql {

=pod

=head2 fill_out_maps_by_map_sql

The SQL for finding basic info on a map.

=cut

    my $self = shift;
    return q[
        select map.map_id,
               map.accession_id as map_aid,
               map.map_name,
               ms.map_set_id,
               ms.accession_id as map_set_aid,
               ms.short_name as map_set_name,
               s.common_name as species_name
        from   cmap_map map,
               cmap_map_set ms,
               cmap_species s
        where  map.accession_id=?
        and    map.map_set_id=ms.map_set_id
        and    ms.species_id=s.species_id
    ];
}

# ----------------------------------------------------
sub fill_out_maps_by_map_set_sql {

=pod

=head2 fill_out_maps_by_map_set_sql

The SQL for finding basic info on a map.

=cut

    my $self = shift;
    return q[
        select ms.map_set_id,
               ms.short_name as map_set_name,
               ms.accession_id as map_set_aid,
               s.common_name as species_name
        from   cmap_map_set ms,
               cmap_species s
        where  ms.accession_id=?
        and    ms.species_id=s.species_id
    ];
}

# ----------------------------------------------------
sub feature_detail_data_sql {

=pod

=head2 feature_detail_data_sql

The SQL for finding basic info on a feature.

=cut

    my $self = shift;
    return q[
        select     f.feature_id, 
                   f.accession_id, 
                   f.map_id,
                   f.feature_type_id,
                   f.feature_name,
                   f.alternate_name,
                   f.is_landmark,
                   f.start_position,
                   f.stop_position,
                   f.dbxref_name,
                   f.dbxref_url,
                   fn.note,
                   ft.feature_type,
                   map.map_name,
                   map.accession_id as map_aid,
                   ms.map_set_id,
                   ms.accession_id as map_set_aid,
                   ms.short_name as map_set_name,
                   s.species_id,
                   s.common_name as species_name,
                   mt.map_type,
                   mt.map_units
        from       cmap_feature f
        left join  cmap_feature_note fn
        on         f.feature_id=fn.feature_id
        inner join cmap_feature_type ft
        on         f.feature_type_id=ft.feature_type_id
        inner join cmap_map map
        on         f.map_id=map.map_id
        inner join cmap_map_set ms
        on         map.map_set_id=ms.map_set_id
        inner join cmap_species s
        on         ms.species_id=s.species_id
        inner join cmap_map_type mt
        on         ms.map_type_id=mt.map_type_id
        where      f.accession_id=?
    ];
}

# ----------------------------------------------------
sub form_data_ref_map_sets_sql {

=pod

=head2 form_data_ref_map_sets_sql

The SQL for finding all reference map sets.

=cut

    my $self = shift;

    return q[
        select   ms.accession_id, 
                 ms.map_set_id,
                 ms.short_name as map_set_name,
                 ms.display_order,
                 ms.published_on,
                 s.common_name as species_name,
                 s.display_order
        from     cmap_map_set ms,
                 cmap_species s
        where    ms.can_be_reference_map=1
        and      ms.is_enabled=1
        and      ms.species_id=s.species_id
        order by s.display_order,
                 species_name,
                 ms.display_order,
                 ms.published_on desc,
                 ms.map_set_name
    ];
}

# ----------------------------------------------------
sub form_data_ref_maps_sql {

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
sub map_data_map_ids_by_single_reference_map {

=pod

=head2 map_data_map_ids_by_single_reference_map

The SQL for finding all the maps of a given study which
have some correspondence to a given region of a reference
map.

=cut

    my ( $self, %args )   = @_;
    my @evidence_type_ids = @{ $args{'evidence_type_ids'} || [] };

    if ( @evidence_type_ids ) {
        return q[
            select   distinct map.map_id,
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
                     mt.map_type_id,
                     mt.map_type,
                     mt.map_units,
                     mt.is_relational_map,
                     mt.shape as default_shape,
                     mt.width as default_width,
                     mt.color as default_color,
                     s.species_id,
                     s.common_name as species_name
            from     cmap_map map,
                     cmap_feature f1, 
                     cmap_feature f2, 
                     cmap_correspondence_lookup cl,
                     cmap_feature_correspondence fc,
                     cmap_correspondence_evidence ce,
                     cmap_map_set ms,
                     cmap_species s,
                     cmap_map_type mt
            where    f1.map_id=?
            and      (
                ( f1.start_position>=? and
                  f1.start_position<=? )
                or   (
                    f1.stop_position is not null and
                    f1.start_position<=? and
                    f1.stop_position>=?
                )
            )
            and      f1.feature_id=cl.feature_id1
            and      cl.feature_correspondence_id=fc.feature_correspondence_id
            and      fc.is_enabled=1
            and      fc.feature_correspondence_id=ce.feature_correspondence_id
            and      ce.evidence_type_id in (].
            join( ',', @evidence_type_ids ).q[)
            and      cl.feature_id2=f2.feature_id
            and      f2.map_id=map.map_id
            and      map.map_set_id=?
            and      map.map_id<>?
            and      map.map_set_id=ms.map_set_id
            and      ms.map_type_id=mt.map_type_id
            and      ms.species_id=s.species_id
        ];
    }
    else {
        return q[
            select   distinct map.map_id,
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
                     mt.map_type_id,
                     mt.map_type,
                     mt.map_units,
                     mt.is_relational_map,
                     mt.shape as default_shape,
                     mt.width as default_width,
                     mt.color as default_color,
                     s.species_id,
                     s.common_name as species_name
            from     cmap_map map,
                     cmap_feature f1, 
                     cmap_feature f2, 
                     cmap_map_set ms,
                     cmap_species s,
                     cmap_map_type mt,
                     cmap_correspondence_lookup cl,
                     cmap_feature_correspondence fc
            where    f1.map_id=?
            and      (
                ( f1.start_position>=? and
                  f1.start_position<=? )
                or   (
                    f1.stop_position is not null and
                    f1.start_position<=? and
                    f1.stop_position>=?
                )
            )
            and      f1.feature_id=cl.feature_id1
            and      cl.feature_correspondence_id=fc.feature_correspondence_id
            and      fc.is_enabled=1
            and      cl.feature_id2=f2.feature_id
            and      f2.map_id=map.map_id
            and      map.map_set_id=?
            and      map.map_id<>?
            and      map.map_set_id=ms.map_set_id
            and      ms.map_type_id=mt.map_type_id
            and      ms.species_id=s.species_id
        ];
    }

    return 1;
}

# ----------------------------------------------------
sub map_stop_sql {

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
sub map_start_sql {

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

# ----------------------------------------------------
sub set_date_format {

=pod

=head2 set_date_format

The SQL for setting the proper date format.

=cut

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

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2002-3 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
