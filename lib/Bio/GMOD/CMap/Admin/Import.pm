package Bio::GMOD::CMap::Admin::Import;
# vim: set ft=perl:

# $Id: Import.pm,v 1.44 2004-01-13 22:46:18 kycl4rk Exp $

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
$VERSION  = (qw$Revision: 1.44 $)[-1];

use Data::Dumper;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Utils 'next_number';
use Text::RecordParser;
use Text::ParseWords 'parse_line';
use XML::Simple;

use base 'Bio::GMOD::CMap';

use constant FIELD_SEP => "\t"; # use tabs for field separator
use constant STRING_RE => qr{\S+}; 
use constant RE_LOOKUP => {
    string => STRING_RE,
    number => NUMBER_RE,
};

use vars '$LOG_FH';

%COLUMNS = (
    map_name             => { is_required => 1, datatype => 'string' },
    map_accession_id     => { is_required => 0, datatype => 'string' },
    map_display_order    => { is_required => 0, datatype => 'number' },
    map_start            => { is_required => 0, datatype => 'number' },
    map_stop             => { is_required => 0, datatype => 'number' },
    feature_name         => { is_required => 1, datatype => 'string' },
    feature_accession_id => { is_required => 0, datatype => 'string' },
    feature_alt_name     => { is_required => 0, datatype => 'string' },
    feature_aliases      => { is_required => 0, datatype => 'string' },
    feature_start        => { is_required => 1, datatype => 'number' },
    feature_stop         => { is_required => 0, datatype => 'number' },
    feature_type         => { is_required => 1, datatype => 'string' },
    feature_note         => { is_required => 0, datatype => 'string' },
    is_landmark          => { is_required => 0, datatype => 'number' },
    feature_dbxref_name  => { is_required => 0, datatype => 'string' },
    feature_dbxref_url   => { is_required => 0, datatype => 'string' },
    feature_attributes   => { is_required => 0, datatype => 'string' },
);

# ----------------------------------------------------
sub import_tab {

=pod

=head2 import_tab

Imports tab-delimited file with the following fields:

    map_name *
    map_accession_id
    map_display_order
    map_start
    map_stop
    feature_name *
    feature_alt_name +
    feature_accession_id
    feature_aliases
    feature_start *
    feature_stop
    feature_type *
    feature_note +
    is_landmark
    feature_dbxref_name +
    feature_dbxref_url +
    feature_attributes

Fields with an asterisk are required.  Order of fields is not important.

Fields with a plus sign are deprecated.

When you import data for an map set that already has data, all
existing maps and features will be updated.  If you choose, any of the
pre-existing maps or features that aren't updated can be deleted (this
is what you'd want if the import file contains *all* the data you
have for the map set).

=head3 Feature Attributes

Feature attributes are defined as key:value pairs separated by
semi-colons, e.g.:

    Genbank ID: "BH245189"; Overgo: "SOG1776";

Which defines two separate attributes, one of type "Genbank ID" with
the value "BH245189" and another of type "Overgo" with the value of
"SOG1776."  It isn't strictly necessary to place double-quotes around
the values of the attributes, but it is recommended.  It is actually
required if the values themselves contain a delimiter (colons or
semi-colons), e.g.:

    DBXRef: "http://www.gramene.org/db/markers/marker_view?marker_name=CDO590"

If, in addition, you wish to include literal double-quotes in the
attribute values, they must be backslash-escapes, e.g.:

    DBXRef: "<a href=\"http://www.gramene.org/db/markers/marker_view?marker_name=CDO590\">View At Gramene</a>"

(But see below about importing actual cross-references.)

Version 0.08 of CMap added the "feature_note" field.  This is now
considered just another type of attribute.  The "feature_note" field
is provided only for backward-compatibility and will simply be added
as an attribute of type "Note."

Attribute names can be as wide as 255 characters while the values can
be quite large (exactly how large depends on which database you use
and how that field is defined).  The order of the attributes will be
used to determine the "display_order."

=head3 Feature Aliases

Feature aliases should be a comma-separated list of values.  They may
either occur in the "feature_aliases" (or "feature_alt_name" in order to 
remain backward-compatible) field or in the "feature_attributes" field 
with the key "aliases" (case-insensitive), e.g.:

    Aliases: "SHO29a, SHO29b"

Note that an alias which is the same (case-sensitive) as the feature's 
primary name will be discarded.

=head3 Cross-references

Any attribute of type "dbxref" or "xref" (case-insensitive) will be 
entered as an xref for the feature.  The field value should be enclosed
in double-quotes with the xref name separated from the URL by a 
semicolon like so:

    XRef: "View at Gramene;http://www.gramene.org/db/markers/marker_view?marker_name=CDO590"

The older "feature_dbxref*" fields are still accepted and are simply
appended to the list of xrefs.

=cut

    my ( $self, %args ) = @_;
    my $db              = $self->db           or die 'No database handle';
    my $map_set_id      = $args{'map_set_id'} or die      'No map set id';
    my $fh              = $args{'fh'}         or die     'No file handle';
    my $overwrite       = $args{'overwrite'}  ||                        0;
    $LOG_FH             = $args{'log_fh'}     ||                 \*STDOUT;

    my $admin = Bio::GMOD::CMap::Admin->new(
        data_source => $self->data_source
    ) or return $self->error(
        "Can't create admin object: ", Bio::GMOD::CMap::Admin->error
    );


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
            select map.map_name, 
                   map.map_id,
                   map.accession_id
            from   cmap_map map
            where  map.map_set_id=?
        ],
        {},
        ( $map_set_id )
    );

    my %maps     = map { uc $_->[0], { map_id => $_->[1] } } @$map_info;
    my %map_aids = map { $_->[2], $_->[0]                  } @$map_info;

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
            $maps{ $map_name }{'features'}{ $_->{'feature_id'} } = 0;
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
    my $parser = Text::RecordParser->new(
        fh              => $fh,
        field_separator => FIELD_SEP,
        header_filter   => sub { $_ = shift; s/\s+/_/g; lc $_ },
        field_filter    => sub { $_ = shift; s/^\s+|\s+$//g; $_ },
    );
    $parser->field_compute(
        'feature_aliases', sub { [ parse_line( ',', 0, shift() ) ] }
    );
    $parser->bind_header;

    my %required = 
        map  { $_, 0 }
        grep { $COLUMNS{ $_ }{'is_required'} }
        keys %COLUMNS;
        
    for my $column_name ( $parser->field_list ) {
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
    while ( my $record = $parser->fetchrow_hashref ) {
        for my $field_name ( $parser->field_list ) {
            my $field_attr = $COLUMNS{ $field_name } or next;
            my $field_val  = $record->{ $field_name };

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
        }

        my $feature_type    = $record->{'feature_type'};
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
                                 shape )
                        values ( ?, ?, ?, ?, ? )
                    ],
                    {},
                    ( $feature_type_id, $feature_type_id, $feature_type, 
                      1, 'line' 
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
        my $map_aid  = $record->{'map_accession_id'} || '';
        if ( $map_aid ) {
            $map_name = $map_aids{ $map_aid } || '';
        }
 
        $map_name ||= $record->{'map_name'};
        if ( exists $maps{ uc $map_name } ) { 
            $map_id = $maps{ uc $map_name }{'map_id'};
            $maps{ uc $map_name }{'touched'} = 1;
        }

        my $display_order = $record->{'map_display_order'} || 1;
        my $map_start     = $record->{'map_start'}         || 0;
        my $map_stop      = $record->{'map_stop'}          || 0;

        if ( 
            defined $map_start &&
            defined $map_stop  &&
            $map_start > $map_stop 
        ) {
            ( $map_start, $map_stop ) = ( $map_stop, $map_start );
        }

        #
        # If the map already exists, just remember stuff about it.
        #
        unless ( $map_id ) {
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
                             display_order
                           )
                    values ( ?, ?, ?, ?, ?, ?, ? )
                ],
                {}, 
                ( $map_id, $map_aid, $map_set_id, 
                  $map_name, $map_start, $map_stop, 
                  $display_order
                )
            );

            $self->Print("Created map $map_name ($map_id).\n");
            $maps{ uc $map_name }{'map_id'}  = $map_id;
            $maps{ uc $map_name }{'touched'} = 1;
        }

        $map_info{ $map_id }{'map_id'}         ||= $map_id;
        $map_info{ $map_id }{'map_set_id'}     ||= $map_set_id;
        $map_info{ $map_id }{'map_name'}       ||= $map_name;
        $map_info{ $map_id }{'start_position'} ||= $map_start;
        $map_info{ $map_id }{'stop_position'}  ||= $map_stop;
        $map_info{ $map_id }{'display_order'}  ||= $display_order;
        $map_info{ $map_id }{'accession_id'}   ||= $map_aid;

        #
        # Basic feature info
        #
        my $feature_name    = $record->{'feature_name'} 
            or warn "feature name blank! ", Dumper( $record ), "\n";
        my $accession_id    = $record->{'feature_accession_id'};
        my $aliases         = $record->{'feature_aliases'};
        my $attributes      = $record->{'feature_attributes'}  || '';
        my $start           = $record->{'feature_start'};
        my $stop            = $record->{'feature_stop'};
        my $is_landmark     = $record->{'is_landmark'} || 0;

        #
        # Feature attributes
        #
        my ( @fattributes, @xrefs );
        for my $attr ( parse_line( ';', 1, $attributes ) ) {
            my ( $key, $value ) = 
                map { s/^\s+|\s+$//g; s/^"|"$//g; $_ } 
                parse_line( ':', 1, $attr )
            ;

            if ( $key =~ /^alias(es)?$/i ) {
                push @$aliases, 
                    map { s/^\s+|\s+$//g; s/\\"/"/g; $_ } 
                    parse_line( ',', 1, $value )
                ;
            }
            elsif ( $key =~ /^(db)?xref$/i ) {
                $value =~ s/^"|"$//g;
                if ( my ( $xref_name, $xref_url ) = split(/;/, $value) ) {
                    push @xrefs, { name => $xref_name, url => $xref_url };
                }
            }
            else {
                $value =~ s/\\"/"/g;
                push @fattributes, { name => $key, value => $value };
            }
        }

        #
        # Backward-compatibility stuff
        #
        if ( my $alt_name = $record->{'feature_alt_name'} ) {
            push @$aliases, $alt_name;
        }

        if ( my $feature_note = $record->{'feature_note'} ) {
            push @fattributes, { name => 'Note', value => $feature_note };
        }

        my $dbxref_name = $record->{'feature_dbxref_name'} || '';
        my $dbxref_url  = $record->{'feature_dbxref_url'}  || '';

        if ( $dbxref_name && $dbxref_url ) {
            push @xrefs, { name => $dbxref_name, url => $dbxref_url };
        }

        #
        # Check start and stop positions, flip if necessary.
        #
        if ( 
            defined $start &&
            defined $stop  &&
            $start ne ''   &&
            $stop  ne ''   &&
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
        # If there's no accession ID, see if another feature
        # with the same name exists.
        #
        if ( !$feature_id && !$accession_id ) {
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
                           feature_name=?, start_position=?, stop_position=?,
                           is_landmark=?
                    where  feature_id=?
                ],
                {}, 
                ( $accession_id, $map_id, $feature_type_id, 
                  $feature_name, $start, $stop, $is_landmark,
                  $feature_id
                )
            );

            $maps{ uc $map_name }{'features'}{ $feature_id } = 1 if 
                defined $maps{ uc $map_name }{'features'}{ $feature_id };
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
                             feature_type_id, feature_name, 
                             start_position, stop_position,
                             is_landmark
                           )
                    values ( ?, ?, ?, ?, ?, ?, ?, ? )
                ],
                {}, 
                ( $feature_id, $accession_id, $map_id, $feature_type_id, 
                  $feature_name, $start, $stop, $is_landmark
                )
            );
        }

        for my $name ( @$aliases ) {
            next if $name eq $feature_name;
            $admin->feature_alias_create(
                feature_id => $feature_id,
                alias      => $name,
            ) or warn $admin->error;
        }

        if ( @fattributes ) {
            $admin->set_attributes( 
                object_id  => $feature_id, 
                table_name => 'cmap_feature',
                attributes => \@fattributes,
                overwrite  => $overwrite,
            ) or return $self->error( $admin->error );
        }

        if ( @xrefs ) {
            $admin->set_xrefs(
                object_id  => $feature_id,
                table_name => 'cmap_feature',
                overwrite  => $overwrite,
                xrefs      => \@xrefs,
            ) or return $self->error( $admin->error );
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
                       display_order=?
                where  map_id=?
            ],
            {}, 
            ( 
                $map->{'map_set_id'}, 
                $map->{'map_name'}, 
                $map->{'start_position'}, 
                $map->{'stop_position'}, 
                $map->{'display_order'}, 
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
                my ( $feature_id, $touched ) = 
                each %{ $maps{ uc $map_name }{'features'} } 
            ) {
                next if $touched;
                $self->Print(
                    "Feature '$feature_id' ",
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
        # Verify that the map start and stop coordinates at least
        # take into account the extremes of the feature coordinates.
        #
        $min_start = 0 unless defined $min_start;
        $max_start = 0 unless defined $max_start;
        $max_stop  = 0 unless defined $max_stop;
        $map_start = 0 unless defined $map_start;
        $map_stop  = 0 unless defined $map_stop;

        $max_stop    = $max_start if $max_start > $max_stop;
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

        $self->Print(
            "Verified map $map_name ($map_id) ",
            "start ($map_start) and stop ($map_stop).\n",
        );
    }

    $self->Print("Done\n");
    
    return 1;
}

# ----------------------------------------------------
sub import_objects {

=pod

=head2 import_objects

Imports an XML document containing CMap database objects.

=cut

    my ( $self, %args ) = @_;
    my $db              = $self->db           or die 'No database handle';
    my $fh              = $args{'fh'}         or die     'No file handle';
    my $overwrite       = $args{'overwrite'}  ||                        0;
    $LOG_FH             = $args{'log_fh'}     ||                 \*STDOUT;

    my $admin = Bio::GMOD::CMap::Admin->new(
        data_source => $self->data_source
    ) or return $self->error(
        "Can't create admin object: ", Bio::GMOD::CMap::Admin->error
    );

    my $import        =  XMLin( $fh,
        KeepRoot      => 0,
        SuppressEmpty => 1,
        ForceArray    => [ qw( 
            cmap_map_set map feature xref attribute cmap_feature_type 
            cmap_map_type cmap_species feature_alias cmap_evidence_type 
            cmap_feature_correspondence cmap_xref correspondence_evidence
        ) ],
    );

    #
    # Species.
    #
    my %species;
    for my $species ( @{ $import->{'cmap_species'} || [] } )  {
        $self->import_object(
            table_name  => 'cmap_species',
            pk_name     => 'species_id',
            object_type => 'species',
            object      => $species,
            field_names => [
                qw/accession_id common_name full_name display_order/
            ],
        ) or return;

        $species{ $species->{'object_id'} } = $species;
    }

    #
    # Map types.
    #
    my %map_types;
    for my $map_type ( @{ $import->{'cmap_map_type'} || [] } )  {
        $self->import_object(
            table_name  => 'cmap_map_type',
            pk_name     => 'map_type_id',
            object_type => 'map_type',
            object      => $map_type,
            field_names => [ qw/ accession_id map_type map_units color
                is_relational_map shape display_order width
            / ],
        ) or return;

        $map_types{ $map_type->{'object_id'} } = $map_type;
    }

    #
    # Feature types.
    #
    my %feature_types;
    for my $ft ( @{ $import->{'cmap_feature_type'} || [] } )  {
        $self->import_object(
            table_name  => 'cmap_feature_type',
            pk_name     => 'feature_type_id',
            object_type => 'feature_type',
            object      => $ft,
            field_names => [ qw/ accession_id feature_type shape
                color default_rank drawing_lane drawing_priority
            / ],
        ) or return;

        $feature_types{ $ft->{'object_id'} } = $ft;
    }

    #
    # Evidence types.
    #
    my %evidence_type_ids;
    for my $et ( @{ $import->{'cmap_evidence_type'} || [] } )  {
        $self->import_object(
            table_name  => 'cmap_evidence_type',
            pk_name     => 'evidence_type_id',
            object_type => 'evidence_type',
            object      => $et,
            field_names => [ qw/ accession_id evidence_type line_color rank / ],
        ) or return;

        $evidence_type_ids{ $et->{'object_id'} } = 
            $et->{'new_evidence_type_id'};
    }

    #
    # Map sets, maps, features
    #
    my %feature_ids;
    for my $ms ( @{ $import->{'cmap_map_set'} || [] } ) {
        $self->Print(
            "Importing map set '$ms->{map_set_name}' ($ms->{accession_id})\n"
        );

        my $species          = $species{ $ms->{'species_id'} };
        my $map_type         = $map_types{ $ms->{'map_type_id'} };
        $ms->{'species_id'}  = $species->{'new_species_id'} or 
            return $self->error('Cannot determine species id');
        $ms->{'map_type_id'} = $map_type->{'new_map_type_id'} or 
            return $self->error('Cannot determine map type id');

        $self->import_object(
            table_name  => 'cmap_map_set',
            pk_name     => 'map_set_id',
            object_type => 'map_set',
            object      => $ms,
            field_names => [ qw/ accession_id map_set_name short_name
                color shape is_enabled display_order can_be_reference_map
                published_on width species_id map_type_id
            / ],
        ) or return;

        for my $map ( @{ $ms->{'map'} || [] } ) {
            $map->{'map_set_id'} = $ms->{'new_map_set_id'};
            $self->import_object(
                table_name  => 'cmap_map',
                pk_name     => 'map_id',
                object_type => 'map',
                object      => $map,
                field_names => [ qw/ accession_id map_name display_order
                    start_position stop_position map_set_id
                / ],
            ) or return;

            for my $feature ( @{ $map->{'feature'} || [] } ) {
                my $ft = $feature_types{ $feature->{'feature_type_id'} };
                $feature->{'feature_type_id'} = $ft->{'new_feature_type_id'};
                $feature->{'map_id'}          = $map->{'new_map_id'};
                $self->import_object(
                    table_name  => 'cmap_feature',
                    pk_name     => 'feature_id',
                    object_type => 'feature',
                    object      => $feature,
                    field_names => [ qw/ map_id accession_id
                        feature_name start_position stop_position
                        is_landmark feature_type_id
                    / ],
                ) or return;

                $feature_ids{ $feature->{'object_id'} } = 
                    $feature->{'new_feature_id'};

                for my $alias ( @{ $feature->{'feature_alias'} || [] } ) {
                    $alias->{'feature_id'} = $feature->{'new_feature_id'};
                    $self->import_object(
                        table_name          => 'cmap_feature_alias',
                        pk_name             => 'feature_alias_id',
                        object_type         => 'feature_alias',
                        object              => $alias,
                        field_names         => [ qw/ feature_id alias / ],
                        lookup_accession_id => 0,
                    ) or return;
                }
            }
        }
    }

    #
    # Feature correspondences
    #
    for my $fc ( @{ $import->{'cmap_feature_correspondence'} || [] } )  {
        $fc->{'feature_id1'} = $feature_ids{ $fc->{'feature_id1'} };
        $fc->{'feature_id2'} = $feature_ids{ $fc->{'feature_id2'} };

        for my $e ( @{ $fc->{'correspondence_evidence'} } ) {
            $e->{'evidence_type_id'} = 
                $evidence_type_ids{ $e->{'evidence_type_id'} };
        }

        $self->import_object(
            table_name  => 'cmap_feature_correspondence',
            pk_name     => 'feature_correspondence_id',
            object_type => 'feature_correspondence',
            object      => $fc,
            field_names => [ qw/ 
                accession_id feature_aid1 feature_aid2 is_enabled  
                correspondence_evidence
            / ],
        ) or return;
    }

    #
    # Cross-references
    #
    for my $xref ( @{ $import->{'cmap_xref'} || [] } )  {
        $self->import_object(
            table_name  => 'cmap_xref',
            pk_name     => 'xref_id',
            object_type => 'xref',
            object      => $xref,
            field_names => [ qw/display_order xref_name xref_url table_name/ ],
            lookup_accession_id => 0,
        ) or return;
    }

    return 1;
}

# ----------------------------------------------------
sub import_object {
    my ( $self, %args )     = @_;
    my $object_type         = $args{'object_type'};
    my $object              = $args{'object'};
    my $table_name          = $args{'table_name'};
    my $field_names         = $args{'field_names'};
    my $pk_name             = $args{'pk_name'} || pk_name( $table_name );
    my $lookup_accession_id = defined $args{'lookup_accession_id'}
                              ? $args{'lookup_accession_id'} : 1;
    my $db                  = $self->db;
    my $admin               = $self->admin;

    my $new_object_id;

    if ( $lookup_accession_id ) {
        $new_object_id = $db->selectrow_array(
            qq[
                select $pk_name
                from   $table_name
                where  accession_id=?
            ],
            {},
            ( $object->{'accession_id'} )
        );
    }

    unless ( $new_object_id ) {
        my $create_method = $object_type . '_create';
        $new_object_id    =  $admin->$create_method(
            map { $_, $object->{ $_ } } @$field_names
        ) or return $self->error( $admin->error );
    }

    $object->{"new_$pk_name"} = $new_object_id;

    if ( @{ $object->{'attribute'} || [] } ) {
        $admin->set_attributes(
            table_name => $table_name,
            object_id  => $new_object_id,
            attributes => $object->{'attribute'},
        );
    }

    if ( @{ $object->{'xref'} || [] } ) {
        $admin->set_xrefs(
            table_name => $table_name,
            object_id  => $new_object_id,
            xrefs      => $object->{'xref'},
        );
    }

    return 1;
}

# ----------------------------------------------------
sub Print {
    my $self = shift;
    print $LOG_FH @_;
}

# ----------------------------------------------------
sub admin {
    my $self = shift;

    unless ( defined $self->{'admin'} ) {
        $self->{'admin'} = Bio::GMOD::CMap::Admin->new(
            data_source => $self->data_source
        ) or return $self->error(
            "Can't create admin object: ", Bio::GMOD::CMap::Admin->error
        );
    }

    return $self->{'admin'};
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
