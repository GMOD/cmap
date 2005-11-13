package Bio::GMOD::CMap::Admin::MakeCorrespondences;

# vim: set ft=perl:

# $Id: MakeCorrespondences.pm,v 1.55 2005-11-13 02:20:49 mwz444 Exp $

=head1 NAME

Bio::GMOD::CMap::Admin::MakeCorrespondences - create correspondences

=head1 SYNOPSIS

  use Bio::GMOD::CMap::Admin::MakeCorrespondences;
  blah blah blah

=head1 DESCRIPTION

This module will create automated name-based correspondences.
Basically, it selects every feature from the database (optionally for
only one given map set) and then selects every other feature of the
same type that has either a "feature_name" or alias
matching either its "feature_name" or alias.  The match
must be exact (no suffixes or prefixes), but it is not case-sensitive.
This type of correspondence is likely to be highly error-prone as it
will be very optimistic about what is a valid correspondence (e.g.,
it will create relationships between features named "centromere"), so
it is suggested that you create an evidence like "Automated
name-based" and give it a low ranking in relation to your other
correspondence evidences.

=cut

use strict;
use vars qw( $VERSION $LOG_FH );
$VERSION = (qw$Revision: 1.55 $)[-1];

use Data::Dumper;
use File::Spec::Functions;
use File::Temp qw( tempdir );
use File::Path;
use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Admin;
use Storable qw( store retrieve );

use base 'Bio::GMOD::CMap';

# ----------------------------------------------------
sub make_name_correspondences {

=pod

=head2 make_name_correspondences

=head3 For External Use

=over 4

=item * Description

This will create automated name-based correspondences.

=item * Usage

    $exporter->make_name_correspondences(
        log_fh => $log_fh,
        allow_update => $allow_update,
        quiet => $quiet,
        evidence_type_acc => $evidence_type_acc,
        name_regex => $name_regex,
    );

=item * Returns

1

=item * Fields

=over 4

=item - log_fh

File handle of the log file (default is STDOUT).

=item - allow_update 

If allow is set to 1, the database will be searched for duplicates 
which is slow.  Setting to 0 is recommended.

=item - quiet

Run quietly if 1.

=item - evidence_type_acc

The accession of an evidence type that is defined in the config file.
The correspondences created will have this evidence type.

=item - name_regex

Optional regular expression that captures a part of the name and 
uses that part in the comparisons.  The default is to use the whole
name for the comparison.

Example:  Read1.sp6 and Read1.t7 

The default would not match these two but if the name_regex were 
'(\S+)\.\w+\d$', the "Read1" portion would be captured and they 
would match.

=back

=back

=cut

    my ( $self, %args ) = @_;

    my @from_map_set_ids       = @{ $args{'from_map_set_ids'}       || [] };
    my @to_map_set_ids         = @{ $args{'to_map_set_ids'}         || [] };
    my @skip_feature_type_accs = @{ $args{'skip_feature_type_accs'} || [] };
    my $evidence_type_acc      = $args{'evidence_type_acc'}
                                 or return 'No evidence type';
    my $name_regex             = $args{'name_regex'} 
                                 ? qr/$args{'name_regex'}/o : undef;
    my $quiet                  = $args{'quiet'};
    my $allow_update           = $args{'allow_update'};
    my $sql_object             = $self->sql;
    my $config                 = $self->config;
    my $admin                  = Bio::GMOD::CMap::Admin->new(
        config                 => $config,
        data_source            => $self->data_source,
    );
    my $temp_dir               = tempdir( CLEANUP => 1 );

    my $orig_handler = $SIG{'INT'};
    local $SIG{'INT'} = sub { 
        rmtree $temp_dir;
        &$orig_handler if ref $orig_handler eq 'CODE';
        exit 1;
    };
    
    $LOG_FH = $args{'log_fh'} || \*STDOUT;

    $self->Print("Making name-based correspondences.\n");

    #
    # Normally we only create name-based correspondences between
    # features of the same type, but this reads the configuration
    # file and adds in other allowed feature types.
    #
    my %add_name_correspondences;
    for my $line ( $self->config_data('add_name_correspondence') ) {
        my @feature_type_accs = split /\s+/, $line;

        for my $i ( 0 .. $#feature_type_accs ) {
            my $ft1 = $feature_type_accs[$i] or next;

            for my $j ( $i + 1 .. $#feature_type_accs ) {
                my $ft2 = $feature_type_accs[$j];
                next if $ft1 eq $ft2;

                $add_name_correspondences{ $ft1 }{ $ft2 } = 1;
                $add_name_correspondences{ $ft2 }{ $ft1 } = 1;
            }
        }
    }

    #
    # Make sure they're all accounted for (e.g., possibly defined
    # on multiple lines, as of old).
    #
    for my $ft1 ( keys %add_name_correspondences ) {
        for my $ft2 ( keys %{ $add_name_correspondences{ $ft1 } } ) {
            for my $ft3 ( keys %{ $add_name_correspondences{ $ft2 } } ) {
                next if $ft1 == $ft3;
                $add_name_correspondences{ $ft1 }{ $ft3 } = 1;
            }
        }
    }

    my %disallow_name_correspondence;
    for my $line ( $self->config_data('disallow_name_correspondence') ) {
        my @feature_types = split /\s+/, $line;
        for my $ft ( @feature_types ) {
            $disallow_name_correspondence{ $ft } = 1;
        }
    }

    my @from_map_ids;
    for my $from_ms_id ( @from_map_set_ids ) {
        push @from_map_ids, $self->_get_map_ids( $from_ms_id );
    }

    my @to_map_ids;
    for my $to_ms_id ( @to_map_set_ids ) {
        push @to_map_ids, $self->_get_map_ids( $to_ms_id );
    }

    my %processed_map_pair;
    my ( $num_checked_maps, $num_corr_existed, $num_new_corr ) = ( 0, 0, 0 );

    FROM_MAP:
    for my $from_map_id ( @from_map_ids ) {
        $num_checked_maps++;
        $self->Print("Getting features for map id $from_map_id\n");
        my $from_features = $self->_get_features({
            map_id               => $from_map_id,
            ignore_feature_types => \@skip_feature_type_accs,
            name_regex           => $name_regex,
            temp_dir             => $temp_dir,
        });

        my $num_from_features = scalar keys %$from_features;

        if ( $num_from_features == 0 ) {
            next FROM_MAP;
        }

        TO_MAP:
        for my $to_map_id ( @to_map_ids ) {
            if ( 
                   $from_map_id == $to_map_id
                || $processed_map_pair{ $from_map_id }{ $to_map_id   }++
                || $processed_map_pair{ $to_map_id   }{ $from_map_id }++
            ) {
                next TO_MAP;
            }

            $num_checked_maps++;

            $self->Print("Getting features for map id $to_map_id\n");

            my $to_features = $self->_get_features({
                map_id               => $to_map_id,
                ignore_feature_types => \@skip_feature_type_accs,
                name_regex           => $name_regex,
                temp_dir             => $temp_dir,
            });

            my $num_to_features = scalar keys %$to_features;

            if ( $num_to_features == 0 ) {
                next TO_MAP;
            }

            my ( $smaller_hr, $larger_hr ) = 
                ( $num_from_features < $num_to_features )
                ? ( $from_features, $to_features   )
                : ( $to_features  , $from_features )
            ;

            my $corr = $self->_get_correspondences( 
                $from_map_id, $to_map_id, $evidence_type_acc
            );

            my %done;
            while ( 
                my ( $fname, $features ) = each %$smaller_hr
            ) {
                next unless defined $larger_hr->{ $fname };

                for my $f1 ( @$features ) {
                    my ( $fid1, $ftype1 ) = @$f1;

                    FEATURE_ID2:
                    for my $f2 ( @{ $larger_hr->{ $fname } } ) {
                        my ( $fid2, $ftype2 ) = @$f2;

                        if (
                               $done{ $fid1 }{ $fid2 }++
                            || $done{ $fid2 }{ $fid1 }++
                        ) {
                            next FEATURE_ID2;
                        }

                        if ( $corr->{ $fid2 }{ $fid1 } ) {
                            $self->Print(
                                "Corr existed '$fname' $fid1 => $fid2\n"
                            );
                            $num_corr_existed++;
                            next FEATURE_ID2;
                        }

                        #
                        # Check feature types.
                        #
                        if ( 
                            $ftype1 ne $ftype2 
                            && !$add_name_correspondences{ $ftype1 }{ $ftype2 }
                        ) {
                            next FEATURE_ID2;
                        }

                        if ( 
                            $ftype1 eq $ftype2
                            && $disallow_name_correspondence{ $ftype1 }
                        ) {
                            next FEATURE_ID2;
                        }

                        my $fc_id = $admin->feature_correspondence_create(
                            feature_id1       => $fid1,
                            feature_id2       => $fid2,
                            evidence_type_acc => $evidence_type_acc,
                            allow_update      => $allow_update,
                            threshold         => 0,
                        );

                        $self->Print(
                            "Corr ($fc_id): $fname ($fid1) => $fid2\n"
                        );
                        $num_new_corr++;
                    }
                }
            }
        }
    }

    $SIG{'INT'} = $orig_handler;

    $self->Print(
        sprintf 
        "Done, checked %s map pair%s, %s corr%s existed, %s corr%s created.\n",
        $num_checked_maps,
        $num_checked_maps == 1 ? '' : 's',
        $num_corr_existed,
        $num_corr_existed == 1 ? '' : 's',
        $num_new_corr,
        $num_new_corr     == 1 ? '' : 's'
    );

    return 1;
}

# ----------------------------------------------------
sub Print {

=pod

=head2 Print

=head3 NOT For External Use

=over 4

=item * Description

Prints to the log file.

=item * Usage

    $exporter->Print();

=item * Returns



=back

=cut

    my $self = shift;
    print $LOG_FH @_;
}

# ----------------------------------------------------
sub make_feature_sql {
    my ( $self, %args ) = @_;
    my $map_set_ids              = $args{'map_set_ids'}              || [];
    my $ignore_feature_type_accs = $args{'ignore_feature_type_accs'} || [];
    
    my $sql = q[
        select f.feature_id,
               f.feature_name,
               f.feature_type_acc
        from   cmap_feature f,
               cmap_map map
        where  f.map_id=map.map_id
    ];
    
    if ( @$map_set_ids ) {
        $sql .=
          ' and map.map_set_id in (' . join( ',', @$map_set_ids ) . ') ';
    }

    if ( @$ignore_feature_type_accs ) {
        $sql .=
            ' and f.feature_type_acc not in ('
            . join( ',', map { qq['$_'] } @$ignore_feature_type_accs ) 
            . ') ';
    }
    
    return $sql;
}

# ----------------------------------------------------
sub _get_correspondences {
    my ( $self, $map_id1, $map_id2, $evidence_type_acc ) = @_;

    my $sql_object = $self->sql();
    my $corr       = $sql_object->get_feature_correspondence_details(
        cmap_object                 => $self,
        map_id1                     => $map_id1,
        map_id2                     => $map_id2,
        included_evidence_type_accs => [ $evidence_type_acc, ],
    );

    my %correspondences;
    for my $c (@$corr) {
        $correspondences{ $c->{'feature_id1'} }{ $c->{'feature_id2'} } = 1;
        $correspondences{ $c->{'feature_id2'} }{ $c->{'feature_id1'} } = 1;
    }

    return \%correspondences;
}

# ----------------------------------------------------
sub _get_map_ids {
    my ( $self, $map_set_id ) = @_;

    my $sql_object = $self->sql();
    my $maps       = $sql_object->get_maps_simple(
        cmap_object => $self,
        map_set_id  => $map_set_id,
    );
    my @map_ids = map { $_->{'map_id'} } @{ $maps || [] };
    return @map_ids;
}

# ----------------------------------------------------
sub _get_features {
    my $self                 = shift;
    my $args                 = shift;
    my $map_id               = $args->{'map_id'} || [];
    my $ignore_feature_types = $args->{'ignore_feature_types'} || [];
    my $name_regex           = $args->{'name_regex'};
    my $temp_dir             = $args->{'temp_dir'};
    my $cache                = catfile( $temp_dir, $map_id );

    if ( -e $cache ) {
        return retrieve($cache);
    }

    my $sql_object = $self->sql();
    my $features   = $sql_object->get_features_simple(
        cmap_object              => $self,
        map_id                   => $map_id,
        ignore_feature_type_accs => $ignore_feature_types,
    );
    my $aliases = $sql_object->get_feature_aliases(
        cmap_object              => $self,
        map_id                   => $map_id,
        ignore_feature_type_accs => $ignore_feature_types,
    );

    my %return_features;
FEATURE:
    for my $feature ( @{ $features || [] }, @{ $aliases || [] } ) {
        if ( $name_regex && $feature->{'feature_name'} =~ $name_regex ) {
            $feature->{'feature_name'} = $1;
        }

        push @{ $return_features{ lc $feature->{'feature_name'} } },
            [ $feature->{'feature_id'}, $feature->{'feature_type_acc'} ];
    }

    store \%return_features, $cache;

    return \%return_features;
}

1;

# ----------------------------------------------------
# Drive your cart and plow over the bones of the dead.
# William Blake
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2005 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

