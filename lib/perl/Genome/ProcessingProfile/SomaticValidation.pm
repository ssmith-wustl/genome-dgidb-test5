package Genome::ProcessingProfile::SomaticValidation;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::SomaticValidation {
    is => 'Genome::ProcessingProfile',
    has_param_optional => [
        alignment_strategy => {
            is => 'Text',
            is_many => 0,
            doc => 'Strategy to be used to align',
        },
        snv_detection_strategy => {
            is => "Text",
            is_many => 0,
            doc => "Strategy to be used to detect snvs.",
        },
        indel_detection_strategy => {
            is => "Text",
            is_many => 0,
            doc => "Strategy to be used to detect indels.",
        },
        sv_detection_strategy => {
            is => "Text",
            is_many => 0,
            doc => "Strategy to be used to detect svs.",
        },
        cnv_detection_strategy => {
            is => "Text",
            is_many => 0,
            doc => "Strategy to be used to detect cnvs.",
        },
        identify_dnp_proportion => {
            is => 'Number',
            doc => 'The proportion of reads supporting a DNP to make the call',
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

    #TODO Make optional, support other types
    my ($snv_variant_list) = glob($model->snv_variant_list->output_dir . '/snvs.hq.bed');
    unless($snv_variant_list) {
        $self->error_message('Failed to get a snv variant list for this build!');
        die $self->error_message;
    }

    my $data_directory = $build->data_directory;
    unless ($data_directory) {
        $self->error_message("Failed to get a data_directory for this build!");
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
        snv_variant_list => $snv_variant_list,
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
