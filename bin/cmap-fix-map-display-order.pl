#!/usr/bin/perl

# $Id: cmap-fix-map-display-order.pl,v 1.2 2004-07-30 21:36:35 mwz444 Exp $

=head1 NAME

cmap-fix-map-display-order.pl - Fixes map display order for CMap

=head1 SYNOPSIS

  cmap-fix-map-display-order.pl [options]

Options:

  -d|--datasource=foo           CMap datasource
  --ms-aids=msaid1[,msaid2...]  A list of map set accession IDs
  -h|--help                     Show brief help and exit
  -v|--version                  Show version and exit

=head1 DESCRIPTION

This script sets the "cmap_map.display_order" to a numerical value 
based on some numerical value in the map's name.  If you have many maps 
with the same "display_order" value and the map's have numerical names, 
they will be sorted by the ASCII value of the names, so you'll have "1, 10, 
2, 3...," and that looks silly.  Even if the map names are like "ctg1, ctg10,
ctg2..." you probably want them sorted by the numerical part of the name.

With no arguments, every map for every map set will be affected.  Limit to 
just a subset of map sets by using the "ms-aids" argument.

=cut

# ----------------------------------------------------

use strict;
use Data::Dumper;
use Bio::GMOD::CMap;
use Getopt::Long;
use Pod::Usage;
use File::Basename;

use vars qw[ $VERSION ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;

my ( $help, $show_version, $data_source, $ms_aids );
GetOptions(
    'h|help'         => \$help,
    'v|version'      => \$show_version,
    'd|datasource:s' => \$data_source,
    'ms-aids:s'      => \$ms_aids,
);
pod2usage(2) if $help;

if ( $show_version ) {
    my $prog = basename( $0 );
    print "$prog v$VERSION\n";
    exit(0);
}

my $cmap = Bio::GMOD::CMap->new;
if ( $data_source ) {
    $cmap->data_source( $data_source ) or die $cmap->error;
}
my $db = $cmap->db;

my @map_set_aids;
if ( $ms_aids ) {
    @map_set_aids = split( /,/, $ms_aids );
}
else {
    @map_set_aids = @{
        $db->selectcol_arrayref( 'select accession_id from cmap_map_set' )
    };
}

print "OK to reset display order for maps in ",
    "following map sets from datasource '", $cmap->data_source, "'?\n",
    join(', ', @map_set_aids), "\n[y/N] ";

chomp( my $answer = <STDIN> );
unless ( $answer =~ /^[yY]/ ) {
    print "Not OK, exiting.\n";
    exit(0);
}

my %h  = (
    a  => 1,
    b  => 2,
    c  => 3,
    d  => 4,
    e  => 5,
    f  => 6,
    g  => 7,
    h  => 8,
    i  => 9,
    j  => 10,
);

for my $map_set_aid ( @map_set_aids ) {
    my $maps = $db->selectall_arrayref(
        q[
            select map.map_id, map.map_name
            from   cmap_map map, cmap_map_set ms
            where  map.map_set_id=ms.map_set_id
            and    ms.accession_id=?
        ],
        { Columns => {} },
        ( $map_set_aid )
    );

    for my $map ( @$maps ) {
        my $do = $map->{'map_name'};
        if ( $do =~ /\d/ ) {
            $do =~ s/[^\d]//g;
        }
        elsif ( $do =~ /^[A-Za-z]$/ ) {
            $do = $h{ lc $do };
        }

        unless ( $do =~ /^\d+$/ ) {
            print "+++Skipping $map->{map_name} ($do)\n";
            next;
        }

        print "Setting '$map->{map_name}' to '$do'\n";
        $db->do(
            q[
                update cmap_map
                set    display_order=?
                where  map_id=?
            ],
            { Columns => {} },
            ( $do, $map->{'map_id'} )
        );
    }
}

print "Done.\n";

# ----------------------------------------------------

=pod

=head1 SEE ALSO

Bio::GMOD::CMap.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=cut

