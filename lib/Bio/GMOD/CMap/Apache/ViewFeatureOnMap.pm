package Bio::GMOD::CMap::Apache::ViewFeatureOnMap;
# vim: set ft=perl:

# $Id: ViewFeatureOnMap.pm,v 1.7.2.2 2004-06-08 21:35:09 kycl4rk Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.7.2.2 $)[-1];

use Bio::GMOD::CMap::Apache;
use base 'Bio::GMOD::CMap::Apache';

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;
    my $data_source    = $apr->param('data_source')  || '';
    my $feature_aid    = $apr->param('feature_aid')  || '';
    my $highlight_by   = $apr->param('highlight_by') || '';

    $self->data_source( $data_source ) or return;
    my $data = $self->data_module;

    my ( $ms_aid, $map_aid, $feature_name ) = 
        $data->view_feature_on_map( $feature_aid );

    my $highlight = $highlight_by eq 'accession_id' 
                    ? $feature_aid : $feature_name;

    return $self->error("Can't find the feature accession ID '$feature_aid'")
        unless $ms_aid && $map_aid;

    my $url = $apr->url;

    print $apr->redirect(
        "$url/viewer?ref_map_set_aid=$ms_aid&data_source=$data_source".
        qq[&ref_map_aid=$map_aid&highlight="$highlight"]
    );

    return 1;
}

1;

# ----------------------------------------------------
# You never know what is enough
# Until you know what is more than enough.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::ViewFeatureOnMap - view feature on map

=head1 DESCRIPTION

Given a feature's accession ID, this module will find the map and map
set on which the feature lives and will redirect to the map viewer
with the feature highlighted.  If the feature can't be found, an error
is thrown.

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
