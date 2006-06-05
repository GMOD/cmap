package Bio::GMOD::CMap::Apache::DataDownloader;

# vim: set ft=perl:

# $Id: DataDownloader.pm,v 1.5 2006-06-05 21:21:36 mwz444 Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.5 $)[-1];

use Bio::GMOD::CMap::Apache;
use base 'Bio::GMOD::CMap::Apache';

use constant TEMPLATE => 'data_downloader.tmpl';

sub handler {

    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;

    if ( $apr->param('download') ) {
        $self->data_source( $apr->param('data_source') ) or return;

        my $page_no     = $apr->param('page_no') || 1;
        my $data_module = $self->data_module;
        my $data        = $data_module->data_download(
            map_set_acc => $apr->param('map_set_acc')
              || $apr->param('map_set_aid')
              || '',
            map_acc => $apr->param('map_acc') || $apr->param('map_aid') || '',
            format => $apr->param('format') || '',
          )
          or return $self->error( $data_module->error );

        print $apr->header( -type => 'text/plain', -cookie => $self->cookie ),
          $data;
    }
    else {
        my $html;
        my $t = $self->template;
        $t->process(
            TEMPLATE,
            {   apr                 => $apr,
                page                => $self->page,
                stylesheet          => $self->stylesheet,
                web_image_cache_dir => $self->web_image_cache_dir(),
                web_cmap_htdocs_dir => $self->web_cmap_htdocs_dir(),
            },
            \$html
            )
            or $html = $t->error;

        print $apr->header( -type => 'text/html', -cookie => $self->cookie ),
          $html;

    }

    return 1;
}

1;

# ----------------------------------------------------
# Where man is not nature is barren.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::DataDownloader - print out tab-delimited data 

=head1 DESCRIPTION

For downloading of map or map set data.

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

