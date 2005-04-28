package Bio::GMOD::CMap::Apache::AdminViewer;
# vim: set ft=perl:

# $Id: AdminViewer.pm,v 1.79 2005-04-28 21:49:23 mwz444 Exp $

use strict;
use Data::Dumper;
use Data::Pageset;
use Template;
use Time::Piece;
use Time::ParseDate;
use Text::ParseWords 'parse_line';

use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Admin;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Utils;
use Regexp::Common;

use base 'Bio::GMOD::CMap::Apache';

use constant ADMIN_HOME_URI => 'admin';

use vars qw( 
    $VERSION $COLORS $MAP_SHAPES $FEATURE_SHAPES $WIDTHS $LINE_STYLES
    $MAX_PAGES $PAGE_SIZE
);

$COLORS         = [ sort keys %{ +COLORS } ];
$FEATURE_SHAPES = [ qw( 
    box dumbbell line span up-arrow down-arrow double-arrow filled-box
    in-triangle out-triangle
) ];
$MAP_SHAPES     = [ qw( box dumbbell I-beam ) ];
$WIDTHS         = [ 1 .. 10 ];
$VERSION        = (qw$Revision: 1.79 $)[-1];

use constant TEMPLATE         => {
    admin_home                => 'admin_home.tmpl',
    attribute_create          => 'admin_attribute_create.tmpl',
    attribute_edit            => 'admin_attribute_edit.tmpl',
    confirm_delete            => 'admin_confirm_delete.tmpl',
    corr_evidence_create      => 'admin_corr_evidence_create.tmpl',
    corr_evidence_edit        => 'admin_corr_evidence_edit.tmpl',
    corr_evidence_types_view  => 'admin_corr_evidence_types_view.tmpl',
    corr_evidence_type_create => 'admin_corr_evidence_type_create.tmpl',
    corr_evidence_type_edit   => 'admin_corr_evidence_type_edit.tmpl',
    corr_evidence_type_view   => 'admin_corr_evidence_type_view.tmpl',
    colors_view               => 'admin_colors_view.tmpl',
    error                     => 'admin_error.tmpl',
    feature_alias_create      => 'admin_feature_alias_create.tmpl',
    feature_alias_edit        => 'admin_feature_alias_edit.tmpl',
    feature_alias_view        => 'admin_feature_alias_view.tmpl',
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
    feature_type_view         => 'admin_feature_type_view.tmpl',
    map_create                => 'admin_map_create.tmpl',
    map_edit                  => 'admin_map_edit.tmpl',
    map_view                  => 'admin_map_view.tmpl',
    map_sets_view             => 'admin_map_sets_view.tmpl',
    map_set_create            => 'admin_map_set_create.tmpl',
    map_set_edit              => 'admin_map_set_edit.tmpl',
    map_set_view              => 'admin_map_set_view.tmpl',
    map_type_edit             => 'admin_map_type_edit.tmpl',
    map_type_create           => 'admin_map_type_create.tmpl',
    map_type_view             => 'admin_map_type_view.tmpl',
    map_types_view            => 'admin_map_types_view.tmpl',
    species_edit              => 'admin_species_edit.tmpl',
    species_create            => 'admin_species_create.tmpl',
    species_view              => 'admin_species_view.tmpl',
    species_view_one          => 'admin_species_view_one.tmpl',
    xref_create               => 'admin_xref_create.tmpl',
    xref_edit                 => 'admin_xref_edit.tmpl',
    xrefs_view                => 'admin_xrefs_view.tmpl',
};

use constant XREF_OBJECTS     => [ 
    {
        table_name            => 'cmap_feature',
        object_name           => 'Feature',
        name_field            => 'feature_name',
    },
    {
        table_name            => 'cmap_feature_alias',
        object_name           => 'Feature Alias',
        name_field            => 'alias',
    },
    {
        table_name            => 'cmap_feature_correspondence',
        object_name           => 'Feature Correspondence',
        name_field            => 'accession_id',
    },
    {
        table_name            => 'cmap_map',
        object_name           => 'Map',
        name_field            => 'map_name',
    },
    {
        table_name            => 'cmap_map_set',
        object_name           => 'Map Set',
        name_field            => 'map_set_short_name',
    },
    {
        table_name            => 'cmap_species',
        object_name           => 'Species',
        name_field            => 'species_common_name',
    },
];

my %XREF_OBJ_LOOKUP = map { $_->{'table_name'}, $_ } @{ +XREF_OBJECTS };

# ----------------------------------------------------
sub handler {
#
# Make a jazz noise here...
#
    my ( $self, $apr ) = @_;

    $self->data_source( $apr->param('data_source') ) or return;

    $PAGE_SIZE ||= $self->config_data('max_child_elements') || 0;
    $MAX_PAGES ||= $self->config_data('max_search_pages')   || 1; 

    my $action = $apr->param('action') || 'admin_home';
    my $return = eval { $self->$action() };
    return $self->error( $@ ) if $@;
    return 1;
}

# ----------------------------------------------------
sub admin {
#
# Returns the "admin" object.
#
    my $self = shift;
    unless ( defined $self->{'admin'} ) {
        $self->{'admin'} =  Bio::GMOD::CMap::Admin->new(
            data_source  => $self->data_source,
	    config       => $self->config,
        );
    }
    return $self->{'admin'};
}

# ----------------------------------------------------
sub admin_home {
    my $self = shift;
    my $apr  = $self->apr;
    return $self->process_template( 
        TEMPLATE->{'admin_home'}, 
        { apr => $self->apr } 
    );
}

# ----------------------------------------------------
sub attribute_create {
    my ( $self, %args ) = @_;
    my $apr             = $self->apr;
    my $db              = $self->db;
    my $object_id       = $apr->param('object_id')  or die 'No object id';
    my $table_name      = $apr->param('table_name') or die 'No table name';
    my $object_type     = $table_name;
    $object_type        =~ s/^cmap_//;
    my $pk_name         =  $object_type;
    $pk_name           .=  '_id';

    return $self->process_template( 
        TEMPLATE->{'attribute_create'}, 
        {
            apr         => $apr,
            errors      => $args{'errors'},
            object_type => $object_type,
            pk_name     => $pk_name,
            object_id   => $object_id,
            table_name  => $table_name,
        }
    );
}

# ----------------------------------------------------
sub attribute_edit {
    my ( $self, %args ) = @_;
    my $apr             = $self->apr;
    my $db              = $self->db    or return;
    my $admin           = $self->admin or return;
    my $attribute_id    = $apr->param('attribute_id') or 
                          die 'No feature attribute id';

    my $sth = $db->prepare(
        q[
            select   attribute_id,
                     table_name,
                     object_id,
                     display_order,
                     is_public,
                     attribute_name,
                     attribute_value
            from     cmap_attribute
            where    attribute_id=?
        ]
    );
    $sth->execute( $attribute_id );
    my $attribute = $sth->fetchrow_hashref;

    my $object_id   =  $attribute->{'object_id'};
    my $table_name  =  $attribute->{'table_name'};
    my $object_type =  $table_name;
    $object_type    =~ s/^cmap_//;
    my $pk_name     =  $object_type;
    $pk_name       .=  '_id';

    unless ( $apr->param('return_action') ) {
        $apr->param( 'return_action', "${object_type}_view" );
    }

    $sth = $db->prepare("select * from $table_name where $pk_name=?");
    $sth->execute( $object_id );
    my $object = $sth->fetchrow_hashref;

    return $self->process_template( 
        TEMPLATE->{'attribute_edit'}, 
        {
            apr         => $apr,
            attribute   => $attribute,
            object      => $object,
            pk_name     => $pk_name,
            object_type => $object_type,
        }
    );
}

# ----------------------------------------------------
sub attribute_insert {
    my ( $self, %args ) = @_;
    my $apr             = $self->apr;
    my $db              = $self->db    or return;
    my $admin           = $self->admin or return;
    my @errors          = ();
    my $object_id       = $apr->param('object_id')   or 
                          push @errors, 'No object id';
    my $table_name      = $apr->param('table_name')  or 
                          push @errors, 'No table name';
    my $object_type     = $apr->param('object_type') or 
                          push @errors, 'No object type';
    my $pk_name         = $apr->param('pk_name')     or 
                          push @errors, 'No PK name';
    my $ret_action      = $apr->param('return_action') || "${object_type}_view";
    my $attribute_name  = $apr->param('attribute_name') or
                          push @errors, 'No attribute name';
    my $attribute_value = $apr->param('attribute_value') or
                          push @errors, 'No attribute value';
    my $display_order   = $apr->param('display_order') || 0;
    my $is_public       = $apr->param('is_public');

    $admin->set_attributes(
        object_id  => $object_id,
        table_name => $table_name,
        attributes => [
            { 
                name          => $attribute_name, 
                value         => $attribute_value,
                display_order => $display_order,
                is_public     => $is_public,
            },
        ],
    ) or return $self->error( $admin->error );

    return $self->redirect_home( 
        ADMIN_HOME_URI."?action=$ret_action;$pk_name=$object_id"
    );
}

# ----------------------------------------------------
sub attribute_update {
    my ( $self, %args ) = @_;
    my $apr             = $self->apr;
    my $db              = $self->db    or return;
    my $admin           = $self->admin or return;
    my @errors          = ();
    my $attribute_id    = $apr->param('attribute_id') or 
                          push @errors, 'No attribute id';
    my $attribute_name  = $apr->param('attribute_name') or 
                          push @errors, 'No attribute name';
    my $attribute_value = $apr->param('attribute_value') or 
                          push @errors, 'No attribute value';
    my $pk_name         = $apr->param('pk_name') or 
                          push @errors, 'No PK name';
    my $table_name      = $apr->param('table_name') or 
                          push @errors, 'No table name';
    my $object_id       = $apr->param('object_id') or 
                          push @errors, 'No object id';
    my $object_type     = $apr->param('object_type') or 
                          push @errors, 'No object type';
    my $display_order   = $apr->param('display_order') || 0;
    my $ret_action      = $apr->param('return_action') || "${object_type}_view";
    my $is_public       = $apr->param('is_public');

    return $self->attribute_edit(
        apr    => $apr,
        errors => \@errors,
    ) if @errors;

    $admin->set_attributes(
        object_id  => $object_id,
        table_name => $table_name,
        attributes => [
            { 
                attribute_id  => $attribute_id,
                name          => $attribute_name, 
                value         => $attribute_value,
                is_public     => $is_public,
                display_order => $display_order,
            },
        ],
    ) or return $self->error( $admin->error );

    return $self->redirect_home( 
        ADMIN_HOME_URI."?action=$ret_action;$pk_name=$object_id"
    );
}

# ----------------------------------------------------
sub confirm_delete {
    my $self        = shift;
    my $db          = $self->db or return $self->error;
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

    my $pk_name    = pk_name( $entity_type );
    my $object_id  = $entity_id;

    if ( $entity_type =~ m/^cmap_(attribute|xref)$/ ) {
        my $sth = $db->prepare(
            qq[
                select table_name, object_id
                from   $entity_type
                where  $pk_name=$object_id
            ]
        );
        $sth->execute;
        my $hr = $sth->fetchrow_hashref;

        $object_id = $hr->{'object_id'};
        $pk_name   = pk_name( $hr->{'table_name'} );
    }

    return $self->process_template( 
        TEMPLATE->{'confirm_delete'}, 
        { 
            apr           => $apr,
            return_action => $apr->param('return_action') || '',
            pk_name       => $pk_name,
            object_id     => $object_id,
            entity        => {
                id        => $entity_id,
                name      => $entity_name,
                type      => $entity_type, 
            },
        }
    );
}

# ----------------------------------------------------
sub colors_view {
    my $self        = shift;
    my $apr         = $self->apr;
    my $color_name  = lc $apr->param('color_name') || '';
    my $page_no     = $apr->param('page_no')       ||  1;
    my ( @colors, @errors );

    #
    # Find a particular color (or all matching if there's a splat).
    #
    if ( $color_name ) {
        my $orig_color_name = $color_name;
        if ( $color_name =~ s/\*//g ) {
            for my $color ( grep { /$color_name/ } @$COLORS ) {
                push @colors, {
                    name => $color,
                    hex  => join( '', @{ +COLORS->{ $color } } ),
                };
            }
            @errors = ( "No colors in palette match '$orig_color_name'" )
                unless @colors;
        }
        elsif ( exists COLORS->{ $color_name } ) {
            @colors  = ( {
                name => $color_name,
                hex  => join( '', @{ +COLORS->{ $color_name } } ),
            } );
        }
        else {
            @colors = ();
            @errors = ( "Color '$color_name' isn't in the palette" );
        }
    }
    else {
        @colors = map { 
            { 
                name => $_, 
                hex  => join( '', @{ +COLORS->{ $_ } } )
            } 
        }
        sort keys %{ +COLORS };
    }

    my $pager = Data::Pageset->new( {
        total_entries    => scalar @colors, 
        entries_per_page => $PAGE_SIZE,
        current_page     => $page_no,
        pages_per_set    => $MAX_PAGES,
    } );
    @colors = $pager->splice( \@colors ); 

    return $self->process_template( 
        TEMPLATE->{'colors_view'}, 
        { 
            apr         => $self->apr,
            colors      => \@colors,
            pager       => $pager,
            errors      => \@errors,
        }
    );
}

# ----------------------------------------------------
sub corr_evidence_type_create {
    return 0;
    ###Do this in Config
}

# ----------------------------------------------------
sub corr_evidence_type_insert {
    return 0;
    ###Do this in config
}

# ----------------------------------------------------
sub corr_evidence_type_edit {
    my ( $self, %args ) = @_;
    return 0;
    #Do this in Config file

}

# ----------------------------------------------------
sub corr_evidence_type_update {
    my ( $self, %args ) = @_;
    return 0;
    #Do this in Config file
}

# ----------------------------------------------------
sub corr_evidence_type_view {
    my ( $self, %args )  = @_;
    my $db               = $self->db or return $self->error;
    my $apr              = $self->apr;
    my $incoming_evidence_type_aid = $apr->param('evidence_type_aid') 
        or return $self->error('No evidence type');

    my $evidence_type =
       $self->evidence_type_data($incoming_evidence_type_aid)
       or return $self->error(
        "No evidence type accession '$incoming_evidence_type_aid'"
    );

    return $self->process_template( 
        TEMPLATE->{'corr_evidence_type_view'}, 
        { 
            evidence_type => $evidence_type,
        }
    );
}

# ----------------------------------------------------
sub corr_evidence_types_view {
    my $self        = shift;
    my $db          = $self->db or return $self->error;
    my $apr         = $self->apr;
    my $order_by    = $apr->param('order_by') || 'rank,evidence_type_aid';
    my $page_no     = $apr->param('page_no')  ||  1;


    my @evidence_type_aids = keys(%{$self->config_data('evidence_type')});
    my $evidence_types_hash;
    foreach my $type_aid (@evidence_type_aids){
        $evidence_types_hash->{$type_aid}=
            $self->evidence_type_data($type_aid)
             or return $self->error(
             "No evidence type accession '$type_aid'"
              );
    }

    my $evidence_types;
    foreach my $type_aid (keys(%{$evidence_types_hash})){
        $evidence_types_hash->{$type_aid}{'evidence_type_aid'}=$type_aid;
        push @$evidence_types,$evidence_types_hash->{$type_aid};
    }
    my $pager = Data::Pageset->new( {
        total_entries    => scalar @$evidence_types, 
        entries_per_page => $PAGE_SIZE,
        current_page     => $page_no,
        pages_per_set    => $MAX_PAGES,
    } );
    $evidence_types = 
        @$evidence_types ? [ $pager->splice( $evidence_types ) ] : [];

    return $self->process_template( 
        TEMPLATE->{'corr_evidence_types_view'}, 
        { 
            evidence_types => $evidence_types,
            pager          => $pager,
        }
    );
}

# ----------------------------------------------------
sub entity_delete {
    my $self          = shift;
    my $db            = $self->db or return $self->error;
    my $apr           = $self->apr;
    my $admin         = $self->admin;
    my $entity_type   = $apr->param('entity_type')   or die 'No entity type';
    my $entity_id     = $apr->param('entity_id')     or die 'No entity ID';
    my $return_action = $apr->param('return_action') || '';
    my $pk_name       = pk_name( $entity_type );
    my $uri_args      = $return_action && $pk_name && $entity_id ?
                        "?action=$return_action;$pk_name=$entity_id" : '';

    #
    # Map Set
    #
    if ( $entity_type eq 'cmap_map_set' ) {
        $admin->map_set_delete( map_set_id => $entity_id )
            or return $self->error( $admin->error );
        $uri_args ||= '?action=map_sets_view';
    }
    #
    # Species
    #
    elsif ( $entity_type eq 'cmap_species' ) {
        $admin->species_delete( species_id => $entity_id ) or
            return $self->error( $admin->error );
        $uri_args ||= '?action=species_view';
    }
    #
    # Feature Correspondence
    #
    elsif ( $entity_type eq 'cmap_feature_correspondence' ) {
        $admin->feature_correspondence_delete( 
            feature_correspondence_id => $entity_id 
        ) or return $self->error( $admin->error );
    }
    #
    # Attribute
    #
    elsif ( $entity_type eq 'cmap_attribute' ) {
        my $attribute_id = $apr->param('entity_id');
        my $sth          = $db->prepare( 
            q[
                select table_name, object_id
                from   cmap_attribute 
                where  attribute_id=?
            ],
        );
        $sth->execute( $attribute_id );
        my $attr        = $sth->fetchrow_hashref;
        my $object_id   = $attr->{'object_id'};
        my $object_type = $attr->{'table_name'};
        $object_type    =~ s/^cmap_//;
        my $pk_name     =  $object_type;
        $pk_name       .=  '_id';
        my $ret_action  = $apr->param('return_action') || "${object_type}_view";
        $uri_args       = "?action=$ret_action;$pk_name=$object_id";

        $db->do(
            'delete from cmap_attribute where attribute_id=?',
            {},
            ( $attribute_id )
        );
    }
    #
    # Feature
    #
    elsif ( $entity_type eq 'cmap_feature' ) {
        my $map_id = $admin->feature_delete(
            feature_id => $entity_id
        ) or return $self->error( $admin->error );
        $uri_args ||= "?action=map_view;map_id=$map_id";
    }
    #
    # Feature Alias
    #
    elsif ( $entity_type eq 'cmap_feature_alias' ) {
        my $feature_id = $db->selectrow_array(
            q[
                select feature_id
                from   cmap_feature_alias
                where  feature_alias_id=?
            ],
            {},
            ( $entity_id )
        ) or die "Can't find feature id";

        $db->do(
            q[
                delete
                from   cmap_feature_alias
                where  feature_alias_id=?
            ],
            {},
            ( $entity_id )
        );

        $uri_args = "?action=feature_view;feature_id=$feature_id";
    }
    #
    # Map
    #
    elsif ( $entity_type eq 'cmap_map' ) {
        my $map_set_id  = $admin->map_delete( 
            map_id      => $entity_id 
        ) or return $self->error( $admin->error );
        $uri_args = "?action=map_set_view;map_set_id=$map_set_id";
    }
    #
    # Correspondence evidence
    #
    elsif ( $entity_type eq 'cmap_correspondence_evidence' ) {
        my $feature_corr_id = $admin->correspondence_evidence_delete(
            correspondence_evidence_id => $entity_id 
        ) or return $self->error( $admin->error );

        $uri_args = 
        "?action=feature_corr_view;feature_correspondence_id=$feature_corr_id";
    }
    #
    # Cross-Reference
    #
    elsif ( $entity_type eq 'cmap_xref' ) {
        my $sth = $db->prepare( 
            q[
                select table_name, object_id
                from   cmap_xref 
                where  xref_id=?
            ],
        );
        $sth->execute( $entity_id );
        my $attr        = $sth->fetchrow_hashref;
        my $object_id   = $attr->{'object_id'};
        my $object_type = $attr->{'table_name'};
        $object_type    =~ s/^cmap_//;
        my $pk_name     =  $object_type;
        $pk_name       .=  '_id';

        if ( $return_action && $pk_name && $object_id ) {
            $uri_args = "?action=$return_action;$pk_name=$object_id";
        }
        else {
            $uri_args = '?action=xrefs_view';
        }

        $db->do(
            q[
                delete
                from   cmap_xref
                where  xref_id=?
            ], 
            {}, 
            ( $entity_id )
        );
    }
    #
    # Unknown
    #
    else {
        return $self->error(
            "You are not allowed to delete entities of type '$entity_type.'"
        );
    }

    $self->admin->attribute_delete( $entity_type, $entity_id );
    $self->admin->xref_delete     ( $entity_type, $entity_id );

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
    my $db              = $self->db or return $self->error;
    my $apr             = $self->apr;
    my $map_set_id      = $apr->param('map_set_id') or die 'No map set id';

    my $sth = $db->prepare(
        q[
            select ms.map_set_id, 
                   ms.map_set_short_name,
                   s.species_common_name
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
            apr     => $apr,
            map_set => $map_set,
            errors  => $args{'errors'},
        }
    );
}

# ----------------------------------------------------
sub map_edit {
    my ( $self, %args ) = @_;
    my $errors          = $args{'errors'};
    my $db              = $self->db or return $self->error;
    my $apr             = $self->apr;
    my $map_id          = $apr->param('map_id');
    my $sth             = $db->prepare(
        q[
            select map.map_id, 
                   map.accession_id as map_aid, 
                   map.map_name, 
                   map.display_order, 
                   map.start_position, 
                   map.stop_position,
                   ms.map_set_id, 
                   ms.map_set_name,
                   ms.map_type_accession as map_type_aid,
                   s.species_common_name
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
    my $self           =  shift;
    my $admin          =  $self->admin;
    my $apr            =  $self->apr;
    my $map_id         =  $admin->map_create(
        map_aid   => $apr->param('map_aid')  || '',
        display_order  => $apr->param('display_order') ||  1,
        map_name       => $apr->param('map_name')      || '',
        map_set_id     => $apr->param('map_set_id')    ||  0,
        start_position => defined $apr->param('start_position')
                          ? $apr->param('start_position') : undef,
        stop_position  => defined $apr->param('stop_position')
                          ? $apr->param('stop_position') : undef,
    ) or return $self->map_create( errors => $admin->error );

    return $self->redirect_home( 
        ADMIN_HOME_URI."?action=map_view;map_id=$map_id" 
    ); 
}

# ----------------------------------------------------
sub map_view {
    my $self            = shift;
    my $db              = $self->db or return $self->error;
    my $apr             = $self->apr;
    my $map_id          = $apr->param('map_id')          or die  'No map id';
    my $order_by        = $apr->param('order_by')        || 'start_position';
    my $feature_type_aid= $apr->param('feature_type_aid') ||            0;
    my $page_no         = $apr->param('page_no')         || 1;

    my $sth = $db->prepare(
        q[
            select map.map_id, 
                   map.accession_id as map_aid, 
                   map.map_name, 
                   map.display_order, 
                   map.start_position, 
                   map.stop_position,
                   ms.map_set_id, 
                   ms.map_set_short_name,
                   ms.map_type_accession as map_type_aid,
                   ms.map_units,
                   s.species_common_name,
                   s.species_full_name
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

    $map->{'map_type'}=$self->config_data('map_type')->{$map->{'map_type_aid'}}{'map_type'};

    $map->{'attributes'} = $self->sql->get_attributes(
        cmap_object => $self,
        object_name      => 'map',
        object_id   => $map_id,
        order_by    => $apr->param('att_order_by')
    );

    $map->{'xrefs'} = $self->sql->get_xrefs(
        cmap_object => $self,
        object_name      => 'map',
        object_id   => $map_id,
        order_by    => $apr->param('att_order_by')
    );

    my $sql = q[
        select   f.feature_id, 
                 f.accession_id as feature_aid, 
                 f.feature_name, 
                 f.map_id, 
                 f.start_position, 
                 f.stop_position, 
                 f.is_landmark,
                 f.feature_type_accession as feature_type_aid
        from     cmap_feature f 
        where    f.map_id=?
    ];
    $sql .= "and f.feature_type_accession='$feature_type_aid' " 
         if $feature_type_aid;
    $sql .= "order by $order_by ";

    my $features = $db->selectall_arrayref($sql, { Columns => {} }, ($map_id));

    for my $feature ( @$features ) {
        $feature->{'feature_type'}=$self->config_data('feature_type')->{$feature->{'feature_type_aid'}}{'feature_type'};
    }
    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $pager = Data::Pageset->new( {
        total_entries    => scalar @$features, 
        entries_per_page => $PAGE_SIZE,
        current_page     => $page_no,
        pages_per_set    => $MAX_PAGES,
    } );
    $map->{'features'} = @$features ? [ $pager->splice( $features ) ] : []; 

    my @feature_ids = map { $_->{'feature_id'} } @{ $map->{'features'} };
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

        for my $f ( @$features ) {
            $f->{'aliases'} = [
                sort { lc $a cmp lc $b } 
                @{ $aliases{ $f->{'feature_id'} } || [] }
            ];
        }
    }

    for my $feature ( @{ $map->{'features'} } ) {
        $feature->{'no_correspondences'} = $db->selectrow_array(
            q[
                select count(fc.feature_correspondence_id)
                from   cmap_correspondence_lookup cl,
                       cmap_feature_correspondence fc
                where  cl.feature_id1=?
                and    cl.feature_correspondence_id=
                       fc.feature_correspondence_id
            ],
            {},
            ( $feature->{'feature_id'} )
        );
    }

    my $feature_type_aids_array = $db->selectall_arrayref(
        q[
            select   distinct f.feature_type_accession as feature_type_aid
            from     cmap_feature f
            where    f.map_id=?
            order by feature_type_aid
        ],
        {Columns => {}},
        ( $map_id )
    );
    my @feature_type_aids = map{$_->{'feature_type_aid'}} @$feature_type_aids_array;
print STDERR Dumper(\@feature_type_aids)."\n";
    my %feature_type_name_lookup;
    foreach my $ft_aid (@feature_type_aids){
        $feature_type_name_lookup{$ft_aid}=$self->config_data('feature_type')->{$ft_aid}{'feature_type'};
    }


    return $self->process_template( 
        TEMPLATE->{'map_view'},
        { 
            apr           => $apr,
            map           => $map,
            feature_type_aids => \@feature_type_aids,
            feature_type_name_lookup => \%feature_type_name_lookup,
            pager         => $pager,
        }
    );
}

# ----------------------------------------------------
sub map_update {
    my $self           = shift;
    my $db             = $self->db or return $self->error;
    my $apr            = $self->apr;
    my @errors         = ();
    my $map_id         = $apr->param('map_id')         
        or push @errors, 'No map id';
    my $map_aid   = $apr->param('map_aid')   
        or push @errors, 'No accession id';
    my $display_order  = $apr->param('display_order') || 1;
    my $map_name       = $apr->param('map_name');
    push @errors, 'No map name' unless defined $map_name && $map_name ne '';
    my $start_position = $apr->param('start_position');
    push @errors, 'No start position' unless defined $start_position;
    my $stop_position  = $apr->param('stop_position')  
        or push @errors, 'No stop';

    return $self->map_edit( errors => \@errors ) if @errors;

    my $sql = q[
        update cmap_map
        set    accession_id=?, 
               map_name=?, 
               display_order=?, 
               start_position=?,
               stop_position=?
        where  map_id=?
    ];
    
    $db->do( 
        $sql, 
        {}, 
        ( $map_aid, $map_name, $display_order, 
          $start_position, $stop_position, $map_id 
        ) 
    );

    return $self->redirect_home( 
        ADMIN_HOME_URI."?action=map_view;map_id=$map_id" 
    ); 
}

# ----------------------------------------------------
sub feature_alias_create {
    my ( $self, %args ) = @_;
    my $apr             = $self->apr;
    my $feature_id      = $apr->param('feature_id') or die 'No feature ID';
    my $db              = $self->db;
    my $sth             = $db->prepare(
        q[
            select feature_id, feature_name
            from   cmap_feature
            where  feature_id=?
        ]
    );
    $sth->execute( $feature_id );
    my $feature = $sth->fetchrow_hashref;

    return $self->process_template( 
        TEMPLATE->{'feature_alias_create'}, 
        {
            apr     => $apr,
            feature => $feature,
            errors  => $args{'errors'},
        }
    );
}

# ----------------------------------------------------
sub feature_alias_edit {
    my ( $self, %args )  = @_;
    my $apr              = $self->apr;
    my $feature_alias_id = $apr->param('feature_alias_id') or 
                           die 'No feature alias id';

    my $db    = $self->db;
    my $sth   = $db->prepare(
        q[
            select fa.feature_alias_id,
                   fa.feature_id, 
                   fa.alias, 
                   f.feature_name
            from   cmap_feature_alias fa,
                   cmap_feature f
            where  fa.feature_alias_id=?
            and    fa.feature_id=f.feature_id
        ]
    );
    $sth->execute( $feature_alias_id );
    my $alias = $sth->fetchrow_hashref;

    return $self->process_template( 
        TEMPLATE->{'feature_alias_edit'}, 
        {
            apr    => $apr,
            alias  => $alias,
            errors => $args{'errors'},
        }
    );
}

# ----------------------------------------------------
sub feature_alias_insert {
    my $self       = shift;
    my $apr        = $self->apr;
    my $admin      = $self->admin;
    my $feature_id = $apr->param('feature_id') || 0;

    $admin->feature_alias_create(
        feature_id => $feature_id,
        alias      => $apr->param('alias')      || '',
    ) or return $self->feature_alias_create( errors => [ $admin->error ] );
    
    return $self->redirect_home( 
        ADMIN_HOME_URI."?action=feature_view;feature_id=$feature_id" 
    ); 
}

# ----------------------------------------------------
sub feature_alias_update {
    my $self             = shift;
    my $apr              = $self->apr;
    my $feature_alias_id = $apr->param('feature_alias_id') or 
                           die 'No feature alias id';
    my $alias            = $apr->param('alias') or die 'No alias';
    my $db               = $self->db;

    $db->do(
        q[
            update cmap_feature_alias
            set    alias=?
            where  feature_alias_id=?
        ],
        {},
        ( $alias, $feature_alias_id )
    );
    
    return $self->redirect_home( 
        ADMIN_HOME_URI.
        "?action=feature_alias_view;feature_alias_id=$feature_alias_id" 
    ); 
}

# ----------------------------------------------------
sub feature_alias_view {
    my $self             = shift;
    my $apr              = $self->apr;
    my $feature_alias_id = $apr->param('feature_alias_id') or 
                           die 'No feature alias id';

    my $db    = $self->db;
    my $sth   = $db->prepare(
        q[
            select fa.feature_alias_id,
                   fa.feature_id, 
                   fa.alias, 
                   f.feature_name
            from   cmap_feature_alias fa,
                   cmap_feature f
            where  fa.feature_alias_id=?
            and    fa.feature_id=f.feature_id
        ]
    );
    $sth->execute( $feature_alias_id );
    my $alias = $sth->fetchrow_hashref;

    $alias->{'attributes'} = $self->sql->get_attributes(
        cmap_object => $self,
        object_name      => 'cmap_feature_alias',
        object_id   => $feature_alias_id,
    );

    $alias->{'xrefs'} = $self->sql->get_xrefs(
        cmap_object => $self,
        object_name      => 'cmap_feature_alias',
        object_id   => $feature_alias_id,
    );

    return $self->process_template( 
        TEMPLATE->{'feature_alias_view'}, 
        {
            apr   => $apr,
            alias => $alias,
        }
    );
}

# ----------------------------------------------------
sub feature_create {
    my ( $self, %args ) = @_;
    my $db              = $self->db or return $self->error;
    my $apr             = $self->apr;
    my $map_id          = $apr->param('map_id') or die 'No map id';

    my $sth = $db->prepare(
        q[
            select map.map_id, 
                   map.map_name,
                   ms.map_set_short_name,
                   s.species_common_name
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

    my @feature_type_aids = keys(%{$self->feature_type_data()});
    my %feature_type_name_lookup;
    foreach my $ft_aid (@feature_type_aids){
        $feature_type_name_lookup{$ft_aid}=$self->config_data('feature_type')->{$ft_aid}{'feature_type'};
    }
    return $self->process_template(
        TEMPLATE->{'feature_create'}, 
        { 
            apr           => $apr,
            map           => $map,
            feature_type_aids => \@feature_type_aids,
            feature_type_name_lookup => \%feature_type_name_lookup,
            errors        => $args{'errors'},
        }
    );
}

# ----------------------------------------------------
sub feature_edit {
    my ( $self, %args ) = @_;
    my $db              = $self->db or return $self->error;
    my $apr             = $self->apr;
    my $feature_id      = $apr->param('feature_id') or die 'No feature id';

    my $sth = $db->prepare(
        q[
            select     f.feature_id,
                       f.accession_id as feature_aid,
                       f.map_id,
                       f.feature_type_accession as feature_type_aid,
                       f.feature_name,
                       f.start_position,
                       f.stop_position,
                       f.is_landmark,
                       map.map_name,
                       ms.map_set_short_name,
                       s.species_common_name
            from       cmap_feature f
            inner join cmap_map map
            on         f.map_id=map.map_id
            inner join cmap_map_set ms
            on         map.map_set_id=ms.map_set_id
            inner join cmap_species s
            on         ms.species_id=s.species_id
            where      f.feature_id=?
        ]
    );
    $sth->execute( $feature_id );
    my $feature = $sth->fetchrow_hashref or return $self->error(
        "No feature for ID '$feature_id'"
    );

    my @feature_type_aids = keys(%{$self->feature_type_data()});

    my %feature_type_name_lookup;
    foreach my $ft_aid (@feature_type_aids){
        $feature_type_name_lookup{$ft_aid}=$self->config_data('feature_type')->{$ft_aid}{'feature_type'};
    }
    return $self->process_template(
        TEMPLATE->{'feature_edit'},
        { 
            feature       => $feature,
            feature_type_aids => \@feature_type_aids,
            errors        => $args{'errors'},
            feature_type_name_lookup => \%feature_type_name_lookup,
        }, 
    );
}

# ----------------------------------------------------
sub feature_insert {
    my $self            = shift;
    my $admin           = $self->admin;
    my $apr             = $self->apr;
    my $feature_id      = $admin->feature_create(
        map_id          => $apr->param('map_id')          ||  0,
        feature_aid    => $apr->param('feature_aid')    || '',
        feature_name    => $apr->param('feature_name')    || '',
        feature_type_aid    => $apr->param('feature_type_aid') ||  0,
        is_landmark     => $apr->param('is_landmark')     ||  0,
        start_position  => $apr->param('start_position')  ||  0,
        stop_position   => $apr->param('stop_position')
    ) or return $self->feature_create( errors => $admin->error );

    return $self->redirect_home( 
        ADMIN_HOME_URI.'?action=map_view;map_id='.$apr->param('map_id')
    ); 
}

# ----------------------------------------------------
sub feature_update {
    my $self            = shift;
    my @errors          = ();
    my $db              = $self->db or return $self->error;
    my $apr             = $self->apr;
    my $feature_id      = $apr->param('feature_id')   or 
                          push @errors, 'No feature id';
    my $feature_aid    = $apr->param('feature_aid') or 
                          push @errors, 'No accession id';
    my $feature_name    = $apr->param('feature_name') or 
                          push @errors, 'No feature name';
    my $feature_type_aid = $apr->param('feature_type_aid') 
                          or die 'No feature type';
    my $is_landmark     = $apr->param('is_landmark') || 0;
    my $start_position  = $apr->param('start_position');
    push @errors, "No start" unless $start_position =~ /^$RE{'num'}{'real'}$/;
    my $stop_position   = $apr->param('stop_position');

    return $self->feature_edit( errors => \@errors ) if @errors;

    my $sql = q[
        update cmap_feature
        set    accession_id=?, feature_name=?, 
               feature_type_accession=?, is_landmark=?, start_position=?
    ];
    $sql .= ", stop_position=$stop_position " if $stop_position =~ /^$RE{'num'}{'real'}$/; 
    $sql .= 'where  feature_id=?';
    $db->do(
        $sql,
        {},
        ( $feature_aid, $feature_name, 
          $feature_type_aid, $is_landmark, $start_position, $feature_id )
    );

    return $self->redirect_home( 
        ADMIN_HOME_URI."?action=feature_view;feature_id=$feature_id" 
    ); 
}

# ----------------------------------------------------
sub feature_view {
    my $self       = shift;
    my $db         = $self->db or return $self->error;
    my $apr        = $self->apr;
    my $feature_id = $apr->param('feature_id') or die 'No feature id';
    my $order_by   = $apr->param('order_by') || '';

    my $sth = $db->prepare(
        q[
            select     f.feature_id, 
                       f.accession_id as feature_aid, 
                       f.map_id,
                       f.feature_type_accession as feature_type_aid,
                       f.feature_name,
                       f.is_landmark,
                       f.start_position,
                       f.stop_position,
                       map.map_name,
                       ms.map_set_short_name,
                       s.species_common_name
            from       cmap_feature f
            inner join cmap_map map
            on         f.map_id=map.map_id
            inner join cmap_map_set ms
            on         map.map_set_id=ms.map_set_id
            inner join cmap_species s
            on         ms.species_id=s.species_id
            where      f.feature_id=?
        ]
    );
    $sth->execute( $feature_id );
    my $feature = $sth->fetchrow_hashref or return $self->error(
        "No feature for ID '$feature_id'"
    );

    $feature->{'feature_type'}=$self->config_data('feature_type')->{$feature->{'feature_type_aid'}}{'feature_type'};
    $feature->{'aliases'}    = $self->admin->get_aliases( $feature_id );
    $feature->{'attributes'} = $self->sql->get_attributes(
        cmap_object => $self,
        object_name      => 'feature',
        object_id   => $feature_id,
        order_by    => $apr->param('att_order_by'),
    );

    $feature->{'xrefs'} = $self->sql->get_xrefs(
        cmap_object => $self,
        object_name      => 'feature',
        object_id   => $feature_id,
        order_by    => $apr->param('att_order_by'),
    );

    my $correspondences = $db->selectall_arrayref(
        q[
            select fc.feature_correspondence_id,
                   fc.accession_id as feature_correspondence_aid,
                   fc.feature_id1,
                   fc.feature_id2,
                   fc.is_enabled,
                   f.feature_id,
                   f.feature_name as feature_name,
                   map.map_id,
                   map.map_name,
                   ms.map_set_short_name,
                   s.species_common_name
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
                    select   ce.evidence_type_accession as evidence_type_aid
                    from     cmap_correspondence_evidence ce
                    where    ce.feature_correspondence_id=?
                    order by ce.rank
                ],
                {},
                ( $corr->{'feature_correspondence_id'} )
            )
        } );

        $corr->{'aliases'} = [
            map { $_->{'alias'} }
            @{ $self->admin->get_aliases( $corr->{'feature_id'} ) }
        ];
    }
    
    $feature->{'correspondences'} = $correspondences;

    return $self->process_template(
        TEMPLATE->{'feature_view'}, 
        { feature => $feature }
    );
}

# ----------------------------------------------------
sub feature_search {
    my $self             = shift;
    my $db               = $self->db or return $self->error;
    my $apr              = $self->apr;
    my $admin            = $self->admin;
    my $page_no          = $apr->param('page_no')           ||    1;
    my @species_ids      = ( $apr->param('species_id')      || () );
    my @feature_type_aids = ( $apr->param('feature_type_aid') || () );

    my @all_feature_type_aids = keys(%{$self->config_data('feature_type')});
    my %feature_type_name_lookup;
    foreach my $ft_aid (@all_feature_type_aids){
        $feature_type_name_lookup{$ft_aid}=$self->config_data('feature_type')->{$ft_aid}{'feature_type'};
    }

    my $params              = {
        apr                 => $apr,
        species             => $admin->species,
        feature_type_aids   => \@all_feature_type_aids,
        species_lookup      => { map { $_, 1 } @species_ids },
        feature_type_aid_lookup  => { map { $_, 1 } @feature_type_aids },
        feature_type_name_lookup => \%feature_type_name_lookup,
    }; 

    #
    # If given a feature to search for ...
    #
    if ( my $feature_name    = $apr->param('feature_name') ) {
        my $result           =  $admin->feature_search(
            feature_name     => $feature_name,
            search_field     => $apr->param('search_field')    || '',
            map_aid          => $apr->param('map_aid')         ||  0,
            species_ids      => \@species_ids,
            feature_type_aids => \@feature_type_aids,
            order_by         => $apr->param('order_by')        || '', 
            entries_per_page => $PAGE_SIZE,
            current_page     => $page_no,
            pages_per_set    => $MAX_PAGES,
        );

        $params->{'pager'}    = $result->{'pager'};
        $params->{'features'} = $result->{'results'};
    }

    return $self->process_template( TEMPLATE->{'feature_search'}, $params );
}

# ----------------------------------------------------
sub feature_corr_create {
    my ( $self, %args ) = @_;
    my $db              = $self->db or return $self->error;
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
                   ms.map_set_short_name,
                   s.species_id,
                   s.species_common_name
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
        $feature2_name  =~ s/['"]//g; #'
        my $search_term =  uc $feature2_name;
        my $sql         =  qq[
            select f.feature_id,
                   f.feature_name,
                   map.map_id,
                   map.map_name,
                   ms.map_set_short_name,
                   s.species_id,
                   s.species_common_name
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
                     s.species_common_name,
                     s.species_full_name
            from     cmap_species s
            order by species_common_name
        ],
        { Columns => {} }
    );

    my @evidence_type_aids = keys(%{$self->config_data('evidence_type')});
    my $evidence_types;
    foreach my $type_aid (@evidence_type_aids){
        push @$evidence_types,
            $self->evidence_type_data($type_aid)
             or return $self->error(
             "No evidence type accession '$type_aid'"
              );
    }

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
    my $feature_correspondence_aid     = $apr->param('feature_correspondence_aid') || '';
    my $is_enabled       = $apr->param('is_enabled')   ||  0;
    my $evidence_type_aid = $apr->param('evidence_type_aid') or push @errors,
        'Please select an evidence type';

    push @errors, 
        "Can't create a circular correspondence (feature IDs are the same)"
        if $feature_id1 == $feature_id2;

    return $self->feature_corr_create( errors => \@errors ) if @errors;

    my $feature_correspondence_id =  $admin->feature_correspondence_create(
        feature_id1               => $feature_id1, 
        feature_id2               => $feature_id2, 
        evidence_type_aid             => $evidence_type_aid, 
        feature_correspondence_aid              => $feature_correspondence_aid, 
        is_enabled                => $is_enabled
    );

    if ( $feature_correspondence_id < 0 ) {
        my $db = $self->db or return;
        $feature_correspondence_id = $db->selectrow_array(
            q[
                select feature_correspondence_id
                from   cmap_correspondence_lookup
                where  feature_id1=?
                and    feature_id2=?
            ],
            {},
            ( $feature_id1, $feature_id2 )
        );
    }

    return $self->redirect_home( 
        ADMIN_HOME_URI.'?action=feature_corr_view;'.
            "feature_correspondence_id=$feature_correspondence_id"
    ); 
}

# ----------------------------------------------------
sub feature_corr_edit {
    my $self                      = shift;
    my $db                        = $self->db or return $self->error;
    my $apr                       = $self->apr;
    my $feature_correspondence_id = $apr->param('feature_correspondence_id')
        or return $self->error('No feature correspondence id');

    my $sth = $db->prepare(
        q[
            select fc.feature_correspondence_id,
                   fc.accession_id as feature_correspondence_aid,
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
    my $db                        = $self->db or return $self->error;
    my $apr                       = $self->apr;
    my $order_by                  = $apr->param('order_by') 
                                    || 'evidence_type_aid';
    my $feature_correspondence_id = $apr->param('feature_correspondence_id')
        or return $self->error('No feature correspondence id');
    my $feature_correspondence_aid              = $apr->param('feature_correspondence_aid') || 
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
        ( $feature_correspondence_aid, $is_enabled, $feature_correspondence_id )
    );

    return $self->redirect_home( 
        ADMIN_HOME_URI.'?action=feature_corr_view;'.
            "feature_correspondence_id=$feature_correspondence_id"
    ); 
}

# ----------------------------------------------------
sub feature_corr_view {
    my $self                      = shift;
    my $db                        = $self->db or return $self->error;
    my $sql_object                = $self->sql or return $self->error;
    my $apr                       = $self->apr;
    my $order_by                  = $apr->param('order_by') 
                                    || 'evidence_type_aid';
    my $feature_correspondence_id = $apr->param('feature_correspondence_id')
        or return $self->error('No feature correspondence id');

    my $corr = $sql_object->get_correspondences(
        cmap_object => $self,
        feature_correspondence_id => $feature_correspondence_id,
    )
      or return $sql_object->error();

#    my $sth = $db->prepare(
#        q[
#            select fc.feature_correspondence_id,
#                   fc.accession_id as feature_correspondence_aid,
#                   fc.feature_id1,
#                   fc.feature_id2,
#                   fc.is_enabled
#            from   cmap_feature_correspondence fc
#            where  fc.feature_correspondence_id=?
#        ]
#    );
#    $sth->execute( $feature_correspondence_id ); 
#    my $corr = $sth->fetchrow_hashref or return $self->error(
#        "No record for feature correspondence ID '$feature_correspondence_id'"
#    );

    $corr->{'attributes'} = $sql_object->get_attributes(
        cmap_object => $self,
        object_name      => 'feature_correspondence',
        object_id   => $feature_correspondence_id,
        order_by    => $apr->param('att_order_by'),
    );

    $corr->{'xrefs'} = $sql_object->get_xrefs(
        cmap_object => $self,
        object_name      => 'feature_correspondence',
        object_id   => $feature_correspondence_id,
        order_by    => $apr->param('att_order_by'),
    );

    my $feature1 = $sql_object->get_feature_details(
        cmap_object => $self,
        feature_id => $corr->{'feature_id1'},
    );
    $feature1 = $feature1->[0] if $feature1;

    my $feature2 = $sql_object->get_feature_details(
        cmap_object => $self,
        feature_id => $corr->{'feature_id2'},
    );
    $feature2 = $feature2->[0] if $feature2;

    $corr->{'evidence'} = $db->selectall_arrayref(
        qq[
            select   ce.correspondence_evidence_id,
                     ce.accession_id as correspondence_evidence_aid,
                     ce.feature_correspondence_id,
                     ce.evidence_type_accession as evidence_type_aid,
                     ce.score,
                     ce.rank
            from     cmap_correspondence_evidence ce
            where    ce.feature_correspondence_id=?
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
    my $db                        = $self->db or return $self->error;
    my $apr                       = $self->apr;
    my $feature_correspondence_id = $apr->param('feature_correspondence_id') 
        or return $self->error('No feature correspondence id');

    my $sth = $db->prepare(
        q[
            select fc.feature_correspondence_id,
                   fc.accession_id as feature_correspondence_aid,
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

    my @evidence_type_aids = keys(%{$self->config_data('evidence_type')});
    my $evidence_types;
    foreach my $type_aid (@evidence_type_aids){
        push @$evidence_types,
            $self->evidence_type_data($type_aid)
             or return $self->error(
             "No evidence type accession '$type_aid'"
              );
    }

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
    my $db                         = $self->db or return $self->error;
    my $apr                        = $self->apr;
    my $correspondence_evidence_id = $apr->param('correspondence_evidence_id')
        or die 'No correspondence evidence id';

    my $sth = $db->prepare(
        q[
            select ce.correspondence_evidence_id,
                   ce.accession_id as correspondence_evidence_aid,
                   ce.feature_correspondence_id,
                   ce.evidence_type_accession as evidence_type_aid,
                   ce.score
            from   cmap_correspondence_evidence ce
            where  ce.correspondence_evidence_id=?
        ]
    );
    $sth->execute( $correspondence_evidence_id );
    my $corr = $sth->fetchrow_hashref or return $self->error(
        "No correspondence evidence for ID '$correspondence_evidence_id'"
    );

    my @evidence_type_aids = keys(%{$self->config_data('evidence_type')});
    my $evidence_types;
    foreach my $type_aid (@evidence_type_aids){
        push @$evidence_types,
            $self->evidence_type_data($type_aid)
             or return $self->error(
             "No evidence type accession '$type_aid'"
              );
    }

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
    my $db                        = $self->db or return $self->error;
    my $apr                       = $self->apr;
    my $feature_correspondence_id = $apr->param('feature_correspondence_id') 
        or push @errors, 'No feature correspondence id';
    my $evidence_type_aid          = $apr->param('evidence_type_aid') 
        or push @errors, 'No evidence type';
    my $score                     = $apr->param('score') || '';

    my $correspondence_evidence_id = next_number(
        db               => $db, 
        table_name       => 'cmap_correspondence_evidence',
        id_field         => 'correspondence_evidence_id',
    ) or push @errors, 'No correspondence evidence id';

    return $self->corr_evidence_create( errors => \@errors ) if @errors;

    my $correspondence_evidence_aid = $apr->param('correspondence_evidence_aid') ||
        $correspondence_evidence_id;
    
    $db->do(
        q[
            insert
            into   cmap_correspondence_evidence
                   ( correspondence_evidence_id, accession_id, 
                     feature_correspondence_id, evidence_type_accession,
                     score )
            values ( ?, ?, ?, ?, ? )
        ],
        {},
        ( $correspondence_evidence_id, $correspondence_evidence_aid, 
          $feature_correspondence_id, $evidence_type_aid, $score
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
    my $db                         = $self->db or return $self->error;
    my $apr                        = $self->apr;
    my $correspondence_evidence_id = $apr->param('correspondence_evidence_id') 
        or push @errors, 'No correspondence evidence id';
    my $correspondence_evidence_aid               = $apr->param('correspondence_evidence_aid')
        || $correspondence_evidence_id;
    my $feature_correspondence_id  = $apr->param('feature_correspondence_id') 
        or push @errors, 'No feature correspondence id';
    my $evidence_type_aid           = $apr->param('evidence_type_aid') 
        or push @errors, 'No evidence type';
    my $score                      = $apr->param('score') || '';

    return $self->corr_evidence_edit( errors => \@errors ) if @errors;
    
    $db->do(
        q[
            update cmap_correspondence_evidence
            set    accession_id=?, feature_correspondence_id=?, 
                   evidence_type_accession=?, score=?
            where  correspondence_evidence_id=?
        ],
        {},
        ( $correspondence_evidence_aid, $feature_correspondence_id, $evidence_type_aid,
          $score, $correspondence_evidence_id
        )
    ); 

    return $self->redirect_home( 
        ADMIN_HOME_URI.'?action=feature_corr_view;'.
            "feature_correspondence_id=$feature_correspondence_id"
    ); 
}

# ----------------------------------------------------
sub feature_type_create {
    return 0;
    ###Do this in Config
}

# ----------------------------------------------------
sub feature_type_edit {
    ###Do this in config file 
    return 0;
    my ( $self, %args ) = @_;
}

# ----------------------------------------------------
sub feature_type_insert {
    ###Do this in config file
    return 0;
}

# ----------------------------------------------------
sub feature_type_update {
    my ( $self, %args ) = @_;
    return 0;
    #Do this in Config file
}

# ----------------------------------------------------
sub feature_type_view {
    my ( $self, %args ) = @_;
    my $db              = $self->db or return $self->error;
    my $apr             = $self->apr;
    my $incoming_feature_type_aid = $apr->param('feature_type_aid') or 
                          die 'No feature type id';
    my $feature_type =$self->feature_type_data($incoming_feature_type_aid) 
        or return $self->error(
        "No feature type for accession '$incoming_feature_type_aid'"
    );


    return $self->process_template( 
        TEMPLATE->{'feature_type_view'},
        { 
            feature_type => $feature_type,
        }
    );
}

# ----------------------------------------------------
sub feature_types_view {
    my $self        = shift;
    my $db          = $self->db or return $self->error;
    my $apr         = $self->apr;
    my $order_by    = $apr->param('order_by') || 'feature_type_aid';
    my $page_no     = $apr->param('page_no')  || 1;


    my @feature_type_aids = keys(%{$self->config_data('feature_type')});
    my $feature_types_hash;
    foreach my $type_aid (@feature_type_aids){
        $feature_types_hash->{$type_aid}=
            $self->feature_type_data($type_aid)
             or return $self->error(
             "No feature type accession '$type_aid'"
              );
    }

    my $feature_types;
    foreach my $type_aid (keys(%{$feature_types_hash})){
        $feature_types_hash->{$type_aid}{'feature_type_aid'}=$type_aid;
        push @$feature_types,$feature_types_hash->{$type_aid};
    }
    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $pager = Data::Pageset->new( {
        total_entries    => scalar @$feature_types, 
        entries_per_page => $PAGE_SIZE,
        current_page     => $page_no,
        pages_per_set    => $MAX_PAGES,
    } );
    $feature_types = 
        @$feature_types ? [ $pager->splice( $feature_types ) ] : []; 

    return $self->process_template( 
        TEMPLATE->{'feature_types_view'}, 
        { 
            feature_types => $feature_types,
            pager         => $pager,
        }
    );
}

# ----------------------------------------------------
sub map_sets_view {
    my $self        = shift;
    my $db          = $self->db or return $self->error;
    my $apr         = $self->apr;
    my $map_type_aid    = $apr->param('map_type_aid') || '';
    my $species_id  = $apr->param('species_id')  || '';
    my $is_enabled  = $apr->param('is_enabled');
    my $page_no     = $apr->param('page_no')     ||  1;
    my $order_by    = $apr->param('order_by')    || '';
    
    if ( $order_by ) {
        $order_by .= ',map_set_short_name' unless $order_by eq 'map_set_short_name';
    }
    else {
        $order_by =
            'ms.display_order, map_type_aid, s.display_order, s.species_common_name, '.
            'ms.display_order, ms.published_on desc, ms.map_set_short_name';
    }

    my $sql = q[
        select      ms.map_set_id,
                    ms.map_set_short_name,
                    ms.accession_id as map_set_aid,
                    ms.published_on,
                    ms.is_enabled,
                    ms.display_order,
                    s.species_common_name,
                    s.display_order,
                    ms.map_type_accession as map_type_aid,
                    count(map.map_id) as no_maps
        from        cmap_map_set ms
        left join   cmap_map map
        on          ms.map_set_id=map.map_set_id
        inner join  cmap_species s 
        on          ms.species_id=s.species_id
    ];
    $sql .= qq[ and ms.map_type_accession='$map_type_aid' ] if $map_type_aid;
    $sql .= qq[ and ms.species_id=$species_id ]   if $species_id;
    $sql .= qq[ and ms.is_enabled=$is_enabled ]   
        if defined $is_enabled && $is_enabled =~ m/^[01]$/;
    $sql .= qq[ 
        group by    ms.map_set_id,
                    ms.map_set_short_name,
                    ms.accession_id,
                    ms.published_on,
                    ms.is_enabled,
                    ms.display_order,
                    s.species_common_name,
                    s.display_order,
                    ms.map_type_accession            
        order by $order_by
    ];

    my $map_sets = $db->selectall_arrayref( $sql, { Columns => {} } );

    foreach my $row ( @{$map_sets} ) {
        $row->{'map_type'} =
            $self->map_type_data( $row->{'map_type_aid'}, 'map_type' );       
    }


    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $pager = Data::Pageset->new( {
        total_entries    => scalar @$map_sets, 
        entries_per_page => $PAGE_SIZE,
        current_page     => $page_no,
        pages_per_set    => $MAX_PAGES,
    } );
    $map_sets = @$map_sets ? [ $pager->splice( $map_sets ) ] : [];

    my $specie = $db->selectall_arrayref(
        q[
            select   distinct s.species_id, s.species_full_name, s.species_common_name
            from     cmap_species s,
                     cmap_map_set ms
            where    s.species_id=ms.species_id
            order by species_common_name
        ], { Columns => {} }
    );
    my $map_types;
    my $index=0;
    foreach my $map_type_aid (keys(%{$self->map_type_data()})){	
	$map_types->[$index]->{'map_type_aid'}=$map_type_aid;
	$map_types->[$index]->{'map_type'}    =
	    $self->map_type_data($map_type_aid,'map_type');
	$index++;
    }
    
    return $self->process_template( 
        TEMPLATE->{'map_sets_view'}, 
        { 
            apr       => $apr,
            specie    => $specie,
            map_types => $map_types,
            map_sets  => $map_sets,
            pager     => $pager,
        }
    );
}

# ----------------------------------------------------
sub map_set_create {
    my ( $self, %args ) = @_;
    my $errors          = $args{'errors'};
    my $db              = $self->db or return $self->error;
    my $apr             = $self->apr;

    my $specie = $db->selectall_arrayref(
        q[
            select   s.species_id, s.species_full_name, s.species_common_name
            from     cmap_species s
            order by species_common_name
        ], { Columns => {} }
    );

    return $self->error(
        'Please <a href="admin?action=species_create">create species</a> '.
        'before creating map sets.'
    ) unless @$specie;

    my @map_type_aids = keys(%{$self->map_type_data()});

print STDERR Dumper(\@map_type_aids)."\n";
    return $self->error(
        'Please create map types in your configuration file '.
        'before creating map sets.'
    ) unless @map_type_aids;

    my %map_type_name_lookup;
    foreach my $ft_aid (@map_type_aids){
        $map_type_name_lookup{$ft_aid}=$self->config_data('map_type')->{$ft_aid}{'map_type'};
    }
    return $self->process_template( 
        TEMPLATE->{'map_set_create'},
        { 
            apr       => $apr,
            errors    => $errors,
            specie    => $specie,
            map_type_aids => \@map_type_aids,
            colors    => $COLORS,
            shapes    => $MAP_SHAPES,
            widths    => $WIDTHS,
            map_type_name_lookup => \%map_type_name_lookup,
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
            select    ms.map_set_id, 
                      ms.accession_id, ms.map_set_name,
                      ms.map_set_short_name, 
                      ms.display_order, 
                      ms.published_on, 
                      ms.is_relational_map,
                      ms.can_be_reference_map,
                      ms.map_type_accession as map_type_aid, 
                      ms.species_id, 
                      ms.is_enabled,
                      ms.shape, 
                      ms.width, 
                      ms.color,
                      s.species_common_name,
                      s.species_full_name,
                      ms.map_units
            from      cmap_map_set ms, 
                      cmap_species s 
            where     ms.species_id=s.species_id
            and       ms.map_set_id=?
        ],
    );

    $sth->execute( $map_set_id );
    my $map_set = $sth->fetchrow_hashref or return $self->error(
        "No map set for ID '$map_set_id'"
    );

    $map_set->{'map_type'}=$self->config_data('map_type')->{$map_set->{'map_type_aid'}}{'map_type'};
    $map_set->{'attributes'} = $self->sql->get_attributes(
        cmap_object => $self,
        object_name      => 'map_set',
        object_id   => $map_set_id,
        order_by    => $apr->param('att_order_by'),
    );

    my $specie = $db->selectall_arrayref(
        q[
            select   species_id, species_full_name, species_common_name
            from     cmap_species
            order by species_common_name
        ], { Columns => {} }
    );

    my @map_type_aids = keys(%{$self->config_data('map_type')});
    my %map_type_name_lookup;
    my %map_type_unit_lookup;
    foreach my $ft_aid (@map_type_aids){ 
        $map_type_name_lookup{$ft_aid}=$self->config_data('map_type')->{$ft_aid}{'map_type'};
        $map_type_unit_lookup{$ft_aid}=$self->config_data('map_type')->{$ft_aid}{'map_units'};
    }

    return $self->process_template( 
        TEMPLATE->{'map_set_edit'},
        { 
            map_set   => $map_set,
            specie    => $specie,
            map_type_aids => \@map_type_aids,
            map_type_name_lookup => \%map_type_name_lookup,
            map_type_unit_lookup => \%map_type_unit_lookup,
            colors    => $COLORS,
            shapes    => $MAP_SHAPES,
            widths    => $WIDTHS,
            errors    => $errors,
        }
    );
}

# ----------------------------------------------------
sub map_set_insert {
    my $self                 =  shift;
    my $apr                  =  $self->apr;
    my $admin                =  $self->admin;
    my $map_set_id           =  $admin->map_set_create(
        map_set_name         => $apr->param('map_set_name')         || '',
        map_set_short_name           => $apr->param('map_set_short_name')           || '',
        species_id           => $apr->param('species_id')           || '',
        map_type_aid         => $apr->param('map_type_aid')          || '',
        map_set_aid         => $apr->param('map_set_aid')         || '',
        display_order        => $apr->param('display_order')        ||  1,
        is_relational_map    => $apr->param('is_relational_map')    ||  0,
        can_be_reference_map => $apr->param('can_be_reference_map') ||  0,
        shape                => $apr->param('shape')                || '',
        color                => $apr->param('color')                || '',
        width                => $apr->param('width')                ||  0,
        published_on         => $apr->param('published_on')    || 'today',
    ) or return $self->map_set_create( errors => $admin->error );

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
    my $order_by    = $apr->param('order_by')   || 'display_order,map_name';
    my $page_no     = $apr->param('page_no')    ||  1;

    my $sth = $db->prepare(
        q[
            select    ms.map_set_id, ms.accession_id as map_set_aid, ms.map_set_name,
                      ms.map_set_short_name, ms.display_order, ms.published_on,
                      ms.map_type_accession as map_type_aid,
                      ms.species_id, 
                      ms.is_relational_map,
                      ms.can_be_reference_map, ms.is_enabled,
                      ms.shape, ms.color, ms.width,
                      s.species_common_name,
                      s.species_full_name,
                      ms.map_units,
                      ms.is_relational_map
            from      cmap_map_set ms, 
                      cmap_species s 
            where     ms.species_id=s.species_id
            and       ms.map_set_id=?
        ]
    );

    $sth->execute( $map_set_id );
    my $map_set = $sth->fetchrow_hashref or return $self->error(
        "No map set for ID '$map_set_id'"
    );

    $map_set->{'map_type'}=$self->config_data('map_type')->{$map_set->{'map_type_aid'}}{'map_type'};
    $map_set->{'object_id'}  = $map_set_id;
    $map_set->{'attributes'} = $self->sql->get_attributes(
        cmap_object => $self,
        object_name      => 'map_set',
        object_id   => $map_set_id,
        order_by    => $apr->param('att_order_by'),
    );
    $map_set->{'xrefs'} = $self->sql->get_xrefs(
        cmap_object => $self,
        object_name      => 'map_set',
        object_id   => $map_set_id,
        order_by    => $apr->param('att_order_by'),
    );

    my @maps = @{ 
        $db->selectall_arrayref( 
            qq[
                select    map.map_id, 
                          map.accession_id as map_aid, 
                          map.map_name, 
                          map.display_order, 
                          map.start_position, 
                          map.stop_position,
                          count(f.map_id) as no_features
                from      cmap_map map
                left join cmap_feature f
                on        map.map_id=f.map_id
                where     map.map_set_id=?
                group by  map.map_id, 
                          map.accession_id, 
                          map.map_name, 
                          map.display_order,
                          map.start_position, 
                          map.stop_position
                order by  $order_by
            ],
            { Columns => {} }, 
            ( $map_set_id ) 
        )
    };

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $pager = Data::Pageset->new( {
        total_entries    => scalar @maps,
        entries_per_page => $PAGE_SIZE,
        current_page     => $page_no,
        pages_per_set    => $MAX_PAGES,
    } );

    $map_set->{'maps'} = @maps ? [ $pager->splice( \@maps ) ] : [];
    $apr->param( order_by => $order_by );

    return $self->process_template( 
        TEMPLATE->{'map_set_view'}, 
        { 
            apr     => $apr,
            map_set => $map_set,
            pager   => $pager,
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
    my $map_set_aid         = $apr->param('map_set_aid')         || '';
    my $map_set_name         = $apr->param('map_set_name')         || '';
    my $map_set_short_name           = $apr->param('map_set_short_name')           || '';
    my $species_id           = $apr->param('species_id')           ||  0;
    my $map_type_aid         = $apr->param('map_type_aid')         ||  0;
    my $is_relational_map    = $apr->param('is_relational_map')    ||  0;
    my $can_be_reference_map = $apr->param('can_be_reference_map') ||  0;
    my $is_enabled           = $apr->param('is_enabled')           ||  0;
    my $display_order        = $apr->param('display_order')        ||  1;
    my $shape                = $apr->param('shape')                || '';
    my $color                = $apr->param('color')                || '';
    my $width                = $apr->param('width')                ||  0;
    my $published_on         = $apr->param('published_on')    || 'today';

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

    my $map_units = $self->config_data('map_type')->{$map_type_aid}{'map_units'};

    
    $db->do(
        q[
            update cmap_map_set
            set    accession_id=?, map_set_name=?, map_set_short_name=?,
                   species_id=?, map_type_accession=?, published_on=?,
                   is_relational_map=?,
                   can_be_reference_map=?, display_order=?, 
                   is_enabled=?, shape=?, color=?, width=?,map_units=?
            where  map_set_id=?
        ],
        {},
        (
            $map_set_aid, $map_set_name, $map_set_short_name, 
            $species_id, $map_type_aid, $published_on, 
            $is_relational_map,
            $can_be_reference_map, $display_order, 
            $is_enabled, $shape, $color, $width,
            $map_units, $map_set_id
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
    print $apr->redirect( $uri );
    return 1;
}

# ----------------------------------------------------
sub map_type_create {
    return 0;
    ###Do this in Config
}

# ----------------------------------------------------
sub map_type_edit {
    my ( $self, %args ) = @_;
    return 0;
    #Do this in Config file
}

# ----------------------------------------------------
sub map_type_insert {
   my ( $self, %args ) = @_;
    return 0;
    #Do this in Config file
 
}

# ----------------------------------------------------
sub map_type_update {
    my ( $self, %args ) = @_;
    return 0;
    #Do this in Config file
}

# ----------------------------------------------------
sub map_type_view {
    my ( $self, %args ) = @_;
    my $db              = $self->db;
    my $apr             = $self->apr;
    my $incoming_map_type_aid = $apr->param('map_type_aid') 
                                or die 'No map type ID';
    my $map_type = $self->map_type_data($incoming_map_type_aid) 
         or return $self->error(
        "No map type for accession '$incoming_map_type_aid'"
    );

    return $self->process_template( 
        TEMPLATE->{'map_type_view'},
        { 
            map_type => $map_type,
        }
    );
}

# ----------------------------------------------------
sub map_types_view {
    my $self        = shift;
    my $db          = $self->db;
    my $apr         = $self->apr;
    my $order_by    = $apr->param('order_by') 
                      || 'display_order,map_type_aid';
    my $page_no     = $apr->param('page_no')  ||  1;

    my @map_type_aids = keys(%{$self->config_data('map_type')});
    my $map_types_hash;
    foreach my $type_aid (@map_type_aids){
        $map_types_hash->{$type_aid}=
            $self->map_type_data($type_aid)
             or return $self->error(
             "No map type accession '$type_aid'"
              );
    }
    my $map_types;
    foreach my $type_aid (keys(%{$map_types_hash})){
        $map_types_hash->{$type_aid}{'map_type_aid'}=$type_aid;
        push @$map_types,$map_types_hash->{$type_aid};
    }

    my $pager = Data::Pageset->new( {
        total_entries    => scalar @$map_types, 
        entries_per_page => $PAGE_SIZE,
        current_page     => $page_no,
        pages_per_set    => $MAX_PAGES,
    } );
    $map_types = @$map_types ? [ $pager->splice( $map_types ) ] : []; 

    return $self->process_template( 
        TEMPLATE->{'map_types_view'},
        { 
            map_types   => $map_types,
            pager       => $pager,
        }
    );
}

# ----------------------------------------------------
sub process_template {
    my ( $self, $template, $params ) = @_;

    $params->{'stylesheet'}   = $self->stylesheet;
    $params->{'data_source'}  = $self->data_source;
    $params->{'data_sources'} = $self->data_sources;

    my $output; 
    my $t = $self->template or return; 
    $t->process( $template, $params, \$output ) or $output = $t->error;

    my $apr = $self->apr;
    print $apr->header( -type => 'text/html', -cookie => $self->cookie ), 
        $output;
    return 1;
}

# ----------------------------------------------------
sub species_create {
    my ( $self, %args ) = @_;
    return $self->process_template( 
        TEMPLATE->{'species_create'},
        { 
            apr    => $self->apr,
            errors => $args{'errors'},
        }
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
            select   accession_id as species_aid,
                     species_id, 
                     species_common_name, 
                     species_full_name,
                     display_order
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
    my $self  = shift;
    my $apr   = $self->apr;
    my $admin = $self->admin;

    $admin->species_create( 
        species_aid  => $apr->param('species_aid')  || '', 
        species_common_name   => $apr->param('species_common_name')   || '', 
        species_full_name     => $apr->param('species_full_name')     || '', 
        display_order => $apr->param('display_order') || '', 
    ) or return $self->species_create( errors => $admin->error );

    return $self->redirect_home( ADMIN_HOME_URI.'?action=species_view' ); 
}

# ----------------------------------------------------
sub species_update {
    my $self          = shift;
    my @errors        = ();
    my $db            = $self->db;
    my $apr           = $self->apr;
    my $species_aid  = $apr->param('species_aid') or 
                        push @errors, 'No accession id';
    my $species_id    = $apr->param('species_id')   or 
                        push @errors, 'No species id';
    my $species_common_name   = $apr->param('species_common_name')  or 
                        push @errors, 'No common name';
    my $species_full_name     = $apr->param('species_full_name')    or 
                        push @errors, 'No full name';
    my $display_order = $apr->param('display_order') || 1;

    return $self->species_edit( errors => \@errors ) if @errors;

    $db->do(
        q[ 
            update cmap_species
            set    accession_id=?,
                   species_common_name=?, 
                   species_full_name=?,
                   display_order=?
            where  species_id=?
        ],
        {}, 
        ($species_aid, $species_common_name, $species_full_name, $display_order, $species_id)
    );

    return $self->redirect_home( ADMIN_HOME_URI.'?action=species_view' ); 
}

# ----------------------------------------------------
sub species_view {
    my $self        = shift;
    my $db          = $self->db;
    my $apr         = $self->apr;
    my $species_id  = $apr->param('species_id') || 0;
    my $order_by    = $apr->param('order_by')   || 'display_order,species_common_name';
    my $page_no     = $apr->param('page_no')    ||  1;
    my $sql         = q[
        select   accession_id as species_aid, 
                 species_id, 
                 species_full_name, 
                 species_common_name,
                 display_order
        from     cmap_species
    ];

    if ( $species_id ) {
        $sql .= 'where species_id=?';
        my $sth = $db->prepare( $sql );
        $sth->execute( $species_id );
        my $species = $sth->fetchrow_hashref;

        $species->{'attributes'} = $self->sql->get_attributes(
            cmap_object => $self,
            object_name      => 'species',
            object_id   => $species_id,
            order_by    => $apr->param('att_order_by'),
        );

        $species->{'xrefs'} = $self->sql->get_xrefs(
            cmap_object => $self,
            object_name      => 'species',
            object_id   => $species_id,
            order_by    => $apr->param('att_order_by'),
        );

        return $self->process_template( 
            TEMPLATE->{'species_view_one'},
            { 
                species => $species,
            }
        );
    }
    else {
        $sql .= "order by $order_by";
        my $species = $db->selectall_arrayref( $sql, { Columns => {} } );

        my $pager = Data::Pageset->new( {
            total_entries    => scalar @$species, 
            entries_per_page => $PAGE_SIZE,
            current_page     => $page_no,
            pages_per_set    => $MAX_PAGES,
        } );
        $species = @$species ? [ $pager->splice( $species ) ] : []; 

        return $self->process_template( 
            TEMPLATE->{'species_view'},
            { 
                species => $species,
                pager   => $pager,
            }
        );
    }
}

# ----------------------------------------------------
sub xref_create {
    my ( $self, %args ) = @_;
    my $apr             = $self->apr or return;
    my $table_name      = $apr->param('table_name') || '';
    my $object_id       = $apr->param('object_id')  ||  0;
    my $db_object;
    
    if ( $table_name && $object_id ) {
        my $pk_name =  pk_name( $table_name );
        my $db      = $self->db or return;
        my $sth     = $db->prepare(
            "select * from $table_name where $pk_name=$object_id"
        );
        $sth->execute;
        $db_object = $sth->fetchrow_hashref;

        my $obj                     = $XREF_OBJ_LOOKUP{ $table_name };
        $db_object->{'name'}        = $db_object->{ $obj->{'name_field'} };
        $db_object->{'object_name'} = $obj->{'object_name'};
    }

    return $self->process_template( 
        TEMPLATE->{'xref_create'},
        {
            apr          => $self->apr,
            errors       => $args{'errors'},
            xref_objects => XREF_OBJECTS,
            table_name   => $table_name,
            object_id    => $object_id,
            db_object    => $db_object,
        }
    );
}

# ----------------------------------------------------
sub xref_edit {
    my ( $self, %args ) = @_;
    my $apr             = $self->apr;
    my $xref_id         = $apr->param('xref_id') or die 'No xref id';
    my $admin           = $self->admin;
    my $db              = $self->db or return $self->error;
    my $sth             = $db->prepare(
        q[
            select xref_id,
                   table_name,
                   object_id,
                   display_order,
                   xref_name,
                   xref_url
            from   cmap_xref
            where  xref_id=?
        ]
    );
    $sth->execute( $xref_id );
    my $xref = $sth->fetchrow_hashref or return $self->error(
        "No database cross-reference for ID '$xref_id'"
    );

    my $table_name = $xref->{'table_name'} || '';
    my $object_id  = $xref->{'object_id'}  || '';
    my $db_object;

    if ( $table_name && $object_id ) {
        my $pk_name = pk_name( $table_name );
        my $db      = $self->db or return;
        my $sth     = $db->prepare(
            "select * from $table_name where $pk_name=$object_id"
        );
        $sth->execute;
        $db_object = $sth->fetchrow_hashref;

        my $obj                     = $XREF_OBJ_LOOKUP{ $table_name };
        $db_object->{'name'}        = $db_object->{ $obj->{'name_field'} };
        $db_object->{'object_name'} = $obj->{'object_name'};
        $db_object->{'object_type'} = $obj->{'object_name'};
    }

    return $self->process_template( 
        TEMPLATE->{'xref_edit'},
        {
            apr          => $self->apr,
            errors       => $args{'errors'},
            xref         => $xref,
            xref_objects => XREF_OBJECTS,
            table_name   => $table_name,
            object_id    => $object_id,
            db_object    => $db_object,
        }
    );
}

# ----------------------------------------------------
sub xref_insert {
    my $self            = shift;
    my $db              = $self->db or return $self->error;
    my $apr             = $self->apr;
    my $admin           = $self->admin;
    my $pk_name         = $apr->param('pk_name')       || '';
    my $return_action   = $apr->param('return_action') || '';
    my $object_id       = $apr->param('object_id')     ||  0;

    $admin->xref_create(
        object_id       => $object_id,
        table_name      => $apr->param('table_name')    || '',
        xref_name       => $apr->param('xref_name')     || '',
        xref_url        => $apr->param('xref_url')      || '',
        display_order   => $apr->param('display_order') || '',
    ) or return $self->xref_create( errors => $admin->error );

    my $action = $return_action && $pk_name && $object_id
        ? "$return_action;$pk_name=$object_id" : 'xrefs_view';

    return $self->redirect_home( ADMIN_HOME_URI."?action=$action" ); 
}

# ----------------------------------------------------
sub xref_update {
    my $self            = shift;
    my $db              = $self->db or return $self->error;
    my $apr             = $self->apr;
    my $admin           = $self->admin;
    my @errors          = ();
    my $xref_id         = $apr->param('xref_id') or die 'No xref id';
    my $object_id       = $apr->param('object_id')     || undef;
    my $return_action   = $apr->param('return_action') || '';
    my $display_order   = $apr->param('display_order');
    my $table_name      = $apr->param('table_name')
                          or push @errors, 'No table name';
    my $name            = $apr->param('xref_name')
                          or push @errors, 'No xref name';
    my $url             = $apr->param('xref_url')      
                          or push @errors, 'No URL';

    return $self->xref_edit( errors => \@errors ) if @errors;

    $admin->set_xrefs(
        object_id  => $object_id,
        table_name => $table_name,
        xrefs      => [
            { 
                xref_id       => $xref_id,
                name          => $name, 
                url           => $url,
                display_order => $display_order,
            },
        ],
    ) or return $self->error( $admin->error );

    my $pk_name  = pk_name( $table_name );
    my $uri_args = $return_action && $pk_name && $object_id
        ? "action=$return_action;$pk_name=$object_id"
        : 'action=xrefs_view'
    ;

    return $self->redirect_home( ADMIN_HOME_URI."?$uri_args" );
}

# ----------------------------------------------------
sub xrefs_view {
    my $self         = shift;
    my $db           = $self->db or return $self->error;
    my $admin        = $self->admin;
    my $apr          = $self->apr;
    my $order_by     = $apr->param('order_by') || 'table_name,display_order';
    my $generic_only = $apr->param('generic_only') || 0;
    my $table_name   = $apr->param('table_name')   || '';
    my $page_no      = $apr->param('page_no')      || 1;
    my $sql          = q[
        select xref_id,
               table_name,
               object_id,
               display_order,
               xref_name,
               xref_url
        from   cmap_xref
        where  table_name is not null
    ];
    $sql .= "and object_id is null "        if $generic_only;
    $sql .= "and table_name='$table_name' " if $table_name;
    $sql .= "order by $order_by"            if $order_by;

    my $refs = $db->selectall_arrayref( $sql, { Columns => {} } );

    my $pager = Data::Pageset->new( {
        total_entries    => scalar @$refs, 
        entries_per_page => $PAGE_SIZE,
        current_page     => $page_no,
        pages_per_set    => $MAX_PAGES,
    } );
    $refs = @$refs ? [ $pager->splice( $refs ) ] : []; 

    for my $ref ( @$refs ) {
        my $object_id            = $ref->{'object_id'};
        my $table                = $ref->{'table_name'};
        my $obj                  = $XREF_OBJ_LOOKUP{ $table };
        my $pk_name              = pk_name( $table );
        my $name_field           = $obj->{'name_field'};
        $ref->{'db_object_name'} = $obj->{'object_name'};

        if ( $ref->{'object_id'} ) {
            $ref->{'actual_object_name'} = $db->selectrow_array(
                "select $name_field from $table where $pk_name=$object_id"
            );
        }
    }

    return $self->process_template( 
        TEMPLATE->{'xrefs_view'}, 
        { 
            apr        => $apr,
            xrefs      => $refs,
            pager      => $pager,
            db_objects => XREF_OBJECTS,
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

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
