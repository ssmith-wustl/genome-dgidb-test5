package Genome::Model::Tools::DetectVariants2::Base;

use strict;
use warnings;

use Clone qw/clone/;
use Data::Compare;
use Data::Dumper;
use File::Path;
use Genome;

class Genome::Model::Tools::DetectVariants2::Base {
    is => ['Genome::Command::Base'],
    has => [
        reference_build_id => {
            is => 'Text',
            doc => 'The build-id of a reference sequence build',
            is_input => 1,
        },
        reference_sequence_input => {
            calculate_from => ['reference_build_id'],
            calculate => q{ Genome::Model::Build->get($reference_build_id)->full_consensus_path('fa') },
            doc => 'Location of the reference sequence file',
        },
        aligned_reads_input => {
            is => 'Text',
            doc => 'Location of the aligned reads input file',
            shell_args_position => '1',
            is_input => 1,
        },
        output_directory => {
            is => 'Text',
            doc => 'Location to save to the detector-specific files generated in the course of running',
            is_input => 1,
            is_output => 1,
        },
    ],
    has_optional => [
        control_aligned_reads_input => {
            is => 'Text',
            doc => 'Location of the control aligned reads file to which the input aligned reads file should be compared (for detectors which can utilize a control)',
            shell_args_position => '2',
            is_input => 1,
            is_output => 1,
        },
    ],
    has_transient_optional => [
        _temp_staging_directory  => {
            is => 'Text',
            doc => 'A directory to use for staging the data before putting it in the output_directory--all data here will be copied in _promote_staged_data().',
        },
        _temp_scratch_directory  => {
            is=>'Text',
            doc=>'Temp scratch directory',
        },
    ],
    doc => 'This is the base class for all detect variants classes and the variant detector dispatcher',
};

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
    
    unless($self->_generate_standard_files) {
        die $self->error_message('Failed to generate standard files from detector-specific files');
    }
    
    unless($self->_promote_staged_data) {
        die $self->error_message('Failed to promote staged data.');
    }
    
    return 1;
}

sub _verify_inputs {
    my $self = shift;
    
    my $ref_seq_file = $self->reference_sequence_input;

    unless(Genome::Sys->validate_file_for_reading($ref_seq_file)) {
        $self->error_message("reference sequence input $ref_seq_file does not exist");
        return;
    }

    my $aligned_reads_file = $self->aligned_reads_input;
    unless(Genome::Sys->validate_file_for_reading($aligned_reads_file)) {
        $self->error_message("aligned reads input $aligned_reads_file was not found.");
        return;
    }
    unless(Genome::Sys->validate_file_for_reading($aligned_reads_file.".bai")) {
        $self->error_message("aligned reads input index ".$aligned_reads_file.".bai was not found.");
        return;
    }
    
    if(defined($self->control_aligned_reads_input)){
        my $control_aligned_reads_file = $self->control_aligned_reads_input;
        unless(Genome::Sys->validate_file_for_reading($control_aligned_reads_file)) {
            $self->error_message("control aligned reads input $control_aligned_reads_file was not found.");
            return;
        }
        unless(Genome::Sys->validate_file_for_reading($control_aligned_reads_file.".bai")) {
            $self->error_message("control aligned reads input index ".$control_aligned_reads_file.".bai was not found.");
            return;
        }
    }
    return 1;
}

sub _create_directories {
    my $self = shift;
    
    my $output_directory = $self->output_directory;
    unless (-d $output_directory) {
        eval {
            Genome::Sys->create_directory($output_directory);
        };
        
        if($@) {
            $self->error_message($@);
            return;
        }

        $self->status_message("Created directory: $output_directory");
        chmod 02775, $output_directory;
    }

    $self->_create_temp_directories;

    return 1;
}

sub _create_temp_directories {
    my $self = shift;

    $self->_temp_staging_directory(Genome::Sys->create_temp_directory);
    $self->_temp_scratch_directory(Genome::Sys->create_temp_directory);
    
    return 1;
}

sub _detect_variants {
    my $self = shift;
    
    die('To implement a variant detector to this API, the _detect_variants method needs to be implemented.');
}

sub _generate_standard_files {
    my $self = shift;
    my $class = ref $self || $self;
    my @words = split('::', $class);
    
    my $retval = 1;
    
    unless(scalar(@words) > 2 and $words[0] eq 'Genome') {
        die('Could not determine detector class automatically.  Please implement _generate_standard_files in the subclass.');
    }
    
    my $detector = $words[-1];
    my $module_base = 'Genome::Model::Tools::Bed::Convert';
    
    if($self->detect_snvs) {
        my $snv_module = join('::', $module_base, 'Snv', $detector . 'ToBed'); 
        
        for my $variant_file ($self->_snv_staging_output) {
            if(Genome::Sys->check_for_path_existence($variant_file)) {
                $self->status_message("executing $snv_module on file $variant_file");
                $retval &&= $self->_run_converter($snv_module, $variant_file);
            }  
        }
    }
    
    if($self->detect_indels) {
        my $indel_module = join('::', $module_base, 'Indel', $detector . 'ToBed'); 
        
        for my $variant_file ($self->_indel_staging_output) {
            if(Genome::Sys->check_for_path_existence($variant_file)) {
                $self->status_message("executing $indel_module on file $variant_file");
                $retval &&= $self->_run_converter($indel_module, $variant_file);
            }  
        }
    }
    
    return $retval;
}

sub _run_converter {
    my $self = shift;
    my $converter = shift;
    my $source = shift;
    
    my $output = $source . '.bed'; #shift; #TODO Possibly create accessors for the bed files instead of hard-coding this
    
    my $command = $converter->create(
        source => $source,
        output => $output, 
        reference_build_id => $self->reference_build_id,
    );
    
    unless($command->execute) {
        $self->error_message('Failed to convert ' . $source . ' to the standard format.');
        return;
    }

    return 1;
}

sub _promote_staged_data {
    my $self = shift;
    my $staging_dir = $self->_temp_staging_directory;
    my $output_dir  = $self->output_directory;

    $self->status_message("Now de-staging data from $staging_dir into $output_dir"); 

    my $call = sprintf("rsync -avz %s/* %s", $staging_dir, $output_dir);

    my $rv = system($call);
    $self->status_message("Running Rsync: $call");

    unless ($rv == 0) {
        $self->error_message("Did not get a valid return from rsync, rv was $rv for call $call.  Cleaning up and bailing out");
        rmtree($output_dir);
        die $self->error_message;
    }

    chmod 02775, $output_dir;
    for my $subdir (grep { -d $_  } glob("$output_dir/*")) {
        chmod 02775, $subdir;
    }

    $self->status_message("Files in $output_dir: \n" . join "\n", glob($output_dir . "/*"));

    return $output_dir;
}

sub has_version {
    die "This should be overloaded by the detector/filter";
}

sub line_count {
    my $self = shift;
    my $input = shift;
    unless( -e $input ) {
        die $self->error_message("Could not locate file for line count: $input");
    }
    my $result = `wc -l $input`; 
    my ($answer)  = split /\s/,$result;
    return $answer
}
