package Bio::GMOD::CMap::Admin::MakeCorrespondences;

# $Id: MakeCorrespondences.pm,v 1.20 2003-09-02 16:43:51 kycl4rk Exp $

=head1 NAME

Bio::GMOD::CMap::Admin::MakeCorrespondences - create correspondences

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::MakeCorrespondences;
  blah blah blah

=head1 DESCRIPTION

This module will create automated name-based correspondences.
Basically, it selects every feature from the database (optionally for
only one given map set) and then selects every other feature of the
same type that has either a "feature_name" or "alternate_name"
matching either its "feature_name" or "alternate_name."  The match
must be exact (no suffixes or prefixes), but it is not case-sensitive.
This type of correspondence is likely to be highly error-prone as it
will be very optimistic about what is a valid correspondence (e.g.,
it will create relationships between features named "centromere"), so
it is suggested that you create an evidence like "Automated
name-based" and give it a low ranking in relation to your other
correspondence evidences.

=cut

use strict;
use vars qw( $VERSION $LOG_FH );
$VERSION = (qw$Revision: 1.20 $)[-1];

use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Admin;
use Bio::GMOD::CMap::Utils qw[ next_number ];
use base 'Bio::GMOD::CMap';
use Data::Dumper;

# ----------------------------------------------------
sub make_name_correspondences {
    my ( $self, %args )       = @_;
    my @map_set_ids           = @{ $args{'map_set_ids'}        || [] };
    my @target_map_set_ids    = @{ $args{'target_map_set_ids'} || [] };
    my @skip_feature_type_ids = @{ $args{'skip_feature_type_ids'} || [] };
    my $evidence_type_id      = $args{'evidence_type_id'} or 
                                return 'No evidence type id';
    $LOG_FH                   = $args{'log_fh'} || \*STDOUT;
    my $db                    = $self->db;
    my $admin                 = Bio::GMOD::CMap::Admin->new(
        data_source => $self->data_source
    );

    $self->Print("Making name-based correspondences.\n");

    #
    # Normally we only create name-based correspondences between 
    # features of the same type, but this reads the configuration
    # file and adds in other allowed feature types.
    #
    my %add_name_correspondences;
    for my $line ( $self->config('add_name_correspondence') ) {
        my ( $ft1, $ft2 ) = split /\s+/, $line, 2;
        my $ft_id1 = $db->selectrow_array(
            q[
                select ft.feature_type_id
                from   cmap_feature_type ft
                where  ft.accession_id=?
            ],
            {},
            ( $ft1 ) 
        );
        $self->Print("Can't find feature type '$ft1'!\n") unless $ft_id1;

        my $ft_id2 = $db->selectrow_array(
            q[
                select ft.feature_type_id
                from   cmap_feature_type ft
                where  ft.accession_id=?
            ],
            {},
            ( $ft2 ) 
        );
        $self->Print("Can't find feature type '$ft2'!\n") unless $ft_id2;

        next unless $ft_id1 && $ft_id2;
        $add_name_correspondences{ $ft_id1 }{ $ft_id2 } = 1;
        $add_name_correspondences{ $ft_id2 }{ $ft_id1 } = 1;

    }

    for my $ft_id1 ( keys %add_name_correspondences ) { 
        for my $ft_id2 ( keys %{ $add_name_correspondences{ $ft_id1 } } ) { 
            for my $ft_id3 ( keys %{ $add_name_correspondences{ $ft_id2 } } ) { 
                next if $ft_id1 == $ft_id3;
                $add_name_correspondences{ $ft_id1 }{ $ft_id3 } = 1;
            }
        }
    }

    #
    # Get all the map sets.
    #
    my $sql = q[
        select   ms.map_set_id, 
                 ms.short_name as map_set_name,
                 mt.is_relational_map,
                 s.common_name as species_name
        from     cmap_map_set ms,
                 cmap_map_type mt,
                 cmap_species s
        where    ms.map_type_id=mt.map_type_id
        and      ms.species_id=s.species_id
    ];
    if ( @map_set_ids ) {
        $sql .= 'and ms.map_set_id in (' . join(', ', @map_set_ids) . ')';
    }
    $sql .= 'order by map_set_name';
    my $map_sets = $db->selectall_arrayref( $sql, { Columns => {} } );

    my $feature_sql = q[
        select f.feature_id, 
               f.feature_name,
               f.alternate_name,
               f.feature_type_id
        from   cmap_feature f,
               cmap_feature_type ft
        where  f.map_id=?
        and    f.feature_type_id=ft.feature_type_id
    ];

    if ( @skip_feature_type_ids ) {
        $feature_sql .= 'and ft.feature_type_id not in (' .
            join( ', ', @skip_feature_type_ids ) .
        ')';
    }

    for my $map_set ( @$map_sets ) {
        #
        # Find all the maps.
        #
        my $maps = $db->selectall_arrayref(
            q[
                select map.map_id, map.map_name
                from   cmap_map map
                where  map_set_id=?
                order by map_name
            ],
            { Columns => {} },
            ( $map_set->{'map_set_id'} )
        );

        $self->Print(
            "Map set $map_set->{'species_name'}-$map_set->{'map_set_name'} ",
            "has ", scalar @$maps, " maps.\n"
        );

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

            $self->Print(
                "  Map $map->{'map_name'} has $no_features features.\n"
            );


            for my $feature ( 
                @{ $db->selectall_arrayref(
                    $feature_sql, { Columns => {} }, ( $map->{'map_id'} )
                ) }
            ) {
                my @allowed_ft_ids = ( $feature->{'feature_type_id'} );
                push @allowed_ft_ids, keys %{ $add_name_correspondences{
                    $feature->{'feature_type_id'}
                } || {} };
                my $ft_ids = join(', ', @allowed_ft_ids);

                #
                # Make SQL to find all the places something by this 
                # name occurs on another map.
                #
                my $corr_sql = qq[
                    select f.feature_id, 
                           f.feature_name, 
                           map.map_id,
                           map.map_name,
                           ms.map_set_id,
                           ms.short_name as map_set_name, 
                           s.common_name as species_name
                    from   cmap_map map,
                           cmap_feature f,
                           cmap_map_set ms,
                           cmap_species s
                    where  map.map_id=f.map_id
                    and    (
                        upper(f.feature_name)=?
                        or 
                        upper(f.alternate_name)=?
                    )
                    and    f.feature_type_id in ($ft_ids)
                    and    map.map_set_id=ms.map_set_id
                    and    ms.species_id=s.species_id
                ];

                if ( @target_map_set_ids ) {
                    $corr_sql .= 'and ms.map_set_id in (' .
                        join( ',', @target_map_set_ids )  .
                    ')';
                }

                my $last;
                for my $field ( qw[ feature_name alternate_name ] ) {
                    my $upper_name = uc $feature->{ $field } or next;
                    next if $last && $upper_name eq $last;
                    $last = $upper_name;
                    $self->Print("    Checking $field = '$upper_name'\n");
                    for my $corr ( 
                        @{ $db->selectall_arrayref(
                            $corr_sql,
                            { Columns => {} },
                            ( $upper_name, $upper_name )
                        ) }
                    ) {
                        #
                        # If it's a relational map, then we'll skip
                        # every other map in the map set.
                        #
                        next if $map_set->{'is_relational_map'} &&
                            $map_set->{'map_set_id'} == $corr->{'map_set_id'} &&
                            $map_set->{'map_id'} != $corr->{'map_id'};

                        my $fc_id = $admin->insert_correspondence( 
                            $feature->{'feature_id'},
                            $corr->{'feature_id'},
                            $evidence_type_id,
                        ) or return $self->error( $admin->error );

                        my $map_name = join('-', 
                            $corr->{'species_name'},
                            $corr->{'map_set_name'},
                            $corr->{'map_name'},
                        );

                        $self->Print( 
                            $fc_id > 0
                            ? "      Inserted correspondence to '$map_name'\n"
                            : "      Correspondence existed to '$map_name'\n"
                        );
                    }
                }
            }
        }
    }

    $self->Print("Done.\n");

    return 1;
}

sub Print {
    my $self = shift;
    print $LOG_FH @_;
}

1;

# ----------------------------------------------------
# Drive your cart and plow over the bones of the dead.
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
