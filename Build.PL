# $Id: Build.PL,v 1.31 2004-03-03 21:42:13 kycl4rk Exp $

use strict;

eval { require Module::Build };
if ( $@ =~ /Can't locate/ ) {
    print qq[Please install "Module::Build" before continuing.\n];
    exit(0);
}

use CGI;
use Cwd;
use File::Basename;
use File::Copy;
use File::Find;
use File::Path;
use File::Spec::Functions;
use Pod::Html;

my $cwd          = cwd();
my $install_conf = catfile( $cwd, 'cmap_install.conf' );

my @ARGS = qw[ PREFIX CONF CGIBIN TEMPLATES HTDOCS CACHE ];
my %ARGS = ( 
    PREFIX      => {
        desc    => 'A directory prefix for all install arguments',
        default => catdir('/', 'usr', 'local', 'apache'),
    },
    CONF        => {
        desc    => 'Location for the cmap.conf configuration file',
        default => 'conf',
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
if ( !%OPTIONS && -e $install_conf ) {
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

#
# Make sure we have usable options.
#
if ( $OPTIONS{'PREFIX'} ) {
    print "using PREFIX\n";
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
my @html_links = (
    [ '/cgi-bin/cmap/viewer', 'CMap Viewer' ],
    [ '/cgi-bin/cmap/admin', 'Web Admin Tool' ],
    [ '/cmap/tutorial/', 'User Tutorial' ],
    [ '/cmap/admintut/', 'Admin Tutorial' ],
);

#
# Turn all POD files into HTML and install into "htdocs."
#
my ( @pod_files, @cleanup );
find(
    sub {
        push @pod_files, $File::Find::name 
            if -f $_ && $File::Find::name =~ /\.pod$/;
    },
    $cwd
);

for my $pod ( @pod_files ) {
    my $filename =  basename $pod;
    my $outfile  =  $filename;
    $filename    =~ s/[_-]/ /g;
    $filename    =~ s/\.pod$//;
    $outfile     =~ s/\.pod$/\.html/;
    my $outpath  =  catfile( $cwd, 'htdocs', $outfile );
    print "pod2html $pod -> $outpath\n";
    pod2html( $pod,
        "--outfile=$outpath",
        "--backlink=Back to Top",
        "--title=$filename",
        "--css=/cmap/pod-style.css",
    );
    push @html_links, [ $outfile, $filename ];
    push @cleanup, $outpath;
}

#
# Find all the relevant "docs" and install them into "htdocs."
#
my @doc_files;
find(
    sub {
        push @doc_files, $File::Find::name 
            if -f $_ && $File::Find::name =~ /\.(png|html)$/;
    },
    'docs'
);

for my $file ( @doc_files ) {
    my $filename =  basename $file;
    my $outpath  =  catfile( $cwd, 'htdocs', $filename );
    print "$file -> $outpath\n";
    copy( $file, $outpath ) unless -e $outpath;
    push @html_links, [ $filename, $filename ];
    push @cleanup, $outpath;
}

#
# Create the main CMap index page with a summary of the install.
#
my $index = catfile( 'htdocs', 'index.html' );
open INDEX, ">$index" or die "Can't write new index file '$index': $!\n";
my $q      = CGI->new;
my $title  = 'CMap Installation Summary';
my $navbar = join( '&nbsp;|&nbsp;', 
    map { $_->[1] ? $q->a( { -href => $_->[1] }, $_->[0] ) : $q->b($_->[0]) }
    (
        [ 'CMap Home'      => '' ],
        [ 'Maps'           => '/cgi-bin/cmap/viewer' ],
        [ 'Search'         => '/cgi-bin/cmap/feature_search' ],
        [ 'Matrix'         => '/cgi-bin/cmap/matrix' ],
        [ 'Map Sets'       => '/cgi-bin/cmap/map_set_info' ],
        [ 'Feature Types'  => '/cgi-bin/cmap/feature_type_info' ],
        [ 'Map Types'      => '/cgi-bin/cmap/map_type_info' ],
        [ 'Evidence Types' => '/cgi-bin/cmap/evidence_type_info' ],
        [ 'Species'        => '/cgi-bin/cmap/species_info' ],
        [ 'Help'           => '/cgi-bin/cmap/help' ],
        [ 'Tutorial'       => '/cmap/tutorial' ],
    )
);

print "Creating htdocs/index.html\n";
print INDEX join("\n",
    $q->start_html( { -title => $title, -style => 'cmap.css' } ), 
    $q->h1( $title ),
    $q->br,
    "<!-- Here's a sample navigation bar you will probably want to use. -->",
    $navbar,
    "<!-- End CMap navbar -->",
    $q->p('Congratulations!  CMap has been installed.'),
    $q->p('Eventually you will want to create your own content '.
        'for this intro page.'),
    $q->p("At the top you'll see a sample navigation bar you may wish ".
        'to keep on this page as it links to the major CMap sections.'),
    $q->p('We would appreciate you would include an acknowlegement of CMap '.
        'on this page, e.g.:'
    ),
    $q->p(
        $q->a(
            { -href => 'http://www.gmod.org/cmap' }, 
            'CMap is free software from the GMOD project'
        )
    ),
    $q->p('For the mean time, here are some links to the installed '.
        'application and supporting docs:'),
    $q->ul(
        ( map { $q->li( $q->a({ -href => $_->[0] }, $_->[1]) ) ."\n" } 
        @html_links )
    ),
    'CMap was installed on ' . scalar localtime,
    $q->br,
    $q->a( { -href => 'http://www.gmod.org' }, 
        $q->img( { 
            -src  => 'gmod_logo.jpg', 
            -alt  => 'Powered by GMOD', 
        } )
    ),
    '<hr>',
    'Thanks for supporting the <a href="http://www.gmod.org/">GMOD</a> project!',
    $q->end_html,
    ''
);
close INDEX; 

#
# Make the text for copying the templates, CGI, and htdocs.
#
my ( $install, $installed_cmap_conf );

for my $opt ( 
    [ 'conf',      'CONF'      ],
    [ 'htdocs',    'HTDOCS'    ],
    [ 'templates', 'TEMPLATES' ],
    [ 'cgi-bin',   'CGIBIN'    ],
) {
    my ( $dir, $opt_name ) = @$opt;

    my @files;
    find( 
        sub {
            push @files, $File::Find::name
                if -f $_ && $File::Find::name !~ /CVS/
        },
        $dir
    );

    warn "WARNING:  Couldn't find anything to install in '$dir'!\n" 
        unless @files;

    my %seen;
    for my $file ( @files ) {
        $file  =~ s/\.PL$//;
        next if $seen{ $file }++;
        my $to = $OPTIONS{ $opt_name };
        if ( $file =~ /($dir)(.*)/ ) {
            $to = catdir( $to, $2 );
        }

        my $overwrite_ok = 1;

        if ( $opt_name eq 'CONF' && $file =~ /cmap\.conf$/ ) {
            $installed_cmap_conf = $to;
            $overwrite_ok        = 0;
        }

        if ( $opt_name eq 'HTDOCS' && $file =~ m{htdocs/index\.html$} ) {
            $overwrite_ok = 0;
        }

        my $extra = $overwrite_ok ? '' : 
            qq[if !-e '$to' || ].
            qq[( -e '$to' && \$self->y_n("OK to overwrite '$to'?") )];

        $install .= qq[
            \$self->copy_if_modified(
                from    => '$file',
                to      => '$to',
                flatten => 0,
            ) $extra;
        ];

        $install .= 
        qq[chmod 0755, '$to' or die "Cannot make '$to' executable: \$!\\n";\n]
        if $opt_name eq 'CGIBIN';
    }
}

#
# Make the temp dir for the images
#
$install .= qq[
    unless ( -d '$OPTIONS{CACHE}' ) {
        mkdir '$OPTIONS{CACHE}' or warn 
            "Can't create image cache dir '$OPTIONS{CACHE}': \$!\\n";
    }
    chmod 0777, '$OPTIONS{CACHE}' or warn
        "Can't chmod image cache dir '$OPTIONS{CACHE}': \$!\\n";
];

#
# Write the build script.
#
my $builder      =  Module::Build->subclass(
    class        => 'CMap::Builder',
    code         => qq[
        sub ACTION_install {
            my \$self = shift;

            $install

            \$self->SUPER::ACTION_install;

            chomp( my \$host = `hostname` || 'localhost' );
            print join("\\n\\n",
                '',
                'CMap has been installed.',
                'Be sure to edit "$installed_cmap_conf" with database info!',
                qq[Then go to "http://\$host/cmap"],
                ''       
            );
        }

        sub ACTION_realclean {
            my \$self = shift;
            \$self->delete_filetree( '$install_conf' );
            \$self->SUPER::ACTION_realclean;
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
    sign              => 1,
    requires          => {
        'Class::Base'        => 0,
        'Config::General'    => 0,
        'Data::Page'         => 0,
        'Data::Pageset'      => 0,
        'DBI'                => 1.20,
        'File::MkTemp'       => 0,
        'GD'                 => 2.11,
        'GD::SVG'            => 0.25,
        'IO::Tee'            => 0,
        'Regexp::Common'     => 0,
        'Template'           => 2.00,
        'Text::RecordParser' => 0.02,
        'Time::Piece'        => 0,
        'Time::ParseDate'    => 0,
        'XML::Simple'        => 0,
    },
    PL_files         => {
        'cgi-bin/cmap.PL'    => 'cgi-bin/cmap',
        'conf/cmap.conf.PL'  => 'conf/cmap.conf',
        'lib/Bio/GMOD/CMap/Constants.pm.PL' => 'lib/Bio/GMOD/CMap/Constants.pm',
    },
);

my $tarball = $builder->dist_dir . '.tar.gz';

$builder->add_to_cleanup(
    'cgi-bin/cmap',
    'conf/cmap.conf',
    'lib/Bio/GMOD/CMap/Constants.pm',
    @cleanup,
    $tarball,
    'htdocs/index.html',
    'pod2htmd.x~~',
    'pod2htmi.x~~'
);

$builder->create_build_script;

print qq[Now run "./Build" and "./Build install"\n];
exit(0);

# ----------------------------------------------------
# If others had not been foolish, we should be so.
# William Blake
# ----------------------------------------------------
