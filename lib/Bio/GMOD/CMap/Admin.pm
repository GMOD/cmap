package Bio::GMOD::CMap::Admin;

# $Id: Admin.pm,v 1.5 2002-10-04 01:14:42 kycl4rk Exp $

=head1 NAME

Bio::GMOD::CMap::Admin - admin functions (update, create, etc.)

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin;
  blah blah blah

=head1 DESCRIPTION

Eventually all the database interaction currently in
Bio::GMOD::CMap::Apache::AdminViewer will be moved here so that it can be
shared by my "cmap_admin.pl" script.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.5 $)[-1];

use Bio::GMOD::CMap;
use base 'Bio::GMOD::CMap';
use Bio::GMOD::CMap::Constants;

# ----------------------------------------------------
sub correspondence_evidence_delete {

=pod

=head2 correspondence_evidence_delete

Delete a correspondence evidence.

=cut
    my ( $self, %args ) = @_;
    my $corr_evidence_id = $args{'correspondence_evidence_id'} 
        or return $self->error('No correspondence evidence id');

    my $db = $self->db or return;
    my $feature_correspondence_id = $db->selectrow_array(
        q[
            select feature_correspondence_id
            from   cmap_correspondence_evidence
            where  correspondence_evidence_id=?
        ],
        {},
        ( $corr_evidence_id )
    ) or return $self->error('Invalid correspondence evidence id');

    $db->do(
        q[
            delete
            from   cmap_correspondence_evidence
            where  correspondence_evidence_id=?
        ],
        {},
        ( $corr_evidence_id )
    );

    return $feature_correspondence_id; 
}

# ----------------------------------------------------
sub dbxref_delete {

=pod

=head2 dbxref_delete

Delete a database cross reference.

=cut
    my ( $self, %args ) = @_;
    my $dbxref_id       = $args{'dbxref_id'} or return $self->error(
        'No dbxref id'
    );

    my $db = $self->db or return;
    $db->do(
        q[
            delete
            from   cmap_dbxref
            where  dbxref_id=?
        ], 
        {}, 
        ( $dbxref_id )
    );

    return 1;
}

# ----------------------------------------------------
sub evidence_type_delete {

=pod

=head2 evidence_type_delete 

Delete an evidence type.

=cut
    my ( $self, %args )  = @_;
    my $evidence_type_id = $args{'evidence_type_id'} or return $self->error(
        'No evidence type id'
    );

    my $db  = $self->db or return;
    my $sth = $db->prepare(
        q[
            select   count(ce.evidence_type_id) as no_evidences, 
                     et.evidence_type
            from     cmap_correspondence_evidence ce,
                     cmap_evidence_type et
            where    ce.evidence_type_id=?
            and      ce.evidence_type_id=et.evidence_type_id
            group by evidence_type
        ]
    );
    $sth->execute( $evidence_type_id );
    my $hr = $sth->fetchrow_hashref;

    if ( $hr->{'no_evidences'} > 0 ) {
        return $self->error(
            "Unable to delete evidence type '", $hr->{'evidence_type'},
            "' as ", $hr->{'no_evidences'},
            " evidences are linked to it."
        );
    }
    else {
        $db->do(
            q[
                delete
                from    cmap_evidence_type
                where   evidence_type_id=?
            ],
            {},
            ( $evidence_type_id )
        );
    }

    return 1;
}

# ----------------------------------------------------
sub feature_delete {

=pod

=head2 feature_delete

Delete a feature.

=cut
    my ( $self, %args ) = @_;
    my $feature_id      = $args{'feature_id'} or return $self->error(
        'No feature id'
    );

    my $db     = $self->db or return;
    my $map_id = $db->selectrow_array(
        q[
            select map_id
            from   cmap_feature
            where  feature_id=?
        ],
        {},
        ( $feature_id )
    ) or return $self->error("Invalid feature id ($feature_id)");

    my $feature_correspondence_ids = $db->selectcol_arrayref(
        q[
            select feature_correspondence_id
            from   cmap_correspondence_lookup
            where  feature_id1=?
        ],
        {},
        ( $feature_id )
    );

    for my $feature_correspondence_id ( @$feature_correspondence_ids ) {
        $self->feature_correspondence_delete(
            feature_correspondence_id => $feature_correspondence_id
        ) or return;
    }

    $db->do(
        q[
            delete
            from    cmap_feature
            where   feature_id=?
        ],
        {},
        ( $feature_id )
    );

    return $map_id;
}

# ----------------------------------------------------
sub feature_correspondence_delete {

=pod

=head2 feature_correspondence_delete

Delete a feature correspondence.

=cut
    my ( $self, %args ) = @_;
    my $feature_corr_id = $args{'feature_correspondence_id'} or
        return $self->error('No feature correspondence id');
    my $db              = $self->db or return;
    my $evidence_ids    = $db->selectcol_arrayref(
        q[
            select correspondence_evidence_id
            from   cmap_correspondence_evidence
            where  feature_correspondence_id=?
        ],
        {},
        ( $feature_corr_id )
    );
    
    for my $evidence_id ( @$evidence_ids ) {
        $self->correspondence_evidence_delete(
            correspondence_evidence_id => $evidence_id
        ) or return;
    }

    for my $table ( 
        qw[ cmap_correspondence_lookup cmap_feature_correspondence ]
    ) {
        $db->do(
            qq[
                delete
                from   $table
                where  feature_correspondence_id=?
            ],
            {},
            ( $feature_corr_id )
        );
    }

    return 1;
}

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
    my $db              = $self->db or return;
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
    $count_sql            .= "and map.accession_id=$map_aid " if $map_aid;
    $count_sql            .= "and f.feature_type_id=$feature_type_id " 
                             if $feature_type_id;
    my $no_features        = $db->selectrow_array( $count_sql );
    my $max_child_elements = $self->config('max_child_elements');

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
    $sql .= "limit $limit_start," . $max_child_elements;

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
    
    my $db = $self->db or return;
    return $db->selectrow_array(
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

    my $db = $self->db or return;
    return $db->selectrow_array(
        $sql, {}, ( $feature_id || $feature_aid )
    );
}

# ----------------------------------------------------
sub feature_type_delete {

=pod

=head2 feature_type_delete

Delete a feature type.

=cut
    my ( $self, %args ) = @_;
    my $feature_type_id = $args{'feature_type_id'} or 
        return $self->error('No feature type id');

    my $db  = $self->db or return;
    my $sth = $db->prepare(
        q[
            select   count(f.feature_type_id) as no_features, 
                     ft.feature_type
            from     cmap_feature f,
                     cmap_feature_type ft
            where    f.feature_type_id=?
            and      f.feature_type_id=ft.feature_type_id
            group by feature_type
        ]
    );
    $sth->execute( $feature_type_id );
    my $hr = $sth->fetchrow_hashref;

    if ( $hr->{'no_features'} > 0 ) {
        return $self->error(
            "Unable to delete feature type '", $hr->{'feature_type'},
            "' as ", $hr->{'no_features'},
            " features are linked to it."
        );
    }
    else {
        $db->do(
            q[
                delete
                from   cmap_feature_type
                where  feature_type_id=?
            ],
            {}, ( $feature_type_id )
        );
    }

    return 1;
}

# ----------------------------------------------------
sub feature_types {

=pod

=head2 feature_types

Find all the feature types.

=cut
    my ( $self, %args ) = @_;
    my $order_by        = $args{'order_by'} || 'feature_type';

    my $db = $self->db or return;
    return $db->selectall_arrayref(
        qq[
            select   ft.feature_type_id, 
                     ft.feature_type, 
                     ft.shape
            from     cmap_feature_type ft
            order by $order_by
        ], 
        { Columns => {} }
    );
}

# ----------------------------------------------------
sub map_delete {

=pod

=head2 map_delete

Delete a map.

=cut
    my ( $self, %args ) = @_;
    my $map_id          = $args{'map_id'} or return $self->error('No map id');
    my $db              = $self->db or return;
    my $map_set_id      = $db->selectrow_array(
        q[
            select map_set_id
            from   cmap_map
            where  map_id=?
        ],
        {},
        ( $map_id )
    );
    
    my $feature_ids = $db->selectcol_arrayref(
        q[
            select feature_id
            from   cmap_feature
            where  map_id=?
        ],
        {},
        ( $map_id )
    );

    for my $feature_id ( @$feature_ids ) {
        $self->feature_delete( feature_id => $feature_id ) or return;
    }
    
    $db->do(
        q[
            delete
            from    cmap_map
            where   map_id=?
        ],
        {},
        ( $map_id )
    );

    return $map_set_id;
}

# ----------------------------------------------------
sub map_set_delete {

=pod

=head2 map_set_delete

Delete a map set.

=cut
    my ( $self, %args ) = @_;
    my $map_set_id      = $args{'map_set_id'} or return $self->error(
        'No map set id'
    );
    my $db              = $self->db or return;
    my $map_ids         = $db->selectcol_arrayref( 
        q[          
            select map_id
            from   cmap_map
            where  map_set_id=?
        ],  
        {},
        ( $map_set_id )
    );

    for my $map_id ( @$map_ids ) {
        $self->map_delete( map_id => $map_id ) or return;
    }

    $db->do(    
        q[         
            delete  
            from   cmap_map_set
            where  map_set_id=?
        ],      
        {},     
        ( $map_set_id )
    ); 

    return 1;
}

# ----------------------------------------------------
sub map_type_delete {

=pod

=head2 map_type_delete 

Delete a map type.

=cut
    my ( $self, %args ) = @_;
    my $map_type_id     = $args{'map_type_id'} or 
        return $self->error('No map type id');

    my $db  = $self->db or return;
    my $sth = $db->prepare(
        q[
            select   count(ms.map_set_id) as no_map_sets, 
                     mt.map_type
            from     cmap_map_set ms, cmap_map_type mt
            where    ms.map_type_id=?
            and      ms.map_type_id=mt.map_type_id
            group by map_type 
        ]
    );
    $sth->execute( $map_type_id );
    my $hr = $sth->fetchrow_hashref;

    if ( $hr->{'no_map_sets'} > 0 ) {
        return $self->error(
            "Unable to delete map type '", $hr->{'map_type'}, 
            "' as ", $hr->{'no_map_sets'},
            " map sets are linked to it."
        );
    }       
    else {  
        $db->do(
            q[
                delete
                from   cmap_map_type
                where  map_type_id=?
            ],
            {}, ( $map_type_id )
        );
    }

    return 1;
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

    my $db  = $self->db or return;
    my $sth = $db->prepare( $sql );
    $sth->execute( $map_id || $map_aid );
    return $sth->fetchrow_hashref;
}

# ----------------------------------------------------
sub map_sets {

=pod

=head2 map_sets

Return all the map sets.

=cut
    my ( $self, %args ) = @_;
    my $order_by        = $args{'order_by'} || 'species_name,map_set_name';

    my $db  = $self->db or return;
    return $db->selectall_arrayref(
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
    my $db              = $self->db or return;

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
    my $db              = $self->db or return;

    return $db->selectall_arrayref(
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

# ----------------------------------------------------
sub species_delete {

=pod

=head2 species_delete

Delete a species.

=cut
    my ( $self, %args ) = @_;
    my $species_id      = $args{'species_id'} or 
        return $self->error('No species id');

    my $db  = $self->db or return;
    my $sth = $db->prepare(
        q[
            select   count(ms.map_set_id) as no_map_sets, 
                     s.common_name
            from     cmap_map_set ms, cmap_species s
            where    s.species_id=?
            and      ms.species_id=s.species_id
            group by common_name
        ]
    );
    $sth->execute( $species_id );
    my $hr = $sth->fetchrow_hashref;

    if ( $hr->{'no_map_sets'} > 0 ) {
        return $self->error(
            'Unable to delete ', $hr->{'common_name'},
            ' because ', $hr->{'no_map_sets'}, ' map sets are linked to it.'
        );
    }
    else {
        $db->do(
            q[
                delete
                from   cmap_species
                where  species_id=?
            ],
            {}, ( $species_id )
        );
    }

    return 1;
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
