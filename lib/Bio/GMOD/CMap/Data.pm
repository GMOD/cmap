package Bio::GMOD::CMap::Data;

# $Id: Data.pm,v 1.51 2003-07-11 22:49:03 kycl4rk Exp $

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
$VERSION = (qw$Revision: 1.51 $)[-1];

use Data::Dumper;
use Time::ParseDate;
#use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Utils;
use base 'Bio::GMOD::CMap';

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->data_source( $config->{'data_source'} );
    return $self;
}

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

    my ( $self, %args )        = @_;
    my $slots                  = $args{'slots'};
    my $min_correspondences    = $args{'min_correspondences'}    ||  0;
    my $include_feature_types  = $args{'include_feature_types'}  || [];
    my $include_evidence_types = $args{'include_evidence_types'} || [];
    my @slot_nos               = keys %$slots;
    my @pos                    = sort { $a <=> $b } grep { $_ >= 0 } @slot_nos;
    my @neg                    = sort { $b <=> $a } grep { $_ <  0 } @slot_nos; 
    my @ordered_slot_nos       = ( @pos, @neg );

    #
    # "-1" is a reserved value meaning "All."
    #
    $include_feature_types  = [] if grep { /^-1$/ } @$include_feature_types;
    $include_evidence_types = [] if grep { /^-1$/ } @$include_evidence_types;
    my $feature_type_ids    = 
        $self->feature_type_aid_to_id( @$include_feature_types );
    my $evidence_type_ids   =
        $self->evidence_type_aid_to_id( @$include_evidence_types );

    my ( $data, %correspondences, %correspondence_evidence, %feature_types );
    for my $slot_no ( @ordered_slot_nos ) {
        my $cur_map = $slots->{ $slot_no };
        my $ref_map = $slot_no == 0 ? undef :
            $slot_no > 0 ? $slots->{ $slot_no - 1 } : $slots->{ $slot_no + 1 };

        $data->{'slots'}{ $slot_no } =  $self->map_data( 
            map                      => \$cur_map,                 # pass
            correspondences          => \%correspondences,         # by
            correspondence_evidence  => \%correspondence_evidence, # ref-
            feature_types            => \%feature_types,           # erence
            reference_map            => $ref_map,
            slot_no                  => $slot_no,
            min_correspondences      => $min_correspondences,
            feature_type_ids         => $feature_type_ids,
            evidence_type_ids        => $evidence_type_ids,
        ) || {};
    }

    #
    # Allow only one correspondence evidence per (the top-most ranking).
    #
    for my $fc_id ( keys %correspondence_evidence ) {
        my @evidence = 
            sort { $a->{'evidence_rank'} <=> $b->{'evidence_rank'} }
            @{ $correspondence_evidence{ $fc_id } };
        $correspondence_evidence{ $fc_id } = $evidence[0];
    }

    $data->{'correspondences'}         = \%correspondences;
    $data->{'correspondence_evidence'} = \%correspondence_evidence;
    $data->{'feature_types'}           = \%feature_types;

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
    my $slot_no                 = $args{'slot_no'};
    my $min_correspondences     = $args{'min_correspondences'} ||  0;
    my $feature_type_ids        = $args{'feature_type_ids'};
    my $evidence_type_ids       = $args{'evidence_type_ids'};
    my $map                     = ${ $args{'map'} }; # hashref
    my $reference_map           = $args{'reference_map'};
    my $correspondences         = $args{'correspondences'};
    my $correspondence_evidence = $args{'correspondence_evidence'};
    my $feature_types           = $args{'feature_types'};

    #
    # Sort out the current map.
    #
    my $aid_field   = $map->{'field'};
    my $map_start   = $map->{'start'};
    my $map_stop    = $map->{'stop'};
    my $map_aid     = $aid_field eq 'map_aid'     ? $map->{'aid'} : '';
    my $map_set_aid = $aid_field eq 'map_set_aid' ? $map->{'aid'} : '';
    my $no_flanking_positions = $map->{'no_flanking_positions'} || 0;

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
    # Turn the accession id into an internal id.
    #
    my $map_set_id = $map_set_aid
        ? $self->acc_id_to_internal_id(
            table      => 'cmap_map_set', 
            acc_id     => $map_set_aid,
        )
        : undef
    ;

    my %corr_lookup;
    if ( $ref_map_id || $ref_map_set_id ) {
        my $single_map_id = $map_aid
            ? $self->acc_id_to_internal_id(
                table      => 'cmap_map', 
                acc_id     => $map_aid,
            )
            : undef
        ;

        my ( $from_field, $from_restriction, $to_field, 
            $to_restriction, @corr_args );

        if ( $ref_map_set_id ) {
            $from_field = 'map_set_id';
            push @corr_args, $ref_map_set_id;
        }
        else {
            $from_field = 'map_id';
            $from_restriction = qq[
                and      (
                    ( f1.start_position>=$ref_map_start and 
                      f1.start_position<=$ref_map_stop )
                    or   (
                        f1.stop_position is not null and
                        f1.start_position<=$ref_map_start and
                        f1.stop_position>=$ref_map_stop
                    )
                )
            ];
            push @corr_args, $ref_map_id;
        }

        if ( $map_set_id ) { 
            $to_field = 'map_set_id';
            push @corr_args, $map_set_id;
        }
        else {
            $to_field = 'map_id';
            push @corr_args, $single_map_id;
            if ( defined $map_start && defined $map_stop ) {
                $to_restriction = qq[
                    and f2.start_position>=$map_start
                    and f2.stop_position<=$map_stop
                ];
            }
        }

        my $sql = qq[
            select   f1.feature_id as feature_id1,
                     f2.feature_id as feature_id2, 
                     map2.map_id,
                     cl.feature_correspondence_id,
                     et.evidence_type,
                     et.rank as evidence_rank,
                     et.line_color
            from     cmap_feature f1, 
                     cmap_map map1,
                     cmap_feature f2, 
                     cmap_map map2,
                     cmap_correspondence_lookup cl,
                     cmap_feature_correspondence fc,
                     cmap_correspondence_evidence ce,
                     cmap_evidence_type et
            where    f1.map_id=map1.map_id
            and      map1.$from_field=?
            $from_restriction
            and      f1.feature_id=cl.feature_id1
            and      cl.feature_correspondence_id=
                     fc.feature_correspondence_id
            and      fc.is_enabled=1
            and      fc.feature_correspondence_id=
                     ce.feature_correspondence_id
            and      ce.evidence_type_id=et.evidence_type_id
            and      cl.feature_id2=f2.feature_id
            and      f2.map_id=map2.map_id
            and      map2.$to_field=?
            $to_restriction
        ];

        if ( @$evidence_type_ids ) {
            $sql .= 'and ce.evidence_type_id in ('.
                join( ',', @$evidence_type_ids ).
            ')';
        }

        if ( @$feature_type_ids ) {
            $sql .= 'and f1.feature_type_id in ('.
                join( ',', @$feature_type_ids ).
            ')';
        }

        my $ref_map_correspondences = $db->selectall_arrayref(
            $sql, { Columns => {} }, ( @corr_args )
        );

        for my $corr ( @{ $ref_map_correspondences || [] } ) {
            push @{ $corr_lookup{ $corr->{'map_id'} } }, $corr;
        }

#        print STDERR "ref map corr = ", Dumper( $ref_map_correspondences ), "\n";
#        print STDERR "sql =\n$sql\nargs = ", join(', ', @corr_args), "\n";
    }

    #
    # Whether or not the user choses more than one map (e.g., a 
    # whole map set), we'll sort out which maps are involved individually.
    #
    my @maps = ();
    if ( $map_set_id ) {
        if ( $ref_map_id || $ref_map_set_id ) {
            if ( $ref_map_id ) {
                push @maps, @{ $db->selectall_arrayref(
                    $sql->map_data_map_ids_by_single_reference_map(
                        evidence_type_ids => $evidence_type_ids,
                    ),
                    { Columns => {} },
                    ( $ref_map_id, $ref_map_start, $ref_map_stop, 
                      $map_set_id, $ref_map_id
                    )
                ) };
            }
            elsif ( $reference_map->{'map_ids'} ) {
                push @maps, @{ $db->selectall_arrayref(
                    qq[
                        select distinct map.map_id,
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
                               cmap_feature f1, 
                               cmap_feature f2, 
                               cmap_map_set ms,
                               cmap_species s,
                               cmap_map_type mt,
                               cmap_correspondence_lookup cl,
                               cmap_feature_correspondence fc
                        where  f1.map_id in ( $reference_map->{'map_ids'} )
                        and    f1.feature_id=cl.feature_id1
                        and    cl.feature_correspondence_id=
                               fc.feature_correspondence_id
                        and    fc.is_enabled=1
                        and    cl.feature_id2=f2.feature_id
                        and    f2.map_id=map.map_id
                        and    map.map_set_id=?
                        and    map.map_id not in ( $reference_map->{'map_ids'} )
                        and    map.map_set_id=ms.map_set_id
                        and    ms.map_type_id=mt.map_type_id
                        and    ms.species_id=s.species_id
                    ],
                    {},
                    ( $map_set_id )
                ) };
            }
            else {
                @maps = ();
            }
        }
        else {
            push @maps, @{ 
                $db->selectall_arrayref(
                    q[
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
                        where  map.map_set_id=?
                        and    map.map_set_id=ms.map_set_id
                        and    ms.map_type_id=mt.map_type_id
                        and    ms.species_id=s.species_id
                    ],
                    { Columns => {} },
                    ( $map_set_id )
                ) 
            };
        }

        $map->{'map_ids'} = join( ',', map { $_->{'map_id'} } @maps );
    }
    else {
        #
        # Turn the accession id into an internal id.
        #
        push @maps, @{ 
            $db->selectall_arrayref(
                q[
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
                    where  map.accession_id=?
                    and    map.map_set_id=ms.map_set_id
                    and    ms.map_type_id=mt.map_type_id
                    and    ms.species_id=s.species_id
                ],
                { Columns => {} },
                ( $map_aid )
            ) 
        };
    }

    #
    # For each map, go through and figure out the features involved.
    #
    my $maps;
    for my $map_data ( @maps ) {
        my $map_id = $map_data->{'map_id'};

        #
        # If we're looking at more than one map (a whole map set), 
        # then we'll use the "start" and "stop" found for the current map.
        # Otherwise, we'll use the arguments supplied (if any).
        #
        if ( scalar @maps > 1 ) { 
            $map_start = $map_data->{'start_position'};
            $map_stop  = $map_data->{'stop_position'};
        }
        else {
            #
            # Make sure the start and stop are numbers.
            #
            $map_start = undef if $map_start eq '';
            $map_stop  = undef if $map_stop  eq '';

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
        # If we had to move the start and stop, remember it.
        #
        $map_data->{'start'} = $map_start;
        $map_data->{'stop'}  = $map_stop;
        $map->{'start'}      = $map_start;
        $map->{'stop'}       = $map_stop;

        #
        # Count the correspondences and see if there are enough.
        #
        my $map_correspondences = $corr_lookup{ $map_id };

#        my $map_correspondences;
#        if ( $ref_map_id ) {
#            $map_correspondences = $db->selectall_arrayref(
#                $sql->map_data_feature_correspondence_by_map_sql(
#                    feature_type_ids  => $feature_type_ids,
#                    evidence_type_ids => $evidence_type_ids,
#                ),
#                { Columns => {} },
#                ( 
#                    $ref_map_id, $ref_map_start, $ref_map_stop,
#                    $map_id, $map_id, $map_start, $map_stop
#                )
#            );
#        }
#        elsif ( $ref_map_set_id ) {
#            if ( my $ref_map_ids = $reference_map->{'map_ids'} ) {
#                $map_correspondences = $db->selectall_arrayref(
#                    $sql->map_data_feature_correspondence_by_multi_maps_sql(
#                        reference_map_ids => "$ref_map_ids,$map_id",
#                        evidence_type_ids => $evidence_type_ids,
#                        feature_type_ids  => $feature_type_ids,
#                    ),
#                    { Columns => {} },
#                    ( $map_id, $map_start, $map_stop )
#                );
#            }
#            else {
#                $map_correspondences = $db->selectall_arrayref(
#                    $sql->map_data_feature_correspondence_by_map_set_sql(
#                        evidence_type_ids => $evidence_type_ids,
#                        feature_type_ids  => $feature_type_ids,
#                    ),
#                    { Columns => {} },
#                    ( $ref_map_set_id, $map_id, $map_id, $map_start, $map_stop )
#                );
#            }
#        }

        if ( @{ $map_correspondences || [] } ) {
            my %distinct_correspondences;

            for my $corr ( @{ $map_correspondences || [] } ) {
                $correspondences->{ 
                    $corr->{'feature_id1'} }{ $corr->{'feature_id2'} 
                } = $corr->{'feature_correspondence_id'};

                $correspondences->{
                    $corr->{'feature_id2'} }{ $corr->{'feature_id1'}
                } = $corr->{'feature_correspondence_id'};

                $distinct_correspondences{
                    $corr->{'feature_correspondence_id'}
                } = 1;

                push @{ $correspondence_evidence->{ 
                    $corr->{'feature_correspondence_id'}
                } }, {
                    evidence_type => $corr->{'evidence_type'}, 
                    evidence_rank => $corr->{'evidence_rank'}, 
                    line_color    => $corr->{'line_color'},
                };
            }

            $map_data->{'no_correspondences'} = 
                scalar keys %distinct_correspondences;
        }

        next if 
            $min_correspondences && 
            $map_correspondences && 
            $map_data->{'no_correspondences'} < $min_correspondences;

        #
        # Get the map features.
        #
        $map_data->{'features'} = $db->selectall_hashref(
            $sql->cmap_data_features_sql(
                feature_type_ids => $feature_type_ids, 
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

        $maps->{ $map_id } = $map_data;
    }

    #
    # It's possible we won't have found any maps
    #
    unless ( defined $maps ) {
        my $map_id;
        if ( $map_set_aid ) {
            $map_id = $db->selectrow_array(
                q[
                    select map.map_id   
                    from   cmap_map map,
                           cmap_map_set ms
                    where  map.map_set_id=ms.map_set_id
                    and    ms.accession_id=?
                ],
                {},
                ( "$map_set_aid" )
            );
        }
        else {
            $map_id = $db->selectrow_array(
                q[
                    select map.map_id   
                    from   cmap_map map
                    where  map.accession_id=?
                ],
                {},
                ( "$map_aid" )
            );
        }

        my $sth = $db->prepare( $sql->cmap_data_map_info_sql );
        $sth->execute( $map_id );
        $maps->{ $map_id } = $sth->fetchrow_hashref;
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
            select   distinct map.map_name,
                     map.display_order
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
        $map_sql .= 'order by map.display_order, map.map_name';
        $maps     = $db->selectall_arrayref( $map_sql, { Columns=>{} } );
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

        $map_set_sql .= 'order by map.display_order, map.map_name';

        @reference_map_sets = @{ 
            $db->selectall_arrayref( $map_set_sql, { Columns => {} } )
        };
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

        @reference_map_sets = @{ 
            $db->selectall_arrayref( $map_set_sql, { Columns => {} } )
        };
    }

    #
    # If there's only only set, then pretend that the user selected 
    # this one and expand the relationships to the map level.
    #
    if ( $map_set_aid eq '' && scalar @reference_map_sets == 1 ) {
        $map_set_aid = $reference_map_sets[0]->{'map_set_aid'};
    }

#    warn "map set aid = $map_set_aid\n";
#    warn "ref map sets =\n", Dumper( \@reference_map_sets ), "\n";

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
#    warn "lookup =\n", Dumper( \%lookup ), "\n";

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
            order by map.display_order, map.map_name
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

    my @all_map_sets = @{ 
        $db->selectall_arrayref( $link_map_set_sql, { Columns => {} } )
    };

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

    my ( $self, %args )        = @_;
    my $slots                  = $args{'slots'} or return;
    my $min_correspondences    = $args{'min_correspondences'}    ||  0;
    my $include_feature_types  = $args{'include_feature_types'}  || [];
    my $include_evidence_types = $args{'include_evidence_types'} || [];
    my $ref_map                = $slots->{ 0 };
    my $ref_map_set_aid        = $ref_map->{'map_set_aid'}       ||  0;
    my $ref_map_aid            = $ref_map->{'aid'}               ||  0;
    my $ref_map_start          = $ref_map->{'start'};
    my $ref_map_stop           = $ref_map->{'stop'};
    my $db                     = $self->db  or return;
    my $sql                    = $self->sql or return;

    #
    # Select all the map set that can be reference maps.
    #
    my $ref_map_sets = $db->selectall_arrayref(
        $sql->form_data_ref_map_sets_sql,
        { Columns => {} }
    );

    #
    # "-1" is a reserved value meaning "All."
    #
    $include_feature_types  = [] if grep { /^-1$/ } @$include_feature_types;
    $include_evidence_types = [] if grep { /^-1$/ } @$include_evidence_types;
    my $feature_type_ids    = 
        $self->feature_type_aid_to_id( @$include_feature_types );
    my $evidence_type_ids   =
        $self->evidence_type_aid_to_id( @$include_evidence_types );

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
    }

    #
    # If there is a ref. map selected but no start and stop, find 
    # the ends of the ref. map.
    #
    if ( $ref_map_aid ) {
        my $map_id   =  $self->acc_id_to_internal_id(
            id_field => 'map_id',
            table    => 'cmap_map', 
            acc_id   => $ref_map_aid,
        );

        #
        # Make sure the start and stop are numbers.
        #
        $ref_map_start = undef if $ref_map_start eq '';
        $ref_map_stop  = undef if $ref_map_stop  eq '';
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

    my @slot_nos      = sort { $a <=> $b } keys %$slots;
    my $rightmost_map = $slots->{ $slot_nos[-1] };
    my $leftmost_map  = $slots->{ $slot_nos[ 0] };
    my %feature_types;

    my $comp_maps_right     =  $self->get_comparative_maps( 
        map                 => $rightmost_map,
        min_correspondences => $min_correspondences,
        feature_type_ids    => $feature_type_ids,
        evidence_type_ids   => $evidence_type_ids,
        feature_types       => \%feature_types,
    );

    my $comp_maps_left      =  
        $leftmost_map->{'field'} eq $rightmost_map->{'field'}
        &&
        $leftmost_map->{'aid'} eq $rightmost_map->{'aid'}
        ? $comp_maps_right
        : $self->get_comparative_maps(
            map                 => $leftmost_map,
            min_correspondences => $min_correspondences,
            feature_type_ids    => $feature_type_ids,
            evidence_type_ids   => $evidence_type_ids,
            feature_types       => \%feature_types,
        )
    ;

    #
    # Correspondence evidence types.
    #
    my @evidence_types = 
        sort { lc $a->{'evidence_type'} cmp lc $b->{'evidence_type'} } @{
        $db->selectall_arrayref(
            q[
                select   et.accession_id as evidence_type_aid,
                         et.evidence_type
                from     cmap_evidence_type et
                order by et.evidence_type
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
        evidence_types         => \@evidence_types,
    };
}

# ----------------------------------------------------
sub get_comparative_maps {

=pod

=head2 get_comparative_maps

Given a reference map and (optionally) start and stop positions, figure
out which maps have relationships.

=cut

    my ( $self, %args )     = @_;
    my $map                 = $args{'map'};
    my $min_correspondences = $args{'min_correspondences'};
    my $feature_type_ids    = $args{'feature_type_ids'};
    my $evidence_type_ids   = $args{'evidence_type_ids'};
    my $feature_types       = $args{'feature_types'};

    my $aid_field         = $map->{'field'};
    my $ref_map_aid       = $aid_field eq 'map_aid'     ? $map->{'aid'} : '';
    my $ref_map_set_aid   = $aid_field eq 'map_set_aid' ? $map->{'aid'} : '';
    return unless $ref_map_aid || $ref_map_set_aid;

    my $ref_map_start     = $map->{'start'};
    my $ref_map_stop      = $map->{'stop'};
    my $db                = $self->db  or return;
    my $sql               = $self->sql or return;
    
    #
    # Find the correspondences to other maps.
    #
    my $feature_correspondences;
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

        if ( my $map_ids = $map->{'map_ids'} ) {
            $feature_correspondences = $db->selectall_hashref(
                $sql->correspondences_count_by_multi_maps_sql( 
                    map_ids           => $map_ids,
                    feature_type_ids  => $feature_type_ids,
                    evidence_type_ids => $evidence_type_ids,
                ),
                'feature_correspondence_id',
                { Columns => {} },
            );
        }
        else {
            my $map_set_id =  $self->acc_id_to_internal_id(
                table      => 'cmap_map_set', 
                acc_id     => $ref_map_set_aid,
            );
        
            $feature_correspondences = $db->selectall_hashref(
                $sql->correspondences_count_by_map_set_sql(
                    feature_type_ids  => $feature_type_ids,
                    evidence_type_ids => $evidence_type_ids,
                ),
                'feature_correspondence_id',
                { Columns => {} },
                ( $map_set_id, $map_set_id )
            );
        }
    }
    else {
        #
        # Make sure we have a start and stop.
        #
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

        $feature_correspondences = $db->selectall_hashref(
            $sql->correspondences_count_by_single_map_sql(
                feature_type_ids  => $feature_type_ids,
                evidence_type_ids => $evidence_type_ids,
            ),
            'feature_correspondence_id',
            { Columns => {} },
            ( $ref_map_aid, $ref_map_start, $ref_map_stop, $ref_map_aid )
        );
    }

    #
    # Because of the mess with having to join down to the
    # correspondence evidence table, it's hard to get the
    # *distinct* count of correspondences we need (because
    # there can be multiple evidence codes for each
    # correspondence).  For this reason, we have to just
    # select all the correspondences and use the
    # "selectall_hashref" routine to make them distinct on the
    # "feature_correspondence_id" field, then go through them
    # all and count up by hand how many occur for each map and
    # map set.
    #
    my %count_by_map;     # how many corr. for each map
    my %map_set_aids;     # lookup for map set aid by map aid
    my %map_sets;         # the map set info and any maps (if applicable)
    for my $fc ( values %$feature_correspondences ) {
        my $map_set_aid  = $fc->{'map_set_aid'};
        my $map_aid      = $fc->{'map_aid'};

        $count_by_map{ $map_aid }++;  
        $map_set_aids{ $map_aid } = $map_set_aid;

        unless ( defined $map_sets{ $map_set_aid } ) {
            for ( qw[ 
                map_type_display_order 
                map_type     
                species_display_order  
                species_name 
                ms_display_order       
                map_set_name           
                map_set_aid 
            ] ) {
                $map_sets{ $map_set_aid }{ $_ } = $fc->{ $_ };
                $map_sets{ $map_set_aid }{'published_on'} = 
                    parsedate( $fc->{'published_on'} );
            }
        }

        unless ( defined $map_sets{ $map_set_aid }{'maps'}{ $map_aid } ) {
            $map_sets{ $map_set_aid }{'maps'}{ $map_aid } = {
                map_name             => $fc->{'map_name'},
                map_aid              => $fc->{'map_aid'},
                display_order        => $fc->{'map_display_order'},
                can_be_reference_map => $fc->{'can_be_reference_map'},
            }
        }
    }

    #
    # Sort the map sets and maps for display, count up correspondences.
    #
    my @sorted_map_sets;
    for my $map_set (
        sort { 
            $a->{'map_type_display_order'} <=> $b->{'map_type_display_order'} 
            ||
            $a->{'map_type'}               cmp $b->{'map_type'} 
            ||
            $a->{'species_display_order'}  <=> $b->{'species_display_order'} 
            ||
            $a->{'species_name'}           cmp $b->{'species_name'} 
            ||
            $a->{'ms_display_order'}       <=> $b->{'ms_display_order'} 
            ||
            $b->{'published_on'}           <=> $a->{'published_on'} 
            ||
            $a->{'map_set_name'}           cmp $b->{'map_set_name'} 
        } 
        values %map_sets
    ) {
        my @maps;                  # the maps for the map set
        my $total_correspondences; # all the correspondences for the map set
        my $can_be_reference_map;  # whether or not it can

        for my $map (
            sort {
                $a->{'display_order'} <=> $b->{'display_order'} 
                ||
                $a->{'map_name'}      cmp $b->{'map_name'} 
            }
            values %{ $map_set->{'maps'} }
        ) {
            $can_be_reference_map        = $map->{'can_be_reference_map'};
            $map->{'no_correspondences'} = $count_by_map{ $map->{'map_aid'} };
            next if $min_correspondences &&
                $map->{'no_correspondences'} < $min_correspondences;

            $total_correspondences += $map->{'no_correspondences'};
            push @maps, $map if $map->{'can_be_reference_map'};
        }

        next unless $total_correspondences;
        next if !@maps and $can_be_reference_map;

        push @sorted_map_sets, { 
            map_type           => $map_set->{'map_type'},
            species_name       => $map_set->{'species_name'},
            map_set_name       => $map_set->{'map_set_name'},
            map_set_aid        => $map_set->{'map_set_aid'},
            no_correspondences => $total_correspondences,
            maps               => \@maps,
        };
    }

    return \@sorted_map_sets;
}

# ----------------------------------------------------
sub evidence_type_aid_to_id {

=pod

=head2 evidence_type_aid_to_id

Takes a list of evidence type accession IDs and returns their table IDs.

=cut

    my $self               = shift;
    my @evidence_type_aids = @_;
    my @evidence_type_ids  = ();
    my $db                 = $self->db;

    for my $aid ( @evidence_type_aids ) {
        next unless defined $aid && $aid ne '';
        my $id = $db->selectrow_array(
            q[
                select evidence_type_id
                from   cmap_evidence_type
                where  accession_id=?
            ],
            {},
            ( "$aid" )
        );
        push @evidence_type_ids, $id;
    }

    return @evidence_type_ids ? [ @evidence_type_ids ] : [];
}

# ----------------------------------------------------
sub feature_type_aid_to_id {

=pod

=head2 feature_type_aid_to_id

Takes a list of feature type accession IDs and returns their table IDs.

=cut

    my $self              = shift;
    my @feature_type_aids = @_;
    my @feature_type_ids  = ();
    my $db                = $self->db;

    for my $aid ( @feature_type_aids ) {
        next unless defined $aid && $aid ne '';
        my $id = $db->selectrow_array(
            q[
                select feature_type_id
                from   cmap_feature_type
                where  accession_id=?
            ],
            {},
            ( "$aid" )
        );
        push @feature_type_ids, $id;
    }

    return @feature_type_ids ? [ @feature_type_ids ] : [];
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

    my ( $self, %args )   = @_;
    my $species_aids      = $args{'species_aids'};
    my $feature_type_aids = $args{'feature_type_aids'};
    my $feature_string    = $args{'features'};
    my @feature_names     = (
        map { 
            s/\*/%/g;       # turn stars into SQL wildcards
            s/,//g;         # remove commas
            s/^\s+|\s+$//g; # remove leading/trailing whitespace
            s/"//g;         # remove double quotes
            s/'/\\'/g;      # backslash escape single quotes
            uc $_ || ()     # uppercase what's left
        }
        parse_words( $feature_string )
    );
    my $order_by         = $args{'order_by'} || 
        'feature_name,species_name,map_set_name,map_name,start_position';
    my $search_field     = 
        $args{'search_field'} || $self->config('feature_search_field');
    $search_field        = DEFAULT->{'feature_search_field'} 
        unless VALID->{'feature_search_field'}{ $search_field };
    my $db               = $self->db  or return;

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
                   ms.can_be_reference_map,
                   s.species_id,
                   s.common_name as species_name
            from   cmap_feature f, 
                   cmap_feature_type ft,
                   cmap_map map,
                   cmap_map_set ms,
                   cmap_species s
            $where
            and    f.feature_type_id=ft.feature_type_id
            and    f.map_id=map.map_id
            and    map.map_set_id=ms.map_set_id
            and    ms.is_enabled=1
            and    ms.species_id=s.species_id
        ];

        if ( @$feature_type_aids ) {
            $sql .= 'and ft.accession_id in ('.
                join( ', ', map { qq['$_'] } @$feature_type_aids ). 
            ')';
        }

        if ( @$species_aids ) {
            $sql .= 'and s.accession_id in ('.
                join( ', ', map { qq['$_'] } @$species_aids ). 
            ')';
        }

        $sql .= "order by $order_by";

        push @found_features, @{ 
            $db->selectall_arrayref( $sql, { Columns => {} } ) 
        };
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

=head2 map_set_viewer_data

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
                 s.full_name,
                 s.ncbi_taxon_id
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
                    order by display_order,map_name
                ],
                { Columns => {} }, ( $map_set->{'map_set_id'} )
            )
        } or next;

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

    my ( $self, %args )        = @_;
    my $slots                  = $args{'slots'};
    my $map                    = $slots->{'0'};
    my $highlight              = $args{'highlight'}             || '';
    my $order_by               = $args{'order_by'}          || 'start_position';
    my $comparative_map_field  = $args{'comparative_map_field'} || '';
    my $comparative_map_aid    = $args{'comparative_map_aid'}   || '';
    my $db                     = $self->db  or return;
    my $sql                    = $self->sql or return;
    my $map_id                 = $self->acc_id_to_internal_id(
        table                  => 'cmap_map',
        acc_id                 => $map->{'aid'},
    ) ;
    my $map_start              = $map->{'start'};
    my $map_stop               = $map->{'stop'};

    my $include_feature_types  = $args{'include_feature_types'};
    my $include_evidence_types = $args{'include_evidence_types'};

    #
    # "-1" is a reserved value meaning "All."
    #
    $include_feature_types  = [] if grep { /^-1$/ } @$include_feature_types;
    $include_evidence_types = [] if grep { /^-1$/ } @$include_evidence_types;
    my $feature_type_ids    = 
        $self->feature_type_aid_to_id( @$include_feature_types );
    my $evidence_type_ids   =
        $self->evidence_type_aid_to_id( @$include_evidence_types );

    #
    # Figure out hightlighted features.
    #
    my $highlight_hash = {
        map  { s/^\s+|\s+$//g; ( uc $_, 1 ) } 
        parse_words( $highlight )
#        split( /[,:;\s+]/, $highlight ) 
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
            order_by         => $order_by,
            feature_type_ids => $feature_type_ids,
        ),
        { Columns => {} },
        ( $map_id, $map_start, $map_stop, $map_start, $map_start )
    );

    #
    # Get all the map IDs to use to restrict the feature types.
    #
    my @all_map_ids;
    for my $slot ( values %$slots ) {
        if ( $slot->{'field'} eq 'map_set_aid' ) {
            push @all_map_ids, @{
                $db->selectcol_arrayref(
                    q[
                        select map.map_id
                        from   cmap_map map,
                               cmap_map_set ms
                        where  map.map_set_id=ms.map_set_id
                        and    ms.accession_id=?
                    ],
                    {},
                    ( $slot->{'aid'} )
                )
            };
        }
        else {
            push @all_map_ids, @{
                $db->selectcol_arrayref(
                    q[
                        select map.map_id
                        from   cmap_map map
                        where  map.accession_id=?
                    ],
                    {},
                    ( $slot->{'aid'} )
                )
            };
        }
    }

    #
    # Feature types.
    #
    my $ft_sql;
    if ( @all_map_ids ) {
        $ft_sql .= q[
            select   distinct 
                     ft.accession_id as feature_type_aid,
                     ft.feature_type
            from     cmap_feature_type ft,
                     cmap_feature f
            where    f.feature_type_id=ft.feature_type_id
            and      f.map_id in (].
            join(',', @all_map_ids).q[)
            order by ft.feature_type
        ];
    }
    else {
        $ft_sql .= q[
            select   ft.accession_id as feature_type_aid,
                     ft.feature_type
            from     cmap_feature_type ft
            order by ft.feature_type
        ];
    }

    my @feature_types = 
        sort { lc $a->{'feature_type'} cmp lc $b->{'feature_type'} } 
        @{ $db->selectall_arrayref( $ft_sql, { Columns => {} } ) }
    ;

    #
    # Correspondence evidence types.
    #
    my @evidence_types = 
        sort { lc $a->{'evidence_type'} cmp lc $b->{'evidence_type'} } @{
        $db->selectall_arrayref(
            q[
                select   et.accession_id as evidence_type_aid,
                         et.evidence_type
                from     cmap_evidence_type et
                order by et.evidence_type
            ],
            { Columns => {} }
        )
    };

    #
    # Find every other map position for the features on this map.
    #
    my %comparative_maps;
    for my $feature ( @$features ) {
        my $positions = $db->selectall_arrayref(
            $sql->feature_correspondence_sql(
                comparative_map_field => $comparative_map_field,
                comparative_map_aid   => $comparative_map_aid,
                evidence_type_ids => 
                    @$evidence_type_ids ?  join(',', @$evidence_type_ids) : '',
            ),
            { Columns => {} },
            ( $feature->{'feature_id'} )
        ); 

        my ( %distinct_positions, %evidence );
        for my $position ( @$positions ) {
            my $map_set_aid = $position->{'map_set_aid'};
            my $map_aid     = $position->{'map_aid'};

            unless ( defined $comparative_maps{ $map_set_aid } ) {
                for ( qw[ 
                    map_aid      
                    map_type_display_order 
                    map_type              
                    species_display_order
                    species_name        
                    ms_display_order   
                    map_set           
                    species_name
                    map_set_name
                    map_set_aid
                ] ) {
                    $comparative_maps{ $map_set_aid }{ $_ } = $position->{$_};
                }

                $comparative_maps{ $map_set_aid }{'published_on'} =
                     parsedate( $position->{'published_on'} )
                ;
            }

            unless ( 
                defined $comparative_maps{ $map_set_aid }{'maps'}{ $map_aid }
            ) {
                $comparative_maps{ $map_set_aid }{'maps'}{ $map_aid } = {
                    display_order => $position->{'map_display_order'},
                    map_name      => $position->{'map_name'},
                    map_aid       => $position->{'map_aid'},
                };
            }

            $distinct_positions{ $position->{'feature_id'} } = $position;
            push @{ $evidence{ $position->{'feature_id'} } }, 
                $position->{'evidence_type'}; 
        }

        for my $position ( values %distinct_positions ) {
            $position->{'evidence'} = $evidence{ $position->{'feature_id'} };
        }
        
        $feature->{'no_positions'}    = scalar keys %distinct_positions;
        $feature->{'positions'}       = [ values %distinct_positions ];
        $feature->{'highlight_color'} = 
            $highlight_hash->{ uc $feature->{'feature_name'} }
            ? $self->config('feature_highlight_bg_color')
            : '';
    }

    my @comparative_maps;
    for my $map_set ( 
        sort { 
            $a->{'map_type_display_order'} <=> $b->{'map_type_display_order'} 
            ||
            $a->{'map_type'}               cmp $b->{'map_type'} 
            ||
            $a->{'species_display_order'}  <=> $b->{'species_display_order'} 
            ||
            $a->{'species_name'}           cmp $b->{'species_name'} 
            ||
            $a->{'ms_display_order'}       <=> $b->{'ms_display_order'} 
            ||
            $b->{'published_on'}           <=> $a->{'published_on'} 
            ||
            $a->{'map_set_name'}           cmp $b->{'map_set_name'} 
        } 
        values %comparative_maps
    ) {
        my @maps = sort {
            $a->{'display_order'} <=> $b->{'display_order'} 
            ||
            $a->{'map_name'}      cmp $b->{'map_name'} 
        } 
        values %{ $map_set->{'maps'} };

        push @comparative_maps, {
            map_set_name => 
                $map_set->{'species_name'}.' - '.$map_set->{'map_set_name'},
            map_set_aid  => $map_set->{'map_set_aid'},
            map_type     => $map_set->{'map_type'},
            maps         => \@maps,
        };
    }

    return {
        features          => $features,
        feature_types     => \@feature_types,
        evidence_types    => \@evidence_types,
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

=head1 COPYRIGHT

Copyright (c) 2002-3 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
