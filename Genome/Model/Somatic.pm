
package Genome::Model::Somatic;

use strict;
use warnings;

use Genome;

class Genome::Model::Somatic {
    is  => 'Genome::Model',
    has_optional => [
         tumor_model_links                  => { is => 'Genome::Model::Link', reverse_as => 'to_model', where => [ role => 'tumor'], is_many => 1,
                                               doc => '' },
         tumor_model                     => { is => 'Genome::Model', via => 'tumor_model_links', to => 'from_model', 
                                               doc => '' },
         normal_model_links                  => { is => 'Genome::Model::Link', reverse_as => 'to_model', where => [ role => 'normal'], is_many => 1,
                                               doc => '' },
         normal_model                     => { is => 'Genome::Model', via => 'normal_model_links', to => 'from_model', 
                                               doc => '' },
    ],
};

1;
