package Bio::GMOD::CMap::Apache::MapSetViewer;

# $Id: MapSetViewer.pm,v 1.5 2003-02-11 00:23:11 kycl4rk Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.5 $)[-1];

use Apache::Constants;
use Bio::GMOD::CMap::Apache;
use base 'Bio::GMOD::CMap::Apache';

use constant TEMPLATE => 'map_set_info.tmpl';

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;
    my @map_set_aids   = split( /,/, $apr->param('map_set_aid') );
    $self->data_source( $apr->param('data_source') );
    my $data           = $self->data_module;
    my $map_sets       = $data->map_set_viewer_data(
        map_set_aids   => \@map_set_aids
    );

    my $html;
    my $t = $self->template;
    $t->process( 
        TEMPLATE, 
        { 
            map_sets     => $map_sets,
            page         => $self->page,
            stylesheet   => $self->stylesheet,
            data_sources => $self->data_sources,
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
# Where man is not nature is barren.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::MapSetViewer - 
    show information on one or more map sets

=head1 SYNOPSIS

In httpd.conf:

  <Location /cmap/map_set_info>
      SetHandler  perl-script
      PerlHandler Bio::GMOD::CMap::Apache::MapSetViewer->super
  </Location>

=head1 DESCRIPTION

Show the information on one or more map sets (identified by map set accession
IDs, separated by commas) or all map sets.

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

Copyright (c) 2002 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
