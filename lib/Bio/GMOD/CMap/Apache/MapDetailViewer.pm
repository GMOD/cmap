package Bio::GMOD::CMap::Apache::MapDetailViewer;

# $Id: MapDetailViewer.pm,v 1.17 2003-09-05 22:59:01 kycl4rk Exp $

use strict;
use vars qw( $VERSION $PAGE_SIZE $MAX_PAGES );
$VERSION = (qw$Revision: 1.17 $)[-1];

use Apache::Constants;
use URI::Escape;
use Data::Dumper;
use Data::Pageset;
use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Drawer;

use base 'Bio::GMOD::CMap::Apache';

use constant FIELD_SEP       => "\t";
use constant RECORD_SEP      => "\n";
use constant TEMPLATE        => 'map_detail.tmpl';
use constant COLUMN_NAMES    => [
    qw[ species_accession_id species_name 
        map_set_accession_id map_set_name
        map_accession_id map_name
        feature_accession_id feature_name feature_type start_position 
        stop_position alt_species_name alt_map_set_name alt_map_name 
        alt_feature_type alt_start_position alt_stop_position 
        evidence
    ]
];
use constant MAP_FIELDS      => [
    qw[ species_aid species_name map_set_aid map_set_name map_aid map_name ]
];
use constant FEATURE_FIELDS  => [
    qw[ accession_id feature_name feature_type start_position stop_position ]
];
use constant POSITION_FIELDS => [
    qw[ species_name map_set_name map_name feature_type 
        start_position stop_position evidence
    ]
];

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr )    = @_;
    my $ref_map_set_aid   = $apr->param('ref_map_set_aid')   ||      0;
    my $ref_map_aid       = $apr->param('ref_map_aid')       ||     '';
    my $ref_map_start     = $apr->param('ref_map_start');
    my $ref_map_stop      = $apr->param('ref_map_stop');
    my $comparative_maps  = $apr->param('comparative_maps')  ||     '';
    my $highlight         = $apr->param('highlight')         ||     '';
    my $font_size         = $apr->param('font_size')         ||     '';
    my $image_size        = $apr->param('image_size')        ||     '';
    my $image_type        = $apr->param('image_type')        ||     '';
    my $label_features    = $apr->param('label_features')    ||     '';
    my $collapse_features = $apr->param('collapse_features') ||      0;
    my $page_no           = $apr->param('page_no')           ||      1;
    my $flip              = $apr->param('flip')              ||     '';
    my $action            = $apr->param('action')            || 'view';

    #
    # Set the data source.
    #
    $self->data_source( $apr->param('data_source') );

    $PAGE_SIZE ||= $self->config('max_child_elements') || 0;
    $MAX_PAGES ||= $self->config('max_search_pages')   || 1;
    
    #
    # Take the feature types either from the query string (first
    # choice, splitting the string on commas) or from the POSTed 
    # form <select>.
    #
    my @feature_types;
    if ( $apr->param('feature_types') ) {
        @feature_types = split(/,/, $apr->param('feature_types') );
    }
    else {
        @feature_types = ( $apr->param('include_feature_types') );
    }

    my @evidence_types;
    if ( $apr->param('evidence_types') ) {
        @evidence_types = split(/,/, $apr->param('evidence_types') );
    }
    else {
        @evidence_types = ( $apr->param('include_evidence_types') );
    }

    my %slots = (
        0 => {
            field       => 'map_aid',
            aid         => $ref_map_aid,
            start       => $ref_map_start,
            stop        => $ref_map_stop,
            map_set_aid => $ref_map_set_aid,
        },
    );

    #
    # Add in previous maps.
    #
    my $no_flanking = $self->config('number_flanking_positions') || 0;
    for my $cmap ( split( /:/, $comparative_maps ) ) {
        my ( $slot_no, $field, $accession_id ) = split(/=/, $cmap) or next;
        my ( $start, $stop );
        if ( $accession_id =~ m/^(.+)\[(.+),(.+)\]$/ ) {
            $accession_id = $1;
            $start        = $2;
            $stop         = $3;
        }

        $slots{ $slot_no }        =  {
            field                 => $field,
            aid                   => $accession_id,
            start                 => $start,
            stop                  => $stop,
            no_flanking_positions => $no_flanking,
        }; 
    }

    my $data_module = $self->data_module( data_source => $self->data_source ) 
        or return;
    my ( $comparative_map_field, $comparative_map_aid ) = 
        split( /=/, $apr->param('comparative_map') );

    #
    # Instantiate the drawer.
    #
    my $drawer                 =  Bio::GMOD::CMap::Drawer->new(
        data_source            => $self->data_source,
        apr                    => $apr,
        slots                  => \%slots,
        flip                   => $flip,
        highlight              => $highlight,
        font_size              => $font_size,
        image_size             => $image_size,
        image_type             => $image_type,
        label_features         => $label_features,
        collapse_features      => $collapse_features,
        include_feature_types  => \@feature_types,
        include_evidence_types => \@evidence_types,
        debug                  => $self->config('debug'),
        map_view               => 'details',
    ) or die $self->error( "Drawer: ".Bio::GMOD::CMap::Drawer->error );

    my $data                   = $data_module->map_detail_data( 
        slots                  => \%slots,
        highlight              => $highlight,
        include_feature_types  => \@feature_types,
        include_evidence_types => \@evidence_types,
        order_by               => $apr->param('order_by') || '',
        comparative_map_field  => $comparative_map_field  || '',
        comparative_map_aid    => $comparative_map_aid    || '',
        page_size              => $PAGE_SIZE,
        max_pages              => $MAX_PAGES,
        page_no                => $page_no,
        page_data              => $action eq 'download' ? 0 : 1,
    ) or return $self->error( "Data: ".$data_module->error );

    if ( $action eq 'download' ) {
        my $text       = join( FIELD_SEP, @{ +COLUMN_NAMES } ).RECORD_SEP;
        my $map_fields = join(
            FIELD_SEP, map { $data->{'reference_map'}{$_} } @{ +MAP_FIELDS }
        );

        for my $feature ( @{ $data->{'features'} } ) {
            my $row = join(
                FIELD_SEP, 
                $map_fields, map { $feature->{$_} } @{ +FEATURE_FIELDS }
            );

            if ( @{ $feature->{'positions'} } ) {
                for my $position ( @{ $feature->{'positions'} } ) {
                    $position->{'evidence'} = 
                        join( ',', @{ $position->{'evidence'} } );
                    $text .= join(
                        FIELD_SEP, 
                        $row,
                        map { defined $position->{$_} ? $position->{$_} : '' } 
                            @{ +POSITION_FIELDS }
                    ) . RECORD_SEP;
                }
            }
            else {
                $text .= $row . RECORD_SEP;
            }
        }

        $apr->content_type('text/plain');
        $apr->send_http_header;
        $apr->print( $text );
    }
    else {
        my $ref_map = $drawer->{'data'}{'slots'}{'0'}{ $ref_map_aid };
        $apr->param('ref_map_start',  $ref_map->{'start'}         );
        $apr->param('ref_map_stop',   $ref_map->{'stop'}          );
        $apr->param('feature_types',  join(',', @feature_types )  );
        $apr->param('evidence_types', join(',', @evidence_types ) );
        $apr->param('highlight_uri',  uri_escape( $apr->param('highlight') ) );

        my $html;
        my $t = $self->template;
        $t->process( 
            TEMPLATE, 
            { 
                apr                   => $apr,
                pager                 => $data->{'pager'},
                feature_types         => $data->{'feature_types'},
                evidence_types        => $data->{'evidence_types'},
                reference_map         => $data->{'reference_map'},
                comparative_maps      => $data->{'comparative_maps'},
                comparative_map_field => $comparative_map_field,
                comparative_map_aid   => $comparative_map_aid,
                drawer                => $drawer,
                page                  => $self->page,
                title                 => 'Reference Map Details',
                stylesheet            => $self->stylesheet,
                included_features     => { map { $_, 1 } @feature_types },
                included_evidence     => { map { $_, 1 } @evidence_types },
                features              => $data->{'features'},
            },
            \$html 
        ) or $html = $t->error;

        $apr->content_type('text/html');
        $apr->send_http_header;
        $apr->print( $html );
    }

    return OK;
}

1;

# ----------------------------------------------------
# I should have been a pair of ragged claws,
# Scuttling across the floors of silent seas.
# T. S. Eliot
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::MapDetailViewer - view relational maps

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Apache::MapDetailViewer;
  blah blah blah

=head1 DESCRIPTION

Blah blah blah.

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2002-3 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
