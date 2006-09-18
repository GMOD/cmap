package Bio::GMOD::CMap::Apache::ViewFeatureOnMap;

# vim: set ft=perl:

# $Id: ViewFeatureOnMap.pm,v 1.16 2006-09-18 15:03:08 mwz444 Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.16 $)[-1];

use Bio::GMOD::CMap::Apache;
use base 'Bio::GMOD::CMap::Apache';

sub handler {

    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;
    $self->data_source( $apr->param('data_source') ) or return;
    my $feature_acc = $apr->param('feature_acc')
        || $apr->param('feature_aid')
        || '';
    my $highlight_by = $apr->param('highlight_by') || '';
    my $start = $apr->param('start') || $apr->param('ref_map_start');
    my $stop  = $apr->param('stop')  || $apr->param('ref_map_stop');
    my $data  = $self->data_module;
    my $url   = $apr->url;

    my ( $ms_acc, $map_acc, $feature_name ) =
      $data->view_feature_on_map($feature_acc);

    my $highlight =
      ($highlight_by eq 'feature_acc' or $highlight_by eq 'accession_id') ? $feature_acc : $feature_name;

    return $self->error("Can't find the feature accession ID '$feature_acc'")
      unless $ms_acc && $map_acc;

    print $apr->redirect(
            "$url/viewer?ref_map_set_acc=$ms_acc&label_features=all"
          . qq[&ref_map_accs=$map_acc&highlight="$highlight"]
          . "&ref_map_start=$start&ref_map_stop=$stop"
          . '&data_source='
          . $apr->param('data_source') );

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

