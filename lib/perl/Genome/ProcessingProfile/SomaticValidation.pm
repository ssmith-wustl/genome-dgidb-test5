package Genome::ProcessingProfile::SomaticValidation;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::SomaticValidation {
    is => 'Genome::ProcessingProfile',
    has_param_optional => [
        snv_detection_strategy => {
            is => "Text",
            is_many => 0,
            is_optional =>1,
            doc => "Strategy to be used to detect snvs.",
        },
        indel_detection_strategy => {
            is => "Text",
            is_many => 0,
            is_optional =>1,
            doc => "Strategy to be used to detect indels.",
        },
        sv_detection_strategy => {
            is => "Text",
            is_many => 0,
            is_optional =>1,
            doc => "Strategy to be used to detect svs.",
        },
        cnv_detection_strategy => {
            is => "Text",
            is_many => 0,
            is_optional =>1,
            doc => "Strategy to be used to detect cnvs.",
        },
        minimum_coverage => {
            is => 'Number', doc => 'minimum coverage to call a site (in process-validation step)',
        },
        output_plot => {
            is => 'Boolean', doc => 'include output plot in final results',
        },
    ],
};

sub _resolve_workflow_for_build {
    my $self = shift;
    my $build = shift;

    my $operation = Workflow::Operation->create_from_xml(__FILE__ . '.xml');

    my $log_directory = $build->log_directory;
    $operation->log_dir($log_directory);
    $operation->name($build->workflow_name);

    return $operation;
}


sub _map_workflow_inputs {
    my $self = shift;
    my $build = shift;

    my @inputs = ();

    # Verify the somatic model
    my $model = $build->model;
    unless ($model) {
        $self->error_message("Failed to get a model for this build!");
        die $self->error_message;
    }

    my $tumor_build = $build->tumor_build;
    my $normal_build = $build->normal_build;

    unless ($tumor_build) {
        $self->error_message("Failed to get a tumor_build associated with this somatic capture build!");
        die $self->error_message;
    }

    unless ($normal_build) {
        $self->error_message("Failed to get a normal_build associated with this somatic capture build!");
        die $self->error_message;
    }

    my $variant_list = $model->variant_list_file;
    unless($variant_list) {
        $self->error_message('Failed to get a variant list for this build!');
        die $self->error_message;
    }

    my $data_directory = $build->data_directory;
    unless ($data_directory) {
        $self->error_message("Failed to get a data_directory for this build!");
        die $self->error_message;
    }

    my $tumor_bam = $tumor_build->whole_rmdup_bam_file;
    unless (-e $tumor_bam) {
        $self->error_message("Tumor bam file $tumor_bam does not exist!");
        die $self->error_message;
    }

    my $normal_bam = $normal_build->whole_rmdup_bam_file;
    unless (-e $normal_bam) {
        $self->error_message("Normal bam file $normal_bam does not exist!");
        die $self->error_message;
    }

    my $reference_sequence_build = $model->reference_sequence_build;
    unless($reference_sequence_build) {
        $self->error_message("Failed to get a reference sequence build for this model!");
        die $self->error_message;
    }
    my $reference_fasta = $reference_sequence_build->full_consensus_path('fa');
    unless(Genome::Sys->check_for_path_existence($reference_fasta)) {
        $self->error_message('Could not find reference FASTA for specified reference sequence.');
        die $self->error_message;
    }

    push @inputs,
        build_id => $build->id,
        variant_list => $variant_list,
        ;

    my %default_filenames = $self->default_filenames;
    for my $param (keys %default_filenames) {
        my $default_filename = $default_filenames{$param};
        push @inputs,
            $param => join('/', $data_directory, $default_filename);
    }

    push @inputs,
        minimum_coverage => (defined $self->minimum_coverage ? $self->minimum_coverage : 0),
        output_plot => (defined $self->output_plot ? $self->output_plot : 1),
        ;


    return @inputs;
}

sub default_filenames{
    my $self = shift;

    my %default_filenames = (
        targeted_snv_validation => 'targeted.snvs.validation',
        snv_list_file => 'variant_list.snvs', 
    );

    return %default_filenames;
}

1;
