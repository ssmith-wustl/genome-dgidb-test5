package Genome::Model::Tools::Sx::Bin;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::Sx::Bin {
    is => 'Genome::Model::Tools::Sx',
    is_abstract => 1,
};

sub help_brief {
    return 'Bin sequences';
}

1;

