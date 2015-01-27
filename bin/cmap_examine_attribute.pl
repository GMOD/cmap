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

The goal of this script is to help look for a specific attribute that should be
on every object of the specified type (map set, feature, etc).  It examines the
CMap database and find all instances where the attribute should be.

It prints the value of the attribute if it exists for the object and a warning
if it is missing.

An example is if all map sets are supposed to have a "Description" attribute.
Running 

  $ ./cmap_examine_attribute.pl -d DATASOURCE -a "Description" -o "map_set"

would check to make sure all the map sets in the database have a Description
attribute and provide a list of those that were missing it.

If the attribute name has multiple values for a given object, only one will be
reported.

Prints results to standard out.

=head2 Recognized object types

=over 4

=item * species

=item * map_set

=item * map

=item * feature

=back

=cut

use strict;
use warnings;
use if $ENV{'CMAP_ROOT'}, lib => $ENV{'CMAP_ROOT'} . '/lib';
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
        object_type    => 'map_set',
        get_all        => 1,
        attribute_name => $attribute_name,
    );
    my $map_sets = $sql_object->get_map_sets();
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
        object_type    => 'species',
        get_all        => 1,
        attribute_name => $attribute_name,
    );
    my $species = $sql_object->get_species();
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
        object_type    => 'map',
        get_all        => 1,
        attribute_name => $attribute_name,
    );
    my $maps = $sql_object->get_maps();
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
        object_type    => 'feature',
        get_all        => 1,
        attribute_name => $attribute_name,
    );
    my $features = $sql_object->get_features();
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

=head1 COPYRIGHT

Copyright (c) 2006-7 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

