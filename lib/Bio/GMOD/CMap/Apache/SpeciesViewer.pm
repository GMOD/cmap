package Bio::GMOD::CMap::Apache::SpeciesViewer;
# vim: set ft=perl:

# $Id: SpeciesViewer.pm,v 1.2 2003-10-22 00:20:49 kycl4rk Exp $

use strict;
use vars qw( $VERSION $PAGE_SIZE $MAX_PAGES $INTRO );
$VERSION = (qw$Revision: 1.2 $)[-1];

use Apache::Constants;
use Data::Pageset;
use Bio::GMOD::CMap::Apache;
use base 'Bio::GMOD::CMap::Apache';

use Data::Dumper;

use constant TEMPLATE => 'species_info.tmpl';

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;
    $self->data_source( $apr->param('data_source') ) or return;

    my $page_no        = $apr->param('page_no') || 1;
    my @species_aids   = split( /,/, $apr->param('species_aid') );
    my $data_module    = $self->data_module;
    my $species        = $data_module->species_viewer_data(
        species_aids   => \@species_aids,
    ) or return $self->error( $data_module->error );

    $PAGE_SIZE ||= $self->config('max_child_elements') || 0;
    $MAX_PAGES ||= $self->config('max_search_pages')   || 1;

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $pager            =  Data::Pageset->new( {
        total_entries    => scalar @$species,
        entries_per_page => $PAGE_SIZE,
        current_page     => $page_no,
        pages_per_set    => $MAX_PAGES,
    } );
    $species = [ $pager->splice( $species ) ] if @$species;

    my $t = $self->template;
    for my $s ( @$species ) {
        for my $xref ( @{ $s->{'xrefs'} } ) {
            next if $xref->{'object_id'} && 
                $xref->{'object_id'} != $s->{'species_id'};
            my $url;
            $t->process( \$xref->{'xref_url'}, { object => $s }, \$url );
            $xref->{'xref_url'} = $url;
        }
    }

    $INTRO ||= $self->config('species_info_intro') || '';

    my $html;
    $t->process( 
        TEMPLATE, 
        { 
            apr              => $apr,
            page             => $self->page,
            stylesheet       => $self->stylesheet,
            data_sources     => $self->data_sources,
            species          => $species,
            pager            => $pager,
            intro            => $INTRO,
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
