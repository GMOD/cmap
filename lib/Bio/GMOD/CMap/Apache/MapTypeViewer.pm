package Bio::GMOD::CMap::Apache::MapTypeViewer;
# vim: set ft=perl:

# $Id: MapTypeViewer.pm,v 1.2.2.1 2004-06-18 22:05:47 kycl4rk Exp $

use strict;
use vars qw( $VERSION $PAGE_SIZE $MAX_PAGES $INTRO );
$VERSION = (qw$Revision: 1.2.2.1 $)[-1];

use Data::Pageset;
use Bio::GMOD::CMap::Apache;
use base 'Bio::GMOD::CMap::Apache';

use constant TEMPLATE => 'map_type_info.tmpl';

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;
    $self->data_source( $apr->param('data_source') ) or return;

    my $page_no        = $apr->param('page_no') || 1;
    my @map_type_aids  = split( /,/, $apr->param('map_type_aid') );
    my $data_module    = $self->data_module;
    my $data           = $data_module->map_type_viewer_data(
        map_type_aids  => \@map_type_aids,
    ) or return $self->error( $data_module->error );
    my $map_types      = $data->{'map_types'};

    $PAGE_SIZE ||= $self->config('max_child_elements') || 0;
    $MAX_PAGES ||= $self->config('max_search_pages')   || 1;

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $pager            =  Data::Pageset->new( {
        total_entries    => scalar @$map_types,
        entries_per_page => $PAGE_SIZE,
        current_page     => $page_no,
        pages_per_set    => $MAX_PAGES,
    } );
    $map_types = [ $pager->splice( $map_types ) ] if @$map_types;

    $INTRO ||= $self->config('map_type_info_intro') || '';

    my $html;
    my $t = $self->template;
    $t->process( 
        TEMPLATE, 
        { 
            apr           => $apr,
            page          => $self->page,
            stylesheet    => $self->stylesheet,
            data_sources  => $self->data_sources,
            map_types     => $map_types,
            all_map_types => $data->{'all_map_types'},
            pager         => $pager,
            intro         => $INTRO,
        },
        \$html 
    ) or $html = $t->error;

    print $apr->header( -type => 'text/html', -cookie => $self->cookie ), $html;
    return 1;
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

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
