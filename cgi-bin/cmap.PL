#!perl
use Config;
use File::Basename qw(&basename &dirname);
use File::Spec::Functions;

my $dir = dirname($0);
$file   = shift || catfile( $dir, basename( $0, '.PL','.PLS' ) );

open OUT, ">$file" or die "Can't write to file '$file': $!";

my $startperl = $Config{'startperl'} ne '#!perl'
  ? $Config{'startperl'}
  : "#!$Config{'perlpath'}";

print OUT "$startperl\n";
print OUT q[
use strict;
use Bio::GMOD::CMap::Apache;

eval { Bio::GMOD::CMap::Apache::handler(); };

if ( my $err = $@ ) {
    print "Content-type: text/plain\n\nError: $err";
}
];
close OUT or die "Can't close file '$file': $!\n";