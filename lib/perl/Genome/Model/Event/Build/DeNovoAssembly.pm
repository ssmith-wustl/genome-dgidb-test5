package Genome::Model::Event::Build::DeNovoAssembly;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly {
    is => 'Genome::Model::Event',
    is_abstract => 1,
    has => [
        processing_profile => {
            via => 'build',
        }
    ],
};

sub bsub_rusage {
    return "-R 'span[hosts=1] select[type=LINUX64]'";
}

1;

#$HeadURL
#$Id#
