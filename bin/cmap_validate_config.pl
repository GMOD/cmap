#!/usr/bin/perl -w

=pod

=head1 NAME

validate_cmap_config.pl

=head1 SYNOPSIS

  validate_cmap_config.pl cmap_config_file.conf

=head1 DESCRIPTION

This script will test a config file to determine if it is valid or not.  It
currenly only tests the individual data_source files and not the global.conf.

Someday, it might help write config files but for now it just flags problems
for you.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

=cut

# -------------------------------------------------------

use strict;
use Config::General;
use Bio::GMOD::CMap::Constants;
use Data::Dumper;

my $conf_file = shift or die "Missing configuration file to validate.\n";

if ( $conf_file eq 'global.conf' ) {
    print "This will not validate the global.conf file.  "
        . "It only validates individual data_source config files.  "
        . "Sorry.\n";
    exit(0);
}

print "Parsing config file '$conf_file.'\n";

my $conf = Config::General->new($conf_file)
    or die "Trouble reading config '$conf_file'";
my %config = $conf->getall
    or die "No configuration options present in '$conf_file'";

# Helper definitions ------------------------------
my %generic_scalar_def = (
    validation_method        => \&validate_scalar,
    print_valididated_method => \&print_validated_scalar,
    print_corrections_method => \&print_corrected_scalar,
);

my %attribute_def = (
    validation_method        => \&validate_array,
    print_valididated_method => \&print_validated_array,
    print_corrections_method => \&print_corrected_array,
    element                  => {
        validation_method        => \&validate_hash,
        print_valididated_method => \&print_validated_hash,
        print_corrections_method => \&print_corrected_hash,
        object                   => {
            name => {
                required => 1,
                %generic_scalar_def,
            },
            value => {
                required => 1,
                %generic_scalar_def,
            },
            is_public => {
                no_report_if_missing => 1,
                %generic_scalar_def,
            },
            display_order => {
                no_report_if_missing => 1,
                %generic_scalar_def,
            },
        },
    },
);
my %xref_def = (
    validation_method        => \&validate_array,
    print_valididated_method => \&print_validated_array,
    print_corrections_method => \&print_corrected_array,
    element                  => {
        only_defined_values      => 1,
        validation_method        => \&validate_hash,
        print_valididated_method => \&print_validated_hash,
        print_corrections_method => \&print_corrected_hash,
        object                   => {
            name => {
                required => 1,
                %generic_scalar_def,
            },
            url => {
                required => 1,
                %generic_scalar_def,
            },
        },
    },
);

# Main Definition --------------------------------------
# Defines all of the configuration options.
my %config_defs = (
    is_enabled => {
        required => 1,
        %generic_scalar_def,
    },
    feature_default_display   => { %generic_scalar_def, },
    disable_cache             => { %generic_scalar_def, },
    comp_menu_order           => { %generic_scalar_def, },
    label_features            => { %generic_scalar_def, },
    default_species_acc       => { %generic_scalar_def, },
    collapse_features         => { %generic_scalar_def, },
    scale_maps                => { %generic_scalar_def, },
    omit_area_boxes           => { %generic_scalar_def, },
    aggregate_correspondences => { %generic_scalar_def, },
    corrs_to_map              => { %generic_scalar_def, },
    evidence_default_display  => { %generic_scalar_def, },
    font_size                 => { %generic_scalar_def, },
    image_size                => { %generic_scalar_def, },
    image_type                => { %generic_scalar_def, },
    stack_maps                => { %generic_scalar_def, },
    clean_view                => { %generic_scalar_def, },
    dotplot_ps => { %generic_scalar_def, option_type => 'integer', },
    min_map_pixel_height =>
        { %generic_scalar_def, option_type => 'integer', },
    min_tick_distance => { %generic_scalar_def, option_type => 'integer', },
    map_shape         => { %generic_scalar_def, },
    allow_remote_data_access       => { %generic_scalar_def, },
    allow_remote_data_manipulation => { %generic_scalar_def, },
    feature_search_field           => { %generic_scalar_def, },
    background_color               => { %generic_scalar_def, },
    slot_background_color          => { %generic_scalar_def, },
    slot_border_color              => { %generic_scalar_def, },
    feature_color                  => { %generic_scalar_def, },
    connecting_line_color          => { %generic_scalar_def, },
    connecting_line_type           => { %generic_scalar_def, },
    connecting_ribbon_color        => { %generic_scalar_def, },
    feature_highlight_bg_color     => { %generic_scalar_def, },
    feature_highlight_fg_color     => { %generic_scalar_def, },
    feature_correspondence_color   => { %generic_scalar_def, },
    map_color                      => { %generic_scalar_def, },
    menu_bgcolor                   => { %generic_scalar_def, },
    menu_bgcolor_tint              => { %generic_scalar_def, },
    menu_ref_bgcolor               => { %generic_scalar_def, },
    menu_ref_bgcolor_tint          => { %generic_scalar_def, },
    map_width          => { %generic_scalar_def, option_type => 'integer', },
    cmap_title         => { %generic_scalar_def, },
    cmap_home_intro    => { %generic_scalar_def, },
    map_viewer_intro   => { %generic_scalar_def, },
    species_info_intro => { %generic_scalar_def, },
    map_set_info_intro => { %generic_scalar_def, },
    feature_type_info_intro   => { %generic_scalar_def, },
    map_type_info_intro       => { %generic_scalar_def, },
    evidence_type_info_intro  => { %generic_scalar_def, },
    feature_search_intro      => { %generic_scalar_def, },
    matrix_title              => { %generic_scalar_def, },
    matrix_intro              => { %generic_scalar_def, },
    link_info_intro           => { %generic_scalar_def, },
    user_pref_cookie_name     => { %generic_scalar_def, },
    cookie_domain             => { %generic_scalar_def, },
    stylesheet                => { %generic_scalar_def, },
    feature_type_details_url  => { %generic_scalar_def, },
    evidence_type_details_url => { %generic_scalar_def, },
    max_search_pages => { %generic_scalar_def, option_type => 'integer', },
    max_child_elements => { %generic_scalar_def, option_type => 'integer', },
    expanded_correspondence_lookup =>
        { deprecated => 1, validation_method => \&deprecated_value, },
    debug => { deprecated => 1, validation_method => \&deprecated_value, },
    number_flanking_positions =>
        { deprecated => 1, validation_method => \&deprecated_value, },
    relational_maps_show_only_correspondences =>
        { deprecated => 1, validation_method => \&deprecated_value, },
    database => {
        required                 => 1,
        only_defined_values      => 1,
        validation_method        => \&validate_hash,
        print_valididated_method => \&print_validated_hash,
        print_corrections_method => \&print_corrected_hash,
        object                   => {
            name        => { %generic_scalar_def, required => 1, },
            datasource  => { %generic_scalar_def, required => 1, },
            user        => { %generic_scalar_def, required => 1, },
            password    => { %generic_scalar_def, required => 0, },
            passwd_file => { %generic_scalar_def, required => 0, },
            is_default =>
                { deprecated => 1, validation_method => \&deprecated_value, },
        },
    },
    scalable => {
        validation_method        => \&validate_hash,
        print_valididated_method => \&print_validated_hash,
        print_corrections_method => \&print_corrected_hash,
    },
    scale_conversion => {
        validation_method        => \&validate_hash,
        print_valididated_method => \&print_validated_hash,
        print_corrections_method => \&print_corrected_hash,
    },
    aggregated_correspondence_colors => {
        validation_method        => \&validate_hash,
        print_valididated_method => \&print_validated_hash,
        print_corrections_method => \&print_corrected_hash,
    },
    feature_type => {
        required                 => 1,
        only_defined_values      => 1,
        validation_method        => \&validate_hash_with_acc,
        print_valididated_method => \&print_validated_hash_with_acc,
        print_corrections_method => \&print_corrected_hash_with_acc,
        accession_name           => 'feature_type_acc',
        object                   => {
            feature_type_accession => {
                deprecated => 1,
                warning =>
                    'Warning: feature_type_accession has been changed to feature_type_acc.',
                validation_method => \&deprecated_value,
            },
            feature_type_acc => { %generic_scalar_def, required => 1, },
            feature_type     => { %generic_scalar_def, required => 1, },
            color            => { %generic_scalar_def, },
            color2           => { %generic_scalar_def, },
            overlap_color    => { %generic_scalar_def, },
            area_code        => { %generic_scalar_def, },
            feature_modification_code => { %generic_scalar_def, },
            required_page_code        => {
                validation_method        => \&validate_array,
                print_valididated_method => \&print_validated_array,
                print_corrections_method => \&print_corrected_array,
                element                  => { %generic_scalar_def, },
            },
            extra_forms => {
                validation_method        => \&validate_array,
                print_valididated_method => \&print_validated_array,
                print_corrections_method => \&print_corrected_array,
                element                  => { %generic_scalar_def, },
            },
            attribute => \%attribute_def,
            xref      => \%xref_def,
            shape     => { %generic_scalar_def, no_validation_hash => 1, },
            min_color_value =>
                { %generic_scalar_def, no_validation_hash => 1, },
            max_color_value =>
                { %generic_scalar_def, no_validation_hash => 1, },
            width => { %generic_scalar_def, no_validation_hash => 1, },
            glyph_overlap => {
                deprecated => 1,
                warning    => 'Warning: glyph_overlap is no longer used.',
                validation_method => \&deprecated_value,
            },
            default_rank =>
                { %generic_scalar_def, option_type => 'integer', },
            drawing_lane =>
                { %generic_scalar_def, option_type => 'integer', },
            drawing_priority =>
                { %generic_scalar_def, option_type => 'integer', },
            feature_default_display => { %generic_scalar_def, },
            gbrowse_class           => { %generic_scalar_def, },
            gbrowse_ftype           => { %generic_scalar_def, },
        },
    },
    map_type => {
        required                 => 1,
        only_defined_values      => 1,
        validation_method        => \&validate_hash_with_acc,
        print_valididated_method => \&print_validated_hash_with_acc,
        print_corrections_method => \&print_corrected_hash_with_acc,
        accession_name           => 'map_type_acc',
        object                   => {
            map_type_accession => {
                deprecated => 1,
                warning =>
                    'Warning: map_type_accession has been changed to map_type_acc.',
                validation_method => \&deprecated_value,
            },
            map_type_acc => {
                required => 1,
                %generic_scalar_def,
            },
            map_type => {
                required => 1,
                %generic_scalar_def,
            },
            color              => { %generic_scalar_def, },
            area_code          => { %generic_scalar_def, },
            required_page_code => {
                validation_method        => \&validate_array,
                print_valididated_method => \&print_validated_array,
                print_corrections_method => \&print_corrected_array,
                element                  => { %generic_scalar_def, },
            },
            extra_forms => {
                validation_method        => \&validate_array,
                print_valididated_method => \&print_validated_array,
                print_corrections_method => \&print_corrected_array,
                element                  => { %generic_scalar_def, },
            },
            attribute         => \%attribute_def,
            xref              => \%xref_def,
            is_relational_map => { %generic_scalar_def, },
            map_units         => {
                no_validation_hash => 1,
                required           => 1,
                %generic_scalar_def,
            },
            display_order =>
                { %generic_scalar_def, option_type => 'integer', },
            shape => {
                no_validation_hash => 1,
                %generic_scalar_def,
            },
            width => { %generic_scalar_def, option_type => 'integer', },
            gbrowse_ftype           => { %generic_scalar_def, },
            feature_default_display => {
                validation_method        => \&validate_hash,
                print_valididated_method => \&print_validated_hash,
                print_corrections_method => \&print_corrected_hash,
            },
            unit_granularity => {
                no_validation_hash => 1,
                required           => 1,
                %generic_scalar_def,
            },
        },
    },
    evidence_type => {
        required                 => 1,
        only_defined_values      => 1,
        validation_method        => \&validate_hash_with_acc,
        print_valididated_method => \&print_validated_hash_with_acc,
        print_corrections_method => \&print_corrected_hash_with_acc,
        accession_name           => 'evidence_type_acc',
        object                   => {
            evidence_type_accession => {
                deprecated => 1,
                warning =>
                    'Warning: evidence_type_accession has been changed to evidence_type_acc.',
                validation_method => \&deprecated_value,
            },
            evidence_type_acc => {
                required => 1,
                %generic_scalar_def,
            },
            evidence_type => {
                required => 1,
                %generic_scalar_def,
            },
            color => { %generic_scalar_def, },
            line_type =>
                { %generic_scalar_def, valid_values => CORR_GLYPHS, },
            ribbon_color => { %generic_scalar_def, },
            attribute    => \%attribute_def,
            xref         => \%xref_def,
            rank       => { %generic_scalar_def, option_type => 'integer', },
            line_style => { %generic_scalar_def, },
            aggregated_correspondence_colors => {
                validation_method        => \&validate_hash,
                print_valididated_method => \&print_validated_hash,
                print_corrections_method => \&print_corrected_hash,
            },
        },
    },
    page_code => {
        only_defined_values      => 1,
        validation_method        => \&validate_hash_with_acc,
        print_valididated_method => \&print_validated_hash_with_acc,
        print_corrections_method => \&print_corrected_hash_with_acc,
        object                   => {
            page_code => {
                required => 1,
                %generic_scalar_def,
            },
        },
    },
    extra_form => {
        only_defined_values      => 1,
        validation_method        => \&validate_hash_with_acc,
        print_valididated_method => \&print_validated_hash_with_acc,
        print_corrections_method => \&print_corrected_hash_with_acc,
        object                   => {
            extra_form => {
                required => 1,
                %generic_scalar_def,
            },
        },
    },
    add_name_correspondence => {
        validation_method        => \&validate_array,
        print_valididated_method => \&print_validated_array,
        print_corrections_method => \&print_corrected_array,
        element                  => { %generic_scalar_def, },
    },
    disallow_name_correspondence => {
        validation_method        => \&validate_array,
        print_valididated_method => \&print_validated_array,
        print_corrections_method => \&print_corrected_array,
        element                  => { %generic_scalar_def, },
    },
    make_corr_feature_divisor =>
        { %generic_scalar_def, option_type => 'integer', },
    map_titles => {
        validation_method        => \&validate_array,
        print_valididated_method => \&print_validated_array,
        print_corrections_method => \&print_corrected_array,
        element                  => { %generic_scalar_def, },
    },
    object_plugin => {
        validation_method        => \&validate_hash,
        print_valididated_method => \&print_validated_hash,
        print_corrections_method => \&print_corrected_hash,
        object                   => {
            map_set_info       => { %generic_scalar_def, },
            map_details        => { %generic_scalar_def, },
            feature            => { %generic_scalar_def, },
            feature_type_info  => { %generic_scalar_def, },
            map_type_info      => { %generic_scalar_def, },
            evidence_type_info => { %generic_scalar_def, },
            species_info       => { %generic_scalar_def, },

        },
    },
    page_object => { %generic_scalar_def, no_report_if_missing => 1 },
    show_intraslot_correspondences => { %generic_scalar_def, },
    split_agg_evespondences        => { %generic_scalar_def, },
    ignore_image_map_sanity        => { %generic_scalar_def, },
);
my %global_config_defs = (
    template_dir     => { %generic_scalar_def, required    => 1, },
    cache_dir        => { %generic_scalar_def, required    => 1, },
    default_db       => { %generic_scalar_def, required    => 1, },
    max_img_dir_size => { %generic_scalar_def, option_type => 'integer', },
    max_img_dir_fullness =>
        { %generic_scalar_def, option_type => 'integer', },
    purge_img_dir_when_full =>
        { %generic_scalar_def, option_type => 'integer', },
    file_age_to_purge => { %generic_scalar_def, option_type => 'integer', },
);

my $print_out_full    = 0;
my $print_corrections = 0;

my %found;
my $whole_valid = 1;

# Check all the config options currently in the file.
# (You can ignore the printing stuff,
#  as it is only partially implemented.)
foreach my $option_name ( sort keys %config ) {
    $found{$option_name} = 1;
    if ( $config_defs{$option_name} ) {
        my $def   = $config_defs{$option_name};
        my $valid = $def->{'validation_method'}(
            option_name   => $option_name,
            def           => $def,
            config_object => $config{$option_name}
        );
        $whole_valid = $whole_valid ? $valid : 0;
        if ( $valid and $print_out_full and not $def->{'deprecated'} ) {
            $def->{'print_valididated_method'}(
                option_name   => $option_name,
                def           => $def,
                config_object => $config{$option_name}
            );
        }
        elsif ( $print_out_full
            or ( !$valid and $print_corrections )
            and not $def->{'deprecated'} )
        {
            $def->{'print_corrections_method'}(
                option_name   => $option_name,
                def           => $def,
                config_object => $config{$option_name}
            );
        }
    }
    else {
        print "Warning! Not a valid option: $option_name\n";
    }
}

# Check for any options that the file missed out on.
foreach my $option_name ( sort keys %config_defs ) {
    next if ( $found{$option_name} );
    if ( $print_out_full or $print_corrections ) {
        $config_defs{$option_name}->{'print_corrections_method'}(
            option_name   => $option_name,
            def           => $config_defs{$option_name},
            config_object => $config{$option_name}
        );
    }
    else {
        if ( $config_defs{$option_name}->{'required'} ) {
            $whole_valid = 0;
            print "INVALID: Missing required entry $option_name\n";
        }
        else {
            print "Missing optional entry for $option_name\n"
                unless $config_defs{$option_name}->{'no_report_if_missing'};
        }
    }
}
if ($whole_valid) {
    print "\nThe config file, $conf_file is valid.\n";
}
else {
    print "\nThe config file, $conf_file is INVALID.\n";
}

# -----------------------------------------------------

sub validate_scalar {

    my %args         = @_;
    my $def          = $args{'def'} || {};
    my $config_value = $args{'config_object'};
    my $option_name  = $args{'option_name'};
    my $parent_name  = $args{'parent_name'} || '';
    my $valid        = 1;
    my $error_start
        = $parent_name
        ? "INVALID <$parent_name> option:"
        : "INVALID:";

    if ( ( ( not defined($config_value) ) or $config_value eq '' )
        and $def->{'required'} )
    {
        $valid = 0;
        print "$error_start $option_name is not defined.\n";
    }
    elsif ( defined($config_value) and $config_value ne '' ) {
        if ( defined($config_value) and ref($config_value) ne '' ) {
            $valid = 0;
            print "$error_start '$option_name' is defined as a "
                . ref($config_value)
                . " when it should be simple text.\n";
        }

        # Check for a predifined set of valid values first
        elsif ( ( not $def->{'no_validation_hash'} )
            and $def->{'valid_values'}
            and not $def->{'valid_values'}{$config_value} )
        {
            $valid = 0;
            print
                "$error_start '$config_value' is not valid for $option_name.\n";
        }

        # Check for a set of valid values in Constants.pm
        elsif ( not $def->{'no_validation_hash'}
            and VALID->{$option_name}
            and not VALID->{$option_name}{$config_value} )
        {
            $valid = 0;
            print
                "$error_start '$config_value' is not valid for $option_name.\n";
        }
        elsif ( $def->{'option_type'}
            and $def->{'option_type'} eq 'integer'
            and $config_value !~ /^\d+$/
            and $config_value ne '' )
        {
            $valid = 0;
            print "$error_start '$config_value' is not an integer which is "
                . "required for $option_name.\n";
        }
    }

    return $valid;
}

sub print_validated_scalar {

    my %args         = @_;
    my $def          = $args{'def'} || {};
    my $config_value = $args{'config_value'};
    my $option_name  = $args{'option_name'};

    print "$option_name $config_value\n\n";

    return 1;
}

sub print_corrected_scalar {

    my %args         = @_;
    my $def          = $args{'def'} || {};
    my $config_value = $args{'config_value'};
    my $option_name  = $args{'option_name'};

    my $question;
    if ( defined($config_value) ) {
        $question
            = "The previous entry had this data:\n" . Dumper($config_value);
    }
    else {
        $question = "There was no entry for $option_name.\n";
    }

    $question .= "What should the value of $option_name be?";

    my $value = show_question(
        question       => $question,
        definition     => $def->{'discription'},
        default        => DEFAULT->{$option_name},
        allow_multiple => 0,
        allow_null     => !( $def->{'required'} ),
        option_type    => $def->{'option_type'},
        valid_hash     => VALID->{$option_name},
    );

    if ( defined($value) ) {
        if ( $value =~ /\s/ ) {
            print "$option_name <<EOF\n$value\nEOF\n\n" if defined($value);
        }
        else {
            print "$option_name $value\n\n" if defined($value);
        }
    }
    return 1;
}

sub validate_hash {

    my %args          = @_;
    my $def           = $args{'def'} || {};
    my $config_object = $args{'config_object'};
    my $option_name   = $args{'option_name'};
    my $parent_name   = $args{'parent_name'} || '';
    my $error_start
        = $parent_name
        ? "INVALID <$parent_name> option:"
        : "INVALID:";

    my $valid = 1;
    if ( !$config_object and $def->{'required'} ) {
        $valid = 0;
        print "$error_start $option_name is missing.\n";
        return 0;
    }
    elsif ( !$config_object ) {
        return 1;
    }
    elsif ( ref($config_object) ne 'HASH' ) {
        $valid = 0;
        print "$error_start '$option_name' is defined as a "
            . ref($config_object)
            . " when it should a hash.\n";
        return 0;
    }

    my %found;
    foreach my $key ( sort keys %{ $def->{'object'} } ) {
        $found{$key} = 1;
        my $inner_def = $def->{'object'}{$key};
        unless (
            $inner_def->{'validation_method'}(
                option_name   => $key,
                def           => $inner_def,
                config_object => $config_object->{$key},
                parent_name   => $option_name,
            )
            )
        {
            $valid = 0;
        }
    }

    if ( $def->{'only_defined_values'} ) {
        foreach my $user_option_name ( sort keys %$config_object ) {
            unless ( $found{$user_option_name} ) {
                $valid = 0;
                print "$error_start $user_option_name is "
                    . "not a option in <$option_name>.\n";
            }
        }
    }

    unless ($valid) {
        print "$error_start $option_name does not have the "
            . "correct options (see above)\n";
    }

    return $valid;
}

sub print_validated_hash {

    my %args          = @_;
    my $def           = $args{'def'} || {};
    my $config_object = $args{'config_object'};
    my $option_name   = $args{'option_name'};

    return 1;
}

sub print_corrected_hash {

    my %args          = @_;
    my $def           = $args{'def'} || {};
    my $config_object = $args{'config_object'};
    my $option_name   = $args{'option_name'};

    return 1;
}

sub validate_hash_with_acc {

    my %args          = @_;
    my $def           = $args{'def'} || {};
    my $config_object = $args{'config_object'};
    my $option_name   = $args{'option_name'};
    my $parent_name   = $args{'parent_name'} || '';
    my $error_start
        = $parent_name
        ? "INVALID <$parent_name> option:"
        : "INVALID:";

    my $valid = 1;
    if ( !$config_object and $def->{'required'} ) {
        $valid = 0;
        print "$error_start $option_name is missing.\n";
        return 0;
    }
    elsif ( ref($config_object) ne 'HASH' ) {
        $valid = 0;
        print "$error_start '$option_name' is defined as a "
            . ref($config_object)
            . " when it should a hash.\n";
        return 0;
    }

    foreach my $acc ( sort keys %$config_object ) {
        if ( ref($config_object) ne 'HASH' ) {
            $valid = 0;
            print "$error_start <$option_name $acc> is defined as a "
                . ref($config_object)
                . " when it should a hash.\n";
            next;
        }
        if ( $def->{'accession_name'} ) {
            unless (
                defined( $config_object->{$acc}{ $def->{'accession_name'} } )
                and $acc eq
                $config_object->{$acc}{ $def->{'accession_name'} } )
            {
                $valid = 0;
                print "$error_start the "
                    . $def->{'accession_name'}
                    . " field in <$option_name $acc> must equal '$acc'\n";
            }
        }
        unless (
            validate_hash(
                option_name   => $option_name,
                def           => $def,
                config_object => $config_object->{$acc},
                parent_name   => "$option_name $acc",
            )
            )
        {
            $valid = 0;
            print "$error_start <$option_name $acc> "
                . "is defined incorrectly (see above)\n\n";
        }

    }

    return $valid;
}

sub print_validated_hash_with_acc {

    my %args          = @_;
    my $def           = $args{'def'} || {};
    my $config_object = $args{'config_object'};
    my $option_name   = $args{'option_name'};

    return 1;
}

sub print_corrected_hash_with_acc {

    my %args          = @_;
    my $def           = $args{'def'} || {};
    my $config_object = $args{'config_object'};
    my $option_name   = $args{'option_name'};

    return 1;
}

sub validate_array {

    my %args          = @_;
    my $def           = $args{'def'} || {};
    my $config_object = $args{'config_object'};
    my $option_name   = $args{'option_name'};
    my $parent_name   = $args{'parent_name'} || '';
    my $error_start
        = $parent_name
        ? "INVALID <$parent_name> option:"
        : "INVALID:";

    my $valid = 1;
    if ( !defined($config_object) and $def->{'required'} ) {
        $valid = 0;
        print "$error_start $option_name is missing.\n";
        return 0;
    }
    elsif ( !defined($config_object) ) {
        $valid = 1;
        return 1;
    }
    my $element_def = $def->{'element'};
    if ( ref($config_object) ne 'ARRAY' ) {
        $valid = $element_def->{'validation_method'}(
            option_name   => $option_name,
            def           => $element_def,
            config_object => $config_object,
            parent_name   => $option_name,
        );
    }
    else {
        foreach my $element ( @{$config_object} ) {
            unless (
                $element_def->{'validation_method'}(
                    option_name   => $option_name,
                    def           => $element_def,
                    config_object => $element,
                    parent_name   => $option_name,
                )
                )
            {
                $valid = 0;
            }
        }
    }

    unless ($valid) {
        print "$error_start one or more values in '$option_name' "
            . "is incorrect (see above)\n";
    }

    return $valid;
}

sub print_validated_array {

    my %args          = @_;
    my $def           = $args{'def'} || {};
    my $config_object = $args{'config_object'};
    my $option_name   = $args{'option_name'};

    return 1;
}

sub print_corrected_array {

    my %args          = @_;
    my $def           = $args{'def'} || {};
    my $config_object = $args{'config_object'};
    my $option_name   = $args{'option_name'};

    return 1;
}

sub deprecated_value {

    my %args          = @_;
    my $def           = $args{'def'} || {};
    my $config_object = $args{'config_object'};
    my $option_name   = $args{'option_name'};

    if ( defined($config_object) ) {
        my $warning = $def->{'warning'}
            || "Warning: $option_name has been deprecated";
        print $warning. "\n";
    }

    return 1;
}

# ----------------------------------------------------
sub show_question {

    my %args           = @_;
    my $question       = $args{'question'} or return;
    my $definition     = $args{'definition'} || '';
    my $default        = $args{'default'};
    my $allow_multiple = $args{'allow_multiple'};
    my $allow_null     = $args{'allow_null'};
    my $option_type    = $args{'option_type'};
    my $validHashRef   = $args{'valid_hash'} || {};

    $question .= "<Default: $default>:" if ( defined $default );
    $question .= "[Optional]:"          if ($allow_null);
    $question .= "[Required]:"          if ( !$allow_null );
    my $answer = undef;
    my $reply;
    my $first_time = 1;
OUTSIDE_LOOP: while ( not defined($answer) ) {
        print "\n";
        print $definition. "\n" if $definition;
        print $question. "\n";
        if ( $first_time and defined($default) ) {
            print "Accept the default ($default)? [Y/n]: ";
            chomp( $reply = <STDIN> );
            if ( $reply =~ /y/i or $reply eq '' ) {
                $answer = $default;
                last OUTSIDE_LOOP;
            }
            else {
                print $question. "\n";
            }
        }
        $first_time = 0;
        if ( %$validHashRef and scalar( keys(%$validHashRef) ) < 7 ) {

            #Menu
            my @options = sort keys(%$validHashRef);
        INSIDE_LOOP: while ( not defined($answer) ) {
                for ( my $i = 0; $i <= $#options; $i++ ) {
                    print "    " . ( $i + 1 ) . ") " . $options[$i] . "\n";
                }
                print "Please select from the above list:\n";
                print "(separate multiple answers by a space)\n"
                    if $allow_multiple;

                chomp( $reply = <STDIN> );

                if ($allow_multiple) {
                    my @selected = split( /\s+/, $reply );
                    foreach my $index (@selected) {
                        if (   !$index
                            or $index !~ /^\d+$/
                            or $index - 1 > $#options )
                        {
                            print "Not a valid response.\n";
                            $answer = undef;
                            next INSIDE_LOOP;
                        }
                        else {
                            $answer .= " " . $options[ $index - 1 ];
                        }
                    }
                }
                else {
                    if (   !$reply
                        or $reply !~ /^\d+$/
                        or $reply - 1 > $#options )
                    {
                        print "$reply is not a valid response.\n";
                        $answer = undef;
                        next INSIDE_LOOP;
                    }
                    else {
                        $answer .= $options[ $reply - 1 ];
                    }
                }
            }
        }
        else {

            chomp( $reply = <STDIN> );

            if ( $allow_null and $reply !~ /\S/ ) {
                $answer = '';
            }
            elsif ( %$validHashRef and not $validHashRef->{$answer} ) {
                print "Your input was not valid\n";
                next OUTSIDE_LOOP;
            }
            elsif ( $option_type
                and $option_type eq 'integer'
                and $reply !~ /^\d+$/ )
            {
                print "Your input was not valid\n";
                next OUTSIDE_LOOP;
            }
            else {
                $answer = $reply;
            }
        }
    }
    return $answer;
}

=pod

=head1 SEE ALSO

L<perl>.

=head1 AUTHOR

Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2005-6 Cold Spring Harbor Laboratory

This module is free software; you can redistribute it and/or modify it under
the terms of the GPL (either version 1, or at your option, any later version)
or the Artistic License 2.0.  Refer to LICENSE for the full license text and to
DISCLAIMER for additional warranty disclaimers.

=cut

