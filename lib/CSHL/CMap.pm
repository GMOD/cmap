package CSHL::CMap;

# $Id: CMap.pm,v 1.1.1.1 2002-07-31 23:27:25 kycl4rk Exp $

=head1 NAME

CSHL::CMap.pm - base object for comparative maps

=head1 SYNOPSIS

  package CSHL::CMap::Foo;
  use CSHL::CMap;
  use base 'CSHL::CMap';

  sub foo { print "foo\n" }

  1;

=head1 DESCRIPTION

This is the base class for all the comparative maps modules.  It is
itself based on Andy Wardley's Class::Base module.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.1.1.1 $)[-1];

use Class::Base;
use CSHL::Config;
use DBI;
use Error;

use base 'Class::Base';

# ----------------------------------------------------
sub db {

=pod

=head2 db

Returns a database handle.  This is the only way into the database.

=cut
    my $self = shift;

    unless ( defined $self->{'db'} ) {
            $self->{'db'} = DBI->connect(
            MapV3DataSource,
            MapV3DBUser,
            MapV3DBPassword,
            MapV3DBOptions,
        ) or return $self->error('No db handle:', $DBI::errstr);
    }

    return $self->{'db'};
}

# ----------------------------------------------------
sub error {

=pod

=head2 error

Overrides Class::Base's "error" just enough to use Error::Simple's "throw."

=cut
    my $self = shift;
    $self->SUPER::error( @_ );
    return throw Error::Simple( $self->SUPER::error );
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
