# $Id: 01_ini.t,v 1.5 2003-09-19 19:09:02 kycl4rk Exp $

use strict;
use Test::More tests => 3;
use Template;

use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Data;

my $cmap = Bio::GMOD::CMap->new;
isa_ok( $cmap, 'Bio::GMOD::CMap', 'CMap' );

my $data = $cmap->data_module;
isa_ok( $data, 'Bio::GMOD::CMap::Data', 'Data module' );

my $apache = Bio::GMOD::CMap::Apache->new;
isa_ok( $apache, 'Bio::GMOD::CMap::Apache', 'Apache module' );
