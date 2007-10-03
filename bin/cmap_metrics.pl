#!/usr/bin/perl
# vim: set ft=perl:

# $Id: cmap_metrics.pl,v 1.6 2007-10-03 20:19:53 mwz444 Exp $

=head1 NAME

cmap_metrics.pl

=head1 SYNOPSIS

  cmap_metrics.pl [options]

Options:

  -h|--help         Show help and quit
  -d|--datasource   Define datasource to use
  -l|--list         List defined datasources

=head1 DESCRIPTION

A simple script to tell you how many records are in each table.  If no 
datasource is provided, the default is used.

=cut

use strict;
use Getopt::Long;
use Pod::Usage;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Utils 'commify';

my ( $help, $ds, $list );
GetOptions( 
    'd|datasource:s' => \$ds,
    'h|help'         => \$help,
    'l|list'         => \$list,
);
pod2usage if $help;

my $cmap = Bio::GMOD::CMap->new or die Bio::GMOD::CMap->error;

if ( $list ) {
    my $ds = $cmap->data_sources or die "No datasources defined\n";
    print join("\n", 'Datasources:', ( map { "  $_->{'name'}" } @$ds ), '');
    exit(0);
}

if ( $ds ) {
    $cmap->db( $ds ) or die $cmap->error;
}
$ds = $cmap->data_source;

my $db = $cmap->db or die $cmap->error;

my @tables = qw[
    cmap_attribute
    cmap_correspondence_evidence
    cmap_correspondence_lookup
    cmap_correspondence_matrix
    cmap_feature
    cmap_feature_alias
    cmap_feature_correspondence
    cmap_map
    cmap_map_set
    cmap_next_number
    cmap_species
    cmap_xref
];

my ( @counts, $longest );
for my $table ( @tables ) {
    my $count = $db->selectrow_array("select count(*) from $table") || 0;
       $count = commify( $count );
    my $len   = length $count;
    $longest  = $len if $len > $longest;
    push @counts, [ $table, $count ];
}

my $header = "Number of records in datasource '$ds'";
$header    = join( "\n", $header, ( '-' x length $header ), '' );
print $header;
for my $rec ( @counts ) {
    printf "%${longest}s: %s\n", $rec->[1], $rec->[0];
}

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2003-4 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut
