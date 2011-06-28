package Genome::Model::Tools::Sx::Sorter;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::Sx::Sorter {
    is  => 'Command',
    is_abstract => 1,
};

sub help_brief {
    return 'Sort sequences';
}

1;

