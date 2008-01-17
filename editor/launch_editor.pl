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

$args{'highlight_string'} = '';

# To add plugins, add the plugin name to the plugins list
$args{'plugins'} = [];
if (0) {
    $args{'plugins'} = [
        'ExampleModifyMainMenu',      'ExampleModifyRightClickMenu',
        #'ExampleModifyCommitChanges', 
        'ExampleModifyStartUpMenu',
    ];
}

my $controller = Bio::GMOD::CMap::AppController->new(%args);

