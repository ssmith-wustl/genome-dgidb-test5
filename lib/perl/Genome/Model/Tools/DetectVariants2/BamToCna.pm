package Genome::Model::Tools::DetectVariants2::BamToCna;

use strict;
use warnings;

use Cwd;

use Genome;

class Genome::Model::Tools::DetectVariants2::BamToCna{
    is => ['Genome::Model::Tools::DetectVariants2::Detector'],
    has_constant => [
        detect_snvs => {},
        detect_svs => {},
        detect_indels => {}, 
        detect_cnvs => { value => 1 },
    ],
    has_param => [
         lsf_queue => {
             default_value => 'long',
         },
     ],
};

sub _detect_variants {
    my $self = shift;
    my $b2c_cmd = Genome::Model::Tools::Somatic::BamToCna->create( 
        tumor_bam_file => $self->aligned_reads_input, 
        normal_bam_file => $self->control_aligned_reads_input,
        output_file => $self->_temp_staging_directory."/bam_to_cna_output",
    );
    unless($b2c_cmd->execute){
        $self->error_message("Failed to run BamToCna command.");
        die $self->error_message;
    }

    return 1;
}

sub has_version {
    return 1; #FIXME implement this when this module is filled out
}

1;
