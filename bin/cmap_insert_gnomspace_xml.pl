#!/usr/bin/perl -w

=head1 NAME 

cmap_insert_gnomspace_xml.pl

=head1 SYNOPSIS

  cmap_insert_gnomspace_xml.pl -f FILE -d DATASOURCE -r REF_MAP_SET_ACC \
    -a ALIGN_MAP_SET_ACC -t FEATURE_TYPE_ACC -e EVIDENCE_TYPE_ACC

=head1 OPTIONS

    -h|--help              Show this help message
    -f|--file              GnomSpace XML File
    -d|--data_source       CMap Datasource
    -r|--ref_map_set_acc   Map set accession to insert the reference map into
    -a|--align_map_set_acc Map set accession to insert the alignmed map into
    -t|--feature_type_acc  Feature type accession for the fragments
    -e|--evidence_type_acc Evidence type accession for the correspondenses


=head1 DESCRIPTION

This script parses an XML file from the GnomSpace program, inserts the fragment
data into CMap and creates correspondences between them as defined in the
map_alignment section of the file.  It is an exelent example of how to use the
CMap API to insert features.


=cut

use strict;
use Pod::Usage;
use Data::Dumper;
use Bio::GMOD::CMap::Admin;
use XML::Simple;
use Getopt::Long;
use constant LIVE      => 1;
use constant MAP_START => 0;

my ( $help, $file, $data_source, $ref_map_set_acc, $align_map_set_acc, );
my ( $feature_type_acc, $evidence_type_acc, );
GetOptions(
    'h|help'                => \$help,
    'f|file=s'              => \$file,
    'd|data_source=s'       => \$data_source,
    'r|ref_map_set_acc=s'   => \$ref_map_set_acc,
    'a|align_map_set_acc=s' => \$align_map_set_acc,
    't|feature_type_acc=s'  => \$feature_type_acc,
    'e|evidence_type_acc=s' => \$evidence_type_acc,
);
pod2usage if ($help);
pod2usage if ( !$data_source );
pod2usage if ( !$file );
pod2usage if ( !$ref_map_set_acc );
pod2usage if ( !$align_map_set_acc );
pod2usage if ( !$feature_type_acc );
pod2usage if ( !$evidence_type_acc );

my $cmap_admin = Bio::GMOD::CMap::Admin->new( data_source => $data_source, );

my $ref = XMLin($file);

my %restriction_info;
foreach my $restriction_map ( keys %{ $ref->{'restriction_map'} || [] } ) {
    $restriction_info{$restriction_map}{'name'} = $restriction_map . "_"
        . $ref->{'restriction_map'}{$restriction_map}{'enzymes'};
    @{ $restriction_info{$restriction_map}{'fragments'} } = split( /\s+/,
        $ref->{'restriction_map'}{$restriction_map}{'map_block'} );

}

my $ref_map_name   = $ref->{'map_alignment'}{'reference_map'}{'name'};
my $align_map_name = $ref->{'map_alignment'}{'aligned_map'}{'name'};

# Create Maps
my $ref_map_id = create_map(
    map_set_acc => $ref_map_set_acc,
    info        => $restriction_info{$ref_map_name},
    cmap_admin  => $cmap_admin,
);

my $align_map_id = create_map(
    map_set_acc => $align_map_set_acc,
    info        => $restriction_info{$align_map_name},
    cmap_admin  => $cmap_admin,
);

# Create Features
my $ref_feature_ids = create_features(
    map_id           => $ref_map_id,
    fragments        => $restriction_info{$ref_map_name}{'fragments'},
    feature_type_acc => $feature_type_acc,
    cmap_admin       => $cmap_admin,
);
$cmap_admin->validate_update_map_start_stop($ref_map_id);

my $align_feature_ids = create_features(
    map_id           => $align_map_id,
    fragments        => $restriction_info{$align_map_name}{'fragments'},
    feature_type_acc => $feature_type_acc,
    cmap_admin       => $cmap_admin,
);
$cmap_admin->validate_update_map_start_stop($align_map_id);

# Create Corrs

foreach my $alignment ( @{ $ref->{'map_alignment'}{'f'} || [] } ) {
    my $align_index     = $alignment->{'i'};
    my $ref_start_index = $alignment->{'l'};
    my $ref_stop_index  = $alignment->{'r'};

    my $align_feature_id = $align_feature_ids->[$align_index];
    die "align index $align_index out of bounds"
        if ( LIVE and !$align_feature_id );
    for (
        my $ref_index = $ref_start_index;
        $ref_index <= $ref_stop_index;
        $ref_index++
        )
    {
        my $ref_feature_id = $ref_feature_ids->[$ref_index];
        die "ref index $ref_index out of bounds"
            if ( LIVE and !$ref_feature_id );
        print STDERR
            "Creating corr between indexes $align_index and $ref_index\n";
        print STDERR "$align_feature_id to $ref_feature_id\n" if (LIVE);

        if (LIVE) {
            my $fc_id = $cmap_admin->feature_correspondence_create(
                feature_id1       => $align_feature_id,
                feature_id2       => $ref_feature_id,
                is_enabled        => 1,
                evidence_type_acc => $evidence_type_acc,
            );
            if ($fc_id) {
                print STDERR "feature_correspondence_id $fc_id\n";
            }
            else {
                print STDERR $cmap_admin->error;
            }
        }
    }
}

$cmap_admin->purge_cache(1);

sub create_features {

    my %args             = @_;
    my $map_id           = $args{'map_id'};
    my $fragments        = $args{'fragments'};
    my $feature_type_acc = $args{'feature_type_acc'};
    my $cmap_admin       = $args{'cmap_admin'};

    my @feature_ids;
    my $feature_start = MAP_START;
    foreach my $fragment ( @{ $fragments || [] } ) {
        my $feature_stop = $feature_start + $fragment + 0;
        print STDERR
            "Creating Feature $fragment: $feature_start - $feature_stop\n";
        push @feature_ids,
            $cmap_admin->feature_create(
            map_id           => $map_id,
            feature_name     => $fragment,
            feature_type_acc => $feature_type_acc,
            feature_start    => $feature_start,
            feature_stop     => $feature_stop,
            ) if (LIVE);
        $feature_start = $feature_stop + .001;
        $feature_start = 0.001 * ( int( $feature_start / 0.001 ) );
    }
    return \@feature_ids;
}

sub create_map {

    my %args        = @_;
    my $map_set_acc = $args{'map_set_acc'};
    my $info        = $args{'info'};
    my $cmap_admin  = $args{'cmap_admin'};

    my $map_set_id = $cmap_admin->sql()->acc_id_to_internal_id(
        acc_id      => $map_set_acc,
        object_type => 'map_set',
    );

    die("$map_set_acc is not a valid map set accession\n")
        if ( LIVE and !$map_set_id );

    my $map_name = $info->{'name'};
    my $map_data = $cmap_admin->sql()->get_maps(
        map_set_id => $map_set_id,
        map_name   => $map_name,
    );

    if ( @{ $map_data || [] } ) {
        return $map_data->[0]{'map_id'};
    }
    print STDERR "Creating Map: " . $map_name . "\n";
    my $map_id = $cmap_admin->map_create(
        map_name   => $map_name,
        map_set_id => $map_set_id,
        map_start  => MAP_START,
        map_stop   => MAP_START + 1,
    ) if (LIVE);

    unless ($map_id) {
        die "Failed to create map, $map_name: " . $cmap_admin->error . "\n";
    }

    return $map_id;
}
