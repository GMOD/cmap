package Bio::GMOD::CMap::Data::Generic;

# $Id: Generic.pm,v 1.9 2002-09-13 23:47:04 kycl4rk Exp $

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
$VERSION = (qw$Revision: 1.9 $)[-1];

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
    my ( $self, %args ) = @_;
    my $order_by        = $args{'order_by'}    || '';
    my $restrict_by     = $args{'restrict_by'} || '';
    my $sql             = qq[
        select   f.feature_id,
                 f.accession_id,
                 f.feature_name,
                 f.alternate_name,
                 f.is_landmark,
                 f.start_position,
                 f.stop_position,
                 ft.feature_type,
                 ft.default_rank,
                 ft.is_visible,
                 ft.shape,
                 ft.color,
                 map.accession_id as map_aid,
                 mt.map_units
        from     cmap_feature f,
                 cmap_feature_type ft,
                 cmap_map map,
                 cmap_map_set ms,
                 cmap_map_type mt
        where    f.map_id=?
        and      f.feature_type_id=ft.feature_type_id
        and      f.start_position>=?
        and      f.start_position<=?
        and      f.map_id=map.map_id
        and      map.map_set_id=ms.map_set_id
        and      ms.map_type_id=mt.map_type_id
    ];
    $sql .= "and ft.accession_id='$restrict_by' " if $restrict_by;
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
sub correspondences_count_by_single_map_sql {

=pod

=head2 correspondences_count_by_single_map_sql

The SQL for finding the number of correspondences by for one map.

=cut
    my $self = shift;

    return q[
        select   count(f2.feature_id) as no_correspondences,
                 s.common_name as species_name,
                 mt.map_type,
                 mt.display_order as map_type_display_order,
                 ms.accession_id as map_set_aid,
                 ms.short_name as map_set_name,
                 ms.published_on,
                 ms.can_be_reference_map,
                 ms.display_order as map_set_display_order,
                 map2.accession_id as map_aid,
                 map2.map_name
        from     cmap_map map1,
                 cmap_map map2,
                 cmap_map_set ms,
                 cmap_map_type mt,
                 cmap_species s,
                 cmap_feature f1,
                 cmap_feature f2,
                 cmap_correspondence_lookup cl
        where    map1.accession_id=?
        and      map1.map_id=f1.map_id
        and      f1.start_position>=? 
        and      f1.start_position<=?
        and      f1.feature_id=cl.feature_id1
        and      cl.feature_id2=f2.feature_id
        and      f2.map_id=map2.map_id
        and      map2.accession_id<>?
        and      map2.map_set_id=ms.map_set_id
        and      ms.map_type_id=mt.map_type_id
        and      ms.species_id=s.species_id
        group by common_name,
                 mt.map_type,
                 mt.display_order,
                 ms.map_set_id,
                 ms.short_name,
                 ms.accession_id,
                 map_set_name,
                 ms.published_on,
                 ms.can_be_reference_map,
                 ms.display_order,
                 mt.display_order,
                 map2.map_id,
                 map2.accession_id,
                 map2.map_name
    ];
}

# ----------------------------------------------------
sub correspondences_count_by_map_set_sql {

=pod

=head2 correspondences_count_by_map_set_sql

The SQL for finding the number of correspondences for a whole map set.

=cut
    my $self = shift;

    return qq[
        select   count(f2.feature_id) as no_correspondences,
                 s.common_name as species_name,
                 mt.map_type,
                 mt.display_order as map_type_display_order,
                 ms.accession_id as map_set_aid,
                 ms.short_name as map_set_name,
                 ms.published_on,
                 ms.can_be_reference_map,
                 ms.display_order as map_set_display_order,
                 map2.accession_id as map_aid,
                 map2.map_name
        from     cmap_map map1,
                 cmap_map map2,
                 cmap_map_set ms,
                 cmap_map_type mt,
                 cmap_species s,
                 cmap_feature f1,
                 cmap_feature f2,
                 cmap_correspondence_lookup cl
        where    map1.map_set_id=?
        and      map1.map_id=f1.map_id
        and      f1.feature_id=cl.feature_id1
        and      cl.feature_id2=f2.feature_id
        and      f2.map_id=map2.map_id
        and      map2.map_set_id<>?
        and      map2.map_set_id=ms.map_set_id
        and      ms.map_type_id=mt.map_type_id
        and      ms.species_id=s.species_id
        group by s.species_name,
                 mt.map_type,
                 mt.display_order,
                 ms.map_set_id,
                 ms.map_set_name,
                 ms.published_on,
                 mt.display_order,
                 map2.map_id,
                 map2.map_name
    ];
}

# ----------------------------------------------------
sub correspondences_count_by_multi_maps_sql {

=pod

=head2 correspondences_count_by_multi_maps_sql

The SQL for finding the number of correspondences for many maps 
(like those in a map set).

=cut
    my ( $self, $map_ids ) = @_;

    return qq[
        select   count(f2.feature_id) as no_correspondences,
                 s.common_name as species_name,
                 mt.map_type,
                 mt.display_order as map_type_display_order,
                 ms.accession_id as map_set_aid,
                 ms.short_name as map_set_name,
                 ms.published_on,
                 ms.can_be_reference_map,
                 ms.display_order as map_set_display_order,
                 map2.accession_id as map_aid,
                 map2.map_name
        from     cmap_map map2,
                 cmap_map_set ms,
                 cmap_map_type mt,
                 cmap_species s,
                 cmap_feature f1,
                 cmap_feature f2,
                 cmap_correspondence_lookup cl
        where    f1.map_id in ($map_ids)
        and      f1.feature_id=cl.feature_id1
        and      cl.feature_id2=f2.feature_id
        and      f2.map_id not in ($map_ids)
        and      f2.map_id=map2.map_id
        and      map2.map_set_id=ms.map_set_id
        and      ms.map_type_id=mt.map_type_id
        and      ms.species_id=s.species_id
        group by s.common_name,
                 mt.map_type,
                 mt.display_order,
                 ms.map_set_id,
                 ms.accession_id,
                 ms.short_name,
                 ms.published_on,
                 ms.can_be_reference_map,
                 ms.display_order,
                 mt.display_order,
                 map2.map_id,
                 map2.accession_id,
                 map2.map_name
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
                 f.accession_id as feature_aid,
                 f.start_position,
                 f.stop_position,
                 ft.feature_type,
                 map.map_id,
                 map.accession_id as map_aid,
                 map.map_name,
                 ms.map_set_id,
                 ms.accession_id as map_set_aid,
                 ms.short_name as map_set_name,
                 mt.map_units,
                 s.common_name as species_name,
                 fc.feature_correspondence_id,
                 fc.accession_id as feature_correspondence_aid
        from     cmap_correspondence_lookup cl, 
                 cmap_feature_correspondence fc,
                 cmap_feature f,
                 cmap_feature_type ft,
                 cmap_map map,
                 cmap_map_set ms,
                 cmap_map_type mt,
                 cmap_species s
        where    cl.feature_correspondence_id=fc.feature_correspondence_id
        and      cl.feature_id1=?
        and      cl.feature_id2=f.feature_id
        and      f.feature_type_id=ft.feature_type_id
        and      f.map_id=map.map_id
        and      map.map_set_id=ms.map_set_id
        and      ms.species_id=s.species_id
        and      ms.map_type_id=mt.map_type_id
    ];

    $sql .= "and map.accession_id='".$args{'map_aid'}."'" if $args{'map_aid'};

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

=head2 fill_out_maps_by_map_sql

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
        select f.feature_id, 
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
               ft.feature_type,
               map.map_name,
               map.accession_id as map_aid,
               ms.map_set_id,
               ms.accession_id as map_set_aid,
               ms.short_name as map_set_name,
               s.species_id,
               s.common_name as species_name
        from   cmap_feature f,
               cmap_feature_type ft,
               cmap_map map,
               cmap_map_set ms,
               cmap_species s
        where  f.feature_id=?
        and    f.feature_type_id=ft.feature_type_id
        and    f.map_id=map.map_id
        and    map.map_set_id=ms.map_set_id
        and    ms.species_id=s.species_id
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
    my $self = shift;
    return q[
        select   distinct map.map_id
        from     cmap_map map,
                 cmap_feature f1, 
                 cmap_feature f2, 
                 cmap_correspondence_lookup cl
        where    f1.map_id=?
        and      f1.start_position>=?
        and      f1.start_position<=?
        and      f1.feature_id=cl.feature_id1
        and      cl.feature_id2=f2.feature_id
        and      f2.map_id=map.map_id
        and      map.map_set_id=?
        and      map.map_id<>?
    ];
}

# ----------------------------------------------------
sub map_data_feature_correspondence_by_map_sql {

=pod

=head2 map_data_feature_correspondence_by_map_sql

The SQL for finding all correspondences between two maps.

=cut
    my $self = shift;
    
    return q[
        select   f1.feature_id as feature_id1,
                 f2.feature_id as feature_id2, 
                 cl.feature_correspondence_id
        from     cmap_feature f1, 
                 cmap_feature f2, 
                 cmap_correspondence_lookup cl
        where    f1.map_id=?
        and      f1.start_position>=?
        and      f1.start_position<=?
        and      f1.feature_id=cl.feature_id1
        and      cl.feature_id2=f2.feature_id
        and      f2.map_id=?
        and      f2.start_position>=?
        and      f2.start_position<=?
    ];
}

# ----------------------------------------------------
sub map_data_feature_correspondence_by_map_set_sql{

=pod

=head2 map_data_feature_correspondence_by_map_set_sql

The SQL for finding all correspondences between two maps.

=cut
    my $self = shift;
    
    return q[
        select   f1.feature_id as feature_id1,
                 f2.feature_id as feature_id2, 
                 cl.feature_correspondence_id
        from     cmap_map map,
                 cmap_feature f1, 
                 cmap_feature f2, 
                 cmap_correspondence_lookup cl
        where    map.map_set_id=?
        and      map.map_id=f1.map_id
        and      f1.feature_id=cl.feature_id1
        and      cl.feature_id2=f2.feature_id
        and      f2.map_id=?
        and      f2.start_position>=?
        and      f2.start_position<=?
    ];
}

# ----------------------------------------------------
sub map_data_feature_correspondence_by_multi_maps_sql{

=pod

=head2 map_data_feature_correspondence_by_map_set_sql

The SQL for finding all correspondences between two maps.

=cut
    my ( $self, $map_ids ) = @_;
    
    return qq[
        select   f1.feature_id as feature_id1,
                 f2.feature_id as feature_id2, 
                 cl.feature_correspondence_id
        from     cmap_map map,
                 cmap_feature f1, 
                 cmap_feature f2, 
                 cmap_correspondence_lookup cl
        where    map.map_id in ($map_ids)
        and      map.map_id=f1.map_id
        and      f1.feature_id=cl.feature_id1
        and      cl.feature_id2=f2.feature_id
        and      f2.map_id=?
        and      f2.start_position>=?
        and      f2.start_position<=?
    ];
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

Copyright (c) 2002 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
