package Bio::GMOD::CMap::Admin::ImportCorrespondences;

# $Id: ImportCorrespondences.pm,v 1.6 2003-02-14 01:25:36 kycl4rk Exp $

=head1 NAME

Bio::GMOD::CMap::Admin::ImportCorrespondences - import correspondences

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::ImportCorrespondences;
  my $importer = Bio::GMOD::CMap::Admin::ImportCorrespondences->new;
  $importer->import(
      fh       => $fh,
      log_fh   => $self->log_fh,
  ) or return $importer->error;

=head1 DESCRIPTION

This module encapsulates all the logic for importing features
correspondences.  Currently, only one format is acceptable, a
tab-delimited file containing the following fields:

    feature_name1
    feature_name2
    evidence

The order of the fields is unimportant, and the order of the names of
the features is, too, as reciprocal records will be created for each
correspondences ("A=B" and "B=A," etc.).  If the evidence doesn't
exist, a prompt will ask to create it.

Note:  Both the "feature_name" and "alternate_name" fields are
checked.  For every feature matching each of the two feature names, a
correspondence will be created.

I'd like to add the ability to import with feature accession IDs
(which are unique) as that seems like it could be a lot more accurate
than just feature names (which could be duplicated on other maps).

=cut

use strict;
use vars qw( $VERSION %COLUMNS $LOG_FH );
$VERSION = (qw$Revision: 1.6 $)[-1];

use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Admin;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Utils qw[ next_number ];
use base 'Bio::GMOD::CMap';

%COLUMNS = (
    feature_name1 => { is_required => 1, datatype => 'string' },
    feature_name2 => { is_required => 1, datatype => 'string' },
    evidence      => { is_required => 1, datatype => 'string' },
);

use constant FIELD_SEP => "\t"; # use tabs for field separator
use constant STRING_RE => qr{^[\w\s.()-]+$};
use constant RE_LOOKUP => {
    string => STRING_RE,
    number => NUMBER_RE,
};
use constant FEATURE_SQL => q[
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
    where  (
        upper(f.feature_name)=?
        or
        upper(f.alternate_name)=?
    )
    and    f.map_id=map.map_id
    and    map.map_set_id=ms.map_set_id
    and    ms.map_type_id=mt.map_type_id
];

# ----------------------------------------------------
sub import {
    my ( $self, %args ) = @_;
    my $fh              = $args{'fh'} or return $self->error('No file handle');
#    my @map_set_ids     = @{ $args{'map_set_ids'} || [] };
    my $db              = $self->db;
    $LOG_FH             = $args{'log_fh'} || \*STDOUT;
    my $admin           = Bio::GMOD::CMap::Admin->new(
        data_source => $self->data_source,
    );

    $self->Print("Importing feature correspondence data.\n");
    $self->Print("Checking headers.\n");

    #
    # Make column names lowercase, convert spaces to underscores 
    # (e.g., make "Feature Name" => "feature_name").
    #
    chomp( my $header   = <$fh> );
    my @columns_present = map { s/\s+/_/g; lc $_ } split(FIELD_SEP, $header);

    for my $column_name ( @columns_present ) {
        if ( exists $COLUMNS{ $column_name } ) {
            $self->Print("Column '$column_name' OK.\n")
        }
        else {
            return $self->error("Column name '$column_name' is not valid.");
        }
    }

#    my $sql = FEATURE_SQL;
#    if ( @map_set_ids ) {
#        $self->Print("Restricting SQL with map set IDs.\n");
#        $sql .= 'and ms.map_set_id in (' . join(',', @map_set_ids) . ')';
#    }

    $self->Print("Parsing file...\n");
    my ( %feature_ids, %evidence_type_ids, $inserts, $total );
    LINE:
    while ( <$fh> ) {
        chomp;
        my @fields = split FIELD_SEP;
        return $self->error("Odd number of fields") 
            if @fields > @columns_present;

        my %record;
        for my $i ( 0 .. $#columns_present ) {
            my $field_name = $columns_present[ $i ]  or next;
            my $field_attr = $COLUMNS{ $field_name } or next;
            my $field_val  = $fields[ $i ];

            if ( $field_attr->{'is_required'} && !defined $field_val ) {
                return $self->error("Field '$field_name' is required");
            }

            if ( my $datatype = $field_attr->{'datatype'} && 
                 defined $field_val 
            ) {
                if ( my $regex = RE_LOOKUP->{ $datatype } ) {
                    return $self->error(
                        "Value of '$field_name'  is wrong.  " .
                        "Expected $datatype and got '$field_val'."
                    ) unless $field_val =~ $regex;
                }
            }

            $record{ $field_name } = $field_val;
        }
        $total++;

        my ( @feature_ids1, @feature_ids2 );
        for my $i ( 1, 2 ) {
            my $field_name   = "feature_name$i";
            my $feature_name = $record{ $field_name } or next;
            my $upper_name   = uc $feature_name;
            my @feature_ids;
            if ( defined $feature_ids{ $upper_name } ) {
                @feature_ids = @{ $feature_ids{ $upper_name } } or next;
            }

            unless ( @feature_ids ) {
                @feature_ids = @{ $db->selectall_arrayref(
                    FEATURE_SQL,
                    { Columns => {} },
                    ( $upper_name, $upper_name )
                ) || [] };

                if ( @feature_ids ) {
                    $feature_ids{ $upper_name } = \@feature_ids;

                    if ( $i==1 ) {
                        @feature_ids1 = @feature_ids;
                    }
                    else {
                        @feature_ids2 = @feature_ids;
                    }
                }
            }

            unless ( @feature_ids ) {
                $feature_ids{ $upper_name } = [];
                warn qq[Can't find feature IDs for "$feature_name".\n];
                next LINE;
            }
        }

        next LINE unless @feature_ids1 && @feature_ids2;

        my $evidence_type_id = $evidence_type_ids{ $record{'evidence'} };
        unless ( $evidence_type_id ) {
            $evidence_type_id = $db->selectrow_array(
                q[
                    select evidence_type_id
                    from   cmap_evidence_type
                    where  upper(evidence_type)=?
                ],
                {},
                ( uc $record{'evidence'} )
            );
        } 

        unless ( $evidence_type_id ) {
            $self->Print(qq[No evidence type like "$record{'evidence'}."\n]);
            $self->Print("Create? [Y/n]");
            chomp( my $answer = <STDIN> );
            unless ( $answer =~ m/^[Nn]/ ) {
                $evidence_type_id = next_number(
                    db           => $db, 
                    table_name   => 'cmap_evidence_type',
                    id_field     => 'evidence_type_id',
                ) or return $self->error(
                    'No next number for evidence type id.'
                );

                $db->do(
                    q[
                        insert 
                        into   cmap_evidence_type
                               ( evidence_type_id, accession_id, 
                                 evidence_type )
                        values ( ?, ?, ? )
                    ],
                    {},
                    ( $evidence_type_id, $evidence_type_id, $record{'evidence'}
                    )
                );
            }
            else {
                $self->Print("OK, then skipping\n");
                next LINE;
            }
        }

        for my $feature1 ( @feature_ids1 ) {
            for my $feature2 ( @feature_ids2 ) {
#                #
#                # Don't create correspondences among relational maps.
#                #
#                next if 
#                    $feature1->{'map_set_id'} == $feature2->{'map_set_id'} 
#                    &&
#                    $feature1->{'is_relational_map'} == 1;
#
#                #
#                # Don't create correspondences among relational map sets.
#                #
#                next if $feature1->{'is_relational_map'} && 
#                    $feature2->{'is_relational_map'};

                my $fc_id = $admin->insert_correspondence( 
                    $feature1->{'feature_id'},
                    $feature2->{'feature_id'},
                    $evidence_type_id,
                ) or return $self->error( $admin->error );

                if ( $fc_id > 0 ) {
                    $self->Print("Created correspondence for '",
                        $feature1->{'feature_name'}, "' and '", 
                        $feature2->{'feature_name'}, "' (",
                        $record{'evidence'}, ").\n"
                    );
                }
                else {
                    $self->Print("Correspondence already existed for '",
                        $feature1->{'feature_name'}, "' and '", 
                        $feature2->{'feature_name'}, "' (",
                        $record{'evidence'}, ").\n"
                    );
                }

                $inserts++;
            }
        }

    }

    $self->Print(
        "Processed $total records, inserted $inserts correspondences.\n"
    );

    return 1;
}

sub Print {
    my $self = shift;
    print $LOG_FH @_;
}

1;

# ----------------------------------------------------
# Prisons are built with stones of Law,
# Brothels with bricks of Religion.
# William Blake
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

Copyright (c) 2002 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
