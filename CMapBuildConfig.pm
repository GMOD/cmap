package CMapBuildConfig;

use strict;
use Exporter;
use File::Spec::Functions;
use vars qw(@ISA %Build @EXPORT);

@ISA     = qw(Exporter);
@EXPORT  = qw( %Build );
my $conf = './cmap_install.conf';
open( CONF, $conf ) or die "Can't read conf file '$conf': $!\n";
while ( <CONF> ) {
    chomp;
    s/\s*#.*//g;
    next unless $_;
    my ( $k, $v ) = /^(.+?)=(.+)$/;
    $Build{ $k } = $v;
}
close( CONF );

1;
