package Bio::GMOD::CMap::Drawer::AppDrawer;

# vim: set ft=perl:

# $Id: AppDrawer.pm,v 1.1 2006-02-05 04:17:59 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Drawer::AppDrawer - draw maps 

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Drawer::AppDrawer;
  my $drawer = Bio::GMOD::CMap::Drawer::AppDrawer( ref_map_id => 12345 );
  $drawer->image_name;

=head1 DESCRIPTION

The base map drawing module.

=head1 Usage

    my $drawer = Bio::GMOD::CMap::Drawer::AppDrawer->new(
        slots => $slots,
        data_source => $data_source,
        apr => $apr,
        flip => $flip,
        highlight => $highlight,
        font_size => $font_size,
        image_size => $image_size,
        image_type => $image_type,
        label_features => $label_features,
        included_feature_types  => $included_feature_types,
        corr_only_feature_types => $corr_only_feature_types,
        url_feature_default_display => $url_feature_default_display,
        included_evidence_types => $included_evidence_types,
        ignored_evidence_types  => $ignored_evidence_types,
        less_evidence_types     => $less_evidence_types,
        greater_evidence_types  => $greater_evidence_types,
        evidence_type_score     => $evidence_type_score,
        ignored_feature_types   => $ignored_feature_types,
        config => $config,
        left_min_corrs => $left_min_corrs,
        right_min_corrs => $right_min_corrs,
        general_min_corrs => $general_min_corrs,
        menu_min_corrs => $menu_min_corrs,
        slots_min_corrs => $slots_min_corrs,
        collapse_features => $collapse_features,
        cache_dir => $cache_dir,
        map_view => $map_view,
        data_module => $data_module,
        aggregate => $aggregate,
        cluster_corr => $cluster_corr,
        show_intraslot_corr => $show_intraslot_corr,
        split_agg_ev => $split_agg_ev,
        clean_view => $clean_view,
        corrs_to_map => $corrs_to_map,
        magnify_all => $magnify_all,
        scale_maps => $scale_maps,
        stack_maps => $stack_maps,
        ref_map_order => $ref_map_order,
        comp_menu_order => $comp_menu_order,
        omit_area_boxes => $omit_area_boxes,
        session_id => $session_id,
        next_step => $next_step,
        refMenu => $refMenu,
        compMenu => $compMenu,
        optionMenu => $optionMenu,
        addOpMenu => $addOpMenu,
        skip_drawing => $skip_draweing,
    );

=head2 Fields

=over 4

=item * slots

Slots is the only required field.

It is a hash reference with the information for the maps in each slot.

Breakdown of the data structure (variables represent changeable data):

=over 4

=item - $slot->{$slot_number}{'maps'} 

If there are individually selected maps, this is the hash where they 
are stored.  The map accession ids are the keys and a hash (described 
below) of info is the value.  Either 'maps' or 'map_sets' must be defined.

    $slot->{$slot_number}{'maps'}{$map_acc} = (
        'start' => $start || undef, # the start of the map to be displayed.  Can be undef.
        'stop'  => $stop  || undef, # the stop of the map to be displayed.  Can be undef.
        'mag'   => $mag   || undef, # the magnification of the map to be displayed.  Can be undef.
    ):

=item - $slot->{$slot_number}{'map_sets'} 

If a whole map set is to be displayed it is in this hash with the 
map set accession id as the key and undef as the value (this is saved 
for possible future developement).  Either 'maps' or 'map_sets' must 
be defined.

    $slot->{$slot_number}{'map_sets'}{$map_set_acc} = undef;

=item - $slot->{$slot_number}{'map_set_acc'}

This is the accession of the map set that the slot holds.  There can
be only one map set per slot and this is the map set accession.

    $slot->{$slot_number}{'map_set_acc'} = $map_set_acc;

=back

=item * data_source

The "data_source" parameter is a string of the name of the data source
to be used.  This information is found in the config file as the
"<database>" name field.

Defaults to the default database.

=item * apr

A CGI object that is mostly used to create the URL.

=item * flip

A string that denotes which maps are flipped.  The format is:

 $slot_no.'='.$map_acc

Multiple maps are separated by ':'.


=item * highlight

A string with the feature names to be highlighted separated by commas.

=item * font_size

String with the font size: large, medium or small.

=item * image_size

String with the image size: large, medium or small.

=item * image_type

String with the image type: png, gif, svg or jpeg.

=item * label_features

String with which labels should be displayed: all, landmarks or none.

=item * included_feature_types

An array reference that holds the feature type accessions that are 
included in the picture.

=item * corr_only_feature_types

An array reference that holds the feature type accessions that are 
included in the picture only if there is a correspondence.

=item * url_feature_default_display

This holds the default for how undefined feature types will be treated.  This
will override the value in the config file.

 0 = ignore
 1 = display only if has correspondence
 2 = display

=item * included_evidence_types

An array reference that holds the evidence type accessions that are 
used.

=item * ignored_evidence_types

An array reference that holds the evidence type accessions that are 
ignored.

=item * less_evidence_types

An array reference that holds the evidence type accessions that are used only if
their score is less than that of the score specified in evidence_type_score.

=item * greater_evidence_types

An array reference that holds the evidence type accessions that are used only if
their score is greater than that of the score specified in evidence_type_score.

=item * evidence_type_score

An hash reference that holds the score that evidence is measured against.

=item * ignored_feature_types

An array reference that holds the evidence type accessions that are 
included in the picture.

=item * config

A Bio::GMOD::CMap::Config object that can be passed to this module if
it has already been created.  Otherwise, AppDrawer will create it from 
the data_source.

=item * left_min_corrs

The minimum number of correspondences for the left most slot.

=item * right_min_corrs

The minimum number of correspondences for the right most slot.

=item * general_min_corrs

The minimum number of correspondences for the slots that aren't the right most
or the left most.

=item * menu_min_corrs

The minimum number of correspondences for the menu

=item * slots_min_corrs

The data structure that holds the  minimum number of correspondences for each slot

=item * collapse_features

Set to 1 to collaps overlapping features.

=item * cache_dir

Alternate location for the image file

=item * map_view

Either 'viewer' or 'details'.  This is only useful for links in the 
map area.  'viewer' is the default.

=item * data_module

A Bio::GMOD::CMap::Data object that can be passed to this module if
it has already been created.  Otherwise, AppDrawer will create it.

=item * aggregate

Set to 1 to aggregate the correspondences with one line.

Set to 2 to aggregate the correspondences with two lines.

Set to 3 to cluster the correspondences into groups based on the cluster_corr
value.

=item * cluster_corr

Set to the number of clusters desired.  Will only be used if aggregated == 3.

=item * show_intraslot_corr

Set to 1 to diplsyed intraslot correspondences.

=item * split_agg_ev

Set to 1 to split correspondences with different evidence types.
Set to 0 to aggregate them all together.

=item * clean_view

Set to 1 to not have the control buttons displayed on the image.

=item * corrs_to_map

Set to 1 to have correspondence lines go to the map instead of the feature.

=item * magnify_all

Set to the magnification factor of the whole picture.  The default is 1.

=item * scale_maps

Set to 1 scale the maps with the same unit.  Default is 1.

=item * stack_maps

Set to 1 stack the reference maps vertically.  Default is 0.

=item * ref_map_order

This is the string that dictates the order of the reference maps.  The format
is the list of map_accs in order, separated by commas 

=item * comp_menu_order

This is the string that dictates the order of the comparative maps in the menu.
Options are 'display_order' (order on the map display_order) and 'corrs' (order
on the number of correspondences).  'display_order' is the default.

=item * omit_area_boxes

Omit or set to 0 to render all the area boxes.  This gives full functionality
but can be a slow when there are a lot of features.

Set to 1 to omit the feature area boxes.  This will speed up render time while
leaving the navigation buttons intact.

Set to 2 to omit all of the area boxes.  This will make a non-clickable image.

=item * session_id

The session id.

=item * next_step

The session step that the new urls should use.

=item * refMenu

This is set to 1 if the Reference Menu is displayed.

=item * compMenu

This is set to 1 if the Comparison Menu is displayed.

=item * optionMenu

This is set to 1 if the Options Menu is displayed.

=item * addOpMenu

This is set to 1 if the Additional Options Menu is displayed.

=item * skip_drawing

This is set to 1 if you don't want the drawer to actually do the drawing 

=back

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.1 $)[-1];

use Bio::GMOD::CMap::Utils 'parse_words';
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use Data::Dumper;
use GD;
use base 'Bio::GMOD::CMap::Drawer';


# ----------------------------------------------------
sub init {

=pod

=head2 init

Initializes the drawing object.

=cut

    my ( $self, $config ) = @_;

    $self->initialize_params($config);
    $self->canvas($config->{'canvas'});

    return $self;
}

# ----------------------------------------------------
sub initial_draw {

=pod

=head2 initial_draw

Draw maps for the first time.

=cut

    my ( $self, %args ) = @_;
    $self->clear_canvas();
    $self->data($args{'data'});

    $self->draw();
}


# ----------------------------------------------------
sub canvas {

=pod

=head2 canvas

Gets/Sets the canvas object.

=cut

    my $self = shift;
    my $canvas = shift;
    if ($canvas) {
        $self->{'canvas'} = $canvas;
    }
    return $self->{'canvas'};
}

# ----------------------------------------------------
sub clear_canvas {

=pod

=head2 clear_canvas

Gets/Sets the canvas object.

=cut

    my $self = shift;
    my $canvas = $self->canvas();

    $canvas->delete('all');

}

# ----------------------------------------------------
sub data {

=pod

=head2 data

Overwrites the Drawer->data() method.

Gets/Sets the data object.

=cut

    my $self = shift;
    my $data = shift;
    if ($data) {
        $self->{'data'} = $data;
    }
    return $self->{'data'};
}

# ----------------------------------------------------
sub draw_image {

=pod

=head2 draw_image

Do the actual drawing.

=cut
    my $self      = shift;

    my @data      = $self->drawing_data;
    my $height    = $self->map_height;
    my $width     = $self->map_width;
    my $canvas    = $self->canvas();

    $canvas->configure(-width=>$width,-height=>$height,);

#    my %colors    =
#        map {
#        $_, $img->colorAllocate( map { hex $_ } @{ +COLORS->{$_} } )
#        }
#        keys %{ +COLORS };
#    $img->interlaced('true');
#    $img->filledRectangle( 0, 0, $width, $height,
#        $colors{ $self->config_data('background_color') } );

    #
    # Sort the drawing data by the layer (which is the last field).
    #
    for my $obj ( sort { $a->[-1] <=> $b->[-1] } @data ) {
        my $method = shift @$obj;
        my $layer  = pop @$obj;
        my @colors = pop @$obj;
        push @colors, pop @$obj if $method eq FILL_TO_BORDER;
        if ($method eq 'string'){
            $canvas->createText(
                $obj->[1],
                $obj->[2],
                (   '-text'   => $obj->[3],
                    '-anchor' => 'nw',
                    -fill     => $colors[0],
                    -font => [ -size => 11, ],
                )
            );
        }
        elsif ( $method eq 'rectangle' ){
            $canvas->createRectangle(
                ( $obj->[0], $obj->[1] ),
                ( $obj->[2], $obj->[3] ),
                ( '-outline' => $colors[0],  ),
            );
        }
        elsif ( $method eq 'filledRectangle' ) {
            $canvas->createRectangle(
                ( $obj->[0], $obj->[1] ),
                ( $obj->[2], $obj->[3] ),
                (   '-outline' => $colors[0],
                    -fill      => $colors[0]
                ),
            );
        }
        elsif ( $method eq 'line' ) {
            $canvas->createLine(
                ( $obj->[0], $obj->[1] ),
                ( $obj->[2], $obj->[3] ),
                (   '-width' => '1',
                    '-fill'  => $colors[0],
                    '-cap'   => 'butt',
                    '-join'  => 'miter',
                ),
            );
        }
        else{
#print STDERR "$method\n";
#print STDERR Dumper($obj)."\n";
        }
    }

    #
    # Add a black box around the whole #!.
    #
#    $img->rectangle( 0, 0, $width - 1, $height - 1, $colors{'black'} );

    return;
}

1;

# ----------------------------------------------------
# It is not all books that are as dull as their readers.
# Henry David Thoreau
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>, L<GD>, L<GD::SVG>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-5 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

