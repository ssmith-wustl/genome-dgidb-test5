package Genome::Model::Tools::DetectVariants2::Detector;

use strict;
use warnings;

use File::Copy;
use File::Basename;
use Genome;

class Genome::Model::Tools::DetectVariants2::Detector {
    is => ['Genome::Model::Tools::DetectVariants2::Base'],
    is_abstract => 1,
    has_optional => [
        params => {
            is => 'Text',
            is_input => 1,
            is_output => 1,
            doc => 'The full parameter list coming in from the dispatcher. It is one string before being parsed.',
        },
        version => {
            is => 'String',
            is_input => 1,
            doc => 'The version of the detector to run',
        },
        capture_set_input => {
            is => 'Text',
            doc => 'Location of the file containing the regions of interest (if present, only variants in the set will be reported)',
            is_input => 1,
        },
        snv_params => {
            is => 'Text',
            doc => 'Parameters to pass through to SNV detection',
            is_input => 1,
        },
        indel_params => {
            is => 'Text',
            doc => 'Parameters to pass through to small indel detection',
            is_input => 1,
        },
        sv_params => {
            is => 'Text',
            doc => 'Parameters to pass through to structural variation detection',
            is_input => 1,
        },
        _snv_base_name => {
            is => 'Text',
            default_value => 'snvs.hq',
            is_input => 1,
        },
        snv_output => {
            calculate_from => ['_snv_base_name', 'output_directory'],
            calculate => q{ join("/", $output_directory, $_snv_base_name); },
            doc => "Where the SNV output should be once all work has been done",
            is_output => 1,
        },
        snv_bed_output => {
            calculate_from => ['_snv_base_name', 'output_directory'],
            calculate => q{ join("/", $output_directory, $_snv_base_name) . ".bed"; },
            doc => "Where the SNV output which has been converted to .bed format should be once all work has been done",
            is_output => 1,
        },
        _snv_staging_output => {
            calculate_from => ['_temp_staging_directory', '_snv_base_name'],
            calculate => q{ join("/", $_temp_staging_directory, $_snv_base_name); },
            doc => 'Where the SNV output should be generated (It will be copied to the snv_output in _promote_staged_data().)',
        },
        _indel_base_name => {
            is => 'Text',
            default_value => 'indels.hq',
            is_input => 1,
        },
        indel_output => {
            calculate_from => ['_indel_base_name', 'output_directory'],
            calculate => q{ join("/", $output_directory, $_indel_base_name); },
            is_output => 1,
        },
        indel_bed_output => {
            calculate_from => ['_indel_base_name', 'output_directory'],
            calculate => q{ join("/", $output_directory, $_indel_base_name) . ".bed"; },
            is_output => 1,
        },
        _indel_staging_output => {
            calculate_from => ['_temp_staging_directory', '_indel_base_name'],
            calculate => q{ join("/", $_temp_staging_directory, $_indel_base_name); },
        },
        _sv_base_name => {
            is => 'Text',
            default_value => 'svs.hq',
            is_input => 1,
        },
        sv_output => {
            calculate_from => ['_sv_base_name', 'output_directory'],
            calculate => q{ join("/", $output_directory, $_sv_base_name); },
            is_output => 1,
        },
        _sv_staging_output => {
            calculate_from => ['_temp_staging_directory', '_sv_base_name'],
            calculate => q{ join("/", $_temp_staging_directory, $_sv_base_name); },
        },
        _filtered_indel_base_name => {
            is => 'Text',
            default_value => 'indels_all_sequences.filtered',
            is_input => 1,
        },
        filtered_indel_output => {
            calculate_from => ['_filtered_indel_base_name', 'output_directory'],
            calculate => q{ join("/", $output_directory, $_filtered_indel_base_name); },
            is_output => 1,
        },
        filtered_indel_bed_output => {
            calculate_from => ['_filtered_indel_base_name', 'output_directory'],
            calculate => q{ join("/", $output_directory, $_filtered_indel_base_name) . ".bed"; },
            is_output => 1,
        },
        _filtered_indel_staging_output => {
            calculate_from => ['_temp_staging_directory', '_filtered_indel_base_name'],
            calculate => q{ join("/", $_temp_staging_directory, $_filtered_indel_base_name); },
        },
    ],
    has_constant => [
        variant_types => {
            is => 'ARRAY',
            value => [('snv', 'indel', 'sv')],
        },
        #These can't be turned off--just pass no detector name to skip
        detect_snvs => { value => 1 },
        detect_indels => { value => 1 },
        detect_svs => { value => 1 },
    ],
    doc => 'This is the base class for all detector classes',
};

sub help_brief {
    "The base class for variant detectors.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
This is just an abstract base class for variant detector modules.
EOS
} 

sub help_detail {
    return <<EOS 
This is just an abstract base class for variant detector modules.
EOS
}

sub execute {

    my $self = shift;
    unless($self->_verify_inputs) {
        die $self->error_message('Failed to verify inputs.');
    }

    unless($self->_create_directories) {
        die $self->error_message('Failed to create directories.');
    }

    unless($self->_detect_variants) {
        die $self->error_message('Failed in main execution logic.');
    }

    unless($self->_sort_detector_output){
        die $self->error_message('Failed in _sort_detector_output');
    }

    unless($self->_generate_standard_files) {
        die $self->error_message('Failed to generate standard files from detector-specific files');
    }

    unless($self->_promote_staged_data) {
        die $self->error_message('Failed to promote staged data.');
    }

    return 1;
}

sub _sort_detector_output {
    my $self = shift;

    my @detector_files = glob($self->_temp_staging_directory."/*.hq");

    for my $detector_file (@detector_files){
        my $detector_unsorted_output = $self->_temp_scratch_directory . "/" . basename($detector_file) . ".unsorted";

        Genome::Sys->copy_file($detector_file,$detector_unsorted_output);
        unlink($detector_file);

        my $sort_cmd = Genome::Model::Tools::Bed::ChromSort->create(
            input => $detector_unsorted_output,
            output => $detector_file,
        );

        unless ($sort_cmd->execute()) {
            $self->error_message("Failed to sort detector file " . $detector_unsorted_output);
            return;
        }
    }

    return 1;
}   
