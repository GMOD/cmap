#!/usr/bin/perl -w

=pod
                                                                                                                             
=head1 NAME
                                                                                                                             
upgrade_config_14_to_15.pl
                                                                                                                             
=head1 SYNOPSIS
                                                                                                                             
  upgrade_config_14_to_15.pl cmap.conf
                                                                                                                             
=head1 DESCRIPTION
                                                                                                                             
This script will make changes to a config file that are required for version
15.  It creates a new file that ends in ".15".
                                                                                                                             
=head1 AUTHOR
                                                                                                                             
Ben Faga E<lt>faga@cshl.eduE<gt>.
                                                                                                                             
=cut


use strict;

my $file = shift or die "No file given\n";

open FILE_IN, $file or die "Problem with file, $file\n";
open FILE_OUT, ">".$file.".15";

while(<FILE_IN>){
    my $line = $_;
    $line =~ s/_type_accession/_type_acc/;
    $line =~ s/species_name/species_common_name/;
    print FILE_OUT $line;
}


