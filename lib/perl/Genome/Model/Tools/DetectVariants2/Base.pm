package Genome::Model::Tools::DetectVariants2::Base;

use strict;
use warnings;

use Clone qw/clone/;
use Data::Compare;
use Data::Dumper;
use File::Path;
use File::Basename;
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
            is_constant => 1,
            calculate_from => ['reference_build_id'],
            calculate => q| 
                my $build = Genome::Model::Build->get($reference_build_id);
                my $cache_base_dir = $build->local_cache_basedir;
                if ( -d $cache_base_dir ) { # WE ARE ON A MACHINE THAT SUPPORTS CACHING
                    return $build->cached_full_consensus_path('fa');
                }
                else { # USE NETWORK REFERENCE
                    return $build->full_consensus_path('fa');
                }
                |,
            doc => 'Location of the reference sequence file',
        },
        output_directory => {
            is => 'Text',
            doc => 'Location to save to the detector-specific files generated in the course of running',
            is_input => 1,
            is_output => 1,
        },
    ],
    has_optional => [
        aligned_reads_input => {
            is => 'Text',
            doc => 'Location of the aligned reads input file',
            shell_args_position => '1',
            is_input => 1,
        },
        control_aligned_reads_input => {
            is => 'Text',
            doc => 'Location of the control aligned reads file to which the input aligned reads file should be compared (for detectors which can utilize a control)',
            shell_args_position => '2',
            is_input => 1,
            is_output => 1,
        },
        multiple_bams => {
            is => 'Text',
            is_many => 1,
            doc => 'run on many bams',
            is_input =>1,
            is_output=>1,
        },
        aligned_reads_sample => {
            is => 'Text',
            doc => 'Sample name for the source of the aligned_reads_input',
            is_input => 1,
        },
        control_aligned_reads_sample => {
            is => 'Text',
            doc => 'Sample name for the source of the control_aligned_reads_input',
            is_input => 1,
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
    unless($self->_check_for_multiple_bams){
        die $self->error_message('Failed to find proper bam inputs.');
    }

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

sub _check_for_multiple_bams {
    my $self = shift;
    if(defined($self->multiple_bams)){
        die $self->error_message("This pipeline does not currently support multiple bams.");
    }else {
        return 1;
    }
    
    
    unless(defined $self->multiple_bams ){
        if(defined($self->aligned_reads_input)){
            return 1;
        }else{
            return undef;
        }
    }
    warn "This pipeline does not currently support running on multiple bams. It will proceed only with the first bam in the list.\n";

    if(defined $self->aligned_reads_input){
        return undef;
    }

    my @bams = $self->multiple_bams;
    $self->aligned_reads_input($bams[0]);

    return 1;
}

sub _verify_inputs {
    my $self = shift;
    
    my $reference_build_id = $self->reference_build_id;
    if ( not $reference_build_id ) {
        $self->error_message('No reference sequence build id');
        return;
    }
    my $reference_build = Genome::Model::Build->get($reference_build_id);
    if ( not $reference_build ) {
        $self->error_message('Failed to get reference sequence build for id: '.$reference_build_id);
        return;
    }

    my $ref_seq_file = $reference_build->full_consensus_path('fa'); # verify the network one exists
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
    my $bed_module_base = 'Genome::Model::Tools::Bed::Convert';
    my $vcf_module_base = 'Genome::Model::Tools::Vcf::Convert';
    
    if($self->detect_snvs) {
        my $bed_snv_module = join('::', $bed_module_base, 'Snv', $detector . 'ToBed'); 
        
        for my $variant_file ($self->_snv_staging_output) {
            if(Genome::Sys->check_for_path_existence($variant_file)) {
                $self->status_message("executing $bed_snv_module on file $variant_file");
                $retval &&= $self->_run_bed_converter($bed_snv_module, $variant_file);
            }  
        }
    }
    
    if($self->detect_indels) {
        my $indel_module = join('::', $bed_module_base, 'Indel', $detector . 'ToBed'); 
        
        for my $variant_file ($self->_indel_staging_output) {
            if(Genome::Sys->check_for_path_existence($variant_file)) {
                $self->status_message("executing $indel_module on file $variant_file");
                $retval &&= $self->_run_bed_converter($indel_module, $variant_file);
            }  
        }
    }

    $retval &&= $self->_generate_vcf;

    
    return $retval;
}

sub _run_bed_converter {
    my $self = shift;
    my $converter = shift;
    my $source = shift;
    
    my $output = $source . '.bed';
    
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

sub _generate_vcf {
    my $self = shift;
    my $class = ref $self || $self;
    my @words = split('::', $class);
    
    my $retval = 1;
    
    unless(scalar(@words) > 2 and $words[0] eq 'Genome') {
        die('Could not determine detector class automatically.  Please implement _generate_standard_files in the subclass.');
    }

    my $detector = $words[-1];
    my $vcf_module_base = 'Genome::Model::Tools::Vcf::Convert';

    if($self->detect_snvs) {
        my $vcf_snv_module = join('::', $vcf_module_base, 'Snv', $detector); 
        eval {
            $vcf_snv_module->__meta__;
        };
        if($@){
            $self->status_message("Couldn't find a working vcf converter at $vcf_snv_module");
        } else {  
            for my $variant_file ($self->_snv_staging_output) {
                if(Genome::Sys->check_for_path_existence($variant_file)) {
                    $self->status_message("executing $vcf_snv_module on file $variant_file");
                    $retval &&= $self->_run_vcf_converter($vcf_snv_module, $variant_file, "snvs");
                }  
            }
        }
    }

    return $retval;
}

sub _run_vcf_converter {
    my $self = shift;
    my $converter = shift;
    my $input_file = shift;
    my $type = shift;
    my $dirname = dirname($input_file);    
    my $output_file = $dirname . '/'.$type.'.vcf';
    my $aligned_reads_sample = $self->aligned_reads_sample;
    my $reference_sequence_build = Genome::Model::Build->get($self->reference_build_id);

    my $command = $converter->create(
        input_file => $input_file,
        output_file => $output_file, 
        aligned_reads_sample => $aligned_reads_sample,
        sequencing_center => 'WUSTL',
        vcf_version => "4.0",
        reference_sequence_build => $reference_sequence_build,
    );
    
    unless($command->execute) {
        $self->error_message('Failed to convert ' . $input_file . ' to the standard format.');
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
