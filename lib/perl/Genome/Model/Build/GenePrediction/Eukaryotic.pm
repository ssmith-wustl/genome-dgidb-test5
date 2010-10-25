package Genome::Model::Build::GenePrediction::Eukaryotic;

use strict;
use warnings;
use Genome;

class Genome::Model::Build::GenePrediction::Eukaryotic {
    is => 'Genome::Model::Build::GenePrediction',
};

sub log_directory {
    my $self = shift;
    return $self->data_directory . '/logs/';
}

sub resolve_workflow_name {
    my $self = shift;
    return 'eukaryotic gene prediction ' . $self->build_id;
}

sub split_fastas_output_directory {
    my $self = shift;
    return $self->data_directory . '/split_fastas/';
}

sub raw_output_directory {
    my $self = shift;
    return $self->data_directory . '/raw_predictor_output/';
}

sub prediction_directory {
    my $self = shift;
    return $self->data_directory;
}

1;

