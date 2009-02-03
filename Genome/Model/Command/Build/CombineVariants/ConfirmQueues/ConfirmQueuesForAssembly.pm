package Genome::Model::Command::Build::CombineVariants::ConfirmQueues::ConfirmQueuesForAssembly;

use strict;
use warnings;
use above 'Genome';

class Genome::Model::Command::Build::CombineVariants::ConfirmQueues::ConfirmQueuesForAssembly{
    is => 'Command',
    has =>[
        pse_ids =>{ 
            is => 'Integer',
            doc => 'comma separated queue pses to confirm',
            is_many =>1
        }
    ],
};

sub execute{
    my $self = shift;
    my @pse_ids = $self->pse_ids;

    for my $pse_id (@pse_ids){
        my $pse = GSC::PSE->get($pse_id);
        $pse->confirm;
   }

}

1;
