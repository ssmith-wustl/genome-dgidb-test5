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

sub _create_drug_name {
    my $self = shift;
    my ($name, $nomenclature, $source_db_name, $source_db_version, $description) = @_;
    my %params = ( 
        name => $name,
        nomenclature => $nomenclature,
        source_db_name => $source_db_name,
        source_db_version => $source_db_version,
        description => $description,
    );

    my $drug_name = Genome::DrugNameReport->get(%params);
    return $drug_name if $drug_name;
    return Genome::DrugNameReport->create(%params);
}

sub _create_drug_name_association {
    my $self = shift;
    my ($drug_name, $alternate_name, $nomenclature, $description) = @_;
    my %params = (
        drug_name_id => $drug_name->id,
        alternate_name => $alternate_name,
        nomenclature => $nomenclature,
        description => $description,
    );
    return Genome::DrugNameReportAssociation->create(%params);    
}

sub _create_drug_name_category_association {
    my $self = shift;
    my ($drug_name, $category_name, $category_value, $description) = @_;
    my %params = (
        drug_name_id => $drug_name->id,
        category_name => $category_name,
        category_value => $category_value,
        description => $description,
    );
    return Genome::DrugNameReportCategoryAssociation->create(%params);
}

sub _create_gene_name {
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
        my $gene_name = Genome::GeneNameReport->get(%params);
        return $gene_name if $gene_name;
    }
    return Genome::GeneNameReport->create(%params);
}

sub _create_gene_name_association {
    my $self = shift;
    my ($gene_name, $alternate_name, $nomenclature, $description) = @_;
    my %params = (
        gene_name_id => $gene_name->id,
        alternate_name => $alternate_name,
        nomenclature => $nomenclature,
        description => $description,
    );
    my $gene_name_association = Genome::GeneNameReportAssociation->get(%params);
    return $gene_name_association if $gene_name_association;
    return Genome::GeneNameReportAssociation->create(%params);
}

sub _create_gene_name_category_association {
    my $self = shift;
    my ($gene_name, $category_name, $category_value, $description) = @_;
    my %params = (
        gene_name_id => $gene_name->id,
        category_name => $category_name,
        category_value => $category_value,
        description => $description,
    );
    return Genome::GeneNameReportAssociation->create(%params);
}

sub _create_interaction {
    my $self = shift;
    my ($drug_name, $gene_name, $type, $description) = @_;
    my %params = (
        gene_name_id => $gene_name->id,
        drug_name_id => $drug_name->id,
        interaction_type => $type,
        description =>  $description,
    );

    my $interaction = Genome::DrugGeneInteractionReport->get(%params);
    return $interaction if $interaction;
    return Genome::DrugGeneInteractionReport->create(%params);
}

sub _create_interaction_attribute {
    my $self = shift;
    my ($interaction, $name, $value) = @_;
    my %params = (
        drug_gene_interaction => $interaction,
        name => $name,
        value => $value,
    );
    return Genome::DrugGeneInteractionReportAttribute->create(%params);
}

1;
