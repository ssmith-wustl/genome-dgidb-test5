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
};

sub _detect_variants {
    my $self = shift;
    my $gatk_cmd = Genome::Model::Tools::Gatk::SomaticIndel->create( 
        tumor_bam => $self->aligned_reads_input, 
        normal_bam => $self->control_aligned_reads_input,
        output_file => $self->_temp_staging_directory."/gatk_output_file",
        bed_output_file => $self->_temp_staging_directory."/indels.hq",
    );
    unless($gatk_cmd->execute){
        $self->error_message("Failed to run GATK command.");
        die $self->error_message;
    }
    return 1;
}

sub has_version {
    return 1; #FIXME implement this when this module is filled out
}

1;
