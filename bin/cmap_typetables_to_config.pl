#!/usr/bin/perl -w
# $Id: cmap_typetables_to_config.pl,v 1.1 2004-03-19 18:48:36 mwz444 Exp $

=head1 NAME

cmap_typetables_to_config.pl: reads CMap0.11 schema from db and outputs
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
    print "<feature_type>\n";
    print "name ".$row->{'feature_type'}."\n" if $row->{'feature_type'};
    print "default_rank ".$row->{'default_rank'}."\n" if $row->{'default_rank'};
    print "color ".$row->{'color'}."\n" if $row->{'color'};
    print "shape ".$row->{'shape'}."\n" if $row->{'shape'};
    print "drawing_lane ".$row->{'drawing_lane'}."\n" if $row->{'drawing_lane'};
    print "drawing_priority ".$row->{'drawing_priority'}."\n" if $row->{'drawing_priority'};
    print "</feature_type>\n\n";
}
###Get evidence types
$sth=$dbh->prepare("select * from cmap_evidence_type;");
$sth->execute;
while (  my $row = $sth->fetchrow_hashref ) {
    print "<evidence_type>\n";
    print "name ".$row->{'evidence_type'}."\n" if $row->{'evidence_type'};
    print "rank ".$row->{'rank'}."\n" if $row->{'rank'};
    print "color ".$row->{'line_color'}."\n" if $row->{'line_color'};
    print "</evidence_type>\n\n";
}

###Get map types
$sth=$dbh->prepare("select * from cmap_map_type;");
$sth->execute;
while (  my $row = $sth->fetchrow_hashref ) {
    print "<map_type>\n";
    print "name ".$row->{'map_type'}."\n" if $row->{'map_type'};
    print "map_units ".$row->{'map_units'}."\n" if $row->{'map_units'};
    print "is_relational_map ".$row->{'is_relational_map'}."\n" if $row->{'is_relational_map'};
    print "width ".$row->{'width'}."\n" if $row->{'width'};
    print "shape ".$row->{'shape'}."\n" if $row->{'shape'};
    print "color ".$row->{'line_color'}."\n" if $row->{'line_color'};
    print "display_order ".$row->{'display_order'}."\n" if $row->{'display_order'};
    print "</map_type>\n\n";
}
