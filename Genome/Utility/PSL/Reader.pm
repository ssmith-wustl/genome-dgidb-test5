package Genome::Utility::PSL::Reader;

use strict;
use warnings;

use above "Genome";

class Genome::Utility::PSL::Reader {
    is => 'Genome::Utility::Parser',
    has => [
            separator => {
                          default_value => '\t',
                      },
            ],
};

1;
