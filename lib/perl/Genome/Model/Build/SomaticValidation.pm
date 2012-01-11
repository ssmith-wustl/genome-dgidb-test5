package Genome::Model::Build::SomaticValidation;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::SomaticValidation {
    is => 'Genome::Model::Build',
    has_optional => [
        reference_sequence_build => {
            is => 'Genome::Model::Build::ReferenceSequence', via => 'inputs', to => 'value', where => [name => 'reference_sequence_build'],
        },
        annotation_build => {
            is => 'Genome::Model::Build::ImportedAnnotation',
            via => 'inputs', to => 'value', where => [ name => 'annotation_build' ],
            is_mutable => 1,
        },
        previously_discovered_variations_build => {
            is => 'Genome::Model::Build::ImportedVariationList',
            via => 'inputs', to => 'value', where => [ name => 'previously_discovered_variations_build' ],
            is_mutable => 1,
            doc => 'build of variants to screen out from consideration (such as from dbSNP)',
        },
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
        alignment_strategy => {
            is => 'Text',
            via => 'model',
        },
        snv_detection_strategy => {
            is => 'Text',
            via => 'model',
        },
        sv_detection_strategy => {
            is => 'Text',
            via => 'model',
        },
        indel_detection_strategy => {
            is => 'Text',
            via => 'model',
        },
        cnv_detection_strategy => {
            is => 'Text',
            via => 'model',
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

        merged_alignment_result => {
            is => 'Genome::InstrumentData::AlignmentResult::Merged',
            via => 'result_users',
            to => 'software_result',
            where => [label => 'merged_alignment'],
        },
        control_merged_alignment_result => {
            is => 'Genome::InstrumentData::AlignmentResult::Merged',
            via => 'result_users',
            to => 'software_result',
            where => [label => 'control_merged_alignment'],
        },

        coverage_stats_result => {
            is => 'Genome::InstrumentData::AlignmentResult::Merged',
            via => 'result_users',
            to => 'software_result',
            where => [label => 'coverage_stats_tumor'],
        },
        control_coverage_stats_result  => {
            is => 'Genome::InstrumentData::AlignmentResult::Merged',
            via => 'result_users',
            to => 'software_result',
            where => [label => 'coverage_stats_normal'],
        },

        loh_version => {
            via => 'model',
        },
        tiering_version => {
            via => 'model',
        },
    ],
};

sub post_allocation_initialization {
    my $self = shift;

    my @result_subfolders;
    for my $subdir ('alignments', 'variants', 'coverage') {
        push @result_subfolders, $self->data_directory."/".$subdir;
    }

    for my $subdir (@result_subfolders){
        Genome::Sys->create_directory($subdir) unless -d $subdir;
    }

    for my $variant_type ('snv', 'indel', 'sv') {
        my $property = $variant_type . '_variant_list';
        my $variant_list = $self->$property;

        if($variant_list) {
            $variant_list->add_user(label => 'uses', user => $self);
        }
    }

    return 1;
}

sub data_set_path {
    my ($self, $dataset, $version, $file_format) = @_;
    my $path;
    
    if ($version and $file_format) {
        $version =~ s/^v//;
        $path = $self->data_directory."/$dataset.v$version.$file_format";
    }
    elsif ($file_format) {
        # example $b->data_set_path('alignments/tumor/','','flagstat')
        my @paths = glob($self->data_directory."/$dataset".'*.'.$file_format);
        return unless @paths == 1;
        $path = $paths[0];
    }
    return $path if -e $path;
    return;
}

sub tumor_bam {
    my $self = shift;

    my $result = $self->merged_alignment_result;
    return unless $result;
    return $result->merged_alignment_bam_path;
}

sub normal_bam {
    my $self = shift;

    my $result = $self->control_merged_alignment_result;
    return unless $result;
    return $result->merged_alignment_bam_path;
}

sub tumor_bam_flagstat_file {
    return shift->_bam_flagstat_file('tumor');
}

sub normal_bam_flagstat_file {
    return shift->_bam_flagstat_file('normal');
}

sub _bam_flagstat_file {
    my ($self, $type) = @_;
    my $method = $type . '_bam';
    my $flag_file = $self->$method . '.flagstat';
    return $flag_file if -e $flag_file;
    return;
}

sub workflow_name {
    my $self = shift;
    return $self->build_id . ' Somatic Variant Validation Pipeline';
}

sub calculate_estimated_kb_usage {
    my $self = shift;

    # FIXME find out how much we probably really need
    return 15_728_640;
}

sub files_ignored_by_diff {
    return qw(
        build.xml
    );
}

sub dirs_ignored_by_diff {
    return qw(
        logs/
        reports/
    );
}

sub validate_for_start_methods {
    my $self = shift;
    my @methods = $self->SUPER::validate_for_start_methods;
    push @methods, qw(
        _validate_required_for_start_properties
    );
    return @methods;
}

sub _validate_required_for_start_properties {
    my $model_method = $_[0]->model->class . '::_validate_required_for_start_properties';
    return (\&$model_method)->(@_);
}

1;
