#!/usr/bin/perl
# vim: set ft=perl:

# $Id: cmap_admin.pl,v 1.114 2005-08-30 16:49:49 mwz444 Exp $

use strict;
use Pod::Usage;
use Getopt::Long;
use Data::Dumper;

use vars qw[ $VERSION ];
$VERSION = (qw$Revision: 1.114 $)[-1];

#
# Get command-line options
#
my ( $show_help, $show_info, $show_version, $no_log, $datasource, $Quiet );
my ($ACTION);

#create species values
my ( $species_full_name, $species_common_name, $species_acc );

#create map set values
my ( $map_set_name, $map_set_short_name, $species_id, $map_type_acc, );
my ( $map_set_acc,  $map_shape,          $map_color,  $map_width );

#import file
my ( $overwrite, $allow_update );

#cache purging
my ($cache_level);

#import corrs
my ($map_set_accs);

#import alignment
my ( $feature_type_acc, $evidence_type_acc, $from_map_set_acc, );
my ( $to_map_set_acc,   $format, );

#export sql
my ( $add_truncate, $export_file, $quote_escape, $tables, );

#export text
my ( $feature_type_accs, $exclude_fields, $directory, );

#export text
my ($export_objects);

#delete map_set
my ($map_accs);

#delete corr
my ( $evidence_type_accs, );

#make name corr
my ($from_map_set_accs, $to_map_set_accs, $skip_feature_type_accs,$name_regex);

GetOptions(
    'h|help'                => \$show_help,             # Show help and exit
    'i|info'                => \$show_info,             # Show help and exit
    'v|version'             => \$show_version,          # Show version and exit
    'no-log'                => \$no_log,                # Don't keep a log
    'd|datasource=s'        => \$datasource,            # Default data source
    'q|quiet'               => \$Quiet,                 # Only print necessities
    'a|action=s'            => \$ACTION,                # Command line action
    'species_full_name=s'   => \$species_full_name,
    'species_common_name=s' => \$species_common_name,
    'species_acc=s'         => \$species_acc,
    'species_id=s'          => \$species_id,
    'map_set_name=s'        => \$map_set_name,
    'map_set_short_name=s'  => \$map_set_short_name,
    'map_accs=s'            => \$map_accs,
    'map_type_acc=s'        => \$map_type_acc,
    'feature_type_acc=s'    => \$feature_type_acc,
    'feature_type_accs=s'   => \$feature_type_accs,
    'evidence_type_acc=s'   => \$evidence_type_acc,
    'evidence_type_accs=s'  => \$evidence_type_accs,
    'skip_feature_type_accs=s'   => \$skip_feature_type_accs,
    'map_set_acc=s'         => \$map_set_acc,
    'map_set_accs=s'        => \$map_set_accs,
    'from_map_set_acc=s'    => \$from_map_set_acc,
    'from_map_set_accs=s'   => \$from_map_set_accs,
    'to_map_set_acc=s'      => \$to_map_set_acc,
    'to_map_set_accs=s'     => \$to_map_set_accs,
    'map_shape=s'           => \$map_shape,
    'map_color=s'           => \$map_color,
    'map_width=i'           => \$map_width,
    'overwrite'           => \$overwrite,
    'allow_update'        => \$allow_update,
    'cache_level=i'         => \$cache_level,
    'format=s'              => \$format,
    'add_truncate'        => \$add_truncate,
    'export_file=s'         => \$export_file,
    'export_objects=s'      => \$export_objects,
    'tables=s'              => \$tables,
    'quote_escape=s'        => \$quote_escape,
    'exclude_fields=s'      => \$exclude_fields,
    'directory=s'           => \$directory,
    'name_regex=s'           => \$name_regex,

  )
  or pod2usage(2);
my $file_str = join( ' ', @ARGV );
 
pod2usage(-verbose=>1) if $show_info;
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

my %command_line_actions = (
    create_species                   => 1,
    create_map_set                   => 1,
    import_tab_data                  => 1,
    import_correspondences           => 1,
    import_alignments                => 1,
    import_object_data               => 1,
    purge_query_cache                => 1,
    reload_correspondence_matrix     => 1,
    delete_duplicate_correspondences => 1,
    export_as_sql                    => 1,
    export_as_text                   => 1,
    export_objects                   => 1,
    delete_maps                   => 1,
    delete_correspondences           => 1,
    make_name_correspondences        => 1,
);

my $continue     = 1;
my $command_line = 0;
while ($continue) {
    my $action;

    # if action is defined in the command line, only do that then exit
    if ($ACTION) {
        $action       = $ACTION;
        $continue     = 0;
        $command_line = 1;
        unless ( $command_line_actions{$action} ) {
            print STDERR "\nERROR: '$action' is not a command line action.\n"
              . "Please choose from the following:\n"
              . join( "\n", sort keys %command_line_actions ) . "\n\n";
            exit(0);
        }
    }
    else {
        $action = $cli->show_greeting;
    }
    die "Cannot do '$action'!" unless ( $cli->can($action) );

    # Arguments are only used with command_line
    $cli->$action(
        command_line        => $command_line,
        species_full_name   => $species_full_name,
        species_common_name => $species_common_name,
        species_acc         => $species_acc,
        map_set_name        => $map_set_name,
        map_set_short_name  => $map_set_short_name,
        species_id          => $species_id,
        species_acc         => $species_acc,
        map_type_acc        => $map_type_acc,
        feature_type_acc    => $feature_type_acc,
        feature_type_accs   => $feature_type_accs,
        evidence_type_acc   => $evidence_type_acc,
        evidence_type_accs  => $evidence_type_accs,
        skip_feature_type_accs   => $skip_feature_type_accs,
        map_set_acc         => $map_set_acc,
        from_map_set_acc    => $from_map_set_acc,
        from_map_set_accs   => $from_map_set_accs,
        to_map_set_acc      => $to_map_set_acc,
        to_map_set_accs     => $to_map_set_accs,
        map_set_accs        => $map_set_accs,
        map_shape           => $map_shape,
        map_color           => $map_color,
        map_width           => $map_width,
        file_str            => $file_str,
        overwrite           => $overwrite,
        allow_update        => $allow_update,
        cache_level         => $cache_level,
        format              => $format,
        add_truncate        => $add_truncate,
        export_file         => $export_file,
        export_objects      => $export_objects,
        tables              => $tables,
        quote_escape        => $quote_escape,
        exclude_fields      => $exclude_fields,
        directory           => $directory,
        name_regex           => $name_regex,
        map_accs            => $map_accs,

    );
}

# ./bin/cmap_admin.pl -d WashU -a create_species --species_full_name "Blah Blah" --species_common_name "Blah" --species_acc Blah

# ./bin/cmap_admin.pl -d WashU -a create_map_set --species_acc Blah --map_set_name "MS20" --map_type_acc 2

# ./bin/cmap_admin.pl -d WashU -a import_tab_data --map_set_acc 13  file1 file2

# ./bin/cmap_admin.pl -d WashU -a purge_query_cache --cache_level 2;

# ./bin/cmap_admin.pl -d WashU -a reload_correspondence_matrix

# ./bin/cmap_admin.pl -d WashU -a delete_duplicate_correspondences

# ./bin/cmap_admin.pl -d WashU -a import_correspondences --map_set_accs 'Blah 13' data/tabtest.corr

# ./bin/cmap_admin.pl -d WashU -a import_object_data cmap_export.xml

# ./bin/cmap_admin.pl -d WashU -a export_as_sql --export_file cmap_export.sql --quote_escape backslash --tables all

# ./bin/cmap_admin.pl -d WashU -a export_as_text --species_acc Blah

# ./bin/cmap_admin.pl -d WashU -a export_objects --species_acc Blah --export_objects "map_set species"

# ./bin/cmap_admin.pl -d WashU -a delete_maps --map_accs "28 26"

# ./bin/cmap_admin.pl -d WashU -a delete_maps --map_set_acc 13

# ./bin/cmap_admin.pl -d WashU -a delete_correspondences --species_acc SP1 --evidence_type_accs all

# ./bin/cmap_admin.pl -d WashU -a make_name_correspondences --evidence_type_acc ANB --from_map_set_accs "10 7 MS10 MS4 MS5 MS6 MS8" --to_map_set_accs "10 7 MS10 MS4 MS5 MS6 MS8" --skip_feature_type_accs "" --name_regex exact_match


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
use Bio::GMOD::CMap::Admin::ImportAlignments();
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

    unless ( $self->{'admin'} ) {
        $self->{'admin'} = Bio::GMOD::CMap::Admin->new(
            db          => $self->db,
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

    my $menu_options = [
        {
            action  => 'change_data_source',
            display => 'Change current data source',
        },
        {
            action  => 'create_species',
            display => 'Create new species'
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
            action  => 'delete_duplicate_correspondences',
            display => 'Delete duplicate correspondences'
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
            action  => 'manage_links',
            display => 'Manage imported links'
        },
    ];

    if ( $self->config_data('gbrowse_compatible') ) {
        push @$menu_options,
          {
            action  => 'prepare_for_gbrowse',
            display => 'Prepare the Database for GBrowse data'
          };
        push @$menu_options,
          {
            action  => 'copy_cmap_into_gbrowse',
            display => 'Copy CMap into the GBrowse database'
          };
        push @$menu_options,
          {
            action  => 'copy_gbrowse_into_cmap',
            display => 'Copy GBrowse into the CMap database'
          };
    }

    push @$menu_options,
      {
        action  => 'quit',
        display => 'Quit'
      };
    print "\nCurrent data source: ", $self->data_source, "\n";

    my $action = $self->show_menu(
        title => join( "\n", $separator, '  --= Main Menu =--  ', $separator ),
        prompt  => 'What would you like to do?',
        display => 'display',
        return  => 'action',
        data    => $menu_options,
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
sub create_species {

    my ( $self, %args ) = @_;
    my $command_line        = $args{'command_line'};
    my $species_full_name   = $args{'species_full_name'};
    my $species_common_name = $args{'species_common_name'}
      || $species_full_name;
    my $species_acc = $args{'species_acc'} || '';
    print "Creating new species.\n";

    if ($command_line) {
        my @missing = ();
        unless ( defined($species_full_name) ) {
            push @missing, 'species_full_name';
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            exit(0);
        }
    }
    else {
        print "Full Species Name (long): ";
        chomp( $species_full_name = <STDIN> || 'New Species' );

        print "Common Name [$species_full_name]: ";
        chomp( $species_common_name = <STDIN> );
        $species_common_name ||= $species_full_name;

        print "Accession ID (optional): ";
        chomp( $species_acc = <STDIN> );

        print "OK to create species '$species_full_name' in data source '",
          $self->data_source, "'?\n[Y/n] ";
        chomp( my $answer = <STDIN> );
        return if $answer =~ m/^[Nn]/;
    }

    my $admin = $self->admin;
    $admin->species_create(
        species_acc         => $species_acc         || '',
        species_common_name => $species_common_name || '',
        species_full_name   => $species_full_name   || '',
      )
      or do {
        print "Error: ", $admin->error, "\n";
        return;
      };

    my $log_fh = $self->log_fh;
    print $log_fh "Species $species_common_name created\n";

    $self->purge_query_cache( cache_level => 1 );
}

# ----------------------------------------------------
sub create_map_set {

    my ( $self, %args ) = @_;
    my $sql_object         = $self->sql or die $self->error;
    my $command_line       = $args{'command_line'};
    my $map_set_name       = $args{'map_set_name'};
    my $map_set_short_name = $args{'map_set_short_name'};
    my $species_id         = $args{'species_id'};
    my $species_acc        = $args{'species_acc'};
    my $map_type_acc       = $args{'map_type_acc'};
    my $map_set_acc        = $args{'map_set_acc'};
    my $map_shape          = $args{'map_shape'};
    my $map_color          = $args{'map_color'};
    my $map_width          = $args{'map_width'};

    print "Creating new map set.\n";

    if ($command_line) {
        my @missing = ();
        unless ( defined($map_set_name) ) {
            push @missing, 'map_set_name';
        }
        unless ( defined($map_set_short_name) ) {
            $map_set_short_name ||= $map_set_name;
        }
        if ($species_id) {
            my $return = $sql_object->get_species(
                cmap_object => $self,
                species_id  => $species_id
            );
            unless ( defined($return) and %$return ) {
                print STDERR "The species_id, '$species_id' is not valid.\n";
                push @missing, 'species_id or species_acc';
            }
        }
        elsif ($species_acc) {
            $species_id = $sql_object->acc_id_to_internal_id(
                cmap_object => $self,
                acc_id      => $species_acc,
                object_type => 'species'
            );
            unless ($species_id) {
                print STDERR "The species_acc, '$species_acc' is not valid.\n";
                push @missing, 'species_id or species_acc';
            }
        }
        else {
            push @missing, 'species_id or species_acc';
        }

        if ( defined($map_type_acc) ) {
            unless ( $self->map_type_data($map_type_acc) ) {
                print STDERR
                  "The map_type_acc, '$map_type_acc' is not valid.\n";
                push @missing, 'map_type_acc';
            }
        }
        else {
            push @missing, 'map_type_acc';
        }

        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            exit(0);
        }
    }
    else {
        my $species_info = $self->show_menu(
            title   => 'Available Species',
            prompt  => 'What species?',
            display => 'species_common_name',
            return  => 'species_id,species_common_name',
            data    => $sql_object->get_species( cmap_object => $self ),
        );
        my $species_common_name;
        ( $species_id, $species_common_name ) = @$species_info;

        unless ($species_id) {
            print "No species!  Please use cmap_admin.pl to create.\n";
            return;
        }
        my $map_type;
        ( $map_type_acc, $map_type ) = $self->show_menu(
            title   => 'Available Map Types',
            prompt  => 'What type of map?',
            display => 'map_type',
            return  => 'map_type_acc,map_type',
            data    => $self->fake_selectall_arrayref(
                $self->map_type_data(), 'map_type_acc', 'map_type'
            )
        );
        die "No map types! Please use the config file to add some.\n"
          unless $map_type_acc;

        print "Map Study Name (long): ";
        chomp( $map_set_name = <STDIN> || 'New map set' );

        print "Short Name [$map_set_name]: ";
        chomp( $map_set_short_name = <STDIN> );
        $map_set_short_name ||= $map_set_name;

        print "Accession ID (optional): ";
        chomp( $map_set_acc = <STDIN> );

        $map_color = $self->map_type_data( $map_type_acc, 'color' )
          || $self->config_data("map_color");

        $map_color = $self->show_question(
            question   => 'What color should this map set be?',
            default    => $map_color,
            valid_hash => COLORS,
        );

        $map_shape = $self->map_type_data( $map_type_acc, 'shape' )
          || 'box';

        $map_shape = $self->show_question(
            question   => 'What shape should this map set be?',
            default    => $map_shape,
            valid_hash => VALID->{'map_shapes'},
        );

        $map_width = $self->map_type_data( $map_type_acc, 'width' )
          || $self->config_data("map_width");

        $map_width = $self->show_question(
            question => 'What width should this map set be?',
            default  => $map_width,
        );

        print "OK to create set '$map_set_name' in data source '",
          $self->data_source, "'?\n[Y/n] ";
        chomp( my $answer = <STDIN> );
        return if $answer =~ m/^[Nn]/;
    }

    my $admin      = $self->admin;
    my $map_set_id = $admin->map_set_create(
        map_set_name       => $map_set_name,
        map_set_short_name => $map_set_short_name,
        species_id         => $species_id,
        map_type_acc       => $map_type_acc,
        map_set_acc        => $map_set_acc,
        shape              => $map_shape,
        color              => $map_color,
        width              => $map_width,
      )
      or do {
        print "Error: ", $admin->error, "\n";
        return;
      };

    my $log_fh = $self->log_fh;
    print $log_fh "Map set $map_set_name created\n";

    $self->purge_query_cache( cache_level => 1 );

}

# ----------------------------------------------------
sub delete_data {

    #
    # Deletes data.
    #
    my $self = shift;

    my $action = $self->show_menu(
        title   => 'Delete Options',
        prompt  => 'What do you want to delete?',
        display => 'display',
        return  => 'action',
        data    => [
            {
                action  => 'delete_maps',
                display => 'Delete a map set (or maps within it)',
            },
            {
                action  => 'delete_correspondences',
                display => 'Feature correspondences',
            },
        ]
    );

    $self->$action();
    $self->purge_query_cache( cache_level => 1 );
}

# ----------------------------------------------------
sub delete_correspondences {

    #
    # Deletes a map set.
    #
    my ( $self, %args ) = @_;
    my $command_line           = $args{'command_line'};
    my $species_acc            = $args{'species_acc'};
    my $map_set_accs           = $args{'map_set_accs'};
    my $map_type_acc           = $args{'map_type_acc'};
    my $evidence_type_accs_str = $args{'evidence_type_accs'};
    my $sql_object             = $self->sql or die $self->error;
    my $map_sets;
    my @evidence_type_accs;

    if ($command_line) {
        my @missing = ();
        if ( defined($map_set_accs) ) {

            # split on space or comma
            my @map_set_accs = split /[,\s]+/, $map_set_accs;
            if (@map_set_accs) {
                $map_sets = $sql_object->get_map_sets(
                    cmap_object  => $self,
                    map_set_accs => \@map_set_accs,
                );
            }
            unless ( @{ $map_sets || [] } ) {
                print STDERR
                  "Map set Accession(s), '$map_set_accs' is/are not valid.\n";
                push @missing, 'valid map_set_accs';
            }
        }
        elsif ( defined($species_acc) or $map_type_acc ) {
            my $species_id;
            if ( defined($species_acc) ) {
                $species_id = $sql_object->acc_id_to_internal_id(
                    cmap_object => $self,
                    acc_id      => $species_acc,
                    object_type => 'species'
                );
                unless ($species_id) {
                    print STDERR
                      "The species_acc, '$species_acc' is not valid.\n";
                    push @missing, 'valid species_acc';
                }
            }
            if ($map_type_acc) {
                unless ( $self->map_type_data($map_type_acc) ) {
                    print STDERR "The map_type_acc, '$map_type_acc' "
                      . "is not valid.\n";
                    push @missing, 'valid map_type_acc';
                }
            }
            $map_sets = $sql_object->get_map_sets(
                cmap_object  => $self,
                species_id   => $species_id,
                map_type_acc => $map_type_acc,
            );
        }
        else {
            push @missing, 'map_set_accs or species_acc or map_type_acc';
        }
        if ( defined($evidence_type_accs_str) and $evidence_type_accs_str=~/all/i){
            @evidence_type_accs = keys( %{ $self->evidence_type_data() } );
        }
        elsif ( defined($evidence_type_accs_str) ) {
            @evidence_type_accs = split /[,\s]+/, $evidence_type_accs_str;
            my $valid = 1;
            foreach my $fta (@evidence_type_accs) {
                unless ( $self->evidence_type_data($fta) ) {
                    print STDERR
                      "The evidence_type_acc, '$fta' is not valid.\n";
                    $valid = 0;
                }
            }
            unless ($valid) {
                push @missing, 'valid evidence_type_acc';
            }
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            exit(0);
        }
    }
    else {
        $map_sets = $self->get_map_sets;
        return unless @{ $map_sets || [] };
        my @map_set_names;
        if ( @{ $map_sets || [] } ) {
            @map_set_names =
              map {
                join( '-',
                    $_->{'species_common_name'},
                    $_->{'map_set_short_name'} )
              } @$map_sets;
        }
        else {
            @map_set_names = ('All');
        }

        my @evidence_types = $self->show_menu(
            title      => 'Select Evidence Type (Optional)',
            prompt     => 'Select evidence types',
            display    => 'evidence_type',
            return     => 'evidence_type_acc,evidence_type',
            allow_null => 0,
            allow_mult => 1,
            allow_all  => 1,
            data       => $self->fake_selectall_arrayref(
                $self->evidence_type_data(), 'evidence_type_acc',
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
        if (@$map_sets) {
            print "\n  Map Set(s)           :\n",
              join( "\n", map { "    $_" } @map_set_names );
        }
        if (@evidence_types) {
            print "\n  Evidence Types       :\n",
              join( "\n", map { "    $_->[1]" } @evidence_types );
        }
        @evidence_type_accs = map { $_->[0] } @evidence_types;
        print "\n[Y/n] ";
        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;

    }

    unless (@evidence_type_accs){
        print "No evidence types selected.  Doing Nothing.\n";
        return;
    }
    my %evidence_lookup = map { $_, 1 } @evidence_type_accs;
    my $admin           = $self->admin;
    my $log_fh          = $self->log_fh;
    my $disregard_evidence=@evidence_type_accs ?0 :1;

    for my $map_set (@$map_sets) {
        my $map_set_id = $map_set->{'map_set_id'};
        my $corrs      = $sql_object->get_feature_correspondence_details(
            cmap_object                 => $self,
            included_evidence_type_accs => \@evidence_type_accs,
            map_set_id2                 => $map_set_id,
            disregard_evidence_type     => $disregard_evidence,
        );

        print $log_fh "Deleting correspondences for ",
          $map_set->{'species_common_name'}, '-',
          $map_set->{'map_set_short_name'},  "\n";

        #
        # If there is more evidence supporting the correspondence,
        # then just remove the evidence, otherwise remove the
        # correspondence (which will remove all the evidence).
        #
        for my $corr (@$corrs) {
            my $all_evidence = $sql_object->get_correspondence_evidences(
                cmap_object               => $self,
                feature_correspondence_id =>
                  $corr->{'feature_correspondence_id'},
            );

            my $no_evidence_deleted = 0;
            for my $evidence (@$all_evidence) {
                next
                  unless $evidence_lookup{ $evidence->{'evidence_type_acc'} };
                $admin->correspondence_evidence_delete(
                    correspondence_evidence_id =>
                      $evidence->{'correspondence_evidence_id'} );
                $no_evidence_deleted++;
            }

            if ( $no_evidence_deleted == scalar @$all_evidence ) {
                $admin->feature_correspondence_delete(
                    feature_correspondence_id =>
                      $corr->{'feature_correspondence_id'} );
            }
        }
    }
    $self->purge_query_cache( cache_level => 1 );
}

# ----------------------------------------------------
sub delete_maps {

    #
    # Deletes a map set.
    #
    my ( $self, %args ) = @_;
    my $command_line = $args{'command_line'};
    my $map_set_acc  = $args{'map_set_acc'};
    my $map_accs_str = $args{'map_accs'};
    my $sql_object   = $self->sql or die $self->error;
    my $map_set_id;
    my $map_set;
    my @map_ids;

    if ($command_line) {
        my @missing = ();
        unless ( defined($map_set_acc) or defined($map_accs_str) ) {
            push @missing, 'map_set_acc or map_accs';
        }
        if ( defined($map_accs_str) ) {
            my @map_accs = split /[,\s]+/, $map_accs_str;
            my $valid = 1;
            foreach my $acc (@map_accs) {
                my $map_id = $sql_object->acc_id_to_internal_id(
                    cmap_object => $self,
                    acc_id      => $acc,
                    object_type => 'map'
                );
                if ($map_id) {
                    push @map_ids, $map_id;
                }
                else {
                    print STDERR "The map_accs, '$acc' is not valid.\n";
                    $valid = 0;
                }
            }
            unless ($valid) {
                push @missing, 'valid map_accs';
            }
        }
        elsif ( defined($map_set_acc) ) {
            my $map_sets = $sql_object->get_map_sets(
                cmap_object => $self,
                map_set_acc => $map_set_acc,
            );
            if ( @{ $map_sets || [] } ) {
                $map_set    = $map_sets->[0];
                $map_set_id = $map_set->{'map_set_id'};
            }
            unless ($map_set_id) {
                print STDERR
                  "Map set Accession, '$map_set_acc' is not valid.\n";
                push @missing, 'valid map_set_acc';
            }
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            exit(0);
        }
    }
    else {
        my $map_sets = $self->get_map_sets( allow_mult => 0, allow_null => 0 );
        return unless @{ $map_sets || [] };
        $map_set    = $map_sets->[0];
        $map_set_id = $map_set->{'map_set_id'};

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

        if ( $delete_what eq 'some' ) {
            @map_ids = $self->show_menu(
                title      => 'Restrict by Map (optional)',
                prompt     => 'Select one or more maps',
                display    => 'map_name',
                return     => 'map_id',
                allow_null => 1,
                allow_mult => 1,
                data       => $sql_object->get_maps(
                    cmap_object => $self,
                    map_set_id  => $map_set_id
                ),
            );
        }

        my $map_names;
        if (@map_ids) {
            foreach my $map_id (@map_ids) {
                push @$map_names,
                  $sql_object->get_object_name(
                    cmap_object => $self,
                    object_id   => $map_id,
                    object_type => 'map',
                  );
            }
        }

        print join(
            "\n",
            map { $_ || () } 'OK to delete?',
            '  Data source : ' . $self->data_source,
            '  Map Set     : '
              . $map_set->{'species_common_name'} . '-'
              . $map_set->{'map_set_short_name'},
            (
                @{ $map_names || [] }
                ? '  Maps        : ' . join( ', ', @$map_names )
                : ''
            ),
            '[Y/n] ',
        );

        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;
    }

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
          . $map_set->{'species_common_name'} . '-'
          . $map_set->{'map_set_short_name'} . "'\n";
        $admin->map_set_delete( map_set_id => $map_set_id )
          or return $self->error( $admin->error );
    }
    $self->purge_query_cache( cache_level => 1 );
}

# ----------------------------------------------------
sub export_data {

    #
    # Exports data.
    #
    my $self = shift;

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
    my ( $self, %args ) = @_;
    my $command_line          = $args{'command_line'};
    my $species_acc           = $args{'species_acc'};
    my $map_set_accs          = $args{'map_set_accs'};
    my $map_type_acc          = $args{'map_type_acc'};
    my $feature_type_accs_str = $args{'feature_type_accs'};
    my $exclude_fields_str    = $args{'exclude_fields'};
    my $dir_str               = $args{'directory'};
    $dir_str = "." unless defined($dir_str);

    my $sql_object = $self->sql or die $self->error;
    my $log_fh = $self->log_fh;
    my $map_sets;
    my @feature_type_accs;
    my @exclude_fields;
    my $dir;

    # Column Names
    my @col_names = qw(
      map_acc
      map_name
      map_start
      map_stop
      feature_acc
      feature_name
      feature_aliases
      feature_start
      feature_stop
      feature_type_acc
      feature_dbxref_name
      feature_dbxref_url
      is_landmark
      feature_attributes
    );

    # Names of values returned that correspond to col_names
    my @val_names = qw(
      map_acc
      map_name
      map_start
      map_stop
      feature_acc
      feature_name
      feature_aliases
      feature_start
      feature_stop
      feature_type_acc
      feature_dbxref_name
      feature_dbxref_url
      is_landmark
      feature_attributes
    );

    if ($command_line) {
        my @missing = ();

        # if map_set_accs is defined, get those, otherwise rely on the species
        # and map type.  Either or both of those can be undef.
        if ( defined($map_set_accs) ) {

            # split on space or comma
            my @map_set_accs = split /[,\s]+/, $map_set_accs;
            if (@map_set_accs) {
                $map_sets = $sql_object->get_map_sets(
                    cmap_object  => $self,
                    map_set_accs => \@map_set_accs,
                );
            }
            unless ( @{ $map_sets || [] } ) {
                print STDERR
                  "Map set Accession(s), '$map_set_accs' is/are not valid.\n";
                push @missing, 'valid map_set_accs';
            }
        }
        else {
            my $species_id;
            if ( defined($species_acc) ) {
                $species_id = $sql_object->acc_id_to_internal_id(
                    cmap_object => $self,
                    acc_id      => $species_acc,
                    object_type => 'species'
                );
                unless ($species_id) {
                    print STDERR
                      "The species_acc, '$species_acc' is not valid.\n";
                    push @missing, 'valid species_acc';
                }
            }
            if ($map_type_acc) {
                unless ( $self->map_type_data($map_type_acc) ) {
                    print STDERR "The map_type_acc, '$map_type_acc' "
                      . "is not valid.\n";
                    push @missing, 'valid map_type_acc';
                }
            }
            $map_sets = $sql_object->get_map_sets(
                cmap_object  => $self,
                species_id   => $species_id,
                map_type_acc => $map_type_acc,
            );
            unless ( @{ $map_sets || [] } ) {
                print STDERR
                  "No map set constraints given.\n";
                push @missing, 'map_set_accs or species_acc or map_type_acc';
            }
        }
        if ( defined($feature_type_accs_str) ) {
            @feature_type_accs = split /[,\s]+/, $feature_type_accs_str;
            my $valid = 1;
            foreach my $fta (@feature_type_accs) {
                unless ( $self->feature_type_data($fta) ) {
                    print STDERR "The feature_type_acc, '$fta' is not valid.\n";
                    $valid = 0;
                }
            }
            unless ($valid) {
                push @missing, 'valid feature_type_acc';
            }
        }
        if ($exclude_fields_str) {
            @exclude_fields = split /[,\s]+/, $exclude_fields_str;
            my $valid = 1;
            foreach my $ef (@exclude_fields) {
                my $found = 0;
                foreach my $column (@col_names) {
                    if ( $ef eq $column ) {
                        $found = 1;
                        last;
                    }
                }
                unless ($found) {
                    print STDERR
                      "The exclude_fields name '$ef' is not valid.\n";
                    $valid = 0;
                }
            }
            unless ($valid) {
                exit(0);
            }
            if ( @exclude_fields == @col_names ) {
                print "\nError:  Can't exclude all the fields!\n";
                exit(0);
            }
        }
        $dir = $self->_get_dir( dir_str => $dir_str ) or return;
        unless ( defined($dir) ) {
            push @missing, 'valid directory';
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            exit(0);
        }
    }
    else {

        $map_sets = $self->get_map_sets or return;
        my $feature_types_ref = $self->get_feature_types;

        @exclude_fields = $self->show_menu(
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

        $dir = $self->_get_dir() or return;

        my @map_set_names;
        if ( @{ $map_sets || [] } ) {
            @map_set_names =
              map {
                join( '-',
                    $_->{'species_common_name'},
                    $_->{'map_set_short_name'} )
              } @$map_sets;
        }
        else {
            @map_set_names = ('All');
        }
        my $display_feature_types;
        if (@$feature_types_ref) {
            $display_feature_types = $feature_types_ref;
        }
        else {
            $display_feature_types = [ [ 'All', 'All' ], ];
        }

        @feature_type_accs = map { $_->[0] } @$feature_types_ref;

        my $excluded_fields =
          @exclude_fields ? join( ', ', @exclude_fields ) : 'None';

        #
        # Confirm decisions.
        #
        print join( "\n",
            'OK to export?',
            '  Data source     : ' . $self->data_source,
            "  Map Sets        :\n"
              . join( "\n", map { "    $_" } @map_set_names ),
            "  Feature Types   :\n"
              . join( "\n", map { "    $_->[1]" } @$display_feature_types ),
            "  Exclude Fields  : $excluded_fields",
            "  Directory       : $dir",
            "[Y/n] " );
        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;
    }

    my %exclude = map { $_, 1 } @exclude_fields;
    for ( my $i = 0 ; $i <= $#col_names ; $i++ ) {
        if ( $exclude{ $col_names[$i] } ) {
            splice( @col_names, $i, 1 );
            splice( @val_names, $i, 1 );
            $i--;
        }
    }

    for my $map_set (@$map_sets) {
        my $map_set_id          = $map_set->{'map_set_id'};
        my $map_set_short_name  = $map_set->{'map_set_short_name'};
        my $species_common_name = $map_set->{'species_common_name'};
        my $file_name = join( '-', $species_common_name, $map_set_short_name );
        $file_name =~ tr/a-zA-Z0-9-/_/cs;
        $file_name = "$dir/$file_name.dat";

        print $log_fh "Dumping '$species_common_name-$map_set_short_name' "
          . "to '$file_name'\n";
        open my $fh, ">$file_name" or die "Can't write to $file_name: $!\n";
        print $fh join( OFS, @col_names ), ORS;

        my $maps = $sql_object->get_maps_simple(
            cmap_object => $self,
            map_set_id  => $map_set_id,
        );

        my $attributes = $sql_object->get_attributes(
            cmap_object => $self,
            object_type => 'feature',
        );

        my %attr_lookup = ();
        for my $a (@$attributes) {
            push @{ $attr_lookup{ $a->{'object_id'} } },
              qq[$a->{'attribute_name'}: "$a->{'attribute_value'}"];
        }

        for my $map (@$maps) {
            my $features = $sql_object->get_features(
                cmap_object       => $self,
                feature_type_accs => \@feature_type_accs,
                map_id            => $map->{'map_id'},
            );

            my $aliases = $sql_object->get_feature_aliases(
                cmap_object => $self,
                map_id      => $map->{'map_id'},
            );

            my %alias_lookup = ();
            for my $a (@$aliases) {
                push @{ $alias_lookup{ $a->{'feature_id'} } }, $a->{'alias'};
            }

            for my $feature (@$features) {
                $feature->{'feature_stop'} = undef
                  if $feature->{'feature_stop'} < $feature->{'feature_start'};

                $feature->{'feature_attributes'} = join( '; ',
                    @{ $attr_lookup{ $feature->{'feature_id'} } || [] } );

                $feature->{'feature_aliases'} = join( ',',
                    map { s/"/\\"/g ? qq["$_"] : $_ }
                      @{ $alias_lookup{ $feature->{'feature_id'} || [] } } );

                print $fh join( OFS, map { $feature->{$_} } @val_names ), ORS;
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
    my ( $self, %args ) = @_;
    my $command_line = $args{'command_line'};
    my $file         = $args{'export_file'};
    my $add_truncate = $args{'add_truncate'};
    $add_truncate = 1 unless ( defined($add_truncate) );
    my $quote_escape    = $args{'quote_escape'};
    my $dump_tables_str = $args{'tables'};
    my @dump_tables;
    my $default_file = './cmap_dump.sql';

    my $sql_object = $self->sql or die $self->error;
    my $db         = $self->db  or die $self->error;
    my $log_fh = $self->log_fh;

    my $quote_escape_options = [
        { display => 'Doubled',   action => 'doubled' },
        { display => 'Backslash', action => 'backslash' },
    ];
    my @tables = @{ $sql_object->get_table_info() };

    if ($command_line) {
        my @missing = ();
        if ( defined($file) ) {
            if ( -d $file ) {
                print "'$file' is a directory.  Please give me a file path.\n";
                push @missing, 'export_file';
            }
            elsif ( -e _ && not -w _ ) {
                print "'$file' exists and you don't have "
                  . "permissions to overwrite.\n";
                push @missing, 'export_file';
            }
        }
        else {
            $file = $default_file;
        }
        if ($quote_escape) {
            my $found = 0;
            foreach my $item (@$quote_escape_options) {
                if ( $quote_escape eq $item->{'action'} ) {
                    $found = 1;
                }
            }
            unless ($found) {
                print STDERR "The quote_escape, '$quote_escape' "
                  . "is not valid.\n";
                push @missing, 'quote_escape';
            }
        }
        else {
            push @missing, 'quote_escape';
        }
        if ( !$dump_tables_str or $dump_tables_str =~ /^all$/i ) {
            @dump_tables = map { $_->{'name'} } @tables;
        }
        else {
            @dump_tables = split /[,\s]+/, $dump_tables_str;
            my $valid = 1;
            foreach my $dump_table (@dump_tables) {
                my $found = 0;
                foreach my $table (@tables) {
                    if ( $dump_table eq $table->{'name'} ) {
                        $found = 1;
                        last;
                    }
                }
                unless ($found) {
                    print STDERR
                      "The table name '$dump_table' is not valid.\n";
                    $valid = 0;
                }
            }
            unless ($valid) {
                push @missing, 'tables';
            }
        }

        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            exit(0);
        }
    }
    else {

        #
        # Ask user what/how/where to dump.
        #
        @dump_tables = $self->show_menu(
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
        $add_truncate = $answer =~ m/^[yY]/;

        for ( ; ; ) {
            print "Where would you like to write the file?\n",
              "['q' to quit, '$default_file' is default] ";
            chomp( my $user_file = <STDIN> );
            $user_file ||= $default_file;

            if ( -d $user_file ) {
                print
                  "'$user_file' is a directory.  Please give me a file path.\n";
                next;
            }
            elsif ( -e _ && -w _ ) {
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
                print
                  "'$user_file' exists & isn't writable by you.  Try again.\n";
                next;
            }
            else {
                $file = $user_file;
                last;
            }
        }

        $quote_escape = $self->show_menu(
            title  => 'Quote Style',
            prompt => "How should embeded quotes be escaped?\n"
              . 'Hint: Oracle and Sybase like [1], MySQL likes [2]',
            display => 'display',
            return  => 'action',
            data    => $quote_escape_options,
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
    }

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
    my ( $self, %args ) = @_;
    my $command_line = $args{'command_line'};
    my $species_acc  = $args{'species_acc'};
    my $map_set_accs = $args{'map_set_accs'};
    my $map_type_acc = $args{'map_type_acc'};

    #my $feature_type_accs_str = $args{'feature_type_accs'};
    my $object_str = $args{'export_objects'};
    my $file_name  = $args{'export_file'} || 'cmap_export.xml';
    my $dir_str    = $args{'directory'};
    $dir_str = "." unless defined($dir_str);
    my $sql_object = $self->sql;
    my $export_path;
    my @db_objects;
    my $map_sets;

    #my $feature_types

    my $object_options = [
        {
            object_type => 'map_set',
            object_name => 'Map Sets',
        },
        {
            object_type => 'species',
            object_name => 'Species',
        },
        {
            object_type => 'feature_correspondence',
            object_name => 'Feature Correspondence',
        },
        {
            object_type => 'xref',
            object_name => 'Cross-references',
        },
    ];

    if ($command_line) {
        my @missing = ();

        if ( !$object_str or $object_str =~ /^all$/i ) {
            @db_objects = map { $_->{'object_type'} } @$object_options;
        }
        else {
            @db_objects = split /[,\s]+/, $object_str;
            my $valid = 1;
            foreach my $ob (@db_objects) {
                my $found = 0;
                foreach my $option (@$object_options) {
                    if ( $ob eq $option->{'object_type'} ) {
                        $found = 1;
                        last;
                    }
                }
                unless ($found) {
                    print STDERR
                      "The export_objects name '$ob' is not valid.\n";
                    $valid = 0;
                }
            }
            unless ($valid) {
                exit(0);
            }
        }

        # if map_set_accs is defined, get those, otherwise rely on the species
        # and map type.  Either or both of those can be undef.
        if ( grep { /map_set/ } @db_objects ) {
            if ( defined($map_set_accs) ) {

                # split on space or comma
                my @map_set_accs = split /[,\s]+/, $map_set_accs;
                if (@map_set_accs) {
                    $map_sets = $sql_object->get_map_sets(
                        cmap_object  => $self,
                        map_set_accs => \@map_set_accs,
                    );
                }
                unless ( @{ $map_sets || [] } ) {
                    print STDERR
"Map set Accession(s), '$map_set_accs' is/are not valid.\n";
                    push @missing, 'valid map_set_accs';
                }
            }
            else {
                my $species_id;
                if ( defined($species_acc) ) {
                    $species_id = $sql_object->acc_id_to_internal_id(
                        cmap_object => $self,
                        acc_id      => $species_acc,
                        object_type => 'species'
                    );
                    unless ($species_id) {
                        print STDERR
                          "The species_acc, '$species_acc' is not valid.\n";
                        push @missing, 'valid species_acc';
                    }
                }
                if ($map_type_acc) {
                    unless ( $self->map_type_data($map_type_acc) ) {
                        print STDERR "The map_type_acc, '$map_type_acc' "
                          . "is not valid.\n";
                        push @missing, 'valid map_type_acc';
                    }
                }
                $map_sets = $sql_object->get_map_sets(
                    cmap_object  => $self,
                    species_id   => $species_id,
                    map_type_acc => $map_type_acc,
                );
            }

       #if ( defined($feature_type_accs_str) ) {
       #    @feature_type_accs = split /[,\s]+/, $feature_type_accs_str;
       #    my $valid = 1;
       #    foreach my $fta (@feature_type_accs) {
       #        unless ( $self->feature_type_data($fta) ) {
       #            print STDERR "The feature_type_acc, '$fta' is not valid.\n";
       #            $valid = 0;
       #        }
       #    }
       #    unless ($valid) {
       #        push @missing, 'valid feature_type_acc';
       #    }
       #}
        }
        my $dir = $self->_get_dir( dir_str => $dir_str ) or return;
        unless ( defined($dir) ) {
            push @missing, 'valid directory';
        }
        $export_path = catfile( $dir, $file_name );

        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            exit(0);
        }
    }
    else {
        for ( ; ; ) {
            my $dir = $self->_get_dir() or return;

            print 'What file name [cmap_export.xml]? ';
            chomp( $file_name = <STDIN> );
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
            data       => $object_options,
        );

        @db_objects = map { $_->[0] } @objects;
        my @object_names = map { $_->[1] } @objects;

        my @confirm = (
            '  Data source  : ' . $self->data_source,
            '  Objects      : ' . join( ', ', @object_names ),
            "  File name    : $export_path",
        );

        if ( grep { /map_set/ } @db_objects ) {
            $map_sets = $self->get_map_sets or return;

            #$feature_types = $self->get_feature_types;
            #my @ft_names = map { $_->{'feature_type'} } @$feature_types;
            my @map_set_names =
              map {
                    $_->{'species_common_name'} . '-'
                  . $_->{'map_set_short_name'} . ' ('
                  . $_->{'map_type'} . ')'
              } @$map_sets;

            @map_set_names = ('All') unless @map_set_names;

            #@ft_names      = ('All') unless @ft_names;

            push @confirm, (
                "  Map Sets     :\n"
                  . join( "\n", map { "    $_" } @map_set_names ),

            #   "  Feature Types:\n" . join( "\n", map { "    $_" } @ft_names ),
            );
        }

        #
        # Confirm decisions.
        #
        print join( "\n", 'OK to export?', @confirm, '[Y/n] ' );
        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;
    }

    my $exporter =
      Bio::GMOD::CMap::Admin::Export->new( data_source => $self->data_source );

    $exporter->export(
        objects     => \@db_objects,
        output_path => $export_path,
        log_fh      => $self->log_fh,
        map_sets    => $map_sets,

        #feature_types => $feature_types, NOT USED
      )
      or do {
        print "Error: ", $exporter->error, "\n";
        return;
      };

    return 1;
}

# ----------------------------------------------------
sub get_files {

    #
    # Ask the user for files.
    #
    my ( $self, %args ) = @_;
    my $file_str = $args{'file_str'} || '';
    my $allow_mult = defined $args{'allow_mult'} ? $args{'allow_mult'} : 1;
    my $prompt =
        defined $args{'prompt'} ? $args{'prompt'}
      : $allow_mult             ? 'Please specify the files?[q to quit] '
      : 'Please specify the file?[q to quit] ';
    my $term = $self->term;

    ###New File Handling
    while ( $file_str !~ /\S/ ) {
        $file_str = $term->readline($prompt);
        return undef if $file_str =~ m/^[Qq]$/;
    }
    $term->addhistory($file_str);

    my @file_strs = split( /\s+/, $file_str );
    my @files     = ();

    # allow filename expantion and put into @files
    foreach my $str (@file_strs) {
        my @tmp_files = glob($str);
        print "WARNING: Unable to read '$str'!\n" unless (@tmp_files);
        push @files, @tmp_files;
    }
    foreach ( my $i = 0 ; $i <= $#files ; $i++ ) {
        if ( -r $files[$i] and -f $files[$i] ) {
            print "$files[$i] read correctly.\n";
        }
        else {
            print "WARNING: Unable to read file '$files[$i]'!\n";
            splice( @files, $i, 1 );
            $i--;
        }
    }
    return \@files if (@files);
    return undef;
}

# ----------------------------------------------------
sub get_map_sets {

    #
    # Help user choose map sets.
    #
    my ( $self, %args ) = @_;
    my $allow_mult = defined $args{'allow_mult'} ? $args{'allow_mult'} : 1;
    my $allow_null = defined $args{'allow_null'} ? $args{'allow_null'} : 1;
    my $sql_object = $self->sql or die $self->error;
    my $log_fh     = $self->log_fh;

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
        $map_sets = $sql_object->get_map_sets(
            cmap_object  => $self,
            map_set_accs => \@accessions,
        );
        unless ( $map_sets and @$map_sets ) {
            print "Those map sets were not in the database!\n";
            return;
        }
        return unless @$map_sets;
    }
    else {
        my $map_type_results =
          $sql_object->get_used_map_types( cmap_object => $self, );
        unless (@$map_type_results) {
            print
              "No map sets in the database!  Use cmap_admin.pl to create.\n";
            return;
        }

        $map_type_results =
          sort_selectall_arrayref( $map_type_results, 'map_type' );

        my @map_types = $self->show_menu(
            title      => 'Restrict by Map Set by Map Types',
            prompt     => 'Limit map sets by which map types?',
            display    => 'map_type',
            return     => 'map_type_acc,map_type',
            allow_null => $allow_null,
            allow_mult => $allow_mult,
            data       => $map_type_results,
        );
        if ( @map_types and ref $map_types[0] ne 'ARRAY' ) {
            @map_types = @{ [ [@map_types] ] };
        }

        my $map_set_species = $sql_object->get_map_sets(
            cmap_object   => $self,
            map_type_accs => \@map_types,
        );
        die "No species! Please create.\n"
          unless @$map_set_species;

        # eliminate redundancy
        $map_set_species =
          sort_selectall_arrayref( $map_set_species, 'species_id' );
        my $tmp_species_id;
        for ( my $i = 0 ; $i <= $#{$map_set_species} ; $i++ ) {
            if ( $tmp_species_id == $map_set_species->[$i]{'species_id'} ) {
                splice( @$map_set_species, $i, 1 );
                $i--;
            }
            $tmp_species_id = $map_set_species->[$i]{'species_id'};
        }

        my $species_ids = $self->show_menu(
            title      => 'Restrict by Species',
            prompt     => 'Limit by which species?',
            display    => 'species_common_name',
            return     => 'species_id',
            allow_null => $allow_null,
            allow_mult => $allow_mult,
            data       => $map_set_species,
        );

        if ( defined($species_ids) and ref $species_ids ne 'ARRAY' ) {
            $species_ids = [ $species_ids, ];
        }

        my $ms_choices = $sql_object->get_map_sets(
            cmap_object   => $self,
            map_type_accs => \@map_types,
            species_ids   => $species_ids,
        );

        my $map_set_ids = $self->show_menu(
            title      => 'Restrict by Map Sets',
            prompt     => 'Limit by which map sets?',
            display    => 'map_type,species_common_name,map_set_short_name',
            return     => 'map_set_id',
            allow_null => $allow_null,
            allow_mult => $allow_mult,
            data       => $ms_choices,
        );
        if ( defined($map_set_ids) and ref $map_set_ids ne 'ARRAY' ) {
            $map_set_ids = [ $map_set_ids, ];
        }

        $map_sets = $sql_object->get_map_sets(
            cmap_object => $self,
            map_set_ids => $map_set_ids,
            species_ids => $species_ids,
        );
        $map_sets =
          sort_selectall_arrayref( $map_sets,
            'species_common_name, map_set_short_name' );

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
        my $sql_object = $self->sql or die $self->error;
        $ft_sql_data = $sql_object->get_used_feature_types(
            cmap_object => $self,
            map_set_ids => \@map_set_ids,
        );
    }
    else {
        $ft_sql_data =
          $self->fake_selectall_arrayref( $self->feature_type_data(),
            'feature_type_acc', 'feature_type' );
    }
    $ft_sql_data = sort_selectall_arrayref( $ft_sql_data, 'feature_type' );

    my @feature_types = $self->show_menu(
        title      => 'Restrict by Feature Types',
        prompt     => 'Limit export by feature types?',
        display    => 'feature_type',
        return     => 'feature_type_acc,feature_type',
        allow_null => 1,
        allow_mult => 1,
        data       => $ft_sql_data,
    );

    return \@feature_types;
}

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
                action  => 'import_alignments',
                display => 'Import Alignment (ex: BLAST)'
            },
            {
                action  => 'import_object_data',
                display => 'Import CMap objects [experimental]'
            },
        ],
    );

    $self->$action();
}

# ----------------------------------------------------
sub manage_links {

    #
    # Determine what kind of data to import (new or old)
    #
    my $self = shift;
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
    my $sql_object = $self->sql or die $self->error;

    #
    # Get the species.
    #
    my ( $species_id, $species_common_name ) = $self->show_menu(
        title   => "Available Species",
        prompt  => 'Please select a species',
        display => 'species_common_name',
        return  => 'species_id,species_common_name',
        data    => $sql_object->get_species( cmap_object => $self ),
    );
    do { print "No species to select from.\n"; return } unless $species_id;

    #
    # Get the map set.
    #
    my ( $map_set_id, $map_set_name ) = $self->show_menu(
        title   => "Available Map Sets (for $species_common_name)",
        prompt  => 'Please select a map set',
        display => 'map_set_name',
        return  => 'map_set_id,map_set_name',
        data    => $sql_object->get_map_sets(
            cmap_object => $self,
            species_id  => $species_id
        ),
    );
    do { print "There are no map sets!\n"; return }
      unless $map_set_id;

    ###New File Handling
    my $files = $self->get_files() or return;

    my $link_set_name = $self->show_question(
        question => 'What should this link set be named (default='
          . $files->[0] . ')?',
        default => $files->[0],
    );
    $link_set_name = "map set $map_set_id:" . $link_set_name;

    #
    # Confirm decisions.
    #
    print join( "\n",
        'OK to import?',
        '  Data source     : ' . $self->data_source,
        "  File            : " . join( ", ", @$files ),
        "  Species         : $species_common_name",
        "  Map Study       : $map_set_name",
        "  Link Set        : $link_set_name",
        "[Y/n] " );
    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my $link_manager =
      Bio::GMOD::CMap::Admin::ManageLinks->new(
        data_source => $self->data_source, );

    foreach my $file (@$files) {
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
    my ( $self, %args ) = @_;
    my $command_line = $args{'command_line'};
    my $file_str     = $args{'file_str'};
    my $map_set_accs = $args{'map_set_accs'};
    my $sql_object   = $self->sql or die $self->error;
    my $single_file  = $self->file;
    my $term         = $self->term;
    my $files;
    my @map_set_ids;

    if ($command_line) {
        my @missing = ();
        if ($file_str) {
            unless ( $files = $self->get_files( file_str => $file_str ) ) {
                print STDERR "None of the files, '$file_str' succeded.\n";
                push @missing, 'input file(s)';
            }
        }
        else {
            push @missing, 'input file(s)';
        }
        if ( defined($map_set_accs) ) {

            # split on space or comma
            my @map_set_accs = split /[,\s]+/, $map_set_accs;
            my $map_sets;
            if (@map_set_accs) {
                $map_sets = $sql_object->get_map_sets(
                    cmap_object  => $self,
                    map_set_accs => \@map_set_accs,
                );
            }
            unless ( @{ $map_sets || [] } ) {
                print STDERR
                  "Map set Accession(s), '$map_set_accs' is/are not valid.\n";
                push @missing, 'map_set_accs';
            }
            @map_set_ids = map { $_->{'map_set_id'} } @$map_sets;
        }
        else {
            push @missing, 'map_set_acc';
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            exit(0);
        }
    }
    else {

        #
        # Make sure we have a file to parse.
        #
        if ($single_file) {
            print "OK to use '$single_file'? [Y/n] ";
            chomp( my $answer = <STDIN> );
            $single_file = '' if $answer =~ m/^[Nn]/;
        }

        if ( -r $single_file and -f _ ) {
            push @$files, $single_file;
        }
        else {
            print "Unable to read '$single_file' or not a regular file.\n"
              if $single_file;
            $files = $self->get_files() or return;
        }

        #
        # Get the map set.
        #
        my @map_sets = $self->show_menu(
            title      => 'Restrict by Map Set (optional)',
            prompt     => 'Please select a map set to restrict the search',
            display    => 'species_common_name,map_set_short_name',
            return     => 'map_set_id,species_common_name,map_set_short_name',
            allow_null => 1,
            allow_mult => 1,
            data       => sort_selectall_arrayref(
                $sql_object->get_map_sets( cmap_object => $self, ),
                'species_common_name, map_set_short_name'
            ),
        );

        @map_set_ids = map { $_->[0] } @map_sets;

        print join( "\n",
            'OK to import?',
            '  Data source   : ' . $self->data_source,
            "  File          : " . join( ", ", @$files ),
        );

        if (@map_sets) {
            print join( "\n",
                '',
                '  From map sets :',
                map { "    $_" }
                  map { join( '-', $_->[1], $_->[2] ) } @map_sets );
        }
        print "\n[Y/n] ";

        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;
    }

    my $importer =
      Bio::GMOD::CMap::Admin::ImportCorrespondences->new(
        data_source => $self->data_source, );
    foreach my $file (@$files) {
        my $fh = IO::File->new($file) or die "Can't read $file: $!";
        $self->file($file);
        $importer->import(
            fh          => $fh,
            map_set_ids => \@map_set_ids,
            log_fh      => $self->log_fh,
          )
          or do {
            print "Error: ", $importer->error, "\n";
            return;
          };
    }
    $self->purge_query_cache( cache_level => 4 );
}

# ----------------------------------------------------
sub import_alignments {

    #
    # Gathers the info to import feature correspondences.
    #
    my ( $self, %args ) = @_;
    my $command_line      = $args{'command_line'};
    my $file_str          = $args{'file_str'};
    my $from_map_set_acc  = $args{'from_map_set_acc'};
    my $to_map_set_acc    = $args{'to_map_set_acc'};
    my $format            = $args{'format'};
    my $feature_type_acc  = $args{'feature_type_acc'};
    my $evidence_type_acc = $args{'evidence_type_acc'};
    my $single_file       = $self->file;
    my $term              = $self->term;
    my $sql_object        = $self->sql;
    my $files;
    my $query_map_set_id;
    my $hit_map_set_id;

    my $formats = [
        {
            display => 'BLAST',
            format  => 'blast'
        },
    ];

    if ($command_line) {
        my @missing = ();
        if ($file_str) {
            unless ( $files = $self->get_files( file_str => $file_str ) ) {
                print STDERR "None of the files, '$file_str' succeded.\n";
                push @missing, 'input file(s)';
            }
        }
        else {
            push @missing, 'input file(s)';
        }
        if ( defined($from_map_set_acc) ) {
            $query_map_set_id = $sql_object->acc_id_to_internal_id(
                cmap_object => $self,
                acc_id      => $from_map_set_acc,
                object_type => 'map_set'
            );
            unless ($query_map_set_id) {
                print STDERR
                  "Map set Accession, '$from_map_set_acc' is not valid.\n";
                push @missing, 'from_map_set_acc';
            }
        }
        else {
            push @missing, 'from_map_set_acc';
        }
        if ( defined($to_map_set_acc) ) {
            $query_map_set_id = $sql_object->acc_id_to_internal_id(
                cmap_object => $self,
                acc_id      => $to_map_set_acc,
                object_type => 'map_set'
            );
            unless ($query_map_set_id) {
                print STDERR
                  "Map set Accession, '$to_map_set_acc' is not valid.\n";
                push @missing, 'to_map_set_acc';
            }
        }
        else {
            push @missing, 'to_map_set_acc';
        }
        if ( defined($feature_type_acc) ) {
            unless ( $self->feature_type_data($feature_type_acc) ) {
                print STDERR
                  "The feature_type_acc, '$feature_type_acc' is not valid.\n";
                push @missing, 'feature_type_acc';
            }
        }
        else {
            push @missing, 'feature_type_acc';
        }
        if ( defined($evidence_type_acc) ) {
            unless ( $self->evidence_type_data($evidence_type_acc) ) {
                print STDERR
                  "The evidence_type_acc, '$evidence_type_acc' is not valid.\n";
                push @missing, 'evidence_type_acc';
            }
        }
        else {
            push @missing, 'evidence_type_acc';
        }
        if ($format) {
            my $found = 0;
            foreach my $item (@$formats) {
                if ( $format eq $item->{'format'} ) {
                    $found = 1;
                }
            }
            unless ($found) {
                print STDERR "The format, '$format' is not valid.\n";
                push @missing, 'format';
            }
        }
        else {
            push @missing, 'evidence_type_acc';
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            exit(0);
        }
    }
    else {

        #
        # Make sure we have a file to parse.
        #
        if ($single_file) {
            print "OK to use '$single_file'? [Y/n] ";
            chomp( my $answer = <STDIN> );
            $single_file = '' if $answer =~ m/^[Nn]/;
        }

        if ( -r $single_file and -f _ ) {
            push @$files, $single_file;
        }
        else {
            print "Unable to read '$single_file' or not a regular file.\n"
              if $single_file;
            $files = $self->get_files() or return;
        }

        #
        # Get the map set.
        #
        my $query_map_sets = $self->get_map_sets(
            explanation => 'First you will select the map set of the Query',
            allow_mult  => 0,
            allow_null  => 0,
          )
          or return;
        my $use_query_as_hit_answer =
          $self->show_question( question =>
              'Do you want to use the query map set as the Subject set? [y|N]',
          );
        my $hit_map_sets;
        if ( $use_query_as_hit_answer =~ /^y/ ) {
            $hit_map_sets = $query_map_sets;
        }
        else {
            $hit_map_sets = $self->get_map_sets(
                explanation => 'Now you will select the subject map set',
                allow_mult  => 0,
                allow_null  => 0,
              )
              or return;
        }

        $query_map_set_id = $query_map_sets->[0]{'map_set_id'};
        $hit_map_set_id   = $hit_map_sets->[0]{'map_set_id'};

        #
        # Get the feature type
        #
        my @feature_type = $self->show_menu(
            title  => 'Feature Type of the Hits',
            prompt => "Select the feature type that the newly "
              . "created features will be assigned.\n"
              . "It is recommended that alignment features have "
              . "their own feature type such as blast_alignment.",
            display    => 'feature_type',
            return     => 'feature_type_acc,feature_type',
            allow_null => 0,
            allow_mult => 0,
            data       => sort_selectall_arrayref(
                $self->fake_selectall_arrayref(
                    $self->feature_type_data(), 'feature_type_acc',
                    'feature_type'
                ),
                'feature_type'
            ),
        );

        #
        # Get the evidence type
        #
        my @evidence_type = $self->show_menu(
            title  => 'Evidence Type of the Hits',
            prompt => "Select the evidence type that the newly created "
              . "evidences will be assigned.\n"
              . "It is recommended that alignment "
              . "evidences have their own evidence type such as blast_alignment.",
            display    => 'evidence_type',
            return     => 'evidence_type_acc,evidence_type',
            allow_null => 0,
            allow_mult => 0,
            data       => $self->fake_selectall_arrayref(
                $self->evidence_type_data(), 'evidence_type_acc',
                'evidence_type'
            ),
        );

        $feature_type_acc    => $feature_type[0],
          $evidence_type_acc => $evidence_type[0],

          #
          # Get the format of the alignment (BLAST...)
          #
          # SearchIO.pm from BioPerl has a list of available formats.
          # Currently only BLAST is included because that is the only one
          # that I have files to test.

          $format = $self->show_menu(
            title   => 'Alignment Format',
            prompt  => 'What format is the alignment in?',
            display => 'display',
            return  => 'format',
            data    => $formats,
          );

        print join( "\n",
            'OK to import?',
            '  Data source     : ' . $self->data_source,
            "  File            : " . join( ", ", @$files ),
            '  Query Map Set   : ' . $query_map_sets->[0]{'map_set_short_name'},
            '  Subject Map Set : ' . $hit_map_sets->[0]{'map_set_short_name'},
            '  Feature Type    : ' . $feature_type[1],
            '  Evidence Type   : ' . $evidence_type[1],
            '  Format          : ' . $format,
        );

        print "\n[Y/n] ";

        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;
    }

    my $importer =
      Bio::GMOD::CMap::Admin::ImportAlignments->new(
        data_source => $self->data_source, );
    foreach my $file (@$files) {
        $importer->import_alignments(
            file_name         => $file,
            query_map_set_id  => $query_map_set_id,
            hit_map_set_id    => $hit_map_set_id,
            feature_type_acc  => $feature_type_acc,
            evidence_type_acc => $evidence_type_acc,
            format            => $format,
            log_fh            => $self->log_fh,
          )
          or do {
            print "Error: ", $importer->error, "\n";
            return;
          };
    }
    $self->purge_query_cache( cache_level => 2 );
}

# ----------------------------------------------------
sub delete_duplicate_correspondences {

    #
    # deletes all duplicate correspondences.
    #
    my $self = shift;

    my $admin = Bio::GMOD::CMap::Admin->new(
        config      => $self->config,
        data_source => $self->data_source,
    );

    $admin->delete_duplicate_correspondences();

    $self->purge_query_cache( cache_level => 4 );
}

# ----------------------------------------------------

sub purge_query_cache_menu {

    my $self = shift;

    my $cache_level = $self->show_menu(
        title  => '  --= Cache Level =--  ',
        prompt => "At which cache level would you like to start the purging?\n"
          . "(The purges cascade down. ie selecting level 3 removes 3 and 4):",
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

    $self->purge_query_cache( cache_level => $cache_level );
}

# ----------------------------------------------------
sub purge_query_cache {

    my ( $self, %args ) = @_;
    my $cache_level = $args{'cache_level'} || 1;

    my $admin = Bio::GMOD::CMap::Admin->new(
        config      => $self->config,
        data_source => $self->data_source,
    );
    print "Purging cache at level $cache_level.\n";
    $admin->purge_cache($cache_level);
    print "Cache Purged\n";
}

# ----------------------------------------------------
sub import_tab_data {

    #
    # Imports simple (old) tab-delimited format
    #
    my ( $self, %args ) = @_;
    my $command_line = $args{'command_line'};
    my $file_str     = $args{'file_str'};
    my $map_set_acc  = $args{'map_set_acc'};
    my $overwrite    = $args{'overwrite'} || 0;
    my $allow_update = $args{'allow_update'} || 0;
    my $sql_object   = $self->sql;
    my ( $map_set, $files );

    if ($command_line) {
        my @missing = ();
        if ($file_str) {
            unless ( $files = $self->get_files( file_str => $file_str ) ) {
                print STDERR "None of the files, '$file_str' succeded.\n";
                push @missing, 'input file(s)';
            }
        }
        else {
            push @missing, 'input file(s)';
        }
        if ( defined($map_set_acc) ) {
            my $map_sets = $sql_object->get_map_sets(
                cmap_object => $self,
                map_set_acc => $map_set_acc,
            );
            unless ( @{ $map_sets || [] } ) {
                print STDERR
                  "Map set Accession, '$map_set_acc' is not valid.\n";
                push @missing, 'map_set_acc';
            }
            $map_set = $map_sets->[0];
        }
        else {
            push @missing, 'map_set_acc';
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            exit(0);
        }
    }
    else {

        ###New File Handling
        $files = $self->get_files() or return;

        my $map_sets = $self->get_map_sets( allow_mult => 0, allow_null => 0 );
        return unless @{ $map_sets || [] };
        $map_set = $map_sets->[0];

        print "Remove data in map set not in import file? [y/N] ";
        chomp( $overwrite = <STDIN> );
        $overwrite = ( $overwrite =~ /^[Yy]/ ) ? 1 : 0;

        print "\nNOTE: If yes to the following, features on the same map with "
          . "the same name \nwill be treated as duplicates.  "
          . "Be sure to select the default, 'NO', if that \n"
          . "will create problems for your data.\n"
          . "Check for duplicate data (slow)? [y/N]";
        chomp( $allow_update = <STDIN> );
        $allow_update = ( $allow_update =~ /^[Yy]/ ) ? 1 : 0;

        #
        # Confirm decisions.
        #
        print join( "\n",
            'OK to import?',
            '  Data source : ' . $self->data_source,
            "  File        : " . join( ", ", @$files ),
            "  Species     : " . $map_set->{species_common_name},
            "  Map Type    : " . $map_set->{map_type},
            "  Map Set     : " . $map_set->{map_set_short_name},
            "  Map Set Acc : " . $map_set->{map_set_acc},
            "  Overwrite   : " .     ( $overwrite    ? "Yes" : "No" ),
            "  Update Features : " . ( $allow_update ? "Yes" : "No" ),
            "[Y/n] " );
        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;
    }

    my $importer =
      Bio::GMOD::CMap::Admin::Import->new( data_source => $self->data_source, );

    my $time_start = new Benchmark;
    my %maps;    #stores the maps info between each file
    foreach my $file (@$files) {
        my $fh = IO::File->new($file) or die "Can't read $file: $!";
        $importer->import_tab(
            map_set_id   => $map_set->{'map_set_id'},
            fh           => $fh,
            map_type_acc => $map_set->{'map_type_acc'},
            log_fh       => $self->log_fh,
            overwrite    => $overwrite,
            allow_update => $allow_update,
            maps         => \%maps,
          )
          or do {
            print "Error: ", $importer->error, "\n";
            return;
          };
    }

    my $time_end = new Benchmark;
    print STDERR "import time: "
      . timestr( timediff( $time_end, $time_start ) ) . "\n";

    $self->purge_query_cache( cache_level => 1 );
}

# ----------------------------------------------------
sub import_object_data {

    #
    # Gathers the info to import physical or genetic maps.
    #
    my ( $self, %args ) = @_;
    my $command_line = $args{'command_line'};
    my $file_str     = $args{'file_str'};
    my $overwrite    = $args{'overwrite'} || 0;
    my $term         = $self->term;
    my $single_file  = $self->file;
    my $files;

    if ($command_line) {
        my @missing = ();
        if ($file_str) {
            unless ( $files = $self->get_files( file_str => $file_str ) ) {
                print STDERR "None of the files, '$file_str' succeded.\n";
                push @missing, 'input file(s)';
            }
        }
        else {
            push @missing, 'input file(s)';
        }
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            exit(0);
        }
    }
    else {

        #
        # Make sure we have a file to parse.
        #
        if ($single_file) {
            print "OK to use '$single_file'? [Y/n] ";
            chomp( my $answer = <STDIN> );
            $single_file = '' if $answer =~ m/^[Nn]/;
        }

        if ( -r $single_file and -f _ ) {
            push @$files, $single_file;
        }
        else {
            print "Unable to read '$single_file' or not a regular file.\n"
              if $single_file;
            $files = $self->get_files() or return;
        }

        print "Overwrite any existing data? [y/N] ";
        chomp( $overwrite = <STDIN> );
        $overwrite = ( $overwrite =~ /^[Yy]/ ) ? 1 : 0;

        #
        # Confirm decisions.
        #
        print join( "\n",
            'OK to import?',
            '  Data source : ' . $self->data_source,
            "  File        : " . join( ', ', @$files ),
            "  Overwrite   : " . ( $overwrite ? "Yes" : "No" ),
            "[Y/n] " );
        chomp( my $answer = <STDIN> );
        return if $answer =~ /^[Nn]/;
    }

    my $importer =
      Bio::GMOD::CMap::Admin::Import->new( data_source => $self->data_source, );
    foreach my $file (@$files) {
        my $fh = IO::File->new($file) or die "Can't read $file: $!";
        $self->file($file);
        $importer->import_objects(
            fh        => $fh,
            log_fh    => $self->log_fh,
            overwrite => $overwrite,
          )
          or do {
            print "Error: ", $importer->error, "\n";
            return;
          };
    }
    $self->purge_query_cache( cache_level => 1 );
}

# ----------------------------------------------------
sub make_name_correspondences {

    my ( $self, %args ) = @_;
    my $command_line        = $args{'command_line'};
    my $evidence_type_acc   = $args{'evidence_type_acc'};
    my $from_map_set_accs   = $args{'from_map_set_accs'};
    my $to_map_set_accs   = $args{'to_map_set_accs'};
    my $skip_feature_type_accs_str = $args{'skip_feature_type_accs'};
    my $allow_update = $args{'allow_update'} || 0;
    my $name_regex_option   = $args{'name_regex'};
    my $sql_object = $self->sql;

    my @from_map_set_ids;
    my @to_map_set_ids;
    my @skip_feature_type_accs,
    my $allow_update,
    my $name_regex;
    my $regex_options = [
        {
            regex_title => 'exact match only',
            regex       => '',
            option_name => 'exact_match',
        },
        {
            regex_title => q[read pairs '(\S+)\.\w\d$'],
            regex       => '(\S+)\.\w\d$',
            option_name => 'read_pair',
        },
    ];

    if ($command_line) {
        my @missing = ();
        if ( defined($evidence_type_acc) ) {
            unless ( $self->evidence_type_data($evidence_type_acc) ) {
                print STDERR
                  "The evidence_type_acc, '$evidence_type_acc' is not valid.\n";
                push @missing, 'evidence_type_acc';
            }
        }
        else {
            push @missing, 'evidence_type_acc';
        }
        if ( defined($skip_feature_type_accs_str) ) {
            @skip_feature_type_accs = split /[,\s]+/, $skip_feature_type_accs_str;
            my $valid = 1;
            foreach my $fta (@skip_feature_type_accs) {
                unless ( $self->feature_type_data($fta) ) {
                    print STDERR "The skip_feature_type_acc, '$fta' is not valid.\n";
                    $valid = 0;
                }
            }
            unless ($valid) {
                push @missing, 'valid feature_type_acc';
            }
        }
        if ( defined($from_map_set_accs) ) {
            # split on space or comma
            my @from_map_set_accs = split /[,\s]+/, $from_map_set_accs;
            if (@from_map_set_accs) {
                my $valid = 1;
                foreach my $acc (@from_map_set_accs){
                    my $map_set_id = $sql_object->acc_id_to_internal_id(
                        cmap_object => $self,
                        acc_id      => $acc,
                        object_type => 'map_set'
                    );
                    if($map_set_id) {
                        push @from_map_set_ids, $map_set_id;
                    }
                    else{
                        print STDERR
                          "from map set accession, '$acc' is not valid.\n";
                        $valid = 0;
                    }
                }
                unless($valid){
                    push @missing, 'valid from_map_set_accs';
                }
            }
            else{
                push @missing, 'valid from_map_set_accs';
            }
        }
        else{
            push @missing, 'from_map_set_accs';
        }
        if ( defined($to_map_set_accs) ) {
            # split on space or comma
            my @to_map_set_accs = split /[,\s]+/, $to_map_set_accs;
            if (@to_map_set_accs) {
                my $valid = 1;
                foreach my $acc (@to_map_set_accs){
                    my $map_set_id = $sql_object->acc_id_to_internal_id(
                        cmap_object => $self,
                        acc_id      => $acc,
                        object_type => 'map_set'
                    );
                    if($map_set_id) {
                        push @to_map_set_ids, $map_set_id;
                    }
                    else{
                        print STDERR
                          "to map set accession, '$acc' is not valid.\n";
                        $valid = 0;
                    }
                }
                unless($valid){
                    push @missing, 'valid to_map_set_accs';
                }
            }
            else{
                push @missing, 'valid to_map_set_accs';
            }
        }
        else{
            @to_map_set_ids = @from_map_set_ids;
        }
        if ($name_regex_option){
            my $found = 0;
            foreach my $item (@$regex_options) {
                if ( $name_regex_option eq $item->{'option_name'} ) {
                    $found = 1;
                    $name_regex = $item->{'regex'} ;
                    last;
                }
            }
            unless ($found) {
                print STDERR
                  "The name_regex '$name_regex_option' is not valid.\n";
                push @missing, 'valid name_regex';
            }
        }
        else{
            $name_regex = '';
        }
        
        if (@missing) {
            print STDERR "Missing the following arguments:\n";
            print STDERR join( "\n", sort @missing ) . "\n";
            exit(0);
        }
    }
    else {
    #
    # Get the evidence type id.
    #
        my $evidence_type;
        ( $evidence_type_acc, $evidence_type ) = $self->show_menu(
            title   => 'Available evidence types',
            prompt  => 'Please select an evidence type',
            display => 'evidence_type',
            return  => 'evidence_type_acc,evidence_type',
            data    => sort_selectall_arrayref(
                $self->fake_selectall_arrayref(
                    $self->evidence_type_data(), 'evidence_type_acc',
                    'evidence_type'
                ),
                'evidence_type'
            ),
        );
        die "No evidence types!  Please use the config file to create.\n"
          unless $evidence_type;

        my $from_map_sets =
          $self->get_map_sets(
            explanation => 'First you will select the starting map sets' )
          or return;

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
                explanation => 'Now you will select the target map sets' )
              or return;
        }

        my @skip_features = $self->show_menu(
            title      => 'Skip Feature Types (optional)',
            prompt     => 'Select any feature types to skip in check',
            display    => 'feature_type',
            return     => 'feature_type_acc,feature_type',
            allow_null => 1,
            allow_mult => 1,
            data       => sort_selectall_arrayref(
                $self->fake_selectall_arrayref(
                    $self->feature_type_data(), 'feature_type_acc',
                    'feature_type'
                ),
                'feature_type'
            ),
        );
        @skip_feature_type_accs = map { $_->[0] } @skip_features;
        my $skip =
          @skip_features
          ? join( "\n     ", map { $_->[1] } @skip_features ) . "\n"
          : '    None';

        print "Check for duplicate data (slow)? [y/N] ";
        chomp( $allow_update = <STDIN> );
        $allow_update = ( $allow_update =~ /^[Yy]/ ) ? 1 : 0;

        $name_regex = $self->show_menu(
            title => "Match Type\n(You can add your own "
              . "match types by editing cmap_admin.pl)",
            prompt     => "Select the match type that you desire",
            display    => 'regex_title',
            return     => 'regex',
            allow_null => 0,
            allow_mult => 0,
            data   => $regex_options,
        );

        my $from = join(
            "\n",
            map {
                    "    "
                  . $_->{species_common_name} . "-"
                  . $_->{map_set_short_name} . " ("
                  . $_->{map_set_acc} . ")"
              } @{$from_map_sets}
        );

        my $to = join(
            "\n",
            map {
                    "    "
                  . $_->{species_common_name} . "-"
                  . $_->{map_set_short_name} . " ("
                  . $_->{map_set_acc} . ")"
              } @{$to_map_sets}
        );
        print "Make name-based correspondences\n",
          '  Data source   : ' . $self->data_source, "\n",
          "  Evidence type : $evidence_type\n", "  From map sets :\n$from\n",
          "  To map sets   :\n$to\n",           "  Skip features :\n$skip\n",
          "  Check for dups  : " . ( $allow_update ? "yes" : "no" );
        print "\nOK to make correspondences? [Y/n] ";
        chomp( my $answer = <STDIN> );
        return if $answer =~ m/^[Nn]/;
        @from_map_set_ids = map { $_->{map_set_id} } @$from_map_sets;
        @to_map_set_ids   = map { $_->{map_set_id} } @$to_map_sets;
    }

    my $corr_maker = Bio::GMOD::CMap::Admin::MakeCorrespondences->new(
        db          => $self->db,
        data_source => $self->data_source,
    );

    my $time_start = new Benchmark;
    $corr_maker->make_name_correspondences(
        evidence_type_acc      => $evidence_type_acc,
        from_map_set_ids       => \@from_map_set_ids,
        to_map_set_ids         => \@to_map_set_ids,
        skip_feature_type_accs => \@skip_feature_type_accs,
        log_fh                 => $self->log_fh,
        quiet                  => $Quiet,
        name_regex             => $name_regex,
        allow_update           => $allow_update,
      )
      or do { print "Error: ", $corr_maker->error, "\n"; return; };

    my $time_end = new Benchmark;
    print STDERR "make correspondence time: "
      . timestr( timediff( $time_end, $time_start ) ) . "\n";

    $self->purge_query_cache( cache_level => 4 );
    return 1;
}

# ----------------------------------------------------
sub reload_correspondence_matrix {

    my ( $self, %args ) = @_;
    my $command_line = $args{'command_line'};

    unless ($command_line) {
        print "OK to truncate table in data source '", $self->data_source,
          "' and reload? [Y/n] ";
        chomp( my $answer = <STDIN> );
        return if $answer =~ m/^[Nn]/;
    }

    my $admin = $self->admin;
    $admin->reload_correspondence_matrix or do {
        print "Error: ", $admin->error, "\n";
        return;
    };

    return 1;
}

# ----------------------------------------------------
sub prepare_for_gbrowse {

    require Bio::GMOD::CMap::Admin::GBrowseLiason;

    #
    # Gathers the info to import feature correspondences.
    #
    my $self = shift;
    my $term = $self->term;

    #
    # Get the map sets.
    #
    my $map_sets = $self->get_map_sets(
        explanation => 'Which map sets do you want to use',
        allow_mult  => 1,
        allow_null  => 0,
      )
      or return;

    #
    # Get the feature types
    #
    my $feature_type_data = $self->feature_type_data();
    my $menu_options;
    foreach my $ft_acc ( keys(%$feature_type_data) ) {
        if ( $feature_type_data->{$ft_acc}->{'gbrowse_class'} ) {
            push @$menu_options,
              {
                feature_type => $feature_type_data->{$ft_acc}->{'feature_type'},
                feature_type_acc => $ft_acc,
              };
        }
    }
    $menu_options = sort_selectall_arrayref( $menu_options, 'feature_type' );

    unless ( $menu_options and @$menu_options ) {
        print "No GBrowse eligible feature types\n";
        return 0;
    }

    my @feature_types = $self->show_menu(
        title  => 'Feature Types to be Prepared',
        prompt =>
          "Select the feature types that should be prepared for GBrowse data.\n"
          . "Only eligible feature type (that have a 'gbrowse_class' defined in their config) are displayed.",
        display    => 'feature_type',
        return     => 'feature_type_acc,feature_type',
        allow_null => 0,
        allow_mult => 1,
        data       => $menu_options,
    );

    print join( "\n",
        'OK to prepare for GBrowse?',
        '  Data source     : ' . $self->data_source,
        '  Map Sets        : '
          . join( "\n",
            map { "    " . $_->{'map_set_short_name'} } @$map_sets ),
        '  Feature Types   : '
          . join( "\n", map { "    " . $_->[1] } @feature_types ),
    );

    print "\n[Y/n] ";

    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my @map_set_ids       = map { $_->{'map_set_id'} } @$map_sets;
    my @feature_type_accs = map { $_->[0] } @feature_types;
    my $gbrowse_liason    =
      Bio::GMOD::CMap::Admin::GBrowseLiason->new(
        data_source => $self->data_source, );
    $gbrowse_liason->prepare_data_for_gbrowse(
        map_set_ids       => \@map_set_ids,
        feature_type_accs => \@feature_type_accs,
      )
      or do {
        print "Error: ", $gbrowse_liason->error, "\n";
        return;
      };
}

# ----------------------------------------------------
sub copy_cmap_into_gbrowse {

    require Bio::GMOD::CMap::Admin::GBrowseLiason;

    #
    # Gathers the info to import feature correspondences.
    #
    my $self = shift;
    my $term = $self->term;

    #
    # Get the map sets.
    #
    my $map_sets = $self->get_map_sets(
        explanation => 'Which map sets do you want to copy data from?',
        allow_mult  => 1,
        allow_null  => 0,
      )
      or return;

    #
    # Get the feature types
    #
    my $feature_type_data = $self->feature_type_data();
    my $menu_options;
    foreach my $ft_acc ( keys(%$feature_type_data) ) {
        if (    $feature_type_data->{$ft_acc}->{'gbrowse_class'}
            and $feature_type_data->{$ft_acc}->{'gbrowse_ftype'} )
        {
            push @$menu_options,
              {
                feature_type => $feature_type_data->{$ft_acc}->{'feature_type'},
                feature_type_acc => $ft_acc,
              };
        }
    }
    $menu_options = sort_selectall_arrayref( $menu_options, 'feature_type' );

    unless ( $menu_options and @$menu_options ) {
        print "No GBrowse eligible feature types\n";
        return 0;
    }

    my @feature_types = $self->show_menu(
        title  => 'Feature Types to be Prepared',
        prompt =>
          "Select the feature types that should be prepared for GBrowse data.\n"
          . "Only eligible feature types ('gbrowse_class' and 'gbrowse_ftype' defined in the config) are displayed.\n"
          . "Selecting none will select all.",
        display    => 'feature_type',
        return     => 'feature_type_acc,feature_type',
        allow_null => 1,
        allow_mult => 1,
        data       => $menu_options,
    );

    print join(
        "\n",
        'OK to copy data into GBrowse?',
        '  Data source     : ' . $self->data_source,
        '  Map Sets        : '
          . join( "\n",
            map { "    " . $_->{'map_set_short_name'} } @$map_sets ),
        '  Feature Types   : '
          . (
            @feature_types
            ? join( "\n", map { "    " . $_->[1] } @feature_types )
            : 'All'
          ),
    );

    print "\n[Y/n] ";

    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my @map_set_ids       = map { $_->{'map_set_id'} } @$map_sets;
    my @feature_type_accs = map { $_->[0] } @feature_types;
    my $gbrowse_liason    =
      Bio::GMOD::CMap::Admin::GBrowseLiason->new(
        data_source => $self->data_source, );
    $gbrowse_liason->copy_data_into_gbrowse(
        map_set_ids       => \@map_set_ids,
        feature_type_accs => \@feature_type_accs,
      )
      or do {
        print "Error: ", $gbrowse_liason->error, "\n";
        return;
      };
}

# ----------------------------------------------------
sub copy_gbrowse_into_cmap {

    require Bio::GMOD::CMap::Admin::GBrowseLiason;

    #
    # Gathers the info to import feature correspondences.
    #
    my $self = shift;
    my $term = $self->term;

    #
    # Get the map sets.
    #
    my $map_sets = $self->get_map_sets(
        explanation =>
          'Which map set do you want the copied data to be part of?',
        allow_mult => 0,
        allow_null => 0,
      )
      or return;
    my $map_set_id = $map_sets->[0]{'map_set_id'};

    print join( "\n",
        'OK to copy data into CMap?',
        '  Data source     : ' . $self->data_source,
        '  Map Set         : '
          . join( "\n",
            map { "    " . $_->{'map_set_short_name'} } @$map_sets ),
    );

    print "\n[Y/n] ";

    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my $gbrowse_liason =
      Bio::GMOD::CMap::Admin::GBrowseLiason->new(
        data_source => $self->data_source, );
    $gbrowse_liason->copy_data_into_cmap( map_set_id => $map_set_id, )
      or do {
        print "Error: ", $gbrowse_liason->error, "\n";
        return;
      };
    $self->purge_query_cache( cache_level => 1 );
}

# ----------------------------------------------------
sub show_question {
    my %args         = @_;
    my $question     = $args{'question'} or return;
    my $default      = $args{'default'};
    my $allow_null   = $args{'allow_null'};
    my $validHashRef = $args{'valid_hash'} || ();
    $allow_null = 1 unless ( defined($allow_null) );

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
        elsif (( !$allow_null and not defined($answer) )
            or ( defined($answer) and $answer =~ /\s+/ ) )
        {
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

        # only one choice, use it.
        $result = [ map { $data->[0]->{$_} } @return ];
        $result = [$result] if ( $args{'allow_mult'} );
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
    my ( $self, %args ) = @_;
    my $dir_str = $args{'dir_str'};
    my $dir;
    my $fh = \*STDOUT;
    $fh = \*STDERR if ($dir_str);
    my $continue_loop = 1;
    while ( not defined($dir) and $continue_loop ) {
        my $answer;
        if ($dir_str) {
            $continue_loop = 0;
            $answer        = $dir_str;
        }
        else {
            print $fh "\nTo which directory should I write the output files?\n",
              "['q' to quit, current dir (.) is default] ";
            chomp( $answer = <STDIN> );
            $answer ||= '.';
            return if $answer =~ m/^[qQ]/;
        }

        if ( -d $answer ) {
            if ( -w _ ) {
                $dir = $answer;
                last;
            }
            else {
                print $fh "\n'$answer' is not writable by you.\n\n";
                next;
            }
        }
        elsif ( -f $answer ) {
            print $fh "\n'$answer' is not a directory.  Please try again.\n\n";
            next;
        }
        else {
            my $response;
            if ( not $dir_str ) {
                print $fh "\n'$answer' does not exist.  Create? [Y/n] ";
                chomp( $response = <STDIN> );
            }
            $response ||= 'y';
            if ( $response =~ m/^[Yy]/ ) {
                eval { mkpath( $answer, 0, 0711 ) };
                if ( my $err = $@ ) {
                    print $fh "I couldn't make that directory: $err\n\n";
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
    -i|info          Display more options
    -v|version       Display version
    -d|--datasource  The default data source to use
    --no-log         Don't keep a log of actions
    --action         Command line action. See --info for more information

=head1 OPTIONS

This script has command line actions that can be used for scripting.  This allows the user to skip the menu system.  The following are the allowed actions.

=head2 create_species

cmap_admin.pl [-d data_source] --action create_species --species_full_name "full name" [--species_common_name "common name"] [--species_acc "accession"]

  Required:
    --species_full_name : Full name of the species
  Optional:
    --species_common_name : Common name of the species
    --species_acc : Accession ID for the species

=head2 create_map_set

cmap_admin.pl [-d data_source] --action  required_optionste_map_set --map_set_name "Map Set Name" (--species_id id OR --species_acc accession) --map_type_acc "Map_type_accession" [--map_set_short_name "Short Name"] [--map_set_acc accesssion] [--map_shape shape] [--map_color color] [--map_width integer]

  Required:
    --map_set_name
    (
        --species_id : ID for the species
        or
        --species_acc : Accession ID for the species
    )
    --map_type_acc
  Optional:
    --map_set_short_name : Short name 
    --map_set_acc : Accession ID for the map set
    --map_shape : Shape of the maps in this set
    --map_color : Color of the maps in this set
    --map_width : Width of the maps in this set

=head2 delete_correspondences

cmap_admin.pl [-d data_source] --action delete_correspondences (--map_set_accs "accession [, acc2...]" OR --map_type_acc accession OR --species_acc accession) [--evidence_type_accs "accession [, acc2...]"]

  Required:
    --map_set_accs : A comma (or space) separated list of map set accessions
    or
    --map_type_acc : Accession ID of for the map type
    or
    --species_acc : Accession ID for the species
                                                                                
  Optional:
    --evidence_type_accs : A comma (or space) separated list of evidence type accessions to be deleted

=head2 delete_maps

cmap_admin.pl [-d data_source] --action delete_maps (--map_set_acc accession OR --map_accs "accession [, acc2...]")

  Required:
    --map_set_acc : Accession Id of a map set to be deleted
    or
    --map_accs :  A comma (or space) separated list of map accessions to be deleted

=head2 export_as_text

cmap_admin.pl [-d data_source] --action export_as_text (--map_set_accs "accession [, acc2...]" OR --map_type_acc accession OR --species_acc accession) [--feature_type_accs "accession [, acc2...]"] [--exclude_fields "field [, field2...]"] [--directory directory]

  Required:
    --map_set_accs : A comma (or space) separated list of map set accessions
    or
    --map_type_acc : Accession ID of for the map type
    or
    --species_acc : Accession ID for the species
  Optional:
    --feature_type_accs : A comma (or space) separated list of feature type accessions
    --exclude_fields : List of table fields to exclude from output
    --directory : Directory to place the output

=head2 export_as_sql

cmap_admin.pl [-d data_source] --action export_as_sql [--add_truncate] [--export_file file_name] [--quote_escape value] [--tables "table [, table2...]"] 
        Optional:
    --export_file : Name of the export file (default:./cmap_dump.sql)
    --add_truncate : Include to add 'TRUNCATE TABLE' statements
    --quote_escape : How embedded quotes are escaped
                     'doubled' for Oracle
                     'backslash' for MySQL
    --tables : Tables to be exported.  (default: 'all')

=head2 export_objects

cmap_admin.pl [-d data_source] --action export_objects --export_objects "all"|"map_set" (--map_set_accs "accession [, acc2...]" OR --map_type_acc accession OR --species_acc accession) [--export_file file_name] [--directory directory]

cmap_admin.pl [-d data_source] --action export_objects --export_objects "species"&|"feature_correspondence"&|"xref" [--export_file file_name] [--directory directory]

  Required:
    --export_objects : Objects to be exported
                       Accepted options:
                        all, map_set, species,
                        feature_correspondence, xref
  Required if exporting map_set (or all):
    --map_set_accs : A comma (or space) separated list of map set accessions
    or
    --map_type_acc : Accession ID of for the map type
    or
    --species_acc : Accession ID for the species
  Optional:
    --export_file : Name of the output file (default: cmap_export.xml)
    --directory : Directory where the output file goes (default: ./)

=head2 import_correspondences

cmap_admin.pl [-d data_source] --action  import_correspondences --map_set_accs "accession [, acc2...]" file1 [file2 ...]

  Required:
    --map_set_accs : A comma (or space) separated list of map set accessions

=head2 import_alignments 

cmap_admin.pl [-d data_source] --action import_alignments --from_map_set_acc accession --to_map_set_acc accession --format format --feature_type_acc accession --evidence_type_acc accession file1 [file2 ...]

  Required:     --from_map_set_acc : Accession ID of the query
    --to_map_set_acc : Accession ID of the subject
    --format : Type of alingment file
                Current formats: blast
    --feature_type_acc : Accession ID of for the feature type 
               of the feature that represents the alignment
    --evidence_type_acc : Accession ID of for the evidence type of the alignment

=head2 import_tab_data

cmap_admin.pl [-d data_source] --action import_tab_data --map_set_acc accession [--overwrite] [--allow_update] file1 [file2 ...]

  Required:
    --map_set_acc : Accession Id of a map set for information to be inserted into
  Optional:
    --overwrite : Include to remove data in map set not in import file
    --allow_update : Include to check for duplicate data (slow)

=head2 import_object_data
cmap_admin.pl [-d data_source] --action import_object_data [--overwrite] file1 [file2 ...]

  Optional:
    --overwrite : Include to remove data in map set not in import file

=head2 make_name_correspondences

cmap_admin.pl [-d data_source] --action make_name_correspondences --evidence_type_acc acc --from_map_set_accs "accession [, acc2...]" [--to_map_set_accs "accession [, acc2...]"] [--skip_feature_type_accs "accession [, acc2...]"] [--allow_update] [--name_regex name]

  Required:
    --evidence_type_acc : Accession ID of the evidence type to be created
    --from_map_set_accs : A comma (or space) separated list of map set 
        accessions that will be the starting point of the correspondences.
  Optional:
    --to_map_set_accs : A comma (or space) separated list of map set 
        accessions that will be the destination of the correspondences.  
        Only specify if different that from_map_set_accs.
    --skip_feature_type_accs : A comma (or space) separated list of 
        feature type accessions that should not be used
    --allow_update : Include to check for duplicate data (slow)
    --name_regex : The name of the regular expression to be used
                    (default: exact_match)
                    Options: exact_match, read_pair

=head2 reload_correspondence_matrix

cmap_admin.pl [-d data_source] --action reload_correspondence_matrix

=head2 purge_query_cache

cmap_admin.pl [-d data_source] --action purge_query_cache [--cache_level level]

  Optional:
    --cache_level : The level of the cache to be purged (default: 1)

=head2 delete_duplicate_correspondences

cmap_admin.pl [-d data_source] --action delete_duplicate_correspondences

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
Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-5 Cold Spring Harbor Laboratory

This program is free software;  you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

Bio::GMOD::CMap::Admin::Import, Bio::GMOD::CMap::Admin::ImportCorrespondences.

=cut

