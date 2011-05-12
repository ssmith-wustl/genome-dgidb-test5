package Genome::Model::Tools::DetectVariants2::GatkGermlineIndelUnifiedGenotyper;

use strict;
use warnings;

use Cwd;

use Genome;

class Genome::Model::Tools::DetectVariants2::GatkGermlineIndelUnifiedGenotyper{
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
             default_value => "-R 'rusage[mem=6000] select[type==LINUX64 && model != Opteron250 && mem>6000 && maxtmp>100000] span[hosts=1]' -M 6000000",
         },
     ],
};

sub _detect_variants {
    my $self = shift;
    my $refseq = $self->reference_sequence_input;
    $refseq =~ s/\/opt\/fscache//;
    my $gatk_cmd = Genome::Model::Tools::Gatk::GermlineIndelUnifiedGenotyper->create( 
        bam_file => $self->aligned_reads_input, 
        vcf_output_file => $self->_temp_staging_directory."/indels.hq",
        mb_of_ram => $self->mb_of_ram,
        reference_fasta => $refseq,
    );
    unless($gatk_cmd->execute){
        $self->error_message("Failed to run GATK command.");
        die $self->error_message;
    }
    unless(-s $self->_temp_staging_directory."/indels.hq"){
        my $filename = $self->_temp_staging_directory."/indels.hq";
        Genome::Sys->write_file($filename, '');
    }
    return 1;
}

sub has_version {
    return 1; #FIXME implement this when this module is filled out
}

1;
