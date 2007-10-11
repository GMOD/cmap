#!/usr/bin/perl -w
# vim: set ft=perl:

=head1 NAME

cmap_reduce_cache_size.pl - Limit the size of the query caches

=head1 SYNOPSIS

  cmap_reduce_cache_size.pl [options]

  options:
  -h|--help                 : Show this message
  -c|--config_dir           : The location of the config directory

This script will reduce the size of the query caches to the size given in the
config file as 'max_query_cache_size'.

No Options

=head1 DESCRIPTION

This script cycles through each CMap data_source and (using the
Cache::SizeAwareFileCache functionality) reduces the size of the query cache to
the value given as 'max_query_cache_size' in the config file.  

It first removes any expired entries and then if it is still over the limit, it
moves to last accessed entries.

If 'max_query_cache_size' is not set, it will use the default value in
Bio::GMOD::CMap::Constants.

It is suggested that this script is run periodically as a cron job.

=cut

use strict;
use warnings;
use Data::Dumper;
use Bio::GMOD::CMap;

use Pod::Usage;
use Getopt::Long;

my ( $help, $config_dir, );
GetOptions(
    'h|help'         => \$help,
    'c|config_dir=s' => \$config_dir,
);
pod2usage if ($help);

my $cmap_object = Bio::GMOD::CMap->new();
$cmap_object->{'config'}
    = Bio::GMOD::CMap::Config->new( config_dir => $config_dir, );

my $config_object = $cmap_object->config();

# cycle through each data_source
# and reduce the size.
for my $config_name ( @{ $config_object->get_config_names() } ) {
    print "Reducing: $config_name\n";
    $cmap_object->data_source($config_name);
    $cmap_object->control_cache_size();
}

=pod

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2005 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut
