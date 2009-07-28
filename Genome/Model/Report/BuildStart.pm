package Genome::Model::Report::BuildStart;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Report::BuildStart {
    is => 'Genome::Model::Report',
    has => [
    name => {
        default_value => 'Build Start',
        is_constant => 1,
    },
    description => {
        calculate => q| 
        return sprintf(
            'Build Initialized for Model (%s)',
            $self->model_name,
        );
        |,
        is_constant => 1,
    },
    ],
};

sub _generate_data {
    return 1;
}

1;

#$HeadURL$
#$Id$
