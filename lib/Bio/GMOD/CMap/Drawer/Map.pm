package Bio::GMOD::CMap::Drawer::Map;

# vim: set ft=perl:

# $Id: Map.pm,v 1.124 2004-09-13 20:55:07 mwz444 Exp $

=pod

=head1 NAME

Bio::GMOD::CMap::Drawer::Map - draw a map

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Drawer::Map;
  blah blah blah

=head1 DESCRIPTION

You'll never directly use this module.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.124 $)[-1];

use URI::Escape;
use Data::Dumper;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Utils qw[
  even_label_distribution
  simple_column_distribution
  commify
  presentable_number
];
use Bio::GMOD::CMap::Drawer::Glyph;
use base 'Bio::GMOD::CMap';

my @INIT_FIELDS = qw[ drawer base_x base_y slot_no maps config aggregate magnify_all scale_maps ];

my %SHAPE = (
    'default'  => 'draw_box',
    'box'      => 'draw_box',
    'dumbbell' => 'draw_dumbbell',
    'I-beam'   => 'draw_i_beam',
);

BEGIN {

    #
    # Create automatic accessor methods.
    #
    my @AUTO_FIELDS = qw[
      map_set_id map_set_aid map_type accession_id species_id
      map_id species_name map_units map_name map_set_name
      map_type_id is_relational_map begin end species_aid map_type_aid
    ];

    foreach my $sub_name (@AUTO_FIELDS) {
        no strict 'refs';
        unless ( defined &$sub_name ) {
            *{$sub_name} = sub {
                my $self   = shift;
                my $map_id = shift;
                return $self->{'maps'}{$map_id}{$sub_name};
            };
        }
    }
}

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->params( $config, @INIT_FIELDS );
    return $self;
}

# ----------------------------------------------------
sub base_x {

=pod

=head2 base_x

Figure out where right-to-left this map belongs.

=cut

    my $self    = shift;
    my $slot_no = $self->slot_no;
    my $drawer  = $self->drawer;
    my $buffer  = 15;

    my $base_x;
    if ( $slot_no < 0 || ( $slot_no == 0 && $drawer->label_side eq LEFT ) ) {
        $base_x = $drawer->min_x - $buffer;
    }
    else {
        $base_x = $drawer->max_x + $buffer;
    }

    return $base_x;
}

# ----------------------------------------------------
sub base_y {

=pod

=head2 base_y

Return the base y coordinate.

=cut

    my $self = shift;
    return $self->{'base_y'} || 0;
}

# ----------------------------------------------------
sub color {

=pod

=head2 color

Returns the color of the map.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    return $map->{'color'}
      || $map->{'default_color'}
      || $self->config_data('map_color');
}

# ----------------------------------------------------
sub drawer {

=pod

=head2 drawer

Returns the Bio::GMOD::CMap::Drawer object.

=cut

    my $self = shift;
    return $self->{'drawer'};
}

# ----------------------------------------------------
sub draw_box {

=pod

=head2 draw_box

Draws the map as a "box" (a filled-in rectangle).  Return the bounds of the
box.

=cut

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $map_area_data = $args{'map_area_data'};
    my $drawer = $args{'drawer'} || $self->drawer
      or $self->error('No drawer');
    my ( $x1, $y1, $y2 ) = @{ $args{'coords'} || [] }
      or $self->error('No coordinates');
    my $map_id    = $args{'map_id'};
    my $map_aid    = $self->map_aid($map_id);
    my $is_flipped = $args{'is_flipped'};
    my $slot_no   = $args{'slot_no'};
    my $color     = $self->color( $map_id );
    my $width     = $self->map_width( $map_id );
    my $x2        = $x1 + $width;
    my $x_mid     = $x1 + ($width/2);
    my @coords = ( $x1, $y1, $x2, $y2 );
    my @map_coords = @coords;

    my $truncated = $drawer->data_module->truncatedMap($slot_no,$map_id);
    if (($truncated>=2 and $is_flipped) 
        or (($truncated==1 or $truncated==3) and not $is_flipped)){
        $self->draw_truncation_arrows(
            is_up         => 1,
            map_coords    => \@map_coords,
            coords        => \@coords,
            drawer        => $drawer,
            map_area_data => $map_area_data,
            drawing_data  => $drawing_data,
            is_flipped    => $is_flipped,
            map_id        => $map_id,
            map_aid       => $map_aid,
            slot_no       => $slot_no,
        )
    }

    push @$drawing_data, [ FILLED_RECT, @map_coords, $color ];
    push @$drawing_data, [ RECTANGLE,   @map_coords, 'black' ];

    if (($truncated>=2 and not $is_flipped) 
        or (($truncated==1 or $truncated==3) and $is_flipped)){
        $self->draw_truncation_arrows(
            is_up         => 0,
            map_coords    => \@map_coords,
            coords        => \@coords,
            drawer        => $drawer,
            map_area_data => $map_area_data,
            drawing_data  => $drawing_data,
            is_flipped    => $is_flipped,
            map_id        => $map_id,
            map_aid       => $map_aid,
            slot_no       => $slot_no,
        )
    }

    if ( my $map_units = $args{'map_units'} ) {
        $self->draw_map_bottom(
            map_id  => $map_id,
            slot_no => $slot_no,
            map_x1  => $map_coords[0],
            map_x2  => $map_coords[2],
            map_y2  => $map_coords[3],
            drawer  => $drawer,
            drawing_data  => $drawing_data,
            map_area_data => $map_area_data,
            map_units  => $map_units,
            bounds  => \@coords,
        );
    }

    return (\@coords,\@map_coords);
}

# ----------------------------------------------------
sub draw_dumbbell {

=pod

=head2 draw_dumbbell

Draws the map as a "dumbbell" (a line with circles on the ends).  Return the
bounds of the image.

=cut

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $map_area_data = $args{'map_area_data'};
    my $drawer = $args{'drawer'} || $self->drawer
      or $self->error('No drawer');
    my ( $x1, $y1, $y2 ) = @{ $args{'coords'} || [] }
      or $self->error('No coordinates');
    my $map_id    = $args{'map_id'};
    my $is_flipped = $args{'is_flipped'};
    my $slot_no   = $args{'slot_no'};
    my $map_aid      = $self->map_aid($map_id);
    my $color     = $self->color( $map_id );
    my $width     = $self->map_width( $map_id );
    my $x2        = $x1 + $width;
    my $mid_x     = $x1 + $width / 2;
    my $arc_width = $width + 6;

    my $drew_bells =0;
    my @coords = ( $x1, $y1, $x2, $y2 );
    my @map_coords = ($x1,$y1,$x2,$y2);
    my $truncated = $drawer->data_module->truncatedMap($slot_no,$map_id);
    if (($truncated>=2 and $is_flipped) 
        or (($truncated==1 or $truncated==3) and not $is_flipped)){
        $self->draw_truncation_arrows(
            is_up         => 1,
            map_coords    => \@map_coords,
            coords        => \@coords,
            drawer        => $drawer,
            map_area_data => $map_area_data,
            drawing_data  => $drawing_data,
            is_flipped    => $is_flipped,
            map_id        => $map_id,
            map_aid       => $map_aid,
            slot_no       => $slot_no,
        )
    }
    else{
        push @$drawing_data,
          [ ARC, $mid_x, $map_coords[1], $arc_width, $arc_width, 0, 360, $color ];
        push @$drawing_data, [ FILL_TO_BORDER, $mid_x, $map_coords[1], $color, $color ];
        $drew_bells = 1;
    }
    if (($truncated>=2 and not $is_flipped) 
        or (($truncated==1 or $truncated==3) and $is_flipped)){
        $self->draw_truncation_arrows(
            is_up         => 0,
            map_coords    => \@map_coords,
            coords        => \@coords,
            drawer        => $drawer,
            map_area_data => $map_area_data,
            drawing_data  => $drawing_data,
            is_flipped    => $is_flipped,
            map_id        => $map_id,
            map_aid       => $map_aid,
            slot_no       => $slot_no,
        )
    }
    else{
        push @$drawing_data,
          [ ARC, $mid_x, $map_coords[3], $arc_width, $arc_width, 0, 360, $color ];
        push @$drawing_data, [ FILL_TO_BORDER, $mid_x, $map_coords[3], $color, $color ];
        $drew_bells = 1;
    }
    push @$drawing_data, [ FILLED_RECT,    $map_coords[0],    $map_coords[1], $map_coords[2],    $map_coords[3], $color ];

    if ( my $map_units = $args{'map_units'} ) {
        $self->draw_map_bottom(
            map_id  => $map_id,
            slot_no => $slot_no,
            map_x1  => $map_coords[0],
            map_x2  => $map_coords[2],
            map_y2  => $map_coords[3],
            drawer  => $drawer,
            drawing_data  => $drawing_data,
            map_area_data => $map_area_data,
            map_units  => $map_units,
            bounds  => \@coords,
        );
    }
    if ($drew_bells){
        $coords[0] = $mid_x - $arc_width / 2
            if ($coords[0] > $mid_x - $arc_width / 2); 
        $coords[1] = $map_coords[1] - $arc_width / 2
            if ($coords[1] > $map_coords[1] - $arc_width / 2); 
        $coords[2] = $mid_x + $arc_width / 2
            if ($coords[2] < $mid_x + $arc_width / 2); 
        $coords[3] = $map_coords[3] + $arc_width / 2
            if ($coords[3] < $map_coords[3] + $arc_width / 2); 
    }
    return (
        \@coords,
        \@map_coords
    );
}

# ----------------------------------------------------
sub draw_i_beam {

=pod

=head2 draw_i_beam

Draws the map as an "I-beam."  Return the bounds of the image.

=cut

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $map_area_data = $args{'map_area_data'};
    my $drawer = $args{'drawer'} || $self->drawer
      or $self->error('No drawer');
    my ( $x1, $y1, $y2 ) = @{ $args{'coords'} || [] }
      or $self->error('No coordinates');
    my $map_id= $args{'map_id'};
    my $is_flipped = $args{'is_flipped'};
    my $slot_no   = $args{'slot_no'};
    my $map_aid      = $self->map_aid($map_id);
    my $color = $self->color( $map_id );
    my $width = $self->map_width( $map_id );
    my $x2    = $x1 + $width;
    my $x     = $x1 + $width / 2;

    my @coords=($x1,  $y1, $x2,  $y2);
    my @map_coords=($x1,  $y1, $x2,  $y2);
    my $truncated = $drawer->data_module->truncatedMap($slot_no,$map_id);
    if (($truncated>=2 and $is_flipped) 
        or (($truncated==1 or $truncated==3) and not $is_flipped)){
        $self->draw_truncation_arrows(
            is_up         => 1,
            map_coords    => \@map_coords,
            coords        => \@coords,
            drawer        => $drawer,
            map_area_data => $map_area_data,
            drawing_data  => $drawing_data,
            is_flipped    => $is_flipped,
            map_id        => $map_id,
            map_aid       => $map_aid,
            slot_no       => $slot_no,
        )
    }
    else{
        push @$drawing_data, [ LINE, $map_coords[0], $map_coords[1], $map_coords[2], $map_coords[1], $color ];
    }
    if (($truncated>=2 and not $is_flipped) 
        or (($truncated==1 or $truncated==3) and $is_flipped)){
        $self->draw_truncation_arrows(
            is_up         => 0,
            map_coords    => \@map_coords,
            coords        => \@coords,
            drawer        => $drawer,
            map_area_data => $map_area_data,
            drawing_data  => $drawing_data,
            is_flipped    => $is_flipped,
            map_id        => $map_id,
            map_aid       => $map_aid,
            slot_no       => $slot_no,
        )
    }
    else{
        push @$drawing_data, [ LINE, $map_coords[0], $map_coords[3], $map_coords[2], $map_coords[3], $color ];
    }
    push @$drawing_data, [ LINE, $x,  $map_coords[1], $x,  $map_coords[3], $color ];
    if ( my $map_units = $args{'map_units'} ) {
        $self->draw_map_bottom(
            map_id  => $map_id,
            slot_no => $slot_no,
            map_x1  => $map_coords[0],
            map_x2  => $map_coords[2],
            map_y2  => $map_coords[3],
            drawer  => $drawer,
            drawing_data  => $drawing_data,
            map_area_data => $map_area_data,
            map_units  => $map_units,
            bounds  => \@coords,
        );
    }

    return ( \@coords,\@map_coords );
}

# ----------------------------------------------------
sub draw_map_bottom{

=pod

=head2 draw_map_bottom

draws the information to be placed at the bottom of the map
such as the units.

=cut

    my ($self,%args) = @_;
    my $map_id       = $args{'map_id'};
    my $slot_no      = $args{'slot_no'};
    my $x1           = $args{'map_x1'};
    my $x2           = $args{'map_x2'};
    my $y2           = $args{'map_y2'};
    my $drawer       = $args{'drawer'};
    my $drawing_data = $args{'drawing_data'};
    my $map_area_data = $args{'map_area_data'};
    my $map_units    = $args{'map_units'};
    my $bounds       = $args{'bounds'};
    my $top_buf          = 12;
    my $buf              = 2;
    my $font         = $drawer->regular_font;
    my $y            = $y2 + $top_buf;
    my $x_mid        = $x1 + ( ( $x2 - $x1 ) / 2 );    
    my $magnification=$drawer->data_module->magnification($slot_no,$map_id);
    my $slot_info=$drawer->data_module->slot_info->{$slot_no};
    my $start_pos   = defined($slot_info->{$map_id}->[0])
        ? $slot_info->{$map_id}->[0]
            : "''";
    my $stop_pos   = defined($slot_info->{$map_id}->[1])
            ? $slot_info->{$map_id}->[1]
            : "''";
    my $x;
    my $code;
    my $map_aid      = $self->map_aid($map_id);
    ###Full size button if needed
    if ($drawer->data_module->truncatedMap($slot_no,$map_id)
        or $magnification!=1){
        my $full_str="Reset Map"; 
        $x  = $x_mid -
            (($font->width * length($full_str)) / 2);
        push @$drawing_data, [ STRING, $font, $x, $y, $full_str, 'grey' ];
        $code=qq[
            onMouseOver="window.status='Make map original size';return true" 
            onClick="mod_map_info($slot_no, '$map_aid', '', '',1);document.comparative_map_form.submit();"
            ]; 
        push @$map_area_data,
          {
            coords => [
                $x,
                $y, 
                $x+($font->width * length($full_str)),
                $y+$font->height,
                ],
            url  => '#',
            alt  => 'Make map original size',
            code => $code,
          };
        $y += $font->height + $buf;
        $bounds->[0]=$x
            if ($bounds->[0]<$x);
        $bounds->[2]=$x+($font->width * length($full_str))
            if ($bounds->[2]<$x+($font->width * length($full_str)));
        $bounds->[3]=$y+$font->height
            if ($bounds->[3]<$y+$font->height);

    }

    ###Scale buttons
    my $mag_plus_val  = $magnification<=1?$magnification*2:$magnification*2;
    my $mag_minus_val = $magnification<=1?$magnification/2:$magnification/2;
    my $mag_plus_str  = "+";
    my $mag_minus_str = "-";
    my $mag_mid_str   = " Mag ";
    $x  = $x_mid -
            (($font->width * length($mag_minus_str.$mag_plus_str.$mag_mid_str)) / 2);

    # Minus side
    push @$drawing_data, [ STRING, $font, $x, $y, $mag_minus_str, 'grey' ];
    $code=qq[
        onMouseOver="window.status='Magnify by $mag_minus_val times original size';return true" 
        onClick="mod_map_info($slot_no,'$map_aid',$start_pos, $stop_pos,$mag_minus_val);document.comparative_map_form.submit();"
        ]; 
    push @$map_area_data,
      {
        coords => [
            $x,
            $y, 
            $x+($font->width * length($mag_minus_str)),
            $y+$font->height],
        url  => '#',
        alt  => 'Magnification',
        code => $code,
      };
    $bounds->[0]=$x
        if ($bounds->[0]>$x);
    $bounds->[3]=$y+$font->height
        if ($bounds->[3]<$y+$font->height);
    $x+=($font->width * length($mag_minus_str));
    # Middle
    push @$drawing_data, [ STRING, $font, $x, $y, $mag_mid_str, 'grey' ];
    $code=qq[
        onMouseOver="window.status='Current Magnification: $magnification times original size';return true" 
        ]; 
    push @$map_area_data,
      {
        coords => [
            $x,
            $y, 
            $x+($font->width * length($mag_mid_str)),
            $y+$font->height],
        url  => '',
        alt  => 'Current Magnification: '.$magnification.' times',
        code => $code,
      };
    $x+=($font->width * length($mag_mid_str));
    # Plus Side
    push @$drawing_data, [ STRING, $font, $x, $y, $mag_plus_str, 'grey' ];
    $code=qq[
        onMouseOver="window.status='Magnify by $mag_plus_val times original size';return true" 
        onClick="mod_map_info($slot_no,'$map_aid',$start_pos,$stop_pos,$mag_plus_val);document.comparative_map_form.submit();"
        ]; 
    push @$map_area_data,
      {
        coords => [
            $x,
            $y, 
            $x+($font->width * length($mag_plus_str)),
            $y+$font->height],
        url  => '#',
        alt  => 'Magnification',
        code => $code,
      };
        $bounds->[2]=$x+($font->width * length($mag_plus_str))
            if ($bounds->[2]<$x+($font->width * length($mag_plus_str)));
    $y += $font->height + $buf;

    ###Start and stop
    my ($start,$stop)
        = $drawer->data_module->getDisplayedStartStop($slot_no,$map_id);
    my $start_str = commify($start)."-".commify($stop)." ".$map_units;
    $x    = $x_mid -
      ( ( $font->width * length($start_str) ) / 2 );
    push @$drawing_data, [ STRING, $font, $x, $y, $start_str, 'grey' ];
    $y += $font->height + $buf;
    $bounds->[0]=$x
        if ($bounds->[0]>$x);
    $bounds->[2]=$x+($font->width * length($start_str))
        if ($bounds->[2]<$x+($font->width * length($start_str)));
    $bounds->[3]=$y
        if ($bounds->[3]<$y);
    ###Map Length
#    my $map_length =$self->map_length($map_id);
#    my $size_str    = presentable_number($map_length,3).$map_units;
#    $x    = $x_mid -
#      ( ( $font->width * length($size_str) ) / 2 );
#    push @$drawing_data, [ STRING, $font, $x, $y, $size_str, 'grey' ];
    $y2 = $font->height +$y+$buf;
}

# ----------------------------------------------------
sub draw_truncation_arrows {
                                                                                                                             
=pod
                                                                                                                             
=head2 draw_map_title
                                                                                                                             
Draws the map title.
                                                                                                                             
=cut
                                                                                                                             
    my $self       = shift;
    my %args          = @_;
    my $is_up         = $args{'is_up'};
    my $map_coords    = $args{'map_coords'};
    my $coords        = $args{'coords'};
    my $drawer        = $args{'drawer'};
    my $map_area_data = $args{'map_area_data'};
    my $drawing_data  = $args{'drawing_data'};
    my $is_flipped    = $args{'is_flipped'};
    my $map_id        = $args{'map_id'};
    my $map_aid       = $args{'map_aid'};
    my $slot_no       = $args{'slot_no'};

    my $trunc_color      ='grey';
    my $trunc_half_width = 6; 
    my $trunc_height     = 8;
    my $trunc_line_width = 4;
    my $trunc_buf        = 2;
    my $x_mid            = $map_coords->[0] + ( ( $map_coords->[2] - $map_coords->[0] ) / 2 );

    if ($is_up){
        # Move rest of map down.
        $map_coords->[1]+= $trunc_height+$trunc_buf;
        $map_coords->[3]+= $trunc_height+$trunc_buf;
        $coords->[3]+= $trunc_height+$trunc_buf;
        # Down Arrow signifying that this has been truncated. 
        my $y_base     = $map_coords->[1]-$trunc_buf;
        push @$drawing_data, 
            [ LINE, $x_mid-$trunc_half_width,  $y_base, 
                $x_mid-($trunc_half_width-$trunc_line_width),  $y_base, $trunc_color ];
        push @$drawing_data, 
            [ LINE, $x_mid-$trunc_half_width,  $y_base, 
                $x_mid,  $y_base-$trunc_height, $trunc_color ];
        push @$drawing_data, 
            [ LINE, $x_mid,  $y_base-$trunc_height, 
                $x_mid+$trunc_half_width,  $y_base, $trunc_color ];
        push @$drawing_data, 
            [ LINE, $x_mid+$trunc_half_width,  $y_base, 
                $x_mid+($trunc_half_width-$trunc_line_width),  $y_base, $trunc_color ];
        push @$drawing_data, 
            [ LINE, $x_mid+($trunc_half_width-$trunc_line_width),  
                $y_base, $x_mid,  $y_base-($trunc_height-$trunc_line_width), $trunc_color ];
        push @$drawing_data, 
            [ LINE, $x_mid-($trunc_half_width-$trunc_line_width),  
                $y_base, $x_mid,  $y_base-($trunc_height-$trunc_line_width), $trunc_color ];
        push @$drawing_data, 
            [ FILL, $x_mid, $y_base-$trunc_height+1, $trunc_color ];

        # Create the link
        my ($scroll_start,$scroll_stop,$scroll_mag)
            = $drawer->data_module->scroll_data($slot_no,$map_id,$is_flipped,'UP');
        my $code=qq[ 
            onMouseOver="window.status='Scroll up';return true" 
            onClick="mod_map_info($slot_no, '$map_aid', $scroll_start,$scroll_stop,$scroll_mag);
            document.comparative_map_form.submit();"
            ]; 
        push @$map_area_data,
          {
            coords => [$x_mid-$trunc_half_width,$y_base-$trunc_height,
                $x_mid+$trunc_half_width,$y_base],
            url  => '#',
            alt  => 'Scroll',
            code => $code,
          };
    }
    else{
        # Down Arrow signifying that this has been truncated. 
        my $y_base     = $map_coords->[3]+$trunc_buf;
        push @$drawing_data, 
            [ LINE, $x_mid-$trunc_half_width,  $y_base, 
                $x_mid-($trunc_half_width-$trunc_line_width),  $y_base, $trunc_color ];
        push @$drawing_data, 
            [ LINE, $x_mid-$trunc_half_width,  $y_base, 
                $x_mid,  $y_base+$trunc_height, $trunc_color ];
        push @$drawing_data, 
            [ LINE, $x_mid,  $y_base+$trunc_height, 
                $x_mid+$trunc_half_width,  $y_base, $trunc_color ];
        push @$drawing_data, 
            [ LINE, $x_mid+$trunc_half_width,  $y_base, 
                $x_mid+($trunc_half_width-$trunc_line_width),  $y_base, $trunc_color ];
        push @$drawing_data, 
            [ LINE, $x_mid+($trunc_half_width-$trunc_line_width),  
                $y_base, $x_mid,  $y_base+($trunc_height-$trunc_line_width), $trunc_color ];
        push @$drawing_data, 
            [ LINE, $x_mid-($trunc_half_width-$trunc_line_width),  
                $y_base, $x_mid,  $y_base+($trunc_height-$trunc_line_width), $trunc_color ];
        push @$drawing_data, 
            [ FILL, $x_mid, $y_base+$trunc_height-1, $trunc_color ];

        # Create the link
        my ($scroll_start,$scroll_stop,$scroll_mag)
            = $drawer->data_module->scroll_data($slot_no,$map_id,$is_flipped,'DOWN');
        my $code=qq[ 
            onMouseOver="window.status='Scroll down';return true" 
            onClick="mod_map_info($slot_no, '$map_aid', $scroll_start,$scroll_stop,$scroll_mag);
            document.comparative_map_form.submit();"
            ]; 
        push @$map_area_data,
          {
            coords => [$x_mid-$trunc_half_width,$y_base,
                $x_mid+$trunc_half_width,$y_base+$trunc_height],
            url  => '#',
            alt  => 'Scroll',
            code => $code,
          };
    }
}

# ----------------------------------------------------
sub draw_map_title {

=pod

=head2 draw_map_title

Draws the map title.

=cut

    my $self    = shift;
    my %args    = @_;
    my $min_y   = $args{'min_y'} || 0;
    my $left_x  = $args{'left_x'} || 0;
    my $right_x = $args{'right_x'} || 0;
    my $lines   = $args{'lines'} || [];
    my $buttons = $args{'buttons'} || [];
    my $font    = $args{'font'};
    my $buffer  = 4;
    my $mid_x   = $left_x + ( ( $right_x - $left_x ) / 2 );
    my $top_y   =
      $min_y - ( scalar @$lines + 1 ) * ( $font->height + $buffer ) - 4;
    my $leftmost  = $mid_x;
    my $rightmost = $mid_x;

    #
    # Place the titles.
    #
    my ( @drawing_data, @map_area_data );
    my $y = $top_y;
    for my $label (@$lines) {
        my $len     = $font->width * length($label);
        my $label_x = $mid_x - $len / 2;
        my $end     = $label_x + $len;

        push @drawing_data, [ STRING, $font, $label_x, $y, $label, 'black' ];

        $y += $font->height + $buffer;
        $leftmost  = $label_x if $label_x < $leftmost;
        $rightmost = $end     if $end > $rightmost;
    }

    #
    # Figure out how much room left-to-right the buttons will take.
    #
    my $buttons_width;
    for my $button (@$buttons) {
        $buttons_width += $font->width * length( $button->{'label'} );
    }
    $buttons_width += 6 * ( scalar @$buttons - 1 );

    #
    # Place the buttons.
    #
    my $label_x = $mid_x - $buttons_width / 2;
    my $sep_x   = $label_x;
    my $sep_y   = $y;
    $y += 6;

    for my $button (@$buttons) {
        my $len  = $font->width * length( $button->{'label'} );
        my $end  = $label_x + $len;
        my @area = ( $label_x - 2, $y - 2, $end + 2, $y + $font->height + 2 );
        push @drawing_data,
          [ STRING, $font, $label_x, $y, $button->{'label'}, 'grey' ],
          [ RECTANGLE, @area, 'grey' ],;

        $leftmost  = $label_x if $label_x < $leftmost;
        $rightmost = $end     if $end > $rightmost;
        $label_x += $len + 6;

        push @map_area_data,
          {
            coords => \@area,
            url    => $button->{'url'},
            alt    => $button->{'alt'},
          };
    }

    push @drawing_data, [ LINE, $sep_x, $sep_y, $label_x - 6, $sep_y, 'grey' ];

    #
    # Enclose the whole area in black-edged white box.
    #
    my @bounds = (
        $leftmost - $buffer,
        $top_y - $buffer,
        $rightmost + $buffer,
        $min_y + $buffer,
    );

    push @drawing_data, [
        FILLED_RECT, @bounds, 'white', 0    # bottom-most layer
    ];

    push @drawing_data, [ RECTANGLE, @bounds, 'black' ];

    return ( \@bounds, \@drawing_data, \@map_area_data );
}

# ----------------------------------------------------
sub features {

=pod

=head2 features

Returns all the features on the map.  Features are stored in raw format as 
a hashref keyed on feature_id.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);

    unless ( defined $map->{'feature_store'} ) {
        for my $data (
            map  { $_->[0] }
            sort {
                     $a->[1] <=> $b->[1]
                  || $a->[2] <=> $b->[2]
                  || $a->[3] <=> $b->[3]
                  || $a->[4] <=> $b->[4]
            }
            map {
                [
                    $_,
                    $_->{'drawing_lane'},
                    $_->{'drawing_priority'},
                    defined $_->{'start_position'} ? $_->{'start_position'} : 0,
                    defined $_->{'stop_position'}  ? $_->{'stop_position'}  : 0,
                ]
            } values %{ $map->{'features'} }
          )
        {

            push @{ $map->{'feature_store'}{ $data->{'drawing_lane'} } }, $data;
        }
    }

    return $map->{'feature_store'};
}

# ----------------------------------------------------
sub no_features {

=pod

=head2 no_features

Returns the number features on the map.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    return $map->{'no_features'};
}

# ----------------------------------------------------
sub shape {

=pod

=head2 shape

Returns a string describing how to draw the map.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    my $shape  = $map->{'shape'} || $map->{'default_shape'} || '';
    $shape = 'default' unless defined $SHAPE{$shape};
    return $shape;
}

# ----------------------------------------------------
sub layout {

=pod

=head2 layout

Lays out the map.

Variable Info:
    $map_drawing_data{$map_id} holds the un-offset drawing data for each map;
    $map_area_data{$map_id} holds the un-offset area data for each map;
    $map_placement_data{$map_id} holds the boundary and map_coords for each map.
        {'bounds'} holds the boundary data for the whole thing, labels, toppers,
                   footers, everything that needs to avoid collision.
        {'map_coords'} holds the coords of just the map (ie the box/dumbell/I-beam)
    $features_with_corr_by_map_id{$map_id};
    

=cut

    #p#rint S#TDERR "layout()\n";
    my $self         = shift;
    my $base_y       = $self->base_y;
    my $slot_no      = $self->slot_no;
    my $drawer       = $self->drawer;
    my $label_side   = $drawer->label_side($slot_no);
    my $reg_font     = $drawer->regular_font
      or return $self->error( $drawer->error );
    my $slots       = $drawer->slots;
    my @map_ids     = $self->map_ids;
    my $font_width  = $reg_font->width;
    my $font_height = $reg_font->height;
    my $no_of_maps  = scalar @map_ids;

    # if more than one map in slot, compress all
    my $is_compressed  = $drawer->data_module->compress_maps($slot_no);
    my $label_features = $drawer->label_features;
    my $config         = $self->config or return;

    #
    # The title is often the widest thing we'll draw, so we need
    # to figure out which is the longest and take half its length
    # into account when deciding where to start with the map(s).
    #
    my @config_map_titles = $config->get_config('map_titles');
    my $longest;
    for my $map_id (@map_ids) {
        for my $length ( map { length $self->$_($map_id) } @config_map_titles )
        {
            $length ||= 0;
            $longest = $length if $length > $longest;
        }
    }
    my $half_title_length = ( $font_width * $longest ) / 2 + 10;
    my $original_base_x   =
        $label_side eq RIGHT
      ? $self->base_x + $half_title_length
      : $self->base_x - $half_title_length;

    #
    # These are for drawing the map titles last if this is a relational map.
    #
    my (
        $top_y,  
        $bottom_y,
        $slot_min_y,           # northernmost coord for the slot
        $slot_max_y,           # southernmost coord for the slot
        $slot_min_x,           # easternmost coord for the slot
        $slot_max_x,           # westernmost coord for the slot
        @map_titles,           # the titles to put above - for relational maps
        $map_set_aid,          # the map set acc. ID - for relational maps
        %feature_type_aids,    # the distinct feature type IDs
    );

    #
    # Some common things we'll need later on.
    #
    my $connecting_line_color  = $drawer->config_data('connecting_line_color');
    my $apr                    = $drawer->apr;
    my $url                    = $apr->url;
    my $map_viewer_url         = $url . '/viewer';
    my $map_details_url        = $url . '/map_details';
    my $map_set_info_url       = $url . '/map_set_info';
    my $rel_map_show_corr_only =
      $drawer->config_data('relational_maps_show_only_correspondences') || 0;
    my $feature_highlight_fg_color =
      $drawer->config_data('feature_highlight_fg_color');
    my $feature_highlight_bg_color =
      $drawer->config_data('feature_highlight_bg_color');

    my $self_url =
      $drawer->map_view eq 'details' ? $map_details_url : $map_viewer_url;

    my @ordered_slot_nos = sort { $a <=> $b } grep { $_ != 0 } keys %$slots;

    my ( @map_buttons, $last_map_x );
    my $last_map_y  = $base_y;
    my $show_labels =
        $is_compressed ? 0
      : $label_features eq 'none' ? 0
      : 1;
    my $show_ticks     = 1;#Always show ticks 
    my $show_map_title = $is_compressed ? 0 : 1;
    my $show_map_units = $is_compressed ? 0 : 1;

    my $base_x =
        $slot_no == 0 ? $self->base_x
      : $slot_no > 0  ? $self->base_x + $half_title_length + 10
      : $self->base_x - $half_title_length - 20;

    my @map_columns = ();
    # Variable info:
    #
    my %map_drawing_data;
    my %map_area_data;
    my %map_placement_data;
    my %map_aggregate_corr;
    my %features_with_corr_by_map_id;
  MAP:
    for my $map_id (@map_ids) {
        my $map_width    = $self->map_width($map_id);
        my $is_flipped   = 0;
        my $max_x;

        my $actual_map_length = $self->map_length($map_id);
        my $map_length        = $actual_map_length || 1;

        #
        # Find out if it flipped
        #
        unless ($is_compressed) {
            for my $rec ( @{ $drawer->flip } ) {
                if (   $rec->{'slot_no'} == $slot_no
                    && $rec->{'map_aid'} == $self->accession_id($map_id) )
                {
                    $is_flipped = 1;
                    last;
                }
            }
        }

        my $features = $self->features($map_id);

        #
        # Reset map buttons.
        #
        @map_buttons = (
            {
                url => $map_set_info_url
                  . '?map_set_aid='
                  . $self->map_set_aid($map_id)
                  . ';data_source='
                  . $drawer->data_source,
                alt   => 'Map Set Info',
                label => 'i',
            }
        );

        #
        # The map.
        #

        # Get the desired map height.
        my $pixel_height=$self->get_map_height(
            drawer          => $drawer,
            slot_no         => $slot_no,
            map_id          => $map_id,
            is_compressed   => $is_compressed,
            );
        # Place the map vertically in the slot
        my ($placed_y1,$placed_y2,$capped);
        ($placed_y1,$placed_y2, $pixel_height,$capped) 
            = $self->place_map_y(
                drawer          => $drawer,
                slot_no         => $slot_no,
                map_id          => $map_id,
                is_compressed   => $is_compressed,
                pixel_height    => $pixel_height,
                map_aggregate_corr  => \%map_aggregate_corr,
                );
        $map_placement_data{$map_id}{'bounds'}=[0,$placed_y1,0,$placed_y2];
        $map_placement_data{$map_id}{'map_coords'}=[0,$placed_y1,0,$placed_y2];
        # Add the topper
        $self->add_topper(
            drawer             => $drawer,
            slot_no            => $slot_no,
            map_id             => $map_id,
            is_compressed      => $is_compressed,
            map_drawing_data   => \%map_drawing_data,
            map_area_data      => \%map_area_data,
            map_placement_data => \%map_placement_data,
            );
             
        # Draw the actual Map
        my $mid_x = 0; 
        my $draw_sub_name = $SHAPE{ $self->shape($map_id) };
        my ($bounds,$new_map_coords) = $self->$draw_sub_name(
            map_id       => $map_id,
            slot_no      => $slot_no,
            map_units    => $self->map_units($map_id), 
            drawer       => $drawer,
            is_flipped   => $is_flipped,
            coords       => [ $mid_x, 
                              $map_placement_data{$map_id}{'map_coords'}[1], 
                              $map_placement_data{$map_id}{'map_coords'}[3], 
                            ],
            drawing_data => $map_drawing_data{$map_id},
            map_area_data => $map_area_data{$map_id},
        );
        $map_placement_data{$map_id}{'map_coords'}[0]=$new_map_coords->[0]
            if ($map_placement_data{$map_id}{'map_coords'}[0]>$new_map_coords->[0]);
        $map_placement_data{$map_id}{'map_coords'}[1]=$new_map_coords->[1]
            if ($map_placement_data{$map_id}{'map_coords'}[1]>$new_map_coords->[1]);
        $map_placement_data{$map_id}{'map_coords'}[2]=$new_map_coords->[2]
            if ($map_placement_data{$map_id}{'map_coords'}[2]<$new_map_coords->[2]);
        $map_placement_data{$map_id}{'map_coords'}[3]=$new_map_coords->[3]
            if ($map_placement_data{$map_id}{'map_coords'}[3]<$new_map_coords->[3]);
        $map_placement_data{$map_id}{'bounds'}[0]=$bounds->[0]
            if ($map_placement_data{$map_id}{'bounds'}[0]>$bounds->[0]);
        $map_placement_data{$map_id}{'bounds'}[1]=$bounds->[1]
            if ($map_placement_data{$map_id}{'bounds'}[1]>$bounds->[1]);
        $map_placement_data{$map_id}{'bounds'}[2]=$bounds->[2]
            if ($map_placement_data{$map_id}{'bounds'}[2]<$bounds->[2]);
        $map_placement_data{$map_id}{'bounds'}[3]=$bounds->[3]
            if ($map_placement_data{$map_id}{'bounds'}[3]<$bounds->[3]);

        # Add an asterisk if the map was capped
        $self->add_capped_mark(
            drawer             => $drawer,
            map_id             => $map_id,
            drawing_data       => $map_drawing_data{$map_id},
            map_area_data      => $map_area_data{$map_id},
            capped             => $capped,
            map_placement_data => \%map_placement_data,
            );

        my $new_map_name = $self->map_name($map_id);
        if ( $drawer->highlight_feature($new_map_name) ) {
            push @{$map_drawing_data{$map_id}},
              [ RECTANGLE, @{$map_placement_data{$map_id}{'map_coords'}},
                $feature_highlight_fg_color ];

            push @{$map_drawing_data{$map_id}},
              [ FILLED_RECT, @{$map_placement_data{$map_id}{'map_coords'}}, 
                $feature_highlight_bg_color, 0 ];
        }

        # Tick marks.
        if ($show_ticks) {
            $self->new_add_tick_marks(
                map_coords        => $map_placement_data{$map_id}{'map_coords'},
                bounds            => $map_placement_data{$map_id}{'bounds'},
                drawer            => $drawer,
                map_id            => $map_id,
                slot_no           => $slot_no,
                drawing_data      => $map_drawing_data{$map_id},
                map_area_data     => $map_area_data{$map_id},
                pixel_height      => $pixel_height,
                is_flipped        => $is_flipped,
                actual_map_length => $actual_map_length,
                map_length        => $map_length,
            );
        }

        #
        # Features.
        #
        my $min_y = $map_placement_data{$map_id}{'map_coords'}[1]; # remembers the northermost position
        my %lanes;                  # associate priority with a lane
        my %features_with_corr;     # features w/correspondences
        my ( $leftmostf, $rightmostf );    # furthest features

        my $new_base_x = $map_placement_data{$map_id}{'map_coords'}[0];
        
        for my $lane ( sort { $a <=> $b } keys %$features ) {
            my %even_labels;               # holds label coordinates
              #my ( @north_labels, @south_labels );    # holds label coordinates
            my $lane_features = $features->{$lane};
            my $midpoint      =
              ( $lane_features->[0]->{'start_position'} +
                  $lane_features->[-1]->{'start_position'} ) / 2;
            my $prev_label_y;    # the y value of previous label
            my @fcolumns = ();   # for feature east-to-west

            #
            # Use the "drawing_lane" to determine where to draw the feature.
            #
            unless ( exists $lanes{$lane} ) {
                $lanes{$lane} = {
                    order    => ( scalar keys %lanes ) + 1,
                    furthest => $label_side eq RIGHT ? $rightmostf : $leftmostf,
                };

                my $lane = $lanes{$lane};
                $new_base_x =
                    $lane->{'furthest'}
                  ? $label_side eq RIGHT
                  ? $lane->{'furthest'} + 2
                  : $lane->{'furthest'} - ( $map_width + 4 )
                  : $new_base_x;
            }
            my %drawn_glyphs;
            for my $feature (@$lane_features) {
                ########################################
                my $coords;
                my $color;
                my $label_y;

                ( $leftmostf, $rightmostf, $coords, $color, $label_y ) =
                  $self->add_feature_to_map(
                    base_x            => $new_base_x,
                    map_base_y        => $map_placement_data{$map_id}{'map_coords'}[1],
                    drawer            => $drawer,
                    feature           => $feature,
                    map_id            => $map_id,
                    slot_no           => $slot_no,
                    drawing_data      => $map_drawing_data{$map_id},
                    map_area_data     => $map_area_data{$map_id},
                    fcolumns          => \@fcolumns,
                    pixel_height      => $pixel_height,
                    is_flipped        => $is_flipped,
                    map_length        => $map_length,
                    leftmostf         => $leftmostf,
                    rightmostf        => $rightmostf,
                    drawn_glyphs      => \%drawn_glyphs,
                    feature_type_aids => \%feature_type_aids,
                  );
                $self->collect_labels_to_display(
                    even_labels        => \%even_labels,
                    map_id             => $map_id,
                    slot_no            => $slot_no,
                    is_flipped         => $is_flipped,
                    show_labels        => $show_labels,
                    drawer             => $drawer,
                    feature            => $feature,
                    coords             => $coords,
                    color              => $color,
                    midpoint           => $midpoint,
                    label_y            => $label_y,
                    feature_type_aids  => \%feature_type_aids,
                    features_with_corr => \%features_with_corr,
                    map_base_y         => $map_placement_data{$map_id}{'map_coords'}[1],
                );
                ########################################
            }

            #
            # We have to wait until all the features for the lane are
            # drawn before placing the labels.
            ##############################################
            my $min_x=0;
            (
                $new_base_x, $leftmostf, $rightmostf, $max_x, $min_x, $top_y,
                $bottom_y, $min_y
              )
              = $self->add_labels_to_map(
                base_x             => $new_base_x,
                base_y             => $map_placement_data{$map_id}{'map_coords'}[1],
                even_labels        => \%even_labels,
                drawer             => $drawer,
                rightmostf         => $rightmostf,
                leftmostf          => $leftmostf,
                map_id             => $map_id,
                slot_no            => $slot_no,
                drawing_data       => $map_drawing_data{$map_id},
                map_area_data      => $map_area_data{$map_id},
                features_with_corr => \%features_with_corr,
                min_x              => $map_placement_data{$map_id}{'bounds'}[0],
                top_y              => $map_placement_data{$map_id}{'bounds'}[1],
                max_x              => $map_placement_data{$map_id}{'bounds'}[2],
                bottom_y           => $map_placement_data{$map_id}{'bounds'}[3],
                min_y              => $map_placement_data{$map_id}{'bounds'}[1],
                pixel_height       => $pixel_height,
              );
            $map_placement_data{$map_id}{'bounds'}[0]=$min_x
                if ($map_placement_data{$map_id}{'bounds'}[0]>$min_x);
            $map_placement_data{$map_id}{'bounds'}[1]=$top_y
                if ($map_placement_data{$map_id}{'bounds'}[1]>$top_y);
            $map_placement_data{$map_id}{'bounds'}[1]=$min_y
                if ($map_placement_data{$map_id}{'bounds'}[1]>$min_y);
            $map_placement_data{$map_id}{'bounds'}[2]=$max_x
                if ($map_placement_data{$map_id}{'bounds'}[2]<$max_x);
            $map_placement_data{$map_id}{'bounds'}[3]=$bottom_y
                if ($map_placement_data{$map_id}{'bounds'}[3]<$bottom_y);

            ##############################################
            $lanes{$lane}{'furthest'} =
              $label_side eq RIGHT ? $rightmostf : $leftmostf;
            $map_placement_data{$map_id}{'bounds'}[0]=$leftmostf
                if ($map_placement_data{$map_id}{'bounds'}[0]>$leftmostf);
            $map_placement_data{$map_id}{'bounds'}[2]=$rightmostf
                if ($map_placement_data{$map_id}{'bounds'}[2]<$rightmostf);
        }

        $features_with_corr_by_map_id{$map_id}=\%features_with_corr;

        my ( $min_x);

        #
        # Buttons
        #
        
        my $ref_map   = $slots->{0} or next;
        my ($ref_map_link,@rmap_links);
        my $ref_map_aids_hash=$ref_map->{'maps'};
        my $ref_map_set_aids_hash=$ref_map->{'map_sets'};
        for my $field (qw[ maps map_sets ]) {
            my @aid_info;
            next unless (defined($ref_map->{$field})); 
            foreach my $aid (keys %{$ref_map->{$field}}){
                push @aid_info, $aid.'['.$ref_map->{$field}{$aid}{'start'}.'*'
                    .$ref_map->{$field}{$aid}{'stop'}.'x'
                    .$ref_map->{$field}{$aid}{'mag'}
                    .']';
            }
            if ($field eq 'maps'){
                $ref_map_link = 'ref_map_aids='.
                    join(';ref_map_aids=',@aid_info).
                    ';';
            }
            else{
                $ref_map_link = 'ref_map_set_aids='.
                    join(';ref_map_set_aids=',@aid_info).
                    ';';
            }

            if(@aid_info){
                push @rmap_links, $ref_map_link;
            }
        }

        my @flips;
        my @flipping_flips;
        my $acc_id = $self->accession_id($map_id);
        for my $rec ( @{ $drawer->flip } ) {
            push @flips, $rec->{'slot_no'} . '%3d' . $rec->{'map_aid'};
            unless (   
                $rec->{'slot_no'} == $slot_no
                && 
                $rec->{'map_aid'} == $acc_id )
            {
                push @flipping_flips,   
                    $rec->{'slot_no'} . '%3d' . $rec->{'map_aid'};
            }
        }
        push @flipping_flips, "$slot_no%3d$acc_id" unless $is_flipped;
        my $flip_str=join(":",@flips);
        my $flipping_flip_str=join(":",@flipping_flips);

        my $feature_type_selection='';
        $feature_type_selection.='feature_type_'.$_.'=2;' 
            foreach (@{$drawer->include_feature_types});
        $feature_type_selection.='feature_type_'.$_.'=1;' 
            foreach (@{$drawer->corr_only_feature_types});
        #
        # Map details button.
        #
        my $slots = $drawer->slots;
        my @maps;
        for my $side (qw[ left right ]) {
            my $no     = $side eq 'left' ? $slot_no - 1 : $slot_no + 1;
            my $new_no = $side eq 'left' ? -1           : 1;
            my $map   = $slots->{$no} or next;
            my $link;
            for my $field (qw[ maps map_sets ]) {
                my @aid_info;
                next unless (defined($map->{$field})); 
                foreach my $aid (keys %{$map->{$field}}){
                    push @aid_info, $aid.'['.$map->{$field}{$aid}{'start'}.'*'
                        .$map->{$field}{$aid}{'stop'}.'x'
                        .$map->{$field}{$aid}{'mag'}
                        .']';
                }
                my $field_type='map_set_aid';
                if ($field eq 'maps'){
                    $field_type='map_aid';
                }
                my $link = join( '%3d', $new_no, $field_type, join(',',@aid_info) );
                push @maps, $link;
            }
        }

        my $details_url =
            $map_details_url
          . '?ref_map_set_aid='
          . $self->map_set_aid($map_id)
          . ';ref_map_aids='
          . $self->accession_id($map_id)
          . ';comparative_maps='
          . join( ':', @maps )
          . ';label_features='
          . $drawer->label_features
          . ';' . $feature_type_selection
          . 'include_evidence_types='
          . join( ',', @{ $drawer->include_evidence_types || [] } )
          . ';highlight='
          . uri_escape( $drawer->highlight )
          . ';min_correspondences='
          . $drawer->min_correspondences
          . ';image_type='
          . $drawer->image_type
          . ';data_source='
          . $drawer->data_source;

        if ($is_compressed) {
            push @map_buttons, {   
                label => 'M',
                url   => 'matrix?&show_matrix=1'.
                    '&link_map_set_aid='.$self->map_set_aid( $map_id ),
                alt   => 'View In Matrix'
            };
        }
        else {
            push @map_buttons,
              {
                label => '?',
                url   => $details_url,
                alt   => 'Map Details',
            },   
            {   
                label => 'M',
                url   => 'matrix?map_type_aid='.$self->map_type_aid( $map_id ).
                    '&species_aid='.$self->species_aid( $map_id ).
                    '&map_set_aid='.$self->map_set_aid( $map_id ).
                    '&map_name='.$self->map_name( $map_id ).
                    '&show_matrix=1',
                alt   => 'View In Matrix'
              };
        }

        #
        # Delete button.
        #
        if ( $slot_no != 0 ) {
            my @cmap_nos;
            if ( $slot_no < 0 ) {
                push @cmap_nos, grep { $_ > $slot_no } @ordered_slot_nos;
            }
            else {
                push @cmap_nos, grep { $_ < $slot_no } @ordered_slot_nos;
            }
            my %delete_comparative_map_hash;
            foreach my $slot_no (@cmap_nos){
                next if ($slot_no==0);
                $delete_comparative_map_hash{$slot_no}=$slots->{$slot_no};
            }

            my @cmaps;
            for my $slot_no (@cmap_nos) {
                my $map   = $slots->{$slot_no} or next;
                my $link;
                for my $field (qw[ maps map_sets ]) {
                    my @aid_info;
                    next unless (defined($map->{$field})); 
                    foreach my $aid (keys %{$map->{$field}}){
                        push @aid_info, $aid.'['
                            .$map->{$field}{$aid}{'start'}.'*'
                            .$map->{$field}{$aid}{'stop'}.'x'
                            .$map->{$field}{$aid}{'mag'}
                            .']';
                    }
                    my $field_type='map_set_aid';
                    if ($field eq 'maps'){
                        $field_type='map_aid';
                    }
                    my $link = join( '%3d', $slot_no, $field_type, join(',',@aid_info) );
                    push @cmaps, $link;
                }
            }

            my $delete_url=$self->create_viewer_link(
                ref_map_set_aid   => $slots->{'0'}{'map_set_aid'},
                ref_map_aids      => $ref_map_aids_hash,
                ref_map_set_aids  => $ref_map_set_aids_hash,
                comparative_maps  => \%delete_comparative_map_hash,
                label_features    => $drawer->label_features,
                feature_type_aids => $drawer->include_feature_types,
                corr_only_feature_type_aids 
                                  => $drawer->corr_only_feature_types,
                evidence_type_aids  
                                  => $drawer->include_evidence_types,
                highlight         => uri_escape( $drawer->highlight ),
                min_correspondences => $drawer->min_correspondences,
                image_type        => $drawer->image_type,
                flip              => $flip_str,
                data_source       => $drawer->data_source,
                );

            push @map_buttons,
              {
                label => 'X',
                url   => $delete_url,
                alt   => 'Delete Map',
              };
        }

        #
        # Flip button.
        #
        unless ($is_compressed) {
            my %flip_comparative_map_hash;
            foreach my $slot_no (keys(%$slots)){
                next if ($slot_no==0);
                $flip_comparative_map_hash{$slot_no}=$slots->{$slot_no};
            }

            my $flip_url=$self->create_viewer_link(
                ref_map_set_aid   => $slots->{'0'}{'map_set_aid'},
                ref_map_aids      => $ref_map_aids_hash,
                ref_map_set_aids  => $ref_map_set_aids_hash,
                comparative_maps  => \%flip_comparative_map_hash,
                label_features    => $drawer->label_features,
                feature_type_aids => $drawer->include_feature_types,
                corr_only_feature_type_aids 
                                  => $drawer->corr_only_feature_types,
                evidence_type_aids  
                                  => $drawer->include_evidence_types,
                highlight         => uri_escape( $drawer->highlight ),
                min_correspondences => $drawer->min_correspondences,
                image_type        => $drawer->image_type,
                flip              => $flipping_flip_str,
                data_source       => $drawer->data_source,
                );

            push @map_buttons,
              {
                label => 'F',
                url   => $flip_url,
                alt   => 'Flip Map',
              };
        }

        #
        # New View button.
        #
        unless ($is_compressed) {
            my $new_url =
                $map_viewer_url
              . '?ref_map_set_aid='
              . $self->map_set_aid($map_id)
              . ';ref_map_aids='
              . $self->accession_id($map_id)
              . ';ref_map_start='
              . $self->start_position($map_id)
              . ';ref_map_stop='
              . $self->stop_position($map_id)
              . ';label_features='
              . $drawer->label_features
              . ';' . $feature_type_selection
              . ';include_evidence_types='
              . join( ',', @{ $drawer->include_evidence_types || [] } )
              . ';highlight='
              . uri_escape( $drawer->highlight )
              . ';image_type='
              . $drawer->image_type
              . ';data_source='
              . $drawer->data_source;

            push @map_buttons,
              {
                label => 'N',
                url   => $new_url,
                alt   => 'New Map View',
              };
        }

        #
        # The map title(s).
        #
        if ($is_compressed) {    
            unless (@map_titles) {
                push @map_titles, map { $self->$_($map_id) }
                  grep { !/map_name/ }
                  reverse @config_map_titles;
            }
            $map_set_aid = $self->map_set_aid($map_id);
        }
        else {
            my @lines = map { $self->$_($map_id) } @config_map_titles;
            my ( $bounds, $drawing_data, $map_data ) = $self->draw_map_title(
                left_x  => $min_x,
                right_x => $max_x,
                min_y   => $min_y - $font_height - 8,
                lines   => \@lines,
                buttons => \@map_buttons,
                font    => $reg_font,
            );

            $min_x = $bounds->[0] unless defined $min_x;
            $min_x = $bounds->[0] if $bounds->[0] < $min_x;
            $top_y = $bounds->[1] if $bounds->[1] < $top_y;
            $max_x = $bounds->[2] if $bounds->[2] > $max_x;
            $map_placement_data{$map_id}{'bounds'}[0]=$min_x
                if ($map_placement_data{$map_id}{'bounds'}[0]>$min_x);
            $map_placement_data{$map_id}{'bounds'}[1]=$top_y
                if ($map_placement_data{$map_id}{'bounds'}[1]>$top_y);
            $map_placement_data{$map_id}{'bounds'}[2]=$max_x
                if ($map_placement_data{$map_id}{'bounds'}[2]<$max_x);

            push @{$map_drawing_data{$map_id}},  @$drawing_data;
            push @{$map_area_data{$map_id}}, @$map_data;
        }
        $slot_min_y = $map_placement_data{$map_id}{'bounds'}[1]
            if (not defined $slot_max_y
                or $map_placement_data{$map_id}{'bounds'}[1]<$slot_min_y);
        $slot_max_y = $map_placement_data{$map_id}{'bounds'}[3]
            if (not defined $slot_max_y
                or $map_placement_data{$map_id}{'bounds'}[3]>$slot_max_y);
    }

###NEW STUFF######
    # place each map in a lane and find the width of each lane
    my %map_lane;
    my @lane_width;
    my @map_colunms;
    my $y_buffer = 4;
    my $lane_buffer = 4;
    for my $map_id (sort {$map_placement_data{$a}{'bounds'}[1]<=>$map_placement_data{$b}{'bounds'}[1]} @map_ids) {
        if (@map_columns) {
            for my $i ( 0 .. $#map_columns ) {
                if ( $map_columns[$i] < $map_placement_data{$map_id}{'bounds'}[1] ) {
                    $map_lane{$map_id} = $i;
                    last;
                }
            }
        }
        else {
            $map_lane{$map_id} = 0;
        }
        $map_lane{$map_id} = scalar @map_columns
          unless defined $map_lane{$map_id};
        $map_columns[$map_lane{$map_id}] = $map_placement_data{$map_id}{'bounds'}[3] + $y_buffer;
        
        $lane_width[$map_lane{$map_id}]=$map_placement_data{$map_id}{'bounds'}[2]
                - $map_placement_data{$map_id}{'bounds'}[0]
            if ($lane_width[$map_lane{$map_id}]<$map_placement_data{$map_id}{'bounds'}[2]
                    -$map_placement_data{$map_id}{'bounds'}[0]);
    }
    my @lane_base_x;
    $lane_base_x[0]=$base_x;
    if ($slot_no >= 0){
        # maps are placed from left to right
        for my $i (1..$#map_columns){
            $lane_base_x[$i]=$lane_base_x[$i-1]+$lane_width[$i-1]+$lane_buffer;
        }
        $slot_min_x = $lane_base_x[0];
        $slot_max_x = $lane_base_x[-1]+$lane_width[-1]+$lane_buffer;
    }
    else{
        # maps are placed from right to left
        for my $i (1..$#map_columns){
            $lane_base_x[$i]=$lane_base_x[$i-1]-$lane_width[$i]-$lane_buffer;
        }
        $slot_max_x = $lane_base_x[0]+$lane_width[0];
        $slot_min_x = $lane_base_x[-1];
    }

    # Offset all of the coords accordingly
    for my $map_id (@map_ids) {
        my $offset=$lane_base_x[$map_lane{$map_id}]-$map_placement_data{$map_id}{'bounds'}[0];
                

        $self->offset_drawing_data(
            drawing_data  => $map_drawing_data{$map_id},
            offset        => $offset,
            );
        $drawer->add_drawing(@{$map_drawing_data{$map_id}});
        for (my $i=0;$i<=$#{$map_area_data{$map_id}};$i++){
            $map_area_data{$map_id}[$i]{'coords'}[0]+=$offset;
            $map_area_data{$map_id}[$i]{'coords'}[2]+=$offset;
        }
        $drawer->add_map_area(@{$map_area_data{$map_id}});
        for my $key (keys(%{$features_with_corr_by_map_id{$map_id}})){
            $features_with_corr_by_map_id{$map_id}{$key}{'left'}[0]  += $offset;
            $features_with_corr_by_map_id{$map_id}{$key}{'right'}[0] += $offset;
        }
        # Register all the features that have correspondences.
        $drawer->register_feature_position(%$_) for values %{$features_with_corr_by_map_id{$map_id}};
    
        $map_placement_data{$map_id}{'map_coords'}[0]+=$offset;
        $map_placement_data{$map_id}{'map_coords'}[2]+=$offset;
        $map_placement_data{$map_id}{'bounds'}[0]+=$offset;
        $map_placement_data{$map_id}{'bounds'}[2]+=$offset;


        my $new_map_start         = $self->start_position($map_id);
        my $new_map_stop          = $self->stop_position($map_id);

        $drawer->register_map_coords(
            $slot_no,  $map_id,  $new_map_start, $new_map_stop,
            @{$map_placement_data{$map_id}{'map_coords'}}, 
        );

    }
#xxx
    #Make aggregated correspondences
    for my $map_id (@map_ids){
        if ($self->aggregate){
            my @drawing_data=();
            my $map_length=$self->map_length($map_id);
            for my $ref_connect (@{$map_aggregate_corr{$map_id}}) {
                my $map_coords = $map_placement_data{$map_id}{'map_coords'};
                my $line_color =
                    $ref_connect->[2] <= 1  ? 'lightgrey'
                  : $ref_connect->[2] <= 5  ? 'lightblue'
                  : $ref_connect->[2] <= 25 ? 'blue'
                  : $ref_connect->[2] <= 50 ? 'purple'
                  : $ref_connect->[2] <= 200 ? 'red'
                  : 'black';
                my $this_map_x=$label_side eq RIGHT ? $map_coords->[0]-4 : $map_coords->[2]+4;
                my $this_map_x2=$label_side eq RIGHT ? $map_coords->[0] : $map_coords->[2];
                my $this_map_y=(($ref_connect->[3]/$map_length)
                                * ($map_coords->[3]-$map_coords->[1]))+$map_coords->[1];
                push @drawing_data,
                  [
                    LINE,
                    $ref_connect->[0],
                    $ref_connect->[1], 
                    $this_map_x, 
                    $this_map_y, 
                    $line_color,       0
                  ];
                push @drawing_data,
                  [
                    LINE,
                    $this_map_x,
                    $this_map_y-1, 
                    $this_map_x,
                    $this_map_y+1, 
                    'black',       0
                  ];
                push @drawing_data,
                  [
                    LINE,
                    $this_map_x,
                    $this_map_y, 
                    $this_map_x2,
                    $this_map_y, 
                    'black',       0
                  ];

            }
            $drawer->add_drawing(@drawing_data);
        }
    }
###END NEW STUFF#########

    #
    # Draw the map titles last for compressed maps,
    # centered over all the maps.
    #
    if ($is_compressed) {
        my $base_x =
            $label_side eq RIGHT
          ? $self->base_x + $half_title_length + 10
          : $self->base_x - $half_title_length - 20;
        $slot_min_x = $base_x unless defined $slot_min_x;
        $slot_max_x = $base_x unless defined $slot_max_x;

        unless (@map_titles) {
            push @map_titles, map { $self->$_( $map_ids[0] ) }
              grep { !/map_name/ } @config_map_titles;
        }

        my ( $bounds, $drawing_data, $map_data ) = $self->draw_map_title(
            left_x  => $slot_min_x,
            right_x => $slot_max_x,
            min_y   => $slot_min_y - 10 - ( $font_height + 8 ),
            lines   => \@map_titles,
            buttons => \@map_buttons,
            font    => $reg_font,
        );

        $slot_min_x = $bounds->[0] if $bounds->[0] < $slot_min_x;
        $top_y      = $bounds->[1] if $bounds->[1] < $top_y;
        $slot_max_x = $bounds->[2] if $bounds->[2] > $slot_max_x;

        $drawer->add_drawing(@$drawing_data);
        $drawer->add_map_area(@$map_data);
    }

    #
    # Register the feature types we saw.
    #
    $drawer->register_feature_type( keys %feature_type_aids );

    #
    # Background color
    #
    my $buffer = 10;
    return [
        $slot_min_x - $buffer,
        $slot_min_y - $buffer,
        $slot_max_x + $buffer,
        $slot_max_y + $buffer,
    ];
}

# ----------------------------------------

=pod

=head2 get_map_height

gets the desired map height after scaling.

=cut

sub get_map_height {

    my ( $self, %args ) = @_;
    my $drawer          = $args{'drawer'};
    my $slot_no         = $args{'slot_no'};
    my $map_id          = $args{'map_id'};
    my $is_compressed   = $args{'is_compressed'};

    my $magnify_all     = $self->magnify_all;

    my $min_map_pixel_height = $drawer->config_data('min_map_pixel_height');
    my $pixel_height = $drawer->pixel_height();
    if ($is_compressed and $slot_no!=0){
        $pixel_height = $min_map_pixel_height;
    }
    
    #
    # Set information used to scale.
    #
    if ($drawer->{'data'}{'ref_unit_size'}{$self->map_units($map_id)}){
        $pixel_height
            = ($self->stop_position($map_id)-$self->start_position($map_id))
            * ($drawer->pixel_height()
              / $drawer->{'data'}{'ref_unit_size'}{$self->map_units($map_id)});
        
    }

    $pixel_height = $min_map_pixel_height 
        if ($pixel_height < $min_map_pixel_height);
    $pixel_height=$pixel_height*$drawer->data_module->magnification($slot_no,$map_id)
        *$magnify_all;

    return $pixel_height;
}


# ----------------------------------------

=pod

=head2 place_map_y

Takes the height, returns the vertical boundaries of the map 
(not counting toppers and footers). 
This will take into account where the correspondences are on the 
reference maps and any capping that needs to be done.

=cut

sub place_map_y {

    my ( $self, %args )    = @_;
    my $drawer             = $args{'drawer'};
    my $slot_no            = $args{'slot_no'};
    my $map_id             = $args{'map_id'};
    my $is_compressed      = $args{'is_compressed'};
    my $pixel_height       = $args{'pixel_height'};
    my $map_aggregate_corr = $args{'map_aggregate_corr'};

    my ($return_y1,$return_y2);
    
    my $map_name        = $self->map_name($map_id);
    my $ref_slot_no     = $drawer->reference_slot_no($slot_no);
    my $base_y          = $self->base_y;
    my $boundary_factor = 0.5;
    my $magnify_all     = $self->magnify_all;
    my $capped          = 0;

    my $top_boundary    = $base_y - (
        ($drawer->pixel_height()) * $boundary_factor * $magnify_all);
    my $bottom_boundary = $base_y+($drawer->pixel_height() * $magnify_all) + (
        ($drawer->pixel_height()) * $boundary_factor * $magnify_all);

    #
    # If drawing compressed maps in the first slot, then draw them
    # in "display_order," else we'll try to line them up.
    #
    my ( $this_map_y, $this_map_x )=(0,0);

    $return_y1 = $this_map_y;
    $return_y2 = $this_map_y + $pixel_height;
    if (defined $ref_slot_no){
        # Use Correspondences to figure out where to put this vertically.
        my $ref_corrs = $drawer->map_correspondences( $slot_no, $map_id );
        my ( $min_ref_y, $max_ref_y,  $ref_top, $ref_bottom );
        for my $ref_corr ( values %$ref_corrs ) {

            #
            # Get the information about the reference map.
            #
#xxx
            my $ref_pos =
                $drawer->reference_map_coords( $ref_slot_no,
                $ref_corr->{'ref_map_id'} );

            # average of corr on ref map
            my $avg_mid=defined($ref_corr->{'avg_mid'})
                ? $ref_corr->{'avg_mid'}
                : $ref_corr->{'start_avg1'};

            # average of corr on current map
            my $avg_mid2=defined($ref_corr->{'avg_mid2'})
                ? $ref_corr->{'avg_mid2'}
                : $ref_corr->{'start_avg2'};

            my $ref_map_pixel_len = $ref_pos->{'y2'} - $ref_pos->{'y1'};
            my $ref_map_unit_len  = $ref_pos->{'map_stop'} - $ref_pos->{'map_start'};
            $ref_top    = $ref_pos->{'y1'};
            $ref_bottom = $ref_pos->{'y2'};

            # Set the avg location of the corr on the ref map
            my $ref_map_mid_y =
                $ref_pos->{'y1'} +
                (($avg_mid - $ref_pos->{'map_start'} ) /
                  $ref_map_unit_len ) * $ref_map_pixel_len;
#xxx
            my $ref_map_y1 =
              $ref_pos->{'y1'} +
              ( ( $ref_corr->{'min_start'} - $ref_pos->{'map_start'} ) /
                  $ref_map_unit_len ) * $ref_map_pixel_len;
            my $ref_map_y2 =
              $ref_pos->{'y1'} +
              ( ( $ref_corr->{'max_start'} - $ref_pos->{'map_start'} ) /
                  $ref_map_unit_len ) * $ref_map_pixel_len;

            # add aggregate correspondences to ref_connections
            if (0){
                # Single line to avg corr
                push @{$map_aggregate_corr->{$map_id}},
                  [ $ref_pos->{'x1'}, $ref_map_mid_y, $ref_corr->{'no_corr'}
                  ,($avg_mid2-$self->start_position($map_id))];
            }
            else{
                # V showing span of corrs
                push @{$map_aggregate_corr->{$map_id}},
                  [ $ref_pos->{'x1'}, $ref_map_y1, $ref_corr->{'no_corr'} 
                  ,($ref_corr->{'min_start2'}-$self->start_position($map_id)) ];
                push @{$map_aggregate_corr->{$map_id}},
                  [ $ref_pos->{'x1'}, $ref_map_y2, $ref_corr->{'no_corr'}
                  ,($ref_corr->{'max_start2'}-$self->start_position($map_id)) ];
            }
            #
            # Center map around ref_map_mid_y
            #
            my $map_unit_len  = $self->map_length($map_id);
            my $map_start  = $self->start_position($map_id);
            my $rstart = sprintf( "%.2f", ( $avg_mid2 - $map_start ) / $map_unit_len );
            $min_ref_y = $ref_map_mid_y - ($pixel_height*$rstart);
            $max_ref_y = $ref_map_mid_y + ($pixel_height*(1-$rstart));
        }
    
        $return_y1  = $min_ref_y,
        $return_y2  = $max_ref_y,
    }
    my $temp_hash = $self->new_enforce_boundaries(
        return_y1       => $return_y1,
        return_y2       => $return_y2,
        top_boundary    => $top_boundary,
        bottom_boundary => $bottom_boundary,
        pixel_height    => $pixel_height,
    );
    $return_y1       = $temp_hash->{'return_y1'};
    $return_y2       = $temp_hash->{'return_y2'};
    $pixel_height    = $temp_hash->{'pixel_height'};
    $capped          = $temp_hash->{'capped'};

    return ($return_y1,$return_y2,$pixel_height,$capped);
}

# ----------------------------------------

=pod

=head2 offset_drawing_data

Add the topper to the map.

=cut

sub offset_drawing_data {

    my ( $self, %args )    = @_;
    my $offset             = $args{'offset'};
    my $drawing_data       = $args{'drawing_data'};
    
    for (my $i=0;$i<=$#{$drawing_data};$i++){
        if ( $drawing_data->[$i][0] eq STRING_UP
          or $drawing_data->[$i][0] eq STRING){
            $drawing_data->[$i][2]+=$offset;
        }
        elsif ( $drawing_data->[$i][0] eq FILL
            or  $drawing_data->[$i][0] eq ARC
            or  $drawing_data->[$i][0] eq FILL_TO_BORDER){
            $drawing_data->[$i][1]+=$offset;
        }
        elsif ($drawing_data->[$i][0] eq LINE
            or $drawing_data->[$i][0] eq FILLED_RECT
            or $drawing_data->[$i][0] eq RECTANGLE
            ){  
            $drawing_data->[$i][1]+=$offset;
            $drawing_data->[$i][3]+=$offset;
        }
        else{
            die $drawing_data->[$i][0]." not caught in offset.  Inform developer\n";
        }
    }
}

# ----------------------------------------

=pod

=head2 add_topper

Add the topper to the map.

=cut

sub add_topper {

    my ( $self, %args )    = @_;
    my $drawer             = $args{'drawer'};
    my $slot_no            = $args{'slot_no'};
    my $map_id             = $args{'map_id'};
    my $is_compressed      = $args{'is_compressed'};
    my $map_drawing_data   = $args{'map_drawing_data'};
    my $map_placement_data = $args{'map_placement_data'};
    my $map_area_data      = $args{'map_area_data'};

    my $no_features        = $self->no_features($map_id);
    my $map_name           = $self->map_name($map_id);
    my $reg_font     = $drawer->regular_font
      or return $self->error( $drawer->error );
    my $font_width         = $reg_font->width;
    my $font_height        = $reg_font->height;
    my $topper_height      = ( $font_height + 2 ) * 2;

    my $base_x     = $map_placement_data->{$map_id}{'map_coords'}[0];
    my $map_base_y = $map_placement_data->{$map_id}{'map_coords'}[1];

    #
    # Indicate total number of features on the map.
    #
    my @map_toppers = $is_compressed ? ($map_name) : ();
    push @map_toppers, "[$no_features]" if defined $no_features;
    for my $i ( 0 .. $#map_toppers ) {
        my $topper = $map_toppers[$i];
        my $f_x1   = $base_x - ( ( length($topper) * $font_width ) / 2 );
        my $f_x2   = $f_x1 + ( length($topper) * $font_width ) ;

        my $topper_y =
              $map_base_y - ( $font_height * ( scalar @map_toppers - $i ) + 4 );

        $map_placement_data->{$map_id}{'bounds'}[1]=$topper_y
            if  ($map_placement_data->{$map_id}{'bounds'}[1]>$topper_y);

        my @topper_bounds=($f_x1, $topper_y, $f_x2,
            $topper_y+( $font_height * ( scalar @map_toppers - $i ))-4);
        my $map             = $self->map($map_id);
        my $map_details_url = DEFAULT->{'map_details_url'};
        my $code            = '';
        eval $self->map_type_data( $map->{'map_type_aid'}, 'area_code' );
        push @{$map_area_data->{$map_id}},
          {
            coords => \@topper_bounds,
            url  => $map_details_url."?ref_map_aids=".$map->{'accession_id'},
            alt  => 'Map Details: ' . $map->{'map_name'},
            code => $code,
          };
                                                                                
        $map_placement_data->{$map_id}{'bounds'}[0]=$f_x1
            if  ($map_placement_data->{$map_id}{'bounds'}[0]>$f_x1);
        $map_placement_data->{$map_id}{'bounds'}[1]=$topper_y
            if  ($map_placement_data->{$map_id}{'bounds'}[1]>$topper_y);
        $map_placement_data->{$map_id}{'bounds'}[2]=$f_x2
            if  ($map_placement_data->{$map_id}{'bounds'}[2]<$f_x2);

        push @{$map_drawing_data->{$map_id}},
          [ STRING, $reg_font, $f_x1, $topper_y, $topper, 'black' ];
    }

}

# ----------------------------------------

=pod

=head2 add_capped_mark

Add astrisks to the map if it was capped

=cut
sub add_capped_mark {

    my ( $self, %args )    = @_;
    my $drawer             = $args{'drawer'};
    my $map_id             = $args{'map_id'};
    my $map_area_data      = $args{'map_area_data'};
    my $drawing_data       = $args{'drawing_data'};
    my $capped             = $args{'capped'};
    my $map_placement_data = $args{'map_placement_data'};

    my $reg_font     = $drawer->regular_font
      or return $self->error( $drawer->error );
    my $font_width         = $reg_font->width;
    my $font_height        = $reg_font->height;
    my $map_coords         = $map_placement_data->{$map_id}{'map_coords'};
    if ($capped == 1 or $capped == 3){ #top capped
        # Draw asterisk
        my ($x1,$y1,$x2,$y2)=($map_coords->[2]+2,
                $map_coords->[1],
                $map_coords->[2]+2+$font_width,
                $map_coords->[1]+$font_height);
        push @$drawing_data,
            [ STRING, $reg_font, $x1, $y1 , '*', 'red' ];
        # add map over to identify what it means
        push @$map_area_data,
          {
            coords => [$x1,$y1,$x2,$y2],
            url  => '',
            alt  => 'Size Capped',
          };
        $map_placement_data->{$map_id}{'bounds'}[2]=$x2
            if ($map_placement_data->{$map_id}{'bounds'}[2]<$x2);
    }
    if ($capped >= 2){ #bottom capped
        # Draw asterisk
        my ($x1,$y1,$x2,$y2)=($map_coords->[2]+2,
                $map_coords->[3] - $font_height,
                $map_coords->[2]+2+$font_width,
                $map_coords->[3]);
        push @$drawing_data,
            [ STRING, $reg_font,$x1 , $y1 , '*', 'red' ];
        # add map over to identify what it means
        push @$map_area_data,
          {
            coords => [$x1,$y1,$x2,$y2],
            url  => '',
            alt  => 'Size Capped',
          };
        $map_placement_data->{$map_id}{'bounds'}[2]=$x2
            if ($map_placement_data->{$map_id}{'bounds'}[2]<$x2);
    }
}

# ----------------------------------------

=pod

=head2 layout_map_foundation

Lays out the base map

=cut

sub layout_map_foundation {

    my ( $self, %args ) = @_;

    my ( $min_x, $area );
    my $base_x          = $args{'base_x'};
    my $base_y          = $args{'base_y'};
    my $map_base_y      = $args{'base_y'};
    my $top_y           = $args{'top_y'};
    my $map_id          = $args{'map_id'};
    my $is_compressed   = $args{'is_compressed'};
    my $slot_no         = $args{'slot_no'};
    my $drawer          = $args{'drawer'};
    my $map_columns     = $args{'map_columns'};
    my $drawing_data    = $args{'drawing_data'};
    my $map_area_data    = $args{'map_area_data'};
    my $original_base_x = $args{'original_base_x'};
    my $last_map_x      = $args{'last_map_x'};
    my $last_map_y      = $args{'last_map_y'};
    my $no_of_maps      = $args{'no_of_maps'};
    my $map_length      = $args{'map_length'};

    my $pixel_height = $drawer->pixel_height;
    my $label_side   = $drawer->label_side($slot_no);
    my $reg_font     = $drawer->regular_font
      or return $self->error( $drawer->error );
    my $magnify_all = $self->magnify_all;
    my $font_width  = $reg_font->width;
    my $font_height = $reg_font->height;

    my $column_width         = 70;
    if ($self->aggregate){
        $column_width        = 40;
    }
    my @ref_connections;
    my $topper_height        = ( $font_height + 2 ) * 2;
    my $map_name             = $self->map_name($map_id);
    my $no_features          = $self->no_features($map_id);
    my $min_map_pixel_height = $drawer->config_data('min_map_pixel_height');
    my $scaled_map_pixel_height = $min_map_pixel_height;
    my $capped               = 0; #represents if the size of the map 
                                  #was capped. Representation based on binary:
                                  # 0 = not capped, 1 = top; 2 = bottom
                                  # 3 = both 

    #
    # Set information used to scale.
    #
    if ($drawer->{'data'}{'ref_unit_size'}{$self->map_units($map_id)}){
        $scaled_map_pixel_height
            = ($self->stop_position($map_id)-$self->start_position($map_id))
            * ($drawer->pixel_height()
              / $drawer->{'data'}{'ref_unit_size'}{$self->map_units($map_id)});
        $scaled_map_pixel_height = $min_map_pixel_height
            if ($scaled_map_pixel_height < $min_map_pixel_height);
        $scaled_map_pixel_height=$scaled_map_pixel_height*$drawer->data_module->magnification($slot_no,$map_id)
            *$magnify_all;
    }
    #
    # Get the information about the reference map.
    #
    my ($ref_y1,$ref_y2);
    my $ref_slot_no = $drawer->reference_slot_no($slot_no);
    my $ref_corrs = $drawer->map_correspondences( $slot_no, $map_id );
    for my $ref_corr ( values %$ref_corrs ) {
        my $ref_pos =
            $drawer->reference_map_coords( $ref_slot_no,
            $ref_corr->{'ref_map_id'} );
        $ref_y1 = $ref_pos->{'y1'} 
            if (!defined($ref_y1) or $ref_y1>$ref_pos->{'y1'}); 
        $ref_y2 = $ref_pos->{'y2'} 
            if (!defined($ref_y2) or $ref_y2<$ref_pos->{'y2'}); 
    }
    #
    # Set the boundaries for the top and the bottom that no
    # map shall be allowed to cross.
    #
    my $boundary_factor=0.5;
#    my $top_boundary=$ref_y1 - (
#        ($ref_y2 - $ref_y1) * $boundary_factor);
#    my $bottom_boundary=$ref_y2 + (
#        ($ref_y2 - $ref_y1) * $boundary_factor);
    my $top_boundary=$base_y - (
        ($drawer->pixel_height()) * $boundary_factor * $magnify_all);
    my $bottom_boundary=$base_y+($drawer->pixel_height() * $magnify_all) + (
        ($drawer->pixel_height()) * $boundary_factor * $magnify_all);

    #
    #Decide the dimentions of a compressed map
    #
    my $compressed_map_pix_height = int(
        (
            $drawer->pixel_height -
              ( ( ( $font_height + 4 ) * 2 ) * $no_of_maps )
        ) / $no_of_maps
    );
    $compressed_map_pix_height = $min_map_pixel_height
      if $compressed_map_pix_height < $min_map_pixel_height;
    my $compressed_map_pix_width = 4;

    #
    # Indicate total number of features on the map.
    #
    my @map_toppers = $is_compressed ? ($map_name) : ();
    push @map_toppers, "[$no_features]" if defined $no_features;

    #
    # If drawing compressed maps in the first slot, then draw them
    # in "display_order," else we'll try to line them up.
    #
    if ( $is_compressed && $slot_no == 0 ) {
        my ( $this_map_y, $this_map_x );
        if ( $last_map_y > $drawer->pixel_height ) {
            $this_map_y = $base_y;
            $this_map_x = $last_map_x + 50;
        }
        else {
            $this_map_y = $last_map_y;
            $this_map_x = $last_map_x;
        }
        $this_map_x = $original_base_x unless defined($this_map_x);
        $last_map_x = $this_map_x;
        my $half_label = ( ( $font_width * length($map_name) ) / 2 );
        $base_x       = $this_map_x - $half_label;
        $map_base_y   = $this_map_y;
        $pixel_height = $scaled_map_pixel_height;
        $area         = [
            $base_x,
            $this_map_y + $font_height,
            $base_x + $font_width * length($map_name),
            $this_map_y + $font_height + $pixel_height
        ];
    }
    elsif ($is_compressed) {
        my $ref_corrs = $drawer->map_correspondences( $slot_no, $map_id );
        my ( $min_ref_y, $max_ref_y,  $ref_top, $ref_bottom );
        for my $ref_corr ( values %$ref_corrs ) {

            #
            # Get the information about the reference map.
            #
            my $ref_pos =
                $drawer->reference_map_coords( $ref_slot_no,
                $ref_corr->{'ref_map_id'} );

            my $avg_mid;
            if (defined($ref_corr->{'avg_mid'})){
                $avg_mid=$ref_corr->{'avg_mid'};
            }
            else{
                $avg_mid=$ref_corr->{'start_avg1'}
            }
            my $avg_mid2;
            if (defined($ref_corr->{'avg_mid2'})){
                $avg_mid2=$ref_corr->{'avg_mid2'};
            }
            else{
                $avg_mid2=$ref_corr->{'start_avg2'}
            }


            my $ref_map_pixel_len = $ref_pos->{'y2'} - $ref_pos->{'y1'};
            my $ref_map_unit_len  = $ref_pos->{'map_stop'} - $ref_pos->{'map_start'};
            $ref_top    = $ref_pos->{'y1'};
            $ref_bottom = $ref_pos->{'y2'};

            my $ref_map_y1 =
              $ref_pos->{'y1'} +
              ( ( $ref_corr->{'min_start'} - $ref_pos->{'map_start'} ) /
                  $ref_map_unit_len ) * $ref_map_pixel_len;
            my $ref_map_y2 =
              $ref_pos->{'y1'} +
              ( ( $ref_corr->{'max_start'} - $ref_pos->{'map_start'} ) /
                  $ref_map_unit_len ) * $ref_map_pixel_len;
            # Set the avg location of the corr on the ref map
            my $ref_map_mid_y =
                $ref_pos->{'y1'} +
                (($avg_mid - $ref_pos->{'map_start'} ) /
                  $ref_map_unit_len ) * $ref_map_pixel_len;

            if (0){
                # Single line to avg corr
                push @ref_connections,
                  [ $ref_pos->{'x1'}, $ref_map_mid_y, $ref_corr->{'no_corr'}
                  ,($avg_mid2-$self->start_position($map_id))];
            }
            else{
                # V showing span of corrs
                push @ref_connections,
                  [ $ref_pos->{'x1'}, $ref_map_y1, $ref_corr->{'no_corr'} 
                  ,($ref_corr->{'min_start2'}-$self->start_position($map_id)) ];
                push @ref_connections,
                  [ $ref_pos->{'x1'}, $ref_map_y2, $ref_corr->{'no_corr'}
                  ,($ref_corr->{'max_start2'}-$self->start_position($map_id)) ];
            }

            #
            # If desired, draw maps to scale otherwise
            #  keep the map a consistent height.
            #
            if ($self->scale_maps 
                and $self->config_data('scalable')
                and
                $self->config_data('scalable')->{$self->map_units($map_id)}){
                $min_ref_y = $ref_map_mid_y - ($scaled_map_pixel_height/2);
                $max_ref_y = $ref_map_mid_y + ($scaled_map_pixel_height/2);
            }
            else{
                $min_ref_y = $ref_map_mid_y - $min_map_pixel_height;
                $max_ref_y = $ref_map_mid_y + $min_map_pixel_height;
            }
        }

        my $map_pix_len = $max_ref_y - $min_ref_y;
        if ( $map_pix_len < $min_map_pixel_height ) {
            $pixel_height = $min_map_pixel_height;
            my $mid_ref_y = $min_ref_y + ( $max_ref_y - $min_ref_y );
            $min_ref_y = $mid_ref_y - ( $pixel_height / 2 );
            $max_ref_y = $mid_ref_y + ( $pixel_height / 2 );
        }
        else {
            $pixel_height = $map_pix_len;
        }
        $map_base_y = $min_ref_y;

        my $map_lane;
        my $buffer = 4;

        if (@$map_columns) {
            for my $i ( 0 .. $#{$map_columns} ) {
                if ( $map_columns->[$i] < $min_ref_y - $topper_height ) {
                    $map_lane = $i;
                    last;
                }
            }
        }
        else {
            $map_lane = 0;
        }
        $map_lane = scalar @$map_columns
          unless defined $map_lane;
        $map_columns->[$map_lane] = $max_ref_y + $buffer;

        $base_x = $label_side eq RIGHT
            ? $original_base_x + ( $column_width * $map_lane )
            : $original_base_x - ( $column_width * $map_lane );
        $area = [
            $base_x,                                   $min_ref_y,
            $base_x + $font_width * length($map_name), $max_ref_y,
        ];


        if (defined $ref_slot_no){
            my $temp_hash = $self->enforce_boundaries(
                map_base_y      => $map_base_y,
                top_boundary    => $top_boundary,
                bottom_boundary => $bottom_boundary,
                pixel_height    => $pixel_height,
                area            => $area,
            );
            $map_base_y      = $temp_hash->{'map_base_y'};
            $top_boundary    = $temp_hash->{'top_boundary'};
            $bottom_boundary = $temp_hash->{'bottom_boundary'};
            $pixel_height    = $temp_hash->{'pixel_height'};
            $capped          = $temp_hash->{'capped'};
        }
    }
    else{
        if ($self->scale_maps
            and $self->config_data('scalable')
            and
            $self->config_data('scalable')->{$self->map_units($map_id)}){
            $pixel_height = $scaled_map_pixel_height;
            if (defined $ref_slot_no){
                my $temp_hash = $self->enforce_boundaries(
                    map_base_y      => $map_base_y,
                    top_boundary    => $top_boundary,
                    bottom_boundary => $bottom_boundary,
                    pixel_height    => $pixel_height,
                    area            => $area,
                );
                $map_base_y      = $temp_hash->{'map_base_y'};
                $top_boundary    = $temp_hash->{'top_boundary'};
                $bottom_boundary = $temp_hash->{'bottom_boundary'};
                $pixel_height    = $temp_hash->{'pixel_height'};
                $capped          = $temp_hash->{'capped'};
            }
        }
    }

    $top_y = $map_base_y unless defined $top_y;
    $top_y = $map_base_y if $map_base_y < $top_y;

    for my $i ( 0 .. $#map_toppers ) {
        my $topper = $map_toppers[$i];
        my $f_x    = $base_x - ( ( length($topper) * $font_width ) / 2 );

        my $topper_y;
        if ( $slot_no == 0 ) {
            $topper_y = $map_base_y;
            $map_base_y += $font_height + 2;
            $last_map_y += $font_height + 2;
        }
        else {
            $topper_y =
              $map_base_y - ( $font_height * ( scalar @map_toppers - $i ) + 4 );
        }

        my @topper_bounds=($f_x, $topper_y,  
            $f_x + ( length($topper) * $font_width ) ,
            $topper_y+( $font_height * ( scalar @map_toppers - $i ))-4);
        my $map             = $self->map($map_id);
        my $map_details_url = DEFAULT->{'map_details_url'};
        my $code            = '';
        eval $self->map_type_data( $map->{'map_type_aid'}, 'area_code' );
        push @$map_area_data,
          {
            coords => \@topper_bounds,
            url  => $map_details_url."?ref_map_aids=".$map->{'accession_id'},
            alt  => 'Map Details: ' . $map->{'map_name'},
            code => $code,
          };
                                                                                

        push @$drawing_data,
          [ STRING, $reg_font, $f_x, $topper_y, $topper, 'black' ];
        $min_x = $f_x if ( ( not defined($min_x) ) or $f_x < $min_x );
    }
    
    return ( $base_x, $min_x, $map_base_y, $top_y, $area, 
        $last_map_x, $last_map_y, $pixel_height, $capped, \@ref_connections );

}

# ----------------------------------------------------------
sub enforce_boundaries {
    #
    # enforce the boundaries of maps
    #
    my ($self,%args)    = @_;
    my $map_base_y      = $args{'map_base_y'};
    my $top_boundary    =$args{'top_boundary'};
    my $bottom_boundary =$args{'bottom_boundary'};
    my $capped          = 0;
    my $pixel_height    =$args{'pixel_height'};
    my $area            =$args{'area'};
     
    if ($map_base_y<$top_boundary){
        $capped        = 1; 
        $pixel_height -= ($top_boundary-$map_base_y); 
        $map_base_y    = $top_boundary;
        if ($area and scalar @$area){
            if ($area->[1]<$top_boundary){
                $area->[1] = $top_boundary;
            } 
        }
    }
    if ($bottom_boundary and $pixel_height+$map_base_y>$bottom_boundary){
        ###Assumes $bottom_boundary is not naturally 0 
        $capped += 2;
        $pixel_height=$bottom_boundary-$map_base_y;
            if ($area and scalar @$area){
                if ($area->[3]>$bottom_boundary){
                $area->[3]     = $bottom_boundary;
                } 
        } 
    }
    return {
        map_base_y      => $map_base_y,
		top_boundary    => $top_boundary,
		bottom_boundary => $bottom_boundary,
		pixel_height    => $pixel_height,
		capped          => $capped,
    }
}

# ----------------------------------------------------------
sub new_enforce_boundaries {
    #
    # enforce the boundaries of maps
    #
    my ($self,%args)    = @_;
    my $return_y1       = $args{'return_y1'};
    my $return_y2       = $args{'return_y2'};
    my $top_boundary    =$args{'top_boundary'};
    my $bottom_boundary =$args{'bottom_boundary'};
    my $capped          = 0;
    my $pixel_height    =$args{'pixel_height'};
     
    if ($return_y1 < $top_boundary){
        $capped        = 1; 
        $pixel_height -= ($top_boundary-$return_y1); 
        $return_y1     = $top_boundary;
    }
    if ($return_y2>$bottom_boundary){
        $capped += 2;
        $pixel_height -= $return_y2-$bottom_boundary;
        $return_y2= $bottom_boundary;
    }
    return {
        return_y1       => $return_y1,
        return_y2       => $return_y2,
		pixel_height    => $pixel_height,
		capped          => $capped,
    }
}

# ---------------------------------------------------
sub add_tick_marks {

    my ( $self, %args )   = @_;
    my $base_x            = $args{'base_x'};
    my $map_base_y        = $args{'map_base_y'};
    my $drawer            = $args{'drawer'};
    my $map_id            = $args{'map_id'};
    my $slot_no           = $args{'slot_no'};
    my $drawing_data      = $args{'drawing_data'};
    my $map_area_data     = $args{'map_area_data'};
    my $pixel_height      = $args{'pixel_height'};
    my $is_flipped        = $args{'is_flipped'};
    my $map_start         = $self->start_position($map_id);
    my $actual_map_length = $args{'actual_map_length'};
    my $map_length        = $args{'map_length'};
    my $map_width         = $self->map_width($map_id);
    my $max_x             = $args{'max_x'};
    my $min_x             = $args{'min_x'};
    my $map_coords        = $args{'map_coords'};
    my $map_aid           = $self->map_aid($map_id);

    my $label_side = $drawer->label_side($slot_no);
    my $reg_font   = $drawer->regular_font
      or return $self->error( $drawer->error );
    my $font_width  = $reg_font->width;
    my $font_height = $reg_font->height;

    my $array_ref     = $self->tick_mark_interval($map_id,$pixel_height);
    my ($interval,$map_scale) =@$array_ref;
    my $no_intervals  = int( $actual_map_length / $interval );
    my $tick_overhang = 15;
    my @intervals     =
      map { int( $map_start + ( $_ * $interval ) ) } 1 .. $no_intervals;
    my $min_tick_distance= $self->config_data('min_tick_distance') || 40;
    my $last_tick_rel_pos = undef;

    for my $tick_pos (@intervals) {
        my $rel_position = ( $tick_pos - $map_start ) / $map_length;
        
        if (
            (
             ($rel_position*$pixel_height) < $min_tick_distance)
             or 
                (defined($last_tick_rel_pos) 
                 and (
                  ($rel_position*$pixel_height)
                  - ($last_tick_rel_pos*$pixel_height)
                    < $min_tick_distance
                 )
            )
           ){
            next;
        }
            
        
        $last_tick_rel_pos = $rel_position;

        my $y_pos = $is_flipped
          ? $map_coords->[3] - ( $pixel_height * $rel_position )
          : $map_coords->[1] + ( $pixel_height * $rel_position );

        my $tick_start =
            $label_side eq RIGHT
          ? $base_x - $tick_overhang
          : $base_x;

        my $tick_stop =
            $label_side eq RIGHT
          ? $base_x + $map_width
          : $base_x + $map_width + $tick_overhang;

        push @$drawing_data,
          [ LINE, $tick_start, $y_pos, $tick_stop, $y_pos, 'grey' ];

        my $clip_arrow_color='grey';
        my $clip_arrow_width  = 6;
        my $clip_arrow_y1_down = $y_pos+2;
        my $clip_arrow_y1_up = $y_pos-2;
        my $clip_arrow_y2_down = $clip_arrow_y1_down+3;
        my $clip_arrow_y2_up = $clip_arrow_y1_up-3;
        my $clip_arrow_y3_down = $clip_arrow_y2_down+5;
        my $clip_arrow_y3_up = $clip_arrow_y2_up-5;
        my $clip_arrow_x1 = 
            $label_side eq LEFT 
          ? $tick_stop-$clip_arrow_width
          : $tick_start;
        my $clip_arrow_x2 = $clip_arrow_x1 +$clip_arrow_width;
        my $clip_arrow_xmid = ($clip_arrow_x1+$clip_arrow_x2)/2; 
        # First line across
        push @$drawing_data,
          [ LINE, $clip_arrow_x1, $clip_arrow_y1_down, $clip_arrow_x2, $clip_arrow_y1_down, $clip_arrow_color ];
        push @$drawing_data,
          [ LINE, $clip_arrow_x1, $clip_arrow_y1_up, $clip_arrow_x2, $clip_arrow_y1_up, $clip_arrow_color ];
        # line to arrow 
        push @$drawing_data,
          [ LINE, $clip_arrow_xmid, $clip_arrow_y1_down, $clip_arrow_xmid, $clip_arrow_y2_down, $clip_arrow_color ];
        push @$drawing_data,
          [ LINE, $clip_arrow_xmid, $clip_arrow_y1_up, $clip_arrow_xmid, $clip_arrow_y2_up, $clip_arrow_color ];
        # base of arrow
        push @$drawing_data,
          [ LINE, $clip_arrow_x1, $clip_arrow_y2_down, $clip_arrow_x2, $clip_arrow_y2_down, $clip_arrow_color ];
        push @$drawing_data,
          [ LINE, $clip_arrow_x1, $clip_arrow_y2_up, $clip_arrow_x2, $clip_arrow_y2_up, $clip_arrow_color ];
        # left side of arrow
        push @$drawing_data,
          [ LINE, $clip_arrow_x1, $clip_arrow_y2_down, $clip_arrow_xmid, $clip_arrow_y3_down, $clip_arrow_color ];
        push @$drawing_data,
          [ LINE, $clip_arrow_x1, $clip_arrow_y2_up, $clip_arrow_xmid, $clip_arrow_y3_up, $clip_arrow_color ];
        # right side of arrow
        push @$drawing_data,
          [ LINE, $clip_arrow_x2, $clip_arrow_y2_down, $clip_arrow_xmid, $clip_arrow_y3_down, $clip_arrow_color ];
        push @$drawing_data,
          [ LINE, $clip_arrow_x2, $clip_arrow_y2_up, $clip_arrow_xmid, $clip_arrow_y3_up, $clip_arrow_color ];
        # fill arrow
        push @$drawing_data,
          [ FILL, $clip_arrow_xmid, $clip_arrow_y2_down+1, $clip_arrow_color ];
        push @$drawing_data,
          [ FILL, $clip_arrow_xmid, $clip_arrow_y2_up-1, $clip_arrow_color ];

        my $down_command=$is_flipped ? '1' : '0';
        my $up_command=$is_flipped ? '0' : '1';
        my ($up_start_pos,$up_stop_pos,$down_start_pos,$down_stop_pos);
        my $slot_info=$drawer->data_module->slot_info->{$slot_no};
        if ($is_flipped){
            $up_start_pos    = $tick_pos;
            $down_stop_pos = $tick_pos;
            $down_start_pos   = defined($slot_info->{$map_id}->[0])
                ? $slot_info->{$map_id}->[0]
                : "''";
            $up_stop_pos   = defined($slot_info->{$map_id}->[1])
                ? $slot_info->{$map_id}->[1]
                : "''";

        }
        else{
            $up_stop_pos    = $tick_pos;
            $down_start_pos = $tick_pos;
            $up_start_pos   = defined($slot_info->{$map_id}->[0])
                ? $slot_info->{$map_id}->[0]
                : "''";
            $down_stop_pos   = defined($slot_info->{$map_id}->[1])
                ? $slot_info->{$map_id}->[1]
                : "''";
        }
        my $magnification = defined($slot_info->{$map_id}->[4])
            ? $slot_info->{$map_id}->[4]
            : "'1'";

        
        my $down_code=qq[ 
            onMouseOver="window.status='crop down';return true" 
            onClick="mod_map_info($slot_no, '$map_aid', $down_start_pos, $down_stop_pos,$magnification);document.comparative_map_form.submit();"
            ]; 
        my $up_code=qq[
            onMouseOver="window.status='crop up';return true" 
            onClick="mod_map_info($slot_no, '$map_aid', $up_start_pos, $up_stop_pos,$magnification);document.comparative_map_form.submit();"
            ]; 
        push @$map_area_data,
          {
            coords => [$clip_arrow_x1,$clip_arrow_y1_down,
                $clip_arrow_x2,$clip_arrow_y3_down],
            url  => '#',
            alt  => 'Crop from here down',
            code => $down_code,
          };
        push @$map_area_data,
          {
            coords => [$clip_arrow_x1,$clip_arrow_y3_up,
                $clip_arrow_x2,$clip_arrow_y1_up],
            url  => '#',
            alt  => 'Crop from here up',
            code => $up_code,
          };
        my $label_x =
            $label_side eq RIGHT
          ? $tick_start - $font_height - 2
          : $tick_stop + 2;
        #
        # Figure out how many signifigant figures the number needs by 
        # going down to the $interval size.
        #
        my $sig_figs = int(''.(log(abs($tick_pos))/log(10)))-int(''.(log(abs($interval))/log(10))) + 1;
        my $tick_pos_str = presentable_number($tick_pos,$sig_figs);
        my $label_y = $y_pos + ( $font_width * length($tick_pos_str) ) / 2;

        push @$drawing_data,
          [ STRING_UP, $reg_font, $label_x, $label_y, $tick_pos_str, 'grey' ];

        my $right = $label_x + $font_height;
        $max_x = $right   if $right > $max_x;
        $min_x = $label_x if $label_x < $min_x;
    }
    return ( $max_x, $min_x );
}

# ---------------------------------------------------
sub new_add_tick_marks {

    my ( $self, %args )   = @_;
    my $map_coords        = $args{'map_coords'};
    my $bounds            = $args{'bounds'};
    my $drawer            = $args{'drawer'};
    my $map_id            = $args{'map_id'};
    my $slot_no           = $args{'slot_no'};
    my $drawing_data      = $args{'drawing_data'};
    my $map_area_data     = $args{'map_area_data'};
    my $pixel_height      = $args{'pixel_height'};
    my $is_flipped        = $args{'is_flipped'};
    my $map_start         = $self->start_position($map_id);
    my $actual_map_length = $args{'actual_map_length'};
    my $map_length        = $args{'map_length'};
    my $map_width         = $self->map_width($map_id);
    my $map_aid           = $self->map_aid($map_id);

    my $label_side = $drawer->label_side($slot_no);
    my $reg_font   = $drawer->regular_font
      or return $self->error( $drawer->error );
    my $font_width  = $reg_font->width;
    my $font_height = $reg_font->height;
    my $base_x     = $map_coords->[0];

    my $array_ref     = $self->tick_mark_interval($map_id,$pixel_height);
    my ($interval,$map_scale) =@$array_ref;
    my $no_intervals  = int( $actual_map_length / $interval );
    my $tick_overhang = 15;
    my @intervals     =
      map { int( $map_start + ( $_ * $interval ) ) } 1 .. $no_intervals;
    my $min_tick_distance= $self->config_data('min_tick_distance') || 40;
    my $last_tick_rel_pos = undef;

    for my $tick_pos (@intervals) {
        my $rel_position = ( $tick_pos - $map_start ) / $map_length;
        
        # If there isn't enough space, skip this one.
        if (
            ( ($rel_position*$pixel_height) < $min_tick_distance)
             or 
            ( defined($last_tick_rel_pos) 
              and (
                  ($rel_position*$pixel_height)
                  - ($last_tick_rel_pos*$pixel_height)
                    < $min_tick_distance
                 )
            )
           ){
            next;
        }
            
        $last_tick_rel_pos = $rel_position;

        my $y_pos = $is_flipped
          ? $map_coords->[3] - ( $pixel_height * $rel_position )
          : $map_coords->[1] + ( $pixel_height * $rel_position );

        my $tick_start =
            $label_side eq RIGHT
          ? $base_x - $tick_overhang
          : $base_x;

        my $tick_stop =
            $label_side eq RIGHT
          ? $base_x + $map_width
          : $base_x + $map_width + $tick_overhang;

        push @$drawing_data,
          [ LINE, $tick_start, $y_pos, $tick_stop, $y_pos, 'grey' ];

        my $clip_arrow_color='grey';
        my $clip_arrow_width  = 6;
        my $clip_arrow_y1_down = $y_pos+2;
        my $clip_arrow_y1_up = $y_pos-2;
        my $clip_arrow_y2_down = $clip_arrow_y1_down+3;
        my $clip_arrow_y2_up = $clip_arrow_y1_up-3;
        my $clip_arrow_y3_down = $clip_arrow_y2_down+5;
        my $clip_arrow_y3_up = $clip_arrow_y2_up-5;
        my $clip_arrow_x1 = 
            $label_side eq LEFT 
          ? $tick_stop-$clip_arrow_width
          : $tick_start;
        my $clip_arrow_x2 = $clip_arrow_x1 +$clip_arrow_width;
        my $clip_arrow_xmid = ($clip_arrow_x1+$clip_arrow_x2)/2; 
        # First line across
        push @$drawing_data,
          [ LINE, $clip_arrow_x1, $clip_arrow_y1_down, $clip_arrow_x2, $clip_arrow_y1_down, $clip_arrow_color ];
        push @$drawing_data,
          [ LINE, $clip_arrow_x1, $clip_arrow_y1_up, $clip_arrow_x2, $clip_arrow_y1_up, $clip_arrow_color ];
        # line to arrow 
        push @$drawing_data,
          [ LINE, $clip_arrow_xmid, $clip_arrow_y1_down, $clip_arrow_xmid, $clip_arrow_y2_down, $clip_arrow_color ];
        push @$drawing_data,
          [ LINE, $clip_arrow_xmid, $clip_arrow_y1_up, $clip_arrow_xmid, $clip_arrow_y2_up, $clip_arrow_color ];
        # base of arrow
        push @$drawing_data,
          [ LINE, $clip_arrow_x1, $clip_arrow_y2_down, $clip_arrow_x2, $clip_arrow_y2_down, $clip_arrow_color ];
        push @$drawing_data,
          [ LINE, $clip_arrow_x1, $clip_arrow_y2_up, $clip_arrow_x2, $clip_arrow_y2_up, $clip_arrow_color ];
        # left side of arrow
        push @$drawing_data,
          [ LINE, $clip_arrow_x1, $clip_arrow_y2_down, $clip_arrow_xmid, $clip_arrow_y3_down, $clip_arrow_color ];
        push @$drawing_data,
          [ LINE, $clip_arrow_x1, $clip_arrow_y2_up, $clip_arrow_xmid, $clip_arrow_y3_up, $clip_arrow_color ];
        # right side of arrow
        push @$drawing_data,
          [ LINE, $clip_arrow_x2, $clip_arrow_y2_down, $clip_arrow_xmid, $clip_arrow_y3_down, $clip_arrow_color ];
        push @$drawing_data,
          [ LINE, $clip_arrow_x2, $clip_arrow_y2_up, $clip_arrow_xmid, $clip_arrow_y3_up, $clip_arrow_color ];
        # fill arrow
        push @$drawing_data,
          [ FILL, $clip_arrow_xmid, $clip_arrow_y2_down+1, $clip_arrow_color ];
        push @$drawing_data,
          [ FILL, $clip_arrow_xmid, $clip_arrow_y2_up-1, $clip_arrow_color ];

        my $down_command=$is_flipped ? '1' : '0';
        my $up_command=$is_flipped ? '0' : '1';
        my ($up_start_pos,$up_stop_pos,$down_start_pos,$down_stop_pos);
        my $slot_info=$drawer->data_module->slot_info->{$slot_no};
        if ($is_flipped){
            $up_start_pos    = $tick_pos;
            $down_stop_pos = $tick_pos;
            $down_start_pos   = defined($slot_info->{$map_id}->[0])
                ? $slot_info->{$map_id}->[0]
                : "''";
            $up_stop_pos   = defined($slot_info->{$map_id}->[1])
                ? $slot_info->{$map_id}->[1]
                : "''";

        }
        else{
            $up_stop_pos    = $tick_pos;
            $down_start_pos = $tick_pos;
            $up_start_pos   = defined($slot_info->{$map_id}->[0])
                ? $slot_info->{$map_id}->[0]
                : "''";
            $down_stop_pos   = defined($slot_info->{$map_id}->[1])
                ? $slot_info->{$map_id}->[1]
                : "''";
        }
        my $magnification = defined($slot_info->{$map_id}->[4])
            ? $slot_info->{$map_id}->[4]
            : "'1'";

        
        my $down_code=qq[ 
            onMouseOver="window.status='crop down';return true" 
            onClick="mod_map_info($slot_no, '$map_aid', $down_start_pos, $down_stop_pos,$magnification);document.comparative_map_form.submit();"
            ]; 
        my $up_code=qq[
            onMouseOver="window.status='crop up';return true" 
            onClick="mod_map_info($slot_no, '$map_aid', $up_start_pos, $up_stop_pos,$magnification);document.comparative_map_form.submit();"
            ]; 
        push @$map_area_data,
          {
            coords => [$clip_arrow_x1,$clip_arrow_y1_down,
                $clip_arrow_x2,$clip_arrow_y3_down],
            url  => '#',
            alt  => 'Crop from here down',
            code => $down_code,
          };
        push @$map_area_data,
          {
            coords => [$clip_arrow_x1,$clip_arrow_y3_up,
                $clip_arrow_x2,$clip_arrow_y1_up],
            url  => '#',
            alt  => 'Crop from here up',
            code => $up_code,
          };
        my $label_x =
            $label_side eq RIGHT
          ? $tick_start - $font_height - 2
          : $tick_stop + 2;
        #
        # Figure out how many signifigant figures the number needs by 
        # going down to the $interval size.
        #
        my $sig_figs = int(''.(log(abs($tick_pos))/log(10)))-int(''.(log(abs($interval))/log(10))) + 1;
        my $tick_pos_str = presentable_number($tick_pos,$sig_figs);
        my $label_y = $y_pos + ( $font_width * length($tick_pos_str) ) / 2;

        push @$drawing_data,
          [ STRING_UP, $reg_font, $label_x, $label_y, $tick_pos_str, 'grey' ];

        my $right = $label_x + $font_height;
        $bounds->[0] = $label_x if $label_x < $bounds->[0];
        $bounds->[2] = $right   if $right > $bounds->[2];
    }
}

# ---------------------------------------------------
sub add_feature_to_map {

    my ( $self, %args ) = @_;
    my $base_x            = $args{'base_x'};
    my $map_base_y        = $args{'map_base_y'};
    my $drawer            = $args{'drawer'};
    my $feature           = $args{'feature'};
    my $map_id            = $args{'map_id'};
    my $slot_no           = $args{'slot_no'};
    my $drawing_data      = $args{'drawing_data'};
    my $map_area_data     = $args{'map_area_data'};
    my $pixel_height      = $args{'pixel_height'};
    my $is_flipped        = $args{'is_flipped'};
    my $map_length        = $args{'map_length'};
    my $rightmostf        = $args{'rightmostf'};
    my $leftmostf         = $args{'leftmostf'};
    my $fcolumns          = $args{'fcolumns'};
    my $feature_type_aids = $args{'feature_type_aids'};
    my $drawn_glyphs      = $args{'drawn_glyphs'};

    my $map_width = $self->map_width($map_id);
    my $reg_font  = $drawer->regular_font
      or return $self->error( $drawer->error );
    my $font_width            = $reg_font->width;
    my $font_height           = $reg_font->height;
    my $default_feature_color = $drawer->config_data('feature_color');
    my $map_start             = $self->start_position($map_id);
    my $label_side            = $drawer->label_side($slot_no);
    my $feature_corr_color    =
      $drawer->config_data('feature_correspondence_color') || '';
    my $collapse_features   = $drawer->collapse_features;
    my $feature_details_url = DEFAULT->{'feature_details_url'};

    # If the map isn't showing labeled features (e.g., it's a
    # relational map and hasn't been expanded), then leave off
    # drawing features that don't have correspondences.
    #
    my $has_corr = $drawer->has_correspondence( $feature->{'feature_id'} );

    my $feature_shape = $feature->{'shape'} || LINE;
    my $shape_is_triangle = $feature_shape =~ /triangle$/;
    my $fstart = $feature->{'start_position'} || 0;
    my $fstop = $shape_is_triangle ? undef: $feature->{'stop_position'};
    $fstop = undef if $fstop < $fstart;

    my $rstart = sprintf( "%.2f", ( $fstart - $map_start ) / $map_length );
    $rstart = $rstart > 1 ? 1 : $rstart < 0 ? 0 : $rstart;
    my $rstop =
      defined $fstop
      ? sprintf( "%.2f", ( $fstop - $map_start ) / $map_length )
      : undef;
    if ( defined $rstop ) {
        $rstop = $rstop > 1 ? 1 : $rstop < 0 ? 0 : $rstop;
    }

    my $tick_overhang = 2;
    my $y_pos1        = $is_flipped
      ? $map_base_y + $pixel_height - ( $pixel_height * $rstart )
      : $map_base_y + ( $pixel_height * $rstart );

    my $y_pos2 =
        defined $rstop
      ? $is_flipped
      ? $map_base_y + $pixel_height - ( $pixel_height * $rstop )
      : $map_base_y + ( $pixel_height * $rstop )
      : undef;

    if ( $is_flipped && defined $y_pos2 ) {
        ( $y_pos2, $y_pos1 ) = ( $y_pos1, $y_pos2 );
    }
    $y_pos2 = $y_pos1 unless defined $y_pos2 && $y_pos2 > $y_pos1;
    my $color = $has_corr ? $feature_corr_color : '';
    $color ||= $feature->{'color'}
      || $default_feature_color;
    my $label      = $feature->{'feature_name'};
    my $tick_start = $base_x - $tick_overhang;
    my $tick_stop  = $base_x + $map_width + $tick_overhang;

    my $label_y;
    my @coords = ();
    if ( $shape_is_triangle || $y_pos2 <= $y_pos1 ) {
        $label_y               = $y_pos1 - $font_height / 2;
        $feature->{'midpoint'} = $fstart;
        $feature->{'mid_y'}    = $y_pos1;
    }
    else {
        $label_y = ( $y_pos1 + ( $y_pos2 - $y_pos1 ) / 2 ) - $font_height / 2;

        $feature->{'midpoint'} =
          ( $fstop > $fstart ) ? ( $fstart + $fstop ) / 2 : $fstart;

        $feature->{'mid_y'} = ( $y_pos1 + $y_pos2 ) / 2;
    }

    #
    # Here we try to reduce the redundant drawing of glyphs.
    # However, if a feature has a correspondence, we want to
    # make sure to draw it so it will show up highlighted.
    #
    my $glyph_key = int($y_pos1) . $feature_shape . int($y_pos2)."_".$has_corr;
    my $draw_this = 1;
    #if ( $drawn_glyphs->{$glyph_key} and $collapse_features ) {
    #    $draw_this = $has_corr ? 1 : 0;
    #}
    if ($drawn_glyphs->{$glyph_key} and $collapse_features){
        $draw_this = 0;
    }

    if ($draw_this) {
        my (@temp_drawing_data);
        if ( $feature_shape eq LINE ) {
            $y_pos1 = ( $y_pos1 + $y_pos2 ) / 2;
            push @temp_drawing_data,
              [ LINE, $tick_start, $y_pos1, $tick_stop, $y_pos1, $color ];

            @coords = ( $tick_start, $y_pos1, $tick_stop, $y_pos1 );
        }
        else {

            my $buffer = 2;
            my $column_index;
            if ( not $self->feature_type_data( $feature->{'feature_type_aid'}, 
                'glyph_overlap' )) {
                $column_index = simple_column_distribution(
                    low          => $y_pos1-$map_base_y,
                    high         => $y_pos2-$map_base_y,,
                    columns      => $fcolumns,
                    map_height   => $pixel_height,
                    buffer       => $buffer,
                );
            }
            else {
                $column_index = 0;
            }

            $feature->{'column'} = $column_index;
            my $offset       = ( $column_index + 1 ) * 7;
            my $vert_line_x1 = $label_side eq RIGHT ? $tick_start : $tick_stop;
            my $vert_line_x2 =
                $label_side eq RIGHT
              ? $tick_stop + $offset
              : $tick_start - $offset;

            my $glyph = Bio::GMOD::CMap::Drawer::Glyph->new();
            my $feature_glyph = $feature_shape;
            $feature_glyph =~s/-/_/g;
            if ($glyph->can($feature_glyph)){
                ###DEBUGING
                #push @temp_drawing_data,
                #[ LINE, $vert_line_x1, $y_pos1, 
                #    $vert_line_x2, $y_pos2, 'blue', ];

                @coords = @{$glyph->$feature_glyph(
                    drawing_data => \@temp_drawing_data,
                    x_pos2       => $vert_line_x2,
                    x_pos1       => $vert_line_x1,
                    y_pos1       => $y_pos1,
                    y_pos2       => $y_pos2,
                    color        => $color,
                    is_flipped   => $is_flipped,
                    direction    => $feature->{'direction'},
                    name         => $feature->{'feature_name'},
                    label_side   => $label_side,
                )};
            }
            else{
                return $self->error("Can't draw shape '$feature_glyph'");
            } 
            if ( $feature->{'feature_type'} eq 'chunk' ) {
                push @$map_area_data,
                  {
                    coords => \@coords,
                    url    => 'viewer?',
                    alt    => 'Zoom: '
                      . $feature->{'start_position'} . '-'
                      . $feature->{'stop_position'}
                  };
            }
            else {
                my $code = '';
                eval $self->feature_type_data( $feature->{'feature_type_aid'},
                    'area_code' );
                push @$map_area_data,
                  {
                    coords => \@coords,
                    url    => $feature_details_url . $feature->{'accession_id'},
                    alt    => 'Feature Details: '
                      . $feature->{'feature_name'} . ' ['
                      . $feature->{'accession_id'} . ']',
                    code => $code,
                  };
            }

        }

        push @$drawing_data, @temp_drawing_data;

        #
        # Register that we saw this type of feature.
        #
        $feature_type_aids->{ $feature->{'feature_type_aid'} } = 1;

        ####
        my ( $left_side, $right_side );
        my $buffer = 2;
        $left_side  = $coords[0] - $buffer;
        $right_side = $coords[2] + $buffer;
        $leftmostf  = $left_side unless defined $leftmostf;
        $rightmostf = $right_side unless defined $rightmostf;
        $leftmostf  = $left_side if $left_side < $leftmostf;
        $rightmostf = $right_side if $right_side > $rightmostf;

        ###Save the corrds and label_y so if there is another
        ### that's collapsed it can use those for its own label
        $drawn_glyphs->{$glyph_key} = [ \@coords, $label_y ];
    }
    else {
        ###Collapsed feature still needs coorect labeling info
        @coords  = @{ $drawn_glyphs->{$glyph_key}->[0] };
        $label_y = $drawn_glyphs->{$glyph_key}->[1];
    }
    return ( $leftmostf, $rightmostf, \@coords, $color, $label_y );
}

# ----------------------------------------------------
sub collect_labels_to_display {

    my ( $self, %args ) = @_;

    my $coords = $args{'coords'};

    #my $north_labels       = $args{'north_labels'};
    #my $south_labels       = $args{'south_labels'};
    my $even_labels        = $args{'even_labels'};
    my $drawer             = $args{'drawer'};
    my $feature            = $args{'feature'};
    my $color              = $args{'color'};
    my $label_y            = $args{'label_y'};
    my $is_flipped         = $args{'is_flipped'};
    my $map_id             = $args{'map_id'};
    my $slot_no            = $args{'slot_no'};
    my $show_labels        = $args{'show_labels'};
    my $midpoint           = $args{'midpoint'};
    my $feature_type_aids  = $args{'feature_type_aids'};
    my $features_with_corr = $args{'features_with_corr'};
    my $map_base_y         = $args{'map_base_y'},

    my $label    = $feature->{'feature_name'};
    my $has_corr = $drawer->has_correspondence( $feature->{'feature_id'} );
    my $feature_details_url = DEFAULT->{'feature_details_url'};

    my $is_highlighted = $drawer->highlight_feature(
        $feature->{'feature_name'},
        @{ $feature->{'aliases'} || [] },
        $feature->{'accession_id'},
    );

    if ($has_corr) {
        my $mid_feature =
          $coords->[1] + ( ( $coords->[3] - $coords->[1] ) / 2 );
        $features_with_corr->{ $feature->{'feature_id'} } = {
            feature_id => $feature->{'feature_id'},
            slot_no    => $slot_no,
            map_id     => $map_id,
            left       => [ $coords->[0], $mid_feature ],
            right      => [ $coords->[2], $mid_feature ],
            tick_y     => $mid_feature,
        };
    }

    if (
        $show_labels
        && (
               $has_corr
            || $drawer->label_features eq 'all'
            || $is_highlighted
            || (   $drawer->label_features eq 'landmarks'
                && $feature->{'is_landmark'} )
        )
      )
    {

#        my $labels =
#             $feature->{'midpoint'} < $midpoint && $is_flipped
#          || $feature->{'midpoint'} > $midpoint && $is_flipped
#          || $feature->{'midpoint'} < $midpoint && !$is_flipped
#          ? $north_labels
#          : $south_labels;
#
#        push @$labels,
#          {
#            priority       => $feature->{'drawing_priority'},
#            text           => $label,
#            target         => $label_y,
#            color          => $color,
#            is_highlighted => $is_highlighted,
#            feature_coords => $coords,
#            feature_mid_y  => $feature->{'mid_y'},
#            feature_type   => $feature->{'feature_type'},
#            has_corr       => $has_corr,
#            feature_id     => $feature->{'feature_id'},
#            start_position => $feature->{'start_position'},
#            shape          => $feature->{'shape'},
#            url            => $feature_details_url . $feature->{'accession_id'},
#            alt            => 'Feature Details: '
#              . $feature->{'feature_name'} . ' ['
#              . $feature->{'accession_id'} . ']',
#          };
        my $even_label_key =
            $is_highlighted ? 'highlights'
          : $has_corr       ? 'correspondences'
          : 'normal';
        push @{ $even_labels->{$even_label_key} },
          {
            priority       => $feature->{'drawing_priority'},
            text           => $label,
            target         => $label_y,
            map_base_y     => $map_base_y,
            color          => $color,
            is_highlighted => $is_highlighted,
            feature_coords => $coords,
            feature_mid_y  => $feature->{'mid_y'},
            feature_type   => $feature->{'feature_type'},
            has_corr       => $has_corr,
            feature_id     => $feature->{'feature_id'},
            start_position => $feature->{'start_position'},
            shape          => $feature->{'shape'},
            column         => $feature->{'column'},
            url            => $feature_details_url . $feature->{'accession_id'},
            alt            => 'Feature Details: '
              . $feature->{'feature_name'} . ' ['
              . $feature->{'accession_id'} . ']',
          };
    }

}

# ----------------------------------------------------
sub add_labels_to_map {

    # Labels moving north
    # must be reverse sorted by start position;  moving south,
    # they should be in ascending order.
    #
    my ( $self, %args ) = @_;

    my $base_x      = $args{'base_x'};
    my $base_y      = $args{'base_y'};
    my $even_labels = $args{'even_labels'};

    my $drawer             = $args{'drawer'};
    my $rightmostf         = $args{'rightmostf'};
    my $leftmostf          = $args{'leftmostf'};
    my $map_id             = $args{'map_id'};
    my $slot_no            = $args{'slot_no'};
    my $drawing_data       = $args{'drawing_data'};
    my $map_area_data      = $args{'map_area_data'};
    my $features_with_corr = $args{'features_with_corr'};
    my $max_x              = $args{'max_x'};
    my $min_x              = $args{'min_x'};
    my $top_y              = $args{'top_y'};
    my $bottom_y           = $args{'bottom_y'};
    my $min_y              = $args{'min_y'};
    my $pixel_height       = $args{'pixel_height'};

    my $label_side = $drawer->label_side($slot_no);
    my $reg_font   = $drawer->regular_font
      or return $self->error( $drawer->error );
    my $font_width         = $reg_font->width;
    my $font_height        = $reg_font->height;
    my $feature_corr_color =
      $drawer->config_data('feature_correspondence_color') || '';
    my $feature_highlight_fg_color =
      $drawer->config_data('feature_highlight_fg_color');
    my $feature_highlight_bg_color =
      $drawer->config_data('feature_highlight_bg_color');

    #my @accepted_labels;    # the labels we keep
    my $buffer = 2;  # the space between things

    my $accepted_labels = even_label_distribution(
        labels      => $even_labels,
        map_height  => $pixel_height,
        font_height => $font_height,
        start_y     => $base_y,
    );
    my $label_offset = 20;
    $base_x =
        $label_side eq RIGHT
      ? $rightmostf > $base_x ? $rightmostf : $base_x
      : $leftmostf < $base_x
      ? $leftmostf
      : $base_x;

    for my $label (@$accepted_labels) {
        my $text    = $label->{'text'};
        my $label_y = $label->{'y'};
        my $label_len = $font_width * length( $text );
        my $label_x =
            $label_side eq RIGHT
          ? $base_x + $label_offset
          : $base_x - ( $label_offset + $label_len );
        my $label_end = $label_x + $label_len;
        my $color     =
            $label->{'has_corr'}
          ? $feature_corr_color || $label->{'color'}
          : $label->{'color'};

        push @$drawing_data,
          [ STRING, $reg_font, $label_x, $label_y, $text, $color ];

        my @label_bounds = (
            $label_x - $buffer,
            $label_y,
            $label_end + $buffer,
            $label_y + $font_height,
        );

        $leftmostf = $label_bounds[0] if $label_bounds[0] < $leftmostf;
        $rightmostf = $label_bounds[2]
          if $label_bounds[2] > $rightmostf;

        #
        # Highlighting.
        #
        if ( $label->{'is_highlighted'} ) {
            push @$drawing_data,
              [ RECTANGLE, @label_bounds, $feature_highlight_fg_color ];

            push @$drawing_data,
              [ FILLED_RECT, @label_bounds, $feature_highlight_bg_color, 0 ];
        }

        push @$map_area_data,
          {
            coords => \@label_bounds,
            url    => $label->{'url'},
            alt    => $label->{'alt'},
          };

        $min_x    = $label_bounds[0] if $label_bounds[0] < $min_x;
        $top_y    = $label_bounds[1] if $label_bounds[1] < $top_y;
        $max_x    = $label_bounds[2] if $label_bounds[2] > $max_x;
        $bottom_y = $label_bounds[3] if $label_bounds[3] > $bottom_y;
        $min_y    = $label_y         if $label_y < $min_y;

        #
        # Now connect the label to the middle of the feature.
        #
        my @coords = @{ $label->{'feature_coords'} || [] };
        my $label_connect_x1 =
            $label_side eq RIGHT
          ? $coords[2]
          : $label_end + $buffer;

        my $label_connect_y1 =
            $label_side eq RIGHT
          ? $label->{'feature_mid_y'}
          : $label_y + $font_height / 2;

        my $label_connect_x2 =
            $label_side eq RIGHT
          ? $label_x - $buffer
          : $coords[0];

        my $label_connect_y2 =
            $label_side eq RIGHT
          ? $label_y + $font_height / 2
          : $label->{'feature_mid_y'};

        #
        # Back the connection off.
        #
        if ( $label->{'shape'} eq LINE ) {
            if ( $label_side eq RIGHT ) {
                $label_connect_x1 += $buffer;
            }
            else {
                $label_connect_x2 -= $buffer;
            }
        }

        push @{$drawing_data},
            $drawer->add_connection(
                $label_connect_x1, $label_connect_y1, $label_connect_x2,
                $label_connect_y2, 'grey'
            );

        #
        # If the feature got a label, then update the right
        # or left connection points for linking up to
        # corresponding features.
        #
        if ( defined $features_with_corr->{ $label->{'feature_id'} } ) {
            if ( $label_side eq RIGHT ) {
                $features_with_corr->{ $label->{'feature_id'} }{'right'} = [
                    $label_bounds[2],
                    (
                        $label_bounds[1] +
                          ( $label_bounds[3] - $label_bounds[1] ) / 2
                    )
                ];
            }
            else {
                $features_with_corr->{ $label->{'feature_id'} }{'left'} = [
                    $label_bounds[0],
                    (
                        $label_bounds[1] +
                          ( $label_bounds[3] - $label_bounds[1] ) / 2
                    )
                ];
            }
        }
    }

    $min_x = $leftmostf  if $leftmostf < $min_x;
    $max_x = $rightmostf if $rightmostf > $max_x;

    return ( $base_x, $leftmostf, $rightmostf, $max_x, $min_x, $top_y,
        $bottom_y, $min_y );

}

# ----------------------------------------------------
sub map_ids {

=pod

=head2 map_ids

Returns the all the map IDs sorted by the number of correspondences
(to the reference map), highest to lowest.

=cut

    my $self = shift;

    unless ( $self->{'sorted_map_ids'} ) {
        my @map_ids = keys %{ $self->{'maps'} || {} };

        if ( $self->slot_no == 0 && scalar @map_ids > 1 ) {
            $self->{'sorted_map_ids'} = [
                map { $_->[0] }
                  sort { $a->[1] <=> $b->[1] || $a->[2] cmp $b->[2] }
                  map {
                    [
                        $_,
                        $self->{'maps'}{$_}{'display_order'},
                        $self->{'maps'}{$_}{'map_name'}
                    ]
                  } @map_ids
            ];
        }
        else {
            $self->{'sorted_map_ids'} = [
                map    { $_->[0] }
                  sort { $b->[1] <=> $a->[1] }
                  map  { [ $_, $self->{'maps'}{$_}{'no_correspondences'} ] }
                  @map_ids
            ];
        }
    }

    return @{ $self->{'sorted_map_ids'} || [] };
}

# ----------------------------------------------------
sub map {

=pod

=head2 map

Returns one map.

=cut

    my $self = shift;
    my $map_id = shift or return;
    return $self->{'maps'}{$map_id};
}

# ----------------------------------------------------
sub maps {

=pod

=head2 maps

Gets/sets all the maps.

=cut

    my $self = shift;
    $self->{'maps'} = shift if @_;
    return $self->{'maps'};
}

# ----------------------------------------------------
sub map_length {

=pod

=head2 map_length

Returns the map's length (stop - start).

=cut

    my $self   = shift;
    my $map_id = shift or return;

    return $self->stop_position($map_id) - $self->start_position($map_id);
}

# ----------------------------------------------------
sub map_width {

=pod

=head2 map_width

Returns a string describing how to draw the map.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    return $map->{'width'}
      || $map->{'default_width'}
      || $self->config_data('map_width');
}

# ----------------------------------------------------
sub real_map_length {

=pod

=head2 real_map_length

Returns the entiry map's length.

=cut

    my $self = shift;
    my $map_id = shift or return;
    return $self->real_stop_position($map_id) -
      $self->real_start_position($map_id);
}

# ----------------------------------------------------
sub real_start_position {

=pod

=head2 real_start_position

Returns a map's start position.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    return $map->{'start_position'};
}

# ----------------------------------------------------
sub real_stop_position {

=pod

=head2 real_stop_position

Returns a map's stop position.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    return $map->{'stop_position'};
}

# ----------------------------------------------------
sub slot_no {

=pod

=head2 slot_no

Returns the slot number.

=cut

    my $self = shift;
    return $self->{'slot_no'};
}

# ----------------------------------------------------
sub map_aid {

=pod

=head2 map_aid

Returns a map's map_aid (accession)

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    return $map->{'accession_id'};
}

# ----------------------------------------------------
sub start_position {

=pod

=head2 start_position

Returns a map's start position for the range selected.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    return $map->{'start_position'};
}

# ----------------------------------------------------
sub stop_position {

=pod

=head2 stop_position

Returns a map's stop position for the range selected.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $map    = $self->map($map_id);
    return $map->{'stop_position'};
}

# ----------------------------------------------------
sub tick_mark_interval {

=pod

=head2 tick_mark_interval

Returns the map's tick mark interval.

=cut

    my $self   = shift;
    my $map_id = shift or return;
    my $pixel_height = shift or return;
    my $map    = $self->map($map_id);

    unless ( defined $map->{'tick_mark_interval'} ) {
        my $map_length =
          $self->stop_position($map_id) - $self->start_position($map_id);
        my $map_scale  = int(log(abs($map_length))/log(10)); 
        #if (int(($map_length/(10**$map_scale))+.5)>=2){
        #    push @{$map->{'tick_mark_interval'}}, (10**$map_scale, $map_scale);
        #}
        #else{
            push @{$map->{'tick_mark_interval'}}, (10**($map_scale-1),$map_scale);
        #}
    }

    return $map->{'tick_mark_interval'};
}

# ----------------------------------------------------
sub DESTROY {

=pod

=head2 DESTROY

Break cyclical links.

=cut

    my $self = shift;
    $self->{'drawer'} = undef;
}

1;

# ----------------------------------------------------
# The hours of folly are measur'd by the clock,
# but of wisdom: no clock can measure.
# William Blake
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

