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
        region_of_interest => {
            is => 'Genome::FeatureList',
            doc => '',
            id_by => 'region_of_interest_id',
        },
        region_of_interest_id => {
            is => 'Text',
            doc => 'FeatureList for the region of interest (if present, only variants in the set will be reported)',
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
    has_optional_transient => [
        _result => {
            is => 'UR::Object',
            doc => 'SoftwareResult for the run of this detector',
            id_by => "_result_id",
            id_class_by => '_result_class',
            is_output => 1,
        },
        _result_class => {
            is => 'Text',
            is_output => 1,
        },
        _result_id => {
            is => 'Number',
            is_output => 1,
        },
    ],
    has_constant => [
        #These can't be turned off--just pass no detector name to skip
        detect_snvs => { value => 1 },
        detect_indels => { value => 1 },
        detect_svs => { value => 1 },
    ],
    has_param => [
        lsf_queue => {
            default => 'apipe',
        },
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

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    for my $input ('aligned_reads_input', 'control_aligned_reads_input') {
        if($self->$input) {
            my $canonical_path = Cwd::abs_path($self->$input);
            unless($canonical_path) {
                die $self->error_message('Failed to resolve real path to ' . $input);
            }

            $self->$input($canonical_path);
        }
    }

    return $self;
}

sub shortcut {
    my $self = shift;

    $self->_resolve_output_directory;

    #try to get using the lock in order to wait here in shortcut if another process is creating this alignment result
    my ($params) = $self->params_for_result;
    my $result = Genome::Model::Tools::DetectVariants2::Result->get_with_lock(%$params);
    unless($result) {
        $self->status_message('No existing result found.');
        return;
    }

    $self->_result($result);
    $self->status_message('Using existing result ' . $result->__display_name__);
    $self->_link_output_directory_to_result;

    return 1;
}

sub _resolve_output_directory {
    my $self = shift;
    #Subclasses override this
    return 1;
}


sub execute {
    my $self = shift;

    $self->_resolve_output_directory;

    if(-e $self->output_directory) {
        die $self->error_message('Output directory already exists!');
    }

    my ($params) = $self->params_for_result;
    my $result = Genome::Model::Tools::DetectVariants2::Result->get_or_create(%$params, _instance => $self);

    unless($result) {
        die $self->error_message('Failed to create generate result!');
    }

    $self->_result($result);
    $self->status_message('Generated result.');
    $self->_link_output_directory_to_result;

    return 1;
}

sub _generate_result {
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

        unless(rename($detector_file,$detector_unsorted_output)) {
            $self->error_message('Failed to move ' . $detector_file . ' to ' . $detector_unsorted_output . ' for sorting!');
            return;
        }

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


sub params_for_result {
    my $self = shift;

    my %params = (
        detector_name => $self->class,
        detector_params => $self->params,
        detector_version => $self->version,
        aligned_reads => $self->aligned_reads_input,
        control_aligned_reads => $self->control_aligned_reads_input,
        reference_build_id => $self->reference_build_id,
        region_of_interest_id => $self->region_of_interest_id,
        test_name => $ENV{GENOME_SOFTWARE_RESULT_TEST_NAME} || undef,
        chromosome_list => undef,
    );

    return \%params;
}

sub _link_output_directory_to_result {
    my $self = shift;

    my $result = $self->_result;
    return unless $result;

    unless(-e $self->output_directory) {
        Genome::Sys->create_symlink($result->output_dir, $self->output_directory);
    }

    return 1;
}

# Given a line of output from this detector, parse and return the chromosome, position, reference, and variant
# The position must be converted to the same position that a bed would consider the STOP position
# This is used for intersecting the detector specific file with the bed version
# Override this method in each detector if the format varies from this
#TODO clean all of this up. It is usually/should be based on logic from Genome::Model::Tools::Bed::Convert logic in process_source... 
# this should be smarter about using that work ... perhaps process_source should call a method that just parses one line, and this method can be replaced by a call to that instead
sub parse_line_for_bed_intersection {
    my $class = shift;
    my $line = shift;

    unless ($line) {
        die $class->error_message("No line provided to parse_line_for_bed_intersection");
    }

    my ($chromosome, $position, $reference, $variant) = split "\t",  $line;

    unless (defined $chromosome && defined $position && defined $reference && defined $variant) {
        die $class->error_message("Could not get chromosome, position, reference, or variant for line: $line");
    }

    return [$chromosome, $position, $reference, $variant];
}

1;
