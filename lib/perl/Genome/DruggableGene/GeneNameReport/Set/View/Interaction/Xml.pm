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
        data => { is => 'HASH' },
    ],
};

sub _generate_content {
    my $self = shift;

    #create the XML doc and add it to the object
    my $doc = XML::LibXML->createDocument();
    $self->_xml_doc($doc);
    my $drug_gene_interaction = $doc->createElement("drug_gene_interaction");

    my $data = $self->data;
    $drug_gene_interaction->addChild($self->get_interactions($data->{definite_groups}));
    $drug_gene_interaction->addChild($self->get_ambiguous_interactions($data->{ambiguous_search_terms}));
    $drug_gene_interaction->addChild($self->get_missing_interactions($data->{definite_groups}));
    $drug_gene_interaction->addChild($self->get_missing_ambiguous_interactions($data->{ambiguous_search_terms}));
    $drug_gene_interaction->addChild($self->get_search_terms_without_groups($data->{search_terms_without_groups}));
#    $drug_gene_interaction->addChild($self->get_no_interaction_genes_node);
#    $drug_gene_interaction->addChild($self->get_filtered_out_interactions_node);

    $doc->setDocumentElement($drug_gene_interaction);
    return $doc->toString(1);
}

sub get_search_terms_without_groups {
    my $self = shift;
    my $search_terms_without_groups = shift;
    my $doc = $self->_xml_doc;
    my $search_terms_without_groups_node = $doc->createElement("search_terms_without_groups");

    for my $name (@{$search_terms_without_groups}){
        my $item = $doc->createElement('item');
        $item->addChild($doc->createTextNode($name));
        $search_terms_without_groups_node->addChild($item);
    }

    return $search_terms_without_groups_node;
}

sub get_missing_interactions {
    my $self = shift;
    my $groups = shift;
    my $doc = $self->_xml_doc;
    my $missing_interactions_node = $doc->createElement("missing_interactions");

    while (my ($group_name, $group_data) = each %{$groups}){
        my $group = $group_data->{group};
        my @search_terms = @{$group_data->{search_terms}};

        if (0 == scalar map{$_->interactions}$group->genes){
            my $item = $doc->createElement('item');
            $missing_interactions_node->addChild($item);
            my $group_node = $doc->createElement('group');
            $group_node->addChild($doc->createTextNode($group_name));
            $item->addChild($group_node);
            my $search_terms_node = $doc->createElement('search_terms');
            $search_terms_node->addChild($doc->createTextNode(join(', ', @search_terms)));
            $item->addChild($search_terms_node);
        }
    }
    return $missing_interactions_node;
}

sub get_missing_ambiguous_interactions {
    my $self = shift;
    my $ambiguous_terms_to_gene_groups = shift;
    my $doc = $self->_xml_doc;
    my $missing_interactions_node = $doc->createElement("missing_ambiguous_interactions");

    while (my ($ambiguous_term, $gene_groups) = each %{$ambiguous_terms_to_gene_groups}){
        while (my ($gene_group_name, $gene_group_data) = each %{$gene_groups}){
            my $group = $gene_group_data->{group};

            if (0 == scalar map{$_->interactions}$group->genes){
                my $item = $doc->createElement('item');
                $missing_interactions_node->addChild($item);
                my $group_node = $doc->createElement('group');
                $group_node->addChild($doc->createTextNode($gene_group_name));
                $item->addChild($group_node);
                my $search_terms_node = $doc->createElement('search_terms');
                $search_terms_node->addChild($doc->createTextNode($ambiguous_term));
                $item->addChild($search_terms_node);
                my $matches_node = $doc->createElement('number_of_matches');
                $matches_node->addChild($doc->createTextNode($gene_group_data->{number_of_matches}));
                $item->addChild($matches_node);
            }
        }
    }
    return $missing_interactions_node;
}

sub get_interactions {
    my $self = shift;
    my $groups = shift;
    my $doc = $self->_xml_doc;
    my $interactions_node = $doc->createElement("interactions");

    while (my ($group_name, $group_data) = each %{$groups}){
        my $group = $group_data->{group};
        my @search_terms = @{$group_data->{search_terms}};

        for my $interaction (map{$_->interactions}$group->genes){
            $interactions_node->addChild($self->build_interaction_node(
                    $interaction->drug_name,
                    $interaction->drug->human_readable_name,
                    $interaction->gene_name,
                    $group_name,
                    $group_data->{search_terms},
                    [$interaction->interaction_types],
                ));
        }
    }
    return $interactions_node;
}

sub get_ambiguous_interactions {
    my $self = shift;
    my $ambiguous_terms_to_gene_groups = shift;
    my $doc = $self->_xml_doc;
    my $interactions_node = $doc->createElement("ambiguous_interactions");

    while (my ($ambiguous_term, $gene_groups) = each %{$ambiguous_terms_to_gene_groups}){
        while (my ($gene_group_name, $gene_group_data) = each %{$gene_groups}){
            my $group = $gene_group_data->{group};

            for my $interaction (map{$_->interactions}$group->genes){
                my $interaction_node = ($self->build_interaction_node(
                        $interaction->drug_name,
                        $interaction->drug->human_readable_name,
                        $interaction->gene_name,
                        $gene_group_name,
                        [$ambiguous_term],
                        [$interaction->interaction_types],
                    ));

                my $matches_node = $doc->createElement('number_of_matches');
                $matches_node->addChild($doc->createTextNode($gene_group_data->{number_of_matches}));
                $interaction_node->addChild($matches_node);
                $interactions_node->addChild($interaction_node);
            }
        }
    }
    return $interactions_node;
}

sub build_interaction_node {
    my $self = shift;
    my $drug_name = shift;
    my $human_readable_drug_name = shift;
    my $gene_name = shift;
    my $gene_group_name = shift;
    my $search_terms = shift;
    my $interaction_types = shift;
    my $doc = $self->_xml_doc;

    my $item = $doc->createElement('item');
    my $drug_node = $doc->createElement('drug');
    $drug_node->addChild($doc->createAttribute('key', 'drug_name'));
    $drug_node->addChild($doc->createTextNode($drug_name));
    $item->addChild($drug_node);
    my $human_readable_drug_name_node = $doc->createElement('human_readable_drug_name');#Eventually replace with drug groups
    $human_readable_drug_name_node->addChild($doc->createTextNode($human_readable_drug_name));
    $item->addChild($human_readable_drug_name_node);
    my $gene_node = $doc->createElement('gene');
    $gene_node->addChild($doc->createAttribute('key', 'gene_name'));
    $gene_node->addChild($doc->createTextNode($gene_name));
    $item->addChild($gene_node);
    my $group_node = $doc->createElement('group');
    $group_node->addChild($doc->createTextNode($gene_group_name));
    $item->addChild($group_node);
    my $interaction_types_node = $doc->createElement('interaction_type');
    $interaction_types_node->addChild($doc->createTextNode(join(', ', @{$interaction_types})));
    $item->addChild($interaction_types_node);
    my $search_terms_node = $doc->createElement('search_terms');
    $search_terms_node->addChild($doc->createTextNode(join(', ', @{$search_terms})));
    $item->addChild($search_terms_node);

    return $item;
}

sub get_filtered_out_interactions_node {
    my $self = shift;
    my $doc = $self->_xml_doc;
    my $interactions= $doc->createElement("filtered_out_interactions");

    for my $interaction ($self->filtered_out_interactions){
        my $item = $doc->createElement('item');
        $interactions->addChild($item);
        my $drug = $doc->createElement('drug');
        $drug->addChild($doc->createAttribute('key', 'drug_name'));
        $drug->addChild($doc->createTextNode($interaction->drug_name));
        $item->addChild($drug);
        my $human_readable_drug_name = $doc->createElement('human_readable_drug_name');
        $human_readable_drug_name->addChild($doc->createTextNode($interaction->drug->human_readable_name));
        $item->addChild($human_readable_drug_name);
        my $human_readable_gene_name = $doc->createElement('human_readable_gene_name');
        $human_readable_gene_name->addChild($doc->createTextNode($interaction->gene->human_readable_name));
        $item->addChild($human_readable_gene_name);
        my $gene = $doc->createElement('gene');
        $gene->addChild($doc->createAttribute('key', 'gene_name'));
        $gene->addChild($doc->createTextNode($interaction->gene_name));
        $item->addChild($gene);
        my $bridge = Genome::DruggableGene::GeneNameGroupBridge->get(gene=>Genome::DruggableGene::GeneNameReport->get(name=>$interaction->gene_name));
        if($bridge){
            my $group = $doc->createElement('group');
            $group->addChild($doc->createTextNode(
                    $bridge->group->name
                ));
            $item->addChild($group);
        }
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
1;
