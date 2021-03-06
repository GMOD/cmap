#!/usr/bin/perl -w

=head1 NAME 

cmap_parcefpc.pl

=head1 SYNOPSIS

  cmap_parcefpc.pl [-a assembly_file] [options] fpc_file 

  options:
  -d|--delete_contig0 : Delete Contig0 which is where 
                        the singletons are placed.

  Files Created: 
    fpc_file.cmap
    fpc_file.assembly (if assembly_file is provided.


=head1 DESCRIPTION

Parces FPC files into CMap style files.  The output file is loadable into the
database with cmap_admin.pl

The assembly file must be like that produced by cmap_manageParsedAceFiles.pl.

If an assembly file is provided, the script will read through that file and
output (into a separate file) the lines that define clones that share a name
with one of the FPC clones.  The feature type accession of the assembly clones
must be "clone".

=cut

# ----------------------------------------------------
use strict;
use Pod::Usage;
use Getopt::Long;
use IO::File;
use Bio::MapIO;
use Data::Dumper;

my ( $help, $assembly_clone_file, $delete_contig0);
GetOptions( 
    'h|help'   => \$help,
    'a|assembly=s'   => \$assembly_clone_file,
    'd|delete_contig0'   => \$delete_contig0,
);
pod2usage if ($help or !@ARGV) ;

my $fpc_file = $ARGV[$#ARGV];


my $clone_name;
my $start;
my $stop;
my $line;
my $contig_name;

my $main_output = IO::File->new("> ".$fpc_file.".cmap")
    or die "Couldn't open $fpc_file.edit for writing: $!\n";

###Print lead line
print $main_output "map_name\tfeature_name\tfeature_start\tfeature_stop\tfeature_type_acc\n";


###Read in the FPC Data
my $mapio = new Bio::MapIO(-format => "fpc",-file => $fpc_file,
     -readcor => 0, -verbose => 0);

my $fpcmap = $mapio->next_map();
my %fpc_clones;
foreach my $contigid ($fpcmap->each_contigid()) {
    next if (!$contigid and $delete_contig0);
    $contig_name="FPC_Contig$contigid";
    # Create the marker object of only the required markers
    my $contigobj = $fpcmap->get_contigobj($contigid);
    # get all the clones in this contig
    foreach my $cloneid ($contigobj->each_cloneid()) {
        my $cloneobj = $fpcmap->get_cloneobj($cloneid);
        my $start = $cloneobj->range()->start();
        my $end   = $cloneobj->range()->end();
        $fpc_clones{$cloneid}=1;
        print $main_output "$contig_name\t$cloneid\t$start\t$end\tclone\n";
    }
                                                                                
    # get all the markers in this contig
    foreach my $markerid ($contigobj->each_markerid()) {
        my $markerobj = $fpcmap->get_markerobj($markerid);
        my $pos = $markerobj->position($contigid);
        print $main_output "$contig_name\t$markerid\t$pos\t$pos\tfpc_marker\n";
    }
}

if ($assembly_clone_file){
    ###Get the sequence clones to be added to the assembly 
    ### If the clone is in the %fpc_clones then we want to add it.
    ### Since we know this data is input in the correct form,
    ###  we can just print out the whole line. 
    my $assembly_output = IO::File->new("> ".$fpc_file.".assembly")
        or die "Couldn't open $fpc_file.assembly for writing: $!\n";
    print $assembly_output "map_name\tfeature_name\tfeature_start\tfeature_stop\tfeature_type_acc\n";
    open FILE_IN, $assembly_clone_file or die "couldn't open $assembly_clone_file.\n";
    while(<FILE_IN>){
        if($_=~/^\S+\t(\S+)\t\S+\t\S+\tclone/){
            $line=$_;
            $clone_name=$1;
            if ($fpc_clones{$clone_name}){
                print $assembly_output $line;
            }
        }
    }
}

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2004-5 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

