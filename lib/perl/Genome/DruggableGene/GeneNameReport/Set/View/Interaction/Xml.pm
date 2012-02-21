package Genome::DruggableGene::GeneNameReport::Set::View::Interaction::Xml;

use strict;
use warnings;
use Genome;
use Data::Dumper;
use XML::LibXML;

class Genome::DruggableGene::GeneNameReport::Set::View::Interaction::Xml {
    is => 'Genome::View::Status::Xml',
    has => {
        perspective => { is => 'Text', value => 'interaction' },
    },
    has_optional => [
        no_match_genes => { is => 'Text', is_many => 1 },
        no_interaction_genes => { is => 'Genome::DruggableGene::GeneNameReport', is_many => 1 },
        interactions => { is => 'Genome::DruggableGene::DrugGeneInteraction', is_many => 1 },
        filtered_out_interactions => { is => 'Genome::DruggableGene::DrugGeneInteraction', is_many => 1 },
        identifier_to_genes=> { is => 'HASH' },
    ],
};

sub _generate_content {
    my $self = shift;

    #create the XML doc and add it to the object
    my $doc = XML::LibXML->createDocument();
    $self->_xml_doc($doc);
    my $drug_gene_interaction = $doc->createElement("drug_gene_interaction");

    $drug_gene_interaction->addChild($self->get_no_match_genes_node);
    $drug_gene_interaction->addChild($self->get_no_interaction_genes_node);
    $drug_gene_interaction->addChild($self->get_interactions_node);
    $drug_gene_interaction->addChild($self->get_filtered_out_interactions_node);

    $doc->setDocumentElement($drug_gene_interaction);
    return $doc->toString(1);
}

sub get_no_match_genes_node {
    my $self = shift;
    my $doc = $self->_xml_doc;

    my $no_match_genes = $doc->createElement("no_match_genes");

    for my $name ($self->no_match_genes){
        my $item = $doc->createElement('item');
        $item->addChild($doc->createTextNode($name));
        $no_match_genes->addChild($item);
    }

    return $no_match_genes;
}

sub get_no_interaction_genes_node {
    my $self = shift;
    my $doc = $self->_xml_doc;

    my $no_interaction_genes= $doc->createElement("no_interaction_genes");

    for my $gene ($self->no_interaction_genes){
        my $item = $doc->createElement('item');
        my $line = $gene->name;
        my %identifier_to_genes = %{$self->identifier_to_genes};
        IDENTIFIER: for (my ($key, $value) = each %identifier_to_genes){
            for my $g (@$value){ #array of genes
                if($g == $gene){
                    $line .= ' ( ' . $key . ' ) ';
                    last IDENTIFIER;
                }
            }
        }
        $item->addChild($doc->createTextNode($line));
        $no_interaction_genes->addChild($item);
    }

    return $no_interaction_genes;
}

sub get_interactions_node {
    my $self = shift;
    my $doc = $self->_xml_doc;

    my $interactions= $doc->createElement("interactions");

    for my $interaction ($self->interactions){
        my $item = $doc->createElement('item');
        $item->addChild($doc->createTextNode($interaction->__display_name__));
        $interactions->addChild($item);
    }

    return $interactions;
}

sub get_filtered_out_interactions_node {
    my $self = shift;
    my $doc = $self->_xml_doc;

    my $filtered_out_interactions= $doc->createElement("filtered_out_interactions");

    for my $filtered_out_interaction ($self->filtered_out_interactions){
        my $item = $doc->createElement('item');
        $item->addChild($doc->createTextNode($filtered_out_interaction->__display_name__));
        $filtered_out_interactions->addChild($item);
    }

    return $filtered_out_interactions;
}
1;
