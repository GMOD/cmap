#!/usr/bin/perl
# vim: set ft=perl:

# $Id: cmap_matrix_compare.pl,v 1.12 2007-09-28 20:16:59 mwz444 Exp $

=head1 NAME

cmap_matrix_compare.pl - compare matrix correspondences before and after a load

=head1 SYNOPSIS

  ./cmap_matrix_compare.pl [options]

  Options:

    -h|--help             Show brief usage statement
    -s|--store[=file]     Store the results for future comparison
    -r|--retrieve[=file]  Retrieve the data from a file
    -c|--compare[=file]   Compare the data in the file to the 
                          database or another file

If no "file" argument is supplied for "store," "compare" or
"retrieve," then "matrix_data.dat" will be used.

=head1 DESCRIPTION

This script is designed to compare the CMap correspondence matrix data
between different loads of the database.  In in its simplest use
(i.e., given no arguments), it will print out text tables showing the
current data in the matrix.  Its real power, however, is in being able
to take snapshots of the current database for comparisons.  To take a
snapshot, use the "-s" or "--store" argument, optionally giving a file
name in which to store the data.  (The data will be stored in a binary
[non-human-readable] format.)

Once you have one or more snapshots of your data, you can pass the
"-r" or "--retrieve" argument to retrieve the data from any file and
print it in tabular format.  You can also use past snapshots to
compare with what is currently in the database or between two
different snapshot files.  Passing just one argument to "-c" or
"--compare" will cause that file to be compared to the current
database.  Passing two will cause them to be compare to each other.

For example, say you want to take a snapshot on Monday:

  ./cmap_matrix_compare.pl --store monday.dat

On Tuesday, you alter the matrix information, so you take another:

  ./cmap_matrix_compare.pl --store tuesday.dat

On Wednesday, you alter the matrix information yet again.  Now you want
to see what the matrix looked like on Monday:

  ./cmap_matrix_compare.pl --retrieve monday.dat

To see how things changed from Monday to the current database:

  ./cmap_matrix_compare.pl --compare monday.dat

To see how things changed between Monday and Tuesday:

  ./cmap_matrix_compare.pl --compare monday.dat --compare tuesday.dat

=cut

# -------------------------------------------------------------------
use strict;
use Bio::GMOD::CMap;
use Getopt::Long;
use Data::Dumper;
use Pod::Usage;
use POSIX 'strftime';
use Storable;
use Text::TabularDisplay;

use constant DEFAULT_STORE_FILE => 'matrix_data.dat';
use constant DATE_FORMAT        => '%Y-%m-%d %I:%M %p';

my ( $help, $store, @compare, $retrieve );
GetOptions(
    'h|help'       => \$help,
    's|store:s'    => \$store,
    'c|compare:s'  => \@compare,
    'r|retrieve:s' => \$retrieve,
);
pod2usage if $help;

die qq[Error:  The "compare" option takes only one or two arguments.\n] 
    if scalar @compare > 2;

my $cmap = Bio::GMOD::CMap->new or die Bio::GMOD::CMap->error;
my $db   = $cmap->db            or die $cmap->error;
my $data = $cmap->data_module   or die $cmap->error;

#
# Get the enabled map sets.
#
my $map_sets = $db->selectall_hashref(
    q[
        select   ms.map_set_acc, 
                 ms.map_set_short_name,
                 ms.is_relational_map,
                 s.species_common_name
        from     cmap_map_set ms,
                 cmap_species s
        where    ms.is_enabled=1
        and      ms.species_id=s.species_id
        order by s.display_order,
                 species_common_name,
                 ms.display_order,
                 ms.published_on desc,
                 ms.map_set_short_name
    ],
    'map_set_acc',
    { Columns => {} }
);

#
# Get the current matrix data.
#
my $matrix_raw = $data->matrix_correspondence_data;
my $matrix     = $matrix_raw->{'data'};

#
# Match up the matrix data with the reference map sets.
#
for my $rec ( @$matrix ) {
    next unless exists $map_sets->{ $rec->{'reference_map_set_acc'} };
    push @{ 
        $map_sets->{ $rec->{'reference_map_set_acc'} }{'correspondences'} 
    }, $rec;
}

if ( defined $store ) {
    store_data( $map_sets, $store );
}
elsif ( defined $retrieve ) {
    retrieve_data( $retrieve ); 
}
elsif ( @compare ) {
    compare( $map_sets, \@compare );
}
else {
    show_current( $map_sets );
}

exit(0);

# -------------------------------------------------------------------
sub compare {
#
# If given two files to compare, retrieve the "current" matrix from
# the first and use the second as the old data.  If given just one
# file argument, then use what's passed for the current and retrieve
# the old data from the file.
#
    my $map_sets = shift;
    my @files    = @{ shift() || [] };

    my ( $file, $from, $to );
    if ( scalar @files > 1 ) {
        my ( $file1, $file2 ) = @files;
        die "Files are the same\n" if $file1 eq $file2;
        for ( $file1, $file2 ) {
            die "Can't read '$_'\n" unless -r $_;
        }
        $map_sets      = retrieve( $file1 ) or die "No data in '$file'\n";;
        $file          = $file2;
        my @file1_stat = stat $file1;
        my @file2_stat = stat $file2;
        $from          = qq["$file1" (] . strftime( DATE_FORMAT,
                         localtime( $file1_stat[9] ) ). ')';
        $to            = qq["$file2" (] . strftime( DATE_FORMAT,
                         localtime( $file2_stat[9] ) ). ')';
    }
    else {
        $file = $files[0] || DEFAULT_STORE_FILE;
        die "Can't read '$file'\n" unless -r $file;
        my @file_stat = stat $file;
        $to           = qq["$file" (] . strftime( DATE_FORMAT,
                        localtime( $file_stat[9] ) ) . ')';
        $from         = 'Current Database ('.
                        strftime( DATE_FORMAT, localtime ). ')';
    }

    my $old_map_sets = retrieve( $file ) or die "No data in '$file'\n";;

    print "Showing Correspondence Matrix Comparison\nFrom: $from\nTo  : $to\n";
    for my $ms ( 
        map  { $_->[2] }
        sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] }
        map  { [ $_->{'species_common_name'}, $_->{'map_set_short_name'}, $_ ] }
        values %$map_sets 
    ) {
        next if $ms->{'is_relational_map'};
        my $map_set_name = join(
            '-', $ms->{'species_common_name'}, $ms->{'map_set_short_name'} 
        );

        my $table = Text::TabularDisplay->new(
            $map_set_name, '# From.', '# To.', 'Change'
        );

        my @corr;
        for my $rec ( @{ $ms->{'correspondences'} } ) {
            my $link_ms_acc = $rec->{'link_map_set_acc'};
            my $link_ms     = $map_sets->{ $link_ms_acc } or next;
            my $cur         = $rec->{'correspondences'};
            my $old = $old_map_sets->{ $link_ms_acc }{'correspondence_lookup'}
                { $ms->{'map_set_acc'} } || '-';

            push @corr, [
                $link_ms->{'species_common_name'},
                $link_ms->{'map_set_short_name'},
                $cur,
                $old,
                ( $cur - $old ) || '',
            ];
        }

        for my $corr ( 
            sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] }
            @corr 
        ) {
            $table->add( 
                join( '-', $corr->[0], $corr->[1] ), 
                $corr->[2], 
                $corr->[3],
                $corr->[4] 
            );
        }

        print $table->render, "\n\n";
    }
}

# -------------------------------------------------------------------
sub show_current {
    my $map_sets = shift;
    my $source   = shift || 'Current Correspondence Matrix ('.
                   strftime(DATE_FORMAT, localtime). ')';

    print "Showing Data from $source\n";
    for my $ms ( 
        map  { $_->[2] }
        sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] }
        map  { [ $_->{'species_common_name'}, $_->{'map_set_short_name'}, $_ ] }
        values %$map_sets 
    ) {
        next if $ms->{'is_relational_map'};
        my $map_set_name = join(
            '-', $ms->{'species_common_name'}, $ms->{'map_set_short_name'} 
        );

        my $table = Text::TabularDisplay->new( $map_set_name, '# Corr.' );

        my @corr;
        for my $rec ( @{ $ms->{'correspondences'} } ) {
            my $link_ms = $map_sets->{ $rec->{'link_map_set_acc'} } or next;
            push @corr, [
                $link_ms->{'species_common_name'}, 
                $link_ms->{'map_set_short_name'},
                $rec->{'correspondences'},
            ];
        }

        for my $corr ( 
            sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] }
            @corr 
        ) {
            $table->add( join( '-', $corr->[0], $corr->[1] ), $corr->[2] );
        }

        print $table->render, "\n\n";
    }
}

# -------------------------------------------------------------------
sub retrieve_data {
    my $file = shift;
    $file    = DEFAULT_STORE_FILE if $file eq '' or $file == 1;
    die "Can't read '$file'\n" unless -r $file;
    my $old_map_sets = retrieve( $file ) or die "No data in '$file'\n";;
    my @file_stat    = stat $file;
    my $source       = qq["$file" (] . strftime( DATE_FORMAT,
                       localtime( $file_stat[9] ) ) . ')';
    show_current( $old_map_sets, $source );
}

# -------------------------------------------------------------------
sub store_data {
    my ( $map_sets, $file ) = @_;
    $file ||= DEFAULT_STORE_FILE;
    die "File '$file' exists\n" if -e $file;

    #
    # Turn the arrayref of correspondences into a hashref lookup
    # for use in future comparisons.
    #
    for my $ms ( values %$map_sets ) {
        my %corr = 
            map { $_->{'link_map_set_acc'}, $_->{'correspondences'} }
            @{ $ms->{'correspondences'} || [] };
        $ms->{'correspondence_lookup'} = \%corr;
    }

    store $map_sets, $file;
    print "Data stored in '$file.'\n",
        "Run '$0 --compare $file' to compare.\n";
}

=pod

=head1 SEE ALSO

Bio::GMOD::CMap.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut
