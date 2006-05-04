#!/usr/bin/perl -w

=head1 NAME

remove_sync_from_chado.pl: removes the dbxrefs that point to the CMap database
from a chado database
   
=head1 SYNOPSIS

remove_sync_from_chado.pl --chado_datasource datasource -u sql_username [-p sql_password] [-b db_base_name] 

Options:

	--chado_datasource chado_datasource( postgres ex: "dbi:Pg:dbname=chado")
	--db_base_name     The name used in the chado "db" table to define the 
                       dbxrefs as cmap.  Default: cmap
	-u sql_username
	-p sql_password (optional) 

=head1 DESCRIPTION

With a little input from the user, this removes the dbxrefs that point to the
CMap database from a synchronized chado database.

=cut

use strict;
use Getopt::Long;
use DBI;
use Pod::Usage;
use Data::Dumper;

my ( $help, $chado_datasource,$cmap_base_name, $user, $password );

GetOptions(
    'help|h|?'              => \$help,
    'chado_datasource|d|:s' => \$chado_datasource,
    'u:s'                   => \$user,
    'p:s'                   => \$password,
    'db_base_name|b:s'        => \$cmap_base_name,
    )
    or pod2usage;

$cmap_base_name ||= 'cmap';

unless ($chado_datasource and $user){
    print "ERROR: Not all required command line flags were defined\n";
    pod2usage(0);
}

$password = $password || '';

pod2usage(0) if $help;

my $options = {
    AutoCommit       => 1,
    FetchHashKeyName => 'NAME_lc',
    LongReadLen      => 3000,
    LongTruncOk      => 1,
    RaiseError       => 1,
};
my $dbh = DBI->connect( $chado_datasource, $user, $password, $options );

print "OK to remove the CMap references from '$chado_datasource' "
    . "with a base name of '$cmap_base_name'?\n[y/N] ";
chomp( my $answer = <STDIN> );
unless ($answer =~ m/^[Yy]/){
    print "Exiting\n";
    exit;
}

print "Removing CMap external references from '$chado_datasource'.\n";


my $db_ids_ref = get_all_dbs( $dbh, $cmap_base_name );
                                                                                                                             
foreach my $key ( keys %{ $db_ids_ref || {} } ) {
    my $db_id = $db_ids_ref->{$key};
    next unless ($db_id);
    my $delete_dbxref_str = q[
            delete from dbxref
            where db_id = ?
        ];
    $dbh->do( $delete_dbxref_str, {}, ($db_id) );
    my $delete_db_str = q[
            delete from db
            where db_id = ?
        ];
    $dbh->do( $delete_db_str, {}, ($db_id) );
}


#----------------------------------------------

sub get_all_dbs {
    my $dbh = shift;
    my $cmap_base_name = shift;
    my $db_ids_ref;

    for my $db_type ( qw[ species map_set map feature ] ) {
        $db_ids_ref->{$db_type} = get_db($cmap_base_name.'_'.$db_type, $dbh);
    }
    
    return $db_ids_ref;
}

sub get_db {
    my $cmap_db_name = shift;
    my $dbh = shift;
    my $db_id        = $dbh->selectrow_array(
        q[
            select db_id
            from   db
            where  name=?
        ],
        {}, ($cmap_db_name)
    );
    return $db_id;
}



