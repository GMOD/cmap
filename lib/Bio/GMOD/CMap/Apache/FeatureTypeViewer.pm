package Bio::GMOD::CMap::Apache::FeatureTypeViewer;

# vim: set ft=perl:

# $Id: FeatureTypeViewer.pm,v 1.14 2007-09-28 20:17:08 mwz444 Exp $

use strict;
use vars qw( $VERSION $PAGE_SIZE $MAX_PAGES $INTRO );
$VERSION = (qw$Revision: 1.14 $)[-1];

use Data::Pageset;
use Bio::GMOD::CMap::Apache;
use base 'Bio::GMOD::CMap::Apache';

use constant TEMPLATE => 'feature_type_info.tmpl';

sub handler {

    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;
    $self->data_source( $apr->param('data_source') ) or return;

    my $page_no = $apr->param('page_no') || 1;
    my @ft_accs =
      split( /,/,
             $apr->param('feature_type_acc')
          || $apr->param('feature_type_aid')
          || $apr->param('feature_type') );
    my $data_module = $self->data_module;
    my $data        =
      $data_module->feature_type_info_data( feature_types => \@ft_accs, )
      or return $self->error( $data_module->error );
    my $feature_types = $data->{'feature_types'};

    $PAGE_SIZE ||= $self->config_data('max_child_elements') || 0;
    $MAX_PAGES ||= $self->config_data('max_search_pages')   || 1;

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $returned = scalar @{ $feature_types || [] };
    my $pager = Data::Pageset->new(
        {
            total_entries    => $returned,
            current_page     => $page_no,
            entries_per_page => $PAGE_SIZE,
            pages_per_set    => $MAX_PAGES,
        }
    );
    $feature_types = [ $pager->splice($feature_types) ] if $returned;

    for my $ft (@$feature_types) {
        $self->object_plugin( 'feature_type_info', $ft );
    }

    $INTRO ||= $self->config_data('feature_type_info_intro') || '';

    my $html;
    my $t = $self->template;
    $t->process(
        TEMPLATE,
        {   apr                 => $apr,
            page                => $self->page,
            stylesheet          => $self->stylesheet,
            data_sources        => $self->data_sources,
            feature_types       => $feature_types,
            all_feature_types   => $data->{'all_feature_types'},
            pager               => $pager,
            intro               => $INTRO,
            web_image_cache_dir => $self->web_image_cache_dir(),
            web_cmap_htdocs_dir => $self->web_cmap_htdocs_dir(),
        },
        \$html
        )
        or $html = $t->error;

    print $apr->header( -type => 'text/html', -cookie => $self->cookie ), $html;
    return 1;
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

Ben Faga E<lt>faga@cshl.eduE<gt>.
Ken Y. Clark E<lt>kclark@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-6 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

