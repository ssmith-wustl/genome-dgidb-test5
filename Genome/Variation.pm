package Genome::Variation;

use strict;
use warnings;
use Genome;


class Genome::Variation {
    type_name  => 'genome variation',
    table_name => 'GENOME_VARIATION',
    id_by      => [ variation_id => { is => 'Number' }, ],
    has        => [
        database       => { is => 'Text' },
        version        => { is => 'Text' },
        submitter_name => { is => 'Text' },
        data_directory => { is => 'Path' },
        allele_string  => { is => 'Text' },
        reference      => {
            calculate_from => 'allele_string',
            calculate      => q|
                my ($reference, $variant) = split ("/", $allele_string);
                return $reference;
            |,
        },
        variant => {
            calculate_from => 'allele_string',
            calculate      => q|
                my ($reference, $variant) = split ("/", $allele_string);
                return $variant;
            |,
        },
        variation_type => { is => 'Text' },
        chrom_name     => { is => 'Text' },
        start          => { is => 'Number' },
        stop           => { is => 'Number' },
        build          => {
            is    => "Genome::Model::Build",
            id_by => 'build_id',
        },
    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::Variations',
};

1;

