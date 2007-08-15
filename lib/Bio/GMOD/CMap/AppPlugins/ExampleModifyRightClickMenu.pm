package Bio::GMOD::CMap::AppPlugins::ExampleModifyRightClickMenu;

# $Id: ExampleModifyRightClickMenu.pm,v 1.7 2007-08-15 20:45:27 mwz444 Exp $

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
    my $window_key        = $args{'window_key'};
    my $menu_items        = $args{'menu_items'};
    my $report_menu_items = $args{'report_menu_items'};
    my $app_interface     = $self->app_interface();
    my $app_display_data  = $self->app_display_data();
    my $app_data_module   = $self->data_module();

    return
        unless (
        $app_interface->number_of_object_selections( $window_key, ) );

    # Using Attributes Example
    push @{$menu_items}, [
        Button   => 'Use Search Terms',
        -command => sub {
            my $selected_type = $app_interface->object_selected_type(
                window_key => $window_key, );
            my @urls;
            my $template_processor = $self->template;
            if ( $selected_type eq 'map' ) {
                foreach my $map_key (
                    $app_interface->object_selection_keys( $window_key, ) )
                {
                    my $map_id = $app_display_data->map_key_to_id($map_key);

                    # Get the Attributes
                    my $attribs
                        = $app_display_data->app_data_module()
                        ->generic_get_data(
                        method_name => 'get_attributes',
                        parameters  => {
                            object_id      => $map_id,
                            object_type    => 'map',
                            attribute_name => "search_term",
                        },
                        );
                    next unless ( @{ $attribs || [] } );

                    my @search_terms;
                    foreach my $attrib ( @{ $attribs || [] } ) {
                        push @search_terms, $attrib->{'attribute_value'};
                    }
                    next unless (@search_terms);
                    my $url = "http://www.google.com/search?q="
                        . join( '+', @search_terms );
                    push @urls, $url;
                }
            }
            elsif ( $selected_type eq 'feature' ) {
                foreach my $feature_acc (
                    $app_interface->object_selection_keys(
                        window_key => $window_key,
                    )
                    )
                {
                    my $feature_data = $app_display_data->app_data_module()
                        ->feature_data( feature_acc => $feature_acc, );
                    my $feature_id = $feature_data->{'feature_id'};

                    # Get the Xrefs
                    my $attribs
                        = $app_display_data->app_data_module()
                        ->generic_get_data(
                        method_name => 'get_attributes',
                        parameters  => {
                            object_id      => $feature_id,
                            object_type    => 'feature',
                            attribute_name => "search_term",
                        },
                        );
                    next unless ( @{ $attribs || [] } );

                    my @search_terms;
                    foreach my $attrib ( @{ $attribs || [] } ) {
                        push @search_terms, $attrib->{'attribute_value'};
                    }
                    next unless (@search_terms);
                    my $url = "http://www.google.com/search?q="
                        . join( '+', @search_terms );
                    push @urls, $url;
                }
            }
            if (@urls) {
                foreach my $url (@urls) {
                    system( "/usr/bin/firefox " . $url );
                }
            }
            else {
                $self->app_interface->popup_warning( text =>
                        "There are no search terms attached to the object(s).\n",
                );
            }
        },
    ];

    # External Links Example
    push @{$menu_items}, [
        Button   => 'Open External Links',
        -command => sub {
            my $selected_type = $app_interface->object_selected_type(
                window_key => $window_key, );
            my @urls;
            my $template_processor = $self->template;
            if ( $selected_type eq 'map' ) {
                foreach my $map_key (
                    $app_interface->object_selection_keys( $window_key, ) )
                {
                    my $map_id = $app_display_data->map_key_to_id($map_key);

                    # Get the Xrefs
                    my $xrefs
                        = $app_display_data->app_data_module()
                        ->generic_get_data(
                        method_name => 'get_xrefs',
                        parameters  => {
                            object_id   => $map_id,
                            object_type => 'map',
                        },
                        );
                    next unless ( @{ $xrefs || [] } );

                    my $map_data = $app_display_data->app_data_module()
                        ->map_data( map_id => $map_id, );

                    foreach my $xref ( @{ $xrefs || [] } ) {
                        my $url;
                        $template_processor->process( \$xref->{'xref_url'},
                            { object => $map_data }, \$url );

                        push @urls, $url;
                    }
                }
            }
            elsif ( $selected_type eq 'feature' ) {
                foreach my $feature_acc (
                    $app_interface->object_selection_keys(
                        window_key => $window_key,
                    )
                    )
                {
                    my $feature_data = $app_display_data->app_data_module()
                        ->feature_data( feature_acc => $feature_acc, );
                    my $feature_id = $feature_data->{'feature_id'};

                    # Get the Xrefs
                    my $xrefs
                        = $app_display_data->app_data_module()
                        ->generic_get_data(
                        method_name => 'get_xrefs',
                        parameters  => {
                            object_id   => $feature_id,
                            object_type => 'feature',
                        },
                        );
                    next unless ( @{ $xrefs || [] } );

                    foreach my $xref ( @{ $xrefs || [] } ) {
                        my $url;
                        $template_processor->process( \$xref->{'xref_url'},
                            { object => $feature_data }, \$url );

                        push @urls, $url;
                    }
                }
            }
            if (@urls) {
                foreach my $url (@urls) {
                    system( "/usr/bin/firefox " . $url );
                }
            }
            else {
                $self->app_interface->popup_warning(
                    text => "There are no external references to present.\n",
                );
            }
        },
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

