package Genome::DruggableGene::Command::GeneNameReport::ConvertToEntrez;

use strict;
use warnings;
use Genome;

class Genome::DruggableGene::Command::GeneNameReport::ConvertToEntrez {
    is => 'Genome::Command::Base',
    has => [
        gene_identifier => {
            is => 'Text',
            shell_args_position => 1,
            doc => 'Gene identifiers to convert to entrez',
        },
        _entrez_gene_name_reports => {
            is => 'Genome::DruggableGene::GeneNameReport',
            is_many => 1,
            is_output => 1,
            is_optional => 1,
            doc => 'Array of gene name reports produced as output',
        },
        _intermediate_gene_name_reports => {
            is => 'Genome::DruggableGene::GeneNameReport',
            is_many => 1,
            is_output => 1,
            is_optional => 1,
            doc => 'Array of gene name reports that were used to create _entrez_gene_name_reports',
        },
    ],
};

sub help_brief {
    'Translate a gene identifier to one or more Genome::DruggableGene::GeneNameReports';
}

sub help_synopsis {
    'genome druggable-gene gene-name-report convert-to-entrez --gene-identifier ARK1D1';
}

sub help_detail {
    #TODO: write me
}

sub execute {
    my $self = shift;
    my $gene_identifier = $self->gene_identifier;
    my ($entrez_gene_name_reports, $intermediate_gene_name_reports) = Genome::DruggableGene::GeneNameReport->convert_to_entrez($gene_identifier);
    $self->_entrez_gene_name_reports($entrez_gene_name_reports->{$gene_identifier}) if $entrez_gene_name_reports->{$gene_identifier};
    $self->_intermediate_gene_name_reports($intermediate_gene_name_reports->{$gene_identifier}) if $intermediate_gene_name_reports->{$gene_identifier};
    return 1;
}

1;
