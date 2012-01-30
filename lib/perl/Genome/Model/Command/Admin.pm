package Genome::Model::Command::Admin;

use strict;
use warnings;

use Genome;
      
class Genome::Model::Command::Admin {
    is => 'Command::Tree',
    is_abstract => 1,
    english_name => 'genome model admin command',
    doc => 'admion models and builds',
};

1;

