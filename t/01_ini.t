#!/usr/bin/perl -w

# $Id: 01_ini.t,v 1.3 2003-01-23 18:51:55 kycl4rk Exp $

#
# CMap test suite
#
# Very simple testing right now.  I'm hard pressed to come up with 
# good tests given that the application is so heavily dependent on 
# a database and mainly produces visual output that can't be easily
# verified with automated tests.
#

use strict;
use Test::More 'no_plan';
use Template;

use lib '../lib';
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Data;

my $cmap = Bio::GMOD::CMap->new;
isa_ok( $cmap, 'Bio::GMOD::CMap', 'CMap' );

my $t = $cmap->template;
isa_ok( $t, 'Template', 'Template' );

my $data = $cmap->data_module;
isa_ok( $data, 'Bio::GMOD::CMap::Data', 'Data module' );

my $apache = Bio::GMOD::CMap::Apache->new;
isa_ok( $apache, 'Bio::GMOD::CMap::Apache', 'Apache module' );
