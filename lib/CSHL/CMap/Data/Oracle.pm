package CSHL::CMap::Data::Oracle;

# $Id: Oracle.pm,v 1.1.1.1 2002-07-31 23:27:28 kycl4rk Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.1.1.1 $)[-1];

use CSHL::CMap::Data::Generic;
use base 'CSHL::CMap::Data::Generic';

# ----------------------------------------------------
#sub init {
#    my ( $self, $config ) = @_;
#
#    $self->db->do(
#        q[ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS']
#    );
#}

1;

# ----------------------------------------------------
# I should not talk so much about myself
# if there were anybody whom I knew as well.
# Henry David Thoreau
# ----------------------------------------------------

=head1 NAME

CSHL::CMap::Data::Oracle - Oracle module

=head1 SYNOPSIS

  use CSHL::CMap::Data::Oracle;
  blah blah blah

=head1 DESCRIPTION

Blah blah blah.

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

Copyright (c) 2002 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
