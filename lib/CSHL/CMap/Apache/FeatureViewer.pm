package CSHL::CMap::Apache::FeatureViewer;

# $Id: FeatureViewer.pm,v 1.1.1.1 2002-07-31 23:27:28 kycl4rk Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.1.1.1 $)[-1];

use Apache::Constants;
use Apache::Request;

use Data::Dumper;

use Error;
use CSHL::CMap::Apache;
use CSHL::CMap::Data;
use base 'CSHL::CMap::Apache';

use constant TEMPLATE => 'feature_detail.tmpl';

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;

    my $feature_aid = $apr->param('feature_aid') or die 'No accession id';
    my $data        = CSHL::CMap::Data->new;
    my $feature     = $data->feature_detail_data( feature_aid => $feature_aid )
        or die $data->error;

    my $t = $self->template or die 'No template';
    if ( my $mini_template = $feature->{'dbxref'}{'url'} ) {
        $t->process( 
            \$mini_template, 
            { feature => $feature }, 
            \$feature->{'dbxref_url'}
        ) or throw Error::Simple $t->error;
    }

#    warn "feature = ", Dumper( $feature ), "\n";

    my $html;
    $t->process( 
        TEMPLATE, 
        { 
            feature => $feature,
            page    => $self->page,
        }, 
        \$html 
    ) or throw Error::Simple $t->error;

    $apr->content_type('text/html');
    $apr->send_http_header;
    $apr->print( $html );
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

CSHL::CMap::Apache::FeatureViewer - view feature details

=head1 SYNOPSIS

In httpd.conf:

  <Location /cmap/feature>
      SetHandler  perl-script
      PerlHandler CSHL::CMap::Apache::FeatureViewer->super
  </Location>

=head1 DESCRIPTION

This module is a mod_perl handler for displaying the details of a feature.  It
inherits from CSHL::CMap::Apache where all the error handling occurs (which is
why I can just "die" here).

=head1 SEE ALSO

L<perl>, CSHL::CMap::Apache.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

Copyright (c) 2002 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
