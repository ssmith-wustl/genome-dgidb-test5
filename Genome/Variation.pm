package Genome::Variation;

use strict;
use warnings;
use Genome;

class Genome::Variation{
    type_name => 'genome variation',
    table_name => 'GENOME_VARIATION',
    id_by => [
        variation_id => {is => 'Number'},
        ],
    has =>[
        external_variation_id => {is => 'Number'},
        allele_string => {is => 'String'},
        variation_type => {is => 'String'},
        chrom_name => {is => 'String'},
        start => {is => 'Number'},
        stop => {is => 'Number'},
        pubmed_id => {is => 'Number'},
        ],
    has_many => [
        variation_instances => {is => 'Genome::VariationInstance', reverse_id_by => 'variation'},
        submitters => {is => 'Genome::Submitter', via => 'variation_instances', to => 'submitter'},
        ],

        schema_name => 'files',
        data_source => 'Genome::DataSource::Variations',
};

sub submitter_name
{
    my $self = shift;

    my @submitters = $self->submitters;
    return 'NONE' unless @submitters;

    return $submitters[0]->submitter_name;
}

sub source
{
    my $self = shift;

    my @submitters = $self->submitters;
    return 'NONE' unless @submitters;

    return $submitters[0]->variation_source;
}


1;

