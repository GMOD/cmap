# $Id: Build.PL,v 1.61 2006-06-05 21:21:31 mwz444 Exp $

use strict;
use CMapBuilder;
use Cwd;
use File::Spec::Functions;
eval { require Module::Build };
if ( $@ =~ /Can't locate/ ) {
    print qq[Please install "Module::Build" before continuing.\n];
    exit(0);
}

# HTDOCS must be after WEB_DOCUMENT_ROOT
# CACHE and SESSIONS must be after HTDOCS
my @OPTION_LIST = qw[
    CONF
    CGIBIN
    TEMPLATES
    WEB_DOCUMENT_ROOT
    HTDOCS
    CACHE
    SESSIONS
];
my @ARGS = (qw[ PREFIX ], @OPTION_LIST);
my %ARGS = (
    PREFIX => {
        desc    => 'A directory prefix for all install arguments',
        default => catdir( '/', 'usr', 'local', 'apache' ),
    },
    CONF => {
        desc    => 'Location for the cmap.conf configuration file',
        default => catdir( 'conf', 'cmap.conf' ),
    },
    CGIBIN => {
        desc    => 'Location for CGI executables',
        default => 'cgi-bin',
    },
    TEMPLATES => {
        desc    => 'Location for CMap HTML templates',
        default => catdir( 'templates', 'cmap' ),
    },
    WEB_DOCUMENT_ROOT => {
        desc    => 'Location of web document root',
        default => catdir( 'htdocs' ),
    },
    HTDOCS => {
        desc    => 'Location for static files',
        default => catdir( 'cmap' ),
    },
    CACHE => {
        desc    => 'Location for temporary image files',
        default => catdir('tmp'),
    },
    SESSIONS => {
        desc    => 'Location for session files',
        default => catdir('tmp', 'sessions'),
    },
);

my $OPTIONS = join( '|', @ARGS );
my %OPTIONS;

my $USAGE = join(
    "\n",
    'To customize install locations, provide one or more of the options ',
    '',
    join(
        "\n",
        map {
            sprintf(
                "%18s: %-s\n\t\t(default: %s%s)\n",
                $_,
                $ARGS{$_}{'desc'},
                $_ eq 'PREFIX' ? ''
                : ( $_ eq 'HTDOCS' )
                ? '$PREFIX + $WEB_DOCUMENT_ROOT + '
                : ( $_ eq 'CACHE' or $_ eq 'SESSIONS' )
                ? '$HTDOCS + '
                : '$PREFIX + ',
                $ARGS{$_}{'default'}
                )
            } @ARGS
    ),
    "e.g., 'perl Build.PL PREFIX=/usr/local/apache'",
    '',
    ''
);

#
# Process command-line args.
#
my @argv = @ARGV;
foreach (@argv) {
print STDERR "$OPTIONS \n$_\n";
    if (/^--?h(elp)?/i) {
        print $USAGE;
        exit(0);
    }
    elsif (/($OPTIONS)=(.+)/og) {
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
            "It looks like you have installed cmap before.\n"
              . "Should I use the settings in '"
              . $install_conf . "'?",
            'y'
        );

        if ($yes) {
            print "Using previous settings from '$install_conf.'\n";
            open F, $install_conf or die "Can't read '$install_conf: $!\n";
            while (<F>) {
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
my $prefix = $OPTIONS{'PREFIX'} || $ARGS{'PREFIX'}{'default'};

for my $option (@OPTION_LIST) {

    if ( $option eq 'HTDOCS' ) {
        $OPTIONS{$option} ||= catdir( $OPTIONS{'WEB_DOCUMENT_ROOT'}, $ARGS{$option}{'default'} );
    }
    elsif ( $option eq 'CACHE' or $option eq 'SESSIONS' ) {
        $OPTIONS{$option} ||= catdir( $OPTIONS{'HTDOCS'}, $ARGS{$option}{'default'} );
    }
    else {
        $OPTIONS{$option} ||= catdir( $prefix, $ARGS{$option}{'default'} );
    }
}

print "The following options will be used to install CMap:\n", join(
    "\n", '',
    (
        map { sprintf( "%18s: %-s", $_, $OPTIONS{$_} ) }
         @OPTION_LIST
    ),
    '',
    ''
  ),
  ;

#
# Write out our current config options.
#
open F, ">$install_conf" or warn "Can't write '$install_conf': $!\n";
print F "$_=$OPTIONS{$_}\n" for @OPTION_LIST;
close F;

#
# Prepare a list of the base files to include in the default index page.
#
my $builder = CMapBuilder->new(
    create_readme     => 0,
    dist_abstract     => 'Genetic and comparative maps',
    dist_author       => 'Ken Y. Clark <kclark@cshl.org>',
    dist_name         => 'cmap',
    dist_version_from => 'lib/Bio/GMOD/CMap.pm',
    license           => 'gpl',
    script_files      => ['bin/cmap_admin.pl'],
    sign              => 1,
    requires          => {
        'Algorithm::Numerical::Sample' => 0,
        'Apache::Htpasswd'             => 0,
        'Bit::Vector'                  => 0,
        'Cache::Cache'                 => 0,
        'CGI'                          => 0,
        'CGI::Session'                 => 0,
        'Class::Base'                  => 0,
        'Clone'                        => 0,
        'Config::General'              => 0,
        'Data::Dumper'                 => 0,
        'Date::Format'                 => 0,
        'Data::Page'                   => 0,
        'Data::Pageset'                => 0,
        'Data::Stag'                   => 0,
        'DBI'                          => 1.20,
        'Digest::MD5'                  => 0,
        'File::Temp'                   => 0,
        'Filesys::Df'                  => 0,
        'GD'                           => 2.11,
        'GD::SVG'                      => 0.25,
        'IO::Tee'                      => 0,
        'Params::Validate'             => 0,
        'Regexp::Common'               => 0,
        'Storable'                     => 0,
        'Template'                     => 2.00,
        'Template::Plugin::Comma'      => 0,
        'Text::RecordParser'           => 0.02,
        'Time::ParseDate'              => 0,
        'Time::Piece'                  => 0,
        'URI::Escape'                  => 0,
        'XML::Parser::PerlSAX'         => 0,
        'XML::Simple'                  => 0,
    },
    recommends => {
        'Apache'    => 0,
        'Bio::Perl' => 0,
    },
    PL_files => {
        'cgi-bin/cmap.PL'                   => 'cgi-bin/cmap',
        'conf/global.conf.PL'               => 'conf/cmap.conf/global.conf',
        'lib/Bio/GMOD/CMap/Constants.pm.PL' =>
            'lib/Bio/GMOD/CMap/Constants.pm',
    },
);

$builder->notes( $_, $OPTIONS{$_} )
  for @OPTION_LIST;

my $tarball = $builder->dist_dir . '.tar.gz';

$builder->add_to_cleanup( 'cgi-bin/cmap', 'conf/cmap.conf',
    'lib/Bio/GMOD/CMap/Constants.pm',
    $tarball, 'htdocs/index.html', 'pod2htmd.x~~', 'pod2htmi.x~~' );

$builder->create_build_script;

print "Now run './Build' and './Build install'\n";
print "(Other Build targets include 'html' and 'templates')\n";
exit(0);

# ----------------------------------------------------
# If others had not been foolish, we should be so.
# William Blake
# ----------------------------------------------------
