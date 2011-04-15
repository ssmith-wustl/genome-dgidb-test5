package Genome::Site::WUGC::IlluminaGenotyping;

use strict;
use warnings;
use Genome;

class Genome::Site::WUGC::IlluminaGenotyping {
    table_name => 'GSC.ILLUMINA_GENOTYPING',
    data_source => 'Genome::DataSource::GMSchema',
    id_by => [
        seq_id => { is => 'Number' },
    ],
    has => [
        name => { is => 'Text' , column_name => 'DNA_NAME'},
        source_barcode => { is => 'Text' },
        well => { is => 'Text' },
        bead_chip_barcode => { is => 'Text' },
    ],
    has_optional => [
        replicate_dna_name => { is => 'Text' },
        call_rate => { is => 'Number' },
        replicate_error_rate => { is => 'Number' },
        status => { is => 'Text' },
        analysis_name => { is => 'Text' },
        genome_studio_version => { is => 'Text' },
        sample_concordance => { is => 'Number' },
        replicate_seq_id => { is => 'Number' },
        custom_num_fail_cutoff => { is => 'Number' },
        custom_cutoff => { is => 'Number' },
        num_fail_cutoff => { is => 'Number' },
        cutoff => { is => 'Number' },
        num_of_probe => { is => 'Number' },
    ],
};


sub __display_name__ {
    my $self = shift;
    return $self->source_barcode . ' for sample ' . $self->name;
}


sub meets_default_criteria {
    my $self = shift;

    my @snp_concordance = Genome::Site::WUGC::SnpConcordance->get(seq_id => $self->seq_id);
    @snp_concordance = grep { $_->is_external_comparison } @snp_concordance;
    @snp_concordance = grep { $_->match_percent && $_->match_percent > 90 } @snp_concordance;

    return (scalar @snp_concordance ? 1 : 0);
}


1;

