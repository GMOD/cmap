#!/usr/bin/perl

=head1 NAME 

cmap_09_to_10.pl

=head1 SYNOPSIS

  cmap_09_to_10.pl [options] [-d data_source]

Options:

  -h|--help    Show brief help

=head1 DESCRIPTION

Converts data in CMap version 0.09 to 0.10.  This is a non-destructive
conversion -- data will only be added into the new tables and nothing will
be deleted.  You must create the new tables "cmap_attribute" and
"cmap_feature_alias" before running this script.

=cut

use strict;
use Getopt::Long;
use Pod::Usage;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Admin;

my ( $ds, $help );
GetOptions(
    'd:s'    => \$ds,
    'h|help' => \$help,
) or pod2usage;
pod2usage(1) if $help;

my $cmap = Bio::GMOD::CMap->new or die Bio::GMOD::CMap->error;
if ( $ds ) {
    $cmap->data_source( $ds ) or die $cmap->error;
}
my $db = $cmap->db;

my $admin = Bio::GMOD::CMap::Admin->new( data_source => $cmap->data_source );

#
# cmap_feature_note => cmap_attribute
#
my $feature_notes = $db->selectall_arrayref(
    'select feature_id, note from cmap_feature_note',
    { Columns => {} }
);

print "Converting feature notes (", scalar @$feature_notes, ")\n";
for my $note ( @$feature_notes ) {
    $admin->set_attributes(
        object_id  => $note->{'feature_id'},
        table_name => 'cmap_feature',
        attributes => [ { name => 'Note', value => $note->{'note'}  } ],
    ) or die $admin->error;
}

#
# cmap_feature_type.description => cmap_attribute
#
my $feature_types = $db->selectall_arrayref(
    'select feature_type_id, description from cmap_feature_type',
    { Columns => {} }
);

print "Converting feature type descriptions (", scalar @$feature_types, ")\n";
for my $ft ( @$feature_types ) {
    $admin->set_attributes(
        object_id  => $ft->{'feature_type_id'},
        table_name => 'cmap_feature_type',
        attributes => [ 
            { name => 'Description', value => $ft->{'description'}  } 
        ],
    ) or die $admin->error;
}

#
# cmap_map_set.remarks => cmap_attribute
#
my $ms_remarks = $db->selectall_arrayref(
    'select map_set_id, remarks from cmap_map_set where remarks is not null',
    { Columns => {} }
);

print "Converting map set remarks (", scalar @$ms_remarks, ")\n";
for my $rem ( @$ms_remarks ) {
    $admin->set_attributes(
        object_id  => $rem->{'map_set_id'},
        table_name => 'cmap_map_set',
        attributes => [ 
            { name => 'Description', value => $rem->{'remarks'}  } 
        ],
    ) or die $admin->error;
}

#
# cmap_feature.alternate_name => cmap_feature_alias
#
my $features = $db->selectall_arrayref(
    q[
        select feature_id, alternate_name 
        from   cmap_feature 
        where  alternate_name is not null
    ],
    { Columns => {} }
);

print "Converting feature aliases (", scalar @$features, ")\n";
for my $f ( @$features ) {
    next unless defined $f->{'alternate_name'} && $f->{'alternate_name'} ne '';

    $db->do(
        'insert into cmap_feature_alias (feature_id, alias) values (?, ?)',
        {},
        ( $f->{'feature_id'}, $f->{'alternate_name'} )
    );
}

print join("\n",
    'You may now drop the following:',
    "\tcmap_feature_type.description",
    "\tcmap_map_set.remarks",
    "\tcmap_feature.alternate_name",
    "\tcmap_feature_note"
);

print "\nDone\n";
