#!/usr/bin/perl
# vim: set ft=perl:

# $Id: cmap_admin.pl,v 1.147 2008-06-27 14:54:03 mwz444 Exp $

use strict;
use if $ENV{'CMAP_ROOT'}, lib => $ENV{'CMAP_ROOT'} . '/lib';
use Pod::Usage;
use Getopt::Long;
use Bio::GMOD::CMap::Admin::Interactive;
use Data::Dumper;

use vars qw[ $VERSION ];
$VERSION = (qw$Revision: 1.147 $)[-1];

#
# Get command-line options
#
my ( $show_help, $show_info, $show_version, $no_log, $datasource, $quiet );
my ($ACTION);

# get the config dir for when there are multiple installs
my ($config_dir);

#create species values
my ( $species_full_name, $species_common_name, $species_acc );

#create map set values
my ( $map_set_name, $map_set_short_name, $species_id, $map_type_acc, );
my ( $map_set_acc,  $map_shape,          $map_color,  $map_width );

#import file
my ( $overwrite, $allow_update );

#cache purging
my ( $cache_level, $purge_all, );

#import corrs
my ($map_set_accs);

#import alignment
my ( $feature_type_acc, $evidence_type_acc, $from_map_set_acc, );
my ( $to_map_set_acc, $format, );

#import links
my ($link_group);

#export sql
my ( $add_truncate, $export_file, $quote_escape, $tables, );

#export text
my ( $feature_type_accs, $exclude_fields, $directory, );

#export text
my ($export_objects);

#export gff
my ( $species_accs, $only_corrs, $ignore_unit_granularity, );

#delete map_set
my ($map_accs);

#delete corr
my ( $evidence_type_accs, );

#make name corr
my ($from_map_set_accs, $to_map_set_accs, $skip_feature_type_accs,
    $name_regex,        $from_group_size
);

GetOptions(
    'h|help'         => \$show_help,       # Show help and exit
    'i|info'         => \$show_info,       # Show help and exit
    'v|version'      => \$show_version,    # Show version and exit
    'no-log'         => \$no_log,          # Don't keep a log
    'd|datasource=s' => \$datasource,      # Default data source
    'q|quiet'        => \$quiet,           # Only print necessities
    'c|config_dir=s' => \$config_dir,      # location of the config files
    'a|action=s'     => \$ACTION,          # Command line action
    'species_full_name=s'             => \$species_full_name,
    'species_common_name=s'           => \$species_common_name,
    'species_acc=s'                   => \$species_acc,
    'species_accs=s'                  => \$species_accs,
    'species_id=s'                    => \$species_id,
    'map_set_name=s'                  => \$map_set_name,
    'map_set_short_name=s'            => \$map_set_short_name,
    'map_accs=s'                      => \$map_accs,
    'map_type_acc=s'                  => \$map_type_acc,
    'feature_type_acc=s'              => \$feature_type_acc,
    'feature_type_accs=s'             => \$feature_type_accs,
    'evidence_type_acc=s'             => \$evidence_type_acc,
    'evidence_type_accs=s'            => \$evidence_type_accs,
    'skip_feature_type_accs=s'        => \$skip_feature_type_accs,
    'map_set_acc=s'                   => \$map_set_acc,
    'map_set_accs=s'                  => \$map_set_accs,
    'from_map_set_acc=s'              => \$from_map_set_acc,
    'from_map_set_accs=s'             => \$from_map_set_accs,
    'to_map_set_acc=s'                => \$to_map_set_acc,
    'to_map_set_accs=s'               => \$to_map_set_accs,
    'map_shape=s'                     => \$map_shape,
    'map_color=s'                     => \$map_color,
    'map_width=i'                     => \$map_width,
    'overwrite'                       => \$overwrite,
    'allow_update'                    => \$allow_update,
    'cache_level=i'                   => \$cache_level,
    'purge_all|purge_all_datasources' => \$purge_all,
    'format=s'                        => \$format,
    'add_truncate'                    => \$add_truncate,
    'export_file=s'                   => \$export_file,
    'export_objects=s'                => \$export_objects,
    'tables=s'                        => \$tables,
    'quote_escape=s'                  => \$quote_escape,
    'exclude_fields=s'                => \$exclude_fields,
    'directory=s'                     => \$directory,
    'name_regex=s'                    => \$name_regex,
    'from_group_size=s'               => \$from_group_size,
    'link_group=s'                    => \$link_group,
    'only_corrs'                      => \$only_corrs,
    'ignore_unit_granularity'         => \$ignore_unit_granularity,
) or pod2usage(2);
my $file_str = join( ' ', @ARGV );

pod2usage( -verbose => 1 ) if $show_info;
pod2usage(0) if $show_help;
if ($show_version) {
    print "$0 Version: $VERSION (CMap Version $Bio::GMOD::CMap::VERSION)\n";
    exit(0);
}

#
# Create a CLI object.
#
my $interactive = Bio::GMOD::CMap::Admin::Interactive->new(
    user       => $>,            # effective UID
    no_log     => $no_log,
    datasource => $datasource,
    config_dir => $config_dir,
    file       => shift,
);

die "$datasource is not a valid data source.\n"
    if ($datasource
    and $ACTION
    and $datasource ne $interactive->data_source() );

my %command_line_actions = (
    create_species                   => 1,
    create_map_set                   => 1,
    import_gff                       => 1,
    import_tab_data                  => 1,
    import_correspondences           => 1,
    import_object_data               => 1,
    import_links                     => 1,
    purge_query_cache                => 1,
    delete_duplicate_correspondences => 1,
    export_as_gff                    => 1,
    export_as_sql                    => 1,
    export_as_text                   => 1,
    export_objects                   => 1,
    delete_maps                      => 1,
    delete_features                  => 1,
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
        $action = $interactive->show_greeting;
    }
    die "Cannot do '$action'!" unless ( $interactive->can($action) );

    # Arguments are only used with command_line
    $interactive->$action(
        command_line            => $command_line,
        species_full_name       => $species_full_name,
        species_common_name     => $species_common_name,
        species_acc             => $species_acc,
        map_set_name            => $map_set_name,
        map_set_short_name      => $map_set_short_name,
        species_id              => $species_id,
        species_accs            => $species_accs,
        map_type_acc            => $map_type_acc,
        feature_type_acc        => $feature_type_acc,
        feature_type_accs       => $feature_type_accs,
        evidence_type_acc       => $evidence_type_acc,
        evidence_type_accs      => $evidence_type_accs,
        skip_feature_type_accs  => $skip_feature_type_accs,
        map_set_acc             => $map_set_acc,
        from_map_set_acc        => $from_map_set_acc,
        from_map_set_accs       => $from_map_set_accs,
        to_map_set_acc          => $to_map_set_acc,
        to_map_set_accs         => $to_map_set_accs,
        map_set_accs            => $map_set_accs,
        map_shape               => $map_shape,
        map_color               => $map_color,
        map_width               => $map_width,
        file_str                => $file_str,
        overwrite               => $overwrite,
        allow_update            => $allow_update,
        cache_level             => $cache_level,
        purge_all               => $purge_all,
        format                  => $format,
        add_truncate            => $add_truncate,
        export_file             => $export_file,
        export_objects          => $export_objects,
        tables                  => $tables,
        quote_escape            => $quote_escape,
        exclude_fields          => $exclude_fields,
        directory               => $directory,
        name_regex              => $name_regex,
        from_group_size         => $from_group_size,
        map_accs                => $map_accs,
        link_group              => $link_group,
        only_corrs              => $only_corrs,
        ignore_unit_granularity => $ignore_unit_granularity,

    );
}

# ./bin/cmap_admin.pl -d WashU -a create_species --species_full_name "Blah Blah" --species_common_name "Blah" --species_acc Blah

# ./bin/cmap_admin.pl -d WashU -a create_map_set --species_acc Blah --map_set_name "MS20" --map_type_acc 2

# ./bin/cmap_admin.pl -d WashU -a import_gff file1 file2

# ./bin/cmap_admin.pl -d WashU -a import_gff --map_set_acc 13  file1 file2

# ./bin/cmap_admin.pl -d WashU -a import_tab_data --map_set_acc 13  file1 file2

# ./bin/cmap_admin.pl -d WashU -a import_links --link_group 'Team 1'  file1 file2

# ./bin/cmap_admin.pl -d WashU -a purge_query_cache --cache_level 2;

# ./bin/cmap_admin.pl -d WashU -a purge_query_cache --cache_level 2 --purge_all_datasources;

# ./bin/cmap_admin.pl -d WashU -a delete_duplicate_correspondences --map_set_acc 'blah'

# ./bin/cmap_admin.pl -d WashU -a import_correspondences --map_set_accs 'Blah 13' data/tabtest.corr

# ./bin/cmap_admin.pl -d WashU -a import_object_data cmap_export.xml

# ./bin/cmap_admin.pl -d WashU -a export_as_sql --export_file cmap_export.sql --quote_escape backslash --tables all

# ./bin/cmap_admin.pl -d WashU -a export_as_text --species_acc Blah

# ./bin/cmap_admin.pl -d WashU -a export_objects --species_acc Blah --export_objects "map_set species"

# ./bin/cmap_admin.pl -d WashU -a delete_maps --map_accs "28 26"

# ./bin/cmap_admin.pl -d WashU -a delete_maps --map_set_acc 13

# ./bin/cmap_admin.pl -d WashU -a delete_maps --map_set_acc 13 --map_accs "all"

# ./bin/cmap_admin.pl -d WashU -a delete_features --map_accs "28 26" --feature_type_accs "blast marker"

# ./bin/cmap_admin.pl -d WashU -a delete_features --map_set_acc 13 --feature_type_accs "blast marker"

# ./bin/cmap_admin.pl -d WashU -a delete_correspondences --species_acc SP1 --evidence_type_accs all

# ./bin/cmap_admin.pl -d WashU -a make_name_correspondences --evidence_type_acc ANB --from_map_set_accs "10 7 MS10 MS4 MS5 MS6 MS8" --to_map_set_accs "10 7 MS10 MS4 MS5 MS6 MS8" --skip_feature_type_accs "" --name_regex exact_match --from_group_size 500

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
    -c|--config_dir  The location of the config files to use (useful when multiple installs)
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

cmap_admin.pl [-d data_source] --action  create_map_set --map_set_name "Map Set Name" (--species_id id OR --species_acc accession) --map_type_acc "Map_type_accession" [--map_set_short_name "Short Name"] [--map_set_acc accesssion] [--map_shape shape] [--map_color color] [--map_width integer]

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

cmap_admin.pl [-d data_source] --action delete_maps (--map_set_acc accession [ --map_accs all ] OR --map_accs "accession [, acc2...]")

  Required:
    --map_set_acc : Accession Id of a map set to be deleted
    or
    --map_accs :  A comma (or space) separated list of map accessions to be deleted

To delete all the maps from a map set, supply the --map_set_acc and use "--map_accs all".

=head2 export_as_gff

cmap_admin.pl [-d data_source] --action export_as_gff [ --species_accs "accession [, acc2...]" OR --map_set_accs "accession [, acc2...]" OR --map_accs "accession [, acc2...]" ] [--only_corrs] [--ignore_unit_granularity] [--directory directory] [--export_file file_name]

  Only use one or none of the following options: --species_accs, --map_set_accs 
    or --map_accs.  Using none, will result in the whole database being exported.

  Optional:
    --species_accs : A comma (or space) separated list of species accessions
    --map_set_accs : A comma (or space) separated list of map set accessions
    --map_accs     : A comma (or space) separated list of map accessions
    --ignore_unit_granularity : A boolean. Set to true to tell the exporter 
                                not to use the unit_granularity to make all of
                                the positions into integers.
    --only_corrs : A boolean. Set to true to only output correspondences.
    --directory : Directory to place the output
    --export_file : Name of the export file (default: DATASOURCE.gff)

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

=head2 import_gff

cmap_admin.pl [-d data_source] --action import_gff [--map_set_acc accession] file1 [file2 ...]

  Optional:
    --map_set_acc : Accession Id of a map set for information to be inserted
                    into.  This is not required if the map set is defined in 
                    the file.

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

cmap_admin.pl [-d data_source] --action make_name_correspondences --evidence_type_acc acc --from_map_set_accs "accession [, acc2...]" [--to_map_set_accs "accession [, acc2...]"] [--skip_feature_type_accs "accession [, acc2...]"] [--allow_update] [--name_regex name] [--from_group_size number]

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
    --from_group_size : The number of maps from the "from" map set to group 
        together during name based correspondence creation.
                    (default: 1)

=head2 delete_duplicate_correspondences

cmap_admin.pl [-d data_source] --action delete_duplicate_correspondences [--map_set_acc map_set_acc]

  Optional:
    --map_set_acc : Limit the search for duplicates to correspondences 
        related to one map set.  Any correspondences that the map set 
        has will be examined.

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

There are five layers of the cache.  When one layer is purged all of
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

Level 4 is purged when correspondence information is changed.

=item * Cache Level 5 (purge whole image caching )

Level 5 is purged when any information changes

=back

=head2 Delete duplicate correspondences

If duplicate correspondences may have been added, this will remove them.

=head2 Manage links

This option is where to import and delete links that will show up in
the "Imported Links" section of CMap.  The import takes a tab delimited
file, see "perldoc /path/to/Bio/GMOD/CMap/Admin/ManageLinks.pm" for
more info on the format.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.eduE<gt>.
Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-8 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=head1 SEE ALSO

Bio::GMOD::CMap::Admin::Import, Bio::GMOD::CMap::Admin::ImportCorrespondences.

=cut

