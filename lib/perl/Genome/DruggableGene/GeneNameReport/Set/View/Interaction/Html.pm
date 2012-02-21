package Genome::DruggableGene::GeneNameReport::Set::View::Interaction::Html;

use strict;
use warnings;

use Genome;

class Genome::DruggableGene::GeneNameReport::Set::View::Interaction::Html {
    is => 'Genome::View::Status::Html',
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

sub _get_xml_view {
    my $self = shift;
    #die $self->error_message( "Genes without drugs:\n" );
    #print join("\n", map{$_->name}$self->no_interaction_genes);
    return Genome::DruggableGene::GeneNameReport::Set::View::Interaction::Xml->create(
        no_match_genes => [$self->no_match_genes],
        no_interaction_genes => [$self->no_interaction_genes],
        interactions => [$self->interactions],
        filtered_out_interactions => [$self->filtered_out_interactions],
        identifier_to_genes=> [$self->identifier_to_genes],
        subject => $self->subject,
    );
}

1;
