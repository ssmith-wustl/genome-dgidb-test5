package Genome::DruggableGene::Command::GeneNameReport::ConvertToEntrez;

use strict;
use warnings;
use Genome;

class Genome::DruggableGene::Command::GeneNameReport::ConvertToEntrez {
    is => 'Genome::Command::Base',
    has => [
        gene_identifiers => {
            is => 'Text',
            shell_args_position => 1,
            doc => 'Gene identifiers to convert to entrez',
            is_many => 1,
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
    for my $gene_identifier ($self->gene_identifiers) {
        my ($entrez_gene_name_reports, $intermediate_gene_name_reports) = Genome::DruggableGene::GeneNameReport->convert_to_entrez($gene_identifier);
        my (@entrez, @intermediate);
        @entrez = $self->_entrez_gene_name_reports($entrez_gene_name_reports->{$gene_identifier}) if $entrez_gene_name_reports->{$gene_identifier};
        @intermediate = $self->_intermediate_gene_name_reports($intermediate_gene_name_reports->{$gene_identifier}) if $intermediate_gene_name_reports->{$gene_identifier};
        if(@entrez){
            $self->status_message($gene_identifier . " as entrez is:\n");
            $self->status_message($_->name . "\n") for (@entrez);
        }
        if(@intermediate) {
            $self->status_message($gene_identifier . " as intermediate is:\n");
            $self->status_message($_-> name . "\n") for (@intermediate);
        }
    }
    return 1;
}

1;
