#!perl

use strict;
use CMapBuildConfig;
use Cwd;
use File::Basename qw(&basename &dirname);

my $origdir = cwd;
chdir dirname($0);
my $file;
($file = basename($0)) =~ s/\.PL$//;
open OUT, ">$file" or die "Can't write file '$file': $!\n";
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
template_dir $Build{'TEMPLATES'}

#   
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
cache_dir $Build{'CACHE'}

#
# Which database should be the default
# Use the "name" from the specific conf file
# Default: CMap
# 
default_db CMap
!GROK!THIS!
