#!perl

use strict;
use CMapBuilder;
use Cwd;
use File::Basename qw(&basename &dirname);

my $builder               = CMapBuilder->current;
my $datasource            = $builder->notes('DATASOURCE');
my $dns_str               = $builder->notes('DNS_STR');
my $db_user               = $builder->notes('DB_USER');
my $db_pass               = $builder->notes('DB_PASS');

my $origdir = cwd;
chdir dirname($0);
my $file;
( $file = basename($0) ) =~ s/\.PL$//;
open OUT, ">$file" or die "Can't write file '$file': $!\n";
print "Extracting $file (with variable substitutions)\n";
print OUT<<"!GROK!THIS!";
# ----------------------------------------------------
#
# demo.conf
#
# This is an example of a configuration file for a CMap database.  It was
# created by running "Build demo". 
#
# Remember that your webserver must be restarted and you may need to use
# cmap_admin.pl to purge the cache to enact any changes here
#
# ----------------------------------------------------

#
# Set this to "0" if you want to disable use of
# this file.
#
is_enabled 1

#
# Database connection parameters
#
# You can only specify one database sections per conf file.
# If you wish to add more, you must make a different conf file.
# The database name must be unique across all conf files in this dir.
#
# Parameters:
#
#   name      : A nickname for the connection, shows up in lists
#   datasource: The string passed to DBI to connect to the database, e.g.,
#               MySQL: "dbi:mysql:CMAP"
#               PostgreSQL: "dbi:Pg:dbname=cmap"
#   user      : The user name to connect to the database
#   password  : The password to connect to the database
#
<database>
    name       $datasource
    datasource $dns_str
    user       $db_user
    password   $db_pass
</database>

#
#disable_cache
#                                                                                                                
# Set to 1 if the query cache should not be used.  This is handy for
#  speed testing or debugging.
# default is 0.
disable_cache 0

#
# Set to 1 to allow an editor running remotely to access the data in the
# database.
# default is 0.
# 

allow_remote_data_access 0

#
# Set to 1 to allow an editor running remotely to change the data in the
# database.
# default is 0.
# 
allow_remote_data_manipulation 0

#
# What the default display option should be for feature types
# Default is 'display'.
# Other options: 'corr_only', 'ignore'
#
feature_default_display=display

# ----------------------------------------------------
#
# Start optional settings
#
# ----------------------------------------------------

#
# Introductory texts for various pages.
#
cmap_home_intro <<EOF
Welcome to the genetic and comparative maps.
EOF

#map_viewer_intro <<EOF
#EOF

feature_search_intro <<EOF
A <b>feature</b> in CMap is any element that can be placed on a
map, either as a point or an interval.  
EOF

#feature_type_info_intro <<EOF
#EOF

#map_type_info_intro <<EOF
#EOF

#species_info_intro <<EOF
#EOF

matrix_intro <<EOF
Each cell in the matrix shows the number of correspondences (and maps)
between each pair.  A correspondence is any relationship between
two features.
EOF

#map_set_info_intro <<EOF
#EOF

#
# When making name-based correspondences, the default behavior is to
# allow correspondences between features of the *exact* same type.  If
# you wish to expand the feature types allowed when making name-based
# correspondences, then add their accession IDs to this section.  The
# relationships will be reciprocal, so if you say "foo bar" then
# correspondences from features with the accession ID "foo" will be
# allowed to those with the accession ID "bar" and vice versa.
# Separate feature types with spaces.  Assert all equivalent feature
# types on one line, e.g., "foo bar baz."
# Default: Nothing
#
#add_name_correspondence foo bar baz
#add_name_correspondence fee fie

# Any entries to "disallow_name_correspondence" will cause the admin
# tool to NOT make correspondences between features of the types listed.
# Either list the feature type accessions separated by spaces on one
# line or individually on separate lines, e.g.:
#
# disallow_name_correspondence centromere qtl
# - or -
# disallow_name_correspondence centromere
# disallow_name_correspondence qtl
#

# In response to database problems making correspondences with really large
# maps, the features on a map can be divided (based on feature_id) to decrease
# the number of features that the database has to handle and one time.  If you
# are not having this problem, it will not help you at all.
# Default: 1
#
# make_corr_feature_divisor 1

#
# The background color of the map image
# Values: any color found in the COLORS array of Bio::GMOD::CMap::Constants
# To view this file, either look in the "lib" directory of the original
# CMap source directory, or, if you have the very handy "pmtools" installed
# on your system, type "pmcat Bio::GMOD::CMap::Constants" on your 
# command-line.
# Default: lightgoldenrodyellow
#
background_color lightgoldenrodyellow

#
# The color of the line connecting feature correspondences
# Values: COLORS
# Default: lightblue
# 
connecting_line_color lightblue

#
# Cookie domain
# Default: commented out
#
#cookie_domain .foo.org

#
# Default color of a feature if the feature type's "color" is "Default"
# Values: COLORS
# Default: black
#
feature_color black

#
# Color of box around a highlighted feature
# Values: COLORS
# Default: red
#
feature_highlight_fg_color red

#
# Color of background behind a highlighted feature
# Values: COLORS
# Default: yellow
#
feature_highlight_bg_color yellow

#
# Color of a feature label when it has a correspondence
# Comment out to use the feature's own color
# Values: COLORS
# Default: red
#
feature_correspondence_color red

#
# Default font size
# Values: small, medium, large
# Default: small
#
font_size small

#
# Which field in cmap_feature to search in 
# feature search if none specified
# Values: feature_name, alternate_name, both
# Default: feature_name
#
feature_search_field feature_name

#
# Default size of images
# Values: small, medium, large
# Default: small
#
image_size small

#
# Default image format
# Values: png, jpeg
# Default: png
#
image_type png

#
# Which features to show by default
# Values: none, landmarks, all
# Default: all
#
label_features all

#
# Collapse features glyphs into one glyph if they overlap by default
# Values: 0 (don't collapse), 1 (collapse)
# Default: 1 
#
collapse_features 1

#
# Set default value for scale_maps
# Allow scaleable (set by scalable) maps to be drawn in scale
# Values: 0 (don't scale), 1 (scale)
# Default: 1
#
scale_maps 1

#
# Set default value for stack_maps
# Stack the reference maps vertically instead of side-by-side.
# Values: 0 (don't stack), 1 (stack)
# Default: 1
#
stack_maps 0

#
# Set default value for clean_view
# In the clean view, navigation buttons are removed from the picture
# Values: 0 (don't clean), 1 (clean)
# Default: 0
#
clean_view 0

#
# Set default value for dotplot_ps
# This is the pixel size for the dotplot.
# Values: positive integer
# Default: 1
#
dotplot_ps 1

#
# Set default value for show_intraslot_correspondences
# Show correspondences between maps in the same slot.
# Values: 0 (don't show), 1 (show)
# Default: 1
#
show_intraslot_correspondences 0

#
# Set default, aggregate correspondences into one or two lines.
# Values: 0 (don't aggregate), 1 (one line), 2 (two lines)
# Default: 1 
#
aggregate_correspondences 1

#
# Default color of a map if the "color" field of both the map type
# and the map set are "Default"
# Values: any color found in the COLORS array of Bio::GMOD::CMap::Constants
# Default: lightgrey
#
map_color lightgrey

#
# The titles to put atop the individual maps, e.g., "Wheat-2M"
# Your choices will be stacked in the order defined
# Values: species_common_name, map_set_name ,map_set_short_name, map_name
# Default: species_common_name,map_set_short_name, map_name
#
map_titles species_common_name 
map_titles map_set_short_name
map_titles map_name

#
# Default width of the maps
# Value: any number from 1 to 10
# Default: 8
#
map_width 8

#
# Title to use on the matrix correspondence page
# Value: a string
# Default: Welcome to the Matrix
#
matrix_title Welcome to the Matrix

#
# The smallest any map can be drawn, in pixels
# Values: any positive integer (within reason)
# Default: 20
#
min_map_pixel_height 20

#
# The maximum number of elements that can appear on a page
# (like in search results)
# Set to "0" or a negative number or comment out to disable
# Values: any positive integer (within reason)
# Default: 25
#
max_child_elements 25

#
# How many pages of results to show in searches
# Set to "0" (or a negative number) or comment out to disable
# Values: any positive integer (within reason)
# Default: 10
#
max_search_pages 10

#
# The colors of the slot background and border.
# Values: COLORS
# Default: background = beige, border = khaki
#
slot_background_color beige
slot_border_color khaki

#
# Stylesheet
# Default: /cmap/cmap.css
#
stylesheet /cmap/cmap.css

#
# Name of the cookie holding user preferences
# Default: CMAP_USER_PREF
#
user_pref_cookie_name CMAP_USER_PREF

#
# scalable_units
# units (such as bp) that can be used to scale the maps
# against each other.
#
<scalable>
    bp 1
    cM 1
</scalable>

# scale_conversion Available in v.14 when out
# The unit to unit conversion factor if scaling between maps of different units
# is desired.  This completely made up example is read "One band is .1 the size
# of one centimorgan".  For more information, please view the
# ADMINISTRATION.pod file in the docs/ directory.
#<scale_conversion>
#    <bands>
#        cM .1
#    </bands>
#</scale_conversion>

# Specify the default aggregation colors.
# The format is:
# <aggregated_correspondence_colors>
#   "upper_bound" "color"
#   "upper_bound" "color"
#   0 "color from last upperbound to infinity"
# </aggregated_correspondence_colors>
# See ADMINISTRATION.pod for further explaination
<aggregated_correspondence_colors>
    1    lightgrey
    2   blue
    5   purple
    20  red
    0    black
</aggregated_correspondence_colors>

# comp_menu_order
#
# Dictates the default value of how the comparison maps will be ordered in the
# menu select box.  The choices are 'display_order' and 'corrs'.  'display_order'
# is the classical order based on the maps display order and their names.
# Specifying 'corrs' orders the maps by the number of correspondences.
# Default: 'display_order'
comp_menu_order display_order

# corrs_to_map
#
# Determines if correspondence lines go to the feature or map
# Set to 1 to have them go to the map.
# Default: 0
#
corrs_to_map 0


# menu_bgcolor 
#
# The background color of some areas of the menu
# Values: COLOR
# Default: white
#
menu_bgcolor white

# menu_bgcolor_tint
#
# The background color of tinted areas of the menu
# Values: COLOR
# Default: lightgrey
#
menu_bgcolor_tint lightgrey

# menu_ref_bgcolor 
#
# The background color of some of the reference map areas of the menu
# Values: COLOR
# Default: lightblue
#
menu_ref_bgcolor lightblue

# menu_ref_bgcolor_tint
#
# The background color of tinted reference map areas of the menu
# Values: COLOR
# Default: aqua
#
menu_ref_bgcolor_tint aqua

#
# Drawing information for Feature type
#

#Notice the area_code, required_page_code and extra_forms
#  The area_code is perl code that will be used to create the javascript
#    for features/maps being described.  It will be inserted in the area map
#    over the object.  \$code is a variable that holds the javascript, so
#    append all new code to the \$code variable.  Some of the variables
#    from the underlying CMap code are accessable to this code.
#
#  The required_page_code lists the names of required page_code (described
#    later) needed to perform the tasks in area_code.  The page_code is 
#    added to the top of the page and is most likely going to be functions
#    to be called.
#
#  The extra_forms contains the names of extra_forms (described later)
#    which contain extra form elements.  This is so the admin can add
#    text fields, buttons, etc. 
#

<feature_type contig>
feature_type_acc contig
feature_type Contig
default_rank 1
color
shape span 
drawing_lane 2
drawing_priority 1
feature_default_display
area_code <<EOF
\$code=sprintf("onMouseOver=\\"window.status='%s';return true\\"",\$feature->{'feature_type_acc'});
\$code.=sprintf(" onClick=\\"demo('%s')\\";",\$feature->{'feature_id'});
EOF
</feature_type>

<feature_type read>
feature_type_acc read
feature_type Read
default_rank 2 
color
shape direction-arrow
drawing_lane 2
drawing_priority 1
feature_default_display
area_code <<EOF
\$code=sprintf("onMouseOver=\\"window.status='%s';return true\\"",\$feature->{'feature_type_acc'});
\$code.=sprintf(" onClick=\\"demo('%s')\\";",\$feature->{'feature_id'});
EOF
</feature_type>

<feature_type syntenic_block>
feature_type_acc syntenic_block
feature_type Syntenic Block
default_rank 3 
color blue
shape direction-arrow
drawing_lane 3
drawing_priority 3
feature_default_display
area_code <<EOF
\$code=sprintf("onMouseOver=\\"window.status='%s';return true\\"",\$feature->{'feature_type_acc'});
\$code.=sprintf(" onClick=\\"demo('%s')\\";",\$feature->{'feature_id'});
EOF
</feature_type>

<feature_type read_depth>
  feature_type_acc read_depth
  feature_type read_depth
  default_rank 1
  color crimson
  shape heatmap
  drawing_lane 1
  drawing_priority 2
  area_code <<EOF
      \$code=sprintf("onMouseOver=\\"window.status='%s';return true\\"",\$feature->{'feature_name'});
      \$alt = "Number of Reads: ".\$feature->{'feature_name'}."; pos:".\$feature->{'feature_start'}.(defined(\$feature->{'feature_stop'})?'-'.\$feature->{'feature_stop'}:'');
  EOF
</feature_type>


<evidence_type ANB> 
evidence_type_acc ANB 
evidence_type Automated name-based 
rank 1 
color 
# The aggregated_correspondence_colors option dictates the color of aggregated
# correspondence lines for this evidence type.  It is defined the same way as
# aggregated_correspondence_colors is in the main general section above.
# Also see the ADMINISTRATION.pod.
#
#These colors will only be used if the aggregate correspondences are split based
#on evidence type.  Meaning each evidence type will have it's own aggregated
#correspondence.  It is suggested to use primary colors for each different type,
#so they can be distinguished.
<aggregated_correspondence_colors>
    1    lightblue
    20   blue
    0    darkblue
</aggregated_correspondence_colors>

</evidence_type>

<evidence_type synteny> 
evidence_type_acc synteny 
evidence_type Synteny
rank 1 
line_type ribbon
color blue
# The aggregated_correspondence_colors option dictates the color of aggregated
# correspondence lines for this evidence type.  It is defined the same way as
# aggregated_correspondence_colors is in the main general section above.
# Also see the ADMINISTRATION.pod.
#
#These colors will only be used if the aggregate correspondences are split based
#on evidence type.  Meaning each evidence type will have it's own aggregated
#correspondence.  It is suggested to use primary colors for each different type,
#so they can be distinguished.
<aggregated_correspondence_colors>
    1    pink
    20   red
    0    black
</aggregated_correspondence_colors>

</evidence_type>

<map_type Seq>
map_type_acc Seq
map_type Sequence
map_units bp
is_relational_map 
width 1
shape box
color 
display_order 1
unit_granularity 1
<feature_default_display>
</feature_default_display>
</map_type>
!GROK!THIS!
