package Genome::Model::Tools::WuBlast::Blastn;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::WuBlast::Blastn {
    is => 'Genome::Model::Tools::WuBlast',
    has_optional => [
    N => {
        is => 'Integer',
        doc => 'Mismatch score',
    },
    ],
};

sub _additional_blast_params {
    return (qw/ N /);
}

1;

#$HeadURL$
#$Id$
