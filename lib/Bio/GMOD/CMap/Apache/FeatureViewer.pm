package Bio::GMOD::CMap::Apache::FeatureViewer;
# vim: set ft=perl:

# $Id: FeatureViewer.pm,v 1.11 2004-02-10 22:50:09 kycl4rk Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.11 $)[-1];

use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Data;
use base 'Bio::GMOD::CMap::Apache';

use constant TEMPLATE => 'feature_detail.tmpl';

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;
    my $feature_aid    = $apr->param('feature_aid') or die 'No accession id';

    $self->data_source( $apr->param('data_source') ) or return;
    my $data           = $self->data_module;
    my $feature        = $data->feature_detail_data(feature_aid=>$feature_aid)
        or return $self->error( $data->error );

    #
    # Make the subs in the URL.
    #
    my $t = $self->template or return;
    my $html;
    $t->process( 
        TEMPLATE, 
        { 
            apr        => $self->apr,
            feature    => $feature,
            page       => $self->page,
            stylesheet => $self->stylesheet,
        }, 
        \$html 
    ) or return $self->error( $t->error );

    print $apr->header( -type => 'text/html', -cookie => $self->cookie ), $html;
    return 1;
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

This module is a mod_perl handler for displaying the details of a
feature.  It inherits from Bio::GMOD::CMap::Apache where all the error
handling occurs (which is why I can just "die" here).

=head1 SEE ALSO

L<perl>, Bio::GMOD::CMap::Apache.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
