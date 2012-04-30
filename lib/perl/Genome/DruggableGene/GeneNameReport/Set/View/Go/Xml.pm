package Genome::DruggableGene::GeneNameReport::Set::View::Go::Xml;

use strict;
use warnings;
use Genome;
use Data::Dumper;
use XML::LibXML;

class Genome::DruggableGene::GeneNameReport::Set::View::Go::Xml {
    is => 'Genome::View::Status::Xml',
    has => {
        perspective => { is => 'Text', value => 'go' },
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
    my $go_results = $doc->createElement("go_results");

    my $data = $self->data;
    $go_results->addChild($self->get_go_results($data->{definite_groups}));

    $doc->setDocumentElement($go_results);
    return $doc->toString(1);
}

sub get_go_results {
    my $self = shift;
    my $groups = shift;
    my $doc = $self->_xml_doc;
    my $go_results_node = $doc->createElement("definite_go_results");

    my %existing_entries;

    while (my ($group_name, $group_data) = each %{$groups}){
        my $group = $group_data->{group};
        my @search_terms = @{$group_data->{search_terms}};
        my @go_genes = grep($_->nomenclature eq 'go_gene_name', $group->genes);
        my @go_category_names = map($_->category_value, grep($_->category_name eq 'go_short_name_and_id', map($_->gene_categories, @go_genes)));
        for my $go_category_name (@go_category_names){
            #skip duplicate entries
            my $entry_key = join(":", $go_category_name, $group_name, join(', ', @{$group_data->{search_terms}}));
            unless($existing_entries{$entry_key}){
                $go_results_node->addChild($self->build_go_results_node(
                    $go_category_name,
                    $group_name,
                    $group_data->{search_terms},
                ));
                $existing_entries{$entry_key}++;
            }
        }
    }

    return $go_results_node;
}

sub build_go_results_node {
    my $self = shift;
    my $go_category_name = shift;
    my $gene_group_name = shift;
    my $search_terms = shift;
    my $doc = $self->_xml_doc;

    my $item = $doc->createElement('item');

    my $gene_group_name_node = $doc->createElement('gene_group_name');
    $gene_group_name_node->addChild($doc->createTextNode($gene_group_name));
    $item->addChild($gene_group_name_node);
    my $category_name_node = $doc->createElement('category_name');
    $category_name_node->addChild($doc->createAttribute('key', 'category_name'));
    $category_name_node->addChild($doc->createTextNode($go_category_name));
    $item->addChild($category_name_node);
    my $search_terms_node = $doc->createElement('search_terms');
    $search_terms_node->addChild($doc->createTextNode(join(', ', @{$search_terms})));
    $item->addChild($search_terms_node);

    return $item;
}

1;
