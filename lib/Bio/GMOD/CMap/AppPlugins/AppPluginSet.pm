package Bio::GMOD::CMap::AppPlugins::AppPluginSet;
use strict;

# API for using plugins
# Modified from the GBrowse module Bio::Graphics::Browser::AppPluginSet
# which was written by Lincoln Stein

#  $Id: AppPluginSet.pm,v 1.4 2007-04-05 20:29:35 mwz444 Exp $

use Data::Dumper;

use constant DEBUG => 0;
use Bio::GMOD::CMap;
use base 'Bio::GMOD::CMap';

# ----------------------------------------------------
sub init {

=pod

=head2 init

Initializes the drawing object.

=cut

    my ( $self, $config ) = @_;

    for my $param (
        qw[ config      data_source      app_interface
        app_data_module app_display_data
        ]
        )
    {
        $self->$param( $config->{$param} )
            or die "Failed to pass $param to AppDisplayData\n";
    }

    my $additional_plugins = $config->{'plugins'};
    $self->{'plugins'} = {};

    my @plugins;
    for my $line (
        $self->config_data('editor_plugins'),
        @{ $additional_plugins || [] }
        )
    {
        push @plugins, split /\s+/, $line;
    }

PLUGIN:
    for my $plugin (@plugins) {
        my $class    = 'Bio::GMOD::CMap::AppPlugins::' . $plugin;
        my $eval_str = "require $class";
        if ( eval $eval_str ) {
            warn "plugin $plugin loaded successfully" if DEBUG;
            my $obj = $class->new(
                config           => $self->config,
                data_source      => $self->data_source,
                app_interface    => $self->app_interface,
                app_data_module  => $self->app_data_module,
                app_display_data => $self->app_display_data,

            );
            $self->{'plugins'}{$plugin} = $obj;
            next PLUGIN;
        }
        else {
            warn $@ if $@ and $@ !~ /^Can\'t locate/;
        }
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

sub plugins {
    my $self = shift;
    return wantarray ? values %{ $self->{plugins} } : $self->{plugins};
}

sub plugin {
    my $self        = shift;
    my $plugin_name = shift;
    $self->plugins->{$plugin_name};
}

sub modify_main_menu {
    my ( $self, %args ) = @_;
    my $window_key = $args{'window_key'};

    for my $p ( $self->plugins ) {
        next unless $p->type eq 'modify_main_menu';
        $p->modify_main_menu( window_key => $window_key, );
    }
}

sub modify_right_click_menu {
    my ( $self, %args ) = @_;
    my $window_key  = $args{'window_key'};
    my $menu_window = $args{'menu_window'};

    for my $p ( $self->plugins ) {
        next unless $p->type eq 'modify_right_click_menu';
        $p->modify_right_click_menu(
            window_key  => $window_key,
            menu_window => $menu_window,
        );
    }
}

1;

__END__

=head1 NAME

Bio::GMOD::CMap::AppPlugins::AppPluginSet -- A set of plugins

=head1 SYNOPSIS

None.  Used internally by the CMap Application

=head1 METHODS

=over 4

=item $plugin_set = Bio::GMOD::CMap::AppPlugins::AppPluginSet->new($config,$page_settings,@search_path)

Initialize plugins according to the configuration, page settings and
the plugin search path.  Returns an object.

=item $plugin_set->configure($database)

Configure the plugins given the database.

=item $plugin_set->annotate($segment,$feature_files,$rel2abs)

Run plugin annotations on the $segment, adding the resulting feature
files to the hash ref in $feature_files ({track_name=>$feature_list}).
The $rel2abs argument holds a coordinate mapper callback, but is
currently unused.

=back

=head1 SEE ALSO

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.
Lincoln Stein E<lt>lstein@cshl.orgE<gt>.

Copyright (c) 2007 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

