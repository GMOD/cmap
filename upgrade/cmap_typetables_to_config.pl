#!/usr/bin/perl -w
# $Id: cmap_typetables_to_config.pl,v 1.1 2004-10-09 20:19:34 mwz444 Exp $

=head1 NAME

cmap_typetables_to_config.pl: reads CMap0.12 schema from db and outputs
                              configurations for the "*_type" tables
   
=head1 SYNOPSIS

cmap_typetables_to_config.pl -d datasource -u sql_username [-p sql_password] >>cmap_conf_file.conf

Options:

	-d datasource (mysql ex: "dbi:mysql:CMAP";
                       postgres ex: "dbi:Pg:dbname=CMAP")
	-u sql_username
	-p sql_password (optional) 

=head1 DESCRIPTION

Use this to profile the CMap drawing code.

=cut



use strict;
use Getopt::Long;
use DBI;      
use Pod::Usage;


my ($help,$datasource,$user,$password);

GetOptions(
    'help|h|?' => \$help,
    'd:s'      => \$datasource,
    'u:s'      => \$user,
    'p:s'      => \$password,
) or pod2usage;

$password=$password || '';

pod2usage(0) if $help;

my $options    = {
    AutoCommit       => 1,
    FetchHashKeyName => 'NAME_lc',
    LongReadLen      => 3000,
    LongTruncOk      => 1,
    RaiseError       => 1,
};
my $dbh=DBI->connect( 
                $datasource, $user, $password, $options 
            );
my $sth;
###Get Feature types
$sth=$dbh->prepare("select * from cmap_feature_type;");
$sth->execute;
while (  my $row = $sth->fetchrow_hashref ) {
    print "\n<feature_type ".$row->{'accession_id'}.">";
    print "\nfeature_type_accession ".$row->{'accession_id'};
    print "\nfeature_type ";
    print $row->{'feature_type'} if $row->{'feature_type'};
    print "\ndefault_rank ";
    print $row->{'default_rank'} if $row->{'default_rank'};
    print "\ncolor ";
    print $row->{'color'} if $row->{'color'};
    print "\nshape ";
    print $row->{'shape'} if $row->{'shape'};
    print "\ndrawing_lane ";
    print $row->{'drawing_lane'} if $row->{'drawing_lane'};
    print "\ndrawing_priority ";
    print $row->{'drawing_priority'} if $row->{'drawing_priority'};
    print "\n".q[area_code <<EOF
$code=sprintf("onMouseOver=\"window.status='%s';return true\"",$feature->{'feature_name'});
EOF];
    print "\nrequired_page_code ";
    print "\nextra_forms ";
    print "\n</feature_type>\n\n";
}
###Get evidence types
$sth=$dbh->prepare("select * from cmap_evidence_type;");
$sth->execute;
while (  my $row = $sth->fetchrow_hashref ) {
    print "\n<evidence_type ".$row->{'accession_id'}.">";
    print "\nevidence_type_accession ".$row->{'accession_id'};
    print "\nevidence_type ";
    print $row->{'evidence_type'} if $row->{'evidence_type'};
    print "\nrank ";
    print $row->{'rank'} if $row->{'rank'};
    print "\ncolor ";
    print $row->{'line_color'} if $row->{'line_color'};
    print "\n</evidence_type>\n\n";
}

###Get map types
$sth=$dbh->prepare("select * from cmap_map_type;");
$sth->execute;
while (  my $row = $sth->fetchrow_hashref ) {
    print "\n<map_type ".$row->{'accession_id'}.">";
    print "\nmap_type_accession ".$row->{'accession_id'};
    print "\nmap_type ";
    print $row->{'map_type'} if $row->{'map_type'};
    print "\nmap_units ";
    print $row->{'map_units'} if $row->{'map_units'};
    print "\nis_relational_map ";
    print $row->{'is_relational_map'} if $row->{'is_relational_map'};
    print "\nwidth ";
    print $row->{'width'} if $row->{'width'};
    print "\nshape ";
    print $row->{'shape'} if $row->{'shape'};
    print "\ncolor ";
    print $row->{'line_color'} if $row->{'line_color'};
    print "\ndisplay_order ";
    print $row->{'display_order'} if $row->{'display_order'};
    print "\n".q[area_code <<EOF
$code=sprintf("onMouseOver=\"window.status='%s';return true\"",$map->{'map_name'});
EOF];
    print "\nrequired_page_code ";
    print "\nextra_forms ";
    print "\n</map_type>\n\n";
}
