package Genome::Model::Command::Build::AmpliconAssembly::TrimAndScreen;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::AmpliconAssembly::TrimAndScreen{
    is => 'Genome::Model::Event',
};

sub execute {
    my $self = shift;

    my $trim_and_screener = Genome::Model::Tools::AmpliconAssembly::TrimAndScreen->create(
        directory => $self->build->data_directory,
        sequencing_center => $self->model->sequencing_center,
        sequencing_platform => $self->model->sequencing_platform,
        trimmer_and_screener => 'trim3_and_crossmatch',
        #trimmer_and_screener => $self->model->trimmer_and_screener,
        #trimmer_and_screener_params => $self->model->trimmer_and_screener_params,
    )
        or return;
    $trim_and_screener->execute
        or return;

    return 1;
}

1;

#$HeadURL$
#$Id$
