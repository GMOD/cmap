package Bio::GMOD::CMap::Apache::AdminViewer;

# $Id: AdminViewer.pm,v 1.17 2003-01-25 00:43:12 kycl4rk Exp $

use strict;
use Data::Dumper;

use Apache::Constants qw[ :common M_GET REDIRECT ];
use Apache::Request;
use Template;
use Time::Object;
use Time::ParseDate;

use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Admin;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Utils;

use base 'Bio::GMOD::CMap::Apache';

use constant ADMIN_HOME_URI => '/cmap/admin';

use vars qw( 
    $VERSION $COLORS $MAP_SHAPES $FEATURE_SHAPES $WIDTHS $LINE_STYLES
);

$COLORS         = [ sort keys %{ +COLORS } ];
$FEATURE_SHAPES = [ qw( box dumbbell line span ) ];
$LINE_STYLES    = [ qw( dashed solid ) ];
$MAP_SHAPES     = [ qw( box dumbbell I-beam ) ];
$WIDTHS         = [ 1 .. 10 ];
$VERSION        = (qw$Revision: 1.17 $)[-1];

use constant TEMPLATE         => {
    admin_home                => 'admin_home.tmpl',
    confirm_delete            => 'admin_confirm_delete.tmpl',
    corr_evidence_create      => 'admin_corr_evidence_create.tmpl',
    corr_evidence_edit        => 'admin_corr_evidence_edit.tmpl',
    corr_evidence_types_view  => 'admin_corr_evidence_types_view.tmpl',
    corr_evidence_type_create => 'admin_corr_evidence_type_create.tmpl',
    corr_evidence_type_edit   => 'admin_corr_evidence_type_edit.tmpl',
    dbxref_create             => 'admin_dbxref_create.tmpl',
    dbxref_edit               => 'admin_dbxref_edit.tmpl',
    dbxrefs_view              => 'admin_dbxrefs_view.tmpl',
    error                     => 'admin_error.tmpl',
    feature_corr_create       => 'admin_feature_corr_create.tmpl',
    feature_corr_view         => 'admin_feature_corr_view.tmpl',
    feature_corr_edit         => 'admin_feature_corr_edit.tmpl',
    feature_edit              => 'admin_feature_edit.tmpl',
    feature_create            => 'admin_feature_create.tmpl',
    feature_view              => 'admin_feature_view.tmpl',
    feature_search            => 'admin_feature_search.tmpl',
    feature_types_view        => 'admin_feature_types_view.tmpl',
    feature_type_create       => 'admin_feature_type_create.tmpl',
    feature_type_edit         => 'admin_feature_type_edit.tmpl',
    map_create                => 'admin_map_create.tmpl',
    map_edit                  => 'admin_map_edit.tmpl',
    map_view                  => 'admin_map_view.tmpl',
    map_sets_view             => 'admin_map_sets_view.tmpl',
    map_set_create            => 'admin_map_set_create.tmpl',
    map_set_edit              => 'admin_map_set_edit.tmpl',
    map_set_view              => 'admin_map_set_view.tmpl',
    map_type_edit             => 'admin_map_type_edit.tmpl',
    map_type_create           => 'admin_map_type_create.tmpl',
    map_types_view            => 'admin_map_types_view.tmpl',
    species_edit              => 'admin_species_edit.tmpl',
    species_create            => 'admin_species_create.tmpl',
    species_view              => 'admin_species_view.tmpl',
};

# ----------------------------------------------------
sub handler {
#
# Make a jazz noise here...
#
    my ( $self, $apr ) = @_;
    my $action         = $apr->param( 'action' ) || 'admin_home';
    my $return         = eval { $self->$action() };

    if ( my $err = $@ || $self->error ) {
        $self->process_template(
            $self->error_template,
            { error => $err }
        );
    }

    return $return || OK;
}

# ----------------------------------------------------
sub admin {
#
# Returns the "admin" object.
#
    my $self = shift;
    unless ( defined $self->{'admin'} ) {
        $self->{'admin'} = Bio::GMOD::CMap::Admin->new;
    }
    return $self->{'admin'};
}

# ----------------------------------------------------
sub admin_home {
    my $self = shift;
    my $apr  = $self->apr;

    return $self->process_template( 
        TEMPLATE->{'admin_home'}, 
        { 
            stylesheet  => $self->stylesheet,
        }
    );
}

# ----------------------------------------------------
sub confirm_delete {
    my $self        = shift;
    my $db          = $self->db;
    my $apr         = $self->apr;
    my $entity_type = $apr->param('entity_type') or die 'No entity type';
    my $entity_id   = $apr->param('entity_id')   or die 'No entity id';
    my $entity_name = $apr->param('entity_name') || '';

    unless ( $entity_name ) {
        (my $base_table_name  = $entity_type ) =~ s/^cmap_//;
        my $entity_id_field   = $apr->param('entity_id_field') || 
                                $base_table_name.'_id';
        my $entity_name_field = $apr->param('entity_name_field') || 
                                $base_table_name.'_name';
        $entity_name          = $db->selectrow_array(
            qq[
                select $entity_name_field
                from   $entity_type
                where  $entity_id_field=$entity_id
            ]
        );
    }

    my $entity = {
        id     => $entity_id,
        name   => $entity_name,
        type   => $entity_type, 
    };

    return $self->process_template( 
        TEMPLATE->{'confirm_delete'}, 
        { entity => $entity }, 
    );
}

# ----------------------------------------------------
sub corr_evidence_type_create {
    my ( $self, %args ) = @_;
    return $self->process_template( 
        TEMPLATE->{'corr_evidence_type_create'},
        { 
            apr         => $self->apr,
            line_styles => $LINE_STYLES,
            line_colors => $COLORS,
            errors      => $args{'errors'} 
        }
    );
}

# ----------------------------------------------------
sub corr_evidence_type_insert {
    my $self          = shift;
    my @errors        = ();
    my $db            = $self->db;
    my $apr           = $self->apr;
    my $evidence_type = $apr->param('evidence_type') or 
        push @errors, 'No evidence type';
    my $evidence_id   = next_number(
        db            => $db, 
        table_name    => 'cmap_evidence_type',
        id_field      => 'evidence_type_id',
    ) or push @errors, 'No next number for correspondence evidence type id';
    my $accession_id  = $apr->param('accession_id')  || $evidence_id;
    my $rank          = $apr->param('rank')          ||  1;
    my $line_style    = $apr->param('line_style')    || '';
    my $line_color    = $apr->param('line_color')    || '';

    return $self->corr_evidence_type_create( errors => \@errors ) if @errors;

    $db->do(
        q[
            insert
            into    cmap_evidence_type
                    ( evidence_type_id, accession_id, evidence_type, 
                      rank, line_style, line_color )
            values  ( ?, ?, ?, ?, ?, ? )
        ],
        {},
        ( $evidence_id, $accession_id, $evidence_type, 
          $rank, $line_style, $line_color )
    );

    return $self->redirect_home( 
        ADMIN_HOME_URI.'?action=corr_evidence_types_view'
    ); 
}

# ----------------------------------------------------
sub corr_evidence_type_edit {
    my ( $self, %args )  = @_;
    my $errors           = $args{'errors'};
    my $db               = $self->db;
    my $apr              = $self->apr;
    my $evidence_type_id = $apr->param('evidence_type_id') 
        or return $self->error('No evidence type id');

    my $sth = $db->prepare(
        q[
            select et.evidence_type_id,
                   et.accession_id,
                   et.evidence_type,
                   et.rank,
                   et.line_style,
                   et.line_color
            from   cmap_evidence_type et
            where  et.evidence_type_id=?
        ]
    );
    $sth->execute( $evidence_type_id );
    my $evidence_type = $sth->fetchrow_hashref or return $self->error(
        "No evidence type for ID '$evidence_type_id'"
    );

    return $self->process_template( 
        TEMPLATE->{'corr_evidence_type_edit'}, 
        { 
            evidence_type => $evidence_type,
            line_styles   => $LINE_STYLES,
            line_colors   => $COLORS,
            errors        => $errors,
        }
    );
}

# ----------------------------------------------------
sub corr_evidence_type_update {
    my $self             = shift;
    my @errors           = ();
    my $db               = $self->db;
    my $apr              = $self->apr;
    my $evidence_type_id = $apr->param('evidence_type_id') 
                           or push @errors, 'No evidence type id';
    my $accession_id     = $apr->param('accession_id')  
                           or push @errors, 'No accession id';
    my $evidence_type    = $apr->param('evidence_type') 
                           or push @errors, 'No evidence type';
    my $rank             = $apr->param('rank') || 1;
    my $line_style       = $apr->param('line_style') || '';
    my $line_color       = $apr->param('line_color') || '';

    return $self->corr_evidence_type_edit( errors => \@errors ) if @errors;

    $db->do(
        q[
            update cmap_evidence_type
            set    accession_id=?, evidence_type=?, 
                   rank=?, line_style=?, line_color=?
            where  evidence_type_id=?
        ],
        {},
        ( $accession_id, $evidence_type, $rank, $line_style, $line_color,
          $evidence_type_id )
    );

    return $self->redirect_home( 
        ADMIN_HOME_URI.'?action=corr_evidence_types_view'
    );
}

# ----------------------------------------------------
sub corr_evidence_types_view {
    my $self        = shift;
    my $db          = $self->db;
    my $apr         = $self->apr;
    my $order_by    = $apr->param('order_by') || 'evidence_type';
    my $limit_start = $apr->param('limit_start') ||          0;

    my $evidence_types = $db->selectall_arrayref(
        qq[
            select   et.evidence_type_id,
                     et.accession_id,
                     et.evidence_type,
                     et.rank,
                     et.line_style,
                     et.line_color
            from     cmap_evidence_type et
            order by $order_by
        ],
        { Columns => {} }
    );

    my $pager       =  paginate( 
        self        => $self,
        data        => $evidence_types,
        limit_start => $limit_start,
    );

    return $self->process_template( 
        TEMPLATE->{'corr_evidence_types_view'}, 
        { 
            evidence_types => $pager->{'data'},
            no_elements    => $pager->{'no_elements'},
            page_size      => $pager->{'page_size'},
            pages          => $pager->{'pages'},
            cur_page       => $pager->{'cur_page'},
            show_start     => $pager->{'show_start'},
            show_stop      => $pager->{'show_stop'},
        }
    );
}

# ----------------------------------------------------
sub dbxref_create {
    my ( $self, %args ) = @_;
    my $admin           = $self->admin;

    return $self->process_template( 
        TEMPLATE->{'dbxref_create'},
        {
            apr           => $self->apr,
            errors        => $args{'errors'},
            specie        => $admin->species,
            map_sets      => $admin->map_sets,
            feature_types => $admin->feature_types,
        }
    );
}

# ----------------------------------------------------
sub dbxref_edit {
    my ( $self, %args ) = @_;
    my $apr             = $self->apr;
    my $dbxref_id       = $apr->param('dbxref_id') or die 'No dbxref id';
    my $admin           = $self->admin;

    my $sth = $self->db->prepare(
        q[
            select    d.dbxref_id,
                      d.map_set_id,
                      d.feature_type_id,
                      d.species_id,
                      d.dbxref_name,
                      d.url,
                      ft.feature_type,
                      ms.short_name as map_set_name,
                      s.common_name as species_name
            from      cmap_dbxref d
            left join cmap_map_set ms
            on        d.map_set_id=ms.map_set_id
            left join cmap_species s
            on        d.species_id=s.species_id
            inner join cmap_feature_type ft
            on        d.feature_type_id=ft.feature_type_id
            where     d.dbxref_id=?
        ]
    );
    $sth->execute( $dbxref_id );
    my $dbxref = $sth->fetchrow_hashref or return $self->error(
        "No database cross-reference for ID '$dbxref_id'"
    );

    return $self->process_template( 
        TEMPLATE->{'dbxref_edit'},
        {
            apr           => $self->apr,
            errors        => $args{'errors'},
            dbxref        => $dbxref,
            specie        => $admin->species,
            map_sets      => $admin->map_sets,
            feature_types => $admin->feature_types,
        }
    );
}

# ----------------------------------------------------
sub dbxref_insert {
    my $self            = shift;
    my $db              = $self->db;
    my $apr             = $self->apr;
    my $admin           = $self->admin;
    my @errors          = ();
    my $species_id      = $apr->param('species_id')      ||  0;
    my $map_set_id      = $apr->param('map_set_id')      ||  0;
    my $feature_type_id = $apr->param('feature_type_id') ||  0;
    my $name            = $apr->param('dbxref_name')     || '';
    my $url             = $apr->param('url')             || '';

    unless ( $species_id || $map_set_id ) {
        push @errors, 'Please choose either a species or a map set';
    }
    if ( $species_id && $map_set_id ) {
        push @errors, 'Please choose only one of either a species or a map set';
    }
    push @errors, 'Please supply a feature' unless $feature_type_id;
    push @errors, 'Please supply a name'    unless $name;
    push @errors, 'Please supply a URL'     unless $url;

#    if ( $species_id ) {
#        my $exists = $db->selectrow_array(
#            q[
#                select count(*)
#                from   cmap_dbxref
#                where  feature_type_id=?
#                and    species_id=?
#            ],
#            {},
#            ( $feature_type_id, $species_id )
#        );
#
#        push @errors, 
#            'A record already exists for that feature type and species.'
#            if $exists;
#    }

#    if ( $map_set_id ) {
#        my $exists = $db->selectrow_array(
#            q[
#                select count(*)
#                from   cmap_dbxref
#                where  feature_type_id=?
#                and    map_set_id=?
#            ],
#            {},
#            ( $feature_type_id, $map_set_id )
#        );
#
#        push @errors, 
#            'A record already exists for that feature type and map set.'
#            if $exists;
#    }

    return $self->dbxref_create( errors => \@errors ) if @errors;

    my $dbxref_id  = next_number(
        db         => $db, 
        table_name => 'cmap_dbxref',
        id_field   => 'dbxref_id',
    ) or die 'No next number for dbxref id';

    $db->do(
        q[
            insert
            into   cmap_dbxref
                   (dbxref_id, species_id, map_set_id, 
                    feature_type_id, dbxref_name, url)
            values (?, ?, ?, ?, ?, ?)
        ],
        {},
        ( $dbxref_id, $species_id, $map_set_id, 
          $feature_type_id, $name, $url 
        )
    );

    return $self->redirect_home( ADMIN_HOME_URI.'?action=dbxrefs_view' ); 
}

# ----------------------------------------------------
sub dbxref_update {
    my $self            = shift;
    my $db              = $self->db;
    my $apr             = $self->apr;
    my $admin           = $self->admin;
    my @errors          = ();
    my $dbxref_id       = $apr->param('dbxref_id') or die 'No dbxref id';
    my $species_id      = $apr->param('species_id')      ||  0;
    my $map_set_id      = $apr->param('map_set_id')      ||  0;
    my $feature_type_id = $apr->param('feature_type_id') ||  0;
    my $name            = $apr->param('dbxref_name')     || '';
    my $url             = $apr->param('url')             || '';

    unless ( $species_id || $map_set_id ) {
        push @errors, 'Please choose either a species or a map set';
    }
    if ( $species_id && $map_set_id ) {
        push @errors, 'Please choose only one of either a species or a map set';
    }
    push @errors, 'Please supply a feature' unless $feature_type_id;
    push @errors, 'Please supply a name'    unless $name;
    push @errors, 'Please supply a URL'     unless $url;

    return $self->dbxref_edit( errors => \@errors ) if @errors;

    $db->do(
        q[
            update cmap_dbxref
            set    species_id=?, map_set_id=?, feature_type_id=?, 
                   dbxref_name=?, url=?
            where  dbxref_id=?
        ],
        {},
        ( $species_id, $map_set_id, $feature_type_id, $name, $url, $dbxref_id )
    );

    return $self->redirect_home( ADMIN_HOME_URI.'?action=dbxrefs_view' ); 
}

# ----------------------------------------------------
sub dbxrefs_view {
    my $self            = shift;
    my $db              = $self->db;
    my $admin           = $self->admin;
    my $apr             = $self->apr;
    my $order_by        = $apr->param('order_by')        ||
                          'feature_type,species_name';
    my $species_id      = $apr->param('species_id')      || 0;
    my $feature_type_id = $apr->param('feature_type_id') || 0;
    my $limit_start     = $apr->param('limit_start')     || 0;

    my $sql = qq[
        select     d.dbxref_id,
                   d.map_set_id,
                   d.feature_type_id,
                   d.species_id,
                   d.dbxref_name,
                   d.url,
                   ft.feature_type,
                   ms.short_name as map_set_name,
                   s.common_name as species_name
        from       cmap_dbxref d
        left join  cmap_map_set ms
        on         d.map_set_id=ms.map_set_id
        left join  cmap_species s
        on         d.species_id=s.species_id
        inner join cmap_feature_type ft
        on         d.feature_type_id=ft.feature_type_id
    ];
    $sql .= "and d.species_id=$species_id "           if $species_id;
    $sql .= "and d.feature_type_id=$feature_type_id " if $feature_type_id;
    $sql .= "order by $order_by";

    my $refs = $db->selectall_arrayref( $sql, { Columns => {} } );

    my $pager       =  paginate( 
        self        => $self,
        data        => $refs,
        limit_start => $limit_start,
    );

    return $self->process_template( 
        TEMPLATE->{'dbxrefs_view'}, 
        { 
            apr           => $apr,
            specie        => $admin->species,
            feature_types => $admin->feature_types,
            dbxrefs       => $pager->{'data'},
            no_elements   => $pager->{'no_elements'},
            page_size     => $pager->{'page_size'},
            pages         => $pager->{'pages'},
            cur_page      => $pager->{'cur_page'},
            show_start    => $pager->{'show_start'},
            show_stop     => $pager->{'show_stop'},
        }
    );
}

# ----------------------------------------------------
sub entity_delete {
    my $self        = shift;
    my $db          = $self->db;
    my $apr         = $self->apr;
    my $admin       = $self->admin;
    my $entity_type = $apr->param('entity_type') or die 'No entity type';
    my $uri_args;

    #
    # Map Set
    #
    if ( $entity_type eq 'cmap_map_set' ) {
        $admin->map_set_delete( map_set_id => $apr->param('entity_id') )
            or return $self->error( $admin->error );
        $uri_args = '?action=map_sets_view';
    }
    #
    # Map Type
    #
    elsif ( $entity_type eq 'cmap_map_type' ) {
        $admin->map_type_delete(
            map_type_id => $apr->param('entity_id') 
        ) or return $self->error( $admin->error );
        $uri_args = '?action=map_types_view';
    }
    #
    # Species
    #
    elsif ( $entity_type eq 'cmap_species' ) {
        $admin->species_delete( species_id => $apr->param('entity_id') ) or
            return $self->error( $admin->error );
        $uri_args = '?action=species_view';
    }
    #
    # Feature Correspondence
    #
    elsif ( $entity_type eq 'cmap_feature_correspondence' ) {
        $admin->feature_correspondence_delete( 
            feature_correspondence_id => $apr->param('entity_id') 
        ) or return $self->error( $admin->error );
    }
    #
    # Feature Type
    #
    elsif ( $entity_type eq 'cmap_feature_type' ) {
        $admin->feature_type_delete( 
            feature_type_id => $apr->param('entity_id') 
        ) or return $self->error( $admin->error );
        $uri_args = '?action=feature_types_view';
    }
    #
    # Feature
    #
    elsif ( $entity_type eq 'cmap_feature' ) {
        my $map_id = $admin->feature_delete(
            feature_id => $apr->param('entity_id')
        ) or return $self->error( $admin->error );
        $uri_args = "?action=map_view;map_id=$map_id";
    }
    #
    # Evidence Type
    #
    elsif ( $entity_type eq 'cmap_evidence_type' ) {
        $admin->evidence_type_delete(
            evidence_type_id => $apr->param('entity_id')
        ) or return $self->error( $admin->error );

        $uri_args = '?action=corr_evidence_types_view';
    }
    #
    # Map
    #
    elsif ( $entity_type eq 'cmap_map' ) {
        my $map_set_id  = $admin->map_delete( 
            map_id => $apr->param('entity_id') 
        ) or return $self->error( $admin->error );
        $uri_args = "?action=map_set_view;map_set_id=$map_set_id";
    }
    #
    # Correspondence evidence
    #
    elsif ( $entity_type eq 'cmap_correspondence_evidence' ) {
        my $feature_corr_id = $admin->correspondence_evidence_delete(
            correspondence_evidence_id => $apr->param('entity_id') 
        ) or return $self->error( $admin->error );

        $uri_args = 
        "?action=feature_corr_view;feature_correspondence_id=$feature_corr_id";
    }
    #
    # DB Cross-References
    #
    elsif ( $entity_type eq 'cmap_dbxref' ) {
        $admin->dbxref_delete(
            dbxref_id => $apr->param('entity_id') 
        ) or return $self->error( $admin->error );

        $uri_args = '?action=dbxrefs_view';
    }
    else {
        return $self->error(
            "You are not allowed to delete entities of type '$entity_type.'"
        );
    }

    return $self->redirect_home( ADMIN_HOME_URI.$uri_args ); 
}

# ----------------------------------------------------
sub error_template { 
    my $self = shift;
    return TEMPLATE->{'error'};
}

# ----------------------------------------------------
sub map_create {
    my ( $self, %args ) = @_;
    my $db              = $self->db;
    my $apr             = $self->apr;
    my $map_set_id      = $apr->param('map_set_id') or die 'No map set id';

    my $sth = $db->prepare(
        q[
            select ms.map_set_id, 
                   ms.short_name as map_set_name,
                   s.common_name as species_name
            from   cmap_map_set ms,
                   cmap_species s
            where  ms.map_set_id=?
            and    ms.species_id=s.species_id
        ]
    );
    $sth->execute( $map_set_id );
    my $map_set = $sth->fetchrow_hashref or return $self->error(
        "No map set for ID '$map_set_id'"
    );

    return $self->process_template( 
        TEMPLATE->{'map_create'}, 
        { 
            map_set => $map_set,
            errors  => $args{'errors'},
        }
    );
}

# ----------------------------------------------------
sub map_edit {
    my ( $self, %args ) = @_;
    my $errors          = $args{'errors'};
    my $db              = $self->db;
    my $apr             = $self->apr;
    my $map_id          = $apr->param('map_id');
    my $sth             = $db->prepare(
        q[
            select map.map_id, 
                   map.accession_id, 
                   map.map_name, 
                   map.start_position, 
                   map.stop_position,
                   ms.map_set_id, 
                   ms.map_set_name,
                   mt.map_type,
                   s.common_name as species_name
            from   cmap_map map, 
                   cmap_map_set ms, 
                   cmap_map_type mt,
                   cmap_species s
            where  map.map_id=?
            and    map.map_set_id=ms.map_set_id
            and    ms.map_type_id=mt.map_type_id
            and    ms.species_id=s.species_id
        ]
    );
    $sth->execute( $map_id );
    my $map = $sth->fetchrow_hashref or return $self->error(
        "No map for ID '$map_id'"
    );

    return $self->process_template( 
        TEMPLATE->{'map_edit'}, 
        { 
            map    => $map,
            errors => $errors, 
        }
    );
}

# ----------------------------------------------------
sub map_insert {
    my $self           = shift;
    my @errors         = ();
    my $db             = $self->db;
    my $apr            = $self->apr;
    my $map_id         = next_number(
        db             => $db, 
        table_name     => 'cmap_map',
        id_field       => 'map_id',
    ) or die 'No next number for map id';
    my $accession_id   = $apr->param('accession_id') || $map_id;
    my $map_name       = $apr->param('map_name')     or 
                         push @errors, 'No map name';
    my $map_set_id     = $apr->param('map_set_id')   or 
                         push @errors, 'No map set id';
    my $start_position = $apr->param('start_position');
    my $stop_position  = $apr->param('stop_position');
    push @errors, 'No start' unless $start_position =~ NUMBER_RE;
    push @errors, 'No stop'  unless $stop_position  =~ NUMBER_RE;

    return $self->map_create( errors => \@errors ) if @errors;
    
    $db->do(
        q[
            insert
            into   cmap_map
                   ( map_id, accession_id, map_set_id, map_name, 
                     start_position, stop_position )
            values ( ?, ?, ?, ?, ?, ? )
        ],
        {},
        ( $map_id, $accession_id, $map_set_id, $map_name, 
          $start_position, $stop_position 
        )
    );

    return $self->redirect_home( 
        ADMIN_HOME_URI."?action=map_view;map_id=$map_id" 
    ); 
}

# ----------------------------------------------------
sub map_view {
    my $self            = shift;
    my $db              = $self->db;
    my $apr             = $self->apr;
    my $map_id          = $apr->param('map_id')          or die  'No map id';
    my $order_by        = $apr->param('order_by')        || 'start_position';
    my $feature_type_id = $apr->param('feature_type_id') ||                0;
    my $limit_start     = $apr->param('limit_start')     ||                0;

    my $sth = $db->prepare(
        q[
            select map.map_id, 
                   map.accession_id, 
                   map.map_name, 
                   map.start_position, 
                   map.stop_position,
                   ms.map_set_id, 
                   ms.short_name as map_set_name,
                   mt.map_type,
                   s.common_name as species_name
            from   cmap_map map, 
                   cmap_map_set ms, 
                   cmap_map_type mt,
                   cmap_species s
            where  map.map_id=?
            and    map.map_set_id=ms.map_set_id
            and    ms.map_type_id=mt.map_type_id
            and    ms.species_id=s.species_id
        ]
    );
    $sth->execute( $map_id );
    my $map = $sth->fetchrow_hashref or return $self->error(
        "No map for ID '$map_id'"
    );

    my $sql = q[
        select   f.feature_id, 
                 f.accession_id, 
                 f.feature_name, 
                 f.alternate_name, 
                 f.map_id, 
                 f.start_position, 
                 f.stop_position, 
                 f.is_landmark,
                 f.feature_type_id,
                 ft.feature_type
        from     cmap_feature f, 
                 cmap_feature_type ft
        where    f.map_id=?
        and      f.feature_type_id=ft.feature_type_id
    ];
    $sql .= "and f.feature_type_id=$feature_type_id " if $feature_type_id;
    $sql .= "order by $order_by ";

    my $features = $db->selectall_arrayref($sql, { Columns => {} }, ($map_id));

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $data        =  paginate( 
        self        => $self,
        data        => $features,
        limit_start => $limit_start,
    );
    $map->{'features'} = $data->{'data'};

    my $feature_types = $db->selectall_arrayref(
        q[
            select   distinct ft.feature_type_id, ft.feature_type
            from     cmap_feature f,
                     cmap_feature_type ft
            where    f.map_id=?
            and      f.feature_type_id=ft.feature_type_id
            order by feature_type
        ],
        { Columns => {} },
        ( $map_id )
    );

    return $self->process_template( 
        TEMPLATE->{'map_view'},
        { 
            apr           => $apr,
            map           => $map,
            feature_types => $feature_types,
            limit_start   => $limit_start,
            no_elements   => $data->{'no_elements'},
            page_size     => $data->{'page_size'},
            pages         => $data->{'pages'},
            cur_page      => $data->{'cur_page'},
            show_start    => $data->{'show_start'},
            show_stop     => $data->{'show_stop'},
        }
    );
}

# ----------------------------------------------------
sub map_update {
    my $self           = shift;
    my $db             = $self->db;
    my $apr            = $self->apr;
    my @errors         = ();
    my $map_id         = $apr->param('map_id')         
        or push @errors, 'No map id';
    my $accession_id   = $apr->param('accession_id')   
        or push @errors, 'No accession id';
    my $map_name       = $apr->param('map_name')       
        or push @errors, 'No map name';
    my $start_position = $apr->param('start_position');
    push @errors, 'No start position' unless defined $start_position;
    my $stop_position  = $apr->param('stop_position')  
        or push @errors, 'No stop';

    return $self->map_edit( errors => \@errors ) if @errors;

    my $sql = q[
        update cmap_map
        set    accession_id=?, 
               map_name=?, 
               start_position=?,
               stop_position=?
        where  map_id=?
    ];
    
    $db->do( 
        $sql, 
        {}, 
        ( $accession_id, $map_name, $start_position, $stop_position, $map_id ) 
    );

    return $self->redirect_home( 
        ADMIN_HOME_URI."?action=map_view;map_id=$map_id" 
    ); 
}

# ----------------------------------------------------
sub feature_create {
    my ( $self, %args ) = @_;
    my $db              = $self->db;
    my $apr             = $self->apr;
    my $map_id          = $apr->param('map_id') or die 'No map id';

    my $sth = $db->prepare(
        q[
            select map.map_id, 
                   map.map_name,
                   ms.short_name as map_set_name,
                   s.common_name as species_name
            from   cmap_map map,
                   cmap_map_set ms,
                   cmap_species s
            where  map.map_id=?
            and    map.map_set_id=ms.map_set_id
            and    ms.species_id=s.species_id
        ]
    );
    $sth->execute( $map_id );
    my $map = $sth->fetchrow_hashref or return $self->error(
        "No map for ID '$map_id'"
    );

    my $feature_types = $db->selectall_arrayref(
        q[
            select   ft.feature_type_id,
                     ft.feature_type
            from     cmap_feature_type ft
            order by feature_type
        ],
        { Columns => {} }
    );

    return $self->process_template(
        TEMPLATE->{'feature_create'}, 
        { 
            apr           => $apr,
            map           => $map,
            feature_types => $feature_types,
            errors        => $args{'errors'},
        }
    );
}

# ----------------------------------------------------
sub feature_edit {
    my ( $self, %args ) = @_;
    my $db              = $self->db;
    my $apr             = $self->apr;
    my $feature_id      = $apr->param('feature_id') or die 'No feature id';

    my $sth = $db->prepare(
        q[
            select f.feature_id,
                   f.accession_id,
                   f.map_id,
                   f.feature_type_id,
                   f.feature_name,
                   f.alternate_name,
                   f.start_position,
                   f.stop_position,
                   f.is_landmark,
                   f.dbxref_name,
                   f.dbxref_url,
                   ft.feature_type,
                   map.map_name,
                   ms.short_name as map_set_name,
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
        ]
    );
    $sth->execute( $feature_id );
    my $feature = $sth->fetchrow_hashref or return $self->error(
        "No feature for ID '$feature_id'"
    );

    my $feature_types = $db->selectall_arrayref(
        q[
            select   ft.feature_type_id,
                     ft.feature_type
            from     cmap_feature_type ft
            order by feature_type
        ],
        { Columns => {} }
    );

    return $self->process_template(
        TEMPLATE->{'feature_edit'},
        { 
            feature       => $feature,
            feature_types => $feature_types,
            errors        => $args{'errors'},
        }, 
    );
}

# ----------------------------------------------------
sub feature_insert {
    my $self            = shift;
    my @errors          = ();
    my $db              = $self->db;
    my $apr             = $self->apr;
    my $map_id          = $apr->param('map_id') or die 'No map_id';
    my $feature_id      = next_number(
        db              => $db, 
        table_name      => 'cmap_feature',
        id_field        => 'feature_id',
    ) or die 'No feature id';
    my $accession_id    = $apr->param('accession_id') || $feature_id;
    my $feature_name    = $apr->param('feature_name') or 
                          push @errors, 'No feature name';
    my $alternate_name  = $apr->param('alternate_name') || '';
    my $feature_type_id = $apr->param('feature_type_id') 
                           or push @errors, 'No feature type';
    my $start_position  = $apr->param('start_position');
    push @errors, "No start" unless $start_position =~ NUMBER_RE;
    my $stop_position   = $apr->param('stop_position');
    my $is_landmark     = $apr->param('is_landmark') || 0;
    my $dbxref_name     = $apr->param('dbxref_name') || '';
    my $dbxref_url      = $apr->param('dbxref_url')  || '';

    return $self->feature_create( errors => \@errors ) if @errors;

    my @insert_args = ( 
        $feature_id, $accession_id, $map_id, $feature_name, 
        $alternate_name, $feature_type_id, $is_landmark, 
        $dbxref_name, $dbxref_url, $start_position
    );

    my $stop_placeholder; 
    if ( $stop_position =~ NUMBER_RE ) {
        $stop_placeholder = '?';
        push @insert_args, $stop_position;
    }
    else {
        $stop_placeholder = 'NULL';
    }

    $db->do(
        qq[
            insert
            into   cmap_feature
                   ( feature_id, accession_id, map_id, feature_name, 
                     alternate_name, feature_type_id, is_landmark,
                     dbxref_name, dbxref_url, start_position, stop_position )
            values ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, $stop_placeholder )
        ],
        {},
        @insert_args
    );

    return $self->redirect_home( 
        ADMIN_HOME_URI."?action=map_view;map_id=$map_id" 
    ); 
}

# ----------------------------------------------------
sub feature_update {
    my $self            = shift;
    my @errors          = ();
    my $db              = $self->db;
    my $apr             = $self->apr;
    my $feature_id      = $apr->param('feature_id')   or 
                          push @errors, 'No feature id';
    my $accession_id    = $apr->param('accession_id') or 
                          push @errors, 'No accession id';
    my $feature_name    = $apr->param('feature_name') or 
                          push @errors, 'No feature name';
    my $alternate_name  = $apr->param('alternate_name') || '';
    my $feature_type_id = $apr->param('feature_type_id') 
                          or die 'No feature type id';
    my $is_landmark     = $apr->param('is_landmark') || 0;
    my $start_position  = $apr->param('start_position');
    push @errors, "No start" unless $start_position =~ NUMBER_RE;
    my $stop_position   = $apr->param('stop_position');
    my $dbxref_name     = $apr->param('dbxref_name') || '';
    my $dbxref_url      = $apr->param('dbxref_url')  || '';

    return $self->feature_edit( errors => \@errors ) if @errors;

    my $sql = q[
        update cmap_feature
        set    accession_id=?, feature_name=?, alternate_name=?,
               feature_type_id=?, is_landmark=?, start_position=?,
               dbxref_name=?, dbxref_url=?
    ];
    $sql .= ", stop_position=$stop_position " if $stop_position =~ NUMBER_RE;
    $sql .= 'where  feature_id=?';
    $db->do(
        $sql,
        {},
        ( $accession_id, $feature_name, $alternate_name,
          $feature_type_id, $is_landmark, $start_position, 
          $dbxref_name, $dbxref_url,
          $feature_id
        )
    );

    return $self->redirect_home( 
        ADMIN_HOME_URI."?action=feature_view;feature_id=$feature_id" 
    ); 
}

# ----------------------------------------------------
sub feature_view {
    my $self       = shift;
    my $db         = $self->db;
    my $apr        = $self->apr;
    my $feature_id = $apr->param('feature_id') or die 'No feature id';
    my $sth = $db->prepare(
        q[
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
                   ms.short_name as map_set_name,
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
        ]
    );
    $sth->execute( $feature_id );
    my $feature = $sth->fetchrow_hashref or return $self->error(
        "No feature for ID '$feature_id'"
    );

    my $correspondences = $db->selectall_arrayref(
        q[
            select fc.feature_correspondence_id,
                   fc.accession_id,
                   fc.feature_id1,
                   fc.feature_id2,
                   fc.is_enabled,
                   f.feature_id,
                   f.feature_name as feature_name,
                   f.alternate_name as alternate_name,
                   map.map_id,
                   map.map_name,
                   ms.short_name as map_set_name,
                   s.common_name as species_name
            from   cmap_correspondence_lookup cl,
                   cmap_feature_correspondence fc,
                   cmap_feature f,
                   cmap_map map,
                   cmap_map_set ms,
                   cmap_species s
            where  cl.feature_id1=? 
            and    cl.feature_correspondence_id=fc.feature_correspondence_id
            and    cl.feature_id2=f.feature_id
            and    f.map_id=map.map_id
            and    map.map_set_id=ms.map_set_id
            and    ms.species_id=s.species_id
        ],
        { Columns => {} },
        ( $feature_id )
    );

    for my $corr ( @$correspondences ) {
        $corr->{'evidence'} = join(', ', @{
            $db->selectcol_arrayref(
                q[
                    select   et.evidence_type
                    from     cmap_correspondence_evidence ce,
                             cmap_evidence_type et
                    where    ce.feature_correspondence_id=?
                    and      ce.evidence_type_id=et.evidence_type_id
                    order by et.rank
                ],
                {},
                ( $corr->{'feature_correspondence_id'} )
            )
        } );
    }
    
    $feature->{'correspondences'} = $correspondences;

    return $self->process_template(
        TEMPLATE->{'feature_view'}, 
        { feature => $feature }
    );
}

# ----------------------------------------------------
sub feature_search {
    my $self          = shift;
    my $db            = $self->db;
    my $apr           = $self->apr;
    my $admin         = $self->admin;
    my $limit_start   = $apr->param('limit_start')  ||  0;
    my $params        = {
        apr           => $apr,
        feature_types => $admin->feature_types,
    }; 

    #
    # If given a feature to search for ...
    #
    if ( my $feature_name   = $apr->param('feature_name') ) {
        my $features        =  $admin->feature_search(
            feature_name    => $feature_name,
            map_aid         => $apr->param('map_aid')         ||  0,
            feature_type_id => $apr->param('feature_type_id') ||  0,
            field_name      => $apr->param('field_name')      || '',
            order_by        => $apr->param('order_by')        || '', 
        );

        #
        # Slice the results up into pages suitable for web viewing.
        #
        my $data        =  paginate( 
            self        => $self,
            data        => $features,
            limit_start => $limit_start,
        );

        $params->{ $_ } = $data->{ $_ } for keys %$data;
    }

    return $self->process_template( TEMPLATE->{'feature_search'}, $params );
}

# ----------------------------------------------------
sub feature_corr_create {
    my ( $self, %args ) = @_;
    my $db              = $self->db;
    my $apr             = $self->apr;
    my $feature_id1     = $apr->param('feature_id1')   or die 'No feature id';
    my $feature_id2     = $apr->param('feature_id2')   ||  0;
    my $feature2_name   = $apr->param('feature2_name') || '';
    my $species_id      = $apr->param('species_id')    ||  0;
    my $sth             = $db->prepare(
        q[
            select f.feature_id,
                   f.feature_name,
                   map.map_id,
                   map.map_name,
                   ms.short_name as map_set_name,
                   s.species_id,
                   s.common_name as species_name
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
    $sth->execute( $feature_id1 );
    my $feature1 = $sth->fetchrow_hashref or return $self->error(
        "No feature for ID '$feature_id1'"
    );

    my $feature2;
    if ( $feature_id2 ) {
        $sth->execute( $feature_id2 );
        $feature2 = $sth->fetchrow_hashref or return $self->error(
            "No feature for ID '$feature_id2'"
        );
    }

    my $feature2_choices;
    if ( $feature2_name ) {
        $feature2_name  =~ s/\*/%/g;
        $feature2_name  =~ s/['"]//g;
        my $search_term =  uc $feature2_name;
        my $sql         =  qq[
            select f.feature_id,
                   f.feature_name,
                   map.map_id,
                   map.map_name,
                   ms.short_name as map_set_name,
                   s.species_id,
                   s.common_name as species_name
            from   cmap_feature f,
                   cmap_map map,
                   cmap_map_set ms,
                   cmap_species s
            where  upper(f.feature_name) like '$search_term'
            and    f.map_id=map.map_id
            and    map.map_set_id=ms.map_set_id
            and    ms.species_id=s.species_id
        ];
        $sql .= "and s.species_id=$species_id " if $species_id;
        $feature2_choices = $db->selectall_arrayref( $sql, { Columns => {} } );
    }

    my $species = $db->selectall_arrayref(
        q[
            select   s.species_id,
                     s.common_name,
                     s.full_name
            from     cmap_species s
            order by common_name
        ],
        { Columns => {} }
    );

    my $evidence_types = $db->selectall_arrayref(
        q[
            select   et.evidence_type_id,
                     et.evidence_type,
                     et.rank
            from     cmap_evidence_type et
            order by rank, evidence_type
        ],
        { Columns => {} }
    );

    return $self->process_template(
        TEMPLATE->{'feature_corr_create'}, 
        { 
            apr              => $apr,
            feature1         => $feature1,
            feature2         => $feature2,
            feature2_choices => $feature2_choices,
            species          => $species,
            evidence_types   => $evidence_types,
            errors           => $args{'errors'},
        }, 
    );
}

# ----------------------------------------------------
sub feature_corr_insert {
    my $self             = shift;
    my @errors           = ();
    my $admin            = $self->admin or return;
    my $apr              = $self->apr;
    my $feature_id1      = $apr->param('feature_id1')  or die 'No feature id1';
    my $feature_id2      = $apr->param('feature_id2')  or die 'No feature id2';
    my $accession_id     = $apr->param('accession_id') || '';
    my $is_enabled       = $apr->param('is_enabled')   ||  0;
    my $evidence_type_id = $apr->param('evidence_type_id') or push @errors,
        'Please select an evidence type';

    push @errors, 
        "Can't create a circular correspondence (feature IDs are the same)"
        if $feature_id1 == $feature_id2;

    return $self->feature_corr_create( errors => \@errors ) if @errors;

    my $feature_correspondence_id = $admin->insert_correspondence(
        $feature_id1, $feature_id2, $evidence_type_id, 
        $accession_id, $is_enabled
    );

    return $self->redirect_home( 
        ADMIN_HOME_URI.'?action=feature_corr_view;'.
            "feature_correspondence_id=$feature_correspondence_id"
    ); 
}

# ----------------------------------------------------
sub feature_corr_edit {
    my $self                      = shift;
    my $db                        = $self->db;
    my $apr                       = $self->apr;
    my $feature_correspondence_id = $apr->param('feature_correspondence_id')
        or return $self->error('No feature correspondence id');

    my $sth = $db->prepare(
        q[
            select fc.feature_correspondence_id,
                   fc.accession_id,
                   fc.feature_id1,
                   fc.feature_id2,
                   fc.is_enabled
            from   cmap_feature_correspondence fc
            where  fc.feature_correspondence_id=?
        ]
    );
    $sth->execute( $feature_correspondence_id ); 
    my $corr = $sth->fetchrow_hashref or return $self->error(
        "No record for feature correspondence ID '$feature_correspondence_id'"
    );

    return $self->process_template(
        TEMPLATE->{'feature_corr_edit'},
        { corr => $corr  }
    );
}

# ----------------------------------------------------
sub feature_corr_update {
    my $self                      = shift;
    my $db                        = $self->db;
    my $apr                       = $self->apr;
    my $order_by                  = $apr->param('order_by') || 'evidence_type';
    my $feature_correspondence_id = $apr->param('feature_correspondence_id')
        or return $self->error('No feature correspondence id');
    my $accession_id              = $apr->param('accession_id') || 
        $feature_correspondence_id;
    my $is_enabled                = $apr->param('is_enabled')   || 0;

    $db->do(
        q[
            update cmap_feature_correspondence
            set    accession_id=?,
                   is_enabled=?
            where  feature_correspondence_id=?
        ],
        {},
        ( $accession_id, $is_enabled, $feature_correspondence_id )
    );

    return $self->redirect_home( 
        ADMIN_HOME_URI.'?action=feature_corr_view;'.
            "feature_correspondence_id=$feature_correspondence_id"
    ); 
}

# ----------------------------------------------------
sub feature_corr_view {
    my $self                      = shift;
    my $db                        = $self->db;
    my $apr                       = $self->apr;
    my $order_by                  = $apr->param('order_by') || 'evidence_type';
    my $feature_correspondence_id = $apr->param('feature_correspondence_id')
        or return $self->error('No feature correspondence id');

    my $sth = $db->prepare(
        q[
            select fc.feature_correspondence_id,
                   fc.accession_id,
                   fc.feature_id1,
                   fc.feature_id2,
                   fc.is_enabled
            from   cmap_feature_correspondence fc
            where  fc.feature_correspondence_id=?
        ]
    );
    $sth->execute( $feature_correspondence_id ); 
    my $corr = $sth->fetchrow_hashref or return $self->error(
        "No record for feature correspondence ID '$feature_correspondence_id'"
    );

    $sth = $db->prepare(
        q[
            select f.feature_id, 
                   f.accession_id, 
                   f.map_id,
                   f.feature_type_id,
                   f.feature_name,
                   f.alternate_name,
                   f.start_position,
                   f.stop_position,
                   ft.feature_type,
                   map.map_name,
                   ms.map_set_id,
                   ms.short_name as map_set_name,
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
        ]
    );
    $sth->execute( $corr->{'feature_id1'} );
    my $feature1 = $sth->fetchrow_hashref;
    $sth->execute( $corr->{'feature_id2'} );
    my $feature2 = $sth->fetchrow_hashref;

    $corr->{'evidence'} = $db->selectall_arrayref(
        qq[
            select   ce.correspondence_evidence_id,
                     ce.accession_id,
                     ce.feature_correspondence_id,
                     ce.evidence_type_id,
                     ce.score,
                     ce.remark,
                     et.evidence_type,
                     et.rank
            from     cmap_correspondence_evidence ce,
                     cmap_evidence_type et
            where    ce.feature_correspondence_id=?
            and      ce.evidence_type_id=et.evidence_type_id
            order by $order_by
        ],
        { Columns => {} },
        ( $feature_correspondence_id )
    );

    return $self->process_template(
        TEMPLATE->{'feature_corr_view'}, 
        {
            corr     => $corr,
            feature1 => $feature1,
            feature2 => $feature2,
        }
    );
}

# ----------------------------------------------------
sub corr_evidence_create {
    my ( $self, %args )           = @_;
    my $db                        = $self->db;
    my $apr                       = $self->apr;
    my $feature_correspondence_id = $apr->param('feature_correspondence_id') 
        or return $self->error('No feature correspondence id');

    my $sth = $db->prepare(
        q[
            select fc.feature_correspondence_id,
                   fc.accession_id,
                   fc.feature_id1,
                   fc.feature_id2,
                   f1.feature_name as feature_name1,
                   f2.feature_name as feature_name2
            from   cmap_feature_correspondence fc,
                   cmap_feature f1,
                   cmap_feature f2
            where  fc.feature_correspondence_id=?
            and    fc.feature_id1=f1.feature_id
            and    fc.feature_id2=f2.feature_id
        ]
    );
    $sth->execute( $feature_correspondence_id );
    my $corr = $sth->fetchrow_hashref or return $self->error(
        "No feature correspondence for ID '$feature_correspondence_id'"
    );

    my $evidence_types = $db->selectall_arrayref(
        q[
            select   et.evidence_type_id,
                     et.evidence_type,
                     et.rank
            from     cmap_evidence_type et
            order by et.rank
        ],
        { Columns => {} }
    );

    return $self->process_template( 
        TEMPLATE->{'corr_evidence_create'}, 
        {
            corr           => $corr,
            evidence_types => $evidence_types,
            errors         => $args{'errors'},
        }
    );
}

# ----------------------------------------------------
sub corr_evidence_edit {
    my ( $self, %args )            = @_;
    my $db                         = $self->db;
    my $apr                        = $self->apr;
    my $correspondence_evidence_id = $apr->param('correspondence_evidence_id')
        or die 'No correspondence evidence id';

    my $sth = $db->prepare(
        q[
            select ce.correspondence_evidence_id,
                   ce.accession_id,
                   ce.feature_correspondence_id,
                   ce.evidence_type_id,
                   ce.score,
                   ce.remark
            from   cmap_correspondence_evidence ce
            where  ce.correspondence_evidence_id=?
        ]
    );
    $sth->execute( $correspondence_evidence_id );
    my $corr = $sth->fetchrow_hashref or return $self->error(
        "No correspondence evidence for ID '$correspondence_evidence_id'"
    );

    my $evidence_types = $db->selectall_arrayref(
        q[
            select   et.evidence_type_id,
                     et.evidence_type,
                     et.rank
            from     cmap_evidence_type et
            order by rank, evidence_type
        ],
        { Columns => {} }
    );

    return $self->process_template( 
        TEMPLATE->{'corr_evidence_edit'},
        {
            corr           => $corr,
            evidence_types => $evidence_types,
            errors         => $args{'errors'},
        }
    );
}

# ----------------------------------------------------
sub corr_evidence_insert {
    my $self                      = shift;
    my @errors                    = ();
    my $db                        = $self->db;
    my $apr                       = $self->apr;
    my $feature_correspondence_id = $apr->param('feature_correspondence_id') 
        or push @errors, 'No feature correspondence id';
    my $evidence_type_id          = $apr->param('evidence_type_id') 
        or push @errors, 'No evidence type';
    my $score                     = $apr->param('score') || '';
    my $remark                    = $apr->param('remark') || '';

    my $correspondence_evidence_id = next_number(
        db               => $db, 
        table_name       => 'cmap_correspondence_evidence',
        id_field         => 'correspondence_evidence_id',
    ) or push @errors, 'No correspondence evidence id';

    return $self->corr_evidence_create( errors => \@errors ) if @errors;

    my $accession_id = $apr->param('accession_id') ||
        $correspondence_evidence_id;
    
    $db->do(
        q[
            insert
            into   cmap_correspondence_evidence
                   ( correspondence_evidence_id, accession_id, 
                     feature_correspondence_id, evidence_type_id,
                     score, remark )
            values ( ?, ?, ?, ?, ?, ? )
        ],
        {},
        ( $correspondence_evidence_id, $accession_id, 
          $feature_correspondence_id, $evidence_type_id,
          $score, $remark 
        )
    ); 

    return $self->redirect_home( 
        ADMIN_HOME_URI.'?action=feature_corr_view;'.
            "feature_correspondence_id=$feature_correspondence_id"
    ); 
}

# ----------------------------------------------------
sub corr_evidence_update {
    my $self                       = shift;
    my @errors                     = ();
    my $db                         = $self->db;
    my $apr                        = $self->apr;
    my $correspondence_evidence_id = $apr->param('correspondence_evidence_id') 
        or push @errors, 'No correspondence evidence id';
    my $accession_id               = $apr->param('accession_id')
        || $correspondence_evidence_id;
    my $feature_correspondence_id  = $apr->param('feature_correspondence_id') 
        or push @errors, 'No feature correspondence id';
    my $evidence_type_id           = $apr->param('evidence_type_id') 
        or push @errors, 'No evidence type';
    my $score                      = $apr->param('score') || '';
    my $remark                     = $apr->param('remark') || '';

    return $self->corr_evidence_edit( errors => \@errors ) if @errors;
    
    $db->do(
        q[
            update cmap_correspondence_evidence
            set    accession_id=?, feature_correspondence_id=?, 
                   evidence_type_id=?, score=?, remark=?
            where  correspondence_evidence_id=?
        ],
        {},
        ( $accession_id, $feature_correspondence_id, $evidence_type_id,
          $score, $remark, $correspondence_evidence_id
        )
    ); 

    return $self->redirect_home( 
        ADMIN_HOME_URI.'?action=feature_corr_view;'.
            "feature_correspondence_id=$feature_correspondence_id"
    ); 
}

# ----------------------------------------------------
sub feature_type_create {
    my ( $self, %args ) = @_;

    return $self->process_template( 
        TEMPLATE->{'feature_type_create'}, 
        {
            apr    => $self->apr,
            colors => $COLORS,
            shapes => $FEATURE_SHAPES,
            errors => $args{'errors'},
        }
    );
}

# ----------------------------------------------------
sub feature_type_edit {
    my ( $self, %args ) = @_;
    my $db              = $self->db;
    my $apr             = $self->apr;
    my $feature_type_id = $apr->param('feature_type_id') or 
                          die 'No feature type id';
    my $sth             = $db->prepare(
        q[
            select   accession_id,
                     feature_type_id, 
                     feature_type, 
                     shape, 
                     color,
                     drawing_lane,
                     drawing_priority
            from     cmap_feature_type
            where    feature_type_id=?
        ]
    );
    $sth->execute( $feature_type_id );
    my $feature_type = $sth->fetchrow_hashref or return $self->error(
        "No feature type for ID '$feature_type_id'"
    );

    return $self->process_template( 
        TEMPLATE->{'feature_type_edit'},
        { 
            feature_type => $feature_type,
            colors       => $COLORS,
            shapes       => $FEATURE_SHAPES,
            errors       => $args{'errors'},
        }
    );
}


# ----------------------------------------------------
sub feature_type_insert {
    my $self             = shift;
    my @errors           = ();
    my $db               = $self->db;
    my $apr              = $self->apr;
    my $feature_type     = $apr->param('feature_type') or 
                           push @errors, 'No feature type';
    my $shape            = $apr->param('shape')        or 
                           push @errors, 'No shape';
    my $color            = $apr->param('color')            || '';
    my $drawing_lane     = $apr->param('drawing_lane')     ||  1;
    my $drawing_priority = $apr->param('drawing_priority') ||  1;
    my $feature_type_id  = next_number(
        db               => $db, 
        table_name       => 'cmap_feature_type',
        id_field         => 'feature_type_id',
    ) or push @errors, 'No feature type id';
    my $accession_id     = $apr->param('accession_id') || $feature_type_id;

    return $self->feature_type_create( errors => \@errors ) if @errors;

    $db->do(
        q[ 
            insert
            into   cmap_feature_type 
                   ( accession_id, feature_type_id, feature_type, 
                     shape, color, drawing_lane, drawing_priority )
            values ( ?, ?, ?, ?, ?, ?, ? )
        ],
        {}, 
        ( $accession_id, $feature_type_id, $feature_type, 
          $shape, $color, $drawing_lane, $drawing_priority )
    );

    return $self->redirect_home( ADMIN_HOME_URI.'?action=feature_types_view' ); 
}

# ----------------------------------------------------
sub feature_type_update {
    my $self             = shift;
    my @errors           = ();
    my $db               = $self->db;
    my $apr              = $self->apr;
    my $accession_id     = $apr->param('accession_id')
        or push @errors, 'No accession id';
    my $shape            = $apr->param('shape')
        or push @errors, 'No shape';
    my $color            = $apr->param('color')            || '';
    my $drawing_lane     = $apr->param('drawing_lane')     || 1;
    my $drawing_priority = $apr->param('drawing_priority') || 1;
    my $feature_type_id  = $apr->param('feature_type_id') 
        or push @errors, 'No feature type id';
    my $feature_type     = $apr->param('feature_type')    
        or push @errors, 'No feature type';

    return $self->feature_type_edit( errors => \@errors ) if @errors;

    $db->do(
        q[ 
            update cmap_feature_type
            set    accession_id=?, 
                   feature_type=?, 
                   shape=?, 
                   color=?,
                   drawing_lane=?,
                   drawing_priority=?
            where  feature_type_id=?
        ],
        {}, 
        ( $accession_id, $feature_type, $shape, $color, 
          $drawing_lane, $drawing_priority, $feature_type_id 
        )
    );

    return $self->redirect_home( ADMIN_HOME_URI.'?action=feature_types_view' ); 
}

# ----------------------------------------------------
sub feature_types_view {
    my $self        = shift;
    my $db          = $self->db;
    my $apr         = $self->apr;
    my $order_by    = $apr->param('order_by')    || 'feature_type';
    my $limit_start = $apr->param('limit_start') ||              0;

    $order_by = 'drawing_lane,drawing_priority' if $order_by eq 'drawing_lane';

    my $feature_types = $db->selectall_arrayref(
        qq[
            select   accession_id, 
                     feature_type_id, 
                     feature_type, 
                     shape, 
                     color,
                     drawing_lane,
                     drawing_priority
            from     cmap_feature_type
            order by $order_by
        ], 
        { Columns => {} }
    );

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $pager       =  paginate( 
        self        => $self,
        data        => $feature_types,
        limit_start => $limit_start,
    );

    return $self->process_template( 
        TEMPLATE->{'feature_types_view'}, 
        { 
            feature_types => $pager->{'data'},
            no_elements   => $pager->{'no_elements'},
            page_size     => $pager->{'page_size'},
            pages         => $pager->{'pages'},
            cur_page      => $pager->{'cur_page'},
            show_start    => $pager->{'show_start'},
            show_stop     => $pager->{'show_stop'},
        }
    );
}

# ----------------------------------------------------
sub map_sets_view {
    my $self        = shift;
    my $db          = $self->db;
    my $apr         = $self->apr;
    my $map_type_id = $apr->param('map_type_id') || '';
    my $species_id  = $apr->param('species_id')  || '';
    my $is_enabled  = $apr->param('is_enabled');
    my $limit_start = $apr->param('limit_start') || 0;
    my $order_by    = $apr->param('order_by')    || 'species_name,short_name';

    unless ( $order_by eq 'map_set_name' ) {
        $order_by .= ',map_set_name';
    }

    my $sql = q[
        select   ms.map_set_id, ms.short_name as map_set_name, 
                 ms.accession_id, ms.is_enabled,
                 s.common_name as species_name,
                 mt.map_type
        from     cmap_map_set ms, 
                 cmap_species s, 
                 cmap_map_type mt
        where    ms.species_id=s.species_id
        and      ms.map_type_id=mt.map_type_id
    ];
    $sql .= qq[ and ms.map_type_id=$map_type_id ] if $map_type_id;
    $sql .= qq[ and ms.species_id=$species_id ]   if $species_id;
    $sql .= qq[ and ms.is_enabled=$is_enabled ]   if $is_enabled =~ m/^[01]$/;
    $sql .= qq[ order by $order_by ];

    my $map_sets = $db->selectall_arrayref( $sql, { Columns => {} } );

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $data        =  paginate( 
        self        => $self,
        data        => $map_sets,
        limit_start => $limit_start,
    );

    my $specie = $db->selectall_arrayref(
        q[
            select   distinct s.species_id, s.full_name, s.common_name
            from     cmap_species s,
                     cmap_map_set ms
            where    s.species_id=ms.species_id
            order by common_name
        ], { Columns => {} }
    );

    my $map_types = $db->selectall_arrayref(
        q[
            select   distinct mt.map_type_id, mt.map_type
            from     cmap_map_type mt,
                     cmap_map_set ms
            where    mt.map_type_id=ms.map_type_id
            order by map_type
        ], { Columns => {} }
    );

    return $self->process_template( 
        TEMPLATE->{'map_sets_view'}, 
        { 
            apr         => $apr,
            specie      => $specie,
            map_types   => $map_types,
            map_sets    => $data->{'data'},
            no_elements => $data->{'no_elements'},
            page_size   => $data->{'page_size'},
            pages       => $data->{'pages'},
            cur_page    => $data->{'cur_page'},
            show_start  => $data->{'show_start'},
            show_stop   => $data->{'show_stop'},
        }
    );
}

# ----------------------------------------------------
sub map_set_create {
    my ( $self, %args ) = @_;
    my $errors          = $args{'errors'};
    my $db              = $self->db;
    my $apr             = $self->apr;

    my $specie = $db->selectall_arrayref(
        q[
            select   s.species_id, s.full_name, s.common_name
            from     cmap_species s
            order by common_name
        ], { Columns => {} }
    );

    my $map_types = $db->selectall_arrayref(
        q[
            select   mt.map_type_id, mt.map_type
            from     cmap_map_type mt
            order by map_type
        ], { Columns => {} }
    );

    return $self->process_template( 
        TEMPLATE->{'map_set_create'},
        { 
            apr       => $apr,
            errors    => $errors,
            specie    => $specie,
            map_types => $map_types,
            colors    => $COLORS,
            shapes    => $MAP_SHAPES,
            widths    => $WIDTHS,
        }
    );
}

# ----------------------------------------------------
sub map_set_edit {
    my ( $self, %args ) = @_;
    my $errors          = $args{'errors'};
    my $db              = $self->db;
    my $apr             = $self->apr;
    my $map_set_id      = $apr->param('map_set_id') or die 'No map set ID';

    my $sth = $db->prepare(
        q[
            select    ms.map_set_id, ms.accession_id, ms.map_set_name,
                      ms.short_name, ms.display_order, ms.remarks,
                      ms.published_on, ms.can_be_reference_map,
                      ms.map_type_id, ms.species_id, ms.is_enabled,
                      ms.shape, ms.width, ms.color,
                      s.common_name as species_common_name,
                      s.full_name as species_full_name,
                      mt.map_type, mt.map_units,
                      mt.shape as default_shape,
                      mt.color as default_width, 
                      mt.width as default_color
            from      cmap_map_set ms, 
                      cmap_species s, 
                      cmap_map_type mt
            where     ms.species_id=s.species_id
            and       ms.map_type_id=mt.map_type_id
            and       ms.map_set_id=?
        ],
    );

    $sth->execute( $map_set_id );
    my $map_set = $sth->fetchrow_hashref or return $self->error(
        "No map set for ID '$map_set_id'"
    );

    my $specie = $db->selectall_arrayref(
        q[
            select   species_id, full_name, common_name
            from     cmap_species
            order by common_name
        ], { Columns => {} }
    );

    my $map_types = $db->selectall_arrayref(
        q[
            select   map_type_id, map_type, map_units
            from     cmap_map_type
            order by map_type
        ], { Columns => {} }
    );

    return $self->process_template( 
        TEMPLATE->{'map_set_edit'},
        { 
            map_set   => $map_set,
            specie    => $specie,
            map_types => $map_types,
            colors    => $COLORS,
            shapes    => $MAP_SHAPES,
            widths    => $WIDTHS,
            errors    => $errors,
        }
    );
}

# ----------------------------------------------------
sub map_set_insert {
    my $self                 = shift;
    my $db                   = $self->db;
    my $apr                  = $self->apr;
    my @errors               = ();
    my $map_set_name         = $apr->param('map_set_name')
        or push @errors, 'No map set name';
    my $short_name           = $apr->param('short_name')
        or push @errors, 'No short name';
    my $species_id           = $apr->param('species_id')
        or push @errors, 'No species';
    my $map_type_id          = $apr->param('map_type_id')
        or push @errors, 'No map type';
    my $accession_id         = $apr->param('accession_id')         || '';
    my $display_order        = $apr->param('display_order')        ||  1;
    my $can_be_reference_map = $apr->param('can_be_reference_map') ||  0;
    my $remarks              = $apr->param('remarks')              || '';
    my $shape                = $apr->param('shape')                || '';
    my $color                = $apr->param('color')                || '';
    my $width                = $apr->param('width')                ||  0;
    my $published_on         = $apr->param('published_on')  || localtime;

    if ( $published_on ) {{
        my $pub_date = parsedate($published_on, VALIDATE => 1)
            or do {
                push @errors, "Publication date '$published_on' is not valid";
                last;
            };
        my $t = localtime( $pub_date );
        $published_on = $t->strftime( $self->data_module->sql->date_format );
    }}

    return $self->map_set_create( errors => \@errors ) if @errors;

    my $map_set_id = next_number(
        db           => $db, 
        table_name   => 'cmap_map_set',
        id_field     => 'map_set_id',
    ) or die 'No map set id';
    $accession_id ||= $map_set_id;

    $db->do(
        q[
            insert
            into   cmap_map_set
                   ( map_set_id, accession_id, map_set_name, short_name,
                     species_id, map_type_id, published_on, display_order, 
                     can_be_reference_map, remarks, shape,
                     width, color
                   )
            values ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )
        ],
        {}, 
        ( 
            $map_set_id, $accession_id, $map_set_name, $short_name,
            $species_id, $map_type_id, $published_on, $display_order, 
            $can_be_reference_map, $remarks, $shape, 
            $width, $color
        )
    );

    return $self->redirect_home( 
        ADMIN_HOME_URI."?action=map_set_view;map_set_id=$map_set_id",
    );
}

# ----------------------------------------------------
sub map_set_view {
    my $self        = shift;
    my $db          = $self->db;
    my $apr         = $self->apr;
    my $map_set_id  = $apr->param('map_set_id') or die 'No map set id';
    my $limit_start = $apr->param('limit_start') || 0;

    my $sth = $db->prepare(
        q[
            select    ms.map_set_id, ms.accession_id, ms.map_set_name,
                      ms.short_name, ms.display_order, ms.published_on,
                      ms.remarks, ms.map_type_id, ms.species_id, 
                      ms.can_be_reference_map, ms.is_enabled,
                      ms.shape, ms.color, ms.width,
                      s.common_name as species_common_name,
                      s.full_name as species_full_name,
                      mt.map_type, mt.map_units,
                      mt.is_relational_map,
                      mt.shape as default_shape,
                      mt.color as default_color,
                      mt.width as default_width
            from      cmap_map_set ms, 
                      cmap_species s, 
                      cmap_map_type mt
            where     ms.species_id=s.species_id
            and       ms.map_type_id=mt.map_type_id
            and       ms.map_set_id=?
        ]
    );

    $sth->execute( $map_set_id );
    my $map_set = $sth->fetchrow_hashref or return $self->error(
        "No map set for ID '$map_set_id'"
    );
    my @maps = @{ 
        $db->selectall_arrayref( 
            q[
                select   map_id, accession_id, map_name, 
                         start_position, stop_position
                from     cmap_map
                where    map_set_id=?
                order by map_name
            ],
            { Columns => {} }, 
            ( $map_set_id ) 
        )
    };

    my $all_numbers = grep { $_->{ 'map_name' } =~ m/[0-9]/ } @maps;
    if ( $all_numbers == scalar @maps ) {
        @maps = 
            map  { $_->[0] }
            sort { $a->[1] <=> $b->[1] }
            map  { [$_, extract_numbers( $_->{ 'map_name' } )] }
            @maps
        ;
    }

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $data        =  paginate( 
        self        => $self,
        data        => \@maps,
        limit_start => $limit_start,
    );

    $map_set->{'maps'} = $data->{'data'};

    return $self->process_template( 
        TEMPLATE->{'map_set_view'}, 
        { 
            map_set     => $map_set,
            no_elements => $data->{'no_elements'},
            page_size   => $data->{'page_size'},
            pages       => $data->{'pages'},
            cur_page    => $data->{'cur_page'},
            show_start  => $data->{'show_start'},
            show_stop   => $data->{'show_stop'},
        }
    );
}

# ----------------------------------------------------
sub map_set_update {
    my $self                 = shift;
    my $db                   = $self->db;
    my $apr                  = $self->apr;
    my @errors               = ();
    my $map_set_id           = $apr->param('map_set_id')           ||  0;
    my $accession_id         = $apr->param('accession_id')         || '';
    my $map_set_name         = $apr->param('map_set_name')         || '';
    my $short_name           = $apr->param('short_name')           || '';
    my $species_id           = $apr->param('species_id')           ||  0;
    my $map_type_id          = $apr->param('map_type_id')          ||  0;
    my $can_be_reference_map = $apr->param('can_be_reference_map') ||  0;
    my $is_enabled           = $apr->param('is_enabled')           ||  0;
    my $display_order        = $apr->param('display_order')        ||  1;
    my $remarks              = $apr->param('remarks')              || '';
    my $shape                = $apr->param('shape')                || '';
    my $color                = $apr->param('color')                || '';
    my $width                = $apr->param('width')                ||  0;
    my $published_on         = $apr->param('published_on')  || localtime;

    if ( $published_on ) {{
        my $pub_date = parsedate($published_on, VALIDATE => 1)
            or do {
                push @errors, "Publication date '$published_on' is not valid";
                last;
            };
        my $t = localtime( $pub_date );
        $published_on = $t->strftime( $self->data_module->sql->date_format );
    }}

    return $self->map_set_edit( errors => \@errors ) if @errors;

    $db->do(
        q[
            update cmap_map_set
            set    accession_id=?, map_set_name=?, short_name=?,
                   species_id=?, map_type_id=?, published_on=?,
                   can_be_reference_map=?, display_order=?, 
                   remarks=?, is_enabled=?, shape=?,
                   color=?, width=?
            where  map_set_id=?
        ],
        {},
        (
            $accession_id, $map_set_name, $short_name, 
            $species_id, $map_type_id, $published_on, 
            $can_be_reference_map, $display_order, 
            $remarks, $is_enabled, $shape,
            $color, $width,
            $map_set_id
        )
    );

    return $self->redirect_home( 
        ADMIN_HOME_URI."?action=map_set_view;map_set_id=$map_set_id",
    )
}

# ----------------------------------------------------
sub redirect_home {
    my ( $self, $uri ) = @_;
    my $apr            = $self->apr;

    $apr->method_number( M_GET );
    $apr->method( 'GET' );
    $apr->headers_in->unset( 'Content-length' );
    $apr->headers_out->add( Location => $uri );
    $apr->status( REDIRECT );
    $apr->send_http_header;
    return DONE;
}

# ----------------------------------------------------
sub map_type_create {
    my ( $self, %args ) = @_;
    return $self->process_template( 
        TEMPLATE->{'map_type_create'},
        { 
            apr    => $self->apr,
            colors => $COLORS,
            shapes => $MAP_SHAPES,
            widths => $WIDTHS,
            errors => $args{'errors'},
        }
    );
}

# ----------------------------------------------------
sub map_type_edit {
    my ( $self, %args ) = @_;
    my $errors          = $args{'errors'};
    my $db              = $self->db;
    my $apr             = $self->apr;
    my $map_type_id     = $apr->param('map_type_id') or die 'No map type ID';
    my $sth             = $db->prepare(
        q[
            select   map_type_id, 
                     map_type, 
                     map_units, 
                     is_relational_map,
                     display_order,
                     shape, 
                     width, 
                     color
            from     cmap_map_type
            where    map_type_id=?
        ]
    );
    $sth->execute( $apr->param('map_type_id') );
    my $map_type = $sth->fetchrow_hashref or return $self->error(
        "No map type for ID '$map_type_id'"
    );

    return $self->process_template( 
        TEMPLATE->{'map_type_edit'},
        { 
            map_type => $map_type,
            colors   => $COLORS,
            shapes   => $MAP_SHAPES,
            widths   => $WIDTHS,
            errors   => $errors,
        }
    );
}

# ----------------------------------------------------
sub map_type_insert {
    my $self              = shift;
    my @errors            = ();
    my $db                = $self->db;
    my $apr               = $self->apr;
    my $map_type          = $apr->param('map_type')  
        or push @errors, 'No map type';
    my $map_units         = $apr->param('map_units') 
        or push @errors, 'No map units';
    my $shape             = $apr->param('shape')     
        or push @errors, 'No shape';
    my $width             = $apr->param('width')             || '';
    my $color             = $apr->param('color')             || '';
    my $display_order     = $apr->param('display_order')     || '';
    my $is_relational_map = $apr->param('is_relational_map') ||  0;
    my $map_type_id       = next_number(
        db                => $db, 
        table_name        => 'cmap_map_type',
        id_field          => 'map_type_id',
    ) or die 'No map type id';

    return $self->map_type_create( errors => \@errors ) if @errors;

    $db->do(
        q[ 
            insert
            into   cmap_map_type 
                   ( map_type_id, map_type, map_units, is_relational_map,
                     display_order, shape, width, color )
            values ( ?, ?, ?, ?, ?, ?, ?, ? )
        ],
        {}, 
        ( $map_type_id, $map_type, $map_units, $is_relational_map, 
          $display_order, $shape, $width, $color )
    );

    return $self->redirect_home( ADMIN_HOME_URI.'?action=map_types_view' ); 
}

# ----------------------------------------------------
sub map_type_update {
    my $self              = shift;
    my @errors            = ();
    my $db                = $self->db;
    my $apr               = $self->apr;
    my $map_type_id       = $apr->param('map_type_id') 
        or push @errors, 'No map type id';
    my $map_type          = $apr->param('map_type')    
        or push @errors, 'No map type';
    my $map_units         = $apr->param('map_units')   
        or push @errors, 'No map units';
    my $shape             = $apr->param('shape')       
        or push @errors, 'No shape';
    my $is_relational_map = $apr->param('is_relational_map') || 0;
    my $display_order     = $apr->param('display_order');
    my $width             = $apr->param('width') || '';
    my $color             = $apr->param('color') || '';

    return $self->map_type_edit( errors => \@errors ) if @errors;

    $db->do(
        q[ 
            update cmap_map_type
            set    map_type=?, 
                   map_units=?, 
                   is_relational_map=?, 
                   display_order=?, 
                   shape=?, 
                   width=?, 
                   color=?
            where  map_type_id=?
        ],
        {}, 
        ( $map_type, $map_units, $is_relational_map, $display_order,
          $shape, $width, $color, $map_type_id 
        )
    );

    return $self->redirect_home( ADMIN_HOME_URI.'?action=map_types_view' ); 
}

# ----------------------------------------------------
sub map_types_view {
    my $self        = shift;
    my $db          = $self->db;
    my $apr         = $self->apr;
    my $order_by    = $apr->param('order_by')    || 'map_type';
    my $limit_start = $apr->param('limit_start') ||          0;

    my $map_types = $db->selectall_arrayref(
        qq[
            select   map_type_id, 
                     map_type, 
                     map_units, 
                     is_relational_map, 
                     display_order, 
                     shape, 
                     width, 
                     color
            from     cmap_map_type
            order by $order_by
        ],
        { Columns => {} }
    );

    my $pager       =  paginate( 
        self        => $self,
        data        => $map_types,
        limit_start => $limit_start,
    );

    return $self->process_template( 
        TEMPLATE->{'map_types_view'},
        { 
            map_types   => $pager->{'data'},
            no_elements => $pager->{'no_elements'},
            page_size   => $pager->{'page_size'},
            pages       => $pager->{'pages'},
            cur_page    => $pager->{'cur_page'},
            show_start  => $pager->{'show_start'},
            show_stop   => $pager->{'show_stop'},
        }
    );
}

# ----------------------------------------------------
sub process_template {
    my ( $self, $template, $params ) = @_;

    my $output; 
    my $t = $self->template or return; 
    $t->process( $template, $params, \$output ) or $output = $t->error;

    my $apr = $self->apr;
    $apr->content_type('text/html');
    $apr->send_http_header;
    $apr->print( $output );
    return OK;
}

# ----------------------------------------------------
sub species_create {
    my ( $self, %args ) = @_;
    return $self->process_template( 
        TEMPLATE->{'species_create'},
        { errors => $args{'errors'} }
    );
}

# ----------------------------------------------------
sub species_edit {
    my ( $self, %args ) = @_;
    my $db              = $self->db;
    my $apr             = $self->apr;
    my $species_id      = $apr->param('species_id') or die 'No species_id';
    my $sth             = $db->prepare(
        q[
            select   accession_id,
                     species_id, 
                     common_name, 
                     full_name,
                     display_order, 
                     ncbi_taxon_id
            from     cmap_species
            where    species_id=?
        ]
    );
    $sth->execute( $species_id );
    my $species = $sth->fetchrow_hashref or return $self->error(
        "No species for ID '$species_id'"
    );

    return $self->process_template( 
        TEMPLATE->{'species_edit'},
        { 
            species => $species,
            errors  => $args{'errors'},
        } 
    );
}

# ----------------------------------------------------
sub species_insert {
    my $self          = shift;
    my @errors        = ();
    my $db            = $self->db;
    my $apr           = $self->apr;
    my $common_name   = $apr->param('common_name') or 
                        push @errors, 'No common name';
    my $full_name     = $apr->param('full_name')   or 
                        push @errors, 'No full name';
    my $display_order = $apr->param('display_order') || 1;
    my $ncbi_taxon_id = $apr->param('ncbi_taxon_id') || 1;
    my $species_id    = next_number(
        db            => $db, 
        table_name    => 'cmap_species',
        id_field      => 'species_id',
    ) or push @errors, "Can't get new species id";
    my $accession_id  = $apr->param('accession_id')  || $species_id;

    return $self->species_create( errors => \@errors ) if @errors;

    $db->do(
        q[ 
            insert
            into   cmap_species 
                   ( accession_id, species_id, full_name, common_name, 
                     display_order, ncbi_taxon_id
                   )
            values ( ?, ?, ?, ?, ?, ? )
        ],
        {}, 
        ( $accession_id, $species_id, $full_name, 
          $common_name, $display_order, $ncbi_taxon_id
        )
    );

    return $self->redirect_home( ADMIN_HOME_URI.'?action=species_view' ); 
}

# ----------------------------------------------------
sub species_update {
    my $self          = shift;
    my @errors        = ();
    my $db            = $self->db;
    my $apr           = $self->apr;
    my $accession_id  = $apr->param('accession_id') or 
                        push @errors, 'No accession id';
    my $species_id    = $apr->param('species_id')   or 
                        push @errors, 'No species id';
    my $common_name   = $apr->param('common_name')  or 
                        push @errors, 'No common name';
    my $full_name     = $apr->param('full_name')    or 
                        push @errors, 'No full name';
    my $display_order = $apr->param('display_order') || 1;
    my $ncbi_taxon_id = $apr->param('ncbi_taxon_id') || 1;

    return $self->species_edit( errors => \@errors ) if @errors;

    $db->do(
        q[ 
            update cmap_species
            set    accession_id=?,
                   common_name=?, 
                   full_name=?,
                   display_order=?,
                   ncbi_taxon_id=?
            where  species_id=?
        ],
        {}, 
        ( $accession_id, $common_name, $full_name, 
          $display_order, $ncbi_taxon_id, $species_id 
        )
    );

    return $self->redirect_home( ADMIN_HOME_URI.'?action=species_view' ); 
}

# ----------------------------------------------------
sub species_view {
    my $self        = shift;
    my $db          = $self->db;
    my $apr         = $self->apr;
    my $order_by    = $apr->param('order_by')    || 'common_name';
    my $limit_start = $apr->param('limit_start') ||             0;

    my $species = $db->selectall_arrayref(
        qq[
            select   accession_id, 
                     species_id, 
                     full_name, 
                     common_name,
                     display_order, 
                     ncbi_taxon_id
            from     cmap_species
            order by $order_by
        ],
        { Columns => {} }
    );

    my $pager       =  paginate( 
        self        => $self,
        data        => $species,
        limit_start => $limit_start,
    );

    return $self->process_template( 
        TEMPLATE->{'species_view'},
        { 
            species     => $pager->{'data'},
            no_elements => $pager->{'no_elements'},
            page_size   => $pager->{'page_size'},
            pages       => $pager->{'pages'},
            cur_page    => $pager->{'cur_page'},
            show_start  => $pager->{'show_start'},
            show_stop   => $pager->{'show_stop'},
        }
    );
}

1;

# ----------------------------------------------------
# All wholsome food is caught without a net or a trap.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::AdminViewer - curate comparative map data

=head1 SYNOPSIS

In httpd.conf:

  <Location /maps/admin>
      AuthType     Basic
      AuthName     "Map Curation"
      AuthUserFile /usr/local/apache/passwd/passwords
      Require      valid-user
      SetHandler   perl-script
      PerlHandler  Bio::GMOD::CMap::Admin
  </Location>

=head1 DESCRIPTION

This module is intended to provide a basic, web-based frontend for the
curation of the data for comparative maps.  As this time, it's fairly
limited to allowing the creation of new map sets, editing/deleting of
existing sets, and importing of data.  However, there are a couple
of scripts that must be run whenever new maps are imported (or
corrected) -- namely one that updates feature correspondences and one
that updates the precomputed "feature" table.  Currently,
these must be run by hand.

It is strongly recommended that this <Location> include at least basic
authentication.  This will require you to read up on the "htpasswd"
program.  Essentially, you should be able to run:

  # htpasswd -c /path/to/passwd/file

This will "create" (-c) the file given as the last argument, so don't
use this if the file already exists.  You will be prompted for a user
name and password to save into that file.  After you've created this
file and edited your server's configuration file, restart Apache.

=head1 SEE ALSO

L<perl>, htpasswd.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

Copyright (c) 2002 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
