# $Id: Build.PL,v 1.40 2004-08-04 04:26:05 mwz444 Exp $

use strict;
use CMapBuilder;
use Cwd;
use File::Spec::Functions;
eval { require Module::Build };
if ( $@ =~ /Can't locate/ ) { 
    print qq[Please install "Module::Build" before continuing.\n];
    exit(0);
}

my @ARGS = qw[ PREFIX CONF CGIBIN TEMPLATES HTDOCS CACHE ];
my %ARGS = ( 
    PREFIX      => {
        desc    => 'A directory prefix for all install arguments',
        default => catdir('/', 'usr', 'local', 'apache'),
    },
    CONF        => {
        desc    => 'Location for the cmap.conf configuration file',
        default => catdir('conf','cmap.conf'),
    },
    CGIBIN      => {
        desc    => 'Location for CGI executables',
        default => 'cgi-bin',
    },
    TEMPLATES   => {
        desc    => 'Location for CMap HTML templates',
        default => catdir( 'templates', 'cmap' ),
    },
    HTDOCS      => {
        desc    => 'Location for static files',
        default => catdir( 'htdocs', 'cmap' ),
    },
    CACHE       => {
        desc    => 'Location for temporary image files',
        default => catdir( 'tmp' ),
    },
);

my $OPTIONS = join ( '|', @ARGS );
my %OPTIONS;

my $USAGE = join("\n", 
    'To customize install locations, provide one or more of the options ',
    '',
    join("\n", 
        map { 
            sprintf("%10s: %-s\n\t\t(default: %s%s)\n", 
                $_, $ARGS{$_}{'desc'}, 
                $_ eq 'PREFIX' ? ''
                    : $_ eq 'CACHE' ? '$PREFIX + $HTDOCS + '
                    : '$PREFIX + ',
                $ARGS{$_}{'default'}
            ) 
        } 
        @ARGS
    ),
    "e.g., 'perl Build.PL PREFIX=/usr/local/apache'",
    '',
    ''
);

#
# Process command-line args.
#
my @argv = @ARGV;
foreach ( @argv ) {
    if ( /^--?h(elp)?/i ) {
        print $USAGE;
        exit(0);
    }
    elsif ( /($OPTIONS)=(.+)/og ) {
        $OPTIONS{$1} = $2;
    }
    else {
        warn "Ignoring unknown option '$_'\n";
        push @ARGV, $_;
    }
}

#
# See if previous config options exist.
#
my $install_conf = catfile( cwd(), 'cmap_install.conf' );
if ( !%OPTIONS ) {
    if ( -e $install_conf ) {
        my $yes = Module::Build->y_n(
            "It looks like you have installed cmap before.\n".
            "Should I use the settings in '". $install_conf . "'?",
            'y'
        );
        
        if ( $yes ) {
            print "Using previous settings from '$install_conf.'\n";
            open F, $install_conf or die "Can't read '$install_conf: $!\n";
            while ( <F> ) {
                chomp; 
                next if /^#/;
                next unless /^($OPTIONS)=(.+)/o;
                $OPTIONS{$1} = $2;
            }
            close F;
        }
    }
    else {
        print "No arguments to Build.PL.  Using defaults.\n",
              "Execute 'perl Build.PL --help' for help.\n";
    }
}  

#
# Make sure we have usable options.
#
if ( $OPTIONS{'PREFIX'} ) {
    for my $option ( qw[ CONF CGIBIN TEMPLATES CACHE HTDOCS ] ) {
        $OPTIONS{ $option } ||= $option eq 'CACHE'
            ? catdir( 
                $OPTIONS{'HTDOCS'} || $ARGS{'HTDOCS'}{'default'}, 
                $ARGS{'CACHE'}{'default'} 
            )
            : $ARGS{ $option }{'default'}
        ;

        #
        # Now add the default prefix
        #
        $OPTIONS{ $option } = catdir( $OPTIONS{'PREFIX'}, $OPTIONS{ $option } );
    }
}
else {
    my $prefix = $ARGS{'PREFIX'}{'default'};
    for my $option ( qw[ CONF TEMPLATES CGIBIN HTDOCS CACHE ] ) {
        $OPTIONS{ $option } ||= $option eq 'CACHE'
            ? catdir( 
                $prefix, 
                $ARGS{'HTDOCS'}{'default'}, 
                $ARGS{ $option }{'default'} 
            )
            : catdir( $ARGS{'PREFIX'}{'default'}, $ARGS{ $option }{'default'} )
        ;
    }
}

print "The following options will be used to install CMap:\n",
    join( "\n", '',
        ( map { sprintf( "%10s: %-s", $_, $OPTIONS{ $_ } ) } 
          qw[ CONF CGIBIN TEMPLATES HTDOCS CACHE ] 
        ),
        '', ''
    ),
;

#
# Write out our current config options.
#
open F,">$install_conf" or warn "Can't write '$install_conf': $!\n";
print F "$_=$OPTIONS{$_}\n" for qw[ CONF CGIBIN TEMPLATES HTDOCS CACHE ];
close F;

#
# Prepare a list of the base files to include in the default index page.
#
my $builder           =  CMapBuilder->new(
    create_readme     => 0,
    dist_abstract     => 'Genetic and comparative maps',
    dist_author       => 'Ken Y. Clark <kclark@cshl.org>',
    dist_name         => 'cmap',
    dist_version_from => 'lib/Bio/GMOD/CMap.pm',
    license           => 'gpl',
    script_files      => [ 'bin/cmap_admin.pl' ],
    sign              => 1,
    requires          => {
        'Class::Base'        => 0,
        'Config::General'    => 0,
        'Data::Page'         => 0,
        'Data::Pageset'      => 0,
        'DBI'                => 1.20,
        'File::Temp'       => 0,
        'GD'                 => 2.11,
        'GD::SVG'            => 0.25,
        'Regexp::Common'     => 0,
        'Template'           => 2.00,
        'Text::RecordParser' => 0.02,
        'Time::Piece'        => 0,
        'Time::ParseDate'    => 0,
        'XML::Simple'        => 0,
        'Cache::FileCache'   => 0,
        'Storable'           => 0,
        'Algorithm::Numerical::Sample' => 0,
        'Bit::Vector'        => 0,
        'CGI'                => 0,
        'URI::Escape'        => 0,
        'Date::Format'       => 0,
    },
    PL_files         => {
        'cgi-bin/cmap.PL'    => 'cgi-bin/cmap',
        'conf/global.conf.PL'  => 'conf/cmap.conf/global.conf',
        'lib/Bio/GMOD/CMap/Constants.pm.PL' => 'lib/Bio/GMOD/CMap/Constants.pm',
    },
);

$builder->notes($_, $OPTIONS{$_}) for qw[ CONF CGIBIN TEMPLATES HTDOCS CACHE ];

my $tarball = $builder->dist_dir . '.tar.gz';

$builder->add_to_cleanup(
    'cgi-bin/cmap',
    'conf/cmap.conf',
    'lib/Bio/GMOD/CMap/Constants.pm',
    $tarball,
    'htdocs/index.html',
    'pod2htmd.x~~',
    'pod2htmi.x~~'
);

$builder->create_build_script;

print "Now run './Build' and './Build install'\n";
print "(Other Build targets include 'html' and 'templates')\n";
exit(0);

# ----------------------------------------------------
# If others had not been foolish, we should be so.
# William Blake
# ----------------------------------------------------
