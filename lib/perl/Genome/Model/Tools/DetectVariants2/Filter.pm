package Genome::Model::Tools::DetectVariants2::Filter;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::DetectVariants2::Filter {
    is  => ['Genome::Model::Tools::DetectVariants2::Base'],
    doc => 'Tools to filter variations that have been detected',
    is_abstract => 1,
    has => [
        input_directory => {
           is => 'String',
           is_input => 1,
           doc => 'The directory to filter',
        },
        output_directory => {
            is => 'String',
            is_input => 1,
            is_output => 1,
            doc => 'The directory containing the results of filtering',
        },
        detector_directory => {
            is => 'String',
            is_input => 1,
            is_output => 1,
            is_optional => 1,
            doc => 'The directory containing the results of filtering',
        },
        params => {
            is => 'String',
            is_input => 1,
            is_optional => 1,
            doc => 'The param string as passed in from the strategy',
        },
        version => {
            is => 'Version',
            is_input => 1,
            is_optional => 1,
            doc => 'The version of the variant filter to use.',
        },
    ],
    has_constant => [
        _variant_type => {
            type => 'String',
            default => 'variant_type',
            doc => 'variant type that this module operates on, overload this in submodules accordingly',
        },
    ],
};

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants2 filter ...
EOS
}

sub help_detail {
    return <<EOS 
Tools to run variant detector filters with a common API
EOS
}


sub execute {
    my $self = shift;
       
    unless($self->_validate_input) {
        die $self->error_message('Failed to validate input.');
    }
    unless($self->_create_directories) {
        die $self->error_message('Failed to create directories.');
    }
    unless($self->_filter_variants){
        die $self->error_message("Failed to run _filter_variants");
    }
    unless($self->_promote_staged_data) {
        die $self->error_message('Failed to promote staged data.');
    }
    unless($self->_generate_standard_output){
        die $self->error_message("Failed to generate standard output");
    }
    unless($self->_validate_output){
        die $self->error_message("Failed to validate output");
    }
    return 1;
}

sub _filter_variants {
    die "This function should be overloaded by the filter when implemented."
}

sub _validate_input {
    my $self = shift;

    my $input_directory = $self->input_directory;
    unless (Genome::Sys->check_for_path_existence($input_directory)) {
        $self->error_message("input directory $input_directory does not exist");
        return;
    }

    return 1;
}

sub _validate_output {
    my $self = shift;
    unless(-d $self->output_directory){
        die $self->error_message("Could not validate the existence of output_directory");
    }
    my @files = glob($self->output_directory."/*");
    my ($hq,$lq);
    ($hq) = grep /[svs|snvs|indels]\.hq\.bed/, @files;
    ($lq) = grep /[svs|snvs|indels]\.lq\.bed/, @files;
    unless($hq && $lq){
        die $self->error_message("Could not locate either or both hq and lq files");
    }
    unless($self->_check_file_counts) {
        die $self->error_message("Could not validate line counts of output files.");
    }

    return 1;
}

sub _check_file_counts {
    my $self = shift;

    my $input_file = $self->input_directory."/".$self->_variant_type.".hq.bed";
    my $hq_output_file = $self->output_directory."/".$self->_variant_type.".hq.bed";
    my $lq_output_file = $self->output_directory."/".$self->_variant_type.".lq.bed";
    my $detector_style_file = $self->output_directory."/".$self->_variant_type.".hq";
    my $total_input = $self->line_count($input_file);
    my $total_output = $self->line_count($hq_output_file) + $self->line_count($lq_output_file);
    unless(($total_input - $total_output) == 0){
        die $self->error_message("Total lines of bed-formatted output did not match total input lines. Input lines: $total_input \t output lines: $total_output");
    }
    my $detector_style_output = $self->line_count($detector_style_file) + $self->line_count($lq_output_file);
    unless(($total_input - $detector_style_output) == 0){
        die $self->error_message("Total lines of detector-style output did not match total input lines. Input lines: $total_input \t output lines: $detector_style_output");
    }

    return 1;
}

sub has_version {
   
    ## No Filter version checking is currently done.
    ## Overloading this in an individual filter module
    ## will enable version checking for that module.

    return 1;
}

# This are crazy and ugly, but are just a very temporary solution until we start handing strategies down to detectors and filters
# For now this method is unnecessary because we are only accounting for one level of filtering. Later this will change.
sub _get_detector_version {
    my $self = shift;
    my $detector_output_directory = $self->detector_directory;

    my @subdirs = split("/", $detector_output_directory);
    my $detector_subdir = $subdirs[-1];

    my ($variant_type, $detector_name, $detector_version, $detector_params) = split("-", $detector_subdir);
    
    return $detector_version;
}

sub _get_detector_parameters {
    my $self = shift;
    my $detector_output_directory = $self->detector_directory;

    my @subdirs = split("/", $detector_output_directory);
    my $detector_subdir = $subdirs[-1];

    my ($variant_type, $detector_name, $detector_version, $detector_params) = split("-", $detector_subdir);
    
    return $detector_params;
}

# Look for Detector formatted output and bed formatted output
sub _generate_standard_output {
    my $self = shift;
    my $detector_output = $self->output_directory."/".$self->_variant_type.".hq";
    my $filter_output = $self->output_directory."/".$self->_variant_type.".hq.bed";
    my $detector_file = -e $detector_output;
    my $filter_file = -e $filter_output;

    # If there is a filter_file (bed format) and not a detector file, generate a detector file
    if( $filter_file && not $detector_file){
        $self->_create_detector_file($filter_file,$detector_file);
    } 
    # If there is a detector_file and not a filter_file, generate a filter_file
    elsif ($detector_file && not $filter_file) {
        $self->_create_filter_file($detector_file,$filter_file);
    } 
    # If there is neither a detector_file nor a filter_file, explode
    elsif ((not $detector_file) &&( not $filter_file)) {
        die $self->error_message("Could not locate output file of any type for this filter.");
    }

    return 1;
}

# If the filter has a bed formatted output file, but no detector-style file, generate the detector-style
sub _create_detector_file {
    my $self = shift;
    my $filter_file = shift;
    my $detector_file = shift;
    my $original_detector_file = $self->input_directory."/".$self->_variant_type.".hq";
    unless(Genome::Model::Tools::Joinx::Intersect->execute( input_file_a => $original_detector_file, input_file_b => $filter_file, output_file => $detector_file )) {
        die $self->error_message("Failed to execute gmt joinx intersect in order to generate detector-style output file");
    }        
    unless(-e $detector_file){
        die $self->error_message("Failed to create a detector-style output file");
    }

    return 1;
}

# If the filter has no bed formatted output file, but does have a detector-style file, generate the bed formatt
sub _create_filter_file {
    my $self = shift;
    my $filter_file = shift;
    my $detector_file = shift;

    die $self->error_message("This functionality has not yet been implemented.");

    return 1;
}

1;
