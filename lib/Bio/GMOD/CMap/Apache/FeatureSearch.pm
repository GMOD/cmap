package Bio::GMOD::CMap::Apache::FeatureSearch;

# $Id: FeatureSearch.pm,v 1.2 2002-08-27 22:18:42 kycl4rk Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.2 $)[-1];

use Apache::Constants;

use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use base 'Bio::GMOD::CMap::Apache';

use constant TEMPLATE => 'feature_search.tmpl';

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr )   = @_;
    my $preferences      = $apr->pnotes('PREFERENCES')     || {};
    my $features         = $apr->param('features')         || 
                           $preferences->{'features'}      || 
                           $preferences->{'highlight'}     || '';
    my $order_by         = $apr->param('order_by')         || '';
    my $species_id       = $apr->param('species_id')       ||  0;
    my $feature_type_id  = $apr->param('feature_type_id')  ||  0;
    my $limit_start      = $apr->param('limit_start')      ||  0;
    my $limit_end        = $apr->param('limit_end')        ||  0;
    my $search_field     = $apr->param('search_field')     || '';
    my $feature_type_aid = $apr->param('feature_type_aid') || '';

    my $data             =  Bio::GMOD::CMap::Data->new;
    my $results          =  $data->feature_search_data(
        features         => $features,
        order_by         => $order_by,
        search_field     => $search_field,
        species_id       => $species_id,
        feature_type_aid => $feature_type_aid,
        limit_start      => $limit_start,
        limit_end        => $limit_end,
    );

    $apr->param( features => $features );
    my $max_child_elements = $self->config('max_child_elements') || 1;

    my $html;
    my $t = $self->template;
    $t->process( 
        TEMPLATE, 
        { 
            apr             => $apr, 
            page            => $self->page,
            species         => $results->{'species'},
            feature_types   => $results->{'feature_types'},
            search_results  => $results->{'data'},
            result_set_size => $results->{'result_set_size'},
            limit_start     => $results->{'limit_start'},
            limit_end       => $results->{'limit_end'},
            page_size       => $max_child_elements,
            no_pages        => $results->{'no_pages'},
        },
        \$html 
    ) 
    or $html = $t->error;

    $apr->content_type('text/html');
    $apr->send_http_header;
    $apr->print( $html );
    return OK;
}

1;

# ----------------------------------------------------
# All men want, not something to do with,
# but something to do,
# or rather something to be.
# Henry David Thoreau
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::FeatureSearch - find features

=head1 SYNOPSIS

In httpd.conf:

  <Location /cmap/feature>
      SetHandler  perl-script
      PerlHandler Bio::GMOD::CMap::Apache::FeatureSearch->super
  </Location>

=head1 DESCRIPTION

This module presents the user a form for searching for features on maps 
and the results of those searches.

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

Copyright (c) 2002 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
