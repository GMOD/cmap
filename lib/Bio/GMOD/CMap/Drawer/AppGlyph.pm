package Bio::GMOD::CMap::Drawer::AppGlyph;

# vim: set ft=perl:

=head1 NAME

Bio::GMOD::CMap::Drawer::AppGlyph - glyph drawing methods

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Drawer::AppGlyph;

=head1 DESCRIPTION

This module contains methods for drawing feature glyphs in the editor.

=head1 EXPORTED SUBROUTINES

=cut 

use strict;
use Data::Dumper;
use Bio::GMOD::CMap::Constants;
use Regexp::Common;
require Class::Base;
use vars qw( $VERSION @EXPORT @EXPORT_OK );
$VERSION = (qw$Revision: 1.1 $)[-1];

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
    my $items   = $args{'items'};
    my $x_pos2  = $args{'x_pos2'};
    my $x_pos1  = $args{'x_pos1'};
    my $y_pos1  = $args{'y_pos1'};
    my $y_pos2  = $args{'y_pos2'};
    my $color   = $args{'color'};
    my $name    = $args{'name'};
    my $feature = $args{'feature'};
    my $mid_x   = int( ( $x_pos1 + $x_pos2 ) / 2 );
    my @coords;
    push @$items,
        (
        [   1, undef, 'line',
            [ $mid_x, $y_pos1, $mid_x, $y_pos2 ],
            { -fill => $color, }
        ],
        );
    @coords = ( $x_pos2, $y_pos1, $x_pos2, $y_pos2 );

    return \@coords, $items;
}

# ------------------------------------
sub span {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $items      = $args{'items'};
    my $x_pos2     = $args{'x_pos2'};
    my $x_pos1     = $args{'x_pos1'};
    my $y_pos1     = $args{'y_pos1'};
    my $y_pos2     = $args{'y_pos2'};
    my $color      = $args{'color'};
    my $name       = $args{'name'};
    my $feature    = $args{'feature'};
    my $label_side = $args{'label_side'} || RIGHT;
    my @coords;
    my $reverse = $label_side eq RIGHT ? -1 : 1;
    my $mid_y = int( ( $y_pos1 + $y_pos2 ) / 2 );
    push @$items,
        (
        [   1, undef, 'line',
            [ $x_pos1, $mid_y, $x_pos2, $mid_y ],
            { -fill => $color, }
        ],
        [   1, undef, 'line',
            [ $x_pos1, $y_pos1, $x_pos1, $y_pos2 ],
            { -fill => $color, }
        ],
        [   1, undef, 'line',
            [ $x_pos2, $y_pos1, $x_pos2, $y_pos2 ],
            { -fill => $color, }
        ]
        );
    @coords = ( $x_pos1, $y_pos1, $x_pos2, $y_pos2 );

    return \@coords, $items;
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

Up is left in the app.

=cut

    my ( $self, %args ) = @_;
    my $items      = $args{'items'};
    my $x_pos2     = $args{'x_pos2'};
    my $x_pos1     = $args{'x_pos1'};
    my $y_pos1     = $args{'y_pos1'};
    my $y_pos2     = $args{'y_pos2'};
    my $color      = $args{'color'};
    my $name       = $args{'name'};
    my $feature    = $args{'feature'};
    my $label_side = $args{'label_side'} || RIGHT;
    my @coords;
    my $mid_y = int( ( $y_pos1 + $y_pos2 ) / 2 );
    my $arrow_head_half_width = 5;
    push @$items,
        (
        [   1, undef, 'line',
            [ $x_pos1, $mid_y, $x_pos2, $mid_y ],
            { -fill => $color, }
        ],
        [   1, undef, 'line',
            [ $x_pos1, $mid_y, $x_pos1 + $arrow_head_half_width, $y_pos1 ],
            { -fill => $color, }
        ],
        [   1, undef, 'line',
            [ $x_pos1, $mid_y, $x_pos1 + $arrow_head_half_width, $y_pos2 ],
            { -fill => $color, }
        ],
        );
    @coords = ( $x_pos1, $y_pos1, $x_pos2, $y_pos2 );

    return \@coords, $items;
}

# ------------------------------------
sub down_arrow {

=pod

=head2

Down is right in the app

=cut

    my ( $self, %args ) = @_;
    my $items      = $args{'items'};
    my $x_pos2     = $args{'x_pos2'};
    my $x_pos1     = $args{'x_pos1'};
    my $y_pos1     = $args{'y_pos1'};
    my $y_pos2     = $args{'y_pos2'};
    my $color      = $args{'color'};
    my $name       = $args{'name'};
    my $feature    = $args{'feature'};
    my $label_side = $args{'label_side'} || RIGHT;
    my @coords;
    my $arrow_head_half_width = 5;
    my $mid_y = int( ( $y_pos1 + $y_pos2 ) / 2 );
    push @$items,
        (
        [   1, undef, 'line',
            [ $x_pos1, $mid_y, $x_pos2, $mid_y ],
            { -fill => $color, }
        ],
        [   1, undef, 'line',
            [ $x_pos2, $mid_y, $x_pos2 - $arrow_head_half_width, $y_pos1 ],
            { -fill => $color, }
        ],
        [   1, undef, 'line',
            [ $x_pos2, $mid_y, $x_pos2 - $arrow_head_half_width, $y_pos2 ],
            { -fill => $color, }
        ],
        );
    @coords = ( $x_pos1, $y_pos1, $x_pos2, $y_pos2 );

    return \@coords, $items;
}

# ------------------------------------
sub right_facing_arrow {

=pod

=head2

This is going to point up in the app

=cut

    my ( $self, %args ) = @_;
    my $items      = $args{'items'};
    my $x_pos2     = $args{'x_pos2'};
    my $x_pos1     = $args{'x_pos1'};
    my $y_pos1     = $args{'y_pos1'};
    my $y_pos2     = $args{'y_pos2'};
    my $color      = $args{'color'};
    my $name       = $args{'name'};
    my $feature    = $args{'feature'};
    my $label_side = $args{'label_side'} || RIGHT;
    my @coords;
    my $arrow_head_half_width = 4;
    my $mid_x = int( ( $x_pos1 + $x_pos2 ) / 2 );
    push @$items,
        (
        [   1, undef, 'line',
            [ $mid_x, $y_pos1, $mid_x, $y_pos2 ],
            { -fill => $color, }
        ],
        [   1, undef, 'line',
            [   $mid_x - $arrow_head_half_width,
                $y_pos1 + $arrow_head_half_width,
                $mid_x,
                $y_pos1
            ],
            { -fill => $color, }
        ],
        [   1, undef, 'line',
            [   $mid_x + $arrow_head_half_width,
                $y_pos1 + $arrow_head_half_width,
                $mid_x,
                $y_pos1
            ],
            { -fill => $color, }
        ],
        );
    @coords = (
        $mid_x - $arrow_head_half_width, $y_pos1,
        $mid_x + $arrow_head_half_width, $y_pos2
    );

    return \@coords, $items;
}

# ------------------------------------
sub double_arrow {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $items      = $args{'items'};
    my $x_pos2     = $args{'x_pos2'};
    my $x_pos1     = $args{'x_pos1'};
    my $y_pos1     = $args{'y_pos1'};
    my $y_pos2     = $args{'y_pos2'};
    my $color      = $args{'color'};
    my $name       = $args{'name'};
    my $feature    = $args{'feature'};
    my $label_side = $args{'label_side'} || RIGHT;
    my @coords;
    my $arrow_head_half_width = 5;
    my $mid_y = int( ( $y_pos1 + $y_pos2 ) / 2 );
    push @$items,
        (
        [   1, undef, 'line',
            [ $x_pos1, $mid_y, $x_pos2, $mid_y ],
            { -fill => $color, }
        ],
        [   1, undef, 'line',
            [ $x_pos2, $mid_y, $x_pos2 - $arrow_head_half_width, $y_pos1 ],
            { -fill => $color, }
        ],
        [   1, undef, 'line',
            [ $x_pos2, $mid_y, $x_pos2 - $arrow_head_half_width, $y_pos2 ],
            { -fill => $color, }
        ],
        [   1, undef, 'line',
            [ $x_pos1, $mid_y, $x_pos1 + $arrow_head_half_width, $y_pos1 ],
            { -fill => $color, }
        ],
        [   1, undef, 'line',
            [ $x_pos1, $mid_y, $x_pos1 + $arrow_head_half_width, $y_pos2 ],
            { -fill => $color, }
        ],
        );
    @coords = ( $x_pos1, $y_pos1, $x_pos2, $y_pos2 );

    return \@coords, $items;
}

# ------------------------------------
sub dumbbell {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $items            = $args{'items'};
    my $x_pos2           = $args{'x_pos2'};
    my $x_pos1           = $args{'x_pos1'};
    my $y_pos1           = $args{'y_pos1'};
    my $y_pos2           = $args{'y_pos2'};
    my $color            = $args{'color'};
    my $name             = $args{'name'};
    my $feature          = $args{'feature'};
    my $app_display_data = $args{'app_display_data'};
    my $feature_type_acc = $args{'feature_type_acc'};
    my @coords;

    my $mid_y = int( ( $y_pos1 + $y_pos2 ) / 2 );
    my $height = $y_pos2 - $y_pos1;
    push @$items, (
        [   1, undef, 'line',
            [ $x_pos1, $mid_y, $x_pos2, $mid_y ],
            { -fill => $color, }
        ],

        [   1, undef, 'oval',
            [ $x_pos1, $y_pos1, $x_pos1 + $height, $y_pos2, ],
            { -fill => $color, -outline => $color }
        ],
        [   1, undef, 'oval',
            [ $x_pos2 - $height, $y_pos1, $x_pos2, $y_pos2, ],
            { -fill => $color, -outline => $color }
        ],
    );

    @coords = ( $x_pos1, $y_pos1, $x_pos2, $y_pos2 );

    return \@coords, $items;
}

# ------------------------------------
sub i_beam {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $items            = $args{'items'};
    my $x_pos2           = $args{'x_pos2'};
    my $x_pos1           = $args{'x_pos1'};
    my $y_pos1           = $args{'y_pos1'};
    my $y_pos2           = $args{'y_pos2'};
    my $color            = $args{'color'};
    my $name             = $args{'name'};
    my $feature          = $args{'feature'};
    my $app_display_data = $args{'app_display_data'};
    my $feature_type_acc = $args{'feature_type_acc'};
    my @coords;

    my $mid_y = int( ( $y_pos1 + $y_pos2 ) / 2 );
    my $height = $y_pos2 - $y_pos1;
    push @$items,
        (
        [   1, undef, 'line',
            [ $x_pos1, $mid_y, $x_pos2, $mid_y ],
            { -fill => $color, }
        ],
        [   1, undef, 'line',
            [ $x_pos1, $y_pos1, $x_pos1, $y_pos2 ],
            { -fill => $color, }
        ],
        [   1, undef, 'line',
            [ $x_pos2, $y_pos1, $x_pos2, $y_pos2 ],
            { -fill => $color, }
        ],
        );

    @coords = ( $x_pos1, $y_pos1, $x_pos2, $y_pos2 );

    return \@coords, $items;
}

# ------------------------------------
sub box {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $items      = $args{'items'};
    my $x_pos2     = $args{'x_pos2'};
    my $x_pos1     = $args{'x_pos1'};
    my $y_pos1     = $args{'y_pos1'};
    my $y_pos2     = $args{'y_pos2'};
    my $color      = $args{'color'};
    my $name       = $args{'name'};
    my $feature    = $args{'feature'};
    my $label_side = $args{'label_side'} || RIGHT;
    my @coords;

    @coords = ( $x_pos1, $y_pos2, $x_pos2, $y_pos1, );
    push @$items,
        (
        [   1, undef, 'rectangle',
            [ $x_pos1, $y_pos1, $x_pos2, $y_pos2 ],
            { -outline => $color, }
        ],
        );

    return \@coords, $items;
}

# ------------------------------------
sub filled_box {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $items      = $args{'items'};
    my $x_pos2     = $args{'x_pos2'};
    my $x_pos1     = $args{'x_pos1'};
    my $y_pos1     = $args{'y_pos1'};
    my $y_pos2     = $args{'y_pos2'};
    my $color      = $args{'color'};
    my $name       = $args{'name'};
    my $feature    = $args{'feature'};
    my $label_side = $args{'label_side'} || RIGHT;
    my @coords;

    @coords = ( $x_pos1, $y_pos2, $x_pos2, $y_pos1, );
    push @$items,
        (
        [   1, undef, 'rectangle',
            [ $x_pos1, $y_pos1, $x_pos2, $y_pos2 ],
            { -fill => $color, -outline => 'black', }
        ],
        );

    return \@coords, $items;
}

# ------------------------------------
sub banding {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $items            = $args{'items'};
    my $x_pos2           = $args{'x_pos2'};
    my $x_pos1           = $args{'x_pos1'};
    my $y_pos1           = $args{'y_pos1'};
    my $y_pos2           = $args{'y_pos2'};
    my $color1           = $args{'color'} || 'red';
    my $name             = $args{'name'};
    my $feature          = $args{'feature'};
    my $app_display_data = $args{'app_display_data'};
    my $drawer           = $args{'drawer'};
    my $label_side       = $args{'label_side'} || RIGHT;
    my $feature_type_acc = $args{'feature_type_acc'};
    my @coords;
    my $color2
        = $app_display_data->feature_type_data( $feature_type_acc, 'color2' )
        || 'black';
    my $oscillating_color_key = 'oscillating_color_' . $feature_type_acc;
    my $color = $app_display_data->{$oscillating_color_key} || $color1;

    if ( $app_display_data->{$oscillating_color_key} eq $color2 ) {
        $app_display_data->{$oscillating_color_key} = $color1;
    }
    else {
        $app_display_data->{$oscillating_color_key} = $color2;
    }
    push @$items,
        (
        [   1, undef, 'rectangle',
            [ $x_pos1, $y_pos1, $x_pos2, $y_pos2 ],
            { -fill => $color, -outline => $color, }
        ],
        );
    @coords = ( $x_pos1, $y_pos1, $x_pos2, $y_pos2 );

    return \@coords, $items;
}

# ------------------------------------
sub bar {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $items            = $args{'items'};
    my $x_pos2           = $args{'x_pos2'};
    my $x_pos1           = $args{'x_pos1'};
    my $y_pos1           = $args{'y_pos1'};
    my $y_pos2           = $args{'y_pos2'};
    my $color            = $args{'color'} || 'red';
    my $name             = $args{'name'};
    my $feature          = $args{'feature'};
    my $app_display_data = $args{'app_display_data'};
    my $label_side       = $args{'label_side'} || RIGHT;
    my @coords;

    push @$items,
        (
        [   1, undef, 'rectangle',
            [ $x_pos1, $y_pos1, $x_pos2, $y_pos2 ],
            { -fill => $color, -outline => $color, }
        ],
        );
    @coords = ( $x_pos1, $y_pos1, $x_pos2, $y_pos2 );

    return \@coords, $items;
}

# ------------------------------------
sub in_triangle {
    my ( $self, %args ) = @_;

    return $self->left_facing_triangle(%args);
}

# ------------------------------------
sub out_triangle {
    my ( $self, %args ) = @_;

    return $self->right_facing_triangle(%args);
}

# ------------------------------------
sub left_facing_triangle {

=pod

=head2

Left is up in the app.

=cut

    my ( $self, %args ) = @_;
    my $items      = $args{'items'};
    my $x_pos2     = $args{'x_pos2'};
    my $x_pos1     = $args{'x_pos1'};
    my $y_pos1     = $args{'y_pos1'};
    my $y_pos2     = $args{'y_pos2'};
    my $color      = $args{'color'};
    my $name       = $args{'name'};
    my $feature    = $args{'feature'};
    my $label_side = $args{'label_side'} || RIGHT;
    my @coords;

    my $width = int( ( $y_pos2 - $y_pos1 ) * 0.5 );
    my $mid_x = int( ( $x_pos1 + $x_pos2 ) / 2 );

    push @$items,
        (
        [   1, undef,
            'polygon',
            [   $mid_x - $width, $y_pos2, $mid_x + $width,
                $y_pos2,         $mid_x,  $y_pos1,
            ],
            { -fill => $color, }
        ],
        );

    @coords = ( $mid_x - $width, $y_pos1, $mid_x + $width, $y_pos2, );

    return \@coords, $items;
}

# ------------------------------------
sub right_facing_triangle {

=pod

=head2 

Right is down in the app.

=cut

    my ( $self, %args ) = @_;
    my $items      = $args{'items'};
    my $x_pos2     = $args{'x_pos2'};
    my $x_pos1     = $args{'x_pos1'};
    my $y_pos1     = $args{'y_pos1'};
    my $y_pos2     = $args{'y_pos2'};
    my $color      = $args{'color'};
    my $name       = $args{'name'};
    my $feature    = $args{'feature'};
    my $label_side = $args{'label_side'} || RIGHT;
    my @coords;

    my $width = int( ( $y_pos2 - $y_pos1 ) * 0.5 );
    my $mid_x = int( ( $x_pos1 + $x_pos2 ) / 2 );

    push @$items,
        (
        [   1, undef,
            'polygon',
            [   $mid_x - $width, $y_pos1, $mid_x + $width,
                $y_pos1,         $mid_x,  $y_pos2,
            ],
            { -fill => $color, }
        ],
        );

    @coords = ( $mid_x - $width, $y_pos1, $mid_x + $width, $y_pos2, );

    return \@coords, $items;
}

# ------------------------------------
sub read_depth {

    #NOT UPDATED

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $items      = $args{'items'};
    my $x_pos2     = $args{'x_pos2'};
    my $x_pos1     = $args{'x_pos1'};
    my $y_pos1     = $args{'y_pos1'};
    my $y_pos2     = $args{'y_pos2'};
    my $color      = $args{'color'};
    my $name       = $args{'name'};
    my $feature    = $args{'feature'};
    my $label_side = $args{'label_side'} || RIGHT;
    my @coords;
    my $reverse = $label_side eq RIGHT ? 1 : -1;

    if ( $name =~ /^$RE{'num'}{'real'}$/ ) {
        $x_pos2 = $x_pos1 + ( $name * $reverse );
    }
    else {
        $x_pos2 = $x_pos1;
    }
    $x_pos2 += ( 3 * $reverse );
    push @$items, [ LINE, $x_pos2, $y_pos1, $x_pos2, $y_pos2, $color, ];

    if ( $reverse > 0 ) {
        @coords = ( $x_pos1, $y_pos1, $x_pos2, $y_pos2 );
    }
    else {
        @coords = ( $x_pos2, $y_pos1, $x_pos1, $y_pos2 );
    }

    return \@coords, $items;
}

# ------------------------------------
sub heatmap {

=pod

=head2



=cut

    my ( $self, %args ) = @_;
    my $items            = $args{'items'};
    my $x_pos2           = $args{'x_pos2'};
    my $x_pos1           = $args{'x_pos1'};
    my $y_pos1           = $args{'y_pos1'};
    my $y_pos2           = $args{'y_pos2'};
    my $color            = $args{'color'};
    my $name             = $args{'name'};
    my $feature          = $args{'feature'};
    my $app_display_data = $args{'app_display_data'};
    my $label_side       = $args{'label_side'} || RIGHT;
    my $feature_type_acc = $args{'feature_type_acc'};
    my @coords;

    # Get feature type values
    my ( $top_value, $bot_value, $top_color_array, $bot_color_array, );
    unless ( $top_value
        = $app_display_data->{ 'hm_top_val_' . $feature_type_acc } )
    {
        $top_value = $app_display_data->feature_type_data( $feature_type_acc,
            'max_value' )
            || 100;
        $app_display_data->{ 'hm_top_val_' . $feature_type_acc } = $top_value;
    }
    unless ( $bot_value
        = $app_display_data->{ 'hm_bot_val_' . $feature_type_acc } )
    {
        $bot_value = $app_display_data->feature_type_data( $feature_type_acc,
            'min_value' )
            || 0;
        $app_display_data->{ 'hm_bot_val_' . $feature_type_acc } = $bot_value;
    }

    my $value = defined($name) ? $name : $bot_value;

    unless ( $value =~ /^$RE{'num'}{'real'}$/ ) {
        $value = $bot_value;
    }

    unless ( $top_color_array
        = $app_display_data->{ 'hm_top_color_' . $feature_type_acc } )
    {
        $top_color_array = [
            split /\s*,\s*/,
            $app_display_data->feature_type_data( $feature_type_acc,
                'max_color_value' )
                || '0,255,0'
        ];
        $app_display_data->{ 'hm_top_color_' . $feature_type_acc }
            = $top_color_array;
    }
    unless ( $bot_color_array
        = $app_display_data->{ 'hm_bot_color_' . $feature_type_acc } )
    {
        $bot_color_array = [
            split /\s*,\s*/,
            $app_display_data->feature_type_data( $feature_type_acc,
                'min_color_value' )
                || '255,0,0'
        ];
        $app_display_data->{ 'hm_bot_color_' . $feature_type_acc }
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

    $color = sprintf( "#%02x%02x%02x", $r_color, $g_color, $b_color, );

    push @$items,
        (
        [   1, undef, 'rectangle',
            [ $x_pos1, $y_pos1, $x_pos2, $y_pos2 ],
            { -fill => $color, -outline => $color, }
        ],
        );
    @coords = ( $x_pos2, $y_pos1, $x_pos1, $y_pos2 );

    return \@coords, $items;
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

