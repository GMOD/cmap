package Bio::GMOD::CMap::AppPlugins::ExampleModifyRightClickMenu;

# $Id: ExampleModifyRightClickMenu.pm,v 1.1 2007-04-05 15:20:20 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::AppPlugins::ExampleModifyRightClickMenu -- Base class for gbrowse plugins.

=head1 SYNOPSIS

 package Bio::GMOD::CMap::AppPlugins::ExampleModifyRightClickMenu;

=head1 DESCRIPTION

This is an example plugin to modify the right_click menu.

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
    return 'modify_right_click_menu';
}

sub modify_right_click_menu {
    my ( $self, %args ) = @_;
    my $window_key       = $args{'window_key'};
    my $menu_window      = $args{'menu_window'};
    my $app_interface    = $self->app_interface();
    my $app_display_data = $self->app_display_data();

    return
        unless (
        $app_interface->number_of_object_selections( $window_key, ) );
    $menu_window->Button(
        -text    => 'Selected Items',
        -command => sub {
            my $selected_type = $app_interface->object_selected_type(
                window_key => $window_key, );
            print STDERR "Selected Type: $selected_type\n";
            if ( $selected_type eq 'map' ) {
                print STDERR "Map Ids\n";
                foreach my $map_key (
                    $app_interface->object_selection_keys( $window_key, ) )
                {
                    print STDERR $app_display_data->{'map_key_to_id'}
                        {$map_key} . "\n";
                }
            }
            elsif ( $selected_type eq 'feature' ) {
                print STDERR "Feature Accessions\n";
                foreach my $feature_acc (
                    $app_interface->object_selection_keys(
                        window_key => $window_key,
                    )
                    )
                {
                    print STDERR "$feature_acc\n";
                }
            }

            $menu_window->destroy();
        },
    )->pack( -side => 'top', -anchor => 'nw' );

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

