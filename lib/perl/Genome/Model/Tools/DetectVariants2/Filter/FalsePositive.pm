package Genome::Model::Tools::DetectVariants2::Filter::FalsePositive;

use warnings;
use strict;

use Genome;

class Genome::Model::Tools::DetectVariants2::Filter::FalsePositive {
    is => 'Genome::Model::Tools::DetectVariants2::Filter',
};

sub _filter_variants {
    my $self = shift;
    
    my ($tumor_bam,$variant_file,$output_file,$filtered_file,$refseq);

    $tumor_bam = $self->aligned_reads_input;
    $variant_file = $self->input_directory."/snvs.hq.bed";
    $output_file = $self->_temp_staging_directory."/snvs.hq.bed";
    $filtered_file = $self->_temp_staging_directory."/snvs.lq.bed";
    $refseq = $self->reference_sequence_input;

    my $ff_cmd = Genome::Model::Tools::Somatic::FilterFalsePositives->create(
            bam_file => $tumor_bam,
            variant_file => $variant_file,
            output_file => $output_file,
            filtered_file => $filtered_file,
            reference => $refseq,
    );

    unless( $ff_cmd->execute ) {
        die $self->error_message("Failed to execute FilterFalsePositive command." );
    }

    return 1;
}

1;
