package Bio::GMOD::CMap::Apache::FeatureSearch;

# $Id: FeatureSearch.pm,v 1.6 2003-02-11 00:23:11 kycl4rk Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.6 $)[-1];

use Apache::Constants;

use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use Bio::GMOD::CMap::Utils 'paginate';
use base 'Bio::GMOD::CMap::Apache';

use Data::Dumper;

use constant TEMPLATE => 'feature_search.tmpl';

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr )    = @_;
    my $preferences       = $apr->pnotes('PREFERENCES')     || {};
    my $features          = $apr->param('features')         || 
                            $preferences->{'features'}      || 
                            $preferences->{'highlight'}     || '';
    my $order_by          = $apr->param('order_by')         || '';
    my $limit_start       = $apr->param('limit_start')      ||  0;
    my $search_field      = $apr->param('search_field')     || '';
    my @species_aids      = ( $apr->param('species_aid')      );
    my @feature_type_aids = ( $apr->param('feature_type_aid') );

    $self->data_source( $apr->param('data_source') );

    #
    # Because I need a <select> element on the search form, I could
    # get the species and feature type acc. IDs as an array.  However,
    # if the user clicks on a link in the pager, then I have to look
    # in the "*_aids" field, which is a comma-separated string of acc. IDs.
    #
    unless ( @species_aids ) {
        @species_aids = split /,/, $apr->param('species_aids');
    }

    unless ( @feature_type_aids ) {
        @feature_type_aids = split /,/, $apr->param('feature_type_aids');
    }

    #
    # Set the parameters in the request object.
    #
    $apr->param( features               => $features                         );
    $apr->param( species_aids           => join(',', @species_aids         ) );
    $apr->param( feature_type_aids      => join(',', @feature_type_aids    ) );

    my $data              = $self->data_module;
    my $results           =  $data->feature_search_data(
        features          => $features,
        order_by          => $order_by,
        search_field      => $search_field,
        species_aids      => \@species_aids,
        feature_type_aids => \@feature_type_aids,
    );

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $page_data   =  paginate( 
        self        => $self,
        data        => $results->{'data'},
        limit_start => $limit_start,
    );

    my $html;
    my $t = $self->template;
    $t->process( 
        TEMPLATE, 
        { 
            apr                 => $apr, 
            page                => $self->page,
            stylesheet          => $self->stylesheet,
            species             => $results->{'species'},
            feature_types       => $results->{'feature_types'},
            search_results      => $page_data->{'data'},
            no_elements         => $page_data->{'no_elements'},
            page_size           => $page_data->{'page_size'},
            pages               => $page_data->{'pages'},
            cur_page            => $page_data->{'cur_page'},
            show_start          => $page_data->{'show_start'},
            show_stop           => $page_data->{'show_stop'},
            species_lookup      => { map { $_, 1 } @species_aids      },
            feature_type_lookup => { map { $_, 1 } @feature_type_aids },
            data_sources        => $self->data_sources,
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
