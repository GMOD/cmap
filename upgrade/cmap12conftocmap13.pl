#!/usr/bin/perl -w

=pod

=head1 NAME

cmap12conftocmap13.pl

=head1 SYNOPSIS

  cmap12conftocmap13.pl cmap.conf

=head1 DESCRIPTION

Parses a CMap config file from version 0.12 (maybe earlier but not tested) 
and converts it to CMap version 0.13.

Creates a "global.conf" and one "cmap#.conf" for each database
described in the config file.  These should be moved to the cmap.conf
directory in the current working directory (so it's best to launch
from within the "cmap.conf" directory).

Does not carry over ANY comments.  It just ignores all of the commented 
text.  It does add the pre-scripted comments.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

=cut

# -------------------------------------------------------

use strict;
use Config::General;

my $conf_file = shift or die "Missing original 'cmap.conf' file\n";

print "Parsing config file '$conf_file.'\n";

my $conf = Config::General->new( $conf_file ) or
    die "Trouble reading config '$conf_file'";
my %config = $conf->getall or 
    die "No configuration options present in '$conf_file'";

my %handled;

open my $global_conf, ">global.conf" or 
    die "Couldn't create 'global.conf': $!\n";

print $global_conf q[# ----------------------------------------------------
#
# cmap.conf
#
# Edit this file to customize the look and behavior of
# the CMap application.  The only sections that *must*
# be set are "database," "template_dir" and "cache_dir."
#
# Remember that your webserver must be restarted to
# enact any changes here.
#
# ----------------------------------------------------

#
# An absolute path to the directory holding the templates
# Default: Set on install
#
];
$handled{'template_dir'}=1;
print $global_conf "template_dir ".$config{'template_dir'}."\n\n";

print $global_conf q[#
# An absolute path to the directory where images are written I would
# also suggest you purge this directory for old images so you don't
# fill up your disk.  Here's a simple cron job you can put in your
# root's crontab (all on one line, of course):
#
# 0 0 * * *  find /usr/local/apache/htdocs/cmap/tmp
# -type f -mtime +1 -exec rm -rf {} ;
#
# Default: /usr/local/apache/htdocs/cmap/tmp
#

];
$handled{'cache_dir'}=1;
print $global_conf "cache_dir ".$config{'cache_dir'}."\n\n";

my @databases;
if (ref($config{'database'}) eq 'HASH'){
    # One database
    push @databases, $config{'database'};
}
else{
    @databases = @{$config{'database'}};
}

my $default_config='';
my $config_index=0;
my @file_handles;

$handled{'database'}=1;
foreach my $db (@databases){
    my $config_name = 'cmap'.$config_index.'.conf';
    open my $fh, '>'.$config_name
        or die "couldn't open config file $config_name\n";

    $file_handles[$config_index]=$fh;
    $config_index++;
    print $fh q[# ----------------------------------------------------
#
# cmap.conf
#
# Edit this file to customize the look and behavior of
# the CMap application.  The only section that *must*
# be set is "database".
#
# Remember that your webserver must be restarted to
# enact any changes here.
#
# ----------------------------------------------------

#
# Enable this config file
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
#   datasource: The string passed to DBI to connect to the database
#   user      : The user name to connect to the database
#   password  : The password to connect to the database
#   is_default: Either "1" or "0," only required if defining
#               multiple data sources
#

<database>
];
    print $fh "    name ".$db->{'name'}."\n";
    print $fh "    datasource ".$db->{'datasource'}."\n";
    print $fh "    user ".$db->{'user'}."\n";
    print $fh "    password ".$db->{'password'}."\n";
    print $fh "</database>\n\n";
    
    $default_config = $config_name if $db->{'is_default'};
    $default_config = $config_name if not $default_config;
}

print $global_conf q[#
# Which database should be the default
# Use the "name" from the specific conf file
# Default: CMap
#
];
print $global_conf "default_db ".$default_config."\n\n";

###Finish off with the individual config files

foreach my $fh (@file_handles){
    print $fh q[#
#Using expanded cmap_correspondence_lookup table
#
# Set to 1 if your cmap_correspondence_lookup table is the
#  expanded version that looks like this:
#
# explain cmap_correspondence_lookup;
# +---------------------------+--------------+
# | Field                     | Type         |
# +---------------------------+--------------+
# | feature_id1               | int(11)      |
# | feature_id2               | int(11)      |
# | feature_correspondence_id | int(11)      |
# | start_position1           | double(11,2) |
# | start_position2           | double(11,2) |
# | stop_position1            | double(11,2) |
# | stop_position2            | double(11,2) |
# | map_id1                   | int(11)      |
# | map_id2                   | int(11)      |
# | feature_type_accession1   | varchar(20)  |
# | feature_type_accession2   | varchar(20)  |
# +---------------------------+--------------+

expanded_correspondence_lookup 1

#
#disable_cache
#
# Set to 1 if the query cache should not be used.  This is handy for
#  speed testing or debugging.
# default is 0.
disable_cache 0

#feature_default_display
# What the default display option should be for feature types
# Default is 'display'.
# Other options: 'corr_only', 'ignore'
feature_default_display=display

#
# scalable_units
# units (such as bp) that can be used to scale the maps
# against each other.
#
<scalable>
    bp 1
    cm 0
</scalable>

#
# ----------------------------------------------------
#
# Start optional settings
#
# ----------------------------------------------------

#
# Introductory texts for various pages.
#
];

    $handled{'cmap_home_intro'}=1;
    print $fh "cmap_home_intro <<EOF\n".$config{'cmap_home_intro'}."\nEOF\n" if $config{'cmap_home_intro'};

    $handled{'map_viewer_intro'}=1;
    print $fh "map_viewer_intro <<EOF\n".$config{'map_viewer_intro'}."\nEOF\n" if $config{'map_viewer_intro'};

    $handled{'feature_search_intro'}=1;
    print $fh "feature_search_intro <<EOF\n".$config{'feature_search_intro'}."\nEOF\n" if $config{'feature_search_intro'};

    $handled{'feature_type_info_intro'}=1;
    print $fh "feature_type_info_intro <<EOF\n".$config{'feature_type_info_intro'}."\nEOF\n" if $config{'feature_type_info_intro'};

    $handled{'map_type_info_intro'}=1;
    print $fh "map_type_info_intro <<EOF\n".$config{'map_type_info_intro'}."\nEOF\n" if $config{'map_type_info_intro'};

    $handled{'species_info_intro'}=1;
    print $fh "species_info_intro <<EOF\n".$config{'species_info_intro'}."\nEOF\n" if $config{'species_info_intro'};

    $handled{'matrix_intro'}=1;
    print $fh "matrix_intro <<EOF\n".$config{'matrix_intro'}."\nEOF\n" if $config{'matrix_intro'};

    $handled{'map_set_info_intro'}=1;
    print $fh "map_set_info_intro <<EOF\n".$config{'map_set_info_intro'}."\nEOF\n" if $config{'map_set_info_intro'};

    print $fh q[#
# When making name-based correspondences, the default behavior is to
# allow correspondences between features of the *exact* same type.  If
# you wish to expand the feature types allowed when making name-based
# correspondences, then add their accession IDs to this section.  The
# relationships will be reciprocal, so if you say "foo bar" then
# correspondences from features with the accession ID "foo" will be
# allowed to those with the accession ID "bar" and vice versa.
# Separate feature types with spaces.  You may assert more than two
# feature types on one line, e.g., "foo bar baz."
# Default: Nothing
#
#add_name_correspondence foo bar baz
#add_name_correspondence fee fie

#
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
];

    print $fh q[#
# The background color of the map image
# Values: any color found in the COLORS array of Bio::GMOD::CMap::Constants
# To view this file, either look in the "lib" directory of the original
# CMap source directory, or, if you have the very handy "pmtools" installed
# on your system, type "pmcat Bio::GMOD::CMap::Constants" on your
# command-line.
# Default: lightgoldenrodyellow
#
];
    $handled{'background_color'}=1;
    print $fh "background_color ".$config{'background_color'}."\n\n";

    print $fh q[#
# The color of the line connecting feature correspondences
# Values: COLORS
# Default: lightblue
#
];
    $handled{'connecting_line_color'}=1;
    print $fh "connecting_line_color ".$config{'connecting_line_color'}."\n\n";

    print $fh q[#
# Cookie domain
# Default: commented out
#
#cookie_domain .foo.org

];

    print $fh q[#
# Turn on/off debug statements
# Values: 1 or 0
# Default: 1
#
];
    $handled{'debug'}=1;
    print $fh "debug ".$config{'debug'}."\n\n";

    print $fh q[#
# Default color of a feature if the feature type's "color" is "Default"
# Values: COLORS
# Default: black
#
];
    $handled{'feature_color'}=1;
    print $fh "feature_color ".$config{'feature_color'}."\n\n";

    print $fh q[#
# Color of box around a highlighted feature
# Values: COLORS
# Default: red
#
];
    $handled{'feature_highlight_fg_color'}=1;
    print $fh "feature_highlight_fg_color ".$config{'feature_highlight_fg_color'}."\n\n";

    print $fh q[#
# Color of background behind a highlighted feature
# Values: COLORS
# Default: yellow
#
];
    $handled{'feature_highlight_bg_color'}=1;
    print $fh "feature_highlight_bg_color ".$config{'feature_highlight_bg_color'}."\n\n";

    print $fh q[#
# Color of a feature label when it has a correspondence
# Comment out to use the feature's own color
# Values: COLORS
# Default: red
#
];
    $handled{'feature_correspondence_color'}=1;
    print $fh "feature_correspondence_color ".$config{'feature_correspondence_color'}."\n\n";

    print $fh q[#
# Default font size
# Values: small, medium, large
# Default: small
#
];
    $handled{'font_size'}=1;
    print $fh "font_size ".$config{'font_size'}."\n\n";

    print $fh q[#
# Which field in cmap_feature to search in
# feature search if none specified
# Values: feature_name, alternate_name, both
# Default: feature_name
#
];
    $handled{'feature_search_field'}=1;
    print $fh "feature_search_field ".$config{'feature_search_field'}."\n\n";

    print $fh q[#
# Default size of images
# Values: small, medium, large
# Default: small
#
];
    $handled{'image_size'}=1;
    print $fh "image_size ".$config{'image_size'}."\n\n";

    print $fh q[#
# Default image format
# Values: png, jpeg
# Default: png
#
];
    $handled{'image_type'}=1;
    print $fh "image_type ".$config{'image_type'}."\n\n";

    print $fh q[#
# Which features to show by default
# Values: none, landmarks, all
# Default: all
#
];
    $handled{'label_features'}=1;
    print $fh "label_features ".$config{'label_features'}."\n\n";

    print $fh q[#
# Default color of a map if the "color" field of both the map type
# and the map set are "Default"
# Values: any color found in the COLORS array of Bio::GMOD::CMap::Constants
# Default: lightgrey
#
];
    $handled{'map_color'}=1;
    print $fh "map_color ".$config{'map_color'}."\n\n";

    print $fh q[#
# The titles to put atop the individual maps, e.g., "Wheat-2M"
# Your choices will be stacked in the order defined
# Values: species_name, map_set_name (short_name), map_name
# Default: species_name, map_set_name (short_name), map_name
#
];
    $handled{'map_titles'}=1;
    if (ref($config{'map_titles'}) eq 'SCALAR'){
        print $fh "map_titles ".$config{'map_titles'}."\n\n";
    }
    else{
        foreach my $mt (@{$config{'map_titles'}}){
            print $fh "map_titles ".$mt."\n\n";
        }
    }

    print $fh q[#
# Default width of the maps
# Value: any number from 1 to 10
# Default: 8
#
];
    $handled{'map_width'}=1;
    print $fh "map_width ".$config{'map_width'}."\n\n";

    print $fh q[#
# Title to use on the matrix correspondence page
# Value: a string
# Default: Welcome to the Matrix
#
];
    $handled{'matrix_title'}=1;
    print $fh "matrix_title ".$config{'matrix_title'}."\n\n";

    print $fh q[#
# The smallest any map can be drawn, in pixels
# Values: any positive integer (within reason)
# Default: 20
#
];
    $handled{'min_map_pixel_height'}=1;
    print $fh "min_map_pixel_height ".$config{'min_map_pixel_height'}."\n\n";

    print $fh q[#
# The maximum number of elements that can appear on a page
# (like in search results)
# Set to "0" or a negative number or comment out to disable
# Values: any positive integer (within reason)
# Default: 25
#
];
    $handled{'max_child_elements'}=1;
    print $fh "max_child_elements ".$config{'max_child_elements'}."\n\n";

    print $fh q[#
# How many pages of results to show in searches
# Set to "0" (or a negative number) or comment out to disable
# Values: any positive integer (within reason)
# Default: 10
#
];
    $handled{'max_search_pages'}=1;
    print $fh "max_search_pages ".$config{'max_search_pages'}."\n\n";

    print $fh q[#
# The number of positions to have flanking zoomed areas.
# Default: 3
#
];
    $handled{'number_flanking_positions'}=1;
    print $fh "number_flanking_positions ".$config{'number_flanking_positions'}."\n\n";

    print $fh q[#
# Whether or not to display only features with
# correspondences on relational maps
# Default: 1
#
];
    $handled{'relational_maps_show_only_correspondences'}=1;
    print $fh "relational_maps_show_only_correspondences ".$config{'relational_maps_show_only_correspondences'}."\n\n";

    print $fh q[#
# The colors of the slot background and border.
# Values: COLORS
# Default: background = beige, border = khaki
#
];
    $handled{'slot_background_color'}=1;
    print $fh "slot_background_color ".$config{'slot_background_color'}."\n\n";
    $handled{'slot_border_color'}=1;
    print $fh "slot_border_color ".$config{'slot_border_color'}."\n\n";

    print $fh q[#
# Stylesheet
# Default: /cmap/cmap.css
#
];
    $handled{'stylesheet'}=1;
    print $fh "stylesheet ".$config{'stylesheet'}."\n\n";

    print $fh q[#
# Name of the cookie holding user preferences
# Default: CMAP_USER_PREF
#
];
    $handled{'user_pref_cookie_name'}=1;
    print $fh "user_pref_cookie_name ".$config{'user_pref_cookie_name'}."\n\n";

    $handled{'page_object'}=1;
    print $fh "page_object ".$config{'page_object'}."\n\n";
}
foreach my $key (keys(%config)){
    next if $handled{$key};
    foreach my $fh (@file_handles){
        print $fh "$key ".$config{$key}."\n\n";
    }
}

print "Finished.\n";
