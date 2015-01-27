#!perl

use strict;
use CMapBuilder;
use Cwd;
use File::Basename qw(&basename &dirname);
use File::Spec::Functions qw(catfile);

my $builder               = CMapBuilder->current;
my $web_document_root_dir = $builder->notes('WEB_DOCUMENT_ROOT');
my $web_cmap_htdocs_dir     = $builder->notes('HTDOCS');
my $template_dir          = $builder->notes('TEMPLATES');
my $cache_dir             = $builder->notes('CACHE');
my $session_dir           = $builder->notes('SESSIONS');

my $file = 'global.conf';
my $pathname = catfile($ARGV[1], $file);
open(OUT, '>', $pathname) or die "Can't write file '$pathname': $!\n";
print "Extracting $file (with variable substitutions)\n";
print OUT<<"!GROK!THIS!";
# ----------------------------------------------------
#
# global.conf
#
# sets the configurations used for all the 
# other conf files
#
#
# ----------------------------------------------------

#   
# An absolute path to the directory holding the templates
# Default: Set on install
#   
template_dir $template_dir

# The absolute path to the document root for the web server.
web_document_root_dir $web_document_root_dir

# The absolute path to the cmap docs directory.  This must be in the
# web_document_root directory.
web_cmap_htdocs_dir $web_cmap_htdocs_dir

#   
# An absolute path to the directory where images are written.  This must be
# within the web_document_root.  I would also suggest you purge this directory
# for old images so you don't fill up your disk.  Here's a simple cron job you
# can put in your root's crontab (all on one line, of course):
#
# 0 0 * * *  find /usr/local/apache/htdocs/cmap/tmp 
# -type f -mtime +1 -exec rm -rf {} ;
#
# Default: /usr/local/apache/htdocs/cmap/tmp
#
cache_dir $cache_dir

#   
# An absolute path to the directory where session files are written.  
#
# Default: /usr/local/apache/htdocs/cmap/tmp
#
session_dir $session_dir

#
# Which database should be the default
# Use the "name" from the specific conf file
# Default: CMAP
# 
default_db CMAP

#
# max_img_dir_fullness 
# This is the maximum percent the image cache directory will fill before CMap
# quits writing to it.  This is to keep CMap from filling your drive.  
# Default: 0
#
max_img_dir_fullness 0

#
# max_img_dir_size 
# Using this option may slow down your requests by as much as 0.4 seconds.
# This is the maximum size (in bytes) the image cache directory will grow
# before CMap quits writing to it.  This is to keep CMap from filling your
# drive.
# Default: 0
#
max_img_dir_size 0

#
# purge_img_dir_when_full
# Allow CMap to purge the image directory when it is full.
# Default: 0
#
purge_img_dir_when_full 0

#
# file_age_to_purge
# The age of an image file that an image has to be to be purged.  This is in
# seconds.
# Default: 300
#file_age_to_purge 300

#
# The maximum number of area boxes that CMap will print before it drops
# them all.  This can save a browser from crashing.  No commas allowed.
# Default: 20000
#
max_image_map_objects 20000

#
# The maximum size (in bytes) of each individual query cache (each datasource
# has 4).  The cmap_reduce_cache_size.pl script uses this value to determin the
# maximum size of each cache.  You should set this script up as a cron job.
# Default: 26214400 # 25Mb
#max_query_cache_size 26214400
!GROK!THIS!
