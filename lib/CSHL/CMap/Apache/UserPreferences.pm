package CSHL::CMap::Apache::UserPreferences;

# $Id: UserPreferences.pm,v 1.1.1.1 2002-07-31 23:27:28 kycl4rk Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.1.1.1 $)[-1];

use Apache::Constants;
use Apache::Cookie;
use Apache::Request;

use CSHL::CMap::Constants;

use constant FIELD_SEP  => '=';
use constant RECORD_SEP => ';';

sub handler {
#
# Get the current preferences and any existing cookie.  Always take
# current settings over cookie settings.  End by always setting
# cookie with current settings.
#
    my $r                 = shift;
    my @preference_fields = @{ +PREFERENCE_FIELDS };
    my $apr               = Apache::Request->new( $r );
    my $cookie_name       = $r->dir_config('USER_PREF_COOKIE_NAME') ||
                            DEFAULT->{'user_pref_cookie_name'};
    my %preferences       = ();

    #
    # Try to fetch the cookie and read it.
    #
    if ( my %cookies = Apache::Cookie->new($r)->fetch ) {{
        my $cookie        = $cookies{$cookie_name} or last;
        my $cookie_string = $cookie->value         ||   '';
        my @cookie_fields = split RECORD_SEP, $cookie_string;

        foreach ( @cookie_fields ) {
            my ( $name, $value )  = split FIELD_SEP;
            $preferences{ $name } = $value if $value;
        }
    }}

    #
    # This updates the preferences with whatever is in the latest
    # request from the user.  If the preference isn't defined in this
    # request, then we'll leave whatever's there.  If nothing is
    # defined, then we'll set it with the default value.
    #
    for my $pref ( @preference_fields ) {
        $preferences{ $pref } = 
            defined $apr->param( $pref )
                ? $apr->param( $pref ) 
                : defined $preferences{ $pref }
                    ? $preferences{ $pref } 
                    : DEFAULT->{ $pref } || '';
        ;
    }

    #
    # Place the preferences into pnotes for use further downstream.
    #
    $apr->pnotes( PREFERENCES => \%preferences );

    #
    # Set a new cookie with the latest preferences.
    #
    my $cookie_domain = $apr->dir_config('COOKIE_DOMAIN') ||
                        DEFAULT->{'cookie_domain'};
    my $cookie_value  = join( RECORD_SEP,
        map { join( FIELD_SEP, $_, $preferences{ $_ } ) } @preference_fields 
    );

    my $cookie   = Apache::Cookie->new(
        $apr,
        -name    => $cookie_name,
        -value   => $cookie_value,
        -expires => '+1y',
        -domain  => $cookie_domain,
        -path    => '/'
    );
    $cookie->bake;

    return OK;
}

1;

# ----------------------------------------------------
# Streets that follow like a tedious argument
# Of insidious intent
# To lead you to an overwhelming question...
# T. S. Eliot
# ----------------------------------------------------

=head1 NAME

CSHL::CMap::Apache::UserPreferences - save user preferences

=head1 SYNOPSIS

In httpd.conf:

  <Location /cmap/viewer>
      PerlInitHandler CSHL::CMap::Apache::UserPreferences
      SetHandler      perl-script
      PerlHandler     CSHL::CMap::Apache::MapViewer->super
  </Location> 

=head1 DESCRIPTION

By placing this module as the "PerlInitHandler" of a <Location>
directive in the httpd.conf, you get automatic handling of
cookie-based preferences.  To add preferences, edit the
CSHL::CMap::Constants file and add to the "PREFERENCE_FIELDS".  Also
be sure to set the default values in the "DEFAULT" section of that
file.

=head1 SEE ALSO

L<perl>, CSHL::CMap::Constants.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

Copyright (c) 2002 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
