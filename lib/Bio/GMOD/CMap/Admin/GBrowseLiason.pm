package Bio::GMOD::CMap::Admin::GBrowseLiason;

# vim: set ft=perl:

# $Id: GBrowseLiason.pm,v 1.2 2005-02-14 19:45:28 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Admin::GBrowseLiason - import alignments such as BLAST

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::GBrowseLiason;
  my $liason = Bio::GMOD::CMap::Admin::GBrowseLiason->new;
  $liason->import(
    map_set_ids       => \@map_set_ids,
    feature_type_aids => \@feature_type_aids,
  ) or return $liason->error;

=head1 DESCRIPTION

This module encapsulates the logic for dealing with the 
GBrowse integration at the db level.

=cut

use strict;
use vars qw( $VERSION %COLUMNS $LOG_FH );
$VERSION = (qw$Revision: 1.2 $)[-1];

use Data::Dumper;
use Bio::GMOD::CMap;

use base 'Bio::GMOD::CMap';

# ----------------------------------------------
=pod

=head2 prepare_data_for_gbrowse

Given a list of map set ids and a list of feature type accessions,
this will add the "gbrowse_class" value in the config file for each
feature type, for all the features matching the map set ids and 
feature type accessions.

=cut

sub prepare_data_for_gbrowse {
    my ( $self, %args ) = @_;
    my $map_set_ids = $args{'map_set_ids'}
      or return $self->error('No map set ids');
    my $feature_type_aids = $args{'feature_type_aids'}
      or return $self->error('No feature type aids');
    my $db           = $self->db;
    my %class_lookup;
    $LOG_FH = $args{'log_fh'} || \*STDOUT;
    print $LOG_FH "Preparing Data for GBrowse\n";
    my $admin = Bio::GMOD::CMap::Admin->new(
      data_source => $self->data_source
    );


    for (my $i=0;$i<=$#{$feature_type_aids}; $i++){
        my $class = $self->feature_type_data($feature_type_aids->[$i],'gbrowse_class');
        if ($class){
            $class_lookup{$feature_type_aids->[$i]}=$class;
        }
        else{
            print $LOG_FH "Feature Type with aid ".$feature_type_aids->[$i]." not eligible\n";
            print $LOG_FH "If you wish to prepare this feature type, add a gbrowse_class to it in the config file\n";
            splice @$feature_type_aids,$i,1;
            $i--;   
        }
    }
    return $self->error( "No Map Sets to work on.\n" )
        unless ($map_set_ids and @$map_set_ids);
    return $self->error( "No Feature Types to work on.\n" )
        unless (%class_lookup);

    # 
    # Make sure there is a "Map" feature for GBrowse
    #
    my $map_set_sql = qq[
        select  ms.map_type_accession as map_type_aid,
                map.map_id,
                map.start_position,
                map.stop_position,
                map.map_name
        from    cmap_map_set ms,
                cmap_map map
        where   map.map_set_id=ms.map_set_id
            and ms.map_set_id in ( 
    ].
        join (',',@$map_set_ids).
        qq[ ) 
    ];

    my $map_feature_sql = qq[
        select  feature_id
        from    cmap_feature
        where   feature_type_accession = ?
            and map_id = ?
            and gclass = ?
    ];
    
    my $sth = $db->prepare( $map_feature_sql );
    
    my $map_set_results = $db->selectall_arrayref( $map_set_sql, { Columns => {} }, );
    my %map_class_lookup;
    my $ft_aid = $self->config_data('gbrowse_default_map_feature_type_aid'); 
    return $self->error( "No gbrowse_default_map_feature_type_aid defined in config file.\n" ) unless ($ft_aid);
    foreach my $row (@$map_set_results){
        unless ($map_class_lookup{$row->{'map_type_aid'}}){
            my $class = $self->map_type_data($row->{'map_type_aid'},'gbrowse_map_class');
            $class = $self->config_data('gbrowse_default_map_class') unless ($class);
            return $self->error( "No gbrowse_default_map_class defined in config file.\n" ) unless ($class);
            $map_class_lookup{$row->{'map_type_aid'}} = $class;
        }
        $sth->execute($ft_aid,$row->{'map_id'},$map_class_lookup{$row->{'map_type_aid'}});
        my $map_search = $sth->fetchrow_arrayref;
        unless ($map_search and @$map_search){
            print $LOG_FH "Adding Map feature\n";
            $admin->feature_create(
                map_id => $row->{'map_id'},
                feature_name => $row->{'map_name'},
                start_position => $row->{'start_position'},
                stop_position => $row->{'stop_position'},
                feature_type_aid => $ft_aid,
                gclass => $map_class_lookup{$row->{'map_type_aid'}},
            );
        }
    }

    my $update_sql = qq[
        update cmap_feature, cmap_map
        set cmap_feature.gclass=? 
        where cmap_feature.feature_type_accession = ?
            and cmap_feature.map_id = cmap_map.map_id
            and cmap_map.map_set_id in ( 
    ].
        join (',',@$map_set_ids).
        qq[ ) 
    ];

    $sth = $db->prepare( $update_sql );
    
    foreach my $ft_aid (@$feature_type_aids){
        print $LOG_FH "Preparing Feature Type with accession $ft_aid\n";
        $sth->execute($class_lookup{$ft_aid},$ft_aid);
    }

    return 1;
}
