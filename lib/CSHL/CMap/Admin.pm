package CSHL::CMap::Admin;

# $Id: Admin.pm,v 1.1.1.1 2002-07-31 23:27:25 kycl4rk Exp $

=head1 NAME

CSHL::CMap::Admin - admin functions (update, create, etc.)

=head1 SYNOPSIS

  use CSHL::CMap::Admin;
  blah blah blah

=head1 DESCRIPTION

Eventually all the database interaction currently in
CSHL::CMap::Apache::AdminViewer will be moved here so that it can be
shared by my "cmap_admin.pl" script.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.1.1.1 $)[-1];

use CSHL::CMap;
use base 'CSHL::CMap';
use CSHL::CMap::Constants;

# ----------------------------------------------------
sub feature_search {

=pod

=head2 feature_search

Find all the features matching some criteria.

=cut
    my ( $self, %args ) = @_;
    my $feature_name    = uc $args{'feature_name'} or 
                          $self->error('No feature name');
    $feature_name       =~ s/\*/%/g; # make stars into SQL wildcards
    my $map_aid         = $args{'map_aid'}         ||             '';
    my $feature_type_id = $args{'feature_type_id'} ||              0;
    my $field_name      = $args{'field_name'}      || 'feature_name';
    my $order_by        = $args{'order_by'}        || 'feature_name';
    my $limit_start     = $args{'limit_start'}     ||              0;
    my $db              = $self->db;
    my $comparison      = $feature_name =~ m/%/ ? 'like' : '=';

    my $where = $field_name eq 'both'
        ? qq[
            where  (
                upper(f.feature_name) $comparison "$feature_name"
                or
                upper(f.alternate_name) $comparison "$feature_name"
            )
        ]
        : qq[where upper(f.$field_name) $comparison "$feature_name"]
    ;

    my $count_sql = qq[
        select count(f.feature_id)
        from   cmap_feature f,
               cmap_map map
        $where
        and    f.map_id=map.map_id
    ];
    $count_sql .= "and map.accession_id=$map_aid "                  if $map_aid;
    $count_sql .= "and f.feature_type_id=$feature_type_id " if $feature_type_id;
    my $no_features = $db->selectrow_array( $count_sql );

    my $sql = qq[
        select f.feature_id, 
               f.feature_name,
               f.alternate_name,
               f.start_position,
               f.stop_position,
               ft.feature_type,
               map.map_name,
               map.map_id,
               ms.map_set_id,
               ms.short_name as map_set_name,
               s.species_id,
               s.common_name as species_name,
               mt.map_type
        from   cmap_feature f,
               cmap_feature_type ft,
               cmap_map map,
               cmap_map_set ms,
               cmap_species s,
               cmap_map_type mt
        $where 
        and f.feature_type_id=ft.feature_type_id
        and f.map_id=map.map_id
        and map.map_set_id=ms.map_set_id
        and ms.species_id=s.species_id
        and ms.map_type_id=mt.map_type_id
    ];
    $sql .= "and map.accession_id=$map_aid "                  if $map_aid;
    $sql .= "and f.feature_type_id=$feature_type_id " if $feature_type_id;
    $sql .= "order by $order_by ";
    $sql .= "limit $limit_start," . MAX_CHILD_ELEMENTS;

    my $features = $db->selectall_arrayref( $sql, { Columns => {} } );

    return {
        total_count => $no_features,
        features    => $features,
    };
}

# ----------------------------------------------------
sub feature_type_by_id {

=pod

=head2 feature_type_by_id  

Find all feature types by the internal ID.

=cut
    my ( $self, %args ) = @_;
    my $feature_type_id = $args{'feature_type_id'} or 
        $self->error('No feature type id');
    
    return $self->db->selectrow_array(
        q[
            select ft.feature_type
            from   cmap_feature_type ft
            where  feature_type_id=?
        ],
        {}, 
        ( $feature_type_id )
    );
}


# ----------------------------------------------------
sub feature_name_by_id {

=pod

=head2 feature_name_by_id

Find a feature's name by either its internal or accession ID.

=cut
    my ( $self, %args ) = @_;
    my $feature_id      = $args{'feature_id'} || 0;
    my $feature_aid     = $args{'feature_aid'} || 0;
    $self->error('Need either feature id or accession id') 
        unless $feature_id || $feature_aid;
    
    my $search_field = $feature_id ? 'feature_id' : 'accession_id';
    my $sql = qq[
        select f.feature_name
        from   cmap_feature f
        where  $search_field=?
    ];

    return $self->db->selectrow_array(
        $sql, {}, ( $feature_id || $feature_aid )
    );
}

# ----------------------------------------------------
sub map_info_by_id {

=pod

=head2 map_info_by_id

Find a map's basic info by either its internal or accession ID.

=cut
    my ( $self, %args ) = @_;
    my $map_id          = $args{'map_id'} || 0;
    my $map_aid         = $args{'map_aid'} || 0;
    $self->error('Need either map id or accession id') 
        unless $map_id || $map_aid;
    
    my $search_field = $map_id ? 'map_id' : 'accession_id';
    my $sql = qq[
        select map.map_name,
               map.map_id,
               map.accession_id,
               ms.map_set_id,
               ms.map_set_name,
               s.species_id,
               s.common_name as species_name
        from   cmap_map map,
               cmap_map_set ms,
               cmap_species s
        where  map.$search_field=?
        and    map.map_set_id=ms.map_set_id
        and    ms.species_id=s.species_id
    ];

    my $sth = $self->db->prepare( $sql );
    $sth->execute( $map_id || $map_aid );
    return $sth->fetchrow_hashref;
}

# ----------------------------------------------------
sub feature_types {

=pod

=head2 feature_types

Find all the feature types.

=cut
    my ( $self, %args ) = @_;
    my $order_by        = $args{'order_by'} || 'feature_type';

    return $self->db->selectall_arrayref(
        qq[
            select   ft.feature_type_id, 
                     ft.feature_type, 
                     ft.how_to_draw
            from     cmap_feature_type ft
            order by $order_by
        ], 
        { Columns => {} }
    );
}

# ----------------------------------------------------
sub map_sets {

=pod

=head2 map_sets

Return all the map sets.

=cut
    my ( $self, %args ) = @_;
    my $order_by        = $args{'order_by'} || 'species_name,map_set_name';

    return $self->db->selectall_arrayref(
        qq[
            select   ms.map_set_id, 
                     ms.short_name as map_set_name,
                     s.common_name as species_name
            from     cmap_map_set ms,
                     cmap_species s
            where    ms.species_id=s.species_id
            order by $order_by
        ], 
        { Columns => {} }
    );
}

# ----------------------------------------------------
sub reload_correspondence_matrix {
    my ( $self, %args ) = @_;
    my $db              = $self->db or die 'No db handle';

    #
    # Empty the table.
    #
    $db->do('truncate table cmap_correspondence_matrix');

    #
    # Select all the reference maps.
    #
    my @reference_maps = @{
        $db->selectall_arrayref(
            q[
                select   map.map_id,
                         map.accession_id as map_aid,
                         map.map_name,
                         ms.accession_id map_set_aid,
                         ms.short_name as map_set_name,
                         s.accession_id as species_aid,
                         s.common_name as species_name
                from     cmap_map map,
                         cmap_map_set ms,
                         cmap_species s
                where    map.map_set_id=ms.map_set_id
                and      ms.can_be_reference_map=1
                and      ms.species_id=s.species_id
                order by map_set_name, map_name
            ],
            { Columns => {} }
        )
    };

    print("Updating ", scalar @reference_maps, " reference maps.\n");

    #
    # Go through each map and figure the number of correspondences.
    #
    my ( $i, $new_records ); # counters
    for my $map ( @reference_maps ) {
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
                         ms.short_name as map_set_name,
                         s.accession_id as species_aid,
                         s.common_name as species_name
                from     cmap_feature f1, 
                         cmap_feature f2, 
                         cmap_correspondence_lookup cl,
                         cmap_map map,
                         cmap_map_set ms,
                         cmap_species s
                where    f1.map_id=?
                and      f1.feature_id=cl.feature_id1
                and      cl.feature_id2=f2.feature_id
                and      f2.map_id<>?
                and      f2.map_id=map.map_id
                and      map.map_set_id=ms.map_set_id
                and      ms.can_be_reference_map=1
                and      ms.species_id=s.species_id
                group by map.accession_id,
                         map.map_name,
                         ms.accession_id,
                         ms.short_name,
                         s.accession_id,
                         s.common_name
                order by map_set_name, map_name
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
                         ms.short_name as map_set_name,
                         s.accession_id as species_aid,
                         s.common_name as species_name
                from     cmap_feature f1,
                         cmap_feature f2,
                         cmap_correspondence_lookup cl,
                         cmap_map map,
                         cmap_map_set ms,
                         cmap_species s
                where    f1.map_id=?
                and      f1.feature_id=cl.feature_id1
                and      cl.feature_id2=f2.feature_id
                and      f2.map_id<>?
                and      f2.map_id=map.map_id
                and      map.map_set_id=ms.map_set_id
                and      ms.can_be_reference_map=0
                and      ms.species_id=s.species_id
                group by ms.accession_id,
                         ms.short_name,
                         s.accession_id,
                         s.common_name
                order by map_set_name
            ],
            { Columns => {} },
            ( $map->{'map_id'}, $map->{'map_id'} )
        );

        for my $corr ( @$map_correspondences, @$map_set_correspondences ) {
            next if $corr->{'map_set_aid'} eq $map->{'map_set_aid'};
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
                    $map->{'map_aid'}, 
                    $map->{'map_name'},
                    $map->{'map_set_aid'},
                    $map->{'species_aid'},
                    $corr->{'map_aid'}, 
                    $corr->{'map_name'},
                    $corr->{'map_set_aid'},
                    $corr->{'species_aid'},
                    $corr->{'no_correspondences'},
                )
            );

            $new_records++;
        }
    }

    print("\n$new_records new records inserted.\n");
}

# ----------------------------------------------------
sub species {

=pod

=head2 species

Return all the species.

=cut
    my ( $self, %args ) = @_;
    my $order_by        = $args{'order_by'} || 'common_name';

    return $self->db->selectall_arrayref(
        qq[
            select   s.species_id, 
                     s.common_name, 
                     s.full_name
            from     cmap_species s
            order by $order_by
        ], 
        { Columns => {} }
    );
}

1;

# ----------------------------------------------------
# I should have been a pair of ragged claws,
# Scuttling across the floors of silent seas.
# T. S. Eliot
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
