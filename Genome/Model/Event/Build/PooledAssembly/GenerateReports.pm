package Genome::Model::Event::Build::PooledAssembly::GenerateReports;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Event::Build::PooledAssembly::GenerateReports {
    is => 'Genome::Model::Event',
};

sub execute {
    my $self = shift; 

    return Genome::Model::Tools::PooledBac::GenerateReports->execute(
        project_dir => $self->build->project_dir, 
    );

    return 1;
}

1;
