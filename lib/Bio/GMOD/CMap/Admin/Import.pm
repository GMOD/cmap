package Bio::GMOD::CMap::Admin::Import;

# $Id: Import.pm,v 1.22 2003-03-13 20:03:02 kycl4rk Exp $

=pod

=head1 NAME

Bio::GMOD::CMap::Admin::Import - import map data

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::Import;

  my $importer = Bio::GMOD::CMap::Admin::Import->new(db=>$db);
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
$VERSION  = (qw$Revision: 1.22 $)[-1];

use Data::Dumper;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Utils 'next_number';

use base 'Bio::GMOD::CMap';

use constant FIELD_SEP => "\t"; # use tabs for field separator
use constant STRING_RE => qr{\S+};    #; qr{^[\w\s.()/-]+$};
use constant RE_LOOKUP => {
    string => STRING_RE,
    number => NUMBER_RE,
};

use vars '$LOG_FH';

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
    linkage_group        => { is_required => 0, datatype => 'string' },
    is_landmark          => { is_required => 0, datatype => 'number' },
    feature_dbxref_name  => { is_required => 0, datatype => 'string' },
    feature_dbxref_url   => { is_required => 0, datatype => 'string' },
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
    linkage_group
    is_landmark
    feature_dbxref_name
    feature_dbxref_url

Starred fields are required.  Order of fields is not important.

When you import data for an map set that already has data, all
existing maps and features will be updated.  If you choose, any of the
pre-existing maps or features that aren't updated can be deleted (this
is what you'd want if the import file contained *all* the data you
have for the map set).

=cut

    my ( $self, %args ) = @_;
    my $db              = $self->db           or die 'No database handle';
    my $map_set_id      = $args{'map_set_id'} or die      'No map set id';
    my $fh              = $args{'fh'}         or die     'No file handle';
    my $overwrite       = $args{'overwrite'}  ||                        0;
    $LOG_FH             = $args{'log_fh'}     ||                 \*STDOUT;

    #
    # Examine map set.
    #
    $self->Print("Importing map set data.\n");
    $self->Print("Examining map set.\n");
    my $map_set_name = join ('-', 
        $db->selectrow_array(
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
    );

    my $map_info = $db->selectall_arrayref(
        q[
            select upper(map.map_name), 
                   map.accession_id,
                   map.map_id
            from   cmap_map map
            where  map.map_set_id=?
        ],
        {},
        ( $map_set_id )
    );

    my %maps     = map { $_->[0], { map_id => $_->[1] } } @$map_info;
    my %map_aids = map { $_->[1], $_->[0]               } @$map_info;

    $self->Print(
        "'$map_set_name' currently has ", scalar keys %maps, " maps.\n"
    );

    #
    # Memorize the features currently on each map.
    #
    for my $map_name ( keys %maps ) {
        my $map_id = $maps{ $map_name }{'map_id'} or return $self->error(
            "Map '$map_name' has no ID!"
        );

        my $features = $db->selectall_arrayref(
            q[
                select f.feature_id, f.feature_name
                from   cmap_feature f
                where  f.map_id=?
            ],
            { Columns => {} },
            ( $map_id )
        );

        for ( @$features ) {
            $maps{ $map_name }{'features'}{ uc $_->{'feature_name'} } = {
                feature_id => $_->{'feature_id'}
            } 
        }

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
    my @columns_present = 
        map  { s/^\s+|\s+$//g; s/\s+/_/g; lc $_ } 
        split( FIELD_SEP, $header );

    my %required = 
        map  { $_, 0 }
        grep { $COLUMNS{ $_ }{'is_required'} }
        keys %COLUMNS;
        
    for my $column_name ( @columns_present ) {
        if ( exists $COLUMNS{ $column_name } ) {
            $self->Print("Column '$column_name' OK.\n");
            $required{ $column_name } = 1 if defined $required{ $column_name };
        }
        else {
            return $self->error("Column name '$column_name' is not valid.");
        }
    }

    if ( my @missing = grep { $required{ $_ } == 0 } keys %required ) {
        return $self->error("Missing following required columns: ".
            join(', ', @missing) 
        );
    }

    $self->Print("Parsing file...\n");
    my ( %feature_type_ids, %feature_ids, %map_info );
    while ( <$fh> ) {
        chomp;
        my @fields = split FIELD_SEP;
        return $self->error("Odd number of fields") 
            if @fields > @columns_present;

        my %record;
        for my $i ( 0 .. $#columns_present ) {
            my $field_name =  $columns_present[ $i ]  or next;
            my $field_attr =  $COLUMNS{ $field_name } or next;
            my $field_val  =  $fields[ $i ];
               $field_val  =~ s/^\s+|\s+$//g # remove leading/trailing space
                    if defined $field_val && $field_val =~ /\s/;

            if ( 
                $field_attr->{'is_required'} && 
                ( !defined $field_val || $field_val eq '' )
            ) {
                return $self->error("Field '$field_name' is required");
            }

            my $datatype = $field_attr->{'datatype'} || '';
            if ( $datatype && defined $field_val && $field_val ne '' ) {
                if ( my $regex = RE_LOOKUP->{ $datatype } ) {
                    #
                    # The following line forces the string a numeric 
                    # context where it's more likely to succeed in the
                    # regex.  This solves ".4" being bad according to
                    # the regex.
                    #
                    $field_val += 0 if $datatype eq 'number';
                    return $self->error(
                        "Value of '$field_name' is wrong.  " .
                        "Expected $datatype and got '$field_val'."
                    ) unless $field_val =~ $regex;
                }
            }
            elsif ( $datatype eq 'number' && $field_val eq '' ) {
                $field_val = undef;
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
        my ( $map_id, $map_name );
        my $map_aid  = $record{'map_accession_id'} || '';
        if ( $map_aid ) {
            $map_name = $map_aids{ $map_aid } || '';
        }
 
        $map_name ||= $record{'map_name'};
        if ( exists $maps{ uc $map_name } ) { 
            $map_id = $maps{ uc $map_name }{'map_id'};
            $maps{ uc $map_name }{'touched'} = 1;
        }

        my $linkage_group = $record{'linkage_group'};
        my $map_start     = $record{'map_start'}    || 0;
        my $map_stop      = $record{'map_stop'}     || 0;
        if ( 
            defined $map_start &&
            defined $map_stop  &&
            $map_stop > $map_start 
        ) {
            ( $map_start, $map_stop ) = ( $map_stop, $map_start );
        }

        #
        # If the map already exists, just remember stuff about it.
        #
        if ( $map_id ) {
            $map_info{ $map_id }{'map_id'}         ||= $map_id;
            $map_info{ $map_id }{'map_set_id'}     ||= $map_set_id;
            $map_info{ $map_id }{'map_name'}       ||= $map_name;
            $map_info{ $map_id }{'start_position'} ||= $map_start;
            $map_info{ $map_id }{'stop_position'}  ||= $map_stop;
            $map_info{ $map_id }{'linkage_group'}  ||= $linkage_group;
            $map_info{ $map_id }{'accession_id'}   ||= $map_aid;

        }
        else {
            $map_id          = next_number(
                db           => $db, 
                table_name   => 'cmap_map',
                id_field     => 'map_id',
            ) or die 'No map id';
            $map_aid ||= $map_id;

            $db->do(
                q[
                    insert
                    into   cmap_map 
                           ( map_id, accession_id, map_set_id, 
                             map_name, start_position, stop_position,
                             linkage_group
                           )
                    values ( ?, ?, ?, ?, ?, ?, ? )
                ],
                {}, 
                ( $map_id, $map_aid, $map_set_id, 
                  $map_name, $map_start, $map_stop, $linkage_group
                )
            );

            $self->Print("Created map $map_name ($map_id).\n");
            $maps{ uc $map_name }{'map_id'} = $map_id;
        }

        #
        # See if the acc. id already exists.
        #
        my $feature_name   = $record{'feature_name'}     #or next;
            or warn "feature name blank! ", Dumper( %record ), "\n";
        my $accession_id   = $record{'feature_accession_id'};
        my $alternate_name = $record{'feature_alt_name'}    || '';
        my $dbxref_name    = $record{'feature_dbxref_name'} || '';
        my $dbxref_url     = $record{'feature_dbxref_url'}  || '';
        my $start          = $record{'feature_start'};
        my $stop           = $record{'feature_stop'};
        my $is_landmark    = $record{'is_landmark'};

        if ( 
            defined $start &&
            defined $stop  &&
            $stop < $start 
        ) {
            ( $start, $stop ) = ( $stop, $start );
        }

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
        # Just see if another identical record exists.
        #
        unless ( $feature_id ) {
            $feature_id = $db->selectrow_array(
                q[
                    select feature_id
                    from   cmap_feature
                    where  map_id=?
                    and    upper(feature_name)=?
                ],
                {},
                ( $map_id, uc $feature_name )
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
                           start_position=?, stop_position=?,
                           dbxref_name=?, dbxref_url=?, is_landmark=?
                    where  feature_id=?
                ],
                {}, 
                ( $accession_id, $map_id, $feature_type_id, 
                  $feature_name, $alternate_name, 
                  $start, $stop, $dbxref_name, $dbxref_url, $is_landmark,
                  $feature_id
                )
            );

            $maps{uc $map_name}{'features'}{uc $feature_name}{'touched'} = 1;
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
                             start_position, stop_position,
                             dbxref_name, dbxref_url, is_landmark
                           )
                    values ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )
                ],
                {}, 
                ( $feature_id, $accession_id, $map_id, $feature_type_id, 
                  $feature_name, $alternate_name, $start, $stop,
                  $dbxref_name, $dbxref_url, $is_landmark
                )
            );
        }

        my $pos = join('-', map { defined $_ ? $_ : () } $start, $stop);
        $self->Print(
            "$action $feature_type '$feature_name' on map $map_name at $pos.\n"
        );
    }

    #
    # Go through and update all the maps.
    #
    for my $map ( values %map_info ) {
        $db->do(
            q[
                update cmap_map 
                set    map_set_id=?,
                       map_name=?, 
                       start_position=?, 
                       stop_position=?,
                       linkage_group=?
                where  map_id=?
            ],
            {}, 
            ( 
                $map->{'map_set_id'}, 
                $map->{'map_name'}, 
                $map->{'map_start'}, 
                $map->{'map_stop'}, 
                $map->{'linkage_group'}, 
                $map->{'map_id'},
            )
        );

        if ( $map->{'accession_id'} ) {
            $db->do(
                q[
                    update cmap_map 
                    set    accession_id=?
                    where  map_id=?
                ],
                {}, 
                ( $map->{'accession_id'}, $map->{'map_id'} )
            );
        }

        $self->Print("Updated map $map->{'map_name'} ($map->{'map_id'}).\n");
    }

    #
    # Go through existing maps and features, delete any that weren't 
    # updated, if necessary.
    #
    if ( $overwrite ) {
        my $admin = Bio::GMOD::CMap::Admin->new(
            data_source => $self->data_source
        ) or return $self->error(
            "Can't create admin object: ", Bio::GMOD::CMap::Admin->error
        );

        for my $map_name ( sort keys %maps ) {
            my $map_id = $maps{ uc $map_name }{'map_id'} or return $self->error(
                "Map '$map_name' has no ID!"
            );

            unless ( $maps{ uc $map_name }{'touched'} ) {
                $self->Print(
                    "Map '$map_name' ($map_id) ",
                    "wasn't updated or inserted, so deleting\n"
                );
                $admin->map_delete( map_id => $map_id ) or return 
                    $self->error( $admin->error );
                delete $maps{ uc $map_name };
                next;
            }

            while ( 
                my ( $feature_name, $feature ) =  
                    each %{ $maps{ uc $map_name }{'features'} } 
            ) {
                next if $feature->{'touched'};
                my $feature_id = $feature->{'feature_id'} or next;
                $self->Print(
                    "Feature '$feature_name' ($feature_id) ",
                    "wasn't updated or inserted, so deleting\n"
                );
                $admin->feature_delete( feature_id => $feature_id ) or return 
                    $self->error( $admin->error );
            }
        }
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

        #
        # For now, I've decided to always do this.  2003-02-11
        #
#        if ( 
#            !defined $map_start      ||
#            !defined $map_stop       ||
#            $map_start <= $map_stop  ||
#            $map_start > $min_start  ||
#            $map_stop  < $max_start  ||
#            ( defined $max_stop && $map_stop < $max_stop )
#        ) {
            $min_start ||= 0;
            $max_start ||= 0;
            $max_stop  ||= 0;
            $map_start   = 0 unless defined $map_start;
            $map_stop    = 0 unless defined $map_stop;
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
#        }

        $self->Print(
            "Verified map $map_name ($map_id) ",
            "start ($map_start) and stop ($map_stop).\n",
        );
    }

    $self->Print("Done\n");
    
    return 1;
}

sub Print {
    my $self = shift;
    print $LOG_FH @_;
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

=head1 COPYRIGHT

Copyright (c) 2002-3 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
