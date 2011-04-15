package Genome::Site::WUGC::ExternalGenotyping;

use strict;
use warnings;
use Genome;

class Genome::Site::WUGC::ExternalGenotyping {
    table_name => 'GSC.EXTERNAL_GENOTYPING',
    data_source => 'Genome::DataSource::GMSchema',
    id_by => [
        seq_id => { is => 'Number' },
    ],
    has => [
        organism_sample_id => { is => 'Number' },
        genotyping_platform_id => { is => 'Number' },
    ],
};


1;
