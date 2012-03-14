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
        $no_interaction_genes->addChild($item);
        my $gene_name = $doc->createElement('gene');
        $gene_name->addChild($doc->createTextNode($gene->name));
        $item->addChild($gene_name);
        my $identifiers = $doc->createElement('identifiers');
        $item->addChild($identifiers);
        my @search_terms;
        IDENTIFIER: while (my ($identifier, $genes) = each %{$self->identifier_to_genes}){
            for my $identified_gene (@$genes){
                if($identified_gene == $gene){
                    push @search_terms, $identifier;
                    next IDENTIFIER;
                }
            }
        }
        $identifiers->addChild($doc->createTextNode('(' . join(' , ', @search_terms) . ')')) if @search_terms;
    }

    return $no_interaction_genes;
}

sub get_interactions_node {
    my $self = shift;
    my $doc = $self->_xml_doc;
    my $interactions= $doc->createElement("interactions");

    for my $interaction ($self->interactions){
        my $item = $doc->createElement('item');
        $interactions->addChild($item);
        my $drug = $doc->createElement('drug');
        $drug->addChild($doc->createAttribute('key', 'drug_name'));
        $drug->addChild($doc->createTextNode($interaction->drug_name));
        $item->addChild($drug);
        my $gene = $doc->createElement('gene');
        $gene->addChild($doc->createAttribute('key', 'gene_name'));
        $gene->addChild($doc->createTextNode($interaction->gene_name));
        $item->addChild($gene);
        my $group = $doc->createElement('group');
        $group->addChild($doc->createTextNode(
                Genome::DruggableGene::GeneNameGroupBridge->get(gene_name_report=>Genome::DruggableGene::GeneNameReport->get(name=>$interaction->gene_name))->gene_name_group->name
            ));
        $item->addChild($group);
        my $interaction_types = $doc->createElement('interaction_type');
        $interaction_types->addChild($doc->createTextNode(join(', ', $interaction->interaction_types)));
        $item->addChild($interaction_types);
        my $identifier = $doc->createElement('identifier');
        $item->addChild($identifier);

        my @identifiers;
        IDENTIFIER: while (my ($identifier, $genes) = each %{$self->identifier_to_genes}){
            for my $identified_gene (@$genes){
                if($identified_gene == $interaction->gene){
                    push @identifiers, $identifier;
                    next IDENTIFIER;
                }
            }
        }
        $identifier->addChild($doc->createTextNode(join(', ', @identifiers)));
    }

    return $interactions;
}

sub get_filtered_out_interactions_node {
    my $self = shift;
    my $doc = $self->_xml_doc;
    my $filtered_out_interactions= $doc->createElement("filtered_out_interactions");

    for my $filtered_out_interaction ($self->filtered_out_interactions){
        my $item = $doc->createElement('item');
        my $line = $filtered_out_interaction->__display_name__;
        IDENTIFIER: while (my ($identifier, $genes) = each %{$self->identifier_to_genes}){
            for my $identified_gene (@$genes){
                if($identified_gene == $filtered_out_interaction->gene){
                    $line .= ' ( ' . $identifier . ' ) ';
                    next IDENTIFIER;
                }
            }
        }
        $item->addChild($doc->createTextNode($line));
        $filtered_out_interactions->addChild($item);
    }

    return $filtered_out_interactions;
}
1;
