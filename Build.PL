# $Id: Build.PL,v 1.1 2003-09-10 19:48:44 kycl4rk Exp $

use strict;

eval { require Module::Build };
if ( $@ =~ /Can't locate/ ) {
    print qq[Please install "Module::Build" before continuing.\n"];
    exit(0);
}

use FindBin '$Bin';
use File::Copy;
use File::Basename;
use File::Path;
use MyBuilder;

use constant INSTALL_CONF => 'cmap_install.conf';

my %ARGS = ( 
    CONF_DIR        => {
        desc        => 'Location for the cmap.conf configuration file',
        default     => '/usr/local/apache/conf',
    },
    TEMPLATE_DIR    => {
        desc        => 'Location for CMap HTML templates',
        default     => '/usr/local/apache/templates',
    },
    STYLESHEET_DIR  => {
        desc        => 'Location for CMap stylesheet',
        default     => '/usr/local/apache/htdocs',
    },
);

my $OPTIONS = join ( '|', keys %ARGS );
my %OPTIONS;

my $USAGE = join("\n", 
    'Usage:',
    'To customize install locations, provide one or more of the options ',
    join("\n", map { sprintf("%20s: %-s", $_, $ARGS{$_}{'desc'}) } keys %ARGS),
    "e.g., 'perl Build.PL TEMPLATE_DIR=/opt/templates'",
    '',
    ''
);

#
# Process command-line args.
#
my @argv = @ARGV;
@ARGV    = ();
foreach ( @argv ) {
    if ( /^--?h(elp)?/i ) {
        print $USAGE;
        exit(0);
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
if ( -e INSTALL_CONF && !%OPTIONS ) {
    print STDERR "It looks like you have installed cmap before.\n",
        "Should I use the settings in ", INSTALL_CONF, "?  [Y/n] ";
    chomp ( my $answer = <> );
    if ( !$answer || $answer =~ /^[Yy]/ ) {
        print STDERR "Using previous settings for file paths.\n";
        open F, INSTALL_CONF or die "Can't read ".INSTALL_CONF.": $!";
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
# If no options, set with defaults.
#
$OPTIONS{'CONF_DIR'}       ||= $ARGS{'CONF_DIR'}{'default'};
$OPTIONS{'TEMPLATE_DIR'}   ||= $ARGS{'TEMPLATE_DIR'}{'default'};
$OPTIONS{'STYLESHEET_DIR'} ||= $ARGS{'STYLESHEET_DIR'}{'default'};

print "The following options will be used to install CMap:\n",
    join( "\n", 
        ( map { sprintf( "%20s: %-s", $_, $OPTIONS{ $_ } ) } keys %OPTIONS ),
        ''
    ),
;

#
# Write out our current config options.
#
my $config = "$Bin/".INSTALL_CONF;
open F,">$config" or warn "Can't open $config for writing: $!\n";
print F 
    "# This hints file contains configuration \n",
    "# information used by the CMap installer.\n",
    qq[# To reconfigure, run "perl Makefile.PL `cat ".INSTALL_CONF."`"\n]
;
print F "$_=$OPTIONS{$_}\n" for keys %OPTIONS;
close F;

#
# Copy the templates.
#
#if ( my $template_dir = $OPTIONS{'TEMPLATE_DIR'} ) {
#    my $template_src = "$Bin/templates";
#    opendir DIR, $template_src;
#    my @templates = grep {/.+\.tmpl$/} readdir DIR;
#    close DIR;
#    print "\nCopying templates to '$template_dir'.\n";
#    for ( @templates ) {
#        my $template = $template_src.'/'.$_;
#        copy( $template, $template_dir ) or warn 
#            "Can't copy '$template' to '$template_dir': $!\n";
#    }
#
#    local $/;
#    my $conf_file = "$Bin/conf/cmap.conf";
#    print "\nUpdating '$conf_file'\n  with template dir '$template_dir'.\n";
#    open( F, "<$conf_file" ) or die "Can't read $conf_file: $!\n";
#    my $configuration = <F>;
#    close F;
#
#    if (
#        $configuration =~ s{template_dir\s+.+}{template_dir $template_dir}
#    ) {
#        open( F, ">$conf_file" ) or die "Can't write $conf_file: $!\n";
#        print F $configuration;
#        close F;
#    }
#    else {
#        print map { "  $_\n" }
#            "I was unable to update the configuation file",
#            "($conf_file)",
#            "with the location of you template directory\n",
#            "($template_dir).",
#            "Please be sure to do this yourself.";
#    }
#}

#
# Copy the admin script.
#
#if ( my $script_dir = $OPTIONS{'SCRIPT_DIR'} ) {
#    my $admin_script = "$Bin/bin/cmap_admin.pl";
#    print "\nCopying admin script to '$script_dir'.\n";
#    scopy( $admin_script , $script_dir );
#}

#
# Copy the stylesheet.
#
#if ( my $stylesheet_dir = $OPTIONS{'STYLESHEET_DIR'} ) {
#    my $stylesheet = "$Bin/conf/cmap.css";
#    print "\nCopying stylesheet to '$stylesheet_dir'.\n";
#    scopy( $stylesheet , $stylesheet_dir );
#}
#
##
## Copy the config file and update the Constants file 
## with the location of the config file.
##
#if ( my $conf_dir = $OPTIONS{'CONF_DIR'} ) {
#    my $conf_file = "$Bin/conf/cmap.conf";
#    print "\nCopying config file to '$conf_dir'.\n";
#    scopy( $conf_file , $conf_dir );
#
#    local $/;
#    my $constants_file = "$Bin/lib/Bio/GMOD/CMap/Constants.pm";
#    print "\nUpdating '$constants_file'\n  with config location '$conf_dir'.\n";
#    open( F, "<$constants_file" ) or die "Can't read $constants_file: $!\n";
#    my $constants = <F>;
#    close F;
#
#    my $conf_path = "$conf_dir/cmap.conf";
#
#    if (
#        $constants =~ s
#            {use constant CONFIG_FILE => '.+'}
#            {use constant CONFIG_FILE => '$conf_path'}
#    ) {
#        open( F, ">$constants_file" ) or die 
#            "Can't write $constants_file: $!\n";
#        print F $constants;
#        close F;
#    }
#    else {
#        print map { "  $_\n" }
#            "I was unable to update the constants file",
#            "($constants_file)",
#            "with the location of you config file\n",
#            "($conf_file).",
#            "Please be sure to do this yourself.";
#    }
#}

#
# Write the makefile.
#
my $build             =  MyBuilder->new(
    module_name       => 'Bio::GMOD::CMap',
    dist_abstract     => 'Modules for drawing comparative and genetic maps',
    dist_author       => 'Ken Y. Clark <kclark@cshl.org>',
    dist_name         => 'cmap',
    dist_version_from => 'lib/Bio/GMOD/CMap.pm',
    license           => 'gpl',
    scripts           => [ 'bin/cmap_admin.pl' ],
    requires          => {
        'Apache'             => 0,
        'Apache::Request'    => 0,
        'Class::Base'        => 0,
        'Config::General'    => 0,
        'Data::Page'         => 0,
        'Data::Pageset'      => 0,
        'DBI'                => 1.20,
        'File::MkTemp'       => 0,
        'GD'                 => 1.33,
        'IO::Tee'            => 0,
        'Template'           => 2.00,
        'Text::RecordParser' => 0.02,
        'Time::Object'       => 0,
        'Time::ParseDate'    => 0,
    },
);

if ( my $failures = $build->prereq_failures ) {
    while ( my ( $type, $list ) = each %$failures ) {
        while ( my ( $name, $hash ) = each %$list ) {
            print "Failed to find module '$name': $hash->{'message'}\n";
        }
    }
}

$build->add_to_cleanup( INSTALL_CONF );
$build->create_build_script;

print qq[Now run "./Build" and "./Build install"\n];
print qq[Be sure to edit your "cmap.conf" file with your database info!\n];
exit(0);

# ----------------------------------------------------
# If others had not been foolish, we should be so.
# William Blake
# ----------------------------------------------------
