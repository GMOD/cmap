package Bio::GMOD::CMap::Apache::MapViewer;

# $Id: MapViewer.pm,v 1.4 2002-08-30 02:49:55 kycl4rk Exp $

use strict;
use vars qw( $VERSION $TEMPLATE $PAGE $DEBUG );
$VERSION = (qw$Revision: 1.4 $)[-1];

use Apache::Constants;
use Apache::Request;
use Template;
use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Drawer;
use Bio::GMOD::CMap::Data;

use Carp;
use Data::Dumper;
use base 'Bio::GMOD::CMap::Apache';
use constant TEMPLATE => 'cmap_viewer.tmpl';

sub handler {
    my ( $self, $apr ) = @_;

    #
    # User Preferences.
    #
    my $preferences = $apr->pnotes('PREFERENCES') || {};
    for my $field ( @{ +PREFERENCE_FIELDS } ) {
        $apr->param( $field, $preferences->{ $field } );
    }

    my $html;

    my $prev_ref_map_set_aid  = $apr->param('prev_ref_map_set_aid')  ||  0;
    my $ref_map_set_aid       = $apr->param('ref_map_set_aid')       ||  0;
    my $ref_map_aid           = $apr->param('ref_map_aid')           ||  0;
    my $ref_map_start         = $apr->param('ref_map_start');
    my $ref_map_stop          = $apr->param('ref_map_stop');
    my $comparative_maps      = $apr->param('comparative_maps')      || '';
    my $comparative_map_right = $apr->param('comparative_map_right') || '';
    my $comparative_map_left  = $apr->param('comparative_map_left')  || '';
    my $highlight             = $apr->param('highlight')             || '';
    my $font_size             = $apr->param('font_size')             || '';
    my $image_size            = $apr->param('image_size')            ||  0;
    my $image_type            = $apr->param('image_type')            || '';
    my $include_features      = $apr->param('include_features')   || '';

    if ( 
        $prev_ref_map_set_aid && $prev_ref_map_set_aid != $ref_map_set_aid 
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
    for my $cmap ( split( /:/, $comparative_maps ) ) {
        my ( $slot_no, $field, $accession_id ) = split(/=/, $cmap) or next;
        $slots{ $slot_no } =  {
            field        => $field,
            aid          => $accession_id,
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
        $slots{ $slot_no } =  {
            field        => $field,
            aid          => $accession_id,
        }; 
    }

    #
    # Instantiate the drawer if there's at least one map to draw.
    #
    my $drawer;
    if ( $ref_map_aid ) {
        $drawer              =  Bio::GMOD::CMap::Drawer->new(
            apr              => $apr,
            slots            => \%slots,
            highlight        => $highlight,
            font_size        => $font_size,
            image_size       => $image_size,
            image_type       => $image_type,
            include_features => $include_features,
            debug            => $DEBUG,
        ) or return $self->error( "Drawer: ".Bio::GMOD::CMap::Drawer->error );

        %slots = %{ $drawer->slots };
    }

    #
    # Get the data for the form.
    #
    my $data = $self->data_module;
    my $form_data = $data->cmap_form_data( slots => \%slots ) or 
        return $self->error( "Data: ".$data->error );

    #
    # The start and stop may have had to be moved as there 
    # were too few or too many features in the selected region.
    #
    $apr->param( ref_map_start => $form_data->{'ref_map_start'} );
    $apr->param( ref_map_stop  => $form_data->{'ref_map_stop'}  );

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

    my $t = $self->template or return $self->error( 'No template' );
    $t->process( 
        TEMPLATE, 
        {
            apr              => $apr,
            form_data        => $form_data,
            drawer           => $drawer,
            page             => $self->page,
            debug            => $self->debug,
            comparative_maps => join( ':', @comp_maps ),
            title            => 'Comparative Maps',
            stylesheet       => $self->stylesheet,
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

This module is a mod_perl handler for displaying the user interface to select
and display comparative maps.  It inherits from Bio::GMOD::CMap::Apache where
all the error handling occurs.

=head1 SEE ALSO

L<perl>, L<Template>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

Copyright (c) 2002 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
