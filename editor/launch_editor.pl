#!/usr/bin/perl -w
# Launches the editor

use strict;
use warnings;
use Data::Dumper;
use Bio::GMOD::CMap::AppController;

my %args;
$args{'data_source'}=$ARGV[0]||'';
my $controller = Bio::GMOD::CMap::AppController->new(%args);

