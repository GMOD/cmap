package Bio::GMOD::CMap::Drawer::GDWrapper;

# Based on Bio::Graphics::GDWrapper by Lincoln Stein

use base 'GD::Image';
use Memoize 'memoize';
use Carp 'cluck';
memoize('_match_font');

my $DefaultFont;
my $GdInit;

sub new {
    my $self = shift;
    my ($gd,$default_font) = @_;
    $DefaultFont = $default_font unless $default_font eq '1';
    $gd->useFontConfig(1);
    return bless $gd,ref $self || $self;
}

sub default_font { return $DefaultFont || 'Arial' }

# print with a truetype string
sub string {
    my $self = shift;
    my ($font,$x,$y,$string,$color) = @_;
    my $fontface   = $self->_match_font($font);
    my ($fontsize) = $fontface =~ /-(\d+)/;
    $self->stringFT($color,$fontface,$fontsize,0,$x,$y+$fontsize+2,$string);
}

sub string_width {
    my $self = shift;
    my ($font,$string) = @_;
    my $fontface = $self->_match_font($font);
    my ($fontsize) = $fontface =~ /-([\d.]+)/;
    my @bounds   = GD::Image->stringFT(0,$fontface,$fontsize,0,0,0,$string);
    return abs($bounds[2]-$bounds[0]);
}

sub string_height {
    my $self = shift;
    my ($font,$string) = @_;
    my $fontface = $self->_match_font($font);
    my ($fontsize) = $fontface =~ /-(\d+)/;
    my @bounds   = GD::Image->stringFT(0,$fontface,$fontsize,0,0,0,$string);
    return abs($bounds[5]-$bounds[3]);
}

# find a truetype match for a built-in font
sub _match_font {
    my $self = shift;
    my $font = shift;
    return $font unless ref $font && $font->isa('GD::Font');

    # work around older versions of GD that require useFontConfig to be called from a GD::Image instance
    $GdInit++ || eval{GD::Image->useFontConfig(1)} || GD::Image->new(10,10)->useFontConfig(1);

    my $fh     = $font->height-1;
    my $height = $fh*0.75; # 1 px == 0.75 pt (http://www.w3.org/TR/CSS21/syndata.html#x39)
    my $style  = $font eq GD->gdMediumBoldFont ? 'bold'
	        :$font eq GD->gdGiantFont      ? 'bold'
                :'normal';
    my $ttfont = $self->default_font;
    return "$ttfont-$height:$style";
}

1;
