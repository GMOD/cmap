package Bio::GMOD::CMap::Apache::FeatureAliasViewer;
# vim: set ft=perl:

# $Id: FeatureAliasViewer.pm,v 1.1 2003-10-29 20:40:27 kycl4rk Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.1 $)[-1];

use Apache::Constants;
use Apache::Request;
use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Data;
use base 'Bio::GMOD::CMap::Apache';

use constant TEMPLATE => 'feature_alias_detail.tmpl';

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;
    $self->data_source( $apr->param('data_source') ) or return;
    my $data_module    = $self->data_module;
    my $alias          = $data_module->feature_alias_detail_data(
        feature_aid    => $apr->param('feature_aid')   || '',
        feature_alias  => $apr->param('feature_alias') || '',
    ) or return $self->error( $data_module->error );

    my $t = $self->template or return;
    my $html;
    $t->process( 
        TEMPLATE, 
        { 
            alias      => $alias,
            page       => $self->page,
            stylesheet => $self->stylesheet,
        }, 
        \$html 
    ) or return $self->error( $t->error );

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

Bio::GMOD::CMap::Apache::FeatureViewer - view feature details

=head1 SYNOPSIS

In httpd.conf:

  <Location /cmap/feature>
      SetHandler  perl-script
      PerlHandler Bio::GMOD::CMap::Apache::FeatureViewer->super
  </Location>

=head1 DESCRIPTION

This module is a mod_perl handler for displaying the details of a feature.  It
inherits from Bio::GMOD::CMap::Apache where all the error handling occurs (which is
why I can just "die" here).

=head1 SEE ALSO

L<perl>, Bio::GMOD::CMap::Apache.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2002-3 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut