package Bio::GMOD::CMap;

# vim: set ft=perl:

# $Id: CMap.pm,v 1.82 2005-04-25 22:22:30 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap.pm - base object for comparative maps

=head1 SYNOPSIS

  package Bio::GMOD::CMap::Foo;
  use Bio::GMOD::CMap;
  use base 'Bio::GMOD::CMap';

  sub foo { print "foo\n" }

  1;

=head1 DESCRIPTION

This is the base class for all the comparative maps modules.  It is
itself based on Andy Wardley's Class::Base module.

=head1 METHODS

=cut

use strict;
use vars '$VERSION';
$VERSION = '0.15';

use Data::Dumper;
use Class::Base;
use Config::General;
use Bio::GMOD::CMap::Data;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Config;
use URI::Escape;
use DBI;
use File::Path;
use Storable qw(freeze thaw);
use Template;

use base 'Class::Base';

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->config( $config->{'config'} );
    $self->data_source( $config->{'data_source'} ) or return;
    return $self;
}

# ----------------------------------------------------
sub cache_dir {

=pod

=head2 cache_dir

Returns the cache directory.

=cut

    my $self          = shift;
    my $new_cache_dir = shift;
    my $config        = $self->config or return;

    if ( defined($new_cache_dir) ) {
        $self->{'cache_dir'} = $new_cache_dir;
    }
    unless ( defined $self->{'cache_dir'} ) {
        unless ( $self->{'config'} ) {
            die "no configuration information\n";
        }

        my $cache_dir = $config->get_config('cache_dir')
          or return $self->error(
            'No cache directory defined in "' . GLOBAL_CONFIG_FILE . '"' );

        unless ( -d $cache_dir ) {
            eval { mkpath( $cache_dir, 0, 0700 ) };
            if ( my $err = $@ ) {
                return $self->error(
                    "Cache directory '$cache_dir' can't be created: $err");
            }
        }

        $self->{'cache_dir'} = $cache_dir;
    }

    return $self->{'cache_dir'};
}

# ----------------------------------------------------

=pod

=head2 config

Returns configuration object.

=cut

sub config {

    my $self      = shift;
    my $newConfig = shift;
    if ($newConfig) {
        $self->{'config'} = $newConfig;
    }
    unless ( defined $self->{'config'} ) {
        $self->{'config'} = Bio::GMOD::CMap::Config->new
          or return Bio::GMOD::CMap::Config->error;
    }

    return $self->{'config'};
}

# ----------------------------------------------------
sub config_data {

=pod

=head2 config_data

Access configuration.

=cut

    my $self = shift;
    my $config = $self->config or return;
    $config->get_config(@_);
}

# ----------------------------------------------------
sub object_plugin {

=pod

=head2 object_plugin

Allow for object plugin stuff.

=cut

    my ( $self, $obj_type, $object ) = @_;
    my $plugin_info = $self->config_data('object_plugin') or return;
    my $xref_sub    = $plugin_info->{ $obj_type }         or return;

    if ( $xref_sub =~ /^\s*sub\s*{/ ) {
        $xref_sub = eval $xref_sub;
    }
    elsif ( $xref_sub =~ /\w+::\w+/ ) {
        $xref_sub = \&{ $xref_sub };
    }

    return unless ref $xref_sub eq 'CODE';

    no strict 'refs';
    $xref_sub->( $object );
}

# ----------------------------------------------------
sub map_type_data {

=pod

=head2 map_type_data

Return data from config about map type 

=cut

    my $self         = shift;
    my $map_type_aid = shift;
    my $attribute    = shift;
    my $config       = $self->config or return;

    if ($attribute) {
        return $config->get_config('map_type')->{$map_type_aid}{$attribute};
    }
    elsif ($map_type_aid) {
        return $config->get_config('map_type')->{$map_type_aid};
    }
    else {
        return $config->get_config('map_type');
    }
}

# ----------------------------------------------------
sub feature_type_data {

=pod

=head2 feature_type_data

Return data from config about feature type 

=cut

    my $self             = shift;
    my $feature_type_aid = shift;
    my $attribute        = shift;
    my $config           = $self->config or return;

    if ($attribute) {
        return $config->get_config('feature_type')->{$feature_type_aid}
          ->{$attribute};
    }
    elsif ($feature_type_aid) {
        return $config->get_config('feature_type')->{$feature_type_aid};
    }
    else {
        return $config->get_config('feature_type');
    }
}

# ----------------------------------------------------
sub evidence_type_data {

=pod

=head2 evidence_type_data

Return data from config about evidence type 

=cut

    my $self              = shift;
    my $evidence_type_aid = shift;
    my $attribute         = shift;
    my $config            = $self->config or return;

    if ($attribute) {
        return $config->get_config('evidence_type')->{$evidence_type_aid}
          ->{$attribute};
    }
    elsif ($evidence_type_aid) {
        return $config->get_config('evidence_type')->{$evidence_type_aid};
    }
    else {
        $config->get_config('evidence_type');
    }
}

# ----------------------------------------------------
sub data_source {

=pod

=head2 data_source

Basically a front for set_config()

=cut

    my $self   = shift;
    my $arg    = shift || '';
    my $config = $self->config or return;

    #
    # If passed a new data source, force a reconnect.
    # This may slow things down.
    #
    if ($arg) {
        $config->set_config($arg)
          or return $self->error(
            "Couldn't set data source to '$arg': " . $config->error );
        $self->{'data_source'} = $config->get_config('database')->{'name'};
        if ( defined $self->{'db'} ) {
            my $db = $self->db;
            $db->disconnect;
            $self->{'db'} = undef;
        }

    }

    unless ( $self->{'data_source'} ) {
        $self->{'data_source'} = $config->get_config('database')->{'name'};
    }

    return $self->{'data_source'} || '';
}

# ----------------------------------------------------
sub data_sources {

=pod

=head2 data_sources

Returns all the data souces defined in the configuration files.

=cut

    my $self   = shift;
    my $config = $self->config or return;

    unless ( defined $self->{'data_sources'} ) {
        my @data_sources_result;

        $self->data_source() unless ( $self->{'data_source'} );

        my $ok = 0;

        if ( my $current = $self->{'data_source'} ) {
            foreach my $config_name ( @{ $config->get_config_names } ) {
                my $source = $config->get_config( 'database', $config_name );
                if ( $current && $source->{'name'} eq $current ) {
                    $source->{'is_current'} = 1;
                    $ok = 1;
                }
                else {
                    $source->{'is_current'} = 0;
                }

                $data_sources_result[ ++$#data_sources_result ] = $source;
            }
        }

        die "No database defined as default\n" unless ($ok);

        $self->{'data_sources'} =
          [ sort { $a->{'name'} cmp $b->{'name'} } @data_sources_result ];

    }

    if ( @{ $self->{'data_sources'} } ) {
        return $self->{'data_sources'};
    }
    else {
        return $self->error("Can't determine data sources (undefined?)");
    }
}

# ----------------------------------------------------
sub db {

=pod

=head2 db

Returns a database handle.  This is the only way into the database.

=cut

    my $self    = shift;
    my $db_name = shift || $self->data_source();
    my $config  = $self->config or return;
    return unless $db_name;

    unless ( defined $self->{'db'} ) {
        my $config = $config->get_config('database')
          or return $self->error('No database configuration options defined');

        unless ( ref $config eq 'HASH' ) {
            return $self->error( 'DB config not a hash.  '
                  . 'You may have more than one "database" specified in the config file'
            );
        }

        return $self->error("Couldn't determine database info")
          unless defined $config;

        my $datasource = $config->{'datasource'}
          or $self->error('No database source defined');
        my $user = $config->{'user'}
          or $self->error('No database user defined');
        my $password = $config->{'password'} || '';
        my $options = {
            AutoCommit       => 1,
            FetchHashKeyName => 'NAME_lc',
            LongReadLen      => 3000,
            LongTruncOk      => 1,
            RaiseError       => 1,
        };

        eval {
            $self->{'db'} =
              DBI->connect( $datasource, $user, $password, $options );
        };

        if ( $@ || !defined $self->{'db'} ) {
            my $error = $@ || $DBI::errstr;
            return $self->error(
                "Can't connect to data source '$db_name': $error");
        }
    }

    return $self->{'db'};
}

# ----------------------------------------------------
sub aggregate {

=pod
                                                                                
=head2 aggregate

Returns the boolean aggregate variable.  This determines 
if the correspondences are aggregated or individually depicted.

The default is 1.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'aggregate'} = $val if defined $val;
    $self->{'aggregate'} = $self->config_data('aggregate_correspondences') || 1
      unless defined $self->{'aggregate'};
    return $self->{'aggregate'};
}

# ----------------------------------------------------
sub cluster_corr {

=pod
                                                                                
=head2 cluster_corr

Returns the number of clusters that the correspondences should be broken into.
It will return 0 if not clustering.

The default is 0.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'cluster_corr'} = $val if defined $val;
    $self->{'cluster_corr'} = $self->config_data('cluster_correspondences') || 0
      unless defined $self->{'cluster_corr'};
    $self->{'cluster_corr'} = 0 unless ($self->aggregate==3);
    return $self->{'cluster_corr'};
}

# ----------------------------------------------------
sub show_intraslot_corr {

=pod
                                                                                
=head2 show_intraslot_corr

Returns the boolean show_intraslot_corr variable.  This determines 
if the intraslot correspondences are displayed.

The default is 1.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'show_intraslot_corr'} = $val if defined $val;
    $self->{'show_intraslot_corr'} =
      $self->config_data('show_intraslot_correspondences')
      unless defined $self->{'show_intraslot_corr'};
    $self->{'show_intraslot_corr'} = 0
      unless defined $self->{'show_intraslot_corr'};
    return $self->{'show_intraslot_corr'};
}

# ----------------------------------------------------
sub split_agg_ev {

=pod
                                                                                
=head2 split_agg_ev

Returns the boolean split_agg_ev variable.  This determines 
if the correspondences of different evidence types will be 
aggregated together or split.

The default is 1.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'split_agg_ev'} = $val if defined $val;
    $self->{'split_agg_ev'} =
      $self->config_data('split_agg_evespondences')
      unless defined $self->{'split_agg_ev'};
    $self->{'split_agg_ev'} = 0
      unless defined $self->{'split_agg_ev'};
    return $self->{'split_agg_ev'};
}

# ----------------------------------------------------
sub clean_view {

=pod
                                                                                
=head2 clean_view

Returns the boolean clean_view variable.  This determines 
if there will be control buttons on the map.

The default is 1.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'clean_view'} = $val if defined $val;
    $self->{'clean_view'} = $self->config_data('clean_view')
      unless defined $self->{'clean_view'};
    $self->{'clean_view'} = 0
      unless defined $self->{'clean_view'};
    return $self->{'clean_view'};
}

# ----------------------------------------------------
sub magnify_all {

=pod
                                                                                
=head2 magnify_all

Returns the boolean magnify_all variable.  This determines 
the value that the whole image is magnified by.

The default is 1.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'magnify_all'} = $val if defined($val);

    # Don't allow Zero as a value
    $self->{'magnify_all'} = 1 unless $self->{'magnify_all'};
    return $self->{'magnify_all'};
}

# ----------------------------------------------------
sub scale_maps {

=pod
                                                                                
=head2 scale_maps

Returns the boolean scale_maps variable.  This determines 
if the maps are drawn to scale 

The default is 1.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'scale_maps'} = $val if defined $val;
    $self->{'scale_maps'} = $self->config_data('scale_maps')
      unless defined $self->{'scale_maps'};
    $self->{'scale_maps'} = 1
      unless defined $self->{'scale_maps'};
    return $self->{'scale_maps'};
}

# ----------------------------------------------------
sub stack_maps {

=pod
                                                                                
=head2 stack_maps

Returns the boolean stack_maps variable.  This determines 
if the reference maps are staced vertically.

The default is 0.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'stack_maps'} = $val if defined $val;
    $self->{'stack_maps'} = $self->config_data('stack_maps')
      unless defined $self->{'stack_maps'};
    $self->{'stack_maps'} = 0
      unless defined $self->{'stack_maps'};
    return $self->{'stack_maps'};
}

# ----------------------------------------------------
sub ref_map_order {

=pod
                                                                                
=head2 ref_map_order

Returns the string that describes the order of the ref maps. 

The default is ''.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'ref_map_order'} = $val if defined $val;
    $self->{'ref_map_order'} = '' unless defined $self->{'ref_map_order'};
    return $self->{'ref_map_order'};
}

# ----------------------------------------------------
sub comp_menu_order {

=pod
                                                                                
=head2 comp_menu_order

Returns the string that determins how the comparison map menu is ordered. 

The default is ''.

=cut

    my $self = shift;
    my $val  = shift;
    $self->{'comp_menu_order'} = $val if defined $val;
    $self->{'comp_menu_order'} = $self->config_data('comp_menu_order') || '' 
        unless defined $self->{'comp_menu_order'};
    return $self->{'comp_menu_order'};
}

# ----------------------------------------------------
sub data_module {

=pod

=head2 data

Returns a handle to the data module.

=cut

    my $self = shift;

    $self->{'data_module'} = shift if @_;

    unless ( $self->{'data_module'} ) {
        $self->{'data_module'} = Bio::GMOD::CMap::Data->new(
            data_source         => $self->data_source,
            config              => $self->config,
            aggregate           => $self->aggregate,
            cluster_corr        => $self->cluster_corr,
            show_intraslot_corr => $self->show_intraslot_corr,
            split_agg_ev        => $self->split_agg_ev,
            ref_map_order       => $self->ref_map_order,
            comp_menu_order     => $self->comp_menu_order,
          )
          or $self->error( Bio::GMOD::CMap::Data->error );
    }

    return $self->{'data_module'};
}

# ----------------------------------------------------
sub get_multiple_xrefs {

=pod

=head2 get_multiple_xrefs

Given a table name and some objects, get the cross-references.

=cut

    my ( $self, %args ) = @_;
    my $table_name = $args{'table_name'} or return;
    my $objects    = $args{'objects'};
    my $db         = $self->db or return;

    return unless @{ $objects || [] };

    my $xrefs = $db->selectall_arrayref(
        q[
            select   object_id, display_order, xref_name, xref_url
            from     cmap_xref
            where    table_name=?
            order by object_id, display_order, xref_name
        ],
        { Columns => {} },
        ($table_name)
    );

    my ( %xref_specific, @xref_generic );
    for my $xref (@$xrefs) {
        if ( $xref->{'object_id'} ) {
            push @{ $xref_specific{ $xref->{'object_id'} } }, $xref;
        }
        else {
            push @xref_generic, $xref;
        }
    }

    my $t = $self->template;
    for my $o (@$objects) {
        for my $attr ( @{ $o->{'attributes'} || [] } ) {
            my $attr_val  = $attr->{'attribute_value'}   or next;
            my $attr_name = lc $attr->{'attribute_name'} or next;
            $attr_name =~ tr/ /_/s;
            push @{ $o->{'attribute'}{$attr_name} }, $attr->{'attribute_value'};
        }

        my @xrefs = @{ $xref_specific{ $o->{'object_id'} } || [] };
        push @xrefs, @xref_generic;

        my @processed;
        for my $xref (@xrefs) {
            my $url;
            $t->process( \$xref->{'xref_url'}, { object => $o }, \$url );

            push @processed,
              {
                xref_name => $xref->{'xref_name'},
                xref_url  => $_,
              } for map { $_ || () } split /\s+/, $url;
        }

        $o->{'xrefs'} = \@processed;
    }
}

# ----------------------------------------------------
sub create_viewer_link {

=pod

=head2 create_viewer_link

Given information about the link, creates a url to cmap_viewer.

=cut

    my ( $self, %args ) = @_;
    my $prev_ref_species_aid        = $args{'prev_ref_species_aid'};
    my $prev_ref_map_set_aid        = $args{'prev_ref_map_set_aid'};
    my $ref_species_aid             = $args{'ref_species_aid'};
    my $ref_map_set_aid             = $args{'ref_map_set_aid'};
    my $ref_map_start               = $args{'ref_map_start'};
    my $ref_map_stop                = $args{'ref_map_stop'};
    my $comparative_maps            = $args{'comparative_maps'};
    my $highlight                   = $args{'highlight'};
    my $font_size                   = $args{'font_size'};
    my $image_size                  = $args{'image_size'};
    my $image_type                  = $args{'image_type'};
    my $label_features              = $args{'label_features'};
    my $collapse_features           = $args{'collapse_features'};
    my $aggregate                   = $args{'aggregate'};
    my $cluster_corr                = $args{'cluster_corr'};
    my $scale_maps                  = $args{'scale_maps'};
    my $stack_maps                  = $args{'stack_maps'};
    my $ref_map_order               = $args{'ref_map_order'};
    my $show_intraslot_corr         = $args{'show_intraslot_corr'};
    my $split_agg_ev                = $args{'split_agg_ev'};
    my $clean_view                  = $args{'clean_view'};
    my $magnify_all                 = $args{'magnify_all'};
    my $flip                        = $args{'flip'};
    my $min_correspondences         = $args{'min_correspondences'};
    my $ref_map_aids                = $args{'ref_map_aids'};
    my $feature_type_aids           = $args{'feature_type_aids'};
    my $corr_only_feature_type_aids = $args{'corr_only_feature_type_aids'};
    my $ignored_feature_type_aids   = $args{'ignored_feature_type_aids'};
    my $url_feature_default_display = $args{'url_feature_default_display'};
    my $included_evidence_type_aids = $args{'included_evidence_type_aids'};
    my $ignored_evidence_type_aids  = $args{'ignored_evidence_type_aids'};
    my $less_evidence_type_aids     = $args{'less_evidence_type_aids'};
    my $greater_evidence_type_aids  = $args{'greater_evidence_type_aids'};
    my $evidence_type_score         = $args{'evidence_type_score'};
    my $data_source                 = $args{'data_source'} or return;
    my $url                         = $args{'url'};
    $url .= '?' unless $url =~ /\?$/;

    ###Required Fields
    unless ( ( defined($ref_map_set_aid) or defined($ref_map_aids) )
        and defined($data_source) )
    {
        return '';
    }
    $url .= "data_source=$data_source;";

    ### optional
    $url .= "ref_map_set_aid=$ref_map_set_aid;"
      if defined($ref_map_set_aid);
    $url .= "ref_species_aid=$ref_species_aid;"
      if defined($ref_species_aid);
    $url .= "prev_ref_species_aid=$prev_ref_species_aid;"
      if defined($prev_ref_species_aid);
    $url .= "prev_ref_map_set_aid=$prev_ref_map_set_aid;"
      if defined($prev_ref_map_set_aid);
    $url .= "ref_map_start=$ref_map_start;"
      if defined($ref_map_start);
    $url .= "ref_map_stop=$ref_map_stop;"
      if defined($ref_map_stop);
    $url .= "highlight=" . uri_escape($highlight) . ";"
      if defined($highlight);
    $url .= "font_size=$font_size;"
      if defined($font_size);
    $url .= "image_size=$image_size;"
      if defined($image_size);
    $url .= "image_type=$image_type;"
      if defined($image_type);
    $url .= "label_features=$label_features;"
      if defined($label_features);
    $url .= "collapse_features=$collapse_features;"
      if defined($collapse_features);
    $url .= "cluster_corr=$cluster_corr;"
      if defined($cluster_corr);
    $url .= "aggregate=$aggregate;"
      if defined($aggregate);
    $url .= "scale_maps=$scale_maps;"
      if defined($scale_maps);
    $url .= "stack_maps=$stack_maps;"
      if defined($stack_maps);
    $url .= "ref_map_order=$ref_map_order;"
      if defined($ref_map_order);
    $url .= "split_agg_ev=$split_agg_ev;"
      if defined($split_agg_ev);
    $url .= "clean_view=$clean_view;"
      if defined($clean_view);
    $url .= "magnify_all=$magnify_all;"
      if defined($magnify_all);
    $url .= "flip=$flip;"
      if defined($flip);
    $url .= "min_correspondences=$min_correspondences;"
      if defined($min_correspondences);

    #multi
    if ( $ref_map_aids and %$ref_map_aids ) {
        my @ref_strs;
        foreach my $ref_map_aid ( keys(%$ref_map_aids) ) {
            if (   defined( $ref_map_aids->{$ref_map_aid}{'start'} )
                or defined( $ref_map_aids->{$ref_map_aid}{'stop'} ) )
            {
                push @ref_strs,
                  $ref_map_aid . '['
                  . $ref_map_aids->{$ref_map_aid}{'start'} . '*'
                  . $ref_map_aids->{$ref_map_aid}{'stop'} . 'x'
                  . $ref_map_aids->{$ref_map_aid}{'magnify'} . ']';
            }
            else {
                push @ref_strs, $ref_map_aid;
            }
        }
        $url .= "ref_map_aids=" . join( ',', @ref_strs ) . ";";
    }

    if ( $comparative_maps and %$comparative_maps ) {
        my @strs;
        foreach my $slot_no ( keys(%$comparative_maps) ) {
            my $map = $comparative_maps->{$slot_no};
            for my $field (qw[ maps map_sets ]) {
                next unless ( defined( $map->{$field} ) );
                foreach my $aid ( keys %{ $map->{$field} } ) {
                    if ( $field eq 'maps' ) {
                        my $start =
                          defined( $map->{$field}{$aid}{'start'} )
                          ? $map->{$field}{$aid}{'start'}
                          : '';
                        my $stop =
                          defined( $map->{$field}{$aid}{'stop'} )
                          ? $map->{$field}{$aid}{'stop'}
                          : '';
                        my $mag =
                          defined( $map->{$field}{$aid}{'mag'} )
                          ? $map->{$field}{$aid}{'mag'}
                          : 1;
                        push @strs,
                          $slot_no
                          . '%3dmap_aid%3d'
                          . $aid . '['
                          . $start . '*'
                          . $stop . 'x'
                          . $mag . ']';

                    }
                    else {
                        push @strs, $slot_no . '%3dmap_set_aid%3d' . $aid;
                    }
                }
            }
        }

        $url .= "comparative_maps=" . join( ':', @strs ) . ";";
    }

    foreach my $aid (@$feature_type_aids) {
        $url .= "ft_" . $aid . "=2;";
    }
    foreach my $aid (@$corr_only_feature_type_aids) {
        $url .= "ft_" . $aid . "=1;";
    }
    foreach my $aid (@$ignored_feature_type_aids) {
        $url .= "ft_" . $aid . "=0;";
    }
    $url .= "ft_DEFAULT=$url_feature_default_display;"
      if defined($url_feature_default_display);
    foreach my $aid (@$included_evidence_type_aids) {
        $url .= "et_" . $aid . "=1;";
    }
    foreach my $aid (@$ignored_evidence_type_aids) {
        $url .= "et_" . $aid . "=0;";
    }
    foreach my $aid (@$less_evidence_type_aids) {
        $url .= "et_" . $aid . "=2;";
    }
    foreach my $aid (@$greater_evidence_type_aids) {
        $url .= "et_" . $aid . "=3;";
    }
    foreach my $aid (keys(%$evidence_type_score)) {
        $url .= "ets_" . $aid . "=".$evidence_type_score->{$aid}.";";
    }

    return $url;
}

# ----------------------------------------------------
sub get_link_name_space {

=pod

=head2 get_link_name_space

This is a consistant way of naming the link name space

=cut

    my $self = shift;
    return 'imported_links_' . $self->data_source;
}

# ----------------------------------------------------
sub cache_level_name {

=pod

=head2 cache_level_name

This is a consistant way of naming the cache levels. 

=cut

    my $self  = shift;
    my $level = shift;
    return $self->ERROR(
        "Cache Level: $level should not be higher than " . CACHE_LEVELS )
      unless ( $level <= CACHE_LEVELS );
    return $self->config_data('database')->{'name'} . "_L" . $level;
}

# ----------------------------------------------------
sub DESTROY {

=pod

=head2 DESTROY

Object clean-up when destroyed by Perl.

=cut

    my $self = shift;
    $self->db->disconnect if defined $self->{'db'};
    return 1;
}

# ----------------------------------------------------
sub template {

=pod

=head2 template

Returns a Template Toolkit object.

=cut

    my $self   = shift;
    my $config = $self->config or return;

    unless ( $self->{'template'} ) {
        my $cache_dir = $self->cache_dir or return;
        my $template_dir = $config->get_config('template_dir')
          or return $self->error(
            'No template directory defined in "' . GLOBAL_CONFIG_FILE . '"' );
        return $self->error("Template directory '$template_dir' doesn't exist")
          unless -d $template_dir;

        $self->{'template'} = Template->new(
            COMPILE_EXT  => '.ttc',
            COMPILE_DIR  => $cache_dir,
            INCLUDE_PATH => $template_dir,
            FILTERS      => {
                dump => sub { Dumper( shift() ) },
                nbsp => sub { my $s = shift; $s =~ s{\s+}{\&nbsp;}g; $s },
                commify => \&Bio::GMOD::CMap::Utils::commify,
            },
          )
          or $self->error(
            "Couldn't create Template object: " . Template->error() );
    }

    return $self->{'template'};
}

# ----------------------------------------------------
sub warn {

=pod

=head2 warn

Provides a simple way to print messages to STDERR.

=cut

    my $self = shift;
    print STDERR @_;
}

# ----------------------------------------------------
sub sql {

=pod

=head2 sql

Returns the correct SQL module driver for the RDBMS we're using.

=cut

    my $self      = shift;
    my $db_driver = lc shift;

    unless ( defined $self->{'sql_module'} ) {
        my $db = $self->db or return;
        $db_driver = lc $db->{'Driver'}->{'Name'} || '';
        $db_driver = DEFAULT->{'sql_driver_module'}
          unless VALID->{'sql_driver_module'}{$db_driver};
        my $sql_module = VALID->{'sql_driver_module'}{$db_driver};

        eval "require $sql_module"
          or return $self->error(
            qq[Unable to require SQL module "$sql_module": $@]);

        # IF YOU ARE GETTING A BIZZARE WARNING:
        # It might be that the $sql_module has errors in it
        #  aren't being reported.  This might manifest as "$self->sql" 
        #  returning nothing or as "cannot find method new".
        $self->{'sql_module'} = $sql_module->new( config => $self->config );
    }

    return $self->{'sql_module'};
}

###########################################

=pod
                                                                                
=head2 Query Caching
                                                                                
Query results (and subsequent manipulations) are cached 
in a Cache::FileCache file.

There are four levels of caching.  This is so that if some part of 
the database is changed, the whole chache does not have to be purged.  
Only the cache level and the levels above it need to be cached.

Level 1: Species or Map Sets.
Level 2: Maps
Level 3: Features
Level 4: Correspondences

For example if features are added, then Level 3 and 4 need to be purged.
If a new Map is added, Levels 2,3 and 4 need to be purged.

=cut

# ----------------------------------------------------
sub cache_array_results {

    my ( $self, $cache_level, $sql, $attr, $args, $db, $select_type, $sub ) =
      @_;
    $cache_level = 1 unless $cache_level;
    my $cache_name = "L" . $cache_level . "_cache";

    unless ( $self->{$cache_name} ) {
        $self->{$cache_name} = $self->init_cache($cache_level)
            or return;
    }

    my $data;
    my $cache_key = $sql . join( '-', @$args );
    unless ( $self->{'disable_cache'}
        or $data =
        thaw( $self->{ $cache_name }->get($cache_key) ) )
    {
        $data = $db->$select_type( $sql, $attr, @$args );
        if ( ref $sub eq 'CODE' ) {
            $sub->( $data, $db );
        }
        $self->{ $cache_name }->set( $cache_key, freeze($data) );
    }
    return $data;
}
# ----------------------------------------------------
sub get_cached_results {
    my $self        = shift;
    my $cache_level = shift;
    my $query       = shift;

    $cache_level = 1 unless $cache_level;
    my $cache_name = "L" . $cache_level . "_cache";
#print STDERR "GET: $cache_level $cache_name\n";

    unless ( $self->{$cache_name} ) {
        $self->{$cache_name} = $self->init_cache($cache_level)
            or return;
    }

    # can only check for disabled cache after init_cache is called.
    return undef if ( $self->{'disable_cache'} );

    return undef unless ($query);
    return thaw( $self->{$cache_name}->get($query) );
}

sub store_cached_results {
    my $self        = shift;
    my $cache_level = shift;
    my $query       = shift;
    my $object      = shift;
    $cache_level = 1 unless $cache_level;
    my $cache_name = "L" . $cache_level . "_cache";
#print STDERR "STORE: $cache_level $cache_name\n";

    unless ( $self->{$cache_name} ) {
        $self->{$cache_name} = $self->init_cache($cache_level)
            or return;
    }

    # can only check for disabled cache after init_cache is called.
    return undef if ( $self->{'disable_cache'} );

    $self->{$cache_name}->set( $query, freeze($object) );
}

sub init_cache {
    my $self        = shift;
    my $cache_level = shift;

    # We need to read from the config file if the cache is diabled.
    $self->{'disable_cache'} = $self->config_data('disable_cache');

    my $namespace = $self->cache_level_name($cache_level);
    return unless ($namespace);

    my %cache_params = ( 'namespace' => $namespace, );

    my $cache = new Cache::FileCache( \%cache_params );

    return $cache;
}

1;

# ----------------------------------------------------
# To create a little flower is the labour of ages.
# William Blake
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>, L<Class::Base>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

