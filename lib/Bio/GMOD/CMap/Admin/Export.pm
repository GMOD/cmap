package Bio::GMOD::CMap::Admin::Export;
# vim: set ft=perl:

# $Id: Export.pm,v 1.2 2003-10-31 23:03:56 kycl4rk Exp $

=pod

=head1 NAME

Bio::GMOD::CMap::Admin::Export - export CMap data

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::Export;

  my $exporter = Bio::GMOD::CMap::Admin::Export->new(db=>$db);
  $exporter->export(
      map_set_id => $map_set_id,
      fh         => $fh,
  ) or print "Error: ", $exporter->error, "\n";

=head1 DESCRIPTION

This module encapsulates the logic for exporting all the various types
of data out of CMap.

=cut

use strict;
use vars qw( $VERSION %DISPATCH %COLUMNS );
$VERSION  = (qw$Revision: 1.2 $)[-1];

use Data::Dumper;
use File::Spec::Functions;
use YAML 'Dump';
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Utils 'pk_name';

use base 'Bio::GMOD::CMap';

use vars '$LOG_FH';

# ----------------------------------------------------
sub export {

=pod

=head2 export

Exports data.

=cut

    my ( $self, %args ) = @_;
    my $objects         = $args{'objects'};
    my $output_dir      = $args{'output_dir'} || '.';
    my $db              = $self->db           or die 'No database handle';
    $LOG_FH             = $args{'log_fh'}     ||                 \*STDOUT;

    return $self->error('No objects to export') unless @$objects;

    my $out_file = catfile( $output_dir, 'cmap_dump.dat' );
    open my $out_fh, ">$out_file" or die "Can't open '$out_file'\n";

    local $| = 1;

    my %dump; 
    for my $object_type ( @$objects ) {
        my $method = 'get_'.$object_type;

        if ( $self->can( $method ) ) {

            (my $pretty = $object_type ) =~ s/_/ /g;

            $self->Print("Dumping objects for type '$pretty.'\n");

            my $objects = $self->$method( %args );

            if ( ref $objects eq 'ARRAY' ) {
                push @{ $dump{ $object_type } }, @$objects;
            }
            elsif ( ref $objects eq 'HASH' ) {
                while ( my ( $k, $v ) = each %$objects ) {
                    push @{ $dump{ $k } }, @$v;
                }
            }
        }
        else {
            $self->Print("Can't do '$method' -- skipping object\n");
        }
    }

    print $out_fh Dump( \%dump );
    close $out_fh;

    return 1;
}

# ----------------------------------------------------
sub get_attributes_and_xrefs {
    my ( $self, $table_name, $objects ) = @_;
    my $db = $self->db or return;

    my $attributes = $db->selectall_arrayref(
        q[
            select object_id,
                   attribute_name,
                   attribute_value,
                   display_order,
                   is_public
            from   cmap_attribute
            where  object_id is not null
            and    table_name=?
        ],
        { Columns => {} },
        ( $table_name )
    );

    my $xrefs = $db->selectall_arrayref(
        q[
            select object_id,
                   display_order,
                   xref_name,
                   xref_url
            from   cmap_xref
            where  object_id is not null
            and    table_name=?
        ],
        { Columns => {} },
        ( $table_name )
    );

    my %attr_lookup;
    for my $a ( @$attributes ) {
        push @{ $attr_lookup{ $a->{'object_id'} } }, $a;
    }

    my %xref_lookup;
    for my $x ( @$xrefs ) {
        push @{ $xref_lookup{ $x->{'object_id'} } }, $x;
    }

    for my $o ( @$objects ) {
        $o->{'attributes'} = $attr_lookup{ $o->{'object_id'} };
        $o->{'xrefs'}      = $xref_lookup{ $o->{'object_id'} };
    }

    return 1;
}

# ----------------------------------------------------
sub get_evidence_type {
    my ( $self, %args ) = @_;

    my $db  = $self->db or return;
    my $sql = q[
        select evidence_type_id as object_id,
               accession_id,
               evidence_type, 
               rank, 
               line_color
        from   cmap_evidence_type
    ];

    if ( my $et_id = $args{'evidence_type_id'} ) {
        $sql .= "where evidence_type_id=$et_id";
    }

    my $et = $db->selectall_arrayref( $sql, { Columns => {} } );

    $self->get_attributes_and_xrefs( 'cmap_evidence_type', $et );

    return $et;
}

# ----------------------------------------------------
sub get_feature_correspondence {
    my ( $self, %args ) = @_;

    my $db = $self->db or return;
    my $fc = $db->selectall_arrayref(
        q[
            select fc.feature_correspondence_id as object_id,
                   fc.accession_id,
                   fc.is_enabled,
                   f1.accession_id as feature_aid1,
                   f2.accession_id as feature_aid2
            from   cmap_feature_correspondence fc,
                   cmap_feature f1,
                   cmap_feature f2
            where  fc.feature_id1=f1.feature_id
            and    fc.feature_id2=f2.feature_id
        ],
        { Columns => {} }
    );

    $self->get_attributes_and_xrefs( 'cmap_feature_correspondence', $fc );

    return $fc;
}

# ----------------------------------------------------
sub get_feature_type {
    my ( $self, %args ) = @_;

    my $db  = $self->db or return;
    my $sql = q[
        select feature_type_id as object_id,
               accession_id,
               feature_type, 
               default_rank, 
               shape,
               color,
               drawing_lane,
               drawing_priority
        from   cmap_feature_type
    ];

    if ( my $ft_id = $args{'feature_type_id'} ) {
        $sql .= "where feature_type_id=$ft_id";
    }

    my $ft = $db->selectall_arrayref( $sql, { Columns => {} } );

    $self->get_attributes_and_xrefs( 'cmap_feature_type', $ft );

    return $ft;
}

# ----------------------------------------------------
sub get_map_set {
    my ( $self, %args ) = @_;
    my $db              = $self->db or return;
    my $sql             = q[
        select ms.map_set_id as object_id,
               ms.accession_id,
               ms.map_set_name, 
               ms.short_name, 
               ms.map_type_id,
               ms.species_id,
               ms.published_on,
               ms.can_be_reference_map,
               ms.display_order,
               ms.is_enabled,
               ms.shape,
               ms.color,
               ms.width,
               s.accession_id as species_aid
        from   cmap_map_set ms,
               cmap_species s
        where  ms.species_id=s.species_id
    ];

    if ( 
        my @map_set_ids = 
        map { $_->{'map_set_id'} } @{ $args{'map_sets'} || [] } 
    ) {
        $sql .= 'and map_set_id in (' . join(',', @map_set_ids) . ')';
    }

    my $map_sets = $db->selectall_arrayref( $sql, { Columns => {} } );

    my ( @map_sets, %species_ids, %map_type_ids, %ft_ids );
    for my $ms ( @$map_sets ) {
        my %map_set = 
            map  { $_, $ms->{ $_ } } 
            grep { !/(species_id|map_type_id)/ }
            keys %$ms
        ;

        $species_ids { $ms->{'species_id'}  } = 1;
        $map_type_ids{ $ms->{'map_type_id'} } = 1;

        my $maps = $db->selectall_arrayref(
            q[
                select map_id as object_id,
                       accession_id,
                       map_name,
                       display_order,
                       start_position,
                       stop_position
                from   cmap_map
                where  map_set_id=?
            ],
            { Columns => {} },
            ( $ms->{'object_id'} )
        );

        $self->get_attributes_and_xrefs( 'cmap_map', $maps );

        for my $map ( @$maps ) {
            $map->{'features'} = $db->selectall_arrayref(
                q[
                    select f.feature_id as object_id,
                           f.accession_id,
                           f.feature_name,
                           f.is_landmark,
                           f.start_position,
                           f.stop_position,
                           ft.accession_id as feature_type_aid
                    from   cmap_feature f
                           cmap_feature_type ft
                    where  f.map_id=?
                    and    f.feature_type_id=ft.feature_type_id
                ],
                { Columns => {} },
                ( $map->{'object_id'} )
            );

            my $aliases = $db->selectall_arrayref(
                q[
                    select f.accession_id as feature_aid,
                           fa.feature_alias_id as object_id,
                           fa.feature_id,
                           fa.alias
                    from   cmap_feature f,
                           cmap_feature_alias fa
                    where  f.map_id=?
                    and    f.feature_id=fa.feature_id
                ],
                { Columns => {} },
                ( $map->{'object_id'} )
            );

            $self->get_attributes_and_xrefs( 'cmap_feature_alias', $aliases );

            my %alias_lookup = ();
            for my $alias ( @$aliases ) {
                push @{ $alias_lookup{ $alias->{'feature_id'} } }, $alias;
            }

            for my $f ( @{ $map->{'features'} } ) {
                $ft_ids{ $f->{'feature_type_id'} } = 1;
                $f->{'aliases'} = $alias_lookup{ $f->{'object_id'} };
            }

            $self->get_attributes_and_xrefs( 
                'cmap_feature', $map->{'features'} 
            );
        }

        $map_set{'maps'} = $maps;

        push @map_sets, \%map_set;
    }

    $self->get_attributes_and_xrefs( 'cmap_map_set', \@map_sets );

    my @species;
    for my $species_id ( keys %species_ids ) {
        push @species, @{ $self->get_species( species_id => $species_id ) };
    }

    my @map_type;
    for my $map_type_id ( keys %map_type_ids ) {
        push @map_type, @{ $self->get_map_type( map_type_id => $map_type_id ) };
    }

    my @feature_types;
    for my $feature_type_id ( keys %ft_ids ) {
        push @feature_types, @{ 
            $self->get_feature_type( feature_type_id => $feature_type_id ) 
        };
    }

    return {
        map_set      => \@map_sets,
        species      => \@species,
        map_type     => \@map_type,
        feature_type => \@feature_types,
    };
}

# ----------------------------------------------------
sub get_map_type {
    my ( $self, %args ) = @_;

    my $db  = $self->db or return;
    my $sql = q[
        select map_type_id as object_id,
               accession_id,
               map_type, 
               map_units, 
               is_relational_map,
               shape,
               color,
               width,
               display_order
        from   cmap_map_type
    ];

    if ( my $map_type_id = $args{'map_type_id'} ) {
        $sql .= "where map_type_id=$map_type_id";
    }

    my $mt = $db->selectall_arrayref( $sql, { Columns => {} } );

    $self->get_attributes_and_xrefs( 'cmap_map_type', $mt );

    return $mt;
}

# ----------------------------------------------------
sub get_species {
    my ( $self, %args ) = @_;

    my $db  = $self->db or return;
    my $sql = q[
        select species_id as object_id,
               accession_id,
               common_name, 
               full_name, 
               display_order
        from   cmap_species
    ];

    if ( my $species_id = $args{'species_id'} ) {
        $sql .= "where species_id=$species_id";
    }

    my $species = $db->selectall_arrayref( $sql, { Columns => {} } );

    $self->get_attributes_and_xrefs( 'cmap_species', $species );

    return $species;
}

# ----------------------------------------------------
sub get_xref {
    my ( $self, %args ) = @_;
    my $db              = $self->db or return;
    return $db->selectall_arrayref(
        q[
            select table_name,
                   display_order,
                   xref_name,
                   xref_url
            from   cmap_xref
            where  object_id is null
        ],
        { Columns => {} }
    );
}

# ----------------------------------------------------
sub Print {
    my $self = shift;
    print $LOG_FH @_;
}

1;

# ----------------------------------------------------
# Which way does your beard point tonight?
# Allen Ginsberg
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
