#!/usr/bin/perl -w

=head1 NAME 

cmap_parseWashUAceFiles.pl

=head1 SYNOPSIS

  ./cmap_parseWashUAceFiles.pl ace_file

=head1 OPTIONS


=head1 DESCRIPTION

Parses an ace file of SuperContigs as used by Washington University 
into a tab delimited file that cmap_admin.pl can read.

Requires contigs to be named like the WashU supercontigs.

Use cmap_manageParsedAceFile.pl afterward to make the data more managable.

=cut

# ----------------------------------------------------
use strict;
use Pod::Usage;
use Getopt::Long;
use Data::Dumper;

my ( $help );
GetOptions( 
    'h|help'   => \$help,
);
pod2usage if ($help or !@ARGV) ;

my $file_in = $ARGV[$#ARGV];
my %contig_data;
my %read_data;
my %contig_to_reads;
my $do_cluster=0;

print STDERR "before parse\n";
parse_ace( 
	   contig_data    => \%contig_data,
	   read_data      => \%read_data,
	   contig_to_reads   => \%contig_to_reads,
	   file_in        => $file_in,
	   );

print STDERR "after parse before sort\n";
my %clusters;
foreach my $contig_name (keys %contig_data){
    if ($contig_name=~/Contig(\d+)\.(\d+)/){
	$clusters{$1}->[$2]=1;	
    }
}
print STDERR "afterall\n";

###Print lead line
print "map_name\tfeature_name\tfeature_start\tfeature_stop\tfeature_type_accession\n";

###Print Clusters
my $cluster_name;
my $cluster_num=1;
my $offset;
my $clusterLine;
my $output;
my $readLines;
foreach my $contig_num (sort {$a <=> $b} keys %clusters){
    $offset=0;
    $output='';
    $cluster_name="Contig".$contig_num;
    print STDERR "$cluster_name ".$#{$clusters{$contig_num}}."\n";
    ###Map Set
    for (my $i=0; $i<=$#{$clusters{$contig_num}}; $i++){
	next unless ($clusters{$contig_num}->[$i]);
	my $contig_name="$cluster_name.$i";
	my $contig_stop=$contig_data{$contig_name}{'num_of_bases'}+$offset;

	print "$cluster_name\t$contig_name\t$offset\t$contig_stop\tcontig\n";
	###Map
	foreach my $read_name (
			       sort {
				   $read_data{$a}{'padded_start'}
				   <=>
       			           $read_data{$b}{'padded_start'}
			       }
				    @{$contig_to_reads{$contig_name}}
			       ){
	    my $dir='+';
	    $dir='-' if $read_data{$read_name}{'complement'} eq 'C';
	    my $read_start =
		$offset + $read_data{$read_name}{'padded_start'};
	    my $read_stop  =
		$read_start + $read_data{$read_name}{'length'};
	    if ($read_start>$read_stop){
		print STDERR "rev\n";
		($read_start,$read_stop)=($read_stop,$read_start);
	    }
	    $read_start= $offset>$read_start?
		$offset+1 : 
		$read_start;
	    $read_stop= $read_stop>$contig_stop?
		$contig_stop: 
		$read_stop;
	    		
	    
	    print "$cluster_name\t$read_name\t$read_start\t$read_stop\tread\n";
	    ###Feature
	    
	}
	$offset=$contig_stop;
    }
    $cluster_num++;
}


# ----------------------------------------------------
=pod

=head2 parse_ace

parses the ace file 

=cut

sub parse_ace{

    my %args  = @_; 
    my $contig_data    = $args{'contig_data'}  or die   'No contig data ref';
    my $read_data      = $args{'read_data'}    or die   'No read data ref';
    my $contig_to_reads   = $args{'contig_to_reads'} or die   'No contig/read ref';
    my $file           = $args{'file_in'}      or die   'No file handle';
    
    open (FILE_IN, $file) or die "couldn't open $file";
    my $file_num_of_contigs;
    my $file_num_of_reads;
    my $contig_name;
    my $read_name;
    while (<FILE_IN>){
	if (/^AS\s+(\d+)\s+(\d+)/i){
	    $file_num_of_contigs = $1;
	    $file_num_of_reads   = $2;
	}
	elsif (/^CO\s+(.+)\s+(\d+)\s+(\d+)\s+(\d+)\s+([U|C])/i){
	    $contig_name=$1;
	    %{$contig_data->{$contig_name}}=( 
				  num_of_bases         => $2,
				  num_of_reads         => $3,
				  num_of_base_segments => $4,
				  complement           => $5,
				  );	    
	}
	elsif(/^AF\s+(\S+)\s+([U|C])\s+(-*\d+)/i){
	    %{$read_data->{$1}}=(
				 complement   => $2,
				 padded_start => $3,
				 );
	    push @{$contig_to_reads->{$contig_name}},$1;
	}
	elsif(/^RD\s+(\S+)\s+(\d+)\s+\d+\s+\d+/){
	    $read_name = $1;
	    $read_data->{$read_name}->{'length'}=$2;	    
	}
	elsif(/^QA\s+([-]*\d+)\s+([-]*\d+)\s+(\d+)\s+(\d+)/){
	    $read_data->{$read_name}->{'qual_clip_start'}  = $1;
	    $read_data->{$read_name}->{'qual_clip_end'}    = $2;
	    $read_data->{$read_name}->{'align_clip_start'} = $3;
	    $read_data->{$read_name}->{'align_clip_end'}   = $4;
	}
    }

    ###Maybe Later
    ###Check consistancy of data
    #return $self->error("Wrong number of contigs found.") if ($file_num_of_contigs!=scalar(@contig_info));
    #my $total_reads=0;
    #foreach my $i (0..$#contig_info){
#	if ($contig_info[$i]{'num_of_reads'}!=scalar(@{$read_info[$i]})){
#	    return $self->error("Wrong number of reads in contig found.");
#	}
#	$total_reads+=scalar(@{$read_info[$i]})
#    }


}

