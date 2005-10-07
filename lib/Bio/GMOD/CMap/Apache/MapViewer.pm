package Bio::GMOD::CMap::Apache::MapViewer;

# vim: set ft=perl:

# $Id: MapViewer.pm,v 1.117 2005-10-07 15:41:19 mwz444 Exp $

use strict;
use vars qw( $VERSION $INTRO $PAGE_SIZE $MAX_PAGES);
$VERSION = (qw$Revision: 1.117 $)[-1];

use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Drawer;
use Bio::GMOD::CMap::Data;
use Bio::GMOD::CMap::Utils;
use CGI::Session;
use Template;
use URI::Escape;
use Data::Dumper;

use base 'Bio::GMOD::CMap::Apache';
use constant TEMPLATE        => 'cmap_viewer.tmpl';
use constant DETAIL_TEMPLATE => 'map_detail_bottom.tmpl';
use constant FIELD_SEP       => "\t";
use constant RECORD_SEP      => "\n";
use constant COLUMN_NAMES    => [
    qw[ species_acc species_common_name
        map_set_acc map_set_name
        map_acc map_name
        feature_acc feature_name feature_type_acc feature_start
        feature_stop alt_species_common_name alt_map_set_name alt_map_name
        alt_feature_type alt_feature_start alt_feature_stop
        evidence
        ]
];
use constant MAP_FIELDS => [
    qw[ species_acc species_common_name map_set_acc map_set_short_name map_acc map_name ]
];
use constant FEATURE_FIELDS => [
    qw[ feature_acc feature_name feature_type_acc feature_start feature_stop ]
];
use constant POSITION_FIELDS => [
    qw[ species_common_name2 map_set_short_name2 map_name2 feature_type_acc2
        feature_start2 feature_stop2 evidence
        ]
];

# ----------------------------------------------------
sub handler {

    #
    # Main entry point.  Decides whether we forked and whether to
    # read session data.  Calls "show_form."
    #
    my ( $self, $apr ) = @_;

    # parse the url
    my %parsed_url_options = Bio::GMOD::CMap::Utils->parse_url( $apr, $self )
        or return $self->error();

    $INTRO ||= $self->config_data( 'map_viewer_intro', $self->data_source )
        || '';
    my %included_corr_only_features =
        map { $_ => 1 } @{ $parsed_url_options{'corr_only_feature_types'} };
    my %ignored_feature_types
        = map { $_ => 1 } @{ $parsed_url_options{'ignored_feature_types;'} };

    #
    # Instantiate the drawer if there's at least one map to draw.
    #
    my ( $drawer, $extra_code, $extra_form );
    if ( @{ $parsed_url_options{'ref_map_accs'} || () } ) {
        $drawer = Bio::GMOD::CMap::Drawer->new(
            apr => $apr,
            %parsed_url_options,
            )
            or return $self->error( Bio::GMOD::CMap::Drawer->error );

        $parsed_url_options{'slots'} = $drawer->{'slots'};
        $apr->param( 'left_min_corrs',  $drawer->left_min_corrs );
        $apr->param( 'right_min_corrs', $drawer->right_min_corrs );
        $extra_code = $drawer->{'data'}->{'extra_code'};
        $extra_form = $drawer->{'data'}->{'extra_form'};

        $parsed_url_options{'feature_types'}
            = $drawer->included_feature_types;
        $parsed_url_options{'corr_only_feature_types'}
            = $drawer->corr_only_feature_types;
        $parsed_url_options{'ignored_feature_types'}
            = $drawer->ignored_feature_types;
        $parsed_url_options{'ignored_evidence_types'}
            = $drawer->ignored_evidence_types;
        $parsed_url_options{'included_evidence_types'}
            = $drawer->included_evidence_types;
        $parsed_url_options{'greater_evidence_types'}
            = $drawer->greater_evidence_types;
        $parsed_url_options{'less_evidence_types'}
            = $drawer->less_evidence_types;
        %included_corr_only_features =
            map { $_ => 1 }
            @{ $parsed_url_options{'corr_only_feature_types'} };
        %ignored_feature_types = map { $_ => 1 }
            @{ $parsed_url_options{'ignored_feature_types'} };
    }

    #
    # Get the data for the form.
    #
    my $data      = $self->data_module;
    my $form_data = $data->cmap_form_data(
        slots                  => $parsed_url_options{'slots'},
        menu_min_corrs         => $parsed_url_options{'menu_min_corrs'},
        included_feature_types => $parsed_url_options{'feature_types'},
        ignored_feature_types => $parsed_url_options{'ignored_feature_types'},
        ignored_evidence_types =>
            $parsed_url_options{'ignored_evidence_types'},
        included_evidence_types =>
            $parsed_url_options{'included_evidence_types'},
        less_evidence_types    => $parsed_url_options{'less_evidence_types'},
        greater_evidence_types =>
            $parsed_url_options{'greater_evidence_types'},
        evidence_type_score => $parsed_url_options{'evidence_type_score'},
        ref_species_acc     => $parsed_url_options{'ref_species_acc'},
        ref_map_set_acc     => $parsed_url_options{'ref_map_set_acc'},
        ref_slot_data       => $drawer->{'data'}->{'slots'}{0},
        )
        or return $self->error( $data->error );

    for my $key (qw[ ref_species_acc ref_map_set_acc ]) {
        $apr->param( $key, $form_data->{$key} );
    }

    my $feature_default_display = $data->feature_default_display;

    $form_data->{'feature_types'}
        = [ sort { lc $a->{'feature_type'} cmp lc $b->{'feature_type'} }
            @{ $self->data_module->get_all_feature_types } ];

    my %evidence_type_menu_select = (
        (   map { $_ => 0 } @{ $parsed_url_options{'ignored_evidence_types'} }
        ),
        (   map { $_ => 1 }
                @{ $parsed_url_options{'included_evidence_types'} }
        ),
        ( map { $_ => 2 } @{ $parsed_url_options{'less_evidence_types'} } ),
        (   map { $_ => 3 } @{ $parsed_url_options{'greater_evidence_types'} }
        )
    );

    unless ( $parsed_url_options{'reusing_step'} ) {
        Bio::GMOD::CMap::Utils->create_session_step( \%parsed_url_options )
            or return $self->error('Problem creating the new session step.');
    }

    $apr->param( 'session_id', $parsed_url_options{'session_id'} );
    $apr->param( 'step',       $parsed_url_options{'next_step'} );

    my $html;
    my $t = $self->template or return;
    $t->process(
        TEMPLATE,
        {   apr            => $apr,
            url_for_saving => $parsed_url_options{'url_for_saving'},
            form_data      => $form_data,
            drawer         => $drawer,
            page           => $self->page,
            intro          => $INTRO,
            data_source    => $self->data_source,
            data_sources   => $self->data_sources,
            title          => $self->config_data('cmap_title') || 'CMap',
            stylesheet     => $self->stylesheet,
            selected_maps  =>
                { map { $_, 1 } @{ $parsed_url_options{'ref_map_accs'} } },
            included_features =>
                { map { $_, 1 } @{ $parsed_url_options{'feature_types'} } },
            corr_only_feature_types   => \%included_corr_only_features,
            ignored_feature_types     => \%ignored_feature_types,
            evidence_type_menu_select => \%evidence_type_menu_select,
            evidence_type_score => $parsed_url_options{'evidence_type_score'},
            feature_types       =>
                join( ',', @{ $parsed_url_options{'feature_types'} } ),
            evidence_types => join( ',',
                @{ $parsed_url_options{'included_evidence_types'} } ),
            extra_code              => $extra_code,
            extra_form              => $extra_form,
            feature_default_display => $feature_default_display,
            no_footer => $parsed_url_options{'path_info'} eq 'map_details' ? 1
            : 0,
            prev_ref_map_order => $self->ref_map_order(),
            no_footer => $parsed_url_options{'path_info'} eq 'map_details' ? 1
            : 0,
        },
        \$html
        )
        or $html = $t->error;

    if ( $parsed_url_options{'path_info'} eq 'map_details'
        and scalar( keys %{ $parsed_url_options{'ref_maps'} } ) == 1 )
    {
        $PAGE_SIZE ||= $self->config_data('max_child_elements') || 0;
        $MAX_PAGES ||= $self->config_data('max_search_pages')   || 1;
        my ($map_acc) = keys %{ $parsed_url_options{'ref_maps'} };
        my $map_id = $self->sql->acc_id_to_internal_id(
            cmap_object => $self,
            object_type => 'map',
            acc_id      => $map_acc,
        );

        my $detail_data = $data->map_detail_data(
            ref_map                 => $drawer->{'data'}{'slots'}{0}{$map_id},
            map_id                  => $map_id,
            highlight               => $parsed_url_options{'highlight'},
            included_feature_types  => $parsed_url_options{'feature_types'},
            corr_only_feature_types =>
                $parsed_url_options{'corr_only_feature_types'},
            ignored_feature_types =>
                $parsed_url_options{'ignored_feature_types'},
            included_evidence_types =>
                $parsed_url_options{'included_evidence_types'},
            ignored_evidence_types =>
                $parsed_url_options{'ignored_evidence_types'},
            order_by => $apr->param('order_by') || '',
            comparative_map_field =>
                $parsed_url_options{'comparative_map_field'} || '',
            comparative_map_field_acc =>
                $parsed_url_options{'comparative_map_field_acc'} || '',
            page_size => $PAGE_SIZE,
            max_pages => $MAX_PAGES,
            page_no   => $parsed_url_options{'page_no'},
            page_data => $parsed_url_options{'action'} eq 'download' ? 0 : 1,
            )
            or return $self->error( "Data: " . $data->error );

        $self->object_plugin( 'map_details',
            $detail_data->{'reference_map'} );

        if ( $parsed_url_options{'action'} eq 'download' ) {
            my $text = join( FIELD_SEP, @{ +COLUMN_NAMES } ) . RECORD_SEP;
            my $map_fields = join( FIELD_SEP,
                map { $detail_data->{'reference_map'}{$_} }
                    @{ +MAP_FIELDS } );

            for my $feature ( @{ $detail_data->{'features'} } ) {
                my $row = join( FIELD_SEP,
                    $map_fields,
                    map { $feature->{$_} } @{ +FEATURE_FIELDS } );

                if ( @{ $feature->{'positions'} } ) {
                    for my $position ( @{ $feature->{'positions'} } ) {
                        $position->{'evidence'}
                            = join( ',', @{ $position->{'evidence'} } );
                        $text .= join(
                            FIELD_SEP,
                            $row,
                            map {
                                defined $position->{$_}
                                    ? $position->{$_}
                                    : ''
                                } @{ +POSITION_FIELDS }
                            )
                            . RECORD_SEP;
                    }
                }
                else {
                    $text .= $row . RECORD_SEP;
                }
            }

            print $apr->header( -type => 'text/plain' ), $text;
        }
        else {
            my @map_ids = map { $_ || () }
                keys %{ $drawer->{'data'}{'slots'}{'0'} };
            my $ref_map_id = shift @map_ids;
            my $ref_map    = $drawer->{'data'}{'slots'}{'0'}{$ref_map_id};
            $apr->param( 'ref_map_start', $ref_map->{'start'} );
            $apr->param( 'ref_map_stop',  $ref_map->{'stop'} );

            my $detail_html;
            my $t = $self->template;
            $t->process(
                DETAIL_TEMPLATE,
                {   apr                   => $apr,
                    pager                 => $detail_data->{'pager'},
                    feature_types         => $detail_data->{'feature_types'},
                    feature_count_by_type =>
                        $detail_data->{'feature_count_by_type'},
                    evidence_types   => $detail_data->{'evidence_types'},
                    reference_map    => $detail_data->{'reference_map'},
                    comparative_maps => $detail_data->{'comparative_maps'},
                    comparative_map_field => '',
                    comparative_map_acc   => '',
                    drawer                => $drawer,
                    page                  => $self->page,
                    title                 => 'Reference Map Details',
                    stylesheet            => $self->stylesheet,
                    features              => $detail_data->{'features'},
                },
                \$detail_html
                )
                or $detail_html = $t->error;

            print $apr->header(
                -type   => 'text/html',
                -cookie => $self->cookie
                ),
                $html, $detail_html;
        }
    }
    else {

        # Regular map viewing
        print $apr->header(
            -type   => 'text/html',
            -cookie => $self->cookie
        ), $html;
    }

    return 1;
}

1;

# ----------------------------------------------------
# Prisons are built with stones of Law,
# Brothels with bricks of Religion.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::MapViewer - view comparative maps

=head1 SYNOPSIS

In httpd.conf:

  <Location /cmap/viewer>
      SetHandler  perl-script
      PerlHandler Bio::GMOD::CMap::Apache::MapViewer->super
  </Location>

=head1 DESCRIPTION

This module is a mod_perl handler for displaying the user interface to
select and display comparative maps.  It inherits from
Bio::GMOD::CMap::Apache where all the error handling occurs.

Added forking to allow creation of really large maps.  Stole most of
the implementation from Randal Schwartz:

    http://www.stonehenge.com/merlyn/LinuxMag/col39.html

=head1 SEE ALSO

L<perl>, L<Template>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

