package Bio::GMOD::CMap::Apache::MatrixViewer;
# vim: set ft=perl:

# $Id: MatrixViewer.pm,v 1.10 2004-02-10 22:50:09 kycl4rk Exp $

use strict;
use vars qw( $VERSION $INTRO );
$VERSION = (qw$Revision: 1.10 $)[-1];

use Bio::GMOD::CMap::Apache;
use base 'Bio::GMOD::CMap::Apache';

use constant TEMPLATE => 'matrix.tmpl';

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr )   = @_;
    my $show_matrix      = $apr->param('show_matrix')      ||  0;
    my $species_aid      = $apr->param('species_aid')      || '';
    my $map_type_aid     = $apr->param('map_type_aid')     || '';
    my $map_set_aid      = $apr->param('map_set_aid')      || '';
    my $map_name         = $apr->param('map_name')         || '';
    my $link_map_set_aid = $apr->param('link_map_set_aid') || '';
    my $prev_species_aid = $apr->param('prev_species_aid') || '';
    my $prev_map_set_aid = $apr->param('prev_map_set_id')  || '';
    my $prev_map_name    = $apr->param('prev_map_name')    || '';

    $self->data_source( $apr->param('data_source') ) or return;

    if ( $prev_species_aid && $species_aid != $prev_species_aid ) {
        $map_set_aid = '';
        $map_name    = '';
    }

    my $data_module      =  $self->data_module;
    my $data             =  $data_module->matrix_correspondence_data(
        show_matrix      => $show_matrix,
        species_aid      => $species_aid,
        map_type_aid     => $map_type_aid,
        map_set_aid      => $map_set_aid,
        map_name         => $map_name,
        link_map_set_aid => $link_map_set_aid,
    ) or return $self->error( $data_module->error );

    $apr->param( species_aid  => $data->{'species_aid'}  );
    $apr->param( map_type_aid => $data->{'map_type_aid'} );
    $apr->param( map_set_aid  => $data->{'map_set_aid'}  );
    $apr->param( map_name     => $data->{'map_name'}     );

    $INTRO ||= $self->config('matrix_intro') || '';

    my $html;
    my $t = $self->template;
    $t->process( 
        TEMPLATE, 
        { 
            apr          => $apr,
            page         => $self->page,
            top_row      => $data->{'top_row'},
            matrix       => $data->{'matrix'}, 
            title        => $self->config('matrix_title'),
            species      => $data->{'species'},
            map_types    => $data->{'map_types'},
            map_sets     => $data->{'map_sets'},
            maps         => $data->{'maps'},
            stylesheet   => $self->stylesheet,
            data_sources => $self->data_sources,
            intro        => $INTRO,
        },
        \$html 
    ) or $html = $t->error;

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

Bio::GMOD::CMap::Apache::MatrixViewer - view correspondence matrix

=head1 SYNOPSIS

In httpd.conf:

  <Location /cmap/matrix>
      SetHandler  perl-script
      PerlHandler Bio::GMOD::CMap::Apache::MatrixViewer->super
  </Location>

=head1 DESCRIPTION

Show all the correspondences amongst all the maps.

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
