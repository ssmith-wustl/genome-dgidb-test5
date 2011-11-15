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
};

# this is a comprimise to maintain compatibility with SomaticVariation
# while not using tumor_model/normal_model naming scheme on inputs
sub tumor_model { $_[0]->tumor_reference_alignment->model }
sub normal_model { $_[0]->normal_reference_alignment->model }

sub post_allocation_initialization {
    my $self = shift;

    my @result_subfolders;
    for my $subdir ('variants') {
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
    $version =~ s/^v//;
    if ($version and $file_format){
        $path = $self->data_directory."/$dataset.v$version.$file_format";
    }
    return $path;
}

sub tumor_bam {
    my $self = shift;

    my $tumor_build = $self->tumor_reference_alignment;
    my $tumor_bam = $tumor_build->whole_rmdup_bam_file;
    unless ($tumor_bam){
        die $self->error_message("No whole_rmdup_bam file found for tumor build!");
    }
    return $tumor_bam;
}

sub normal_bam {
    my $self = shift;

    my $normal_build = $self->normal_reference_alignment;
    my $normal_bam = $normal_build->whole_rmdup_bam_file;
    unless ($normal_bam){
        die $self->error_message("No whole_rmdup_bam file found for normal build!");
    }
    return $normal_bam;
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
