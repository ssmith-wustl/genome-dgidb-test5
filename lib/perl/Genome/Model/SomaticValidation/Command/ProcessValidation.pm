package Genome::Model::SomaticValidation::Command::ProcessValidation;

use strict;
use warnings;

use Genome;
use Cwd qw(abs_path);

class Genome::Model::SomaticValidation::Command::ProcessValidation {
    is => 'Command',
    has_input => [
        filtered_validation_file    => { is => 'Text', doc => "bed file of variants passing filter", is_optional => 0 },
        min_coverage                => { is => 'Text', doc => "Minimum coverage to call a site", is_optional => 1 },
        variants_file               => { is => 'Text', doc => "File of variants to report on", },
        output_file                 => { is => 'Text', doc => "Output file for validation results", is_output => 1 },
        output_plot                 => { is => 'Boolean', doc => "Optional plot of variant allele frequencies", is_optional => 1, },
        build_id => {
            is => 'Integer',
            is_output => 1,
            doc => 'build id of SomaticValidation model',
        },
    ],
    has => [
        build => {
            is => 'Genome::Model::Build::SomaticValidation',
            id_by => 'build_id',
        },
    ],
    has_param => [
        lsf_resource => {
            default_value => 'rusage[tmp=2000] select[tmp>2000]',
        },
    ],
};

sub execute {
    my $self = shift;
    my $build = $self->build;

    my @validation_original_file = glob($build->data_directory . '/variants/snv/varscan-somatic-validation*/snvs.hq.validation'); 
    unless(scalar @validation_original_file == 1) {
        die $self->error_message('Unable to determine the original varscan file to use for ProcessValidation run');
    }

    my $filtered_bed = $self->filtered_validation_file;
    my $filtered_original_file = Cwd::abs_path($filtered_bed);
    $filtered_original_file =~ s/\.bed$//;
    unless(Genome::Sys->check_for_path_existence($filtered_original_file)) {
        die $self->error_message('Failed to find original filtered file to use for ProcessValidation run.');
    }

    my $process_validation = Genome::Model::Tools::Varscan::ProcessValidation->create(
        validation_file => $validation_original_file[0],
        filtered_validation_file => $filtered_original_file,
        variants_file => $self->variants_file,
        output_file => $self->output_file,
        output_plot => $self->output_plot,
    );

    unless($process_validation->execute) {
        die $self->error_message('Execution of ProcessValidation failed');
    }

    return 1;
}

1;