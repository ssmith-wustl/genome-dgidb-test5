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
    ]
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


1;
