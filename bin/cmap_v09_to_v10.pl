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
my $fts = $db->selectall_arrayref(
    'select feature_type_id, description from cmap_feature_type',
    { Columns => {} }
);

print "Converting feature type descriptions (", scalar @$fts, ")\n";
for my $ft ( @$fts ) {
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
# cmap_correspondence_evidence.remarks => cmap_attribute
#
my $ce_remarks = $db->selectall_arrayref(
    q[
        select correspondence_evidence_id, remark 
        from   cmap_correspondence_evidence
        where  remarks is not null
    ],
    { Columns => {} }
);

print "Converting correspondence evidence remarks (", 
    scalar @$ce_remarks, ")\n";
for my $rem ( @$ce_remarks ) {
    $admin->set_attributes(
        object_id  => $rem->{'correspondence_evidence_id'},
        table_name => 'cmap_correspondence_evidence',
        attributes => [ 
            { name => 'Remarks', value => $rem->{'remark'}  } 
        ],
    ) or die $admin->error;
}

#
# cmap_feature.alternate_name => cmap_feature_alias
#
my $features = $db->selectall_arrayref(
    q[
        select feature_id, feature_name, alternate_name 
        from   cmap_feature 
        where  alternate_name is not null
    ],
    { Columns => {} }
);

print "Converting feature aliases (", scalar @$features, ")\n";
my $id = 1;
for my $f ( @$features ) {
    next unless defined $f->{'alternate_name'} && $f->{'alternate_name'} ne '';
    next if $f->{'feature_name'} eq $f->{'alternate_name'};

    $db->do(
        q[
            insert
            into   cmap_feature_alias2
                   (feature_alias_id, feature_id, alias)
            values (?, ?, ?)
        ],
        {},
        ( $id++, $f->{'feature_id'}, $f->{'alternate_name'} )
    );
}

$db->do(
    'insert into cmap_next_number (table_name, next_number) values (?, ?)',
    {},
    ( 'cmap_feature_alias', $id )
);

#
# DBXrefs
#
my $dbxrefs = $db->selectall_arrayref(
    q[
        select dbxref_id, map_set_id, feature_type_id, species_id, 
               dbxref_name, url
        from   cmap_dbxref
    ],
    { Columns => {} },
);

print "Converting generic dbxrefs (", scalar @$dbxrefs, ")\n";
my $feature_types = $db->selectall_hashref(
    'select feature_type_id, accession_id, feature_type from cmap_feature_type',
    'feature_type_id'
);

my @new_xrefs;
for my $dbxref ( @$dbxrefs ) {
    my $new_url = convert_xref(
        feature_type_id => $dbxref->{'feature_type_id'} ||  0,
        map_set_id      => $dbxref->{'map_set_id'}      ||  0,
        species_id      => $dbxref->{'species_id'}      ||  0,
        name            => $dbxref->{'dbxref_name'}     || '',
        url             => $dbxref->{'url'}             || '',
    ) or next;

    push @new_xrefs, { 
        name => $dbxref->{'dbxref_name'}, 
        url  => $new_url,
    };
}

if ( @new_xrefs ) {
    print "Creating ", scalar @new_xrefs, " new xrefs.\n";
    $admin->set_xrefs(
        table_name => 'cmap_feature',
        xrefs      => \@new_xrefs,
    ) or warn $admin->error;
}

my $dbxref_features = $db->selectall_arrayref(
    q[
        select feature_id, dbxref_name, dbxref_url 
        from   cmap_feature
    ],
    { Columns => {} }
);
print "Converting feature-specific dbxrefs (", scalar @$dbxref_features, ")\n";

for my $f ( @$dbxref_features ) {
    my $feature_id  = $f->{'feature_id'}  or next;
    my $name        = $f->{'dbxref_name'} or next;
    my $url         = $f->{'dbxref_url'}  or next;

    my $new_url     = convert_xref(
        feature_id  => $feature_id,
        name        => $name,
        url         => $url,
    ) or next;

#    if ( $name =~ /^not available$/i && $url eq '' ) {
#        ; # do nothing for now
#    }
#    elsif ( $name && $url ) {

    $admin->set_xrefs(
        table_name => 'cmap_feature',
        object_id => $feature_id, 
        xrefs      => [ { name => $name, url => $new_url } ] 
    ) or warn $admin->error;
}

#
# Species NCBI taxon id
#
my $species = $db->selectall_arrayref(
    q[
        select species_id, ncbi_taxon_id
        from   cmap_species
    ],
    { Columns => {} }
);
print "Converting species NCBI taxon ID (", scalar @$species , ")\n";

for my $s ( @$species  ) {
    my $species_id = $s->{'species_id'}    or next;
    my $taxon_id   = $s->{'ncbi_taxon_id'} or next;

    $admin->set_attributes(
        table_name => 'cmap_species',
        object_id  => $species_id,
        attributes => [ { name => 'NCBI Taxon ID', value => $taxon_id } ],
    ) or warn $admin->error;
}

print join("\n",
    'You may now drop the following:',
    "\tcmap_feature_type.description",
    "\tcmap_map_set.remarks",
    "\tcmap_feature.alternate_name",
    "\tcmap_feature.dbxref_name",
    "\tcmap_feature.dbxref_url",
    "\tcmap_feature_note",
    "\tcmap_dbxref",
    "\tcmap_species.ncbi_taxon_id",
);

print "\nDone\n";
exit(0);

#
# Subroutines start here.
#
#sub convert_xref {
#    my %args            = @_;
#    my $feature_type_id = $args{'feature_type_id'} || 0;
#    my $map_set_id      = $args{'map_set_id'}      || 0;
#    my $species_id      = $args{'species_id'}      || 0;
#    my $feature_id      = $args{'feature_id'}      || 0;
#    my $name            = $args{'name'}            || '';
#    my $url             = $args{'url'}             || '';
#    my $ft              = $feature_types->{ $feature_type_id };
#
#    $url =~ s#\[%\s*feature\.#\[% object.#g;
#    $url =~ s/accession_id/feature_aid/g;
#
#    if ( $url =~ m/alternate_name/ ) {
#        warn "DBXref '$name' uses deprecated 'alternate_name' column\n";
#        $url =~ s#\[% object\.alternate_name\s*#\[% a #g;
#        $url = '[% FOREACH a=object.aliases %]'.$url.' [% END %]';
#    }
#
#    my $new_url;
#    if ( $map_set_id ) {
#        my $map_set_aid = $db->selectrow_array(
#            'select accession_id from cmap_map_set where map_set_id=?',
#            {},
#            ( $map_set_id )
#        ) or next;
#
#        $new_url = 
#            '[% IF object.feature_type_aid==\'' . $ft->{'accession_id'} .
#            '\' AND object.map_set_aid==\'' . $map_set_aid . '\' %]'.
#            $url . '[% END %]'
#        ;
#    }
#    elsif ( $species_id ) {
#        my $species_aid = $db->selectrow_array(
#            'select accession_id from cmap_species where species_id=?',
#            {},
#            ( $species_id )
#        ) or next;
#
#        $new_url = 
#            '[% IF object.feature_type_aid==\'' . $ft->{'accession_id'} .
#            '\' AND object.species_aid==\'' . $species_aid . '\' %]'.
#            $url . '[% END %]'
#        ;
#    }
#    elsif ( $feature_id ) {
#        if ( $name =~ /^not available$/i ) {
#            $new_url = '';
#        }
#        else {
#            $new_url = $url;
#        }
#    }
#
#    return $new_url;
#}
