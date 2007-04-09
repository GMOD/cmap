package Bio::GMOD::CMap::Apache::Remote;

# vim: set ft=perl:

# $Id: Remote.pm,v 1.8 2007-04-09 16:39:33 mwz444 Exp $

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.8 $)[-1];

use Bio::GMOD::CMap::Apache;
use Storable qw(nfreeze thaw);
use Data::Dumper;
use base 'Bio::GMOD::CMap::Apache';

sub handler {

    #
    # Make a jazz noise here...
    #
    my ( $self, $apr ) = @_;
    $self->data_source( $apr->param('data_source') ) or return;
    my $action = $apr->param('action');

    my $data_access = $self->config_data('allow_remote_data_access');
    my $data_manipulation
        = $self->config_data('allow_remote_data_manipulation');

    unless ($data_access) {
        print STDERR "Remote Access Attempted\n";
        print "Data Source Not Remotely Accessible\n";
        return 1;
    }

    if ( $action =~ /^update/ and not $data_manipulation ) {
        print STDERR "Remote Commit Attempted\n";
        print "Data Source Not Remotely Modifyable\n";
        return 1;
    }

    print $apr->header( -type => 'text/plain', );
    if ( $action eq 'get_config' ) {

        # Remove sensitive data
        my $config = clone $self->config();
        foreach
            my $data_source_name ( keys %{ $config->{'config_data'} || {} } )
        {
            $config->{'config_data'}{$data_source_name}{'database'}
                {'datasource'} = undef;
            $config->{'config_data'}{$data_source_name}{'database'}{'user'}
                = undef;
            $config->{'config_data'}{$data_source_name}{'database'}
                {'password'} = undef;
        }
        print nfreeze($config);
    }
    elsif ( $action eq 'get_maps' ) {
        my $map_id   = $apr->param('map_id');
        my @map_ids  = $apr->param('map_ids');
        my @map_accs = $apr->param('map_accs');
        my $data     = $self->sql()->get_maps(
            cmap_object => $self,
            map_id      => $map_id,
            map_ids     => \@map_ids,
            map_accs    => \@map_accs,
        );
        unless ( @{ $data || [] } ) {
            $data = undef;
        }
        print nfreeze($data);
    }
    elsif ( $action eq 'get_species' ) {
        my $is_relational_map = $apr->param('is_relational_map');
        my $is_enabled        = $apr->param('is_enabled');
        my $data              = $self->sql()->get_species(
            cmap_object       => $self,
            is_relational_map => $is_relational_map,
            is_enabled        => $is_enabled,
        );
        unless ( @{ $data || [] } ) {
            $data = undef;
        }
        print nfreeze($data);
    }
    elsif ( $action eq 'get_map_sets' ) {
        my $is_relational_map = $apr->param('is_relational_map');
        my $is_enabled        = $apr->param('is_enabled');
        my $species_id        = $apr->param('species_id');
        my $data              = $self->sql()->get_map_sets(
            cmap_object       => $self,
            species_id        => $species_id,
            is_relational_map => $is_relational_map,
            is_enabled        => $is_enabled,
        );
        unless ( @{ $data || [] } ) {
            $data = undef;
        }
        print nfreeze($data);
    }
    elsif ( $action eq 'get_maps_from_map_set' ) {
        my $map_set_id = $apr->param('map_set_id');
        my $data       = $self->sql()->get_maps_from_map_set(
            cmap_object => $self,
            map_set_id  => $map_set_id,
        );
        unless ( @{ $data || [] } ) {
            $data = undef;
        }
        print nfreeze($data);
    }
    elsif ( $action eq 'get_features_sub_maps_version' ) {
        my $map_id       = $apr->param('map_id');
        my $no_sub_maps  = $apr->param('no_sub_maps');
        my $get_sub_maps = $apr->param('get_sub_maps');
        my $data         = $self->sql()->get_features_sub_maps_version(
            cmap_object  => $self,
            map_id       => $map_id,
            no_sub_maps  => $no_sub_maps,
            get_sub_maps => $get_sub_maps,
        );
        unless ( @{ $data || [] } ) {
            $data = undef;
        }
        print nfreeze($data);
    }
    elsif ( $action eq 'get_feature_correspondence_for_counting' ) {
        my $slot_info = $self->unstringify_slot_info(
            slot_info_str => $apr->param('slot_info'), );
        my $slot_info2 = $self->unstringify_slot_info(
            slot_info_str => $apr->param('slot_info2'), );
        my $data = $self->sql()->get_feature_correspondence_for_counting(
            cmap_object => $self,
            slot_info   => $slot_info,
            slot_info2  => $slot_info2,
        );
        unless ( @{ $data || [] } ) {
            $data = undef;
        }
        print nfreeze($data);
    }
    elsif ( $action eq 'update_features' ) {

        for my $feature_data_str ( split( /:/, $apr->param('feature_str') ) )
        {

            # Parse the feature data and allow for shorter alternatives
            my %feature_data = split( /,/, $feature_data_str );
            my $feature_id = $feature_data{'feature_id'}
                || $feature_data{'id'}
                or next;
            my $map_id = $feature_data{'map_id'} || undef;
            my $feature_acc = $feature_data{'feature_acc'}
                || $feature_data{'acc'}
                || undef;
            my $feature_type_acc = $feature_data{'feature_type_acc'}
                || $feature_data{'type_acc'}
                || undef;
            my $feature_name = $feature_data{'feature_name'}
                || $feature_data{'name'}
                || undef;
            my $direction = $feature_data{'direction'}
                || $feature_data{'dir'}
                || undef;

            # These options can be defined as false.
            my $is_landmark   = $feature_data{'is_landmark'};
            my $feature_start =
                defined( $feature_data{'feature_start'} )
                ? $feature_data{'feature_start'}
                : $feature_data{'start'};
            my $feature_stop =
                defined( $feature_data{'feature_stop'} )
                ? $feature_data{'feature_stop'}
                : $feature_data{'stop'};
            my $default_rank =
                defined( $feature_data{'default_rank'} )
                ? $feature_data{'default_rank'}
                : $feature_data{'rank'};

            $self->sql()->update_feature(
                cmap_object      => $self,
                feature_id       => $feature_id,
                map_id           => $map_id,
                feature_acc      => $feature_acc,
                feature_type_acc => $feature_type_acc,
                feature_name     => $feature_name,
                is_landmark      => $is_landmark,
                feature_start    => $feature_start,
                feature_stop     => $feature_stop,
                default_rank     => $default_rank,
                direction        => $direction,

            );
        }
        print 1;
    }

    return 1;
}

# ----------------------------------------------------

=pod

=head2 unstringify_slot_info

Turn a slot_info url string into a url

  Structure:
    {
        map_id => [ current_start, current_stop, ori_start, ori_stop, magnification ],
    }

  URL Structure
    :map_id*current_start*current_stop*ori_start*ori_stop*magnification

=cut

sub unstringify_slot_info {

    my ( $self, %args ) = @_;
    my $slot_info_str = $args{'slot_info_str'};

    my $return_obj      = {};
    my @slot_info_array = split /:/, $slot_info_str;

    foreach my $map_info_str (@slot_info_array) {
        my @la = split /\*/, $map_info_str;
        if ( my $map_id = $la[0] ) {
            $return_obj->{$map_id} = [
                ( defined( $la[1] ) and $la[1] ne '' ) ? $la[1] : undef,
                ( defined( $la[2] ) and $la[2] ne '' ) ? $la[2] : undef,
                ( defined( $la[3] ) and $la[3] ne '' ) ? $la[3] : undef,
                ( defined( $la[4] ) and $la[4] ne '' ) ? $la[4] : undef,
                ( defined( $la[5] ) and $la[5] ne '' ) ? $la[5] : undef,
            ];
        }
    }

    return $return_obj;
}

1;

=head1 NAME

Bio::GMOD::CMap::Apache::Remote - handles remote data requests

=head1 DESCRIPTION

This module handles remote data requests.

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2006 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

