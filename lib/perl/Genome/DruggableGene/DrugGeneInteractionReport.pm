package Genome::DruggableGene::DrugGeneInteractionReport;

use strict;
use warnings;

use Genome;

class Genome::DruggableGene::DrugGeneInteractionReport {
    is => 'Genome::Searchable',
    id_generator => '-uuid',
    table_name => 'dgidb.drug_gene_interaction_report',
    schema_name => 'dgidb',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => { is => 'Text' },
    ],
    has => [
        drug_name_report_id => { is => 'Text'},
        drug_name_report => {
            is => 'Genome::DruggableGene::DrugNameReport',
            id_by => 'drug_name_report_id',
            constraint_name => 'drug_gene_interaction_report_drug_name_report_id_fkey',
        },
        drug_name_report_name => {
            via => 'drug_name_report',
            to => 'name',
        },
        gene_name_report_id => { is => 'Text'},
        gene_name_report => {
            is => 'Genome::DruggableGene::GeneNameReport',
            id_by => 'gene_name_report_id',
            constraint_name => 'drug_gene_interaction_report_gene_name_report_id_fkey',
        },
        gene_name_report_name => {
            via => 'gene_name_report',
            to => 'name',
        },
        source_db_name => { is => 'Text'},
        source_db_version => { is => 'Text'},
        description => { is => 'Text', is_optional => 1 },
        drug_gene_interaction_report_attributes => {
            is => 'Genome::DruggableGene::DrugGeneInteractionReportAttribute',
            reverse_as => 'drug_gene_interaction_report',
            is_many => 1,
        },
        citation => {
            calculate_from => ['source_db_name', 'source_db_version'],
            calculate => q|
                my $citation = Genome::DruggableGene::Citation->get(source_db_name => $source_db_name, source_db_version => $source_db_version);
                return $citation;
            |,
        },
        interaction_types => {
            via => 'drug_gene_interaction_report_attributes',
            to => 'value',
            where => [name => 'interaction_type'],
            is_many => 1,
            is_optional => 1,
        },
        is_potentiator => {
            calculate => q|
                my @potentiator = grep($_ =~ /potentiator/, $self->interaction_types);
                return 1 if @potentiator;
                return 0;
            |,
        },
        is_untyped => {
            calculate => q|
                my @na = grep($_ =~ /na/, $self->interaction_types);
                return 1 if @na;
                return 0;
            |,
        },
        is_inhibitor => {
            calculate => q|
                my @inhibitor = grep($_ =~ /inhibitor/, $self->interaction_types);
                return 1 if @inhibitor;
                return 0;
            |,
        }
    ],
    doc => 'Claim regarding an interaction between a drug name and a gene name',
};

sub __display_name__ {
    my $self = shift;
    return "Interaction of " . $self->drug_name_report_name . " and " . $self->gene_name_report_name;
}

if ($INC{"Genome/Search.pm"}) {
    __PACKAGE__->create_subscription(
        method => 'commit',
        callback => \&add_to_search_index_queue,
    );
    __PACKAGE__->create_subscription(
        method => 'delete',
        callback => \&add_to_search_index_queue,
    );
}

sub add_to_search_index_queue {
    my $self = shift;
    my $set = Genome::DruggableGene::DrugGeneInteractionReport->define_set(
        drug_name_report_name => $self->drug_name_report_name,
        gene_name_report_name => $self->gene_name_report_name,
    );
    Genome::Search::Queue->create(
        subject_id => $set->id,
        subject_class => $set->class,
        priority => 9,
    );
}

1;
