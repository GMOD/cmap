#!/usr/bin/perl

# $Id: cmap_dump.pl,v 1.2 2002-10-11 21:37:51 kycl4rk Exp $

use strict;
use Data::Dumper;
use Pod::Usage;
use Getopt::Long;
use Bio::GMOD::CMap;

use constant STR => 'string';
use constant NUM => 'number';

use vars qw[ $VERSION ];
$VERSION = (qw$Revision: 1.2 $)[-1];

#
# Get command-line options.
#
my ( $show_help, $show_version, $truncate );
GetOptions(
    'h|help'         => \$show_help,    # Show help and exit
    'v|version'      => \$show_version, # Show version and exit
    't|add-truncate' => \$truncate,     # Add truncate table statements
) or pod2usage(2);

pod2usage(0) if $show_help;
if ( $show_version ) {
    print "$0 Version: $VERSION\n";
    exit(0);
}

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
my %dump_tables;
for my $table_name ( map { $_->{'name'} } @tables ) {
    $dump_tables{ $table_name } = 1 if $args{ $table_name };
}

my $db = Bio::GMOD::CMap->new->db or die 'No db';
print "--\n-- Dumping data for Cmap",
    "\n-- Produced by cmap_dump.pl",
    "\n-- Version: $VERSION",
    "\n-- ", scalar localtime, "\n--\n";
for my $table ( @tables ) {
    my $table_name = $table->{'name'};
    next if %dump_tables && !$dump_tables{ $table_name };

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

=pod

=head1 NAME

cmap_dump.pl - dump data from Cmap tables like "mysqldump"

=head1 SYNOPSIS

  ./cmap_dump.pl [options] [tables]

  Options:

    -t|add-truncate Add 'truncate table' statements
    -h|help         Display help message
    -v|version      Display version

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
