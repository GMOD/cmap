package Bio::GMOD::CMap;

# $Id: CMap.pm,v 1.20 2003-01-01 02:16:18 kycl4rk Exp $

=head1 NAME

Bio::GMOD::CMap.pm - base object for comparative maps

=head1 SYNOPSIS

  package Bio::GMOD::CMap::Foo;
  use Bio::GMOD::CMap;
  use base 'Bio::GMOD::CMap';

  sub foo { print "foo\n" }

  1;

=head1 DESCRIPTION

This is the base class for all the comparative maps modules.  It is
itself based on Andy Wardley's Class::Base module.

=head1 METHODS

=cut

use strict;
use vars '$VERSION';
$VERSION = 0.06;

use Class::Base;
use Config::General;
use Bio::GMOD::CMap::Constants;
use DBI;
#use Bio::GMOD::CMap::DB;

use base 'Class::Base';

## ----------------------------------------------------
#sub init {
#    my ( $self, $config ) = $_;
#    $self->{'db'} = $config->{'db'} || undef;
#    return $self;
#}

# ----------------------------------------------------
sub config {

=pod

=head2 config

Returns one or all options from the config file.

=cut
    my ( $self, $option ) = @_;

    unless ( $self->{'config'} ) {
        my $conf          = Config::General->new( CONFIG_FILE ) or
            return $self->error('Error reading config file: '.CONFIG_FILE);
        my %config        = $conf->getall or 
            $self->error('No configuration options');
        $self->{'config'} = \%config;
    }

    if ( $option ) {
        my $value = defined $self->{'config'}{ $option } 
            ? $self->{'config'}{ $option } 
            : DEFAULT->{ $option }
        ;

        if ( $value ) {
            return wantarray && ref $value ? @$value : $value;
        }
        else {
            return wantarray ? () : '';
        }
    }
    else {
        return wantarray ? @{ $self->{'config'} } : $self->{'config'};
    }
}

# ----------------------------------------------------
sub db {

=pod

=head2 db

Returns a database handle.  This is the only way into the database.

=cut
    my $self = shift;

    unless ( defined $self->{'db'} ) {
        my $config     = $self->config('database') or 
            $self->error('No database configuration options');
        my $datasource = $config->{'datasource'}
            or $self->error('No database source defined');
        my $user       = $config->{'user'}
            or $self->error('No database user defined');
        my $password   = $config->{'password'} || '';
        my $options    = $config->{'options'}  || {};

        eval {
            $self->{'db'} = DBI->connect( 
                $datasource, $user, $password, $options 
            );

#            Bio::GMOD::CMap::DB->connect( 
#                $datasource, $user, $password, $options 
#            );
        };

        if ( $@ || !defined $self->{'db'} ) {
            my $error = $@ || $DBI::errstr;
            return $self->error( "Can't connect to database: $error" );
        }
    }

    return $self->{'db'};
}

# ----------------------------------------------------
sub data_module {

=pod

=head2 data

Returns a handle to the data module.

=cut
    my $self = shift;

    unless ( $self->{'data_module'} ) { 
        $self->{'data_module'} = Bio::GMOD::CMap::Data->new or 
            $self->error( Bio::GMOD::CMap::Data->error );
    }

    return $self->{'data_module'};
}

# ----------------------------------------------------
sub DESTROY {

=pod

=head2 DESTROY

Object clean-up when destroyed by Perl.

=cut
    my $self = shift;
    $self->db->disconnect if defined $self->{'db'};
    return 1;
}

## ----------------------------------------------------
#sub error {
#
#=pod
#
#=head2 error
#
#Overrides Class::Base's "error" just enough to use Exception::Class's "throw."
#
#=cut
#    my $self = shift;
#    $self->SUPER::error( @_ );
#    return CMapException->throw( error => $self->SUPER::error );
#}

# ----------------------------------------------------
sub template { 

=pod

=head2 template

Returns a Template Toolkit object.

=cut
    my $self = shift;

    unless ( $self->{'template'} ) {
        my $template_dir = $self->config('template_dir') || '';
        return $self->error("Template directory '$template_dir' doesn't exist")
            unless -d $template_dir;

        $self->{'template'} = Template->new( 
            INCLUDE_PATH    => $template_dir,
            FILTERS         => {
                dump        => sub { Dumper( shift() ) },
                nbsp        => sub { my $s=shift; $s =~ s{\s+}{\&nbsp;}g; $s },
                commify     => \&Bio::GMOD::CMap::Utils::commify,
            },
        ) or $self->error(
            "Couldn't create Template object: ".Template->error()
        );
    }

    return $self->{'template'};
}

# ----------------------------------------------------
sub warn {

=pod

=head2 warn

Provides a simple way to print messages to STDERR.  Also, I could
easily turn off warnings glabally with the "debug" flag.

=cut
    my $self = shift;
    print STDERR @_;
}

1;

# ----------------------------------------------------
# To create a little flower is the labour of ages.
# William Blake
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>, L<Class::Base>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

Copyright (c) 2002 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
