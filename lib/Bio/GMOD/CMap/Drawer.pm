package Bio::GMOD::CMap::Drawer;

# vim: set ft=perl:

# $Id: Drawer.pm,v 1.92 2005-02-10 19:06:03 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Drawer - draw maps 

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Drawer;
  my $drawer = Bio::GMOD::CMap::Drawer( ref_map_id => 12345 );
  $drawer->image_name;

=head1 DESCRIPTION

The base map drawing module.

=head1 Usage

    my $drawer = Bio::GMOD::CMap::Drawer->new(
        slots => $slots,
        data_source => $data_source,
        apr => $apr,
        flip => $flip,
        highlight => $highlight,
        font_size => $font_size,
        image_size => $image_size,
        image_type => $image_type,
        label_features => $label_features,
        included_feature_types => $included_feature_types,
        corr_only_feature_types => $corr_only_feature_types,
        included_evidence_types => $included_evidence_types,
        ignored_evidence_types => $ignored_evidence_types,
        ignored_feature_types => $ignored_feature_types,
        config => $config,
        min_correspondences => $min_correspondences,
        collapse_features => $collapse_features,
        cache_dir => $cache_dir,
        map_view => $map_view,
        data_module => $data_module,
        aggregate => $aggregate,
        cluster_corr => $cluster_corr,
        show_intraslot_corr => $show_intraslot_corr,
        split_agg_ev => $split_agg_ev,
        clean_view => $clean_view,
        magnify_all => $magnify_all,
        scale_maps => $scale_maps,
        stack_maps => $stack_maps,
        ref_map_order => $ref_map_order,
        comp_menu_order => $comp_menu_order,
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

    $slot->{$slot_number}{'maps'}{$map_aid} = (
        'start' => $start || undef, # the start of the map to be displayed.  Can be undef.
        'stop'  => $stop  || undef, # the stop of the map to be displayed.  Can be undef.
        'mag'   => $mag   || undef, # the magnification of the map to be displayed.  Can be undef.
    ):
   
=item - $slot->{$slot_number}{'map_sets'} 

If a whole map set is to be displayed it is in this hash with the 
map set accession id as the key and undef as the value (this is saved 
for possible future developement).  Either 'maps' or 'map_sets' must 
be defined.

    $slot->{$slot_number}{'map_sets'}{$map_set_aid} = undef;

=item - $slot->{$slot_number}{'map_set_aid'}

This is the accession of the map set that the slot holds.  There can
be only one map set per slot and this is the map set accession.

    $slot->{$slot_number}{'map_set_aid'} = $map_set_aid;

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

 $slot_no.'='.$map_aid

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

=item * included_evidence_types

An array reference that holds the feature type accessions that are 
ignored.

=item * ignored_evidence_types

An array reference that holds the evidence type accessions that are 
ignored.

=item * ignored_feature_types

An array reference that holds the evidence type accessions that are 
included in the picture.

=item * config

A Bio::GMOD::CMap::Config object that can be passed to this module if
it has already been created.  Otherwise, Drawer will create it from 
the data_source.

=item * min_correspondences

The minimum number of correspondences.

=item * collapse_features

Set to 1 to collaps overlapping features.

=item * cache_dir

Alternate location for the image file

=item * map_view

Either 'viewer' or 'details'.  This is only useful for links in the 
map area.  'viewer' is the default.

=item * data_module

A Bio::GMOD::CMap::Data object that can be passed to this module if
it has already been created.  Otherwise, Drawer will create it.

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

=item * magnify_all

Set to the magnification factor of the whole picture.  The default is 1.

=item * scale_maps

Set to 1 scale the maps with the same unit.  Default is 1.

=item * stack_maps

Set to 1 stack the reference maps vertically.  Default is 0.

=item * ref_map_order

This is the string that dictates the order of the reference maps.  The format
is the list of map_aids in order, separated by commas 

=item * comp_menu_order

This is the string that dictates the order of the comparative maps in the menu.
Options are 'display_order' (order on the map display_order) and 'corrs' (order
on the number of correspondences).  'display_order' is the default.

=back

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.92 $)[-1];

use Bio::GMOD::CMap::Utils 'parse_words';
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use Bio::GMOD::CMap::Drawer::Map;
use Bio::GMOD::CMap::Drawer::Glyph;
use File::Basename;
use File::Temp 'tempfile';
use File::Path;
use Data::Dumper;
use base 'Bio::GMOD::CMap';

my @INIT_PARAMS = qw[
  apr flip slots highlight font_size image_size image_type
  label_features included_feature_types corr_only_feature_types
  included_evidence_types ignored_evidence_types ignored_feature_types
  config data_source min_correspondences collapse_features cache_dir
  map_view data_module aggregate cluster_corr show_intraslot_corr clean_view
  magnify_all scale_maps stack_maps ref_map_order comp_menu_order
  split_agg_ev 
];

# ----------------------------------------------------
sub init {

=pod

=head2 init

Initializes the drawing object.

=cut

    my ( $self, $config ) = @_;

    for my $param (@INIT_PARAMS) {
        $self->$param( $config->{$param} );
    }

    my $gd_class = $self->image_type eq 'svg' ? 'GD::SVG' : 'GD';

    eval "use $gd_class";

    return $self->error(@$) if @$;

    $self->data;
    $self->draw or return;

    return $self;
}

# ----------------------------------------
sub xdata_module {

=pod

=head2 data_module

Returns the CMap::Data object.

=cut

    my $self = shift;
    $self->{'data_module'} = shift if @_;
    unless ( $self->{'data_module'} ) {
        $self->{'data_module'} = $self->SUPER::data_module();
    }
    return $self->{'data_module'} || undef;
}

# ----------------------------------------------------
sub apr {

=pod

=head2 apr

Returns the Apache::Request object.

=cut

    my $self = shift;
    $self->{'apr'} = shift if @_;
    return $self->{'apr'} || undef;
}

# ----------------------------------------------------
sub adjust_frame {

=pod

=head2 adjust_frame

If there's anything drawn in a negative X or Y region, move everything
so that it's positive.

=cut

    my ( $self, %args ) = @_;
    my ( $x_shift, $y_shift );

    if (%args) {
        $x_shift = $args{'x_shift'};
        $y_shift = $args{'y_shift'};
    }

    unless ( defined $x_shift && defined $y_shift ) {
        my $min_x = $self->min_x - 10;
        my $min_y = $self->min_y - 10;
        $x_shift = $min_x < 0 ? abs $min_x : 0;
        $y_shift = $min_y < 0 ? abs $min_y : 0;
    }

    for my $rec (
        map { @{ $self->{'drawing_data'}{$_} } }
        keys %{ $self->{'drawing_data'} }
      )
    {
        my $shape = $rec->[0];
        for my $y_field ( @{ SHAPE_XY->{$shape}{'y'} } ) {
            $rec->[$y_field] += $y_shift;
        }
        for my $x_field ( @{ SHAPE_XY->{$shape}{'x'} } ) {
            $rec->[$x_field] += $x_shift;
        }
    }

    if ( $args{'shift_feature_coords'} ) {
        for my $slot ( values %{ $self->{'feature_position'} } ) {
            for my $feature_pos ( values %{$slot} ) {
                $feature_pos->{'right'}[0] += $x_shift;
                $feature_pos->{'right'}[1] += $y_shift;
                $feature_pos->{'left'}[0]  += $x_shift;
                $feature_pos->{'left'}[1]  += $y_shift;
            }
        }
    }

    unless ( $args{'leave_map_areas'} ) {
        for my $rec ( @{ $self->{'image_map_data'} } ) {
            my @coords = @{ $rec->{'coords'} || [] } or next;
            $coords[$_] += $y_shift for ( 1, 3 );
            $coords[$_] += $x_shift for ( 0, 2 );
            $rec->{'coords'} = [ map { int } @coords ];
        }
    }

    unless ( $args{'leave_max_x_y'} ) {
        $self->{$_} += $x_shift for qw[ min_x max_x ];
        $self->{$_} += $y_shift for qw[ min_y max_y ];
    }

    return 1;
}

# ----------------------------------------------------
sub add_connection {

=pod

=head2 add_connection

Draws a line from one point to another.

=cut

    my ( $self, $x1, $y1, $x2, $y2, $color, $same_map, $label_side, $line_type )
      = @_;
    my $layer = 0;      # bottom-most layer of image
    my @lines = ();
    my $line  = LINE;

    if ( !$line_type or $line_type eq 'direct' ) {
        push @lines, [ $line, $x1, $y1, $x2, $y2, $color, $layer ];
    }
    else {
        my $extention_length = 15;
        if ( $y1 == $y2 ) {
            push @lines, [ $line, $x1, $y1, $x2, $y2, $color ];
        }
        elsif ($same_map) {
            if ( $label_side eq RIGHT ) {
                push @lines,
                  [
                    $line, $x1, $y1, $x1 + $extention_length,
                    $y1, $color, $layer
                  ];
                push @lines,
                  [
                    $line,                   $x1 + $extention_length, $y1,
                    $x2 + $extention_length, $y2,                     $color,
                    $layer
                  ];
                push @lines,
                  [
                    $line, $x2 + $extention_length,
                    $y2, $x2, $y2, $color, $layer
                  ];
            }
            else {
                push @lines,
                  [
                    $line, $x1, $y1, $x1 - $extention_length,
                    $y1, $color, $layer
                  ];
                push @lines,
                  [
                    $line,                   $x1 - $extention_length, $y1,
                    $x2 - $extention_length, $y2,                     $color,
                    $layer
                  ];
                push @lines,
                  [
                    $line, $x2 - $extention_length,
                    $y2, $x2, $y2, $color, $layer
                  ];
            }
        }
        else {
            if ( $x1 < $x2 ) {
                push @lines,
                  [
                    $line, $x1, $y1, $x1 + $extention_length,
                    $y1, $color, $layer
                  ];
                push @lines,
                  [
                    $line,                   $x1 + $extention_length, $y1,
                    $x2 - $extention_length, $y2,                     $color,
                    $layer
                  ];
                push @lines,
                  [
                    $line, $x2 - $extention_length,
                    $y2, $x2, $y2, $color, $layer
                  ];
            }
            else {
                push @lines,
                  [
                    $line, $x1, $y1, $x1 - $extention_length,
                    $y1, $color, $layer
                  ];
                push @lines,
                  [
                    $line,                   $x1 - $extention_length, $y1,
                    $x2 + $extention_length, $y2,                     $color,
                    $layer
                  ];
                push @lines,
                  [
                    $line, $x2 + $extention_length,
                    $y2, $x2, $y2, $color, $layer
                  ];
            }
        }
    }

    return @lines;
}

# ----------------------------------------------------
sub add_drawing {

=pod

=head2 add_drawing

Accepts a list of attributes to describe how to draw an object.

=cut

    my $self = shift;
    my ( @records, @attr );
    if ( ref $_[0] eq 'ARRAY' ) {
        @records = @_;
    }
    else {
        push @records, [@_];
    }

    my ( @x, @y );
    for my $rec (@records) {
        if ( ref $_[0] eq 'ARRAY' ) {
            @attr = @{ shift() };
        }
        else {
            @attr = @_;
        }

        #
        # The last field should be a number specifying the layer.
        # If it's not, then push on the default layer of "1."
        #
        push @attr, 1 unless $attr[-1] =~ m/^-?\d+$/;

        #
        # Extract the X and Y positions in order to pass them to
        # min and max methods (to know how big the image should be).
        #
        my $shape       = $attr[0] or next;
        my $layer       = $attr[-1];
        my @x_locations = @{ SHAPE_XY->{$shape}{'x'} || [] } or next;
        my @y_locations = @{ SHAPE_XY->{$shape}{'y'} || [] } or next;
        push @x, @attr[@x_locations];
        push @y, @attr[@y_locations];

        if ( $shape eq STRING ) {
            my $font   = $attr[1];
            my $string = $attr[4];
            push @x,
              $attr[ $x_locations[0] ] + ( $font->width * length($string) );
            push @y, $attr[ $y_locations[0] ] - $font->height;
        }
        elsif ( $shape eq STRING_UP ) {
            my $font = $attr[1];
            push @x, $attr[ $x_locations[0] ] + $font->height;
        }

        push @{ $self->{'drawing_data'}{$layer} }, [@attr];
    }

    $self->min_x(@x);
    $self->max_x(@x);
    $self->min_y(@y);
    $self->max_y(@y);
}

# ----------------------------------------------------
sub add_map_area {

=pod

=head2 add_map_area

Accepts a list of coordinates and a URL for hyperlinking a map area.

=cut

    my $self = shift;

    if ( ref $_[0] eq 'HASH' ) {
        push @{ $self->{'image_map_data'} }, @_;
    }
    elsif ( ref $_[0] eq 'ARRAY' && @{ $_[0] } ) {
        push @{ $self->{'image_map_data'} }, $_ for @_;
    }
    else {
        push @{ $self->{'image_map_data'} }, {@_} if @_;
    }
}

# ----------------------------------------------------
sub collapse_features {

=pod

=head2 collapse_features

Gets/sets whether to collapse features.

=cut

    my $self = shift;
    my $arg  = shift;

    if ( defined $arg ) {
        $self->{'collapse_features'} = $arg;
    }

    return $self->{'collapse_features'} || 0;
}

# ----------------------------------------------------
sub comparative_map {

=pod

=head2 comparative_map

Gets/sets the comparative map.

=cut

    my $self = shift;
    if ( my $map = shift ) {
        my ( $field, $aid ) = split( /=/, $map )
          or $self->error(qq[Invalid input to comparative map "$map"]);
        $self->{'comparative_map'}{'field'} = $field;
        $self->{'comparative_map'}{'aid'}   = $aid;
    }

    return $self->{'comparative_map'};
}

# ----------------------------------------------------
sub correspondences_exist {

=pod

=head2 correspondence_exist

Returns whether or not there are any feature correspondences.

=cut

    my $self = shift;
    return %{ $self->{'data'}{'correspondences'} || {} } ? 1 : 0;
}

# ----------------------------------------------------
sub intraslot_correspondences_exist {

=pod

=head2 intraslot_correspondence_exist

Returns whether or not there are any intraslot correspondences.

=cut

    my $self = shift;
    return %{ $self->{'data'}{'intraslot_correspondences'} || {} } ? 1 : 0;
}

# ----------------------------------------------------
sub flip {

=pod

=head2 flip

Gets/sets which maps to flip.

=cut

    my $self = shift;
    if ( my $arg = shift ) {
        for my $s ( split /:/, $arg ) {
            my ( $slot_no, $map_aid ) = split /=/, $s or next;
            push @{ $self->{'flip'} },
              {
                slot_no => $slot_no,
                map_aid => $map_aid,
              };
        }
    }

    return $self->{'flip'} || [];
}

# ----------------------------------------------------
sub get_completed_map {

=pod

=head2 get_completed_maps

Gets a completed map.

=cut

    my ( $self, $map_no ) = @_;
    return $self->{'completed_maps'}{$map_no};
}

# ----------------------------------------------------
sub included_evidence_types {

=pod

=head2 included_evidence_types

Gets/sets which evidence type (accession IDs) to include.

=cut

    my $self = shift;

    if ( my $arg = shift ) {
        push @{ $self->{'included_evidence_types'} }, @$arg;
    }
    $self->{'included_evidence_types'} = []
      unless $self->{'included_evidence_types'};

    return $self->{'included_evidence_types'};
}

# ----------------------------------------------------
sub ignored_evidence_types {

=pod

=head2 ignored_evidence_types

Gets/sets which evidence type (accession IDs) to ignore.

=cut

    my $self = shift;

    if ( my $arg = shift ) {
        push @{ $self->{'ignored_evidence_types'} }, @$arg;
    }
    $self->{'ignored_evidence_types'} = []
      unless $self->{'ignored_evidence_types'};

    return $self->{'ignored_evidence_types'};
}

# ----------------------------------------------------
sub included_feature_types {

=pod

=head2 included_feature_types

Gets/sets which feature type (accession IDs) to include.

=cut

    my $self = shift;

    if ( my $arg = shift ) {
        push @{ $self->{'included_feature_types'} }, @$arg;
    }
    $self->{'included_feature_types'} = []
      unless $self->{'included_feature_types'};

    return $self->{'included_feature_types'};
}

# ----------------------------------------------------
sub corr_only_feature_types {

=pod
                                                                                
=head2 corr_only_feature_types
                                                                                
Gets/sets which feature type (accession IDs) to corr_only.
                                                                                
=cut

    my $self = shift;

    if ( my $arg = shift ) {
        push @{ $self->{'corr_only_feature_types'} }, @$arg;
    }
    $self->{'corr_only_feature_types'} = []
      unless $self->{'corr_only_feature_types'};

    return $self->{'corr_only_feature_types'};
}

# ----------------------------------------------------
sub ignored_feature_types {

=pod
                                                                                
=head2 ignored_feature_types
                                                                                
Gets/sets which feature type (accession IDs) to ignore.
                                                                                
=cut

    my $self = shift;

    if ( my $arg = shift ) {
        push @{ $self->{'ignored_feature_types'} }, @$arg;
    }
    $self->{'ignored_feature_types'} = []
      unless $self->{'ignored_feature_types'};

    return $self->{'ignored_feature_types'};
}

# ----------------------------------------------------
sub set_completed_map {

=pod

=head2 set_completed_map

Sets a completed map.

=cut

    my ( $self, %args ) = @_;
    $self->{'completed_maps'}{ $args{'map_no'} } = $args{'map'};
}

# ----------------------------------------------------
sub drawing_data {

=pod

=head2 drawing_data

Returns the drawing data.

=cut

    my $self = shift;
    return map { @{ $self->{'drawing_data'}{$_} } }
      sort     { $a <=> $b }
      keys %{ $self->{'drawing_data'} };
}

# ----------------------------------------------------
sub draw {

=pod

=head2 draw

Lays out the image and writes it to the file system, set the "image_name."

=cut

    my $self = shift;

    my ( $min_y, $max_y, $min_x, $max_x );
    my $corrs_aggregated = 0;
    my $slots_capped_max = undef;
    my $slots_capped_min = undef;

    for my $slot_no ( $self->slot_numbers ) {

        # If there is nothing in one of the slots, don't show any slots
        #  after it.  That is the purpose of the slots_capped variables.
        next if ( defined($slots_capped_max) and $slots_capped_max < $slot_no );
        next if ( defined($slots_capped_min) and $slots_capped_min > $slot_no );
        my $data = $self->slot_data($slot_no) or return;
        unless (%$data) {
            if ( $slot_no > 0 ) {
                $slots_capped_max = $slot_no;
            }
            elsif ( $slot_no < 0 ) {
                $slots_capped_min = $slot_no;

            }
            else {

                # slot is 0
                $slots_capped_max = $slot_no;
                $slots_capped_min = $slot_no;
            }
            next;
        }

        my $map = Bio::GMOD::CMap::Drawer::Map->new(
            drawer      => $self,
            slot_no     => $slot_no,
            maps        => $data,
            config      => $self->config(),
            aggregate   => $self->aggregate,
            clean_view  => $self->clean_view,
            magnify_all => $self->magnify_all,
            scale_maps  => $self->scale_maps,
            stack_maps  => $self->stack_maps,
          )
          or return $self->error( Bio::GMOD::CMap::Drawer::Map->error );

        my ( $bounds, $corrs_aggregated_tmp ) = $map->layout
          or return $self->error( $map->error );
        $corrs_aggregated = $corrs_aggregated_tmp if $corrs_aggregated_tmp;
        $min_x = $bounds->[0] unless defined $min_x;
        $min_y = $bounds->[1] unless defined $min_y;
        $max_x = $bounds->[2] unless defined $max_x;
        $max_y = $bounds->[3] unless defined $max_y;
        $min_x = $bounds->[0] if $bounds->[0] < $min_x;
        $min_y = $bounds->[1] if $bounds->[1] < $min_y;
        $max_x = $bounds->[2] if $bounds->[2] > $max_x;
        $max_y = $bounds->[3] if $bounds->[3] > $max_y;

        $self->slot_sides(
            slot_no => $slot_no,
            left    => $bounds->[0],
            right   => $bounds->[2],
        );
        $self->min_x( ( $min_x, ) );
        $self->max_x( ( $max_x, ) );
        $self->min_y( ( $min_y, ) );
        $self->max_y( ( $max_y, ) );

        #
        # Draw feature correspondences to reference map.
        #

        for my $position_set (
            $self->feature_correspondence_positions( slot_no => $slot_no ) )
        {
            my @positions = @{ $position_set->{'positions'} || [] } or next;
            my $evidence_info = $self->feature_correspondence_evidence(
                $position_set->{'feature_id1'},
                $position_set->{'feature_id2'}
            );

            $self->add_drawing(
                $self->add_connection(
                    @positions,
                    $evidence_info->{'line_color'}
                      || $self->config_data('connecting_line_color'),
                    $position_set->{'same_map'}   || 0,
                    $position_set->{'label_side'} || '',
                    $position_set->{'line_type'},
                )
            );
        }
    }

    #
    # Frame out the slots.
    #
    my $bg_color     = $self->config_data('slot_background_color');
    my $border_color = $self->config_data('slot_border_color');
    for my $slot_no ( $self->slot_numbers ) {
        my ( $left, $right ) = $self->slot_sides( slot_no => $slot_no );
        my @slot_bounds = ( $left, $min_y, $right, $max_y, );

        $self->add_drawing( FILLED_RECT, @slot_bounds, $bg_color,     -1 );
        $self->add_drawing( RECTANGLE,   @slot_bounds, $border_color, 10 );
    }

    #
    # Add the legend
    #
    my @bounds = ( $min_x, $max_y + 10 );
    my $font   = $self->regular_font;
    my $x      = $min_x + 20;
    $max_y += 20;

    #
    # Add the legend for the feature types.
    #
    if ( my @feature_types = $self->feature_types_seen ) {
        my $string = 'Feature Types:';
        $self->add_drawing( STRING, $font, $x, $max_y, $string, 'black' );
        $max_y += $font->height + 10;
        my $end = $x + $font->width * length($string);
        $max_x = $end if $end > $max_x;

        my $corr_color     = $self->config_data('feature_correspondence_color');
        my $ft_details_url = $self->config_data('feature_type_details_url');
        my $et_details_url = $self->config_data('evidence_type_details_url');

        if ( $corr_color && $self->correspondences_exist ) {
            push @feature_types,
              {
                shape        => '',
                color        => $corr_color,
                feature_type => "Features in $corr_color have correspondences",
                correspondence_color => 1,
              };
        }

        for my $ft (@feature_types) {
            my $color = $ft->{'color'} || $self->config_data('feature_color');
            my $label     = $ft->{'feature_type'} or next;
            my $feature_x = $x;
            my $feature_y = $max_y;
            my $label_x   = $feature_x + 15;
            my $label_y;

            if ( $ft->{'shape'} eq 'line' ) {
                $self->add_drawing( LINE, $feature_x, $feature_y,
                    $feature_x + 10,
                    $feature_y, $color );
                $label_y = $feature_y;
            }
            else {
                my @temp_drawing_data;
                my $glyph         = Bio::GMOD::CMap::Drawer::Glyph->new();
                my $feature_glyph = $ft->{'shape'};
                $feature_glyph =~ s/-/_/g;
                if ( $glyph->can($feature_glyph) ) {
                    $glyph->$feature_glyph(
                        drawing_data => \@temp_drawing_data,
                        x_pos2       => $feature_x + 7,
                        x_pos1       => $feature_x + 3,
                        y_pos1       => $feature_y,
                        y_pos2       => $feature_y + 8,
                        color        => $color,
                        label_side   => RIGHT,
                    );
                    $self->add_drawing(@temp_drawing_data);
                }
                $label_y = $feature_y + 5;
            }

            my $ft_y = $label_y - $font->height / 2;
            $self->add_drawing( STRING, $font, $label_x, $ft_y, $label,
                $color );

            $self->add_map_area(
                coords => [
                    $label_x, $ft_y,
                    $label_x + $font->width * length($label),
                    $ft_y + $font->height,
                ],
                url => $ft_details_url . $ft->{'feature_type_aid'},
                alt => "Feature Type Details for $label",
              )
              unless $ft->{'correspondence_color'};

            my $furthest_x = $label_x + $font->width * length($label) + 5;
            $max_x = $furthest_x if $furthest_x > $max_x;
            $max_y = $label_y + $font->height;
        }

        #
        # Evidence type legend.
        #
        if ( my @evidence_types = $self->correspondence_evidence_seen ) {
            $self->add_drawing( STRING, $font, $x, $max_y, 'Evidence Types:',
                'black' );
            $max_y += $font->height + 10;

            for my $et (@evidence_types) {
                my $color = $et->{'line_color'}
                  || $self->config_data('connecting_line_color');
                my $string =
                  ucfirst($color) . ' line denotes ' . $et->{'evidence_type'};

                $self->add_drawing( STRING, $font, $x + 15, $max_y, $string,
                    $color );

                my $end = $x + 15 + $font->width * length($string) + 4;
                $max_x = $end if $end > $max_x;

                $self->add_map_area(
                    coords =>
                      [ $x + 15, $max_y, $end, $max_y + $font->height, ],
                    url => $et_details_url . $et->{'evidence_type_aid'},
                    alt => 'Evidence Type Details for '
                      . $et->{'evidence_type'},
                );

                $max_y += $font->height + 5;
            }
        }
        $max_y += 5;
    }

    if ($corrs_aggregated) {

        $self->add_drawing( STRING, $font, $x, $max_y,
            'Aggregated Correspondences Colors:', 'black' );
        $max_y += $font->height + 10;
        my $all_corr_colors   = $self->aggregated_correspondence_colors;
        if ( $all_corr_colors and %$all_corr_colors ){
            foreach my $evidence_type_aid (keys (%$all_corr_colors)){
                my $corr_colors       = $all_corr_colors->{$evidence_type_aid};
                my $default_color     
                    = $self->default_aggregated_correspondence_color($evidence_type_aid);
                my $last_bound;
                if ( $evidence_type_aid ne DEFAULT->{'aggregated_type_substitute'} ){
                    $self->add_drawing( STRING, $font, $x, $max_y,
                        $self->evidence_type_data($evidence_type_aid, 'evidence_type') 
                        , 'black' );
                    $max_y += $font->height + 4;
                }
                elsif ( scalar ( keys ( %$all_corr_colors) ) > 1 ){
                    # These are the default colors.
                    # They are not needed if the types are defined.
                    next;
                }
                foreach my $color_bound ( 
                    sort { $a <=> $b } grep { $_ } keys(%$corr_colors) 
                ){
                    $self->add_drawing(
                        STRING, $font, $x+15, $max_y,
                        $color_bound . ' or fewer correspondences',
                        $corr_colors->{$color_bound}
                    );
                    $max_y += $font->height + 4;
                    $last_bound = $color_bound;
                }
                $self->add_drawing( STRING, $font, $x+15, $max_y,
                    'More than ' . $last_bound . ' correspondences',
                    $default_color );
                $max_y += $font->height + 6;
            }
        }
        else {
            my $default_color     = $self->default_aggregated_correspondence_color;
            $self->add_drawing( STRING, $font, $x, $max_y,
                'All Aggregated Correspondences',
                $default_color );
            $max_y += $font->height + 4;

        }
        $max_y += $font->height;

    }

    #
    # Extra symbols.
    #
    my @buttons = (
        [ 'i'  => 'Map Set Info' ],
        [ '?'  => 'Map Details' ],
        [ 'M'  => 'Matrix View' ],
        [ 'X'  => 'Delete Map' ],
        [ 'F'  => 'Flip Map' ],
        [ 'UF' => 'Unflip Map' ],
        [ 'N'  => 'New Map View' ],
    );
    {
        $self->add_drawing( STRING, $font, $x, $max_y, 'Menu Symbols:',
            'black' );
        $max_y += $font->height + 10;

        for my $button (@buttons) {
            my ( $sym, $caption ) = @$button;
            $self->add_drawing( STRING, $font, $x + 3, $max_y + 2, $sym,
                'grey' );
            my $end = $x + ( $font->width * length($sym) ) + 4;

            $self->add_drawing( RECTANGLE, $x, $max_y, $end,
                $max_y + $font->height + 4, 'grey' );

            $self->add_drawing( STRING, $font, $end + 5, $max_y + 2, $caption,
                'black' );

            $max_y += $font->height + 10;
        }
    }

    my $watermark = 'CMap v' . $Bio::GMOD::CMap::VERSION;
    my $wm_x      = $max_x - $font->width * length($watermark) - 5;
    my $wm_y      = $max_y;
    $self->add_drawing( STRING, $font, $wm_x, $wm_y, $watermark, 'grey' );
    $self->add_map_area(
        coords => [
            $wm_x,                                     $wm_y,
            $wm_x + $font->width * length($watermark), $wm_y + $font->height
        ],
        url => CMAP_URL,
        alt => 'GMOD-CMap website',
    );

    $max_y += $font->height + 5;

    push @bounds, ( $max_x, $max_y );

    $self->add_drawing( FILLED_RECT, @bounds, $bg_color,     -1 );
    $self->add_drawing( RECTANGLE,   @bounds, $border_color, -1 );

    $self->max_x($max_x);

    #
    # Move all the coordinates to positive numbers.
    #
    $self->adjust_frame;

    my @data      = $self->drawing_data;
    my $height    = $self->map_height;
    my $width     = $self->map_width;
    my $img_class = $self->image_class;
    my $img       = $img_class->new( $width, $height );
    my %colors    =
      map {
        $_, $img->colorAllocate( map { hex $_ } @{ +COLORS->{$_} } )
      }
      keys %{ +COLORS };
    $img->interlaced('true');
    $img->filledRectangle( 0, 0, $width, $height,
        $colors{ $self->config_data('background_color') } );

    #
    # Sort the drawing data by the layer (which is the last field).
    #
    for my $obj ( sort { $a->[-1] <=> $b->[-1] } @data ) {
        my $method = shift @$obj;
        my $layer  = pop @$obj;
        my @colors = pop @$obj;
        push @colors, pop @$obj if $method eq FILL_TO_BORDER;
        $img->$method( @$obj, map { $colors{ lc $_ } } @colors );
    }

    #
    # Add a black box around the whole #!.
    #
    $img->rectangle( 0, 0, $width - 1, $height - 1, $colors{'black'} );

    #
    # Write to a temporary file and remember it.
    #
    my $cache_dir = $self->cache_dir or return;
    my ( $fh, $filename ) = tempfile( 'X' x 9, DIR => $cache_dir );
    my $image_type = $self->image_type;
    print $fh $img->$image_type();
    $fh->close;
    $self->image_name($filename);

    return $self;
}

# ----------------------------------------------------
sub data {

=pod

=head2 data

Uses the Bio::GMOD::CMap::Data module to retreive the 
necessary data for drawing.

=cut

    my $self = shift;

    unless ( $self->{'data'} ) {
        my $data = $self->data_module or return;
        $self->{'data'} = $data->cmap_data(
            slots                       => $self->{'slots'},
            min_correspondences         => $self->min_correspondences,
            included_feature_type_aids  => $self->included_feature_types,
            corr_only_feature_type_aids => $self->corr_only_feature_types,
            ignored_feature_type_aids   => $self->ignored_feature_types,
            included_evidence_types     => $self->included_evidence_types,
            ignored_evidence_type_aids  => $self->ignored_evidence_types,
          )
          or return $self->error( $data->error );

        return $self->error("Problem getting data") unless $self->{'data'};

        # Set the feature and evidence types for later use.
        $self->included_feature_types(
            $self->{'data'}{'included_feature_type_aids'} );
        $self->corr_only_feature_types(
            $self->{'data'}{'corr_only_feature_type_aids'} );
        $self->ignored_feature_types(
            $self->{'data'}{'ignored_feature_type_aids'} );
        $self->included_evidence_types(
            $self->{'data'}{'included_evidence_type_aids'} );
        $self->ignored_evidence_types(
            $self->{'data'}{'ignored_evidence_type_aids'} );
    }

    return $self->{'data'};
}

# ----------------------------------------------------
sub correspondence_evidence_seen {

=pod

=head2 correspondence_evidence_seen

Returns a distinct list of all the correspondence evidence types seen.

=cut

    my $self = shift;
    unless ( $self->{'correspondence_evidence_seen'} ) {
        my %types =
          map { $_->{'evidence_type'}, $_ }
          values %{ $self->{'data'}{'correspondence_evidence'} };

        $self->{'correspondence_evidence_seen'} = [
            map { $types{$_} }
              sort keys %types
        ];
    }

    return @{ $self->{'correspondence_evidence_seen'} || [] };
}

# ----------------------------------------------------
sub feature_correspondence_evidence {

=pod

=head2 feature_correspondence_evidence

Given a feature correspondence ID, returns supporting evidence.

=cut

    my ( $self, $fid1, $fid2 ) = @_;
    my $feature_correspondence_id =
      $self->{'data'}{'correspondences'}{$fid1}{$fid2}
      or return;

    return $self->{'data'}{'correspondence_evidence'}
      {$feature_correspondence_id};
}

# ----------------------------------------------------
sub intraslot_correspondence_evidence {

=pod

=head2 intraslot_correspondence_evidence

Given two feature ids, returns supporting evidence.

=cut

    my ( $self, $fid1, $fid2 ) = @_;
    my $intraslot_correspondence_id =
      $self->{'data'}{'intraslot_correspondences'}{$fid1}{$fid2}
      or return;

    return $self->{'data'}{'intraslot_correspondence_evidence'}
      {$intraslot_correspondence_id};
}

# ----------------------------------------------------
sub feature_types_seen {

=pod

=head2 feature_types_seen

Returns all the feature types seen on the maps.

=cut

    my $self = shift;
    unless ( $self->{'feature_types'} ) {
        $self->{'feature_types'} =
          [ values %{ $self->{'data'}{'feature_types'} || {} } ];
    }

    return sort { lc $a->{'feature_type'} cmp lc $b->{'feature_type'} }
      map { $_->{'seen'} ? $_ : () } @{ $self->{'feature_types'} || [] };
}

# ----------------------------------------------------
sub feature_correspondences {

=pod

=head2 feature_correspondences

Returns the correspondences for a given feature id.

=cut

    my $self = shift;
    my @feature_ids = ref $_[0] eq 'ARRAY' ? @{ shift() } : ( shift() );
    return unless @feature_ids;

    return
      map { keys %{ $self->{'data'}{'correspondences'}{$_} || {} } }
      @feature_ids;
}

# ----------------------------------------------------
sub intraslot_correspondences {

=pod

=head2 intraslot_correspondences

Returns the correspondences for a given feature id.

=cut

    my $self = shift;
    my @feature_ids = ref $_[0] eq 'ARRAY' ? @{ shift() } : ( shift() );
    return unless @feature_ids;

    return
      map { keys %{ $self->{'data'}{'intraslot_correspondences'}{$_} || {} } }
      @feature_ids;
}

# ----------------------------------------------------
sub feature_correspondence_positions {

=pod

=head2 feature_correspondence_positions

Accepts a slot number and returns an array of arrayrefs denoting the positions
to connect corresponding features on two maps.

=cut

    my ( $self, %args ) = @_;
    my $slot_no     = $args{'slot_no'};
    my $ref_slot_no = $self->reference_slot_no($slot_no);
    my $ref_side    = $slot_no > 0 ? RIGHT: LEFT;
    my $cur_side    = $slot_no > 0 ? LEFT: RIGHT;

    my @return = ();
    for my $f1 ( keys %{ $self->{'feature_position'}{$slot_no} } ) {
        my $self_label_side = $self->label_side($slot_no);

        my @f1_pos =
          @{ $self->{'feature_position'}{$slot_no}{$f1}{$cur_side} || [] }
          or next;

        my @f1_self_pos =
          @{ $self->{'feature_position'}{$slot_no}{$f1}{$self_label_side}
              || [] }
          or next;
        for my $f2 ( $self->feature_correspondences($f1) ) {
            my @same_map =
              @{ $self->{'feature_position'}{$slot_no}{$f2}{$self_label_side}
                  || [] };

            my @ref_pos =
              @{ $self->{'feature_position'}{$ref_slot_no}{$f2}{$ref_side}
                  || [] };

            push @return,
              {
                feature_id1 => $f1,
                feature_id2 => $f2,
                positions   => [ @f1_self_pos, @same_map ],
                same_map    => 1,
                label_side  => $self->label_side($slot_no),
                line_type   => 'direct',
              }
              if @same_map;

            push @return,
              {
                feature_id1 => $f1,
                feature_id2 => $f2,
                positions   => [ @f1_pos, @ref_pos ],
                line_type   => 'direct',
              }
              if @ref_pos;
        }
        for my $f2 ( $self->intraslot_correspondences($f1) ) {
            my @same_map =
              @{ $self->{'feature_position'}{$slot_no}{$f2}{$self_label_side}
                  || [] };

            my @ref_pos =
              @{ $self->{'feature_position'}{$ref_slot_no}{$f2}{$ref_side}
                  || [] };

            push @return,
              {
                feature_id1 => $f1,
                feature_id2 => $f2,
                positions   => [ @f1_self_pos, @same_map ],
                same_map    => 1,
                label_side  => $self->label_side($slot_no),
                line_type   => 'indirect',
              }
              if @same_map;

            push @return,
              {
                feature_id1 => $f1,
                feature_id2 => $f2,
                positions   => [ @f1_pos, @ref_pos ],
                line_type   => 'indirect',
              }
              if @ref_pos;
        }
    }

    return @return;
}

# ----------------------------------------------------
sub font_size {

=pod

=head2 font_size

Returns the font size.

=cut

    my $self      = shift;
    my $font_size = shift;

    if ( $font_size && defined VALID->{'font_size'}{$font_size} ) {
        $self->{'font_size'} = $font_size;
    }

    unless ( $self->{'font_size'} ) {
        $self->{'font_size'} = $self->config_data('font_size')
          || DEFAULT->{'font_size'};
    }

    return $self->{'font_size'};
}

# ----------------------------------------------------
sub has_correspondence {

=pod

=head2 has_correspondence

Returns whether or not a feature has a correspondence.

=cut

    my $self = shift;
    my $feature_id = shift or return;
    return defined $self->{'data'}{'correspondences'}{$feature_id}
      || defined $self->{'data'}{'intraslot_correspondences'}{$feature_id};
}

# ----------------------------------------------------
sub highlight {

=pod

=head2 highlight

Gets/sets the string of highlighted features.

=cut

    my $self = shift;
    $self->{'highlight'} = shift if @_;
    return $self->{'highlight'};
}

# ----------------------------------------------------
sub highlight_feature {

=pod

=head2 highlight_feature

Gets/sets the string of highlighted features.

=cut

    my ( $self, @ids ) = @_;
    return unless @ids;

    unless ( defined $self->{'highlight_hash'} ) {
        if ( my $highlight = $self->highlight ) {

            #
            # Remove leading and trailing whitespace, convert to uppercase.
            #
            $self->{'highlight_hash'} =
              { map { s/^\s+|\s+$//g; ( uc $_, 1 ) } parse_words($highlight) };
        }
        else {

            #
            # Define it to nothing.
            #
            $self->{'highlight_hash'} = '';
        }
    }

    return unless $self->{'highlight_hash'};

    for my $id (@ids) {
        return 1 if exists $self->{'highlight_hash'}{ uc $id };
    }

    return 0;
}

# ----------------------------------------------------
sub font_class {

=pod

=head2 font_class

Returns 'GD::SVG::Font' if $self->image_type returns 'svg'; otherwise 
'GD::Font.'

=cut

    my $self = shift;
    return $self->image_type eq 'svg' ? 'GD::SVG::Font' : 'GD::Font';
}

# ----------------------------------------------------
sub image_class {

=pod

=head2 image_class

Returns 'GD::SVG' if $self->image_type returns 'svg'; otherwise 'GD.'

=cut

    my $self = shift;
    return $self->image_type eq 'svg' ? 'GD::SVG::Image' : 'GD::Image';
}

# ----------------------------------------------------
sub image_map_data {

=pod

=head2 image_map_data

Returns an array of records with the "coords" and "url" for each image map
area.

=cut

    my $self = shift;
    return @{ $self->{'image_map_data'} || [] };
}

# ----------------------------------------------------
sub image_size {

=pod

=head2 image_size

Returns the set image size.

=cut

    my $self       = shift;
    my $image_size = shift;

    if ( $image_size && VALID->{'image_size'}{$image_size} ) {
        $self->{'image_size'} = $image_size;
    }

    unless ( defined $self->{'image_size'} ) {
        $self->{'image_size'} = $self->config_data('image_size')
          || DEFAULT->{'image_size'};
    }

    return $self->{'image_size'};
}

# ----------------------------------------------------
sub image_type {

=pod

=head2 image_type

Gets/sets the current image type.

=cut

    my $self       = shift;
    my $image_type = shift;

    if ( $image_type && VALID->{'image_type'}{$image_type} ) {
        $self->{'image_type'} = $image_type;
    }

    unless ( defined $self->{'image_type'} ) {
        $self->{'image_type'} = $self->config_data('image_type')
          || DEFAULT->{'image_type'};
    }

    return $self->{'image_type'};
}

# ----------------------------------------------------
sub image_name {

=pod

=head2 image_name

Gets/sets the current image name.

=cut

    my $self = shift;

    if ( my $path = shift ) {
        return $self->error(qq[Unable to read image file "$path"])
          unless -r $path;
        my $image_name = basename($path);
        $self->{'image_name'} = $image_name;
    }

    return $self->{'image_name'} || '';
}

# ----------------------------------------------------
sub label_side {

=pod

=head2 label_side

Returns the side to place the labels based on the map number.  The only
map this would really affect is the main reference map, and only then 
when there is only one comparative map:  When the comparative map is 
on the left, put the labels on the right of the main reference map;
otherwise, always put the labels of maps 1 and greater on the right
and everything else on the left.

=cut

    my ( $self, $slot_no ) = @_;

    unless (defined( $self->{'label_side'} )
        and defined( $self->{'label_side'}{$slot_no} ) )
    {
        my $side;
        if ( $slot_no == 0 && $self->total_no_slots == 2 ) {
            my $slot_data = $self->slot_data;
            $side = defined $slot_data->{-1} ? RIGHT: LEFT;
        }
        elsif ( $slot_no == 0 && $self->total_no_slots == 1 ) {
            $side = RIGHT;
        }
        elsif ( $slot_no == 0 ) {
            my $slot_data = $self->slot_data;
            $side = defined $slot_data->{1} ? LEFT: RIGHT;
        }
        elsif ( $slot_no > 0 ) {
            $side = RIGHT;
        }
        else {
            $side = LEFT;
        }

        $self->{'label_side'}{$slot_no} = $side;
    }

    return $self->{'label_side'}{$slot_no};
}

# ----------------------------------------------------
sub map_correspondences {

=pod

=head2 map_correspondences

Returns the correspondences from a slot no to its reference slot.

=cut

    my ( $self, $slot_no, $map_id ) = @_;
    if ( defined $slot_no && $map_id ) {
        return $self->{'data'}{'map_correspondences'}{$slot_no}{$map_id};
    }
    elsif ( defined $slot_no ) {
        return $self->{'data'}{'map_correspondences'}{$slot_no};
    }
    else {
        return {};
    }
}

# ----------------------------------------------------
sub map_height {

=pod

=head2 map_height

Gets/sets the output map image's height.

=cut

    my $self = shift;
    return $self->max_y + 10;
}

# ----------------------------------------------------
sub map_width {

=pod

=head2 map_width

Gets/sets the output map image's width.

=cut

    my $self = shift;
    return $self->max_x + 10;
}

# ----------------------------------------------------
sub map_view {

=pod

=head2 map_view

Gets/sets whether we're looking at the regular viewer or details.

=cut

    my $self = shift;
    $self->{'map_view'} = shift if @_;
    return $self->{'map_view'} || 'viewer';
}

# ----------------------------------------------------
sub min_correspondences {

=pod

=head2 min_correspondences

Gets/sets the minimum number of correspondences.

=cut

    my $self = shift;
    $self->{'min_correspondences'} = shift if @_;
    return $self->{'min_correspondences'} || 0;
}

# ----------------------------------------------------
sub label_features {

=pod

=head2 label_features

Gets/sets whether to show feature labels.

=cut

    my $self = shift;

    if ( my $arg = shift ) {
        $self->error(qq[Show feature labels input "$arg" invalid])
          unless VALID->{'label_features'}{$arg};
        $self->{'label_features'} = $arg;
    }

    return $self->{'label_features'} || '';
}

# ----------------------------------------------------
sub slot_numbers {

=pod

=head2 slot_numbers

Returns the slot numbers, 0 to positive, -1 to negative.

=cut

    my $self = shift;

    #unless ( $self->{'slot_numbers'} ) {
    my @slot_nos = keys %{ $self->{'slots'} };
    my @pos      = sort { $a <=> $b } grep { $_ >= 0 } @slot_nos;
    my @neg      = sort { $b <=> $a } grep { $_ < 0 } @slot_nos;

    $self->{'slot_numbers'} = [ @pos, @neg ];

    #}

    return @{ $self->{'slot_numbers'} };
}

# ----------------------------------------------------
sub slot_data {

=pod

=head2 slot_data

Returns the data for one or all slots.

=cut

    my $self = shift;
    my $data = $self->data;

    if ( defined( my $slot_no = shift ) ) {
        return exists $data->{'slots'}{$slot_no}
          ? $data->{'slots'}{$slot_no}
          : undef;
    }
    else {
        return $data->{'slots'};
    }
}

# ----------------------------------------------------
sub slot_sides {

=pod

=head2 slot_sides

Remembers the right and left bounds of a slot.

=cut

    my ( $self, %args ) = @_;
    my $slot_no = $args{'slot_no'} || 0;
    my $right   = $args{'right'};
    my $left    = $args{'left'};

    if ( defined $right && defined $left ) {
        $self->{'slot_sides'}{$slot_no} = [ $left, $right ];
    }

    return @{ $self->{'slot_sides'}{$slot_no} || [] };
}

# ----------------------------------------------------
sub slots {

=pod

=head2 slots

Gets/sets what's in the "slots" (the maps in each position).

=cut

    my $self = shift;
    $self->{'slots'} = shift if @_;
    return $self->{'slots'};
}

# ----------------------------------------------------
sub max_x {

=pod

=head2 max_x

Gets/sets the maximum x-coordinate.

=cut

    my $self = shift;

    if ( my @args = sort { $a <=> $b } @_ ) {
        $self->{'max_x'} = $args[-1] unless defined $self->{'max_x'};
        $self->{'max_x'} = $args[-1] if $args[-1] > $self->{'max_x'};
    }

    return $self->{'max_x'} || 0;
}

# ----------------------------------------------------
sub max_y {

=pod

=head2 max_y

Gets/sets the maximum x-coordinate.

=cut

    my $self = shift;

    if ( my @args = sort { $a <=> $b } @_ ) {
        $self->{'max_y'} = $args[-1] unless defined $self->{'max_y'};
        $self->{'max_y'} = $args[-1] if $args[-1] > $self->{'max_y'};
    }

    return $self->{'max_y'} || 0;
}

# ----------------------------------------------------
sub min_x {

=pod

=head2 min_x

Gets/sets the minimum x-coordinate.

=cut

    my $self = shift;

    if ( my @args = sort { $a <=> $b } @_ ) {
        $self->{'min_x'} = $args[0] unless defined $self->{'min_x'};
        $self->{'min_x'} = $args[0] if $args[0] < $self->{'min_x'};
    }

    return $self->{'min_x'} || 0;
}

# ----------------------------------------------------
sub min_y {

=pod

=head2 min_y

Gets/sets the minimum x-coordinate.

=cut

    my $self = shift;

    if ( my @args = sort { $a <=> $b } @_ ) {
        $self->{'min_y'} = $args[0] unless defined $self->{'min_y'};
        $self->{'min_y'} = $args[0] if $args[0] < $self->{'min_y'};
    }

    return $self->{'min_y'} || 0;
}

# ----------------------------------------------------
sub pixel_height {

=pod

=head2 pixel_height

Returns the pixel height of the image based upon the requested "image_size."

=cut

    my $self = shift;

    unless ( $self->{'pixel_height'} ) {
        my $image_size = $self->image_size;
        $self->{'pixel_height'} = VALID->{'image_size'}{$image_size}
          or $self->error("Can't figure out pixel height");
    }

    return $self->{'pixel_height'};
}

# ----------------------------------------------------
sub reference_slot_no {

=pod

=head2 reference_slot_no

Returns the reference slot number for a given slot number.

=cut

    my ( $self, $slot_no ) = @_;
    return unless defined $slot_no;

    my $ref_slot_no =
        $slot_no > 0 ? $slot_no - 1
      : $slot_no < 0 ? $slot_no + 1
      : undef;
    return undef unless defined $ref_slot_no;

    my $slot_data = $self->slot_data;
    return defined $slot_data->{$ref_slot_no} ? $ref_slot_no : undef;
}

# ----------------------------------------------------
sub register_feature_type {

=pod

=head2 register_feature_type

Remembers a feature type.

=cut

    my ( $self, @feature_type_ids ) = @_;
    $self->{'data'}{'feature_types'}{$_}{'seen'} = 1 for @feature_type_ids;
}

# ----------------------------------------------------
sub register_feature_position {

=pod

=head2 register_feature_position

Remembers the feature position on a map.

=cut

    my ( $self, %args ) = @_;
    my $feature_id = $args{'feature_id'} or return;
    my $slot_no = $args{'slot_no'};
    return unless defined $slot_no;

    $self->{'feature_position'}{$slot_no}{$feature_id} = {
        right  => $args{'right'},
        left   => $args{'left'},
        tick_y => $args{'tick_y'},
        map_id => $args{'map_id'},
    };
}

# ----------------------------------------------------
sub register_map_coords {

=pod

=head2 register_map_coords

Returns the font for the "regular" stuff (feature labels, map names, etc.).

=cut

    my (
        $self, $slot_no, $map_id, $start, $stop,
        $x1,   $y1,      $x2,     $y2,    $is_flipped
      )
      = @_;
    $self->{'map_coords'}{$slot_no}{$map_id} = {
        map_start  => $start,
        map_stop   => $stop,
        y1         => $y1,
        y2         => $y2,
        x1         => $x1,
        x2         => $x2,
        is_flipped => $is_flipped,
    };
}

# ----------------------------------------------------
sub reference_map_coords {

=pod

=head2 reference_map_coords

Returns top and bottom y coordinates of the reference map for a given 
slot and map id.

=cut

    my ( $self, $slot_no, $map_id ) = @_;

    #
    # The correspondence record contains the min and max start
    # positions from this slot to
    #
    if ( defined $slot_no && $map_id ) {
        return $self->{'map_coords'}{$slot_no}{$map_id};
    }
    else {
        return {};
    }
}

# ----------------------------------------------------
sub regular_font {

=pod

=head2 regular_font

Returns the font for the "regular" stuff (feature labels, map names, etc.).

=cut

    my $self = shift;
    unless ( $self->{'regular_font'} ) {
        my $font_size = $self->font_size;
        my $font_pkg  = $self->font_class or return;
        my %methods   = (
            small  => 'Tiny',
            medium => 'Small',
            large  => 'Large',
        );

        if ( my $font = $methods{$font_size} ) {
            $self->{'regular_font'} = $font_pkg->$font()
              or return $self->error(
                "Error creating font with package '$font_pkg'");
        }
        else {
            return $self->error(qq[No "regular" font for "$font_size"]);
        }
    }

    return $self->{'regular_font'};
}

# ----------------------------------------------------
sub tick_y_positions {

=pod

=head2 tick_y_positions

Returns the "tick_y" positions of the features IDs in a given slot.

=cut

    my ( $self, %args ) = @_;
    my $slot_no     = $args{'slot_no'};
    my $feature_ids = $args{'feature_ids'};

    return unless defined $slot_no && @$feature_ids;

    push @$feature_ids, $self->feature_correspondences($feature_ids);

    my @return = ();
    for my $feature_id (@$feature_ids) {
        push @return,
          $self->{'feature_position'}{$slot_no}{$feature_id}{'tick_y'}
          || ();
    }

    return @return;
}

# ----------------------------------------------------
sub total_no_slots {

=pod

=head2 total_no_slots

Returns the number of slots.

=cut

    my $self = shift;
    return scalar keys %{ $self->slot_data };
}

# ----------------------------------------------------
sub aggregated_correspondence_colors {

=pod

=head2 aggregated_correspondence_colors

Returns the correspondence colors specified in the config file for 
that evidence type.  Defaults to the 'aggregated_correspondence_colors'
that is defined in the main section.

=cut

    my $self              = shift;
    my $evidence_type_aid = shift;

    return $self->{'corr_colors'}
         unless ($evidence_type_aid);

    unless ( $self->{'corr_colors'} and $self->{'corr_colors'}{$evidence_type_aid} ) {
        unless ($self->{'corr_colors'}{$evidence_type_aid} =
            $self->evidence_type_data( $evidence_type_aid, 'aggregated_correspondence_colors' )
        ){
          $self->{'corr_colors'}{$evidence_type_aid} = 
              $self->config_data('aggregated_correspondence_colors');
        }
    }

    return $self->{'corr_colors'}{$evidence_type_aid};
}

# ----------------------------------------------------
sub default_aggregated_correspondence_color {

=pod

=head2 default_aggregated_correspondence_color

Returns the correspondence colors specified as the default or 
the value in Constants.pm for aggregated_correspondence_color.

=cut

    my $self = shift;
    my $evidence_type_aid = shift;

    $evidence_type_aid = DEFAULT->{'aggregated_type_substitute'}
         unless ($evidence_type_aid);

    unless ( $self->{'default_corr_color'} 
        and $self->{'default_corr_color'}{$evidence_type_aid}
    ) {
        my $corr_colors = $self->aggregated_correspondence_colors($evidence_type_aid);
        if ( $corr_colors and %$corr_colors ) {
            $self->{'default_corr_color'}{$evidence_type_aid} = $corr_colors->{0};
        }
        unless ( $self->{'default_corr_color'}{$evidence_type_aid} ) {
            $self->{'default_corr_color'}{$evidence_type_aid}
                = DEFAULT->{'aggregated_correspondence_color'};
        }
    }

    return $self->{'default_corr_color'}{$evidence_type_aid};
}

# ----------------------------------------------------
sub aggregated_line_color {

=pod

=head2 aggregated_line_color

Given the evidence type and the number of correspondences, 
return the correct line color for the aggregated correspondences.

=cut

    my ( $self, %args ) = @_;
    my $evidence_type_aid = $args{'evidence_type_aid'};
    my $corr_no = $args{'corr_no'};

    my $corr_colors       = $self->aggregated_correspondence_colors($evidence_type_aid);
    my $line_color        = $self->default_aggregated_correspondence_color($evidence_type_aid);
    foreach my $color_bound ( 
        sort { $a <=> $b } grep { $_ } keys(%$corr_colors) 
    ){
        if ( $corr_no <= $color_bound ) {
            $line_color = $corr_colors->{$color_bound};
            last;
        }
    }
    return $line_color;
}

# ----------------------------------------------------
sub create_link_params {

=pod

=head2 create_link_params

Creates default link parameters for CMap->create_viewer_link()

=cut

    my ( $self, %args ) = @_;
    my $prev_ref_species_aid        = $args{'prev_ref_species_aid'};
    my $prev_ref_map_set_aid        = $args{'prev_ref_map_set_aid'};
    my $ref_species_aid             = $args{'ref_species_aid'};
    my $ref_map_set_aid             = $args{'ref_map_set_aid'};
    my $ref_map_names               = $args{'ref_map_names'};
    my $ref_map_start               = $args{'ref_map_start'};
    my $ref_map_stop                = $args{'ref_map_stop'};
    my $comparative_maps            = $args{'comparative_maps'};
    my $highlight                   = $args{'highlight'};
    my $font_size                   = $args{'font_size'};
    my $image_size                  = $args{'image_size'};
    my $image_type                  = $args{'image_type'};
    my $label_features              = $args{'label_features'};
    my $collapse_features           = $args{'collapse_features'};
    my $aggregate                   = $args{'aggregate'};
    my $cluster_corr                = $args{'cluster_corr'};
    my $scale_maps                  = $args{'scale_maps'};
    my $stack_maps                  = $args{'stack_maps'};
    my $ref_map_order               = $args{'ref_map_order'};
    my $comp_menu_order             = $args{'comp_menu_order'};
    my $show_intraslot_corr         = $args{'show_intraslot_corr'};
    my $split_agg_ev                = $args{'split_agg_ev'};
    my $clean_view                  = $args{'clean_view'};
    my $magnify_all                 = $args{'magnify_all'};
    my $flip                        = $args{'flip'};
    my $min_correspondences         = $args{'min_correspondences'};
    my $ref_map_aids                = $args{'ref_map_aids'};
    my $feature_type_aids           = $args{'feature_type_aids'};
    my $corr_only_feature_type_aids = $args{'corr_only_feature_type_aids'};
    my $ignored_feature_type_aids   = $args{'ignored_feature_type_aids'};

    my $evidence_type_aids         = $args{'evidence_type_aids'};
    my $ignored_evidence_type_aids = $args{'ignored_evidence_type_aids'};
    my $data_source                = $args{'data_source'};
    my $url                        = $args{'url'};

    ### Required Fields that Drawer can't figure out.
    unless ( defined($ref_map_set_aid) ) {
        return;
        $ref_map_set_aid = undef;
    }

    ### Optional fields for finer control
    unless ( defined($prev_ref_species_aid) ) {
        $prev_ref_species_aid = undef;
    }
    unless ( defined($prev_ref_map_set_aid) ) {
        $prev_ref_map_set_aid = undef;
    }
    unless ( defined($ref_species_aid) ) {
        $ref_species_aid = undef;
    }
    unless ( defined($ref_map_names) ) {
        $ref_map_names = undef;
    }
    unless ( defined($ref_map_start) ) {
        $ref_map_start = undef;
    }
    unless ( defined($ref_map_stop) ) {
        $ref_map_stop = undef;
    }
    unless ( defined($comparative_maps) ) {
        $comparative_maps = undef;
    }
    unless ( defined($highlight) ) {
        $highlight = $self->highlight();
    }
    unless ( defined($font_size) ) {
        $font_size = $self->font_size();
    }
    unless ( defined($image_size) ) {
        $image_size = $self->image_size();
    }
    unless ( defined($image_type) ) {
        $image_type = $self->image_type();
    }
    unless ( defined($label_features) ) {
        $label_features = $self->label_features();
    }
    unless ( defined($collapse_features) ) {
        $collapse_features = $self->collapse_features();
    }
    unless ( defined($aggregate) ) {
        $aggregate = $self->aggregate();
    }
    unless ( defined($cluster_corr) ) {
        $cluster_corr = $self->cluster_corr();
    }
    unless ( defined($scale_maps) ) {
        $scale_maps = $self->scale_maps();
    }
    unless ( defined($stack_maps) ) {
        $stack_maps = $self->stack_maps();
    }
    unless ( defined($comp_menu_order) ) {
        $comp_menu_order = $self->comp_menu_order();
    }
    unless ( defined($ref_map_order) ) {
        $ref_map_order = $self->ref_map_order();
    }
    unless ( defined($show_intraslot_corr) ) {
        $show_intraslot_corr = $self->show_intraslot_corr();
    }
    unless ( defined($split_agg_ev) ) {
        $split_agg_ev = $self->split_agg_ev();
    }
    unless ( defined($clean_view) ) {
        $clean_view = $self->clean_view();
    }
    unless ( defined($magnify_all) ) {
        $magnify_all = $self->magnify_all();
    }
    unless ( defined($flip) ) {
        my @flips;
        for my $rec ( @{ $self->flip } ) {
            push @flips, $rec->{'slot_no'} . '%3d' . $rec->{'map_aid'};
        }
        $flip = join( ":", @flips );
    }
    unless ( defined($min_correspondences) ) {
        $min_correspondences = $self->min_correspondences();
    }
    unless ( defined($ref_map_aids) ) {
        $ref_map_aids = $self->ref_map_aids();
    }
    unless ( defined($feature_type_aids) ) {
        $feature_type_aids = $self->included_feature_types();
    }
    unless ( defined($corr_only_feature_type_aids) ) {
        $corr_only_feature_type_aids = $self->corr_only_feature_types();
    }
    unless ( defined($ignored_feature_type_aids) ) {
        $ignored_feature_type_aids = $self->ignored_feature_types();
    }
    unless ( defined($ignored_evidence_type_aids) ) {
        $ignored_evidence_type_aids = $self->ignored_evidence_types();
    }
    unless ( defined($evidence_type_aids) ) {
        $evidence_type_aids = $self->included_evidence_types();
    }
    unless ( defined($data_source) ) {
        $data_source = $self->data_source();
    }
    unless ( defined($url) ) {
        $url = '/viewer';
    }

    return (
        prev_ref_species_aid        => $prev_ref_species_aid,
        prev_ref_map_set_aid        => $prev_ref_map_set_aid,
        ref_species_aid             => $ref_species_aid,
        ref_map_set_aid             => $ref_map_set_aid,
        ref_map_names               => $ref_map_names,
        ref_map_start               => $ref_map_start,
        ref_map_stop                => $ref_map_stop,
        comparative_maps            => $comparative_maps,
        highlight                   => $highlight,
        font_size                   => $font_size,
        image_size                  => $image_size,
        image_type                  => $image_type,
        label_features              => $label_features,
        collapse_features           => $collapse_features,
        aggregate                   => $aggregate,
        cluster_corr                => $cluster_corr,
        scale_maps                  => $scale_maps,
        stack_maps                  => $stack_maps,
        ref_map_order               => $ref_map_order,
        comp_menu_order             => $comp_menu_order,
        show_intraslot_corr         => $show_intraslot_corr,
        split_agg_ev                => $split_agg_ev,
        clean_view                  => $clean_view,
        magnify_all                 => $magnify_all,
        flip                        => $flip,
        min_correspondences         => $min_correspondences,
        ref_map_aids                => $ref_map_aids,
        feature_type_aids           => $feature_type_aids,
        corr_only_feature_type_aids => $corr_only_feature_type_aids,
        ignored_feature_type_aids   => $ignored_feature_type_aids,
        ignored_evidence_type_aids  => $ignored_evidence_type_aids,
        evidence_type_aids          => $evidence_type_aids,
        data_source                 => $data_source,
        url                         => $url,
    );
}


# ----------------------------------------------------
# It is not all books that are as dull as their readers.
# Henry David Thoreau
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>, L<GD>, L<GD::SVG>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

