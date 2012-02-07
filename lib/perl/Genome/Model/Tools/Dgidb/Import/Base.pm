package Genome::Model::Tools::Dgidb::Import::Base;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Dgidb::Import::Base {
    is => 'Command::V2',
    is_abstract => 1,
    has => [
        version => {
            is => 'Text',
            is_input => 1,
            doc => 'Version identifier for the infile (ex 3)',
        },
    ],
    doc => 'Base class for importing datasets into DGI:DB',
};

sub _create_drug_name_report {
    my $self = shift;
    my ($name, $nomenclature, $source_db_name, $source_db_version, $description) = @_;
    my %params = ( 
        name => uc $name,
        nomenclature => $nomenclature,
        source_db_name => $source_db_name,
        source_db_version => $source_db_version,
        description => $description,
    );

    my $drug_name_report = Genome::DruggableGene::DrugNameReport->get(%params);
    return $drug_name_report if $drug_name_report;
    return Genome::DruggableGene::DrugNameReport->create(%params);
}

sub _create_drug_name_report_association {
    my $self = shift;
    my ($drug_name_report, $alternate_name, $nomenclature, $description) = @_;
    my %params = (
        drug_id => $drug_name_report->id,
        alternate_name => uc $alternate_name,
        nomenclature => $nomenclature,
        description => $description,
    );

    my $drug_name_report_association = Genome::DruggableGene::DrugNameReportAssociation->get(%params);
    return $drug_name_report_association if $drug_name_report_association;
    return Genome::DruggableGene::DrugNameReportAssociation->create(%params);    
}

sub _create_drug_name_report_category_association {
    my $self = shift;
    my ($drug_name_report, $category_name, $category_value, $description) = @_;
    my %params = (
        drug_id => $drug_name_report->id,
        category_name => $category_name,
        category_value => lc $category_value,
        description => $description,
    );
    my $drug_name_report_category_association = Genome::DruggableGene::DrugNameReportCategoryAssociation->get(%params);
    return $drug_name_report_category_association if $drug_name_report_category_association;
    return Genome::DruggableGene::DrugNameReportCategoryAssociation->create(%params);
}

sub _create_gene_name_report {
    my $self = shift;
    my ($name, $nomenclature, $source_db_name, $source_db_version, $description) = @_;
    my %params = (
        name => uc $name,
        nomenclature => $nomenclature,
        source_db_name => $source_db_name,
        source_db_version => $source_db_version,
        description => $description,
    );

    if($name ne 'NA'){
        my $gene_name_report = Genome::DruggableGene::GeneNameReport->get(%params);
        return $gene_name_report if $gene_name_report;
    }
    return Genome::DruggableGene::GeneNameReport->create(%params);
}

sub _create_gene_name_report_association {
    my $self = shift;
    my ($gene_name_report, $alternate_name, $nomenclature, $description) = @_;
    my %params = (
        gene_id => $gene_name_report->id,
        alternate_name => uc $alternate_name,
        nomenclature => $nomenclature,
        description => $description,
    );
    my $gene_name_report_association = Genome::DruggableGene::GeneNameReportAssociation->get(%params);
    return $gene_name_report_association if $gene_name_report_association;
    return Genome::DruggableGene::GeneNameReportAssociation->create(%params);
}

sub _create_gene_name_report_category_association {
    my $self = shift;
    my ($gene_name_report, $category_name, $category_value, $description) = @_;
    my %params = (
        gene_id => $gene_name_report->id,
        category_name => $category_name,
        category_value => lc $category_value,
        description => $description,
    );
    my $gene_name_report_category_association = Genome::DruggableGene::GeneNameReportCategoryAssociation->get(%params);
    return $gene_name_report_category_association if $gene_name_report_category_association;
    return Genome::DruggableGene::GeneNameReportCategoryAssociation->create(%params);
}

sub _create_interaction_report {
    my $self = shift;
    my ($drug_name_report, $gene_name_report, $source_db_name, $source_db_version, $description) = @_;
    my %params = (
        gene_id => $gene_name_report->id,
        drug_id => $drug_name_report->id,
        source_db_name => $source_db_name,
        source_db_version => $source_db_version,
        description =>  $description,
    );

    my $interaction = Genome::DruggableGene::DrugGeneInteractionReport->get(%params);
    return $interaction if $interaction;
    return Genome::DruggableGene::DrugGeneInteractionReport->create(%params);
}

sub _create_interaction_report_attribute {
    my $self = shift;
    my ($interaction, $name, $value) = @_;
    my %params = (
        drug_gene_interaction_report => $interaction,
        name => $name,
        value => lc $value,
    );
    my $attribute = Genome::DruggableGene::DrugGeneInteractionReportAttribute->get(%params);
    return $attribute if $attribute;
    return Genome::DruggableGene::DrugGeneInteractionReportAttribute->create(%params);
}

1;
