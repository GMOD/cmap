#!/usr/bin/perl
# vim: set ft=perl:

# $Id: profile-cmap-draw.pl,v 1.4 2003-09-29 20:49:47 kycl4rk Exp $

=head1 NAME

profile-cmap-draw.pl - profile drawing code for CMap

=head1 SYNOPSIS

To profile the drawing code using DProf:

  perl -d:DProf profile-cmap-draw.pl [options]

To profile the drawing code using DBI::ProfileDumper

  DBI_PROFILE=DBI::ProfileDumper profile-cmap-draw.pl [options]

Options:

    -h|--help|-?   Print brief help
    -d             The CMap data source to use
    -f             File containing URL
    -u             String for URL

  Then:

  dprofpp [-r|-u] [tmon.out]

=head1 DESCRIPTION

Use this to profile the CMap drawing code.

=cut

use strict;
use Data::Dumper;
use Getopt::Long;
use CGI;
use Pod::Usage;
use Apache::FakeRequest;
use Bio::GMOD::CMap::Drawer;
use Bio::GMOD::CMap::Constants;

my ( $help, $datasource, $file, $url, $min_correspondences );
GetOptions(
    'help|h|?' => \$help,
    'd:s'      => \$datasource,
    'f:s'      => \$file,
    'u:s'      => \$url,
) or pod2usage;

pod2usage(0) if $help;

if ( $file ) {
    open my $fh, $file or die "Can't read file '$file': $!\n";
    local $/;
    $url = <$fh>;
    close $fh;
    chomp $url;
}

pod2usage('No URL or file') unless $url;

my $q = CGI->new( $url );
my $ref_map_set_aid       = $q->param('ref_map_set_aid')       ||  0;
my $ref_map_aid           = $q->param('ref_map_aid')           ||  0;
my $ref_map_start         = $q->param('ref_map_start');
my $ref_map_stop          = $q->param('ref_map_stop');
my $comparative_maps      = $q->param('comparative_maps')      || '';
my $comparative_map_right = $q->param('comparative_map_right') || '';
my $comparative_map_left  = $q->param('comparative_map_left')  || '';
$min_correspondences      = $q->param('min_correspondences')   ||  0;
$datasource             ||= $q->param('data_source') || $datasource;

my %slots = (
    0 => {
        field       => $ref_map_aid == -1 ? 'map_set_aid' : 'map_aid',
        aid         => $ref_map_aid == -1 ? $ref_map_set_aid : $ref_map_aid,
        start       => $ref_map_start,
        stop        => $ref_map_stop,
        map_set_aid => $ref_map_set_aid,
    },
);

for my $cmap ( split( /:/, $comparative_maps ) ) {
    my ( $slot_no, $field, $accession_id ) = split(/=/, $cmap) or next;
    my ( $start, $stop ); 
    if ( $accession_id =~ m/^(.+)\[(.+),(.+)\]$/ ) {
        $accession_id = $1;
        $start        = $2;
        $stop         = $3;
    }
    $slots{ $slot_no } =  {
        field          => $field,
        aid            => $accession_id,
        start          => $start,
        stop           => $stop,
    };
}

my @slot_nos  = sort { $a <=> $b } keys %slots;
my $max_right = $slot_nos[-1];
my $max_left  = $slot_nos[ 0];

for my $side ( ( RIGHT, LEFT ) ) {
    my $slot_no = $side eq RIGHT ? $max_right + 1 : $max_left - 1;
    my $cmap    = $side eq RIGHT
        ? $comparative_map_right : $comparative_map_left;
    my ( $field, $accession_id ) = split( /=/, $cmap ) or next;
    my ( $start, $stop );
    if ( $accession_id =~ m/^(.+)\[(.+),(.+)\]$/ ) {
        $accession_id = $1;
        $start        = $2;
        $stop         = $3;
    }
    $slots{ $slot_no } =  {
        field          => $field,
        aid            => $accession_id,
        start          => $start,
        stop           => $stop,
    };
}

my $apr                 =  Apache::FakeRequest->new;
my $drawer              =  Bio::GMOD::CMap::Drawer->new(
    apr                 => $apr,
    data_source         => $datasource,
    cache_dir           => '.',
    slots               => \%slots,
    highlight           => '',
    font_size           => 'small',
    image_size          => 'small',
    image_type          => 'png',
    label_features      => 'all',
    min_correspondences => $min_correspondences || 0,
) or die Bio::GMOD::CMap::Drawer->error;

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

=cut
