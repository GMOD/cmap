#!/usr/bin/perl -w
# Launches the editor

use strict;
use warnings;
use Data::Dumper;
use Bio::GMOD::CMap::AppController;

my %args;
$args{'data_source'} = $ARGV[0] || '';
$args{'remote_url'}  = $ARGV[1] || '';
$args{'saved_view'}  = $ARGV[2] || '';

# To add plugins, add the plugin name to the plugins list
# $args{'plugins'}     = ['ExampleModifyMainMenu','ExampleModifyRightClickMenu',];
$args{'plugins'} = [];
my $controller = Bio::GMOD::CMap::AppController->new(%args);

