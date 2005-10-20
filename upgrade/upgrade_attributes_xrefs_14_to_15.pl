#!/usr/bin/perl -w

=head1 NAME

upgrade_attributes_xrefs_14_to_15.pl - Check and modify any attributes or xrefs in
the database that refer to an obsolete variable name.

=head1 SYNOPSIS

upgrade_attributes_xrefs_14_to_15.pl

Use this to check if a tab delimited file will import correctly.

Options:

    -h|--help|-?      Print brief help
    -d|--data_source  The CMap data source to use
    -c|--commit       Have the program make the suggested changes
    -q|--quiet        Only prints neccessary output
    -v|--verbose      Verbose output

=head1 DESCRIPTION

Use this to check if there are attributes in the db that need to be modified to
work with the version 0.15 code. 

Using the --commit flag will cause the script to implement the required changes.

=cut

use strict;
use warnings;
use Data::Dumper;

use Bio::GMOD::CMap;
use Pod::Usage;
use Getopt::Long;

my ( $help, $data_source, $commit_changes, $verbose, $quiet );
GetOptions(
    'help|h|?'        => \$help,
    'd|data_source:s' => \$data_source,
    'commit|c'        => \$commit_changes,
    'verbose|v'       => \$verbose,
    'quiet|q'         => \$quiet,
    )
    or pod2usage;

pod2usage(0) if $help;

pod2usage("No Datasource provided") unless ($data_source);

my $cmap_object = Bio::GMOD::CMap->new( data_source => $data_source );

print STDERR "Checking Attributes in Datasource: $data_source\n" unless ($quiet);

my $sql_object = $cmap_object->sql();

# Attribute
my $attributes = $sql_object->get_attributes(
    cmap_object => $cmap_object,
    get_all     => 1
);

if ( @{ $attributes || [] } ) {
    for my $attribute ( @{ $attributes || [] } ) {
        print STDERR 'Considering attribute value:'
            . $attribute->{'attribute_value'} . "\n"
            if ($verbose);
        my $new_value = _update_variables_in_string(
            string      => $attribute->{'attribute_value'},
            object_type => $attribute->{'object_type'}
        );
        if ($new_value) {
            if ($commit_changes) {
                print "Changing attribute id "
                    . $attribute->{'attribute_id'}
                    . " to: $new_value\n";
                $sql_object->update_attribute(
                    cmap_object     => $cmap_object,
                    attribute_id    => $attribute->{'attribute_id'},
                    attribute_value => $new_value,
                );

            }
            else {
                print "attribute:\t"
                    . $attribute->{'attribute_id'}
                    . "\t$new_value\n";
            }
        }

    }
}
else {
    print "No attributes found in data source, $data_source\n";
}

# Xref
print STDERR "Checking Xrefs in Datasource: $data_source\n" unless ($quiet);
my $xrefs = $sql_object->get_xrefs(
    cmap_object => $cmap_object,
    get_all     => 1
);

if ( @{ $xrefs || [] } ) {
    for my $xref ( @{ $xrefs || [] } ) {
        print STDERR 'Considering xref url:' . $xref->{'xref_url'} . "\n"
            if ($verbose);
        my $new_url = _update_variables_in_string(
            string      => $xref->{'xref_url'},
            object_type => $xref->{'object_type'}
        );
        if ($new_url) {
            if ($commit_changes) {
                print "Changing xref id "
                    . $xref->{'xref_id'}
                    . " to: $new_url\n";
                $sql_object->update_xref(
                    cmap_object => $cmap_object,
                    xref_id     => $xref->{'xref_id'},
                    xref_url    => $new_url,
                );

            }
            else {
                print "xref:\t" . $xref->{'xref_id'} . "\t$new_url\n";
            }
        }

    }
}
else {
    print "No xrefs found in data source, $data_source\n";
}

# ---------------------------------
# if the string is modified, then return the new string otherwise
# return undef.
sub _update_variables_in_string {
    my %args                  = @_;
    my $string_to_deconstruct = $args{'string'};
    my $object_type           = $args{'object_type'};
    my $reconstructed_value;

    my @string_segments    = split( /(\[%|%])/, $string_to_deconstruct );
    my $inside_tt_brackets = 0;
    my $string_modified    = 0;
SEGMENT:
    for my $segment (@string_segments) {
        if ( $segment eq '[%' ) {
            $inside_tt_brackets = 1;
            $reconstructed_value .= $segment;
            next SEGMENT;
        }
        if ( $segment eq '%]' ) {
            $inside_tt_brackets = 0;
            $reconstructed_value .= $segment;
            next SEGMENT;
        }
        unless ($inside_tt_brackets) {
            $reconstructed_value .= $segment;
            next SEGMENT;
        }

        # We are now inside the brackets

        # Substitutions
        if ( $segment =~ s/_type_accession/_type_acc/g ) {
            $string_modified = 1;
        }
        if ( $segment =~ s/_aid/_acc/g ) {
            $string_modified = 1;
        }
        if ( $segment =~ s/\.short_name/.map_set_short_name/g ) {
            $string_modified = 1;
        }
        if ( $segment =~ s/\.common_name/.species_common_name/g ) {
            $string_modified = 1;
        }
        if ( $segment =~ s/\.species_name/.species_common_name/g ) {
            $string_modified = 1;
        }
        if ( $segment =~ s/\.full_name/.species_full_name/g ) {
            $string_modified = 1;
        }
        if ( $segment =~ s/\.full_name/.species_full_name/g ) {
            $string_modified = 1;
        }

        # ambiguous words
        my $found_ambiguous_word  = 0;
        my %ambiguous_word_lookup = (
            'start_position' =>
                { 'map' => 'map_start', 'feature' => 'feature_start' },
            'stop_position' =>
                { 'map' => 'map_stop', 'feature' => 'feature_stop' },
            'accession_id' => {
                'species'                 => 'species_acc',
                'map_set'                 => 'map_set_acc',
                'map'                     => 'map_acc',
                'feature'                 => 'feature_acc',
                'feature_correspondence'  => 'feature_correspondence_acc',
                'correspondence_evidence' => 'correspondence_evidence_acc',
            },
        );

        for my $word ( keys %ambiguous_word_lookup ) {
            if ( $ambiguous_word_lookup{$word}->{$object_type} ) {
                my $replacement
                    = $ambiguous_word_lookup{$word}->{$object_type};
                if ( $segment =~ s/\.$word/.$replacement/g ) {
                    $string_modified = 1;
                }
            }
        }

        # Obsolete values
        my %obsolete_words
            = ( 'can_be_reference_map' => 'is_relational_map', );
        for my $word (keys %obsolete_words){
            if ($segment=~/$word/){
                print qq[ WARNING: "$word" has been deprecated.  ];
                if ($obsolete_words{$word}){
                    print qq[ Please see "$obsolete_words{$word}" to possibly replace the functionality.];
                }
                print qq[\n];
            }
        }

        $reconstructed_value .= $segment;

    }
    return $string_modified ? $reconstructed_value : undef;
}

