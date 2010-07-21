package Genome::Model::Event::Build::PooledAssembly::RunBlast;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Event::Build::PooledAssembly::RunBlast {
    is => 'Genome::Model::Event',
};

sub execute {
    my $self = shift;

    return Genome::Model::Tools::PooledBac::RunBlast->execute(
        blast_params => $self->model->processing_profile->blast_params,
        #input/output
        ref_seq_file=>$self->model->ref_seq_file, 
        pooled_bac_dir=>$self->model->pooled_bac_dir,
        ace_file_name => $self->model->ace_file_name, 
        project_dir => $self->build->project_dir, 
        );

    return 1;
}

1;
