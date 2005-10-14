package Bio::GMOD::CMap::Admin::SavedLink;

# vim: set ft=perl:

# $Id: SavedLink.pm,v 1.1 2005-10-14 20:05:22 mwz444 Exp $

use strict;
use warnings;
use Data::Dumper;
use Data::Stag qw(:all);
use Time::ParseDate;

use Bio::GMOD::CMap::Admin;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Drawer;
use Storable qw(freeze thaw);

use base 'Bio::GMOD::CMap::Admin';

sub create_saved_link {
    my ( $self, %args ) = @_;
    my $parsed_options_ref = $args{'parsed_options_ref'};
    my $link_group         = $args{'link_group'};
    my $link_front         = $args{'link_front'};
    my $link_title         = $args{'link_title'};
    my $link_comment       = $args{'link_comment'};

    # Remove the session info to get keep create_session_step from overwriting
    delete $parsed_options_ref->{'session'};
    delete $parsed_options_ref->{'session_id'};
    delete $parsed_options_ref->{'step'};

    # Create the drawer object to use it's link creation abilities
    my $drawer = Bio::GMOD::CMap::Drawer->new(
        skip_drawing => 1,
        %$parsed_options_ref,
        )
        or return $self->error( Bio::GMOD::CMap::Drawer->error );

    # Drawer went through some work (inadvertantly), we may as well take
    # advantage of that.
    $parsed_options_ref->{'slots'} = $drawer->{'slots'};

    # Created the URLs.
    # Not the saved_link_id will be added to the saved url in the insert call
    my $saved_url = $link_front
        . $self->create_viewer_link(
        $drawer->create_link_params( skip_map_info => 1, ) );
    my $legacy_url = $link_front . $self->create_viewer_link(
        $drawer->create_link_params(
            new_session       => 1,
            create_legacy_url => 1,
            ref_map_set_acc   => $parsed_options_ref->{'ref_map_set_acc'},

         #        ref_map_accs => $parsed_options_ref->{'slots'}->{0}{'maps'},
        )
    );

    # Get the session Step object that will be stored in the db.
    my $session_step_object
        = Bio::GMOD::CMap::Utils->create_session_step($parsed_options_ref)
        or return $self->error('Problem creating the new session step.');

    my $saved_link_id = $self->sql->insert_saved_link(
        cmap_object         => $self,
        saved_url           => $saved_url,
        legacy_url          => $legacy_url,
        session_step_object => freeze($session_step_object),
        link_group          => $link_group,
        link_title          => $link_title,
        link_comment        => $link_comment,
    );
    return $saved_link_id;
}

sub read_saved_links_file {
    my ( $self, %args ) = @_;
    my $file_name  = $args{'file_name'};
    my $link_front = $args{'link_front'} || 'viewer';
    my $link_group = $args{'link_group'} || DEFAULT->{'link_group'};
    print "Importing links from $file_name\n";

    my $stag_object = stag_parse( '-file' => $file_name, 'xml' );

VIEW:
    for my $view_params ( stag_find( $stag_object, 'cmap_view' ) ) {
        my %parsed_options;

        # get title
        my $link_title         = $view_params->find('title');
        my $current_link_group = $view_params->find('group') || $link_group;
        my $link_comment       = $view_params->find('comment');

        # Deal with each slot
        my $slots;
    SLOT:
        for my $slot_params ( stag_find( $view_params, 'slot' ) ) {
            my $slot_num = $slot_params->find('number');
            unless ( defined $slot_num ) {
                print STDERR qq[Slot object needs a 'number' parameter.\n];
                next VIEW;
            }
            $slots->{$slot_num} = _create_slot($slot_params);
        }
        $parsed_options{'slots'} = $slots;

        my $options_params = $view_params->get('menu_options');
        if ($options_params) {
        OPTION:
            for my $option ( $options_params->children() ) {
                my $tag = $option->element();
                $parsed_options{$tag} = $option->find($tag);
            }
        }

        my $saved_link_id = $self->create_saved_link(
            link_group         => $current_link_group,
            link_front         => $link_front,
            link_title         => $link_title,
            link_comment       => $link_comment,
            parsed_options_ref => \%parsed_options,
        );

    }
    return 1;
}

sub _create_slot {
    my $slot_params = shift;

    my %slot;

    $slot{'map_set_acc'} = $slot_params->sget('map_set_acc');

    # Get Maps info
    for my $map_params ( $slot_params->get('map') ) {
        my $map_acc = $map_params->find('map_acc');
        $slot{'maps'}{$map_acc} = {
            start => $map_params->sget('map_start'),
            stop  => $map_params->sget('map_stop'),
            mag   => $map_params->sget('map_magnification') || 1,
        };
    }

    #Get Map Set info
    for my $map_set_params ( $slot_params->get('map_set') ) {
        my $map_set_acc = $map_set_params->find('map_set_acc');
        $slot{'map_sets'}{$map_set_acc} = ();
    }
    return \%slot;
}

1;

# ----------------------------------------------------
# All wholsome food is caught without a net or a trap.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Admin::SavedLink - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<perl>

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.edu<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-5 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

