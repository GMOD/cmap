package Bio::GMOD::CMap::Apache::MapViewer;
# vim: set ft=perl:

# $Id: MapViewer.pm,v 1.31.2.1 2004-06-17 20:14:06 kycl4rk Exp $

use strict;
use vars qw( $VERSION $INTRO );
$VERSION = (qw$Revision: 1.31.2.1 $)[-1];

use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Drawer;
use Bio::GMOD::CMap::Data;
use Template;

use base 'Bio::GMOD::CMap::Apache';
use constant TEMPLATE     => 'cmap_viewer.tmpl';

# ----------------------------------------------------
sub handler {
#
# Main entry point.  Decides whether we forked and whether to 
# read session data.  Calls "show_form."
#
    my ( $self, $apr ) = @_;
    my $prev_ref_species_aid  = $apr->param('prev_ref_species_aid')  || '';
    my $prev_ref_map_set_aid  = $apr->param('prev_ref_map_set_aid')  || '';
    my $ref_species_aid       = $apr->param('ref_species_aid')       || '';
    my $ref_map_set_aid       = $apr->param('ref_map_set_aid')       || '';
    my $ref_map_aid           = $apr->param('ref_map_aid')           || '';
    my $ref_map_start         = $apr->param('ref_map_start');
    my $ref_map_stop          = $apr->param('ref_map_stop');
    my $comparative_maps      = $apr->param('comparative_maps')      || '';
    my $comparative_map_right = $apr->param('comparative_map_right') || '';
    my $comparative_map_left  = $apr->param('comparative_map_left')  || '';
    my $highlight             = $apr->param('highlight')             || '';
    my $font_size             = $apr->param('font_size')             || '';
    my $image_size            = $apr->param('image_size')            || '';
    my $image_type            = $apr->param('image_type')            || '';
    my $label_features        = $apr->param('label_features')        || '';
    my $collapse_features     = $apr->param('collapse_features')     ||  0;
    my $flip                  = $apr->param('flip')                  || '';
    my $min_correspondences   = $apr->param('min_correspondences')   ||  0;

    #
    # Take the feature types either from the query string (first
    # choice, splitting the string on commas) or from the POSTed 
    # form <select>.
    #
    my @feature_types;
    if ( $apr->param('feature_types') ) {
        @feature_types = ( $apr->param('feature_types') );
    }
    elsif ( $apr->param('include_feature_types') ) {
        @feature_types = split( /,/, $apr->param('include_feature_types') );
    }

    my @evidence_types;
    if ( $apr->param('evidence_types') ) {
        @evidence_types = ( $apr->param('evidence_types') );
    }
    elsif ( $apr->param('include_evidence_types') ) {
        @evidence_types = split( /,/, $apr->param('include_evidence_types') );
    }

    #
    # Set the data source.
    #
    $self->data_source( $apr->param('data_source') ) or return;

    if ( 
        $prev_ref_species_aid && $prev_ref_species_aid ne $ref_species_aid 
    ) {
        $ref_map_set_aid = '';
    }

    if ( 
        $prev_ref_map_set_aid && $prev_ref_map_set_aid ne $ref_map_set_aid 
    ) {
        $ref_map_aid           = undef;
        $ref_map_start         = undef;
        $ref_map_stop          = undef;
        $comparative_maps      = undef;
        $comparative_map_right = undef;
        $comparative_map_left  = undef;
    }

    my %slots = (
        0 => {
            field       => $ref_map_aid eq '-1' ? 'map_set_aid' : 'map_aid',
            aid         => $ref_map_aid eq '-1' 
                           ? $ref_map_set_aid : $ref_map_aid,
            start       => $ref_map_start,
            stop        => $ref_map_stop,
            map_set_aid => $ref_map_set_aid,
        },
    );

    #
    # Add in previous maps.
    #
    for my $cmap ( split( /:/, $comparative_maps ) ) {
        my ( $slot_no, $field, $accession_id ) = split(/=/, $cmap) or next;
        my ( $start, $stop );
        if ( $accession_id =~ m/^(.+)\[(.+),(.+)\]$/ ) {
            $accession_id = $1;
            $start        = $2;
            $stop         = $3;
        }
        $slots{ $slot_no } =  {
            field          => $field,
            aid            => $accession_id,
            start          => $start,
            stop           => $stop,
        }; 
    }

    my @slot_nos  = sort { $a <=> $b } keys %slots;
    my $max_right = $slot_nos[-1];
    my $max_left  = $slot_nos[ 0];

    #
    # Add in our next chosen maps.
    #
    for my $side ( ( RIGHT, LEFT ) ) {
        my $slot_no = $side eq RIGHT ? $max_right + 1 : $max_left - 1;
        my $cmap    = $side eq RIGHT 
            ? $comparative_map_right : $comparative_map_left;
        my ( $field, $accession_id ) = split( /=/, $cmap ) or next;
        my ( $start, $stop );
        if ( $accession_id =~ m/^(.+)\[(.+),(.+)\]$/ ) {
            $accession_id = $1;
            $start        = $2;
            $stop         = $3;
        }
        $slots{ $slot_no } =  {
            field          => $field,
            aid            => $accession_id,
            start          => $start,
            stop           => $stop,
        }; 
    }

    #
    # Instantiate the drawer if there's at least one map to draw.
    #
    my $drawer;
    if ( $ref_map_aid ) {    
        $drawer                    =  Bio::GMOD::CMap::Drawer->new(
            apr                    => $apr,
            data_source            => $self->data_source,
            slots                  => \%slots,
            flip                   => $flip,
            highlight              => $highlight,
            font_size              => $font_size,
            image_size             => $image_size,
            image_type             => $image_type,
            label_features         => $label_features,
            collapse_features      => $collapse_features,
            min_correspondences    => $min_correspondences,
            include_feature_types  => \@feature_types,
            include_evidence_types => \@evidence_types,
            debug                  => $self->config('debug'),
        ) or return $self->error( Bio::GMOD::CMap::Drawer->error );

        %slots = %{ $drawer->{'slots'} };
    }

    #
    # Get the data for the form.
    #
    my $data                   = $self->data_module;
    my $form_data              = $data->cmap_form_data( 
        slots                  => \%slots,
        min_correspondences    => $min_correspondences,
        include_feature_types  => \@feature_types,
        include_evidence_types => \@evidence_types,
        ref_species_aid        => $ref_species_aid,
    ) or return $self->error( $data->error );

    $form_data->{'feature_types'} = $drawer 
        ? [ 
            sort {
                lc $a->{'feature_type'} cmp lc $b->{'feature_type'}
            } @{ $drawer->{'feature_types'} }
        ]
        : []
    ;

    #
    # The start and stop may have had to be moved as there 
    # were too few or too many features in the selected region.
    #
    $apr->param( ref_map_start   => $form_data->{'ref_map_start'}   );
    $apr->param( ref_map_stop    => $form_data->{'ref_map_stop'}    );
    $apr->param( ref_species_aid => $form_data->{'ref_species_aid'} );
    $apr->param( ref_map_set_aid => $form_data->{'ref_map_set_aid'} );

    #
    # Wrap up our current comparative maps so we can store them on 
    # the next page the user sees.
    #
    my @comp_maps = ();
    for my $slot_no ( grep { $_ != 0 } keys %slots ) {
        push @comp_maps, join( '=', 
            $slot_no, map { $slots{ $slot_no }{ $_ } } qw[ field aid ]
        );
    }

    $INTRO ||= $self->config('map_viewer_intro') || '';

    my $html;
    my $t = $self->template or return;
    $t->process( 
        TEMPLATE, 
        {
            apr               => $apr,
            form_data         => $form_data,
            drawer            => $drawer,
            page              => $self->page,
            debug             => $self->debug,
            intro             => $INTRO,
            data_source       => $self->data_source,
            data_sources      => $self->data_sources,
            comparative_maps  => join( ':', @comp_maps ),
            title             => $self->config('cmap_title') || 'CMap',
            stylesheet        => $self->stylesheet,
            included_features => { map { $_, 1 } @feature_types },
            included_evidence => { map { $_, 1 } @evidence_types },
            feature_types     => join( ',', @feature_types ),
            evidence_types    => join( ',', @evidence_types ),
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
