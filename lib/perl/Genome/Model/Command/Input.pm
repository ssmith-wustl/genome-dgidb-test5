package Genome::Model::Command::Input;

use strict;
use warnings;

use Genome;
      
class Genome::Model::Command::Input {
    is => 'Command',
    is_abstract => 1,
    english_name => 'genome model input command',
    doc => 'work with model inputs',
};

1;

