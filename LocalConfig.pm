package LocalConfig;

use strict;
use Exporter;
use File::Spec::Functions;
use vars qw(@ISA %Local @EXPORT);

@ISA     = qw(Exporter);
@EXPORT  = qw( %Local );
my $conf = './cmap_install.conf';
open( CONF, $conf ) or die "Can't read conf file '$conf': $!\n";
while ( <CONF> ) {
    chomp;
    s/\s*#.*//g;
    next unless $_;
    my ( $k, $v ) = /^(.+?)=(.+)$/;
    $Local{ $k } = $v;
}
close( CONF );

1;
