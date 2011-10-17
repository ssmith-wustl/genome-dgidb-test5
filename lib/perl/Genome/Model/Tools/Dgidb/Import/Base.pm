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

    my $drug_name = Genome::DrugName->get(%params);
    return $drug_name if $drug_name;
    return Genome::DrugName->create(%params);
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
    return Genome::DrugNameAssociation->create(%params);    
}

sub _create_drug_name_category_association {
    my $self = shift;
    my ($drug_name, $category, $description) = @_;
    my %params = (
        drug_name_id => $drug_name->id,
        category_name => $category,
        description => $description,
    );
    return Genome::DrugNameCategoryAssociation->create(%params);
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
        my $gene_name = Genome::GeneName->get(%params);
        return $gene_name if $gene_name;
    }
    return Genome::GeneName->create(%params);
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
    my $gene_name_association = Genome::GeneNameAssociation->get(%params);
    return $gene_name_association if $gene_name_association;
    return Genome::GeneNameAssociation->create(%params);
}

sub _create_gene_name_category_association {
    my $self = shift;
    my ($gene_name, $category_name, $description) = @_;
    my %params = (
        gene_name_id => $gene_name->id,
        category_name => $category_name,
        description => $description,
    );
    return Genome::GeneNameAssociation->create(%params);
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

    my $interaction = Genome::DrugGeneInteraction->get(%params);
    return $interaction if $interaction;
    return Genome::DrugGeneInteraction->create(%params);
}

sub _create_interaction_attribute {
    my $self = shift;
    my ($interaction, $name, $value) = @_;
    my %params = (
        drug_gene_interaction => $interaction,
        name => $name,
        value => $value,
    );
    return Genome::DrugGeneInteractionAttribute->create(%params);
}

1;
