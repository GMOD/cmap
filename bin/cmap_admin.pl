#!/usr/bin/perl

# $Id: cmap_admin.pl,v 1.21 2003-02-20 23:54:37 kycl4rk Exp $

use strict;
use Pod::Usage;
use Getopt::Long;

use vars qw[ $VERSION ];
$VERSION = (qw$Revision: 1.21 $)[-1];

#
# Turn off output buffering.
#
$| = 1;

#
# Get command-line options
#
my ( $show_help, $show_version, $no_log );

GetOptions(
    'h|help'    => \$show_help,    # Show help and exit
    'v|version' => \$show_version, # Show version and exit
    'no-log'    => \$no_log,       # Don't keep a log
) or pod2usage(2);

pod2usage(0) if $show_help;
if ( $show_version ) {
    print "$0 Version: $VERSION (CMap Version $Bio::GMOD::CMap::VERSION)\n";
    exit(0);
}

#
# Create a CLI object.
#
my $cli = Bio::GMOD::CMap::CLI::Admin->new( 
    user   => $>,  # effective UID
    no_log => $no_log,
    file   => shift,
);

while ( 1 ) { 
    my $action = $cli->show_greeting;
    $cli->$action();
}

# ----------------------------------------------------
package Bio::GMOD::CMap::CLI::Admin;

use strict;
use File::Path;
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
use Bio::GMOD::CMap::Admin::MakeCorrespondences();
use Bio::GMOD::CMap::Admin::ImportCorrespondences();

use base 'Bio::GMOD::CMap';

use constant STR    => 'string';
use constant NUM    => 'number';
use constant OUT_FS => "\t";     # ouput field separator
use constant OUT_RS => "\n";     # ouput record separator

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->params( $config, qw[ file user no_log ] );
    return $self;
}

# ----------------------------------------------------
sub file { 
    my $self = shift;
    $self->{'file'} = shift if @_;
    return $self->{'file'} || '' 
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
    return $self->{'user'} || '' 
}

# ----------------------------------------------------
sub log_filename {
    my $self = shift;
    unless ( $self->{'log_filename'} ) {
        my ( $name, $passwd, $uid, $gid, $quota, $comment, $gcos, 
            $home_dir, $shell ) = getpwuid( $self->user );

        my $filename = 'cmap_admin_log';
        my $i        = 0;
        my $path;
        while ( 1 ) {
            $path = join( '/', $home_dir, $filename . '.' . $i );
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
            my $fh = IO::Tee->new( \*STDOUT, ">$path" ) or return $self->error(
                "Unable to open '$path': $!"
            );
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
    my $self   = shift;

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

    my $action  =  $self->show_menu(
        title   => join("\n", $separator, '  --= Main Menu =--  ', $separator),
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
                display => 'Import data for existing map set' 
            },
            { 
                action  => 'make_name_correspondences', 
                display => 'Make name-based correspondences' 
            },
            { 
                action  => 'import_correspondences', 
                display => 'Import feature correspondences' 
            },
            { 
                action  => 'reload_correspondence_matrix', 
                display => 'Reload correspondence matrix' 
            },
            { 
                action  => 'export_data', 
                display => 'Export data' 
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
        title   => 'Available Date Sources',
        prompt  => 'Which data source?',
        display => 'display',
        return  => 'value',
        data     => [
            map { { value => $_->{'name'}, display => $_->{'name'} } }
            @{ $self->data_sources }
        ],
    );

    $self->data_source( $data_source );
}

# ----------------------------------------------------
sub create_map_set {
    my $self = shift;
    my $db   = $self->db;
    print "Creating new map set.\n";
    
    my ( $map_type_id, $map_type ) = $self->show_menu(
        title   => 'Available Map Types',
        prompt  => 'What type of map?',
        display => 'map_type',
        return  => 'map_type_id,map_type',
        data     => $db->selectall_arrayref(
            q[
                select   mt.map_type_id, mt.map_type
                from     cmap_map_type mt
                order by map_type
            ],
            { Columns => {} },
        ),
    );
    die "No map types! Please use the web admin tool to create.\n" 
        unless $map_type_id;

    my ( $species_id, $common_name ) = $self->show_menu(
        title   => 'Available Species',
        prompt  => 'What species?',
        display => 'common_name,full_name',
        return  => 'species_id,common_name',
        data     => $db->selectall_arrayref(
            q[
                select   s.species_id, s.common_name, s.full_name
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

    my $map_set_id = next_number(
        db           => $db,
        table_name   => 'cmap_map_set',
        id_field     => 'map_set_id',
    ) or die 'No map set id';


    print "OK to create set '$map_set_name'?\n[Y/n] ";
    chomp( my $answer = <STDIN> );
    return if $answer =~ m/^[Nn]/;

    $db->do(
        q[
            insert
            into   cmap_map_set
                   ( map_set_id, accession_id, map_set_name, short_name,
                     species_id, map_type_id
                   )
            values ( ?, ?, ?, ?, ?, ? )
        ],
        {},
        (
            $map_set_id, $map_set_id, $map_set_name, $short_name,
            $species_id, $map_type_id
        )
    );

    print "Map set $map_set_name created\n";
}

# ----------------------------------------------------
sub export_data {
#
# Exports data.
#
    my $self = shift;
    my $db   = $self->db;
    
    my $action  = $self->show_menu(
        title   => 'Data Export Formats',
        prompt  => 'What do you want to export?',
        display => 'display',
        return  => 'action',
        data    => [
            { 
                action  => 'export_as_sql',
                display => 'All Data as SQL INSERT statements',
            },
            { 
                action  => 'export_as_text',
                display => 'Map Data in CMap import format',
            },
            { 
                action  => 'export_correspondences',
                display => 'Feature correspondences in CMap import format',
            },
        ]
    );
    
    $self->$action( $db );
}

# ----------------------------------------------------
sub export_as_sql {
#
# Exports data as SQL INSERT statements.
#
    my $self   = shift;
    my $db     = $self->db;
    my $log_fh = $self->log_fh;
    my @tables = (
        {
            name   => 'cmap_correspondence_evidence',
            fields => {
                correspondence_evidence_id => NUM,
                accession_id               => STR,
                feature_correspondence_id  => NUM,
                evidence_type_id           => NUM,
                score                      => NUM,
                remark                     => STR,
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
            name   => 'cmap_dbxref',
            fields => {
                dbxref_id       => NUM,
                map_set_id      => NUM,
                feature_type_id => NUM,
                species_id      => NUM,
                dbxref_name     => STR,
                url             => STR,
            }
        },
        {
            name   => 'cmap_evidence_type',
            fields => {
                evidence_type_id => NUM,
                accession_id     => STR,
                evidence_type    => STR,
                rank             => NUM,
                line_color       => STR,
                line_style       => STR,
            }
        },
        {
            name   => 'cmap_feature',
            fields => {
                feature_id      => NUM,
                accession_id    => STR,
                map_id          => NUM,
                feature_type_id => NUM,
                feature_name    => STR,
                alternate_name  => STR,
                is_landmark     => NUM,
                start_position  => NUM,
                stop_position   => NUM,
                dbxref_name     => STR,
                dbxref_url      => STR,
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
            name   => 'cmap_feature_type',
            fields => {
                feature_type_id  => NUM,
                accession_id     => STR,
                feature_type     => STR,
                default_rank     => NUM,
                is_visible       => NUM,
                shape            => STR,
                color            => STR,
                drawing_lane     => NUM,
                drawing_priority => NUM,
            }
        },
        {
            name   => 'cmap_map',
            fields => {
                map_id         => NUM,
                accession_id   => STR,
                map_set_id     => NUM,
                map_name       => STR,
                linkage_group  => STR,
                start_position => NUM,
                stop_position  => NUM,
            }
        },
        {
            name   => 'cmap_map_type',
            fields => {
                map_type_id       => NUM,
                map_type          => STR,
                map_units         => STR,
                is_relational_map => NUM,
                shape             => STR,
                color             => STR,
                width             => NUM,
                display_order     => NUM,
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
                ncbi_taxon_id => NUM,
            }
        },
        { 
            name   => 'cmap_map_set',
            fields => {
                map_set_id           => NUM,
                accession_id         => STR,
                map_set_name         => STR,
                short_name           => STR,
                map_type_id          => NUM,
                species_id           => NUM,
                published_on         => STR,
                can_be_reference_map => NUM,
                display_order        => NUM,
                is_enabled           => NUM,
                remarks              => STR,
                shape                => STR,
                color                => STR,
                width                => NUM,
            },
        }
    );

    #
    # Ask user what/how/where to dump.
    #
    my @dump_tables = $self->show_menu(
        title       => 'Select Tables',
        prompt      => 'Which tables do you want to export?',
        display     => 'table_name',
        return      => 'table_name',
        allow_all   => 1,
        data        => [ map { { 'table_name', $_->{'name'} } } @tables ],
    );

    print "Add 'TRUNCATE TABLE' statements? [Y/n] ";
    chomp( my $answer = <STDIN> );
    $answer ||= 'y';
    my $add_truncate = $answer =~ m/^[yY]/;

    my $file;
    for ( ;; ) {
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
        title   => 'Quote Style',
        prompt  => "How should embeded quotes be escaped?\n".
                   'Hint: Oracle and Sybase like [1], MySQL likes [2]',
        display => 'display',
        return  => 'action',
        data     => [
            { display => 'Doubled',   action => 'doubled'   },
            { display => 'Backslash', action => 'backslash' },
        ],
    );

    #
    # Confirm decisions.
    #
    print join("\n",
        'OK to export?',
        '  Tables       : ' . join(', ', @dump_tables),
        '  Add Truncate : ' . ( $add_truncate ? 'Yes' : 'No' ), 
        "  File         : $file",
        "  Escape Quotes: $quote_escape",
        "[Y/n] "
    );

    chomp( $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    print $log_fh "Making SQL dump of tables to '$file'\n";
    open my $fh, ">$file" or die "Can't write to '$file': $!\n";
    print $fh 
        "--\n-- Dumping data for Cmap",
        "\n-- Produced by cmap_admin.pl",
        "\n-- Version: ", $main::VERSION,
        "\n-- ", scalar localtime, "\n--\n";

    my %dump_tables = map { $_, 1 } @dump_tables;
    for my $table ( @tables ) {
        my $table_name = $table->{'name'};
        next if %dump_tables && !$dump_tables{ $table_name };

        print $log_fh "Dumping data for '$table_name.'\n";
        print $fh "\n--\n-- Data for '$table_name'\n--\n";
        if ( $add_truncate ) {
            print $fh "TRUNCATE TABLE $table_name;\n";
        }

        my %fields     = %{ $table->{'fields'} };
        my @fld_names  = sort keys %fields;

        my $insert = "INSERT INTO $table_name (". join(', ', @fld_names).
                ') VALUES (';

        my $sth = $db->prepare(
            'select ' . join(', ', @fld_names). " from $table_name"
        );
        $sth->execute;
        while ( my $rec = $sth->fetchrow_hashref ) { 
            my @vals;
            for my $fld ( @fld_names ) {
                my $val = $rec->{ $fld };
                if ( $fields{ $fld } eq STR ) {
                    # Escape existing single quotes.
                    $val =~ s/'/\\'/g if $quote_escape eq 'backslash'; 
                    $val =~ s/'/''/g  if $quote_escape eq 'doubled'; 
                    $val = defined $val ? qq['$val'] : qq[''];
                }
                else {
                    $val = defined $val ? $val : 'NULL';
                }
                push @vals, $val;
            }

            print $fh $insert, join(', ', @vals), ");\n";
        }
    }

    print $fh "\n--\n-- Finished dumping Cmap data\n--\n";
}

# ----------------------------------------------------
sub export_as_text {
#
# Exports data as tab-delimited import format.
#
    my $self   = shift;
    my $db     = $self->db;
    my $log_fh = $self->log_fh;

    my @col_names = qw( 
        map_accession_id
        map_name
        map_start
        map_stop
        feature_accession_id
        feature_name
        feature_alt_name
        feature_start
        feature_stop
        feature_type
        feature_dbxref_name
        feature_dbxref_url
    );
    
    my @map_set_ids = $self->show_menu(
        title       => 'Select Map Sets',
        prompt      => 'Which map sets do you want to export?',
        display     => 'common_name,short_name',
        return      => 'map_set_id',
        allow_all   => 1,
        data        => $db->selectall_arrayref(
            q[
                select   ms.map_set_id,
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

    my @feature_type_ids = $self->show_menu(
        title       => 'Select Feature Types',
        prompt      => 'Which feature types do you want to include?',
        display     => 'feature_type',
        return      => 'feature_type_id',
        allow_all   => 1,
        data        => $db->selectall_arrayref(
            q[
                select   distinct ft.feature_type_id, 
                         ft.feature_type
                from     cmap_map map,
                         cmap_feature f,
                         cmap_feature_type ft
                where    map.map_set_id in (].join(',', @map_set_ids).q[)
                and      map.map_id=f.map_id
                and      f.feature_type_id=ft.feature_type_id
                order by feature_type
            ],
            { Columns => {} }
        )
    );

    my @exclude_fields = $self->show_menu(
        title       => 'Select Fields to Exclude',
        prompt      => 'Which fields do you want to exclude?',
        display     => 'field_name',
        return      => 'field_name',
        allow_null  => 1,
        allow_mult  => 1,
        data        => [ map { { field_name => $_ } } @col_names ],
    );

    if ( @exclude_fields == @col_names ) {
        print "\nError:  Can't exclude all the fields!\n";
        return;
    }

    my $dir = _get_dir();
    my $map_sets = $db->selectall_arrayref(
        q[
            select   ms.map_set_id, 
                     ms.short_name as map_set_name,
                     s.common_name as species_name
            from     cmap_map_set ms,
                     cmap_species s
            where    ms.map_set_id in (].join(',', @map_set_ids).q[)
            and      ms.species_id=s.species_id
            order by common_name, short_name
        ],
        { Columns => {} }
    );

    my @map_set_names = 
        map { join( '-', $_->{'species_name'}, $_->{'map_set_name'} ) }
        @$map_sets
    ;

    my $feature_types = $db->selectcol_arrayref(
        q[
            select   ft.feature_type
            from     cmap_feature_type ft
            where    ft.feature_type_id in (].join(',', @feature_type_ids).q[)
            order by feature_type
        ],
    );

    my $excluded_fields = 
        @exclude_fields ? join(', ', @exclude_fields) : 'None';

    #
    # Confirm decisions.
    #
    print join("\n",
        'OK to export?',
        '  Map Sets               : ' . join(', ', @map_set_names),
        '  Feature Types          : ' . join(', ', @$feature_types),
        "  Exclude Fields         : $excluded_fields",
        "  Directory              : $dir",
        "[Y/n] "
    );
    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my %exclude = map  { $_, 1 } @exclude_fields;
    @col_names  = grep { ! $exclude{ $_ } } @col_names;

    for my $map_set ( @$map_sets ) {
        my $map_set_id   = $map_set->{'map_set_id'};
        my $map_set_name = $map_set->{'map_set_name'};
        my $species_name = $map_set->{'species_name'};
        my $file_name    = join( '-', $species_name, $map_set_name );
           $file_name    =~ tr/a-zA-Z0-9-/_/cs;
           $file_name    = "$dir/$file_name.dat";

        print $log_fh "Dumping '$species_name-$map_set_name' to '$file_name'\n";
        open my $fh, ">$file_name" or die "Can't write to $file_name: $!\n";
        print $fh join( OUT_FS, @col_names ), OUT_RS;

        my $maps = $db->selectall_arrayref(
            q[
                select   map_id
                from     cmap_map
                where    map_set_id=?
                order by map_name
            ],
            { Columns => {} },
            ( $map_set_id )
        );

        for my $map ( @$maps ) {
            my $features = $db->selectall_arrayref(
                q[
                    select   f.feature_id, 
                             f.accession_id as feature_accession_id,
                             f.feature_name,
                             f.alternate_name as feature_alt_name,
                             f.start_position as feature_start,
                             f.stop_position as feature_stop,
                             f.dbxref_name as feature_dbxref_name,
                             f.dbxref_url as feature_dbxref_url,
                             ft.feature_type,
                             map.map_name, 
                             map.accession_id as map_accession_id,
                             map.start_position as map_start,
                             map.stop_position as map_stop
                    from     cmap_feature f,
                             cmap_feature_type ft,
                             cmap_map map
                    where    f.map_id=?
                    and      f.map_id=map.map_id
                    and      f.feature_type_id=ft.feature_type_id
                    and      ft.feature_type_id in (].
                             join(',', @feature_type_ids).q[)
                    order by f.start_position
                ],
                { Columns => {} },
                ( $map->{'map_id'} )
            );

            for my $feature ( @$features ) {
                $feature->{'stop_position'} = undef 
                if $feature->{'stop_position'} < $feature->{'start_position'};

                print $fh 
                    join( OUT_FS, map { $feature->{ $_ } } @col_names ), 
                    OUT_RS;
            }
        }
        
        close $fh;
    }
}

# ----------------------------------------------------
sub export_correspondences {
#
# Exports feature correspondences in CMap import format.
#
    my $self   = shift;
    my $db     = $self->db;
    my $log_fh = $self->log_fh;

    print "Include feature accession IDs? [Y/n] ";
    chomp( my $export_corr_aid = <STDIN> );
    $export_corr_aid = ( $export_corr_aid =~ /^[Nn]/ ) ? 0 : 1;

    my $dir = _get_dir();

    #
    # Confirm decisions.
    #
    print join("\n",
        'OK to export feature correspondences?',
        "  Export Accession IDs : " . ( $export_corr_aid ? "Yes" : "No" ),
        "  Directory            : $dir",
        "[Y/n] "
    );
    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my $corr_file = "$dir/feature_correspondences.dat";
    open my $fh, ">$corr_file" or die "Can't write to $corr_file: $!\n";
    print $log_fh "Dumping feature correspondences to '$corr_file'\n";
    my $sth = $db->prepare(
        q[
            select fc.feature_correspondence_id,
                   fc.is_enabled,
                   f1.accession_id as feature_accession_id1,
                   f1.feature_name as feature_name1,
                   f2.accession_id as feature_accession_id2,
                   f2.feature_name as feature_name2
            from   cmap_feature_correspondence fc,
                   cmap_feature f1,
                   cmap_feature f2
            where  fc.feature_id1=f1.feature_id
            and    fc.feature_id2=f2.feature_id
        ]
    );
    $sth->execute;

    my @col_names = ( 
        map { !$export_corr_aid && $_ =~ /accession/ ? () : $_ }
        qw[ 
            feature_name1 
            feature_accession_id1 
            feature_name2 
            feature_accession_id2
            evidence 
        ] 
    );

    print $fh join( OUT_FS, @col_names ), OUT_RS;
    while ( my $fc = $sth->fetchrow_hashref ) {
        $fc->{'evidence'} = join(',', @{
            $db->selectcol_arrayref(
                q[
                    select et.evidence_type
                    from   cmap_correspondence_evidence ce,
                           cmap_evidence_type et
                    where  ce.feature_correspondence_id=?
                    and    ce.evidence_type_id=et.evidence_type_id
                ],
                {},
                ( $fc->{'feature_correspondence_id'} )
            )
        });


        print $fh join( OUT_FS, map { $fc->{ $_ } } @col_names ), OUT_RS;
    }
}

# ----------------------------------------------------
sub import_correspondences {
#
# Gathers the info to import feature correspondences.
#
    my $self = shift;
    my $db   = $self->db;
    my $file = $self->file;
    my $term = $self->term;

    #
    # Make sure we have a file to parse.
    #
    if ( $file ) {
        print "OK to use '$file'? [Y/n] ";
        chomp( my $answer = <STDIN> );
        $file = '' if $answer =~ m/^[Nn]/;
    }

    while ( ! -r $file || ! -f _ ) {
        print "Unable to read '$file' or not a regular file.\n" if $file;
        $file =  $term->readline( 'Where is the file? [q to quit] ');
        $file =~ s/^\s*|\s*$//g;
        return if $file =~ m/^[Qq]/;
    }

    #
    # Open the file.  If it's good, remember it.
    #
    my $fh = IO::File->new( $file ) or die "Can't read $file: $!";
    $term->addhistory( $file ); 
    $self->file( $file );

    #
    # Get the map set.
    #
#    my @map_sets = $self->show_menu(
#        title       => 'Reference Map Set (optional)',
#        prompt      => 'Please select a map set',
#        display     => 'species_name,map_set_name',
#        return      => 'map_set_id,species_name,map_set_name',
#        allow_null  => 1,
#        allow_mult  => 1,
#        data        => $db->selectall_arrayref(
#            q[
#                select   ms.map_set_id, 
#                         ms.short_name as map_set_name,
#                         s.common_name as species_name
#                from     cmap_map_set ms,
#                         cmap_species s
#                where    ms.species_id=s.species_id
#                order by common_name, map_set_name
#            ],
#            { Columns => {} },
#        ),
#    );
#
#    my @map_set_ids = map { $_->[0] } @map_sets;

    print join("\n",
        'OK to import?',
        "  File      : $file",
    );

#    if ( @map_sets ) {
#        print join("\n", 
#            '',
#            '  From map sets:', 
#            map { "    $_" } map { join('-', $_->[1], $_->[2]) } @map_sets
#        );
#    }
    print "\n[Y/n] ";

    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my $importer = Bio::GMOD::CMap::Admin::ImportCorrespondences->new(
        data_source => $self->data_source,
    );

    $importer->import( 
        fh          => $fh,
#        map_set_ids => \@map_set_ids,
        log_fh      => $self->log_fh,
    ) or do { 
        print "Error: ", $importer->error, "\n"; 
        return; 
    };
}

# ----------------------------------------------------
sub import_data {
#
# Gathers the info to import physical or genetic maps.
#
    my $self = shift;
    my $db   = $self->db;
    my $term = $self->term;
    my $file = $self->file;

    #
    # Make sure we have a file to parse.
    #
    if ( $file ) {
        print "OK to use '$file'? [Y/n] ";
        chomp( my $answer = <STDIN> );
        $file = '' if $answer =~ m/^[Nn]/;
    }

    while ( ! -r $file || ! -f _ ) {
        print "Unable to read '$file' or not a regular file.\n" if $file;
        $file =  $term->readline( 'Where is the file? [q to quit] ');
        $file =~ s/^\s*|\s*$//g;
        return if $file =~ m/^[Qq]/;
    }

    #
    # Open the file.  If it's good, remember it.
    #
    my $fh = IO::File->new( $file ) or die "Can't read $file: $!";
    $term->addhistory($file); 
    $self->file( $file );

    #
    # Get the map type.
    #
    my ( $map_type_id, $map_type ) = $self->show_menu(
        title   => 'Available Map Types',
        prompt  => 'Please select a map type',
        display => 'map_type',
        return  => 'map_type_id,map_type',
        data     => $db->selectall_arrayref(
            q[
                select   mt.map_type_id, mt.map_type
                from     cmap_map_type mt
                order by map_type
            ],
            { Columns => {} },
        ),
    );
    do { print "No map types to select from.\n"; return } unless $map_type_id;

    #
    # Get the species.
    #
    my ( $species_id, $species ) = $self->show_menu(
        title   => "Available Species (for $map_type)",
        prompt  => 'Please select a species',
        display => 'common_name',
        return  => 'species_id,common_name',
        data     => $db->selectall_arrayref(
            q[
                select   distinct s.species_id, s.common_name
                from     cmap_species s,
                         cmap_map_set ms
                where    ms.species_id=s.species_id
                and      ms.map_type_id=?
                order by common_name
            ],
            { Columns => {} },
            ( $map_type_id )
        ),
    );
    do { print "No species to select from.\n"; return } unless $species_id;
    
    #
    # Get the map set.
    #
    my ( $map_set_id, $map_set_name ) = $self->show_menu(
        title   => "Available Map Sets (for $map_type, $species)",
        prompt  => 'Please select a map set',
        display => 'map_set_name',
        return  => 'map_set_id,map_set_name',
        data    => $db->selectall_arrayref(
            q[
                select   ms.map_set_id, ms.map_set_name
                from     cmap_map_set ms
                where    ms.map_type_id=?
                and      ms.species_id=?
                and      ms.map_type_id=?
                order by map_set_name
            ],
            { Columns => {} },
            ( $map_type_id, $species_id, $map_type_id )
        ),
    );
    do { print "There are no map sets for that map type!\n"; return }
         unless $map_set_id;

    print "Remove data in map set not in import file? [Y/n] ";
    chomp( my $overwrite = <STDIN> );
    $overwrite = ( $overwrite =~ /^[Nn]/ ) ? 0 : 1;

    #
    # Confirm decisions.
    #
    print join("\n",
        'OK to import?',
        "  File      : $file",
        "  Species   : $species",
        "  Map Type  : $map_type",
        "  Map Study : $map_set_name",
        "  Overwrite : " . ( $overwrite ? "Yes" : "No" ),
        "[Y/n] "
    );
    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    my $importer = Bio::GMOD::CMap::Admin::Import->new(
        data_source => $self->data_source,
    );
    $importer->import(
        map_set_id => $map_set_id,
        fh         => $fh,
        map_type   => $map_type,
        log_fh     => $self->log_fh,
        overwrite  => $overwrite,
    ) or do { 
        print "Error: ", $importer->error, "\n"; 
        return; 
    };
}

# ----------------------------------------------------
sub make_name_correspondences {
    my $self = shift;
    my $db   = $self->db;

    #
    # Get the evidence type id.
    #
    my ( $evidence_type_id, $evidence_type ) = $self->show_menu(
        title   => 'Available evidence types',
        prompt  => 'Please select an evidence type',
        display => 'evidence_type',
        return  => 'evidence_type_id,evidence_type',
        data    => $db->selectall_arrayref(
            q[
                select   et.evidence_type_id, et.evidence_type
                from     cmap_evidence_type et
                order by evidence_type
            ],
            { Columns => {} },
        ),
    );

    #
    # Get the map set.
    #
    my @map_sets = $self->show_menu(
        title       => 'Reference Map Set (optional)',
        prompt      => 'Please select a map set',
        display     => 'species_name,map_set_name',
        return      => 'map_set_id,species_name,map_set_name',
        allow_null  => 1,
        allow_mult  => 1,
        data        => $db->selectall_arrayref(
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

    print "Make name-based correspondences\n",
        "  Evidence type: $evidence_type";
    if ( @map_sets ) {
        print join("\n", 
            '',
            '  From map sets:', 
            map { "    $_" } map { join('-', $_->[1], $_->[2]) } @map_sets
        );
    }

    print "\nOK to make correspondences? [Y/n] ";
    chomp( my $answer = <STDIN> );
    return if $answer =~ m/^[Nn]/;

    my $corr_maker = Bio::GMOD::CMap::Admin::MakeCorrespondences->new(
        db          => $db,
        data_source => $self->data_source,
    );
    $corr_maker->make_name_correspondences(
        evidence_type_id => $evidence_type_id,
        map_set_ids      => \@map_set_ids,
        log_fh           => $self->log_fh,
    ) or do { print "Error: ", $corr_maker->error, "\n"; return; };

    return 1;
}

# ----------------------------------------------------
sub reload_correspondence_matrix {
    my $self  = shift;

    print "OK to truncate table and reload? [Y/n] ";
    chomp( my $answer = <STDIN> );
    return if $answer =~ m/^[Nn]/;

    my $admin = Bio::GMOD::CMap::Admin->new( 
        db          => $self->db,
        data_source => $self->data_source,
    );
    $admin->reload_correspondence_matrix or do { 
        print "Error: ", $admin->error, "\n"; return; 
    };

    return 1;
}

# ----------------------------------------------------
sub show_menu {
    my $self    = shift;
    my %args    = @_;
    my $data    = $args{'data'}   or return;
    my @return  = split(/,/, $args{'return'} ) 
                  or die "No return field(s) defined\n";
    my @display = split(/,/, $args{'display'});
    my $result;

    if ( scalar @$data > 1 ) {
        my $i      = 1;
        my %lookup = ();

        my $title = $args{'title'} || '';
        print $title ? "\n$title\n" : "\n";
        for my $row ( @$data ) {
            print "[$i] ", join(' : ', map { $row->{$_} } @display), "\n";
            $lookup{ $i } = scalar @return > 1 ? 
                [ map { $row->{$_} } @return ] : $row->{ $return[0] };
            $i++;
        }

        if ( $args{'allow_all'} ) {
            print "[$i] All of the above\n";
        }

        my $prompt = $args{'prompt'} || 'Please select';
        for ( ;; ) {
            print "\n$prompt", 
                $args{'allow_null'} 
                    ? ' (0 or <Enter> for nothing)'               : '',
                $args{'allow_all'} || $args{'allow_mult'} 
                    ? "\n(separate multiple choices with spaces)" : '',
                ': '
            ;

            chomp( my $answer = <STDIN> );

            if ( $args{'allow_null'} && $answer == 0 ) {
                $result = undef;
                last;
            }
            elsif ( $args{'allow_all'} && $answer == $i ) {
                $result = [ map { $lookup{ $_ } } 1 .. $i - 1 ];
                last;
            }
            elsif ( $args{'allow_all'} || $args{'allow_mult'} ) {
                my %numbers = 
                    map { $_, 1 }         # make a lookup
                    grep {/\d+/}          # take only numbers
                    split /\s+/, $answer
                ;

                $result = [ 
                    map { $_ || () }      # parse out nulls
                    map { $lookup{ $_ } } # look it up
                    keys %numbers         # make unique
                ];

                next unless @$result;

                last;
            }
            elsif ( defined $lookup{ $answer } ) {
                $result = $lookup{ $answer }; 
                last;
            }
        }
    }
    elsif ( scalar @$data == 0 ) {
        $result = undef;
    }
    else {
        $result = [ map { $data->[0]->{ $_ } } @return ];
    }

    return wantarray 
        ? defined $result 
            ? @$result : () 
        : $result
    ;
}

# ----------------------------------------------------
sub _get_dir {
#
# Get a directory for writing files to.
#
    my $dir;
    for ( ;; ) {
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
                else  {
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

    -h|help     Display help message
    -v|version  Display version
    --no-log    Don't keep a log of actions

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

B<Note:> All the questions asked in cmap_admin.pl can be answered
either by choosing the number of the answer from a pre-defined list or
by typing something (usually a file path, notice that you can use
tab-completion if your system supports it).  When the answer must be
selected from a list and the answer is required, you will not be
allowed to leave the question until you have selected an answer from
the list.  Occassionally the answer is not required, so you can just
hit "<Return>."  Sometimes more than one answer is acceptable, so you
should specify all your choices on one line, separating the numbers
with spaces.  Finally, sometimes a question is never asked if there is
only one possible answer; the one answer is automatically taken and
processing moves on to the next question.

There are seven actions you can take with this tool:

=over 4

=item 1 

Change data source

Whenever the "Main Menu" is displayed, the current data source is
displayed.  If you have configured CMap to work with multiple data
sources, you can use this option to change which one you are currently
using.  The one defined as the "default" will always be chosen when
you first begin. See the ADMINISTRATION document for more information
on creating multiple data sources.

=item 2

Create new map set

This is the only feature duplicated with the web admin tool.  This is
a very simple implementation, however, meant strictly as a convenience
when loading new data sets.  You can only specify the species, map
type, long and short names.  Everything else about the map set must be
edited with the web admin tool.


=item 2 

Import data for existing map set

This allows you to import the feature data for a map set. The map set
may be one you just created and is empty or one that already has data
associated with it.  If the latter, you may choose to remove all the
data currently in the map set when isn't updated with the new data you
are importing.  For specifics on how the data should be formatted, see
the documentation ("perldoc") for Bio::GMOD::CMap::Admin::Import.  The
file containing the feature data can either be given as an argument to
this script or you can specify the file's location when asked.  

=item 3 

Make name-based correspondences

This option will create correspondences between any two features with
the same "feature_name" or "alternate_name," irrespective of case.  It
is possible to choose to make the correspondences from only one map
set (for the occasions when you bring in just one new map set, you
don't want to rerun this for the whole database -- it can take a long
time).

=item 4 

Import feature correspondences

Choose this option to import a file containing correspondences between
your features.  For more information on the format of this file, see
the documentation for Bio::GMOD::CMap::Admin::ImportCorrespondences.

=item 5 

Reload correspondence matrix

You should choose this option whenever you've altered the number of
correspondences in the database.  This will truncate the
"cmap_correspondence_matrix" table and reload it with the pair-wise
comparison of every map set in the database.

=item 6 Export data

There are three ways to dump the data in CMap:

=over 4 

=item 1 All Data as SQL INSERT statements

This method creates an INSERT statement for every record in every
table (or just those selected) a la "mysqldump."  This is meant to be
an easy way to backup or migrate an entire CMap database, esp. when
moving between database platforms (e.g. Oracle to MySQL).  The output
will be put into a file of your choosing and can be fed directly into
another database to mirror your current one.  You can also choose to
add "TRUNCATE TABLE" statements just before the INSERT statements so
as to erase any existing data.

=item 2 Map data in CMap import format

This method creates a separate file for each map set in the database.
The data is dumped to the same tab-delimited format used when
importing.  You can choose to dump every map set or just particular
ones, and you can choose to I<leave out> certain fields (e.g., maybe
you don't care to export your accession IDs).

=item 3 Feature correspondence data in CMap import format

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

=back

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2002-3 Cold Spring Harbor Laboratory

This program is free software;  you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

Bio::GMOD::CMap::Admin::Import, Bio::GMOD::CMap::Admin::ImportCorrespondences.

=cut
