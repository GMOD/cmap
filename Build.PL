# $Id: Build.PL,v 1.9 2003-09-24 21:06:25 kycl4rk Exp $

use strict;

eval { require Module::Build };
if ( $@ =~ /Can't locate/ ) {
    print qq[Please install "Module::Build" before continuing.\n];
    exit(0);
}

use FindBin '$Bin';
use File::Copy;
use File::Basename;
use File::Path;
use File::Spec::Functions;

use constant INSTALL_CONF   => 'cmap_install.conf';
my $cmap_conf_file          =  catfile('conf', 'cmap.conf');
my $stylesheet_file         =  catfile('conf', 'cmap.css');

my @ARGS = qw[ PREFIX CONF_DIR TEMPLATE_DIR STYLESHEET_DIR ];
my %ARGS = ( 
    PREFIX         => {
        desc       => 'A directory prefix for all install arguments',
        default    => catdir('/', 'usr', 'local', 'apache'),
    },
    CONF_DIR       => {
        desc       => 'Location for the cmap.conf configuration file',
        default    => 'conf',
    },
    TEMPLATE_DIR   => {
        desc       => 'Location for CMap HTML templates',
        default    => 'templates',
    },
    STYLESHEET_DIR => {
        desc       => 'Location for CMap stylesheet',
        default    => 'htdocs',
    },
);

my $OPTIONS = join ( '|', @ARGS );
my %OPTIONS;

my $USAGE = join("\n", 
    'To customize install locations, provide one or more of the options ',
    '',
    join("\n", 
        map { sprintf("%14s: %-s\n\t\t(default: %s)\n", 
            $_, $ARGS{$_}{'desc'}, $ARGS{$_}{'default'}) 
        } 
        @ARGS
    ),
    "e.g., 'perl Build.PL PREFIX=/opt'",
    '',
    ''
);

#
# Process command-line args.
#
foreach ( @ARGV ) {
    if ( /^--?h(elp)?/i ) {
        print $USAGE;
        exit(0);
    }
    elsif ( /($OPTIONS)=(.+)/og ) {
        $OPTIONS{$1} = $2;
    }
    else {
        warn "Ignoring unknown option '$_'\n";
    }
}

#
# See if previous config options exist.
#
if ( !%OPTIONS && -e INSTALL_CONF ) {
    my $yes = Module::Build->y_n( 
        "It looks like you have installed cmap before.\n".
        "Should I use the settings in '". INSTALL_CONF . "'?",
        'y'
    );

    if ( $yes ) {
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
# Make sure we have usable options.
#
if ( $OPTIONS{'PREFIX'} ) {
    for my $option ( qw[ CONF_DIR TEMPLATE_DIR STYLESHEET_DIR ] ) {
        $OPTIONS{ $option } ||= $ARGS{ $option }{'default'};
        $OPTIONS{ $option }   = catdir( 
            $OPTIONS{'PREFIX'}, $OPTIONS{ $option } 
        );
    }
}
else {
    for my $option ( qw[ CONF_DIR TEMPLATE_DIR STYLESHEET_DIR ] ) {
        $OPTIONS{ $option } ||= catdir( 
            $ARGS{'PREFIX'}{'default'}, $ARGS{ $option }{'default'}
        );
    }
}

print "The following options will be used to install CMap:\n",
    join( "\n", '',
        ( map { sprintf( "%20s: %-s", $_, $OPTIONS{ $_ } ) } 
          qw[ CONF_DIR TEMPLATE_DIR STYLESHEET_DIR ] 
        ),
        '', ''
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
print F "$_=$OPTIONS{$_}\n" for qw[ CONF_DIR TEMPLATE_DIR STYLESHEET_DIR ];
close F;

#
# Make the text for copying the templates.
#
opendir( TEMPLATES, 'templates' );
my $template_copy = join("\n",
    map {
        $_ = catfile( 'templates', $_ );
        qq[
            \$self->copy_if_modified(
                from    => '$_',
                to_dir  => '$OPTIONS{'TEMPLATE_DIR'}',
                flatten => 1,
            );
        ]
    }
    grep { /\.tmpl$/ } readdir( TEMPLATES )
);
closedir TEMPLATES;

#
# Write the build script.
#
my $conf_file         =  catfile('conf', 'cmap.conf');
my $stylesheet        =  catfile('conf', 'cmap.css');
my $builder           =  Module::Build->subclass(
    class             => 'My::Builder',
    code              => qq[
        sub ACTION_install {
            my \$self = shift;

            $template_copy

            \$self->copy_if_modified( 
                from    => '$conf_file',
                to_dir  => '$OPTIONS{'CONF_DIR'}',
                flatten => 1,
            );

            \$self->copy_if_modified( 
                from    => '$stylesheet',
                to_dir  => '$OPTIONS{'STYLESHEET_DIR'}',
                flatten => 1,
            );

            \$self->SUPER::ACTION_install;
        }
    ]
)->new(
    module_name       => 'Bio::GMOD::CMap',
    dist_abstract     => 'Modules for drawing comparative and genetic maps',
    dist_author       => 'Ken Y. Clark <kclark@cshl.org>',
    dist_name         => 'cmap',
    dist_version_from => 'lib/Bio/GMOD/CMap.pm',
    license           => 'gpl',
    script_files      => [ 'bin/cmap_admin.pl' ],
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
    PL_files         => {
        'conf/cmap.conf.PL'  => 'conf/cmap.conf',
        'lib/Bio/GMOD/CMap/Constants.pm.PL' => 'lib/Bio/GMOD/CMap/Constants.pm',
    },
);

if ( my $failures = $builder->prereq_failures ) {
    while ( my ( $type, $list ) = each %$failures ) {
        while ( my ( $name, $hash ) = each %$list ) {
            print "Failed to find module '$name': $hash->{'message'}\n";
        }
    }
}

$builder->add_to_cleanup( 
    INSTALL_CONF, 'conf/cmap.conf', 'lib/Bio/GMOD/CMap/Constants.pm'
);
$builder->create_build_script;

print qq[Now run "./Build" and "./Build install"\n];
print qq[Be sure to edit your "cmap.conf" file with your database info!\n];
exit(0);

# ----------------------------------------------------
# If others had not been foolish, we should be so.
# William Blake
# ----------------------------------------------------
