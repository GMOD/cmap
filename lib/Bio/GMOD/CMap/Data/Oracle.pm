package Bio::GMOD::CMap::Data::Oracle;

# vim: set ft=perl:

# $Id: Oracle.pm,v 1.8 2008-02-12 22:13:09 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Data::Oracle - Oracle module

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Data::Oracle;
  blah blah blah

=head1 DESCRIPTION

Blah blah blah.

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.8 $)[-1];

use DBD::Oracle qw(:ora_types);
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
        q[ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS']);

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

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-8 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut
