#!/usr/bin/perl

# $Id: cmap_data_diagnostics.pl,v 1.1 2006-12-28 18:07:22 mwz444 Exp $

=head1 NAME

cmap_data_diagnostics.pl - Check the data for problems

=head1 SYNOPSIS

  cmap_data_diagnostics.pl [options] 1> stats_file 2>error_file

Options:

  -d|--datasource=foo           CMap datasource
  -o|--report_optional          Report optional values that are missing

=head1 DESCRIPTION

This script will crawl through the main cmap data (species, map_set, map and
features) to look for any problems.

=cut

# ----------------------------------------------------

use strict;
use Data::Dumper;
use Bio::GMOD::CMap::Admin;
use Bio::GMOD::CMap::Drawer::Glyph;
use Getopt::Long;
use Pod::Usage;

use vars qw[ $VERSION ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;

my ( $help, $show_version, $data_source, $report_optional, );
GetOptions(
    'h|help'            => \$help,
    'v|version'         => \$show_version,
    'd|datasource:s'    => \$data_source,
    'o|report_optional' => \$report_optional,
);
pod2usage(2) if $help;

if ($show_version) {
    my $prog = basename($0);
    print "$prog v$VERSION\n";
    exit(0);
}

my %global_map_types;
my %global_feature_types;

my $cmap_admin = Bio::GMOD::CMap::Admin->new( data_source => $data_source, );

my $sql_object = $cmap_admin->sql();

my $species_list = $sql_object->get_species( cmap_object => $cmap_admin, );

if ( @{ $species_list || [] } ) {
    print "Number of Species: " . scalar(@$species_list) . "\n";
}
else {
    print "WARNING - No Species in the database.\n";
}

for my $species_data ( @{ $species_list || [] } ) {
    check_species($species_data);
}

check_map_types();

check_feature_types();

# -----------------------------------------------
sub check_species {

=pod

=head2 check_species 

Do the species check on the species data and then check the map sets.

=cut 

    my $species_data = shift;
    print "Species ID: " . $species_data->{'species_id'} . "\n";

    # String Columns
    foreach my $column_name (
        qw[
        species_acc       species_common_name
        species_full_name
        ]
        )
    {
        unless ( $species_data->{$column_name} ) {
            print STDERR "Species ID "
                . $species_data->{'species_id'}
                . ": $column_name is not filled\n";
        }
    }

    # Numeric Columns
    foreach my $column_name (
        qw[
        display_order
        ]
        )
    {
        unless ( defined( $species_data->{$column_name} ) ) {
            print STDERR "Species ID "
                . $species_data->{'species_id'}
                . ": $column_name is not defined\n";
        }
    }

    my $map_set_list = $sql_object->get_map_sets(
        cmap_object => $cmap_admin,
        species_id  => $species_data->{'species_id'},
    );

    if ( @{ $map_set_list || [] } ) {
        print "    Number of Map Sets: " . scalar(@$map_set_list) . "\n";
    }
    else {
        print "    WARNING - No Map Sets of this species.\n";
    }

    for my $map_set_data ( @{ $map_set_list || [] } ) {
        check_map_set($map_set_data);
    }
}

# -----------------------------------------------
sub check_map_set {

=pod

=head2 check_map_set 

Do the map_set check on the map_set data and then check the maps.

=cut 

    my $map_set_data = shift;
    print "    Map_Set ID: " . $map_set_data->{'map_set_id'} . "\n";

    # String Columns
    foreach my $column_name (
        qw[
        map_set_acc
        map_set_name
        map_set_short_name
        map_type_acc
        published_on
        map_units
        epoch_published_on
        ]
        )
    {
        unless ( $map_set_data->{$column_name} ) {
            print STDERR "Map Set ID "
                . $map_set_data->{'map_set_id'}
                . ": $column_name is not filled\n";
        }
    }
    $global_map_types{ $map_set_data->{'map_type_acc'} } = 1;

    # Numeric Columns
    foreach my $column_name (
        qw[
        is_relational_map
        map_set_display_order
        is_enabled
        ]
        )
    {
        unless ( defined( $map_set_data->{$column_name} ) ) {
            print STDERR "Map Set ID "
                . $map_set_data->{'map_set_id'}
                . ": $column_name is not defined\n";
        }
    }

    if ($report_optional) {

        # Optional String Columns
        foreach my $column_name (
            qw[
            shape
            color
            width
            ]
            )
        {
            unless ( $map_set_data->{$column_name} ) {
                print STDERR "OPTIONAL - Map Set ID "
                    . $map_set_data->{'map_set_id'}
                    . ": $column_name is not filled\n";
            }
        }
    }

    my $map_list = $sql_object->get_maps(
        cmap_object => $cmap_admin,
        map_set_id  => $map_set_data->{'map_set_id'},
    );

    if ( @{ $map_list || [] } ) {
        print "        Number of Maps: " . scalar(@$map_list) . "\n";
    }
    else {
        print "        WARNING - No Maps in this map set.\n";
    }

    for my $map_data ( @{ $map_list || [] } ) {
        check_map($map_data);
    }
}

# -----------------------------------------------
sub check_map {

=pod

=head2 check_map 

Do the map check on the map data and then check the features.

=cut 

    my $map_data = shift;
    print "        Map ID: " . $map_data->{'map_id'} . "\n";

    # String Columns
    foreach my $column_name (
        qw[
        map_acc
        map_name
        ]
        )
    {
        unless ( $map_data->{$column_name} ) {
            print STDERR "Map ID "
                . $map_data->{'map_id'}
                . ": $column_name is not filled\n";
        }
    }

    # Numeric Columns
    foreach my $column_name (
        qw[
        map_start
        map_stop
        display_order
        ]
        )
    {
        unless ( defined( $map_data->{$column_name} ) ) {
            print STDERR "Map ID "
                . $map_data->{'map_id'}
                . ": $column_name is not defined\n";
        }
    }

    if ($report_optional) {

        # Optional String Columns
        foreach my $column_name ( @{ [] } ) {
            unless ( $map_data->{$column_name} ) {
                print STDERR "OPTIONAL - Map ID "
                    . $map_data->{'map_id'}
                    . ": $column_name is not filled\n";
            }
        }
    }

    my $feature_list = $sql_object->get_features(
        cmap_object    => $cmap_admin,
        map_id         => $map_data->{'map_id'},
        ignore_aliases => 1,
    );

    if ( @{ $feature_list || [] } ) {
        print "            Number of Features: "
            . scalar(@$feature_list) . "\n";
    }
    else {
        print "            WARNING - No Features on this map.\n";
    }

    for my $feature_data ( @{ $feature_list || [] } ) {
        check_feature($feature_data);
    }
}

# -----------------------------------------------
sub check_feature {

=pod

=head2 check_feature 

Do the feature check on the feature data 

=cut 

    my $feature_data = shift;

    # String Columns
    foreach my $column_name (
        qw[
        feature_acc
        feature_type_acc
        feature_name
        direction
        map_id
        ]
        )
    {
        unless ( $feature_data->{$column_name} ) {
            print STDERR "Feature ID "
                . $feature_data->{'feature_id'}
                . ": $column_name is not filled\n";
        }
    }
    $global_feature_types{ $feature_data->{'feature_type_acc'} } = 1;

    # Numeric Columns
    foreach my $column_name (
        qw[
        feature_start
        feature_stop
        ]
        )
    {
        unless ( defined( $feature_data->{$column_name} ) ) {
            print STDERR "Feature ID "
                . $feature_data->{'feature_id'}
                . ": $column_name is not defined\n";
        }
    }

    if ($report_optional) {

        # Optional Numeric Columns
        foreach my $column_name (
            qw[
            is_landmark
            ]
            )
        {
            unless ( defined( $feature_data->{$column_name} ) ) {
                print STDERR "OPTIONAL - Feature ID "
                    . $feature_data->{'feature_id'}
                    . ": $column_name is not filled\n";
            }
        }
    }
}

# -----------------------------------------------
sub check_map_types {

=pod

=head2 check_map_types 

Do the map_types check on the map_types data 

=cut 

    my $map_type_data = $cmap_admin->map_type_data();

    foreach my $map_type_acc ( keys %global_map_types ) {
        next unless ($map_type_acc);    # Guard against blank entries
        my $current_type_data;
        unless ( $current_type_data = $map_type_data->{$map_type_acc} ) {
            print STDERR
                "Map Type $map_type_acc is NOT defined in the config file\n";
            next;
        }

        # String Columns
        foreach my $column_name (
            qw[
            map_type_acc
            map_type
            map_units
            ]
            )
        {
            unless ( $current_type_data->{$column_name} ) {
                print STDERR "Map Type Acc $map_type_acc"
                    . ": $column_name is not filled\n";
            }
        }

        # Numeric Columns
        foreach my $column_name (
            qw[
            unit_granularity
            ]
            )
        {
            unless ( defined( $current_type_data->{$column_name} ) ) {
                print STDERR "Map Type Acc $map_type_acc"
                    . ": $column_name is not defined\n";
            }
        }

        if ($report_optional) {

            # Optional String Columns
            foreach my $column_name (
                qw[
                feature_default_display
                area_code
                shape
                width
                color
                ]
                )
            {
                unless ( $current_type_data->{$column_name} ) {
                    print STDERR "OPTIONAL - Map Type Acc $map_type_acc"
                        . ": $column_name is not filled\n";
                }
            }

            # Optional Numeric Columns
            foreach my $column_name (
                qw[
                display_order
                ]
                )
            {
                unless ( defined( $current_type_data->{$column_name} ) ) {
                    print STDERR "OPTIONAL - Map Type Acc $map_type_acc"
                        . ": $column_name is not filled\n";
                }
            }
        }
    }
}

# -----------------------------------------------
sub check_feature_types {

=pod

=head2 check_feature_types 

Do the feature_types check on the feature_types data 

=cut 

    my $feature_type_data = $cmap_admin->feature_type_data();

    foreach my $feature_type_acc ( keys %global_feature_types ) {
        next unless ($feature_type_acc);    # Guard against blank entries
        my $current_type_data;
        unless ( $current_type_data = $feature_type_data->{$feature_type_acc} ) {
            print STDERR
                "Feature Type $feature_type_acc is NOT defined in the config file\n";
            next;
        }

        # String Columns
        foreach my $column_name (
            qw[
            feature_type_acc
            feature_type
            ]
            )
        {
            unless ( $current_type_data->{$column_name} ) {
                print STDERR "Feature Type Acc $feature_type_acc"
                    . ": $column_name is not filled\n";
            }
        }

        # Check the viability of the shape
        my $glyph         = Bio::GMOD::CMap::Drawer::Glyph->new();
        my $feature_glyph = $current_type_data->{'shape'};
        $feature_glyph =~ s/-/_/g;
        if ( $feature_glyph and not $glyph->can($feature_glyph) ) {
            print STDERR "Feature Type Acc $feature_type_acc"
                . ": ".$current_type_data->{'shape'}." is not a valid shape\n";
        }

        # Numeric Columns
        foreach my $column_name (
            qw[
            ]
            )
        {
            unless ( defined( $current_type_data->{$column_name} ) ) {
                print STDERR "Feature Type Acc $feature_type_acc"
                    . ": $column_name is not defined\n";
            }
        }

        if ($report_optional) {

            # Optional String Columns
            foreach my $column_name (
                qw[
                feature_default_display
                color
                area_code
                shape
                ]
                )
            {
                unless ( $current_type_data->{$column_name} ) {
                    print STDERR "OPTIONAL - Feature Type Acc $feature_type_acc"
                        . ": $column_name is not filled\n";
                }
            }

            # Optional Numeric Columns
            foreach my $column_name (
                qw[
                default_rank
                drawing_lane
                drawing_priority
                ]
                )
            {
                unless ( defined( $current_type_data->{$column_name} ) ) {
                    print STDERR "OPTIONAL - Feature Type Acc $feature_type_acc"
                        . ": $column_name is not filled\n";
                }
            }
        }
    }
}

# ----------------------------------------------------

=pod

=head1 SEE ALSO

Bio::GMOD::CMap.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

=cut

