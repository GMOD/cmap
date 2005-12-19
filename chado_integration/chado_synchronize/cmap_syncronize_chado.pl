#!/usr/bin/perl -w

=head1 NAME

cmap_syncronize_chado.pl: reads a chado schema and inserts data into CMap.
   
=head1 SYNOPSIS

cmap_syncronize_chado.pl --chado_datasource datasource -u sql_username [-p sql_password] --cmap_datasource cmap_datasource 

Options:

	--chado_datasource chado_datasource( postgres ex: "dbi:Pg:dbname=chado")
	--cmap_datasource cmap_datasource as defined by the CMap config files (ex. CMAP)
	-u sql_username
	-p sql_password (optional) 

=head1 DESCRIPTION

With a little input from the user, this reads a chado schema and inserts data
into CMAP.

It requires that the featureset table be populated before hand.

=cut

use strict;
use Getopt::Long;
use DBI;
use Pod::Usage;
use Benchmark;
use Data::Dumper;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Constants;
use Bio::GMOD::CMap::Utils;

use constant CMAP_BASE_NAME => 'cmap';

my ( $help, $chado_datasource,$cmap_datasource, $user, $password );

GetOptions(
    'help|h|?'              => \$help,
    'chado_datasource|d|:s' => \$chado_datasource,
    'u:s'                   => \$user,
    'p:s'                   => \$password,
    'cmap_datasource|m|:s'  => \$cmap_datasource,
    )
    or pod2usage;

$cmap_datasource ||= q{};

unless ($chado_datasource and $cmap_datasource and $user){
    print "ERROR: Not all required command line flags were defined\n";
    pod2usage(0);
}

$password = $password || '';

pod2usage(0) if $help;

my $options = {
    AutoCommit       => 1,
    FetchHashKeyName => 'NAME_lc',
    LongReadLen      => 3000,
    LongTruncOk      => 1,
    RaiseError       => 1,
};
my $dbh = DBI->connect( $chado_datasource, $user, $password, $options );

# Create the CMap object that will do the CMap grunt work 
my $cmap_object = Bio::GMOD::CMap->new(data_source => $cmap_datasource,);

# If the data source is wrong, it won't match what was created
if ($cmap_datasource ne $cmap_object->data_source()){
    die qq{'$cmap_datasource' is not a proper CMap data source};
}

# This object is a direct link to the sql queries for CMap.
my $cmap_sql_object = $cmap_object->sql();

my $contact_id   = get_set_contact($dbh);
die unless ($contact_id);
my $db_ids_ref = get_set_all_dbs( $contact_id,$dbh );

print "Dealing with Species \n";
my @selected_featureset_ids = select_featureset();

my %chado_to_cmap_species = get_set_cmap_species(
    dbh             => $dbh,
    cmap_sql_object => $cmap_sql_object,
    cmap_object     => $cmap_object,
    species_db_id   => $db_ids_ref->{'species'},
    selected_featureset_ids =>\@selected_featureset_ids,
);

print "Dealing with Map Sets\n";
my @inserted_featureset_ids = get_set_cmap_map_set(
    dbh                       => $dbh,
    cmap_sql_object           => $cmap_sql_object,
    cmap_object               => $cmap_object,
    map_set_db_id             => $db_ids_ref->{'map_set'},
    chado_to_cmap_species_ref => \%chado_to_cmap_species,
    selected_featureset_ids =>\@selected_featureset_ids,
);

print "Dealing with Maps\n";
my %chado_to_cmap_map;
for my $featureset_id (@inserted_featureset_ids){
    my %tmp_chado_to_cmap_map = get_set_cmap_map(
        dbh             => $dbh,
        cmap_sql_object => $cmap_sql_object,
        cmap_object     => $cmap_object,
        map_db_id       => $db_ids_ref->{'map'},
        map_set_db_id   => $db_ids_ref->{'map_set'},
        featureset_id   => $featureset_id,
    );
    for my $key (keys %tmp_chado_to_cmap_map){
        $chado_to_cmap_map{$key}=$tmp_chado_to_cmap_map{$key};
    }
}
print "Dealing with Features\n";
get_set_cmap_feature(
    dbh             => $dbh,
    cmap_sql_object => $cmap_sql_object,
    cmap_object     => $cmap_object,
    chado_to_cmap_map_ref     => \%chado_to_cmap_map,
    map_db_id       => $db_ids_ref->{'map'},
    feature_db_id   => $db_ids_ref->{'feature'},
);

#----------------------------------------------

sub get_set_contact {
    my $dbh = shift;
    my $contact_id        = $dbh->selectrow_array(
        q[
            select contact_id
            from   contact
            where  description=?
        ],
        {}, (CMAP_BASE_NAME)
    );
    unless ($contact_id) {
        $dbh->do(
            q[
                insert into contact 
                ( description )
                values (?)
            ], {}, (CMAP_BASE_NAME)
        );
        $contact_id = $dbh->selectrow_array(
            q[ select currval('contact_contact_id_seq') ],
        );
    }
    return $contact_id;
}

sub get_set_all_dbs {
    my $contact_id   = shift;
    my $dbh = shift;
    my $db_ids_ref;

    for my $db_type ( qw[ species map_set map feature ] ) {
        $db_ids_ref->{$db_type} = get_set_db(CMAP_BASE_NAME.'_'.$db_type, $contact_id,$dbh);
    }
    
    return $db_ids_ref;
}

sub get_set_db {
    my $cmap_db_name = shift;
    my $contact_id  = shift;
    my $dbh = shift;
    my $db_id        = $dbh->selectrow_array(
        q[
            select db_id
            from   db
            where  name=?
        ],
        {}, ($cmap_db_name)
    );
    unless ($db_id) {
        $dbh->do(
            q[
                insert into db 
                ( name, contact_id)
                values (?,?)
            ],
            {}, ( $cmap_db_name, $contact_id )
        );
        $db_id
            = $dbh->selectrow_array( q[ select currval('db_db_id_seq') ], );
    }
    return $db_id;
}

sub select_featureset {

    my @selected_featureset_ids;
    my $all_featuresets = $dbh->selectall_arrayref(
        q[
        select
            fs.featureset_id,
            fs.name as featureset_name,
            o.genus,
            o.species
        from
            featureset fs,
            organism o
        where fs.organism_id = o.organism_id
        ],
        { Columns => {} },
    );

    @selected_featureset_ids = show_menu(
        title      => 'Select Feature Types',
        prompt     => 'Which cmap feature types should we look for?',
        display    => 'featureset_name,genus,species',
        return     => 'featureset_id',
        allow_null => 1,
        allow_mult => 1,
        allow_all  => 1,
        data       => $all_featuresets,
    );

    return @selected_featureset_ids;
}

sub get_set_cmap_species {

    my %args = @_;
    my $dbh = $args{'dbh'};
    my $cmap_sql_object = $args{'cmap_sql_object'};
    my $cmap_object = $args{'cmap_object'};
    my $species_db_id = $args{'species_db_id'};
    my $selected_featureset_ids = $args{'selected_featureset_ids'};
    
    my %chado_to_cmap_species;

    # Get previously inserted organisms
    my $prev_org_sql = 
        q[ 
        select 
            odbx.organism_id 
        from 
            organism_dbxref odbx, 
            dbxref dbx,
            db
        where 
            odbx.dbxref_id = dbx.dbxref_id
        and db.db_id = dbx.db_id 
        and db.name = ?
        ];
    if ( @{ $selected_featureset_ids || [] } ) {
        $prev_org_sql .= q[ 
            and odbx.organism_id in ( 
                select organism_id 
                from featureset
                where featureset_id in (
            ]
            . join( q{,}, map {'?'} @{selected_featureset_ids} ) 
            . q[
                )
                )
            ];
    }

    my $previously_inserted_organisms_ref = $dbh->selectall_arrayref(
        $prev_org_sql,
        { Columns => {} },
        CMAP_BASE_NAME . '_species', @{$selected_featureset_ids || []}
    );

    # Get IDs and insert into the hash
    my @previously_inserted_organism_ids;
    for my $organism (@$previously_inserted_organisms_ref) {
        push @previously_inserted_organism_ids, $organism->{'organism_id'};
        $chado_to_cmap_species{ $organism->{'organism_id'} } = $organism->{'accession'};
    }

    # Get new inserts
    my $organism_sql = q[
        select distinct
            o.organism_id,
            o.abbreviation,
            o.genus,
            o.species,
            o.common_name,
            o.comment
        from organism o,
            featureset fs
        where o.organism_id = fs.organism_id
    ];
    if (@previously_inserted_organism_ids) {
        $organism_sql .= q[ and o.organism_id not in ( ]
            . join( q{,}, @previously_inserted_organism_ids ) . ')';
    }
    if ( @{ $selected_featureset_ids || [] } ) {
        $organism_sql .= q[ 
            and fs.featureset_id in (
            ]
            . join( q{,}, map {'?'} @{selected_featureset_ids} ) 
            . q[
                )
            ];
    }
    my $new_organisms
        = $dbh->selectall_arrayref( $organism_sql, { Columns => {} }, @{$selected_featureset_ids || []},);
    #print "PROMPT USER FOR DISPLAY ORDER\n";
    for my $new_organism (@{$new_organisms||[]}){
        my $organism_id = $new_organism->{'organism_id'};
        my $species_full_name
            = $new_organism->{'genus'} . q{ } . $new_organism->{'species'}
            || $new_organism->{'common_name'}
            || $new_organism->{'abbreviation'};
        my $species_common_name = $new_organism->{'common_name'}
            || $new_organism->{'abbreviation'}
            || $species_full_name;
        my $display_order = 1;
       
        my $species_id = $cmap_sql_object->insert_species(
            cmap_object         => $cmap_object,
            species_common_name => $species_common_name,
            species_full_name   => $species_full_name,
            display_order       => $display_order,
        );
        $chado_to_cmap_species{ $organism_id }
            = $species_id;
        
        # Insert dbxref
        $dbh->do(
            q[
                insert into dbxref 
                ( db_id, accession)
                values (?,?)
            ], {}, ($species_db_id,$species_id)
        );
        my $dbxref_id = $dbh->selectrow_array(
            q[ select currval('dbxref_dbxref_id_seq') ],
        );
        $dbh->do(
            q[
                insert into organism_dbxref 
                ( dbxref_id, organism_id)
                values (?,?)
            ], {}, ($dbxref_id,$organism_id)
        );
    }
    

    return %chado_to_cmap_species;
}

sub get_set_cmap_map_set {

    my %args = @_;
    my $dbh = $args{'dbh'};
    my $cmap_sql_object = $args{'cmap_sql_object'};
    my $cmap_object = $args{'cmap_object'};
    my $map_set_db_id = $args{'map_set_db_id'};
    my $chado_to_cmap_species_ref = $args{'chado_to_cmap_species_ref'};
    my $selected_featureset_ids = $args{'selected_featureset_ids'};
    
    # Get previously inserted featuresets
    my $prev_featureset_sql = 
        q[ 
        select 
            dbx.accession,
            fsdbx.featureset_id 
        from 
            featureset_dbxref fsdbx, 
            dbxref dbx,
            db
        where 
            fsdbx.dbxref_id = dbx.dbxref_id
        and db.db_id = dbx.db_id 
        and db.name = ?
        ];
    if ( @{ $selected_featureset_ids || [] } ) {
        $prev_featureset_sql .= q[ 
            and fsdbx.featureset_id in (
            ]
            . join( q{,}, map {'?'} @{selected_featureset_ids} ) 
            . q[
                )
            ];
    }
    my $previously_inserted_featuresets_ref = $dbh->selectall_arrayref(
        $prev_featureset_sql,
        { Columns => {} },
        CMAP_BASE_NAME . '_map_set', @{$selected_featureset_ids || []}, 
    );

    # Get IDs and insert into the hash
    my @inserted_featureset_ids;
    for my $featureset (@$previously_inserted_featuresets_ref) {
        push @inserted_featureset_ids, $featureset->{'featureset_id'};
    }

    # Get new inserts
    my $featureset_sql = q[
    select 
        fs.featureset_id,
        fs.name,
        fs.uniquename,
        fs.organism_id, 
        cvt.name as type_name
    from 
        featureset fs,  
        cvterm cvt
        where fs.feature_type_id = cvt.cvterm_id
    ];
    if (@inserted_featureset_ids) {
        $featureset_sql .= q[ and fs.featureset_id not in ( ]
            . join( q{,}, @inserted_featureset_ids ) . ')';
    }
    if ( @{ $selected_featureset_ids || [] } ) {
        $featureset_sql .= q[ 
            and fs.featureset_id in (
            ]
            . join( q{,}, map {'?'} @{selected_featureset_ids} ) 
            . q[
                )
            ];
    }

    my $new_featuresets
        = $dbh->selectall_arrayref( $featureset_sql, { Columns => {} }, @{$selected_featureset_ids || []},);
    #print "PROMPT USER FOR MAP SET PARAMS\n";
    for my $new_featureset (@{$new_featuresets||[]}){
        # get map set type and remove improper chars
        my $map_type_acc = $new_featureset->{'type_name'};
        $map_type_acc =~ s/\s+/_/g;

        my $map_type_data = $cmap_object->map_type_data($map_type_acc);
        unless($map_type_data and %$map_type_data){
            print qq{Map type accession, '$map_type_acc' }
                . qq{not found in the CMap config file.\n};
            print qq{To include these maps in CMap, }
                . qq{create a map_type entry for '$map_type_acc' in the config file.\n};
            next;
        };
        my $species_id;
        unless ( $species_id
            = $chado_to_cmap_species_ref->{ $new_featureset->{'organism_id'} }
            )
        {
            die qq{ERROR: Organism with ID '}
                . $new_featureset->{'organism_id'}
                . qq{' doesn't have a dbxref to cmap \n};
        }

        # Get map type params
        my $featureset_id      = $new_featureset->{'featureset_id'};
        my $map_set_name       = $new_featureset->{'name'};
        my $map_set_short_name = $new_featureset->{'uniquename'};
        my $published_on       = undef;
        my $display_order      = 1;
        my $is_enabled         = 1;
        my $shape              = $map_type_data->{'shape'}
            || $cmap_object->config_data("map_shape")
            || DEFAULT->{'map_shape'}
            || 'box';
        my $width = $map_type_data->{'width'}
            || $cmap_object->config_data("map_width")
            || DEFAULT->{'map_width'}
            || '0';
        my $color = $map_type_data->{'color'}
            || $cmap_object->config_data("map_color")
            || DEFAULT->{'map_color'}
            || 'black';
        my $map_units         = $map_type_data->{'map_units'}         || 'bp';
        my $is_relational_map = $map_type_data->{'is_relational_map'} || 0;
       
        # Insert
        my $map_set_id = $cmap_sql_object->insert_map_set(
            cmap_object        => $cmap_object,
            map_set_name       => $map_set_name,
            map_set_short_name => $map_set_short_name,
            map_type_acc       => $map_type_acc,
            species_id         => $species_id,
            published_on       => $published_on,
            display_order      => $display_order,
            is_enabled         => $is_enabled,
            shape              => $shape,
            width              => $width,
            color              => $color,
            map_units          => $map_units,
            is_relational_map  => $is_relational_map,
        );
        
        # Insert dbxref
        $dbh->do(
            q[
                insert into dbxref 
                ( db_id, accession)
                values (?,?)
            ], {}, ($map_set_db_id,$map_set_id)
        );
        my $dbxref_id = $dbh->selectrow_array(
            q[ select currval('dbxref_dbxref_id_seq') ],
        );
        $dbh->do(
            q[
                insert into featureset_dbxref 
                ( dbxref_id, featureset_id)
                values (?,?)
            ], {}, ($dbxref_id,$featureset_id)
        );
        push @inserted_featureset_ids, $new_featureset->{'featureset_id'};
    }
    

    return @inserted_featureset_ids;
}

sub get_set_cmap_map {

    my %args = @_;
    my $dbh = $args{'dbh'};
    my $cmap_sql_object = $args{'cmap_sql_object'};
    my $cmap_object = $args{'cmap_object'};
    my $map_db_id = $args{'map_db_id'};
    my $map_set_db_id = $args{'map_set_db_id'};
    my $featureset_id = $args{'featureset_id'};
    
    # Get previously inserted featuresets
    my $previously_inserted_features_ref = $dbh->selectall_arrayref(
        q[ 
        select 
            dbx.accession,
            fdbx.feature_id 
        from 
            feature_dbxref fdbx, 
            dbxref dbx,
            feature_featureset ffs
        where 
            fdbx.dbxref_id = dbx.dbxref_id
        and fdbx.feature_id = ffs.feature_id
        and dbx.db_id = ?
        and ffs.featureset_id = ?
        ],
        { Columns => {} },
        $map_db_id,$featureset_id,
    );

    # Get IDs and insert into the hash
    my %chado_to_cmap_map;
    for my $feature (@$previously_inserted_features_ref) {
        $chado_to_cmap_map{$feature->{'feature_id'}}=$feature->{'accession'};
    }

    # Get new inserts
    my $feature_sql = q[
    select 
        f.feature_id,
        f.name as map_name,
        f.uniquename,
        f.seqlen,
        dbx.accession as map_set_id,
        cvt.name as type_name
    from 
        dbxref dbx,
        feature_featureset ffs,
        feature f,
        featureset_dbxref fsdbx,
        cvterm cvt
        where f.type_id = cvt.cvterm_id
        and f.feature_id = ffs.feature_id
        and ffs.featureset_id = fsdbx.featureset_id
        and dbx.dbxref_id = fsdbx.dbxref_id
        and dbx.db_id = ?
        and ffs.featureset_id = ? 
    ];
    if (%chado_to_cmap_map) {
        $feature_sql .= q[ and f.feature_id not in ( ]
            . join( q{,}, keys(%chado_to_cmap_map) ) . ')';
    }

    my $new_features
        = $dbh->selectall_arrayref( $feature_sql, { Columns => {} }, $map_set_db_id,$featureset_id,);
    #print "PROMPT USER FOR MAP PARAMS\n";
    for my $new_feature (@{$new_features||[]}){


        # Get map type params
        my $feature_id = $new_feature->{'feature_id'};
        my $map_set_id = $new_feature->{'map_set_id'};
        my $map_name   = $new_feature->{'map_name'}
            || $new_feature->{'uniquename'}
            || 'UNNAMED';
        my $display_order = 1;
        my $map_start     = 1;
        my $map_stop      = $new_feature->{'seqlen'};
       
        # Insert
        my $map_id = $cmap_sql_object->insert_map(
            cmap_object   => $cmap_object,
            map_set_id    => $map_set_id,
            map_name      => $map_name,
            display_order => $display_order,
            map_start     => $map_start,
            map_stop      => $map_stop,
        );

        $chado_to_cmap_map{$new_feature->{'feature_id'}}= $map_id;
        
        # Insert dbxref
        $dbh->do(
            q[
                insert into dbxref 
                ( db_id, accession)
                values (?,?)
            ], {}, ($map_db_id,$map_id)
        );
        my $dbxref_id = $dbh->selectrow_array(
            q[ select currval('dbxref_dbxref_id_seq') ],
        );
        $dbh->do(
            q[
                insert into feature_dbxref 
                ( dbxref_id, feature_id)
                values (?,?)
            ], {}, ($dbxref_id,$feature_id)
        );
    }

    return %chado_to_cmap_map;
}

sub get_set_cmap_feature {

    my %args = @_;
    my $dbh = $args{'dbh'};
    my $cmap_sql_object = $args{'cmap_sql_object'};
    my $cmap_object = $args{'cmap_object'};
    my $chado_to_cmap_map_ref = $args{'chado_to_cmap_map_ref'};
    my $map_db_id = $args{'map_db_id'};
    my $feature_db_id = $args{'feature_db_id'};
    
    my $all_feature_types = fake_selectall_arrayref( $cmap_object,
        $cmap_object->feature_type_data(),
        'feature_type_acc', 'feature_type' );

    $all_feature_types = sort_selectall_arrayref( $all_feature_types, 'feature_type' );
                                                                                                                             
    my @feature_type_accs = show_menu(
        title      => 'Select Feature Types',
        prompt     => 'Which cmap feature types should we look for?',
        display    => 'feature_type',
        return     => 'feature_type_acc',
        allow_null => 0,
        allow_mult => 1,
        allow_all  => 1,
        data       => $all_feature_types,
    );

    # Since the data involved can be huge, 
    # we're going to handle each map individual

    my %failed_feature_types;
    for my $chado_map_id (keys %{$chado_to_cmap_map_ref||{}}){
    print "Handling Map $chado_map_id\n";

        # Get new inserts
        my $feature_sql = q[
        select 
            floc.featureloc_id,
            f.name,
            f.uniquename,
            floc.fmin as feature_start,
            floc.fmax as feature_stop,
            floc.strand as direction,
            cvt.name as type_name
        from 
            featureloc floc,
            feature f,
            cvterm cvt
            where f.type_id = cvt.cvterm_id
            and f.feature_id = floc.feature_id
            and floc.srcfeature_id = ?
        ];
        if (@feature_type_accs) {
            $feature_sql .= q[ 
                and cvt.name in ( ]
                . join( q{,}, map {'?'} @feature_type_accs ) . ')';
        }
        $feature_sql .= q[
            and floc.featureloc_id not in (
                select 
                    fldbx.featureloc_id
                from 
                    featureloc_dbxref fldbx, 
                    featureloc floc, 
                    dbxref dbx
                where 
                    fldbx.dbxref_id = dbx.dbxref_id
                and fldbx.featureloc_id = floc.featureloc_id
                and dbx.db_id = ?
                and floc.srcfeature_id = ?
            )
            ];


        my $new_features = $dbh->selectall_arrayref(
            $feature_sql, { Columns => {} }, $chado_map_id,
            @feature_type_accs, $feature_db_id, $chado_map_id,
        );
        print "Inserting ".scalar @{$new_features||[]}." features.\n";
        #print "PROMPT USER FOR FEATURE PARAMS\n";
        for my $new_feature (@{$new_features||[]}){
            # get feature type and remove improper chars
            my $feature_type_acc = $new_feature->{'type_name'};
            $feature_type_acc =~ s/\s+/_/g;
            if ($failed_feature_types{$feature_type_acc}){
                next;
            }

            my $feature_type_data = $cmap_object->feature_type_data($feature_type_acc);
            unless($feature_type_data and %$feature_type_data){
                $failed_feature_types{$feature_type_acc}=1;
                print qq{Feature type accession, '$feature_type_acc' }
                    . qq{not found in the CMap config file.\n};
                print qq{To include these features in CMap, }
                    . qq{create a feature_type entry for '$feature_type_acc' in the config file.\n};
                next;
            };

            # Get map type params
            my $featureloc_id   = $new_feature->{'featureloc_id'};
            my $cmap_map_id       = $chado_to_cmap_map_ref->{$chado_map_id};
            my $feature_name = $new_feature->{'name'}
                || $new_feature->{'uniquename'};
            my $is_landmark   = $feature_type_data->{'is_landmark'} || 0;
            my $feature_start = $new_feature->{'feature_start'};
            my $feature_stop  = $new_feature->{'features_stop'};
            unless ( defined $feature_stop ) {
                $feature_stop = $feature_start;
            }
            my $default_rank = $new_feature->{''};
            my $direction;
            if ( defined( $new_feature->{'strand'} )
                and $new_feature->{'strand'} < 0 )
            {
                $direction = -1;
            }
            else {
                $direction = 1;
            }
           
            # Insert
            my $cmap_feature_id = $cmap_sql_object->insert_feature(
                cmap_object      => $cmap_object,
                map_id           => $cmap_map_id,
                feature_type_acc => $feature_type_acc,
                feature_name     => $feature_name,
                is_landmark      => $is_landmark,
                feature_start    => $feature_start,
                feature_stop     => $feature_stop,
                default_rank     => $default_rank,
                direction        => $direction,
            );
            
            # Insert dbxref
            $dbh->do(
                q[
                    insert into dbxref 
                    ( db_id, accession)
                    values (?,?)
                ], {}, ($feature_db_id,$cmap_feature_id)
            );
            my $dbxref_id = $dbh->selectrow_array(
                q[ select currval('dbxref_dbxref_id_seq') ],
            );
            $dbh->do(
                q[
                    insert into featureloc_dbxref 
                    ( dbxref_id, featureloc_id)
                    values (?,?)
                ], {}, ($dbxref_id,$featureloc_id)
            );
        }
    }

    return 1;
}

# ----------------------------------------------------
sub show_menu {
    my %args   = @_;
    my $data   = $args{'data'} or return;
    my @return = split( /,/, $args{'return'} )
      or die "No return field(s) defined\n";
    my @display = split( /,/, $args{'display'} );
    my $result;

    if ( scalar @$data > 1 || $args{'allow_null'} ) {
        my $i      = 1;
        my %lookup = ();

        my $title = $args{'title'} || '';
        print $title ? "\n$title\n" : "\n";
        for my $row (@$data) {
            print "[$i] ", join( ' : ', map { $row->{$_} } @display ), "\n";
            $lookup{$i} =
              scalar @return > 1
              ? [ map { $row->{$_} } @return ]
              : $row->{ $return[0] };
            $i++;
        }

        if ( $args{'allow_all'} ) {
            print "[$i] All of the above\n";
        }

        my $prompt = $args{'prompt'} || 'Please select';
        $prompt .=
             $args{'allow_null'}
          && $args{'allow_mult'} ? "\n(<Enter> for nothing, multiple allowed): "
          : $args{'allow_null'}  ? ' (0 or <Enter> for nothing): '
          : $args{'allow_mult'}  ? ' (multiple allowed): '
          : $args{'allow_mult'}  ? ' (multiple allowed):'
          : ' (one choice only): ';

        for ( ; ; ) {
            print "\n$prompt";
            chomp( my $answer = <STDIN> );

            if ( $args{'allow_null'} && !$answer ) {
                $result = undef;
                last;
            }
            elsif ( $args{'allow_all'} || $args{'allow_mult'} ) {
                my %numbers =

                  # make a lookup
                  map { $_, 1 }

                  # take only numbers
                  grep { /\d+/ }

                  # look for ranges
                  map { $_ =~ m/(\d+)-(\d+)/ ? ( $1 .. $2 ) : $_ }

                  # split on space or comma
                  split /[,\s]+/, $answer;

                if ( $args{'allow_all'} && grep {$_ == $i} keys %numbers ) {
                    $result = [ map { $lookup{$_} } 1 .. $i - 1 ];
                    last;
                }

                $result = [
                    map { $_ || () }    # parse out nulls
                      map  { $lookup{$_} }    # look it up
                      sort { $a <=> $b }      # keep order
                      keys %numbers           # make unique
                ];

                next unless @$result;
                last;
            }
            elsif ( defined $lookup{$answer} ) {
                $result = $lookup{$answer};
                last;
            }
        }
    }
    elsif ( scalar @$data == 0 ) {
        $result = undef;
    }
    else {

        # only one choice, use it.
        $result = [ map { $data->[0]->{$_} } @return ];
        $result = [$result] if ( $args{'allow_mult'} );
        unless ( wantarray or scalar(@$result) != 1 ) {
            $result = $result->[0];
        }
        my $value = join( ' : ', map { $data->[0]->{$_} } @display );
        my $title = $args{'title'} || '';
        print $title ? "\n$title\n" : "\n";
        print "Using '$value'\n";
    }

    return wantarray
      ? defined $result ? @$result : ()
      : $result;
}


