#!/usr/bin/perl

# $Id: cmap_dump.pl,v 1.4 2002-11-15 01:13:08 kycl4rk Exp $

use strict;
use DBI;
use Data::Dumper;
use Pod::Usage;
use Getopt::Long;
use Bio::GMOD::CMap;

use constant STR    => 'string';
use constant NUM    => 'number';
use constant OUT_FS => "\t";     # ouput field separator
use constant OUT_RS => "\n";     # ouput record separator

use vars qw[ $VERSION ];
$VERSION = (qw$Revision: 1.4 $)[-1];

my %dispatch = (
    text     => \&text_dump,
    sql      => \&sql_dump,
);

#
# Get command-line options.
#
my ( $show_help, $show_version, $truncate, $out_type );
GetOptions(
    'h|help'       => \$show_help,    # Show help and exit
    'v|version'    => \$show_version, # Show version and exit
    'add-truncate' => \$truncate,     # Add truncate table statements
    't|type=s'     => \$out_type,     # INSERT statements or text format
) or pod2usage(2);

$out_type ||= 'sql';

pod2usage(0) if $show_help or !exists $dispatch{ lc $out_type };
if ( $show_version ) {
    print "$0 Version: $VERSION\n";
    exit(0);
}

my @Tables = (
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
        }
    },
    {
        name   => 'cmap_feature_type',
        fields => {
            feature_type_id => NUM,
            accession_id    => STR,
            feature_type    => STR,
            default_rank    => NUM,
            is_visible      => NUM,
            shape           => STR,
            color           => STR,
        }
    },
    {
        name   => 'cmap_map',
        fields => {
            map_id         => NUM,
            accession_id   => STR,
            map_set_id     => NUM,
            map_name       => STR,
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
# Get any specific tables to dump.
#
my %args = map { $_ =~ s/\s+//g; ( $_, 1 ) } @ARGV;
my %Dump_tables;
for my $table_name ( map { $_->{'name'} } @Tables ) {
    $Dump_tables{ $table_name } = 1 if $args{ $table_name };
}

#
# Create a database handle and dispatch the action.
#
my $bio = Bio::GMOD::CMap->new or die 'No CMap object';
my $db  = $bio->db             or die $bio->error;
$dispatch{ lc $out_type }->( $db );

#
# Create a separate file for each map set, dump data like import format.
#
sub text_dump {
    my $db = shift;

    my @col_names = ( 
        #'map_accession_id',
        'map_name',
        'map_start',
        'map_stop',
        #'feature_accession_id',
        'feature_name',
        'feature_alt_name',
        'feature_start',
        'feature_stop',
        'feature_type',
    );

    my $map_sets = $db->selectall_arrayref(
        q[
            select ms.map_set_id, 
                   ms.map_set_name,
                   s.common_name as species_name
            from   cmap_map_set ms,
                   cmap_species s
            where  ms.species_id=s.species_id
        ],
        { Columns => {} }
    );

    for my $map_set ( @$map_sets ) {
        my $map_set_id   = $map_set->{'map_set_id'};
        my $map_set_name = $map_set->{'map_set_name'};
        my $species_name = $map_set->{'species_name'};
        my $file_name    = join( '-', $species_name, $map_set_name );
           $file_name    =~ tr/a-zA-Z0-9-/_/cs;
           $file_name    .= '.dat';

        print "Dumping '$species_name-$map_set_name' to '$file_name'\n";
        open my $fh, ">./$file_name" or die "Can't write to ./$file_name: $!";
        print $fh join( OUT_FS, @col_names ), OUT_RS;

        my $maps = $db->selectall_arrayref(
            q[
                select   map_id, 
                         map_name, 
                         accession_id,
                         start_position,
                         stop_position
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
                             f.accession_id,
                             f.feature_name,
                             f.alternate_name,
                             f.start_position,
                             f.stop_position,
                             ft.feature_type
                    from     cmap_feature f,
                             cmap_feature_type ft
                    where    f.map_id=?
                    and      f.feature_type_id=ft.feature_type_id
                    order by f.start_position
                ],
                { Columns => {} },
                ( $map->{'map_id'} )
            );

            for my $feature ( @$features ) {
                $feature->{'stop_position'} = undef 
                if $feature->{'stop_position'} < $feature->{'start_position'};

                print $fh join( OUT_FS,
                    #$map->{'accession_id'},
                    $map->{'map_name'},
                    $map->{'start_position'},
                    $map->{'stop_position'},
                    #$feature->{'accession_id'},
                    $feature->{'feature_name'},
                    $feature->{'alternate_name'},
                    $feature->{'start_position'},
                    $feature->{'stop_position'},
                    $feature->{'feature_type'},
                ), OUT_RS;
            }
        }
        
        close $fh;
    }
}

#
# Create dump of data with SQL INSERT statements -- all in one output stream.
#
sub sql_dump {
    my $db = shift;
    print "--\n-- Dumping data for Cmap",
        "\n-- Produced by cmap_dump.pl",
        "\n-- Version: $VERSION",
        "\n-- ", scalar localtime, "\n--\n";
    for my $table ( @Tables ) {
        my $table_name = $table->{'name'};
        next if %Dump_tables && !$Dump_tables{ $table_name };

        print "\n--\n-- Data for '$table_name'\n--\n";
        if ( $truncate ) {
            print "TRUNCATE TABLE $table_name;\n" if $truncate;
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
                    $val =~ s/'/\\'/g;
                    $val = defined $val ? qq['$val'] : qq[''];
                }
                else {
                    $val = defined $val ? $val : 'NULL';
                }
                push @vals, $val;
            }

            print $insert, join(', ', @vals), ");\n";
        }
    }

    print "\n--\n-- Finished dumping Cmap data\n--\n";
}

=pod

=head1 NAME

cmap_dump.pl - dump data from Cmap tables like "mysqldump"

=head1 SYNOPSIS

  ./cmap_dump.pl [options] [tables]

  Options:

    -t|--type=SQL|text INSERT statements (default) or text format
    -t|--add-truncate  Add 'truncate table' statements
    -h|--help          Display help message
    -v|--version       Display version

=head1 DESCRIPTION

This program mimics the "mysqldump" allowing you to dump all the data
in the Cmap database (or just the data in the tables specified).  The
data is dumped as "INSERT" statements suitable for feeding directly to
another database.  This is especially helpful for moving data between
different databases (e.g., Oracle to MySQL).

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

=head1 SEE ALSO

Bio::GMOD::CMap.

=cut
