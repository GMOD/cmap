package Bio::GMOD::CMap::Apache::FeatureSearch;
# vim: set ft=perl:

# $Id: FeatureSearch.pm,v 1.20 2004-06-16 17:31:28 mwz444 Exp $

use strict;
use vars qw( $VERSION $PAGE_SIZE $MAX_PAGES $INTRO );
$VERSION = (qw$Revision: 1.20 $)[-1];

use Bio::GMOD::CMap::Data;
use Data::Pageset;
use Data::Dumper;
use base 'Bio::GMOD::CMap::Apache';

use constant TEMPLATE => 'feature_search.tmpl';

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr )    = @_;
    my $features          = $apr->param('features')     || '';
    my $order_by          = $apr->param('order_by')     || '';
    my $page_no           = $apr->param('page_no')      ||  1;
    my $search_field      = $apr->param('search_field') || '';
    my @species_aids      = ( $apr->param('species_aid')      );
    my @feature_type_aids = ( $apr->param('feature_type_aid') );

    $self->data_source( $apr->param('data_source') ) or return;

    $PAGE_SIZE ||= $self->config_data('max_child_elements')   ||  0;
    $MAX_PAGES ||= $self->config_data('max_search_pages')     ||  1;
    $INTRO     ||= $self->config_data('feature_search_intro') || '';

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

    my $data              =  $self->data_module or return;
    my $results           =  $data->feature_search_data(
        features          => $features,
        order_by          => $order_by,
        search_field      => $search_field,
        species_aids      => \@species_aids,
        feature_type_aids => \@feature_type_aids,
        page_size         => $PAGE_SIZE,
        page_no           => $page_no,
        pages_per_set     => $MAX_PAGES,
        page_data         => 1,
    ) or return $self->error( $data->error );

    my $html;
    my $t = $self->template;
print STDERR Dumper(\@feature_type_aids)."\n";
print STDERR Dumper($results->{'feature_type_aids'})."\n";
    $t->process( 
        TEMPLATE, 
        { 
            apr                 => $apr, 
            page                => $self->page,
            stylesheet          => $self->stylesheet,
            pager               => $results->{'pager'},
            species             => $results->{'species'},
            feature_type_aids       => $results->{'feature_type_aids'},
            search_results      => $results->{'data'},
            species_lookup      => { map { $_, 1 } @species_aids      },
            feature_type_aid_lookup => { map { $_, 1 } @feature_type_aids },
            data_sources        => $self->data_sources,
            intro               => $INTRO,
        },
        \$html 
    ) 
    or $html = $t->error;

    print $apr->header( -type => 'text/html', -cookie => $self->cookie ), $html;
    return 1;
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

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
