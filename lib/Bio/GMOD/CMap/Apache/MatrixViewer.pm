package Bio::GMOD::CMap::Apache::MatrixViewer;
# vim: set ft=perl:

# $Id: MatrixViewer.pm,v 1.16 2005-07-13 17:53:04 mwz444 Exp $

use strict;
use vars qw( $VERSION $INTRO );
$VERSION = (qw$Revision: 1.16 $)[-1];

use Bio::GMOD::CMap::Apache;
use base 'Bio::GMOD::CMap::Apache';

use constant TEMPLATE => 'matrix.tmpl';

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr )   = @_;
    my $show_matrix      = $apr->param('show_matrix')      ||  0;
    my $species_acc      = $apr->param('species_acc')      || '';
    my $map_type_acc     = $apr->param('map_type_acc')     || '';
    my $map_set_acc      = $apr->param('map_set_acc')      || '';
    my $map_name         = $apr->param('map_name')         || '';
    my $hide_empty_rows  = $apr->param('hide_empty_rows')  || '';
    my $link_map_set_acc = $apr->param('link_map_set_acc') || '';
    my $prev_species_acc = $apr->param('prev_species_acc') || '';
    my $prev_map_set_acc = $apr->param('prev_map_set_id')  || '';
    my $prev_map_name    = $apr->param('prev_map_name')    || '';

    $self->data_source( $apr->param('data_source') ) or return;

    if ( $prev_species_acc && $species_acc != $prev_species_acc ) {
        $map_set_acc = '';
        $map_name    = '';
    }

    my $data_module      =  $self->data_module;
    my $data             =  $data_module->matrix_correspondence_data(
        show_matrix      => $show_matrix,
        species_acc      => $species_acc,
        map_type_acc     => $map_type_acc,
        map_set_acc      => $map_set_acc,
        map_name         => $map_name,
        hide_empty_rows  => $hide_empty_rows,
        link_map_set_acc => $link_map_set_acc,
    ) or return $self->error( $data_module->error );

    $apr->param( species_acc  => $data->{'species_acc'}  );
    $apr->param( map_type     => $data->{'map_type'} );
    $apr->param( map_set_acc  => $data->{'map_set_acc'}  );
    $apr->param( map_name     => $data->{'map_name'}     );

    $INTRO ||= $self->config_data('matrix_intro') || '';

    my $html;
    my $t = $self->template;
    $t->process( 
        TEMPLATE, 
        { 
            apr          => $apr,
            page         => $self->page,
            top_row      => $data->{'top_row'},
            matrix       => $data->{'matrix'}, 
            title        => $self->config_data('matrix_title'),
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
