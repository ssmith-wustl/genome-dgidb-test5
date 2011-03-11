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
    has_transient_optional => [
        _validate_output_offset => {
            type => 'Integer',
            default => 0,
            doc => 'The offset added to the number of lines in input  when compared to the number of lines in output',
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
    $DB::single=1;
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
    # Add the offset to the input (some filters output more or less lines than they take as input)
    my $offset = $self->_validate_output_offset;
    $total_input += $offset;

    my $total_output = $self->line_count($hq_output_file) + $self->line_count($lq_output_file);
    unless(($total_input - $total_output) == 0){
        die $self->error_message("Total lines of bed-formatted output did not match total input lines. Input lines (including an offset of $offset): $total_input \t output lines: $total_output");
    }
    #my $detector_style_output = $self->line_count($detector_style_file) + $self->line_count($lq_output_file);
    #unless(($total_input - $detector_style_output) == 0){
    #    die $self->error_message("Total lines of detector-style output did not match total input lines. Input lines: $total_input \t output lines: $detector_style_output");
    #}

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

sub _get_detector_info {
    my $self = shift;
    my $detector_directory = $self->detector_directory;

    my @subdirs = split("/",$detector_directory);
    my $detector_subdir = $subdirs[-1];
    my ($detector_name, $detector_version, $detector_params, $other) = split("-", $detector_subdir);

    # FIXME this is really ugly and should be fixed promptly. "varscan-somatic" is misinterpreted in the detector directory path.
    if($detector_version eq 'somatic'){
        $detector_name = 'varscan';
        $detector_version = $detector_params;
        $detector_params = $other;
    }
    return ($detector_name, $detector_version, $detector_params);
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
    my $hq_detector_output = $self->output_directory."/".$self->_variant_type.".hq";
    my $hq_bed_output = $self->output_directory."/".$self->_variant_type.".hq.bed";
    my $lq_detector_output = $self->output_directory."/".$self->_variant_type.".lq";
    my $lq_bed_output = $self->output_directory."/".$self->_variant_type.".lq.bed";
    my $original_detector_file = $self->input_directory."/".$self->_variant_type.".hq";

    my $hq_detector_file = -e $hq_detector_output;
    my $hq_bed_file = -e $hq_bed_output;
    my $lq_detector_file = -e $lq_detector_output;
    my $lq_bed_file = -e $lq_bed_output;

    # If there is a hq_bed_file (bed format) and not a detector file, generate a detector file
    if( $hq_bed_file && not $hq_detector_file){
        $self->_create_detector_file($hq_bed_output,$original_detector_file);
        unless($lq_detector_file){
            $self->_create_detector_file($lq_bed_output,$original_detector_file);
        }
    } 
    # If there is a hq_detector_file and not a hq_bed_file, generate a hq_bed_file
    elsif ($hq_detector_file && not $hq_bed_file) {
        $self->_create_bed_file($hq_detector_file,$hq_bed_file);
        unless($lq_bed_file){
            $self->_create_bed_file($lq_detector_file,$lq_bed_file);
        }
    } 
    # If there is neither a hq_detector_file nor a hq_bed_file, explode
    elsif ((not $hq_detector_file) &&( not $hq_bed_file)) {
        die $self->error_message("Could not locate output file of any type for this filter.");
    }

    return 1;
}

# If the filter has a bed formatted output file, but no detector-style file, generate the detector-style
sub _create_detector_file {
    my $self = shift;
    my $bed_file = shift;
    my $detector_file = shift;
    my ($detector_name) = $self->_get_detector_info;
    my $variant_type = $self->_variant_type;
    $variant_type =~ s/s$//;
    my $module_base = 'Genome::Model::Tools::Bed::Convert';
    my @supported_variant_types = ('indel','snv'); 
    unless(grep($variant_type,@supported_variant_types)){
        die $self->error_message("Filter has encountered an unsupported variant type: ".$variant_type);
    }
    my $converter = join('::', $module_base, ucfirst($variant_type), ucfirst($detector_name) . 'ToBed'); 
    $self->status_message(" About to call converter: $converter");
    eval{
        $converter->__meta__;
    };
    if($@){
        die $self->error_message("Could not interpret the string: $converter");
    }
    my @bed = split "/",$bed_file;
    my (undef,$quality,undef) = split /\./,$bed[-1];
    my $output_file = $self->output_directory."/".$variant_type."s.".$quality;
    my $result = $converter->create(
        source => $bed_file,
        output => $output_file, 
        detector_style_input => $detector_file,
        reference_sequence_input => $self->reference_sequence_input,
    );
     
    unless($result->convert_bed_to_detector) {
        $self->error_message('Failed to execute '.$converter);
        return;
    }

    unless(-e $detector_file){
        die $self->error_message("Failed to create a detector-style output file");
    }

    return 1;
}

# If the filter has no bed formatted output file, but does have a detector-style file, generate the bed formatt
sub _create_bed_file {
    my $self = shift;
    my $filter_file = shift;
    my $detector_file = shift;
    my $original_detector_file = $self->input_directory."/".$self->_variant_type.".hq";



    unless(-e $detector_file){
        die $self->error_message("Failed to create a detector-style output file");
    }

    return 1;
}

1;
