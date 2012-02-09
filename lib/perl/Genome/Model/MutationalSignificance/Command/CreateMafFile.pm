package Genome::Model::MutationalSignificance::Command::CreateMafFile;

use strict;
use warnings;

use Genome;

class Genome::Model::MutationalSignificance::Command::CreateMafFile {
    is => ['Command::V2'],
    has_input => [
        model => {
            is => 'Genome::Model::SomaticVariation'},
    ],
    has_output => [
        model_output => {},
    ],
};

sub execute {
    my $self = shift;

    my $rand = rand();
    $self->model_output($rand);
    my $status = "Created MAF file $rand";
    $self->status_message($status);
    return 1;
}

1;
