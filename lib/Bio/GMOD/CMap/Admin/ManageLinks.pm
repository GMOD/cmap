package Bio::GMOD::CMap::Admin::ManageLinks;
# vim: set ft=perl:

# $Id: ManageLinks.pm,v 1.3 2004-10-01 18:07:24 mwz444 Exp $

=pod

=head1 NAME

Bio::GMOD::CMap::Admin::ManageLinks - imports and drops links 

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::ManageLinks;

  my $importer = Bio::GMOD::CMap::Admin::ManageLinks->new(db=>$db);
  $importer->import(
      map_set_id => $map_set_id,
      fh         => $fh,
  ) or print "Error: ", $importer->error, "\n";

=head1 DESCRIPTION

This module encapsulates the logic for importing all the various types
of maps into the database.

=cut

use strict;
use vars qw( $VERSION %DISPATCH %COLUMNS );
$VERSION  = (qw$Revision: 1.3 $)[-1];

use Data::Dumper;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Constants;
use Text::RecordParser;
use Text::ParseWords 'parse_line';
use Cache::FileCache;
use Storable qw(freeze thaw);
use Regexp::Common;
use base 'Bio::GMOD::CMap';

use constant FIELD_SEP => "\t"; # use tabs for field separator
use constant STRING_RE => qr{\S+}; 
use constant RE_LOOKUP => {
    string => STRING_RE,
    number => '^'.$RE{'num'}{'real'}.'$',
};

use vars '$LOG_FH';

%COLUMNS = (
    map_name             => { is_required => 1, datatype => 'string' },
    map_start            => { is_required => 0, datatype => 'number' },
    map_stop             => { is_required => 0, datatype => 'number' },
    map_accesion_id      => { is_required => 0, datatype => 'string' },
    link_name            => { is_required => 0, datatype => 'string' },
);

# ----------------------------------------------------

=pod

=head2 import_links

Imports tab-delimited file with the following fields:

    map_name *
    map_accession_id
    map_start
    map_stop
    link_name

=cut

sub import_links {

    my ( $self, %args ) = @_;
    my $db              = $self->db           or die 'No database handle';
    my $map_set_id      = $args{'map_set_id'} or die      'No map set id';
    my $link_set_name   = $args{'link_set_name'} or die 'No link set name';
    my $name_space      = $args{'name_space'} or die 'No name space';
    my $fh              = $args{'fh'}         or die     'No file handle';

    $LOG_FH             = $args{'log_fh'}     ||                 \*STDOUT;
    my @links;
    
    #
    # Make column names lowercase, convert spaces to underscores 
    # (e.g., make "Feature Name" => "feature_name").
    #
    $self->Print("Checking headers.\n");
    my $parser = Text::RecordParser->new(
        fh              => $fh,
        field_separator => FIELD_SEP,
        header_filter   => sub { $_ = shift; s/\s+/_/g; lc $_ },
        field_filter    => sub { $_ = shift; s/^\s+|\s+$//g; $_ },
    );
    $parser->field_compute(
        'feature_aliases', sub { [ parse_line( ',', 0, shift() ) ] }
    );
    $parser->bind_header;

    my %required = 
        map  { $_, 0 }
        grep { $COLUMNS{ $_ }{'is_required'} }
        keys %COLUMNS;
        
    for my $column_name ( $parser->field_list ) {
        if ( exists $COLUMNS{ $column_name } ) {
            $self->Print("Column '$column_name' OK.\n");
            $required{ $column_name } = 1 if defined $required{ $column_name };
        }
        else {
            return $self->error("Column name '$column_name' is not valid.");
        }
    }

    if ( my @missing = grep { $required{ $_ } == 0 } keys %required ) {
        return $self->error("Missing following required columns: ".
            join(', ', @missing) 
        );
    }

    my $sql_str=q[
        select accession_id 
        from cmap_map_set ms
        where ms.map_set_id=?
        ];
    my ($map_set_aid,) = $db->selectrow_array( $sql_str, {}, ($map_set_id) )
        or return $self->error("$map_set_id is not a real map set id");

    $self->Print("Parsing file...\n");
    my ($last_map_name,$last_map_id)=('','');
    while ( my $record = $parser->fetchrow_hashref ) {
        for my $field_name ( $parser->field_list ) {
            my $field_attr = $COLUMNS{ $field_name } or next;
            my $field_val  = $record->{ $field_name };

            if ( 
                $field_attr->{'is_required'} && 
                ( !defined $field_val || $field_val eq '' )
            ) {
                return $self->error("Field '$field_name' is required");
            }

            my $datatype = $field_attr->{'datatype'} || '';
            if ( $datatype && defined $field_val && $field_val ne '' ) {
                if ( my $regex = RE_LOOKUP->{ $datatype } ) {
                    #
                    # The following line forces the string a numeric 
                    # context where it's more likely to succeed in the
                    # regex.  This solves ".4" being bad according to
                    # the regex.
                    #
                    $field_val += 0 if $datatype eq 'number';
                    return $self->error(
                        "Value of '$field_name' is wrong.  " .
                        "Expected $datatype and got '$field_val'."
                    ) unless $field_val =~ $regex;
                }
            }
            elsif ( $datatype eq 'number' && $field_val eq '' ) {
                $field_val = undef;
            }
        }

        my $map_aid    = $record->{'map_accession_id'};
        my $map_name   = $record->{'map_name'};
        my $map_start  = $record->{'map_start'};
        my $map_stop   = $record->{'map_stop'};
        my $link_name  = $record->{'link_name'};
        my $sth = $db->prepare(qq[
            select accession_id
            from   cmap_map map
            where  map.map_set_id=?
               and map.map_name=?
            ]);

        unless(defined($map_aid)){
            return $self->error(
                "Must specify a map_accession_id or a map_name\n"
                ) unless(defined($map_name));
            
            $sth->execute( $map_set_id,$map_name );
            my $hr = $sth->fetchrow_hashref;
            $map_aid = $hr->{'accession_id'};
            return $self->error(
                "$map_name was not in the dataset\n"
                ) unless(defined($map_aid));
        }
        unless($link_name){
            $link_name       = $map_name ? $map_name:"map_aid:$map_aid";
            if (defined($map_start) and defined($map_stop)
                and !($map_start eq '') and !($map_stop eq '')){
                $link_name.=" from $map_start to $map_stop.";
            }
            elsif(defined($map_start)and !($map_start eq '')){
                $link_name.=" from $map_start to the end.";
            }
            elsif(defined($map_stop)and !($map_stop eq '')){
                $link_name.=" from the start to $map_stop.";
            }
        }

        my %ref_map_aids_hash;
        $ref_map_aids_hash{$map_aid}=();
        my %temp_hash=(
            link_name            => $link_name,
            ref_map_set_aid => $map_set_aid,
            ref_map_aids    => \%ref_map_aids_hash,
            ref_map_start   => $map_start,
            ref_map_stop    => $map_stop,
            data_source     => $self->data_source,
        );
        push @links,\%temp_hash ;
    }
    my %cache_params = (
        'namespace' => $name_space,
    );
    my $cache = new Cache::FileCache( \%cache_params );

    $cache->set( $link_set_name, freeze(\@links) );
    $self->Print("Done\n");
    
    return 1;
}

# ----------------------------------------------------
sub delete_links {

=pod

=head2 delete_links 

Deletes links

=cut

    my ( $self, %args ) = @_;
    my $link_set_name   = $args{'link_set_name'};
    my $name_space      = $args{'name_space'} or die 'No name space';
    $LOG_FH             = $args{'log_fh'}     ||                 \*STDOUT;

    my %cache_params = (
        'namespace' => $name_space,
    );
    my $cache = new Cache::FileCache( \%cache_params );

    $cache->remove($link_set_name);
    return 1;
}

# ----------------------------------------------------
sub list_set_names {

=pod

=head2 list_set_names 

Lists all the link sets in this namespace

=cut

    my ( $self, %args ) = @_;
    my $name_space      = $args{'name_space'} or die 'No name space';
    $LOG_FH             = $args{'log_fh'}     ||                 \*STDOUT;

    my %cache_params = (
        'namespace' => $name_space,
    );
    my $cache = new Cache::FileCache( \%cache_params );

    return $cache->get_keys();
}

# ----------------------------------------------------
sub output_links {

=pod

=head2 list_set_names 

Lists all the link sets in this namespace

=cut

    my ( $self, %args ) = @_;
    my $name_space      = $args{'name_space'} or return;
    my $link_set_name   = $args{'link_set_name'} or return;
    $LOG_FH             = $args{'log_fh'}     ||                 \*STDOUT;

    my %cache_params = (
        'namespace' => $name_space,
    );
    my $cache = new Cache::FileCache( \%cache_params );

    my @links;
    my $link_data_set=thaw($cache->get($link_set_name)); 
    foreach my $link_data (@$link_data_set){
        my %temp_array=(
            name => $link_data->{'link_name'},
            link => $self->create_viewer_link(%$link_data),
        );
        push @links,\%temp_array;
    }
    return @links; 
}

# -------------------------------------------
sub Print {
    my $self = shift;
    print $LOG_FH @_;
}

1;

# ----------------------------------------------------
# Which way does your beard point tonight?
# Allen Ginsberg
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
