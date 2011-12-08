package Genome::Model::SomaticValidation;

use strict;
use warnings;

use Genome;

class Genome::Model::SomaticValidation {
    is  => 'Genome::Model',
    has => [
        #FIXME probably remove this and fix the (potentional) report issue by having it look at model but fallback on processing profile
        map({
            $_ => {
                via => 'processing_profile',
            }
        } Genome::ProcessingProfile::SomaticValidation->params_for_class),
    ],
    has_optional => [
        snv_variant_list => {
            is => 'Genome::SoftwareResult',
            via => 'inputs', to => 'value', where => [ name => 'snv_variant_list' ],
            is_mutable => 1,
        },
        indel_variant_list => {
            is => 'Genome::SoftwareResult',
            via => 'inputs', to => 'value', where => [ name => 'indel_variant_list' ],
            is_mutable => 1,
        },
        sv_variant_list => {
            is => 'Genome::SoftwareResult',
            via => 'inputs', to => 'value', where => [ name => 'sv_variant_list' ],
            is_mutable => 1,
        },
        reference_sequence_build => {
            is => 'Genome::Model::Build::ReferenceSequence',
            via => 'inputs', to => 'value', where => [ name => 'reference_sequence_build' ],
            is_mutable => 1,
        },
        target_region_set_name => {
            is => 'Text',
            via => 'target_region_set',
            to => 'name',
        },
        target_region_set => {
            is => 'Genome::FeatureList',
            via => 'inputs', to => 'value', where => [ name => 'target_region_set' ],
            is_mutable => 1,
        },
        region_of_interest_set => {
            is => 'Genome::FeatureList',
            via => 'inputs', to => 'value', where => [ name => 'region_of_interest_set' ],
            is_mutable => 1,
        },
        region_of_interest_set_name => {
            is => 'Text',
            via => 'region_of_interest_set',
            to => 'name',
        },
        design_set => {
            is => 'Genome::FeatureList',
            via => 'inputs', to => 'value', where => [ name => 'design_set' ],
            is_mutable => 1,
        },
        tumor_sample => {
            is => 'Genome::Sample',
            via => 'inputs', to => 'value', where => [ name => 'tumor_sample' ],
            is_mutable => 1,
        },
        normal_sample => {
            is => 'Genome::Sample',
            via => 'inputs', to => 'value', where => [ name => 'normal_sample' ],
            is_mutable => 1,
        },
    ],
    has_transient_constant_optional => {
        sequencing_platform => {
            value => undef,
            doc => 'This can be removed once it has been removed from Genome::Model',
            is_deprecated => 1,
        },
    },
};

sub _validate_required_for_start_properties {
    my $self = shift;

    my @missing_required_properties;
    #push @missing_required_properties, '*_variant_list' unless ($self->snv_variant_list || $self->indel_variant_list || $self->sv_variant_list);
    push @missing_required_properties, 'reference_sequence_build' unless ($self->reference_sequence_build);
    push @missing_required_properties, 'tumor_sample' unless ($self->tumor_sample);
#    push @missing_required_properties, 'normal_sample' unless ($self->normal_sample);
    push @missing_required_properties, 'instrument_data' unless (scalar @{[ $self->instrument_data ]} );

    my $tag;
    if (@missing_required_properties) {
        $tag = UR::Object::Tag->create(
            type => 'error',
            properties => \@missing_required_properties,
            desc => 'missing required property',
        );
    }

    return $tag;
}

#limit compatible instrument data check to these samples
sub get_all_possible_samples {
    my $self = shift;

    my @result;
    push @result, $self->tumor_sample if $self->tumor_sample;
    push @result, $self->normal_sample if $self->normal_sample;

    return @result;
}

1;
