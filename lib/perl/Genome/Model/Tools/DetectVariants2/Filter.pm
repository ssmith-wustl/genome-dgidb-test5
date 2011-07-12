package Genome::Model::Tools::DetectVariants2::Filter;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::DetectVariants2::Filter {
    is  => ['Genome::Model::Tools::DetectVariants2::Base'],
    doc => 'Tools to filter variations that have been detected',
    is_abstract => 1,
    has_input => [
        previous_result_id => {
            is => 'Number',
            doc => 'ID for the software result containing the data which to filter',
        },
        output_directory => {
            is => 'String',
            is_output => 1,
            doc => 'The directory containing the results of filtering',
        },
        params => {
            is => 'String',
            is_optional => 1,
            doc => 'The param string as passed in from the strategy',
        },
        version => {
            is => 'Version',
            is_optional => 1,
            doc => 'The version of the variant filter to use.',
        },
    ],
    has => [
        previous_result => {
            is => 'Genome::Model::Tools::DetectVariants2::Result::Base',
            doc => 'The software result containing the data which to filter',
            id_by => 'previous_result_id',
        },
        detector_name => {
            is => 'String',
            via => 'previous_result',
            to => 'detector_name',
            doc => 'The name of the detector this filter is running below',
        },
        detector_version => {
            is => 'String',
            via => 'previous_result',
            to => 'detector_version',
            doc => 'The version of the detector this filter is running below',
        },
        detector_params => {
            is => 'String',
            via => 'previous_result',
            to => 'detector_params',
            is_optional => 1,
            doc => 'The params of the detector this filter is running below',
        },
        input_directory => {
            is => 'String',
            via => 'previous_result',
            to => 'output_dir',
            doc => 'The data on which to operate--the result of a detector or previous filter',
        },
        aligned_reads_input => {
            is => 'Text',
            via => 'previous_result',
            to => 'aligned_reads',
            doc => 'Location of the aligned reads input file',
            is_input => 1, #SHOULD NOT ACTUALLY BE AN INPUT
            is_optional => 1,
        },
        reference_build_id => {
            is => 'Text',
            via => 'previous_result',
            to => 'reference_build_id',
            doc => 'The build-id of a reference sequence build',
            is_input => 1, #SHOULD NOT ACTUALLY BE AN INPUT
            is_optional => 1,
        },
        control_aligned_reads_input => {
            is => 'Text',
            via => 'previous_result',
            to => 'control_aligned_reads',
            doc => 'Location of the control aligned reads file to which the input aligned reads file should be compared (for detectors which can utilize a control)',
            is_optional => 1,
            is_input => 0,
        },
    ],
    has_constant => [
        _variant_type => {
            type => 'String',
            default => 'variant_type',
            doc => 'variant type that this module operates on, overload this in submodules accordingly',
        },
    ],
    has_optional_transient => [
        _validate_output_offset => {
            type => 'Integer',
            default => 0,
            doc => 'The offset added to the number of lines in input  when compared to the number of lines in output',
        },
        _result => {
            is => 'Genome::Model::Tools::DetectVariants2::Result::Filter',
            doc => 'SoftwareResult for the run of this filter',
            id_by => "result_id",
            is_output => 1,
        },
        result_id => {
            is => 'Number',
            is_output => 1,
        },
        _detector_directory => {
            is => 'Text',
            doc => 'Directory of the original detector run that is being filtered',
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

# Take all parameters from the "params" property and store them in individual properties for the class.
# resolve_class_and_params_for_argv will check for us to make sure all the property names are valid
sub _process_params { 
    my $self = shift;
    if ($self->params) {
        my @param_list = split(" ", $self->params);
        my($cmd_class,$params) = $self->class->resolve_class_and_params_for_argv(@param_list);

        # For each parameter set in params... use the class properties to assign the values
        for my $param_name (keys %$params) {
            $self->$param_name($params->{$param_name});
        }
    }

    return 1;
}


sub shortcut {
    my $self = shift;

    #try to get using the lock in order to wait here in shortcut if another process is creating this alignment result
    my ($params) = $self->params_for_result;
    my $result = Genome::Model::Tools::DetectVariants2::Result::Filter->get_with_lock(%$params);
    unless($result) {
        $self->status_message('No existing result found.');
        return;
    }

    $self->_result($result);
    $self->status_message('Using existing result ' . $result->__display_name__);
    $self->_link_to_result;

    return 1;
}

sub execute {
    my $self = shift;

    $self->_process_params;

    my ($params) = $self->params_for_result;
    my $result = Genome::Model::Tools::DetectVariants2::Result::Filter->get_or_create(%$params, _instance => $self);

    unless($result) {
        die $self->error_message('Failed to create generate result!');
    }

    if(-e $self->output_directory) {
        unless(readlink($self->output_directory) eq $result->output_dir) {
            die $self->error_message('Existing output directory ' . $self->output_directory . ' points to a different location!');
        }
    }

    $self->_result($result);
    $self->status_message('Generated result.');
    $self->_link_to_result;

    return 1;
}

sub _generate_result {
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

    my $previous_result = $self->previous_result;
    unless($previous_result) {
        $self->error_message('No previous result found for basis of running this filter.');
        return;
    }

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

#check that the bed file counts are reasonable given the input
sub _check_bed_file_counts {
    my $self = shift;
    my $total_input = shift;
    my $hq_output_file = $self->output_directory."/".$self->_variant_type.".hq.bed";
    my $lq_output_file = $self->output_directory."/".$self->_variant_type.".lq.bed";

    my $total_output = $self->line_count($hq_output_file) + $self->line_count($lq_output_file);

    my $offset = $self->_validate_output_offset;
    $total_input += $offset;
    
    unless(($total_input - $total_output) == 0){
        die $self->error_message("Total lines of bed-formatted output did not match total input lines. Input lines (including an offset of $offset): $total_input \t output lines: $total_output");
    }

    return 1;
}

#check that the natively formatted file matches expectation
sub _check_native_file_counts {
    my $self = shift;
    my $total_input = shift;

    my $hq_output_file = $self->output_directory."/".$self->_variant_type.".hq.bed";
    my $detector_style_file = $self->output_directory."/".$self->_variant_type.".hq";

    my $total_output = $self->line_count($hq_output_file);
    my $detector_style_output = $self->line_count($detector_style_file);
    unless(($total_output - $detector_style_output) == 0){
        die $self->error_message("Total lines of detector-style output did not match total output lines. Output lines: $total_output \t Detector-style output lines: $detector_style_output");
    }

    return 1;
}


sub _check_file_counts {
    my $self = shift;

    my $input_file = $self->input_directory."/".$self->_variant_type.".hq.bed";
    my $total_input = $self->line_count($input_file);

    return ($self->_check_bed_file_counts($total_input) && $self->_check_native_file_counts($total_input));
}

sub has_version {

    ## No Filter version checking is currently done.
    ## Overloading this in an individual filter module
    ## will enable version checking for that module.

    return 1;
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
    # If there is an hq_bed_file (bed format) and not a detector file, generate a detector file
    if( $hq_bed_file && not $hq_detector_file){
        $self->_convert_bed_to_detector($original_detector_file,$hq_bed_output,$hq_detector_output);
        unless($lq_detector_file){
            $self->_convert_bed_to_detector($original_detector_file,$lq_bed_output,$lq_detector_output);
        }
    }
    # If there is an hq_detector_file and not an hq_bed_file, generate an hq_bed_file
    elsif ($hq_detector_file && not $hq_bed_file) {
        $self->_create_bed_file($hq_detector_output,$hq_bed_output);
        unless($lq_bed_file){
            $self->_create_bed_file($lq_detector_output,$lq_bed_output);
        }
    }
    # If there is neither an hq_detector_file nor an hq_bed_file, explode
    elsif ((not $hq_detector_file) &&( not $hq_bed_file)) {
        die $self->error_message("Could not locate output file of any type for this filter.");
    }

    return 1;
}

# If the filter has no bed formatted output file, but does have a detector-style file, generate the bed formatt
sub _create_bed_file {
    my $self = shift;
    die $self->error_message(" gmt detect-variants filter->_create_bed_file must be defined by a subclass if it is to be used" );
}

sub _convert_bed_to_detector {
    my $self = shift;
    my $detector_file = shift;  #$self->detector_style_input;
    my $bed_file = shift;       #$self->source;
    my $output = shift;         #$self->output;

    my $ofh = Genome::Sys->open_file_for_writing($output);
    my $detector_fh = Genome::Sys->open_file_for_reading($detector_file);
    my $bed_fh = Genome::Sys->open_file_for_reading($bed_file);

    #This cycles through the bed and original detector file, looking for intersecting lines 
    # to dump into the detector style output

    OUTER: while(my $line = $bed_fh->getline){
        chomp $line;
        my ($chr,$start,$stop,$refvar,@data) = split "\t", $line;
        my ($ref,$var) = split "/", $refvar;
        my $scan=undef;
        while(my $dline = $detector_fh->getline){
            chomp $dline;
            my ($dchr,$dpos,$dref,$dvar) = split "\t", $dline;
            if(($chr eq $dchr)&&($stop == $dpos)&&($ref eq $dref)&&($var eq $dvar)){
                print $ofh $dline."\n";
                next OUTER;
            }
        }
    }

    $bed_fh->close;
    $ofh->close;
    $detector_fh->close;
    return 1;
}


sub params_for_result {
    my $self = shift;

    my $previous_result = $self->previous_result;
    my $previous_filter_strategy;
    if($previous_result->can('previous_filter_strategy') and $previous_result->previous_filter_strategy) {
        $previous_filter_strategy = $previous_result->previous_filter_strategy;
    }
    if($previous_result->can('filter_name')) {
        if($previous_filter_strategy) {
            $previous_filter_strategy .= ' then ';
        } else {
            $previous_filter_strategy = '';
        }
        $previous_filter_strategy .= join(' ', $previous_result->filter_name, $previous_result->filter_version);
        if($previous_result->filter_params) {
            $previous_filter_strategy .= ' [' . $previous_result->filter_params . ']';
        }
    }

    my %params = (
        detector_name => $self->detector_name,
        detector_params => $self->detector_params,
        detector_version => $self->detector_version,
        filter_name => $self->class,
        filter_params => $self->params,
        filter_version => $self->version,
        previous_filter_strategy => $previous_filter_strategy,
        aligned_reads => $self->aligned_reads_input,
        control_aligned_reads => $self->control_aligned_reads_input,
        reference_build_id => $self->reference_build_id,
        region_of_interest_id => $previous_result->region_of_interest_id,
        test_name => $ENV{GENOME_SOFTWARE_RESULT_TEST_NAME} || undef,
        chromosome_list => $previous_result->chromosome_list,
    );

    return \%params;
}

sub _link_to_result {
    my $self = shift;

    my $result = $self->_result;
    return unless $result;

    unless(-e $self->output_directory) {
        Genome::Sys->create_symlink($result->output_dir, $self->output_directory);
    }

    my $previous_result = $self->previous_result;
    my @users = $previous_result->users;
    unless(grep($_->user eq $result, @users)) {
        $previous_result->add_user(user => $result, label => 'uses');
    }

    return 1;
}

sub detector_directory {
    my $self = shift;

    my $previous_result = $self->previous_result;

    unless($self->_detector_directory) {
        my $detector_result = Genome::Model::Tools::DetectVariants2::Result->get(
            detector_name => $self->detector_name,
            detector_params => $self->detector_params,
            detector_version => $self->detector_version,
            aligned_reads => $self->aligned_reads_input,
            control_aligned_reads => $self->control_aligned_reads_input,
            reference_build_id => $self->reference_build_id,
            region_of_interest_id => $previous_result->region_of_interest_id,
            test_name => $ENV{GENOME_SOFTWARE_RESULT_TEST_NAME} || undef,
            chromosome_list => $previous_result->chromosome_list,
        );

        unless($detector_result) {
            die $self->error_message('Could not find original detector result');
        }

        $self->_detector_directory($detector_result->output_dir);
    }

    return $self->_detector_directory;
}


1;
