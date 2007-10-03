#!/usr/bin/perl -w

=head1 NAME 

cmap_parceagp.pl

=head1 SYNOPSIS

  cmap_parceagp.pl agp_file > CMAP_IMPORT_FILE

=head1 DESCRIPTION

Parces AGP files into CMap style files.
Output is loadable into the database with cmap_admin.pl

=cut

# ----------------------------------------------------
use strict;
use Pod::Usage;
use Getopt::Long;
use IO::File;
use Data::Dumper;

my ( $help, );
GetOptions( 
    'h|help'   => \$help,
);
pod2usage if ($help or !@ARGV) ;

my $agp_file = $ARGV[$#ARGV];
open FILE_IN,$agp_file 
    or die "Couldn't open $agp_file: $!\n";

my $main_output = IO::File->new("> ".$agp_file.".cmap")
    or die "Couldn't open $agp_file.cmap for writing: $!\n";

###Print lead line
print $main_output "map_name\tfeature_name\tfeature_start\tfeature_stop\tfeature_type_acc\tfeature_direction\n";

my $map_name_pos        = 0;
my $start_pos           = 1;
my $stop_pos            = 2;
my $part_number_pos     = 3;
my $component_type_pos  = 4;
my $component_id_pos    = 5;
my $N_gap_length_pos    = 5;
my $component_start_pos = 6;
my $N_gap_type_pos      = 6;
my $component_stop_pos  = 7;
my $N_linkage_pos       = 7;
my $component_dir_pos   = 8;
my $feature_type_acc;
my $feature_name;
my $feature_dir;
my $line;

###Read in the AGP Data
my @la; #line array
while(<FILE_IN>){
    $line = $_;
    $line =~ s/\t\t/\t/g;
    @la=split(/\t/,$line);
    if ($la[$component_type_pos] eq 'N'){
        # This represents a gap
        $feature_type_acc = ($la[$N_gap_type_pos] eq 'fragment')?
            "gap":  $la[$N_gap_type_pos]."_gap";
        $feature_name = $feature_type_acc.":".$la[$start_pos]."-".$la[$stop_pos];
        $feature_dir  = 1;
    }
    else{
        $feature_type_acc = 
            ($la[$component_type_pos]=~/\s*F\s*/i)? 'finished_htg': 
            ($la[$component_type_pos]=~/\s*A\s*/i)? 'active_finishing': 
            ($la[$component_type_pos]=~/\s*D\s*/i)? 'draft_htg': 
            ($la[$component_type_pos]=~/\s*G\s*/i)? 'whole_genome_finishing': 
            ($la[$component_type_pos]=~/\s*P\s*/i)? 'pre-draft_htg': 
            ($la[$component_type_pos]=~/\s*O\s*/i)? 'other_sequence': 
            ($la[$component_type_pos]=~/\s*W\s*/i)? 'wgs_contig': 
             '';
        die "Component type: '$la[$component_type_pos]', not recognized\n" unless ($feature_type_acc);
        $feature_name = $la[$component_id_pos];
        $feature_dir  = (!$la[$component_dir_pos] or $la[$component_dir_pos]=~/\+/) ? 1 : -1; 
    }
    print $main_output "$la[$map_name_pos]\t"
        . "$feature_name\t"
        . "$la[$start_pos]\t"
        . "$la[$stop_pos]\t"
        . "$feature_type_acc\t"
        . "$feature_dir\n";
}

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2005 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut


