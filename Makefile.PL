use strict;
use FindBin '$Bin';
use File::Copy;
use File::Basename;
use File::Path;
use ExtUtils::MakeMaker qw[ prompt WriteMakefile ];

use constant CONF_FILE => 'cmap_install.conf';

my @OPTIONS = qw[ CONF_DIR TEMPLATE_DIR STYLESHEET_DIR SCRIPT_DIR ];
my $OPTIONS = join ( '|', @OPTIONS );
my %OPTIONS;

#
# Process command-line args.
#
my @argv = @ARGV;
@ARGV    = ();
foreach ( @argv ) {
    if ( /^--?h(elp)?/i ) {
        die join("\n", 
            'To customize install locations, provide one or '.
            'more of the options ',
            join( ', ', @OPTIONS ),
            "e.g., 'CONF_DIR=/usr/local/apache/conf'"
        );
    }
    elsif ( /($OPTIONS)=(.+)/og ) {
        $OPTIONS{$1} = $2;
    }
    else {
        push @ARGV, $_;
    }
}

#
# See if previous config options exist.
#
if ( -e CONF_FILE && !%OPTIONS ) {
    print STDERR "It looks like you have installed cmap before.\n",
        "Should I use the previous settings in ", CONF_FILE, "\n",
        "to set the file paths? [Y/n] ";
    chomp ( my $answer = <> );
    if ( !$answer || $answer =~ /^[Yy]/ ) {
        print STDERR "Using previous settings for file paths.\n";
        open F, CONF_FILE or die "Can't read ".CONF_FILE.": $!";
        while ( <F> ) {
            chomp;
            next if /^\#/;
            next unless /^($OPTIONS)=(.+)/o;
            $OPTIONS{$1} = $2;
        }
        close F;
    }
}

#
# If no options, get interactively.
#
unless ( %OPTIONS ) {
    my $preamble = <<"PREAMBLE";
# -----------------------------------------
# Generic Model Organism Database
# Comparative and Genetic Maps Installation
# -----------------------------------------

I'm going to ask you some questions about how to 
configure your system.  These options can be given
as arguments to this script with the options:

PREAMBLE

    $preamble .= join( "\n", map { "\t$_" } @OPTIONS, '' );
    print $preamble;

    $OPTIONS{'CONF_DIR'} = get_path(
        prompt   => 'Where would you like the configuration file installed?',
        optional => 1,
        default  => '/usr/local/apache/conf',
    );

    $OPTIONS{'TEMPLATE_DIR'} = get_path(
        prompt   => 'Where would you like the HTML templates installed?',
        optional => 1,
        default  => '/usr/local/apache/templates/cmap',
    );

    $OPTIONS{'SCRIPT_DIR'} = get_path(
        prompt   => 'Where would you like the command-line scripts installed?',
        optional => 1,
        default  => '/usr/local/bin/',
    );

    $OPTIONS{'STYLESHEET_DIR'} = get_path(
        prompt   => 'Where would you like the HTML stylesheet installed?',
        optional => 1,
        default  => '/usr/local/apache/cmap',
    );
}

#
# Write out our current config options.
#
my $config = "$Bin/".CONF_FILE;
open F,">$config" or die "Can't open $config for writing: $!";
print F 
    "# This hints file contains configuration information used\n",
    "# by the cmap installer.\n",
    qq[# To reconfigure, run "perl Makefile.PL `cat ".CONF_FILE."`"\n];
foreach ( keys %OPTIONS ) {
    print F "$_=$OPTIONS{$_}\n";
}
close F;

#
# Let the installer know where things are going.
#
print "\nHere are the paths I'm using to install:\n",
    map { "  $_ = $OPTIONS{$_}\n" } keys %OPTIONS;

#
# Copy the templates.
#
if ( my $template_dir = $OPTIONS{'TEMPLATE_DIR'} ) {
    my $template_src = "$Bin/templates";
    opendir DIR, $template_src;
    my @templates = grep {/.+\.tmpl$/} readdir DIR;
    close DIR;
    print "\nCopying templates to '$template_dir'.\n";
    for ( @templates ) {
        my $template = $template_src.'/'.$_;
        copy( $template, $template_dir ) or warn 
            "Can't copy '$template' to '$template_dir': $!\n";
    }

    local $/;
    my $conf_file = "$Bin/apache_conf/cmap.conf";
    print "\nUpdating '$conf_file'\n  with template dir '$template_dir'.\n";
    open( F, "<$conf_file" ) or die "Can't read $conf_file: $!\n";
    my $configuration = <F>;
    close F;

    if (
        $configuration =~ s{template_dir\s+.+}{template_dir $template_dir}
    ) {
        open( F, ">$conf_file" ) or die "Can't write $conf_file: $!\n";
        print F $configuration;
        close F;
    }
    else {
        print map { "  $_\n" }
            "I was unable to update the configuation file",
            "($conf_file)",
            "with the location of you template directory\n",
            "($template_dir).",
            "Please be sure to do this yourself.";
    }
}

#
# Copy the admin script.
#
if ( my $script_dir = $OPTIONS{'SCRIPT_DIR'} ) {
    my $admin_script = "$Bin/bin/cmap_admin.pl";
    print "\nCopying admin script to '$script_dir'.\n";
    scopy( $admin_script , $script_dir );
}

#
# Copy the stylesheet.
#
if ( my $stylesheet_dir = $OPTIONS{'STYLESHEET_DIR'} ) {
    my $stylesheet = "$Bin/apache_conf/cmap.css";
    print "\nCopying stylesheet to '$stylesheet_dir'.\n";
    scopy( $stylesheet , $stylesheet_dir );
}

#
# Copy the config file and update the Constants file 
# with the location of the config file.
#
if ( my $conf_dir = $OPTIONS{'CONF_DIR'} ) {
    my $conf_file = "$Bin/apache_conf/cmap.conf";
    print "\nCopying config file to '$conf_dir'.\n";
    scopy( $conf_file , $conf_dir );

    local $/;
    my $constants_file = "$Bin/lib/Bio/GMOD/CMap/Constants.pm";
    print "\nUpdating '$constants_file'\n  with config location '$conf_dir'.\n";
    open( F, "<$constants_file" ) or die "Can't read $constants_file: $!\n";
    my $constants = <F>;
    close F;

    my $conf_path = "$conf_dir/cmap.conf";

    if (
        $constants =~ s
            {use constant CONFIG_FILE => '.+'}
            {use constant CONFIG_FILE => '$conf_path'}
    ) {
        open( F, ">$constants_file" ) or die 
            "Can't write $constants_file: $!\n";
        print F $constants;
        close F;
    }
    else {
        print map { "  $_\n" }
            "I was unable to update the constants file",
            "($constants_file)",
            "with the location of you config file\n",
            "($conf_file).",
            "Please be sure to do this yourself.";
    }
}

#
# Write the makefile.
#
print "\nOK to write Makefile? [Y/n] ";
chomp( my $answer = <STDIN> );
if ( !$answer || $answer =~ /^[Yy]/ ) {
   WriteMakefile(
        NAME          => 'Bio::GMOD::CMap',
        VERSION       => '0.03',
        AUTHOR        => 'Ken Y. Clark <kclark@cshl.org>',
        ABSTRACT      => 'Modules for drawing comparative and genetic maps.',
        PREREQ_PM     => {
            Apache          => 0,
            Apache::Request => 0,
            Class::Base     => 0,
            DBI             => 1.21,
            Error           => 0.15,
            File::MkTemp    => 0,
            GD              => 1.33,
            Template        => 2.00,
            Time::Object    => 0,
            Time::ParseDate => 0,
        },
    );

    print qq[Now you must run "make" and "make install"\n];
    print qq[Be sure to edit your "cmap.conf" file with your database info.\n];
}
exit(0);

# ----------------------------------------------------
sub get_path {
    my %args   = @_;
    my $prompt = $args{'prompt'};
    $prompt   .= ' (optional)' if $args{'optional'};
    my $path   = $args{'default'} || '';

    print "\n$prompt\n";

    if ( $path ) {
        chomp( my $answer = prompt qq[Use default "$path"? [Y/n] ] );
        $path = '' if $answer =~ m/^[Nn]/;
    }
    
    my $dir_prompt = 'Directory: ';
    $dir_prompt   .= '[q to quit]' if $args{'optional'};
    while ( 1 ) {
        $path ||= prompt $dir_prompt;
        next unless $path;
        if ( $path eq 'q' ) {
            $path = '';
            last;
        }
        elsif ( -e $path ) {
            last;
        }
        else {
            print qq[Directory "$path" doesn't exist.  Create? [Y/n] ];
            chomp( my $answer = <STDIN> );
            if ( $answer =~ m/^[Nn]/ ) {
                $path = '';
                next;
            }
            else {
                mkpath( $path, 0, 0711 ) or die qq[Can't make path "$path": $!];
                last;
            }
        }
    }

    return $path;
}

# ----------------------------------------------------
sub scopy {
    my $src_file  = shift;
    my $dest_dir  = shift;
    my $filename  = basename( $src_file );
    my $dest_file = join('/', $dest_dir, $filename );
    my $ok        = 1;

    if ( -e $dest_file ) {
        print "\nFile '$dest_file' already exists.  Overwrite? [Y/n] ";
        chomp( my $answer = <STDIN> );
        if ( !$answer || $answer =~ /^[Yy]/ ) {
            $ok = 1;
        }
        else { 
            print "  Won't overwrite '$dest_file'.\n";
            $ok = 0;
        }
    }

    if ( $ok ) {
        copy( $src_file, $dest_dir ) or die 
            "Can't copy '$src_file'\n  to '$dest_dir':\n  $!\n";
    }
}

# ----------------------------------------------------
# If others had not been foolish, we should be so.
# William Blake
# ----------------------------------------------------
