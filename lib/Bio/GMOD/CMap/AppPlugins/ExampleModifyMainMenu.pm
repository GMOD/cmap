package Bio::GMOD::CMap::AppPlugins::ExampleModifyMainMenu;

# $Id: ExampleModifyMainMenu.pm,v 1.1 2007-03-14 15:09:30 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::AppPlugins::ExampleModifyMainMenu -- Base class for gbrowse plugins.

=head1 SYNOPSIS

 package Bio::GMOD::CMap::AppPlugins::ExampleModifyMainMenu;

=head1 DESCRIPTION

This is an example plugin to modify the main menu.

=cut

use strict;
use Data::Dumper;
use Bio::GMOD::CMap::AppPlugins::AppPlugin;
use base 'Bio::GMOD::CMap::AppPlugins::AppPlugin';

use vars '$VERSION';
$VERSION = '0.01';

sub description {
    my $self = shift;
    return p("This is an example menu modifier.");
}

sub type {
    my $self = shift;
    return 'modify_main_menu';
}

sub modify_main_menu {
    my ( $self, %args ) = @_;
    my $window_key    = $args{'window_key'};
    my $app_interface = $self->app_interface();

    push @{ $app_interface->{'menu_bar_order'}{$window_key} }, 'Extras';
    $app_interface->{'menu_items'}{$window_key}{'Extras'} = [
        [   'command',
            '~Hello',
            -command => sub {
                print STDERR "Hello world\n";
            },
        ],
    ];

    return;
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

