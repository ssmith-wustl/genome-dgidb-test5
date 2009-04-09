package Genome::Model::Tools::MetagenomicClassifier::Rdp::ListGenera;

use strict;
use warnings;

use Bio::SeqIO;
require Genome::Utility::MetagenomicClassifier::Rdp::TrainingSet;

class Genome::Model::Tools::MetagenomicClassifier::Rdp::ListGenera {
    is => 'Command',
    has_optional => [
        training_set => {
            type => 'String',
            doc => 'name of training set (broad)',
        },
        training_path => {
            type => 'String',
            doc => 'name of training set (broad)',
        },
    ],
};

sub execute {
    my $self = shift;
    

    my $path = $self->training_path;
    unless ($path) {
        $path = Genome::Utility::MetagenomicClassifier::Rdp->get_training_path($self->training_set);
    }

    my $training_set = Genome::Utility::MetagenomicClassifier::Rdp::TrainingSet->create(path => $path);

    my @genera = @{$training_set->get_genera};

    foreach my $genus (@genera) {
        print _to_string($genus) . "\n";
    }

    return 1;
}

sub _to_string {
    my $genus = shift;
    my @ancestors;

    my $current_taxon = $genus;
    while (defined $current_taxon) {
        unshift @ancestors, $current_taxon;
        $current_taxon = $current_taxon->ancestor
    }

    my $taxonomy_string = "";
    my $first = 1;
    foreach my $taxon (@ancestors) {
        if ($first) {
            $first = 0;
        }
        else {
            $taxonomy_string.= ";";
        }

        $taxonomy_string .= $taxon->node_name;
    }

    return $taxonomy_string;
}

#< HELP >#
sub help_brief {
    "rdp training-set taxonomy lister",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools metagenomic-classifier rdp list-genera   
EOS
}

1;

#$HeadURL$
#$Id$
