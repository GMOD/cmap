package Bio::GMOD::CMap::Data::Oracle;

# $Id: Oracle.pm,v 1.1 2002-08-23 16:07:21 kycl4rk Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.1 $)[-1];

use Bio::GMOD::CMap::Data::Generic;
use base 'Bio::GMOD::CMap::Data::Generic';

# ----------------------------------------------------
sub set_date_format {

=pod

=head2 set_date_format

The SQL for setting the proper date format.

=cut
    my $self = shift;

    $self->db->do(
        q[ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS']
    );

    return 1;
}

# ----------------------------------------------------
sub date_format {

=pod

=head2 date_format

The strftime string for date format.

=cut
    my $self = shift;
    return '%d-%b-%y';
}

1;

# ----------------------------------------------------
# I should not talk so much about myself
# if there were anybody whom I knew as well.
# Henry David Thoreau
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Data::Oracle - Oracle module

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Data::Oracle;
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
