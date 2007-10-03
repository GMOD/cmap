#!/usr/bin/perl -w

=head1 NAME 

cmap_import_alignment.pl

=head1 SYNOPSIS

  cmap_import_alignment.pl [options] 

  options:
  -h|--help                 : Show this message
  -d|--data_source          : CMap data source
  -f|--file                 : Alignment file or files
  -q|--query_map_set_acc    : Map set accession of queries
  -s|--subject_map_set_acc  : Map set accession of subjects
  -t|--format               : Type of file (default "blast")
  --fta|--feature_type_acc  : Feature type of hsps 
  --eta|--evidence_type_acc : Evidence type of the correspondence
  -i|--identity             : Identity cutoff (default "0")
  -l|--length               : Length cutoff (default "0")

=head1 USAGE

 $ ./cmap_import_alignment.pl -d DATASOURCE -f ALIGNMENT_FILE \
    -q QUERY_MAP_SET_ACC -s SUBJECT_MAP_SET_ACC -t FORMAT \
    --fta HSP_FEATURE_TYPE -eta CORRESPONDENCE_EVIDENCE_TYPE

=head1 DESCRIPTION

This script directly imports alignment data recognized by BioPerl's SearchIO
module (it has been tested for BLAST) into a CMap database.

It uses the name field from both the query and subject (as parsed by BioPerl)
to determine which CMap map is being refered to.  If no map with that name is
currently in the specific map set, the map will be created.

The HSPs are created as features with the type defined from the command line.
Correspondences between the HSPs are created. 

Requires Bio::Perl

=cut

# ----------------------------------------------------
use strict;
use Pod::Usage;
use Getopt::Long;
use IO::File;
use Data::Dumper;
use Bio::SearchIO;
use Bio::GMOD::CMap::Admin;

my ($help,              $data_source,         $file_str,
    $query_map_set_acc, $subject_map_set_acc, $format,
    $feature_type_acc,  $evidence_type_acc,   $min_identity,
    $min_length,
);
GetOptions(
    'h|help'                     => \$help,
    'd|datasource|data_source=s' => \$data_source,
    'f|file=s'                   => \$file_str,
    'q|query_map_set_acc=s'      => \$query_map_set_acc,
    's|subject_map_set_acc=s'    => \$subject_map_set_acc,
    't|format=s'                 => \$format,
    'fta|feature_type_acc=s'     => \$feature_type_acc,
    'eta|evidence_type_acc=s'    => \$evidence_type_acc,
    'i|min_identity=s'           => \$min_identity,
    'l|min_length=s'             => \$min_length,
);
pod2usage if ($help);

$min_identity ||= 0;
$min_length   ||= 0;

my $admin = Bio::GMOD::CMap::Admin->new( data_source => $data_source, );

my $files;
my $query_map_set_id;
my $subject_map_set_id;

my $formats = [
    {   display => 'BLAST',
        format  => 'blast'
    },
];

my $sql_object = $admin->sql;

# Validate input
my @missing = ();
if ($file_str) {
    unless ( $files = get_files( file_str => $file_str ) ) {
        print STDERR "None of the files, '$file_str' succeded.\n";
        push @missing, 'input file(s)';
    }
}
else {
    push @missing, 'input file(s)';
}
if ( defined($query_map_set_acc) ) {
    $query_map_set_id = $sql_object->acc_id_to_internal_id(
        acc_id      => $query_map_set_acc,
        object_type => 'map_set'
    );
    unless ($query_map_set_id) {
        print STDERR
            "Map set Accession, '$query_map_set_acc' is not valid.\n";
        push @missing, 'query_map_set_acc';
    }
}
else {
    push @missing, 'query_map_set_acc';
}
if ( defined($subject_map_set_acc) ) {
    $subject_map_set_id = $sql_object->acc_id_to_internal_id(
        acc_id      => $subject_map_set_acc,
        object_type => 'map_set'
    );
    unless ($subject_map_set_id) {
        print STDERR
            "Map set Accession, '$subject_map_set_acc' is not valid.\n";
        push @missing, 'subject_map_set_acc';
    }
}
else {
    push @missing, 'subject_map_set_acc';
}
if ( defined($feature_type_acc) ) {
    unless ( $admin->feature_type_data($feature_type_acc) ) {
        print STDERR
            "The feature_type_acc, '$feature_type_acc' is not valid.\n";
        push @missing, 'feature_type_acc';
    }
}
else {
    push @missing, 'feature_type_acc';
}
if ( defined($evidence_type_acc) ) {
    unless ( $admin->evidence_type_data($evidence_type_acc) ) {
        print STDERR
            "The evidence_type_acc, '$evidence_type_acc' is not valid.\n";
        push @missing, 'evidence_type_acc';
    }
}
else {
    push @missing, 'evidence_type_acc';
}
if ($format) {
    my $found = 0;
    foreach my $item (@$formats) {
        if ( $format eq $item->{'format'} ) {
            $found = 1;
        }
    }
    unless ($found) {
        print STDERR "The format, '$format' is not valid.\n";
        push @missing, 'format';
    }
}
else {
    push @missing, 'format';
}

if (@missing) {
    print STDERR "Missing the following arguments:\n";
    print STDERR join( "\n", sort @missing ) . "\n";
    pod2usage;
}

# Done Validating input

foreach my $file (@$files) {
    import_alignments(
        file_name         => $file,
        query_map_set_id  => $query_map_set_id,
        hit_map_set_id    => $subject_map_set_id,
        feature_type_acc  => $feature_type_acc,
        evidence_type_acc => $evidence_type_acc,
        format            => $format,
        admin             => $admin,
        min_identity      => $min_identity,
        min_length        => $min_length,
        )
        or do {
        print "Error: ", $admin->error, "\n";
        return;
        };
}
$admin->purge_cache(2);

# ----------------------------------------------------
sub get_files {

    #
    # Ask the user for files.
    #
    my %args       = @_;
    my $file_str   = $args{'file_str'} || '';
    my $allow_mult = defined $args{'allow_mult'} ? $args{'allow_mult'} : 1;
    my $prompt     =
          defined $args{'prompt'} ? $args{'prompt'}
        : $allow_mult             ? 'Please specify the files?[q to quit] '
        : 'Please specify the file?[q to quit] ';

    my @file_strs = split( /\s+/, $file_str );
    my @files     = ();

    # allow filename expantion and put into @files
    foreach my $str (@file_strs) {
        my @tmp_files = glob($str);
        print "WARNING: Unable to read '$str'!\n" unless (@tmp_files);
        push @files, @tmp_files;
    }
    foreach ( my $i = 0; $i <= $#files; $i++ ) {
        if ( -r $files[$i] and -f $files[$i] ) {
            print "$files[$i] read correctly.\n";
        }
        else {
            print "WARNING: Unable to read file '$files[$i]'!\n";
            splice( @files, $i, 1 );
            $i--;
        }
    }
    return \@files if (@files);
    return undef;
}

# ----------------------------------------------
sub import_alignments {
    my (%args)    = @_;
    my $admin     = $args{'admin'};
    my $file_name = $args{'file_name'}
        or die 'No file';
    my $query_map_set_id = $args{'query_map_set_id'}
        or die 'No map set';
    my $hit_map_set_id = $args{'hit_map_set_id'}
        || $query_map_set_id;
    my $feature_type_acc = $args{'feature_type_acc'}
        or die 'No feature_type_acc';
    my $evidence_type_acc = $args{'evidence_type_acc'}
        or die 'No evidence_type_acc';
    my $min_identity = $args{'min_identity'} || 0;
    my $min_length   = $args{'min_length'}   || 0;
    my $format       = $args{'format'}       || 'blast';

    my $in = new Bio::SearchIO(
        -format => $format,
        -file   => $file_name
    );
    my $added_feature_ids = {};
    my $maps_seen         = {};

    while ( my $result = $in->next_result ) {
        my $query_map_id = get_map_id(
            object     => $result,
            map_set_id => $query_map_set_id,
            maps_seen  => $maps_seen,
            )
            or die "Unable to find or create map "
            . $result->query_name() . "\n";
        while ( my $hit = $result->next_hit ) {
            my $hit_map_id = get_map_id(
                object     => $hit,
                map_set_id => $hit_map_set_id,
                maps_seen  => $maps_seen,
                )
                or die "Unable to find or create map " . $hit->name() . "\n";
            while ( my $hsp = $hit->next_hsp ) {
                if ( $hsp->length('total') > $min_length ) {
                    if ( $hsp->percent_identity >= $min_identity ) {
                        my @query_range = $hsp->range('query');
                        my @hit_range   = $hsp->range('hit');

                        my $query_feature_id = get_feature_id(
                            feature_type_acc  => $feature_type_acc,
                            map_id            => $query_map_id,
                            start             => $query_range[0],
                            end               => $query_range[1],
                            format            => $format,
                            added_feature_ids => $added_feature_ids,
                            )
                            or die
                            "Unable to find or create feature for query \n";
                        my $hit_feature_id = get_feature_id(
                            feature_type_acc  => $feature_type_acc,
                            map_id            => $hit_map_id,
                            start             => $hit_range[0],
                            end               => $hit_range[1],
                            format            => $format,
                            added_feature_ids => $added_feature_ids,
                            )
                            or die
                            "Unable to find or create feature for subject \n";

                        $admin->feature_correspondence_create(
                            feature_id1       => $query_feature_id,
                            feature_id2       => $hit_feature_id,
                            evidence_type_acc => $evidence_type_acc,
                        );
                    }
                }
            }
        }
    }
    return 1;
}

# get_map_id
#
# Check if this map needs adding, if so add it.
# Return the map_id of the map.
sub get_map_id {
    my (%args)     = @_;
    my $object     = $args{'object'};
    my $map_set_id = $args{'map_set_id'};
    my $admin      = $args{'admin'};
    my $maps_seen  = $args{'maps_seen'};

    my $sql_object = $admin->sql;

    my ( $map_name, $map_desc, $map_acc, $map_length );

    if ( ref($object) eq 'Bio::Search::Result::BlastResult' ) {
        $map_name   = $object->query_name();
        $map_desc   = $object->query_description();
        $map_acc    = $object->query_accession();
        $map_length = $object->query_length();
    }
    elsif ( ref($object) eq 'Bio::Search::Hit::BlastHit' ) {
        $map_name   = $object->name();
        $map_desc   = $object->description();
        $map_acc    = $object->accession();
        $map_length = $object->length();
    }
    else {
        return 0;
    }
    if ( $map_name =~ /^\S+\|\S+/ and $map_desc ) {
        $map_name = $map_desc;
    }

    $map_acc = '' unless defined($map_acc);

    # Check if added before
    my $map_key
        = $map_set_id . ":" . $map_name . ":" . $map_acc . ":" . $map_length;
    if ( $maps_seen->{$map_key} ) {
        return $maps_seen->{$map_key};
    }

    # Check for existance of map in cmap_map

    my $map_id_results = $sql_object->get_maps(
        map_acc     => $map_acc,
        map_name    => $map_name,
        map_length  => $map_length,
    );

    my $map_id;
    if ( $map_id_results and @$map_id_results ) {
        $map_id = $map_id_results->[0]{'map_id'};
    }
    else {

        # Map not found, creat it.
        print "Map \"$map_name\" not found.  Creating.\n";
        $map_id = $sql_object->insert_map(
            map_name    => $map_name,
            map_set_id  => $map_set_id,
            map_acc     => $map_acc,
            map_start   => '1',
            map_stop    => $map_length,
        );
    }
    $maps_seen->{$map_key} = $map_id;
    return $map_id;
}

# get_feature_id
#
# Check if this feature needs adding, if so add it.
# Return the map_id of the map.
sub get_feature_id {
    my (%args)            = @_;
    my $feature_type_acc  = $args{'feature_type_acc'};
    my $map_id            = $args{'map_id'};
    my $start             = $args{'start'};
    my $end               = $args{'end'};
    my $format            = $args{'format'};
    my $admin             = $args{'admin'};
    my $added_feature_ids = $args{'added_feature_ids'};
    my $direction         = 1;
    if ( $end < $start ) {
        ( $start, $end ) = ( $end, $start );
        $direction = -1;
    }

    my $sql_object = $admin->sql;

    my $feature_key = $direction
        . $feature_type_acc . ":"
        . $map_id . ":"
        . $start . ":"
        . $end;
    if ( $added_feature_ids->{$feature_key} ) {
        return $added_feature_ids->{$feature_key};
    }
    my $feature_id;

    # Check for existance of feature in cmap_feature

    my $feature_id_results = $sql_object->get_features(
        feature_start     => $start,
        feature_stop      => $end,
        feature_type_accs => [$feature_type_acc],
        direction         => $direction,
    );

    if ( $feature_id_results and @$feature_id_results ) {
        $feature_id = $feature_id_results->[0]{'feature_id'};
    }
    else {

        # Feature not found, creat it.
        my $feature_name = $format . "_hsp:$direction:$start,$end";
        $feature_id = $admin->feature_create(
            map_id           => $map_id,
            feature_name     => $feature_name,
            feature_start    => $start,
            feature_stop     => $end,
            is_landmark      => 0,
            feature_type_acc => $feature_type_acc,
            direction        => $direction,
        );
    }

    $added_feature_ids->{$feature_key} = $feature_id;
    return $added_feature_ids->{$feature_key};
}

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2007 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

