package Bio::GMOD::CMap::Admin::MakeCorrespondences;
# vim: set ft=perl:

# $Id: MakeCorrespondences.pm,v 1.42 2004-08-04 04:26:06 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.42 $)[-1];

use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Admin;
use Bio::GMOD::CMap::Utils qw[ next_number ];
use base 'Bio::GMOD::CMap';
use Data::Dumper;

# ----------------------------------------------------
sub make_name_correspondences {
    my ( $self, %args )        = @_;
    my @map_set_ids            = @{ $args{'map_set_ids'}        || [] };
    my @skip_feature_type_aids    
        = @{ $args{'skip_feature_type_aids'} || [] };
    my $evidence_type_aid      = $args{'evidence_type_aid'} or 
                                 return 'No evidence type';
    $LOG_FH                    = $args{'log_fh'} || \*STDOUT;
    my $name_regex             = $args{'name_regex'} ||'';
    my $quiet                  = $args{'quiet'};
    my $allow_update           = $args{'allow_update'};
    my $db                     = $self->db;
    my $admin                  = Bio::GMOD::CMap::Admin->new(
	    config      => $self->config,
        data_source => $self->data_source,
    );
    $self->Print("Making name-based correspondences.\n") unless $quiet;

    my $expanded_correspondence_lookup 
        = $self->config_data('expanded_correspondence_lookup'); 
    #
    # Normally we only create name-based correspondences between 
    # features of the same type, but this reads the configuration
    # file and adds in other allowed feature types.
    #
print STDERR "$expanded_correspondence_lookup MAKE \n";
    my %add_name_correspondences;
    for my $line ( $self->config_data('add_name_correspondence') ) {
        my @feature_type_aids = split /\s+/, $line;

        for my $i ( 0 .. $#feature_type_aids ) {
            my $ft1    = $feature_type_aids[ $i ] or next;

            for my $j ( $i+1 .. $#feature_type_aids ) {
                my $ft2 = $feature_type_aids[ $j ];
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
    for my $ft_id1 ( keys %add_name_correspondences ) {
        for my $ft_id2 ( keys %{ $add_name_correspondences{ $ft_id1 } } ) {
            for my $ft_id3 ( keys %{ $add_name_correspondences{ $ft_id2 } } ) {
                next if $ft_id1 == $ft_id3;
                $add_name_correspondences{ $ft_id1 }{ $ft_id3 } = 1;
            }
        }
    }

    my %disallow_name_correspondence;
    for my $line ( $self->config_data('disallow_name_correspondence') ) {
        my @feature_types = split /\s+/, $line;
        for my $ft ( @feature_types ) {
            my $ft_id =$self->feature_type_data($ft)
                 or next;
            $disallow_name_correspondence{ $ft_id } = 1;
        }
    }

    my $feature_sql = q[
        select f.feature_id,
               f.feature_name,
               f.feature_type_accession as feature_type_aid,
               map.map_id,
               ms.map_set_id
        from   cmap_feature f,
               cmap_map map,
               cmap_map_set ms
        where  f.map_id=map.map_id
        and    map.map_set_id=ms.map_set_id
    ];

    my $alias_sql = q[
        select fa.feature_id,
               fa.alias
        from   cmap_feature f,
               cmap_feature_alias fa,
               cmap_map map,
               cmap_map_set ms
        where  f.feature_id=fa.feature_id
        and    f.map_id=map.map_id
        and    map.map_set_id=ms.map_set_id
    ];

    if ( @map_set_ids ) {
        for ( $feature_sql, $alias_sql ) {
            $_ .= 'and map.map_set_id in (' .
                join( ', ', @map_set_ids ) .
            ') ';
        }
    }

    if ( @skip_feature_type_aids ) {
        for ( $feature_sql, $alias_sql ) {
            $_ .= "and f.feature_type_accession not in ('" .
                join( "', '", @skip_feature_type_aids ) .
            "')";
        }
    }
    print STDERR "Getting Features\n";
    my $features = $db->selectall_hashref( $feature_sql, 'feature_id' );
    my $aliases  = $db->selectall_arrayref( $alias_sql );

    print STDERR "Parsing Features\n";
    my %alias_lookup;
    for my $a ( @$aliases ) {
        push @{ $alias_lookup{ $a->[0] } }, $a->[1];
    }   

    my %names = ();
    for my $f ( values %$features ) {
        for my $name ( 
            $f->{'feature_name'}, 
            @{ $alias_lookup{ $f->{'feature_id'} } || [] }
        ) {
            next unless $name;
            if ($name_regex and $name=~/$name_regex/){
                $name=$1;
            }
            $names{ lc $name }{ $f->{'feature_id'} } = 0;
        }
    }

    my $corr;
    if ($allow_update){
	$corr = $db->selectall_hashref(
        q[
            select fc.feature_id1,
                   fc.feature_id2,
                   fc.feature_correspondence_id
            from   cmap_feature_correspondence fc,
                   cmap_correspondence_evidence ce
            where  fc.feature_correspondence_id=ce.feature_correspondence_id
            and    ce.evidence_type_accession=?
                
        ],
        'feature_correspondence_id',
        {},
        ( $evidence_type_aid )
	);
    }

    my %corr = ();
    if ($allow_update){
	for my $c ( values %$corr ) {
	    $corr{ $c->{'feature_id1'} }{ $c->{'feature_id2'} } = 
		$c->{'feature_correspondence_id'};
	    
	    $corr{ $c->{'feature_id2'} }{ $c->{'feature_id1'} } = 
		$c->{'feature_correspondence_id'};
	}
    }
    print STDERR "Inserting Features\n";

    for my $name ( keys %names ) {
        my @feature_ids = keys %{ $names{ $name } };

        #
        # Only one feature has this name, so skip.
        #
        next if scalar @feature_ids == 1;

        my %done;
        for my $i ( 0..$#feature_ids ) {
            my $fid1 = $feature_ids[ $i ]; 
            my $f1   = $features->{ $fid1 };

            for my $j ( $i+1..$#feature_ids ) {
                my $fid2 = $feature_ids[ $j ]; 
                next if $fid1 == $fid2;          # same feature
                next if $done{ $fid1 }{ $fid2 }; # already processed

                my $f2 = $features->{ $fid2 };

                #
                # Check feature types.
                #
                unless ( 
                    $f1->{'feature_type_aid'} == $f2->{'feature_type_aid'} 
                ) {
                    next unless $add_name_correspondences
                        { $f1->{'feature_type_aid'} }
                        { $f2->{'feature_type_aid'} }
                    ;
                }
                next if     
                    $f1->{'feature_type_id'} == $f2->{'feature_type_id'} &&
                    $disallow_name_correspondence{ $f1->{'feature_type_id'} }
                ;

                my $s = "b/w '$f1->{'feature_name'}' ".
                        "and '$f2->{'feature_name'}.'\n";

                #
                # Check if we already know that a correspondence based
                # on our evidence already exists.
                #
                if ( $allow_update and $corr{ $fid1 }{ $fid2 } ) {
                    $self->Print("Correspondence exists $s") unless $quiet;
                    next;
                }
                else {
                    my $fc_id = $admin->add_feature_correspondence_to_list( 
                        feature_id1       => $f1->{'feature_id'},
                        feature_id2       => $f2->{'feature_id'},
                        evidence_type_aid => $evidence_type_aid,
		                allow_update      => $allow_update,
		                expanded_correspondence_lookup      
                            => $expanded_correspondence_lookup,
                    ) or return $self->error( $admin->error );

                    $admin->insert_feature_correspondence_if_gt(1000);

                    if ($allow_update){
                        $corr{ $fid1 }{ $fid2 } = $fc_id;
                        $corr{ $fid2 }{ $fid1 } = $fc_id;
                    }
                    $done{ $fid1 }{ $fid2 } = 1;
                    $done{ $fid2 }{ $fid1 } = 1;
                }
            }
        }
    }
    $admin->insert_feature_correspondence_if_gt(0);
    $self->Print("Done.\n") unless $quiet;

    return 1;
}

# ----------------------------------------------------
sub Print {
    my $self = shift;
    print $LOG_FH @_;
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

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2002-4 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
