package Bio::GMOD::CMap::Admin;
# vim: set ft=perl:

# $Id: Admin.pm,v 1.40 2003-12-20 02:28:29 kycl4rk Exp $

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
$VERSION = (qw$Revision: 1.40 $)[-1];

use Data::Dumper;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Utils qw[ next_number parse_words ];
use base 'Bio::GMOD::CMap';
use Bio::GMOD::CMap::Constants;

# ----------------------------------------------------
sub attribute_delete {

=pod

=head2 attribute_delete

Delete an object's attributes.

=cut

    my $self       = shift;
    my $table_name = shift     or return;
    my $object_id  = shift     or return;
    my $db         = $self->db or return;

    $db->do(
        'delete from cmap_attribute where table_name=? and object_id=?',
        {},
        ( $table_name, $object_id )
    );
}

# ----------------------------------------------------
sub correspondence_evidence_delete {

=pod

=head2 correspondence_evidence_delete

Delete a correspondence evidence.

=cut

    my ( $self, %args ) = @_;
    my $corr_evidence_id = $args{'correspondence_evidence_id'} 
        or return $self->error('No correspondence evidence id');

    $self->attribute_delete('cmap_correspondence_evidence', $corr_evidence_id);

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
        $self->attribute_delete('cmap_evidence_type', $evidence_type_id);
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
sub feature_alias_create {
    my ( $self, %args )  = @_;
    my $db               = $self->db;
    my $feature_id       = $args{'feature_id'} or 
                           return $self->error('No feature id');
    my $alias            = $args{'alias'} or return 1;
    my $feature_name     = $db->selectrow_array(
        q[
            select feature_name
            from   cmap_feature
            where  feature_id=?
        ],
        {},
        ( $feature_id )
    );

    return 1 if $alias eq $feature_name;

    my $feature_alias_id = $db->selectrow_array(
        q[
            select feature_alias_id
            from   cmap_feature_alias
            where  feature_id=?
            and    alias=?
        ],
        {},
        ( $feature_id, $alias )
    );

    return 1 if $feature_alias_id;

    $feature_alias_id = next_number(
        db            => $db, 
        table_name    => 'cmap_feature_alias',
        id_field      => 'feature_alias_id',
    ) or return $self->error('No feature alias id');

    $db->do(
        q[
            insert
            into   cmap_feature_alias
                   (feature_alias_id, feature_id, alias)
            values (?, ?, ?)
        ],
        {},
        ( $feature_alias_id, $feature_id, $alias )
    );

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

    $self->attribute_delete( 'cmap_feature', $feature_id );

    $db->do(
        q[
            delete
            from    cmap_feature_alias
            where   feature_id=?
        ],
        {},
        ( $feature_id )
    );

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

    $self->attribute_delete( 'cmap_feature_correspondence', $feature_corr_id );

    return 1;
}

# ----------------------------------------------------
sub feature_type_create {
    my ( $self, %args ) = @_;
    my @missing         = ();
    my $db              = $self->db or return $self->error;
    my $feature_type    = $args{'feature_type'} or push @missing,'feature type';
    my $shape           = $args{'shape'}        or push @missing, 'shape';

    if ( @missing ) {
        return $self->error('Missing required fields: ', join(', ', @missing));
    }

    my $color            = $args{'color'}            || '';
    my $default_rank     = $args{'default_rank'}     ||  1;
    my $drawing_lane     = $args{'drawing_lane'}     ||  1;
    my $drawing_priority = $args{'drawing_priority'} ||  1;
    my $feature_type_id  = next_number(
        db               => $db,
        table_name       => 'cmap_feature_type',
        id_field         => 'feature_type_id',
    ) or return $self->error('No feature type id');
    my $accession_id     = $args{'accession_id'} || $feature_type_id;

    $db->do(
        q[
            insert
            into   cmap_feature_type
                   ( accession_id, feature_type_id, feature_type,
                     shape, color, default_rank, drawing_lane, 
                     drawing_priority
                   )
            values ( ?, ?, ?, ?, ?, ?, ?, ? )
        ],
        {},
        ( $accession_id, $feature_type_id, $feature_type,
          $shape, $color, $default_rank, $drawing_lane, $drawing_priority
        )
    );

    return $feature_type_id;
}

# ----------------------------------------------------
sub get_feature_attribute_id {

=pod

=head2 get_feature_attribute_id

Retrieves the feature attribute id for a given feature attribute.
Creates it if necessary.

=cut

    my $self                 = shift;
    my $attribute_name       = shift     or return $self->error('No name');
    my $display_order        = shift     || 1;
    my $db                   = $self->db or return;
    my $feature_attribute_id = $db->selectrow_array(
        q[
            select feature_attribute_id 
            from   cmap_feature_attribute
            where  attribute_name=?
        ],
        {},
        ( $attribute_name )
    );

    unless ( $feature_attribute_id ) {
        $feature_attribute_id = next_number( 
            db               => $db,
            table_name       => 'cmap_feature_attribute',
            id_field         => 'feature_attribute_id',
        ) or return $self->error( 
            "Can't get next ID for 'cmap_feature_attribute'"
        );

        $db->do(
            q[
                insert 
                into   cmap_feature_attribute
                       (feature_attribute_id, attribute_name, display_order)
                values (?, ?, ?)
            ],
            {},
            ( $feature_attribute_id, $attribute_name, $display_order )
        );
    }

    return $feature_attribute_id;
}

# ----------------------------------------------------
sub get_aliases {

=pod

=head2 get_aliases 

Retrieves the aliases attached to a feature.

=cut

    my ( $self, $feature_id ) = @_;
    my $db = $self->db or return;

    return $db->selectall_arrayref(
        q[
            select   feature_alias_id, feature_id, alias
            from     cmap_feature_alias
            where    feature_id=?
            order by alias
        ],
        { Columns => {} },
        ( $feature_id )
    );
}

# ----------------------------------------------------
sub feature_search {

=pod

=head2 feature_search

Find all the features matching some criteria.

=cut

    my ( $self, %args ) = @_;
    my @feature_names   = (
        map { 
            s/\*/%/g;       # turn stars into SQL wildcards
            s/,//g;         # kill commas
            s/^\s+|\s+$//g; # kill leading/trailing whitespace
            s/"//g;         # kill double quotes
            s/'/\\'/g;      # backslash escape single quotes
            uc $_ || ()     # uppercase what's left
        }
        parse_words( $args{'feature_name'} )
    );
    my $map_aid          = $args{'map_aid'}          ||             '';
    my $species_ids      = $args{'species_ids'}      ||             [];
    my $feature_type_ids = $args{'feature_type_ids'} ||             [];
    my $search_field     = $args{'search_field'}     || 'feature_name';
    my $order_by         = $args{'order_by'}         || 
        'feature_name,species_name,map_set_name,map_name,start_position';
    my $limit_start      = $args{'limit_start'}      ||              0;
    my $db               = $self->db or return;

    #
    # "-1" is a reserved value meaning "all"
    #
    $species_ids      = [] if grep { /^-1$/ } @$species_ids;
    $feature_type_ids = [] if grep { /^-1$/ } @$feature_type_ids;

    my %features;
    for my $feature_name ( map { uc $_ } @feature_names ) {
        my $comparison = $feature_name =~ m/%/ ? 'like' : '=';

        my $where;
        if ( $search_field eq 'feature_name' ) {
            $feature_name = uc $feature_name;
            $where = qq[
                where  (
                    upper(f.feature_name) $comparison '$feature_name'
                    or
                    upper(fa.alias) $comparison '$feature_name'
                )
            ];
        }
        else {
            $where = qq[where f.accession_id $comparison '$feature_name'];
        }

        my $sql = qq[
            select     f.feature_id, 
                       f.accession_id as feature_aid,
                       f.feature_name,
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
            from       cmap_feature f
            left join  cmap_feature_alias fa
            on         f.feature_id=fa.feature_id
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
            $where 
        ];
        $sql .= "and map.accession_id='$map_aid' " if $map_aid;

        if ( @$species_ids ) {
            $sql .= 'and ms.species_id in (' . 
                join(', ', @$species_ids ) . ') ';
        }

        if ( my $ft = join(', ',  @$feature_type_ids ) ) {
            $sql .= "and f.feature_type_id in ($ft) ";
        }

        my $found = $db->selectall_hashref( $sql, 'feature_id' );
        while ( my ( $id, $f ) = each %$found ) {
            $features{ $id } = $f;
        }
    }

    my @results = ();
    if ( $order_by =~ /position/ ) {
        @results = 
            map  { $_->[1] }
            sort { $a->[0] <=> $b->[0] }
            map  { [ $_->{ $order_by }, $_ ] }
            values %features
        ;
    }
    else {
        my @sort_fields = split( /,/, $order_by );
        @results = 
            map  { $_->[1] }
            sort { $a->[0] cmp $b->[0] }
            map  { [ join('', @{ $_ }{ @sort_fields } ), $_ ] }
            values %features
        ;
    }

    return \@results;
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

    $self->attribute_delete( 'cmap_feature_type', $feature_type_id );

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
sub insert_correspondence {

=pod

=head2 insert_correspondence

Inserts a correspondence.  Returns -1 if there is nothing to do.

=cut

    my $self             = shift;
    my $feature_id1      = shift;
    my $feature_id2      = shift;
    my $evidence_type_id = shift;
    my $accession_id     = shift || '';
    my $is_enabled       = shift;
       $is_enabled       = 1 unless defined $is_enabled;
    my $db               = $self->db or return;
    return -1 if $feature_id1 == $feature_id2;

    my $feature_sth = $db->prepare(
        q[
            select f.feature_id,
                   f.feature_name,
                   map.accession_id as map_aid,
                   map.map_name,
                   map.map_set_id,
                   mt.is_relational_map
            from   cmap_feature f,
                   cmap_map map,
                   cmap_map_set ms,
                   cmap_map_type mt
            where  f.feature_id=?
            and    f.map_id=map.map_id
            and    map.map_set_id=ms.map_set_id
            and    ms.map_type_id=mt.map_type_id
        ]
    );

    $feature_sth->execute( $feature_id1 );
    my $feature1 = $feature_sth->fetchrow_hashref;
    $feature_sth->execute( $feature_id2 );
    my $feature2 = $feature_sth->fetchrow_hashref;

    #
    # Don't create correspondences among relational maps.
    #
    return -1 if 
        $feature1->{'map_set_id'} == $feature2->{'map_set_id'} 
        &&
        $feature1->{'is_relational_map'} == 1;

    #
    # Don't create correspondences among relational map sets.
    #
    return -1 if $feature1->{'is_relational_map'} && 
        $feature2->{'is_relational_map'};

    #
    # Skip if a correspondence with this evidence type exists already.
    #
    my $count = $db->selectrow_array(
        q[
            select count(*)
            from   cmap_correspondence_lookup cl,
                   cmap_correspondence_evidence ce
            where  cl.feature_id1=?
            and    cl.feature_id2=?
            and    cl.feature_correspondence_id=ce.feature_correspondence_id
            and    ce.evidence_type_id=?
        ],
        {},
        ( $feature_id1, $feature_id2, $evidence_type_id )
    ) || 0;
    return -1 if $count;

    #
    # See if a correspondence exists already.
    #
    my $feature_correspondence_id = $db->selectrow_array(
        q[
            select feature_correspondence_id
            from   cmap_correspondence_lookup
            where  feature_id1=?
            and    feature_id2=?
        ],
        {},
        ( $feature_id1, $feature_id2 )
    ) || 0;

    unless ( $feature_correspondence_id ) {
        $feature_correspondence_id = next_number(
            db               => $db,
            table_name       => 'cmap_feature_correspondence',
            id_field         => 'feature_correspondence_id',
        ) or return $self->error('No next number for feature correspondence');
        $accession_id ||= $feature_correspondence_id;

        #
        # Create the official correspondence record.
        #
        $db->do(
            q[
                insert
                into   cmap_feature_correspondence
                       ( feature_correspondence_id, accession_id,
                         feature_id1, feature_id2, is_enabled )
                values ( ?, ?, ?, ?, ? )
            ],
            {},
            ( 
                $feature_correspondence_id, 
                $accession_id, 
                $feature_id1, 
                $feature_id2,
                $is_enabled
            )
        );
    }

    #
    # Create the evidence.
    #
    my $correspondence_evidence_id = next_number(
        db               => $db,
        table_name       => 'cmap_correspondence_evidence',
        id_field         => 'correspondence_evidence_id',
    ) or return $self->error('No next number for correspondence evidence');

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
        ( 
            $correspondence_evidence_id,  
            $correspondence_evidence_id, 
            $feature_correspondence_id,   
            $evidence_type_id
        )
    );

    #
    # Create the lookup record.
    #
    my @insert = (
        [ $feature_id1, $feature_id2 ],
        [ $feature_id2, $feature_id1 ],
    );

    for my $vals ( @insert ) {
        next if $db->selectrow_array(
            q[
                select count(*)
                from   cmap_correspondence_lookup cl
                where  cl.feature_id1=?
                and    cl.feature_id2=?
                and    cl.feature_correspondence_id=?
            ],
            {},
            ( $vals->[0], $vals->[1], $feature_correspondence_id )
        );

        $db->do(
            q[
                insert
                into   cmap_correspondence_lookup
                       ( feature_id1, feature_id2,
                         feature_correspondence_id )
                values ( ?, ?, ? )
            ],
            {},
            ( $vals->[0], $vals->[1], $feature_correspondence_id )
        );
    }
    
    return $feature_correspondence_id;
}

# ----------------------------------------------------
sub map_create {
    my ( $self, %args ) = @_;
    my @missing         = ();
    my $map_set_id      = $args{'map_set_id'} or
                         push @missing, 'map set id';
    my $map_name       = $args{'map_name'};
    push @missing, 'map name' unless defined $map_name && $map_name ne '';
    my $start_position = $args{'start_position'};
    push @missing, 'start position' unless 
        defined $start_position && $start_position ne '';
    my $stop_position  = $args{'stop_position'};
    push @missing, 'stop position' unless 
        defined $stop_position && $stop_position ne '';

    if ( @missing ) {
        return $self->error('Missing required fields: ', join(', ', @missing));
    }

    unless ( $start_position =~ NUMBER_RE ) {
        return $self->error("Bad start position ($start_position)");
    }

    unless ( $stop_position =~ NUMBER_RE ) {
        return $self->error("Bad stop position ($stop_position)");
    }

    my $db              = $self->db or return $self->error;
    my $map_id          = next_number(
        db              => $db,
        table_name      => 'cmap_map',
        id_field        => 'map_id',
    ) or die 'No next number for map id';

    my $accession_id   = $args{'accession_id'}  || $map_id;
    my $display_order  = $args{'display_order'} ||       1;

    $db->do(
        q[
            insert
            into   cmap_map
                   ( map_id, accession_id, map_set_id, map_name,
                     display_order, start_position, stop_position )
            values ( ?, ?, ?, ?, ?, ?, ? )
        ],
        {},
        ( $map_id, $accession_id, $map_set_id, $map_name, $display_order,
          $start_position, $stop_position,
        )
    );

    return $map_id;
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

    $self->attribute_delete( 'cmap_map', $map_id );
    
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

    $self->attribute_delete( 'cmap_map_set', $map_set_id );

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
sub map_type_create {
    my ( $self, %args ) = @_;
    my @missing         = ();
    my $map_type        = $args{'map_type'}  or push @missing, 'map type';
    my $map_units       = $args{'map_units'} or push @missing, 'map units';
    my $shape           = $args{'shape'}     or push @missing, 'shape';

    if ( @missing ) {
        return $self->error('Missing required fields: ', join(', ', @missing));
    }

    my $width             = $args{'width'}             || '';
    my $color             = $args{'color'}             || '';
    my $display_order     = $args{'display_order'}     ||  1;
    my $is_relational_map = $args{'is_relational_map'} ||  0;
    my $db                = $self->db;
    my $map_type_id       = next_number(
        db                => $db,
        table_name        => 'cmap_map_type',
        id_field          => 'map_type_id',
    ) or return $self->error('No map type id');
    my $accession_id      = $args{'accession_id'} || $map_type_id;

    $db->do(
        q[
            insert
            into   cmap_map_type
                   ( map_type_id, accession_id, map_type, map_units,
                     is_relational_map, display_order, shape, width, color )
            values ( ?, ?, ?, ?, ?, ?, ?, ?, ? )
        ],
        {},
        ( $map_type_id, $accession_id, $map_type, $map_units,
          $is_relational_map, $display_order, $shape, $width, $color )
    );

    return $map_type_id;
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
        $self->attribute_delete( 'cmap_map_type', $map_type_id );

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
    my ( $i, $new_records ) = ( 0, 0 ); # counters
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
                         ms.short_name,
                         s.accession_id,
                         s.common_name
                order by map_set_name
            ],
            { Columns => {} },
            ( $map->{'map_id'} )
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
sub set_attributes {

=pod

=head2 set_attributes

Set the attributes for a database object.

=cut

    my ( $self, %args ) = @_;
    my $object_id       = $args{'object_id'} or 
                          return $self->error('No object id');
    my $table_name      = $args{'table_name'} or 
                          return $self->error('No table name');
    my @attributes      = @{ $args{'attributes'} || [] } or return;
    my $overwrite       = $args{'overwrite'} || 0;
    my $db              = $self->db or return;

    if ( $overwrite ) {
        $db->do(
            'delete from cmap_attribute where object_id=? and table_name=?',
            {},
            $object_id, $table_name
        );
    }

    for my $attr ( @attributes ) {
        my $attribute_id  = $attr->{'attribute_id'} || 0;
        my $attr_name     = $attr->{'name'}  || $attr->{'attribute_name'};
        my $attr_value    = $attr->{'value'} || $attr->{'attribute_value'};
        my $is_public     = $attr->{'is_public'};
        my $display_order = $attr->{'display_order'};

        next unless 
            defined $attr_name  && $attr_name  ne '' && 
            defined $attr_value && $attr_value ne ''
        ;

        $attribute_id ||= $db->selectrow_array(
            q[
                select attribute_id
                from   cmap_attribute
                where  object_id=?
                and    table_name=?
                and    attribute_name=?
                and    attribute_value=?
            ],
            {},
            ( $object_id, $table_name, $attr_name, $attr_value )
        );

        if ( $attribute_id ) {
            my @update_fields   =  (
                [ object_id       => $object_id  ],
                [ table_name      => $table_name ],
                [ attribute_name  => $attr_name  ],
                [ attribute_value => $attr_value ],
            );

            if ( defined $display_order ) {
                push @update_fields, [ display_order => $display_order ];
            }

            if ( defined $is_public ) {
                push @update_fields, [ is_public => $is_public ];
            }

            my $update_sql = 
                'update cmap_attribute set ' .
                join(', ', map { $_->[0].'=?' } @update_fields) .
                ' where attribute_id=?'
            ;

            $db->do(
                $update_sql,
                {}, 
                ( ( map { $_->[1] } @update_fields ), $attribute_id )
            ); 
        }
        else {
            $attribute_id  =  next_number( 
                db         => $db,
                table_name => 'cmap_attribute',
                id_field   => 'attribute_id',
            ) or return $self->error(
                "Can't get next ID for 'cmap_attribute'"
            );

            unless ( $display_order ) {
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

            $is_public = 1 unless defined $is_public;

            $db->do(
                q[
                    insert 
                    into    cmap_attribute
                            (attribute_id, object_id, table_name,
                             display_order, is_public, 
                             attribute_name, attribute_value)
                    values  (?, ?, ?, ?, ?, ?, ?)
                ],
                {}, 
                ($attribute_id, $object_id, $table_name, 
                 $display_order, $is_public, $attr_name, $attr_value)
            );
        }
    }

    return 1;
}

# ----------------------------------------------------
sub set_xrefs {

=pod

=head2 set_xrefs

Set the attributes for a database object.

=cut

    my ( $self, %args ) = @_;
    my $object_id       = $args{'object_id'};
    my $table_name      = $args{'table_name'} or 
                          return $self->error('No table name');
    my @xrefs           = @{ $args{'xrefs'} || [] } or return;
    my $overwrite       = $args{'overwrite'} || 0;
    my $db              = $self->db or return;

    if ( $overwrite && $object_id ) {
        $db->do(
            'delete from cmap_xref where object_id=? and table_name=?',
            {},
            $object_id, $table_name
        );
    }

    for my $attr ( @xrefs ) {
        my $xref_id       = $attr->{'xref_id'} || 0;
        my $xref_name     = $attr->{'name'}    || $attr->{'xref_name'};
        my $xref_url      = $attr->{'url'}     || $attr->{'xref_url'};
        my $display_order = $attr->{'display_order'};

        next unless 
            defined $xref_name && $xref_name ne '' && 
            defined $xref_url  && $xref_url  ne ''
        ;

        if ( $object_id ) {
            $xref_id ||= $db->selectrow_array(
                q[
                    select xref_id
                    from   cmap_xref
                    where  object_id=?
                    and    table_name=?
                    and    xref_name=?
                    and    xref_url=?
                ],
                {},
                ( $object_id, $table_name, $xref_name, $xref_url )
            );
        }

        if ( $xref_id ) {
            my @update_fields =  (
                [ table_name  => $table_name ],
                [ xref_name   => $xref_name  ],
                [ xref_url    => $xref_url   ],
            );

            if ( defined $object_id ) {
                push @update_fields, [ object_id => $object_id ];
            }

            if ( defined $display_order && $display_order ne '' ) {
                push @update_fields, [ display_order => $display_order ];
            }

            my $update_sql = 
                'update cmap_xref set ' .
                join(', ', map { $_->[0].'=?' } @update_fields) .
                ' where xref_id=?'
            ;

            $db->do(
                $update_sql,
                {}, 
                ( ( map { $_->[1] } @update_fields ), $xref_id )
            ); 
        }
        else {
            $xref_id       =  next_number( 
                db         => $db,
                table_name => 'cmap_xref',
                id_field   => 'xref_id',
            ) or return $self->error( "Can't get next ID for 'cmap_xref'" );

            unless ( defined $display_order && $display_order ne '') {
                my $do_sql = qq[
                    select max(display_order)
                    from   cmap_xref
                    where  table_name='$table_name'
                ];
                $do_sql  .= "and object_id=$object_id" if $object_id;
                $display_order = $db->selectrow_array( $do_sql );
                $display_order++;
            }

            $db->do(
                q[
                    insert 
                    into    cmap_xref
                            (xref_id, object_id, table_name,
                             display_order, xref_name, xref_url)
                    values  (?, ?, ?, ?, ?, ?)
                ],
                {}, 
                ($xref_id, $object_id, $table_name, 
                 $display_order, $xref_name, $xref_url)
            );
        }
    }

    return 1;
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
sub species_create {
    my ( $self, %args ) = @_;
    my @missing;
    my $db              = $self->db;
    my $common_name     = $args{'common_name'} or
                          push @missing, 'common name';
    my $full_name       = $args{'full_name'}   or
                          push @missing, 'full name';
    if ( @missing ) {
        return $self->error('Missing required fields: ', join(', ', @missing));
    }

    my $display_order   = $args{'display_order'} || 1;
    my $species_id      = next_number(
        db              => $db, 
        table_name      => 'cmap_species',
        id_field        => 'species_id',
    ) or return $self->error( "Can't get new species id" );
    my $accession_id    = $args{'accession_id'} || $species_id;
            
    $db->do(         
        q[           
            insert   
            into   cmap_species 
                   ( accession_id, species_id, full_name, common_name,
                     display_order
                   )
            values ( ?, ?, ?, ?, ? )
        ],
        {},
        ($accession_id, $species_id, $full_name, $common_name, $display_order)
    );

    return $species_id;
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
        $self->attribute_delete( 'cmap_species', $species_id );

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

# ----------------------------------------------------
sub xref_delete {

=pod

=head2 xref_delete

Delete a cross reference.

=cut

    my $self       = shift;
    my $table_name = shift     or return;
    my $object_id  = shift     or return;
    my $db         = $self->db or return;

    $db->do(
        'delete from cmap_xref where table_name=? and object_id=?',
        {},
        ( $table_name, $object_id )
    );

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

=head1 COPYRIGHT

Copyright (c) 2002-3 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
