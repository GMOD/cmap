package CSHL::CMap::Admin::Import;

# $Id: Import.pm,v 1.1.1.1 2002-07-31 23:27:27 kycl4rk Exp $

=pod

=head1 NAME

CSHL::CMap::Admin::DataImport - import map data

=head1 SYNOPSIS

  use CSHL::CMap::Admin::DataImport;

  my $importer = CSHL::CMap::Admin::DataImport->new(db=>$db);
  $importer->import(
      map_set_id => $map_set_id,
      fh           => $fh,
      map_type     => $map_type,
  ) or print "Error: ", $importer->error, "\n";

=head1 DESCRIPTION

This module encapsulates the logic for importing all the various types
of maps into the database.

=cut

use strict;
use vars qw( $VERSION %DISPATCH %COLUMNS );
$VERSION  = (qw$Revision: 1.1.1.1 $)[-1];

use CSHL::CMap;
use CSHL::CMap::Constants;
use CSHL::CMap::Utils 'next_number';

use base 'CSHL::CMap';

use constant FIELD_SEP => "\t"; # use tabs for field separator
use constant STRING_RE => qr{^[\w\s.()-]+$};
use constant RE_LOOKUP => {
    string => STRING_RE,
    number => NUMBER_RE,
};

%COLUMNS = (
    map_name             => { is_required => 1, datatype => 'string' },
    map_accession_id     => { is_required => 0, datatype => 'string' },
    map_start            => { is_required => 0, datatype => 'number' },
    map_stop             => { is_required => 0, datatype => 'number' },
    feature_name         => { is_required => 1, datatype => 'string' },
    feature_accession_id => { is_required => 0, datatype => 'string' },
    feature_alt_name     => { is_required => 0, datatype => 'string' },
    feature_start        => { is_required => 1, datatype => 'number' },
    feature_stop         => { is_required => 0, datatype => 'number' },
    feature_type         => { is_required => 1, datatype => 'string' },
);


# ----------------------------------------------------
sub import {

=pod

=head2 import

Imports tab-delimited file with the following fields:

    map_name *
    map_accession_id
    map_start
    map_stop
    feature_name *
    feature_accession_id
    feature_alt_name
    feature_start *
    feature_stop
    feature_type *

Starred fields are required.  Order of fields is not important.

=cut

    my ( $self, %args ) = @_;
    my $db              = $self->db           or die 'No database handle';
    my $map_set_id      = $args{'map_set_id'} or die 'No map set id';
    my $fh              = $args{'fh'}         or die 'No file handle';
    my $overwrite       = $args{'overwrite'}  || 0;

#    $self->be_quiet( $args{'be_quiet'} );

    my ( %map_ids, %feature_type_ids, %feature_ids );
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

    $self->Print("Parsing file...\n");
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
                my $regex = RE_LOOKUP->{ $datatype };
                return $self->error(
                    "Value of '$field_name'  is wrong.  " .
                    "Expected $datatype and got '$field_val'."
                ) unless $field_val =~ $regex;
            }

            $record{ $field_name } = $field_val;
        }

        my $feature_type    = $record{'feature_type'};
        my $feature_type_id = $feature_type_ids{ uc $feature_type };

        #
        # Not in our cache, so select it.
        #
        unless ( $feature_type_id ) {
            $feature_type_id = $db->selectrow_array(
                q[
                    select feature_type_id
                    from   cmap_feature_type
                    where  upper(feature_type)=?
                ],
                {},
                ( uc $feature_type )
            ) || 0;

            $feature_type_ids{ uc $feature_type } = $feature_type_id;
        }

        #
        # Not in the database, so ask to create it.
        #
        unless ( $feature_type_id ) {
            print "Feature type '$feature_type' doesn't exist.  Create?[Y/n] ";
            chomp( my $answer = <STDIN> );
            if ( $answer =~ m/[Yy]/ ) {
                $feature_type_id = next_number(
                    db           => $db, 
                    table_name   => 'cmap_feature_type',
                    id_field     => 'feature_type_id',
                ) or die 'No next number for feature type id.';

                $db->do(
                    q[
                        insert
                        into   cmap_feature_type
                               ( feature_type_id, accession_id, 
                                 feature_type, default_rank,
                                 is_visible, how_to_draw )
                        values ( ?, ?, ?, ?, ?, ? )
                    ],
                    {},
                    ( $feature_type_id, $feature_type_id, $feature_type, 
                      1, 1, 'line' 
                    )
                );
            }
            else {
                next;
            }

            $feature_type_ids{ uc $feature_type } = $feature_type_id;
        }

        #
        # Figure out the map id (or create it).
        #
        my $map_name = $record{'map_name'};
        my $map_id   = $map_ids{ $map_name };
        unless ( $map_id ) {
            $map_id = $db->selectrow_array(
                q[
                    select map_id
                    from   cmap_map
                    where  map_set_id=?
                    and    map_name=?
                ],
                {}, ( $map_set_id, $map_name )
            );

            unless ( $map_id ) {
                $map_id = next_number(
                    db           => $db, 
                    table_name   => 'cmap_map',
                    id_field     => 'map_id',
                ) or die 'No map id';

                my $accession_id = $record{'accession_id'} || $map_id;
                my $map_start    = $record{'map_start'}    || 0;
                my $map_stop     = $record{'map_stop'}     || 0;

                $db->do(
                    q[
                        insert
                        into   cmap_map 
                               ( map_id, accession_id, map_set_id, 
                                 map_name, start_position, stop_position )
                        values ( ?, ?, ?, ?, ?, ? )
                    ],
                    {}, 
                    ( $map_id, $accession_id, $map_set_id, 
                      $map_name, $map_start, $map_stop 
                    )
                );

                $self->Print(
                    "Created map $map_name ($map_id).\n"
                );
            }

            $self->Print("No id for map $map_name.\n"), next 
                unless $map_id;
            $map_ids{ $map_name } = $map_id;
        }

        #
        # See if the acc. id already exists.
        #
        my $feature_name   = $record{'feature_name'}     or next;
        my $accession_id   = $record{'accession_id'};
        my $alternate_name = $record{'feature_alt_name'} || '';
        my $start          = $record{'feature_start'};
        my $stop           = $record{'feature_stop'};
        my $feature_id;
        if ( $accession_id ) {
            $feature_id = $db->selectrow_array(
                q[
                    select feature_id
                    from   cmap_feature
                    where  accession_id=?
                ],
                {},
                ( $accession_id )
            );
        }
        #
        # Else, just see if another identical record exists.
        #
        else {
            $feature_id = $db->selectrow_array(
                q[
                    select feature_id
                    from   cmap_feature
                    where  map_id=?
                    and    feature_name=?
                    and    start_position=?
                ],
                {},
                ( $map_id, $feature_name, $start )
            );
        }

        my $action = 'Inserted';
        if ( $feature_id ) {
            $action         = 'Updated';
            $accession_id ||= $feature_id;
            $db->do(
                q[
                    update cmap_feature
                    set    accession_id=?, map_id=?, feature_type_id=?, 
                           feature_name=?, alternate_name=?, 
                           start_position=?, stop_position=?
                    where  feature_id=?
                ],
                {}, 
                ( $accession_id, $map_id, $feature_type_id, 
                  $feature_name, $alternate_name, 
                  $start, $stop, $feature_id
                )
            );
        }
        else {
            #
            # Create a new feature record.
            #
            $feature_id = next_number(
                db           => $db, 
                table_name   => 'cmap_feature',
                id_field     => 'feature_id',
            ) or die 'No feature id';

            $accession_id ||= $feature_id;

            $db->do(
                q[
                    insert
                    into   cmap_feature
                           ( feature_id, accession_id, map_id,
                             feature_type_id, feature_name, alternate_name, 
                             start_position, stop_position )
                    values ( ?, ?, ?, ?, ?, ?, ?, ? )
                ],
                {}, 
                ( $feature_id, $accession_id, $map_id, $feature_type_id, 
                  $feature_name, $alternate_name, $start, $stop 
                )
            );
        }

        my $pos = join('-', map { defined $_ ? $_ : () } $start, $stop);
        $self->Print("$action $feature_type '$feature_name' on map ".
              "$map_name ($map_id) at $pos.\n"
        );
    }

    # 
    # Make sure the maps have legitimate starts and stops.
    # 
    for my $map_name ( sort keys %map_ids ) {
        my $map_id = $map_ids{ $map_name };
        $self->Print("Verifying start and stop for map $map_name ($map_id).\n");
        my ( $start, $stop ) = $db->selectrow_array(
            q[
                select map.start_position, map.stop_position
                from   cmap_map map
                where  map.map_id=?
            ],
            {},
            ( $map_id )
        );

        next if $start > 0 and $stop > 0;
        
        my ( $min, $max ) = $db->selectrow_array(
            q[
                select   min(f.start_position), 
                         max(f.stop_position)
                from     cmap_feature f
                where    f.map_id=?
                group by f.map_id
            ],
            {},
            ( $map_id )
        );

        $db->do(
            q[
                update cmap_map
                set    start_position=?,
                       stop_position=?
                where  map_id=?
            ],
            {},
            ( $min, $max, $map_id )
        );
    }    

    $self->Print("Done\n");
    
    return 1;
}

sub Print {
    my $self = shift;
    print @_;
}

1;

#-----------------------------------------------------
# Which way does your beard point tonight?
# Allen Ginsberg
#-----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

Copyright (c) 2002 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
