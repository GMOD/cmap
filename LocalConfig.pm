package LocalConfig;

use strict;
use Exporter;
use vars qw(@ISA %Local @EXPORT);

@ISA    = qw(Exporter);
@EXPORT = qw( %Local );

open( CONF, 'cmap_install.conf' ) ;
while ( <CONF> ) {
    chomp;
    s/\s*#.*//g;
    next unless $_;
    my ( $k, $v ) = /^(.+?)=(.+)$/;
    $Local{ $k } = $v;
}
close( CONF );

1;
