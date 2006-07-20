package Bio::GMOD::CMap::Admin;

# vim: set ft=perl:

# $Id: Admin.pm,v 1.95 2006-07-20 13:45:40 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.95 $)[-1];

use Data::Dumper;
use Data::Pageset;
use Time::ParseDate;
use Time::Piece;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Utils qw[ parse_words ];
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
    my $sql_object = $self->sql;

    my $evidences = $sql_object->get_correspondence_evidences(
        cmap_object                => $self,
        correspondence_evidence_id => $corr_evidence_id,
    );
    return $self->error('Invalid correspondence evidence id')
        unless (@$evidences);
    my $feature_correspondence_id
        = $evidences->[0]{'feature_correspondence_id'};

    $self->attribute_delete( 'correspondence_evidence', $corr_evidence_id );
    $self->xref_delete( 'correspondence_evidence', $corr_evidence_id );

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
        feature_acc => $feature_acc,
        feature_start => $feature_start,
        feature_stop => $feature_stop,
        is_landmark => $is_landmark,
        feature_type_acc => $feature_type_acc,
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

=item - feature_acc

Identifier that is used to access this object.  Can be alpha-numeric.  
If not defined, the object_id will be assigned to it.

=item - feature_start

Location on the map where this feature begins.

=item - feature_stop

Location on the map where this feature ends. (not required)

=item - is_landmark

Declares the feature to be a landmark.

=item - feature_type_acc

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
    my $feature_acc  = $args{'feature_acc'};
    my $feature_name = $args{'feature_name'}
        or push @missing, 'feature_name';
    my $feature_type_acc = $args{'feature_type_acc'}
        or push @missing, 'feature_type_acc';
    my $feature_start = $args{'feature_start'};
    push @missing, 'start' unless $feature_start =~ /^$RE{'num'}{'real'}$/;
    my $feature_stop = $args{'feature_stop'};
    my $is_landmark  = $args{'is_landmark'} || 0;
    my $direction    = $args{'direction'} || 1;
    my $gclass       = $args{'gclass'};
    $gclass = undef unless ( $self->config_data('gbrowse_compatible') );
    my $sql_object = $self->sql or return $self->error;

    my $default_rank
        = $self->feature_type_data( $feature_type_acc, 'default_rank' ) || 1;

    if (@missing) {
        return $self->error(
            'Feature create failed.  Missing required fields: ',
            join( ', ', @missing ) );
    }

    my $feature_id = $sql_object->insert_feature(
        cmap_object      => $self,
        map_id           => $map_id,
        feature_name     => $feature_name,
        feature_acc      => $feature_acc,
        feature_type_acc => $feature_type_acc,
        feature_start    => $feature_start,
        feature_stop     => $feature_stop,
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

    my $feature_alias_id = $sql_object->insert_feature_alias(
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
        unless (@$features);

    my $map_id = $features->[0]{'map_id'};

    my $corrs = $sql_object->get_feature_correspondence_details(
        cmap_object             => $self,
        feature_id1             => $feature_id,
        disregard_evidence_type => 1,
    );
    foreach my $corr (@$corrs) {
        $self->feature_correspondence_delete(
            feature_correspondence_id => $corr->{'feature_correspondence_id'},
        );
    }

    $self->attribute_delete( 'feature', $feature_id );
    $self->xref_delete( 'feature', $feature_id );

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
        feature_acc1 => $feature_acc1,
        feature_acc2 => $feature_acc2,
        is_enabled => $is_enabled,
        evidence_type_acc => $evidence_type_acc,
        correspondence_evidence => $correspondence_evidence,
        feature_correspondence_acc => $feature_correspondence_acc,
    );

=item * Returns

Correpondence ID

=item * Fields

=over 4

=item - feature_id1

=item - feature_id2

=item - feature_acc1

=item - feature_acc2

=item - is_enabled

=item - evidence_type_acc

The accession id of a evidence type that is defined in the config file.

=item - correspondence_evidence

List of evidence hashes that correspond to the evidence types that this 
correspondence should have.  The hashes must have a "evidence_type_acc"
key.

=item - feature_correspondence_acc

Identifier that is used to access this object.  Can be alpha-numeric.  
If not defined, the object_id will be assigned to it.

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $feature_id1                = $args{'feature_id1'};
    my $feature_id2                = $args{'feature_id2'};
    my $feature_acc1               = $args{'feature_acc1'};
    my $feature_acc2               = $args{'feature_acc2'};
    my $evidence_type_acc          = $args{'evidence_type_acc'};
    my $score                      = $args{'score'};
    my $evidence                   = $args{'correspondence_evidence'};
    my $feature_correspondence_acc = $args{'feature_correspondence_acc'}
        || '';
    my $is_enabled = $args{'is_enabled'};
    $is_enabled = 1 unless defined $is_enabled;
    my $threshold = $args{'threshold'} || 0;
    my $sql_object = $self->sql or return;

    unless ( $feature_id1 or $feature_acc1 ) {

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

    if ($evidence_type_acc) {
        push @$evidence,
            {
            evidence_type_acc => $evidence_type_acc,
            score             => $score,
            };
    }

    #
    # See if we have only accession IDs and if we can find feature IDs.
    #
    if ( !$feature_id1 && $feature_acc1 ) {
        $feature_id1 = $sql_object->acc_id_to_internal_id(
            cmap_object => $self,
            object_type => 'feature',
            acc_id      => $feature_acc1,
        );
    }

    if ( !$feature_id2 && $feature_acc2 ) {
        $feature_id2 = $sql_object->acc_id_to_internal_id(
            cmap_object => $self,
            object_type => 'feature',
            acc_id      => $feature_acc2,
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
        my $corrs = $sql_object->get_feature_correspondence_details(
            cmap_object             => $self,
            feature_id1             => $feature_id1,
            feature_id2             => $feature_id2,
            disregard_evidence_type => 1,
        );
        if (@$corrs) {
            $feature_correspondence_id
                = $corrs->[0]{'feature_correspondence_id'};
        }
    }
    if ($feature_correspondence_id) {

        #
        # Add new evidences to correspondence
        # Skip if a correspondence with this evidence type exists already.
        #

        for ( my $i = 0; $i <= $#{$evidence}; $i++ ) {
            my $evidence_array = $sql_object->get_correspondence_evidences(
                cmap_object               => $self,
                feature_correspondence_id => $feature_correspondence_id,
                evidence_type_acc => $evidence->[$i]{'evidence_type_acc'},
            );
            next if @$evidence_array;

            $sql_object->insert_correspondence_evidence(
                cmap_object               => $self,
                feature_correspondence_id => $feature_correspondence_id,
                evidence_type_acc => $evidence->[$i]{'evidence_type_acc'},
                score             => $evidence->[$i]{'score'},
            );
        }
    }
    else {

        # New Correspondence

        $feature_correspondence_id
            = $sql_object->insert_feature_correspondence(
            cmap_object => $self,
            feature_id1 => $feature_id1,
            feature_id2 => $feature_id2,
            is_enabled  => $is_enabled,
            evidence    => $evidence,
            threshold   => $threshold,
            );
    }

    return $feature_correspondence_id || -1;
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
    print "Retrieving list of correspondences\n";
    my $corr_hash = $sql_object->get_duplicate_correspondences_hash(
        cmap_object => $self );
    print "Retrieved list of correspondences\n\n";
    print
        "Examining correspondences.\n (A '.' will appear for each deleted correspondence)\n";

    my $feature_count = 0;
    my $delete_count  = 0;
    my $report_num    = 5000;
    ### Move any non-duplicate evidence from the duplicate to the original.
    foreach my $feature_id1 ( keys %{$corr_hash} ) {
        $feature_count++;
        print "Examined $feature_count features.\n"
            unless ( $feature_count % $report_num );
        foreach my $feature_id2 ( keys %{ $corr_hash->{$feature_id1} } ) {
            next
                if (
                scalar( @{ $corr_hash->{$feature_id1}{$feature_id2} } )
                == 1 );

            my @corr_list = sort { $a <=> $b }
                @{ $corr_hash->{$feature_id1}{$feature_id2} };
            my $original_id = shift @corr_list;

            foreach my $duplicate_id (@corr_list) {
                $delete_count++;
                print "Deleted $delete_count duplicates.\n"
                    unless ( $delete_count % $report_num );
                print ".";
                my $move_evidence = $sql_object->get_moveable_evidence(
                    cmap_object  => $self,
                    original_id  => $original_id,
                    duplicate_id => $duplicate_id,
                );
                if ( scalar(@$move_evidence) ) {
                    foreach my $evidence_id (@$move_evidence) {
                        $sql_object->update_correspondence_evidence(
                            cmap_object                => $self,
                            correspondence_evidence_id => $evidence_id,
                            feature_correspondence_id  => $original_id,
                        );
                    }
                }
                $self->feature_correspondence_delete(
                    feature_correspondence_id => $duplicate_id );
            }
        }
    }
    print "\n\nDone. Deleted $delete_count duplicates.\n";
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
 Level 4: images

For example if features are added, then Level 3,4 and 5 need to be purged.
If a new Map is added, Levels 2,3,4 and 5 need to be purged.


=back

=back

=cut

    my ( $self, $cache_level ) = @_;
    $cache_level = 1 unless $cache_level;

    for ( my $i = $cache_level - 1; $i <= CACHE_LEVELS; $i++ ) {
        my $namespace = $self->cache_level_name($i)
            or return $self->ERROR(
            "Cache Level: $i should not be higher than " . CACHE_LEVELS );
        my %params = ( 'namespace' => $namespace, );
        my $cache = new Cache::SizeAwareFileCache( \%params );
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
    my $feature_correspondence_id = $args{'feature_correspondence_id'}
        or return $self->error('No feature correspondence id');

    my $sql_object = $self->sql or return;

    $sql_object->delete_evidence(
        cmap_object               => $self,
        feature_correspondence_id => $feature_correspondence_id,
    );

    $sql_object->delete_correspondence(
        cmap_object               => $self,
        feature_correspondence_id => $feature_correspondence_id,
    );

    $self->attribute_delete( 'feature_correspondence',
        $feature_correspondence_id, );
    $self->xref_delete( 'feature_correspondence',
        $feature_correspondence_id, );

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
        map_acc => $map_acc,
        feature_type_accs => $feature_type_accs,
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

Eather 'feature_name' or 'feature_acc'

=item - species_ids

=item - order_by

List of columns (in order) to order by. Options are
feature_name, species_common_name, map_set_short_name, map_name and feature_start.

=item - map_acc

=item - feature_type_accs

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
    my $map_acc           = $args{'map_acc'}           || '';
    my $species_ids       = $args{'species_ids'}       || [];
    my $feature_type_accs = $args{'feature_type_accs'} || [];
    my $search_field      = $args{'search_field'}      || 'feature_name';
    my $order_by          = $args{'order_by'}
        || 'feature_name,species_common_name,map_set_short_name,map_name,feature_start';
    my $sql_object = $self->sql or return;

    #
    # "-1" is a reserved value meaning "all"
    #
    $species_ids       = [] if grep {/^-1$/} @$species_ids;
    $feature_type_accs = [] if grep {/^-1$/} @$feature_type_accs;

    my %features;
    for my $feature_name ( map { uc $_ } @feature_names ) {

        my $feature_results;
        if ( $search_field eq 'feature_name' ) {
            $feature_results = $sql_object->get_features(
                cmap_object       => $self,
                map_acc           => $map_acc,
                feature_name      => $feature_name,
                feature_type_accs => $feature_type_accs,
                species_ids       => $species_ids,
                aliases_get_rows  => 1,
            );
        }
        else {
            $feature_results = $sql_object->get_features(
                cmap_object       => $self,
                map_acc           => $map_acc,
                feature_acc       => $feature_name,
                feature_type_accs => $feature_type_accs,
                species_ids       => $species_ids,
                aliases_get_rows  => 1,
            );
        }

        foreach my $f (@$feature_results) {
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
        {   total_entries    => scalar @results,
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
                feature_id  => $f->{'feature_id'},
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
        feature_acc => $feature_acc,
    );

=item * Returns

Array of feature names.

=item * Fields

=over 4

=item - feature_id

=item - feature_acc

=back

=back

=cut

    my ( $self, %args ) = @_;
    my $feature_id  = $args{'feature_id'}  || 0;
    my $feature_acc = $args{'feature_acc'} || 0;
    $self->error('Need either feature id or accession id')
        unless $feature_id || $feature_acc;

    my $sql_object = $self->sql or return;
    my $features = $sql_object->get_features_simple(
        cmap_object => $self,
        feature_id  => $feature_id,
        feature_acc => $feature_acc,
    );
    return unless (@$features);
    return $features->[0]{'feature_name'};
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
    my $order_by = $args{'order_by'} || 'feature_type_acc';

    my @feature_type_accs = keys( %{ $self->config_data('feature_type') } );
    my $feature_types;
    foreach my $type_acc ( sort { $a->{$order_by} cmp $b->{$order_by} }
        @feature_type_accs )
    {
        $feature_types->[ ++$#{$feature_types} ]
            = $self->feature_type_data($type_acc)
            or return $self->error("No feature type accession '$type_acc'");
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
        map_acc => $map_acc,
        map_start => $map_start,
        map_stop => $map_stop,
        display_order => $display_order,
    );

=item * Returns

Map ID

=item * Fields

=over 4

=item - map_name

Name of the map being created

=item - map_set_id

=item - map_acc

Identifier that is used to access this object.  Can be alpha-numeric.  
If not defined, the object_id will be assigned to it.

=item - map_start

Begining point of the map.

=item - map_stop

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
    my $map_start = $args{'map_start'};
    push @missing, 'start position'
        unless defined $map_start && $map_start ne '';
    my $map_stop = $args{'map_stop'};
    push @missing, 'stop position'
        unless defined $map_stop && $map_stop ne '';
    my $map_acc = $args{'map_acc'};

    if (@missing) {
        return $self->error( 'Map create failed.  Missing required fields: ',
            join( ', ', @missing ) );
    }

    unless ( $map_start =~ /^$RE{'num'}{'real'}$/ ) {
        return $self->error("Bad start position ($map_start)");
    }

    unless ( $map_stop =~ /^$RE{'num'}{'real'}$/ ) {
        return $self->error("Bad stop position ($map_stop)");
    }

    my $sql_object = $self->sql or return $self->error;
    my $map_id = $sql_object->insert_map(
        cmap_object   => $self,
        map_acc       => $map_acc,
        map_set_id    => $map_set_id,
        map_name      => $map_name,
        map_start     => $map_start,
        map_stop      => $map_stop,
        display_order => $display_order,
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
        unless (@$maps);

    my $map_set_id = $maps->[0]{'map_set_id'};

    my $features = $sql_object->get_features_simple(
        cmap_object => $self,
        map_id      => $map_id,
    );

    foreach my $feature (@$features) {
        $self->feature_delete( feature_id => $feature->{'feature_id'}, );
    }

    $self->attribute_delete( 'map', $map_id );
    $self->xref_delete( 'map', $map_id );

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
        map_set_acc => $map_set_acc,
        map_type_acc => $map_type_acc,
        width => $width,
        is_relational_map => $is_relational_map,
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

=item - map_set_acc

Identifier that is used to access this object.  Can be alpha-numeric.  
If not defined, the object_id will be assigned to it.

=item - map_type_acc

The accession id of a map type that is defined in the config file.

=item - width

Pixel width of the map

=item - is_relational_map

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
    my $map_type_acc = $args{'map_type_acc'}
        or push @missing, 'map_type_acc';
    my $map_set_acc   = $args{'map_set_acc'}   || '';
    my $display_order = $args{'display_order'} || 1;
    my $shape         = $args{'shape'}         || '';
    my $color         = $args{'color'}         || '';
    my $width         = $args{'width'}         || 0;
    my $published_on  = $args{'published_on'}  || 'today';

    if (@missing) {
        return $self->error(
            'Map set create failed.  Missing required fields: ',
            join( ', ', @missing ) );
    }

    if ($published_on) {
        my $pub_date = parsedate( $published_on, VALIDATE => 1 )
            or return $self->error(
            "Publication date '$published_on' is not valid");
        my $t = localtime($pub_date);
        $published_on = $t->strftime( $self->data_module->sql->date_format );
    }
    my $map_units = $self->map_type_data( $map_type_acc, 'map_units' );

           $color ||= $self->map_type_data( $map_type_acc, 'color' )
        || $self->config_data("map_color")
        || DEFAULT->{'map_color'}
        || 'black';

           $shape ||= $self->map_type_data( $map_type_acc, 'shape' )
        || $self->config_data("map_shape")
        || DEFAULT->{'map_shape'}
        || 'box';

           $width ||= $self->map_type_data( $map_type_acc, 'width' )
        || $self->config_data("map_width")
        || DEFAULT->{'map_width'}
        || '0';

    my $is_relational_map
        = $self->map_type_data( $map_type_acc, 'is_relational_map' ) || 0;

    my $map_set_id = $sql_object->insert_map_set(
        cmap_object        => $self,
        map_set_acc        => $map_set_acc,
        map_set_short_name => $map_set_short_name,
        map_set_name       => $map_set_name,
        species_id         => $species_id,
        published_on       => $published_on,
        map_type_acc       => $map_type_acc,
        display_order      => $display_order,
        shape              => $shape,
        width              => $width,
        color              => $color,
        map_units          => $map_units,
        is_relational_map  => $is_relational_map,
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
    $self->xref_delete( 'map_set', $map_set_id );

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
    my $sql_object = $self->sql or return;

    my $new_records
        = $sql_object->reload_correspondence_matrix( cmap_object => $self, );

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
    my $sql_object = $self->sql or return;

    if ($overwrite) {
        $sql_object->delete_attribute(
            cmap_object => $self,
            object_id   => $object_id,
            object_type => $object_type,
        );
    }

    for my $attr (@attributes) {
        my $attr_id    = $attr->{'attribute_id'};
        my $attr_name  = $attr->{'name'} || $attr->{'attribute_name'};
        my $attr_value =
            defined( $attr->{'value'} )
            ? $attr->{'value'}
            : $attr->{'attribute_value'};
        my $is_public     = $attr->{'is_public'};
        my $display_order = $attr->{'display_order'};

        next
            unless defined $attr_name
            && $attr_name ne ''
            && defined $attr_value
            && $attr_value ne '';

        unless ($attr_id) {
            # Check for duplicate attribute
            my $attribute = $sql_object->get_attributes(
                cmap_object    => $self,
                object_id      => $object_id,
                object_type    => $object_type,
                attribute_name => $attr_name,
                attribute_value => $attr_value,
            );
            if ( @{ $attribute || [] } ) {
                $attr_id = $attribute->[0]{'attribute_id'};
            }
        }

        if ($attr_id) {
            $sql_object->update_attribute(
                cmap_object     => $self,
                attribute_id    => $attr_id,
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
            $attr_id = $sql_object->insert_attribute(
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
    my $sql_object = $self->sql or return;

    if ( $overwrite && $object_id ) {
        $sql_object->delete_xref(
            cmap_object => $self,
            object_id   => $object_id,
            object_type => $object_type,
        );
    }

    for my $xref (@xrefs) {
        my $xref_id   = $xref->{'xref_id'};
        my $xref_name = $xref->{'name'} || $xref->{'xref_name'};
        my $xref_url  = $xref->{'url'} || $xref->{'xref_url'};
        my $is_public
            = defined( $xref->{'is_public'} ) ? $xref->{'is_public'} : 1;

        my $display_order = $xref->{'display_order'};

        next
            unless defined $xref_name
            && $xref_name ne ''
            && defined $xref_url
            && $xref_url ne '';

        unless ($xref_id) {
            # Check for duplicate xref
            my $xref = $sql_object->get_xrefs(
                cmap_object => $self,
                object_id   => $object_id,
                object_type => $object_type,
                xref_name   => $xref_name,
                xref_url    => $xref_url,
            );
            if ( @{ $xref || [] } ) {
                $xref_id = $xref->[0]{'xref_id'};
            }
        }

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
        species_acc => $species_acc,
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

=item - species_acc

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
    my $species_acc   = $args{'species_acc'};

    my $species_id = $sql_object->insert_species(
        cmap_object         => $self,
        species_acc         => $species_acc,
        species_full_name   => $species_full_name,
        species_common_name => $species_common_name,
        display_order       => $display_order,
        )
        or return $sql_object->error;

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
    my $cascade_delete = $args{'cascade_delete'} || 0;

    my $sql_object = $self->sql or return;

    my $map_sets = $sql_object->get_map_sets(
        cmap_object => $self,
        species_id  => $species_id,
    );

    if ( scalar(@$map_sets) > 0 and !$cascade_delete ) {
        return $self->error(
            'Unable to delete ',
            $map_sets->[0]{'species_common_name'},
            ' because ', scalar(@$map_sets), ' map sets are linked to it.'
        );
    }

    foreach my $map_set (@$map_sets) {
        $self->map_set_delete( map_set_id => $map_set->{'map_set_id'}, );
    }

    $self->attribute_delete( 'species', $species_id );
    $self->xref_delete( 'species', $species_id );

    $sql_object->delete_species(
        cmap_object => $self,
        species_id  => $species_id,
    );

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
    my $xref_id;

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
                {   name          => $xref_name,
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

# ----------------------------------------------------
sub validate_update_map_start_stop {

=pod

=head2 validate_update_map_start_stop

=head3 For External Use

=over 4

=item * Description

Given a map_id, make sure that the map boundaries are that of the features on
it.  If not, update the map to extend the start and stop.

=item * Usage

    $admin->validate_update_map_start_stop( $map_id );

=item * Returns

Nothing

=item * Fields

=over 4

=item - map_id

The primary key of the map.

=back

=back

=cut

    my $self       = shift;
    my $map_id     = shift or return;
    my $sql_object = $self->sql or return;

    my $map_array = $sql_object->get_maps_simple(
        cmap_object => $self,
        map_id      => $map_id,
    );
    my ( $map_start, $map_stop );
    my ( $ori_map_start, $ori_map_stop );
    if (@$map_array) {
        $ori_map_start = $map_start = $map_array->[0]{'map_start'};
        $ori_map_stop  = $map_stop  = $map_array->[0]{'map_stop'};
    }

    my ( $min_start, $max_start, $max_stop )
        = $sql_object->get_feature_bounds_on_map(
        cmap_object => $self,
        map_id      => $map_id,
        );

    #
    # Verify that the map start and stop coordinates at least
    # take into account the extremes of the feature coordinates.
    #
    $min_start = 0 unless defined $min_start;
    $max_start = 0 unless defined $max_start;
    $max_stop  = 0 unless defined $max_stop;
    $map_start = 0 unless defined $map_start;
    $map_stop  = 0 unless defined $map_stop;

    $max_stop  = $max_start if $max_start > $max_stop;
    $map_start = $min_start if $min_start < $map_start;
    $map_stop  = $max_stop  if $max_stop > $map_stop;

    if (   $ori_map_start != $map_start
        or $ori_map_stop != $map_stop )
    {
        $map_id = $sql_object->update_map(
            cmap_object => $self,
            map_id      => $map_id,
            map_start   => $map_start,
            map_stop    => $map_stop,
        );
    }

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

