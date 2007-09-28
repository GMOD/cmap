#!/usr/bin/perl
# vim: set ft=perl:

# $Id: profile-cmap-draw.pl,v 1.7 2007-09-28 20:16:59 mwz444 Exp $

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
    --debug        Show debugging info

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
use Bio::GMOD::CMap::Apache::MapViewer;
use Bio::GMOD::CMap::Constants;
use Benchmark;

my ( $help, $datasource, $file, $url, $min_correspondences, $debug );
GetOptions(
    'help|h|?' => \$help,
    'd:s'      => \$datasource,
    'f:s'      => \$file,
    'u:s'      => \$url,
    'debug'    => \$debug,
) or pod2usage;

pod2usage(0) if $help;

if ( $file ) {
    print "Reading URL from file '$file'\n" if $debug;
    open my $fh, $file or die "Can't read file '$file': $!\n";
    local $/;
    $url = <$fh>;
    close $fh;
    chomp $url;
}

pod2usage('No URL or file') unless $url;
 
$url =~ s/^.*\?//; # isolate query string
$url =~ s/\s*$//;  # remove trailing spaces

my $q = CGI->new( $url );
my $time_new_mapView = new Benchmark;
my $viewer = Bio::GMOD::CMap::Apache::MapViewer->new( apr => $q )
    or die Bio::GMOD::CMap::Apache::MapViewer->error;

eval { my $output = $viewer->handler( $q ) };
my $time_after_eval = new Benchmark;

if ( my $e = $@ || $viewer->error ) {
    print "Error: $e\n";
}
print STDERR "Total:           ".timestr(timediff($time_after_eval,$time_new_mapView))."\n";
    

print "Done\n";

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2003-5 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut
