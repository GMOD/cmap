#!/usr/bin/perl -w

=head1 NAME 

cmap_manageParsedAceFile.pl

=head1 SYNOPSIS

  ./cmap_manageParsedAceFile.pl options cmap_tab_file



=head1 OPTIONS


=head1 DESCRIPTION

Takes a tab delimited cmap file created by an ace file parser,
finds the reads that don't have pairs near them and prints them out.

Also creates the read depth.

Output is loadable into the database with cmap_admin.pl

=cut

# ----------------------------------------------------
use strict;
use Pod::Usage;
use Getopt::Long;
use IO::File;
use Data::Dumper;

my ( $help );
GetOptions( 
    'h|help'   => \$help,
);
pod2usage if ($help or !@ARGV) ;

my $file_in = $ARGV[$#ARGV];


my %read_data;
my $last_contig="";
my $contig;
my $read;
my $start;
my $stop;
my $primer;
my $name;
my $index;
my $line;
my @remaining_stops; ###holds the stops;
my @real_read_depths;
my $current_depth=0;
open FILE_IN, $file_in or die "couldn't open $file_in\n";
my $main_output = IO::File->new("> ".$file_in.".edit")
    or die "Couldn't open $file_in.edit for writing: $!\n";
my $clone_output = IO::File->new("> ".$file_in.".clones")
    or die "Couldn't open $file_in.clones for writing: $!\n";

while(<FILE_IN>){
    if($_=~/^(\S+)\t(\S+)\t(\S+)\t(\S+)\tread/){
        $line=$_;
        $contig=$1;
        $read=$2;
        $start=$3;
        $stop=$4;

        $current_depth=add_to_read_depth(
            $start,
            $stop,
            $current_depth,
            \@real_read_depths,
            \@remaining_stops
        );
        if ($read=~/(.+)\.([A-Za-z]\d+\w{0,1})$/){
            $name  = $1;
            $primer= $2;
        }
        else{
            die "$read  didn't match\n";
        }
        if ($primer=~/^g/){
            $index=0;
        }
        else{
            $index=1;
        }
        $read_data{$name}[$index]=[$start,$line];
    }
    elsif($_=~/^(\S+)/){
        $line=$_;
        if ($1 ne $last_contig){
            $last_contig=$1;
            finish_read_depth(
                $current_depth,
                \@real_read_depths,
                \@remaining_stops
            );
            processContig(\%read_data,$contig,\@real_read_depths
                ,$main_output,$clone_output) 
                if (%read_data);
            %read_data        = ();
            $current_depth    = 0;
            @real_read_depths = ();
            @remaining_stops  = ();    
        }
        print $main_output $line;
    }
    else{
        print $main_output $_;
    }
}
close FILE_IN;

finish_read_depth(
    $current_depth,
    \@real_read_depths,
    \@remaining_stops
);
 
processContig(\%read_data,$contig,\@real_read_depths
    ,$main_output,$clone_output) if (%read_data);

#####################Helper Functions###################
sub add_to_read_depth{
    my $start         = shift;
    my $stop          = shift;
    my $current_depth = shift;
    my $depth_data    = shift;
    my $stop_data     = shift;

    ### Adjust current depth and stops
    while (scalar(@$stop_data)){
        if ($start>$stop_data->[0]){
            ###There is a stop before this start
            if ($depth_data->[-1][0]+1
                == $stop_data->[0]){
                ###last region ended with this stop
                ### reduce the depth of the new region.
                $depth_data->[-1][2]--;
                $current_depth--;
                splice @$stop_data,0,1; ###Remove the used stop.
            }   
            else{
                $depth_data->[-1][1]=$stop_data->[0];
                $current_depth--;
                push @$depth_data, [$stop_data->[0]+1,undef,$current_depth];
                splice @$stop_data,0,1; ###Remove the used stop.
            }
        }
        else{
            ###Since the stops are in order, 
            ### none of them will be > $start.
            last;
        }        
    }

    if (not scalar(@$depth_data)){
        $current_depth++;
        push @$depth_data, [$start,undef,$current_depth];
        push @$stop_data, $stop;
    }
    elsif ($depth_data->[-1][0]==$start){
        ###If this starts at the same place as previous
        $current_depth++;
        $depth_data->[-1][2]=$current_depth;
        ordered_insert($stop_data, $stop);
    }
    else{
        $depth_data->[-1][1] = $start - 1;
        $current_depth++;
        push @$depth_data, [$start,undef,$current_depth];
        ordered_insert($stop_data, $stop);
    }   
    return $current_depth; 
}

sub finish_read_depth{
    my $current_depth = shift;
    my $depth_data    = shift;
    my $stop_data     = shift;
    while (scalar(@$stop_data)){
        if ($depth_data->[-1][0]+1
            == $stop_data->[0]){
            ###last region ended with this stop
            ### reduce the depth of the new region.
            $depth_data->[-1][2]--;
            $current_depth--;
            splice @$stop_data,0,1; ###Remove the used stop.
        }   
        else{
            $depth_data->[-1][1]=$stop_data->[0];
            $current_depth--;
            push @$depth_data, [$stop_data->[0]+1,undef,$current_depth];
            splice @$stop_data,0,1; ###Remove the used stop.
        }
    }
    pop @$depth_data; ###Remove the last, empty region.
}

sub processContig{
    my $read_data    = shift;
    my $contig       = shift;
    my $depth_data   = shift;
    my $main_output  = shift;
    my $clone_output = shift;
    my @read_pair_data;
    my %count=('singlet'=>0,'far'=>0,'good'=>0);
    foreach my $name (keys %{$read_data}){
        if (not $read_data->{$name}[0] or 
            not $read_data->{$name}[1]){
            #p#rint S#TDERR "singlet $name\n";
            $count{'singlet'}++;
            printSinglet($name,$read_data,$main_output);
            next;
        }
        elsif (abs($read_data->{$name}[0][0] - 
            $read_data->{$name}[1][0]) >100000){
            #p#rint S#TDERR "distance $name\n";
                $count{'far'}++;
            printDistance($name,$read_data,$contig,$main_output);
            next;
        }
        else{
            $count{'good'}++;
            my $start = $read_data->{$name}[0][0];
            my $stop  = $read_data->{$name}[1][0];
            ($start,$stop) = ($stop,$start) if ($start>$stop);
            push @read_pair_data, [ $start, $stop ];
            printClone($name,$read_data,$contig,$clone_output);
        }
    }
    foreach my $key (keys %count){
        print STDERR "$contig $key $count{$key}\n";;
    }
    processReadDepth(
        contig     => $contig,
        depth_data => $depth_data,
        fh         => $main_output,
        type       => 'read_depth',
    );

    ### deal read pair depth
    my $current_pair_depth = 0;
    my @real_read_depths   = ();
    my @remaining_stops    = ();
    @read_pair_data = sort sort_read_pairs @read_pair_data;
    foreach my $data (@read_pair_data){
        my $pair_start = $data->[0];
        my $pair_stop  = $data->[1];
    
        
        $current_pair_depth=add_to_read_depth(
            $pair_start,
            $pair_stop,
            $current_pair_depth,
            \@real_read_depths,
            \@remaining_stops
        );
    }
    finish_read_depth(
        $current_pair_depth,
        \@real_read_depths,
        \@remaining_stops
    );
    processReadDepth(
        contig     => $contig,
        depth_data => \@real_read_depths,
        fh         => $main_output,
        type       => 'pair_depth',
    ) if (scalar(@real_read_depths));
}

sub processReadDepth{
    my %args        = @_;
    my $contig      = $args{'contig'};
    my $depth_data  = $args{'depth_data'};
    my $fh          = $args{'fh'};
    my $type        = $args{'type'};
    my $w_size      = $args{'w_size'}|| 1000;

    my $w_start         =undef;
    my $w_stop          =$w_size;
    my $w_current_avg   =0;
    my $w_current_bases =0;
    my $temp_region_start; #holds larger of window start or region start 
    my $new_current_bases;
    my $region_length;

    foreach my $region (@$depth_data){
        unless(defined($w_start)){
            $w_start=$region->[0];
            $w_stop = $w_start + $w_size-1; 
        }
        if ($region->[1]>$w_stop){
            ###region exits window
            #First finish up current window.
            my $segment_length = $w_stop-$region->[0]+1;
            $new_current_bases=$w_current_bases + $segment_length;
            if ($new_current_bases != $w_size){
                print STDERR "Window size wrong $new_current_bases $w_size\n";
                print STDERR "$w_start $w_stop\n";
            }
            $w_current_avg=
                (($w_current_avg*$w_current_bases)
                    +
                 ($region->[2]*$segment_length)
                )/$new_current_bases;
            print $fh "$contig\t".int($w_current_avg+.5)."\t$w_start\t"
                . ($w_start + $new_current_bases-1)."\t$type\n";
            $w_start = $w_stop+1;
            $w_stop += $w_size; 
            $w_current_bases = 0;
            $w_current_avg   = 0;
            #Deal with any windows that will fit inside the region
            while ($region->[1]>$w_stop){
                print $fh "$contig\t".$region->[2]."\t$w_start\t"
                . $w_stop."\t$type\n";
                $w_start = $w_stop+1;
                $w_stop += $w_size;
                $w_current_bases = 0;
                $w_current_avg   = 0;
            }
        }
        ###region in window. Just factor region into avg
        $region_length=$region->[0]>$w_start?
            $region->[1]-$region->[0]+1:
            $region->[1]-$w_start+1;
        $new_current_bases=$w_current_bases + $region_length;
        if ($new_current_bases > 0){
            $w_current_avg=
                (($w_current_avg*$w_current_bases)
                    +
                 ($region->[2]*$region_length)
                )/$new_current_bases;
        }
        $w_current_bases = $new_current_bases;
    }
    print $fh "$contig\t".int($w_current_avg+.5)."\t$w_start\t"
                . ($w_start + $new_current_bases-1)."\t$type\n";

}

sub printSinglet{
    my $name=shift;
    my $read_data=shift;
    my $fh          = shift;

    if ( $read_data->{$name}[0]){
        print $fh $read_data->{$name}[0][1];
    }
    if ( $read_data->{$name}[1]){
        print $fh $read_data->{$name}[1][1];
    }
}

sub printDistance{
    my $name=shift;
    my $read_data=shift;
    my $contig=shift;
    my $fh          = shift;

    my $start=$read_data->{$name}[0][0];
    my $stop=$read_data->{$name}[1][0];
    ($start,$stop)=($stop,$start) if ($stop<$start);
    print $fh "$contig\t$name\t$start\t$stop\tfar_apart\n";
}

sub printClone{
    my $name=shift;
    my $read_data=shift;
    my $contig=shift;
    my $fh          = shift;

    my $start=$read_data->{$name}[0][0];
    my $stop=$read_data->{$name}[1][0];
    ($start,$stop)=($stop,$start) if ($stop<$start);
    print $fh "$contig\t$name\t$start\t$stop\tclone\n";
}

sub ordered_insert{
    my $array = shift;
    my $value = shift;
    for (my $i=0;$i<scalar(@$array);$i++){
        if ($array->[$i] > $value){
            splice(@$array,$i,0,$value);
            return;
        }
    }
    push @$array,$value;
}

sub sort_read_pairs {
    return ($a->[0] <=> $b->[0]) if ($a->[0] <=> $b->[0]);
    return ($a->[1] <=> $b->[1]);
}
    
