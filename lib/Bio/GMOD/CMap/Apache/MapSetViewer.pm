package Bio::GMOD::CMap::Apache::MapSetViewer;

# $Id: MapSetViewer.pm,v 1.9 2003-09-04 17:48:32 kycl4rk Exp $

use strict;
use vars qw( $VERSION $PAGE_SIZE $MAX_PAGES );
$VERSION = (qw$Revision: 1.9 $)[-1];

use Apache::Constants;
use Data::Pageset;
use Bio::GMOD::CMap::Apache;
use base 'Bio::GMOD::CMap::Apache';

use Data::Dumper;

use constant TEMPLATE => 'map_set_info.tmpl';

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;
    $self->data_source( $apr->param('data_source') );

    my $page_no        = $apr->param('page_no') || 1;
    my @map_set_aids   = split( /,/, $apr->param('map_set_aid') );
    my $data_module    = $self->data_module;
    my $data           = $data_module->map_set_viewer_data(
        map_set_aids   => \@map_set_aids,
        species_aid    => $apr->param('species_aid')  || '',
        map_type_aid   => $apr->param('map_type_aid') || '',
    ) or return $self->error( $data_module->error );
    my $map_sets       = $data->{'map_sets'};

    $PAGE_SIZE ||= $self->config('max_child_elements') || 0;
    $MAX_PAGES ||= $self->config('max_search_pages')   || 1;

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $pager            =  Data::Pageset->new( {
        total_entries    => scalar @$map_sets,
        entries_per_page => $PAGE_SIZE,
        current_page     => $page_no,
        pages_per_set    => $MAX_PAGES,
    } );
    $map_sets = [ $pager->splice( $map_sets ) ] if @$map_sets;

    my $html;
    my $t = $self->template;
    $t->process( 
        TEMPLATE, 
        { 
            apr              => $apr,
            page             => $self->page,
            stylesheet       => $self->stylesheet,
            data_sources     => $self->data_sources,
            map_sets         => $map_sets,
            pager            => $pager,
            show_restriction => @map_set_aids ? 0 : 1,
            species          => $data->{'species'},
            map_types        => $data->{'map_types'},
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

=head1 COPYRIGHT

Copyright (c) 2002-3 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
