#!/usr/bin/perl
# vim: set ft=perl:

# $Id: cmap_admin.pl,v 1.84 2005-01-05 03:03:39 mwz444 Exp $

use strict;
use Pod::Usage;
use Getopt::Long;

use vars qw[ $VERSION ];
$VERSION = (qw$Revision: 1.84 $)[-1];

#
# Get command-line options
#
my ( $show_help, $show_version, $no_log, $datasource, $Quiet );

GetOptions(
    'h|help'         => \$show_help,       # Show help and exit
    'v|version'      => \$show_version,    # Show version and exit
    'no-log'         => \$no_log,          # Don't keep a log
    'd|datasource=s' => \$datasource,      # Default data source
    'q|quiet'        => \$Quiet,           # Only print necessities
) or pod2usage(2);

pod2usage(0) if $show_help;
if ($show_version) {
    print "$0 Version: $VERSION (CMap Version $Bio::GMOD::CMap::VERSION)\n";
    exit(0);
}

#
# Create a CLI object.
#
my $cli = Bio::GMOD::CMap::CLI::Admin->new(
    user       => $>,            # effective UID
    no_log     => $no_log,
    datasource => $datasource,
    file       => shift,
);

while (1) {
    my $action = $cli->show_greeting;
    $cli->$action();
}

# ----------------------------------------------------
package Bio::GMOD::CMap::CLI::Admin;

use strict;
use File::Path;
use File::Spec::Functions;
use IO::File;
use IO::Tee;
use Data::Dumper;
use Term::ReadLine;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Admin;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use Bio::GMOD::CMap::Utils;
use Bio::GMOD::CMap::Admin::Import();
use Bio::GMOD::CMap::Admin::Export();
use Bio::GMOD::CMap::Admin::MakeCorrespondences();
use Bio::GMOD::CMap::Admin::ImportCorrespondences();
use Bio::GMOD::CMap::Admin::ManageLinks();
use Benchmark;

use base 'Bio::GMOD::CMap';

use constant STR => 'string';
use constant NUM => 'number';
use constant OFS => "\t";       # ouput field separator
use constant ORS => "\n";       # ouput record separator

#
# Turn off output buffering.
#
$| = 1;

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->params( $config, qw[ file user no_log ] );
    unless ( $self->{'config'} ) {
        $self->{'config'} = Bio::GMOD::CMap::Config->new();
    }

    if ( $config->{'datasource'} ) {
        $self->data_source( $config->{'datasource'} ) or die $self->error;
    }
    return $self;
}

# ----------------------------------------------------
sub admin {
    my $self = shift;
    my $db   = $self->db or die $self->error;

    unless ( $self->{'admin'} ) {
        $self->{'admin'} = Bio::GMOD::CMap::Admin->new(
            db          => $db,
            data_source => $self->data_source,
        );
    }

    return $self->{'admin'};
}

# ----------------------------------------------------
sub file {
    my $self = shift;
    $self->{'file'} = shift if @_;
    return $self->{'file'} || '';
}

# ----------------------------------------------------
sub no_log {
    my $self = shift;
    my $arg  = shift;
    $self->{'no_log'} = $arg if defined $arg;

    unless ( defined $self->{'no_log'} ) {
        $self->{'no_log'} = 0;
    }
    return $self->{'no_log'};
}

# ----------------------------------------------------
sub user {
    my $self = shift;
    return $self->{'user'} || '';
}

# ----------------------------------------------------
sub log_filename {
    my $self = shift;
    unless ( $self->{'log_filename'} ) {
        my (
            $name,    $passwd, $uid,      $gid, $quota,
            $comment, $gcos,   $home_dir, $shell
          )
          = getpwuid( $self->user );

        my $filename = 'cmap_admin_log';
        my $i        = 0;
        my $path;
        while (1) {
            $path = catfile( $home_dir, $filename . '.' . $i );
            last unless -e $path;
            $i++;
        }

        $self->{'log_filename'} = $path;
    }

    return $self->{'log_filename'};
}

# ----------------------------------------------------
sub log_fh {
    my $self = shift;

    if ( $self->no_log ) {
        return *STDOUT;
    }
    else {
        unless ( $self->{'log_fh'} ) {
            my $path = $self->log_filename or return;
            my $fh = IO::Tee->new( \*STDOUT, ">$path" )
              or return $self->error("Unable to open '$path': $!");
            print $fh "Log file created '", scalar localtime, ".'\n";
            $self->{'log_fh'} = $fh;
        }
        return $self->{'log_fh'};
    }
}

# ----------------------------------------------------
sub term {
    my $self = shift;

    unless ( $self->{'term'} ) {
        $self->{'term'} = Term::ReadLine->new('Map Importer');
    }

    return $self->{'term'};
}

# ----------------------------------------------------
sub quit {
    my $self = shift;

    if ( defined $self->{'log_fh'} ) {
        my $log_fh = $self->log_fh;
        print $log_fh "Log file closed '", scalar localtime, ".'\n";
        print "Log file:  ", $self->log_filename, "\nNamaste.\n";
    }

    exit(0);
}

# ----------------------------------------------------
sub show_greeting {
    my $self      = shift;
    my $separator = '-=' x 10;

    print "\nCurrent data source: ", $self->data_source, "\n";

    my $action = $self->show_menu(
        title => join( "\n", $separator, '  --= Main Menu =--  ', $separator ),
        prompt  => 'What would you like to do?',
        display => 'display',
        return  => 'action',
        data    => [
            {
                action  => 'change_data_source',
                display => 'Change current data source',
            },
            {
                action  => 'create_map_set',
                display => 'Create new map set'
            },
            {
                action  => 'import_data',
                display => 'Import data',
            },
            {
                action  => 'export_data',
                display => 'Export data'
            },
            {
                action  => 'delete_data',
                display => 'Delete data',
            },
            {
                action  => 'make_name_correspondences',
                display => 'Make name-based correspondences'
            },
            {
                action  => 'reload_correspondence_matrix',
                display => 'Reload correspondence matrix'
            },
            {
                action  => 'purge_query_cache_menu',
                display => 'Purge the cache to view new data'
            },
            {
                action  => 'delete_duplicate_correspondences',
                display => 'Delete duplicate correspondences'
            },
            {
                action  => 'manage_links',
                display => 'Manage imported links'
            },
            {
                action  => 'quit',
                display => 'Quit'
            },
        ],
    );

    return $action;
}

# ----------------------------------------------------
sub change_data_source {
    my $self = shift;

    my $data_source = $self->show_menu(
        title   => 'Available Data Sources',
        prompt  => 'Which data source?',
        display => 'display',
        return  => 'value',
        data    => [
            map { { value => $_->{'name'}, display => $_->{'name'} } }
              @{ $self->data_sources }
        ],
    );

    $self->data_source($data_source) or warn $self->error, "\n";
}

# ----------------------------------------------------
sub create_map_set {
    my $self = shift;
    my $db = $self->db or die $self->error;
    print "Creating new map set.\n";

    my ( $map_type_aid, $map_type ) = $self->show_menu(
        title   => 'Available Map Types',
        prompt  => 'What type of map?',
        display => 'map_type',
        return  => 'map_type_aid,map_type',
        data    => $self->fake_selectall_arrayref(
            $self->map_type_data(), 'map_type_accession as map_type_aid',
            'map_type'
        )
    );
    die "No map types! Please use the config file to add some.\n"
      unless $map_type_aid;

    my ( $species_id, $common_name ) = $self->show_menu(
        title   => 'Available Species',
        prompt  => 'What species?',
        display => 'common_name',
        return  => 'species_id,common_name',
        data    => $db->selectall_arrayref(
            q[
                select   s.species_id, s.common_name
                from     cmap_species s
                order by common_name
            ],
            { Columns => {} },
        ),
    );
    die "No species!  Please use the web admin tool to create.\n"
      unless $species_id;

    print "Map Study Name (long): ";
    chomp( my $map_set_name = <STDIN> || 'New map set' );

    print "Short Name [$map_set_name]: ";
    chomp( my $short_name = <STDIN> );
    $short_name ||= $map_set_name;

    print "Accession ID (optional): ";
    chomp( my $map_set_aid = <STDIN> );

    my $map_color = $self->map_type_data( $map_type_aid, 'color' )
      || $self->config_data("map_color");

    $map_color = $self->show_question(
        question   => 'What color should this map set be?',
        default    => $map_color,
        valid_hash => COLORS,
    );

    my $map_shape = $self->map_type_data( $map_type_aid, 'shape' )
      || 'box';

    $map_shape = $self->show_question(
        question   => 'What shape should this map set be?',
        default    => $map_shape,
        valid_hash => VALID->{'map_shapes'},
    );

    my $map_width = $self->map_type_data( $map_type_aid, 'width' )
      || $self->config_data("map_width");

    $map_width = $self->show_question(
        question => 'What width should this map set be?',
        default  => $map_width,
    );

    my $map_units = $self->map_type_data( $map_type_aid, 'map_units' );
    my $is_relational_map =
      $self->map_type_data( $map_type_aid, 'is_relational_map' );

    my $map_set_id = next_number(
        db         => $db,
        table_name => 'cmap_map_set',
        id_field   => 'map_set_id',
      )
      or die 'No map set id';
    $map_set_aid ||= $map_set_id;

    print "OK to create set '$map_set_name' in data source '",
      $self->data_source, "'?\n[Y/n] ";
    chomp( my $answer = <STDIN> );
    return if $answer =~ m/^[Nn]/;

    $is_relational_map ||= 0;    #make sure this is set to something
    $db->do(
        q[
            insert
            into   cmap_map_set
                   ( map_set_id, accession_id, map_set_name, short_name,
                     species_id, map_type_accession, map_units, is_relational_map, 
		     color, shape, width
                   )
            values ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )
        ],
        {},
        (
            $map_set_id, $map_set_aid,       $map_set_name,
            $short_name, $species_id,        $map_type_aid,
            $map_units,  $is_relational_map, $map_color,
            $map_shape,  $map_width
        )
    );

    my $log_fh = $self->log_fh;
    print $log_fh "Map set $map_set_name created\n";

    $self->purge_query_cache(1);
}

# ----------------------------------------------------
sub delete_data {

    #
    # Deletes data.
    #
    my $self = shift;
    my $db   = $self->db or die $self->error;

    my $action = $self->show_menu(
        title   => 'Delete Options',
        prompt  => 'What do you want to delete?',
        display => 'display',
        return  => 'action',
        data    => [
            {
                action  => 'delete_map_set',
                display => 'Delete a map set (or maps within it)',
            },
            {
                action  => 'delete_correspondences',
                display => 'Feature correspondences',
            },
        ]
    );

    $self->$action($db);
    $self->purge_query_cache(1);
}

# ----------------------------------------------------
sub delete_correspondences {

    #
    # Deletes a map set.
    #
    my $self = shift;
    my $db   = $self->db or die $self->error;

    #
    # Get the map set.
    #
    my @map_set_ids = $self->show_menu(
        title      => 'Select Map Set(s)',
        prompt     => 'Select Map Set(s)',
        display    => 'common_name,short_name,accession_id',
        return     => 'map_set_id',
        allow_null => 0,
        allow_mult => 1,
        allow_all  => 1,
        data       => $db->selectall_arrayref(
            q[
                select   ms.map_set_id,
                         ms.accession_id,
                         ms.short_name,
                         s.common_name
                from     cmap_map_set ms,
                         cmap_species s
                where    ms.species_id=s.species_id
                order by common_name, short_name
            ],
            { Columns => {} },
        )
    );

    my %map_set_names = @map_set_ids
      ? map {
        $_->{'map_set_id'},
          join( '-', $_->{'species_name'}, $_->{'map_set_name'} ),
      } @{
        $db->selectall_arrayref(
            q[
                        select   ms.map_set_id, 
                                 ms.short_name as map_set_name,
                                 s.common_name as species_name
                        from     cmap_map_set ms,
                                 cmap_species s
                        where    ms.map_set_id in (]
              . join( ',', @map_set_ids ) . q[)
                        and      ms.species_id=s.species_id
                        order by common_name, short_name
                    ],
            { Columns => {} }
        )
      }
      : ();

    my @evidence_types = $self->show_menu(
        title      => 'Select Evidence Type (Optional)',
        prompt     => 'Select evidence types',
        display    => 'evidence_type',
        return     => 'evidence_type_aid,evidence_type',
        allow_null => 0,
        allow_mult => 1,
        allow_all  => 1,
        data       => $self->fake_selectall_arrayref(
            $self->evidence_type_data(),
            'evidence_type_accession as evidence_type_aid',
            'evidence_type'
        )
    );

    #
    # Confirm decisions.
    #
    print join( "\n",
        'OK to delete feature correspondences?',
        '  Data source          : ' . $self->data_source,
    );
    if (@map_set_ids) {
        print "\n  Map Set(s)           :\n",
          join( "\n", map { "    $_" } values %map_set_names );
    }
    if (@evidence_types) {
        print "\n  Evidence Types       :\n",
          join( "\n", map { "    $_->[1]" } @evidence_types );
    }
    print "\n[Y/n] ";
    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my $evidence_types =
      "'" . join( "','", map { $_->[0] } @evidence_types ) . "'";
    my %evidence_lookup = map { $_->[0], 1 } @evidence_types;
    my $admin           = $self->admin;
    my $log_fh          = $self->log_fh;
    for my $map_set_id (@map_set_ids) {
        my $fc_ids = $db->selectall_hashref(
            qq[
                select cl.feature_correspondence_id
                from   cmap_feature f,
                       cmap_map map,
                       cmap_correspondence_lookup cl,
                       cmap_feature_correspondence fc,
                       cmap_correspondence_evidence ce
                where  f.map_id=map.map_id
                and    map.map_set_id=?
                and    f.feature_id=cl.feature_id1
                and    cl.feature_correspondence_id=fc.feature_correspondence_id
                and    fc.feature_correspondence_id=ce.feature_correspondence_id
                and    ce.evidence_type_accession in ($evidence_types)
            ],
            'feature_correspondence_id',
            {},
            ($map_set_id)
        );

        print $log_fh "Deleting correspondences for ",
          $map_set_names{$map_set_id}, "\n";

        #
        # If there is more evidence supporting the correspondence,
        # then just remove the evidence, otherwise remove the
        # correspondence (which will remove all the evidence).
        #
        for my $fc_id ( keys %$fc_ids ) {
            my $all_evidence = $db->selectall_arrayref(
                qq[
                    select ce.correspondence_evidence_id,
                           ce.evidence_type_accession as evidence_type_aid
                    from   cmap_correspondence_evidence ce
                    where  ce.feature_correspondence_id=?
                ],
                { Columns => {} },
                ($fc_id)
            );

            my $no_evidence_deleted = 0;
            for my $evidence (@$all_evidence) {
                next
                  unless $evidence_lookup{ $evidence->{'evidence_type_aid'} };
                $admin->correspondence_evidence_delete(
                    correspondence_evidence_id =>
                      $evidence->{'correspondence_evidence_id'} );
                $no_evidence_deleted++;
            }

            if ( $no_evidence_deleted == scalar @$all_evidence ) {
                $admin->feature_correspondence_delete(
                    feature_correspondence_id => $fc_id );
            }
        }
    }
    $self->purge_query_cache(1);
}

# ----------------------------------------------------
sub delete_map_set {

    #
    # Deletes a map set.
    #
    my $self = shift;
    my $db   = $self->db or die $self->error;

    my $map_sets = $self->get_map_sets( allow_mult => 0, allow_null => 0 );
    return unless @{ $map_sets || [] };
    my $map_set    = $map_sets->[0];
    my $map_set_id = $map_set->{'map_set_id'};

    my $delete_what = $self->show_menu(
        title   => 'Delete',
        prompt  => 'How much to delete?',
        display => 'display',
        return  => 'value',
        data    => [
            { value => 'entire', display => 'Delete entire map set' },
            { value => 'some',   display => 'Delete just some maps in it' }
        ],
    );

    my @map_ids;
    if ( $delete_what eq 'some' ) {
        @map_ids = $self->show_menu(
            title      => 'Restrict by Map (optional)',
            prompt     => 'Select one or more maps',
            display    => 'map_name',
            return     => 'map_id',
            allow_null => 1,
            allow_mult => 1,
            data       => $db->selectall_arrayref(
                q[
                    select   map.map_id, 
                             map.map_name
                    from     cmap_map map
                    where    map.map_set_id=?
                    order by map_name
                ],
                { Columns => {} },
                ($map_set_id)
            ),
        );
    }

    my $map_names;
    if (@map_ids) {
        $map_names = $db->selectcol_arrayref(
            q[
                select map.map_name
                from   cmap_map map
                where  map.map_id in (] . join( ', ', @map_ids ) . q[)
            ]
        );
    }

    print join(
        "\n",
        map { $_ || () } 'OK to delete?',
        '  Data source : ' . $self->data_source,
        '  Map Set     : '
          . $map_set->{'species_name'} . '-'
          . $map_set->{'map_set_name'},
        (
            @{ $map_names || [] }
            ? '  Maps        : ' . join( ', ', @$map_names )
            : ''
        ),
        '[Y/n] ',
    );

    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my $admin  = $self->admin;
    my $log_fh = $self->log_fh;
    if (@map_ids) {
        for my $map_id (@map_ids) {
            print $log_fh "Deleting map ID '$map_id.'\n";
            $admin->map_delete( map_id => $map_id )
              or return $self->error( $admin->error );
        }
    }
    else {
        print $log_fh "Deleting map set "
          . $map_set->{'species_name'} . '-'
          . $map_set->{'map_set_name'} . "'\n";
        $admin->map_set_delete( map_set_id => $map_set_id )
          or return $self->error( $admin->error );
    }
    $self->purge_query_cache(1);
}

# ----------------------------------------------------
sub export_data {

    #
    # Exports data.
    #
    my $self = shift;
    my $db   = $self->db or die $self->error;

    my $action = $self->show_menu(
        title   => 'Data Export Options',
        prompt  => 'What do you want to export?',
        display => 'display',
        return  => 'action',
        data    => [
            {
                action  => 'export_as_text',
                display => 'Data in tab-delimited CMap format',
            },
            {
                action  => 'export_as_sql',
                display => 'Data as SQL INSERT statements',
            },
            {
                action  => 'export_objects',
                display => 'Database objects [experimental]',
            },
        ]
    );

    $self->$action();
}

# ----------------------------------------------------
sub export_as_text {

    #
    # Exports data in tab-delimited import format.
    #
    my $self   = shift;
    my $db     = $self->db or die $self->error;
    my $log_fh = $self->log_fh;

    my @col_names = qw(
      map_accession_id
      map_name
      map_start
      map_stop
      feature_accession_id
      feature_name
      feature_aliases
      feature_start
      feature_stop
      feature_type_accession
      feature_dbxref_name
      feature_dbxref_url
      is_landmark
      feature_attributes
    );

    my $map_sets      = $self->get_map_sets;
    my $feature_types = $self->get_feature_types;

    my @exclude_fields = $self->show_menu(
        title      => 'Select Fields to Exclude',
        prompt     => 'Which fields do you want to EXCLUDE from export?',
        display    => 'field_name',
        return     => 'field_name',
        allow_null => 1,
        allow_mult => 1,
        data       => [ map { { field_name => $_ } } @col_names ],
    );

    if ( @exclude_fields == @col_names ) {
        print "\nError:  Can't exclude all the fields!\n";
        return;
    }

    my $dir = _get_dir() or return;

    my @map_set_names;
    if ( @{ $map_sets || [] } ) {
        @map_set_names =
          map { join( '-', $_->{'species_name'}, $_->{'map_set_name'} ) }
          @$map_sets;
    }
    else {
        @map_set_names = ('All');
    }

    if ( !@$feature_types ) {
        $feature_types = [ [ 'All', 'All' ], ];
    }

    my $excluded_fields =
      @exclude_fields ? join( ', ', @exclude_fields ) : 'None';

    #
    # Confirm decisions.
    #
    print join( "\n",
        'OK to export?',
        '  Data source     : ' . $self->data_source,
        "  Map Sets        :\n" . join( "\n", map { "    $_" } @map_set_names ),
        "  Feature Types   :\n"
          . join( "\n", map { "    $_->[2]" } @$feature_types ),
        "  Exclude Fields  : $excluded_fields",
        "  Directory       : $dir",
        "[Y/n] " );
    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my %exclude = map { $_, 1 } @exclude_fields;
    @col_names = grep { !$exclude{$_} } @col_names;

    my $ft_sql = q[
        select   f.feature_id, 
                 f.accession_id as feature_accession_id,
                 f.feature_name,
                 f.start_position as feature_start,
                 f.stop_position as feature_stop,
                 f.is_landmark,
                 f.feature_type_accession as feature_type_aid,
                 map.map_name, 
                 map.accession_id as map_accession_id,
                 map.start_position as map_start,
                 map.stop_position as map_stop
        from     cmap_feature f,
                 cmap_map map
        where    f.map_id=?
        and      f.map_id=map.map_id
    ];
    $ft_sql .=
      "and f.feature_type_accession in ('"
      . join( "','", map { $_->[0] } @$feature_types ) . "') "
      if @$feature_types;
    $ft_sql .= 'order by f.start_position';

    for my $map_set (@$map_sets) {
        my $map_set_id   = $map_set->{'map_set_id'};
        my $map_set_name = $map_set->{'map_set_name'};
        my $species_name = $map_set->{'species_name'};
        my $file_name    = join( '-', $species_name, $map_set_name );
        $file_name =~ tr/a-zA-Z0-9-/_/cs;
        $file_name = "$dir/$file_name.dat";

        print $log_fh "Dumping '$species_name-$map_set_name' to '$file_name'\n";
        open my $fh, ">$file_name" or die "Can't write to $file_name: $!\n";
        print $fh join( OFS, @col_names ), ORS;

        my $maps = $db->selectall_arrayref(
            q[
                select   map_id
                from     cmap_map
                where    map_set_id=?
                order by map_name
            ],
            { Columns => {} },
            ($map_set_id)
        );

        my $attributes = $db->selectall_arrayref(
            q[
                select object_id, 
                       attribute_name,
                       attribute_value
                from   cmap_attribute
                where  table_name=?
            ],
            {},
            ('cmap_feature')
        );

        my %attr_lookup = ();
        for my $a (@$attributes) {
            push @{ $attr_lookup{ $a->[0] } }, qq[$a->[1]: "$a->[2]"];
        }

        for my $map (@$maps) {
            my $features = $db->selectall_arrayref(
                $ft_sql,
                { Columns => {} },
                ( $map->{'map_id'} )
            );

            my $aliases = $db->selectall_arrayref(
                q[
                    select fa.feature_id,
                           fa.alias 
                    from   cmap_feature_alias fa,
                           cmap_feature f
                    where  fa.feature_id=f.feature_id
                    and    f.map_id=?
                ],
                {},
                ( $map->{'map_id'} )
            );

            my %alias_lookup = ();
            for my $a (@$aliases) {
                push @{ $alias_lookup{ $a->[0] } }, $a->[1];
            }

            for my $feature (@$features) {
                $feature->{'stop_position'} = undef
                  if $feature->{'stop_position'} < $feature->{'start_position'};

                $feature->{'feature_attributes'} = join( '; ',
                    @{ $attr_lookup{ $feature->{'feature_id'} } || [] } );

                $feature->{'feature_aliases'} = join( ',',
                    map { s/"/\\"/g ? qq["$_"] : $_ }
                      @{ $alias_lookup{ $feature->{'feature_id'} || [] } } );

                print $fh join( OFS, map { $feature->{$_} } @col_names ), ORS;
            }
        }

        close $fh;
    }
}

# ----------------------------------------------------
sub export_as_sql {

    #
    # Exports data as SQL INSERT statements.
    #
    my $self   = shift;
    my $db     = $self->db or die $self->error;
    my $log_fh = $self->log_fh;
    my @tables = (
        {
            name   => 'cmap_attribute',
            fields => {
                attribute_id    => NUM,
                table_name      => STR,
                object_id       => NUM,
                display_order   => NUM,
                is_public       => NUM,
                attribute_name  => STR,
                attribute_value => STR,
            }
        },
        {
            name   => 'cmap_correspondence_evidence',
            fields => {
                correspondence_evidence_id => NUM,
                accession_id               => STR,
                feature_correspondence_id  => NUM,
                evidence_type_accession    => STR,
                score                      => NUM,
                rank                       => NUM,
            }
        },
        {
            name   => 'cmap_correspondence_lookup',
            fields => {
                feature_id1               => NUM,
                feature_id2               => NUM,
                feature_correspondence_id => NUM,

            }
        },
        {
            name   => 'cmap_correspondence_matrix',
            fields => {
                reference_map_aid     => STR,
                reference_map_name    => STR,
                reference_map_set_aid => STR,
                reference_species_aid => STR,
                link_map_aid          => STR,
                link_map_name         => STR,
                link_map_set_aid      => STR,
                link_species_aid      => STR,
                no_correspondences    => NUM,
            }
        },
        {
            name   => 'cmap_feature',
            fields => {
                feature_id             => NUM,
                accession_id           => STR,
                map_id                 => NUM,
                feature_type_accession => STR,
                feature_name           => STR,
                is_landmark            => NUM,
                start_position         => NUM,
                stop_position          => NUM,
                default_rank           => NUM,
            }
        },
        {
            name   => 'cmap_feature_alias',
            fields => {
                feature_alias_id => NUM,
                feature_id       => NUM,
                alias            => STR,
            }
        },
        {
            name   => 'cmap_feature_correspondence',
            fields => {
                feature_correspondence_id => NUM,
                accession_id              => STR,
                feature_id1               => NUM,
                feature_id2               => NUM,
                is_enabled                => NUM,
            }
        },
        {
            name   => 'cmap_map',
            fields => {
                map_id         => NUM,
                accession_id   => STR,
                map_set_id     => NUM,
                map_name       => STR,
                display_order  => NUM,
                start_position => NUM,
                stop_position  => NUM,
            }
        },
        {
            name   => 'cmap_next_number',
            fields => {
                table_name  => STR,
                next_number => NUM,
            }
        },
        {
            name   => 'cmap_species',
            fields => {
                species_id    => NUM,
                accession_id  => STR,
                common_name   => STR,
                full_name     => STR,
                display_order => STR,
            }
        },
        {
            name   => 'cmap_map_set',
            fields => {
                map_set_id           => NUM,
                accession_id         => STR,
                map_set_name         => STR,
                short_name           => STR,
                map_type_accession   => STR,
                species_id           => NUM,
                published_on         => STR,
                can_be_reference_map => NUM,
                display_order        => NUM,
                is_enabled           => NUM,
                shape                => STR,
                color                => STR,
                width                => NUM,
                map_units            => STR,
                is_relational_map    => NUM,
            },
        },
        {
            name   => 'cmap_xref',
            fields => {
                xref_id       => NUM,
                table_name    => STR,
                object_id     => NUM,
                display_order => NUM,
                xref_name     => STR,
                xref_url      => STR,
            }
        },
    );

    #
    # Ask user what/how/where to dump.
    #
    my @dump_tables = $self->show_menu(
        title     => 'Select Tables',
        prompt    => 'Which tables do you want to export?',
        display   => 'table_name',
        return    => 'table_name',
        allow_all => 1,
        data      => [ map { { 'table_name', $_->{'name'} } } @tables ],
    );

    print "Add 'TRUNCATE TABLE' statements? [Y/n] ";
    chomp( my $answer = <STDIN> );
    $answer ||= 'y';
    my $add_truncate = $answer =~ m/^[yY]/;

    my $file;
    for ( ; ; ) {
        my $default = './cmap_dump.sql';
        print "Where would you like to write the file?\n",
          "['q' to quit, '$default' is default] ";
        chomp( my $user_file = <STDIN> );
        $user_file ||= $default;

        if ( -d $user_file ) {
            print "'$user_file' is a directory.  Please give me a file path.\n";
            next;
        }
        elsif ( -e _ && -r _ ) {
            print "'$user_file' exists.  Overwrite? [Y/n] ";
            chomp( my $overwrite = <STDIN> );
            $overwrite ||= 'y';
            if ( $overwrite =~ m/^[yY]/ ) {
                $file = $user_file;
                last;
            }
            else {
                print "OK, I won't overwrite.  Try again.\n";
                next;
            }
        }
        elsif ( -e _ ) {
            print "'$user_file' exists & isn't writable by you.  Try again.\n";
            next;
        }
        else {
            $file = $user_file;
            last;
        }
    }

    my $quote_escape = $self->show_menu(
        title  => 'Quote Style',
        prompt => "How should embeded quotes be escaped?\n"
          . 'Hint: Oracle and Sybase like [1], MySQL likes [2]',
        display => 'display',
        return  => 'action',
        data    => [
            { display => 'Doubled',   action => 'doubled' },
            { display => 'Backslash', action => 'backslash' },
        ],
    );

    #
    # Confirm decisions.
    #
    print join( "\n",
        'OK to export?',
        '  Data source  : ' . $self->data_source,
        '  Tables       : ' . join( ', ', @dump_tables ),
        '  Add Truncate : ' . ( $add_truncate ? 'Yes' : 'No' ),
        "  File         : $file",
        "  Escape Quotes: $quote_escape",
        "[Y/n] " );

    chomp( $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    print $log_fh "Making SQL dump of tables to '$file'\n";
    open my $fh, ">$file" or die "Can't write to '$file': $!\n";
    print $fh "--\n-- Dumping data for CMap v", $Bio::GMOD::CMap::VERSION,
      "\n-- Produced by cmap_admin.pl v", $main::VERSION, "\n-- ",
      scalar localtime, "\n--\n";

    my %dump_tables = map { $_, 1 } @dump_tables;
    for my $table (@tables) {
        my $table_name = $table->{'name'};
        next if %dump_tables && !$dump_tables{$table_name};

        print $log_fh "Dumping data for '$table_name.'\n";
        print $fh "\n--\n-- Data for '$table_name'\n--\n";
        if ($add_truncate) {
            print $fh "TRUNCATE TABLE $table_name;\n";
        }

        my %fields    = %{ $table->{'fields'} };
        my @fld_names = sort keys %fields;

        my $insert =
          "INSERT INTO $table_name (" . join( ', ', @fld_names ) . ') VALUES (';

        my $sth =
          $db->prepare(
            'select ' . join( ', ', @fld_names ) . " from $table_name" );
        $sth->execute;
        while ( my $rec = $sth->fetchrow_hashref ) {
            my @vals;
            for my $fld (@fld_names) {
                my $val = $rec->{$fld};
                if ( $fields{$fld} eq STR ) {

                    # Escape existing single quotes.
                    $val =~ s/'/\\'/g if $quote_escape eq 'backslash';
                    $val =~ s/'/''/g  if $quote_escape eq 'doubled';     #'
                    $val = defined $val ? qq['$val'] : qq[''];
                }
                else {
                    $val = defined $val ? $val : 'NULL';
                }
                push @vals, $val;
            }

            print $fh $insert, join( ', ', @vals ), ");\n";
        }
    }

    print $fh "\n--\n-- Finished dumping Cmap data\n--\n";
}

# ----------------------------------------------------
sub export_objects {

    #
    # Exports serialized database objects.
    #
    my $self = shift;

    my $export_path;
    for ( ; ; ) {
        my $dir = _get_dir() or return;

        print 'What file name [cmap_export.xml]? ';
        chomp( my $file_name = <STDIN> );
        $file_name ||= 'cmap_export.xml';

        $export_path = catfile( $dir, $file_name );

        if ( -e $export_path ) {
            print "The file '$export_path' exists.  Overwrite? [Y/n] ";
            chomp( my $answer = <STDIN> );
            if ( $answer =~ /^[Nn]/ ) {
                next;
            }
            else {
                last;
            }
        }

        last if $export_path;
    }

    #
    # Which objects?
    #
    my @objects = $self->show_menu(
        title      => 'Which objects?',
        prompt     => 'Please select the objects you wish to export',
        display    => 'object_name',
        return     => 'object_type,object_name',
        allow_null => 0,
        allow_mult => 1,
        allow_all  => 1,
        data       => [
            {
                object_type => 'cmap_map_set',
                object_name => 'Map Sets',
            },
            {
                object_type => 'cmap_species',
                object_name => 'Species',
            },
            {
                object_type => 'cmap_feature_correspondence',
                object_name => 'Feature Correspondence',
            },
            {
                object_type => 'cmap_xref',
                object_name => 'Cross-references',
            },
        ]
    );

    my @db_objects   = map { $_->[0] } @objects;
    my @object_names = map { $_->[1] } @objects;

    my @confirm = (
        '  Data source  : ' . $self->data_source,
        '  Objects      : ' . join( ', ', @object_names ),
        "  File name    : $export_path",
    );

    my ( $map_sets, $feature_types );
    if ( grep { /map_set/ } @db_objects ) {
        $map_sets      = $self->get_map_sets;
        $feature_types = $self->get_feature_types;
        my @ft_names = map { $_->{'feature_type'} } @$feature_types;
        my @map_set_names =
          map {
                $_->{'species_name'} . '-'
              . $_->{'map_set_name'} . ' ('
              . $_->{'map_type'} . ')'
          } @$map_sets;

        @map_set_names = ('All') unless @map_set_names;
        @ft_names      = ('All') unless @ft_names;

        push @confirm,
          (
            "  Map Sets     :\n"
              . join( "\n", map { "    $_" } @map_set_names ),
            "  Feature Types:\n" . join( "\n", map { "    $_" } @ft_names ),
          );
    }

    #
    # Confirm decisions.
    #
    print join( "\n", 'OK to export?', @confirm, '[Y/n] ' );
    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my $exporter =
      Bio::GMOD::CMap::Admin::Export->new( data_source => $self->data_source );

    $exporter->export(
        objects       => \@db_objects,
        output_path   => $export_path,
        log_fh        => $self->log_fh,
        map_sets      => $map_sets,
        feature_types => $feature_types,
      )
      or do {
        print "Error: ", $exporter->error, "\n";
        return;
      };

    return 1;
}

# ----------------------------------------------------
sub get_map_sets {

    #
    # Help user choose map sets.
    #
    my ( $self, %args ) = @_;
    my $allow_mult = defined $args{'allow_mult'} ? $args{'allow_mult'} : 1;
    my $allow_null = defined $args{'allow_null'} ? $args{'allow_null'} : 1;
    my $db     = $self->db or die $self->error;
    my $log_fh = $self->log_fh;

    if ( my $explanation = $args{'explanation'} ) {
        print join( "\n",
            "------------------------------------------------------",
            "NOTE: $explanation",
            "------------------------------------------------------",
        );
    }

    my $select = $self->show_menu(
        title   => 'Map Set Selection Method',
        prompt  => 'How would you like to select map sets?',
        display => 'display',
        return  => 'action',
        data    => [
            {
                action  => 'by_accession_id',
                display => 'Supply Map Set Accession ID',
            },
            {
                action  => 'by_menu',
                display => 'Use Menus'
            },
        ],
    );

    my $map_sets;
    if ( $select eq 'by_accession_id' ) {
        print 'Please supply the accession IDs separated by commas or spaces: ';
        chomp( my $answer = <STDIN> );
        my @accessions = split( /[,\s+]/, $answer );
        return unless @accessions;
        for my $acc (@accessions) {
            my $sth = $db->prepare(
                q[
                    select   ms.map_set_id, 
                             ms.accession_id as map_set_aid,
                             ms.short_name as map_set_name,
                             s.common_name as species_name,
                             ms.map_type_accession as map_type_aid
                    from     cmap_map_set ms,
                             cmap_species s
                    where    ms.accession_id=?
                    and      ms.species_id=s.species_id
                ]
            );
            $sth->execute($acc);
            push @{$map_sets}, $sth->fetchrow_hashref;
        }
        foreach my $row ( @{$map_sets} ) {
            $row->{'map_type'} =
              $self->map_type_data( $row->{'map_type_aid'}, 'map_type' );
        }
        return unless @$map_sets;
    }
    else {
        my $map_types =
          $self->fake_selectall_arrayref( $self->map_type_data(),
            'map_type_accession as map_type_aid', 'map_type' );
        $map_types = sort_selectall_arrayref( $map_types, 'map_type' );
        die "No map types! Please use the config file to create.\n"
          unless @$map_types;

        my @map_types = $self->show_menu(
            title      => 'Restrict by Map Set by Map Types',
            prompt     => 'Limit map sets by which map types?',
            display    => 'map_type',
            return     => 'map_type_aid,map_type',
            allow_null => $allow_null,
            allow_mult => $allow_mult,
            data       => $map_types,
        );
        if ( @map_types and ref $map_types[0] ne 'ARRAY' ) {
            @map_types = @{ [ [@map_types] ] };
        }

        my $species_sql = q[
            select   distinct s.species_id, 
                     s.common_name
            from     cmap_species s,
                     cmap_map_set ms
            where    s.species_id=ms.species_id
        ];
        $species_sql .=
          "and ms.map_type_accession in ('"
          . join( "','", map { $_->[0] } @map_types ) . "') "
          if @map_types;
        $species_sql .= 'order by common_name';
        my $species =
          $db->selectall_arrayref( $species_sql, { Columns => {} } );
        die "No species! Please use the web admin tool to create.\n"
          unless @$species;

        my $species_ids = $self->show_menu(
            title      => 'Restrict by Species',
            prompt     => 'Limit by which species?',
            display    => 'common_name',
            return     => 'species_id',
            allow_null => $allow_null,
            allow_mult => $allow_mult,
            data       => $species,
        );

        if ( ref $species_ids ne 'ARRAY' ) {
            $species_ids = [ $species_ids, ];
        }

        my $map_set_sql = q[
            select   ms.map_set_id,
                     ms.accession_id,
                     ms.short_name,
                     s.common_name,
                     ms.map_type_accession as map_type_aid
            from     cmap_map_set ms,
                     cmap_species s
            where    ms.species_id=s.species_id
        ];
        $map_set_sql .=
          'and ms.species_id in (' . join( ',', @$species_ids ) . ') '
          if ( @$species_ids and defined $species_ids->[0] );
        $map_set_sql .=
          "and ms.map_type_accession in ('"
          . join( "','", map { $_->[0] } @map_types ) . "') "
          if @map_types;
        $map_set_sql .= 'order by short_name';
        my $ms_choices =
          $db->selectall_arrayref( $map_set_sql, { Columns => {} } );

        foreach my $row ( @{$ms_choices} ) {
            $row->{'map_type'} =
              $self->map_type_data( $row->{'map_type_aid'}, 'map_type' );
        }

        my $map_set_ids = $self->show_menu(
            title      => 'Restrict by Map Sets',
            prompt     => 'Limit by which map sets?',
            display    => 'map_type,common_name,short_name',
            return     => 'map_set_id',
            allow_null => $allow_null,
            allow_mult => $allow_mult,
            data       => $ms_choices,
        );
        if ( ref $map_set_ids ne 'ARRAY' ) {
            $map_set_ids = [ $map_set_ids, ];
        }

        my $where;
        $where .= 'and ms.species_id in  (' . join( ',', @$species_ids ) . ') '
          if ( @$species_ids and defined $species_ids->[0] );
        $where .=
          "and ms.map_type_accession in ('"
          . join( "','", map { $_->[0] } @map_types ) . "') "
          if @map_types;
        $where .= 'and ms.map_set_id in  (' . join( ',', @$map_set_ids ) . ') '
          if ( @$map_set_ids and defined $map_set_ids->[0] );

        $map_set_sql = qq[
            select   ms.map_set_id, 
                     ms.accession_id as map_set_aid,
                     ms.short_name as map_set_name,
                     s.common_name as species_name,
                     ms.map_type_accession as map_type_aid
            from     cmap_map_set ms,
                     cmap_species s
            where    ms.species_id=s.species_id
            $where
        ];
        $map_set_sql .= 'order by common_name, short_name';

        $map_sets = $db->selectall_arrayref( $map_set_sql, { Columns => {} } );
        foreach my $row ( @{$map_sets} ) {
            $row->{'map_type'} =
              $self->map_type_data( $row->{'map_type_aid'}, 'map_type' );
        }
    }
    return $map_sets;
}

# ----------------------------------------------------
sub get_feature_types {

    #
    # Allow selection of feature types
    #
    my ( $self, %args ) = @_;
    my @map_set_ids = @{ $args{'map_set_ids'} || [] };
    my $ft_sql;
    my $ft_sql_data;
    if (@map_set_ids) {
        my $db = $self->db or die $self->error;
        $ft_sql_data = $db->selectall_arrayref(
            qq[
            select   distinct  
                     f.feature_type_accession as feature_type_aid
            from     cmap_map_set ms,
                     cmap_map map,
                     cmap_feature f
            where    ms.map_set_id in (] . join( ',', @map_set_ids ) . qq[
            and      ms.map_set_id=map.map_set_id
            and      map.map_id=f.map_id
            order by feature_type_aid
	    ], { Columns => {} }
        );
        foreach my $row ( @{$ft_sql_data} ) {
            $row->{'feature_type'} =
              $self->feature_type_data( $row->{'feature_type_aid'},
                'feature_type' );
        }

    }
    else {
        $ft_sql_data =
          $self->fake_selectall_arrayref( $self->feature_type_data(),
            'feature_type_aid', 'feature_type' );
    }

    my @feature_types = $self->show_menu(
        title      => 'Restrict by Feature Types',
        prompt     => 'Limit export by feature types?',
        display    => 'feature_type',
        return     => 'feature_type_aid,feature_type',
        allow_null => 1,
        allow_mult => 1,
        data       => $ft_sql_data,
    );

    return \@feature_types;
}

# ----------------------------------------------------
#sub export_correspondences {
##
## Exports feature correspondences in CMap import format.
##
#    my $self = shift;
#    my $db   = $self->db or die $self->error;
#
#    my @evidence_type_ids = $self->show_menu(
#        title       => 'Restrict by Evidence Type (Optional)',
#        prompt      => 'Select which evidence types to restrict by',
#        display     => 'evidence_type',
#        return      => 'evidence_type_id',
#        allow_null  => 1,
#        allow_mult  => 1,
#        data        => $db->selectall_arrayref(
#            q[
#                select   et.evidence_type_id, et.evidence_type
#                from     cmap_evidence_type et
#                order by evidence_type
#            ],
#            { Columns => {} }
#        )
#    );
#
#    my @evidence_types;
#    if ( @evidence_type_ids ) {
#        @evidence_types = @{
#            $db->selectcol_arrayref(
#                q[
#                    select evidence_type
#                    from   cmap_evidence_type
#                    where  evidence_type_id in (].
#                    join(', ', @evidence_type_ids).q[)
#                ]
#            )
#        };
#    }
#
#    my @map_set_ids = $self->show_menu(
#        title       => 'Select Map Sets',
#        prompt      => 'Restrict by Map Set',
#        display     => 'common_name,short_name',
#        return      => 'map_set_id',
#        allow_null  => 1,
#        allow_mult  => 1,
#        data        => $db->selectall_arrayref(
#            q[
#                select   ms.map_set_id,
#                         ms.short_name,
#                         s.common_name
#                from     cmap_map_set ms,
#                         cmap_species s
#                where    ms.species_id=s.species_id
#                order by common_name, short_name
#            ],
#            { Columns => {} },
#        )
#    );
#
#    my @map_set_names = @map_set_ids
#        ?  map { join( '-', $_->{'species_name'}, $_->{'map_set_name'} ) } @{
#            $db->selectall_arrayref(
#                q[
#                    select   ms.map_set_id,
#                             ms.short_name as map_set_name,
#                             s.common_name as species_name
#                    from     cmap_map_set ms,
#                             cmap_species s
#                    where    ms.map_set_id in (].join(',', @map_set_ids).q[)
#                    and      ms.species_id=s.species_id
#                    order by common_name, short_name
#                ],
#                { Columns => {} }
#            )
#        }
#        : ()
#    ;
#
#    print "Include feature accession IDs? [Y/n] ";
#    chomp( my $export_corr_aid = <STDIN> );
#    $export_corr_aid = ( $export_corr_aid =~ /^[Nn]/ ) ? 0 : 1;
#
#    my $dir = _get_dir() or return;
#
#    #
#    # Confirm decisions.
#    #
#    print join("\n",
#        'OK to export feature correspondences?',
#        '  Data source          : ' . $self->data_source,
#        "  Export Accession IDs : " . ( $export_corr_aid ? "Yes" : "No" ),
#        "  Directory            : $dir",
#    );
#    if ( @evidence_types ) {
#        print "\n  Evidence Types       :\n",
#            join( "\n", map { "    $_" } @evidence_types );
#    }
#    if ( @map_set_ids ) {
#        print "\n  Map Set(s)           :\n",
#            join( "\n", map { "    $_" } @map_set_names );
#    }
#    print "\n[Y/n] ";
#    chomp( my $answer = <STDIN> );
#    return if $answer =~ /^[Nn]/;
#
#    my $corr_file = "$dir/feature_correspondences.dat";
#    open my $fh, ">$corr_file" or die "Can't write to $corr_file: $!\n";
#    my $log_fh = $self->log_fh;
#    print $log_fh "Dumping feature correspondences to '$corr_file'\n";
#
#    my $sql = q[
#        select fc.feature_correspondence_id,
#               fc.is_enabled,
#               f1.accession_id as feature_accession_id1,
#               f1.feature_name as feature_name1,
#               f2.accession_id as feature_accession_id2,
#               f2.feature_name as feature_name2
#        from   cmap_feature_correspondence fc,
#               cmap_feature f1,
#               cmap_feature f2,
#               cmap_map map1,
#               cmap_map map2
#        where  fc.feature_id1=f1.feature_id
#        and    f1.map_id=map1.map_id
#        and    fc.feature_id2=f2.feature_id
#        and    f2.map_id=map2.map_id
#    ];
#
#    if ( my $map_set_ids = join( ',', @map_set_ids ) ) {
#        $sql .= qq[
#            and (
#                map1.map_set_id in ($map_set_ids) or
#                map2.map_set_id in ($map_set_ids)
#            )
#        ];
#    }
#
#    my $sth = $db->prepare( $sql );
#    $sth->execute;
#
#    my @col_names = (
#        map { !$export_corr_aid && $_ =~ /accession/ ? () : $_ }
#        qw[
#            feature_name1
#            feature_accession_id1
#            feature_name2
#            feature_accession_id2
#            evidence
#            is_enabled
#        ]
#    );
#
#    my $evidence_sql = q[
#        select et.evidence_type
#        from   cmap_correspondence_evidence ce,
#               cmap_evidence_type et
#        where  ce.feature_correspondence_id=?
#        and    ce.evidence_type_id=et.evidence_type_id
#    ];
#    if ( @evidence_type_ids ) {
#        $evidence_sql .= 'and ce.evidence_type_id in ('.
#            join( ', ', @evidence_type_ids ).
#        ')';
#    }
#
#    print $fh join( OFS, @col_names ), ORS;
#    my $no_exported = 0;
#    while ( my $fc = $sth->fetchrow_hashref ) {
#        $fc->{'evidence'} = join(',', @{
#            $db->selectcol_arrayref(
#                $evidence_sql,
#                {},
#                ( $fc->{'feature_correspondence_id'} )
#            )
#        }) or next;
#
#        print $fh join( OFS, map { $fc->{ $_ } } @col_names ), ORS;
#        $no_exported++;
#    }
#    print "\nExported $no_exported records.\n";
#}

# ----------------------------------------------------
sub import_data {

    #
    # Determine what kind of data to import (new or old)
    #
    my $self = shift;

    my $action = $self->show_menu(
        title   => 'Import Options',
        prompt  => 'What would you like to import?',
        display => 'display',
        return  => 'action',
        data    => [
            {
                action  => 'import_tab_data',
                display => 'Import tab-delimited data for existing map set'
            },
            {
                action  => 'import_correspondences',
                display => 'Import feature correspondences'
            },
            {
                action  => 'import_object_data',
                display => 'Import CMap objects [experimental]'
            },
        ],
    );

    $self->$action();
    $self->purge_query_cache(1);
}

# ----------------------------------------------------
sub manage_links {

    #
    # Determine what kind of data to import (new or old)
    #
    my $self = shift;
    my $db   = $self->db or die $self->error;
    my $term = $self->term;

    my $action = $self->show_menu(
        title   => 'Import Options',
        prompt  => 'What would you like to import?',
        display => 'display',
        return  => 'action',
        data    => [
            {
                action  => 'import_links',
                display => 'Import Links'
            },
            {
                action  => 'delete_links',
                display => 'Remove Link Set'
            },
        ],
    );

    $self->$action();
}

# ----------------------------------------------------
sub import_links {

    #
    # Imports links in simple tab-delimited format
    #
    my ( $self, %args ) = @_;
    my $db   = $self->db or die $self->error;
    my $term = $self->term;

    #
    # Get the species.
    #
    my ( $species_id, $species_name ) = $self->show_menu(
        title   => "Available Species",
        prompt  => 'Please select a species',
        display => 'common_name',
        return  => 'species_id,common_name',
        data    => $db->selectall_arrayref(
            q[
                select   distinct s.species_id, s.common_name
                from     cmap_species s,
                         cmap_map_set ms
                where    ms.species_id=s.species_id
                order by common_name
            ],
            { Columns => {} },
            ()
        ),
    );
    do { print "No species to select from.\n"; return } unless $species_id;

    #
    # Get the map set.
    #
    my ( $map_set_id, $map_set_name ) = $self->show_menu(
        title   => "Available Map Sets (for $species_name)",
        prompt  => 'Please select a map set',
        display => 'map_set_name',
        return  => 'map_set_id,map_set_name',
        data    => $db->selectall_arrayref(
            q[
                select   ms.map_set_id, ms.map_set_name
                from     cmap_map_set ms
                where    ms.species_id=?
                order by map_set_name
            ],
            { Columns => {} },
            ($species_id)
        ),
    );
    do { print "There are no map sets!\n"; return }
      unless $map_set_id;

    ###New File Handling
    my $file_str = $term->readline('Where is the file?[q to quit] ');
    return if $file_str =~ m/^[Qq]$/;
    my @file_strs = split( /\s+/, $file_str );
    my @files = ();
    foreach my $str (@file_strs) {
        push @files, glob($str);
    }
    foreach ( my $i = 0 ; $i <= $#files ; $i++ ) {
        unless ( -r $files[$i] and -f $files[$i] ) {
            print "Unable to read $files[$i]\n";
            splice( @files, $i, 1 );
            $i--;
        }
    }
    return unless ( scalar(@files) );

    my $link_set_name = $self->show_question(
        question => 'What should this link set be named (default='
          . $files[0] . ')?',
        default => $files[0],
    );
    $link_set_name = "map set $map_set_id:" . $link_set_name;

    #
    # Confirm decisions.
    #
    print join( "\n",
        'OK to import?',
        '  Data source     : ' . $self->data_source,
        "  File            : " . join( ", ", @files ),
        "  Species         : $species_name",
        "  Map Study       : $map_set_name",
        "  Link Set        : $link_set_name",
        "[Y/n] " );
    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my $link_manager =
      Bio::GMOD::CMap::Admin::ManageLinks->new(
        data_source => $self->data_source, );

    foreach my $file (@files) {
        my $fh = IO::File->new($file) or die "Can't read $file: $!";
        $link_manager->import_links(
            map_set_id    => $map_set_id,
            fh            => $fh,
            link_set_name => $link_set_name,
            log_fh        => $self->log_fh,
            name_space    => $self->get_link_name_space,
          )
          or do {
            print "Error: ", $link_manager->error, "\n";
            return;
          };
    }
}

# ----------------------------------------------------
sub delete_links {

    #
    # Removes links
    #
    my ( $self, %args ) = @_;
    my $name_space = $self->get_link_name_space;
    my $db         = $self->db or die $self->error;
    my $term       = $self->term;

    my $link_manager =
      Bio::GMOD::CMap::Admin::ManageLinks->new(
        data_source => $self->data_source, );
    my @link_set_names =
      $link_manager->list_set_names( name_space => $self->get_link_name_space,
      );
    my @link_set_name_display;
    foreach my $name (@link_set_names) {
        $link_set_name_display[ ++$#link_set_name_display ]->{'link_set_name'} =
          $name;
    }
    my $link_set_name = $self->show_menu(
        title   => join("\n"),
        prompt  => 'Which would you like to remove?',
        display => 'link_set_name',
        return  => 'link_set_name',
        data    => \@link_set_name_display,
    );
    unless ($link_set_name) {
        print "No Link Sets\n";
        return;
    }

    #
    # Confirm decisions.
    #
    print join( "\n",
        'OK to remove?',
        '  Data source     : ' . $self->data_source,
        "  Link Set        : $link_set_name",
        "[Y/n] " );
    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    $link_manager->delete_links(
        link_set_name => $link_set_name,
        log_fh        => $self->log_fh,
        name_space    => $self->get_link_name_space,
      )
      or do {
        print "Error: ", $link_manager->error, "\n";
        return;
      };
}

# ----------------------------------------------------
sub import_correspondences {

    #
    # Gathers the info to import feature correspondences.
    #
    my $self = shift;
    my $db   = $self->db or die $self->error;
    my $file = $self->file;
    my $term = $self->term;

    #
    # Make sure we have a file to parse.
    #
    if ($file) {
        print "OK to use '$file'? [Y/n] ";
        chomp( my $answer = <STDIN> );
        $file = '' if $answer =~ m/^[Nn]/;
    }

    while ( !-r $file || !-f _ ) {
        print "Unable to read '$file' or not a regular file.\n" if $file;
        $file = $term->readline('Where is the file? [q to quit] ');
        $file =~ s/^\s*|\s*$//g;
        return if $file =~ m/^[Qq]/;
    }

    #
    # Open the file.  If it's good, remember it.
    #
    my $fh = IO::File->new($file) or die "Can't read $file: $!";
    $term->addhistory($file);
    $self->file($file);

    #
    # Get the map set.
    #
    my @map_sets = $self->show_menu(
        title      => 'Restrict by Map Set (optional)',
        prompt     => 'Please select a map set to restrict the search',
        display    => 'species_name,map_set_name',
        return     => 'map_set_id,species_name,map_set_name',
        allow_null => 1,
        allow_mult => 1,
        data       => $db->selectall_arrayref(
            q[
                select   ms.map_set_id, 
                         ms.short_name as map_set_name,
                         s.common_name as species_name
                from     cmap_map_set ms,
                         cmap_species s
                where    ms.species_id=s.species_id
                order by common_name, map_set_name
            ],
            { Columns => {} },
        ),
    );

    my @map_set_ids = map { $_->[0] } @map_sets;

    print join( "\n",
        'OK to import?',
        '  Data source   : ' . $self->data_source,
        "  File          : $file",
    );

    if (@map_sets) {
        print join( "\n",
            '',
            '  From map sets :',
            map { "    $_" } map { join( '-', $_->[1], $_->[2] ) } @map_sets );
    }
    print "\n[Y/n] ";

    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my $importer =
      Bio::GMOD::CMap::Admin::ImportCorrespondences->new(
        data_source => $self->data_source, );

    $importer->import(
        fh          => $fh,
        map_set_ids => \@map_set_ids,
        log_fh      => $self->log_fh,
      )
      or do {
        print "Error: ", $importer->error, "\n";
        return;
      };
    $self->purge_query_cache(4);
}

# ----------------------------------------------------
sub delete_duplicate_correspondences {

    #
    # deletes all duplicate correspondences.
    #
    my $self = shift;
    my $db   = $self->db or die $self->error;

    my $admin = Bio::GMOD::CMap::Admin->new(
        config      => $self->config,
        data_source => $self->data_source,
    );

    $admin->delete_duplicate_correspondences();

    $self->purge_query_cache(4);
}

# ----------------------------------------------------

sub purge_query_cache_menu {

    my $self = shift;

    my $cache_level = $self->show_menu(
        title  => '  --= Cache Level =--  ',
        prompt =>
'At which cache level would you like to start the purging?\n(The purges cascade down. ie selecting level 3 removes 3 and 4):',
        display => 'display',
        return  => 'level',
        data    => [
            {
                level   => 1,
                display => 'Cache Level 1 Purge All (Species/Map Sets changed)',
            },
            {
                level   => 2,
                display => 'Cache Level 2 (purge map info)',
            },
            {
                level   => 3,
                display => 'Cache Level 3 (purge feature info)',
            },
            {
                level   => 4,
                display => 'Cache Level 4 (purge correspondence info)',
            },
            {
                level   => 0,
                display => 'quit',
            },
        ],
    );
    return unless $cache_level;

    $self->purge_query_cache($cache_level);
}

# ----------------------------------------------------
sub purge_query_cache {

    my $self        = shift;
    my $cache_level = shift || 1;

    my $admin = Bio::GMOD::CMap::Admin->new(
        config      => $self->config,
        data_source => $self->data_source,
    );
    print "Purging cache\n";
    $admin->purge_cache($cache_level);
    print "Cache Purged\n";
}

# ----------------------------------------------------
sub import_tab_data {

    #
    # Imports simple (old) tab-delimited format
    #
    my $self = shift;
    my $db   = $self->db or die $self->error;
    my $term = $self->term;

    ###New File Handling
    my $file_str =
      $term->readline(
'Where is the file(s)? \nSeparate Multiple files with a space. [q to quit] '
      );
    return if $file_str =~ m/^[Qq]$/;
    my @file_strs = split( /\s+/, $file_str );
    my @files = ();
    foreach my $str (@file_strs) {
        push @files, glob($str);
    }
    foreach ( my $i = 0 ; $i <= $#files ; $i++ ) {
        unless ( -r $files[$i] and -f $files[$i] ) {
            print "Unable to read $files[$i]\n";
            splice( @files, $i, 1 );
            $i--;
        }
    }

    my $map_sets = $self->get_map_sets( allow_mult => 0, allow_null => 0 );
    return unless @{ $map_sets || [] };
    my $map_set = $map_sets->[0];

    print "Remove data in map set not in import file? [y/N] ";
    chomp( my $overwrite = <STDIN> );
    $overwrite = ( $overwrite =~ /^[Yy]/ ) ? 1 : 0;

    print
"\nNOTE: If yes to the following, features on the same map with the same name \nwill be treated as duplicates.  Be sure to select the default, 'NO', if that \nwill create problems for your data.\nCheck for duplicate data (slow)? [y/N]";
    chomp( my $allow_update = <STDIN> );
    $allow_update = ( $allow_update =~ /^[Yy]/ ) ? 1 : 0;

    #
    # Confirm decisions.
    #
    print join( "\n",
        'OK to import?',
        '  Data source : ' . $self->data_source,
        "  File        : " . join( ", ", @files ),
        "  Species     : " . $map_set->{species_name},
        "  Map Type    : " . $map_set->{map_type},
        "  Map Set     : " . $map_set->{map_set_name},
        "  Map Set Acc : " . $map_set->{map_set_aid},
        "  Overwrite   : " .     ( $overwrite    ? "Yes" : "No" ),
        "  Update Features : " . ( $allow_update ? "Yes" : "No" ),
        "[Y/n] " );
    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my $importer =
      Bio::GMOD::CMap::Admin::Import->new( data_source => $self->data_source, );

    my $time_start = new Benchmark;
    foreach my $file (@files) {
        my $fh = IO::File->new($file) or die "Can't read $file: $!";
        $importer->import_tab(
            map_set_id   => $map_set->{'map_set_id'},
            fh           => $fh,
            map_type_aid => $map_set->{'map_type_aid'},
            log_fh       => $self->log_fh,
            overwrite    => $overwrite,
            allow_update => $allow_update,
          )
          or do {
            print "Error: ", $importer->error, "\n";
            return;
          };
    }

    my $time_end = new Benchmark;
    print STDERR "import time: "
      . timestr( timediff( $time_end, $time_start ) ) . "\n";

    $self->purge_query_cache(1);
}

# ----------------------------------------------------
sub import_object_data {

    #
    # Gathers the info to import physical or genetic maps.
    #
    my $self = shift;
    my $db   = $self->db or die $self->error;
    my $term = $self->term;
    my $file = $self->file;

    #
    # Make sure we have a file to parse.
    #
    if ($file) {
        print "OK to use '$file'? [Y/n] ";
        chomp( my $answer = <STDIN> );
        $file = '' if $answer =~ m/^[Nn]/;
    }

    while ( !-r $file || !-f _ ) {
        print "Unable to read '$file' or not a regular file.\n" if $file;
        $file = $term->readline('Where is the file? [q to quit] ');
        $file =~ s/^\s*|\s*$//g;
        return if $file =~ m/^[Qq]/;
    }

    #
    # Open the file.  If it's good, remember it.
    #
    my $fh = IO::File->new($file) or die "Can't read $file: $!";
    $term->addhistory($file);
    $self->file($file);

    print "Overwrite any existing data? [y/N] ";
    chomp( my $overwrite = <STDIN> );
    $overwrite = ( $overwrite =~ /^[Yy]/ ) ? 1 : 0;

    #
    # Confirm decisions.
    #
    print join( "\n",
        'OK to import?',
        '  Data source : ' . $self->data_source,
        "  File        : $file",
        "  Overwrite   : " . ( $overwrite ? "Yes" : "No" ),
        "[Y/n] " );
    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my $importer =
      Bio::GMOD::CMap::Admin::Import->new( data_source => $self->data_source, );
    $importer->import_objects(
        fh        => $fh,
        log_fh    => $self->log_fh,
        overwrite => $overwrite,
      )
      or do {
        print "Error: ", $importer->error, "\n";
        return;
      };
    $self->purge_query_cache(1);
}

# ----------------------------------------------------
sub make_name_correspondences {
    my $self = shift;
    my $db   = $self->db or die $self->error;

    #
    # Get the evidence type id.
    #
    my ( $evidence_type_aid, $evidence_type ) = $self->show_menu(
        title   => 'Available evidence types',
        prompt  => 'Please select an evidence type',
        display => 'evidence_type',
        return  => 'evidence_type_aid,evidence_type',
        data    => $self->fake_selectall_arrayref(
            $self->evidence_type_data(),
            'evidence_type_accession as evidence_type_aid',
            'evidence_type'
        ),
    );
    die "No evidence types!  Please use the config file to create.\n"
      unless $evidence_type;

    my $from_map_sets =
      $self->get_map_sets(
        explanation => 'First you will select the starting map sets' );

    my $use_from_as_target_answer =
      $self->show_question( question =>
          'Do you want to use the starting map sets as the target sets? [y|N]',
      );
    my $to_map_sets;
    if ( $use_from_as_target_answer =~ /^y/ ) {
        $to_map_sets = $from_map_sets;
    }
    else {
        $to_map_sets =
          $self->get_map_sets(
            explanation => 'Now you will select the target map sets' );
    }

    my @skip_features = $self->show_menu(
        title      => 'Skip Feature Types (optional)',
        prompt     => 'Select any feature types to skip in check',
        display    => 'feature_type',
        return     => 'feature_type_aid,feature_type',
        allow_null => 1,
        allow_mult => 1,
        data       => $self->fake_selectall_arrayref(
            $self->feature_type_data(),
            'feature_type_accession as feature_type_aid',
            'feature_type'
        ),
    );
    my @skip_feature_type_aids = map { $_->[0] } @skip_features;
    my $skip =
      @skip_features
      ? join( "\n     ", map { $_->[1] } @skip_features ) . "\n"
      : '    None';

    print "Check for duplicate data (slow)? [y/N] ";
    chomp( my $allow_update = <STDIN> );
    $allow_update = ( $allow_update =~ /^[Yy]/ ) ? 1 : 0;

    my $name_regex = $self->show_menu(
        title =>
"Match Type\n(You can add your own match types by editing cmap_admin.pl)",
        prompt     => "Select the match type that you desire",
        display    => 'regex_title',
        return     => 'regex',
        allow_null => 0,
        allow_mult => 0,
        data       => [
            {
                regex_title => 'exact match only',
                regex       => '',
            },
            {
                regex_title => q[read pairs '(\S+)\.\w\d$'],
                regex       => '(\S+)\.\w\d$',
            },
        ],
    );

    my $from = join( "\n",
        map { "    $_->{species_name}-$_->{map_set_name} ($_->{map_set_aid})" }
          @{$from_map_sets} );

    my $to = join( "\n",
        map { "    $_->{species_name}-$_->{map_set_name} ($_->{map_set_aid})" }
          @{$to_map_sets} );
    print "Make name-based correspondences\n",
      '  Data source   : ' . $self->data_source, "\n",
      "  Evidence type : $evidence_type\n", "  From map sets :\n$from\n",
      "  To map sets   :\n$to\n",           "  Skip features :\n$skip\n",
      "  Check for dups  : " . ( $allow_update ? "yes" : "no" );
    print "\nOK to make correspondences? [Y/n] ";
    chomp( my $answer = <STDIN> );
    return if $answer =~ m/^[Nn]/;

    my $corr_maker = Bio::GMOD::CMap::Admin::MakeCorrespondences->new(
        db          => $db,
        data_source => $self->data_source,
    );

    my @from_map_set_ids = map { $_->{map_set_id} } @$from_map_sets;
    my @to_map_set_ids   = map { $_->{map_set_id} } @$to_map_sets;
    my $time_start = new Benchmark;
    $corr_maker->make_name_correspondences(
        evidence_type_aid      => $evidence_type_aid,
        from_map_set_ids       => \@from_map_set_ids,
        to_map_set_ids         => \@to_map_set_ids,
        skip_feature_type_aids => \@skip_feature_type_aids,
        log_fh                 => $self->log_fh,
        quiet                  => $Quiet,
        name_regex             => $name_regex,
        allow_update           => $allow_update,
      )
      or do { print "Error: ", $corr_maker->error, "\n"; return; };

    my $time_end = new Benchmark;
    print STDERR "make correspondence time: "
      . timestr( timediff( $time_end, $time_start ) ) . "\n";

    $self->purge_query_cache(4);
    return 1;
}

# ----------------------------------------------------
sub reload_correspondence_matrix {
    my $self = shift;

    print "OK to truncate table in data source '", $self->data_source,
      "' and reload? [Y/n] ";
    chomp( my $answer = <STDIN> );
    return if $answer =~ m/^[Nn]/;

    my $admin = $self->admin;
    $admin->reload_correspondence_matrix or do {
        print "Error: ", $admin->error, "\n";
        return;
    };

    return 1;
}

# ----------------------------------------------------
sub show_question {
    my $self         = shift;
    my %args         = @_;
    my $question     = $args{'question'} or return;
    my $default      = $args{'default'};
    my $validHashRef = $args{'valid_hash'} || ();

    $question .= "<Default: $default>:" if ( defined $default );
    my $answer;
    while (1) {
        print $question;
        chomp( $answer = <STDIN> );
        if ( $validHashRef and $answer and not $validHashRef->{$answer} ) {
            print "Options:\n" . join( "\n", keys %{$validHashRef} ) . "\n";
            print
              "Your input was not valid, please choose from the above list\n";
            print $question;
            next;
        }
        elsif ( $answer and $answer !~ /^\S+$/ ) {
            print "Your input was not valid.\n";
            print $question;
            next;
        }
        $answer = $answer || $default;
        return $answer;
    }
}

# ----------------------------------------------------
sub show_menu {
    my $self   = shift;
    my %args   = @_;
    my $data   = $args{'data'} or return;
    my @return = split( /,/, $args{'return'} )
      or die "No return field(s) defined\n";
    my @display = split( /,/, $args{'display'} );
    my $result;

    if ( scalar @$data > 1 || $args{'allow_null'} ) {
        my $i      = 1;
        my %lookup = ();

        my $title = $args{'title'} || '';
        print $title ? "\n$title\n" : "\n";
        for my $row (@$data) {
            print "[$i] ", join( ' : ', map { $row->{$_} } @display ), "\n";
            $lookup{$i} =
              scalar @return > 1
              ? [ map { $row->{$_} } @return ]
              : $row->{ $return[0] };
            $i++;
        }

        if ( $args{'allow_all'} ) {
            print "[$i] All of the above\n";
        }

        my $prompt = $args{'prompt'} || 'Please select';
        $prompt .=
             $args{'allow_null'}
          && $args{'allow_mult'} ? "\n(<Enter> for nothing, multiple allowed): "
          : $args{'allow_null'}  ? ' (0 or <Enter> for nothing): '
          : $args{'allow_mult'}  ? ' (multiple allowed): '
          : $args{'allow_mult'}  ? ' (multiple allowed):'
          : ' (one choice only): ';

        for ( ; ; ) {
            print "\n$prompt";
            chomp( my $answer = <STDIN> );

            if ( $args{'allow_null'} && $answer == 0 ) {
                $result = undef;
                last;
            }
            elsif ( $args{'allow_all'} && $answer == $i ) {
                $result = [ map { $lookup{$_} } 1 .. $i - 1 ];
                last;
            }
            elsif ( $args{'allow_all'} || $args{'allow_mult'} ) {
                my %numbers =

                  # make a lookup
                  map { $_, 1 }

                  # take only numbers
                  grep { /\d+/ }

                  # look for ranges
                  map { $_ =~ m/(\d+)-(\d+)/ ? ( $1 .. $2 ) : $_ }

                  # split on space or comma
                  split /[,\s]+/, $answer;

                $result = [
                    map { $_ || () }    # parse out nulls
                      map  { $lookup{$_} }    # look it up
                      sort { $a <=> $b }      # keep order
                      keys %numbers           # make unique
                ];

                next unless @$result;
                last;
            }
            elsif ( defined $lookup{$answer} ) {
                $result = $lookup{$answer};
                last;
            }
        }
    }
    elsif ( scalar @$data == 0 ) {
        $result = undef;
    }
    else {
        $result = [ map { $data->[0]->{$_} } @return ];
        unless ( wantarray or scalar(@$result) != 1 ) {
            $result = $result->[0];
        }
        my $value = join( ' : ', map { $data->[0]->{$_} } @display );
        my $title = $args{'title'} || '';
        print $title ? "\n$title\n" : "\n";
        print "Using '$value'\n";
    }

    return wantarray
      ? defined $result ? @$result : ()
      : $result;
}

# ----------------------------------------------------
sub _get_dir {

    #
    # Get a directory for writing files to.
    #
    my $dir;
    for ( ; ; ) {
        print "\nTo which directory should I write the output files?\n",
          "['q' to quit, current dir (.) is default] ";
        chomp( my $answer = <STDIN> );
        $answer ||= '.';
        return if $answer =~ m/^[qQ]/;

        if ( -d $answer ) {
            if ( -w _ ) {
                $dir = $answer;
                last;
            }
            else {
                print "\n'$answer' is not writable by you.\n\n";
                next;
            }
        }
        elsif ( -f $answer ) {
            print "\n'$answer' is not a directory.  Please try again.\n\n";
            next;
        }
        else {
            print "\n'$answer' does not exist.  Create? [Y/n] ";
            chomp( my $response = <STDIN> );
            $response ||= 'y';
            if ( $response =~ m/^[Yy]/ ) {
                eval { mkpath( $answer, 0, 0711 ) };
                if ( my $err = $@ ) {
                    print "I couldn't make that directory: $err\n\n";
                    next;
                }
                else {
                    $dir = $answer;
                    last;
                }
            }
        }
    }
    return $dir;
}

# ----------------------------------------------------
# Life is full of misery, loneliness, and suffering --
# and it's all over much too soon.
# Woody Allen
# ----------------------------------------------------

=pod

=head1 NAME

cmap_admin.pl - command-line CMap administrative tool

=head1 SYNOPSIS

  ./cmap_admin.pl [options] [data_file]

  Options:

    -h|help          Display help message
    -v|version       Display version
    -d|--datasource  The default data source to use
    --no-log         Don't keep a log of actions

=head1 DESCRIPTION

This script is a complement to the web-based administration tool for
the GMOD-CMap application.  This tool handles all of the long-running
processes (e.g., importing/exporting data and correspondences,
reloading cache tables) and tasks which require interaction with
file-based data (i.e., map coordinates, feature correspondences,
etc.).

The output of the actions taken by the program (i.e., statements of
what happens, not the menu items, etc.) will be tee'd between your
terminal and a log file unless you pass the "--no-log" argument on the
command line.  The log will be placed into your home directory and
will be called "cmap_admin_log.x" where "x" is a number starting at
zero and ascending by one for each time you run the program (until you
delete existing logs, of course).  The name of the log file will be
echoed to you when you exit the program.

All the questions asked in cmap_admin.pl can be answered either by
choosing the number of the answer from a pre-defined list or by typing
something (usually a file path, notice that you can use tab-completion
if your system supports it).  When the answer must be selected from a
list and the answer is required, you will not be allowed to leave the
question until you have selected an answer from the list.
Occassionally the answer is not required, so you can just hit
"<Return>."  Sometimes more than one answer is acceptable, so you
should specify all your choices on one line, separating the numbers
with spaces or commas and alternately specifying ranges with a dash
(and no spaces around the dash).  For instance, the following are
eqivalent:

  This:               Equates to:
  1                   1
  1-3                 1,2,3
  1,3-5               1,3,4,5
  1 3 3-5             1,3,4,5
  1, 3  5-8 , 10      1,3,5,6,7,8,10

Finally, sometimes a question is never asked if there is only one
possible answer; the one answer is automatically taken and processing
moves on to the next question.

=head1 ACTIONS

=head2 Change data source

Whenever the "Main Menu" is displayed, the current data source is
displayed.  If you have configured CMap to work with multiple data
sources, you can use this option to change which one you are currently
using.  The one defined as the "default" will always be chosen when
you first begin. See the ADMINISTRATION document for more information
on creating multiple data sources.

=head2 Create new map set

This is the one feature duplicated with the web admin tool.  This is
a very simple implementation, however, meant strictly as a convenience
when loading new data sets.  You can only specify the species, map
type, long and short names.  Everything else about the map set must be
edited with the web admin tool.

=head2 Import data for existing map set

This allows you to import the feature data for a map set. The map set
may be one you just created and is empty or one that already has data
associated with it.  If the latter, you may choose to remove all the
data currently in the map set when isn't updated with the new data you
are importing.  For specifics on how the data should be formatted, see
the documentation ("perldoc") for Bio::GMOD::CMap::Admin::Import.  The
file containing the feature data can either be given as an argument to
this script or you can specify the file's location when asked.  

=head2 Make name-based correspondences

This option will create correspondences between any two features with
the same "feature_name" or "aliases," irrespective of case.  It
is possible to choose to make the correspondences from only one map
set (for the occasions when you bring in just one new map set, you
don't want to rerun this for the whole database -- it can take a long
time).

=head2 Import feature correspondences

Choose this option to import a file containing correspondences between
your features.  For more information on the format of this file, see
the documentation for Bio::GMOD::CMap::Admin::ImportCorrespondences.
Like the name-based correspondences, you can restrict the maps which
are involved in the search.  The lookups for the features will be done
as normal, but only if one of the two features falls on one of the
maps specified will a correspondence be created.  Again, the idea is
that this should take less time than reloading correspondences when
searching the entire database.

=head2 Reload correspondence matrix

You should choose this option whenever you've altered the number of
correspondences in the database.  This will truncate the
"cmap_correspondence_matrix" table and reload it with the pair-wise
comparison of every map set in the database.

=head2 Export data

There are three ways to dump the data in CMap:

=over 4 

=item 1 

All Data as SQL INSERT statements

This method creates an INSERT statement for every record in every
table (or just those selected) a la "mysqldump."  This is meant to be
an easy way to backup or migrate an entire CMap database, esp. when
moving between database platforms (e.g. Oracle to MySQL).  The output
will be put into a file of your choosing and can be fed directly into
another database to mirror your current one.  You can also choose to
add "TRUNCATE TABLE" statements just before the INSERT statements so
as to erase any existing data.

B<Note to Oracle users>: If you have ampersands in strings, Oracle
will think that they are variables and will prompt you for values when
you run the file.  Either "SET SCAN OFF" or "SET DEFINE OFF" to have
Oracle accept the string as is.

=item 2 

Map data in CMap import format

This method creates a separate file for each map set in the database.
The data is dumped to the same tab-delimited format used when
importing.  You can choose to dump every map set or just particular
ones, and you can choose to I<leave out> certain fields (e.g., maybe
you don't care to export your accession IDs).

=item 3 

Feature correspondence data in CMap import format

This method dumps the feature correspondence data in the same
tab-delimited format that is accepted for importing.  You can choose
to export with or without the feature accession IDs.  If you choose to
export feature accession IDs, it will affect how the importing of the
data will work.  When accession IDs are present in the feature
correspondence import file, only features with the specified accession
IDs are used to create the correspondences, which is what you'll want
if you're exporting your correspondences to another database which
uses the same accession IDs for the same features as the source.  If,
however, the accession ID can't be found while importing, a name
lookup is used to find all the features with that name
(case-insensitively), which is what would happen if the accession IDs
weren't present at all.  In short, exporting with accession IDs is a
Good Thing if the importing database has the same accession IDs
(this was is much faster and more exact), but a very, very Bad Thing
if the importing database has different accession IDs.

=back

=head2 Delete a map or map set

Along with creating a map set, this is the an task duplicated with the
web admin tool.  The reason is because very large maps or map sets can
take a very long time to delete.  As all of the referential integrity
(e.g., deleting from one table causes deletes in others so as to not
create orphan records) is handled in Perl, then can take a while to
completely remove a map or map set.  Such a long-running process can
time out in web browsers, so it can be more convenient to remove data
using cmap_admin.pl.

To remove just one (or more) map of a map set, first choose the map
set and then the map (or maps) within it.  If you wish to remove an
entire map set, then answer "0" (or just hit "Return") when given a
list of maps.
 
=head2 Purge the cache to view new data
                                                                                                                             
Purge the query cache.  The results of many queries are cached in an
effort to reduce time querying the database for common queries.
Purging the cache is important after the data has changed or after
the configuration file has change.  Otherwise the changes will not
be consistantly displayed.
                                                                                                                             
There are four layers of the cache.  When one layer is purged all of
the layers after it are purged.
                                                                                                                             
=over 4
                                                                                                                             
=item * Cache Level 1 Purge All
                                                                                                                             
Purge all when a map set or species has been added or modified.  A
change to map sets or species has potential to impact all of the data.
                                                                                                                             
=item * Cache Level 2 (purge map info on down)
                                                                                                                             
Level 2 is purged when map information is changed.
                                                                                                                             
=item * Cache Level 3 (purge feature info on down)
                                                                                                                             
Level 3 is purged when feature information is changed.
                                                                                                                             
=item * Cache Level 4 (purge correspondence info on down)
                                                                                                                             
Level 3 is purged when correspondence information is changed.
                                                                                                                             
=back
                                                                                                                             
=head2 Delete duplicate correspondences
                                                                                                                             
If duplicate correspondences may have been added, this will remove them.
                                                                                                                             
=head2 Manage links
                                                                                                                             
This option is where to import and delete links that will show up in
the "Imported Links" section of CMap.  The import takes a tab delimited
file, see "perldoc /path/to/Bio/GMOD/CMap/Admin/ManageLinks.pm" for
more info on the format.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This program is free software;  you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

Bio::GMOD::CMap::Admin::Import, Bio::GMOD::CMap::Admin::ImportCorrespondences.

=cut

