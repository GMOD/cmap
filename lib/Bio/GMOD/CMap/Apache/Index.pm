package Bio::GMOD::CMap::Apache::Index;

# $Id: Index.pm,v 1.4 2003-02-20 16:50:07 kycl4rk Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.4 $)[-1];

use Apache::Constants;
use Data::Dumper;

use Bio::GMOD::CMap::Apache;
use base 'Bio::GMOD::CMap::Apache';

use constant TEMPLATE => 'index.tmpl';

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr )   = @_;
    my $html;
    my $t = $self->template;
    $t->process( 
        TEMPLATE, 
        { 
            page       => $self->page,
            stylesheet => $self->stylesheet,
        }, 
        \$html 
    ) or $html = $t->error;

    $apr->content_type('text/html');
    $apr->send_http_header;
    $apr->print( $html );
    return OK;
}

1;

# ----------------------------------------------------
# You never know what is enough
# Until you know what is more than enough.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::Index - index page

=head1 SYNOPSIS

In httpd.conf:

  <Location /cmap>
      SetHandler  perl-script
      PerlHandler Bio::GMOD::CMap::Apache
  </Location>

=head1 DESCRIPTION

When "/cmap" is called with no path, this will be the default handler.

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2002-3 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
