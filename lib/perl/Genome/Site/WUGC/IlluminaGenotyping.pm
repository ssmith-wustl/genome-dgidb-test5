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
        dna_name => { is => 'Text' },
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

1;

