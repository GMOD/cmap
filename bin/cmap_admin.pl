#!/usr/bin/perl

# $Id: cmap_admin.pl,v 1.2 2002-08-23 16:02:37 kycl4rk Exp $

use strict;
use Pod::Usage;
use Getopt::Long;

use vars qw[ $VERSION $BE_QUIET ];
$VERSION = (qw$Revision: 1.2 $)[-1];

#
# Turn off output buffering.
#
$| = 1;

#
# Get command-line options
#
my $show_help;    
my $show_version; 

GetOptions(
    'h|help'    => \$show_help,    # Show help and exit
    'q|quiet'   => \$BE_QUIET,     # Don't show status messages
    'v|version' => \$show_version, # Show version and exit
) or pod2usage(2);

pod2usage(0) if $show_help;
if ( $show_version ) {
    print "$0 Version: $VERSION\n";
    exit(0);
}

#
# Create a CLI object with the file arg (if any).
#
my $cli = CSHL::CMap::CLI::Admin->new( file => shift );
while ( 1 ) { 
    my $action = $cli->show_greeting;
    $cli->$action();
}

# ----------------------------------------------------
package CSHL::CMap::CLI::Admin;

use strict;
use IO::File;
use Data::Dumper;
use Term::ReadLine;
use CSHL::Config;
use CSHL::CMap;
use CSHL::CMap::Admin;
use CSHL::CMap::Constants;
use CSHL::CMap::Data;
use CSHL::CMap::Utils;
use CSHL::CMap::Admin::Import();
use CSHL::CMap::Admin::MakeCorrespondences();

use base 'CSHL::CMap';

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->params( $config, 'file' );
    return $self;
}

# ----------------------------------------------------
sub file { 
    my $self = shift;
    $self->{'file'} = shift if @_;
    return $self->{'file'} || '' 
}

# ----------------------------------------------------
sub term {
    my $self = shift;
    $self->{'term'} ||= Term::ReadLine->new('Map Importer');
    return $self->{'term'}
}

# ----------------------------------------------------
sub quit {
    print "Namaste.\n"; 
    exit(0);
}

# ----------------------------------------------------
sub show_greeting {
    my $self      = shift;
    my $separator = '-=' x 10;

    my $action  =  $self->show_menu(
        title   => join("\n", $separator, '  --= Main Menu =--  ', $separator),
        prompt  => 'What would you like to do?',
        display => 'display',
        return  => 'action',
        data    => [
            { 
                action  => 'create_map_set', 
                display => 'Create new map set' 
            },
            { 
                action  => 'import_data', 
                display => 'Import data for existing map set' 
            },
            { 
                action  => 'make_name_correspondences', 
                display => 'Make name-based correspondences' 
            },
            { 
                action  => 'reload_correspondence_matrix', 
                display => 'Reload correspondence matrix' 
            },
#            { 
#                action  => 'correspondences', 
#                display => 'Import Feature Correspondences' 
#            },
            { 
                action  => 'quit',   
                display => 'Quit' 
            },
        ],
    );

    return $action;
}

# ----------------------------------------------------
sub create_map_set {
    my $self = shift;
    my $db   = $self->db;
    print "Creating new map set.\n";
    
    my ( $map_type_id, $map_type ) = $self->show_menu(
        title   => 'Available Map Types',
        prompt  => 'What type of map?',
        display => 'map_type',
        return  => 'map_type_id,map_type',
        data     => $db->selectall_arrayref(
            q[
                select   mt.map_type_id, mt.map_type
                from     cmap_map_type mt
                order by map_type
            ],
            { Columns => {} },
        ),
    );
    die "No map types to select from.\n" unless $map_type_id;

    my ( $species_id, $common_name ) = $self->show_menu(
        title   => 'Available Species',
        prompt  => 'What species?',
        display => 'common_name,full_name',
        return  => 'species_id,common_name',
        data     => $db->selectall_arrayref(
            q[
                select   s.species_id, s.common_name, s.full_name
                from     cmap_species s
                order by common_name
            ],
            { Columns => {} },
        ),
    );
    die "No species to select from.\n" unless $species_id;

    print "Map Study Name (long): ";
    chomp( my $map_set_name = <STDIN> || 'New map set' ); 

    print "Short Name [$map_set_name]: ";
    chomp( my $short_name = <STDIN> );
    $short_name ||= $map_set_name; 

    my $map_set_id = next_number(
        db           => $db,
        table_name   => 'cmap_map_set',
        id_field     => 'map_set_id',
    ) or die 'No map set id';


    print "OK to create set '$map_set_name'?\n[Y/n] ";
    chomp( my $answer = <STDIN> );
    return if $answer =~ m/^[Nn]/;

    $db->do(
        q[
            insert
            into   cmap_map_set
                   ( map_set_id, accession_id, map_set_name, short_name,
                     species_id, map_type_id
                   )
            values ( ?, ?, ?, ?, ?, ? )
        ],
        {},
        (
            $map_set_id, $map_set_id, $map_set_name, $short_name,
            $species_id, $map_type_id
        )
    );

    print "Map set $map_set_name created\n";
}

# ----------------------------------------------------
sub import_correspondences {
#
# Gathers the info to import feature correspondences.
#
    my $self = shift;
    my $file = $self->file;
    my $term = $self->term;

    #
    # Make sure we have a file to parse.
    #
    if ( $file ) {
        print "OK to use '$file'? [Y/n] ";
        chomp( my $answer = <STDIN> );
        $file = '' if $answer =~ m/^[Nn]/;
    }

    while ( ! -r $file ) {
        print "Unable to read '$file'.\n" if $file;
        $file =  $term->readline( 'Where is the file? [q to quit] ');
        $file =~ s/^\s*|\s*$//g;
        return if $file =~ m/^[Qq]/;
    }

    #
    # Open the file.  If it's good, remember it.
    #
    my $fh = IO::File->new( $file ) or die "Can't read $file: $!";
    $term->addhistory( $file ); 
    $self->file( $file );

    #
    # Ask whether to overwrite or append the data.
    #
    my $overwrite = 1;
#    my $overwrite = $self->show_menu(
#        title   => 'Overwrite/Append',
#        prompt  => 'Do you wish to Overwrite or Append this data? ',
#        display => 'display',
#        return  => 'value',
#        data    => [
#            { value => 1, display => 'Overwrite' },
#            { value => 0, display => 'Append'    },
#        ],
#    );

    my $overwrite_yes_no = $overwrite ? 'Yes' : 'No';

    print join("\n",
        'OK to import?',
        "  File      : $file",
        "  Overwrite : $overwrite_yes_no",
        "[Y/n] "
    );
    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    print "Importing data...\n";

    my $importer = CSHL::CMap::Admin::FeatureCorrespondenceImport->new;
    $importer->import(
        fh           => $fh,
        overwrite    => $overwrite,
        be_quiet     => 0, #$BE_QUIET,
    ) or do { print "Error: ", $importer->error, "\n"; return; };
}

# ----------------------------------------------------
sub import_data {
#
# Gathers the info to import physical or genetic maps.
#
    my $self = shift;
    my $db   = $self->db;
    my $term = $self->term;
    my $file = $self->file;

    #
    # Make sure we have a file to parse.
    #
    if ( $file ) {
        print "OK to use '$file'? [Y/n] ";
        chomp( my $answer = <STDIN> );
        $file = '' if $answer =~ m/^[Nn]/;
    }

    while ( ! -r $file ) {
        print "Unable to read '$file'.\n" if $file;
        $file =  $term->readline( 'Where is the file? [q to quit] ');
        $file =~ s/^\s*|\s*$//g;
        return if $file =~ m/^[Qq]/;
    }

    #
    # Open the file.  If it's good, remember it.
    #
    my $fh = IO::File->new( $file ) or die "Can't read $file: $!";
    $term->addhistory($file); 
    $self->file( $file );

    #
    # Get the map type.
    #
    my ( $map_type_id, $map_type ) = $self->show_menu(
        title   => 'Available Map Types',
        prompt  => 'Please select a map type',
        display => 'map_type',
        return  => 'map_type_id,map_type',
        data     => $db->selectall_arrayref(
            q[
                select   mt.map_type_id, mt.map_type
                from     cmap_map_type mt
                order by map_type
            ],
            { Columns => {} },
        ),
    );
    do { print "No map types to select from.\n"; return } unless $map_type_id;

    #
    # Get the species.
    #
    my ( $species_id, $species ) = $self->show_menu(
        title   => "Available Species (for $map_type)",
        prompt  => 'Please select a species',
        display => 'common_name',
        return  => 'species_id,common_name',
        data     => $db->selectall_arrayref(
            q[
                select   distinct s.species_id, s.common_name
                from     cmap_species s,
                         cmap_map_set ms
                where    ms.species_id=s.species_id
                and      ms.map_type_id=?
                order by common_name
            ],
            { Columns => {} },
            ( $map_type_id )
        ),
    );
    do { print "No species to select from.\n"; return } unless $species_id;
    
    #
    # Get the map set.
    #
    my ( $map_set_id, $map_set_name ) = $self->show_menu(
        title   => "Available Map Sets (for $map_type, $species)",
        prompt  => 'Please select a map set',
        display => 'map_set_name',
        return  => 'map_set_id,map_set_name',
        data    => $db->selectall_arrayref(
            q[
                select   ms.map_set_id, ms.map_set_name
                from     cmap_map_set ms
                where    ms.map_type_id=?
                and      ms.species_id=?
                and      ms.map_type_id=?
                order by map_set_name
            ],
            { Columns => {} },
            ( $map_type_id, $species_id, $map_type_id )
        ),
    );
    do { print "There are no map sets for that map type!\n"; return }
         unless $map_set_id;

    #
    # Ask whether to overwrite or append the data.
    #
    my $overwrite = 1;
#    my $overwrite = $self->show_menu(
#        title   => 'Overwrite/Append',
#        prompt  => 'Do you wish to Overwrite or Append this data? ',
#        display => 'display',
#        return  => 'value',
#        data    => [
#            { value => 1, display => 'Overwrite' },
#            { value => 0, display => 'Append'    },
#        ],
#    );

    my $overwrite_yes_no = $overwrite ? 'Yes' : 'No';

    print join("\n",
        'OK to import?',
        "  File      : $file",
        "  Species   : $species",
        "  Map Type  : $map_type",
        "  Map Study : $map_set_name",
        "  Overwrite : $overwrite_yes_no",
        "[Y/n] "
    );
    chomp( my $answer = <STDIN> );
    return if $answer =~ /^[Nn]/;

    print "Importing data...\n";

    my $importer = CSHL::CMap::Admin::Import->new( db => $db );
    $importer->import(
        map_set_id => $map_set_id,
        fh           => $fh,
        map_type     => $map_type,
        overwrite    => $overwrite,
        be_quiet     => 0, #$BE_QUIET,
    ) or do { print "Error: ", $importer->error, "\n"; return; };
}

# ----------------------------------------------------
sub make_name_correspondences {
    my $self = shift;
    my $db   = $self->db;

    #
    # Get the evidence type id.
    #
    my ( $evidence_type_id, $evidence_type ) = $self->show_menu(
        title   => 'Available evidence types',
        prompt  => 'Please select an evidence type',
        display => 'evidence_type',
        return  => 'evidence_type_id,evidence_type',
        data    => $db->selectall_arrayref(
            q[
                select   et.evidence_type_id, et.evidence_type
                from     cmap_evidence_type et
                order by evidence_type
            ],
            { Columns => {} },
        ),
    );

    #
    # Get the map set.
    #
    my ( $map_set_id, $map_set_name ) = $self->show_menu(
        title      => 'Reference Map Set (optional)',
        prompt     => 'Please select a map set',
        display    => 'common_name,map_set_name',
        return     => 'map_set_id,map_set_name',
        allow_null => 1,
        data       => $db->selectall_arrayref(
            q[
                select   ms.map_set_id, 
                         ms.map_set_name,
                         s.common_name
                from     cmap_map_set ms,
                         cmap_species s
                where    ms.species_id=s.species_id
                order by common_name, map_set_name
            ],
            { Columns => {} },
        ),
    );

    print "OK to make correspondences? [Y/n] ";
    chomp( my $answer = <STDIN> );
    return if $answer =~ m/^[Nn]/;

    my $corr_maker = CSHL::CMap::Admin::MakeCorrespondences->new( db => $db );
    $corr_maker->make_name_correspondences(
        evidence_type_id => $evidence_type_id,
        map_set_id       => $map_set_id,
    ) or do { print "Error: ", $corr_maker->error, "\n"; return; };

    return 1;
}

# ----------------------------------------------------
sub reload_correspondence_matrix {
    my $self  = shift;

    print "OK to truncate table and reload? [Y/n] ";
    chomp( my $answer = <STDIN> );
    return if $answer =~ m/^[Nn]/;

    my $admin = CSHL::CMap::Admin->new( db => $self->db );
    $admin->reload_correspondence_matrix or do { 
        print "Error: ", $admin->error, "\n"; return; 
    };

    return 1;
}

# ----------------------------------------------------
sub show_menu {
    my $self    = shift;
    my %args    = @_;
    my $data    = $args{'data'}   or return;
    my @return  = split(/,/, $args{'return'} ) 
                  or die "No return field(s) defined\n";
    my @display = split(/,/, $args{'display'});
    my $result;

    if ( scalar @$data > 1 ) {
        my $i      = 1;
        my %lookup = ();

        my $title = $args{'title'} || '';
        print $title ? "\n$title\n" : "\n";
        for my $row ( @$data ) {
            print "[$i] ", join(' : ', map { $row->{$_} } @display), "\n";
            $lookup{ $i } = scalar @return > 1 ? 
                [ map { $row->{$_} } @return ] : $row->{ $return[0] };
            $i++;
        }

        my $number;
        my $prompt = $args{'prompt'} || 'Please select';
        while ( 1 ) {
            print "\n$prompt", 
                $args{'allow_null'} ? ' (0 for nothing)' : '',
                ': '
            ;
            chomp( $number = <STDIN> );
            if ( $args{'allow_null'} && $number == 0 ) {
                $result = undef;
                last;
            }
            elsif ( defined $lookup{ $number } ) {
                $result = $lookup{ $number }; 
                last;
            }
        }
    }
    elsif ( scalar @$data == 0 ) {
        $result = undef;
    }
    else {
        $result = [ map { $data->[0]->{ $_ } } @return ];
    }

    return wantarray ? defined $result ? @$result : undef : $result;
}

# ----------------------------------------------------
# Life is full of misery, loneliness, and suffering --
# and it's all over much too soon.
# Woody Allen
# ----------------------------------------------------

=pod

=head1 NAME

cmap_admin.pl - command-line comparative maps administrative tool

=head1 SYNOPSIS

  ./cmap_admin.pl [options] [map_set_data]

  Options:

    -h|help    Display help message
    -q|quiet   Don't print more than is necessary
    -v|version Display version

=head1 DESCRIPTION

This script is meant to be a command-line replacement for the
web-based creation and importing of map set data.  Why this giant
leap backwards?  These imports can take a *long* time, so it's awkward
to handle them in a web interface.

If the CSHL::* modules are not installed into your standard Perl
library path, be sure to have your PERL5LIB environment variable set
to their location (e.g., "/usr/local/apache/lib/perl") or to supply
that path to Perl when invoking the script, like so:

  perl -I/usr/local/apache/lib/perl map_importer.pl

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

=head1 SEE ALSO

L<perl>.

=cut
