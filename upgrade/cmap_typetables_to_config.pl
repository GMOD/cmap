#!/usr/bin/perl -w

# $Id: cmap_typetables_to_config.pl,v 1.4 2004-12-15 20:07:54 mwz444 Exp $

=pod

=head1 NAME

cmap_typetables_to_config.pl - create config for "cmap_*_type" tables

=head1 SYNOPSIS

  cmap_typetables_to_config.pl <cmap-conf-file-or-dir> [...]

=head1 DESCRIPTION

This script queries the "cmap_*_type" tables (e.g., "cmap_map_type")
used in CMap versions 0.12 and less and converts this information to
the config file format.  After running this script, you may choose to 
drop these tables from your schema (but be sure you backed up your
database first!).  

The script accepts multiple arguments, each of which may be a directory 
where the config files exist (in which case every file in the
directory ending in ".conf" will be processed with the exception of
the "global.conf" file) or a file path.  Each file processed will be
examined for the database connection information, then that database
will be queried for the "*_type" tables, and this information will be
appended to the configuration file.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>, 
Ken Youens-Clark E<lt>kclark@cshl.eduE<gt>.

=cut

# -------------------------------------------------------

use strict;
use Config::General;
use DBI;
use File::Spec::Functions;
use Getopt::Long;
use Pod::Usage;

my ($help);
GetOptions( 'help|h|?' => \$help, ) or pod2usage;

pod2usage(0) if $help;

pod2usage('No arguments') unless @ARGV;

my @configs;
for my $arg (@ARGV) {
    if ( -d $arg ) {
        opendir DIR, $arg;
        push @configs, map { catfile( $arg, $_ ) }
          grep { /.*\.conf$/ && !/^global.conf$/ } readdir DIR;
        closedir DIR;
    }
    elsif ( -f _ ) {
        push @configs, $arg;
    }
}

my $connect_options = {
    AutoCommit       => 1,
    FetchHashKeyName => 'NAME_lc',
    LongReadLen      => 3000,
    LongTruncOk      => 1,
    RaiseError       => 1,
};

for my $file (@configs) {
    print "Parsing config file '$file'\n";
    my %db_opts;
    {
        my $cfile = Config::General->new($file) or die "Error reading '$file'";
        my %config = $cfile->getall;
        %db_opts = %{ $config{'database'} }
          or die "No database configuration present in '$file'";
    }

    my $datasource = $db_opts{'datasource'} || '';
    my $user       = $db_opts{'user'}       || '';
    my $password   = $db_opts{'password'}   || '';

    unless ( $datasource && $user ) {
        warn "Not enough db args in '$file', skipping.\n";
        next;
    }

    my $dbh = DBI->connect( $datasource, $user, $password, $connect_options );

    open my $fh, ">>$file" or die "Can't append to '$file': $!\n";

    #
    # Feature types
    #
    my $ft = $dbh->selectall_arrayref( 'select * from cmap_feature_type',
        { Columns => {} } );
    for my $row (@$ft) {
        print $fh "\n<feature_type " . $row->{'accession_id'} . ">";
        print $fh "\nfeature_type_accession " . $row->{'accession_id'};
        print $fh "\nfeature_type ";
        print $fh $row->{'feature_type'} if $row->{'feature_type'};
        print $fh "\ndefault_rank ";
        print $fh $row->{'default_rank'} if $row->{'default_rank'};
        print $fh "\ncolor ";
        print $fh $row->{'color'} if $row->{'color'};
        print $fh "\nshape ";
        print $fh $row->{'shape'} if $row->{'shape'};
        print $fh "\ndrawing_lane ";
        print $fh $row->{'drawing_lane'} if $row->{'drawing_lane'};
        print $fh "\ndrawing_priority ";
        print $fh $row->{'drawing_priority'} if $row->{'drawing_priority'};
        print $fh "\n" . q[area_code <<EOF
    $code=sprintf("onMouseOver=\"window.status='%s';return true\"",$feature->{'feature_name'});
EOF];
        print $fh "\nrequired_page_code ";
        print $fh "\nextra_forms ";
        
        # Get Attributes
        my $atts = $dbh->selectall_arrayref( q[
            select * 
            from   cmap_attribute 
            where  table_name = 'cmap_feature_type'
               and object_id = ]
            .$row->{'feature_type_id'}
            , { Columns => {} } );
        foreach my $att (@$atts){
            print $fh "\n<attribute>"
                . "\n  name "
                . $att->{'attribute_name'}
                . "\n  value "
                . $att->{'attribute_value'}
                . "\n  is_public "
                . $att->{'is_public'}
                . "\n  display_order "
                . $att->{'display_order'}
                . "\n</attribute>\n";
        }
        # Get Xrefs
        my $xrefs = $dbh->selectall_arrayref( q[
            select * 
            from   cmap_xref 
            where  table_name = 'cmap_feature_type'
               and object_id = ]
            .$row->{'feature_type_id'}
            , { Columns => {} } );
        foreach my $xref (@$xrefs){
            print $fh "\n<xref>"
                . "\n  name "
                . $xref->{'xref_name'}
                . "\n  url "
                . $xref->{'xref_url'}
                . "\n  display_order "
                . $xref->{'display_order'}
                . "\n</xref>\n";
        }

        print $fh "\n</feature_type>\n\n";
    }

    #
    # Evidence types
    #
    my $et = $dbh->selectall_arrayref( 'select * from cmap_evidence_type',
        { Columns => {} } );
    for my $row (@$et) {
        print $fh "\n<evidence_type " . $row->{'accession_id'} . ">";
        print $fh "\nevidence_type_accession " . $row->{'accession_id'};
        print $fh "\nevidence_type ";
        print $fh $row->{'evidence_type'} if $row->{'evidence_type'};
        print $fh "\nrank ";
        print $fh $row->{'rank'} if $row->{'rank'};
        print $fh "\ncolor ";
        print $fh $row->{'line_color'} if $row->{'line_color'};
        
        # Get Attributes
        my $atts = $dbh->selectall_arrayref( q[
            select * 
            from   cmap_attribute 
            where  table_name = 'cmap_evidence_type'
               and object_id = ]
            .$row->{'evidence_type_id'}
            , { Columns => {} } );
        foreach my $att (@$atts){
            print $fh "\n<attribute>"
                . "\n  name "
                . $att->{'attribute_name'}
                . "\n  value "
                . $att->{'attribute_value'}
                . "\n  is_public "
                . $att->{'is_public'}
                . "\n  display_order "
                . $att->{'display_order'}
                . "\n</attribute>\n";
        }
        # Get Xrefs
        my $xrefs = $dbh->selectall_arrayref( q[
            select * 
            from   cmap_xref 
            where  table_name = 'cmap_evidence_type'
               and object_id = ]
            .$row->{'evidence_type_id'}
            , { Columns => {} } );
        foreach my $xref (@$xrefs){
            print $fh "\n<xref>"
                . "\n  name "
                . $xref->{'xref_name'}
                . "\n  url "
                . $xref->{'xref_url'}
                . "\n  display_order "
                . $xref->{'display_order'}
                . "\n</xref>\n";
        }

        print $fh "\n</evidence_type>\n\n";
    }

    #
    # Map types
    #
    my $mt = $dbh->selectall_arrayref( 'select * from cmap_map_type',
        { Columns => {} } );
    for my $row (@$mt) {
        print $fh "\n<map_type " . $row->{'accession_id'} . ">";
        print $fh "\nmap_type_accession " . $row->{'accession_id'};
        print $fh "\nmap_type ";
        print $fh $row->{'map_type'} if $row->{'map_type'};
        print $fh "\nmap_units ";
        print $fh $row->{'map_units'} if $row->{'map_units'};
        print $fh "\nis_relational_map ";
        print $fh $row->{'is_relational_map'} if $row->{'is_relational_map'};
        print $fh "\nwidth ";
        print $fh $row->{'width'} if $row->{'width'};
        print $fh "\nshape ";
        print $fh $row->{'shape'} if $row->{'shape'};
        print $fh "\ncolor ";
        print $fh $row->{'line_color'} if $row->{'line_color'};
        print $fh "\ndisplay_order ";
        print $fh $row->{'display_order'} if $row->{'display_order'};
        print $fh "\n" . q[area_code <<EOF
    $code=sprintf("onMouseOver=\"window.status='%s';return true\"",$map->{'map_name'});
EOF];
        print $fh "\nrequired_page_code ";
        print $fh "\nextra_forms ";
        
        # Get Attributes
        my $atts = $dbh->selectall_arrayref( q[
            select * 
            from   cmap_attribute 
            where  table_name = 'cmap_map_type'
               and object_id = ]
            .$row->{'map_type_id'}
            , { Columns => {} } );
        foreach my $att (@$atts){
            print $fh "\n<attribute>"
                . "\n  name "
                . $att->{'attribute_name'}
                . "\n  value "
                . $att->{'attribute_value'}
                . "\n  is_public "
                . $att->{'is_public'}
                . "\n  display_order "
                . $att->{'display_order'}
                . "\n</attribute>\n";
        }
        # Get Xrefs
        my $xrefs = $dbh->selectall_arrayref( q[
            select * 
            from   cmap_xref 
            where  table_name = 'cmap_map_type'
               and object_id = ]
            .$row->{'map_type_id'}
            , { Columns => {} } );
        foreach my $xref (@$xrefs){
            print $fh "\n<xref>"
                . "\n  name "
                . $xref->{'xref_name'}
                . "\n  url "
                . $xref->{'xref_url'}
                . "\n  display_order "
                . $xref->{'display_order'}
                . "\n</xref>\n";
        }

        print $fh "\n</map_type>\n\n";
    }

    close $fh;
}

print "Finished.\n";
