package Bio::GMOD::CMap::Apache::FeatureSearch;

# $Id: FeatureSearch.pm,v 1.12 2003-07-15 03:11:46 kycl4rk Exp $

use strict;
use vars qw( $VERSION $PAGE_SIZE $MAX_PAGES );
$VERSION = (qw$Revision: 1.12 $)[-1];

use Apache::Constants;

use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use Data::Pageset;
use base 'Bio::GMOD::CMap::Apache';

use Data::Dumper;

use constant TEMPLATE => 'feature_search.tmpl';

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr )    = @_;
    my $preferences       = $apr->pnotes('PREFERENCES')       || {};
    my $features          = $apr->param('features')           || 
                            $preferences->{'features'}        || 
                            $preferences->{'highlight'}       || '';
    my $order_by          = $apr->param('order_by')           || '';
    my $page_no           = $apr->param('page_no')            ||  1;
    my $search_field      = $apr->param('search_field')       || '';
    my @species_aids      = ( $apr->param('species_aid')      );
    my @feature_type_aids = ( $apr->param('feature_type_aid') );

    $self->data_source( $apr->param('data_source') );

    $PAGE_SIZE ||= $self->config('max_child_elements') || 0;
    $MAX_PAGES ||= $self->config('max_search_pages')   || 1;

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
    # "-1" is a reserved value meaning "All."
    #
    @species_aids      = () if grep { /^-1$/ } @species_aids;
    @feature_type_aids = () if grep { /^-1$/ } @feature_type_aids;

    #
    # Set the parameters in the request object.
    #
    $apr->param( features               => $features                         );
    $apr->param( species_aids           => join(',', @species_aids         ) );
    $apr->param( feature_type_aids      => join(',', @feature_type_aids    ) );

    my $data              = $self->data_module or return;
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
    my $pager = Data::Pageset->new( {
        total_entries    => scalar @{ $results->{'data'} },
        entries_per_page => $PAGE_SIZE,
        current_page     => $page_no,
        pages_per_set    => $MAX_PAGES,
    } );
    $results->{'data'} = [ $pager->splice( $results->{'data'} ) ];

    my $html;
    my $t = $self->template;
    $t->process( 
        TEMPLATE, 
        { 
            apr                 => $apr, 
            page                => $self->page,
            pager               => $pager,
            stylesheet          => $self->stylesheet,
            species             => $results->{'species'},
            feature_types       => $results->{'feature_types'},
            search_results      => $results->{'data'},
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

=head1 COPYRIGHT

Copyright (c) 2002-3 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
