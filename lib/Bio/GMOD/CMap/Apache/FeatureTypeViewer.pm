package Bio::GMOD::CMap::Apache::FeatureTypeViewer;

# $Id: FeatureTypeViewer.pm,v 1.1 2003-09-08 17:15:47 kycl4rk Exp $

use strict;
use vars qw( $VERSION $PAGE_SIZE $MAX_PAGES );
$VERSION = (qw$Revision: 1.1 $)[-1];

use Apache::Constants;
use Data::Pageset;
use Bio::GMOD::CMap::Apache;
use base 'Bio::GMOD::CMap::Apache';

use Data::Dumper;

use constant TEMPLATE => 'feature_type_info.tmpl';

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;
    $self->data_source( $apr->param('data_source') );

    my $page_no           = $apr->param('page_no') || 1;
    my @ft_aids           = split( /,/, $apr->param('feature_type_aid') );
    my $data_module       = $self->data_module;
    my $feature_types     = $data_module->feature_type_info_data(
        feature_type_aids => \@ft_aids,
    ) or return $self->error( $data_module->error );

    $PAGE_SIZE ||= $self->config('max_child_elements') || 0;
    $MAX_PAGES ||= $self->config('max_search_pages')   || 1;

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $returned         =  scalar @{ $feature_types || [] };
    my $pager            =  Data::Pageset->new( {
        total_entries    => $returned,
        current_page     => $page_no,
        entries_per_page => $PAGE_SIZE,
        pages_per_set    => $MAX_PAGES,
    } );
    $feature_types = [ $pager->splice( $feature_types ) ] if $returned;

    print STDERR Dumper($feature_types), "\n";

    my $html;
    my $t = $self->template;
    $t->process( 
        TEMPLATE, 
        { 
            apr              => $apr,
            page             => $self->page,
            stylesheet       => $self->stylesheet,
            data_sources     => $self->data_sources,
            feature_types    => $feature_types,
            pager            => $pager,
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
# 'Tis well to be bereft of promis'd good,
# That we may lift the soul, and contemplate
# With lively joy the joys we cannot share.
# Samuel Taylor Coleridge
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
