#!perl

use strict;
use CMapBuildConfig;
use Cwd;
use File::Basename qw(&basename &dirname);
use File::Spec::Functions;

my $conf_dir = catfile( $Build{'CONF'} );

my $origdir = cwd;
chdir dirname($0);
my $file;
($file = basename($0)) =~ s/\.PL$//;
open OUT, ">$file" or die "Can't write file '$file': $!\n";
print "Extracting $file (with variable substitutions)\n";
print OUT<<'NOGROK';
package Bio::GMOD::CMap::Constants;
# vim: set ft=perl:

# $Id: Constants.pm.PL,v 1.15 2004-06-23 20:53:48 mwz444 Exp $

use strict;
use GD;
use base qw( Exporter );
use vars qw( @EXPORT $VERSION );
require Exporter;
$VERSION = (qw$Revision: 1.15 $)[-1];

@EXPORT = qw[ 
    ARC
    COLORS
    GLOBAL_CONFIG_FILE
    CONFIG_DIR
    CMAP_URL
    DASHED_LINE
    DEFAULT
    FILL
    FILLED_RECT
    FILL_TO_BORDER
    LEFT
    LINE
    NUMBER_RE
    NORTH
    PREFERENCE_FIELDS
    RECTANGLE
    RIGHT
    SHAPE_XY
    SOUTH
    STRING
    STRING_UP
    VALID
];

NOGROK
print OUT<<"!GROK!THIS!";
#
# The location of the configuration files.
#
use constant CONFIG_DIR => '$conf_dir';
use constant GLOBAL_CONFIG_FILE => 'global.conf';

!GROK!THIS!

print OUT<<'NOGROK';
#
# My palette of colors available for drawing maps
#
use constant COLORS      => {
    white                => ['FF','FF','FF'],
    black                => ['00','00','00'],
    aliceblue            => ['F0','F8','FF'],
    antiquewhite         => ['FA','EB','D7'],
    aqua                 => ['00','FF','FF'],
    aquamarine           => ['7F','FF','D4'],
    azure                => ['F0','FF','FF'],
    beige                => ['F5','F5','DC'],
    bisque               => ['FF','E4','C4'],
    blanchedalmond       => ['FF','EB','CD'],
    blue                 => ['00','00','FF'],
    blueviolet           => ['8A','2B','E2'],
    brown                => ['A5','2A','2A'],
    burlywood            => ['DE','B8','87'],
    cadetblue            => ['5F','9E','A0'],
    chartreuse           => ['7F','FF','00'],
    chocolate            => ['D2','69','1E'],
    coral                => ['FF','7F','50'],
    cornflowerblue       => ['64','95','ED'],
    cornsilk             => ['FF','F8','DC'],
    crimson              => ['DC','14','3C'],
    cyan                 => ['00','FF','FF'],
    darkblue             => ['00','00','8B'],
    darkcyan             => ['00','8B','8B'],
    darkgoldenrod        => ['B8','86','0B'],
    darkgrey             => ['A9','A9','A9'],
    darkgreen            => ['00','64','00'],
    darkkhaki            => ['BD','B7','6B'],
    darkmagenta          => ['8B','00','8B'],
    darkolivegreen       => ['55','6B','2F'],
    darkorange           => ['FF','8C','00'],
    darkorchid           => ['99','32','CC'],
    darkred              => ['8B','00','00'],
    darksalmon           => ['E9','96','7A'],
    darkseagreen         => ['8F','BC','8F'],
    darkslateblue        => ['48','3D','8B'],
    darkslategrey        => ['2F','4F','4F'],
    darkturquoise        => ['00','CE','D1'],
    darkviolet           => ['94','00','D3'],
    deeppink             => ['FF','14','100'],
    deepskyblue          => ['00','BF','FF'],
    dimgrey              => ['69','69','69'],
    dodgerblue           => ['1E','90','FF'],
    firebrick            => ['B2','22','22'],
    floralwhite          => ['FF','FA','F0'],
    forestgreen          => ['22','8B','22'],
    fuchsia              => ['FF','00','FF'],
    gainsboro            => ['DC','DC','DC'],
    ghostwhite           => ['F8','F8','FF'],
    gold                 => ['FF','D7','00'],
    goldenrod            => ['DA','A5','20'],
    grey                 => ['80','80','80'],
    green                => ['00','80','00'],
    greenyellow          => ['AD','FF','2F'],
    honeydew             => ['F0','FF','F0'],
    hotpink              => ['FF','69','B4'],
    indianred            => ['CD','5C','5C'],
    indigo               => ['4B','00','82'],
    ivory                => ['FF','FF','F0'],
    khaki                => ['F0','E6','8C'],
    lavender             => ['E6','E6','FA'],
    lavenderblush        => ['FF','F0','F5'],
    lawngreen            => ['7C','FC','00'],
    lemonchiffon         => ['FF','FA','CD'],
    lightblue            => ['AD','D8','E6'],
    lightcoral           => ['F0','80','80'],
    lightcyan            => ['E0','FF','FF'],
    lightgoldenrodyellow => ['FA','FA','D2'],
    lightgreen           => ['90','EE','90'],
    lightgrey            => ['D3','D3','D3'],
    lightpink            => ['FF','B6','C1'],
    lightsalmon          => ['FF','A0','7A'],
    lightseagreen        => ['20','B2','AA'],
    lightskyblue         => ['87','CE','FA'],
    lightslategrey       => ['77','88','99'],
    lightsteelblue       => ['B0','C4','DE'],
    lightyellow          => ['FF','FF','E0'],
    lime                 => ['00','FF','00'],
    limegreen            => ['32','CD','32'],
    linen                => ['FA','F0','E6'],
    magenta              => ['FF','00','FF'],
    maroon               => ['80','00','00'],
    mediumaquamarine     => ['66','CD','AA'],
    mediumblue           => ['00','00','CD'],
    mediumorchid         => ['BA','55','D3'],
    mediumpurple         => ['100','70','DB'],
    mediumseagreen       => ['3C','B3','71'],
    mediumslateblue      => ['7B','68','EE'],
    mediumspringgreen    => ['00','FA','9A'],
    mediumturquoise      => ['48','D1','CC'],
    mediumvioletred      => ['C7','15','85'],
    midnightblue         => ['19','19','70'],
    mintcream            => ['F5','FF','FA'],
    mistyrose            => ['FF','E4','E1'],
    moccasin             => ['FF','E4','B5'],
    navajowhite          => ['FF','DE','AD'],
    navy                 => ['00','00','80'],
    oldlace              => ['FD','F5','E6'],
    olive                => ['80','80','00'],
    olivedrab            => ['6B','8E','23'],
    orange               => ['FF','A5','00'],
    orangered            => ['FF','45','00'],
    orchid               => ['DA','70','D6'],
    palegoldenrod        => ['EE','E8','AA'],
    palegreen            => ['98','FB','98'],
    paleturquoise        => ['AF','EE','EE'],
    palevioletred        => ['DB','70','100'],
    papayawhip           => ['FF','EF','D5'],
    peachpuff            => ['FF','DA','B9'],
    peru                 => ['CD','85','3F'],
    pink                 => ['FF','C0','CB'],
    plum                 => ['DD','A0','DD'],
    powderblue           => ['B0','E0','E6'],
    purple               => ['80','00','80'],
    red                  => ['FF','00','00'],
    rosybrown            => ['BC','8F','8F'],
    royalblue            => ['41','69','E1'],
    saddlebrown          => ['8B','45','13'],
    salmon               => ['FA','80','72'],
    sandybrown           => ['F4','A4','60'],
    seagreen             => ['2E','8B','57'],
    seashell             => ['FF','F5','EE'],
    sienna               => ['A0','52','2D'],
    silver               => ['C0','C0','C0'],
    skyblue              => ['87','CE','EB'],
    slateblue            => ['6A','5A','CD'],
    slategrey            => ['70','80','90'],
    snow                 => ['FF','FA','FA'],
    springgreen          => ['00','FF','7F'],
    steelblue            => ['46','82','B4'],
    tan                  => ['D2','B4','8C'],
    teal                 => ['00','80','80'],
    thistle              => ['D8','BF','D8'],
    tomato               => ['FF','63','47'],
    turquoise            => ['40','E0','D0'],
    violet               => ['EE','82','EE'],
    wheat                => ['F5','DE','B3'],
    whitesmoke           => ['F5','F5','F5'],
    yellow               => ['FF','FF','00'],
    yellowgreen          => ['9A','CD','32'],
};

#
# The URL of the GMOD-CMap website.
#
use constant CMAP_URL => 'http://www.gmod.org/cmap';

#
# This group represents strings used for the GD package for drawing.
# I'd rather use constants in order to get compile-time spell-checking
# rather than using plain strings (even though that would be somewhat
# faster).  These strings correspond to the methods of the GD package.
# Don't change these!
#
use constant ARC            => 'arc';
use constant DASHED_LINE    => 'dashedLine';
use constant LINE           => 'line';
use constant FILLED_RECT    => 'filledRectangle';
use constant FILL           => 'fill';
use constant FILL_TO_BORDER => 'fillToBorder';
use constant RECTANGLE      => 'rectangle';
use constant STRING         => 'string';
use constant STRING_UP      => 'stringUp';

#
# More string constants to avoid mis-spells.
#
use constant RIGHT => 'right';
use constant LEFT  => 'left';
use constant NORTH => 'north';
use constant SOUTH => 'south';

#
# Describes where the X and Y attributes of a shape are.
#
use constant SHAPE_XY => {
    ARC           , { x => [ 1    ],  y => [ 2    ] },
    FILL          , { x => [ 1    ],  y => [ 2    ] },
    FILLED_RECT   , { x => [ 1, 3 ],  y => [ 2, 4 ] },
    FILL_TO_BORDER, { x => [ 1    ],  y => [ 2    ] },
    LINE          , { x => [ 1, 3 ],  y => [ 2, 4 ] },
    RECTANGLE     , { x => [ 1, 3 ],  y => [ 2, 4 ] },
    STRING        , { x => [ 2    ],  y => [ 3    ] },
    STRING_UP     , { x => [ 2    ],  y => [ 3    ] },
};

#
# Holds default values for misc items.
#
use constant DEFAULT => {
    #
    # The background color of the map image.
    # Default: lightgoldenrodyellow
    #
    background_color => 'lightgoldenrodyellow',

    #
    # Where the main viewer is located.
    #
    cmap_viewer_url => 'viewer',

    #
    # The color of the line connecting things.
    # Default: lightblue
    #
    connecting_line_color => 'lightblue',

    #
    # The domain of the cookies.
    # Default: empty
    #
    cookie_domain => '',

    #
    # Whether or not to be in debug mode ("0" or "1").
    # Default: 0
    #
    debug => 0,

    #
    # URL for evidence type info
    #
    evidence_type_details_url => 'evidence_type_info?evidence_type=',

    #
    # Color of a feature if not defined
    # Default: black
    #
    feature_color => 'black',

    #
    # Where to see feature details.
    #
    feature_details_url => 'feature?feature_aid=',

    #
    # Color of box around a highlighted feature.
    # Default: red
    #
    feature_highlight_fg_color => 'red',

    #
    # Color of background behind a highlighted feature.
    # Default: yellow
    #
    feature_highlight_bg_color => 'yellow',

    #
    # Color of a feature label when it has a correspondence.
    # Leave undefined to use the feature's own color.
    # Default: green
    #
    feature_correspondence_color => '',

    #
    # The normal font size
    # Default: small
    #
    font_size => 'small',

    #
    # Which field to search if none specified.
    # Choices: feature_name, accession_id
    # Default: feature_name
    #
    feature_search_field => 'feature_name',

    #
    # Where to see feature type details.
    #
    feature_type_details_url => 'feature_type_info?feature_type=',
    
    #
    # The size of the map image.  Note that there are options on the
    # template for the user to choose the size of the image they're
    # given.  You should make sure that what you place here
    # occurs in the choices on the template.  The default values on
    # the template are "small," "medium," and "large."
    # Default: small
    #
    image_size => 'small',

    #
    # The way to deliver the image, 'png' or 'jpeg'
    # (or whatever your compilation of GD offers, perhaps 'gif'?).
    # Default: png
    #
    image_type => 'png',

    #
    # What to show for feature labels on the maps.
    # Values: none landmarks all
    # Default: 'all'
    #
    label_features => 'all',
    
    #
    # Color of a map (type) if not defined
    # Default: lightgrey
    #
    map_color => 'lightgrey',

    #
    # The URL for map set info.
    # Default: map_set_info
    #
    map_set_info_url => 'map_set_info',

    #
    # The titles to put atop the individual maps, e.g., "Wheat-2M."
    # Your choices will be stacked in the order defined.
    # Choices: species_name, map_set_name (short_name), map_name
    # Default: species_name, map_name
    #
    map_titles => [ qw( species_name map_set_name map_name) ],

    #
    # Width of a map.
    # Default: 8
    #
    map_width => 8,

    #
    # The smallest any map can be drawn, in pixels.
    # Default: 20
    #
    min_map_pixel_height => 20,

    #
    # How to draw a map.
    #
    map_shape => 'box',

    #
    # Title for matrix page
    #
    matrix_title => 'Welcome to the Matrix',

    #
    # The maximum number of features allowed on a map.
    # Set to "0" (or a negative number) or undefined to disable.
    # Default: 200
    #
    max_feature_count => 0,

    #
    # The maximum number of elements that can appear on a page 
    # (like in search results).
    #
    max_child_elements => 25,

    #
    # How many pages of results to show in searches.
    # Default: 10
    #
    max_search_pages => 10,

    #
    # Maximum number of seconds before timing out the web request
    # Default: 0 (disabled)
    #
    max_web_timeout => 0,

    #
    # The number of positions to have flanking zoomed areas.
    # Default: 3
    #
    number_flanking_positions => 3,

    #
    # The module to dispatch to when no path is given to "/cmap."
    #
    path_info => 'index',

    #
    # Where to see more on a map type.
    #
    map_details_url => 'map_details',

    #
    # The colors of the slot background and border.
    # Values: COLORS
    # Default: background = beige, border = khaki
    #
    slot_background_color => 'beige',
    slot_border_color     => 'khaki',

    #
    # The HTML stylesheet.
    # Default: empty
    #
    stylesheet => '',
    
    #
    # The name of the SQL driver module to use if nothing else is specified.
    # Default: generic
    #
    sql_driver_module => 'generic',

    #
    # What to name the cookie containing user preferences.
    #
    user_pref_cookie_name => 'CMAP_USER_PREF', 
};

#
# A regular expression for determining valid numbers.
#
use constant NUMBER_RE => qr{^\-?\d+(?:\.\d+)?$};

#
# The fields to remember between requests and sessions.
#
use constant PREFERENCE_FIELDS => [ qw(
    highlight
    image_size
    font_size
    image_type  
    label_features
    data_source
    collapse_features
) ];

#
# A list of valid options.
#
use constant VALID => {
    #
    # Font sizes
    #
    font_size      => {
        small      => 1,
        medium     => 1,
        large      => 1,
    },

    #
    # Image types, this should match how you compiled libgd on your system.
    #
    image_type  => { 
        png     => 1, 
        jpeg    => 1,
        svg     => 1,
    },

    #
    # Image heights, in pixels.
    #
    image_size => {
        small  => 400,
        medium => 600,
        large  => 800,
    },

    #
    # The fields allowed in the feature search.
    # 
    feature_search_field => {
        feature_name     => 1,
        feature_aid      => 1,   
    },

    #
    # SQL driver modules used by Bio::GMOD::CMap::Data
    # If you use a different database, then just point the driver
    # name to the module you want to use.  Or write your own module
    # and point your driver to it.  Use only lowercase for the keys.
    #
    sql_driver_module => {
        generic       => 'Bio::GMOD::CMap::Data::Generic',
        mysql         => 'Bio::GMOD::CMap::Data::MySQL',
        oracle        => 'Bio::GMOD::CMap::Data::Oracle',
    },

    #
    # The GD shapes we can draw.
    #
    shape => {
        ARC           , 1,
        LINE          , 1,
        FILL          , 1,
        FILLED_RECT   , 1,
        FILL_TO_BORDER, 1,
        RECTANGLE     , 1,
        STRING        , 1,
        STRING_UP     , 1,
    },

    #
    # The choices for "label_features"
    #
    label_features => {
        all       => 1,
        landmarks => 1,
        none      => 1,
    },
    #
    # The choices of map shape
    #
    map_shapes=>{
      'box'      => 1,
        'dumbbell' => 1,
        'I-beam'   => 1,
    },

};

#
# Unit conversions
#
use constant UNITS      => {
    p => 1e-12,
    n => 1e-9,
    u => 1e-6,
    m => 0.001,
    c => 0.01,
    k => 1000,
    M => 1_000_000,
    G => 1_000_000_000
};


1;

# ----------------------------------------------------
# It is not all books that are as dull as their readers.
# Henry David Thoreau
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Constants - constants module

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Constants;
  blah blah blah

=head1 DESCRIPTION

This module exports a bunch of constants.  It's hoped that users of
the code distribution will be able to make most or all of their
changes in just this file in order to customize the look and feel of
their installation.

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
NOGROK
