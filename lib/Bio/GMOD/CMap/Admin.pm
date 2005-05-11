package Bio::GMOD::CMap::Admin;

# vim: set ft=perl:

# $Id: Admin.pm,v 1.77 2005-05-11 03:36:48 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Admin - admin functions (update, create, etc.)

=head1 SYNOPSIS

Create an Admin object to have access to its data manipulation methods.
The "data_source" parameter is a string of the name of the data source 
to be used.  This information is found in the config file as the 
"<database>" name field.

  use Bio::GMOD::CMap::Admin;

  my $admin = Bio::GMOD::CMap::Admin->new(
      data_source => $data_source
  );

=head1 DESCRIPTION

This module gives access to many data manipulation methods.

Eventually all the database interaction currently in
Bio::GMOD::CMap::Apache::AdminViewer will be moved here so that it can be
shared by my "cmap_admin.pl" script.

=head1 METHODS

=cut

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.77 $)[-1];

use Data::Dumper;
use Data::Pageset;
use Time::ParseDate;
use Time::Piece;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Utils qw[ next_number parse_words ];
use base 'Bio::GMOD::CMap';
use Bio::GMOD::CMap::Constants;
use Regexp::Common;

# ----------------------------------------------------
sub attribute_delete {

=pod

=head2 attribute_delete

=head3 For External Use

=over 4

=item * Description

Delete an object's attributes.

=item * Usage

    $admin->attribute_delete(
        $object_type,
        $object_id
    );

=item * Returns

Nothing

=item * Fields

=over 4

=item - object_type

The name of the object being reference.

=item - object_id

The primary key of the object.

=back

=back

=cut

    my $self        = shift;
    my $object_type = shift or return;
    my $object_id   = shift or return;
    my $sql_object  = $self->sql or return;

    $sql_object->delete_attribute(
        cmap_object => $self,
        object_type => $object_type,
        object_id   => $object_id,
    );
}

# ----------------------------------------------------
sub correspondence_evidence_delete {

=pod

=head2 correspondence_evidence_delete

=head3 For External Use

=over 4

=item * Description

Delete a correspondence evidence.

=item * Usage

    $admin->correspondence_evidence_delete(
        correspondence_evidence_id => $correspondence_evidence_id,
    );

=item * Returns

Nothing

=item * Fields

=over 4

=item - correspondence_evidence_id

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $corr_evidence_id = $args{'correspondence_evidence_id'}
      or return $self->error('No correspondence evidence id');

    $self->attribute_delete( 'correspondence_evidence', $corr_evidence_id );

    my $sql_object = $self->sql or return;
    my $evidences = $sql_object->get_evidences(
        cmap_object                => $self,
        correspondence_evidence_id => $corr_evidence_id,
    );
    return $self->error('Invalid correspondence evidence id')
      unless (@$evidences) my $feature_correspondence_id =
      $evidence->[0]{'feature_correspondence_id'};

    $sql_object->delete_evidence(
        cmap_object                => $self,
        correspondence_evidence_id => $corr_evidence_id,
    );

    return $feature_correspondence_id;
}

# ----------------------------------------------------
sub feature_create {

=pod

=head2 feature_create

=head3 For External Use

=over 4

=item * Description

Create a feature.

=item * Usage

    $admin->feature_create(
        map_id => $map_id,
        feature_name => $feature_name,
        feature_aid => $feature_aid,
        start_position => $start_position,
        stop_position => $stop_position,
        is_landmark => $is_landmark,
        feature_type_aid => $feature_type_aid,
        direction => $direction,
        #gclass => $gclass,
    );

=item * Returns

Feature ID

=item * Fields

=over 4

=item - map_id

Identifier of the map that this is on.

=item - feature_name

=item - feature_aid

Identifier that is used to access this object.  Can be alpha-numeric.  
If not defined, the object_id will be assigned to it.

=item - start_position

Location on the map where this feature begins.

=item - stop_position

Location on the map where this feature ends. (not required)

=item - is_landmark

Declares the feature to be a landmark.

=item - feature_type_aid

The accession id of a feature type that is defined in the config file.

=item - direction

The direction the feature points in relation to the map.

=item - gclass

The gclass that the feature will have.  This only relates to using CMap
integrated with GBrowse and should not be used otherwise. 

=back

=back

=cut

    my ( $self, %args ) = @_;
    my @missing      = ();
    my $map_id       = $args{'map_id'} or push @missing, 'map_id';
    my $feature_name = $args{'feature_name'}
      or push @missing, 'feature_name';
    my $feature_type_aid = $args{'feature_type_aid'}
      or push @missing, 'feature_type_aid';
    my $start_position = $args{'start_position'};
    push @missing, 'start' unless $start_position =~ /^$RE{'num'}{'real'}$/;
    my $stop_position = $args{'stop_position'};
    my $is_landmark   = $args{'is_landmark'} || 0;
    my $direction     = $args{'direction'} || 1;
    my $gclass        = $args{'gclass'};
    $gclass = undef unless ( $self->config_data('gbrowse_compatible') );
    my $sql_object = $self->sql_object or return $self->error;

    my $default_rank =
      $self->feature_type_data( $feature_type_aid, 'default_rank' ) || 1;

    if (@missing) {
        return $self->error(
            'Feature create failed.  Missing required fields: ',
            join( ', ', @missing ) );
    }

    my $feature_id = $sql_object->insert_feature(
        cmap_objcet      => $self,
        map_id           => $map_id,
        feature_name     => $feature_name,
        feature_type_aid => $feature_type_aid,
        start_position   => $start_position,
        stop_position    => $stop_position,
        is_landmark      => $is_landmark,
        direction        => $direction,
        default_rank     => $default_rank,
        gclass           => $gclass,
    );

    return $feature_id;
}

# ----------------------------------------------------
sub feature_alias_create {

=pod

=head2 feature_alias_create

=head3 For External Use

=over 4

=item * Description

Create an alias for a feature.  The alias is searchable.

=item * Usage

    $admin->feature_alias_create(
        feature_id => $feature_id,
        alias => $alias,
    );

=item * Returns

1

=item * Fields

=over 4

=item - feature_id

=item - alias

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $sql_object = $self->sql;
    my $feature_id = $args{'feature_id'}
      or return $self->error('No feature id');
    my $alias = $args{'alias'} or return 1;
    my $features = $sql_object->get_features_simple(
        cmap_object => $self,
        feature_id  => $feature_id,
    );

    if ( !@$features or $alias eq $features->[0]{'feature_name'} ) {
        return 1;
    }

    my $feature_aliases = $sql_object->get_feature_aliases(
        cmap_object => $self,
        alias       => $alias,
        feature_id  => $feature_id,
    );
    return 1 if (@$feature_aliases);

    my $feature_alias_id = $sql_object->insert_feature_aliases(
        cmap_object => $self,
        alias       => $alias,
        feature_id  => $feature_id,
    );

    return $feature_alias_id;
}

# ----------------------------------------------------
sub feature_delete {

=pod

=head2 feature_delete

=head3 For External Use

=over 4

=item * Description

Delete a feature.

=item * Usage

    $admin->feature_delete(
        feature_id => $feature_id,
    );

=item * Returns

Nothing

=item * Fields

=over 4

=item - feature_id

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $feature_id = $args{'feature_id'}
      or return $self->error('No feature id');

    my $sql_object = $self->sql or return;

    my $features = $sql_object->get_features(
        cmap_object => $self,
        feature_id  => $feature_id,
    );
    return $self->error('Invalid feature id')
      unless (@$features) my $map_id = $features->[0]{'map_id'};

    my $corrs = $sql_object->get_correspondence_details(
        cmap_object => $self,
        feature_id  => $feature_id,
    );
    foreach my $corr (@$corrs) {
        $self->feature_correspondence_delete(
            feature_correspondence_id => $corr->{'feature_correspondence_id'};
        );
    }

    $self->attribute_delete( 'feature', $feature_id );

    $sql_object->delete_feature_alias(
        cmap_object => $self,
        feature_id  => $feature_id,
    );

    $sql_object->delete_feature(
        cmap_object => $self,
        feature_id  => $feature_id,
    );

    return $map_id;
}

# ----------------------------------------------------
sub feature_correspondence_create {

=pod

=head2 feature_correspondence_create

=head3 For External Use

=over 4

=item * Description

Inserts a correspondence.  Returns -1 if there is nothing to do.

=item * Usage

Requires feature_ids or feature accessions for both features.

    $admin->feature_correspondence_create(
        feature_id1 => $feature_id1,
        feature_id2 => $feature_id2,
        feature_aid1 => $feature_aid1,
        feature_aid2 => $feature_aid2,
        is_enabled => $is_enabled,
        evidence_type_aid => $evidence_type_aid,
        correspondence_evidence => $correspondence_evidence,
        feature_correspondence_aid => $feature_correspondence_aid,
    );

=item * Returns

Correpondence ID

=item * Fields

=over 4

=item - feature_id1

=item - feature_id2

=item - feature_aid1

=item - feature_aid2

=item - is_enabled

=item - evidence_type_aid

The accession id of a evidence type that is defined in the config file.

=item - correspondence_evidence

List of evidence hashes that correspond to the evidence types that this 
correspondence should have.  The hashes must have a "evidence_type_aid"
key.

=item - feature_correspondence_aid

Identifier that is used to access this object.  Can be alpha-numeric.  
If not defined, the object_id will be assigned to it.

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $feature_id1                = $args{'feature_id1'};
    my $feature_id2                = $args{'feature_id2'};
    my $feature_aid1               = $args{'feature_aid1'};
    my $feature_aid2               = $args{'feature_aid2'};
    my $evidence_type_aid          = $args{'evidence_type_aid'};
    my $score                      = $args{'score'};
    my $evidence                   = $args{'correspondence_evidence'};
    my $feature_correspondence_aid = $args{'feature_correspondence_aid'} || '';
    my $is_enabled                 = $args{'is_enabled'};
    $is_enabled = 1 unless defined $is_enabled;
    my $threshold = $args{'threshold'} || 0;
    my $sql_object = $self->sql or return;

    unless ( $feature_id1 or $feature_aid1 ) {

        # Flush the buffer;
        $sql_object->insert_feature_correspondence(
            cmap_object => $self,
            threshold   => 0,
        );
    }

    my $allow_update =
      defined( $args{'allow_update'} )
      ? $args{'allow_update'}
      : 1;

    if ($evidence_type_aid) {
        push @$evidence,
          {
            evidence_type_aid => $evidence_type_aid,
            score             => $score,
          };
    }

    #
    # See if we have only accession IDs and if we can find feature IDs.
    #
    if ( !$feature_id1 && $feature_aid1 ) {
        $feature_id1 = $sql_object->acc_id_to_internal_id(
            cmap_object => $self,
            object_type => 'feature',
            acc_id      => $feature_aid1,
        );
    }

    if ( !$feature_id2 && $feature_aid2 ) {
        $feature_id2 = $sql_object->acc_id_to_internal_id(
            cmap_object => $self,
            object_type => 'feature',
            acc_id      => $feature_aid2,
        );
    }

    #
    # Bail if no feature IDs.
    #
    return -1 unless $feature_id1 && $feature_id2;

    #
    # Bail if features are the same.
    #
    return -1 if $feature_id1 == $feature_id2;

    #
    # Bail if no evidence.
    #$self->error('No evidence')
    return -1
      unless @{ $evidence || [] };

    my $feature_correspondence_id = '';
    if ($allow_update) {

        #
        # See if a correspondence exists already.
        #
        my $corrs = $sql_object->get_correspondence_details(
            cmap_object => $self,
            feature_id1 => $feature_id1,
            feature_id2 => $feature_id2,
        );
        if (@$corrs) {
            $feature_correspondence_id =
              $corrs->[0]{'feature_correspondence_id'};
        }
    }
    if ($feature_correspondence_id) {

        #
        # Add new evidences to correspondence
        # Skip if a correspondence with this evidence type exists already.
        #

        for ( my $i = 0 ; $i <= $#{$evidence} ; $i++ ) {
            my $evidence_array = $sql_object->get_evidence(
                cmap_object               => $self,
                feature_correspondence_id => $feature_correspondence_id,
                evidence_type_aid => $evidence->[$i]{'evidence_type_aid'},
            );
            next if @$evidence_array;

            $sql_object->insert_correspondence_evidence(
                cmap_object               => $self,
                feature_correspondence_id => $feature_correspondence_id,
                evidence_type_aid => $evidence->[$i]{'evidence_type_aid'},
                score             => $evidence->[$i]{'score'},
            );
        }
    }
    else {

        # New Correspondence

        my $feature_correspondence_id =
          $sql_object->insert_feature_correspondence(
            cmap_object => $self,
            feature_id1 => $feature_id1,
            feature_id2 => $feature_id2,
            is_enabled  => $is_enabled,
            evidence    => $evidence,
            threshold   => $threshold,
          );
    }

    return $feature_correspondence_id;
}

# ----------------------------------------------------
sub delete_duplicate_correspondences {

=pod

=head2 delete_duplicate_correspondences

=head3 For External Use

=over 4

=item * Description

Searches the database for duplicate correspondences and removes one
instance.  Any evidence from the deleted one that is not duplicated 
is moved to the remaining correspondence.

=item * Usage

    $admin->delete_duplicate_correspondences();

=item * Returns

Nothing

=back

=cut

    my ( $self, %args ) = @_;
    my $sql_object = $self->sql or return;

    print "Deleting Duplicate Correspondences\n";
    my $duplicates =
      $sql_object->get_duplicate_correspondences( cmap_object => $self );

    ### Move any non-duplicate evidence from the duplicate to the original.
    foreach my $dup (@$duplicates) {
        print "Deleting correspondence id " . $dup->{'duplicate_id'} . "\n";
        my $move_evidence = $sql_object->get_moveable_evidence(
            cmap_object  => $self,
            original_id  => $dup->{'original_id'},
            duplicate_id => $dup->{'duplicate_id'},
        );
        if ( scalar(@$move_evidence) ) {
            foreach my $evidence (@$move_evidence) {
                $sql_object->update_correspondence_evidence(
                    cmap_object                => $self,
                    correspondence_evidence_id =>
                      $evidence->{'correspondence_evidence_id'},
                    feature_correspondence_id => $dup->{'original_id'},
                );
            }
        }
        $self->feature_correspondence_delete(
            feature_correspondence_id => $dup->{'duplicate_id'} );
    }

}

sub purge_cache {

=pod

=head2 purge_cache

=head3 For External Use

=over 4

=item * Description

Purge the query cache from the level supplied on down.

=item * Usage

    $admin->purge_cache( $cache_level );

=item * Returns

Nothing

=item * Fields

=over 4

=item - cache_level

This is the level that you want to purge.

There are four levels of caching.  This is so that if some part of
the database is changed, the whole chache does not have to be purged.
Only the cache level and the levels above it need to be cached.

 Level 1: Species or Map Sets.
 Level 2: Maps
 Level 3: Features
 Level 4: Correspondences

For example if features are added, then Level 3 and 4 need to be purged.
If a new Map is added, Levels 2,3 and 4 need to be purged.


=back

=back

=cut

    my ( $self, $cache_level ) = @_;
    $cache_level = 1 unless $cache_level;

    for ( my $i = $cache_level - 1 ; $i <= CACHE_LEVELS ; $i++ ) {
        my $namespace = $self->cache_level_name($i)
          or return $self->ERROR(
            "Cache Level: $i should not be higher than " . CACHE_LEVELS );
        my %params = ( 'namespace' => $namespace, );
        my $cache = new Cache::FileCache( \%params );
        $cache->clear;
    }
}

# ----------------------------------------------------
sub feature_correspondence_delete {

=pod

=head2 feature_correspondence_delete

=head3 For External Use

=over 4

=item * Description

Delete a feature correspondence.

=item * Usage

    $admin->feature_correspondence_delete(
        feature_correspondence_id => $feature_correspondence_id,
    );

=item * Returns

Nothing

=item * Fields

=over 4

=item - feature_correspondence_id

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $feature_corr_id = $args{'feature_correspondence_id'}
      or return $self->error('No feature correspondence id');

    my $sql_object = $self->sql or return;
    my $evidences = $sql_object->get_evidences(
        cmap_object               => $self,
        feature_correspondence_id => $feature_correspondence_id,
    );
    return $self->error('Invalid correspondence evidence id')
      unless (@$evidences);

    $sql_object->delete_evidence(
        cmap_object               => $self,
        feature_correspondence_id => $feature_correspondence_id,
    );

    $sql_object->delete_correspondence(
        cmap_object               => $self,
        feature_correspondence_id => $feature_correspondence_id,
    );

    $self->attribute_delete( 'feature_correspondence', $feature_corr_id );

    return 1;
}

# ----------------------------------------------------
sub get_aliases {

=pod

=head2 get_aliases

=head3 For External Use

=over 4

=item * Description

Retrieves the aliases attached to a feature.

=item * Usage

    $admin->get_aliases( $feature_id );

=item * Returns

Arrayref of hashes with keys "feature_alias_id", "feature_id" and "alias".

=back

=cut

    my ( $self, $feature_id ) = @_;
    my $sql_object = $self->sql or return;

    return $sql_object->get_feature_aliases(
        cmap_object => $self,
        feature_id  => $feature_id,
    );
}

# ----------------------------------------------------
sub feature_search {

=pod

=head2 feature_search

=head3 For External Use

=over 4

=item * Description

Find all the features matching some criteria.

=item * Usage

None of the fields are required.

    $admin->feature_search(
        search_field => $search_field,
        species_ids => $species_ids,
        order_by => $order_by,
        map_aid => $map_aid,
        feature_type_aids => $feature_type_aids,
    );

=item * Returns

Hash with keys "results" and "pager".

"results": Arrayref of hashes with column names as keys.

"pager": a Data::Pageset object.

=item * Fields

=over 4

=item - feature_name

A string with one or more feature names or accessions to search.

=item - search_field

Eather 'feature_name' or 'feature_accession'

=item - species_ids

=item - order_by

List of columns (in order) to order by. Options are
feature_name, species_common_name, map_set_short_name, map_name and start_position.

=item - map_aid

=item - feature_type_aids

=back

=back

=cut

    my ( $self, %args ) = @_;
    my @feature_names = (
        map {
            s/\*/%/g;          # turn stars into SQL wildcards
            s/,//g;            # kill commas
            s/^\s+|\s+$//g;    # kill leading/trailing whitespace
            s/"//g;            # kill double quotes
            s/'/\\'/g;         # backslash escape single quotes
            uc $_ || ()        # uppercase what's left
          } parse_words( $args{'feature_name'} )
    );
    my $map_aid           = $args{'map_aid'}           || '';
    my $species_ids       = $args{'species_ids'}       || [];
    my $feature_type_aids = $args{'feature_type_aids'} || [];
    my $search_field      = $args{'search_field'}      || 'feature_name';
    my $order_by          = $args{'order_by'}
      || 'feature_name,species_common_name,map_set_short_name,map_name,start_position';
    my $sql_object = $self->sql_object or return;

    #
    # "-1" is a reserved value meaning "all"
    #
    $species_ids       = [] if grep { /^-1$/ } @$species_ids;
    $feature_type_aids = [] if grep { /^-1$/ } @$feature_type_aids;

    my %features;
    for my $feature_name ( map { uc $_ } @feature_names ) {

        if ( $search_field eq 'feature_name' ) {
            my $features = $sql_object->get_feature_details(
                cmap_object       => $self,
                map_id            => $map_id,
                feature_name      => $feature_name,
                feature_type_aids => $feature_type_aids,
                species_ids       => $species_ids,
                aliases_get_rows  => 1,
            );
        }
        else {
            my $features = $sql_object->get_feature_details(
                cmap_object       => $self,
                map_id            => $map_id,
                feature_aid       => $feature_name,
                feature_type_aids => $feature_type_aids,
                species_ids       => $species_ids,
                aliases_get_rows  => 1,
            );

        }

        foreach my $f (@$features) {
            $features{ $f->{'feature_id'} } = $f;
        }
    }

    my @results = ();
    if ( $order_by =~ /position/ ) {
        @results =
          map  { $_->[1] }
          sort { $a->[0] <=> $b->[0] }
          map  { [ $_->{$order_by}, $_ ] } values %features;
    }
    else {
        my @sort_fields = split( /,/, $order_by );
        @results =
          map  { $_->[1] }
          sort { $a->[0] cmp $b->[0] }
          map  { [ join( '', @{$_}{@sort_fields} ), $_ ] } values %features;
    }

    #
    # Slice the results up into pages suitable for web viewing.
    #
    my $pager = Data::Pageset->new(
        {
            total_entries    => scalar @results,
            entries_per_page => $args{'entries_per_page'},
            current_page     => $args{'current_page'},
            pages_per_set    => $args{'pages_per_set'},
        }
    );

    if (@results) {
        @results = $pager->splice( \@results );

        for my $f (@results) {
            $f->{'aliases'} = $sql_object->get_feature_aliases(
                cmap_object => $self,
                feature_id  => $feature_id,
            );
        }
    }

    return {
        results => \@results,
        pager   => $pager,
    };
}

# ----------------------------------------------------
sub feature_name_by_id {

=pod

=head2 feature_name_by_id

=head3 For External Use

=over 4

=item * Description

Find a feature's name by either its internal or accession ID.

=item * Usage

    $admin->feature_name_by_id(
        feature_id => $feature_id,
        feature_aid => $feature_aid,
    );

=item * Returns

Array of feature names.

=item * Fields

=over 4

=item - feature_id

=item - feature_aid

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $feature_id  = $args{'feature_id'}  || 0;
    my $feature_aid = $args{'feature_aid'} || 0;
    $self->error('Need either feature id or accession id')
      unless $feature_id || $feature_aid;

    my $sql_object = $self->sql or return;
    my $features = $sql_object->get_features_simple(
        cmap_object => $self,
        feature_id  => $feature_id,
        feature_aid => $feature_aid,
    );
    return unless (@$features);
    return $feature->[0]{'feature_name'};
}

# ----------------------------------------------------
sub feature_types {

=pod

=head2 feature_types

=head3 For External Use

=over 4

=item * Description

Find all the feature types.

=item * Usage

    $admin->feature_types(
        order_by => $order_by,
    );

=item * Returns

Arrayref of hashes with feature_type data.

=item * Fields

=over 4

=item - order_by

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $order_by = $args{'order_by'} || 'feature_type_aid';

    my @feature_type_aids = keys( %{ $self->config_data('feature_type') } );
    my $feature_types;
    foreach my $type_aid ( sort { $a->{$order_by} cmp $b->{$order_by} }
        @feature_type_aids )
    {
        $feature_types->[ ++$#{$feature_types} ] =
          $self->feature_type_data($type_aid)
          or return $self->error("No feature type accession '$type_aid'");
    }
    return $feature_types;
}

# ----------------------------------------------------
sub map_create {

=pod

=head2 map_create

=head3 For External Use

=over 4

=item * Description

map_create

=item * Usage

    $admin->map_create(
        map_name => $map_name,
        map_set_id => $map_set_id,
        map_aid => $map_aid,
        start_position => $start_position,
        stop_position => $stop_position,
        display_order => $display_order,
    );

=item * Returns

Map ID

=item * Fields

=over 4

=item - map_name

Name of the map being created

=item - map_set_id

=item - map_aid

Identifier that is used to access this object.  Can be alpha-numeric.  
If not defined, the object_id will be assigned to it.

=item - start_position

Begining point of the map.

=item - stop_position

End point of the map.

=item - display_order

=back

=back

=cut

    my ( $self, %args ) = @_;
    my @missing    = ();
    my $map_set_id = $args{'map_set_id'}
      or push @missing, 'map_set_id';
    my $map_name = $args{'map_name'};
    my $display_order = $args{'display_order'} || 1;
    push @missing, 'map name' unless defined $map_name && $map_name ne '';
    my $start_position = $args{'start_position'};
    push @missing, 'start position'
      unless defined $start_position && $start_position ne '';
    my $stop_position = $args{'stop_position'};
    push @missing, 'stop position'
      unless defined $stop_position && $stop_position ne '';
    my $map_aid = $args{'map_aid'};

    if (@missing) {
        return $self->error( 'Map create failed.  Missing required fields: ',
            join( ', ', @missing ) );
    }

    unless ( $start_position =~ /^$RE{'num'}{'real'}$/ ) {
        return $self->error("Bad start position ($start_position)");
    }

    unless ( $stop_position =~ /^$RE{'num'}{'real'}$/ ) {
        return $self->error("Bad stop position ($stop_position)");
    }

    my $sql_object = $self->sql or return $self->error;
    my $map_id = $sql_object->insert_map(
        cmap_objcet    => $self,
        map_aid        => $map_aid,
        map_set_id     => $map_set_id,
        map_name       => $map_name,
        start_position => $start_position,
        stop_position  => $stop_position,
        display_order  => $display_order,
    );

    return $map_id;
}

# ----------------------------------------------------
sub map_delete {

=pod

=head2 map_delete

=head3 For External Use

=over 4

=item * Description

Delete a map.

=item * Usage

    $admin->map_delete(
        map_id => $map_id,
    );

=item * Returns

Nothing

=item * Fields

=over 4

=item - map_id

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $map_id     = $args{'map_id'} or return $self->error('No map id');
    my $sql_object = $self->sql      or return;

    my $maps = $sql_object->get_maps(
        cmap_object => $self,
        map_id      => $map_id,
    );
    return $self->error('Invalid map id')
      unless (@$maps) my $map_set_id = $maps->[0]{'map_set_id'};

    my $features = $sql_object->get_features_simple(
        cmap_object => $self,
        map_id      => $map_id,
    );

    foreach my $feature (@$features) {
        $self->feature_delete( feature_id => $feature->{'feature_id'}, );
    }

    $self->attribute_delete( 'map', $map_id );

    $sql_object->delete_map(
        cmap_object => $self,
        map_id      => $map_id,
    );

    return $map_set_id;
}

# ----------------------------------------------------
sub map_set_create {

=pod

=head2 map_set_create

=head3 For External Use

=over 4

=item * Description

map_set_create

=item * Usage

    $admin->map_set_create(
        map_set_name => $map_set_name,
        map_set_aid => $map_set_aid,
        map_type_aid => $map_type_aid,
        width => $width,
        can_be_reference_map => $can_be_reference_map,
        published_on => $published_on,
        map_set_short_name => $map_set_short_name,
        display_order => $display_order,
        species_id => $species_id,
        color => $color,
        shape => $shape,
    );

=item * Returns

Map Set ID

=item * Fields

=over 4

=item - map_set_name

Name of the map set being created

=item - map_set_aid

Identifier that is used to access this object.  Can be alpha-numeric.  
If not defined, the object_id will be assigned to it.

=item - map_type_aid

The accession id of a map type that is defined in the config file.

=item - width

Pixel width of the map

=item - can_be_reference_map

=item - published_on

=item - map_set_short_name

=item - display_order

=item - species_id

=item - color

Identifier that is used to access this object.  Can be alpha-numeric.  
If not defined, the object_id will be assigned to it.

=item - shape

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $sql_object   = $self->sql;
    my @missing      = ();
    my $map_set_name = $args{'map_set_name'}
      or push @missing, 'map_set_name';
    my $map_set_short_name = $args{'map_set_short_name'}
      or push @missing, 'map_set_short_name';
    my $species_id = $args{'species_id'}
      or push @missing, 'species';
    my $map_type_aid = $args{'map_type_aid'}
      or push @missing, 'map_type_aid';
    my $map_set_aid          = $args{'map_set_aid'}          || '';
    my $display_order        = $args{'display_order'}        || 1;
    my $can_be_reference_map = $args{'can_be_reference_map'} || 0;
    my $shape                = $args{'shape'}                || '';
    my $color                = $args{'color'}                || '';
    my $width                = $args{'width'}                || 0;
    my $published_on         = $args{'published_on'}         || 'today';

    if (@missing) {
        return $self->error(
            'Map set create failed.  Missing required fields: ',
            join( ', ', @missing ) );
    }

    if ($published_on) {
        my $pub_date = parsedate( $published_on, VALIDATE => 1 )
          or
          return $self->error("Publication date '$published_on' is not valid");
        my $t = localtime($pub_date);
        $published_on = $t->strftime( $self->data_module->sql->date_format );
    }
    my $map_units = $self->map_type_data( $map_type_aid, 'map_units' );
         $color = $self->map_type_data( $map_type_aid, 'color' )
      || $self->config_data("map_color")
      || DEFAULT->{'map_color'}
      || 'black';
         $shape = $self->map_type_data( $map_type_aid, 'shape' )
      || $self->config_data("map_shape")
      || DEFAULT->{'map_shape'}
      || 'box';
    my $is_relational_map =
      $self->map_type_data( $map_type_aid, 'is_relational_map' ) || 0;

    my $sql_object = $self->sql or return $self->error;
    my $map_set_id = $sql_object->insert_set_map(
        cmap_objcet          => $self,
        map_set_aid          => $map_set_aid,
        map_set_short_name   => $map_set_short_name,
        map_set_name         => $map_set_name,
        species_id           => $species_id,
        can_be_reference_map => $can_be_reference_map,
        published_on         => $published_on,
        map_type_aid         => $map_type_aid,
        display_order        => $display_order,
        shape                => $shape,
        width                => $width,
        color                => $color,
        map_units            => $map_units,
        is_relational_map    => $is_relational_map,
    );

    return $map_set_id;
}

# ----------------------------------------------------
sub map_set_delete {

=pod

=head2 map_set_delete

=head3 For External Use

=over 4

=item * Description

Delete a map set.

=item * Usage

    $admin->map_set_delete(
        map_set_id => $map_set_id,
    );

=item * Returns

Nothing

=item * Fields

=over 4

=item - map_set_id

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $map_set_id = $args{'map_set_id'}
      or return $self->error('No map set id');
    my $sql_object = $self->sql or return;
    my $maps = $sql_object->get_maps(
        cmap_object => $self,
        map_set_id  => $map_set_id,
    );

    foreach my $map (@$maps) {
        $self->map_delete( map_id => $map->{'map_id'}, );
    }

    $self->attribute_delete( 'map_set', $map_set_id );

    $sql_object->delete_map_set(
        cmap_object => $self,
        map_set_id  => $map_set_id,
    );

    return 1;
}

# ----------------------------------------------------
sub reload_correspondence_matrix {

=pod

=head2 reload_correspondence_matrix

=head3 For External Use

=over 4

=item * Description

Reload the matrix data table with up to date information

=item * Usage

    $admin->reload_correspondence_matrix();

=item * Returns

Nothing

=back

=cut

    my ( $self, %args ) = @_;
    my $sqp_object = $self->sql or return;

    my $new_records =
      $sql_object->reload_correspondence_matrix( cmap_object => $self, );

    print("\n$new_records new records inserted.\n");
}

# ----------------------------------------------------
sub set_attributes {

=pod

=head2 set_attributes

=head3 For External Use

=over 4

=item * Description

Set the attributes for a database object.

=item * Usage

    $admin->set_attributes(
        object_id => $object_id,
        overwrite => $overwrite,
        object_type => $object_type,
    );

=item * Returns

1

=item * Fields

=over 4

=item - object_id

The primary key of the object.

=item - overwrite

Set to 1 to delete old data first.

=item - object_type

The name of the object being reference.

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $object_id = $args{'object_id'}
      or return $self->error('No object id');
    my $object_type = $args{'object_type'}
      or return $self->error('No table name');
    my @attributes = @{ $args{'attributes'} || [] } or return;
    my $overwrite = $args{'overwrite'} || 0;

    if ($overwrite) {
        $sql_object->delete_attribute(
            cmap_object => $self,
            object_id   => $object_id,
            object_type => $object_type,
        );
    }

    for my $attr (@attributes) {
        my $attribute_id = $attr->{'attribute_id'} || 0;
        my $attr_name    = $attr->{'name'}         || $attr->{'attribute_name'};
        my $attr_value    = $attr->{'value'} || $attr->{'attribute_value'};
        my $is_public     = $attr->{'is_public'};
        my $display_order = $attr->{'display_order'};

        next
          unless defined $attr_name
          && $attr_name ne ''
          && defined $attr_value
          && $attr_value ne '';

        my $attributes_array = $sql_object->get_attributes(
            cmap_object     => $self,
            object_id       => $object_id,
            object_type     => $object_type,
            attribute_name  => $attr_name,
            attribute_value => $attr_value,
        );
        $attribute_id = $attributes_array->[0]{'attribute_id'}
          if (@$map_set_array);

        if ($attribute_id) {
            $sql_object->update_attribute(
                cmap_object     => $self,
                attribute_id    => $attribute_id,
                object_id       => $object_id,
                object_type     => $object_type,
                attribute_name  => $attr_name,
                attribute_value => $attr_value,
                display_order   => $display_order,
                is_public       => $is_public,
            );
        }
        else {
            $is_public = 1 unless defined $is_public;
            $attribute_id = $sql_object->insert_attribute(
                cmap_object     => $self,
                object_id       => $object_id,
                object_type     => $object_type,
                attribute_name  => $attr_name,
                attribute_value => $attr_value,
                display_order   => $display_order,
                is_public       => $is_public,
            );
        }
    }

    return 1;
}

# ----------------------------------------------------
sub set_xrefs {

=pod

=head2 set_xrefs

=head3 For External Use

=over 4

=item * Description

Set the attributes for a database object.

=item * Usage

    $admin->set_xrefs(
        object_id => $object_id,
        overwrite => $overwrite,
        object_type => $object_type,
    );

=item * Returns

1

=item * Fields

=over 4

=item - object_id

The primary key of the object.

=item - overwrite

Set to 1 to delete old data first.

=item - object_type

The name of the object being reference.

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $object_id   = $args{'object_id'};
    my $object_type = $args{'object_type'}
      or return $self->error('No object name');
    my @xrefs = @{ $args{'xrefs'} || [] } or return;
    my $overwrite = $args{'overwrite'} || 0;

    if ( $overwrite && $object_id ) {
        $sql_object->delete_xref(
            cmap_object => $self,
            object_id   => $object_id,
            object_type => $object_type,
        );
    }

    for my $xref (@xrefs) {
        my $xref_id   = $xref->{'xref_id'} || 0;
        my $xref_name = $xref->{'name'}    || $xref->{'xref_name'};
        my $xref_url  = $xref->{'url'}     || $xref->{'xref_url'};
        my $display_order = $xref->{'display_order'};

        next
          unless defined $xref_name
          && $xref_name ne ''
          && defined $xref_url
          && $xref_url ne '';

        my $xrefs_array = $sql_object->get_xrefs(
            cmap_object => $self,
            object_id   => $object_id,
            object_type => $object_type,
            xref_name   => $xref_name,
            xref_url    => $xref_url,
        );
        $xref_id = $xrefs_array->[0]{'xref_id'} if (@$map_set_array);

        if ($xref_id) {
            $sql_object->update_xref(
                cmap_object   => $self,
                xref_id       => $xref_id,
                object_id     => $object_id,
                object_type   => $object_type,
                xref_name     => $xref_name,
                xref_url      => $xref_url,
                display_order => $display_order,
            );
        }
        else {
            $is_public = 1 unless defined $is_public;
            $xref_id = $sql_object->insert_xref(
                cmap_object   => $self,
                object_id     => $object_id,
                object_type   => $object_type,
                xref_name     => $xref_name,
                xref_url      => $xref_url,
                display_order => $display_order,
            );
        }
    }

    return 1;
}

# ----------------------------------------------------
sub species_create {

=pod

=head2 species_create

=head3 For External Use

=over 4

=item * Description

species_create

=item * Usage

    $admin->species_create(
        species_full_name => $species_full_name,
        species_common_name => $species_common_name,
        display_order => $display_order,
        species_aid => $species_aid,
    );

=item * Returns

Species ID

=item * Fields

=over 4

=item - species_full_name

Full name of the species, such as "Homo Sapiens".

=item - species_common_name

Short name of the species, such as "Human".

=item - display_order

=item - species_aid

Identifier that is used to access this object.  Can be alpha-numeric.  
If not defined, the object_id will be assigned to it.

=back

=back

=cut

    my ( $self, %args ) = @_;
    my @missing;
    my $sql_object          = $self->sql;
    my $species_common_name = $args{'species_common_name'}
      or push @missing, 'common name';
    my $species_full_name = $args{'species_full_name'}
      or push @missing, 'full name';
    if (@missing) {
        return $self->error(
            'Species create failed.  Missing required fields: ',
            join( ', ', @missing ) );
    }

    my $display_order = $args{'display_order'} || 1;
    my $species_aid   = $args{'species_aid'};

    my $species_id = $sql_object->insert_species(
        cmap_objcet         => $self,
        species_aid         => $species_aid,
        species_id          => $species_id,
        species_full_name   => $species_full_name,
        species_common_name => $species_common_name,
        display_order       => $display_order,
    );

    return $species_id;
}

# ----------------------------------------------------
sub species_delete {

=pod

=head2 species_delete

=head3 For External Use

=over 4

=item * Description

Delete a species.

=item * Usage

    $admin->species_delete(
        species_id => $species_id,
    );

=item * Returns

Nothing

=item * Fields

=over 4

=item - species_id

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $species_id = $args{'species_id'}
      or return $self->error('No species id');

    my $sql_object = $self->sql or return;

    my $map_sets = $sql_object->get_map_sets(
        cmap_object => $self,
        species_id  => $species_id,
    );

    if ( scalar(@$map_sets) > 0 ) {
        return $self->error(
            'Unable to delete ',
            $map_sets->[0]{'species_common_name'},
            ' because ', scalar(@$map_sets), ' map sets are linked to it.'
        );
    }
    else {
        $self->attribute_delete( 'species', $species_id );

        $sql_object->delete_species(
            cmap_object => $self,
            species_id  => $species_id,
        );
    }

    return 1;
}

# ----------------------------------------------------
sub xref_create {

=pod

=head2 xref_create

=head3 For External Use

=over 4

=item * Description

xref_create

=item * Usage

    $admin->xref_create(
        object_id => $object_id,
        xref_name => $xref_name,
        xref_url => $xref_url,
        object_type => $object_type,
        display_order => $display_order,
    );

=item * Returns

XRef ID

=item * Fields

=over 4

=item - object_id

The primary key of the object.

=item - xref_name

=item - xref_url

=item - object_type

The name of the table being reference.

=item - display_order

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $sql_object  = $self->sql or return $self->error;
    my @missing     = ();
    my $object_id   = $args{'object_id'} || 0;
    my $object_type = $args{'object_type'}
      or push @missing, 'database object (table name)';
    my $xref_name = $args{'xref_name'} or push @missing, 'xref name';
    my $xref_url  = $args{'xref_url'}  or push @missing, 'xref URL';
    my $display_order = $args{'display_order'};

    if (@missing) {
        return $self->error(
            'Cross-reference create failed.  Missing required fields: ',
            join( ', ', @missing ) );
    }

    #
    # See if one like this exists already.
    #
    my $xrefs = $sql_object->get_xrefs(
        cmap_object => $self,
        object_type => $object_type,
        object_id   => $object_id,
        xref_name   => $xref_name,
        xref_url    => $xref_url,
    );

    if (@$xrefs) {
        my $xref = $xrefs->[0];
        $xref_id = $xref->{'xref_id'};
        if ( defined $display_order
            && $xref->{'display_order'} != $display_order )
        {
            $sql_object->update_xrefs(
                cmap_object   => $self,
                display_order => $display_order,
                xref_id       => $xref_id,
            );
        }
    }
    else {
        $xref_id = $self->set_xrefs(
            object_id   => $object_id,
            object_type => $object_type,
            xrefs       => [
                {
                    name          => $xref_name,
                    url           => $xref_url,
                    display_order => $display_order,
                },
            ],
          )
          or return $self->error;
    }

    return $xref_id;
}

# ----------------------------------------------------
sub xref_delete {

=pod

=head2 xref_delete

=head3 For External Use

=over 4

=item * Description

Delete a cross reference.

=item * Usage

    $admin->xref_delete(
        $object_type,
        $object_id
    );

=item * Returns

Nothing

=item * Fields

=over 4

=item - object_type

The name of the table being reference.

=item - object_id

The primary key of the object.

=back

=back

=cut

    my $self        = shift;
    my $object_type = shift or return;
    my $object_id   = shift or return;
    my $sql_object  = $self->sql or return;

    $sql_object->delete_xref(
        cmap_object => $self,
        object_type => $object_type,
        object_id   => $object_id,
    );

    return 1;
}

1;

# ----------------------------------------------------
# I should have been a pair of ragged claws,
# Scuttling across the floors of silent seas.
# T. S. Eliot
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

