#!/usr/bin/perl
# vim: set ft=perl:

# $Id: cmap_validate_import_file.pl,v 1.1 2007-10-26 19:48:32 mwz444 Exp $

=head1 NAME

cmap_validate_import_file.pl - Check a tab delimited file for import

=head1 SYNOPSIS

cmap_validate_import_file.pl d DATASOURCE -f IMPORT_FILE

Use this to check if a tab delimited file will import correctly.

Options:

    -h|--help|-?   Print brief help
    -d             The CMap data source to use
    -f             Import File 

=head1 DESCRIPTION

Use this to check if a tab delimited file will import correctly.

This will check to make sure that the required columns are present and that the
feature types are defined in the config directory.

=cut

use strict;
use if $ENV{'CMAP_ROOT'}, lib => $ENV{'CMAP_ROOT'} . '/lib';
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;
use Bio::GMOD::CMap::Admin::Import;
use Bio::GMOD::CMap::Constants;

my ( $help, $data_source, $file, $url, $min_correspondences, $debug );
GetOptions(
    'help|h|?' => \$help,
    'd:s'      => \$data_source,
    'f:s'      => \$file,
) or pod2usage;

pod2usage(0) if $help;

pod2usage("No Datasource provided") unless ($data_source);
pod2usage("No file provided") unless ($file);
my $fh = IO::File->new($file) or die "Can't read $file: $!";

 
my $importer = Bio::GMOD::CMap::Admin::Import->new(data_source=>$data_source)
    or die Bio::GMOD::CMap::Admin::Import->error;
die ("Datasource, $data_source does not exist\n") 
    unless ($importer->data_source eq $data_source); 
my $valid = $importer->validate_tab_file(
    fh => $fh,
);

if ($valid){
    print "VALID\n";
}
else{
    print "\nFAILED: $file failed the validity check for the above reasons\n";
}
    

=pod

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

Munged profile-cmap-draw.pl by Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2005 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut
