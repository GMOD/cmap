package Bio::GMOD::CMap::Data;

# $Id: Data.pm,v 1.29 2003-01-11 03:46:25 kycl4rk Exp $

=head1 NAME

Bio::GMOD::CMap::Data - base data module

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Data;
  my $data = Bio::GMOD::CMap::Data->new;
  my $foo  = $data->foo_data;

=head1 DESCRIPTION

A module for getting data from a database.  Think DBI for whatever
RDBMS you want to use underneath.  I'll try to write generic SQL to
work with anything, and customize it in subclasses.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.29 $)[-1];

use Data::Dumper;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Utils;
use base 'Bio::GMOD::CMap';

# ----------------------------------------------------
sub acc_id_to_internal_id {

=pod

=head2 acc_id_to_internal_id

Given an accession id for a particular table, find the internal id.  Expects:

    table   : the name of the table from which to select
    acc_id  : the value of the accession id
    id_field: (opt.) the name of the internal id field

=cut
    my ( $self, %args ) = @_;
    my $table           = $args{'table'}    or $self->error('No table');
    my $acc_id          = $args{'acc_id'}   or $self->error('No accession id');
    my $id_field        = $args{'id_field'} || '';

    #
    # If no "id_field" param, then strip "cmap_" off the table 
    # name and append "_id".
    #
    unless ( $id_field ) {
        if ( $table =~ m/^cmap_(.+)$/ ) {
            $id_field = $1.'_id';
        }
        else {
            $self->error(qq[No id field and I can't figure it out]);
        }
    }

    my $db = $self->db or return;
    my $id = $db->selectrow_array(
        qq[
            select $id_field
            from   $table
            where  accession_id=?
        ],
        {},
        ( $acc_id )
    ) or $self->error(
        qq[Unable to find internal id for acc. id "$acc_id" in table "$table"]
    );

    return $id;
}

# ----------------------------------------------------
sub cmap_data {

=pod

=head2 cmap_data

Organizes the data for drawing comparative maps.

=cut
    my ( $self, %args )       = @_;
    my $slots                 = $args{'slots'};
    my $include_feature_types = $args{'include_feature_types'};
    my @slot_nos              = keys %$slots;
    my @pos                   = sort { $a <=> $b } grep { $_ >= 0 } @slot_nos;
    my @neg                   = sort { $b <=> $a } grep { $_ <  0 } @slot_nos; 
    my @ordered_slot_nos      = ( @pos, @neg );

    my ( $data, %correspondences, %feature_types );
    for my $slot_no ( @ordered_slot_nos ) {
        my $cur_map = $slots->{ $slot_no };
        my $ref_map = 
            $slot_no > 0  ? $slots->{ $slot_no - 1 } || undef :
            $slot_no < 0  ? $slots->{ $slot_no + 1 } || undef :
            undef
        ;

        $data->{'slots'}{ $slot_no } = $self->map_data( 
            map                   => \$cur_map,         # pass
            correspondences       => \%correspondences, # by
            feature_types         => \%feature_types,   # reference
            reference_map         => $ref_map,
            slot_no               => $slot_no,
            include_feature_types => $include_feature_types,
        );
    }

    $data->{'correspondences'} = \%correspondences;
    $data->{'feature_types'}   = \%feature_types;

    return $data;
}

# ----------------------------------------------------
sub map_data {

=pod

=head2 map_data

Returns the data for drawing comparative maps.

=cut
    my ( $self, %args ) = @_;
    my $db              = $self->db  or return;
    my $sql             = $self->sql or return;

    #
    # Get the arguments.
    #
    my $slot_no               = $args{'slot_no'};
    my $include_feature_types = $args{'include_feature_types'};
    my $map                   = ${ $args{'map'} }; # hashref
    my $reference_map         = $args{'reference_map'};
    my $correspondences       = $args{'correspondences'};
    my $feature_types         = $args{'feature_types'};

    #
    # Sort out the current map.
    #
    my $aid_field   = $map->{'field'};
    my $map_start   = $map->{'start'};
    my $map_stop    = $map->{'stop'};
    my $map_aid     = $aid_field eq 'map_aid'     ? $map->{'aid'} : '';
    my $map_set_aid = $aid_field eq 'map_set_aid' ? $map->{'aid'} : '';
    my $no_flanking_positions = $map->{'no_flanking_positions'} || 0;

#    warn "\n------------------\nslot no = $slot_no\n";
#    warn "map = ", Dumper($map), "\n";
#    warn "ref map = ", Dumper($reference_map), "\n";

    #
    # Understand our reference map.  We can either be comparing our
    # current map to a single reference map or to an entire map set.
    #
    my ( $ref_map_start, $ref_map_stop, $ref_map_set_id, $ref_map_id );
    if ( $reference_map ) {
        my $field      =  $reference_map->{'field'};
        $ref_map_start =  $field eq 'map_set_aid' 
                          ? undef : $reference_map->{'start'};
        $ref_map_stop  =  $field eq 'map_set_aid'
                          ? undef : $reference_map->{'stop'};

        $ref_map_id    =  $field eq 'map_aid'
            ? $self->acc_id_to_internal_id(
                table      => 'cmap_map',
                acc_id     => $reference_map->{'aid'},
            )
            : undef
        ;

        $ref_map_set_id =  $field eq 'map_set_aid'
            ? $self->acc_id_to_internal_id(
                table      => 'cmap_map_set',
                acc_id     => $reference_map->{'aid'},
            )
            : undef
        ;
    }

    #
    # Whether or not the user choses more than one map (e.g., a 
    # whole map set), we'll sort out which maps are involved individually.
    #
    my @map_ids = ();
    if ( $map_set_aid ) {
        die "Need a reference map to display an entire map set" 
            unless $ref_map_id || $ref_map_set_id;

        #
        # Turn the accession id into an internal id.
        #
        my $map_set_id = $self->acc_id_to_internal_id(
            table  => 'cmap_map_set', 
            acc_id => $map_set_aid,
        );

        if ( $ref_map_id ) {
            push @map_ids, @{ $db->selectcol_arrayref(
                $sql->map_data_map_ids_by_single_reference_map,
                {},    
                ( $ref_map_id, $ref_map_start, $ref_map_stop, 
                  $map_set_id, $ref_map_id
                )
            ) };
        }
        else {
            push @map_ids, @{ $db->selectcol_arrayref(
                qq[
                    select   distinct map.map_id
                    from     cmap_map map,
                             cmap_feature f1, 
                             cmap_feature f2, 
                             cmap_correspondence_lookup cl,
                             cmap_feature_correspondence fc
                    where    f1.map_id in ( $reference_map->{'map_ids'} )
                    and      f1.feature_id=cl.feature_id1
                    and      cl.feature_correspondence_id=
                             fc.feature_correspondence_id
                    and      fc.is_enabled=1
                    and      cl.feature_id2=f2.feature_id
                    and      f2.map_id=map.map_id
                    and      map.map_set_id=?
                    and      map.map_id not in ( $reference_map->{'map_ids'} )
                ],
                {},
                ( $map_set_id )
            ) };
        }

        $map->{'map_ids'} = join( ',', @map_ids );
    }
    else {
        #
        # Turn the accession id into an internal id.
        #
        push @map_ids, $self->acc_id_to_internal_id(
            table  => 'cmap_map', 
            acc_id => $map_aid,
        );
    }

    #
    # For each map, go through and figure out the features involved.
    #
    my $maps;
    for my $map_id ( @map_ids ) {
        #
        # Get all the info on the map.
        #
        my $sth = $db->prepare( $sql->cmap_data_map_info_sql );
        $sth->execute( $map_id );
        my $map_data = $sth->fetchrow_hashref;
#        warn "map data =\n", Dumper( $map_data ), "\n";

        #
        # If we're looking at more than one map (a whole map set), 
        # then we'll use the "start" and "stop" found for the current map.
        # Otherwise, we'll use the arguments supplied (if any).
        #
        if ( scalar @map_ids > 1 ) { 
            $map_start = $map_data->{'start_position'};
            $map_stop  = $map_data->{'stop_position'};
        }
        else {
            #
            # Make sure the start and stop are numbers.
            #
            for ( $map_start, $map_stop ) {
                next unless defined $_;
                unless ( $_ =~ NUMBER_RE ) {
                    $_ = $self->feature_name_to_position( 
                        feature_name => $_,
                        map_id       => $map_id,
                    ) || 0;
                }
            }

            $map_start = $map_data->{'start_position'} 
                unless defined $map_start;
            $map_start = $map_data->{'start_position'} 
                if $map_start < $map_data->{'start_position'};
            $map_stop  = $map_data->{'stop_position'} 
                unless defined $map_stop;
            $map_stop  = $map_data->{'stop_position'} 
                if $map_stop > $map_data->{'stop_position'};

            if ( 
                defined $map_start && 
                defined $map_stop  &&
                $map_start > $map_stop
            ) {
                ( $map_start, $map_stop ) = ( $map_stop, $map_start );
            }

            #
            # If we're supposed to add in flanking features...
            #
            if ( $no_flanking_positions > 0 ) {
                unless ( $map_start == $map_data->{'start_position'} ) {
                    #
                    # Find everything before the start...
                    #
                    my $positions = $db->selectcol_arrayref(
                        q[
                            select   distinct start_position
                            from     cmap_feature
                            where    map_id=?
                            and      start_position<?
                            order by start_position desc
                        ],
                        {},
                        ( $map_id, $map_start )
                    );

                    #
                    # Then take the furthest one out that exists.
                    #
                    if ( @$positions ) {
                        my $i = $no_flanking_positions - 1;
                        $i-- while !defined $positions->[$i];
                        $map_start = $positions->[$i];
                    } 
                }

                unless ( $map_stop == $map_data->{'stop_position'} ) {
                    #
                    # Find all the positions after the current stop...
                    #
                    my $positions = $db->selectcol_arrayref(
                        q[
                            select   distinct start_position
                            from     cmap_feature
                            where    map_id=?
                            and      start_position>?
                            order by start_position asc
                        ],
                        {},
                        ( $map_id, $map_stop )
                    );  

                    #
                    # The take the furthest one out that exists.
                    #
                    if ( @$positions ) {
                        my $i = $no_flanking_positions - 1;
                        $i-- while !defined $positions->[$i];
                        $map_stop = $positions->[$i];
                    }
                }
            }
        }

        #
        # This feature doesn't really work right now.
        #
#        ( $map_start, $map_stop ) = $self->verify_map_range( 
#            map_id           => $map_id,
#            start            => $map_start,
#            stop             => $map_stop,
#            begin            => $map_data->{'begin'},
#            end              => $map_data->{'end'},
#            include_feature_types   => $include_feature_types,
#        );

        #
        # If we had to move the start and stop, remember it.
        #
        $map_data->{'start'} = $map_start;
        $map_data->{'stop'}  = $map_stop;
        $map->{'start'}      = $map_start;
        $map->{'stop'}       = $map_stop;

        #
        # Get the reference map features.
        #
        $map_data->{'features'} = $db->selectall_hashref(
            $sql->cmap_data_features_sql(
                feature_type_aids => $include_feature_types, 
            ),
            'feature_id',
            {},
            ( $map_id, $map_start, $map_stop, $map_start, $map_start )
        );

        my $map_feature_types = $db->selectall_arrayref(
            $sql->cmap_data_feature_types_sql,
            { Columns => {} },
            ( $map_id, $map_start, $map_stop )
        );

        $feature_types->{ $_->{'feature_type_id'} } = $_ 
            for @$map_feature_types;

        my $map_correspondences;
        if ( $ref_map_id ) {
            $map_correspondences = $db->selectall_arrayref(
                $sql->map_data_feature_correspondence_by_map_sql,
                { Columns => {} },
                ( $ref_map_id, $ref_map_start, $ref_map_stop,
                  $map_id, $map_start, $map_stop
                )
            );
        }
        elsif ( $ref_map_set_id ) {
            if ( my $ref_map_ids = $reference_map->{'map_ids'} ) {
                $map_correspondences = $db->selectall_arrayref(
                    $sql->map_data_feature_correspondence_by_multi_maps_sql(
                        $ref_map_ids
                    ),
                    { Columns => {} },
                    ( $map_id, $map_start, $map_stop )
                );
            }
            else {
                $map_correspondences = $db->selectall_arrayref(
                    $sql->map_data_feature_correspondence_by_map_set_sql,
                    { Columns => {} },
                    ( $ref_map_set_id, $map_id, $map_start, $map_stop )
                );
            }
        }

        if ( $map_correspondences ) {
            $map_data->{'no_correspondences'} = 
                scalar @$map_correspondences;

            for my $corr ( @$map_correspondences ) {
                $correspondences->{ 
                    $corr->{'feature_id1'} }{ $corr->{'feature_id2'} 
                } = $corr->{'feature_correspondence_id'};

                $correspondences->{
                    $corr->{'feature_id2'} }{ $corr->{'feature_id1'}
                } = $corr->{'feature_correspondence_id'};
            }
        }

        $maps->{ $map_id } = $map_data;
#        warn "map data = ", Dumper( $map_data ), "\n";
    }

    return $maps;
}

# ----------------------------------------------------
sub matrix_correspondence_data {

=pod

=head2 matrix_data

Returns the data for the correspondence matrix.

=cut
    my ( $self, %args )  = @_;
    my $db               = $self->db                 or return;
    my $species_aid      = $args{'species_aid'}      ||     '';
    my $map_set_aid      = $args{'map_set_aid'}      ||     '';
    my $map_name         = $args{'map_name'}         ||     ''; 
    my $link_map_set_aid = $args{'link_map_set_aid'} ||      0;

    #
    # Get all the species.
    #
    my $species = $db->selectall_arrayref( 
        q[
            select   distinct s.accession_id as species_aid, 
                     s.common_name,
                     s.display_order 
            from     cmap_species s,
                     cmap_map_set ms
            where    s.species_id=ms.species_id
            and      ms.can_be_reference_map=1
            and      ms.is_enabled=1
            order by s.display_order, s.common_name
        ],
        { Columns => {} } 
    );

    #
    # Make sure that species_id is set if map_set_id is.
    #
    if ( $map_set_aid && !$species_aid ) {
        $species_aid = $db->selectrow_array(
            q[
                select s.accession_id
                from   cmap_map_set ms,
                       cmap_species s
                where  ms.accession_id=?
                and    ms.species_id=s.species_id
            ],
            {},
            ( $map_set_aid )
        );
    }

    #
    # Get all the map sets for a given species.
    #
    my ( $maps, $map_sets );
    if ( $species_aid ) {
        $map_sets = $db->selectall_arrayref( 
            q[
                select   ms.accession_id as map_set_aid, 
                         ms.short_name as map_set_name
                from     cmap_map_set ms,
                         cmap_species s
                where    ms.can_be_reference_map=1
                and      ms.is_enabled=1
                and      ms.species_id=s.species_id
                and      s.accession_id=?
                order by ms.display_order, 
                         ms.published_on desc, 
                         ms.short_name
            ],
            { Columns => {} },
            ( "$species_aid" )
        );

        my $map_sql = qq[
            select   distinct map.map_name
            from     cmap_map map,
                     cmap_map_set ms,
                     cmap_species s
            where    map.map_set_id=ms.map_set_id
            and      ms.can_be_reference_map=1
            and      ms.is_enabled=1
            and      ms.species_id=s.species_id
            and      s.accession_id='$species_aid'
        ];
        $map_sql .= "and ms.accession_id='$map_set_aid' " if $map_set_aid;
        $map_sql .= 'order by map_name';
        $maps     = $db->selectall_arrayref( $map_sql, { Columns=>{} } );

        #
        # Sort maps that start with a number numerically.
        #
        my $all_numbers = grep { $_->{'map_name'} =~ m/^[0-9]/ } @$maps;
        if ( $all_numbers == scalar @$maps ) {
            @$maps = 
                map  { $_->[0] }
                sort { $a->[1] <=> $b->[1] }
                map  { [$_, extract_numbers( $_->{'map_name'} )] }
                @$maps
            ;
        }
    }

    #
    # Select all the map sets for the left-hand column 
    # (those which can be reference sets).
    #
    my @reference_map_sets = ();
    if ( $map_set_aid ) {
        my $map_set_sql = qq[
            select   map.map_id, 
                     map.accession_id as map_aid,
                     map.map_name, 
                     ms.map_set_id, 
                     ms.accession_id as map_set_aid,
                     ms.short_name as map_set_name,
                     s.species_id,
                     s.accession_id as species_aid,
                     s.common_name as species_name
            from     cmap_map map,
                     cmap_map_set ms,
                     cmap_species s
            where    map.map_set_id=ms.map_set_id
            and      ms.is_enabled=1
            and      ms.accession_id='$map_set_aid'
            and      ms.species_id=s.species_id
        ];

        $map_set_sql .= "and map.map_name='$map_name' " if $map_name;

        $map_set_sql .= 'order by map.map_name';

        @reference_map_sets = @{ 
            $db->selectall_arrayref( $map_set_sql, { Columns => {} } )
        };

        my $all_numbers = grep { $_->{'map_name'} =~ m/^[0-9]/ } 
            @reference_map_sets;
        if ( $all_numbers == scalar @reference_map_sets ) {
            @reference_map_sets = 
                map  { $_->[0] }
                sort { $a->[1] <=> $b->[1] }
                map  { [ $_, extract_numbers( $_->{'map_name'} ) ] }
                @reference_map_sets
            ;
        }
    }
    else {
        my $map_set_sql;
        if ( $map_name ) {
            $map_set_sql = qq[
                select   map.map_name,
                         map.accession_id as map_aid, 
                         ms.map_set_id, 
                         ms.accession_id as map_set_aid, 
                         ms.short_name as map_set_name,
                         ms.display_order as map_set_display_order,
                         ms.published_on, 
                         s.species_id,
                         s.accession_id as species_aid,
                         s.common_name as species_name,
                         s.display_order as species_display_order
                from     cmap_map map,
                         cmap_map_set ms,
                         cmap_species s
                where    map.map_name='$map_name'
                and      map.map_set_id=ms.map_set_id
                and      ms.is_enabled=1
                and      ms.species_id=s.species_id
                and      ms.can_be_reference_map=1
            ];
            $map_set_sql .= 
                "and s.accession_id='$species_aid' " if $species_aid;

            $map_set_sql .= 
                "and ms.accession_id='$map_set_aid' " if $map_set_aid;

            $map_set_sql .= q[
                order by species_display_order, 
                         species_name, 
                         map_set_display_order,
                         published_on,
                         map_set_name
            ];
        }
        else {
            $map_set_sql = q[
                select   ms.map_set_id, 
                         ms.accession_id as map_set_aid,
                         ms.short_name as map_set_name,
                         ms.display_order as map_set_display_order,
                         s.species_id,
                         s.accession_id as species_aid,
                         s.common_name as species_name,
                         s.display_order as species_display_order
                from     cmap_map_set ms,
                         cmap_species s
                where    ms.can_be_reference_map=1
                and      ms.is_enabled=1
                and      ms.species_id=s.species_id
            ];
            $map_set_sql .= 
                "and s.accession_id='$species_aid' " if $species_aid;

            $map_set_sql .= 
                "and ms.accession_id='$map_set_aid' " if $map_set_aid;

            $map_set_sql .= q[
                order by species_display_order, 
                         species_name,
                         map_set_display_order,
                         published_on desc,
                         map_set_name
            ];
        }

#        warn "ref map set sql =\n$map_set_sql\n";
        @reference_map_sets = @{ 
            $db->selectall_arrayref( $map_set_sql, { Columns => {} } )
        };
    }

    #
    # If there's only only set, then pretend that the user selected 
    # this one and expand the relationships to the map level.
    #
    if ( $map_set_aid == '' && scalar @reference_map_sets == 1 ) {
        $map_set_aid = $reference_map_sets[0]->{'map_set_aid'};
    }

#    warn "map set aid = $map_set_aid\n";
#    warn "ref map sets =\n", Dumper( @reference_map_sets ), "\n";

    #
    # Select the relationships from the pre-computed table.
    # If there's a map_set_id, then we should break down the 
    # results by map, else we sum it all up on map set ids.
    # If there's both a map_set_id and a link_map_set_id, then we should
    # break down the results by map by map, else we sum it
    # all up on map set ids.
    #
    my $select_sql;
    if ( $map_set_aid and $link_map_set_aid ) {
        $select_sql = qq[
            select   sum(cm.no_correspondences) as correspondences,
                     cm.reference_map_aid,
                     cm.reference_map_set_aid,
                     cm.reference_species_aid,
                     cm.link_map_aid,
                     cm.link_map_set_aid,
                     cm.link_species_aid
            from     cmap_correspondence_matrix cm,
                     cmap_map_set ms
            where    cm.reference_map_set_aid='$map_set_aid'
            and      cm.link_map_set_aid='$link_map_set_aid'
            and      cm.reference_map_set_aid=ms.accession_id
            and      ms.is_enabled=1
        ];

        $select_sql .= "and cm.reference_species_aid='$species_aid' " 
            if $species_aid;

        $select_sql .= "and cm.reference_map_name='$map_name' " 
            if $map_name;

        $select_sql .= q[
            group by cm.reference_map_aid,
                     cm.reference_map_set_aid,
                     cm.link_map_set_aid,
                     cm.reference_species_aid,
                     cm.link_map_aid,
                     cm.link_species_aid,
                     cm.link_map_set_aid
        ];
    }
    elsif ( $map_set_aid ) {
        $select_sql = qq[
            select   sum(cm.no_correspondences) as correspondences,
                     cm.reference_map_aid,
                     cm.reference_map_set_aid,
                     cm.reference_species_aid,
                     cm.link_map_set_aid,
                     cm.link_species_aid
            from     cmap_correspondence_matrix cm,
                     cmap_map_set ms
            where    cm.reference_map_set_aid='$map_set_aid'
            and      cm.reference_map_set_aid=ms.accession_id
        ];

        $select_sql .= "and cm.reference_species_aid='$species_aid' " 
            if $species_aid;

        $select_sql .= "and cm.reference_map_name='$map_name' " 
            if $map_name;

        $select_sql .= q[
            group by cm.reference_map_aid,
                     cm.reference_map_set_aid,
                     cm.link_map_set_aid,
                     cm.reference_species_aid,
                     cm.link_species_aid
        ];
    }
    else {
        #
        # This is the most generic SQL, showing all the possible 
        # combinations of map sets to map sets.
        #
        $select_sql = q[
            select   sum(cm.no_correspondences) as correspondences,
                     cm.reference_map_set_aid,
                     cm.reference_species_aid,
                     cm.link_map_set_aid,
                     cm.link_species_aid
            from     cmap_correspondence_matrix cm
        ];

        #
        # I shouldn't have to worry about not having "WHERE" as
        # the user shouldn't be able to select a map name
        # without having first selected a species.
        #
        $select_sql .= "where cm.reference_species_aid='$species_aid' " 
            if $species_aid;

        $select_sql .= "and cm.reference_map_name='$map_name' " 
            if $map_name;

        $select_sql .= q[
            group by cm.reference_map_set_aid,
                     cm.link_map_set_aid,
                     cm.reference_species_aid,
                     cm.link_species_aid
        ];
    }
#    warn "select_sql =\n$select_sql\n";
    my $data = $db->selectall_arrayref( $select_sql, { Columns => {} } );
#    warn "data =\n", Dumper( $data ), "\n";

    #
    # Create a lookup hash from the data.
    #
    my %lookup;
    for my $hr ( @$data ) {
        if ( $map_set_aid && $link_map_set_aid ) {
            #
            # Map sets that can't be references won't have a "link_map_id."
            #
            my $link_aid = $hr->{'link_map_aid'} || $hr->{'link_map_set_aid'};
            $lookup{ $hr->{'reference_map_aid'}  }
               { $link_aid } = $hr->{'correspondences'};
        }
        elsif ( $map_set_aid ) {
            $lookup{ $hr->{'reference_map_aid'}  }
               { $hr->{'link_map_set_aid'} } = $hr->{'correspondences'};
        }
        else {
            $lookup{ $hr->{'reference_map_set_aid'}  }
               { $hr->{'link_map_set_aid'} } = $hr->{'correspondences'}
        }
    }
#    warn "lookup =\n", Dumper( %lookup ), "\n";

    #
    # Select ALL the map sets to go across.
    #
    my $link_map_can_be_reference = ( $link_map_set_aid )
        ? $db->selectrow_array(
            q[
                select ms.can_be_reference_map
                from   cmap_map_set ms
                where  ms.accession_id=?
            ],
            {},
            ( $link_map_set_aid )
        )
        : undef
    ;

    #
    # If given a map set id for a map set that can be a reference map, 
    # select the individual map.  Otherwise, if given a map set id for
    # a map set that can't be a reference or if given nothing, grab 
    # the entire map set.
    #
    my $link_map_set_sql;
    if ( 
        $map_set_aid && $link_map_set_aid && $link_map_can_be_reference 
    ) {
        $link_map_set_sql = qq[
            select   map.map_id,
                     map.accession_id as map_aid,
                     map.map_name,
                     ms.map_set_id, 
                     ms.accession_id as map_set_aid, 
                     ms.short_name as map_set_name,
                     s.species_id,
                     s.accession_id as species_aid,
                     s.common_name as species_name,
                     mt.map_type_id, 
                     mt.map_type
            from     cmap_map map,
                     cmap_map_set ms,
                     cmap_map_type mt,
                     cmap_species s
            where    map.map_set_id=ms.map_set_id
            and      ms.is_enabled=1
            and      ms.accession_id='$link_map_set_aid'
            and      ms.map_type_id=mt.map_type_id
            and      ms.species_id=s.species_id
            order by map_name
        ];
    }
    else {
        $link_map_set_sql = q[
            select   ms.map_set_id, 
                     ms.accession_id as map_set_aid,
                     ms.short_name as map_set_name,
                     ms.display_order as map_set_display_order,
                     ms.published_on,
                     s.species_id,
                     s.accession_id as species_aid,
                     s.common_name as species_name,
                     s.display_order as species_display_order,
                     mt.map_type_id, 
                     mt.map_type,
                     mt.display_order as map_type_display_order
            from     cmap_map_set ms,
                     cmap_map_type mt,
                     cmap_species s
            where    ms.map_type_id=mt.map_type_id
            and      ms.is_enabled=1
            and      ms.species_id=s.species_id
        ];

        $link_map_set_sql .= 
            "and ms.accession_id='$link_map_set_aid' " if $link_map_set_aid;

        $link_map_set_sql .= q[
            order by map_type_display_order,
                     map_type,
                     species_display_order, 
                     species_name, 
                     map_set_display_order,
                     published_on,
                     map_set_name
        ];
    }

#    warn "link sql =\n$link_map_set_sql\n";
    my @all_map_sets = @{ 
        $db->selectall_arrayref( $link_map_set_sql, { Columns => {} } )
    };

    my $all_numbers = grep { $_->{'map_name'} =~ m/^[0-9]/ } 
        @all_map_sets;
    if ( $all_numbers == scalar @all_map_sets ) {
        @all_map_sets = 
            map  { $_->[0] }
            sort { $a->[1] <=> $b->[1] }
            map  { [$_, extract_numbers( $_->{'map_name'} )] }
            @all_map_sets
        ;
    }

#    warn "all map sets =\n", Dumper( \@all_map_sets ), "\n";

    #
    # Figure out the number by type and species.
    #
    my ( %no_by_type, %no_by_type_and_species );
    for my $map_set ( @all_map_sets ) {
        my $map_type_id = $map_set->{'map_type_id'};
        my $species_aid = $map_set->{'species_aid'};

        $no_by_type{ $map_type_id }++;
        $no_by_type_and_species{ $map_type_id }{ $species_aid }++;
    }

    #
    # The top row of the table is a listing of all the map sets.
    #
    my $top_row = {
        no_by_type             => \%no_by_type,
        no_by_type_and_species => \%no_by_type_and_species,
        map_sets               => \@all_map_sets
    };

#    warn "top row =\n", Dumper( $top_row ), "\n";

    #
    # Fill in the matrix with the reference set and all it's correspondences.
    # Herein lies madness.
    #
    my ( @matrix, %no_by_species );
#    warn "lookup = ", Dumper( \%lookup ), "\n";
    for my $map_set ( @reference_map_sets ) {
        my $r_map_aid       = $map_set->{'map_aid'} || 0;
        my $r_map_set_aid   = $map_set->{'map_set_aid'};
        my $r_species_aid   = $map_set->{'species_aid'};
#        my $reference_aid   = $r_map_aid || $r_map_set_aid;
        my $reference_aid   = 
            $map_name && $map_set_aid ? $r_map_aid     : 
            $map_name                 ? $r_map_set_aid : 
            $r_map_aid || $r_map_set_aid;

        $no_by_species{ $r_species_aid }++;

        for my $comp_map_set ( @all_map_sets ) {
#            warn "comp map set = ", Dumper($comp_map_set), "\n";
            my $comp_map_set_aid = $comp_map_set->{'map_set_aid'};
            my $comp_map_aid     = $comp_map_set->{'map_aid'} || 0;
            my $comparative_aid  = $comp_map_aid || $comp_map_set_aid;
            my $correspondences  = 
                $comp_map_set_aid eq $r_map_set_aid ? 'N/A' :
                $lookup{ $reference_aid }{ $comparative_aid } || 0
            ;
#            my $correspondences;
#            if ( $map_set_aid ) {
#                if ( $comp_map_aid eq $r_map_aid ) { 
#                    $correspondences = 'N/A';
#                }
#                else {
#                    $correspondences = 
#                        $lookup{ $reference_aid }{ $comparative_aid } || 0;
#                }
#            }
#            else {
#                $correspondences = 
#                    $comp_map_set_aid eq $r_map_set_aid ? 'N/A' :
#                    $lookup{ $reference_aid }{ $comparative_aid } || 0
#            }
#            warn "correspondences = $correspondences\n";

            push @{ $map_set->{'correspondences'} }, {
                map_set_aid => $comp_map_set_aid, 
                map_aid     => $comp_map_aid,
                number      => $correspondences,
            };
        }

        push @matrix, $map_set;
    }

#    warn "matrix =\n", Dumper( @matrix ), "\n";

    my $matrix_data   =  {
        data          => \@matrix,
        no_by_species => \%no_by_species,
    };

    return {
        top_row     => $top_row,
        species_aid => $species_aid,
        map_set_aid => $map_set_aid,
        map_name    => $map_name,
        matrix      => $matrix_data,
        data        => $data,
        species     => $species,
        map_sets    => $map_sets,
        maps        => $maps,
    };
}

# ----------------------------------------------------
sub cmap_form_data {

=pod

=head2 cmap_form_data

Returns the data for the main comparative map HTML form.

=cut
    my ( $self, %args ) = @_;
    my $slots           = $args{'slots'} or return;
#    warn "slots =\n", Dumper( $slots ), "\n";
    my $ref_map         = $slots->{ 0 };
    my $ref_map_set_aid = $ref_map->{'map_set_aid'} || 0;
    my $ref_map_aid     = $ref_map->{'aid'}         || 0;
    my $ref_map_start   = $ref_map->{'start'};
    my $ref_map_stop    = $ref_map->{'stop'};
    my $db              = $self->db  or return;
    my $sql             = $self->sql or return;

    #
    # Select all the map set that can be reference maps.
    #
    my $ref_map_sets = $db->selectall_arrayref(
        $sql->form_data_ref_map_sets_sql,
        { Columns => {} }
    );

    #
    # If the user selected a map set, select all the maps in it.
    #
    my $ref_maps; 
    if ( $ref_map_set_aid ) {
        $ref_maps = $db->selectall_arrayref(
            $sql->form_data_ref_maps_sql,
            { Columns => {} },
            ( "$ref_map_set_aid" )
        );

        $self->error(
            qq[No maps exist for the ref. map set acc. id "$ref_map_set_aid"]
        ) unless @$ref_maps;

        if ( grep { $_->{'map_name'} =~ m/^[0-9]/ } @$ref_maps ) {
            @$ref_maps = 
                map  { $_->[0] }
                sort { $a->[1] <=> $b->[1] }
                map  { [ $_, extract_numbers( $_->{'map_name'} ) ] }
                @$ref_maps
            ;
        }

    }

    #
    # If there is a ref. map selected but no start and stop, find 
    # the ends of the ref. map.
    #
    if ( $ref_map_aid ) {
        my $map_id = $self->acc_id_to_internal_id(
            table  => 'cmap_map', 
            acc_id => $ref_map_aid,
        );

        #
        # Make sure the start and stop are numbers.
        #
        for ( $ref_map_start, $ref_map_stop ) {
            next unless defined $_;
            unless ( $_ =~ NUMBER_RE ) {
                $_ = $self->feature_name_to_position( 
                    feature_name => $_,
                    map_id       => $map_id,
                ) || 0;
            }
        }

        if ( 
            defined $ref_map_start && 
            defined $ref_map_stop  &&
            $ref_map_start > $ref_map_stop
        ) {
            ( $ref_map_start, $ref_map_stop ) = 
            ( $ref_map_stop, $ref_map_start ) ;
        }

#        my $ref_map_begin = $self->map_start( map_id => $map_id ); 
#        my $ref_map_end   = $self->map_stop ( map_id => $map_id );
#        $ref_map_start = $ref_map_start unless defined $ref_map_start;
#        $ref_map_stop  = $ref_map_stop  unless defined $ref_map_stop;

        unless ( defined $ref_map_start && defined $ref_map_stop ) {
            my ( $ref_map_begin, $ref_map_end ) = $db->selectrow_array(
                q[
                    select start_position, stop_position
                    from   cmap_map
                    where  map_id=?
                ],
                {},
                ( $map_id )
            );

            $ref_map_start = $ref_map_begin unless defined $ref_map_start;
            $ref_map_start = $ref_map_begin if $ref_map_start < $ref_map_begin;
            $ref_map_stop  = $ref_map_end   if $ref_map_stop  > $ref_map_stop;
        }

        #
        # This feature doesn't really work right now.
        #
#        ( $ref_map_start, $ref_map_stop ) = $self->verify_map_range( 
#            map_id => $map_id,
#            start  => $ref_map_start,
#            stop   => $ref_map_stop,
#            begin  => $ref_map_begin,
#            end    => $ref_map_end,
#        );
        
        $slots->{ 0 }->{'start'} = $ref_map_start;
        $slots->{ 0 }->{'stop'}  = $ref_map_stop;
    }

    my @slot_nos        = sort { $a <=> $b } keys %$slots;
    my $left_map        = $slots->{ $slot_nos[ 0] };
    my $right_map       = $slots->{ $slot_nos[-1] };
    my $left_ref_map    = $slots->{exists $slot_nos[ 1]? $slot_nos[ 1] : undef};
    my $right_ref_map   = $slots->{exists $slot_nos[-2]? $slot_nos[-2] : undef};
    my $comp_maps_right = $self->get_comparative_maps( $right_map ) || [];
    my $comp_maps_left  = $self->get_comparative_maps( $left_map )  || [];

    #
    # Feature types.
    #
    my @feature_types = 
        sort { lc $a->{'feature_type'} cmp lc $b->{'feature_type'} } @{
        $db->selectall_arrayref(
            q[
                select   ft.accession_id as feature_type_aid,
                         ft.feature_type
                from     cmap_feature_type ft
                order by ft.feature_type
            ],
            { Columns => {} }
        )
    };

    #
    # Fill out all the info we have on every map.
    #
    my $map_info = $self->fill_out_maps( $slots );
    
    return {
        ref_map_sets           => $ref_map_sets,
        ref_maps               => $ref_maps,
        ref_map_start          => $ref_map_start,
        ref_map_stop           => $ref_map_stop,
        comparative_maps_right => $comp_maps_right,
        comparative_maps_left  => $comp_maps_left,
        map_info               => $map_info,
        feature_types          => \@feature_types,
    };
}

# ----------------------------------------------------
sub get_comparative_maps {

=pod

=head2 get_comparative_maps

Given a reference map and (optionally) start and stop positions, figure
out which maps have relationships.

=cut
#    my ( $self, $map, $ref_map ) = @_;
    my $self            = shift;
    my %args            = ( ref $_[0] ) ? %{ shift() } : @_;
#    warn "args =\n", Dumper( %args ), "\n";

    my $aid_field       = $args{'field'};
    my $ref_map_aid     = $aid_field eq 'map_aid'     ? $args{'aid'} : '';
    my $ref_map_set_aid = $aid_field eq 'map_set_aid' ? $args{'aid'} : '';
    return unless $ref_map_aid || $ref_map_set_aid;

    my $ref_map_start   = $args{'start'};
    my $ref_map_stop    = $args{'stop'};
    my $db              = $self->db  or return;
    my $sql             = $self->sql or return;
    
    #
    # Find the correspondences to other maps.
    #
    my $correspondences;
    if ( $ref_map_set_aid ) {
        #
        # If by an entire map set, make sure it's a relational set.
        #
        return unless $db->selectrow_array(
            q[
                select mt.is_relational_map
                from   cmap_map_set ms,
                       cmap_map_type mt
                where  ms.accession_id=?
                and    ms.map_type_id=mt.map_type_id
            ],
            {},
            ( $ref_map_set_aid ) 
        );

        if ( my $map_ids = $args{'map_ids'} ) {
            $correspondences = $db->selectall_arrayref(
                $sql->correspondences_count_by_multi_maps_sql( $map_ids ),
                { Columns => {} },
            );
        }
        else {
            my $map_set_id =  $self->acc_id_to_internal_id(
                table      => 'cmap_map_set', 
                acc_id     => $ref_map_set_aid,
            );
        
            $correspondences = $db->selectall_arrayref(
                $sql->correspondences_count_by_map_set_sql,
                { Columns => {} },
                ( $map_set_id, $map_set_id )
            );
        }
    }
    else {
        #
        # Make sure we have a start and stop.
        #
#        $ref_map_start = $self->map_start( map_aid => $ref_map_aid ) 
#            unless defined $ref_map_start && $ref_map_stop ne '';
#
#        $ref_map_stop = $self->map_stop( map_aid => $ref_map_aid )
#            unless defined $ref_map_stop && $ref_map_stop ne '';

        my ( $ref_map_begin, $ref_map_end ) = $db->selectrow_array(
            q[
                select start_position, stop_position
                from   cmap_map
                where  accession_id=?
            ],
            {},
            ( $ref_map_aid )
        );

        $ref_map_start = $ref_map_begin
            unless defined $ref_map_start && $ref_map_stop ne '';

        $ref_map_stop = $ref_map_end
            unless defined $ref_map_stop && $ref_map_stop ne '';

        $correspondences = $db->selectall_arrayref(
            $sql->correspondences_count_by_single_map_sql,
            { Columns => {} },
            ( $ref_map_aid, $ref_map_start, $ref_map_stop, $ref_map_aid )
        );
    }

    my $map_sets;
    my $join_token = '::';
    for my $corr ( @$correspondences ) {
        my $map_type    = $corr->{'map_type'};
        my $display     = $corr->{'map_type_display_order'};
        my $key         = join( $join_token, $display, $map_type );
        my $map_set_aid = $corr->{'map_set_aid'};

        for ( qw[ map_set_aid species_name map_set_name ] ) {
            $map_sets->{ $key }{ $map_set_aid }{ $_ } = $corr->{ $_ };
        }

        $map_sets->{ $key }{ $map_set_aid }{ 'no_correspondences' } +=
            $corr->{'no_correspondences'};

        next unless $corr->{'can_be_reference_map'};

        push @{ 
            $map_sets->{ $key }{ $map_set_aid }{ 'maps' }
        }, $corr;
    }

#    warn "map sets = \n", Dumper( $map_sets ), "\n";

    my @return;
    for ( sort keys %$map_sets ) {
        my ( $display, $map_type ) = split $join_token;
        my @map_sets;
        for my $map_set ( values %{ $map_sets->{ $_ } } ) {
            push @map_sets, $map_set;
        }

        push @return, { 
            type     => $map_type,
            map_sets => \@map_sets,
        };
    }

    return \@return;
}

# ----------------------------------------------------
sub feature_correspondence_data {

=pod

=head2 feature_correspondence_data

Retrieve the data for a feature correspondence.

=cut
    my ( $self, %args )           = @_;
    my $feature_correspondence_id = $args{'feature_correspondence_id'} 
        or return;
}

# ----------------------------------------------------
sub feature_name_to_position {

=pod

=head2 feature_name_to_position

Turn a feature name into a position.

=cut
    my ( $self, %args ) = @_;
    my $feature_name    = $args{'feature_name'} or return;
    my $map_id          = $args{'map_id'}       or return;
    my $db              = $self->db             or return;
    my $sql             = $self->sql            or return;
    my $upper_name      = uc $feature_name;
    my $position        = $db->selectrow_array(
        $sql->feature_name_to_position_sql,
        {},
        ( $upper_name, $upper_name, $map_id )
    ) || 0;

    return $position;
}

# ----------------------------------------------------
sub fill_out_maps {

=pod

=head2 fill_out_maps

Gets the names, IDs, etc., of the maps in the slots.

=cut
    my ( $self, $slots ) = @_;
    my $db               = $self->db  or return;
    my $sql              = $self->sql or return;
    my $map_sth          = $db->prepare( $sql->fill_out_maps_by_map_sql );
    my $map_set_sth      = $db->prepare( $sql->fill_out_maps_by_map_set_sql );
    my @ordered_slot_nos = sort { $a <=> $b } keys %$slots;

    my @maps;
    for my $i ( 0 .. $#ordered_slot_nos ) {
        my $slot_no = $ordered_slot_nos[ $i ];
        my $slot    = $slots->{ $slot_no };
        my $aid     = $slot->{'aid'};
        my $field   = $slot->{'field'};
        my $sth     = $field eq 'map_aid' ? $map_sth : $map_set_sth;
        $sth->execute( $aid );
        my $map     = $sth->fetchrow_hashref;

        #
        # To select the other comparative maps, we have to cut off everything
        # after the current map.  E.g., if there are maps in slots -2, -1, 0,
        # 1, and 2, for slot 1 we should choose everything less than it (and
        # non-zero).  The opposite is true for negative slots.
        #
        my @cmap_nos;
        if ( $slot_no == 0 ) {
            $map->{'is_reference_map'} = 1;
        }
        elsif ( $slot_no < 0 ) {
            push @cmap_nos, grep { $_>$slot_no && $_!=0 } @ordered_slot_nos;
        }
        else {
            push @cmap_nos, grep { $_<$slot_no && $_!=0 } @ordered_slot_nos;
        }

        $map->{'cmaps'} = [ 
            map { 
                { 
                    field   => $slots->{$_}{'field'}, 
                    aid     => $slots->{$_}{'aid'},
                    slot_no => $_,
                }
            } @cmap_nos
        ];

        $map->{'slot_no'} = $slot_no;
        push @maps, $map;
    }

    return \@maps;
}

# ----------------------------------------------------
sub feature_detail_data {

=pod

=head2 feature_detail_data

Given a feature acc. id, find out all the details on it.

=cut
    my ( $self, %args ) = @_;
    my $feature_aid     = $args{'feature_aid'} or die 'No accession id';
    my $db              = $self->db  or return;
    my $sql             = $self->sql or return;
    my $sth             = $db->prepare( $sql->feature_detail_data_sql );

    $sth->execute( $feature_aid );
    my $feature = $sth->fetchrow_hashref or return $self->error(
        "Invalid feature accession ID ($feature_aid)"
    );

    my $correspondences = $db->selectall_arrayref(
        $sql->feature_correspondence_sql,
        { Columns => {} },
        ( $feature->{'feature_id'} )
    );

    for my $corr ( @$correspondences ) {
        $corr->{'evidence'} = $db->selectall_arrayref(
            q[
                select   ce.accession_id,
                         ce.score,
                         ce.remark,
                         et.rank,
                         et.evidence_type
                from     cmap_correspondence_evidence ce,
                         cmap_evidence_type et
                where    ce.feature_correspondence_id=?
                and      ce.evidence_type_id=et.evidence_type_id
                order by et.rank
            ],
            { Columns => {} },
            ( $corr->{'feature_correspondence_id'} )
        )
    }

    if ( $feature->{'dbxref_name'} || $feature->{'dbxref_url'} ) {
        $feature->{'dbxrefs'} = [
            { 
                dbxref_name => $feature->{'dbxref_name'},
                url         => $feature->{'dbxref_url'},
            }
        ]
    }
    else {
        my $dbxrefs = $db->selectall_arrayref(
            q[
                select d.species_id,
                       d.map_set_id,
                       d.feature_type_id,
                       d.url,
                       d.dbxref_name
                from   cmap_dbxref d
                where  d.feature_type_id=?
                and    (
                    d.species_id=?
                    or     
                    d.map_set_id=?
                )
                or     (
                    d.species_id=?
                    and     
                    d.map_set_id=?
                )
            ],
            { Columns => {} },
            ( 
                $feature->{'feature_type_id'},
                $feature->{'species_id'},
                $feature->{'map_set_id'},
                $feature->{'species_id'},
                $feature->{'map_set_id'},
            )
        );

        my ( @generic, @specific );
        for my $dbxref ( @$dbxrefs ) {
            if ( $dbxref->{'map_set_id'} == $feature->{'map_set_id'} ) {
                push @specific, $dbxref;
            }
            else {
                push @generic, $dbxref;
            }
        }
        $feature->{'dbxrefs'} = @specific ? \@specific : \@generic;
    }

    $feature->{'correspondences'} = $correspondences;

    return $feature;
}

# ----------------------------------------------------
sub feature_search_data {

=pod

=head2 feature_search_data

Given a list of feature names, find any maps they occur on.

=cut
    my ( $self, %args )  = @_;
    my $species_aid      = $args{'species_aid'}      ||  0;
    my $feature_type_aid = $args{'feature_type_aid'} || '';
    my $feature_string   = $args{'features'};
    my @feature_names    = (
        # Turn stars into SQL wildcards, kill quotes.
        map { s/\*/%/g; s/['"]//g; uc $_ || () }
        split( /[,:;\s+]/, $feature_string ) 
    );
    my $order_by         = $args{'order_by'} || 
        'feature_name,species_name,map_set_name,map_name,start_position';
    my $search_field     = 
        $args{'search_field'} || $self->config('feature_search_field');
       $search_field     = DEFAULT->{'feature_search_field'} 
        unless VALID->{'feature_search_field'}{ $search_field };
    my $db               = $self->db  or return;
    my $sql              = $self->sql or return;

    #
    # We'll get the feature ids first.  Use "like" in case they've
    # included wildcard searches.
    #
    my @found_features = ();
    for my $feature_name ( @feature_names ) {
        my $comparison = $feature_name =~ m/%/ ? 'like' : '=';
        my $where      = $search_field eq 'both'
            ? qq[
                where  (
                    upper(f.feature_name) $comparison '$feature_name'
                    or
                    upper(f.alternate_name) $comparison '$feature_name'
                )
            ]
            : qq[where upper(f.$search_field) $comparison '$feature_name']
        ;

        my $sql = qq[
            select f.accession_id as feature_aid,
                   f.feature_name, 
                   f.alternate_name, 
                   f.start_position,
                   f.stop_position,
                   ft.feature_type,
                   map.accession_id as map_aid,
                   map.map_name, 
                   ms.accession_id as map_set_aid, 
                   ms.short_name as map_set_name,
                   s.species_id,
                   s.common_name as species_name
            from   cmap_feature f, 
                   cmap_feature_type ft,
                   cmap_map map,
                   cmap_map_set ms,
                   cmap_species s
            $where
            and    f.feature_type_id=ft.feature_type_id
        ];
        $sql .= "and ft.accession_id='$feature_type_aid' " if $feature_type_aid;
        $sql .= q[
            and    f.map_id=map.map_id
            and    map.map_set_id=ms.map_set_id
            and    ms.is_enabled=1
            and    ms.can_be_reference_map=1
            and    ms.species_id=s.species_id
        ];
        $sql .= "and s.accession_id='$species_aid' " if $species_aid;

        $sql .= "order by $order_by";

        push @found_features, @{ $db->selectall_arrayref($sql, {Columns=>{}}) };
    }

    #
    # If no species was selected, then look at what's in the search
    # results so they can narrow down what they have.  If no search 
    # results, then just show all.
    #
    my $species = $db->selectall_arrayref(
        q[
            select   s.accession_id as species_aid,
                     s.common_name as species_name
            from     cmap_species s
            order by species_name
        ],
        { Columns => {} } 
    );

    #
    # Get the feature types.
    #
    my $feature_types = $db->selectall_arrayref(
        q[
            select   ft.accession_id as feature_type_aid,
                     ft.feature_type
            from     cmap_feature_type ft
            order by feature_type
        ],
        { Columns => {} }
    );

    return {
        data          => \@found_features,
        species       => $species,
        feature_types => $feature_types,
    };
}

# ----------------------------------------------------
sub map_set_viewer_data {

=pod

=head2 map_data

Returns the data for drawing comparative maps.

=cut
    my ( $self, %args ) = @_;
    my @map_set_aids    = @{ $args{'map_set_aids'} || [] };
    my $db              = $self->db or return;

    my $sql = q[
        select   ms.map_set_id, 
                 ms.accession_id as map_set_aid,
                 ms.map_set_name, 
                 ms.short_name,
                 ms.map_type_id, 
                 ms.species_id, 
                 ms.can_be_reference_map,
                 ms.remarks,
                 mt.map_type, 
                 mt.map_units, 
                 s.common_name, 
                 s.full_name
        from     cmap_map_set ms, 
                 cmap_map_type mt, 
                 cmap_species s
        where    ms.map_type_id=mt.map_type_id
        and      ms.species_id=s.species_id
    ]; 

    if ( @map_set_aids ) {
        $sql .= 'and ms.accession_id in ('.
            join( ',', map { qq['$_'] } @map_set_aids ) . 
        ')';
    }
    $sql .= 'order by short_name';

    my $map_sets = $db->selectall_arrayref( $sql, { Columns => {} } );

    for my $map_set ( @$map_sets ) {
        next unless $map_set->{'can_be_reference_map'};
        my @maps =  @{
            $db->selectall_arrayref(
                q[
                    select   map.accession_id as map_aid, 
                             map.map_name
                    from     cmap_map map
                    where    map.map_set_id=?
                    order by map_name
                ],
                { Columns => {} }, ( $map_set->{'map_set_id'} )
            )
        } or next;

        my $all_numbers = grep { $_->{'map_name'} =~ m/^[0-9]/ } @maps;

        if ( $all_numbers == scalar @maps ) {
            @maps = 
                map  { $_->[0] }
                sort { $a->[1] <=> $b->[1] }
                map  { [ $_, extract_numbers( $_->{'map_name'} ) ] }
                @maps
            ;
        }

        $map_set->{'maps'} = \@maps;
    }

    return $map_sets;
}

# ----------------------------------------------------
sub map_stop {

=pod

=head2 map_stop

Given a map acc. id or a map_id, find the highest start or stop position
(remembering that some features span a distance).  Optionally finds the 
lowest stop for a given feature type. (enhancement)

=cut
    my ( $self, %args ) = @_;
    my $db              = $self->db  or return;
    my $sql_obj         = $self->sql or return;
    my $map_aid         = $args{'map_aid'}        || 0;
    my $map_id          = $args{'map_id'}         || 0;
    my $id              = ( $map_aid || $map_id ) or return 
                          $self->error( "Not enough args to map_stop()" );
    my $sql             = $sql_obj->map_stop_sql( %args );

    my ( $start, $stop ) = $db->selectrow_array( $sql, {}, ( $id ) )
        or $self->error(qq[Can't determine map stop for id "$id"]);

    return $start > $stop ? $start : $stop;
}

# ----------------------------------------------------
sub map_start {

=pod

=head2 map_start

Given a map acc. id or a map_id, find the lowest start position.  
Optionally finds the lowest start for a given feature type. (enhancement)

=cut
    my ( $self, %args ) = @_;
    my $db              = $self->db  or return;
    my $sql_obj         = $self->sql or return;
    my $map_aid         = $args{'map_aid'}         || 0;
    my $map_id          = $args{'map_id'}          || 0;
    my $id              = ( $map_aid || $map_id ) or return $self->error(
        "Not enough args to map_start()"
    );
    my $sql             = $sql_obj->map_start_sql( %args );
    defined ( my $start = $db->selectrow_array( $sql, {}, ( $id ) ) )
        or return $self->error( qq[Can't determine map start for id "$id"] );

    return $start;
}

# ----------------------------------------------------
sub map_detail_data {

=pod

=head2 map_detail_data

Returns the detail info for a map.

=cut
    my ( $self, %args )       = @_;
    my $map                   = $args{'map'};
    my $highlight             = $args{'highlight'}         ||               '';
    my $order_by              = $args{'order_by'}          || 'start_position';
    my $comparative_map_aid   = $args{'comparative_map_aid'} ||             '';
    my $include_feature_types = $args{'include_feature_types'};
    my $db                    = $self->db  or return;
    my $sql                   = $self->sql or return;
    my $map_id                = $self->acc_id_to_internal_id(
        table                 => 'cmap_map',
        acc_id                => $map->{'aid'},
    );
    my $map_start             = $map->{'start'};
    my $map_stop              = $map->{'stop'};

    #
    # Figure out hightlighted features.
    #
    my $highlight_hash = {
        map  { s/^\s+|\s+$//g; ( uc $_, 1 ) } split( /[,:;\s+]/, $highlight ) 
    };

    my $sth = $db->prepare(
        q[
            select s.accession_id as species_aid,
                   s.common_name as species_name,
                   ms.accession_id as map_set_aid,
                   ms.short_name as map_set_name,
                   map.accession_id as map_aid,
                   map.map_name,
                   map.start_position,
                   map.stop_position,
                   mt.map_units
            from   cmap_map map,
                   cmap_map_set ms,
                   cmap_species s,
                   cmap_map_type mt
            where  map.map_id=?
            and    map.map_set_id=ms.map_set_id
            and    ms.species_id=s.species_id
            and    ms.map_type_id=mt.map_type_id
        ]
    );
    $sth->execute( $map_id );
    my $reference_map = $sth->fetchrow_hashref;

    $map_start = $reference_map->{'start_position'} 
        unless defined $map_start and $map_start =~ NUMBER_RE;
    $map_stop  = $reference_map->{'stop_position'} 
        unless defined $map_stop and $map_stop =~ NUMBER_RE;
    $reference_map->{'start'} = $map_start;
    $reference_map->{'stop'}  = $map_stop;

    #
    # Get the reference map features.
    #
    my $features = $db->selectall_arrayref(
        $sql->cmap_data_features_sql( 
            order_by          => $order_by,
            feature_type_aids => $include_feature_types,
        ),
        { Columns => {} },
        ( $map_id, $map_start, $map_stop, $map_start, $map_start )
    );

    my @feature_types = 
        sort { lc $a->{'feature_type'} cmp lc $b->{'feature_type'} } @{
        $db->selectall_arrayref(
            q[
                select   distinct ft.accession_id as feature_type_aid,
                         ft.feature_type
                from     cmap_feature f,
                         cmap_feature_type ft
                where    f.map_id=?
                and      f.start_position>=?
                and      f.start_position<=?
                and      f.feature_type_id=ft.feature_type_id
                order by feature_type
            ],
            { Columns => {} },
            ( $map_id, $map_start, $map_stop )
        )
    };

    #
    # Find every other map position for the features on this map.
    #
    my %comparative_maps;
    for my $feature ( @$features ) {
        my $positions = $db->selectall_arrayref(
            $sql->feature_correspondence_sql(
                map_aid => $comparative_map_aid
            ),
            { Columns => {} },
            ( $feature->{'feature_id'} )
        ); 

        for my $position ( @$positions ) {
            $comparative_maps{ $position->{'map_aid'} } = {
                map_aid      => $position->{'map_aid'},
                map_set_name => join(' - ',
                    $position->{'species_name'},
                    $position->{'map_set_name'},
                    $position->{'map_name'}
                )
            };
        }

        $feature->{'no_positions'}    = scalar @$positions;
        $feature->{'positions'}       = $positions;
        $feature->{'highlight_color'} = 
            $highlight_hash->{ uc $feature->{'feature_name'} }
            ? $self->config('feature_highlight_bg_color')
            : '';
    }

    my @comparative_maps = 
        sort { 
            $a->{'map_set_name'} cmp $b->{'map_set_name'} 
        } 
        values %comparative_maps
    ;

    return {
        features          => $features,
        feature_types     => \@feature_types,
        reference_map     => $reference_map,
        comparative_maps  => \@comparative_maps,
    }
}

# ----------------------------------------------------
sub sql {

=pod

=head2 sql

Returns the correct SQL module driver for the RDBMS we're using.

=cut
    my $self      = shift;
    my $db_driver = lc shift;

    unless ( defined $self->{'sql_module'} ) {
        my $db         = $self->db or return;
        $db_driver     = lc $db->{'Driver'}->{'Name'} || '';
        $db_driver     = DEFAULT->{'sql_driver_module'}
                         unless VALID->{'sql_driver_module'}{ $db_driver };
        my $sql_module = VALID->{'sql_driver_module'}{ $db_driver };

        eval "require $sql_module" or return $self->error(
            qq[Unable to require SQL module "$sql_module": $@]
        );

        $self->{'sql_module'} = $sql_module->new; 
    }

    return $self->{'sql_module'};
}

# ----------------------------------------------------
sub verify_map_range {

=pod

=head2 verify_map_range

Makes sure that a map doesn't include too many or too few features.  Set
MAX_FEATURE_COUNT to zero or undefined to disable this.

=cut
    my ( $self, %args ) = @_;
    my $map_id          = $args{'map_id'} or return;
    my $begin           = $args{'begin'} || $self->map_start(map_id => $map_id);
    my $end             = $args{'end'}   || $self->map_stop (map_id => $map_id);
    my $start           = $args{'start'} =~ NUMBER_RE ? $args{'start'} : $begin;
    my $stop            = $args{'stop'}  =~ NUMBER_RE ? $args{'stop'}  : $end;
    my $max_fcount      = $self->config('max_feature_count') || 0;
    return ( $start, $stop ) unless $max_fcount > 0;
    my $db              = $self->db  or return;
    my $sql             = $self->sql or return;
    my $minimum_trunc   = 1.01;
    my $minimum_augment = ( 1.01 * ( $end - $begin ) ) || 1;

#    warn "\nmap begin = $begin, end = $end.\n";

    #
    # Make sure of how many features we'll be selecting.
    #
    while ( 1 ) {
        my $feature_count = $db->selectrow_array(
            $sql->cmap_data_feature_count_sql,
            { Columns => {} },
            ( $map_id, $start, $stop )
        );
#        warn "start = $start, stop = $stop, feature count = $feature_count\n";

        #
        # Porridge is too cold.  Increase search range incrementally.
        #
        if ( $feature_count <= 0 ) {
            if ( $stop + $minimum_augment <= $end ) {
                $stop += $minimum_augment;
            }
            elsif ( $start - $minimum_augment >= $begin ) {
                $start -= $minimum_augment;
            }
            else {
                $start -= $minimum_augment/2;
                $stop  += $minimum_augment/2;
            }

            next;
        }

        #
        # Porridge is too hot.  Decrease search range by some factor 
        # of the number of results.
        #
        elsif ( $feature_count > $max_fcount ) {
#            my $factor = sprintf( "%0.1f", $feature_count/$max_fcount );
            my $factor = $feature_count/$max_fcount;
            $factor    = $minimum_trunc if $factor < $minimum_trunc;
            $stop      = int ( $start + ( ( $stop - $start ) / $factor ) );
            next;
        }

        #
        # This one's just right.
        #
        else {
            last;
        }
    }

    return ( $start, $stop );
}

1;

# ----------------------------------------------------
# An aged man is but a paltry thing,
# A tattered coat upon a stick.
# William Butler Yeats
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>, L<DBI>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

Copyright (c) 2002 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
