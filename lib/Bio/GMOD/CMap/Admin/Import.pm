package Bio::GMOD::CMap::Admin::Import;

# $Id: Import.pm,v 1.6 2002-10-01 14:13:29 kycl4rk Exp $

=pod

=head1 NAME

Bio::GMOD::CMap::Admin::DataImport - import map data

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::DataImport;

  my $importer = Bio::GMOD::CMap::Admin::DataImport->new(db=>$db);
  $importer->import(
      map_set_id => $map_set_id,
      fh         => $fh,
  ) or print "Error: ", $importer->error, "\n";

=head1 DESCRIPTION

This module encapsulates the logic for importing all the various types
of maps into the database.

=cut

use strict;
use vars qw( $VERSION %DISPATCH %COLUMNS );
$VERSION  = (qw$Revision: 1.6 $)[-1];

use Data::Dumper;
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

    #
    # Examine map set.
    #
    $self->Print("Examining map set.\n");
    my $map_set_name = join ('-', @{ 
        $db->selectall_arrayref(
            q[
                select s.common_name, ms.map_set_name
                from   cmap_map_set ms,
                       cmap_species s
                where  ms.map_set_id=?
                and    ms.species_id=s.species_id
            ],
            {},
            ( $map_set_id )
        )
    } );

    my %maps = map { $_->[0], { map_id => $_->[1] } } @{
        $db->selectall_arrayref(
            q[
                select upper(map_name), map_id
                from   cmap_map
                where  map_set_id=?
            ],
            {},
            ( $map_set_id )
        )
    };
    $self->Print("$map_set_name currently has ", scalar keys %maps, " maps\n");

    #
    # Memorize the features currently on each map.
    #
    for my $map_name ( keys %maps ) {
        my $map_id   = $maps{ $map_name }{'map_id'} or return $self->error(
            "Map '$map_name' has no ID!"
        );

        my $features = $db->selectall_arrayref(
            q[
                select f.feature_name
                from   cmap_feature f
                where  f.map_id=?
            ],
            { Columns => {} },
            ( $map_id )
        );

        $maps{ $map_name }{'features'}{ $_ } = {} for @$features;

        $self->Print(
            "Map '$map_name' currently has ", scalar @$features, " features\n"
        );
    }

    #
    # Make column names lowercase, convert spaces to underscores 
    # (e.g., make "Feature Name" => "feature_name").
    #
    $self->Print("Checking headers.\n");
    chomp( my $header   = <$fh> );
    my @columns_present = map { s/\s+/_/g; lc $_ } split( FIELD_SEP, $header );

    for my $column_name ( @columns_present ) {
        if ( exists $COLUMNS{ $column_name } ) {
            $self->Print("Column '$column_name' OK.\n")
        }
        else {
            return $self->error("Column name '$column_name' is not valid.");
        }
    }

    $self->Print("Parsing file...\n");
    my ( %feature_type_ids, %feature_ids );
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
            $self->Print(
                "Feature type '$feature_type' doesn't exist.  Create?[Y/n] "
            );
            chomp( my $answer = <STDIN> );
            unless ( $answer =~ m/^[Nn]/ ) {
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
                                 is_visible, shape )
                        values ( ?, ?, ?, ?, ?, ? )
                    ],
                    {},
                    ( $feature_type_id, $feature_type_id, $feature_type, 
                      1, 1, 'line' 
                    )
                );

                $self->Print("Feature type '$feature_type' created.\n");
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
        my $map_id   = $maps{ uc $map_name }{'map_id'} || 0;
        unless ( $map_id ) {
            $map_id          = next_number(
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

            $self->Print("Created map $map_name ($map_id).\n");
            $maps{ uc $map_name }{'map_id'} = $map_id;
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
                    and    upper(feature_name)=?
                    and    start_position=?
                ],
                {},
                ( $map_id, uc $feature_name, $start )
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

            $maps{ uc $map_name }{'features'}{ $feature_name }{'updated'} = 1;
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
        $self->Print(
            "$action $feature_type '$feature_name' on map $map_name at $pos.\n"
        );
    }

    # 
    # Make sure the maps have legitimate starts and stops.
    # 
    for my $map_name ( sort keys %maps ) {
        my $map_id = $maps{ $map_name }{'map_id'};
        my ( $map_start, $map_stop ) = $db->selectrow_array(
            q[
                select map.start_position, map.stop_position
                from   cmap_map map
                where  map.map_id=?
            ],
            {},
            ( $map_id )
        );

        my ( $min_start, $max_start, $max_stop ) = $db->selectrow_array(
            q[
                select   min(f.start_position), 
                         max(f.start_position),
                         max(f.stop_position)
                from     cmap_feature f
                where    f.map_id=?
                group by f.map_id
            ],
            {},
            ( $map_id )
        );

        if ( 
            !defined $map_start      ||
            !defined $map_stop       ||
            $map_start <= $map_stop  ||
            $map_start > $min_start  ||
            $map_stop  < $max_start  ||
            ( defined $max_stop && $map_stop < $max_stop )
        ) {
            $min_start ||= 0;
            $max_start ||= 0;
            $max_stop  ||= 0;
            $max_stop    = $max_start > $max_stop ? $max_start : $max_stop;
            $map_start   = $min_start if $min_start < $map_start;
            $map_stop    = $max_stop  if $max_stop  > $map_stop;

            $db->do(
                q[
                    update cmap_map
                    set    start_position=?,
                           stop_position=?
                    where  map_id=?
                ],
                {},
                ( $map_start, $map_stop, $map_id )
            );
        }

        $self->Print(
            "Verified start ($map_start) and stop ($map_stop) ",
            "for map $map_name ($map_id).\n"
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
