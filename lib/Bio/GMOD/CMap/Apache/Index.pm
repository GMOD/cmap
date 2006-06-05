package Bio::GMOD::CMap::Apache::Index;
# vim: set ft=perl:

# $Id: Index.pm,v 1.10 2006-06-05 21:21:38 mwz444 Exp $

use strict;
use vars qw( $VERSION $INTRO );
$VERSION = (qw$Revision: 1.10 $)[-1];

use Bio::GMOD::CMap::Apache;
use base 'Bio::GMOD::CMap::Apache';

use constant TEMPLATE => 'index.tmpl';

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr )   = @_;

    $INTRO ||= $self->config_data('cmap_home_intro') || '';

    my $html;
    my $t = $self->template or return;
    $t->process(
        TEMPLATE,
        {   apr                 => $self->apr,
            page                => $self->page,
            intro               => $INTRO,
            stylesheet          => $self->stylesheet,
            web_image_cache_dir => $self->web_image_cache_dir(),
            web_cmap_htdocs_dir => $self->web_cmap_htdocs_dir(),
        },
        \$html
        )
        or $html = $t->error;

    print $apr->header( -type => 'text/html', -cookie => $self->cookie ), $html;
    return 1;
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

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
