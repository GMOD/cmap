#!/usr/bin/perl -w
# vim: set ft=perl:

=head1 NAME

cmap_examine_attribute.pl 

=head1 SYNOPSIS

cmap_examine_attribute.pl [options]

Options:

  -h|--help|-?   This help message
  -d|datasource  The CMap datasource to use
  -a|--attribute|--attribute_name
      The name of the attribute to be searched for.
  -o|--object_type
      The type of object to be looked at:
      map_set, species, map, feature, map_type, feature_type, evidence_type
        

=head1 DESCRIPTION

The goal of this script is to help look for attributes that haven't been
installed or maybe are stale.

This script examines the CMap data and find all instances of attributes for the object type.  It
will report types that are missing the thing.

If the attribute name has multiple values for a given object, only one will be reported.

Prints results to standard out.

=cut

use strict;
use warnings;
use Data::Dumper;
use Bio::GMOD::CMap::Admin;
use Bio::GMOD::CMap::Utils;
use Getopt::Long;
use Pod::Usage;

my ( $help, $datasource, $attribute_name, $object_type );
GetOptions(
    'help|h|?'                     => \$help,
    'datasource|d:s'               => \$datasource,
    'attribute|attribute_name|a:s' => \$attribute_name,
    'object_type|o:s'              => \$object_type,
    )
    or pod2usage;

pod2usage(0) if $help;
pod2usage(0) if ( !$datasource );
pod2usage(0) if ( !$attribute_name );
pod2usage(0) if ( !$object_type );

my $cmap_admin = Bio::GMOD::CMap::Admin->new( data_source => $datasource, );
my $sql_object = $cmap_admin->sql();

if ( $object_type eq 'map_set' ) {
    my $attributes = $sql_object->get_attributes(
        cmap_object    => $cmap_admin,
        object_type    => 'map_set',
        get_all        => 1,
        attribute_name => $attribute_name,
    );
    my $map_sets = $sql_object->get_map_sets( cmap_object => $cmap_admin, );
    my %attr_lookup;
    for my $attr (@$attributes) {
        $attr_lookup{ $attr->{'object_id'} } = $attr->{'attribute_value'};
    }
    foreach my $map_set ( @{ $map_sets || [] } ) {
        if ( $attr_lookup{ $map_set->{'map_set_id'} } ) {
            print $map_set->{'map_set_acc'} . "\t"
                . $map_set->{'map_set_name'} . "\t"
                . $attr_lookup{ $map_set->{'map_set_id'} } . "\n";
        }
        else {
            print $map_set->{'map_set_acc'} . "\t"
                . $map_set->{'map_set_name'}
                . "\tMISSING\n";
        }
    }
}
elsif ( $object_type eq 'species' ) {
    my $attributes = $sql_object->get_attributes(
        cmap_object    => $cmap_admin,
        object_type    => 'species',
        get_all        => 1,
        attribute_name => $attribute_name,
    );
    my $species = $sql_object->get_species( cmap_object => $cmap_admin, );
    my %attr_lookup;
    for my $attr (@$attributes) {
        $attr_lookup{ $attr->{'object_id'} } = $attr->{'attribute_value'};
    }
    foreach my $species ( @{ $species || [] } ) {
        if ( $attr_lookup{ $species->{'species_id'} } ) {
            print $species->{'species_acc'} . "\t"
                . $species->{'species_common_name'} . "\t"
                . $attr_lookup{ $species->{'species_id'} } . "\n";
        }
        else {
            print $species->{'species_acc'} . "\t"
                . $species->{'species_common_name'}
                . "\tMISSING\n";
        }
    }
}
elsif ( $object_type eq 'map' ) {
    my $attributes = $sql_object->get_attributes(
        cmap_object    => $cmap_admin,
        object_type    => 'map',
        get_all        => 1,
        attribute_name => $attribute_name,
    );
    my $maps = $sql_object->get_maps( cmap_object => $cmap_admin, );
    my %attr_lookup;
    for my $attr (@$attributes) {
        $attr_lookup{ $attr->{'object_id'} } = $attr->{'attribute_value'};
    }
    foreach my $map ( @{ $maps || [] } ) {
        if ( $attr_lookup{ $map->{'map_id'} } ) {
            print $map->{'map_acc'} . "\t"
                . $map->{'map_name'} . "\t"
                . $attr_lookup{ $map->{'map_id'} } . "\n";
        }
        else {
            print $map->{'map_acc'} . "\t"
                . $map->{'map_name'}
                . "\tMISSING\n";
        }
    }
}
elsif ( $object_type eq 'feature' ) {
    my $attributes = $sql_object->get_attributes(
        cmap_object    => $cmap_admin,
        object_type    => 'feature',
        get_all        => 1,
        attribute_name => $attribute_name,
    );
    my $features = $sql_object->get_features( cmap_object => $cmap_admin, );
    my %attr_lookup;
    for my $attr (@$attributes) {
        $attr_lookup{ $attr->{'object_id'} } = $attr->{'attribute_value'};
    }
    foreach my $feature ( @{ $features || [] } ) {
        if ( $attr_lookup{ $feature->{'feature_id'} } ) {
            print $feature->{'feature_acc'} . "\t"
                . $feature->{'feature_name'} . "\t"
                . $attr_lookup{ $feature->{'feature_id'} } . "\n";
        }
        else {
            print $feature->{'feature_acc'} . "\t"
                . $feature->{'feature_name'}
                . "\tMISSING\n";
        }
    }
}
elsif ( $object_type eq 'feature_type' ) {
    my $feature_type_data = $cmap_admin->feature_type_data();
    print STDERR "Feature Type Not Implemented Yet\n";
}
elsif ( $object_type eq 'evidence_type' ) {
    my $evidence_type_data = $cmap_admin->evidence_type_data();
    print STDERR "Evidence Type Not Implemented Yet\n";
}
elsif ( $object_type eq 'map_type' ) {
    my $map_type_data = $cmap_admin->map_type_data();
    print STDERR "Map Type Not Implemented Yet\n";
}

=pod

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.orgE<gt>.

=cut
