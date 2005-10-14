package Bio::GMOD::CMap::Apache::SavedLinkViewer;

# vim: set ft=perl:

# $Id: SavedLinkViewer.pm,v 1.1 2005-10-14 20:05:22 mwz444 Exp $

use strict;
use Data::Dumper;
use Template;
use Time::ParseDate;

use CGI;
use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Admin::SavedLink;
use Bio::GMOD::CMap::Constants;
use Storable qw(freeze thaw);

use base 'Bio::GMOD::CMap::Apache';

use vars qw( $VERSION $PAGE_SIZE $MAX_PAGES $INTRO );
use constant MULTI_VIEW_TEMPLATE => 'saved_links_viewer.tmpl';
use constant EDIT_TEMPLATE       => 'saved_link_edit.tmpl';
use constant VIEW_TEMPLATE       => 'saved_link_view.tmpl';
use constant SAVED_LINK_URI      => 'saved_link';

# ----------------------------------------------------
sub handler {

    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;

    $self->data_source( $apr->param('data_source') ) or return;

    my $action = $apr->param('action') || 'saved_links_viewer';
    my $return = eval { $self->$action() };
    return $self->error($@) if $@;
    return 1;
}

# ---------------------------------------------------
sub saved_links_viewer {
    my ( $self, %args ) = @_;
    my $apr        = $self->apr;
    my $sql_object = $self->sql or return;

    my $page_no            = $apr->param('page_no') || 1;
    my $selected_link_group = $apr->param('selected_link_group');

    # Create hash of link_groups
    my $link_group_counts_ref
        = $sql_object->get_saved_link_groups( cmap_object => $self, );

    my $pager;
    my $saved_links_ref;
    if ($selected_link_group) {

        # Get the Saved links
        $saved_links_ref = $sql_object->get_saved_links(
            cmap_object => $self,
            link_group   => $selected_link_group,
        );

        # Slice the results up into pages suitable for web viewing.
        $PAGE_SIZE ||= $self->config_data('max_child_elements') || 0;
        $MAX_PAGES ||= $self->config_data('max_search_pages')   || 1;
        $pager = Data::Pageset->new(
            {   total_entries    => scalar @$saved_links_ref,
                entries_per_page => $PAGE_SIZE,
                current_page     => $page_no,
                pages_per_set    => $MAX_PAGES,
            }
        );
        $saved_links_ref = [ $pager->splice($saved_links_ref) ]
            if @$saved_links_ref;
    }

    $INTRO ||= $self->config_data('saved_links_intro') || '';

    my $html;
    my $t = $self->template;
    $t->process(
        MULTI_VIEW_TEMPLATE,
        {   apr              => $apr,
            current_url      => $apr->url( -path_info => 1, -query => 1 ),
            page             => $self->page,
            stylesheet       => $self->stylesheet,
            data_sources     => $self->data_sources,
            saved_links      => $saved_links_ref,
            link_group_counts => $link_group_counts_ref,
            pager            => $pager,
            intro            => $INTRO,
        },
        \$html
        )
        or $html = $t->error;

    print $apr->header( -type => 'text/html', -cookie => $self->cookie ),
        $html;
    return 1;
}

# ----------------------------------------------------
sub saved_link_view {
    my ( $self, %args ) = @_;
    my $apr           = $self->apr;
    my $sql_object    = $self->sql or return;
    my $saved_link_id = $apr->param('saved_link_id')
        or die 'No feature saved_link id';
    my $url_to_return_to = $apr->param('url_to_return_to');
    my $saved_links      = $sql_object->get_saved_links(
        cmap_object   => $self,
        saved_link_id => $saved_link_id,
    );
    my $saved_link;
    if ( @{ $saved_links || [] } ) {
        $saved_link = $saved_links->[0];
    }
    unless ( %{ $saved_link || {} } ) {
        return $self->error(
            "Failed getting saved link with id $saved_link_id\n");
    }

    my $t = $self->template or return;
    return $t->process(
        VIEW_TEMPLATE,
        {   apr              => $apr,
            saved_link       => $saved_link,
            url_to_return_to => $url_to_return_to,
        }
    );
}

# ----------------------------------------------------
sub saved_link_create {
    my ( $self, %args ) = @_;
    my $current_apr = $self->apr;
    my $url_to_save = $current_apr->param('url_to_save')
        or die 'No url to save';

    my $apr_to_save = new CGI($url_to_save)
        or return $self->error("URL did not parse correctly.  $url_to_save");

    # GET USERNAME FROM COOKIE
    my $link_group = $current_apr->param('link_group')
        || DEFAULT->{'link_group'};

    # Use the url to create the parameters to pass to drawer.
    my %parsed_url_options
        = Bio::GMOD::CMap::Utils->parse_url( $apr_to_save, $self )
        or return $self->error();


    my ($link_front) = ($url_to_save =~ m/.+\/(.+?)\?/);
    my $saved_link_admin = Bio::GMOD::CMap::Admin::SavedLink->new;
    my $saved_link_id = $saved_link_admin->create_saved_link(
        link_group => $link_group,
        link_front => $link_front,
        parsed_options_ref => \%parsed_url_options,
        );

    # After creating the link,
    # send everything over to saved_link_edit to handle
    # but first modify some values that it uses
    $current_apr->param( 'url_to_return_to', $url_to_save );
    $current_apr->param( 'saved_link_id',    $saved_link_id );

    return $self->saved_link_edit();
}

# ----------------------------------------------------
sub saved_link_edit {
    my ( $self, %args ) = @_;
    my $apr           = $self->apr;
    my $sql_object    = $self->sql or return;
    my $saved_link_id = $apr->param('saved_link_id')
        or die 'No feature saved_link id';
    my $url_to_return_to = $apr->param('url_to_return_to');

    my $saved_links = $sql_object->get_saved_links(
        cmap_object   => $self,
        saved_link_id => $saved_link_id,
    );
    my $saved_link;
    if ( @{ $saved_links || [] } ) {
        $saved_link = $saved_links->[0];
    }
    unless ( %{ $saved_link || {} } ) {
        return $self->error(
            "Failed getting saved link with id $saved_link_id\n");
    }

    my $t = $self->template or return;
    return $t->process(
        EDIT_TEMPLATE,
        {   apr              => $apr,
            saved_link       => $saved_link,
            url_to_return_to => $url_to_return_to,
        }
    );
}

# ----------------------------------------------------
sub saved_link_update {
    my ( $self, %args ) = @_;
    my $apr              = $self->apr;
    my $url_to_return_to = $apr->param('url_to_return_to');

    my $saved_link_id = $apr->param('saved_link_id')
        or die 'No feature saved_link id';

    $self->sql->update_saved_link(
        cmap_object   => $self,
        saved_link_id => $saved_link_id,
        link_group     => $apr->param('link_group'),
        link_comment  => $apr->param('link_comment'),
    );

    return $self->saved_link_edit();

#    return $apr->redirect( SAVED_LINK_URI
#            . "?action=saved_link_edit;saved_link_id=$saved_link_id;url_to_return_to=$url_to_return_to"
#    );
}

sub admin_create_saved_link {
    my ( $self, %args ) = @_;
    my $apr_to_save = $args{'apr_to_save'};
    my $link_group = $args{'link_group'};
    my $link_front = $args{'link_front'};
    
    # Use the url to create the parameters to pass to drawer.
    my %parsed_url_options
        = Bio::GMOD::CMap::Utils->parse_url( $apr_to_save, $self )
        or return $self->error();

    # Remove the session info to get keep create_session_step from overwriting
    delete $parsed_url_options{'session'};
    delete $parsed_url_options{'session_id'};
    delete $parsed_url_options{'step'};

    # Create the drawer object to use it's link creation abilities
    my $drawer = Bio::GMOD::CMap::Drawer->new(
        apr => $apr_to_save,
        %parsed_url_options,
        )
        or return $self->error( Bio::GMOD::CMap::Drawer->error );

    # Drawer went through some work (inadvertantly), we may as well take
    # advantage of that.
    $parsed_url_options{'slots'} = $drawer->{'slots'};

    # Created the URLs.
    # Not the saved_link_id will be added to the saved url in the insert call
    #my $url_front = $apr_to_save->url(-path_info =>1);
    my $saved_url = $link_front
        . $self->create_viewer_link(
        $drawer->create_link_params( skip_map_info => 1, ) );
    my $legacy_url = $link_front . $self->create_viewer_link(
        $drawer->create_link_params(
            new_session       => 1,
            create_legacy_url => 1,
            ref_map_set_acc   => $parsed_url_options{'ref_map_set_acc'},

           #        ref_map_accs => $parsed_url_options{'slots'}->{0}{'maps'},
        )
    );

    # Get the session Step object that will be stored in the db.
    my $session_step_object
        = Bio::GMOD::CMap::Utils->create_session_step( \%parsed_url_options )
        or return $self->error('Problem creating the new session step.');

    my $saved_link_id = $self->sql->insert_saved_link(
        cmap_object         => $self,
        saved_url           => $saved_url,
        legacy_url          => $legacy_url,
        session_step_object => freeze($session_step_object),
        link_group           => $link_group,
    );
    return $saved_link_id;

}

1;

# ----------------------------------------------------
# All wholsome food is caught without a net or a trap.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::SavedLinkViewer - 

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

