package Bio::GMOD::CMap::Admin::Export;
# vim: set ft=perl:

# $Id: Export.pm,v 1.1 2003-10-30 23:24:12 kycl4rk Exp $

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
$VERSION  = (qw$Revision: 1.1 $)[-1];

use Data::Dumper;
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
    my $db              = $self->db           or die 'No database handle';
#    my $fh              = $args{'fh'}         or die     'No file handle';
    $LOG_FH             = $args{'log_fh'}     ||                 \*STDOUT;

    return $self->error('No objects to export') unless @$objects;

    open my $out, ">./out" or die "Can't open 'out'\n";

    my %dump; 
    for my $object_type ( @$objects ) {
        my $method = 'get_'.$object_type;

        if ( $self->can( $method ) ) {
            my $objects = $self->$method();
            (my $pretty = $object_type ) =~ s/_/ /g;
            $self->Print("Getting objects for type '$pretty'\n");
            if ( $object_type ne 'xref' ) {
                $self->get_attributes_and_xrefs( $object_type, $objects );
            }
            $dump{ $object_type } = $objects;
        }
        else {
            $self->Print("Can't do '$method' -- skipping object\n");
        }
    }

    print $out Dump( \%dump );

    return 1;
}

# ----------------------------------------------------
sub get_attributes_and_xrefs {
    my ( $self, $object_type, $objects ) = @_;
    my $db = $self->db or return;

    my $table_name = 'cmap_'.$object_type;

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
    my $self = shift;
    my $db   = $self->db or return;
    return $db->selectall_arrayref(
        q[
            select evidence_type_id as object_id,
                   accession_id,
                   evidence_type, 
                   rank, 
                   line_color
            from   cmap_evidence_type
        ],
        { Columns => {} }
    );
}

# ----------------------------------------------------
sub get_feature_correspondence {
    my $self = shift;
    my $db   = $self->db or return;
    return $db->selectall_arrayref(
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
}

# ----------------------------------------------------
sub get_feature_type {
    my $self = shift;
    my $db   = $self->db or return;
    return $db->selectall_arrayref(
        q[
            select feature_type_id as object_id,
                   accession_id,
                   feature_type, 
                   default_rank, 
                   shape,
                   color,
                   drawing_lane,
                   drawing_priority
            from   cmap_feature_type
        ],
        { Columns => {} }
    );
}

# ----------------------------------------------------
sub get_map_type {
    my $self = shift;
    my $db   = $self->db or return;
    return $db->selectall_arrayref(
        q[
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
        ],
        { Columns => {} }
    );
}

# ----------------------------------------------------
sub get_species {
    my $self = shift;
    my $db   = $self->db or return;
    return $db->selectall_arrayref(
        q[
            select species_id as object_id,
                   accession_id,
                   common_name, 
                   full_name, 
                   display_order
            from   cmap_species
        ],
        { Columns => {} }
    );
}

# ----------------------------------------------------
sub get_xref {
    my $self = shift;
    my $db   = $self->db or return;
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
