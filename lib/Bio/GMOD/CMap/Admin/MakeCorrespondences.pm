package Bio::GMOD::CMap::Admin::MakeCorrespondences;

# $Id: MakeCorrespondences.pm,v 1.4 2002-09-13 05:32:07 kycl4rk Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.4 $)[-1];

use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Utils 'next_number';
use base 'Bio::GMOD::CMap';

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->params( $config, qw[ file db ] );
    return $self;
}

# ----------------------------------------------------
sub make_name_correspondences {
    my ( $self, %args )  = @_;
    my $map_set_id       = $args{'map_set_id'} || 0;
    my $evidence_type_id = $args{'evidence_type_id'} or 
                           return 'No evidence type id';
    my $db               = $self->db;

    #
    # Get all the map sets.
    #
    my $sql = q[
        select   ms.map_set_id, 
                 ms.short_name as map_set_name,
                 mt.is_relational_map
        from     cmap_map_set ms,
                 cmap_map_type mt
        where    ms.map_type_id=mt.map_type_id
    ];
    $sql .= "and ms.map_set_id=$map_set_id " if $map_set_id;
    $sql .= 'order by map_set_name';
    my $map_sets = $db->selectall_arrayref( $sql, { Columns => {} } );

    for my $map_set ( @$map_sets ) {
        #
        # Find all the maps.
        #
        my $maps = $db->selectall_arrayref(
            q[
                select map.map_id, map.map_name
                from   cmap_map map
                where  map_set_id=?
                order by map_name desc
            ],
            { Columns => {} },
            ( $map_set->{'map_set_id'} )
        );

        print "Map set $map_set->{'map_set_name'} has ", 
            scalar @$maps, " maps.\n";

        for my $map ( @$maps ) {
            #
            # Find all the features.
            #
            my $no_features = $db->selectrow_array(
                q[
                    select count(*)
                    from   cmap_feature f
                    where  map_id=?
                ],
                { Columns => {} },
                ( $map->{'map_id'} )
            );

            print "  Map $map->{'map_name'} has $no_features features.\n";

            #
            # Make SQL to find all the places something by this 
            # name occurs on another map.  If it's a relational
            # map, then we'll skip every other map in the map set.
            #
            my $corr_sql =  $map_set->{'is_relational_map'}
                ? qq[
                    select f.feature_id
                    from   cmap_map map,
                           cmap_feature f
                    where  map.map_set_id<>$map_set->{'map_set_id'}
                    and    map.map_id=f.map_id
                    and    (
                        upper(f.feature_name)=?
                        or
                        upper(f.alternate_name)=?
                    )
                ]
                : qq[
                    select f.feature_id
                    from   cmap_feature f
                    where  f.map_id<>$map->{'map_id'}
                    and    (
                        upper(f.feature_name)=?
                        or
                        upper(f.alternate_name)=?
                    )
                ]
            ;

            for my $feature ( 
                @{ $db->selectall_arrayref(
                    q[
                        select f.feature_id, f.feature_name
                        from   cmap_feature f
                        where  map_id=?
                    ],
                    { Columns => {} },
                    ( $map->{'map_id'} )
                ) }
            ) {
                my $upper_name = uc $feature->{'feature_name'} or next;
                for my $corr_id ( 
                    @{ $db->selectcol_arrayref(
                        $corr_sql,
                        {},
                        ( $upper_name, $upper_name )
                    ) }
                ) {
                    #
                    # Skip if a correspondence exists already.
                    #
                    my $count = $db->selectrow_array(
                        q[
                            select count(*)
                            from   cmap_correspondence_lookup
                            where  feature_id1=?
                            and    feature_id2=?
                        ],
                        {},
                        ( $feature->{'feature_id'}, $corr_id )
                    ) || 0;
                    next if $count;

                    my $feature_correspondence_id = next_number(
                        db               => $db,
                        table_name       => 'cmap_feature_correspondence',
                        id_field         => 'feature_correspondence_id',
                    ) or die 'No next number for feature correspondence';

                    #
                    # Create the official correspondence record.
                    #
                    $db->do(
                        q[
                            insert
                            into   cmap_feature_correspondence
                                   ( feature_correspondence_id, accession_id,
                                     feature_id1, feature_id2 )
                            values ( ?, ?, ?, ? )
                        ],
                        {},
                        ( $feature_correspondence_id, 
                          $feature_correspondence_id, 
                          $feature->{'feature_id'}, 
                          $corr_id
                        )
                    );

                    #
                    # Create the evidence.
                    #
                    my $correspondence_evidence_id = next_number(
                        db               => $db,
                        table_name       => 'cmap_correspondence_evidence',
                        id_field         => 'correspondence_evidence_id',
                    ) or die 'No next number for correspondence evidence';

                    $db->do(
                        q[
                            insert
                            into   cmap_correspondence_evidence
                                   ( correspondence_evidence_id, accession_id,
                                     feature_correspondence_id,     
                                     evidence_type_id 
                                   )
                            values ( ?, ?, ?, ? )
                        ],
                        {},
                        ( $correspondence_evidence_id,  
                          $correspondence_evidence_id, 
                          $feature_correspondence_id,   
                          $evidence_type_id
                        )
                    );

                    #
                    # Create the lookup record.
                    #
                    my @insert = (
                        [ $feature->{'feature_id'}, $corr_id ],
                        [ $corr_id, $feature->{'feature_id'} ],
                    );

                    for my $vals ( @insert ) {
                        $db->do(
                            q[
                                insert
                                into   cmap_correspondence_lookup
                                       ( feature_id1, feature_id2,
                                         feature_correspondence_id )
                                values ( ?, ?, ? )
                            ],
                            {},
                            ( $vals->[0],
                              $vals->[1],
                              $feature_correspondence_id
                            )
                        );
                    }
                    
                    print "    Inserted correspondence for feature '", 
                        $feature->{'feature_name'}, "'.\n";
                }
            }
        }
    }

    return 1;
}

1;

# ----------------------------------------------------
# Drive your cart and plow over the bones of the dead.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Admin::MakeCorrespondences - create correspondences

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::MakeCorrespondences;
  blah blah blah

=head1 DESCRIPTION

Blah blah blah.

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

Copyright (c) 2002 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
