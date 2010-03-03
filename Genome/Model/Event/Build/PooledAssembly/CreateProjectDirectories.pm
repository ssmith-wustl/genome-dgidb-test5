package Genome::Model::Event::Build::PooledAssembly::CreateProjectDirectories;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Event::Build::PooledAssembly::CreateProjectDirectories {
    is => 'Genome::Model::Event',
};

sub execute {
    my $self = shift; 
    
    return Genome::Model::Tools::PooledBac::CreateProjectDirectoriesNew->execute(
        pooled_bac_dir=>$self->model->pooled_bac_dir,
        ace_file_name => $self->model->ace_file_name,
        phd_file_name_or_dir => $self->model->phd_ball, 
        project_dir => $self->build->project_dir
    );
    
    return 1;
}

1;
