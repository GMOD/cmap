#!/usr/bin/perl

=head1 NAME

cmap_netinstall.pl

=head1 SYNOPSIS

  cmap_netinstall.pl -b|--build_param_str BUILD_STRING [options] 

  options:
  -h|--help            : Show this message
  -d|--dev             : Use the developement version from SourceForge CVS
  -b|--build_param_str : Use this string to predefine Build.PL parameters
                         such as CONF or PREFIX

=head1 DESCRIPTION

Net-based installer of CMap

Save this to disk as "cmap_netinstall.pl" and run:

   perl cmap_netinstall.pl

=cut

use warnings;
use strict;
use Config;
use Getopt::Long;
use Pod::Usage;

my ( $show_help, $get_from_cvs, $build_param_string, );

BEGIN {

    GetOptions(
        'h|help'              => \$show_help,             # Show help and exit
        'd|dev'               => \$get_from_cvs,          # Use the dev cvs
        'b|build_param_str=s' => \$build_param_string,    # Build parameters
        )
        or pod2usage(2);
    pod2usage(2) if $show_help;
    print STDERR "\nAbout to install CMap and all its prerequisites.\n";
    print STDERR
        "\nYou will be asked various questions during this process. You can almost always accept the default answer.\n";
    print STDERR
        "The whole process will take several minutes and will generate lots of messages.\n";
    print STDERR "\nPress return when you are ready to start!\n";
    my $h = <>;
    print STDERR
        "*** Installing Perl files needed for a net-based install ***\n";
    eval << 'END';
    use CPAN '!get';
    eval "use CPAN::Config";
    if ($@) {
        CPAN::Shell->Config();
    }

    CPAN::Shell->install('LWP::Simple');
    CPAN::Shell->install('Archive::Zip');
    CPAN::Shell->install('Archive::Tar');
    CPAN::Shell->install('IO::Zlib');
    CPAN::HandleConfig->commit;
END
}

use File::Temp qw(tempdir);
use LWP::Simple;
use Archive::Zip ':ERROR_CODES';
use Archive::Tar;
use File::Copy 'cp';
use CPAN '!get';

use constant CMAP_DEFAULT => '0.16';

#use constant SOURCEFORGE_MIRRORS => [
#'http://superb-west.dl.sourceforge.net/sourceforge/gmod/',
#'http://easynews.dl.sourceforge.net/sourceforge/gmod/',
#];
use constant SOURCEFORGE_CMAP =>
    'http://sourceforge.net/project/showfiles.php?group_id=27707&package_id=55129';
use constant NMAKE =>
    'http://download.microsoft.com/download/vc15/patch/1.52/w95/en-us/nmake15.exe';

my %REPOSITORIES = (
    'Kobes'  => 'http://theoryx5.uwinnipeg.ca/ppms',
    'Bribes' => 'http://www.Bribes.org/perl/ppm'
);

my $binaries = $Config{'binexp'};
my $make     = $Config{'make'};

# this is so that ppm can be called in a pipe
$ENV{COLUMNS} = 80;    # why do we have to do this?
$ENV{LINES}   = 24;

my $tmpdir = tempdir( CLEANUP => 1 )
    or die "Could not create temporary directory: $!";
my $windows = $Config{osname} =~ /mswin/i;

if ( $windows && !-e "$binaries/${make}.exe" ) {

    print STDERR "Installing make utility...\n";

    -w $binaries
        or die
        "$binaries directory is not writeable. Please re-login as Admin.\n";

    chdir $tmpdir;

    my $rc = mirror( NMAKE, "nmake.zip" );
    die "Could not download nmake executable from Microsoft web site."
        unless $rc == RC_OK
        or $rc == RC_NOT_MODIFIED;

    my $zip = Archive::Zip->new('nmake.zip')
        or die "Couldn't open nmake zip file for decompression: $!";
    $zip->extractTree == AZ_OK or die "Couldn't unzip file: $!";
    -e 'NMAKE.EXE'             or die "Couldn't extract nmake.exe";

    cp( 'NMAKE.EXE', "$binaries/${make}.EXE" )
        or die "Couldn't install nmake.exe: $!";
    cp( 'NMAKE.ERR', "$binaries/${make}.ERR" )
        ;    # or die "Couldn't install nmake.err: $!"; # not fatal
}

setup_ppm() if $windows;

unless ( eval "use GD 2.35; 1" ) {
    if ($windows) {
        print STDERR "Installing GD via ppm.\n";
        print STDERR "(This may take a while...\n";
        system("ppm install GD");
    }
    else {
        print STDERR "Installing GD via CPAN...\n";
        if ( installed_or_install('GD') ) {
            print STDERR "GD is installed.\n";
        }
        else {
            die "GD could not be installed.\n"
                . "Please install and try again\n";
        }
    }
}

print STDERR "\n*** Installing prerequisites for CMap ***\n";

foreach my $module (
    'Algorithm::Numerical::Sample', 'Apache::Htpasswd',
    'Bit::Vector',                  'Cache::Cache',
    'CGI',                          'CGI::Session',
    'Class::Base',                  'Clone',
    'Config::General',              'Data::Dumper',
    'Date::Format',                 'Data::Page',
    'Data::Pageset',                'Data::Stag',
    'DBI',                          'Digest::MD5',
    'File::Temp',                   'Filesys::DfPortable',
    'GD',                           'GD::SVG',
    'IO::Tee',                      'IO::Tee',
    'Module::Build',                'Params::Validate',
    'Regexp::Common',               'Storable',
    'Template',                     'Template::Plugin::Comma',
    'Text::RecordParser',           'Time::ParseDate',
    'Time::Piece',                  'URI::Escape',
    'XML::Parser::PerlSAX',         'XML::Simple',
    )
{
    if ( installed_or_install($module) ) {
        print STDERR "$module is installed.\n";
    }
    else {
        die "$module could not be installed.\n"
            . "Please install and try again\n";
    }
}

my $cmap_dir = '';
my $problem  = 0;
print STDERR "\n *** Downloading CMap ***\n";
eval { $cmap_dir = do_get_distro( $get_from_cvs, ) };
if ( !$cmap_dir ) {
    print STDERR "Failed to get distribution\n";
    exit 0;
}
print STDERR "\n *** Installing CMap ***\n";
eval { do_install( $cmap_dir, 'Build', $build_param_string, ) };

exit 0;

END {
    open STDERR, ">/dev/null"
        ;    # windows has an annoying message when cleaning up temp file
}

sub do_get_distro {
    my ( $get_from_cvs, ) = @_;
    chdir $tmpdir;
    my $local_name = 'cmap.tgz';
    if ($get_from_cvs) {
        my $distribution_dir = "cmap";
        print STDERR "Please, press return when prompted for a password.\n";
        unless (
            system(
                'cvs -d:pserver:anonymous@gmod.cvs.sourceforge.net:/cvsroot/gmod login'
                    . ' && '
                    . 'cvs -z3 -d:pserver:anonymous@gmod.cvs.sourceforge.net:/cvsroot/gmod co -P cmap'
            ) == 0
            )
        {
            print STDERR "Failed to check out the CMap module from CVS: $!\n";
            return undef;
        }

        unless ( chdir $distribution_dir ) {
            print STDERR "Couldn't enter $distribution_dir directory: $!";
            return undef;
        }

        return $distribution_dir;
    }
    else {
        my $distribution_dir = find_cmap_latest();
        my @mirrors          = (
            'http://superb-west.dl.sourceforge.net/sourceforge/gmod/',
            'http://easynews.dl.sourceforge.net/sourceforge/gmod/',
        );
        foreach my $mirror (@mirrors) {
            my $cmap_file_name = $mirror . $distribution_dir . '.tar.gz';
            if (do_get_static_distro(
                    $cmap_file_name, $local_name, $distribution_dir
                )
                )
            {
                return $distribution_dir;
            }
        }
        return undef;
    }
    return undef;
}

sub do_get_static_distro {
    my ( $download, $local_name, $distribution_dir, ) = @_;
    chdir $tmpdir;
    print STDERR "Downloading $download...\n";
    my $rc = mirror( $download, $local_name );
    unless ( $rc == RC_OK or $rc == RC_NOT_MODIFIED ) {
        print STDERR
            "Could not download $distribution_dir distribution from $download.";
        return 0;
    }

    print STDERR "Unpacking $local_name...\n";
    my $z;
    unless ( $z = Archive::Tar->new( $local_name, 1 ) ) {
        print STDERR "Couldn't open $distribution_dir archive: $!";
        return 0;
    }
    unless ( $z->extract() ) {
        print STDERR "Couldn't extract $distribution_dir archive: $!";
        return 0;
    }
    unless ( chdir $distribution_dir ) {
        print STDERR "Couldn't enter $distribution_dir directory: $!";
        return 0;
    }
    return 1;
}

sub do_install {
    my ( $distribution_dir, $method, $build_param_string, ) = @_;
    $build_param_string ||= '';

    print STDERR "Installing $distribution_dir\n";

    chdir $tmpdir;

    chdir $distribution_dir
        or die "Couldn't enter $distribution_dir directory: $!";

    if ( $method eq 'make' ) {
        system("perl Makefile.PL") == 0
            or die "Couldn't run perl Makefile.PL command\n";
        system("$make install") == 0;    #        or die "Couldn't install\n";
    }
    elsif ( $method eq 'Build' ) {
        system("perl ./Build.PL $build_param_string") == 0
            or die "Couldn't run perl Build.PL command\n";
        system("./Build ") == 0
            or die "Couldn't run ./Build command\n";
        system("./Build install") == 0;
    }
}

# make sure ppm repositories are correct!
sub setup_ppm {
    open S, "ppm repo list --csv|" or die "Couldn't open ppm for listing: $!";
    my %repository;
    while (<S>) {
        chomp;
        my ( $index, $package_count, $name ) = split /,/;
        $repository{$name} = $index;
    }
    close S;
    print STDERR
        "Adding needed PPM repositories. This may take a while....\n";
    for my $name ( keys %REPOSITORIES ) {
        next if $repository{$name};
        system("ppm rep add $name $REPOSITORIES{$name}");
    }
}

sub find_cmap_latest {
    print STDERR "Looking up most recent version...";
    my $download_page = get(SOURCEFORGE_CMAP);
    my @files         = $download_page =~ /(cmap--?\d+\.\d+)/g;
    my %versions      = map { /(\d+\.\d+)/ => $_ } @files;
    my @versions      = sort { $b <=> $a } keys %versions;
    my $version       = $versions[0] || CMAP_DEFAULT;
    print STDERR $version, "\n";
    return $versions{$version};
}

sub installed_or_install {
    my $module = shift;
    if ( eval "require $module" ) {
        return 1;
    }
    else {
        CPAN::Shell->install($module);
        if ( eval "require $module" ) {
            return 1;
        }
        else {
            print STDERR "$@\n";
            return 0;
        }
    }
    return 0;
}
