package Bio::GMOD::CMap::Admin::ImportCorrespondences;

# $Id: ImportCorrespondences.pm,v 1.1 2002-09-10 01:46:47 kycl4rk Exp $

use strict;
use vars qw( $VERSION %COLUMNS );
$VERSION = (qw$Revision: 1.1 $)[-1];

use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Utils 'next_number';
use base 'Bio::GMOD::CMap';

use constant FIELD_SEP => "\t"; # use tabs for field separator
use constant STRING_RE => qr{^[\w\s.()-]+$};
use constant RE_LOOKUP => {
    string => STRING_RE,
    number => NUMBER_RE,
};

%COLUMNS = (
    feature_aid1 => { is_required => 1, datatype => 'string' },
    feature_aid2 => { is_required => 0, datatype => 'string' },
    evidence     => { is_required => 0, datatype => 'string' },
);

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->params( $config, qw[ file db ] );
    return $self;
}

# ----------------------------------------------------
sub import {
    my ( $self, %args ) = @_;
    my $fh              = $args{'fh'} or die 'No file handle';
    my $db              = $self->db;

    print("Checking headers.\n");

    #
    # Make column names lowercase, convert spaces to underscores 
    # (e.g., make "Feature Name" => "feature_name").
    #
    chomp( my $header   = <$fh> );
    my @columns_present = map { s/\s+/_/g; lc $_ } split(FIELD_SEP, $header);

    print("Parsing file...\n");
    my ( %feature_ids, %evidence_type_ids );
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

        my ( $feature_id1, $feature_id2 );
        for my $i ( 1, 2 ) {
            my $field    = $i==1 ? \$feature_id1 : \$feature_id2;
            my $aid_name = "feature_aid$i";
            my $aid      = $record{$aid_name};
            $$field      = $feature_ids{ $aid } || $db->selectrow_array(
                q[
                    select feature_id
                    from   cmap_feature
                    where  accession_id=?
                ],
                {},
                ( $aid )
            );
            die "Can't get a value for $aid_name ($aid).\n" unless $$field;
        }

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
            print(qq[No evidence type like "$record{'evidence'}."\n]);
            print("Create? [Y/n]");
            chomp( my $answer = <STDIN> );
            if ( $answer =~ m/^[Yy]/ ) {
                $evidence_type_id = next_number(
                    db           => $db, 
                    table_name   => 'cmap_evidence_type',
                    id_field     => 'evidence_type_id',
                ) or die 'No next number for evidence type id.';

                $db->do(
                    q[
                        insert 
                        into   cmap_evidence_type
                               ( evidence_type_id, accession_id, 
                                 evidence_type, rank )
                        values ( ?, ?, ?, ? )
                    ],
                    {},
                    ( $evidence_type_id, $evidence_type_id, 
                      $record{'evidence'}, 0 
                    )
                );
            }
            else {
                print("OK, then skipping\n");
                next LINE;
            }
        }

        #
        # Skip if a correspondence for this type exists already.
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
        next LINE if $count;

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
            ) or die 'No next number for feature correspondence';

            #
            # Create the official correspondence record.
            #
            $db->do(
                q[
                    insert
                    into   cmap_feature_correspondence
                           ( feature_correspondence_id, accession_id,
                             feature_id1, feature_id2 )
                    values ( ?, ?, ?, ? )
                ],
                {},
                ( $feature_correspondence_id, 
                  $feature_correspondence_id, 
                  $feature_id1, 
                  $feature_id2
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
        ) or die 'No next number for correspondence evidence';

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
            ( $correspondence_evidence_id,  
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
            $db->do(
                q[
                    insert
                    into   cmap_correspondence_lookup
                           ( feature_id1, feature_id2,
                             feature_correspondence_id )
                    values ( ?, ?, ? )
                ],
                {},
                ( $vals->[0],
                  $vals->[1],
                  $feature_correspondence_id
                )
            );
        }
        
        print "    Inserted correspondence.\n", 
    }

    return 1;
}

1;

# ----------------------------------------------------
# Prisons are built with stones of Law,
# Brothels with bricks of Religion.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Admin::ImportCorrespondences - import correspondences

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::ImportCorrespondences;
  blah blah blah

=head1 DESCRIPTION

Blah blah blah.

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

Copyright (c) 2002 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
