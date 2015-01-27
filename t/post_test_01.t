#!/usr/bin/perl
# vim: set ft=perl:
#

use strict;

use Data::Dumper;

#use Test::More tests => 8;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Test::More qw(no_plan);
use Bio::GMOD::CMap::Admin::Interactive;
use File::Spec::Functions qw( catfile );
use DBI::Const::GetInfoType;

my @wipe_species_fields = qw[ species_id ];
my @wipe_map_set_fields = qw[
    species_id          published_on
    epoch_published_on  map_set_id
];
my @wipe_map_fields = qw[
    species_id          published_on
    epoch_published_on  map_set_id
    map_id
];
my @wipe_feature_fields = qw[
    species_id          published_on
    epoch_published_on  map_set_id
    map_id              feature_id
];
my @wipe_corr_fields = qw[
    feature_id1     feature_id2
    species_id2     species_acc2
    map_set_id2     map_id2
    published_on2   feature_correspondence_id
    feature_correspondence_acc
];
my @wipe_matrix_fields = qw[];

my $interactive = Bio::GMOD::CMap::Admin::Interactive->new(
    user       => $>,                         # effective UID
    no_log     => 1,
    datasource => 'CMAP_POST_INSTALL_TEST',

    #config_dir => $config_dir,
);
my $sql_object = $interactive->sql();
my $driver = $sql_object->db->get_info($GetInfoType{SQL_DBMS_NAME});
# ----------------------------------------------
### Return Objects
my $get_species_return = [
    {   'display_order'       => '1',
        'species_full_name'   => 'species_full_name1',
        'species_common_name' => 'species_common_name1',
        'species_acc'         => 'species_acc1',
    }
];
my $get_map_sets_return = [
    {   'width'                  => '5',
        'map_units'              => 'bp',
        'species_display_order'  => '1',
        'map_set_display_order'  => '1',
        'map_type_acc'           => 'Seq',
        'color'                  => 'red',
        'is_relational_map'      => '0',
        'map_set_name'           => 'map_set_name1',
        'map_type'               => 'Sequence',
        'map_type_display_order' => '1',
        'is_enabled'             => '1',
        'map_set_acc'            => 'map_set_acc1',
        'species_common_name'    => 'species_common_name1',
        'species_full_name'      => 'species_full_name1',
        'shape'                  => 'box',
        'map_set_short_name'     => 'map_set_short_name1',
        'species_acc'            => 'species_acc1'
    }
];

my $get_maps_return1 = [
    {   'width'                  => '5',
        'map_units'              => 'bp',
        'default_width'          => '1',
        'default_color'          => undef,
        'default_shape'          => 'box',
        'map_type_acc'           => 'Seq',
        'color'                  => 'red',
        'is_relational_map'      => '0',
        'map_set_name'           => 'map_set_name1',
        'map_type'               => 'Sequence',
        'map_type_display_order' => '1',
        'map_name'               => 'T1',
        'display_order'          => '1',
        'map_set_acc'            => 'map_set_acc1',
        'map_stop'               => ($driver eq 'SQLite') ? '1000' : '1000.00',
        'map_start'              => ($driver eq 'SQLite') ? '0' : '0.00',
        'species_full_name'      => 'species_full_name1',
        'species_common_name'    => 'species_common_name1',
        'map_acc'                => 'T1',
        'shape'                  => 'box',
        'map_set_short_name'     => 'map_set_short_name1',
        'species_acc'            => 'species_acc1'
    }
];

my $get_features_return1 = [
    {   'map_units'           => 'bp',
        'feature_acc'         => 'T1.1',
        'feature_type'        => 'Contig',
        'map_type_acc'        => 'Seq',
        'feature_stop'        => ($driver eq 'SQLite') ? '1000' : '1000.00',
        'direction'           => '1',
        'feature_type_acc'    => 'contig',
        'is_relational_map'   => '0',
        'is_landmark'         => '0',
        'map_set_name'        => 'map_set_name1',
        'map_type'            => 'Sequence',
        'map_name'            => 'T1',
        'map_set_acc'         => 'map_set_acc1',
        'map_stop'            => ($driver eq 'SQLite') ? '1000' : '1000.00',
        'map_start'           => ($driver eq 'SQLite') ? '0' : '0.00',
        'default_rank'        => '1',
        'feature_start'       => ($driver eq 'SQLite') ? '0' : '0.00',
        'species_common_name' => 'species_common_name1',
        'map_acc'             => 'T1',
        'aliases'             => [ 'F1.A', 'F1.AA' ],
        'feature_name'        => 'F1',
        'map_set_short_name'  => 'map_set_short_name1',
        'species_acc'         => 'species_acc1'
    },
    {   'map_units'           => 'bp',
        'feature_acc'         => 'T1.2',
        'feature_type'        => 'Read',
        'map_type_acc'        => 'Seq',
        'feature_stop'        => ($driver eq 'SQLite') ? '500' : '500.00',
        'direction'           => '1',
        'feature_type_acc'    => 'read',
        'is_relational_map'   => '0',
        'is_landmark'         => '0',
        'map_set_name'        => 'map_set_name1',
        'map_type'            => 'Sequence',
        'map_name'            => 'T1',
        'map_set_acc'         => 'map_set_acc1',
        'map_stop'            => ($driver eq 'SQLite') ? '1000' : '1000.00',
        'map_start'           => ($driver eq 'SQLite') ? '0' : '0.00',
        'default_rank'        => '2',
        'feature_start'       => ($driver eq 'SQLite') ? '0' : '0.00',
        'species_common_name' => 'species_common_name1',
        'map_acc'             => 'T1',
        'aliases'             => ['R1.g1.A'],
        'feature_name'        => 'R1.g1',
        'map_set_short_name'  => 'map_set_short_name1',
        'species_acc'         => 'species_acc1'
    }
];

my $get_corrs_return0 = [
    {   'feature_acc1'           => 'T1.2',
        'feature_start2'         => ($driver eq 'SQLite') ? '0' : '0.00',
        'map_units2'             => 'bp',
        'map_set_short_name2'    => 'map_set_short_name2',
        'feature_acc2'           => 'T2.4',
        'ms_display_order2'      => '1',
        'map_acc2'               => 'T2',
        'evidence_type'          => 'Automated name-based 3',
        'map_display_order2'     => '1',
        'feature_type_acc1'      => 'read',
        'feature_type2'          => 'Read',
        'is_enabled'             => '1',
        'feature_type_acc2'      => 'read',
        'species_common_name2'   => 'species_common_name1',
        'score'                  => undef,
        'evidence_type_acc'      => 'ANB3',
        'map_set_acc2'           => 'map_set_acc2',
        'species_display_order2' => '1',
        'map_type2'              => 'Sequence',
        'feature_type1'          => 'Read',
        'feature_stop2'          => ($driver eq 'SQLite') ? '500' : '500.00',
        'feature_name2'          => 'R1.b1',
        'map_name2'              => 'T2',
        'map_type_acc2'          => 'Seq'
    }
];

my $get_corrs_return1 = [
    {   'feature_acc1'           => 'T1.1',
        'feature_start2'         => ($driver eq 'SQLite') ? '0' : '0.00',
        'map_units2'             => 'bp',
        'map_set_short_name2'    => 'map_set_short_name2',
        'feature_acc2'           => 'T2.1',
        'ms_display_order2'      => '1',
        'map_acc2'               => 'T2',
        'evidence_type'          => 'Automated name-based',
        'map_display_order2'     => '1',
        'feature_type_acc1'      => 'contig',
        'feature_type2'          => 'Contig',
        'is_enabled'             => '1',
        'feature_type_acc2'      => 'contig',
        'species_common_name2'   => 'species_common_name1',
        'score'                  => undef,
        'evidence_type_acc'      => 'ANB',
        'map_set_acc2'           => 'map_set_acc2',
        'species_display_order2' => '1',
        'map_type2'              => 'Sequence',
        'feature_type1'          => 'Contig',
        'feature_stop2'          => ($driver eq 'SQLite') ? '1000' : '1000.00',
        'feature_name2'          => 'F1',
        'map_name2'              => 'T2',
        'map_type_acc2'          => 'Seq'
    },
    {   'feature_acc1'           => 'T1.1',
        'feature_start2'         => ($driver eq 'SQLite') ? '1000' : '1000.00',
        'map_units2'             => 'bp',
        'map_set_short_name2'    => 'map_set_short_name2',
        'feature_acc2'           => 'T2.2',
        'ms_display_order2'      => '1',
        'map_acc2'               => 'T2',
        'evidence_type'          => 'Automated name-based',
        'map_display_order2'     => '1',
        'feature_type_acc1'      => 'contig',
        'feature_type2'          => 'Contig',
        'is_enabled'             => '1',
        'feature_type_acc2'      => 'contig',
        'species_common_name2'   => 'species_common_name1',
        'score'                  => undef,
        'evidence_type_acc'      => 'ANB',
        'map_set_acc2'           => 'map_set_acc2',
        'species_display_order2' => '1',
        'map_type2'              => 'Sequence',
        'feature_type1'          => 'Contig',
        'feature_stop2'          => ($driver eq 'SQLite') ? '2000' : '2000.00',
        'feature_name2'          => 'F1.A',
        'map_name2'              => 'T2',
        'map_type_acc2'          => 'Seq'
    }
];

my $get_corrs_return2 = [
    {   'feature_acc1'           => 'T1.1',
        'feature_start2'         => ($driver eq 'SQLite') ? '0' : '0.00',
        'map_units2'             => 'bp',
        'map_set_short_name2'    => 'map_set_short_name2',
        'feature_acc2'           => 'T2.1',
        'ms_display_order2'      => '1',
        'map_acc2'               => 'T2',
        'evidence_type'          => 'Automated name-based',
        'map_display_order2'     => '1',
        'feature_type_acc1'      => 'contig',
        'feature_type2'          => 'Contig',
        'is_enabled'             => '1',
        'feature_type_acc2'      => 'contig',
        'species_common_name2'   => 'species_common_name1',
        'score'                  => undef,
        'evidence_type_acc'      => 'ANB',
        'map_set_acc2'           => 'map_set_acc2',
        'species_display_order2' => '1',
        'map_type2'              => 'Sequence',
        'feature_type1'          => 'Contig',
        'feature_stop2'          => ($driver eq 'SQLite') ? '1000' : '1000.00',
        'feature_name2'          => 'F1',
        'map_name2'              => 'T2',
        'map_type_acc2'          => 'Seq'
    },
    {   'feature_acc1'           => 'T1.1',
        'feature_start2'         => ($driver eq 'SQLite') ? '0' : '0.00',
        'map_units2'             => 'bp',
        'map_set_short_name2'    => 'map_set_short_name2',
        'feature_acc2'           => 'T2.1',
        'ms_display_order2'      => '1',
        'map_acc2'               => 'T2',
        'evidence_type'          => 'Automated name-based',
        'map_display_order2'     => '1',
        'feature_type_acc1'      => 'contig',
        'feature_type2'          => 'Contig',
        'is_enabled'             => '1',
        'feature_type_acc2'      => 'contig',
        'species_common_name2'   => 'species_common_name1',
        'score'                  => undef,
        'evidence_type_acc'      => 'ANB',
        'map_set_acc2'           => 'map_set_acc2',
        'species_display_order2' => '1',
        'map_type2'              => 'Sequence',
        'feature_type1'          => 'Contig',
        'feature_stop2'          => ($driver eq 'SQLite') ? '1000' : '1000.00',
        'feature_name2'          => 'F1',
        'map_name2'              => 'T2',
        'map_type_acc2'          => 'Seq'
    },
    {   'feature_acc1'           => 'T1.1',
        'feature_start2'         => ($driver eq 'SQLite') ? '1000' : '1000.00',
        'map_units2'             => 'bp',
        'map_set_short_name2'    => 'map_set_short_name2',
        'feature_acc2'           => 'T2.2',
        'ms_display_order2'      => '1',
        'map_acc2'               => 'T2',
        'evidence_type'          => 'Automated name-based',
        'map_display_order2'     => '1',
        'feature_type_acc1'      => 'contig',
        'feature_type2'          => 'Contig',
        'is_enabled'             => '1',
        'feature_type_acc2'      => 'contig',
        'species_common_name2'   => 'species_common_name1',
        'score'                  => undef,
        'evidence_type_acc'      => 'ANB',
        'map_set_acc2'           => 'map_set_acc2',
        'species_display_order2' => '1',
        'map_type2'              => 'Sequence',
        'feature_type1'          => 'Contig',
        'feature_stop2'          => ($driver eq 'SQLite') ? '2000' : '2000.00',
        'feature_name2'          => 'F1.A',
        'map_name2'              => 'T2',
        'map_type_acc2'          => 'Seq'
    },
    {   'feature_acc1'           => 'T1.1',
        'feature_start2'         => ($driver eq 'SQLite') ? '1000' : '1000.00',
        'map_units2'             => 'bp',
        'map_set_short_name2'    => 'map_set_short_name2',
        'feature_acc2'           => 'T2.2',
        'ms_display_order2'      => '1',
        'map_acc2'               => 'T2',
        'evidence_type'          => 'Automated name-based',
        'map_display_order2'     => '1',
        'feature_type_acc1'      => 'contig',
        'feature_type2'          => 'Contig',
        'is_enabled'             => '1',
        'feature_type_acc2'      => 'contig',
        'species_common_name2'   => 'species_common_name1',
        'score'                  => undef,
        'evidence_type_acc'      => 'ANB',
        'map_set_acc2'           => 'map_set_acc2',
        'species_display_order2' => '1',
        'map_type2'              => 'Sequence',
        'feature_type1'          => 'Contig',
        'feature_stop2'          => ($driver eq 'SQLite') ? '2000' : '2000.00',
        'feature_name2'          => 'F1.A',
        'map_name2'              => 'T2',
        'map_type_acc2'          => 'Seq'
    }
];

my $get_corrs_return3 = [
    {   'feature_acc1'           => 'T1.2',
        'feature_start2'         => ($driver eq 'SQLite') ? '0' : '0.00',
        'map_units2'             => 'bp',
        'map_set_short_name2'    => 'map_set_short_name2',
        'feature_acc2'           => 'T2.4',
        'ms_display_order2'      => '1',
        'map_acc2'               => 'T2',
        'evidence_type'          => 'Automated name-based 2',
        'map_display_order2'     => '1',
        'feature_type_acc1'      => 'read',
        'feature_type2'          => 'Read',
        'is_enabled'             => '1',
        'feature_type_acc2'      => 'read',
        'species_common_name2'   => 'species_common_name1',
        'score'                  => undef,
        'evidence_type_acc'      => 'ANB2',
        'map_set_acc2'           => 'map_set_acc2',
        'species_display_order2' => '1',
        'map_type2'              => 'Sequence',
        'feature_type1'          => 'Read',
        'feature_stop2'          => ($driver eq 'SQLite') ? '500' : '500.00',
        'feature_name2'          => 'R1.b1',
        'map_name2'              => 'T2',
        'map_type_acc2'          => 'Seq'
    }
];

my $get_matrix_return = [
    {   'reference_species_acc' => 'species_acc1',
        'correspondences'       => '3',
        'map_count'             => '1',
        'link_map_set_acc'      => 'map_set_acc2',
        'reference_map_set_acc' => 'map_set_acc1',
        'link_species_acc'      => 'species_acc1'
    },
    {   'reference_species_acc' => 'species_acc1',
        'correspondences'       => '3',
        'map_count'             => '1',
        'link_map_set_acc'      => 'map_set_acc1',
        'reference_map_set_acc' => 'map_set_acc2',
        'link_species_acc'      => 'species_acc1'
    }
];

# -----------------------------------------------------------------------
### Species Creation
my $species_id;
ok( $species_id = $interactive->create_species(
        species_common_name => 'species_common_name1',
        species_full_name   => 'species_full_name1',
        command_line        => 1,
        species_acc         => 'species_acc1',
    ),
    "Testing create_species"
);

my $actual_get_species_return
    = $sql_object->get_species( species_id => $species_id, );

wipe_fields_from_array_ref( $actual_get_species_return, @wipe_species_fields,
);

is_deeply( $actual_get_species_return, $get_species_return,
    'Get Species Check' );

# -----------------------------------------------------------------------
### Map Set Creation
my $map_set_id1;
ok( $map_set_id1 = $interactive->create_map_set(
        map_set_acc        => 'map_set_acc1',
        command_line       => 1,
        map_color          => 'red',
        map_width          => '5',
        map_type_acc       => 'Seq',
        species_id         => $species_id,
        map_set_name       => 'map_set_name1',
        map_set_short_name => 'map_set_short_name1',
        map_shape          => 'box',
    ),
    "Testing create_map_set"
);

my $map_set_id2;
ok( $map_set_id2 = $interactive->create_map_set(
        map_set_acc        => 'map_set_acc2',
        command_line       => 1,
        map_color          => 'red',
        map_width          => '5',
        map_type_acc       => 'Seq',
        species_id         => $species_id,
        map_set_name       => 'map_set_name2',
        map_set_short_name => 'map_set_short_name2',
        map_shape          => 'box',
    ),
    "Testing create_map_set"
);

my $actual_get_map_sets_return
    = $sql_object->get_map_sets( map_set_id => $map_set_id1, );
wipe_fields_from_array_ref( $actual_get_map_sets_return, @wipe_map_set_fields,
);

is_deeply( $actual_get_map_sets_return, $get_map_sets_return,
    'Get Map Set Check' );

# -----------------------------------------------------------------------
### Import tab to populate map set 1
ok( $interactive->import_tab_data(
        allow_update => 0,
        map_set_acc  => 'map_set_acc1',
        command_line => 1,
        overwrite    => 0,
        file_str     => catfile( 't', 'test_data', 'tab_data1' ),
        quiet        => 1,
    ),
    "Testing import_tab_data"
);

my $actual_get_maps_return1
    = $sql_object->get_maps( map_set_id => $map_set_id1, );
my $map_id1 = $actual_get_maps_return1->[0]{'map_id'};
wipe_fields_from_array_ref( $actual_get_maps_return1, @wipe_map_fields, );

is_deeply( $actual_get_maps_return1, $get_maps_return1, 'Get Map Check' );

my $actual_get_features_return1
    = $sql_object->get_features( map_id => $map_id1, );
wipe_fields_from_array_ref( $actual_get_features_return1,
    @wipe_feature_fields, );
is_deeply( $actual_get_features_return1, $get_features_return1,
    'Get Feature Check' );

# -----------------------------------------------------------------------
### Import tab to populate map set 2
ok( $interactive->import_tab_data(
        allow_update => 0,
        map_set_acc  => 'map_set_acc2',
        command_line => 1,
        overwrite    => 0,
        file_str     => catfile( 't', 'test_data', 'tab_data2' ),
        quiet        => 1,
    ),
    "Testing import_tab_data 2"
);

# -----------------------------------------------------------------------
### Import Corrs (feature aliases)
ok( $interactive->import_correspondences(
        map_set_accs => 'map_set_acc1,map_set_acc2',
        command_line => 1,
        file_str     => catfile( 't', 'test_data', 'tab_corrs_aliases' ),
    ),
    'Testing import_correspondences (feature aliases)'
);

my $actual_get_corrs_return0
    = $sql_object->get_feature_correspondence_details(
    map_id1                     => $map_id1,
    included_evidence_type_accs => ['ANB3'],
    );
wipe_fields_from_array_ref( $actual_get_corrs_return0, @wipe_corr_fields, );
is_deeply( $actual_get_corrs_return0, $get_corrs_return0,
    'Get Correspondence Check import (feature aliases)' );
# -----------------------------------------------------------------------
### Import Corrs (feature names)
ok( $interactive->import_correspondences(
        map_set_accs => 'map_set_acc1,map_set_acc2',
        command_line => 1,
        file_str     => catfile( 't', 'test_data', 'tab_corrs1' ),
    ),
    'Testing import_correspondences (feature names)'
);

my $actual_get_corrs_return1
    = $sql_object->get_feature_correspondence_details(
    map_id1                     => $map_id1,
    included_evidence_type_accs => ['ANB'],
    );
wipe_fields_from_array_ref( $actual_get_corrs_return1, @wipe_corr_fields, );
is_deeply( $actual_get_corrs_return1, $get_corrs_return1,
    'Get Correspondence Check import (feature names)' );

# -----------------------------------------------------------------------
### Make Corrs
ok( $interactive->make_name_correspondences(
        command_line           => 1,
        allow_update           => 0,
        from_map_set_accs      => 'map_set_acc1',
        to_map_set_accs        => 'map_set_acc2',
        evidence_type_acc      => 'ANB',
        skip_feature_type_accs => 'marker',
        name_regex             => 'exact_match',
        quiet                  => 1,
    ),
    "Testing Make Correspondences exact_match"
);

my $actual_get_corrs_return2
    = $sql_object->get_feature_correspondence_details(
    map_id1                     => $map_id1,
    included_evidence_type_accs => ['ANB'],
    );

wipe_fields_from_array_ref( $actual_get_corrs_return2, @wipe_corr_fields, );
is_deeply( $actual_get_corrs_return2, $get_corrs_return2,
    'Get Correspondence Check exact match' );

ok( $interactive->make_name_correspondences(
        command_line           => 1,
        allow_update           => 0,
        from_map_set_accs      => 'map_set_acc1',
        to_map_set_accs        => 'map_set_acc2',
        evidence_type_acc      => 'ANB2',
        skip_feature_type_accs => 'marker,contig',
        name_regex             => 'read_pair',
        quiet                  => 1,
    ),
    "Testing Make Correspondences read_pair"
);
my $actual_get_corrs_return3
    = $sql_object->get_feature_correspondence_details(
    map_id1                     => $map_id1,
    included_evidence_type_accs => ['ANB2'],
    );
wipe_fields_from_array_ref( $actual_get_corrs_return3, @wipe_corr_fields, );
is_deeply( $actual_get_corrs_return3, $get_corrs_return3,
    'Get Correspondence Check read_pair' );

# -----------------------------------------------------------------------
### Delete Duplicate Corrs
ok( $interactive->delete_duplicate_correspondences(
        command_line => 1,
        map_set_acc  => 'map_set_acc1',
    ),
    'Testing delete_duplicate_correspondences'
);

my $actual_get_corrs_return4
    = $sql_object->get_feature_correspondence_details(
    map_id1                     => $map_id1,
    included_evidence_type_accs => ['ANB'],
    );
wipe_fields_from_array_ref( $actual_get_corrs_return4, @wipe_corr_fields, );
is_deeply( $actual_get_corrs_return4, $get_corrs_return1,
    'Get Correspondence Check delete_duplicate' );

# -----------------------------------------------------------------------
### Reload the Matrix
ok( $interactive->reload_correspondence_matrix( command_line => '1', ),
    'Testing reload_correspondence_matrix' );

my $actual_get_matrix_return = $sql_object->get_matrix_relationships();
wipe_fields_from_array_ref( $actual_get_matrix_return, @wipe_matrix_fields, );
is_deeply( $actual_get_matrix_return, $get_matrix_return, 'Matrix Check' );

# -----------------------------------------------------------------------
### Export text file
ok( $interactive->export_as_text(
        map_set_accs => 'map_set_acc1',
        command_line => '1',
        directory    => 't/test_data',

        #feature_type_accs => '',
        #exclude_fields => '',
        #map_type_acc => '',
        #species_acc => '',
    ),
    'Testing export_as_text'
);

# -----------------------------------------------------------------------
### Export sql file
ok( $interactive->export_as_sql(
        tables       => 'all',
        export_file  => 't/test_data/export_sql',
        command_line => '1',
        add_truncate => '1',
        quote_escape => 'backslash',
    ),
    'Testing export_as_sql'
);

# -----------------------------------------------------------------------
### Delete Map Set
foreach my $vals ( [ $map_set_id1, 'map_set_acc1' ],
    [ $map_set_id2, 'map_set_acc2' ] )
{
    my $map_set_id  = $vals->[0];
    my $map_set_acc = $vals->[1];
    ok( $interactive->delete_maps(
            map_set_acc  => $map_set_acc,
            command_line => 1,
        ),
        "Testing delete_maps"
    );
    is_deeply( $sql_object->get_map_sets( map_set_id => $map_set_id, ),
        [], 'Delete Map Set Check' );
}

# -----------------------------------------------------------------------
### Delete species
ok( $sql_object->delete_species( species_id => $species_id, ),
    "Testing delete_species" );
is_deeply( $sql_object->get_species( species_id => $species_id, ),
    [], 'Delete Species Check' );

# -----------------------------------------------------------------------
sub wipe_fields_from_array_ref {

    my $array_ref = shift;
    my @fields    = @_;
    foreach my $row ( @{ $array_ref || [] } ) {
        foreach my $field (@fields) {
            delete $row->{$field};
        }
    }
}
