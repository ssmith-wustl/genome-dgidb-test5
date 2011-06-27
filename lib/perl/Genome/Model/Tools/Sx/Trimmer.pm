package Genome::Model::Tools::Sx::Trimmer;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::Sx::Trimmer {
    is => 'Command',
    is_abstract => 1,
};

sub help_brief {
    return 'Trim sequences';
}

1;

