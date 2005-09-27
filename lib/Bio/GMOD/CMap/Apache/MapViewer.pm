package Bio::GMOD::CMap::Apache::MapViewer;

# vim: set ft=perl:

# $Id: MapViewer.pm,v 1.116 2005-09-27 16:02:27 mwz444 Exp $

use strict;
use vars qw( $VERSION $INTRO $PAGE_SIZE $MAX_PAGES);
$VERSION = (qw$Revision: 1.116 $)[-1];

use Bio::GMOD::CMap::Apache;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Drawer;
use Bio::GMOD::CMap::Data;
use Bio::GMOD::CMap::Utils;
use CGI::Session;
use Template;
use URI::Escape;
use Regexp::Common;
use Clone qw(clone);
use Data::Dumper;

use base 'Bio::GMOD::CMap::Apache';
use constant TEMPLATE        => 'cmap_viewer.tmpl';
use constant DETAIL_TEMPLATE => 'map_detail_bottom.tmpl';
use constant FIELD_SEP       => "\t";
use constant RECORD_SEP      => "\n";
use constant COLUMN_NAMES    => [
    qw[ species_acc species_common_name
      map_set_acc map_set_name
      map_acc map_name
      feature_acc feature_name feature_type_acc feature_start
      feature_stop alt_species_common_name alt_map_set_name alt_map_name
      alt_feature_type alt_feature_start alt_feature_stop
      evidence
      ]
];
use constant MAP_FIELDS => [
    qw[ species_acc species_common_name map_set_acc map_set_short_name map_acc map_name ]
];
use constant FEATURE_FIELDS => [
    qw[ feature_acc feature_name feature_type_acc feature_start feature_stop ]
];
use constant POSITION_FIELDS => [
    qw[ species_common_name2 map_set_short_name2 map_name2 feature_type_acc2
      feature_start2 feature_stop2 evidence
      ]
];

# ----------------------------------------------------
sub handler {

    #
    # Main entry point.  Decides whether we forked and whether to
    # read session data.  Calls "show_form."
    #
    my ( $self, $apr ) = @_;
    my $prev_ref_species_acc = $apr->param('prev_ref_species_acc')
      || $apr->param('prev_ref_species_aid')
      || '';
    my $prev_ref_map_set_acc = $apr->param('prev_ref_map_set_acc')
      || $apr->param('prev_ref_map_set_aid')
      || '';
    my $ref_species_acc = $apr->param('ref_species_acc')
      || $apr->param('ref_species_aid')
      || '';
    my $ref_map_set_acc = $apr->param('ref_map_set_acc')
      || $apr->param('ref_map_set_aid')
      || '';
    my $ref_map_start           = $apr->param('ref_map_start');
    my $ref_map_stop            = $apr->param('ref_map_stop');
    my $comparative_maps        = $apr->param('comparative_maps') || '';
    my @comparative_map_right   = $apr->param('comparative_map_right');
    my @comparative_map_left    = $apr->param('comparative_map_left');
    my $comp_map_set_right      = $apr->param('comp_map_set_right');
    my $comp_map_set_left       = $apr->param('comp_map_set_left');
    my $highlight               = $apr->param('highlight') || '';
    my $font_size               = $apr->param('font_size') || '';
    my $image_size              = $apr->param('image_size') || '';
    my $image_type              = $apr->param('image_type') || '';
    my $label_features          = $apr->param('label_features') || '';
    my $collapse_features       = $apr->param('collapse_features');
    my $aggregate               = $apr->param('aggregate');
    my $cluster_corr            = $apr->param('cluster_corr');
    my $show_intraslot_corr     = $apr->param('show_intraslot_corr');
    my $split_agg_ev            = $apr->param('split_agg_ev');
    my $clean_view              = $apr->param('clean_view');
    my $corrs_to_map            = $apr->param('corrs_to_map');
    my $magnify_all             = $apr->param('magnify_all');
    my $ignore_image_map_sanity = $apr->param('ignore_image_map_sanity');
    my $scale_maps              = $apr->param('scale_maps');
    my $stack_maps              = $apr->param('stack_maps');
    my $comp_menu_order         = $apr->param('comp_menu_order');
    my $ref_map_order           = $apr->param('ref_map_order');
    my $prev_ref_map_order      = $apr->param('prev_ref_map_order');
    my $flip                    = $apr->param('flip') || '';
    my $page_no                 = $apr->param('page_no') || 1;
    my $action                  = $apr->param('action') || 'view';
    my $refMenu                 = $apr->param('refMenu');
    my $compMenu                = $apr->param('compMenu');
    my $optionMenu              = $apr->param('optionMenu');
    my $addOpMenu               = $apr->param('addOpMenu');
    my $omit_area_boxes         = $apr->param('omit_area_boxes');
    my $session_id              = $apr->param('session_id');
    my $step                    = $apr->param('step') || 0;
    my $session_mod             = $apr->param('session_mod') || '';
    my $left_min_corrs          = $apr->param('left_min_corrs') || 0;
    my $right_min_corrs         = $apr->param('right_min_corrs') || 0;
    my $general_min_corrs       = $apr->param('general_min_corrs');
    my $menu_min_corrs          = $apr->param('menu_min_corrs') || 0;

    # Check for depricated min_correspondences value
    # Basically general_min_corrs is a new way to address
    # the min_correspondences legacy while keeping the option
    # for this feature open in the future.
    $general_min_corrs = $apr->param('min_correspondences')
      unless defined($general_min_corrs);
    my %slots_min_corrs;

    if ($general_min_corrs) {
        unless ( defined($left_min_corrs) ) {
            $left_min_corrs = $general_min_corrs;
            $apr->param( 'left_min_corrs', $left_min_corrs );
        }
        unless ( defined($right_min_corrs) ) {
            $right_min_corrs = $general_min_corrs;
            $apr->param( 'right_min_corrs', $right_min_corrs );
            unless ( defined($menu_min_corrs) ) {
                $menu_min_corrs = $general_min_corrs;
                $apr->param( 'menu_min_corrs', $menu_min_corrs );
            }
        }
    }

    my ( %slots, $next_step );
    my $reusing_step = 0;

    # If this was submitted by a button, clear the modified map fields.
    # They are no longer needed.
    if ( $apr->param('sub') ) {
        $apr->param( 'modified_ref_map',  '' );
        $apr->param( 'modified_comp_map', '' );
    }

    my $path_info = $apr->path_info || '';
    if ($path_info) {
        $path_info =~ s{^/(cmap/)?}{};    # kill superfluous stuff
    }

    $collapse_features = $self->config_data('collapse_features')
      unless ( defined($collapse_features) );

    # reset the params only if you want the code to be able to change them.
    # otherwise, simply initialize the avalue.
    $apr->param( 'aggregate', $self->aggregate($aggregate) );
    $self->cluster_corr($cluster_corr);
    $apr->param( 'show_intraslot_corr',
        $self->show_intraslot_corr($show_intraslot_corr) );
    $apr->param( 'split_agg_ev',    $self->split_agg_ev($split_agg_ev) );
    $apr->param( 'clean_view',      $self->clean_view($clean_view) );
    $apr->param( 'magnify_all',     $self->magnify_all($magnify_all) );
    $apr->param( 'scale_maps',      $self->scale_maps($scale_maps) );
    $apr->param( 'stack_maps',      $self->stack_maps($stack_maps) );
    $apr->param( 'comp_menu_order', $self->comp_menu_order($comp_menu_order) );

    if ($ref_map_order) {
        $self->ref_map_order($ref_map_order);
    }
    else {

        #use the previous order if new order is not defined.
        $self->ref_map_order($prev_ref_map_order);
    }

    $INTRO ||= $self->config_data( 'map_viewer_intro', $self->data_source )
      || '';

    #
    # Take the feature types either from the query string (first
    # choice, splitting the string on commas) or from the POSTed
    # form <select>.
    #
    my @ref_map_accs;
    if ( $apr->param('ref_map_accs') or $apr->param('ref_map_aids') ) {
        foreach
          my $acc ( $apr->param('ref_map_accs'), $apr->param('ref_map_aids') )
        {

            # Remove start and stop if they are the same
            while ( $acc =~ s/(.+\[)(\d+)\*\2(\D.*)/$1*$3/ ) { }
            push @ref_map_accs, split( /[:,]/, $acc );
        }
    }

    if ( scalar(@ref_map_accs) ) {
        $apr->param( 'ref_map_accs', join( ":", @ref_map_accs ) );
    }

    #
    # Catch old argument, handle nicely.
    #
    if ( $apr->param('ref_map_acc') || $apr->param('ref_map_aid') ) {
        push @ref_map_accs,
          $apr->param('ref_map_acc') || $apr->param('ref_map_aid');
    }

    my %ref_maps;
    my %ref_map_sets = ();
    foreach my $ref_map_acc (@ref_map_accs) {
        next if $ref_map_acc == -1;
        my ( $start, $stop, $magnification ) = ( undef, undef, 1 );
        ( $ref_map_acc, $start, $stop, $magnification, $highlight ) =
          parse_map_info( $ref_map_acc, $highlight );
        $ref_maps{$ref_map_acc} =
          { start => $start, stop => $stop, mag => $magnification };
    }

    # Only included for legacy urls
    # Deal with modified ref map
    # map info specified in this param trumps 'ref_map_accs' info
    if ( $apr->param('modified_ref_map') ) {
        my $ref_map_acc = $apr->param('modified_ref_map');

        # remove duplicate start and end
        while ( $ref_map_acc =~ s/(.+\[)(\d+)\*\2(\D.*)/$1*$3/ ) { }
        $apr->param( 'modified_ref_map', $ref_map_acc );

        my ( $start, $stop, $magnification ) = ( undef, undef, 1 );
        ( $ref_map_acc, $start, $stop, $magnification, $highlight ) =
          parse_map_info( $ref_map_acc, $highlight );
        $ref_maps{$ref_map_acc} =
          { start => $start, stop => $stop, mag => $magnification };

        # Add the modified version into the comparative_maps param
        my $found = 0;
        for ( my $i = 0 ; $i <= $#ref_map_accs ; $i++ ) {
            my $old_map_acc = $ref_map_accs[$i];
            $old_map_acc =~ s/^(.*)\[.*/$1/;
            if ( $old_map_acc eq $ref_map_acc ) {
                $ref_map_accs[$i] = $apr->param('modified_ref_map');
                $found = 1;
                last;
            }
        }
        push @ref_map_accs, $apr->param('modified_ref_map') if !$found;
        $apr->param( 'ref_map_accs', join( ":", @ref_map_accs ) );
    }

    my @ref_map_set_accs = ();
    if ( $apr->param('ref_map_set_acc') || $apr->param('ref_map_set_aid') ) {
        @ref_map_set_accs =
          split( /,/,
            $apr->param('ref_map_set_acc') || $apr->param('ref_map_set_aid') );
    }

    my @feature_types;
    my $url_feature_default_display = undef;
    my @corr_only_feature_types;
    my @ignored_feature_types;
    my @included_evidence_types;
    my @ignored_evidence_types;
    my @less_evidence_types;
    my @greater_evidence_types;
    my %evidence_type_score;

    foreach my $param ( $apr->param ) {
        if ( $param =~ /^ft_(\S+)/ or $param =~ /^feature_type_(\S+)/ ) {
            my $ft  = $1;
            my $val = $apr->param($param);
            if ( $ft eq 'DEFAULT' ) {
                if ( $val =~ /^\d$/ ) {
                    $url_feature_default_display = $val;
                }
                else {
                    $url_feature_default_display = undef;
                }
                next;
            }
            if ( $val == 0 ) {
                push @ignored_feature_types, $ft;
            }
            elsif ( $val == 1 ) {
                push @corr_only_feature_types, $ft;
            }
            elsif ( $val == 2 ) {
                push @feature_types, $ft;
            }
        }
        elsif ( $param =~ /^et_(\S+)/ or $param =~ /^evidence_type_(\S+)/ ) {
            my $et  = $1;
            my $val = $apr->param($param);
            if ( $val == 0 ) {
                push @ignored_evidence_types, $et;
            }
            elsif ( $val == 1 ) {
                push @included_evidence_types, $et;
            }
            elsif ( $val == 2 ) {
                push @less_evidence_types, $et;
            }
            elsif ( $val == 3 ) {
                push @greater_evidence_types, $et;
            }
        }
        if ( $param =~ /^ets_(\S+)/ ) {
            my $et  = $1;
            my $val = $apr->param($param);
            $evidence_type_score{$et} = $val;
        }
    }

    # Set the UFDD or get the default UFDD in none is supplied
    $url_feature_default_display =
      $self->url_feature_default_display($url_feature_default_display);
    $apr->param( 'ft_DEFAULT',           $url_feature_default_display );
    $apr->param( 'feature_type_DEFAULT', undef );

    my %included_corr_only_features =
      map { $_ => 1 } @corr_only_feature_types;
    my %ignored_feature_types = map { $_ => 1 } @ignored_feature_types;

    #
    # Set the data source.
    #
    $self->data_source( $apr->param('data_source') ) or return;

    if (   $prev_ref_species_acc
        && $prev_ref_species_acc ne $ref_species_acc )
    {
        $ref_map_set_acc  = '';
        @ref_map_set_accs = ();
    }

    if (   $prev_ref_map_set_acc
        && $prev_ref_map_set_acc ne $ref_map_set_acc )
    {
        @ref_map_accs          = ();
        @ref_map_set_accs      = ();
        $ref_map_start         = undef;
        $ref_map_stop          = undef;
        $comparative_maps      = undef;
        @comparative_map_right = ();
        @comparative_map_left  = ();
    }

    if ( grep { /^-1$/ } @ref_map_accs ) {
        $ref_map_sets{$ref_map_set_acc} = ();
    }

    my ( $session, $s_object );
    if ($session_id) {

        #handle the sessions
        $session =
          new CGI::Session( "driver:File", $session_id,
            { Directory => '/tmp' } );
        $s_object = $session->param('object');
        if ( defined($s_object) ) {
            unless ($step) {
                $step = $#{$s_object} + 1;
            }
            my $prev_step = $step - 1;
            $next_step = $step + 1;
            my $step_hash;
            if (    $s_object->[$step]
                and $s_object->[$step]{'session_mod'}
                and $s_object->[$step]{'session_mod'} eq $session_mod )
            {
                $step_hash    = $s_object->[$step];
                $reusing_step = 1;
            }
            else {
                $step_hash = $s_object->[$prev_step];
            }
            if ( defined($step_hash) ) {
                %slots           = %{ clone( $step_hash->{'slots'} ) };
                $ref_species_acc = $step_hash->{'ref_species_acc'};
                $ref_map_set_acc = $step_hash->{'ref_map_set_acc'};

                # Apply Session Modifications
                my ( $change_left_min_corrs, $change_right_min_corrs ) =
                  modify_slots( \%slots, $session_mod )
                  if ( !$reusing_step );

                # if a slot was deleted, change the left/right_min_corrs
                if ($change_left_min_corrs) {
                    my @slot_nos = sort { $a <=> $b } keys %slots;
                    $left_min_corrs = $slots{ $slot_nos[0] }->{'min_corrs'};
                }
                if ($change_right_min_corrs) {
                    my @slot_nos = sort { $a <=> $b } keys %slots;
                    $right_min_corrs = $slots{ $slot_nos[-1] }->{'min_corrs'};
                }
                @ref_map_accs = keys( %{ $slots{0}->{'maps'} } );
                $apr->param( 'ref_map_accs', join( ":", @ref_map_accs ) );

            }
            else {

                # invalid step
                return $self->error( 'Invalid session step: ' . $step );
            }
        }
        else {

            # invalid session_id
            return $self->error( 'Invalid session_id: ' . $session_id );
        }
    }
    else {
        $session =
          new CGI::Session( "driver:File", undef, { Directory => '/tmp' } );
        $session_id = $session->id();
        $step       = 0;
        $next_step  = $step + 1;
        $session->expire('+2w');    #expires in two weeks
        %slots = (
            0 => {
                map_set_acc => $ref_map_set_acc,
                map_sets    => \%ref_map_sets,
                maps        => \%ref_maps,
            }
        );

        #
        # Add in previous maps.
        #
        # Remove start and stop if they are the same
        while ( $comparative_maps =~ s/(.+\[)(\d+)\*\2(\D.*)/$1*$3/ ) { }

        for my $cmap ( split( /:/, $comparative_maps ) ) {
            my ( $slot_no, $field, $map_acc ) = split( /=/, $cmap ) or next;
            my ( $start, $stop, $magnification );
            foreach my $acc ( split /,/, $map_acc ) {
                ( $acc, $start, $stop, $magnification, $highlight ) =
                  parse_map_info( $acc, $highlight );
                if ( $field eq 'map_acc' or $field eq 'map_aid' ) {
                    $slots{$slot_no}{'maps'}{$acc} = {
                        start => $start,
                        stop  => $stop,
                        mag   => $magnification,
                    };
                }
                elsif ( $field eq 'map_set_acc' or $field eq 'map_set_aid' ) {
                    unless ( defined( $slots{$slot_no}{'map_sets'}{$acc} ) ) {
                        $slots{$slot_no}{'map_sets'}{$acc} = ();
                    }
                }
            }
        }

        # Deal with modified comp map
        # map info specified in this param trumps $comparative_maps info
        if ( $apr->param('modified_comp_map') ) {
            my $comp_map = $apr->param('modified_comp_map');

            # remove duplicate start and end
            while ( $comp_map =~ s/(.+\[)(\d+)\*\2(\D.*)/$1*$3/ ) { }
            $apr->param( 'modified_comp_map', $comp_map );

            my ( $slot_no, $field, $acc ) = split( /=/, $comp_map ) or next;
            my ( $start, $stop, $magnification ) = ( undef, undef, 1 );
            ( $acc, $start, $stop, $magnification, $highlight ) =
              parse_map_info( $acc, $highlight );
            if ( $field eq 'map_acc' or $field eq 'map_aid' ) {
                $slots{$slot_no}->{'maps'}{$acc} = {
                    start => $start,
                    stop  => $stop,
                    mag   => $magnification,
                };
            }
            elsif ( $field eq 'map_set_acc' or $field eq 'map_set_aid' ) {
                unless ( defined( $slots{$slot_no}->{'map_sets'}{$acc} ) ) {
                    $slots{$slot_no}->{'map_sets'}{$acc} = ();
                }
            }

            # Add the modified version into the comparative_maps param
            my @cmaps = split( /:/, $comparative_maps );
            my $found = 0;
            for ( my $i = 0 ; $i <= $#cmaps ; $i++ ) {
                my ( $c_slot_no, $c_field, $c_acc ) =
                  split( /=/, $cmaps[$i] )
                  or next;
                $acc =~ s/^(.*)\[.*/$1/;
                if (    ( $c_slot_no eq $slot_no )
                    and ( $c_field eq $field )
                    and ( $c_acc   eq $acc ) )
                {
                    $cmaps[$i] = $comp_map;
                    $found = 1;
                    last;
                }
            }
            push @cmaps, $comp_map if ( !$found );
        }
    }

    # If ref_map_start/stop are defined and there is only one ref map
    # use those values and then wipe them from the params. 
    if (    scalar keys( %{ $slots{0}->{'maps'} } ) == 1
        and scalar(@ref_map_accs) == 1 )
    {
        ( $ref_map_start, $ref_map_stop ) = ( $ref_map_stop, $ref_map_start )
          if (  defined($ref_map_start)
            and defined($ref_map_stop)
            and $ref_map_start > $ref_map_stop );
        if ( defined($ref_map_start) and $ref_map_start ne '' ) {
            $slots{0}->{'maps'}{ $ref_map_accs[0] }{'start'} = $ref_map_start;
        }
        if ( defined($ref_map_stop) and $ref_map_stop ne '' ) {
            $slots{0}->{'maps'}{ $ref_map_accs[0] }{'stop'} = $ref_map_stop;
        }
    }
    $apr->delete('ref_map_start','ref_map_stop', );

    # Build %slots_min_corrs
    my @slot_nos  = sort { $a <=> $b } keys %slots;
    my $max_right = $slot_nos[-1];
    my $max_left  = $slot_nos[0];
    if ($general_min_corrs) {
        foreach my $slot_no (@slot_nos) {
            $slots_min_corrs{$slot_no} = $general_min_corrs;
        }
    }

    # set the left and the right slots' min corr
    $slots_min_corrs{$max_left}  = $left_min_corrs;
    $slots_min_corrs{$max_right} = $right_min_corrs;

    #
    # Add in our next chosen maps.
    #
    for my $side ( ( RIGHT, LEFT ) ) {
        my $slot_no = $side eq RIGHT ? $max_right + 1 : $max_left - 1;
        my $cmap =
          $side eq RIGHT
          ? \@comparative_map_right
          : \@comparative_map_left;
        my $cmap_set_acc =
          $side eq RIGHT ? $comp_map_set_right : $comp_map_set_left;
        if (@$cmap) {
            if ( grep { /^-1$/ } @$cmap ) {
                unless (
                    defined( $slots{$slot_no}->{'map_sets'}{$cmap_set_acc} ) )
                {
                    $slots{$slot_no}->{'map_sets'}{$cmap_set_acc} = ();
                }
            }
            else {
                foreach my $map_acc (@$cmap) {
                    my ( $start, $stop, $magnification );
                    ( $map_acc, $start, $stop, $magnification, $highlight ) =
                      parse_map_info( $map_acc, $highlight );

                    $slots{$slot_no}{'maps'}{$map_acc} = {
                        start => $start,
                        stop  => $stop,
                        mag   => $magnification,
                    };
                }
            }

            # Set this slots min corrs
            $slots_min_corrs{$slot_no} = $menu_min_corrs;

            # Change the left/right_min_corrs value for future links
            if ( $slot_no < 0 ) {
                $left_min_corrs = $menu_min_corrs;
            }
            else {
                $right_min_corrs = $menu_min_corrs;
            }
        }
    }

    #
    # Instantiate the drawer if there's at least one map to draw.
    #
    my ( $drawer, $extra_code, $extra_form );
    if (@ref_map_accs) {
        $drawer = Bio::GMOD::CMap::Drawer->new(
            apr                         => $apr,
            data_source                 => $self->data_source,
            slots                       => \%slots,
            flip                        => $flip,
            highlight                   => $highlight,
            font_size                   => $font_size,
            image_size                  => $image_size,
            image_type                  => $image_type,
            label_features              => $label_features,
            collapse_features           => $collapse_features,
            left_min_corrs              => $left_min_corrs,
            right_min_corrs             => $right_min_corrs,
            general_min_corrs           => $general_min_corrs,
            menu_min_corrs              => $menu_min_corrs,
            slots_min_corrs             => \%slots_min_corrs,
            included_feature_types      => \@feature_types,
            corr_only_feature_types     => \@corr_only_feature_types,
            ignored_feature_types       => \@ignored_feature_types,
            url_feature_default_display => $url_feature_default_display,
            ignored_evidence_types      => \@ignored_evidence_types,
            included_evidence_types     => \@included_evidence_types,
            less_evidence_types         => \@less_evidence_types,
            greater_evidence_types      => \@greater_evidence_types,
            evidence_type_score         => \%evidence_type_score,
            config                      => $self->config,
            data_module                 => $self->data_module,
            aggregate                   => $self->aggregate,
            cluster_corr                => $self->cluster_corr,
            show_intraslot_corr         => $self->show_intraslot_corr,
            split_agg_ev                => $self->split_agg_ev,
            clean_view                  => $self->clean_view,
            magnify_all                 => $self->magnify_all,
            ignore_image_map_sanity     => $ignore_image_map_sanity,
            scale_maps                  => $self->scale_maps,
            stack_maps                  => $self->stack_maps,
            ref_map_order               => $self->ref_map_order,
            comp_menu_order             => $self->comp_menu_order,
            corrs_to_map                => $corrs_to_map,
            omit_area_boxes             => $omit_area_boxes,
            refMenu                     => $refMenu,
            compMenu                    => $compMenu,
            optionMenu                  => $optionMenu,
            addOpMenu                   => $addOpMenu,
            session_id                  => $session_id,
            next_step                   => $next_step,
          )
          or return $self->error( Bio::GMOD::CMap::Drawer->error );

        %slots = %{ $drawer->{'slots'} };
        $apr->param( 'left_min_corrs',  $drawer->left_min_corrs );
        $apr->param( 'right_min_corrs', $drawer->right_min_corrs );
        $extra_code = $drawer->{'data'}->{'extra_code'};
        $extra_form = $drawer->{'data'}->{'extra_form'};

        @feature_types               = @{ $drawer->included_feature_types };
        @corr_only_feature_types     = @{ $drawer->corr_only_feature_types };
        @ignored_feature_types       = @{ $drawer->ignored_feature_types };
        @ignored_evidence_types      = @{ $drawer->ignored_evidence_types };
        @included_evidence_types     = @{ $drawer->included_evidence_types };
        @greater_evidence_types      = @{ $drawer->greater_evidence_types };
        @less_evidence_types         = @{ $drawer->less_evidence_types };
        %included_corr_only_features =
          map { $_ => 1 } @corr_only_feature_types;
        %ignored_feature_types = map { $_ => 1 } @ignored_feature_types;
    }

    #
    # Get the data for the form.
    #
    my $data      = $self->data_module;
    my $form_data = $data->cmap_form_data(
        slots                   => \%slots,
        menu_min_corrs          => $menu_min_corrs,
        included_feature_types  => \@feature_types,
        ignored_feature_types   => \@ignored_feature_types,
        ignored_evidence_types  => \@ignored_evidence_types,
        included_evidence_types => \@included_evidence_types,
        less_evidence_types     => \@less_evidence_types,
        greater_evidence_types  => \@greater_evidence_types,
        evidence_type_score     => \%evidence_type_score,
        ref_species_acc         => $ref_species_acc,
        ref_map_set_acc         => $ref_map_set_acc,
        ref_slot_data           => $drawer->{'data'}->{'slots'}{0},
      )
      or return $self->error( $data->error );

    for my $key (qw[ ref_species_acc ref_map_set_acc ]) {
        $apr->param( $key, $form_data->{$key} );
    }

    my $feature_default_display = $data->feature_default_display;

    $form_data->{'feature_types'} =
      [ sort { lc $a->{'feature_type'} cmp lc $b->{'feature_type'} }
          @{ $self->data_module->get_all_feature_types } ];

    my %evidence_type_menu_select = (
        ( map { $_ => 0 } @ignored_evidence_types ),
        ( map { $_ => 1 } @included_evidence_types ),
        ( map { $_ => 2 } @less_evidence_types ),
        ( map { $_ => 3 } @greater_evidence_types )
    );

    unless ($reusing_step) {
        my $step_object = {
            slots           => \%slots,
            ref_species_acc => $ref_species_acc,
            ref_map_set_acc => $ref_map_set_acc,
            session_mod     => $session_mod,
        };
        if ( $s_object and $step ) {
            $s_object->[$step] = $step_object;
            if ( $#{$s_object} > $step ) {
                splice( @$s_object, $step + 1 );
            }
        }
        else {
            $s_object = [$step_object];
        }
        $session->param( 'object', $s_object );
    }

    $apr->param( 'session_id', $session_id );
    $apr->param( 'step',       $next_step );

    my $html;
    my $t = $self->template or return;
    $t->process(
        TEMPLATE,
        {
            apr               => $apr,
            form_data         => $form_data,
            drawer            => $drawer,
            page              => $self->page,
            intro             => $INTRO,
            data_source       => $self->data_source,
            data_sources      => $self->data_sources,
            title             => $self->config_data('cmap_title') || 'CMap',
            stylesheet        => $self->stylesheet,
            selected_maps     => { map { $_, 1 } @ref_map_accs },
            included_features => { map { $_, 1 } @feature_types },
            corr_only_feature_types   => \%included_corr_only_features,
            ignored_feature_types     => \%ignored_feature_types,
            evidence_type_menu_select => \%evidence_type_menu_select,
            evidence_type_score       => \%evidence_type_score,
            feature_types             => join( ',', @feature_types ),
            evidence_types            => join( ',', @included_evidence_types ),
            extra_code                => $extra_code,
            extra_form                => $extra_form,
            feature_default_display   => $feature_default_display,
            no_footer                 => $path_info eq 'map_details' ? 1 : 0,
            prev_ref_map_order        => $self->ref_map_order(),
            no_footer                 => $path_info eq 'map_details' ? 1 : 0,
        },
        \$html
      )
      or $html = $t->error;

    if ( $path_info eq 'map_details' and scalar keys %ref_maps == 1 ) {
        $PAGE_SIZE ||= $self->config_data('max_child_elements') || 0;
        $MAX_PAGES ||= $self->config_data('max_search_pages')   || 1;
        my ( $comparative_map_field, $comparative_map_field_acc ) =
          split( /=/, $apr->param('comparative_map') );
        my ($map_acc) = keys %ref_maps;
        my $map_id = $self->sql->acc_id_to_internal_id(
            cmap_object => $self,
            object_type => 'map',
            acc_id      => $map_acc,
        );

        my $detail_data = $data->map_detail_data(
            ref_map                   => $drawer->{'data'}{'slots'}{0}{$map_id},
            map_id                    => $map_id,
            highlight                 => $highlight,
            included_feature_types    => \@feature_types,
            corr_only_feature_types   => \@corr_only_feature_types,
            ignored_feature_types     => \@ignored_feature_types,
            included_evidence_types   => \@included_evidence_types,
            ignored_evidence_types    => \@ignored_evidence_types,
            order_by                  => $apr->param('order_by') || '',
            comparative_map_field     => $comparative_map_field || '',
            comparative_map_field_acc => $comparative_map_field_acc || '',
            page_size                 => $PAGE_SIZE,
            max_pages                 => $MAX_PAGES,
            page_no                   => $page_no,
            page_data                 => $action eq 'download' ? 0 : 1,
          )
          or return $self->error( "Data: " . $data->error );

        $self->object_plugin( 'map_details', $detail_data->{'reference_map'} );

        if ( $action eq 'download' ) {
            my $text = join( FIELD_SEP, @{ +COLUMN_NAMES } ) . RECORD_SEP;
            my $map_fields = join( FIELD_SEP,
                map { $detail_data->{'reference_map'}{$_} } @{ +MAP_FIELDS } );

            for my $feature ( @{ $detail_data->{'features'} } ) {
                my $row = join( FIELD_SEP,
                    $map_fields, map { $feature->{$_} } @{ +FEATURE_FIELDS } );

                if ( @{ $feature->{'positions'} } ) {
                    for my $position ( @{ $feature->{'positions'} } ) {
                        $position->{'evidence'} =
                          join( ',', @{ $position->{'evidence'} } );
                        $text .= join(
                            FIELD_SEP,
                            $row,
                            map {
                                defined $position->{$_}
                                  ? $position->{$_}
                                  : ''
                              } @{ +POSITION_FIELDS }
                          )
                          . RECORD_SEP;
                    }
                }
                else {
                    $text .= $row . RECORD_SEP;
                }
            }

            print $apr->header( -type => 'text/plain' ), $text;
        }
        else {
            my @map_ids = map { $_ || () }
              keys %{ $drawer->{'data'}{'slots'}{'0'} };
            my $ref_map_id = shift @map_ids;
            my $ref_map    = $drawer->{'data'}{'slots'}{'0'}{$ref_map_id};
            $apr->param( 'ref_map_start', $ref_map->{'start'} );
            $apr->param( 'ref_map_stop',  $ref_map->{'stop'} );

            my $detail_html;
            my $t = $self->template;
            $t->process(
                DETAIL_TEMPLATE,
                {
                    apr                   => $apr,
                    pager                 => $detail_data->{'pager'},
                    feature_types         => $detail_data->{'feature_types'},
                    feature_count_by_type =>
                      $detail_data->{'feature_count_by_type'},
                    evidence_types        => $detail_data->{'evidence_types'},
                    reference_map         => $detail_data->{'reference_map'},
                    comparative_maps      => $detail_data->{'comparative_maps'},
                    comparative_map_field => '',
                    comparative_map_acc   => '',
                    drawer                => $drawer,
                    page                  => $self->page,
                    title                 => 'Reference Map Details',
                    stylesheet            => $self->stylesheet,
                    features              => $detail_data->{'features'},
                },
                \$detail_html
              )
              or $detail_html = $t->error;

            print $apr->header(
                -type   => 'text/html',
                -cookie => $self->cookie
              ),
              $html, $detail_html;
        }
    }
    else {

        # Regular map viewing
        print $apr->header(
            -type   => 'text/html',
            -cookie => $self->cookie
        ), $html;
    }

    return 1;
}

# ----------------------------------------------------
sub parse_map_info {

    # parses the map info
    my $acc       = shift;
    my $highlight = shift;

    my ( $start, $stop, $magnification ) = ( undef, undef, 1 );

    # following matches map_id[1*200] and map_id[1*200x2]
    if ( $acc =~ m/^(.+)\[(.*)\*(.*?)(?:x([\d\.]*)|)\]$/ ) {
        $acc = $1;
        ( $start, $stop ) = ( $2, $3 );
        $magnification = $4 if $4;
        ( $start, $stop ) = ( undef, undef ) if ( $start == $stop );
        $start = undef unless ( $start =~ /\S/ );
        $stop  = undef unless ( $stop  =~ /\S/ );
        my $start_stop_feature = 0;
        my @highlight_array;
        push @highlight_array, $highlight if $highlight;

        if ( $start !~ /^$RE{'num'}{'real'}$/ ) {
            push @highlight_array, $start if $start;
            $start_stop_feature = 1;
        }

        if ( $stop !~ /^$RE{'num'}{'real'}$/ ) {
            push @highlight_array, $stop if $stop;
            $start_stop_feature = 1;
        }
        $highlight = join( ',', @highlight_array );

        if (    !$start_stop_feature
            and defined($start)
            and defined($stop)
            and $stop < $start )
        {
            ( $start, $stop ) = ( $stop, $start );
        }
    }

    return ( $acc, $start, $stop, $magnification, $highlight );
}

# ----------------------------------------------------
sub modify_slots {

    # Modify the slots object using a modification string
    my $slots                  = shift;
    my $mod_str                = shift;
    my $change_left_min_corrs  = 0;
    my $change_right_min_corrs = 0;

    my @mod_cmds = split( /:/, $mod_str );

    foreach my $mod_cmd (@mod_cmds) {
        my @mod_array = split( /=/, $mod_cmd );
        next unless (@mod_array);

        if ( $mod_array[0] eq 'start' ) {
            next unless ( scalar(@mod_array) == 4 );
            my $slot_no = $mod_array[1];
            my $map_acc = $mod_array[2];
            my $start   = $mod_array[3];
            if (    $slots->{$slot_no}
                and $slots->{$slot_no}{'maps'}{$map_acc} )
            {
                $slots->{$slot_no}{'maps'}{$map_acc}{'start'} = $start;
            }
        }
        elsif ( $mod_array[0] eq 'stop' ) {
            next unless ( scalar(@mod_array) == 4 );
            my $slot_no = $mod_array[1];
            my $map_acc = $mod_array[2];
            my $stop    = $mod_array[3];
            if (    $slots->{$slot_no}
                and $slots->{$slot_no}{'maps'}{$map_acc} )
            {
                $slots->{$slot_no}{'maps'}{$map_acc}{'stop'} = $stop;
            }
        }
        elsif ( $mod_array[0] eq 'mag' ) {
            next unless ( scalar(@mod_array) == 4 );
            my $slot_no = $mod_array[1];
            my $map_acc = $mod_array[2];
            my $mag     = $mod_array[3];
            if (    $slots->{$slot_no}
                and $slots->{$slot_no}{'maps'}{$map_acc} )
            {
                $slots->{$slot_no}{'maps'}{$map_acc}{'mag'} = $mag;
            }
        }
        elsif ( $mod_array[0] eq 'reset' ) {
            next unless ( scalar(@mod_array) == 3 );
            my $slot_no = $mod_array[1];
            my $map_acc = $mod_array[2];
            if (    $slots->{$slot_no}
                and $slots->{$slot_no}{'maps'}{$map_acc} )
            {
                $slots->{$slot_no}{'maps'}{$map_acc}{'start'} = undef;
                $slots->{$slot_no}{'maps'}{$map_acc}{'stop'}  = undef;
                $slots->{$slot_no}{'maps'}{$map_acc}{'mag'}   = 1;
            }
        }
        elsif ( $mod_array[0] eq 'del' ) {
            if ( scalar(@mod_array) == 3 ) {
                my $slot_no = $mod_array[1];
                my $map_acc = $mod_array[2];
                if (    $slots->{$slot_no}
                    and $slots->{$slot_no}{'maps'}{$map_acc} )
                {
                    delete $slots->{$slot_no}{'maps'}{$map_acc};

                    # If deleting last map, remove the whole thing
                    unless ( $slots->{$slot_no}{'maps'} ) {
                        $slots->{$slot_no}{'map_sets'} = {};
                    }
                }
            }
            elsif ( scalar(@mod_array) == 2 ) {
                my $slot_no = $mod_array[1];
                if ( $slots->{$slot_no} ) {
                    $slots->{$slot_no} = {};
                }
            }
        }
        elsif ( $mod_array[0] eq 'limit' ) {
            next unless ( scalar(@mod_array) == 3 );
            my $slot_no = $mod_array[1];
            my $map_acc = $mod_array[2];
            my $mag     = $mod_array[3];
            if (    $slots->{$slot_no}
                and $slots->{$slot_no}{'maps'}{$map_acc} )
            {
                foreach
                  my $other_map_acc ( keys( %{ $slots->{$slot_no}{'maps'} } ) )
                {
                    next if ( $other_map_acc eq $map_acc );
                    delete $slots->{$slot_no}{'maps'}{$other_map_acc};
                }
            }
        }
    }

    # If ever a slot has no maps, remove the slot.
    my $delete_pos = 0;
    my $delete_neg = 0;
    foreach my $slot_no ( keys %{$slots} ) {
    }
    foreach my $slot_no ( sort orderOutFromZero keys %{$slots} ) {
    }
    foreach my $slot_no ( sort orderOutFromZero keys %{$slots} ) {
        unless (
            ( $slots->{$slot_no}{'maps'} and %{ $slots->{$slot_no}{'maps'} } )
            or ( $slots->{$slot_no}{'mapsets'}
                and %{ $slots->{$slot_no}{'map_sets'} } )
          )
        {
            if ( $slot_no >= 0 ) {
                $delete_pos             = 1;
                $change_right_min_corrs = 1;
            }
            if ( $slot_no <= 0 ) {
                $delete_neg            = 1;
                $change_left_min_corrs = 1;
            }
        }
        if ( $slot_no >= 0 and $delete_pos ) {
            delete $slots->{$slot_no};
        }
        elsif ( $slot_no < 0 and $delete_neg ) {
            delete $slots->{$slot_no};
        }
    }
    return ( $change_left_min_corrs, $change_right_min_corrs );
}

sub orderOutFromZero {
    ###Return the sort in this order (0,1,-1,-2,2,-3,3,)
    return ( abs($a) cmp abs($b) );
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

