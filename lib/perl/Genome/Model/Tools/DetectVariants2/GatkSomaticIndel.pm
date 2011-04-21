package Genome::Model::Tools::DetectVariants2::GatkSomaticIndel;

use strict;
use warnings;

use Cwd;

use Genome;

class Genome::Model::Tools::DetectVariants2::GatkSomaticIndel{
    is => ['Genome::Model::Tools::DetectVariants2::Detector'],
    has_constant => [
        detect_snvs => {},
        detect_svs => {},
        detect_indels => { value => 1 },
    ],
    has => [
        mb_of_ram => {
            is => 'Text',
            doc => 'Amount of memory to allow GATK to use',
            default => 5000,
        },
    ],
    has_param => [
         lsf_queue => {
             default_value => 'long',
         },
         lsf_resource => {
             # fscache will select blades with fscaching of the human reference directory
             default_value => "-M 8000000 -R 'select[type==LINUX64 && mem>8000 && fscache] rusage[mem=8000]'",
         },
     ],
};

sub _detect_variants {
    my $self = shift;
    my $refseq = $self->reference_sequence_input;
    $refseq =~ s/\/opt\/fscache//;
    my $gatk_cmd = Genome::Model::Tools::Gatk::SomaticIndel->create( 
        tumor_bam => $self->aligned_reads_input, 
        normal_bam => $self->control_aligned_reads_input,
        output_file => $self->_temp_staging_directory."/gatk_output_file",
        mb_of_ram => $self->mb_of_ram,
        reference => $refseq,
    );
    unless($gatk_cmd->execute){
        $self->error_message("Failed to run GATK command.");
        die $self->error_message;
    }

    my $cmd = "grep SOMATIC ".$self->_temp_staging_directory."/gatk_output_file > ".$self->_temp_staging_directory."/indels.hq";

    ## TODO This is not running in a shellcmd because shellcmd inexplicably bombs out when running this. It dies 
    ## after receiving an exit code of 1. This should be addressed, and the system call replaced.    
    unless(system($cmd)){
        die $self->error_message("Could not execute grep to separate germline and somatic calls in gatk");
    }
    unless(-e $self->_temp_staging_directory."/indels.hq"){
        my $filename = $self->_temp_staging_directory."/indels.hq";
        my $output = system("touch $filename");
        if($output){
            $self->error_message("creating an empty indels.hq file failed. output=".$output);
            die $self->error_message;
        }
    }

    return 1;
}

sub _create_temp_directories {
    my $self = shift;
    $self->_temp_staging_directory($self->output_directory);
    $self->_temp_scratch_directory($self->output_directory);
    return 1;
}
    

sub has_version {
    return 1; #FIXME implement this when this module is filled out
}

1;
