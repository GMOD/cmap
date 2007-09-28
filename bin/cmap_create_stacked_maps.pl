#!/usr/bin/perl -w
# vim: set ft=perl:

=head1 NAME

cmap_create_stacked_maps.pl - Creates new data by stacking relational maps into
large contigs based off of correspondences to a reference map set. 

=head1 SYNOPSIS

cmap_create_stacked_maps.pl [options]

Options:

    -h|--help|-?   This help message
    -d|datasource  The CMap datasource to use
    -s|-m|--map_set_to_stack|--stack_map_set_acc  
        The accession of the relational map set (Required)
    -r|--reference_map_set|--ref_map_set_acc      
        The accession of the reference map set (Required)
    -n|--new_map_set|--new_map_set_acc 
        The accession of the map set to place the data into (Required)
    -f|--feature_type_acc|--stack_feature_type_acc 
        The feature type for the features that denote the original relational
        maps. (Required)
    -e|--evidence_type_accs
    -c|--correspondence_cutoff 
        The minimum number of correspondences a map needs to be placed 
        (default 0).
    -a|--alignment_file
        If the order of maps is already known, supply a file and it will be 
        used.  Any maps not in the file will be removed. 

Creates new data by stacking relational maps into large contigs based off of a
reference map set.  It uses data already in the CMap database.

=head1 DESCRIPTION

In order to simplify the view of relational map sets such as FPC contigs, where
there may be a lot of maps and a data overload, this will stack the contigs on
top of one another (method described below).  This will decrease the number of
maps required be queried and display.

This script will populate a new map set using data already in the database from
a relational map set (such as FPC maps) and a reference map set (such as a
sequence assembly).  The relational maps get mapped to the reference maps and
ordered based on correspondences in the database.  It then imports the stacked
data into a new map set (that you must create before hand).

Any relational maps that do not correspond to the reference map will be
SILENTLY dropped.  In the future, we may add reporting of this.

Attributes are created for each contig feature that reports the number of corrs
to each reference map.  Also, an xref is created to link back to the original
map.

Note: The stacking portion may act strangly if map units are not integers.

=head1 BEFORE YOU START

Here are some things that you will need to do BEFORE running this script.

=over 4

=item * New Map Set

Create a map set for the new stacked maps to be placed into.  Then use that
accession id for the "new_map_set" value.

=item * New Feature type

Create a new feature_type in the config file.  Supply this accession as
"feature_type_acc".  This will be the feature type that denotes the boundaries
of the original maps in the stacked maps.

=item * Alignment File (optional)

If the location and order of stacking maps on a reference map is already known,
a file can be supplied with this information.

This file is tab-delimited and contains 2 columns, reference map accession and
stack map accession.  The order that these are listed is the order that the
maps will appear.  The orientation of the maps will still be determined by the
correspondences.

If this file is imported, any stack maps that aren't in it, will be ignored.

=item * Evidence Type Accessions (optional)

To limit the correspondences used to specific evidence types, use the --evidence_type_accs flag followed by a comma or space delimited list of evidence type accessions.

  --evidence_type_acc "ANB, BLAST"

=back

=head1 AFTER RUNNING

You may want to run the duplicate correspondence remover in cmap_admin.pl.

=cut

use strict;
use warnings;
use Data::Dumper;
use Bio::GMOD::CMap::Admin;
use Getopt::Long;
use Pod::Usage;

my ($help,            $datasource,             $stack_map_set_acc,
    $ref_map_set_acc, $new_map_set_acc,        $stack_feature_type_acc,
    $corr_cutoff,     $evidence_type_accs_str, $alignment_file,
);
GetOptions(
    'help|h|?'                                    => \$help,
    'd:s'                                         => \$datasource,
    'map_set_to_stack|stack_map_set_acc|s|m:s'    => \$stack_map_set_acc,
    'reference_map_set|ref_map_set_acc|r:s'       => \$ref_map_set_acc,
    'new_map_set|new_map_set_acc|n:s'             => \$new_map_set_acc,
    'feature_type_acc|stack_feature_type_acc|f:s' => \$stack_feature_type_acc,
    'evidence_type_accs|e:s'                      => \$evidence_type_accs_str,
    'correspondence_cutoff|c:s'                   => \$corr_cutoff,
    'alignment_file|a:s'                          => \$alignment_file,
) or pod2usage;

pod2usage(0) if $help;

$corr_cutoff ||= 0;

my $cmap_admin = Bio::GMOD::CMap::Admin->new( data_source => $datasource, );
my $sql_object = $cmap_admin->sql();

my @evidence_type_accs = ();
if ($evidence_type_accs_str) {
    @evidence_type_accs = split( /[,\s]/, $evidence_type_accs_str );
}

unless (
    validate_params(
        cmap_admin             => $cmap_admin,
        sql_object             => $sql_object,
        stack_map_set_acc      => $stack_map_set_acc,
        ref_map_set_acc        => $ref_map_set_acc,
        new_map_set_acc        => $new_map_set_acc,
        stack_feature_type_acc => $stack_feature_type_acc,
        evidence_type_accs     => \@evidence_type_accs,
    )
    )
{
    pod2usage(0);
}

my $stack_map_set_id = $sql_object->acc_id_to_internal_id(
    acc_id      => $stack_map_set_acc,
    object_type => 'map_set'
);
my ( $stack_map_set, )
    = @{ $sql_object->get_map_sets_simple( map_set_id => $stack_map_set_id, )
    };
my $stack_maps
    = $sql_object->get_maps_simple( map_set_id => $stack_map_set_id, )
    or die "No maps in $stack_map_set_acc.\n";
my $ref_map_set_id = $sql_object->acc_id_to_internal_id(
    acc_id      => $ref_map_set_acc,
    object_type => 'map_set'
);
my ( $ref_map_set, )
    = @{ $sql_object->get_map_sets_simple( map_set_id => $ref_map_set_id, ) };
my $ref_maps = $sql_object->get_maps_simple( map_set_id => $ref_map_set_id, );
die "No maps in $ref_map_set_acc.\n" unless @{ $ref_maps || [] };
my %ref_map_lookup = map { $_->{'map_id'} => $_ } @$ref_maps;

my $new_map_set_id = $sql_object->acc_id_to_internal_id(
    acc_id      => $new_map_set_acc,
    object_type => 'map_set'
);

# Handle an alignment file
my %best_ref_map_id;
my %stacked_map_order_on_ref_map;
my %ref_map_id_lookup;
if ($alignment_file) {
    my $fh;
    my $line;
    my @la;
    open $fh, $alignment_file
        or die "Couldn't open alignment file: $alignment_file\n";
    while (<$fh>) {
        my $line = $_;
        chomp($line);
        @la = split "\t", $line;
        next unless ( $la[0] and $la[1] );
        my $ref_map_id;
        unless ( $ref_map_id = $ref_map_id_lookup{ $la[0] } ) {
            $ref_map_id = $sql_object->acc_id_to_internal_id(
                acc_id      => $la[0],
                object_type => 'map'
            );
            next unless ($ref_map_id);
            $ref_map_id_lookup{ $la[0] } = $ref_map_id;
        }
        my $stack_map_id = $sql_object->acc_id_to_internal_id(
            acc_id      => $la[1],
            object_type => 'map'
        );
        $best_ref_map_id{$stack_map_id} = $ref_map_id;
        push @{ $stacked_map_order_on_ref_map{$ref_map_id} }, $stack_map_id;
    }
    close $fh;
}

my %stack_maps_on_ref_map;
my %stack_median_loc;
my %stack_start;
my %stack_stop;
my %stack_mean_loc;
my %stack_map_name;
my %stack_map_acc;
my %stack_direction;
my $count        = 1;
my $report_count = 100;

my %corrs_to_refs_for_map;

my $kill_script = 0;
STACK_MAP:
foreach my $stack_map ( @{ $stack_maps || [] } ) {
    my $stack_map_id = $stack_map->{'map_id'};
    $stack_start{$stack_map_id}    = $stack_map->{'map_start'};
    $stack_stop{$stack_map_id}     = $stack_map->{'map_stop'};
    $stack_map_name{$stack_map_id} = $stack_map->{'map_name'};
    $stack_map_acc{$stack_map_id}  = $stack_map->{'map_acc'};
    if ( $alignment_file and not $best_ref_map_id{$stack_map_id} ) {
        next STACK_MAP;
    }
    my $corrs = $sql_object->get_feature_correspondence_for_counting(
        slot_info => { $stack_map_id => [], },
        slot_info2 => { map { $_->{'map_id'} => [], } @$ref_maps },
        included_evidence_type_accs => \@evidence_type_accs,
    );

    # Skips maps w/ no corrs
    next STACK_MAP unless ( @{ $corrs || [] } );

    my %corr_locs_to_map;
    foreach my $corr ( @{$corrs} ) {
        my $corr_stack_loc
            = ( $corr->{'feature_stop1'} + $corr->{'feature_start1'} ) / 2;
        my $corr_ref_loc
            = ( $corr->{'feature_stop2'} + $corr->{'feature_start2'} ) / 2;
        push @{ $corr_locs_to_map{ $corr->{'map_id2'} } },
            [ $corr_stack_loc, $corr_ref_loc ];
    }

    # The best reference map is determined by total number of corrs.
    my $best_ref_map_id;

    if ($alignment_file) {
        next STACK_MAP
            unless ( $best_ref_map_id = $best_ref_map_id{$stack_map_id} );
        foreach my $ref_map_id ( keys %corr_locs_to_map ) {
            $corrs_to_refs_for_map{$stack_map_id}{$ref_map_id}
                = scalar @{ $corr_locs_to_map{$ref_map_id} };
        }
    }
    else {
        my $best_corr_num = 0;

        # the keys are sorted so that results will be reproducible.
        foreach my $ref_map_id ( sort { $a <=> $b } keys %corr_locs_to_map ) {
            $corrs_to_refs_for_map{$stack_map_id}{$ref_map_id}
                = scalar @{ $corr_locs_to_map{$ref_map_id} };
            if ( scalar @{ $corr_locs_to_map{$ref_map_id} } > $best_corr_num )
            {
                $best_ref_map_id = $ref_map_id;
                $best_corr_num   = scalar @{ $corr_locs_to_map{$ref_map_id} };
            }
        }
        next STACK_MAP unless ( $best_corr_num >= $corr_cutoff );
    }
    my @sorted_by_ref_locs = sort { $a->[1] <=> $b->[1] }
        @{ $corr_locs_to_map{$best_ref_map_id} || [] };
    my $locs_num = ( scalar @sorted_by_ref_locs );

    if ( $locs_num == 0 ) {
        print STDERR "Map "
            . $stack_map_name{$stack_map_id}
            . " (id: $stack_map_id), does not have correspondences "
            . "to the map it is aligned with ($best_ref_map_id)\n";
        $kill_script = 1;
        next STACK_MAP;
    }

    my $ref_median_loc;
    if ( $locs_num % 2 ) {

        #odd number
        $ref_median_loc = $sorted_by_ref_locs[ int( $locs_num / 2 ) ][1];
    }
    else {

        #even number is a bit more complicated
        my $half_total = $locs_num / 2;
        $ref_median_loc = ( $sorted_by_ref_locs[ $half_total - 1 ][1]
                + $sorted_by_ref_locs[$half_total][1] ) / 2;
    }

    my $ref_loc_sum = 0;
    $ref_loc_sum += $_->[1] foreach (@sorted_by_ref_locs);
    my $ref_mean_loc = $ref_loc_sum / ( scalar @sorted_by_ref_locs );

    # my $inc_stack_sub = sub { return $_[0]->[0] < $_[1]->[0] };
    my $inc_stack_sub = sub { return $_[0][0] < $_[1][0] };
    my ( $inc_score, undef )
        = longest_run( \@sorted_by_ref_locs, $inc_stack_sub );
    my $dec_stack_sub = sub { return $_[0]->[0] > $_[1]->[0] };
    my ( $dec_score, undef )
        = longest_run( \@sorted_by_ref_locs, $dec_stack_sub );
    my $direction = ( $dec_score > $inc_score ) ? -1 : 1;

    push @{ $stack_maps_on_ref_map{$best_ref_map_id} }, $stack_map_id;
    $stack_median_loc{$stack_map_id} = $ref_median_loc;
    $stack_mean_loc{$stack_map_id}   = $ref_mean_loc;
    $stack_direction{$stack_map_id}  = $direction;

    print "Read " . $report_count . " Maps\n"
        unless ( $count % $report_count );
    $count++;
}
print "Done Reading Maps\n";
die "Script Failed\n" if ($kill_script);

foreach my $ref_map_id ( keys %stack_maps_on_ref_map ) {
    print "--------------------------------------\n";
    print "Reference Map: "
        . $ref_map_lookup{$ref_map_id}->{'map_name'}
        . " ($ref_map_id)\n";
    my @stack_map_ids;
    if ($alignment_file) {
        @stack_map_ids
            = @{ $stacked_map_order_on_ref_map{$ref_map_id} || [] };
    }
    else {
        @stack_map_ids = @{ $stack_maps_on_ref_map{$ref_map_id} };
        @stack_map_ids = sort {
                   ( $stack_median_loc{$a} <=> $stack_median_loc{$b} )
                || ( $stack_mean_loc{$a} <=> $stack_mean_loc{$b} )
                || ( $a <=> $b )
        } @stack_map_ids;
    }
    next unless (@stack_map_ids);

    # Create map but fill in start and stop later.
    my $new_map_id = $sql_object->insert_map(
        map_set_id => $new_map_set_id,
        map_name   => $stack_map_set->{'map_set_short_name'} . " on "
            . $ref_map_lookup{$ref_map_id}->{'map_name'},
        display_order => 1,
        map_start     => 1,
        map_stop      => 2,
    );
    print "Stacking " . scalar(@stack_map_ids) . " Maps\n";
    my $current_composite_length = 0;
    $count        = 1;
    $report_count = 10;
    foreach my $stack_map_id (@stack_map_ids) {
        my $stack_map_length
            = $stack_stop{$stack_map_id} - $stack_start{$stack_map_id} + 1;
        my $stack_offset
            = $current_composite_length - $stack_start{$stack_map_id} + 1;
        my $new_composite_end = $current_composite_length + $stack_map_length;

        my $new_feature_id = $sql_object->insert_feature(
            map_id           => $new_map_id,
            feature_name     => $stack_map_name{$stack_map_id},
            is_landmark      => 1,
            feature_start    => $current_composite_length + 1,
            feature_stop     => $current_composite_length + $stack_map_length,
            feature_type_acc => $stack_feature_type_acc,
            direction        => $stack_direction{$stack_map_id},
        );

        # Create attributes to hold the number of corrs to each ref map
        my $drawing_order = 1;
        foreach my $corr_ref_map_id (
            sort {
                $corrs_to_refs_for_map{$stack_map_id}
                    {$b} <=> $corrs_to_refs_for_map{$stack_map_id}{$a}
            } keys %{ $corrs_to_refs_for_map{$stack_map_id} || {} }
            )
        {
            $sql_object->insert_attribute(
                display_order  => $drawing_order,
                object_type    => 'feature',
                object_id      => $new_feature_id,
                is_public      => 1,
                attribute_name => 'Reference Map Correspondences',
                attribute_value =>
                    $ref_map_lookup{$corr_ref_map_id}->{'map_name'} . ":"
                    . $corrs_to_refs_for_map{$stack_map_id}{$corr_ref_map_id},
            );
            $drawing_order++;
        }

        # Create dbxref to link back to the original map
        $sql_object->insert_xref(
            object_type => 'feature',
            object_id   => $new_feature_id,
            xref_name   => 'Original Map',
            xref_url    => 'viewer?ref_map_accs='
                . $stack_map_acc{$stack_map_id},
        );

        my $features
            = $sql_object->get_features_simple( map_id => $stack_map_id, );

        foreach my $feature ( @{ $features || [] } ) {
            my $new_feature_id;

            if ( $stack_direction{$stack_map_id} > 0 ) {
                $new_feature_id = $sql_object->insert_feature(
                    map_id        => $new_map_id,
                    feature_name  => $feature->{'feature_name'},
                    is_landmark   => $feature->{'is_landmark'},
                    feature_start => $stack_offset
                        + $feature->{'feature_start'},
                    feature_stop => $stack_offset
                        + $feature->{'feature_stop'},
                    feature_type_acc => $feature->{'feature_type_acc'},
                    default_rank     => $feature->{'default_rank'},
                    direction        => $feature->{'direction'},
                );

            }
            else {
                $new_feature_id = $sql_object->insert_feature(
                    map_id        => $new_map_id,
                    feature_name  => $feature->{'feature_name'},
                    is_landmark   => $feature->{'is_landmark'},
                    feature_start => $new_composite_end
                        - $feature->{'feature_stop'},
                    feature_stop => $new_composite_end
                        - $feature->{'feature_start'},
                    feature_type_acc => $feature->{'feature_type_acc'},
                    default_rank     => $feature->{'default_rank'},
                    direction => ( $feature->{'direction'} < 0 ) ? 1 : -1,
                );

            }

            my $corrs = $sql_object->get_feature_correspondence_details(
                feature_id1             => $feature->{'feature_id'},
                disregard_evidence_type => 1,
            );
            foreach my $corr ( @{ $corrs || [] } ) {
                $cmap_admin->feature_correspondence_create(
                    feature_id1             => $new_feature_id,
                    feature_id2             => $corr->{'feature_id2'},
                    is_enabled              => $corr->{'is_enabled'},
                    evidence_type_acc       => $corr->{'evidence_type_acc'},
                    correspondence_evidence => [],
                    allow_update            => 0,
                    threshold               => 100,
                );
            }
        }

        # Flush the correspondences
        $cmap_admin->feature_correspondence_create();

        $current_composite_length = $new_composite_end;

        print "Added " . $report_count . " Maps\n"
            unless ( $count % $report_count );
        $count++;
    }

    # Fill in start and stop of the map
    $sql_object->update_map(
        map_id    => $new_map_id,
        map_start => 1,
        map_stop  => $current_composite_length,
    );

}
my $cache_level = 1;
print "Purging cache at level $cache_level.\n";
$cmap_admin->purge_cache($cache_level);
print "Cache Purged\n";

sub validate_params {

    my %args                   = @_;
    my $cmap_admin             = $args{'cmap_admin'};
    my $sql_object             = $args{'sql_object'};
    my $stack_map_set_acc      = $args{'stack_map_set_acc'};
    my $ref_map_set_acc        = $args{'ref_map_set_acc'};
    my $new_map_set_acc        = $args{'new_map_set_acc'};
    my $stack_feature_type_acc = $args{'stack_feature_type_acc'};
    my $evidence_type_accs     = $args{'evidence_type_accs'};

    my @missing = ();
    if ( defined($stack_map_set_acc) ) {
        my $query_map_set_id = $sql_object->acc_id_to_internal_id(
            acc_id      => $stack_map_set_acc,
            object_type => 'map_set'
        );
        unless ($query_map_set_id) {
            print STDERR
                "Map set Accession, '$stack_map_set_acc' is not valid.\n";
            push @missing, 'stack_map_set_acc';
        }
    }
    else {
        push @missing, 'stack_map_set_acc';
    }
    if ( defined($ref_map_set_acc) ) {
        my $query_map_set_id = $sql_object->acc_id_to_internal_id(
            acc_id      => $ref_map_set_acc,
            object_type => 'map_set'
        );
        unless ($query_map_set_id) {
            print STDERR
                "Map set Accession, '$ref_map_set_acc' is not valid.\n";
            push @missing, 'reference_map_set';
        }
    }
    else {
        push @missing, 'reference_map_set';
    }
    if ( defined($new_map_set_acc) ) {
        my $query_map_set_id = $sql_object->acc_id_to_internal_id(
            acc_id      => $new_map_set_acc,
            object_type => 'map_set'
        );
        unless ($query_map_set_id) {
            print STDERR
                "Map set Accession, '$new_map_set_acc' is not valid.\n";
            push @missing, 'new_map_set';
        }
    }
    else {
        push @missing, 'new_map_set';
    }
    if ( defined($stack_feature_type_acc) ) {
        unless ( $cmap_admin->feature_type_data($stack_feature_type_acc) ) {
            print STDERR
                "The feature_type_acc, '$stack_feature_type_acc' is not valid.\n";
            push @missing, 'valid feature_type_acc';
        }
    }
    else {
        push @missing, 'valid feature_type_acc';
    }
    if ( @{ $evidence_type_accs || [] } ) {
        foreach my $evidence_type_acc ( @{ $evidence_type_accs || [] } ) {
            unless ( $cmap_admin->evidence_type_data($evidence_type_acc) ) {
                print STDERR
                    "The evidence_type_acc, '$evidence_type_acc' is not valid.\n";
                push @missing, 'valid evidence_type_acc';
            }
        }
    }
    if (@missing) {
        print STDERR "Missing the following arguments:\n";
        print STDERR join( "\n", sort @missing ) . "\n";
        return 0;
    }
    return 1;
}

# Return score and longest run for a run of objects
# in an array ref.
# longest_run written by Lincoln Stein
sub longest_run {
    my ( $arrayref, $scoresub ) = @_;

    my @score = [ 0, [] ];    # array ref containing [score,[subsequence]]
    for ( my $i = 0; $i < @$arrayref; $i++ ) {
        push @score, longest_run_score( $arrayref, \@score, $i, $scoresub );
    }
    my ( $best_score, $subseq ) = @{ $score[-1] };
    for ( my $i = 0; $i < @score - 1; $i++ ) {
        if ( $score[$i][0] > $best_score ) {
            $best_score = $score[$i][0];
            $subseq     = $score[$i][1];
        }
    }
    return ( $best_score, [ map { $arrayref->[$_] } @$subseq ] );
}

# longest_run_score written by Lincoln Stein
sub longest_run_score {
    my ( $arrayref, $scores, $position, $scoresub ) = @_;

    # find longest subsequence that this position extends
    my $max_score = 0;
    my $max_subseq;
    for my $subpart (@$scores) {
        my $sub_score = $subpart->[0];
        my $sub_seq   = $subpart->[1];

        # boundary condition; empty $sub_seq;
        unless (@$sub_seq) {
            $max_score  = 0;
            $max_subseq = $sub_seq;
            next;
        }

        my $score = $scoresub->(
            $arrayref->[ $sub_seq->[-1] ],
            $arrayref->[$position]
        );
        if ($score) {
            my $new_score = $sub_score + $score;
            if ( $new_score > $max_score ) {
                $max_score  = $new_score;
                $max_subseq = $sub_seq;
            }
        }
    }
    return [
        $max_score || 0,
        [ defined $max_subseq ? @$max_subseq : (), $position ]
    ];
}

=pod

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2006-7 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

