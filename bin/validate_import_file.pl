#!/usr/bin/perl
# vim: set ft=perl:

# $Id: validate_import_file.pl,v 1.1 2005-02-09 05:31:35 mwz444 Exp $

=head1 NAME

validate_import_file.pl - Check a tab delimited file for import

=head1 SYNOPSIS

validate_import_file.pl 

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

Ben Faga E<lt>faga@cshl.orgE<gt>.

Munged profile-cmap-draw.pl by Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=cut
