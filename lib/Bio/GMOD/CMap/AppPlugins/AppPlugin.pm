package Bio::GMOD::CMap::AppPlugins::AppPlugin;

# $Id: AppPlugin.pm,v 1.7 2007-08-01 21:28:14 mwz444 Exp $
# base class for plugins for the Generic Genome Browser

=head1 NAME

Bio::GMOD::CMap::AppPlugins::AppPlugin -- Base class for gbrowse plugins.

=head1 SYNOPSIS

 package Bio::GMOD::CMap::AppPlugins::AppPlugin::MyPlugin;
 use base Bio::GMOD::CMap::AppPlugins::AppPlugin;

 # called by the editor to return description of plugin
 sub description { 'This is an example plugin' }

 # called by the editor to return type of plugin
 sub type        { 'modify_main_menu' }

 # called by the editor to add new menus to the main menu
 sub modify_main_menu {
 }

=head1 DESCRIPTION

This is the base class for CMap applicationplugins.  Plugins
are perl .pm files that are stored in the Bio/GMOD/CMap/AppPlugins/
directory.  Plugins are activated in the configuration
file by including them on the list indicated by the "editor_plugins" setting:

 editor_plugins Plugin1 Plugin2


CMap currently recognizes 1 distinct types of plugins:

=over 4

=item 1) modify_main_menu

=item 2) modify_start_up_menu

=item 3) modify_right_click_menu

=item 4) modify_commit_changes


=back
	
All plug-ins inherit from Bio::GMOD::CMap::AppPlugins::AppPlugin, which
defines reasonable (but uninteresting) defaults for each of the
methods.  Specific behavior is then implemented by selectively
overriding certain methods.

The best way to understand how this works is to look at the source
code for some working plugins.  Examples provided with the gbrowse
distribution include:

=over 4

=item 

=back

=head1 METHODS

The remainder of this document describes the methods available to the
programmer.

=head2 INITIALIZATION

The initialization methods establish the human-readable name,
description, and basic operating parameters of the plugin.  They
should be overridden in each plugin you write.

=over 4

=item $description = $self->description()

This method returns a longer description for the plugin.  The text may
contain HTML tags, and should describe what the plugin does and who
wrote it.  This text is displayed when the user presses the "About..."
button.

=item $type = $self->type()

This tells gbrowse what the plugin's type is.  It must return one of the types
"modify_main_menu" or "modify_start_up_menu" or "modify_right_click_menu" or
"modify_commit_changes"  as described in the introduction to this
documentation.  If the method is not overridden, type() will return "generic."

=item $self->init()

This method is called before any methods are invoked and allows the plugin to
do any run-time initialization it needs.  The default is to do the nessesary
initializations to tie the plugin into the editor.  Ordinarily this method
should not be overwritten.

=back

=head2 ACCESS TO THE ENVIRONMENT

=over 4

=item $app_interface = $self->app_interface()

=item $app_display_data = $self->app_display_data()

=item $app_data_module = $self->app_data_module()

=item $config_info = $self->config_data('option_in_question')

=back

=head2 METHODS TO BE IMPLEMENTED IN Main Menu Adders 

All plugins that modify_main_menu should override one or more of the methods
described in this section.

=over 4

=item $self->modify_main_menu()

=back

=head2 METHODS TO BE IMPLEMENTED IN Start Up Menu Adders 

All plugins that modify_start_up_menu should override one or more of the
methods described in this section.

=over 4

=item $self->modify_start_up_menu()

=back

=head2 METHODS TO BE IMPLEMENTED IN Right Click Menu Adders 

All plugins that modify_right_click_menu should override one or more of the
methods described in this section.

=over 4

=item $self->modify_right_click_menu()

=back

=head2 METHODS TO BE IMPLEMENTED IN Commit Changes Modifiers 

All plugins that modify_commit_changes should override one or more of the
methods described in this section.

=over 4

=item $self->modify_commit_changes()

This method should return true in order for the changes to be committed.  If
the plugin returns false, the commit will not happen.  

=back


=cut

use strict;
use Data::Dumper;
use Bio::GMOD::CMap;
use base 'Bio::GMOD::CMap';

use vars '$VERSION';
$VERSION = '0.01';

sub init {
    my ( $self, $config ) = @_;

    for my $param (
        qw[ config data_source app_interface app_data_module app_display_data ]
        )
    {
        $self->$param( $config->{$param} )
            or die "Failed to pass $param to AppDisplayData\n";
    }

    return $self;
}

# ----------------------------------------------------
sub app_data_module {

=pod

=head3 app_data_module

Returns a handle to the data module.

=cut

    my $self = shift;

    $self->{'app_data_module'} = shift if @_;

    return $self->{'app_data_module'};
}

# ----------------------------------------------------
sub app_interface {

=pod

=head3 app_interface

Returns a handle to the data module.

=cut

    my $self = shift;

    $self->{'app_interface'} = shift if @_;

    return $self->{'app_interface'};
}

# ----------------------------------------------------
sub app_display_data {

=pod

=head3 app_interface

Returns a handle to the data module.

=cut

    my $self = shift;

    $self->{'app_display_data'} = shift if @_;

    return $self->{'app_display_data'};
}

sub description {
    my $self = shift;
    return p(
        "This is the base class for all CMap Editor plugins.",
        "The fact that you're seeing this means that the author of",
        "this plugin hasn't yet entered a real description"
    );
}

sub type {
    my $self = shift;
    return 'generic';
}

sub modify_main_menu {
    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    return;
}

sub modify_start_up_menu {
    my ( $self, %args ) = @_;
    my $button_items = $args{'button_items'};
    return;
}

sub modify_right_click_menu {
    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $menu_items = $args{'menu_items'};
    return;
}

sub modify_commit_changes {
    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};
    my $actions    = $args{'actions'};
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

