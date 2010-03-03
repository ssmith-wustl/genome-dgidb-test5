package Genome::Model::Event::Build::PooledAssembly::AddLinkingContigs;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Event::Build::PooledAssembly::AddLinkingContigs {
    is => 'Genome::Model::Event',
};

sub execute {
    my $self = shift; 

    return Genome::Model::Tools::PooledBac::AddLinkingContigs->execute(        
        #input/output
        project_dir => $self->build->project_dir, 
    );

    return 1;
}

1;
