package Bio::GMOD::CMap::Admin::Export;
# vim: set ft=perl:

# $Id: Export.pm,v 1.6.2.2 2004-06-18 21:23:05 kycl4rk Exp $

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
$VERSION  = (qw$Revision: 1.6.2.2 $)[-1];

use Data::Dumper;
use File::Spec::Functions;
use XML::Simple;
use Bio::GMOD::CMap;

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
    my $output          = $args{'output'};
    my $output_path     = $args{'output_path'};
    return $self->error('No output argument') unless $output || $output_path;
    return $self->error('Output arg not a scalar reference') if 
        defined $output && ref $output ne 'SCALAR';
    my $db              = $self->db or 
                          return $self->error('No database handle');
    $LOG_FH             = $args{'log_fh'} || \*STDOUT;

    return $self->error('No objects to export') unless @$objects;

    local $| = 1;

    my %dump; 
    for my $object_type ( @$objects ) {
        my $method = 'get_'.$object_type;

        if ( $self->can( $method ) ) {
            my $pretty = $object_type;
            $pretty    =~ s/^cmap_//;
            $pretty    =~ s/_/ /g;

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

    my $date = localtime;
    $dump{'dump_date'} = $date;
    my @comments = (
        'This file contains data from CMap (http://www.gmod.org/cmap)',
        'From the ' . $self->data_source . ' data source',
        "Created on $date"
    );

    my $xml = join( "\n",
        "<?xml version='1.0'?>",
        ( join( "\n", map { "<!-- $_ -->" } @comments ) ),
        '', '', 
        XMLout( \%dump, 
            RootName      => 'cmap_export',
            NoAttr        => 1,
            SuppressEmpty => 1,
            XMLDecl       => 0,
        )
    );

    if ( $output_path ) {
        open my $out_fh, ">$output_path" or die "Can't open '$output_path'\n";
        print $out_fh $xml;
        close $out_fh;
    }
    else {
        $$output = $xml;
    }
    
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
        if ( defined $attr_lookup{ $o->{'object_id'} } ) {
            $o->{'attribute'} = $attr_lookup{ $o->{'object_id'} };
        }

        if ( defined $xref_lookup{ $o->{'object_id'} } ) {
            $o->{'xref'} = $xref_lookup{ $o->{'object_id'} };
        }
    }

    return 1;
}

# ----------------------------------------------------
sub get_cmap_evidence_type {
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

    unless ( $args{'no_attributes'} ) {
        $self->get_attributes_and_xrefs( 'cmap_evidence_type', $et );
    }

    return $et;
}

# ----------------------------------------------------
sub get_cmap_feature_correspondence {
    my ( $self, %args ) = @_;
    my $map_set_ids     = join(', ', 
        map { $_->{'map_set_id'} } @{ $args{'map_sets'} || [] }
    );

    my $fc_sql = q[
        select fc.feature_correspondence_id as object_id,
               fc.accession_id,
               fc.is_enabled,
               f1.accession_id as feature_aid1,
               f2.accession_id as feature_aid2
        from   cmap_feature_correspondence fc,
               cmap_feature f1,
               cmap_feature f2,
               cmap_map map1,
               cmap_map map2
        where  fc.feature_id1=f1.feature_id
        and    f1.map_id=map1.map_id
        and    fc.feature_id2=f2.feature_id
        and    f2.map_id=map2.map_id      
    ];         
               
    if ( $map_set_ids ) {
        $fc_sql .= qq[ 
            and map1.map_set_id in ($map_set_ids) 
            and map2.map_set_id in ($map_set_ids)
        ]; 
    }  

    my $db = $self->db or return;
    my $fc = $db->selectall_arrayref( $fc_sql, { Columns => {} } );

    unless ( $args{'no_attributes'} ) {
        $self->get_attributes_and_xrefs( 'cmap_feature_correspondence', $fc );
    }

    my $evidence_sql;
    if ( $map_set_ids )  {
        $evidence_sql = qq[
            select ce.correspondence_evidence_id as object_id,
                   ce.feature_correspondence_id,
                   ce.accession_id,
                   ce.evidence_type_id,
                   ce.score
            from   cmap_correspondence_evidence ce,
                   cmap_feature_correspondence fc,
                   cmap_feature f1,
                   cmap_feature f2,
                   cmap_map map1,
                   cmap_map map2
            where  ce.feature_correspondence_id=fc.feature_correspondence_id
            and    fc.feature_id1=f1.feature_id
            and    f1.map_id=map1.map_id
            and    fc.feature_id2=f2.feature_id
            and    f2.map_id=map2.map_id      
            and    map1.map_set_id in ($map_set_ids) 
            and    map2.map_set_id in ($map_set_ids)
        ];
    }
    else {
        $evidence_sql = q[
            select correspondence_evidence_id as object_id,
                   feature_correspondence_id,
                   accession_id,
                   evidence_type_id,
                   score
            from   cmap_correspondence_evidence
        ];
    }

    my $evidence = $db->selectall_arrayref( $evidence_sql, { Columns => {} } );
    my %evidence_lookup = ();
    for my $e ( @$evidence ) {
        push @{ $evidence_lookup{ $e->{'object_id'} } }, $e;
    }

    for my $corr ( @$fc ) {
        $corr->{'correspondence_evidence'} = 
            $evidence_lookup{ $corr->{'object_id'} };
    }

    return $fc;
}

# ----------------------------------------------------
sub get_cmap_feature_type {
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

    unless ( $args{'no_attributes'} ) {
        $self->get_attributes_and_xrefs( 'cmap_feature_type', $ft );
    }

    return $ft;
}

# ----------------------------------------------------
sub get_cmap_map_set {
    my ( $self, %args ) = @_;
    my $db              = $self->db or return;
    my $sql             = q[
        select map_set_id as object_id,
               accession_id,
               map_set_name, 
               short_name, 
               map_type_id,
               species_id,
               published_on,
               can_be_reference_map,
               display_order,
               is_enabled,
               shape,
               color,
               width,
               species_id,
               map_type_id
        from   cmap_map_set ms
    ];

    if ( 
        my @map_set_ids = 
        map { $_->{'map_set_id'} } @{ $args{'map_sets'} || [] } 
    ) {
        $sql .= 'where map_set_id in (' . join(',', @map_set_ids) . ')';
    }

    my $map_sets = $db->selectall_arrayref( $sql, { Columns => {} } );

    my ( %species_ids, %map_type_ids, %ft_ids );
    for my $ms ( @$map_sets ) {
        $species_ids { $ms->{'species_id'}  } = 1;
        $map_type_ids{ $ms->{'map_type_id'} } = 1;

        $ms->{'map'} = $db->selectall_arrayref(
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

        unless ( $args{'no_attributes'} ) {
            $self->get_attributes_and_xrefs( 'cmap_map', $ms->{'map'} );
        }

        for my $map ( @{ $ms->{'map'} } ) {
            $map->{'feature'} = $db->selectall_arrayref(
                q[
                    select feature_id as object_id,
                           accession_id,
                           feature_name,
                           is_landmark,
                           start_position,
                           stop_position,
                           feature_type_id
                    from   cmap_feature
                    where  map_id=?
                ],
                { Columns => {} },
                ( $map->{'object_id'} )
            );

            my $aliases = $db->selectall_arrayref(
                q[
                    select fa.feature_alias_id as object_id,
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

            unless ( $args{'no_attributes'} ) {
                $self->get_attributes_and_xrefs( 
                    'cmap_feature_alias', $aliases 
                );
            }

            my %alias_lookup = ();
            for my $alias ( @$aliases ) {
                push @{ $alias_lookup{ $alias->{'feature_id'} } }, $alias;
            }

            for my $f ( @{ $map->{'feature'} } ) {
                $ft_ids{ $f->{'feature_type_id'} } = 1;
                if ( defined $alias_lookup{ $f->{'object_id'} } ) {
                    $f->{'feature_alias'} = $alias_lookup{ $f->{'object_id'} };
                }
            }

            $self->get_attributes_and_xrefs( 
                'cmap_feature', $map->{'feature'} 
            ) unless $args{'no_attributes'};
        }
    }

    unless ( $args{'no_attributes'} ) {
        $self->get_attributes_and_xrefs( 'cmap_map_set', $map_sets );
    }

    my @species;
    for my $species_id ( keys %species_ids ) {
        push @species, @{ 
            $self->get_cmap_species( species_id => $species_id ) 
        };
    }

    my @map_type;
    for my $map_type_id ( keys %map_type_ids ) {
        push @map_type, @{ 
            $self->get_cmap_map_type( map_type_id => $map_type_id ) 
        };
    }

    my @feature_types;
    for my $feature_type_id ( keys %ft_ids ) {
        push @feature_types, @{ 
            $self->get_cmap_feature_type( feature_type_id => $feature_type_id ) 
        };
    }

    return {
        cmap_map_set      => $map_sets,
        cmap_species      => \@species,
        cmap_map_type     => \@map_type,
        cmap_feature_type => \@feature_types,
    };
}

# ----------------------------------------------------
sub get_cmap_map_type {
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

    unless ( $args{'no_attributes'} ) {
        $self->get_attributes_and_xrefs( 'cmap_map_type', $mt );
    }

    return $mt;
}

# ----------------------------------------------------
sub get_cmap_species {
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

    unless ( $args{'no_attributes'} ) {
        $self->get_attributes_and_xrefs( 'cmap_species', $species );
    }

    return $species;
}

# ----------------------------------------------------
sub get_cmap_xref {
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
            or     object_id=0
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

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
