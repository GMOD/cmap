package Bio::GMOD::CMap::Config;
# vim: set ft=perl:

# $Id: Config.pm,v 1.7.2.1 2005-01-11 19:53:46 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Config - handles config files

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Config;

=head1 DESCRIPTION

This module handles config files

=head1 EXPORTED SUBROUTINES

=cut 

use strict; 
use Class::Base;
use Config::General;
use Data::Dumper;
use Bio::GMOD::CMap::Constants;

use base 'Class::Base';    

# ----------------------------------------------------
sub init {
    my ( $self ) = @_;
    $self->set_config();
    return $self;
}

# ----------------------------------------------------
sub read_config_dir {

=pod

=head2 read_config_dir

Reads in config files from the conf directory.
Requires a global conf and at least one db specific conf.
The conf dir and the global conf file are specified in Constants.pm

=cut

    my $self   = shift;
    my $suffix = 'conf';
    my $global = GLOBAL_CONFIG_FILE;
    my %config_data;

    #
    # Get files from directory (taken from Bio/Graphics/Browser.pm by lstein)
    #
    die CONFIG_DIR.": not a directory"  unless -d CONFIG_DIR;
    opendir(D,CONFIG_DIR) or die "Couldn't open ".CONFIG_DIR.": $!";
    my @conf_files = map { CONFIG_DIR."/$_" } grep {/\.$suffix$/} readdir(D);
    close D;
    
    #
    # Try to work around a bug in Apache/mod_perl which appears when
    # running under linux/glibc 2.2.1
    #
    unless ( @conf_files ) {
        # use File::Spec::catfile here?
        @conf_files = glob( CONFIG_DIR . "/*.$suffix" );
    }
    
    #
    # Read config data from each file and store it all in a hash.
    #
    foreach my $conf_file ( @conf_files ) {
        my $conf   = Config::General->new( $conf_file ) or 
            return $self->error("Trouble reading config '$conf_file'");
        my %config = $conf->getall or return
            $self->error("No configuration options present in '$conf_file'");

        if ( $conf_file =~ /$global$/ ) {
            $self->{'global_config'} = \%config;
        }
        else {
            my $db_name = $config{'database'}{'name'} || return $self->error(
                qq[Config file "$conf_file" does not defined a db name]
            );
            $config_data{ $db_name } = \%config;
        }
    } 

    #
    # Need a global and specific conf file
    #
    return $self->error( 'No "global.conf" found in ' . CONFIG_DIR ) 
        unless $self->{'global_config'};
    return $self->error( 'No database conf files found in ' . CONFIG_DIR ) 
        unless %config_data;
    $self->{'config_data'} = \%config_data;
#print STDERR "Read Config Files\n";
    return 1;
}

# ----------------------------------------------------
sub set_config {

=pod

=head2 set_config

Sets the active config data.

=cut

    my $self        = shift;
    my $config_name = shift;

    unless ( $self->{'config_data'} ) {
        $self->read_config_dir() or return $self->error;
    }

    #
    # If config_name specified, check if it exists.
    #
    if ( $config_name ) {
#print STDERR "looking up '$config_name'\n";
        if ( $self->{'config_data'}{ $config_name } ) {
            $self->{'current_config'} = $config_name;
            return 1;
        }
    }

    unless ( $self->{'current_config'} ) {
#print STDERR "current config = ", Dumper($self->{'current_config'}), "\n";
        #
        # If the default db is in the global_config
        # and it exists, set that as the config.
        #
        if (
            $self->{'global_config'}{'default_db'} &&
            $self->{'config_data'}{ $self->{'global_config'}{'default_db'} }
        ) {
            $self->{'current_config'} = $self->{'global_config'}{'default_db'};
            return 1;
        }

        #
        # No preference set.  Just let Fate (keys) decide.
        #
        $self->{'current_config'} = ( keys %{ $self->{'config_data'} } )[0];
    }
    
    return 1 if ($self->{'current_config'});
    return 0;
}

# ----------------------------------------------------
sub get_config_names {

=pod

=head2 get_config_names

Returns an array ref of the keys to self->{'config_data'}.

=cut

    my $self=shift;
    return [ keys %{ $self->{'config_data'} } ];
}

# ----------------------------------------------------
sub get_config {

=pod

=head2 config

Returns one option from the config files.
optionally you can specify a set of config data to read from.

=cut

    my ( $self, $option, $specific_db ) = @_;

    #
    # If config not set, set it.
    #
    unless ( $self->{'current_config'} ) {
        $self->set_config() or return self->error;
    }
    
    return $self unless $option;

    #
    # If a specific db conf file was asked for, supply answer from it.
    #
    my $value;
    if ( $specific_db ) {
        $value = defined $self->{'config_data'}{ $specific_db }{ $option } 
        ? $self->{'config_data'}{ $specific_db }{ $option }
        : '';            
    }
    else{
        #
        # Is it in the global config
        #
        if ( defined $self->{'global_config'}{ $option } ) {
            $value = $self->{'global_config'}{ $option };
        }
        else{
            #
            # Otherwise get it from the other config.
            #
            $value = defined $self->{'config_data'}{$self->{'current_config'}}{ $option } 
            ?  $self->{'config_data'}->{$self->{'current_config'}}{ $option }
            : DEFAULT->{ $option }
            ;
        }
    }

    if ( defined($value) ) {
        return wantarray && (ref $value eq "ARRAY") ? @$value : $value;
    }
    else {
        return wantarray ? () : '';
    }
}

1;

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
