package Bio::GMOD::CMap::AppPlugins::ExampleModifyCommitChanges;

# $Id: ExampleModifyCommitChanges.pm,v 1.3 2007-12-12 22:18:45 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::AppPlugins::ExampleModifyCommitChanges 

=head1 SYNOPSIS

 package Bio::GMOD::CMap::AppPlugins::ExampleModifyCommitChanges;

=head1 DESCRIPTION

This is an example plugin to modify the commit changes function.

The modify_commit_changes must return 1 if the commit is to proceed.

=cut

use strict;
use Data::Dumper;
use Bio::GMOD::CMap::AppPlugins::AppPlugin;
use base 'Bio::GMOD::CMap::AppPlugins::AppPlugin';

use vars '$VERSION';
$VERSION = '0.01';

sub description {
    my $self = shift;
    return p("This is an example commit changes modifier.");
}

sub type {
    my $self = shift;
    return 'modify_commit_changes';
}

sub modify_commit_changes {
    my ( $self, %args ) = @_;
    my $window_key       = $args{'window_key'};
    my $actions          = $args{'actions'};
    my $app_interface    = $self->app_interface();
    my $app_display_data = $self->app_display_data();

    #print STDERR Dumper($actions) . "\n";

    return 1;
}

1;

__END__


=head1 SEE ALSO


=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.
Lincoln Stein E<lt>lstein@cshl.orgE<gt>.

Copyright (c) 2007 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

