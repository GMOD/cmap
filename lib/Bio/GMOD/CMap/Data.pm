package Bio::GMOD::CMap::Data;
# vim: set ft=perl:

# $Id: Data.pm,v 1.116 2004-05-17 20:41:31 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.116 $)[-1];

use Data::Dumper;
use Regexp::Common;
use Time::ParseDate;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Utils;
use base 'Bio::GMOD::CMap';
use Cache::FileCache;
use Storable qw(freeze thaw);

# ----------------------------------------------------
sub init {
    #p#rint S#TDERR "init\n";
    my ( $self, $config ) = @_;
    $self->config($config->{'config'});
    $self->data_source( $config->{'data_source'} );
    my %cache_params = ('namespace'=>'sql_results',);
    $self->{'cache'}= new Cache::FileCache(\%cache_params);
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
            $self->error(qq[No id field and I cannot figure it out]);
        }
    }

    my $db = $self->db or return;
    my $sql_str=
       qq[
            select $id_field
            from   $table
            where  accession_id=?
	  ];
    my $id; 
    if(my $scalarref=$self->get_cached_results($sql_str.$acc_id)){
	$id=$$scalarref;
    }
    else{
	$id= $db->selectrow_array(
				  $sql_str,
				  {},
				  ( $acc_id )
				  ) or $self->error(
        qq[Unable to find internal id for acc. id "$acc_id" in table "$table"]
						    );
	$self->store_cached_results($sql_str.$acc_id,\$id);
    }
    return $id;
}

# ----------------------------------------------------

=pod

=head2 correspondence_detail_data

Gets the specifics on a feature correspondence record.

=cut

sub correspondence_detail_data {
    #p#rint S#TDERR "correspondence_detail_data\n";
    my ( $self, %args )    = @_;
    my $correspondence_aid = $args{'correspondence_aid'} or 
        return $self->error('No correspondence accession ID');
    my $db                 = $self->db;
    my $sql =  q[
            select feature_correspondence_id,
                   accession_id,
                   feature_id1,
                   feature_id2,
                   is_enabled
            from   cmap_feature_correspondence
            where  accession_id=?
		 ];
    my ($corr,$feature1,$feature2);
    unless (($corr,$feature1,$feature2)=@{$self->get_cached_results($sql.$correspondence_aid)}){
	my $sth                = $db->prepare($sql);
	$sth->execute( $correspondence_aid ); 
	
	my $corr = $sth->fetchrow_hashref or return $self->error(
	    "No record for correspondence accession ID '$correspondence_aid'"
	);

	$corr->{'attributes'} = $self->get_attributes(
          'cmap_feature_correspondence', $corr->{'feature_correspondence_id'},
						      );

	$corr->{'xrefs'} = $self->get_xrefs(
          'cmap_feature_correspondence', $corr->{'feature_correspondence_id'},
        );
	
	$sth = $db->prepare(
	    q[
            select f.feature_id, 
                   f.accession_id as feature_aid, 
                   f.map_id,
                   f.accession_id as map_aid,
                   f.feature_type_accession as feature_type_aid,
                   f.feature_name,
                   f.start_position,
                   f.stop_position,
                   map.map_name,
                   map.accession_id as map_aid,
                   ms.map_set_id,
                   ms.accession_id as map_set_aid,
                   ms.short_name as map_set_name,
                   s.common_name as species_name,
                   ms.map_units
            from   cmap_feature f,
                   cmap_map map,
                   cmap_map_set ms,
                   cmap_species s
            where  f.feature_id=?
            and    f.map_id=map.map_id
            and    map.map_set_id=ms.map_set_id
            and    ms.species_id=s.species_id
	      ]
        );
	$sth->execute( $corr->{'feature_id1'} );
	$feature1 = $sth->fetchrow_hashref;
	$sth->execute( $corr->{'feature_id2'} );
        $feature2 = $sth->fetchrow_hashref;

	$corr->{'evidence'} = $db->selectall_arrayref(
        qq[
            select   ce.correspondence_evidence_id,
                     ce.accession_id,
                     ce.feature_correspondence_id,
                     ce.score,
                     ce.evidence_type_accession as evidence_type_aid
            from     cmap_correspondence_evidence ce
            where    ce.feature_correspondence_id=?
        ],
        { Columns => {} },
        ( $corr->{'feature_correspondence_id'} )
        );

	foreach my $row ( @{ $corr->{'evidence'} } ) {
	    $row->{'rank'} =
		$self->evidence_type_data( $row->{'evidence_type_aid'}, 'rank' );
	    $row->{'evidence_type'} =
		$self->evidence_type_data( $row->{'evidence_type_aid'}, 'evidence_type' );
	}

	$corr->{'evidence'} = sort_selectall_arrayref(
	     $corr->{'evidence'}, 'rank', 'evidence_type'
						      );
	$self->store_cached_results($sql.$correspondence_aid,
				    [$corr,$feature1,$feature2])
    }
    return {
        correspondence => $corr,
        feature1       => $feature1,
        feature2       => $feature2,
    };
}

# ----------------------------------------------------
=pod

=head2 cmap_data

Organizes the data for drawing comparative maps.

=cut

sub cmap_data {
    #p#rint S#TDERR "cmap_data\n";
    my ( $self, %args )        = @_;
    my $slots                  = $args{'slots'};
    my $min_correspondences    = $args{'min_correspondences'}    ||  0;
    my $include_feature_type_aids  = $args{'include_feature_type_aids'}  || [];
    my $corr_only_feature_type_aids= $args{'corr_only_feature_type_aids'}|| [];
    my $include_evidence_type_aids = $args{'include_evidence_type_aids'} || [];
    my @slot_nos               = keys %$slots;
    my @pos                    = sort { $a <=> $b } grep { $_ >= 0 } @slot_nos;
    my @neg                    = sort { $b <=> $a } grep { $_ <  0 } @slot_nos; 
    my @ordered_slot_nos       = ( @pos, @neg );
    my $db                     = $self->db or return;
    my $pid=$$;

    #
    # "-1" is a reserved value meaning "All" for feature and evidence types
    # "-1" is reserved for "None"
    #
    $include_feature_type_aids  = [] if grep { /^-1$/ } @$include_feature_type_aids;
    $corr_only_feature_type_aids  = [] if grep { /^-1$/ } @$include_feature_type_aids;
    $include_evidence_type_aids = [] if grep { /^-1$/ } @$include_evidence_type_aids;
   

    #
    # Delete anything from the cache.
    #
    #$db->do("delete from cmap_map_cache where pid=$pid");

    my ( $data, %feature_correspondences, %intraslot_correspondences, 
	 %map_correspondences, 
        %correspondence_evidence, %feature_types, %map_type_aids);

    $self->slot_info($slots);
    for my $slot_no ( @ordered_slot_nos ) {
        my $cur_map     = $slots->{ $slot_no };
        my $ref_slot_no = $slot_no == 0 ? undef :
            $slot_no > 0 ? $slot_no - 1 : $slot_no + 1;
        my $ref_map     = defined $ref_slot_no ? $slots->{$ref_slot_no} : undef;

        $data->{'slots'}{ $slot_no } =  $self->slot_data( 
            map                      => \$cur_map,                 # pass
            feature_correspondences  => \%feature_correspondences, # by
            intraslot_correspondences  => \%intraslot_correspondences, #
            map_correspondences      => \%map_correspondences,     # ref
            correspondence_evidence  => \%correspondence_evidence, # "
            feature_types            => \%feature_types,           # "
            reference_map            => $ref_map,
            slot_no                  => $slot_no,
            ref_slot_no              => $ref_slot_no,
            min_correspondences      => $min_correspondences,
            feature_type_aids        => $include_feature_type_aids,
            corr_only_feature_type_aids => $corr_only_feature_type_aids,
            evidence_type_aids       => $include_evidence_type_aids,
            pid                      => $pid,
	    map_type_aids            =>\%map_type_aids,
        ) or return;
    }
    ###Get the extra javascript that goes along with the feature_types.
    ### and get extra forms
    my ($extra_code,$extra_form);
    ($extra_code,$extra_form)=
	$self->get_web_page_extras(\%feature_types,\%map_type_aids,$extra_code,$extra_form);
    #
    # Allow only one correspondence evidence per (the top-most ranking).
    #
    for my $fc_id ( keys %correspondence_evidence ) {
        my @evidence = 
            sort { $a->{'evidence_rank'} <=> $b->{'evidence_rank'} }
            @{ $correspondence_evidence{ $fc_id } };
        $correspondence_evidence{ $fc_id } = $evidence[0];
    }

    $data->{'correspondences'}         = \%feature_correspondences;
    $data->{'intraslot_correspondences'} = \%intraslot_correspondences;
    $data->{'map_correspondences'}     = \%map_correspondences;
    $data->{'correspondence_evidence'} = \%correspondence_evidence;
    $data->{'feature_types'}           = \%feature_types;
    $data->{'extra_code'}              =$extra_code;
    $data->{'extra_form'}              =$extra_form;

    return $data;
}

# ----------------------------------------------------
=pod

=head2 slot_data

Returns the feature and correspondence data for the maps in a slot.

=cut

sub slot_data {
    #p#rint S#TDERR "slot_data\n";
    my ( $self, %args )         = @_;
    my $db                      = $self->db  or return;
    my $sql                     = $self->sql or return;
    my $this_slot_no            = $args{'slot_no'};
    my $ref_slot_no             = $args{'ref_slot_no'};
    my $min_correspondences     = $args{'min_correspondences'} ||  0;
    my $feature_type_aids        = $args{'feature_type_aids'};
    my $evidence_type_aids       = $args{'evidence_type_aids'};
    my $slot_map                = ${ $args{'map'} }; # hashref
    my $reference_map           = $args{'reference_map'};
    my $feature_correspondences = $args{'feature_correspondences'};
    my $intraslot_correspondences=$args{'intraslot_correspondences'};
    my $map_correspondences     = $args{'map_correspondences'};
    my $correspondence_evidence = $args{'correspondence_evidence'};
    my $feature_types_seen      = $args{'feature_types'};
    my $corr_only_feature_type_aids = $args{'corr_only_feature_type_aids'};
    my $map_type_aids           = $args{'map_type_aids'};
    my $pid                     = $args{'pid'};
    my $max_no_features         = 200000;

    #
    # If there is more than 1 map in this slot, we will return totals
    # for all the features on every map and the number of
    # correspondences on them to the reference map.
    #
    # If there is just one map in this slot, then we will look to see
    # if the total number of features on the map exceeds some number
    # -- 200 for now.  If so, we will chunk the map's features and
    # correspondences;  if not, we will show all.
    #

    #
    # Sort out the map(s) in the current slot ("this" map) -- are we
    # looking at just one map or all the maps in the set?
    #
    my $map_start   = $slot_map->{'start'};
    my $map_stop    = $slot_map->{'stop'};
    $map_start      = undef if defined $map_start && $map_start eq '';
    $map_stop       = undef if defined $map_stop  && $map_stop  eq '';
    my @map_aids    = $slot_map->{'field'} eq 'map_aid'
        ? ref( $slot_map->{'aid'} ) eq 'ARRAY' 
            ? @{ $slot_map->{'aid'} } : split(/,/, $slot_map->{'aid'})
        : ();
    my $map_set_aid = $slot_map->{'map_set_aid'} ? $slot_map->{'map_set_aid'} 
        : $slot_map->{'field'} eq 'map_set_aid' ? $slot_map->{'aid'} : '';
    my $no_flanking_positions = $slot_map->{'no_flanking_positions'} || 0;

    #
    # Turn any accession ids into internal ids.
    #
    my $map_set_id = $map_set_aid
        ? $self->acc_id_to_internal_id(
            table      => 'cmap_map_set', 
            acc_id     => $map_set_aid,
        )
        : undef
    ;

    #
    # Allow individual selection of maps to override other selections.
    #
    my @slot_map_ids;
    if ( $slot_map->{'map_names'} && $map_set_id ) {
        my @map_names;
        if ( ref( $slot_map->{'map_names'} eq 'ARRAY' ) ) {
            @map_names = @{ $slot_map->{'map_names'} };
        }
        else {
            @map_names = map{s/^\s+|\s+$//g;$_} split(/,/, $slot_map->{'map_names'});
        }

        my @map_ids;
        for my $map_name ( @map_names ) {
	    my $sql=q[
                    select map_id
                    from   cmap_map
                    where  map_set_id=?
                    and    upper(map_name)=?
		      ];
	    my $map_id;
	    if (my $scalarref = 
		$self->get_cached_results($sql.$map_set_id.(uc $map_name))){
		$map_id=$$scalarref;
	    }
	    else{
		$map_id = $db->selectrow_array($sql, {},
					       ( $map_set_id, uc $map_name )
					       );
		$self->store_cached_results($sql.$map_set_id.(uc $map_name),
					\$map_id);
	    }
            push @map_ids, $map_id if $map_id;
        }
        @slot_map_ids = @map_ids if @map_ids;
    }
    else {
        for my $map_aid ( @map_aids ) {
            push @slot_map_ids, $self->acc_id_to_internal_id(
                table      => 'cmap_map', 
                acc_id     => $map_aid,
            );
        }
    }

    return $self->error(
        "Cannot convert accession IDs to internal IDs (slot $this_slot_no)"
    ) unless $map_set_id || @slot_map_ids;

    #
    # If looking at just one map, we can restrict by feature names,
    # so look to see if either the start or stop positions look like
    # non-numbers and convert to their positions if so.
    #
    if ( scalar @slot_map_ids == 1 ) {
        for ( $map_start, $map_stop ) {
            next if !defined $_ || ( defined $_ && $_ =~ $RE{'num'}{'real'} );
            $_ = $self->feature_name_to_position( 
                feature_name => $_,
                map_id       => $slot_map_ids[0],
            ) || 0;
        }

        if ( 
            defined $map_start && 
            defined $map_stop  &&
            $map_start > $map_stop
        ) {
            ( $map_start, $map_stop ) = ( $map_stop, $map_start );
        }
    }
    else {
        $map_start = undef;
        $map_stop  = undef;
    }

    #
    # Figure out the reference map(s).
    #
    my ( $ref_map_id, $ref_map_start, $ref_map_stop, $ref_maps, 
        $ref_pos_restrict );
    if ( defined $ref_slot_no ) {
        #$ref_maps = $db->selectall_arrayref(
        #    q[
        #        select map_id, start_position, stop_position
        #        from   cmap_map_cache
        #        where  pid=?
        #        and    slot_no=?
        #    ],
        #    { Columns => {} },
        #    ( $pid, $ref_slot_no )
        #);
	
	foreach my $map (@{$self->slot_info->{$ref_slot_no}}){
	    my %temp_hash=('map_id'=>$map->[0], 
			   'start_position'=>$map->[1], 
			   'stop_position'=>$map->[2],
			   );
	    push @{$ref_maps}, \%temp_hash;
	}
        return $self->error('No ref maps') unless @$ref_maps;

        #
        # If there's just one reference map, take note of the 
        # map's ID and start/stop positions.
        #
        if ( scalar @$ref_maps == 1 ) {
            $ref_map_id    = $ref_maps->[0]->{'map_id'};
            $ref_map_start = $ref_maps->[0]->{'start_position'};
            $ref_map_stop  = $ref_maps->[0]->{'stop_position'};

            my ($start, $stop) = $db->selectrow_array(
                q[
                    select start_position, stop_position
                    from   cmap_map
                    where  map_id=?
                ],
                {}, 
                ( $ref_map_id )
            );

            unless ( $start == $ref_map_start && $stop == $ref_map_stop ) {
                $ref_pos_restrict = qq[
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
            }
        }
    }

    #
    # Gather necessary info on all the maps in this slot.
    #
    my @maps = ();
    if ( @slot_map_ids ) { # user selected individual maps
	my $sql=q[
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
                           ms.map_type_accession as map_type_aid,
                           ms.map_units,
                           ms.is_relational_map,
                           s.species_id,
                           s.common_name as species_name
                    from   cmap_map map,
                           cmap_map_set ms,
                           cmap_species s
                    where  map.map_id in (].join(',', @slot_map_ids).q[)
                    and    map.map_set_id=ms.map_set_id
                    and    ms.species_id=s.species_id
		  ];
        my $tempMap;
	unless ($tempMap=$self->get_cached_results($sql)){
	    $tempMap=  $db->selectall_arrayref($sql,                
					       { Columns => {} }
					       );

	    foreach my $row (@{$tempMap}){
		$row->{'default_shape'}=
		    $self->map_type_data($row->{'map_type_aid'},'shape');
		$row->{'default_color'}=
		    $self->map_type_data($row->{'map_type_aid'},'color');
		$row->{'default_width'}=
		    $self->map_type_data($row->{'map_type_aid'},'width');
		$row->{'map_type'}=
		    $self->map_type_data($row->{'map_type_aid'},'map_type');
	    }
	    $self->store_cached_results($sql,$tempMap);
	}
	push @maps, @{$tempMap};
    }
    else { # there must be multiple maps in this slot
        if ( @{ $ref_maps || [] } ) {
            if ( $ref_map_id ) { # just one reference map, use ref_map_id
		my $sql_str=$sql->map_data_map_ids_by_single_reference_map(
                        evidence_type_aids => $evidence_type_aids,
			);
		my $temp_array;
		unless($temp_array=$self->get_cached_results
		       (
			$sql_str.$ref_map_id. $ref_map_start. $ref_map_stop. 
			$ref_map_start. $ref_map_stop. 
			$map_set_id. $ref_map_id)){
		    $temp_array=$db->selectall_arrayref
			(
			 $sql_str,
			 { Columns => {} },
			 ( $ref_map_id, $ref_map_start, $ref_map_stop, 
			   $ref_map_start, $ref_map_stop, 
			   $map_set_id, $ref_map_id
			   ));
		    $self->get_cached_results
		       (
			$sql_str.$ref_map_id. $ref_map_start. $ref_map_stop. 
			$ref_map_start. $ref_map_stop. 
			$map_set_id. $ref_map_id,$temp_array);
		    
		}

                push @maps, @{$temp_array};
            }
            else { # many reference maps, use map_cache
		my $slot_sql = " and f1.map_id in ('".
		    join("','", 
			 map{$_->[0]} @{$self->slot_info->{$ref_slot_no}}).
		    "')";
		my $sql_str= q[
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
                                 ms.map_type_accession as map_type_aid,
                                 ms.map_units,
                                 ms.is_relational_map,
                                 s.species_id,
                                 s.common_name as species_name
                        from     cmap_map map,
                                 cmap_feature f1, 
                                 cmap_feature f2, 
                                 cmap_map_set ms,
                                 cmap_species s,
                                 cmap_correspondence_lookup cl,
                                 cmap_feature_correspondence fc
                        where    f1.feature_id=cl.feature_id1
                        and      cl.feature_correspondence_id=
                                 fc.feature_correspondence_id
                        and      fc.is_enabled=1
                        and      cl.feature_id2=f2.feature_id
                        and      f2.map_id=map.map_id
                        and      map.map_set_id=?
                        and      map.map_set_id=ms.map_set_id
                        and      ms.species_id=s.species_id
		        $slot_sql
			       ];
		my $tempMap;
		unless($tempMap=$self->get_cached_results($sql_str.$map_set_id)){
		    $tempMap=$db->selectall_arrayref(
						     $sql_str,
						     { Columns => {} },
						     ( $map_set_id )
						     );
		    foreach my $row (@{$tempMap}){
			$row->{'default_shape'}=
			    $self->map_type_data($row->{'map_type_accession'},'shape');
			$row->{'default_color'}=
			    $self->map_type_data($row->{'map_type_accession'},'color');
			$row->{'default_width'}=
			    $self->map_type_data($row->{'map_type_accession'},'width');
			$row->{'map_type'}=
			    $self->map_type_data($row->{'map_type_accession'},'map_type');
		    }
		    $self->get_cached_results($sql_str.$map_set_id,$tempMap);
		}
        	 push @maps, @{$tempMap};
            }
        }
        else { # no reference maps, just get all the maps in this set
	    my $sql_str=q[
                        select   map.map_id,
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
                                 ms.map_type_accession as map_type_aid,
                                 ms.map_units,
                                 ms.is_relational_map,
                                 s.species_id,
                                 s.common_name as species_name
                        from     cmap_map map,
                                 cmap_map_set ms,
                                 cmap_species s
                        where    map.map_set_id=?
                        and      map.map_set_id=ms.map_set_id
                        and      ms.species_id=s.species_id
			  ];
            my $tempMap;
	    unless($tempMap=$self->get_cached_results($sql_str.$map_set_id)){
		$tempMap= $db->selectall_arrayref(
						  $sql_str,
						  { Columns => {} },
						  ( $map_set_id )
						  ); 
		$self->get_cached_results($sql_str.$map_set_id,$tempMap);
	    }
            push @maps, @{$tempMap};
        }
    }

    #
    # Store all the map types
    #
    if ( scalar @maps == 1 ) {
        $map_start = $maps[0]{'start_position'} unless defined $map_start; 
        $map_stop  = $maps[0]{'stop_position'}  unless defined $map_stop;
	$map_type_aids->{$maps[0]{'map_type_aid'}}=1;
    }
    else {
        for ( @maps ) {
	    $map_type_aids->{$_->{'map_type_aid'}}=1;
        }
    }

    
    # 
    # More than one map in the slot?  All are compressed.
    # 
    my $return;
    if (  scalar(@maps)==1 ) { # just one map in this slot
        
       #
        # Register the feature types on the maps in this slot.
        #
        my $ft_sql = qq[
            select   distinct
                     f.feature_type_accession as feature_type_aid
            from     cmap_feature f
            where    
        ];
	$ft_sql .= " f.map_id in ('".
	    join("','", map{$_->[0]} @{$self->slot_info->{$this_slot_no}}).
	    "')";
        if ( @$feature_type_aids ) {
            $ft_sql .= "and f.feature_type_accession in ('".
                join( "','", @$feature_type_aids ).
            "')";
        }

	my $ft;
	unless($ft=$self->get_cached_results($ft_sql)){
	    $ft = $db->selectall_hashref(
					    $ft_sql, 'feature_type_aid', {}, (  )
					    );
	    foreach my $rowKey (keys %{$ft}){
		$ft->{$rowKey}->{'feature_type'}=
		    $self->feature_type_data
		    (
		     $ft->{$rowKey}->{'feature_type_aid'},'feature_type'
		     );
		$ft->{$rowKey}->{'shape'}=
		    $self->feature_type_data
		    (
		     $ft->{$rowKey}->{'feature_type_aid'},'shape'
		     ); 
		$ft->{$rowKey}->{'color'}=
		    $self->feature_type_data
		    (
		     $ft->{$rowKey}->{'feature_type_aid'},'color'
		     );
	    }
	    $self->store_cached_results($ft_sql,$ft)
	}
        $feature_types_seen->{ $_ } = $ft->{ $_ } for keys %$ft;

        #
        # Figure out how many features are on each map.
        #
        my %count_lookup;
        my $f_count_sql = qq[
            select   count(f.feature_id) as no_features, f.map_id
            from     cmap_feature f
            where    
        ];

	$f_count_sql .= " f.map_id in ('".
	    join("','", map{$_->[0]} @{$self->slot_info->{$ref_slot_no}}).
	    "')";
	$f_count_sql .=" group by f.map_id";
	my $f_counts;
	unless($f_counts=$self->get_cached_results($f_count_sql)){
	    $f_counts = $db->selectall_arrayref(
						   $f_count_sql, { Columns => {} }, (  )
						   );
	    $self->get_cached_results($f_count_sql,$f_counts);
	}

        for my $f ( @$f_counts ) {
            $count_lookup{ $f->{'map_id'} } = $f->{'no_features'};
        }

	for my $map (@maps){
	    $map->{'start_position'} = $map_start;
	    $map->{'stop_position'}  = $map_stop;
        #if ( $map->{'no_features'} <= $max_no_features ) {
            my $where   = @$feature_type_aids
                ? "and f.feature_type_accession in ('".join("','",@$feature_type_aids)."')"
                : ''
            ;
            ###
	    my $sql_base_top=qq[
                    select   f.feature_id,
                             f.accession_id,
                             f.map_id,
                             f.feature_name,
                             f.is_landmark,
                             f.start_position,
                             f.stop_position,
                             f.feature_type_accession as feature_type_aid,
                             map.accession_id as map_aid,
                             ms.map_units
                    from     cmap_feature f,
                             cmap_map map,
                             cmap_map_set ms
				];
	    my $sql_base_bottom=qq[
                    where    f.map_id=$maps[0]{'map_id'}
				   ];

	    if (defined($map_start) and defined($map_start)){
		$sql_base_bottom.=
		    qq[
		       and      (
                        ( f.start_position>=$map_start and 
                          f.start_position<=$map_stop )
                        or   (
                            f.stop_position is not null and
                            f.start_position<=$map_start and
                            f.stop_position>=$map_stop
                        )
				 )
		       ];
	    }
	    $sql_base_bottom.=
		qq[
                    $where
                    and      f.map_id=map.map_id
                    and      map.map_set_id=ms.map_set_id
			   ];
	    my $corr_free_sql=$sql_base_top.$sql_base_bottom;
	    if (@$corr_only_feature_type_aids){
		$corr_free_sql.="and f.feature_type_accession not in ('".
		join("','",@$corr_only_feature_type_aids).
		"')";
	    }
	    my $sql_str=$corr_free_sql;
	    if(@$corr_only_feature_type_aids and 
	       ($self->slot_info->{$this_slot_no+1}
		||
		$self->slot_info->{$this_slot_no-1})){
		my $map_id_string .= " and f2.map_id in (".
		    join("", 
			 ($self->slot_info->{$this_slot_no+1}? 
			  map{$_->[0]} @{$self->slot_info->{$this_slot_no+1}}:
			  ()
			  ),
			 ($self->slot_info->{$this_slot_no-1}? 
			  map{$_->[0]} @{$self->slot_info->{$this_slot_no-1}}:
			  ()
			  )
			 ).
			 ")";
		my $with_corr_sql=
		    $sql_base_top.
		    q[,
		      cmap_feature f2,
		      cmap_correspondence_lookup cl
		      ].
		      $sql_base_bottom.
		      q[
			and cl.feature_id1=f.feature_id
			and cl.feature_id2=f2.feature_id];
		$with_corr_sql.=" and f.feature_type_accession in ('".
		    join("','",@$corr_only_feature_type_aids).
		    "')".
		    $map_id_string;
		$sql_str=$corr_free_sql." UNION ".$with_corr_sql;
	    }

	    unless($map->{'features'}=$self->get_cached_results($sql_str.$maps[0]{'map_id'})){

		$map->{'features'} = $db->selectall_hashref
		    (
		     $sql_str,
		     'feature_id', {}, ( )
		     );  
		foreach my $rowKey (keys %{$map->{'features'}}){
		    $map->{'features'}->{$rowKey}->{'feature_type'}=
			$self->feature_type_data
			(
			 $map->{'features'}->{$rowKey}->{'feature_type_aid'},'feature_type'
			 );
		    $map->{'features'}->{$rowKey}->{'default_rank'}=
			$self->feature_type_data
			(
			 $map->{'features'}->{$rowKey}->{'feature_type_aid'},'default_rank'
			 ); 
		    $map->{'features'}->{$rowKey}->{'shape'}=
			$self->feature_type_data
			(
			 $map->{'features'}->{$rowKey}->{'feature_type_aid'},'shape'
			 );
		    $map->{'features'}->{$rowKey}->{'color'}=
			$self->feature_type_data
			(
			 $map->{'features'}->{$rowKey}->{'feature_type_aid'},'color'
			 );
		    $map->{'features'}->{$rowKey}->{'drawing_lane'}=
			$self->feature_type_data
			(
			 $map->{'features'}->{$rowKey}->{'feature_type_aid'},'drawing_lane'
			 );
		    $map->{'features'}->{$rowKey}->{'drawing_priority'}=
			$self->feature_type_data
			(
			 $map->{'features'}->{$rowKey}->{'feature_type_aid'},'drawing_priority'
			 );
		}
		$self->store_cached_results($sql_str.$maps[0]{'map_id'},$map->{'features'});
            }
        
	    ###set $feature_correspondences and$correspondence_evidence
	    if (defined $ref_slot_no){
		$self->get_feature_correspondences
		(
		 $feature_correspondences,$correspondence_evidence,
		 'map_id',$map->{'map_id'}, $pid, $ref_slot_no,
		 $evidence_type_aids,$feature_type_aids,$map_start,$map_stop );
	    }
	    $return->{ $map->{'map_id'} } = $map;
	}
    }
    else { # more than one map in this slot
        #
        # Register the feature types on the maps in this slot.
        #
        my $ft_sql = qq[
            select   distinct
                     f.feature_type_accession as feature_type_aid
            from     cmap_feature f
            where    
        ];
	$ft_sql .= " f.map_id in ('".
	    join("','", map{$_->[0]} @{$self->slot_info->{$this_slot_no}}).
	    "')";
        if ( @$feature_type_aids ) {
            $ft_sql .= "and f.feature_type_accession in ('".
                join( "','", @$feature_type_aids ).
            "')";
        }
	my $ft;
	unless($ft=$self->get_cached_results($ft_sql)){
	    $ft = $db->selectall_hashref(
					    $ft_sql, 'feature_type_aid', {}, (  )
					    );
	    foreach my $rowKey (keys %{$ft}){
		$ft->{$rowKey}->{'feature_type'}=
		    $self->feature_type_data
		    (
		     $ft->{$rowKey}->{'feature_type_aid'},'feature_type'
		     );
		$ft->{$rowKey}->{'shape'}=
		    $self->feature_type_data
		    (
		     $ft->{$rowKey}->{'feature_type_aid'},'shape'
		     ); 
		$ft->{$rowKey}->{'color'}=
		    $self->feature_type_data
		    (
		     $ft->{$rowKey}->{'feature_type_aid'},'color'
		     );
	    }
	    $self->store_cached_results($ft_sql,$ft)
	}
        $feature_types_seen->{ $_ } = $ft->{ $_ } for keys %$ft;

        #
        # Figure out how many features are on each map.
        #
        my %count_lookup;
        my $f_count_sql = qq[
            select   count(f.feature_id) as no_features, f.map_id
            from     cmap_feature f
            where    
        ];

	$f_count_sql .= " f.map_id in ('".
	    join("','", map{$_->[0]} @{$self->slot_info->{$ref_slot_no}}).
	    "')";
	$f_count_sql .=" group by f.map_id";
	my $f_counts;
	unless($f_counts=$self->get_cached_results($f_count_sql)){
	    $f_counts = $db->selectall_arrayref(
						   $f_count_sql, { Columns => {} }, (  )
						   );
	    $self->get_cached_results($f_count_sql,$f_counts);
	}

        for my $f ( @$f_counts ) {
            $count_lookup{ $f->{'map_id'} } = $f->{'no_features'};
        }

        #
        # Query for the counts of correspondences.
        #
        my $where = @$evidence_type_aids 
            ? "and ce.evidence_type_accession in ('".join( "','",@$evidence_type_aids)."')"
            : ''
        ;

        my ( $field, $value );
        if ( $map_set_id || scalar @slot_map_ids > 1 ) { 
            $field = 'map_set_id';
            $value = $map_set_id;
        }
        else {
            $field = 'map_id';
            $value = $slot_map_ids[0];
        }

        my ( $count_sql, $position_sql, @query_args );
        if ( $ref_map_id ) { # just one reference map
            my $base_sql = qq[ 
                select   %s
                         f1.map_id as map_id1, 
                         f2.map_id as map_id2
                from     cmap_feature f1,
                         cmap_feature f2,
                         cmap_map map2,
                         cmap_correspondence_lookup cl,
                         cmap_feature_correspondence fc,
                         cmap_correspondence_evidence ce
                where    f1.map_id=?
                $ref_pos_restrict
                and      f1.feature_id=cl.feature_id1
                and      cl.feature_correspondence_id=
                         fc.feature_correspondence_id
                and      fc.is_enabled=1
                and      fc.feature_correspondence_id=
                         ce.feature_correspondence_id
                $where
                and      cl.feature_id2=f2.feature_id
                and      f2.map_id=map2.map_id
                and      map2.$field=?
                group by map_id1, map_id2
            ];
            $count_sql = sprintf( $base_sql, 
                'count(distinct cl.feature_correspondence_id) as no_corr, '
            );
            $position_sql = sprintf( $base_sql,
                 'min(f1.start_position) as min_start, ' .
                 'max(f1.start_position) as max_start, '
            );
            push @query_args, $ref_map_id, $value;
        }
        elsif ( defined $ref_slot_no ) { # multiple reference maps
            my $base_sql = qq[ 
                select   %s
                         f1.map_id as map_id1, 
                         f2.map_id as map_id2
                from     cmap_feature f1,
                         cmap_feature f2,
                         cmap_map map2,
                         cmap_correspondence_lookup cl,
                         cmap_feature_correspondence fc,
                         cmap_correspondence_evidence ce
                where    f1.feature_id=cl.feature_id1
                and      cl.feature_correspondence_id=
                         fc.feature_correspondence_id
                and      fc.is_enabled=1
                and      fc.feature_correspondence_id=
                         ce.feature_correspondence_id
                $where
                and      cl.feature_id2=f2.feature_id
                and      f2.map_id=map2.map_id
                and      map2.$field=?
            ];

	    $base_sql .= " and f1.map_id in ('".
		join("','",map{$_->[0]} @{$self->slot_info->{$ref_slot_no}}).
		"')";
	    $base_sql .=" group by map_id1,map_id2";

            $count_sql = sprintf( $base_sql, 
                'count(distinct cl.feature_correspondence_id) as no_corr, '
            );
            $position_sql = sprintf( $base_sql,
                 'min(f1.start_position) as min_start, ' .
                 'max(f1.start_position) as max_start, '
            );
            push @query_args, $value;
        }

        my %map_id_lookup = map { $_->{'map_id'}, 1 } @maps;
        my %corr_lookup;
        if ( $count_sql ) {

            my ($map_corr_counts, $positions);
	    if(my $arrayref=
		   $self->get_cached_results($count_sql.$position_sql.join(".",@query_args))){
		($map_corr_counts, $positions)=@$arrayref;
	    }
	    else{
		$map_corr_counts= $db->selectall_arrayref( 
		    $count_sql, { Columns => {} }, @query_args 
       		);
		$positions = $db->selectall_hashref( 
                    $position_sql, 'map_id2', {}, @query_args 
                 );
		$self->get_cached_results($count_sql.$position_sql.join(".",@query_args),
					  [$map_corr_counts,$positions]);
	    }
            for my $count ( @$map_corr_counts ) {
                next unless $map_id_lookup{ $count->{'map_id2'} };
                my $pos = $positions->{ $count->{'map_id2'} };
		
                $map_correspondences->
                    { $this_slot_no       } 
                    { $count->{'map_id2'} }
                    { $count->{'map_id1'} }
                = {
                    map_id     => $count->{'map_id2'},
                    ref_map_id => $count->{'map_id1'},
                    no_corr    => $count->{'no_corr'},
                    min_start  => $pos->{'min_start'},
                    max_start  => $pos->{'max_start'},
                };
                $corr_lookup{ $count->{'map_id2'} } += $count->{'no_corr'};
            }
        }


        for my $map ( @maps ) {
            $map->{'no_correspondences'} = $corr_lookup{ $map->{'map_id'} };
            next if $min_correspondences && defined $ref_slot_no &&
                $map->{'no_correspondences'} < $min_correspondences;
            $map->{'no_features'}        = $count_lookup{ $map->{'map_id'} };

            ###set $feature_correspondences and$correspondence_evidence
	    if (defined $ref_slot_no){
		$self->get_feature_correspondences(
		$feature_correspondences,$correspondence_evidence,
    	        'map_id',$map->{'map_id'}, $pid, $ref_slot_no,
	        $evidence_type_aids,$feature_type_aids,$map_start,$map_stop );
	    }
	    $return->{ $map->{'map_id'} } = $map;
        }
    }
    $self->get_intraslot_correspondences(
		$intraslot_correspondences,$correspondence_evidence,
    	        $pid, $ref_slot_no,
	        $evidence_type_aids,$feature_type_aids,$map_start,$map_stop );
    
    return $return;


}

# ----------------------------------------------------
=pod

=head2 get_web_page_extras

gets the extra javascript code that needs to go on the web
    page for these features.
    
=cut
sub get_web_page_extras{

    my $self          = shift;
    my $feature_types = shift;
    my $map_type_aids = shift;
    my $extra_code    = shift;
    my $extra_form    = shift;

    my %snippet_aids;
    my %extra_form_aids;
    my $required_string;

    ###Get the feature type info
    foreach my $key (keys %{$feature_types}){
	###First get the code snippets
	$required_string=
	    $self->feature_type_data($key,'required_page_code');
	foreach my $snippet_aid (split(/\s*,\s*/ ,$required_string)){
	    $snippet_aids{$snippet_aid}=1;
	}
	###Then get the extra form stuff
	$required_string=
	    $self->feature_type_data($key,'extra_forms');
	foreach my $extra_form_aid (split(/\s*,\s*/ ,$required_string)){
	    $extra_form_aids{$extra_form_aid}=1;
	}
    }

    ###Get the map type info
    foreach my $key (keys %{$map_type_aids}){
	###First get the code snippets
	$required_string=
	    $self->map_type_data($key,'required_page_code');
	foreach my $snippet_aid (split(/\s*,\s*/ ,$required_string)){
	    $snippet_aids{$snippet_aid}=1;
	}
	###Then get the extra form stuff
	$required_string=
	    $self->map_type_data($key,'extra_forms');
	foreach my $extra_form_aid (split(/\s*,\s*/ ,$required_string)){
	    $extra_form_aids{$extra_form_aid}=1;
	}

    }


    foreach my $snippet_aid (keys(%snippet_aids)){
	$extra_code.=
	    $self->config_data('page_code')->{$snippet_aid}->{'page_code'};
    } 
    foreach my $extra_form_aid (keys(%extra_form_aids)){
	$extra_form.=
	    $self->config_data('extra_form')->{$extra_form_aid}->{'extra_form'};
    }
    return ($extra_code,$extra_form);
}	


# ----------------------------------------------------
=pod
    
=head2 get_feature_correspondences

inserts correspondence info into $feature_correspondence and 
$correspondence_evidence based on corrs from the slot
and the provided id.

=cut
sub get_feature_correspondences {
    #print S#TDERR "get_feature_correspondences\n";
    my ( $self,$feature_correspondences,$correspondence_evidence,
	 $field,$value, $pid, $slot_no,
	 $evidence_type_aids,$feature_type_aids,
	 $map_start,$map_stop ) = @_;
    my $db = $self->db;
    my $to_restriction='';

    if ( $field eq 'map_id' && defined $map_start && defined $map_stop ) {
	$to_restriction = qq[
	    and      (
		      ( f2.start_position>=$map_start and 
			f2.start_position<=$map_stop )
		      or   (
			    f2.stop_position is not null and
			    f2.start_position<=$map_start and
			    f2.stop_position>=$map_stop
			    )
		      )
			     ];
    }

    my $corr_sql = qq[
        select   f.feature_id as feature_id,
                 f2.feature_id as ref_feature_id, 
                 f2.feature_name as f2_name,
                 f2.start_position as f2_start,
                 map.map_id,
                 cl.feature_correspondence_id,
                 ce.evidence_type_accession as evidence_type_aid
        from     cmap_feature f, 
                 cmap_feature f2, 
                 cmap_map map,
                 cmap_correspondence_lookup cl,
                 cmap_feature_correspondence fc,
                 cmap_correspondence_evidence ce
        where    f.feature_id=cl.feature_id1
        and      cl.feature_correspondence_id=
                 fc.feature_correspondence_id
        and      fc.is_enabled=1
        and      fc.feature_correspondence_id=
                 ce.feature_correspondence_id
        and      cl.feature_id2=f2.feature_id
        and      f2.map_id=map.map_id
        and      map.$field=?
        $to_restriction
    ];
    
    if ($self->slot_info->{$slot_no} 
	and 
	@{$self->slot_info->{$slot_no}}){
	if (scalar(@{$self->slot_info->{$slot_no}})==1){
	    $corr_sql .= " and f.map_id = ".
	        $self->slot_info->{$slot_no}->[0][0].
		" ";
	}
	else{
	    $corr_sql .= " and f.map_id in (".
	        join("", map{$_->[0]} @{$self->slot_info->{$slot_no}}).
		")";
	}
    }

    if ( @$evidence_type_aids ) {
        $corr_sql .= "and ce.evidence_type_accession in ('".
            join( "','", @$evidence_type_aids ).
        "')";
    }

    if ( @$feature_type_aids ) {
        $corr_sql .= "and f.feature_type_accession in ('".
            join( "','", @$feature_type_aids ).
        "')";
    }
    my $ref_correspondences;
    unless ($ref_correspondences=$self->get_cached_results($corr_sql.$value)){

	$ref_correspondences = $db->selectall_arrayref(
	    $corr_sql, { Columns => {} }, ( $value )
        );
    
	foreach my $row ( @{$ref_correspondences } ) {
	    $row->{'evidence_rank'} = $self->evidence_type_data( 
	        $row->{'evidence_type_aid'}, 'rank' 
	    );
	    $row->{'line_color'} = $self->evidence_type_data( 
	        $row->{'evidence_type_aid'}, 'line_color' 
	    );
	    $row->{'evidence_type'} = $self->evidence_type_data( 
                $row->{'evidence_type_aid'}, 'evidence_type' 
            );
	}
	$self->store_cached_results($corr_sql.$value,$ref_correspondences);
    }		   
    for my $corr ( @{ $ref_correspondences } ) {
	$feature_correspondences->{
            $corr->{'feature_id'}}{ $corr->{'ref_feature_id'} }
	= $corr->{'feature_correspondence_id'};

	$feature_correspondences->{
	    $corr->{'ref_feature_id'} }{ $corr->{'feature_id'}}
	= $corr->{'feature_correspondence_id'};

	push @{ $correspondence_evidence->{
	    $corr->{'feature_correspondence_id'}
	} }, {
                evidence_type_aid => $corr->{'evidence_type_aid'},
                evidence_type     => $corr->{'evidence_type'},
                evidence_rank     => $corr->{'evidence_rank'},
                line_color        => $corr->{'line_color'},
            };
        }

}

# ----------------------------------------------------
=pod

=head2 get_intraslot_correspondences

inserts correspondence info into $intraslot_correspondence and 
$correspondence_evidence based on corrs from the slot
and the provided id.

=cut
sub get_intraslot_correspondences {
    my ( $self,$intraslot_correspondences,$correspondence_evidence,
	 $pid, $slot_no,
	 $evidence_type_aids,$feature_type_aids,
	 $map_start,$map_stop ) = @_;
    my $db = $self->db;
    my $to_restriction='';

    $slot_no=0 unless $slot_no;
    if ( defined $map_start && defined $map_stop ) {
	$to_restriction = qq[
	    and      (
		      ( f2.start_position>=$map_start and 
			f2.start_position<=$map_stop )
		      or   (
			    f2.stop_position is not null and
			    f2.start_position<=$map_start and
			    f2.stop_position>=$map_stop
			    )
		      )
			     ];
    }

    my $corr_sql = qq[
        select   f.feature_id as feature_id,
                 f2.feature_id as ref_feature_id, 
                 f2.feature_name as f2_name,
                 f2.start_position as f2_start,
                 f2.map_id,
                 cl.feature_correspondence_id,
                 ce.evidence_type_accession as evidence_type_aid
        from     cmap_feature f, 
                 cmap_feature f2,
                 cmap_correspondence_lookup cl,
                 cmap_feature_correspondence fc,
                 cmap_correspondence_evidence ce
        where    f.feature_id=cl.feature_id1
        and      cl.feature_correspondence_id=
                 fc.feature_correspondence_id
        and      fc.is_enabled=1
        and      fc.feature_correspondence_id=
                 ce.feature_correspondence_id
        and      cl.feature_id2=f2.feature_id
        $to_restriction
    ];

    $corr_sql .= "and f.map_id in ('".
	join("','", map{$_->[0]} @{$self->slot_info->{$slot_no}}).
	"')";
    $corr_sql .= "and f2.map_id in ('".
	join("','", map{$_->[0]} @{$self->slot_info->{$slot_no}}).
	"')";


    if ( @$evidence_type_aids ) {
        $corr_sql .= "and ce.evidence_type_accession in ('".
            join( "','", @$evidence_type_aids ).
        "')";
    }

    if ( @$feature_type_aids ) {
        $corr_sql .= "and f.feature_type_accession in ('".
            join( "','", @$feature_type_aids ).
        "')";
    }

    my $ref_correspondences;
    unless ($ref_correspondences=$self->get_cached_results($corr_sql)){
	$ref_correspondences= $db->selectall_arrayref
	    (
	     $corr_sql, { Columns => {} }, (  )
	     );
    
	foreach my $row ( @{$ref_correspondences } ) {
	    $row->{'evidence_rank'} = $self->evidence_type_data( 
								 $row->{'evidence_type_aid'}, 'rank' 
								 );
	    $row->{'line_color'} = $self->evidence_type_data( 
							      $row->{'evidence_type_aid'}, 'line_color' 
							      );
	    $row->{'evidence_type'} = $self->evidence_type_data( 
								 $row->{'evidence_type_aid'}, 'evidence_type' 
								 );
}
	    $self->store_cached_results($corr_sql,$ref_correspondences);
	
    }
			   
    for my $corr ( @{ $ref_correspondences } ) {
	$intraslot_correspondences->{
            $corr->{'feature_id'}}{ $corr->{'ref_feature_id'} }
	= $corr->{'feature_correspondence_id'};

	$intraslot_correspondences->{
	    $corr->{'ref_feature_id'} }{ $corr->{'feature_id'}}
	= $corr->{'feature_correspondence_id'};

	push @{ $correspondence_evidence->{
	    $corr->{'feature_correspondence_id'}
	} }, {
                evidence_type_aid => $corr->{'evidence_type_aid'},
                evidence_type     => $corr->{'evidence_type'},
                evidence_rank     => $corr->{'evidence_rank'},
                line_color        => $corr->{'line_color'},
            };
    }
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
    my $map_type_aid     = $args{'map_type_aid'}     ||     '';
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
    # And map types.
    #
    my $map_types = $db->selectall_arrayref( 
        q[
            select   distinct ms.map_type_accession as map_type_aid
            from     cmap_map_set ms
            where    ms.can_be_reference_map=1
            and      ms.is_enabled=1
        ],
        { Columns => {} } 
    );
    foreach my $row ( @{$map_types} ) {
        $row->{'map_type'} =
            $self->map_type_data( $row->{'map_type_aid'}, 'map_type' );
        $row->{'display_order'} =
            $self->map_type_data( $row->{'map_type_aid'}, 'display_order' );
    }

    $map_types =
        sort_selectall_arrayref( $map_types, 'display_order', 'map_type' );

    unless ( $args{'show_matrix'} ) {
        return {
            species_aid => $species_aid,
            map_types   => $map_types,
            species     => $species,
        };
    }

    #
    # Make sure that species_aid is set if map_set_id is.
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
    # Make sure that map_type_aid is set if map_set_id is.
    #
    if ( $map_set_aid && !$map_type_aid ) {
        $map_type_aid = $db->selectrow_array(
            q[
                select ms.map_type_accession as map_type_aid
                from   cmap_map_set ms
                where  ms.accession_id=?
            ],
            {},
            ( $map_set_aid )
        );
    }

    #
    # Get all the map sets for a given species and/or map type.
    #
    my ( $maps, $map_sets );
    if ( $species_aid || $map_type_aid ) {
        my $sql = q[
            select   s.display_order,
                     s.common_name as species_name, 
                     ms.accession_id as map_set_aid, 
                     ms.display_order,
                     ms.short_name as map_set_name
            from     cmap_map_set ms,
                     cmap_species s
            where    ms.can_be_reference_map=1
            and      ms.is_enabled=1
            and      ms.species_id=s.species_id
        ];

        $sql .= "and s.accession_id='$species_aid' "   if $species_aid;
        $sql .= "and ms.map_type_accession='$map_type_aid' " if $map_type_aid;
       
        $map_sets = $db->selectall_arrayref( $sql, { Columns => {} } );

        foreach my $row ( @{$map_sets} ) {
            $row->{'default_display_order'} = $self->map_type_data( 
                $row->{'map_type_accession'}, 'display_order' 
            );

            $row->{'map_type'} = $self->map_type_data( 
                $row->{'map_type_accession'}, 'map_type' 
            );
        }

        $map_sets = sort_selectall_arrayref( $map_sets, 
            'default_display_order', 'map_type', 'display_order', 
            'common_name', 'display_order', 'published_on', 'short_name' 
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
        ];
        $map_sql .= "and ms.map_type_accession='$map_type_aid' " 
                    if $map_type_aid;
        $map_sql .= "and s.accession_id='$species_aid' "   if $species_aid;
        $map_sql .= "and ms.accession_id='$map_set_aid' "  if $map_set_aid;
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
                     ms.map_type_accession as map_type_aid, 
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

        my $tempMapSet = $db->selectall_arrayref( 
            $map_set_sql, { Columns => {} } 
        );

        foreach my $row ( @$tempMapSet ) {
            $row->{'map_type_display_order'} = $self->map_type_data( 
                $row->{'map_type_accession'}, 'display_order' 
            );

            $row->{'map_type'} = $self->map_type_data( 
                $row->{'map_type_accession'}, 'map_type' 
            );
        }

        @reference_map_sets = @$tempMapSet;
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
                         ms.map_type_accession as map_type_aid, 
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
                "and s.accession_id='$species_aid' "   if $species_aid;

            $map_set_sql .= 
                "and ms.map_type_accession='$map_type_aid' " if $map_type_aid;

            $map_set_sql .= 
                "and ms.accession_id='$map_set_aid' "  if $map_set_aid;
        }
        else {
            $map_set_sql = q[
                select   ms.map_set_id, 
                         ms.accession_id as map_set_aid,
                         ms.short_name as map_set_name,
                         ms.display_order as map_set_display_order, 
                         ms.map_type_accession as map_type_aid, 
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
                "and s.accession_id='$species_aid' "   if $species_aid;

            $map_set_sql .= 
                "and ms.map_type_accession='$map_type_aid' " if $map_type_aid;

            $map_set_sql .= 
                "and ms.accession_id='$map_set_aid' "  if $map_set_aid;

	}

        my $tempMapSet =  
            $db->selectall_arrayref( $map_set_sql, { Columns => {} } );
	
        foreach my $row ( @{$tempMapSet} ) {
            $row->{'map_type_display_order'} = $self->map_type_data( 
		$row->{'map_type_accession'}, 'display_order' 
            );

            $row->{'map_type'} = $self->map_type_data( 
                $row->{'map_type_accession'}, 'map_type' 
            );
        }

        @reference_map_sets = @{ 
            sort_selectall_arrayref($tempMapSet,
                'map_type_display_order', 'map_type', 'species_display_order', 
                'species_name', 'map_set_display_order', 'map_set_name',
                'published_on desc', 'map_set_name'
            )
        };
    }

    #
    # If there's only only set, then pretend that the user selected 
    # this one and expand the relationships to the map level.
    #
#    if ( $map_set_aid eq '' && scalar @reference_map_sets == 1 ) {
#        $map_set_aid = $reference_map_sets[0]->{'map_set_aid'};
#    }

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
    my $data = $db->selectall_arrayref( $select_sql, { Columns => {} } );

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
    my $tempMapSet;
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
                     ms.map_type_accession as map_type_aid
            from     cmap_map map,
                     cmap_map_set ms,
                     cmap_species s
            where    map.map_set_id=ms.map_set_id
            and      ms.is_enabled=1
            and      ms.accession_id='$link_map_set_aid'
            and      ms.species_id=s.species_id
            order by map.display_order, map.map_name
        ];
        $tempMapSet=$db->selectall_arrayref( $link_map_set_sql, { Columns => {} } );
        foreach my $row (@{$tempMapSet}){
            $row->{'map_type'}=
        	$self->map_type_data($row->{'map_type_accession'},'map_type');
        }
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
                     ms.map_type_accession as map_type_aid
            from     cmap_map_set ms,
                     cmap_species s
            where    ms.is_enabled=1
            and      ms.species_id=s.species_id
        ];

        $link_map_set_sql .= 
            "and ms.accession_id='$link_map_set_aid' " if $link_map_set_aid;

        $tempMapSet=$db->selectall_arrayref( $link_map_set_sql, { Columns => {} } );
        foreach my $row (@{$tempMapSet}){
            $row->{'map_type'}=
        	$self->map_type_data($row->{'map_type_accession'},'map_type');
            $row->{'map_type_display_order'}=
        	$self->map_type_data($row->{'map_type_accession'},'display_order');
        }
        $tempMapSet=sort_selectall_arrayref($tempMapSet, 'map_type_display_order',
        				 'map_type',
        				 'species_display_order', 
        				 'species_name', 
        				 'map_set_display_order',
        				 'published_on',
        				 'map_set_name');
    }

    my @all_map_sets = @{ 
        $db->selectall_arrayref( $link_map_set_sql, { Columns => {} } )
    };

    #
    # Figure out the number by type and species.
    #
    my ( %no_by_type, %no_by_type_and_species );
    for my $map_set ( @all_map_sets ) {
        my $map_type_aid = $map_set->{'map_type_accession'};
        my $species_aid = $map_set->{'species_aid'};

        $no_by_type{ $map_type_aid }++;
        $no_by_type_and_species{ $map_type_aid }{ $species_aid }++;
    }

    #
    # The top row of the table is a listing of all the map sets.
    #
    my $top_row = {
        no_by_type             => \%no_by_type,
        no_by_type_and_species => \%no_by_type_and_species,
        map_sets               => \@all_map_sets
    };

    #
    # Fill in the matrix with the reference set and all it's correspondences.
    # Herein lies madness.
    #
    my ( @matrix, %no_ref_by_species_and_type, %no_ref_by_type );
    for my $map_set ( @reference_map_sets ) {
        my $r_map_aid       = $map_set->{'map_aid'} || '';
        my $r_map_set_aid   = $map_set->{'map_set_aid'};
        my $r_map_type_aid  = $map_set->{'map_type_aid'};
        my $r_species_aid   = $map_set->{'species_aid'};
        my $reference_aid   = 
            $map_name && $map_set_aid ? $r_map_aid     : 
            $map_name                 ? $r_map_set_aid : 
            $r_map_aid || $r_map_set_aid;

        $no_ref_by_type{ $r_map_type_aid }++;
        $no_ref_by_species_and_type{ $r_species_aid }{ $r_map_type_aid }++;

        for my $comp_map_set ( @all_map_sets ) {
            my $comp_map_set_aid = $comp_map_set->{'map_set_aid'};
            my $comp_map_aid     = $comp_map_set->{'map_aid'} || '';
            my $comparative_aid  = $comp_map_aid || $comp_map_set_aid;
            my $correspondences  = 
                ( $r_map_aid && $comp_map_aid && $r_map_aid eq $comp_map_aid )
                ? 'N/A' :
                $lookup{ $reference_aid }{ $comparative_aid } || 0
            ;

            push @{ $map_set->{'correspondences'} }, {
                map_set_aid => $comp_map_set_aid, 
                map_aid     => $comp_map_aid,
                number      => $correspondences,
            };
        }

        push @matrix, $map_set;
    }

    my $matrix_data            =  {
        data                   => \@matrix,
        no_by_type             => \%no_ref_by_type,
        no_by_species_and_type => \%no_ref_by_species_and_type,
    };

    return {
        top_row      => $top_row,
        species_aid  => $species_aid,
        map_set_aid  => $map_set_aid,
        map_type_aid => $map_type_aid,
        map_name     => $map_name,
        matrix       => $matrix_data,
        data         => $data,
        species      => $species,
        map_sets     => $map_sets,
        map_types    => $map_types,
        maps         => $maps,
    };
}

# ----------------------------------------------------
=pod

=head2 cmap_form_data

Returns the data for the main comparative map HTML form.

=cut

sub cmap_form_data {
    #p#rint S#TDERR "cmap_form_data\n";
    my ( $self, %args )        = @_;
    my $slots                  = $args{'slots'} or return;
    my $min_correspondences    = $args{'min_correspondences'}    ||  0;
    my $feature_type_aids      = $args{'include_feature_types'}  || [];
    my $evidence_type_aids     = $args{'include_evidence_types'} || [];
    my $ref_species_aid        = $args{'ref_species_aid'}        || '';
    my $ref_map                = $slots->{ 0 };
    my $ref_map_set_aid        = $ref_map->{'map_set_aid'}       ||  0;
    my $ref_map_start          = $ref_map->{'start'};
    my $ref_map_stop           = $ref_map->{'stop'};
    my $db                     = $self->db  or return;
    my $sql                    = $self->sql or return;
    my $pid                    = $$;

    my @ref_maps;

    if ($self->slot_info){
	foreach my $map (@{$self->slot_info->{0}}){
	    my %temp_hash=('map_id'=>$map->[0], 
			   'start_position'=>$map->[1], 
			   'stop_position'=>$map->[2],
			   );
	    push @ref_maps, \%temp_hash;
	}
    }
   
    if ( scalar @ref_maps > 1 ) {
        $ref_map_start = undef;
        $ref_map_stop  = undef;
    }
    my $sql_str;
    if ( $ref_map_set_aid && !$ref_species_aid ) {
        $sql_str=q[
                select s.accession_id
                from   cmap_map_set ms,
                       cmap_species s
                where  ms.accession_id=?
                and    ms.species_id=s.species_id
		      ];
	if (my $scalar_ref=$self->get_cached_results($sql_str.$ref_map_set_aid)){
	    $ref_species_aid=$$scalar_ref;
	}
	else{
	    $ref_species_aid = $db->selectrow_array(
						    $sql_str,
						    {},
						    ( $ref_map_set_aid )
						    );
	    $self->store_cached_results($sql_str.$ref_map_set_aid,\$ref_species_aid);
	}
    }
    #
    # Select all the map set that can be reference maps.
    #

   $sql_str=q[
            select   distinct s.accession_id as species_aid,
                     s.display_order,
                     s.common_name as species_common_name,
                     s.full_name as species_full_name
            from     cmap_map_set ms,
                     cmap_species s
            where    ms.is_enabled=1
            and      ms.can_be_reference_map=1
            and      ms.species_id=s.species_id
            order by s.display_order,
                     s.common_name, 
                     s.full_name
	      ];
    my $ref_species;
    my $scalar_ref;

    if($scalar_ref=$self->get_cached_results($sql_str)){
	$ref_species=$$scalar_ref;
    }
    else{
	$ref_species = $db->selectall_arrayref
	    (
	     $sql_str,
	     { Columns => {} }
	     );
	$self->store_cached_results($sql_str,\$ref_species);
    }

    if ( @$ref_species && !$ref_species_aid ) {
        $ref_species_aid = $ref_species->[0]{'species_aid'};
    }

    #
    # Select all the map set that can be reference maps.
    #
    my $ref_map_sets = [];
    if ($ref_species_aid){
        $sql_str=$sql->form_data_ref_map_sets_sql( $ref_species_aid );
	unless($ref_map_sets=$self->get_cached_results($sql_str)){
	    $ref_map_sets=$db->selectall_arrayref
		(
		 $sql_str,
		 { Columns => {} },
		 );
	    $self->store_cached_results($sql_str,$ref_map_sets);
	}
    }
    #
    # If there's only one map set, pretend it was submitted.
    #
    if ( !$ref_map_set_aid && scalar @$ref_map_sets == 1 ) {
        $ref_map_set_aid = $ref_map_sets->[0]{'accession_id'}; 
    }

    #
    # "-1" is a reserved value meaning "All."
    #
    $feature_type_aids  = [] if grep { /^-1$/ } @$feature_type_aids;
    $evidence_type_aids = [] if grep { /^-1$/ } @$evidence_type_aids;
   
    #
    # If the user selected a map set, select all the maps in it.
    #
    my ( $ref_maps, $ref_map_set_info ); 
    
    if ( $ref_map_set_aid ) {
	unless (
		(ref($ref_map->{'aid'}) eq 'ARRAY'? 
		 @{$ref_map->{'aid'}}:
		 $ref_map->{'aid'}) 
		 or $ref_map->{'map_names'}){
	    $sql_str=$sql->form_data_ref_maps_sql;	
	    unless($ref_maps=$self->get_cached_results($sql_str."$ref_map_set_aid")){
		$ref_maps = $db->selectall_arrayref
		    (
		     $sql_str,
		     { Columns => {} },
		     ( "$ref_map_set_aid" )
		     );
		$self->store_cached_results($sql_str."$ref_map_set_aid",$ref_maps);
	    }
            $self->error(
                qq[No maps exist for the ref. map set acc. id "$ref_map_set_aid"]
            ) unless @$ref_maps;
       }

        unless ( @ref_maps ) {
	    $sql_str=q[
                    select   ms.map_set_id, 
                             ms.accession_id as map_set_aid,
                             ms.map_set_name, 
                             ms.short_name,
                             ms.map_type_accession as map_type_aid, 
                             ms.species_id, 
                             ms.can_be_reference_map, 
                             ms.map_units, 
                             s.accession_id as species_aid, 
                             s.common_name as species_common_name, 
                             s.full_name as species_full_name
                    from     cmap_map_set ms, 
                             cmap_species s
                    where    ms.accession_id=?
                    and      ms.species_id=s.species_id
		       ];
	    unless($ref_map_set_info=$self->get_cached_results($sql_str.$ref_map_set_aid)){
		my $sth = $db->prepare($sql_str );
		$sth->execute( $ref_map_set_aid );
		$ref_map_set_info = $sth->fetchrow_hashref;
		$ref_map_set_info->{'attributes'} = $self->get_attributes
		    (
		     'cmap_map_set', $ref_map_set_info->{'map_set_id'}
		     );
		$ref_map_set_info->{'xrefs'} = $self->get_xrefs(
                    'cmap_map_set', $ref_map_set_info->{'map_set_id'}
								);
		$ref_map_set_info->{'map_type'} = $self->map_type_data(
                    $ref_map_set_info->{'map_type_accession'},'map_type'
                );
		$self->get_cached_results($sql_str.$ref_map_set_aid,$ref_map_set_info);
            }
	}
    }

    #
    # If there is a ref. map selected but no start and stop, find 
    # the ends of the ref. map.
    #
    if ( scalar @ref_maps == 1 ) {
        my $ref_map_begin = $ref_maps[0]{'start_position'};
        my $ref_map_end   = $ref_maps[0]{'stop_position'};
        $ref_map_start    = $ref_map_begin unless defined $ref_map_start;
        $ref_map_stop     = $ref_map_end   unless defined $ref_map_stop;
        $ref_map_start    = $ref_map_begin if $ref_map_start < $ref_map_begin;
        $ref_map_stop     = $ref_map_end   if $ref_map_stop  > $ref_map_stop;
        $slots->{ 0 }->{'start'} = $ref_map_start;
        $slots->{ 0 }->{'stop'}  = $ref_map_stop;
    }

    my @slot_nos      = sort { $a <=> $b } keys %$slots;
    my $rightmost_map = $slots->{ $slot_nos[-1] };
    my $leftmost_map  = $slots->{ $slot_nos[ 0] };
    my %feature_types;
    my ($comp_maps_right,$comp_maps_left);
    if ($self->slot_info){
	$comp_maps_right     =  $self->get_comparative_maps( 
        min_correspondences => $min_correspondences,
        feature_type_aids   => $feature_type_aids,
        evidence_type_aids  => $evidence_type_aids,
        feature_types       => \%feature_types,
        ref_slot_no         => $slot_nos[-1],
        pid                 => $pid,
        );

	$comp_maps_left      =  $slot_nos[0] == $slot_nos[-1]
        ? $comp_maps_right
        : $self->get_comparative_maps(
            min_correspondences => $min_correspondences,
            feature_type_aids   => $feature_type_aids,
            evidence_type_aids  => $evidence_type_aids,
            feature_types       => \%feature_types,
            ref_slot_no         => $slot_nos[0],
            pid                 => $pid,
        )
	;
    }

    #
    # Correspondence evidence types.
    #
    my @evidence_types = @{
	$self->fake_selectall_arrayref($self->evidence_type_data(),'evidence_type_accession as evidence_type_aid', 'evidence_type')};
    #
    # Fill out all the info we have on every map.
    #
    my $map_info = $self->fill_out_maps( $slots );

    #$db->do("delete from cmap_map_cache where pid=$pid");
    
    return {
        ref_species_aid        => $ref_species_aid,
        ref_species            => $ref_species,
        ref_map_sets           => $ref_map_sets,
        ref_map_set_aid        => $ref_map_set_aid,
        ref_maps               => $ref_maps,
        ref_map_start          => $ref_map_start,
        ref_map_stop           => $ref_map_stop,
        ref_map_set_info       => $ref_map_set_info,
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
    my $min_correspondences = $args{'min_correspondences'};
    my $feature_type_aids   = $args{'feature_type_aids'};
    my $evidence_type_aids  = $args{'evidence_type_aids'};
    my $feature_types       = $args{'feature_types'};
    my $ref_slot_no         = $args{'ref_slot_no'};
    my $pid                 = $args{'pid'};
    my $db                  = $self->db  or return;
    my $sql                 = $self->sql or return;
    return unless defined $ref_slot_no;
    #
    # Find out how many reference maps there are 
    # (and make sure there are some!).
    #
    my $ref_maps=[];
    # = $db->selectall_arrayref(
    #    q[
    #        select map_id, start_position, stop_position
    #        from   cmap_map_cache
    #        where  pid=?
    #        and    slot_no=?
    #    ],
    #    { Columns => {} },
    #    ( $pid, $ref_slot_no )
    #);
    foreach my $map (@{$self->slot_info->{$ref_slot_no}}){
	my %temp_hash=('map_id'=>$map->[0], 
		       'start_position'=>$map->[1], 
		       'stop_position'=>$map->[2],
		       );
	push @{$ref_maps}, \%temp_hash;
    }
    return $self->error('No ref maps') unless @$ref_maps;

    my ( $ref_map_id, $ref_map_start, $ref_map_stop );
    my $from_restriction = '';
    if ( scalar @$ref_maps == 1 ) {
        $ref_map_id        = $ref_maps->[0]->{'map_id'};
        $ref_map_start     = $ref_maps->[0]->{'start_position'};
        $ref_map_stop      = $ref_maps->[0]->{'stop_position'};
        my ($start, $stop);
	my $sql_str=q[
                select start_position, stop_position
                from   cmap_map
                where  map_id=?
		      ];
     
	if(my $arrayref = $self->get_cached_results($sql_str.$ref_map_id)){
	    
	    ($start, $stop)=@$arrayref ;
	}
	else{
	    ($start, $stop)= $db->selectrow_array(
 	        $sql_str,  
                {}, 
                ( $ref_map_id )
            );
	    $self->store_cached_results($sql_str.$ref_map_id,[$start, $stop]);
	}
        if ( $start == $ref_map_start && $stop == $ref_map_stop ) {
            $ref_map_start = undef;
            $ref_map_stop  = undef;
        }
        else{
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
        }
    }

    my $additional_where  = '';
    my $additional_tables = '';
    if ( @$evidence_type_aids ) {
        $additional_tables = ', cmap_correspondence_evidence ce';
        $additional_where .= "
            and fc.feature_correspondence_id=ce.feature_correspondence_id
            and ce.evidence_type_accession in ('" 
            . join( "','", @$evidence_type_aids ) . "') "; 
    }

    if ( @$feature_type_aids ) {
        $additional_where .= "and f2.feature_type_accession in ('".
            join( "','", @$feature_type_aids ).
        "') ";
    }

    my $corr_sql = qq[ 
        select   count(distinct cl.feature_correspondence_id) as no_corr, 
                 f2.map_id
        from     cmap_feature f1,
                 cmap_feature f2,
                 cmap_correspondence_lookup cl,
                 cmap_feature_correspondence fc
        $additional_tables
        where   f1.feature_id=cl.feature_id1
        $from_restriction
        and      cl.feature_correspondence_id=
                 fc.feature_correspondence_id
        and      fc.is_enabled=1
        and      cl.feature_id2=f2.feature_id
        and      f1.map_id!=f2.map_id
        $additional_where
    ];

    $corr_sql .= " and f1.map_id in ('".
	join("','", map{$_->[0]} @{$self->slot_info->{$ref_slot_no}}).
	"')";
    $corr_sql .=" group by f2.map_id";
    my $feature_correspondences;
    unless($feature_correspondences=$self->get_cached_results($corr_sql)){
	$feature_correspondences = $db->selectall_arrayref(
        $corr_sql,
        { Columns => {} },
        ( )
							   );
	$self->store_cached_results($corr_sql,$feature_correspondences);
    }
    
    my %map_sets;     # the map set info and any maps
    for my $fc ( @$feature_correspondences ) {
        my $sth = $db->prepare(
            q[
                select s.common_name as species_name,
                       s.display_order as species_display_order,
                       ms.map_type_accession as map_type_aid,
                       ms.accession_id as map_set_aid,
                       ms.short_name as map_set_name,
                       ms.published_on,
                       ms.display_order as ms_display_order,
                       ms.can_be_reference_map,
                       map.map_id,
                       map.accession_id as map_aid,
                       map.map_name,
                       map.display_order as map_display_order
                from   cmap_map map,
                       cmap_map_set ms,
                       cmap_species s
                where  map.map_id=?
                and    map.map_set_id=ms.map_set_id
                and    ms.species_id=s.species_id
            ]
        );
        $sth->execute( $fc->{'map_id'} );
        my $info            = $sth->fetchrow_hashref;
        $info->{'map_type'} = 
            $self->map_type_data($info->{'map_type_accession'},'map_type');
        $info->{'map_type_display_order'} = 
            $self->map_type_data($info->{'map_type_accession'},'display_order');
        $info->{'published_on'} = parsedate( $info->{'published_on'} );

        unless( $map_sets{ $info->{'map_set_aid'} } ){
            $map_sets{ $info->{'map_set_aid'} } = $info;
        }

        $map_sets{ $info->{'map_set_aid'} }{'maps'}{ $info->{'map_aid'} } = {
            map_name             => $info->{'map_name'},
            map_aid              => $info->{'map_aid'},
            display_order        => $info->{'map_display_order'},
            can_be_reference_map => $info->{'can_be_reference_map'},
            no_correspondences   => $fc->{'no_corr'},
        };
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
#sub evidence_type_aid_to_id {
#
#=pod
#
#=head2 evidence_type_aid_to_id
#
#Takes a list of evidence type accession IDs and returns their table IDs.
#
#=cut
#
#    my $self               = shift;
#    my @evidence_type_aids = @_;
#    my @evidence_type_ids  = ();
#    my $db                 = $self->db or return;
#
#    for my $aid ( @evidence_type_aids ) {
#        next unless defined $aid && $aid ne '';
#        my $id = $db->selectrow_array(
#            q[
#                select evidence_type_id
#                from   cmap_evidence_type
#                where  accession_id=?
#            ],
#            {},
#            ( "$aid" )
#        );
#        push @evidence_type_ids, $id;
#    }
#
#    return @evidence_type_ids ? [ @evidence_type_ids ] : [];
#}

# ----------------------------------------------------
sub feature_alias_detail_data {

=pod

=head2 feature_alias_detail_data

Returns the data for the feature alias detail page.

=cut

    my ( $self, %args ) = @_;
    my $feature_aid     = $args{'feature_aid'} or 
                          return $self->error('No feature acc. id');
    my $feature_alias   = $args{'feature_alias'} or 
                          return $self->error('No feature alias');

    my $db    = $self->db;
    my $sth   = $db->prepare(
        q[
            select fa.feature_alias_id,
                   fa.alias,
                   f.accession_id as feature_aid,
                   f.feature_name
            from   cmap_feature_alias fa,
                   cmap_feature f
            where  fa.alias=?
            and    fa.feature_id=f.feature_id
            and    f.accession_id=?
        ]
    );
    $sth->execute( $feature_alias, $feature_aid );
    my $alias = $sth->fetchrow_hashref or return $self->error('No alias');

    $alias->{'object_id'}  = $alias->{'feature_alias_id'};
    $alias->{'attributes'} = $self->get_attributes(
        'cmap_feature_alias', $alias->{'feature_alias_id'}
    );

    $self->get_multiple_xrefs(
        table_name => 'cmap_feature_alias', objects => [ $alias ],
    );

    return $alias;
}

# ----------------------------------------------------
#sub feature_type_aid_to_id {
#
#=pod
#
#=head2 feature_type_aid_to_id
#
#Takes a list of feature type accession IDs and returns their table IDs.
#
#=cut
#
#    my $self              = shift;
#    my @feature_type_aids = @_;
#    my @feature_type_ids  = ();
#    my $db                = $self->db or return;
#
#    for my $aid ( @feature_type_aids ) {
#        next unless defined $aid && $aid ne '';
#        my $id = $db->selectrow_array(
#            q[
#                select feature_type_id
#                from   cmap_feature_type
#                where  accession_id=?
#            ],
#            {},
#            ( "$aid" )
#        );
#        push @feature_type_ids, $id;
#    }
#
#    return @feature_type_ids ? [ @feature_type_ids ] : [];
#}

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
    my $upper_name      = uc $feature_name;
    my $sql_str=q[
            select    f.start_position
            from      cmap_feature f
            left join cmap_feature_alias fa
            on        f.feature_id=fa.feature_id
            where     f.map_id=?
            and       (
                upper(f.feature_name)=?
                or
                upper(fa.alias)=?
            )
		  ];
    my $position;
    if(my $scalarref=$self->get_cached_results($sql_str.$map_id.$upper_name)){
	$position=$$scalarref;
    }
    else{
	$position  = $db->selectrow_array
	    (
	     $sql_str,
	     {},
	     ( $map_id, $upper_name, $upper_name )
	     ) || 0;
	$self->store_cached_results($sql_str.$map_id.$upper_name,\$position);
    }
    return $position;
}

# ----------------------------------------------------
=pod

=head2 fill_out_maps

Gets the names, IDs, etc., of the maps in the slots.

=cut

sub fill_out_maps {
    #p#rint S#TDERR "fill_out_maps\n";
    my ( $self, $slots ) = @_;
    my $db               = $self->db  or return;
    my $sql              = $self->sql or return;
    my $map_sql          = $sql->fill_out_maps_by_map_sql;
    my $map_set_sql      = $sql->fill_out_maps_by_map_set_sql;
    my $map_sth          = $db->prepare( $map_sql );
    my $map_set_sth      = $db->prepare( $map_set_sql );
    my @ordered_slot_nos = sort { $a <=> $b } keys %$slots;

    my @maps;
    for my $i ( 0 .. $#ordered_slot_nos ) {
        my $slot_no = $ordered_slot_nos[ $i ];
        my $slot    = $slots->{ $slot_no };
        my $aid     = $slot->{'aid'};
        my $field   = $slot->{'field'};
        my $sth     = $field eq 'map_aid' ? $map_sth : $map_set_sth;
	my $sql_str = $field eq 'map_aid' ? $map_sql : $map_set_sql;
	my $map;
	unless($map=$self->get_cached_results($sql_str.$aid)){
	    $sth->execute( $aid );
	    $map     = $sth->fetchrow_hashref;
	    $self->store_cached_results($sql_str.$aid,$map) if ($map);
	}

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

    $feature->{'object_id'}  = $feature->{'feature_id'};
    $feature->{'attributes'} = $self->get_attributes(
        'cmap_feature', $feature->{'feature_id'}
    );
    $feature->{'aliases'}    = $db->selectall_arrayref(
        q[
            select   fa.feature_alias_id, 
                     fa.alias,
                     f.accession_id as feature_aid
            from     cmap_feature_alias fa,
                     cmap_feature f
            where    fa.feature_id=?
            and      fa.feature_id=f.feature_id
            order by alias
        ],
        { Columns => {} },
        ( $feature->{'feature_id'} )
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
                         ce.evidence_type_accession as evidence_type_aid
                from     cmap_correspondence_evidence ce
                where    ce.feature_correspondence_id=?
            ],
            { Columns => {} },
            ( $corr->{'feature_correspondence_id'} )
        );

        foreach my $row ( @{ $corr->{'evidence'} } ) {
            $row->{'rank'} = $self->evidence_type_data( 
                $row->{'evidence_type_aid'}, 'rank' 
            );
            $row->{'evidence_type'} = $self->evidence_type_data( 
                $row->{'evidence_type_aid'}, 'map_type' 
            );
        }

        $corr->{'evidence'} = sort_selectall_arrayref( 
            $corr->{'evidence'}, 'rank', 'evidence_type' 
        );

        $corr->{'aliases'} = $db->selectcol_arrayref(
            q[
                select   alias 
                from     cmap_feature_alias
                where    feature_id=?
                order by alias
            ],
            {},
            ( $corr->{'feature_id'} )
        );
    }

    $feature->{'correspondences'} = $correspondences;

    $self->get_multiple_xrefs(
        table_name => 'cmap_feature', objects => [ $feature ],
    );

    return $feature;
}

# ----------------------------------------------------
sub feature_search_data {

=pod

=head2 feature_search_data

Given a list of feature names, find any maps they occur on.

=cut

    my ( $self, %args )   = @_;
    my $db                = $self->db or return;
    my $species_aids      = $args{'species_aids'};
    my $feature_type_aids = $args{'feature_type_aids'};
    my $feature_string    = $args{'features'};
    my $page_data         = $args{'page_data'};
    my $page_size         = $args{'page_size'};
    my $page_no           = $args{'page_no'};
    my $pages_per_set     = $args{'pages_per_set'};
    my @feature_names     = (
        map { 
            s/\*/%/g;       # turn stars into SQL wildcards
            s/,//g;         # remove commas
            s/^\s+|\s+$//g; # remove leading/trailing whitespace
            s/"//g;         # remove double quotes"
            s/'/\\'/g;      # backslash escape single quotes
            $_ || ()        
        }
        parse_words( $feature_string )
    );
    my $order_by         = $args{'order_by'} || 
        'feature_name,species_name,map_set_name,map_name,start_position';
    my $search_field     = 
        $args{'search_field'} || $self->config('feature_search_field');
    $search_field        = DEFAULT->{'feature_search_field'} 
        unless VALID->{'feature_search_field'}{ $search_field };

    #
    # We'll get the feature ids first.  Use "like" in case they've
    # included wildcard searches.
    #
    my %features = ();
    for my $feature_name ( @feature_names ) {
        my $comparison = $feature_name =~ m/%/ ? 'like' : '=';
        $feature_name  = uc $feature_name;
        my $where      = '';
        if ( @$feature_type_aids ) {
            $where .= 'and ft.accession_id in ('.
                join( ', ', map { qq['$_'] } @$feature_type_aids ). 
            ') ';
        }

        if ( @$species_aids ) {
            $where .= 'and s.accession_id in ('.
                join( ', ', map { qq['$_'] } @$species_aids ). 
            ') ';
        }

        my $sql;
        if ( $search_field eq 'feature_name' ) {
            $sql = qq[
                select   f.feature_id,
                         f.accession_id as feature_aid,
                         f.feature_name, 
                         f.start_position,
                         f.stop_position,
                         f.feature_type_accession as feature_type_aid,
                         map.accession_id as map_aid,
                         map.map_name, 
                         ms.accession_id as map_set_aid, 
                         ms.short_name as map_set_name,
                         ms.can_be_reference_map,
                         s.species_id,
                         s.common_name as species_name,
                         ms.map_units
                from     cmap_feature f,
                         cmap_map map,
                         cmap_map_set ms,
                         cmap_species s
                where    upper(f.feature_name) $comparison '$feature_name'
                and      f.map_id=map.map_id
                and      map.map_set_id=ms.map_set_id
                and      ms.species_id=s.species_id
                and      ms.is_enabled=1
                $where
                UNION
                select f.feature_id,
                       f.accession_id as feature_aid,
                       f.feature_name,
                       f.start_position,
                       f.stop_position,
                       f.feature_type_accession as feature_type_aid,
                       map.accession_id as map_aid,
                       map.map_name,
                       ms.accession_id as map_set_aid,
                       ms.short_name as map_set_name,
                       ms.can_be_reference_map,
                       s.species_id,
                       s.common_name as species_name,
                       ms.map_units
                from   cmap_feature_alias fa,
                       cmap_feature f,
                       cmap_map map,
                       cmap_map_set ms,
                       cmap_species s
                where  upper(fa.alias) $comparison '$feature_name'
                and    fa.feature_id=f.feature_id
                and    f.map_id=map.map_id
                and    map.map_set_id=ms.map_set_id
                and    ms.species_id=s.species_id
                and    ms.is_enabled=1
                $where
            ];
        }
        else {
            $sql = qq[
                select   f.feature_id,
                         f.accession_id as feature_aid,
                         f.feature_name, 
                         f.start_position,
                         f.stop_position,
                         f.feature_type_accession as feature_type_aid,
                         map.accession_id as map_aid,
                         map.map_name, 
                         ms.accession_id as map_set_aid, 
                         ms.short_name as map_set_name,
                         ms.can_be_reference_map,
                         s.species_id,
                         s.common_name as species_name,
                         ms.map_units
                from     cmap_feature f,
                         cmap_map map,
                         cmap_map_set ms,
                         cmap_species s
                where    upper(f.accession_id) $comparison '$feature_name'
                and      f.map_id=map.map_id
                and      map.map_set_id=ms.map_set_id
                and      ms.species_id=s.species_id
                and      ms.is_enabled=1
                $where
            ];
        }

        my $features = $db->selectall_arrayref( $sql,  { Columns => {} } );
        foreach my $row (@{$features}){
            $row->{'feature_type'}=
        	$self->map_type_data($row->{'feature_type_aid'},'feature_type');
        }
        for my $f ( @$features ) {
            $features{ $f->{'feature_id'} } = $f;
        }
    }

    #
    # Perform sort on accumulated results.
    #
    my @found_features = ();
    if ( $order_by eq 'start_position' ) {
        @found_features = 
            map  { $_->[1] }
            sort { $a->[0] <=> $b->[0] }
            map  { [ $_->{ $order_by }, $_ ] }
            values %features
        ;
    }
    else {
        my @sort_fields = split( /,/, $order_by );
        @found_features = 
            map  { $_->[1] }
            sort { $a->[0] cmp $b->[0] }
            map  { [ join('', @{ $_ }{ @sort_fields } ), $_ ] }
            values %features
        ;
    }

    #
    # Page the data here so as to make the "IN" statement 
    # below managable.
    #
    my $pager = Data::Pageset->new( {
        total_entries    => scalar @found_features,
        entries_per_page => $page_size,
        current_page     => $page_no,
        pages_per_set    => $pages_per_set,
    } );

    if ( $page_data && @found_features ) {
        @found_features = $pager->splice( \@found_features ) 
    }

    my @feature_ids = map { $_->{'feature_id'} } @found_features;
    if ( @feature_ids ) {
        my $aliases = $db->selectall_arrayref(
            q[
                select fa.feature_id, fa.alias
                from   cmap_feature_alias fa
                where  feature_id in (].
                join(',', @feature_ids).q[)
            ],
        );

        my %aliases;
        for my $alias ( @$aliases ) {
            push @{ $aliases{ $alias->[0] } }, $alias->[1];
        }

        for my $f ( @found_features ) {
            $f->{'aliases'} = [
                sort { lc $a cmp lc $b } 
                @{ $aliases{ $f->{'feature_id'} } || [] }
            ];
        }
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
    my $feature_types = 
        $self->fake_selectall_arrayref($self->feature_type_data(),
            'feature_type_accession as feature_type_aid', 
            'feature_type');

    return {
        data          => \@found_features,
        species       => $species,
        feature_types => $feature_types,
        pager         => $pager,
    };
}

# ----------------------------------------------------
sub evidence_type_info_data {

=pod

=head2 evidence_type_info_data

Return data for a list of evidence type acc. IDs.

=cut

    my ( $self, %args ) = @_;
    
    my @return_array;

    my @evidence_types = keys(%{$self->config_data('evidence_type')});

    my %supplied_evidence_types;
    if ($args{'evidence_types'}){
        %supplied_evidence_types = map{$_=>1} @{ $args{'evidence_types'}};
    }
    foreach my $evidence_type (@evidence_types){
        if (%supplied_evidence_types){
            next unless ($supplied_evidence_types{$evidence_type});
        }
        $return_array[++$#return_array]=
        {
             'evidence_type_aid'=>$evidence_type,
             'evidence_type'=>$self->evidence_type_data($evidence_type,'evidence_type'),
             'rank'=>$self->evidence_type_data($evidence_type,'rank'),
             'line_color'=>$self->evidence_type_data($evidence_type,'line_color'),
             
         };
    }
    my $default_color = $self->config_data('connecting_line_color');

    for my $ft ( @return_array ) {
        $ft->{'line_color'} ||= $default_color;
    }
    return \@return_array;
}

# ----------------------------------------------------
sub feature_type_info_data {

=pod

=head2 feature_type_info_data

Return data for a list of feature type acc. IDs.

=cut

    my ( $self, %args ) = @_;
    
    my @return_array;

    my @feature_types = keys(%{$self->config_data('feature_type')});

    my %supplied_feature_types;
    if ($args{'feature_types'}){
        %supplied_feature_types = map{$_=>1} @{ $args{'feature_types'}};
    }
    foreach my $feature_type (@feature_types){
        if (%supplied_feature_types){
            next unless ($supplied_feature_types{$feature_type});
        }
        $return_array[++$#return_array]=
        {
             'feature_type_aid'=>$feature_type,
             'feature_type' =>$self->feature_type_data($feature_type,'feature_type'),
             'shape'=>$self->feature_type_data($feature_type,'shape'),
             'color'=>$self->feature_type_data($feature_type,'color'),
             
             };
    }


    my $default_color = $self->config_data('feature_color');

    for my $ft ( @return_array ) {
        $ft->{'color'} ||= $default_color;
    }

    @return_array = 
        sort { lc $a->{'feature_type'} cmp lc $b->{'feature_type'} }
        @return_array;
    

    return \@return_array;
}

# ----------------------------------------------------
sub map_set_viewer_data {

=pod

=head2 map_set_viewer_data

Returns the data for drawing comparative maps.

=cut

    my ( $self, %args ) = @_;
    my @map_set_aids    = @{ $args{'map_set_aids'} || [] };
    my $species_aid     = $args{'species_aid'}  || 0;
    my $map_type_aid    = $args{'map_type_aid'} || 0;
    my $db              = $self->db or return;

    for ( $species_aid, $map_type_aid ) {
        $_ = 0 if $_ == -1;
    }

    my $restriction;
    if ( @map_set_aids ) {
        $restriction .= 'and ms.accession_id in ('.
            join( ',', map { qq['$_'] } @map_set_aids ) . 
        ') ';
    }

    $restriction .= qq[and s.accession_id='$species_aid' ]   if $species_aid;
    $restriction .= qq[and ms.map_type_accession='$map_type_aid' ] if $map_type_aid;

    #
    # Map sets
    #
    my $map_set_sql = qq[
        select   ms.map_set_id, 
                 ms.accession_id as map_set_aid,
                 ms.map_set_name, 
                 ms.short_name,
                 ms.map_type_accession as map_type_aid, 
                 ms.species_id, 
                 ms.can_be_reference_map,
                 ms.map_units, 
                 s.accession_id as species_aid, 
                 s.common_name, 
                 s.full_name
        from     cmap_map_set ms,  
                 cmap_species s
        where    ms.species_id=s.species_id
        $restriction
    ]; 
    my $map_sets = $db->selectall_arrayref( $map_set_sql, { Columns => {} } );
    foreach my $row (@{$map_sets}){
            $row->{'map_type'}=
        	$self->map_type_data($row->{'map_type_accession'},'map_type');
    }
    #
    # Maps in the map sets
    #
    my $map_sql = qq[
        select   map.map_set_id,
                 map.accession_id as map_aid, 
                 map.display_order,
                 map.map_name
        from     cmap_map map,
                 cmap_map_set ms,  
                 cmap_species s
        where    map.map_set_id=ms.map_set_id
        and      ms.can_be_reference_map=1
        and      ms.species_id=s.species_id
        $restriction
        order by map.map_set_id, 
                 map.display_order, 
                 map.map_name
    ];

    my $maps = $db->selectall_arrayref( $map_sql, { Columns => {} } );
    my %map_lookup;
    for my $map ( @$maps ) {
        push @{ $map_lookup{ $map->{'map_set_id'} } }, $map;
    }

    #
    # Feature types on the maps
    #
    my $ft_sql = qq[
        select   distinct 
                 f.feature_type_accession as feature_type_aid, 
                 map.map_set_id
        from     cmap_feature f,
                 cmap_map map,
                 cmap_map_set ms, 
                 cmap_species s
        where    f.map_id=map.map_id
        and      map.map_set_id=ms.map_set_id
        and      ms.species_id=s.species_id
        $restriction
    ];
    my $feature_types = $db->selectall_arrayref( $ft_sql,  { Columns => {} } );
    foreach my $row (@{$feature_types}){
            $row->{'feature_type'}=
        	$self->feature_type_data($row->{'feature_type_aid'},'feature_type');
    }
    my %ft_lookup;
    for my $ft ( @$feature_types ) {
        push @{ $ft_lookup{ $ft->{'map_set_id'} } }, $ft;
    }

    #
    # Attributes of the map sets
    #
    my $attributes = $db->selectall_arrayref( 
        q[
            select   object_id, display_order, is_public,
                     attribute_name, attribute_value
            from     cmap_attribute
            where    table_name=?
            order by object_id, display_order, attribute_name
        ],
        { Columns => {} },
        ( 'cmap_map_set' )
    );
    my %attr_lookup;
    for my $attr ( @$attributes ) {
        push @{ $attr_lookup{ $attr->{'object_id'} } }, $attr;
    }

    #
    # Make sure we have something
    #
    if ( @map_set_aids && scalar @$map_sets == 0 ) {
        return $self->error(
            'No map sets match the following accession IDs: '.
            join(', ', @map_set_aids)
        );
    }

    #
    # Sort it all out
    #
    for my $map_set ( @$map_sets ) {
        $map_set->{'object_id'}     = $map_set->{'map_set_id'};
        $map_set->{'attributes'}    = $attr_lookup{ $map_set->{'map_set_id'} };
        $map_set->{'feature_types'} = 
            $ft_lookup{ $map_set->{'map_set_id'} }  || [];
        $map_set->{'maps'}          = 
            $map_lookup{ $map_set->{'map_set_id'} } || [];
    }

    $self->get_multiple_xrefs(
        table_name => 'cmap_map_set',
        objects    => $map_sets,
    );

    #
    # Grab species and map type info for form restriction controls.
    #
    my $species = $db->selectall_arrayref(
        q[
            select   s.accession_id as species_aid,
                     s.common_name as species_name
            from     cmap_species s
            order by s.display_order,
                     species_name
        ],
        { Columns => {} } 
    );

    my $map_types = 
        $self->fake_selectall_arrayref($self->map_type_data(),
            'map_type_accession as map_type_aid',
            'map_type');
    $map_types = sort_selectall_arrayref
        ( $map_types, 'display_order', 'map_type' );

    return {
        species   => $species,
        map_types => $map_types,
        map_sets  => $map_sets,
    };
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
    my ( $start, $stop );
    if(my $arrayref=$self->get_cached_results($sql.$id)){
	( $start, $stop ) = @$arrayref;
    }
    else{
	( $start, $stop ) = $db->selectrow_array( $sql, {}, ( $id ) )
        or $self->error(qq[Cannot determine map stop for id "$id"]);
	$self->store_cached_results($sql.$id,[$start,$stop]);
    }
    return $start > $stop ? $start : $stop;
}

# ----------------------------------------------------
sub map_start {

=pod

=head2 map_start

Given a map acc. id or a map_id, find the lowest start position.  
Optionally finds the lowest start for a given feature type. (enhancement)

=cut
;
    my ( $self, %args ) = @_;
    my $db              = $self->db  or return;
    my $sql_obj         = $self->sql or return;
    my $map_aid         = $args{'map_aid'}         || 0;
    my $map_id          = $args{'map_id'}          || 0;
    my $id              = ( $map_aid || $map_id ) or return $self->error(
        "Not enough args to map_start()"
    );
    my $sql             = $sql_obj->map_start_sql( %args ); 
    my ( $start, $stop );
    if(my $arrayref=$self->get_cached_results($sql.$id)){
	( $start, $stop ) = @$arrayref;
    }
    else{
	defined ( my $start = $db->selectrow_array( $sql, {}, ( $id ) ) )
        or return $self->error( qq[Cannot determine map start for id "$id"] );
	$self->store_cached_results($sql.$id,[$start,$stop]);
    }
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
    my $order_by               = $args{'order_by'} || 'f.start_position';
    my $comparative_map_field  = $args{'comparative_map_field'} || '';
    my $comparative_map_aid    = $args{'comparative_map_aid'}   || '';
    my $page_size              = $args{'page_size'}             || 25;
    my $max_pages              = $args{'max_pages'}             ||  0;
    my $page_no                = $args{'page_no'}               ||  1;
    my $page_data              = $args{'page_data'};
    my $db                     = $self->db  or return;
    my $sql                    = $self->sql or return;
    my $map_id                 = $self->acc_id_to_internal_id(
        table                  => 'cmap_map',
        acc_id                 => $map->{'aid'},
    ) ;
    my $map_start              = $map->{'start'};
    my $map_stop               = $map->{'stop'};

    my $feature_type_aids  = $args{'include_feature_types'};
    my $evidence_type_aids = $args{'include_evidence_types'};

    #
    # "-1" is a reserved value meaning "All."
    #
    $feature_type_aids  = [] if grep { /^-1$/ } @$feature_type_aids;
    $evidence_type_aids = [] if grep { /^-1$/ } @$evidence_type_aids;
   
    #
    # Figure out hightlighted features.
    #
    my $highlight_hash = {
        map  { s/^\s+|\s+$//g; defined $_ && $_ ne '' ? ( uc $_, 1 ) : () } 
        parse_words( $highlight )
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
                   ms.map_units
            from   cmap_map map,
                   cmap_map_set ms,
                   cmap_species s
            where  map.map_id=?
            and    map.map_set_id=ms.map_set_id
            and    ms.species_id=s.species_id
        ]
    );
    $sth->execute( $map_id );
    my $reference_map = $sth->fetchrow_hashref;

    $map_start = $reference_map->{'start_position'} 
        unless defined $map_start and $map_start =~ NUMBER_RE;
    $map_stop  = $reference_map->{'stop_position'} 
        unless defined $map_stop and $map_stop =~ NUMBER_RE;
    $reference_map->{'start'}       = $map_start;
    $reference_map->{'stop'}        = $map_stop;
    $reference_map->{'object_id'}   = $map_id;
    $reference_map->{'attributes'}  = $self->get_attributes(
        'cmap_map', $map_id
    );
    $self->get_multiple_xrefs(
        table_name => 'cmap_map', objects => [ $reference_map ]
    );

    #
    # Get the reference map features.
    #
    my $features = $db->selectall_arrayref(
        $sql->cmap_data_features_sql( 
            order_by         => $order_by,
            feature_type_aids => $feature_type_aids,
        ),
        { Columns => {} },
        ( $map_id, $map_start, $map_stop, $map_start, $map_start )
    );

    #
    # Page the data here so as to reduce the calls below
    # for the comparative map info.
    #
    my $pager = Data::Pageset->new( {
        total_entries    => scalar @$features,
        entries_per_page => $page_size,
        current_page     => $page_no,
        pages_per_set    => $max_pages,
    } );
    $features = [ $pager->splice( $features ) ] if $page_data && @$features;

    #
    # Feature aliases.
    #
    my $aliases = $db->selectall_arrayref(
        q[
            select f.feature_id,
                   fa.alias
            from   cmap_feature f,
                   cmap_feature_alias fa
            where  f.map_id=?
            and    f.feature_id=fa.feature_id
        ],
        {},
        ( $map_id )
    );

    my %alias_lookup;
    for my $alias ( @$aliases ) {
        push @{ $alias_lookup{ $alias->[0] } }, $alias->[1];
    }

    for my $feature ( @$features ) {
        $feature->{'aliases'} = $alias_lookup{ $feature->{'feature_id'} } || [];
    }

    #
    # Get all the feature types on all the maps.
    #
    my $ft_sql .= q[
        select   distinct 
                 f.feature_type_accession as feature_type_aid
        from     cmap_feature f
        where   
    ];
    $ft_sql .= " f.map_id in ('";
    
    $ft_sql.=join("','", 
		  map{
		      join("','",
			   map{$_->[0]} @{$self->slot_info->{$_}}
			   ) 
		      } 
		  keys %{$self->slot_info}
		  )."')";

    my $tempFeatureTypes=$db->selectall_arrayref( $ft_sql, { Columns => {} });
    foreach my $row (@{$tempFeatureTypes}){
        $row->{'feature_type'}=
            $self->feature_type_data($row->{'feature_type_aid'},'feature_type');
    }
    my @feature_types = 
        sort { lc $a->{'feature_type'} cmp lc $b->{'feature_type'} } 
        @{ $tempFeatureTypes };

    #
    # Correspondence evidence types.
    #
    my @evidence_types = 
        sort { lc $a->{'evidence_type'} cmp lc $b->{'evidence_type'} }
            @{$self->fake_selectall_arrayref($self->evidence_type_data(),
                'evidence_type_accession as evidence_type_aid', 
                'evidence_type')
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
                evidence_type_aids => 
                    @$evidence_type_aids ?  join(',', @$evidence_type_aids) : '',
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

        for my $val ( 
            $feature->{'feature_name'},
            @{ $feature->{'aliases'} || [] },
            $feature->{'accession_id'}
        ) {
            if ( $highlight_hash->{ uc $val } ) {
                $feature->{'highlight_color'} = 
                    $self->config('feature_highlight_bg_color');
            }
        }
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

    #
    # Delete anything from the cache.
    #
    #$db->do("delete from cmap_map_cache where pid=$pid");

    return {
        features          => $features,
        feature_types     => \@feature_types,
        evidence_types    => \@evidence_types,
        reference_map     => $reference_map,
        comparative_maps  => \@comparative_maps,
        pager             => $pager,
    };
}

# ----------------------------------------------------
sub map_type_viewer_data {

=pod

=head2 map_type_viewer_data

Returns data on map types.

=cut

    my ( $self, %args ) = @_;
    my @return_array;

    my @map_types = keys(%{$self->config_data('map_type')});

    my %supplied_map_types;
    if ($args{'map_types'}){
        %supplied_map_types = map{$_=>1} @{ $args{'map_types'}};
    }

    foreach my $map_type ( @map_types ) {
        if ( %supplied_map_types ) {
            next unless $supplied_map_types{ $map_type };
        }

        $return_array[ ++$#return_array ] = {
            map_type_aid  => $map_type,
            map_type      => $self->map_type_data( $map_type, 'map_type' ),
            shape         => $self->map_type_data( $map_type, 'shape' ),
            color         => $self->map_type_data( $map_type, 'color' ),
            width         => $self->map_type_data( $map_type, 'width' ),
            display_order => $self->map_type_data( $map_type, 'display_order' ),
            map_units     => $self->map_type_data( $map_type, 'map_units' ),
            is_relational_map =>
                $self->map_type_data( $map_type, 'is_relational_map' ),
         };
    }


    my $default_color = $self->config_data('map_color');

    for my $mt ( @return_array ) {
        $mt->{'width'}    ||= DEFAULT->{'map_width'};
        $mt->{'shape'}    ||= DEFAULT->{'map_shape'};
        $mt->{'color'}    ||= DEFAULT->{'map_color'};
    }

    @return_array = 
        sort { lc $a->{'feature_type'} cmp lc $b->{'feature_type'} }
        @return_array;
    

    return \@return_array;
}

# ----------------------------------------------------
sub species_viewer_data {

=pod

=head2 species_viewer_data

Returns data on species.

=cut

    my ( $self, %args ) = @_;
    my @species_aids    = @{ $args{'species_aids'} || [] };
    my $db              = $self->db or return;

    my $sql = q[
        select   s.species_id,
                 s.accession_id as species_aid,
                 s.common_name,
                 s.full_name,
                 s.display_order
        from     cmap_species s 
    ];

    if ( @species_aids ) {
        $sql .= 'where s.accession_id in ('.
            join( ',', map { qq['$_'] } @species_aids ) . 
        ') ';
    }

    $sql .= 'order by display_order, common_name';

    my $species = $db->selectall_arrayref( $sql, { Columns => {} } );

    my $attributes = $db->selectall_arrayref(
        q[
            select   object_id, display_order, is_public, 
                     attribute_name, attribute_value
            from     cmap_attribute
            where    table_name=?
            order by object_id, display_order, attribute_name
        ],
        { Columns => {} },
        ( 'cmap_species' )
    );

    my %attr_lookup;
    for my $attr ( @$attributes ) {
        push @{ $attr_lookup{ $attr->{'object_id'} } }, $attr;
    }

    for my $s ( @$species ) {
        $s->{'object_id'}  = $s->{'species_id'};
        $s->{'attributes'} = $attr_lookup{ $s->{'species_id'} };
    }

    $self->get_multiple_xrefs(
        table_name => 'cmap_species',
        objects    => $species,
    );

    return $species;
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

        $self->{'sql_module'} = $sql_module->new(config => $self->config); 
    }

    return $self->{'sql_module'};
}

# ----------------------------------------------------
sub view_feature_on_map {

=pod

=head2 view_feature_on_map


=cut

    my ( $self, $feature_aid )    = @_;
    my $db                        = $self->db or return;
    my ( $map_set_aid, $map_aid, $feature_name ) = $db->selectrow_array(
        q[
            select ms.accession_id,
                   map.accession_id,
                   f.feature_name
            from   cmap_map_set ms,
                   cmap_map map,
                   cmap_feature f
            where  f.accession_id=?
            and    f.map_id=map.map_id
            and    map.map_set_id=ms.map_set_id
        ],
        {},
        ( $feature_aid )
    );

    return ( $map_set_aid, $map_aid, $feature_name );
}

# ----------------------------------------------------
# store and retrieve the slot info.
sub slot_info{
    my $self  = shift;
    my $slots = shift;
    my $db    = $self->db;

    my $sql_str = 
	q[
	  select distinct m.map_id,
	         m.start_position,
	         m.stop_position
	  from   cmap_map m
	  ];

    if ($slots){
	my $sql_suffix;
	foreach my $slot_no (sort orderOutFromZero keys %{$slots}){
	    $sql_suffix="";
	    if ($slots->{$slot_no}){
		if (ref $slots->{$slot_no}{'aid'} eq 'ARRAY'){
		    if (scalar(@{$slots->{$slot_no}{'aid'}})){
			$sql_suffix=
			    "where m.accession_id in ('".
			    join("','",@{$slots->{$slot_no}{'aid'}}).
			    "')";
		    }
		}
		else{
		    if ($slots->{$slot_no}{'field'} eq 'map_set_aid'){
			#Map set aid
			if ($slot_no ==0){
			    $sql_suffix=
				q[,
				  cmap_map_set ms
				  where m.map_set_id=ms.map_set_id
				  ].
				  "and ms.accession_id = '".
				  $slots->{$slot_no}{'aid'}.
				  "'";
			}
			else{
			    my $slot_modifier= $slot_no>0 ? -1 : 1;
			    $sql_suffix=
				q[, cmap_feature f1,
				  cmap_feature f2,
				  cmap_correspondence_lookup cl,
				  cmap_map_set ms
				  where m.map_set_id=ms.map_set_id
				  and m.map_id=f1.map_id 
				  and f1.feature_id=cl.feature_id1
				  and f2.feature_id=cl.feature_id2
				  ].
				"and f2.map_id in (".
				join(",",
				     map {$_->[0]}
				     @{$self->{'slot_info'}{$slot_no+$slot_modifier}}).
				     ")". 
				  " and ms.accession_id = '".
				  $slots->{$slot_no}{'aid'}.
				  "'";
			}
		    }
		    else{
			###aid is a list of map_ids
			$sql_suffix=
			    "where m.accession_id = '".
			    $slots->{$slot_no}{'aid'}.
			    "'";
		    }
		}
		if ($sql_suffix){
		    ###If aid was found, $sql_suffix will be created
		    my $slot_results;
		    unless ($slot_results=
			    $self->get_cached_results($sql_str.$sql_suffix)){ 
			$slot_results=
			    $db->selectall_arrayref($sql_str.$sql_suffix, {},());
			$self->store_cached_results($sql_str.$sql_suffix,$slot_results);
		    }
			
		    push @{$self->{'slot_info'}{$slot_no}}, 
		    @{$slot_results};
		}
	    }
	}	
    }
    return $self->{'slot_info'};
}

sub orderOutFromZero{
    ###Return the sort in this order (0,1,2,3,-1,-2,-3)
    ###If both are positive (or 0) give the cmp.
    return $a cmp $b if ($a>=0 and $b>=0);
    ###Otherwise reverse the compare.
    return $b cmp $a;
}

# ----------------------------------------------------
sub get_cached_results{
    my $self=shift;
    my $query=shift;
    return thaw($self->{'cache'}->get($query));
}

sub store_cached_results{
    my $self=shift;
    my $query=shift;
    my $object=shift;
    #print S#TDERR Dumper($self->get_cached_results($query));
    #print S#TDERR "$query\n";
    #print S#TDERR Dumper($object)."---------------------\n";
    $self->{'cache'}->set($query,freeze($object));
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

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
