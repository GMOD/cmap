package Bio::GMOD::CMap::Apache::DataDownloader;
# vim: set ft=perl:

# $Id: DataDownloader.pm,v 1.1.2.1 2004-06-17 18:21:57 kycl4rk Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.1.2.1 $)[-1];

use Bio::GMOD::CMap::Apache;
use base 'Bio::GMOD::CMap::Apache';

sub handler {
    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;
    $self->data_source( $apr->param('data_source') ) or return;

    my $page_no        = $apr->param('page_no') || 1;
    my $map_set_aid    = $apr->param('map_set_aid');
    my $map_aid        = $apr->param('map_aid');
    my $data_module    = $self->data_module;
    my $data           = $data_module->data_download(
        map_set_aid    => $map_set_aid,
        map_aid        => $map_aid,
    ) or return $self->error( $data_module->error );

    print $apr->header( -type => 'text/plain', -cookie => $self->cookie ), 
        $data;
    return 1;
}

1;

# ----------------------------------------------------
# Where man is not nature is barren.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::DataDownloader - print out tab-delimited data 

=head1 DESCRIPTION

For downloading of map or map set data.

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
