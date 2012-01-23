package Genome::Model::MutationalSignificance::Command::CreateMafFile;

use strict;
use warnings;

use Genome;

my $DEFAULT_LSF_RESOURCE = "-R 'select[model!=Opteron250 && type==LINUX64 && mem>64000 && tmp>150000] span[hosts=1] rusage[tmp=150000, mem=64000]' -M 64000000 -n 4";

class Genome::Model::MutationalSignificance::Command::CreateMafFile {
    is => ['Command::V2'],
    has_input => [
        model => {
            is => 'Genome::Model::SomaticVariation'},
    ],
    has_output => [
        model_output => {},
    ],
    has_param => [
        lsf_resource => { default_value => $DEFAULT_LSF_RESOURCE },
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
