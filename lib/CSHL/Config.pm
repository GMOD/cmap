package CSHL::Config; 

use strict;

use base qw( Exporter );
use vars qw( @EXPORT  );
require Exporter;

@EXPORT = qw[ 
    MapV3DataSource
    MapV3DBUser
    MapV3DBPassword 
    MapV3DBOptions 
];

#
# Comparative map database connection info.
#
use constant MapV3DataSource => 'dbi:mysql:FOO';
use constant MapV3DBUser     => 'user';
use constant MapV3DBPassword => 'password';
use constant MapV3DBOptions  => {
    RaiseError       => 1,
    FetchHashKeyName => 'NAME_lc',
    LongReadLen      => 3000,
    LongTruncOk      => 1,
};

1;

=pod

=head1 NAME

CSHL::Config - General config module

=head1 SYNOPSIS

  use CSHL::Config;
  $self->{'db'} = DBI->connect( 
      MapDataSource,
      MapDBUser,
      MapDBPassword,
      MapDBOptions,
  );

=head1 DESCRIPTION

=cut
