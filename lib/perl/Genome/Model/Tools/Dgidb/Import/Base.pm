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
        name => $name,
        nomenclature => $nomenclature,
        source_db_name => $source_db_name,
        source_db_version => $source_db_version,
        description => $description,
    );

    my $drug_name_report = Genome::DrugNameReport->get(%params);
    return $drug_name_report if $drug_name_report;
    return Genome::DrugNameReport->create(%params);
}

sub _create_drug_name_report_association {
    my $self = shift;
    my ($drug_name_report, $alternate_name, $nomenclature, $description) = @_;
    my %params = (
        drug_name_report_id => $drug_name_report->id,
        alternate_name => $alternate_name,
        nomenclature => $nomenclature,
        description => $description,
    );
    return Genome::DrugNameReportAssociation->create(%params);    
}

sub _create_drug_name_report_category_association {
    my $self = shift;
    my ($drug_name_report, $category_name, $category_value, $description) = @_;
    my %params = (
        drug_name_report_id => $drug_name_report->id,
        category_name => $category_name,
        category_value => $category_value,
        description => $description,
    );
    return Genome::DrugNameReportCategoryAssociation->create(%params);
}

sub _create_gene_name_report {
    my $self = shift;
    my ($name, $nomenclature, $source_db_name, $source_db_version, $description) = @_;
    my %params = (
        name => $name,
        nomenclature => $nomenclature,
        source_db_name => $source_db_name,
        source_db_version => $source_db_version,
        description => $description,
    );

    if($name ne 'na'){
        my $gene_name_report = Genome::GeneNameReport->get(%params);
        return $gene_name_report if $gene_name_report;
    }
    return Genome::GeneNameReport->create(%params);
}

sub _create_gene_name_report_association {
    my $self = shift;
    my ($gene_name_report, $alternate_name, $nomenclature, $description) = @_;
    my %params = (
        gene_name_report_id => $gene_name_report->id,
        alternate_name => $alternate_name,
        nomenclature => $nomenclature,
        description => $description,
    );
    my $gene_name_report_association = Genome::GeneNameReportAssociation->get(%params);
    return $gene_name_report_association if $gene_name_report_association;
    return Genome::GeneNameReportAssociation->create(%params);
}

sub _create_gene_name_report_category_association {
    my $self = shift;
    my ($gene_name_report, $category_name, $category_value, $description) = @_;
    my %params = (
        gene_name_report_id => $gene_name_report->id,
        category_name => $category_name,
        category_value => $category_value,
        description => $description,
    );
    return Genome::GeneNameReportCategoryAssociation->create(%params);
}

sub _create_interaction_report {
    my $self = shift;
    my ($drug_name_report, $gene_name_report, $type, $description) = @_;
    my %params = (
        gene_name_report_id => $gene_name_report->id,
        drug_name_report_id => $drug_name_report->id,
        interaction_type => $type,
        description =>  $description,
    );

    my $interaction = Genome::DrugGeneInteractionReport->get(%params);
    return $interaction if $interaction;
    return Genome::DrugGeneInteractionReport->create(%params);
}

sub _create_interaction_report_attribute {
    my $self = shift;
    my ($interaction, $name, $value) = @_;
    my %params = (
        drug_gene_interaction_report => $interaction,
        name => $name,
        value => $value,
    );
    return Genome::DrugGeneInteractionReportAttribute->create(%params);
}

1;
