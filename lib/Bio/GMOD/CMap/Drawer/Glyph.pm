package Bio::GMOD::CMap::Drawer::Glyph;

# vim: set ft=perl:

=head1 NAME

Bio::GMOD::CMap::Drawer::Glyph - glyph drawing methods

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Drawer::Glyph;

=head1 DESCRIPTION

This module contains methods for drawing glyphs.

=head1 EXPORTED SUBROUTINES

=cut 

use strict;
use Data::Dumper;
use Bio::GMOD::CMap::Constants;
use Regexp::Common;
require Class::Base;
use vars qw( $VERSION @EXPORT @EXPORT_OK );
$VERSION = (qw$Revision: 1.14 $)[-1];

use base 'Class::Base';

use constant GLYPHS_THAT_CAN_OVERLAP => {
    read_depth => 1,
    heatmap    => 1,
    banding    => 1,
};

# -----------------------------------
sub allow_glyph_overlap {

=pod

=head2 allow_glyph_overlap

Boolean that returns whether or not this glyph is allowed to overlap.

=cut

    my ( $self, $glyph_name ) = @_;

    return GLYPHS_THAT_CAN_OVERLAP->{$glyph_name};
}

# ------------------------------------
sub line {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $x_pos2       = $args{'x_pos2'};
    my $x_pos1       = $args{'x_pos1'};
    my $y_pos1       = $args{'y_pos1'};
    my $y_pos2       = $args{'y_pos2'};
    my $color        = $args{'color'};
    my $name         = $args{'name'};
    my $feature      = $args{'feature'};
    my $label_side   = $args{'label_side'} || RIGHT;
    my @coords;
    my $reverse = $label_side eq RIGHT ? -1 : 1;
    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos1, $x_pos2, $y_pos2, $color, ];
    @coords = ( $x_pos2, $y_pos1, $x_pos2, $y_pos2 );

    return \@coords;
}

# ------------------------------------
sub span {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $x_pos2       = $args{'x_pos2'};
    my $x_pos1       = $args{'x_pos1'};
    my $y_pos1       = $args{'y_pos1'};
    my $y_pos2       = $args{'y_pos2'};
    my $color        = $args{'color'};
    my $name         = $args{'name'};
    my $feature      = $args{'feature'};
    my $label_side   = $args{'label_side'} || RIGHT;
    my @coords;
    my $reverse = $label_side eq RIGHT ? -1 : 1;
    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos1, $x_pos2, $y_pos2, $color, ];

    push @$drawing_data,
        [
        LINE, $x_pos2,
        $y_pos1, $x_pos2 + ( 3 * $reverse ),
        $y_pos1, $color,
        ];

    push @$drawing_data,
        [
        LINE, $x_pos2,
        $y_pos2, $x_pos2 + ( 3 * $reverse ),
        $y_pos2, $color,
        ];

    if ( $reverse > 0 ) {
        @coords = ( $x_pos2, $y_pos1, $x_pos2 + 3, $y_pos2 );
    }
    else {
        @coords = ( $x_pos2 - 3, $y_pos1, $x_pos2, $y_pos2 );
    }

    return \@coords;
}

# ------------------------------------
sub direction_arrow {
    my ( $self, %args ) = @_;
    my $dir        = $args{'direction'}  || 0;
    my $is_flipped = $args{'is_flipped'} || 0;

    unless ($dir) {
        return $self->right_facing_arrow(%args);
    }
    if (   ( $dir > 0 and not $is_flipped )
        or ( $dir < 0 and $is_flipped ) )
    {
        return $self->down_arrow(%args);
    }
    else {
        return $self->up_arrow(%args);
    }
}

# ------------------------------------
sub up_arrow {

=pod

=head2


=cut

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $x_pos2       = $args{'x_pos2'};
    my $x_pos1       = $args{'x_pos1'};
    my $y_pos1       = $args{'y_pos1'};
    my $y_pos2       = $args{'y_pos2'};
    my $color        = $args{'color'};
    my $name         = $args{'name'};
    my $feature      = $args{'feature'};
    my $label_side   = $args{'label_side'} || RIGHT;
    my @coords;
    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos1, $x_pos2, $y_pos2, $color, ];
    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos1, $x_pos2 - 2, $y_pos1 + 2, $color ];

    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos1, $x_pos2 + 2, $y_pos1 + 2, $color ];

    @coords = ( $x_pos2 - 2, $y_pos2, $x_pos2 + 2, $y_pos1, );

    return \@coords;
}

# ------------------------------------
sub down_arrow {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $x_pos2       = $args{'x_pos2'};
    my $x_pos1       = $args{'x_pos1'};
    my $y_pos1       = $args{'y_pos1'};
    my $y_pos2       = $args{'y_pos2'};
    my $color        = $args{'color'};
    my $name         = $args{'name'};
    my $feature      = $args{'feature'};
    my $label_side   = $args{'label_side'} || RIGHT;
    my @coords;
    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos1, $x_pos2, $y_pos2, $color, ];
    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos2, $x_pos2 - 2, $y_pos2 - 2, $color ];

    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos2, $x_pos2 + 2, $y_pos2 - 2, $color ];

    @coords = ( $x_pos2 - 2, $y_pos2, $x_pos2 + 2, $y_pos1, );

    return \@coords;
}

# ------------------------------------
sub right_facing_arrow {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $x_pos2       = $args{'x_pos2'};
    my $x_pos1       = $args{'x_pos1'};
    my $y_pos1       = $args{'y_pos1'};
    my $y_pos2       = $args{'y_pos2'};
    my $color        = $args{'color'};
    my $name         = $args{'name'};
    my $feature      = $args{'feature'};
    my $label_side   = $args{'label_side'} || RIGHT;
    my @coords;

    my $height = $y_pos2 - $y_pos1;
    my $mid_y = $y_pos1 + ( $height / 2 );
    push @$drawing_data, [ LINE, $x_pos1, $mid_y, $x_pos2, $mid_y, $color ];
    push @$drawing_data,
        [ LINE, $x_pos2 - 2, $mid_y - 2, $x_pos2, $mid_y, $color ];
    push @$drawing_data,
        [ LINE, $x_pos2 - 2, $mid_y + 2, $x_pos2, $mid_y, $color ];

    @coords = ( $x_pos2, $mid_y + 2, $x_pos2, $mid_y + 2, );

    return \@coords;
}

# ------------------------------------
sub double_arrow {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $x_pos2       = $args{'x_pos2'};
    my $x_pos1       = $args{'x_pos1'};
    my $y_pos1       = $args{'y_pos1'};
    my $y_pos2       = $args{'y_pos2'};
    my $color        = $args{'color'};
    my $name         = $args{'name'};
    my $feature      = $args{'feature'};
    my $label_side   = $args{'label_side'} || RIGHT;

    # my $= $args{''};
    my @coords;
    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos1, $x_pos2, $y_pos2, $color, ];
    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos1, $x_pos2 - 2, $y_pos1 + 2, $color ];
    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos1, $x_pos2 + 2, $y_pos1 + 2, $color ];
    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos2, $x_pos2 - 2, $y_pos2 - 2, $color ];
    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos2, $x_pos2 + 2, $y_pos2 - 2, $color ];

    @coords = ( $x_pos2 - 2, $y_pos2, $x_pos2 + 2, $y_pos1, );

    return \@coords;
}

# ------------------------------------
sub dumbbell {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $x_pos2       = $args{'x_pos2'};
    my $x_pos1       = $args{'x_pos1'};
    my $y_pos1       = $args{'y_pos1'};
    my $y_pos2       = $args{'y_pos2'};
    my $color        = $args{'color'};
    my $name         = $args{'name'};
    my $feature      = $args{'feature'};
    my @coords;
    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos1, $x_pos2, $y_pos2, $color, ];
    my $width = $feature->{'width'} || 4;

    unless ( $y_pos1 == $y_pos2 ) {
        $y_pos1 += 2;
        $y_pos2 -= 2;
    }

    push @$drawing_data,
        [ ARC, $x_pos2, $y_pos1, $width, $width, 0, 360, $color ];
    push @$drawing_data, [ FILL, $x_pos2 + 1, $y_pos1 + 1, $color ];
    push @$drawing_data,
        [ ARC, $x_pos2, $y_pos2, $width, $width, 0, 360, $color ];
    push @$drawing_data, [ FILL, $x_pos2 + 1, $y_pos2 + 1, $color ];

    @coords
        = ( $x_pos2 - $width / 2, $y_pos1, $x_pos2 + $width / 2, $y_pos2 );

    return \@coords;
}

# ------------------------------------
sub i_beam {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $x_pos2       = $args{'x_pos2'};
    my $x_pos1       = $args{'x_pos1'};
    my $y_pos1       = $args{'y_pos1'};
    my $y_pos2       = $args{'y_pos2'};
    my $color        = $args{'color'};
    my $name         = $args{'name'};
    my $feature      = $args{'feature'};
    my @coords;
    my $width = $feature->{'width'} || 4;

    my $half_width = $width / 2;
    push @$drawing_data,
        [
        LINE,                  $x_pos2 + $half_width, $y_pos1,
        $x_pos2 + $half_width, $y_pos2,               $color,
        ];

    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos1, $x_pos2 + $width, $y_pos1, $color ];
    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos2, $x_pos2 + $width, $y_pos2, $color ];

    @coords = ( $x_pos2, $y_pos1, $x_pos2 + $width, $y_pos2 );

    return \@coords;
}

# ------------------------------------
sub box {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $x_pos2       = $args{'x_pos2'};
    my $x_pos1       = $args{'x_pos1'};
    my $y_pos1       = $args{'y_pos1'};
    my $y_pos2       = $args{'y_pos2'};
    my $color        = $args{'color'};
    my $name         = $args{'name'};
    my $feature      = $args{'feature'};
    my $label_side   = $args{'label_side'} || RIGHT;
    my @coords;

    @coords = ( $x_pos1, $y_pos2, $x_pos2, $y_pos1, );
    push @$drawing_data, [ RECTANGLE, @coords, $color ];

    return \@coords;
}

# ------------------------------------
sub filled_box {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $x_pos2       = $args{'x_pos2'};
    my $x_pos1       = $args{'x_pos1'};
    my $y_pos1       = $args{'y_pos1'};
    my $y_pos2       = $args{'y_pos2'};
    my $color        = $args{'color'};
    my $name         = $args{'name'};
    my $feature      = $args{'feature'};
    my $label_side   = $args{'label_side'} || RIGHT;
    my @coords;
    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos1, $x_pos2, $y_pos2, $color, ];
    my $width = $feature->{'width'} || 3;
    push @$drawing_data,
        [ FILLED_RECT, $x_pos2, $y_pos1, $x_pos2 + $width, $y_pos2, $color, ];
    push @$drawing_data,
        [ RECTANGLE, $x_pos2, $y_pos1, $x_pos2 + $width, $y_pos2, 'black', ];
    @coords
        = ( $x_pos2 - $width / 2, $y_pos1, $x_pos2 + $width / 2, $y_pos2 );

    return \@coords;
}

# ------------------------------------
sub banding {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $drawing_data     = $args{'drawing_data'};
    my $x_pos2           = $args{'x_pos2'};
    my $x_pos1           = $args{'x_pos1'};
    my $y_pos1           = $args{'y_pos1'};
    my $y_pos2           = $args{'y_pos2'};
    my $color1           = $args{'color'} || 'red';
    my $name             = $args{'name'};
    my $feature          = $args{'feature'};
    my $calling_obj      = $args{'calling_obj'};
    my $drawer           = $args{'drawer'};
    my $label_side       = $args{'label_side'} || RIGHT;
    my $feature_type_acc = $args{'feature_type_acc'};
    my @coords;
    my $color2
        = $calling_obj->feature_type_data( $feature_type_acc, 'color2' )
        || 'black';
    my $oscillating_color_key = 'oscillating_color_' . $feature_type_acc;
    my $color = $calling_obj->{$oscillating_color_key} || $color1;

    if ( $calling_obj->{$oscillating_color_key} eq $color2 ) {
        $calling_obj->{$oscillating_color_key} = $color1;
    }
    else {
        $calling_obj->{$oscillating_color_key} = $color2;
    }
    my $width = $feature->{'width'} || 3;
    push @$drawing_data,
        [ FILLED_RECT, $x_pos2, $y_pos1, $x_pos2 + $width, $y_pos2, $color, ];
    @coords = ( $x_pos2, $y_pos1, $x_pos2 + $width, $y_pos2 );

    return \@coords;
}

# ------------------------------------
sub bar {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $x_pos2       = $args{'x_pos2'};
    my $x_pos1       = $args{'x_pos1'};
    my $y_pos1       = $args{'y_pos1'};
    my $y_pos2       = $args{'y_pos2'};
    my $color        = $args{'color'} || 'red';
    my $name         = $args{'name'};
    my $feature      = $args{'feature'};
    my $calling_obj  = $args{'calling_obj'};
    my $label_side   = $args{'label_side'} || RIGHT;
    my @coords;

    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos1, $x_pos2, $y_pos2, $color, ];
    my $width = $feature->{'width'} || 3;
    push @$drawing_data,
        [ FILLED_RECT, $x_pos2, $y_pos1, $x_pos2 + $width, $y_pos2, $color, ];
    @coords
        = ( $x_pos2 - $width / 2, $y_pos1, $x_pos2 + $width / 2, $y_pos2 );

    return \@coords;
}

# ------------------------------------
sub in_triangle {
    my ( $self, %args ) = @_;
    my $label_side = $args{'label_side'} || RIGHT;

    if ( $label_side eq LEFT ) {
        return $self->right_facing_triangle(%args);
    }
    else {
        return $self->left_facing_triangle(%args);
    }
}

# ------------------------------------
sub out_triangle {
    my ( $self, %args ) = @_;
    my $label_side = $args{'label_side'} || RIGHT;

    if ( $label_side eq RIGHT ) {
        return $self->right_facing_triangle(%args);
    }
    else {
        return $self->left_facing_triangle(%args);
    }
}

# ------------------------------------
sub right_facing_triangle {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $x_pos2       = $args{'x_pos2'};
    my $x_pos1       = $args{'x_pos1'};
    my $y_pos1       = $args{'y_pos1'};
    my $y_pos2       = $args{'y_pos2'};
    my $color        = $args{'color'};
    my $name         = $args{'name'};
    my $feature      = $args{'feature'};
    my $label_side   = $args{'label_side'} || RIGHT;
    my @coords;

    my $width  = 3;
    my $height = $y_pos2 - $y_pos1;
    my $mid_y  = $y_pos1 + ( $height / 2 );

    push @$drawing_data,
        [ LINE, $x_pos2, $mid_y - $width, $x_pos2, $mid_y + $width, $color ];
    push @$drawing_data,
        [ LINE, $x_pos2, $mid_y - $width, $x_pos2 + $width, $mid_y, $color ];
    push @$drawing_data,
        [ LINE, $x_pos2, $mid_y + $width, $x_pos2 + $width, $mid_y, $color ];
    push @$drawing_data, [ FILL, $x_pos2 + 1, $mid_y + 1, $color ];

    @coords = (
        $x_pos2 - $width,
        $mid_y - $width,
        $x_pos2 + $width,
        $mid_y + $width,
    );

    return \@coords;
}

# ------------------------------------
sub left_facing_triangle {

=pod
                                                                                =head2 


=cut

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $x_pos2       = $args{'x_pos2'};
    my $x_pos1       = $args{'x_pos1'};
    my $y_pos1       = $args{'y_pos1'};
    my $y_pos2       = $args{'y_pos2'};
    my $color        = $args{'color'};
    my $name         = $args{'name'};
    my $feature      = $args{'feature'};
    my $label_side   = $args{'label_side'} || RIGHT;
    my @coords;

    my $width  = 3;
    my $height = $y_pos2 - $y_pos1;
    my $mid_y  = $y_pos1 + ( $height / 2 );

    push @$drawing_data,
        [
        LINE,
        $x_pos2 + $width,
        $mid_y - $width,
        $x_pos2 + $width,
        $mid_y + $width,
        $color
        ];
    push @$drawing_data,
        [ LINE, $x_pos2 + $width, $mid_y - $width, $x_pos2, $mid_y, $color ];
    push @$drawing_data,
        [ LINE, $x_pos2, $mid_y, $x_pos2 + $width, $mid_y + $width, $color ];
    push @$drawing_data, [ FILL, $x_pos2 + $width - 1, $mid_y + 1, $color ];

    @coords = (
        $x_pos2 - $width,
        $mid_y - $width,
        $x_pos2 + $width,
        $mid_y + $width,
    );

    return \@coords;
}

# ------------------------------------
sub read_depth {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $drawing_data = $args{'drawing_data'};
    my $x_pos2       = $args{'x_pos2'};
    my $x_pos1       = $args{'x_pos1'};
    my $y_pos1       = $args{'y_pos1'};
    my $y_pos2       = $args{'y_pos2'};
    my $color        = $args{'color'};
    my $name         = $args{'name'};
    my $feature      = $args{'feature'};
    my $label_side   = $args{'label_side'} || RIGHT;
    my @coords;
    my $reverse = $label_side eq RIGHT ? 1 : -1;

    if ( $name =~ /^$RE{'num'}{'real'}$/ ) {
        $x_pos2 = $x_pos1 + ( $name * $reverse );
    }
    else {
        $x_pos2 = $x_pos1;
    }
    $x_pos2 += ( 3 * $reverse );
    push @$drawing_data,
        [ LINE, $x_pos2, $y_pos1, $x_pos2, $y_pos2, $color, ];

    if ( $reverse > 0 ) {
        @coords = ( $x_pos1, $y_pos1, $x_pos2, $y_pos2 );
    }
    else {
        @coords = ( $x_pos2, $y_pos1, $x_pos1, $y_pos2 );
    }

    return \@coords;
}

# ------------------------------------
sub heatmap {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $drawing_data     = $args{'drawing_data'};
    my $x_pos2           = $args{'x_pos2'};
    my $x_pos1           = $args{'x_pos1'};
    my $y_pos1           = $args{'y_pos1'};
    my $y_pos2           = $args{'y_pos2'};
    my $color            = $args{'color'};
    my $name             = $args{'name'};
    my $feature          = $args{'feature'};
    my $calling_obj      = $args{'calling_obj'};
    my $label_side       = $args{'label_side'} || RIGHT;
    my $drawer           = $args{'drawer'};
    my $feature_type_acc = $args{'feature_type_acc'};
    my @coords;

    # Get feature type values
    my ( $top_value, $bot_value, $top_color_array, $bot_color_array, );
    unless ( $top_value
        = $calling_obj->{ 'hm_top_val_' . $feature_type_acc } )
    {
        $top_value = $calling_obj->feature_type_data( $feature_type_acc,
            'max_value' )
            || 100;
        $calling_obj->{ 'hm_top_val_' . $feature_type_acc } = $top_value;
    }
    unless ( $bot_value
        = $calling_obj->{ 'hm_bot_val_' . $feature_type_acc } )
    {
        $bot_value = $calling_obj->feature_type_data( $feature_type_acc,
            'min_value' )
            || 0;
        $calling_obj->{ 'hm_bot_val_' . $feature_type_acc } = $bot_value;
    }

    my $value = defined($name) ? $name : $bot_value;

    unless ( $value =~ /^$RE{'num'}{'real'}$/ ) {
        $value = $bot_value;
    }

    unless ( $top_color_array
        = $calling_obj->{ 'hm_top_color_' . $feature_type_acc } )
    {
        $top_color_array = [
            split /\s*,\s*/,
            $calling_obj->feature_type_data( $feature_type_acc,
                'max_color_value' )
                || '0,255,0'
        ];
        $calling_obj->{ 'hm_top_color_' . $feature_type_acc }
            = $top_color_array;
    }
    unless ( $bot_color_array
        = $calling_obj->{ 'hm_bot_color_' . $feature_type_acc } )
    {
        $bot_color_array = [
            split /\s*,\s*/,
            $calling_obj->feature_type_data( $feature_type_acc,
                'min_color_value' )
                || '255,0,0'
        ];
        $calling_obj->{ 'hm_bot_color_' . $feature_type_acc }
            = $bot_color_array;
    }

    # Do Color Math
    my $value_fraction
        = ( $value - $bot_value + 1 ) / ( $top_value - $bot_value + 1 );
    if ( $value_fraction < 0 ) {
        $value_fraction = 0;
    }
    elsif ( $value_fraction > 1 ) {
        $value_fraction = 1;
    }

    my $r_color
        = $value_fraction * ( $top_color_array->[0] - $bot_color_array->[0] )
        + $bot_color_array->[0];
    my $g_color
        = $value_fraction * ( $top_color_array->[1] - $bot_color_array->[1] )
        + $bot_color_array->[1];
    my $b_color
        = $value_fraction * ( $top_color_array->[2] - $bot_color_array->[2] )
        + $bot_color_array->[2];

    my $color
        = $drawer->define_color( [ $r_color, $g_color, $b_color ] );

    my $width = $feature->{'width'} || 3;
    push @$drawing_data,
        [ FILLED_RECT, $x_pos2, $y_pos1, $x_pos2 + $width, $y_pos2, $color, ];
    @coords = ( $x_pos2, $y_pos1, $x_pos2 + $width, $y_pos2 );

    return \@coords;
}

1;

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2004 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

