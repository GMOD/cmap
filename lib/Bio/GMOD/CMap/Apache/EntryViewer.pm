package Bio::GMOD::CMap::Apache::EntryViewer;
# vim: set ft=perl:


use strict;
use vars qw( $VERSION $INTRO );
$VERSION = (qw$Revision: 1.3.2.2 $)[-1];

use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use Template;
use Data::Dumper;

use base 'Bio::GMOD::CMap::Apache';
use constant TEMPLATE     => 'entry_viewer.tmpl';

# ----------------------------------------------------
sub handler {
#
# Main entry point.  Decides whether we forked and whether to 
# read session data.  Calls "show_form."
#
    my ( $self, $apr ) = @_;
    my $ref_species_aid       = $apr->param('ref_species_aid')       || '';
    my $ref_map_set_aid       = $apr->param('ref_map_set_aid')       || '';
    my $ref_map_names         = $apr->param('ref_map_names')         || '';
    my $min_correspondence_maps   = $apr->param('min_correspondence_maps')   || 0;
    my $name_search           = $apr->param('name_search')           || '';
    my $order_by              = $apr->param('order_by')              || '';
    my $page_index_start      = $apr->param('page_index_start')      || 1;
    my $page_index_stop       = $apr->param('page_index_stop')       || 20;

    $INTRO ||= $self->config_data('map_viewer_intro', $self->data_source)||'';

    #
    # Take the feature types either from the query string (first
    # choice, splitting the string on commas) or from the POSTed 
    # form <select>.
    #
    my @ref_map_aids;
    if ( $apr->param('ref_map_aid') ) {
        @ref_map_aids = split( /,/,  $apr->param('ref_map_aid') );
    }
    elsif ( $apr->param('ref_map_aids') ) {
        @ref_map_aids = ( $apr->param('ref_map_aids') );
    }

    my @feature_types;
    if ( defined($apr->param('feature_types')) ) {
        @feature_types = ( $apr->param('feature_types') );
    }
    elsif ( $apr->param('included_feature_types') ) {
        @feature_types = split( /,/, $apr->param('included_feature_types') );
    }
    my @corr_only_feature_types;
    if ( defined($apr->param('corr_only_feature_types')) ) {
        @corr_only_feature_types = ( $apr->param('corr_only_feature_types') );
    }
    my %included_corr_only_features = map{$_=>1} @corr_only_feature_types;

    my @evidence_types;
    if ( $apr->param('evidence_types') ) {
        @evidence_types = ( $apr->param('evidence_types') );
    }
    elsif ( $apr->param('included_evidence_types') ) {
        @evidence_types = split( /,/, $apr->param('included_evidence_types') );
    }

    #
    # Set the data source.
    #
    $self->data_source( $apr->param('data_source') ) or return;

    my ( $ref_field, $ref_value );
    if ( grep {/^-1$/} @ref_map_aids ) {
        $ref_field = 'map_set_aid';
        $ref_value = $ref_map_set_aid;
    }
    else {
        $ref_field = 'map_aid';
        $ref_value = \@ref_map_aids;
    }

    my %slots = (
        0 => {
            field       => $ref_field,
            aid         => $ref_value,
            start       => '',
            stop        => '',
            map_set_aid => $ref_map_set_aid,
            map_names   => $ref_map_names,
        },
    );

    
    #
    # Get the data for the form.
    #
    my $data                   = $self->data_module;
    my $form_data              = $data->cmap_entry_data( 
        slots                  => \%slots,
        min_correspondence_maps    => $min_correspondence_maps,
        included_feature_types  => \@feature_types,
        included_evidence_types => \@evidence_types,
        ref_species_aid        => $ref_species_aid,
        page_index_start       => $page_index_start,
        page_index_stop        => $page_index_stop,
        name_search            => $name_search,
        order_by               => $order_by,
    ) or return $self->error( $data->error );

    #
    # The start and stop may have had to be moved as there 
    # were too few or too many features in the selected region.
    #
    $apr->param( ref_map_start   => $form_data->{'ref_map_start'}   );
    $apr->param( ref_map_stop    => $form_data->{'ref_map_stop'}    );
    $apr->param( ref_map_names   => $ref_map_names                  );
    $apr->param( ref_map_aids    => join(',', @ref_map_aids)        );
    $apr->param( ref_species_aid => $form_data->{'ref_species_aid'} );
    $apr->param( ref_map_set_aid => $form_data->{'ref_map_set_aid'} );

    my $url_sort_tmpl = "/entry?ref_species_aid=$ref_species_aid&ref_map_set_aid=$ref_map_set_aid&ref_map_names=$ref_map_names&min_correspondence_maps=$min_correspondence_maps&name_search=$name_search&page_index_start=$page_index_start&page_index_stop=$page_index_stop";

    my $html;
    my $t = $self->template or return;
    $t->process( 
        TEMPLATE, 
        {
            apr                 => $apr,
            form_data           => $form_data,
            page_index_start    => $page_index_start,
            page_index_stop     => $page_index_stop,
            name_search         => $name_search,
            cur_order_by        => $order_by,
            url_sort_tmpl       => $url_sort_tmpl,
            min_correspondence_maps => $min_correspondence_maps,
            page                => $self->page,
            debug               => $self->debug,
            intro               => $INTRO,
            url_sort_tmpl       => $url_sort_tmpl,
            data_source         => $self->data_source,
            data_sources        => $self->data_sources,
            title               => 'Welcome to CMap',
            stylesheet          => $self->stylesheet,
            selected_maps       => { map { $_, 1 } @ref_map_aids   },
            included_features   => { map { $_, 1 } @feature_types  },
            included_evidence   => { map { $_, 1 } @evidence_types },
            included_corr_only_features => \%included_corr_only_features,
            feature_types       => join( ',', @feature_types ),
            evidence_types      => join( ',', @evidence_types ),
        },
        \$html 
    ) or $html = $t->error;

    print $apr->header( -type => 'text/html', -cookie => $self->cookie ), $html;
    return 1;
}

1;

# ----------------------------------------------------
# Prisons are built with stones of Law,
# Brothels with bricks of Religion.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::EntryViewer - entry page to view comparative maps

=head1 SYNOPSIS

In httpd.conf:

  <Location /cmap/entry>
      SetHandler  perl-script
      PerlHandler Bio::GMOD::CMap::Apache::EntryViewer->super
  </Location>

=head1 DESCRIPTION

This module is a mod_perl handler for directing the user to 
comparative maps.  It inherits from
Bio::GMOD::CMap::Apache where all the error handling occurs.

Added forking to allow creation of really large maps.  Stole most of
the implementation from Randal Schwartz:

    http://www.stonehenge.com/merlyn/LinuxMag/col39.html

=head1 SEE ALSO

L<perl>, L<Template>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.
Ben Faga E<lt>faga@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
