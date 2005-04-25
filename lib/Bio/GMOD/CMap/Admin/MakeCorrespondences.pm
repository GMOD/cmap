package Bio::GMOD::CMap::Admin::MakeCorrespondences;

# vim: set ft=perl:

# $Id: MakeCorrespondences.pm,v 1.48 2005-04-25 17:14:08 mwz444 Exp $

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
$VERSION = (qw$Revision: 1.48 $)[-1];

use Bio::GMOD::CMap;
use Bio::GMOD::CMap::Admin;
use Bio::GMOD::CMap::Utils qw[ next_number ];
use base 'Bio::GMOD::CMap';
use Data::Dumper;

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
        evidence_type_aid => $evidence_type_aid,
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

=item - evidence_type_aid

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
    #my @map_set_ids            = @{ $args{'map_set_ids'}            || [] };
    my @from_map_set_ids       = @{ $args{'from_map_set_ids'}            || [] };
    my @to_map_set_ids         = @{ $args{'to_map_set_ids'}            || [] };
    my @skip_feature_type_aids = @{ $args{'skip_feature_type_aids'} || [] };
    my $evidence_type_aid      = $args{'evidence_type_aid'}
      or return 'No evidence type';
    $LOG_FH = $args{'log_fh'} || \*STDOUT;
    my $name_regex   = $args{'name_regex'} || '';
    my $quiet        = $args{'quiet'};
    my $allow_update = $args{'allow_update'};
    my $db           = $self->db;
    my $admin        = Bio::GMOD::CMap::Admin->new(
        config      => $self->config,
        data_source => $self->data_source,
    );
    $self->Print("Making name-based correspondences.\n") unless $quiet;

    #
    # Normally we only create name-based correspondences between
    # features of the same type, but this reads the configuration
    # file and adds in other allowed feature types.
    #
    my %add_name_correspondences;
    for my $line ( $self->config_data('add_name_correspondence') ) {
        my @feature_type_aids = split /\s+/, $line;

        for my $i ( 0 .. $#feature_type_aids ) {
            my $ft1 = $feature_type_aids[$i] or next;

            for my $j ( $i + 1 .. $#feature_type_aids ) {
                my $ft2 = $feature_type_aids[$j];
                next if $ft1 eq $ft2;

                $add_name_correspondences{$ft1}{$ft2} = 1;
                $add_name_correspondences{$ft2}{$ft1} = 1;
            }
        }
    }

    #
    # Make sure they're all accounted for (e.g., possibly defined
    # on multiple lines, as of old).
    #
    for my $ft_id1 ( keys %add_name_correspondences ) {
        for my $ft_id2 ( keys %{ $add_name_correspondences{$ft_id1} } ) {
            for my $ft_id3 ( keys %{ $add_name_correspondences{$ft_id2} } ) {
                next if $ft_id1 == $ft_id3;
                $add_name_correspondences{$ft_id1}{$ft_id3} = 1;
            }
        }
    }

    my %disallow_name_correspondence;
    for my $line ( $self->config_data('disallow_name_correspondence') ) {
        my @feature_types = split /\s+/, $line;
        for my $ft (@feature_types) {
            my $ft_id = $self->feature_type_data($ft)
              or next;
            $disallow_name_correspondence{$ft_id} = 1;
        }
    }

    my $from_feature_sql = q[
        select f.feature_id,
               f.feature_name,
               f.feature_type_accession as feature_type_aid
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
    my $to_feature_sql = $from_feature_sql;

    if (@from_map_set_ids) {
        for ( $from_feature_sql ) {
            $_ .= 'and map.map_set_id in (' . join( ', ', @from_map_set_ids ) . ') ';
        }
    }
    if (@to_map_set_ids) {
        for ( $to_feature_sql  ) {
            $_ .= 'and map.map_set_id in (' . join( ', ', @to_map_set_ids ) . ') ';
        }
    }
    if (@from_map_set_ids or @to_map_set_ids) {
        for ( $alias_sql ) {
            $_ .= 'and map.map_set_id in (' . join( ', ', @from_map_set_ids,@to_map_set_ids ) . ') ';
        }
    }

    if (@skip_feature_type_aids) {
        for ( $from_feature_sql, $alias_sql, $to_feature_sql ) {
            $_ .=
              "and f.feature_type_accession not in ('"
              . join( "', '", @skip_feature_type_aids ) . "')";
        }
    }
    print STDERR "Getting Features\n";
    my $from_features = $db->selectall_hashref( $from_feature_sql, 'feature_id' );
    my $to_features   = $db->selectall_hashref( $to_feature_sql, 'feature_id' );
    my $aliases    = $db->selectall_arrayref($alias_sql);

    print STDERR "Parsing Features\n";
    my %alias_lookup;
    for my $a (@$aliases) {
        push @{ $alias_lookup{ $a->[0] } }, $a->[1];
    }

    my %from_name_to_ids = ();
    for my $f ( values %$from_features ) {
        for my $name ( $f->{'feature_name'},
            @{ $alias_lookup{ $f->{'feature_id'} } || [] } )
        {
            next unless $name;
            if ( $name_regex and $name =~ /$name_regex/ ) {
                $name = $1;
            }
            push @{$from_name_to_ids{ lc $name }}, $f->{'feature_id'};
        }
    }

    my %to_name_to_ids = ();
    for my $f ( values %$to_features ) {
        for my $name ( $f->{'feature_name'},
            @{ $alias_lookup{ $f->{'feature_id'} } || [] } )
        {
            next unless $name;
            if ( $name_regex and $name =~ /$name_regex/ ) {
                $name = $1;
            }
            push @{$to_name_to_ids{ lc $name }}, $f->{'feature_id'};
        }
    }

    my $corr;
    if ($allow_update) {
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
            ($evidence_type_aid)
        );
    }

    my %corr = ();
    if ($allow_update) {
        for my $c ( values %$corr ) {
            $corr{ $c->{'feature_id1'} }{ $c->{'feature_id2'} } =
              $c->{'feature_correspondence_id'};

            $corr{ $c->{'feature_id2'} }{ $c->{'feature_id1'} } =
              $c->{'feature_correspondence_id'};
        }
    }
    print STDERR "Inserting Features\n";

    for my $from_name ( keys %from_name_to_ids ) {
        #
        # Skip unless there is a matching name in %to_name_to_ids
        #
        next unless ($to_name_to_ids{$from_name} and @{$to_name_to_ids{$from_name}});

        my %done;
        for my $i ( 0 .. $#{$from_name_to_ids{$from_name}} ) {
            my $fid1 = $from_name_to_ids{$from_name}->[$i];
            my $f1   = $from_features->{$fid1};

            for my $j ( 0 .. $#{$to_name_to_ids{$from_name}} ) {
                my $fid2 = $to_name_to_ids{$from_name}->[$j];
                next if $fid1 == $fid2;         # same feature
                next if $done{$fid1}{$fid2};    # already processed

                my $f2 = $to_features->{$fid2};

                #
                # Check feature types.
                #
                unless (
                    $f1->{'feature_type_aid'} == $f2->{'feature_type_aid'} )
                {
                    next
                      unless
                      $add_name_correspondences{ $f1->{'feature_type_aid'} }
                      { $f2->{'feature_type_aid'} };
                }
                next
                  if $f1->{'feature_type_id'} == $f2->{'feature_type_id'}
                  && $disallow_name_correspondence{ $f1->{'feature_type_id'} };

                my $s =
                    "b/w '$f1->{'feature_name'}' "
                  . "and '$f2->{'feature_name'}.'\n";

                #
                # Check if we already know that a correspondence based
                # on our evidence already exists.
                #
                if ( $allow_update and $corr{$fid1}{$fid2} ) {
                    $self->Print("Correspondence exists $s") unless $quiet;
                    next;
                }
                else {
                    my $fc_id = $admin->add_feature_correspondence_to_list(
                        feature_id1       => $f1->{'feature_id'},
                        feature_id2       => $f2->{'feature_id'},
                        evidence_type_aid => $evidence_type_aid,
                        allow_update      => $allow_update,
                      )
                      or return $self->error( $admin->error );

                    $admin->insert_feature_correspondence_if_gt(1000);

                    if ($allow_update) {
                        $corr{$fid1}{$fid2} = $fc_id;
                        $corr{$fid2}{$fid1} = $fc_id;
                    }
                    $done{$fid1}{$fid2} = 1;
                    $done{$fid2}{$fid1} = 1;
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

