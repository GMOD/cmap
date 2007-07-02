package Bio::GMOD::CMap::AppPlugins::ExampleModifyCommitChanges;

# $Id: ExampleModifyCommitChanges.pm,v 1.1 2007-07-02 15:16:29 mwz444 Exp $

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

    print STDERR Dumper($actions) . "\n";

    return 1;
}

1;

__END__


=head1 SEE ALSO


=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.
Lincoln Stein E<lt>lstein@cshl.orgE<gt>.

Copyright (c) 2007 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

