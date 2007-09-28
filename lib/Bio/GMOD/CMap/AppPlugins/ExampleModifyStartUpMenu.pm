package Bio::GMOD::CMap::AppPlugins::ExampleModifyStartUpMenu;

# $Id: ExampleModifyStartUpMenu.pm,v 1.2 2007-09-28 20:17:10 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::AppPlugins::ExampleModifyStartUpMenu -- Base class for gbrowse plugins.

=head1 SYNOPSIS

 package Bio::GMOD::CMap::AppPlugins::ExampleModifyStartUpMenu;

=head1 DESCRIPTION

This is an example plugin to modify the start_up menu.

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
    return 'modify_start_up_menu';
}

sub modify_start_up_menu {
    my ( $self, %args ) = @_;
    my $button_items = $args{'button_items'};

    # Using Attributes Example
    push @{$button_items}, {
        -text    => 'Simple Exit',
        -command => sub {
            exit;
        },
    };

    return;
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

