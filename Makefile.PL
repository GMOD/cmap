use File::Copy;
use File::Path;
use ExtUtils::MakeMaker qw[ prompt WriteMakefile ];

my $template_dir = get_path(
    'Where would you like the HTML templates installed?'
);

my $script_dir = get_path(
    'Where would you like the command-line scripts installed?'
);

#
# Copy the templates.
#
my $template_src = './templates';
opendir DIR, $template_src;
my @templates = readdir DIR;
close DIR;
print "Copying templates from $template_src to $template_dir\n";
copy( $template_src.'/'.$_, $template_dir) for @templates;

WriteMakefile(
    NAME          => 'CSHL::CMap',
    VERSION       => '0.02',
    AUTHOR        => 'Ken Y. Clark (kclark@cshl.org)',
    ABSTRACT      => 'Modules for drawing comparative genomic maps.',
    EXE_FILES     => [ 'bin/cmap_admin.pl' ],
    INSTALLSCRIPT => $script_dir,
    PREREQ_PM     => {
        Apache          => 1.27,
        Apache::Cookie  => 0,
        Apache::Request => 1.0,
        Class::Base     => 0.03,
        DBI             => 1.23,
        Error           => 0.15,
        File::MkTemp    => 1.06,
        GD              => 1.40,
        Template        => 2.07,
    },
);

print "Change CSHL::CMap::Constants TEMPLATE_DIR => $template_dir\n";
print "To load your data, run '$script_dir/cmap_admin.pl'\n";

# ----------------------------------------------------
sub get_path {
    my $prompt = shift;
    my $path;

    while ( 1 ) {
        $path = prompt $prompt;
        if ( -e $path ) {
            last;
        }
        else {
            print qq[Directory "$path" doesn't exist.  Create? [y/n] ];
            chomp( my $answer = <STDIN> );
            if ( lc $answer eq 'y' ) {
                mkpath( $path, 0, 0711 ) or die qq[Can't make path "$path": $!];
                last;
            }
        }
    }

    return $path;
}
