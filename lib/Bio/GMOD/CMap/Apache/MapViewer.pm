package Bio::GMOD::CMap::Apache::MapViewer;
# vim: set ft=perl:

# $Id: MapViewer.pm,v 1.57 2004-09-01 20:50:49 mwz444 Exp $

use strict;
use vars qw( $VERSION $INTRO $PAGE_SIZE $MAX_PAGES);
$VERSION = (qw$Revision: 1.57 $)[-1];

use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Drawer;
use Bio::GMOD::CMap::Data;
use Template;
use URI::Escape;
use Regexp::Common;
use Data::Dumper;

use base 'Bio::GMOD::CMap::Apache';
use constant TEMPLATE     => 'cmap_viewer.tmpl';
use constant DETAIL_TEMPLATE     => 'map_detail_bottom.tmpl';
use constant FIELD_SEP       => "\t";
use constant RECORD_SEP      => "\n";
use constant COLUMN_NAMES    => [
    qw[ species_accession_id species_name 
        map_set_accession_id map_set_name
        map_accession_id map_name
        feature_accession_id feature_name feature_type start_position 
        stop_position alt_species_name alt_map_set_name alt_map_name 
        alt_feature_type alt_start_position alt_stop_position 
        evidence
    ]
];
use constant MAP_FIELDS      => [
    qw[ species_aid species_name map_set_aid map_set_name map_aid map_name ]
];
use constant FEATURE_FIELDS  => [
    qw[ accession_id feature_name feature_type start_position stop_position ]
];
use constant POSITION_FIELDS => [
    qw[ species_name map_set_name map_name feature_type 
        start_position stop_position evidence
    ]
];

# ----------------------------------------------------
sub handler {
#
# Main entry point.  Decides whether we forked and whether to 
# read session data.  Calls "show_form."
#
    my ( $self, $apr ) = @_;
    my $prev_ref_species_aid  = $apr->param('prev_ref_species_aid')  || '';
    my $prev_ref_map_set_aid  = $apr->param('prev_ref_map_set_aid')  || '';
    my $ref_species_aid       = $apr->param('ref_species_aid')       || '';
    my $ref_map_set_aid       = $apr->param('ref_map_set_aid')       || '';
    my $ref_map_names         = $apr->param('ref_map_names')         || '';
    my $ref_map_start         = $apr->param('ref_map_start');
    my $ref_map_stop          = $apr->param('ref_map_stop');
    my $comparative_maps      = $apr->param('comparative_maps')      || '';
    my @comparative_map_right = $apr->param('comparative_map_right');
    my @comparative_map_left  = $apr->param('comparative_map_left');
    my $highlight             = $apr->param('highlight')             || '';
    my $font_size             = $apr->param('font_size')             || '';
    my $image_size            = $apr->param('image_size')            || '';
    my $image_type            = $apr->param('image_type')            || '';
    my $label_features        = $apr->param('label_features')        || '';
    my $collapse_features     = $apr->param('collapse_features')     ||  0;
    my $aggregate             = $apr->param('aggregate')             ;
    my $scale_maps            = $apr->param('scale_maps')             ;
    my $flip                  = $apr->param('flip')                  || '';
    my $min_correspondences   = $apr->param('min_correspondences')   ||  0;
    my $page_no               = $apr->param('page_no')               ||      1;
    my $action                = $apr->param('action')                || 'view';


    my $path_info = $apr->path_info || '';
    if ( $path_info ) {
       $path_info =~ s{^/(cmap/)?}{}; # kill superfluous stuff
    }

    $self->aggregate($aggregate);
    $self->scale_maps($scale_maps);

    $INTRO ||= $self->config_data('map_viewer_intro', $self->data_source)||'';

    #
    # Take the feature types either from the query string (first
    # choice, splitting the string on commas) or from the POSTed 
    # form <select>.
    #
    my @ref_map_aids;
    if ( $apr->param('ref_map_aids') ) {
        foreach my $aid ($apr->param('ref_map_aids')){
            push @ref_map_aids,split( /[:,]/,$aid);
        }
    }
    ###For DEBUGGING purposes.  Remove before release
    if ( $apr->param('ref_map_aid') ) {
        die "ref_map_aid defined ".$apr->param('ref_map_aid');
    }

    my %ref_maps;
    my %ref_map_sets=();
    foreach my $ref_map_aid (@ref_map_aids){
        next if ($ref_map_aid == -1);
        my ($start, $stop) = (undef,undef);
        if ($ref_map_aid =~/^(\S+)\[(.*)\*(.*)\]/){
            $ref_map_aid = $1;
            ($start,$stop)=($2,$3); 
            $start = undef unless($start =~ /\S/);
            $stop  = undef unless($stop  =~ /\S/);
            my $start_stop_feature=0;
            if ($start !~ /^$RE{'num'}{'real'}$/){
                $highlight = join( ',', $highlight, $start );
                $start_stop_feature=1;
            }
            if ($stop !~ /^$RE{'num'}{'real'}$/){
                $highlight = join( ',', $highlight, $stop );
                $start_stop_feature=1;
            }
            if ((not $start_stop_feature) and defined($start) and defined($stop) 
                and $stop<$start){
                ($start,$stop)= ($stop,$start); 
            }
        } 
        $ref_maps{$ref_map_aid} = {start=>$start,stop=>$stop};
    }
    if (scalar @ref_map_aids==1){
        unless ($ref_map_aids[0]=='-1'){
            if (defined($ref_map_start) and not defined($ref_maps{$ref_map_aids[0]}{'start'})){
                $ref_maps{$ref_map_aids[0]}{'start'} =$ref_map_start;
            }
            if (defined($ref_map_stop)
                 and not defined($ref_maps{$ref_map_aids[0]}{'stop'})){
                $ref_maps{$ref_map_aids[0]}{'stop'} =$ref_map_stop;
            }
        }
    }


    my @ref_map_set_aids=();
    if ( $apr->param('ref_map_set_aid') ) {
        @ref_map_set_aids = split( /,/,  $apr->param('ref_map_set_aid') );
    }

    my @feature_types;
    my @corr_only_feature_types;
    my $feature_types_undefined=1;
    foreach my $param ($apr->param){
        if ($param=~/^feature_type_(\S+)/){
            my $ft  = $1;
            $feature_types_undefined=0;
            my $val = $apr->param($param);
            if ($val==1){
                push @corr_only_feature_types,$ft;
            }
            elsif ($val==2){
                push @feature_types,$ft;
            }
        }
    }

    my %include_corr_only_features = map{$_=>1} @corr_only_feature_types;

    my @evidence_types;
    if ( $apr->param('evidence_types') ) {
        foreach my $et ($apr->param('evidence_types')){
            push @evidence_types,split( /[:,]/,$et);
        }
        unless(@evidence_types){
            @evidence_types = split( /,/, $apr->param('evidence_types') );
        }
    }
    elsif ( $apr->param('include_evidence_types') ) {
        @evidence_types = split( /,/, $apr->param('include_evidence_types') );
    }

    #
    # Set the data source.
    #
    $self->data_source( $apr->param('data_source') ) or return;

    if ( 
        $prev_ref_species_aid && $prev_ref_species_aid ne $ref_species_aid 
    ) {
        $ref_map_set_aid = '';
        @ref_map_set_aids      = ();
    }

    if ( 
        $prev_ref_map_set_aid && $prev_ref_map_set_aid ne $ref_map_set_aid 
    ) {
        @ref_map_aids          = ();
        @ref_map_set_aids      = ();
        $ref_map_start         = undef;
        $ref_map_stop          = undef;
        $ref_map_names         = '';
        $comparative_maps      = undef;
        @comparative_map_right = ();
        @comparative_map_left  = ();
    }

    if ( grep {/^-1$/} @ref_map_aids ) {
        $ref_map_sets{$ref_map_set_aid}=();
    }

    my %slots=();
    #if (%ref_maps or %ref_map_sets){
        %slots = ( 
            0 => {
                map_set_aid => $ref_map_set_aid,
                map_sets    => \%ref_map_sets,
                maps        => \%ref_maps,
                map_names   => $ref_map_names, 
            });
    #}

    #
    # Add in previous maps.
    #
    for my $cmap ( split( /:/, $comparative_maps ) ) {
        my ( $slot_no, $field, $accession_id ) = split(/=/, $cmap) or next;
        my ( $start, $stop );
        foreach my $aid (split /,/,$accession_id){
            if ( $aid =~ m/^(.+)\[(.*)\*(.*)\]$/ ) {
                $aid=$1;
                ($start,$stop)=($2,$3); 
                $start = undef unless($start =~ /\S/);
                $stop  = undef unless($stop  =~ /\S/);
                my $start_stop_feature=0;
                if ($start !~ /^$RE{'num'}{'real'}$/){
                    $highlight = join( ',', $highlight, $start );
                    $start_stop_feature=1;
                }
                if ($stop !~ /^$RE{'num'}{'real'}$/){
                    $highlight = join( ',', $highlight, $stop );
                    $start_stop_feature=1;
                }
                if ((not $start_stop_feature) and defined($start) and defined($stop) 
                    and $stop<$start){
                    ($start,$stop)= ($stop,$start); 
                }
            }
            if ($field eq 'map_aid'){
                $slots{$slot_no}->{'maps'}{$aid} =  {
                    start          => $start,
                    stop           => $stop,
                };
            }
            elsif ($field eq 'map_set_aid'){
                unless(defined($slots{$slot_no}->{'map_sets'}{$aid})){
                    $slots{$slot_no}->{'map_sets'}{$aid}=();
                }
            }
        }
    }

    my @slot_nos  = sort { $a <=> $b } keys %slots;
    my $max_right = $slot_nos[-1];
    my $max_left  = $slot_nos[ 0];

    #
    # Add in our next chosen maps.
    #
    for my $side ( ( RIGHT, LEFT ) ) {
        my $slot_no = $side eq RIGHT ? $max_right + 1 : $max_left - 1;
        my $cmap    = $side eq RIGHT 
            ? \@comparative_map_right : \@comparative_map_left;
        ###Use the first comp_map to determine the field
        foreach my $cmap_str (@$cmap){
            my ( $field, $accession_id ) = split( /=/, $cmap_str ) or next;
            my ( $start, $stop );
            if ( $accession_id =~ m/^(.+)\[(.*)\*(.*)\]$/ ) {
                $accession_id = $1;
                $start        = $2;
                $stop         = $3;
                $start = undef unless($start =~ /\S/);
                $stop  = undef unless($stop  =~ /\S/);
                my $start_stop_feature=0;
                if ($start !~ /^$RE{'num'}{'real'}$/){
                    $highlight = join( ',', $highlight, $start );
                    $start_stop_feature=1;
                }
                if ($stop !~ /^$RE{'num'}{'real'}$/){
                    $highlight = join( ',', $highlight, $stop );
                    $start_stop_feature=1;
                }
            }
            if ($field eq 'map_aid'){
                $slots{$slot_no}->{'maps'}{$accession_id} =  {
                    start          => $start,
                    stop           => $stop,
                };
            }
            elsif ($field eq 'map_set_aid'){
                unless(defined($slots{$slot_no}->{'map_sets'}{$accession_id})){
                    $slots{$slot_no}->{'map_sets'}{$accession_id}=();
                }
            }
        } 
    }

    #
    # Instantiate the drawer if there's at least one map to draw.
    #
    my ($drawer,$extra_code,$extra_form);
    if ( @ref_map_aids || $ref_map_names ) {
        $drawer                    =  Bio::GMOD::CMap::Drawer->new(
            apr                    => $apr,
            data_source            => $self->data_source,
            slots                  => \%slots,
            flip                   => $flip,
            highlight              => $highlight,
            font_size              => $font_size,
            image_size             => $image_size,
            image_type             => $image_type,
            label_features         => $label_features,
            collapse_features      => $collapse_features,
            min_correspondences    => $min_correspondences,
            include_feature_types  => \@feature_types,
            corr_only_feature_types=> \@corr_only_feature_types,
            include_evidence_types => \@evidence_types,
            config                 => $self->config,
            data_module            => $self->data_module,
            aggregate              => $self->aggregate,
            scale_maps              => $self->scale_maps,
            feature_types_undefined => $feature_types_undefined,
        ) or return $self->error( Bio::GMOD::CMap::Drawer->error );

        %slots = %{ $drawer->{'slots'} };
        $extra_code=$drawer->{'data'}->{'extra_code'};
        $extra_form=$drawer->{'data'}->{'extra_form'};
    }

    
    #
    # Get the data for the form.
    #
    my $data                   = $self->data_module;
    my $form_data              = $data->cmap_form_data( 
        slots                  => \%slots,
        min_correspondences    => $min_correspondences,
        include_feature_types  => \@feature_types,
        include_evidence_types => \@evidence_types,
        ref_species_aid        => $ref_species_aid,
        ref_map_set_aid        => $ref_map_set_aid,
    ) or return $self->error( $data->error );

    $form_data->{'feature_types'} = 
        [
        sort {
                lc $a->{'feature_type'} cmp lc $b->{'feature_type'}
            } @{ $self->data_module->get_all_feature_types}
        ];

    #
    # Wrap up our current comparative maps so we can store them on 
    # the next page the user sees.
    #
    my @comp_maps = ();
    for my $slot_no ( grep { $_ != 0 } keys %slots ) {
        foreach my $map_aid (keys(%{$slots{$slot_no}{'maps'}})){
            my $map_str = join( '=', $slot_no, 'map_aid', $map_aid);
            if (defined $slots{$slot_no}{'maps'}{$map_aid}{'start'}
                or 
                defined $slots{$slot_no}{'maps'}{$map_aid}{'stop'}){
                $map_str .= "["
                  . $slots{$slot_no}{'maps'}{$map_aid}{'start'}."*"
                  . $slots{$slot_no}{'maps'}{$map_aid}{'stop'}
                  . "]";
            }
            push @comp_maps, $map_str;
        }
        foreach my $map_aid (keys(%{$slots{$slot_no}{'map_sets'}})){
            my $map_str = join( '=', $slot_no, 'map_set_aid', $map_aid);
            push @comp_maps, $map_str;
        }
    }
  
    my $html;
    my $t = $self->template or return;
    $t->process( 
        TEMPLATE, 
        {
            apr               => $apr,
            form_data         => $form_data,
            drawer            => $drawer,
            page              => $self->page,
            debug             => $self->debug,
            intro             => $INTRO,
            data_source       => $self->data_source,
            data_sources      => $self->data_sources,
            comparative_maps  => join( ':', @comp_maps ),
            title             => $self->config_data('cmap_title') || 'CMap',
            stylesheet        => $self->stylesheet,
            selected_maps     => { map { $_, 1 } @ref_map_aids   },
            included_features => { map { $_, 1 } @feature_types  },
            included_evidence => { map { $_, 1 } @evidence_types },
            included_corr_only_features => \%include_corr_only_features,
            feature_types     => join( ',', @feature_types ),
            feature_types_undefined => $feature_types_undefined,
            evidence_types    => join( ',', @evidence_types ),
            extra_code        => $extra_code,
            extra_form        => $extra_form,
        },
        \$html 
    ) or $html = $t->error;


    if ($path_info eq 'map_details' and scalar(keys(%ref_maps))==1){
            
        $PAGE_SIZE ||= $self->config_data('max_child_elements') || 0;
        $MAX_PAGES ||= $self->config_data('max_search_pages')   || 1;
        my ($map_id,) = keys(%ref_maps);

        my $detail_data            = $data->map_detail_data(
            ref_map                => $drawer->{'data'}{'slots'}{0}{$map_id},
            highlight              => $highlight,
            include_feature_types  => \@feature_types,
            include_evidence_types => \@evidence_types,
            order_by               => $apr->param('order_by') || '',
            comparative_map_field  => '',
            comparative_map_aid    => '',
            page_size              => $PAGE_SIZE,
            max_pages              => $MAX_PAGES,
            page_no                => $page_no,
            page_data              => $action eq 'download' ? 0 : 1,
        ) or return $self->error( "Data: ".$data->error );

        if ( $action eq 'download' ) {
            my $text       = join( FIELD_SEP, @{ +COLUMN_NAMES } ).RECORD_SEP;
            my $map_fields = join(
                FIELD_SEP, map { $detail_data->{'reference_map'}{$_} } @{ +MAP_FIELDS }
            );

            for my $feature ( @{ $detail_data->{'features'} } ) {
                my $row = join(
                    FIELD_SEP, 
                    $map_fields, map { $feature->{$_} } @{ +FEATURE_FIELDS }
                );

                if ( @{ $feature->{'positions'} } ) {
                    for my $position ( @{ $feature->{'positions'} } ) {
                        $position->{'evidence'} = 
                            join( ',', @{ $position->{'evidence'} } );
                        $text .= join(
                            FIELD_SEP, 
                            $row,
                            map { defined $position->{$_} ? $position->{$_} : '' } 
                                @{ +POSITION_FIELDS }
                        ) . RECORD_SEP;
                    }
                }
                else {
                    $text .= $row . RECORD_SEP;
                }
            }

            print $apr->header( -type => 'text/plain' ), $text;
        }
        else {
            my @map_ids    = map {$_||()} keys %{$drawer->{'data'}{'slots'}{'0'}};
            my $ref_map_id = shift @map_ids;
            my $ref_map    = $drawer->{'data'}{'slots'}{'0'}{ $ref_map_id };
            $apr->param('ref_map_start',  $ref_map->{'start'}         );
            $apr->param('ref_map_stop',   $ref_map->{'stop'}          );
            $apr->param('feature_types',  join(',', @feature_types )  );
            $apr->param('evidence_types', join(',', @evidence_types ) );
            $apr->param('highlight_uri',  uri_escape( $apr->param('highlight') ) );

            my $detail_html;
            my $t = $self->template;
            $t->process( 
                DETAIL_TEMPLATE, 
                { 
                    apr                   => $apr,
                    pager                 => $detail_data->{'pager'},
                    feature_types         => $detail_data->{'feature_types'},
                    feature_count_by_type => $detail_data->{'feature_count_by_type'},
                    evidence_types        => $detail_data->{'evidence_types'},
                    reference_map         => $detail_data->{'reference_map'},
                    comparative_maps      => $detail_data->{'comparative_maps'},
                    comparative_map_field => '',
                    comparative_map_aid   => '',
                    drawer                => $drawer,
                    page                  => $self->page,
                    title                 => 'Reference Map Details',
                    stylesheet            => $self->stylesheet,
                    included_features     => { map { $_, 1 } @feature_types },
                    included_evidence     => { map { $_, 1 } @evidence_types },
                    features              => $detail_data->{'features'},
                },
                \$detail_html 
            ) or $detail_html = $t->error;

            print $apr->header( -type => 'text/html', -cookie => $self->cookie ), 
                $html,
                $detail_html;
        }
    }
    else{
        # Regular map Viewing
        print $apr->header( -type => 'text/html', -cookie => $self->cookie ), $html;
    }
    return 1;
}

1;

# ----------------------------------------------------
# Prisons are built with stones of Law,
# Brothels with bricks of Religion.
# William Blake
# ----------------------------------------------------

=head1 NAME

Bio::GMOD::CMap::Apache::MapViewer - view comparative maps

=head1 SYNOPSIS

In httpd.conf:

  <Location /cmap/viewer>
      SetHandler  perl-script
      PerlHandler Bio::GMOD::CMap::Apache::MapViewer->super
  </Location>

=head1 DESCRIPTION

This module is a mod_perl handler for displaying the user interface to
select and display comparative maps.  It inherits from
Bio::GMOD::CMap::Apache where all the error handling occurs.

Added forking to allow creation of really large maps.  Stole most of
the implementation from Randal Schwartz:

    http://www.stonehenge.com/merlyn/LinuxMag/col39.html

=head1 SEE ALSO

L<perl>, L<Template>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
