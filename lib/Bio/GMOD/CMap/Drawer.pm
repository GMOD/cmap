package Bio::GMOD::CMap::Drawer;

# $Id: Drawer.pm,v 1.11 2002-09-24 22:39:04 kycl4rk Exp $

=head1 NAME

Bio::GMOD::CMap::Drawer - draw maps

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Drawer;
  my $drawer = Bio::GMOD::CMap::Drawer( ref_map_id => 12345 );
  $drawer->image_name;

=head1 DESCRIPTION

The base map drawing module.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.11 $)[-1];

use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Data;
use Bio::GMOD::CMap::Drawer::Map;
use GD;
use File::MkTemp;
use File::Path;
use Data::Dumper;
use base 'Bio::GMOD::CMap';

use constant INIT_PARAMS => [
    qw( apr slots highlight font_size image_size image_type include_features )
];

# ----------------------------------------------------
sub init {

=pod

=head2 init

Initializes the drawing object.

=cut

    my ( $self, $config ) = @_;

    for my $param ( @{ +INIT_PARAMS } ) {
        $self->$param( $config->{ $param } );
    }

#    $Error::Debug = $self->debugging ? 1 : 0;
    $self->draw;
    return $self;
}

## ----------------------------------------------------
#sub add_map_href_bounds {
#
#=pod
#
#=head2 add_map_href_bounds
#
#Stores the coords for making maps clickable.
#
#=cut
#    my ( $self, %args ) = @_;
#    push @{ $self->{'map_href_bounds'} }, \%args; 
#}

# ----------------------------------------------------
sub apr {

=pod

=head2 apr

Returns the Apache::Request object.

=cut
    my $self       = shift;
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
    my $self    = shift;
    my $min_x   = $self->min_x - 10;
    my $min_y   = $self->min_y - 10;
    my $x_shift = $min_x < 0 ? abs $min_x : 0;
    my $y_shift = $min_y < 0 ? abs $min_y : 0;

    for my $rec ( 
        map   { @{ $self->{'drawing_data'}{ $_ } } }
        keys %{ $self->{'drawing_data'} }
    ) {
        my $shape = $rec->[0];
        for my $y_field ( @{ SHAPE_XY->{ $shape }{'y'} } ) {
            $rec->[ $y_field ] += $y_shift;
        }
        for my $x_field ( @{ SHAPE_XY->{ $shape }{'x'} } ) {
            $rec->[ $x_field ] += $x_shift;
        }
    }

    for my $rec ( @{ $self->{'image_map_data'} } ) {
        my @coords       = @{ $rec->{'coords'} };
        $coords[ $_ ]   += $y_shift for ( 1, 3 );
        $coords[ $_ ]   += $x_shift for ( 0, 2 );
        $rec->{'coords'} = join( ',', map { int } @coords );
    }

    $self->{ $_ } += $x_shift for qw[ min_x max_x ];
    $self->{ $_ } += $y_shift for qw[ min_y max_y ];

    return 1;
}

# ----------------------------------------------------
sub add_connection {

=pod

=head2 add_connection

Draws a line from one point to another.

=cut
    my ( $self, $x1, $y1, $x2, $y2, $color ) = @_;
    my $layer = 0; # bottom-most layer of image
    my @lines = ();

    if ( $y1 == $y2 ) {
        push @lines, [ LINE, $x1, $y1, $x2, $y2, $color ];
    }
    else {
        if ( $x1 < $x2 ) {
            push @lines, [ LINE, $x1  , $y1, $x1+5, $y1, $color, $layer ];
            push @lines, [ LINE, $x1+5, $y1, $x2-5, $y2, $color, $layer ];
            push @lines, [ LINE, $x2-5, $y2, $x2  , $y2, $color, $layer ];
        }
        else {
            push @lines, [ LINE, $x1  , $y1, $x1-5, $y1, $color, $layer ];
            push @lines, [ LINE, $x1-5, $y1, $x2+5, $y2, $color, $layer ];
            push @lines, [ LINE, $x2+5, $y2, $x2  , $y2, $color, $layer ];
        }
    }

    $self->add_drawing( @lines );
}

# ----------------------------------------------------
sub add_drawing {

=pod

=head2 add_drawing

Accepts a list of attributes to describe how to draw an object.

=cut
    my $self  = shift;
    my ( @records, @attr );
    if ( ref $_[0] eq 'ARRAY' ) {
        @records = @_;
    }
    else {
        push @records, [ @_ ];
    }

    my ( @x, @y );
    for my $rec ( @records ) {
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
        push @attr, 1 unless $attr[ -1 ] =~ m/^-?\d+$/;

        #
        # Extract the X and Y positions in order to pass them to 
        # min and max methods (to know how big the image should be).
        #
        my $shape = $attr[  0 ];
        my $layer = $attr[ -1 ];
        $self->error( qq[Shape "$shape" is not valid] )
            unless VALID->{'shape'}{ $shape };
        my @x_locations = @{ SHAPE_XY->{ $shape }{'x'} };
        my @y_locations = @{ SHAPE_XY->{ $shape }{'y'} };
        push @x, @attr[ @x_locations ];
        push @y, @attr[ @y_locations ];

        if ( $shape eq STRING ) {
            my $font   = $attr[1];
            my $string = $attr[4];
            push @x, $attr[ $x_locations[0] ] + ($font->width*length($string));
            push @y, $attr[ $y_locations[0] ] - $font->height;
        }
        elsif ( $shape eq STRING_UP ) {
            my $font   = $attr[1];
            push @x, $attr[ $x_locations[0] ] + $font->height;
        }

        push @{ $self->{'drawing_data'}{ $layer } }, [ @attr ];
    }

    $self->min_x( @x ); 
    $self->max_x( @x );
    $self->min_y( @y ); 
    $self->max_y( @y );
}

# ----------------------------------------------------
sub add_map_area {

=pod

=head2 add_drawing

Accepts a list of coordinates and a URL for hyperlinking a map area.

=cut
    my ( $self, %args ) = @_;
    push @{ $self->{'image_map_data'} }, { %args };
}

# ----------------------------------------------------
sub cache_dir {

=pod

=head2 cache_dir

Returns the cache directory.

=cut
    my $self = shift;

    unless ( defined $self->{'cache_dir'} ) {
        my $cache_dir   = $self->config('cache_dir');
        -d $cache_dir || eval{ mkpath( $cache_dir, 0, 0700 ) } || 
            return $self->error("No cache dir; Using '$cache_dir'");
        $self->{'cache_dir'} = $cache_dir;
    }

    return $self->{'cache_dir'};
}

# ----------------------------------------------------
sub comparative_map {

=pod

=head2 comparative_map

Gets/sets the comparative map.

=cut
    my $self = shift;
    if ( my $map = shift ) {
        my ( $field, $aid ) = split( /=/, $map ) or 
            $self->error( qq[Invalid input to comparative map "$map"] );
        $self->{'comparative_map'}{'field'} = $field;
        $self->{'comparative_map'}{'aid'}   = $aid;
    }

    return $self->{'comparative_map'};
}

# ----------------------------------------------------
sub get_completed_map {

=pod

=head2 get_completed_maps

Gets a completed map.

=cut
    my ( $self, $map_no ) = @_;
    return $self->{'completed_maps'}{ $map_no };
}

## ----------------------------------------------------
#sub get_map_href_bounds {
#
#=pod
#
#=head2 get_map_href_bounds
#
#Retrieves the coords for making maps clickable.
#
#=cut
#    my $self = shift;
#    return $self->{'map_href_bounds'};
#}

## ----------------------------------------------------
#sub hyperlink_maps {
#
#=pod
#
#=head2 hyperlink_maps
#
#Make maps clickable.
#
#=cut
#    my $self  = shift;
#    my $slots = $self->slots;
#
#    for my $href ( @{ $self->get_map_href_bounds } ) {
#        my $slot_no  = $href->{'slot_no'};
#        my $map_id   = $href->{'map_id'};
#        my $map_name = $href->{'map_name'};
#        my @bounds   = @{ $href->{'bounds'} };
#        my @maps;
#        for my $side ( qw[ left right ] ) {
#            my $no      = $side eq 'left' ? $slot_no - 1 : $slot_no + 1;
#            my $new_no  = $side eq 'left' ? -1 : 1;
#            my $map     = $slots->{ $no } or next; 
#            my $link    = 
#                join( '%3d', $new_no, map { $map->{$_} } qw[ field aid ] );
#
#            if ( 
#                my @ref_positions = sort { $a <=> $b }
#                $self->feature_correspondence_map_positions(
#                    slot_no     => $slot_no,
#                    map_id      => $map_id,
#                    ref_slot_no => $no,
#                )
#            ) {
#                my $first = $ref_positions[0];
#                my $last  = $ref_positions[-1];
#                $link    .= "[$first,$last]";
#            }
#
#            push @maps, $link;
#        }
#
#        my $url = $self->config('map_details_url').
#            '?ref_map_set_aid='.$self->map_set_aid( $map_id ).
#            ';ref_map_aid='.$self->accession_id( $map_id ).
#            ';comparative_maps='.join( ':', @maps );
#
#        $self->add_map_area(
#            coords => \@bounds,
#            url    => $url,
#            alt    => 'Details: '.$map_name,
#        );
#    }
#}

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
    return 
        map   { @{ $self->{'drawing_data'}{ $_ } } }
        sort  { $a <=> $b } 
        keys %{ $self->{'drawing_data'} };
}

# ----------------------------------------------------
sub draw {

=pod

=head2 draw

Lays out the image and writes it to the file system, set the "image_name."

=cut
    my $self = shift;

    my ( $min_y, $max_y );
    for my $slot_no ( $self->slot_numbers ) {
        my $data      = $self->slot_data( $slot_no );
        my $map       =  Bio::GMOD::CMap::Drawer::Map->new( 
            drawer    => $self, 
#            base_x    => $self->max_x,
#            base_y    => 0,
            slot_no   => $slot_no,
            maps      => $data,
        );
        my @bounds = $map->layout;
        $min_y     = $bounds[1] unless defined $min_y;
        $min_y     = $bounds[1] if $bounds[1] < $min_y;
        $max_y     = $bounds[3] unless defined $max_y;
        $max_y     = $bounds[3] if $bounds[3] > $max_y;
        $self->slot_sides( 
            slot_no => $slot_no,
            left    => $bounds[0], 
            right   => $bounds[2],
        );
    }

    #
    # Frame out the slots.
    #
    my $bg_color     = $self->config('slot_background_color');
    my $border_color = $self->config('slot_border_color');
    for my $slot_no ( $self->slot_numbers ) {
        my ( $left, $right ) = $self->slot_sides( slot_no => $slot_no );
        my @slot_bounds = (
            $left,
            $min_y,
            $right,
            $max_y,
        );

        $self->add_drawing( FILLED_RECT, @slot_bounds, $bg_color,     -1 );
        $self->add_drawing( RECTANGLE,   @slot_bounds, $border_color, -1 );
    }
    $self->adjust_frame;

    my @data   = $self->drawing_data;
    my $height = $self->map_height;
    my $width  = $self->map_width;
    my $gd     = GD::Image->new( $width, $height );
    my %colors =
        map { $_, $gd->colorAllocate( map { hex $_ } @{ +COLORS->{$_} } ) }
        keys %{ +COLORS }
    ;
    $gd->interlaced( 'true' );
    $gd->fill( 0, 0, $colors{ $self->config('background_color') } );

    #
    # Sort the drawing data by the layer (which is the last field).
    #
    for my $obj ( sort { $a->[-1] <=> $b->[-1] } @data ) {
        my $method = shift @$obj;
        my $layer  = pop   @$obj;
        my @colors = pop   @$obj;
        push @colors, pop @$obj if $method eq FILL_TO_BORDER;
        $gd->$method( @$obj, map { $colors{ lc $_ } } @colors );
    }

    #
    # Add a black box around the whole #!.
    #
    $gd->rectangle( 0, 0, $width - 1, $height - 1, $colors{'black'} );

    #
    # Write to a temporary file and remember it.
    #
    my $cache_dir = $self->cache_dir;
    my ( $fh, $filename ) = mkstempt( 'X' x 9, $cache_dir );
    my $image_type = $self->image_type;
    print $fh $gd->$image_type();
    $fh->close;
    $self->image_name( $filename );

    return 1;
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
        my $data             =  Bio::GMOD::CMap::Data->new;
        $self->{'data'}      =  $data->cmap_data( 
            slots            => $self->slots,
            include_features => $self->include_features,
        );
    }

    return $self->{'data'};
}

# ----------------------------------------------------
sub has_correspondence {

=pod

=head2 has_correspondence

Returns whether or not a feature has a correspondence.

=cut
    my $self       = shift;
    my $feature_id = shift or return;
    return defined $self->{'data'}{'correspondences'}{ $feature_id };
}

# ----------------------------------------------------
sub feature_correspondences {

=pod

=head2 feature_correspondences

Returns the correspondences for a given feature id.

=cut
    my $self        = shift;
    my @feature_ids = ref $_[0] eq 'ARRAY' ? @{ shift() } : ( shift() );
    return unless @feature_ids;

    return map { keys %{ $self->{'data'}{'correspondences'}{ $_ } || {} } }
        @feature_ids;
}

# ----------------------------------------------------
sub feature_correspondence_positions {

=pod

=head2 feature_correspondence_positions

Accepts a map number and returns an array of arrayrefs denoting the positions
to connect corresponding features on two maps.

=cut
    my ( $self, %args ) = @_;
    my $slot_no         = $args{'slot_no'};
    my $ref_slot_no     = $self->reference_slot_no( $slot_no );

    return unless defined $slot_no and defined $ref_slot_no;

    my $ref_side = $slot_no > 0 ? RIGHT : LEFT;
    my $cur_side = $slot_no > 0 ? LEFT  : RIGHT;

    my @return = ();
    for my $f1 ( keys %{ $self->{'feature_position'}{ $slot_no } } ) {
        my @f1_pos = @{
            $self->{'feature_position'}{ $slot_no }{ $f1 }{ $cur_side }
            || []
        } or next;

        for my $f2 ( $self->feature_correspondences( $f1 ) ) {
            my @ref_pos = @{ 
                $self->{'feature_position'}{ $ref_slot_no }{ $f2 }{ $ref_side } 
                || []
            } or next;
            push @return, [ @f1_pos, @ref_pos ];
        }
    }

    return @return;
}

# ----------------------------------------------------
sub feature_correspondence_map_positions {

=pod

=head2 feature_correspondence_map_positions

Accepts a map number and returns an array of arrayrefs denoting the 
map positions (start, stop) in the reference slot to use when selecting a
region of corresponding features.

=cut
    my ( $self, %args ) = @_;
    my $slot_no         = $args{'slot_no'};
    my $map_id          = $args{'map_id'};
    my $comp_slot_no    = $args{'comp_slot_no'};
    my $comp_slot_data  = $self->slot_data( $comp_slot_no );
    return unless defined $slot_no && defined $comp_slot_no && $comp_slot_data;
    my @comp_map_ids    = map { $_ || () } keys %$comp_slot_data;
    return if scalar @comp_map_ids > 1; # too many maps (e.g., contigs)
    my $comp_map        = $comp_slot_data->{ $comp_map_ids[0] };

    my @return = ();
    for my $f1 ( keys %{ $self->{'feature_position'}{ $slot_no } } ) {
        next if defined $map_id && 
            $self->{'feature_position'}{ $slot_no }{$f1}{'map_id'} != $map_id;

        for my $f2 ( $self->feature_correspondences( $f1 ) ) {
            next unless defined $comp_map->{'features'}{ $f2 };
            push @return, $comp_map->{'features'}{ $f2 }{'start_position'};
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
    if ( my $font_size = shift ) {
        $self->error(qq[Font size "$font_size" is not valid"])
            unless defined VALID->{'font_size'}{ $font_size };
        $self->{'font_size'} ||= $font_size;
    }
    return $self->{'font_size'};
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

=head2 highlight

Gets/sets the string of highlighted features.

=cut
    my $self         = shift;
    my $feature_name = uc shift or return;

    unless ( defined $self->{'highlight_hash'} ) {
        if ( my $highlight = $self->highlight ) {
            #
            # Remove leading and trailing slashes, convert to uppercase.
            #
            $self->{'highlight_hash'} = {
                map  { s/^\s+|\s+$//g; ( uc $_, 1 ) }
                split( /[\s,]/, $highlight )
            };
        }
        else {
            #
            # Define it to nothing.
            #
            $self->{'highlight_hash'} = '';
        }
    }

    return unless $self->{'highlight_hash'};
    return exists $self->{'highlight_hash'}{ $feature_name };
}

# ----------------------------------------------------
sub image_map_data {

=pod

=head2 image_size

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

    my $self = shift;

    if ( my $image_size = shift ) {
        return $self->error( qq[Invalid image size ("$image_size")] )
            unless VALID->{'image_size'}{ $image_size };
        $self->{'image_size'} = $image_size;
    }

    unless ( defined $self->{'image_size'} ) {
        $self->{'image_size'} = $self->config('image_size');
    }

    return $self->{'image_size'};
}

# ----------------------------------------------------
sub image_type {

=pod

=head2 image_type

Gets/sets the current image type.

=cut

    my $self = shift;

    if ( my $image_type = shift ) {
        return $self->error( qq[Invalid image type ("$image_type")] )
            unless VALID->{'image_type'}{ $image_type };
        $self->{'image_type'} = $image_type;
    }

    unless ( defined $self->{'image_type'} ) {
        $self->{'image_type'} = $self->config('image_type');
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
    if ( my $image_name = shift ) {
        my $path = join( '/', $self->cache_dir, $image_name );
        return $self->error(qq[Unable to read image file "$path"])
            unless -r $path;
        $self->{'image_name'} = $image_name;
    }

    return $self->{'image_name'} || '';
}

# ----------------------------------------------------
sub label_font {

=pod

=head2 label_font

Returns the font for the "label" stuff (titles mostly).

=cut
    my $self = shift;
    unless ( $self->{'label_font'} ) {
        my $font_size = $self->font_size;
        $self->{'label_font'} = VALID->{'font_size'}{ $font_size }{'label'}
            or $self->error(qq[No label font for font size "$font_size"])
    }

    return $self->{'label_font'};
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

    unless ( $self->{'label_side'}{ $slot_no } ) {
        my $side;
        if ( $slot_no == 0 && $self->total_no_slots == 2 ) {
            my $slot_data = $self->slot_data;
            $side = defined $slot_data->{ -1 } ? RIGHT : LEFT;
        }
        elsif ( $slot_no == 0 && $self->total_no_slots == 1 ) {
            $side = LEFT;
        }
        elsif ( $slot_no == 0 ) {
            my $slot_data = $self->slot_data;
            $side = defined $slot_data->{ 1 } ? LEFT : RIGHT;
        }
        elsif ( $slot_no > 0 ) {
            $side = RIGHT;
        }
        else {
            $side = LEFT;
        }

        $self->{'label_side'}{ $slot_no } = $side;
    }

    return $self->{'label_side'}{ $slot_no };
}

# ----------------------------------------------------
sub layout_menu {

=pod

=head2 layout_menu

Lays out the menu.

=cut

    my $self   = shift;
    my @fields = qw[ species_name map_set_name map_name ];
    my @labels = ();
    for my $map ( $self->slot_data ) {
        push @labels, join( '-', map { $map->{ $_ } } @fields );
    }
#    warn "labels = ", join("\n", @labels), "\n";
    my $label_font = $self->label_font;

    for my $label ( @labels ) {
        my $label_y     = $self->min_y - $label_font->height - 10;
        my $label_width = $label_font->width * length( $label );
        my $map_width   = $self->max_x - $self->min_x;
#           $map_width   = $label_width if $map_width < $label_width;
        my $label_x     = $map_width/2 - $label_width/2;
        $self->add_drawing(
            STRING, $label_font, $label_x, $label_y, $label, 'black'
        );
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
sub include_features {

=pod

=head2 include_features

Gets/sets whether to show feature labels.

=cut
    my $self = shift;

    if ( my $arg = shift ) {
        $self->error(qq[Show feature labels input "$arg" invalid])
            unless VALID->{'include_features'}{ $arg };
        $self->{'include_features'} = $arg;
    }

    return $self->{'include_features'} || 0;
}

# ----------------------------------------------------
sub slot_numbers {

=pod

=head2 slot_numbers

Returns the slot numbers, 0 to positive, -1 to negative.

=cut
    my $self = shift;

    unless ( $self->{'slot_numbers'} ) {
        my @slot_nos = keys %{ $self->{'slots'} };
        my @pos      = sort { $a <=> $b } grep { $_ >= 0 } @slot_nos;
        my @neg      = sort { $b <=> $a } grep { $_ <  0 } @slot_nos;

        $self->{'slot_numbers'} = [ @pos, @neg ];
    }

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

    if ( defined ( my $slot_no = shift ) ) {
        return exists $data->{'slots'}{ $slot_no }
            ? $data->{'slots'}{ $slot_no } : undef;
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
    my $slot_no         = $args{'slot_no'} || 0;
    my $right           = $args{'right'};
    my $left            = $args{'left'};

    if ( defined $right && defined $left ) {
        $self->{'slot_sides'}{ $slot_no } = [ $left, $right ];
    }

    return @{ $self->{'slot_sides'}{ $slot_no } || [] };
}

# ----------------------------------------------------
sub slots {

=pod

=head2 slots

Gets/sets what's in the "slots" (the maps in each position).

=cut
    my $self         = shift;
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
        my $image_size          = $self->image_size;
        $self->{'pixel_height'} = VALID->{'image_size'}{ $image_size }
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
        $slot_no > 0 ? $slot_no - 1 : 
        $slot_no < 0 ? $slot_no + 1 : 
        undef
    ;
    return undef unless defined $ref_slot_no;

    my $slot_data = $self->slot_data;
    return defined $slot_data->{ $ref_slot_no } ? $ref_slot_no : undef;
}

# ----------------------------------------------------
sub register_feature_position {

=pod

=head2 register_feature_position

Remembers the feature position on a map.

=cut
    my ( $self, %args ) = @_;
    my $feature_id      = $args{'feature_id'} or return;
    my $slot_no         = $args{'slot_no'};
    return unless defined $slot_no;

    $self->{'feature_position'}{ $slot_no }{ $feature_id } = {
        right  => $args{'right'},
        left   => $args{'left'},
        tick_y => $args{'tick_y'},
        map_id => $args{'map_id'},
#        start  => $args{'start'},
#        stop   => $args{'stop'},
    };
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
        $self->{'regular_font'} = VALID->{'font_size'}{ $font_size }{'regular'}
            or $self->error(qq[No "regular" font for "$font_size"])
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
    my $slot_no         = $args{'slot_no'};
    my $feature_ids     = $args{'feature_ids'};

    return unless defined $slot_no && @$feature_ids;

    push @$feature_ids, $self->feature_correspondences( $feature_ids );

    my @return = ();
    for my $feature_id ( @$feature_ids ) {
        push @return, 
            $self->{'feature_position'}{ $slot_no }{ $feature_id }{'tick_y'} 
            || ()
        ;
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

1;

# ----------------------------------------------------
# It is not all books that are as dull as their readers.
# Henry David Thoreau
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>, L<GD>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

Copyright (c) 2002 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
