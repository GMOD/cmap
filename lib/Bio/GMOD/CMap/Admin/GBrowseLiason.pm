package Bio::GMOD::CMap::Admin::GBrowseLiason;

# vim: set ft=perl:

# $Id: GBrowseLiason.pm,v 1.7 2005-03-14 18:57:31 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.7 $)[-1];

use Data::Dumper;
use Bio::GMOD::CMap;
use Bio::DB::GFF::Util::Binning;
use Bio::Graphics::Browser::Util qw[open_config];

use base 'Bio::GMOD::CMap';

# constants.

# this is the smallest bin (1 K)
use constant MIN_BIN    => 1000;

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
    my %gclass_lookup;
    $LOG_FH = $args{'log_fh'} || \*STDOUT;
    print $LOG_FH "Preparing Data for GBrowse\n";
    my $admin = $self->admin;

    for (my $i=0;$i<=$#{$feature_type_aids}; $i++){
        my $gclass = $self->feature_type_data($feature_type_aids->[$i],'gbrowse_class');
        if ($gclass){
            $gclass_lookup{$feature_type_aids->[$i]}=$gclass;
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
        unless (%gclass_lookup);

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
                feature_name => $self->create_fref_name($row->{'map_name'}),
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
        $sth->execute($gclass_lookup{$ft_aid},$ft_aid);
    }

    return 1;
}

# ----------------------------------------------
=pod

=head2 copy_data_into_gbrowse

Given a list of map set ids and an optional list of feature type accessions,
this will copy data from the CMap side of the db to the GBrowse side, allowing
it to be viewed in GBrowse.

=cut

sub copy_data_into_gbrowse {
    my ( $self, %args ) = @_;
    my $map_set_ids = $args{'map_set_ids'}
      or return $self->error('No map set ids');
    my $feature_type_aids = $args{'feature_type_aids'}
      or return $self->error('No feature type aids');
    my $db           = $self->db;
    my %gclass_lookup;
    my %ftype_lookup;
    $LOG_FH = $args{'log_fh'} || \*STDOUT;

    print $LOG_FH "Handling Feature Types\n";
    # unless feature types are specified, get all of them.
    unless ($feature_type_aids and @$feature_type_aids){
        my $feature_type_data = $self->feature_type_data();
        @$feature_type_aids = keys(%$feature_type_data);
    }

    # get the feature type aid that is used for the "Map feature" 
    # and make sure that it is not in the list of feature types
    my $gbrowse_map_ft_aid = $self->config_data('gbrowse_default_map_feature_type_aid'); 

    @$feature_type_aids = grep !/$gbrowse_map_ft_aid/, @$feature_type_aids;

    # Remove feature types that don't have the proper attributes
    # specified in the config file.
    for (my $i=0;$i<=$#{$feature_type_aids}; $i++){
        my $gclass = $self->feature_type_data($feature_type_aids->[$i],'gbrowse_class');
        my $ftype = $self->feature_type_data($feature_type_aids->[$i],'gbrowse_ftype');
        if ($gclass and $ftype){
            $gclass_lookup{$feature_type_aids->[$i]}=$gclass;
            $ftype_lookup{$feature_type_aids->[$i]}=$ftype;
        }
        else{
            print $LOG_FH $feature_type_aids->[$i]." will Not be used because it does not have the following: \n";
            print $LOG_FH "gbrowse_class\n" unless $gclass;
            print $LOG_FH "gbrowse_ftype\n" unless $ftype;
            print $LOG_FH "\n";
            splice @$feature_type_aids,$i,1;
            $i--;   
        }
    }

    #Make sure we have something to work with
    return $self->error( "No Map Sets to work on.\n" )
        unless ($map_set_ids and @$map_set_ids);
    return $self->error( "No Feature Types to work on.\n" )
        unless (%gclass_lookup);

    print $LOG_FH "Prepare data\n";

    # calling prepare_data_for_gbrowse since it's all written and everything
    $self->prepare_data_for_gbrowse( 
        map_set_ids => $map_set_ids,
        feature_type_aids => $feature_type_aids,
    ) or do {
        print "Error: ", $self->error, "\n";
        return;
    };


    # Make sure there are all the required ftypes and get their ftypeids
    my %ftypeid_lookup;
    $self->find_or_create_ftype(\%ftypeid_lookup,values(%ftype_lookup));

    

    # Get the data from CMap that is to be copied.
    # We will make the sql in a way that we don't get duplicate data.

    my $feature_sql = q[
        select  m.map_name,
                f.feature_id,
                f.feature_type_accession as feature_type_aid,
                f.start_position,
                f.stop_position,
                f.direction
        from    cmap_map m,
                cmap_feature f
        LEFT JOIN fdata 
        on      fdata.feature_id = f.feature_id
            and fdata.fstart = f.start_position
            and fdata.fstop = f.stop_position
        where   f.map_id=m.map_id
            and fdata.fid is NULL
            and m.map_set_id in ( 
    ].
        join (',',@$map_set_ids).
        qq[ ) 
            and f.feature_type_accession in ('
    ].
        join ("','",@$feature_type_aids).
        qq[ ')
    ];
    my $map_feature_sql = qq[
        select  m.map_name,
                ms.map_type_accession as map_type_aid,
                f.feature_id,
                f.feature_type_accession as feature_type_aid,
                f.start_position,
                f.stop_position,
                f.direction
        from    cmap_map m,
                cmap_map_set ms,
                cmap_feature f
        LEFT JOIN fdata 
        on      fdata.feature_id = f.feature_id
            and fdata.fstart = f.start_position
            and fdata.fstop = f.stop_position
        where   f.map_id=m.map_id
            and ms.map_set_id=m.map_set_id
            and fdata.fid is NULL
            and ms.map_set_id in ( 
    ].
        join (',',@$map_set_ids).
        qq[ ) 
            and f.feature_type_accession='$gbrowse_map_ft_aid'
    ];
            
    my $insert_data_sth = $db->prepare( q[
        insert into fdata 
        ( fref , fstart, fstop, fbin, ftypeid, fstrand, feature_id )
        values (?,?,?,?,?,?,?)
    ]);

    my ($fref,$fstart,$fstop,$fbin,$ftypeid,$fstrand,$feature_id);

    # Insert the new features
    my $feature_results = $db->selectall_arrayref( $feature_sql, { Columns => {} }, );
    foreach my $row (@$feature_results){
        $fref       = $self->create_fref_name($row->{'map_name'});
        $fstart     = $row->{'start_position'};
        $fstop      = $row->{'stop_position'} ;
        $fbin       = bin($fstart,$fstop,MIN_BIN);
        $ftypeid    = $ftypeid_lookup{$ftype_lookup{$row->{'feature_type_aid'}}};
        $fstrand    = ($row->{'feature_id'}>0) ? '+' : '-' ;
        $feature_id = $row->{'feature_id'};

        $insert_data_sth->execute($fref,$fstart,$fstop,$fbin,$ftypeid,$fstrand,$feature_id);
    }

    # Insert the new map features
    my $map_feature_results = $db->selectall_arrayref( $map_feature_sql, { Columns => {} }, );
    my %map_ftype_lookup;
    foreach my $row (@$map_feature_results){
        # First get the maps ftype
        unless ($map_ftype_lookup{$row->{'map_type_aid'}}){
            my $ftype = $self->map_type_data($row->{'map_type_aid'},'gbrowse_ftype');
            if ($ftype){
                $map_ftype_lookup{$row->{'map_type_aid'}}=$ftype;
            }
            else{
                print $LOG_FH "Map Type with aid ".$row->{'map_type_aid'}." not eligible\n";
                print $LOG_FH "If you wish to prepare this map type, add a gbrowse_ftype to it in the config file\n";
                return $self->error("Map Type Not Accepted: ".$row->{'map_type_aid'}."\n");
            }
        }
        # Next get the id of the ftype
        unless ($ftypeid_lookup{$map_ftype_lookup{$row->{'map_type_aid'}}}){ 
            $self->find_or_create_ftype(\%ftypeid_lookup,$map_ftype_lookup{$row->{'map_type_aid'}});
        }
        
        $fref       = $self->create_fref_name($row->{'map_name'});
        $fstart     = $row->{'start_position'};
        $fstop      = $row->{'stop_position'} ;
        $fbin       = bin($fstart,$fstop,MIN_BIN);
        $ftypeid    = $ftypeid_lookup{$map_ftype_lookup{$row->{'map_type_aid'}}};
        $fstrand    = '+' ;
        $feature_id = $row->{'feature_id'};

        $insert_data_sth->execute($fref,$fstart,$fstop,$fbin,$ftypeid,$fstrand,$feature_id);
    }

    return 1;
}

# ----------------------------------------------
=pod

=head2 copy_data_into_cmap

Given a list of map set ids and an optional list of feature type accessions,
this will copy data from the CMap side of the db to the GBrowse side, allowing
it to be viewed in GBrowse.

=cut

sub copy_data_into_cmap {
    my ( $self, %args ) = @_;
    my $map_set_id = $args{'map_set_id'}
      or return $self->error('No map set ids');
    my $db           = $self->db;
    my %fmethod_to_ft_aid;

    my $gbrowse_config_dir = $self->config_data('gbrowse_config_dir');
    return  $self->error('No gbrowse_config_dir defined in config file') unless $gbrowse_config_dir;

    my $gbrowse_config = $self->config_data('gbrowse_config_file');
    return $self->error('No gbrowse_config_file defined in config file') unless $gbrowse_config;
    $gbrowse_config =~ s/\.conf$//;
    $gbrowse_config =~ s/^\d+\.//;

    my $main_gbconfig = open_config($gbrowse_config_dir);
    $main_gbconfig->source($gbrowse_config) or return $self->("Reading $gbrowse_config FAILED");
    my $gbconfig = $main_gbconfig->config();
    my $track_info = $gbconfig->{'config'};
                                                                                                                             
    my @labels = $gbconfig->labels();
    my $fmethod;
    # Build the connection between fmethod and ft_aids
    foreach my $label (@labels){
        if ( $track_info->{$label}{'cmap_feature_type_accession'} ) {
            $fmethod = $track_info->{$label}{'feature'};
            $fmethod =~ s/:.+//;
            $fmethod_to_ft_aid{ $fmethod } = $track_info->{$label}{'cmap_feature_type_accession'};
        }
    }
    
    my $data_sql = q[
        select
            m_group.feature_name as map_name,
            m_data.fstart as map_start,
            m_data.fstop as map_stop,
            f_group.feature_id,
            f_group.accession_id as feature_aid,
            f_group.feature_name as feature_name,
            f_data.fstart as feature_start,
            f_data.fstop as feature_stop,
            f_data.fstrand as feature_strand,
            f_type.fmethod as feature_method
        from cmap_feature m_group,
            cmap_feature f_group,
            fdata m_data,
            fdata f_data,
            ftype f_type
        where
            m_data.feature_id=m_group.feature_id
            and (not f_group.map_id > 0)
            and f_data.fref=m_group.feature_name
            and f_data.feature_id=f_group.feature_id
            and f_data.ftypeid=f_type.ftypeid 
    ];
    $data_sql .= " and f_type.fmethod in ('"
        . join ("','", keys(%fmethod_to_ft_aid) )
        . "')";
    $data_sql .= " order by m_group.feature_name ";

    my $feature_results = $db->selectall_arrayref( $data_sql, { Columns => {} }, );

    my $current_map_name;
    my $map_id;
    my $admin = $self->admin;
    my ($direction,$ft_aid);
    my $map_count = 0;

    foreach my $row (@$feature_results){
        unless (defined $map_id and $current_map_name eq $row->{'map_name'}){
            $map_count++;
            $current_map_name = $row->{'map_name'};
            $map_id = $admin->map_create(
                map_name => $row->{'map_name'},
                map_set_id => $map_set_id,
                start_position => $row->{'map_start'},
                stop_position => $row->{'map_stop'},
            );
        }
        $direction = 1;
        if ( (defined($row->{'feature_strand'})
              and $row->{'feature_strand'} eq '-')
            or $row->{'feature_stop'}<$row->{'feature_start'}){
            $direction = -1;
        }
        $ft_aid = $fmethod_to_ft_aid{$row->{'feature_method'}};
        

        $admin->feature_update(
                map_id => $map_id,
                feature_id => $row->{'feature_id'},
                feature_name => $row->{'feature_name'},
                start_position => $row->{'feature_start'},
                stop_position => $row->{'feature_stop'},
                feature_type_accession => $ft_aid,
                direction => $direction,
        );
    }
    print "Copied ".scalar(@$feature_results)." features on $map_count maps.\n";



    return 1;
}

# ----------------------------------------------
=pod

=head2 create_fref_name

This method gives a stable way to name the feature that represents a GBrowse
reference sequence.

=cut

sub create_fref_name {
    my $self     = shift;
    my $map_name = shift;
    
    return $map_name;
}

# ----------------------------------------------
=pod

=head2 find_or_create_ftype

Takes lookup hash and a list of ftype fmethods and fills the lookup hash with
the ftypeids with the fmethod as the key.

=cut

sub find_or_create_ftype {
    my $self       = shift;
    my $lookup     = shift;
    my @ftype_list = @_;
    my $db         = $self->db;

    my $sth = $db->prepare( q[
        select  ftypeid 
        from    ftype
        where   fmethod=?]
     );
    my $insert_type_sth = $db->prepare( q[
        insert into ftype 
        (fmethod,fsource) 
        values (?,'.')
    ]);

    
    foreach my $ftype (@ftype_list){
        next if ($lookup->{$ftype});
        $sth->execute($ftype);
        my $ftype_result = $sth->fetchrow_hashref;
        if ($ftype_result and %$ftype_result) {
            $lookup->{$ftype}=$ftype_result->{'ftypeid'};
        }
        else{
            $insert_type_sth->execute($ftype);
            $sth->execute($ftype);
            my $ftype_result = $sth->fetchrow_hashref;
            if ($ftype_result and %$ftype_result) {
                $lookup->{$ftype}=$ftype_result->{'ftypeid'};
            }
            else{
                die "Something terrible has happened and the ftype, $ftype did not insert\n";
            }
        }
    }
}

sub admin {
    my $self = shift;

    unless($self->{'admin'}){
        $self->{'admin'} = Bio::GMOD::CMap::Admin->new(
          data_source => $self->data_source
        );
    }
    return $self->{'admin'};
}

1;
