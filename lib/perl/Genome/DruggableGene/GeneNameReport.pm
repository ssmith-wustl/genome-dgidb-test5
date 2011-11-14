package Genome::DruggableGene::GeneNameReport;

use strict;
use warnings;

use Genome;
use List::MoreUtils qw/ uniq /;

class Genome::DruggableGene::GeneNameReport {
    is => 'Genome::Searchable',
    id_generator => '-uuid',
    table_name => 'dgidb.gene_name_report',
    schema_name => 'dgidb',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => {is => 'Text'},
    ],
    has => [
        name => { is => 'Text'},
        nomenclature => { is => 'Text'},
        source_db_name => { is => 'Text'},
        source_db_version => { is => 'Text'},
        description => {
            is => 'Text',
            is_optional => 1,
        },
        gene_name_report_associations => {
            is => 'Genome::DruggableGene::GeneNameReportAssociation',
            reverse_as => 'gene_name_report',
            is_many => 1,
        },
        gene_name_report_category_associations => {
            is => 'Genome::DruggableGene::GeneNameReportCategoryAssociation',
            reverse_as => 'gene_name_report',
            is_many => 1,
        },
        drug_gene_interaction_reports => {
            is => 'Genome::DruggableGene::DrugGeneInteractionReport',
            reverse_as => 'gene_name_report',
            is_many => 1,
        },
        drug_name_reports => {
            is => 'Genome::DruggableGene::DrugNameReport',
            via => 'drug_gene_interaction_reports',
            to => 'drug_name_report',
            is_many => 1,
        },
        citation => {
            calculate_from => ['source_db_name', 'source_db_version'],
            calculate => q|
                my $citation = Genome::DruggableGene::Citation->get(source_db_name => $source_db_name, source_db_version => $source_db_version);
                return $citation;
            |,
        }
    ],
    doc => 'Claim regarding the name of a drug',
};

sub __display_name__ {
    my $self = shift;
    return $self->name . '(' . $self->source_db_name . ' ' . $self->source_db_version . ')';
}

if ($INC{"Genome/Search.pm"}) {
    __PACKAGE__->create_subscription(
        method => 'commit',
        callback => \&commit_callback,
    );
}

sub commit_callback {
    my $self = shift;
    Genome::Search->add(Genome::DruggableGene::GeneNameReport->define_set(name => $self->name));
}

sub convert_to_entrez {
    my $class = shift;
    my $gene_identifier = shift;
    my ($entrez_gene_name_reports, $intermediate_gene_name_reports) = $class->_convert_to_entrez_gene_name_report($gene_identifier);
    return ($entrez_gene_name_reports, $intermediate_gene_name_reports);
}

sub _convert_to_entrez_gene_name_report {
    my $class = shift;
    my $gene_identifier = shift;
    my @entrez_gene_name_reports;
    my @intermediate_gene_name_reports;

    #If the incoming gene identifier has a trailing version number, strip it off before comparison
    if ($gene_identifier =~ /(.*)\.\d+$/){
        $gene_identifier = $1;
    }

    @entrez_gene_name_reports = $class->_match_as_entrez_gene_symbol($gene_identifier);

    unless(@entrez_gene_name_reports){
        @entrez_gene_name_reports = $class->_match_as_entrez_id($gene_identifier);
    }

    unless(@entrez_gene_name_reports){
        @entrez_gene_name_reports = $class->_match_as_ensembl_id($gene_identifier);
    }

    unless(@entrez_gene_name_reports){
        my $intermediate_gene_name_reports;
        ($intermediate_gene_name_reports, @entrez_gene_name_reports) = $class->_match_as_uniprot_id($gene_identifier);
        @intermediate_gene_name_reports = @{$intermediate_gene_name_reports};
    }

    return \@entrez_gene_name_reports, \@intermediate_gene_name_reports;
}

sub _match_as_entrez_gene_symbol {
    my $class = shift;
    my $gene_identifier = shift;

    my @entrez_gene_name_report_associations = Genome::DruggableGene::GeneNameReportAssociation->get(nomenclature => ['entrez_gene_symbol', 'entrez_gene_synonym'], alternate_name => $gene_identifier);
    my @gene_name_reports = map($_->gene_name_report, @entrez_gene_name_report_associations);

    @gene_name_reports = uniq @gene_name_reports;
    return @gene_name_reports;
}

sub _match_as_entrez_id {
    my $class = shift;
    my $gene_identifier = shift;

    my @entrez_gene_name_reports = Genome::DruggableGene::GeneNameReport->get(nomenclature => 'entrez_id', name => $gene_identifier);
    return @entrez_gene_name_reports;
}

sub _match_as_ensembl_id {
    my $class = shift;
    my $gene_identifier = shift;
    my @entrez_gene_name_reports;

    my @gene_name_reports = Genome::DruggableGene::GeneNameReport->get(source_db_name => 'Ensembl', name => $gene_identifier);
    for my $gene_name_report (@gene_name_reports){
        my @identifiers = ($gene_name_report->name, map($_->alternate_name, $gene_name_report->gene_name_report_associations));
        for my $identifier (@identifiers){
            push @entrez_gene_name_reports, $class->_match_as_entrez_gene_symbol($identifier);
        }
    }

    return @entrez_gene_name_reports;
}

sub _match_as_uniprot_id {
    my $class = shift;
    my $gene_identifier = shift;

    my @gene_name_report_associations = Genome::DruggableGene::GeneNameReportAssociation->get(nomenclature => 'uniprot_id', alternate_name => $gene_identifier);
    my @gene_name_reports = map($_->gene_name_report, @gene_name_report_associations);
    @gene_name_reports = uniq @gene_name_reports;
    my @entrez_gene_name_reports;
    for my $gene_name_report (@gene_name_reports){
        my @identifiers = ($gene_name_report->name, map($_->alternate_name, grep($_->nomenclature ne 'uniprot_id', $gene_name_report->gene_name_report_associations)));
        for my $identifier (@identifiers){
            push @entrez_gene_name_reports, $class->_match_as_entrez_gene_symbol($identifier);
        }
    }

    @entrez_gene_name_reports = uniq @entrez_gene_name_reports;
    return (\@gene_name_reports, @entrez_gene_name_reports);
}



1;
