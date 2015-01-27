# $Id: Build.PL,v 1.74 2008-03-11 14:52:00 mwz444 Exp $

use strict;
use lib './install_util';
use CMapBuilder;
use Cwd;
use FindBin;
use File::Spec::Functions;
eval { require Module::Build };
if ( $@ =~ /Can't locate/ ) {
    print qq[Please install "Module::Build" before continuing.\n];
    exit(0);
}

# CACHE and SESSIONS must be after HTDOCS
my @OPTION_LIST = qw[
  CONF
  CGIBIN
  TEMPLATES
  HTDOCS
  CACHE
  SESSIONS
];
my @ARGS = ( qw[ PREFIX ], @OPTION_LIST );
my %ARGS = (
    PREFIX => {
        desc    => 'A directory prefix for all install arguments',
        default => $FindBin::Bin
    },
    CONF => {
        desc    => 'Location for the cmap configuration files',
        default => 'conf',
    },
    CGIBIN => {
        desc    => 'Location for CGI executables',
        default => 'cgi-bin',
    },
    TEMPLATES => {
        desc    => 'Location for CMap HTML templates',
        default => catdir( 'templates', 'cmap' ),
    },
    HTDOCS => {
        desc    => 'Location for static files',
        default => 'htdocs',
    },
    CACHE => {
        desc    => 'Location for temporary image files',
        default => 'tmp',
    },
    SESSIONS => {
        desc    => 'Location for session files',
        default => catdir( 'tmp', 'sessions' ),
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
                : ( $_ eq 'HTDOCS' ) ? '$PREFIX + '
                : ( $_ eq 'CACHE' or $_ eq 'SESSIONS' ) ? '$HTDOCS + '
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
my $using_install_conf = 0;
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
            $using_install_conf = 1;
        }
    }
    else {
        print "No arguments to Build.PL.  Using defaults.\n",
          "Execute 'perl Build.PL --help' for help.\n";
    }
}

unless ($using_install_conf) {

    #
    # Make sure we have usable options.
    #
    my $prefix = $OPTIONS{'PREFIX'} || $FindBin::Bin;

    # Backwards compatiple for if "cmap.conf" is specified at end of CONF
    if ( $OPTIONS{'CONF'} ) {
        $OPTIONS{'CONF'} =~ s{cmap.conf[/\\]?$}{};
        $OPTIONS{'CONF'} = catdir( $OPTIONS{'CONF'}, 'cmap.conf' );
    }

    if ($prefix) {
        $OPTIONS{'CONF'}   ||= catdir( $prefix, $ARGS{'CONF'}{'default'} );
        $OPTIONS{'CGIBIN'} ||= catdir( $prefix, $ARGS{'CGIBIN'}{'default'} );
        $OPTIONS{'TEMPLATES'} ||=
          catdir( $prefix, $ARGS{'TEMPLATES'}{'default'} );
    }

    # These options are dependent on other options
    $OPTIONS{'HTDOCS'} ||=
      catdir( $prefix, $ARGS{'HTDOCS'}{'default'} );
    $OPTIONS{'CACHE'} ||=
      catdir( $OPTIONS{'HTDOCS'}, $ARGS{'CACHE'}{'default'} );
    $OPTIONS{'SESSIONS'} ||=
      catdir( $OPTIONS{'HTDOCS'}, $ARGS{'SESSIONS'}{'default'} );

    print "The following install options have been inferred:\n",
      join( "\n",
        '', ( map { sprintf( "%18s: %-s", $_, $OPTIONS{$_} ) } @OPTION_LIST ),
        '', '' ),
      ;

    # Let the user define them if they need to.
    my $use_values = Module::Build->y_n( "Use these values?", 'y' );
    if ( !$use_values ) {
        foreach
            my $opt ( 'CONF', 'CGIBIN', 'TEMPLATES' )
        {
            $OPTIONS{$opt} = Module::Build->prompt(
                "$opt: "
                    . $ARGS{$opt}->{'desc'} . "\n"
                    . "What should the value of $opt be?\n",
                $OPTIONS{$opt},
            );
        }
        $OPTIONS{'HTDOCS'} = Module::Build->prompt(
            "HTDOCS: "
                . $ARGS{'HTDOCS'}->{'desc'} . "\n"
                . "What should the value of HTDOCS be?\n",
            catdir(
                $ARGS{'HTDOCS'}{'default'}
            )
        );
        $OPTIONS{'CACHE'} = Module::Build->prompt(
            "CACHE: "
                . $ARGS{'CACHE'}->{'desc'} . "\n"
                . "What should the value of CACHE be?\n",
            catdir( $OPTIONS{'HTDOCS'}, $ARGS{'CACHE'}{'default'} )
        );
        $OPTIONS{'SESSIONS'} = Module::Build->prompt(
            "SESSIONS: "
                . $ARGS{'SESSIONS'}->{'desc'} . "\n"
                . "What should the value of SESSIONS be?\n",
            catdir( $OPTIONS{'HTDOCS'}, $ARGS{'SESSIONS'}{'default'} )
        );
    }
}

print "The following options will be used to install CMap:\n",
  join( "\n",
    '', ( map { sprintf( "%18s: %-s", $_, $OPTIONS{$_} ) } @OPTION_LIST ),
    '', '' ),
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
    script_files      => [
        'bin/cmap_admin.pl',
        'bin/cmap_create_stacked_maps.pl',
        'bin/cmap_data_diagnostics.pl',
        'bin/cmap_examine_attribute.pl',
        'bin/cmap_fix_map_display_order.pl',
        'bin/cmap_import_alignment.pl',
        'bin/cmap_manageParsedAceFile.pl',
        'bin/cmap_matrix_compare.pl',
        'bin/cmap_metrics.pl',
        'bin/cmap_parseagp.pl',
        'bin/cmap_parsefpc.pl',
        'bin/cmap_parseWashUAceFiles.pl',
        'bin/cmap_reduce_cache_size.pl',
        'bin/cmap_validate_config.pl',
        'bin/cmap_validate_import_file.pl',
    ],
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
        'Data::Page'                   => 0,
        'Data::Pageset'                => 0,
        'Data::Stag'                   => 0,
        'DBI'                          => 1.20,
        'Filesys::DfPortable'          => 0,
        'GD'                           => 2.11,
        'GD::SVG'                      => 0.25,
        'IO::Tee'                      => 0,
        'IO::Tee'                      => 0,
        'Module::Build'                => .28,
        'Params::Validate'             => 0,
        'Regexp::Common'               => 0,
        'Template'                     => 2.00,
        'Template::Plugin::Comma'      => 0,
        'Text::RecordParser'           => 0.02,
        'Time::ParseDate'              => 0,
        'Time::Piece'                  => 0,
        'URI::Escape'                  => 0,
        'XML::Simple'                  => 0,
    },
    recommends => { 
        'DBD::SQLite',                 => 0,
    },
);

$builder->notes( $_, $OPTIONS{$_} ) for @OPTION_LIST;

my $tarball = $builder->dist_dir . '.tar.gz';

$builder->add_to_cleanup( 'conf/cmap.conf',
    $tarball, 'pod2htmd.x~~', 'pod2htmi.x~~' );

$builder->create_build_script;

print <<END;
Now run './Build'.

Afterwards, execute './Build test' to run the pre-installation tests
(requires DBD::SQLite).

If you specified a non-default install directory (outside $FindBin::Bin),
execute './Build install' to install CMap files. The post-installation tests
can then be run with './Build post_install_test' (requires DBD::MySQL).

(Other Build targets include 'html' and 'templates').
END
exit(0);

sub ask_about_dir {
    my $prompt = shift;
    while (1) {
        my $answer = Module::Build->prompt( $prompt . "\n", 'quit', );
        exit(0) if ( $answer =~ /^q$/i or $answer =~ /^quit$/i );
        return $answer if ( -d $answer );
        print "\n$answer is not a directory.\n";
    }
}

# ----------------------------------------------------
# If others had not been foolish, we should be so.
# William Blake
# ----------------------------------------------------
